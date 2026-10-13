# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/neutral-language.sh -- P10 neutral language (spec §14.5 P10), machine-checked. Sourced by
# tools/regress.sh with cwd = repo root, after the core rows. Only NTL_* globals and ntl_* functions.
#
# Page: document.body.innerText + every text node (hidden panels too: help, detail, tooltip, paste
# box, logon, banners) + title/aria-label/placeholder/alt/meta content + document.title, in all
# three themes -- idle, and with detail panel + tooltip open on the strongest AP, an associated
# client, a free client and a bubble (when present) -- plus the chanbar tooltip text of every
# occupied channel; fixtures demo, active, devices, field-probes (start themes cover both logons).
# Display script: LOG of both starchorus-display.sh copies (--once, EVERY screen x every fixture) plus every "…"
# literal of the scripts (menu, spinner and dialog texts that --once never prints). The screen list is read
# from each script (its screen_NAME() functions), not typed here: a typed list would silently miss a screen added
# later (the display script has 7 screens). Vacuity guard: screens that produced output == screens defined, and render()
# dispatches every one of them (`--once NAME` for a name render() does not know silently prints the summary instead).
# A screen counts as covered only if its output is non-empty on at least one fixture and (other than summary itself) differs
# from the summary's output on at least one fixture: counting loop passes proves nothing, a screen that returned early at
# once would still read "7/7" and its text would never be scanned.
# Nothing may match the P10 regex below (JS \b semantics via (?a)); the storage key "hostile" and
# the operator label "Suspect" are allowed (neither is in the regex).
NTL_P10_RE='(?a)\b(evil[ -]?twin|rogue|attack(er)?|threat|intru(der|sion)|malicious|spoof(ed|ing)?|karma|bandit|target|deauth flood)\b'
ntl_p10file() { # ntl_p10file FILE REGEX -> exit 0 iff no re.I match; prints up to 20 hits with context
  python3 - "$1" "$2" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8", errors="replace").read()
hits = [(m.group(0), t[max(0, m.start() - 40):m.end() + 40].replace("\n", " | ")) for m in re.finditer(sys.argv[2], t, re.I)]
for h, c in hits[:20]: print("    hit: %s  (...%s...)" % (h, c))
sys.exit(1 if hits else 0)
PY
}
# One eval: returns "#grabs tag,tag,…" + the de-duplicated text lines of every grab.
NTL_EVP10='(async()=>{const T0=STARCHORUS.getTheme(),seen=new Set(),tags=[];const add=s=>{for(const l of String(s==null?"":s).split("\n")){const t=l.trim();if(t)seen.add(t)}};const grab=tag=>{tags.push(tag);add(document.body.innerText);const w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,{acceptNode:n=>/^(SCRIPT|STYLE|NOSCRIPT)$/.test(n.parentNode.nodeName)?NodeFilter.FILTER_REJECT:NodeFilter.FILTER_ACCEPT});while(w.nextNode())add(w.currentNode.nodeValue);document.querySelectorAll("[title],[aria-label],[placeholder],[alt],meta[content]").forEach(e=>{for(const a of ["title","aria-label","placeholder","alt","content"])add(e.getAttribute(a))});add(document.title)};const byRssi=(a,b)=>(b.rssi??-999)-(a.rssi??-999)||(a.id<b.id?-1:1);for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await STARCHORUS.wait(50);STARCHORUS.frame();grab(t);const pick=[["ap",STARCHORUS.nodes("ap").sort(byRssi)[0]],["assoc",STARCHORUS.nodes("assoc")[0]],["free",STARCHORUS.nodes("free")[0]],["bubble",STARCHORUS.nodes("bubble")[0]]];for(const [k,n] of pick){if(!n)continue;STARCHORUS.select(n.id);if(k!=="bubble")STARCHORUS.hoverNode(n.id);await STARCHORUS.wait(20);STARCHORUS.frame();grab(t+":"+k);STARCHORUS.hoverNode(null);STARCHORUS.deselect()}const ch=STARCHORUS.channels();for(const b of ["2.4","5","6"])for(const c of Object.keys(ch[b]||{}))add(STARCHORUS.hoverChannel(b,c))}STARCHORUS.setTheme(T0);STARCHORUS.frame();return "#grabs "+tags.join(",")+"\n"+[...seen].join("\n")})()'

