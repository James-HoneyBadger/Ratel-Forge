#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Ratel Forge — fearless Linux provisioning
#
# Universal entry point: detects the distribution, resolves the requested
# install type, runs pre-flight checks, then hands off to the matching distro
# provisioner. Honey Badger OS identifiers are retained for compatibility.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

readonly HB_PROG="${0##*/}"

# ── Install type catalogue (single source of truth) ──────────────────────────
hb_type_label() {
    case "$1" in
        full)      printf 'Full' ;;
        developer) printf 'Developer' ;;
        desktop)   printf 'Desktop' ;;
        minimal)   printf 'Minimal' ;;
        *)         printf '%s' "$1" ;;
    esac
}

hb_type_size() {
    case "$1" in
        full)      printf '6-9 GB' ;;
        developer) printf '2-4 GB' ;;
        desktop)   printf '3-5 GB' ;;
        minimal)   printf '0.3-0.8 GB' ;;
    esac
}

hb_type_blurb() {
    case "$1" in
        full)      printf 'Everything: desktop, toolchain, office, media' ;;
        developer) printf 'Toolchain, containers, editors, XFCE desktop' ;;
        desktop)   printf 'XFCE, browsers, office, media, basic dev tools' ;;
        minimal)   printf 'CLI tools only, no desktop or GUI apps' ;;
    esac
}

hb_type_bullets() {
    case "$1" in
        full)
            printf '    • Complete XFCE desktop with networking, audio, and fonts\n'
            printf '    • Full development stack (Python, Node.js, Go, Rust, Java, Ruby)\n'
            printf '    • Containers, editors, and database clients\n'
            printf '    • Productivity suite (LibreOffice, GIMP, VLC, Firefox)\n'
            printf '    • Ratel theme, wallpaper, and LightDM greeter\n'
            ;;
        developer)
            printf '    • Languages, build tools, containers, and editors\n'
            printf '    • XFCE desktop with networking, audio, and fonts\n'
            printf '    • No office suite or media applications\n'
            printf '    • Ratel theme, wallpaper, and LightDM greeter\n'
            ;;
        desktop)
            printf '    • Complete XFCE desktop with networking, audio, and fonts\n'
            printf '    • Browsers, office, and media applications\n'
            printf '    • Basic development tools\n'
            printf '    • Ratel theme, wallpaper, and LightDM greeter\n'
            ;;
        minimal)
            printf '    • CLI tools, monitoring, nano, and Ratel Forge commands\n'
            printf '    • No desktop, audio stack, fonts, or GUI applications\n'
            printf '    • Suitable for servers, containers, and remote hosts\n'
            ;;
    esac
}

print_install_types() {
    printf 'Install types\n\n'
    local number=1 type
    for type in full developer desktop minimal; do
        printf '  %s  %-10s %-12s %s\n' \
            "$number" "$(hb_type_label "$type")" "$(hb_type_size "$type")" "$(hb_type_blurb "$type")"
        number=$((number + 1))
    done
    printf '\nSelect with --type <name>.\n'
}

