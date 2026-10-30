#!/usr/bin/env bash
# ============================================================
# UniShell - Module 4: Text Processing, Pipes and Redirection
# ============================================================
# Teaches standard input / output / error, the operators > >> < 2>, pipes,
# regular expressions and quoting versus wildcard expansion, then shows safe
# examples of grep, egrep, wc, sort, uniq, cut, tr, head, tail, tee and diff.
#
# The examples read data/sample.log, a small fixed log file that ships with
# UniShell. Anything written goes into ./sandbox only.
#
# This file is SOURCED by unishell.sh, which then calls module_text_processing.
# ============================================================

TXT_LOG="${UNISHELL_DATA}/sample.log"

# ------------------------------------------------------------
# Sub-menu
# ------------------------------------------------------------
module_text_processing() {
  local choice

  if [ ! -r "$TXT_LOG" ]; then
    msg_err "Cannot read the sample log: $TXT_LOG"
    log_activity "text" "sample log missing" "error"
    return 0
  fi

  # COMMAND: mkdir -p | PURPOSE: make sure ./sandbox exists before anything is written | MODULE: Unix Basics
  mkdir -p "$UNISHELL_SANDBOX" 2>/dev/null

  while :; do
    section_title "Module 4 - Text Processing, Pipes and Redirection"
    printf '  %s\n' "  Sample data: data/sample.log ($(wc -l < "$TXT_LOG") lines)"
    printf '\n'
    printf '  %s\n' " 1. Standard input, output and error"
    printf '  %s\n' " 2. Redirection: >, >>, <, 2>"
    printf '  %s\n' " 3. Pipes: |"
    printf '  %s\n' " 4. Search with grep and egrep"
    printf '  %s\n' " 5. Count and order: wc, sort, uniq"
    printf '  %s\n' " 6. Columns and characters: cut, tr"
    printf '  %s\n' " 7. head, tail and tee"
    printf '  %s\n' " 8. Compare two files with diff"
    printf '  %s\n' " 9. Regular expressions"
    printf '  %s\n' "10. Quoting versus wildcard expansion"
    printf '  %s\n' " 0. Back to the main menu"
    printf '\n'

    if ! ask_choice "Choose an option (0-10): " 0 10; then
      return 0
    fi
    choice="$UNISHELL_CHOICE"

    case "$choice" in
      1)  txt_demo_streams ;;
      2)  txt_demo_redirection ;;
      3)  txt_demo_pipes ;;
      4)  txt_demo_grep ;;
      5)  txt_demo_count_sort ;;
      6)  txt_demo_columns ;;
      7)  txt_demo_head_tail_tee ;;
      8)  txt_demo_diff ;;
      9)  txt_demo_regex ;;
      10) txt_demo_quoting ;;
      0)  return 0 ;;
    esac
  done
}

