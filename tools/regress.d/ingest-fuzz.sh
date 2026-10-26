# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/ingest-fuzz.sh -- foreign or broken documents must not crash the viewer, must not wipe a good display,
# and SSID text (attacker text from the air) must never become markup. Mutants come from tools/fuzz-doc.py (derived, seeded).
# GUARDS AGAINST: a document that makes STARCHORUS.load()/render throw or stall, a rejected one that clears the sky, NaN in the layout, a
#                 poisoned Object.prototype, an unescaped SSID in the tooltip/detail/#source-desc, and the display script echoing SSID text
#                 into a shell (the canary proof has its own positive control: an injectable stand-in must create the file with the very same
#                 payloads, so the proof cannot be void). Anchors: all 7 classes, >= FUZ_MIN_MUTANTS, every sink driven, the masked text FOUND.
#                 Also (section 5b): a place in the page that runs text as code or reaches out of it by a name the sink list above does not hold
#                 (eval(, new Function, Function(, setTimeout or setInterval with a string, setAttribute('on…'), document.write, insertAdjacentHTML,
#                 .outerHTML =, srcdoc, javascript:, an inline on…= attribute in a markup string, import(, postMessage, the word eval as any identifier
#                 (window.eval, (0, eval)(…)), createElement('script') and createContextualFragment, a bracket name such as self["eval"], and the constructor route
#                 ([].constructor.constructor("…")(), also as ["constructor"], which reaches Function without spelling it; since 24 October 2026)): none stands today, one would be red.
# NEGATIVE PROBE: a page copy with `esc = String` (the SSID lands as an <img> in the panel) and with the null-entry skip removed from
#                 normalizeDoc => red; as the standing row "sensor bites" below (copy under out/); an empty mutant list => red.
#                 Generator ignores the seed => row 1 red (payload compared without the seed field); page copies with
#                 `x.innerHTML +=`, insertAdjacentHTML, outerHTML =, document.write, ["innerHTML"] => row "innerHTML sinks" red.
#                 Canary path with spaces and no fallback path => row 1 red (the generator refuses); the same situation with
#                 the refusal switched off => display row red (the positive control creates nothing); control sabotaged (no eval)
#                 => display row red; canary file created before the verdict => display row "CREATED". Relative TMPDIR (out/x)
#                 without the absolute-path check => display row red "control 0 of N" (after the cd the control puts the file
#                 elsewhere), with it a fallback to /tmp and green; a generator copy without the backtick family under a short TMPDIR =>
#                 display row red "2/3 families" (the count alone would stay green, 10 of 15 texts). The zero list of section 5b is read against a
#                 copy of the page with one planted line per word (the row 'page zero list sensor bites'): a word whose expression no longer finds
#                 its own line is red.
# NOT PROVEN:     sinks outside the list below (a new assignment => row red, add a driver); behaviour in real browsers
#                 and on the device (there only the output under jq, never a collector); only ~30 s of observation per run. Limit of the
#                 static ratchet: it does not see sinks whose name is computed at run time (x[a + b] = ...); moreover
#                 every word innerHTML outside // comments is an assignment or red (multi-line, Object.assign). The other ways of running
#                 text as code (eval(, new Function(, setAttribute('on...'), setTimeout or setInterval with a string, javascript:, an inline
#                 on...= attribute in a markup string, import(, postMessage) are in the zero list of section 5b (row 'page zero list'), each
#                 with a planted copy that must be counted; that list reads the text of the page, so it does not see a name that is put together
#                 at run time (`window['ev' + 'al']`), a handler attribute that two strings make (`'<a ' + 'onclick=…'`), or a string that is
#                 handed to a function of the page which later runs it. The canary proof holds for three payloads ($( ), backticks, breaking
#                 out of quotes), not for every shell syntax, and only for the Overview under this machine's shell.
# Sourced by tools/regress.sh with cwd = repo root; two Chrome runs (the drop-in's wall time is in out/PREFIX-timing.txt;
# row names carry no seconds). Only FUZ_* names are set.
# Own directory: one mktemp -d under $TMPDIR (or /tmp; absolute path only), removed at the end of this file; nothing else outside the repo is touched.
# Mutants are only DATA served to the page in headless Chrome against 127.0.0.1; nothing in here sends or executes a mutant.
FUZ_MIN_MUTANTS=600   # python3 -B tools/fuzz-doc.py --summary   (measured: 771 mutants + 3 big = 774); floor about 88 %
FUZ_MIN_ANCHORS=26    # positive anchors the eval found: masked text in tooltip/detail/#source-desc/hint, and the random cloud's tooltip and sheet (measured: 26; the count is deterministic for a given bundle)
FUZ_MIN_DISPLAY=150     # documents the collector could have written that go to the display script (measured: 229)
FUZ_MIN_PAYLOADS=3    # injection texts derived from the bundle (section 4 lists them in out/PREFIX-fuzz-payloads.txt: wc -l; measured: 3 with a long $TMPDIR path, 15 under /tmp (the #n variants of the three families exist only for short paths))
FUZ_INNER_MAX=20      # .innerHTML assignments in the page; raise only together with a driver for the new sink (measured: 20; nine of
                     # them feed the driven and static targets, eleven go into the nine drawer/panel targets below, known open, not driven)
