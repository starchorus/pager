#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
run-census.py -- how many processes does one cycle of the collector start, and what do they cost?

WHAT IT MEASURES: the collector (a COPY of starchorus-collect.sh) runs as a daemon for SECONDS seconds on the recon.db source against a
synthetic, device-scale recon.db (gen-recon.py) and a synthetic OUI file (gen-oui.py). Every external command it starts goes through rexec
(rexec.c), which logs the command, its CPU and its wall time. seg.py turns the log into one line per cycle. In `full` mode a new row is inserted
into the copy of the database every second, so every cycle is a full pass; in `skip` mode nothing changes and the collector skips the
unchanged cycles. The first segment is the start-up, the second the first full pass.
HOW TO RUN:  python3 -B -I tools/bench/census/run-census.py OUTDIR [SECONDS=20] [full|skip] [VENDOR=1]
             python3 -B -I tools/bench/census/seg.py OUTDIR/log.tsv           (all segments)
  Needs a C compiler (cc), python3, the sqlite3 command and the POSIX tools; macOS or Linux. No device, no network, no radio: the collector reads
  the database copy and writes under OUTDIR/out; STARCHORUS_BLUETOOTH and STARCHORUS_TRAFFIC are 0. A command that is missing from REXEC_REAL_PATH
  (default /usr/bin:/bin:/usr/sbin:/sbin; set it to change) gets no shim, so the collector sees it as absent, as it would on a box without it.
  The collector is taken from the repository this file sits in unless COLLECT=PATH names another file (it is copied, never run in place).
WRITES ONLY under OUTDIR: rexec, bin/ (the shims), work/ (the collector copy), recon.db, oui.txt, out/, tmp/, alerts/, log.tsv, collect.out, collect.err,
  rq.PID.sql (the SQL batches the collector gave sqlite3, for bench-sql.py).
DETERMINISTIC: the number of processes per cycle and their names (for one collector and one set of settings). NOISE: every microsecond figure
(a few ten percent on a shared machine); compare only within one run. Not part of any gate.
"""
import glob
import os
import shutil
import stat
import subprocess
import sys
import time

if len(sys.argv) < 2 or len(sys.argv) > 5:
    sys.exit(__doc__)
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
C = os.path.abspath(sys.argv[1])
N = int(sys.argv[2]) if len(sys.argv) > 2 else 20
MODE = sys.argv[3] if len(sys.argv) > 3 else "full"
VEND = sys.argv[4] if len(sys.argv) > 4 else "1"
if MODE not in ("full", "skip"):
    sys.exit(__doc__)
SRC = os.environ.get("COLLECT") or os.path.join(REPO, "starchorus-collect.sh")
if not os.path.isfile(SRC):
    sys.exit("run-census: no collector at %s" % SRC)
cc = shutil.which("cc")
if not cc:
    sys.exit("run-census: needs a C compiler (cc) for rexec.c")
REAL = os.environ.get("REXEC_REAL_PATH") or "/usr/bin:/bin:/usr/sbin:/sbin"

os.makedirs(C, exist_ok=True)
for d in ("out", "tmp", "alerts", "bin", "work"):
    shutil.rmtree(os.path.join(C, d), ignore_errors=True)
    os.makedirs(os.path.join(C, d))
for f in glob.glob(os.path.join(C, "rq.*.sql")) + [os.path.join(C, "log.tsv")]:
    if os.path.exists(f):
        os.remove(f)
subprocess.run([cc, "-O1", "-o", os.path.join(C, "rexec"), os.path.join(HERE, "rexec.c")], check=True)


def which_in(name, path):
    for d in path.split(":"):
        p = os.path.join(d, name)
        if os.access(p, os.X_OK) and os.path.isfile(p):
            return p
    return None


# one link per command the collector may run; a command the real path lacks gets none
for c in ("awk basename cat chmod cmp cp cut date dd df dirname expr false find grep head id jq ln ls mkdir mktemp mv nice od printf ps readlink rm "
          "sed seq sleep sort sqlite3 stat tail tee test timeout touch tr true uname uniq wc xargs").split():
    if which_in(c, REAL):
        os.symlink(os.path.join(C, "rexec"), os.path.join(C, "bin", c))
# the SQL batch of a cycle comes on sqlite3's standard input: keep a copy of each batch (rq.PID.sql), then pass it on to the real program through
# its shim. The copy is made with the real tee, by its full path, so that the census counts no process the collector did not start.
tee = which_in("tee", REAL)
shim = os.path.join(C, "bin", "sqlite3")
if os.path.islink(shim) and tee:
    os.remove(shim)
    with open(shim, "w") as f:
        f.write('#!/bin/sh\nif [ -t 0 ]; then REXEC_NAME=sqlite3 exec "%s/rexec" "$@"; fi\n%s "%s/rq.$$.sql" | REXEC_NAME=sqlite3 "%s/rexec" "$@"\n' % (C, tee, C, C))
    os.chmod(shim, os.stat(shim).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
work = os.path.join(C, "work", "starchorus-collect.sh")
shutil.copy(SRC, work)
now = str(int(time.time()))
subprocess.run([sys.executable, "-B", "-I", os.path.join(HERE, "gen-recon.py"), os.path.join(C, "recon.db"), now], check=True, stdout=subprocess.DEVNULL)
subprocess.run([sys.executable, "-B", "-I", os.path.join(HERE, "gen-oui.py"), os.path.join(C, "oui.txt")], check=True, stdout=subprocess.DEVNULL)
env = dict(os.environ, REXEC_LOG=os.path.join(C, "log.tsv"), REXEC_REAL_PATH=REAL, PATH=os.path.join(C, "bin") + ":" + REAL,
           STARCHORUS_OUTDIR=os.path.join(C, "out"), STARCHORUS_RECON_DB=os.path.join(C, "recon.db"), STARCHORUS_SOURCE="recondb",
           STARCHORUS_MAX_AGE="3600", STARCHORUS_INTERVAL="2", STARCHORUS_VENDOR=VEND, STARCHORUS_OUI_FILE=os.path.join(C, "oui.txt"),
           STARCHORUS_TMPDIR=os.path.join(C, "tmp"), STARCHORUS_ALERT_DIR=os.path.join(C, "alerts"), STARCHORUS_BLUETOOTH="0", STARCHORUS_TRAFFIC="0")
real_sqlite3 = which_in("sqlite3", REAL)
with open(os.path.join(C, "collect.out"), "w") as so, open(os.path.join(C, "collect.err"), "w") as se:
    proc = subprocess.Popen(["sh", work], env=env, stdout=so, stderr=se)
    try:
        for i in range(N):
            time.sleep(1)
            if MODE == "full" and real_sqlite3:
                subprocess.run([real_sqlite3, os.path.join(C, "recon.db"),
                                "insert into ssid values (%d,100000,1,4,'FFFFFFFFFFFF','Fixture-Probe-0001',0,%d,-60,0,0,0);" % (9000000 + i, int(time.time()))],
                               stderr=subprocess.DEVNULL)
    finally:
        proc.terminate()
        try:
            proc.wait(15)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
log = os.path.join(C, "log.tsv")
lines = open(log).read().splitlines() if os.path.exists(log) else []
print("run-census: %d processes logged, %d of them sleeps, %d SQL batches kept; log: %s" % (
    len(lines), sum(1 for ln in lines if ln.startswith("sleep\t")), len(glob.glob(os.path.join(C, "rq.*.sql"))), log))
