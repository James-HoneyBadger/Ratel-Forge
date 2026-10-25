#!/usr/bin/env python3
"""Lint the Ratel Forge GTK themes.

Checks (stdlib only, so CI needs no extra packages):
  * structurally balanced CSS
  * required palette tokens and widget selectors
  * no universal background rule (which would paint every widget)
  * WCAG contrast for text, muted text, accent text, and status colours

Usage: python3 scripts/lint-theme.py [--verbose]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEMES = {
    "base": ROOT / "theme" / "honey-badger-theme.css",
    "high-contrast": ROOT / "theme" / "honey-badger-theme-hc.css",
}

REQUIRED_TOKENS = [
    "ratel_bg", "ratel_surface", "ratel_surface_alt", "ratel_base",
    "ratel_border", "ratel_text", "ratel_muted", "ratel_dim",
    "ratel_accent", "ratel_accent_soft", "ratel_on_accent",
    "ratel_warning", "ratel_error", "ratel_success", "ratel_info",
]

REQUIRED_SELECTORS = [
    "headerbar", "button", "entry", "menuitem", "notebook",
    "scrollbar", "switch", "check", "radio", "progressbar",
    "treeview", "tooltip", "popover", "infobar", "*:focus",
]

# (foreground, background, minimum ratio, description)
CONTRAST_RULES = [
    ("ratel_text", "ratel_bg", 4.5, "body text on window"),
    ("ratel_text", "ratel_surface", 4.5, "body text on surface"),
    ("ratel_text", "ratel_base", 4.5, "body text on base"),
    ("ratel_muted", "ratel_bg", 4.5, "muted text on window"),
    ("ratel_on_accent", "ratel_accent", 4.5, "text on accent"),
    ("ratel_accent", "ratel_bg", 3.0, "accent on window (UI)"),
    ("ratel_warning", "ratel_bg", 3.0, "warning on window (UI)"),
    ("ratel_error", "ratel_bg", 3.0, "error on window (UI)"),
    ("ratel_success", "ratel_bg", 3.0, "success on window (UI)"),
    ("ratel_info", "ratel_bg", 3.0, "info on window (UI)"),
]


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def _channel(c: float) -> float:
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(hex_color: str) -> float:
    r, g, b = hex_to_rgb(hex_color)
    return 0.2126 * _channel(r) + 0.7152 * _channel(g) + 0.0722 * _channel(b)


def contrast(a: str, b: str) -> float:
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def lint(name: str, path: Path) -> list[str]:
    problems: list[str] = []
    if not path.is_file():
        return [f"{name}: missing {path.relative_to(ROOT)}"]

    css = path.read_text()
    if css.count("{") != css.count("}"):
        problems.append(f"{name}: unbalanced braces")

    if "@import url(\"resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css\")" not in css:
        problems.append(f"{name}: missing Adwaita dark baseline import")

    tokens = dict(re.findall(r"@define-color\s+(ratel_[a-z_]+)\s+(#[0-9a-fA-F]{6});", css))
    for token in REQUIRED_TOKENS:
        if token not in tokens:
            problems.append(f"{name}: palette token missing: {token}")

    if re.search(r"(?m)^\s*\*\s*\{[^}]*background-color", css):
        problems.append(f"{name}: universal '* { background-color }' rule detected")

    for selector in REQUIRED_SELECTORS:
        if not re.search(rf"(?m)^\s*{re.escape(selector)}[\s,{{:.>]", css):
            problems.append(f"{name}: required selector missing: {selector}")

    for fg, bg, minimum, label in CONTRAST_RULES:
        if fg in tokens and bg in tokens:
            ratio = contrast(tokens[fg], tokens[bg])
            status = "ok" if ratio >= minimum else "FAIL"
            print(f"  {name:14s} {label:28s} {ratio:5.2f}:1 (min {minimum}) {status}")
            if ratio < minimum:
                problems.append(f"{name}: contrast {ratio:.2f} < {minimum} for {label}")

    return problems


def main() -> int:
    verbose = "--verbose" in sys.argv
    problems: list[str] = []
    for name, path in THEMES.items():
        print(f"Linting {name}: {path.relative_to(ROOT)}")
        found = lint(name, path)
        problems.extend(found)
        if verbose:
            for item in found:
                print(f"  ! {item}")

    if problems:
        print(f"\n{len(problems)} theme problem(s):")
        for item in problems:
            print(f"  ✖ {item}")
        return 1

    print("\n✔ Themes pass structural, palette, selector, and contrast checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
