# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/labels-particles.sh -- labels (the L switch, click pin, the D8 band ring, the WarGames cursor in
# the text budget) and particles (reset only on a source change). Sourced by tools/regress.sh with
# cwd = repo root, after the core rows. Only LBL_*/PTC_* globals are set.
#
# Timing rules: every run here compares labels, budgets or particle positions, so none of
# them may use ?fixed from boot (nodes never fade in). They use ?poll=0&spin=0&intro=0 and, where a frozen
# clock is needed, freeze inside the eval -- the particle run via setToggles({paused:true}), which stops S.clock while
# fades and easing keep running. The particle run pins &autolod=0 so that CPU load from a parallel Chrome
# cannot flip the LOD particle tier (which refills the pool once) in the middle of a measurement.

# --ready for a run on a served fixture: the boot poll has replaced the built-in sky (its apsTotal is above 0 from the first frame, so a count would be met at once)
LBL_RDY="window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'"

# ---- labels (1): L off = no AP labels at all, not even forced ones; the core text (__center__) stays
LBL_EVLAB="(async()=>{let ok=true;const det={};for(const th of ['wargames','whitehall','foundation'])for(const v of ['2d','3d']){STARCHORUS.setTheme(th);STARCHORUS.setView(v);await STARCHORUS.wait(1300);STARCHORUS.setToggles({labels:true,vendor:true});const ap=STARCHORUS.nodes('ap').filter(n=>n.visible).sort((a,b)=>b.rssi-a.rssi)[0];STARCHORUS.pin(ap.id,true);STARCHORUS.hoverNode(ap.id);STARCHORUS.frame();const on=STARCHORUS.labels().filter(l=>l.kind==='label'&&l.id!=='__center__').length;STARCHORUS.setToggles({labels:false});STARCHORUS.frame();const L=STARCHORUS.labels();const off=L.filter(l=>l.id!=='__center__'&&['label','vendor','badge','facet','cursor'].includes(l.kind)).length;const c=L.some(l=>l.id==='__center__');det[th+'-'+v]=[on,off,c];if(!(on>0&&off===0&&c))ok=false;STARCHORUS.pin(ap.id,false);STARCHORUS.hoverNode(null);STARCHORUS.setToggles({labels:true,vendor:false});}return JSON.stringify({ok,det})})()"
runq "$F/many-clients.json" "?poll=0&spin=0&intro=0&rm=1" "out/$P-lbl-labels" --wait 3 --fps 0 --ready "$LBL_RDY" \
  --eval "$LBL_EVLAB" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
LBL_VLAB=$(evalv "out/$P-lbl-labels.json" 1)
LBL_ELAB=$(evalv "out/$P-lbl-labels.json" 2)
case "$LBL_VLAB" in
  '{"ok":true'*)
    if [ "$LBL_ELAB" = 0 ]; then row "labels: labels:false hides AP labels (3 themes x 2D/3D)" PASS
    else row "labels: labels:false hides AP labels, errors $LBL_ELAB" FAIL; fi ;;
  *) row "labels: labels:false hides AP labels" FAIL; echo "    $(printf '%s' "${LBL_VLAB:-no-value}" | cut -c1-200)" ;;
esac

# ---- labels (2): a real pointer click toggles the pin (single run, cdp --step; 0.3 s pump > 250 ms debounce)
LBL_EVID="(()=>{const a=STARCHORUS.nodes('ap').filter(n=>n.visible&&STARCHORUS.hitTest(n.sx,n.sy)===n.id&&(document.elementFromPoint(n.sx,n.sy)||{}).id==='hud').sort((x,y)=>y.rssi-x.rssi)[0];window.__k08id=a?a.id:null;return window.__k08id||'none'})()"
LBL_EVXY="(()=>{const s=STARCHORUS.nodeScreen(window.__k08id);return s?[Math.round(s.sx),Math.round(s.sy)]:null})()"
LBL_EVP="(()=>{const n=STARCHORUS.node(window.__k08id);return n?n.pinned:'no-node'})()"
LBL_EVLK="JSON.stringify([STARCHORUS.camera().locked===window.__k08id,!document.getElementById('detail').hidden])"
runq "$F/field-probes.json" "?poll=0&spin=0&intro=0" "out/$P-lbl-pin" --wait 4 --fps 0 \
  --step "eval:$LBL_EVID" --step "eval:$LBL_EVP" --step "clickat:$LBL_EVXY" --step "eval:$LBL_EVP" \
  --step "eval:$LBL_EVLK" --step "clickat:$LBL_EVXY" --step "eval:$LBL_EVP" \
  --step "eval:STARCHORUS.errors().length" >/dev/null 2>&1
