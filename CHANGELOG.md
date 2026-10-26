# Changelog

All notable changes to Ratel (formerly Honey Badger OS) are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.2] - 2026-10-26

### Fixed
- **Debian/Ubuntu provisioning aborted at the repositories step on systems that
  already ship VS Code's deb822 `vscode.sources`.** The installer wrote a
  second definition of the same repository with a different `Signed-By`, so apt
  rejected every command with `Conflicting values set for option Signed-By
  regarding source https://packages.microsoft.com/repos/code`. An existing VS
  Code source definition is now reused, and the only file ever removed is the
  installer's own `sources.list.d/vscode.list` — `/etc/apt/sources.list` and
  hand-written entries are never touched.
- **GitHub CLI keyrings kept `mktemp`'s `0600` mode**, so apt's `_apt` user
  could not read them and signature verification failed. Keyrings are installed
  `0644`.
- **The NodeSource setup script was downloaded and executed as root** with only
  a shebang check. The Node.js repository is now configured like the others —
  signed keyring plus a `nodistro` source entry — with the major version pinned
  via `HONEY_BADGER_NODE_MAJOR`.
- **The lock file lived at `/tmp/honeybadger-install.lock`**, where another
  local user could pre-create a symlink and have the installer truncate the
  target (it was opened before the root check). State now lives under
  `~/.local/share/honey-badger/`, and the file is opened append-only and never
  unlinked.
- **The JSON summary was written with `>` to a predictable `/tmp` path** and
  followed symlinks. It is now written to a private temp file and renamed.
- **Config validation could be bypassed with `KEY=value command …`.** Values
  must now be a bare word, a single-quoted string, or a double-quoted string
  containing only plain text and `${VAR}`/`${VAR:-default}` references.
- **A corrupted checkpoint file aborted the installer** (`abc: unbound
  variable`) because the state file was sourced. It is now parsed defensively.
- **Uninstall discarded edits made after installation** for `.nanorc`,
  `.inputrc`, `.editorconfig`, and the bat/ripgrep/tmux configs by restoring the
  pre-install backup over them; the backup is now restored only while the file
  is still the managed version. Uninstall also cancels cleanly instead of
  exiting 1 when stdin is closed.
- **`sbopkg` was resolved from `releases/latest` and installed as root** with no
  digest. It is pinned to 0.38.2 and verified against a built-in SHA-256; a
  different `HONEY_BADGER_SBOPKG_VERSION` needs `HONEY_BADGER_SBOPKG_SHA256`, and
  `HONEY_BADGER_ALLOW_UNVERIFIED_DOWNLOADS=1` opts out explicitly.
- **Smaller corrections:** downloads are restricted to HTTPS for redirects;
  unattended Debian runs set `DEBIAN_FRONTEND=noninteractive` and keep existing
  dpkg config files; Arch updates with a single `pacman -Syu`; openSUSE no
  longer points SLES at a Leap Packman repository; the Debian Flatpak check no
  longer treats app IDs as regexes; `honey-badger-doctor` expects
  `honey-badger-report`; the npm `PATH` fragment quotes its directory; the
  interrupt message no longer claims the failed step was completed.

### Added
- Regression tests for apt-source reconciliation, the state-file and uninstall
  guarantees, the config-validator bypass, and corrupted checkpoints.
- Toolkit coverage: Debian/Ubuntu now install `yq`, `shfmt`, `tokei`, and
  `neovim`; Gentoo gains `app-misc/yq` and `dev-util/git-delta`; Slackware gains
  `tree` from its official tree. Packages a family does not ship are still
  reported as warnings rather than failures.

## [3.0.1] - 2026-10-26

Fixes found during a full review of the 3.0.0 provisioning rewrite.

### Fixed
- **`--skip-docker` only skipped configuration.** Docker packages are now
  filtered from every manifest. Slackware no longer skips git/python/node setup
  when Docker cannot be installed, and Void no longer enables the Docker service
  when the flag is set.
- **Docker group membership was never recorded for uninstall.** It is written to
  the rollback manifest, removed by `uninstall.sh`, and matched by exact group
  name rather than a substring.
- **Configuration validation only warned about unknown keys.** Unknown keys,
  malformed assignments, command substitution, and shell metacharacters are now
  rejected before the file is sourced.
- **Dry runs wrote logs under `$HOME`.** Dry-run logs go to a temporary
  directory; no empty log file is created on every run, and invalid
  `HONEY_BADGER_LOG_COUNT` values fall back to 5 instead of aborting startup.
- **Uninstall could restore a stale `.bashrc`.** It now restores the pre-install
  backup only when no user edits remain, removes the expanded npm `PATH` line,
  and no longer aborts when a managed line was the last line in the file.
