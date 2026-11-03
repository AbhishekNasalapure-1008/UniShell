#!/usr/bin/env bash
# ============================================================
# UniShell - Module 10: Activity Logs   (Phase 9)
# ============================================================
# Shows the record of what has been done in UniShell. Every entry is written
# by log_activity() and log_activity_exit() in lib/common.sh into ONE file:
#
#     logs/activity.log
#
# That is the only place UniShell ever writes a log, so nothing can end up
# scattered around the machine. Each line has exactly four fields separated
# by " | ":
#
#     timestamp | module | action | status
#
# The timestamp is written with date '+%Y-%m-%d %H:%M:%S'. The status is
# either a short word (OK, requested, skipped, error, refused) or "exit=N",
# which is the exit status a piece of work returned. Text typed by the user
# is never stored, so the log cannot collect anything private.
#
# This module only READS the log. When it wants to record that the log was
# viewed it uses the same shared logger as every other module, so even that
# entry obeys the one-file rule.
#
# This file is SOURCED by unishell.sh, which then calls module_logs.
# ============================================================

# The one and only log file.
LOGS_FILE="$UNISHELL_ACTIVITY_LOG"

# A fixed list of modules for the "filter by module" option. The user picks a
# NUMBER from this list, so no typed text is ever used as a search pattern.
LOGS_MODULES=(
  menu unishell ipc quiz logs
  commands files permissions text_processing
  shell_programming processes system_calls
)

# ------------------------------------------------------------
# Sub-menu
# ------------------------------------------------------------
module_logs() {
  local choice

  while :; do
    section_title "Module 10 - Activity Logs"
    printf '  %s\n' " 1. How the log works"
    printf '  %s\n' " 2. Show the whole activity log"
    printf '  %s\n' " 3. Show the most recent entries"
    printf '  %s\n' " 4. Show just one module"
    printf '  %s\n' " 5. Count the entries for each module"
    printf '  %s\n' " 6. Show the entries that did not finish cleanly"
    printf '  %s\n' " 0. Back to the main menu"
    printf '\n'

    if ! ask_choice "Choose an option (0-6): " 0 6; then
      return 0
    fi
    choice="$UNISHELL_CHOICE"

    case "$choice" in
      1) logs_explain ;;
      2) logs_show_all ;;
      3) logs_show_recent ;;
      4) logs_filter_module ;;
      5) logs_count_by_module ;;
      6) logs_show_problems ;;
      0) return 0 ;;
    esac
  done
}

# ------------------------------------------------------------
# Small helpers
# ------------------------------------------------------------
# logs_ready - true when there is something to show. It explains honestly why
# there is nothing, instead of printing an empty screen.
logs_ready() {
  if [ ! -e "$LOGS_FILE" ]; then
    msg_warn "There is no log file yet at $LOGS_FILE."
    return 1
  fi
  if [ ! -r "$LOGS_FILE" ]; then
    msg_err "The log exists but cannot be read: $LOGS_FILE"
    return 1
  fi
  if [ ! -s "$LOGS_FILE" ]; then
    msg_info "The log exists but is still empty, so nothing has been recorded yet."
    return 1
  fi
  return 0
}

# logs_line_count - how many entries the log holds.
logs_line_count() {
  # COMMAND: wc -l < file | PURPOSE: count the lines without printing the file name | MODULE: 4
  wc -l < "$LOGS_FILE" 2>/dev/null || printf '0\n'
}

