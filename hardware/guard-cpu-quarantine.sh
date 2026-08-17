#!/bin/sh
# guard-cpu-quarantine.sh — refuse to run the CPU-quarantine kit on anything
# but THIS laptop. Machine identity: LENOVO 82EY (IdeaPad Gaming 3 15ARH05),
# product serial PF2N8WGV. A mismatch means the kit landed on a healthy
# machine — die loudly instead of silently offlining a working core.
# Used as ExecStartPre in hardware/disable-badcore.service and
# hardware/throttle-badcore.service; systemd skips ExecStart when this exits
# non-zero. The initramfs hook embeds the same check inline.

die() { echo "guard-cpu-quarantine: $*" >&2; exit 1; }

match() { # match <sysfs-path> <expected-value>
    [ -r "$1" ] || die "cannot read $1"
    val="$(cat "$1")"
    [ "$val" = "$2" ] || die "DMI mismatch: $1 is '$val', expected '$2' — not touching CPUs"
}

match /sys/class/dmi/id/sys_vendor LENOVO
match /sys/class/dmi/id/product_name 82EY
match /sys/class/dmi/id/product_serial PF2N8WGV

exit 0
