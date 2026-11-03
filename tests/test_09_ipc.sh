#!/usr/bin/env bash
# ============================================================
# UniShell - Module 7 (IPC) tests   (Phase 8)
# COMMAND: bash tests/test_09_ipc.sh | PURPOSE: prove every IPC demonstration compiles without warnings, runs for real, ends by itself and leaves nothing behind | MODULE: Inter-Process Communication
#
# The most important checks here are the safety ones:
#   * a program that waits for a partner must still finish on its own, so each
#     run is wrapped in "timeout" and a run that needed to be killed (status
#     124) is reported as a FAILURE;
#   * a signal is only ever sent to a process this test started a moment ago;
#   * the sender refuses pids and signals it should never accept.
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

# run_guarded <seconds> <program> [args...]
# Runs a demonstration with a hard time limit. If the program hangs, timeout
# stops it and we get status 124, which every caller checks for explicitly.
have_timeout=0
# COMMAND: command -v timeout | PURPOSE: use a time limit when the tool is present | MODULE: 1
command -v timeout >/dev/null 2>&1 && have_timeout=1

run_guarded() {
  local secs="$1"; shift
  if [ "$have_timeout" -eq 1 ]; then
    BIN_OUT="$(timeout "$secs" "$@" 2>&1)"
    BIN_RC=$?
  else
    BIN_OUT="$("$@" 2>&1)"
    BIN_RC=$?
  fi
}

# wait_for_line <file> <needle> [tries]
# Bounded wait: used so a partner is only contacted once it is really ready.
wait_for_line() {
  local file="$1" needle="$2" tries="${3:-50}"
  while [ "$tries" -gt 0 ]; do
    if [ -f "$file" ] && grep -qF -- "$needle" "$file"; then return 0; fi
    sleep 0.1
    tries=$((tries - 1))
  done
  return 1
}

MENU_OUT=""
MENU_RC=0
run_menu() {
  MENU_OUT="$(printf '%s' "$1" | bash ./unishell.sh 2>&1)"
  MENU_RC=$?
}
expect_in() {
  if printf '%s' "$MENU_OUT" | grep -qF -- "$1"; then ok "$2"; else bad "$2 (output did not contain: $1)"; fi
}

IPC_PROGRAMS="pipe_demo fifo_receiver fifo_sender signal_demo signal_receiver signal_sender"

printf 'Module 7 (IPC) tests\n'

# ---------- 1. the C sources ----------
printf '\n1. The IPC C sources\n'
for f in pipe_demo.c fifo_receiver.c fifo_sender.c signal_demo.c signal_receiver.c signal_sender.c; do
  if [ -r "c_programs/$f" ]; then ok "c_programs/$f exists and is readable"; else bad "c_programs/$f is missing"; fi
done
for f in pipe_demo.c fifo_receiver.c fifo_sender.c signal_demo.c signal_receiver.c signal_sender.c; do
  if grep -q 'COMMAND:' "c_programs/$f"; then ok "c_programs/$f documents its commands"; else bad "c_programs/$f has no COMMAND header"; fi
done
for f in pipe_demo.c fifo_receiver.c fifo_sender.c signal_demo.c signal_receiver.c signal_sender.c; do
  if grep -q 'perror(' "c_programs/$f"; then ok "c_programs/$f reports failures with perror()"; else bad "c_programs/$f does not use perror()"; fi
done

# Each facility really is used, by the program that claims to demonstrate it.
pairs="pipe_demo.c:pipe( fifo_receiver.c:mkfifo( fifo_receiver.c:unlink( fifo_receiver.c:poll( fifo_sender.c:write( signal_demo.c:sigaction( signal_receiver.c:alarm( signal_receiver.c:pause( signal_sender.c:kill("
for pair in $pairs; do
  file="c_programs/${pair%%:*}"
  needle="${pair##*:}"
  if grep -qF -- "$needle" "$file"; then ok "$file uses $needle"; else bad "$file does not use $needle"; fi
done

# Descriptors must be released: every program that opens one also closes it.
for f in pipe_demo.c fifo_receiver.c fifo_sender.c; do
  if grep -qF 'close(' "c_programs/$f"; then ok "c_programs/$f releases its descriptors with close()"; else bad "c_programs/$f never calls close()"; fi
done

# SIGKILL cannot be caught or ignored, so the whitelist must never be able to
# produce it. The name may still appear in a comment; what matters is what the
# whitelist actually returns.
if grep -qE 'return[[:space:]]+SIGKILL' c_programs/signal_sender.c; then
  bad "signal_sender.c can return SIGKILL from its whitelist"
else
  ok "signal_sender.c can never return SIGKILL"
