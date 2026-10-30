#!/usr/bin/env bash
# ============================================================
# UniShell - Module 6: Process Management Lab   (Phase 7)
# ============================================================
# Teaches what a process is, then runs the real compiled C demonstrations in
# bin/ that show fork(), the exec() family, exit(), wait() and waitpid(), and
# the difference between a zombie and an orphan process.
#
# The C programs are fixed files that ship with UniShell. UniShell only runs
# them; nothing typed by the user is ever executed as code, and no process
# that UniShell did not start itself is ever touched or stopped.
#
# This file is SOURCED by unishell.sh, which then calls module_processes.
# ============================================================

# COMMAND: (path) | PURPOSE: point at the compiled demonstrations and their sources | MODULE: Process Management
PR_BIN="$UNISHELL_BIN"
PR_SRC="$UNISHELL_ROOT/c_programs"

# ------------------------------------------------------------
# Sub-menu
# ------------------------------------------------------------
module_processes() {
  local choice

  while :; do
    section_title "Module 6 - Process Management Lab"
    printf '  %s\n' " 1. What is a process? (pid, parent pid and a real child)"
    printf '  %s\n' " 2. fork() - one process becomes two"
    printf '  %s\n' " 3. The exec() family - replacing the running program"
    printf '  %s\n' " 4. wait() and waitpid() - reaping children"
    printf '  %s\n' " 5. Zombie and orphan processes"
    printf '  %s\n' " 6. Run every process demonstration"
    printf '  %s\n' " 0. Back to the main menu"
    printf '\n'

    if ! ask_choice "Choose an option (0-6): " 0 6; then
      return 0
    fi
    choice="$UNISHELL_CHOICE"

    case "$choice" in
      1) pr_demo_process ;;
      2) pr_run_bin "process_fork" "fork() - one process becomes two" ;;
      3) pr_run_bin "exec_demo"    "The exec() family - replacing the running program" ;;
      4) pr_run_bin "wait_demo"    "wait() and waitpid() - reaping children" ;;
      5) pr_explain_zombie_orphan ;;
      6) pr_run_everything ;;
      0) return 0 ;;
    esac
  done
}

# ------------------------------------------------------------
# Build helper: make sure bin/<name> exists
# ------------------------------------------------------------
# make all only ever writes into bin/, and it is the project's own build rule,
# so this cannot change anything the user typed.
pr_require_bin() {
  local name="$1"
  local path="$PR_BIN/$name"

  if [ -x "$path" ]; then
    return 0
  fi

  msg_warn "bin/$name is missing, so it will be built first."
  # COMMAND: make all | PURPOSE: compile every C demonstration into bin/ | MODULE: 3
  if ! ( cd "$UNISHELL_ROOT" && make all ); then
    msg_err "make all failed. Run 'make all' in $UNISHELL_ROOT to see why."
    return 1
  fi
  if [ ! -x "$path" ]; then
    msg_err "bin/$name still does not exist after make all."
    return 1
  fi
  return 0
}

# pr_run_bin <name> <title> - run one compiled demonstration
pr_run_bin() {
  local name="$1" title="$2" rc

  section_title "$title"

  if ! pr_require_bin "$name"; then
    log_activity "processes" "missing C demonstration: $name" "error"
    press_enter_to_continue
    return 0
  fi

  printf '  Running: ./bin/%s\n\n' "$name"
  # COMMAND: ./bin/<name> | PURPOSE: run the compiled C demonstration for real | MODULE: Process Management
  "$PR_BIN/$name"
  rc=$?
  printf '\n  bin/%s exited with status %s\n' "$name" "$rc"

  log_activity "processes" "ran C demonstration: $name" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 1. What is a process?
# ------------------------------------------------------------
pr_demo_process() {
  section_title "What is a process?"

  printf '  A process is one running program. Every process has a pid (process\n'
  printf '  id) and, unless it is the very first one, a parent process.\n\n'

  printf '  UniShell shell, right now : pid %s\n' "$$"
  printf '  the process that started it: pid %s\n' "$PPID"

  printf '\n  ps prints the real process-table entries:\n'
  # COMMAND: ps -o pid,ppid,stat,comm -p | PURPOSE: show the real table entry for this shell and its parent | MODULE: Process Management
  ps -o pid,ppid,stat,comm -p "$$" "$PPID" 2>/dev/null || msg_warn "ps is not available on this system."

  printf '\n  stat column : R = running, S = sleeping, Z = zombie\n'

  printf '\n  A new process gets a new pid. Here UniShell starts a real child:\n'
  # COMMAND: bash -c | PURPOSE: start a child process that reports its own pid and parent | MODULE: Process Management
  bash -c 'printf "    child : my pid is %s and my parent is %s\n" "$$" "$PPID"'

  printf '  The child printed %s as its parent, because UniShell started it.\n' "$$"
  printf '  When the child ended, its entry left the process table again.\n'

  printf '\n'
  msg_info "A parent can start many children. Each child is a separate process"
  msg_info "with its own pid and its own copy of memory, even though it was"
  msg_info "started by the same program."

  log_activity "processes" "demo: what is a process" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 5. Zombie and orphan processes
# ------------------------------------------------------------
pr_explain_zombie_orphan() {
  section_title "Zombie and orphan processes"

  printf '  Zombie (defunct)\n'
  printf '    A child that has ENDED but whose parent has not collected its exit\n'
  printf '    status yet. The child is not running and holds no memory of its\n'
  printf '    own; only a small entry stays in the process table. Its state in\n'
  printf '    /proc is the letter Z. wait() or waitpid() collects the status and\n'
  printf '    the entry disappears.\n\n'

  printf '  Orphan\n'
  printf '    A process whose parent ended first. It is not left without a\n'
  printf '    parent: the system adopts it and gives it a new one (normally the\n'
  printf '    init process, which is pid 1, though on some systems another\n'
  printf '    process such as a systemd user session takes that role). An orphan\n'
  printf '    therefore keeps running normally, and is reaped by its new parent\n'
  printf '    when it ends.\n\n'

  printf '  Why a zombie is still a problem\n'
  printf '    A process table has a fixed size. A program that starts many\n'
  printf '    children and never waits for them fills the table with zombies and\n'
  printf '    then cannot start any more processes.\n\n'

  msg_info "Option 4 runs bin/wait_demo, which shows all of this for real:"
  msg_info "it reads the letter Z from /proc for a child it has not reaped yet,"
  msg_info "then collects it, and it creates an orphan and shows the new parent"
  msg_info "the system gave it. Every child it starts is waited for, so it leaves"
  msg_info "nothing behind."

  log_activity "processes" "explained zombie and orphan processes" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 6. Run every process demonstration
# ------------------------------------------------------------
pr_run_everything() {
  section_title "Every process demonstration"
  local name rc

  printf '  The three process programs will now be run in order.\n'

  for name in process_fork exec_demo wait_demo; do
    printf '\n--- bin/%s ---\n' "$name"
    if pr_require_bin "$name"; then
      # COMMAND: ./bin/<name> | PURPOSE: run each compiled demonstration in order | MODULE: Process Management
      "$PR_BIN/$name"
      rc=$?
      printf '\n  bin/%s exited with status %s\n' "$name" "$rc"
    else
      msg_err "Skipping bin/$name because it could not be built."
    fi
  done

  printf '\n'
  msg_info "The source of each program is in c_programs/ and is meant to be"
  msg_info "read alongside the output, line by line."

  log_activity "processes" "ran every process demonstration" "OK"
  press_enter_to_continue
}
