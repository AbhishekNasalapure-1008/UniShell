#!/usr/bin/env bash
# ============================================================
# UniShell - unit tests for lib/common.sh  (Phase 3)
# COMMAND: bash tests/test_01_common.sh | PURPOSE: prove the shared helpers validate input and guard the sandbox | MODULE: 2
#
# Every check runs in its own child shell, so one failure cannot change the
# result of the next one.
# ============================================================

cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok()  { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); }

# common_run "<shell code>" - starts a fresh shell, loads common.sh and runs
# the code in it. This is how the helpers are used in the real program.
common_run() { bash -c "source ./lib/common.sh; $1"; }

printf 'Unit tests for lib/common.sh\n'

# ---------- 1. the file itself ----------
printf '\n1. File sanity\n'
if [ -f lib/common.sh ]; then ok "lib/common.sh exists"; else bad "lib/common.sh is missing"; fi
# COMMAND: grep -q | PURPOSE: detect carriage returns that break bash | MODULE: 2
if grep -q $'\r' lib/common.sh 2>/dev/null; then
  bad "lib/common.sh uses CRLF line endings"
else
  ok "lib/common.sh uses LF line endings"
fi
# COMMAND: bash -n | PURPOSE: check the script for syntax errors without running it | MODULE: 5
if bash -n lib/common.sh; then ok "lib/common.sh passes the bash -n syntax check"; else bad "lib/common.sh has a syntax error"; fi

# ---------- 2. paths ----------
printf '\n2. Paths are built from the project root\n'
root="$(common_run 'printf %s "$UNISHELL_ROOT"')"
if [ "$root" = "$(pwd)" ]; then ok "UNISHELL_ROOT points at the project root"; else bad "UNISHELL_ROOT is '$root'"; fi
sandbox_var="$(common_run 'printf %s "$UNISHELL_SANDBOX"')"
if [ "$sandbox_var" = "$(pwd)/sandbox" ]; then ok "UNISHELL_SANDBOX points at ./sandbox"; else bad "UNISHELL_SANDBOX is '$sandbox_var'"; fi

# ---------- 3. colours ----------
printf '\n3. Colours\n'
red="$(common_run 'printf %s "$C_RED"')"
if [ -z "$red" ]; then ok "colours are disabled when output is not a terminal"; else bad "colour codes leaked into piped output"; fi

# ---------- 4. sandbox guard: is_safe_name ----------
printf '\n4. is_safe_name accepts plain names\n'
for name in notes.txt practice data.log report1; do
  if common_run "is_safe_name $name"; then ok "accepts '$name'"; else bad "rejected the safe name '$name'"; fi
done

printf '\n5. is_safe_name refuses anything dangerous\n'
unsafe_names=("" "." ".." "-rf" "a/b" "/etc/passwd" "../escape" "two words.txt")
for name in "${unsafe_names[@]}"; do
  if common_run "is_safe_name \"$name\""; then bad "accepted the unsafe name '$name'"; else ok "refuses '$name'"; fi
done

# ---------- 5. sandbox_path ----------
printf '\n6. sandbox_path\n'
built="$(common_run 'sandbox_path notes.txt')"
if [ "$built" = "$(pwd)/sandbox/notes.txt" ]; then ok "builds a path inside the sandbox"; else bad "sandbox_path returned '$built'"; fi
if common_run 'sandbox_path ../escape' >/dev/null 2>&1; then bad "sandbox_path accepted '../escape'"; else ok "refuses to build a path outside the sandbox"; fi

# ---------- 6. check_inside_sandbox ----------
printf '\n7. check_inside_sandbox\n'
if common_run 'check_inside_sandbox "$UNISHELL_SANDBOX/notes.txt"'; then ok "accepts a file inside the sandbox"; else bad "rejected a valid sandbox file"; fi
if common_run 'check_inside_sandbox "$UNISHELL_SANDBOX"'; then ok "accepts the sandbox directory itself"; else bad "rejected the sandbox directory"; fi
if common_run 'check_inside_sandbox "$UNISHELL_SANDBOX/../Makefile"'; then bad "accepted a path that escapes with .."; else ok "refuses sandbox/../Makefile"; fi
if common_run 'check_inside_sandbox /etc/passwd'; then bad "accepted /etc/passwd"; else ok "refuses /etc/passwd"; fi
if common_run 'check_inside_sandbox /tmp/unishell-escape'; then bad "accepted a path in /tmp"; else ok "refuses a path in /tmp"; fi

