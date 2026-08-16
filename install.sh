#!/usr/bin/env bash
# install.sh — symlink the versioned dotfiles (home/) into $HOME.
#
# Idempotent. Never clobbers anything:
#   - target already symlinked into this repo   -> skip ("ok")
#   - target exists as a real file / other link -> skip ("SKIP")
#   - target missing                            -> create symlink + parent dirs
#
# Usage:
#   ./install.sh            # apply
#   ./install.sh --dry-run  # show what WOULD change, change nothing
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DOTFILES/home"

link() { # link <repo-relative-path>
  # NOTE: separate `local` statements — `local a=1 b=$a` declares both
  # variables before ANY assignment runs (bash gotcha; unbound under set -u).
  local rel="$1"
  local src="$SRC/$rel"
  local dst="$HOME/$rel"

  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    echo "  ok    $rel"
    return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    echo "  SKIP  $rel  (exists, not ours: $dst)"
    return
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  link  $rel"
  else
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "  link  $rel -> $src"
  fi
}

if [ "$DRY_RUN" -eq 1 ]; then
  echo "==> DRY RUN — nothing will be changed"
else
  echo "==> Linking dotfiles from $SRC"
fi

while IFS= read -r -d '' f; do
  link "${f#"$SRC"/}"
done < <(find "$SRC" -type f -print0)

echo
echo "==> Done. Per-app setup (ghostty defaults, VLC look, fonts, hardware kit):"
echo "    ./setup-ghostty-defaults.sh    # Ctrl+Alt+T -> Ghostty (2 pkexec prompts)"
echo "    ./setup-gnome-defaults.sh      # dconf defaults (desktop animations ON)"
echo "    ./setup-normcap-defaults.sh    # NormCap flatpak OCR fix + neutral border (no sudo)"
echo "    ./scripts/install-fonts.sh     # JetBrainsMono Nerd Font + Inter"
echo "    ~/.local/bin/vlc-windows-look.sh  # VLC flatpak Windows look"
echo "    see hardware/README.md for the CPU-quarantine kit"
