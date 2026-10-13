#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/regress.sh — full non-regression per docs/architecture.md §11.0 (global criteria)
# and the harness rows. Dev machine only. This is tier T2 (tools/README.md).
# usage: sh tools/regress.sh [PREFIX]    (any cwd; writes out/PREFIX-*.json/png, prints a table)
# exit 0 = every row PASS, 1 = at least one FAIL, 2 = setup problem.
# Preflight first (harness.sh PF_TOOLS_FULL: exit 2 + "MISSING: tool"); wall time per phase and drop-in: out/PREFIX-timing.txt.
# The Chrome-free rows (page/collector/display/fixture/harness rules, baselines and floors BASE_*/MIN_*) live in tools/static.sh,
# which tools/quick.sh (tier T1, the pre-commit hook) runs too; they come first here, then the Chrome rows, then the drop-ins.
# shellcheck source-path=SCRIPTDIR source=harness.sh
. "$(dirname "$0")/harness.sh" || exit 2
# Preflight: every tool this run needs, checked BEFORE any row: a missing one is "MISSING: tool" and exit 2, not follow-up FAILs.
# sqlite3 is the one deliberate switch: ALLOW_NO_SQLITE=1 runs without it and the collector selftest row is then "NOT COVERED".
# shellcheck disable=SC2086   # the tool list is a word list on purpose
preflight $PF_TOOLS_FULL || exit 2
[ "${STARCHORUS_PREFLIGHT_ONLY:-0}" != 1 ] || { echo "preflight: ok (T2)"; exit 0; }   # probe mode of tools/regress.d/preflight.sh
P=${1:-rg}; cd "$R" || exit 2
tm_begin "out/$P-timing.txt"   # wall time per phase and drop-in, whole seconds; read by the last row
# shellcheck source-path=SCRIPTDIR source=static.sh
. "$R/tools/static.sh"
tm_lap "phase static.sh rows"

EV1="STARCHORUS.errors().length"
EV2="STARCHORUS.stats().themeErrors"
EV3="STARCHORUS.themeCheck().ok && (STARCHORUS.setTheme('wargames'),STARCHORUS.themeCheck().ok) && (STARCHORUS.setTheme('whitehall'),STARCHORUS.themeCheck().ok) && (STARCHORUS.setTheme('foundation'),true)"
# EV4: the 10 geometric + 2 layout-state layoutInfo fields are identical in all three themes after a
# real tick (clock frozen in the eval after the fade-in; setTheme; wait 300; settle; frame). labelsDrawn and
# labelCollisions are font/render-dependent and excluded (spec §4.7).
EV4="(async()=>{STARCHORUS.setFixedTime(0);const G=['minClientDistancePx','p5ClientDistancePx','medianClientDistancePx','overlapsPx','clientsInStarZone','clientsInApHalo','freeInOrbitZone','apMinGapPx','apRadiusErrPx','clusterCount','settled','iterations'];const o=[];for(const t of['foundation','wargames','whitehall']){STARCHORUS.setTheme(t);await STARCHORUS.wait(300);STARCHORUS.settle();STARCHORUS.frame();const L=STARCHORUS.layoutInfo();o.push(JSON.stringify(G.map(k=>L[k])))}STARCHORUS.setTheme('foundation');return o[0]===o[1]&&o[1]===o[2]&&o[0].indexOf('null')<0})()"
EV5="(STARCHORUS.frame(), STARCHORUS.perf().drawCalls.fillText)"
# EV6: fillText of one forced frame in every theme, "f/w/h" (budget rows)
EV6="(()=>{const o=[];for(const t of ['foundation','wargames','whitehall']){STARCHORUS.setTheme(t);STARCHORUS.frame();o.push(STARCHORUS.perf().drawCalls.fillText)}STARCHORUS.setTheme('foundation');STARCHORUS.frame();return o.join('/')})()"
# EVS: budget stress -- vendor lines on, reduced motion (WarGames cursor always drawn), every visible AP
# pinned (forced labels bypass maxLabels), one drawn AP locked; "f/w/h" with two vacuity markers:
# "!" = the locked AP has no kind:'label' entry in that theme (the id alone would also match the per-AP
# glyph/vendor/badge entries, so the kind filter is what makes the marker mean what it says),
# "?" = the WarGames cursor slot was not drawn in the wargames frame. budget() rejects both.
EVS="(()=>{STARCHORUS.setToggles({vendor:true});STARCHORUS.setReducedMotion(true);const aps=STARCHORUS.nodes('ap').filter(n=>n.visible).sort((a,b)=>b.rssi-a.rssi||(a.id<b.id?-1:1));if(aps.length<10)return 'vacuous:'+aps.length;aps.forEach(n=>STARCHORUS.pin(n.id,true));STARCHORUS.frame();const drawn=new Set(STARCHORUS.labels().filter(l=>l.kind==='label').map(l=>l.id));const L=(aps.find(n=>drawn.has(n.id))||aps[0]).id;STARCHORUS.select(L);const o=[];for(const t of ['foundation','wargames','whitehall']){STARCHORUS.setTheme(t);STARCHORUS.frame();const ls=STARCHORUS.labels();o.push(STARCHORUS.perf().drawCalls.fillText+(ls.some(l=>l.id===L&&l.kind==='label')?'':'!')+(t==='wargames'&&!ls.some(l=>l.kind==='cursor')?'?':''))}STARCHORUS.setTheme('foundation');STARCHORUS.frame();return o.join('/')})()"
budget() { # budget "f/w/h" LIMIT MIN → 0 iff three integers, each MIN..LIMIT, and no vacuity marker in ANY slot
  printf '%s\n' "$1" | awk -F/ -v L="$2" -v M="$3" 'NF==3 && $0 !~ /[!?]/ { ok=1; for (i=1;i<=3;i++) { v=$i; if (v !~ /^[0-9]+$/ || v+0 > L || v+0 < M) ok=0 } exit !ok } { exit 1 }'
}