# ------------------------------------------------------------
# 1. Streams
# ------------------------------------------------------------
txt_demo_streams() {
  section_title "Standard input, output and error"

  printf 'Every program starts with three open channels (file descriptors):\n'
  printf '  fd 0 = standard input   (where it reads from, usually the keyboard)\n'
  printf '  fd 1 = standard output  (normal results)\n'
  printf '  fd 2 = standard error   (diagnostics, kept separate)\n\n'

  printf 'This line is normal output, on fd 1.\n'
  # COMMAND: >&2 | PURPOSE: write to standard error (fd 2) instead of standard output (fd 1) | MODULE: Text Processing
  printf 'This line is an error message, on fd 2.\n' >&2

  printf '\nKeeping them separate is what lets you save results and still see\n'
  printf 'errors, or the other way round. A program can also read its input:\n\n'
  # COMMAND: | | PURPOSE: feed one command's output into the next command's input | MODULE: Text Processing
  printf 'alpha\nbeta\ngamma\n' | cat

  printf '\n'
  msg_info "fd 1 and fd 2 are separate streams even though both reach the screen"
  msg_info "by default. The next option shows how to send them to files."
  log_activity "text" "demo: streams" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 2. Redirection
# ------------------------------------------------------------
txt_demo_redirection() {
  local out="$UNISHELL_SANDBOX/redirect.txt"
  local err="$UNISHELL_SANDBOX/redirect.err"

  section_title "Redirection: >, >>, <, 2>"

  printf '1. ">" creates the file if needed and OVERWRITES it:\n'
  # COMMAND: > | PURPOSE: redirect standard output, overwriting the file | MODULE: Text Processing
  printf 'first line\n' > "$out"
  printf '   written. The file now holds one line.\n'

  printf '\n2. ">>" APPENDS to the end of the file:\n'
  # COMMAND: >> | PURPOSE: redirect standard output, adding to the end of the file | MODULE: Text Processing
  printf 'second line\n' >> "$out"
  # COMMAND: cat | PURPOSE: print the file so the result is visible | MODULE: Unix Basics
  cat "$out"

  printf '\n3. "<" feeds a FILE into a command instead of the keyboard:\n'
  # COMMAND: < | PURPOSE: read standard input from a file | MODULE: Text Processing
  grep line < "$out"

  printf '\n4. "2>" sends only standard ERROR to a file:\n'
  printf '   (ls is asked about a name that does not exist)\n'
  # COMMAND: 2> | PURPOSE: redirect only standard error into a file | MODULE: Text Processing
  ls -- "$UNISHELL_SANDBOX/no-such-file" 2> "$err"
  printf '   the message did not reach the screen; it is in the file:\n'
  # COMMAND: cat | PURPOSE: show the captured error message | MODULE: Unix Basics
  cat "$err"

  printf '\n5. ">file 2>&1" sends BOTH streams to the same file:\n'
  # COMMAND: > file 2>&1 | PURPOSE: merge standard output and standard error into one file | MODULE: Text Processing
  ls -- "$UNISHELL_SANDBOX/no-such-file" "$UNISHELL_SANDBOX" > "$err" 2>&1
  printf '   now the file holds the listing AND the error message.\n'

  printf '\n'
  msg_info "> and >> change fd 1, < changes fd 0, 2> changes fd 2."
  msg_info "2>&1 means 'make fd 2 point where fd 1 points'."
  msg_info "Everything here is written inside ./sandbox."
  log_activity "text" "demo: redirection" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 3. Pipes
# ------------------------------------------------------------
txt_demo_pipes() {
  section_title "Pipes: one program's output becomes the next one's input"

  printf 'Count the log lines by level (column 3):\n'
  # COMMAND: cut | sort | uniq -c | PURPOSE: split out one column and count how often each value appears | MODULE: Text Processing
  cut -d' ' -f3 "$TXT_LOG" | sort | uniq -c

  printf '\nThe five most frequent whole lines:\n'
  # COMMAND: sort | uniq -c | sort -rn | head | PURPOSE: group equal lines and show the commonest first | MODULE: Text Processing
  sort "$TXT_LOG" | uniq -c | sort -rn | head -n 5

  printf '\n'
  msg_info "A pipe connects fd 1 of the left program straight to fd 0 of the"
  msg_info "right program, with no temporary file in between."
  msg_info "Each program runs at the same time, so the data flows through."
  log_activity "text" "demo: pipes" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 4. grep and egrep
# ------------------------------------------------------------
txt_demo_grep() {
  section_title "Search with grep and egrep"

  printf 'Count the ERROR lines (-c counts matches):\n'
  # COMMAND: grep -c | PURPOSE: count the lines that match a pattern | MODULE: Text Processing
  printf '  grep -c ERROR   -> %s\n' "$(grep -c ERROR "$TXT_LOG")"

  printf '\nThe first three ERROR lines, with their line numbers (-n):\n'
  # COMMAND: grep -n | PURPOSE: print matching lines with their line numbers | MODULE: Text Processing
  grep -n ERROR "$TXT_LOG" | head -n 3

  printf '\nERROR or WARN, using an extended regular expression (egrep):\n'
  # COMMAND: egrep | PURPOSE: match either ERROR or WARN using the | alternative | MODULE: Text Processing
  printf '  egrep -c "ERROR|WARN"  -> %s\n' "$(egrep -c 'ERROR|WARN' "$TXT_LOG")"

  printf '\nLines that do NOT contain INFO (-v inverts the match):\n'
  # COMMAND: grep -v | PURPOSE: print the lines that do NOT match | MODULE: Text Processing
  grep -v INFO "$TXT_LOG" | head -n 3

  printf '\n'
  msg_info "grep uses basic regular expressions, egrep uses the extended form."
  msg_info "egrep is the old name for 'grep -E', which is why | and ( ) work plainly."
  msg_info "Common options: -c count, -n line number, -i ignore case, -v invert."
  log_activity "text" "demo: grep and egrep" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 5. wc, sort, uniq
# ------------------------------------------------------------
txt_demo_count_sort() {
  section_title "Count and order: wc, sort, uniq"

  printf 'Measure the file with wc (lines, words, bytes):\n'
  # COMMAND: wc -l -w -c | PURPOSE: count lines, words and bytes | MODULE: Text Processing
  wc -l -w -c "$TXT_LOG"

  printf '\nHow many times each level appears:\n'
  # COMMAND: cut | sort | uniq -c | PURPOSE: count each distinct value in one column | MODULE: Text Processing
  cut -d' ' -f3 "$TXT_LOG" | sort | uniq -c

  printf '\nThe distinct users who appear (column 5), in order:\n'
  # COMMAND: cut | sort -u | PURPOSE: list each distinct value once | MODULE: Text Processing
  cut -d' ' -f5 "$TXT_LOG" | sort -u

  printf '\n'
  msg_info "uniq only compares neighbouring lines, so the input must be sorted"
  msg_info "first; that is why sort and uniq almost always appear together."
  msg_info "sort -u removes duplicates; sort -rn orders numbers from large to small."
  log_activity "text" "demo: wc, sort, uniq" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 6. cut and tr
# ------------------------------------------------------------
txt_demo_columns() {
  section_title "Columns and characters: cut, tr"

  printf 'cut -d" " -f3 keeps only the level column (field 3):\n'
  # COMMAND: cut -d -f | PURPOSE: print one field, chosen by a delimiter | MODULE: Text Processing
  cut -d' ' -f3 "$TXT_LOG" | head -n 3

  printf '\ncut -d" " -f5 keeps only the user column (field 5):\n'
  # COMMAND: cut -d -f | PURPOSE: print a different field of the same lines | MODULE: Text Processing
  cut -d' ' -f5 "$TXT_LOG" | head -n 3

  printf '\nThe first three lines converted to UPPER CASE by tr:\n'
  # COMMAND: tr a-z A-Z | PURPOSE: change every lower-case letter to upper case | MODULE: Text Processing
  tr 'a-z' 'A-Z' < "$TXT_LOG" | head -n 3

  printf '\nRuns of spaces squeezed into one by tr -s:\n'
  # COMMAND: tr -s ' ' | PURPOSE: squeeze repeated spaces into a single space | MODULE: Text Processing
  printf 'one    two     three\n' | tr -s ' '

  printf '\n'
  msg_info "cut picks COLUMNS (by delimiter or by character position)."
  msg_info "tr changes or removes CHARACTERS and reads only its standard input,"
  msg_info "so it needs a pipe or a '<' redirection."
  log_activity "text" "demo: cut and tr" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 7. head, tail, tee
# ------------------------------------------------------------
txt_demo_head_tail_tee() {
  local saved="$UNISHELL_SANDBOX/errors.txt"

  section_title "head, tail and tee"

  printf 'The first 3 lines (head):\n'
  # COMMAND: head -n | PURPOSE: print the first lines of the input | MODULE: Text Processing
  head -n 3 "$TXT_LOG"

  printf '\nThe last 3 lines (tail):\n'
  # COMMAND: tail -n | PURPOSE: print the last lines of the input | MODULE: Text Processing
  tail -n 3 "$TXT_LOG"

  printf '\nCount the ERROR lines while also SAVING them (tee):\n'
  # COMMAND: tee | PURPOSE: copy the stream to a file and still pass it on | MODULE: Text Processing
  printf '  number of ERROR lines -> %s\n' "$(grep ERROR "$TXT_LOG" | tee "$saved" | wc -l)"
  printf '  the same lines are now stored in sandbox/errors.txt:\n'
  # COMMAND: cat | PURPOSE: show the file tee created | MODULE: Unix Basics
  cat "$saved"

  printf '\n'
  msg_info "head and tail are how you peek at a large file cheaply."
  msg_info "tee splits a pipe: the data goes to the screen (or the next program)"
  msg_info "AND to a file at the same time. tee -a appends instead of overwriting."
  log_activity "text" "demo: head, tail, tee" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 8. diff
# ------------------------------------------------------------
txt_demo_diff() {
  local a="$UNISHELL_SANDBOX/diff_a.txt"
  local b="$UNISHELL_SANDBOX/diff_b.txt"

  section_title "Compare two files with diff"

  # COMMAND: > | PURPOSE: write the first file to compare | MODULE: Text Processing
  printf 'alpha\nbeta\ngamma\n' > "$a"
  # COMMAND: > | PURPOSE: write the second file to compare | MODULE: Text Processing
  printf 'alpha\nBETA\ngamma\ndelta\n' > "$b"

  printf 'diff_a.txt : alpha / beta / gamma\n'
  printf 'diff_b.txt : alpha / BETA / gamma / delta\n\n'

  # COMMAND: diff | PURPOSE: compare two files line by line | MODULE: Text Processing
  if diff -- "$a" "$b"; then
    msg_ok "The two files are identical."
  else
    printf '  "<" lines come from diff_a.txt, ">" lines come from diff_b.txt.\n'
  fi

  printf '\n'
  msg_info "diff exit status: 0 means identical, 1 means different, 2 means error."
  msg_info "That is why 'if diff a b' is the usual way to test two files in a script."
  log_activity "text" "demo: diff" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 9. Regular expressions
# ------------------------------------------------------------
txt_demo_regex() {
  section_title "Regular expressions"

  printf 'A regular expression describes a PATTERN of text.\n\n'

  printf 'Lines that begin with a date and time (^ anchors the start):\n'
  # COMMAND: grep ^pattern | PURPOSE: match lines that begin with the pattern | MODULE: Text Processing
  grep '^2025-10-01 09:0' "$TXT_LOG" | head -n 3

  printf '\nLines that end with the word login-ok ($ anchors the end):\n'
  # COMMAND: grep pattern$ | PURPOSE: match lines that end with the pattern | MODULE: Text Processing
  grep 'login-ok$' "$TXT_LOG" | head -n 3

  printf '\nEvery HH:MM:SS time, using a character class and a repeat (egrep):\n'
  # COMMAND: egrep [0-9]{2} | PURPOSE: match two digits, repeated to build h:m:s | MODULE: Text Processing
  egrep '[0-9]{2}:[0-9]{2}:[0-9]{2}' "$TXT_LOG" | head -n 2

  printf '\nThe users alice or dave, using a group and an alternative:\n'
  # COMMAND: egrep (a|b) | PURPOSE: match one of two alternatives inside a group | MODULE: Text Processing
  egrep ' (alice|dave) ' "$TXT_LOG" | head -n 2

  printf '\n'
  msg_info "^ start   $ end   . any character   * zero or more   + one or more"
  msg_info "[0-9] a digit   [abc] one of these   {2} exactly two   ( ) group   | or"
  msg_info "Basic grep needs + ? { } ( ) escaped; egrep (grep -E) does not."
  log_activity "text" "demo: regular expressions" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 10. Quoting versus wildcard expansion
# ------------------------------------------------------------
txt_demo_quoting() {
  section_title "Quoting versus wildcard expansion"

  # COMMAND: touch | PURPOSE: create files for the wildcard to match | MODULE: Text Processing
  touch -- "$UNISHELL_SANDBOX/wild1.txt" "$UNISHELL_SANDBOX/wild2.txt" "$UNISHELL_SANDBOX/wild3.txt" 2>/dev/null

  printf 'The SHELL expands a wildcard BEFORE the command runs.\n'
  printf 'In ./sandbox there are wild1.txt, wild2.txt and wild3.txt.\n\n'

  printf '1. Unquoted "wild*.txt" : the shell replaces it with the names:\n'
  # COMMAND: ls wild*.txt | PURPOSE: let the shell expand the * wildcard into matching names | MODULE: Text Processing
  ( cd "$UNISHELL_SANDBOX" && ls -- wild*.txt )

  printf '\n2. Quoted "wild*.txt" : the quotes stop the expansion, so it stays literal:\n'
  # COMMAND: printf "wild*.txt" | PURPOSE: show that quoting prevents the wildcard from being expanded | MODULE: Text Processing
  ( cd "$UNISHELL_SANDBOX" && printf '  the command receives the text: %s\n' "wild*.txt" )

  printf '\n3. Double quotes still expand a variable, single quotes never do:\n'
  name="UniShell"
  # COMMAND: printf "$name" | PURPOSE: show double quotes allow $variables to expand | MODULE: Text Processing
  printf '  double quotes : %s\n' "$name"
  # COMMAND: printf '$name' | PURPOSE: show single quotes keep the text exactly as typed | MODULE: Text Processing
  printf '  single quotes : %s\n' '$name'

  printf '\n'
  msg_info "Single quotes: everything inside is literal, including $ and *."
  msg_info "Double quotes: $variable, command substitution and \\ still work,"
  msg_info "               but a * stays literal."
  msg_info "Unquoted: the shell expands wildcards and splits the text on spaces."
  log_activity "text" "demo: quoting and wildcards" "OK"
  press_enter_to_continue
}
