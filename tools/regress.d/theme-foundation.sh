# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/theme-foundation.sh -- the Foundation theme.
#   dust cohesion = freshness · gold only for the alarm · no spiral ornament · the Compendium line · the Vault card · the core's heartbeat · dawn/dusk spirals
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only TFD_* globals are set.

TFD_Q="?poll=0&spin=0&intro=0&debug=1"
tfd_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }

# ---- dust cohesion = freshness; the core, the radius and the hit-test do not change; dawn/dusk rotate the dust
TFD_EVD='(async()=>{
await STARCHORUS.wait(800);const o={},G=2000000;
const ap=(n,age)=>({bssid:"02:00:00:00:15:0"+n,ssid:"d"+n,band:"5",channel:36+4*n,rssi:-55,security:"WPA2",last_seen:G-age,clients:[]});
STARCHORUS.load({source:"recon-db",generated:G,aps:[ap(1,0),ap(2,120),ap(3,600),ap(4,2000)],unassociated:[]},"dust");
await STARCHORUS.wait(2600);STARCHORUS.setFixedTime(9500000);await STARCHORUS.wait(150);STARCHORUS.frame();
const d=STARCHORUS.dust().tiers;o.aps=d.map(t=>t.aps).join("");
const R=d.map(t=>t.meanRadius),A=d.map(t=>t.meanAlpha);
o.radius=(R[0]<R[1]&&R[1]<R[2]&&R[2]<R[3]);o.alpha=(A[0]>A[1]&&A[1]>A[2]&&A[2]>A[3]);o.ratio=R[3]/R[0]>1.9&&R[3]/R[0]<2.6;
const px=[1,2,3,4].map(n=>STARCHORUS.node("02:00:00:00:15:0"+n).px);o.px=px.every(v=>v===px[0]);
const hit=[1,2,3,4].map(n=>{const s=STARCHORUS.nodeScreen("02:00:00:00:15:0"+n);return STARCHORUS.hitTest(s.sx,s.sy)==="02:00:00:00:15:0"+n;});o.hit=hit.join();
o.cohTok=JSON.stringify(STARCHORUS._internals.THEMES.foundation.particles.cohesion);o.off=["wargames","whitehall"].map(t=>STARCHORUS._internals.THEMES[t].particles.cohesion.scale.join()).join("|");
// dawn spirals in: the same dust of a NEW AP sits elsewhere when the dawn turn is switched off (digest differs), and is identical when it is 0 = 0
const P=STARCHORUS._internals.THEMES.foundation.particles;
const dig=async(rad,label)=>{P.spiral.dawnRad=rad;STARCHORUS.load({source:"recon-db",generated:G+5,aps:[ap(1,0)],unassociated:[]},label);STARCHORUS.setFixedTime(9600000);await STARCHORUS.wait(120);STARCHORUS.load({source:"recon-db",generated:G+10,aps:[ap(1,0),ap(2,0)],unassociated:[]},label);await STARCHORUS.wait(150);return STARCHORUS.particleDigest();};
const d1=await dig(1.4,"dawn1"),d0=await dig(0,"dawn0"),d1b=await dig(1.4,"dawn1b");
o.dawn=[d1!==d0,d1===d1b].join();P.spiral.dawnRad=1.4;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "$TFD_Q" "out/$P-tfd-dust" --width 1440 --height 900 --wait 2 --fps 0 --eval-timeout 120 --eval "$TFD_EVD" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
TFD_D=$(evalv "out/$P-tfd-dust.json" 1 | tfd_nj); TFD_DE=$(evalv "out/$P-tfd-dust.json" 2)
TFD_DW=$(printf '%s' '{"alpha":true,"aps":"1111","cohTok":"{\"scale\":[1,1.3,1.7,2.3],\"alpha\":[1,0.85,0.65,0.45]}","dawn":"true,true","errors":0,"hit":"true,true,true,true","off":"1,1,1,1|1,1,1,1","px":true,"radius":true,"ratio":true}' | tfd_nj)
if [ "$TFD_D" = "$TFD_DW" ] && [ "$TFD_DE" = 0 ]; then
  row "Foundation: dust cohesion = freshness: the mean dust radius grows T0 < T1 < T2 < T3 (ratio ≈ 2.3) while its alpha falls, the star's size and hit-test are unchanged, off in the other themes, dawn spirals in (the dust of a new AP sits differently with the turn on, deterministically)" PASS