# ── Help ─────────────────────────────────────────────────────────────────────
show_help() {
    cat <<'ENDHELP'
Ratel Forge — fearless Linux provisioning

Usage
  install.sh [options]

Install types
  full         Complete XFCE desktop, full development stack, applications
  developer    Languages, containers, editors, and an XFCE core desktop
  desktop      XFCE desktop with productivity applications
  minimal      Command-line essentials, no desktop environment

Options
  -h, --help                 Show this help and exit
  -V, --version              Show version information and exit
  -t, --type TYPE            Install type: full, developer, desktop, minimal
      --list-types           Print the install types and exit
  -n, --dry-run              Simulate the install without changing anything
  -y, --yes                  Assume yes for the confirmation prompt
      --non-interactive      Never prompt (requires --type or the env var)
      --check                Run pre-flight checks only, then exit
      --resume               Resume a previous run, skipping completed phases
      --no-banner            Omit the banner
      --ascii                Use ASCII instead of Unicode glyphs
      --high-contrast        Use the high-contrast theme variant (desktop only)
      --font-size PX         Desktop font size, 8-24 (default: 10, desktop only)
      --no-color             Disable coloured output
  -v, --verbose              Show debug output
  -q, --quiet                Errors only

Component options
      --skip-docker          Skip Docker installation and group setup
      --skip-python          Skip Python development setup
      --skip-node            Skip Node.js development setup
      --skip-nano            Skip nano configuration
      --skip-theme           Skip theme and wallpaper installation
      --skip-git             Skip Git identity configuration

Group selection
      --components LIST      Comma-separated package groups to install:
                             base, dev, desktop, apps (default: all for the type)
                             base is always installed; Minimal installs base only

Environment
  HONEY_BADGER_INSTALL_TYPE=full|developer|desktop|minimal
  HONEY_BADGER_DRY_RUN=1, HONEY_BADGER_NONINTERACTIVE=1
  HONEY_BADGER_ASSUME_YES=1
  HONEY_BADGER_GIT_USERNAME, HONEY_BADGER_GIT_EMAIL
  HONEY_BADGER_LOG_COUNT=5, HONEY_BADGER_NETWORK_TIMEOUT=3
  HONEY_BADGER_WALLPAPER_SIZE=1920x1080
  HONEY_BADGER_NPM_GLOBAL_PATH=~/.npm-global
  NO_COLOR=1                 Disable colours (https://no-color.org)

Supported distributions
  Arch       Arch, Manjaro, EndeavourOS, ArcoLinux, Artix
  Debian     Debian, Ubuntu, Mint, Pop!_OS, Elementary, Zorin, Kali
  Fedora     Fedora, RHEL, CentOS, AlmaLinux, Rocky Linux
  Gentoo     Gentoo, Funtoo
  openSUSE   Tumbleweed, Leap, SLES, GeckoLinux
  Void       Void Linux (glibc and musl)
  Slackware  Slackware, Salix

Examples
  ./install.sh                              Interactive install
  ./install.sh --type full --dry-run        Preview a full install
  ./install.sh --type minimal --yes         Unattended minimal install
  ./install.sh --check                      Check the environment only
  ./install.sh --skip-docker --skip-node    Without Docker and Node.js

Documentation  https://github.com/James-HoneyBadger/Ratel-Forge
ENDHELP
    exit 0
}

# ── Version ──────────────────────────────────────────────────────────────────
show_version() {
    local version="" codename=""
    local conf="$HONEY_BADGER_ROOT/config/honey-badger-os.conf"

    # Read defaults without sourcing the file (it must stay unexecuted until
    # the shared library has validated it).
    if [[ -r "$conf" ]]; then
        version="$(sed -n 's/^HONEY_BADGER_VERSION=.*:-*\([^}]*\)}.*$/\1/p' "$conf" | head -n1)"
        codename="$(sed -n 's/^HONEY_BADGER_CODENAME=.*:-*\([^}]*\)}.*$/\1/p' "$conf" | head -n1)"
    fi

    version="${HONEY_BADGER_VERSION:-${version:-2.5.0}}"
    codename="${HONEY_BADGER_CODENAME:-${codename:-Fearless}}"

    printf 'Ratel Forge %s%s\n' "$version" "${codename:+ \"$codename\"}"
    printf 'Fearless Linux provisioning · MIT licensed\n'
    exit 0
}

# ── Argument parsing ─────────────────────────────────────────────────────────
# Parsed before sourcing lib/common.sh so that --help and --version have no
# side effects (no log directory, no lock file, no temp files).
HONEY_BADGER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export HONEY_BADGER_ROOT

CHECK_ONLY=0
_HB_FONT_SIZE_SET=0

_unknown_option() {
    printf '%s: unknown option: %s\n' "$HB_PROG" "$1" >&2
    printf 'Try %s --help for the full list of options.\n' "$HB_PROG" >&2
    exit 2
}

_require_value() {
    if [[ $# -lt 2 || -z "${2:-}" ]]; then
        printf '%s: option %s requires a value\n' "$HB_PROG" "$1" >&2
        exit 2
    fi
}

_normalize_components() {
    local raw="${1,,}" item out=""
    local -a items
    IFS=',' read -r -a items <<< "$raw"
    for item in "${items[@]}"; do
        [[ -n "$item" ]] || continue
        case "$item" in
            base|dev|desktop|apps) out="${out:+$out,}$item" ;;
            *)
                printf '%s: invalid component: %s\n' "$HB_PROG" "$item" >&2
                printf 'Valid components: base, dev, desktop, apps\n' >&2
                return 1
                ;;
        esac
    done
    if [[ -z "$out" ]]; then
        printf '%s: --components requires at least one value\n' "$HB_PROG" >&2
        return 1
    fi
    # base is the floor of every profile; never silently drop it.
    case ",$out," in
        *,base,*) ;;
        *)
            printf '%s: note: base is always installed; adding it to the component list\n' "$HB_PROG" >&2
            out="base,$out"
            ;;
    esac
    # Canonical order keeps summaries and resumes stable.
    local ordered="" c
    for c in base dev desktop apps; do
        case ",$out," in
            *",$c,"*) ordered="${ordered:+$ordered,}$c" ;;
        esac
    done
    _HB_NORMALIZED_COMPONENTS="$ordered"
    return 0
}

