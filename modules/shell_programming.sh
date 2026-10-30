#!/usr/bin/env bash
# ============================================================
# UniShell - Module 5: Shell Programming Lab   (Phase 6)
# ============================================================
# Teaches how to write shell scripts: variables and environment variables,
# read and readonly, positional parameters, exit status, && and ||, test and
# [ ] with if/elif/else, for and while loops, case, set, shift,
# here-documents and trap. It finishes by running the real example scripts in
# examples/ and by explaining .profile from a sample file.
#
# This file is SOURCED by unishell.sh, which then calls module_shell_programming.
# Nothing typed by the user is ever executed as shell code:
#   * the short demos below are fixed code that ships with UniShell
#   * the example scripts are fixed files; they are only ever run, never built
#     from user text
#   * .profile is only displayed, never sourced
# ============================================================

# COMMAND: (path) | PURPOSE: point at the example scripts that ship with UniShell | MODULE: Shell Programming
SP_DIR="${UNISHELL_ROOT}/examples"
SP_PROFILE="$SP_DIR/profile.sample"
SP_BASICS="$SP_DIR/script_basics.sh"
SP_CONTROL="$SP_DIR/script_control.sh"
SP_ADVANCED="$SP_DIR/script_advanced.sh"

# ------------------------------------------------------------
# Sub-menu
# ------------------------------------------------------------
module_shell_programming() {
  local choice

  if [ ! -d "$SP_DIR" ]; then
    msg_err "Cannot find the examples folder: $SP_DIR"
    log_activity "shell" "examples folder missing" "error"
    return 0
  fi

  while :; do
    section_title "Module 5 - Shell Programming Lab"
    printf '  %s\n' " 1. Variables and environment variables"
    printf '  %s\n' " 2. read, readonly and positional parameters"
    printf '  %s\n' " 3. Exit status, && and ||"
    printf '  %s\n' " 4. Conditions: test, [ ] and if"
    printf '  %s\n' " 5. Loops: for and while"
    printf '  %s\n' " 6. case"
    printf '  %s\n' " 7. set, shift and here-documents"
    printf '  %s\n' " 8. trap and cleanup"
    printf '  %s\n' " 9. Run the complete example scripts"
    printf '  %s\n' "10. About .profile (a sample file, never executed)"
    printf '  %s\n' " 0. Back to the main menu"
    printf '\n'

    if ! ask_choice "Choose an option (0-10): " 0 10; then
      return 0
    fi
    choice="$UNISHELL_CHOICE"

    case "$choice" in
      1)  sp_demo_variables ;;
      2)  sp_demo_read ;;
      3)  sp_demo_exit_status ;;
      4)  sp_demo_test_if ;;
      5)  sp_demo_loops ;;
      6)  sp_demo_case ;;
      7)  sp_demo_set_shift ;;
      8)  sp_demo_trap ;;
      9)  sp_demo_run_scripts ;;
      10) sp_demo_profile ;;
      0)  return 0 ;;
    esac
  done
}

