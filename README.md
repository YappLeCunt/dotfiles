# dotfiles

Reproducible setup for this Ubuntu 24.04 / GNOME 46 box (Lenovo IdeaPad
Gaming 3 15ARH05, Ryzen 7 4800H, NVIDIA GTX 1650 Ti + AMD Renoir iGPU).

## Fresh-machine quick start

```sh
git clone git@github.com:YappLeCunt/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh                 # symlink home/ -> ~ (never clobbers; --dry-run first)
./scripts/install-fonts.sh   # JetBrainsMono Nerd Font + Inter (no sudo)
./setup-ghostty-defaults.sh  # Ctrl+Alt+T -> Ghostty (2 pkexec prompts)
./setup-gnome-defaults.sh    # dconf defaults (desktop animations ON)
./setup-gnome-extensions.sh  # GNOME extensions (clipboard indicator)
./setup-normcap-defaults.sh  # NormCap flatpak OCR fix + neutral border (no sudo)
~/.local/bin/vlc-windows-look.sh   # VLC flatpak, Windows look (1 pkexec if flatpak missing)
~/.local/bin/monitor-prefs --status   # verify refresh-rate prefs (auto-applied every login)
```

Then handle the non-dotfile bits (see `packages.txt`): apt installs
(`git curl gh ghostty flatpak fzf`), `flatpak install org.videolan.VLC
com.github.dynobo.normcap eu.betterbird.Betterbird`,
starship installer, `git clone --depth 1
junegunn/fzf.git ~/.fzf`, ble.sh build, and copy Segoe UI from a Windows
install (proprietary — never vendored here). Finally, on this laptop, apply
the CPU-quarantine kit (`hardware/README.md`).

## Layout

Dotfiles are **layered by platform** — `install.sh` picks the active layers
and symlinks each path from the deepest layer that provides it (a GNOME
override of a Linux file wins over the Linux copy, which wins over the
all-OS copy). Detection: `uname` for Linux, `$XDG_CURRENT_DESKTOP` for the
DE (with a `pgrep` fallback for SSH sessions). Re-running after a layer
change re-points our own symlinks; real files are never clobbered.

| Path | Purpose |
|---|---|
| `home/` | Layer 0 — **ALL-OS** (starship.toml, .gitconfig). Always active. |
| `home-linux/` | Layer 1 — **Linux** (.bashrc + ble.sh, fontconfig, flatpak scripts). Active on Linux. |
| `home-gnome/` | Layer 2 — **GNOME DE** (GNOME-specific configs). Active when GNOME is running. |
| `home-kde/` | Layer 2 — **KDE DE** (KDE Connect config etc.). Active when KDE is running. |
| `ghostty/config` | Ghostty config → `~/.config/ghostty/config` (step 4 of setup script) |
| `setup-ghostty-defaults.sh` | Idempotent: Ghostty as default terminal (x-terminal-emulator alt + Ctrl+Alt+T via gsettings) |
| `setup-gnome-defaults.sh` | Idempotent: dconf defaults (desktop animations ON, Blur prefs) |
| `setup-gnome-extensions.sh` | Idempotent: installs/enables GNOME extensions from EGO (clipboard indicator, Blur my Shell); merges `enabled-extensions`, never clobbers |
| `blur-my-shell/settings.dconf` | Blur my Shell dconf settings (glass pipelines, bright alt-tab; dock blur OFF — ubuntu-dock keeps its own look) — applied by setup-gnome-defaults.sh |
| `dash-to-dock/settings.dconf` | Ubuntu Dock dconf settings (bottom dock, white dots, external-monitor preference) — applied by setup-gnome-defaults.sh |
| `desktop/Dock Settings.desktop` | Dock Settings launcher — copied to `~/Desktop` by install.sh **only when desktop icons (ding) are enabled**; copied not symlinked (gvfs trusted flag is per-path) |
| `setup-normcap-defaults.sh` | Idempotent: NormCap flatpak OCR fix (tessdata bugs) + neutral capture border; config in `normcap/settings.conf` |
| `normcap/settings.conf` | Canonical NormCap config (border `#48484A`); **copied** into the sandbox dir, not symlinked (see NormCap section) |
| `scripts/install-fonts.sh` | Fetches JetBrainsMono Nerd Font + Inter |
| `home/.local/bin/monitor-prefs` | EDID-keyed refresh-rate restorer — survives connector renames (prime-select/MUX/dock); rules `home/.config/monitor-prefs`, autostart `home-linux/.config/autostart/monitor-prefs.desktop` |
| `packages.txt` | Curated apt / flatpak / manual package manifest |
| `hardware/` | CPU-quarantine kit for the degraded core 1 (initramfs hook + systemd units + heartbeat) |

