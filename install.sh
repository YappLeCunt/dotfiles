#!/usr/bin/env bash
# install.sh — symlink the versioned dotfiles (home*/) into $HOME.
#
# Layered by platform, deepest layer wins for any given path:
#   home/          layer 0 — ALL-OS    (starship.toml, .gitconfig, ...)
#   home-linux/    layer 1 — Linux     (.bashrc, fontconfig, flatpak scripts, ...)
#   home-gnome/    layer 2 — GNOME DE  (GNOME-specific configs)
#   home-kde/      layer 2 — KDE DE    (kdeconnect + KDE-specific configs)
# Layer 0 is always active; layer 1 when uname says Linux; the DE layer is
# picked from $XDG_CURRENT_DESKTOP (with a pgrep fallback for SSH sessions).
#
# Idempotent. Never clobbers a real file:
#   - target already symlinked to the winning layer   -> skip ("ok")
#   - target symlinked into this repo (stale layer)   -> re-point ("relink")
#   - target exists as a real file / foreign link     -> skip ("SKIP")
#   - target missing                                  -> create symlink + parent dirs
#
# Usage:
#   ./install.sh            # apply
#   ./install.sh --dry-run  # show what WOULD change, change nothing
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- active layers (lowest priority first; later entries win) ----------------
LAYERS=("$DOTFILES/home")
if [ "$(uname -s)" = "Linux" ]; then
  LAYERS+=("$DOTFILES/home-linux")
fi
DE="${XDG_CURRENT_DESKTOP:-}"
if [ -z "$DE" ]; then          # SSH / no session env: sniff running shell
  pgrep -x gnome-shell >/dev/null 2>&1 && DE="GNOME"
  pgrep -x plasmashell >/dev/null 2>&1 && DE="KDE"
fi
case "$DE" in
  *GNOME*) LAYERS+=("$DOTFILES/home-gnome") ;;
  *KDE*)   LAYERS+=("$DOTFILES/home-kde") ;;
esac

echo "==> Active layers:"
for l in "${LAYERS[@]}"; do echo "    ${l#"$DOTFILES"/}"; done

# ---- build winner map: relpath -> winning source -----------------------------
declare -A WINNER
for layer in "${LAYERS[@]}"; do
  [ -d "$layer" ] || continue
  while IFS= read -r -d '' f; do
    WINNER["${f#"$layer"/}"]="$f"
  done < <(find "$layer" -type f -print0)
done

link() { # link <rel> <src>
  local rel="$1" src="$2" dst="$HOME/$rel"
  local target
  if [ -L "$dst" ]; then
    target="$(readlink "$dst")"
    case "$target" in
      "$DOTFILES"/*)   # ours (any layer) — re-point if stale
        if [ "$target" = "$src" ]; then
          echo "  ok    $rel"
        elif [ "$DRY_RUN" -eq 1 ]; then
          echo "  relink $rel"
        else
          ln -sfn "$src" "$dst"
          echo "  relink $rel -> $src"
        fi
        return ;;
    esac
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
fi

for rel in "${!WINNER[@]}"; do
  link "$rel" "${WINNER[$rel]}"
done

echo
echo "==> Done. Per-app setup (ghostty defaults, VLC look, fonts, hardware kit):"
echo "    ./setup-ghostty-defaults.sh    # Ctrl+Alt+T -> Ghostty (2 pkexec prompts)"
echo "    ./setup-gnome-defaults.sh      # dconf defaults (animations ON, Blur prefs)"
echo "    ./setup-gnome-extensions.sh    # GNOME extensions (clipboard indicator, Blur my Shell)"
echo "    ./setup-normcap-defaults.sh    # NormCap flatpak OCR fix + neutral border (no sudo)"
echo "    ./scripts/install-fonts.sh     # JetBrainsMono Nerd Font + Inter"
echo "    ~/.local/bin/vlc-windows-look.sh  # VLC flatpak Windows look"
echo "    see hardware/README.md for the CPU-quarantine kit"
