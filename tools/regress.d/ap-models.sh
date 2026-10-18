# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/ap-models.sh -- the theme-free models and marks.
#   freshness D1 · event record D2 + change cue D18 · poll deadline + liveness dot D3 · sky reference,
#   crowding, deviations D11 · signal levels D9 (U2) · marks D5-D8/D17 · colour roles §4.1, D16 · fixtures
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only APM_* globals are set.
#
# Eight Chrome runs. The data/sequence evals run WITHOUT ?fixed (a frozen clock never fades a node in, so nothing new
# would draw); everything they read is deterministic anyway (timing only decides that a cue is still "playing").

APM_Q="?poll=0&spin=0&intro=0&debug=1"
apm_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }   # key-order-free JSON text

# ---- freshness: the page's tiers = a Python recount of tests/fixtures/aged.json (boundaries 60/300/900, undated, +301 s)
APM_PY_FRESH=$(python3 - "$F/aged.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); g = d["generated"]; c = {"t0": 0, "t1": 0, "t2": 0, "t3": 0, "undated": 0}
for a in d["aps"]:
    ls = a.get("last_seen")
    if ls is None or ls <= 0 or g - ls < -300:
        c["undated"] += 1
        continue
    age = max(0, g - ls)
    c["t0" if age < 60 else "t1" if age < 300 else "t2" if age < 900 else "t3"] += 1
print(json.dumps(c, separators=(",", ":")))
PY
)
APM_EVF='(async()=>{
const S=()=>JSON.stringify(STARCHORUS.stats().fresh);const L=()=>STARCHORUS.legendRows().filter(r=>/^fresh/.test(r.kind)).map(r=>r.visible?1:0).join("");
const cells=()=>["n-fresh-cell","n-record-cell"].map(i=>document.getElementById(i).hidden?0:1).join("");
const o={};o.fresh=S();o.legend=L();o.cells=cells();
const tiers=STARCHORUS.nodes("ap").map(n=>STARCHORUS.node(n.id)).sort((a,b)=>a.id<b.id?-1:1).map(n=>n.freshTier==null?"u":n.freshTier).join("");o.tiers=tiers;
STARCHORUS.select("02:00:5e:a0:00:04");o.detail=(document.getElementById("detail-body").innerText.match(/Freshness\s*([^\n]*)/)||[])[1];STARCHORUS.deselect();
STARCHORUS.hoverNode("02:00:5e:a0:00:04");o.tip=(document.getElementById("tip-body").innerText.match(/Heard\s*([^\n]*)/)||[])[1];STARCHORUS.hoverNode(null);
const doc=await fetch("starchorus.json").then(r=>r.json());
const win=JSON.parse(JSON.stringify(doc));win.center.max_age=120;STARCHORUS.load(win,"maxage");o.window=STARCHORUS.legendRows().filter(r=>/^fresh/.test(r.kind)).map(r=>r.visible?1:0).join("")+"/"+cells();
const whole=JSON.parse(JSON.stringify(doc));whole.center.max_age=0;STARCHORUS.load(whole,"maxage0");o.whole=STARCHORUS.legendRows().filter(r=>/^fresh/.test(r.kind)).map(r=>r.visible?1:0).join("");
const nogen=JSON.parse(JSON.stringify(doc));delete nogen.generated;STARCHORUS.load(nogen,"nogen");o.nogen=JSON.stringify(STARCHORUS.stats().fresh)+"/"+STARCHORUS.legendRows().filter(r=>/^fresh/.test(r.kind)).map(r=>r.visible?1:0).join("");
return JSON.stringify(o);})()'
runq "$F/aged.json" "$APM_Q" "out/$P-apm-fresh" --wait 3 --fps 0 --eval "$APM_EVF" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
APM_FR=$(evalv "out/$P-apm-fresh.json" 1)
APM_FRE=$(evalv "out/$P-apm-fresh.json" 2)
APM_FR_ALL=$(printf '%s' "$APM_FR" | python3 -c '
import json, sys
o = json.load(sys.stdin)
print(json.dumps({"fresh": json.loads(o["fresh"]), "legend": o["legend"], "cells": o["cells"], "detail": o["detail"], "tip": o["tip"], "window": o["window"], "whole": o["whole"], "nogen": o["nogen"]}, sort_keys=True, separators=(",", ":")))
' 2>/dev/null)
# the exact expectation, built from the recount (order of `tiers` = BSSID order 01..0e of the fixture)
APM_FR_WANT=$(python3 - "$APM_PY_FRESH" <<'PY'
import json, sys
f = json.loads(sys.argv[1])
print(json.dumps({"cells": "11", "detail": "heard < 5 min", "fresh": f, "legend": "11111", "nogen": '{"t0":0,"t1":0,"t2":0,"t3":0,"undated":14}/00000',
                  "tip": "heard < 5 min", "whole": "11111", "window": "11001/10"}, sort_keys=True, separators=(",", ":")))
PY
)
if [ "$APM_FR_ALL" = "$APM_FR_WANT" ] && [ "$APM_FRE" = 0 ]; then
  row "freshness D1 = Python recount $APM_PY_FRESH" PASS
else
  row "freshness D1 (err ${APM_FRE:-?})" FAIL
  echo "    got:  $APM_FR_ALL"; echo "    want: $APM_FR_WANT"
fi
APM_TIERS=$(printf '%s' "$APM_FR" | python3 -c 'import json,sys;print(json.load(sys.stdin)["tiers"])' 2>/dev/null)
rowif "freshness: per-AP tiers (ages 0,30,59 -> T0 · 60,299 -> T1 · 300,899 -> T2 · 900,3600 -> T3 · -30 -> T0 · 4 undated) [$APM_TIERS]" [ "$APM_TIERS" = 0001122330uuuu ]

# ---- static: freshness lives in one function, is theme-free and clock-free
APM_FO=$(grep -c '^function freshOf(' "$H")
APM_FT=$(awk '/^function freshOf\(/,/^}/' "$H" | grep -cE 'THEME|Date\.now|Math\.random|theme ===')
rowif "freshness: freshOf() once, no THEME/Date.now/random ($APM_FO/$APM_FT)" [ "$APM_FO/$APM_FT" = 1/0 ]

# ---- event record D2 + change cue D18, liveness dot D3, signal levels, D16 marks (one demo run, real clock)
APM_EVE='(async()=>{
const ap=(n,rssi,extra)=>Object.assign({bssid:"02:00:00:00:00:"+String(n).padStart(2,"0"),ssid:"s"+n,band:"2.4",channel:1+n%11,rssi,security:"WPA2",last_seen:1789300000},extra||{});
const mk=(g,aps,un)=>({source:"recon-db",generated:g,aps,unassociated:un||[]});
const out=[];const ev=()=>{const e=STARCHORUS.stats().events;return [e.captureSeq,e.arrived,e.departed,e.changed,e.cues,e.newStations].join("/")};
STARCHORUS.load(mk(100,[ap(1,-50),ap(2,-60),ap(3,-70),ap(4,-55)],[{mac:"02:00:00:00:99:01",rssi:-70}]),"seq");out.push(ev());
await STARCHORUS.wait(1500);
STARCHORUS.load(mk(105,[ap(1,-50),ap(2,-60),ap(3,-70),ap(4,-55),ap(5,-65)],[{mac:"02:00:00:00:99:01",rssi:-70},{mac:"02:00:00:00:99:02",rssi:-71}]),"seq");out.push(ev());
STARCHORUS.load(mk(105,[ap(1,-50)]),"seq");out.push(ev());
STARCHORUS.load(mk(110,[ap(1,-42),ap(2,-60,{channel:9}),ap(3,-70),ap(5,-65)],[]),"seq");out.push(ev());
const cue=[];for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);STARCHORUS.frame();cue.push(STARCHORUS.perf().drawCalls.cue)}out.push(cue.join(","));
STARCHORUS.setTheme("foundation");
STARCHORUS.load(mk(115,[ap(1,-40),ap(2,-60,{channel:9}),ap(3,-70),ap(5,-65)],[]),"seq");out.push(ev());
const cue2=[];for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);STARCHORUS.frame();cue2.push(STARCHORUS.perf().drawCalls.cue)}out.push(cue2.join(","));
STARCHORUS.load(mk(120,[ap(1,-40)],[]),"otherlabel");out.push(ev());
STARCHORUS.setReducedMotion(true);STARCHORUS.load(mk(125,[ap(1,-20)],[]),"otherlabel");STARCHORUS.load(mk(130,[ap(1,-30)],[]),"otherlabel");await STARCHORUS.wait(1200);STARCHORUS.frame();out.push("rm:"+STARCHORUS.perf().drawCalls.cue);STARCHORUS.setReducedMotion(null);
STARCHORUS.load({source:"recon-db",aps:[ap(1,-40)]},"nogen");STARCHORUS.load({source:"recon-db",aps:[ap(1,-40),ap(2,-40)]},"nogen");out.push("nogen:"+ev());
return out.join(" | ");})()'
# liveness dot: demo (off) -> live doc (live) -> 6 stale polls (stale)
APM_EVD='(async()=>{const d=document.querySelector("#masthead .brand .dot"),o=[d.dataset.live];const doc={source:"recon-db",generated:1789300000,aps:[{bssid:"02:00:00:00:00:01",ssid:"x",band:"2.4",channel:1,rssi:-50}]};STARCHORUS.load(doc,"starchorus.json",{mode:"live"});o.push(d.dataset.live);for(let i=0;i<6;i++)await STARCHORUS.pollNow();o.push(d.dataset.live);STARCHORUS.load({source:"none",aps:[]},"none");o.push(d.dataset.live);return o.join("/");})()'
# signal levels (D9/U2): boundaries at the rings, percent = round(100*rssiT), word = the theme voice
APM_EVG='(async()=>{
const dbms=[-38,-40,-41,-58,-60,-61,-80,-81,-88];const aps=dbms.map((d,i)=>({bssid:"02:00:00:00:01:"+String(i).padStart(2,"0"),ssid:"g"+i,band:"5",channel:36+4*i,rssi:d,security:"WPA2"}));
STARCHORUS.load({source:"recon-db",generated:1789300000,aps},"sig");const o={rings:STARCHORUS._internals.LAYOUT.rings.join(",")};
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);o[t]=aps.map(a=>{STARCHORUS.hoverNode(a.bssid);const m=/Signal\s*([^\n]*)/i.exec(document.getElementById("tip-body").innerText);return m?m[1]:"?";}).join(";");}
STARCHORUS.hoverNode(null);STARCHORUS.setTheme("foundation");return JSON.stringify(o);})()'
# D16: data strings are never transformed (canvas label text + DOM), in the uppercase themes
APM_EVU='(async()=>{
STARCHORUS.load({source:"recon-db",generated:1789300000,center:{label:"Mixed Case Centre"},aps:[{bssid:"02:00:00:00:02:01",ssid:"MixedCase Net",vendor:"Vend Or Ltd",band:"5",channel:36,rssi:-45,security:"WPA2"}]},"u16");
await STARCHORUS.wait(1500);const o={};STARCHORUS.setToggles({vendor:true});STARCHORUS.pin("02:00:00:00:02:01",true);
for(const t of ["wargames","whitehall"]){STARCHORUS.setTheme(t);await STARCHORUS.wait(60);STARCHORUS.frame();const L=STARCHORUS.labels().map(l=>l.text).join("|");
 STARCHORUS.hoverNode("02:00:00:00:02:01");const s=document.querySelector("#tip .ssid");const cs=getComputedStyle(s).textTransform;STARCHORUS.hoverNode(null);
 STARCHORUS.select("02:00:00:00:02:01");const dt=getComputedStyle(document.getElementById("detail-title")).textTransform+"/"+document.getElementById("detail-title").textContent;STARCHORUS.deselect();
 o[t]={ssid:/MixedCase Net/.test(L),centre:/Mixed Case Centre/.test(L),tip:cs,detail:dt};}   // the vendor line is drawn but not listed by labels(): the static row below covers it
