#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
gen-oui.py -- a synthetic OUI file in the firmware's form: 38,959 lines "AA:BB:CC<TAB>NAME", 13,031 of them under 00, sorted by prefix.

The names are invented ("MADE-UP VENDOR NNNNN LTD") and the prefixes random; the file only has the size and the shape of the real one,
which is what the collector's index build is sensitive to. Deterministic (random.seed(11)). Writes only the file named on the command line.

usage: python3 -B -I gen-oui.py OUT.txt
"""
import random
import sys

if len(sys.argv) != 2:
    sys.exit(__doc__)
random.seed(11)
out = sys.argv[1]
seen = set()
lines = []


def add(first):
    while True:
        p = "%02X:%02X:%02X" % (first, random.randrange(256), random.randrange(256))
        if p not in seen:
            seen.add(p)
            lines.append("%s\tMADE-UP VENDOR %05d LTD" % (p, len(lines)))
            return


for _ in range(13031):
    add(0)
for _ in range(38959 - 13031):
    add(random.randrange(1, 256))
random.shuffle(lines)
lines.sort(key=lambda ln: ln[:8])
with open(out, "w") as f:
    f.write("\n".join(lines) + "\n")
print(out, len(lines))