fi
whitelisted="$(grep -cE 'return[[:space:]]+SIG[A-Z0-9]+' c_programs/signal_sender.c)"
if [ "$whitelisted" -eq 3 ]; then
  ok "the whitelist returns exactly three signals (SIGUSR1, SIGUSR2, SIGTERM)"
else
  bad "the whitelist returns $whitelisted signals, expected 3"
fi
# The whitelist is real code, not a comment.
if grep -q 'name_to_signal' c_programs/signal_sender.c; then ok "signal_sender.c turns a name into a signal through a fixed whitelist"; else bad "signal_sender.c has no whitelist function"; fi

# ---------- 2. the build ----------
printf '\n2. make all compiles every IPC program into bin/\n'
make clean >/dev/null 2>&1
build_out="$(make all 2>&1)"
build_rc=$?
if [ "$build_rc" -eq 0 ]; then ok "make all returned 0"; else bad "make all returned $build_rc"; fi
warnings="$(printf '%s' "$build_out" | grep -c 'warning:')"
if [ "$warnings" -eq 0 ]; then ok "gcc reported no warnings"; else bad "gcc reported $warnings warnings"; fi
for name in $IPC_PROGRAMS; do
  if [ -x "bin/$name" ]; then ok "bin/$name was built and is executable"; else bad "bin/$name is missing or not executable"; fi
done

# ---------- 3. pipe_demo ----------
printf '\n3. bin/pipe_demo - an unnamed pipe from pipe()\n'
run_guarded 10 ./bin/pipe_demo
if [ "$BIN_RC" -eq 0 ]; then ok "pipe_demo exited with status 0"; else bad "pipe_demo exited with status $BIN_RC"; fi
if [ "$BIN_RC" -ne 124 ]; then ok "pipe_demo finished by itself (it did not have to be stopped)"; else bad "pipe_demo hung and had to be stopped"; fi
chk '1. pipe()' "$BIN_OUT" "pipe() returned the two descriptors"
chk '-> read end is fd ' "$BIN_OUT" "the read end of the pipe was reported"
chk 'the read end it does not use' "$BIN_OUT" "the child closed the end it does not use"
chk 'wrote 22 bytes: hello through the pipe' "$BIN_OUT" "the child wrote the message into the pipe"
chk 'read() returned the text: "hello through the pipe"' "$BIN_OUT" "the parent read the same bytes back"
chk 'reaped child pid ' "$BIN_OUT" "the parent reaped the child, so no zombie is left"
chk 'A pipe holds no name' "$BIN_OUT" "the program explains why a pipe cannot be found by another program"

# ---------- 4. fifo_receiver with no sender must still finish ----------
printf '\n4. bin/fifo_receiver with no sender - it must not hang\n'
rm -f sandbox/ipc_test.fifo
start="$(date +%s)"
run_guarded 20 ./bin/fifo_receiver sandbox/ipc_test.fifo 2
end="$(date +%s)"
elapsed=$((end - start))
if [ "$BIN_RC" -eq 3 ]; then ok "fifo_receiver exited with status 3 (nothing was sent)"; else bad "fifo_receiver exited with status $BIN_RC, expected 3"; fi
if [ "$BIN_RC" -ne 124 ]; then ok "fifo_receiver ended by itself instead of hanging"; else bad "fifo_receiver hung and had to be stopped"; fi
if [ "$elapsed" -lt 15 ]; then ok "fifo_receiver finished in about $elapsed second(s), close to its deadline"; else bad "fifo_receiver took $elapsed seconds, far longer than its deadline"; fi
chk 'poll()' "$BIN_OUT" "poll() is the call that does the waiting"
chk 'opened without blocking' "$BIN_OUT" "the read end was opened with O_NONBLOCK"
chk 'no sender appeared within 2 second(s)' "$BIN_OUT" "the deadline was reported honestly"
chk 'unlink()  -> removed the FIFO' "$BIN_OUT" "the receiver removed its own FIFO"
if [ ! -e sandbox/ipc_test.fifo ]; then ok "no FIFO was left in the sandbox"; else bad "sandbox/ipc_test.fifo was left behind"; fi

# ---------- 5. the FIFO pair end to end ----------
printf '\n5. bin/fifo_receiver and bin/fifo_sender together\n'
rm -f sandbox/ipc_test.fifo sandbox/ipc_recv.out
# COMMAND: & | PURPOSE: start the receiving half in the background | MODULE: Process Management
./bin/fifo_receiver sandbox/ipc_test.fifo 8 > sandbox/ipc_recv.out 2>&1 &
recpid=$!
if wait_for_line sandbox/ipc_recv.out 'poll()' 60; then ok "the receiver reached its waiting state"; else bad "the receiver never became ready"; fi
./bin/fifo_sender sandbox/ipc_test.fifo hello through the named pipe > sandbox/ipc_send.out 2>&1
send_rc=$?
wait "$recpid"
rec_rc=$?
send_out="$(cat sandbox/ipc_send.out 2>/dev/null)"
rec_out="$(cat sandbox/ipc_recv.out 2>/dev/null)"

