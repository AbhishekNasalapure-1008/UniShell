#!/usr/bin/env bash
# ============================================================
# UniShell - Module 1: Unix Command Library
# ============================================================
# Shows beginner-friendly explanations of Unix commands (purpose, syntax,
# example, expected output, practical uses and syllabus mapping) and runs a
# few safe demonstrations.
#
# This file is SOURCED by unishell.sh, which then calls module_commands.
# Nothing typed by the user is ever executed: text is only compared with the
# names listed in data/command_library.txt.
# ============================================================

# COMMAND: (path) | PURPOSE: point at the text file that holds the explanations | MODULE: Unix Basics
CMDLIB_FILE="${UNISHELL_DATA}/command_library.txt"

# ------------------------------------------------------------
# Reading the library file
# ------------------------------------------------------------

# cmdlib_entries - print one command name per line, in file order.
# COMMAND: awk | PURPOSE: print the second word of every "### name" header | MODULE: Text Processing
cmdlib_entries() {
  awk '/^### / { print $2 }' "$CMDLIB_FILE" 2>/dev/null
}

# cmdlib_has <name> - true when the library contains an entry for <name>.
cmdlib_has() {
  local name="$1" entry
  for entry in $(cmdlib_entries); do
    [ "$entry" = "$name" ] && return 0
  done
  return 1
}

# cmdlib_show <name> - print the whole block that belongs to <name>.
# COMMAND: awk | PURPOSE: print only the lines between this header and the next one | MODULE: Text Processing
cmdlib_show() {
  awk -v want="$1" '/^### / { inside = ($2 == want) } inside { print }' "$CMDLIB_FILE"
}

# ------------------------------------------------------------
# Sub-menu
# ------------------------------------------------------------
module_commands() {
  local choice

  if [ ! -r "$CMDLIB_FILE" ]; then
    msg_err "Cannot read the command library: $CMDLIB_FILE"
    log_activity "commands" "library file missing" "error"
    return 0
  fi

  while :; do
    section_title "Module 1 - Unix Command Library"
    printf '  %s\n' "1. List every command in the library"
    printf '  %s\n' "2. Explain one command"
    printf '  %s\n' "3. Run safe live demonstrations"
    printf '  %s\n' "4. About passwd and su (explained, never run)"
    printf '  %s\n' "0. Back to the main menu"
    printf '\n'

    if ! ask_choice "Choose an option (0-4): " 0 4; then
      return 0            # input ended, so leave this module
    fi
    choice="$UNISHELL_CHOICE"

    case "$choice" in
      1) cmdlib_list ;;
      2) cmdlib_explain ;;
      3) cmdlib_demos ;;
      4) cmdlib_privileged ;;
      0) return 0 ;;
    esac
  done
}

