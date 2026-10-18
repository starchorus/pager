# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/legend.sh -- the legend shows the canvas marks, and the debug hook
# STARCHORUS.legendRows(). Sourced by tools/regress.sh with cwd = repo root, after the core rows.
# Only LEG_* globals are set.
#
# One many-clients run with ?debug=1 carries both runtime rows. It may keep ?fixed: nothing here reads a
# node or a canvas, only the #legend DOM and the token values (nodes would stay invisible under a frozen
# clock). Eval order matters: the basic DOM row runs FIRST, because tools/evals/legend-truth.js ends with
# a synthetic STARCHORUS.load that replaces the fixture (the '#leg-open' count would then be 0).
# The token table that makes the check non-tautological lives in tools/evals/legend-truth.js, not in the
# page; a change of the canvas marks (open ring D6, identity D7, randomized D8, derived-row swatches D10, ...)
# must update it in the same commit.

LEG_EVDOM='(function(){var o=[];o.push(document.querySelector("#leg-open .cnt").textContent);STARCHORUS.setTheme("wargames");o.push(getComputedStyle(document.getElementById("leg-arc")).display!=="none");STARCHORUS.setTheme("foundation");o.push(getComputedStyle(document.getElementById("leg-arc")).display!=="none");STARCHORUS.setView("3d");o.push(getComputedStyle(document.getElementById("leg-height")).display!=="none");STARCHORUS.setView("2d");return o.join("/")})()'
LEG_EVL=$(cat "$R/tools/evals/legend-truth.js")
runq "$F/many-clients.json" "?intro=0&poll=0&spin=0&fixed=$STARCHORUS_FIXED&debug=1" "out/$P-legend" --fps 0 --wait 3 \
  --eval "$LEG_EVDOM" --eval "$LEG_EVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
LEG_VDOM=$(evalv "out/$P-legend.json" 1)
LEG_VL=$(evalv "out/$P-legend.json" 2)
LEG_ERR=$(evalv "out/$P-legend.json" 3)

if [ "$LEG_VL" = "[]" ] && [ "$LEG_ERR" = 0 ]; then
  row "legend swatches = canvas tokens (3 themes)" PASS
else
  row "legend swatches != canvas tokens (errors ${LEG_ERR:-?})" FAIL
  echo "    $(printf '%s' "${LEG_VL:-no-value}" | cut -c1-160)"
fi
# basic §9.4 checks: security count, #leg-arc only in WarGames, #leg-height only in 3D
if [ "$LEG_VDOM" = "4/true/false/true" ]; then
  row "legend DOM: leg-open 4, arc W/F, height 3D" PASS
else
  row "legend DOM (want 4/true/false/true, got ${LEG_VDOM:-no-value})" FAIL
fi

# ---- static: #leg-arc follows the probe-arc draw path, no randomized row without a randomized mark
LEG_UT=$(awk '/^function (buildLegend|legendVisibility)\(/,/^}/' "$H" | grep -c 'crt\.userToggle')
rowif "legend #leg-arc not keyed on crt.userToggle" [ "$LEG_UT" = 0 ]
LEG_ARC=$(awk '/^function legendVisibility\(/,/^}/' "$H" | grep -c 'THEME.render.probeArc && THEME.line.edge.style === "parabola"')   # D10: the visibility rules live in legendVisibility()
LEG_RND=$(awk '/^function buildLegend\(/,/^}/' "$H" | sed 's://.*::' | grep -c "data-kind=\"client-random\"")   # D8: the randomized row exists (hidden until such a client is present)
rowif "legend: buildLegend: arc path-bound ($LEG_ARC), randomized row (D8) present ($LEG_RND)" [ "$LEG_ARC/$LEG_RND" = 1/1 ]

# ---- static: the three legend variables are mirrored (themeCheck/EV3 covers them) and painted at first paint
LEG_MIR=$(grep -c '\["--client", "render.clientCore", ""\], \["--bubble-fill", "render.bubbleFill", ""\], \["--bubble-stroke", "render.bubbleStroke", ""\],' "$H")
LEG_ROOT=$(grep -cE '^  --(client|bubble-fill|bubble-stroke): ' "$H")
rowif "legend: --client/--bubble-* in CSS_MIRROR ($LEG_MIR) and :root ($LEG_ROOT)" [ "$LEG_MIR/$LEG_ROOT" = 1/3 ]

