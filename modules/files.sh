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

# files_rel <path> - print a path the way the project sees it, for example
# sandbox/notes.txt, so every message can show the path that was created.
files_rel() {
  printf 'sandbox/%s\n' "${1#"$UNISHELL_SANDBOX"/}"
}

# files_ask_relpath <prompt> - read a relative path into $FILES_RELPATH and its
# full path into $FILES_PATH.
# Every part between slashes must pass is_safe_name, which already refuses an
# empty part, "." and "..", so "demo/inner" is accepted while "../etc" is not.
# An absolute path is refused up front. check_inside_sandbox then confirms the
# finished path really is inside ./sandbox.
files_ask_relpath() {
  local prompt="$1" rel rest part

  if ! ask_text "$prompt"; then
    msg_warn "No path was given."
    return 1
  fi
  rel="$UNISHELL_INPUT"

  # A leading slash means an absolute path, which would leave the sandbox.
  case "$rel" in
    /*)
      msg_err "Absolute paths are refused. Use a path inside ./sandbox."
      return 1
      ;;
  esac

  rest="$rel"
  while [ -n "$rest" ]; do
    case "$rest" in
      */*) part="${rest%%/*}"; rest="${rest#*/}" ;;
      *)   part="$rest";       rest="" ;;
    esac
    if ! is_safe_name "$part"; then
      msg_err "That is not a safe relative path inside ./sandbox."
      return 1
    fi
  done

  FILES_RELPATH="$rel"
  FILES_PATH="$UNISHELL_SANDBOX/$rel"

  # Final, independent check on the resolved path.
  # COMMAND: path check | PURPOSE: prove the resolved path really is inside ./sandbox | MODULE: Unix Basics
  if ! check_inside_sandbox "$FILES_PATH"; then
    msg_err "Refused: that path is not inside ./sandbox."
    return 1
  fi
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
    printf '  %s\n' "1. Create files and directories (touch, mkdir, mkdir -p)"
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
      1) files_menu_create ;;
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
# The create sub-menu. Nothing here is created automatically: every name is
# typed by the user, and an existing name is never written over.
files_menu_create() {
  local choice

  while :; do
    section_title "Create files and directories"
    printf '  Working folder: %s\n' "$UNISHELL_SANDBOX"
    printf '\n'
    printf '  %s\n' "1. Create a new file (touch)"
    printf '  %s\n' "2. Create a new directory (mkdir)"
    printf '  %s\n' "3. Create nested directories (mkdir -p)"
    printf '  %s\n' "4. Create multiple files (touch)"
    printf '  %s\n' "5. Create a file with custom content (> and a here-document)"
    printf '  %s\n' "6. Return to previous menu"
    printf '\n'

    if ! ask_choice "Choose an option (1-6): " 1 6; then
      return 0
    fi
    choice="$UNISHELL_CHOICE"

    case "$choice" in
      1) files_create_file ;;
      2) files_create_dir ;;
      3) files_create_nested ;;
      4) files_create_many ;;
      5) files_create_with_content ;;
      6) return 0 ;;
    esac
  done
}

# 1 - create one empty file with a name the user types.
files_create_file() {
  local path

  section_title "Create a new file"
  files_ask_name "Name for the new file (for example: notes.txt): " || { press_enter_to_continue; return 0; }
  path="$(sandbox_path "$FILES_NAME")" || { press_enter_to_continue; return 0; }

  # Second, independent check: the resolved path must still be inside ./sandbox.
  if ! check_inside_sandbox "$path"; then
    msg_err "Refused: that path is not inside ./sandbox."
    log_activity "files" "refused create outside sandbox" "refused"
    press_enter_to_continue
    return 0
  fi

  if [ -d "$path" ]; then
    msg_err "'$FILES_NAME' is already a directory, so a file cannot use that name."
    log_activity "files" "create file on a directory name" "refused"
    press_enter_to_continue
    return 0
  fi

  if [ -e "$path" ]; then
    msg_warn "'$FILES_NAME' already exists, so nothing was changed."
    msg_info "An existing file is never overwritten. Use option 5 if you want to"
    msg_info "replace its content, and confirm when you are asked."
    log_activity "files" "create file: name exists" "refused"
    press_enter_to_continue
    return 0
  fi

  # COMMAND: touch | PURPOSE: create an empty file with the typed name | MODULE: Unix Basics
  if touch -- "$path" 2>/dev/null; then
    msg_ok "touch created $(files_rel "$path")"
    ls -l -- "$path"
    log_activity "files" "demo: create a new file" "OK"
  else
    msg_err "touch could not create '$FILES_NAME'."
    log_activity "files" "create file failed" "error"
  fi
  press_enter_to_continue
}

