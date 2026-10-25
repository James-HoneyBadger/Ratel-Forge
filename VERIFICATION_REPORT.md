# Ratel Forge — Verification Report

Current results on Linux, Bash 5.3:

| Suite | Checks | Result |
|-------|--------|--------|
| `verify_scripts.sh` | 157 | ✅ all passed |
| `verify_advanced.sh` | 28 | ✅ all passed |
| `test_final.sh` | 75 | ✅ all passed |
| **Total** | **260** | **✅** |

CI additionally runs `shellcheck` on every script, lints both themes for
structure and contrast, and dry-runs the installer in Arch, Debian, Fedora,
Gentoo, openSUSE, Slackware, and Void containers.

## 1. Static verification — `verify_scripts.sh`

Runs without executing installer logic:

- **Syntax** — `bash -n` on every script, including the shared library, distro
  provisioners, and fallback utilities.
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
- **Package manifests** — every family has a manifest with a `BASE_PACKAGES`
  section, and its provisioner loads that exact file.

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
- **Colour control** — `NO_COLOR`, `--no-color`, `--verbose`, `--quiet`,
  `--help` are all present and functional.

## 3. Execution smoke tests — `test_final.sh`

Actually sources and runs code:

- **Syntax** — every script, including completions and assets.
- **Sourcing** — `lib/common.sh` loads cleanly with the full API available.
- **Double-source** — sourcing twice is safe.
- **Dry-run** — `hb_sudo` prints instead of executing.
- **Idempotency** — `ensure_bashrc_line` does not duplicate entries.
- **JSON summary** — init/add/write produce a non-empty file.
- **Config** — the palette config sources cleanly and defines the version.
- **Config validation** — command substitution is rejected.
- **Theme** — GTK3 CSS exists with `@define-color`; GTK2 file exists.
- **Progress** — `hb_next_step` emits `[n/total]` counters.
- **Checkpoint** — save, load, and clear.
- **Banner** — `hb_show_banner` includes the distribution name.
- **CLI** — `install.sh --help` mentions the component flags.
- **Type selection** — the menu prints before the prompt, is not captured into
  the summary, and the selected profile is applied.
- **Profile disk** — `--check --type full` reports the 9 GB requirement.
- **Manifest realism** — base groups stay lean and no manifest uses
  `exfat-utils`.
- **Colour** — `NO_COLOR=1` produces no ANSI escapes.
- **CLI** — `--version`, `--list-types`, and invalid `--type` exit codes.
- **Dry-run safety** — `setup_nano` writes nothing under `HOME` in dry-run.
- **Theme metadata** — metatheme name and palette tokens agree.
- **Manifests** — the loader populates arrays with no empty entries.
- **Phase resume** — a completed phase is skipped and only that phase.

## Manual verification performed for 2.4.0

- Rendered the banner, section headers, severity lines, and key/value rows in a
  pseudo-TTY; verified box alignment and colour degradation.
- Exercised `--help`, `--version`, `--list-types`, `--check`, and `--type` and
  confirmed the first three create no log directory, lock, or temp files.
- Confirmed `--dry-run` performs no user-level writes (nano, theme, GTK and XFCE settings, pip/npm installs, utility scripts).
- Reviewed the GTK3 stylesheet for invalid selectors (`* { background }`,
  GTK2-style `.class` names) and removed them.
- Verified the icon theme descriptor inherits a real icon set rather than
  pointing at an empty directory.
- Verified all 750 package entries are byte-identical before and after the move
  to manifests (parsed comparison against the previous arrays).
- Verified `--components dev` skips the base group and `--resume` skips a
  pre-recorded `update` phase.
- Verified `honey-badger-theme` status/apply/list/palette and
  `honey-badger-doctor` exit codes in a clean temporary home.
- Ran a full dry-run end to end: 13/13 steps, zero files written under `HOME`,
  and dry-run messages report intent rather than success.
- Simulated all seven provisioners with stub package managers to measure step
  budgets (4–21 depending on family and type), confirming no `[n/n+1]` counters.
- Verified skip mode (`--skip-theme`) prints `[n]` without a fraction.

## Known limitations

- Package-name validity is not checked against live repositories.
- Service management is verified by pattern, not by querying a running system.
- Slackware package availability via `sbopkg` is not guaranteed.
- GTK3 theme requires GTK 3.20+ (2016 or newer); GTK2 apps use the palette-only
  theme.
- Wallpaper generation needs ImageMagick; without it, the step is skipped with a
  warning.
