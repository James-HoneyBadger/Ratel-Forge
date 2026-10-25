# Ratel Forge — Project Overview

## What it is

Ratel Forge is a **post-install provisioning framework** for Linux. It is not a
distribution: it runs on top of an existing installation and applies a
consistent development and desktop environment across seven distribution
families.

It was previously called *Honey Badger OS*. The project kept the animal — Ratel
is the honey badger's proper common name — but dropped the `OS` suffix, because
what ships here is a framework, not an operating system.

## Goals

1. **One entry point** — `install.sh` detects the distribution and dispatches to
   the right provisioner.
2. **Consistent experience** — the same tools, terminal vocabulary, theme, and
   utilities regardless of family.
3. **Honest profiles** — Full, Developer, Desktop, and Minimal describe exactly
   what they install, including disk footprint.
4. **Security-first** — no `eval`, no `curl | bash`, whitelisted config keys,
   array-based package arguments, and a truthful dry-run.
5. **Maintainability** — a shared library owns UI, logging, theme, and utility
   generation so seven provisioners stay small.

## Architecture

```
install.sh ──→ pre-flight ──→ detect_distribution ──→ distros/{family}/install-{family}.sh
                                                          │
                                                          ▼
                                                   lib/common.sh
                                     ┌─────────────┬──────────────┬─────────────┐
                                     ▼             ▼              ▼             ▼
                                  ui.sh      packages.sh      theme.sh    utilities.sh
```

| Component | Responsibility |
|-----------|----------------|
| `install.sh` | Flag parsing (side-effect free for `--help`/`--version`/`--list-types`), environment checks, install-type catalogue, detection, summary, confirmation, dispatch |
| `lib/common.sh` | Entry point: configuration, logging setup, `hb_sudo`, progress, checkpoints/phases, JSON summary, network and service helpers |
| `lib/ui.sh` | Colours, glyphs, layout, logging, prompts, banner |
| `lib/packages.sh` | Manifest loader (sections become arrays, no `eval`) |
| `lib/theme.sh` | GTK themes, XFCE/LightDM appearance, wallpaper |
| `lib/utilities.sh` | Utility command generation and post-install report |
| `config/packages/*.conf` | Package manifests per family |
| `distros/*/install-*.sh` | Package lists, package-manager commands, repository setup, service management |
| `config/honey-badger-os.conf` | Release identity, palette, typography, feature flags |
| `theme/` | GTK3 stylesheet, GTK2 gtkrc, metatheme descriptor |
| `assets/` | Standalone fallback copies of the utility commands |
| `completions/` | Bash and Zsh completion definitions |

### Design decisions

- **Detection cannot corrupt its own result.** `detect_distribution` sets
  `HB_DISTRO_FAMILY` and `HB_DISTRO_LABEL` and writes nothing to stdout. The
  previous echo-plus-logging approach meant command substitution captured log
  lines and produced a path containing a newline.
- **One UI vocabulary.** Provisioners call `hb_section`, `hb_rule`, `hb_kv`,
  `hb_next_step`, and the `log_*` family instead of printing ad-hoc banners.
- **Glyphs degrade, never break.** UTF-8 is detected from the locale; `--ascii`
  or `TERM=dumb` falls back to ASCII. Colour degrades from 256 to ANSI-8 to none.
- **Dry-run means dry.** Mutating user-level functions return early under
  `hb_dry_run`; `hb_sudo` prints commands instead of running them.
- **Theme is a first-class artifact.** It is installed for the user *and*
  system-wide, registered as a metatheme, applied through GTK and XFCE settings,
  and generated from the same palette as the wallpaper.
- **Logs are structured.** Log files receive timestamped, ANSI-free lines. The
  universal installer additionally tees raw subprocess output, with a flag that
  prevents the shared library from writing duplicates.
- **Package data is separate from logic.** Manifests make package changes
  reviewable and keep provisioning code small.
- **Resume is explicit.** Completed phases are recorded; `--resume` skips them
  and rejects state from a different distro/type.
- **Themes are generated and linted.** The high-contrast variant is derived from
  the base stylesheet; `scripts/lint-theme.py` enforces structure, required
  selectors, and WCAG contrast in CI.

## Supported platforms

| Family | Package manager | Init | Derivatives |
|--------|-----------------|------|-------------|
| Arch | pacman | systemd | Manjaro, EndeavourOS, ArcoLinux, Artix |
| Debian | apt | systemd | Ubuntu, Mint, Pop!\_OS, Elementary, Zorin, Kali |
| Fedora | dnf / yum | systemd | RHEL, CentOS, AlmaLinux, Rocky |
| Gentoo | emerge (Portage) | OpenRC / systemd | Funtoo |
| openSUSE | zypper | systemd | Leap, Tumbleweed, SLES, GeckoLinux |
| Void | xbps | runit | — |
| Slackware | slackpkg | SysV init | Salix |

## Testing strategy

| Suite | Scope |
|-------|-------|
| `verify_scripts.sh` | Syntax, structure, required functions, package-manager parity, install-type coverage |
| `verify_advanced.sh` | Security patterns (no `eval`, no `curl|bash`, no `chmod 777`), sudo discipline, traps, env defaults, colour handling |
| `test_final.sh` | Sourcing, double-source safety, dry-run, idempotency, JSON output, progress counters, banner, checkpoint, config validation |

All three run locally and in CI, including dry-runs in seven container images.

## Roadmap ideas

- Publish a JSON schema for `honeybadger-summary.json`
- Package-list manifests per family (data, not code) for easier review
- Optional Wayland session profile
- Screenshot gallery generated from a container in CI
