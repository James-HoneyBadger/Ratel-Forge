#!/bin/bash
# Ratel Forge Script Verification Tool
# Tests the installation scripts for common issues and potential problems

set -euo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[0;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

PASSED_TESTS=0
FAILED_TESTS=0

# log_test is purely informational — does NOT increment counters
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

# Test 1: Syntax validation
test_syntax() {
    echo -e "\n=== SYNTAX VALIDATION ==="

    log_test "Main installer script syntax"
    if bash -n install.sh 2>/dev/null; then
        log_pass "Main script syntax is valid"
    else
        log_fail "Main script has syntax errors"
    fi

    # Shared library modules
    for libfile in lib/*.sh; do
        log_test "Syntax check for $libfile"
        if bash -n "$libfile" 2>/dev/null; then
            log_pass "$libfile syntax is valid"
        else
            log_fail "$libfile has syntax errors"
        fi
    done

    for script in distros/*/install-*.sh; do
        local script_name=$(basename "$script")
        log_test "Syntax check for $script_name"
        if bash -n "$script" 2>/dev/null; then
            log_pass "$script_name syntax is valid"
        else
            log_fail "$script_name has syntax errors"
        fi
    done
}

# Test 2: File structure validation
test_file_structure() {
    echo -e "\n=== FILE STRUCTURE VALIDATION ==="

    log_test "Required directories exist"
    local required_dirs=("distros" "config" "theme" "assets" "lib" "completions")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_pass "Directory '$dir' exists"
        else
            log_fail "Required directory '$dir' is missing"
        fi
    done

    log_test "Shared library exists"
    if [[ -f "lib/common.sh" ]]; then
        log_pass "lib/common.sh exists"
    else
        log_fail "lib/common.sh is missing"
    fi

    log_test "Distribution scripts exist"
    local distros=("arch" "debian" "fedora" "gentoo" "opensuse" "slackware" "void")
    for distro in "${distros[@]}"; do
        local script="distros/$distro/install-$distro.sh"
        if [[ -f "$script" ]]; then
            log_pass "Script for $distro exists"
            if [[ -x "$script" ]]; then
                log_pass "Script for $distro is executable"
            else
                log_fail "Script for $distro is not executable"
            fi
        else
            log_fail "Script for $distro is missing"
        fi
    done

    log_test "Asset scripts are non-empty"
    for asset in assets/honey-badger-*; do
        local name=$(basename "$asset")
        if [[ -s "$asset" ]]; then
            log_pass "Asset '$name' is non-empty"
        else
            log_fail "Asset '$name' is empty (0 bytes)"
        fi
    done
}

# Test 3: Hardcoded paths check
test_hardcoded_paths() {
    echo -e "\n=== HARDCODED PATHS CHECK ==="

    log_test "Checking for hardcoded paths"
    local found_hardcoded=false

    if grep -r "/Users/daddy" distros/ lib/ >/dev/null 2>&1; then
        log_fail "Found hardcoded paths in scripts"
        found_hardcoded=true
    fi

    if grep -rn '/home/[a-z][a-z0-9_-]*/' distros/ lib/ 2>/dev/null | grep -v '\$HOME' | grep -v '#' >/dev/null 2>&1; then
        log_fail "Found potential hardcoded home paths"
        found_hardcoded=true
    fi

    if ! $found_hardcoded; then
        log_pass "No obvious hardcoded paths found"
    fi
}

# Test 4: Required functions exist
test_required_functions() {
    echo -e "\n=== REQUIRED FUNCTIONS CHECK ==="

    local main_functions=("main" "detect_distribution" "check_sudo" "run_preflight_checks")
    for func in "${main_functions[@]}"; do
        log_test "Main script has '$func' function"
        if grep -qE "^${func}\s*\(\)" install.sh; then
            log_pass "Function '$func' found in main script"
        else
            log_fail "Function '$func' missing from main script"
        fi
    done

    # Check distribution scripts have main function
    for script in distros/*/install-*.sh; do
        local script_name=$(basename "$script")
        log_test "$script_name has main function"
        if grep -qE "^main\s*\(\)" "$script"; then
            log_pass "$script_name has main function"
        else
            log_fail "$script_name missing main function"
        fi
    done

    # Check shared library has key functions
    if [[ -f lib/common.sh ]]; then
        log_test "Shared library key functions"
        local lib_funcs=("hb_sudo" "log_info" "log_success" "log_error" "setup_nano"
                         "setup_honey_badger_theme" "setup_xfce" "install_assets"
                         "setup_git" "setup_docker" "create_utility_scripts"
                         "show_post_install" "hb_json_init" "hb_json_write"
                         "ensure_bashrc_line" "is_noninteractive" "hb_next_step"
                         "hb_check_network" "hb_backup_file" "hb_acquire_lock"
                         "hb_register_temp" "hb_skip_component" "log_debug"
                         "hb_rollback_init" "hb_load_checkpoint" "hb_clear_checkpoint"
                         "hb_show_banner" "hb_init_distro_log" "hb_enable_service"
                         "hb_component_enabled" "hb_effective_components" "hb_desktop_enabled")
        for func in "${lib_funcs[@]}"; do
            if grep -qE "^${func}\s*\(\)" lib/common.sh lib/*.sh; then
                log_pass "shared library has '$func'"
            else
                log_fail "shared library missing '$func'"
            fi
        done
    fi
}

# Test 5: Package manager commands validation
test_package_managers() {
    echo -e "\n=== PACKAGE MANAGER VALIDATION ==="

    log_test "Arch script uses pacman"
    if grep -q "pacman" distros/arch/install-arch.sh; then
        log_pass "Arch script uses pacman"
    else
        log_fail "Arch script doesn't use pacman"
    fi

    log_test "Debian script uses apt"
    if grep -q "apt" distros/debian/install-debian.sh; then
        log_pass "Debian script uses apt"
    else
        log_fail "Debian script doesn't use apt"
    fi

    log_test "Fedora script uses dnf/yum"
    if grep -q "dnf\|yum" distros/fedora/install-fedora.sh; then
        log_pass "Fedora script uses dnf/yum"
    else
        log_fail "Fedora script doesn't use dnf/yum"
    fi

    log_test "Void script uses xbps"
    if grep -q "xbps" distros/void/install-void.sh; then
        log_pass "Void script uses xbps"
    else
        log_fail "Void script doesn't use xbps"
    fi

    log_test "Slackware script uses slackpkg"
    if grep -q "slackpkg" distros/slackware/install-slackware.sh; then
        log_pass "Slackware script uses slackpkg"
    else
        log_fail "Slackware script doesn't use slackpkg"
    fi
}

# Test 6: Environment variable usage
test_environment_variables() {
    echo -e "\n=== ENVIRONMENT VARIABLE USAGE ==="

    log_test "Scripts use HONEY_BADGER_INSTALL_TYPE"
    local scripts_using_var=0
    for script in distros/*/install-*.sh; do
        if grep -q "HONEY_BADGER_INSTALL_TYPE" "$script"; then
            scripts_using_var=$((scripts_using_var + 1))
        fi
    done

    local total_distros
    total_distros=$(find distros/*/install-*.sh -maxdepth 0 2>/dev/null | wc -l | tr -d ' ')
    if [[ $scripts_using_var -eq $total_distros ]]; then
        log_pass "All $total_distros distribution scripts use HONEY_BADGER_INSTALL_TYPE"
    elif [[ $scripts_using_var -gt 0 ]]; then
        log_warn "$scripts_using_var/$total_distros distribution scripts use HONEY_BADGER_INSTALL_TYPE"
        log_fail "Not all distro scripts use HONEY_BADGER_INSTALL_TYPE"
    else
        log_fail "No distribution scripts use HONEY_BADGER_INSTALL_TYPE"
    fi

    log_test "Main script sets environment variable"
    if grep -q "export HONEY_BADGER_INSTALL_TYPE" install.sh; then
        log_pass "Main script exports HONEY_BADGER_INSTALL_TYPE"
    else
        log_fail "Main script doesn't export HONEY_BADGER_INSTALL_TYPE"
    fi
}

# Test 7: Error handling
test_error_handling() {
    echo -e "\n=== ERROR HANDLING CHECK ==="

    log_test "Scripts use 'set -euo pipefail'"
    for script in install.sh lib/common.sh distros/*/install-*.sh; do
        local name=$(basename "$script")
        if head -10 "$script" | grep -q "set -euo pipefail"; then
            log_pass "$name uses proper error handling"
        else
            log_fail "$name missing 'set -euo pipefail'"
        fi
    done
}

# Test 8: Configuration files exist
test_config_files() {
    echo -e "\n=== CONFIGURATION FILES CHECK ==="

    local config_files=("config/nanorc" "config/honey-badger-os.conf")
    for config in "${config_files[@]}"; do
        log_test "Configuration file '$config' exists"
        if [[ -f "$config" ]]; then
            log_pass "Configuration file '$config' found"
        else
            log_fail "Configuration file '$config' missing"
        fi
    done
}

# Test 9: Shared library sourcing parity
test_shared_library_parity() {
    echo -e "\n=== SHARED LIBRARY PARITY ==="

    log_test "All distro scripts source lib/common.sh"
    for script in distros/*/install-*.sh; do
        local name=$(basename "$script")
        if grep -q "source.*lib/common.sh\|\..*lib/common.sh" "$script"; then
            log_pass "$name sources lib/common.sh"
        else
            log_fail "$name does not source lib/common.sh"
        fi
    done

    log_test "All distro scripts use hb_sudo"
    for script in distros/*/install-*.sh; do
        local name=$(basename "$script")
        if grep -q "hb_sudo" "$script"; then
            log_pass "$name uses hb_sudo"
        else
            log_fail "$name uses raw sudo instead of hb_sudo"
        fi
    done

    log_test "All distro scripts support all 4 install types"
    for script in distros/*/install-*.sh; do
        local name=$(basename "$script")
        local has_all=true
        for itype in full developer desktop minimal; do
            if ! grep -q "\"$itype\"" "$script"; then
                has_all=false
            fi
        done
        if $has_all; then
            log_pass "$name supports all 4 install types"
        else
            log_fail "$name missing some install types"
        fi
    done
}

# Test 10: New project files validation
test_new_project_files() {
    echo -e "\n=== NEW PROJECT FILES VALIDATION ==="

    local project_files=(
        ".github/workflows/ci.yml"
        "CHANGELOG.md"
        "CONTRIBUTING.md"
        "LICENSE"
        "completions/honey-badger.bash"
        "completions/honey-badger.zsh"
        "theme/index.theme"
        "theme/index-hc.theme"
        "theme/honey-badger-theme-hc.css"
        "assets/ratel-logo.svg"
        "lib/ui.sh"
        "lib/theme.sh"
        "lib/utilities.sh"
        "lib/packages.sh"
        "Makefile"
        "justfile"
        "schema/honeybadger-summary.schema.json"
        "scripts/lint-theme.py"
        "scripts/generate_theme_variants.py"
        "scripts/theme-screenshot.sh"
    )
    for pf in "${project_files[@]}"; do
        log_test "Project file '$pf' exists"
        if [[ -f "$pf" ]]; then
            log_pass "'$pf' exists"
        else
            log_fail "'$pf' is missing"
        fi
    done
}


# Test 11: Package manifests
test_package_manifests() {
    echo -e "\n=== PACKAGE MANIFEST VALIDATION ==="

    local families=(arch debian fedora gentoo opensuse slackware void)
    for family in "${families[@]}"; do
        local manifest="config/packages/${family}.conf"
        log_test "Manifest for $family exists and is structured"
        if [[ -s "$manifest" ]] && grep -q '^\[BASE_PACKAGES\]$' "$manifest"; then
            log_pass "$manifest has a BASE_PACKAGES section"
        else
            log_fail "$manifest is missing or malformed"
        fi

        log_test "$family provisioner loads its manifest"
        if grep -q "hb_load_package_manifest .*config/packages/${family}.conf" \
            "distros/${family}/install-${family}.sh"; then
            log_pass "$family provisioner loads $manifest"
        else
            log_fail "$family provisioner does not load its manifest"
        fi
    done
}

# Main test runner
run_all_tests() {
    echo "🦡 Ratel Forge Script Verification Tool"
    echo "============================================="

    test_syntax
    test_file_structure
    test_hardcoded_paths
    test_required_functions
    test_package_managers
    test_environment_variables
    test_error_handling
    test_config_files
    test_shared_library_parity
    test_new_project_files
    test_package_manifests

    local TOTAL_TESTS=$((PASSED_TESTS + FAILED_TESTS))
    echo -e "\n============================================="
    echo -e "Test Results:"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo -e "Total: $TOTAL_TESTS"

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}🦡 All tests passed! Scripts appear to be ready for deployment.${NC}"
        return 0
    else
        echo -e "\n${RED}🦡 Some tests failed. Please review the issues above.${NC}"
        return 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi
