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
runq demo "$OBV_Q" "out/$P-obv-model" --wait 2 --fps 0 --eval-timeout 90 --eval "$OBV_EVB" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
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
runq demo "$OBV_Q" "out/$P-obv-obs" --wait 2 --fps 0 --eval-timeout 90 --eval "$OBV_EVO" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
OBV_O=$(evalv "out/$P-obv-obs.json" 1 | obv_nj); OBV_OE=$(evalv "out/$P-obv-obs.json" 2)
OBV_OW=$(printf '%s' '{"c1":0,"same":0,"c2":7,"n":9,"groups":"Look-alike,Responders,Configuration","look":true,"cfg":true,"p10":false,"noFriend":false,"watch":"watched SSID present: cafe","lost":"false,false,true","mobileExcluded":true,"panel":"true/none/on","panelOff":"true/true","watchStored":"[\"cafe\",\"nothere\"]","cleared":"none","errors":0}' | obv_nj)
if [ "$OBV_O" = "$OBV_OW" ] && [ "$OBV_OE" = 0 ]; then
  row "observations: dwell gate (0 -> 7 -> 9), look-alike only vs the confirmed set, neutral wording, watchlist (lost needs hop data), drawer shares the legend, clear local data" PASS
else
  row "observations (err ${OBV_OE:-?})" FAIL
  echo "    got:  $(printf '%s' "$OBV_O" | cut -c1-560)"; echo "    want: $OBV_OW"
fi

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
runq demo "$OBV_Q" "out/$P-obv-keys" --wait 2 --fps 0 --eval "$OBV_EVK" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
OBV_K=$(evalv "out/$P-obv-keys.json" 1 | obv_nj); OBV_KE=$(evalv "out/$P-obv-keys.json" 2)
OBV_KW=$(printf '%s' '{"start":"false,false","afterKeys":"true,true","persisted":"true,true","buttons":"true,true,true,true","help":true,"back":"false,false"}' | obv_nj)
if [ "$OBV_K" = "$OBV_KW" ] && [ "$OBV_KE" = 0 ]; then row "observation keys W/B toggle, persist as booleans, buttons and help entries exist [$OBV_K]" PASS
else row "observation keys W/B toggle, persist as booleans, buttons and help entries exist [$OBV_K]" FAIL; fi
runq demo "$OBV_Q&obs=1&baseline=1" "out/$P-obv-query" --wait 2 --fps 0 --eval "JSON.stringify([STARCHORUS.getToggles().observations,STARCHORUS.getToggles().baselineDiff,document.documentElement.dataset.obs])" >/dev/null 2>&1
OBV_QV=$(evalv "out/$P-obv-query.json" 1)
rowif "observations: ?obs=1&baseline=1 override the start state [$OBV_QV]" [ "$OBV_QV" = '[true,true,"on"]' ]

# ---- D15: the observations drawer and the taller controls keep the edge panels apart (field-probes, three themes, three viewports, drawer on)
eval "$(grep '^EDG_OVL=' tools/regress.d/edge-layout.sh)"
for OBV_VP in 1440x900 1000x640; do
  runq "$F/field-probes.json" "?poll=0&spin=0&intro=0&obs=1&baseline=1" "out/$P-obv-d15-$OBV_VP" --width "${OBV_VP%x*}" --height "${OBV_VP#*x}" --wait 4 --fps 0 --eval "$EDG_OVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
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
OBV_SEC=$(grep -c 'starchorus.baseline.v1\|starchorus.watch.v1' SECURITY.md)
rowif "P8 SECURITY.md lists the baseline and watch keys ($OBV_SEC)" [ "$OBV_SEC" -ge 2 ]