# 2 - create one directory with a name the user types.
files_create_dir() {
  local path

  section_title "Create a new directory"
  files_ask_name "Name for the new directory (for example: docs): " || { press_enter_to_continue; return 0; }
  path="$(sandbox_path "$FILES_NAME")" || { press_enter_to_continue; return 0; }

  if ! check_inside_sandbox "$path"; then
    msg_err "Refused: that path is not inside ./sandbox."
    log_activity "files" "refused create outside sandbox" "refused"
    press_enter_to_continue
    return 0
  fi

  if [ -e "$path" ]; then
    if [ -d "$path" ]; then
      msg_warn "'$FILES_NAME' already exists as a directory, so nothing was changed."
    else
      msg_err "'$FILES_NAME' already exists as a file, so a directory cannot use that name."
    fi
    log_activity "files" "create dir: name exists" "refused"
    press_enter_to_continue
    return 0
  fi

  # COMMAND: mkdir | PURPOSE: create one directory, and refuse when the name is already taken | MODULE: Unix Basics
  if mkdir -- "$path" 2>/dev/null; then
    msg_ok "mkdir created $(files_rel "$path")"
    ls -ld -- "$path"
    log_activity "files" "demo: create a new directory" "OK"
  else
    msg_err "mkdir could not create '$FILES_NAME'."
    log_activity "files" "create dir failed" "error"
  fi
  press_enter_to_continue
}

# 3 - create a whole branch such as demo/inner in one step.
files_create_nested() {
  local rel path

  section_title "Create nested directories"
  printf 'Type a relative path. Every folder in it is created, including the\n'
  printf 'missing parents, in one mkdir -p step.\n\n'

  files_ask_relpath "Relative path inside ./sandbox (for example: demo/inner): " || { press_enter_to_continue; return 0; }
  rel="$FILES_RELPATH"
  path="$FILES_PATH"

  if [ -e "$path" ] && [ ! -d "$path" ]; then
    msg_err "'$rel' already exists as a file, so a directory cannot use that name."
    log_activity "files" "create nested: name exists" "refused"
    press_enter_to_continue
    return 0
  fi

  # COMMAND: mkdir -p | PURPOSE: create the directory and every missing parent in one step | MODULE: Unix Basics
  if mkdir -p -- "$path" 2>/dev/null; then
    msg_ok "mkdir -p created $(files_rel "$path")"
    printf '\nEach level now exists:\n'
    # COMMAND: find | PURPOSE: list the branch that mkdir -p just made | MODULE: Unix Basics
    ( cd "$UNISHELL_SANDBOX" && find "./$rel" -print 2>/dev/null )
    printf '\n'
    msg_info "mkdir without -p fails when a parent is missing. mkdir -p makes"
    msg_info "every missing parent and stays quiet when the path already exists."
    log_activity "files" "demo: create nested directories" "OK"
  else
    msg_err "mkdir -p could not create '$rel'."
    log_activity "files" "create nested failed" "error"
  fi
  press_enter_to_continue
}

