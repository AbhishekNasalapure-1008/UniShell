#!/usr/bin/env bash
# ============================================================
# UniShell - Module 3: File Permissions Lab
# ============================================================
# Teaches owner / group / others, read / write / execute, symbolic and numeric
# modes, directory permissions, umask, ls -l, stat and chown. Every REAL change
# is made to a practice file INSIDE ./sandbox, so nothing on the real system is
# touched. chown is explained but never executed, because changing the owner of
# a file normally needs root.
#
# This file is SOURCED by unishell.sh, which then calls module_permissions.
# ============================================================

PERM_FILE_NAME="perm_demo.txt"
PERM_DIR_NAME="perm_dir"
PERM_FILE="$UNISHELL_SANDBOX/$PERM_FILE_NAME"
PERM_DIR="$UNISHELL_SANDBOX/$PERM_DIR_NAME"

# ------------------------------------------------------------
# Small helpers
# ------------------------------------------------------------

# perm_make_demo - (re)create the practice file at a known starting mode.
perm_make_demo() {
  # COMMAND: mkdir -p | PURPOSE: create the practice directory inside ./sandbox | MODULE: Permissions
  mkdir -p -- "$PERM_DIR" 2>/dev/null || return 1
  # COMMAND: touch | PURPOSE: create the practice file so chmod has a target | MODULE: Permissions
  touch -- "$PERM_FILE" 2>/dev/null || return 1
  # COMMAND: > | PURPOSE: give the file a little content to demonstrate reading | MODULE: Text Processing
  printf 'owner group others\n' > "$PERM_FILE"
  # COMMAND: chmod | PURPOSE: start from one known mode so the demo repeats cleanly | MODULE: Permissions
  chmod 644 -- "$PERM_FILE" 2>/dev/null || return 1
  return 0
}

# perm_line <path> - show the long listing and the modes of one file.
perm_line() {
  local path="$1"
  # COMMAND: ls -l | PURPOSE: show permissions, links, owner, size and date | MODULE: Permissions
  ls -l -- "$path"
  # COMMAND: stat -c | PURPOSE: print the numeric mode, symbolic mode, owner and group | MODULE: Permissions
  stat -c '  numeric mode = %a    symbolic = %A    owner = %U    group = %G' -- "$path"
}

perm_reset() {
  if ! perm_make_demo; then
    msg_err "Could not create the practice file inside $UNISHELL_SANDBOX"
    log_activity "permissions" "practice file could not be created" "error"
    return 1
  fi
  return 0
}

# ------------------------------------------------------------
# Sub-menu
# ------------------------------------------------------------
module_permissions() {
  local choice

  # COMMAND: mkdir -p | PURPOSE: make sure ./sandbox exists before anything is written | MODULE: Unix Basics
  mkdir -p "$UNISHELL_SANDBOX" 2>/dev/null

  while :; do
    section_title "Module 3 - File Permissions Lab"
    printf '  %s\n' "  Practice file: $PERM_FILE_NAME   (inside ./sandbox)"
    printf '\n'
    printf '  %s\n' "1. How to read permissions (ls -l, stat)"
    printf '  %s\n' "2. Symbolic chmod (u+x, g-w, o=r)"
    printf '  %s\n' "3. Numeric chmod (644, 755, 600)"
    printf '  %s\n' "4. Directory permissions and umask"
    printf '  %s\n' "5. chown - explained, never run"
    printf '  %s\n' "0. Back to the main menu"
    printf '\n'

    if ! ask_choice "Choose an option (0-5): " 0 5; then
      return 0
    fi
    choice="$UNISHELL_CHOICE"

    case "$choice" in
      1) perm_demo_read ;;
      2) perm_demo_symbolic ;;
      3) perm_demo_numeric ;;
      4) perm_demo_umask ;;
      5) perm_demo_chown ;;
      0) return 0 ;;
    esac
  done
}