# ------------------------------------------------------------
# 1. Variables and environment variables
# ------------------------------------------------------------
sp_demo_variables() {
  section_title "Variables and environment variables"

  # Everything runs in a subshell, so nothing here changes UniShell itself.
  (
    # COMMAND: name=value | PURPOSE: create a shell variable | MODULE: Shell Programming
    COURSE="Unix Programming"
    # COMMAND: export | PURPOSE: put a variable into the environment of child processes | MODULE: Shell Programming
    export LAB="UniShell"

    printf '  shell variable       COURSE = %s\n' "$COURSE"
    printf '  environment variable LAB    = %s\n' "$LAB"

    # A child program inherits exported variables, but not plain shell ones.
    printf '  a child sees LAB    as: %s\n' "$(bash -c 'printf "%s" "$LAB"')"
    printf '  a child sees COURSE as: [%s]\n' "$(bash -c 'printf "%s" "$COURSE"')"
  )

  printf '\n'
  msg_info "A shell variable exists only in the shell that made it."
  msg_info "export copies a variable into the environment, so every child"
  msg_info "process started from here can read it."
  printf '\n'
  printf '  Some variables are already in your environment at login:\n'
  printf '    HOME = %s\n' "${HOME:-<unset>}"
  printf '    USER = %s\n' "${USER:-<unset>}"
  printf '    SHELL= %s\n' "${SHELL:-<unset>}"

  log_activity "shell" "demo: variables and environment" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 2. read, readonly and positional parameters
# ------------------------------------------------------------
sp_demo_read() {
  section_title "read, readonly and positional parameters"

  # COMMAND: read -r | PURPOSE: store one line of input in a variable | MODULE: Shell Programming
  if ask_text "Type a word and press Enter: "; then
    printf '  read stored the line in the variable NAME\n'
    printf '  NAME   = %s\n' "$UNISHELL_INPUT"
    printf '  length = %s characters (${#NAME})\n' "${#UNISHELL_INPUT}"
  else
    msg_warn "Nothing was read this time."
  fi

  printf '\n'
  # Positional parameters are the arguments a script is started with.
  # $0 is the script name, $1 the first argument, $# the count.
  (
    # COMMAND: set -- | PURPOSE: give the positional parameters values | MODULE: Shell Programming
    set -- alpha beta gamma
    printf '  positional: $1=%s  $2=%s  $3=%s   $#=%s\n' "$1" "$2" "$3" "$#"
    printf '  $0 is the name the shell was started with: %s\n' "$0"
  )

  printf '\n'
  # A subshell is used so the readonly marker does not affect UniShell itself.
  (
    # COMMAND: readonly | PURPOSE: protect a variable from being changed later | MODULE: Shell Programming
    readonly LIMIT=10
    printf '  LIMIT is readonly with the value %s\n' "$LIMIT"
    LIMIT=20
  ) 2>/dev/null || msg_ok "readonly refused the second assignment, exactly as it should."

  msg_info "read, readonly and positional parameters are all builtins: they"
  msg_info "belong to the shell itself, so no program has to be started."
  log_activity "shell" "demo: read, readonly, positional parameters" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 3. Exit status, && and ||
# ------------------------------------------------------------
sp_demo_exit_status() {
  section_title "Exit status, && and ||"

  # COMMAND: true | PURPOSE: a command that always succeeds (status 0) | MODULE: Shell Programming
  true
  printf '  true  returned exit status %s\n' "$?"
  # COMMAND: false | PURPOSE: a command that always fails (status 1) | MODULE: Shell Programming
  false
  printf '  false returned exit status %s\n' "$?"

  printf '\n'
  # && runs the right-hand command only when the left one SUCCEEDED.
  # COMMAND: && | PURPOSE: run the next command only when the previous one succeeded | MODULE: Shell Programming
  true  && printf '  true  && ... printed this line (the left side succeeded)\n'
  false && printf '  this line never appears\n'
  # || runs the right-hand command only when the left one FAILED.
  # COMMAND: || | PURPOSE: run the next command only when the previous one failed | MODULE: Shell Programming
  false || printf '  false || ... printed this line (the left side failed)\n'
  true  || printf '  this line never appears\n'

  printf '\n'
  msg_info "Exit status 0 means success; anything else means failure."
  msg_info "&& is a short if: 'do the next thing only if this one worked'."
  msg_info "|| is the opposite: 'do the next thing only if this one failed'."

  log_activity "shell" "demo: exit status, && and ||" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 4. Conditions: test, [ ] and if
# ------------------------------------------------------------
sp_demo_test_if() {
  section_title "Conditions: test, [ ] and if"
  local value=7

  printf '  value = %s\n\n' "$value"

  # COMMAND: test | PURPOSE: evaluate a condition and return 0 (true) or 1 (false) | MODULE: Shell Programming
  if test "$value" -gt 5; then
    printf '  test : %s -gt 5 is true\n' "$value"
  fi
  # COMMAND: [ ] | PURPOSE: the same test written in the more common bracket form | MODULE: Shell Programming
  if [ "$value" -gt 5 ]; then
    printf '  [ ]  : %s -gt 5 is true\n' "$value"
  fi

  if [ -z "" ]; then
    printf '  test -z: an empty string has zero length\n'
  fi
  if [ -n "abc" ]; then
    printf '  test -n: the string abc is not empty\n'
  fi
  if [ "$value" -ge 5 ] && [ "$value" -le 10 ]; then
    printf '  both conditions are true: %s is between 5 and 10\n' "$value"
  fi

  printf '\n  if / elif / else:\n'
  if [ "$value" -gt 10 ]; then
    printf '    big\n'
  elif [ "$value" -ge 5 ]; then
    printf '    %s is medium (5 to 10)\n' "$value"
  else
    printf '    small\n'
  fi

  printf '\n'
  msg_info "test and [ ] are the same builtin; [ ] simply needs a closing ]."
  msg_info "Numeric tests use -eq -ne -lt -le -gt -ge; strings use = and !=."
  msg_info "The condition is only tested through these fixed operators, never by"
  msg_info "running anything the user typed."

  log_activity "shell" "demo: test, [ ] and if" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 5. Loops: for and while
# ------------------------------------------------------------
sp_demo_loops() {
  section_title "Loops: for and while"

  printf '  for over a fixed list:\n'
  # COMMAND: for | PURPOSE: repeat once for each item in a list | MODULE: Shell Programming
  for fruit in apple banana cherry; do
    printf '    %s\n' "$fruit"
  done

  printf '\n  for over a range of numbers:\n'
  for n in 1 2 3; do
    printf '    count %s\n' "$n"
  done

  printf '\n  while, repeating as long as the condition stays true:\n'
  local i=1
  # COMMAND: while | PURPOSE: repeat while a condition is true | MODULE: Shell Programming
  while [ "$i" -le 3 ]; do
    printf '    i = %s\n' "$i"
    i=$((i + 1))
  done

  printf '\n'
  msg_info "for is used when the number of repeats is known in advance."
  msg_info "while is used when the loop should run until something changes."
  msg_info "A loop that never changes its condition would run forever, so every"
  msg_info "while loop here moves its counter with i=\$((i + 1))."

  log_activity "shell" "demo: for and while" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 6. case
# ------------------------------------------------------------
sp_demo_case() {
  section_title "case"
  local answer

  # COMMAND: case | PURPOSE: compare one value with several patterns and run the first match | MODULE: Shell Programming
  for answer in start stop reload unknown; do
    case "$answer" in
      start|begin) printf '  %-8s -> starting\n' "$answer" ;;
      stop|end)    printf '  %-8s -> stopping\n' "$answer" ;;
      reload)      printf '  %-8s -> reloading\n' "$answer" ;;
      *)           printf '  %-8s -> not understood\n' "$answer" ;;
    esac
  done

  printf '\n'
  msg_info "case compares one value against several patterns and runs the first"
  msg_info "one that matches. Patterns may use | for alternatives and * as the"
  msg_info "catch-all at the end. It is a tidier form of a long if/elif chain."

  log_activity "shell" "demo: case" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 7. set, shift and here-documents
# ------------------------------------------------------------
sp_demo_set_shift() {
  section_title "set, shift and here-documents"

  # Everything runs in a subshell, so set and shift never affect UniShell.
  (
    # COMMAND: set -- | PURPOSE: set the positional parameters $1, $2, $3 | MODULE: Shell Programming
    set -- alpha beta gamma
    printf '  set -- :  $# = %s,  $* = %s\n' "$#" "$*"

    # COMMAND: shift | PURPOSE: drop $1 and move the rest down | MODULE: Shell Programming
    while [ "$#" -gt 0 ]; do
      printf '    $1 = %s\n' "$1"
      shift
    done
    printf '  after the loop, $# = %s\n' "$#"

    printf '\n  a quoted here-document (variables stay literal):\n'
    # A here-document starts with << and a marker word. The lines up to the
    # marker on its own line become the command's standard input.
    #
    # The marker must start at the beginning of the line, so these lines are
    # deliberately not indented.
    # COMMAND: << | PURPOSE: feed several lines to a command as its input | MODULE: Shell Programming
    cat <<'DOC'
    this text came from a here-document
    $HOME is not expanded here, because the marker is quoted
DOC

    printf '  an unquoted here-document (variables are expanded):\n'
    cat <<DOC2
    HOME is expanded here to $HOME
DOC2
  )

  printf '\n'
  msg_info "set -- is a tidy way to give a script its own arguments in a demo."
  msg_info "shift is how a script walks through its arguments one at a time."
  msg_info "A here-document saves writing a long input in a separate file;"
  msg_info "quote the marker to keep \$variables literal."

  log_activity "shell" "demo: set, shift, here-documents" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 8. trap and cleanup
# ------------------------------------------------------------
sp_demo_trap() {
  section_title "trap and cleanup"

  # A subshell is used so the trap is gone when the demo ends.
  (
    # COMMAND: trap | PURPOSE: run a command when the shell receives a signal or exits | MODULE: Shell Programming
    trap 'printf "  trap : the EXIT trap ran, so cleanup happens however we finish.\n"' EXIT
    printf '  the subshell is doing its work...\n'
  )

  printf '\n'
  msg_info "trap names a handler to run when a signal arrives or when the shell"
  msg_info "exits. EXIT always fires, so it is perfect for removing temporary"
  msg_info "files. UniShell uses 'trap on_interrupt INT TERM' in unishell.sh so"
  msg_info "that Ctrl-C always leaves the terminal in a clean state."

  log_activity "shell" "demo: trap and cleanup" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 9. Run the complete example scripts
# ------------------------------------------------------------
sp_demo_run_scripts() {
  section_title "Running the complete example scripts"
  local script missing=0

  for script in "$SP_BASICS" "$SP_CONTROL" "$SP_ADVANCED"; do
    if [ ! -r "$script" ]; then
      msg_err "Missing example script: $script"
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    log_activity "shell" "example script missing" "error"
    press_enter_to_continue
    return 0
  fi

  printf '  The scripts live in examples/ and are run with: bash <script>\n'

  printf '\n--- script_basics.sh (one line is fed to read) ---\n'
  # COMMAND: bash <script> | PURPOSE: run a stored shell script for real | MODULE: Shell Programming
  bash "$SP_BASICS" <<'SP_INPUT'
Ada Lovelace
SP_INPUT

  printf '\n--- script_control.sh ---\n'
  bash "$SP_CONTROL"

  printf '\n--- script_advanced.sh one two three ---\n'
  bash "$SP_ADVANCED" one two three

  printf '\n'
  msg_info "Each script is a plain text file you can open and read. UniShell"
  msg_info "runs them with bash; they never read or change anything you typed."

  log_activity "shell" "demo: ran the example scripts" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 10. About .profile - a sample file only
# ------------------------------------------------------------
sp_demo_profile() {
  section_title "About .profile"

  printf '  A login shell reads your real ~/.profile once, at login, to set up\n'
  printf '  your environment. UniShell does NOT read it and does NOT change it.\n'
  printf '  It shows this sample file instead:\n\n'

  if [ ! -r "$SP_PROFILE" ]; then
    msg_err "Missing sample file: $SP_PROFILE"
    press_enter_to_continue
    return 0
  fi

  # COMMAND: cat | PURPOSE: display the sample file without executing any of it | MODULE: Unix Basics
  cat "$SP_PROFILE"

  printf '\n'
  # Read-only check: UniShell only looks whether a real file exists.
  if [ -f "${HOME:-/nonexistent}/.profile" ]; then
    msg_warn "A real ~/.profile exists on this machine."
    msg_info "UniShell has not opened, executed or changed it."
  else
    msg_info "This machine has no ~/.profile, which is normal for some setups."
  fi

  log_activity "shell" "explained .profile (sample only, not executed)" "OK"
  press_enter_to_continue
}
