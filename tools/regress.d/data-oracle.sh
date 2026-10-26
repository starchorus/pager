# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/data-oracle.sh -- the counters, the device clusters and the ESS sets of the page against an independent model.
# GUARDS AGAINST: a change of the data logic (stats() counters, G1 device grouping, G2 ESS sets, essMerge fold) that nobody notices because
#                 no other row reads those numbers. Every fixture and the hand documents (edge cases with hand-computed answers) are loaded in both
#                 essMerge modes; the page's stats(), devices(), essClusters() and deviceOf() are compared with tools/data-oracle.py, a
#                 second formulation of the rules (not the page's code). Plus devices.json against the documented ground truth of its generator.
# NEGATIVE PROBE: a page copy with three planted faults (BSSID local-bit exception removed, ESS counting from 3 devices,
#                 clients counted twice) => red in exactly those classes; fixture copies of devices.json (cluster member removed, one AP more)
#                 => ground-truth row red. Standing rows "sensor bites" and "ground truth bites" below (copies under out/ only).
# NOT PROVEN:     geometry, layout, bubbles, identity, filters (all bands on), ageing/fading over several polls; fixtures and hand
#                 documents only, no fuzz documents; the model's rules are a second reading, not a proof of the rule itself.
#                 Only the rule lines that the hand documents name are backed by a hand document (security words, channel/frequency
#                 limits of the band derivation, radio pair with an unknown band, window limits, suffix); any other rule line of the page is not proven.
# Sourced by tools/regress.sh with cwd = repo root; two Chrome runs (about 5 s each). Only ORC_* names are set.
# Mutated pages are only DATA/JS served to headless Chrome on 127.0.0.1; nothing in here sends or executes a mutant elsewhere.
# Known open findings (glob on "NAME/MODE:field" | owner | cause). Empty: page and model agree everywhere. A new finding is red; an entry that
# nothing hits is red "please remove". A finding is fixed in the page, never here.
ORC_KNOWN_OPEN=''
ORC_JS=$(cat "$R/tools/evals/data-oracle.js")
ORC_Q="?poll=0&spin=0&intro=0&debug=1&fixed=$STARCHORUS_FIXED"
ORC_B="out/$P-oracle-bundle.json"
# --ready: the boot poll has answered (the bundle is no capture, so the page leaves the built-in sky for sourceKind none); the eval then empties the page state and loads each document itself
ORC_RDY="window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'"
printf '%s\n' "$ORC_KNOWN_OPEN" > "out/$P-oracle-open.txt"

# ---- 1. the run: the bundle (fixtures + hand documents) in ONE eval, then the judge
python3 -B tools/data-oracle.py bundle "$F" "$ORC_B"
runq "$ORC_B" "$ORC_Q" "out/$P-oracle" --wait 2 --fps 0 --ready "$ORC_RDY" --eval-timeout 120 --eval "$ORC_JS(\"run\")" > "out/$P-oracle.txt" 2>&1; ORC_RC=$?
ORC_V=$(python3 -B tools/data-oracle.py judge "out/$P-oracle.json" "$ORC_B" "$H" "out/$P-oracle-open.txt" run); ORC_VC=$?
# The number of fixtures the judge compared is counted here a second time, from the directory (the judge has its own floor, MIN_FIXTURES): a bundle
# that loses fixtures reads "5 fixtures" while the directory has more, and the line is red.
ORC_NFX=$(find "$F" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
ORC_OK=0; [ "$ORC_VC" = 0 ] && [ "$ORC_RC" = 0 ] && case "$ORC_V" in "$ORC_NFX fixtures + "*) ORC_OK=1 ;; esac
rowif "data oracle: $ORC_V" [ "$ORC_OK" = 1 ]
[ "$ORC_OK" = 1 ] || echo "    driver exit $ORC_RC, judge exit $ORC_VC, fixtures in $F: $ORC_NFX"

# ---- 2. the ground truth of the fixture itself (the header of gen-testdata.py, and the README if it states numbers)
ORC_T=$(python3 -B tools/data-oracle.py truth "$F/devices.json" tools/gen-testdata.py tools/README.md); ORC_TC=$?
rowif "data oracle ground truth: $ORC_T" [ "$ORC_TC" = 0 ]

# ---- 3. the ground truth bites: copies of devices.json under out/ that break it must be RED (a python-only run, no Chrome). Fair by
# construction: the broken thing exists once in the fixture (grep -c), each copy differs from the original in exactly that one change.
ORC_M1=$(grep -c '"bssid": "78:8a:20:cc:dd:21"' "$F/devices.json"); ORC_M2=$(grep -c '"bssid": "50:c7:bf:ee:00:43"' "$F/devices.json")
rm -f "out/$P-oracle-fx1.json" "out/$P-oracle-fx2.json" "out/$P-oracle-fx3.json"   # no copy of an earlier run may stand in for a missing one
python3 -B - "$F/devices.json" "out/$P-oracle-fx1.json" "out/$P-oracle-fx2.json" "out/$P-oracle-fx3.json" <<'PYEND'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
def cut(bssid):
    e = json.loads(json.dumps(d)); e["aps"] = [a for a in e["aps"] if a["bssid"] != bssid]; return e
