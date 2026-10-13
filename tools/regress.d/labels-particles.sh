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

# ---- labels (1): L off = no AP labels at all, not even forced ones; the core text (__center__) stays
LBL_EVLAB="(async()=>{let ok=true;const det={};for(const th of ['wargames','whitehall','foundation'])for(const v of ['2d','3d']){STARCHORUS.setTheme(th);STARCHORUS.setView(v);await STARCHORUS.wait(1300);STARCHORUS.setToggles({labels:true,vendor:true});const ap=STARCHORUS.nodes('ap').filter(n=>n.visible).sort((a,b)=>b.rssi-a.rssi)[0];STARCHORUS.pin(ap.id,true);STARCHORUS.hoverNode(ap.id);STARCHORUS.frame();const on=STARCHORUS.labels().filter(l=>l.kind==='label'&&l.id!=='__center__').length;STARCHORUS.setToggles({labels:false});STARCHORUS.frame();const L=STARCHORUS.labels();const off=L.filter(l=>l.id!=='__center__'&&['label','vendor','badge','facet','cursor'].includes(l.kind)).length;const c=L.some(l=>l.id==='__center__');det[th+'-'+v]=[on,off,c];if(!(on>0&&off===0&&c))ok=false;STARCHORUS.pin(ap.id,false);STARCHORUS.hoverNode(null);STARCHORUS.setToggles({labels:true,vendor:false});}return JSON.stringify({ok,det})})()"
runq "$F/many-clients.json" "?poll=0&spin=0&intro=0&rm=1" "out/$P-lbl-labels" --wait 3 --fps 0 \
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
  runq "$F/$LBL_FX.json" "?poll=0&spin=0&intro=0&autolod=0&debug=1" "out/$P-lbl-ring-$LBL_FX" --wait 3 --fps 0 \
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
runq "$F/field-probes.json" "?poll=0&spin=0&intro=0&rm=1&autolod=0" "out/$P-lbl-bud" --wait 3 --fps 0 \
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
