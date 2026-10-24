#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
bench-sql.py -- the collector's SQL batch as it is, against a variant that scans the ssid table once (the lever of one scan of `ssid` into a temporary table).

WHAT IT MEASURES: the child CPU of one `sqlite3 -readonly` run over the batch the collector sends each cycle (taken from the batches
run-census.py kept, the largest one, less the two alternatives a database with a `time` column does not use), and over a variant in which
the queries over a one-hour window read a temporary table made by one scan (`CREATE TEMP TABLE rwin ...`) instead of ssid. It also says whether
the two give identical output (they must: that is the point of the variant).
HOW TO RUN:  python3 -B -I tools/bench/census/run-census.py OUTDIR 6 full          (makes OUTDIR/recon.db and OUTDIR/rq.PID.sql)
             python3 -B -I tools/bench/census/bench-sql.py OUTDIR [N=60]
  Needs python3 and the sqlite3 command line (/usr/bin/sqlite3 or the first on PATH). No device, no network.
WRITES ONLY under OUTDIR: rq_base.sql and rq_one.sql (the two batches that were timed). The database is opened read-only.
DETERMINISTIC: the line "outputs identical: True", the byte counts. NOISE: the milliseconds (median of N runs, plus the minimum; about +-5 percent
on a quiet machine, more on a shared one: compare the two rows of one run, never two runs). Not part of any gate.
"""
import glob
import os
import re
import resource
import shutil
import subprocess
import sys
import time

if len(sys.argv) < 2:
    sys.exit(__doc__)
out_dir = sys.argv[1]
N = int(sys.argv[2]) if len(sys.argv) > 2 else 60
batches = sorted(glob.glob(os.path.join(out_dir, "rq.*.sql")), key=os.path.getsize, reverse=True)
if not batches:
    sys.exit("bench-sql: no rq.*.sql in %s (run census/run-census.py first)" % out_dir)
db = os.path.join(out_dir, "recon.db")
sqlite3 = shutil.which("sqlite3")
if not sqlite3 or not os.path.exists(db):
    sys.exit("bench-sql: needs the sqlite3 command and %s" % db)
sql = open(batches[0]).read()
parts = re.split(r"(?m)^SELECT '#STARCHORUS_([A-Z]+[0-9]*)#';\n", sql)
head = parts[0]
groups = list(zip(parts[1::2], parts[2::2]))
steady = [(g, s) for g, s in groups if g not in ("APS2", "CLI2")]           # HAS_TIME=1 is learnt after the first batch


def batch(gl):
    return head + "".join("SELECT '#STARCHORUS_%s#';\n%s" % (g, s) for g, s in gl)


base = batch(steady)
cut = re.search(r"time > (\d+)", sql).group(1)
var = []
for g, s in steady:
    if g in ("APS1", "CLI1", "PRB1", "RESP1", "WMIN"):
        s = s.replace("FROM ssid", "FROM rwin")
    var.append((g, s))
one = head + "CREATE TEMP TABLE rwin AS SELECT * FROM ssid WHERE time > %s AND type IN (4,5,8);\n" % cut + "".join("SELECT '#STARCHORUS_%s#';\n%s" % (g, s) for g, s in var)
open(os.path.join(out_dir, "rq_base.sql"), "w").write(base)
open(os.path.join(out_dir, "rq_one.sql"), "w").write(one)


def run(text):
    r0 = resource.getrusage(resource.RUSAGE_CHILDREN)
    t0 = time.time()
    out = subprocess.run([sqlite3, "-readonly", "-noheader", "-separator", "\t", db], input=text, capture_output=True, text=True).stdout
    r1 = resource.getrusage(resource.RUSAGE_CHILDREN)
    return out, (r1.ru_utime - r0.ru_utime) + (r1.ru_stime - r0.ru_stime), time.time() - t0


ob, _, _ = run(base)
oo, _, _ = run(one)
print("outputs identical:", ob == oo, "| base %d bytes, variant %d bytes" % (len(ob), len(oo)))
for name, text in (("base", base), ("one-scan", one)):
    cpu = []
    wall = []
    for _ in range(N):
        _, c, w = run(text)
        cpu.append(c)
        wall.append(w)
    cpu.sort()
    wall.sort()
    print("%-9s cpu median %.2f ms (min %.2f)  wall median %.2f ms" % (name, cpu[N // 2] * 1000, cpu[0] * 1000, wall[N // 2] * 1000))
