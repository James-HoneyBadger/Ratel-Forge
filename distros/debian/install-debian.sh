#!/bin/bash
# Ratel Forge - Debian/Ubuntu Post-Install Script
# Supports: Debian, Ubuntu, Linux Mint, Pop!_OS, Elementary, Zorin

set -euo pipefail

# Source shared library
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/common.sh"

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
    hb_sudo apt upgrade -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold
    hb_sudo apt install -y software-properties-common apt-transport-https ca-certificates gnupg lsb-release
    hb_outcome "Would update system packages" "System updated successfully"
}

# ── Repository setup (secured) ──────────────────────────────────────────────
# Print every apt source file that already mentions <url substring>.
# Both the deb822 *.sources form and the legacy *.list form have to be checked.
_hb_apt_source_files() {
    local url="$1" apt_dir="${2:-/etc/apt}" file
    for file in "$apt_dir/sources.list" "$apt_dir"/sources.list.d/*.list "$apt_dir"/sources.list.d/*.sources; do
        [[ -f "$file" ]] || continue
        grep -qF "$url" "$file" 2>/dev/null || continue
        printf '%s\n' "$file"
    done
}

_hb_vscode_source_files() {
    _hb_apt_source_files 'packages.microsoft.com/repos/code' "${1:-/etc/apt}"
}

# Configure the VS Code apt repository exactly once. apt refuses to merge two
# definitions of the same source that disagree on Signed-By ("Conflicting
# values set for option Signed-By"), which breaks every subsequent apt call.
# An existing definition is reused; the installer's own legacy vscode.list is
# the only file it will ever remove.
# shellcheck disable=SC2120  # callers and tests may pass a custom apt directory
_hb_add_vscode_repository() {
    local apt_dir="${1:-/etc/apt}"
    local -a existing_sources=()
    mapfile -t existing_sources < <(_hb_vscode_source_files "$apt_dir")

    if [[ ${#existing_sources[@]} -gt 0 ]]; then
        # Only the legacy file this installer writes may ever be removed.
        # Deleting anything else (sources.list, a hand-written entry) would
        # drop repositories the user depends on, so any other definition is
        # simply honoured as-is.
        local legacy="$apt_dir/sources.list.d/vscode.list"
        local -a keep=()
        local file preferred
        for file in "${existing_sources[@]}"; do
            [[ "$file" == "$legacy" ]] || keep+=("$file")
        done

        if [[ ${#keep[@]} -gt 0 && -f "$legacy" ]]; then
            hb_sudo rm -f "$legacy"
            log_info "Removed duplicate VS Code source definition: $legacy"
            hb_json_add_config "removed-source:$legacy"
        fi

        # Prefer the deb822 format maintained by VS Code when reporting.
        preferred="${keep[0]:-$legacy}"
        for file in "${keep[@]}"; do
            [[ "$file" == *.sources ]] && preferred="$file"
        done
        log_info "VS Code repository already configured: $preferred"
        return 0
    fi

    log_info "Adding VS Code repository..."
    local gpg_tmp
    gpg_tmp="$(mktemp)"
    hb_register_temp "$gpg_tmp"
    if hb_download "https://packages.microsoft.com/keys/microsoft.asc" "$gpg_tmp" \
        "${HONEY_BADGER_VSCODE_KEY_SHA256:-}"; then
        if [[ -s "$gpg_tmp" ]]; then
            gpg --batch --yes --dearmor <"$gpg_tmp" \
                | hb_sudo tee "$apt_dir/trusted.gpg.d/packages.microsoft.gpg" >/dev/null
            # apt reads keyrings as the unprivileged _apt user, so a restrictive
            # umask must not leave the key unreadable.
            hb_sudo chmod 0644 "$apt_dir/trusted.gpg.d/packages.microsoft.gpg"
            printf 'deb [arch=amd64,arm64,armhf signed-by=%s/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main\n' "$apt_dir" \
                | hb_sudo tee "$apt_dir/sources.list.d/vscode.list" >/dev/null
        fi
    else
        log_warning "Failed to download the VS Code signing key"
        hb_json_add_error "VS Code key download failed"
    fi
    rm -f "$gpg_tmp"
}

# Install NodeSource's apt repository without executing their setup script.
# The major version is pinned (HONEY_BADGER_NODE_MAJOR) so the source URL is
# reproducible; the keyring is verified when a digest is supplied.
# shellcheck disable=SC2120  # callers and tests may pass a custom apt directory
_hb_add_nodesource_repository() {
    local apt_dir="${1:-/etc/apt}"
    local major="${HONEY_BADGER_NODE_MAJOR:-24}"
    [[ "$major" =~ ^[0-9]+$ ]] || major=24

    local -a existing=()
    mapfile -t existing < <(_hb_apt_source_files 'deb.nodesource.com' "$apt_dir")
    if [[ ${#existing[@]} -gt 0 ]]; then
        log_info "Node.js repository already configured: ${existing[0]}"
        return 0
    fi

    log_info "Adding Node.js repository..."
    local key_tmp keyring="/usr/share/keyrings/nodesource.gpg"
    key_tmp="$(mktemp)"
    hb_register_temp "$key_tmp"
    if ! hb_download "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key" \
        "$key_tmp" "${HONEY_BADGER_NODE_KEY_SHA256:-}"; then
        log_warning "Failed to download the NodeSource signing key"
        hb_json_add_error "NodeSource key download failed"
        rm -f "$key_tmp"
        return 0
    fi
    gpg --batch --yes --dearmor <"$key_tmp" | hb_sudo tee "$keyring" >/dev/null
    hb_sudo chmod 0644 "$keyring"
    printf 'deb [signed-by=%s] https://deb.nodesource.com/node_%s.x nodistro main\n' \
        "$keyring" "$major" \
        | hb_sudo tee "$apt_dir/sources.list.d/nodesource.list" >/dev/null
    rm -f "$key_tmp"
    hb_outcome "Would add the Node.js repository" "Node.js repository added"
}

add_repositories() {
    hb_next_step "Adding additional repositories..."

    # Repository setup fetches keys and rewrites apt sources; skip the
    # whole step in dry-run so the preview stays compact.
    if hb_dry_run; then
        log_info "[DRY-RUN] Would add the Node.js, GitHub CLI, and VS Code repositories"
        return 0
    fi

    # Add universe repository for Ubuntu
    if command -v add-apt-repository >/dev/null 2>&1; then
        if lsb_release -i 2>/dev/null | grep -q Ubuntu; then
            hb_sudo add-apt-repository universe -y
            log_info "Added Ubuntu universe repository"
        fi
    fi

    # Node.js: configure NodeSource's apt repository directly. Running their
    # setup script as root would execute unverified remote code, so the signing
    # key and the source entry are installed like every other repository.
    local node_major=""
    if command -v nodejs >/dev/null 2>&1; then
        node_major="$(nodejs --version 2>/dev/null | sed -n 's/^v\([0-9][0-9]*\).*/\1/p')"
        [[ "$node_major" =~ ^[0-9]+$ ]] || node_major=0
    fi
    if [[ -z "$node_major" ]] || (( node_major < 20 )); then
        _hb_add_nodesource_repository
    fi

    # Docker: install the distribution's packages (docker.io/docker-compose).
    # Using Docker's own repository here previously conflicted with docker.io
    # and broke on derivatives whose codename is not an Ubuntu codename
    # (Mint, Elementary, Zorin, Kali).
    # GitHub CLI repository
    log_info "Adding GitHub CLI repository..."
    local gh_key_tmp
    gh_key_tmp="$(mktemp)"
    hb_register_temp "$gh_key_tmp"
    if hb_download "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
        "$gh_key_tmp" "${HONEY_BADGER_GITHUB_CLI_KEY_SHA256:-}"; then
        if [[ -s "$gh_key_tmp" ]]; then
            # apt reads keyrings as the unprivileged _apt user, so the download
            # must not keep mktemp's 0600 mode.
            hb_sudo install -m 0644 "$gh_key_tmp" /usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null || {
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
        _hb_add_vscode_repository
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
        if hb_sudo apt install -y \
            -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
            "${available_packages[@]}"; then
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
        if flatpak list 2>/dev/null | grep -qF "$package"; then
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
    install_apt_packages CLI_TOOLS_PACKAGES "base tools"
    case "$install_type" in
        "full")
            install_apt_packages DEVELOPER_PACKAGES "developer"
            install_apt_packages APPLICATIONS_PACKAGES "applications"
            install_snap_packages SNAP_PACKAGES "Snap"
            install_flatpak_packages FLATPAK_PACKAGES "Flatpak"
            ;;
        "developer")
            install_apt_packages DEVELOPER_PACKAGES "developer"
            local -a dev_snaps=("postman")
            install_snap_packages dev_snaps "development Snap"
            ;;
        "apps")
            install_apt_packages APPLICATIONS_PACKAGES "applications"
            install_snap_packages SNAP_PACKAGES "Snap"
            install_flatpak_packages FLATPAK_PACKAGES "Flatpak"
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
    hb_init_distro_log "debian"

    # Data lives in config/packages/debian.conf so package changes are reviewable
    # without touching shell logic. Loaded into BASE_PACKAGES, DEVELOPER_PACKAGES, …
    hb_load_package_manifest "$HONEY_BADGER_ROOT/config/packages/debian.conf"

    if is_noninteractive; then
        # Never stop for a debconf or config-file question in unattended runs.
        export DEBIAN_FRONTEND=noninteractive
        export APT_LISTCHANGES_FRONTEND=none
    fi

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
            full)      hb_set_total_steps 14 ;;
            developer) hb_set_total_steps 12 ;;
            apps)      hb_set_total_steps 10 ;;
            minimal)   hb_set_total_steps 7 ;;
        esac
    fi
    hb_phases_init "$install_type"
    show_banner
    check_debian_system
    hb_phase update update_system
    hb_phase packages install_packages_by_type
    hb_phase nano setup_nano
    hb_phase shell setup_shell
    hb_phase utilities create_utility_scripts \
        "sudo apt update && sudo apt upgrade -y" \
        "sudo apt install -y" \
        "sudo apt autoremove -y && sudo apt autoclean" \
        "apt-cache search" \
        "sudo apt purge -y" \
        "apt list --upgradable 2>/dev/null"
    if [[ "$install_type" == "full" || "$install_type" == "developer" ]]; then
        hb_phase dev setup_development_environment
    fi
    show_post_install
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
