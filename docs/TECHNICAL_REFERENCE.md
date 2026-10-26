# Ratel Forge — Technical Reference

This document describes the implementation: execution flow, module APIs, data
formats, state files, invariants, and extension points. For usage, see the
[User Manual](USER_MANUAL.md); for procedures, see [INSTRUCTIONS.md](INSTRUCTIONS.md).

---

## Contents

1. [Scope and invariants](#1-scope-and-invariants)
2. [Execution flow](#2-execution-flow)
3. [Repository layout](#3-repository-layout)
4. [Module API](#4-module-api)
5. [Install type and component resolution](#5-install-type-and-component-resolution)
6. [Package manifest format](#6-package-manifest-format)
7. [Configuration and key validation](#7-configuration-and-key-validation)
8. [State, artifacts, and logs](#8-state-artifacts-and-logs)
9. [JSON install summary](#9-json-install-summary)
10. [Utility architecture](#10-utility-architecture)
11. [Security model](#11-security-model)
12. [Extension points](#12-extension-points)
13. [Testing and CI](#13-testing-and-ci)
14. [Compatibility and limitations](#14-compatibility-and-limitations)

---

## 1. Scope and invariants

Ratel Forge provisions **developer tooling**. The following invariants are
enforced by `scripts/check-no-desktop-layer.sh` and by code review:

1. No desktop-environment, window-manager, display-manager, greeter, session,
   boot-target, theme, icon-theme, font, or wallpaper code.
2. No writes to `~/.profile`, `/etc/profile`, PAM, or login configuration.
3. `--dry-run` installs nothing and writes no user configuration; it only
   writes temporary logs and runs the connectivity probe.
4. Every privileged operation goes through `hb_sudo`.
5. No `eval`, no `curl | bash`, and no unquoted command construction.
6. Configuration files accept only whitelisted keys; command substitution,
   unknown keys, and shell metacharacters are rejected.
7. User files are backed up to `<file>.hb-backup` before replacement.
8. Provisioning is idempotent; re-running converges without duplicating entries.
9. The progress denominator never reports a total below the steps executed.

## 2. Execution flow

```
install.sh
  ├─ parse flags (before sourcing the library; --help/--version are side-effect free)
  ├─ source lib/common.sh (validates config, loads ui/packages/editor/shell/utilities)
  ├─ setup_logging (tee to a timestamped log)
  ├─ acquire lock, init JSON summary, load checkpoint
  ├─ check_root / check_sudo / check_architecture
  ├─ detect_distribution → HB_DISTRO_FAMILY, HB_DISTRO_LABEL
  ├─ get_installation_type → HB_SELECTED_TYPE
  ├─ check_option_coherence
  ├─ run_preflight_checks (network, disk, layout)
  ├─ show_installation_summary + confirm_installation
  └─ run_installer → distros/<family>/install-<family>.sh
        ├─ hb_json_init / hb_rollback_init
        ├─ hb_phases_init <type>
        ├─ hb_set_total_steps <n>
        ├─ hb_phase update|packages|nano|shell|utilities|dev
        └─ show_post_install (writes the JSON summary)
```

`detect_distribution` communicates through `HB_DISTRO_FAMILY` and
`HB_DISTRO_LABEL` and writes nothing to stdout, so command substitution cannot
capture log lines.

## 3. Repository layout

| Path | Responsibility |
|------|----------------|
| `install.sh` | Flags, pre-flight, type catalogue, detection, summary, dispatch |
| `lib/common.sh` | Configuration, sudo, progress, phases, checkpoints, rollback, JSON, downloads, services, components, Git/Docker/Python/Node setup |
| `lib/ui.sh` | Colours, glyphs, logging, prompts, banner |
| `lib/packages.sh` | Manifest loader |
| `lib/editor.sh` | Nano configuration and editor defaults |
| `lib/shell.sh` | Shell fragments, readline, tool configuration |
| `lib/utilities.sh` | Utility generation, metadata, post-install report |
| `assets/honey-badger-*` | Standalone utilities copied into `~/.local/bin` |
| `config/honey-badger-os.conf` | Release identity and tunables |
| `config/packages/<family>.conf` | Package manifests |
| `config/nanorc` | Enhanced nano configuration |
| `distros/<family>/install-<family>.sh` | Family provisioner |
| `schema/honeybadger-summary.schema.json` | JSON summary schema |
| `scripts/check-no-desktop-layer.sh` | Scope guard |
| `verify_scripts.sh`, `verify_advanced.sh`, `test_final.sh` | Test suites |

## 4. Module API

Functions marked **internal** are not part of the stable surface.

### 4.1 `lib/ui.sh`

| Function | Purpose |
|----------|---------|
| `log_info`, `log_success`, `log_warning`, `log_error` | Status lines |
| `log_step`, `log_debug` | Step and verbose lines |
| `hb_outcome <dry> <real>` | Prints the appropriate message for the current mode |
| `hb_rule`, `hb_section <title>`, `hb_kv <key> <value>` | Layout |
| `hb_prompt <label> [default]`, `hb_confirm <question> [yes|no]` | Input |
| `is_noninteractive`, `hb_dry_run` | Mode predicates |
| `hb_show_banner <label> <subtitle>` | Banner |
| `hb_init_distro_log <family>` | Sets and rotates `LOG_FILE` |

Colour degrades 256 → ANSI-8 → none; glyphs degrade to ASCII when `--ascii`,
`TERM=dumb`, or the locale is not UTF-8.

### 4.2 `lib/common.sh`

| Group | Function | Purpose |
|-------|----------|---------|
| Config | `_hb_validate_config <file>` (**internal**) | Whitelist and injection checks |
| Sudo | `hb_sudo <cmd…>` | Dry-run-aware privileged execution |
| Progress | `hb_set_total_steps <n>`, `hb_next_step <msg>` | `[n/total]` counters; auto-corrects the denominator upward |
| Locking | `hb_acquire_lock`, `hb_release_lock` | Prevent concurrent runs |
| Temp | `hb_register_temp <path>` | Cleanup on exit |
| Backup | `hb_backup_file <path>` | One-time `.hb-backup` copy |
| Checkpoint | `hb_save_checkpoint` (**internal**), `hb_load_checkpoint`, `hb_clear_checkpoint` | Resume state |
| Phases | `hb_phases_init <type>`, `hb_phase_done`, `hb_phase_mark_done`, `hb_phase <id> <cmd…>`, `hb_phases_reset` | Phase-based resume |
| Rollback | `hb_rollback_init`, `hb_rollback_add_packages`, `hb_rollback_add_file`, `hb_rollback_add_group` | Uninstall manifest |
| Downloads | `hb_download <url> <dest> [sha256]` | curl/wget, non-empty, checksum, dry-run no-op |
| Network | `hb_check_network` | DNS → `host` → `ping` → `curl` |
| Services | `hb_enable_service <name>` | systemd/OpenRC/runit/SysV |
| Components | `hb_component_enabled`, `hb_component_for_label`, `hb_component_allowed`, `hb_effective_components` | Group resolution |
| Skips | `hb_skip_active`, `hb_skip_component <name>` | Skip-flag state |
| Shell | `ensure_bashrc_line <line>` | Idempotent `.bashrc` edit |
| JSON | `hb_json_init`, `hb_json_add_package`, `hb_json_add_config`, `hb_json_add_error`, `hb_json_write [path]`, `_hb_json_escape` (**internal**) | Summary |
| Development | `setup_git`, `setup_docker`, `setup_python_dev`, `setup_node_dev`, `setup_development_environment` | Developer environment |

`hb_effective_components` intersects the profile's candidate components with
`--components` and always reports `base`.

### 4.3 `lib/packages.sh`

| Function | Purpose |
|----------|---------|
| `hb_load_package_manifest <path>` | Reads `[SECTION]` blocks into global arrays of the same name |

The loader trims CR and trailing whitespace, skips blank lines and `#` comments,
and declares each section with `declare -g -a`. It never evaluates content.

### 4.4 `lib/editor.sh`

| Function | Purpose |
|----------|---------|
| `setup_nano` | Installs `~/.nanorc`, creates `~/.nano/backups`, sets `EDITOR`/`VISUAL` |

### 4.5 `lib/shell.sh`

| Function | Purpose |
|----------|---------|
| `setup_shell` | Orchestrates fragments, readline, and tool configuration |
| `_hb_write_shell_fragments <dir>` (**internal**) | Writes `00-env.sh`, `10-aliases.sh`, `20-tools.sh` |
| `_hb_write_readline_config` (**internal**) | Writes `~/.inputrc` |
| `_hb_write_tool_configs <config_home>` (**internal**) | Writes bat, ripgrep, tmux, EditorConfig |

XDG paths are resolved **at call time**, so tests and alternate `HOME` values are
isolated. The `.bashrc` integration is exactly two lines:

```bash
# Ratel Forge shell configuration
for f in "${XDG_CONFIG_HOME:-$HOME/.config}"/ratel/shell/*.sh; do [ -r "$f" ] && . "$f"; done
```

### 4.6 `lib/utilities.sh`

| Function | Purpose |
|----------|---------|
| `create_utility_scripts <update> <install> <clean> [search] [remove] [check]` | Installs utilities, completion, and metadata |
| `show_post_install` | Renders the post-install summary and writes JSON |

Generated metadata:

`~/.local/share/honey-badger/install-info`

```bash
HONEY_BADGER_VERSION="3.0.2"
HONEY_BADGER_CODENAME="Fearless"
HONEY_BADGER_INSTALL_TYPE="developer"
HONEY_BADGER_COMPONENTS="base,dev"
HONEY_BADGER_DISTRO="arch"
HONEY_BADGER_BUILD_DATE="unknown"
HONEY_BADGER_LOG="/home/user/.local/share/honey-badger/logs/..."
```

`~/.local/share/honey-badger/pm.conf`

```bash
HB_PM_UPDATE='sudo pacman -Syu --noconfirm'
HB_PM_INSTALL='sudo pacman -S --needed --noconfirm'
HB_PM_CLEAN='sudo pacman -Sc --noconfirm'
HB_PM_SEARCH='pacman -Ss'
HB_PM_REMOVE='sudo pacman -Rns --noconfirm'
HB_PM_CHECK='pacman -Qu'
```

Commands are stored with `@Q` quoting and are trusted, installer-generated data.

## 5. Install type and component resolution

| Type | Candidate components | Step totals (per family) |
|------|----------------------|--------------------------|
| `full` | base, dev, apps | Arch 13, Debian 14, Fedora 12, Gentoo 12, openSUSE 13, Slackware 16, Void 11 |
| `developer` | base, dev | 12, 12, 11, 11, 11, 15, 10 |
| `apps` | base, apps | 9, 10, 7, 7, 8, 10, 7 |
| `minimal` | base | 6, 7, 6, 6, 6, 9, 6 |

Resolution:

1. `_normalize_components` validates, adds `base`, and orders the list.
2. `if hb_skip_active` the static step total is disabled and counters show `[n]`.
3. The provisioner's `case` statement decides which groups to install.
4. `hb_component_allowed <label>` gates each install call through
   `hb_component_for_label`.
5. `hb_effective_components` reports what the profile can actually install,
   intersected with `--components`.

`check_option_coherence` warns when `--components` requests a group the profile
never installs (for example `dev` with `apps`).

## 6. Package manifest format

```ini
[BASE_PACKAGES]
curl
git

[CLI_TOOLS_PACKAGES]
jq
ripgrep

[DEVELOPER_PACKAGES]
python3

[APPLICATIONS_PACKAGES]
firefox

[AUR_PACKAGES]
visual-studio-code-bin

[SNAP_PACKAGES]
code --classic

[FLATPAK_PACKAGES]
com.github.tchx84.Flatseal
```

- One entry per line; entries may contain spaces for package-manager flags.
- `#` starts a comment; blank lines are ignored.
- Section names must match `^[A-Z0-9_]+$`.
- Slackware also uses `BASE_SETS` and `DEVELOPER_SETS` for disk sets.

Component mapping (`hb_component_for_label`):

| Label contains | Component |
|----------------|-----------|
| `base` | base |
| `developer`, `development`, `dev` | dev |
| `application`, `snap`, `flatpak`, `aur` | apps |
| anything else | base |

## 7. Configuration and key validation

`config/honey-badger-os.conf` is sourced only through `_hb_validate_config`,
which rejects:

- lines containing `$(` or backticks
- keys outside the whitelist

Whitelisted keys: `HONEY_BADGER_VERSION`, `HONEY_BADGER_CODENAME`,
`HONEY_BADGER_BUILD_DATE`, `EDITOR`, `VISUAL`, `HONEY_BADGER_DEV_MODE`,
`HONEY_BADGER_SKIP_{DOCKER,PYTHON,NODE,NANO,SHELL,GIT}`, `HONEY_BADGER_GIT_USERNAME`,
`HONEY_BADGER_GIT_EMAIL`, `HONEY_BADGER_LOG_COUNT`, `HONEY_BADGER_NETWORK_TIMEOUT`,
`HONEY_BADGER_MIN_DISK_GB`, `HONEY_BADGER_NPM_GLOBAL_PATH`.

Unknown keys are ignored with a warning.

## 8. State, artifacts, and logs

| Artifact | Path | Format |
|----------|------|--------|
| Installer log | `~/.local/share/honey-badger/logs/honeybadger-<ts>.log` | Timestamped, ANSI-free |
| Provisioner log | same directory, `honeybadger-<family>-<ts>.log` | Timestamped |
| Lock | `~/.local/share/honey-badger/install.lock` | PID (flock) |
| Checkpoint | `~/.local/share/honey-badger/checkpoint` | `CHECKPOINT_*` lines |
| Phase state | `~/.local/share/honey-badger/phases` | `type:`, `distro:`, phase IDs |
| Rollback manifest | `~/.local/share/honey-badger/rollback-manifest` | `FILE:`, `PACKAGE:`, `GROUP:` |
| JSON summary | `/tmp/honeybadger-summary.json` | Schema below |
| Install metadata | `~/.local/share/honey-badger/install-info` | Shell assignments |
| Package commands | `~/.local/share/honey-badger/pm.conf` | Shell assignments |
| Utility UI | `~/.local/share/honey-badger/ui.sh` | Shell library |

Log rotation keeps `HONEY_BADGER_LOG_COUNT` files (default 5) and is skipped in
dry-run.

## 9. JSON install summary

Written by `hb_json_write`:

```json
{
  "honey_badger_version": "3.0.2",
  "distro": "arch",
  "install_type": "full",
  "components": "base,dev,apps",
  "status": "success",
  "dry_run": false,
  "start_time": "2026-10-25T00:00:00Z",
  "end_time": "2026-10-25T00:10:00Z",
  "packages_installed": ["curl", "git"],
  "configs_changed": ["~/.nanorc", "~/.config/ratel/shell"],
  "errors": []
}
```

`status` is `success`, `partial` (at least one error), or `dry-run`. The schema
is `schema/honeybadger-summary.schema.json` (`additionalProperties: false`).

## 10. Utility architecture

Utilities are standalone bash scripts copied from `assets/` to
`~/.local/bin`. They read `install-info`, `pm.conf`, and `ui.sh` from
`${XDG_DATA_HOME:-$HOME/.local/share}/honey-badger`. If `ui.sh` is missing they
fall back to plain-text helpers, so they remain usable.

| Utility | Options | Exit codes |
|---------|---------|------------|
| `honey-badger-info` | `--json` | 0; 2 unknown option |
| `honey-badger-update` | `--check`, `--dry-run`, `--no-flatpak`, `--no-snap`, `--no-clean` | 0; 1 no command/failed; 2 usage |
| `honey-badger-install` | `--search`, `--remove`, `--file`, `--dry-run` | 0; 1 failure; 2 usage |
| `honey-badger-report` | `--output`, `--no-log` | 0; 1 write failure; 2 usage |
| `honey-badger-doctor` | `--json` | 0 no blocking issue; 1 failures |
| `honey-badger-uninstall` | `--dry-run` | 0 |

`honey-badger-report` redacts `$HOME` and the user name before writing. It never
prints environment variables or file contents other than the log tail.

## 11. Security model

| Control | Implementation |
|---------|----------------|
| No `eval` | `verify_advanced.sh` fails on line-leading `eval` |
| No download-and-execute | `hb_download` writes a file; callers validate it before `hb_sudo bash <file>` |
| Empty downloads rejected | `[[ -s "$dest" ]]` before use |
| Checksums | Optional SHA-256; `HONEY_BADGER_REQUIRE_CHECKSUMS=1` fails closed |
| Privilege | Single `hb_sudo` wrapper; dry-run prints instead of executing |
| Config injection | Whitelist plus `$(`/backtick rejection |
| Package names | Regex validation before invoking a package manager |
| Docker group | Announced as root-equivalent before `usermod -aG` |
| Scope | Desktop/login guard in CI and tests |

Known trusted inputs: `pm.conf`, `install-info`, and `ui.sh` are generated by the
installer and sourced by the utilities. A user who can write them can already run
code as themselves.

## 12. Extension points

- **New distribution:** create `distros/<family>/install-<family>.sh`, add a
  manifest, add detection, add CI. See [INSTRUCTIONS.md](INSTRUCTIONS.md#2-add-a-distribution).
- **New packages:** edit `config/packages/<family>.conf` only.
- **New CLI option:** parse before sourcing, export `HONEY_BADGER_*`, document,
  complete, test.
- **New setup phase:** add `lib/<name>.sh`, source it from `lib/common.sh`, call
  `hb_phase <id> <fn>` from each provisioner, bump step totals.
- **New utility:** add `assets/honey-badger-<name>`, register it in
  `create_utility_scripts`, `uninstall.sh`, and both completions.
- **New doctor check:** add a `check_*` function in
  `assets/honey-badger-doctor` and call it before the report is emitted.

## 13. Testing and CI

| Suite | Scope |
|-------|-------|
| `verify_scripts.sh` | Syntax, structure, required functions, manager parity, install types, manifest sections, shell phase, desktop-layer guard |
| `verify_advanced.sh` | Security patterns, sudo discipline, service management, environment defaults, install-type completeness, login-configuration check, colour handling |
| `test_final.sh` | Sourcing, double-source, dry-run, idempotency, JSON, progress, config identity, shell layer, package manifests, resume, type selection, profile reporting, extended utilities |

CI (`.github/workflows/ci.yml`) runs syntax checks, ShellCheck, the guard, config
validation, all three suites, and minimal dry-runs in seven distribution
containers.

## 14. Compatibility and limitations

- Bash 4.3+ (`declare -n`, `mapfile`, `@Q` quoting).
- GNU coreutils and GNU `find` (`-printf`) are assumed on Linux.
- `~/.config/tmux/tmux.conf` is read by tmux 3.1+; older tmux uses
  `~/.tmux.conf`, which is never overwritten.
- Debian/Ubuntu expose `fd` as `fdfind` and `bat` as `batcat`.
- Package-name validity is not checked against live repositories; unavailable
  packages are warnings, not failures.
- Service management is provider-agnostic but not verified against a running
  system in tests.
- Slackware packages outside the official disk sets depend on `sbopkg` and
  SlackBuilds.org availability. `sbopkg` is pinned to a fixed release whose
  digest is compiled in; a different `HONEY_BADGER_SBOPKG_VERSION` needs
  `HONEY_BADGER_SBOPKG_SHA256`, and
  `HONEY_BADGER_ALLOW_UNVERIFIED_DOWNLOADS=1` accepts the download unchecked.
- Shell fragments target bash only.