LBL_PID=$(evalv "out/$P-lbl-pin.json" 1)
LBL_P0=$(evalv "out/$P-lbl-pin.json" 2)
LBL_P1=$(evalv "out/$P-lbl-pin.json" 4)
LBL_LK=$(evalv "out/$P-lbl-pin.json" 5)
LBL_P2=$(evalv "out/$P-lbl-pin.json" 7)
LBL_EPIN=$(evalv "out/$P-lbl-pin.json" 8)
if [ "$LBL_P0/$LBL_P1/$LBL_P2" = "false/true/false" ] && [ "$LBL_LK" = "[true,true]" ] && [ "$LBL_EPIN" = 0 ]; then
  row "labels: click pins AP, 2nd click unpins ($LBL_PID)" PASS
else
  row "labels: click pin $LBL_P0/$LBL_P1/$LBL_P2, lock+detail $LBL_LK" FAIL
fi

# ---- labels (2): double click toggles once, clients are additive, a bubble is selected but never pinned,
# an empty click deselects and keeps the pins (synthetic PointerEvents through the real handlers).
# The bubble check toggles the pin with STARCHORUS.pin(id) afterwards: it returns true only if the click left
# the bubble unpinned. The pin is removed again right away.
LBL_EVPINJS="(async()=>{const hud=document.getElementById('hud');let pid=20;const click=(x,y)=>{const o={clientX:x,clientY:y,pointerId:++pid,pointerType:'mouse',button:0,buttons:1,bubbles:true,isPrimary:true};hud.dispatchEvent(new PointerEvent('pointerdown',o));hud.dispatchEvent(new PointerEvent('pointerup',Object.assign({},o,{buttons:0})));};await STARCHORUS.wait(300);const ap=STARCHORUS.nodes('ap').filter(n=>n.visible&&STARCHORUS.hitTest(n.sx,n.sy)===n.id).sort((a,b)=>b.rssi-a.rssi)[0];click(ap.sx,ap.sy);click(ap.sx,ap.sy);const dbl=STARCHORUS.node(ap.id).pinned===true;await STARCHORUS.wait(300);const b=STARCHORUS.nodes('bubble').find(b=>STARCHORUS.hitTest(b.sx,b.sy)===b.id);let bub=true;if(b){click(b.sx,b.sy);bub=STARCHORUS.camera().locked===b.id&&STARCHORUS.pin(b.id)===true;STARCHORUS.pin(b.id,false);}await STARCHORUS.wait(300);const cl=STARCHORUS.nodes('client').filter(n=>n.visible&&!n.bubble&&STARCHORUS.hitTest(n.sx,n.sy)===n.id).slice(0,2);for(const c of cl){const s=STARCHORUS.nodeScreen(c.id);click(s.sx,s.sy);await STARCHORUS.wait(300);}const add=cl.length===2&&cl.every(c=>STARCHORUS.node(c.id).pinned===true)&&STARCHORUS.node(ap.id).pinned===true;click(4,4);const keep=STARCHORUS.camera().locked===null&&STARCHORUS.node(ap.id).pinned===true;return JSON.stringify({ok:dbl&&bub&&add&&keep&&!!b,dbl,bub,add,keep,bubble:!!b})})()"
runq "$F/field-probes.json" "?poll=0&spin=0&intro=0" "out/$P-lbl-pinjs" --wait 4 --fps 0 \
  --eval "$LBL_EVPINJS" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
LBL_VJS=$(evalv "out/$P-lbl-pinjs.json" 1)
LBL_EJS=$(evalv "out/$P-lbl-pinjs.json" 2)
case "$LBL_VJS" in
  '{"ok":true'*)
    if [ "$LBL_EJS" = 0 ]; then row "labels: dbl-click 1 toggle, clients additive, bubble no pin" PASS
    else row "labels: dbl-click/additive/bubble pin, errors $LBL_EJS" FAIL; fi ;;
  *) row "labels: dbl-click/additive/bubble pin" FAIL; echo "    $(printf '%s' "${LBL_VJS:-no-value}" | cut -c1-200)" ;;
esac

# ---- labels (3) D8: probe-orbit clients carry no band ring in any theme; associated clients keep it.
# Proof on the sprite cache: applyTheme clears it, so every theme is measured on its own bake set.
LBL_EVRING="(async()=>{const out={};for(const th of ['wargames','whitehall','foundation']){STARCHORUS.setTheme(th);await STARCHORUS.wait(700);STARCHORUS.frame();const keys=[...STARCHORUS._internals.spriteCache.keys()].map(k=>k.split('|'));const cl=STARCHORUS.nodes('client').filter(n=>n.visible&&!n.bubble).map(n=>STARCHORUS.node(n.id));out[th]=[cl.filter(x=>x.affinity).length,cl.filter(x=>!x.free&&!x.affinity).length,keys.filter(p=>p[1].indexOf('client')===0&&['b24','b5','b6','unknown'].includes(p[2])).length]}return JSON.stringify(out)})()"
for LBL_FX in field-probes few-clients; do
  runq "$F/$LBL_FX.json" "?poll=0&spin=0&intro=0&autolod=0&debug=1" "out/$P-lbl-ring-$LBL_FX" --wait 3 --fps 0 --ready "$LBL_RDY" \
    --eval "$LBL_EVRING" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
