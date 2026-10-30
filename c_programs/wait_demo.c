/* ============================================================
 * UniShell - wait_demo.c   (Phase 7: Processes)
 * COMMAND: ./bin/wait_demo | PURPOSE: show wait vs waitpid, read child exit statuses, and observe a real zombie and a real orphan | MODULE: Shell Programming
 *
 * What this program shows:
 *   fork()      - children are created; one of them creates a child of its own
 *   exit()      - each child ends with its own status
 *   waitpid()   - the parent reaps ONE chosen child and reads its status
 *   WIFEXITED / WEXITSTATUS - decode the status value
 *   getpid() / getppid() - a process can see itself and its parent
 *   zombie      - a child that ended and has NOT been waited for yet: its
 *                 state in /proc is 'Z' until the parent reaps it
 *   orphan      - a child whose parent ended first; the system adopts it
 *
 * Every child this program creates is waited for, so nothing is left in the
 * process table when it finishes. The orphan is adopted and reaped by the
 * system, which is exactly what normally happens to an orphan.
 *
 * Build: make all
 * Run  : ./bin/wait_demo
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <unistd.h>       /* fork getpid getppid sleep usleep _exit */
#include <sys/types.h>    /* pid_t */
#include <sys/wait.h>     /* waitpid and WIFEXITED / WEXITSTATUS */

/* ------------------------------------------------------------
 * Helper 1: read the state letter of a process from /proc.
 * /proc/<pid>/stat begins with: pid (name) state ...
 * so the third item is the one-letter state. 'Z' means zombie, and the
 * file disappears completely once the process has been reaped.
 * ------------------------------------------------------------ */
static void read_proc_state(pid_t pid, char *out, size_t out_size)
{
    char path[64];
    FILE *f;
    long pid_field;
    char name[256];
    char state;

    snprintf(path, sizeof path, "/proc/%ld/stat", (long)pid);
    f = fopen(path, "r");
    if (f == NULL) {
        snprintf(out, out_size, "gone (the entry no longer exists)");
        return;
    }
    if (fscanf(f, "%ld %255s %c", &pid_field, name, &state) == 3) {
        if (state == 'Z') {
            snprintf(out, out_size, "'Z' (a zombie, also called defunct)");
        } else {
            snprintf(out, out_size, "'%c'", state);
        }
    } else {
        snprintf(out, out_size, "unreadable");
    }
    fclose(f);
}

/* ------------------------------------------------------------
 * Helper 2: ask the kernel for a process's parent pid.
 * getppid() is captured when the shell starts, so it does not change when
 * the parent dies. Reading /proc/<pid>/status shows the CURRENT parent.
 * ------------------------------------------------------------ */
static pid_t read_ppid(pid_t pid)
{
    char path[64];
    char line[256];
    FILE *f;
    long ppid = -1;

    snprintf(path, sizeof path, "/proc/%ld/status", (long)pid);
    f = fopen(path, "r");
    if (f == NULL) {
        return -1;
    }
    while (fgets(line, sizeof line, f) != NULL) {
        if (strncmp(line, "PPid:", 5) == 0) {
            sscanf(line + 5, "%ld", &ppid);
            break;
        }
    }
    fclose(f);
    return (pid_t)ppid;
}

