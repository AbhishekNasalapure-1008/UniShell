#!/usr/bin/env bash
# ============================================================
# UniShell - Module 5 (Shell Programming) tests  (Phase 6)
# COMMAND: bash tests/test_07_shell.sh | PURPOSE: prove the example scripts run, the Module 5 demos work, and that no shell configuration file is ever executed or changed | MODULE: Shell Programming
# ============================================================

cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok()  { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); }

# sp_run "<function>" "<input>" - load common.sh and the module, run one demo,
# capture both normal output and error output.
sp_run() {
  printf '%s' "$2" | bash -c "source ./lib/common.sh; source ./modules/shell_programming.sh; $1" 2>&1
}

# chk "<needle>" "<haystack>" "<label>" - the haystack must contain the needle
chk() {
  if printf '%s' "$2" | grep -qF -- "$1"; then
    ok "$3"
  else
    bad "$3 (output did not contain: $1)"
  fi
}

printf 'Module 5 (Shell Programming) tests\n'

# ---------- 1. the files are present ----------
printf '\n1. The example files\n'
for f in examples/script_basics.sh examples/script_control.sh examples/script_advanced.sh examples/profile.sample; do
  if [ -r "$f" ]; then ok "$f exists and is readable"; else bad "$f is missing"; fi
done

# ---------- 2. syntax and line endings ----------
printf '\n2. Bash syntax and line endings\n'
for f in examples/script_basics.sh examples/script_control.sh examples/script_advanced.sh modules/shell_programming.sh; do
  if bash -n "$f" 2>/dev/null; then ok "bash -n accepts $f"; else bad "bash -n rejected $f"; fi
done
# CR characters break a shell script, so every shipped script must use LF only.
for f in examples/script_basics.sh examples/script_control.sh examples/script_advanced.sh examples/profile.sample; do
  if [ "$(grep -c $'\r' "$f")" -eq 0 ]; then ok "$f uses LF line endings"; else bad "$f contains CR characters"; fi
done

# ---------- 3. script_basics.sh really runs ----------
printf '\n3. examples/script_basics.sh\n'
basic_out="$(printf 'Ada Lovelace\n' | bash examples/script_basics.sh 2>&1)"
if [ -n "$basic_out" ]; then ok "the script produced output"; else bad "the script produced no output"; fi
chk 'COURSE (shell variable)       = Unix Programming' "$basic_out" "a plain shell variable was set"
chk 'a child sees LAB    as: UniShell' "$basic_out" "an exported variable is inherited by a child"
chk 'a child sees COURSE as: []' "$basic_out" "a plain variable is NOT inherited by a child"
chk 'LIMIT = 10 (marked readonly, so a later change would be refused)' "$basic_out" "readonly kept its value"
chk 'read stored the line in the variable who' "$basic_out" "read took the piped line"
chk 'the value of who is now: Ada Lovelace' "$basic_out" "the value read from input is correct"

# ---------- 4. script_control.sh really runs ----------
printf '\n4. examples/script_control.sh\n'
ctrl_out="$(bash examples/script_control.sh 2>&1)"
chk 'test : 7 is greater than 5' "$ctrl_out" "the test builtin branch ran"
chk '[ ]  : 7 is greater than 5' "$ctrl_out" "the [ ] form ran too"
chk 'both conditions are true: 7 is between 5 and 10' "$ctrl_out" "&& joined two conditions"
chk 'if/elif: 7 is medium (5 to 10)' "$ctrl_out" "if / elif picked the right branch"
chk 'i = 3' "$ctrl_out" "the while loop counted up to 3"
chk 'for:' "$ctrl_out" "the for loop ran"
case_lines="$(printf '%s' "$ctrl_out" | grep -c -- ' -> ')"
if [ "$case_lines" -eq 4 ]; then ok "case matched 4 values (4 lines printed)"; else bad "case printed $case_lines lines, expected 4"; fi

