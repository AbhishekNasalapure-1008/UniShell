/* ============================================================
 * UniShell - file_io.c   (Phase 7: File and directory system calls)
 * COMMAND: ./bin/file_io <working-directory> | PURPOSE: demonstrate the file system calls open, write, read, close, creat, mkdir, chdir, getcwd and rmdir | MODULE: Unix Basics
 *
 * What this program shows:
 *   open(), write(), read(), close(), creat()  - the file calls
 *   mkdir(), chdir(), getcwd(), rmdir()        - the directory calls
 *   unlink()                                    - used at the end to clean up
 *
 * Safety: it only ever works inside the directory given on the command line.
 * UniShell passes a path inside ./sandbox, and the program deletes what it
 * created before it exits, so nothing is left behind.
 *
 * Build: make all
 * Run  : ./bin/file_io sandbox/file_io_demo
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

/* The system calls live in these headers. */
#include <unistd.h>       /* read write close unlink chdir getcwd rmdir */
#include <fcntl.h>        /* open and creat, plus O_RDONLY and O_APPEND */
#include <sys/stat.h>     /* mkdir and the mode bits such as 0755 */
#include <sys/types.h>    /* ssize_t, mode_t and other system types */

/* ------------------------------------------------------------
 * Helper 1: report a failed system call and stop.
 * perror() prints the message we choose, then the system's own reason
 * (for example "Permission denied"), using the value already in errno.
 * ------------------------------------------------------------ */
static void die(const char *what)
{
    /* Flush our buffered output first, so the error appears in the right
     * place instead of jumping ahead of text still waiting in the buffer. */
    fflush(stdout);
    perror(what);
    exit(EXIT_FAILURE);
}

/* ------------------------------------------------------------
 * Helper 2: write every byte, even when write() writes only part of it.
 * write() is allowed to write fewer bytes than requested. Ignoring that
 * would silently lose data, so we loop until the whole text is written.
 * ------------------------------------------------------------ */
static int write_all(int fd, const char *text)
{
    size_t total = strlen(text);
    size_t done = 0;

    while (done < total) {
        ssize_t n = write(fd, text + done, total - done);
        if (n < 0) {
            if (errno == EINTR) {
                continue;          /* the call was interrupted: try again */
            }
            return -1;
        }
        done += (size_t)n;
    }
    return 0;
}

/* make_absolute - turn the argument into a full path.
 * This matters because the program changes directory, and a relative path
 * would then point somewhere else. */
static int make_absolute(const char *path, char *out, size_t out_size)
{
    char here[4096];

    if (path[0] == '/') {                       /* already absolute */
        if (strlen(path) + 1 > out_size) {
            return -1;
        }
        strcpy(out, path);
        return 0;
    }
    if (getcwd(here, sizeof here) == NULL) {    /* join with the current dir */
        return -1;
    }
    if (strlen(here) + 1 + strlen(path) + 1 > out_size) {
        return -1;
    }
    snprintf(out, out_size, "%s/%s", here, path);
    return 0;
}

