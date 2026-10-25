#!/bin/bash
# Ratel Forge - Slackware Post-Install Script
# Supports: Slackware Linux (14.2+, 15.0+, -current)

set -euo pipefail

# Source shared library
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/common.sh"

hb_init_distro_log "slackware"

# ── Package lists ────────────────────────────────────────────────────────────
# Data lives in config/packages/slackware.conf so package changes are reviewable
# without touching shell logic. Loaded into BASE_PACKAGES, DEVELOPER_PACKAGES, …
hb_load_package_manifest "$HONEY_BADGER_ROOT/config/packages/slackware.conf"

# ── Banner ──────────────────────────────────────────────────────────────────
show_banner() {
    hb_show_banner "Slackware" "Slackware provisioning"
}

# ── System check ────────────────────────────────────────────────────────────
check_slackware_system() {
    if [[ -f /etc/slackware-version ]]; then
        log_info "Detected: $(cat /etc/slackware-version)"
    fi
}

# ── slackpkg setup ──────────────────────────────────────────────────────────
setup_slackpkg() {
    hb_next_step "Configuring slackpkg mirrors..."
    if hb_dry_run; then
        log_info "[DRY-RUN] Would configure slackpkg mirrors and refresh metadata"
        return 0
    fi
    # Ensure at least one mirror is uncommented in /etc/slackpkg/mirrors
    if ! grep -q '^[^#]' /etc/slackpkg/mirrors 2>/dev/null; then
        log_warning "No active mirrors in /etc/slackpkg/mirrors"
        if is_noninteractive; then
            # Auto-enable the first commented mirror for the detected version
            local slack_ver
            slack_ver=$(sed -n 's/.*Slackware \([0-9.]*\).*/\1/p' /etc/slackware-version 2>/dev/null || echo "current")
            log_info "Non-interactive: attempting to auto-enable a mirror for Slackware ${slack_ver}"
            hb_sudo sed -i "0,/^#.*mirrors.slackware.com.*${slack_ver}/s/^#//" /etc/slackpkg/mirrors 2>/dev/null || \
            hb_sudo sed -i '0,/^#.*http/s/^#//' /etc/slackpkg/mirrors 2>/dev/null || \
            log_warning "Could not auto-enable a mirror; slackpkg may fail"
        else
            log_info "Please uncomment a mirror in /etc/slackpkg/mirrors before continuing"
            read -rp "Press Enter after configuring a mirror, or Ctrl-C to abort..."
        fi
    fi
    hb_sudo slackpkg update gpg 2>/dev/null || true
    hb_sudo slackpkg update
    hb_outcome "Would configure slackpkg" "slackpkg configured"
}

# ── System update ───────────────────────────────────────────────────────────
update_system() {
    hb_next_step "Updating system packages..."
    if is_noninteractive; then
        # batch mode: auto-accept
        echo "Y" | hb_sudo slackpkg upgrade-all || true
    else
        hb_sudo slackpkg upgrade-all || true
    fi
    hb_outcome "Would update system packages" "System updated"
}

# ── Disk set installation ───────────────────────────────────────────────────
install_disk_sets() {
    local -n sets_ref=$1
    local set_type="$2"
    if ! hb_component_allowed "$set_type"; then
        log_info "Skipping $set_type (component disabled by --components)"
        return 0
    fi
    hb_next_step "Installing $set_type disk sets..."
    for disk_set in "${sets_ref[@]}"; do
        log_info "Installing disk set: $disk_set"
        if is_noninteractive; then
            echo "Y" | hb_sudo slackpkg install-new "$disk_set" 2>/dev/null || true
        else
            hb_sudo slackpkg install-new "$disk_set" || true
        fi
    done
    hb_outcome "Would install $set_type disk sets" "Installed $set_type disk sets"
}

