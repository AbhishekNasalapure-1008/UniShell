# UniShell — Interactive Unix Programming Learning and Demonstration System

A menu-driven terminal application written in Bash and C that teaches Unix
programming by running **real** commands and **real** system calls.

> **Status: Phase 9 of 11 — all ten modules are implemented and tested.**
> The scaffold, `Makefile` and test harness exist and have been run and
> verified, and the menu drives the ten-module application. Every module from
> **1 (Unix Command Library)** to **10 (Activity Logs)** is working: they run
> real commands and real C programs, keep every destructive action inside
> `./sandbox`, write every log line into `./logs`, and are covered by
> automated tests. Nothing in this document claims a feature works before it
> has been built and tested.

---

## 1. Problem Statement

Students memorise Unix commands without understanding their purpose, syntax,
output, or how a shell command relates to the C system calls underneath it.
A typed command such as `grep` hides both its own logic and the file
descriptors, processes and pipes that make it work.

UniShell addresses this by combining command explanations, safe hands-on
demos, exercises and C experiments in one structured terminal application.
Every feature answers: what is it, why is it used, where is it used in
practice, what is the syntax, what does the example do, what output should the
student expect, and which syllabus module does it belong to.

## 2. Objectives

1. Explain each syllabus command with purpose, syntax, example and expected output.
2. Demonstrate the same ideas through C system calls (`fork`, `exec`, `pipe`, `open`, ...).
3. Let students practise safely — every destructive demo runs inside `./sandbox`.
4. Map every feature to its syllabus module, marking anything that goes beyond the four, so the instructor can trace coverage.
5. Keep every file short and commented so the student can explain it line by line in a viva.

## 3. Features

| # | Module | Status |
|---|---|---|
| 1 | Unix Command Library | **done and tested** (Phase 4) |
| 2 | File and Directory Management | **done and tested** (Phase 4) |
| 3 | File Permissions Lab | **done and tested** (Phase 5) |
| 4 | Text Processing, Pipes, Redirection | **done and tested** (Phase 5) |
| 5 | Shell Programming Lab | **done and tested** (Phase 6) |
| 6 | Process Management Lab (C) | **done and tested** (Phase 7) |
| 7 | Inter-Process Communication Lab | **done and tested** (Phase 8) |
| 8 | C System Calls Demonstrations | **done and tested** (Phase 7) |
| 9 | Quiz and Practical Exercises | **done and tested** (Phase 9) |
| 10 | Activity Logs | **done and tested** (Phase 9) |

Optional topics (message queues, semaphores, shared memory, client-server,
`popen`, `fcntl`, `setjmp`, `getrlimit`) are intentionally **out of scope**.

## 4. Architecture

```
UniShell/
  unishell.sh          entry point: banner, menu loop, numeric dispatcher (no eval)
  lib/                 shared helpers: colours, validation, sandbox guard, logging
  modules/             one script per menu module
  c_programs/          one .c file per C demonstration
  examples/            runnable shell scripts and a sample .profile
  data/                command_library.txt, sample.log, quiz_questions.txt,
                       practice_exercises.txt
  sandbox/             the only place destructive demos may write
  logs/                activity.log (timestamped, appended safely)
  tests/               test_*.sh, run by "make test"
  docs/                COMMAND_MAP.md, SYLLABUS_MAPPING.md
  bin/                 compiled executables only (generated, git-ignored)
```

Design rules: no `eval`, no user string ever reaches a shell; menu choices are
mapped by `case` to fixed functions; all input is validated; writes are
confined to `sandbox/` and `logs/`.

## 5. Prerequisites

- Linux (or WSL2 Ubuntu) with Bash 4 or newer
- GCC and GNU Make (`sudo apt-get install build-essential`)
- No root privileges required to build or run UniShell

## 6. How to Build

```bash
cd ~/UniShell
make all      # compiles c_programs/*.c into bin/
```

## 7. How to Run