_validate_font_size() {
    local size="$1"
    if [[ ! "$size" =~ ^[0-9]+$ ]] || (( size < 8 || size > 24 )); then
        printf '%s: invalid font size: %s (expected 8-24)\n' "$HB_PROG" "$size" >&2
        exit 2
    fi
}

_validate_type_value() {
    case "$1" in
        full|developer|desktop|minimal) return 0 ;;
        *)
            printf '%s: invalid install type: %s\n' "$HB_PROG" "$1" >&2
            printf 'Valid types: full, developer, desktop, minimal\n' >&2
            exit 2
            ;;
    esac
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)          show_help ;;
        -V|--version)       show_version ;;
        --list-types)       print_install_types; exit 0 ;;
        -t|--type|--install-type)
            _require_value "$@"
            _type_value="${2,,}"
            _validate_type_value "$_type_value"
            export HONEY_BADGER_INSTALL_TYPE="$_type_value"
            shift 2
            ;;
        --type=*|--install-type=*)
            _type_value="${1#*=}"
            _type_value="${_type_value,,}"
            _validate_type_value "$_type_value"
            export HONEY_BADGER_INSTALL_TYPE="$_type_value"
            shift
            ;;
        -n|--dry-run)       export HONEY_BADGER_DRY_RUN=1; shift ;;
        -y|--yes)           export HONEY_BADGER_ASSUME_YES=1; shift ;;
        --non-interactive)  export HONEY_BADGER_NONINTERACTIVE=1; shift ;;
        --check)            CHECK_ONLY=1; shift ;;
        --resume)           export HONEY_BADGER_RESUME=1; shift ;;
        --no-banner)        export HONEY_BADGER_NO_BANNER=1; shift ;;
        --ascii)            export HONEY_BADGER_ASCII=1; shift ;;
        --no-color)         export HONEY_BADGER_NO_COLOR=1; shift ;;
        --high-contrast)    export HONEY_BADGER_HIGH_CONTRAST=1; shift ;;
        --font-size)
            _require_value "$@"
            _validate_font_size "$2"
            export HONEY_BADGER_FONT="Noto Sans $2"
            export HONEY_BADGER_MONO_FONT="Noto Sans Mono $2"
            _HB_FONT_SIZE_SET=1
            shift 2
            ;;
        --font-size=*)
            _validate_font_size "${1#*=}"
            export HONEY_BADGER_FONT="Noto Sans ${1#*=}"
            export HONEY_BADGER_MONO_FONT="Noto Sans Mono ${1#*=}"
            _HB_FONT_SIZE_SET=1
            shift
            ;;
        -v|--verbose)       export HONEY_BADGER_VERBOSITY=2; shift ;;
        -q|--quiet)         export HONEY_BADGER_VERBOSITY=0; shift ;;
        --skip-docker)      export HONEY_BADGER_SKIP_DOCKER=1; shift ;;
        --skip-python)      export HONEY_BADGER_SKIP_PYTHON=1; shift ;;
        --skip-node)        export HONEY_BADGER_SKIP_NODE=1; shift ;;
        --skip-nano)        export HONEY_BADGER_SKIP_NANO=1; shift ;;
        --skip-theme|--no-theme) export HONEY_BADGER_SKIP_THEME=1; shift ;;
        --skip-git)         export HONEY_BADGER_SKIP_GIT=1; shift ;;
        --components)
            _require_value "$@"
            _normalize_components "$2" || exit 2
            export HONEY_BADGER_COMPONENTS="$_HB_NORMALIZED_COMPONENTS"
            shift 2
            ;;
        --components=*)
            _normalize_components "${1#*=}" || exit 2
            export HONEY_BADGER_COMPONENTS="$_HB_NORMALIZED_COMPONENTS"
            shift
            ;;
        --)                 shift; break ;;
        -*)                 _unknown_option "$1" ;;
        *)
            printf '%s: unexpected argument: %s\n' "$HB_PROG" "$1" >&2
            printf 'Try %s --help for usage.\n' "$HB_PROG" >&2
            exit 2
            ;;
    esac
