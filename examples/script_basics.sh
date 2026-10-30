#!/usr/bin/env bash
# ============================================================
# UniShell - examples/script_basics.sh   (Phase 6: Shell Programming)
# COMMAND: bash examples/script_basics.sh | PURPOSE: show variables, environment variables, readonly and read inside a real script | MODULE: Shell Programming
#
# This script only prints. It never writes a file and never changes anything.
# Run it from the project folder:
#     bash examples/script_basics.sh
# It reads one line from standard input, to demonstrate the read builtin.
# ============================================================

# A plain shell variable: only this script knows about it.
COURSE="Unix Programming"

# export copies a variable into the ENVIRONMENT, so child programs inherit it.
export LAB="UniShell"

echo "COURSE (shell variable)       = $COURSE"
echo "LAB    (environment variable) = $LAB"

# A child program receives the environment, but NOT plain shell variables.
echo "a child sees LAB    as: $(bash -c 'printf "%s" "$LAB"')"
echo "a child sees COURSE as: [$(bash -c 'printf "%s" "$COURSE"')]"

# Some environment variables are set for you when you log in.
echo "HOME = $HOME"
echo "PATH has $(printf '%s' "$PATH" | tr ':' '\n' | wc -l) entries"

# Positional parameters: $# counts the arguments and $1 is the first one.
echo "this script was given $# argument(s)"
if [ "$#" -gt 0 ]; then
  echo "the first argument is: $1"
fi

# readonly protects a value from being changed later on.
readonly LIMIT=10
echo "LIMIT = $LIMIT (marked readonly, so a later change would be refused)"

# read takes one whole line from standard input into a variable.
printf 'Type a word: '
if read -r who; then
  echo "read stored the line in the variable who"
else
  echo "read found no input, so a default is used"
  who="(nothing read)"
fi
echo "the value of who is now: $who"

echo "script finished"
