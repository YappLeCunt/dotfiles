#!/usr/bin/env bash
# setup-gnome-defaults.sh — GNOME desktop defaults that live in dconf,
# not in files (so they can't be symlinked like the rest of the dotfiles).
# Idempotent: safe to re-run any time.
#
# - Desktop animations stay ENABLED. They were once disabled for iGPU
#   snappiness, but that was reverted on request (see git history) —
#   do NOT re-disable without asking.
# - Blur my Shell + Ubuntu Dock settings loaded from blur-my-shell/ and
#   dash-to-dock/ dconf files (both subtrees are portable).
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

echo "==> GNOME: Ubuntu Dock settings (from dash-to-dock/settings.dconf)"
DOCK_DCONF="$DOTFILES/dash-to-dock/settings.dconf"
if [ -f "$DOCK_DCONF" ]; then
  dconf load /org/gnome/shell/extensions/dash-to-dock/ < "$DOCK_DCONF"
  echo "  applied"
else
  echo "  no dash-to-dock/settings.dconf in repo — skipping"
fi

echo "==> Done."
