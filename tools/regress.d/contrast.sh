# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/contrast.sh -- contrast (WarGames/Whitehall greys, line.ring, bubble caption)
# and the debug hook STARCHORUS.contrast(). Sourced by tools/regress.sh with cwd = repo root,
# after the core rows. Only CTR_* globals are set.
#
# One demo run with ?debug=1 carries all three runtime checks: the default pair list in every theme
# (text >= 4.5, rings/marks >= 3), the API semantics (known ratios, alpha compositing, "ground", a single
# pair, themeId without a theme switch, invalid input) and the 2D ring pixels on #bg. The run may use
# ?fixed: it only reads token maths and the #bg canvas, which is baked in applyTheme (nodes would stay
# invisible under a frozen clock, but no node is measured here).
# The pair list may GROW (the active-scan chip and the banner/chrome pairs are part of it):
# the row requires >= 23 pairs and prints the measured count; every pair must pass its own minimum.

# ---- runtime: default list, API semantics, ring pixels (one Chrome run)
CTR_EV1='(function(){const bad=[];let n=0;for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);const r=STARCHORUS.contrast();if(!Array.isArray(r)||r.length<23){bad.push(t+":shape:"+(Array.isArray(r)?r.length:typeof r));continue}n=r.length;for(const p of r)if(!p.pass)bad.push(t+":"+p.fg+"@"+[].concat(p.bg).join("+")+"="+p.ratio)}STARCHORUS.setTheme("foundation");return bad.length?bad.join(","):"ok:"+n})()'
CTR_EV2='(function(){const r=STARCHORUS.contrast([["#ffffff","#000000"],["#777777","#000000"],["rgba(255,255,255,0.5)","#000000"],["ink.primary","surface.panelFill"],["nope","surface.base",3]],"wargames").map(p=>p.ratio+"/"+p.pass).join(",");const one=STARCHORUS.contrast(["ink.muted","ground",4.5],"whitehall");const a=JSON.stringify(STARCHORUS.contrast(null,"whitehall"));STARCHORUS.setTheme("whitehall");const b=JSON.stringify(STARCHORUS.contrast());STARCHORUS.setTheme("foundation");const e=[STARCHORUS.contrast({}).error,STARCHORUS.contrast(null,"nope").error,STARCHORUS.contrast(null,"constructor").error].join("|");return r==="21/undefined,4.69/undefined,5.32/undefined,16.72/undefined,null/false"&&one.length===1&&one[0].pass===true&&one[0].ratio===4.86&&a===b&&STARCHORUS.getTheme()==="foundation"&&e==="pairs: expected [[fg, bg, min?], …]|unknown theme: nope|unknown theme: constructor"?"ok":r+"|"+JSON.stringify(one)+"|"+e})()'
# ring pixels: scan the column 2 px left of the centre upward; each ring crossing must carry the theme's
# line.ring RGB (tolerance 6/255, alpha >= 0.45 of the token alpha -- 1-px rings are antialiased).
CTR_EV3='(function(){const I=STARCHORUS._internals;if(!I)return "no-debug";const bad=[];for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);STARCHORUS.frame();const s=String(I.THEMES[t].line.ring||""),h=/^#([0-9a-f]{6})$/i.exec(s),q=/^rgba?\(([^)]+)\)$/.exec(s);let c=null;if(h){const n=parseInt(h[1],16);c=[n>>16&255,n>>8&255,n&255,1]}else if(q){const v=q[1].split(",").map(Number);c=[v[0],v[1],v[2],v.length>3?v[3]:1]}if(!c){bad.push(t+":no-line.ring");continue}const x=innerWidth/2-2,cy=innerHeight/2;let hit=0,prev=false;for(let y=0;y<=cy;y++){const p=STARCHORUS.pixel("bg",x,y),m=p.a>=0.45*c[3]*255&&Math.abs(p.r-c[0])<=6&&Math.abs(p.g-c[1])<=6&&Math.abs(p.b-c[2])<=6;if(m&&!prev)hit++;prev=m}if(hit!==I.LAYOUT.rings.length)bad.push(t+":"+hit+"/"+I.LAYOUT.rings.length)}STARCHORUS.setTheme("foundation");return bad.length?bad.join(","):"ok"})()'
runq demo "?poll=0&spin=0&fixed=$STARCHORUS_FIXED&intro=0&debug=1" "out/$P-contrast" --fps 0 --wait 3 \
  --eval "$CTR_EV1" --eval "$CTR_EV2" --eval "$CTR_EV3" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CTR_V1=$(evalv "out/$P-contrast.json" 1); CTR_V2=$(evalv "out/$P-contrast.json" 2)