# ---------- 5. script_advanced.sh really runs ----------
printf '\n5. examples/script_advanced.sh\n'
adv_out="$(bash examples/script_advanced.sh one two three 2>&1)"
chk 'arguments: 3 of them (one two three)' "$adv_out" "the script saw all three arguments"
chk '  argument: three' "$adv_out" "shift walked to the last argument"
chk 'after the loop, $# = 0' "$adv_out" "shift emptied the argument list"
chk 'heredoc: this text came from a here-document.' "$adv_out" "the quoted here-document ran"
chk 'heredoc: $HOME stays literal because the marker was quoted.' "$adv_out" "a quoted marker stopped variable expansion"
chk 'heredoc: with an unquoted marker, HOME is expanded to /' "$adv_out" "an unquoted marker allowed variable expansion"
adv_last="$(printf '%s' "$adv_out" | tail -n 1)"
if [ "$adv_last" = "trap  : the EXIT trap ran, so cleanup always happens" ]; then
  ok "the EXIT trap ran last, after all the script's output"
else
  bad "the EXIT trap message was not the last line (got: $adv_last)"
fi

# ---------- 6. the Module 5 demos ----------
printf '\n6. Module 5 demonstration functions\n'
out="$(sp_run 'sp_demo_variables' '')"
chk 'environment variable LAB    = UniShell' "$out" "sp_demo_variables shows a shell variable"
chk 'a child sees COURSE as: []' "$out" "sp_demo_variables proves export is what children inherit"

out="$(sp_run 'sp_demo_read' 'Grace Hopper
')"
chk 'Grace Hopper' "$out" "sp_demo_read displays what read stored"
chk '$1=alpha  $2=beta  $3=gamma' "$out" "sp_demo_read shows the positional parameters"
chk 'readonly refused the second assignment' "$out" "sp_demo_read proves readonly blocks a second assignment"

out="$(sp_run 'sp_demo_exit_status' '')"
chk 'true  returned exit status 0' "$out" "sp_demo_exit_status reads the status of true"
chk 'false returned exit status 1' "$out" "sp_demo_exit_status reads the status of false"
chk 'false || ... printed this line (the left side failed)' "$out" "sp_demo_exit_status shows ||"

out="$(sp_run 'sp_demo_test_if' '')"
chk 'test : 7 -gt 5 is true' "$out" "sp_demo_test_if shows the test builtin"
chk '[ ]  : 7 -gt 5 is true' "$out" "sp_demo_test_if shows the [ ] form"
chk '7 is medium (5 to 10)' "$out" "sp_demo_test_if shows if / elif / else"

out="$(sp_run 'sp_demo_loops' '')"
chk 'cherry' "$out" "sp_demo_loops ran the for loop"
chk 'count 3' "$out" "sp_demo_loops ran the numeric for loop"
i_lines="$(printf '%s' "$out" | grep -c '    i = ')"
if [ "$i_lines" -eq 3 ]; then ok "the while loop ran exactly three times"; else bad "the while loop printed $i_lines iterations, expected 3"; fi

out="$(sp_run 'sp_demo_case' '')"
case_lines="$(printf '%s' "$out" | grep -c -- ' -> ')"
if [ "$case_lines" -eq 4 ]; then ok "sp_demo_case matched 4 values"; else bad "sp_demo_case printed $case_lines lines, expected 4"; fi

out="$(sp_run 'sp_demo_set_shift' '')"
chk 'set -- :  $# = 3,  $* = alpha beta gamma' "$out" "sp_demo_set_shift set the positional parameters"
chk 'after the loop, $# = 0' "$out" "sp_demo_set_shift used shift"
chk '$HOME is not expanded here, because the marker is quoted' "$out" "the quoted here-document stayed literal"
chk 'HOME is expanded here to /' "$out" "the unquoted here-document was expanded"

out="$(sp_run 'sp_demo_trap' '')"
chk 'the EXIT trap ran, so cleanup happens however we finish.' "$out" "sp_demo_trap fired the EXIT trap"

out="$(sp_run 'sp_demo_run_scripts' '')"
chk 'COURSE (shell variable)       = Unix Programming' "$out" "option 9 runs script_basics.sh"
chk 'if/elif: 7 is medium (5 to 10)' "$out" "option 9 runs script_control.sh"
chk 'trap  : the EXIT trap ran, so cleanup always happens' "$out" "option 9 runs script_advanced.sh"

