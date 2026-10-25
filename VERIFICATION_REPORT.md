# Ratel Forge — Verification Report

Current results on Linux, Bash 5.3:

| Suite | Checks | Result |
|-------|--------|--------|
| `verify_scripts.sh` | 174 | ✅ all passed |
| `verify_advanced.sh` | 28 | ✅ all passed |
| `test_final.sh` | 87 | ✅ all passed |
| **Total** | **289** | **✅** |

CI additionally runs `shellcheck` on every script, enforces the desktop-layer
guard, and dry-runs the installer in Arch, Debian, Fedora, Gentoo, openSUSE,
Slackware, and Void containers.

## Scope enforced by this release

Version 3.0 removes the desktop-environment layer. Ratel Forge now provisions
developer tooling only, and the following are verified to be absent from the
executable and configuration surface:

- XFCE packages and configuration channels (`xfce4-*`, `thunar`, `xfconf`)
- LightDM and other display-manager or greeter configuration
- session files, boot-target changes, runlevels, and auto-login
- GTK/Qt themes, icon themes, fonts, and wallpapers

`scripts/check-no-desktop-layer.sh` is the single source of truth for that check
and runs in `make lint`, `verify_scripts.sh`, `test_final.sh`, and CI.

## 1. Static verification — `verify_scripts.sh`

Runs without executing installer logic:

- **Syntax** — `bash -n` on every script, including the shared library, distro
  provisioners, fallback utilities, and the guard.
- **Structure** — required directories and files exist and are non-empty.
- **Hardcoded paths** — scans for absolute home paths that should use `$HOME`.
- **Required functions** — `main()` in every entry point; the full shared-library
  API surface.
- **Package managers** — each family uses its own manager.
- **Environment variable parity** — all provisioners consume
  `HONEY_BADGER_INSTALL_TYPE`, and the installer exports it.
- **Error handling** — `set -euo pipefail` in all scripts.
- **Config presence** — `nanorc` and `honey-badger-os.conf`.
- **Shared-library parity** — every provisioner sources `lib/common.sh`, uses
  `hb_sudo`, and supports all four install types.
- **Package manifests** — every family has a manifest with `BASE_PACKAGES` and
  `CLI_TOOLS_PACKAGES` sections, and its provisioner loads and installs both.
- **Desktop-layer guard** — no desktop-environment or login code anywhere.

## 2. Security and robustness — `verify_advanced.sh`

- **Security scan** — no `eval`, no `curl | bash`, no `chmod 777`, no dangerous
  `rm -rf /`, HTTPS-only downloads, registered temp files.
- **Package-name typos** — common misspellings are rejected.
- **Sudo discipline** — no unsafe raw patterns; `hb_sudo` used throughout.
- **Service management** — init-system handling per family.
- **Environment defaults** — parameter expansion with defaults.
- **Error robustness** — command existence checks and trap handlers.
- **File operations** — existence checks before modification.
- **Install-type completeness** — all seven families support all four types.
- **JSON output** — all provisioners initialise and write the summary.
- **Login configuration** — no provisioner writes `/etc/inittab`, `.xinitrc`,
  `graphical.target`, or display-manager configuration.
- **Colour control** — `NO_COLOR`, `--no-color`, `--verbose`, `--quiet`,
  `--help` are all present and functional.

## 3. Execution smoke tests — `test_final.sh`

Actually sources and runs code:

- **Syntax** — every script, including completions, assets, and the guard.
- **Sourcing** — `lib/common.sh` loads cleanly with the full API available.
- **Double-source** — sourcing twice is safe.
- **Dry-run** — `hb_sudo` prints instead of executing.
- **Idempotency** — `ensure_bashrc_line` does not duplicate entries.
- **JSON summary** — init/add/write produce a non-empty file.
- **Config** — the config sources cleanly and defines the version.
- **Config validation** — command substitution is rejected.
- **Desktop-layer guard** — the guard passes.
- **Progress** — `hb_next_step` emits `[n/total]` counters.
- **Checkpoint** — save, load, and clear.
- **Banner** — `hb_show_banner` includes the distribution name.
- **CLI** — `install.sh --help` mentions the component flags and no desktop
  flags; `--skip-theme` is rejected.