CTR_V3=$(evalv "out/$P-contrast.json" 3); CTR_ERR=$(evalv "out/$P-contrast.json" 4)
case $CTR_V1 in
  ok:*) row "contrast text ≥ 4.5, rings ≥ 3 (3 themes, ${CTR_V1#ok:} pairs)" PASS ;;
  *) row "contrast (3 themes)" FAIL; echo "    ${CTR_V1:-no-value}" ;;
esac
if [ "$CTR_V2" = ok ] && [ "$CTR_ERR" = 0 ]; then
  row "STARCHORUS.contrast() API (errors $CTR_ERR)" PASS
else
  row "STARCHORUS.contrast() API (errors ${CTR_ERR:-?})" FAIL; echo "    ${CTR_V2:-no-value}"
fi
if [ "$CTR_V3" = ok ]; then
  row "contrast: 2D ring pixels = line.ring (3 themes)" PASS
else
  row "contrast: 2D ring pixels = line.ring" FAIL; echo "    ${CTR_V3:-no-value}"
fi

# ---- static: the two ring loops in §34 use line.ring; spokes and dot grid keep line.hairline
CTR_N=$(awk '/==== 34 RENDER LAYERS/,/==== 35 RENDER HUD/' "$H" | grep -c 'strokeStyle = THEME\.line\.ring')
# the Scope (D22) draws its own rings in the same colour: one more, and in drawScopeBg only; the 2D and 3D loops stay exactly two
CTR_S=$(awk '/^function drawScopeBg\(/,/^}/' "$H" | grep -c 'strokeStyle = THEME\.line\.ring')
rowif "contrast: rings stroked with line.ring (2D+3D) = $((CTR_N - CTR_S)), and the Scope's = $CTR_S" [ "$((CTR_N - CTR_S))/$CTR_S" = 2/1 ]
CTR_C=$(grep -c 'c.fillStyle = THEME.ink.secondary; c.fillText(TD.upper ? "CLIENTS"' "$H")
CTR_P=$(sed -n '/^const CONTRAST_PAIRS/,/^window.STARCHORUS = /p' "$H" | grep -c 'Date\.now\|Math\.random\|performance\.now\|document\.\|getComputedStyle\|fetch(')
rowif "contrast: bubble caption ink.secondary ($CTR_C), contrast() pure ($CTR_P)" [ "$CTR_C/$CTR_P" = 1/0 ]

# ---- 0.2, the radio pair: the Bluetooth mark is a contrast pair of its own (render.btMark on surface.base, minimum 3, the ring minimum), in all three themes; the pair is one of
# the rows CTR_EV1 above already requires to pass. A mark too dark for the ground fails the same API, so the row can bite.
CTR_EVB='(function(){const o=[];for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);const r=STARCHORUS.contrast().filter(p=>p.fg==="render.btMark");o.push(r.length===1&&r[0].bg==="surface.base"&&r[0].min===3&&r[0].pass?r[0].ratio:"bad:"+JSON.stringify(r))}
const dark=STARCHORUS.contrast([["#2a1020","surface.base",3]],"foundation")[0].pass;STARCHORUS.setTheme("foundation");return o.join("/")+"|"+dark})()'
runq demo "?poll=0&spin=0&fixed=$STARCHORUS_FIXED&intro=0&debug=1" "out/$P-contrast-bt" --fps 0 --wait 2 --eval "$CTR_EVB" >/dev/null 2>&1
CTR_B=$(evalv "out/$P-contrast-bt.json" 1)
rowif "contrast (radio pair): render.btMark on surface.base is a pair of its own, minimum 3, passing in all 3 themes (7.18 / 8.05 / 3.94), and a too-dark mark fails the same API [$CTR_B]" [ "$CTR_B" = "7.18/8.05/3.94|false" ]
