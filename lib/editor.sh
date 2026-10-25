#!/bin/bash
# shellcheck disable=SC2034  # Variables are consumed by the sourcing script
# shellcheck disable=SC2088  # Tilde strings are human-readable labels, not paths
# Ratel Forge - Editor configuration layer
# ---------------------------------------------------------------------------
# Nano setup and editor defaults.
#
# Sourced by lib/common.sh; do not source directly.
# ---------------------------------------------------------------------------

# Prevent double-sourcing
[[ -n "${_HB_EDITOR_LOADED:-}" ]] && return 0
readonly _HB_EDITOR_LOADED=1

# ── Nano setup ───────────────────────────────────────────────────────────────
setup_nano() {
    hb_next_step "Setting up enhanced nano configuration..."

    if hb_dry_run; then
        log_info "[DRY-RUN] Would install ~/.nanorc and editor defaults"
        return 0
    fi

    if hb_skip_component "nano"; then
        log_info "Skipping nano setup (--skip-nano)"
        return 0
    fi

    mkdir -p ~/.nano/backups

    if [[ -f "$HONEY_BADGER_ROOT/config/nanorc" ]]; then
        hb_backup_file "$HOME/.nanorc"
        cp "$HONEY_BADGER_ROOT/config/nanorc" ~/.nanorc
    else
        log_warning "nanorc configuration file not found"
    fi

    ensure_bashrc_line 'export EDITOR=nano'
    ensure_bashrc_line 'export VISUAL=nano'

    hb_json_add_config "~/.nanorc"
    log_success "Enhanced nano configuration installed"
}
