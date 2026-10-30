# UniShell — Interactive Unix Programming Learning and Demonstration System

A menu-driven terminal application written in Bash and C that teaches Unix
programming by running **real** commands and **real** system calls.

> **Status: Phase 7 of 11 — modules 1 to 6 and 8 are implemented and tested.**
> The scaffold, `Makefile` and test harness exist and have been run and
> verified, and the menu drives the ten-module application. Modules **1 (Unix
> Command Library)**, **2 (File and Directory Management)**, **3 (File
> Permissions Lab)**, **4 (Text Processing, Pipes and Redirection)**, **5
> (Shell Programming Lab)**, **6 (Process Management Lab)** and **8 (C System
> Calls Demonstrations)** are working: they run real commands and real C
> programs, keep every destructive action inside `./sandbox`, and are covered
> by automated tests. Module **7 (Inter-Process Communication)** and modules
> **9 (Quiz and Practical Exercises)** and **10 (Activity Logs)** still answer
> "not implemented yet" and name their scheduled phase. Nothing in this
> document claims a feature works before it has been built and tested.

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
| 7 | Inter-Process Communication Lab | planned (Phase 8) |
| 8 | C System Calls Demonstrations | **done and tested** (Phase 7) |
| 9 | Quiz and Practical Exercises | planned (Phase 9) |
| 10 | Activity Logs | planned (Phase 9) |

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
  data/                command_library.txt, sample.log
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
Modules 1 to 6 and 8 open their own sub-menu; module 7 and modules 9 to 10
still answer "not implemented yet" until their phase is built.

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

Modules 7 and 9 to 10 are described here as each one is completed and tested.

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

Current state: nine test scripts, run in order by `make test`:

| Script | Checks | Result |
|---|---|---|
| `tests/test_00_scaffold.sh` | folders, write access, toolchain, LF line endings | 38 passed, 0 failed |
| `tests/test_01_common.sh` | `lib/common.sh`: name safety, sandbox containment, logging, input validation | 40 passed, 0 failed |
| `tests/test_02_menu.sh` | menu navigation, invalid input, exit codes, injection safety, logging | 46 passed, 0 failed |
| `tests/test_03_commands.sh` | module 1: all 28 commands documented, seven fields each, typed text never executed | 22 passed, 0 failed |
| `tests/test_04_files.sh` | module 2: create/copy/remove/reset, and removal cannot escape `./sandbox` | 25 passed, 0 failed |
| `tests/test_05_permissions.sh` | module 3: `chmod` numeric and symbolic, `umask` on new files, `chown` never run | 19 passed, 0 failed |
| `tests/test_06_text.sh` | module 4: `grep`/`egrep` counts, pipes, redirection, `tee`, `diff`, regex, quoting | 28 passed, 0 failed |
| `tests/test_07_shell.sh` | module 5: the example scripts really run, every scripting demo works, `~/.profile` is never executed or changed | 71 passed, 0 failed |
| `tests/test_08_c.sh` | modules 6 and 8: every C program compiles without warnings, runs, returns 0, prints what it claims, and leaves nothing outside `./sandbox` | 67 passed, 0 failed |

`make test` ends with `=== RESULT: ALL TESTS PASSED ===` (356 checks).

Extra manual safety verification (run outside the test suite): `bash -n` on
every shell script, no `eval` anywhere in `unishell.sh`, `lib/`, `modules/` or
`examples/`, no `kill()` in any `c_programs/*.c`, and a check that payloads
typed at the main prompt or into a module cannot create a file, delete
`Makefile`/`/etc/passwd`, or leave anything outside `./sandbox`.

## 11. Limitations

- Not a general-purpose shell: it runs a fixed set of demonstrations, not arbitrary commands.
- Optional syllabus topics listed in section 3 are not implemented.
- Demos are designed for a single local user.
- Modules 7 and 9 to 10 (inter-process communication, quiz, activity-log
  viewer) are not implemented yet; each one says so and names its phase.
- `chmod`/`umask` are demonstrated on one practice file and directory inside
  `./sandbox`; results depend on the filesystem supporting Unix permissions
  (true on the Linux filesystem, ignored on a Windows drive such as `/mnt/c`).

## 12. Future Enhancements

- Optional modules (message queues, semaphores, shared memory, client-server).
- Progress tracking across quiz attempts.
- Exportable session report for submission.
