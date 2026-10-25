#!/bin/bash
# shellcheck disable=SC2034
# Render GTK3 widgets under Xvfb and save a screenshot for visual review.
#
# Usage: scripts/theme-screenshot.sh [theme-name] [output.png]
#
# Requires: xvfb, imagemagick, and gtk3 examples (gtk3-widget-factory or
# gtk3-demo). These are intentionally not installed automatically; run this on
# a workstation or in a dedicated CI job.
set -euo pipefail

THEME="${1:-Ratel}"
OUTPUT="${2:-/tmp/ratel-${THEME}.png}"
DISPLAY_NUM="${HONEY_BADGER_XVFB_DISPLAY:-:99}"

for cmd in Xvfb import; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'Missing dependency: %s\n' "$cmd" >&2
        printf 'Install xvfb and imagemagick, then retry.\n' >&2
        exit 1
    fi
done

WIDGET_APP=""
for candidate in gtk3-widget-factory gtk3-demo; do
    if command -v "$candidate" >/dev/null 2>&1; then
        WIDGET_APP="$candidate"
        break
    fi
done
if [[ -z "$WIDGET_APP" ]]; then
    printf 'Missing gtk3-widget-factory (or gtk3-demo).\n' >&2
    printf 'Install your distro package for GTK3 examples, then retry.\n' >&2
    exit 1
fi

XVFB_PID=""
APP_PID=""
cleanup() {
    [[ -n "$APP_PID" ]] && kill "$APP_PID" 2>/dev/null || true
    [[ -n "$XVFB_PID" ]] && kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT

Xvfb "$DISPLAY_NUM" -screen 0 1280x800x24 >/dev/null 2>&1 &
XVFB_PID=$!
sleep 1

DISPLAY="$DISPLAY_NUM" GTK_THEME="$THEME" "$WIDGET_APP" >/dev/null 2>&1 &
APP_PID=$!
sleep 3

DISPLAY="$DISPLAY_NUM" import -window root "$OUTPUT"
printf 'Saved %s\n' "$OUTPUT"