FUZ_SINKS_DRIVEN="detailBody sourceDesc tipBody"   # fed by documents: select / load label + note + drop hint / hoverNode (ingest-fuzz.js)
FUZ_SINKS_STATIC="helpList legendBody tip"         # constant markup (legend rows are also re-checked after every theme switch)
# Known open sinks (target | owner | cause): innerHTML targets that exist in the page but have NO driver in ingest-fuzz.js yet (the
# drawers and panels). Each one must still exist (a gone one is red: "please remove"); any target in none of the three lists is red.
# The fix is a driver per sink in tools/evals/ingest-fuzz.js (open the drawer/panel on an all-text-hostile document, panelBad over its container,
# masked text found), then the name moves to FUZ_SINKS_DRIVEN.
FUZ_SINKS_OPEN="ab=renderAir (Air drawer) ib=renderInv (inventory) hb=renderHome (homing meter) tb=renderTime (time series) rb=renderRec (record drawer) e=recLabel (record position) ob=renderObs (observations) el0=renderTote (Foundation tote card) c=renderCaption (caption)"
# Known open findings (glob on the mutant name | owner | cause). New finding => red; an entry nothing hits => red "please remove".
# A finding is fixed in the page, never here.
FUZ_KNOWN_OPEN='4:top.generated:*e+308|page|generated beyond +-8.64e12 s: setSourcePanel calls new Date(generated*1000).toISOString(), RangeError after ingest already replaced the display, so load() reports an error for a document it took'
FUZ_JS=$(cat "$R/tools/evals/ingest-fuzz.js")
FUZ_Q="?poll=0&spin=0&intro=0&debug=1&fixed=$STARCHORUS_FIXED"
FUZ_RDY="window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'"
# The canary is the file an injected `touch` would create. The payloads carry its path UNQUOTED, and this repo lives under
# ".../Application Support/...": with a space in the path `touch A B/c` splits into several arguments, the file could never appear
# at the expected path and "canary untouched" would stay green whatever the display script does. So the file gets its
# OWN mktemp directory under $TMPDIR (else /tmp) whose path must stay ONE shell word; else the fallback is out/ of the repo, and
# tools/fuzz-doc.py refuses a path that would split (the row is then red). The stand-in in section 4 proves the path works.
FUZ_CD=""
for FUZ_TP in "${TMPDIR:-/tmp}" /tmp; do
  case ${FUZ_TP%/} in /*) ;; *) continue ;; esac   # ABSOLUTE only: section 4 cd's into the directory; a relative
  # TMPDIR (out/x) would pass the word check, the canary path would be relative, and after the cd the control would touch a path that does not exist
  case ${FUZ_TP%/} in *[!A-Za-z0-9_./-]*) continue ;; esac
  FUZ_CD=$(mktemp -d "${FUZ_TP%/}/starchorus-fuzz.XXXXXX" 2>/dev/null) && break
  FUZ_CD=""
done
case $FUZ_CD in *[!A-Za-z0-9_./-]*) rmdir "$FUZ_CD" 2>/dev/null; FUZ_CD="" ;; esac
if [ -n "$FUZ_CD" ]; then FUZ_CAN="$FUZ_CD/canary"; else FUZ_CAN="$R/out/$P-fuzz-canary"; fi

# ---- 1. the generator: deterministic, the seed matters, every class filled, the display set derived
rm -rf "out/$P-fuzz-display" "$FUZ_CAN"
python3 -B tools/fuzz-doc.py --canary "$FUZ_CAN" --out "out/$P-fuzz.json" --emit-dir "out/$P-fuzz-display" > "out/$P-fuzz-gen.txt" 2>&1; FUZ_G1=$?
python3 -B tools/fuzz-doc.py --canary "$FUZ_CAN" --out "out/$P-fuzz2.json" > /dev/null 2>&1; FUZ_G2=$?
python3 -B tools/fuzz-doc.py --canary "$FUZ_CAN" --seed 1 --out "out/$P-fuzz3.json" > /dev/null 2>&1; FUZ_G3=$?
FUZ_SUM=$(python3 -B tools/fuzz-doc.py --canary "$FUZ_CAN" --summary | sed 's/^seed [0-9]*: //')
FUZ_NM=$(python3 -c 'import json,sys; f=json.load(open(sys.argv[1]))["fuzz"]; print(len(f["mutants"])+len(f["big"]))' "out/$P-fuzz.json" 2>/dev/null)
FUZ_NC=$(python3 -c 'import json,sys; c=json.load(open(sys.argv[1]))["fuzz"]["classes"]; print(sum(1 for k in "1234567" if c.get(k,0)>0))' "out/$P-fuzz.json" 2>/dev/null)
# "other seed, other bytes" is judged on the payload (mutants + big) WITHOUT the seed field: the bundle writes its own seed
# into the JSON, so a plain cmp would stay different even if the generator ignored the seed (vacuous)
FUZ_SD=$(python3 -c 'import json,sys
a,b=[json.load(open(f))["fuzz"] for f in sys.argv[1:3]]
print(1 if (a["mutants"],a["big"])!=(b["mutants"],b["big"]) else 0)' "out/$P-fuzz.json" "out/$P-fuzz3.json" 2>/dev/null)
python3 -B tools/fuzz-doc.py --canary "x y/canary" --summary > /dev/null 2>&1; FUZ_G4=$?   # a path that would split must be refused (exit 2)
FUZ_GOK=0
if [ "$FUZ_G1$FUZ_G2$FUZ_G3$FUZ_G4" = 0002 ] && cmp -s "out/$P-fuzz.json" "out/$P-fuzz2.json" && [ "$FUZ_SD" = 1 ] \
   && [ "$FUZ_NC" = 7 ] && ge "${FUZ_NM:-0}" "$FUZ_MIN_MUTANTS"; then FUZ_GOK=1; fi
rowif "fuzz-doc.py: same seed same bytes, other seed other payload, refuses a splitting canary path, $FUZ_NC/7 classes, $FUZ_NM mutants (≥ $FUZ_MIN_MUTANTS)" [ "$FUZ_GOK" = 1 ]
[ "$FUZ_GOK" = 1 ] || echo "    generator rc $FUZ_G1/$FUZ_G2/$FUZ_G3 (want 0/0/0), rc for a path with a space $FUZ_G4 (want 2), seed changes payload: $FUZ_SD, canary $FUZ_CAN, $FUZ_SUM"

# ---- 2. the run: main (every mutant, 2D then 3D, the sinks) and big (class 7 alone, explicit timeout: a hang only hits it)
runq "out/$P-fuzz.json" "$FUZ_Q" "out/$P-fuzz" --wait 2 --fps 0 --ready "$FUZ_RDY" --eval-timeout 120 \
  --eval "$FUZ_JS(\"main\")" --eval "$FUZ_JS(\"big\")" > "out/$P-fuzz.txt" 2>&1; FUZ_RC=$?
printf '%s\n' "$FUZ_KNOWN_OPEN" > "out/$P-fuzz-open.txt"
FUZ_V=$(fuzz_verdict "out/$P-fuzz.json" run "$FUZ_MIN_MUTANTS" "$FUZ_MIN_ANCHORS" "out/$P-fuzz-open.txt"); FUZ_VC=$?
tm_note "eval ingest-fuzz main+big" "$(report_secs "out/$P-fuzz.json" 2)"   # the evals' own clock: timing file, not the row name
FUZ_OK=0; [ "$FUZ_VC" = 0 ] && [ "$FUZ_RC" = 0 ] && FUZ_OK=1
rowif "ingest fuzz: $FUZ_V" [ "$FUZ_OK" = 1 ]
[ "$FUZ_OK" = 1 ] || { echo "    driver exit $FUZ_RC"; python3 - "out/$P-fuzz.json" <<'PYEND'
import json, sys
try: ev = json.load(open(sys.argv[1])).get("eval") or []
except Exception as e: ev = []; print("    no report: %s" % e)
for e in ev:
    try: r = json.loads(e["value"])
    except Exception: print("    eval gave: %s" % str(e.get("value"))[:200]); continue
    for n, w in (r.get("findings") or [])[:12]: print("    finding %s: %s" % (n[:60], w[:120]))
PYEND
}

# ---- 3. the sensor bites: the same machinery against a page copy with the two faults planted must be RED for exactly those.
# Fair by construction: both target lines exist once, the copy differs from the page in exactly them, and it boots without
# errors (any third finding fails the row). The copy is only served to headless Chrome on 127.0.0.1; nothing in it sends.
FUZ_E=$(grep -c '^const esc = (s) => String(s)\.replace' "$H"); FUZ_N=$(grep -c 'if (!isObj(a)) return;' "$H")
FUZ_PG="out/$P-fuzz-probe.html"
sed 's/^const esc = (s) => String(s)\.replace.*$/const esc = (s) => String(s);/' "$H" | sed 's/if (!isObj(a)) return;//' > "$FUZ_PG"
FUZ_D=$(diff "$H" "$FUZ_PG" | grep -c '^<')
python3 -B tools/fuzz-doc.py --classes 3,6 --canary "$FUZ_CAN" --out "out/$P-fuzz-probe.json" > /dev/null 2>&1
FUZ_HKEEP=$H; H=$FUZ_PG   # runq serves $H: point it at the copy for this one call, then put it back
runq "out/$P-fuzz-probe.json" "$FUZ_Q" "out/$P-fuzz-probe" --wait 2 --fps 0 --ready "$FUZ_RDY" --eval-timeout 120 \
  --eval "$FUZ_JS(\"main\")" --eval "$FUZ_JS(\"big\")" > "out/$P-fuzz-probe.txt" 2>&1
H=$FUZ_HKEEP
FUZ_PV=$(fuzz_verdict "out/$P-fuzz-probe.json" probe 0 0 -); FUZ_PC=$?
FUZ_POK=0; [ "$FUZ_E" = 1 ] && [ "$FUZ_N" = 1 ] && [ "$FUZ_D" = 2 ] && [ "$FUZ_PC" = 0 ] && FUZ_POK=1
rowif "ingest fuzz sensor bites: page with esc=String and no null-skip is RED, $FUZ_PV" [ "$FUZ_POK" = 1 ]

# ---- 3b. text from the air that cannot be shown (0.2.5): an SSID made of letters with C1 controls, zero-width characters, direction marks and overrides (U+202E among them), embeddings, isolates, the invisible
# operators and U+FEFF between them is stored and drawn WITHOUT them: the node's text is the letters alone, and neither the tooltip nor the detail sheet (the DOM text is read) holds one of those characters
# and both hold the letters. Ordinary text next to them is NOT touched (positive term): a second SSID of accented Latin, CJK, Greek, Hebrew, Arabic, a no-break space and an emoji comes out of the page unchanged (node and tooltip), on the page and on the old-expression copy alike. The tooltip and the sheet are the sinks the earlier expression `[\x00-\x1f\x7f]` let the overrides through. The page's one expression is pinned to the line, and a copy of the page with the
# earlier expression must be RED on the same run (fair: the copy differs from the page in that one line, and it boots without an error)
FUZ_CTLJS='(()=>{const BAD=/[\x7f-\x9f\u200b-\u200f\u202a-\u202e\u2060-\u2069\ufeff]/;
const raw="A\u202eB\u200bC\u0085D\u200fE\u2066F\u2069G\ufeffH\u2060I\u202aJ\u202dK\u2064L\u0090M\u007fN\u200cO\u2065P",want="ABCDEFGHIJKLMNOP";
const id="02:00:00:00:0c:01",id2="02:00:00:00:0c:02",o={};
const legit="Caf\u00e9 \u65e5\u672c\u8a9e \u0395\u03bb\u03ac\u03b4\u03b1 \u05e9\u05dc \u0645\u0631 \ud83d\ude00 a\u00a0b";   /* 27 UTF-16 units: inside the 32 an SSID may have */
const doc=(g)=>({source:"recon-db",generated:g,aps:[{bssid:id,ssid:raw,band:"2.4",channel:6,freq:2437,rssi:-50,security:"WPA2"},{bssid:id2,ssid:legit,band:"5",channel:36,freq:5180,rssi:-60,security:"WPA2"}],unassociated:[]});
STARCHORUS.load(doc(100),"ctl");STARCHORUS.load(doc(105),"ctl");   /* two captures: the observation needs its dwell */
o.err=STARCHORUS.errors().length;
const ap=JSON.parse(STARCHORUS.exportText("json")).aps.find(a=>a.bssid===id);o.node=ap?ap.ssid:null;
STARCHORUS.hoverNode(id);const tip=document.getElementById("tip").innerText;STARCHORUS.hoverNode(null);
STARCHORUS.select(id);const det=document.getElementById("detail-title").innerText+"\n"+document.getElementById("detail-body").innerText;STARCHORUS.deselect();
const ap2=JSON.parse(STARCHORUS.exportText("json")).aps.find(a=>a.bssid===id2);o.legitOk=!!ap2&&ap2.ssid===legit;
STARCHORUS.hoverNode(id2);o.legitTip=document.getElementById("tip").innerText.indexOf(legit.replace(/\u00a0/g," "))>=0||document.getElementById("tip").innerText.indexOf(legit)>=0;STARCHORUS.hoverNode(null);
o.nodeOk=o.node===want;o.tipHas=tip.indexOf(want)>=0;o.tipBad=BAD.test(tip);o.detHas=det.indexOf(want)>=0;o.detBad=BAD.test(det);
/* the trick is told: tooltip and detail of the stripped name say so, the observations count it, the legitimate name carries no such mark */
o.tipMark=tip.indexOf("invisible characters removed")>=0;o.detMark=det.indexOf("invisible characters removed")>=0;
o.obsMark=STARCHORUS.observations().some(x=>x.group==="Look-alike"&&/1 SSID\(s\) carried invisible characters \(removed\)/.test(x.text));
STARCHORUS.hoverNode(id2);o.legitNoMark=document.getElementById("tip").innerText.indexOf("invisible characters")<0;STARCHORUS.hoverNode(null);
delete o.node;return JSON.stringify(o)})()'
FUZ_CQ="?poll=0&spin=0&intro=0&debug=1"
runq demo "$FUZ_CQ" "out/$P-fuzz-ctl" --wait 2 --fps 0 --ready --eval-timeout 90 --eval "$FUZ_CTLJS" >/dev/null 2>&1
FUZ_CV=$(evalv "out/$P-fuzz-ctl.json" 1)
FUZ_NEWC='[\x00-\x1f\x7f-\x9f'
for FUZ_r in 200b:200f 202a:202e 2060:2069; do FUZ_NEWC="$FUZ_NEWC"'\u'"${FUZ_r%:*}"'-\u'"${FUZ_r#*:}"; done
FUZ_NEWC="$FUZ_NEWC"'\u'"feff]"
FUZ_OLDC='[\x00-\x1f\x7f]'
FUZ_CN=$(grep -cF "String(x).replace(/$FUZ_NEWC/g," "$H")
FUZ_CPG="out/$P-fuzz-ctl-old.html"
FUZ_A=$FUZ_NEWC FUZ_B=$FUZ_OLDC awk '{ i = index($0, ENVIRON["FUZ_A"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["FUZ_B"] substr($0, i + length(ENVIRON["FUZ_A"])) } { print }' "$H" > "$FUZ_CPG"
FUZ_CD2=$(diff "$H" "$FUZ_CPG" | grep -c '^<')
FUZ_HKEEP=$H; H=$FUZ_CPG
runq demo "$FUZ_CQ" "out/$P-fuzz-ctl-old" --wait 2 --fps 0 --ready --eval-timeout 90 --eval "$FUZ_CTLJS" >/dev/null 2>&1
H=$FUZ_HKEEP
FUZ_CO=$(evalv "out/$P-fuzz-ctl-old.json" 1)
FUZ_CWANT='{"err":0,"legitOk":true,"legitTip":true,"nodeOk":true,"tipHas":true,"tipBad":false,"detHas":true,"detBad":false,"tipMark":true,"detMark":true,"obsMark":true,"legitNoMark":true}'
FUZ_OOK=0; [ "$FUZ_CV" = "$FUZ_CWANT" ] && [ "$FUZ_CN" = 1 ] && FUZ_OOK=1
rowif "ingest fuzz: an SSID with C1 controls, zero-width characters, direction marks, U+202E and the other overrides, isolates and U+FEFF is stored and drawn without them (node, tooltip and detail sheet read as DOM text), and says so: tooltip, detail row and an observation name the removal, the legitimate name beside it carries no mark; the page holds the one expression once [$FUZ_CV]" [ "$FUZ_OOK" = 1 ]
FUZ_BK=0
case $FUZ_CO in '{"err":0,"legitOk":true,"legitTip":true,"nodeOk":false,"tipHas":false,"tipBad":true,"detHas":false,"detBad":true,"tipMark":true,"detMark":true,"obsMark":true,"legitNoMark":true}') FUZ_BK=1 ;; esac   # the old class still drops U+007F, so the marks stand there too
[ "$FUZ_CD2" = 1 ] || FUZ_BK=0
rowif "ingest fuzz sensor bites: a page copy with the earlier expression [\\x00-\\x1f\\x7f] (differs in $FUZ_CD2 line) draws the overrides and the zero-width characters: RED [$FUZ_CO]" [ "$FUZ_BK" = 1 ]
[ "$FUZ_POK" = 1 ] || echo "    target lines esc $FUZ_E, null-skip $FUZ_N, changed lines $FUZ_D"