# ------------------------------------------------------------
# 1. How the log works
# ------------------------------------------------------------
logs_explain() {
  section_title "How the activity log works"

  printf '  Every action in UniShell is appended to one file:\n'
  printf '    %s\n\n' "$LOGS_FILE"

  printf '  Each line has four fields, separated by " | ":\n\n'
  printf '    %-21s %s\n' "time"   "when the action happened, as YYYY-MM-DD HH:MM:SS"
  printf '    %-21s %s\n' "module" "which part of UniShell did it (menu, ipc, quiz, ...)"
  printf '    %-21s %s\n' "action" "a short description of what was done"
  printf '    %-21s %s\n' "status" "how it ended: OK, skipped, error, or exit=0, exit=1, ..."
  printf '\n'

  printf '  Two rules keep the log safe and useful:\n'
  printf '    - it is written with >> so earlier entries are never erased;\n'
  printf '    - text typed by the user is never stored, so no secret can leak in.\n\n'

  printf '  Where the file lives right now:\n'
  # COMMAND: ls -l | PURPOSE: show the log file's size and timestamp | MODULE: Unix Basics
  if [ -e "$LOGS_FILE" ]; then
    ls -l "$LOGS_FILE"
    printf '\n  It holds %s entries.\n' "$(logs_line_count)"
  else
    printf '    (the file is created the first time something is logged)\n'
  fi

  log_activity "logs" "explained how the activity log works" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 2. Show the whole activity log
# ------------------------------------------------------------
logs_show_all() {
  section_title "The whole activity log"

  if ! logs_ready; then
    log_activity "logs" "viewed the log (nothing to show)" "empty"
    press_enter_to_continue
    return 0
  fi

  printf '  Every line is: time | module | action | status\n\n'
  # COMMAND: cat | PURPOSE: print the log exactly as stored, changing nothing | MODULE: Unix Basics
  cat "$LOGS_FILE"

  printf '\n  %s entries in total.\n' "$(logs_line_count)"
  log_activity "logs" "viewed the whole activity log" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 3. Show the most recent entries
# ------------------------------------------------------------
logs_show_recent() {
  section_title "The most recent entries"
  local n

  if ! logs_ready; then
    press_enter_to_continue
    return 0
  fi

  if ! ask_choice "How many of the newest entries? (1-50): " 1 50; then
    return 0
  fi
  n="$UNISHELL_CHOICE"

  printf '\n'
  # COMMAND: tail -n | PURPOSE: print only the last N lines of the log | MODULE: Unix Basics
  tail -n "$n" "$LOGS_FILE"

  printf '\n  Showing the newest %s of %s entries.\n' "$n" "$(logs_line_count)"
  log_activity "logs" "viewed the last $n entries" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 4. Show just one module
# ------------------------------------------------------------
logs_filter_module() {
  section_title "Show the entries for one module"
  local i=1 m

  if ! logs_ready; then
    press_enter_to_continue
    return 0
  fi

  for m in "${LOGS_MODULES[@]}"; do
    printf '  %2s. %s\n' "$i" "$m"
    i=$((i + 1))
  done
  printf '\n'

  # The number is checked against the length of the fixed list, so the chosen
  # module is always one of the names above - never text the user typed.
  if ! ask_choice "Choose a module (1-${#LOGS_MODULES[@]}): " 1 "${#LOGS_MODULES[@]}"; then
    return 0
  fi
  m="${LOGS_MODULES[$((UNISHELL_CHOICE - 1))]}"

  printf '\n  Entries for module "%s":\n\n' "$m"
  # COMMAND: awk -F'|' | PURPOSE: print only the lines whose second field is this module | MODULE: Text Processing
  # The spaces around each field are trimmed first, because log_activity pads
  # the module and action columns to line them up.
  awk -F'|' -v want="$m" '
    {
      name = $2
      gsub(/^[ \t]+|[ \t]+$/, "", name)
      if (name == want) print
    }
  ' "$LOGS_FILE"

  log_activity "logs" "filtered the log by module: $m" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 5. Count the entries for each module
# ------------------------------------------------------------
logs_count_by_module() {
  section_title "Entries for each module"

  if ! logs_ready; then
    press_enter_to_continue
    return 0
  fi

  printf '  %-20s %s\n' "MODULE" "ENTRIES"
  printf '  %-20s %s\n' "--------------------" "-------"
  # COMMAND: awk | PURPOSE: count how many lines belong to each module | MODULE: Text Processing
  # COMMAND: sort | PURPOSE: keep the table in the same order every time | MODULE: Unix Basics
  awk -F'|' '
    {
      name = $2
      gsub(/^[ \t]+|[ \t]+$/, "", name)
      count[name]++
    }
    END {
      for (name in count) printf "  %-20s %d\n", name, count[name]
    }
  ' "$LOGS_FILE" | sort

  printf '\n  %s entries in total across every module.\n' "$(logs_line_count)"
  log_activity "logs" "counted the entries for each module" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 6. Show the entries that did not finish cleanly
# ------------------------------------------------------------
logs_show_problems() {
  section_title "Entries that did not finish cleanly"
  local out

  if ! logs_ready; then
    press_enter_to_continue
    return 0
  fi

  printf '  These are the entries whose status says something went wrong: a word\n'
  printf '  such as "error" or "refused", or an "exit=N" where N is not 0.\n\n'

  # COMMAND: awk -F'|' | PURPOSE: keep only the lines whose status shows a problem | MODULE: Text Processing
  out="$(awk -F'|' '
    {
      status = $4
      gsub(/^[ \t]+|[ \t]+$/, "", status)
      bad = (status == "error" || status == "refused" \
             || (status ~ /^exit=/ && status != "exit=0"))
      if (bad) print
    }
  ' "$LOGS_FILE")"

  if [ -z "$out" ]; then
    msg_ok "Nothing to report: no entry ended with an error or a non-zero exit status."
  else
    printf '%s\n' "$out"
  fi

  log_activity "logs" "reviewed the entries that did not finish cleanly" "OK"
  press_enter_to_continue
}