done
LBL_RA=$(evalv "out/$P-lbl-ring-field-probes.json" 1)
LBL_RB=$(evalv "out/$P-lbl-ring-few-clients.json" 1)
if LBL_R=$(python3 -c 'import json,sys
a=json.loads(sys.argv[1]); b=json.loads(sys.argv[2])
ok=(len(a)==3==len(b) and all(v[0]>0 and v[1]==0 and v[2]==0 for v in a.values())
    and all(v[1]>0 and v[2]>0 for v in b.values()))
print("probe-orbit %s, assoc %s" % (sorted(a.values())[0], sorted(b.values())[0]))
sys.exit(0 if ok else 1)' "$LBL_RA" "$LBL_RB" 2>/dev/null); then
  row "labels: probe orbits without band ring (D8) [$LBL_R]" PASS
else
  row "labels: D8 band ring: $(printf '%s' "$LBL_RA" | cut -c1-80) / $(printf '%s' "$LBL_RB" | cut -c1-60)" FAIL
fi

# ---- labels (4): worst-case fillText with select+hover and vendor off/on, 3 themes x 2D/3D; and the
# invariant "every HUD text is listed in labels() exactly once, and exactly the COUNTED ones cost a slot".
# The fixed-vocabulary posts (centre label, 3D ring dBm, WarGames cursor) are baked sprites and
# carry sprite:true, so the invariant is two-sided: fillText === the entries without the flag, and the
# flagged ones must still be there (otherwise "moved to a sprite" would be indistinguishable from "lost").
# The all-theme/all-fixture budget rows live in tools/regress.sh; this one adds the cursor invariant.
LBL_EVBUD="(async()=>{const K=['label','ring','vendor','badge','group','cursor'];let worst={'2d':0,'3d':0},inv=true,cur=0,baked=0;for(const th of ['wargames','whitehall','foundation'])for(const v of ['2d','3d']){STARCHORUS.setTheme(th);STARCHORUS.setView(v);await STARCHORUS.wait(1300);for(const vend of [false,true]){STARCHORUS.setToggles({vendor:vend});const ap=STARCHORUS.nodes('ap').filter(n=>n.visible&&!STARCHORUS.node(n.id).hidden).sort((a,b)=>b.rssi-a.rssi)[0];STARCHORUS.select(ap.id);await STARCHORUS.wait(v==='3d'?1300:50);STARCHORUS.hoverNode(ap.id);STARCHORUS.frame();const ft=STARCHORUS.perf().drawCalls.fillText,L=STARCHORUS.labels();worst[v]=Math.max(worst[v],ft);const H=L.filter(l=>K.includes(l.kind));if(ft!==H.filter(l=>!l.sprite).length||H.filter(l=>l.sprite).length===0)inv=false;baked+=H.filter(l=>l.sprite).length;cur+=L.filter(l=>l.kind==='cursor').length;STARCHORUS.deselect();STARCHORUS.hoverNode(null);}}STARCHORUS.setToggles({vendor:false});return JSON.stringify({ok:worst['2d']<=30&&worst['3d']<=24&&inv&&cur>0&&baked>0,worst,inv,cursorFrames:cur,baked})})()"
runq "$F/field-probes.json" "?poll=0&spin=0&intro=0&rm=1&autolod=0" "out/$P-lbl-bud" --wait 3 --fps 0 --ready "$LBL_RDY" \
  --eval "$LBL_EVBUD" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
LBL_VBUD=$(evalv "out/$P-lbl-bud.json" 1)
LBL_EBUD=$(evalv "out/$P-lbl-bud.json" 2)
LBL_WORST=$(printf '%s' "$LBL_VBUD" | sed -n 's/.*"worst":{\([^}]*\)}.*/\1/p')
case "$LBL_VBUD" in
  '{"ok":true'*)
    if [ "$LBL_EBUD" = 0 ]; then row "labels: fillText+cursor field-probes ($LBL_WORST); every HUD text is in labels() once and only the un-baked ones cost a slot" PASS
    else row "labels: fillText+cursor field-probes, errors $LBL_EBUD" FAIL; fi ;;
  *) row "labels: fillText+cursor field-probes" FAIL; echo "    $(printf '%s' "${LBL_VBUD:-no-value}" | cut -c1-200)" ;;
esac

