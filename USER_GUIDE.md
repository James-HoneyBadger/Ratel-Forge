# Ratel Forge — User Guide

Ratel Forge turns a Linux system you already run into a development machine:
language toolchains, containers, editors, database clients, developer
applications, and a consistent set of utilities.

This is the quick guide. The complete documentation set is:

- **[User Manual](docs/USER_MANUAL.md)** — every option, utility, setting, and
  troubleshooting step
- **[Technical Reference](docs/TECHNICAL_REFERENCE.md)** — internals and APIs
- **[Instructions](docs/INSTRUCTIONS.md)** — task playbooks
- **[README](README.md)** — project overview

Ratel Forge never installs or reconfigures a desktop environment, display
manager, greeter, session, or login behaviour. Your desktop and login stay
exactly as your distribution set them up.

## Before you start

- A supported Linux installation (see below)
- A regular user account with `sudo` (or `wheel`) privileges
- Outbound network access
- Free disk space: 1 GB minimal, 2 GB developer, 3 GB applications, 5 GB full

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
| Full | 5–8 GB | A development workstation with toolchains and GUI apps |
| Developer | 2–4 GB | Languages, containers, editors, DB clients (no GUI apps) |
| Applications | 3–5 GB | GUI developer apps and browsers (no toolchains) |
| Minimal | 0.5–1.0 GB | Servers: CLI tools only, including the modern toolkit |

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
./install.sh --type full --components base,apps
```

Components are `base`, `dev`, and `apps`. The `base` group includes both the
core CLI tools and the modern toolkit (`jq`, `ripgrep`, `fd`, `bat`, `fzf`,
`zoxide`, `direnv`, `delta`, and friends). `base` is always installed and is
added automatically if you leave it out, so a filter can never produce a system
without `git`, `curl`, or editor basics. Minimal installs use `base` only;
`--components` is ignored there and the installer says so.

### Skipping components

```bash
./install.sh --skip-docker --skip-node --skip-git
```

Available: `--skip-docker`, `--skip-python`, `--skip-node`, `--skip-nano`,
`--skip-shell`, `--skip-git`.

### Accessibility and terminals

- `--ascii` replaces Unicode glyphs for terminals without UTF-8 support
- `--no-color` (or `NO_COLOR=1`) disables colour entirely
- `--quiet` shows errors only; `--verbose` adds debug detail
- `--no-banner` omits the header

## After installation

### Utility commands

```bash
honey-badger-info                     # system, hardware, and install details
honey-badger-info --json              # same data for scripts and dashboards
honey-badger-update                   # update packages, Flatpak, Snap; clean cache
honey-badger-update --check           # list available updates without installing
honey-badger-update --dry-run         # show the commands without running them
honey-badger-install ripgrep          # install packages with the native manager
honey-badger-install --file tools.txt # install packages listed in a file
honey-badger-install --search ripgrep # search the repositories
honey-badger-install --remove vim     # remove packages
honey-badger-doctor                   # diagnose metadata/toolchains/runtime issues
honey-badger-doctor --json            # machine-readable diagnostics
honey-badger-report                   # redacted report for a bug report
honey-badger-report --output r.txt    # write it to a mode-600 file
honey-badger-uninstall                # remove Ratel Forge customizations
```

All are in `~/.local/bin` (added to `PATH` in `~/.bashrc`). Bash completion is
installed for them, so `<Tab>` completes subcommands and flags.

On Minimal installs `honey-badger-doctor` reports "toolchain checks skipped"
instead of failing. `honey-badger-uninstall` removes the utility commands,
generated configuration, and install metadata — packages stay installed, exactly
like `uninstall.sh`.

### What changed

| Area | Location |
|------|----------|
| Packages | Installed with the native package manager |
| Nano | `~/.nanorc`, `~/.nano/backups` |
| Shell | `PATH` entries and editor defaults in `~/.bashrc` |
| Git | `~/.gitconfig` (only if no identity was set) |
| Docker | Docker service enabled and the user added to the `docker` group |
| Shell fragments | `~/.config/ratel/shell/*.sh` plus one source line in `~/.bashrc` |
| Readline | `~/.inputrc` (history search, case-insensitive completion) |
| Tool config | `~/.config/bat/config`, `~/.config/ripgrep/config`, `~/.config/tmux/tmux.conf` |
| EditorConfig | `~/.editorconfig` |
| Git defaults | `~/.gitconfig`, `~/.config/git/ignore` |
| Utilities | `~/.local/bin/honey-badger-*`, `~/.local/share/honey-badger/` |

Backups of overwritten user files are kept beside the originals with a
`.hb-backup` suffix.

### Shell and tool settings

Shell configuration is written as fragments under `~/.config/ratel/shell/`:
`00-env.sh` (environment and tool paths), `10-aliases.sh` (interactive aliases),
and `20-tools.sh` (optional `fzf`, `zoxide`, and `direnv` hooks). A single line in
`~/.bashrc` sources them, so adding your own file to that directory is enough to
extend the setup.

Use `--skip-shell` to leave shell and tool configuration untouched. Nothing here
writes to login files, PAM, or `/etc/profile`; the desktop and login behaviour of
the distribution are never changed.

### Reloading your shell

```bash
source ~/.bashrc
```

or open a new terminal. Log out and back in after Docker adds you to its group.

## Changing what gets installed

Package lists live in `config/packages/<family>.conf`. Each section becomes an
array of the same name:

```
[BASE_PACKAGES]
curl
wget

[DEVELOPER_PACKAGES]
python3
nodejs

[APPLICATIONS_PACKAGES]
firefox
```

Add or remove one entry per line, then run the installer again — provisioning is
idempotent. Entries may contain spaces (snap flags such as `code --classic`).

Components map to sections:

| Component | Section | Installed by |
|-----------|---------|--------------|
| `base` | `BASE_PACKAGES` + `CLI_TOOLS_PACKAGES` | every type |
| `dev` | `DEVELOPER_PACKAGES` | `full`, `developer` |
| `apps` | `APPLICATIONS_PACKAGES` | `full`, `apps` |

## Logs and diagnostics

- Per-run logs: `~/.local/share/honey-badger/logs/` (last 5 kept)
- Universal installer log: `~/.local/share/honey-badger/logs/honeybadger-install-*.log`
- Machine-readable summary: `/tmp/honeybadger-summary.json`
- Checkpoint: `~/.local/share/honey-badger/checkpoint` (informational; installs
  are idempotent, so re-running converges)
- Rollback manifest: `~/.local/share/honey-badger/rollback-manifest`
- Shareable report: `honey-badger-report` (redacts your home directory and user
  name; `--output` writes it with mode 600)

## Troubleshooting

| Symptom | Resolution |
|---------|------------|
| `Do not run this installer as root` | Run `./install.sh` as your user |
| `No network connectivity detected` | Verify DNS and HTTPS egress; the probe tries DNS, `host`, `ping`, then `curl` |
| `Insufficient disk space` | Use a smaller type; `--check` reports free space |
| `Unsupported distribution` | Open an issue with the output of `cat /etc/os-release` |
| Docker permission errors | Log out and back in so the group membership applies |
| Toolchain not found in a new shell | `source ~/.bashrc`, then `honey-badger-doctor` |
| An interrupt left the machine half-configured | Re-run with `--resume` |
| Unsure what is broken | Run `honey-badger-doctor` |
| Filing a bug | Run `honey-badger-report` and review the output before sharing |

## Uninstalling

```bash
bash uninstall.sh            # interactive
bash uninstall.sh --dry-run  # preview
```

Removes Ratel Forge files and restores `.hb-backup` originals. System packages
are intentionally left for your package manager:

```bash
sudo apt remove ...      # Debian/Ubuntu
sudo pacman -Rns ...     # Arch
```

## Getting help

- `./install.sh --help` — every option and environment variable
- `./install.sh --list-types` — install profiles
- [README](README.md) — architecture, security model, contributing