```bash
cd ~/UniShell
./unishell.sh
```

Type a number from `0` to `10` and press Enter. The banner, menu and sandbox
path are printed; an invalid answer is refused and re-asked; `0` leaves cleanly.
Every module from 1 to 10 opens its own sub-menu.

Every session appends one line per action to `logs/activity.log` in the fixed
form `timestamp | module | action | status`. No text typed by the user is
written to the log.

## 8. Module Descriptions

**Module 1 — Unix Command Library.** A sub-menu that either lists all 28
documented commands or explains one by name. Explanations are read from
`data/command_library.txt` with `awk`; nothing typed is ever executed. Each
entry has seven fixed fields: syllabus module, purpose, syntax, example,
expected output, practical uses and notes. Sub-menu option 4 explains `passwd`
and `su` **without running them**, and option 3 runs seven small live demos
(`echo`/`printf`, `date`/`cal`, `who`/`pwd`, `type`, `ls`, `read`/`test`/
`readonly`, and `set`/`shift`/`trap`).

**Module 2 — File and Directory Management.** Creates a small practice tree
inside `./sandbox`, then demonstrates `pwd`, `cd`, `ls`, `mkdir`, `cp`, `mv`,
`cat`, `wc` and removal. Every name typed is checked with `is_safe_name`
(one plain name: no `/`, no space, no leading `-`) and again with
`check_inside_sandbox` before anything is deleted. `sandbox/.gitkeep` is never
removed, and a reset uses `find -mindepth 1 ! -name '.gitkeep'` so the sandbox
itself survives.

**Module 3 — File Permissions Lab.** Works on one practice file
(`sandbox/perm_demo.txt`) and one practice directory. Shows `ls -l` and
`stat -c '%a %A %U %G'` side by side, demonstrates symbolic changes (`u+x`,
`g-w`, `o=r`) and numeric modes (`600`, `755`, `644`), and shows what `umask`
does to a **newly created** file and directory — inside a subshell, so the
running UniShell's umask is untouched. `chown` is explained only and never run.

**Module 4 — Text Processing, Pipes and Redirection.** Reads
`data/sample.log` (32 lines: `YYYY-MM-DD HH:MM:SS LEVEL SERVICE USER MESSAGE`).
Demonstrates standard input, output and error; `>`, `>>`, `<` and `2>`;
pipelines; `grep`, `egrep`, `wc`, `sort`, `uniq`, `cut`, `tr`, `head`, `tail`,
`tee` and `diff`; regular expressions; and quoting versus wildcard expansion.
Every file it writes goes into `./sandbox`.

**Module 5 — Shell Programming Lab.** A ten-option sub-menu that teaches how a
script is written: variables and `export`, `read`, `readonly` and positional
parameters, exit status with `&&` and `||`, `test`/`[ ]` and `if`/`elif`/`else`,
`for` and `while` loops, `case`, `set`, `shift` and here-documents, and `trap`.
Every short demo runs inside a subshell, so nothing it does can change the
running UniShell. Option 9 runs the three real scripts in `examples/`
(`script_basics.sh`, `script_control.sh`, `script_advanced.sh`) with `bash`, and
option 10 displays `examples/profile.sample` as text — a real `~/.profile` is
never read, executed or changed.

**Module 6 — Process Management Lab.** Explains what a process is (pid and
parent pid, shown with `ps`), then runs the compiled C demonstrations in `bin/`:
`process_fork` (`fork()` and a child that `exit(7)`s), `exec_demo` (the `exec`
family replacing the running program), and `wait_demo` (`wait`/`waitpid`,
reading a real zombie `Z` state from `/proc`, and an orphan adopted by another
process). A missing program is built first with `make all`. No process that
UniShell did not start itself is ever touched, and none of the C sources calls
`kill()`.

