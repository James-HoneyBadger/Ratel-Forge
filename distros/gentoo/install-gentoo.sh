#!/bin/bash
# Ratel Forge - Gentoo Post-Install Script
# Supports: Gentoo Linux, Funtoo

set -euo pipefail

# Source shared library
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/common.sh"

hb_init_distro_log "gentoo"

# ── Package lists ────────────────────────────────────────────────────────────
# Data lives in config/packages/gentoo.conf so package changes are reviewable
# without touching shell logic. Loaded into BASE_PACKAGES, DEVELOPER_PACKAGES, …
hb_load_package_manifest "$HONEY_BADGER_ROOT/config/packages/gentoo.conf"

# ── Banner ───────────────────────────────────────────────────────────────────
show_banner() {
    hb_show_banner "Gentoo" "Gentoo-based provisioning"
}

# ── System check ─────────────────────────────────────────────────────────────
check_gentoo_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "Detected: ${PRETTY_NAME:-Gentoo Linux}"
    fi
}

# ── System update ────────────────────────────────────────────────────────────
update_system() {
    hb_next_step "Syncing Portage tree and updating system..."
    hb_sudo emerge --sync --quiet
    hb_sudo emerge --update --deep --newuse @world --quiet || true
    hb_outcome "Would update system packages" "System updated successfully"
}

# ── Package installation ────────────────────────────────────────────────────
install_emerge_packages() {
    local -n packages_ref=$1
    local package_type="$2"
    if ! hb_component_allowed "$package_type"; then
        log_info "Skipping $package_type (component disabled by --components)"
        return 0
    fi
    if [[ ${#packages_ref[@]} -eq 0 ]]; then
        log_info "No $package_type packages to install"
        return 0
    fi
    hb_next_step "Installing $package_type packages..."
    local -a available_packages=()
    for package in "${packages_ref[@]}"; do
        # Check if already installed (strip category for qlist check)
        local pkg_name="${package##*/}"
        if qlist -I "$pkg_name" >/dev/null 2>&1 || equery list "$package" >/dev/null 2>&1; then
            log_info "$package already installed"
        else
            available_packages+=("$package")
        fi
    done
    if [[ ${#available_packages[@]} -gt 0 ]]; then
        if hb_sudo emerge --ask=n --quiet "${available_packages[@]}"; then
            for p in "${available_packages[@]}"; do hb_json_add_package "$p"; done
            hb_outcome "Would install $package_type packages" "Installed $package_type packages"
        else
            log_warning "Some $package_type packages failed to install"
            hb_json_add_error "Some $package_type packages failed"
        fi
    else
        log_info "All $package_type packages already installed"
    fi
}

# ── Main installation by type ───────────────────────────────────────────────
install_packages_by_type() {
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    log_info "Installation type: $install_type"
    install_emerge_packages BASE_PACKAGES "base"
    install_emerge_packages CLI_TOOLS_PACKAGES "base tools"
    case "$install_type" in
        "full")
            install_emerge_packages DEVELOPER_PACKAGES "developer"
            install_emerge_packages APPLICATIONS_PACKAGES "applications"
            ;;
        "developer")
            install_emerge_packages DEVELOPER_PACKAGES "developer"
            ;;
        "apps")
            install_emerge_packages APPLICATIONS_PACKAGES "applications"
            ;;
        "minimal")
            log_info "Minimal installation - CLI tools only"
            ;;
        *)
            log_error "Unknown installation type: $install_type"
            exit 1
            ;;
    esac
}

# ── Development tools (Gentoo-specific) ──────────────────────────────────────
setup_dev_gentoo() {
    if ! hb_component_enabled dev; then
        log_info "Skipping setup_dev_gentoo (dev component disabled)"
        return 0
    fi

    hb_next_step "Installing Gentoo development tools..."
    setup_development_environment
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo "Ratel Forge - Gentoo Installation Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    hb_json_init
    hb_rollback_init
    export HONEY_BADGER_DISTRO="gentoo"
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    if hb_skip_active; then
        # Skips and component filters change the step count; show [n] instead
        # of a fraction that would not add up.
        hb_set_total_steps 0
    else
        case "$install_type" in
            full)      hb_set_total_steps 12 ;;
            developer) hb_set_total_steps 11 ;;
            apps)      hb_set_total_steps 7 ;;
            minimal)   hb_set_total_steps 6 ;;
        esac
    fi
    hb_phases_init "$install_type"
    show_banner
    check_gentoo_system
    hb_phase update update_system
    hb_phase packages install_packages_by_type
    hb_phase nano setup_nano
    hb_phase shell setup_shell
    hb_phase utilities create_utility_scripts \
        "sudo emerge --sync && sudo emerge --update --deep --changed-use @world" \
        "sudo emerge --noreplace" \
        "sudo emerge --depclean && sudo eclean-dist --deep" \
        "emerge --search" \
        "sudo emerge --unmerge" \
        "emerge --pretend --update --deep --newuse @world --quiet"
    if [[ "$install_type" == "full" || "$install_type" == "developer" ]]; then
        hb_phase dev setup_dev_gentoo
    fi
    show_post_install
}

main "$@"
