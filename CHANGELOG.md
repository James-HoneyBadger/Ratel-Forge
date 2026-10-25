# Changelog

All notable changes to Ratel (formerly Honey Badger OS) are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.4.0] - 2026-10-25

Everything from the follow-up improvement list: structure, data, resume,
component selection, new utilities, accessibility, integrity, and tooling.

### Added
- **Layered library** — `lib/common.sh` (~600 lines) now composes
  `lib/ui.sh` (terminal UI), `lib/packages.sh` (manifest loader),
  `lib/theme.sh` (desktop), and `lib/utilities.sh` (commands + report). Each has
  its own double-source guard and shellcheck directives.
- **Package manifests** — `config/packages/<family>.conf` holds every package
  list as reviewable data. All 750 entries were migrated with a parsed
  before/after comparison to prove parity.
- **Phase-based resume** — `hb_phase <id> <command>` records completed phases;
  `--resume` skips them and refuses state from a different distro or install
  type. Fresh runs reset the state.
- **Component selection** — `--components base,dev,desktop,apps` filters package
  groups and the desktop/dev setup that depends on them.
- **`honey-badger-theme`** — `status`, `apply [default|high-contrast]`, `list`,
  and `palette` (renders swatches from generated palette metadata).
- **`honey-badger-doctor`** — checks theme installation, icon descriptor, GTK and
  XFCE settings, PATH, metadata, Git identity, Docker group, and package manager;
  exits non-zero on hard failures.
- **High-contrast theme** — generated `Ratel-HC` variant with pure-black
  surfaces, 2 px borders, 3 px focus rings, and AAA contrast. Both variants are
  installed so switching is live. Enable at install time with
  `--high-contrast`.
- **Font sizing** — `--font-size N` (8–24) sets UI and monospace fonts.
- **Verified downloads** — `hb_download` writes to a temp file, rejects empty
  responses, and verifies SHA-256 when supplied. Per-artifact checksum variables
  and `HONEY_BADGER_REQUIRE_CHECKSUMS=1` fail closed.
- **Tooling** — `Makefile` and `justfile` (`lint`, `test`, `check`, `theme`),
  `scripts/lint-theme.py` (structure, selectors, WCAG contrast),
  `scripts/generate_theme_variants.py`, and
  `schema/honeybadger-summary.schema.json`.

### Changed
- **Renamed to Ratel Forge** — repository (`James-HoneyBadger/Ratel-Forge`),
  display name, banner wordmark, documentation, and user-facing messages. GTK
  theme IDs stay `Ratel` / `Ratel-HC`, and all `HONEY_BADGER_*` identifiers and
  `honey-badger-*` commands are unchanged.
- **Configuration is genuinely env-overridable** — every value now uses
  `${VAR:-default}`; previously the file overwrote exported variables, so the
  documented override behaviour did not work.
- **Theme installation** — installs both variants to the user and system theme
  directories, and the LightDM/XFCE appearance follows the selected variant and
  configured fonts.
- **Themes are part of CI** — the theme lint step checks palette coverage,
  required widget selectors, and contrast ratios for both variants.
- **Tests** — 234 checks (was 193), including manifests, resume, CLI validation,
  dry-run write safety, and theme metadata.

### Fixed
- **Step counters could exceed the plan** — a full Arch run printed `[13/12]`.
  Budgets are now measured per distro/type, the counter self-corrects when a
  flow adds steps, and skip/component runs fall back to `[n]` rather than a
  denominator that does not add up.
- **Dry-run pipelines died with SIGPIPE (status 141)** — `hb_sudo` now drains
  stdin, so `cmd | hb_sudo tee file` works in dry-run.
- **Dry-run reported real success** — "System updated successfully" and
  "Installed … packages" are replaced by "Would update/install …".
- **Arch package checks ignored groups** — `xfce4` and `xfce4-goodies` are
  groups, not packages, so they were reported as unavailable. The check now
  resolves groups, and the manifest uses `7zip`/`fastfetch` (their predecessors
  left the repositories).
- **Slackware installs aborted after the first package** — `((installed++))`
  returns status 1 when the old value is 0, which kills a `set -e` script. The
  uninstaller had the same `((removed++))` bug.
- `--version` parsing of the new `${VAR:-default}` config format.
- Component guards log the actual package group rather than a variable name.
- `honey-badger-theme` palette resolution and status output.
- Uninstaller removes both theme variants.

## [2.3.0] - 2026-10-25

**Ratel.** A full look-and-feel and usability overhaul, plus fixes for several
real defects found while reviewing the installer end to end.

### Added
- **Brand: Ratel** — the honey badger's proper common name. Chosen because the
  project is a provisioning framework, not an operating system, so the `OS`
  suffix was dropped. `HONEY_BADGER_*` environment variables and
  `honey-badger-*` commands are unchanged for compatibility.
