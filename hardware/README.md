# hardware/ — CPU quarantine kit for the degraded core

Core 1 (CPUs 2/3) of this IdeaPad's Ryzen 7 4800H is physically degraded —
it segfaults tasks and hard-freezes the box on both Windows and Linux.
This kit keeps the damage contained.

| File | Installed to | Effect |
|---|---|---|
| `disable-badcore-initramfs` | `/etc/initramfs-tools/scripts/init-premount/disable-badcore` | Offlines CPUs 2,3 inside the initramfs, before the real root is mounted — the earliest possible point |
| `disable-badcore.service` | `/etc/systemd/system/` | Offlines CPUs 2,3 in the real root (backup for when the initramfs hook hasn't been rebuilt yet) |
| `throttle-badcore.service` | `/etc/systemd/system/` | Alternative: keep CPUs 2,3 online but cap them at base clock 2.9 GHz |
| `heartbeat.sh` | `~/testwindow/heartbeat.sh` | Test-window logger: `epoch \| wallclock \| uptime \| online-CPU list` every 20s |

## Install — quarantine (recommended while core 1 is unstable)

```sh
sudo cp hardware/disable-badcore-initramfs /etc/initramfs-tools/scripts/init-premount/disable-badcore
sudo chmod +x /etc/initramfs-tools/scripts/init-premount/disable-badcore
sudo update-initramfs -u
sudo cp hardware/disable-badcore.service /etc/systemd/system/
sudo systemctl enable --now disable-badcore.service
```

## Install — throttle (want the core available but capped)

Stop and disable `disable-badcore.service` first, then:

```sh
sudo cp hardware/throttle-badcore.service /etc/systemd/system/
sudo systemctl enable --now throttle-badcore.service
```

## Notes

- **`amd_pstate=passive` on the kernel cmdline is REQUIRED** for the throttle
  caps to hold. With `acpi-cpufreq`, `scaling_max_freq` is a paper cap — the
  silicon boosts to ~4.26 GHz anyway (verified with turbostat).
- Verify quarantine: `cat /sys/devices/system/cpu/online` → `0-1,4-15`
  (CPUs 2 and 3 gone). Verify throttle: `cat /sys/devices/system/cpu/cpu2/cpufreq/scaling_max_freq` → `2900000`.
- `heartbeat.sh` is a test-window tool: `tail -5 ~/testwindow/install-heartbeat.log`
  — a gap in lines plus an uptime reset means the box crashed.
