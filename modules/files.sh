#!/usr/bin/env bash
# ============================================================
# UniShell - Module 2: File and Directory Management
# ============================================================
# Runs real file and directory commands, but only ever inside ./sandbox.
# Every name typed by the user passes is_safe_name, and every destructive
# action is re-checked with check_inside_sandbox before it runs.
#
# This file is SOURCED by unishell.sh, which then calls module_files.
# ============================================================

# ------------------------------------------------------------
# Small helpers
# ------------------------------------------------------------

# files_ask_name <prompt> - read one safe name into $FILES_NAME.
# Returns 0 on success, 1 when the input was empty, ended or unsafe.
files_ask_name() {
  local prompt="$1"
  if ! ask_text "$prompt"; then
    msg_warn "No name was given."
    return 1
  fi
  FILES_NAME="$UNISHELL_INPUT"
  # Refuse anything with a slash, a space or a leading dash, so a name can
  # never point outside the sandbox.
  if ! is_safe_name "$FILES_NAME"; then
    msg_err "That is not a safe name. Use letters, digits, dot, dash or underscore."
    return 1
  fi
  return 0
}

# files_make_demo_tree - create the sample tree the demos use.
files_make_demo_tree() {
  # COMMAND: mkdir -p | PURPOSE: create a directory and any missing parents | MODULE: Unix Basics
  mkdir -p "$UNISHELL_SANDBOX/demo/inner" 2>/dev/null || return 1
  # COMMAND: touch | PURPOSE: create an empty file, or refresh its timestamps | MODULE: Unix Basics
  touch "$UNISHELL_SANDBOX/demo/hello.txt" "$UNISHELL_SANDBOX/notes.txt" 2>/dev/null || return 1
  # COMMAND: > | PURPOSE: write text into a file | MODULE: Text Processing
  printf 'line one\nline two\n' > "$UNISHELL_SANDBOX/demo/hello.txt"
  # COMMAND: > | PURPOSE: write text into a file | MODULE: Text Processing
  printf 'UniShell practice file\nalpha beta gamma\n' > "$UNISHELL_SANDBOX/notes.txt"
  return 0
}

# ------------------------------------------------------------
# Sub-menu
# ------------------------------------------------------------
module_files() {
  local choice

  # COMMAND: mkdir -p | PURPOSE: make sure ./sandbox exists before anything is written | MODULE: Unix Basics
  mkdir -p "$UNISHELL_SANDBOX" 2>/dev/null

  while :; do
    section_title "Module 2 - File and Directory Management"
    printf '  %s\n' "  Working folder: $UNISHELL_SANDBOX"
    printf '\n'
    printf '  %s\n' "1. Create files and directories (touch, mkdir -p)"
    printf '  %s\n' "2. List contents (ls, ls -a, ls -l, ls -R)"
    printf '  %s\n' "3. Paths and errors (pwd, cd, absolute vs relative)"
    printf '  %s\n' "4. Copy and move (cp, mv)"
    printf '  %s\n' "5. Remove a file or empty directory (rm, rmdir)"
    printf '  %s\n' "6. View a file (cat, wc, od)"
    printf '  %s\n' "7. Reset the sandbox"
    printf '  %s\n' "0. Back to the main menu"
    printf '\n'

    if ! ask_choice "Choose an option (0-7): " 0 7; then
      return 0
    fi
    choice="$UNISHELL_CHOICE"

    case "$choice" in
      1) files_demo_create ;;
      2) files_demo_list ;;
      3) files_demo_paths ;;
      4) files_demo_copy_move ;;
      5) files_demo_remove ;;
      6) files_demo_view ;;
      7) files_demo_reset ;;
      0) return 0 ;;
    esac
  done
}

