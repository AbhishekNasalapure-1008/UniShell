#!/usr/bin/env bash
# ============================================================
# UniShell - Module 6 and Module 8 (C system calls) tests  (Phase 7)
# COMMAND: bash tests/test_08_c.sh | PURPOSE: prove every C demonstration compiles without warnings, runs, returns 0, prints what it claims, and leaves nothing behind outside ./sandbox | MODULE: C System Calls
# ============================================================

cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok()  { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); }

# chk "<needle>" "<haystack>" "<label>"
chk() {
  if printf '%s' "$2" | grep -qF -- "$1"; then
    ok "$3"
  else
    bad "$3 (output did not contain: $1)"
  fi
}

BIN_OUT=""
BIN_RC=0

# run_bin <name> [args...] - run ./bin/<name> and capture stdout, stderr, status
run_bin() {
  local name="$1"; shift
  BIN_OUT="$("./bin/$name" "$@" 2>&1)"
  BIN_RC=$?
}

printf 'Module 6 and 8 (C system calls) tests\n'

# ---------- 1. the C sources ----------
printf '\n1. The C sources\n'
for f in file_io.c process_fork.c exec_demo.c wait_demo.c; do
  if [ -r "c_programs/$f" ]; then ok "c_programs/$f exists and is readable"; else bad "c_programs/$f is missing"; fi
done

for f in file_io.c process_fork.c exec_demo.c wait_demo.c; do
  if grep -q 'COMMAND:' "c_programs/$f"; then ok "c_programs/$f documents its commands"; else bad "c_programs/$f has no COMMAND header"; fi
done

for f in file_io.c process_fork.c exec_demo.c wait_demo.c; do
  if grep -q 'perror(' "c_programs/$f"; then ok "c_programs/$f reports failures with perror()"; else bad "c_programs/$f does not use perror()"; fi
done

# Requirement: never kill arbitrary processes. None of the programs may signal
# any process at all.
for f in file_io.c process_fork.c exec_demo.c wait_demo.c; do
  if grep -qE '\bkill[[:space:]]*\(' "c_programs/$f"; then
    bad "c_programs/$f calls kill()"
  else
    ok "c_programs/$f never calls kill()"
  fi
done

if grep -q 'write_all' c_programs/file_io.c; then ok "file_io.c handles partial writes with a write_all() loop"; else bad "file_io.c has no partial-write handling"; fi

# ---------- 2. the build ----------
printf '\n2. make all compiles every program into bin/\n'
make clean >/dev/null 2>&1
build_out="$(make all 2>&1)"
build_rc=$?
if [ "$build_rc" -eq 0 ]; then ok "make all returned 0"; else bad "make all returned $build_rc"; fi
warnings="$(printf '%s' "$build_out" | grep -c 'warning:')"
if [ "$warnings" -eq 0 ]; then ok "gcc reported no warnings"; else bad "gcc reported $warnings warnings"; fi
for name in file_io process_fork exec_demo wait_demo; do
  if [ -x "bin/$name" ]; then ok "bin/$name was built and is executable"; else bad "bin/$name is missing or not executable"; fi
done

# ---------- 3. process_fork ----------
printf '\n3. bin/process_fork\n'
run_bin process_fork
if [ "$BIN_RC" -eq 0 ]; then ok "process_fork exited with status 0"; else bad "process_fork exited with status $BIN_RC"; fi
chk 'parent: I am about to call fork().' "$BIN_OUT" "the parent reports itself before fork()"
chk 'child : fork() returned 0, so I am the child.' "$BIN_OUT" "fork() returned 0 in the child"
chk "which is my child's pid." "$BIN_OUT" "fork() returned the child pid in the parent"
chk 'parent: child ended normally with exit status 7.' "$BIN_OUT" "the parent reaped the child and read exit status 7"
chk 'parent: because I waited, the child was reaped.' "$BIN_OUT" "the parent waited, so no zombie is left"

# ---------- 4. exec_demo ----------
printf '\n4. bin/exec_demo\n'
run_bin exec_demo
if [ "$BIN_RC" -eq 0 ]; then ok "exec_demo exited with status 0"; else bad "exec_demo exited with status $BIN_RC"; fi
chk 'child : hello from execlp (found on PATH)' "$BIN_OUT" "execlp() replaced the child with echo"
chk 'child : hello from execl (full path)' "$BIN_OUT" "execl() replaced the child with echo"
chk 'parent: execlp("echo", ...) finished with exit status 0.' "$BIN_OUT" "the execlp child was reaped with status 0"
chk 'parent: execl("/bin/echo", ...) finished with exit status 0.' "$BIN_OUT" "the execl child was reaped with status 0"
chk 'parent: both children were reaped with wait().' "$BIN_OUT" "both exec children were reaped"

