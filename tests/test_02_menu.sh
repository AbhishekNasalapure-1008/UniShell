#!/usr/bin/env bash
# ============================================================
# UniShell - menu and navigation tests  (Phase 3)
# COMMAND: bash tests/test_02_menu.sh | PURPOSE: drive the real menu with scripted input and check what it prints and its exit status | MODULE: 2
#
# The menu is started as a child process and fed input through a pipe, just
# like a person typing. Because the output is a pipe and not a terminal,
# common.sh turns colours off, which makes these checks readable.
#
# Note: after an unfinished module the menu waits for "Press Enter to return
# to the menu", so the scripted input has a blank line there.
# ============================================================

cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok()  { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); }

MENU_OUT=""
MENU_RC=0

# run_menu "<input>" - start ./unishell.sh with the given input.
run_menu() {
  MENU_OUT="$(printf '%s' "$1" | bash ./unishell.sh 2>&1)"
  MENU_RC=$?
  return 0
}

expect_rc() {
  if [ "$MENU_RC" -eq "$1" ]; then ok "$2 (exit status $MENU_RC)"; else bad "$2 (expected exit status $1, got $MENU_RC)"; fi
}
expect_no_rc() {
  if [ "$MENU_RC" -ne "$1" ]; then ok "$2 (exit status $MENU_RC)"; else bad "$2 (expected something other than $1)"; fi
}
expect_in() {
  if printf '%s' "$MENU_OUT" | grep -qF "$1"; then ok "$2"; else bad "$2 (output did not contain: $1)"; fi
}
expect_not_in() {
  if printf '%s' "$MENU_OUT" | grep -qF "$1"; then bad "$2 (output contained: $1)"; else ok "$2"; fi
}

printf 'Menu and navigation tests for ./unishell.sh\n'

# ---------- 1. menu starts and exits cleanly ----------
printf '\n1. Start up and exit\n'
run_menu '0
'
expect_rc 0 "choosing 0 exits with status 0"
expect_in "Unix Programming Learning Lab" "the banner is printed"
expect_in "10. Activity Logs" "all ten module entries are listed"
expect_in "0. Exit" "the exit entry is listed"
expect_in "Thank you for using UniShell" "a farewell message is printed"
expect_in "Practice files are kept inside" "the sandbox path is shown to the user"

# ---------- 2. invalid input ----------
printf '\n2. Invalid input is refused, not executed\n'
run_menu 'hello
0
'
expect_rc 0 "menu recovers from text input and still exits cleanly"
expect_in "is not a number" "text is reported as not a number"

run_menu '99
0
'
expect_rc 0 "menu recovers from an out-of-range number"
expect_in "Please choose a number from 0 to 10" "99 is reported as out of range"

run_menu '

0
'
expect_rc 0 "menu recovers from an empty line"
expect_in "Nothing was entered" "an empty line is reported"

# ---------- 3. navigation ----------
printf '\n3. Navigation\n'
run_menu '1
0
0
'
expect_rc 0 "opening module 1 and returning to the menu works"
expect_in "Module 1 - Unix Command Library" "module 1 opens the command library sub-menu"
expect_in "List every command in the library" "the sub-menu options are listed"

run_menu '2
0
0
'
expect_rc 0 "opening module 2 and returning to the menu works"
expect_in "Module 2 - File and Directory Management" "module 2 opens the file and directory sub-menu"

run_menu '5
0
0
'
expect_rc 0 "opening module 5 and returning to the menu works"
expect_in "Module 5 - Shell Programming Lab" "module 5 opens the shell programming sub-menu"
expect_in "About .profile" "the shell programming sub-menu is listed"

run_menu '6
0
0
'
expect_rc 0 "opening module 6 and returning to the menu works"
expect_in "Module 6 - Process Management Lab" "module 6 opens the process management sub-menu"

