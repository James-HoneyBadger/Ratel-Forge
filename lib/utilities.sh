#!/bin/bash
# shellcheck disable=SC2034  # Variables are consumed by the sourcing script
# shellcheck disable=SC2088  # Tilde strings are human-readable labels, not paths
# Ratel Forge - Utility command generation and post-install report
# ---------------------------------------------------------------------------
# Installs honey-badger-* commands from assets/, writes their metadata
# (install-info, pm.conf, palette.env, ui.sh), and renders the post-install
# summary.
#
# Sourced by lib/common.sh; do not source directly.
# ---------------------------------------------------------------------------

# Prevent double-sourcing
[[ -n "${_HB_UTILITIES_LOADED:-}" ]] && return 0
readonly _HB_UTILITIES_LOADED=1

# ── Utility script creation ──────────────────────────────────────────────────
# Creates distro-aware utility scripts. Caller passes the package manager
# commands, which are recorded in ~/.local/share/honey-badger/pm.conf so the
# installed commands stay data-driven.
#   create_utility_scripts <update> <install> <clean> [search] [remove]
# E.g.: create_utility_scripts \
#           "sudo pacman -Syu --noconfirm" \
#           "sudo pacman -S --needed --noconfirm" \
#           "sudo pacman -Sc --noconfirm" \
#           "pacman -Ss" \
#           "sudo pacman -Rns --noconfirm"
create_utility_scripts() {
    local pm_update_cmd="${1:-}"
    local pm_install_cmd="${2:-}"
    local pm_clean_cmd="${3:-}"
    local pm_search_cmd="${4:-}"
    local pm_remove_cmd="${5:-}"

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

    # ── Package manager commands used by update/install ──
    cat > "$share_dir/pm.conf" << ENDPM
# Ratel Forge package manager commands — generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
HB_PM_UPDATE=${pm_update_cmd@Q}
HB_PM_INSTALL=${pm_install_cmd@Q}
HB_PM_CLEAN=${pm_clean_cmd@Q}
HB_PM_SEARCH=${pm_search_cmd@Q}
HB_PM_REMOVE=${pm_remove_cmd@Q}
ENDPM

    # ── Install metadata (read by every utility) ──
    local components variant="none" has_desktop=0
    components="$(hb_effective_components)"
    if hb_desktop_enabled && ! hb_skip_component theme; then
        variant="$(hb_theme_name)"
        has_desktop=1
    fi
    cat > "$share_dir/install-info" << ENDINFO
# Ratel Forge install metadata — generated $(date -u +%Y-%m-%dT%H:%M:%SZ)
HONEY_BADGER_VERSION="${HONEY_BADGER_VERSION:-2.5.0}"
HONEY_BADGER_CODENAME="${HONEY_BADGER_CODENAME:-Fearless}"
HONEY_BADGER_INSTALL_TYPE="${HONEY_BADGER_INSTALL_TYPE:-full}"
HONEY_BADGER_COMPONENTS="${components}"
HONEY_BADGER_HAS_DESKTOP=${has_desktop}
HONEY_BADGER_THEME_VARIANT="${variant}"
HONEY_BADGER_FONT="${HONEY_BADGER_FONT:-Noto Sans 10}"
HONEY_BADGER_MONO_FONT="${HONEY_BADGER_MONO_FONT:-Noto Sans Mono 10}"
HONEY_BADGER_DISTRO="${HONEY_BADGER_DISTRO:-unknown}"
HONEY_BADGER_BUILD_DATE="${HONEY_BADGER_BUILD_DATE:-unknown}"
HONEY_BADGER_LOG="${LOG_FILE:-unknown}"
ENDINFO

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

    # ── Utility commands (single source of truth: assets/) ──
    local utility
    for utility in info update install theme doctor uninstall; do
        local src="$HONEY_BADGER_ROOT/assets/honey-badger-$utility"
        if [[ -f "$src" ]]; then
            install -m 755 "$src" "$bin_dir/honey-badger-$utility"
        else
            log_warning "Utility source missing: $src"
        fi
    done

    # The uninstaller is self-contained; ship it so removal works without the checkout.
    if [[ -f "$HONEY_BADGER_ROOT/uninstall.sh" ]]; then
        install -m 644 "$HONEY_BADGER_ROOT/uninstall.sh" "$share_dir/uninstall.sh"
    fi

    # ── Shell completion (loaded automatically by bash-completion) ──
    local completion_dir
    completion_dir="${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions"
    if [[ -f "$HONEY_BADGER_ROOT/completions/honey-badger.bash" ]]; then
        mkdir -p "$completion_dir"
        install -m 644 "$HONEY_BADGER_ROOT/completions/honey-badger.bash" \
            "$completion_dir/honey-badger"
    fi

    hb_json_add_config "~/.local/bin/honey-badger-*"
    hb_json_add_config "~/.local/share/honey-badger/install-info"
    log_success "Utility scripts created in $bin_dir"
}

