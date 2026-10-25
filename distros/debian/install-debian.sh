#!/bin/bash
# Ratel Forge - Debian/Ubuntu Post-Install Script
# Supports: Debian, Ubuntu, Linux Mint, Pop!_OS, Elementary, Zorin

set -euo pipefail

# Source shared library
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/common.sh"

hb_init_distro_log "debian"

# ── Package lists ────────────────────────────────────────────────────────────
# Data lives in config/packages/debian.conf so package changes are reviewable
# without touching shell logic. Loaded into BASE_PACKAGES, DEVELOPER_PACKAGES, …
hb_load_package_manifest "$HONEY_BADGER_ROOT/config/packages/debian.conf"

# ── Banner ───────────────────────────────────────────────────────────────────
show_banner() {
    hb_show_banner "Debian/Ubuntu" "Debian-based provisioning"
}

# ── System check ─────────────────────────────────────────────────────────────
check_debian_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        log_info "Detected: ${PRETTY_NAME:-Debian}"
    fi
}

# ── System update ────────────────────────────────────────────────────────────
update_system() {
    hb_next_step "Updating system packages..."
    hb_sudo apt update
    hb_sudo apt upgrade -y
    hb_sudo apt install -y software-properties-common apt-transport-https ca-certificates gnupg lsb-release
    hb_outcome "Would update system packages" "System updated successfully"
}

# ── Repository setup (secured) ──────────────────────────────────────────────
add_repositories() {
    hb_next_step "Adding additional repositories..."

    # Add universe repository for Ubuntu
    if command -v add-apt-repository >/dev/null 2>&1; then
        if lsb_release -i 2>/dev/null | grep -q Ubuntu; then
            hb_sudo add-apt-repository universe -y
            log_info "Added Ubuntu universe repository"
        fi
    fi

    # Node.js: download setup script to temp file first (no pipe to bash)
    if ! command -v nodejs >/dev/null 2>&1 || [[ $(nodejs --version 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1) -lt 16 ]]; then
        log_info "Adding Node.js repository..."
        local node_setup
        node_setup="$(mktemp)"
        hb_register_temp "$node_setup"
        if hb_download "https://deb.nodesource.com/setup_lts.x" "$node_setup" \
            "${HONEY_BADGER_NODE_SETUP_SHA256:-}"; then
            if [[ -s "$node_setup" ]]; then
                if head -n1 "$node_setup" | grep -q '^#!.*bash'; then
                    hb_sudo bash "$node_setup"
                    hb_outcome "Would add the Node.js repository" "Node.js repository added"
                else
                    log_warning "Node.js setup script failed validation (not a shell script)"
                    hb_json_add_error "Node.js setup script validation failed"
                fi
            else
                log_info "[DRY-RUN] Would run the Node.js setup script"
            fi
            rm -f "$node_setup"
        else
            rm -f "$node_setup"
            log_warning "Failed to download Node.js setup script"
            hb_json_add_error "Node.js repository setup failed"
        fi
    fi

    # Docker repository - detect correct distro (not hardcoded to ubuntu)
    log_info "Adding Docker repository..."
    local distro_id
    distro_id="$(lsb_release -is 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    # Map derivatives to their upstream for Docker repos
    case "$distro_id" in
        linuxmint|pop|elementary|zorin|kali) distro_id="ubuntu" ;;
        "") distro_id="debian" ;;
    esac
    local docker_codename
    docker_codename="$(lsb_release -cs 2>/dev/null)"
    local docker_key_tmp
    docker_key_tmp="$(mktemp)"
    hb_register_temp "$docker_key_tmp"
    if hb_download "https://download.docker.com/linux/${distro_id}/gpg" "$docker_key_tmp" \
        "${HONEY_BADGER_DOCKER_GPG_SHA256:-}"; then
        if [[ -s "$docker_key_tmp" ]]; then
            hb_sudo gpg --batch --yes --dearmor \
                -o /usr/share/keyrings/docker-archive-keyring.gpg \
                <"$docker_key_tmp" 2>/dev/null || {
                log_warning "Failed to dearmor the Docker GPG key"
                hb_json_add_error "Docker GPG key import failed"
            }
        fi
    else
        log_warning "Failed to download Docker GPG key for ${distro_id}"
        hb_json_add_error "Docker GPG key download failed"
    fi
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${distro_id} ${docker_codename} stable" | hb_sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # GitHub CLI repository
    log_info "Adding GitHub CLI repository..."
    local gh_key_tmp
    gh_key_tmp="$(mktemp)"
    hb_register_temp "$gh_key_tmp"
    if hb_download "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
        "$gh_key_tmp" "${HONEY_BADGER_GITHUB_CLI_KEY_SHA256:-}"; then
        if [[ -s "$gh_key_tmp" ]]; then
            hb_sudo cp "$gh_key_tmp" /usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null || {
                log_warning "Failed to install the GitHub CLI keyring"
                hb_json_add_error "GitHub CLI keyring install failed"
            }
        fi
    else
        log_warning "Failed to download GitHub CLI GPG key"
        hb_json_add_error "GitHub CLI GPG key download failed"
    fi
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | hb_sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

    # VS Code repository (if not using Snap)
    if ! snap list code >/dev/null 2>&1; then
        log_info "Adding VS Code repository..."
        local gpg_tmp
        gpg_tmp="$(mktemp)"
        hb_register_temp "$gpg_tmp"
        if hb_download "https://packages.microsoft.com/keys/microsoft.asc" "$gpg_tmp" \
            "${HONEY_BADGER_VSCODE_KEY_SHA256:-}"; then
            if [[ -s "$gpg_tmp" ]]; then
                gpg --batch --yes --dearmor <"$gpg_tmp" \
                    | hb_sudo tee /etc/apt/trusted.gpg.d/packages.microsoft.gpg >/dev/null
                hb_sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
            fi
        else
            log_warning "Failed to download the VS Code signing key"
            hb_json_add_error "VS Code key download failed"
        fi
        rm -f "$gpg_tmp"
    fi

    hb_sudo apt update
    hb_outcome "Would add additional repositories" "Additional repositories added"
}

