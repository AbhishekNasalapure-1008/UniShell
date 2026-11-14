#!/usr/bin/env bash
# ============================================================
# UniShell - Module 2 (File and Directory Management) tests  (Phase 4)
# COMMAND: bash tests/test_04_files.sh | PURPOSE: prove the interactive create sub-menu creates exactly what the user names, and that every action stays inside ./sandbox | MODULE: Unix Basics
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

# Start from a known state so a repeat run behaves exactly like the first one.
find sandbox -mindepth 1 ! -name '.gitkeep' -exec rm -rf -- {} + 2>/dev/null

# ---------- 1. path guards ----------
printf '\n1. Sandbox path guards\n'
if bash -c 'source ./lib/common.sh; sandbox_path ../escape' >/dev/null 2>&1; then bad "sandbox_path accepted ../escape"; else ok "sandbox_path refuses ../escape"; fi
if bash -c 'source ./lib/common.sh; sandbox_path a/b'        >/dev/null 2>&1; then bad "sandbox_path accepted a slash"; else ok "sandbox_path refuses a name with a slash"; fi
if bash -c 'source ./lib/common.sh; check_inside_sandbox /etc/passwd' >/dev/null 2>&1; then bad "check_inside_sandbox accepted /etc/passwd"; else ok "check_inside_sandbox refuses /etc/passwd"; fi
if bash -c 'source ./lib/common.sh; check_inside_sandbox "$UNISHELL_SANDBOX/notes.txt"'; then ok "check_inside_sandbox accepts a sandbox path"; else bad "check_inside_sandbox rejected a valid sandbox path"; fi

# ---------- 2. the create sub-menu ----------
printf '\n2. The create sub-menu\n'
run_menu '2
1
6
0
0
'
expect_rc 0 "the create sub-menu opens and closes"
expect_in "Create files and directories" "the create sub-menu has its own heading"
expect_in "1. Create a new file (touch)" "option 1 creates a new file"
expect_in "2. Create a new directory (mkdir)" "option 2 creates a new directory"
expect_in "3. Create nested directories (mkdir -p)" "option 3 creates nested directories"
expect_in "4. Create multiple files (touch)" "option 4 creates multiple files"
expect_in "5. Create a file with custom content" "option 5 writes custom content"
expect_in "6. Return to previous menu" "option 6 returns to the previous menu"
if [ -e sandbox/demo ] || [ -e sandbox/notes.txt ]; then bad "the module still creates predefined items"; else ok "nothing is created automatically any more"; fi

# ---------- 3. create a file with a custom name ----------
printf '\n3. Creating a file with a custom name\n'
run_menu '2
1
1
my_notes.txt

6
0
0
'
expect_rc 0 "the create-file flow completes"
expect_in "touch created sandbox/my_notes.txt" "touch reported the created path"
if [ -f sandbox/my_notes.txt ]; then ok "sandbox/my_notes.txt was created"; else bad "the named file was not created"; fi

# ---------- 4. create a directory with a custom name ----------
printf '\n4. Creating a directory with a custom name\n'
run_menu '2
1
2
docs

6
0
0
'
expect_rc 0 "the create-directory flow completes"
expect_in "mkdir created sandbox/docs" "mkdir reported the created path"
if [ -d sandbox/docs ]; then ok "sandbox/docs was created"; else bad "the named directory was not created"; fi

# ---------- 5. create nested directories ----------
printf '\n5. Creating nested directories\n'
run_menu '2
1
3
project/src/lib

6
0
0
'
expect_rc 0 "the nested-directory flow completes"
expect_in "mkdir -p created sandbox/project/src/lib" "mkdir -p reported the created path"
if [ -d sandbox/project/src/lib ]; then ok "the whole branch was created"; else bad "the nested directories were not created"; fi
if [ -d sandbox/project/src ]; then ok "the missing parent was created too"; else bad "the parent level is missing"; fi

# ---------- 6. create multiple files ----------
printf '\n6. Creating multiple files\n'
run_menu '2
1
4
multi_one.txt
multi_two.txt
multi_one.txt


6
0
0
'
expect_rc 0 "the multi-file flow completes"
expect_in "touch created 2 file(s)" "two files were created from the typed names"
expect_in "1 name(s) were skipped" "the repeated name was skipped, not created twice"
if [ -f sandbox/multi_one.txt ] && [ -f sandbox/multi_two.txt ]; then ok "both named files exist"; else bad "one of the named files is missing"; fi

# ---------- 7. write custom content ----------
printf '\n7. Writing custom content\n'
run_menu '2
1
5
custom_note.txt
alpha line
beta line
END

