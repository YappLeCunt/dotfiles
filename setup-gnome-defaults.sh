#!/usr/bin/env bash
# setup-gnome-defaults.sh — GNOME desktop defaults that live in dconf,
# not in files (so they can't be symlinked like the rest of the dotfiles).
# Idempotent: safe to re-run any time.
#
# - Desktop animations stay ENABLED. They were once disabled for iGPU
#   snappiness, but that was reverted on request (see git history) —
#   do NOT re-disable without asking.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> GNOME: enabling desktop animations"
gsettings set org.gnome.desktop.interface enable-animations true

echo "==> GNOME: Blur my Shell settings (from blur-my-shell/settings.dconf)"
BLUR_DCONF="$DOTFILES/blur-my-shell/settings.dconf"
if [ -f "$BLUR_DCONF" ]; then
  dconf load /org/gnome/shell/extensions/blur-my-shell/ < "$BLUR_DCONF"
  echo "  applied"
else
  echo "  no blur-my-shell/settings.dconf in repo — skipping"
fi

echo "==> Done."