STARCHORUS.pin("02:00:00:00:02:01",false);STARCHORUS.setToggles({vendor:false});STARCHORUS.setTheme("foundation");return JSON.stringify(o);})()'
runq demo "$APM_Q" "out/$P-apm-run" --wait 2 --fps 0 --eval-timeout 90 \
  --eval "$APM_EVE" --eval "$APM_EVD" --eval "$APM_EVG" --eval "$APM_EVU" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
APM_E=$(evalv "out/$P-apm-run.json" 1); APM_D=$(evalv "out/$P-apm-run.json" 2); APM_G=$(evalv "out/$P-apm-run.json" 3 | apm_nj)
APM_U=$(evalv "out/$P-apm-run.json" 4 | apm_nj); APM_RE=$(evalv "out/$P-apm-run.json" 5)
rowif "events D2 + cue D18 [$APM_E]" [ "$APM_E" = "1/0/0/0/0/0 | 2/1/0/0/0/1 | 2/1/0/0/0/1 | 3/0/1/1/1/0 | 1,1,1 | 4/0/0/0/0/0 | 0,0,0 | 1/0/0/0/0/0 | rm:1 | nogen:0/0/0/0/0/0" ]
rowif "liveness dot: demo off · live · stale after 6 · none off [$APM_D]" [ "$APM_D" = "off/live/stale/off" ]
APM_GW=$(printf '%s' '{"foundation":"-38 dBm (87 %, excellent);-40 dBm (83 %, excellent);-41 dBm (82 %, good);-58 dBm (53 %, good);-60 dBm (50 %, good);-61 dBm (48 %, weak);-80 dBm (17 %, weak);-81 dBm (15 %, marginal);-88 dBm (3 %, marginal)","rings":"-40,-60,-80","wargames":"-38 dBm (87 %, MAX);-40 dBm (83 %, MAX);-41 dBm (82 %, STRONG);-58 dBm (53 %, STRONG);-60 dBm (50 %, STRONG);-61 dBm (48 %, WEAK);-80 dBm (17 %, WEAK);-81 dBm (15 %, MIN);-88 dBm (3 %, MIN)","whitehall":"-38 dBm (87 %, STRONG);-40 dBm (83 %, STRONG);-41 dBm (82 %, GOOD);-58 dBm (53 %, GOOD);-60 dBm (50 %, GOOD);-61 dBm (48 %, WEAK);-80 dBm (17 %, WEAK);-81 dBm (15 %, FAINT);-88 dBm (3 %, FAINT)"}' | apm_nj)
rowif "signal D9: rings -40/-60/-80, 4 levels, percent, theme words" [ "$APM_G" = "$APM_GW" ]
[ "$APM_G" = "$APM_GW" ] || { echo "    got:  $(printf '%s' "$APM_G" | cut -c1-300)"; }
APM_UW=$(printf '%s' '{"whitehall":{"centre":true,"detail":"none/MixedCase Net","ssid":true,"tip":"none"},"wargames":{"centre":true,"detail":"none/MixedCase Net","ssid":true,"tip":"none"}}' | apm_nj)
rowif "D16 data strings never transformed (canvas + DOM, WarGames/Whitehall)" [ "$APM_U" = "$APM_UW" ]
[ "$APM_U" = "$APM_UW" ] || { echo "    got:  $(printf '%s' "$APM_U" | cut -c1-300)"; }
rowif "models run: no page errors (${APM_RE:-?})" [ "$APM_RE" = 0 ]
rowif "D16 no toUpperCase on data strings in the canvas text path" [ "$(sed 's://.*::' "$H" | grep -c 'TD\.upper ?.*\(raw\|vraw\|ap\.vendor\|centerLabel\|g\.key\)')" = 0 ]

