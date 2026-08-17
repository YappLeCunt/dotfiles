#!/usr/bin/env bash
# setup-zram.sh — compressed swap in RAM (zram) for memory-poor laptops.
# Idempotent: safe to re-run on any boot, after updates, or on a fresh install.
#
# Why this exists — a 14 GB laptop with Chrome/Electron routinely blows past
# RAM: the kernel OOM-kills a browser tab and can take the whole desktop
# session down with it (observed 2026-08-17: 24.4 GB working set vs 25 GB
# total capacity -> org.gnome.Shell@x11.service died with 'oom-kill').
# zram keeps evicted pages compressed IN RAM (zstd ~2.5-3x on browser pages),
# so swap is ~20-50x faster than disk and the SSD never thrashes.
#
# What it does:
#   1. installs zram-tools (apt) if missing
#   2. writes /etc/default/zramswap (ALGO=zstd, PERCENT=50, PRIORITY=100)
#      — never clobbers an existing file unless --force
#   3. enables + restarts zramswap (package postinst starts it with the
#      default 256 MiB device; the real config must be written FIRST)
#   4. writes /etc/sysctl.d/99-zram.conf (vm.swappiness=150) + applies it
#   5. verifies: swapon --show, zramctl, sysctl vm.swappiness
#
# Needs root: re-execs via pkexec (GUI polkit prompt) or sudo on headless.
# NOTE: keep the disk swapfile as a fallback — zram is the fast tier, the
# disk swap is the safety net once zram fills.
set -euo pipefail

# ---- re-exec as root (pkexec preferred, sudo fallback) ----------------------
if [ "$(id -u)" -ne 0 ]; then
  if command -v pkexec >/dev/null 2>&1; then
    exec pkexec "$0" "$@"
  else
    exec sudo "$0" "$@"
  fi
fi

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }

ZRAM_CONF=/etc/default/zramswap
SYSCTL_CONF=/etc/sysctl.d/99-zram.conf
REPO_CONF="ALGO=zstd
PERCENT=50
PRIORITY=100
"

# ---- 1. zram-tools -----------------------------------------------------------
if ! command -v zramswap >/dev/null 2>&1; then
  log "zram-tools missing — installing"
  apt-get install -y zram-tools
else
  log "zram-tools present"
fi

# ---- 2. /etc/default/zramswap -------------------------------------------------
log "Configuring $ZRAM_CONF"
if [ ! -f "$ZRAM_CONF" ]; then
  printf '%s' "$REPO_CONF" > "$ZRAM_CONF"
  echo "  wrote repo default (zstd / 50% / priority 100)"
elif [ "$FORCE" = 1 ]; then
  printf '%s' "$REPO_CONF" > "$ZRAM_CONF"
  echo "  overwrote (--force)"
elif cmp -s <(printf '%s' "$REPO_CONF") "$ZRAM_CONF"; then
  echo "  in sync with repo (zstd / 50% / priority 100)"
else
  warn "existing $ZRAM_CONF differs from repo default — keeping yours:"
  diff -u <(printf '%s' "$REPO_CONF") "$ZRAM_CONF" | sed 's/^/  /' || true
  warn "re-run with --force to apply the repo default"
fi

# ---- 3. zramswap service ------------------------------------------------------
log "Enabling + (re)starting zramswap"
systemctl enable zramswap >/dev/null 2>&1 || true
systemctl restart zramswap

# ---- 4. swappiness -------------------------------------------------------------
log "Setting vm.swappiness=150 ($SYSCTL_CONF)"
if ! grep -q '^vm.swappiness=150$' "$SYSCTL_CONF" 2>/dev/null || [ "$FORCE" = 1 ]; then
  printf 'vm.swappiness=150\n' > "$SYSCTL_CONF"
fi
sysctl -w vm.swappiness=150 >/dev/null

# ---- 5. verify -----------------------------------------------------------------
log "Verifying"
swapon --show
zramctl
echo "  vm.swappiness = $(sysctl -n vm.swappiness)"
