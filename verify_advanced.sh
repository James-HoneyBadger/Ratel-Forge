#!/bin/bash
# Advanced Ratel Forge Script Verification
# Tests for runtime functionality, security, and potential issues

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[0;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

PASSED_TESTS=0
FAILED_TESTS=0

log_test() {
    echo -e "${CYAN}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASSED_TESTS=$((PASSED_TESTS + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ── Security scanning ───────────────────────────────────────────────────────
test_security() {
    echo -e "\n=== SECURITY SCANNING ==="

    # S1: eval injection
    log_test "No eval usage in scripts"
    local eval_found=false
    for script in distros/*/install-*.sh lib/*.sh; do
        if grep -nE '^\s*eval\s' "$script" 2>/dev/null; then
            log_fail "eval found in $(basename "$script")"
            eval_found=true
        fi
    done
    if ! $eval_found; then
        log_pass "No eval injection vectors found"
    fi

    # S2: curl|bash pattern
    log_test "No curl|bash (download-and-execute) patterns"
    local curl_bash_found=false
    for script in distros/*/install-*.sh lib/*.sh; do
        if grep -nE 'curl.*\|\s*(sudo\s+)?bash|wget.*\|\s*(sudo\s+)?bash' "$script" 2>/dev/null; then
            log_fail "curl|bash found in $(basename "$script")"
            curl_bash_found=true
        fi
    done
    if ! $curl_bash_found; then
        log_pass "No curl|bash patterns found"
    fi

    # S3: World-writable temp files
    log_test "No insecure temp file usage"
    local insecure_tmp=false
    for script in distros/*/install-*.sh lib/*.sh; do
        # Flag: writing to /tmp with predictable names without mktemp
        if grep -nE '>/tmp/[a-zA-Z]' "$script" 2>/dev/null | grep -v 'LOG_FILE\|honeybadger-' >/dev/null 2>&1; then
            log_warn "Predictable /tmp file in $(basename "$script")"
            insecure_tmp=true
        fi
    done
    if ! $insecure_tmp; then
        log_pass "Temp files use mktemp or honeybadger- prefix"
    fi

    # S4: chmod 777
    log_test "No chmod 777 usage"
    local chmod_777=false
    for script in distros/*/install-*.sh lib/*.sh install.sh; do
        if grep -nE 'chmod\s+777' "$script" 2>/dev/null; then
            log_fail "chmod 777 in $(basename "$script")"
            chmod_777=true
        fi
    done
    if ! $chmod_777; then
        log_pass "No chmod 777 usage"
    fi

    # S5: Unverified downloads
    log_test "Downloads use verification (checksums, gpg, or https)"
    local unverified=false
    for script in distros/*/install-*.sh lib/*.sh; do
        if grep -nE 'curl.*http://' "$script" 2>/dev/null | grep -v '#' >/dev/null 2>&1; then
            log_warn "HTTP (non-HTTPS) download in $(basename "$script")"
            unverified=true
        fi
    done
    if ! $unverified; then
        log_pass "All downloads use HTTPS"
    fi

    # S6: sudo rm -rf /
    log_test "No dangerous recursive delete on root"
    local danger_rm=false
    for script in distros/*/install-*.sh lib/*.sh install.sh; do
        if grep -nE 'rm\s+(-rf|-fr)\s+/\s*$' "$script" 2>/dev/null; then
            log_fail "Dangerous rm -rf / in $(basename "$script")"
            danger_rm=true
        fi
    done
    if ! $danger_rm; then
        log_pass "No dangerous recursive deletes"
    fi
}

# ── Package name validation ─────────────────────────────────────────────────
test_package_names() {
    echo -e "\n=== PACKAGE NAME VALIDATION ==="

    log_test "Checking for common package name typos"
    local typos=(
        "\\<firefx\\>" "\\<chronium\\>" "\\<libreofice\\>" "\\<thunderbrd\\>"
        "\\<pytho\\>" "\\<nodjs\\>" "\\<vs-code\\>" "\\<vscoe\\>"
    )
    local found_typos=false
    for script in distros/*/install-*.sh; do
        for typo in "${typos[@]}"; do
            if grep -Eqi "$typo" "$script" 2>/dev/null; then
                log_fail "Possible typo in $(basename "$script"): $typo"
                found_typos=true
            fi
        done
    done
    if ! $found_typos; then
        log_pass "No common typos detected in package names"
    fi
}

# ── Sudo usage patterns ─────────────────────────────────────────────────────
test_sudo_usage() {
    echo -e "\n=== SUDO USAGE VALIDATION ==="

    log_test "Checking for unsafe sudo patterns"
    local unsafe_patterns=(
        "sudo[[:space:]].*rm[[:space:]].*-rf[[:space:]]+/$"
        "sudo[[:space:]].*chmod[[:space:]].*777"
        "sudo[[:space:]].*chown[[:space:]].*-R[[:space:]].* /$"
    )
    local found_unsafe=false
    for script in distros/*/install-*.sh lib/*.sh; do
        for pattern in "${unsafe_patterns[@]}"; do
            if grep -Eq "$pattern" "$script" 2>/dev/null; then
                log_fail "Unsafe sudo pattern in $(basename "$script")"
                found_unsafe=true
            fi
        done
    done
    if ! $found_unsafe; then
        log_pass "No unsafe sudo patterns detected"
    fi

    log_test "Distro scripts use hb_sudo wrapper"
    local using_hb_sudo=0
    for script in distros/*/install-*.sh; do
        if grep -q "hb_sudo" "$script"; then
            using_hb_sudo=$((using_hb_sudo + 1))
        fi
    done
    local total_distros
    total_distros=$(find distros/*/install-*.sh -maxdepth 0 2>/dev/null | wc -l | tr -d ' ')
    if [[ $using_hb_sudo -eq $total_distros ]]; then
        log_pass "All $total_distros distro scripts use hb_sudo wrapper"
    else
        log_fail "Only $using_hb_sudo/$total_distros distro scripts use hb_sudo"
    fi
}

# ── Service management ──────────────────────────────────────────────────────
test_service_management() {
    echo -e "\n=== SERVICE MANAGEMENT VALIDATION ==="

    log_test "Checking for service management in distro scripts"
    local has_service_mgmt=0
    for script in distros/*/install-*.sh; do
        if grep -q "systemctl\|sv\|rc\.d\|runit\|enable_runit" "$script"; then
            has_service_mgmt=$((has_service_mgmt + 1))
        fi
    done
    if [[ $has_service_mgmt -gt 0 ]]; then
        log_pass "$has_service_mgmt scripts manage services"
    else
        log_warn "No scripts manage services"
    fi
}

# ── Environment variable handling ────────────────────────────────────────────
test_environment_handling() {
    echo -e "\n=== ENVIRONMENT VARIABLE HANDLING ==="

    log_test "Checking for default value handling"
    local scripts_with_defaults=0
    for script in distros/*/install-*.sh lib/*.sh; do
        if grep -q '\${.*:-.*}' "$script"; then
            scripts_with_defaults=$((scripts_with_defaults + 1))
        fi
    done
    if [[ $scripts_with_defaults -gt 0 ]]; then
        log_pass "$scripts_with_defaults scripts use parameter expansion with defaults"
    else
        log_warn "No scripts use parameter expansion with defaults"
    fi
}

# ── Error handling robustness ────────────────────────────────────────────────
test_error_robustness() {
    echo -e "\n=== ERROR HANDLING ROBUSTNESS ==="

    log_test "Checking for command existence verification"
    local scripts_checking_commands=0
    for script in distros/*/install-*.sh lib/*.sh; do
        if grep -q "command -v" "$script"; then
            scripts_checking_commands=$((scripts_checking_commands + 1))
        fi
    done
    if [[ $scripts_checking_commands -gt 0 ]]; then
        log_pass "$scripts_checking_commands scripts verify command existence"
    else
        log_fail "No scripts verify command existence before use"
    fi

    log_test "Checking for trap handlers"
    local scripts_with_trap=0
    for script in distros/*/install-*.sh install.sh lib/*.sh; do
        if grep -q "trap " "$script"; then
            scripts_with_trap=$((scripts_with_trap + 1))
        fi
    done
    if [[ $scripts_with_trap -gt 0 ]]; then
        log_pass "$scripts_with_trap scripts have trap handlers"
    else
        log_warn "No scripts have trap handlers"
    fi

    log_test "Shared library has signal trap (INT/TERM)"
    if grep -qE "trap.*INT|trap.*TERM" lib/*.sh; then
        log_pass "shared library traps INT/TERM signals"
    else
        log_fail "shared library missing INT/TERM signal traps"
    fi
}

# ── File operations safety ───────────────────────────────────────────────────
test_file_operations() {
    echo -e "\n=== FILE OPERATIONS SAFETY ==="

    log_test "Checking for file existence verification"
    local scripts_checking_files=0
    for script in distros/*/install-*.sh lib/*.sh; do
        if grep -q '\[\[.*-f.*\]\]\|\[\[.*-d.*\]\]' "$script"; then
            scripts_checking_files=$((scripts_checking_files + 1))
        fi
    done
    if [[ $scripts_checking_files -gt 0 ]]; then
        log_pass "$scripts_checking_files scripts verify file/directory existence"
    else
        log_fail "No scripts verify file/directory existence"
    fi
}

# ── Installation type completeness ───────────────────────────────────────────
test_installation_completeness() {
    echo -e "\n=== INSTALLATION TYPE COMPLETENESS ==="

    local install_types=("full" "developer" "apps" "minimal")
    for install_type in "${install_types[@]}"; do
        log_test "Checking $install_type installation type support"
        local scripts_supporting=0
        for script in distros/*/install-*.sh; do
            if grep -q "\"$install_type\"" "$script"; then
                scripts_supporting=$((scripts_supporting + 1))
            fi
        done
        local total_distros
        total_distros=$(find distros/*/install-*.sh -maxdepth 0 2>/dev/null | wc -l | tr -d ' ')
        if [[ $scripts_supporting -eq $total_distros ]]; then
            log_pass "All $total_distros scripts support '$install_type'"
        elif [[ $scripts_supporting -gt 0 ]]; then
            log_warn "$scripts_supporting/$total_distros scripts support '$install_type'"
            log_fail "Not all scripts support '$install_type' type"
        else
            log_fail "No scripts support '$install_type' type"
        fi
    done
}

# ── JSON output support ─────────────────────────────────────────────────────
test_json_output() {
    echo -e "\n=== JSON OUTPUT SUPPORT ==="

    log_test "Distro scripts use JSON output functions"
    local json_support=0
    for script in distros/*/install-*.sh; do
        if grep -q "hb_json_init\|hb_json_write" "$script"; then
            json_support=$((json_support + 1))
        fi
    done
    local total_distros
    total_distros=$(find distros/*/install-*.sh -maxdepth 0 2>/dev/null | wc -l | tr -d ' ')
    if [[ $json_support -eq $total_distros ]]; then
        log_pass "All $total_distros distro scripts support JSON output"
    else
        log_fail "Only $json_support/$total_distros distro scripts support JSON output"
    fi
}

# ── Config backup & temp file registration ───────────────────────────────────
test_backup_and_temp_registration() {
    echo -e "\n=== BACKUP & TEMP FILE REGISTRATION ==="

    log_test "Shared library has hb_backup_file function"
    if grep -qE "^hb_backup_file\(\)" lib/*.sh; then
        log_pass "hb_backup_file is defined"
    else
        log_fail "hb_backup_file is not defined"
    fi

    log_test "Shared library has hb_register_temp function"
    if grep -qE "^hb_register_temp\(\)" lib/*.sh; then
        log_pass "hb_register_temp is defined"
    else
        log_fail "hb_register_temp is not defined"
    fi

    log_test "Distro scripts use hb_register_temp for temp files"
    local reg_count=0
    for script in distros/*/install-*.sh; do
        if grep -q "hb_register_temp" "$script"; then
            reg_count=$((reg_count + 1))
        fi
    done
    if [[ $reg_count -gt 0 ]]; then
        log_pass "$reg_count distro scripts register temp files"
    else
        log_warn "No distro scripts register temp files"
    fi

    log_test "Distro scripts never modify login or session configuration"
    if grep -qE '/etc/inittab|\.xinitrc|graphical\.target|lightdm|display-manager' \
        distros/*/install-*.sh 2>/dev/null; then
        log_fail "A provisioner modifies login or session configuration"
    else
        log_pass "No login or session configuration is modified"
    fi
}

# ── Color and verbosity control ──────────────────────────────────────────────
test_color_verbosity() {
    echo -e "\n=== COLOR & VERBOSITY CONTROL ==="

    log_test "Shared library supports NO_COLOR"
    if grep -q "NO_COLOR" lib/*.sh; then
        log_pass "shared library supports NO_COLOR standard"
    else
        log_fail "shared library missing NO_COLOR support"
    fi

    log_test "install.sh supports --no-color flag"
    if grep -q "\-\-no-color" install.sh; then
        log_pass "install.sh handles --no-color"
    else
        log_fail "install.sh missing --no-color flag"
    fi

    log_test "install.sh supports --verbose and --quiet flags"
    if grep -q "\-\-verbose" install.sh && grep -q "\-\-quiet" install.sh; then
        log_pass "install.sh handles --verbose and --quiet"
    else
        log_fail "install.sh missing verbosity flags"
    fi

    log_test "install.sh supports --help flag"
    if grep -q "\-\-help" install.sh; then
        log_pass "install.sh handles --help"
    else
        log_fail "install.sh missing --help flag"
    fi
}

# Main test runner
run_advanced_tests() {
    echo "🦡 Advanced Ratel Forge Script Verification"
    echo "==============================================="

    test_security
    test_package_names
    test_sudo_usage
    test_service_management
    test_environment_handling
    test_error_robustness
    test_file_operations
    test_installation_completeness
    test_json_output
    test_backup_and_temp_registration
    test_color_verbosity

    local TOTAL_TESTS=$((PASSED_TESTS + FAILED_TESTS))
    echo -e "\n==============================================="
    echo -e "Advanced Test Results:"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo -e "Total: $TOTAL_TESTS"

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}🦡 Advanced tests passed! Scripts are robust and ready.${NC}"
        return 0
    else
        echo -e "\n${YELLOW}🦡 Some advanced issues detected. Review above.${NC}"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_advanced_tests
fi