# 4 - create several files, one name per line, until an empty line is typed.
files_create_many() {
  local line path made=0 skipped=0

  section_title "Create multiple files"
  printf 'Type one file name per line. Press Enter on an empty line when you\n'
  printf 'are finished.\n\n'

  while :; do
    printf 'New file name (empty line to finish): '
    # COMMAND: read -r | PURPOSE: read one file name exactly as typed | MODULE: Unix Basics
    if ! read -r line; then
      printf '\n'
      break
    fi
    [ -n "$line" ] || break

    if ! is_safe_name "$line"; then
      msg_err "That is not a safe name, so it was skipped."
      skipped=$((skipped + 1))
      continue
    fi
    path="$(sandbox_path "$line")" || { skipped=$((skipped + 1)); continue; }

    if ! check_inside_sandbox "$path"; then
      msg_err "Refused: that path is not inside ./sandbox."
      skipped=$((skipped + 1))
      continue
    fi

    if [ -e "$path" ]; then
      msg_warn "'$line' already exists, so it was left untouched."
      skipped=$((skipped + 1))
      continue
    fi

    # COMMAND: touch | PURPOSE: create one empty file per typed name | MODULE: Unix Basics
    if touch -- "$path" 2>/dev/null; then
      msg_ok "touch created $(files_rel "$path")"
      made=$((made + 1))
    else
      msg_err "touch could not create '$line'."
      skipped=$((skipped + 1))
    fi
  done

  printf '\n'
  msg_info "touch created $made file(s); $skipped name(s) were skipped."
  log_activity "files" "demo: create multiple files" "OK"
  press_enter_to_continue
}

# 5 - create one file and let the user type its content until a line says END.
files_create_with_content() {
  local path line content="" lines

  section_title "Create a file with custom content"
  files_ask_name "Name for the file (for example: note.txt): " || { press_enter_to_continue; return 0; }
  path="$(sandbox_path "$FILES_NAME")" || { press_enter_to_continue; return 0; }

  if ! check_inside_sandbox "$path"; then
    msg_err "Refused: that path is not inside ./sandbox."
    log_activity "files" "refused create outside sandbox" "refused"
    press_enter_to_continue
    return 0
  fi

  if [ -d "$path" ]; then
    msg_err "'$FILES_NAME' is already a directory, so a file cannot use that name."
    log_activity "files" "create content on a directory name" "refused"
    press_enter_to_continue
    return 0
  fi

  # Writing would replace the whole file, so an existing name needs a clear yes.
  if [ -e "$path" ]; then
    msg_warn "'$FILES_NAME' already exists. Writing would replace its content."
    if ! ask_yes_no "Replace '$FILES_NAME' with the new content?"; then
      msg_info "Nothing was written."
      log_activity "files" "create content: overwrite declined" "refused"
      press_enter_to_continue
      return 0
    fi
  fi

  printf '\nType the content, one line at a time.\n'
  printf 'Finish with a line that contains only: END\n\n'

  while :; do
    printf '> '
    # COMMAND: read -r | PURPOSE: read one line of content exactly as typed | MODULE: Text Processing
    if ! read -r line; then
      printf '\n'
      break
    fi
    if [ "$line" = "END" ]; then
      break
    fi
    content+="$line"$'\n'
  done

  # COMMAND: > | PURPOSE: write the collected text into the file, only after the user agreed | MODULE: Text Processing
  if printf '%s' "$content" > "$path" 2>/dev/null; then
    lines="$(printf '%s' "$content" | wc -l)"
    msg_ok "Wrote $(files_rel "$path") ($lines line(s))"
    printf '\n--- cat %s ---\n' "$(files_rel "$path")"
    # COMMAND: cat | PURPOSE: show what was just written | MODULE: Unix Basics
    cat -- "$path"
    log_activity "files" "demo: create a file with content" "OK"
  else
    msg_err "Could not write '$FILES_NAME'."
    log_activity "files" "write content failed" "error"
  fi
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

  files_ask_name "Source file inside ./sandbox (for example: notes.txt): " || { press_enter_to_continue; return 0; }
  src="$(sandbox_path "$FILES_NAME")" || { press_enter_to_continue; return 0; }

  if [ ! -f "$src" ]; then
    msg_err "There is no file named '$FILES_NAME' in ./sandbox."
    msg_info "Create a file first with option 1, then list what is there with option 2."
    msg_info "Only a plain name is accepted, so a path can never leave ./sandbox."
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
    msg_info "Create a file first with option 1, then list what is there with option 2."
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