# ---- 0.2, the radio pair: the legend rows of the new layers are the canvas, on tests/fixtures/radio-pair.json (the three kinds are hidden on every other fixture:
# tools/evals/legend-truth.js above). The Bluetooth row exists exactly while a mark can be drawn, with its geometry clause, its swatch the render.btMark of each theme;
# the activity row only in bars mode with the bar shown and a whisker drawn; the traffic row while a station carries the cue. Runs without ?fixed: nodes must fade in.
LEG_EVR='(async()=>{const I=STARCHORUS._internals,S=I.S,sleep=STARCHORUS.wait,o={};await sleep(1500);
const fx=await (await fetch("starchorus.json")).json(),G=fx.generated,A="02:00:00:00:02:01";
const ld=(mut,gen,label)=>{const d=JSON.parse(JSON.stringify(fx));if(gen!=null)d.generated=gen;if(mut)mut(d);return STARCHORUS.load(d,label||"rp-leg");};
const vis=()=>["bt","activity","traffic"].map(k=>STARCHORUS.legendRows().find(r=>r.kind===k).visible?1:0).join("");
const geo=()=>document.getElementById("leg-geometry").textContent;
o.start=vis();
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);const r=STARCHORUS.legendRows().find(x=>x.kind==="bt");o["sw_"+t]=r.paints.length>0&&r.paints.every(p=>p.tok==="render.btMark"&&p.css===p.val);}
STARCHORUS.setTheme("foundation");
STARCHORUS.setToggles({bands:{bt:false}});o.btOff=vis()+"|"+geo();STARCHORUS.setToggles({bands:{bt:true}});o.btOn=vis()+"|"+(geo().indexOf("Bluetooth and Wi-Fi share the rings, not the scale")>0);
STARCHORUS.setChannelMode("spectrum");o.spectrum=vis();STARCHORUS.setChannelMode("waterfall");o.waterfall=vis();STARCHORUS.setChannelMode("bars");o.bars=vis();
ld(d=>{delete d.activity;},G+10);o.noActivity=vis();ld(null,G+20);o.again=vis();
ld(d=>{d.bluetooth=[];},G+30);o.btEmpty=vis();ld(null,G+40);
const lp=(pk,g)=>ld(d=>{d.unassociated.forEach(u=>{if(u.mac===A)u.packets=pk;else delete u.packets;});},g,"rp-leg2");
lp(1000,G+100);o.cue0=vis();lp(1100,G+140);await sleep(300);o.cue1=vis();lp(50,G+180);await sleep(300);o.cue2=vis();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$F/radio-pair.json" "?poll=0&spin=0&intro=0&debug=1" "out/$P-legend-radio" --fps 0 --wait 3 --eval-timeout 120 --eval "$LEG_EVR" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
LEG_R=$(evalv "out/$P-legend-radio.json" 1 | python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null); LEG_RE=$(evalv "out/$P-legend-radio.json" 2)
LEG_RW='{"again":"110","bars":"110","btEmpty":"010","btOff":"010|rings = received signal (dBm), not range · direction is not measured","btOn":"110|true","cue0":"110","cue1":"111","cue2":"110","errors":0,"noActivity":"100","spectrum":"100","start":"110","sw_foundation":true,"sw_wargames":true,"sw_whitehall":true,"waterfall":"100"}'
if [ "$LEG_R" = "$LEG_RW" ] && [ "$LEG_RE" = 0 ]; then
  row "legend (radio pair): Bluetooth row exactly while a mark is drawn (swatch = render.btMark in 3 themes, geometry clause with it), activity row only in bars mode with a whisker, traffic row while a station carries the cue" PASS
else
  row "legend (radio pair) (err ${LEG_RE:-?})" FAIL; echo "    got:  $(printf '%s' "$LEG_R" | cut -c1-500)"; echo "    want: $LEG_RW"
fi
# the bar collapsed under a detail sheet (1000x560: eleven cells in the Sky panel, with the Bluetooth cell, wrap to four rows at 500 px high and the bar's own fallback
# collapses it there; at 560 px it is shown) takes the activity row with it
LEG_EVC='(async()=>{const sleep=STARCHORUS.wait,o={};await sleep(1800);const row=()=>STARCHORUS.legendRows().find(r=>r.kind==="activity").visible,bar=()=>document.getElementById("chanbar").hidden;
o.open=[bar(),row()].join("/");STARCHORUS.select("02:00:00:00:01:01");await sleep(300);STARCHORUS.frame();o.sel=[bar(),row()].join("/");STARCHORUS.deselect();await sleep(300);o.closed=[bar(),row()].join("/");return JSON.stringify(o)})()'
runq "$F/radio-pair.json" "?poll=0&spin=0&intro=0&debug=1" "out/$P-legend-collapse" --width 1000 --height 560 --fps 0 --wait 3 --eval-timeout 60 --eval "$LEG_EVC" >/dev/null 2>&1
LEG_C=$(evalv "out/$P-legend-collapse.json" 1)
rowif "legend (radio pair): the activity row hides with the collapsed bar (1000x560, a detail sheet open) and returns with it [$LEG_C]" [ "$LEG_C" = '{"open":"false/true","sel":"true/false","closed":"false/true"}' ]
