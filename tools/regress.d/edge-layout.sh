# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/edge-layout.sh -- D15: theme-free chrome (chrome.bezel, chrome.banner.show,
# data-banner, edge-panel rule) and the edge-panel layout resolver layoutEdges() (§37).
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only EDG_* globals are set.
#
# The binding invariant is the pairwise intersection area 0 of every visible edge panel and every .panel,
# with and without an open #detail (the detail of EVERY AP), in all three themes, at the three reference viewports;
# a panel that leaves the viewport counts as an overlap too. The mode strings (stats/chan/legend-scroll/
# motto) are the measured D15 decisions: they are pinned at 1440x900 and 1000x640, and only reported at
# 1280x800, where the row count depends on the theme's font metrics.
# The runs may keep ?fixed from boot: nothing here reads a node position or the canvas, only DOM boxes,
# computed styles and token values (under a frozen clock the stars never fade in, but the chrome is final).
# The "[data-theme=" baseline lives in tools/static.sh (BASE_DATA_THEME = 0).

EDG_OVL="(()=>{const I=['masthead','stats','source','legend','controls','chanbar','classbar-top','classbar-bot','dtg'];const vis=e=>{if(!e||!e.getClientRects().length)return false;const c=getComputedStyle(e);if(c.display==='none'||c.visibility==='hidden')return false;const r=e.getBoundingClientRect();return r.width>0&&r.height>0};const m=()=>{const s=new Set(I.map(i=>document.getElementById(i)).filter(Boolean));document.querySelectorAll('.panel').forEach(e=>s.add(e));const B=[...s].filter(vis).map(e=>[e.id||e.className,e.getBoundingClientRect()]);let a=0;const bad=[];for(let i=0;i<B.length;i++){const p=B[i][1];if(p.left<-0.5||p.top<-0.5||p.right>innerWidth+0.5||p.bottom>innerHeight+0.5){a+=1;bad.push('off:'+B[i][0]);}for(let j=i+1;j<B.length;j++){const q=B[j][1];const w=Math.min(p.right,q.right)-Math.max(p.left,q.left),h=Math.min(p.bottom,q.bottom)-Math.max(p.top,q.top);if(w>0&&h>0){a+=w*h;bad.push(B[i][0]+'/'+B[j][0]+' '+Math.round(w)+'x'+Math.round(h));}}}return [a,bad]};let tot=0;const why=[];for(const t of ['foundation','wargames','whitehall']){STARCHORUS.setTheme(t);STARCHORUS.deselect();let r=m();tot+=r[0];if(r[1].length)why.push(t+':'+r[1]);for(const n of STARCHORUS.nodes('ap')){STARCHORUS.select(n.id);r=m();tot+=r[0];if(r[1].length)why.push(t+'+'+n.id+':'+r[1]);}STARCHORUS.deselect();}STARCHORUS.setTheme('foundation');return Math.round(tot)===0?'0':Math.round(tot)+' '+why.slice(0,3).join(' | ')})()"
EDG_MODES="['foundation','wargames','whitehall'].map(t=>{STARCHORUS.setTheme(t);const c=STARCHORUS.edgeLayout(),b=document.getElementById('legend-body');return c.stats+'/'+c.chan+'/'+(b.scrollHeight>b.clientHeight?'scroll':'full')+'/'+getComputedStyle(document.querySelector('#masthead .motto')).display}).join(' ')"
EDG_Q="?poll=0&spin=0&fixed=$STARCHORUS_FIXED&intro=0"

