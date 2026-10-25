#!/bin/bash
# Ratel Forge - Void Linux Post-Install Script
# Supports: Void Linux (glibc and musl)

set -euo pipefail

# Source shared library
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/common.sh"

hb_init_distro_log "void"

# ── Package lists ────────────────────────────────────────────────────────────
# Data lives in config/packages/void.conf so package changes are reviewable
# without touching shell logic. Loaded into BASE_PACKAGES, DEVELOPER_PACKAGES, …
hb_load_package_manifest "$HONEY_BADGER_ROOT/config/packages/void.conf"

# ── Banner ───────────────────────────────────────────────────────────────────
show_banner() {
    hb_show_banner "Void Linux" "Void Linux provisioning"
}

# ── System check ─────────────────────────────────────────────────────────────
check_void_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "Detected: ${PRETTY_NAME:-Void Linux}"
    fi
}

# ── System update ────────────────────────────────────────────────────────────
update_system() {
    hb_next_step "Updating system packages..."
    hb_sudo xbps-install -Syu
    hb_outcome "Would update system packages" "System updated successfully"
}

# ── Package installation ────────────────────────────────────────────────────
install_xbps_packages() {
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
        if xbps-query "$package" >/dev/null 2>&1; then
            log_info "$package already installed"
        elif xbps-query -R "$package" >/dev/null 2>&1; then
            available_packages+=("$package")
        else
            log_warning "$package not available in repositories"
        fi
    done
    if [[ ${#available_packages[@]} -gt 0 ]]; then
        if hb_sudo xbps-install -y "${available_packages[@]}"; then
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

# ── Void-specific service management (runit) ────────────────────────────────
enable_runit_service() {
    local service="$1"
    if [[ -d "/etc/sv/$service" ]]; then
        if [[ ! -L "/var/service/$service" ]]; then
            hb_sudo ln -sf "/etc/sv/$service" /var/service/
            log_success "Enabled runit service: $service"
        else
            log_info "Service $service already enabled"
        fi
    else
        log_warning "Service $service not found in /etc/sv/"
    fi
}

# ── XFCE setup (Void-specific with runit) ───────────────────────────────────
setup_xfce_void() {
    hb_next_step "Setting up XFCE desktop for Void Linux..."
    enable_runit_service "lightdm"
    enable_runit_service "NetworkManager"
    enable_runit_service "dbus"
    setup_xfce
}

# ── Main installation by type ───────────────────────────────────────────────
install_packages_by_type() {
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    log_info "Installation type: $install_type"
    install_xbps_packages BASE_PACKAGES "base"
    case "$install_type" in
        "full")
            install_xbps_packages DEVELOPER_PACKAGES "developer"
            install_xbps_packages DESKTOP_PACKAGES "desktop"
            install_xbps_packages APPLICATIONS_PACKAGES "applications"
            setup_xfce_void
            ;;
        "developer")
            install_xbps_packages DEVELOPER_PACKAGES "developer"
            install_xbps_packages DESKTOP_PACKAGES "basic desktop"
            setup_xfce_void
            ;;
        "desktop")
            install_xbps_packages DESKTOP_PACKAGES "desktop"
            install_xbps_packages APPLICATIONS_PACKAGES "applications"
            local -a basic_dev=("python3" "python3-pip" "nodejs" "git")
            install_xbps_packages basic_dev "basic development"
            setup_xfce_void
            ;;
        "minimal")
            log_info "Minimal installation - desktop environment skipped"
            ;;
        *)
            log_error "Unknown installation type: $install_type"
            exit 1
            ;;
    esac
}

# ── Docker setup (Void-specific with runit) ─────────────────────────────────
setup_docker_void() {
    if ! hb_component_enabled dev; then
        log_info "Skipping setup_docker_void (dev component disabled)"
        return 0
    fi

    if command -v docker >/dev/null 2>&1; then
        enable_runit_service "docker"
    fi
    setup_development_environment
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo "Ratel Forge - Void Linux Installation Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    hb_json_init
    hb_rollback_init
    export HONEY_BADGER_DISTRO="void"
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    if hb_skip_active; then
        # Skips and component filters change the step count; show [n] instead
        # of a fraction that would not add up.
        hb_set_total_steps 0
    else
        case "$install_type" in
            full)      hb_set_total_steps 14 ;;
            developer) hb_set_total_steps 13 ;;
            desktop)   hb_set_total_steps 11 ;;
            minimal)   hb_set_total_steps 4 ;;
        esac
    fi
    hb_phases_init "$install_type"
    show_banner
    check_void_system
    hb_phase update update_system
    hb_phase packages install_packages_by_type
    hb_phase nano setup_nano
    hb_phase utilities create_utility_scripts \
        "sudo xbps-install -Syu" \
        "sudo xbps-install -y" \
        "sudo xbps-remove -Oo" \
        "xbps-query -Rs" \
        "sudo xbps-remove -R"
    if hb_desktop_enabled; then
        if ! hb_skip_component "theme"; then
            hb_phase theme setup_honey_badger_theme
            hb_phase assets install_assets
        fi
    fi
    if [[ "$install_type" == "full" || "$install_type" == "developer" ]]; then
        hb_phase dev setup_docker_void
    fi
    show_post_install
}

main "$@"
