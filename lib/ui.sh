#!/bin/bash
# shellcheck disable=SC2034  # Colour and glyph variables are consumed by the caller
# shellcheck disable=SC2088  # Tilde strings are human-readable labels, not paths
# Ratel Forge - Terminal UI layer
# ---------------------------------------------------------------------------
# Colour, glyph, layout, logging, prompt, and banner primitives shared by the
# installer, the distro provisioners, and the generated utilities.
#
# Sourced by lib/common.sh; do not source directly.
# ---------------------------------------------------------------------------

# Prevent double-sourcing
[[ -n "${_HB_UI_LOADED:-}" ]] && return 0
readonly _HB_UI_LOADED=1
# ── NO_COLOR / --no-color support (https://no-color.org) ────────────────────
# Disable colors when NO_COLOR is set, when not a TTY, or when --no-color is passed
if [[ -n "${NO_COLOR:-}" ]] || [[ "${HONEY_BADGER_NO_COLOR:-0}" == "1" ]] || [[ ! -t 1 ]]; then
    _HB_USE_COLOR=0
else
    _HB_USE_COLOR=1
fi

# ── Color definitions (individually guarded to handle partial inheritance) ─────
# The palette is intentionally warm and low-fatigue: amber accents on neutral
# ink, with muted supporting tones. 256-color terminals get the refined values;
# everything else falls back to the equivalent ANSI-8 color.
if [[ "$_HB_USE_COLOR" == "1" ]]; then
    _HB_COLOR_DEPTH="$(tput colors 2>/dev/null || echo 8)"
    [[ "$_HB_COLOR_DEPTH" =~ ^[0-9]+$ ]] || _HB_COLOR_DEPTH=8

    if [[ "$_HB_COLOR_DEPTH" -ge 256 ]]; then
        [[ -z "${HB_ACCENT:-}" ]]    && HB_ACCENT='\033[38;5;214m'   # amber
        [[ -z "${HB_ACCENT_ALT:-}" ]] && HB_ACCENT_ALT='\033[38;5;179m'
        [[ -z "${HB_OK:-}" ]]        && HB_OK='\033[38;5;113m'       # sage green
        [[ -z "${HB_WARN:-}" ]]      && HB_WARN='\033[38;5;221m'     # warm yellow
        [[ -z "${HB_ERR:-}" ]]       && HB_ERR='\033[38;5;203m'      # coral red
        [[ -z "${HB_STEP:-}" ]]      && HB_STEP='\033[38;5;111m'     # calm blue
        [[ -z "${HB_MUTED:-}" ]]     && HB_MUTED='\033[38;5;245m'    # grey
        [[ -z "${HB_RULE:-}" ]]      && HB_RULE='\033[38;5;238m'     # hairline
    else
        [[ -z "${HB_ACCENT:-}" ]]    && HB_ACCENT='\033[0;33m'
        [[ -z "${HB_ACCENT_ALT:-}" ]] && HB_ACCENT_ALT='\033[0;33m'
        [[ -z "${HB_OK:-}" ]]        && HB_OK='\033[0;32m'
        [[ -z "${HB_WARN:-}" ]]      && HB_WARN='\033[0;33m'
        [[ -z "${HB_ERR:-}" ]]       && HB_ERR='\033[0;31m'
        [[ -z "${HB_STEP:-}" ]]      && HB_STEP='\033[0;34m'
        [[ -z "${HB_MUTED:-}" ]]     && HB_MUTED='\033[0;37m'
        [[ -z "${HB_RULE:-}" ]]      && HB_RULE='\033[0;37m'
    fi

    [[ -z "${HB_DIM:-}" ]]   && HB_DIM='\033[2m'
    [[ -z "${RED:-}" ]]      && RED="$HB_ERR"
    [[ -z "${GREEN:-}" ]]    && GREEN="$HB_OK"
    [[ -z "${YELLOW:-}" ]]   && YELLOW="$HB_WARN"
    [[ -z "${BLUE:-}" ]]     && BLUE="$HB_STEP"
    [[ -z "${CYAN:-}" ]]     && CYAN="$HB_ACCENT"
    [[ -z "${MAGENTA:-}" ]]  && MAGENTA='\033[0;35m'
    [[ -z "${WHITE:-}" ]]    && WHITE='\033[0;37m'
    [[ -z "${BOLD:-}" ]]     && BOLD='\033[1m'
    [[ -z "${NC:-}" ]]       && NC='\033[0m'
