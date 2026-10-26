#!/bin/bash
# Ratel Forge - Arch Linux Post-Install Script
# Supports: Arch Linux, Manjaro, EndeavourOS, ArcoLinux, Artix

set -euo pipefail

# Source shared library
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/common.sh"

hb_init_distro_log "arch"

# ── Package lists ────────────────────────────────────────────────────────────
# Data lives in config/packages/arch.conf so package changes are reviewable
# without touching shell logic. Loaded into BASE_PACKAGES, DEVELOPER_PACKAGES, …
hb_load_package_manifest "$HONEY_BADGER_ROOT/config/packages/arch.conf"

# ── Banner ───────────────────────────────────────────────────────────────────
show_banner() {
    hb_show_banner "Arch Linux" "Arch-based provisioning"
}

# ── System check ─────────────────────────────────────────────────────────────
check_arch_system() {
    if ! command -v pacman >/dev/null 2>&1; then
        log_error "This script is for Arch-based systems only!"
        exit 1
    fi
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "Detected: ${PRETTY_NAME:-Arch Linux}"
    fi
}

# ── System update ────────────────────────────────────────────────────────────
update_system() {
    hb_next_step "Updating system packages..."
    # -Syu in one call: refreshing the database separately (-Sy) leaves a
    # window where packages can be installed against a newer database.
    hb_sudo pacman -Syu --noconfirm
    hb_outcome "Would update system packages" "System updated successfully"
}

# ── AUR helper ───────────────────────────────────────────────────────────────
install_yay() {
    if ! hb_component_enabled apps && ! hb_component_enabled dev; then
        log_info "Skipping yay (apps and dev components disabled)"
        return 0
    fi
    hb_next_step "Installing yay AUR helper..."
    if command -v yay >/dev/null 2>&1; then
        log_info "yay AUR helper already installed"
        return 0
    fi
    if hb_dry_run; then
        log_info "[DRY-RUN] Would build and install the yay AUR helper"
        return 0
    fi
    hb_sudo pacman -S --noconfirm --needed base-devel git
    local temp_dir
    temp_dir="$(mktemp -d)"
    hb_register_temp "$temp_dir"
    if ! git clone https://aur.archlinux.org/yay.git "$temp_dir"; then
        log_error "Failed to clone yay repository"
        return 1
    fi
    (cd "$temp_dir" && makepkg -si --noconfirm)
    rm -rf "$temp_dir"
    hb_outcome "Would install yay" "yay AUR helper installed"
}

# ── Package installation ────────────────────────────────────────────────────
install_pacman_packages() {
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
        if pacman -Qi "$package" >/dev/null 2>&1; then
            log_info "$package already installed"
        elif pacman -Si "$package" >/dev/null 2>&1 ||
             pacman -Sgq "$package" >/dev/null 2>&1; then
            available_packages+=("$package")
        else
            log_warning "$package not available in repositories"
        fi
    done
    if [[ ${#available_packages[@]} -gt 0 ]]; then
        if hb_sudo pacman -S --noconfirm --needed "${available_packages[@]}"; then
            for p in "${available_packages[@]}"; do hb_json_add_package "$p"; done
            hb_outcome "Would install $package_type packages" "Installed $package_type packages"
        else
            log_warning "Some $package_type packages failed to install"
            hb_json_add_error "Some $package_type packages failed"
        fi
    else
        log_info "All $package_type packages already installed or unavailable"
    fi
}

install_aur_packages() {
    local -n packages_ref=$1
    local package_type="$2"
    if ! hb_component_allowed "$package_type"; then
        log_info "Skipping $package_type (component disabled by --components)"
        return 0
    fi
    if ! command -v yay >/dev/null 2>&1; then
        log_warning "yay not available, skipping AUR packages"
        return 0
    fi
    if [[ ${#packages_ref[@]} -eq 0 ]]; then return 0; fi
    hb_next_step "Installing $package_type AUR packages..."
    if hb_dry_run; then
        for package in "${packages_ref[@]}"; do
            log_info "[DRY-RUN] Would install AUR package: $package"
        done
        return 0
    fi
    for package in "${packages_ref[@]}"; do
        if pacman -Qi "$package" >/dev/null 2>&1; then
            log_info "$package already installed"
        elif yay -S --noconfirm --needed "$package" 2>/dev/null; then
            hb_json_add_package "$package"
            hb_outcome "Would install $package from AUR" "Installed $package from AUR"
        else
            log_warning "Failed to install $package from AUR"
        fi
    done
}

# ── Main installation by type ───────────────────────────────────────────────
install_packages_by_type() {
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    log_info "Installation type: $install_type"
    install_pacman_packages BASE_PACKAGES "base"
    install_pacman_packages CLI_TOOLS_PACKAGES "base tools"
    case "$install_type" in
        "full")
            install_pacman_packages DEVELOPER_PACKAGES "developer"
            install_pacman_packages APPLICATIONS_PACKAGES "applications"
            install_yay
            install_aur_packages AUR_PACKAGES "AUR"
            ;;
        "developer")
            install_pacman_packages DEVELOPER_PACKAGES "developer"
            install_yay
            local -a dev_aur=("visual-studio-code-bin" "postman-bin")
            install_aur_packages dev_aur "development AUR"
            ;;
        "apps")
            install_pacman_packages APPLICATIONS_PACKAGES "applications"
            install_yay
            install_aur_packages AUR_PACKAGES "AUR"
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

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo "Ratel Forge - Arch Linux Installation Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    hb_json_init
    hb_rollback_init
    export HONEY_BADGER_DISTRO="arch"
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    if hb_skip_active; then
        # Skips and component filters change the step count; show [n] instead
        # of a fraction that would not add up.
        hb_set_total_steps 0
    else
        case "$install_type" in
            full)      hb_set_total_steps 13 ;;
            developer) hb_set_total_steps 12 ;;
            apps)      hb_set_total_steps 9 ;;
            minimal)   hb_set_total_steps 6 ;;
        esac
    fi
    hb_phases_init "$install_type"
    show_banner
    hb_phase update update_system
    hb_phase packages install_packages_by_type
    hb_phase nano setup_nano
    hb_phase shell setup_shell
    hb_phase utilities create_utility_scripts \
        "sudo pacman -Syu --noconfirm" \
        "sudo pacman -S --needed --noconfirm" \
        "sudo pacman -Sc --noconfirm" \
        "pacman -Ss" \
        "sudo pacman -Rns --noconfirm" \
        "pacman -Qu"
    if [[ "$install_type" == "full" || "$install_type" == "developer" ]]; then
        hb_phase dev setup_development_environment
    fi
    show_post_install
}

main "$@"
