# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/theme-whitehall.sh -- the Whitehall theme.
#   true exercise banner (every line ends with the disclaimer) · plot-freshness tote lamps (D1) · teleprinter logon (STARTEX, ITA2 characters, constant 37.5 ms) ·
#   sector clock (hand from `generated`) · ownship symbol · the new plot's own dashed mark · U1 = no (the sky still turns) ·
#   the middle dot U+00B7 has an advance in 'Starchorus Sans' (both faces leave it out; the next font of the stack sets it)
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only TWH_* globals are set.

TWH_Q="?poll=0&spin=0&intro=0&debug=1&theme=whitehall"
twh_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }

# ---- the exercise banner: text per source kind, every line ends with the disclaimer, no "SIMULATED" on real data, visible in Whitehall only
TWH_EVB='(async()=>{
await STARCHORUS.wait(900);const o={},D=" · NOT A GOVERNMENT SYSTEM";
const doc=(src,g)=>({source:src,generated:g,aps:[{bssid:"02:00:00:00:13:01",ssid:"w",band:"2.4",channel:6,rssi:-50,security:"WPA2",clients:[]}],unassociated:[]});
const st={};const snap=(k)=>{const b=STARCHORUS.bannerLines(),d=[document.getElementById("classbar-top").textContent,document.getElementById("classbar-bot").textContent];st[k]=[b[0],b[1],d[0]===b[0]&&d[1]===b[1],b.every(l=>l.endsWith(D))];};
STARCHORUS.loadDemo();snap("demo");
STARCHORUS.load(doc("recon-db",100),"lv",{mode:"live"});snap("live");
STARCHORUS.load(doc("airodump-csv",200),"rc");snap("recorded");
STARCHORUS.load(doc("iw-scan-ACTIVE",300),"ac");snap("active");
STARCHORUS.load({source:"none",generated:400,aps:[],unassociated:[]},"nn");snap("none");
STARCHORUS.load(doc("re<con>db;x",500),"sx");snap("sanitised");
o.st=JSON.stringify(st);
o.top=STARCHORUS.bannerLines()[0];
o.sim=Object.keys(st).filter(k=>/SIMULATED/.test(st[k][1])).join(",");
const vis=()=>[getComputedStyle(document.getElementById("classbar-top")).display,getComputedStyle(document.getElementById("classbar-bot")).display].join();
o.wh=vis();STARCHORUS.setTheme("wargames");o.wg=vis();STARCHORUS.setTheme("foundation");o.fd=vis();STARCHORUS.setTheme("whitehall");
o.rule=getComputedStyle(document.documentElement).getPropertyValue("--banner-rule").trim();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "$TWH_Q" "out/$P-twh-banner" --width 1440 --height 900 --wait 2 --fps 0 --eval-timeout 90 --eval "$TWH_EVB" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
TWH_B=$(evalv "out/$P-twh-banner.json" 1 | twh_nj); TWH_BE=$(evalv "out/$P-twh-banner.json" 2)
TWH_BW=$(printf '%s' '{"errors":0,"fd":"none,none","rule":"#7a1414","sim":"demo","st":"{\"demo\":[\"EXERCISE – EXERCISE – EXERCISE · NOT A GOVERNMENT SYSTEM\",\"SIMULATED PLOTS · PASSIVE RECEIVE ONLY · NOT A GOVERNMENT SYSTEM\",true,true],\"live\":[\"EXERCISE – EXERCISE – EXERCISE · NOT A GOVERNMENT SYSTEM\",\"REAL-WORLD DATA · NOT EXERCISE PLAY · RECON-DB · LIVE · NOT A GOVERNMENT SYSTEM\",true,true],\"recorded\":[\"EXERCISE – EXERCISE – EXERCISE · NOT A GOVERNMENT SYSTEM\",\"REAL-WORLD DATA · NOT EXERCISE PLAY · AIRODUMP-CSV · RECORDED · NOT A GOVERNMENT SYSTEM\",true,true],\"active\":[\"EXERCISE – EXERCISE – EXERCISE · NOT A GOVERNMENT SYSTEM\",\"ACTIVE SCAN · THE COLLECTOR SENT PROBE REQUESTS · IW-SCAN-ACTIVE · NOT A GOVERNMENT SYSTEM\",true,true],\"none\":[\"EXERCISE – EXERCISE – EXERCISE · NOT A GOVERNMENT SYSTEM\",\"ENDEX · NO FEED · NOT A GOVERNMENT SYSTEM\",true,true],\"sanitised\":[\"EXERCISE – EXERCISE – EXERCISE · NOT A GOVERNMENT SYSTEM\",\"REAL-WORLD DATA · NOT EXERCISE PLAY · RECONDBX · RECORDED · NOT A GOVERNMENT SYSTEM\",true,true]}","top":"EXERCISE – EXERCISE – EXERCISE · NOT A GOVERNMENT SYSTEM","wg":"none,none","wh":"block,block"}' | twh_nj)
if [ "$TWH_B" = "$TWH_BW" ] && [ "$TWH_BE" = 0 ]; then
  row "Whitehall: exercise banner: top EXERCISE – EXERCISE – EXERCISE, bottom per source kind (SIMULATED PLOTS only for the demo; REAL-WORLD DATA · NOT EXERCISE PLAY · SOURCE · LIVE|RECORDED; the active line; ENDEX · NO FEED), every line ends with the disclaimer, the source is sanitised chrome, DOM = model, visible in Whitehall only, rule #7a1414" PASS