# ---- sky reference / crowding / deviations (D11): warm-up, outlier hold, confirmed deviation, observer moved, N >= 30 gate, no identifiers
APM_EVK='(async()=>{
const ap=(ch,rssi,id)=>({bssid:"02:00:00:00:"+(id>>8).toString(16).padStart(2,"0")+":"+(id&255).toString(16).padStart(2,"0"),ssid:"n"+id,band:"2.4",channel:ch,rssi,security:"WPA2",last_seen:1789300000});
const mk=(g,list)=>({source:"recon-db",generated:g,aps:list,unassociated:[]});
const base=()=>{const l=[];let id=1;for(const [ch,n] of [[1,4],[6,3],[11,3]])for(let i=0;i<n;i++)l.push(ap(ch,-70,id++));return l;};
const big=()=>{const l=base();for(let i=0;i<9;i++)l.push(ap(6,-70,100+i));return l;};
const out={};const sk=()=>{const s=STARCHORUS.skyStats();return s.ref.captures+"/"+(s.ref.warm?1:0)+"/"+s.deviations.map(d=>d.band+":"+d.channel+d.dir).join(",")};
for(let g=0;g<7;g++)STARCHORUS.load(mk(100+g,base()),"sky");out.warm=sk();
STARCHORUS.load(mk(107,big()),"sky");out.first=sk();STARCHORUS.load(mk(108,big()),"sky");out.second=sk();
for(let g=109;g<115;g++)STARCHORUS.load(mk(g,big()),"sky");out.adopted=sk();
const other=[];for(let i=0;i<10;i++)other.push(ap(1+i%3*5,-60,300+i));STARCHORUS.load(mk(120,other),"sky");out.moved=sk()+"/r"+STARCHORUS.skyStats().ref.resets;
const s=STARCHORUS.skyStats();out.keys=Object.keys(s).join(",");out.ids=/02:00|"n\d|bssid|ssid|mac/i.test(JSON.stringify(s))?"IDENTIFIER":"clean";
const lv=[];for(const n of [1,2,3,4,6,7,10]){const l=[];for(let i=0;i<n;i++)l.push(ap(6,-40,500+i));STARCHORUS.load(mk(200+n,l),"crowd"+n);lv.push(n+":"+STARCHORUS.skyStats().crowding.level);}out.crowd=lv.join(" ");
const l30=[];for(let i=0;i<34;i++)l30.push(ap(1+i%11,-60,700+i));STARCHORUS.load(mk(300,l30),"n30");const t=STARCHORUS.skyStats();out.gate=[t.ok,t.band["2.4"].shown,t.band["2.4"].p!=null,t.band["5"].shown,t.hidden.shown].join("/");
const l5=[];for(let i=0;i<8;i++)l5.push(ap(1+i,-60,800+i));STARCHORUS.load(mk(301,l5),"n8");const u=STARCHORUS.skyStats();out.small=[u.ok,u.band["2.4"].shown,u.band["2.4"].p].join("/");
STARCHORUS.load(mk(302,big()),"sky2");for(let g=303;g<312;g++)STARCHORUS.load(mk(g,base()),"sky2");
out.cell=document.getElementById("n-crowd").textContent+"|"+/crowding \d\/5/.test(document.getElementById("n-crowd").title);
const voices=[];for(const th of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(th);voices.push(document.getElementById("n-crowd").title.split(" · ")[0]);}STARCHORUS.setTheme("foundation");out.voice=voices.join("/");
return JSON.stringify(out);})()'
runq demo "$APM_Q" "out/$P-apm-sky" --wait 2 --fps 0 --eval-timeout 90 --eval "$APM_EVK" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
APM_K=$(evalv "out/$P-apm-sky.json" 1 | apm_nj); APM_KE=$(evalv "out/$P-apm-sky.json" 2)
APM_KW=$(printf '%s' '{"adopted":"15/1/","cell":"1|true","crowd":"1:1 2:2 3:2 4:3 6:4 7:4 10:5","first":"8/1/","gate":"true/34/true/<5/<5","ids":"clean","keys":"n,ok,minN,band,security,hidden,crowding,deviations,ref","moved":"1/0//r1","second":"9/1/2.4:6up","small":"false/8/","voice":"Compendium/SKY SUMMARY/SITREP","warm":"7/1/"}' | apm_nj)
if [ "$APM_K" = "$APM_KW" ] && [ "$APM_KE" = 0 ]; then
  row "sky: warm 6, hold, deviation, adopted, reset, gate, crowding 1-5, no ids" PASS
