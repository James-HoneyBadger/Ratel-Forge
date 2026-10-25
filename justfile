# Ratel Forge — developer tasks
set shell := ["bash", "-uc"]

alias t := test
alias c := check

# List tasks
default:
    @just --list

# Structural, shellcheck, and theme checks
lint:
    @for f in install.sh lib/*.sh uninstall.sh distros/*/install-*.sh assets/honey-badger-*; do bash -n "$f" || exit 1; done
    @if command -v shellcheck >/dev/null 2>&1; then shellcheck -x -s bash -e SC2034 install.sh lib/*.sh uninstall.sh distros/*/install-*.sh assets/honey-badger-*; else echo "shellcheck not installed, skipping"; fi
    @python3 scripts/lint-theme.py

# Run the three verification suites
test:
    bash verify_scripts.sh
    bash verify_advanced.sh
    bash test_final.sh

# Regenerate the high-contrast theme and lint both
theme:
    python3 scripts/generate_theme_variants.py
    python3 scripts/lint-theme.py

# Everything CI runs
check: lint test

# Remove caches
clean:
    -find . -name __pycache__ -type d -prune -exec rm -rf {} +