# ---- 1-9 (+ active): verify.sh PASS + global evals per fixture, Foundation 2D
ft=""; ftbad=0
for f in demo legacy few-clients many-clients field-scale single-ap empty-none devices field-probes active; do
  fx=$([ $f = demo ] && echo demo || echo "$F/$f.json")
  out=$(sh tools/verify.sh "$H" "$fx" "out/$P-$f" --eval "$EV1" --eval "$EV2" --eval "$EV3" --eval "$EV4" --eval "$EV5" --eval "$EV6" 2>&1)
  res=$(printf '%s\n' "$out" | sed -n 's/^result: *//p'); fps=$(printf '%s\n' "$out" | sed -n 's/^fps: *\([0-9]*\).*/\1/p')
  vals=$(python3 -c 'import json,sys;r=json.load(open(sys.argv[1]));print(" ".join(json.dumps(e["value"]) for e in r.get("eval",[])))' "out/$P-$f.json")
  # shellcheck disable=SC2086   # word-split the eval values on purpose
  set -- $vals
  ok=PASS; [ "$res" = PASS ] || ok=FAIL; [ "$1" = 0 ] || ok=FAIL; [ "$2" = 0 ] || ok=FAIL; [ "$3" = true ] || ok=FAIL; [ "$4" = true ] || ok=FAIL; [ "$5" -le 30 ] 2>/dev/null || ok=FAIL
  row "verify+globals $f (fps $fps, fillText $5)" "$ok"
  v6=$(evalv "out/$P-$f.json" 6); ft="$ft $f=$v6"; budget "$v6" 30 0 || ftbad=1
done
rowif "2D fillText ≤ 30 in all 3 themes, 10 fixtures" [ "$ftbad" = 0 ]
[ "$ftbad" = 0 ] || echo "   $ft"
# 3D run: EV1 EV4 EV5 EV6 in one run (one merged row)
runq "$F/many-clients.json" "?view=3d&intro=0" "out/$P-3d" --eval "$EV1" --eval "$EV4" --eval "$EV5" --eval "$EV6" >/dev/null 2>&1
v=$(python3 -c 'import json,sys;r=json.load(open(sys.argv[1]));print(" ".join(json.dumps(e["value"]) for e in r["eval"]))' "out/$P-3d.json")
# shellcheck disable=SC2086
set -- $v
if [ "$1" = 0 ] && [ "$2" = true ] && [ "$3" -le 24 ] 2>/dev/null; then row "3D many-clients fillText $3 <= 24, EV4 $2" PASS; else row "3D many-clients fillText $3 <= 24, EV4 $2" FAIL; fi
v6=$(evalv "out/$P-3d.json" 4)
rowif "3D fillText ≤ 24 all themes, many-clients ($v6)" budget "$v6" 24 0
for vw in 2d 3d; do
  lim=30; [ "$vw" = 3d ] && lim=24
  runq "$F/field-scale.json" "?intro=0&poll=0&spin=0&view=$vw" "out/$P-stress-$vw" --wait 5 --fps 0 --eval "$EV1" --eval "$EVS" >/dev/null 2>&1
  e1=$(evalv "out/$P-stress-$vw.json" 1); vs=$(evalv "out/$P-stress-$vw.json" 2)
  if [ "$e1" = 0 ] && budget "$vs" "$lim" 10; then row "$vw stress fillText ≤ $lim per theme ($vs)" PASS; else row "$vw stress fillText ≤ $lim per theme ($vs)" FAIL; fi
done