else
  row "Whitehall: exercise banner (err ${TWH_BE:-?})" FAIL
  echo "    got:  $(printf '%s' "$TWH_B" | cut -c1-900)"; echo "    want: $TWH_BW"
fi

# ---- tote lamps against a Python recount of aged.json (D1 rules), 1:1 with the tiers; the four labels
TWH_PYT=$(python3 - <<'PY'
import json
d = json.load(open("tests/fixtures/aged.json"))
g = d["generated"]; t = {"2.4": [0]*4, "5": [0]*4, "6": [0]*4}; undated = 0; unk = 0
for a in d["aps"]:
    ls = a.get("last_seen")
    if ls is None or ls <= 0: undated += 1; continue
    age = g - ls
    if age < 0:
        if -age > 300: undated += 1; continue
        age = 0
    tier = 0 if age < 60 else 1 if age < 300 else 2 if age < 900 else 3
    band = {"2.4GHz": "2.4", "5GHz": "5", "6GHz": "6"}.get(a.get("band"))
    if band is None: unk += 1; continue
    t[band][tier] += 1
print(json.dumps([t["2.4"], t["5"], t["6"], undated, unk], separators=(",", ":")))
PY
)
TWH_EVT='(async()=>{await STARCHORUS.wait(1500);const o={},t=STARCHORUS.tote(),f=STARCHORUS.stats().fresh;
o.model=JSON.stringify([t.bands["2.4"],t.bands["5"],t.bands["6"],t.undated,t.unknown]);o.labels=t.labels.join("/");
o.sum=[0,1,2,3].map(i=>t.bands["2.4"][i]+t.bands["5"][i]+t.bands["6"][i]).join()===[f.t0,f.t1,f.t2,f.t3].join();
const tb=document.getElementById("tote");o.dom=[tb.hidden,tb.querySelectorAll(".lamp").length,tb.querySelectorAll(".lamp.on").length,tb.querySelectorAll(".tr").length].join();
o.lampOn=[...tb.querySelectorAll(".lamp.on")].map(e=>e.textContent).join("");
STARCHORUS.setTheme("wargames");await STARCHORUS.wait(100);o.wg=document.getElementById("tote").hidden;STARCHORUS.setTheme("whitehall");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$F/aged.json" "$TWH_Q" "out/$P-twh-tote" --width 1440 --height 900 --wait 2 --fps 0 --eval-timeout 90 --eval "$TWH_EVT" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
TWH_T=$(evalv "out/$P-twh-tote.json" 1 | twh_nj); TWH_TE=$(evalv "out/$P-twh-tote.json" 2)
TWH_TW=$(TWH_PYT="$TWH_PYT" python3 -c 'import json,os;print(json.dumps({"dom":"false,12,4,5","errors":0,"labels":"HEARD/RECENT/FADING/ON RECORD","lampOn":"4222","model":os.environ["TWH_PYT"],"sum":True,"wg":True},sort_keys=True,separators=(",",":"),ensure_ascii=False))')
if [ "$TWH_T" = "$TWH_TW" ] && [ "$TWH_TE" = 0 ]; then
  row "Whitehall: plot-freshness tote lamps = Python recount of aged.json per band and D1 tier (HEARD/RECENT/FADING/ON RECORD, undated counted apart), tiers sum to stats().fresh, 12 lamps, hidden in WarGames" PASS
