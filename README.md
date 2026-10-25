<img src="assets/ratel-logo.svg" width="88" alt="Ratel logo">

# 🦡 Ratel Forge

**Fearless Linux provisioning — one command, seven distribution families, a developer's toolkit.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](#)
[![Platforms](https://img.shields.io/badge/Distros-7%20families-amber)](#supported-distributions)

Ratel Forge turns a fresh Linux installation into a machine that is ready for
application development: language toolchains, containers, editors, database
clients, GUI developer applications, and a set of small utilities that keep the
environment consistent.

It is **not a distribution** and it is **not a desktop-environment installer**.
It runs on top of the distro you already trust — detecting what it is, then
applying the right package manager, service manager, and configuration
conventions. It never installs or reconfigures a desktop environment, display
manager, greeter, session, or login behaviour.

> Formerly **Honey Badger OS**. The name changed to Ratel — the honey badger's
> proper common name — because this project provides a provisioning framework,
> not an operating system. Environment variables (`HONEY_BADGER_*`) and command
> names (`honey-badger-*`) are unchanged for compatibility.

---

## Contents

- [Documentation](#documentation)
- [Supported distributions](#supported-distributions)
- [What it configures](#what-it-configures)
- [Quick start](#quick-start)
- [Install types](#install-types)
- [Command-line reference](#command-line-reference)
- [Package manifests](#package-manifests)
- [Utility commands](#utility-commands)
- [Architecture](#architecture)
- [Testing](#testing)
- [Security model](#security-model)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Documentation

| Document | Audience | Contents |
|----------|----------|----------|
| [User Manual](docs/USER_MANUAL.md) | Users | Installation, profiles, components, settings, utilities, troubleshooting, FAQ |
| [Technical Reference](docs/TECHNICAL_REFERENCE.md) | Maintainers | Execution flow, module API, formats, state, JSON schema, security, extension points |
| [Instructions](docs/INSTRUCTIONS.md) | Operators and contributors | Step-by-step procedures: deploy, add a distro, add a phase, add a utility, debug, release |
| [Contributing](CONTRIBUTING.md) | Contributors | Conventions and pull-request workflow |
| [Changelog](CHANGELOG.md) | Everyone | Release history |

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

## What it configures

| Layer | What Ratel Forge does |
|-------|------------------------|
| **System utilities** | Installs a lean base of CLI tools (`git`, `curl`, `wget`, `htop`, `tmux`, `rsync`, `nmap`, archives, OpenSSH) plus a modern toolkit: `jq`, `ripgrep`, `fd`, `bat`, `fzf`, `zoxide`, `direnv`, `delta`, `shellcheck`, `shfmt`, `hyperfine`, `tokei`, `ncdu`, `btop`, `httpie` |
| **Language toolchains** | Python, Node.js, Go, Rust, OpenJDK, Ruby, PHP, plus GCC, Clang, CMake, Ninja, Meson, and Make |
| **Containers & data** | Docker, Compose, PostgreSQL/MySQL clients, SQLite, and Redis |
| **Editor & shell** | Neovim, an enhanced nano configuration, `EDITOR`/`VISUAL` defaults, shell fragments, readline history search, Git identity and quality defaults |
| **Developer applications** | IDEs, API clients, browsers, office and media tools, and database GUIs |
| **Tool settings** | Config for `bat`, `ripgrep`, `tmux`, and EditorConfig; `delta` as the Git pager when installed |
| **Utilities** | `honey-badger-info`, `-update`, `-install`, `-doctor`, and `-uninstall` |

It deliberately does **not** touch:

- desktop environments or window managers
- display managers, greeters, or session files
- boot targets, runlevels, or auto-login
- GTK/Qt themes, icon themes, fonts, or wallpapers

A CI guard (`scripts/check-no-desktop-layer.sh`) fails the build if any of that
code appears again.

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

Dry runs are truthful: user-level steps (nano config, editor defaults, tool
installs) are skipped as well as privileged ones.

### Unattended

```bash
./install.sh --type developer --yes
```

## Install types

| Type | Disk | Includes | Best for |
|------|------|----------|----------|
| **Full** | 5–8 GB | Full toolchain, containers, editors, CLI utilities, and GUI developer applications | A new development workstation |
| **Developer** | 2–4 GB | Languages, build tools, containers, editors, and DB clients — no GUI applications | Coding machines, servers, and VMs |
| **Applications** | 3–5 GB | GUI developer applications, browsers, and media tools — no language toolchains | Laptops that already have a toolchain or use containers |
| **Minimal** | 0.5–1.0 GB | CLI tools (including the modern toolkit), monitoring, nano, and Ratel Forge commands — no GUI applications | Servers and containers |

List them at any time:

```bash
./install.sh --list-types
```

## Command-line reference

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help and exit |
| `-V, --version` | Show version and exit |
| `-t, --type TYPE` | Install type: `full`, `developer`, `apps`, `minimal` |
| `--list-types` | Print the install types and exit |
| `-n, --dry-run` | Simulate the install without making changes |
| `-y, --yes` | Assume yes for the confirmation prompt |
| `--non-interactive` | Never prompt (requires `--type`) |
| `--check` | Run pre-flight checks only, then exit |
| `--resume` | Resume a previous run, skipping phases already completed |
| `--components LIST` | Package groups to install: `base`, `dev`, `apps` |
| `--no-banner` | Omit the banner |
| `--ascii` | Use ASCII instead of Unicode glyphs |
| `--no-color` | Disable coloured output |
| `-v, --verbose` | Show debug output |
| `-q, --quiet` | Errors only |
| `--skip-docker` | Skip Docker installation and group setup |
| `--skip-python` | Skip Python development setup |
| `--skip-node` | Skip Node.js development setup |
| `--skip-nano` | Skip nano configuration |
| `--skip-shell` | Skip shell fragments and CLI tool configuration |
| `--skip-git` | Skip Git identity configuration |

`--help`, `--version`, and `--list-types` are side-effect free: they run before
the shared library is sourced, so they never create log files or locks.

### Environment variables

| Variable | Values | Purpose |
|----------|--------|---------|
| `HONEY_BADGER_INSTALL_TYPE` | `full` \| `developer` \| `apps` \| `minimal` | Install profile |
| `HONEY_BADGER_DRY_RUN` | `1` | Same as `--dry-run` |
| `HONEY_BADGER_NONINTERACTIVE` | `1` | Same as `--non-interactive` |
| `HONEY_BADGER_ASSUME_YES` | `1` | Same as `--yes` |
| `HONEY_BADGER_GIT_USERNAME` / `_EMAIL` | text | Git identity for unattended runs |
| `HONEY_BADGER_LOG_COUNT` | integer (5) | Rotated log files to keep |
| `HONEY_BADGER_NETWORK_TIMEOUT` | seconds (3) | Connectivity probe timeout |
| `HONEY_BADGER_MIN_DISK_GB` | integer | Override the profile disk check |
| `HONEY_BADGER_NPM_GLOBAL_PATH` | path (`~/.npm-global`) | npm global prefix |
| `HONEY_BADGER_COMPONENTS` | `base,dev,apps` | Same as `--components` |
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

[DEVELOPER_PACKAGES]
python3
nodejs
go

[APPLICATIONS_PACKAGES]
firefox
postman
```

Sections become arrays of the same name (`BASE_PACKAGES`, `DEVELOPER_PACKAGES`, …),
and the provisioner loads them with `hb_load_package_manifest`. Reviewing a
package change is a diff of a plain list, with no shell logic in the way.

Components map to sections:

| Component | Manifest section | Installed by |
|-----------|------------------|--------------|
| `base` | `BASE_PACKAGES` + `CLI_TOOLS_PACKAGES` (and `BASE_SETS` on Slackware) | every type |
| `dev` | `DEVELOPER_PACKAGES` (and `DEVELOPER_SETS` on Slackware) | `full`, `developer` |
| `apps` | `APPLICATIONS_PACKAGES`, snaps, flatpaks, AUR | `full`, `apps` |

## What gets installed

**Base (all types)** — `curl`, `wget`, `git`, `unzip`, `zip`, `htop`, `tree`,
`tmux`, `screen`, OpenSSH, `rsync`, and `nmap`.

**Base tools (all types)** — `jq`, `ripgrep`, `fd`, `bat`, `fzf`, `zoxide`,
`direnv`, `git-delta`, `shellcheck`, `shfmt`, `hyperfine`, `tokei`, `ncdu`,
`btop`, `httpie`, and `yq` where the family packages it. Debian/Ubuntu ship
`fd` as `fdfind` and `bat` as `batcat`; the names are unchanged upstream.

**Developer** — Python 3, Node.js, Go, Rust, OpenJDK, Ruby, PHP; GCC, Clang,
CMake, Ninja, Meson, Make; Docker and Compose; PostgreSQL/MySQL clients, SQLite,
Redis; Neovim and an enhanced nano; `gh` and `git-delta`.

**Applications** — Firefox, Chromium, LibreOffice, GIMP, Inkscape, VLC,
Audacity, FFmpeg, Thunderbird, Telegram, plus IDE/API-client packages where the
family provides them (VS Code, Postman, and friends).

**Settings (all types)** — shell fragments in `~/.config/ratel/shell/*.sh`
sourced from a single `~/.bashrc` line, `~/.inputrc` history search,
`~/.editorconfig`, and configuration for `bat`, `ripgrep`, and `tmux`. Git gains
sensible defaults when the key is unset: `zdiff3` conflicts, rerere, auto-stash
rebases, `push.autoSetupRemote`, pruning fetches, a global ignore file, and
`delta` as the pager when it is installed.

**Ratel layer** — nano configuration, Docker group setup, the `honey-badger-*`
utilities (including a redacted `report`), shell completion, and a JSON install
summary.

## Look and feel

Terminal output is the only visual surface Ratel Forge owns. The installer uses
one design system from start to finish:

```
  ╭────────────────────────────────────────────────────────────╮
  │                                                            │
  │ R A T E L   F O R G E                                      │
  │ Fearless Linux provisioning                                │
  │                                                            │
  ╰────────────────────────────────────────────────────────────╯
  🦡  v3.0.0 "Fearless" · dry-run

  ── Choose an installation type ─────────────────────────────

  1  Full  · 5-8 GB
     Complete developer workstation: language toolchains, containers,
     editors, CLI utilities, and GUI developer applications.
     Best for: a new machine you want fully set up. (recommended)

  2  Developer  · 2-4 GB
     Languages, build tools, containers, editors, and database clients.
     Skips GUI applications.
     Best for: coding machines, servers, and development VMs.

  3  Applications  · 3-5 GB
     GUI developer applications, browsers, and media tools, without
     language toolchains or build tools.
     Best for: laptops that already have a toolchain or use containers.

  4  Minimal  · 0.5-1.0 GB
     CLI tools, monitoring, nano, and Ratel Forge commands. No GUI
     applications, audio stack, or fonts.
     Best for: servers, containers, and remote hosts.

  Default: 1 (Full). Type ? to show this list again.

  ? Select installation type [1-4] [1]: 2
  ✔ Selected: Developer (2-4 GB)

  ── Pre-flight checks ──────────────────────────────────────
  • Checking network connectivity…
  ✔ Network reachable
  ✔ Disk space OK (443 GB free; 4 GB required for developer)
  ✔ Repository layout OK

  ❯ [1/11] Updating system packages...
```

- Severity glyphs (`✔`, `▲`, `✖`, `•`, `❯`) with automatic ASCII fallback
- `[n/total]` progress counters from the shared library; when skip flags or
  component filters change the plan, the counter falls back to `[n]` so the
  denominator never lies
- 256-colour palette when supported, ANSI-8 fallback otherwise
- Width-aware rules clamped to 100 columns
- Timestamped, ANSI-free logs for direct provisioner runs; the universal
  installer additionally tees raw subprocess output into its own log

## Utility commands

| Command | What it does |
|---------|--------------|
| `honey-badger-info [--json]` | OS, kernel, hardware, install type, and components |
| `honey-badger-update [--check] [--dry-run]` | List available updates (`--check`) or update packages, Flatpak/Snap, and clean the cache |
| `honey-badger-install <pkg…>` | Install packages with the native package manager |
| `honey-badger-install --file <list>` | Install packages listed one per line (comments allowed) |
| `honey-badger-install --search <term>` | Search the repositories |
| `honey-badger-install --remove <pkg…>` | Remove packages |
| `honey-badger-report [--output FILE]` | Redacted environment report for bug reports |
| `honey-badger-doctor [--json]` | Diagnose metadata, utilities, toolchains, shell setup, SSH permissions, locale, and runtime issues |
| `honey-badger-uninstall` | Remove Ratel Forge customizations (keeps packages) |

Every command sources a shared `~/.local/share/honey-badger/ui.sh`, so they look
and behave like the installer. They read install metadata from
`install-info`, and package-manager commands from `pm.conf`, so the same
utilities work on all seven families.

`honey-badger-doctor` is profile-aware: toolchain checks are skipped on Minimal
installs. Both `info` and `doctor` accept `--json` for dashboards and scripts,
and bash completion is installed to
`~/.local/share/bash-completion/completions/honey-badger`.

## Architecture

```
install.sh                       Entry point: flags, checks, dispatch
├── lib/
│   ├── common.sh                Core: config, sudo, progress, resume, JSON
│   ├── ui.sh                    Colours, glyphs, layout, logging, prompts
│   ├── packages.sh              Manifest loader (sections -> arrays)
│   ├── editor.sh                Nano configuration and editor defaults
│   ├── shell.sh                 Shell fragments, readline, tool configs
│   └── utilities.sh             honey-badger-* generation, post-install
├── config/
│   ├── honey-badger-os.conf     Version, editor, flags, tunables
│   ├── packages/<family>.conf   Package manifests (7 families)
│   └── nanorc                   Enhanced nano configuration
├── distros/<family>/             One provisioner per family
├── assets/                      Fallback utility commands and logo
├── completions/                 Bash and Zsh completions
├── docs/                        User manual, technical reference, instructions
├── scripts/                     Desktop-layer guard
├── schema/                      JSON schema for the install summary
├── Makefile / justfile          lint, test, check targets
├── verify_scripts.sh            Static structure checks
├── verify_advanced.sh           Security and robustness checks
└── test_final.sh                Execution-level smoke tests
```

### Design decisions

- **Developer tooling only.** No desktop environment, display manager, greeter,
  session, boot target, theme, or wallpaper code — enforced by a CI guard.
- **Shell settings are fragment-based.** All shell configuration lives in
  `~/.config/ratel/shell/*.sh` behind one sourced line. Nothing touches login
  files, PAM, or `/etc/profile`, and removal is a directory delete.
- **Existing choices win.** Git defaults are only written when the key is unset,
  so a configured machine is never silently rewritten.
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
- **Components narrow a profile.** `--components base,dev,apps` filters package
  groups and the development setup that depends on them. `base` is always
  included.

## Testing

```bash
bash verify_scripts.sh    # structure, syntax, parity, desktop-layer guard
bash verify_advanced.sh   # security patterns, dry-run, colour handling
bash test_final.sh        # sourcing, idempotency, JSON, progress, banner
```

The suites run in CI across seven container images.

Developer shortcuts:

```bash
make lint     # bash -n, shellcheck, desktop-layer guard
make test     # the three suites
make check    # both
make guard    # fail if desktop-environment or login code reappears
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
- The install summary has a published JSON schema under `schema/`

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Do not run this installer as root` | Run `./install.sh` as your user; sudo is requested per step |
| `No network connectivity detected` | Check DNS and outbound HTTPS; the probe falls back from DNS to `host`, `ping`, then `curl` |
| `Insufficient disk space` | Choose a smaller type or free space (`--check` reports what is available) |
| Package install failures | Non-fatal for optional packages; inspect the log |
| Toolchain not on `PATH` | Reload the shell (`source ~/.bashrc`) and run `honey-badger-doctor` |
| Need to undo | `bash uninstall.sh` (packages are left to your package manager) |

Logs live in `~/.local/share/honey-badger/logs/` (rotated, 5 by default). The
universal installer also writes a summary to `/tmp/honeybadger-summary.json`.

## Contributing

1. Fork and branch from `main`
2. Keep user-facing output on the shared UI helpers
3. Never add desktop-environment, display-manager, greeter, session, or login
   handling — `make guard` must stay green
4. Run all three suites plus `bash -n` on changed scripts
5. Open a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full checklist.

## License

MIT — see [LICENSE](LICENSE).

---

*Ratel: fearless by name, methodical by design.*