# ---------- 7. .profile is only ever displayed ----------
printf '\n7. .profile safety\n'
if grep -nE '^[[:space:]]*\.' examples/profile.sample >/dev/null 2>&1; then
  bad "the sample file has an uncommented dot-source line"
else
  ok "the sample file has no uncommented dot-source line"
fi
if grep -qF '#         . "$HOME/.bashrc"' examples/profile.sample; then
  ok "the real .bashrc handover is shown as a comment only"
else
  bad "the .bashrc handover line is missing or not commented"
fi

# The demo must not touch the real ~/.profile. Its checksum is compared before
# and after, so the check looks at the real file rather than at UniShell's text.
if [ -f "${HOME:-/nonexistent}/.profile" ]; then
  before_sum="$(md5sum "${HOME}/.profile" | awk '{print $1}')"
  sp_run 'sp_demo_profile' '' >/dev/null 2>&1
  after_sum="$(md5sum "${HOME}/.profile" | awk '{print $1}')"
  if [ "$before_sum" = "$after_sum" ]; then
    ok "the real ~/.profile is unchanged after the demo (same checksum)"
  else
    bad "the real ~/.profile changed during the demo"
  fi
else
  ok "this machine has no ~/.profile, so there was nothing to change"
fi

out="$(sp_run 'sp_demo_profile' '')"
chk 'PATH="$HOME/bin:$PATH"' "$out" "the sample shows a PATH line"
chk 'never executed' "$out" "the sample states that it is never executed"

# ---------- 8. nothing typed is ever executed ----------
printf '\n8. Nothing typed is executed as code\n'
rm -f sp_marker_a sp_marker_b sp_marker_c 2>/dev/null
printf '%s\n\n\n\n' '; touch sp_marker_a' | bash -c "source ./lib/common.sh; source ./modules/shell_programming.sh; sp_demo_read" >/dev/null 2>&1
if [ ! -e sp_marker_a ]; then ok "a semicolon payload typed into read was not executed"; else bad "typed input was executed (sp_marker_a exists)"; rm -f sp_marker_a; fi

printf '%s\n\n\n\n' '$(touch sp_marker_b)' | bash -c "source ./lib/common.sh; source ./modules/shell_programming.sh; sp_demo_read" >/dev/null 2>&1
if [ ! -e sp_marker_b ]; then ok "a command substitution payload typed into read was not executed"; else bad "typed input was executed (sp_marker_b exists)"; rm -f sp_marker_b; fi

printf '%s\n\n\n\n' '`touch sp_marker_c`' | bash -c "source ./lib/common.sh; source ./modules/shell_programming.sh; sp_demo_read" >/dev/null 2>&1
if [ ! -e sp_marker_c ]; then ok "a backtick payload typed into read was not executed"; else bad "typed input was executed (sp_marker_c exists)"; rm -f sp_marker_c; fi

# ---------- 9. no eval anywhere ----------
printf '\n9. No eval in the shell programming files\n'
for f in modules/shell_programming.sh examples/script_basics.sh examples/script_control.sh examples/script_advanced.sh examples/profile.sample; do
  if grep -n '\beval\b' "$f" >/dev/null 2>&1; then bad "$f contains the word eval"; else ok "$f contains no eval"; fi
done

# ---------- 10. side effects stay out of the way ----------
printf '\n10. Nothing is left behind\n'
if [ -z "$(find sandbox -type f ! -name '.gitkeep' 2>/dev/null)" ]; then
  ok "the sandbox is still empty after the shell programming demos"
else
  bad "the shell programming demos left files in the sandbox"
fi
if [ ! -e injection_marker ] && [ ! -e sp_marker_a ] && [ ! -e sp_marker_b ] && [ ! -e sp_marker_c ]; then
  ok "no marker files were created in the project folder"
else
  bad "a marker file was created in the project folder"
fi

# ---------- summary ----------
printf '\nModule 5 test result: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