done

# ── Shared library ──────────────────────────────────────────────────────────
if [[ ! -f "$HONEY_BADGER_ROOT/lib/common.sh" ]]; then
    printf '%s: fatal: lib/common.sh not found next to %s\n' "$HB_PROG" "$HB_PROG" >&2
    printf 'Re-clone the repository; the checkout is incomplete.\n' >&2
    exit 1
fi

# shellcheck source=lib/common.sh
source "$HONEY_BADGER_ROOT/lib/common.sh"

# ── Banner ──────────────────────────────────────────────────────────────────
show_banner() {
    [[ "${HONEY_BADGER_NO_BANNER:-0}" == "1" ]] && return 0
    hb_show_banner "" "Fearless Linux provisioning"
}

# ── Environment checks ──────────────────────────────────────────────────────
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this installer as root."
        log_info "Run it as your normal user; it will request sudo when needed."
        exit 1
    fi
}

check_sudo() {
    if [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]]; then
        log_info "[DRY-RUN] Skipping sudo credential check"
        return 0
    fi
    if sudo -n true 2>/dev/null; then
        log_success "Sudo privileges confirmed"
        return 0
    fi
    log_info "Requesting sudo privileges…"
    if ! sudo true; then
        log_error "This installer requires sudo privileges."
        log_info "Ensure your user is in the sudo (or wheel) group."
        exit 1
    fi
    log_success "Sudo privileges confirmed"
}

check_architecture() {
    case "$(uname -m)" in
        x86_64|amd64)  log_info "Architecture: x86_64" ;;
        aarch64|arm64) log_info "Architecture: aarch64" ;;
        *)
            log_warning "Architecture '$(uname -m)' is not officially supported"
            log_info "Continuing with a best-effort installation"
            ;;
    esac
}