else
  row "Foundation: dust cohesion = freshness (err ${TFD_DE:-?})" FAIL
  echo "    got:  $(printf '%s' "$TFD_D" | cut -c1-800)"; echo "    want: $TFD_DW"
fi

# ---- no spiral ornament (Foundation's grid is rings only; no spiral token in any theme, no turns API), gold only for the alarm, the core's heartbeat
TFD_EVP='(async()=>{
await STARCHORUS.wait(1500);const o={};STARCHORUS.setView("2d");STARCHORUS.setFixedTime(9700000);await STARCHORUS.wait(150);STARCHORUS.frame();
// the grid carries spokes and dots only, in every theme; Foundation draws neither, so the centre is ringed by plain circles
o.grid=["foundation","wargames","whitehall"].map(t=>Object.keys(STARCHORUS._internals.THEMES[t].render.grid).sort().join("+")).join();
o.fdGrid=[STARCHORUS._internals.THEMES.foundation.render.grid.spokes,STARCHORUS._internals.THEMES.foundation.render.grid.dotStepPx].join();
o.api=typeof STARCHORUS.phiTurns;
// gold only for the alarm: Foundation UI/chrome tokens carry no gold hue; the alarm token does
const TH=STARCHORUS._internals.THEMES.foundation,hsl=(c)=>{const m=c.match(/[\d.]+/g).map(Number);let r,g,b;if(c[0]==="#"){const h=c.slice(1);r=parseInt(h.slice(0,2),16)/255;g=parseInt(h.slice(2,4),16)/255;b=parseInt(h.slice(4,6),16)/255;}else{r=m[0]/255;g=m[1]/255;b=m[2]/255;}const mx=Math.max(r,g,b),mn=Math.min(r,g,b),l=(mx+mn)/2,d=mx-mn;let h=0,s=0;if(d>0){s=d/(1-Math.abs(2*l-1));h=mx===r?((g-b)/d)%6:mx===g?(b-r)/d+2:(r-g)/d+4;h=(h*60+360)%360;}return {h,s};};
const gold=(c)=>{const x=hsl(c);return x.h>=30&&x.h<=60&&x.s>0.4;};
const ui={"accent.selection":TH.accent.selection,"accent.focusRing":TH.accent.focusRing,"accent.toggleOn":TH.accent.toggleOn,"accent.toggleBorder":TH.accent.toggleBorder,"chrome.ink":TH.chrome.ink,"line.device":TH.line.device,"line.edge.color":TH.line.edge.color,"ink.primary":TH.ink.primary,"status.ringStrong":TH.status.ringStrong};
o.goldUi=Object.keys(ui).filter(k=>gold(ui[k])).join(",")||"none";o.goldAlarm=gold(TH.status.alarm);o.aura=TH.status.alarmAura;
// the heartbeat: the core scales in place (<= 1 Hz), never outward; reduced motion and the other themes: 1
const beat=async(ms)=>{STARCHORUS.setFixedTime(ms);await STARCHORUS.wait(90);STARCHORUS.frame();return STARCHORUS.stats().coreBeat;};
o.beat=[await beat(0),await beat(312.5),await beat(937.5),await beat(1250)].join();
STARCHORUS.setReducedMotion(true);o.beatRm=await beat(312.5);STARCHORUS.setReducedMotion(false);
STARCHORUS.setTheme("wargames");o.beatWg=await beat(312.5);STARCHORUS.setTheme("whitehall");o.beatWh=await beat(312.5);STARCHORUS.setTheme("foundation");
o.hz=TH.render.coreBeat.hz<=1;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "$TFD_Q" "out/$P-tfd-grid" --width 1440 --height 900 --wait 2 --fps 0 --eval-timeout 120 --eval "$TFD_EVP" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
TFD_P=$(evalv "out/$P-tfd-grid.json" 1 | tfd_nj); TFD_PE=$(evalv "out/$P-tfd-grid.json" 2)
TFD_PW=$(printf '%s' '{"aura":"none","beat":"1,1.07,0.93,1","beatRm":1,"beatWg":1,"beatWh":1,"errors":0,"goldAlarm":true,"api":"undefined","fdGrid":"0,0","goldUi":"none","grid":"dotStepPx+spokes,dotStepPx+spokes,dotStepPx+spokes","hz":true}' | tfd_nj)
if [ "$TFD_P" = "$TFD_PW" ] && [ "$TFD_PE" = 0 ]; then
  row "Foundation: no spiral ornament (grid = spokes + dots in all three themes, Foundation 0/0, so only round rings about the centre; no spiral-turns API), gold only for the alarm (no gold hue in any Foundation UI token, alarmAura none), the core beats in place at 0.8 Hz (1 → 1.07 → 0.93 → 1), no beat under reduced motion or in the other themes" PASS
