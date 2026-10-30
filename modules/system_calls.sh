#!/usr/bin/env bash
# ============================================================
# UniShell - Module 8: C System Calls Demonstrations   (Phase 7)
# ============================================================
# Teaches what a system call is and runs the real compiled C program
# bin/file_io, which calls open(), read(), write(), close(), creat(), mkdir(),
# rmdir(), chdir() and getcwd() and shows the value each one returned.
#
# Safety: file_io is only ever given a path inside ./sandbox, and the path is
# checked with check_inside_sandbox() first. The program removes everything it
# creates before it exits. Nothing typed by the user is executed as code.
#
# This file is SOURCED by unishell.sh, which then calls module_system_calls.
# ============================================================

# COMMAND: (path) | PURPOSE: point at the compiled demonstrations and their sources | MODULE: C System Calls
SC_BIN="$UNISHELL_BIN"
SC_SRC="$UNISHELL_ROOT/c_programs"

# ------------------------------------------------------------
# Sub-menu
# ------------------------------------------------------------
module_system_calls() {
  local choice

  while :; do
    section_title "Module 8 - C System Calls Demonstrations"
    printf '  %s\n' " 1. What is a system call?"
    printf '  %s\n' " 2. Run the file and directory demonstration (inside ./sandbox)"
    printf '  %s\n' " 3. The file calls: open, read, write, close, creat"
    printf '  %s\n' " 4. The directory calls: mkdir, rmdir, chdir, getcwd"
    printf '  %s\n' " 5. Read the source of a demonstration"
    printf '  %s\n' " 6. Run every C demonstration"
    printf '  %s\n' " 0. Back to the main menu"
    printf '\n'

    if ! ask_choice "Choose an option (0-6): " 0 6; then
      return 0
    fi
    choice="$UNISHELL_CHOICE"

    case "$choice" in
      1) sc_explain_what ;;
      2) sc_run_file_io ;;
      3) sc_explain_file_calls ;;
      4) sc_explain_dir_calls ;;
      5) sc_read_source ;;
      6) sc_run_all ;;
      0) return 0 ;;
    esac
  done
}

