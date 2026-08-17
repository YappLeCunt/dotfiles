#!/usr/bin/env bash
# setup-gnome-defaults.sh — GNOME desktop defaults that live in dconf,
# not in files (so they can't be symlinked like the rest of the dotfiles).
# Idempotent: safe to re-run any time.
#
# - Desktop animations stay ENABLED. They were once disabled for iGPU
#   snappiness, but that was reverted on request (see git history) —
#   do NOT re-disable without asking.
# - GSConnect prefs come from gsconnect/gsconnect.dconf, applied ONLY when
#   no device is paired yet. Certs/pairing are machine-specific by design
#   (stripped from the file) — re-pair on a fresh box.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> GNOME: enabling desktop animations"
gsettings set org.gnome.desktop.interface enable-animations true

echo "==> GNOME: GSConnect preferences"
GSCONNECT_DCONF="$DOTFILES/gsconnect/gsconnect.dconf"
if [ -f "$GSCONNECT_DCONF" ]; then
  EXISTING="$(dconf read /org/gnome/shell/extensions/gsconnect/devices 2>/dev/null || true)"
  if [ -n "$EXISTING" ] && [ "$EXISTING" != "@as []" ]; then
    echo "  GSConnect already has devices — keeping existing pairing + prefs"
  else
    dconf load /org/gnome/shell/extensions/gsconnect/ < "$GSCONNECT_DCONF"
    echo "  GSConnect prefs applied (gsconnect/gsconnect.dconf)"
  fi
else
  echo "  no gsconnect/gsconnect.dconf in repo — skipping"
fi

echo "==> Done."