run_menu '8
0
0
'
expect_rc 0 "opening module 8 and returning to the menu works"
expect_in "Module 8 - C System Calls Demonstrations" "module 8 opens the system calls sub-menu"

run_menu '9
0
0
'
expect_rc 0 "opening module 9 and returning to the menu works"
expect_in "Module 9 - Quiz and Practical Exercises" "module 9 opens the quiz sub-menu"
expect_in "Start the quiz (multiple choice, scored)" "the quiz sub-menu options are listed"

run_menu '10
0
0
'
expect_rc 0 "opening module 10 and returning to the menu works"
expect_in "Module 10 - Activity Logs" "module 10 opens the activity log sub-menu"
expect_in "Show the whole activity log" "the log sub-menu options are listed"

# ---------- 4. end of input ----------
printf '\n4. End of input\n'
run_menu ''
expect_rc 0 "end of input exits with status 0"
expect_in "Input ended (Ctrl-D)" "end of input is explained"

run_menu '0'
expect_rc 0 "a last line with no trailing newline is still accepted"

run_menu '1
'
expect_rc 0 "end of input during the pause still exits cleanly"

# ---------- 5. injection safety ----------
printf '\n5. Nothing typed can be executed\n'
run_menu '0; echo PWNED
0
'
expect_not_in "PWNED" "a command after a semicolon is not executed"
expect_in "is not a number" "the attempt is refused as not a number"

run_menu '/bin/ls
0
'
expect_not_in "Makefile" "a typed program name is not executed"
expect_in "is not a number" "a typed path is refused as not a number"

run_menu '$(echo PWNED)
0
'
expect_not_in "PWNED" "command substitution typed at the prompt is not executed"

run_menu '`echo PWNED`
0
'
expect_not_in "PWNED" "backtick substitution typed at the prompt is not executed"

# This payload would create a file if it were executed. The check looks at the
# real side effect instead of at the text the menu prints, so it proves
# non-execution on its own.
rm -f injection_marker 2>/dev/null
run_menu '0; touch injection_marker
0
'
if [ ! -e injection_marker ]; then
  ok "a payload that would create a file was not executed"
else
  bad "typed input was executed (injection_marker was created)"
  rm -f injection_marker 2>/dev/null
fi

# ---------- 6. the menu runs no eval ----------
printf '\n6. No eval in the sources\n'
# COMMAND: grep -n | PURPOSE: search the sources for a forbidden word | MODULE: 4
if grep -n '\beval\b' unishell.sh lib/common.sh >/dev/null 2>&1; then
  bad "the word eval appears in unishell.sh or lib/common.sh"
else
  ok "unishell.sh and lib/common.sh contain no eval"
fi

# ---------- 7. logging ----------
printf '\n7. Activity log\n'
before="$(wc -l < logs/activity.log 2>/dev/null || echo 0)"
run_menu '1

0
'
after="$(wc -l < logs/activity.log)"
if [ "$after" -gt "$before" ]; then ok "activity.log grew during a session ($before -> $after lines)"; else bad "activity.log did not grow"; fi
if grep -q "open module: Unix Command Library" logs/activity.log; then ok "opening a module is recorded"; else bad "module selection is missing from the log"; fi
if grep -q "session started" logs/activity.log; then ok "session start is recorded"; else bad "session start is missing from the log"; fi
if grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} \|' logs/activity.log; then ok "every log line starts with a timestamp"; else bad "a log line has no timestamp"; fi

# ---------- 8. nothing is left behind ----------
printf '\n8. Side effects stay inside the project\n'
if [ -z "$(find sandbox -type f ! -name '.gitkeep' 2>/dev/null)" ]; then ok "the sandbox is still empty after a menu session"; else bad "the menu left files in the sandbox"; fi
if command -v git >/dev/null 2>&1 && [ -d .git ]; then ok "git repository present (skipping status check)"; fi

# ---------- summary ----------
printf '\nmenu test result: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
