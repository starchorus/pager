# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/theme-wargames.sh -- the WarGames theme.
#   ring strokes bundled (drawCalls.stroke <= 30 on field-probes) · phosphor afterglow = freshness · arrival arcs + the contracting receive ring ·
#   source badge · logon (cursor, "LISTEN ONLY" as a copy-token claim) · IMSAI lamps = capture counter in binary · crowding sign
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only TWG_* globals are set.
#
# Everything theme-specific is a token (render.phosphor, render.recvRing, render.arrivalArcs, chrome.badge/crowdSign/lamps, copy.*); the other two themes carry the same keys switched off.

TWG_Q="?poll=0&spin=0&intro=0&debug=1"
# --ready: the fonts are loaded, the capture is in and a frame has been painted after both (--wait stays the ceiling); the demo runs use the bare form; the logon run keeps its fixed wait
TWG_RDY='document.fonts.ready.then(() => new Promise(r => requestAnimationFrame(() => r(!!window.STARCHORUS && STARCHORUS.nodes("ap").length > 0 && STARCHORUS.stats().sourceKind !== "demo"))))'
twg_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }

# ---- vector-faithful marks: bundled ring strokes (field-probes <= 30), sprite cap kept, rings still drawn
TWG_EVS='(async()=>{
await STARCHORUS.wait(1500);const o={};STARCHORUS.setFixedTime(9000000);
for(const t of ["wargames","foundation","whitehall"]){STARCHORUS.setTheme(t);STARCHORUS.frame();const d=STARCHORUS.perf().drawCalls;o[t]=[d.stroke,STARCHORUS.stats().sprites<=128].join(":");}
STARCHORUS.setTheme("wargames");STARCHORUS.frame();o.err=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$F/field-probes.json" "$TWG_Q&theme=wargames" "out/$P-twg-stroke" --width 1440 --height 900 --wait 3 --ready "$TWG_RDY" --fps 0 --eval-timeout 90 --eval "$TWG_EVS" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
TWG_S=$(evalv "out/$P-twg-stroke.json" 1 | twg_nj); TWG_SE=$(evalv "out/$P-twg-stroke.json" 2)
TWG_SOK=$(printf '%s' "$TWG_S" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(all(int(d[t].split(":")[0]) <= 30 and d[t].split(":")[1] == "true" for t in ("wargames","foundation","whitehall")) and d["err"] == 0)' 2>/dev/null)
if [ "$TWG_SOK" = True ] && [ "$TWG_SE" = 0 ]; then row "WarGames: vector-faithful marks: ring/tick strokes bundled, drawCalls.stroke on field-probes ≤ 30 in every theme, sprite cap kept [$(printf '%s' "$TWG_S" | cut -c1-90)]" PASS
else row "WarGames: vector-faithful marks: ring/tick strokes bundled, drawCalls.stroke on field-probes ≤ 30 in every theme, sprite cap kept [$(printf '%s' "$TWG_S" | cut -c1-90)]" FAIL; fi

# ---- phosphor afterglow = freshness: the glow around a star follows T0 > T1 > T2 > T3 (none); off in the other themes
TWG_EVP='(async()=>{
await STARCHORUS.wait(800);const o={};const G=1000000;
const ap=(n,age)=>({bssid:"02:00:00:00:10:0"+n,ssid:"p"+n,band:"5",channel:36,rssi:-50,security:"WPA3",last_seen:G-age,clients:[]});
STARCHORUS.load({source:"recon-db",generated:G,aps:[ap(1,0),ap(2,120),ap(3,600),ap(4,2000)],unassociated:[]},"ph");
await STARCHORUS.wait(1600);STARCHORUS.setView("2d");STARCHORUS.setFixedTime(9100000);STARCHORUS.frame();
const glow=(id)=>{const s=STARCHORUS.nodeScreen(id),n=STARCHORUS.node(id);let sum=0;for(let k=0;k<16;k++){const a=k*Math.PI/8,r=n.px*2.3;sum+=STARCHORUS.pixel("sky",s.sx+Math.cos(a)*r,s.sy+Math.sin(a)*r).a;}return sum;};
const id=(n)=>"02:00:00:00:10:0"+n;
const g=[1,2,3,4].map(n=>glow(id(n)));o.order=(g[0]>g[1]&&g[1]>g[2]&&g[2]>g[3]&&g[0]>=2*g[3]);
o.tiers=[1,2,3,4].map(n=>STARCHORUS.node(id(n)).freshTier).join("");
// the ring around a star is still drawn (bundled), once per AP: a strong-ring pixel exists just outside the star
const s1=STARCHORUS.nodeScreen(id(1)),n1=STARCHORUS.node(id(1));let ring=0;for(let r=n1.px+1;r<n1.px+8;r+=0.5)if(STARCHORUS.pixel("sky",s1.sx+r,s1.sy).a>100)ring++;o.ring=ring>0;
const TH=STARCHORUS._internals.THEMES;o.tokens=["wargames","foundation","whitehall"].map(k=>TH[k].render.phosphor.enabled+"/"+TH[k].render.recvRing.enabled+"/"+TH[k].render.arrivalArcs).join(" ");o.sprites=STARCHORUS.stats().sprites<=128;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
# The glow is sampled at 2.3*px. The WPA3 ring (width 1.5 at px+4) ends about 1.25 px inside 1.9*px, and a sample rounded to a whole pixel there
# read ring bleed that swamped the tiers once the first-time placements of #41 moved the stars to other sub-pixel positions (30 October 2026).
runq demo "$TWG_Q&theme=wargames" "out/$P-twg-ph" --width 1440 --height 900 --wait 2 --ready --fps 0 --eval-timeout 120 --eval "$TWG_EVP" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
TWG_P=$(evalv "out/$P-twg-ph.json" 1 | twg_nj); TWG_PE=$(evalv "out/$P-twg-ph.json" 2)
TWG_PW=$(printf '%s' '{"errors":0,"order":true,"ring":true,"sprites":true,"tiers":"0123","tokens":"true/true/true false/false/false false/false/false"}' | twg_nj)
if [ "$TWG_P" = "$TWG_PW" ] && [ "$TWG_PE" = 0 ]; then
  row "WarGames: phosphor: the afterglow around a star follows freshness T0 > T1 > T2 > T3, the security ring is still drawn, tokens on in WarGames only, sprite cap kept" PASS
else
  row "WarGames: phosphor (err ${TWG_PE:-?})" FAIL
  echo "    got:  $(printf '%s' "$TWG_P" | cut -c1-700)"; echo "    want: $TWG_PW"
fi

# ---- arrival: arcs only for a real arrival, and the receive ring contracts 18.5 -> 10.5 px in 300 ms (page clock); none under reduced motion, none in the other themes
TWG_EVA='(async()=>{
await STARCHORUS.wait(800);const o={},T=7000000;
const cl=(n)=>({mac:"3c:22:fb:10:20:"+String(n).padStart(2,"0"),rssi:-60-n,probes:["homenet"]});
const mk=(g,n)=>({source:"recon-db",generated:g,aps:[{bssid:"02:00:00:00:11:01",ssid:"a",band:"2.4",channel:6,rssi:-50,security:"WPA2",clients:[]}],unassociated:Array.from({length:n},(_,i)=>cl(i+1))});
const live=(d)=>STARCHORUS.load(d,"arr",{mode:"live"}),at=async(ms)=>{STARCHORUS.setFixedTime(ms);await STARCHORUS.wait(90);};
const arcs=()=>{STARCHORUS.frame();return STARCHORUS.stats().probeArcs;};
await at(T);live(mk(100,2));o.first=[STARCHORUS.recvRing().active,STARCHORUS.stats().events.newStations].join();
await at(T+200);live(mk(105,2));o.same=[STARCHORUS.recvRing().active,arcs()].join();
await at(T+400);live(mk(110,3));const r0=STARCHORUS.recvRing();o.arr0=[r0.active,r0.px,r0.alpha,STARCHORUS.stats().events.newStations].join();
await at(T+400+150);const r1=STARCHORUS.recvRing();await at(T+400+299);const r2=STARCHORUS.recvRing();await at(T+400+300);const r3=STARCHORUS.recvRing();
o.mid=[r1.px,r2.px,r3.active].join();
// arcs run on the real clock (a node fades in over 250 ms): a repeated capture raises none, a new station one, then none again
STARCHORUS.setFixedTime(null);live(mk(200,2));await STARCHORUS.wait(1600);live(mk(205,2));await STARCHORUS.wait(450);o.arcSame=arcs();live(mk(210,3));await STARCHORUS.wait(450);o.arcNow=arcs();await STARCHORUS.wait(1500);o.arcLater=arcs();
// the ring is drawn (a pixel on it at age 0) and it contracts (the mid radius is smaller)
STARCHORUS.setView("2d");await at(T+800);live(mk(120,4));await at(T+800);STARCHORUS.frame();
const CX=Math.round(innerWidth/2),CY=Math.round(innerHeight/2);let hit=0;for(let k=0;k<12;k++){const a=k*Math.PI/6;if(STARCHORUS.pixel("sky",CX+Math.cos(a)*18.5,CY+Math.sin(a)*18.5).a>0)hit++;}o.ringPix=hit>0;
// reduced motion and the other themes: no ring, no arrival arc
STARCHORUS.setReducedMotion(true);await at(T+900);live(mk(130,5));o.rm=[STARCHORUS.recvRing().active,arcs()].join();STARCHORUS.setReducedMotion(false);
STARCHORUS.setTheme("foundation");await at(T+1000);live(mk(140,6));o.found=[STARCHORUS.recvRing().active,arcs()].join();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "$TWG_Q&theme=wargames" "out/$P-twg-arr" --width 1440 --height 900 --wait 2 --ready --fps 0 --eval-timeout 120 --eval "$TWG_EVA" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
TWG_A=$(evalv "out/$P-twg-arr.json" 1 | twg_nj); TWG_AE=$(evalv "out/$P-twg-arr.json" 2)
TWG_AW=$(printf '%s' '{"arcLater":0,"arcNow":1,"arcSame":0,"arr0":"true,18.5,0.9,1","errors":0,"first":"false,0","found":"false,0","mid":"14.5,10.527,false","ringPix":true,"rm":"false,0","same":"false,0"}' | twg_nj)
if [ "$TWG_A" = "$TWG_AW" ] && [ "$TWG_AE" = 0 ]; then
  row "WarGames: arrival: no ring and no arc for a first or repeated capture, one arc and a receive ring contracting 18.5 → 14.5 → 10.5 px within 300 ms for a new station, drawn, none under reduced motion or in Foundation" PASS
else
  row "WarGames: arrival (err ${TWG_AE:-?})" FAIL
  echo "    got:  $(printf '%s' "$TWG_A" | cut -c1-700)"; echo "    want: $TWG_AW"
fi

# ---- source badge per kind (WarGames only, chrome text), lamps = capture counter in binary (frozen when stale), crowding sign in the Air drawer
TWG_EVB='(async()=>{
await STARCHORUS.wait(900);const o={};
const ap=(n)=>({bssid:"02:00:00:00:12:0"+n,ssid:"b"+n,band:"2.4",channel:1+2*n,rssi:-50-n,security:"WPA2",clients:[]});
const mk=(g,src)=>({source:src||"recon-db",generated:g,aps:[ap(1),ap(2),ap(3),ap(4)],unassociated:[]});
const b=()=>{const x=STARCHORUS.badge();return x.shown+":"+x.text+":"+x.kind;};
STARCHORUS.loadDemo();o.demo=b();
STARCHORUS.load(mk(100),"lv",{mode:"live"});o.live=b();
for(let i=0;i<7;i++)STARCHORUS.load(mk(100),"lv",{mode:"live"});o.stale=b()+"|"+STARCHORUS.stats().captureStale;
STARCHORUS.load(mk(300),"rec");o.rec=b();
STARCHORUS.load(mk(400,"iw-scan-ACTIVE"),"act");o.act=b();o.actTitle=STARCHORUS.badge().title;
STARCHORUS.load({source:"none",generated:500,aps:[],unassociated:[]},"non");o.none=b();
// lamps: the capture counter in binary; a stale feed freezes it (the counter does not move) and dims the lamps
for(let i=0;i<5;i++)STARCHORUS.load(mk(1000+5*i),"lamp",{mode:"live"});const L=STARCHORUS.lamps();o.lamps=[L.value,L.bits.join(""),L.frozen].join(" ");
o.dom=[document.querySelectorAll("#lamps i.on").length,document.getElementById("lamps").dataset.value,document.getElementById("lamps").getAttribute("aria-label")].join("|");
for(let i=0;i<7;i++)STARCHORUS.load(mk(1020),"lamp",{mode:"live"});const L2=STARCHORUS.lamps();o.frozen=[L2.value===L.value+0||L2.value===L.value,L2.frozen,document.getElementById("lamps").dataset.frozen].join();
// crowding sign
STARCHORUS.load(mk(2000),"sign",{mode:"live"});STARCHORUS.openDrawer("air");await STARCHORUS.wait(150);
const sg=document.getElementById("crowd-sign");o.sign=sg?[sg.querySelectorAll(".steps i").length,sg.querySelectorAll(".steps i.on").length===STARCHORUS.stats().crowding,sg.querySelector(".cap").textContent,getComputedStyle(sg).animationName,getComputedStyle(sg.querySelector("i")).animationName].join("|"):"none";
o.signAria=sg?sg.getAttribute("aria-label"):"";
STARCHORUS.openDrawer(null);
// the other themes: no badge, no lamps, no sign
STARCHORUS.setTheme("foundation");STARCHORUS.openDrawer("air");await STARCHORUS.wait(150);o.foundation=[STARCHORUS.badge().shown,STARCHORUS.lamps().shown,!!document.getElementById("crowd-sign"),getComputedStyle(document.getElementById("mast-badge")).display].join();
STARCHORUS.setTheme("whitehall");await STARCHORUS.wait(150);o.whitehall=[STARCHORUS.badge().shown,STARCHORUS.lamps().shown,!!document.getElementById("crowd-sign")].join();
STARCHORUS.openDrawer(null);STARCHORUS.setTheme("wargames");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "$TWG_Q&theme=wargames" "out/$P-twg-badge" --width 1440 --height 900 --wait 2 --ready --fps 0 --eval-timeout 120 --eval "$TWG_EVB" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
TWG_B=$(evalv "out/$P-twg-badge.json" 1 | twg_nj); TWG_BE=$(evalv "out/$P-twg-badge.json" 2)
TWG_BW=$(printf '%s' '{"act":"true:Active scan:active","actTitle":"Active scan · iw-scan-ACTIVE","demo":"true:Simulation:demo","dom":"2|5|capture counter, binary 5","errors":0,"foundation":"false,false,false,none","frozen":"true,true,1","lamps":"5 00000101 false","live":"true:Live RX:live","none":"true:No feed:none","rec":"true:Recorded:recorded","sign":"5|true|derived from channel overlap · not a security assessment|none|none","signAria":"Channel crowding 2 of 5","stale":"true:Stale:stale|true","whitehall":"false,false,false"}' | twg_nj)
if [ "$TWG_B" = "$TWG_BW" ] && [ "$TWG_BE" = 0 ]; then
  row "WarGames: source badge per kind (Simulation · Live RX · Stale · Recorded · Active scan + source · No feed), IMSAI lamps = capture counter in binary and frozen when stale, crowding sign (5 steps, level = crowding, caption, no animation), all absent in Foundation and Whitehall" PASS
else
  row "WarGames: source badge per kind (Simulation · Live RX · Stale · Recorded · Active scan + source · No feed), IMSAI lamps = capture counter in binary and frozen when stale, crowding sign (5 steps, level = crowding, caption, no animation), all absent in Foundation and Whitehall (err ${TWG_BE:-?})" FAIL
  echo "    got:  $(printf '%s' "$TWG_B" | cut -c1-700)"; echo "    want: $TWG_BW"
fi

# ---- logon: a visible cursor while it types, the LISTEN ONLY line is a copy-token claim (rx only), the mode line follows the source
TWG_EVL='(async()=>{
await STARCHORUS.wait(2200);const o={};
const t=document.getElementById("intro-text").textContent;o.typing=[getComputedStyle(document.getElementById("intro")).display,t.length>0,t.slice(-1)==="▮"].join();
const rx=STARCHORUS.logonLines();o.rx=[rx.length,rx.indexOf("LISTEN ONLY · STARCHORUS SENDS NO FRAMES"),rx[2].slice(0,20)].join("|");
STARCHORUS.load({source:"iw-scan-ACTIVE",generated:1,aps:[],unassociated:[]},"act");const ac=STARCHORUS.logonLines();o.act=[ac.length,ac.indexOf("LISTEN ONLY · STARCHORUS SENDS NO FRAMES"),/ACTIVE SCAN/.test(ac.join(" "))].join("|");
STARCHORUS.load({source:"recon-db",generated:2,aps:[],unassociated:[]},"rxx");
STARCHORUS.skipIntro();o.skipped=[document.getElementById("intro-text").textContent.indexOf("LISTEN ONLY · STARCHORUS SENDS NO FRAMES")>=0,document.getElementById("intro-text").textContent.slice(-1)!=="▮"].join();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "?poll=0&spin=0&debug=1&theme=wargames" "out/$P-twg-logon" --width 1440 --height 900 --wait 1 --fps 0 --eval-timeout 60 --eval "$TWG_EVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
TWG_L=$(evalv "out/$P-twg-logon.json" 1 | twg_nj); TWG_LE=$(evalv "out/$P-twg-logon.json" 2)
TWG_LW=$(printf '%s' '{"act":"4|-1|true","errors":0,"rx":"5|3|MODE: RX ONLY — NOTH","skipped":"true,true","typing":"block,true,true"}' | twg_nj)
if [ "$TWG_L" = "$TWG_LW" ] && [ "$TWG_LE" = 0 ]; then
  row "WarGames: logon: a visible cursor while it types, the LISTEN ONLY line only with a passive source (a copy-token claim), the mode line follows the source, skip shows the full text without the cursor" PASS
else
  row "WarGames: logon (err ${TWG_LE:-?})" FAIL
  echo "    got:  $(printf '%s' "$TWG_L" | cut -c1-700)"; echo "    want: $TWG_LW"
fi

# ---- D15 with the masthead badge and lamps (WarGames, three viewports), static rows
eval "$(grep '^EDG_OVL=' tools/regress.d/edge-layout.sh)"
for TWG_VP in 1440x900 1280x800 1000x640; do
  runq "$F/field-probes.json" "$TWG_Q&theme=wargames" "out/$P-twg-d15-$TWG_VP" --width "${TWG_VP%x*}" --height "${TWG_VP#*x}" --wait 4 --ready "$TWG_RDY" --fps 0 --eval "$EDG_OVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
  TWG_OV=$(evalv "out/$P-twg-d15-$TWG_VP.json" 1); TWG_OVE=$(evalv "out/$P-twg-d15-$TWG_VP.json" 2)
  if [ "$TWG_OV" = 0 ] && [ "$TWG_OVE" = 0 ]; then row "WarGames: D15 overlap 0 with badge and lamps $TWG_VP (err ${TWG_OVE:-?}) [$(printf '%s' "$TWG_OV" | cut -c1-60)]" PASS
  else row "WarGames: D15 overlap 0 with badge and lamps $TWG_VP (err ${TWG_OVE:-?}) [$(printf '%s' "$TWG_OV" | cut -c1-60)]" FAIL; fi
done
TWG_NET=$(grep -cE 'method:|POST|XMLHttpRequest|WebSocket|EventSource|sendBeacon' starchorus.html); TWG_FE=$(grep -c 'fetch(' starchorus.html)
if [ "$TWG_NET" = 0 ] && [ "$TWG_FE" = 1 ]; then row "WarGames: passivity: no send path in the page (= $TWG_NET), fetch( = $TWG_FE" PASS
else row "WarGames: passivity: no send path in the page (= $TWG_NET), fetch( = $TWG_FE" FAIL; fi
TWG_CLK=$(awk '/^function recvRingObj\(/,/^function drawThreshold\(/' starchorus.html | grep -cE 'Math\.random|Date\.now|performance\.now|new Date\(')
rowif "WarGames: the receive ring is page-clock driven, no wall clock or random ($TWG_CLK)" [ "$TWG_CLK" = 0 ]
TWG_CL=$(grep -c 'LISTEN ONLY' starchorus.html)
rowif "WarGames: the LISTEN ONLY claim exists once, in the copy tokens ($TWG_CL)" [ "$TWG_CL" = 1 ]