else
  row "sky reference/crowding (err ${APM_KE:-?})" FAIL
  echo "    got:  $(printf '%s' "$APM_K" | cut -c1-420)"; echo "    want: $APM_KW"
fi

# ---- poll deadline: a hung server must not keep the chip on "Live", and is silence: after six deadlines (32.4 s of poll time) it reads Offline
APM_EVH='(async()=>{const doc={source:"recon-db",generated:1789300000,aps:[{bssid:"02:00:00:00:00:01",ssid:"x",band:"2.4",channel:1,rssi:-50}]};STARCHORUS.load(doc,"starchorus.json",{mode:"live"});const t0=performance.now(),r=[];for(let i=0;i<6;i++){const x=await STARCHORUS.pollNow();r.push(x.ok?1:0);}const s=STARCHORUS.stats(),ms=performance.now()-t0;const a=STARCHORUS.pollNow(),b=STARCHORUS.pollNow();const same=a===b;await a;return JSON.stringify({r:r.join(""),stale:s.captureStale,off:s.captureOffline,polls:s.stalePolls,fast:ms<5000,same});})()'
runq "$F/field-probes.json" "?poll=0&spin=0&intro=0&pollto=400" "out/$P-apm-hang" --delay 3 --wait 2 --fps 0 --eval-timeout 60 --eval "$APM_EVH" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
APM_H=$(evalv "out/$P-apm-hang.json" 1); APM_HE=$(evalv "out/$P-apm-hang.json" 2)
if [ "$APM_H" = '{"r":"000000","stale":true,"off":true,"polls":6,"fast":true,"same":true}' ] && [ "$APM_HE" = 0 ]; then
  row "poll deadline: 6 hung polls -> stale and offline in < 5 s, one request at a time" PASS
