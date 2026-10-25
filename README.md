<img src="assets/ratel-logo.svg" width="88" alt="Ratel logo">

# 🦡 Ratel Forge

**Fearless Linux provisioning — one command, seven distribution families, a coherent desktop.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](#)
[![Platforms](https://img.shields.io/badge/Distros-7%20families-amber)](#supported-distributions)

Ratel turns a fresh Linux installation into a complete development and desktop
environment: toolchains, containers, editors, a themed XFCE session, and a set
of small utilities that make the machine pleasant to live in.

It is **not a distribution**. It runs on top of the distro you already trust —
detecting what it is, then applying the right package manager, service manager,
and desktop conventions.

> Formerly **Honey Badger OS**. The name changed to Ratel — the honey badger's
> proper common name — because this project provides a provisioning framework,
> not an operating system. Environment variables (`HONEY_BADGER_*`) and command
> names (`honey-badger-*`) are unchanged for compatibility.

---

## Contents

- [Supported distributions](#supported-distributions)
- [Quick start](#quick-start)
- [Install types](#install-types)
- [Command-line reference](#command-line-reference)
- [Package manifests](#package-manifests)
- [What gets installed](#what-gets-installed)
- [Look and feel](#look-and-feel)
- [Utility commands](#utility-commands)
- [Architecture](#architecture)
- [Testing](#testing)
- [Security model](#security-model)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Supported distributions

| Family | Distributions | Package manager | Init |
|--------|---------------|-----------------|------|
| **Arch** | Arch, Manjaro, EndeavourOS, ArcoLinux, Artix | `pacman` | systemd |
| **Debian** | Debian, Ubuntu, Mint, Pop!\_OS, Elementary, Zorin, Kali | `apt` | systemd |
| **Fedora** | Fedora, RHEL, CentOS, AlmaLinux, Rocky Linux | `dnf` | systemd |
| **Gentoo** | Gentoo, Funtoo | `emerge` | OpenRC / systemd |
| **openSUSE** | Tumbleweed, Leap, SLES, GeckoLinux | `zypper` | systemd |
| **Void** | Void Linux (glibc and musl) | `xbps` | runit |
| **Slackware** | Slackware, Salix | `slackpkg` | SysV init |

Detection uses `/etc/os-release` first, then `ID_LIKE`, then the available
package manager, then well-known release files — so derivatives usually work
without an explicit entry.

## Quick start

```bash
git clone https://github.com/James-HoneyBadger/Ratel-Forge.git
cd Ratel-Forge
./install.sh
```

The installer will:

1. Check network, disk space, sudo access, and repository layout
2. Detect your distribution family
3. Let you choose an install type (or read `--type`)
4. Show a summary and ask for confirmation
5. Hand off to the matching provisioner and log everything

Run as your normal user — **not** with `sudo ./install.sh`. Privileged steps are
requested individually.

### Preview without changing anything

```bash
./install.sh --type full --dry-run
```

Dry runs are truthful: user-level steps (nano config, theme files, editor
defaults, tool installs) are skipped as well as privileged ones.

### Unattended

```bash
./install.sh --type minimal --yes
```

## Install types

| Type | Disk | Includes | Best for |
|------|------|----------|----------|
| **Full** | 6–9 GB | XFCE desktop, full toolchain, containers, browsers, office, media, theme | New workstations |
| **Developer** | 2–4 GB | Languages, build tools, containers, editors, XFCE desktop (no office/media apps) | Development machines |
| **Desktop** | 3–5 GB | XFCE desktop with networking/audio/fonts, browsers, office, media, basic dev tools | Everyday desktops |
| **Minimal** | 0.3–0.8 GB | CLI tools, monitoring, nano, Ratel Forge commands — no desktop | Servers and containers |

List them at any time:

```bash
./install.sh --list-types
```

## Command-line reference

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help and exit |
| `-V, --version` | Show version and exit |
| `-t, --type TYPE` | Install type: `full`, `developer`, `desktop`, `minimal` |
| `--list-types` | Print the install types and exit |
| `-n, --dry-run` | Simulate the install without making changes |
| `-y, --yes` | Assume yes for the confirmation prompt |
| `--non-interactive` | Never prompt (requires `--type`) |
| `--check` | Run pre-flight checks only, then exit |
| `--resume` | Resume a previous run, skipping phases already completed |
| `--components LIST` | Package groups to install: `base`, `dev`, `desktop`, `apps` |
| `--high-contrast` | Use the `Ratel-HC` high-contrast theme variant |
| `--font-size PX` | Desktop font size, 8–24 (default 10) |
| `--no-banner` | Omit the banner |
| `--ascii` | Use ASCII instead of Unicode glyphs |
| `--no-color` | Disable coloured output |
| `-v, --verbose` | Show debug output |
| `-q, --quiet` | Errors only |
| `--skip-docker` | Skip Docker installation and group setup |
| `--skip-python` | Skip Python development setup |
| `--skip-node` | Skip Node.js development setup |
| `--skip-nano` | Skip nano configuration |
| `--skip-theme` | Skip theme and wallpaper installation |
| `--skip-git` | Skip Git identity configuration |

`--help`, `--version`, and `--list-types` are side-effect free: they run before
the shared library is sourced, so they never create log files or locks.

### Environment variables

| Variable | Values | Purpose |
|----------|--------|---------|
| `HONEY_BADGER_INSTALL_TYPE` | `full` \| `developer` \| `desktop` \| `minimal` | Install profile |
| `HONEY_BADGER_DRY_RUN` | `1` | Same as `--dry-run` |
| `HONEY_BADGER_NONINTERACTIVE` | `1` | Same as `--non-interactive` |
| `HONEY_BADGER_ASSUME_YES` | `1` | Same as `--yes` |
| `HONEY_BADGER_GIT_USERNAME` / `_EMAIL` | text | Git identity for unattended runs |
| `HONEY_BADGER_LOG_COUNT` | integer (5) | Rotated log files to keep |
| `HONEY_BADGER_NETWORK_TIMEOUT` | seconds (3) | Connectivity probe timeout |
| `HONEY_BADGER_WALLPAPER_SIZE` | `WxH` (1920x1080) | Generated wallpaper size |
| `HONEY_BADGER_NPM_GLOBAL_PATH` | path (`~/.npm-global`) | npm global prefix |
| `HONEY_BADGER_COMPONENTS` | `base,dev,desktop,apps` | Same as `--components` |
| `HONEY_BADGER_HIGH_CONTRAST` | `1` | Same as `--high-contrast` |
| `HONEY_BADGER_THEME_VARIANT` | `default` \| `high-contrast` | Active theme variant |
| `HONEY_BADGER_FONT` / `_MONO_FONT` | font spec | Desktop and monospace fonts |
| `HONEY_BADGER_REQUIRE_CHECKSUMS` | `1` | Fail downloads that have no SHA-256 |
| `HONEY_BADGER_DOCKER_GPG_SHA256` | hex | Expected Docker key digest |
| `HONEY_BADGER_GITHUB_CLI_KEY_SHA256` | hex | Expected GitHub CLI key digest |
| `HONEY_BADGER_VSCODE_KEY_SHA256` | hex | Expected VS Code key digest |
| `HONEY_BADGER_NODE_SETUP_SHA256` | hex | Expected NodeSource script digest |
| `HONEY_BADGER_SBOPKG_SHA256` | hex | Expected sbopkg package digest |
| `HONEY_BADGER_ASCII` | `1` | Force ASCII glyphs |
| `NO_COLOR` | any | Disable colours ([no-color.org](https://no-color.org)) |
| `CI` | `true` | Implies non-interactive |

## Package manifests

Package lists are data, not code. Each family has a manifest under
`config/packages/<family>.conf`:

```
[BASE_PACKAGES]
curl
wget
git

[SNAP_PACKAGES]
code --classic
```

Sections become arrays of the same name (`BASE_PACKAGES`, `SNAP_PACKAGES`, …),
and the provisioner loads them with `hb_load_package_manifest`. Reviewing a
package change is now a diff of a plain list, with no shell logic in the way.

## What gets installed

**Base (all types)** — `curl`, `wget`, `git`, `htop`, `neofetch`, `tmux`, `tree`,
OpenSSH, `rsync`, `nmap`, `gparted`, filesystem tools, audio utilities, and
DejaVu/Liberation/Noto fonts (including colour emoji).

**Developer** — Python 3, Node.js, Go, Rust, OpenJDK, Ruby, PHP; GCC, Clang,
CMake, Ninja, Meson, Make; Docker and Compose; PostgreSQL/MySQL clients, SQLite,
Redis; Neovim and an enhanced nano; `gh` and `git-delta`.

**Desktop** — XFCE4 with Whisker Menu and panel plugins, Thunar, LightDM, Rofi,
dmenu, notification and power management, NetworkManager applets, PulseAudio,
fonts, and disk tools (`gparted`, `ntfs-3g`, `exfatprogs`, `dosfstools`).

**Applications** — Firefox, Chromium, LibreOffice, GIMP, Inkscape, VLC,
Audacity, OBS, FFmpeg, Thunderbird, Telegram.

**Ratel layer** — the GTK2/GTK3 theme, generated wallpaper, LightDM greeter
theme, XFCE appearance settings, nano configuration, Git defaults, and the
`honey-badger-*` utilities.

## Look and feel

### Terminal

The installer uses one design system from start to finish:

```
  ╭────────────────────────────────────────────────────────────╮
  │                                                            │
  │ R A T E L   F O R G E                                      │
  │ Fearless Linux provisioning                                │
  │                                                            │
  ╰────────────────────────────────────────────────────────────╯
  🦡  v2.5.0 "Fearless" · dry-run

  ── Choose an installation type ─────────────────────────────

  1  Full  · 6-9 GB
     Everything: XFCE desktop, full development toolchain, browsers,
     office and media apps, containers, theme, and utilities.
     Best for: a new workstation you want fully set up. (recommended)

  2  Developer  · 2-4 GB
     Languages, build tools, containers, editors, and an XFCE desktop.
     Skips office suites and media applications.
     Best for: coding machines and development VMs.

  3  Desktop  · 3-5 GB
     XFCE desktop, browsers, office and media apps, plus basic dev tools.
     Best for: everyday desktops where you do not compile much.

  4  Minimal  · 0.3-0.8 GB
     CLI tools, monitoring, nano, and Ratel Forge commands. No desktop,
     audio stack, fonts, or GUI applications.
     Best for: servers, containers, and remote hosts.

  Default: 1 (Full). Type ? to show this list again.

  ? Select installation type [1-4] [1]: 2
  ✔ Selected: Developer (2-4 GB)

  ── Pre-flight checks ──────────────────────────────────────
  • Checking network connectivity…
  ✔ Network reachable
  ✔ Disk space OK (443 GB free; 4 GB required for developer)
  ✔ Repository layout OK

  ❯ [1/12] Updating system packages...
```

- Severity glyphs (`✔`, `▲`, `✖`, `•`, `❯`) with automatic ASCII fallback
- `[n/total]` progress counters from the shared library; when skip flags or
  component filters change the plan, the counter falls back to `[n]` so the
  denominator never lies
- 256-colour palette when supported, ANSI-8 fallback otherwise
- Width-aware rules clamped to 100 columns
- Timestamped, ANSI-free logs for direct provisioner runs; the universal
  installer additionally tees raw subprocess output into its own log

### Desktop theme

Ratel ships a warm, low-fatigue dark theme. Surfaces are espresso rather than
pure black, so elevation stays readable; a single honey accent carries
selection, focus, and progress.

| Token | Hex | Used for |
|-------|-----|----------|
| Background | `#16120d` | Windows |
| Surface | `#201a14` | Header bars, panels, menus |
| Base | `#12100b` | Text views, lists, inputs |
| Border | `#3a3128` | Hairlines and frames |
| Text | `#f3ebdf` | Primary foreground |
| Muted text | `#b8a992` | Secondary foreground |
| Accent | `#e6a92e` | Selection, focus, links, progress |
| On accent | `#1a1409` | Text over the accent |
| Warning / Error / Success | `#e9b44c` / `#e0685c` / `#79b96f` | Status |

Implementation notes:

- `theme/honey-badger-theme.css` imports Adwaita's dark baseline (GTK 3.20+)
  then overrides the palette and the widgets that define the character —
  header bars, buttons, entries, menus, tabs, switches, scales, progress bars,
  sidebars, tree views, popovers, tooltips, infobars.
- `theme/gtkrc-2.0` reproduces the palette for legacy GTK2 apps without
  depending on a specific theme engine.
- `theme/index.theme` registers the metatheme; the icon theme inherits
  `hicolor, Adwaita, gnome, Humanity` so no icon ever goes missing.
- `assets/ratel-logo.svg` is installed as `ratel.svg` in the user icon theme and
  the system hicolor/pixmaps directories.
- A **high-contrast variant** (`Ratel-HC`) is generated from the same stylesheet
  by `scripts/generate_theme_variants.py`: pure-black surfaces, 2 px borders,
  3 px focus rings, and AAA-level contrast. Select it with `--high-contrast`,
  then switch live with `honey-badger-theme apply high-contrast`.
- `--font-size` sets both the UI and monospace fonts (8–24 px).
- The theme is installed to `~/.themes/Ratel` **and** `/usr/share/themes/Ratel`
  so LightDM and other accounts can use it.
- `~/.config/gtk-3.0/settings.ini`, `~/.gtkrc-2.0`, and the XFCE
  `xsettings`/`xfwm4` channels are written so the theme applies on next login —
  and immediately if an XFCE session is running.

## Utility commands

| Command | What it does |
|---------|--------------|
| `honey-badger-info [--json]` | OS, kernel, hardware, install type, components, theme |
| `honey-badger-update [--dry-run]` | Update system packages, Flatpak/Snap, then clean the cache |
| `honey-badger-install <pkg…>` | Install packages with the native package manager |
| `honey-badger-install --search <term>` | Search the repositories |
| `honey-badger-install --remove <pkg…>` | Remove packages |
| `honey-badger-theme [status\|apply\|list\|palette]` | Inspect, switch, or preview the theme |
| `honey-badger-doctor [--json]` | Diagnose theme, settings, utilities, and runtime issues |
| `honey-badger-uninstall` | Remove Ratel Forge customizations (keeps packages) |

Every command sources a shared `~/.local/share/honey-badger/ui.sh`, so they look
and behave like the installer. They read install metadata from
`install-info`, and package-manager commands from `pm.conf`, so the same
utilities work on all seven families.

`honey-badger-doctor` is profile-aware: theme checks are skipped on Minimal
installs, where no desktop exists. Both `info` and `doctor` accept `--json` for
dashboards and scripts, and bash completion is installed to
`~/.local/share/bash-completion/completions/honey-badger`.

## Architecture

```
install.sh                       Entry point: flags, checks, dispatch
├── lib/
│   ├── common.sh                Core: config, sudo, progress, resume, JSON
│   ├── ui.sh                    Colours, glyphs, layout, logging, prompts
│   ├── packages.sh              Manifest loader (sections -> arrays)
│   ├── theme.sh                 GTK/theme, XFCE, LightDM, wallpaper
│   └── utilities.sh             honey-badger-* generation, post-install
├── config/
│   ├── honey-badger-os.conf     Version, palette, typography, flags
│   ├── packages/<family>.conf   Package manifests (7 families)
│   └── nanorc                   Enhanced nano configuration
├── distros/<family>/             One provisioner per family
├── theme/
│   ├── honey-badger-theme.css   GTK3 base theme
│   ├── honey-badger-theme-hc.css Generated high-contrast variant
│   ├── gtkrc-2.0                GTK2 theme
│   ├── index.theme              Metatheme descriptor
│   └── index-hc.theme           High-contrast metatheme
├── assets/                      Fallback utility commands and logo
├── completions/                 Bash and Zsh completions
├── scripts/                     Theme generator and linter
├── schema/                      JSON schema for the install summary
├── Makefile / justfile          lint, test, check, theme targets
├── verify_scripts.sh            Static structure checks
├── verify_advanced.sh           Security and robustness checks
└── test_final.sh                Execution-level smoke tests
```

### Design decisions

- **Data-driven install types.** `install.sh` owns one catalogue (label, size,
  blurb, bullets) used by the menu, the summary, and `--list-types`; there is no
  duplicated copy to drift.
- **Detection never pollutes its result.** `detect_distribution` sets
  `HB_DISTRO_FAMILY`/`HB_DISTRO_LABEL` instead of echoing, so diagnostic output
  can never be captured into a path.
- **One UI vocabulary.** `hb_section`, `hb_rule`, `hb_kv`, `hb_prompt`,
  `hb_confirm`, `hb_dry_run`, and the `log_*` family are shared by the installer
  and provisioners.
- **Truthful dry-run.** Every user-level mutating function returns early in
  dry-run; `hb_sudo` prints instead of executing.
- **No `eval`, no `curl | bash`.** Downloads go through `hb_download`, which
  writes to a temp file, rejects empty responses, and verifies a SHA-256 when
  one is supplied.
- **Package lists are data.** Each family has a reviewable manifest; the loader
  turns sections into arrays without `eval`.
- **Resume is phase-based.** `hb_phase <id> <command>` records completed units
  of work, so `--resume` skips only what finished — and refuses to reuse state
  from a different distro or install type.
- **Components narrow a profile.** `--components base,dev,desktop,apps` filters
  package groups and the desktop/dev setup that depends on them. `base` is
  always included, and options that need a desktop are dropped with a warning
  when the desktop component is not selected.
- **Themes are generated, then linted.** The high-contrast variant is derived
  from the base stylesheet and both are checked for structure, selectors, and
  WCAG contrast in CI.

## Testing

```bash
bash verify_scripts.sh    # structure, syntax, parity
bash verify_advanced.sh   # security patterns, dry-run, colour handling
bash test_final.sh        # sourcing, idempotency, JSON, progress, banner
```

The suites cover 260 checks locally and run in CI across seven container images.

Developer shortcuts:

```bash
make lint     # bash -n, shellcheck, theme structure/contrast
make test     # the three suites
make check    # both
make theme    # regenerate the high-contrast theme and lint it
```

Visual review (optional, needs `xvfb` + GTK3 examples):

```bash
scripts/theme-screenshot.sh Ratel /tmp/ratel.png
```

## Security model

- No `eval`, no `curl | bash`, and no unquoted command construction
- Config files are whitelisted by key; lines containing command substitution are
  rejected
- Every privileged operation goes through `hb_sudo`, which honours dry-run
- Package names are validated before use by the install helper
- Docker group membership is announced as root-equivalent before being granted
- GPG key imports use `--batch --yes` and HTTPS only
- Downloads are verified to be non-empty; pass a SHA-256 (or set
  `HONEY_BADGER_REQUIRE_CHECKSUMS=1`) to enforce integrity
- The install summary now has a published JSON schema under `schema/`

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Do not run this installer as root` | Run `./install.sh` as your user; sudo is requested per step |
| `No network connectivity detected` | Check DNS and outbound HTTPS; the probe falls back from DNS to `host`, `ping`, then `curl` |
| `Insufficient disk space` | Choose a smaller type or free space (`--check` reports what is available) |
| Package install failures | Non-fatal for optional packages; inspect the log |
| Theme not applied after login | Log out and back in; confirm `~/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml` exists |
| Need to undo | `bash uninstall.sh` (packages are left to your package manager) |

Logs live in `~/.local/share/honey-badger/logs/` (rotated, 5 by default). The
universal installer also writes a summary to `/tmp/honeybadger-summary.json`.

## Contributing

1. Fork and branch from `main`
2. Keep user-facing output on the shared UI helpers
3. Run all three suites plus `bash -n` on changed scripts
4. Open a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full checklist.

## License

MIT — see [LICENSE](LICENSE).

---

*Ratel: fearless by name, methodical by design.*
