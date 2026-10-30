# UniShell — Syllabus Mapping

This document shows how every UniShell feature maps onto the four Unix
Programming syllabus modules. It is the trace an instructor can follow to see
that each syllabus topic is covered by a real, tested demonstration.

**Syllabus modules used in UniShell**

| # | Syllabus module | What it covers |
|---|---|---|
| 1 | Unix Basics | Files, directories, simple commands, the file system, paths and the shell environment |
| 2 | Shell Programming | Shell builtins, variables, positional parameters, conditions and scripts |
| 3 | File System and Permissions | Ownership, permission bits, `chmod`, `umask`, metadata |
| 4 | Text Processing | Filters, pipes, redirection, regular expressions and field extraction |

`data/command_library.txt` tags every entry with one of these modules in a
`SYLLABUS :` line, and `tests/test_03_commands.sh` checks that all of them are
present.

---

## Module 1 — Unix Basics

| Command | Where in UniShell | How it is demonstrated |
|---|---|---|
| `echo` | `modules/commands.sh` → `cmdlib_demo_echo`; library entry | Prints text, `-n` suppresses the newline |
| `printf` | `cmdlib_demo_echo`; `lib/common.sh` everywhere | Formats a padded table; used for all program output |
| `ls` | `cmdlib_demo_ls`, `modules/files.sh` → `files_demo_list` | Plain, `-a`, `-l` and `-R` listings of `./sandbox` |
| `who` | `cmdlib_demo_ident` | Lists login sessions; reports honestly when WSL has none |
| `date` | `cmdlib_demo_date`; `lib/common.sh` → `log_activity` | Shows the date and a `+%Y-%m-%d %H:%M:%S` timestamp |
| `cal` | `cmdlib_demo_date` | Prints the current month's calendar |
| `pwd` | `cmdlib_demo_ident`, `files_demo_paths` | Shows the absolute current directory |
| `cd` | `files_demo_paths` | Runs inside a subshell, plus a failing `cd` that returns status 1 |
| `mkdir` | `files_demo_create` (`mkdir -p`), `files_make_demo_tree` | Creates a directory tree; plain `mkdir` on an existing name shows the error |
| `rmdir` | `files_demo_remove` | Removes an empty directory only — it refuses when data is inside |
| `cat` | `files_demo_view`; text demos | Prints a file and feeds pipes |
| `mv` | `files_demo_copy_move` | Renames a copy inside `./sandbox` |
| `rm` | `files_demo_remove` | Deletes one file that has passed both sandbox checks |
| `cp` | `files_demo_copy_move` | Copies a file, keeping the original |
| `touch` | `files_make_demo_tree` | Creates the practice files |
| File system concepts | `files_demo_paths`, `cmdlib_demo_ls` | Hidden files, absolute vs relative paths, `.`, `..`, `HOME`, `PATH` |

## Module 2 — Shell Programming

| Command | Where in UniShell | How it is demonstrated |
|---|---|---|
| `type` | `cmdlib_demo_type` | Shows whether `echo`, `pwd`, `ls` are builtins or programs; `type -t` gives one word |
| `read` | `cmdlib_demo_read`; `lib/common.sh` → `ask_choice`, `ask_text`, `ask_yes_no` | Reads a line into a variable and prints its length |
| `readonly` | `cmdlib_demo_read` | Shown in a subshell, where a later assignment is refused |
| `test` | `cmdlib_demo_read` | `test -n` decides between two messages |
| `set` | `cmdlib_demo_set` | `set --` builds `$1 $2 $3` inside a subshell |
| `shift` | `cmdlib_demo_set` | Moves the positional parameters down and prints `$#` |
| `trap` | `cmdlib_demo_set`; `unishell.sh` → `on_interrupt` | An `EXIT` trap in a subshell; the real program traps `INT`/`TERM` to exit 130 |

### Full scripts and control flow (Phase 6)

Module 5 (`modules/shell_programming.sh`) completes the Shell Programming
syllabus topic by moving from single builtins to whole scripts. Every short
demo runs in a subshell, and the three real scripts in `examples/` are run with
`bash` on option 9.

