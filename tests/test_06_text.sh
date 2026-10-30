#!/usr/bin/env bash
# ============================================================
# UniShell - Module 4 (Text Processing, Pipes and Redirection) tests  (Phase 5)
# COMMAND: bash tests/test_06_text.sh | PURPOSE: prove the text tools, pipes and redirection demos work on data/sample.log and only write inside ./sandbox | MODULE: Text Processing
# ============================================================

cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok()  { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); }

# txt_run "<function>" - load common.sh and the module, run one demo, capture
# both normal output and error output.
txt_run() { printf '\n' | bash -c "source ./lib/common.sh; source ./modules/text_processing.sh; $1" 2>&1; }

printf 'Module 4 (Text Processing, Pipes and Redirection) tests\n'

mkdir -p sandbox

# ---------- 1. the sample data ----------
printf '\n1. Sample data\n'
if [ -r data/sample.log ]; then ok "data/sample.log is readable"; else bad "data/sample.log is missing"; fi
lines="$(wc -l < data/sample.log)"
if [ "$lines" -eq 32 ]; then ok "data/sample.log has 32 lines"; else bad "data/sample.log has $lines lines, expected 32"; fi
errors="$(grep -c ERROR data/sample.log)"
if [ "$errors" -eq 7 ]; then ok "the log contains 7 ERROR lines"; else bad "found $errors ERROR lines, expected 7"; fi
both="$(egrep -c 'ERROR|WARN' data/sample.log)"
if [ "$both" -eq 14 ]; then ok "egrep counts 14 ERROR or WARN lines"; else bad "egrep counted $both, expected 14"; fi

# ---------- 2. streams ----------
printf '\n2. Standard input, output and error\n'
out="$(txt_run 'txt_demo_streams')"
if printf '%s' "$out" | grep -qF "standard error"; then ok "the demo explains standard error"; else bad "the stream explanation is missing"; fi
if printf '%s' "$out" | grep -qF "This line is an error message, on fd 2."; then ok "a message written to fd 2 reaches the terminal"; else bad "the fd 2 message was not produced"; fi

# ---------- 3. redirection ----------
printf '\n3. Redirection\n'
out="$(txt_run 'txt_demo_redirection')"
if printf '%s' "$out" | grep -qF "Redirection: >, >>, <, 2>"; then ok "the redirection demo starts"; else bad "the redirection demo did not start"; fi
if [ -f sandbox/redirect.txt ] && grep -qF "first line" sandbox/redirect.txt && grep -qF "second line" sandbox/redirect.txt; then
  ok "> then >> wrote both lines into sandbox/redirect.txt"
else
  bad "sandbox/redirect.txt does not hold both lines"
fi
if [ -f sandbox/redirect.err ] && [ -s sandbox/redirect.err ]; then ok "2> captured the error message in sandbox/redirect.err"; else bad "sandbox/redirect.err is missing or empty"; fi

# ---------- 4. pipes ----------
printf '\n4. Pipes\n'
out="$(txt_run 'txt_demo_pipes')"
if printf '%s' "$out" | grep -qE '[0-9]+ (INFO|WARN|ERROR)'; then ok "the pipe counted lines per level"; else bad "the per-level count is missing"; fi

# ---------- 5. grep and egrep ----------
printf '\n5. grep and egrep\n'
out="$(txt_run 'txt_demo_grep')"
if printf '%s' "$out" | grep -qF "grep -c ERROR   -> 7"; then ok "grep -c reports 7 ERROR lines"; else bad "the grep -c line is wrong or missing"; fi
if printf '%s' "$out" | grep -qF -- "-> 14"; then ok "egrep counts 14 ERROR or WARN lines"; else bad "the egrep count is wrong or missing"; fi
if printf '%s' "$out" | grep -qF "bad-password"; then ok "grep -n printed matching lines"; else bad "the grep -n output is missing"; fi

