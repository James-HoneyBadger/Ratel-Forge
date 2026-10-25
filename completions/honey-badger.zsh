#compdef install.sh honey-badger-install honey-badger-update honey-badger-info honey-badger-report honey-badger-doctor
# Zsh completion for the Ratel installer. Place in $fpath or source directly.

_install_sh() {
    _arguments \
        '(-h --help)'{-h,--help}'[Show help and exit]' \
        '(-V --version)'{-V,--version}'[Show version and exit]' \
        '(-t --type --install-type)'{-t,--type}'[Install type]:type:(full developer apps minimal)' \
        '--install-type[Install type]:type:(full developer apps minimal)' \
        '--list-types[Print the install types and exit]' \
        '(-n --dry-run)'{-n,--dry-run}'[Simulate without making changes]' \
        '(-y --yes)'{-y,--yes}'[Assume yes for the confirmation prompt]' \
        '--non-interactive[Never prompt]' \
        '--check[Run pre-flight checks only]' \
        '--resume[Resume a previous run]' \
        '--components[Package groups]:groups:(base dev apps)' \
        '--no-banner[Omit the banner]' \
        '--ascii[Use ASCII glyphs]' \
        '--no-color[Disable coloured output]' \
        '(-v --verbose)'{-v,--verbose}'[Show debug output]' \
        '(-q --quiet)'{-q,--quiet}'[Errors only]' \
        '--skip-docker[Skip Docker setup]' \
        '--skip-python[Skip Python dev setup]' \
        '--skip-node[Skip Node.js dev setup]' \
        '--skip-nano[Skip nano configuration]' \
        '--skip-shell[Skip shell and CLI tool configuration]' \
        '--skip-git[Skip Git identity setup]'
}

_honey_badger_install() {
    _arguments \
        '(-h --help)'{-h,--help}'[Show help and exit]' \
        '(-s --search)'{-s,--search}'[Search the repositories]:term:' \
        '(-r --remove)'{-r,--remove}'[Remove the named packages]' \
        '(-f --file)'{-f,--file}'[Read packages from a file]:file:_files' \
        '(-n --dry-run)'{-n,--dry-run}'[Show the command only]' \
        '*:package:_honey_badger_packages'
}

_honey_badger_packages() {
    if (( $+commands[apt-cache] )); then
        local -a pkgs
        pkgs=(${(f)"$(apt-cache --no-generate pkgnames "${words[CURRENT]}" 2>/dev/null | head -50)"})
        _describe 'package' pkgs
    elif (( $+commands[pacman] )); then
        local -a pkgs
        pkgs=(${(f)"$(pacman -Ssq "^${words[CURRENT]}" 2>/dev/null | head -50)"})
        _describe 'package' pkgs
    fi
}

_honey_badger_simple() {
    case "${words[1]##*/}" in
        honey-badger-update)
            _arguments '(-n --dry-run)'{-n,--dry-run}'[Show the commands only]' \
                '--no-flatpak[Skip Flatpak]' '--no-snap[Skip Snap]' '--no-clean[Skip cache cleanup]' \
                '(-h --help)'{-h,--help}'[Show help and exit]'
            ;;
        honey-badger-uninstall)
            _arguments '--dry-run[Show what would be removed]' '(-h --help)'{-h,--help}'[Show help and exit]'
            ;;
        honey-badger-report)
            _arguments '--output[Write the report to a file]:file:_files' \
                '--no-log[Omit the log tail]' '(-h --help)'{-h,--help}'[Show help and exit]'
            ;;
        *)
            _arguments '--json[Machine-readable output]' '(-h --help)'{-h,--help}'[Show help and exit]'
            ;;
    esac
}

compdef _install_sh install.sh
compdef _honey_badger_install honey-badger-install
compdef _honey_badger_simple honey-badger-update
compdef _honey_badger_simple honey-badger-info
compdef _honey_badger_simple honey-badger-doctor
compdef _honey_badger_simple honey-badger-report
compdef _honey_badger_simple honey-badger-uninstall
