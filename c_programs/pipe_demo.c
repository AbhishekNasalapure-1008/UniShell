/* ============================================================
 * UniShell - pipe_demo.c   (Phase 8: Inter-Process Communication)
 * COMMAND: ./bin/pipe_demo | PURPOSE: create an unnamed pipe with pipe(), fork a child that writes into it, and have the parent read the bytes back | MODULE: Inter-Process Communication
 *
 * What this program shows:
 *   pipe()    - create a pipe and get two file descriptors: one to read
 *               from and one to write to
 *   fork()    - make a child so that two processes can use the pipe
 *   write()   - the child sends bytes into the write end
 *   read()    - the parent pulls bytes out of the read end
 *   close()   - close the ends that are not used, so read() can see EOF
 *   waitpid() - reap the child so no zombie is left behind
 *
 * Why a pipe works: the kernel keeps a small buffer between the two
 * descriptors. A read() on an empty pipe waits until a write() puts bytes in,
 * and a read() returns 0 (end of file) when every write end has been closed.
 *
 * Safety: this program only talks to the child it created itself with fork().
 * It never signals or stops any other process, and it creates no files.
 *
 * Build: make all
 * Run  : ./bin/pipe_demo
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include <unistd.h>       /* pipe read write close fork */
#include <sys/types.h>    /* pid_t */
#include <sys/wait.h>     /* waitpid and the WIFEXITED / WEXITSTATUS macros */

/* Report a failed call and stop. perror() adds the system's own reason. */
static void die(const char *what)
{
    fflush(stdout);
    perror(what);
    exit(EXIT_FAILURE);
}

int main(void)
{
    int fds[2];              /* fds[0] = read end, fds[1] = write end */
    pid_t pid;
    int status;
    char buf[128];
    ssize_t got;
    size_t total = 0;
    const char *message = "hello through the pipe";

    printf("pipe_demo: an unnamed pipe carries bytes in one direction.\n\n");

    /* ---- pipe(): the kernel fills in two file descriptors. ---- */
    if (pipe(fds) == -1) {
        die("pipe");
    }
    printf(" 1. pipe()   -> read end is fd %d, write end is fd %d\n", fds[0], fds[1]);

    /* Flush the output buffers before fork(), so the parent's text is not
     * copied into the child and printed twice. */
    fflush(stdout);

    pid = fork();
    if (pid == -1) {
        die("fork");
    }

    if (pid == 0) {
        /* ---------- child: writes only ---------- */
        /* Close the read end: this process does not need it, and keeping it
         * open would stop the parent from ever seeing end of file. */
        if (close(fds[0]) == -1) {
            die("child close read end");
        }
        printf(" 2. child    : closed fd %d (the read end it does not use)\n", fds[0]);

        if (write(fds[1], message, strlen(message)) == -1) {
            die("child write");
        }
        printf(" 3. child    : wrote %lu bytes: %s\n",
               (unsigned long)strlen(message), message);

        if (close(fds[1]) == -1) {
            die("child close write end");
        }
        printf(" 4. child    : closed fd %d, which tells the parent it is the end\n",
               fds[1]);

        /* Flush our own output, then leave with _exit() so we do not run any
         * of the parent's pending cleanup. */
        fflush(stdout);
        _exit(0);
    }

    /* ---------- parent: reads only ---------- */
    /* Close the write end. If the parent kept it open, the following read()
     * would block for ever, because the pipe would still have a writer. */
    if (close(fds[1]) == -1) {
        die("parent close write end");
    }
    printf(" 5. parent   : closed fd %d (the write end it does not use)\n", fds[1]);

    /* Read until the pipe returns 0, which means the child closed its end. */
    buf[0] = '\0';
    while ((got = read(fds[0], buf + total, sizeof buf - 1 - total)) > 0) {
        total += (size_t)got;
        if (total >= sizeof buf - 1) {
            break;
        }
    }
    if (got == -1) {
        die("parent read");
    }
    buf[total] = '\0';
    printf(" 6. parent   : read() returned the text: \"%s\"\n", buf);

    if (close(fds[0]) == -1) {
        die("parent close read end");
    }
    printf(" 7. parent   : close() released the read end fd %d\n", fds[0]);

    /* ---- waitpid(): collect the child's exit status so nothing is left. ---- */
    if (waitpid(pid, &status, 0) == -1) {
        die("waitpid");
    }
    if (WIFEXITED(status)) {
        printf(" 8. parent   : reaped child pid %ld, exit status %d\n",
               (long)pid, WEXITSTATUS(status));
    } else {
        printf(" 8. parent   : child pid %ld was stopped by a signal\n", (long)pid);
    }

    printf("\nThe parent and the child were the only two processes involved.\n");
    printf("When the last descriptor was closed, the kernel threw the pipe away.\n");
    printf("A pipe holds no name, so no other program on the system can find it.\n");
    return 0;
}
