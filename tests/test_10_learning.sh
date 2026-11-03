#!/usr/bin/env bash
# ============================================================
# UniShell - Module 9 and Module 10 (quiz, exercises, logs) tests   (Phase 9)
# COMMAND: bash tests/test_10_learning.sh | PURPOSE: prove the quiz scores answers, the exercises show hints and solutions, the activity log records timestamps and exit statuses, and every log stays inside ./logs | MODULE: 9 and 10
#
# The quiz and the log viewer are driven through the real menu with scripted
# input, exactly as a person would type it. The answers below are read from
# data/quiz_questions.txt, so the expected score is not a guess.
# ============================================================

cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok()  { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); }

chk() {
  if printf '%s' "$2" | grep -qF -- "$1"; then
    ok "$3"
  else
    bad "$3 (output did not contain: $1)"
  fi
}

MENU_OUT=""
MENU_RC=0
run_menu() {
  MENU_OUT="$(printf '%s' "$1" | bash ./unishell.sh 2>&1)"
  MENU_RC=$?
}
expect_in() {
  if printf '%s' "$MENU_OUT" | grep -qF -- "$1"; then ok "$2"; else bad "$2 (output did not contain: $1)"; fi
}
expect_not_in() {
  if printf '%s' "$MENU_OUT" | grep -qF -- "$1"; then bad "$2 (output contained: $1)"; else ok "$2"; fi
}

QUIZ_FILE="data/quiz_questions.txt"
EXERCISE_FILE="data/practice_exercises.txt"
LOG_FILE="logs/activity.log"

# How many lines the log already held before this test started. The format
# checks below look only at the lines this run adds, so they judge the code in
# front of us rather than whatever happened to be in the log already.
LOG_START="$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)"

printf 'Module 9 and 10 (learning and activity) tests\n'

# ---------- 1. the data files ----------
printf '\n1. The learning material\n'
if [ -r "$QUIZ_FILE" ]; then ok "$QUIZ_FILE exists and is readable"; else bad "$QUIZ_FILE is missing"; fi
if [ -r "$EXERCISE_FILE" ]; then ok "$EXERCISE_FILE exists and is readable"; else bad "$EXERCISE_FILE is missing"; fi

for field in 'TOPIC: ' 'QUESTION: ' 'OPTION A: ' 'OPTION B: ' 'OPTION C: ' 'OPTION D: ' 'ANSWER: ' 'HINT: ' 'EXPLANATION: '; do
  n="$(grep -c "^$field" "$QUIZ_FILE")"
  if [ "$n" -gt 0 ]; then ok "the question bank has $n of the field '$field'"; else bad "the question bank has no '$field' field"; fi
done

questions="$(grep -c '^### ' "$QUIZ_FILE")"
if [ "$questions" -ge 10 ]; then ok "the question bank holds $questions questions"; else bad "only $questions questions were found"; fi
# Every question needs one answer of each kind of field, or the quiz cannot score.
for field in 'QUESTION: ' 'OPTION A: ' 'OPTION B: ' 'OPTION C: ' 'OPTION D: ' 'ANSWER: ' 'HINT: ' 'EXPLANATION: '; do
  n="$(grep -c "^$field" "$QUIZ_FILE")"
  if [ "$n" -eq "$questions" ]; then ok "every question has a '$field' line ($n of $questions)"; else bad "'$field' appears $n times but there are $questions questions"; fi
done

bad_answers="$(grep -E '^ANSWER: ' "$QUIZ_FILE" | grep -cvE '^ANSWER: [ABCD]$')"
if [ "$bad_answers" -eq 0 ]; then ok "every ANSWER is a single letter A, B, C or D"; else bad "$bad_answers answers are not a single letter A-D"; fi

exercises="$(grep -c '^### ' "$EXERCISE_FILE")"
if [ "$exercises" -ge 5 ]; then ok "the exercise file holds $exercises exercises"; else bad "only $exercises exercises were found"; fi
for field in 'TOPIC: ' 'TASK: ' 'HINT: ' 'SOLUTION: ' 'EXPLAIN: '; do
  n="$(grep -c "^$field" "$EXERCISE_FILE")"
  if [ "$n" -eq "$exercises" ]; then ok "every exercise has a '$field' line ($n of $exercises)"; else bad "'$field' appears $n times but there are $exercises exercises"; fi
done

if grep -q $'\r' "$QUIZ_FILE" 2>/dev/null; then bad "$QUIZ_FILE uses CRLF line endings"; else ok "$QUIZ_FILE uses LF line endings"; fi
if grep -q $'\r' "$EXERCISE_FILE" 2>/dev/null; then bad "$EXERCISE_FILE uses CRLF line endings"; else ok "$EXERCISE_FILE uses LF line endings"; fi