else
    HB_ACCENT='' HB_ACCENT_ALT='' HB_OK='' HB_WARN='' HB_ERR=''
    HB_STEP='' HB_MUTED='' HB_RULE='' HB_DIM=''
    # Guard against readonly variables from parent shells
    readonly -p 2>/dev/null | grep -q ' RED=' || RED=''
    readonly -p 2>/dev/null | grep -q ' GREEN=' || GREEN=''
    readonly -p 2>/dev/null | grep -q ' YELLOW=' || YELLOW=''
    readonly -p 2>/dev/null | grep -q ' BLUE=' || BLUE=''
    readonly -p 2>/dev/null | grep -q ' MAGENTA=' || MAGENTA=''
    readonly -p 2>/dev/null | grep -q ' CYAN=' || CYAN=''
    readonly -p 2>/dev/null | grep -q ' WHITE=' || WHITE=''
    readonly -p 2>/dev/null | grep -q ' BOLD=' || BOLD=''
    readonly -p 2>/dev/null | grep -q ' NC=' || NC=''
fi

# ── Glyphs & geometry ───────────────────────────────────────────────────────
# Fall back to ASCII for non-UTF-8 locales, dumb terminals, or HONEY_BADGER_ASCII=1.
_HB_UTF8=0
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *UTF-8*|*utf8*|*UTF8*) _HB_UTF8=1 ;;
esac
[[ "${HONEY_BADGER_ASCII:-0}" == "1" || "${TERM:-}" == "dumb" ]] && _HB_UTF8=0

if [[ "$_HB_UTF8" == "1" ]]; then
    _HB_G_OK='✔'  _HB_G_ERR='✖'  _HB_G_WARN='▲'  _HB_G_INFO='•'  _HB_G_STEP='❯'
    _HB_G_RULE='─' _HB_G_V='│' _HB_G_TL='╭' _HB_G_TR='╮' _HB_G_BL='╰' _HB_G_BR='╯'
else
    _HB_G_OK='+'  _HB_G_ERR='x'  _HB_G_WARN='!'  _HB_G_INFO='-'  _HB_G_STEP='>'
    _HB_G_RULE='-' _HB_G_V='|' _HB_G_TL='+' _HB_G_TR='+' _HB_G_BL='+' _HB_G_BR='+'
fi


# ── Output primitives ───────────────────────────────────────────────────────
# Log files receive plain, timestamped text; the terminal receives the styled
# variant. Keeping them separate means ANSI escapes never leak into logs.
_hb_log_line() {
    local level="$1" message="$2"
    # When the top-level installer is already teeing stdout into LOG_FILE,
    # writing here too would duplicate every line.
    [[ "${HONEY_BADGER_TEE_ACTIVE:-0}" == "1" ]] && return 0
    [[ -n "${LOG_FILE:-}" ]] || return 0
    printf '%s  %-7s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$message" \
        >>"$LOG_FILE" 2>/dev/null || true
}

_hb_emit() {
    local color="$1" glyph="$2" level="$3" message="$4"
    printf '  %b%s%b %s\n' "$color" "$glyph" "$NC" "$message"
    _hb_log_line "$level" "$message"
}

# ── Logging functions ────────────────────────────────────────────────────────
log_info() {
    [[ "$HONEY_BADGER_VERBOSITY" -ge 1 ]] || return 0
    _hb_emit "$HB_ACCENT" "$_HB_G_INFO" INFO "$1"
}

log_success() {
    [[ "$HONEY_BADGER_VERBOSITY" -ge 1 ]] || return 0
    _hb_emit "$HB_OK" "$_HB_G_OK" OK "$1"
}

