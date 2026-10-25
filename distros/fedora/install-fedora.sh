#!/bin/bash
# Ratel Forge - Fedora/RHEL Post-Install Script
# Supports: Fedora, RHEL, CentOS, AlmaLinux, Rocky Linux

set -euo pipefail

# Source shared library
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/common.sh"

hb_init_distro_log "fedora"

# ── Package lists ────────────────────────────────────────────────────────────
# Data lives in config/packages/fedora.conf so package changes are reviewable
# without touching shell logic. Loaded into BASE_PACKAGES, DEVELOPER_PACKAGES, …
hb_load_package_manifest "$HONEY_BADGER_ROOT/config/packages/fedora.conf"

# ── Banner ───────────────────────────────────────────────────────────────────
show_banner() {
    hb_show_banner "Fedora/RHEL" "Fedora-based provisioning"
}

# ── System check ─────────────────────────────────────────────────────────────
check_fedora_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "Detected: ${PRETTY_NAME:-Fedora}"
    fi
}

# Determine package manager
get_pm() {
    if command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    else
        echo "yum"
    fi
}

# ── System update ────────────────────────────────────────────────────────────
update_system() {
    hb_next_step "Updating system packages..."
    local pm
    pm="$(get_pm)"
    hb_sudo "$pm" update -y
    hb_outcome "Would update system packages" "System updated successfully"
}

# ── Package installation ────────────────────────────────────────────────────
install_dnf_packages() {
    local -n packages_ref=$1
    local package_type="$2"
    if ! hb_component_allowed "$package_type"; then
        log_info "Skipping $package_type (component disabled by --components)"
        return 0
    fi
    local pm
    pm="$(get_pm)"
    if [[ ${#packages_ref[@]} -eq 0 ]]; then
        log_info "No $package_type packages to install"
        return 0
    fi
    hb_next_step "Installing $package_type packages..."
    local -a available_packages=()
    for package in "${packages_ref[@]}"; do
        if rpm -q "$package" >/dev/null 2>&1; then
            log_info "$package already installed"
        elif "$pm" info "$package" >/dev/null 2>&1; then
            available_packages+=("$package")
        else
            log_warning "$package not available in repositories"
        fi
    done
    if [[ ${#available_packages[@]} -gt 0 ]]; then
        if hb_sudo "$pm" install -y "${available_packages[@]}"; then
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

# ── XFCE service setup (Fedora-specific) ─────────────────────────────────────
setup_xfce_fedora() {
    hb_next_step "Setting up XFCE desktop for Fedora..."
    # Install XFCE group
    local pm
    pm="$(get_pm)"
    hb_sudo "$pm" groupinstall -y "Xfce Desktop" 2>/dev/null || true
    hb_sudo systemctl set-default graphical.target 2>/dev/null || true
    setup_xfce
}

# ── Main installation by type ───────────────────────────────────────────────
install_packages_by_type() {
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    log_info "Installation type: $install_type"
    install_dnf_packages BASE_PACKAGES "base"
    case "$install_type" in
        "full")
            install_dnf_packages DEVELOPER_PACKAGES "developer"
            install_dnf_packages DESKTOP_PACKAGES "desktop"
            install_dnf_packages APPLICATIONS_PACKAGES "applications"
            setup_xfce_fedora
            ;;
        "developer")
            install_dnf_packages DEVELOPER_PACKAGES "developer"
            install_dnf_packages DESKTOP_PACKAGES "basic desktop"
            setup_xfce_fedora
            ;;
        "desktop")
            install_dnf_packages DESKTOP_PACKAGES "desktop"
            install_dnf_packages APPLICATIONS_PACKAGES "applications"
            local -a basic_dev=("python3" "python3-pip" "nodejs" "npm" "git")
            install_dnf_packages basic_dev "basic development"
            setup_xfce_fedora
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

# ── Development tools (Fedora-specific) ──────────────────────────────────────
setup_dev_fedora() {
    if ! hb_component_enabled dev; then
        log_info "Skipping setup_dev_fedora (dev component disabled)"
        return 0
    fi

    hb_next_step "Installing Fedora development group..."
    local pm
    pm="$(get_pm)"
    hb_sudo "$pm" groupinstall -y "Development Tools" 2>/dev/null || true
    setup_development_environment
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo "Ratel Forge - Fedora Installation Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    hb_json_init
    hb_rollback_init
    export HONEY_BADGER_DISTRO="fedora"
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    local pm
    pm="$(get_pm)"
    if hb_skip_active; then
        # Skips and component filters change the step count; show [n] instead
        # of a fraction that would not add up.
        hb_set_total_steps 0
    else
        case "$install_type" in
            full)      hb_set_total_steps 15 ;;
            developer) hb_set_total_steps 14 ;;
            desktop)   hb_set_total_steps 11 ;;
            minimal)   hb_set_total_steps 4 ;;
        esac
    fi
    hb_phases_init "$install_type"
    show_banner
    check_fedora_system
    hb_phase update update_system
    hb_phase packages install_packages_by_type
    hb_phase nano setup_nano
    hb_phase utilities create_utility_scripts \
        "sudo $pm update -y" \
        "sudo $pm install -y" \
        "sudo $pm autoremove -y && sudo $pm clean all" \
        "$pm search" \
        "sudo $pm remove -y"
    if hb_desktop_enabled; then
        if ! hb_skip_component "theme"; then
            hb_phase theme setup_honey_badger_theme
            hb_phase assets install_assets
        fi
    fi
    if [[ "$install_type" == "full" || "$install_type" == "developer" ]]; then
        hb_phase dev setup_dev_fedora
    fi
    show_post_install
}

main "$@"
