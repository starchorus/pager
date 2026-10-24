#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
sim-poll.py -- the page's poll scheduler, simulated: how many requests does it make per capture the collector publishes?

WHAT IT MEASURES: a Python restatement of pollNextMs / pollArm in src/js/38-data-source.js with the constants of src/js/20-config.js (STEP 2 s,
LEAD 3 s, GUESS 1.1, POLL_MS 5 s, MAXI 600 s) against four invented collectors (a cycle of a given length and jitter, published every `period`
seconds), over half an hour of simulated time. It prints polls, captures and polls per capture. It is a restatement: when the page's rules change,
change the constants here too (tools/regress.d/poll-cadence.sh holds the rules as rows; this file shows what they cost).
HOW TO RUN:  python3 -B -I tools/bench/page/sim-poll.py          (no arguments; no files read or written; no Chrome, no device, no network)
DETERMINISTIC: all of it (random.seed(3)): the same lines every run. Not part of any gate.
"""
import random

STEP, LEAD, GUESS, POLL_MS, MAXI = 2000, 3000, 1.1, 5000, 600


def sim(period_s, cycle_s, jitter, horizon_s=1800, interval_s=30):
    # the collector publishes capture k at t_pub = k*period + cycle_s(+jitter), with generated = k*period (cycle start)
    random.seed(3)
    pubs = []
    t = 0.0
    while t < horizon_s + 100:
        pubs.append((t + cycle_s + random.uniform(-jitter, jitter), int(t)))
        t += period_s

    def latest(now):
        g = None
        for tp, gen in pubs:
            if tp <= now:
                g = gen
        return g

    now = 0.5
    wait = 0
    since = 0
    last_old = False
    gaps = []
    last_gen = None
    reqs = []
    stale_after = 1000 * max(30, 2 * interval_s + 15)
    first = True
    while now < horizon_s:
        g = latest(now)
        reqs.append(now)
        fresh = g is not None and g != last_gen
        if g is not None and last_gen is not None and g > last_gen:
            gaps = (gaps + [g - last_gen])[-3:]
        ok = g is not None
        known = last_old and wait <= STEP
        last_old = ok and not fresh
        since = 0 if fresh else since + wait
        if fresh:
            last_gen = g
        s = sorted(gaps)
        n = len(s)
        sp = (s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2) if n else None
        if first:
            nxt = POLL_MS
            first = False
        elif fresh:
            nxt = max(STEP, round(1000 * min(sp if sp is not None else GUESS * interval_s, MAXI) - LEAD)) if (known or sp is None) else STEP
        else:
            nxt = STEP if since < stale_after else POLL_MS
        wait = nxt
        now += nxt / 1000
    caps = len([1 for tp, gen in pubs if tp < horizon_s])
    return len(reqs), caps


for period, cyc, jit, label in ((33, 3, 0.5, "busy night: 30 s sleep + 3 s cycle"), (42, 12, 1.0, "loaded device: 30 s sleep + 12 s cycle"),
                                (30.2, 0.2, 0.2, "skip cycles (quiet): 30 s sleep + 0.2 s"), (36, 6, 3.0, "6 s cycle with 3 s jitter")):
    r, c = sim(period, cyc, jit)
    print("%-42s %4d polls for %3d captures = %.2f polls per capture (%.1f per minute)" % (label, r, c, r / c, r / (1800 / 60)))
