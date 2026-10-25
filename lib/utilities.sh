#!/bin/bash
# shellcheck disable=SC2034  # Variables are consumed by the sourcing script
# shellcheck disable=SC2088  # Tilde strings are human-readable labels, not paths
# Ratel Forge - Utility command generation and post-install report
# ---------------------------------------------------------------------------
# Generates honey-badger-info/update/install plus their shared UI module, and
# renders the post-install summary.
#
# Sourced by lib/common.sh; do not source directly.
# ---------------------------------------------------------------------------

# Prevent double-sourcing
[[ -n "${_HB_UTILITIES_LOADED:-}" ]] && return 0
readonly _HB_UTILITIES_LOADED=1

# ── Utility script creation ──────────────────────────────────────────────────
# Creates distro-aware utility scripts. Caller must pass the package manager
# commands as arguments.
#   create_utility_scripts <pm_update_cmd> <pm_install_cmd> <pm_clean_cmd>
# E.g.: create_utility_scripts "sudo pacman -Syu --noconfirm" "sudo pacman -S --noconfirm" "sudo pacman -Sc --noconfirm"
create_utility_scripts() {
    local pm_update_cmd="${1:-echo 'No package manager update command configured'}"
    local pm_install_cmd="${2:-echo 'No package manager install command configured'}"
    local pm_clean_cmd="${3:-echo 'No package manager clean command configured'}"

    hb_next_step "Creating Ratel Forge utility scripts..."

    if hb_dry_run; then
        log_info "[DRY-RUN] Would install honey-badger-* utility commands"
        return 0
    fi

    local bin_dir="$HOME/.local/bin"
    local share_dir="$HOME/.local/share/honey-badger"
    mkdir -p "$bin_dir" "$share_dir"
    ensure_bashrc_line "export PATH=\"\$HOME/.local/bin:\$PATH\""

    # ── Shared UI helpers (keeps all utilities visually consistent) ──
    cat > "$share_dir/ui.sh" << 'EOF'
#!/bin/bash
# Ratel Forge — shared terminal UI helpers for utility commands.
[[ -n "${HB_UI_LOADED:-}" ]] && return 0
HB_UI_LOADED=1

if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
    HB_ACCENT='' HB_OK='' HB_WARN='' HB_ERR='' HB_MUTED='' HB_BOLD='' HB_NC=''
else
    HB_ACCENT='\033[38;5;214m'
    HB_OK='\033[38;5;113m'
    HB_WARN='\033[38;5;221m'
    HB_ERR='\033[38;5;203m'
    HB_MUTED='\033[38;5;245m'
    HB_BOLD='\033[1m'
    HB_NC='\033[0m'
fi

hb_rule() {
    local count="${1:-54}" line="" i
    for ((i = 0; i < count; i++)); do line+="─"; done
    printf '  %s%s%s\n' "$HB_MUTED" "$line" "$HB_NC"
}

hb_header() {
    local title="$1"
    printf '\n  %s%sRATEL FORGE%s  %s·%s  %s%s%s\n' \
        "$HB_ACCENT" "$HB_BOLD" "$HB_NC" "$HB_MUTED" "$HB_NC" "$HB_BOLD" "$title" "$HB_NC"
    hb_rule
}

hb_kv() {
    local key="$1" value="$2"
    printf '  %s%-22s%s %s\n' "$HB_MUTED" "$key" "$HB_NC" "$value"
}

hb_ok()   { printf '  %s✔%s %s\n' "$HB_OK" "$HB_NC" "$1"; }
hb_warn() { printf '  %s▲%s %s\n' "$HB_WARN" "$HB_NC" "$1"; }
hb_err()  { printf '  %s✖%s %s\n' "$HB_ERR" "$HB_NC" "$1" >&2; }
hb_info() { printf '  %s•%s %s\n' "$HB_ACCENT" "$HB_NC" "$1"; }
EOF

    # ── Install metadata (read by the utilities) ──
    cat > "$share_dir/install-info" << ENDINFO
# Ratel Forge install metadata — generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
HONEY_BADGER_VERSION="${HONEY_BADGER_VERSION:-2.4.0}"
HONEY_BADGER_CODENAME="${HONEY_BADGER_CODENAME:-Fearless}"
HONEY_BADGER_INSTALL_TYPE="${HONEY_BADGER_INSTALL_TYPE:-full}"
HONEY_BADGER_DISTRO="${HONEY_BADGER_DISTRO:-unknown}"
HONEY_BADGER_BUILD_DATE="${HONEY_BADGER_BUILD_DATE:-unknown}"
ENDINFO

    # ── honey-badger-info ──
    cat > "$bin_dir/honey-badger-info" << 'EOF'
#!/bin/bash
# Ratel Forge System Information
set -uo pipefail

HB_SHARE="${XDG_DATA_HOME:-$HOME/.local/share}/honey-badger"
# shellcheck source=/dev/null
[[ -r "$HB_SHARE/ui.sh" ]] && source "$HB_SHARE/ui.sh"
# shellcheck source=/dev/null
[[ -r "$HB_SHARE/install-info" ]] && source "$HB_SHARE/install-info"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    printf 'Usage: honey-badger-info\n\n'
    printf 'Shows operating system, hardware, and Ratel Forge details.\n'
    exit 0
fi

os_name="Unknown"
[[ -r /etc/os-release ]] && os_name="$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-Unknown}")"
cpu="$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || true)"
memory="$(free -h 2>/dev/null | awk '/^Mem:/ {print $3 " / " $2}' || true)"
disk="$(df -h / 2>/dev/null | awk 'NR==2 {print $3 " / " $2 " (" $5 " used)"}' || true)"
uptime_text="$(uptime -p 2>/dev/null || uptime 2>/dev/null || true)"
editor_name="${EDITOR:-not set}"
editor_name="${editor_name##*/}"