- **CI dry-runs could not fail.** Each provisioner now runs the minimal and full
  profiles and the job fails unless the completion summary is reached.
  ShellCheck now covers every library module.
- **The Full disk check failed on hosts with less free space than the
  requirement** even though the requirement was applied correctly.
- **Added regression tests** for component/base handling, config validation,
  `--skip-docker`, log rotation, dry-run write safety, and manifest duplicates.

### Upgrading from 2.x
3.0 removed desktop provisioning. Leftover 2.x desktop files are no longer
managed by the installer or uninstaller. Remove `~/.themes/Ratel*`,
`~/.icons/Ratel`, `/usr/share/themes/Ratel*`,
`/usr/share/backgrounds/honeybadger.jpg`, and Ratel Forge LightDM drop-ins under
`/etc/lightdm/`, and clear any `user-session=xfce` line.

## [3.0.0] - 2026-10-25

**Ratel Forge is now a developer provisioning system, not a desktop installer.**

### Removed
- **The entire desktop-environment layer.** Ratel Forge no longer installs or
  configures XFCE, Thunar, LightDM, a greeter, session files, boot targets,
  GTK/icon themes, fonts, or wallpapers. Desktop and login configuration are
  left entirely to the distribution.
- `lib/theme.sh`, `theme/`, `assets/honey-badger-theme`,
  `scripts/generate_theme_variants.py`, `scripts/lint-theme.py`, and
  `scripts/theme-screenshot.sh`.
- The `desktop` install type and the `desktop` component.
- The `--high-contrast`, `--font-size`, `--skip-theme`, and `--no-theme` flags,
  `HONEY_BADGER_HIGH_CONTRAST`, `HONEY_BADGER_THEME_VARIANT`,
  `HONEY_BADGER_THEME_*`, `HONEY_BADGER_FONT`, `HONEY_BADGER_MONO_FONT`, and
  `HONEY_BADGER_WALLPAPER_SIZE`.
- `theme_variant` from the install summary schema.
- XFCE, Thunar, LightDM, Mousepad, and Xarchiver entries from every package
  manifest.

### Changed
- **Install types** are now `full`, `developer`, `apps`, and `minimal`
  (`desktop` is replaced by `apps`).
- **Components** are now `base`, `dev`, and `apps`.
- `honey-badger-info` and `honey-badger-doctor` report toolchain and installation
  data only; `doctor` checks toolchains instead of themes.
- `lib/theme.sh` became `lib/editor.sh` and contains only nano setup.
- The post-install summary no longer suggests rebooting into a desktop session.

### Added
- **`honey-badger-update --check`** lists available system, Flatpak, and Snap
  updates without installing them. Each family records a check command in
  `pm.conf` (e.g. `pacman -Qu`, `apt list --upgradable`).
- **`honey-badger-install --file <list>`** installs packages from a plain-text
  list, ignoring comments and blank lines and de-duplicating entries.
- **`honey-badger-report`** collects a redacted environment report (install
  metadata, system, tool versions, doctor diagnostics, log tail) for bug reports.
  `--output` writes a mode-600 file; `--no-log` omits the log tail.
- **`honey-badger-doctor` v2** additionally checks duplicate `PATH` entries,
  shell-fragment installation, `EDITOR`, `~/.ssh` permissions, UTF-8 locale,
  inotify watch limits, the npm global prefix, and the Docker socket.
- **Shell and tool settings** for every profile: fragments in
  `~/.config/ratel/shell/` sourced by one `~/.bashrc` line, `~/.inputrc` history
  search, `~/.editorconfig`, and configuration for `bat`, `ripgrep`, and `tmux`.
  `--skip-shell` opts out. No login, PAM, or `/etc/profile` files are touched.
- **Git quality defaults** when the key is unset: `merge.conflictStyle=zdiff3`,
  `rerere`, `rebase.autoStash`, `push.autoSetupRemote`, `fetch.prune`, a global
  ignore file, an auto-detected `core.editor`, and `delta` as pager plus
  `interactive.diffFilter` when it is installed.
- **Modern CLI toolkit** in a new `CLI_TOOLS_PACKAGES` manifest section,
  installed with the base component on every profile: `jq`, `ripgrep`, `fd`,
  `bat`, `fzf`, `zoxide`, `direnv`, `git-delta`, `shellcheck`, `shfmt`,
  `hyperfine`, `tokei`, `ncdu`, `btop`, `httpie`, and `yq` where available.
  Debian/Ubuntu use the `fd-find` and `bat` package names (commands `fdfind`
  and `batcat`).