log_warning() {
    _hb_emit "$HB_WARN" "$_HB_G_WARN" WARN "$1"
}

log_error() {
    _hb_emit "$HB_ERR" "$_HB_G_ERR" ERROR "$1"
}

log_step() {
    [[ "$HONEY_BADGER_VERBOSITY" -ge 1 ]] || return 0
    _hb_emit "$HB_STEP" "$_HB_G_STEP" STEP "$1"
}

log_debug() {
    [[ "$HONEY_BADGER_VERBOSITY" -ge 2 ]] || return 0
    _hb_emit "$HB_MUTED" "$_HB_G_INFO" DEBUG "$1"
}

# Report the result of an action, or what it would have done in dry-run mode.
#   hb_outcome <dry-run message> <real message>
hb_outcome() {
    if hb_dry_run; then
        log_info "[DRY-RUN] $1"
    else
        log_success "$2"
    fi
}

# ── Layout helpers ──────────────────────────────────────────────────────────
# Usable width, clamped so the UI stays readable on very wide terminals.
hb_term_width() {
    local cols="${COLUMNS:-}"
    if [[ ! "$cols" =~ ^[0-9]+$ ]] && [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
        cols="$(tput cols 2>/dev/null || true)"
    fi
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
    (( cols < 48 )) && cols=48
    (( cols > 100 )) && cols=100
    printf '%s' "$cols"
}

_hb_repeat() {
    local glyph="$1" count="$2" out="" i
    for ((i = 0; i < count; i++)); do out+="$glyph"; done
    printf '%s' "$out"
}

hb_rule() {
    local width="${1:-$(hb_term_width)}"
    local count=$(( width - 4 ))
    (( count < 8 )) && count=8
    printf '  %b%s%b\n' "$HB_RULE" "$(_hb_repeat "$_HB_G_RULE" "$count")" "$NC"
}

hb_section() {
    local title="$1"
    local width="${2:-$(hb_term_width)}"
    local label="$title"
    local count=$(( width - 4 - ${#label} - 2 ))
    (( count < 4 )) && count=4
    printf '\n  %b%s%b %b%s%b %b%s%b\n' \
        "$HB_RULE" "$_HB_G_RULE$_HB_G_RULE" "$NC" \
        "${HB_ACCENT}${BOLD}" "$label" "$NC" \
        "$HB_RULE" "$(_hb_repeat "$_HB_G_RULE" "$count")" "$NC"
}

# Aligned key/value row used by summaries and reports.
hb_kv() {
    local key="$1" value="$2" width="${3:-16}"
    printf '  %b%-*s%b  %s\n' "$HB_MUTED" "$width" "$key" "$NC" "$value"
}

# ── Prompt helpers ──────────────────────────────────────────────────────────
# hb_prompt echoes the answer only, so callers can use command substitution.
hb_prompt() {
    local label="$1" default="${2:-}" answer=""
    if is_noninteractive; then
        printf '%s' "$default"
        return 0
    fi
    if [[ -n "$default" ]]; then
        printf '  %b?%b %s %b[%s]%b: ' "$HB_ACCENT" "$NC" "$label" "$HB_MUTED" "$default" "$NC" >&2
    else
        printf '  %b?%b %s: ' "$HB_ACCENT" "$NC" "$label" >&2
    fi
    IFS= read -r answer || answer=""
    printf '%s' "${answer:-$default}"
}

# hb_confirm <question> [yes|no] — returns 0 for yes.
hb_confirm() {
    local question="$1" default="${2:-no}" answer reply
    local hint='[y/N]' fallback='no'
    if [[ "$default" == "yes" || "$default" == "y" ]]; then
        hint='[Y/n]'
        fallback='yes'
    fi
    if is_noninteractive; then
        [[ "$fallback" == "yes" ]]
        return
    fi
    answer="$(hb_prompt "$question $hint" "")"
    reply="${answer:-$fallback}"
    case "${reply,,}" in
        y|yes) return 0 ;;
        *)     return 1 ;;
    esac
}

# ── Mode helpers ────────────────────────────────────────────────────────────
is_noninteractive() {
    [[ "${HONEY_BADGER_NONINTERACTIVE:-0}" == "1" || "${CI:-}" == "true" ]]
}

hb_dry_run() {
    [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]]
}


# ── Unified banner display ──────────────────────────────────────────────────
hb_show_banner() {
    local distro_name="${1:-}"
    local subtitle="${2:-Fearless Linux configuration}"
    local version="${HONEY_BADGER_VERSION:-2.4.0}"
    local codename="${HONEY_BADGER_CODENAME:-}"
    local install_type="${HONEY_BADGER_INSTALL_TYPE:-}"

    # A banner is pure decoration: never emit it in quiet mode, and never
    # repeat it when an orchestrator (install.sh) already printed one.
    [[ "${HONEY_BADGER_VERBOSITY:-1}" -ge 1 ]] || return 0
    [[ "${HONEY_BADGER_NO_BANNER:-0}" == "1" ]] && return 0
    [[ "${HONEY_BADGER_BANNER_SHOWN:-0}" == "1" ]] && return 0

    local mode=""
    [[ "${HONEY_BADGER_DRY_RUN:-0}" == "1" ]] && mode="dry-run"
    [[ "${HONEY_BADGER_NONINTERACTIVE:-0}" == "1" ]] && mode="${mode:+$mode · }non-interactive"
    [[ "${HONEY_BADGER_VERBOSITY:-1}" -ge 2 ]] && mode="${mode:+$mode · }verbose"

    local mark="[hb]"
    [[ "$_HB_UTF8" == "1" ]] && mark="🦡"

    local inner=58
    local wordmark="R A T E L   F O R G E"
    local border
    border="$(_hb_repeat "$_HB_G_RULE" $((inner + 2)))"

    printf '\n'
    printf '  %b%s%s%s%b\n' "$HB_ACCENT" "$_HB_G_TL" "$border" "$_HB_G_TR" "$NC"
    printf '  %b%s%b %-*s %b%s%b\n' "$HB_ACCENT" "$_HB_G_V" "$NC" "$inner" "" "$HB_ACCENT" "$_HB_G_V" "$NC"
    printf '  %b%s%b %b%-*s%b %b%s%b\n' "$HB_ACCENT" "$_HB_G_V" "$NC" \
        "${BOLD}${HB_ACCENT}" "$inner" "$wordmark" "$NC" "$HB_ACCENT" "$_HB_G_V" "$NC"
    printf '  %b%s%b %b%-*s%b %b%s%b\n' "$HB_ACCENT" "$_HB_G_V" "$NC" \
        "$HB_MUTED" "$inner" "${subtitle:0:$inner}" "$NC" "$HB_ACCENT" "$_HB_G_V" "$NC"
    printf '  %b%s%b %-*s %b%s%b\n' "$HB_ACCENT" "$_HB_G_V" "$NC" "$inner" "" "$HB_ACCENT" "$_HB_G_V" "$NC"
    printf '  %b%s%s%s%b\n' "$HB_ACCENT" "$_HB_G_BL" "$border" "$_HB_G_BR" "$NC"

    local meta="v${version}"
    [[ -n "$codename" ]] && meta+=" \"${codename}\""
    [[ -n "$distro_name" ]] && meta+=" · ${distro_name} edition"
    [[ -n "$install_type" ]] && meta+=" · ${install_type}"
    [[ -n "$mode" ]] && meta+=" · ${mode}"
    printf '  %b%s%b  %b%s%b\n\n' "$HB_ACCENT" "$mark" "$NC" "$HB_MUTED" "$meta" "$NC"
    HONEY_BADGER_BANNER_SHOWN=1
    export HONEY_BADGER_BANNER_SHOWN
}

# ── Unified distro log initialization ───────────────────────────────────────
hb_init_distro_log() {
    local distro_name="${1:-unknown}"
    LOG_FILE="${_HB_LOG_DIR}/honeybadger-${distro_name}-$(date +%Y%m%d-%H%M%S).log"
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/honeybadger-${distro_name}-install.log"
    log_debug "Distro log initialized: $LOG_FILE"
}

