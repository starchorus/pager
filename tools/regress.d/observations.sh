# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/observations.sh -- what the page remembers and what it derives.
#   change log per AP · baseline + diff + ghosts (D19) · observations panel (W) · P1/P3/P4/P8/P10 · keys, query, persistence, layout
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only OBV_* globals are set.
#
# Runs WITHOUT ?fixed: nodes must fade in for the drawing checks, and the dwell gate of the observations counts captures, not seconds.

OBV_Q="?poll=0&spin=0&intro=0&debug=1"
obv_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }

# ---- change log + baseline + P3: change log, baseline, ghosts, own/mobile exclusion, storage
OBV_EVB='(async()=>{
const ap=(n,ch,sec,ssid,extra)=>Object.assign({bssid:"02:00:00:00:05:"+String(n).padStart(2,"0"),ssid:ssid==null?"k"+n:ssid,band:"2.4",channel:ch,freq:2407+5*ch,rssi:-50-n,security:sec||"WPA2",last_seen:1789300000},extra||{});
const mk=(g,aps,extra)=>Object.assign({source:"recon-db",generated:g,aps,unassociated:[]},extra||{});
const id=(n)=>"02:00:00:00:05:"+String(n).padStart(2,"0"),o={};
STARCHORUS.load(mk(100,[ap(1,6),ap(2,1),ap(3,11),ap(4,6),ap(5,1),ap(6,11)]),"chg");
STARCHORUS.load(mk(105,[ap(1,11),ap(2,1),ap(3,11),ap(4,6),ap(5,1),ap(6,11)]),"chg");
STARCHORUS.load(mk(110,[ap(1,11,"WPA3"),ap(2,1),ap(3,11),ap(4,6),ap(5,1),ap(6,11)]),"chg");
STARCHORUS.load(mk(115,[ap(1,11,"WPA3",null,{freq:2470}),ap(2,1,"WPA2",null,{freq:2413}),ap(3,11),ap(4,6),ap(5,1),ap(6,11)]),"chg");   // freq flutter only
o.chg=STARCHORUS.changes(id(1)).map(c=>c.kind+":"+c.from+">"+c.to).join(",");o.chgTotal=STARCHORUS.stats().changeEntries;
STARCHORUS.select(id(1));o.detail=(document.getElementById("detail-body").innerText.match(/Changes\s*([^\n]*)/)||[])[1];STARCHORUS.deselect();
o.setN=STARCHORUS.setBaseline();STARCHORUS.setToggles({baselineDiff:true});
const hop=[{freq:2412},{freq:2437},{freq:2462}],B=()=>{const b=STARCHORUS.baseline();return [b.new,b.gone,b.changed,b.ghosts].join("/")};
STARCHORUS.load(mk(120,[ap(1,11,"WPA3"),ap(2,1),ap(3,11),ap(4,6)],{channels:hop}),"chg");o.gone=B();STARCHORUS.frame();o.ghostRow=STARCHORUS.legendRows().filter(r=>r.kind==="ghost").map(r=>r.visible).join();
STARCHORUS.load(mk(125,[ap(1,11,"WPA3"),ap(2,1),ap(3,11),ap(4,6)]),"chg");o.noHop=B();
STARCHORUS.load(mk(130,[ap(1,11,"WPA3"),ap(2,1),ap(3,11),ap(4,6)],{channels:[{freq:2462}]}),"chg");o.oneCh=B();
STARCHORUS.load(mk(135,[ap(1,11,"WPA3"),ap(2,1),ap(3,11),ap(4,6),ap(9,3)],{channels:hop,center:{label:"x",own_bssids:[id(4)]}}),"chg");o.newOwn=B();
STARCHORUS.load(mk(140,[ap(1,11,"WPA3"),ap(2,1),ap(3,11),ap(4,6),ap(5,4,"WPA2"),ap(6,11)],{channels:hop}),"chg");o.changedRow=B();STARCHORUS.setToggles({baselineDiff:false});o.diffOff=B();STARCHORUS.setToggles({baselineDiff:true});
// P3: a probable phone hotspot raises no event, joins no baseline, and is only counted
STARCHORUS.load(mk(200,[ap(1,6),ap(2,6,"WPA2","iPhone of X",{bssid:"da:bb:cc:00:07:02"})]),"mob");
STARCHORUS.load(mk(205,[ap(1,6),ap(2,11,"WPA2","iPhone of X",{bssid:"da:bb:cc:00:07:02"})]),"mob");
o.mobChg=STARCHORUS.changes("da:bb:cc:00:07:02").length;o.mobEv=STARCHORUS.stats().events.changed;o.mobNode=STARCHORUS.node("da:bb:cc:00:07:02").mobile;
STARCHORUS.setBaseline();o.mobBase=Object.keys(JSON.parse(localStorage.getItem("starchorus.baseline.v1")).aps).join(",");
// P8/P1: <= 500 APs, APs only
const many=[];for(let i=0;i<600;i++)many.push({bssid:"02:00:0a:"+(i>>8).toString(16).padStart(2,"0")+":"+(i&255).toString(16).padStart(2,"0")+":01",ssid:"m"+i,band:"5",channel:36,rssi:-40-(i%50),security:"WPA2"});
STARCHORUS.load(mk(300,many,{}),"many");o.cap=STARCHORUS.setBaseline();o.stored=Object.keys(JSON.parse(localStorage.getItem("starchorus.baseline.v1")).aps).length;
o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$OBV_Q" "out/$P-obv-model" --wait 2 --fps 0 --ready --eval-timeout 90 --eval "$OBV_EVB" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
OBV_B=$(evalv "out/$P-obv-model.json" 1 | obv_nj); OBV_BE=$(evalv "out/$P-obv-model.json" 2)
OBV_BW=$(printf '%s' '{"chg":"channel:6>11,security:wpa2>wpa3","chgTotal":2,"detail":"ch 6 → 11 · security wpa2 → wpa3","setN":6,"gone":"0/2/0/2","ghostRow":"true","noHop":"0/0/0/0","oneCh":"0/1/0/1","newOwn":"1/2/0/2","changedRow":"0/0/1/0","diffOff":"0/0/0/0","mobChg":0,"mobEv":0,"mobNode":true,"mobBase":"02:00:00:00:05:01","cap":500,"stored":500,"errors":0}' | obv_nj)
if [ "$OBV_B" = "$OBV_BW" ] && [ "$OBV_BE" = 0 ]; then
  row "change log (channel+security = 2 entries, freq flutter 0), baseline gone 2 = 2 ghosts, no hop data -> never gone, own/mobile excluded, <= 500 APs" PASS
