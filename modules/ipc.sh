#!/usr/bin/env bash
# ============================================================
# UniShell - Module 7: Inter-Process Communication Lab   (Phase 8)
# ============================================================
# Teaches the three classic ways two Unix processes talk to each other, and
# runs the real compiled C programs in bin/ that use each one:
#
#   * an unnamed pipe  : pipe()      - bin/pipe_demo
#   * a named pipe     : mkfifo()    - bin/fifo_receiver and bin/fifo_sender
#   * signals          : sigaction() - bin/signal_demo, bin/signal_receiver
#                                      and bin/signal_sender
#
# Safety, and why these demonstrations cannot hang or hurt anything:
#   * the FIFO is created inside ./sandbox, and the path is checked with
#     check_inside_sandbox() first;
#   * the receiver gives up after a few seconds (poll() plus a deadline), so a
#     missing sender can never leave a process waiting for ever;
#   * the signal receiver has an alarm() deadline for the same reason;
#   * the only process ever signalled is the receiver UniShell started itself a
#     moment earlier, and bin/signal_sender accepts only USR1, USR2 and TERM.
#
# Nothing typed by the user is ever executed: every number is compared with a
# fixed list and every program run is a file that ships with UniShell.
#
# This file is SOURCED by unishell.sh, which then calls module_ipc.
# ============================================================

# COMMAND: (path) | PURPOSE: point at the compiled demonstrations and their sources | MODULE: Inter-Process Communication
IPC_BIN="$UNISHELL_BIN"
IPC_SRC="$UNISHELL_ROOT/c_programs"

# Working paths - all of them inside ./sandbox.
IPC_FIFO="$UNISHELL_SANDBOX/ipc_demo.fifo"
IPC_FIFO_OUT="$UNISHELL_SANDBOX/ipc_fifo_receiver.out"
IPC_SIG_OUT="$UNISHELL_SANDBOX/ipc_signal_receiver.out"

# ------------------------------------------------------------
# Sub-menu
# ------------------------------------------------------------
module_ipc() {
  local choice

  while :; do
    section_title "Module 7 - Inter-Process Communication Lab"
    printf '  %s\n' " 1. What is inter-process communication?"
    printf '  %s\n' " 2. Unnamed pipe: pipe() carries bytes to a child"
    printf '  %s\n' " 3. Named pipe: mkfifo(), a receiver and a sender"
    printf '  %s\n' " 4. Signals and signal handlers"
    printf '  %s\n' " 5. Signals: a receiver waits and a sender signals it"
    printf '  %s\n' " 6. Read the source of a demonstration"
    printf '  %s\n' " 7. Run every IPC demonstration"
    printf '  %s\n' " 0. Back to the main menu"
    printf '\n'

    if ! ask_choice "Choose an option (0-7): " 0 7; then
      return 0
    fi
    choice="$UNISHELL_CHOICE"

    case "$choice" in
      1) ipc_explain_what ;;
      2) ipc_run_bin "pipe_demo" "Unnamed pipe: pipe() carries bytes to a child" ;;
      3) ipc_run_fifo ;;
      4) ipc_run_bin "signal_demo" "Signals and signal handlers" ;;
      5) ipc_run_signal_pair ;;
      6) ipc_read_source ;;
      7) ipc_run_everything ;;
      0) return 0 ;;
    esac
  done
}

