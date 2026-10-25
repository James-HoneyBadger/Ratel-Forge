# Ratel Forge — User Guide

Ratel Forge configures a complete development and desktop environment on a Linux
system you already run. This guide covers day-to-day use; see the
[README](README.md) for the full option reference.

## Before you start

- A supported Linux installation (see below)
- A regular user account with `sudo` (or `wheel`) privileges
- Outbound network access
- Free disk space: 1 GB for minimal, 3 GB for desktop/developer, 5 GB for full

Do **not** run the installer as root. It requests privileged access per step.

## Supported distributions

| Family | Distributions |
|--------|---------------|
| Arch | Arch, Manjaro, EndeavourOS, ArcoLinux, Artix |
| Debian | Debian, Ubuntu, Linux Mint, Pop!\_OS, Elementary, Zorin, Kali |
| Fedora | Fedora, RHEL, CentOS, AlmaLinux, Rocky Linux |
| Gentoo | Gentoo, Funtoo |
| openSUSE | Tumbleweed, Leap, SLES, GeckoLinux |
| Void | Void Linux (glibc and musl) |
| Slackware | Slackware, Salix |

## Install

```bash
git clone https://github.com/James-HoneyBadger/Ratel-Forge.git
cd Ratel-Forge
./install.sh
```

The installer checks the environment, detects the distribution, asks for an
install type, shows a summary, and then provisions the machine. Everything is
logged.

### Choosing a type

| Type | Disk | Best for |
|------|------|----------|
| Full | 3–5 GB | A workstation with everything configured |
| Developer | 2–3 GB | Languages, containers, editors, XFCE core |
| Desktop | 2–3 GB | A themed XFCE desktop with productivity apps |
| Minimal | 0.5–1 GB | Servers: CLI tools only |

You can skip the menu with `--type`:

```bash
./install.sh --type developer
```

### Checking the environment first

```bash
./install.sh --check
```

Reports network, disk space, sudo access, and whether the distribution is
supported — without installing anything.

### Previewing changes

```bash
./install.sh --type full --dry-run
```

Dry-run suppresses privileged commands **and** user-level file writes, so it is
safe to run on a live system.

### Unattended installs

```bash
./install.sh --type minimal --yes
```

For CI, set `HONEY_BADGER_NONINTERACTIVE=1`, `HONEY_BADGER_INSTALL_TYPE`, and
optionally `HONEY_BADGER_GIT_USERNAME`/`HONEY_BADGER_GIT_EMAIL`.

### Resuming an interrupted run

Every major unit of work is a phase. If a run stops partway, continue from where
it left off:

```bash
./install.sh --type full --resume
```

Only completed phases are skipped, and resume state from a different distro or
install type is discarded automatically.

### Choosing package groups

`--type` sets the baseline; `--components` narrows it:

```bash
./install.sh --type full --components base,dev
./install.sh --type full --components base,desktop,apps
```

Components are `base`, `dev`, `desktop`, and `apps`. Omitting `base` skips core
utilities, so include it unless you know you have them already.

### Skipping components

```bash
./install.sh --skip-docker --skip-node --skip-git
```

Available: `--skip-docker`, `--skip-python`, `--skip-node`, `--skip-nano`,
`--skip-theme`, `--skip-git`.

### Accessibility and terminals

- `--ascii` replaces Unicode glyphs for terminals without UTF-8 support
- `--no-color` (or `NO_COLOR=1`) disables colour entirely
- `--quiet` shows errors only; `--verbose` adds debug detail
- `--no-banner` omits the header

## After installation

### Utility commands

```bash
honey-badger-info                     # system, hardware, and install details
honey-badger-update                   # update packages, Flatpak, Snap; clean cache
honey-badger-install ripgrep          # install packages with the native manager
honey-badger-theme status             # active theme, icons, wallpaper
honey-badger-theme palette            # print the palette with swatches
honey-badger-theme apply              # re-apply the theme live
honey-badger-theme apply high-contrast
honey-badger-doctor                   # diagnose theme/settings/runtime issues
```

All are in `~/.local/bin` (added to `PATH` in `~/.bashrc`).

### What changed

