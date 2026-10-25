#!/bin/bash
# shellcheck disable=SC2034  # Variables are consumed by the sourcing script
# shellcheck disable=SC2088  # Tilde strings are human-readable labels, not paths
# Ratel Forge - Shell and developer-tool configuration layer
# ---------------------------------------------------------------------------
# Writes user-level shell fragments, readline settings, and configuration for
# CLI tools (bat, ripgrep, tmux, EditorConfig). It never touches login files,
# PAM, /etc/profile, or anything that changes how the system logs in.
#
# Sourced by lib/common.sh; do not source directly.
# ---------------------------------------------------------------------------

# Prevent double-sourcing
[[ -n "${_HB_SHELL_LOADED:-}" ]] && return 0
readonly _HB_SHELL_LOADED=1

# shellcheck disable=SC2016  # expanded by the user's shell, not at install time
_HB_SHELL_SOURCE_LINE='for f in "${XDG_CONFIG_HOME:-$HOME/.config}"/ratel/shell/*.sh; do [ -r "$f" ] && . "$f"; done'

# ── Shell configuration orchestrator ────────────────────────────────────────
setup_shell() {
    hb_next_step "Configuring shell and developer tool settings..."

    if hb_dry_run; then
        log_info "[DRY-RUN] Would install shell fragments and CLI tool configuration"
        return 0
    fi

    if hb_skip_component "shell"; then
        log_info "Skipping shell configuration (--skip-shell)"
        return 0
    fi

    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    _hb_write_shell_fragments "$config_home/ratel/shell"
    _hb_write_readline_config
    _hb_write_tool_configs "$config_home"

    ensure_bashrc_line "# Ratel Forge shell configuration"
    ensure_bashrc_line "$_HB_SHELL_SOURCE_LINE"

    hb_json_add_config "~/.config/ratel/shell"
    hb_json_add_config "~/.inputrc"
    if [[ "${SHELL##*/}" != "bash" ]]; then
        log_info "Shell fragments target bash; ${SHELL##*/} was not modified"
    fi
    log_success "Shell and tool configuration installed"
}

# ── Shell fragments ─────────────────────────────────────────────────────────
# Kept in one directory so removal is a single directory delete instead of
# pattern-matching an unknown number of lines in ~/.bashrc.
_hb_write_shell_fragments() {
    local shell_dir="$1"
    mkdir -p "$shell_dir"

    cat > "$shell_dir/00-env.sh" << 'ENDENV'
# Ratel Forge — environment defaults
export LESS="-R -F -X"
export PAGER="${PAGER:-less}"
export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/ripgrep/config"
export BAT_CONFIG_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/bat/config"
ENDENV

    cat > "$shell_dir/10-aliases.sh" << 'ENDALIASES'
# Ratel Forge — interactive shell aliases
[[ $- == *i* ]] || return 0

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias gco='git checkout'
alias gb='git branch'
alias ...='cd ../..'

return 0
ENDALIASES

    cat > "$shell_dir/20-tools.sh" << 'ENDTOOLS'
# Ratel Forge — hooks for installed CLI tools (all optional)
[[ $- == *i* ]] || return 0

if command -v fzf >/dev/null 2>&1; then
    for _hb_fzf in /usr/share/fzf/key-bindings.bash \
                    /usr/share/fzf/shell/key-bindings.bash \
                    /usr/share/doc/fzf/examples/key-bindings.bash; do
        if [ -r "$_hb_fzf" ]; then
            . "$_hb_fzf"
            break
        fi
    done
    unset _hb_fzf
fi

if command -v zoxide >/dev/null 2>&1; then
    source <(zoxide init bash)
fi

if command -v direnv >/dev/null 2>&1; then
    source <(direnv hook bash)
fi

return 0
ENDTOOLS
}

# ── Readline ────────────────────────────────────────────────────────────────
_hb_write_readline_config() {
    local inputrc="$HOME/.inputrc"
    hb_backup_file "$inputrc"
    {
        printf '# Managed by Ratel Forge\n'
        # shellcheck disable=SC2016  # readline directive, not shell expansion
        [[ -r /etc/inputrc ]] && printf '$include /etc/inputrc\n'
        cat << 'ENDINPUTRC'
set completion-ignore-case on
set show-all-if-ambiguous on
set colored-stats on
"\e[A": history-search-backward
"\e[B": history-search-forward
ENDINPUTRC
    } > "$inputrc"
}

# ── Tool configuration files ────────────────────────────────────────────────
_hb_write_tool_configs() {
    local config_home="$1"
    local bat_dir="$config_home/bat"
    local rg_dir="$config_home/ripgrep"
    local tmux_dir="$config_home/tmux"

    mkdir -p "$bat_dir" "$rg_dir" "$tmux_dir"

    hb_backup_file "$bat_dir/config"
    cat > "$bat_dir/config" << 'ENDBAT'
# Managed by Ratel Forge
--theme="TwoDark"
--style="numbers,changes,header"
--paging=auto
ENDBAT

    hb_backup_file "$rg_dir/config"
    cat > "$rg_dir/config" << 'ENDRG'
# Managed by Ratel Forge
--smart-case
--hidden
--glob=!.git/*
ENDRG

    hb_backup_file "$tmux_dir/tmux.conf"
    cat > "$tmux_dir/tmux.conf" << 'ENDTMUX'
# Managed by Ratel Forge (tmux 3.1+ reads ~/.config/tmux/tmux.conf)
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
ENDTMUX

    hb_backup_file "$HOME/.editorconfig"
    cat > "$HOME/.editorconfig" << 'ENDEDITORCONFIG'
# Managed by Ratel Forge
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 4

[*.{js,jsx,ts,tsx,json,yml,yaml,css,scss,html,md}]
indent_size = 2

[Makefile]
indent_style = tab

[*.go]
indent_style = tab
ENDEDITORCONFIG

    hb_json_add_config "~/.config/bat/config"
    hb_json_add_config "~/.config/ripgrep/config"
    hb_json_add_config "~/.config/tmux/tmux.conf"
    hb_json_add_config "~/.editorconfig"
}
