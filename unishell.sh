#!/usr/bin/env bash
# ============================================================
# UniShell - entry point
# COMMAND: ./unishell.sh | PURPOSE: start the menu-driven learning application | MODULE: 2
#
# Start it with ./unishell.sh or with bash unishell.sh
# ============================================================

# set -u turns a mistyped variable name into an error instead of an empty
# value. set -e is deliberately NOT used: this program handles its own errors
# and one failed command must never close the menu.
set -u

UNISHELL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_FILE="$UNISHELL_ROOT/lib/common.sh"

if [ ! -r "$COMMON_FILE" ]; then
  printf 'UniShell: cannot read %s\n' "$COMMON_FILE" >&2
  exit 1
fi

# COMMAND: source | PURPOSE: load colours, input handling, logging and the sandbox guard | MODULE: 2
source "$COMMON_FILE"

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------
show_menu() {
  show_banner
  printf '\n'
  printf ' %s\n' "1. Unix Command Library"
  printf ' %s\n' "2. File and Directory Management"
  printf ' %s\n' "3. File Permissions Lab"
  printf ' %s\n' "4. Text Processing and Pipes"
  printf ' %s\n' "5. Shell Programming Lab"
  printf ' %s\n' "6. Process Management Lab"
  printf ' %s\n' "7. Inter-Process Communication Lab"
  printf ' %s\n' "8. C System Calls Demonstrations"
  printf ' %s\n' "9. Quiz and Practical Exercises"
  printf ' %s\n' "10. Activity Logs"
  printf ' %s\n' "0. Exit"
  printf '\n'
  printf ' Practice files are kept inside: %s\n' "$UNISHELL_SANDBOX"
  printf '\n'
}

# ------------------------------------------------------------
# Dispatch
# ------------------------------------------------------------
# The number the user typed is only ever COMPARED with these values. The text
# on the right of each ")" is a fixed function name that already exists in the
# program, so no text typed at the prompt can ever run as a command.
handle_choice() {
  case "$1" in
    1)  run_module commands          "Unix Command Library"             4 ;;
    2)  run_module files             "File and Directory Management"    4 ;;
    3)  run_module permissions       "File Permissions Lab"             5 ;;
    4)  run_module text_processing   "Text Processing and Pipes"        5 ;;
    5)  run_module shell_programming "Shell Programming Lab"            6 ;;
    6)  run_module processes         "Process Management Lab"           7 ;;
    7)  run_module ipc               "Inter-Process Communication Lab"  8 ;;
    8)  run_module system_calls      "C System Calls Demonstrations"    7 ;;
    9)  run_module quiz              "Quiz and Practical Exercises"     9 ;;
    10) run_module logs              "Activity Logs"                    9 ;;
    0)  return 1 ;;   # returning 1 tells the menu loop to leave
    *)  msg_err "Only numbers 0 to 10 are valid." ;;
  esac
  return 0
}

# run_module <key> <title> <phase>
# Loads modules/<key>.sh when it exists and calls module_<key>. When the module
# has not been written yet it says so honestly instead of pretending to work.
run_module() {
  local key="$1" title="$2" phase="$3"
  local file="$UNISHELL_ROOT/modules/${key}.sh"
  local func="module_${key}"

  log_activity "menu" "open module: $title" "requested"
  printf '\n'

  if [ -f "$file" ]; then
    # COMMAND: source | PURPOSE: load this module's functions into the current shell | MODULE: 2
    source "$file"
  fi

  # COMMAND: declare -F | PURPOSE: check a function exists before calling it | MODULE: 2
  if declare -F "$func" >/dev/null 2>&1; then
    "$func"
    log_activity "menu" "closed module: $title" "OK"
  else
    msg_warn "$title is not implemented yet."
    msg_info "It is scheduled for Phase $phase of the build plan."
    log_activity "menu" "module not ready: $title" "skipped"
    press_enter_to_continue
  fi
}

quit_unishell() {
  log_activity "unishell" "session ended" "bye"
  printf '\n'
  msg_ok "Thank you for using UniShell. Goodbye."
  exit 0
}

# COMMAND: trap | PURPOSE: leave cleanly when the user presses Ctrl-C | MODULE: 2
on_interrupt() {
  printf '\n'
  log_activity "unishell" "interrupted by signal" "SIGINT/SIGTERM"
  msg_warn "Interrupted. Leaving UniShell cleanly."
  exit 130   # 128 + 2 is the usual exit status for SIGINT
}
trap on_interrupt INT TERM

# ------------------------------------------------------------
# Main loop
# ------------------------------------------------------------
main() {
  # COMMAND: mkdir -p | PURPOSE: make sure ./sandbox and ./logs exist before use | MODULE: 1
  ensure_runtime_dirs || exit 1
  log_activity "unishell" "session started" "OK"

  while :; do
    show_menu
    # COMMAND: ask_choice | PURPOSE: read a validated number, never a command | MODULE: 2
    if ! ask_choice "Enter your choice (0-10): " 0 10; then
      printf '\n'
      msg_warn "Input ended (Ctrl-D). Leaving UniShell cleanly."
      log_activity "unishell" "input ended (EOF)" "bye"
      exit 0
    fi
    handle_choice "$UNISHELL_CHOICE" || quit_unishell
  done
}

main "$@"
