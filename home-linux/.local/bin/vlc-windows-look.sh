#!/usr/bin/env bash
# vlc-windows-look.sh — replicate the "Windows look" VLC setup on a fresh Linux machine.
# Idempotent: safe to re-run. sudo is needed ONLY to install flatpak itself (if missing);
# everything else is user-level. GUI sudo approval (polkit) works fine.
#
# What it does:
#   1. installs flatpak if missing (apt/dnf/pacman)          [sudo, once]
#   2. adds the Flathub remote (user-level)
#   3. installs VLC (org.videolan.VLC, user-level)
#   4. flatpak overrides: QT_STYLE_OVERRIDE=fusion (flat Windows widgets)
#      + FONTCONFIG_FILE=<standalone config> (Inter font wins over DejaVu)
#   5. installs Inter static fonts to ~/.local/share/fonts/Inter (no sudo)
#   6. writes ~/.config/fontconfig/vlc-fonts.conf — overrides placed AFTER
#      the runtime conf.d include so 57-dejavu-sans.conf cannot clobber them
#   7. verifies: sandbox fc-match must resolve sans-serif -> Inter

set -euo pipefail

APP_ID=org.videolan.VLC
FC_CONF="$HOME/.config/fontconfig/vlc-fonts.conf"
FONT_DIR="$HOME/.local/share/fonts/Inter"
INTER_REPO="rsms/inter"
INTER_VERSION="v4.1"   # bump as needed; falls back to GitHub latest-release API

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }

# ---- 1. flatpak bootstrap (only when missing) -------------------------------
if ! command -v flatpak >/dev/null 2>&1; then
  log "flatpak not found — installing (sudo approval required once)"
  if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y flatpak
  elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y flatpak
  elif command -v pacman  >/dev/null 2>&1; then sudo pacman -Sy --noconfirm flatpak
  else warn "Unsupported distro — install flatpak manually, then re-run."; exit 1
  fi
fi

# ---- 2. Flathub remote ------------------------------------------------------
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# ---- 3. VLC -----------------------------------------------------------------
log "Ensuring $APP_ID (user-level install)"
flatpak install --user -y flathub "$APP_ID"

# ---- 4. flatpak overrides ----------------------------------------------------
log "Applying flatpak overrides"
flatpak override --user --env=QT_STYLE_OVERRIDE=fusion "$APP_ID"
flatpak override --user --env="FONTCONFIG_FILE=$FC_CONF" "$APP_ID"

# ---- 5. Inter fonts ----------------------------------------------------------
# IMPORTANT: install the STATIC Inter.ttc — the variable TTF's family is
# "Inter Variable", so aliases for "Inter" silently fall through to DejaVu.
log "Installing Inter fonts to $FONT_DIR"
mkdir -p "$FONT_DIR"
if [ ! -f "$FONT_DIR/Inter.ttc" ]; then
  tmp="$(mktemp -d)"
  url="https://github.com/$INTER_REPO/releases/download/$INTER_VERSION/Inter-$INTER_VERSION.zip"
  if ! curl -fsSL -o "$tmp/inter.zip" "$url"; then
    log "Inter $INTER_VERSION not found — falling back to latest release"
    url="$(curl -fsSL "https://api.github.com/repos/$INTER_REPO/releases/latest" | grep -o 'https://[^"]*\.zip' | head -1)"
    [ -n "$url" ] || { warn "Could not locate Inter download URL"; exit 1; }
    curl -fsSL -o "$tmp/inter.zip" "$url"
  fi
  ( cd "$tmp" && python3 -c "import zipfile; zipfile.ZipFile('inter.zip').extractall('.')" )
  cp "$tmp"/Inter.ttc "$FONT_DIR/" 2>/dev/null || warn "Inter.ttc not found in archive (check Inter version layout)"
  cp "$tmp"/InterVariable*.ttf "$FONT_DIR/" 2>/dev/null || true
  rm -rf "$tmp"
fi
fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1

# ---- 6. standalone fontconfig config ------------------------------------------
# Overrides must come AFTER the conf.d include: the flatpak runtime's
# 57-dejavu-sans.conf otherwise clobbers any user sans-serif alias.
log "Writing $FC_CONF"
mkdir -p "$(dirname "$FC_CONF")"
cat > "$FC_CONF" <<'XML'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>/usr/share/fonts</dir>
  <dir>/usr/local/share/fonts</dir>
  <dir prefix="xdg">fonts</dir>
  <include ignore_missing="yes">/etc/fonts/conf.d</include>
  <cachedir prefix="xdg">fontconfig</cachedir>
  <!-- Loaded AFTER conf.d: these win over 57-dejavu-sans.conf -->
  <alias>
    <family>sans-serif</family>
    <prefer><family>Inter</family></prefer>
  </alias>
  <alias>
    <family>Sans Serif</family>
    <prefer><family>Inter</family></prefer>
  </alias>
  <alias>
    <family>system-ui</family>
    <prefer><family>Inter</family></prefer>
  </alias>
  <!-- The strong-prepend match is REQUIRED: the alias alone loses to the
       runtime's 57-dejavu-sans.conf alias (verified empirically). -->
  <match target="pattern">
    <test name="family">
      <string>sans-serif</string>
    </test>
    <edit name="family" mode="prepend" binding="strong">
      <string>Inter</string>
    </edit>
  </match>
</fontconfig>
XML

# ---- 7. verify ----------------------------------------------------------------
log "Verifying"
flatpak list --user --columns=application,version 2>/dev/null | grep -i "$APP_ID" || true
m="$(flatpak run --command=fc-match "$APP_ID" sans-serif 2>/dev/null)"
echo "  sans-serif -> $m"
case "$m" in
  *Inter*) ;;
  *) warn "sans-serif still resolves to: $m — something is off" ;;
esac
echo "  bold       -> $(flatpak run --command=fc-match "$APP_ID" 'sans-serif:bold' 2>/dev/null)"
echo "  overrides: $(flatpak override --user --show "$APP_ID" | tr '\n' ' ')"

log "Done. Start it: flatpak run $APP_ID"
warn "If VLC is already running, restart it — Qt caches fonts at startup."
