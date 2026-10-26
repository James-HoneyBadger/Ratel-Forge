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
    local -a sections=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        line="${line%"${line##*[![:space:]]}"}"   # trim trailing whitespace

        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" =~ ^\[([A-Z0-9_]+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            sections+=("$section")
            declare -g -a "$section=()"
            continue
        fi

        [[ -n "$section" ]] || continue

        local -n manifest_ref="$section"
        manifest_ref+=("$line")
        unset -n manifest_ref
    done < "$manifest"

    if [[ "${HONEY_BADGER_SKIP_DOCKER:-0}" == "1" && ${#sections[@]} -gt 0 ]]; then
        local name entry
        local -a kept=()
        for name in "${sections[@]}"; do
            local -n manifest_packages_ref="$name"
            if [[ ${#manifest_packages_ref[@]} -gt 0 ]]; then
                kept=()
                for entry in "${manifest_packages_ref[@]}"; do
                    case "$entry" in
                        docker|docker.io|docker-ce|docker-ce-cli|docker-compose|\
                        */docker|*/docker-compose|app-containers/docker*)
                            continue
                            ;;
                    esac
                    kept+=("$entry")
                done
                manifest_packages_ref=(${kept[@]+"${kept[@]}"})
            fi
            unset -n manifest_packages_ref
        done
        log_info "Skipping Docker packages (--skip-docker)"
    fi

    log_debug "Loaded package manifest: $manifest"
}