else
  row "poll deadline [$APM_H] err ${APM_HE:-?}" FAIL
fi
# the row can bite: a page copy that counts an aborted fetch as an answer is stale after the same six polls, but never offline
APM_HM="out/$P-apm-hang.html"
sed 's/late = true; ac.abort();/late = true; heard = true; ac.abort();/' "$H" > "$APM_HM"
APM_HN=$(grep -c 'late = true; heard = true; ac.abort();' "$APM_HM")
APM_HKEEP=$H; H=$APM_HM   # runq serves $H: point it at the copy for this one call, then put it back
runq "$F/field-probes.json" "?poll=0&spin=0&intro=0&pollto=400" "out/$P-apm-hangm" --delay 3 --wait 2 --fps 0 --eval-timeout 60 --eval "$APM_EVH" >/dev/null 2>&1
H=$APM_HKEEP
APM_HV=$(evalv "out/$P-apm-hangm.json" 1)
if [ "$APM_HN" = 1 ] && [ "$APM_HV" = '{"r":"000000","stale":true,"off":false,"polls":6,"fast":true,"same":true}' ]; then
  row "poll deadline probe bites: a deadline taken for an answer is stale but never offline (mutation $APM_HN)" PASS
else
  row "poll deadline probe bites (mutation $APM_HN) [$APM_HV]" FAIL
