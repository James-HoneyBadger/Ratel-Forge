#!/bin/bash
# shellcheck disable=SC2034  # Variables are consumed by the sourcing script
# shellcheck disable=SC2088  # Tilde strings are human-readable labels, not paths
# Ratel Forge - Desktop configuration layer
# ---------------------------------------------------------------------------
# Nano setup, GTK2/GTK3 theme installation, XFCE and LightDM appearance,
# wallpaper generation, and asset installation.
#
# Sourced by lib/common.sh; do not source directly.
# ---------------------------------------------------------------------------

# Prevent double-sourcing
[[ -n "${_HB_THEME_LOADED:-}" ]] && return 0
readonly _HB_THEME_LOADED=1

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

# ── Theme setup ──────────────────────────────────────────────────────────────
# Installs a complete, self-consistent GTK theme:
#   • user    → ~/.themes/Ratel  (for the current user)
#   • system  → /usr/share/themes/Ratel (for LightDM and other users)
#   • icons   → ~/.icons/Ratel (index only; inherits the system icon set)
#   • settings → GTK2/GTK3 defaults so the theme is active without a session
# The theme the session should use, honouring --high-contrast and the config.
hb_theme_name() {
    if [[ "${HONEY_BADGER_HIGH_CONTRAST:-0}" == "1" ||
          "${HONEY_BADGER_THEME_VARIANT:-default}" == "high-contrast" ]]; then
        printf 'Ratel-HC'
    else
        printf 'Ratel'
    fi
}

setup_honey_badger_theme() {
    hb_next_step "Installing Ratel theme..."

    if ! hb_component_enabled desktop; then
        log_info "Skipping theme (desktop component disabled)"
        return 0
    fi

    if hb_dry_run; then
        log_info "[DRY-RUN] Would install the Ratel themes and apply $(hb_theme_name)"
        return 0
    fi

    local icon_name="Ratel"
    local icon_dir="$HOME/.icons/$icon_name"
    local font="${HONEY_BADGER_FONT:-Noto Sans 10}"
    local mono="${HONEY_BADGER_MONO_FONT:-Noto Sans Mono 10}"
    local active
    active="$(hb_theme_name)"

    # Install both variants so switching does not require reinstalling.
    local variant css index dest
    for variant in Ratel Ratel-HC; do
        if [[ "$variant" == "Ratel-HC" ]]; then
            css="$HONEY_BADGER_ROOT/theme/honey-badger-theme-hc.css"
            index="$HONEY_BADGER_ROOT/theme/index-hc.theme"
        else
            css="$HONEY_BADGER_ROOT/theme/honey-badger-theme.css"
            index="$HONEY_BADGER_ROOT/theme/index.theme"
        fi

        dest="$HOME/.themes/$variant"
        mkdir -p "$dest/gtk-2.0" "$dest/gtk-3.0"

        if [[ -f "$css" ]]; then
            cp "$css" "$dest/gtk-3.0/gtk.css"
        else
            log_warning "GTK3 theme source missing: $css"
        fi

        if [[ -f "$HONEY_BADGER_ROOT/theme/gtkrc-2.0" ]]; then
            cp "$HONEY_BADGER_ROOT/theme/gtkrc-2.0" "$dest/gtk-2.0/gtkrc"
        fi

        if [[ -f "$index" ]]; then
            cp "$index" "$dest/index.theme"
        fi
    done

    # Icon theme index: inherit the system set so no icon ever goes missing.
    mkdir -p "$icon_dir/scalable/apps"
    cat > "$icon_dir/index.theme" << 'ENDICONS'
[Icon Theme]
Name=Ratel
Comment=Ratel icon theme (inherits system icons)
Inherits=hicolor,Adwaita,gnome,Humanity
ENDICONS

    # Brand mark, available to launchers and the greeter.
    if [[ -f "$HONEY_BADGER_ROOT/assets/ratel-logo.svg" ]]; then
        cp "$HONEY_BADGER_ROOT/assets/ratel-logo.svg" "$icon_dir/scalable/apps/ratel.svg"
    fi

    # System-wide copies for display managers and other accounts.
    hb_sudo mkdir -p /usr/share/themes
    for variant in Ratel Ratel-HC; do
        hb_sudo mkdir -p "/usr/share/themes/$variant/gtk-2.0" "/usr/share/themes/$variant/gtk-3.0"
        hb_sudo cp "$HOME/.themes/$variant/gtk-2.0/gtkrc" \
            "/usr/share/themes/$variant/gtk-2.0/gtkrc" 2>/dev/null || true
        hb_sudo cp "$HOME/.themes/$variant/gtk-3.0/gtk.css" \
            "/usr/share/themes/$variant/gtk-3.0/gtk.css" 2>/dev/null || true
        hb_sudo cp "$HOME/.themes/$variant/index.theme" \
            "/usr/share/themes/$variant/index.theme" 2>/dev/null || true
    done

    if [[ -f "$HONEY_BADGER_ROOT/assets/ratel-logo.svg" ]]; then
        hb_sudo mkdir -p /usr/share/icons/hicolor/scalable/apps /usr/share/pixmaps
        hb_sudo cp "$HONEY_BADGER_ROOT/assets/ratel-logo.svg" \
            /usr/share/icons/hicolor/scalable/apps/ratel.svg 2>/dev/null || true
        hb_sudo cp "$HONEY_BADGER_ROOT/assets/ratel-logo.svg" \
            /usr/share/pixmaps/ratel.svg 2>/dev/null || true
    fi

    # Activate the selected variant for GTK3 applications.
    mkdir -p "$HOME/.config/gtk-3.0"
    hb_backup_file "$HOME/.config/gtk-3.0/settings.ini"
    cat > "$HOME/.config/gtk-3.0/settings.ini" << ENDGTK3INI
[Settings]
gtk-theme-name=$active
gtk-icon-theme-name=$icon_name
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
gtk-font-name=$font
gtk-enable-animations=true
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
ENDGTK3INI

    # Activate the theme for GTK2 applications.
    hb_backup_file "$HOME/.gtkrc-2.0"
    cat > "$HOME/.gtkrc-2.0" << ENDGTK2RC
# Managed by Ratel Forge
gtk-theme-name="$active"
gtk-icon-theme-name="$icon_name"
gtk-font-name="$font"
gtk-cursor-theme-name="Adwaita"
ENDGTK2RC

    hb_json_add_config "~/.themes/Ratel"
    hb_json_add_config "~/.themes/Ratel-HC"
    hb_json_add_config "~/.config/gtk-3.0/settings.ini"
    hb_json_add_config "~/.gtkrc-2.0"
    log_success "Ratel themes installed (active: $active)"
}

