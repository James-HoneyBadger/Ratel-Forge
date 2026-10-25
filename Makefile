# Ratel Forge — developer tasks
#
# make lint    structural + shellcheck + desktop-layer guard
# make test    the three verification suites
# make check   lint + test (what CI runs)

SHELL := /bin/bash
SHELLCHECK ?= shellcheck

SCRIPTS := install.sh lib/*.sh uninstall.sh distros/*/install-*.sh assets/honey-badger-* scripts/check-no-desktop-layer.sh

.PHONY: help lint syntax shellcheck guard test check clean

help:
	@printf "%s\n" \
	  "make lint      Structural, shellcheck, and desktop-layer guard" \
	  "make test      Run verify_scripts.sh, verify_advanced.sh, test_final.sh" \
	  "make check     lint + test" \
	  "make guard     Fail if desktop-environment or login code reappears" \
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

guard:
	@scripts/check-no-desktop-layer.sh

test:
	@bash verify_scripts.sh
	@bash verify_advanced.sh
	@bash test_final.sh

lint: syntax shellcheck guard

check: lint test

clean:
	@find . -name "__pycache__" -type d -prune -exec rm -rf {} + 2>/dev/null || true
	@echo "OK clean"