else
  row "change log + baseline (err ${OBV_BE:-?})" FAIL
  echo "    got:  $(printf '%s' "$OBV_B" | cut -c1-500)"; echo "    want: $OBV_BW"
fi

# ---- observations: dwell gate, groups, neutral wording (P10), watchlist, look-alike against the CONFIRMED set only, panel shares the legend
OBV_EVO='(async()=>{
const ap=(n,ch,sec,ssid,extra)=>Object.assign({bssid:"aa:bb:cc:00:06:"+String(n).padStart(2,"0"),ssid:ssid==null?"n"+n:ssid,band:"2.4",channel:ch,freq:2407+5*ch,rssi:-50-n,security:sec||"WPA2",last_seen:1789300000},extra||{});
const mk=(g,aps,extra)=>Object.assign({source:"recon-db",generated:g,aps,unassociated:[]},extra||{});
const o={};
const base=()=>[ap(1,6,"WPA2","HomeNet"),ap(2,6,"WPA2","HomeNet"),ap(3,11,"WPA2","HomeNat"),ap(4,2,"Open","cafe"),ap(5,1,"WEP","old"),ap(6,6,"WPA2",""),ap(7,3,"WPA2","multi",{responded_ssids:4}),ap(8,1,"WPA2","iPhone of X",{bssid:"da:bb:cc:00:06:08"}),ap(9,9,"WPA2 (TKIP)","tk"),ap(10,1,"WPA3/WPA2","tr")];
STARCHORUS.load(mk(100,base()),"obs");o.c1=STARCHORUS.observations().length;
STARCHORUS.load(mk(100,base()),"obs");o.same=STARCHORUS.observations().length;             // same generated: no capture, no tick
STARCHORUS.load(mk(105,base()),"obs");o.c2=STARCHORUS.observations().length;
STARCHORUS.setIdentity("aa:bb:cc:00:06:01","friend");
STARCHORUS.load(mk(110,base()),"obs");STARCHORUS.load(mk(115,base()),"obs");
const obs=STARCHORUS.observations();o.n=obs.length;o.groups=[...new Set(obs.map(x=>x.group))].join(",");const tx=obs.map(x=>x.text).join(" | ");
o.look=/same SSID from a BSSID outside your confirmed set: HomeNet \(1\)/.test(tx)&&/SSID close to a confirmed one: HomeNat ~ HomeNet \(1\)/.test(tx);
o.cfg=["2 open or WEP","other than 1, 6 and 11","without a broadcast SSID","transition mode","still use TKIP","mobile hotspots: 1","several SSIDs (up to 4)"].every(s=>tx.includes(s));
o.p10=/\b(evil[ -]?twin|rogue|attack(er)?|threat|intru(der|sion)|malicious|spoof(ed|ing)?|karma|bandit|target|deauth flood)\b/i.test(tx);
STARCHORUS.setIdentity("aa:bb:cc:00:06:01","unknown");STARCHORUS.load(mk(120,base()),"obs");STARCHORUS.load(mk(125,base()),"obs");o.noFriend=STARCHORUS.observations().some(x=>x.group==="Look-alike");   // no confirmed set -> no look-alike
STARCHORUS.watch("cafe",true);STARCHORUS.watch("nothere",true);STARCHORUS.load(mk(130,base()),"obs");STARCHORUS.load(mk(135,base()),"obs");
o.watch=STARCHORUS.observations().filter(x=>x.group==="Watchlist").map(x=>x.text).join("|");
const w=[];w.push(STARCHORUS.observations().some(x=>/not heard now/.test(x.text)));   // never seen -> never lost
const gone=base().filter(a=>a.ssid!=="cafe");STARCHORUS.load(mk(140,gone),"obs");STARCHORUS.load(mk(145,gone),"obs");w.push(STARCHORUS.observations().some(x=>/watched SSID not heard now: cafe/.test(x.text)));   // seen, gone, but no hop data
STARCHORUS.load(mk(150,gone,{channels:[{freq:2412}]}),"obs");STARCHORUS.load(mk(155,gone,{channels:[{freq:2412}]}),"obs");w.push(STARCHORUS.observations().some(x=>/watched SSID not heard now: cafe/.test(x.text)));   // hop data present
o.lost=w.join();
o.mobileExcluded=!STARCHORUS.observations().some(x=>/iPhone/.test(x.text));
STARCHORUS.setToggles({observations:true});const ob=document.getElementById("obs-body");o.panel=[!ob.hidden,getComputedStyle(document.getElementById("legend-body")).display,document.documentElement.dataset.obs].join("/");
STARCHORUS.setToggles({observations:false});o.panelOff=[document.getElementById("obs-body").hidden,getComputedStyle(document.getElementById("legend-body")).display!=="none"].join("/");
o.watchStored=localStorage.getItem("starchorus.watch.v1");
STARCHORUS.clearLocalData();o.cleared=Object.keys(localStorage).filter(k=>k.indexOf("starchorus.")===0).join(",")||"none";
o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$OBV_Q" "out/$P-obv-obs" --wait 2 --fps 0 --ready --eval-timeout 90 --eval "$OBV_EVO" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
OBV_O=$(evalv "out/$P-obv-obs.json" 1 | obv_nj); OBV_OE=$(evalv "out/$P-obv-obs.json" 2)
OBV_OW=$(printf '%s' '{"c1":0,"same":0,"c2":7,"n":9,"groups":"Look-alike,Responders,Configuration","look":true,"cfg":true,"p10":false,"noFriend":false,"watch":"watched SSID present: cafe","lost":"false,false,true","mobileExcluded":true,"panel":"true/none/on","panelOff":"true/true","watchStored":"[\"cafe\",\"nothere\"]","cleared":"none","errors":0}' | obv_nj)
if [ "$OBV_O" = "$OBV_OW" ] && [ "$OBV_OE" = 0 ]; then
  row "observations: dwell gate (0 -> 7 -> 9), look-alike only vs the confirmed set, neutral wording, watchlist (lost needs hop data), drawer shares the legend, clear local data" PASS