for EDG_VP in 1440x900 1280x800 1000x640; do
  runq "$F/field-probes.json" "$EDG_Q" "out/$P-d15-$EDG_VP" --width "${EDG_VP%x*}" --height "${EDG_VP#*x}" \
    --wait 4 --fps 0 --eval "$EDG_OVL" --eval "$EDG_MODES" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
  EDG_OV=$(evalv "out/$P-d15-$EDG_VP.json" 1)
  EDG_MD=$(evalv "out/$P-d15-$EDG_VP.json" 2)
  EDG_ER=$(evalv "out/$P-d15-$EDG_VP.json" 3)
  case $EDG_VP in
    # the stats row carries the crowding cell (always) and the two freshness cells (dated APs) -> ten cells do not fit one
    # line between masthead and source at 1440 px, so the D15 resolver wraps it (fit); the legend has four blocks (Measured/Derived/
    # Operator + Heard rows) and scrolls inside its max-height (741 px of content in 648) — the overlap area is still 0
    1440x900) EDG_WANT="fit/between/scroll/block fit/between/scroll/block fit/between/scroll/block" ;;
    1000x640) EDG_WANT="fit/docked/scroll/block fit/docked/scroll/block fit/docked/scroll/block" ;;
    *) EDG_WANT=$EDG_MD ;;   # 1280x800: the wrap depends on the theme's font metrics; only the overlap binds
  esac
  if [ "$EDG_OV" = 0 ] && [ "$EDG_MD" = "$EDG_WANT" ] && [ "$EDG_ER" = 0 ]; then
    row "D15 overlap 0 field-probes $EDG_VP" PASS
  else
    row "D15 overlap field-probes $EDG_VP (err ${EDG_ER:-?})" FAIL
    echo "    area: $(printf '%s' "${EDG_OV:-no-value}" | cut -c1-140)"
    echo "    modes: ${EDG_MD:-no-value}"
    echo "    want:  $EDG_WANT"
  fi
done

# tallest chrome: 3D camera row + every optional legend row, at the smallest reference viewport
runq "$F/devices.json" "$EDG_Q&view=3d&deviceLinks=1&essMerge=1&affinity=1" "out/$P-d15-3d" \
  --width 1000 --height 640 --wait 4 --fps 0 --eval "$EDG_OVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
EDG_OV=$(evalv "out/$P-d15-3d.json" 1)
EDG_ER=$(evalv "out/$P-d15-3d.json" 2)
if [ "$EDG_OV" = 0 ] && [ "$EDG_ER" = 0 ]; then
  row "D15 overlap 0 devices 3D+all rows 1000x640" PASS
else
  row "D15 overlap devices 3D 1000x640 (err ${EDG_ER:-?})" FAIL
  echo "    area: $(printf '%s' "${EDG_OV:-no-value}" | cut -c1-140)"
fi

# the Camera row is there in 2D on the desktop too: `+`, `−` and reset (titles 'Zoom in [+]', 'Zoom out [−]', 'Reset [0]'), the four orbit
# arrows only in 3D; with it the 2D panels still do not overlap (smallest reference viewport, EDG_OVL first, in 2D)
EDG_CAM='(async()=>{const E=i=>document.getElementById(i),vis=e=>!!e&&!e.hidden&&e.getClientRects().length>0&&getComputedStyle(e).display!=="none",q=()=>[...document.querySelectorAll("#cam button")].filter(vis).map(b=>b.id.slice(4)).join("+"),o=[vis(E("cam")),q(),["cam-in","cam-out","cam-reset"].map(i=>E(i).title).join("|")];STARCHORUS.setView("3d");await STARCHORUS.wait(300);o.push(vis(E("cam")),q());STARCHORUS.setView("2d");await STARCHORUS.wait(300);o.push(q());return o.join()})()'
runq "$F/field-probes.json" "$EDG_Q" "out/$P-d15-cam" --width 1000 --height 640 --wait 4 --fps 0 \
  --eval "$EDG_OVL" --eval "$EDG_CAM" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
EDG_OV=$(evalv "out/$P-d15-cam.json" 1)
EDG_V=$(evalv "out/$P-d15-cam.json" 2)
EDG_ER=$(evalv "out/$P-d15-cam.json" 3)
EDG_W='true,in+out+reset,Zoom in [+]|Zoom out [−]|Reset [0],true,left+right+up+down+in+out+reset,in+out+reset'
if [ "$EDG_OV" = 0 ] && [ "$EDG_V" = "$EDG_W" ] && [ "$EDG_ER" = 0 ]; then
  row "Camera row in 2D on the desktop: + - reset, arrows only in 3D, overlap 0 (1000x640)" PASS
