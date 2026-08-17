#!/usr/bin/env bash
# setup-gnome-extensions.sh — install & enable the GNOME Shell extensions this
# setup depends on, straight from extensions.gnome.org (EGO).
# Idempotent: safe to re-run any time; never touches other extensions.
#
#   clipboard-indicator@tudmotu.com       # clipboard history (top-bar icon)
#
# Install path preference:
#   1. Live: with a shell session reachable, the shell installs + registers
#      the extension itself (org.gnome.Shell.Extensions.InstallRemoteExtension)
#      — loaded immediately, no restart.
#   2. Headless/SSH: direct EGO download + unzip + schema compile. The shell
#      only picks these up after Alt+F2 r or logout/login.
# Then enabled-extensions is MERGED (existing extensions preserved — we never
# clobber the list, only add ours to it).
set -euo pipefail

EXTENSIONS=(
  "clipboard-indicator@tudmotu.com"
)

EXT_DIR="$HOME/.local/share/gnome-shell/extensions"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }

SHELL_MAJOR="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)"
if [ -z "$SHELL_MAJOR" ]; then
  warn "gnome-shell not installed — nothing to do here."
  exit 1
fi
echo "  shell major: $SHELL_MAJOR"

is_installed() { # uuid -> 0 if dir + metadata.json exist
  [ -f "$EXT_DIR/$1/metadata.json" ]
}

shell_reachable() { # 0 if a shell session answers on the session bus
  gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Extensions.ListExtensions >/dev/null 2>&1
}

install_via_shell() { # uuid — shell downloads, registers, enables (live)
  gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
    --method org.gnome.Shell.Extensions.InstallRemoteExtension "$1" >/dev/null 2>&1
}

install_via_ego() { # uuid — headless fallback: EGO zip + schema compile
  local uuid="$1" enc pk url zipfile
  enc="$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))' "$uuid")"
  pk="$(curl -s "https://extensions.gnome.org/extension-query/?search=$enc" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for e in d.get('extensions',[]):
    if e.get('uuid')=='$uuid':
        print(e['pk']); break
")"
  [ -n "$pk" ] || { warn "EGO: no entry for $uuid"; return 1; }
  url="$(curl -s "https://extensions.gnome.org/extension-info/?pk=$pk&shell_version=$SHELL_MAJOR" | python3 -c "
import json,sys
print(json.load(sys.stdin).get('download_url') or '')
")"
  [ -n "$url" ] || { warn "EGO: no build for shell $SHELL_MAJOR ($uuid)"; return 1; }
  zipfile="$(mktemp --suffix=.zip)"
  curl -sL -o "$zipfile" "https://extensions.gnome.org$url"
  rm -rf "$EXT_DIR/$uuid"
  unzip -q "$zipfile" -d "$EXT_DIR/$uuid/"
  rm -f "$zipfile"
  if [ -d "$EXT_DIR/$uuid/schemas" ]; then
    glib-compile-schemas "$EXT_DIR/$uuid/schemas"   # prefs dialog dies without this
  fi
}

# ---- 1. install missing extensions ------------------------------------------
LIVE=0
shell_reachable && LIVE=1
if [ "$LIVE" -eq 1 ]; then
  log "Shell session reachable — installing live (no restart needed)"
else
  warn "No shell session — installing files only (Alt+F2 r or logout/login to load)"
fi

for uuid in "${EXTENSIONS[@]}"; do
  if is_installed "$uuid"; then
    echo "  ok    $uuid (already installed)"
    continue
  fi
  log "Installing $uuid"
  if [ "$LIVE" -eq 1 ] && install_via_shell "$uuid"; then
    echo "  installed + registered via shell"
  else
    install_via_ego "$uuid" && echo "  installed via EGO (file-based)"
  fi
done

# ---- 2. merge into enabled-extensions (never clobber) ------------------------
log "Merging enabled-extensions (preserving existing)"
CUR="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || echo '@as []')"
NEW="$(CUR="$CUR" python3 -c '
import ast, os, sys
raw = os.environ["CUR"]
cur = [] if raw == "@as []" else ast.literal_eval(raw)
for w in sys.argv[1:]:
    if w not in cur:
        cur.append(w)
print(repr(cur))
' "${EXTENSIONS[@]}")"
gsettings set org.gnome.shell enabled-extensions "$NEW"

# ---- 3. verify ---------------------------------------------------------------
log "Verifying"
for uuid in "${EXTENSIONS[@]}"; do
  if gnome-extensions info "$uuid" >/dev/null 2>&1; then
    state="$(gnome-extensions info "$uuid" | sed -n 's/^ *State: //p')"
    if [ "$state" != "ACTIVE" ]; then
      echo "  $uuid -> $state (restart shell: Alt+F2 r or logout/login)"
    else
      echo "  $uuid -> ACTIVE"
    fi
  else
    echo "  $uuid -> on disk, shell not aware yet (restart shell)"
  fi
done
echo "  enabled-extensions = $(gsettings get org.gnome.shell enabled-extensions)"
log "Done. Clipboard Indicator = top-bar clipboard icon."
