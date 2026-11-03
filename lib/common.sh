#!/usr/bin/env bash
# ============================================================
# UniShell - lib/common.sh
# Shared helpers for every module. This file is SOURCED, never executed.
# COMMAND: source lib/common.sh | PURPOSE: load helper functions into the running shell | MODULE: 2
#
# What this file guarantees for the whole project:
#   * no dynamic code execution anywhere in UniShell
#   * text typed by a user is only ever COMPARED, never executed
#   * every file a demo writes stays inside ./sandbox
#   * every action can be recorded in logs/activity.log
# ============================================================

# Sourcing this file twice must not do anything twice.
# COMMAND: return | PURPOSE: leave a sourced file early | MODULE: 2
if [ -n "${UNISHELL_COMMON_LOADED:-}" ]; then
  return 0
fi
UNISHELL_COMMON_LOADED=1

# ------------------------------------------------------------
# 1. Where everything lives
# ------------------------------------------------------------
# BASH_SOURCE[0] is this file (.../lib/common.sh), so the project root is one
# directory above it. Building every path from the root means UniShell works
# no matter which directory the user starts it from.
UNISHELL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNISHELL_SANDBOX="$UNISHELL_ROOT/sandbox"
UNISHELL_LOGS="$UNISHELL_ROOT/logs"
UNISHELL_DATA="$UNISHELL_ROOT/data"
UNISHELL_BIN="$UNISHELL_ROOT/bin"
UNISHELL_ACTIVITY_LOG="$UNISHELL_LOGS/activity.log"

# COMMAND: realpath -m | PURPOSE: resolve ".." and symlinks once, so the sandbox guard cannot be fooled | MODULE: 1
UNISHELL_SANDBOX_REAL="$(realpath -m -- "$UNISHELL_SANDBOX" 2>/dev/null || printf '%s' "$UNISHELL_SANDBOX")"

# ------------------------------------------------------------
# 2. Colours - only when a human is watching
# ------------------------------------------------------------
# COMMAND: [ -t 1 ] | PURPOSE: use colour only when stdout is a real terminal | MODULE: 2
# Piped or redirected output (for example the test scripts) stays plain text,
# which keeps captures and log files readable.
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_CYAN=$'\033[36m'
else
  C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

# ------------------------------------------------------------
# 3. Display helpers
# ------------------------------------------------------------
# COMMAND: printf | PURPOSE: print formatted text without a trailing newline surprise | MODULE: 1
msg_info() { printf '%s%s%s\n' "$C_BLUE"   "$1" "$C_RESET"; }
msg_ok()   { printf '%s%s%s\n' "$C_GREEN"  "$1" "$C_RESET"; }
msg_warn() { printf '%s%s%s\n' "$C_YELLOW" "$1" "$C_RESET"; }
# COMMAND: >&2 | PURPOSE: send errors to stderr so they stay separate from normal results | MODULE: 2
msg_err()  { printf '%s%s%s\n' "$C_RED"    "$1" "$C_RESET" >&2; }

# COMMAND: printf | PURPOSE: draw the UniShell banner | MODULE: 1
show_banner() {
  printf '%s\n' "========================================"
  printf '%s\n' "             U N I S H E L L"
  printf '%s\n' "       Unix Programming Learning Lab"
  printf '%s\n' "========================================"
}

# section_title <text> - a small heading used inside modules
section_title() {
  printf '\n%s== %s ==%s\n' "$C_BOLD" "$1" "$C_RESET"
}

# press_enter_to_continue - pause until the user presses Enter
# If input has ended (Ctrl-D) this returns immediately, so the menu can close
# cleanly instead of spinning forever.
press_enter_to_continue() {
  local discard
  printf '%s' "Press Enter to return to the menu... "
  read -r discard || printf '\n'
  return 0
}

# ------------------------------------------------------------
# 4. Safe input
# ------------------------------------------------------------
# Every function here only READS text and COMPARES it. Nothing typed by a user
# is handed to a shell, which is why UniShell never needs dynamic execution.

# ask_choice <prompt> <min> <max>
# Reads one whole number in [min, max] into $UNISHELL_CHOICE.
# Returns 0 when a valid number was read, 1 when input ended (Ctrl-D).
ask_choice() {
  local prompt="$1" min="$2" max="$3" answer
  while :; do
    printf '%s' "$prompt"
    # COMMAND: read -r | PURPOSE: read one line exactly as typed | MODULE: 2
    # With the default IFS, read also removes leading and trailing spaces,
    # so " 5 " is accepted as 5.
    if ! read -r answer; then
      # read returns non-zero when input ends. If the last line still held
      # text (a file without a final newline) we keep it, otherwise we stop.
      if [ -z "$answer" ]; then
        printf '\n'
        return 1
      fi
    fi
    if [ -z "$answer" ]; then
      msg_warn "Nothing was entered. Please type a number."
      continue
    fi
    # COMMAND: case | PURPOSE: allow digits only and reject every other character | MODULE: 2
    # The rejected text is intentionally NOT printed back. Reflecting whatever
    # the user typed could let control characters reach the terminal, so the
    # message stays fixed instead.
    case "$answer" in
      *[!0-9]*)
        msg_err "That is not a number. Please type digits only."
        continue
        ;;
    esac
    # 10#$answer forces base 10, so "08" means 8 instead of an invalid octal
    answer=$((10#$answer))
    if [ "$answer" -lt "$min" ] || [ "$answer" -gt "$max" ]; then
      msg_err "Please choose a number from $min to $max."
      continue
    fi
    UNISHELL_CHOICE="$answer"
    return 0
  done
}

# ask_yes_no <prompt> - keeps asking until the answer is y or n.
# Returns 0 for yes, 1 for no.
ask_yes_no() {
  local prompt="$1" answer
  while :; do
    printf '%s (y/n): ' "$prompt"
    if ! read -r answer; then
      printf '\n'
      return 1
    fi
    case "$answer" in
      y|Y|yes|YES|Yes)      return 0 ;;
      n|N|no|NO|No|"")      return 1 ;;
      *) msg_warn "Please answer y or n." ;;
    esac
  done
}