- **Type selection** — the menu prints before the prompt, is not captured into
  the summary, and the selected profile is applied.
- **Profile disk** — `--check --type full` reports the 8 GB requirement.
- **Manifest realism** — base groups stay lean and no manifest uses
  `exfat-utils`.
- **Colour** — `NO_COLOR=1` produces no ANSI escapes.
- **CLI** — `--version`, `--list-types`, and invalid `--type` exit codes.
- **Dry-run safety** — `setup_nano` writes nothing under `HOME` in dry-run.
- **Config identity** — release identity is present and no theme/wallpaper keys
  exist.
- **Manifests** — the loader populates arrays with no empty entries.
- **Phase resume** — a completed phase is skipped and only that phase.
- **Profile-aware reporting** — Minimal and Full summaries differ appropriately,
  and `honey-badger-doctor` skips toolchain checks on Minimal.
- **Shell layer** — `setup_shell` writes fragments and tool configs, passes
  `bash -n`, adds exactly one source line, is idempotent on re-run, and writes
  nothing in dry-run.
- **Extended utilities** — `install --file` reads, sanitises, and de-duplicates a
  list; `update --check` prints the recorded check command; `report` produces a
  redacted document and writes mode-600 output.
- **Profile coherence** — a component outside the selected profile (for example
  `dev` with `apps`) is reported instead of silently ignored.

## Manual verification performed for 3.0.0

- Grepped the executable and configuration surface for XFCE, Thunar, LightDM,
  greeter, session, boot-target, theme, font, and wallpaper references; zero
  matches outside the guard's own pattern.
- Reviewed all seven manifests after the desktop section was removed; no XFCE,
  Thunar, LightDM, Mousepad, or Xarchiver entries remain.
- Exercised `--help`, `--version`, `--list-types`, `--check`, and `--type` and
  confirmed the first three create no log directory, lock, or temp files.
- Confirmed `--dry-run` performs no user-level writes (nano, editor defaults,
  pip/npm installs, utility scripts).
- Verified `--components dev` and `--components apps` filter the expected groups
  and that `base` is always added.
- Verified the CLI toolkit is present in all seven manifests (including
  category-prefixed Gentoo names) and installed by every provisioner.
- Verified shell fragments, `~/.inputrc`, `~/.editorconfig`, and `bat`/`ripgrep`/
  `tmux` configuration are created under a temporary `HOME`/`XDG_CONFIG_HOME`,
  are syntax-valid, and are removed by `uninstall.sh`.
- Verified `setup_git` never overwrites an existing `git config` key.
- Verified `honey-badger-report` redacts `$HOME` and the user name while leaving
  OS and architecture strings intact.
- Verified all 28 distro/type step totals with stub package managers: every path
  ends on `[n/n]`.
- Reviewed the codebase and fixed: Debian repository setup running in dry-run,
  profile/component mismatch silence, doctor checking toolchains on profiles
  without a dev component, report not resolving Debian's `fdfind`/`batcat`,
  uninstall deleting a pre-existing `~/.config/git/ignore`, `setup_git` running
  without `git`, and an unquoted Python interpreter.
- Verified `honey-badger-info --json` and `honey-badger-doctor --json` produce
  valid JSON with the new metadata (no theme or desktop fields).
- Verified `honey-badger-uninstall` no longer references theme or XFCE paths.
- Ran the deck of seven provisioners under `HONEY_BADGER_DRY_RUN=1` and
  confirmed each accepts `full`, `developer`, `apps`, and `minimal`.

## Known limitations

- Package-name validity is not checked against live repositories.
- Service management is verified by pattern, not by querying a running system.
- Slackware package availability via `sbopkg` is not guaranteed.
- `~/.config/tmux/tmux.conf` is read by tmux 3.1 and newer; older tmux uses
  `~/.tmux.conf`, which Ratel Forge deliberately does not overwrite.
- `apps` installs GUI applications but no X11 server; the host distribution is
  expected to provide any display stack the user wants.