# ── XFCE desktop configuration ──────────────────────────────────────────────
setup_xfce() {
    hb_next_step "Configuring XFCE desktop environment..."

    if ! hb_component_enabled desktop; then
        log_info "Skipping XFCE (desktop component disabled)"
        return 0
    fi

    if hb_dry_run; then
        log_info "[DRY-RUN] Would configure LightDM and XFCE appearance"
        return 0
    fi

    # Enable display manager (systemd)
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-enabled lightdm >/dev/null 2>&1; then
            log_info "LightDM already enabled"
        else
            hb_sudo systemctl enable lightdm 2>/dev/null || true
            log_success "LightDM display manager enabled"
        fi
    fi

    # Configure LightDM greeter (theme now exists system-wide)
    hb_sudo mkdir -p /etc/lightdm
    cat << 'ENDLIGHTDM' | hb_sudo tee /etc/lightdm/lightdm.conf >/dev/null
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=xfce

[LightDM]
minimum-uid=1000
ENDLIGHTDM

    cat << ENDGREETER | hb_sudo tee /etc/lightdm/lightdm-gtk-greeter.conf >/dev/null
[greeter]
theme-name=$(hb_theme_name)
icon-theme-name=Ratel
font-name=${HONEY_BADGER_FONT:-Noto Sans 10}
background=/usr/share/backgrounds/honeybadger.jpg
ENDGREETER

    _hb_apply_xfce_appearance

    hb_json_add_config "/etc/lightdm/lightdm.conf"
    log_success "XFCE desktop configured"
}

