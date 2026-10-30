# ============================================================
# UniShell - Makefile
# COMMAND: make all | PURPOSE: compile every C demo into bin/ | MODULE: 3
# Only bin/ is written by the build. Sources and data are never touched.
# ============================================================

SHELL   := /bin/bash
CC      := gcc
# COMMAND: gcc -Wall -Wextra | PURPOSE: show real bugs instead of hiding them | MODULE: 3
CFLAGS  := -Wall -Wextra -O0 -g -std=gnu99
SRC_DIR := c_programs
BIN_DIR := bin

# every .c file in c_programs/ becomes an executable of the same name in bin/
SOURCES := $(wildcard $(SRC_DIR)/*.c)
TARGETS := $(patsubst $(SRC_DIR)/%.c,$(BIN_DIR)/%,$(SOURCES))

.PHONY: all dirs test clean help

# ---------- build ----------
all: dirs $(TARGETS)
	@if [ -z "$(SOURCES)" ]; then \
		echo "[make all] no C sources in $(SRC_DIR)/ yet - nothing to compile"; \
	else \
		echo "[make all] built: $(notdir $(TARGETS))"; \
	fi

dirs:
	@mkdir -p $(BIN_DIR)

# one executable per source file, named after the source
$(BIN_DIR)/%: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) $< -o $@
	@echo "[gcc] $< -> $@"

# ---------- tests ----------
test: all
	@echo "=== UniShell test run ==="
	@fail=0; \
	for t in tests/test_*.sh; do \
	if [ ! -f "$$t" ]; then echo "[skip] no test scripts yet"; continue; fi; \
	echo "--- $$t"; \
	bash "$$t" || fail=1; \
	done; \
	if [ $$fail -eq 0 ]; then \
	echo "=== RESULT: ALL TESTS PASSED ==="; \
	else \
	echo "=== RESULT: SOME TESTS FAILED ==="; exit 1; \
	fi

# ---------- cleanup: generated files only ----------
clean:
	@rm -f $(BIN_DIR)/*
	@rm -f $(SRC_DIR)/*.o
	@find . -type f -name '*.tmp' -delete
	@echo "[make clean] removed bin/*, *.o and *.tmp - sources and data untouched"

help:
	@echo "make all   - compile c_programs/*.c into bin/"
	@echo "make test  - run every tests/test_*.sh"
	@echo "make clean - remove generated files only"