- **New CLI options** — `--version`, `--list-types`, `--check`, `--yes`,
  `--type`, `--no-banner`, `--ascii`, and `--skip-git`. `--help`, `--version`,
  and `--list-types` run before the shared library is sourced and therefore have
  no side effects.
- **Single install-type catalogue** — one source of truth drives the menu, the
  summary, and `--list-types`, so the three can no longer drift apart.
- **Terminal design system** (`lib/common.sh`) — `hb_section`, `hb_rule`,
  `hb_kv`, `hb_prompt`, `hb_confirm`, `hb_dry_run`, `hb_term_width`, plus
  severity glyphs with automatic ASCII fallback and a 256-colour palette.
- **Refined banner** — width-aware box, wordmark, and a metadata line with
  version, codename, distribution, install type, and mode.
- **GTK3 theme rewrite** — imports the Adwaita dark baseline, then overrides the
  palette and every surface that defines the character (header bars, buttons,
  entries, menus, tabs, scrollbars, switches, scales, progress/level bars,
  sidebars, tree views, popovers, tooltips, infobars, status bars, links, focus
  rings).
- **GTK2 theme rewrite** — palette parity for legacy apps with no engine
  dependency.
- **Icon theme descriptor** — inherits `hicolor, Adwaita, gnome, Humanity`, so
  no icon resolves to a blank square.
- **XFCE appearance channels** — `xsettings.xml` and `xfwm4.xml` are written for
  theme, icons, fonts, antialiasing, compositing, four workspaces, and a modern
  button layout; applied live when `xfconf-query` is present.
- **System-wide theme install** — `/usr/share/themes/Ratel` in addition to the
  user copy, so LightDM and other accounts can use it.
- **Utility UI library** — `~/.local/share/honey-badger/ui.sh` plus
  `install-info` metadata shared by `honey-badger-info`, `-update`, and
  `-install`, which now render consistently with the installer.
- **Docs** — rewritten README with a CLI reference, palette table, and
  architecture notes; refreshed user guide, project overview, contributing
  guide, and verification report.

### Changed
- **Logging** — severity glyphs with aligned output on the terminal, and
  timestamped, ANSI-free lines in log files for direct provisioner runs.
- **Dry-run is now truthful** — user-level steps (nano, theme, wallpaper, Git
  identity, pip, npm, utility scripts, XFCE settings) return early instead of
  writing files. Previously only `sudo` commands were suppressed.
- **Config** — palette keys replaced with semantic tokens (`_BG`, `_SURFACE`,
  `_BASE`, `_BORDER`, `_TEXT`, `_MUTED_TEXT`, `_ACCENT`, `_ACCENT_TEXT`,
  `_WARNING`, `_ERROR`, `_SUCCESS`, `_INFO`) plus `_FONT` and `_MONO_FONT`.
- **Completions** — Bash and Zsh now cover every flag and complete install-type
  values.
- **Uninstaller** — knows the Ratel theme paths (user, system, legacy), restores
  GTK and XFCE settings from backup, and reports what it will remove.

### Fixed
- **Distribution detection polluted its own result** — `detect_distribution`
  logged to stdout while also echoing the family, so `distro=$(detect_distribution)`
  captured log text and produced a path containing a newline. It now sets
  `HB_DISTRO_FAMILY`/`HB_DISTRO_LABEL` and emits nothing.
- **GTK3 theme was effectively broken** — a `* { background-color: … }` rule
  painted every widget and destroyed depth; class selectors such as `.button`
  and `.menubar` do not match GTK3 widget names. Both issues are gone.
- **Icon theme pointed at an empty directory** — `IconTheme=HoneyBadger`
  resolved to nothing; it now inherits the system set.
- **LightDM could not see the theme** — it was installed only under `$HOME`,
  which the greeter cannot read; a system-wide copy is now installed.
- **`honey-badger-info` always reported version 1.0.0** — the quoted heredoc
  prevented interpolation; the version now comes from generated metadata.
- **Dry-run created real files** — see "Dry-run is now truthful" above.

### Removed
- Legacy `HONEY_BADGER_THEME_PRIMARY/SECONDARY` config keys (superseded by the
  semantic palette).

## [2.1.0] - 2026-04-02

### Added
- **openSUSE support** (`distros/opensuse/install-opensuse.sh`) — zypper package manager, Packman multimedia repository, XFCE patterns, Tumbleweed/Leap/SLES/GeckoLinux detection
- **Gentoo support** (`distros/gentoo/install-gentoo.sh`) — emerge/Portage package manager, category/package naming, OpenRC + systemd dual init support, Funtoo detection
- **CI matrix expansion** — openSUSE Tumbleweed and Gentoo Stage3 container dry-runs in GitHub Actions (8 distros total)