else
  row "Foundation: no spiral ornament (grid = spokes + dots in all three themes, Foundation 0/0, so only round rings about the centre; no spiral-turns API), gold only for the alarm (no gold hue in any Foundation UI token, alarmAura none), the core beats in place at 0.8 Hz (1 → 1.07 → 0.93 → 1), no beat under reduced motion or in the other themes (err ${TFD_PE:-?})" FAIL
  echo "    got:  $(printf '%s' "$TFD_P" | cut -c1-800)"; echo "    want: $TFD_PW"
fi

# ---- the Compendium line (own wording, uncertainty in words, no device/SSID/MAC) and the Vault card (the shared deviations, busier/quieter, never a threat)
TFD_EVC='(async()=>{
await STARCHORUS.wait(1200);const o={};
const P10=/\b(evil[ -]?twin|rogue|attack(er)?|threat|intru(der|sion)|malicious|spoof(ed|ing)?|karma|bandit|target|deauth flood)\b|crisis|danger|emergency|breach|hostile/i;
// a small sky: counted, not estimated; the drawer shows the line and the vault
STARCHORUS.openDrawer("air");await STARCHORUS.wait(200);
const c=document.getElementById("compendium"),v=document.getElementById("vault");o.dom=[!!c,!!v,c?c.querySelector("h4").textContent:"",v?v.querySelector("h4").textContent:""].join("|");
const line=STARCHORUS.skyLine();o.small=[/counted, not estimated: fewer than 30 stars/.test(line),/still forming/.test(line)].join();
// names never appear: the SSIDs and vendors of the fixture are absent from both blocks
const ssids=STARCHORUS.nodes("ap").map(n=>STARCHORUS.node(n.id).ssid).filter(Boolean),vend=STARCHORUS.nodes("ap").map(n=>STARCHORUS.node(n.id).vendor).filter(Boolean);
const txt=(c?c.innerText:"")+" "+(v?v.innerText:"");o.names=[...ssids,...vend].some(x=>x.length>2&&txt.indexOf(x)>=0);
o.macLike=/[0-9a-f]{2}(:[0-9a-f]{2}){5}/i.test(txt);o.p10=P10.test(txt);
// a big sky: proportions with an interval in words
const ap=(n,ch,b)=>({bssid:"02:00:00:00:16:"+n.toString(16).padStart(2,"0"),ssid:"v"+n,band:b||"2.4",channel:ch,rssi:-60,security:"WPA2",clients:[]});
const mk=(g,list)=>({source:"recon-db",generated:g,aps:list,unassociated:[]});
const big=[];for(let i=0;i<40;i++)big.push(ap(i+1,[1,6,11][i%3],i%4===0?"5":"2.4"));
for(let i=0;i<7;i++)STARCHORUS.load(mk(100+5*i,big.map((a,j)=>j%4===0?Object.assign({},a,{channel:36}):a)),"vault");
const l2=STARCHORUS.skyLine();o.big=[/about \d+ in 10, somewhere between \d+ and \d+/.test(l2),/The usual picture holds/.test(l2)].join();
// deviation: two captures with a burst on 2.4 GHz channel 6 -> the sky differs from the usual picture
const burst=big.slice();for(let i=0;i<14;i++)burst.push(ap(100+i,6));
STARCHORUS.load(mk(200,burst),"vault");STARCHORUS.load(mk(205,burst),"vault");await STARCHORUS.wait(200);
const vo=STARCHORUS.vault();o.vault=JSON.stringify(vo.filter(d=>d.channel===6).map(d=>[d.band,d.channel,d.dir]));
const v2=document.getElementById("vault").innerText;o.vaultText=[/2\.4 GHz ch 6: busier than this sky usually is \(\d+ stars, usually about \d+\)/.test(v2),P10.test(v2)].join();
o.line3=/differ from the usual picture|differs from the usual picture/.test(STARCHORUS.skyLine());
// the other themes: no compendium, no vault
STARCHORUS.setTheme("wargames");STARCHORUS.openDrawer("air");await STARCHORUS.wait(200);o.wg=[!!document.getElementById("compendium"),!!document.getElementById("vault")].join();
STARCHORUS.setTheme("whitehall");await STARCHORUS.wait(200);o.wh=[!!document.getElementById("compendium"),!!document.getElementById("vault")].join();STARCHORUS.setTheme("foundation");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$F/many-clients.json" "$TFD_Q" "out/$P-tfd-comp" --width 1440 --height 900 --wait 2 --fps 0 --eval-timeout 120 --eval "$TFD_EVC" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
TFD_C=$(evalv "out/$P-tfd-comp.json" 1 | tfd_nj); TFD_CE=$(evalv "out/$P-tfd-comp.json" 2)
TFD_CW=$(printf '%s' '{"big":"true,true","dom":"true|true|Compendium of the Local Sky|Vault","errors":0,"line3":true,"macLike":false,"names":false,"p10":false,"small":"true,true","vault":"[[\"2.4\",6,\"up\"]]","vaultText":"true,false","wg":"false,false","wh":"false,false"}' | tfd_nj)
if [ "$TFD_C" = "$TFD_CW" ] && [ "$TFD_CE" = 0 ]; then
  row "Foundation: Compendium of the Local Sky (own wording: counted, not estimated below 30 stars, 'about n in 10, somewhere between a and b' above, 'still forming' / 'the usual picture holds') and Vault (a deviation on 2.4 GHz ch 6: busier than this sky usually is), no SSID, vendor or MAC, no P10 word, absent in the other themes" PASS