# ---------- 7. logging ----------
printf '\n8. log_activity\n'
before="$(wc -l < logs/activity.log 2>/dev/null || echo 0)"
common_run 'log_activity "unittest" "common.sh unit test" "OK"' >/dev/null
after="$(wc -l < logs/activity.log)"
if [ "$after" -eq "$((before + 1))" ]; then ok "appends exactly one line"; else bad "appended $((after - before)) lines instead of one"; fi

last="$(tail -n 1 logs/activity.log)"
fields="$(printf '%s' "$last" | awk -F'|' '{print NF}')"
if [ "$fields" -eq 4 ]; then ok "log line has 4 fields: time, module, action, status"; else bad "log line has $fields fields: $last"; fi
# COMMAND: grep -E | PURPOSE: check the timestamp shape of a log line | MODULE: 4
if printf '%s' "$last" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} \|'; then
  ok "log line starts with a date and time"
else
  bad "log line has no timestamp: $last"
fi
if printf '%s' "$last" | grep -q 'unittest'; then ok "module name is recorded"; else bad "module name missing from the log"; fi

# ---------- 8. ask_choice ----------
printf '\n9. ask_choice validation\n'
out="$(printf '7\n' | common_run 'if ask_choice "Number: " 0 10; then printf "OK:%s" "$UNISHELL_CHOICE"; fi')"
if [ "$out" = "Number: OK:7" ]; then ok "accepts 7 in the range 0-10"; else bad "unexpected result: '$out'"; fi

out="$(printf ' 7 \n' | common_run 'if ask_choice "Number: " 0 10; then printf "OK:%s" "$UNISHELL_CHOICE"; fi')"
if [ "$out" = "Number: OK:7" ]; then ok "accepts ' 7 ' with surrounding spaces"; else bad "unexpected result: '$out'"; fi

out="$(printf 'abc\n3\n' | common_run 'if ask_choice "n: " 0 10; then printf "OK:%s" "$UNISHELL_CHOICE"; fi' 2>&1)"
case "$out" in
  *"is not a number"*"OK:3") ok "refuses text, then accepts 3" ;;
  *) bad "unexpected result: '$out'" ;;
esac

out="$(printf '99\n00\n' | common_run 'if ask_choice "n: " 0 10; then printf "OK:%s" "$UNISHELL_CHOICE"; fi' 2>&1)"
case "$out" in
  *"Please choose a number from 0 to 10"*"OK:0") ok "refuses 99, then reads 00 as 0 (base 10, not octal)" ;;
  *) bad "unexpected result: '$out'" ;;
esac

out="$(printf -- '-1\n0\n' | common_run 'if ask_choice "n: " 0 10; then printf "OK:%s" "$UNISHELL_CHOICE"; fi' 2>&1)"
case "$out" in
  *"is not a number"*"OK:0") ok "refuses -1 as a non-number, then accepts 0" ;;
  *) bad "unexpected result: '$out'" ;;
esac

out="$(printf '5' | common_run 'if ask_choice "n: " 0 10; then printf "OK:%s" "$UNISHELL_CHOICE"; fi')"
case "$out" in
  *"OK:5") ok "accepts a final line with no trailing newline" ;;
  *) bad "unexpected result: '$out'" ;;
esac

printf '' | common_run 'ask_choice "n: " 0 10' >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 1 ]; then ok "returns 1 when input ends (Ctrl-D)"; else bad "expected exit status 1 on end of input, got $rc"; fi

# ---------- 9. ask_yes_no ----------
printf '\n10. ask_yes_no\n'
if printf 'y\n' | common_run 'ask_yes_no "Continue?"'; then ok "y means yes"; else bad "y was not accepted as yes"; fi
if printf 'N\n' | common_run 'ask_yes_no "Continue?"'; then bad "N was treated as yes"; else ok "N means no"; fi
out="$(printf 'maybe\nn\n' | common_run 'if ask_yes_no "Continue?"; then printf YES; else printf NO; fi' 2>&1)"
case "$out" in
  *"Please answer y or n"*"NO") ok "re-asks on an unclear answer" ;;
  *) bad "unexpected result: '$out'" ;;
esac

# ---------- 10. sourcing twice ----------
printf '\n11. Double sourcing is harmless\n'
out="$(common_run 'source ./lib/common.sh; printf %s "$UNISHELL_COMMON_LOADED"')"
if [ "$out" = "1" ]; then ok "common.sh can be sourced twice without resetting anything"; else bad "unexpected result: '$out'"; fi

# ---------- summary ----------
printf '\ncommon.sh unit test result: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
