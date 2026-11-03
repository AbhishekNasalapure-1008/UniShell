/* ============================================================
 * UniShell - signal_sender.c   (Phase 8: Inter-Process Communication)
 * COMMAND: ./bin/signal_sender <pid> [USR1|USR2|TERM] | PURPOSE: send one of a small fixed set of signals to a process whose pid was given on the command line | MODULE: Inter-Process Communication
 *
 * This is the sending half of the signal demonstration. It pairs with
 * bin/signal_receiver, which prints its pid and then waits.
 *
 * What this program shows:
 *   kill()    - ask the kernel to deliver a signal to one process
 *   getpid()  - know our own pid, so we can refuse to signal ourselves
 *
 * Safety, and why the checks below are not decoration:
 *   * only USR1, USR2 and TERM may be sent. TERM is a polite request to stop;
 *     USR1 and USR2 are free for programmers to use. SIGKILL and SIGSTOP are
 *     refused on purpose, because they cannot be caught or refused.
 *   * pid 1 (the very first process) and pid 0 are refused, and so is our own
 *     pid. A signal sent to the wrong process can stop something important,
 *     so the range is kept deliberately narrow.
 *   * UniShell itself only ever passes the pid of bin/signal_receiver that it
 *     started a moment earlier, so in practice the target is always a process
 *     UniShell owns.
 *
 * Build: make all
 * Run  : ./bin/signal_sender 12345 USR1
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include <signal.h>       /* kill and the SIGxxx numbers */
#include <unistd.h>       /* getpid */
#include <sys/types.h>    /* pid_t */

static void die(const char *what)
{
    fflush(stdout);
    perror(what);
    exit(EXIT_FAILURE);
}

/* name_to_signal - turn a short name into a number, using a fixed list.
 * Nothing outside this list is ever produced, which is the whole point: the
 * text typed by the user selects from a whitelist and can never become an
 * arbitrary signal number. */
static int name_to_signal(const char *name)
{
    if (strcmp(name, "USR1") == 0) return SIGUSR1;
    if (strcmp(name, "USR2") == 0) return SIGUSR2;
    if (strcmp(name, "TERM") == 0) return SIGTERM;
    return 0;                    /* 0 means "not allowed" */
}

static const char *signal_to_name(int signo)
{
    if (signo == SIGUSR1) return "SIGUSR1";
    if (signo == SIGUSR2) return "SIGUSR2";
    if (signo == SIGTERM) return "SIGTERM";
    return "?";
}

int main(int argc, char **argv)
{
    const char *name = "USR1";
    long raw;
    char *end;
    pid_t target;
    int signo;

    if (argc < 2 || argc > 3) {
        fprintf(stderr, "usage: %s <pid> [USR1|USR2|TERM]\n", argv[0]);
        return 2;
    }

    /* ---- read the pid with strtol(), which reports junk honestly ---- */
    errno = 0;
    raw = strtol(argv[1], &end, 10);
    if (errno != 0 || end == argv[1] || *end != '\0') {
        fprintf(stderr, "'%s' is not a pid\n", argv[1]);
        return 2;
    }
    if (raw <= 1) {
        fprintf(stderr, "refusing pid %ld: a pid must be greater than 1\n", raw);
        return 2;
    }
    if ((pid_t)raw == getpid()) {
        fprintf(stderr, "refusing to signal ourselves (pid %ld)\n", (long)getpid());
        return 2;
    }
    target = (pid_t)raw;

    if (argc == 3) {
        name = argv[2];
    }
    signo = name_to_signal(name);
    if (signo == 0) {
        fprintf(stderr, "'%s' is not an allowed signal (use USR1, USR2 or TERM)\n", name);
        return 2;
    }

    printf("signal_sender: pid %ld\n", (long)getpid());
    printf(" 1. whitelist   -> %s is allowed, so the number %d will be sent\n",
           name, signo);
    printf(" 2. kill()      -> sending %s (%d) to pid %ld\n",
           signal_to_name(signo), signo, (long)target);

    /* ---- kill() is the system call that delivers a signal. Its name is
     * historical: it does not necessarily kill anything, it just sends the
     * signal whose number is given here. ---- */
    if (kill(target, signo) == -1) {
        die("kill");
    }

    printf(" 3. delivered   -> the kernel accepted the signal for pid %ld\n",
           (long)target);
    printf("\nThe other program is responsible for what it does with the signal:\n");
    printf("bin/signal_receiver has a handler for this one, so it prints which\n");
    printf("signal it caught and exits normally instead of being stopped.\n");
    return 0;
}