# ask_text <prompt> - reads one non-empty line into $UNISHELL_INPUT.
# Returns 0 on success, 1 on an empty line or end of input.
ask_text() {
  local prompt="$1" answer
  printf '%s' "$prompt"
  if ! read -r answer; then
    if [ -z "$answer" ]; then
      printf '\n'
      return 1
    fi
  fi
  if [ -z "$answer" ]; then
    msg_warn "Nothing was entered."
    return 1
  fi
  UNISHELL_INPUT="$answer"
  return 0
}

# ------------------------------------------------------------
# 5. Sandbox safety
# ------------------------------------------------------------
# No destructive command is ever run on a path UniShell has not checked.
# Two independent checks are used:
#   is_safe_name         - a single plain name, no slashes at all
#   check_inside_sandbox - a resolved path that really lives in ./sandbox

# is_safe_name <name> - true when <name> is one safe file name
# Spaces are refused because every later command would then need quoting in
# exactly the right place; refusing them removes a whole class of mistakes.
is_safe_name() {
  local name="$1"
  case "$name" in
    "")                 return 1 ;;   # empty
    .|..)               return 1 ;;   # this directory and its parent
    -*)                 return 1 ;;   # looks like an option, e.g. "-rf"
    */*)                return 1 ;;   # a slash could leave the sandbox
    *[[:space:]]*)      return 1 ;;   # spaces need quoting everywhere
    *[![:print:]]*)     return 1 ;;   # control characters
  esac
  [ "${#name}" -le 64 ] || return 1
  return 0
}

# sandbox_path <name> - prints ./sandbox/<name> when <name> is safe
sandbox_path() {
  local name="$1"
  if ! is_safe_name "$name"; then
    msg_err "'$name' is not a safe file name (no slash, space or leading '-')."
    return 1
  fi
  printf '%s/%s\n' "$UNISHELL_SANDBOX" "$name"
}

# check_inside_sandbox <path> - true when <path> resolves inside ./sandbox
check_inside_sandbox() {
  local target="$1" real
  real="$(realpath -m -- "$target" 2>/dev/null)" || return 1
  case "$real" in
    "$UNISHELL_SANDBOX_REAL"|"$UNISHELL_SANDBOX_REAL"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# ensure_runtime_dirs - create ./sandbox and ./logs when they are missing
ensure_runtime_dirs() {
  # COMMAND: mkdir -p | PURPOSE: create a directory only when it is missing | MODULE: 1
  mkdir -p "$UNISHELL_SANDBOX" 2>/dev/null || { msg_err "Cannot create $UNISHELL_SANDBOX"; return 1; }
  mkdir -p "$UNISHELL_LOGS" 2>/dev/null     || { msg_err "Cannot create $UNISHELL_LOGS"; return 1; }
  return 0
}

# ------------------------------------------------------------
# 6. Activity log
# ------------------------------------------------------------
# Only four fixed things are written: time, module, action and status. Text
# typed by the user is never logged, so the log cannot collect passwords or
# personal data. The action text must not contain a "|" character, because
# " | " is what separates the four fields.
# log_activity <module> <action> [status]
log_activity() {
  local module="$1" action="$2" status="${3:-OK}"
  [ -d "$UNISHELL_LOGS" ] || mkdir -p "$UNISHELL_LOGS" 2>/dev/null || return 1
  # COMMAND: date '+%Y-%m-%d %H:%M:%S' | PURPOSE: timestamp every entry | MODULE: 1
  # COMMAND: >> | PURPOSE: append so earlier entries are never overwritten | MODULE: 2
  printf '%s | %-12s | %-42s | %s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$module" "$action" "$status" \
    >> "$UNISHELL_ACTIVITY_LOG" 2>/dev/null || return 1
  return 0
}

# log_activity_exit <module> <action> <exit-status>
# Records one finished piece of work together with the status it returned, so
# the log says not only what was attempted but whether it worked. The status
# is a plain number, so nothing but digits reaches the log file.
log_activity_exit() {
  local module="$1" action="$2" status="$3"
  log_activity "$module" "$action" "exit=$status"
}