fi
APM_TO=$(grep -c 'AbortController' "$H"); APM_FE=$(grep -c 'fetch("starchorus.json' "$H")
if [ "$APM_TO" -ge 1 ] && [ "$APM_FE" = 1 ]; then row "poll deadline: AbortController in tryPoll ($APM_TO), fetch still once ($APM_FE)" PASS
else row "poll deadline: AbortController in tryPoll ($APM_TO), fetch still once ($APM_FE)" FAIL; fi

# ---- colour roles §4.1: tools/check-colors.py on the live token sets of all three themes
runq demo "$APM_Q" "out/$P-apm-themes" --wait 1 --fps 0 --eval "JSON.stringify(STARCHORUS._internals.THEMES)" >/dev/null 2>&1
APM_CC=$(python3 tools/check-colors.py "out/$P-apm-themes.json" 2>&1 | tail -1)
APM_CS=$(python3 tools/check-colors.py --selftest 2>&1 | tail -1)
APM_CN=$(printf '%s' "$APM_CC" | sed -n 's/^check-colors: \([0-9]*\) checks, \([0-9]*\) FAIL.*/\1\/\2/p')
if [ "${APM_CN##*/}" = 0 ] && [ "$APM_CS" = "selftest ok" ] && [ "${APM_CN%%/*}" -ge 100 ]; then row "colour roles (check-colors.py: ${APM_CN%%/*} checks, ${APM_CN##*/} FAIL) + selftest [$APM_CS]" PASS
else row "colour roles (check-colors.py: ${APM_CN%%/*} checks, ${APM_CN##*/} FAIL) + selftest [$APM_CS]" FAIL; fi
[ "${APM_CN##*/}" = 0 ] || python3 tools/check-colors.py "out/$P-apm-themes.json" 2>&1 | head -12 | sed 's/^/    /'
APM_NEG=$(python3 - "out/$P-apm-themes.json" <<'PY'
import json, subprocess, sys, tempfile
d = json.load(open(sys.argv[1])); t = json.loads(d["eval"][0]["value"])
def run(mut):
    u = json.loads(json.dumps(t)); mut(u)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(u, f); n = f.name
    return subprocess.run([sys.executable, "tools/check-colors.py", n], capture_output=True, text=True).returncode
# negative controls: each mutation must turn the validator red
r = [run(lambda u: u["wargames"]["band"]["6"].__setitem__("core", "#e7c54a")),        # 6 GHz back to yellow
     run(lambda u: u["whitehall"]["accent"].__setitem__("selection", "#4cff6b")),      # selection back to terminal green
     run(lambda u: u["foundation"]["accent"].__setitem__("selection", "#e0b95a")),     # selection = the alarm gold
     run(lambda u: u["foundation"]["render"].__setitem__("bubbleStroke", "rgba(199,215,255,0.55)")),  # tinted aggregate
     run(lambda u: u["wargames"]["chrome"].__setitem__("bezel", {"color": "#2ab42a", "widthPx": 1, "gapPx": 0, "bracketPx": 10})),   # chrome in a band colour
     run(lambda u: u["foundation"]["render"].__setitem__("btMark", u["foundation"]["band"]["2.4"]["core"])),     # 0.2: the Bluetooth mark in the 2.4 GHz core colour
     run(lambda u: u["whitehall"]["render"].__setitem__("btMark", u["whitehall"]["band"]["6"]["core"]))]         # 0.2: the Bluetooth mark in the 6 GHz violet
print("".join("1" if x else "0" for x in r))
PY
)
rowif "colour validator bites: 7/7 mutations red, the last two the Bluetooth mark in the 2.4 GHz core colour and in the 6 GHz violet [$APM_NEG]" [ "$APM_NEG" = 1111111 ]

# ---- ring values, static anchors of the marks
APM_RG=$(grep -c 'rings: \[-40, -60, -80\]' "$H")
APM_TK=$(grep -c 'changeCue: "glowPulse"\|changeCue: "bloomPulse"\|changeCue: "tick"' "$H")
APM_RM=$(grep -c 'clientRandomizedMark: "hollow"\|clientRandomizedMark: "crossX"' "$H")
APM_AA=$(grep -c 'alarmAura: "none"\|alarmAura: "wash"' "$H")
rowif "model tokens: rings -40/-60/-80 ($APM_RG) · changeCue ($APM_TK/3) · randomized mark ($APM_RM/3) · alarmAura ($APM_AA/3)" [ "$APM_RG/$APM_TK/$APM_RM/$APM_AA" = 1/3/3/3 ]
APM_DEAD=$(grep -c 'strokeAlpha\|twinkleBloom\|glowAlpha: \[' "$H")
rowif "token hygiene: no dead strokeAlpha/twinkleBloom/glowAlpha ramp ($APM_DEAD)" [ "$APM_DEAD" = 0 ]
APM_PXY=$(awk '/^function drawNebula\(/,/^}/' "$H"; awk '/^function drawBubbles\(/,/^}/' "$H"); APM_PXN=$(printf '%s\n' "$APM_PXY" | sed 's://.*::' | grep -c 'render\.probeArc')   # code only: the comment says why
rowif "colour roles: no render.probeArc stand-in in nebula/bubbles ($APM_PXN)" [ "$APM_PXN" = 0 ]
APM_CRUMB=$(sed -n '/^function drawNebula(/,/^}/p' "$H" | sed 's://.*::' | grep -c 'breathe')
rowif "D17 nebula alpha never breathes ($APM_CRUMB)" [ "$APM_CRUMB" = 0 ]

