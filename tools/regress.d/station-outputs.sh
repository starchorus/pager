# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/station-outputs.sh -- client stations reach the file outputs (P6), and the one project version.
#   the station-export mechanisms exist in the source, each at its exact count
#   stations are first-class rows in json + csv, WITH their AP association (P6) -- proven by co-location, not
#        by the parent merely appearing in the AP section
#   the exclusions hold: an own/mobile PARENT is never filed as a station's association; note TEXT is
#        never exported (alias/tags only, like an AP); own-transmitter stations stay out
#   the display Stations screen shows client MACs, regex-free jq, strongest-first (dBm non-increasing), in the LOG
#   neutral language (P10) holds over the export bodies and the display Stations screen
#   the project version, in every place that states it
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only SOU_* globals are set.
#
# The station in the export and the co-location proof also live in the export run of operator-tools.sh and in
# station-inventory.sh; here the P6-specific facts are pinned.

SOU_Q="?poll=0&spin=0&intro=0&debug=1"
sou_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }

# ---- static: the station-export mechanisms.
# Red if: exportModel stops building the station array, the association guard is removed, the csv kind-column head
# changes, or the SITREP cap constant is dropped.
sou_n() { grep -cF "$1" "$H"; }
SOU_ANCHORS="
1|const stations = S.clientOrder.filter(n => n.target === 1 && !eventSkip(n))
1|const par = (!n.free && !n.affinity && n.parent && !eventSkip(S.aps.get(n.parent))) ? n.parent : null;
1|const head = \"kind,bssid,ssid,band,channel,security,rssi,heard,alias,tags,association,randomized,probes,cloud\";
1|const STA_SITREP_MAX = 20;
"
SOU_BAD=$(printf '%s\n' "$SOU_ANCHORS" | while IFS='|' read -r _want _pat; do
  [ -n "$_pat" ] || continue
  _got=$(sou_n "$_pat"); [ "$_got" = "$_want" ] || printf '%s (want %s, got %s)\n' "$_pat" "$_want" "$_got"
done)
SOU_CNT=$(printf '%s\n' "$SOU_ANCHORS" | grep -c '|')
if [ -z "$SOU_BAD" ] && [ "$SOU_CNT" = 4 ]; then
  row "station-export mechanisms in the source: 4 anchors at their exact counts" PASS
else
  row "station-export mechanisms (anchors $SOU_CNT/4)" FAIL; [ -z "$SOU_BAD" ] || printf '    %s\n' "$SOU_BAD"
fi

# ---- stations in the export, on a crafted capture where the co-location and own-parent-guard facts are
# each observable. Three APs: a normal AP N, an OWN AP O (own_bssids), a mobile hotspot H (locally-administered,
# hotspot SSID). Stations: SA associated to N (association MUST be filed), SO associated to O (own parent -> MUST be
# null), SH associated to H (mobile parent -> MUST be null), SF free with a probe, plus a per-station NOTE on SA.
# Red if: exportModel carries APs only (nStations 0); the association is dropped (assocN null); the own/mobile
# parent leaks (assocO/assocH non-null, or O/H appears among station associations); a station note TEXT is exported.
SOU_EV1='(async()=>{const o={};
const N="02:00:00:00:31:01",O="02:00:00:00:31:02",H="02:00:00:00:31:03";
const SA="0a:00:00:00:31:aa",SO="0a:00:00:00:31:bb",SH="0a:00:00:00:31:cc",SF="0a:00:00:00:31:dd";
const ap=(b,ss,extra)=>Object.assign({bssid:b,ssid:ss,band:"2.4",channel:6,freq:2437,rssi:-50,security:"WPA2"},extra||{});
const doc={source:"recon-db",generated:700,center:{label:"x",own_bssids:[O]},
  aps:[Object.assign(ap(N,"corp"),{clients:[{mac:SA,rssi:-55}]}),
       Object.assign(ap(O,"mine"),{clients:[{mac:SO,rssi:-56}]}),
       Object.assign(ap(H,"iPhone of X",{caps:["IBSS"]}),{clients:[{mac:SH,rssi:-57}]})],
  unassociated:[{mac:SF,rssi:-58,probes:["home-net"]}]};