# ---- labels (5), 26 October 2026: the vendor line under an AP's label (§8.7). Before, the line was offered to the grid inside the cells its own label had taken and
# never appeared; now label and vendor line are one rectangle of two rows (at the same three places, the first one raised by the extra row), the label alone where that
# finds no room. devices.json (vendors on most of its APs), 3 themes x 2D/3D, the switch off and on, then the device labels (facets, x n) in 2D. Per snapshot: the
# fillText count, the AP labels, the vendor lines, whether every vendor line is an AP's and sits 12 px under its label, the overlapping pairs among the boxes
# (labels, vendor lines, badges, groups, clouds), a digest of the rounded label positions (2D; 3D keeps a little time-dependent jitter), and facets+counters/vendor lines on a carrier.
# The figures with the switch off are those of the page before the change (measured on a copy of 16d7e07), so "nothing moves with the switch off" is a comparison, not a claim.
LBL_EVVEN='(async()=>{const o=[],ids=new Set(STARCHORUS.nodes("ap").map(n=>n.id));
const snap=async(tag,on,dev)=>{STARCHORUS.setToggles({vendor:on});await STARCHORUS.wait(120);STARCHORUS.frame();
const L=STARCHORUS.labels(),ft=STARCHORUS.perf().drawCalls.fillText,lab=L.filter(l=>l.kind==="label"&&!l.sprite),ven=L.filter(l=>l.kind==="vendor"),yok=ven.every(x=>lab.some(l=>l.id===x.id&&Math.abs(x.y-l.y-12)<0.01)),apok=ven.every(x=>ids.has(x.id));
const bx=L.filter(l=>l.w&&["label","vendor","badge","group","cloud"].includes(l.kind));let ovl=0;for(let i=0;i<bx.length;i++)for(let j=i+1;j<bx.length;j++){const a=bx[i],b=bx[j];if(a.x<b.x+b.w&&b.x<a.x+a.w&&a.y<b.y+12&&b.y<a.y+12)ovl++}
const dig=lab.reduce((a,l)=>(a*131+Math.round(l.x)*7+Math.round(l.y)*13+l.id.charCodeAt(l.id.length-1))%1000003,7);
const fc=L.filter(l=>l.kind==="facet"||l.kind==="counter").length,cv=ven.filter(x=>L.some(l=>l.kind==="facet"&&l.id===x.id)).length;
o.push([tag,on?"on":"off",ft,lab.length,ven.length,yok,apok,ovl,tag[0]==="2"?dig:"-",dev?fc+"/"+cv:"-"].join(" "));};
for(const v of ["2d","3d"])for(const th of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(th);STARCHORUS.setView(v);await STARCHORUS.wait(1400);for(const on of [false,true])await snap(v+"/"+th,on,false);}
STARCHORUS.setTheme("foundation");STARCHORUS.setView("2d");await STARCHORUS.wait(1400);STARCHORUS.setToggles({deviceLinks:true});await STARCHORUS.wait(1400);for(const on of [false,true])await snap("2d/devices",on,true);
STARCHORUS.setToggles({vendor:false,deviceLinks:false});return o.join("\n")})()'
LBL_VEN_OFF='2d/foundation off 18 17 0 true true 0 996561 -
2d/wargames off 17 17 0 true true 0 910672 -
2d/whitehall off 18 17 0 true true 0 443419 -
3d/foundation off 13 11 0 true true 0 - -
3d/wargames off 13 11 0 true true 0 - -
3d/whitehall off 13 11 0 true true 0 - -
2d/devices off 12 11 0 true true 0 555469 9/0'
# the page of the sensor: the rectangle is never offered, which is what the old code amounted to (its vendor box could not be placed)
python3 - "$H" "out/$P-lbl-ven-old.html" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
a = 'vb = vt ? place(at(rw, 26), rw, 24) : null;'
if s.count(a) != 1: s += "\n<!-- the vendor rectangle was not found exactly once -->\n"
open(sys.argv[2], "w", encoding="utf-8").write(s.replace(a, 'vb = null;'))
PY
runq "$F/devices.json" "?poll=0&spin=0&intro=0&rm=1&autolod=0" "out/$P-lbl-ven" --wait 3 --fps 0 --ready "$LBL_RDY" --width 1440 --height 900 --eval-timeout 120 --eval "$LBL_EVVEN" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
LBL_HK=$H; H="out/$P-lbl-ven-old.html"
runq "$F/devices.json" "?poll=0&spin=0&intro=0&rm=1&autolod=0" "out/$P-lbl-ven-o" --wait 3 --fps 0 --ready "$LBL_RDY" --width 1440 --height 900 --eval-timeout 120 --eval "$LBL_EVVEN" >/dev/null 2>&1
H=$LBL_HK
LBL_VV=$(evalv "out/$P-lbl-ven.json" 1); LBL_VE=$(evalv "out/$P-lbl-ven.json" 2); LBL_VO=$(evalv "out/$P-lbl-ven-o.json" 1)
LBL_VOFF=$(printf '%s\n' "$LBL_VV" | grep ' off ')
LBL_VON=$(printf '%s\n' "$LBL_VV" | awk '$2=="on"{n++; cap=($1 ~ /^3d/)?24:30; if ($3<=cap && $5>=1 && $6=="true" && $7=="true" && $8==0) ok++} END{print ok+0 "/" n+0}')
LBL_VCAR=$(printf '%s\n' "$LBL_VV" | awk '$1=="2d/devices"{ if ($2=="off") split($10,a,"/"); else split($10,b,"/") } END{print (a[1]==b[1] && a[1]>0 && b[2]>0) ? "kept/" b[2] : "BROKEN/" a[1] ":" b[1] ":" b[2]}')
rowif "labels: the vendor line under an AP's label (Vendor on, devices.json, 3 themes x 2D/3D): every snapshot has vendor lines, each one an AP's and 12 px under its label, none overlaps another box, the fillText count stays in the budget [$LBL_VON]" [ "$LBL_VON/$LBL_VE" = "7/7/0" ]
rowif "labels: with the vendor switch off the page is as it was: fillText counts, label counts and (2D) the digest of the label positions equal the figures measured on the page before the change [$(printf '%s' "$LBL_VOFF" | tr '\n' ';')]" [ "$LBL_VOFF" = "$LBL_VEN_OFF" ]
rowif "labels: a device label keeps its facets and x n with the vendor line (the same facets and counters on and off, and a carrier with a vendor line under it: $LBL_VCAR)" [ "${LBL_VCAR%/*}" = kept ]
LBL_VOLD=$(printf '%s\n' "$LBL_VO" | awk '$2=="on"{n++; v+=$5} END{print v+0 "/" n+0}')
rowif "labels: the sensor bites: a copy that never offers the rectangle (the old behaviour) has no vendor line in any of the seven snapshots with the switch on [$LBL_VOLD], and the same figures with it off" [ "$LBL_VOLD/$(printf '%s\n' "$LBL_VO" | grep ' off ')" = "0/7/$LBL_VEN_OFF" ]