### Changed
- **`install.sh` detection** — Added os-release, ID_LIKE, package manager (`zypper`, `emerge`), and file-based (`/etc/SuSE-release`, `/etc/gentoo-release`) fallback detection for openSUSE and Gentoo
- **Test suite counts** — Updated `verify_scripts.sh`, `verify_advanced.sh`, and `test_final.sh` for 7-distro coverage (176 total tests)
- **Documentation** — README, PROJECT_OVERVIEW, USER_GUIDE, CONTRIBUTING, and VERIFICATION_REPORT updated for 7-distro support

### Fixed
- **Gentoo CI timeout** — Use `emerge-webrsync` instead of `emerge --sync` for fast Portage tree population in CI containers

## [2.0.0] - 2026-04-02

### Added
- **Shared library** (`lib/common.sh`) — eliminates code duplication across all 5 distro scripts
- **`--help` flag** — shows usage, flags, environment variables, and supported distros
- **`--no-color` flag** — disables colored output; also honors `NO_COLOR` env var (no-color.org)
- **`--verbose` / `--quiet` flags** — control log verbosity (debug, normal, errors-only)
- **`--skip-docker`, `--skip-python`, `--skip-node`, `--skip-nano`** — granular component control
- **Signal trapping & cleanup** — removes temp files and saves checkpoint on interrupt
- **Lock file** — prevents concurrent `install.sh` runs via `flock`
- **Config backup** — backs up `~/.bashrc`, `~/.nanorc`, `/etc/inittab` before overwriting (`.hb-backup`)
- **Checkpoint / resume** — interrupted installs can resume from the last successful step
- **Rollback manifest** — records installed packages and changed files for potential uninstall
- **Persistent logging** — logs rotate (keep 5) in `~/.local/share/honey-badger/logs/`
- **Network check hardening** — uses DNS resolution, `host`, `ping`, and `curl` fallback chain
- **`log_debug()` function** — for verbose/dev-mode output
- **`hb_check_network()`** — portable connectivity check that works behind firewalls
- **`hb_skip_component()`** — checks `HONEY_BADGER_SKIP_*` env vars
- **`hb_register_temp()`** — registers temp files for automatic cleanup on exit/signal
- **`hb_backup_file()`** — creates `.hb-backup` copy before overwriting configs
- **Input validation** — `honey-badger-install` validates package names against `[a-zA-Z0-9._+:-]`
- **`--help` on all utilities** — `honey-badger-info`, `honey-badger-update`, `honey-badger-install`
- **GitHub Actions CI** — syntax checking, ShellCheck, test suites, per-distro dry-run in containers
- **Shell completions** — Bash and Zsh completions for `install.sh` and utility scripts
- **CHANGELOG.md** — this file
- **CONTRIBUTING.md** — contributor guide with distro-addition walkthrough
- **Expanded config reference** — `honey-badger-os.conf` fully documented with all variables

### Changed
- **Version bumped** to 2.0.0
- **Config `HONEY_BADGER_DEV_MODE`** now wired up — enables verbose logging when `true`
- **Log files** moved from `/tmp/` to `~/.local/share/honey-badger/logs/` with rotation
- **Colors** respect `NO_COLOR`, non-TTY detection, and `--no-color`
- **Logging functions** respect `HONEY_BADGER_VERBOSITY` levels (quiet/normal/verbose)
- **File permissions** on utility scripts set explicitly to `755` instead of `chmod +x`
- **JSON array building** uses `[@]+"${[@]}"` pattern to avoid unbound variable errors on empty arrays

### Fixed
- **Slackware non-interactive breakage** — no longer prompts for mirror config when `--non-interactive`; auto-enables a mirror instead
- **Hardcoded sbopkg URL** — now resolves latest release from GitHub API with fallback
- **Temp file leak** — Debian Node.js setup and Slackware sbopkg temp files registered for cleanup on signal
- **Arch yay temp directory** — registered for cleanup if build is interrupted
- **`/etc/inittab` overwrite** — now backed up before modification on Slackware
- **`~/.xinitrc` overwrite** — now backed up before modification
- **Unknown CLI flags** — `install.sh` now errors on `--unknown` instead of silently ignoring

## [1.0.0] - 2024-01-01

### Added
- Initial release with Arch, Debian, Fedora, Void, and Slackware support
- Four installation types: full, developer, desktop, minimal
- XFCE desktop environment configuration
- Honey Badger GTK2/GTK3 theme
- Nano editor enhanced configuration
- Docker, Python, Node.js development environment setup
- Dry-run mode (`--dry-run`)
- Non-interactive mode (`--non-interactive`)
- Progress tracking with step counters
- JSON installation summary output
- Three-tier test suite (verify_scripts.sh, verify_advanced.sh, test_final.sh)
