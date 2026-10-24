#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
bench-bt.py -- the three steps of the collector's Bluetooth parse (grep prefilter, tr, the awk grammar) on a btmon window, and two awk variants.

WHAT IT MEASURES: bt_parse in starchorus-collect.sh reads a btmon text through `grep -E` (the prefilter), `tr -d` (clean_ctrl) and an awk
grammar (AWK_BT). This script takes all three from a COPY of the collector (the grammar between `AWK_BT='` and the closing quote, the
prefilter from `bp_k=`), runs them on the fixture the collector's own self-test uses, and times each step as child CPU (median of N runs).
It also times two variants of the grammar and prints the md5 of each variant's output: v1 replaces `sub(/:.*$/, "", b)` by `index()` and
`substr()`, v2 also replaces the known() function by a lookup table. A variant that is not byte-identical in output is not a saving.
HOW TO RUN:  python3 -B -I tools/bench/bt/bench-bt.py OUTDIR [N=30] [COLLECTOR=starchorus-collect.sh] [WINDOW=tests/fixtures/btmon-window.txt]
  Needs python3, grep, tr and awk (the system's; on a Mac that is one-true-awk, on the Pager BusyBox awk, so the milliseconds do not carry over).
  Paths default to the repository this file sits in. No device, no network, no radio; the window is a synthetic fixture (addresses 02:00:00:...).
WRITES ONLY under OUTDIR: the three awk programs (awk_bt.awk, awk_bt_v1.awk, awk_bt_v2.awk), kept.txt (after the grep) and clean.txt (after the tr).
DETERMINISTIC: the input size, the number of kept lines, the md5 of every variant's output (and whether they are equal). NOISE: the milliseconds
(a few ten percent on a shared machine; compare the rows of one run, never two runs). Not part of any gate.
"""
import hashlib
import os
import re
import resource
import subprocess
import sys

if len(sys.argv) < 2:
    sys.exit(__doc__)
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
out_dir = sys.argv[1]
N = int(sys.argv[2]) if len(sys.argv) > 2 else 30
collector = sys.argv[3] if len(sys.argv) > 3 else os.path.join(REPO, "starchorus-collect.sh")
window = sys.argv[4] if len(sys.argv) > 4 else os.path.join(REPO, "tests", "fixtures", "btmon-window.txt")
os.makedirs(out_dir, exist_ok=True)
text = open(collector, encoding="utf-8").read()
m = re.search(r"(?ms)^AWK_BT='\n(.*?)^'\n", text)
k = re.search(r"^\s*bp_k='(.*)'$", text, re.M)
if not m or not k:
    sys.exit("bench-bt: cannot find AWK_BT or bp_k in %s" % collector)
awk_cur, prefilter = m.group(1), k.group(1)
v1 = awk_cur.replace('b = t; sub(/:.*$/, "", b)', 'b = substr(t, 1, index(t, ":") - 1)')
v2 = v1.replace("BEGIN { last = -1; na = 0; nrep = 0; rs = 0 }",
                'BEGIN { last = -1; na = 0; nrep = 0; rs = 0; KN["Type"]=1; KN["Scanning"]=1; KN["Event type"]=1; KN["Address type"]=1; KN["Address"]=1; KN["Company"]=1; KN["Name (complete)"]=1; KN["Name (short)"]=1; KN["RSSI"]=1 }')
v2 = v2.replace("if (!inev || !known(b)) next", "if (!inev || !(b in KN)) next")
progs = [("awk_bt.awk", awk_cur), ("awk_bt_v1.awk", v1), ("awk_bt_v2.awk", v2)]
if v1 == awk_cur or v2 == v1:
    print("bench-bt: note: a variant did not apply to this collector (its text has moved); that row repeats the one before")
for name, body in progs:
    open(os.path.join(out_dir, name), "w").write(body)


def cpu(cmd, stdin=None, env=None):
    t = []
    out = b""
    for _ in range(N):
        r0 = resource.getrusage(resource.RUSAGE_CHILDREN)
        fh = stdin() if stdin else None
        out = subprocess.run(cmd, stdin=fh, capture_output=True, env=env).stdout
        if fh:
            fh.close()
        r1 = resource.getrusage(resource.RUSAGE_CHILDREN)
        t.append(((r1.ru_utime - r0.ru_utime) + (r1.ru_stime - r0.ru_stime)) * 1000)
    t.sort()
    return t[N // 2], out


env = dict(os.environ, LC_ALL="C")
kept_p, clean_p = os.path.join(out_dir, "kept.txt"), os.path.join(out_dir, "clean.txt")
g_ms, filt = cpu(["grep", "-E", prefilter, window], env=env)
open(kept_p, "wb").write(filt)
t_ms, clean = cpu(["tr", "-d", "\\000-\\010\\013-\\037\\177"], stdin=lambda: open(kept_p, "rb"), env=env)
open(clean_p, "wb").write(clean)
res = {}
for name, _ in progs:
    a_ms, out = cpu(["awk", "-f", os.path.join(out_dir, name)], stdin=lambda: open(clean_p, "rb"), env=env)
    res[name] = (a_ms, hashlib.md5(out).hexdigest()[:8])
print("input: %d bytes, kept %d lines" % (os.path.getsize(window), filt.count(b"\n")))
print("grep prefilter %.1f ms | tr %.1f ms" % (g_ms, t_ms))
base = res["awk_bt.awk"][0]
for name, (ms, h) in res.items():
    print("%-16s awk %.1f ms  (%.0f%% of current)  output md5 %s" % (name, ms, 100 * ms / base, h))
print("outputs equal: %s" % (len(set(h for _, h in res.values())) == 1))
