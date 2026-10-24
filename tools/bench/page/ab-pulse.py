#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
ab-pulse.py -- the live dot's pulse, smooth against stepped, in one run: what an idle page costs with each.

WHAT IT MEASURES: with bench-page.py (GPU path, 12 s each, after a 6 s warm-up) it runs two idle states, each with the shipped page (the pulse is
`steps(8)`) and with a copy of the page whose pulse is `ease-in-out` again, ROUNDS times, interleaved (smooth, steps, smooth, steps ...) so that a
change in the machine's load falls on both: the desktop sky paused (Space) at 1440x900 retina, and the phone's Scope at rest at 390x844. agg.py then
prints the mean CPU of renderer + GPU process per variant. Read the two variants against each other: the ratio is the finding.
HOW TO RUN:  python3 -B -I tools/bench/page/ab-pulse.py OUTDIR [ROOT=the repository] [ROUNDS=3]       (about 4 minutes for 3 rounds; needs Chrome)
  ROOT is only read (its tools/cdp.py, starchorus.html and tests/fixtures/many-clients.json). No device, no network (127.0.0.1 only), no radio.
WRITES ONLY under OUTDIR: smooth.html (the changed copy of the page) and results.jsonl.
DETERMINISTIC: nothing here but the frame counts in the lines (0 frames drawn while paused and on the Scope at rest). NOISE: the CPU percentages
(+-25 percent with the machine shared); the same-run ratio of the two variants is the figure to quote, with the caveat. Not part of any gate.
"""
import os
import subprocess
import sys

if len(sys.argv) < 2 or len(sys.argv) > 4:
    sys.exit(__doc__)
HERE = os.path.dirname(os.path.abspath(__file__))
out = os.path.abspath(sys.argv[1])
root = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else os.path.abspath(os.path.join(HERE, "..", "..", ".."))
rounds = int(sys.argv[3]) if len(sys.argv) > 3 else 3
os.makedirs(out, exist_ok=True)
page = open(os.path.join(root, "starchorus.html"), encoding="utf-8").read()
steps, smooth = "animation: pulse 2.6s steps(8) infinite;", "animation: pulse 2.6s ease-in-out infinite;"
if steps not in page:
    sys.exit("ab-pulse: the page has no '%s' to turn back into ease-in-out; nothing to compare" % steps)
smooth_path = os.path.join(out, "smooth.html")
open(smooth_path, "w", encoding="utf-8").write(page.replace(steps, smooth))
fx = os.path.join(root, "tests", "fixtures", "many-clients.json")
q = "?poll=0&intro=0&debug=1"


def bench(query, size, scale, mobile, extra, label):
    subprocess.run([sys.executable, "-B", "-I", os.path.join(HERE, "bench-page.py"), out, root, fx, query, size, scale, mobile, "12", "gpu"] + extra + ["label=" + label],
                   check=True, stdout=subprocess.DEVNULL)


for r in range(1, rounds + 1):
    bench(q + "&view=2d", "1440x900", "2", "0", ["pause", "page=" + smooth_path], "paused-desktop-smooth-r%d" % r)
    bench(q + "&view=2d", "1440x900", "2", "0", ["pause"], "paused-desktop-steps-r%d" % r)
    bench(q + "&scope=1", "390x844", "3", "1", ["page=" + smooth_path], "scope-phone-smooth-r%d" % r)
    bench(q + "&scope=1", "390x844", "3", "1", [], "scope-phone-steps-r%d" % r)
subprocess.run([sys.executable, "-B", "-I", os.path.join(HERE, "agg.py"), os.path.join(out, "results.jsonl")], check=True)
