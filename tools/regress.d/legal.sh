# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/legal.sh -- legal denylist rows (spec §14.7). Sourced by tools/regress.sh
# with cwd = repo root, after the core rows. The §14.7 file set itself (page + both starchorus-display.sh, which
# includes the literal `grep -ciFf tools/denylist.txt`) is the passivity-check.sh row "§14.7 denylist-
# check.sh"; this file adds the grep selftest (which also pins the list CONTENTS, one fixture line per
# §14.7-enumerated item), the extended file set, the rendered text of all three themes (CSS uppercase
# included, both typed logons, detail/help/paste/tooltip/chanbar) and the display LOG.
# Only LGL_* globals are set.

# R1 · grep semantics of this machine (-i substring, -iw whole word, case-sensitive list, data: URIs)
if LGL_O=$(sh tools/denylist-check.sh --selftest 2>&1); then
  row "denylist selftest ($(printf '%s\n' "$LGL_O" | sed -n 's/^selftest: positives hit \([0-9/]*\), negatives hit \([0-9/]*\)$/pos \1, neg \2/p'))" PASS
else
  row "denylist selftest (grep semantics)" FAIL; printf '%s\n' "$LGL_O" | sed 's/^/    /'
fi

# R3 · extended set: collector, both payload.sh, index.html, starchorus-serve.sh, gen-testdata.py, fixtures
LGL_O=$(sh tools/denylist-check.sh --extended 2>&1); LGL_RC=$?
LGL_N=$(printf '%s\n' "$LGL_O" | grep -c '^[0-9][0-9]* [0-9][0-9]* [0-9][0-9]* ')
if [ "$LGL_RC" = 0 ]; then
  row "denylist --extended = 0 ($LGL_N files)" PASS
else
  row "denylist --extended = 0 ($LGL_N files, exit $LGL_RC)" FAIL
  printf '%s\n' "$LGL_O" | grep -v '^0 0 0 ' | cut -c1-170 | sed 's/^/    /'
fi