# ------------------------------------------------------------
# Build helper: make sure bin/<name> exists
# ------------------------------------------------------------
ipc_require_bin() {
  local name="$1"
  local path="$IPC_BIN/$name"

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

# ipc_run_bin <name> <title> - run one compiled demonstration
ipc_run_bin() {
  local name="$1" title="$2" rc

  section_title "$title"

  if ! ipc_require_bin "$name"; then
    log_activity "ipc" "missing C demonstration: $name" "error"
    press_enter_to_continue
    return 0
  fi

  printf '  Running: ./bin/%s\n\n' "$name"
  # COMMAND: ./bin/<name> | PURPOSE: run the compiled C demonstration for real | MODULE: Inter-Process Communication
  "$IPC_BIN/$name"
  rc=$?
  printf '\n  bin/%s exited with status %s\n' "$name" "$rc"

  log_activity_exit "ipc" "ran C demonstration: $name" "$rc"
  press_enter_to_continue
}

# ipc_wait_for <file> <needle> [tries]
# Waits until the background program has printed <needle>, so a signal or a
# message is never sent before the other side is ready to receive it. The
# bounded number of tries means this helper cannot wait for ever either.
ipc_wait_for() {
  local file="$1" needle="$2" tries="${3:-30}"

  while [ "$tries" -gt 0 ]; do
    # COMMAND: grep -qF | PURPOSE: look for a fixed line in the program's output | MODULE: 4
    if [ -f "$file" ] && grep -qF -- "$needle" "$file"; then
      return 0
    fi
    # COMMAND: sleep 0.1 | PURPOSE: wait a moment before looking again | MODULE: 1
    sleep 0.1
    tries=$((tries - 1))
  done
  return 1
}

# ------------------------------------------------------------
# 1. What is inter-process communication?
# ------------------------------------------------------------
ipc_explain_what() {
  section_title "What is inter-process communication?"

  printf '  Every process has its own private memory. Two processes therefore\n'
  printf '  cannot simply read each other variables; they have to ask the kernel\n'
  printf '  to carry data or a short notice between them. That is inter-process\n'
  printf '  communication (IPC).\n\n'

  printf '  Unix gives three tools that this module demonstrates:\n\n'

  printf '  1. The unnamed pipe\n'
  printf '     pipe() returns two file descriptors that share one small buffer.\n'
  printf '     What one process writes into the write end comes out of the read\n'
  printf '     end. It has no name, so it is used between a parent and the child\n'
  printf '     it has just forked. This is exactly what "ls | wc -l" uses.\n\n'

  printf '  2. The named pipe (FIFO)\n'
  printf '     mkfifo() makes a pipe that has a name in the file system. Two\n'
  printf '     programs that were NOT started from each other can meet at that\n'
  printf '     name and pass data, just as if they shared a pipe.\n\n'

  printf '  3. Signals\n'
  printf '     A signal is a very short message: one small number delivered to a\n'
  printf '     process. It carries no data at all - it just says "something\n'
  printf '     happened". The receiving program decides what to do by installing\n'
  printf '     a handler with sigaction().\n\n'

  printf '  Two rules UniShell follows the whole way through:\n'
  printf '    - a read must always be able to finish, so every wait has a deadline;\n'
  printf '    - a signal is only ever sent to a process that UniShell started.\n'

  log_activity "ipc" "explained what inter-process communication is" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 3. Named pipe: a receiver and a sender
# ------------------------------------------------------------
ipc_run_fifo() {
  section_title "Named pipe: mkfifo(), a receiver and a sender"
  local recpid rc

  if ! ipc_require_bin "fifo_receiver" || ! ipc_require_bin "fifo_sender"; then
    log_activity "ipc" "missing FIFO demonstrations" "error"
    press_enter_to_continue
    return 0
  fi

  # COMMAND: mkdir -p | PURPOSE: make sure ./sandbox exists before anything is created | MODULE: 1
  mkdir -p "$UNISHELL_SANDBOX" 2>/dev/null

  # Second, independent check before anything is created or removed.
  if ! check_inside_sandbox "$IPC_FIFO"; then
    msg_err "Refusing to run: $IPC_FIFO is not inside the sandbox."
    log_activity "ipc" "sandbox guard refused the FIFO path" "refused"
    press_enter_to_continue
    return 0
  fi

  printf '  A FIFO is a file of a special type. This module makes one with the\n'
  printf '  mkfifo command, then shows what ls -l says about it.\n\n'

  # COMMAND: rm -f | PURPOSE: start from a clean slate inside the sandbox | MODULE: 1
  rm -f "$IPC_FIFO" "$IPC_FIFO_OUT" 2>/dev/null
  # COMMAND: mkfifo -m 600 | PURPOSE: create a named pipe with a name in the file system | MODULE: Inter-Process Communication
  if ! mkfifo -m 600 "$IPC_FIFO"; then
    msg_err "mkfifo failed for $IPC_FIFO"
    log_activity "ipc" "mkfifo failed" "error"
    press_enter_to_continue
    return 0
  fi
  printf '  created: %s\n\n' "$IPC_FIFO"

  printf '  ls -l marks a FIFO with a p as the first character:\n'
  # COMMAND: ls -l | PURPOSE: show the file type letter at the start of the listing | MODULE: Unix Basics
  ls -l "$IPC_FIFO"

  printf '\n  Now the receiver is started in the background. It opens this same\n'
  printf '  FIFO for reading and waits (with a deadline) for a message.\n\n'

  # COMMAND: ./bin/fifo_receiver <fifo> <timeout> & | PURPOSE: start the receiving half in the background so the sending half can run | MODULE: Inter-Process Communication
  "$IPC_BIN/fifo_receiver" "$IPC_FIFO" 6 > "$IPC_FIFO_OUT" 2>&1 &
  recpid=$!

  if ! ipc_wait_for "$IPC_FIFO_OUT" "poll()"; then
    msg_warn "The receiver did not reach its waiting state in time."
  fi

  printf '  Receiver (pid %s) is ready. Now the sender opens the same FIFO for\n' "$recpid"
  printf '  writing and sends one message.\n\n'

  # COMMAND: ./bin/fifo_sender <fifo> <message> | PURPOSE: send a message through the named pipe | MODULE: Inter-Process Communication
  "$IPC_BIN/fifo_sender" "$IPC_FIFO" "hello through the named pipe"
  rc=$?
  printf '\n  bin/fifo_sender exited with status %s\n' "$rc"

  # COMMAND: wait <pid> | PURPOSE: collect the background receiver so no stray process is left behind | MODULE: Process Management
  wait "$recpid"
  local recrc=$?

  printf '\n  --- what the receiver printed (exit status %s) ---\n' "$recrc"
  # COMMAND: cat | PURPOSE: show the background program's own output | MODULE: Unix Basics
  cat "$IPC_FIFO_OUT" 2>/dev/null

  printf '\n'
  msg_info "The receiver closed its end and removed the FIFO with unlink(), so"
  msg_info "nothing is left in the sandbox. If no sender had appeared, poll()"
  msg_info "would have reached its deadline and the receiver would have exited"
  msg_info "by itself with status 3 instead of hanging."

  # Belt and braces: remove the working files even if a step above went wrong.
  rm -f "$IPC_FIFO" "$IPC_FIFO_OUT" 2>/dev/null

  log_activity_exit "ipc" "ran the FIFO receiver and sender" "$recrc"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 5. Signals: a receiver waits and a sender signals it
# ------------------------------------------------------------
ipc_run_signal_pair() {
  section_title "Signals: a receiver waits and a sender signals it"
  local sigpid rc recrc

  if ! ipc_require_bin "signal_receiver" || ! ipc_require_bin "signal_sender"; then
    log_activity "ipc" "missing signal demonstrations" "error"
    press_enter_to_continue
    return 0
  fi

  mkdir -p "$UNISHELL_SANDBOX" 2>/dev/null
  rm -f "$IPC_SIG_OUT" 2>/dev/null

  printf '  First, the receiver is started in the background. It installs its\n'
  printf '  handlers, prints its pid, and waits for a signal with an alarm()\n'
  printf '  deadline so it can never wait for ever.\n\n'

  # COMMAND: ./bin/signal_receiver <timeout> & | PURPOSE: start the receiving half in the background | MODULE: Inter-Process Communication
  "$IPC_BIN/signal_receiver" 8 > "$IPC_SIG_OUT" 2>&1 &
  sigpid=$!

  # Wait until the receiver really is waiting, so the signal cannot arrive
  # before its handler is installed.
  if ! ipc_wait_for "$IPC_SIG_OUT" "waiting for a signal now"; then
    msg_warn "The receiver did not reach its waiting state in time."
  fi
  printf '  Receiver (pid %s) is waiting.\n\n' "$sigpid"

  printf '  Now the sender is given that pid. It is the only pid UniShell ever\n'
  printf '  passes, so the signal can only reach a process UniShell started.\n\n'

  # COMMAND: ./bin/signal_sender <pid> USR1 | PURPOSE: send one allowed signal to the receiver we started | MODULE: Inter-Process Communication
  "$IPC_BIN/signal_sender" "$sigpid" USR1
  rc=$?
  printf '\n  bin/signal_sender exited with status %s\n' "$rc"

  # COMMAND: wait <pid> | PURPOSE: collect the receiver and read its exit status | MODULE: Process Management
  wait "$sigpid"
  recrc=$?

  printf '\n  --- what the receiver printed (exit status %s) ---\n' "$recrc"
  cat "$IPC_SIG_OUT" 2>/dev/null

  printf '\n'
  msg_info "The receiver caught the signal in its handler, printed which one it"
  msg_info "was, and exited normally - it was not stopped. That is the whole"
  msg_info "point of a handler: the program decides what a signal means."

  rm -f "$IPC_SIG_OUT" 2>/dev/null
  log_activity_exit "ipc" "ran the signal receiver and sender" "$recrc"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 6. Read the source of a demonstration
# ------------------------------------------------------------
ipc_read_source() {
  section_title "Read the source of a demonstration"
  local pick file

  printf '  %s\n' " 1. pipe_demo.c        an unnamed pipe between a parent and a child"
  printf '  %s\n' " 2. fifo_receiver.c    creates a FIFO, waits with poll(), removes it"
  printf '  %s\n' " 3. fifo_sender.c      opens a FIFO for writing and sends a message"
  printf '  %s\n' " 4. signal_demo.c      handlers, raise(), alarm() and SIG_IGN"
  printf '  %s\n' " 5. signal_receiver.c  waits for a signal with an alarm() deadline"
  printf '  %s\n' " 6. signal_sender.c    sends one allowed signal to one process"
  printf '\n'

  if ! ask_choice "Choose a file (1-6): " 1 6; then
    return 0
  fi
  pick="$UNISHELL_CHOICE"

  # The number is only compared with fixed values; no typed text becomes a path.
  case "$pick" in
    1) file="$IPC_SRC/pipe_demo.c" ;;
    2) file="$IPC_SRC/fifo_receiver.c" ;;
    3) file="$IPC_SRC/fifo_sender.c" ;;
    4) file="$IPC_SRC/signal_demo.c" ;;
    5) file="$IPC_SRC/signal_receiver.c" ;;
    6) file="$IPC_SRC/signal_sender.c" ;;
    *) return 0 ;;
  esac

  if [ ! -r "$file" ]; then
    msg_err "Cannot read $file"
    log_activity "ipc" "source file missing" "error"
    press_enter_to_continue
    return 0
  fi

  printf '\n'
  # COMMAND: cat | PURPOSE: display the source file for reading, without running anything | MODULE: Unix Basics
  cat "$file"

  printf '\n'
  msg_info "This is the same file 'make all' compiles into bin/. Every wait in"
  msg_info "these programs has a deadline, so a missing partner cannot hang them."

  log_activity "ipc" "displayed source: ${file##*/}" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 7. Run every IPC demonstration