# ── Package installation ────────────────────────────────────────────────────
install_apt_packages() {
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
        if dpkg -l "$package" 2>/dev/null | grep -q "^ii"; then
            log_info "$package already installed"
        elif apt-cache show "$package" >/dev/null 2>&1; then
            available_packages+=("$package")
        else
            log_warning "$package not available in repositories"
        fi
    done
    if [[ ${#available_packages[@]} -gt 0 ]]; then
        if hb_sudo apt install -y "${available_packages[@]}"; then
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

install_snap_packages() {
    local -n packages_ref=$1
    local package_type="$2"
    if ! hb_component_allowed "$package_type"; then
        log_info "Skipping $package_type (component disabled by --components)"
        return 0
    fi
    if ! command -v snap >/dev/null 2>&1; then
        log_info "Installing snapd..."
        hb_sudo apt install -y snapd
        hb_sudo systemctl enable --now snapd.socket 2>/dev/null || true
    fi
    if [[ ${#packages_ref[@]} -eq 0 ]]; then return 0; fi
    hb_next_step "Installing $package_type Snap packages..."
    for entry in "${packages_ref[@]}"; do
        local package_name flags_str
        local -a flags=()
        package_name="${entry%% *}"
        flags_str="${entry#"$package_name"}"
        [[ -n "$flags_str" ]] && read -r -a flags <<< "$flags_str"

        if snap list "$package_name" >/dev/null 2>&1; then
            log_info "$package_name already installed"
            continue
        fi
        if hb_sudo snap install "$package_name" ${flags[@]+"${flags[@]}"} 2>/dev/null; then
            hb_json_add_package "snap:$package_name"
        else
            log_warning "Failed to install snap $package_name"
        fi
    done
}

install_flatpak_packages() {
    local -n packages_ref=$1
    local package_type="$2"
    if ! hb_component_allowed "$package_type"; then
        log_info "Skipping $package_type (component disabled by --components)"
        return 0
    fi
    if ! command -v flatpak >/dev/null 2>&1; then
        log_info "Installing Flatpak..."
        hb_sudo apt install -y flatpak
        hb_sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    if [[ ${#packages_ref[@]} -eq 0 ]]; then return 0; fi
    hb_next_step "Installing $package_type Flatpak packages..."
    for package in "${packages_ref[@]}"; do
        if flatpak list 2>/dev/null | grep -q "$package"; then
            log_info "$package already installed"
            continue
        fi
        if hb_sudo flatpak install -y flathub "$package" 2>/dev/null; then
            hb_json_add_package "flatpak:$package"
        else
            log_warning "Failed to install $package"
        fi
    done
}

# ── Main installation by type ───────────────────────────────────────────────
install_packages_by_type() {
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    log_info "Installation type: $install_type"
    add_repositories
    install_apt_packages BASE_PACKAGES "base"
    case "$install_type" in
        "full")
            install_apt_packages DEVELOPER_PACKAGES "developer"
            install_apt_packages DESKTOP_PACKAGES "desktop"
            install_apt_packages APPLICATIONS_PACKAGES "applications"
            install_snap_packages SNAP_PACKAGES "Snap"
            install_flatpak_packages FLATPAK_PACKAGES "Flatpak"
            setup_xfce
            ;;
        "developer")
            install_apt_packages DEVELOPER_PACKAGES "developer"
            install_apt_packages DESKTOP_PACKAGES "basic desktop"
            local -a dev_snaps=("code --classic" "postman")
            install_snap_packages dev_snaps "development Snap"
            setup_xfce
            ;;
        "desktop")
            install_apt_packages DESKTOP_PACKAGES "desktop"
            install_apt_packages APPLICATIONS_PACKAGES "applications"
            local -a basic_dev=("python3" "python3-pip" "nodejs" "npm" "git")
            install_apt_packages basic_dev "basic development"
            setup_xfce
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

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo "Ratel Forge - Debian/Ubuntu Installation Log" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    hb_json_init
    hb_rollback_init
    export HONEY_BADGER_DISTRO="debian"
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    if hb_skip_active; then
        # Skips and component filters change the step count; show [n] instead
        # of a fraction that would not add up.
        hb_set_total_steps 0
    else
        case "$install_type" in
            full)      hb_set_total_steps 16 ;;
            developer) hb_set_total_steps 14 ;;
            desktop)   hb_set_total_steps 11 ;;
            minimal)   hb_set_total_steps 5 ;;
        esac
    fi
    hb_phases_init "$install_type"
    show_banner
    check_debian_system
    hb_phase update update_system
    hb_phase packages install_packages_by_type
    hb_phase nano setup_nano
    hb_phase utilities create_utility_scripts \
        "sudo apt update && sudo apt upgrade -y" \
        "sudo apt install -y" \
        "sudo apt autoremove -y && sudo apt autoclean"
    if [[ "$install_type" != "minimal" ]]; then
        if ! hb_skip_component "theme"; then
            hb_phase theme setup_honey_badger_theme
            hb_phase assets install_assets
        fi
    fi
    if [[ "$install_type" == "full" || "$install_type" == "developer" ]]; then
        hb_phase dev setup_development_environment
    fi
    show_post_install
}

main "$@"
