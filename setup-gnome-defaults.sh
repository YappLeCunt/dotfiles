#!/usr/bin/env bash
# setup-gnome-defaults.sh — GNOME desktop defaults that live in dconf,
# not in files (so they can't be symlinked like the rest of the dotfiles).
# Idempotent: safe to re-run any time.
#
# - Desktop animations stay ENABLED. They were once disabled for iGPU
#   snappiness, but that was reverted on request (see git history) —
#   do NOT re-disable without asking.
set -euo pipefail

echo "==> GNOME: enabling desktop animations"
gsettings set org.gnome.desktop.interface enable-animations true

echo "==> Done."
