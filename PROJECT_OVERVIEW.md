# Ratel Forge — Project Overview

## What it is

Ratel Forge is a **post-install provisioning framework for application
developers**. It runs on top of an existing Linux installation and applies a
consistent set of utilities, applications, and settings across seven
distribution families.

It was previously called *Honey Badger OS*. The project kept the animal — Ratel
is the honey badger's proper common name — but dropped the `OS` suffix, because
what ships here is a framework, not an operating system. Version 3.0 removed the
desktop-environment layer entirely.

## Goals

1. **One entry point** — `install.sh` detects the distribution and dispatches to
   the right provisioner.
2. **Consistent developer experience** — the same toolchains, CLI vocabulary,
   editor configuration, and utilities regardless of family.
3. **Honest profiles** — Full, Developer, Applications, and Minimal describe
   exactly what they install, including disk footprint.
4. **Never touch the desktop or login** — no desktop environment, display
   manager, greeter, session, boot target, theme, or wallpaper code. A CI guard
   enforces this.
5. **Security-first** — no `eval`, no `curl | bash`, whitelisted config keys,
   array-based package arguments, and a truthful dry-run.
6. **Maintainability** — a shared library owns UI, logging, editor, and utility
   generation so seven provisioners stay small.

## Architecture

```
install.sh ──→ pre-flight ──→ detect_distribution ──→ distros/{family}/install-{family}.sh
                                                          │
                                                          ▼
                                                   lib/common.sh
                                     ┌─────────────┬──────────────┬─────────────┐
                                     ▼             ▼              ▼             ▼
                                  ui.sh      packages.sh      editor.sh    utilities.sh
```

| Component | Responsibility |
|-----------|----------------|
| `install.sh` | Flag parsing (side-effect free for `--help`/`--version`/`--list-types`), environment checks, install-type catalogue, detection, summary, confirmation, dispatch |
| `lib/common.sh` | Entry point: configuration, logging setup, `hb_sudo`, progress, checkpoints/phases, JSON summary, network and service helpers, Docker/Python/Node setup |
| `lib/ui.sh` | Colours, glyphs, layout, logging, prompts, banner |
| `lib/packages.sh` | Manifest loader (sections become arrays, no `eval`) |
| `lib/editor.sh` | Nano configuration and editor defaults |
| `lib/shell.sh` | Shell fragments, readline settings, and CLI tool configuration |
| `lib/utilities.sh` | Utility command generation and post-install report |
| `assets/honey-badger-*` | `info`, `update`, `install`, `report`, `doctor`, `uninstall` |
| `config/packages/*.conf` | Package manifests per family |
| `distros/*/install-*.sh` | Package lists, package-manager commands, repository setup, service management |
| `config/honey-badger-os.conf` | Release identity, editor, feature flags, tunables |
| `assets/` | Standalone fallback copies of the utility commands and the logo |
| `completions/` | Bash and Zsh completion definitions |
| `docs/` | User manual, technical reference, and task instructions |
| `scripts/check-no-desktop-layer.sh` | Build guard against desktop/login code |

### Components and profiles

| Component | Section | Installed by |
|-----------|---------|--------------|
| `base` | `BASE_PACKAGES` + `CLI_TOOLS_PACKAGES` | every type |
| `dev` | `DEVELOPER_PACKAGES` | `full`, `developer` |
| `apps` | `APPLICATIONS_PACKAGES` | `full`, `apps` |

| Type | Components |
|------|------------|
| `full` | base + dev + apps |
| `developer` | base + dev |
| `apps` | base + apps |
| `minimal` | base |

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
- **Shell settings are fragment-based.** One sourced line activates
  `~/.config/ratel/shell/*.sh`; nothing touches login files, PAM, or
  `/etc/profile`, so uninstall is a directory delete.
- **Existing configuration wins.** Git defaults are applied only when a key is
  unset, so a configured machine is never silently rewritten.
- **Package data is separate from logic.** Manifests make package changes
  reviewable and keep provisioning code small.
- **Resume is explicit.** Completed phases are recorded; `--resume` skips them
  and rejects state from a different distro/type.
- **Desktop scope is enforced, not assumed.** `scripts/check-no-desktop-layer.sh`
  scans the executable and configuration surface for XFCE-family packages,
  display managers, greeters, session files, boot-target changes, and theming,
  and fails CI if any reappear.
- **Logs are structured.** Log files receive timestamped, ANSI-free lines. The
  universal installer additionally tees raw subprocess output, with a flag that
  prevents the shared library from writing duplicates.

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
| `verify_scripts.sh` | Syntax, structure, required functions, package-manager parity, install-type coverage, desktop-layer guard |
| `verify_advanced.sh` | Security patterns (no `eval`, no `curl|bash`, no `chmod 777`), sudo discipline, traps, env defaults, colour handling, login-configuration check |
| `test_final.sh` | Sourcing, double-source safety, dry-run, idempotency, JSON output, progress counters, banner, checkpoint, config validation, profile-aware reporting |

All three run locally and in CI, including dry-runs in seven container images.

## Roadmap ideas

- Publish a JSON schema for `honeybadger-summary.json` (done)
- Additional developer tooling manifests (linters, language version managers)
- Optional container-first profile
- Health checks for toolchain versions in `honey-badger-doctor`