# ── Distribution detection ──────────────────────────────────────────────────
# Sets HB_DISTRO_FAMILY and HB_DISTRO_LABEL. Emits nothing on stdout so callers
# can never accidentally capture diagnostic lines along with the result.
detect_distribution() {
    local distro="" id_like=""
    HB_DISTRO_FAMILY=""
    HB_DISTRO_LABEL=""

    if [[ -r /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        distro="${ID:-}"
        id_like="${ID_LIKE:-}"
        HB_DISTRO_LABEL="${PRETTY_NAME:-${NAME:-$distro}}"
    fi

    case "$distro" in
        arch|manjaro|endeavouros|arcolinux|artix)  HB_DISTRO_FAMILY="arch" ;;
        debian|ubuntu|linuxmint|pop|elementary|zorin|kali) HB_DISTRO_FAMILY="debian" ;;
        fedora|rhel|centos|almalinux|rocky)         HB_DISTRO_FAMILY="fedora" ;;
        slackware|salix)                            HB_DISTRO_FAMILY="slackware" ;;
        void)                                       HB_DISTRO_FAMILY="void" ;;
        opensuse*|sles|sled)                        HB_DISTRO_FAMILY="opensuse" ;;
        gentoo|funtoo)                              HB_DISTRO_FAMILY="gentoo" ;;
    esac

    if [[ -z "$HB_DISTRO_FAMILY" && -n "$id_like" ]]; then
        case "$id_like" in
            *arch*)              HB_DISTRO_FAMILY="arch" ;;
            *debian*|*ubuntu*)   HB_DISTRO_FAMILY="debian" ;;
            *rhel*|*fedora*)     HB_DISTRO_FAMILY="fedora" ;;
            *suse*)              HB_DISTRO_FAMILY="opensuse" ;;
        esac
    fi

    if [[ -z "$HB_DISTRO_FAMILY" ]]; then
        if   command -v pacman >/dev/null 2>&1;   then HB_DISTRO_FAMILY="arch"
        elif command -v apt-get >/dev/null 2>&1;  then HB_DISTRO_FAMILY="debian"
        elif command -v dnf >/dev/null 2>&1;      then HB_DISTRO_FAMILY="fedora"
        elif command -v zypper >/dev/null 2>&1;   then HB_DISTRO_FAMILY="opensuse"
        elif command -v xbps-install >/dev/null 2>&1; then HB_DISTRO_FAMILY="void"
        elif command -v slackpkg >/dev/null 2>&1; then HB_DISTRO_FAMILY="slackware"
        elif command -v emerge >/dev/null 2>&1;   then HB_DISTRO_FAMILY="gentoo"
        fi
    fi

    if [[ -z "$HB_DISTRO_FAMILY" ]]; then
        if   [[ -f /etc/arch-release ]];      then HB_DISTRO_FAMILY="arch"
        elif [[ -f /etc/debian_version ]];    then HB_DISTRO_FAMILY="debian"
        elif [[ -f /etc/redhat-release ]];    then HB_DISTRO_FAMILY="fedora"
        elif [[ -f /etc/slackware-version ]]; then HB_DISTRO_FAMILY="slackware"
        elif [[ -f /etc/void-release ]];      then HB_DISTRO_FAMILY="void"
        elif [[ -f /etc/SuSE-release || -f /etc/SUSE-brand ]]; then HB_DISTRO_FAMILY="opensuse"
        elif [[ -f /etc/gentoo-release ]];    then HB_DISTRO_FAMILY="gentoo"
        fi
    fi

    [[ -n "$HB_DISTRO_FAMILY" ]] || return 1
    [[ -n "$HB_DISTRO_LABEL" ]] || HB_DISTRO_LABEL="$HB_DISTRO_FAMILY"
    return 0
}

# ── Pre-flight checks ───────────────────────────────────────────────────────
_HB_AVAILABLE_GB=0
_HB_REQUIRED_GB=0

run_preflight_checks() {
    hb_section "Pre-flight checks"

    log_info "Checking network connectivity…"
    if ! hb_check_network; then
        log_error "No network connectivity detected."
        log_info "Connect to a network and try again."
        exit 1
    fi
    log_success "Network reachable"

    # Disk space requirement depends on the install type (when already known).
    local required_gb="${HONEY_BADGER_MIN_DISK_GB:-}"
    if [[ -z "$required_gb" ]]; then
        case "${HONEY_BADGER_INSTALL_TYPE:-}" in
            full)      required_gb=9 ;;
            developer) required_gb=4 ;;
            desktop)   required_gb=5 ;;
            minimal)   required_gb=1 ;;
            *)         required_gb=1 ;;
        esac
    fi
    _HB_REQUIRED_GB="$required_gb"

    local available_kb
    available_kb=$(df -Pk / | awk 'NR==2 {print $4}')
    if [[ ! "$available_kb" =~ ^[0-9]+$ ]]; then
        log_warning "Could not determine free disk space; skipping the disk check"
        _HB_AVAILABLE_GB="unknown"
    else
        _HB_AVAILABLE_GB=$((available_kb / 1024 / 1024))
        if [[ $_HB_AVAILABLE_GB -lt $required_gb ]]; then
            log_error "Insufficient disk space: ${_HB_AVAILABLE_GB} GB free, ${required_gb} GB required."
            log_info "Free up space or choose a smaller install type."
            exit 1
        fi
        log_success "Disk space OK (${_HB_AVAILABLE_GB} GB free; ${required_gb} GB required for ${HONEY_BADGER_INSTALL_TYPE:-the baseline})"
    fi

    if [[ ! -d "$HONEY_BADGER_ROOT/distros" ]]; then
        log_error "Required 'distros' directory is missing."
        log_info "The checkout is incomplete; re-clone the repository."
        exit 1
    fi
    log_success "Repository layout OK"

    if [[ "${HONEY_BADGER_DRY_RUN:-0}" != "1" ]] && ! command -v git >/dev/null 2>&1; then
        log_warning "git is not installed; it will be installed as part of the base packages"
    fi
}