# ---- marks: pixels of the D6 gap ring, the D5 pin arc, the D7 identity form (canvas) + sprite kinds of the unknown-band square (D-unknown)
# and the D8 randomized marks. WarGames with the CRT off draws flat lines: a ring at radius px+4 must be there everywhere except its NE gap.
APM_EVM='(async()=>{
const ap=(n,ssid,band,ch,rssi,sec)=>Object.assign({bssid:"02:00:00:00:03:"+String(n).padStart(2,"0"),ssid,rssi,security:sec},band?{band,channel:ch}:{});
const doc={source:"recon-db",generated:1789300000,aps:[ap(1,"open one","5",36,-45,"Open"),ap(2,"wep one","2.4",6,-58,"WEP"),ap(3,"no band",null,null,-52,"WPA2"),ap(4,"pin one","5",149,-66,"WPA2"),ap(5,"id one","2.4",1,-74,"WPA2")],
  unassociated:[{mac:"a2:11:22:33:44:55",rssi:-60,randomized:true},{mac:"3c:22:fb:11:22:33",rssi:-62,vendor:"Apple"}]};
STARCHORUS.load(doc,"marks");await STARCHORUS.wait(1600);
const o={};STARCHORUS.setToggles({crt:false,labels:false,orbits:false,links:false,nebula:false,groups:false});
const K=()=>Array.from(STARCHORUS._internals.spriteCache.keys());
const pxl=(id,ang,r)=>{const n=STARCHORUS.node(id),x=Math.round(n.sx+Math.cos(ang)*r),y=Math.round(n.sy+Math.sin(ang)*r);let b={a:0,r:0,g:0,b:0};for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++){const p=STARCHORUS.pixel("sky",x+dx,y+dy);if(p.a>b.a)b=p;}return b;};
const D=Math.PI/180,id=(n)=>"02:00:00:00:03:0"+n;
for(const t of ["wargames","whitehall"]){STARCHORUS.setTheme(t);await STARCHORUS.wait(80);STARCHORUS.frame();
  const g=[];for(const n of [1,2]){const px=STARCHORUS.node(id(n)).px+4;g.push(pxl(id(n),-45*D,px).a<pxl(id(n),135*D,px).a-90&&pxl(id(n),135*D,px).a>=150);}
  o[t+"_gap"]=g.join(",");
  STARCHORUS.pin(id(4),true);STARCHORUS.frame();const p4=STARCHORUS.node(id(4)),rp=p4.px+13;o[t+"_pin"]=pxl(id(4),-90*D,rp).a<pxl(id(4),90*D,rp).a-70&&pxl(id(4),90*D,rp).a>=120;
  STARCHORUS.select(id(4));STARCHORUS.frame();const rs=STARCHORUS.node(id(4)).px+13;o[t+"_sel"]=pxl(id(4),-90*D,rs+5).a<pxl(id(4),90*D,rs+5).a-70&&pxl(id(4),-90*D,rs).a>=120;STARCHORUS.deselect();STARCHORUS.pin(id(4),false);   // selected AND pinned: the pin arc sits 5 px outside the full selection ring
  STARCHORUS.setIdentity(id(5),"hostile");STARCHORUS.frame();const r5=STARCHORUS.node(id(5)).px+6;let ink=false;for(const a of [0,90,180,270]){const q=pxl(id(5),a*D,r5);if(q.a>150&&q.r>150&&q.g>150&&q.b>150&&Math.abs(q.r-q.g)<45)ink=true;}o[t+"_id"]=ink;STARCHORUS.setIdentity(id(5),"unknown");
}
STARCHORUS.setTheme("foundation");STARCHORUS.frame();o.square=K().some(k=>/\|coreSquare\|/.test(k));o.hollow=K().some(k=>/\|client\|client\|\d+\|rnd$/.test(k));
STARCHORUS.setTheme("wargames");STARCHORUS.frame();o.crossX=K().some(k=>/\|clientCross\|client\|\d+\|L\dx$/.test(k));o.crossPlain=K().some(k=>/\|clientCross\|client\|\d+\|L\d$/.test(k));
STARCHORUS.setTheme("foundation");return JSON.stringify(o);})()'
runq demo "$APM_Q" "out/$P-apm-marks" --wait 2 --fps 0 --eval-timeout 90 --eval "$APM_EVM" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
APM_M=$(evalv "out/$P-apm-marks.json" 1 | apm_nj); APM_ME=$(evalv "out/$P-apm-marks.json" 2)
APM_MW=$(printf '%s' '{"crossPlain":true,"crossX":true,"hollow":true,"square":true,"wargames_gap":"true,true","wargames_id":true,"wargames_pin":true,"wargames_sel":true,"whitehall_gap":"true,true","whitehall_id":true,"whitehall_pin":true,"whitehall_sel":true}' | apm_nj)
if [ "$APM_M" = "$APM_MW" ] && [ "$APM_ME" = 0 ]; then
  row "marks: D6 gap ring (open+WEP) · D5 pin arc ≠ selection ring · D7 identity in ink · unknown-band square · D8 hollow/X" PASS
