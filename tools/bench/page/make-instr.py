#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
make-instr.py -- an instrumented COPY of the page: the named top-level functions are wrapped with timers.

WHAT IT DOES: reads the built page (starchorus.html or a copy), finds the listed top-level functions (render, step, tick, projectAll, ...) and
adds, just before the page's closing `})();`, a function window.__inst() that wraps each of them so that calls and milliseconds are counted in
window.__b[name] = {n, ms}, and a switch window.__every (render only every Nth call; 1 = all). Nothing in the page itself changes until a
driver calls window.__inst(): bench-page.py (option `instr`) and bench-poll.py do. The page is never written; the copy goes where you say.
HOW TO RUN:  python3 -B -I tools/bench/page/make-instr.py PAGE.html OUT.html
DETERMINISTIC: the list of wrapped functions it prints ("wrapped:" / "missing:"; a missing name means the page has renamed it). Not part of any gate.
"""
import re
import sys

if len(sys.argv) != 3:
    sys.exit(__doc__)
src = open(sys.argv[1], encoding="utf-8").read()
names = ("render step scopeStep projectAll stepParticles stepNodes stepClouds stepSky stepBubbles stepFlares tick budgetBegin perfTick loadData "
         "normalizeDoc ingest rebuildClouds rebuildBt rebuildOrders rebuildGroups rebuildDevices rebuildEss settleLayout computeGroupEdges "
         "securityCounts rebuildChannelStats rebuildInterference skyUpdate chanPeakUpdate baselineRecompute obsCompute updateStats renderSourceTruth "
         "recAppend layoutEdges drawChannelBar renderScope scopePlace scopeWave drawScope drawScopeBg rebuildBackground").split()
found = [n for n in names if re.search(r"^\s*function %s\(" % re.escape(n), src, re.M)]
blk = "window.__inst=function(){window.__b={};" + "".join(
    "{const f=%s;window.__b[%r]={n:0,ms:0};%s=function(){const t0=performance.now();try{return f.apply(this,arguments)}finally{const o=window.__b[%r];o.n++;o.ms+=performance.now()-t0}}}" % (n, n, n, n)
    for n in found) + "{const f=render;window.__rc=0;window.__every=1;render=function(){if(window.__every>1&&(window.__rc++%window.__every))return;return f.apply(this,arguments)}}" + "return %s};\n" % repr(",".join(found)).replace("'", '"')
idx = src.rindex("})();")
open(sys.argv[2], "w", encoding="utf-8").write(src[:idx] + blk + src[idx:])
print("wrapped:", ",".join(found))
print("missing:", ",".join(n for n in names if n not in found))