NTL_BAD=""; NTL_GR=""
for NTL_RUN in demo:wargames active:whitehall devices:foundation field-probes:whitehall; do
  NTL_FX=${NTL_RUN%%:*}; NTL_TH=${NTL_RUN#*:}
  if [ "$NTL_FX" = demo ]; then NTL_SRC=demo; else NTL_SRC="$F/$NTL_FX.json"; fi
  runq "$NTL_SRC" "?poll=0&spin=0&theme=$NTL_TH" "out/$P-p10-$NTL_FX" --wait 4 --fps 0 \
    --eval "STARCHORUS.skipIntro()" --eval "$NTL_EVP10" >/dev/null 2>&1
  evalv "out/$P-p10-$NTL_FX.json" 2 > "out/$P-p10-$NTL_FX.txt"
  NTL_G=$(sed -n '1s/^#grabs //p' "out/$P-p10-$NTL_FX.txt" | tr ',' '\n' | grep -c .)
  NTL_GR="$NTL_GR $NTL_FX:$NTL_G"
  [ "$NTL_G" -ge 6 ] || NTL_BAD="$NTL_BAD $NTL_FX:vacuous"   # >= 3 themes x (idle + AP)
  ntl_p10file "out/$P-p10-$NTL_FX.txt" "$NTL_P10_RE" || NTL_BAD="$NTL_BAD $NTL_FX:hit"
done
rowif "P10 page text: 0 hits (3 themes; grabs$NTL_GR)" [ -z "$NTL_BAD" ]
[ -z "$NTL_BAD" ] || echo "   $NTL_BAD"

NTL_LG="out/$P-p10-display.txt"; : > "$NTL_LG"
NTL_SCR=""; NTL_SBAD=""
for NTL_PG in starchorus-display.sh library/user/reconnaissance/starchorus/starchorus-display.sh; do
  # the screens this copy defines, and the names its render() dispatches (plus the default branch, screen_summary)
  NTL_DEF=$(sed -n 's/^screen_\([a-z0-9_]*\)() *{.*/\1/p' "$NTL_PG" | LC_ALL=C sort | tr '\n' ' ')
  NTL_DIS=$( { echo summary; awk '/^render\(\) *{/ { r = 1; next } r && /^}/ { r = 0 } r && /"screen_\$1"/ { s = $1; sub(/\).*/, "", s); gsub(/\|/, "\n", s); print s }' "$NTL_PG"; } | LC_ALL=C sort -u | tr '\n' ' ')
  NTL_RUN=0; NTL_SILENT=""; NTL_SD="out/$P-p10-scr"; rm -rf "$NTL_SD"; mkdir -p "$NTL_SD"
  # the summary of every fixture first: the reference a silent fallback to screen_summary would reproduce
  for NTL_FJ in "$F"/*.json; do STARCHORUS_DISPLAY_PLAIN=1 sh "$NTL_PG" --once summary "$NTL_FJ" > "$NTL_SD/sum-${NTL_FJ##*/}" 2>&1; done
  for NTL_S in $NTL_DEF; do
    NTL_NE=0; NTL_DF=0
    for NTL_FJ in "$F"/*.json; do
      if [ "$NTL_S" = summary ]; then cp "$NTL_SD/sum-${NTL_FJ##*/}" "$NTL_SD/one"; NTL_DF=1
      else
        STARCHORUS_DISPLAY_PLAIN=1 sh "$NTL_PG" --once "$NTL_S" "$NTL_FJ" > "$NTL_SD/one" 2>&1
        cmp -s "$NTL_SD/one" "$NTL_SD/sum-${NTL_FJ##*/}" || NTL_DF=1
      fi
      [ -s "$NTL_SD/one" ] && NTL_NE=1
      cat "$NTL_SD/one" >> "$NTL_LG"
    done
    if [ "$NTL_NE" = 1 ] && [ "$NTL_DF" = 1 ]; then NTL_RUN=$((NTL_RUN + 1)); else NTL_SILENT="$NTL_SILENT $NTL_S"; fi
  done
  rm -rf "$NTL_SD"
  NTL_ND=$(echo "$NTL_DEF" | wc -w | tr -d ' ')
  NTL_SCR="$NTL_SCR ${NTL_PG%/*}:$NTL_RUN/$NTL_ND"
  [ "$NTL_RUN" = "$NTL_ND" ] && [ "$NTL_ND" -ge 7 ] && [ "$NTL_DEF" = "$NTL_DIS" ] || NTL_SBAD="$NTL_SBAD $NTL_PG: covered $NTL_RUN (empty or = summary:${NTL_SILENT:- none}), defined [$NTL_DEF], dispatched [$NTL_DIS];"
  grep -v '^[[:space:]]*#' "$NTL_PG" | grep -o '"[^"]*"' >> "$NTL_LG"
done
NTL_LN=$(wc -l < "$NTL_LG" | tr -d ' ')
rowif "P10 display screens covered = screens defined = screens dispatched (covered/defined per copy, covered = output that is not empty and not the summary:$NTL_SCR)" [ -z "$NTL_SBAD" ]
[ -z "$NTL_SBAD" ] || echo "   $NTL_SBAD"
if [ -s "$NTL_LG" ] && ntl_p10file "$NTL_LG" "$NTL_P10_RE"; then
  row "P10 display LOG + literals: 0 hits ($NTL_LN lines)" PASS
else
  row "P10 display LOG + literals: 0 hits ($NTL_LN lines)" FAIL
fi
