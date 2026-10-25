#compdef install.sh honey-badger-install honey-badger-update honey-badger-info honey-badger-theme honey-badger-doctor
# Zsh completion for the Ratel installer. Place in $fpath or source directly.

_install_sh() {
    _arguments \
        '(-h --help)'{-h,--help}'[Show help and exit]' \
        '(-V --version)'{-V,--version}'[Show version and exit]' \
        '(-t --type --install-type)'{-t,--type}'[Install type]:type:(full developer desktop minimal)' \
        '--install-type[Install type]:type:(full developer desktop minimal)' \
        '--list-types[Print the install types and exit]' \
        '(-n --dry-run)'{-n,--dry-run}'[Simulate without making changes]' \
        '(-y --yes)'{-y,--yes}'[Assume yes for the confirmation prompt]' \
        '--non-interactive[Never prompt]' \
        '--check[Run pre-flight checks only]' \
        '--resume[Resume a previous run]' \
        '--components[Package groups]:groups:(base dev desktop apps)' \
        '--no-banner[Omit the banner]' \
        '--ascii[Use ASCII glyphs]' \
        '--high-contrast[Use the high-contrast theme]' \
        '--font-size[Desktop font size]:px:(8 9 10 11 12 14 16 18)' \
        '--no-color[Disable coloured output]' \
        '(-v --verbose)'{-v,--verbose}'[Show debug output]' \
        '(-q --quiet)'{-q,--quiet}'[Errors only]' \
        '--skip-docker[Skip Docker setup]' \
        '--skip-python[Skip Python dev setup]' \
        '--skip-node[Skip Node.js dev setup]' \
        '--skip-nano[Skip nano configuration]' \
        '--skip-theme[Skip theme and wallpaper]' \
        '--no-theme[Skip theme and wallpaper]' \
        '--skip-git[Skip Git identity setup]'
}

_honey_badger_install() {
    _arguments \
        '--help[Show help and exit]' \
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
    _arguments '--help[Show help and exit]'
}

_honey_badger_theme() {
    _arguments '1:command:(status apply list palette help)'
}

compdef _install_sh install.sh
compdef _honey_badger_install honey-badger-install
compdef _honey_badger_simple honey-badger-update
compdef _honey_badger_simple honey-badger-info
compdef _honey_badger_simple honey-badger-doctor
compdef _honey_badger_theme honey-badger-theme