# ------------------------------------------------------------
# Build helper: make sure bin/<name> exists
# ------------------------------------------------------------
sc_require_bin() {
  local name="$1"
  local path="$SC_BIN/$name"

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

# ------------------------------------------------------------
# 1. What is a system call?
# ------------------------------------------------------------
sc_explain_what() {
  section_title "What is a system call?"

  printf '  A system call is the way a program asks the kernel to do something\n'
  printf '  for it. A program cannot touch the disk, the network or another\n'
  printf '  process by itself; it has to ask, and the kernel does the work.\n\n'

  printf '  Reading a file is therefore not one step but several:\n'
  printf '    open()  asks the kernel to open the file and hand back a number\n'
  printf '            called a file descriptor (a small integer, like 3).\n'
  printf '    read()  asks the kernel for the next bytes from that descriptor.\n'
  printf '    close() tells the kernel the program has finished with it.\n\n'

  printf '  Almost every system call returns a value that must be checked:\n'
  printf '    -1 means it failed, and errno explains why (perror() prints it).\n'
  printf '    0 or more means it worked, and the number has a meaning.\n\n'

  printf '  The programs in c_programs/ call these functions directly:\n'
  # COMMAND: ls -1 | PURPOSE: list the real C sources that ship with UniShell | MODULE: Unix Basics
  if [ -d "$SC_SRC" ]; then
    ( cd "$SC_SRC" && ls -1 *.c 2>/dev/null )
  else
    msg_warn "The source folder is missing: $SC_SRC"
  fi

  printf '\n'
  msg_info "They are compiled by 'make all' into bin/, so the same source is"
  msg_info "compiled once and then run as many times as you like."

  log_activity "system_calls" "explained what a system call is" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 2. Run bin/file_io inside ./sandbox
# ------------------------------------------------------------
sc_run_file_io() {
  section_title "The file and directory demonstration"
  local work entry rc

  if ! sc_require_bin "file_io"; then
    log_activity "system_calls" "missing C demonstration: file_io" "error"
    press_enter_to_continue
    return 0
  fi

  # COMMAND: mkdir -p | PURPOSE: make sure ./sandbox exists before the program writes | MODULE: Unix Basics
  mkdir -p "$UNISHELL_SANDBOX" 2>/dev/null

  # The program is always given a path inside ./sandbox, never anywhere else.
  work="$UNISHELL_SANDBOX/file_io_demo"

  # Second, independent check before anything is run.
  if ! check_inside_sandbox "$work"; then
    msg_err "Refusing to run: $work is not inside the sandbox."
    log_activity "system_calls" "sandbox guard refused the file_io path" "refused"
    press_enter_to_continue
    return 0
  fi

  printf '  The program is given this working directory:\n'
  printf '    %s\n' "$work"
  printf '  That is inside %s, so no file can be made anywhere else.\n\n' "$UNISHELL_SANDBOX"

  # COMMAND: ./bin/file_io <dir> | PURPOSE: run the C demonstration on a directory inside the sandbox | MODULE: C System Calls
  "$SC_BIN/file_io" "$work"
  rc=$?
  printf '\n  bin/file_io exited with status %s\n' "$rc"

  printf '\n  ./sandbox now holds:\n'
  for entry in "$UNISHELL_SANDBOX"/* "$UNISHELL_SANDBOX"/.[!.]*; do
    [ -e "$entry" ] || continue
    printf '    %s\n' "${entry##*/}"
  done

  printf '\n'
  msg_info "The program removes everything it created, so only the files that"
  msg_info "were already there (or nothing at all) are left."

  log_activity "system_calls" "ran C demonstration: file_io" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 3. The file calls
# ------------------------------------------------------------
sc_explain_file_calls() {
  section_title "The file calls: open, read, write, close, creat"

  printf '  creat(path, mode)\n'
  printf '    Creates a file (or empties an existing one) and returns a file\n'
  printf '    descriptor. It is the older, shorter form of open() with the flags\n'
  printf '    O_WRONLY | O_CREAT | O_TRUNC.\n\n'

  printf '  open(path, flags)\n'
  printf '    Opens a file and returns a descriptor, or -1 on failure.\n'
  printf '      O_RDONLY          read only\n'
  printf '      O_WRONLY|O_APPEND write only, adding to the end without erasing\n'
  printf '      O_WRONLY|O_CREAT  create the file when it is not there yet\n\n'

  printf '  read(fd, buffer, count)\n'
  printf '    Asks for up to count bytes. It returns how many it really gave\n'
  printf '    back, which may be fewer than asked; 0 means end of file; -1 is an\n'
  printf '    error.\n\n'

  printf '  write(fd, buffer, count)\n'
  printf '    Sends count bytes. It may accept fewer than count, so a correct\n'
  printf '    program writes in a loop until everything has been sent. bin/file_io\n'
  printf '    does exactly that in its write_all() helper.\n\n'

  printf '  close(fd)\n'
  printf '    Releases the descriptor. Every open() and creat() needs a matching\n'
  printf '    close(), otherwise descriptors leak until the program runs out.\n\n'

  msg_info "run bin/file_io (option 2) and then read file_io.c (option 5): the"
  msg_info "printed step numbers 1 to 11 match the calls in the source."

  log_activity "system_calls" "explained the file system calls" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 4. The directory calls
# ------------------------------------------------------------
sc_explain_dir_calls() {
  section_title "The directory calls: mkdir, rmdir, chdir, getcwd"

  printf '  mkdir(path, mode)\n'
  printf '    Creates a directory. If it already exists, mkdir fails with the\n'
  printf '    error EEXIST, which bin/file_io treats as "already fine".\n\n'

  printf '  rmdir(path)\n'
  printf '    Removes a directory, but only when it is EMPTY. That restriction is\n'
  printf '    deliberate: it stops a single call from throwing away a whole tree.\n\n'

  printf '  chdir(path)\n'
  printf '    Changes the current working directory of the process. After this,\n'
  printf '    a simple name such as "hello.txt" points inside the new directory.\n'
  printf '    chdir("..") goes back up one level.\n\n'

  printf '  getcwd(buffer, size)\n'
  printf '    Writes the current working directory into the buffer, so the\n'
  printf '    program can print where it is. bin/file_io calls it before and\n'
  printf '    after chdir() so the move is visible.\n\n'

  printf '  One trap worth remembering\n'
  printf '    A relative path is resolved against the CURRENT directory. After\n'
  printf '    chdir(), a relative path that was fine a moment ago may point\n'
  printf '    somewhere else. bin/file_io therefore turns its argument into a\n'
  printf '    full path before it moves anywhere.\n'

  log_activity "system_calls" "explained the directory system calls" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 5. Read the source of a demonstration
# ------------------------------------------------------------
sc_read_source() {
  section_title "Read the source of a demonstration"
  local pick file

  printf '  %s\n' " 1. file_io.c      file and directory system calls"
  printf '  %s\n' " 2. process_fork.c fork() and wait()"
  printf '  %s\n' " 3. exec_demo.c    the exec() family"
  printf '  %s\n' " 4. wait_demo.c    waitpid(), zombies and orphans"
  printf '\n'

  if ! ask_choice "Choose a file (1-4): " 1 4; then
    return 0
  fi
  pick="$UNISHELL_CHOICE"

  # The number is only compared with fixed values; no typed text becomes a path.
  case "$pick" in
    1) file="$SC_SRC/file_io.c" ;;
    2) file="$SC_SRC/process_fork.c" ;;
    3) file="$SC_SRC/exec_demo.c" ;;
    4) file="$SC_SRC/wait_demo.c" ;;
    *) return 0 ;;
  esac

  if [ ! -r "$file" ]; then
    msg_err "Cannot read $file"
    log_activity "system_calls" "source file missing" "error"
    press_enter_to_continue
    return 0
  fi

  printf '\n'
  # COMMAND: cat | PURPOSE: display the source file for reading, without running anything | MODULE: Unix Basics
  cat "$file"

  printf '\n'
  msg_info "This is the same file 'make all' compiles into bin/. It only ever"
  msg_info "writes inside the directory it is given, which UniShell keeps inside"
  msg_info "./sandbox."

  log_activity "system_calls" "displayed source: ${file##*/}" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 6. Run every C demonstration