# ---------- 5. wait_demo ----------
printf '\n5. bin/wait_demo\n'
run_bin wait_demo
if [ "$BIN_RC" -eq 0 ]; then ok "wait_demo exited with status 0"; else bad "wait_demo exited with status $BIN_RC"; fi
chk 'parent: reaped pid ' "$BIN_OUT" "waitpid() reported a specific child"
chk 'exit status 42.' "$BIN_OUT" "the second child's own exit status was read back"
chk 'parent: both children were reaped, so no zombies remain.' "$BIN_OUT" "both children were reaped"
chk "says the child state is 'Z' (a zombie, also called defunct)" "$BIN_OUT" "a real zombie state was read from /proc"
chk 'is gone (the entry no longer exists)' "$BIN_OUT" "the zombie disappeared once it was reaped"
chk 'orphan: process B: my pid is ' "$BIN_OUT" "the orphaned process reported itself"
chk 'is not the pid that started me' "$BIN_OUT" "the orphan was adopted by a different process"
chk 'Orphan : a child whose parent ends first.' "$BIN_OUT" "the program explains what an orphan is"
z_lines="$(printf '%s' "$BIN_OUT" | grep -c 'zombie:')"
if [ "$z_lines" -ge 5 ]; then ok "the zombie section printed $z_lines lines of explanation"; else bad "the zombie section printed only $z_lines lines"; fi

# ---------- 6. file_io ----------
printf '\n6. bin/file_io\n'
mkdir -p sandbox
work="$(pwd)/sandbox/file_io_demo"
run_bin file_io "$work"
if [ "$BIN_RC" -eq 0 ]; then ok "file_io exited with status 0 when given a sandbox directory"; else bad "file_io exited with status $BIN_RC"; fi
chk '1. getcwd()  -> started in ' "$BIN_OUT" "getcwd() reported the starting directory"
chk '4. creat()   -> hello.txt created, file descriptor ' "$BIN_OUT" "creat() returned a file descriptor"
chk '5. write()   -> wrote one line, then close() released fd ' "$BIN_OUT" "write() then close() released the descriptor"
chk 'Hello from file_io.c' "$BIN_OUT" "the file was read back with open() and read()"
chk '7. O_APPEND  -> added a second line without erasing the first' "$BIN_OUT" "O_APPEND added a line without erasing"
chk '8. read()    -> hello.txt holds 2 lines and 57 bytes' "$BIN_OUT" "read() measured the file correctly"
chk '9. mkdir()   -> created the directory subdir' "$BIN_OUT" "mkdir() created a directory"
chk 'rmdir()   -> removed the empty directory subdir' "$BIN_OUT" "rmdir() removed the empty directory"
chk '10. unlink()  -> removed hello.txt' "$BIN_OUT" "unlink() removed the file"
chk '11. cleanup   -> removed ' "$BIN_OUT" "the program removed its own working directory"
chk 'All file and directory system calls returned success.' "$BIN_OUT" "every system call reported success"

if [ ! -d sandbox/file_io_demo ]; then ok "no working directory was left in the sandbox"; else bad "sandbox/file_io_demo is still there"; fi
sandbox_files="$(find sandbox -type f ! -name '.gitkeep' 2>/dev/null)"
if [ -z "$sandbox_files" ]; then ok "the sandbox holds no leftover files"; else bad "the sandbox holds leftovers: $sandbox_files"; fi

# No argument must be refused, and the message must go to standard error.
BIN_OUT="$(./bin/file_io 2>&1 >/dev/null)"
BIN_RC=$?
if [ "$BIN_RC" -eq 2 ]; then ok "file_io with no argument exits with status 2"; else bad "file_io with no argument exited with $BIN_RC, expected 2"; fi
chk 'usage: ./bin/file_io <working-directory>' "$BIN_OUT" "the usage message is printed on standard error"

# ---------- 7. nothing escaped the sandbox ----------
printf '\n7. Nothing escaped the sandbox\n'
# The sandbox is skipped on purpose: the point is that nothing was created
# anywhere else in the project.
outside="$(find . -path ./sandbox -prune -o \( -name hello.txt -o -name file_io_demo \) -print 2>/dev/null)"
if [ -z "$outside" ]; then ok "no demonstration files exist anywhere outside ./sandbox"; else bad "files escaped the sandbox: $outside"; fi

zombies="$(ps -eo stat=,comm= 2>/dev/null | grep -cE '^Z.*(file_io|process_fork|exec_demo|wait_demo)')"
if [ "$zombies" -eq 0 ]; then ok "no zombie process was left behind by the demonstrations"; else bad "$zombies zombie process(es) were left behind"; fi

# ---------- 8. the modules that drive the programs ----------
printf '\n8. The modules that run the programs\n'
for f in modules/processes.sh modules/system_calls.sh; do
  if bash -n "$f" 2>/dev/null; then ok "bash -n accepts $f"; else bad "bash -n rejected $f"; fi
done
if grep -q 'check_inside_sandbox' modules/system_calls.sh; then ok "Module 8 checks the sandbox before running file_io"; else bad "Module 8 does not check the sandbox path"; fi
if grep -n '\beval\b' modules/processes.sh modules/system_calls.sh >/dev/null 2>&1; then bad "the new modules contain the word eval"; else ok "the new modules contain no eval"; fi

# ---------- summary ----------
printf '\nModule 6 and 8 test result: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
