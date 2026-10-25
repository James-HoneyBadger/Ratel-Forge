#!/bin/bash
# Ratel Forge - Uninstall Script
# Removes Ratel Forge configurations and utility scripts using the rollback manifest.
# Does NOT remove system packages (use your distro's package manager for that).

set -euo pipefail

# ── Color support ────────────────────────────────────────────────────────────
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
else
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m'
    CYAN='\033[0;36m' BOLD='\033[1m' NC='\033[0m'
fi

log_info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ── Help ─────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat << 'EOF'
Usage: uninstall.sh [--dry-run]

Removes Ratel Forge customizations:
  • Utility commands (~/.local/bin/honey-badger-*)
  • Shell completion (~/.local/share/bash-completion/completions/honey-badger)
  • Theme files (~/.themes/Ratel, ~/.icons/Ratel, /usr/share/themes/Ratel)
  • Desktop appearance settings created by the installer
  • Nano configuration (~/.nanorc, ~/.nano/)
  • Restores backed-up config files (.hb-backup -> original)
  • Clears Ratel Forge data (~/.local/share/honey-badger/)

This script is also installed as `honey-badger-uninstall`, so removal works
without the Ratel Forge checkout.

Options:
  --dry-run   Show what would be removed without actually doing it
  --help      Show this help message

NOTE: System packages installed by Ratel Forge are NOT removed.
      Use your distribution's package manager to remove them.
EOF
    exit 0
fi

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# ── Confirmation ─────────────────────────────────────────────────────────────
echo -e "${BOLD}${YELLOW}🦡 Ratel Forge Uninstaller 🦡${NC}"
echo ""

if [[ $DRY_RUN -eq 1 ]]; then
    log_info "DRY-RUN MODE: showing what would be removed"
    echo ""
fi

if [[ $DRY_RUN -eq 0 ]]; then
    echo -e "${YELLOW}This will remove Ratel Forge customizations from your system.${NC}"
    echo -e "${YELLOW}System packages will NOT be removed.${NC}"
    echo ""
    echo -n "Continue? [y/N]: "
    read -r response
    case "$response" in
        [yY]|[yY][eE][sS]) ;;
        *) log_info "Uninstall cancelled."; exit 0 ;;
    esac
    echo ""
fi

removed=0

# ── Helper ───────────────────────────────────────────────────────────────────
do_remove() {
    local target="$1"
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "Would remove: $target"
        else
            rm -rf "$target"
            log_success "Removed: $target"
        fi
        removed=$((removed + 1))
    fi
}

do_restore_or_remove() {
    local target="$1"
    if [[ -f "${target}.hb-backup" ]]; then
        do_restore_backup "${target}.hb-backup"
    else
        do_remove "$target"
    fi
}

do_restore_backup() {
    local backup="$1"
    local original="${backup%.hb-backup}"
    if [[ -f "$backup" ]]; then
        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "Would restore: $backup -> $original"
        else
            mv "$backup" "$original"
            log_success "Restored: $original"
        fi
        removed=$((removed + 1))
    fi
}

# ── Remove utility scripts ──────────────────────────────────────────────────
log_info "Checking Ratel Forge utility scripts..."
for script in honey-badger-info honey-badger-update honey-badger-install \
              honey-badger-theme honey-badger-doctor honey-badger-uninstall; do
    do_remove "$HOME/.local/bin/$script"
done

# ── Remove theme ────────────────────────────────────────────────────────────
log_info "Checking theme files..."
do_remove "$HOME/.themes/Ratel"
do_remove "$HOME/.themes/Ratel-HC"
do_remove "$HOME/.icons/Ratel"
# Legacy brand directories from earlier releases
do_remove "$HOME/.themes/HoneyBadger"
do_remove "$HOME/.icons/HoneyBadger"

# System-wide theme copy (requires sudo)
for theme_dir in /usr/share/themes/Ratel /usr/share/themes/Ratel-HC; do
    [[ -d "$theme_dir" ]] || continue
    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "Would remove: $theme_dir (sudo)"
    else
        sudo rm -rf "$theme_dir" 2>/dev/null && log_success "Removed: $theme_dir"
    fi
done

# ── Remove generated config (restoring a backup when one exists) ────────────
log_info "Checking generated configuration..."
do_restore_or_remove "$HOME/.nanorc"
do_restore_or_remove "$HOME/.gtkrc-2.0"
do_restore_or_remove "$HOME/.config/gtk-3.0/settings.ini"
do_restore_or_remove "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
do_restore_or_remove "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"

# ── Restore other backed-up files ───────────────────────────────────────────
log_info "Checking for backed-up config files..."
do_restore_backup "$HOME/.bashrc.hb-backup"
do_restore_backup "$HOME/.xinitrc.hb-backup"

# ── Process rollback manifest ───────────────────────────────────────────────
MANIFEST="$HOME/.local/share/honey-badger/rollback-manifest"
if [[ -f "$MANIFEST" ]]; then
    log_info "Processing rollback manifest..."
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        case "$line" in
            FILE:*)
                do_remove "${line#FILE:}"
                ;;
            GROUP:*:*)
                group="${line#GROUP:}"
                user="${group#*:}"
                group="${group%%:*}"
                if [[ $DRY_RUN -eq 1 ]]; then
                    log_info "Would remove user $user from group $group"
                else
                    sudo gpasswd -d "$user" "$group" 2>/dev/null || true
                    log_success "Removed $user from group $group"
                fi
                removed=$((removed + 1))
                ;;
            PACKAGE:*)
                # Log but don't auto-remove packages (safety)
                log_info "Skipping package removal (manual): ${line#PACKAGE:}"
                ;;
        esac
    done < "$MANIFEST"
fi

# ── Remove shell completion ─────────────────────────────────────────────────
log_info "Checking shell completion..."
do_remove "${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions/honey-badger"

# ── Remove Ratel Forge data directory ──────────────────────────────────────
log_info "Checking Ratel Forge data..."
do_remove "$HOME/.local/share/honey-badger"

# ── Clean bashrc additions ──────────────────────────────────────────────────
if [[ -f "$HOME/.bashrc" ]]; then
    log_info "Checking bashrc for Ratel Forge additions..."
    # shellcheck disable=SC2016  # matched literally against ~/.bashrc
    local_patterns=(
        'export EDITOR=nano'
        'export VISUAL=nano'
        'export PATH="$HOME/.local/bin:$PATH"'
        'export PATH=~/.npm-global/bin:$PATH'
    )
    for pattern in "${local_patterns[@]}"; do
        if grep -Fxq "$pattern" "$HOME/.bashrc" 2>/dev/null; then
            if [[ $DRY_RUN -eq 1 ]]; then
                log_info "Would remove from .bashrc: $pattern"
            else
                grep -Fxv "$pattern" "$HOME/.bashrc" > "$HOME/.bashrc.tmp" && \
                    mv "$HOME/.bashrc.tmp" "$HOME/.bashrc"
                log_success "Removed from .bashrc: $pattern"
            fi
            removed=$((removed + 1))
        fi
    done
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
if [[ $DRY_RUN -eq 1 ]]; then
    log_info "Dry run complete. $removed items would be affected."
else
    if [[ $removed -gt 0 ]]; then
        log_success "Uninstall complete. $removed items removed."
        log_info "Restart your terminal or run: source ~/.bashrc"
    else
        log_info "Nothing to remove — Ratel Forge is not installed or already cleaned up."
    fi
fi