# ---- 4. the display script under real jq: the hostile SSID texts (only those the collector could have written) never break a screen,
# never become a command, and `top` prints one line per AP (at most 8).
# Positive control first, so that "the canary stays away" can only be read as "the display script did not run the text": the injection texts are
# DERIVED from the bundle (every string that names the canary after a touch) and handed to a stand-in that is injectable on purpose,
# `sh -c 'eval "echo \"$1\""'` (no display script, nothing of the project; it runs in the own directory). Each text must create the canary.
# One that does not (a path that splits, a text that stopped being one) makes the proof void: the row is RED. Read out/$P-fuzz2.json,
# not the bundle out/$P-fuzz.json: runq overwrites that one with its report; the other has the same bytes (row 1 says so).
python3 -B - "out/$P-fuzz2.json" > "out/$P-fuzz-payloads.txt" 2>/dev/null <<'PYEND'
import json, sys
f = json.load(open(sys.argv[1]))["fuzz"]
seen = []
def walk(x):
    if isinstance(x, str):
        if "touch " + f["canary"] in x and x not in seen: seen.append(x)
    elif isinstance(x, dict):
        for k, v in x.items(): walk(k); walk(v)
    elif isinstance(x, list):
        for v in x: walk(v)
walk(f["mutants"]); walk(f["big"])
for t in seen: print(t)
PYEND
FUZ_CN=0; FUZ_CH=0
while IFS= read -r FUZ_PL; do
  FUZ_CN=$((FUZ_CN + 1)); rm -f "$FUZ_CAN"
  # shellcheck disable=SC2016   # the single quotes are the point: the inner shell expands $1, the outer one must not
  (cd "${FUZ_CD:-$R/out}" && sh -c 'eval "echo \"$1\""' sh "$FUZ_PL" > /dev/null 2>&1)
  [ -e "$FUZ_CAN" ] && FUZ_CH=$((FUZ_CH + 1))
  rm -f "$FUZ_CAN"
