#!/usr/bin/env bash
# ============================================================
# UniShell - scaffold self-test (written in Phase 2)
# COMMAND: bash tests/test_00_scaffold.sh | PURPOSE: prove the project skeleton is complete and usable | MODULE: 3
#
# This is the first test of every run. Every later test depends on the
# folders, the writable sandbox and the toolchain checked here, so if this
# file reports a FAIL, fix it before looking at any other test.
# ============================================================

pass=0
fail=0

# COMMAND: printf | PURPOSE: print one formatted result line | MODULE: 1
ok()  { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); }

# COMMAND: cd | PURPOSE: always test from the project root, no matter where we start | MODULE: 1
cd "$(dirname "$0")/.." || { printf '  [FAIL] cannot locate project root\n'; exit 1; }
printf 'Scaffold self-test - project root: %s\n' "$(pwd)"

# ---------- 1. folders ----------
printf '\n1. Required folders\n'
# COMMAND: for ... in | PURPOSE: repeat the same check over a fixed list | MODULE: 2
for dir in modules c_programs data sandbox logs tests docs; do
  if [ -d "$dir" ]; then ok "folder $dir/ exists"; else bad "folder $dir/ is missing"; fi
done

# ---------- 2. files ----------
printf '\n2. Required files\n'
for file in Makefile README.md .gitignore docs/COMMAND_MAP.md; do
  if [ -f "$file" ]; then ok "file $file exists"; else bad "file $file is missing"; fi
done

# ---------- 3. write access ----------
printf '\n3. Runtime folders are writable\n'
# COMMAND: touch | PURPOSE: create a throwaway file to prove we may write here | MODULE: 1
if touch sandbox/.write_test 2>/dev/null; then
  ok "sandbox/ is writable (destructive demos have a safe home)"
  rm -f sandbox/.write_test
else
  bad "sandbox/ is not writable"
fi
if touch logs/.write_test 2>/dev/null; then
  ok "logs/ is writable"
  rm -f logs/.write_test
else
  bad "logs/ is not writable"
fi

# ---------- 4. tools ----------
printf '\n4. Required tools\n'
# COMMAND: command -v | PURPOSE: check a program exists without running it | MODULE: 1
for tool in gcc make bash; do
  if command -v "$tool" >/dev/null 2>&1; then ok "tool $tool found"; else bad "tool $tool not found"; fi
done

# this project uses $'\r' and arrays, which need bash 4 or newer
if [ "${BASH_VERSINFO[0]}" -ge 4 ]; then
  ok "bash version $BASH_VERSION is 4 or newer"
else
  bad "bash $BASH_VERSION is older than 4"
fi

# ---------- 5. line endings ----------
printf '\n5. Line endings must be LF (CRLF breaks make and bash)\n'
# COMMAND: grep -q | PURPOSE: detect a carriage return that would break a script | MODULE: 2
check_lf() {
  [ -f "$1" ] || return 0
  if grep -q $'\r' "$1" 2>/dev/null; then
    bad "$1 uses CRLF line endings (must be LF)"
  else
    ok "$1 uses LF line endings"
  fi
}
check_lf Makefile
check_lf .gitignore
for script in tests/*.sh modules/*.sh unishell.sh; do
  check_lf "$script"
done

# ---------- 6. safety preconditions ----------
printf '\n6. Safety preconditions\n'
if [ -d sandbox ] && [ -w sandbox ]; then
  ok "sandbox/ exists and is writable, so no demo needs to touch the real home directory"
else
  bad "sandbox/ is missing or read-only"
fi
if [ -f data/.gitkeep ] && [ -f logs/.gitkeep ]; then
  ok "placeholder files keep empty folders visible to git"
else
  bad "missing .gitkeep placeholder in data/ or logs/"
fi

# ---------- summary ----------
printf '\nScaffold self-test result: %d passed, %d failed\n' "$pass" "$fail"
# COMMAND: exit | PURPOSE: return non-zero so "make test" fails loudly | MODULE: 2
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