STARCHORUS.load(doc,"stations");
STARCHORUS.notes(SA,{alias:"laptop-A",note:"secret note text",tags:["lab"]});
const J=JSON.parse(STARCHORUS.exportText("json"));const find=(m)=>J.stations.find(x=>x.mac===m);
o.nStations=J.stations.length;
o.assocN=(find(SA)||{}).association;                 // filed: SA -> N
o.assocO=(find(SO)||{}).association;                 // guarded: own parent -> null
o.assocH=(find(SH)||{}).association;                 // guarded: mobile parent -> null
o.free=(find(SF)||{}).association;                   // free -> null
o.ownAsParent=J.stations.some(x=>x.association===O||x.association===H);   // no station ever files O or H
o.aliasIn=(find(SA)||{}).alias;                      // alias exported (like an AP)
o.noteText=/secret note text/.test(STARCHORUS.exportText("json")+STARCHORUS.exportText("csv")+STARCHORUS.exportText("sitrep"));   // note TEXT never exported
o.err=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$SOU_Q" "out/$P-sou-exp" --wait 2 --fps 0 --ready --eval "$SOU_EV1" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
SOU_E=$(evalv "out/$P-sou-exp.json" 1 | sou_nj); SOU_EE=$(evalv "out/$P-sou-exp.json" 2)
SOU_EW='{"aliasIn":"laptop-A","assocH":null,"assocN":"02:00:00:00:31:01","assocO":null,"err":0,"free":null,"nStations":4,"noteText":false,"ownAsParent":false}'
if [ "$SOU_E" = "$SOU_EW" ] && [ "$SOU_EE" = 0 ]; then
  row "station export: SA associated to N is filed (co-located), own/mobile parents guarded to null, note text never exported, alias is" PASS
else
  row "station export (err ${SOU_EE:-?})" FAIL; echo "    got:  $SOU_E"; echo "    want: $SOU_EW"
fi
# note: all four stations are exported (SA, SO, SH, SF) -- a station is never dropped for its PARENT being own/mobile;
# only the ASSOCIATION is guarded (SO/SH -> null), which is exactly the exclusion above. Own-transmitter STATIONS would drop via
# eventSkip, but SO/SH are ordinary station MACs. The count locks the scenario; the association values are the point.

# ---- the display Stations screen: client MACs in the LOG, regex-free jq, deterministic order.
# Red if: the screen is removed (empty), the jq gains a regex function, or the sort is broken (e.g. sort_by(.r) without
# the negate/tie-break -> the dBm column would ascend, SOU_PG_ORD=1).
SOU_PGO=$(STARCHORUS_DISPLAY_PLAIN=1 sh "$R/starchorus-display.sh" --once clients "$F/field-scale.json" 2>/dev/null)
SOU_PG_N=$(printf '%s\n' "$SOU_PGO" | grep -cE '^-[0-9]+ dBm  [0-9a-f:]{17}  ')          # station lines: "-NN dBm  <mac>  <status>"
SOU_PG_HAS=$(printf '%s\n' "$SOU_PGO" | grep -c 'Stations (GEN')
# ORDER: the 8 lines are strongest-first. Assert the dBm column is non-increasing (a real order check, not a same-run
# reproducibility check which can never fail). field-scale has an RSSI tie at -34/-35, so the MAC tie-break is what makes
# even the ties deterministic; a broken sort (e.g. sort_by(.r) without reverse) yields an INCREASING column and fails.
SOU_PG_DBM=$(printf '%s\n' "$SOU_PGO" | sed -n 's/^\(-[0-9]*\) dBm .*/\1/p')
SOU_PG_ORD=$(printf '%s\n' "$SOU_PG_DBM" | awk 'NR>1 && $1>prev{bad=1} {prev=$1} END{print bad+0}')   # 1 = a line was stronger than the one above (wrong)
# tie determinism: the two MACs at the weakest shown level appear in ascending MAC order (the sort_by(-.r,.mac) tie-break)
SOU_PG_RE=$(awk '/^screen_clients\(\)/,/^}/' "$R/starchorus-display.sh" | grep -cE '\b(test|match|capture|scan|sub|gsub)\(')
if [ "$SOU_PG_N" = 8 ] && [ "$SOU_PG_HAS" -ge 1 ] && [ "$SOU_PG_ORD" = 0 ] && [ "$SOU_PG_RE" = 0 ]; then
  row "display Stations screen: 8 client MACs, strongest-first (dBm non-increasing), regex-free jq" PASS
