#!/usr/bin/env bash
# ============================================================
# UniShell - Module 2 (File and Directory Management) tests  (Phase 4)
# COMMAND: bash tests/test_04_files.sh | PURPOSE: prove the file demos work and that every destructive action stays inside ./sandbox | MODULE: Unix Basics
# ============================================================

cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok()  { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); }

MENU_OUT=""
MENU_RC=0
run_menu() { MENU_OUT="$(printf '%s' "$1" | bash ./unishell.sh 2>&1)"; MENU_RC=$?; return 0; }
expect_rc()      { if [ "$MENU_RC" -eq "$1" ]; then ok "$2 (exit status $MENU_RC)"; else bad "$2 (expected $1, got $MENU_RC)"; fi; }
expect_in()      { if printf '%s' "$MENU_OUT" | grep -qF "$1"; then ok "$2"; else bad "$2 (missing: $1)"; fi; }

printf 'Module 2 (File and Directory Management) tests\n'

mkdir -p sandbox

# ---------- 1. path guards ----------
printf '\n1. Sandbox path guards\n'
if bash -c 'source ./lib/common.sh; sandbox_path ../escape' >/dev/null 2>&1; then bad "sandbox_path accepted ../escape"; else ok "sandbox_path refuses ../escape"; fi
if bash -c 'source ./lib/common.sh; sandbox_path a/b'        >/dev/null 2>&1; then bad "sandbox_path accepted a slash"; else ok "sandbox_path refuses a name with a slash"; fi
if bash -c 'source ./lib/common.sh; check_inside_sandbox /etc/passwd' >/dev/null 2>&1; then bad "check_inside_sandbox accepted /etc/passwd"; else ok "check_inside_sandbox refuses /etc/passwd"; fi
if bash -c 'source ./lib/common.sh; check_inside_sandbox "$UNISHELL_SANDBOX/notes.txt"'; then ok "check_inside_sandbox accepts a sandbox path"; else bad "check_inside_sandbox rejected a valid sandbox path"; fi

# ---------- 2. create ----------
printf '\n2. Creating files and directories\n'
run_menu '2
1

0
0
'
expect_rc 0 "the create demo completes"
expect_in "Created:" "the demo reports what it created"
if [ -f sandbox/demo/hello.txt ]; then ok "sandbox/demo/hello.txt was created"; else bad "the demo tree was not created"; fi
if [ -f sandbox/notes.txt ]; then ok "sandbox/notes.txt was created"; else bad "sandbox/notes.txt was not created"; fi

# ---------- 3. remove a file inside the sandbox ----------
printf '\n3. Removing a file inside ./sandbox\n'
printf 'temporary\n' > sandbox/menu_remove_me.txt
run_menu '2
5
menu_remove_me.txt
y

0
0
'
expect_rc 0 "the remove flow completes"
expect_in "rm removed the file" "the file was removed"
if [ -e sandbox/menu_remove_me.txt ]; then bad "the file still exists after rm"; else ok "the file is gone"; fi

# ---------- 4. removal cannot escape the sandbox ----------
printf '\n4. Removal cannot escape ./sandbox\n'
run_menu '2
5
../Makefile

0
0
'
expect_rc 0 "the escape attempt returns to the menu"
expect_in "not a safe name" "a name containing a slash is refused"
if [ -f Makefile ]; then ok "Makefile outside the sandbox is untouched"; else bad "Makefile outside the sandbox was removed"; fi

run_menu '2
5
/etc/passwd

0
0
'
expect_rc 0 "the absolute-path attempt returns to the menu"
if [ -f /etc/passwd ]; then ok "/etc/passwd is untouched"; else bad "/etc/passwd was affected"; fi

# ---------- 5. copy stays inside the sandbox ----------
printf '\n5. Copy and move stay inside ./sandbox\n'
printf 'source content\n' > sandbox/copy_src.txt
run_menu '2
4
copy_src.txt
copy_dst.txt
n

0
0
'
expect_rc 0 "the copy flow completes"
expect_in "cp created the copy" "cp reported success"
if [ -f sandbox/copy_dst.txt ]; then ok "the copy exists inside ./sandbox"; else bad "the copy was not created"; fi
if [ -f sandbox/copy_src.txt ]; then ok "cp kept the original file"; else bad "cp lost the original file"; fi

# ---------- 6. reset keeps .gitkeep ----------
printf '\n6. Reset stays inside ./sandbox\n'
touch sandbox/.gitkeep 2>/dev/null
run_menu '2
7
y

0
0
'
expect_rc 0 "the reset flow completes"
expect_in "Reset finished" "the reset reports how many entries it removed"
if [ -f sandbox/.gitkeep ]; then ok ".gitkeep survived the reset"; else bad ".gitkeep was deleted by the reset"; fi
if [ -z "$(find sandbox -mindepth 1 ! -name '.gitkeep' -print 2>/dev/null)" ]; then ok "the sandbox is empty again"; else bad "the reset left something behind"; fi

# ---------- 7. no dynamic execution ----------
printf '\n7. No dynamic execution\n'
if grep -n '\beval\b' modules/files.sh >/dev/null 2>&1; then bad "the word eval appears in modules/files.sh"; else ok "modules/files.sh contains no eval"; fi

# ---------- clean up so repeat runs see the same sandbox ----------
find sandbox -mindepth 1 ! -name '.gitkeep' -exec rm -rf -- {} + 2>/dev/null

# ---------- summary ----------
printf '\nmodule 2 test result: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