hb_header "System information"
hb_kv "Operating system" "$os_name"
hb_kv "Ratel Forge"     "v${HONEY_BADGER_VERSION:-unknown} \"${HONEY_BADGER_CODENAME:-}\" (${HONEY_BADGER_INSTALL_TYPE:-unknown})"
hb_kv "Kernel"           "$(uname -r)"
hb_kv "Architecture"     "$(uname -m)"
hb_kv "Hostname"         "$(hostname 2>/dev/null || echo unknown)"
hb_kv "User"             "$(whoami)"
hb_kv "Shell"            "${SHELL##*/}"
hb_kv "Desktop"          "${XDG_CURRENT_DESKTOP:-none}"
hb_kv "Editor"           "$editor_name"
hb_kv "Uptime"           "${uptime_text#up }"
hb_kv "Memory"           "${memory:-N/A}"
hb_kv "Disk (/)"         "${disk:-N/A}"
[[ -n "$cpu" ]] && hb_kv "Processor" "$(printf '%s' "$cpu" | sed 's/  */ /g')"
hb_rule
EOF

    # ── Palette metadata (read by honey-badger-theme --palette) ──
    cat > "$share_dir/palette.env" << ENDPALETTE
RATEL_BG="${HONEY_BADGER_THEME_BG:-#16120d}"
RATEL_SURFACE="${HONEY_BADGER_THEME_SURFACE:-#201a14}"
RATEL_BASE="${HONEY_BADGER_THEME_BASE:-#12100b}"
RATEL_BORDER="${HONEY_BADGER_THEME_BORDER:-#3a3128}"
RATEL_TEXT="${HONEY_BADGER_THEME_TEXT:-#f3ebdf}"
RATEL_MUTED_TEXT="${HONEY_BADGER_THEME_MUTED_TEXT:-#b8a992}"
RATEL_ACCENT="${HONEY_BADGER_THEME_ACCENT:-#e6a92e}"
RATEL_ACCENT_TEXT="${HONEY_BADGER_THEME_ACCENT_TEXT:-#1a1409}"
RATEL_WARNING="${HONEY_BADGER_THEME_WARNING:-#e9b44c}"
RATEL_ERROR="${HONEY_BADGER_THEME_ERROR:-#e0685c}"
RATEL_SUCCESS="${HONEY_BADGER_THEME_SUCCESS:-#79b96f}"
RATEL_INFO="${HONEY_BADGER_THEME_INFO:-#6aa9e0}"
ENDPALETTE

    # ── honey-badger-theme / honey-badger-doctor (shipped as assets) ──
    cp "$HONEY_BADGER_ROOT/assets/honey-badger-theme" "$bin_dir/honey-badger-theme"
    cp "$HONEY_BADGER_ROOT/assets/honey-badger-doctor" "$bin_dir/honey-badger-doctor"

    # ── honey-badger-update ──
    cat > "$bin_dir/honey-badger-update" << ENDUPDATE
#!/bin/bash
# Ratel Forge System Update Script
set -euo pipefail

HB_SHARE="\${XDG_DATA_HOME:-\$HOME/.local/share}/honey-badger"
# shellcheck source=/dev/null
[[ -r "\$HB_SHARE/ui.sh" ]] && source "\$HB_SHARE/ui.sh"

if [[ "\${1:-}" == "--help" || "\${1:-}" == "-h" ]]; then
    printf 'Usage: honey-badger-update\n\n'
    printf 'Updates system packages, then Flatpak and Snap (when present),\n'
    printf 'and cleans the package cache. Uses sudo where required.\n'
    exit 0