int main(int argc, char **argv)
{
    char base[4096];
    char cwd[4096];
    char buf[128];
    const char *line1 = "Hello from file_io.c\n";
    const char *line2 = "Second line, written with O_APPEND.\n";
    ssize_t n;
    int fd, lines = 0, bytes = 0;

    /* Exactly one argument: the working directory. No argument is an error,
     * because the program must not guess where to write. */
    if (argc != 2) {
        fprintf(stderr, "usage: %s <working-directory>\n", argv[0]);
        return 2;
    }

    if (getcwd(cwd, sizeof cwd) == NULL) {
        die("getcwd");
    }
    printf(" 1. getcwd()  -> started in %s\n", cwd);

    /* Work out the full path of the working directory once, so the path stays
     * correct even after chdir() moves us somewhere else. */
    if (make_absolute(argv[1], base, sizeof base) == -1) {
        fprintf(stderr, "path is too long: %s\n", argv[1]);
        return 2;
    }

    /* ---- mkdir(): create the working directory. EEXIST just means it is
     * already there, which is not a real failure for this demo. ---- */
    if (mkdir(base, 0755) == -1 && errno != EEXIST) {
        die("mkdir");
    }
    printf(" 2. mkdir()   -> ready: %s\n", base);

    /* ---- chdir(): move into it, so later names can be simple. ---- */
    if (chdir(base) == -1) {
        die("chdir");
    }
    if (getcwd(cwd, sizeof cwd) == NULL) {
        die("getcwd");
    }
    printf(" 3. chdir()   -> now inside %s\n", cwd);

    /* ---- creat(): create a file and open it for writing in one step. ---- */
    fd = creat("hello.txt", 0644);
    if (fd == -1) {
        die("creat");
    }
    printf(" 4. creat()   -> hello.txt created, file descriptor %d\n", fd);

    /* ---- write(): send the first line to that descriptor. ---- */
    if (write_all(fd, line1) == -1) {
        die("write");
    }
    /* ---- close(): every opened descriptor must be closed. ---- */
    if (close(fd) == -1) {
        die("close");
    }
    printf(" 5. write()   -> wrote one line, then close() released fd %d\n", fd);

    /* ---- open(): open the file again, this time for reading. ---- */
    fd = open("hello.txt", O_RDONLY);
    if (fd == -1) {
        die("open");
    }
    printf(" 6. open()    -> reading hello.txt back:\n");
    /* print uses a buffer, but write() below does not. Flush first so the text
     * above is printed before the file contents, in the order written. */
    fflush(stdout);
    while ((n = read(fd, buf, sizeof buf)) > 0) {
        if (write_all(STDOUT_FILENO, buf) == -1) {
            die("write to stdout");
        }
    }
    if (n < 0) {                    /* n < 0 is a real read error */
        die("read");
    }
    if (close(fd) == -1) {
        die("close");
    }

    /* ---- open() again, with O_APPEND, to add a line at the end. ---- */
    fd = open("hello.txt", O_WRONLY | O_APPEND);
    if (fd == -1) {
        die("open (append)");
    }
    if (write_all(fd, line2) == -1) {
        die("write (append)");
    }
    if (close(fd) == -1) {
        die("close");
    }
    printf(" 7. O_APPEND  -> added a second line without erasing the first\n");

    /* ---- read(): measure the file by counting bytes and newlines. ---- */
    fd = open("hello.txt", O_RDONLY);
    if (fd == -1) {
        die("open (count)");
    }
    while ((n = read(fd, buf, sizeof buf)) > 0) {
        ssize_t i;
        for (i = 0; i < n; i++) {
            if (buf[i] == '\n') {
                lines++;
            }
        }
        bytes += (int)n;
    }
    if (n < 0) {
        die("read");
    }
    if (close(fd) == -1) {
        die("close");
    }
    printf(" 8. read()    -> hello.txt holds %d lines and %d bytes\n", lines, bytes);

    /* ---- mkdir() and rmdir(): make and remove a directory. ---- */
    if (mkdir("subdir", 0755) == -1 && errno != EEXIST) {
        die("mkdir subdir");
    }
    printf(" 9. mkdir()   -> created the directory subdir\n");
    if (rmdir("subdir") == -1) {       /* rmdir only removes an EMPTY directory */
        die("rmdir");
    }
    printf("    rmdir()   -> removed the empty directory subdir\n");

    /* ---- clean up, so a second run starts from a clean state. ---- */
    if (unlink("hello.txt") == -1) {
        die("unlink");
    }
    printf("10. unlink()  -> removed hello.txt\n");
    if (chdir("..") == -1) {
        die("chdir ..");
    }
    if (rmdir(base) == -1) {           /* base is absolute, so it still resolves */
        die("rmdir (working directory)");
    }
    printf("11. cleanup   -> removed %s\n", base);

    printf("\nAll file and directory system calls returned success.\n");
    printf("Nothing was left behind: the working directory is gone again.\n");
    return 0;
}