else
  row "Whitehall: tote lamps (err ${TWH_TE:-?})" FAIL
  echo "    got:  $(printf '%s' "$TWH_T" | cut -c1-700)"; echo "    want: $TWH_TW"
fi

# ---- the teleprinter logon: STARTEX first, ITA2-capable characters only (^[-A-Z0-9 ?:().,'/=+]+$), a constant 37.5 ms per character (measured on the typed text)
TWH_EVL='(async()=>{
await STARCHORUS.wait(1300);const o={};
const re=/^[-A-Z0-9 ?:().,'"'"'\/=+]+$/;
const mk=(src,g)=>({source:src,generated:g,aps:[],unassociated:[]});const bad=[];const first=[];
const kinds=[["demo",()=>STARCHORUS.loadDemo()],["live",()=>STARCHORUS.load(mk("recon-db",1),"a",{mode:"live"})],["recorded",()=>STARCHORUS.load(mk("recon-db",2),"b")],["active",()=>STARCHORUS.load(mk("iw-scan-ACTIVE",3),"c")],["none",()=>STARCHORUS.load({source:"none",generated:4,aps:[],unassociated:[]},"d")]];
for(const [k,f] of kinds){f();const l=STARCHORUS.logonLines();first.push(l[0]);for(const x of l)if(!re.test(x))bad.push(k+":"+x.slice(0,30));}
o.first=first.join(",");o.bad=bad.join("|")||"none";o.lines=STARCHORUS.logonLines().length;
o.timing=JSON.stringify(STARCHORUS.logonTiming());
// measure: the typed text grows one character per step; intervals between growth events inside a line
STARCHORUS.load(mk("recon-db",9),"z",{mode:"live"});
const t=document.getElementById("intro-text");const stamps=[];let last=t.textContent.length,run=true;
const iv=setInterval(()=>{const n=t.textContent.length;if(n>last)stamps.push(performance.now());last=n;},4);
await STARCHORUS.wait(4200);clearInterval(iv);
const d=[];for(let i=1;i<stamps.length;i++){const x=stamps[i]-stamps[i-1];if(x<120)d.push(x);}d.sort((a,b)=>a-b);
o.n=d.length>40;o.median=d.length?Math.round(d[d.length>>1]):0;o.spread=d.length?Math.round(d[Math.floor(d.length*0.9)]-d[Math.floor(d.length*0.1)]):0;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "?poll=0&spin=0&debug=1&theme=whitehall" "out/$P-twh-logon" --width 1440 --height 900 --wait 1 --fps 0 --eval-timeout 90 --eval "$TWH_EVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
TWH_L=$(evalv "out/$P-twh-logon.json" 1); TWH_LE=$(evalv "out/$P-twh-logon.json" 2)
TWH_LOK=$(printf '%s' "$TWH_L" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["first"]=="STARTEX,STARTEX,STARTEX,STARTEX,STARTEX" and d["bad"]=="none" and d["lines"]==6 and d["timing"]=="[37.5,37.5]" and d["n"] and 35<=d["median"]<=45 and d["spread"]<=10 and d["errors"]==0)' 2>/dev/null)
if [ "$TWH_LOK" = True ] && [ "$TWH_LE" = 0 ]; then row "Whitehall: teleprinter logon: STARTEX first, every line in the ITA2-capable set for all five source kinds, token 37.5 ms, measured median within 35-45 ms with a spread <= 10 ms [$(printf '%s' "$TWH_L" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["median"],d["spread"])' 2>/dev/null)]" PASS
else row "Whitehall: teleprinter logon: STARTEX first, every line in the ITA2-capable set for all five source kinds, token 37.5 ms, measured median within 35-45 ms with a spread <= 10 ms [$(printf '%s' "$TWH_L" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["median"],d["spread"])' 2>/dev/null)]" FAIL; fi

# ---- sector clock (hand + period from `generated`), ownship symbol, the new plot's own mark, U1 = no (the sky still turns)
TWH_PYC=$(python3 -c 'import json;f=lambda x:int(x) if x==int(x) else x;print(json.dumps([[g,f((g%3600)/10),(g%3600)//300,((g%3600)//300)%3] for g in (0,1789300000,1789300299,1789300300,1789303599)],separators=(",",":")))')
TWH_EVC='(async()=>{
await STARCHORUS.wait(800);const o={};
const ap=(n,ch)=>({bssid:"02:00:00:00:14:0"+n,ssid:"c"+n,band:"5",channel:ch||36,rssi:-50-n*3,security:"WPA2",clients:[]});
const mk=(g,n)=>({source:"recon-db",generated:g,aps:Array.from({length:n},(_,i)=>ap(i+1,36+4*i)),unassociated:[]});
const rows=[];for(const g of [0,1789300000,1789300299,1789300300,1789303599]){STARCHORUS.load(mk(g,1),"clk"+g);const c=STARCHORUS.plotClock();rows.push([g,c.angleDeg,c.period,c.colour]);}
o.clock=JSON.stringify(rows);
const hand=document.getElementById("plotclock-hand");STARCHORUS.load(mk(1789300000,1),"clkx");o.hand=[hand.style.transform,document.getElementById("plotclock").getAttribute("aria-label")].join("|");
STARCHORUS.load({source:"recon-db",aps:[ap(1)],unassociated:[]},"clkn");o.undated=[STARCHORUS.plotClock().generated,hand.style.display].join();
const cs=getComputedStyle(document.documentElement);o.vars=["--clock-p1","--clock-p2","--clock-p3"].map(v=>cs.getPropertyValue(v).trim()).join();
const TH=STARCHORUS._internals.THEMES;o.tok=[TH.whitehall.look.clock.p1,TH.whitehall.look.clock.p2,TH.whitehall.look.clock.p3].join();
STARCHORUS.setTheme("wargames");await STARCHORUS.wait(100);o.wg=document.getElementById("plotclock").hidden;STARCHORUS.setTheme("foundation");await STARCHORUS.wait(100);o.fd=document.getElementById("plotclock").hidden;STARCHORUS.setTheme("whitehall");
// ownship: painted at the centre, unframed (nothing at the WarGames ring radii); WarGames keeps its ring
STARCHORUS.setView("2d");STARCHORUS.load(mk(100,1),"own");await STARCHORUS.wait(1200);STARCHORUS.setFixedTime(9800000);await STARCHORUS.wait(120);STARCHORUS.frame();
const CX=Math.round(innerWidth/2),CY=Math.round(innerHeight/2),px=(x,y)=>STARCHORUS.pixel("sky",x,y).a;
const ringAny=(r)=>{let n=0;for(let k=0;k<24;k++){const a=k*Math.PI/12;if(px(CX+Math.cos(a)*r,CY+Math.sin(a)*r)>0)n++;}return n;};
o.whOwn=[px(CX,CY-4)>0,ringAny(14)===0,ringAny(18.5)===0].join();
STARCHORUS.setTheme("wargames");await STARCHORUS.wait(150);STARCHORUS.frame();o.wgRing=[ringAny(10.5)>0].join();STARCHORUS.setTheme("whitehall");await STARCHORUS.wait(150);STARCHORUS.setFixedTime(null);
// the new plot mark: a dashed ring around an AP that arrived, for 3 captures, only in Whitehall
STARCHORUS.load(mk(200,2),"np");await STARCHORUS.wait(1500);
STARCHORUS.load(mk(205,3),"np");await STARCHORUS.wait(1500);STARCHORUS.setFixedTime(9900000);await STARCHORUS.wait(120);STARCHORUS.frame();
const ringN=(id)=>{const s=STARCHORUS.nodeScreen(id),n=STARCHORUS.node(id);let c=0;for(let k=0;k<48;k++){const a=k*Math.PI/24,r=n.px+9;if(px(s.sx+Math.cos(a)*r,s.sy+Math.sin(a)*r)>0)c++;}return c;};
const idN="02:00:00:00:14:03",idO="02:00:00:00:14:01";
o.newPlot=[ringN(idN)>0,ringN(idO)===0,STARCHORUS.node(idN).isNew===true||STARCHORUS.stats().events.newAps===1].join();
STARCHORUS.setFixedTime(null);for(let i=0;i<3;i++){STARCHORUS.load(mk(210+5*i,3),"np");await STARCHORUS.wait(300);}await STARCHORUS.wait(600);STARCHORUS.setFixedTime(9950000);await STARCHORUS.wait(120);STARCHORUS.frame();
o.newGone=ringN(idN)===0;
// U1 = no: the sky still turns in Whitehall (spin on by default)
o.spin=[STARCHORUS.getToggles().spin,STARCHORUS._internals.THEMES.whitehall.motion.autoRotateRadPerS>0].join();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "?poll=0&debug=1&intro=0&theme=whitehall" "out/$P-twh-clock" --width 1440 --height 900 --wait 1 --fps 0 --eval-timeout 120 --eval "$TWH_EVC" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
TWH_C=$(evalv "out/$P-twh-clock.json" 1 | twh_nj); TWH_CE=$(evalv "out/$P-twh-clock.json" 2)
TWH_CWB='{"clock":"","errors":0,"fd":true,"hand":"rotate(280deg)|sector clock, period 10 of 12","newGone":true,"newPlot":"true,true,true","spin":"true,true","tok":"#8a4a44,#a08a4a,#4a6a8f","undated":",none","vars":"#8a4a44,#a08a4a,#4a6a8f","wg":true,"wgRing":"true","whOwn":"true,true,true"}'
TWH_CW=$(printf '%s' "$TWH_CWB" | TWH_PYC="$TWH_PYC" python3 -c 'import json,os,sys;w=json.load(sys.stdin);w["clock"]=json.dumps(json.loads(os.environ["TWH_PYC"]),separators=(",",":"));print(json.dumps(w,sort_keys=True,separators=(",",":"),ensure_ascii=False))')
if [ "$TWH_C" = "$TWH_CW" ] && [ "$TWH_CE" = 0 ]; then
  row "Whitehall: sector clock: hand and period from generated (Python recount, undated = no hand, aria-label), token colours in the CSS, hidden in the other themes; ownship symbol unframed (WarGames keeps its ring); a new plot's own dashed mark for 3 captures; U1 = no (the sky still turns)" PASS
else
  row "Whitehall: clock, ownship, new plot (err ${TWH_CE:-?})" FAIL
  echo "    got:  $(printf '%s' "$TWH_C" | cut -c1-900)"; echo "    want: $TWH_CW"
fi

# ---- D15 with the sector clock and the tote lamps (Whitehall, three viewports), static rows
eval "$(grep '^EDG_OVL=' tools/regress.d/edge-layout.sh)"
for TWH_VP in 1440x900 1280x800 1000x640; do
  runq "$F/field-probes.json" "$TWH_Q" "out/$P-twh-d15-$TWH_VP" --width "${TWH_VP%x*}" --height "${TWH_VP#*x}" --wait 4 --fps 0 --eval "$EDG_OVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
  TWH_OV=$(evalv "out/$P-twh-d15-$TWH_VP.json" 1); TWH_OVE=$(evalv "out/$P-twh-d15-$TWH_VP.json" 2)
  if [ "$TWH_OV" = 0 ] && [ "$TWH_OVE" = 0 ]; then row "Whitehall: D15 overlap 0 with clock, tote lamps and banners $TWH_VP (err ${TWH_OVE:-?}) [$(printf '%s' "$TWH_OV" | cut -c1-60)]" PASS
  else row "Whitehall: D15 overlap 0 with clock, tote lamps and banners $TWH_VP (err ${TWH_OVE:-?}) [$(printf '%s' "$TWH_OV" | cut -c1-60)]" FAIL; fi
done
TWH_NET=$(grep -cE 'method:|POST|XMLHttpRequest|WebSocket|EventSource|sendBeacon' starchorus.html); TWH_FE=$(grep -c 'fetch(' starchorus.html)
if [ "$TWH_NET" = 0 ] && [ "$TWH_FE" = 1 ]; then row "Whitehall: passivity: no send path in the page (= $TWH_NET), fetch( = $TWH_FE" PASS
else row "Whitehall: passivity: no send path in the page (= $TWH_NET), fetch( = $TWH_FE" FAIL; fi
TWH_CLK=$(awk '/^function toteObj\(/,/^function renderBadge\(/' starchorus.html | grep -cE 'Math\.random|Date\.now|performance\.now|new Date\(')
rowif "Whitehall: the clock and the tote read no wall clock and no random ($TWH_CLK)" [ "$TWH_CLK" = 0 ]
TWH_DIS=$(grep -c 'NOT A GOVERNMENT SYSTEM' starchorus.html)
rowif "Whitehall: the disclaimer is in the copy tokens of every banner line ($TWH_DIS occurrences)" [ "$TWH_DIS" -ge 7 ]

# ---- the middle dot U+00B7 in 'Starchorus Sans': the embedded subset carries a glyph for it with no advance (measured 22 October 2026: measureText("A·B") equals
#      measureText("AB") in both weights), so Whitehall texts such as "0 free · 0 associated" had the dot over the character after it. Both @font-face rules leave
#      U+00B7 out (unicode-range: U+0-B6, U+B8-10FFFF) and the next font of the stack sets it. The row measures the advance in both weights (> 0), reads the two
#      ranges back from document.fonts, and keeps the defect in view as a control: the same face loaded once more without the range (a FontFace made from the
#      rule's src) still gives the dot no advance (0), so the fix is the range, not the font. On the page before the fix the row is red (advances 0, ranges U+0-10FFFF).
TWH_EVD='(async()=>{const o={};await Promise.all([document.fonts.load("400 20px \"Starchorus Sans\""),document.fonts.load("500 20px \"Starchorus Sans\"")]);
const c=document.createElement("canvas").getContext("2d");const adv=(f)=>{c.font=f;return +(c.measureText("A·B").width-c.measureText("AB").width).toFixed(2)};
o.w400=adv("400 20px \"Starchorus Sans\"");o.w500=adv("500 20px \"Starchorus Sans\"");o.pos=o.w400>0&&o.w500>0;
o.faces=[...document.fonts].filter(f=>f.family.replace(/["\x27]/g,"")==="Starchorus Sans").sort((a,b)=>a.weight-b.weight).map(f=>f.weight+":"+f.unicodeRange).join("|");
let src="";for(const sh of document.styleSheets){try{for(const r of sh.cssRules){if(r.type===CSSRule.FONT_FACE_RULE&&/Starchorus Sans/.test(r.style.getPropertyValue("font-family"))&&r.style.getPropertyValue("font-weight")==="400")src=r.style.getPropertyValue("src")}}catch(e){}}
o.ctl=null;if(src){const f=new FontFace("Starchorus Probe",src,{weight:"400"});await f.load();document.fonts.add(f);o.ctl=adv("400 20px \"Starchorus Probe\"");document.fonts.delete(f)}
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
runq demo "$TWH_Q" "out/$P-twh-dot" --width 1000 --height 640 --wait 2 --fps 0 --eval-timeout 60 --eval "$TWH_EVD" >/dev/null 2>&1
TWH_D=$(evalv "out/$P-twh-dot.json" 1)
TWH_DV=$(printf '%s' "$TWH_D" | python3 -c 'import json,sys
try: o=json.load(sys.stdin)
except Exception: o={}
ok=o.get("pos") is True and o.get("faces")=="400:U+0-B6, U+B8-10FFFF|500:U+0-B6, U+B8-10FFFF" and o.get("ctl")==0 and o.get("errors")==0
print("ok" if ok else "bad", "400:", o.get("w400"), "500:", o.get("w500"), "raw face:", o.get("ctl"), "ranges:", o.get("faces"))')
if [ "${TWH_DV%% *}" = ok ]; then row "Whitehall: the middle dot U+00B7 has an advance in Starchorus Sans (${TWH_DV#ok }; the raw face without the range gives 0)" PASS
else row "Whitehall: the middle dot U+00B7 has an advance in Starchorus Sans [$(printf '%s' "$TWH_DV" | cut -c1-160)]" FAIL; fi