# ------------------------------------------------------------
# 1. List
# ------------------------------------------------------------
cmdlib_list() {
  local name count=0
  section_title "Commands covered by UniShell"

  # The names are simple words with no spaces, so the shell's word splitting
  # is safe here and each name ends up on its own line.
  for name in $(cmdlib_entries); do
    count=$((count + 1))
    printf '  %2d. %s\n' "$count" "$name"
  done

  printf '\n  Total: %d commands.\n' "$count"
  log_activity "commands" "listed the command library" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 2. Explain one command
# ------------------------------------------------------------
cmdlib_explain() {
  local name
  section_title "Explain a command"

  if ! ask_text "Type a command name (for example: grep): "; then
    msg_warn "Nothing was entered."
    press_enter_to_continue
    return 0
  fi
  name="$UNISHELL_INPUT"

  # The name is checked before it is ever printed back, so control characters
  # or an escape sequence cannot be pushed onto the terminal.
  if ! is_safe_name "$name"; then
    msg_err "Please type one plain command name, with no spaces or slashes."
    press_enter_to_continue
    return 0
  fi

  printf '\n'
  if cmdlib_has "$name"; then
    cmdlib_show "$name"
    log_activity "commands" "explained command: $name" "OK"
  else
    msg_err "There is no entry for '$name' in the library."
    msg_info "Choose option 1 to see the commands that are covered."
    log_activity "commands" "command not in library" "not-found"
  fi
  press_enter_to_continue
}

# ------------------------------------------------------------
# 4. passwd and su - explained, never executed
# ------------------------------------------------------------
cmdlib_privileged() {
  section_title "passwd and su - explained, never run"
  printf '  %s\n' "These two commands change the real system, so UniShell only explains"
  printf '  %s\n' "them. It never executes them and never asks for a password."
  printf '\n'

  # COMMAND: (nothing is executed here) | PURPOSE: teach a privileged command without running it | MODULE: Permissions
  cmp_show_passwd
  printf '\n'
  cmp_show_su

  log_activity "commands" "explained passwd and su (not executed)" "OK"
  press_enter_to_continue
}

cmp_show_passwd() {
  cmdlib_show passwd
}

cmp_show_su() {
  cmdlib_show su
}

# ------------------------------------------------------------
# 3. Safe live demonstrations
# ------------------------------------------------------------
cmdlib_demos() {
  local choice
  while :; do
    section_title "Safe live demonstrations"
    printf '  %s\n' "1. echo and printf - printing text"
    printf '  %s\n' "2. date and cal - date and calendar"
    printf '  %s\n' "3. who and pwd - sessions and current directory"
    printf '  %s\n' "4. type - how the shell sees a name"
    printf '  %s\n' "5. ls - listing a directory, hidden files, HOME and PATH"
    printf '  %s\n' "6. Shell builtins: read, test, readonly"
    printf '  %s\n' "7. Shell builtins: set, shift, trap"
    printf '  %s\n' "0. Back"
    printf '\n'

    if ! ask_choice "Choose an option (0-7): " 0 7; then
      return 0
    fi
    choice="$UNISHELL_CHOICE"

    case "$choice" in
      1) cmdlib_demo_echo ;;
      2) cmdlib_demo_date ;;
      3) cmdlib_demo_ident ;;
      4) cmdlib_demo_type ;;
      5) cmdlib_demo_ls ;;
      6) cmdlib_demo_read ;;
      7) cmdlib_demo_set ;;
      0) return 0 ;;
    esac
  done
}

cmdlib_demo_echo() {
  section_title "echo and printf"
  # COMMAND: echo | PURPOSE: print text and then a newline | MODULE: Unix Basics
  echo "Hello from echo"
  # COMMAND: echo -n | PURPOSE: print text without the trailing newline | MODULE: Unix Basics
  echo -n "no newline yet... "
  echo "(the line ends here)"
  # COMMAND: printf | PURPOSE: print text using a format string | MODULE: Unix Basics
  printf 'Name: %-8s Score: %3d\n' "Ann" 90
  printf 'Name: %-8s Score: %3d\n' "Bob" 7
  printf '\n'
  msg_info "echo always adds a newline; printf adds one only when the format has \\n."
  msg_info "%-8s pads the name to 8 characters, %3d pads the number to 3."
  log_activity "commands" "demo: echo and printf" "OK"
  press_enter_to_continue
}

cmdlib_demo_date() {
  section_title "date and cal"
  # COMMAND: date | PURPOSE: print the current date and time | MODULE: Unix Basics
  date
  # COMMAND: date +format | PURPOSE: print only the chosen fields | MODULE: Unix Basics
  printf 'Timestamp: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
  printf 'Year     : %s\n' "$(date '+%Y')"
  printf '\n'
  # COMMAND: cal | PURPOSE: print the calendar of the current month | MODULE: Unix Basics
  cal
  log_activity "commands" "demo: date and cal" "OK"
  press_enter_to_continue
}

cmdlib_demo_ident() {
  local sessions
  section_title "who and pwd"

  # COMMAND: who | PURPOSE: list the users currently logged in | MODULE: Unix Basics
  sessions="$(who 2>/dev/null)"
  if [ -n "$sessions" ]; then
    printf '%s\n' "$sessions"
  else
    msg_warn "who printed nothing: no interactive login session is recorded here."
  fi

  # COMMAND: pwd | PURPOSE: print the absolute path of the current directory | MODULE: Unix Basics
  printf '\nCurrent directory : %s\n' "$(pwd)"
  printf 'UniShell root     : %s\n' "$UNISHELL_ROOT"

  log_activity "commands" "demo: who and pwd" "OK"
  press_enter_to_continue
}

cmdlib_demo_type() {
  section_title "type - how the shell sees a name"
  # COMMAND: type | PURPOSE: show whether a name is a builtin, alias or program | MODULE: Shell Programming
  type echo
  type pwd
  type ls
  # COMMAND: type -t | PURPOSE: print only the category of the name | MODULE: Shell Programming
  printf '\nprint a one-word answer:\n'
  printf '  echo   -> %s\n' "$(type -t echo)"
  printf '  pwd    -> %s\n' "$(type -t pwd)"
  printf '  ls     -> %s\n' "$(type -t ls)"
  msg_info "builtin = inside the shell, file = a program on disk."
  log_activity "commands" "demo: type" "OK"
  press_enter_to_continue
}