# ------------------------------------------------------------
# 1. Reading permissions
# ------------------------------------------------------------
perm_demo_read() {
  section_title "How to read permissions"

  perm_reset || { press_enter_to_continue; return 0; }

  printf 'The practice file is  %s\n\n' "$PERM_FILE_NAME"
  perm_line "$PERM_FILE"

  printf '\n'
  msg_info "ls -l prints ten characters first, for example -rw-r--r--"
  msg_info "  character 1     : the type  (- file, d directory, l symbolic link)"
  msg_info "  characters 2-4  : the OWNER's  read, write, execute"
  msg_info "  characters 5-7  : the GROUP's  read, write, execute"
  msg_info "  characters 8-10 : OTHERS'     read, write, execute"
  printf '\n'
  msg_info "A dash means that right is refused, a letter means it is allowed."
  msg_info "Reading a file uses r, writing uses w, running a program uses x."
  msg_info "For a directory, x means 'may enter it', r means 'may list it'."
  printf '\n'
  msg_info "stat shows the same rights as a number: 644 = rw- r-- r--"
  log_activity "permissions" "demo: read permissions" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 2. Symbolic chmod
# ------------------------------------------------------------
perm_demo_symbolic() {
  section_title "Symbolic chmod: who, then what"

  perm_reset || { press_enter_to_continue; return 0; }

  printf 'Starting point:\n'
  perm_line "$PERM_FILE"

  printf '\n1. Add execute for the OWNER only (chmod u+x):\n'
  # COMMAND: chmod u+x | PURPOSE: add execute for the owner only | MODULE: Permissions
  chmod u+x -- "$PERM_FILE" 2>/dev/null && perm_line "$PERM_FILE"

  printf '\n2. Take write away from the GROUP (chmod g-w):\n'
  # COMMAND: chmod g-w | PURPOSE: remove write from the group | MODULE: Permissions
  chmod g-w -- "$PERM_FILE" 2>/dev/null && perm_line "$PERM_FILE"

  printf '\n3. Give OTHERS read and nothing else (chmod o=r):\n'
  # COMMAND: chmod o=r | PURPOSE: set others to read only, exactly | MODULE: Permissions
  chmod o=r -- "$PERM_FILE" 2>/dev/null && perm_line "$PERM_FILE"

  printf '\n'
  msg_info "The letters are u (user/owner), g (group), o (others), a (all)."
  msg_info "The operators are + (add), - (remove) and = (set exactly)."
  msg_info "So 'o=r' removes whatever others had before and leaves only read."
  log_activity "permissions" "demo: symbolic chmod" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 3. Numeric chmod
# ------------------------------------------------------------
perm_demo_numeric() {
  section_title "Numeric chmod: one digit per group"

  perm_reset || { press_enter_to_continue; return 0; }

  printf 'Each right has a value:  read = 4, write = 2, execute = 1\n'
  printf 'Add them for each group (owner, group, others), for example:\n'
  printf '  6 = 4+2 = read + write      4 = read only      7 = 4+2+1 = everything\n\n'

  printf 'chmod 600  -> only the owner may read and write:\n'
  # COMMAND: chmod 600 | PURPOSE: owner read+write, group and others nothing | MODULE: Permissions
  chmod 600 -- "$PERM_FILE" 2>/dev/null && perm_line "$PERM_FILE"

  printf '\nchmod 755  -> owner everything, group and others read+execute:\n'
  # COMMAND: chmod 755 | PURPOSE: owner rwx, group rx, others rx | MODULE: Permissions
  chmod 755 -- "$PERM_FILE" 2>/dev/null && perm_line "$PERM_FILE"

  printf '\nchmod 644  -> owner read+write, everyone else read only (a normal file):\n'
  # COMMAND: chmod 644 | PURPOSE: owner rw, group r, others r | MODULE: Permissions
  chmod 644 -- "$PERM_FILE" 2>/dev/null && perm_line "$PERM_FILE"

  printf '\n'
  msg_info "The demo leaves the file at 644, its starting mode."
  log_activity "permissions" "demo: numeric chmod" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 4. Directory permissions and umask
# ------------------------------------------------------------
perm_demo_umask() {
  local umask_file="$UNISHELL_SANDBOX/umask_file.txt"
  local umask_dir="$UNISHELL_SANDBOX/umask_dir"

  section_title "Directory permissions and umask"

  # Start clean so the numbers below are always the same.
  # COMMAND: rm -f | PURPOSE: remove the old practice file inside ./sandbox | MODULE: Permissions
  rm -f -- "$umask_file" 2>/dev/null
  # COMMAND: rmdir | PURPOSE: remove the old practice directory when it is empty | MODULE: Permissions
  rmdir -- "$umask_dir" 2>/dev/null

  # COMMAND: umask | PURPOSE: print the current default permission mask | MODULE: Permissions
  printf 'The current umask is: %s\n\n' "$(umask)"

  # COMMAND: touch | PURPOSE: create a file using the current umask | MODULE: Permissions
  touch -- "$umask_file" 2>/dev/null
  # COMMAND: stat -c | PURPOSE: show the mode the default umask produced | MODULE: Permissions
  printf 'with the default umask, a new FILE gets mode %s\n' "$(stat -c '%a' -- "$umask_file" 2>/dev/null)"

  printf '\nThe same creation, but after "umask 077" (inside a subshell,\n'
  printf 'so the UniShell umask is not changed):\n'
  (
    # COMMAND: umask 077 | PURPOSE: set a strict mask, only inside this subshell | MODULE: Permissions
    umask 077
    # The file already exists, and touch does not change the mode of an
    # existing file, so remove it first and let it be created fresh.
    # COMMAND: rm -f | PURPOSE: remove the file so the next touch creates it again | MODULE: Permissions
    rm -f -- "$umask_file" 2>/dev/null
    touch -- "$umask_file" 2>/dev/null
    printf '  umask 077 -> new FILE mode %s\n' "$(stat -c '%a' -- "$umask_file" 2>/dev/null)"
    # COMMAND: mkdir -p | PURPOSE: create a directory with the new umask | MODULE: Permissions
    rmdir -- "$umask_dir" 2>/dev/null
    mkdir -p -- "$umask_dir" 2>/dev/null
    printf '  umask 077 -> new DIR  mode %s\n' "$(stat -c '%a' -- "$umask_dir" 2>/dev/null)"
  )

  printf '\n'
  msg_info "umask is SUBTRACTED from the maximum rights a file could have."
  msg_info "Files start from 666 and directories from 777, then the mask is removed."
  msg_info "umask 022 gives files 644 and directories 755; umask 077 gives 600 and 700."
  printf '\n'
  msg_info "A directory also needs the x right: without it you cannot enter the"
  msg_info "directory, even if you can read its name."

  # COMMAND: rm -f | PURPOSE: clean up the umask practice file inside ./sandbox | MODULE: Permissions
  rm -f -- "$umask_file" 2>/dev/null
  # COMMAND: rmdir | PURPOSE: clean up the umask practice directory when it is empty | MODULE: Permissions
  rmdir -- "$umask_dir" 2>/dev/null

  log_activity "permissions" "demo: directory permissions and umask" "OK"
  press_enter_to_continue
}

# ------------------------------------------------------------
# 5. chown - explained, never executed
# ------------------------------------------------------------
perm_demo_chown() {
  section_title "chown - explained, never run"

  # COMMAND: (nothing is executed here) | PURPOSE: teach a privileged command without running it | MODULE: Permissions
  printf '  %s\n' "chown changes the OWNER and/or the GROUP of a file:"
  printf '  %s\n' "    chown user file            give the file to another user"
  printf '  %s\n' "    chown user:group file      change owner and group together"
  printf '  %s\n' "    chown :group file          change only the group"
  printf '\n'
  printf '  %s\n' "Reading the numbers:"
  printf '  %s\n' "    uid = the numeric owner id, gid = the numeric group id"
  printf '  %s\n' "    stat -c %U:%G FILE   prints the owner and group by NAME"
  printf '\n'
  printf '  %s\n' "Why UniShell does not run it:"
  printf '  %s\n' "    Giving a file to another user needs root (the superuser)."
  printf '  %s\n' "    Changing only the group is allowed for a member of that group,"
  printf '  %s\n' "    but it still changes real system state, so UniShell only shows"
  printf '  %s\n' "    the command and never asks for a password."
  printf '\n'
  printf '  %s\n' "The same is true of passwd and su, which are explained in Module 1."

  log_activity "permissions" "explained chown (not executed)" "OK"
  press_enter_to_continue
}
