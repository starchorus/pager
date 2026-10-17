# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/mutation-probe.sh -- the passivity checker has to be able to say no.
# GUARDS AGAINST: a rule of passivity-check.sh that drifted, was emptied or lost ONE alternative of its regex (importScripts,
#                 hostapd, DEAUTH, sendBeacon ...) stays green, because nothing ever plants a violation.
# NEGATIVE PROBE: `window\.open\(|` taken from NETX, the object prefix of the location alternative, one
#                 alternative each from NETX/TX_WORDS/SEC6_RE/NETSURF_RE, the evidence lines of a family, switching the
#                 sqlite3 rule to whole-line reading, the hcitool row to `lescan` only => "GREEN (BLIND!)", exit 1, these rows red (`--meta`, one image each).
# NOT PROVEN:     proves only that the source guard bites, not the behaviour of the running page (that is net-runtime.sh); one
#                 example per alternative, not every spelling (header of tools/passivity-mutate.sh).
# Sourced by tools/regress.sh with cwd = repo root; chrome-free (about 29 s plus 14 s for --meta). Only MUT_* names are set.
MUT_out="out/$P-pmut.txt"
sh tools/passivity-mutate.sh > "$MUT_out" 2>&1; MUT_rc=$?
MUT_sum=$(sed -n 's/^passivity mutation probe: //p' "$MUT_out" | tail -n 1)
MUT_ok=0; [ "$MUT_rc" = 0 ] && [ -n "$MUT_sum" ] && MUT_ok=1
rowif "passivity mutation probe: ${MUT_sum:-no summary line} (exit $MUT_rc)" [ "$MUT_ok" = 1 ]
[ "$MUT_ok" = 1 ] || grep -E 'BLIND|WRONG|SETUP|UNCOVERED|not yet red|not green|self guard' "$MUT_out" | cut -c1-200 | sed 's/^/    /'
sh tools/passivity-mutate.sh --meta > "$MUT_out" 2>&1; MUT_rc=$?
MUT_sum=$(sed -n 's/^passivity meta probe: //p' "$MUT_out" | tail -n 1)
MUT_ok=0; [ "$MUT_rc" = 0 ] && [ -n "$MUT_sum" ] && MUT_ok=1
rowif "passivity probe bites: ${MUT_sum:-no summary line} (exit $MUT_rc)" [ "$MUT_ok" = 1 ]
[ "$MUT_ok" = 1 ] || sed 's/^/    /' "$MUT_out" | cut -c1-200