# ---------- 2. the new module scripts ----------
printf '\n2. modules/quiz.sh and modules/logs.sh\n'
for f in modules/quiz.sh modules/logs.sh; do
  if bash -n "$f" 2>/dev/null; then ok "bash -n accepts $f"; else bad "bash -n rejected $f"; fi
  if grep -q 'COMMAND:' "$f"; then ok "$f documents its commands"; else bad "$f has no COMMAND comment"; fi
  if grep -n '\beval\b' "$f" >/dev/null 2>&1; then bad "$f contains the word eval"; else ok "$f contains no eval"; fi
done
if grep -qE 'bash -c|\|[[:space:]]*(bash|sh)([[:space:]]|$)|sh -c' modules/quiz.sh; then
  bad "modules/quiz.sh hands something to a shell"
else
  ok "modules/quiz.sh never hands anything to a shell"
fi
if grep -q 'log_activity_exit' modules/quiz.sh; then ok "the quiz records its score with an exit status"; else bad "the quiz does not record an exit status"; fi
if grep -q 'UNISHELL_ACTIVITY_LOG' modules/logs.sh; then ok "the log viewer reads the shared activity log"; else bad "the log viewer does not use the shared log path"; fi
# A redirection into a file would look like ">> \"$something\"". The words
# ">>" also appear in the explanation text, so the check looks for a redirect
# and not merely for the two characters.
if grep -qE '>>[[:space:]]*["$]' modules/logs.sh; then
  bad "the log viewer redirects its output into a file"
else
  ok "the log viewer only reads - it never redirects output into a file"
fi

# ---------- 3. all ten modules and the earlier tests are still here ----------
printf '\n3. Nothing was removed\n'
for f in modules/commands.sh modules/files.sh modules/permissions.sh modules/text_processing.sh \
         modules/shell_programming.sh modules/processes.sh modules/ipc.sh modules/system_calls.sh \
         modules/quiz.sh modules/logs.sh; do
  if [ -r "$f" ]; then ok "$f is present"; else bad "$f is missing"; fi
done
for f in tests/test_00_scaffold.sh tests/test_01_common.sh tests/test_02_menu.sh tests/test_03_commands.sh \
         tests/test_04_files.sh tests/test_05_permissions.sh tests/test_06_text.sh tests/test_07_shell.sh \
         tests/test_08_c.sh tests/test_09_ipc.sh; do
  if [ -r "$f" ]; then ok "$f is present"; else bad "$f is missing"; fi
done

# ---------- 4. the quiz scores a perfect run ----------
printf '\n4. The quiz: a perfect run of 11 answers\n'
# The answers below are the ANSWER lines of the question bank, in order.
run_menu '9
2
B
B
B
A
B
B
A
B
B
B
C

4

0
0
'
expect_in "Module 9 - Quiz and Practical Exercises" "module 9 opens its sub-menu"
expect_in "Question 1 of 11" "the first question is numbered out of the whole bank"
expect_in "Score: 11 correct out of 11." "every right answer produced a perfect score"
expect_in "A perfect run - every answer was right." "a perfect run is named as such"
expect_in "Why: pwd asks the kernel" "the explanation is shown after each answer"
expect_in "Score for this session" "the session score can be shown again"
expect_in "Questions answered : 11" "the session score remembers all 11 questions"
expect_in "Accuracy           : 100%" "the accuracy is worked out correctly"

correct_count="$(printf '%s' "$MENU_OUT" | grep -c 'Correct\.')"
if [ "$correct_count" -eq 11 ]; then ok "the word 'Correct.' appeared 11 times"; else bad "'Correct.' appeared $correct_count times, expected 11"; fi

# ---------- 5. the quiz: a hint, a wrong answer and stopping early ----------
printf '\n5. The quiz: a hint, a wrong answer and stopping early\n'
run_menu '9
2
h
A
q

0
0
'
expect_in "Hint: The name is short for" "typing h shows the hint for the question"
expect_in "Not quite - the answer is B." "a wrong answer is corrected"
expect_in "Score: 0 correct out of 1." "the score counts only the questions actually answered"
expect_not_in "A perfect run" "one wrong answer does not report a perfect run"
expect_not_in "Question 11 of 11" "typing q stopped the quiz before the last question"

# ---------- 6. the practice exercises ----------
printf '\n6. The practice exercises\n'
run_menu '9
3
1
y
y

0
0
'
expect_in "Practice exercises" "the exercise list is shown"
expect_in "---- Exercise 1" "choosing exercise 1 opens it"
expect_in "Task : List every entry" "the task is printed"
expect_in "Hint : One letter adds the hidden entries" "the hint is offered and printed"
expect_in "Solution : ls -la" "the worked solution is printed"
expect_in "Why      : -l prints the long form" "the explanation of the solution is printed"