else
  row "Foundation: Compendium of the Local Sky (own wording (err ${TFD_CE:-?})" FAIL
  echo "    got:  $(printf '%s' "$TFD_C" | cut -c1-800)"; echo "    want: $TFD_CW"
fi

# ---- static rows
TFD_NET=$(grep -cE 'method:|POST|XMLHttpRequest|WebSocket|EventSource|sendBeacon' starchorus.html); TFD_FE=$(grep -c 'fetch(' starchorus.html)
if [ "$TFD_NET" = 0 ] && [ "$TFD_FE" = 1 ]; then row "Foundation: passivity: no send path in the page (= $TFD_NET), fetch( = $TFD_FE" PASS
else row "Foundation: passivity: no send path in the page (= $TFD_NET), fetch( = $TFD_FE" FAIL; fi
TFD_CLK=$(awk '/^function skyLine\(/,/^function renderAir\(/' starchorus.html | grep -cE 'Math\.random|Date\.now|performance\.now|new Date\(')
rowif "Foundation: the Compendium and the Vault read no wall clock and no random ($TFD_CLK)" [ "$TFD_CLK" = 0 ]
TFD_LC=$(grep -c 'Math\.random' starchorus.html)
rowif "Foundation: the dust stays deterministic (Math.random = $TFD_LC)" [ "$TFD_LC" = 0 ]
