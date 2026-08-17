#!/usr/bin/env bash
# setup-gnome-defaults.sh — GNOME desktop defaults that live in dconf,
# not in files (so they can't be symlinked like the rest of the dotfiles).
# Idempotent: safe to re-run any time.
#
# - Desktop animations stay ENABLED. They were once disabled for iGPU
#   snappiness, but that was reverted on request (see git history) —
#   do NOT re-disable without asking.
# - GSConnect: global prefs forced (show-indicators); per-device plugin
#   prefs (clipboard sync, battery alert, notification filter) applied to
#   every paired device via scripts/apply-gsconnect-prefs.sh — phone-agnostic,
#   re-run after pairing any new phone. Certs/pairing stay machine-local.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> GNOME: enabling desktop animations"
gsettings set org.gnome.desktop.interface enable-animations true

echo "==> GNOME: GSConnect preferences"
dconf write /org/gnome/shell/extensions/gsconnect/show-indicators true
echo "  show-indicators = true (global)"
"$DOTFILES/scripts/apply-gsconnect-prefs.sh"

echo "==> Done."
