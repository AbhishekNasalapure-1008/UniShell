#!/usr/bin/env bash
# ============================================================
# UniShell - Module 9: Quiz and Practical Exercises   (Phase 9)
# ============================================================
# An interactive quiz of multiple-choice questions, plus a set of practice
# exercises with hints and worked solutions.
#
# The questions live in data/quiz_questions.txt and the exercises in
# data/practice_exercises.txt. Both are plain text, so new material can be
# added without changing any code. This file only reads those files.
#
# Safety: every answer is a single letter compared against a fixed set
# (A, B, C and D). Nothing typed by the user is echoed back, and nothing at
# all is executed. The SOLUTION lines of the exercises are only ever printed
# for the student to read, never run.
#
# This file is SOURCED by unishell.sh, which then calls module_quiz.
# ============================================================

# Where the material lives.
QUIZ_FILE="$UNISHELL_DATA/quiz_questions.txt"
EXERCISE_FILE="$UNISHELL_DATA/practice_exercises.txt"

# Question data. The arrays are (re)filled by quiz_load().
QU_TOTAL=0
Q_TOPIC=(); Q_TEXT=(); Q_A=(); Q_B=(); Q_C=(); Q_D=(); Q_ANS=(); Q_HINT=(); Q_EXP=()

# Exercise data, filled by ex_load().
EX_TOTAL=0
E_TOPIC=(); E_TASK=(); E_HINT=(); E_SOL=(); E_EXP=()

# The score keeps its value while UniShell is running, so it survives leaving
# and re-entering this module. Starting from 0 the first time.
QU_CORRECT="${QU_CORRECT:-0}"
QU_ASKED="${QU_ASKED:-0}"

# ------------------------------------------------------------
# Sub-menu
# ------------------------------------------------------------
module_quiz() {
  local choice

  while :; do
    section_title "Module 9 - Quiz and Practical Exercises"
    printf '  %s\n' " 1. How the quiz works"
    printf '  %s\n' " 2. Start the quiz (multiple choice, scored)"
    printf '  %s\n' " 3. Practice exercises with hints and solutions"
    printf '  %s\n' " 4. Show the score for this session"
    printf '  %s\n' " 0. Back to the main menu"
    printf '\n'

    if ! ask_choice "Choose an option (0-4): " 0 4; then
      return 0
    fi
    choice="$UNISHELL_CHOICE"

    case "$choice" in
      1) quiz_explain ;;
      2) quiz_start ;;
      3) quiz_practice ;;
      4) quiz_show_score ;;
      0) return 0 ;;
    esac
  done
}

# ------------------------------------------------------------
# Loading the question bank
# ------------------------------------------------------------
# quiz_load reads the whole file once and fills the arrays. It returns non-zero
# when the file is missing or empty, so the caller can say so honestly.
quiz_load() {
  local file="$QUIZ_FILE" n=0 line

  Q_TOPIC=(); Q_TEXT=(); Q_A=(); Q_B=(); Q_C=(); Q_D=(); Q_ANS=(); Q_HINT=(); Q_EXP=()
  QU_TOTAL=0

  if [ ! -r "$file" ]; then
    return 1
  fi

  # COMMAND: while read | PURPOSE: read the question bank one line at a time | MODULE: 2
  # The "|| [ -n "$line" ]" keeps the last line even when the file has no
  # final newline.
  while IFS= read -r line || [ -n "$line" ]; do
    # COMMAND: case | PURPOSE: pick out each field by its fixed prefix | MODULE: 2
    case "$line" in
      '### '*)          n=$((n + 1)) ;;
      'TOPIC: '*)       Q_TOPIC[$n]="${line#TOPIC: }" ;;
      'QUESTION: '*)    Q_TEXT[$n]="${line#QUESTION: }" ;;
      'OPTION A: '*)    Q_A[$n]="${line#OPTION A: }" ;;
      'OPTION B: '*)    Q_B[$n]="${line#OPTION B: }" ;;
      'OPTION C: '*)    Q_C[$n]="${line#OPTION C: }" ;;
      'OPTION D: '*)    Q_D[$n]="${line#OPTION D: }" ;;
      'ANSWER: '*)      Q_ANS[$n]="${line#ANSWER: }" ;;
      'HINT: '*)        Q_HINT[$n]="${line#HINT: }" ;;
      'EXPLANATION: '*) Q_EXP[$n]="${line#EXPLANATION: }" ;;
    esac
  done < "$file"

  QU_TOTAL=$n
  [ "$QU_TOTAL" -gt 0 ]
}