# ---- labels (6), 26 October 2026: what the vendor lines must leave to others (§6.6: forced nodes, group labels and badges rank above an AP's vendor line). devices.json,
# 1440 x 900, Vendor on. (a) each client pinned in turn must show its own vendor line, 2D and 3D: the page before the change gave 0000101111011 (2D, 8 of 13) and
# 0000100001000 (3D) because the AP vendor lines had spent the 2D budget and the AP labels held the cells; a client's line is now placed after the forced AP labels and before the others.
# (b) in 2D, three themes, devices.json and many-clients.json: the group labels and the badges with the switch on equal those with it off (the vendor lines had taken
# the group label's slot, 1 -> 0, in two themes of devices.json and in all three of many-clients.json). The sensor copy offers no rectangle's reserve and no early client line.
LBL_EVPIN='(async()=>{const o=[];for(const v of ["2d","3d"]){STARCHORUS.setTheme("foundation");STARCHORUS.setView(v);STARCHORUS.setToggles({vendor:true});await STARCHORUS.wait(1400);const ids=STARCHORUS.nodes("client").map(n=>n.id);let s="";for(const id of ids){STARCHORUS.pin(id,true);await STARCHORUS.wait(120);STARCHORUS.frame();s+=STARCHORUS.labels().some(l=>l.kind==="vendor"&&l.id===id)?"1":"0";STARCHORUS.pin(id,false)}await STARCHORUS.wait(100);STARCHORUS.frame();o.push(v+" "+s+" "+STARCHORUS.perf().drawCalls.fillText)}STARCHORUS.setToggles({vendor:false});return o.join(";")})()'
LBL_EVGB='(async()=>{const o=[],c=()=>{const L=STARCHORUS.labels();return [L.filter(l=>l.kind==="group").length,L.filter(l=>l.kind==="badge").length]};STARCHORUS.setView("2d");for(const th of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(th);const r=[];for(const on of [false,true]){STARCHORUS.setToggles({vendor:on});await STARCHORUS.wait(1300);STARCHORUS.frame();r.push(c())}o.push(r[0][0]+"/"+r[1][0]+"g"+r[0][1]+"/"+r[1][1]+"b")}STARCHORUS.setToggles({vendor:false});return o.join(" ")})()'
python3 - "$H" "out/$P-lbl-ven-res.html" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
a = ['budget > rest + 1 + res + wb(ap)', 'if (!cvDone && !isForced(ap.id)) cvLines();']
if any(s.count(x) != 1 for x in a): s += "\n<!-- the reserve or the client vendor line was not found exactly once -->\n"
open(sys.argv[2], "w", encoding="utf-8").write(s.replace(a[0], 'budget > rest + 1').replace(a[1], ''))
PY
runq "$F/devices.json" "?poll=0&spin=0&intro=0&rm=1&autolod=0" "out/$P-lbl-res" --wait 3 --fps 0 --ready "$LBL_RDY" --width 1440 --height 900 --eval-timeout 180 --eval "$LBL_EVPIN" --eval "$LBL_EVGB" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
runq "$F/many-clients.json" "?poll=0&spin=0&intro=0&rm=1&autolod=0" "out/$P-lbl-res-m" --wait 3 --fps 0 --ready "$LBL_RDY" --width 1440 --height 900 --eval-timeout 120 --eval "$LBL_EVGB" >/dev/null 2>&1
LBL_HK=$H; H="out/$P-lbl-ven-res.html"
runq "$F/devices.json" "?poll=0&spin=0&intro=0&rm=1&autolod=0" "out/$P-lbl-res-o" --wait 3 --fps 0 --ready "$LBL_RDY" --width 1440 --height 900 --eval-timeout 180 --eval "$LBL_EVPIN" --eval "$LBL_EVGB" >/dev/null 2>&1
runq "$F/many-clients.json" "?poll=0&spin=0&intro=0&rm=1&autolod=0" "out/$P-lbl-res-mo" --wait 3 --fps 0 --ready "$LBL_RDY" --width 1440 --height 900 --eval-timeout 120 --eval "$LBL_EVGB" >/dev/null 2>&1
H=$LBL_HK
LBL_RP=$(evalv "out/$P-lbl-res.json" 1); LBL_RD=$(evalv "out/$P-lbl-res.json" 2); LBL_RM=$(evalv "out/$P-lbl-res-m.json" 1); LBL_RE=$(evalv "out/$P-lbl-res.json" 3)
LBL_ROP=$(evalv "out/$P-lbl-res-o.json" 1); LBL_ROD=$(evalv "out/$P-lbl-res-o.json" 2); LBL_ROM=$(evalv "out/$P-lbl-res-mo.json" 1)
LBL_RPK=$(printf '%s' "$LBL_RP" | tr ';' '\n' | awk '{n=gsub(/1/,"1",$2); if (n==13 && $2 !~ /0/ && $3<=(($1=="2d")?30:24)) ok++} END{print ok+0 "/" NR}')
LBL_RGB=$(printf '%s %s\n' "$LBL_RD" "$LBL_RM" | tr ' ' '\n' | awk '{split($0,a,"g"); sub(/b$/,"",a[2]); split(a[1],g,"/"); split(a[2],b,"/"); if (g[1]==g[2] && b[1]==b[2]) ok++} END{print ok+0 "/" NR}')
rowif "labels: Vendor on keeps what outranks it: each of the 13 clients pinned in turn shows its vendor line, 2D and 3D, inside the budget [$LBL_RPK; before the change 2D 0000101111011, 3D 0000100001000]" [ "$LBL_RPK/$LBL_RE" = "2/2/0" ]
rowif "labels: Vendor on keeps what outranks it: the group labels and the badges equal those with it off (2D, 1440 x 900, 3 themes, devices.json and many-clients.json) [$LBL_RGB: $LBL_RD | $LBL_RM]" [ "$LBL_RGB" = "6/6" ]
LBL_ROPK=$(printf '%s' "$LBL_ROP" | tr ';' '\n' | awk '{n=gsub(/1/,"1",$2); if (n==13) ok++} END{print ok+0}')
LBL_ROGB=$(printf '%s %s\n' "$LBL_ROD" "$LBL_ROM" | tr ' ' '\n' | awk '{split($0,a,"g"); sub(/b$/,"",a[2]); split(a[1],g,"/"); split(a[2],b,"/"); if (g[1]==g[2] && b[1]==b[2]) ok++} END{print ok+0 "/" NR}')
LBL_RBITE=no; [ "$LBL_ROGB" != "6/6" ] && LBL_RBITE=yes
rowif "labels: the sensor bites: a copy without the reserve and without the early client line loses client vendor lines ($LBL_ROPK of 2 snapshots complete) and group labels or badges ($LBL_ROGB equal)" [ "$LBL_ROPK/$LBL_RBITE" = "0/yes" ]

