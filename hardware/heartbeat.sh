#!/bin/bash
# Heartbeat logger for the CPU-quarantine test window.
# Writes one line every 20s: epoch | wallclock | uptime(sec) | online-CPU list.
# Read the result with:  tail -5 ~/testwindow/install-heartbeat.log
#   - every 20s, uptime growing, online=0-1,4-15  -> clean window
#   - gap in lines + uptime reset                  -> it crashed/rebooted
LOG="$HOME/testwindow/install-heartbeat.log"
mkdir -p "$(dirname "$LOG")"
echo "# heartbeat start $(date '+%F %T')" >> "$LOG"
while true; do
  echo "$(date +%s) | $(date '+%F %T') | up=$(awk '{print int($1)}' /proc/uptime)s | online=$(cat /sys/devices/system/cpu/online)" >> "$LOG"
  sleep 20
done