| Topic | Where in UniShell | How it is demonstrated |
|---|---|---|
| Variables and `export` | `sp_demo_variables`; `examples/script_basics.sh` | A plain shell variable beside an exported one, proving a child inherits only the exported value |
| `read`, `readonly`, positional parameters | `sp_demo_read`; `examples/script_basics.sh` | A typed line stored with `read`, `readonly` refusing a change, and `$1 $2 $3` from `set --` |
| Exit status, `&&` and `\|\|` | `sp_demo_exit_status`; `examples/script_advanced.sh` | `true`/`false` statuses and the short-circuit behaviour of `&&` and `\|\|` |
| Conditions: `test`, `[ ]`, `if` | `sp_demo_test_if`; `examples/script_control.sh` | The same comparison through `test` and `[ ]`, then an `if`/`elif`/`else` chain |
| Loops: `for` and `while` | `sp_demo_loops`; `examples/script_control.sh` | A list loop, a numeric loop, and a `while` that advances its own counter |
| `case` | `sp_demo_case`; `examples/script_control.sh` | One value matched against several patterns, a group alternative and a catch-all |
| `set`, `shift`, here-documents | `sp_demo_set_shift`; `examples/script_advanced.sh` | Walking arguments with `shift`, and a quoted versus unquoted `<<` here-document |
| `trap` and cleanup | `sp_demo_trap`; `examples/script_advanced.sh` | An `EXIT` trap that fires however the subshell finishes |
| Scripts and login files | `sp_demo_run_scripts`, `sp_demo_profile` | The example scripts run for real; a sample `.profile` is displayed and never executed |

## Module 3 — File System and Permissions

| Topic | Where in UniShell | How it is demonstrated |
|---|---|---|
| owner / group / others, r/w/x | `modules/permissions.sh` → `perm_demo_read` | `ls -l` on the practice file, with each of the ten characters explained |
| Symbolic permissions | `perm_demo_symbolic` | `chmod u+x`, `chmod g-w`, `chmod o=r`, shown before and after |
| Numeric permissions | `perm_demo_numeric` | `chmod 600`, `755` and `644`, with the 4/2/1 table explained |
| Directory permissions | `perm_demo_umask` | Explains that `x` on a directory means "may enter it" |
| `umask` | `perm_demo_umask` | Compares a default file with one created under `umask 077` (600 vs 700) |
| `ls -l` | `perm_line` | Long listing of the practice file |
| `stat` | `perm_line` | `stat -c '%a %A %U %G'` prints numeric mode, symbolic mode, owner and group |
| `chmod` | every permissions demo | The only command that changes modes; always on a file inside `./sandbox` |
| `chown` | `perm_demo_chown` | **Explained only, never executed** — changing an owner needs root |
| `passwd` | `modules/commands.sh` → `cmdlib_privileged` | **Explained only, never executed** |
| `su` | `cmdlib_privileged` | **Explained only, never executed** |

## Module 4 — Text Processing

| Command | Where in UniShell | How it is demonstrated |
|---|---|---|
| `wc` | `files_demo_view`, `txt_demo_count_sort` | Counts lines, words and bytes of a file |
| `od` | `files_demo_view` | `od -c` shows each byte, including `\n` and hidden characters |
| `grep` | `txt_demo_grep`, `txt_demo_regex` | `-c`, `-n`, `-v`, anchors `^` and `$` |
| `egrep` | `txt_demo_grep`, `txt_demo_regex` | Alternatives `ERROR\|WARN`, groups, `[0-9]{2}` |
| `sort` | `txt_demo_pipes`, `txt_demo_count_sort` | Groups equal lines so `uniq` can count them |
| `uniq` | same as `sort` | `uniq -c` counts adjacent duplicates |
| `cut` | `txt_demo_pipes`, `txt_demo_columns` | `cut -d' ' -f3` and `-f5` pick one column |
| `tr` | `txt_demo_columns` | `tr 'a-z' 'A-Z'` changes case; `tr -s ' '` squeezes spaces |
| `head` | `txt_demo_head_tail_tee` | First three lines of the log |
| `tail` | `txt_demo_head_tail_tee` | Last three lines of the log |
| `tee` | `txt_demo_head_tail_tee` | Saves the ERROR lines to `sandbox/errors.txt` while counting them |
| `diff` | `txt_demo_diff` | Compares two files and explains exit status 0/1/2 |
| Pipes `\|` | `txt_demo_pipes` | `cut \| sort \| uniq -c` and `sort \| uniq -c \| sort -rn \| head` |
| Redirection `> >> < 2>` | `txt_demo_redirection` | Each operator written to a file inside `./sandbox` |
| stdin / stdout / stderr | `txt_demo_streams` | fd 0, fd 1 and fd 2 explained and shown |
| Regular expressions | `txt_demo_regex` | `^`, `$`, `.`, `*`, `+`, `[0-9]`, `{2}`, `( )`, `\|` |
| Quoting vs wildcards | `txt_demo_quoting` | `wild*.txt` expanded, then quoted and left literal; `$name` in double vs single quotes |

