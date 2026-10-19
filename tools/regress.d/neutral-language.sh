# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/neutral-language.sh -- P10 neutral language (spec §14.5 P10), machine-checked. Sourced by
# tools/regress.sh with cwd = repo root, after the core rows. Only NTL_* globals and ntl_* functions.
#
# Page: document.body.innerText + every text node (hidden panels too: help, detail, tooltip, paste
# box, logon, banners) + title/aria-label/placeholder/alt/meta content + document.title, in all
# three themes -- idle, and with detail panel + tooltip open on the strongest AP, an associated
# client, a free client and a bubble (when present) -- plus the chanbar tooltip text of every
# occupied channel; fixtures demo, active, devices, field-probes and alerts (start themes cover both logons; alerts: the legend row and the alert notes).
# Display script: LOG of both starchorus-display.sh copies (--once, EVERY screen x every fixture) plus every "…"
# literal of the scripts (menu, spinner and dialog texts that --once never prints). The screen list is read
# from each script (its screen_NAME() functions), not typed here: a typed list would silently miss a screen added
# later (the display script has 8 screens). Vacuity guard: screens that produced output == screens defined, and render()
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
for NTL_RUN in demo:wargames active:whitehall devices:foundation field-probes:whitehall alerts:wargames; do
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

# ---- probe wording (v0.2): the collector drops wildcard probes at every source, so the JSON cannot know of one: 'broadcast probe' is never written, a station
# reads 'named probe: a' / 'named probes: a, b' / 'no named probe heard'. Page source and rendered text above, both Overview copies and their LOG.
# The bare words 'named probe' also stand in 'No named probe heard.' and in the legend line, so a source substring proves nothing about the
# per-station wording: the page is grepped for the two phrases with their tail ('named probe: ', 'named probes: '), and each Overview copy is
# RUN (probes and clients screens on field-probes.json, the probes screen on a fixture without a probe) and its output must carry the
# header 'N client(s) with a named probe:', a line '  named: <SSID>  (xN)', a Stations line that ends in 'named probe', and 'No named probe heard.'.
NTL_BPN=0; NTL_NP=0; NTL_NN=0; NTL_OVOK=0; NTL_OVBAD=""; NTL_I=0
grep -q 'named probe: ' starchorus.html && grep -q 'named probes: ' starchorus.html && NTL_NP=1
grep -qi 'no named probe heard' starchorus.html && NTL_NN=1
NTL_OVD="out/$P-ntl-ov"; rm -rf "$NTL_OVD"; mkdir -p "$NTL_OVD"
for NTL_PG in starchorus.html starchorus-display.sh library/user/reconnaissance/starchorus/starchorus-display.sh; do
  NTL_BPN=$((NTL_BPN + $(grep -ci 'broadcast probe' "$NTL_PG")))
done
for NTL_PG in starchorus-display.sh library/user/reconnaissance/starchorus/starchorus-display.sh; do
  NTL_I=$((NTL_I + 1)); NTL_M=""
  STARCHORUS_DISPLAY_PLAIN=1 sh "$NTL_PG" --once probes "$F/field-probes.json" > "$NTL_OVD/probes-$NTL_I.txt" 2>&1
  STARCHORUS_DISPLAY_PLAIN=1 sh "$NTL_PG" --once clients "$F/field-probes.json" > "$NTL_OVD/clients-$NTL_I.txt" 2>&1
  STARCHORUS_DISPLAY_PLAIN=1 sh "$NTL_PG" --once probes "$F/single-ap.json" > "$NTL_OVD/none-$NTL_I.txt" 2>&1
  grep -Eq '^[0-9]+ client\(s\) with a named probe:$' "$NTL_OVD/probes-$NTL_I.txt" || NTL_M="$NTL_M header"
  grep -Eq '^  named: .+  \(x[0-9]+\)$' "$NTL_OVD/probes-$NTL_I.txt" || NTL_M="$NTL_M named-line"
  grep -Eq '^-?[0-9]+ dBm  [^ ]+  named probe$' "$NTL_OVD/clients-$NTL_I.txt" || NTL_M="$NTL_M stations-tag"
  grep -qx 'No named probe heard\.' "$NTL_OVD/none-$NTL_I.txt" || NTL_M="$NTL_M none-line"
  NTL_BPN=$((NTL_BPN + $(cat "$NTL_OVD/probes-$NTL_I.txt" "$NTL_OVD/clients-$NTL_I.txt" "$NTL_OVD/none-$NTL_I.txt" | grep -ci 'broadcast probe')))
  if [ -z "$NTL_M" ]; then NTL_OVOK=$((NTL_OVOK + 1)); else NTL_OVBAD="$NTL_OVBAD copy$NTL_I:$NTL_M;"; fi
done
for NTL_FX in demo active devices field-probes; do NTL_BPN=$((NTL_BPN + $(grep -ci 'broadcast probe' "out/$P-p10-$NTL_FX.txt"))); done
NTL_BPN=$((NTL_BPN + $(grep -ci 'broadcast probe' "$NTL_LG")))
rowif "probe wording: 'broadcast probe' $NTL_BPN times in the page, its rendered text, both Overview copies and their LOG (0 wanted); page has 'named probe: ' and 'named probes: ' $NTL_NP/1 and 'no named probe heard' $NTL_NN/1; Overview copies whose probes and Stations screens read 'named' / 'named probe' and say 'No named probe heard.' $NTL_OVOK/2" [ "$NTL_BPN/$NTL_NP/$NTL_NN/$NTL_OVOK" = 0/1/1/2 ]
[ -z "$NTL_OVBAD" ] || echo "   missing in the rendered Overview:$NTL_OVBAD"
NTL_EVW='(async()=>{
const st=(n,pr)=>Object.assign({mac:"3c:22:fb:00:06:0"+n,rssi:-60},pr?{probes:pr}:{});
STARCHORUS.load({source:"recon-db",generated:1789300000,aps:[{bssid:"02:00:00:00:06:01",ssid:"Home",band:"5",channel:36,rssi:-50,security:"WPA2"}],unassociated:[st(1,["Cafe"]),st(2,["Cafe","Lab-Net"]),st(3)]},"probes");
await STARCHORUS.wait(600);const o=[],g=(id)=>(document.getElementById(id).innerText.match(/Probes\s*([^\n]*)/)||[])[1];
for(let i=1;i<=3;i++){const id="3c:22:fb:00:06:0"+i;STARCHORUS.hoverNode(id);const t=g("tip-body");STARCHORUS.hoverNode(null);STARCHORUS.select(id);o.push(t+" | "+g("detail-body"));}
STARCHORUS.deselect();return JSON.stringify(o);})()'
runq demo "?poll=0&spin=0&intro=0&debug=1" "out/$P-ntl-probes" --wait 2 --fps 0 --eval "$NTL_EVW" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
NTL_W=$(evalv "out/$P-ntl-probes.json" 1); NTL_WE=$(evalv "out/$P-ntl-probes.json" 2)
NTL_WW='["named probe: Cafe | named probe: Cafe (heard probe requests, rx only)","named probes: Cafe, Lab-Net | named probes: Cafe, Lab-Net (heard probe requests, rx only)","no named probe heard | no named probe heard"]'
if [ "$NTL_W" = "$NTL_WW" ] && [ "$NTL_WE" = 0 ]; then row "probe wording on the page: tooltip and detail of a station with one probe, with two, and with none" PASS
else row "probe wording on the page (err ${NTL_WE:-?})" FAIL; echo "    got:  $NTL_W"; echo "    want: $NTL_WW"; fi
