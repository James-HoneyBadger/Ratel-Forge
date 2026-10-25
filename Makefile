# Ratel Forge — developer tasks
#
# make lint    structural + shellcheck + theme checks
# make test    the three verification suites
# make check   lint + test (what CI runs)
# make theme   regenerate the high-contrast theme, then lint it

SHELL := /bin/bash
SHELLCHECK ?= shellcheck

SCRIPTS := install.sh lib/*.sh uninstall.sh distros/*/install-*.sh assets/honey-badger-*

.PHONY: help lint syntax shellcheck theme screenshot test check clean

help:
	@printf "%s\n" \
	  "make lint      Structural, shellcheck, and theme checks" \
	  "make test      Run verify_scripts.sh, verify_advanced.sh, test_final.sh" \
	  "make check     lint + test" \
	  "make theme     Regenerate theme variants and lint them" \
	  "make screenshot  Render widgets under Xvfb (needs xvfb + gtk3 examples)" \
	  "make clean     Remove Python caches"

syntax:
	@for f in $(SCRIPTS) verify_scripts.sh verify_advanced.sh test_final.sh; do \
	  bash -n "$$f" || { echo "FAIL $$f"; exit 1; }; \
	done
	@echo "OK syntax"

shellcheck:
	@if command -v $(SHELLCHECK) >/dev/null 2>&1; then \
	  $(SHELLCHECK) -x -s bash -e SC2034 $(SCRIPTS) && echo "OK shellcheck"; \
	else echo "-- shellcheck not installed, skipping"; fi

theme:
	@python3 scripts/generate_theme_variants.py
	@python3 scripts/lint-theme.py

screenshot:
	@scripts/theme-screenshot.sh "$${THEME:-Ratel}" "$${OUTPUT:-/tmp/ratel.png}"

test:
	@bash verify_scripts.sh
	@bash verify_advanced.sh
	@bash test_final.sh

lint: syntax shellcheck theme

check: lint test

clean:
	@find . -name "__pycache__" -type d -prune -exec rm -rf {} + 2>/dev/null || true
	@echo "OK clean"