one = json.loads(json.dumps(d)); one["aps"].append({"bssid": "00:11:22:33:44:55", "ssid": "Extra", "channel": 36, "band": "5GHz", "freq": 5180, "rssi": -70, "security": "WPA2", "clients": []})
for f, x in zip(sys.argv[2:], (cut("78:8a:20:cc:dd:21"), one, cut("50:c7:bf:ee:00:43"))):
    json.dump(x, open(f, "w"))
PYEND
# A copy counts as RED only if it exists, the check exits with exactly 1 (2 = cannot check, a traceback is 1 too but has no verdict line), and the
# verdict line names the field that the break has to move: the dual-band box lost its second radio -> devices, an AP more or a member less -> aps.
ORC_N=0; ORC_R=0; ORC_W=""
for ORC_X in 1 2 3; do
  ORC_N=$((ORC_N + 1))
  case $ORC_X in 1) ORC_PAT='devices: model' ;; *) ORC_PAT='aps: model' ;; esac
  ORC_O=$(python3 -B tools/data-oracle.py truth "out/$P-oracle-fx$ORC_X.json" tools/gen-testdata.py tools/README.md 2>&1); ORC_C=$?
  ORC_V=$(printf '%s' "$ORC_O" | sed -n 's/.*-- FAIL: //p')
  if [ -s "out/$P-oracle-fx$ORC_X.json" ] && [ "$ORC_C" = 1 ] && [ -n "$ORC_V" ] && printf '%s' "$ORC_V" | grep -qF -- "$ORC_PAT"; then
    ORC_R=$((ORC_R + 1))
  fi
  ORC_W="$ORC_W [copy $ORC_X: exit $ORC_C, $(printf '%s' "${ORC_V:-$ORC_O}" | cut -c1-70)]"
done
ORC_TBOK=0; [ "$ORC_M1" = 1 ] && [ "$ORC_M2" = 1 ] && [ "$ORC_R" = "$ORC_N" ] && ORC_TBOK=1
rowif "data oracle ground truth bites: $ORC_R/$ORC_N devices.json copies RED (a dual-band box loses its second radio, one AP more, an MBSSID member less)" [ "$ORC_TBOK" = 1 ]
[ "$ORC_TBOK" = 1 ] || echo "    target lines: dual-band member $ORC_M1, MBSSID member $ORC_M2;$ORC_W"

# ---- 4. the sensor bites: the same machinery against a page copy with three planted faults must be RED in exactly those classes.
#   (a) the randomised/locally administered BSSIDs are no longer excluded from the device logic  => devices(), deviceOf(), stats.devices
#   (b) an ESS set counts only from three devices                                                => stats.essMerged
#   (c) probing clients are counted twice (clients = free + assoc + probing)                     => stats.clients
# Each target line exists once and each fault changes exactly that line; the copy boots without errors (a load failure is an unplanned finding).
ORC_L1='^    if (bssidLocal(b)) continue;'
ORC_L2='c\.deviceIds\.length >= 2 && !isEssExpanded(id)) n++; }); return n; }'
ORC_L3='^  const clients = free + assoc;$'
ORC_E1=$(grep -c -- "$ORC_L1" "$H"); ORC_E2=$(grep -c -- "$ORC_L2" "$H"); ORC_E3=$(grep -c -- "$ORC_L3" "$H")
ORC_PG="out/$P-oracle-probe.html"
sed -e "s/$ORC_L1.*\$/    \/\/ (locally administered exclusion removed by the probe)/" \
    -e 's/c\.deviceIds\.length >= 2 && !isEssExpanded(id)) n++; }); return n; }/c.deviceIds.length >= 3 \&\& !isEssExpanded(id)) n++; }); return n; }/' \
    -e 's/^  const clients = free + assoc;$/  const clients = free + assoc + probing;/' "$H" > "$ORC_PG"
ORC_D=$(diff "$H" "$ORC_PG" | grep -c '^<')
ORC_HKEEP=$H; H=$ORC_PG   # runq serves $H: point it at the copy for this one call, then put it back
runq "$ORC_B" "$ORC_Q" "out/$P-oracle-probe" --wait 2 --fps 0 --ready "$ORC_RDY" --eval-timeout 120 --eval "$ORC_JS(\"run\")" > "out/$P-oracle-probe.txt" 2>&1
H=$ORC_HKEEP
ORC_PV=$(python3 -B tools/data-oracle.py judge "out/$P-oracle-probe.json" "$ORC_B" "$H" - probe); ORC_PC=$?
ORC_POK=0; [ "$ORC_E1" = 1 ] && [ "$ORC_E2" = 1 ] && [ "$ORC_E3" = 1 ] && [ "$ORC_D" = 3 ] && [ "$ORC_PC" = 0 ] && ORC_POK=1
rowif "data oracle sensor bites: page with three planted faults is RED, $ORC_PV" [ "$ORC_POK" = 1 ]
[ "$ORC_POK" = 1 ] || echo "    target lines: bssidLocal $ORC_E1, essMerged $ORC_E2, clients $ORC_E3; changed lines $ORC_D"
