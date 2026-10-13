# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/small-screen.sh -- the small screen 760×600 (D15), in all three themes, with and without the detail sheet.
# The overlap probe is the one of edge-layout.sh (masthead, stats, source, legend, controls, chanbar, both banners, dtg and every .panel; the detail sheet is selected inside it).
# Sourced by tools/regress.sh with cwd = repo root. Only SML_* globals are set.

eval "$(grep '^EDG_OVL=' tools/regress.d/edge-layout.sh)"
for SML_T in foundation wargames whitehall; do
  runq "$F/field-probes.json" "?poll=0&spin=0&intro=0&theme=$SML_T" "out/$P-sml-$SML_T" --width 760 --height 600 --wait 4 --fps 0 --eval "$EDG_OVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
  SML_OV=$(evalv "out/$P-sml-$SML_T.json" 1); SML_OE=$(evalv "out/$P-sml-$SML_T.json" 2)
  if [ "$SML_OV" = 0 ] && [ "$SML_OE" = 0 ]; then row "D15 760x600 $SML_T: overlap 0 with and without the detail sheet (err ${SML_OE:-?}) [$(printf '%s' "$SML_OV" | cut -c1-70)]" PASS
  else row "D15 760x600 $SML_T: overlap 0 with and without the detail sheet (err ${SML_OE:-?}) [$(printf '%s' "$SML_OV" | cut -c1-70)]" FAIL; fi
done
# the stats panel wraps into rows instead of a 100 px column, and the channel bar docks
runq "$F/field-probes.json" "?poll=0&spin=0&intro=0" "out/$P-sml-geo" --width 760 --height 600 --wait 4 --fps 0 --eval "JSON.stringify([STARCHORUS.edgeLayout().chan,Math.round(document.getElementById('stats').getBoundingClientRect().width),Math.round(document.getElementById('stats').getBoundingClientRect().height)])" >/dev/null 2>&1
SML_G=$(evalv "out/$P-sml-geo.json" 1)
rowif "D15 760x600: #stats is a real panel again (width >= 230, height <= 260) and the channel bar docks [$SML_G]" [ "$(printf '%s' "$SML_G" | python3 -c 'import json,sys;a=json.load(sys.stdin);print(a[0]=="docked" and a[1]>=230 and a[2]<=260)' 2>/dev/null)" = True ]
# the drawers (air, time, record, inventory) at 760x600 keep the edge panels apart too
for SML_D in air time rec; do
  runq "$F/field-probes.json" "?poll=0&spin=0&intro=0" "out/$P-sml-d-$SML_D" --width 760 --height 600 --wait 4 --fps 0 --eval "(async()=>{STARCHORUS.openDrawer('$SML_D');await STARCHORUS.wait(300);return 1})()" --eval "$EDG_OVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
  SML_OV=$(evalv "out/$P-sml-d-$SML_D.json" 2); SML_OE=$(evalv "out/$P-sml-d-$SML_D.json" 3)
  if [ "$SML_OV" = 0 ] && [ "$SML_OE" = 0 ]; then row "D15 760x600 with the $SML_D drawer open: overlap 0 (err ${SML_OE:-?}) [$(printf '%s' "$SML_OV" | cut -c1-60)]" PASS
  else row "D15 760x600 with the $SML_D drawer open: overlap 0 (err ${SML_OE:-?}) [$(printf '%s' "$SML_OV" | cut -c1-60)]" FAIL; fi
done
