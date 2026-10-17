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

# ?demo=1 holds the built-in sample sky and never asks for starchorus.json. The file IS served, so a poll that slipped through shows in the
# request list and as a 'Live' chip. The run lasts about 11 s, in which the boot poll and four cadence polls would have been made. Two rows:
# zero starchorus.json requests, the page itself seen and nothing but GET to the own origin (net_verdict, no server log, no poll floor); and the
# chip 'Sample' at the start, after 7 s and after STARCHORUS.pollNow(), which asks nothing either.
NRT_DQ="?demo=1&intro=0&spin=0"
NRT_EVD='(async()=>{const c=document.getElementById("mode-chip"),o=[c.textContent+"/"+c.className];await STARCHORUS.wait(7000);const r=await STARCHORUS.pollNow();o.push(JSON.stringify(r),c.textContent+"/"+c.className,STARCHORUS.errors().length);return o.join("|")})()'
runq "$F/many-clients.json" "$NRT_DQ" "out/$P-net-demo" --wait 3 --fps 0 --eval-timeout 40 --eval "$NRT_EVD" >/dev/null 2>&1
NRT_DV=$(net_verdict "out/$P-net-demo.json" - 0); NRT_DC=$?
NRT_DOK=0; [ "$NRT_DC" = 0 ] && case $NRT_DV in *starchorus.json*) ;; *) NRT_DOK=1 ;; esac
rowif "?demo=1: no starchorus.json request in 11 s with the file served: $NRT_DV" [ "$NRT_DOK" = 1 ]
NRT_DE=$(evalv "out/$P-net-demo.json" 1)
rowif "?demo=1: the chip reads Sample at the start, after 7 s and after pollNow() (which answers ok:false), no error [$NRT_DE]" [ "$NRT_DE" = 'Sample/mode demo|{"ok":false}|Sample/mode demo|0' ]
# the sensor can see: a page copy that ignores ?demo=1 polls, and reads Live
NRT_DP="out/$P-net-demo.html"
sed 's/q.demo1 = q.demo === "1";/q.demo1 = false;/' "$H" > "$NRT_DP"
NRT_DN=$(grep -c 'q.demo1 = false;' "$NRT_DP")
NRT_HKEEP=$H; H=$NRT_DP   # runq serves $H: point it at the copy for this one call, then put it back
runq "$F/many-clients.json" "$NRT_DQ" "out/$P-net-demom" --wait 3 --fps 0 --eval-timeout 40 --eval "$NRT_EVD" >/dev/null 2>&1
H=$NRT_HKEEP
NRT_MDV=$(net_verdict "out/$P-net-demom.json" - 0); NRT_MDE=$(evalv "out/$P-net-demom.json" 1)
NRT_MDOK=0
case $NRT_MDV in *"GET /starchorus.json x"*) case $NRT_MDE in *"|Live/mode live|"*) [ "$NRT_DN" = 1 ] && NRT_MDOK=1 ;; esac ;; esac
rowif "?demo=1 probe bites: a page copy that ignores it polls and reads Live (mutation $NRT_DN)" [ "$NRT_MDOK" = 1 ]
[ "$NRT_MDOK" = 1 ] || { echo "    verdict: $NRT_MDV"; echo "    chip: ${NRT_MDE:-no-value}"; }
# the logon gate is released at the boot: with the feed held back 2 s nothing is typed at ~400 ms on a page that polls (source-truth.sh holds
# that control, 0 characters), and on ?demo=1 the typing has begun
NRT_EVG='[document.getElementById("intro-text").textContent.length>0,STARCHORUS.stats().introShown].join("/")'
runq "$F/active.json" "?theme=wargames&demo=1" "out/$P-net-demo-gate" --delay 2 --wait 0.4 --fps 0 --eval "$NRT_EVG" >/dev/null 2>&1
NRT_G=$(evalv "out/$P-net-demo-gate.json" 1)
rowif "?demo=1: the logon is released at the boot, not by the first poll [$NRT_G]" [ "$NRT_G" = "true/true" ]
