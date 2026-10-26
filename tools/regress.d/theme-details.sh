# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/theme-details.sh -- theme details and D13.
#   D13: motion.introStyle + one "seen" flag per theme id (a single global flag would swallow every
#   intro after the first) · Foundation's coalescing intro · WarGames' per-AP lamp strip · Whitehall's plaque
#   tooltip · Foundation's lit dust · Foundation's slab chrome, small capitals and place-and-time caption.
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only TDT_* globals are set.

TDT_Q="?poll=0&spin=0&intro=0&debug=1&autolod=0"
# --ready on the runs that read a loaded capture or a static answer: the fonts are loaded, the capture is in and a frame has been painted after both (--wait stays the ceiling);
# the runs that watch the intro, the caption or the dust keep their fixed wait
TDT_RDY='document.fonts.ready.then(() => new Promise(r => requestAnimationFrame(() => r(!!window.STARCHORUS && STARCHORUS.stats().apsTotal > 0 && STARCHORUS.stats().sourceKind !== "demo"))))'
tdt_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }

# ---- D13 + the three intro styles. The flag key carries the theme id, so each theme still introduces itself
# once. The negative control is the shipped bug: with ONE shared flag the second theme's logon never appears.
TDT_EVI='(async()=>{const o={},btn=document.getElementById("t-theme");
const disp=()=>getComputedStyle(document.getElementById("intro")).display;
const keys=()=>Object.keys(sessionStorage).filter(k=>k.indexOf("starchorus.introShown.")===0).sort().join(",");
o.styles=["foundation","wargames","whitehall"].map(t=>STARCHORUS._internals.THEMES[t].motion.introStyle).join("/");
for(const k of Object.keys(sessionStorage)) if(k.indexOf("starchorus.introShown.")===0) sessionStorage.removeItem(k);
for(let i=0;i<4&&STARCHORUS.getTheme()!=="foundation";i++){btn.click();STARCHORUS.skipIntro();await STARCHORUS.wait(60);}
for(const k of Object.keys(sessionStorage)) if(k.indexOf("starchorus.introShown.")===0) sessionStorage.removeItem(k);
btn.click();await STARCHORUS.wait(90);o.t1=[STARCHORUS.getTheme(),disp()].join(":");STARCHORUS.skipIntro();
btn.click();await STARCHORUS.wait(90);o.t2=[STARCHORUS.getTheme(),disp()].join(":");STARCHORUS.skipIntro();
o.keys=keys();
btn.click();await STARCHORUS.wait(90);o.back=[STARCHORUS.getTheme(),disp()].join(":");STARCHORUS.skipIntro();
o.keysAll=keys();
btn.click();await STARCHORUS.wait(90);o.again=[STARCHORUS.getTheme(),disp()].join(":");STARCHORUS.skipIntro();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
runq "$F/field-probes.json" "?poll=0&spin=0&debug=1&autolod=0" "out/$P-tdt-intro" --width 1440 --height 900 --wait 3 --fps 0 --eval-timeout 120 --eval "$TDT_EVI" >/dev/null 2>&1
TDT_I=$(evalv "out/$P-tdt-intro.json" 1 | tdt_nj)
# wargames and whitehall both type (display block on arrival); foundation coalesces, so its overlay stays away;
# a second visit to an already-seen theme shows nothing. Both typed themes have their own flag.
TDT_IW=$(printf '%s' '{"again":"wargames:none","back":"foundation:none","errors":0,"keys":"starchorus.introShown.wargames,starchorus.introShown.whitehall","keysAll":"starchorus.introShown.foundation,starchorus.introShown.wargames,starchorus.introShown.whitehall","styles":"coalesce/typed/typed","t1":"wargames:block","t2":"whitehall:block"}' | tdt_nj)
if [ "$TDT_I" = "$TDT_IW" ]; then
  row "intro: D13: motion.introStyle coalesce/typed/typed, one seen-flag per theme id (whitehall's logon is reachable after wargames'; a second visit stays silent)" PASS
else
  row "intro: D13 intro styles + per-theme flag" FAIL; echo "    got:  $TDT_I"; echo "    want: $TDT_IW"