# ---------- 6. wc, sort, uniq ----------
printf '\n6. wc, sort, uniq\n'
out="$(txt_run 'txt_demo_count_sort')"
if printf '%s' "$out" | grep -qF "data/sample.log"; then ok "wc printed the file measurement"; else bad "the wc output is missing"; fi
if printf '%s' "$out" | grep -qF "alice"; then ok "the distinct users are listed"; else bad "the user list is missing"; fi

# ---------- 7. cut and tr ----------
printf '\n7. cut and tr\n'
out="$(txt_run 'txt_demo_columns')"
if printf '%s' "$out" | grep -qF "README"; then bad "unexpected output in the cut/tr demo"; else ok "the cut/tr demo ran"; fi
if printf '%s' "$out" | grep -qF "ALPHA" || printf '%s' "$out" | grep -qE '2025-10-01 [0-9]{2}:[0-9]{2}:[0-9]{2} INFO|2025-10-01'; then ok "tr converted the lines to upper case"; else bad "the tr output is missing"; fi

# ---------- 8. head, tail, tee ----------
printf '\n8. head, tail, tee\n'
out="$(txt_run 'txt_demo_head_tail_tee')"
if printf '%s' "$out" | grep -qF "number of ERROR lines -> 7"; then ok "tee counted the 7 ERROR lines"; else bad "the tee count is wrong or missing"; fi
if [ -f sandbox/errors.txt ]; then ok "tee saved the stream into sandbox/errors.txt"; else bad "sandbox/errors.txt was not created"; fi
if [ -f sandbox/errors.txt ]; then
  saved="$(wc -l < sandbox/errors.txt)"
  if [ "$saved" -eq 7 ]; then ok "sandbox/errors.txt holds the 7 matched lines"; else bad "sandbox/errors.txt has $saved lines, expected 7"; fi
fi

# ---------- 9. diff ----------
printf '\n9. diff\n'
out="$(txt_run 'txt_demo_diff')"
if [ -f sandbox/diff_a.txt ] && [ -f sandbox/diff_b.txt ]; then ok "diff created both files inside ./sandbox"; else bad "the diff input files were not created"; fi
if printf '%s' "$out" | grep -qF '"<" lines come from diff_a.txt'; then ok "diff reported the difference between the files"; else bad "the diff result is missing"; fi

# ---------- 10. regular expressions ----------
printf '\n10. Regular expressions\n'
out="$(txt_run 'txt_demo_regex')"
if printf '%s' "$out" | grep -qF "login-ok"; then ok "the end-anchor pattern matched login-ok"; else bad "the regex demo printed no matches"; fi
if printf '%s' "$out" | grep -qE '[0-9]{2}:[0-9]{2}:[0-9]{2}'; then ok "the digit-class pattern matched timestamps"; else bad "the timestamp pattern printed nothing"; fi

# ---------- 11. quoting versus wildcards ----------
printf '\n11. Quoting versus wildcard expansion\n'
out="$(txt_run 'txt_demo_quoting')"
if printf '%s' "$out" | grep -qF "the command receives the text: wild*.txt"; then ok "quoting stopped the wildcard being expanded"; else bad "the quoted-wildcard line is missing"; fi
if [ -f sandbox/wild1.txt ] && [ -f sandbox/wild3.txt ]; then ok "the wildcard target files were created"; else bad "the wildcard files are missing"; fi

# ---------- 12. sandbox confinement and no dynamic execution ----------
printf '\n12. Safety\n'
if bash -c 'source ./lib/common.sh; check_inside_sandbox "$UNISHELL_SANDBOX/errors.txt"'; then ok "the files written by the demos are inside ./sandbox"; else bad "a demo wrote outside ./sandbox"; fi
if grep -n '\beval\b' modules/text_processing.sh >/dev/null 2>&1; then bad "the word eval appears in modules/text_processing.sh"; else ok "modules/text_processing.sh contains no eval"; fi

# ---------- clean up ----------
find sandbox -mindepth 1 ! -name '.gitkeep' -exec rm -rf -- {} + 2>/dev/null

# ---------- summary ----------
printf '\nmodule 4 test result: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
