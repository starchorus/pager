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
#                 globbed command word, a program no list names, an edited, a vanished and a copied pinned line, `date -s`, `sed -i` and `sort -o`, every spelling of a write outside /dev/null and the private directory (redirections of every form, the destination of cp, mv and tee, the assignment of T and OUT), a function that hands `command` a program of its own name and a command before a `case` on the same line, the action of a `trap` that runs a string, a case inside a group on a body line of an open case, an expansion after `$T/` and a call of `vset` that is not given digits, a here-document whose delimiter has a quote in the middle or whose bare-delimiter body is expanded, `command run_limited`, the floor of write targets read, a `name() { :; }` planted where it defines nothing (in a here-document body, a string or a comment) with a call of that name or a `trap` that names it, a function head or closing brace in such a text that gave the pins another function, a line that looks like a comment inside a string, a bare here-document or after a backslash, a head inside a function, a line with two here-documents of which the first is bare, each part of the rows blinded once, and the family of network words (`alt pnet`); and for the collector, both Overview copies, both payload.sh, the listener and library/, which the same reader now reads whole: a head in a here-document body or a string with a device call, a word of the Bluetooth stack or a built name behind it (`main-head-`), a comment-looking line in a string, a here-document or after a backslash (`main-comment-`), a head inside a function (`main-nested-`, `main-brace-indented`), a built name or a glob in the body of a bare here-document and with two here-documents on a line (`main-heredoc-`, `main-two-heredocs`), the default and the guard of the `iw scan` opt-in behind a comment sign, moved or copied (`main-iw-`), a built name or a glob below a function head in a here-document body, quoted or bare, or in a string, also in a body nested in it and in the handler that the listener writes (`main-script-`; the part before the first head stays text), and a here-document delimiter that is not a plain name (`main-odd-delimiter`), each of those parts blinded once. Mutations that wait for lines of the collector's Bluetooth code are PENDING (listed, not red) until they exist.
# NOT PROVEN:     proves only that the source guard bites, not the behaviour of the running page (that is net-runtime.sh); one
#                 example per alternative, not every spelling (header of tools/passivity-mutate.sh).
# Sourced by tools/regress.sh with cwd = repo root; chrome-free; about 21 minutes on a quiet machine, the length of the longer half: the mutations and the alternatives take about 21 minutes (about 500 checker runs of 2 to 3 s each, more on a busy machine) and --meta finishes sooner, alongside (run one after the other the two took about 36). T1 runs it only when the checker or this probe is staged. Only MUT_* names are set.
# The two halves share nothing (each makes its own mktemp -d, writes only there, builds its own images; --meta runs the script on a blinded image with --only, never on
# the main pass's results), so they run at the same time, each into its own file; the rows are judged one after the other, as before.
# A shell starts a background job with SIGINT ignored, which the job cannot take back, so Ctrl-C would stop this script and leave both halves running for
# some twenty minutes (in the hook, in an export that is already removed). While it waits, this script therefore passes INT and TERM on to the halves as TERM, which
# they trap (their temporary directories go), waits for them to end, and exits 130; the traps are cleared again once both have ended.
MUT_out="out/$P-pmut.txt"; MUT_outm="out/$P-pmeta.txt"
sh tools/passivity-mutate.sh > "$MUT_out" 2>&1 & MUT_pid=$!
sh tools/passivity-mutate.sh --meta > "$MUT_outm" 2>&1 & MUT_pidm=$!
trap 'kill "$MUT_pid" "$MUT_pidm" 2>/dev/null; wait "$MUT_pid" "$MUT_pidm" 2>/dev/null; trap - INT TERM; exit 130' INT TERM
wait "$MUT_pid"; MUT_rc=$?
wait "$MUT_pidm"; MUT_rcm=$?
trap - INT TERM
MUT_sum=$(sed -n 's/^passivity mutation probe: //p' "$MUT_out" | tail -n 1)
MUT_ok=0; [ "$MUT_rc" = 0 ] && [ -n "$MUT_sum" ] && MUT_ok=1
rowif "passivity mutation probe: ${MUT_sum:-no summary line} (exit $MUT_rc)" [ "$MUT_ok" = 1 ]
[ "$MUT_ok" = 1 ] || grep -E 'BLIND|WRONG|SETUP|UNCOVERED|not yet red|not green|self guard' "$MUT_out" | cut -c1-200 | sed 's/^/    /'
MUT_sum=$(sed -n 's/^passivity meta probe: //p' "$MUT_outm" | tail -n 1)
MUT_ok=0; [ "$MUT_rcm" = 0 ] && [ -n "$MUT_sum" ] && MUT_ok=1
rowif "passivity probe bites: ${MUT_sum:-no summary line} (exit $MUT_rcm)" [ "$MUT_ok" = 1 ]
[ "$MUT_ok" = 1 ] || sed 's/^/    /' "$MUT_outm" | cut -c1-200
