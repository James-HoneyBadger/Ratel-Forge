#!/bin/bash
# shellcheck disable=SC2034  # Variables are consumed by the sourcing script
# shellcheck disable=SC2088  # Tilde strings are human-readable labels, not paths
set -euo pipefail

# Ratel Forge - Shared library entry point
# ---------------------------------------------------------------------------
# Loads the UI layer, runtime configuration, and the editor/utility layers,
# then provides the core runtime: sudo wrapper, progress, locking, checkpoints,
# rollback manifest, JSON summary, network checks, service management, and the
# development-environment helpers.
#
# Source this file at the top of each distro script:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/common.sh"
# ---------------------------------------------------------------------------

# Prevent double-sourcing
[[ -n "${_HONEY_BADGER_COMMON_LOADED:-}" ]] && return 0
readonly _HONEY_BADGER_COMMON_LOADED=1

# ── Project root detection (needed to locate the layer modules) ─────────────
if [[ -z "${HONEY_BADGER_ROOT:-}" ]]; then
    HONEY_BADGER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# ── UI layer (colours, glyphs, logging, prompts, banner) ─────────────────────
# shellcheck source=lib/ui.sh
source "$HONEY_BADGER_ROOT/lib/ui.sh"
# shellcheck source=lib/packages.sh
source "$HONEY_BADGER_ROOT/lib/packages.sh"

# ── Source config file (with key validation) ────────────────────────────────
_HB_VALID_CONFIG_KEYS=(
    HONEY_BADGER_VERSION HONEY_BADGER_CODENAME HONEY_BADGER_BUILD_DATE
    EDITOR VISUAL
    HONEY_BADGER_DEV_MODE
    HONEY_BADGER_SKIP_DOCKER HONEY_BADGER_SKIP_PYTHON
    HONEY_BADGER_SKIP_NODE HONEY_BADGER_SKIP_NANO HONEY_BADGER_SKIP_SHELL
    HONEY_BADGER_SKIP_GIT
    HONEY_BADGER_GIT_USERNAME HONEY_BADGER_GIT_EMAIL
    HONEY_BADGER_LOG_COUNT HONEY_BADGER_NETWORK_TIMEOUT
    HONEY_BADGER_MIN_DISK_GB
    HONEY_BADGER_NPM_GLOBAL_PATH
)