6
0
0
'
expect_rc 0 "the custom-content flow completes"
expect_in "Wrote sandbox/custom_note.txt (2 line(s))" "the written path and line count are reported"
if [ "$(wc -l < sandbox/custom_note.txt 2>/dev/null)" = "2" ]; then ok "the multiline content has two lines"; else bad "the multiline content is wrong"; fi
if grep -q 'alpha line' sandbox/custom_note.txt 2>/dev/null; then ok "the typed content is inside the file"; else bad "the typed content is missing"; fi
if grep -q '^END$' sandbox/custom_note.txt 2>/dev/null; then bad "the END marker was written into the file"; else ok "the END marker is not part of the content"; fi

# ---------- 8. duplicate names are never overwritten ----------
printf '\n8. Duplicate names are never overwritten\n'
run_menu '2
1
1
my_notes.txt

6
0
0
'
expect_rc 0 "the duplicate file name flow completes"
expect_in "already exists, so nothing was changed" "an existing file is refused, not replaced"

run_menu '2
1
2
docs

6
0
0
'
expect_rc 0 "the duplicate directory name flow completes"
expect_in "already exists as a directory, so nothing was changed" "an existing directory is refused, not replaced"

run_menu '2
1
5
custom_note.txt
n

6
0
0
'
expect_rc 0 "the content-overwrite flow completes"
expect_in "already exists. Writing would replace its content" "overwriting an existing file asks first"
expect_in "Nothing was written." "declining the confirmation writes nothing"
if grep -q 'alpha line' sandbox/custom_note.txt 2>/dev/null; then ok "the old content survived the declined overwrite"; else bad "the old content was lost"; fi

# ---------- 9. invalid names and paths are refused ----------
printf '\n9. Invalid names and paths are refused\n'
run_menu '2
1
1
/etc/passwd

6
0
0
'
expect_rc 0 "the absolute-path create attempt returns to the sub-menu"
expect_in "not a safe name" "an absolute path is refused as a file name"
if [ -f /etc/passwd ]; then ok "/etc/passwd is untouched"; else bad "/etc/passwd was affected"; fi

run_menu '2
1
1
../escape.txt

6
0
0
'
expect_rc 0 "the traversal create attempt returns to the sub-menu"
expect_in "not a safe name" "a ../ path is refused as a file name"
if [ -e ../escape.txt ]; then bad "a file was created outside the sandbox"; else ok "nothing was created outside ./sandbox"; fi

run_menu '2
1
1


6
0
0
'
expect_rc 0 "the empty-name attempt returns to the sub-menu"
expect_in "No name was given." "an empty name is refused"

run_menu '2
1
3
../escape

6
0
0
'
expect_rc 0 "the nested traversal attempt returns to the sub-menu"
expect_in "not a safe relative path" "a ../ path is refused for nested directories"
if [ -d ../escape ]; then bad "a directory was created outside the sandbox"; else ok "no directory escaped the sandbox"; fi

run_menu '2
1
3
/tmp/unishell_escape

6
0
0
'
expect_rc 0 "the nested absolute-path attempt returns to the sub-menu"
expect_in "Absolute paths are refused" "an absolute path is refused for nested directories"
if [ -e /tmp/unishell_escape ]; then bad "a directory was created outside the sandbox"; else ok "/tmp was not touched"; fi

run_menu '2
1
3
a//b

6
0
0
'
expect_rc 0 "the empty-part path attempt returns to the sub-menu"
expect_in "not a safe relative path" "an empty path part is refused"
if [ -d sandbox/a ]; then bad "a//b created something"; else ok "nothing was created for a//b"; fi

# ---------- 10. removal stays inside ./sandbox ----------
printf '\n10. Removal stays inside ./sandbox\n'
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

# ---------- 11. copy and move stay inside ./sandbox ----------
printf '\n11. Copy and move stay inside ./sandbox\n'
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

# ---------- 12. view a file ----------
printf '\n12. Viewing a file\n'
printf 'view content here\nsecond line\n' > sandbox/view_me.txt
run_menu '2
6
view_me.txt

0
0
'
expect_rc 0 "the view flow completes"
expect_in "View a file: cat, wc, od" "the view demo opened"
expect_in "view content here" "the file content is shown"

# ---------- 13. reset stays inside ./sandbox ----------
printf '\n13. Reset stays inside ./sandbox\n'
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

# ---------- 14. no dynamic execution ----------
printf '\n14. No dynamic execution\n'
if grep -n '\beval\b' modules/files.sh >/dev/null 2>&1; then bad "the word eval appears in modules/files.sh"; else ok "modules/files.sh contains no eval"; fi

# ---------- clean up so repeat runs see the same sandbox ----------
find sandbox -mindepth 1 ! -name '.gitkeep' -exec rm -rf -- {} + 2>/dev/null

# ---------- summary ----------
printf '\nmodule 2 test result: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
