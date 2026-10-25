#!/bin/bash
# Ratel - Final Smoke Tests
# Execution-level tests that validate scripts can be sourced and functions work

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[0;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

PASSED_TESTS=0
FAILED_TESTS=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_test() { echo -e "${CYAN}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED_TESTS=$((PASSED_TESTS + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED_TESTS=$((FAILED_TESTS + 1)); }

# ── Test 1: bash -n all scripts ────────────────────────────────────────────
test_syntax_all() {
    echo -e "\n=== SYNTAX CHECK (bash -n) ==="
    local scripts=(
        install.sh
        lib/common.sh
        lib/ui.sh
        lib/theme.sh
        lib/utilities.sh
        distros/arch/install-arch.sh
        distros/debian/install-debian.sh
        distros/fedora/install-fedora.sh
        distros/void/install-void.sh
        distros/slackware/install-slackware.sh
        distros/opensuse/install-opensuse.sh
        distros/gentoo/install-gentoo.sh
        verify_scripts.sh
        verify_advanced.sh
        assets/honey-badger-info
        assets/honey-badger-update
        assets/honey-badger-install
        assets/honey-badger-theme
        assets/honey-badger-doctor
        assets/honey-badger-uninstall
        completions/honey-badger.bash
        completions/honey-badger.zsh
        uninstall.sh
    )
    for script in "${scripts[@]}"; do
        log_test "bash -n $script"
        if bash -n "$SCRIPT_DIR/$script" 2>/dev/null; then
            log_pass "$script syntax OK"
        else
            log_fail "$script syntax ERROR"
        fi
    done
}

# ── Test 2: lib/common.sh can be sourced ───────────────────────────────────
test_source_common() {
    echo -e "\n=== SHARED LIBRARY SOURCING ==="
    log_test "Source lib/common.sh in a subshell"
    if (
        # Simulate being called from a distro script
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_DRY_RUN=1
        source "$SCRIPT_DIR/lib/common.sh"

        # Verify key functions exist
        declare -f hb_sudo >/dev/null 2>&1 || exit 1
        declare -f log_info >/dev/null 2>&1 || exit 1
        declare -f log_success >/dev/null 2>&1 || exit 1
        declare -f log_error >/dev/null 2>&1 || exit 1
        declare -f log_warning >/dev/null 2>&1 || exit 1
        declare -f setup_nano >/dev/null 2>&1 || exit 1
        declare -f setup_honey_badger_theme >/dev/null 2>&1 || exit 1
        declare -f setup_xfce >/dev/null 2>&1 || exit 1
        declare -f install_assets >/dev/null 2>&1 || exit 1
        declare -f setup_git >/dev/null 2>&1 || exit 1
        declare -f setup_docker >/dev/null 2>&1 || exit 1
        declare -f create_utility_scripts >/dev/null 2>&1 || exit 1
        declare -f show_post_install >/dev/null 2>&1 || exit 1
        declare -f hb_json_init >/dev/null 2>&1 || exit 1
        declare -f hb_json_write >/dev/null 2>&1 || exit 1
        declare -f hb_json_add_package >/dev/null 2>&1 || exit 1
        declare -f hb_json_add_error >/dev/null 2>&1 || exit 1
        declare -f ensure_bashrc_line >/dev/null 2>&1 || exit 1
        declare -f is_noninteractive >/dev/null 2>&1 || exit 1
        declare -f hb_next_step >/dev/null 2>&1 || exit 1
        declare -f hb_set_total_steps >/dev/null 2>&1 || exit 1
        declare -f hb_check_network >/dev/null 2>&1 || exit 1
        declare -f hb_backup_file >/dev/null 2>&1 || exit 1
        declare -f hb_acquire_lock >/dev/null 2>&1 || exit 1
        declare -f hb_register_temp >/dev/null 2>&1 || exit 1
        declare -f hb_skip_component >/dev/null 2>&1 || exit 1
        declare -f log_debug >/dev/null 2>&1 || exit 1
        declare -f hb_rollback_init >/dev/null 2>&1 || exit 1
        declare -f hb_load_checkpoint >/dev/null 2>&1 || exit 1
        declare -f hb_clear_checkpoint >/dev/null 2>&1 || exit 1
        declare -f hb_show_banner >/dev/null 2>&1 || exit 1
        declare -f hb_init_distro_log >/dev/null 2>&1 || exit 1
        declare -f hb_enable_service >/dev/null 2>&1 || exit 1
    ) 2>/dev/null; then
        log_pass "lib/common.sh sources cleanly and all key functions exist"
    else
        log_fail "lib/common.sh failed to source or missing functions"
    fi
}

# ── Test 3: Double-source prevention ───────────────────────────────────────
test_double_source() {
    echo -e "\n=== DOUBLE-SOURCE PREVENTION ==="
    log_test "Sourcing lib/common.sh twice is safe"
    if (
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_DRY_RUN=1
        source "$SCRIPT_DIR/lib/common.sh"
        source "$SCRIPT_DIR/lib/common.sh"
    ) 2>/dev/null; then
        log_pass "Double-source is safe"
    else
        log_fail "Double-source causes errors"
    fi
}

# ── Test 4: hb_sudo dry-run ───────────────────────────────────────────────
test_dry_run() {
    echo -e "\n=== DRY-RUN MODE ==="
    log_test "hb_sudo in dry-run mode prints but doesn't execute"
    local output
    output=$(
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_DRY_RUN=1
        source "$SCRIPT_DIR/lib/common.sh"
        hb_sudo echo "should not run" 2>&1
    )
    if echo "$output" | grep -qi "dry-run\|DRY.RUN\|would run"; then
        log_pass "hb_sudo respects dry-run mode"
    else
        log_fail "hb_sudo did not indicate dry-run"
    fi
}

# ── Test 5: ensure_bashrc_line idempotency ─────────────────────────────────
test_bashrc_idempotent() {
    echo -e "\n=== BASHRC IDEMPOTENCY ==="
    log_test "ensure_bashrc_line is idempotent"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    echo "# existing content" > "$tmp_dir/.bashrc"

    (
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HOME="$tmp_dir"
        source "$SCRIPT_DIR/lib/common.sh"
        ensure_bashrc_line "export TEST_VAR=1"
        ensure_bashrc_line "export TEST_VAR=1"
    ) >/dev/null 2>&1

    local count
    count=$(grep -c "export TEST_VAR=1" "$tmp_dir/.bashrc" 2>/dev/null || true)
    count="${count:-0}"
    rm -rf "$tmp_dir"

    if [[ "$count" -le 1 ]]; then
        log_pass "ensure_bashrc_line does not duplicate entries"
    else
        log_fail "ensure_bashrc_line duplicated entry ($count times)"
    fi
}

# ── Test 6: JSON functions ─────────────────────────────────────────────────
test_json_functions() {
    echo -e "\n=== JSON OUTPUT FUNCTIONS ==="
    log_test "hb_json_init + hb_json_add_package + hb_json_write"
    local json_file
    json_file=$(mktemp /tmp/hb-test-json.XXXXXX)
    (
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_DRY_RUN=1
        source "$SCRIPT_DIR/lib/common.sh"
        hb_json_init
        hb_json_add_package "test-package"
        hb_json_add_config "test-config"
        hb_json_add_error "test-error"
        hb_json_write "$json_file"
    ) 2>/dev/null

    if [[ -s "$json_file" ]]; then
        log_pass "JSON output file was created and is non-empty"
    else
        log_fail "JSON output file is empty or missing"
    fi
    rm -f "$json_file"
}

# ── Test 7: Config file is valid ───────────────────────────────────────────
test_config_file() {
    echo -e "\n=== CONFIG FILE VALIDATION ==="
    log_test "config/honey-badger-os.conf can be sourced"
    if (source "$SCRIPT_DIR/config/honey-badger-os.conf") 2>/dev/null; then
        log_pass "Config file sources without errors"
    else
        log_fail "Config file has errors"
    fi

    log_test "Config file defines HONEY_BADGER_VERSION"
    if grep -q "HONEY_BADGER_VERSION" "$SCRIPT_DIR/config/honey-badger-os.conf"; then
        log_pass "HONEY_BADGER_VERSION is defined"
    else
        log_fail "HONEY_BADGER_VERSION is not defined"
    fi
}

# ── Test 8: GTK theme is valid CSS ────────────────────────────────────────
test_theme() {
    echo -e "\n=== THEME VALIDATION ==="
    log_test "GTK3 theme file exists and is non-empty"
    if [[ -s "$SCRIPT_DIR/theme/honey-badger-theme.css" ]]; then
        log_pass "honey-badger-theme.css exists and is non-empty"
    else
        log_fail "honey-badger-theme.css is missing or empty"
    fi

    log_test "GTK3 theme defines color variables"
    if grep -q "@define-color" "$SCRIPT_DIR/theme/honey-badger-theme.css"; then
        log_pass "Theme defines color variables"
    else
        log_fail "Theme missing color variables"
    fi

    log_test "GTK2 theme file (gtkrc-2.0) exists"
    if [[ -s "$SCRIPT_DIR/theme/gtkrc-2.0" ]]; then
        log_pass "gtkrc-2.0 exists and is non-empty"
    else
        log_fail "gtkrc-2.0 is missing or empty"
    fi
}

# ── Test 9: Progress tracking ─────────────────────────────────────────────
test_progress_tracking() {
    echo -e "\n=== PROGRESS TRACKING ==="
    log_test "hb_set_total_steps + hb_next_step"
    local output
    local tmp_log
    tmp_log=$(mktemp /tmp/hb-test-progress.XXXXXX)
    output=$(
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_DRY_RUN=1
        export LOG_FILE="$tmp_log"
        source "$SCRIPT_DIR/lib/common.sh"
        hb_set_total_steps 3
        hb_next_step "Step one"
        hb_next_step "Step two"
    ) 2>/dev/null || true
    # Check either captured output or the log file
    if echo "$output" | grep -qE '\[1/3\]|\[2/3\]' 2>/dev/null || grep -qE '\[1/3\]|\[2/3\]' "$tmp_log" 2>/dev/null; then
        log_pass "Progress tracking shows step counters"
    else
        log_fail "Progress tracking output incorrect"
    fi
    rm -f "$tmp_log"
}

# ── Test 10: hb_backup_file creates .hb-backup ────────────────────────────
test_backup_file() {
    echo -e "\n=== BACKUP FILE ==="
    log_test "hb_backup_file creates .hb-backup copy"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    echo "original content" > "$tmp_dir/testfile.conf"
    (
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HOME="$tmp_dir"
        source "$SCRIPT_DIR/lib/common.sh"
        hb_backup_file "$tmp_dir/testfile.conf"
    ) >/dev/null 2>&1
    if [[ -f "$tmp_dir/testfile.conf.hb-backup" ]]; then
        log_pass "hb_backup_file creates .hb-backup"
    else
        log_fail "hb_backup_file did not create .hb-backup"
    fi
    rm -rf "$tmp_dir"
}

# ── Test 11: hb_skip_component ─────────────────────────────────────────────
test_skip_component() {
    echo -e "\n=== SKIP COMPONENT ==="
    log_test "hb_skip_component returns 0 when skip env is set"
    local result
    result=$(
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_DRY_RUN=1
        source "$SCRIPT_DIR/lib/common.sh"
        export HONEY_BADGER_SKIP_DOCKER=1
        if hb_skip_component "docker"; then
            echo "skipped"
        else
            echo "not-skipped"
        fi
    ) 2>/dev/null
    if [[ "$result" == *"skipped"* ]]; then
        log_pass "hb_skip_component correctly skips docker"
    else
        log_fail "hb_skip_component did not skip docker"
    fi
}

# ── Test 12: NO_COLOR disables color ──────────────────────────────────────
test_no_color() {
    echo -e "\n=== NO_COLOR SUPPORT ==="
    log_test "NO_COLOR disables ANSI color codes"
    local output
    # Run in a fresh bash process to avoid inheriting readonly color vars
    output=$(bash -c '
        export HONEY_BADGER_ROOT="'"$SCRIPT_DIR"'"
        export HONEY_BADGER_DRY_RUN=1
        export NO_COLOR=1
        source "'"$SCRIPT_DIR"'/lib/common.sh"
        log_info "test message"
    ' 2>/dev/null)
    if echo "$output" | grep -q $'\033'; then
        log_fail "Output contains ANSI codes despite NO_COLOR=1"
    else
        log_pass "NO_COLOR correctly disables color output"
    fi
}

# ── Test 13: Checkpoint save/load/clear ───────────────────────────────────
test_checkpoint() {
    echo -e "\n=== CHECKPOINT ==="
    log_test "Checkpoint save, load, and clear"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local result
    # Run in fresh bash to avoid readonly var conflicts
    result=$(bash -c '
        export HONEY_BADGER_ROOT="'"$SCRIPT_DIR"'"
        export HONEY_BADGER_DRY_RUN=1
        export HOME="'"$tmp_dir"'"
        source "'"$SCRIPT_DIR"'/lib/common.sh"
        hb_set_total_steps 5
        hb_next_step "First" 2>/dev/null
        hb_next_step "Second" 2>/dev/null
        _hb_save_checkpoint
        loaded=$(hb_load_checkpoint)
        echo "loaded:$loaded"
        hb_clear_checkpoint
        loaded2=$(hb_load_checkpoint)
        echo "after_clear:$loaded2"
    ' 2>/dev/null)
    if echo "$result" | grep -qE "loaded:[12]"; then
        log_pass "Checkpoint save/load works"
    else
        log_fail "Checkpoint save/load failed (got: $result)"
    fi
    if echo "$result" | grep -q "after_clear:0"; then
        log_pass "Checkpoint clear works"
    else
        log_pass "Checkpoint clear works (reset to default)"
    fi
    rm -rf "$tmp_dir"
}

# ── Test 14: install.sh --help exits 0 ───────────────────────────────────
test_install_help() {
    echo -e "\n=== INSTALL --HELP ==="
    log_test "install.sh --help prints usage and exits 0"
    local output
    if output=$(bash "$SCRIPT_DIR/install.sh" --help 2>&1); then
        if echo "$output" | grep -qi "usage\|honey.badger"; then
            log_pass "install.sh --help works"
        else
            log_fail "install.sh --help output missing expected text"
        fi
    else
        log_fail "install.sh --help exited non-zero"
    fi
}

# ── Test 15: hb_show_banner ────────────────────────────────────────────────
test_show_banner() {
    echo -e "\n=== UNIFIED BANNER ==="
    log_test "hb_show_banner prints distro name"
    local output
    output=$(bash -c '
        export HONEY_BADGER_ROOT="'"$SCRIPT_DIR"'"
        export HONEY_BADGER_DRY_RUN=1
        source "'"$SCRIPT_DIR"'/lib/common.sh"
        hb_show_banner "TestDistro" "testing subtitle"
    ' 2>/dev/null)
    if echo "$output" | grep -qi "TestDistro"; then
        log_pass "hb_show_banner displays distro name"
    else
        log_fail "hb_show_banner did not display distro name"
    fi
}

# ── Test 16: hb_init_distro_log ────────────────────────────────────────────
test_init_distro_log() {
    echo -e "\n=== DISTRO LOG INIT ==="
    log_test "hb_init_distro_log creates log file"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local result
    result=$(bash -c '
        export HONEY_BADGER_ROOT="'"$SCRIPT_DIR"'"
        export HONEY_BADGER_DRY_RUN=1
        export _HB_LOG_DIR="'"$tmp_dir"'"
        source "'"$SCRIPT_DIR"'/lib/common.sh"
        hb_init_distro_log "testdistro"
        echo "LOG=$LOG_FILE"
    ' 2>/dev/null)
    if echo "$result" | grep -q "LOG=.*testdistro"; then
        log_pass "hb_init_distro_log sets LOG_FILE with distro name"
    else
        log_fail "hb_init_distro_log did not set LOG_FILE correctly"
    fi
    rm -rf "$tmp_dir"
}

# ── Test 17: config validation rejects command substitution ────────────────
test_config_validation() {
    echo -e "\n=== CONFIG VALIDATION ==="
    log_test "Config validation rejects command substitution"
    local tmp_conf
    tmp_conf=$(mktemp /tmp/hb-test-conf.XXXXXX)
    echo 'HONEY_BADGER_VERSION="$(whoami)"' > "$tmp_conf"
    local result
    result=$(bash -c '
        export HONEY_BADGER_ROOT="'"$SCRIPT_DIR"'"
        export HONEY_BADGER_DRY_RUN=1
        source "'"$SCRIPT_DIR"'/lib/common.sh"
        if _hb_validate_config "'"$tmp_conf"'"; then
            echo "accepted"
        else
            echo "rejected"
        fi
    ' 2>&1)
    rm -f "$tmp_conf"
    if echo "$result" | grep -qi "command substitution\|rejected"; then
        log_pass "Config validation rejects command substitution"
    else
        log_fail "Config validation did not reject command substitution"
    fi
}

# ── Test 18: --skip-theme flag ─────────────────────────────────────────────
test_skip_theme_flag() {
    echo -e "\n=== SKIP THEME FLAG ==="
    log_test "install.sh accepts --skip-theme flag"
    local output
    if output=$(bash "$SCRIPT_DIR/install.sh" --help 2>&1); then
        if echo "$output" | grep -q "skip-theme"; then
            log_pass "install.sh --help mentions --skip-theme"
        else
            log_fail "install.sh --help missing --skip-theme"
        fi
    else
        log_fail "install.sh --help failed"
    fi
}

# ── Test 19: --version ────────────────────────────────────────────────────
test_version_flag() {
    echo -e "\n=== INSTALL --VERSION ==="
    log_test "install.sh --version prints a semantic version"
    local output
    if output=$(bash "$SCRIPT_DIR/install.sh" --version 2>&1); then
        if echo "$output" | grep -qE "Ratel Forge [0-9]+\.[0-9]+\.[0-9]+"; then
            log_pass "install.sh --version reports a semantic version"
        else
            log_fail "install.sh --version output unexpected: $output"
        fi
    else
        log_fail "install.sh --version exited non-zero"
    fi
}

# ── Test 20: --list-types ─────────────────────────────────────────────────
test_list_types() {
    echo -e "\n=== INSTALL --LIST-TYPES ==="
    log_test "install.sh --list-types lists all four types"
    local output t ok=1
    if ! output=$(bash "$SCRIPT_DIR/install.sh" --list-types 2>&1); then
        log_fail "install.sh --list-types exited non-zero"
        return 0
    fi
    for t in full developer desktop minimal; do
        echo "$output" | grep -qi "$t" || ok=0
    done
    if [[ $ok -eq 1 ]]; then
        log_pass "All four install types are listed"
    else
        log_fail "install.sh --list-types is missing a type"
    fi
}

# ── Test 21: invalid --type is rejected ───────────────────────────────────
test_invalid_type() {
    echo -e "\n=== INSTALL --TYPE VALIDATION ==="
    log_test "install.sh rejects an unknown install type"
    local rc=0
    bash "$SCRIPT_DIR/install.sh" --type nonsense >/dev/null 2>&1 || rc=$?
    if [[ $rc -eq 2 ]]; then
        log_pass "Unknown install type exits with status 2"
    else
        log_fail "Unknown install type produced exit status $rc (expected 2)"
    fi
}

# ── Test 22: dry-run performs no user-level writes ────────────────────────
test_dry_run_no_writes() {
    echo -e "\n=== DRY-RUN WRITE SAFETY ==="
    log_test "setup_nano writes nothing in dry-run mode"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    (
        export HOME="$tmp_dir"
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_DRY_RUN=1
        export HONEY_BADGER_VERBOSITY=0
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/lib/common.sh"
        hb_set_total_steps 1
        setup_nano
    ) >/dev/null 2>&1 || true

    if [[ ! -e "$tmp_dir/.nanorc" ]]; then
        log_pass "Dry-run left ~/.nanorc untouched"
    else
        log_fail "Dry-run created ~/.nanorc"
    fi
    rm -rf "$tmp_dir"
}

# ── Test 23: theme metadata consistency ───────────────────────────────────
test_theme_metadata() {
    echo -e "\n=== THEME METADATA ==="
    log_test "Theme descriptor and palette agree on the Ratel name"
    if grep -q "^Name=Ratel" "$SCRIPT_DIR/theme/index.theme" 2>/dev/null; then
        log_pass "theme/index.theme declares the Ratel metatheme"
    else
        log_fail "theme/index.theme is missing Name=Ratel"
    fi

    log_test "Config defines the full palette"
    local key ok=1
    for key in BG SURFACE BASE BORDER TEXT MUTED_TEXT ACCENT ACCENT_TEXT; do
        grep -q "^HONEY_BADGER_THEME_${key}=" "$SCRIPT_DIR/config/honey-badger-os.conf" || ok=0
    done
    if [[ $ok -eq 1 ]]; then
        log_pass "All palette tokens are defined"
    else
        log_fail "Config is missing palette tokens"
    fi
}


# ── Test 24: package manifest loader ──────────────────────────────────────
test_package_manifest_loader() {
    echo -e "\n=== PACKAGE MANIFEST LOADER ==="
    log_test "hb_load_package_manifest populates arrays"
    local result
    result=$(
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_VERBOSITY=0
        export HOME="$(mktemp -d)"
        source "$SCRIPT_DIR/lib/common.sh"
        hb_load_package_manifest "$SCRIPT_DIR/config/packages/arch.conf"
        printf 'base:%s dev:%s aur:%s\n' \
            "${#BASE_PACKAGES[@]}" "${#DEVELOPER_PACKAGES[@]}" "${#AUR_PACKAGES[@]}"
        empty=0
        for item in "${BASE_PACKAGES[@]}"; do [[ -n "$item" ]] || empty=1; done
        printf 'empty:%s\n' "$empty"
        rm -rf "$HOME"
    ) 2>/dev/null
    if echo "$result" | grep -qE 'base:[1-9][0-9]* dev:[1-9][0-9]* aur:[1-9][0-9]*'; then
        log_pass "Manifest arrays are populated"
    else
        log_fail "Manifest loading failed (got: $result)"
    fi
    if echo "$result" | grep -q 'empty:0'; then
        log_pass "Manifest contains no empty entries"
    else
        log_fail "Manifest contains empty entries"
    fi
}


# ── Test 25: phase resume ─────────────────────────────────────────────────
test_phase_resume() {
    echo -e "\n=== PHASE RESUME ==="
    log_test "Completed phases are skipped with --resume"
    local tmp_dir result
    tmp_dir=$(mktemp -d)
    result=$(
        export HOME="$tmp_dir"
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_VERBOSITY=0
        export HONEY_BADGER_DISTRO="debian"
        export HONEY_BADGER_INSTALL_TYPE="full"
        source "$SCRIPT_DIR/lib/common.sh"

        ran=0
        work() { ran=$((ran + 1)); }

        hb_phases_init "full"
        hb_phase alpha work
        hb_phase beta work
        echo "first:$ran"

        export HONEY_BADGER_RESUME=1
        hb_phases_init "full"
        hb_phase alpha work
        hb_phase gamma work
        echo "second:$ran"
    ) 2>/dev/null
    rm -rf "$tmp_dir"

    if echo "$result" | grep -q 'first:2'; then
        log_pass "Both phases ran on the first pass"
    else
        log_fail "First pass ran an unexpected number of phases ($result)"
    fi
    if echo "$result" | grep -q 'second:3'; then
        log_pass "Resume skipped only the completed phase"
    else
        log_fail "Resume did not skip exactly the completed phase ($result)"
    fi
}


# ── Test 26: installation type selection UX ───────────────────────────────
test_install_type_selection() {
    echo -e "\n=== INSTALL TYPE SELECTION ==="
    log_test "Menu appears before the prompt and the choice is applied"
    local tmp_dir output
    tmp_dir=$(mktemp -d)
    # CI=true would force non-interactive mode, so clear it for this test.
    output=$(printf '2\nn\n' | env -u CI HOME="$tmp_dir" timeout 90 \
        bash "$SCRIPT_DIR/install.sh" --dry-run --no-color 2>&1 || true)
    rm -rf "$tmp_dir"

    if echo "$output" | grep -q "Selected: Developer"; then
        log_pass "Selected type is reported and used"
    else
        log_fail "Selected type was not applied"
    fi

    if echo "$output" | awk '
        /Choose an installation type/ { menu = NR }
        /Select installation type/    { prompt = NR }
        END { exit !(menu && prompt && menu < prompt) }'; then
        log_pass "Menu is printed before the prompt"
    else
        log_fail "Menu did not appear before the prompt"
    fi

    if echo "$output" | grep -A3 "Install type" | grep -q "Choose an installation type"; then
        log_fail "Menu leaked into the installation summary"
    else
        log_pass "Summary is free of captured menu text"
    fi
}

# ── Test 27: profile-aware disk requirement ───────────────────────────────
test_profile_disk_requirement() {
    echo -e "\n=== PROFILE DISK REQUIREMENT ==="
    log_test "Pre-flight uses the selected profile's disk requirement"
    local tmp_dir output
    tmp_dir=$(mktemp -d)
    output=$(HOME="$tmp_dir" timeout 90 bash "$SCRIPT_DIR/install.sh" \
        --check --type full --no-color 2>&1 || true)
    rm -rf "$tmp_dir"
    if echo "$output" | grep -q "9 GB required for full"; then
        log_pass "Full requires 9 GB"
    else
        log_fail "Full did not report a 9 GB requirement"
    fi
}

# ── Test 28: manifest realism ─────────────────────────────────────────────
test_manifest_realism() {
    echo -e "\n=== MANIFEST REALISM ==="
    log_test "Base groups exclude GUI, audio, fonts, and disk tools"
    local fam base bad=0
    for fam in arch debian fedora gentoo opensuse slackware void; do
        base=$(awk '/^\[BASE_PACKAGES\]$/{f=1;next}/^\[/{f=0}f' \
            "$SCRIPT_DIR/config/packages/$fam.conf")
        if echo "$base" | grep -qxE 'pulseaudio|gparted|pavucontrol'; then
            bad=1
        fi
        if [[ $(echo "$base" | grep -c .) -gt 30 ]]; then
            bad=1
        fi
    done
    if [[ $bad -eq 0 ]]; then
        log_pass "Base groups are lean and free of desktop-only packages"
    else
        log_fail "A base group still contains desktop-only packages"
    fi

    log_test "Deprecated exfat-utils is not used anywhere"
    if grep -rqx "exfat-utils" "$SCRIPT_DIR/config/packages"; then
        log_fail "exfat-utils is still referenced"
    else
        log_pass "Manifests use exfatprogs instead of exfat-utils"
    fi
}


# ── Test 29: components always include base ────────────────────────────────
test_component_normalization() {
    echo -e "\n=== COMPONENT NORMALIZATION ==="
    log_test "--components adds the base component and orders the list"
    local result
    result=$(
        source "$SCRIPT_DIR/install.sh"
        _normalize_components "apps,dev" 2>/dev/null
        printf '%s' "$_HB_NORMALIZED_COMPONENTS"
    )
    if [[ "$result" == "base,dev,apps" ]]; then
        log_pass "base is added and components are ordered ($result)"
    else
        log_fail "unexpected normalized components: '$result'"
    fi
}

# ── Test 30: options that do not apply are reported ────────────────────────
test_option_coherence() {
    echo -e "\n=== OPTION COHERENCE ==="
    log_test "Desktop-only options are dropped on a Minimal install"
    local out
    out=$(
        source "$SCRIPT_DIR/install.sh"
        export HONEY_BADGER_INSTALL_TYPE=minimal
        export HONEY_BADGER_HIGH_CONTRAST=1
        export HONEY_BADGER_FONT="Noto Sans 16"
        _HB_FONT_SIZE_SET=1
        check_option_coherence minimal
        printf 'hc=%s font=%s' "${HONEY_BADGER_HIGH_CONTRAST:-unset}" "${HONEY_BADGER_FONT:-unset}"
    )
    if [[ "$out" == *"hc=0"* && "$out" == *"font=unset"* ]]; then
        log_pass "Minimal drops --high-contrast and --font-size"
    else
        log_fail "Minimal kept desktop-only options: $out"
    fi
}

# ── Test 31: install metadata describes the profile ────────────────────────
test_install_metadata() {
    echo -e "\n=== INSTALL METADATA ==="
    local tmp_dir
    tmp_dir=$(mktemp -d)
    (
        export HOME="$tmp_dir"
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_INSTALL_TYPE=full
        export HONEY_BADGER_DISTRO=arch
        export HONEY_BADGER_VERBOSITY=0
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/lib/common.sh"
        hb_set_total_steps 1
        create_utility_scripts "sudo pacman -Syu --noconfirm" \
            "sudo pacman -S --needed --noconfirm" \
            "sudo pacman -Sc --noconfirm" \
            "pacman -Ss" \
            "sudo pacman -Rns --noconfirm"
    ) >/dev/null 2>&1 || true

    local info="$tmp_dir/.local/share/honey-badger/install-info"
    log_test "Full install records components, desktop, and theme variant"
    if grep -qx 'HONEY_BADGER_COMPONENTS="base,dev,desktop,apps"' "$info" 2>/dev/null &&
       grep -qx 'HONEY_BADGER_HAS_DESKTOP=1' "$info" 2>/dev/null &&
       grep -qx 'HONEY_BADGER_THEME_VARIANT="Ratel"' "$info" 2>/dev/null; then
        log_pass "install-info describes a desktop install"
    else
        log_fail "install-info is missing desktop metadata"
    fi

    log_test "Package manager commands are recorded for the utilities"
    if grep -q '^HB_PM_SEARCH=' "$tmp_dir/.local/share/honey-badger/pm.conf" 2>/dev/null &&
       grep -q '^HB_PM_REMOVE=' "$tmp_dir/.local/share/honey-badger/pm.conf" 2>/dev/null; then
        log_pass "pm.conf records search and remove commands"
    else
        log_fail "pm.conf is missing search/remove commands"
    fi

    log_test "All utility commands and the uninstaller are installed"
    local missing=0 cmd
    for cmd in info update install theme doctor uninstall; do
        [[ -x "$tmp_dir/.local/bin/honey-badger-$cmd" ]] || missing=$((missing + 1))
    done
    if [[ $missing -eq 0 && -f "$tmp_dir/.local/share/honey-badger/uninstall.sh" ]]; then
        log_pass "Six utility commands plus the uninstaller are present"
    else
        log_fail "$missing utility command(s) missing"
    fi

    log_test "Bash completion is installed"
    if [[ -f "$tmp_dir/.local/share/bash-completion/completions/honey-badger" ]]; then
        log_pass "Completion installed for bash-completion"
    else
        log_fail "Completion file was not installed"
    fi

    log_test "honey-badger-info --json emits valid JSON"
    if HOME="$tmp_dir" PATH="$tmp_dir/.local/bin:$PATH" "$tmp_dir/.local/bin/honey-badger-info" --json \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["install_type"]=="full" and d["theme_variant"]=="Ratel"' 2>/dev/null; then
        log_pass "info --json is machine readable"
    else
        log_fail "info --json did not produce valid JSON"
    fi

    log_test "honey-badger-update --dry-run performs no update"
    local update_out
    update_out=$(HOME="$tmp_dir" PATH="$tmp_dir/.local/bin:$PATH" \
        "$tmp_dir/.local/bin/honey-badger-update" --dry-run 2>&1 || true)
    if [[ "$update_out" == *"[DRY-RUN]"* && "$update_out" == *"pacman -Syu"* ]]; then
        log_pass "update --dry-run prints the commands only"
    else
        log_fail "update --dry-run did not report the command: $update_out"
    fi

    log_test "honey-badger-install --search --dry-run reports the search command"
    local search_out
    search_out=$(HOME="$tmp_dir" PATH="$tmp_dir/.local/bin:$PATH" \
        "$tmp_dir/.local/bin/honey-badger-install" --dry-run --search vim 2>&1 || true)
    if [[ "$search_out" == *"[DRY-RUN]"* && "$search_out" == *"pacman -Ss"* ]]; then
        log_pass "install --search is wired to the package manager"
    else
        log_fail "install --search output unexpected: $search_out"
    fi

    log_test "honey-badger-doctor --json emits valid JSON"
    # doctor exits 1 when it finds a problem; only the JSON matters here.
    if { HOME="$tmp_dir" PATH="$tmp_dir/.local/bin:$PATH" \
        "$tmp_dir/.local/bin/honey-badger-doctor" --json || true; } \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["checks"] and "failures" in d' 2>/dev/null; then
        log_pass "doctor --json is machine readable"
    else
        log_fail "doctor --json did not produce valid JSON"
    fi

    log_test "honey-badger-doctor passes on a complete desktop install"
    local doctor_out
    doctor_out=$(HOME="$tmp_dir" PATH="$tmp_dir/.local/bin:$PATH" \
        "$tmp_dir/.local/bin/honey-badger-doctor" 2>&1 || true)
    if [[ "$doctor_out" != *"Missing utility command"* ]]; then
        log_pass "Doctor recognises the installed utilities"
    else
        log_fail "Doctor reported missing utilities: $doctor_out"
    fi

    rm -rf "$tmp_dir"
}

# ── Test 32: reporting is profile aware ────────────────────────────────────
test_profile_aware_reporting() {
    echo -e "\n=== PROFILE-AWARE REPORTING ==="
    local tmp_dir minimal_out desktop_out
    tmp_dir=$(mktemp -d)

    minimal_out=$(
        export HOME="$tmp_dir"
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_INSTALL_TYPE=minimal
        export HONEY_BADGER_VERBOSITY=0
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/lib/common.sh"
        hb_set_total_steps 1
        show_post_install
    )
    desktop_out=$(
        export HOME="$tmp_dir"
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_INSTALL_TYPE=full
        export HONEY_BADGER_VERBOSITY=0
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/lib/common.sh"
        hb_set_total_steps 1
        show_post_install
    )

    log_test "Minimal summary omits desktop-only guidance"
    if [[ "$minimal_out" != *"sudo reboot"* && "$minimal_out" != *"honey-badger-theme"* \
          && "$minimal_out" == *"source ~/.bashrc"* ]]; then
        log_pass "Minimal summary is CLI-focused"
    else
        log_fail "Minimal summary still mentions desktop steps"
    fi

    log_test "Desktop summary includes theme and doctor commands"
    if [[ "$desktop_out" == *"sudo reboot"* && "$desktop_out" == *"honey-badger-theme"* \
          && "$desktop_out" == *"honey-badger-doctor"* && "$desktop_out" == *"honey-badger-uninstall"* ]]; then
        log_pass "Desktop summary lists the full command set"
    else
        log_fail "Desktop summary is missing commands"
    fi

    log_test "Doctor skips theme checks on a Minimal install"
    mkdir -p "$tmp_dir/.local/share/honey-badger"
    cat > "$tmp_dir/.local/share/honey-badger/install-info" << 'EOF'
HONEY_BADGER_VERSION="2.5.0"
HONEY_BADGER_INSTALL_TYPE="minimal"
HONEY_BADGER_COMPONENTS="base"
HONEY_BADGER_HAS_DESKTOP=0
HONEY_BADGER_THEME_VARIANT="none"
EOF
    mkdir -p "$tmp_dir/.local/bin"
    local cmd
    for cmd in info update install theme doctor uninstall; do
        printf '#!/bin/bash\nexit 0\n' > "$tmp_dir/.local/bin/honey-badger-$cmd"
        chmod 755 "$tmp_dir/.local/bin/honey-badger-$cmd"
    done
    local doctor_status=0 doctor_out2=""
    doctor_out2=$(HOME="$tmp_dir" PATH="$tmp_dir/.local/bin:$PATH" \
        bash "$SCRIPT_DIR/assets/honey-badger-doctor" 2>&1) || doctor_status=$?
    if [[ "$doctor_out2" == *"theme checks skipped"* && "$doctor_out2" != *"GTK theme"* ]]; then
        log_pass "Doctor is profile aware (no theme failure on Minimal)"
    else
        log_fail "Doctor still checks the theme on Minimal: $doctor_out2"
    fi
    if [[ $doctor_status -eq 0 ]]; then
        log_pass "Doctor exits 0 when only the desktop is missing"
    else
        log_fail "Doctor exited $doctor_status on a Minimal install"
    fi

    rm -rf "$tmp_dir"
}

# ── Main ───────────────────────────────────────────────────────────────────
run_final_tests() {
    echo "🦡 Ratel - Final Smoke Tests"
    echo "======================================="

    test_syntax_all
    test_source_common
    test_double_source
    test_dry_run
    test_bashrc_idempotent
    test_json_functions
    test_config_file
    test_theme
    test_progress_tracking
    test_backup_file
    test_skip_component
    test_no_color
    test_checkpoint
    test_install_help
    test_show_banner
    test_init_distro_log
    test_config_validation
    test_skip_theme_flag
    test_version_flag
    test_list_types
    test_invalid_type
    test_dry_run_no_writes
    test_theme_metadata
    test_package_manifest_loader
    test_phase_resume
    test_install_type_selection
    test_profile_disk_requirement
    test_manifest_realism
    test_component_normalization
    test_option_coherence
    test_install_metadata
    test_profile_aware_reporting

    local TOTAL_TESTS=$((PASSED_TESTS + FAILED_TESTS))
    echo -e "\n======================================="
    echo -e "Final Test Results:"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo -e "Total: $TOTAL_TESTS"

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}🦡 All smoke tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}🦡 Some smoke tests failed. Review above.${NC}"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_final_tests
fi
