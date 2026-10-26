# Ratel Forge — User Manual

Ratel Forge prepares a Linux machine for application development. It installs a
consistent set of CLI utilities, language toolchains, developer applications,
and user-level settings, then leaves the machine to you.

It is **not** a distribution, and it is **not** a desktop-environment installer.
It never installs or reconfigures a desktop environment, window manager, display
manager, greeter, session, boot target, theme, icon theme, font, or wallpaper,
and it never touches login files, PAM, or `/etc/profile`.

---

## Contents

1. [Requirements](#1-requirements)
2. [Supported distributions](#2-supported-distributions)
3. [Installation](#3-installation)
4. [Install profiles](#4-install-profiles)
5. [Components and package groups](#5-components-and-package-groups)
6. [Command-line reference](#6-command-line-reference)
7. [Environment variables](#7-environment-variables)
8. [What gets installed](#8-what-gets-installed)
9. [Settings and file locations](#9-settings-and-file-locations)
10. [After installation](#10-after-installation)
11. [Utility commands](#11-utility-commands)
12. [Shell and tool settings](#12-shell-and-tool-settings)
13. [Git configuration](#13-git-configuration)
14. [Logs and diagnostics](#14-logs-and-diagnostics)
15. [Troubleshooting](#15-troubleshooting)
16. [Uninstalling](#16-uninstalling)
17. [Security notes](#17-security-notes)
18. [FAQ](#18-faq)

---

## 1. Requirements

- A supported 64-bit Linux installation (x86_64 or aarch64)
- A regular user account with `sudo` (or `wheel`) privileges
- Outbound HTTPS access to distribution repositories and project downloads
- Free disk space: 1 GB minimum, 2 GB developer, 3 GB applications, 5 GB full

Do **not** run the installer as root. It requests privileged access per step and
refuses to run under `sudo ./install.sh`.

## 2. Supported distributions

| Family | Distributions | Package manager | Init |
|--------|---------------|-----------------|------|
| Arch | Arch, Manjaro, EndeavourOS, ArcoLinux, Artix | `pacman` | systemd |
| Debian | Debian, Ubuntu, Mint, Pop!\_OS, Elementary, Zorin, Kali | `apt` | systemd |
| Fedora | Fedora, RHEL, CentOS, AlmaLinux, Rocky Linux | `dnf` / `yum` | systemd |
| Gentoo | Gentoo, Funtoo | `emerge` | OpenRC / systemd |
| openSUSE | Tumbleweed, Leap, SLES, GeckoLinux | `zypper` | systemd |
| Void | Void Linux (glibc and musl) | `xbps` | runit |
| Slackware | Slackware, Salix | `slackpkg` / `sbopkg` | SysV init |

Detection reads `/etc/os-release`, then `ID_LIKE`, then the package manager, then
known release files. Derivatives usually work without an explicit entry.

## 3. Installation

### 3.1 Get the code

```bash
git clone https://github.com/James-HoneyBadger/Ratel-Forge.git
cd Ratel-Forge
```

### 3.2 Check the environment first

```bash
./install.sh --check
```

Reports network reachability, disk space, sudo access, and whether the
distribution is supported. It does not install anything.

### 3.3 Preview the plan

```bash
./install.sh --type developer --dry-run
```

Dry runs skip privileged commands **and** user-level writes, including package
installs, editor configuration, shell fragments, and utility generation.

### 3.4 Run it

```bash
./install.sh
```

The installer:

1. Runs pre-flight checks
2. Detects the distribution family
3. Asks for an install type (or reads `--type`)
4. Shows a summary and asks for confirmation
5. Hands off to the matching provisioner and logs everything

### 3.5 Unattended installation

```bash
./install.sh --type developer --yes
```

For CI, also set `HONEY_BADGER_NONINTERACTIVE=1`, and set
`HONEY_BADGER_GIT_USERNAME` / `HONEY_BADGER_GIT_EMAIL` if you want the Git
identity configured without prompts.

### 3.6 Resuming an interrupted run

```bash
./install.sh --type developer --resume
```

Each unit of work is a phase. Resume skips completed phases, and it discards
state recorded for a different distribution or install type.

### 3.7 Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success, or a requested informational action (`--help`, `--version`, `--list-types`, `--check`) |
| `1` | Pre-flight failure, unsupported distribution, or provisioning failure |
| `2` | Usage error: unknown option, invalid type, invalid component, or missing value |

## 4. Install profiles

| Type | Disk | Components | Best for |
|------|------|------------|----------|
| `full` | 5–8 GB | base + dev + apps | A new development workstation |
| `developer` | 2–4 GB | base + dev | Coding machines, servers, VMs |
| `apps` | 3–5 GB | base + apps | Machines that already have a toolchain or use containers |
| `minimal` | 0.5–1.0 GB | base | Servers, containers, remote hosts |

The pre-flight disk check requires 8 GB for `full`, 4 GB for `developer`, 5 GB
for `apps`, and 1 GB for `minimal`. Override with `HONEY_BADGER_MIN_DISK_GB`.

List profiles without installing:

```bash
./install.sh --list-types
```

## 5. Components and package groups

Components map to manifest sections:

| Component | Manifest sections | Installed by |
|-----------|-------------------|--------------|
| `base` | `BASE_PACKAGES`, `CLI_TOOLS_PACKAGES` | every profile |
| `dev` | `DEVELOPER_PACKAGES` | `full`, `developer` |
| `apps` | `APPLICATIONS_PACKAGES` (plus Snaps, Flatpaks, AUR) | `full`, `apps` |

`base` is always installed. If you omit it, the installer adds it and says so.

### Narrowing a profile

```bash
./install.sh --type full --components base,dev
./install.sh --type full --components base,apps
```

A component that the selected profile never installs is reported and ignored —
for example `--components dev` with `--type apps`. Minimal installs use `base`
only; `--components` is ignored there with an explanatory warning.

### Skipping optional work

```bash
./install.sh --type developer --skip-docker --skip-node --skip-git
```

Available skips: `--skip-docker`, `--skip-python`, `--skip-node`,
`--skip-nano`, `--skip-shell`, `--skip-git`.

## 6. Command-line reference

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help and exit |
| `-V, --version` | Show version and exit |
| `-t, --type TYPE` | Install type: `full`, `developer`, `apps`, `minimal` |
| `--list-types` | Print the install types and exit |
| `-n, --dry-run` | Simulate the install without making changes |
| `-y, --yes` | Assume yes for the confirmation prompt |
| `--non-interactive` | Never prompt (requires `--type` or the env var) |
| `--check` | Run pre-flight checks only, then exit |
| `--resume` | Resume a previous run, skipping completed phases |
| `--components LIST` | Comma-separated package groups: `base`, `dev`, `apps` |
| `--no-banner` | Omit the banner |
| `--ascii` | Use ASCII glyphs instead of Unicode |
| `--no-color` | Disable coloured output |
| `-v, --verbose` | Show debug output |
| `-q, --quiet` | Errors only |
| `--skip-docker` | Skip Docker installation and group setup |
| `--skip-python` | Skip Python development setup |
| `--skip-node` | Skip Node.js development setup |
| `--skip-nano` | Skip nano configuration |
| `--skip-shell` | Skip shell fragments and CLI tool configuration |
| `--skip-git` | Skip Git configuration |

`--help`, `--version`, and `--list-types` are side-effect free: they run before
the shared library is sourced, so they create no log directory, lock, or temp
files.

## 7. Environment variables

| Variable | Values | Purpose |
|----------|--------|---------|
| `HONEY_BADGER_INSTALL_TYPE` | `full` \| `developer` \| `apps` \| `minimal` | Install profile |
| `HONEY_BADGER_DRY_RUN` | `1` | Same as `--dry-run` |
| `HONEY_BADGER_NONINTERACTIVE` | `1` | Same as `--non-interactive` |
| `HONEY_BADGER_ASSUME_YES` | `1` | Same as `--yes` |
| `HONEY_BADGER_COMPONENTS` | `base,dev,apps` | Same as `--components` |
| `HONEY_BADGER_SKIP_DOCKER` | `1` | Skip Docker setup |
| `HONEY_BADGER_SKIP_PYTHON` | `1` | Skip Python setup |
| `HONEY_BADGER_SKIP_NODE` | `1` | Skip Node.js setup |
| `HONEY_BADGER_SKIP_NANO` | `1` | Skip nano configuration |
| `HONEY_BADGER_SKIP_SHELL` | `1` | Skip shell and CLI tool configuration |
| `HONEY_BADGER_SKIP_GIT` | `1` | Skip Git configuration |
| `HONEY_BADGER_GIT_USERNAME` / `_EMAIL` | text | Git identity for unattended runs |
| `HONEY_BADGER_LOG_COUNT` | integer (5) | Rotated log files to keep |
| `HONEY_BADGER_NETWORK_TIMEOUT` | seconds (3) | Connectivity probe timeout |
| `HONEY_BADGER_MIN_DISK_GB` | integer | Override the profile disk check |
| `HONEY_BADGER_NPM_GLOBAL_PATH` | path (`~/.npm-global`) | npm global prefix |
| `HONEY_BADGER_REQUIRE_CHECKSUMS` | `1` | Fail downloads without a SHA-256 |
| `HONEY_BADGER_GITHUB_CLI_KEY_SHA256` | hex | Expected GitHub CLI key digest |
| `HONEY_BADGER_VSCODE_KEY_SHA256` | hex | Expected VS Code key digest |
| `HONEY_BADGER_NODE_MAJOR` | int | Node.js major version for the NodeSource repo (default `24`) |
| `HONEY_BADGER_NODE_KEY_SHA256` | hex | Expected NodeSource signing-key digest |
| `HONEY_BADGER_SBOPKG_VERSION` | text (`0.38.2`) | sbopkg release to install |
| `HONEY_BADGER_SBOPKG_SHA256` | hex | sbopkg digest; the default release verifies against a built-in digest |
| `HONEY_BADGER_ALLOW_UNVERIFIED_DOWNLOADS` | 0/1 | Install root-installed downloads without digest verification |
| `HONEY_BADGER_ASCII` | `1` | Force ASCII glyphs |
| `NO_COLOR` | any | Disable colours ([no-color.org](https://no-color.org)) |
| `CI` | `true` | Implies non-interactive |

The installer also reads `config/honey-badger-os.conf`. Only whitelisted keys are
accepted, and lines containing command substitution are rejected.

## 8. What gets installed

### Base (every profile)

`curl`, `wget`, `git`, `unzip`, `zip`, `htop`, `tree`, `tmux`, `screen`,
OpenSSH, `rsync`, and `nmap`.

### Base tools (every profile)

The modern CLI toolkit: `jq`, `ripgrep`, `fd`, `bat`, `fzf`, `zoxide`, `direnv`,
`git-delta`, `shellcheck`, `shfmt`, `hyperfine`, `tokei`, `ncdu`, `btop`,
`httpie`, and `yq` where the family packages it.

> Debian and Ubuntu package `fd` as `fd-find` (command `fdfind`) and `bat`
> (command `batcat`). Ratel Forge installs the distro packages and reports the
> binary names it knows about.

### Developer (full, developer)

Python 3, Node.js, Go, Rust, OpenJDK, Ruby, PHP; GCC, Clang, CMake, Ninja,
Meson, Make; Docker and Compose; PostgreSQL/MySQL clients, SQLite, Redis;
Neovim, `gh`, and `git-delta` where not already provided.

Profile-specific extras: Fedora and openSUSE install their development groups;
Gentoo installs its development tool set; Slackware installs the `d` and `tcl`
disk sets.

### Applications (full, apps)

Browsers, office and media applications, and IDE/API-client packages where the
family provides them (VS Code, Postman, and friends).

### Settings (every profile)

Nano configuration, shell fragments, readline settings, Git defaults, Docker
group setup, tool configuration files, the `honey-badger-*` utilities, shell
completion, and a JSON install summary.

## 9. Settings and file locations

| Area | Location |
|------|----------|
| Nano | `~/.nanorc`, `~/.nano/backups` |
| Shell fragments | `~/.config/ratel/shell/{00-env,10-aliases,20-tools}.sh` |
| Bash integration | two lines in `~/.bashrc` |
| Readline | `~/.inputrc` |
| EditorConfig | `~/.editorconfig` |
| bat | `~/.config/bat/config` |
| ripgrep | `~/.config/ripgrep/config` |
| tmux | `~/.config/tmux/tmux.conf` (tmux 3.1+) |
| Git | `~/.gitconfig`, `~/.config/git/ignore` |
| Utilities | `~/.local/bin/honey-badger-*` |
| Install metadata | `~/.local/share/honey-badger/install-info`, `pm.conf`, `ui.sh` |
| Logs | `~/.local/share/honey-badger/logs/` |
| Resume state | `~/.local/share/honey-badger/checkpoint` |
| Rollback manifest | `~/.local/share/honey-badger/rollback-manifest` |
| JSON summary | `/tmp/honeybadger-summary.json` |

Existing files are copied to `<file>.hb-backup` before being replaced. The
uninstaller restores those backups.

## 10. After installation

```bash
source ~/.bashrc        # or open a new terminal
honey-badger-info       # confirm the install metadata
honey-badger-doctor     # confirm the environment
```

No reboot is required. If Docker added you to its group, log out and back in for
the membership to apply.

## 11. Utility commands

All commands live in `~/.local/bin`, are added to `PATH` in `~/.bashrc`, and have
bash completion.

### `honey-badger-info [--json]`

Shows OS, kernel, architecture, install type, components, editor, and the install
log path. `--json` is intended for dashboards.

### `honey-badger-update [--check] [--dry-run] [--no-flatpak] [--no-snap] [--no-clean]`

Updates system packages, then Flatpak and Snap packages when installed, then
cleans the cache. `--check` lists available updates without installing them.

### `honey-badger-install [options] <package…>`

```bash
honey-badger-install ripgrep jq
honey-badger-install --search yaml
honey-badger-install --remove vim
honey-badger-install --file ~/dev-tools.txt
```

`--file` reads one package per line; blank lines and `#` comments are ignored,
and duplicates are removed. Package names are validated before use.

### `honey-badger-report [--output FILE] [--no-log]`

Builds a redacted environment report for bug reports: install metadata, system
information, tool versions, `doctor --json`, and the last 40 log lines. `$HOME`
becomes `~` and your user name becomes `<user>`. `--output` writes a mode-600
file. Review the report before sharing it.

### `honey-badger-doctor [--json]`

Checks install metadata, utility commands, toolchains, duplicate `PATH` entries,
shell-fragment installation, `EDITOR`, `~/.ssh` permissions, UTF-8 locale,
inotify watch limits, the npm prefix, the Docker socket, package-manager
availability, and Git identity. Exits `1` when a blocking problem is found.

### `honey-badger-uninstall [--dry-run]`

Removes Ratel Forge files and restores backups. System packages are left to your
package manager.

## 12. Shell and tool settings

Shell configuration is split into fragments:

| File | Purpose |
|------|---------|
| `00-env.sh` | `LESS`, `PAGER`, `RIPGREP_CONFIG_PATH`, `BAT_CONFIG_PATH` |
| `10-aliases.sh` | Interactive aliases (`ll`, `gs`, `gd`, `gl`, `gco`, …) |
| `20-tools.sh` | Guarded hooks for `fzf`, `zoxide`, and `direnv` |

A single line in `~/.bashrc` sources the directory. To add your own settings,
drop another `*.sh` file in `~/.config/ratel/shell/`; to disable the layer, use
`--skip-shell` on the next install or remove the two `.bashrc` lines.

The fragments are bash-only. If your login shell is not bash, the installer says
so and leaves that shell untouched.

## 13. Git configuration

The installer sets an identity only when none exists, then applies defaults
**only when the key is unset**:

| Key | Value |
|-----|-------|
| `init.defaultBranch` | `main` |
| `pull.rebase` | `false` |
| `merge.conflictStyle` | `zdiff3` |
| `rerere.enabled` | `true` |
| `rebase.autoStash` | `true` |
| `push.autoSetupRemote` | `true` |
| `fetch.prune` | `true` |
| `core.editor` | first of `nano`, `vim`, `vi` found |
| `core.pager` | `delta` when installed |
| `interactive.diffFilter` | `delta --color-only` when installed |
| `core.excludesFile` | `~/.config/git/ignore` |

Your existing values are never overwritten.

## 14. Logs and diagnostics

- Per-run logs: `~/.local/share/honey-badger/logs/` (last 5 kept)
- Install summary: `/tmp/honeybadger-summary.json`
- Resume state: `~/.local/share/honey-badger/checkpoint`
- Rollback manifest: `~/.local/share/honey-badger/rollback-manifest`

```bash
honey-badger-doctor            # diagnose
honey-badger-report            # collect a redacted report
```

## 15. Troubleshooting

| Symptom | Resolution |
|---------|------------|
| `Do not run this installer as root` | Run `./install.sh` as your user |
| `No network connectivity detected` | Verify DNS and HTTPS egress; the probe tries DNS, `host`, `ping`, then `curl` |
| `Insufficient disk space` | Use a smaller profile or free space; `--check` reports availability |
| `Unsupported distribution` | Open an issue with `cat /etc/os-release` |
| A package was skipped | The family does not package it; the run continues and the log records it |
| Docker permission errors | Log out and back in so the group membership applies |
| `fdfind`/`batcat` instead of `fd`/`bat` | Expected on Debian and Ubuntu |
| Toolchain missing in a new shell | `source ~/.bashrc`, then `honey-badger-doctor` |
| Shell settings not applied | Confirm the two Ratel lines exist in `~/.bashrc` and your shell is bash |
| An interrupted run left work half-done | Re-run with `--resume` |
| Unsure what is broken | `honey-badger-doctor` |
| Filing a bug | `honey-badger-report` and review before sharing |

## 16. Uninstalling

```bash
bash uninstall.sh --dry-run   # preview
bash uninstall.sh             # remove
```

Removes the utilities, completion, shell fragments, generated configuration, and
install metadata, restoring `.hb-backup` originals where they exist. System
packages are intentionally left installed:

```bash
sudo apt remove <packages>      # Debian/Ubuntu
sudo pacman -Rns <packages>     # Arch
```

## 17. Security notes

- No `eval`, no `curl | bash`, and no unquoted command construction
- Signed-by key imports over HTTPS; downloads are rejected when empty
- Optional SHA-256 enforcement with `HONEY_BADGER_REQUIRE_CHECKSUMS=1`
- Every privileged operation goes through a single sudo wrapper that honours
  dry-run
- Adding your user to the `docker` group grants root-equivalent privileges; the
  installer says so before doing it
- Config files accept only whitelisted keys and reject command substitution
- The report redacts your home directory and user name, but you should still
  review it before sharing

## 18. FAQ

**Does Ratel Forge install a desktop environment?** No. It installs applications
and developer tooling only. Use your distribution's tools for the desktop.

**Will it change my login or session?** No. It never writes display-manager,
greeter, session, PAM, boot-target, or `/etc/profile` configuration.

**Can I run it on a server?** Yes — `minimal` is designed for that.

**Can I use it twice?** Yes. Provisioning is idempotent; re-running converges.
Use `--resume` after an interruption.

**Does it work with zsh?** The utilities work in any shell. The shell fragments
target bash, and the installer tells you when your login shell is something else.

**Where do I change what gets installed?** Edit
`config/packages/<family>.conf`; see [INSTRUCTIONS.md](INSTRUCTIONS.md).

**What if a package name is wrong for my distro?** The provisioner warns and
continues; the log names the package. Fix the manifest and re-run.

**How do I report a bug?** Run `honey-badger-report`, review it, and attach it to
the issue.