fi

hb_header "System update"
hb_info "Updating system packages…"
${pm_update_cmd}

if command -v flatpak >/dev/null 2>&1; then
    hb_info "Updating Flatpak packages…"
    sudo flatpak update -y 2>/dev/null || hb_warn "Flatpak update skipped"
fi

if command -v snap >/dev/null 2>&1; then
    hb_info "Refreshing Snap packages…"
    sudo snap refresh 2>/dev/null || hb_warn "Snap refresh skipped"
fi

hb_info "Cleaning package cache…"
${pm_clean_cmd}

hb_rule
hb_ok "System update complete"
ENDUPDATE

    # ── honey-badger-install ──
    cat > "$bin_dir/honey-badger-install" << ENDINSTALL
#!/bin/bash
# Ratel Forge Package Install Script
set -euo pipefail

HB_SHARE="\${XDG_DATA_HOME:-\$HOME/.local/share}/honey-badger"
# shellcheck source=/dev/null
[[ -r "\$HB_SHARE/ui.sh" ]] && source "\$HB_SHARE/ui.sh"

if [[ "\${1:-}" == "--help" || "\${1:-}" == "-h" || \$# -eq 0 ]]; then
    printf 'Usage: honey-badger-install <package> [package...]\n\n'
    printf 'Installs packages with the native package manager.\n'
    printf 'Example: honey-badger-install firefox vlc gimp\n'
    [[ "\${1:-}" == "--help" || "\${1:-}" == "-h" ]] && exit 0
    exit 1
fi

for arg in "\$@"; do
    if [[ ! "\$arg" =~ ^[a-zA-Z0-9][a-zA-Z0-9._+:-]*\$ ]]; then
        hb_err "Invalid package name: \$arg"
        printf '  Package names may contain letters, digits, dots, hyphens, underscores, plus signs, and colons.\n' >&2
        exit 1
    fi
done

hb_header "Install packages"
hb_info "Installing: \$*"
if ${pm_install_cmd} "\$@"; then
    hb_rule
    hb_ok "Packages installed"
else
    hb_err "Package installation failed"
    exit 1
fi
ENDINSTALL

    chmod 755 "$bin_dir/honey-badger-info" "$bin_dir/honey-badger-update" \
        "$bin_dir/honey-badger-install" "$bin_dir/honey-badger-theme" \
        "$bin_dir/honey-badger-doctor"

    hb_json_add_config "~/.local/bin/honey-badger-*"
    hb_json_add_config "~/.local/share/honey-badger/install-info"
    log_success "Utility scripts created in $bin_dir"
}

# ── Post-install summary ────────────────────────────────────────────────────
show_post_install() {
    [[ "${_HB_POST_INSTALL_SHOWN:-0}" == "1" ]] && return 0
    _HB_POST_INSTALL_SHOWN=1
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    local version="${HONEY_BADGER_VERSION:-2.4.0}"
    local codename="${HONEY_BADGER_CODENAME:-}"

    printf '\n'
    hb_rule
    printf '  %b%s%b %b%s%b\n' "$HB_OK" "$_HB_G_OK" "$NC" "${BOLD}${HB_OK}" \
        "Ratel Forge ${version}${codename:+ \"$codename\"} installation complete" "$NC"
    hb_rule

    hb_section "Next steps"
    if [[ "$install_type" != "minimal" ]]; then
        printf '  %b1.%b Reboot to start your new desktop environment\n' "$HB_ACCENT" "$NC"
        printf '     %bsudo reboot%b\n' "$HB_ACCENT_ALT" "$NC"
        printf '  %b2.%b After login, run %bhoney-badger-info%b to verify the setup\n' \
            "$HB_ACCENT" "$NC" "$HB_ACCENT_ALT" "$NC"
    else
        printf '  %b1.%b Reload your shell: %bsource ~/.bashrc%b\n' \
            "$HB_ACCENT" "$NC" "$HB_ACCENT_ALT" "$NC"
        printf '  %b2.%b Try the enhanced editor: %bnano%b\n' \
            "$HB_ACCENT" "$NC" "$HB_ACCENT_ALT" "$NC"
    fi

    hb_section "Commands"
    hb_kv "honey-badger-info"    "show system and install details" 22
    hb_kv "honey-badger-update"  "update system and packages"      22
    hb_kv "honey-badger-install" "install additional packages"     22

    hb_section "Details"
    hb_kv "Installation log" "$LOG_FILE" 22
    hb_kv "Uninstall"        "bash uninstall.sh" 22
    hb_rule

    # Write machine-readable summary if the JSON helpers are available
    if declare -f hb_json_write >/dev/null 2>&1; then
        hb_json_write
    fi
}
