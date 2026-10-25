#!/usr/bin/env python3
"""Generate the high-contrast Ratel theme from the base stylesheet.

The high-contrast variant is a full standalone stylesheet (not an @import), so
it renders identically even if GTK's relative-import behaviour differs between
releases. Run this after editing theme/honey-badger-theme.css:

    python3 scripts/generate_theme_variants.py
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
BASE = ROOT / "theme" / "honey-badger-theme.css"
OUT = ROOT / "theme" / "honey-badger-theme-hc.css"

PALETTE = {
    "ratel_bg": "#000000",
    "ratel_surface": "#0b0906",
    "ratel_surface_alt": "#15110c",
    "ratel_base": "#000000",
    "ratel_border": "#6f6250",
    "ratel_text": "#ffffff",
    "ratel_muted": "#e3d9c8",
    "ratel_dim": "#b3a795",
    "ratel_accent": "#ffc247",
    "ratel_accent_soft": "#ffd780",
    "ratel_on_accent": "#000000",
    "ratel_warning": "#ffd166",
    "ratel_error": "#ff7a6b",
    "ratel_success": "#8fe08a",
    "ratel_info": "#8cc6ff",
}

OVERRIDES = """
/* ═══════════════════════════════════════════════════════════════════════════
   High-contrast overrides
   Thicker borders and focus rings; every foreground clears AAA contrast on
   its surface.
   ═══════════════════════════════════════════════════════════════════════════ */

*:focus {
    outline: 3px solid @ratel_accent;
    outline-offset: 2px;
}

button,
entry,
spinbutton,
check,
radio {
    border-width: 2px;
}

headerbar,
.titlebar {
    border-bottom-width: 2px;
}

scrollbar slider {
    background-color: alpha(@ratel_text, 0.45);
}

scrollbar slider:hover {
    background-color: @ratel_accent;
}

notebook > header > tabs > tab:checked {
    box-shadow: inset 0 3px 0 @ratel_accent;
}

.sidebar row:selected,
placessidebar row:selected {
    box-shadow: inset 4px 0 0 @ratel_accent;
}
"""


def main() -> int:
    css = BASE.read_text()

    for token, value in PALETTE.items():
        css, count = re.subn(
            rf"@define-color {token}\s+#[0-9a-fA-F]{{6}};",
            f"@define-color {token} {value};",
            css,
        )
        if count == 0:
            raise SystemExit(f"palette token not found in base theme: {token}")

    banner = (
        "/* ═══════════════════════════════════════════════════════════════════════\n"
        "   Ratel — high-contrast GTK3 theme (GENERATED — do not edit)\n"
        "   Regenerate with: python3 scripts/generate_theme_variants.py\n"
        "   ═══════════════════════════════════════════════════════════════════════ */\n\n"
    )
    OUT.write_text(banner + css.rstrip() + "\n" + OVERRIDES)
    print(f"wrote {OUT.relative_to(ROOT)} ({len(OUT.read_text().splitlines())} lines)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
