/* ============================================================
 * UniShell - signal_demo.c   (Phase 8: Inter-Process Communication)
 * COMMAND: ./bin/signal_demo | PURPOSE: install signal handlers with sigaction() and show a signal being caught, timed with alarm(), and ignored | MODULE: Inter-Process Communication
 *
 * What this program shows:
 *   sigaction() - install a handler function for one signal
 *   raise()     - send a signal to THIS process only
 *   alarm()     - ask the kernel for a SIGALRM after N seconds
 *   pause()     - sleep until a signal arrives and its handler returns
 *   SIG_IGN     - show that a signal can be deliberately ignored
 *
 * The important idea: a signal handler should do as little as possible. In
 * this program each handler only sets a small flag (type sig_atomic_t, the
 * only kind of variable that is safe here). The main code then notices the
 * flag and does the printing. That is why the messages appear AFTER the
 * handler has returned instead of from inside it.
 *
 * Safety: this program never signals another process. raise() delivers the
 * signal to itself, and alarm() is the kernel's own timer, so there is no
 * pid to aim at and nothing else on the system can be affected.
 *
 * Build: make all
 * Run  : ./bin/signal_demo
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>

#include <signal.h>       /* sigaction signal raise alarm SIG_IGN */
#include <unistd.h>       /* pause and getpid */
#include <sys/types.h>    /* pid_t */

/* sig_atomic_t is the only variable type that may be touched by a handler.
 * volatile stops the compiler from caching the value in a register. */
static volatile sig_atomic_t usr1_count  = 0;
static volatile sig_atomic_t alarm_fired = 0;

/* ---- handlers: each one only records that something happened ---- */
static void on_usr1(int signo)
{
    (void)signo;                 /* the number is not needed here */
    usr1_count = usr1_count + 1;
}

static void on_alarm(int signo)
{
    (void)signo;
    alarm_fired = 1;
}

int main(void)
{
    struct sigaction sa;

    printf("signal_demo: pid %ld\n\n", (long)getpid());

    /* ---- 1. install the handlers ---- */
    /* sigaction() is the modern, portable way to say "run this function when
     * this signal arrives". sa_flags = 0 means an interrupted system call is
     * NOT restarted, which is exactly what we want for pause() below. */
    sa.sa_handler = on_usr1;
    sigemptyset(&sa.sa_mask);    /* no extra signals blocked while running */
    sa.sa_flags = 0;
    if (sigaction(SIGUSR1, &sa, NULL) == -1) {
        perror("sigaction SIGUSR1");
        return EXIT_FAILURE;
    }

    sa.sa_handler = on_alarm;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGALRM, &sa, NULL) == -1) {
        perror("sigaction SIGALRM");
        return EXIT_FAILURE;
    }
    printf(" 1. sigaction() -> handlers installed for SIGUSR1 and SIGALRM\n");

    /* ---- 2. raise() sends SIGUSR1 to ourselves ---- */
    printf(" 2. raise()     -> sending SIGUSR1 to ourselves...\n");
    if (raise(SIGUSR1) != 0) {
        perror("raise");
        return EXIT_FAILURE;
    }
    /* By the time raise() returns, the handler has already run. */
    printf(" 3. handler     -> on_usr1() ran, so usr1_count is now %d\n",
           (int)usr1_count);

    /* ---- 3. alarm() asks the kernel for a signal later ---- */
    printf(" 4. alarm()     -> asking for SIGALRM in 1 second...\n");
    alarm(1);
    /* pause() sleeps until a signal is delivered and handled. Because the
     * SIGALRM handler returns, pause() comes back and the loop checks the
     * flag. Without the alarm this loop would wait for ever, which is why
     * alarm() is the safe way to put a deadline on a wait. */
    while (alarm_fired == 0) {
        pause();
    }
    printf(" 5. handler     -> on_alarm() ran: SIGALRM arrived after about 1 second\n");

    /* ---- 4. a signal can be ignored on purpose ---- */
    printf(" 6. SIG_IGN     -> asking to ignore SIGTERM, then raising it...\n");
    if (signal(SIGTERM, SIG_IGN) == SIG_ERR) {
        perror("signal SIG_IGN");
        return EXIT_FAILURE;
    }
    raise(SIGTERM);
    printf(" 7. still alive -> SIGTERM was ignored, so the program kept running\n");
    /* Put the default handling back, as a tidy program always should. */
    signal(SIGTERM, SIG_DFL);

    printf("\n  Some signals worth knowing:\n");
    printf("    SIGINT  (2)  Ctrl-C at the terminal\n");
    printf("    SIGTERM (15) polite request to stop\n");
    printf("    SIGKILL (9)  cannot be caught or ignored - the kernel's last resort\n");
    printf("    SIGUSR1 (10) reserved for the programmer, used nowhere by the system\n");
    printf("    SIGALRM (14) the timer set by alarm()\n");

    printf("\n  A handler must be short: it runs in the middle of whatever the\n");
    printf("  program was doing. Setting a flag and letting the main code act on\n");
    printf("  it is the safe pattern, and it is what this program does.\n");
    return 0;
}