done < "out/$P-fuzz-payloads.txt"
# the three payload families of tools/fuzz-doc.py (`$(touch …)`, backticks, `";touch …;"`) are pinned ONE BY ONE:
# under a short $TMPDIR the #n variants make FUZ_CN >= 3 even with a whole family gone, so the count alone proved nothing
# shellcheck disable=SC2016   # the literal `$(` is the family marker, nothing is meant to expand
FUZ_F1=$(grep -c '^\$(touch ' "out/$P-fuzz-payloads.txt"); FUZ_F2=$(grep -c '^`touch ' "out/$P-fuzz-payloads.txt"); FUZ_F3=$(grep -c '^";touch ' "out/$P-fuzz-payloads.txt")
FUZ_FAM=$(( (FUZ_F1 > 0) + (FUZ_F2 > 0) + (FUZ_F3 > 0) ))
FUZ_CTL=0; ge "$FUZ_CN" "$FUZ_MIN_PAYLOADS" && [ "$FUZ_FAM" = 3 ] && [ "$FUZ_CH" = "$FUZ_CN" ] && FUZ_CTL=1
FUZ_PN=0; FUZ_PB=0; FUZ_PF=0; FUZ_PE=0
# every other screen the display script defines (its screen_NAME() functions, not a typed list: a typed list misses a screen that is
# added later); at least six besides top
FUZ_SCR=$(sed -n 's/^screen_\([a-z0-9_]*\)() *{.*/\1/p' "$R/starchorus-display.sh" | grep -vx top | LC_ALL=C sort | tr '\n' ' ')
FUZ_NSCR=$(echo "$FUZ_SCR" | wc -w | tr -d ' ')
for FUZ_F in "out/$P-fuzz-display"/*.json; do
  [ -f "$FUZ_F" ] || continue
  FUZ_PN=$((FUZ_PN + 1))
  FUZ_O=$(STARCHORUS_DISPLAY_PLAIN=1 sh "$R/starchorus-display.sh" --once top "$FUZ_F" 2>&1); FUZ_X=$?
  FUZ_W=$(jq '.aps | length' "$FUZ_F"); [ "$FUZ_W" -le 8 ] || FUZ_W=8
  FUZ_L=$(printf '%s\n' "$FUZ_O" | wc -l | tr -d ' ')
  if [ "$FUZ_X" != 0 ] || [ "$FUZ_L" != $((FUZ_W + 1)) ]; then FUZ_PB=$((FUZ_PB + 1)); echo "    display top $FUZ_F: exit $FUZ_X, $((FUZ_L - 1)) lines, want $FUZ_W"; fi
  printf '%s\n' "$FUZ_O" | grep -q 'touch ' && FUZ_PE=$((FUZ_PE + 1))
  case "$FUZ_F" in *a.json | *-c5.json)   # the anchor documents and the prototype/duplicate ones: every other screen too
    for FUZ_S in $FUZ_SCR; do
      STARCHORUS_DISPLAY_PLAIN=1 sh "$R/starchorus-display.sh" --once "$FUZ_S" "$FUZ_F" > /dev/null 2>&1 || { FUZ_PB=$((FUZ_PB + 1)); echo "    display $FUZ_S $FUZ_F: exit != 0"; }
      FUZ_PF=$((FUZ_PF + 1))
    done ;;
  esac
done
FUZ_PT=$(grep -l 'touch ' "out/$P-fuzz-display"/*.json 2>/dev/null | wc -l | tr -d ' ')
FUZ_PK=0; ge "$FUZ_NSCR" 6 && [ "$FUZ_PB" = 0 ] && [ ! -e "$FUZ_CAN" ] && [ "$FUZ_CTL" = 1 ] && ge "$FUZ_PN" "$FUZ_MIN_DISPLAY" && ge "$FUZ_PT" 1 && ge "$FUZ_PE" 1 && FUZ_PK=1
rowif "display vs hostile SSIDs: $FUZ_PN documents (≥ $FUZ_MIN_DISPLAY) + $FUZ_PF extra screen runs ($FUZ_NSCR screens besides top: ${FUZ_SCR% }), exit 0, one line per AP, canary $([ -e "$FUZ_CAN" ] && echo CREATED || echo untouched) (injectable stand-in creates it with $FUZ_CH of $FUZ_CN texts, ≥ $FUZ_MIN_PAYLOADS, $FUZ_FAM/3 families), echoed as text in $FUZ_PE of $FUZ_PT" [ "$FUZ_PK" = 1 ]
[ "$FUZ_PK" = 1 ] || echo "    canary $FUZ_CAN, control $FUZ_CH of $FUZ_CN texts, families \$( ) $FUZ_F1 / backticks $FUZ_F2 / \";…;\" $FUZ_F3 (each ≥ 1; a control that creates nothing means the canary proof is void: a path that splits, or a text that is no injection any more)"

# ---- 5. static: the HTML-parsing sinks of the page. A new innerHTML assignment (= or +=) is a new sink: it needs a driver in
# tools/evals/ingest-fuzz.js first. Every other way to parse markup (insertAdjacentHTML, outerHTML =, document.write, srcdoc,
# createContextualFragment, setHTMLUnsafe, DOMParser, bracket form) is not driven at all: none may exist (measured: 0).
FUZ_IRE='[A-Za-z0-9_]*\.innerHTML *\+?=[^=]'   # digits too: `el0.innerHTML` must not be read as an empty target
FUZ_IN=$(grep -oE "$FUZ_IRE" "$H" | wc -l | tr -d ' ')
FUZ_IT=$(grep -oE "$FUZ_IRE" "$H" | sed 's/\.innerHTML.*//' | LC_ALL=C sort -u | tr '\n' ' ')
FUZ_OFN=$(printf '%s\n' "$FUZ_SINKS_OPEN" | grep -oE '(^| )[A-Za-z0-9_]+=' | tr -d ' =' | LC_ALL=C sort -u | tr '\n' ' ')
FUZ_IW=$(printf '%s %s %s\n' "$FUZ_SINKS_DRIVEN" "$FUZ_SINKS_STATIC" "$FUZ_OFN" | tr ' ' '\n' | grep . | LC_ALL=C sort -u | tr '\n' ' ')
FUZ_IX=$(grep -oE 'insertAdjacentHTML|outerHTML|document\.write|srcdoc|createContextualFragment|setHTMLUnsafe|parseFromString|\[ *["'"'"']innerHTML|["'"'"']inner["'"'"'] *\+' "$H" | wc -l | tr -d ' ')
FUZ_IWD=$(sed 's#//.*##' "$H" | grep -o 'innerHTML' | wc -l | tr -d ' ')   # every word, also the multi-line and Object.assign forms
FUZ_IK=0; ge "$FUZ_IN" 1 && le "$FUZ_IN" "$FUZ_INNER_MAX" && [ "$FUZ_IT" = "$FUZ_IW" ] && [ "$FUZ_IX" = 0 ] && [ "$FUZ_IWD" = "$FUZ_IN" ] && FUZ_IK=1
rowif "innerHTML sinks: $FUZ_IN assignments (1..$FUZ_INNER_MAX) into {${FUZ_IT% }} = driven + static + known-open lists (open, not driven: ${FUZ_OFN% }), $FUZ_IWD words outside comments, $FUZ_IX other markup sinks (want 0)" [ "$FUZ_IK" = 1 ]
[ "$FUZ_IK" = 1 ] || echo "    innerHTML words outside comments: $FUZ_IWD, assignments: $FUZ_IN (a word that is no plain assignment: multi-line, Object.assign, a read: look at it)"
[ "$FUZ_IK" = 1 ] || echo "    lists: {${FUZ_IW% }} (a target that is new needs a driver in tools/evals/ingest-fuzz.js, then FUZ_SINKS_DRIVEN; one that is gone, also from FUZ_SINKS_OPEN: remove it); other sinks $FUZ_IX"

