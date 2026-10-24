#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
seg.py -- reads the log of run-census.py and prints, per cycle, the external processes the collector started and their child CPU.

A cycle ends at the collector's own `sleep` between cycles (argument 2, 30 or 1 in the log). Per segment: the number of processes, the child CPU
(user + system, from wait4's rusage) and the wall sum, then the commands by CPU. Counts are deterministic for a given collector and data;
the times are noise (a few ten percent on a shared machine; same-run comparisons only). Reads the log, writes nothing.

usage: python3 -B -I seg.py LOG.tsv [SEGMENT...]       (no segment = all; the first is the start-up, then one full pass, then the cycles)
"""
import collections
import sys

if len(sys.argv) < 2:
    sys.exit(__doc__)
lines = [ln.rstrip("\n").split("\t") for ln in open(sys.argv[1])]
segs = [[]]
for ln in lines:
    segs[-1].append(ln)
    if ln[0] == "sleep" and ln[5].strip() in ("2", "30", "1"):
        segs.append([])
want = [int(x) for x in sys.argv[2:]] or range(len(segs))
for i in want:
    s = segs[i]
    c = collections.OrderedDict()
    for ln in s:
        k = ln[0]
        e = c.setdefault(k, [0, 0, 0])
        e[0] += 1
        e[1] += int(ln[1]) + int(ln[2])
        e[2] += int(ln[3])
    tot = sum(v[1] for v in c.values()) / 1000
    print("segment %d: %d execs, %.1f ms child cpu (user+sys), %.1f ms child wall-sum" % (i, len(s), tot, sum(v[2] for v in c.values()) / 1000))
    print("   " + "  ".join("%s x%d (%.1f ms)" % (k, v[0], v[1] / 1000) for k, v in sorted(c.items(), key=lambda kv: -kv[1][1])))