else
  row "Camera row in 2D (err ${EDG_ER:-?}, overlap area $(printf '%s' "${EDG_OV:-no-value}" | cut -c1-100))" FAIL
  echo "    got:  ${EDG_V:-no-value}"
  echo "    want: $EDG_W"
fi

# ... but it gives way in 2D on a desktop window 620 px high or less, where the 760x600 and 1000x500 rules (small-screen.sh, below) need its
# 40 px: gone in 2D at 1000x620, back in 3D (where it always was), gone again in 2D, and still nothing overlaps
EDG_CAMY='(async()=>{const c=document.getElementById("cam"),v=()=>getComputedStyle(c).display!=="none"&&c.getClientRects().length>0,o=[v()];STARCHORUS.setView("3d");await STARCHORUS.wait(300);o.push(v());STARCHORUS.setView("2d");await STARCHORUS.wait(300);o.push(v());return o.join()})()'
runq "$F/field-probes.json" "$EDG_Q" "out/$P-d15-camy" --width 1000 --height 620 --wait 4 --fps 0 \
  --eval "$EDG_OVL" --eval "$EDG_CAMY" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
EDG_OV=$(evalv "out/$P-d15-camy.json" 1)
EDG_V=$(evalv "out/$P-d15-camy.json" 2)
EDG_ER=$(evalv "out/$P-d15-camy.json" 3)
if [ "$EDG_OV" = 0 ] && [ "$EDG_V" = "false,true,false" ] && [ "$EDG_ER" = 0 ]; then
  row "Camera row yields in 2D at 620 px high or less, stays in 3D, overlap 0 (1000x620)" PASS
else
  row "Camera row at 620 px (err ${EDG_ER:-?}, overlap area $(printf '%s' "${EDG_OV:-no-value}" | cut -c1-100))" FAIL
  echo "    got:  ${EDG_V:-no-value} (want false,true,false: 2D, 3D, 2D)"
fi

# chrome tokens drive (no [data-theme] rules): brackets (chrome.bezel), banner + edge offsets
# (chrome.banner.show -> data-banner -> --chrome-top/--chrome-bot), CRT overlay (crt.userToggle)
EDG_TOK="(()=>{const TH=STARCHORUS._internals.THEMES,el=i=>document.getElementById(i),bad=[];for(const t of ['foundation','wargames','whitehall']){STARCHORUS.setTheme(t);STARCHORUS.setToggles({crt:true});const c=TH[t].chrome,on=!!c.banner.show,b=getComputedStyle(el('masthead'),'::before'),e=20+(on?24:0);const ok=b.width===c.bezel.bracketPx+'px'&&b.borderTopWidth===c.bezel.widthPx+'px'&&document.documentElement.dataset.banner===(on?'on':'off')&&getComputedStyle(el('classbar-top')).display===(on?'block':'none')&&getComputedStyle(el('classbar-bot')).display===(on?'block':'none')&&getComputedStyle(el('dtg')).display===(on?'block':'none')&&['masthead','stats','source'].every(i=>Math.round(el(i).getBoundingClientRect().top)===e)&&['legend','controls'].every(i=>Math.round(innerHeight-el(i).getBoundingClientRect().bottom)===e)&&getComputedStyle(el('crt')).display===(TH[t].crt.userToggle?'block':'none')&&STARCHORUS.themeCheck().ok;if(!ok)bad.push(t);}STARCHORUS.setTheme('foundation');return bad.join(',')||'ok'})()"
runq "$F/field-probes.json" "$EDG_Q&debug=1" "out/$P-d15-tok" --width 1440 --height 900 --wait 4 --fps 0 \
  --eval "$EDG_TOK" >/dev/null 2>&1
EDG_V=$(evalv "out/$P-d15-tok.json" 1)
rowif "chrome tokens: bezel/banner/edge/CRT per theme" [ "$EDG_V" = ok ]
[ "$EDG_V" = ok ] || echo "    failing themes: ${EDG_V:-no-value}"