fi
# static: the flag is keyed by theme id, there is no global logonShown key; §39 still makes no theme-id comparison
TDT_S1=$(grep -c 'sessionFlag("logonShown"' "$H"); TDT_S2=$(grep -c '"introShown\." + THEME\.meta\.id' "$H")
TDT_S3=$(grep -c 'logonSequence' "$H")
rowif "intro: no global logonShown ($TDT_S1), flag keyed by theme id ($TDT_S2), no logonSequence ($TDT_S3)" [ "$TDT_S1/$TDT_S2/$TDT_S3" = 0/1/0 ]

# ---- Foundation's coalescing intro: the same sky, gathered from twice as far. Measured as the peak mean
# dust radius during the intro against the same switch with the flag already set; both must settle to one picture.
TDT_EVC='(async()=>{const btn=document.getElementById("t-theme");
const land=async()=>{for(let i=0;i<4&&STARCHORUS.getTheme()!=="foundation";i++){btn.click();STARCHORUS.skipIntro();await STARCHORUS.wait(80);}};
const run=async(clear)=>{await land();
 if(clear) for(const k of Object.keys(sessionStorage)) if(k.indexOf("starchorus.introShown.")===0) sessionStorage.removeItem(k);
 btn.click();STARCHORUS.skipIntro();await STARCHORUS.wait(80);btn.click();STARCHORUS.skipIntro();await STARCHORUS.wait(80);btn.click();
 const p=[];for(let i=0;i<7;i++){STARCHORUS.frame();p.push(STARCHORUS.dust().tiers[0].meanRadius);await STARCHORUS.wait(110);}
 await STARCHORUS.wait(2600);STARCHORUS.frame();
 return {peak:Math.max.apply(null,p.filter(function(v){return v!=null})),settled:STARCHORUS.dust().tiers[0].meanRadius,seen:STARCHORUS.stats().introShown};};
const a=await run(true),b=await run(false);
return JSON.stringify({wider:a.peak>b.peak*1.25,sameSettled:Math.abs(a.settled-b.settled)<0.3,seen:[a.seen,b.seen],
 frozen:await(async()=>{STARCHORUS.setFixedTime(1789300000);
  for(const k of Object.keys(sessionStorage)) if(k.indexOf("starchorus.introShown.")===0) sessionStorage.removeItem(k);
  for(let i=0;i<3;i++){btn.click();STARCHORUS.skipIntro();await STARCHORUS.wait(80);}
  return STARCHORUS.getTheme()==="foundation"&&STARCHORUS.stats().introShown===false;})(),
 errors:STARCHORUS.errors().length})})()'
runq "$F/field-probes.json" "?poll=0&spin=0&debug=1&autolod=0" "out/$P-tdt-coal" --width 1440 --height 900 --wait 3 --fps 0 --eval-timeout 150 --eval "$TDT_EVC" >/dev/null 2>&1
TDT_C=$(evalv "out/$P-tdt-coal.json" 1 | tdt_nj)
TDT_CW=$(printf '%s' '{"errors":0,"frozen":true,"sameSettled":true,"seen":[true,true],"wider":true}' | tdt_nj)
if [ "$TDT_C" = "$TDT_CW" ]; then
  row "Foundation: coalescing intro: the dust gathers from more than 1.25x its usual distance and settles to the same picture (no black screen, no typed text)" PASS
else
  row "Foundation: coalescing intro" FAIL; echo "    got:  $TDT_C"; echo "    want: $TDT_CW"
fi
# frozen time is a measured run: the coalesce must not start there, so no screenshot or digest can move
TDT_S4=$(grep -c 'if (introRunning || S.fixedTime != null) return;' "$H")
rowif "Foundation: coalesce never starts under frozen time ($TDT_S4)" [ "$TDT_S4" = 1 ]

# ---- WarGames lamp strip: one lamp per access point, channel-sorted, lit = D1 tier T0. DOM = model.
TDT_EVL='(()=>{const o={};STARCHORUS.setTheme("wargames");STARCHORUS.openDrawer("air");
const s=STARCHORUS.lampStrip(),dom=document.querySelectorAll("#lamp-strip .lamps i");
o.model=[s.shown,s.lamps.length,s.total,s.lit,s.more].join("/");
o.dom=[dom.length,document.querySelectorAll("#lamp-strip .lamps i.on").length].join("/");
o.capped=s.lamps.length===Math.min(48,s.total)&&s.more===Math.max(0,s.total-s.lamps.length);
o.sorted=s.lamps.every(function(l,i,a){return i===0||a[i-1].channel<l.channel||(a[i-1].channel===l.channel&&a[i-1].id<=l.id)});
const lit=STARCHORUS.nodes("ap").map(function(n){return STARCHORUS.node(n.id)}).filter(function(n){return n&&(n.freshTier==null||n.freshTier===0)});
o.tierRule=s.lamps.every(function(l){return l.on===lit.some(function(n){return n.id===l.id})});
o.band=(function(){const on=[].slice.call(dom).filter(function(e){return e.classList.contains("on")})[0];
 return on?getComputedStyle(on).backgroundColor:"none"})();