# ------------------------------------------------------------
# 1. Create
# ------------------------------------------------------------
files_demo_create() {
  section_title "Create files and directories"

  if files_make_demo_tree; then
    msg_ok "Created: sandbox/demo/  sandbox/demo/inner/  sandbox/demo/hello.txt"
  else
    msg_err "Could not create the demo tree inside $UNISHELL_SANDBOX"
    log_activity "files" "create demo tree failed" "error"
    press_enter_to_continue
    return 0
  fi

  printf '\n'
  msg_info "mkdir -p makes every missing parent folder and does not fail when"
  msg_info "the path already exists, so running this demo twice is harmless."

  printf '\nTry the plain form, which refuses to overwrite:\n'
  # COMMAND: mkdir (without -p) | PURPOSE: show the error when the directory already exists | MODULE: Unix Basics
  if mkdir "$UNISHELL_SANDBOX/demo" 2>"$UNISHELL_SANDBOX/.mkdir.err"; then
    msg_ok "mkdir created the directory."
  else
    msg_warn "mkdir refused: $(cat "$UNISHELL_SANDBOX/.mkdir.err")"
    msg_info "That message went to standard error and the program kept running."
  fi
  rm -f -- "$UNISHELL_SANDBOX/.mkdir.err"

  log_activity "files" "demo: create files and directories" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 2. List
# ------------------------------------------------------------
files_demo_list() {
  section_title "Listing a directory"

  printf '\n--- ls ---\n'
  # COMMAND: ls | PURPOSE: list the names in a directory | MODULE: Unix Basics
  ls -- "$UNISHELL_SANDBOX"

  printf '\n--- ls -a  (includes hidden names that begin with a dot) ---\n'
  # COMMAND: ls -a | PURPOSE: list all entries, including hidden files and the . and .. links | MODULE: Unix Basics
  ls -a -- "$UNISHELL_SANDBOX"

  printf '\n--- ls -l ---\n'
  # COMMAND: ls -l | PURPOSE: long listing with permissions, owner, size and date | MODULE: Unix Basics
  ls -l -- "$UNISHELL_SANDBOX"

  printf '\n--- ls -R ---\n'
  # COMMAND: ls -R | PURPOSE: list every subdirectory as well | MODULE: Unix Basics
  ls -R -- "$UNISHELL_SANDBOX"

  printf '\n'
  msg_info "'.' is the directory itself and '..' is its parent."
  msg_info "A name starting with a dot is hidden: plain ls skips it, ls -a shows it."
  log_activity "files" "demo: list a directory" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 3. Paths and errors
# ------------------------------------------------------------
files_demo_paths() {
  section_title "Paths: absolute, relative, . and .."

  # COMMAND: pwd | PURPOSE: print the absolute path of the current directory | MODULE: Unix Basics
  printf 'Absolute path : %s\n' "$(pwd)"
  printf 'Sandbox (absolute) : %s\n' "$UNISHELL_SANDBOX"
  printf 'Sandbox (relative) : %s\n' "sandbox"
  printf '\nRelative paths are read from the current directory, so "sandbox" only\n'
  printf 'means the same thing while UniShell is in its project folder.\n'
  printf '\n  .  = the current directory -> %s\n' "$UNISHELL_SANDBOX"
  printf '  .. = the parent directory  -> %s\n' "$(dirname "$UNISHELL_SANDBOX")"

  printf '\nChanging directory has to happen in a subshell, because cd is a\n'
  printf 'builtin that would otherwise move the whole program.\n'
  # COMMAND: cd | PURPOSE: change directory, here inside a subshell | MODULE: Unix Basics
  (
    cd "$UNISHELL_SANDBOX" 2>/dev/null || exit 0
    printf '  inside sandbox, pwd says: %s\n' "$(pwd)"
  )

  printf '\nNow the same command on a directory that does not exist:\n'
  # COMMAND: cd (missing path) | PURPOSE: show how a failed command reports an error and returns 1 | MODULE: Unix Basics
  if ( cd "$UNISHELL_SANDBOX/does-not-exist" 2>/dev/null ); then
    msg_warn "Unexpected: cd succeeded."
  else
    msg_ok "cd failed, as expected, and UniShell carried on. (exit status 1)"
  fi

  log_activity "files" "demo: paths and errors" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 4. Copy and move
# ------------------------------------------------------------
files_demo_copy_move() {
  local src dst

  section_title "Copy and move"
  files_make_demo_tree

  files_ask_name "Source file inside ./sandbox (for example: notes.txt): " || { press_enter_to_continue; return 0; }
  src="$(sandbox_path "$FILES_NAME")" || { press_enter_to_continue; return 0; }

  if [ ! -f "$src" ]; then
    msg_err "There is no file named '$FILES_NAME' in ./sandbox."
    msg_info "Option 1 creates sandbox/notes.txt: use a plain name, because a"
    msg_info "name with a slash is refused so it can never leave the sandbox."
    log_activity "files" "copy source missing" "not-found"
    press_enter_to_continue
    return 0
  fi

  files_ask_name "Copy it to (a plain name in ./sandbox): " || { press_enter_to_continue; return 0; }
  dst="$(sandbox_path "$FILES_NAME")" || { press_enter_to_continue; return 0; }

  # COMMAND: cp | PURPOSE: copy a file, keeping the original | MODULE: Unix Basics
  if cp -- "$src" "$dst" 2>/dev/null; then
    msg_ok "cp created the copy."
    ls -l -- "$dst"
  else
    msg_err "cp failed. Check the name and the permissions."
    log_activity "files" "copy failed" "error"
    press_enter_to_continue
    return 0
  fi

  printf '\n'
  if ask_yes_no "Now rename that copy with mv?"; then
    files_ask_name "New name: " || { press_enter_to_continue; return 0; }
    # COMMAND: mv | PURPOSE: rename or move a file | MODULE: Unix Basics
    if mv -- "$dst" "$(sandbox_path "$FILES_NAME")" 2>/dev/null; then
      msg_ok "mv renamed the copy."
    else
      msg_err "mv failed."
    fi
  else
    msg_info "mv not run."
  fi

  log_activity "files" "demo: copy and move" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 5. Remove
# ------------------------------------------------------------
files_demo_remove() {
  local path

  section_title "Remove a file or an empty directory"
  printf 'Only names inside ./sandbox can be removed.\n\n'

  files_ask_name "Name to remove (plain name inside ./sandbox): " || { press_enter_to_continue; return 0; }
  path="$(sandbox_path "$FILES_NAME")" || { press_enter_to_continue; return 0; }

  # Second, independent check. Both checks must agree before anything is removed.
  # COMMAND: path check | PURPOSE: prove the resolved path really is inside ./sandbox | MODULE: Unix Basics
  if ! check_inside_sandbox "$path"; then
    msg_err "Refused: that path is not inside ./sandbox."
    log_activity "files" "refused removal outside sandbox" "refused"
    press_enter_to_continue
    return 0
  fi

  if [ "$FILES_NAME" = ".gitkeep" ]; then
    msg_warn "Refused: .gitkeep keeps the empty folder visible to git."
    press_enter_to_continue
    return 0
  fi

  if [ ! -e "$path" ]; then
    msg_err "Nothing named '$FILES_NAME' exists in ./sandbox."
    log_activity "files" "remove target missing" "not-found"
    press_enter_to_continue
    return 0
  fi

  if ! ask_yes_no "Really remove '$FILES_NAME'?"; then
    msg_info "Nothing was removed."
    press_enter_to_continue
    return 0
  fi

  if [ -d "$path" ]; then
    # COMMAND: rmdir | PURPOSE: remove a directory only when it is empty | MODULE: Unix Basics
    if rmdir -- "$path" 2>/dev/null; then
      msg_ok "rmdir removed the empty directory."
    else
      msg_err "rmdir refused: the directory still contains something."
      msg_info "UniShell uses rmdir instead of 'rm -r' so that data is never deleted by surprise."
    fi
  else
    # COMMAND: rm | PURPOSE: delete one file that has been checked to be inside ./sandbox | MODULE: Unix Basics
    if rm -- "$path" 2>/dev/null; then
      msg_ok "rm removed the file."
    else
      msg_err "rm failed."
    fi
  fi

  log_activity "files" "demo: remove inside sandbox" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 6. View
# ------------------------------------------------------------
files_demo_view() {
  local path

  section_title "View a file: cat, wc, od"
  files_ask_name "Name of a file inside ./sandbox: " || { press_enter_to_continue; return 0; }
  path="$(sandbox_path "$FILES_NAME")" || { press_enter_to_continue; return 0; }

  if [ ! -f "$path" ]; then
    msg_err "There is no file named '$FILES_NAME' in ./sandbox."
    msg_info "Option 1 creates demo/hello.txt; option 2 shows what is there."
    log_activity "files" "view target missing" "not-found"
    press_enter_to_continue
    return 0
  fi

  printf '\n--- cat ---\n'
  # COMMAND: cat | PURPOSE: print the whole file | MODULE: Unix Basics
  cat -- "$path"

  printf '\n--- wc -l -w -c ---\n'
  # COMMAND: wc | PURPOSE: count lines, words and bytes | MODULE: Text Processing
  wc -l -w -c -- "$path"

  printf '\n--- od -c (the first bytes, so hidden characters become visible) ---\n'
  # COMMAND: od -c | PURPOSE: show each byte as a character, including \n and \t | MODULE: Text Processing
  od -c -- "$path" | head -n 2

  log_activity "files" "demo: view a file" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 7. Reset
# ------------------------------------------------------------
files_demo_reset() {
  local entry removed=0

  section_title "Reset the sandbox"
  printf 'This deletes everything inside:\n  %s\n' "$UNISHELL_SANDBOX"
  printf 'It keeps .gitkeep and never touches anything outside ./sandbox.\n\n'

  if ! ask_yes_no "Reset the sandbox now?"; then
    msg_info "Nothing was removed."
    press_enter_to_continue
    return 0
  fi

  # -mindepth 1 keeps the sandbox directory itself out of the list, so the
  # check below can never receive the folder it is protecting.
  # COMMAND: find | PURPOSE: list every entry inside the sandbox | MODULE: Unix Basics
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    # COMMAND: path check | PURPOSE: confirm this entry is inside ./sandbox before deleting | MODULE: Unix Basics
    if ! check_inside_sandbox "$entry"; then
      msg_warn "Skipped a path that was not inside the sandbox."
      continue
    fi
    # COMMAND: rm -rf | PURPOSE: delete one entry that has just been verified to be inside ./sandbox | MODULE: Unix Basics
    if rm -rf -- "$entry" 2>/dev/null; then
      removed=$((removed + 1))
      printf '  removed: %s\n' "${entry#"$UNISHELL_SANDBOX"/}"
    fi
  done <<EOF
$(find "$UNISHELL_SANDBOX" -mindepth 1 ! -name '.gitkeep' -print 2>/dev/null)
EOF

  printf '\n'
  msg_ok "Reset finished. Entries removed: $removed"
  log_activity "files" "reset sandbox ($removed entries)" "OK"
  press_enter_to_continue
}
