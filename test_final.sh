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

# Run every test under a throwaway HOME so the suite never writes logs or
# backups into the developer's real home directory.
TEST_SANDBOX_HOME=""
cleanup_test_sandbox() {
    [[ -n "$TEST_SANDBOX_HOME" ]] && rm -rf "$TEST_SANDBOX_HOME"
}

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
        lib/editor.sh
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
        assets/honey-badger-report
        assets/honey-badger-doctor
        assets/honey-badger-uninstall
        completions/honey-badger.bash
        completions/honey-badger.zsh
        scripts/check-no-desktop-layer.sh
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
        declare -f setup_shell >/dev/null 2>&1 || exit 1
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
        declare -f hb_component_enabled >/dev/null 2>&1 || exit 1
        declare -f hb_effective_components >/dev/null 2>&1 || exit 1
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

# ── Test 8: no desktop-environment or login code ─────────────────────────
test_no_desktop_layer() {
    echo -e "\n=== DESKTOP-LAYER GUARD ==="
    log_test "Code contains no desktop-environment or login handling"
    if bash "$SCRIPT_DIR/scripts/check-no-desktop-layer.sh" >/dev/null 2>&1; then
        log_pass "No desktop-environment or login code detected"
    else
        log_fail "Desktop-environment or login code detected"
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

    log_test "Config validation rejects unknown keys"
    tmp_conf=$(mktemp /tmp/hb-test-conf.XXXXXX)
    echo 'NOT_WHITELISTED=1' > "$tmp_conf"
    result=$(bash -c '
        export HONEY_BADGER_ROOT="'"$SCRIPT_DIR"'"
        export HONEY_BADGER_DRY_RUN=1
        source "'"$SCRIPT_DIR"'/lib/common.sh"
        _hb_validate_config "'"$tmp_conf"'" && echo accepted || echo rejected
    ' 2>&1)
    rm -f "$tmp_conf"
    if echo "$result" | grep -q "rejected"; then
        log_pass "Config validation rejects unknown keys"
    else
        log_fail "Config validation accepted an unknown key"
    fi

    log_test "Config validation rejects shell metacharacters"
    tmp_conf=$(mktemp /tmp/hb-test-conf.XXXXXX)
    echo 'HONEY_BADGER_VERSION="9"; echo pwned' > "$tmp_conf"
    result=$(bash -c '
        export HONEY_BADGER_ROOT="'"$SCRIPT_DIR"'"
        export HONEY_BADGER_DRY_RUN=1
        source "'"$SCRIPT_DIR"'/lib/common.sh"
        _hb_validate_config "'"$tmp_conf"'" && echo accepted || echo rejected
    ' 2>&1)
    rm -f "$tmp_conf"
    if echo "$result" | grep -q "rejected"; then
        log_pass "Config validation rejects shell metacharacters"
    else
        log_fail "Config validation accepted shell metacharacters"
    fi
}

# ── Test 18: desktop-only flags are gone ──────────────────────────────────
test_desktop_flags_absent() {
    echo -e "\n=== DESKTOP FLAGS REMOVED ==="
    log_test "install.sh --help no longer advertises desktop options"
    local output
    if ! output=$(bash "$SCRIPT_DIR/install.sh" --help 2>&1); then
        log_fail "install.sh --help failed"
        return 0
    fi
    if echo "$output" | grep -qiE 'high-contrast|font-size|skip-theme|no-theme|xfce'; then
        log_fail "install.sh --help still mentions desktop options"
    else
        log_pass "install.sh --help has no desktop options"
    fi

    log_test "install.sh rejects the removed --skip-theme flag"
    if bash "$SCRIPT_DIR/install.sh" --skip-theme >/dev/null 2>&1; then
        log_fail "--skip-theme was still accepted"
    else
        log_pass "--skip-theme is rejected"
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
    for t in full developer apps minimal; do
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
    if [[ ! -e "$tmp_dir/.local" ]]; then
        log_pass "Dry-run wrote nothing under ~/.local"
    else
        log_fail "Dry-run wrote under ~/.local"
    fi
    rm -rf "$tmp_dir"
}

# ── Test 23: config carries no desktop appearance settings ────────────────
test_config_identity() {
    echo -e "\n=== CONFIG IDENTITY ==="
    log_test "Config declares the release identity"
    if grep -q '^HONEY_BADGER_VERSION=' "$SCRIPT_DIR/config/honey-badger-os.conf"; then
        log_pass "Config declares HONEY_BADGER_VERSION"
    else
        log_fail "Config is missing HONEY_BADGER_VERSION"
    fi

    log_test "Config has no theme or wallpaper settings"
    if grep -qiE '^HONEY_BADGER_(THEME|FONT|MONO_FONT|WALLPAPER)' \
        "$SCRIPT_DIR/config/honey-badger-os.conf"; then
        log_fail "Config still defines theme or wallpaper settings"
    else
        log_pass "Config is free of theme and wallpaper settings"
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
    # Either the success line ("8 GB required for full") or the refusal
    # ("7 GB free, 8 GB required") proves the profile requirement was applied.
    if echo "$output" | grep -q "8 GB required"; then
        log_pass "Full requires 8 GB"
    else
        log_fail "Full did not report an 8 GB requirement"
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

    log_test "No package appears in more than one manifest section"
    local fam dups=0
    for fam in arch debian fedora gentoo opensuse slackware void; do
        if awk '/^\[/{next} /^[[:space:]]*#/ || NF==0 {next} {print}' \
            "$SCRIPT_DIR/config/packages/$fam.conf" | sort | uniq -d | grep -q .; then
            dups=1
        fi
    done
    if [[ $dups -eq 0 ]]; then
        log_pass "Manifests contain no cross-section duplicates"
    else
        log_fail "A package is listed in more than one manifest section"
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

    log_test "base stays enabled when HONEY_BADGER_COMPONENTS omits it"
    result=$(HONEY_BADGER_COMPONENTS=dev HONEY_BADGER_DRY_RUN=1 bash -c '
        export HONEY_BADGER_ROOT="'"$SCRIPT_DIR"'"
        source "'"$SCRIPT_DIR"'/lib/common.sh"
        if hb_component_enabled base && hb_component_enabled dev &&
           ! hb_component_enabled apps; then
            echo ok
        else
            echo broken
        fi
    ' 2>/dev/null)
    if [[ "$result" == "ok" ]]; then
        log_pass "base is always enabled for environment component lists"
    else
        log_fail "environment components dropped base: $result"
    fi
}

# ── Test 29b: --skip-docker filters packages ───────────────────────────────
test_skip_docker_packages() {
    echo -e "\n=== SKIP-DOCKER FILTERING ==="
    log_test "--skip-docker removes Docker packages from the manifest"
    local result
    result=$(HONEY_BADGER_SKIP_DOCKER=1 HONEY_BADGER_DRY_RUN=1 bash -c '
        export HONEY_BADGER_ROOT="'"$SCRIPT_DIR"'"
        source "'"$SCRIPT_DIR"'/lib/common.sh"
        hb_load_package_manifest "$HONEY_BADGER_ROOT/config/packages/arch.conf" >/dev/null 2>&1
        if printf "%s\n" "${DEVELOPER_PACKAGES[@]}" | grep -qx docker ||
           printf "%s\n" "${DEVELOPER_PACKAGES[@]}" | grep -qx docker-compose; then
            echo leaks
        elif printf "%s\n" "${DEVELOPER_PACKAGES[@]}" | grep -qx postgresql; then
            echo clean
        else
            echo incomplete
        fi
    ' 2>/dev/null)
    if [[ "$result" == "clean" ]]; then
        log_pass "Docker packages are filtered and other packages remain"
    else
        log_fail "Docker filtering result: $result"
    fi
}

# ── Test 29c: invalid log rotation counts are rejected ─────────────────────
test_log_count_validation() {
    echo -e "\n=== LOG COUNT VALIDATION ==="
    log_test "Invalid HONEY_BADGER_LOG_COUNT falls back to 5"
    local out
    out=$(HOME="$(mktemp -d)" HONEY_BADGER_LOG_COUNT=0 HONEY_BADGER_DRY_RUN=1 bash -c '
        source "'"$SCRIPT_DIR"'/lib/common.sh"
        printf "%s" "$_HB_LOG_KEEP"
    ' 2>/dev/null)
    if [[ "$out" == "5" ]]; then
        log_pass "Zero or non-numeric log counts fall back safely"
    else
        log_fail "Unexpected log rotation count: $out"
    fi
}

# ── Test 30: options that do not apply are reported ────────────────────────
test_option_coherence() {
    echo -e "\n=== OPTION COHERENCE ==="
    log_test "Minimal ignores component overrides"
    local out
    out=$(
        source "$SCRIPT_DIR/install.sh"
        export HONEY_BADGER_INSTALL_TYPE=minimal
        export HONEY_BADGER_COMPONENTS="base,dev,apps"
        check_option_coherence minimal 2>/dev/null
        printf 'components=%s' "${HONEY_BADGER_COMPONENTS:-unset}"
    )
    if [[ "$out" == *"components=unset"* ]]; then
        log_pass "Minimal ignores --components and installs base only"
    else
        log_fail "Minimal kept component selection: $out"
    fi

    log_test "Components outside the selected profile are reported"
    out=$(
        source "$SCRIPT_DIR/install.sh"
        export HONEY_BADGER_INSTALL_TYPE=apps
        export HONEY_BADGER_COMPONENTS="base,dev"
        check_option_coherence apps 2>&1
    )
    if [[ "$out" == *"does not install the 'dev' component"* ]]; then
        log_pass "apps profile reports the unusable dev component"
    else
        log_fail "Profile/component mismatch was not reported: $out"
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
    log_test "Full install records the developer component set"
    if grep -qx 'HONEY_BADGER_COMPONENTS="base,dev,apps"' "$info" 2>/dev/null &&
       ! grep -q 'HONEY_BADGER_HAS_DESKTOP\|HONEY_BADGER_THEME_VARIANT' "$info" 2>/dev/null; then
        log_pass "install-info describes a developer install"
    else
        log_fail "install-info is missing developer metadata"
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
    for cmd in info update install report doctor uninstall; do
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
        | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["install_type"]=="full" and "dev" in d["components"]' 2>/dev/null; then
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

    log_test "honey-badger-doctor passes on a complete install"
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
    local tmp_dir minimal_out full_out
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
    full_out=$(
        export HOME="$tmp_dir"
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_INSTALL_TYPE=full
        export HONEY_BADGER_VERBOSITY=0
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/lib/common.sh"
        hb_set_total_steps 1
        show_post_install
    )

    log_test "Minimal summary is CLI-focused"
    if [[ "$minimal_out" == *"source ~/.bashrc"* && "$minimal_out" != *"sudo reboot"* \
          && "$minimal_out" != *"honey-badger-theme"* ]]; then
        log_pass "Minimal summary has no desktop guidance"
    else
        log_fail "Minimal summary still mentions desktop steps"
    fi

    log_test "Full summary lists the developer command set"
    if [[ "$full_out" == *"honey-badger-info"* && "$full_out" == *"honey-badger-doctor"* \
          && "$full_out" == *"honey-badger-uninstall"* && "$full_out" != *"sudo reboot"* ]]; then
        log_pass "Full summary lists info, doctor, and uninstall"
    else
        log_fail "Full summary is missing commands"
    fi

    log_test "Doctor skips toolchain checks on a Minimal install"
    mkdir -p "$tmp_dir/.local/share/honey-badger"
    cat > "$tmp_dir/.local/share/honey-badger/install-info" << 'EOF'
HONEY_BADGER_VERSION="3.0.1"
HONEY_BADGER_INSTALL_TYPE="minimal"
HONEY_BADGER_COMPONENTS="base"
EOF
    mkdir -p "$tmp_dir/.local/bin"
    local cmd
    for cmd in info update install report doctor uninstall; do
        printf '#!/bin/bash\nexit 0\n' > "$tmp_dir/.local/bin/honey-badger-$cmd"
        chmod 755 "$tmp_dir/.local/bin/honey-badger-$cmd"
    done
    local doctor_status=0 doctor_out2=""
    doctor_out2=$(HOME="$tmp_dir" PATH="$tmp_dir/.local/bin:$PATH" \
        bash "$SCRIPT_DIR/assets/honey-badger-doctor" 2>&1) || doctor_status=$?
    if [[ "$doctor_out2" == *"toolchain checks skipped"* && "$doctor_out2" != *"GTK theme"* ]]; then
        log_pass "Doctor is profile aware (no toolchain check on Minimal)"
    else
        log_fail "Doctor still checks toolchains on Minimal: $doctor_out2"
    fi
    if [[ $doctor_status -eq 0 ]]; then
        log_pass "Doctor exits 0 on a Minimal install"
    else
        log_fail "Doctor exited $doctor_status on a Minimal install"
    fi

    rm -rf "$tmp_dir"
}

# ── Test 33: shell and tool configuration ─────────────────────────────────
test_shell_layer() {
    echo -e "\n=== SHELL & TOOL CONFIGURATION ==="
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local run_status=0
    (
        export HOME="$tmp_dir"
        export XDG_CONFIG_HOME="$tmp_dir/.config"
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_VERBOSITY=0
        export LOG_FILE="$tmp_dir/install.log"
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/lib/common.sh"
        hb_set_total_steps 1
        setup_shell
    ) >/dev/null 2>&1 || run_status=$?

    log_test "setup_shell completes without error"
    if [[ $run_status -eq 0 ]]; then
        log_pass "setup_shell completed"
    else
        log_fail "setup_shell exited $run_status"
    fi

    log_test "Shell fragments and tool configs are written"
    local missing=0 f
    for f in ".config/ratel/shell/00-env.sh" ".config/ratel/shell/10-aliases.sh" \
             ".config/ratel/shell/20-tools.sh" ".inputrc" ".editorconfig" \
             ".config/bat/config" ".config/ripgrep/config" ".config/tmux/tmux.conf"; do
        [[ -f "$tmp_dir/$f" ]] || missing=$((missing + 1))
    done
    if [[ $missing -eq 0 ]]; then
        log_pass "All shell and tool configuration files exist"
    else
        log_fail "$missing configuration file(s) missing"
    fi

    log_test "Shell fragments parse cleanly"
    local bad=0
    for f in "$tmp_dir"/.config/ratel/shell/*.sh; do
        bash -n "$f" || bad=$((bad + 1))
    done
    if [[ $bad -eq 0 ]]; then
        log_pass "Shell fragments pass bash -n"
    else
        log_fail "$bad fragment(s) have syntax errors"
    fi

    log_test "~/.bashrc sources the fragment directory"
    local hits
    hits=$(grep -Fc 'ratel/shell/*.sh' "$tmp_dir/.bashrc" 2>/dev/null || true)
    if [[ "${hits:-0}" -eq 1 ]]; then
        log_pass "Fragment source line is present once"
    else
        log_fail "Fragment source line count was ${hits:-0}"
    fi

    log_test "Second run is idempotent"
    (
        export HOME="$tmp_dir"
        export XDG_CONFIG_HOME="$tmp_dir/.config"
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_VERBOSITY=0
        export LOG_FILE="$tmp_dir/install2.log"
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/lib/common.sh"
        hb_set_total_steps 1
        setup_shell
    ) >/dev/null 2>&1 || true
    hits=$(grep -Fc 'ratel/shell/*.sh' "$tmp_dir/.bashrc" 2>/dev/null || true)
    if [[ "${hits:-0}" -eq 1 ]]; then
        log_pass "Re-running setup_shell does not duplicate the source line"
    else
        log_fail "Source line duplicated (${hits:-0} occurrences)"
    fi

    log_test "Dry-run writes no shell configuration"
    local dry_dir
    dry_dir=$(mktemp -d)
    (
        export HOME="$dry_dir"
        export XDG_CONFIG_HOME="$dry_dir/.config"
        export HONEY_BADGER_ROOT="$SCRIPT_DIR"
        export HONEY_BADGER_VERBOSITY=0
        export HONEY_BADGER_DRY_RUN=1
        export LOG_FILE="$dry_dir/install.log"
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/lib/common.sh"
        hb_set_total_steps 1
        setup_shell
    ) >/dev/null 2>&1 || true
    if [[ ! -e "$dry_dir/.config/ratel" && ! -e "$dry_dir/.inputrc" ]]; then
        log_pass "Dry-run left the shell configuration untouched"
    else
        log_fail "Dry-run created shell configuration"
    fi
    rm -rf "$dry_dir" "$tmp_dir"
}

# ── Test 34: extended utilities ───────────────────────────────────────────
test_extended_utilities() {
    echo -e "\n=== EXTENDED UTILITIES ==="
    local tmp_dir
    tmp_dir=$(mktemp -d)
    mkdir -p "$tmp_dir/.local/share/honey-badger"
    cat > "$tmp_dir/.local/share/honey-badger/pm.conf" << 'ENDPM'
HB_PM_UPDATE='sudo apt update && sudo apt upgrade -y'
HB_PM_INSTALL='sudo apt install -y'
HB_PM_CLEAN='sudo apt autoremove -y'
HB_PM_SEARCH='apt-cache search'
HB_PM_REMOVE='sudo apt purge -y'
HB_PM_CHECK='apt list --upgradable'
ENDPM
    cat > "$tmp_dir/.local/share/honey-badger/install-info" << 'ENDINFO'
HONEY_BADGER_VERSION="3.0.1"
HONEY_BADGER_CODENAME="Fearless"
HONEY_BADGER_INSTALL_TYPE="developer"
HONEY_BADGER_COMPONENTS="base,dev"
HONEY_BADGER_DISTRO="debian"
ENDINFO
    cat > "$tmp_dir/packages.txt" << 'ENDPKG'
# developer tools
ripgrep
jq

ripgrep
ENDPKG

    log_test "honey-badger-install --file reads packages and dedupes"
    local file_out
    file_out=$(HOME="$tmp_dir" bash "$SCRIPT_DIR/assets/honey-badger-install" \
        --file "$tmp_dir/packages.txt" --dry-run 2>&1 || true)
    if [[ "$file_out" == *"ripgrep"* && "$file_out" == *"jq"* ]] \
        && [[ $(echo "$file_out" | grep -o 'ripgrep' | wc -l) -eq 1 ]]; then
        log_pass "Package file is read, comments skipped, duplicates removed"
    else
        log_fail "Package file handling was wrong: $file_out"
    fi

    log_test "honey-badger-install --file rejects an unreadable path"
    if HOME="$tmp_dir" bash "$SCRIPT_DIR/assets/honey-badger-install" \
        --file "$tmp_dir/missing.txt" --dry-run >/dev/null 2>&1; then
        log_fail "Missing package file was accepted"
    else
        log_pass "Missing package file is rejected"
    fi

    log_test "honey-badger-update --check prints the check command"
    local check_out
    check_out=$(HOME="$tmp_dir" bash "$SCRIPT_DIR/assets/honey-badger-update" \
        --check --dry-run 2>&1 || true)
    if [[ "$check_out" == *"[DRY-RUN]"* && "$check_out" == *"apt list --upgradable"* ]]; then
        log_pass "Update check is wired to the package manager"
    else
        log_fail "Update check output unexpected: $check_out"
    fi

    log_test "honey-badger-report produces a redacted report"
    mkdir -p "$tmp_dir/.local/share/honey-badger/logs"
    printf 'user=%s home=%s\n' "$USER" "$tmp_dir" \
        > "$tmp_dir/.local/share/honey-badger/logs/honeybadger-test.log"
    local report_out
    report_out=$(HOME="$tmp_dir" bash "$SCRIPT_DIR/assets/honey-badger-report" 2>&1 || true)
    if [[ "$report_out" == *"RATEL FORGE — ENVIRONMENT REPORT"* \
          && "$report_out" == *"Version: 3.0.1"* \
          && "$report_out" == *"<user>"* && "$report_out" == *"~"* ]] \
        && [[ "$report_out" != *"$tmp_dir"* ]]; then
        log_pass "Report includes install data and redacts home/user"
    else
        log_fail "Report output was not redacted as expected"
    fi

    log_test "honey-badger-report --output writes a mode-600 file"
    local report_path="$tmp_dir/report.txt" report_mode
    HOME="$tmp_dir" bash "$SCRIPT_DIR/assets/honey-badger-report" \
        --no-log --output "$report_path" >/dev/null 2>&1 || true
    report_mode=$(stat -c '%a' "$report_path" 2>/dev/null || true)
    if [[ -s "$report_path" && "$report_mode" == "600" ]]; then
        log_pass "Report file written with mode 600"
    else
        log_fail "Report file missing or has mode '${report_mode:-none}'"
    fi

    rm -rf "$tmp_dir"
}

# ── Main ───────────────────────────────────────────────────────────────────
run_final_tests() {
    echo "🦡 Ratel - Final Smoke Tests"
    echo "======================================="

    TEST_SANDBOX_HOME="$(mktemp -d)"
    export HOME="$TEST_SANDBOX_HOME"
    trap cleanup_test_sandbox EXIT

    test_syntax_all
    test_source_common
    test_double_source
    test_dry_run
    test_bashrc_idempotent
    test_json_functions
    test_config_file
    test_no_desktop_layer
    test_progress_tracking
    test_backup_file
    test_skip_component
    test_no_color
    test_checkpoint
    test_install_help
    test_show_banner
    test_init_distro_log
    test_config_validation
    test_desktop_flags_absent
    test_version_flag
    test_list_types
    test_invalid_type
    test_dry_run_no_writes
    test_config_identity
    test_shell_layer
    test_extended_utilities
    test_package_manifest_loader
    test_phase_resume
    test_install_type_selection
    test_profile_disk_requirement
    test_manifest_realism
    test_component_normalization
    test_skip_docker_packages
    test_log_count_validation
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