# ---------- 7. the activity log records what happened ----------
printf '\n7. The activity log\n'
if [ -s "$LOG_FILE" ]; then ok "$LOG_FILE exists and holds entries"; else bad "$LOG_FILE is missing or empty"; fi

if grep -qF 'quiz attempt: 11 of 11 correct' "$LOG_FILE"; then ok "the perfect quiz attempt was recorded"; else bad "the perfect quiz attempt is missing from the log"; fi
if grep -qE 'quiz attempt: 11 of 11 correct.*\| exit=0' "$LOG_FILE"; then ok "the perfect attempt was recorded with exit=0"; else bad "the perfect attempt did not record an exit status of 0"; fi
if grep -qF 'quiz attempt: 0 of 1 correct' "$LOG_FILE"; then ok "the stopped attempt was recorded"; else bad "the stopped attempt is missing from the log"; fi
if grep -qE 'quiz attempt: 0 of 1 correct.*\| exit=1' "$LOG_FILE"; then ok "an imperfect attempt was recorded with a non-zero exit status"; else bad "the imperfect attempt did not record exit=1"; fi

bad_fields="$(tail -n +$((LOG_START + 1)) "$LOG_FILE" 2>/dev/null | awk -F'|' 'NF > 0 && NF != 4 { c++ } END { print c + 0 }')"
if [ "$bad_fields" -eq 0 ]; then ok "every log line written by this run has exactly the four fields time | module | action | status"; else bad "$bad_fields log line(s) written by this run do not have four fields"; fi
bad_times="$(tail -n +$((LOG_START + 1)) "$LOG_FILE" 2>/dev/null | grep -cvE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} \|')"
if [ "$bad_times" -eq 0 ]; then ok "every log line written by this run starts with a timestamp"; else bad "$bad_times log line(s) written by this run have no timestamp"; fi
if grep -qE '\| exit=[0-9]+' "$LOG_FILE"; then ok "exit statuses are stored as plain digits"; else bad "no exit= status was found in the log"; fi

# ---------- 8. the log viewer ----------
printf '\n8. Module 10 reads the log\n'
run_menu '10
2

0
0
'
expect_in "Module 10 - Activity Logs" "module 10 opens its sub-menu"
expect_in "Every line is: time | module | action | status" "the log format is explained before showing it"
expect_in "session started" "a real entry from the log is displayed"
expect_in "entries in total." "the number of entries is reported"

run_menu '10
5

6

0
0
'
expect_in "Entries for each module" "the per-module count is shown"
expect_in "MODULE" "the count table has a heading"
expect_in "did not finish cleanly" "the problem view explains what it looks for"
expect_in "exit=1" "an entry with a non-zero exit status is reported there"

# ---------- 9. logs live only inside ./logs ----------
printf '\n9. Every log stays inside ./logs\n'
# data/sample.log is practice material for the text-processing module, not a
# log UniShell writes, so this looks for the file UniShell actually creates.
stray="$(find . -path ./logs -prune -o -type f -name 'activity.log' -print 2>/dev/null)"
if [ -z "$stray" ]; then ok "the only activity.log anywhere is the one inside ./logs"; else bad "another activity.log exists: $stray"; fi
if grep -qF 'UNISHELL_ACTIVITY_LOG="$UNISHELL_LOGS/activity.log"' lib/common.sh; then ok "the log path is built from the ./logs directory"; else bad "the log path is not built from ./logs"; fi
if [ -f logs/activity.log ]; then ok "the activity log is logs/activity.log"; else bad "logs/activity.log was not found"; fi

# ---------- 10. the menu now offers both modules ----------
printf '\n10. The menu offers the new modules\n'
run_menu '9
0
0
'
expect_in "Module 9 - Quiz and Practical Exercises" "module 9 is implemented and reachable"
expect_not_in "Quiz and Practical Exercises is not implemented yet" "module 9 no longer claims to be unfinished"
if [ "$MENU_RC" -eq 0 ]; then ok "leaving module 9 exits cleanly"; else bad "the menu exited with status $MENU_RC"; fi

run_menu '10
0
0
'
expect_in "Module 10 - Activity Logs" "module 10 is implemented and reachable"
expect_not_in "Activity Logs is not implemented yet" "module 10 no longer claims to be unfinished"

# ---------- 11. nothing is left behind ----------
printf '\n11. Nothing is left behind\n'
leftovers="$(find sandbox -type f ! -name '.gitkeep' 2>/dev/null)"
if [ -z "$leftovers" ]; then ok "the sandbox holds no leftover files"; else bad "the sandbox holds leftovers: $leftovers"; fi

# ---------- summary ----------
printf '\nModule 9 and 10 test result: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
