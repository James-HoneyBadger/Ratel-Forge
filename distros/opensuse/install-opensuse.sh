#!/bin/bash
# Ratel Forge - openSUSE Post-Install Script
# Supports: openSUSE Tumbleweed, openSUSE Leap, SLES, GeckoLinux

set -euo pipefail

# Source shared library
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/common.sh"

hb_init_distro_log "opensuse"

# ── Package lists ────────────────────────────────────────────────────────────
# Data lives in config/packages/opensuse.conf so package changes are reviewable
# without touching shell logic. Loaded into BASE_PACKAGES, DEVELOPER_PACKAGES, …
hb_load_package_manifest "$HONEY_BADGER_ROOT/config/packages/opensuse.conf"

# ── Banner ───────────────────────────────────────────────────────────────────
show_banner() {
    hb_show_banner "openSUSE" "openSUSE-based provisioning"
}

# ── System check ─────────────────────────────────────────────────────────────
check_opensuse_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "Detected: ${PRETTY_NAME:-openSUSE}"
    fi
}

# ── System update ────────────────────────────────────────────────────────────
update_system() {
    hb_next_step "Refreshing repositories and updating system..."
    hb_sudo zypper --non-interactive refresh
    hb_sudo zypper --non-interactive update
    hb_outcome "Would update system packages" "System updated successfully"
}

# ── Package installation ────────────────────────────────────────────────────
install_zypper_packages() {
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
        if rpm -q "$package" >/dev/null 2>&1; then
            log_info "$package already installed"
        elif zypper --non-interactive info "$package" >/dev/null 2>&1; then
            available_packages+=("$package")
        else
            log_warning "$package not available in repositories"
        fi
    done
    if [[ ${#available_packages[@]} -gt 0 ]]; then
        if hb_sudo zypper --non-interactive install --no-confirm "${available_packages[@]}"; then
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

# ── XFCE service setup (openSUSE-specific) ───────────────────────────────────
setup_xfce_opensuse() {
    hb_next_step "Setting up XFCE desktop for openSUSE..."
    # Install XFCE pattern
    hb_sudo zypper --non-interactive install -t pattern xfce 2>/dev/null || true
    hb_sudo systemctl set-default graphical.target 2>/dev/null || true
    setup_xfce
}

# ── Packman repository (multimedia codecs) ───────────────────────────────────
setup_packman() {
    hb_next_step "Setting up Packman repository for multimedia codecs..."
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        local repo_url=""
        if [[ "$ID" == "opensuse-tumbleweed" ]] || [[ "${VERSION_ID:-}" == "" ]]; then
            repo_url="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/"
        else
            repo_url="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_${VERSION_ID}/"
        fi
        if ! zypper repos | grep -qi packman; then
            hb_sudo zypper ar -cfp 90 "$repo_url" packman 2>/dev/null || true
            hb_sudo zypper --non-interactive refresh 2>/dev/null || true
        fi
        hb_outcome "Would configure the Packman repository" "Packman repository configured"
    fi
}

# ── Main installation by type ───────────────────────────────────────────────
install_packages_by_type() {
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    log_info "Installation type: $install_type"
    install_zypper_packages BASE_PACKAGES "base"
    case "$install_type" in
        "full")
            install_zypper_packages DEVELOPER_PACKAGES "developer"
            install_zypper_packages DESKTOP_PACKAGES "desktop"
            install_zypper_packages APPLICATIONS_PACKAGES "applications"
            setup_packman
            setup_xfce_opensuse
            ;;
        "developer")
            install_zypper_packages DEVELOPER_PACKAGES "developer"
            install_zypper_packages DESKTOP_PACKAGES "basic desktop"
            setup_xfce_opensuse
            ;;
        "desktop")
            install_zypper_packages DESKTOP_PACKAGES "desktop"
            install_zypper_packages APPLICATIONS_PACKAGES "applications"
            local -a basic_dev=("python3" "python3-pip" "nodejs" "npm" "git")
            install_zypper_packages basic_dev "basic development"
            setup_packman
            setup_xfce_opensuse
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

# ── Development tools (openSUSE-specific) ────────────────────────────────────
setup_dev_opensuse() {
    if ! hb_component_enabled dev; then
        log_info "Skipping setup_dev_opensuse (dev component disabled)"
        return 0
    fi

    hb_next_step "Installing openSUSE development pattern..."
    hb_sudo zypper --non-interactive install -t pattern devel_basis 2>/dev/null || true
    setup_development_environment
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo "Ratel Forge - openSUSE Installation Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    hb_json_init
    hb_rollback_init
    export HONEY_BADGER_DISTRO="opensuse"
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    if hb_skip_active; then
        # Skips and component filters change the step count; show [n] instead
        # of a fraction that would not add up.
        hb_set_total_steps 0
    else
        case "$install_type" in
            full)      hb_set_total_steps 16 ;;
            developer) hb_set_total_steps 14 ;;
            desktop)   hb_set_total_steps 12 ;;
            minimal)   hb_set_total_steps 4 ;;
        esac
    fi
    hb_phases_init "$install_type"
    show_banner
    check_opensuse_system
    hb_phase update update_system
    hb_phase packages install_packages_by_type
    hb_phase nano setup_nano
    hb_phase utilities create_utility_scripts \
        "sudo zypper --non-interactive update" \
        "sudo zypper --non-interactive install" \
        "sudo zypper --non-interactive clean --all" \
        "zypper search" \
        "sudo zypper --non-interactive remove"
    if hb_desktop_enabled; then
        if ! hb_skip_component "theme"; then
            hb_phase theme setup_honey_badger_theme
            hb_phase assets install_assets
        fi
    fi
    if [[ "$install_type" == "full" || "$install_type" == "developer" ]]; then
        hb_phase dev setup_dev_opensuse
    fi
    show_post_install
}

main "$@"