**Module 8 — C System Calls Demonstrations.** Explains what a system call is,
then runs `bin/file_io`, which calls `getcwd`, `creat`, `write`, `close`,
`open`, `read`, `mkdir`, `rmdir`, `chdir` and `unlink` and prints the value each
one returned. The program is only ever given a working directory inside
`./sandbox` (checked with `check_inside_sandbox` first), turns its argument into
a full path before `chdir`, and removes everything it creates before it exits.
The sub-menu also explains the file and directory calls and can display any of
the four C sources for reading.

**Module 7 — Inter-Process Communication Lab.** Explains why two processes
cannot read each other's memory and must ask the kernel to carry data or a
short notice between them, then runs the compiled demonstrations in `bin/`:
`pipe_demo` (an unnamed `pipe()` between a parent and a child it forked),
`fifo_receiver` and `fifo_sender` (a named pipe made with `mkfifo()`, opened
with a `poll()` deadline), and `signal_demo`, `signal_receiver` and
`signal_sender` (handlers installed with `sigaction()`, `raise()`, `alarm()`,
`pause()` and `SIG_IGN`). Every wait has a deadline, so a missing partner can
never hang a demonstration: the FIFO receiver and the signal receiver both
stop by themselves with exit status 3 when nothing arrives. The FIFO is created
inside `./sandbox` after `check_inside_sandbox`, and `signal_sender` accepts
only `USR1`, `USR2` and `TERM` and refuses pid 0, pid 1 and its own pid, so the
only process ever signalled is the receiver UniShell started itself. The
sub-menu can also display any of the six C sources.

**Module 9 — Quiz and Practical Exercises.** An interactive multiple-choice
quiz read from `data/quiz_questions.txt` and a set of practice exercises read
from `data/practice_exercises.txt`. Each question has a topic, four options,
one stored answer, a hint and an explanation; an answer is a single letter
compared with `A`, `B`, `C` or `D`, and typing `h` shows the hint and `q` stops
and reports the score. Nothing typed is echoed back or executed. The exercises
show a task, offer a hint and then the worked solution for the student to read
— UniShell never runs it. The session score is kept in memory and every attempt
is recorded in the activity log with `exit=0` for a perfect run and `exit=1`
otherwise.

**Module 10 — Activity Logs.** A read-only viewer for the single log file
`logs/activity.log` that every other module writes to. Each line has exactly
four fields — `timestamp | module | action | status` — the timestamp is written
with `date '+%Y-%m-%d %H:%M:%S'`, and no text typed by the user is ever stored.
The sub-menu explains the fields, then shows the whole log with `cat`, the most
recent entries with `tail -n`, the entries for one module (chosen by number from
a fixed list, so no typed text is used as a search pattern), a count per module,
and the entries whose status shows a problem (`error`, `refused`, or an
`exit=N` where N is not 0). The module only reads the file; when it records
that the log was viewed it uses the same shared logger, so even that line obeys
the one-file rule.

## 9. Examples

Real captured output from this project:

```console
$ grep -c ERROR data/sample.log
7
$ grep -c -e ERROR -e WARN data/sample.log
14
$ wc -l data/sample.log
32 data/sample.log
```

```console
$ printf '\n' | bash -c 'source ./lib/common.sh; source ./modules/permissions.sh; perm_make_demo; perm_demo_numeric'
numeric mode = 644    symbolic = -rw-r--r--    owner = ...    group = ...
numeric mode = 600    symbolic = -rw-------    owner = ...    group = ...
numeric mode = 755    symbolic = -rwxr-xr-x    owner = ...    group = ...
```

```console
$ bash examples/script_control.sh
test : 7 is greater than 5
[ ]  : 7 is greater than 5
both conditions are true: 7 is between 5 and 10
if/elif: 7 is medium (5 to 10)
for:
  apple
  banana
  cherry
while:
  i = 1
  i = 2
  i = 3
case:
  start -> starting
  unknown -> not understood
script finished
```