# ── Package installation ───────────────────────────────────────────────────
install_slack_packages() {
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
    local installed=0
    local failed=0
    for package in "${packages_ref[@]}"; do
        # Check if already installed
        if ls /var/log/packages/"${package}"-* >/dev/null 2>&1; then
            log_info "$package already installed"
            continue
        fi
        # Try slackpkg first
        if is_noninteractive; then
            if echo "Y" | hb_sudo slackpkg install "$package" 2>/dev/null; then
                hb_json_add_package "$package"
                installed=$((installed + 1))
            else
                # Try sbopkg if available
                if command -v sbopkg >/dev/null 2>&1; then
                    if hb_sudo sbopkg -i "$package" -B 2>/dev/null; then
                        hb_json_add_package "$package"
                        installed=$((installed + 1))
                    else
                        log_warning "Failed to install: $package"
                        failed=$((failed + 1))
                    fi
                else
                    log_warning "Failed to install: $package (sbopkg not available)"
                    failed=$((failed + 1))
                fi
            fi
        else
            if hb_sudo slackpkg install "$package" 2>/dev/null; then
                hb_json_add_package "$package"
                installed=$((installed + 1))
            else
                log_warning "Failed to install: $package"
                failed=$((failed + 1))
            fi
        fi
    done
    if [[ $failed -gt 0 ]]; then
        log_warning "Installed $installed $package_type packages ($failed failed)"
        hb_json_add_error "$failed $package_type packages failed"
    else
        hb_outcome "Would install $installed $package_type packages" "Installed $installed $package_type packages"
    fi
}

# ── sbopkg setup ────────────────────────────────────────────────────────────
setup_sbopkg() {
    hb_next_step "Setting up sbopkg (SlackBuilds.org package tool)..."
    if hb_dry_run; then
        log_info "[DRY-RUN] Would install sbopkg and sync its repository"
        return 0
    fi
    if command -v sbopkg >/dev/null 2>&1; then
        log_info "sbopkg already installed"
        hb_sudo sbopkg -r 2>/dev/null || true
        return 0
    fi
    # Resolve latest sbopkg release dynamically; fall back to known version
    local sbopkg_url
    sbopkg_url=$(curl -fsSL --connect-timeout 5 -o /dev/null -w '%{redirect_url}' \
        https://github.com/sbopkg/sbopkg/releases/latest 2>/dev/null || true)
    if [[ -n "$sbopkg_url" ]]; then
        local tag="${sbopkg_url##*/}"
        sbopkg_url="https://github.com/sbopkg/sbopkg/releases/download/${tag}/sbopkg-${tag}-noarch-1_wsr.tgz"
    else
        sbopkg_url="https://github.com/sbopkg/sbopkg/releases/latest/download/sbopkg-0.38.2-noarch-1_wsr.tgz"
    fi
    local tmp_pkg
    tmp_pkg=$(mktemp /tmp/sbopkg.XXXXXX.tgz)
    hb_register_temp "$tmp_pkg"
    if hb_download "$sbopkg_url" "$tmp_pkg" "${HONEY_BADGER_SBOPKG_SHA256:-}"; then
        hb_sudo installpkg "$tmp_pkg"
        rm -f "$tmp_pkg"
        hb_sudo sbopkg -r 2>/dev/null || true
        log_success "sbopkg installed and repository synced"
    else
        rm -f "$tmp_pkg"
        log_warning "Could not download sbopkg; some packages may not be available"
    fi
}

# ── XFCE setup (Slackware-specific) ────────────────────────────────────────
setup_xfce_slackware() {
    if ! hb_component_enabled desktop; then
        log_info "Skipping setup_xfce_slackware (desktop component disabled)"
        return 0
    fi

    hb_next_step "Configuring XFCE desktop for Slackware..."
    # Install X11 and XFCE sets
    install_disk_sets X_SET "X Window System"
    install_disk_sets XFCE_SET "XFCE desktop"
    # Set default runlevel to 4 (graphical) in inittab
    if [[ -f /etc/inittab ]] && grep -q "id:3:initdefault" /etc/inittab; then
        hb_backup_file /etc/inittab
        hb_sudo sed -i 's/id:3:initdefault/id:4:initdefault/' /etc/inittab
        log_success "Default runlevel set to 4 (graphical)"
    fi
    # Configure xinitrc for XFCE
    if [[ -d "$HOME" ]]; then
        if [[ ! -f "$HOME/.xinitrc" ]] || ! grep -q "xfce4-session" "$HOME/.xinitrc"; then
            hb_backup_file "$HOME/.xinitrc"
            echo "exec startxfce4" > "$HOME/.xinitrc"
            log_success "XFCE set as default session"
        fi
    fi
    setup_xfce
}

# ── Main installation by type ──────────────────────────────────────────────
install_packages_by_type() {
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    log_info "Installation type: $install_type"
    install_disk_sets BASE_SETS "base system"
    install_slack_packages BASE_PACKAGES "base utilities"
    case "$install_type" in
        "full")
            install_disk_sets DEVELOPER_SETS "development"
            install_slack_packages DEVELOPER_PACKAGES "developer"
            setup_xfce_slackware
            install_slack_packages DESKTOP_PACKAGES "desktop utilities"
            install_slack_packages APPLICATIONS_PACKAGES "applications"
            ;;
        "developer")
            install_disk_sets DEVELOPER_SETS "development"
            install_slack_packages DEVELOPER_PACKAGES "developer"
            setup_xfce_slackware
            install_slack_packages DESKTOP_PACKAGES "desktop utilities"
            ;;
        "desktop")
            setup_xfce_slackware
            install_slack_packages DESKTOP_PACKAGES "desktop utilities"
            install_slack_packages APPLICATIONS_PACKAGES "applications"
            local -a basic_dev=("python3" "git" "make")
            install_slack_packages basic_dev "basic development"
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