| Area | Location |
|------|----------|
| Packages | Installed with the native package manager |
| Nano | `~/.nanorc`, `~/.nano/backups` |
| Shell | `PATH` entries and editor defaults in `~/.bashrc` |
| Git | `~/.gitconfig` (only if no identity was set) |
| Theme | `~/.themes/Ratel`, `/usr/share/themes/Ratel`, `~/.icons/Ratel` |
| GTK settings | `~/.config/gtk-3.0/settings.ini`, `~/.gtkrc-2.0` |
| XFCE | `~/.config/xfce4/xfconf/xfce-perchannel-xml/{xsettings,xfwm4}.xml` |
| LightDM | `/etc/lightdm/lightdm.conf`, `lightdm-gtk-greeter.conf` |
| Wallpaper | `/usr/share/backgrounds/honeybadger.jpg` |
| Utilities | `~/.local/bin/honey-badger-*`, `~/.local/share/honey-badger/` |

Backups of overwritten user files are kept beside the originals with a
`.hb-backup` suffix.

### Rebooting

Desktop types: `sudo reboot` to start LightDM with the new theme.
Minimal: `source ~/.bashrc` (or open a new terminal).

## The desktop theme

The Ratel theme is a warm dark theme designed for long sessions:

- Espresso surfaces (`#16120d` / `#201a14`) instead of pure black
- Honey accent (`#e6a92e`) for selection, focus, and progress
- Warm off-white text (`#f3ebdf`) with muted sand secondary text (`#b8a992`)
- Squared-off 4–6 px radii, slim scrollbars, 2 px focus rings

It applies to GTK3 and GTK2 applications, the XFCE panel and window manager
chrome, and the LightDM greeter.

### High contrast and font size

```bash
./install.sh --type desktop --high-contrast
./install.sh --type desktop --font-size 13
```

`Ratel-HC` uses pure-black surfaces, thicker borders, and 3 px focus rings, with
every foreground at AAA contrast. Both variants are installed, so you can switch
later:

```bash
honey-badger-theme apply high-contrast
honey-badger-theme apply default
```

`--font-size` sets both the interface and monospace fonts (8–24 px). To use
different font families, set `HONEY_BADGER_FONT` and `HONEY_BADGER_MONO_FONT`.

### Changing the palette

Edit `config/honey-badger-os.conf` before installing, or override at runtime:

```bash
HONEY_BADGER_THEME_ACCENT="#4f9cf0" ./install.sh --type desktop
```

The wallpaper is generated from the same palette at the size given by
`HONEY_BADGER_WALLPAPER_SIZE` (default `1920x1080`).

## Changing what gets installed

Package lists live in `config/packages/<family>.conf`. Each section becomes an
array of the same name:

```
[BASE_PACKAGES]
curl
wget
```

Add or remove one entry per line, then run the installer again — provisioning is
idempotent. Entries may contain spaces (snap flags such as `code --classic`).

## Logs and diagnostics

- Per-run logs: `~/.local/share/honey-badger/logs/` (last 5 kept)
- Universal installer log: `~/.local/share/honey-badger/logs/honeybadger-install-*.log`
- Machine-readable summary: `/tmp/honeybadger-summary.json`
- Checkpoint: `~/.local/share/honey-badger/checkpoint` (informational; installs
  are idempotent, so re-running converges)
- Rollback manifest: `~/.local/share/honey-badger/rollback-manifest`

## Troubleshooting

| Symptom | Resolution |
|---------|------------|
| `Do not run this installer as root` | Run `./install.sh` as your user |
| `No network connectivity detected` | Verify DNS and HTTPS egress; the probe tries DNS, `host`, `ping`, then `curl` |
| `Insufficient disk space` | Use a smaller type; `--check` reports free space |
| `Unsupported distribution` | Open an issue with the output of `cat /etc/os-release` |
| Theme unchanged after install | Log out and back in; confirm the `xsettings.xml` file exists |
| Docker permission errors | Log out and back in so the group membership applies |
| Fonts look wrong after install | Run `honey-badger-theme apply`, then log out and back in |
| An interrupt left the machine half-configured | Re-run with `--resume` |
| Unsure what is broken | Run `honey-badger-doctor` |

## Uninstalling

```bash
bash uninstall.sh            # interactive
bash uninstall.sh --dry-run  # preview
```

Removes Ratel Forge files, the user and system theme, and restores `.hb-backup`
originals. System packages are intentionally left for your package manager:

```bash
sudo apt remove ...      # Debian/Ubuntu
sudo pacman -Rns ...     # Arch
```

## Getting help

- `./install.sh --help` — every option and environment variable
- `./install.sh --list-types` — install profiles
- [README](README.md) — architecture, security model, contributing