## Shell: bash + ble.sh + starship + fzf

Mirrors the old Windows PowerShell (PSReadLine + PSFzf) muscle memory:

- `home/.bashrc` — loads ble.sh **before** starship (starship must init after
  ble so it uses ble's PRECMD hook). PATH lines use `$HOME` — portable. The
  one remaining hardcoded path is `downloads-notify.desktop`'s `Exec`
  (freedesktop does not expand `$HOME` there) — adjust the username on
  another machine.
- `home/.blerc` — ghost-text autosuggestions (dim gray, like PSReadLine
  InlinePrediction), Tab = menu completion, ↑/↓ = history search on a typed
  prefix, fzf completion + key bindings. `_ble_contrib_fzf_base=$HOME/.fzf`
  is required because fzf lives in `~/.local/bin` and auto-detect misses it.
- `home/.config/starship.toml` — minimal quiet prompt; repo name is the only
  bright element, git state is the only thing allowed to shout.

## Fonts

- **Segoe UI** (UI + docs, 11pt) — from a Windows install; `fonts.conf`
  routes sans-serif → Segoe UI (strong) with Inter as weak fallback.
  **Inter must stay weak** or the system conf.d rules (56/60-latin) win.
- **JetBrainsMono Nerd Font Mono 13pt** — terminal + monospace.
- `home/.config/fontconfig/fonts.conf` — Segoe UI alias + ClearType-style
  subpixel rendering (embedded bytecode hinting, not autohinter).
- `vlc-windows-look.sh` additionally writes `~/.config/fontconfig/vlc-fonts.conf`
  (Inter wins inside the VLC sandbox; overrides placed after conf.d include).

## VLC (flatpak)

`home/.local/bin/vlc-windows-look.sh` — idempotent, user-level: installs VLC
from Flathub, sets `QT_STYLE_OVERRIDE=fusion` (flat Windows widgets) and
`FONTCONFIG_FILE` to the VLC-specific config, installs Inter static fonts,
verifies with sandboxed `fc-match`.

## NormCap (flatpak)

`setup-normcap-defaults.sh` — idempotent, user-level. The NormCap 0.6.0
flatpak ships two broken tesseract bits that make OCR silently return
nothing:

1. Manifest env `TESSDATA_PREFIX=/app/share`, but the traineddata lives at
   `/app/share/tessdata/` → tesseract can't load *any* language.
2. Its bundled tessdata resources are empty, so the first-run copy into the
   config dir writes a **0-byte** `eng.traineddata`, which NormCap then
   passes via `--tessdata-dir` → fails even with the env fixed.

The script applies `flatpak override --user --env=TESSDATA_PREFIX=/app/share/tessdata`,
replaces the 0-byte traineddata from inside the sandbox, copies
`normcap/settings.conf` (border `#48484A`, neutral dark gray) into
`~/.var/app/com.github.dynobo.normcap/config/normcap/`, and verifies with
sandboxed `tesseract --list-langs` → `eng`.

Note: the settings file is a plain **copy**, not a symlink to this repo —
the flatpak sandbox doesn't mount `~/dotfiles`, so a symlink would be
invisible to the app. If you change the border color in the GUI, re-run the
script (it keeps your file and shows a diff) or copy the new value into
`normcap/settings.conf`.

## GNOME extensions

`setup-gnome-extensions.sh` — idempotent: installs **Clipboard Indicator**
(clipboard history in the top bar) and **Blur my Shell** from
extensions.gnome.org, then merges them into `enabled-extensions` without
touching anything already on the list. Clipboard Indicator was chosen over
the newer "Clipboard History" extension (SUPERCILEX) after an A/B test —
image previews were broken on X11 and the tray icon mis-scaled.

## Phone link: KDE Connect

The phone link is **KDE Connect** (the real one, not GSConnect — GSConnect
was retired after the notification mirror kept re-spamming the same
ColorOS persistent notifications on every reconnect; KDE Connect's
desktop side updates notifications in place and syncs dismissal back to
the phone). Install with `sudo apt install kdeconnect`; the daemon
auto-starts via `/etc/xdg/autostart`. Pair from the tray icon or:

    kdeconnect-cli -l                    # list devices
    kdeconnect-cli -d <id> --pair        # send pair request to the phone

Same Android app either way (KDE Connect for Android). Device certs and
pairing state live in `~/.config/kdeconnect/` and are deliberately NOT
versioned — machine-specific, and re-pairing takes seconds on a fresh box.

**Blur my Shell** (`blur-my-shell@aunetx`) adds frosted glass to the panel,
overview, and alt-tab (custom bright pipeline — the default 0.6 brightness
reads as "still dark"). The dock is deliberately NOT blurred: blur-my-shell's
dash-to-dock styling fights ubuntu-dock's own background (double dark
background = "ruined" dock), so it's disabled in `blur-my-shell/settings.dconf`.
Settings are applied by `setup-gnome-defaults.sh`; the whole subtree is
portable (no certs/device IDs).

