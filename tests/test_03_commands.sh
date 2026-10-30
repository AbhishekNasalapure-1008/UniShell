#!/usr/bin/env bash
# ============================================================
# UniShell - Module 1 (Unix Command Library) tests  (Phase 4)
# COMMAND: bash tests/test_03_commands.sh | PURPOSE: prove the command library explains every required command and that nothing typed is ever executed | MODULE: 2
#
# Two styles are used:
#   * cmdlib_run  - loads common.sh and the module, then calls one function
#   * run_menu    - drives the real ./unishell.sh with scripted input, exactly
#                   like a person typing at the prompt
# ============================================================

cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok()  { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); }

cmdlib_run() { bash -c "source ./lib/common.sh; source ./modules/commands.sh; $1"; }

MENU_OUT=""
MENU_RC=0
run_menu() { MENU_OUT="$(printf '%s' "$1" | bash ./unishell.sh 2>&1)"; MENU_RC=$?; return 0; }
expect_rc()      { if [ "$MENU_RC" -eq "$1" ]; then ok "$2 (exit status $MENU_RC)"; else bad "$2 (expected $1, got $MENU_RC)"; fi; }
expect_in()      { if printf '%s' "$MENU_OUT" | grep -qF "$1"; then ok "$2"; else bad "$2 (missing: $1)"; fi; }
expect_not_in()  { if printf '%s' "$MENU_OUT" | grep -qF "$1"; then bad "$2 (found: $1)"; else ok "$2"; fi; }

printf 'Module 1 (Unix Command Library) tests\n'

# ---------- 1. the library file ----------
printf '\n1. Library file\n'
if [ -r data/command_library.txt ]; then ok "data/command_library.txt is readable"; else bad "data/command_library.txt is missing"; fi
if grep -q $'\r' data/command_library.txt 2>/dev/null; then bad "command_library.txt uses CRLF line endings"; else ok "command_library.txt uses LF line endings"; fi

# ---------- 2. every required command is covered ----------
printf '\n2. Required commands are covered\n'
required="echo printf ls who date cal type pwd cd mkdir rmdir cat mv rm cp wc od chmod grep egrep read readonly test set shift trap passwd su"
missing=""
for c in $required; do
  if ! cmdlib_run "cmdlib_has $c"; then missing="$missing $c"; fi
done
if [ -z "$missing" ]; then ok "all 28 required commands have an entry"; else bad "missing entries:$missing"; fi

# ---------- 3. each entry has the fixed fields ----------
printf '\n3. Every entry carries the required fields\n'
badfields=""
for c in $required; do
  block="$(cmdlib_run "cmdlib_show $c")"
  for field in SYLLABUS PURPOSE SYNTAX EXAMPLE OUTPUT USES NOTES; do
    printf '%s' "$block" | grep -q "^$field" || badfields="$badfields $c/$field"
  done
done
if [ -z "$badfields" ]; then ok "every entry has SYLLABUS, PURPOSE, SYNTAX, EXAMPLE, OUTPUT, USES and NOTES"; else bad "fields missing:$badfields"; fi

# ---------- 4. syllabus mapping ----------
printf '\n4. Syllabus mapping is present\n'
badmap=""
for c in $required; do
  block="$(cmdlib_run "cmdlib_show $c")"
  printf '%s' "$block" | grep -qE 'SYLLABUS : Module [1-4] ' || badmap="$badmap $c"
done
if [ -z "$badmap" ]; then ok "every entry names a syllabus Module 1 to 4"; else bad "no syllabus module for:$badmap"; fi

# ---------- 5. unknown name ----------
printf '\n5. Unknown names\n'
out="$(cmdlib_run 'cmdlib_show definitely-not-real')"
if [ -z "$out" ]; then ok "an unknown name produces no block"; else bad "cmdlib_show printed something for an unknown name"; fi

# ---------- 6. list from the menu ----------
printf '\n6. Listing the library from the menu\n'
run_menu '1
1

0
0
'
expect_rc 0 "listing then leaving the module works"
expect_in "Commands covered by UniShell" "the list screen is shown"
expect_in "grep" "grep appears in the list"

# ---------- 7. explain from the menu ----------
printf '\n7. Explaining a command from the menu\n'
run_menu '1
2
grep

0
0
'
expect_rc 0 "explaining then leaving works"
expect_in "### grep" "the grep block is printed"
expect_in "Print the lines that match a pattern" "the explanation text is printed"

run_menu '1
2
nosuchcommand

0
0
'
expect_in "There is no entry for" "an unknown command is reported honestly"

# ---------- 8. nothing typed is executed ----------
printf '\n8. Typed text is never executed\n'
run_menu '1
2
0; echo PWNED

0
0
'
expect_not_in "PWNED" "a semicolon payload in the explain prompt is not executed"
expect_in "plain command name" "the unsafe name is refused before it is printed"

rm -f injection_marker_1 2>/dev/null
run_menu '1
2
0; touch injection_marker_1

0
0
'
if [ ! -e injection_marker_1 ]; then
  ok "a payload that would create a file was not executed"
else
  bad "typed input was executed (injection_marker_1 was created)"
  rm -f injection_marker_1 2>/dev/null
fi

run_menu '1
2
$(touch injection_marker_2)

0
0
'
if [ ! -e injection_marker_2 ]; then
  ok "a command-substitution payload was not executed"
else
  bad "command substitution typed at the prompt was executed"
  rm -f injection_marker_2 2>/dev/null
fi

# ---------- 9. passwd and su ----------
printf '\n9. passwd and su are explained, never run\n'
run_menu '1
4

0
0
'
expect_rc 0 "the privileged-explanation screen works"
expect_in "passwd" "passwd is explained"
expect_in "switch user" "su is explained"
expect_in "never run" "the screen states that they are never run"

# ---------- 10. no dynamic execution ----------
printf '\n10. No dynamic execution\n'
if grep -n '\beval\b' modules/commands.sh >/dev/null 2>&1; then bad "the word eval appears in modules/commands.sh"; else ok "modules/commands.sh contains no eval"; fi

# ---------- summary ----------
printf '\nmodule 1 test result: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