# Write XFCE appearance channels so the theme, fonts, and window buttons are
# applied on next login — and live if an XFCE session is already running.
_hb_apply_xfce_appearance() {
    local xfconf_dir="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
    local font="${HONEY_BADGER_FONT:-Noto Sans 10}"
    local mono="${HONEY_BADGER_MONO_FONT:-Noto Sans Mono 10}"

    mkdir -p "$xfconf_dir"

    hb_backup_file "$xfconf_dir/xsettings.xml"
    cat > "$xfconf_dir/xsettings.xml" << ENDXSETTINGS
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="$(hb_theme_name)"/>
    <property name="IconThemeName" type="string" value="Ratel"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="${font}"/>
    <property name="MonospaceFontName" type="string" value="${mono}"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
    <property name="CursorThemeSize" type="int" value="24"/>
  </property>
  <property name="Xft" type="empty">
    <property name="Antialias" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="int" value="1"/>
  </property>
</channel>
ENDXSETTINGS

    hb_backup_file "$xfconf_dir/xfwm4.xml"
    cat > "$xfconf_dir/xfwm4.xml" << 'ENDXFWM'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="button_layout" type="string" value="O|SHMC"/>
    <property name="workspace_count" type="int" value="4"/>
    <property name="use_compositing" type="bool" value="true"/>
    <property name="title_font" type="string" value="Noto Sans Bold 10"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="theme" type="string" value="Default"/>
  </property>
</channel>
ENDXFWM

    # Apply live when possible (never in dry-run).
    if [[ "$HONEY_BADGER_DRY_RUN" != "1" ]] && command -v xfconf-query >/dev/null 2>&1; then
        xfconf-query -c xsettings -p /Net/ThemeName -s "$(hb_theme_name)" --create -t string 2>/dev/null || true
        xfconf-query -c xsettings -p /Net/IconThemeName -s Ratel --create -t string 2>/dev/null || true
        xfconf-query -c xsettings -p /Gtk/FontName -s "$font" --create -t string 2>/dev/null || true
        xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "$mono" --create -t string 2>/dev/null || true
        xfconf-query -c xfwm4 -p /general/button_layout -s 'O|SHMC' --create -t string 2>/dev/null || true
        xfconf-query -c xfwm4 -p /general/use_compositing -s true --create -t bool 2>/dev/null || true
    fi
}

# ── Wallpaper / assets ───────────────────────────────────────────────────────
install_assets() {
    hb_next_step "Installing Ratel Forge assets..."

    if ! hb_component_enabled desktop; then
        log_info "Skipping desktop assets (desktop component disabled)"
        return 0
    fi

    if hb_dry_run; then
        log_info "[DRY-RUN] Would generate and install the Ratel Forge wallpaper"
        return 0
    fi

    local wallpaper_dir="/usr/share/backgrounds"
    local wallpaper="$wallpaper_dir/honeybadger.jpg"
    local wallpaper_size="${HONEY_BADGER_WALLPAPER_SIZE:-1920x1080}"
    local c_bg="${HONEY_BADGER_THEME_BG:-#16120d}"
    local c_surface="${HONEY_BADGER_THEME_SURFACE:-#2b2217}"
    local c_accent="${HONEY_BADGER_THEME_ACCENT:-#e6a92e}"
    local c_text="${HONEY_BADGER_THEME_TEXT:-#f3ebdf}"

    hb_sudo mkdir -p "$wallpaper_dir"

    if command -v convert >/dev/null 2>&1; then
        local tmp_wallpaper
        tmp_wallpaper="$(mktemp /tmp/honeybadger-wallpaper.XXXXXX.jpg)"
        hb_register_temp "$tmp_wallpaper"
        if convert -size "$wallpaper_size" "gradient:${c_bg}-${c_surface}" \
            -fill "$c_accent" -draw "rectangle 0,0 100000,6" \
            -font DejaVu-Sans-Bold -pointsize 84 -fill "$c_text" \
            -gravity center -annotate +0-60 "RATEL" \
            -font DejaVu-Sans -pointsize 24 -fill "$c_accent" \
            -annotate +0+40 "FEARLESS · DETERMINED · UNCOMPROMISING" \
            -fill "$c_text" -pointsize 16 -annotate +0+90 "v${HONEY_BADGER_VERSION:-2.5.0}" \
            "$tmp_wallpaper" 2>/dev/null && [[ -s "$tmp_wallpaper" ]]; then
            hb_sudo cp "$tmp_wallpaper" "$wallpaper"
            log_success "Generated Ratel Forge wallpaper (${wallpaper_size})"
        else
            log_warning "ImageMagick wallpaper generation failed"
            log_info "Set a wallpaper manually at $wallpaper"
        fi
    else
        log_info "ImageMagick not available, skipping wallpaper generation"
        log_info "Install ImageMagick and re-run, or set a wallpaper manually"
    fi

    _hb_xfce_set_wallpaper "$wallpaper"
    log_success "Assets installed"
}

# Point every XFCE desktop backdrop at the Ratel Forge wallpaper.
_hb_xfce_set_wallpaper() {
    local wallpaper="$1"
    [[ "$HONEY_BADGER_DRY_RUN" == "1" ]] && return 0
    [[ -f "$wallpaper" ]] || return 0
    command -v xfconf-query >/dev/null 2>&1 || return 0

    local prop
    while IFS= read -r prop; do
        [[ -n "$prop" ]] || continue
        xfconf-query -c xfce4-desktop -p "$prop" -s "$wallpaper" 2>/dev/null || true
    done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E 'last-image$' || true)
}

