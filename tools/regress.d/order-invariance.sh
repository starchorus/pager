# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/order-invariance.sh -- the layout and the counters must not depend on the ORDER of aps[], aps[].clients[], unassociated[].
# GUARDS AGAINST: a sort that is dropped or made partial in the ingest (rebuildOrders, the per-AP client rank), so that the sky of the
#                 same capture looks different from one poll to the next just because the collector listed the entries differently.
#                 Every fixture is loaded as it is and 10 times with all lists of >= 5 entries shuffled (fixed LCG seeds); the canonical
#                 digest (nodes by id to 0.1 px, the 10 geometric layoutInfo fields, the stats counters) must be equal in all runs.
# NEGATIVE PROBE: a page copy without the aps sort (rebuildOrders), without the clients sort (rebuildOrders) and without the
#                 client-rank sort (ingest) => red each; the same probe WITHOUT emptying the maps in the eval would stay green (placebo, see
#                 order-invariance.js); shuffler as identity => shuffler row red. Standing row "sensor bites" below (copy under out/).
# NOT PROVEN:     3D, themes, drawing order (only the 2D extent/layout); order BETWEEN two polls of a running page (there
#                 the map order of the first poll remains; here it is emptied per run); lists with fewer than 5 entries
#                 (counted as skipped in the row name); fixtures only, no fuzz documents. Iteration counts may differ (reported).
# ALSO:           a poll of the same capture in a running page does not relay out (§4.0): no iterations, no movement.
# Sourced by tools/regress.sh with cwd = repo root; three Chrome runs (the drop-in's wall time is in out/PREFIX-timing.txt;
# row names carry no seconds). Only ORD_* names are set.
# Mutated pages and eval copies are only DATA/JS served to headless Chrome on 127.0.0.1; nothing in here sends or executes a mutant elsewhere.
ORD_MIN_LISTS=15   # lists with n >= 5 that get shuffled: the row below names them ("N lists (n>=5)"; measured: 21 over 12 fixtures)
# Known open findings (glob on "FIXTURE#seedK" | owner | cause). Empty: every permutation gave the reference. New finding => red;
# an entry nothing hits => red "please remove". A finding is fixed in the page, never here.
ORD_KNOWN_OPEN=''
ORD_JS=$(cat "$R/tools/evals/order-invariance.js")
ORD_Q="?poll=0&spin=0&intro=0&debug=1&fixed=$STARCHORUS_FIXED"

# ---- 1. the bundle (its own file name: runq writes its REPORT to PREFIX.json, which must not be the bundle): every fixture of tests/fixtures as it is, under order.NAME (the carrier itself is a valid empty document)
python3 -B - "$F" "out/$P-order-bundle.json" <<'PYEND'
import glob, json, os, sys
o = {}
for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.json"))):
    o[os.path.basename(f)[:-5]] = json.load(open(f, encoding="utf-8"))
