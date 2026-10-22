# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/mutation-probe.sh -- the passivity checker has to be able to say no.
# GUARDS AGAINST: a rule of passivity-check.sh that drifted, was emptied or lost ONE alternative of its regex (importScripts,
#                 hostapd, DEAUTH, sendBeacon ...) stays green, because nothing ever plants a violation.
# NEGATIVE PROBE: `window\.open\(|` taken from NETX, the object prefix of the location alternative, one
#                 alternative each from NETX/TX_WORDS/SEC6_RE/NETSURF_RE/BT_WORDS/BT_WRAP_RE, the evidence lines of a family, switching the
#                 sqlite3 rule to whole-line reading, each Bluetooth row (tool words outside the allowlist, the lines of bt_begin, word forms,
#                 wrappers, command position, the pinned apcli_ro lines) to reading nothing => "GREEN (BLIND!)", exit 1, these rows red; the same for the
#                 row of the built names (§14.6d command words from an expansion): the row, its detection, its wrapper words, the report of a new line and of a vanished pin;
#                 its second row (§14.6e command names from a glob, find -exec, xargs or alias): the row, the glob test, each of find's options, the placeholder and the
#                 missing command of xargs, the alias, the end of a case pattern and the `${ }` state (their controls go red), a quoted wrapper; the pinned lines of the
#                 transmit row (the row, a vanished pin, a pin that covers every copy) and three of the new alternatives (`--meta`, one image each); the three rows of the device probe (tools/device-probe.sh,
#                 which runs on the device: its scope fill, its 'named tools' with a pinned list of lines, its 'programs'): a sending, scanning, Bluetooth or network tool, an `iw` that sets something, a built or
#                 globbed command word, a program no list names, an edited, a vanished and a copied pinned line, `date -s`, `sed -i` and `sort -o`, every spelling of a write outside /dev/null and the private directory (redirections of every form, the destination of cp, mv and tee, the assignment of T and OUT), a function that hands `command` a program of its own name and a command before a `case` on the same line, each part of the rows blinded once, and the family of network words (`alt pnet`). Mutations that wait for lines of the collector's Bluetooth code are PENDING (listed, not red) until they exist.
# NOT PROVEN:     proves only that the source guard bites, not the behaviour of the running page (that is net-runtime.sh); one
#                 example per alternative, not every spelling (header of tools/passivity-mutate.sh).
# Sourced by tools/regress.sh with cwd = repo root; chrome-free; about ten minutes for the mutations and the alternatives (a checker run of about 2.5 s for each, more on a busy machine) and about as long again for --meta (T1 runs it only when the checker or this probe is staged). Only MUT_* names are set.
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
