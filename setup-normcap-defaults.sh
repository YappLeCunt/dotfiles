#!/usr/bin/env bash
# setup-normcap-defaults.sh — make the NormCap flatpak actually OCR, with a
# neutral capture border. Idempotent: safe to re-run after reinstalls or
# flatpak updates.
#
# Why this exists — the NormCap 0.6.0 flatpak ships two broken tesseract bits:
#   1. Manifest env TESSDATA_PREFIX=/app/share, but the traineddata lives at
#      /app/share/tessdata/ -> tesseract cannot load ANY language.
#   2. Its bundled tessdata resources are empty, so the first-run copy into
#      the config dir writes a 0-byte eng.traineddata that NormCap then
#      passes via --tessdata-dir -> same failure even with the env fixed.
#
# What it does:
#   1. ensures the NormCap flatpak (com.github.dynobo.normcap, user-level)
#   2. flatpak override: TESSDATA_PREFIX=/app/share/tessdata
#   3. copies ./normcap/settings.conf into the sandbox config dir (never
#      clobbers an existing file). NOTE: this is a plain copy on purpose —
#      a symlink to ~/dotfiles would be invisible inside the sandbox, which
#      doesn't mount the repo.
#   4. replaces a missing/0-byte eng.traineddata with the real one from
#      /app/share/tessdata/ (inside the sandbox)
#   5. verifies: sandboxed tesseract --list-langs must list eng
#
# All user-level — no sudo.
set -euo pipefail

APP_ID=com.github.dynobo.normcap
CONF_DIR="$HOME/.var/app/$APP_ID/config/normcap"
SETTINGS="$CONF_DIR/settings.conf"
TESSDATA="$CONF_DIR/tessdata/eng.traineddata"
SRC_CONF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/normcap/settings.conf"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }

# ---- 1. NormCap flatpak ------------------------------------------------------
if ! flatpak info "$APP_ID" >/dev/null 2>&1; then
  log "NormCap not installed — installing (user-level)"
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install --user -y flathub "$APP_ID"
fi

# ---- 2. flatpak override -----------------------------------------------------
log "Applying flatpak override: TESSDATA_PREFIX=/app/share/tessdata"
flatpak override --user --env=TESSDATA_PREFIX=/app/share/tessdata "$APP_ID"

# ---- 3. settings.conf (neutral dark-gray border #48484A) ---------------------
log "Writing $SETTINGS"
mkdir -p "$CONF_DIR"
if [ ! -f "$SETTINGS" ]; then
  cp "$SRC_CONF" "$SETTINGS"
  echo "  copied repo default (border #48484A)"
elif cmp -s "$SRC_CONF" "$SETTINGS"; then
  echo "  in sync with repo (border #48484A)"
else
  warn "existing settings.conf differs from repo copy — keeping yours:"
  diff -u "$SRC_CONF" "$SETTINGS" | sed 's/^/  /' || true
fi

# ---- 4. traineddata (fix the 0-byte copy bug) --------------------------------
log "Fixing eng.traineddata"
if [ ! -s "$TESSDATA" ]; then   # missing or 0 bytes
  # shellcheck disable=SC2016  # $XDG_CONFIG_HOME expands INSIDE the flatpak sandbox
  flatpak run --command=sh "$APP_ID" -c 'cp /app/share/tessdata/eng.traineddata "$XDG_CONFIG_HOME/normcap/tessdata/eng.traineddata"'
  if [ ! -s "$TESSDATA" ]; then
    warn "copy failed — is the app installed and /app/share/tessdata present?"
  else
    echo "  restored $(du -h "$TESSDATA" | cut -f1) eng.traineddata"
  fi
else
  echo "  present: $(du -h "$TESSDATA" | cut -f1)"
fi

# ---- 5. verify ---------------------------------------------------------------
log "Verifying sandboxed tesseract"
flatpak run --command=tesseract "$APP_ID" --list-langs 2>&1 | sed 's/^/  /'
echo "  overrides: $(flatpak override --user --show "$APP_ID" | tr '\n' ' ')"
log "Done. Relaunch NormCap and grab a region — border is #48484A."