o.off=(function(){const d=[].slice.call(dom).filter(function(e){return !e.classList.contains("on")})[0];
 return d?getComputedStyle(d).backgroundColor:"none"})();
o.other=["foundation","whitehall"].map(function(t){STARCHORUS.setTheme(t);STARCHORUS.openDrawer("air");
 return STARCHORUS.lampStrip().shown+":"+document.querySelectorAll("#lamp-strip .lamps i").length}).join(",");
STARCHORUS.setTheme("wargames");o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
runq "$F/field-probes.json" "$TDT_Q&theme=wargames" "out/$P-tdt-lamp" --width 1440 --height 900 --wait 3 --ready "$TDT_RDY" --fps 0 --eval-timeout 90 --eval "$TDT_EVL" >/dev/null 2>&1
TDT_L=$(evalv "out/$P-tdt-lamp.json" 1 | tdt_nj)
# field-probes has 60 access points: 48 lamps, 12 dropped; 24 of the 60 were heard in the last minute and
# 21 of those fall among the 48 drawn lamps (the caption counts the population, the DOM shows the drawn view). The lit lamp
# carries its BAND colour (2.4 GHz green #2ab42a), the dark slot the chrome token #3d3d3d -- D12 in one row.
TDT_LW=$(printf '%s' '{"band":"rgb(42, 180, 42)","capped":true,"dom":"48/21","errors":0,"model":"true/48/60/24/12","off":"rgb(61, 61, 61)","other":"false:0,false:0","sorted":true,"tierRule":true}' | tdt_nj)
if [ "$TDT_L" = "$TDT_LW" ]; then
  row "WarGames: lamp strip: 48 of 60 lamps (12 more), channel-then-BSSID order, 24 of 60 heard in the last minute (D1 tier T0), 21 of them among the 48 drawn lamps, DOM = model, lit in the band colour and dark in chrome #3d3d3d, absent in the other two themes" PASS
else
  row "WarGames: lamp strip" FAIL; echo "    got:  $TDT_L"; echo "    want: $TDT_LW"
fi
# the band colour must be read at draw time, never stored under chrome (D12 / §4.1 chrome role)
TDT_S5=$(grep -c 'bandColorOf(l.band)' "$H"); TDT_S6=$(grep -c 'lampStrip: { max: 0, off: "#3d3d3d" }\|lampStrip: { max: 48, off: "#3d3d3d" }' "$H")
rowif "WarGames: lamp colour from bandColorOf ($TDT_S5), chrome holds only the dark slot ($TDT_S6 themes)" [ "$TDT_S5/$TDT_S6" = 1/3 ]

# ---- Whitehall plaque tooltip: the SAME rows, a different arrangement. Token-driven, no theme id.
TDT_EVP='(()=>{const o={},g=function(){return document.querySelector("#tip .grid")};
const keys={},cols={};for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);
 STARCHORUS.hoverNode(STARCHORUS.nodes("ap")[0].id);
 keys[t]=[].slice.call(document.querySelectorAll("#tip .grid .k")).map(function(e){return e.textContent}).join("|");
 cols[t]=getComputedStyle(g()).gridTemplateColumns.split(" ").length;
 o["plaque_"+t]=document.documentElement.dataset.plaque;}
