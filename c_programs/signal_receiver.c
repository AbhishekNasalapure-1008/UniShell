/* ============================================================
 * UniShell - signal_receiver.c   (Phase 8: Inter-Process Communication)
 * COMMAND: ./bin/signal_receiver [timeout-seconds] | PURPOSE: install a signal handler, print the pid, and wait for SIGUSR1, SIGUSR2 or SIGTERM to arrive | MODULE: Inter-Process Communication
 *
 * This is the receiving half of the signal demonstration. A second program
 * (bin/signal_sender, or the shell's own kill builtin) sends it a signal.
 *
 * What this program shows:
 *   sigaction() - install handlers for SIGUSR1, SIGUSR2 and SIGTERM
 *   getpid()    - report the pid so the sender knows where to aim
 *   alarm()     - put a deadline on the wait
 *   pause()     - sleep until a signal arrives
 *
 * Why the alarm() deadline matters: without it, a receiver with no sender
 * would wait for ever and the demonstration would hang. The alarm guarantees
 * the program always finishes: either a signal arrives, or the timeout is
 * reached and it exits with status 3 to say honestly that nothing arrived.
 * SIGALRM has its own handler for that reason; left at its default action it
 * would stop the program with a signal instead of letting it exit tidily.
 *
 * Safety: this program does not signal anything. It only waits to be told,
 * and it can only be told by a process that knows its pid. UniShell starts
 * this program itself and passes that pid to bin/signal_sender, so no process
 * that UniShell did not start is ever involved.
 *
 * Build: make all
 * Run  : ./bin/signal_receiver 5
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>

#include <signal.h>       /* sigaction alarm SIGUSR1 SIGUSR2 SIGTERM */
#include <unistd.h>       /* pause and getpid */
#include <sys/types.h>    /* pid_t */

/* The handlers record what happened; the main code does the printing. */
static volatile sig_atomic_t caught    = 0;   /* which signal arrived     */
static volatile sig_atomic_t timed_out = 0;   /* did the deadline arrive? */

static void on_signal(int signo)
{
    caught = signo;
}

static void on_alarm(int signo)
{
    (void)signo;
    timed_out = 1;
}

int main(int argc, char **argv)
{
    struct sigaction sa;
    int timeout_sec = 5;

    if (argc > 2) {
        fprintf(stderr, "usage: %s [timeout-seconds]\n", argv[0]);
        return 2;
    }
    if (argc == 2) {
        timeout_sec = atoi(argv[1]);
        if (timeout_sec <= 0 || timeout_sec > 30) {
            fprintf(stderr, "timeout must be between 1 and 30 seconds\n");
            return 2;
        }
    }

    /* ---- install the same handler for every signal we care about ---- */
    sa.sa_handler = on_signal;
    sigemptyset(&sa.sa_mask);    /* do not block other signals while running */
    sa.sa_flags = 0;             /* no SA_RESTART: pause() must come back */
    if (sigaction(SIGUSR1, &sa, NULL) == -1) {
        perror("sigaction SIGUSR1");
        return EXIT_FAILURE;
    }
    if (sigaction(SIGUSR2, &sa, NULL) == -1) {
        perror("sigaction SIGUSR2");
        return EXIT_FAILURE;
    }
    if (sigaction(SIGTERM, &sa, NULL) == -1) {
        perror("sigaction SIGTERM");
        return EXIT_FAILURE;
    }

    /* SIGALRM is the deadline. Left at its default action it would stop the
     * program with a signal, so it gets a handler that only sets a flag. */
    sa.sa_handler = on_alarm;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGALRM, &sa, NULL) == -1) {
        perror("sigaction SIGALRM");
        return EXIT_FAILURE;
    }

    printf("signal_receiver: pid %ld\n", (long)getpid());
    printf(" 1. sigaction() -> handlers installed for SIGUSR1, SIGUSR2 and SIGTERM\n");
    printf(" 2. getpid()    -> send a signal with: kill -USR1 %ld\n", (long)getpid());
    printf(" 3. alarm()     -> giving up after %d second(s) at the most\n", timeout_sec);
    printf(" 4. pause()     -> waiting for a signal now...\n");

    /* Flush before waiting, so a caller watching our output (or a file it is
     * redirected into) can see that the handlers are installed and we are
     * about to wait. Otherwise the text would sit in a buffer until the end. */
    fflush(stdout);

    /* alarm() asks the kernel for SIGALRM after timeout_sec seconds, which is
     * the deadline that stops this program waiting for ever. */
    alarm((unsigned)timeout_sec);

    while (caught == 0 && timed_out == 0) {
        pause();                 /* sleep until a handled signal arrives */
    }

    alarm(0);                    /* cancel the deadline: it is no longer needed */

    if (caught == 0) {
        printf(" 5. alarm()     -> no signal arrived within %d second(s)\n",
               timeout_sec);
        printf("\nsignal_receiver finished with status 3 (nothing was sent).\n");
        return 3;
    }

    if (caught == SIGUSR1) {
        printf(" 5. handler     -> caught SIGUSR1 (%d), the programmer's own signal\n",
               caught);
    } else if (caught == SIGUSR2) {
        printf(" 5. handler     -> caught SIGUSR2 (%d), the second programmer signal\n",
               caught);
    } else if (caught == SIGTERM) {
        printf(" 5. handler     -> caught SIGTERM (%d), the polite stop request\n",
               caught);
    } else {
        printf(" 5. handler     -> caught signal %d\n", (int)caught);
    }

    printf("\nsignal_receiver finished with status 0.\n");
    return 0;
}