_hb_validate_config() {
    local config_file="$1"
    while IFS= read -r line; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        # Extract variable name
        local var_name="${line%%=*}"
        var_name="${var_name// /}"
        # Reject lines with command substitution or subshells
        if [[ "$line" =~ \$\( ]] || [[ "$line" =~ \` ]]; then
            echo "SECURITY: Rejecting config line with command substitution: $line" >&2
            return 1
        fi
        # Check against whitelist
        local valid=false
        for key in "${_HB_VALID_CONFIG_KEYS[@]}"; do
            if [[ "$var_name" == "$key" ]]; then
                valid=true
                break
            fi
        done
        if ! $valid; then
            echo "WARNING: Unknown config key '$var_name' in $config_file (ignored)" >&2
        fi
    done < "$config_file"
    return 0
}

if [[ -f "$HONEY_BADGER_ROOT/config/honey-badger-os.conf" ]]; then
    if _hb_validate_config "$HONEY_BADGER_ROOT/config/honey-badger-os.conf"; then
        # shellcheck source=../config/honey-badger-os.conf
        # shellcheck disable=SC1091  # resolved dynamically from HONEY_BADGER_ROOT
        source "$HONEY_BADGER_ROOT/config/honey-badger-os.conf"
    else
        echo "ERROR: Config file failed validation, using defaults" >&2
    fi
fi

# ── Verbosity control ───────────────────────────────────────────────────────
# Levels: 0=quiet (errors only), 1=normal (default), 2=verbose (debug output)
HONEY_BADGER_VERBOSITY="${HONEY_BADGER_VERBOSITY:-1}"

# ── Dry-run support ─────────────────────────────────────────────────────────
HONEY_BADGER_DRY_RUN="${HONEY_BADGER_DRY_RUN:-0}"

# ── Dev mode (from config) ──────────────────────────────────────────────────
# When HONEY_BADGER_DEV_MODE=true: skip confirmations, enable verbose logging
if [[ "${HONEY_BADGER_DEV_MODE:-false}" == "true" ]]; then
    HONEY_BADGER_VERBOSITY=2
fi

# ── Logging setup ────────────────────────────────────────────────────────────
# Persistent log directory with rotation
_HB_LOG_DIR="${HOME}/.local/share/honey-badger/logs"
mkdir -p "$_HB_LOG_DIR" 2>/dev/null || _HB_LOG_DIR="/tmp"

# Configurable log rotation count (default 5)
_HB_LOG_KEEP="${HONEY_BADGER_LOG_COUNT:-5}"

# Rotate logs: keep last N runs
_hb_rotate_logs() {
    [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]] && return 0
    local log_dir="$1"
    local keep="${_HB_LOG_KEEP}"
    local -a old_logs=()
    # Collect log files sorted oldest-first
    while IFS= read -r -d '' f; do
        old_logs+=("$f")
    done < <(find "$log_dir" -maxdepth 1 -name 'honeybadger-*.log' -type f -print0 2>/dev/null | sort -z)
    local count=${#old_logs[@]}
    local max_keep=$((keep - 1))
    if [[ $count -gt $max_keep ]]; then
        local to_remove=$((count - max_keep))
        for ((i = 0; i < to_remove; i++)); do
            rm -f "${old_logs[$i]}"
        done
    fi
}

_hb_rotate_logs "$_HB_LOG_DIR"

# Default log file with timestamp
: "${LOG_FILE:=${_HB_LOG_DIR}/honeybadger-$(date +%Y%m%d-%H%M%S).log}"
touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/honeybadger-install.log"

# Wrap sudo: in dry-run mode, print the command instead of executing it
hb_sudo() {
    if [[ "$HONEY_BADGER_DRY_RUN" == "1" ]]; then
        log_info "[DRY-RUN] sudo $*"
        # Drain stdin so pipelines such as `cmd | hb_sudo tee file` do not
        # die with SIGPIPE under `set -o pipefail`.
        if [[ ! -t 0 ]]; then
            cat >/dev/null 2>&1 || true
        fi
        return 0
    fi
    sudo "$@"
}

# ── Progress tracking ───────────────────────────────────────────────────────
_HB_STEP_CURRENT=0
_HB_STEP_TOTAL=0

hb_set_total_steps() {
    _HB_STEP_TOTAL="$1"
    _HB_STEP_CURRENT=0
}

hb_next_step() {
    _HB_STEP_CURRENT=$((_HB_STEP_CURRENT + 1))
    # Some flows add steps dynamically (AUR helpers, repositories). Keep the
    # denominator honest instead of printing "[13/12]".
    if [[ $_HB_STEP_TOTAL -gt 0 && $_HB_STEP_CURRENT -gt $_HB_STEP_TOTAL ]]; then
        _HB_STEP_TOTAL=$_HB_STEP_CURRENT
    fi
    local prefix=""
    if [[ $_HB_STEP_TOTAL -gt 0 ]]; then
        prefix="[${_HB_STEP_CURRENT}/${_HB_STEP_TOTAL}] "
    elif [[ $_HB_STEP_CURRENT -gt 0 ]]; then
        prefix="[${_HB_STEP_CURRENT}] "
    fi
    log_step "${prefix}$1"
}


# ── Lock file (prevent concurrent runs) ─────────────────────────────────────
_HB_LOCK_FILE="/tmp/honeybadger-install.lock"
_HB_LOCK_FD=""

hb_acquire_lock() {
    exec 9>"$_HB_LOCK_FILE"
    if ! flock -n 9; then
        log_error "Another Ratel Forge installation is already running."
        log_error "If this is wrong, remove $_HB_LOCK_FILE and try again."
        exit 1
    fi
    _HB_LOCK_FD=9
    echo $$ > "$_HB_LOCK_FILE"
    log_debug "Lock acquired (PID $$)"
}

hb_release_lock() {
    if [[ -n "$_HB_LOCK_FD" ]]; then
        flock -u 9 2>/dev/null || true
        rm -f "$_HB_LOCK_FILE"
        log_debug "Lock released"
    fi
}

# ── Signal trapping & cleanup ───────────────────────────────────────────────
declare -a _HB_TEMP_FILES=()

hb_register_temp() {
    _HB_TEMP_FILES+=("$1")
}

_hb_cleanup() {
    local exit_code=$?
    # Remove registered temp files
    for f in "${_HB_TEMP_FILES[@]:-}"; do
        if [[ -n "$f" ]]; then
            rm -f "$f" 2>/dev/null || true
        fi
    done
    # Release lock
    hb_release_lock
    # Save checkpoint on non-zero exit
    if [[ $exit_code -ne 0 && $_HB_STEP_CURRENT -gt 0 ]]; then
        _hb_save_checkpoint
        log_warning "Installation interrupted at step ${_HB_STEP_CURRENT}/${_HB_STEP_TOTAL}"
        log_info "Last completed step: ${_HB_STEP_CURRENT}"
        log_info "Re-run the installer to resume from the last checkpoint."
        log_info "Installation log: ${LOG_FILE}"
    fi
    exit "$exit_code"
}

trap '_hb_cleanup' EXIT
trap 'log_error "Installation interrupted by user (Ctrl+C)"; log_info "Log file: ${LOG_FILE}"; exit 130' INT TERM

# ── Config backup ────────────────────────────────────────────────────────────
# Back up a file before overwriting. Creates <file>.hb-backup if no backup exists yet.
hb_backup_file() {
    local file="$1"
    [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]] && return 0
    if [[ -f "$file" && ! -f "${file}.hb-backup" ]]; then
        cp "$file" "${file}.hb-backup"
        log_debug "Backed up $file -> ${file}.hb-backup"
        hb_json_add_config "backup:${file}.hb-backup"
    fi
}

# ── Checkpoint / resume ─────────────────────────────────────────────────────
_HB_CHECKPOINT_FILE="${HOME}/.local/share/honey-badger/checkpoint"

_hb_save_checkpoint() {
    mkdir -p "$(dirname "$_HB_CHECKPOINT_FILE")" 2>/dev/null || true
    cat > "$_HB_CHECKPOINT_FILE" << ENDCP
CHECKPOINT_STEP=${_HB_STEP_CURRENT}
CHECKPOINT_TOTAL=${_HB_STEP_TOTAL}
CHECKPOINT_DISTRO=${HONEY_BADGER_DISTRO:-unknown}
CHECKPOINT_TYPE=${HONEY_BADGER_INSTALL_TYPE:-unknown}
CHECKPOINT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ENDCP
}

hb_load_checkpoint() {
    if [[ -f "$_HB_CHECKPOINT_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$_HB_CHECKPOINT_FILE"
        echo "${CHECKPOINT_STEP:-0}"
    else
        echo "0"
    fi
}

hb_clear_checkpoint() {
    rm -f "$_HB_CHECKPOINT_FILE"
}

hb_should_skip_step() {
    local checkpoint_step="${1:-0}"
    [[ $_HB_STEP_CURRENT -le $checkpoint_step ]]
}

# ── Phase-level resume ──────────────────────────────────────────────────────
# Checkpoints record how far a run got; phases record which units of work
# completed, so `--resume` can skip them safely on the next run.
_HB_PHASE_FILE="${HOME}/.local/share/honey-badger/phases"

hb_phases_reset() {
    rm -f "$_HB_PHASE_FILE"
}

hb_phase_done() {
    [[ -f "$_HB_PHASE_FILE" ]] || return 1
    grep -Fxq "$1" "$_HB_PHASE_FILE" 2>/dev/null
}

hb_phase_mark_done() {
    local id="$1"
    hb_dry_run && return 0
    mkdir -p "$(dirname "$_HB_PHASE_FILE")" 2>/dev/null || true
    printf '%s\n' "$id" >>"$_HB_PHASE_FILE" 2>/dev/null || true
}

# Prepare resume state. Refuses to reuse state from a different distro or
# install type, because the completed phases would not mean the same thing.
hb_phases_init() {
    local type="$1"
    local distro="${HONEY_BADGER_DISTRO:-unknown}"
    hb_dry_run && return 0

    if [[ "${HONEY_BADGER_RESUME:-0}" == "1" && -f "$_HB_PHASE_FILE" ]]; then
        if ! grep -Fxq "type:$type" "$_HB_PHASE_FILE" 2>/dev/null ||
           ! grep -Fxq "distro:$distro" "$_HB_PHASE_FILE" 2>/dev/null; then
            log_warning "Resume state is for a different distro/type; starting fresh"
            rm -f "$_HB_PHASE_FILE"
        fi
    elif [[ "${HONEY_BADGER_RESUME:-0}" != "1" ]]; then
        rm -f "$_HB_PHASE_FILE"
    fi

    if [[ ! -f "$_HB_PHASE_FILE" ]]; then
        mkdir -p "$(dirname "$_HB_PHASE_FILE")" 2>/dev/null || true
        {
            printf 'type:%s\n' "$type"
            printf 'distro:%s\n' "$distro"
        } >"$_HB_PHASE_FILE" 2>/dev/null || true
    fi
}

# hb_phase <id> <command> [args...]
# Runs a phase unless it already completed in a resumed run, then records it.
hb_phase() {
    local id="$1"
    shift
    if [[ "${HONEY_BADGER_RESUME:-0}" == "1" ]] && hb_phase_done "$id"; then
        log_info "Resume: skipping completed phase '$id'"
        return 0
    fi
    "$@"
    hb_phase_mark_done "$id"
}

# ── Rollback manifest ───────────────────────────────────────────────────────
_HB_ROLLBACK_FILE="${HOME}/.local/share/honey-badger/rollback-manifest"

hb_rollback_init() {
    [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]] && return 0
    mkdir -p "$(dirname "$_HB_ROLLBACK_FILE")" 2>/dev/null || true
    echo "# Ratel Forge Rollback Manifest - $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$_HB_ROLLBACK_FILE"
}

hb_rollback_add_packages() {
    [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]] && return 0
    local pm_type="$1"
    shift
    for pkg in "$@"; do
        echo "PACKAGE:${pm_type}:${pkg}" >> "$_HB_ROLLBACK_FILE"
    done
}

hb_rollback_add_file() {
    [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]] && return 0
    echo "FILE:$1" >> "$_HB_ROLLBACK_FILE"
}

hb_rollback_add_group() {
    [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]] && return 0
    echo "GROUP:$1:$2" >> "$_HB_ROLLBACK_FILE"
}

# ── Verified downloads ──────────────────────────────────────────────────────
# hb_download <url> <dest> [sha256]
# Fetches to a file, rejects empty responses, and verifies a SHA-256 when one
# is supplied. Set HONEY_BADGER_REQUIRE_CHECKSUMS=1 to fail closed when callers
# forget to pass one. In dry-run mode nothing is fetched.
hb_download() {
    local url="$1" dest="$2" expected="${3:-}"
    local timeout="${HONEY_BADGER_NETWORK_TIMEOUT:-3}"

    if hb_dry_run; then
        log_info "[DRY-RUN] Would download $url"
        return 0
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 2 --connect-timeout "$timeout" --max-time 120 \
            "$url" -o "$dest" || { log_error "Download failed: $url"; return 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -q --timeout="$timeout" --tries=2 -O "$dest" "$url" \
            || { log_error "Download failed: $url"; return 1; }
    else
        log_error "Neither curl nor wget is available"
        return 1
    fi

    if [[ ! -s "$dest" ]]; then
        log_error "Downloaded file is empty: $url"
        rm -f "$dest"
        return 1
    fi

    if [[ -n "$expected" ]]; then
        local actual
        actual="$(sha256sum "$dest" 2>/dev/null | awk '{print $1}')"
        if [[ "$actual" != "$expected" ]]; then
            log_error "Checksum mismatch for $url"
            log_info "expected: $expected"
            log_info "actual:   ${actual:-unavailable}"
            rm -f "$dest"
            return 1
        fi
        log_debug "Checksum verified: $url"
    elif [[ "${HONEY_BADGER_REQUIRE_CHECKSUMS:-0}" == "1" ]]; then
        log_error "No checksum supplied for $url (HONEY_BADGER_REQUIRE_CHECKSUMS=1)"
        rm -f "$dest"
        return 1
    fi

    return 0
}

# ── Network connectivity check ──────────────────────────────────────────────
hb_check_network() {
    local timeout="${HONEY_BADGER_NETWORK_TIMEOUT:-3}"
    log_debug "Checking network connectivity (timeout: ${timeout}s)..."
    # Try DNS resolution first (works behind firewalls that block ICMP)
    if command -v getent >/dev/null 2>&1; then
        if getent hosts dns.google >/dev/null 2>&1; then
            log_debug "Network OK (DNS resolution)"
            return 0
        fi
    fi
    # Fall back to host
    if command -v host >/dev/null 2>&1; then
        if host -W "$timeout" dns.google >/dev/null 2>&1; then
            log_debug "Network OK (host lookup)"
            return 0
        fi
    fi
    # Fall back to ping
    if ping -c 1 -W "$timeout" 8.8.8.8 >/dev/null 2>&1; then
        log_debug "Network OK (ping)"
        return 0
    fi
    # Last resort: try to reach a repo directly
    if curl -fsSL --connect-timeout "$timeout" --max-time 10 https://google.com -o /dev/null 2>/dev/null; then
        log_debug "Network OK (curl)"
        return 0
    fi
    log_error "No network connectivity detected"
    log_info "Please check your network connection and try again"
    return 1
}


# ── Unified service enablement (cross-init-system) ─────────────────────────
hb_enable_service() {
    local service_name="$1"
    if [[ "$HONEY_BADGER_DRY_RUN" == "1" ]]; then
        log_info "[DRY-RUN] Would enable service: $service_name"
        return 0
    fi
    # systemd
    if command -v systemctl >/dev/null 2>&1; then
        hb_sudo systemctl enable "$service_name" 2>/dev/null || true
        log_debug "Enabled $service_name via systemd"
        return 0
    fi
    # OpenRC
    if command -v rc-update >/dev/null 2>&1; then
        hb_sudo rc-update add "$service_name" default 2>/dev/null || true
        log_debug "Enabled $service_name via OpenRC"
        return 0
    fi
    # runit
    if [[ -d /etc/sv/"$service_name" ]]; then
        hb_sudo ln -sf "/etc/sv/$service_name" /var/service/ 2>/dev/null || true
        log_debug "Enabled $service_name via runit"
        return 0
    fi
    # SysV init
    if command -v update-rc.d >/dev/null 2>&1; then
        hb_sudo update-rc.d "$service_name" defaults 2>/dev/null || true
        log_debug "Enabled $service_name via SysV init"
        return 0
    fi
    log_warning "No supported init system found for enabling $service_name"
}

# ── Component selection ─────────────────────────────────────────────────────
# Components describe package groups: base, dev, apps.
# HONEY_BADGER_COMPONENTS is a comma-separated subset; unset means all.
hb_component_enabled() {
    local name="$1"
    [[ -z "${HONEY_BADGER_COMPONENTS:-}" ]] && return 0
    case ",${HONEY_BADGER_COMPONENTS}," in
        *",$name,"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Map a package-group label ("developer", "applications", …) to a component.
hb_component_for_label() {
    local label="${1,,}"
    case "$label" in
        *base*)                                 printf 'base' ;;
        *developer*|*development*|*dev*)        printf 'dev' ;;
        *application*|*snap*|*flatpak*|*aur*)   printf 'apps' ;;
        *)                                      printf 'base' ;;
    esac
}

hb_component_allowed() {
    hb_component_enabled "$(hb_component_for_label "$1")"
}

# Components actually installed by the selected profile. The install type
# selects the candidate groups and --components narrows them further; base is
# the floor and is always reported.
hb_effective_components() {
    local type="${HONEY_BADGER_INSTALL_TYPE:-full}"
    local candidates
    case "$type" in
        minimal)   candidates="base" ;;
        developer) candidates="base dev" ;;
        apps)      candidates="base apps" ;;
        *)         candidates="base dev apps" ;;
    esac
    local out="" c
    for c in $candidates; do
        hb_component_enabled "$c" && out="${out:+$out,}$c"
    done
    printf '%s' "${out:-base}"
}

# True when any skip flag or component filter is active, which makes the
# static step budget inaccurate.
hb_skip_active() {
    [[ -n "${HONEY_BADGER_COMPONENTS:-}" ]] && return 0
    local var
    for var in HONEY_BADGER_SKIP_DOCKER HONEY_BADGER_SKIP_PYTHON \
               HONEY_BADGER_SKIP_NODE HONEY_BADGER_SKIP_NANO \
               HONEY_BADGER_SKIP_SHELL HONEY_BADGER_SKIP_GIT; do
        [[ "${!var:-0}" == "1" ]] && return 0
    done
    return 1
}

# ── Component skip flags ────────────────────────────────────────────────────
hb_skip_component() {
    local component="$1"
    local var_name="HONEY_BADGER_SKIP_${component^^}"
    [[ "${!var_name:-0}" == "1" ]]
}

# ── Idempotent bashrc helper ────────────────────────────────────────────────
ensure_bashrc_line() {
    local line="$1"
    local bashrc="$HOME/.bashrc"

    if [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]]; then
        log_info "[DRY-RUN] Would ensure ~/.bashrc contains: $line"
        return 0
    fi

    touch "$bashrc"
    hb_backup_file "$bashrc"
    if ! grep -Fxq "$line" "$bashrc"; then
        printf '%s\n' "$line" >> "$bashrc"
    fi
}

# ── JSON summary output ─────────────────────────────────────────────────────
# Collects installation events and writes a JSON summary at the end
declare -a _HB_JSON_PACKAGES_INSTALLED=()
declare -a _HB_JSON_CONFIGS_CHANGED=()
declare -a _HB_JSON_ERRORS=()
_HB_JSON_START_TIME=""

hb_json_init() {
    _HB_JSON_START_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

hb_json_add_package() {
    _HB_JSON_PACKAGES_INSTALLED+=("$1")
}

hb_json_add_config() {
    _HB_JSON_CONFIGS_CHANGED+=("$1")
}

hb_json_add_error() {
    _HB_JSON_ERRORS+=("$1")
}

# Escape a value for inclusion in a JSON string literal.
_hb_json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

# shellcheck disable=SC2120  # callers and tests may pass an output path
hb_json_write() {
    local output_file="${1:-/tmp/honeybadger-summary.json}"
    local end_time
    end_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local distro="${HONEY_BADGER_DISTRO:-unknown}"
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-unknown}"

    # Build JSON arrays safely
    local pkgs_json="" p
    for p in "${_HB_JSON_PACKAGES_INSTALLED[@]+"${_HB_JSON_PACKAGES_INSTALLED[@]}"}"; do
        pkgs_json="${pkgs_json}\"$(_hb_json_escape "$p")\","
    done
    pkgs_json="[${pkgs_json%,}]"

    local configs_json="" c
    for c in "${_HB_JSON_CONFIGS_CHANGED[@]+"${_HB_JSON_CONFIGS_CHANGED[@]}"}"; do
        configs_json="${configs_json}\"$(_hb_json_escape "$c")\","
    done
    configs_json="[${configs_json%,}]"

    local errors_json="" e
    for e in "${_HB_JSON_ERRORS[@]+"${_HB_JSON_ERRORS[@]}"}"; do
        errors_json="${errors_json}\"$(_hb_json_escape "$e")\","
    done
    errors_json="[${errors_json%,}]"

    local status="success" dry_run="false"
    if [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]]; then
        status="dry-run"
        dry_run="true"
    elif [[ ${#_HB_JSON_ERRORS[@]} -gt 0 ]]; then
        status="partial"
    fi

    cat > "$output_file" << ENDJSON
{
  "honey_badger_version": "$(_hb_json_escape "${HONEY_BADGER_VERSION:-1.0.0}")",
  "distro": "$(_hb_json_escape "$distro")",
  "install_type": "$(_hb_json_escape "$install_type")",
  "components": "$(_hb_json_escape "$(hb_effective_components)")",
  "status": "${status}",
  "dry_run": ${dry_run},
  "start_time": "${_HB_JSON_START_TIME}",
  "end_time": "${end_time}",
  "packages_installed": ${pkgs_json},
  "configs_changed": ${configs_json},
  "errors": ${errors_json}
}
ENDJSON
    log_info "Installation summary written to $output_file"
}


# ── Git configuration ────────────────────────────────────────────────────────
# Set a global value only when the user has not chosen one already.
_hb_git_default() {
    local key="$1" value="$2"
    if ! git config --global --get "$key" >/dev/null 2>&1; then
        git config --global "$key" "$value"
    fi
}

setup_git() {
    hb_next_step "Configuring Git..."

    if hb_dry_run; then
        log_info "[DRY-RUN] Would configure Git identity, defaults, and pager"
        return 0
    fi

    if hb_skip_component "git"; then
        log_info "Skipping Git configuration (--skip-git)"
        return 0
    fi

    if ! command -v git >/dev/null 2>&1; then
        log_warning "git is not installed; skipping Git configuration"
        return 0
    fi

    if git config --global user.name >/dev/null 2>&1; then
        log_info "Git identity already configured"
    else
        local git_username="" git_email=""
        if is_noninteractive; then
            git_username="${HONEY_BADGER_GIT_USERNAME:-}"
            git_email="${HONEY_BADGER_GIT_EMAIL:-}"
            if [[ -z "$git_username" || -z "$git_email" ]]; then
                log_warning "Skipping Git identity setup in non-interactive mode"
                log_info "Set HONEY_BADGER_GIT_USERNAME and HONEY_BADGER_GIT_EMAIL to configure automatically"
            fi
        else
            git_username="$(hb_prompt "Git user name")"
            git_email="$(hb_prompt "Git email")"
            if [[ -z "$git_username" || -z "$git_email" ]]; then
                log_warning "Git identity left unset (empty input)"
            elif [[ ! "$git_email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
                log_warning "That does not look like an email address; skipping Git identity"
                git_username=""
            fi
        fi

        if [[ -n "$git_username" && -n "$git_email" ]]; then
            git config --global user.name "$git_username"
            git config --global user.email "$git_email"
            hb_json_add_config "~/.gitconfig"
            log_success "Git identity configured"
        fi
    fi

    _hb_git_default init.defaultBranch main
    _hb_git_default pull.rebase false
    _hb_git_default merge.conflictStyle zdiff3
    _hb_git_default rerere.enabled true
    _hb_git_default rebase.autoStash true
    _hb_git_default push.autoSetupRemote true
    _hb_git_default fetch.prune true

    local editor_cmd="" candidate
    for candidate in nano vim vi; do
        if command -v "$candidate" >/dev/null 2>&1; then
            editor_cmd="$candidate"
            break
        fi
    done
    [[ -n "$editor_cmd" ]] && _hb_git_default core.editor "$editor_cmd"

    if command -v delta >/dev/null 2>&1; then
        _hb_git_default core.pager delta
        _hb_git_default interactive.diffFilter "delta --color-only"
        _hb_git_default delta.navigate true
        _hb_git_default delta.line-numbers true
    fi

    local excludes="${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"
    mkdir -p "$(dirname "$excludes")"
    if [[ ! -f "$excludes" ]]; then
        cat > "$excludes" << 'ENDGITIGNORE'
# Managed by Ratel Forge
.DS_Store
Thumbs.db
*.swp
*.swo
.idea/
.vscode/
ENDGITIGNORE
        hb_json_add_config "~/.config/git/ignore"
    fi
    _hb_git_default core.excludesFile "$excludes"

    log_success "Git defaults applied"
}

# ── Docker setup (with privilege warning) ────────────────────────────────────
setup_docker() {
    hb_next_step "Configuring Docker..."

    if hb_skip_component "docker"; then
        log_info "Skipping Docker setup (--skip-docker)"
        return 0
    fi

    if hb_dry_run; then
        log_info "[DRY-RUN] Would enable Docker and add the user to its group"
        return 0
    fi

    if ! command -v docker >/dev/null 2>&1; then
        log_info "Docker not installed, skipping configuration"
        return 0
    fi

    # Enable service (systemd)
    if command -v systemctl >/dev/null 2>&1; then
        hb_sudo systemctl enable docker 2>/dev/null || true
        hb_sudo systemctl start docker 2>/dev/null || true
    fi

    # Add user to docker group WITH explicit warning
    if ! groups "$USER" | grep -q docker; then
        log_warning "Adding $USER to the 'docker' group grants root-equivalent privileges."
        log_warning "Only proceed if you trust all software running under this user account."
        hb_sudo usermod -aG docker "$USER"
        log_success "Docker configured (log out and back in for group changes to take effect)"
    else
        log_info "User already in docker group"
    fi

    hb_json_add_config "docker-group"
}

# ── Python development setup ────────────────────────────────────────────────
setup_python_dev() {
    if hb_skip_component "python"; then
        log_info "Skipping Python dev setup (--skip-python)"
        return 0
    fi

    if hb_dry_run; then
        log_info "[DRY-RUN] Would install pip, setuptools, wheel, and pipx"
        return 0
    fi

    local python_cmd=""
    if command -v python3 >/dev/null 2>&1; then
        python_cmd="python3"
    elif command -v python >/dev/null 2>&1; then
        python_cmd="python"
    else
        log_warning "Python not found, skipping Python dev setup"
        return 0
    fi

    "$python_cmd" -m pip install --user --upgrade pip setuptools wheel 2>/dev/null || true
    "$python_cmd" -m pip install --user pipx 2>/dev/null || true
    log_success "Python development environment configured"
}

# ── Node.js development setup ───────────────────────────────────────────────
setup_node_dev() {
    if hb_skip_component "node"; then
        log_info "Skipping Node.js dev setup (--skip-node)"
        return 0
    fi

    if hb_dry_run; then
        log_info "[DRY-RUN] Would configure the npm prefix and global tools"
        return 0
    fi

    if ! command -v npm >/dev/null 2>&1; then
        log_warning "npm not found, skipping Node.js dev setup"
        return 0
    fi

    local npm_global="${HONEY_BADGER_NPM_GLOBAL_PATH:-$HOME/.npm-global}"
    mkdir -p "$npm_global"
    npm config set prefix "$npm_global"
    ensure_bashrc_line "export PATH=${npm_global}/bin:\$PATH"

    npm config set fund false 2>/dev/null || true
    npm config set audit-level high 2>/dev/null || true
    npm config set update-notifier false 2>/dev/null || true

    npm install -g typescript ts-node nodemon eslint prettier 2>/dev/null || true
    log_success "Node.js development environment configured"
}

# ── Development environment orchestrator ─────────────────────────────────────
setup_development_environment() {
    hb_next_step "Setting up development environment..."

    if ! hb_component_enabled dev; then
        log_info "Skipping development environment (dev component disabled)"
        return 0
    fi
    setup_git
    setup_docker
    setup_python_dev
    setup_node_dev
    log_success "Development environment setup completed"
}


# ── Editor, shell, and utility layers ────────────────────────────────────────
# shellcheck source=lib/editor.sh
source "$HONEY_BADGER_ROOT/lib/editor.sh"
# shellcheck source=lib/shell.sh
source "$HONEY_BADGER_ROOT/lib/shell.sh"
# shellcheck source=lib/utilities.sh
source "$HONEY_BADGER_ROOT/lib/utilities.sh"