else
  row "observations (err ${OBV_OE:-?})" FAIL
  echo "    got:  $(printf '%s' "$OBV_O" | cut -c1-560)"; echo "    want: $OBV_OW"
fi

# ---- probes for a confirmed SSID (P4): the number of stations as counted, shown once it has held for two captures (the dwell every note has;
# the capture the mark followed counts, since an identity change recomputes the notes at once), carried in the SITREP (and so in its print) and not in JSON or CSV, nothing without a confirmed set, no band word; then the same eval on a page
# copy that bands the number again ('<5' / '5 or more', the text of 0.2.6), which must turn exactly the count keys red (the copy differs
# from the page in that one line: a negative control); and the page without the band text, the ten-minute gate and the new-station band.
# NEGATIVE PROBES (by hand, one-line copies of the page, 2 November 2026): the k > 0 guard dropped -> the dwell row above reads n 10 with a
# Probes group, the count row reads '0 station(s) probed for a confirmed SSID' for zero, and the band copy's key diff gains zero;
# eventSkip(c) dropped from the count -> the count row reads 7 for six and in the SITREP line (the own transmitter counted).
OBV_EVP='(async()=>{
const ap=(n,ssid)=>({bssid:"aa:bb:cc:00:07:"+String(n).padStart(2,"0"),ssid,band:"2.4",channel:6,freq:2437,rssi:-50-n,security:"WPA2",last_seen:1789300000});
const st=(n,probes)=>({mac:"02:00:00:00:07:"+String(n).padStart(2,"0"),rssi:-60-n,probes});
const mk=(g,un)=>({source:"recon-db",generated:g,aps:[ap(1,"HomeNet"),ap(2,"cafe")],unassociated:un,center:{label:"x",own_bssids:["02:00:00:00:07:10"]}}),o={};
const P=()=>STARCHORUS.observations().filter(x=>x.group==="Probes").map(x=>x.text).join("|"),T=()=>STARCHORUS.observations().map(x=>x.text).join(" ");
const un3=[st(1,["HomeNet"]),st(2,["HomeNet","cafe"]),st(3,["HomeNet"]),st(4,["cafe"]),st(5,[])];
STARCHORUS.load(mk(100,un3),"prb");STARCHORUS.setIdentity("aa:bb:cc:00:07:01","friend");o.atMark=P();   // observed first (P2), then confirmed; the mark itself shows no note (the dwell)
STARCHORUS.load(mk(105,un3),"prb");o.first=P();   // the second capture the note has held for (the mark recomputed the notes on the first): the dwell is met
STARCHORUS.load(mk(110,un3),"prb");o.three=P();
const un6=un3.concat([st(6,["HomeNet"]),st(7,["homenet"]),st(8,["HomeNet"]),st(9,["HomeNet"]),st(10,["HomeNet"])]);   // 7 differs in case: no hit; 10 is an own transmitter: not counted
STARCHORUS.load(mk(115,un6),"prb");o.six=P();
o.sitrep=STARCHORUS.exportText("sitrep").split("\n").filter(l=>/probed for a confirmed SSID/.test(l)).join("|");
o.noJsonCsv=!/probed for/.test(STARCHORUS.exportText("json")+STARCHORUS.exportText("csv"));
o.band=/<5|5 or more/.test(T());o.p10=/\b(evil[ -]?twin|rogue|attack(er)?|threat|intru(der|sion)|malicious|spoof(ed|ing)?|karma|bandit|target|deauth flood)\b/i.test(T());
STARCHORUS.load(mk(120,[st(4,["cafe"]),st(5,[])]),"prb");o.zero=P();   // nobody probes for the confirmed name any more: no note, not a 0
STARCHORUS.setIdentity("aa:bb:cc:00:07:01","unknown");STARCHORUS.load(mk(125,un6),"prb");STARCHORUS.load(mk(130,un6),"prb");o.noFriend=P();
STARCHORUS.clearLocalData();o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
obv_probes() {   # obv_probes NAME: the eval on the page $H serves; OBV_P = the answer, OBV_PE = the error count
  runq demo "$OBV_Q" "out/$P-obv-$1" --wait 2 --fps 0 --ready --eval-timeout 90 --eval "$OBV_EVP" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
  OBV_P=$(evalv "out/$P-obv-$1.json" 1 | obv_nj); OBV_PE=$(evalv "out/$P-obv-$1.json" 2)
}
obv_probes probes
OBV_PW=$(printf '%s' '{"atMark":"","first":"3 station(s) probed for a confirmed SSID","three":"3 station(s) probed for a confirmed SSID","six":"6 station(s) probed for a confirmed SSID","sitrep":"  6 station(s) probed for a confirmed SSID","noJsonCsv":true,"band":false,"p10":false,"zero":"","noFriend":"","errors":0}' | obv_nj)
if [ "$OBV_P" = "$OBV_PW" ] && [ "$OBV_PE" = 0 ]; then
  row "observations: stations that probed for a confirmed SSID are counted as they are (3, then 6; a name that differs in case is no hit, an own transmitter is not counted), nothing at the mark itself, from the second capture the note has held for (the mark recomputes the notes, so the capture it followed counts), in the SITREP (and so in its print), not in JSON or CSV, no note for none and none without a confirmed set, no band word, neutral wording" PASS