tm_lap "phase chrome rows (fixtures, 3D, stress)"
# A drop-in that is renamed or lost takes its rows with it and the table still reads "0 FAIL", so the SET
# of drop-ins is pinned by name (a count would miss a rename). Extend it deliberately in the commit that adds a drop-in.
DROPINS="contrast edge-layout doc-drift jq-noregex display-selftest legal neutral-language theme-schema source-truth legend labels-particles ap-models collector-fields observations operator-tools channel-time theme-wargames theme-whitehall theme-foundation doc-binding small-screen display-parity theme-details text-budget station-inventory station-models station-tools station-outputs stop-scope payload-ui hak5-package data-oracle doc-truth hook-behavior ingest-fuzz net-runtime order-invariance mutation-probe preflight"
dih=$(for x in tools/regress.d/*.sh; do [ -f "$x" ] && basename "$x" .sh; done | LC_ALL=C sort | tr '\n' ' ')
# shellcheck disable=SC2086   # DROPINS is a word list on purpose
diw=$(printf '%s\n' $DROPINS | LC_ALL=C sort | tr '\n' ' ')
rowif "regress.d drop-ins ($dih)" [ "$dih" = "$diw" ]
[ "$dih" = "$diw" ] || echo "    want: $diw"
# harness.sh promises that runq touches no caller variable outside the _rq_* prefix (f q p i rc are the
# names most likely to leak); sentinels make that promise a row instead of a comment.
f=SENTF; q=SENTQ; p=SENTP; i=SENTI; rc=SENTR
runq demo "?intro=0&poll=0&spin=0" "out/$P-hyg" --wait 1 --fps 0 >/dev/null 2>&1
rowif "runq leaks no caller globals ($f/$q/$p/$i/$rc)" [ "$f/$q/$p/$i/$rc" = SENTF/SENTQ/SENTP/SENTI/SENTR ]
# tier T1 runs the same static rules on the index (the pre-commit hook): the tool itself must work, from here too.
# Its rows are the ones above, so this is a deliberate double run (about 11 s, no selftest); the row counts its own output.
sh tools/quick.sh "$P-q" > "out/$P-quick.txt" 2>&1; qkrc=$?
qkp=$(grep -c ' PASS$' "out/$P-quick.txt"); qkf=$(grep -c ' FAIL$' "out/$P-quick.txt")
# Exit 0 and 0 FAIL are not enough: a quick.sh that no longer runs its drop-ins or the denylist rows still exits 0. So the
# row also demands a floor of PASS rows (MIN_QUICK_ROWS) and, by NAME, the rows quick.sh itself adds: one "quick drop-in NAME
# ran" per QUICK_DROPINS entry (derived, not typed here) and the two denylist rows.
qkmiss=""
for qkn in $QUICK_DROPINS; do grep -q "^quick drop-in $qkn ran (" "out/$P-quick.txt" || qkmiss="$qkmiss drop-in:$qkn"; done
grep -q '^denylist selftest (pos' "out/$P-quick.txt" || qkmiss="$qkmiss denylist-selftest"
grep -q '^denylist --extended = 0 (' "out/$P-quick.txt" || qkmiss="$qkmiss denylist-extended"
qkok=0; [ "$qkrc" = 0 ] && [ "$qkf" = 0 ] && ge "$qkp" "$MIN_QUICK_ROWS" && [ -z "$qkmiss" ] && qkok=1
rowif "quick.sh (T1): exit $qkrc, $qkp PASS (≥ $MIN_QUICK_ROWS), $qkf FAIL, missing rows:${qkmiss:- none}" [ "$qkok" = 1 ]
[ "$qkok" = 1 ] || sed 's/^/    /' "out/$P-quick.txt" | tail -n 30 | cut -c1-200

tm_lap "phase hygiene, drop-in pin, quick.sh"
# ---- topic rows: every topic drops its rows into tools/regress.d/<topic>.sh
# (sourced in glob order; may use row/rowif/runq/runseq/evalv/ev3/ev3eq/nomatch/budget, $P $F $H $R)
for rd in tools/regress.d/*.sh; do
  [ -f "$rd" ] || continue
  # shellcheck disable=SC1090   # drop-ins are shellchecked by the row above
  . "./$rd"
  tm_lap "drop-in $(basename "$rd" .sh)"
done
tm_total
# The timing file has to name EVERY drop-in that exists (derived from the directory, not typed here) and the total: a lap that
# went missing shows here. It measures only; nothing is parallelised (the drop-ins share out/).
tmnames=$(for x in tools/regress.d/*.sh; do [ -f "$x" ] && basename "$x" .sh; done | tr '\n' ' ')
# shellcheck disable=SC2086   # a word list on purpose
tml=$(tm_check "out/$P-timing.txt" $tmnames); tmrc=$?
rowif "timing out/$P-timing.txt: $tml" [ "$tmrc" = 0 ]
# a NOT COVERED row is neither green nor red; it must not pass unnoticed at the end of a long table
[ "$ncov" = 0 ] || echo "NOT COVERED: $ncov row(s) above were not run on purpose (ALLOW_NO_SQLITE=1); that is not a PASS."
exit $fail