STARCHORUS.hoverNode(null);STARCHORUS.setTheme("foundation");
o.sameRows=keys.foundation===keys.wargames&&keys.wargames===keys.whitehall;
o.rows=keys.whitehall;o.cols=[cols.foundation,cols.wargames,cols.whitehall].join("/");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
runq "$F/field-probes.json" "$TDT_Q" "out/$P-tdt-tip" --width 1440 --height 900 --wait 3 --ready "$TDT_RDY" --fps 0 --eval-timeout 90 --eval "$TDT_EVP" >/dev/null 2>&1
TDT_T=$(evalv "out/$P-tdt-tip.json" 1 | tdt_nj)
TDT_TW=$(printf '%s' '{"cols":"2/2/4","errors":0,"plaque_foundation":"off","plaque_wargames":"off","plaque_whitehall":"on","rows":"Vendor|Band|Signal|Heard|Security|Clients|Group|Device","sameRows":true}' | tdt_nj)
if [ "$TDT_T" = "$TDT_TW" ]; then
  row "Whitehall: plaque tooltip: the same eight rows in every theme, paired two-up (4 grid tracks against 2), switched by chrome.plaqueTip; no plot number, no added field" PASS
else
  row "Whitehall: plaque tooltip" FAIL; echo "    got:  $TDT_T"; echo "    want: $TDT_TW"
fi

# ---- lit dust + slab chrome, small capitals and the caption (one run)
TDT_EVF='(async()=>{const o={};await STARCHORUS.wait(1800);STARCHORUS.frame();
const d={};for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await STARCHORUS.wait(1100);STARCHORUS.frame();
 const x=STARCHORUS.dust().litSide;d[t]=[x.on,x.lit>0,x.shade>0,x.shadeColor].join(":");}
STARCHORUS.setTheme("foundation");await STARCHORUS.wait(1100);STARCHORUS.frame();
o.lit=[d.foundation,d.wargames,d.whitehall].join(" | ");
const ls=STARCHORUS.dust().litSide;o.split=Math.abs(ls.lit-ls.shade)<=ls.lit;
const cs=getComputedStyle(document.documentElement);
o.mirror=["foundation","wargames","whitehall"].map(function(t){STARCHORUS.setTheme(t);
 const c=getComputedStyle(document.documentElement);
 return c.getPropertyValue("--heading-variant").trim()+"/"+c.getPropertyValue("--panel-radius").trim()}).join(",");
STARCHORUS.setTheme("foundation");
o.h4=getComputedStyle(document.querySelector("#legend h4")).fontVariantCaps;
const cap=document.getElementById("caption");
STARCHORUS.setTheme("wargames");STARCHORUS.setTheme("foundation");
const btn=document.getElementById("t-theme");for(let i=0;i<4&&STARCHORUS.getTheme()!=="foundation";i++)btn.click();
btn.click();btn.click();btn.click();await STARCHORUS.wait(120);
o.capShown=[!cap.hidden,cap.textContent.indexOf(" · ")>0,getComputedStyle(cap.querySelector(".place")||cap).textTransform].join(":");
o.capModel=(function(){const c=STARCHORUS.caption();return [c.shown,c.place,/^[0-9]{2}:[0-9]{2} UTC$/.test(c.time||"")].join(":")})();
await STARCHORUS.wait(2300);
const vb=document.getElementById("t-view");vb.click();await STARCHORUS.wait(120);
o.capView=[!cap.hidden,cap.textContent.indexOf(" · ")>0].join(":");vb.click();await STARCHORUS.wait(120);
o.capOther=["wargames","whitehall"].map(function(t){STARCHORUS.setTheme(t);return STARCHORUS.caption().shown}).join(",");
STARCHORUS.setTheme("foundation");await STARCHORUS.wait(2300);
o.capGone=cap.hidden;o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
runq "$F/field-probes.json" "?poll=0&spin=0&debug=1&autolod=0" "out/$P-tdt-look" --width 1440 --height 900 --wait 3 --fps 0 --eval-timeout 150 --eval "$TDT_EVF" >/dev/null 2>&1
TDT_F=$(evalv "out/$P-tdt-look.json" 1 | tdt_nj)
TDT_FW=$(printf '%s' '{"capGone":true,"capModel":"true:This device:true","capOther":"false,false","capShown":"true:true:none","capView":"true:true","errors":0,"h4":"small-caps","lit":"true:true:true:rgba(176,122,60,0.6) | false:false:false: | false:false:false:","mirror":"small-caps/3px,normal/0px,normal/2px","split":true}' | tdt_nj)
if [ "$TDT_F" = "$TDT_FW" ]; then
  row "Foundation: dust is lit not emitting (both sides drawn, bronze shade, off in the other two themes) · slab chrome 3 px · small capitals · the caption names observer and capture time, is not re-cased and goes away" PASS