# ── Install type selection ──────────────────────────────────────────────────
show_installation_types() {
    hb_section "Choose an installation type"

    printf '  %b1  Full%b  %b· %s%b\n' "$HB_ACCENT" "$NC" "$HB_MUTED" "$(hb_type_size full)" "$NC"
    printf '     Everything: XFCE desktop, full development toolchain, browsers,\n'
    printf '     office and media apps, containers, theme, and utilities.\n'
    printf '     %bBest for:%b a new workstation you want fully set up. %b(recommended)%b\n\n' \
        "$HB_MUTED" "$NC" "$HB_OK" "$NC"

    printf '  %b2  Developer%b  %b· %s%b\n' "$HB_ACCENT" "$NC" "$HB_MUTED" "$(hb_type_size developer)" "$NC"
    printf '     Languages, build tools, containers, editors, and an XFCE desktop.\n'
    printf '     Skips office suites and media applications.\n'
    printf '     %bBest for:%b coding machines and development VMs.\n\n' "$HB_MUTED" "$NC"

    printf '  %b3  Desktop%b  %b· %s%b\n' "$HB_ACCENT" "$NC" "$HB_MUTED" "$(hb_type_size desktop)" "$NC"
    printf '     XFCE desktop, browsers, office and media apps, plus basic dev tools.\n'
    printf '     %bBest for:%b everyday desktops where you do not compile much.\n\n' "$HB_MUTED" "$NC"

    printf '  %b4  Minimal%b  %b· %s%b\n' "$HB_ACCENT" "$NC" "$HB_MUTED" "$(hb_type_size minimal)" "$NC"
    printf '     CLI tools, monitoring, nano, and Ratel Forge commands. No desktop,\n'
    printf '     audio stack, fonts, or GUI applications.\n'
    printf '     %bBest for:%b servers, containers, and remote hosts.\n\n' "$HB_MUTED" "$NC"

    printf '  %bDefault:%b 1 (Full). Type %b?%b to show this list again.\n\n' \
        "$HB_MUTED" "$NC" "$HB_ACCENT" "$NC"
}

get_installation_type() {
    HB_SELECTED_TYPE=""
    local type="${HONEY_BADGER_INSTALL_TYPE:-}"

    if [[ -n "$type" ]]; then
        type="${type,,}"
        case "$type" in
            full|developer|desktop|minimal)
                HB_SELECTED_TYPE="$type"
                return 0
                ;;
            *)
                log_error "Invalid install type: $type" >&2
                log_info "Valid types: full, developer, desktop, minimal" >&2
                return 1
                ;;
        esac
    fi

    if is_noninteractive; then
        log_error "Non-interactive mode requires --type (or HONEY_BADGER_INSTALL_TYPE)" >&2
        return 1
    fi

    show_installation_types

    local choice
    while true; do
        choice="$(hb_prompt "Select installation type [1-4]" "1")"
        case "$choice" in
            1|full)      HB_SELECTED_TYPE="full";      return 0 ;;
            2|developer) HB_SELECTED_TYPE="developer"; return 0 ;;
            3|desktop)   HB_SELECTED_TYPE="desktop";   return 0 ;;
            4|minimal)   HB_SELECTED_TYPE="minimal";   return 0 ;;
            \?|help)     show_installation_types ;;
            *)
                log_error "Invalid choice: $choice (expected 1-4, or ? for help)" >&2
                ;;
        esac
    done
}

