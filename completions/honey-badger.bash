# Bash completion for the Ratel installer (install.sh)
# Source this file, or place it in /etc/bash_completion.d/.

_honey_badger_install_sh() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    local types="full developer desktop minimal"
    local opts="--help --version --type --install-type --list-types --dry-run
        --yes --non-interactive --check --resume --components --high-contrast --font-size --no-banner --ascii --no-color
        --verbose --quiet --skip-docker --skip-python --skip-node --skip-nano
        --skip-theme --no-theme --skip-git -h -V -t -n -y -v -q"

    case "$prev" in
        --type|--install-type|-t)
            COMPREPLY=($(compgen -W "$types" -- "$cur"))
            return 0
            ;;
        --components)
            COMPREPLY=($(compgen -W "base dev desktop apps" -- "${cur##*,}"))
            return 0
            ;;
        --font-size)
            COMPREPLY=($(compgen -W "9 10 11 12 14 16" -- "$cur"))
            return 0
            ;;
    esac

    if [[ "$cur" == --type=* ]]; then
        COMPREPLY=($(compgen -W "$(printf -- '--type=%s ' $types)" -- "$cur"))
        return 0
    fi

    COMPREPLY=($(compgen -W "$opts" -- "$cur"))
}
complete -F _honey_badger_install_sh install.sh
complete -F _honey_badger_install_sh ./install.sh

# Completion for honey-badger-install (package names from the system)
_honey_badger_pkg_install() {
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    if [[ "$prev" == "--search" || "$prev" == "-s" ]]; then
        COMPREPLY=()
        return 0
    fi
    if [[ "$cur" == -* ]]; then
        local opts="--search --remove --dry-run --help -s -r -n -h"
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
        return 0
    fi
    if command -v apt-cache >/dev/null 2>&1; then
        COMPREPLY=($(apt-cache --no-generate pkgnames "$cur" 2>/dev/null | head -50))
    elif command -v pacman >/dev/null 2>&1; then
        COMPREPLY=($(pacman -Ssq "^${cur}" 2>/dev/null | head -50))
    elif command -v dnf >/dev/null 2>&1; then
        COMPREPLY=($(dnf list --available -q 2>/dev/null | awk '{print $1}' | grep "^${cur}" | head -50))
    fi
}
complete -F _honey_badger_pkg_install honey-badger-install

# Completion for update / info / doctor / uninstall
_honey_badger_simple() {
    local cur words="--help"
    cur="${COMP_WORDS[COMP_CWORD]}"
    case "${COMP_WORDS[0]##*/}" in
        honey-badger-update)    words="--dry-run --no-flatpak --no-snap --no-clean --help -n -h" ;;
        honey-badger-info)      words="--json --help -h" ;;
        honey-badger-doctor)    words="--json --help -h" ;;
        honey-badger-uninstall) words="--dry-run --help -h" ;;
    esac
    COMPREPLY=($(compgen -W "$words" -- "$cur"))
}
complete -F _honey_badger_simple honey-badger-update
complete -F _honey_badger_simple honey-badger-info
complete -F _honey_badger_simple honey-badger-doctor
complete -F _honey_badger_simple honey-badger-uninstall

# Completion for honey-badger-theme
_honey_badger_theme() {
    local cur
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(compgen -W "status apply list palette --help" -- "$cur"))
}
complete -F _honey_badger_theme honey-badger-theme