else
  row "marks (err ${APM_ME:-?})" FAIL
  echo "    got:  $(printf '%s' "$APM_M" | cut -c1-360)"; echo "    want: $APM_MW"
fi

# ---- fixtures: aged.json = generator output; every recon-db fixture carries last_seen (the collector writes it); field-probes-aged exists
python3 tools/gen-testdata.py --aged --out "out/$P-aged.json" 2>/dev/null
rowif "aged.json = gen-testdata --aged" cmp -s "out/$P-aged.json" "$F/aged.json"
APM_LS=$(python3 - "$F" <<'PY'
import glob, json, sys
bad = []
for f in sorted(glob.glob(sys.argv[1] + "/*.json")):
    d = json.load(open(f))
    if d.get("source") == "recon-db" and any("last_seen" not in a for a in d["aps"]) and not f.endswith("aged.json"):
        bad.append(f.rsplit("/", 1)[-1])
print(",".join(bad) if bad else "ok")
PY
)
rowif "fixtures: recon-db fixtures carry last_seen [$APM_LS]" [ "$APM_LS" = ok ]
APM_LC=$(python3 - "$F" <<'PYLC'
import glob, json, sys
bad = []
for f in sorted(glob.glob(sys.argv[1] + "/*.json")):
    d = json.load(open(f))
    if d.get("source") in ("recon-db", "none"):
        continue
    if any("last_seen" in o for a in d["aps"] for o in [a] + a["clients"]) or any("last_seen" in c for c in d["unassociated"]):
        bad.append(f.rsplit("/", 1)[-1])
print(",".join(bad) if bad else "ok")
PYLC
)
rowif "fixtures: capture fixtures (airodump/tcpdump/iw) carry no last_seen, like their collectors [$APM_LC]" [ "$APM_LC" = ok ]
APM_AG=$(python3 - "$F" <<'PY'
import json, sys
from collections import Counter
d = json.load(open(sys.argv[1] + "/field-probes-aged.json")); g = d["generated"]; c = Counter()
for a in d["aps"]:
    age = g - a["last_seen"]; c["t0" if age < 60 else "t1" if age < 300 else "t2" if age < 900 else "t3"] += 1
print("all4" if len(c) == 4 else "tiers:" + ",".join(sorted(c)))
PY
)
rowif "fixtures: field-probes-aged.json spans all four tiers [$APM_AG]" [ "$APM_AG" = all4 ]

# ---- events on the served fixture: the first poll after boot is a NEW source's first capture -> no arrivals, departures, cues
APM_EVP='(async()=>{await STARCHORUS.wait(600);const e=STARCHORUS.stats().events;return [e.captureSeq,e.arrived,e.departed,e.changed,e.cues,STARCHORUS.stats().sourceKind].join("/");})()'
runq "$F/field-probes.json" "?intro=0&spin=0&debug=1" "out/$P-apm-serve" --wait 3 --fps 0 --eval "$APM_EVP" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
APM_P=$(evalv "out/$P-apm-serve.json" 1); APM_PE=$(evalv "out/$P-apm-serve.json" 2)
if [ "$APM_P" = 1/0/0/0/0/live ] && [ "$APM_PE" = 0 ]; then row "events: served field-probes.json: first poll -> captureSeq 1, arrived = departed = 0 [$APM_P]" PASS
else row "events: served field-probes.json: first poll -> captureSeq 1, arrived = departed = 0 [$APM_P]" FAIL; fi
