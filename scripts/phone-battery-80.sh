#!/usr/bin/env bash
# phone-battery-80.sh — desktop notification when the phone crosses a charge
# level while charging. Edge-triggered (fires on the upward crossing, not on
# every poll) with a cooldown so hover-oscillation can't spam.
#
# Data source: KDE Connect's D-Bus battery interface (Linux-only — the
# kdeconnect-cli has no battery flag, and Windows/macOS expose no battery
# API at all; for those use phone-side automation, e.g. Tasker).
#
# Schedule: run every 5 minutes — systemd user timer, cron, or a Hermes cron
# job. Quiet unless the threshold is crossed. Re-arms when the charge drops
# below the threshold (or stops charging).
#
# Usage:
#   phone-battery-80.sh [threshold]      # default 80
#   PHONE_DEVICE_ID=<id> phone-battery-80.sh
set -euo pipefail

THRESHOLD="${1:-80}"
COOLDOWN_SECS=1800                      # min gap between notifications
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/phone-battery-80.state"

# Resolve the device id: env override, else first paired+reachable device
DEVICE_ID="${PHONE_DEVICE_ID:-}"
if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID="$(kdeconnect-cli -l --id-only 2>/dev/null | head -1 || true)"
fi
[ -n "$DEVICE_ID" ] || { echo "phone-battery-80: no paired device found"; exit 0; }

# ---- read battery state via D-Bus ------------------------------------------
OBJ="/modules/kdeconnect/devices/$DEVICE_ID/battery"
IFACE="org.kde.kdeconnect.device.battery"
read_charge() {
  gdbus call --session --dest org.kde.kdeconnect --object-path "$OBJ" \
    --method org.freedesktop.DBus.Properties.Get "$IFACE" charge 2>/dev/null \
    | grep -oE '[0-9]+' || echo -1
}
read_charging() {
  gdbus call --session --dest org.kde.kdeconnect --object-path "$OBJ" \
    --method org.freedesktop.DBus.Properties.Get "$IFACE" isCharging 2>/dev/null \
    | grep -oiE 'true|false' || echo false
}

CHARGE="$(read_charge)"
CHARGING="$(read_charging)"
[ "$CHARGE" -ge 0 ] 2>/dev/null || { echo "phone-battery-80: battery unknown (phone offline?)"; exit 0; }

# ---- state: last charge + last notify time ----------------------------------
mkdir -p "$(dirname "$STATE_FILE")"
LAST_CHARGE="$(awk -F= '/^charge=/{print $2}' "$STATE_FILE" 2>/dev/null || echo 0)"
LAST_NOTIFY="$(awk -F= '/^notify=/{print $2}' "$STATE_FILE" 2>/dev/null || echo 0)"
NOW="$(date +%s)"

# ---- edge trigger: charging AND crossed threshold upward --------------------
NOTIFY=0
if [ "$CHARGING" = "true" ] && [ "$CHARGE" -ge "$THRESHOLD" ] \
   && [ "$LAST_CHARGE" -lt "$THRESHOLD" ] \
   && [ $(( NOW - LAST_NOTIFY )) -ge "$COOLDOWN_SECS" ]; then
  NOTIFY=1
fi

printf 'charge=%s\nnotify=%s\n' "$CHARGE" "$NOW" > "$STATE_FILE"

if [ "$NOTIFY" -eq 1 ]; then
  NAME="$(kdeconnect-cli -l --id-name-only 2>/dev/null | grep "$DEVICE_ID" | head -1 | cut -d: -f1 || echo Phone)"
  notify-send -i battery-full-charging-symbolic \
    "$NAME at $CHARGE%" \
    "Unplug for battery health" \
    -h string:x-canonical-private-synchronous:phone-battery
  echo "notified: $NAME at $CHARGE%"
fi
