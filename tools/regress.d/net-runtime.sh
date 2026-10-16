# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/net-runtime.sh -- the passivity of the RUNNING page, from the requests it really made.
# GUARDS AGAINST: passivity-check.sh reads source text only; a request built at run time (string concatenation, a new
#                 sink) passes it. Here the CDP Network events (cdp.py "requests") and the http.server log are judged.
# NEGATIVE PROBE: an appended POST fetch, `new Image().src` on 127.0.0.1:9, a removed poll fetch => red;
#                 the first two run as a standing row below (copy of the page under out/), net_verdict dummies in static.sh.
# NOT PROVEN:     behaviour on the device or in another browser; requests after the observation time (~14 s, about eight polls).
# Sourced by tools/regress.sh with cwd = repo root; two Chrome runs (about 15 s + 9 s). Only NRT_* names are set.
# verify.sh (not runq: it cannot take a page path and discards the server log) runs with its fixed URL, i.e. WITHOUT
# ?poll=0. A later --wait overrides verify.sh's own --wait 6 (argparse), measured: 15.4 s wall for --wait 11, with
# a poll about every 2 s (the cadence of spec §9.5 without center.interval). Its exit 1 (fps < 30 or a page error) is judged by the verify rows above, not here; 2 = driver.
NRT_MINPOLL=3   # floor: the boot poll and the cadence's 2 s steps inside --wait 11 bring more (measured as of 0.1.1 with the cadence: 8)
sh tools/verify.sh "$H" "$F/many-clients.json" "out/$P-net" --wait 11 > "out/$P-net.txt" 2>&1; NRT_RC=$?
NRT_V=$(net_verdict "out/$P-net.json" "out/$P-net.server.log" "$NRT_MINPOLL"); NRT_C=$?
NRT_OK=0; [ "$NRT_RC" -le 1 ] && [ "$NRT_C" = 0 ] && NRT_OK=1
rowif "runtime network: $NRT_V" [ "$NRT_OK" = 1 ]
[ "$NRT_RC" -le 1 ] || sed 's/^/    /' "out/$P-net.txt" | tail -n 5 | cut -c1-200

# The sensor must be able to see: the same page plus what a violation looks like (a POST at start-up and an image with
# a foreign origin, which only the request list sees), run in headless Chrome against 127.0.0.1 only (port 9 refuses).
# Expected: RED with exactly these four reasons (browser: path /x, method POST, origin :9; server log: the POST), nothing else.
NRT_PG="out/$P-net-mut.html"
NRT_HAS=$(grep -c '</html>' "$H")   # the page has the closing tag once; the probe hangs its script behind it
{ cat "$H"; printf '%s\n' '<script>fetch("/x",{method:"POST"});new Image().src="http://127.0.0.1:9/x";</script>'; } > "$NRT_PG"
sh tools/verify.sh "$NRT_PG" "$F/many-clients.json" "out/$P-net-mut" --wait 7 --fps 0 > "out/$P-net-mut.txt" 2>&1; NRT_MRC=$?
NRT_MV=$(net_verdict "out/$P-net-mut.json" "out/$P-net-mut.server.log" 2); NRT_MC=$?
NRT_MW=$(printf '%s\n' "$NRT_MV" | sed -n 's/^.* -- FAIL: //p')
NRT_MN=$(printf '%s\n' "$NRT_MW" | awk -F'; ' '{ print NF }')
NRT_MOK=0
if [ "$NRT_HAS" = 1 ] && [ "$NRT_MRC" -le 1 ] && [ "$NRT_MC" = 1 ] && [ "$NRT_MN" = 4 ] \
   && printf '%s\n' "$NRT_MW" | grep -q 'path /x not in' && printf '%s\n' "$NRT_MW" | grep -q 'method POST' && printf '%s\n' "$NRT_MW" | grep -q 'origin http://127\.0\.0\.1:9' \
   && printf '%s\n' "$NRT_MW" | grep -q 'server log: POST /x'; then NRT_MOK=1; fi
rowif "runtime network probe: page with POST + foreign image is RED (4 reasons: path, method, origin, server log)" [ "$NRT_MOK" = 1 ]
[ "$NRT_MOK" = 1 ] || { printf '    %s\n' "verdict: $NRT_MV" "verify exit $NRT_MRC, judge exit $NRT_MC, $NRT_MN reasons, closing tags in page $NRT_HAS"; }