if [ "$send_rc" -eq 0 ]; then ok "the sender exited with status 0"; else bad "the sender exited with status $send_rc"; fi
if [ "$rec_rc" -eq 0 ]; then ok "the receiver exited with status 0"; else bad "the receiver exited with status $rec_rc"; fi
chk 'is a FIFO, so it is safe to open for writing' "$send_out" "the sender checked the path with stat() first"
chk 'writing end is fd ' "$send_out" "the sender opened the write end"
chk 'Message delivered: hello through the named pipe' "$send_out" "the sender reported what it delivered"
chk 'byte(s): hello through the named pipe' "$rec_out" "the message crossed the named pipe"
chk 'returned 0, so every writer has closed' "$rec_out" "the receiver saw end of file once the writer closed"
chk 'released the reading end' "$rec_out" "the receiver closed its descriptor"
if [ ! -e sandbox/ipc_test.fifo ]; then ok "the FIFO was removed at the end"; else bad "the FIFO was left behind"; fi
rm -f sandbox/ipc_recv.out sandbox/ipc_send.out

# ---------- 6. signal_demo ----------
printf '\n6. bin/signal_demo - handlers, raise(), alarm() and SIG_IGN\n'
run_guarded 10 ./bin/signal_demo
if [ "$BIN_RC" -eq 0 ]; then ok "signal_demo exited with status 0"; else bad "signal_demo exited with status $BIN_RC"; fi
if [ "$BIN_RC" -ne 124 ]; then ok "signal_demo finished by itself"; else bad "signal_demo hung and had to be stopped"; fi
chk 'handlers installed for SIGUSR1 and SIGALRM' "$BIN_OUT" "sigaction() installed the handlers"
chk 'on_usr1() ran, so usr1_count is now 1' "$BIN_OUT" "raise() delivered SIGUSR1 to this process"
chk 'SIGALRM arrived after about 1 second' "$BIN_OUT" "alarm() produced a SIGALRM that was handled"
chk 'SIGTERM was ignored, so the program kept running' "$BIN_OUT" "SIG_IGN made the process ignore a signal"
chk 'SIGKILL (9)' "$BIN_OUT" "the program lists the signals worth knowing"

# ---------- 7. signal_receiver with no signal must still finish ----------
printf '\n7. bin/signal_receiver with no signal - it must not hang\n'
run_guarded 20 ./bin/signal_receiver 2
if [ "$BIN_RC" -eq 3 ]; then ok "signal_receiver exited with status 3 (nothing arrived)"; else bad "signal_receiver exited with status $BIN_RC, expected 3"; fi
if [ "$BIN_RC" -ne 124 ]; then ok "signal_receiver ended by itself instead of hanging"; else bad "signal_receiver hung and had to be stopped"; fi
if [ "$BIN_RC" -ne 142 ]; then ok "the alarm deadline did not kill the program with a signal"; else bad "the program was killed by SIGALRM instead of exiting tidily"; fi
chk 'handlers installed for SIGUSR1, SIGUSR2 and SIGTERM' "$BIN_OUT" "all three catchable signals got a handler"
chk 'giving up after 2 second(s) at the most' "$BIN_OUT" "the deadline was set from the command line"
chk 'no signal arrived within 2 second(s)' "$BIN_OUT" "the timeout was reported honestly"
chk 'finished with status 3' "$BIN_OUT" "the program reported its own exit status"

# ---------- 8. the signal pair, one catchable signal at a time ----------
printf '\n8. bin/signal_sender delivers, bin/signal_receiver catches\n'
for S in USR1 USR2 TERM; do
  rm -f sandbox/ipc_sig.out
  ./bin/signal_receiver 8 > sandbox/ipc_sig.out 2>&1 &
  sigpid=$!
  wait_for_line sandbox/ipc_sig.out 'waiting for a signal now' 60
  ./bin/signal_sender "$sigpid" "$S" >/dev/null 2>&1
  send_rc=$?
  wait "$sigpid"
  rec_rc=$?
  sig_out="$(cat sandbox/ipc_sig.out 2>/dev/null)"
  if [ "$send_rc" -eq 0 ] && [ "$rec_rc" -eq 0 ] && printf '%s' "$sig_out" | grep -qF -- "caught SIG$S"; then
    ok "the receiver caught SIG$S and exited with status 0"
  else
    bad "the SIG$S pair failed (sender $send_rc, receiver $rec_rc)"
  fi
  rm -f sandbox/ipc_sig.out
done

