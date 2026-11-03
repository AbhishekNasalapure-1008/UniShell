/* ============================================================
 * UniShell - fifo_receiver.c   (Phase 8: Inter-Process Communication)
 * COMMAND: ./bin/fifo_receiver <fifo-path> [timeout-seconds] | PURPOSE: create a named pipe with mkfifo(), open it for reading, and collect the messages a sender writes into it | MODULE: Inter-Process Communication
 *
 * A named pipe (FIFO) is a pipe that has a name in the file system, so two
 * programs that were NOT started from each other can still talk through it.
 *
 * What this program shows:
 *   mkfifo() - create the FIFO on disk
 *   open()   - open the read end
 *   poll()   - wait for data with a timeout, so the program can never hang
 *   read()   - collect the bytes; 0 means every writer has closed
 *   close()  - release the descriptor
 *   unlink() - remove the FIFO again, so nothing is left behind
 *
 * Why O_NONBLOCK and poll(): opening a FIFO for reading normally blocks until a
 * writer appears. With O_NONBLOCK the open returns at once and poll() waits for
 * data with a deadline, so this program always ends even if no sender shows up.
 *
 * Safety: it only creates and removes the FIFO path given on the command line.
 * UniShell passes a path inside ./sandbox. No other process is ever signalled.
 *
 * Build: make all
 * Run  : ./bin/fifo_receiver sandbox/demo.fifo 3
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include <unistd.h>       /* read close unlink */
#include <fcntl.h>        /* open, O_RDONLY, O_NONBLOCK */
#include <poll.h>         /* poll and struct pollfd */
#include <sys/stat.h>     /* mkfifo, stat */
#include <sys/types.h>    /* mode_t */

#define MAX_MESSAGE 256

static void die(const char *what)
{
    fflush(stdout);
    perror(what);
    exit(EXIT_FAILURE);
}

/* create_fifo - make the FIFO, accepting one that is already there. */
static void create_fifo(const char *path)
{
    struct stat st;

    if (mkfifo(path, 0600) == -1) {
        if (errno != EEXIST) {
            die("mkfifo");
        }
        /* It already exists: make sure it really is a FIFO and not, say, a
         * regular file we would then open by mistake. */
        if (stat(path, &st) == -1) {
            die("stat");
        }
        if (!S_ISFIFO(st.st_mode)) {
            fprintf(stderr, "%s exists but is not a FIFO\n", path);
            exit(2);
        }
    }
}

int main(int argc, char **argv)
{
    const char *path;
    int timeout_sec = 3;
    int fd, slices, rc = 0;
    char buf[MAX_MESSAGE];

    if (argc < 2 || argc > 3) {
        fprintf(stderr, "usage: %s <fifo-path> [timeout-seconds]\n", argv[0]);
        return 2;
    }
    path = argv[1];
    if (argc == 3) {
        timeout_sec = atoi(argv[2]);
        if (timeout_sec <= 0 || timeout_sec > 60) {
            fprintf(stderr, "timeout must be between 1 and 60 seconds\n");
            return 2;
        }
    }

    printf("fifo_receiver: pid %ld\n", (long)getpid());

    /* ---- mkfifo(): give the pipe a name in the file system. ---- */
    create_fifo(path);
    printf(" 1. mkfifo()  -> the FIFO now exists at %s\n", path);

    /* ---- open(): O_RDONLY would block until a writer appeared. O_NONBLOCK
     * returns immediately, and poll() below will do the waiting. ---- */
    fd = open(path, O_RDONLY | O_NONBLOCK);
    if (fd == -1) {
        die("open");
    }
    printf(" 2. open()    -> reading end is fd %d, opened without blocking\n", fd);

    /* poll() in 100 ms slices gives poll() a deadline for the whole wait. */
    slices = timeout_sec * 10;
    printf(" 3. poll()    -> waiting up to %d second(s) for a sender...\n", timeout_sec);

    /* Send everything printed so far on its way before we start waiting.
     * Without this, output redirected to a file would sit in a buffer until
     * the program ended, and anyone watching the file would not know the
     * receiver was ready. */
    fflush(stdout);

    while (slices > 0) {
        struct pollfd pfd;
        int ready;
        ssize_t n;

        pfd.fd = fd;
        pfd.events = POLLIN;
        pfd.revents = 0;

        ready = poll(&pfd, 1, 100);
        if (ready == -1) {
            if (errno == EINTR) {
                continue;               /* interrupted by a signal: just retry */
            }
            die("poll");
        }
        if (ready == 0) {
            slices--;                   /* nothing yet: one slice has passed */
            continue;
        }

        /* Data is ready, or every writer has closed its end. */
        n = read(fd, buf, sizeof buf - 1);
        if (n == -1) {
            if (errno == EAGAIN) {
                continue;               /* nothing after all: keep waiting */
            }
            die("read");
        }
        if (n == 0) {                   /* 0 bytes means end of file */
            printf(" 4. read()    -> returned 0, so every writer has closed\n");
            break;
        }
        buf[n] = '\0';
        printf(" 4. read()    -> received %ld byte(s): %s\n", (long)n, buf);
    }

    if (slices == 0) {
        printf(" 4. read()    -> no sender appeared within %d second(s)\n",
               timeout_sec);
        rc = 3;                         /* honest, non-zero: nothing was sent */
    }

    if (close(fd) == -1) {
        die("close");
    }
    printf(" 5. close()   -> released the reading end fd %d\n", fd);

    /* ---- unlink(): remove the FIFO, so no trace is left behind. ---- */
    if (unlink(path) == -1) {
        die("unlink");
    }
    printf(" 6. unlink()  -> removed the FIFO %s\n", path);

    printf("\nfifo_receiver finished with status %d.\n", rc);
    return rc;
}
