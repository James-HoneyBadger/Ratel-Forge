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

## Repository layout

| Path | Contents |
|------|----------|
| `install.sh` | Universal entry point and install-type catalogue |
| `lib/common.sh` | Core runtime: config, sudo, progress, resume, JSON |
| `lib/ui.sh` | Colours, glyphs, layout, logging, prompts, banner |
| `lib/packages.sh` | Manifest loader |
| `lib/theme.sh` | GTK themes, XFCE/LightDM, wallpaper |
| `lib/utilities.sh` | Utility generation and post-install report |
| `distros/<family>/` | One provisioner per family |
| `config/` | Runtime configuration, nano config |
| `config/packages/` | Package manifests, one per family |
| `theme/` | GTK3 base + generated high-contrast, GTK2 gtkrc, metathemes |
| `assets/` | Standalone fallback utility scripts and logo |
| `completions/` | Bash and Zsh completions |
| `scripts/` | Theme generator and theme linter |
| `schema/` | JSON schema for the install summary |

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
           full)      hb_set_total_steps 14 ;;
           developer) hb_set_total_steps 11 ;;
           desktop)   hb_set_total_steps 10 ;;
           minimal)   hb_set_total_steps 5  ;;
       esac
       show_banner
       # … update, install packages by type, setup_nano, create_utility_scripts …
       show_post_install
   }
   main "$@"
   ```
2. Support all four install types (the tests enforce the literals `full`,
   `developer`, `desktop`, `minimal`).
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

## Themes

- `theme/honey-badger-theme.css` targets GTK 3.20+ and imports Adwaita dark as
  its baseline. Override palette tokens, not individual colours ad hoc.
- Never use `* { background-color: … }`: it destroys every widget's own
  rendering.
- Use real GTK3 widget selectors (`button`, `headerbar`, `entry`, `menuitem`),
  not GTK2/Web-style classes.
- `theme/gtkrc-2.0` must mirror the palette without requiring a theme engine.
- Keep contrast at or above WCAG AA for body text and accent-on-surface text.

## Changing packages

Do not edit arrays in a provisioner. Edit the manifest instead:

```
config/packages/<family>.conf
```

Sections such as `[BASE_PACKAGES]` become arrays of the same name. Add one entry
per line; entries may contain spaces. `verify_scripts.sh` checks that every
family has a manifest with a `BASE_PACKAGES` section and that its provisioner
loads it.

## Working on the theme

- Edit `theme/honey-badger-theme.css` only; the high-contrast variant is derived.
- Regenerate and lint both variants:

  ```bash
  make theme          # runs the generator, then the linter
  ```

- The linter enforces balanced CSS, the Adwaita baseline import, required
  palette tokens and widget selectors, the absence of universal background
  rules, and WCAG contrast for text/UI pairs.
- Add a new widget surface by styling a real GTK3 selector (for example
  `popover.background`), never a web-style class.
- `honey-badger-theme palette` prints the current palette with swatches.
- For a visual check, render widgets under Xvfb:

  ```bash
  scripts/theme-screenshot.sh Ratel /tmp/ratel.png
  ```

  This needs `xvfb`, ImageMagick, and GTK3 examples; it is a local review tool,
  not part of `make check`.

## Testing requirements for a pull request

```bash
make lint    # bash -n, shellcheck (if installed), theme lint
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