## Process Management and C System Calls (Phase 7)

These demonstrations go beyond the four command-library syllabus modules above.
They show the C level underneath the shell: how a program is run by the kernel
(module 6, `modules/processes.sh`) and how a program asks the kernel to touch
files and directories (module 8, `modules/system_calls.sh`). They support the
Unix Basics and Shell Programming modules by showing what really happens when
the shell starts a program or opens a file.

| Topic | Where in UniShell | How it is demonstrated |
|---|---|---|
| process, pid, parent pid | `modules/processes.sh` → `pr_demo_process` | `ps -o pid,ppid,stat,comm` on the running shell and its parent, plus a real child that reports its own pid |
| `fork()` | `pr_run_bin` → `bin/process_fork`; `c_programs/process_fork.c` | One process becomes two; the child `exit(7)`s and the parent reaps it with `wait()` |
| `exec()` family | `pr_run_bin` → `bin/exec_demo`; `c_programs/exec_demo.c` | `execlp()` and `execl()` replace a child with `echo`, then both children are reaped |
| `wait()` and `waitpid()` | `pr_run_bin` → `bin/wait_demo`; `c_programs/wait_demo.c` | Two children reaped by pid, the second's own exit status read back, and a real zombie `Z` state read from `/proc` |
| zombie and orphan | `pr_explain_zombie_orphan` | Explained in text, then shown for real by `wait_demo`, which leaves nothing behind |
| what a system call is | `modules/system_calls.sh` → `sc_explain_what` | `open`/`read`/`close`, the file descriptor, and `-1` plus `errno`/`perror()` |
| file calls | `sc_explain_file_calls`, `sc_run_file_io` → `bin/file_io`; `c_programs/file_io.c` | `creat`, `open` flags, `read`, `write` (partial writes handled) and `close`, run inside `./sandbox` |
| directory calls | `sc_explain_dir_calls` | `mkdir`, `rmdir` (empty only), `chdir` and `getcwd`, plus the relative-path trap |
| reading the source | `sc_read_source` | Any `c_programs/*.c` displayed with `cat`, never executed |

---

## Coverage summary

| Syllabus module | Commands / topics covered | Status |
|---|---|---|
| Module 1 — Unix Basics | echo, printf, ls, who, date, cal, pwd, cd, mkdir, rmdir, cat, mv, rm, cp, touch, paths, hidden files, HOME, PATH | Implemented and tested (Phase 4) |
| Module 2 — Shell Programming | type, read, readonly, test, set, shift, trap, variables and `export`, exit status with `&&`/`\|\|`, `if`/`elif`/`else`, `for`, `while`, `case`, here-documents, `trap` cleanup, whole scripts | Implemented and tested (Phases 4 and 6) |
| Module 3 — File System and Permissions | chmod, umask, stat, ls -l, ownership, chown/passwd/su (explained only) | Implemented and tested (Phase 5) |
| Module 4 — Text Processing | wc, od, grep, egrep, sort, uniq, cut, tr, head, tail, tee, diff, pipes, redirection, regex, quoting | Implemented and tested (Phase 5) |
| Beyond the four modules — Processes and C System Calls | ps, fork, exec, wait/waitpid, zombies, orphans, open, read, write, close, creat, mkdir, rmdir, chdir, getcwd | Implemented and tested (Phase 7) |

**Not yet covered (later phases):** inter-process communication (Phase 8), and
the quiz and logs viewer (Phase 9). Optional topics such as message queues,
semaphores and shared memory remain out of scope.

_Related documents: [`COMMAND_MAP.md`](COMMAND_MAP.md) lists the exact command
used by each feature; `README.md` describes how to build, run and test UniShell._
