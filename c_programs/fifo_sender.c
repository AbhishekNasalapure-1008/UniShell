/* ============================================================
 * UniShell - fifo_sender.c   (Phase 8: Inter-Process Communication)
 * COMMAND: ./bin/fifo_sender <fifo-path> <message words...> | PURPOSE: open a named pipe for writing and send one message to whoever is reading it | MODULE: Inter-Process Communication
 *
 * This is the sending half of the FIFO demonstration. It pairs with
 * bin/fifo_receiver, which creates the FIFO, reads from it and removes it.
 *
 * What this program shows:
 *   stat()   - confirm the path really is a FIFO before opening it
 *   open()   - open the write end
 *   write()  - send the message, in a loop, because write() may accept
 *              fewer bytes than asked
 *   close()  - release the descriptor when the message has been sent
 *
 * Why O_NONBLOCK and a retry loop: opening a FIFO for writing normally BLOCKS
 * until a reader appears. With O_NONBLOCK the open returns at once, and if
 * there is still no reader the kernel answers ENXIO ("no such device or
 * address"). This program retries for a few seconds and then gives up, so it
 * can never sit there for ever when nobody is reading.
 *
 * Safety: it only ever opens the path given on the command line, and UniShell
 * always passes a path inside ./sandbox. It creates nothing, deletes nothing
 * and sends no signal - the receiver owns the FIFO and removes it at the end.
 *
 * Build: make all
 * Run  : ./bin/fifo_sender sandbox/demo.fifo hello from the sender
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include <unistd.h>       /* open close write */
#include <fcntl.h>        /* open, O_WRONLY, O_NONBLOCK */
#include <time.h>         /* nanosleep and struct timespec */
#include <sys/stat.h>     /* stat and S_ISFIFO */
#include <sys/types.h>

#define MAX_MESSAGE   512
#define WAIT_SECONDS  5           /* how long to look for a reader */

static void die(const char *what)
{
    fflush(stdout);
    perror(what);
    exit(EXIT_FAILURE);
}

/* sleep_ms - wait a short while without a busy spin. */
static void sleep_ms(long ms)
{
    struct timespec ts;
    ts.tv_sec  = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000L;
    nanosleep(&ts, NULL);
}

int main(int argc, char **argv)
{
    const char *path;
    char message[MAX_MESSAGE];
    size_t len = 0, sent = 0;
    int i, fd = -1, tries;
    struct stat st;
    ssize_t n;

    if (argc < 3) {
        fprintf(stderr, "usage: %s <fifo-path> <message words...>\n", argv[0]);
        return 2;
    }
    path = argv[1];

    /* ---- join every word after the path into one message ---- */
    for (i = 2; i < argc; i++) {
        size_t word = strlen(argv[i]);
        if (len + word + 2 > sizeof message) {
            fprintf(stderr, "message is too long (maximum %lu bytes)\n",
                    (unsigned long)(sizeof message - 2));
            return 2;
        }
        if (i > 2) {
            message[len++] = ' ';
        }
        memcpy(message + len, argv[i], word);
        len += word;
    }
    message[len++] = '\n';        /* end the line so the receiver prints tidily */
    message[len]   = '\0';

    printf("fifo_sender: pid %ld\n", (long)getpid());

    /* ---- stat(): make sure the path is a FIFO and not some other file. ---- */
    if (stat(path, &st) == -1) {
        fprintf(stderr, "cannot use %s: no FIFO there yet\n", path);
        fprintf(stderr, "start bin/fifo_receiver on that path first.\n");
        return 2;
    }
    if (!S_ISFIFO(st.st_mode)) {
        fprintf(stderr, "%s exists but is not a FIFO\n", path);
        return 2;
    }
    printf(" 1. stat()    -> %s is a FIFO, so it is safe to open for writing\n", path);

    /* ---- open(): O_NONBLOCK so a missing reader cannot block us. ---- */
    tries = WAIT_SECONDS * 10;
    while (tries-- > 0) {
        fd = open(path, O_WRONLY | O_NONBLOCK);
        if (fd != -1) {
            break;
        }
        if (errno != ENXIO) {
            die("open");          /* a real error, not just "no reader yet" */
        }
        sleep_ms(100);            /* nobody reading yet: wait and try again */
    }
    if (fd == -1) {
        fprintf(stderr, "no reader appeared within %d seconds, so nothing was sent\n",
                WAIT_SECONDS);
        return 5;
    }
    printf(" 2. open()    -> writing end is fd %d, opened without blocking\n", fd);

    /* ---- write(): send every byte, retrying on a partial write. ---- */
    while (sent < len) {
        n = write(fd, message + sent, len - sent);
        if (n == -1) {
            if (errno == EINTR) {
                continue;             /* interrupted by a signal: just retry */
            }
            if (errno == EAGAIN) {
                sleep_ms(10);         /* pipe buffer full for now: wait a moment */
                continue;
            }
            die("write");
        }
        sent += (size_t)n;
    }
    printf(" 3. write()   -> sent %lu byte(s)\n", (unsigned long)sent);

    if (close(fd) == -1) {
        die("close");
    }
    printf(" 4. close()   -> released fd %d, so the reader will see end of file\n", fd);

    printf("\nMessage delivered: %s", message);
    printf("The receiver owns the FIFO and removes it when it has read this.\n");
    return 0;
}