# ---- labels (7), 26 October 2026: a forced AP's name outranks a pinned client's vendor line (§6.6: locked -> hover -> pinned). devices.json, 1440 x 900, 2D, Vendor on:
# AP ...bb:12 locked and client ...20:31 pinned, the AP keeps its label (the page before the change drew it); then each client pinned in turn with the AP nearest to it on
# screen locked, the locked labels missing (0/13 on the page before the change) and the client vendor lines drawn. The sensor copy places the client lines ahead of every AP label.
LBL_EVLK='(async()=>{const o=[];STARCHORUS.setTheme("foundation");STARCHORUS.setView("2d");STARCHORUS.setToggles({vendor:true});await STARCHORUS.wait(1400);
const one=async(a,c)=>{STARCHORUS.select(a);STARCHORUS.pin(c,true);await STARCHORUS.wait(150);STARCHORUS.frame();const L=STARCHORUS.labels(),r=[L.some(l=>l.kind==="label"&&l.id===a),L.some(l=>l.kind==="vendor"&&l.id===c)];STARCHORUS.pin(c,false);STARCHORUS.deselect();return r};
o.push((await one("44:4e:6d:aa:bb:12","3c:22:fb:10:20:31"))[0]);let miss=0,cv=0,n=0;
for(const c of STARCHORUS.nodes("client")){const s=STARCHORUS.nodeScreen(c.id);if(!s)continue;const p=STARCHORUS.nodes("ap").filter(a=>a.visible).sort((a,b)=>Math.hypot(a.sx-s.sx,a.sy-s.sy)-Math.hypot(b.sx-s.sx,b.sy-s.sy))[0].id;n++;const q=await one(p,c.id);miss+=!q[0];cv+=q[1]}
STARCHORUS.setToggles({vendor:false});return o[0]+" "+miss+"/"+n+" "+cv})()'
python3 - "$H" "out/$P-lbl-lk-old.html" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
a = 'if (!cvDone && !isForced(ap.id)) cvLines();'
if s.count(a) != 1: s += "\n<!-- the client vendor line's place was not found exactly once -->\n"
open(sys.argv[2], "w", encoding="utf-8").write(s.replace(a, 'if (!cvDone) cvLines();'))
PY
runq "$F/devices.json" "?poll=0&spin=0&intro=0&rm=1&autolod=0" "out/$P-lbl-lk" --wait 3 --fps 0 --ready "$LBL_RDY" --width 1440 --height 900 --eval-timeout 120 --eval "$LBL_EVLK" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
LBL_HK=$H; H="out/$P-lbl-lk-old.html"
runq "$F/devices.json" "?poll=0&spin=0&intro=0&rm=1&autolod=0" "out/$P-lbl-lk-o" --wait 3 --fps 0 --ready "$LBL_RDY" --width 1440 --height 900 --eval-timeout 120 --eval "$LBL_EVLK" >/dev/null 2>&1
H=$LBL_HK
LBL_LKV=$(evalv "out/$P-lbl-lk.json" 1); LBL_LKE=$(evalv "out/$P-lbl-lk.json" 2); LBL_LKO=$(evalv "out/$P-lbl-lk-o.json" 1)
rowif "labels: Vendor on, AP ...bb:12 locked and client ...20:31 pinned: the AP keeps its label; each client pinned with its nearest AP locked loses no locked label (base 0/13) [label, missing, client lines: $LBL_LKV]" [ "${LBL_LKV%% *}/$(printf '%s' "$LBL_LKV" | cut -d' ' -f2)/$LBL_LKE" = "true/0/13/0" ]
rowif "labels: the sensor bites: a copy that places the client vendor lines ahead of every AP label drops the locked AP's label [$LBL_LKO]" [ "${LBL_LKO%% *}" = false ]