json.dump({"generated": 1789300000, "center": {"label": "order"}, "source": "none", "aps": [], "unassociated": [], "order": o}, open(sys.argv[2], "w"))
PYEND
ORD_NF=$(python3 -B -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["order"]))' "out/$P-order-bundle.json" 2>/dev/null)
ORD_ND=$(find "$F" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')

# ---- 2. the run: every fixture, reference twice + 10 permutations, in ONE eval; then the verdict
printf '%s\n' "$ORD_KNOWN_OPEN" > "out/$P-order-open.txt"
runq "out/$P-order-bundle.json" "$ORD_Q" "out/$P-order" --wait 2 --fps 0 --eval-timeout 180 --eval "$ORD_JS(\"run\")" > "out/$P-order.txt" 2>&1; ORD_RC=$?
ORD_V=$(order_verdict "out/$P-order.json" run "$ORD_MIN_LISTS" "out/$P-order-open.txt"); ORD_VC=$?
tm_note "eval order-invariance run" "$(report_secs "out/$P-order.json" 1)"   # the eval's own clock: timing file, not the row name
ORD_OK=0; [ "$ORD_VC" = 0 ] && [ "$ORD_RC" = 0 ] && [ "${ORD_NF:-0}" = "$ORD_ND" ] && ge "$ORD_NF" "$MIN_FIXTURES" && ORD_OK=1
rowif "order invariance: $ORD_V" [ "$ORD_OK" = 1 ]
[ "$ORD_OK" = 1 ] || { echo "    driver exit $ORD_RC, fixtures in the bundle $ORD_NF of $ORD_ND (floor $MIN_FIXTURES)"; python3 - "out/$P-order-bundle.json" <<'PYEND'
import json, sys
try: ev = json.load(open(sys.argv[1])).get("eval") or []
except Exception as e: ev = []; print("    no report: %s" % e)
for e in ev:
    try: r = json.loads(e["value"])
    except Exception: print("    eval gave: %s" % str(e.get("value"))[:200]); continue
    for n, w in (r.get("findings") or [])[:12]: print("    finding %s: %s" % (n[:60], w[:140]))
PYEND
}

# Between two polls of a running page: a poll that delivers the same capture again (the device writes every 30 s, the page
# polls every 5 s) must not relay out (§4.0). It used to restart the relaxation from the homes, so free stations flew up to
# ~600 px and back every 5 s. Real time (no ?fixed: under a frozen clock nothing would move either way), the served fixture
# is the capture, pollNow() fetches it again; wait until the iteration count of field-scale stands still (cap 600, at most
# 40 s on a slow machine), then until the free stations stand still too (the first layout is not held: after the capped
# relaxation and detrap it still glides for about 3 s; < 0.05 px in 0.5 s, at most 20 s), poll, compare after 0.5 s.
ORD_STILL='(async()=>{let last=-1;for(let k=0;k<40;k++){const it=STARCHORUS.layoutInfo().iterations;if(it===last)break;last=it;await STARCHORUS.wait(1000);}const P=()=>{const m=new Map();for(const n of STARCHORUS.nodes("free"))m.set(n.id,[n.sx,n.sy]);return m;};for(let q=0;q<40;q++){const s0=P();await STARCHORUS.wait(500);const s1=P();let mv=0;for(const [k,v] of s0){const w=s1.get(k);if(w)mv=Math.max(mv,Math.hypot(w[0]-v[0],w[1]-v[1]));}if(mv<0.05)break;}const a=P(),i0=STARCHORUS.layoutInfo().iterations;const pr=await STARCHORUS.pollNow();if(!pr||!pr.ok||a.size<1000)return "not tested: poll ok "+(pr&&pr.ok)+", "+a.size+" free stations (want >= 1000)";await STARCHORUS.wait(500);const b=P(),i1=STARCHORUS.layoutInfo().iterations;let mx=0;for(const [k,v] of a){const w=b.get(k);if(w)mx=Math.max(mx,Math.hypot(w[0]-v[0],w[1]-v[1]));}return i0+"/"+i1+"/"+a.size+"/"+mx.toFixed(1);})()'
runq "$F/field-scale.json" "?poll=0&spin=0&intro=0" "out/$P-order-still" --wait 2 --fps 0 --eval-timeout 90 \
  --eval "$ORD_STILL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
ORD_SV=$(evalv "out/$P-order-still.json" 1); ORD_SE=$(evalv "out/$P-order-still.json" 2)
ORD_SI0=${ORD_SV%%/*}; ORD_SR=${ORD_SV#*/}; ORD_SI1=${ORD_SR%%/*}; ORD_SM=${ORD_SV##*/}
ORD_SOK=0; [ -n "$ORD_SV" ] && [ "$ORD_SI0" = "$ORD_SI1" ] && [ "$ORD_SM" = "0.0" ] && [ "$ORD_SE" = 0 ] && ORD_SOK=1
rowif "same capture polled again: no relayout (iterations $ORD_SI0 -> $ORD_SI1), free stations still (max move $ORD_SM px)" [ "$ORD_SOK" = 1 ]
[ "$ORD_SOK" = 1 ] || echo "    got: ${ORD_SV:-no-value} (iterations before/after/free stations/max move px), errors ${ORD_SE:-?}"

# ---- 3. the sensor bites: the same machinery against a page copy WITHOUT the aps sort of rebuildOrders must be RED (a Chrome run of
# its own), and a mixer that does not mix must be caught by the mixer count (second eval of that run, "mixer" mode, no document loaded).
# Fair by construction: both target lines exist once, each copy differs from its original in exactly that line, and the page copy
# boots without errors (a load failure or any other finding fails the row). The copies are served to headless Chrome on 127.0.0.1 only.
# the aps sort line of rebuildOrders as the page writes it (the bssid tie-break is cmpStr)
ORD_SORT='^  aps\.sort((a, b) => b\.rssi - a\.rssi || cmpStr(a\.bssid, b\.bssid));$'
ORD_MIX='^  const shuffle = '
ORD_E1=$(grep -c -- "$ORD_SORT" "$H"); ORD_E2=$(grep -c -- "$ORD_MIX" "$R/tools/evals/order-invariance.js")
ORD_PG="out/$P-order-probe.html"; ORD_PJ="out/$P-order-probe.js"
sed "s/$ORD_SORT/  \/\/ (aps sort removed by the probe)/" "$H" > "$ORD_PG"
sed 's/^  const shuffle = .*$/  const shuffle = (a, rnd) => a.slice();/' "$R/tools/evals/order-invariance.js" > "$ORD_PJ"
ORD_D1=$(diff "$H" "$ORD_PG" | grep -c '^<'); ORD_D2=$(diff "$R/tools/evals/order-invariance.js" "$ORD_PJ" | grep -c '^<')
ORD_JSB=$(cat "$ORD_PJ")
ORD_HKEEP=$H; H=$ORD_PG   # runq serves $H: point it at the copy for this one call, then put it back
runq "out/$P-order-bundle.json" "$ORD_Q" "out/$P-order-probe" --wait 2 --fps 0 --eval-timeout 180 --eval "$ORD_JS(\"run\")" --eval "$ORD_JSB(\"mixer\")" > "out/$P-order-probe.txt" 2>&1
H=$ORD_HKEEP
ORD_PV=$(order_verdict "out/$P-order-probe.json" probe "$ORD_MIN_LISTS" -); ORD_PC=$?
ORD_MV=$(order_verdict "out/$P-order-probe.json" mixerprobe "$ORD_MIN_LISTS" -); ORD_MC=$?
ORD_POK=0; [ "$ORD_E1" = 1 ] && [ "$ORD_E2" = 1 ] && [ "$ORD_D1" = 1 ] && [ "$ORD_D2" = 1 ] && [ "$ORD_PC" = 0 ] && [ "$ORD_MC" = 0 ] && ORD_POK=1
rowif "order sensor bites: page without the aps sort is RED and an identity mixer is caught, $ORD_PV; $ORD_MV" [ "$ORD_POK" = 1 ]
[ "$ORD_POK" = 1 ] || { echo "    target lines: sort $ORD_E1, mixer $ORD_E2; changed lines: page $ORD_D1, eval $ORD_D2"; echo "    page probe: $ORD_PV"; echo "    mixer probe: $ORD_MV"; }
