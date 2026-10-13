# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/station-inventory.sh -- the fourteen places where the page decides whether a key may be a station.
#   (1) each site pinned at its exact count in the page source
#   (2) the behaviour: a station is first class for identity, notes, import, history, freshness and the export (P1, P2, P6)
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only SIN_* globals are set.
#
# Why this drop-in exists. Whether a station key is accepted is decided at a small set of places in the page (the observed()
# gate, the history push and sweep, the freshness fields of the client shapes, the homing gate, the baseline caps, the
# export). A change that quietly re-restricts one of them to access points would leave every other row green. This file
# names each place once, so that a place which changes or disappears without a decision turns the table red instead of
# quietly passing. A legitimate change of one of these places rewrites its anchor here; the SET of fourteen sites never
# shrinks.
#
# One Chrome run (2). (1) is static and reads the page source only.

# ---- (1) the decision points, by exact occurrence count in the page source.
# Each anchor is a fixed string (grep -F): no regex, so a rename cannot be laundered by a character
# class. observed( is the gate for identity, notes and import (AP or station, present or in the baseline); the station line
# ADMITS a present station; the homing gate accepts a present AP or station; histPush( covers APs and stations; the history
# sweep keeps a series while a node of EITHER kind carries the key; newClient() and pubNode()'s client branch carry
# freshTier and ageS (D1 for stations).
sin_n() { grep -cF "$1" "$H"; }
SIN_ANCHORS="
7|observed(
1|const c = S.clients.get(b); if (c && c.target === 1) return true;
1|(!seenAp.has(h.bssid) && !seenCl.has(h.bssid))
3|histPush(
1|if (!rp) histPush(n, a.rssi, gen);
1|if (!live(S.aps.get(id)) && !live(S.clients.get(id))
1|const fr = freshOf(a.last_seen, gen);
2|S.ev.newStations++
2|not observed
1|BASELINE_MAX = 500
1|access points AND stations (a received association may be filed
1|doc.unassociated.length * 160
1|ageS: null, freshTier: null, freshA: 1, freshAT: 1, sparkDirty: true, baseState: null
1|last_seen: n.last_seen, ageS: n.ageS, freshTier: n.freshTier, isNew: isNewAp(n)
"
# the measured counts are written out as evidence (out/PREFIX-sin-anchors.txt)
printf '%s\n' "$SIN_ANCHORS" | while IFS='|' read -r _want _pat; do
  [ -n "$_pat" ] || continue
  printf '%s=%s (want %s)\n' "$_pat" "$(sin_n "$_pat")" "$_want"
done > "out/$P-sin-anchors.txt"
SIN_BAD=$(printf '%s\n' "$SIN_ANCHORS" | while IFS='|' read -r _want _pat; do
  [ -n "$_pat" ] || continue
  _got=$(sin_n "$_pat")
  [ "$_got" = "$_want" ] || printf '%s (want %s, got %s)\n' "$_pat" "$_want" "$_got"
done)
# vacuity guard: the anchor list itself must not be empty or truncated (14 anchors, all non-blank)
SIN_COUNT=$(printf '%s\n' "$SIN_ANCHORS" | grep -c '|')
if [ -z "$SIN_BAD" ] && [ "$SIN_COUNT" = 14 ]; then
  row "station decision points: 14 anchors at their exact counts" PASS
else
  row "station decision points (anchors $SIN_COUNT/14)" FAIL
  [ -z "$SIN_BAD" ] || printf '    %s\n' "$SIN_BAD"
fi

# ---- (2) the behaviour, on many-clients.json: a station is accepted everywhere a key is taken, and the SAME
# call on an access point succeeds as well; an unheard MAC is still refused. The refusal is what keeps the
# acceptance honest: an API that accepted everything would fail the import expectation.
SIN_Q="?poll=0&spin=0&intro=0&debug=1"
SIN_EV='(async()=>{
const o={};
const aps=STARCHORUS.nodes("ap").map(n=>n.id).sort();const cls=STARCHORUS.nodes("client").map(n=>n.id).sort();
o.have=(aps.length>=2)+","+(cls.length>=2);
const A=aps[0],C=cls[0];
STARCHORUS.setIdentity(C,"friend");STARCHORUS.setIdentity(A,"friend");
o.identCl=[STARCHORUS.identity(C),String(C in STARCHORUS.identities())].join(",");
o.identAp=[STARCHORUS.identity(A),String(A in STARCHORUS.identities())].join(",");
o.notes=[(STARCHORUS.notes(C,{alias:"x"})||{}).alias,(STARCHORUS.notes(A,{alias:"x"})||{}).alias].join(",");
o.import=[STARCHORUS.libraryImport(C+" neutral").message||"(none)",STARCHORUS.libraryImport("de:ad:be:ef:00:99 neutral").message].join("/");
o.hist=[((STARCHORUS.hist(C)||{samples:[]}).samples.length>0),((STARCHORUS.hist(A)||{samples:[]}).samples.length>0)].join(",");
o.homing=String(STARCHORUS.homing());
o.leak=String([STARCHORUS.exportText("json"),STARCHORUS.exportText("csv"),STARCHORUS.exportText("sitrep")].some(t=>cls.some(c=>t.indexOf(c)>=0)));
o.apInExport=String(STARCHORUS.exportText("json").indexOf(A)>=0);
// D1 needs a DATED capture. many-clients.json carries no last_seen at all, so every node there is
// undated and the freshness half would be vacuous.
// One small deterministic document, loaded last: generated 1000, last_seen 980 -> age 20 s -> tier 0
// for the access point AND for the station beneath it.
const FA="02:00:5e:a0:00:01",FC="02:00:5e:b0:00:01";
STARCHORUS.load({source:"recon-db",generated:1000,center:{label:"x"},aps:[{bssid:FA,ssid:"a",band:"2.4",channel:6,rssi:-50,security:"WPA2",last_seen:980,clients:[{mac:FC,rssi:-60,last_seen:980}]}],unassociated:[]},"station-fresh");
o.fresh=[STARCHORUS.node(FC).freshTier===0,STARCHORUS.node(FA).freshTier===0].join(",");
o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq "$F/many-clients.json" "$SIN_Q" "out/$P-sin-behave" --wait 3 --fps 0 --eval "$SIN_EV" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
SIN_B=$(evalv "out/$P-sin-behave.json" 1 | python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":")))' 2>/dev/null)
SIN_BE=$(evalv "out/$P-sin-behave.json" 2)
SIN_BW=$(python3 -c '
import json
print(json.dumps({
  "have": "true,true",
  "identCl": "friend,true",            # P2: an observed station is taken
  "identAp": "friend,true",            # the same call on an access point
  "notes": "x,x",                      # a station carries a note, as an AP does
  "import": "(none)/1 rejected: not observed",   # the station line is imported; an unheard MAC is refused
  "hist": "true,true",                 # the station has a series, as the access point does
  "fresh": "true,true",                # D1: tier 0 for the station and for the AP
  "homing": "null",
  "leak": "true",                      # P6: a station MAC appears in the export
  "apInExport": "true",                # ... and so does the access point
  "errors": 0,
}, sort_keys=True, separators=(",", ":")))
')
if [ "$SIN_B" = "$SIN_BW" ] && [ "$SIN_BE" = 0 ]; then
  row "station first class: identity/notes/import, history/freshness, AND the export carries its MAC (P6)" PASS
else
  row "station first class where it should be (err ${SIN_BE:-?})" FAIL
  echo "    got:  $SIN_B"; echo "    want: $SIN_BW"
fi