```console
$ ./bin/process_fork
parent: I am about to call fork().
child : fork() returned 0, so I am the child.
parent: fork() returned 3497, which is my child's pid.
parent: child ended normally with exit status 7.
parent: because I waited, the child was reaped.
```

The full expected output for every feature is listed in
`docs/COMMAND_MAP.md`.

## 10. Testing

```bash
make test     # runs every tests/test_*.sh and reports pass/fail
make clean    # removes generated files only (bin/*, *.o, *.tmp)
```

Current state: eleven test scripts, run in order by `make test`:

| Script | Checks | Result |
|---|---|---|
| `tests/test_00_scaffold.sh` | folders, write access, toolchain, LF line endings | 43 passed, 0 failed |
| `tests/test_01_common.sh` | `lib/common.sh`: name safety, sandbox containment, logging, input validation | 40 passed, 0 failed |
| `tests/test_02_menu.sh` | menu navigation, invalid input, exit codes, injection safety, logging | 48 passed, 0 failed |
| `tests/test_03_commands.sh` | module 1: all 28 commands documented, seven fields each, typed text never executed | 22 passed, 0 failed |
| `tests/test_04_files.sh` | module 2: create/copy/remove/reset, and removal cannot escape `./sandbox` | 25 passed, 0 failed |
| `tests/test_05_permissions.sh` | module 3: `chmod` numeric and symbolic, `umask` on new files, `chown` never run | 19 passed, 0 failed |
| `tests/test_06_text.sh` | module 4: `grep`/`egrep` counts, pipes, redirection, `tee`, `diff`, regex, quoting | 28 passed, 0 failed |
| `tests/test_07_shell.sh` | module 5: the example scripts really run, every scripting demo works, `~/.profile` is never executed or changed | 71 passed, 0 failed |
| `tests/test_08_c.sh` | modules 6 and 8: every C program compiles without warnings, runs, returns 0, prints what it claims, and leaves nothing outside `./sandbox` | 67 passed, 0 failed |
| `tests/test_09_ipc.sh` | module 7: pipes, FIFO and signals run and end without hanging, the receiver stops by itself when no partner appears, and the sender only ever signals a process UniShell started | 106 passed, 0 failed |
| `tests/test_10_learning.sh` | modules 9 and 10: the question and exercise files load, the quiz scores a perfect run, a wrong answer is marked wrong, the log gets four fields per line, and every log file stays under `./logs` | 104 passed, 0 failed |

`make test` ends with `=== RESULT: ALL TESTS PASSED ===` (573 checks).

Extra manual safety verification (run outside the test suite): `bash -n` on
every shell script, no `eval` anywhere in `unishell.sh`, `lib/`, `modules/` or
`examples/`, and a check that payloads typed at the main prompt or into a
module cannot create a file, delete `Makefile`/`/etc/passwd`, or leave anything
outside `./sandbox`. The only C program that calls `kill()` is
`c_programs/signal_sender.c`; it refuses `SIGKILL` and `SIGSTOP`, refuses pid 0,
pid 1 and its own pid, and UniShell only ever passes it the pid of the receiver
it started itself a moment earlier.

## 11. Limitations

- Not a general-purpose shell: it runs a fixed set of demonstrations, not arbitrary commands.
- Optional syllabus topics listed in section 3 are not implemented.
- Demos are designed for a single local user.
- The IPC demonstrations are Linux/POSIX demonstrations: the FIFO is created inside `./sandbox`, and the only process ever signalled is the receiver UniShell started itself.
- The quiz score is kept only while UniShell is running; it is not saved to a file between sessions.
- `chmod`/`umask` are demonstrated on one practice file and directory inside
  `./sandbox`; results depend on the filesystem supporting Unix permissions
  (true on the Linux filesystem, ignored on a Windows drive such as `/mnt/c`).

## 12. Future Enhancements

- Optional modules (message queues, semaphores, shared memory, client-server).
- Persistent progress tracking across sessions (the quiz score is in memory only).
- Exportable session report for submission.
