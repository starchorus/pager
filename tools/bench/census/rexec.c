/* SPDX-License-Identifier: GPL-3.0-or-later
 *
 * rexec.c -- a census shim: counts the processes a script starts and what each costs. Dev machine only; needs a C compiler (cc); nothing in
 * the gates compiles it (tools/bench is not part of any gate).
 *
 * Installed under the names of the commands a script runs (run-census.py links it so, in a directory in front of PATH). It runs the real
 * program, found in $REXEC_REAL_PATH (default /usr/bin:/bin:/usr/sbin:/sbin), waits for it and appends one line to $REXEC_LOG:
 *     name TAB user_us TAB sys_us TAB wall_us TAB maxrss TAB argv1 (the first 40 characters, tabs and newlines turned into blanks)
 * The name is the one the shim was called by, or $REXEC_NAME where that is set. The exit status is the real program's. Stdin, stdout and stderr
 * pass through untouched. The numbers come from wait4's rusage: the CPU of the program and its own children, which is what a `time` of the
 * command would show. Counts of lines are deterministic; the microseconds are noise (same-run comparisons only).
 *
 * build: cc -O1 -o rexec rexec.c
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <errno.h>
#include <libgen.h>

static int find_real(const char *name, const char *self, char *out, size_t n) {
    const char *p = getenv("REXEC_REAL_PATH");
    if (!p) p = "/usr/bin:/bin:/usr/sbin:/sbin";
    char *d = strdup(p), *s = d, *tok;
    while ((tok = strsep(&s, ":"))) {
        snprintf(out, n, "%s/%s", tok, name);
        if (access(out, X_OK) == 0 && strcmp(out, self) != 0) { free(d); return 0; }
    }
    free(d);
    return -1;
}

int main(int argc, char **argv) {
    const char *nm = getenv("REXEC_NAME");
    char *base = nm ? (char *)nm : basename(argv[0]);
    char real[1024];
    if (find_real(base, argv[0], real, sizeof real)) { fprintf(stderr, "rexec: %s: not found\n", base); return 127; }
    struct timeval t0, t1;
    gettimeofday(&t0, NULL);
    pid_t pid = fork();
    if (pid == 0) { execv(real, argv); _exit(127); }
    int st = 0;
    struct rusage ru;
    wait4(pid, &st, 0, &ru);
    gettimeofday(&t1, NULL);
    const char *log = getenv("REXEC_LOG");
    if (log) {
        char line[512];
        long wall = (t1.tv_sec - t0.tv_sec) * 1000000L + (t1.tv_usec - t0.tv_usec);
        char a1[48] = "";
        if (argc > 1) {
            strncpy(a1, argv[1], 40);
            a1[40] = 0;
            for (char *c = a1; *c; c++) if (*c == '\t' || *c == '\n') *c = ' ';
        }
        int n = snprintf(line, sizeof line, "%s\t%ld\t%ld\t%ld\t%ld\t%s\n", base,
            ru.ru_utime.tv_sec * 1000000L + ru.ru_utime.tv_usec, ru.ru_stime.tv_sec * 1000000L + ru.ru_stime.tv_usec, wall, ru.ru_maxrss, a1);
        int fd = open(log, O_WRONLY | O_APPEND | O_CREAT, 0644);
        if (fd >= 0) { if (write(fd, line, n) < 0) { /* the census loses a line, nothing else */ } close(fd); }
    }
    if (WIFEXITED(st)) return WEXITSTATUS(st);
    if (WIFSIGNALED(st)) return 128 + WTERMSIG(st);
    return 1;
}
