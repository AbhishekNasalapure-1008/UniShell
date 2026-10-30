#!/usr/bin/env bash
# ============================================================
# UniShell - examples/script_advanced.sh   (Phase 6: Shell Programming)
# COMMAND: bash examples/script_advanced.sh one two three | PURPOSE: show set, shift, positional parameters, a here-document and trap in a real script | MODULE: Shell Programming
#
# This script only prints. It never writes a file and never changes anything.
# Run it from the project folder:
#     bash examples/script_advanced.sh one two three
# ============================================================

# set -u makes reading a variable that was never set an error. That turns a
# mistyped name into a clear message instead of a silently empty value.
set -u

# trap runs a command when the script finishes. EXIT fires however the script
# ends, which is why traps are used for cleanup.
trap 'echo "trap  : the EXIT trap ran, so cleanup always happens"' EXIT

# Positional parameters: $# is the count, $* is all of them.
echo "arguments: $# of them ($*)"

# shift drops $1 and moves the rest down, one at a time, until none are left.
while [ "$#" -gt 0 ]; do
  echo "  argument: $1"
  shift
done
echo "after the loop, \$# = $#"

# A here-document (<<) feeds the lines that follow to a command's input.
# Because the marker is quoted ('DOC'), the shell does NOT expand variables.
cat <<'DOC'
heredoc: this text came from a here-document.
heredoc: $HOME stays literal because the marker was quoted.
DOC

# With an unquoted marker the shell expands variables first.
cat <<DOC2
heredoc: with an unquoted marker, HOME is expanded to $HOME
DOC2

echo "script finished"