# ------------------------------------------------------------
ipc_run_everything() {
  section_title "Every IPC demonstration"

  printf '  The demonstrations will be run in order. Each one is a real\n'
  printf '  program using a real kernel facility.\n'

  printf '\n--- 1. unnamed pipe: bin/pipe_demo ---\n'
  if ipc_require_bin "pipe_demo"; then
    # COMMAND: ./bin/pipe_demo | PURPOSE: run the unnamed pipe demonstration | MODULE: Inter-Process Communication
    "$IPC_BIN/pipe_demo"
    printf '\n  bin/pipe_demo exited with status %s\n' "$?"
  fi

  printf '\n--- 2. signals and handlers: bin/signal_demo ---\n'
  if ipc_require_bin "signal_demo"; then
    # COMMAND: ./bin/signal_demo | PURPOSE: run the self-contained signal demonstration | MODULE: Inter-Process Communication
    "$IPC_BIN/signal_demo"
    printf '\n  bin/signal_demo exited with status %s\n' "$?"
  fi

  printf '\n--- 3. named pipe: receiver and sender ---\n'
  ipc_run_fifo_quiet

  printf '\n--- 4. signals: receiver and sender ---\n'
  ipc_run_signal_pair_quiet

  printf '\n'
  msg_info "All four demonstrations finished. The pipe and the FIFO were removed"
  msg_info "when their descriptors closed, and every signal went only to a"
  msg_info "process UniShell had started itself."

  log_activity "ipc" "ran every IPC demonstration" "OK"
  press_enter_to_continue
}