- `scripts/check-no-desktop-layer.sh`, a CI guard that fails the build if
  desktop-environment, display-manager, greeter, session, boot-target, theme, or
  wallpaper code reappears.

## [2.5.0] - 2026-10-25

Post-install polish: the utilities now describe what was actually installed and
all of them can be run without the checkout.

### Added
- **`honey-badger-uninstall`** — the uninstaller is installed alongside the
  other commands, so removal no longer requires the repository. It removes the
  theme, all six commands, generated configuration, and install metadata; system
  packages are deliberately left alone.
- **`honey-badger-info --json`** and **`honey-badger-doctor --json`** — the same
  data as the human-readable output, for scripts and dashboards.
- **`honey-badger-update` options**: `--dry-run`, `--no-flatpak`, `--no-snap`,
  `--no-clean`, plus a reboot-required notice.
- **`honey-badger-install` actions**: `--search <term>` and `--remove`, in
  addition to installing, each with `--dry-run`.
- **Bash completion** is now installed to
  `~/.local/share/bash-completion/completions/honey-badger`.
- **Metadata**: `install-info` records the effective components, whether a
  desktop is installed, the theme variant, fonts, and the install log;
  `pm.conf` records update/install/clean/search/remove commands.
- **Install summary JSON** gains `components` and `theme_variant`, and the
  schema requires them.

### Fixed
- **`honey-badger-doctor` failed on Minimal installs** because no theme is
  installed by design. Theme checks are now skipped with an explanation instead
  of reported as a hard failure, and the utilities check lists exactly which
  commands are missing.
- **`honey-badger-theme` now explains itself on Minimal installs** instead of
  reporting a missing theme, and `apply` refuses with a clear message.
- **Post-install summary was the same for every profile**: a Minimal install was
  told to reboot and offered `honey-badger-theme`. Reporting is now profile
  aware — CLI guidance for Minimal, desktop guidance (reboot, theme, doctor)
  only when a desktop was installed.
- **`--components` could silently drop the base group**, leaving a system
  without `git`, `curl`, or a package manager client. `base` is now always
  included, listed first, and the addition is noted.
- **Options that cannot apply are no longer advertised**: `--high-contrast`,
  `--font-size`, and `--skip-theme` on a Minimal install (or with the `desktop`
  component disabled) now produce a clear warning instead of appearing in the
  summary as if they would take effect.
- **Slackware and Gentoo utility commands**: `slackpkg` cleanup was a bare
  `echo`, and `emerge --ask` blocked the generated installer command. Both are
  now non-interactive, and every family records a real search and remove
  command.
- **Utilities no longer break if the data directory is deleted**: they fall back
  to inline UI helpers instead of failing with `command not found`.
- **`uninstall.sh` missed the newer commands** (`honey-badger-theme`,
  `-doctor`, `-uninstall`) and the installed completion file.

### Changed
- Utility commands are installed from `assets/` (single source of truth) instead
  of being generated from heredocs, so they are linted and tested like the rest
  of the project.
- **Tests** — 261 checks (was 240), adding metadata, component-normalisation,
  option-coherence, utility dry-run, and profile-aware reporting coverage.

## [2.4.1] - 2026-10-25

### Fixed
- **The installation-type menu never appeared at the prompt.** It was printed
  inside a command substitution, so the text was captured into the return value
  and leaked into the summary afterwards. Selection now sets
  `HB_SELECTED_TYPE`, the menu prints normally, and `?` redisplays it.
- **Disk requirements ignored the chosen profile.** The type is selected before
  pre-flight now, so a Full install requires 9 GB rather than the baseline 1 GB.

### Changed
- **Realistic profile sizes**: Full 6-9 GB, Developer 2-4 GB, Desktop 3-5 GB,
  Minimal 0.3-0.8 GB, with matching pre-flight thresholds.
- **Honest component groups**: compilers, GUI networking, audio, fonts, and disk
  tools moved out of `BASE_PACKAGES` into developer/desktop groups. Minimal now
  installs a genuinely minimal CLI set, and Developer no longer pulls office or
  media applications.
- **Debian repositories**: use the distribution's `docker.io`/`docker-compose`
  instead of Docker's repository, which conflicted with them and broke on
  derivatives with non-Ubuntu codenames. VS Code is installed from its apt repo
  only (the duplicate snap entry is gone), the NodeSource floor is Node 20, and
  non-free `rar`/`unrar` were dropped.
- **Package availability**: Fedora, openSUSE, and Void now filter packages the
  repositories do not have instead of failing the whole batch.
- **Tests** — 240 checks (was 234), adding type-selection, profile-disk, and
  manifest-realism coverage.

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
