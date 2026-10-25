#!/bin/bash
# Ratel Forge - desktop-layer guard
# ---------------------------------------------------------------------------
# Ratel Forge provisions developer tooling only. It must never install or
# configure a desktop environment, display manager, greeter, or login/session
# behaviour. This guard fails the build if that kind of code reappears.
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

readonly PATTERN='xfce|thunar|lightdm|xfwm|xfdesktop|xfconf|startxfce4|greeter|display-manager|graphical\.target|\.xinitrc|startx'

# Executable and configuration surface. Documentation may describe the
# removal, so it is deliberately out of scope.
targets=(
    install.sh
    uninstall.sh
    lib
    distros
    assets
    config
    completions
    schema
    Makefile
    justfile
    .github
)

found=0
for target in "${targets[@]}"; do
    [[ -e "$target" ]] || continue
    if grep -rIniE "$PATTERN" "$target" \
        --exclude=check-no-desktop-layer.sh 2>/dev/null; then
        found=1
    fi
done

if [[ $found -eq 1 ]]; then
    printf '\n✖ Desktop-environment or login code detected.\n' >&2
    printf '  Ratel Forge must not change the desktop environment, display manager,\n' >&2
    printf '  greeter, session, or login behaviour. Remove the lines above.\n' >&2
    exit 1
fi

printf 'OK no desktop-environment or login code\n'
