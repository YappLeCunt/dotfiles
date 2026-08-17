#!/usr/bin/env bash
# apply-gsconnect-prefs.sh — apply the versioned GSConnect plugin prefs
# (gsconnect/plugin-prefs.dconf) to EVERY paired device.
# Phone-agnostic: the template carries no device ID, so it works with
# whatever phone is paired right now — a new phone, a re-paired phone
# after an app reinstall, anything. Re-run after pairing a new device.
# Idempotent. No sudo. Safe to re-run any time.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$DOTFILES/gsconnect/plugin-prefs.dconf"
BASE="/org/gnome/shell/extensions/gsconnect"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

if [ ! -f "$TEMPLATE" ]; then
  echo "no $TEMPLATE — nothing to apply"
  exit 0
fi

# ---- 1. which devices are paired? --------------------------------------------
RAW="$(dconf read "$BASE/devices" 2>/dev/null || true)"
[ -n "$RAW" ] || RAW="@as []"
IDS="$(printf '%s' "$RAW" | tr -d "[]'" | tr ',' '\n' \
        | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' || true)"

if [ -z "$IDS" ]; then
  log "No paired devices yet — pair a phone in GSConnect, then re-run."
  exit 0
fi

# ---- 2. split the template into per-plugin files ([plugin/X] sections) -------
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT
for plugin in $(grep '^\[' "$TEMPLATE" | sed 's/^\[plugin\///; s/\]$//'); do
  awk -v p="[plugin/$plugin]" \
    '$0==p{f=1;print "[/]";next} /^\[/{f=0} f' "$TEMPLATE" > "$TMPD/$plugin"
done

# ---- 3. load each plugin subtree under each paired device --------------------
for id in $IDS; do
  log "Applying GSConnect prefs to device $id"
  for f in "$TMPD"/*; do
    [ -f "$f" ] || continue
    plugin="$(basename "$f")"
    dconf load "$BASE/device/$id/plugin/$plugin/" < "$f"
    echo "  plugin/$plugin applied"
  done
done
log "Done."
