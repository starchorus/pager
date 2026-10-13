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