else
  row "observations: stations that probed for a confirmed SSID, counted (err ${OBV_PE:-?})" FAIL
  echo "    got:  $(printf '%s' "$OBV_P" | cut -c1-560)"; echo "    want: $OBV_PW"
fi
OBV_PO='add("probes", "Probes", k + " station(s) probed for a confirmed SSID");'
OBV_PN='add("probes", "Probes", "stations probed for a confirmed SSID: " + (k < 5 ? "<5" : "5 or more"));'
if python3 -B - "$H" "out/$P-obv-band.html" "$OBV_PO" "$OBV_PN" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
if t.count(sys.argv[3]) != 1: sys.exit(1)
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(sys.argv[3], sys.argv[4]))
PY
then
  OBV_HK=$H; H="out/$P-obv-band.html"; obv_probes band; H=$OBV_HK
  OBV_PD=$(python3 -c 'import json,sys; g,w=json.loads(sys.argv[1] or "{}"),json.loads(sys.argv[2]); print(",".join(sorted(k for k in set(g)|set(w) if g.get(k)!=w.get(k))))' "$OBV_P" "$OBV_PW" 2>/dev/null)
else OBV_PD=anchor; fi
rowif "observations: a page copy that bands the count again ('<5' / '5 or more') turns exactly the count keys red [$OBV_PD]" [ "$OBV_PD" = "band,first,sitrep,six,three" ]
OBV_BT=$(grep -c '"<5" : "5 or more"' starchorus.html); OBV_GT=$(grep -c 'OBS_PROBE_S\|obsProbe\|newStationsText' starchorus.html)
rowif "observations: the page holds no band text of the probes note ($OBV_BT), no ten-minute gate and no new-station band ($OBV_GT; the sky statistics' own cell rule, D11, is not this)" [ "$OBV_BT/$OBV_GT" = 0/0 ]

