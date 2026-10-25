# Ratel Forge — Operating and Development Instructions

Task-oriented procedures. For concepts, see the
[Technical Reference](TECHNICAL_REFERENCE.md); for usage, the
[User Manual](USER_MANUAL.md).

---

## Contents

1. [Operator procedures](#1-operator-procedures)
2. [Add a distribution](#2-add-a-distribution)
3. [Change packages](#3-change-packages)
4. [Add a CLI option](#4-add-a-cli-option)
5. [Add a setup phase](#5-add-a-setup-phase)
6. [Add a utility command](#6-add-a-utility-command)
7. [Add a doctor check](#7-add-a-doctor-check)
8. [Debug a failed run](#8-debug-a-failed-run)
9. [Release checklist](#9-release-checklist)
10. [Recover from a bad install](#10-recover-from-a-bad-install)

---

## 1. Operator procedures

### 1.1 Verify a machine before installing

```bash
./install.sh --check
```

Confirm network, disk, sudo, and distribution detection.

### 1.2 Preview a profile

```bash
./install.sh --type full --dry-run
```

Expect no files under `$HOME` to change and no package-manager actions.

### 1.3 Install unattended

```bash
export HONEY_BADGER_NONINTERACTIVE=1
export HONEY_BADGER_INSTALL_TYPE=developer
export HONEY_BADGER_GIT_USERNAME="Ada Lovelace"
export HONEY_BADGER_GIT_EMAIL="ada@example.com"
./install.sh --yes
```

### 1.4 Verify after installing

```bash
source ~/.bashrc
honey-badger-info
honey-badger-doctor
```

### 1.5 Collect a bug report

```bash
honey-badger-report --output ~/ratel-report.txt
less ~/ratel-report.txt
```

Review the redacted output before sharing.

### 1.6 Remove Ratel Forge configuration

```bash
bash uninstall.sh --dry-run
bash uninstall.sh
```

Packages are intentionally left installed.

## 2. Add a distribution

1. Create `distros/<family>/install-<family>.sh`. Model it on an existing
   provisioner; keep the structure:
   - source `lib/common.sh`
   - `hb_init_distro_log "<family>"`
   - manifest load
   - `show_banner`
   - package install functions
   - `install_packages_by_type`
   - `main` with `hb_json_init`, `hb_rollback_init`, step totals,
     `hb_phases_init`, phases, `show_post_install`
2. Create `config/packages/<family>.conf` with `[BASE_PACKAGES]`,
   `[CLI_TOOLS_PACKAGES]`, `[DEVELOPER_PACKAGES]`, and
   `[APPLICATIONS_PACKAGES]` (plus `[BASE_SETS]`/`[DEVELOPER_SETS]` if the
   package manager uses sets).
3. Call `install_<pm>_packages CLI_TOOLS_PACKAGES "base tools"` after the base
   packages.
4. Call `hb_phase shell setup_shell` after `setup_nano`.
5. Pass six arguments to `create_utility_scripts` (update, install, clean,
   search, remove, check).
6. Add detection to `install.sh` in all three layers: `/etc/os-release` IDs,
   `ID_LIKE`, and package-manager/release-file fallbacks.
7. Add the family to the CI dry-run matrix.
8. Update the distribution tables in `README.md`, `docs/USER_MANUAL.md`, and
   `PROJECT_OVERVIEW.md`.

Validate step totals with the stub harness:

```bash
stubs=$(mktemp -d)
for c in pacman apt apt-get apt-cache dpkg add-apt-repository lsb_release \
         dnf yum rpm zypper emerge equery qlist slackpkg sbopkg \
         xbps-install xbps-query flatpak snap systemctl \
         curl wget git nodejs npm python3 docker; do
  printf '#!/bin/sh\nexit 0\n' > "$stubs/$c"; chmod +x "$stubs/$c"
done
for t in full developer apps minimal; do
  h=$(mktemp -d)
  HOME="$h" PATH="$stubs:$PATH" HONEY_BADGER_DRY_RUN=1 \
    HONEY_BADGER_NONINTERACTIVE=1 HONEY_BADGER_INSTALL_TYPE="$t" \
    bash distros/<family>/install-<family>.sh 2>&1 |
    grep -oE '\[[0-9]+/[0-9]+\]' | tail -1
  rm -rf "$h"
done
rm -rf "$stubs"
```

The last counter must read `[n/n]` for each type.

## 3. Change packages

Edit the manifest only:

```
config/packages/<family>.conf
```

- One entry per line; `#` comments and blank lines are ignored.
- Entries may contain spaces (for example `code --classic`).
- Use the distribution's real package names, including category prefixes on
  Gentoo.
- Keep `[BASE_PACKAGES]` lean; put modern CLI tooling in
  `[CLI_TOOLS_PACKAGES]`.
- Never edit package arrays inside a provisioner.

Then run:

```bash
bash verify_scripts.sh
./install.sh --type full --dry-run
```

## 4. Add a CLI option

1. Parse it in the `while` loop in `install.sh` **before** `lib/common.sh` is
   sourced, so `--help` stays side-effect free.
2. Export an `HONEY_BADGER_*` variable rather than adding a new global.
3. Add the flag to `show_help`.
4. If it is a skip flag, add it to `_HB_VALID_CONFIG_KEYS` and `hb_skip_active`.
5. Add it to `completions/honey-badger.bash` and `completions/honey-badger.zsh`.
6. Add a smoke test to `test_final.sh`.
7. Document it in `README.md`, `docs/USER_MANUAL.md`, and
   `config/honey-badger-os.conf` when it has an environment form.
8. Run the full check:

```bash
make check
```

## 5. Add a setup phase

1. Create `lib/<name>.sh` following the existing modules: double-source guard,
   a public `setup_<name>` function, internal helpers prefixed `_hb_`.
2. Source it from `lib/common.sh` in the layered section.
3. Call `hb_phase <id> setup_<name>` in each of the seven provisioners.
4. Bump `hb_set_total_steps` for **all four types in all seven families** by the
   number of `hb_next_step` calls the phase adds.
5. Add the function to the required-function lists in `verify_scripts.sh` and
   `test_final.sh`.
6. Add cleanup to `uninstall.sh` for every file the phase creates.
7. Document the files in `docs/USER_MANUAL.md` and the module API in
   `docs/TECHNICAL_REFERENCE.md`.
8. Validate with the stub harness in
   [section 2](#2-add-a-distribution) and with `make check`.

Rules for a phase:

- Guard with `hb_dry_run` before any write.
- Use `hb_backup_file` before replacing a file.
- Use `ensure_bashrc_line` rather than appending directly.
- Never touch login, PAM, or desktop configuration.

## 6. Add a utility command

1. Add `assets/honey-badger-<name>` (executable, `#!/bin/bash`,
   `set -uo pipefail`).
2. Source `ui.sh`, `install-info`, and `pm.conf` with `-r` guards and provide
   plain fallbacks.
3. Add the command to the loop in `create_utility_scripts`
   (`lib/utilities.sh`).
4. Add it to the removal loop in `uninstall.sh`.
5. Add completion in both shells.
6. Add the asset to the syntax list in `test_final.sh` and the project-file list
   in `verify_scripts.sh`.
7. Add tests to `test_final.sh` for its observable behaviour.
8. Document it in `README.md`, `docs/USER_MANUAL.md`, and
   `docs/TECHNICAL_REFERENCE.md`.

Utility conventions:

- Support `--help` and exit `2` on usage errors.
- Exit `1` on operational failure.
- Never print environment variables or secrets.
- Read paths from `${XDG_DATA_HOME:-$HOME/.local/share}`.

## 7. Add a doctor check

1. Add `check_<topic>()` to `assets/honey-badger-doctor`.
2. Use `ok`, `warn`, `fail`, and `skip` so both human and JSON output stay
   consistent.
3. Call it from the check sequence near the end of the file.
4. Keep blocking problems in `fail`; advisory findings belong in `warn`.
5. If the check depends on a component, skip it when that component is absent
   (see `check_toolchain`).
6. Add a test in `test_final.sh` when the behaviour is observable.

## 8. Debug a failed run

1. Read the log named in the failure output:
   `~/.local/share/honey-badger/logs/`.
2. Re-run with `-v` to add debug lines.
3. Re-run the affected provisioner alone in dry-run:

   ```bash
   HONEY_BADGER_DRY_RUN=1 HONEY_BADGER_NONINTERACTIVE=1 \
     HONEY_BADGER_INSTALL_TYPE=developer \
     bash distros/<family>/install-<family>.sh
   ```

4. Inspect state:

   ```bash
   cat ~/.local/share/honey-badger/checkpoint
   cat ~/.local/share/honey-badger/phases
   tail -n 40 ~/.local/share/honey-badger/logs/<latest>.log
   ```

5. Fix the cause, then resume:

   ```bash
   ./install.sh --type developer --resume
   ```

`--resume` refuses state from a different distro or type.

## 9. Release checklist

1. Update `HONEY_BADGER_VERSION` in `config/honey-badger-os.conf`.
2. Add a `CHANGELOG.md` entry (Added / Changed / Fixed / Removed).
3. Update `VERIFICATION_REPORT.md` with current test counts.
4. Run:

   ```bash
   make lint
   make test
   make check
   ```

5. Dry-run every type:

   ```bash
   for t in full developer apps minimal; do
     ./install.sh --type "$t" --dry-run --non-interactive --no-banner
   done
   ```

6. Confirm the guard is green: `make guard`.
7. Verify no desktop/login references in code:

   ```bash
   scripts/check-no-desktop-layer.sh
   ```

8. Commit with the version and a summary; tag the release.

## 10. Recover from a bad install

```bash
# Preview what the uninstaller would touch
bash uninstall.sh --dry-run

# Remove configuration, restore backups
bash uninstall.sh

# Inspect recorded packages, then remove them with the package manager
grep '^PACKAGE:' ~/.local/share/honey-badger/rollback-manifest

# Reinstall cleanly
./install.sh --type developer
```

If shell startup is broken, inspect `~/.bashrc` for the two Ratel lines and
remove them manually; fragments live in `~/.config/ratel/shell/`.