# ── Docker setup (Slackware-specific) ──────────────────────────────────────
setup_docker_slackware() {
    if ! hb_component_enabled dev; then
        log_info "Skipping setup_docker_slackware (dev component disabled)"
        return 0
    fi

    hb_next_step "Setting up Docker for Slackware..."
    if ! command -v docker >/dev/null 2>&1; then
        log_info "Docker not found; attempting sbopkg install..."
        if command -v sbopkg >/dev/null 2>&1; then
            hb_sudo sbopkg -i docker -B 2>/dev/null || {
                log_warning "Docker installation via sbopkg failed"
                return 0
            }
        else
            log_warning "Docker not available and sbopkg not installed"
            return 0
        fi
    fi
    # Start docker daemon
    if [[ -x /etc/rc.d/rc.docker ]]; then
        hb_sudo chmod +x /etc/rc.d/rc.docker
        hb_sudo /etc/rc.d/rc.docker start 2>/dev/null || true
    fi
    setup_development_environment
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    echo "Ratel Forge - Slackware Installation Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    hb_json_init
    hb_rollback_init
    export HONEY_BADGER_DISTRO="slackware"
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    if hb_skip_active; then
        # Skips and component filters change the step count; show [n] instead
        # of a fraction that would not add up.
        hb_set_total_steps 0
    else
        case "$install_type" in
            full)      hb_set_total_steps 21 ;;
            developer) hb_set_total_steps 20 ;;
            desktop)   hb_set_total_steps 16 ;;
            minimal)   hb_set_total_steps 7 ;;
        esac
    fi
    hb_phases_init "$install_type"
    show_banner
    check_slackware_system
    hb_phase slackpkg setup_slackpkg
    hb_phase sbopkg setup_sbopkg
    hb_phase update update_system
    hb_phase packages install_packages_by_type
    hb_phase nano setup_nano
    hb_phase utilities create_utility_scripts \
        "sudo slackpkg update && sudo slackpkg upgrade-all" \
        "sudo slackpkg install" \
        "echo 'Manual cleanup recommended on Slackware'"
    if [[ "$install_type" != "minimal" ]]; then
        if ! hb_skip_component "theme"; then
            hb_phase theme setup_honey_badger_theme
            hb_phase assets install_assets
        fi
    fi
    if [[ "$install_type" == "full" || "$install_type" == "developer" ]]; then
        hb_phase dev setup_docker_slackware
    fi
    show_post_install
}

main "$@"