# ---- keys W/B, query overrides, persisted booleans
OBV_EVK='(async()=>{
const key=(k)=>window.dispatchEvent(new KeyboardEvent("keydown",{key:k})),o={};
o.start=[STARCHORUS.getToggles().observations,STARCHORUS.getToggles().baselineDiff].join();
key("w");key("b");o.afterKeys=[STARCHORUS.getToggles().observations,STARCHORUS.getToggles().baselineDiff].join();
await STARCHORUS.wait(400);const st=STARCHORUS.storageDump()||{};o.persisted=[st.observations,st.baselineDiff].join();
o.buttons=["t-obs","t-baseline","baseline-set","baseline-clear"].map(i=>!!document.getElementById(i)).join();
o.help=/Observations/.test(document.getElementById("help-list").innerText)&&/Baseline diff/.test(document.getElementById("help-list").innerText);
key("w");key("b");o.back=[STARCHORUS.getToggles().observations,STARCHORUS.getToggles().baselineDiff].join();
return JSON.stringify(o);})()'
runq demo "$OBV_Q" "out/$P-obv-keys" --wait 2 --fps 0 --ready --eval "$OBV_EVK" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
OBV_K=$(evalv "out/$P-obv-keys.json" 1 | obv_nj); OBV_KE=$(evalv "out/$P-obv-keys.json" 2)
OBV_KW=$(printf '%s' '{"start":"false,false","afterKeys":"true,true","persisted":"true,true","buttons":"true,true,true,true","help":true,"back":"false,false"}' | obv_nj)
if [ "$OBV_K" = "$OBV_KW" ] && [ "$OBV_KE" = 0 ]; then row "observation keys W/B toggle, persist as booleans, buttons and help entries exist [$OBV_K]" PASS
else row "observation keys W/B toggle, persist as booleans, buttons and help entries exist [$OBV_K]" FAIL; fi
runq demo "$OBV_Q&obs=1&baseline=1" "out/$P-obv-query" --wait 2 --fps 0 --ready --eval "JSON.stringify([STARCHORUS.getToggles().observations,STARCHORUS.getToggles().baselineDiff,document.documentElement.dataset.obs])" >/dev/null 2>&1
OBV_QV=$(evalv "out/$P-obv-query.json" 1)
rowif "observations: ?obs=1&baseline=1 override the start state [$OBV_QV]" [ "$OBV_QV" = '[true,true,"on"]' ]