# ---- particles: one run carries all five particle rows. The document comes from fetch('starchorus.json') inside
# the eval (test code, not page code -- the page still has exactly one fetch), with the same label and
# mode as the boot poll, so setSource() reports "unchanged".
PTC_STATE="const st=()=>STARCHORUS.nodes('ap').map(a=>STARCHORUS.node(a.id).pState).filter(s=>s!=null);for(let i=0;i<40&&st().some(s=>s!=='idle');i++)await STARCHORUS.wait(100);"
PTC_EVA="(async()=>{const doc=await fetch('starchorus.json',{cache:'no-store'}).then(r=>r.json());$PTC_STATE STARCHORUS.setToggles({paused:true});await STARCHORUS.wait(100);const d0=STARCHORUS.particleDigest(),n0=STARCHORUS.stats().particles;const r=STARCHORUS.load(doc,'starchorus.json',{mode:'live'});const d1=STARCHORUS.particleDigest();await STARCHORUS.wait(1200);const d2=STARCHORUS.particleDigest(),s=st();STARCHORUS.setToggles({paused:false});return JSON.stringify({ok:r.ok===true&&n0>0&&d0===d1&&d1===d2&&s.length>0&&s.every(x=>x==='idle'),n0,same:d0===d1&&d1===d2,count:s.length})})()"
PTC_EVE="(async()=>{$PTC_STATE STARCHORUS.setToggles({paused:true});await STARCHORUS.wait(100);const d0=STARCHORUS.particleDigest();document.dispatchEvent(new Event('visibilitychange'));await STARCHORUS.wait(300);const d1=STARCHORUS.particleDigest(),s=st();STARCHORUS.setToggles({paused:false});return JSON.stringify({ok:d0===d1&&s.length>0&&s.every(x=>x==='idle'),count:s.length})})()"
PTC_EVB="(async()=>{const doc=await fetch('starchorus.json',{cache:'no-store'}).then(r=>r.json());const so=()=>{const o={};STARCHORUS.nodes('ap').forEach(a=>{const s=STARCHORUS.node(a.id).pState;if(s!=null)o[a.id]=s});return o};for(let i=0;i<40&&Object.values(so()).some(s=>s!=='idle');i++)await STARCHORUS.wait(100);const d2=JSON.parse(JSON.stringify(doc));d2.generated=(doc.generated||1789300000)+5;const nb='02:4b:30:00:00:09';d2.aps.push({bssid:nb,ssid:'K09-NEW',channel:6,freq:2437,rssi:-48,security:'WPA2-PSK',clients:[]});STARCHORUS.load(d2,'starchorus.json',{mode:'live'});await STARCHORUS.wait(200);const s=so(),g=Object.keys(s).filter(k=>s[k]==='gather');return JSON.stringify({ok:g.length===1&&g[0]===nb&&Object.keys(s).filter(k=>k!==nb).every(k=>s[k]==='idle'),gather:g.slice(0,3),n:Object.keys(s).length})})()"
PTC_EVD="(async()=>{const PP=STARCHORUS._internals.particles;const doc=await fetch('starchorus.json',{cache:'no-store'}).then(r=>r.json());$PTC_STATE const b=JSON.parse(JSON.stringify(doc));b.generated=(doc.generated||1789300000)+10;b.aps=b.aps.slice(0,b.aps.length-10);STARCHORUS.load(b,'starchorus.json',{mode:'live'});await STARCHORUS.wait(2200);const c=JSON.parse(JSON.stringify(doc));c.generated=(doc.generated||1789300000)+15;STARCHORUS.load(c,'starchorus.json',{mode:'live'});await STARCHORUS.wait(1500);return JSON.stringify({ok:PP.count>0&&PP.pooled===PP.count,count:PP.count,pooled:PP.pooled})})()"
PTC_EVC="(async()=>{const doc=await fetch('starchorus.json',{cache:'no-store'}).then(r=>r.json());$PTC_STATE STARCHORUS.load(doc,'other-capture.json');await STARCHORUS.wait(150);const s=st();return JSON.stringify({ok:s.length>0&&s.every(x=>x==='gather'),n:s.length})})()"
runq "$F/field-probes.json" "?poll=0&spin=0&intro=0&autolod=0&debug=1" "out/$P-ptc" --wait 3 --fps 0 \
  --eval "$PTC_EVA" --eval "$PTC_EVE" --eval "$PTC_EVB" --eval "$PTC_EVD" --eval "$PTC_EVC" \
  --eval "STARCHORUS.errors().length" >/dev/null 2>&1