cmdlib_demo_ls() {
  section_title "ls - files, hidden files, HOME and PATH"

  # COMMAND: mkdir -p | PURPOSE: make sure the folder exists before listing it | MODULE: Unix Basics
  mkdir -p "$UNISHELL_SANDBOX"

  printf '\n--- ls sandbox ---\n'
  # COMMAND: ls | PURPOSE: list the names in a directory | MODULE: Unix Basics
  ls -- "$UNISHELL_SANDBOX"

  printf '\n--- ls -a sandbox (the -a shows hidden files) ---\n'
  # COMMAND: ls -a | PURPOSE: list every entry, including names that start with a dot | MODULE: Unix Basics
  ls -a -- "$UNISHELL_SANDBOX"

  printf '\n--- ls -la sandbox (the -l adds details) ---\n'
  # COMMAND: ls -l | PURPOSE: show permissions, links, owner, size and date | MODULE: Unix Basics
  ls -l -- "$UNISHELL_SANDBOX"

  printf '\n'
  msg_info "In ls -a, every directory contains '.' (itself) and '..' (its parent)."
  msg_info "A name that starts with a dot is a hidden file and is skipped by plain ls."
  printf '\n'
  # COMMAND: HOME and PATH are environment variables set by the login shell | MODULE: Unix Basics
  printf 'HOME (your home directory) : %s\n' "${HOME:-<unset>}"
  printf 'PWD  (current directory)   : %s\n' "${PWD:-<unset>}"
  printf 'PATH (where programs hide) : %s\n' "${PATH:-<unset>}"

  log_activity "commands" "demo: ls, HOME and PATH" "OK"
  press_enter_to_continue
}

cmdlib_demo_read() {
  local answer
  section_title "builtins: read, test, readonly"

  # COMMAND: read -r | PURPOSE: read one line of input into a variable | MODULE: Shell Programming
  printf 'Type any short word and press Enter: '
  if read -r answer && [ -n "$answer" ]; then
    printf 'You typed : %s\n' "$answer"
    printf 'Length    : %s characters\n' "${#answer}"
  else
    msg_warn "Nothing was read."
  fi

  printf '\n'
  # COMMAND: test -n | PURPOSE: true when a string is not empty | MODULE: Shell Programming
  if test -n "$answer"; then
    msg_ok "test -n says: the value is not empty."
  else
    msg_warn "test -n says: the value is empty."
  fi

  # A subshell is used so the readonly marker does not affect UniShell itself.
  printf '\n'
  (
    # COMMAND: readonly | PURPOSE: protect a variable from being changed | MODULE: Shell Programming
    readonly DEMO_LIMIT=5
    DEMO_LIMIT=9
  ) 2>/dev/null || msg_ok "Changing a readonly variable was refused, exactly as it should be."

  log_activity "commands" "demo: read, test, readonly" "OK"
  press_enter_to_continue
}

cmdlib_demo_set() {
  section_title "builtins: set, shift, trap"

  # Everything runs in a subshell, so these options never change UniShell.
  (
    # COMMAND: set -- | PURPOSE: set the positional parameters $1, $2, $3 | MODULE: Shell Programming
    set -- alpha beta gamma
    printf 'Arguments : $1=%s $2=%s $3=%s   count=%s\n' "$1" "$2" "$3" "$#"

    # COMMAND: shift | PURPOSE: drop $1 and move the other arguments down | MODULE: Shell Programming
    shift
    printf 'After shift   : $1=%s $2=%s   count=%s\n' "$1" "$2" "$#"

    shift
    printf 'After shift   : $1=%s   count=%s\n' "$1" "$#"

    # COMMAND: trap | PURPOSE: run a command when the shell reaches EXIT | MODULE: Shell Programming
    trap 'printf "trap EXIT ran as the subshell finished.\n"' EXIT
  )

  printf '\n'
  msg_info "set and shift changed only that subshell, so UniShell is untouched."
  msg_info "trap is how a script cleans up after itself, for example on Ctrl-C."
  log_activity "commands" "demo: set, shift, trap" "OK"
  press_enter_to_continue
}