# The "run everything" path needs the same two demonstrations without the
# extra explanations and the pause between them. These two helpers do exactly
# the same work and reuse ipc_wait_for, so there is one implementation of the
# tricky part (waiting for the background program to be ready).
ipc_run_fifo_quiet() {
  local recpid rc

  mkdir -p "$UNISHELL_SANDBOX" 2>/dev/null
  check_inside_sandbox "$IPC_FIFO" || { msg_err "FIFO path is outside the sandbox."; return 0; }

  rm -f "$IPC_FIFO" "$IPC_FIFO_OUT" 2>/dev/null
  mkfifo -m 600 "$IPC_FIFO" 2>/dev/null

  "$IPC_BIN/fifo_receiver" "$IPC_FIFO" 6 > "$IPC_FIFO_OUT" 2>&1 &
  recpid=$!
  ipc_wait_for "$IPC_FIFO_OUT" "poll()"

  printf '  sender says:\n'
  "$IPC_BIN/fifo_sender" "$IPC_FIFO" "hello through the named pipe"
  rc=$?
  wait "$recpid"
  local recrc=$?

  printf '  receiver says (exit %s):\n' "$recrc"
  # COMMAND: sed | PURPOSE: indent the captured output so it reads as a quote | MODULE: 4
  sed 's/^/    /' "$IPC_FIFO_OUT" 2>/dev/null

  rm -f "$IPC_FIFO" "$IPC_FIFO_OUT" 2>/dev/null
  log_activity_exit "ipc" "ran the FIFO receiver and sender" "$recrc"
  [ "$rc" -eq 0 ] || msg_warn "the sender exited with status $rc"
  return 0
}

ipc_run_signal_pair_quiet() {
  local sigpid rc recrc

  mkdir -p "$UNISHELL_SANDBOX" 2>/dev/null
  rm -f "$IPC_SIG_OUT" 2>/dev/null

  "$IPC_BIN/signal_receiver" 8 > "$IPC_SIG_OUT" 2>&1 &
  sigpid=$!
  ipc_wait_for "$IPC_SIG_OUT" "waiting for a signal now"

  "$IPC_BIN/signal_sender" "$sigpid" USR1
  rc=$?
  wait "$sigpid"
  recrc=$?

  printf '  receiver says (exit %s):\n' "$recrc"
  sed 's/^/    /' "$IPC_SIG_OUT" 2>/dev/null

  rm -f "$IPC_SIG_OUT" 2>/dev/null
  log_activity_exit "ipc" "ran the signal receiver and sender" "$recrc"
  [ "$rc" -eq 0 ] || msg_warn "the sender exited with status $rc"
  return 0
}
