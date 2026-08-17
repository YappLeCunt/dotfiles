# hardware/ — CPU quarantine kit for the degraded core

Core 1 (CPUs 2/3) of this IdeaPad's Ryzen 7 4800H is physically degraded —
it segfaults tasks and hard-freezes the box on both Windows and Linux.
This kit keeps the damage contained.

| File | Installed to | Effect |
|---|---|---|
| `disable-badcore-initramfs` | `/etc/initramfs-tools/scripts/init-premount/disable-badcore` | Offlines CPUs 2,3 inside the initramfs, before the real root is mounted — the earliest possible point |
| `disable-badcore.service` | `/etc/systemd/system/` | Offlines CPUs 2,3 in the real root (backup for when the initramfs hook hasn't been rebuilt yet) |
| `throttle-badcore.service` | `/etc/systemd/system/` | Alternative: keep CPUs 2,3 online but cap them at base clock 2.9 GHz |
| `guard-cpu-quarantine.sh` | `/usr/local/sbin/` | DMI machine guard (LENOVO / 82EY / serial PF2N8WGV) — `ExecStartPre` for both units; the initramfs hook embeds the same check inline |
| `heartbeat.sh` | `~/testwindow/heartbeat.sh` | Test-window logger: `epoch \| wallclock \| uptime \| online-CPU list` every 20s |

## Install — quarantine (recommended while core 1 is unstable)

```sh
sudo cp hardware/disable-badcore-initramfs /etc/initramfs-tools/scripts/init-premount/disable-badcore
sudo chmod +x /etc/initramfs-tools/scripts/init-premount/disable-badcore
sudo update-initramfs -u
sudo cp hardware/guard-cpu-quarantine.sh /usr/local/sbin/
sudo chmod +x /usr/local/sbin/guard-cpu-quarantine.sh
sudo cp hardware/disable-badcore.service /etc/systemd/system/
sudo systemctl enable --now disable-badcore.service
```

## Install — throttle (want the core available but capped)

Stop and disable `disable-badcore.service` first, then:

```sh
sudo cp hardware/guard-cpu-quarantine.sh /usr/local/sbin/
sudo chmod +x /usr/local/sbin/guard-cpu-quarantine.sh
sudo cp hardware/throttle-badcore.service /etc/systemd/system/
sudo systemctl enable --now throttle-badcore.service
```

## Safety — machine guard

Both the initramfs hook and the systemd units verify the DMI identity of
this exact laptop before touching any CPU: `sys_vendor` = LENOVO,
`product_name` = 82EY (IdeaPad Gaming 3 15ARH05), `product_serial` =
PF2N8WGV. On any other machine:

- the systemd services **fail before running** — `ExecStartPre` exits
  non-zero, `ExecStart` never runs, CPUs stay untouched
  (`systemctl status disable-badcore` shows the guard's refusal);
- the initramfs hook prints a warning to the console and skips.

If the motherboard or machine is ever replaced, update the three values in
`guard-cpu-quarantine.sh` and in the initramfs hook before re-applying.

## Notes

- **`amd_pstate=passive` on the kernel cmdline is REQUIRED** for the throttle
  caps to hold. With `acpi-cpufreq`, `scaling_max_freq` is a paper cap — the
  silicon boosts to ~4.26 GHz anyway (verified with turbostat).
- Verify quarantine: `cat /sys/devices/system/cpu/online` → `0-1,4-15`
  (CPUs 2 and 3 gone). Verify throttle: `cat /sys/devices/system/cpu/cpu2/cpufreq/scaling_max_freq` → `2900000`.
- `heartbeat.sh` is a test-window tool: `tail -5 ~/testwindow/install-heartbeat.log`
  — a gap in lines plus an uptime reset means the box crashed.
