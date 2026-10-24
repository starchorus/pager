#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
agg.py -- groups the lines of one or more results.jsonl files (bench-page.py) by label and prints the mean CPU of each group.

A label that ends in -r1, -r2, ... is grouped with its repeats ("pulse-smooth-r1" and "pulse-smooth-r2" are the group "pulse-smooth"). Per
group: n, the mean renderer and GPU-process CPU (core percent), their sum with the range, and the mean of all processes. Reads files, writes
nothing. The counts of frames in the lines are deterministic; the percentages are noise, so read the groups of ONE run against each other.

usage: python3 -B -I tools/bench/page/agg.py RESULTS.jsonl [RESULTS.jsonl ...]
"""
import collections
import json
import re
import statistics as st
import sys

if len(sys.argv) < 2:
    sys.exit(__doc__)
groups = collections.OrderedDict()
for path in sys.argv[1:]:
    for ln in open(path):
        try:
            r = json.loads(ln)
        except ValueError:
            continue
        c = r.get("cpu_pct_by_proc_type", {})
        key = re.sub(r"-r\d+$", "", r.get("label", "") or "(no label)")
        groups.setdefault(key, []).append((c.get("renderer", 0), c.get("gpu-process", 0), sum(c.values())))
print("%-44s %3s  %9s %7s  %9s %-15s  %7s" % ("label", "n", "renderer", "gpu", "r+g", "(range)", "all"))
for key, rows in groups.items():
    rg = [a + b for a, b, _ in rows]
    print("%-44s %3d  %9.1f %7.1f  %9.1f (%5.1f..%5.1f)  %7.1f" % (key, len(rows), st.mean(a for a, _, _ in rows), st.mean(b for _, b, _ in rows),
                                                              st.mean(rg), min(rg), max(rg), st.mean(t for _, _, t in rows)))