# ex_load does the same job for the practice exercises.
ex_load() {
  local file="$EXERCISE_FILE" n=0 line

  E_TOPIC=(); E_TASK=(); E_HINT=(); E_SOL=(); E_EXP=()
  EX_TOTAL=0

  if [ ! -r "$file" ]; then
    return 1
  fi

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '### '*)      n=$((n + 1)) ;;
      'TOPIC: '*)   E_TOPIC[$n]="${line#TOPIC: }" ;;
      'TASK: '*)    E_TASK[$n]="${line#TASK: }" ;;
      'HINT: '*)    E_HINT[$n]="${line#HINT: }" ;;
      'SOLUTION: '*) E_SOL[$n]="${line#SOLUTION: }" ;;
      'EXPLAIN: '*) E_EXP[$n]="${line#EXPLAIN: }" ;;
    esac
  done < "$file"

  EX_TOTAL=$n
  [ "$EX_TOTAL" -gt 0 ]
}

# ------------------------------------------------------------
# 1. How the quiz works
# ------------------------------------------------------------
quiz_explain() {
  section_title "How the quiz works"

  printf '  The questions live in a plain text file:\n'
  printf '    %s\n\n' "$QUIZ_FILE"

  printf '  Each question has one line per field:\n'
  printf '    TOPIC, QUESTION, OPTION A to D, ANSWER, HINT, EXPLANATION\n\n'

  printf '  When you take the quiz:\n'
  printf '    - the question and its four options are printed;\n'
  printf '    - you answer with a single letter: A, B, C or D;\n'
  printf '    - type h for a hint before you answer, or q to stop;\n'
  printf '    - after each answer the explanation is shown, right or wrong;\n'
  printf '    - the score is kept so you can see it again from option 4.\n\n'

  printf '  Nothing you type is executed or written to a log: only the letter is\n'
  printf '  compared with the stored answer.\n'

  if quiz_load; then
    printf '\n  This copy of the bank holds %s question(s).\n' "$QU_TOTAL"
  else
    msg_warn "The question bank could not be read: $QUIZ_FILE"
  fi

  log_activity "quiz" "explained how the quiz works" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# Reading one answer
# ------------------------------------------------------------
# quiz_ask_answer reads one of a fixed set of letters. Nothing typed is echoed
# back, so a stray control character cannot reach the terminal.
# Returns: 0 answered (letter in $UNISHELL_QUIZ_ANSWER), 2 hint, 3 stop,
#          1 input ended.
quiz_ask_answer() {
  local answer

  while :; do
    printf 'Your answer (A-D, h = hint, q = stop): '
    # COMMAND: read -r | PURPOSE: read one line exactly as typed | MODULE: 2
    if ! read -r answer; then
      if [ -z "$answer" ]; then
        printf '\n'
        return 1
      fi
    fi
    case "$answer" in
      a|A) UNISHELL_QUIZ_ANSWER="A"; return 0 ;;
      b|B) UNISHELL_QUIZ_ANSWER="B"; return 0 ;;
      c|C) UNISHELL_QUIZ_ANSWER="C"; return 0 ;;
      d|D) UNISHELL_QUIZ_ANSWER="D"; return 0 ;;
      h|H) return 2 ;;
      q|Q) return 3 ;;
      *)   msg_warn "Please type A, B, C or D (or h for a hint, q to stop)." ;;
    esac
  done
}

# ------------------------------------------------------------
# 2. Start the quiz
# ------------------------------------------------------------
quiz_start() {
  section_title "Quiz"

  if ! quiz_load; then
    msg_err "The question bank could not be read: $QUIZ_FILE"
    log_activity "quiz" "question bank missing" "error"
    press_enter_to_continue
    return 0
  fi

  printf '  %s question(s). Answer with A, B, C or D.\n' "$QU_TOTAL"
  printf '  Type h at any question for a hint, or q to stop and see the score.\n'

  # The score for this run starts at zero. The session totals are kept in
  # QU_CORRECT and QU_ASKED and only ever grow, so option 4 can show how the
  # whole session has gone across several attempts.
  local correct=0 asked=0 i=1 rc

  # COMMAND: while | PURPOSE: walk through every question in the bank | MODULE: 2
  while [ "$i" -le "$QU_TOTAL" ]; do
    printf '\nQuestion %s of %s  [%s]\n' "$i" "$QU_TOTAL" "${Q_TOPIC[$i]:-Quiz}"
    printf '  %s\n\n' "${Q_TEXT[$i]:-}"
    printf '    A) %s\n' "${Q_A[$i]:-}"
    printf '    B) %s\n' "${Q_B[$i]:-}"
    printf '    C) %s\n' "${Q_C[$i]:-}"
    printf '    D) %s\n' "${Q_D[$i]:-}"
    printf '\n'

    # Keep asking until the question is answered, stopped or input ends.
    while :; do
      quiz_ask_answer
      rc=$?
      if [ "$rc" -eq 0 ]; then
        break
      elif [ "$rc" -eq 2 ]; then
        printf '  Hint: %s\n\n' "${Q_HINT[$i]:-No hint for this question.}"
      else
        # rc 1 (input ended) or rc 3 (the user typed q): finish the quiz.
        quiz_finish "$correct" "$asked"
        press_enter_to_continue
        return 0
      fi
    done

    asked=$((asked + 1))
    if [ "$UNISHELL_QUIZ_ANSWER" = "${Q_ANS[$i]:-}" ]; then
      correct=$((correct + 1))
      msg_ok "Correct."
    else
      msg_warn "Not quite - the answer is ${Q_ANS[$i]:-?}."
    fi
    printf '  Why: %s\n' "${Q_EXP[$i]:-}"

    i=$((i + 1))
  done

  quiz_finish "$correct" "$asked"
  press_enter_to_continue
}