# R4 · rendered text of all three themes: innerText (with CSS text-transform), #intro-text, [title],
# document.title, meta description -- idle, and once more with #detail, #help and the paste dialog
# force-rendered, the strongest AP selected and hovered (#tip) and every occupied channel's chanbar
# tooltip text appended. innerText is kept as the sampling method on purpose: it is the only surface
# that reflects the .panel text-transform, which a TreeWalker over nodeValue cannot see.
# Start themes wargames and whitehall type the two logons; skipIntro() completes a logon still typing.
# The eval returns "<verdict>|<theme>:<rendered logon lines>,…" -- the line count is taken INSIDE the
# theme loop, because applyTheme() rewrites #intro-text, so a count read after the loop would report
# the last theme's logon three times. Every theme's own count is guarded.
LGL_EVD='(()=>{const cs=/\b(OFFICIAL|SECRET|NOFORN|EYES ONLY|RECIPIENTS ONLY|PROTECTIVELY MARKED)\b/,ci=/shall we play|play a game|game of chess|winning move|defcon|def con|\bnorad\b|\bwopr\b|joshua|falken|thermonuclear|cocked pistol|seldon|psychohistor|trantor|sandogram|prime radiant|galactica|time vault/i,bad=[],lines=[];for(const t of ["wargames","whitehall","foundation"]){STARCHORUS.setTheme(t);STARCHORUS.frame();lines.push(t.slice(0,2)+":"+document.getElementById("intro-text").textContent.split("\n").filter(x=>x.trim()).length);let s=[document.body.innerText,document.getElementById("intro-text").textContent,[...document.querySelectorAll("[title]")].map(e=>e.title).join(" "),document.title,(document.querySelector("meta[name=description]")||{}).content||""].join(" | ");const ap=STARCHORUS.nodes("ap").filter(n=>n.visible).sort((a,b)=>(b.rssi==null?-999:b.rssi)-(a.rssi==null?-999:a.rssi))[0];if(ap){STARCHORUS.select(ap.id);STARCHORUS.hoverNode(ap.id)}const st=["help","detail","paste-wrap"].map(id=>{const e=document.getElementById(id);const o=[e,e.hidden,e.style.display];e.hidden=false;if(getComputedStyle(e).display==="none")e.style.display="block";return o});STARCHORUS.frame();s+=" | "+document.body.innerText;const ch=STARCHORUS.channels()||{};for(const b of ["2.4","5","6"])for(const c of Object.keys(ch[b]||{}))s+=" | "+STARCHORUS.hoverChannel(b,c);for(const[e,h,d]of st){e.hidden=h;e.style.display=d}if(ap){STARCHORUS.hoverNode(null);STARCHORUS.deselect()}STARCHORUS.frame();s=s.replace(/no official marking|not an official/gi," ");const m=s.match(cs)||s.match(ci);if(m)bad.push(t+":"+m[0]);}STARCHORUS.setTheme("foundation");return (bad.join(",")||"none")+"|"+lines.join(",")})()'
LGL_BAD=""; LGL_LOG=""
for LGL_TH in wargames whitehall; do
  runq "$F/field-probes.json" "?poll=0&spin=0&fixed=$STARCHORUS_FIXED&theme=$LGL_TH" "out/$P-deny-$LGL_TH" --wait 4 --fps 0 \
    --eval "STARCHORUS.skipIntro()" --eval "$LGL_EVD" >/dev/null 2>&1
  LGL_V=$(evalv "out/$P-deny-$LGL_TH.json" 2)
  case $LGL_V in *'|'*) LGL_D=${LGL_V%%'|'*}; LGL_L=${LGL_V#*'|'} ;; *) LGL_D=${LGL_V:-no-value}; LGL_L="" ;; esac
  LGL_LOG="$LGL_LOG $LGL_TH>${LGL_L:-?}"
  [ "$LGL_D" = none ] || LGL_BAD="$LGL_BAD $LGL_TH:$LGL_D"
  # every theme's own logon must still be >= 3 rendered lines (the guard the row name promises)
  LGL_N=0; LGL_R=$LGL_L
  while [ -n "$LGL_R" ]; do
    LGL_PR=${LGL_R%%,*}
    case $LGL_R in *,*) LGL_R=${LGL_R#*,} ;; *) LGL_R="" ;; esac
    LGL_N=$((LGL_N + 1))
    [ "${LGL_PR#*:}" -ge 3 ] 2>/dev/null || LGL_BAD="$LGL_BAD $LGL_TH/$LGL_PR:logon-short"
  done
  [ "$LGL_N" = 3 ] || LGL_BAD="$LGL_BAD $LGL_TH:no-per-theme-logon-count"
done
rowif "rendered text+panels: no denied term (logon lines$LGL_LOG)" [ -z "$LGL_BAD" ]
[ -z "$LGL_BAD" ] || echo "   $LGL_BAD"

# R5 · display LOG (a visible surface, P10): both starchorus-display.sh copies, 8 screens x every fixture
LGL_LG="out/$P-display-log.txt"; : > "$LGL_LG"; LGL_FXN=0
for LGL_FJ in "$F"/*.json; do LGL_FXN=$((LGL_FXN + 1)); done
for LGL_PG in starchorus-display.sh library/user/reconnaissance/starchorus/starchorus-display.sh; do
  for LGL_S in summary top bands devices probes clients bluetooth air; do
    for LGL_FJ in "$F"/*.json; do STARCHORUS_DISPLAY_PLAIN=1 sh "$LGL_PG" --once "$LGL_S" "$LGL_FJ" >> "$LGL_LG" 2>&1; done
  done
done
LGL_LN=$(wc -l < "$LGL_LG" | tr -d ' '); LGL_O="empty log $LGL_LG"; LGL_RC=1
if [ -s "$LGL_LG" ]; then LGL_O=$(sh tools/denylist-check.sh "$R/$LGL_LG" 2>&1); LGL_RC=$?; fi
if [ "$LGL_RC" = 0 ]; then
  row "display LOG: no denied term (8 screens x $LGL_FXN fixtures x 2 copies, $LGL_LN lines)" PASS
else
  row "display LOG: no denied term ($LGL_LN lines)" FAIL; printf '%s\n' "$LGL_O" | cut -c1-170 | sed 's/^/    /'
fi