# MUSS BLEIBEN 20 (≤ 720 px): since D21 the phone mode of §9.8 replaces the old small mode (which hid #stats, #legend and
# #chanbar), so the row asks for that mode: data-phone on, no sideways scroll, the detail opens in the sheet, no --lay-*
# variable, and in Whitehall the sheet sits 8 px above the (wrapped) bottom banner. .motto stays hidden below 900 px on the
# desktop side of the bound (760x600). tools/regress.d/phone.sh holds the phone rows themselves.
EDG_SMALL="(()=>{const e=i=>document.getElementById(i);STARCHORUS.select(STARCHORUS.nodes('ap')[0].id);return [document.documentElement.dataset.phone,document.documentElement.scrollWidth,e('detail').parentNode.id==='sheet-body',document.documentElement.style.cssText.indexOf('--lay-')<0,(STARCHORUS.setTheme('whitehall'),Math.round(innerHeight-e('sheet').getBoundingClientRect().bottom)===e('classbar-bot').offsetHeight+8?'ok':'gap')].join('|')})()"
runq "$F/field-probes.json" "$EDG_Q" "out/$P-d15-640" --width 640 --height 900 --wait 4 --fps 0 \
  --eval "$EDG_SMALL" --step size:760x600 --step "eval:getComputedStyle(document.querySelector('#masthead .motto')).display" >/dev/null 2>&1
EDG_V="$(evalv "out/$P-d15-640.json" 1)|$(evalv "out/$P-d15-640.json" 2)"
rowif "responsive 640x900 = phone mode (D21) + motto < 900 px" [ "$EDG_V" = "on|640|true|true|ok|none" ]
[ "$EDG_V" = "on|640|true|true|ok|none" ] || echo "    got: ${EDG_V:-no-value} (want on|640|true|true|ok|none)"

# D15 priority detail > chanbar: in a short viewport the docked bar collapses while a detail is open
EDG_COLL="[STARCHORUS.edgeLayout().chan,(STARCHORUS.select(STARCHORUS.nodes('ap')[0].id),STARCHORUS.edgeLayout().chan),(STARCHORUS.deselect(),STARCHORUS.edgeLayout().chan),document.getElementById('chanbar').hidden].join()"
runq "$F/field-probes.json" "$EDG_Q&theme=wargames" "out/$P-d15-coll" --width 1000 --height 500 --wait 4 --fps 0 \
  --eval "$EDG_COLL" --eval "$EDG_OVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
EDG_V=$(evalv "out/$P-d15-coll.json" 1)
EDG_OV=$(evalv "out/$P-d15-coll.json" 2)
EDG_ER=$(evalv "out/$P-d15-coll.json" 3)
if [ "$EDG_V" = "docked,collapsed,docked,false" ] && [ "$EDG_OV" = 0 ] && [ "$EDG_ER" = 0 ]; then
  row "D15 chanbar yields to #detail (1000x500)" PASS
else
  row "D15 chanbar collapse path (err ${EDG_ER:-?})" FAIL
  echo "    got: ${EDG_V:-no-value} (want docked,collapsed,docked,false), area $(printf '%s' "${EDG_OV:-no-value}" | cut -c1-100)"
fi

# a pass measures the panels without their caps, which used to put a scrolled legend back at the top on every poll,
# toggle and selection: the offset must survive STARCHORUS.edgeLayout() and a toggle (§9.8a). The legend scrolls here (see above).
EDG_SCR='(()=>{const b=document.getElementById("legend-body");b.scrollTop=40;const s0=b.scrollTop;STARCHORUS.edgeLayout();const s1=b.scrollTop;STARCHORUS.setToggles({labels:false});const s2=b.scrollTop;STARCHORUS.setToggles({labels:true});return s0+"/"+s1+"/"+s2;})()'
runq "$F/field-probes.json" "$EDG_Q" "out/$P-d15-scroll" --width 1440 --height 900 --wait 4 --fps 0 \
  --eval "$EDG_SCR" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
EDG_SV=$(evalv "out/$P-d15-scroll.json" 1)
EDG_ER=$(evalv "out/$P-d15-scroll.json" 2)
if [ "$EDG_SV" = "40/40/40" ] && [ "$EDG_ER" = 0 ]; then
  row "D15 legend scroll offset survives a pass and a toggle (40/40/40)" PASS
else
  row "D15 legend scroll offset lost (err ${EDG_ER:-?})" FAIL
  echo "    got: ${EDG_SV:-no-value} (want 40/40/40: set, after edgeLayout(), after a toggle)"