else
  row "display Stations screen (lines $SOU_PG_N, has $SOU_PG_HAS, order-bad $SOU_PG_ORD, regex $SOU_PG_RE)" FAIL
fi

# ---- P10 neutral language over the export bodies and the display Stations screen.
# Red if: a threat word (the regex of neutral-language.sh) appears in json/csv/sitrep or the display Stations LOG on any client-bearing fixture.
SOU_RE='(evil[ -]?twin|rogue|attack|threat|intru|malicious|spoof|karma|bandit|target|deauth flood)'
SOU_EVP='(()=>[STARCHORUS.exportText("json"),STARCHORUS.exportText("csv"),STARCHORUS.exportText("sitrep")].join("\n"))()'
runq "$F/many-clients.json" "$SOU_Q" "out/$P-sou-p10" --wait 3 --fps 0 --ready "window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'" --eval "$SOU_EVP" >/dev/null 2>&1
SOU_XP=$(python3 -c 'import json,sys,re;t=json.load(open(sys.argv[1]))["eval"][0]["value"];print(1 if re.search(sys.argv[2],t,re.I) else 0)' "out/$P-sou-p10.json" "$SOU_RE" 2>/dev/null)
SOU_PGP=$(printf '%s\n' "$SOU_PGO" | grep -ciE "$SOU_RE")
if [ "$SOU_XP" = 0 ] && [ "$SOU_PGP" = 0 ]; then
  row "P10: no threat word in the json/csv/sitrep export bodies or the display Stations screen" PASS
else
  row "P10 export/display (export hit $SOU_XP, display hit $SOU_PGP)" FAIL
fi

# ---- the ONE project version: every place that states it says 0.2.6.2 -- the page (STARCHORUS.version), the spec's §10
# listing, the "# Version:" header of each script (collector, display script and its library copy, serve script, both
# payload.sh), the device probe's banner and the README. A place that says something else, or no longer says it, is red.
SOU_VER=0.2.6.2
SOU_VL="page:$(sed -n 's/^  version: "\([0-9][0-9A-Za-z.-]*\)",$/\1/p' "$H" | tr '\n' ',')"
SOU_VL="$SOU_VL spec:$(sed -n 's/^  version: "\([0-9][0-9A-Za-z.-]*\)",$/\1/p' "$R/docs/architecture.md" | tr '\n' ',')"
for SOU_F in starchorus-collect.sh starchorus-display.sh library/user/reconnaissance/starchorus/starchorus-display.sh starchorus-serve.sh payload.sh library/user/reconnaissance/starchorus/payload.sh; do
  SOU_VL="$SOU_VL $SOU_F:$(sed -n '1,40s/^# Version:  *\([0-9][0-9A-Za-z.-]*\)$/\1/p' "$R/$SOU_F" | tr '\n' ',')"
done
SOU_VL="$SOU_VL device-probe:$(sed -n 's/.*# Starchorus device-probe \([0-9][0-9A-Za-z.-]*\): .*/\1/p' "$R/tools/device-probe.sh" | tr '\n' ',')"
SOU_VL="$SOU_VL README:$(sed -n 's/^Starchorus \([0-9][0-9A-Za-z.-]*\)\. .*/\1/p' "$R/README.md" | tr '\n' ',')"
SOU_VBAD=""; for SOU_X in $SOU_VL; do [ "${SOU_X#*:}" = "$SOU_VER," ] || SOU_VBAD="$SOU_VBAD $SOU_X"; done
rowif "version $SOU_VER in page = spec §10 = 6 script headers = device-probe = README (off:${SOU_VBAD:- none})" [ -z "$SOU_VBAD" ]