# ---- D15: the observations drawer and the taller controls keep the edge panels apart (field-probes, three themes, three viewports, drawer on)
eval "$(grep '^EDG_OVL=' tools/regress.d/edge-layout.sh)"
eval "$(grep '^EDG_RDY=' tools/regress.d/edge-layout.sh)"
OBV_RDY=$EDG_RDY   # the fonts are loaded, the served capture has replaced the built-in sky and a frame has been painted (the overlap reads font metrics)
for OBV_VP in 1440x900 1000x640; do
  runq "$F/field-probes.json" "?poll=0&spin=0&intro=0&obs=1&baseline=1" "out/$P-obv-d15-$OBV_VP" --width "${OBV_VP%x*}" --height "${OBV_VP#*x}" --wait 4 --fps 0 --ready "$OBV_RDY" --eval "$EDG_OVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
  OBV_OV=$(evalv "out/$P-obv-d15-$OBV_VP.json" 1); OBV_OVE=$(evalv "out/$P-obv-d15-$OBV_VP.json" 2)
  if [ "$OBV_OV" = 0 ] && [ "$OBV_OVE" = 0 ]; then row "observations: D15 overlap 0 with the observations drawer open $OBV_VP (err ${OBV_OVE:-?}) [$(printf '%s' "$OBV_OV" | cut -c1-60)]" PASS
  else row "observations: D15 overlap 0 with the observations drawer open $OBV_VP (err ${OBV_OVE:-?}) [$(printf '%s' "$OBV_OV" | cut -c1-60)]" FAIL; fi
done

# ---- static: storage keys are the four of SECURITY.md §4 and nothing else; no client identity enters the baseline
OBV_KEYS=$(grep -oE '"starchorus\.[a-z]+\.v[0-9]+"' starchorus.html | sort -u | tr '\n' ' ')
OBV_HAVE=0; for OBV_K in starchorus.ui.v1 starchorus.identity.v1 starchorus.baseline.v1 starchorus.watch.v1; do case $OBV_KEYS in *"\"$OBV_K\""*) OBV_HAVE=$((OBV_HAVE + 1)) ;; esac; done
rowif "P8 the keys ui/identity/baseline/watch are all there ($OBV_HAVE/4; the complete set is checked in operator-tools.sh) [$OBV_KEYS]" [ "$OBV_HAVE" = 4 ]
# Stations enter the baseline (P1); this row asserts HOW they come in: through exactly one walk, capped apart from the APs,
# and without the association — the baseline keeps what was heard, not which AP a station talks to. A parent in the stored
# tuple turns it red.
OBV_BF=$(awk '/^function baselineSet\(/,/^}/' starchorus.html | sed 's://.*::')   # comments stripped: a note may name the cap
OBV_BC=$(printf '%s\n' "$OBV_BF" | grep -c 'S\.clients'); OBV_BK=$(printf '%s\n' "$OBV_BF" | grep -c 'BASELINE_CL_MAX')
OBV_BP=$(printf '%s\n' "$OBV_BF" | grep -c 'parent\|affinity\|probeVia')
rowif "baseline: baselineSet walks stations once ($OBV_BC), capped by BASELINE_CL_MAX ($OBV_BK), no association stored ($OBV_BP)" [ "$OBV_BC/$OBV_BK/$OBV_BP" = 1/1/0 ]
OBV_SEC="$(grep -c 'starchorus.baseline.v1' SECURITY.md)/$(grep -c 'starchorus.watch.v1' SECURITY.md)"   # each key on its own: two lines naming one key are not both
OBV_SOK=0; [ "${OBV_SEC%/*}" -ge 1 ] && [ "${OBV_SEC#*/}" -ge 1 ] && OBV_SOK=1
rowif "P8 SECURITY.md lists the baseline and watch keys (baseline/watch lines $OBV_SEC)" [ "$OBV_SOK" = 1 ]
