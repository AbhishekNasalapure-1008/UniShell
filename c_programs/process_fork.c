/* ============================================================
 * UniShell - process_fork.c   (Phase 7: Processes)
 * COMMAND: ./bin/process_fork | PURPOSE: show that fork() turns one process into two and that the parent reaps the child with wait() | MODULE: Shell Programming
 *
 * What this program shows:
 *   fork()      - a new process is created; the two processes continue
 *                 from the same line, and fork() tells them apart
 *   getpid()    - a process prints its own pid
 *   getppid()   - a process prints its parent's pid
 *   exit()      - the child ends with a status the parent can read
 *   wait()      - the parent blocks until the child has finished, which
 *                 also removes the child's entry from the process table
 *
 * Build: make all
 * Run  : ./bin/process_fork
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>

#include <unistd.h>       /* fork getpid getppid */
#include <sys/types.h>    /* pid_t */
#include <sys/wait.h>     /* wait and the macros WIFEXITED / WEXITSTATUS */

int main(void)
{
    pid_t pid;
    int status;

    printf("parent: I am running. My pid is %ld.\n", (long)getpid());
    printf("parent: I am about to call fork().\n");

    /* Flush the output buffers BEFORE fork(). When output is a pipe or a file,
     * printf keeps text in a memory buffer. fork() copies that buffer into the
     * child, so without this flush the parent's text would be printed twice.
     * This is a classic fork() trap worth remembering. */
    fflush(stdout);

    /* ---- fork() is called once but returns twice: once in the parent and
     * once in the new child. The two processes then run the same code. ---- */
    pid = fork();

    if (pid < 0) {
        /* fork failed: no child was created. */
        perror("fork");
        return EXIT_FAILURE;
    }

    if (pid == 0) {
        /* Inside the child, fork() returns 0. This branch only runs there. */
        printf("child : fork() returned 0, so I am the child.\n");
        printf("child : my pid is %ld and my parent is %ld.\n",
               (long)getpid(), (long)getppid());
        printf("child : I will call exit(7) now, so my parent can read it.\n");
        /* exit() flushes the output buffers before the process ends. */
        exit(7);
    }

    /* Inside the parent, fork() returns the child's pid (a number > 0). */
    printf("parent: fork() returned %ld, which is my child's pid.\n", (long)pid);
    printf("parent: I will now call wait() and block until the child ends.\n");

    /* ---- wait() waits for one child and fills in its exit status. ---- */
    if (wait(&status) == -1) {
        perror("wait");
        return EXIT_FAILURE;
    }

    /* WIFEXITED says the child ended by itself; WEXITSTATUS reads its code. */
    if (WIFEXITED(status)) {
        printf("parent: child ended normally with exit status %d.\n",
               WEXITSTATUS(status));
    } else {
        printf("parent: child did not end normally.\n");
    }

    printf("parent: because I waited, the child was reaped.\n");
    printf("parent: a child that ends without being waited for stays in the\n");
    printf("parent: process table as a zombie; wait() removes that entry.\n");
    return 0;
}
