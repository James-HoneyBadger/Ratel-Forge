# Ratel Forge — developer tasks
set shell := ["bash", "-uc"]

alias t := test
alias c := check

# List tasks
default:
    @just --list

# Structural, shellcheck, and desktop-layer checks
lint:
    @for f in install.sh lib/*.sh uninstall.sh distros/*/install-*.sh assets/honey-badger-*; do bash -n "$f" || exit 1; done
    @if command -v shellcheck >/dev/null 2>&1; then shellcheck -x -s bash -e SC2034 install.sh lib/*.sh uninstall.sh distros/*/install-*.sh assets/honey-badger-*; else echo "shellcheck not installed, skipping"; fi
    @scripts/check-no-desktop-layer.sh

# Run the three verification suites
test:
    bash verify_scripts.sh
    bash verify_advanced.sh
    bash test_final.sh

# Fail if desktop-environment or login code reappears
guard:
    scripts/check-no-desktop-layer.sh

# Everything CI runs
check: lint test

# Remove caches
clean:
    -find . -name __pycache__ -type d -prune -exec rm -rf {} +