PTC_ERR=$(evalv "out/$P-ptc.json" 6)
PTC_I=1
for PTC_NAME in "same-doc reload keeps the dust (digest, idle)" "visibilitychange keeps resting dust" "+1 BSSID: only it gathers" "vanished APs return their pool block" "label change re-gathers (guard)"; do
  PTC_V=$(evalv "out/$P-ptc.json" "$PTC_I")
  case "$PTC_V" in
    '{"ok":true'*)
      if [ "$PTC_ERR" = 0 ]; then row "particles: $PTC_NAME" PASS
      else row "particles: $PTC_NAME (errors $PTC_ERR)" FAIL; fi ;;
    *) row "particles: $PTC_NAME" FAIL; echo "    $(printf '%s' "${PTC_V:-no-value}" | cut -c1-200)" ;;
  esac
  PTC_I=$((PTC_I + 1))
done

# ---- static: the label edits sit where the design puts them, and section 30 does not reset particles.
# S6/S7 are the chanbar guard (the 6 s highlight only removes the pins it set itself): S6 pins the `temp`
# declaration, S7 the removal loop that consumes it -- either one alone can be reverted while the other
# stays behind. Its runtime proof costs two 6.3 s waits, so it is kept as a shape check here; the behaviour
# is measured by hand when that code changes.
LBL_S1=$(grep -c 'const cand = S.ui.labels ? labelCandidateList(devCarrier) : \[\];' "$H")
LBL_S2=$(grep -c 'S.labelsList.push({ id: "__cursor__", kind: "cursor"' "$H")
LBL_S3=$(grep -c 'pinDebounceMs: 250' "$H")
LBL_S4=$(grep -c 'clickPin(id, e.timeStamp); select(id);' "$H")
LBL_S5=$(awk '/==== 34 RENDER LAYERS/,/==== 35 RENDER HUD/' "$H" | grep -c 'const colorKey = (c.free || c.affinity) ? "client"')
LBL_S6=$(awk '/==== 37 UI/,/==== 38 DATA SOURCE/' "$H" | grep -c 'temp = ids.filter(id => !S.pinned.has(id))')
# S7 anchors the REMOVAL loop as well: without it the declaration can survive while the timeout goes back
# to deleting every id of the entry, which is exactly what the guard exists to prevent.
LBL_S7=$(awk '/==== 37 UI/,/==== 38 DATA SOURCE/' "$H" | grep -c 'for (const id of temp) if (S.locked !== id) S.pinned.delete(id)')
rowif "labels: gate/cursor/debounce/clickPin/D8/chanbar ($LBL_S1$LBL_S2$LBL_S3$LBL_S4$LBL_S5$LBL_S6$LBL_S7)" [ "$LBL_S1$LBL_S2$LBL_S3$LBL_S4$LBL_S5$LBL_S6$LBL_S7" = 1111111 ]
# "0 in §30" is the one count here that an empty range satisfies, so it goes through the anchored slice:
# a broken §30/§31 marker gives NOSLICE, not 0. Floor: about 80 % of the measured size (sec_slice 30 31 | wc -l = 172).
PTC_S1=$(sec_grepc 30 31 135 'particlesReset(') || PTC_S1=NOSLICE
PTC_S2=$(awk '/==== 38 DATA SOURCE/,/==== 39 INTRO/' "$H" | grep -c 'if (changed) particlesReset();')
rowif "particles: no particlesReset in §30 ($PTC_S1), §38 conditional ($PTC_S2)" [ "$PTC_S1/$PTC_S2" = 0/1 ]
