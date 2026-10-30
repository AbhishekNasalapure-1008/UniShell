/* ============================================================
 * UniShell - exec_demo.c   (Phase 7: Processes)
 * COMMAND: ./bin/exec_demo | PURPOSE: show that the exec family replaces the running program while keeping the same process | MODULE: Shell Programming
 *
 * What this program shows:
 *   fork()    - a child process is created first
 *   execlp()  - looks the program up on PATH and replaces the child
 *   execl()   - runs a program named by its full path
 *   perror()  - reached only when exec FAILS, because exec never returns
 *               when it succeeds
 *   _exit()   - ends a child without flushing the parent's buffers twice
 *   wait()    - the parent reaps each child
 *
 * Build: make all
 * Run  : ./bin/exec_demo
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>

#include <unistd.h>       /* fork execl execlp _exit */
#include <sys/types.h>    /* pid_t */
#include <sys/wait.h>     /* wait and WIFEXITED / WEXITSTATUS */

/* run_one - fork, then let the child replace itself using the given exec
 * call. The parent reaps the child and reports its exit status.
 * "what" is only used in the printed explanation. */
static int run_one(const char *what, void (*exec_call)(void))
{
    pid_t pid;
    int status;

    /* Flush the buffers before fork(), so text already printed by the parent
     * is not copied into the child and printed a second time. */
    fflush(stdout);

    pid = fork();

    if (pid < 0) {
        perror("fork");
        return -1;
    }

    if (pid == 0) {
        /* Child: replace this program. If exec works, the lines after it
         * are never reached, because the process image has been replaced. */
        exec_call();
        /* Only reached when the exec call failed. */
        perror("exec");
        _exit(127);          /* 127 is the usual code for "command not found" */
    }

    if (wait(&status) == -1) {
        perror("wait");
        return -1;
    }
    if (WIFEXITED(status)) {
        printf("parent: %s finished with exit status %d.\n",
               what, WEXITSTATUS(status));
    } else {
        printf("parent: %s did not end normally.\n", what);
    }
    return 0;
}

/* The two exec calls are wrapped in small functions so they can be passed to
 * run_one(). Each one REPLACES the current program when it succeeds. */
static void call_execlp(void)
{
    /* execlp searches the PATH for "echo". argv[0] is "echo" by convention. */
    execlp("echo", "echo", "  child : hello from execlp (found on PATH)", (char *)NULL);
}

static void call_execl(void)
{
    /* execl needs the full path of the program, because it does not search. */
    execl("/bin/echo", "echo", "  child : hello from execl (full path)", (char *)NULL);
}

int main(void)
{
    printf("parent: pid %ld is starting two children.\n", (long)getpid());
    printf("parent: each child will replace itself with /bin/echo.\n\n");

    /* First child: execlp() searches PATH. */
    if (run_one("execlp(\"echo\", ...)", call_execlp) == -1) {
        return EXIT_FAILURE;
    }

    /* Second child: execl() uses the full path. */
    if (run_one("execl(\"/bin/echo\", ...)", call_execl) == -1) {
        return EXIT_FAILURE;
    }

    printf("\nparent: both children were reaped with wait().\n");
    printf("parent: notice that each child kept its own pid, but its program\n");
    printf("parent: was replaced by echo - that is what exec does.\n");
    printf("parent: if exec had failed, the child would have printed an error\n");
    printf("parent: with perror() and ended with status 127.\n");
    return 0;
}
