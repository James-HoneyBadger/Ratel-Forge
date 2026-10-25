#!/bin/bash
# shellcheck disable=SC2034  # Arrays are consumed by the sourcing script
# Ratel Forge - Package manifest loader
# ---------------------------------------------------------------------------
# Package lists live in config/packages/<family>.conf so they can be reviewed
# and changed without editing shell logic.
#
# Manifest format:
#   [BASE_PACKAGES]         <- section, becomes an array of the same name
#   curl                    <- one entry per line
#   code --classic          <- entries may contain spaces
#
# Sourced by lib/common.sh; do not source directly.
# ---------------------------------------------------------------------------

# Prevent double-sourcing
[[ -n "${_HB_PACKAGES_LOADED:-}" ]] && return 0
readonly _HB_PACKAGES_LOADED=1

hb_load_package_manifest() {
    local manifest="$1"

    if [[ ! -r "$manifest" ]]; then
        log_warning "Package manifest not found: $manifest"
        return 1
    fi

    local section="" line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        line="${line%"${line##*[![:space:]]}"}"   # trim trailing whitespace

        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" =~ ^\[([A-Z0-9_]+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            declare -g -a "$section=()"
            continue
        fi

        [[ -n "$section" ]] || continue

        local -n manifest_ref="$section"
        manifest_ref+=("$line")
        unset -n manifest_ref
    done < "$manifest"

    log_debug "Loaded package manifest: $manifest"
}