# ── Summary & confirmation ──────────────────────────────────────────────────
# Warn about options that cannot apply to the selected profile, and drop them
# so the summary never advertises work the installer will not do.
check_option_coherence() {
    local install_type="$1"

    if [[ "$install_type" == "minimal" ]]; then
        if [[ "${HONEY_BADGER_HIGH_CONTRAST:-0}" == "1" ]]; then
            log_warning "--high-contrast has no effect on a Minimal install (no desktop)"
            HONEY_BADGER_HIGH_CONTRAST=0
        fi
        if [[ "$_HB_FONT_SIZE_SET" == "1" ]]; then
            log_warning "--font-size has no effect on a Minimal install (no desktop)"
            unset HONEY_BADGER_FONT HONEY_BADGER_MONO_FONT
        fi
        if [[ "${HONEY_BADGER_SKIP_THEME:-0}" == "1" ]]; then
            log_info "--skip-theme is redundant: Minimal installs no theme"
        fi
        if [[ -n "${HONEY_BADGER_COMPONENTS:-}" && "${HONEY_BADGER_COMPONENTS}" != "base" ]]; then
            log_warning "Minimal installs the base component only; ignoring --components"
            unset HONEY_BADGER_COMPONENTS
        fi
        return 0
    fi

    if ! hb_component_enabled desktop; then
        if [[ "${HONEY_BADGER_HIGH_CONTRAST:-0}" == "1" ]]; then
            log_warning "--high-contrast needs the desktop component; ignoring it"
            HONEY_BADGER_HIGH_CONTRAST=0
        fi
        if [[ "$_HB_FONT_SIZE_SET" == "1" ]]; then
            log_warning "--font-size needs the desktop component; ignoring it"
            unset HONEY_BADGER_FONT HONEY_BADGER_MONO_FONT
        fi
        if [[ "${HONEY_BADGER_SKIP_THEME:-0}" == "1" ]]; then
            log_info "--skip-theme is redundant: the desktop component is disabled"
        fi
    fi
}

show_installation_summary() {
    local install_type="$1"

    hb_section "Installation summary"
    hb_kv "Distribution" "${HB_DISTRO_LABEL:-unknown} (${HB_DISTRO_FAMILY:-unknown})"
    hb_kv "Architecture" "$(uname -m)"
    hb_kv "Install type" "$(hb_type_label "$install_type")"
    hb_kv "Components" "$(hb_effective_components)"
    hb_kv "User" "$(whoami) · $HOME"
    hb_kv "Disk" "${_HB_AVAILABLE_GB} GB free · ${_HB_REQUIRED_GB:-?} GB required"
    if hb_desktop_enabled; then
        hb_kv "Theme" "$(hb_theme_name)"
        if [[ -n "${HONEY_BADGER_FONT:-}" ]]; then
            hb_kv "Font" "$HONEY_BADGER_FONT"
        fi
    else
        hb_kv "Theme" "none (no desktop)"
    fi
    [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]] && hb_kv "Mode" "dry run (no changes)"
    printf '\n  Planned components:\n'
    hb_type_bullets "$install_type"
    printf '\n'
}

confirm_installation() {
    if [[ "${HONEY_BADGER_ASSUME_YES:-0}" == "1" ]]; then
        log_info "Confirmation skipped (--yes)"
        return 0
    fi
    if is_noninteractive; then
        log_info "Non-interactive mode: proceeding without confirmation"
        return 0
    fi
    if ! hb_confirm "Proceed with the installation?" no; then
        log_info "Installation cancelled"
        exit 0
    fi
    return 0
}

# ── Hand-off ────────────────────────────────────────────────────────────────
run_installer() {
    local distro="$1"
    local install_type="$2"
    local installer_script="$HONEY_BADGER_ROOT/distros/$distro/install-$distro.sh"

    if [[ ! -f "$installer_script" ]]; then
        log_error "Installer script not found: $installer_script"
        log_info "The checkout is incomplete; re-clone the repository."
        exit 1
    fi

    if [[ ! -x "$installer_script" ]]; then
        log_info "Marking installer executable…"
        chmod +x "$installer_script"
    fi

    hb_section "Provisioning"
    log_info "Running the $distro provisioner ($install_type)"
    export HONEY_BADGER_INSTALL_TYPE="$install_type"
    export HONEY_BADGER_DISTRO="$distro"

    if "$installer_script"; then
        hb_phases_reset 2>/dev/null || true
        hb_clear_checkpoint 2>/dev/null || true
        # The provisioner prints the post-install summary (and writes the JSON
        # summary) as its final action; this keeps it to exactly one report.
        log_success "Provisioning completed"
    else
        log_error "Provisioning failed"
        log_info "Review the log for details:"
        log_info "  • ${LOG_FILE:-unknown}"
        log_info "  • ${_HB_LOG_DIR:-/tmp}/honeybadger-${distro}-*.log"
        log_info "Fix the reported issue, then re-run install.sh to resume."
        exit 1
    fi
}