fi

# ---- static: layoutEdges is theme-free (DOM boxes only) and every chrome-changing site calls it --
# the seven named functions plus the two §41 boot sites (font load, ResizeObserver); all are counted.
EDG_TF=$(awk '/^function layoutEdges\(/,/^}/' "$H" | grep -cE 'THEME|[^A-Za-z]TD\.|[^A-Za-z]TK[^A-Za-z]')
EDG_LE=$(grep -c '^function layoutEdges() {$' "$H")
rowif "layoutEdges ($EDG_LE) theme-free (token reads $EDG_TF)" [ "$EDG_LE/$EDG_TF" = 1/0 ]
EDG_HOOK=""
for EDG_FN in resize updateControlsLook updateStats buildLegend openDetail setSourcePanel; do
  EDG_N=$(awk -v FN="$EDG_FN" '$0 ~ ("^function " FN "\\(") , /^}/' "$H" | grep -c 'layoutEdges()')
  EDG_HOOK="$EDG_HOOK$EDG_N/"
done
EDG_HOOK="$EDG_HOOK$(grep -c '^function closeDetail() {.*layoutEdges(); }$' "$H")"
# the two §41 boot sites are not inside a named function, so they need their own anchors: the font-load
# rerun (labels switch to the signage face) and the ResizeObserver safety net of D15. Without these
# anchors either could be deleted with every other row here still green.
EDG_FT=$(grep -c 'S\.dirty = true; layoutEdges(); if (W > 0) render();' "$H")
EDG_RO=$(grep -c 'rq = requestAnimationFrame(() => { rq = 0; layoutEdges(); })' "$H")
EDG_LB=$(grep -c 'legendBody.innerHTML = rows.join("");' "$H")
rowif "layoutEdges hooks $EDG_HOOK+$EDG_FT/$EDG_RO, legendBody $EDG_LB" [ "$EDG_HOOK/$EDG_FT/$EDG_RO/$EDG_LB" = "1/1/1/1/2/1/1/1/1/1" ]

