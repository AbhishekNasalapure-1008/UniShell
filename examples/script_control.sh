#!/usr/bin/env bash
# ============================================================
# UniShell - examples/script_control.sh   (Phase 6: Shell Programming)
# COMMAND: bash examples/script_control.sh | PURPOSE: show test, [ ], if/elif/else, for, while and case inside a real script | MODULE: Shell Programming
#
# This script only prints. It never writes a file and never changes anything.
# Run it from the project folder:
#     bash examples/script_control.sh
# ============================================================

value=7

# test and [ ] are two names for the same builtin. The [ form needs a final ].
if test "$value" -gt 5; then
  echo "test : $value is greater than 5"
fi
if [ "$value" -gt 5 ]; then
  echo "[ ]  : $value is greater than 5"
fi

# String tests: -z is true for an empty string, -n for a non-empty one.
if [ -z "" ]; then
  echo "test -z: an empty string has zero length"
fi
if [ -n "abc" ]; then
  echo "test -n: the string abc is not empty"
fi

# && joins two conditions that must both be true.
if [ "$value" -ge 5 ] && [ "$value" -le 10 ]; then
  echo "both conditions are true: $value is between 5 and 10"
fi

# if / elif / else chooses exactly one branch.
if [ "$value" -gt 10 ]; then
  echo "if/elif: big"
elif [ "$value" -ge 5 ]; then
  echo "if/elif: $value is medium (5 to 10)"
else
  echo "if/elif: small"
fi

# for repeats over a fixed list.
echo "for:"
for fruit in apple banana cherry; do
  echo "  $fruit"
done

# while repeats as long as its condition stays true.
echo "while:"
i=1
while [ "$i" -le 3 ]; do
  echo "  i = $i"
  i=$((i + 1))
done

# case compares one value with several patterns and runs the first match.
echo "case:"
for answer in start stop reload unknown; do
  case "$answer" in
    start|begin) echo "  $answer -> starting" ;;
    stop|end)    echo "  $answer -> stopping" ;;
    reload)      echo "  $answer -> reloading" ;;
    *)           echo "  $answer -> not understood" ;;
  esac
done

echo "script finished"