# ------------------------------------------------------------
sc_run_all() {
  section_title "Every C demonstration"
  local name rc work

  mkdir -p "$UNISHELL_SANDBOX" 2>/dev/null
  work="$UNISHELL_SANDBOX/file_io_demo"

  # file_io needs a directory argument, so it is run first and on its own.
  if sc_require_bin "file_io" && check_inside_sandbox "$work"; then
    printf '\n--- bin/file_io %s ---\n' "$work"
    # COMMAND: ./bin/file_io <dir> | PURPOSE: run the file and directory demonstration inside the sandbox | MODULE: C System Calls
    "$SC_BIN/file_io" "$work"
    rc=$?
    printf '\n  bin/file_io exited with status %s\n' "$rc"
  else
    msg_err "Skipping bin/file_io."
  fi

  for name in process_fork exec_demo wait_demo; do
    printf '\n--- bin/%s ---\n' "$name"
    if sc_require_bin "$name"; then
      # COMMAND: ./bin/<name> | PURPOSE: run each compiled demonstration in order | MODULE: C System Calls
      "$SC_BIN/$name"
      rc=$?
      printf '\n  bin/%s exited with status %s\n' "$name" "$rc"
    else
      msg_err "Skipping bin/$name because it could not be built."
    fi
  done

  printf '\n'
  msg_info "All four programs returned 0, which means every system call they"
  msg_info "made reported success."

  log_activity "system_calls" "ran every C demonstration" "OK"
  press_enter_to_continue
}