# ---- large text: a browser's minimum font size (16 px) and a wide fallback face, as an in-car browser showed on 17 October 2026 --
# (the version stood outside the masthead, the Whitehall plot clock ran over the name, the source text wrapped one word per line).
# Emulated in the page itself: every text under 16 px is set to 16 px and the face is Verdana. In every theme the version stays
# inside the masthead, the brand fits its box once tightened, the name keeps clear of the clock or the lamps (the badge sits above the cap height), the source text is
# at least 9em wide, the Load button stays inside the panel and no control-group label runs under its first button. The control run at the design sizes shows that
# neither class fires with a release-shaped version (0.0.0 stands in: a longer development string such as 0.2.0-dev.1 may legitimately make the WarGames lamps claim
# their room and the version wrap under the name), and that the real version string stays inside the masthead, the brand in its box and clear of the clock or the lamps.
EDG_BIG="(()=>{const st=document.createElement('style');st.textContent=':root,body,.panel,.brand{font-family:Verdana,sans-serif !important}';document.head.appendChild(st);for(const e of document.querySelectorAll('body *')){const cs=getComputedStyle(e);if(cs.display==='none')continue;const f=parseFloat(cs.fontSize);if(f&&f<16)e.style.setProperty('font-size','16px','important')}const E=i=>document.getElementById(i),R=e=>e.getBoundingClientRect();const out=[];for(const t of ['foundation','wargames','whitehall']){STARCHORUS.setTheme(t);STARCHORUS.edgeLayout();const mh=E('masthead'),mb=E('mast-brand'),v=E('mast-ver'),d=document.querySelector('#source .desc');const rg=document.createRange();rg.setStartBefore(mb.firstChild);rg.setEndAfter(mb.childNodes[1]);const nm=rg.getBoundingClientRect(),vr=R(v);const a=(vr.top<nm.bottom)?{left:nm.left,right:Math.max(nm.right,vr.right),top:nm.top,bottom:nm.bottom}:nm,p=R(mh),deco=mh.querySelector('.plotclock, .lamps');const dr=deco?R(deco):null;const em=parseFloat(getComputedStyle(d).fontSize);out.push([t,R(v).right<=p.right+0.5,mb.scrollWidth<=mb.clientWidth+1,!dr||a.right<=dr.left+1||a.bottom<=dr.top||a.top>=dr.bottom,R(d).width>=9*em-1,R(E('btn-load')).right<=R(E('source')).right+0.5,[...document.querySelectorAll('#controls .group')].every(g=>{const l=g.querySelector('.glabel'),b=[...g.querySelectorAll('.btn, button')].find(x=>x.getClientRects().length);return !l||!b||R(l).right<=R(b).left+0.5})].join(':'))}return out.join('|')})()"
EDG_CTL="(()=>{const E=i=>document.getElementById(i),R=e=>e.getBoundingClientRect();const out=[];for(const t of ['foundation','wargames','whitehall']){STARCHORUS.setTheme(t);STARCHORUS.edgeLayout();const mh=E('masthead'),mb=E('mast-brand'),v=E('mast-ver');const rg=document.createRange();rg.setStartBefore(mb.firstChild);rg.setEndAfter(mb.childNodes[1]);const nm=rg.getBoundingClientRect(),vr=R(v);const a=(vr.top<nm.bottom)?{left:nm.left,right:Math.max(nm.right,vr.right),top:nm.top,bottom:nm.bottom}:nm,deco=mh.querySelector('.plotclock, .lamps'),dr=deco?R(deco):null;const real=[R(v).right<=R(mh).right+0.5,mb.scrollWidth<=mb.clientWidth+1,!dr||a.right<=dr.left+1||a.bottom<=dr.top||a.top>=dr.bottom];const keep=v.textContent;v.textContent='0.0.0';STARCHORUS.edgeLayout();const off=[!mh.classList.contains('tight'),!mh.classList.contains('clear-right')];v.textContent=keep;STARCHORUS.edgeLayout();const b=R(E('btn-load')),c=R(E('mode-chip'));out.push([t,...real,...off,Math.abs(b.top+b.height/2-(c.top+c.height/2))<4,getComputedStyle(document.querySelector('#controls .glabel')).width==='50px'].join(':'))}return out.join('|')})()"
EDG_WANT_BIG="foundation:true:true:true:true:true:true|wargames:true:true:true:true:true:true|whitehall:true:true:true:true:true:true"
EDG_WANT_CTL="foundation:true:true:true:true:true:true:true|wargames:true:true:true:true:true:true:true|whitehall:true:true:true:true:true:true:true"
runq "$F/field-probes.json" "$EDG_Q" "out/$P-bigtext" --width 1200 --height 1900 --wait 4 --fps 0 --eval "$EDG_BIG" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
EDG_V=$(evalv "out/$P-bigtext.json" 1); EDG_ER=$(evalv "out/$P-bigtext.json" 2)
if [ "$EDG_V" = "$EDG_WANT_BIG" ] && [ "$EDG_ER" = 0 ]; then row "large text (16 px minimum, wide face, 1200x1900): version inside the masthead, brand fits, name clear of clock/lamps, source text ≥ 9em, Load inside, no group label under its first button, 3 themes" PASS
else row "large text layout (err ${EDG_ER:-?})" FAIL; echo "    got: ${EDG_V:-no-value} (want $EDG_WANT_BIG)"; fi
runq "$F/field-probes.json" "$EDG_Q" "out/$P-bigtext-ctl" --width 1440 --height 900 --wait 4 --fps 0 --eval "$EDG_CTL" >/dev/null 2>&1
EDG_V=$(evalv "out/$P-bigtext-ctl.json" 1)
if [ "$EDG_V" = "$EDG_WANT_CTL" ]; then row "large-text fits at the design sizes (1440x900): the real version stays inside the masthead, the brand in its box and clear of clock/lamps; with a release-shaped version (0.0.0) neither .tight nor .clear-right fires; Load on the chip's row, group labels 50 px, 3 themes" PASS
else row "large-text fits at the design sizes" FAIL; echo "    got: ${EDG_V:-no-value} (want $EDG_WANT_CTL)"; fi