With a shell session running, the script asks the shell to install via
`org.gnome.Shell.Extensions.InstallRemoteExtension` — registered and
active immediately. Headless (SSH / fresh boot before login) it falls
back to a direct EGO zip + `glib-compile-schemas`, which the shell picks
up after Alt+F2 r or logout/login.

## Email: Betterbird (flatpak)

User-level install from Flathub (`eu.betterbird.Betterbird`, ESR line
140.x). Thunderbird was trialed alongside it and dropped — Betterbird is
the daily driver. Profile lives under `~/.var/app/eu.betterbird.Betterbird/`.

## Hermes desktop entry

The dock icon (`~/.local/share/applications/hermes.desktop`, generated by
`hermes desktop`) points straight at the app — no wrapper. The desktop app
holds a single-instance lock and a second launch focuses the running window
instead of spawning a duplicate backend (`reapOrphans` fix, issue #87295),
so a focus-or-launch wrapper is no longer needed.

## Monitor refresh rates (monitor-prefs)

GNOME keys saved display settings on the RandR **connector name**
(`HDMI-0`, `eDP-1-0`, ...), which changes whenever the GPU driving the
port changes — `prime-select` on-demand ↔ nvidia renamed this box's
external port `HDMI-1-0` → `HDMI-0`, silently dropping the monitor from
75 Hz to its preferred 60 Hz. Symptom: "the desktop feels slower after
switching GPU modes" — nothing in Settings shows a problem.

`home/.local/bin/monitor-prefs` kills that class of bug by keying on the
monitor's **EDID identity** (vendor:product — stable across connector
renames, MUX flips, and docks) and re-applying the saved refresh rate:

    monitor-prefs --status              # show outputs, identities, prefs
    monitor-prefs --apply               # restore rates (autostarts every login)
    monitor-prefs --sync-monitors-xml   # fix GNOME's saved connector names

Rules live in `~/.config/monitor-prefs` (symlinked from `home/.config/`).
X11 applies live via xrandr; Wayland uses `gnome-randr` if installed,
otherwise syncs `monitors.xml` for the next login; macOS is best-effort
via `displayplacer` (append a `:UUID` to each rule from `displayplacer list`).

## Hardware (this laptop only)

`hardware/` — core 1 (CPUs 2/3) is physically degraded; the kit offlines it
in the initramfs (earliest possible point) with a systemd backup, or
optionally throttles it to 2.9 GHz. `amd_pstate=passive` is required for
throttle caps to hold. Full docs: `hardware/README.md`.

## Notes / caveats

- `install.sh` is additive only: it never overwrites an existing file, it
  prints `SKIP` and moves on (symlinks pointing into this repo get
  re-pointed when they move layers). Files here are byte-identical to the
  live configs, so `git diff` stays meaningful after editing either side.
- Nautilus "Open in Terminal" on Ubuntu 24.04 is hardcoded to GNOME Terminal
  (nautilus-extension-gnome-terminal); install `nautilus-open-any-terminal`
  for that menu to launch Ghostty.
- `org.gnome.desktop.default-applications.terminal` is deprecated but kept
  for legacy tooling.
- Nothing secret lives here: no tokens, keys, or credentials. The repo is
  **public** (since Aug 2026) — treat every future commit as public; commit
  emails use the GitHub noreply address; secret scanning + push protection
  are enabled on the repo.