# ---------- 9. the sender refuses what it should never send ----------
printf '\n9. bin/signal_sender refuses dangerous requests\n'
BIN_OUT="$(./bin/signal_sender 1 USR1 2>&1)"; BIN_RC=$?
if [ "$BIN_RC" -eq 2 ]; then ok "pid 1 is refused with status 2"; else bad "pid 1 gave status $BIN_RC, expected 2"; fi
chk 'refusing pid 1' "$BIN_OUT" "the refusal names the pid"

BIN_OUT="$(./bin/signal_sender notanumber USR1 2>&1)"; BIN_RC=$?
if [ "$BIN_RC" -eq 2 ]; then ok "junk text is refused with status 2"; else bad "junk text gave status $BIN_RC, expected 2"; fi
chk 'is not a pid' "$BIN_OUT" "the refusal explains that it is not a pid"

BIN_OUT="$(./bin/signal_sender 0 USR1 2>&1)"; BIN_RC=$?
if [ "$BIN_RC" -eq 2 ]; then ok "pid 0 is refused with status 2"; else bad "pid 0 gave status $BIN_RC, expected 2"; fi

BIN_OUT="$(./bin/signal_sender 2>&1)"; BIN_RC=$?
if [ "$BIN_RC" -eq 2 ]; then ok "no arguments at all is refused with status 2"; else bad "a missing argument gave status $BIN_RC, expected 2"; fi
chk 'usage: ./bin/signal_sender <pid> [USR1|USR2|TERM]' "$BIN_OUT" "the usage line is printed"

# A signal that cannot be caught must not be on the list. Our own helper
# process is the target, so the test can prove the request was refused by
# checking that the helper is still alive afterwards.
# COMMAND: sleep 5 & | PURPOSE: start a helper this test owns and may safely use as a target | MODULE: Process Management
sleep 5 &
guard=$!
BIN_OUT="$(./bin/signal_sender "$guard" KILL 2>&1)"; BIN_RC=$?
if [ "$BIN_RC" -eq 2 ]; then ok "SIGKILL is refused with status 2"; else bad "SIGKILL gave status $BIN_RC, expected 2"; fi
chk 'is not an allowed signal' "$BIN_OUT" "the refusal explains which signals are allowed"
if kill -0 "$guard" 2>/dev/null; then
  ok "the refused signal was never delivered (the helper is still running)"
else
  bad "the helper was stopped, so a refused signal was sent anyway"
fi
kill "$guard" 2>/dev/null
wait "$guard" 2>/dev/null

# ---------- 10. the module that drives it all ----------
printf '\n10. modules/ipc.sh\n'
if bash -n modules/ipc.sh 2>/dev/null; then ok "bash -n accepts modules/ipc.sh"; else bad "bash -n rejected modules/ipc.sh"; fi
if grep -q 'check_inside_sandbox' modules/ipc.sh; then ok "the module checks the sandbox path before creating anything"; else bad "the module does not check the sandbox path"; fi
if grep -q 'log_activity_exit' modules/ipc.sh; then ok "the module records exit statuses in the activity log"; else bad "the module does not record exit statuses"; fi
if grep -n '\beval\b' modules/ipc.sh >/dev/null 2>&1; then bad "modules/ipc.sh contains the word eval"; else ok "modules/ipc.sh contains no eval"; fi
if grep -qE '(^|[^a-zA-Z_])kill[[:space:]]' modules/ipc.sh; then
  bad "modules/ipc.sh runs kill itself instead of using bin/signal_sender"
else
  ok "modules/ipc.sh never signals a process itself"
fi

# ---------- 11. the menu can reach Module 7 ----------
printf '\n11. The menu reaches Module 7\n'
run_menu '7
0
0
'
expect_in "Module 7 - Inter-Process Communication Lab" "the IPC sub-menu opens from the main menu"
expect_in "Unnamed pipe: pipe() carries bytes to a child" "the unnamed pipe option is listed"
expect_in "Signals: a receiver waits and a sender signals it" "the signal pair option is listed"

# ---------- 12. nothing was left behind ----------
printf '\n12. Nothing was left behind\n'
leftovers="$(find sandbox -type f ! -name '.gitkeep' 2>/dev/null)"
if [ -z "$leftovers" ]; then ok "the sandbox holds no leftover files"; else bad "the sandbox holds leftovers: $leftovers"; fi
fifos="$(find sandbox -type p 2>/dev/null)"
if [ -z "$fifos" ]; then ok "no named pipe was left in the sandbox"; else bad "a FIFO was left behind: $fifos"; fi
zombies="$(ps -eo stat=,comm= 2>/dev/null | grep -cE '^Z.*(pipe_demo|fifo_|signal_)')"
if [ "$zombies" -eq 0 ]; then ok "no zombie process was left behind by the demonstrations"; else bad "$zombies zombie process(es) were left behind"; fi

# ---------- summary ----------
printf '\nModule 7 (IPC) test result: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