# ── Post-install summary ────────────────────────────────────────────────────
show_post_install() {
    [[ "${_HB_POST_INSTALL_SHOWN:-0}" == "1" ]] && return 0
    _HB_POST_INSTALL_SHOWN=1
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    local version="${HONEY_BADGER_VERSION:-2.5.0}"
    local codename="${HONEY_BADGER_CODENAME:-}"
    local desktop=0 variant="none"
    if hb_desktop_enabled; then
        desktop=1
        variant="$(hb_theme_name)"
    fi

    printf '\n'
    hb_rule
    printf '  %b%s%b %b%s%b\n' "$HB_OK" "$_HB_G_OK" "$NC" "${BOLD}${HB_OK}" \
        "Ratel Forge ${version}${codename:+ \"$codename\"} installation complete" "$NC"
    hb_rule

    hb_section "Next steps"
    if [[ $desktop -eq 1 ]]; then
        printf '  %b1.%b Reboot to start your new desktop environment\n' "$HB_ACCENT" "$NC"
        printf '     %bsudo reboot%b\n' "$HB_ACCENT_ALT" "$NC"
        printf '  %b2.%b After login, run %bhoney-badger-info%b to verify the setup\n' \
            "$HB_ACCENT" "$NC" "$HB_ACCENT_ALT" "$NC"
        printf '  %b3.%b Try another palette later: %bhoney-badger-theme list%b\n' \
            "$HB_ACCENT" "$NC" "$HB_ACCENT_ALT" "$NC"
    else
        printf '  %b1.%b Reload your shell: %bsource ~/.bashrc%b\n' \
            "$HB_ACCENT" "$NC" "$HB_ACCENT_ALT" "$NC"
        printf '  %b2.%b Verify the setup: %bhoney-badger-info%b\n' \
            "$HB_ACCENT" "$NC" "$HB_ACCENT_ALT" "$NC"
        printf '  %b3.%b Add a desktop later by re-running the installer with\n' \
            "$HB_ACCENT" "$NC"
        printf '     %b--type desktop%b\n' "$HB_ACCENT_ALT" "$NC"
    fi

    hb_section "Commands"
    hb_kv "honey-badger-info"    "system and install details" 22
    hb_kv "honey-badger-update"  "update system and packages"  22
    hb_kv "honey-badger-install" "install, search, or remove"  22
    if [[ $desktop -eq 1 ]]; then
        hb_kv "honey-badger-theme" "switch themes and palettes" 22
        hb_kv "honey-badger-doctor" "diagnose the installation" 22
    fi
    hb_kv "honey-badger-uninstall" "remove Ratel Forge customizations" 22

    hb_section "Details"
    hb_kv "Install type"     "$install_type ($(hb_effective_components))" 22
    if [[ "$variant" != "none" ]]; then
        hb_kv "Theme" "$variant" 22
    fi
    hb_kv "Installation log" "${LOG_FILE:-unknown}" 22
    hb_rule

    # Write machine-readable summary if the JSON helpers are available
    if declare -f hb_json_write >/dev/null 2>&1; then
        hb_json_write
    fi
}