int main(void)
{
    pid_t pids[2];
    int codes[2] = { 0, 42 };    /* the exit status each of the two children uses */
    pid_t pid;
    int status;
    int i;
    char state[64];

    printf("parent: my pid is %ld and I will start two children.\n", (long)getpid());

    /* ============================================================
     * Part 1: two children, reaped with waitpid()
     * ============================================================ */
    for (i = 0; i < 2; i++) {
        /* Flush before every fork(), so the parent's buffered text is not
         * copied into the child and printed twice. */
        fflush(stdout);
        pids[i] = fork();
        if (pids[i] < 0) {
            perror("fork");
            return EXIT_FAILURE;
        }
        if (pids[i] == 0) {
            /* Child: report itself, then end with its own status. */
            printf("child %d: pid %ld, parent %ld, will exit with %d.\n",
                   i, (long)getpid(), (long)getppid(), codes[i]);
            exit(codes[i]);
        }
    }

    printf("parent: two children are running: %ld and %ld.\n",
           (long)pids[0], (long)pids[1]);
    printf("parent: I will reap each one with waitpid(pid, ...).\n");

    /* waitpid() waits for one named child - not just any child, as wait() does. */
    for (i = 0; i < 2; i++) {
        pid_t got = waitpid(pids[i], &status, 0);
        if (got == -1) {
            perror("waitpid");
            return EXIT_FAILURE;
        }
        if (WIFEXITED(status)) {
            printf("parent: reaped pid %ld, exit status %d.\n",
                   (long)got, WEXITSTATUS(status));
        } else {
            printf("parent: pid %ld did not end normally.\n", (long)got);
        }
    }
    printf("parent: both children were reaped, so no zombies remain.\n");

    /* ============================================================
     * Part 2: a real zombie, observed and then cleaned up
     * ============================================================ */
    printf("\n--- zombie: a child that ended and has not been reaped yet ---\n");
    printf("zombie: I will start a child and deliberately NOT wait for it yet.\n");
    fflush(stdout);

    pid = fork();
    if (pid < 0) {
        perror("fork");
        return EXIT_FAILURE;
    }
    if (pid == 0) {
        /* This child ends straight away. Its parent does not reap it yet, so
         * for a short moment it stays in the process table as a zombie. */
        _exit(0);
    }

    /* Give the child time to end before we look at its process table entry. */
    usleep(200000);                                  /* 0.2 seconds */

    read_proc_state(pid, state, sizeof state);
    printf("zombie: /proc/%ld/stat says the child state is %s\n", (long)pid, state);
    printf("zombie: 'Z' means the child has ended but its exit status has not\n");
    printf("zombie: been collected. It uses no CPU and no memory of its own;\n");
    printf("zombie: only one small line stays in the process table.\n");

    if (waitpid(pid, &status, 0) == -1) {
        perror("waitpid");
        return EXIT_FAILURE;
    }
    read_proc_state(pid, state, sizeof state);
    printf("zombie: after waitpid(), /proc/%ld/stat is %s\n", (long)pid, state);
    printf("zombie: the entry is collected, so no zombie is left behind.\n");

    /* ============================================================
     * Part 3: a real orphan, created and adopted by the system
     * ============================================================ */
    printf("\n--- orphan: a child whose parent ends first ---\n");
    printf("orphan: I will start process A, and A will start process B.\n");
    printf("orphan: A then exits at once and does NOT wait for B, so B is orphaned.\n");
    fflush(stdout);

    pid = fork();                        /* process A */
    if (pid < 0) {
        perror("fork");
        return EXIT_FAILURE;
    }
    if (pid == 0) {
        pid_t b = fork();                /* process B, started by A */
        if (b < 0) {
            perror("fork");
            _exit(1);
        }
        if (b == 0) {
            /* B outlives its parent A, so the system adopts it. Reading
             * /proc/<pid>/status shows the parent it has NOW. */
            sleep(1);
            printf("orphan: process B: my pid is %ld and my parent is now %ld.\n",
                   (long)getpid(), (long)read_ppid(getpid()));
            printf("orphan: process B: %ld is not the pid that started me - when my\n",
                   (long)read_ppid(getpid()));
            printf("orphan: process B: parent ended, the system adopted me.\n");
            printf("orphan: process B: I am finishing now, so I do not stay stray.\n");
            fflush(stdout);
            _exit(0);
        }
        /* A reports and leaves immediately, without wait(): that is what
         * turns B into an orphan. */
        printf("orphan: process A (pid %ld): I am exiting now, without waiting for %ld.\n",
               (long)getpid(), (long)b);
        fflush(stdout);
        _exit(0);
    }

    /* The main process reaps A, so A itself never becomes a zombie. */
    if (waitpid(pid, &status, 0) == -1) {
        perror("waitpid");
        return EXIT_FAILURE;
    }
    printf("orphan: main: reaped process A (%ld).\n", (long)pid);
    printf("orphan: main: waiting a moment for the adopted process B to report...\n");
    fflush(stdout);
    sleep(2);

    printf("orphan: main: done. B was adopted and reaped by the system, so this\n");
    printf("orphan: main: program leaves nothing running behind it.\n");

    printf("\nZombie : a child that has ended but has NOT been waited for. It has\n");
    printf("         stopped running, but a small entry stays in the process\n");
    printf("         table until the parent calls wait() or waitpid().\n");
    printf("Orphan : a child whose parent ends first. The system then gives it a\n");
    printf("         new parent (normally the init process, sometimes another\n");
    printf("         process such as a systemd user session), which is why an\n");
    printf("         orphan keeps running instead of being left with no parent.\n");
    return 0;
}