# ---- 5b. the page's zero list: the ways of running text as code, or of reaching out of the page, that no part of the page uses today (measured: 0 each).
# One word per line (name, extended regular expression, a line that has it); every count on the page must be 0, and the same count on a copy of the page with that
# one line planted must be 1: a regular expression that went blind (a typo, a boundary that excludes the line) is red, not green. A line is counted wherever it
# stands (comments and strings too: a word in a comment is a word to read). The copies are plain text; nothing in them is run.
FUZ_ZQ="[\"'\`]"
FUZ_ZT=$(printf '\t')
cat > "out/$P-fuzz-zero.txt" <<ZEND
eval(	(^|[^A-Za-z0-9_.\$])eval[[:space:]]*\(	var zz = eval("1");
new Function	(^|[^A-Za-z0-9_\$])new[[:space:]]+Function	var zz = new Function("return 1");
Function(	(^|[^A-Za-z0-9_\$])Function[[:space:]]*\(	var zz = Function("return 1")();
setTimeout string	setTimeout[[:space:]]*\([[:space:]]*$FUZ_ZQ	setTimeout("zz()", 1);
setInterval string	setInterval[[:space:]]*\([[:space:]]*$FUZ_ZQ	setInterval("zz()", 1);
setAttribute on	setAttribute[[:space:]]*\([[:space:]]*${FUZ_ZQ}[oO][nN]	zz.setAttribute("onclick", "zz()");
document.write	document\.write	document.write("zz");
insertAdjacentHTML	insertAdjacentHTML	zz.insertAdjacentHTML("beforeend", "zz");
.outerHTML =	\.outerHTML[[:space:]]*=[^=]	zz.outerHTML = "zz";
srcdoc	srcdoc	zz.srcdoc = "zz";
javascript:	javascript:	var zz = "javascript:zz()";
inline on...=	<[A-Za-z][^<>]*[[:space:]][oO][nN][a-zA-Z]+[[:space:]]*=	var zz = '<a onclick="zz()">x</a>';
import(	(^|[^A-Za-z0-9_\$.])import[[:space:]]*\(	var zz = import("zz.js");
postMessage	postMessage	window.postMessage("zz", "*");
eval identifier	(^|[^A-Za-z0-9_\$])eval([^A-Za-z0-9_\$]|\$)	var zz = (0, eval)("1");
eval member	(^|[^A-Za-z0-9_\$])eval([^A-Za-z0-9_\$]|\$)	var zz = window.eval("1");
createElement script	createElement[[:space:]]*\([[:space:]]*${FUZ_ZQ}[sS][cC][rR][iI][pP][tT]	var zz = document.createElement("script");
createContextualFragment	createContextualFragment	var zz = document.createRange().createContextualFragment("zz");
bracket name	\[[[:space:]]*${FUZ_ZQ}(eval|Function|write|writeln|setTimeout|setInterval|postMessage)${FUZ_ZQ}[[:space:]]*\]	var zz = self["eval"]("1");
constructor call	\.constructor[[:space:]]*\(	var zz = [].constructor.constructor("return 1")();
constructor bracket	\[[[:space:]]*${FUZ_ZQ}constructor${FUZ_ZQ}[[:space:]]*\]	var zz = []["constructor"]["constructor"]("return 1")();
ZEND
FUZ_ZN=0; FUZ_ZH=0; FUZ_ZB=0; FUZ_ZP=0; FUZ_ZL=""
while IFS="$FUZ_ZT" read -r FUZ_ZW FUZ_ZR FUZ_ZLN; do
  FUZ_ZN=$((FUZ_ZN + 1))
  FUZ_ZC=$(grep -cE "$FUZ_ZR" "$H"); FUZ_ZH=$((FUZ_ZH + FUZ_ZC))
  [ "$FUZ_ZC" = 0 ] || FUZ_ZL="$FUZ_ZL [$FUZ_ZW: $FUZ_ZC]"
  { cat "$H"; printf '%s\n' "$FUZ_ZLN"; } > "out/$P-fuzz-zero.html"
  FUZ_ZC=$(grep -cE "$FUZ_ZR" "out/$P-fuzz-zero.html")
  if [ "$FUZ_ZC" = 1 ]; then FUZ_ZP=$((FUZ_ZP + 1)); else FUZ_ZB=$((FUZ_ZB + 1)); echo "    zero list sensor: a page with the line '$FUZ_ZLN' counts $FUZ_ZC for $FUZ_ZW (want 1)"; fi
done < "out/$P-fuzz-zero.txt"
rm -f "out/$P-fuzz-zero.html"
FUZ_ZOK=0; [ "$FUZ_ZH" = 0 ] && ge "$FUZ_ZN" 21 && FUZ_ZOK=1
rowif "page zero list: $FUZ_ZN words (eval(, new Function, Function(, setTimeout and setInterval with a string, setAttribute on…, document.write, insertAdjacentHTML, .outerHTML =, srcdoc, javascript:, inline on…=, import(, postMessage, eval as any identifier (window.eval, (0, eval)), createElement('script'), createContextualFragment, a bracket name, the constructor route), $FUZ_ZH lines hold one (want 0)" [ "$FUZ_ZOK" = 1 ]
[ "$FUZ_ZOK" = 1 ] || echo "    lines per word:${FUZ_ZL:- none}  (the page runs no text as code and posts no message; a new place needs a driver and a reason, then this list)"
FUZ_ZSOK=0; [ "$FUZ_ZP" = "$FUZ_ZN" ] && [ "$FUZ_ZB" = 0 ] && ge "$FUZ_ZN" 21 && FUZ_ZSOK=1
rowif "page zero list sensor bites: a page with one planted line per word is counted $FUZ_ZP of $FUZ_ZN times (want all, exactly once)" [ "$FUZ_ZSOK" = 1 ]

# ---- 6. clean up: the own canary directory (only what mktemp made above; the pattern keeps a broken variable away from anything else)
case $FUZ_CD in */starchorus-fuzz.??????) rm -rf "$FUZ_CD" ;; esac