else
  row "Foundation: lit dust + slab chrome + caption" FAIL; echo "    got:  $TDT_F"; echo "    want: $TDT_FW"
fi
# the bronze is an ornament: it must keep ΔE ≥ 8 to the alarm colour, so gold still means alarm alone (theme-foundation.sh)
runq demo "$TDT_Q" "out/$P-tdt-themes" --wait 1 --ready --fps 0 --eval "JSON.stringify(STARCHORUS._internals.THEMES)" >/dev/null 2>&1
TDT_DE=$(python3 - "out/$P-tdt-themes.json" <<'PY'
import importlib.util, sys
s = importlib.util.spec_from_file_location("cc", "tools/check-colors.py"); cc = importlib.util.module_from_spec(s); s.loader.exec_module(cc)
t = cc.load(sys.argv[1])["foundation"]; base = cc.parse(t["surface"]["base"])
shade = cc.over(cc.parse(t["particles"]["shade"]), base); alarm = cc.over(cc.parse(t["status"]["alarm"]), base)
print("%.1f" % cc.dE(shade, alarm))
PY
)
rowif "Foundation: bronze shade keeps its distance from alarm (ΔE $TDT_DE ≥ 8)" python3 -c "import sys;sys.exit(0 if float('${TDT_DE:-0}')>=8 else 1)"

# ---- the caption is an overlay (pointer-transparent, gone after ~2 s), so it is not in the D15 panel
# set — but it must never sit on the CHANNEL BAR, which carries data. At its first position it did exactly
# that (it was laid out inside #chanbar's rectangle at z-index 20), which is why this row exists.
TDT_EVX='(async()=>{const o={},btn=document.getElementById("t-theme");
for(let i=0;i<4&&STARCHORUS.getTheme()!=="foundation";i++){btn.click();STARCHORUS.skipIntro();await STARCHORUS.wait(60);}
btn.click();btn.click();btn.click();await STARCHORUS.wait(150);
const cap=document.getElementById("caption");o.shown=!cap.hidden;
const c=cap.getBoundingClientRect();
const hit=(id)=>{const e=document.getElementById(id);if(!e||e.hidden)return 0;
 const r=e.getBoundingClientRect(),w=Math.min(c.right,r.right)-Math.max(c.left,r.left),h=Math.min(c.bottom,r.bottom)-Math.max(c.top,r.top);
 return w>0&&h>0?Math.round(w*h):0};
o.chanbar=hit("chanbar");o.stats=hit("stats");o.masthead=hit("masthead");o.source=hit("source");
o.inView=c.left>=0&&c.right<=innerWidth&&c.top>=0&&c.bottom<=innerHeight;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
for TDT_W in 1440x900 760x600; do
  runq "$F/field-probes.json" "?poll=0&spin=0&debug=1&autolod=0" "out/$P-tdt-cap-$TDT_W" --width "${TDT_W%x*}" --height "${TDT_W#*x}" --wait 3 --fps 0 --eval-timeout 90 --eval "$TDT_EVX" >/dev/null 2>&1
  TDT_X=$(evalv "out/$P-tdt-cap-$TDT_W.json" 1 | tdt_nj)
  TDT_XW=$(printf '%s' '{"chanbar":0,"errors":0,"inView":true,"masthead":0,"shown":true,"source":0,"stats":0}' | tdt_nj)
  if [ "$TDT_X" = "$TDT_XW" ]; then
    row "Foundation: caption at $TDT_W: visible, inside the viewport, and clear of the channel bar, stats, masthead and source" PASS
  else
    row "Foundation: caption clear of the data panels at $TDT_W" FAIL; echo "    got:  $TDT_X"; echo "    want: $TDT_XW"
  fi
done

# ---- a period pip and a sound cloud are NOT built: the page holds exactly one audio path (the homing
# tone). This row makes "not built" a checked fact rather than a claim.
TDT_A1=$(grep -c 'new (window.AudioContext || window.webkitAudioContext)()' "$H")
TDT_A2=$(grep -c 'createOscillator()' "$H")
rowif "audio unchanged: one AudioContext ($TDT_A1), one oscillator ($TDT_A2) — no period pip, no sound cloud" [ "$TDT_A1/$TDT_A2" = 1/1 ]