# ── Logging ─────────────────────────────────────────────────────────────────
# Tee stdout/stderr so package-manager output is captured in the log too.
# The shared library also writes structured lines; suppress its direct writes
# here to avoid duplicates. This flag is intentionally not exported, so child
# provisioners still keep their own per-distro logs.
setup_logging() {
    local log_dir="${_HB_LOG_DIR:-/tmp}"
    mkdir -p "$log_dir" 2>/dev/null || log_dir="/tmp"
    LOG_FILE="$log_dir/honeybadger-install-$(date +%Y%m%d-%H%M%S).log"
    : >>"$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/honeybadger-install.log"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    HONEY_BADGER_TEE_ACTIVE=1
    printf 'Ratel Forge installer — %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >>"$LOG_FILE"
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    setup_logging

    if declare -f hb_acquire_lock >/dev/null 2>&1; then
        hb_acquire_lock
    fi
    if declare -f hb_json_init >/dev/null 2>&1; then
        hb_json_init
    fi

    if [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]]; then
        log_warning "DRY-RUN: no system changes will be made"
    fi

    # Report an interrupted previous run. Provisioners are idempotent, so a
    # fresh run converges safely from where the last one stopped.
    local checkpoint_step=0
    if declare -f hb_load_checkpoint >/dev/null 2>&1; then
        checkpoint_step="$(hb_load_checkpoint)"
        if [[ "${checkpoint_step:-0}" -gt 0 ]]; then
            log_warning "A previous run stopped at step ${checkpoint_step}."
            if [[ "${HONEY_BADGER_RESUME:-0}" == "1" ]]; then
                log_info "Resume requested: completed phases will be skipped"
            elif ! is_noninteractive && ! hb_confirm "Continue with a new run?" yes; then
                log_info "Cancelled; the checkpoint is kept for reference"
                exit 0
            fi
        fi
    fi

    show_banner

    check_root
    if [[ "$CHECK_ONLY" == "1" ]]; then
        # A check should never block on a password prompt.
        if sudo -n true 2>/dev/null; then
            log_success "Sudo access available without a password"
        else
            log_info "Sudo will prompt for a password during installation"
        fi
    else
        check_sudo
    fi
    check_architecture

    if detect_distribution; then
        log_success "Detected ${HB_DISTRO_LABEL} (${HB_DISTRO_FAMILY} family)"
    fi

    if [[ "$CHECK_ONLY" == "1" ]]; then
        # Check against the baseline profile unless one was requested.
        run_preflight_checks
        hb_section "Result"
        if [[ -n "${HB_DISTRO_FAMILY:-}" ]]; then
            log_success "Environment is ready for Ratel Forge"
        else
            log_warning "Environment is ready, but this distribution is not supported"
        fi
        exit 0
    fi

    if [[ -z "${HB_DISTRO_FAMILY:-}" ]]; then
        hb_section "Unsupported distribution"
        log_error "Could not detect a supported Linux distribution."
        printf '\n  Supported families:\n'
        printf '    • Arch       Arch, Manjaro, EndeavourOS, ArcoLinux, Artix\n'
        printf '    • Debian     Debian, Ubuntu, Mint, Pop!_OS, Elementary, Zorin, Kali\n'
        printf '    • Fedora     Fedora, RHEL, CentOS, AlmaLinux, Rocky Linux\n'
        printf '    • Gentoo     Gentoo, Funtoo\n'
        printf '    • openSUSE   Tumbleweed, Leap, SLES, GeckoLinux\n'
        printf '    • Void       Void Linux\n'
        printf '    • Slackware  Slackware, Salix\n\n'
        log_info "Think this distribution should be supported? Open an issue:"
        log_info "https://github.com/James-HoneyBadger/Ratel-Forge/issues"
        exit 1
    fi

    if ! get_installation_type; then
        exit 2
    fi
    local install_type="$HB_SELECTED_TYPE"
    export HONEY_BADGER_INSTALL_TYPE="$install_type"
    log_success "Selected: $(hb_type_label "$install_type") ($(hb_type_size "$install_type"))"

    check_option_coherence "$install_type"

    run_preflight_checks

    show_installation_summary "$install_type"
    confirm_installation
    run_installer "$HB_DISTRO_FAMILY" "$install_type"
}

# Fallback trap when the shared library could not install its own.
if ! declare -f _hb_cleanup >/dev/null 2>&1; then
    trap 'printf "\nInstallation interrupted\n" >&2; exit 130' INT TERM
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
