#!/usr/bin/env bash
# ============================================================
# UniShell - web API self-test (added with the web interface)
# COMMAND: bash tests/test_11_web_api.sh | PURPOSE: prove every Flask endpoint works and that the sandbox cannot be left | MODULE: 3
#
# The checks themselves are written in Python (tests/web_api_checks.py),
# because Flask is needed to talk to the application through its test client.
# That client means no server has to be started and no port has to be bound.
#
# The Python checks need the virtual environment in backend/.venv, which also
# provides Flask for the web application. When that environment is missing the
# test reports a skip and passes, so "make test" still works for anyone who is
# only interested in the CLI.
# ============================================================

cd "$(dirname "$0")/.." || { printf '  [FAIL] cannot locate project root\n'; exit 1; }

PYTHON="backend/.venv/bin/python"

if [ ! -x "$PYTHON" ]; then
  printf '  [SKIP] the web API checks need backend/.venv - see the README\n'
  printf 'web api test result: 0 passed, 0 failed (skipped, no virtual environment)\n'
  exit 0
fi

"$PYTHON" tests/web_api_checks.py
rc=$?

if [ "$rc" -eq 0 ]; then exit 0; else exit 1; fi