# quiz_finish <correct> <asked> - report the score and record it in the log.
quiz_finish() {
  local correct="$1" asked="$2" status="1"

  printf '\n'
  if [ "$asked" -eq 0 ]; then
    msg_info "No questions were answered, so there is no score yet."
  else
    msg_ok "Score: $correct correct out of $asked."
    if [ "$correct" -eq "$asked" ]; then
      msg_info "A perfect run - every answer was right."
      status="0"
    fi
  fi

  QU_CORRECT=$((QU_CORRECT + correct))
  QU_ASKED=$((QU_ASKED + asked))

  # The status field records how the attempt went: exit=0 is a perfect score.
  log_activity_exit "quiz" "quiz attempt: $correct of $asked correct" "$status"
}

# ------------------------------------------------------------
# 4. Show the session score
# ------------------------------------------------------------
quiz_show_score() {
  section_title "Score for this session"

  if [ "$QU_ASKED" -eq 0 ]; then
    msg_info "No quiz questions have been answered yet in this session."
  else
    printf '  Questions answered : %s\n' "$QU_ASKED"
    printf '  Correct answers    : %s\n' "$QU_CORRECT"
    # COMMAND: $(( )) | PURPOSE: work out a percentage with the shell's own arithmetic | MODULE: 2
    printf '  Accuracy           : %s%%\n' "$((QU_CORRECT * 100 / QU_ASKED))"
  fi

  printf '\n'
  msg_info "The score is kept only while UniShell is running. Every attempt is"
  msg_info "recorded in logs/activity.log, which module 10 can show you."

  log_activity "quiz" "showed the session score" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 3. Practice exercises
# ------------------------------------------------------------
quiz_practice() {
  local i choice rc

  section_title "Practice exercises"

  if ! ex_load; then
    msg_err "The exercise file could not be read: $EXERCISE_FILE"
    log_activity "quiz" "exercise file missing" "error"
    press_enter_to_continue
    return 0
  fi

  printf '  Each exercise is a small task to try in your own terminal. UniShell\n'
  printf '  shows the task, offers a hint, and then shows the worked solution.\n'
  printf '  It never runs the solution for you.\n\n'

  i=1
  while [ "$i" -le "$EX_TOTAL" ]; do
    printf '  %2s. [%s] %s\n' "$i" "${E_TOPIC[$i]:-General}" "${E_TASK[$i]:-}"
    i=$((i + 1))
  done
  printf '  %2s. All of them, one after another\n' "$((EX_TOTAL + 1))"
  printf '\n'

  if ! ask_choice "Choose an exercise (1-$((EX_TOTAL + 1))): " 1 $((EX_TOTAL + 1)); then
    return 0
  fi
  choice="$UNISHELL_CHOICE"

  if [ "$choice" -eq $((EX_TOTAL + 1)) ]; then
    i=1
    while [ "$i" -le "$EX_TOTAL" ]; do
      quiz_show_exercise "$i"
      i=$((i + 1))
    done
    log_activity "quiz" "worked through every practice exercise" "OK"
    press_enter_to_continue
    return 0
  fi

  quiz_show_exercise "$choice"
  log_activity "quiz" "worked through practice exercise $choice" "OK"
  press_enter_to_continue
}

# quiz_show_exercise <number> - one task, its hint and its worked solution.
quiz_show_exercise() {
  local n="$1"

  printf '\n---- Exercise %s  [%s] ----\n' "$n" "${E_TOPIC[$n]:-General}"
  printf '  Task : %s\n' "${E_TASK[$n]:-}"

  # ask_yes_no returns 1 for "no" and also when input has ended, so the pause
  # below is skipped safely if there is nobody left to answer.
  if ask_yes_no "  Show a hint first?"; then
    printf '  Hint : %s\n' "${E_HINT[$n]:-No hint for this exercise.}"
  fi

  if ask_yes_no "  Show the worked solution?"; then
    printf '  Solution : %s\n' "${E_SOL[$n]:-}"
    printf '  Why      : %s\n' "${E_EXP[$n]:-}"
  else
    printf '  (The solution was not shown. Come back to it any time.)\n'
  fi
}
