# Contributing to Ratel Forge

Thanks for helping. This guide covers conventions, the test workflow, and the two
most common changes: adding a distribution and adding a CLI option.

## Quick start

```bash
git clone https://github.com/James-HoneyBadger/Ratel-Forge.git
cd Ratel-Forge

bash verify_scripts.sh      # static checks
bash verify_advanced.sh     # security & robustness
bash test_final.sh          # execution-level smoke tests
```

All three suites must pass. CI also runs `shellcheck` and dry-runs the installer
inside seven distribution containers.

Before changing behaviour, read:

- [docs/TECHNICAL_REFERENCE.md](docs/TECHNICAL_REFERENCE.md) — module APIs, data
  formats, invariants
- [docs/INSTRUCTIONS.md](docs/INSTRUCTIONS.md) — procedures for adding a
  distribution, package, option, phase, utility, or doctor check
- [docs/USER_MANUAL.md](docs/USER_MANUAL.md) — the user-facing contract

## Repository layout

| Path | Contents |
|------|----------|
| `install.sh` | Universal entry point and install-type catalogue |
| `lib/common.sh` | Core runtime: config, sudo, progress, resume, JSON |
| `lib/ui.sh` | Colours, glyphs, layout, logging, prompts, banner |
| `lib/packages.sh` | Manifest loader |
| `lib/editor.sh` | Nano configuration and editor defaults |
| `lib/utilities.sh` | Utility generation and post-install report |
| `distros/<family>/` | One provisioner per family |
| `config/` | Runtime configuration, nano config |
| `config/packages/` | Package manifests, one per family |
| `assets/` | Standalone fallback utility scripts and logo |
| `completions/` | Bash and Zsh completions |
| `scripts/` | Desktop-layer guard |
| `schema/` | JSON schema for the install summary |
| `docs/` | User manual, technical reference, and task instructions |

## Coding conventions

- Every executable script starts with `#!/bin/bash` and `set -euo pipefail`.
- Quote everything: `"$var"`, `"${arr[@]}"`. Never rely on word splitting.
- **No `eval`.** Never pipe a download into a shell; save it to a temp file,
  register it with `hb_register_temp`, then execute it.
- All privileged work goes through `hb_sudo`, never raw `sudo` in new code.
- Prefer arrays for package lists and pass them with `"${packages[@]}"`.
- Check for commands with `command -v` before calling them.
- Keep functions small and side-effect free where possible; return values on
  stdout and diagnostics on stderr.

### UI conventions

User-facing output must use the shared vocabulary in `lib/common.sh`:

| Helper | Use for |
|--------|---------|
| `hb_section "Title"` | A new phase of work |
| `hb_rule` | A closing or separating line |
| `hb_kv key value` | Aligned key/value rows |
| `hb_next_step "…"` | A numbered step (prints `[n/total]`) |
| `log_info` / `log_success` / `log_warning` / `log_error` | Status lines |
| `log_debug` | Verbose-only detail |
| `hb_prompt "Label" [default]` | Reading a value (echoes only the answer) |
| `hb_confirm "Question" [yes\|no]` | Yes/no decisions |
| `hb_dry_run` | Early-return guard for mutating functions |

Rules:

- Do not hand-roll `echo -e` banners or bespoke colour codes in provisioners.
- Keep glyphs Unicode but never assume them: the library falls back to ASCII.
- Add a `hb_dry_run` guard to every function that writes user files or runs
  package managers, so `--dry-run` stays truthful.
- Prompts must default safely (typically `no`) and respect non-interactive mode.

### Style

- 4-space indentation, no tabs.
- Section banners use `# ── Title ─────…`.
- Comment *why*, not *what*; keep comments off obvious lines.
- Keep line length reasonable (~100 columns).

## Adding a distribution

1. Create `distros/<family>/install-<family>.sh`:
   ```bash
   #!/bin/bash
   # Ratel Forge — <Family> provisioner
   set -euo pipefail
   source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/common.sh"
   hb_init_distro_log "<family>"

   show_banner() { hb_show_banner "<Label>" "<Family>-based provisioning"; }

   main() {
       hb_json_init
       hb_rollback_init
       export HONEY_BADGER_DISTRO="<family>"
       local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
       case "$install_type" in
           full)      hb_set_total_steps 11 ;;
           developer) hb_set_total_steps 10 ;;
           apps)      hb_set_total_steps 8  ;;
           minimal)   hb_set_total_steps 4  ;;
       esac
       show_banner
       # … update, install packages by type, setup_nano, create_utility_scripts …
       show_post_install
   }
   main "$@"
   ```
2. Support all four install types (the tests enforce the literals `full`,
   `developer`, `apps`, `minimal`).
3. Pass the correct update/install/clean commands to `create_utility_scripts`.
4. Add detection to `install.sh` in all three layers: `/etc/os-release` IDs,
   `ID_LIKE`, and package-manager or release-file fallbacks.
5. Add the family to `.github/workflows/ci.yml` if a usable container exists.
6. Update the distribution tables in `README.md`, `USER_GUIDE.md`, and
   `PROJECT_OVERVIEW.md`.

## Adding a CLI option

1. Parse it in the `while` loop **before** `lib/common.sh` is sourced, so
   `--help` and friends remain side-effect free.
2. Prefer exporting an `HONEY_BADGER_*` environment variable over adding a new
   global.
3. Add the flag to `show_help`.
4. Add it to `completions/honey-badger.bash` and `completions/honey-badger.zsh`.
5. Add a smoke test in `test_final.sh` when the option has observable behaviour.
6. Document it in `README.md` (CLI table) and `USER_GUIDE.md` when relevant.

## Desktop scope

Ratel Forge provisions developer tooling only. Do not add code that installs or
configures:

- desktop environments or window managers
- display managers, greeters, or session files
- boot targets, runlevels, or auto-login
- GTK/Qt themes, icon themes, fonts, or wallpapers

`scripts/check-no-desktop-layer.sh` runs in `make lint` and CI and fails if any
of those reappear.

## Changing packages

Do not edit arrays in a provisioner. Edit the manifest instead:

```
config/packages/<family>.conf
```

Sections such as `[BASE_PACKAGES]` become arrays of the same name. Add one entry
per line; entries may contain spaces. `verify_scripts.sh` checks that every
family has a manifest with a `BASE_PACKAGES` section and that its provisioner
loads it.

## Testing requirements for a pull request

```bash
make lint    # bash -n, shellcheck (if installed), desktop-layer guard
make test    # the three suites
make check   # both, matching CI
```

Individual suites remain runnable directly:

```bash
bash verify_scripts.sh
bash verify_advanced.sh
bash test_final.sh
```

## Commit and pull request

- One logical change per commit; use the imperative mood
  (`Add openSUSE detection`, not `Added…`).
- Reference the issue in the PR description.
- Describe user-visible behaviour changes and how you verified them.

## Release checklist

1. Bump `HONEY_BADGER_VERSION` and `HONEY_BADGER_BUILD_DATE` in
   `config/honey-badger-os.conf` (they use `${VAR:-default}`, so environment
   overrides keep working).
2. Update `show_version`'s fallback (`install.sh`) if the default changed.
3. Add a `CHANGELOG.md` entry under a new version heading.
4. Run all three suites and the container dry-runs.
5. Tag the release.
