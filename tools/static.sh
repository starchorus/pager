#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/static.sh -- the Chrome-free rows of tools/regress.sh, in ONE place. SOURCE it, do not run it.
# Sourced by tools/regress.sh (T2, before the Chrome rows) and by tools/quick.sh (T1, the pre-commit hook): one source of
# these rules, no second rule set. It needs harness.sh sourced, cwd = repo root ($R) and $P set (prefix of out/ files).
# It defines row/rowif/g/le/ge/secs and the baselines and floors (BASE_*, MIN_*), prints the environment lines, then the
# rows. `fail` is reset here and read by the caller afterwards (exit $fail).
#   STATIC_SELFTEST=0   do not run the collector selftest (about 20 s, T2 only); the judge on dummies still runs.
#   QUICK_DROPINS       the drop-ins tools/quick.sh adds (each must be Chrome-free: a row below counts runq/cdp.py/verify.sh).
# No `git` here: the pre-commit hook runs this on an export of the index, where there is no .git (find and globs only).
# The numbers embedded in row names are measurements and may differ from run to run.
# Dev machine only (POSIX sh + python3); nothing here runs on the device or sends anything.
# shellcheck source-path=SCRIPTDIR source=harness.sh
# shellcheck disable=SC2034   # names read by the sourcing script (regress.sh/quick.sh) and by the drop-ins
fail=0
ncov=0   # rows reported NOT COVERED (a deliberate switch such as ALLOW_NO_SQLITE=1): not a PASS, not a FAIL, counted and announced
row() { printf '%-44s %s\n' "$1" "$2"; [ "$2" = PASS ] || fail=1; }
notcov() { printf '%-44s %s\n' "$1" "NOT COVERED"; ncov=$((ncov + 1)); }
rowif() { _n=$1; shift; if "$@"; then row "$_n" PASS; else row "$_n" FAIL; fi; }
g() { grep -c "$1" "$H"; }
le() { [ "$1" -le "$2" ] 2>/dev/null; }   # false (not an error) when a count is "NOSLICE", i.e. its section anchor broke
ge() { [ "$1" -ge "$2" ] 2>/dev/null; }
secs() { while IFS= read -r _l; do secof "$_l"; done; }   # line numbers on stdin → section numbers

# ---- environment: printed before the rows, compared with tools/env-expected.txt. A difference is a HINT (a red row may
# then be the machine, not the code), never a FAIL. Keys: shellcheck python3 jq sqlite3 chrome os.
env_report() {   # env_report OUTFILE  -> writes "key value" lines, prints them with an "env: " prefix and the diff hint
  _en_c=$(python3 -B -c 'import sys; sys.path.insert(0, sys.argv[1]); import cdp; print(cdp.find_chrome())' "$R/tools" 2>/dev/null)
  {
    printf 'shellcheck %s\n' "$(shellcheck --version 2>/dev/null | sed -n 's/^version: //p' | grep . || echo MISSING)"
    printf 'python3 %s\n' "$(python3 -V 2>&1 | sed 's/^Python //' | grep . || echo MISSING)"
    printf 'jq %s\n' "$(jq --version 2>/dev/null | grep . || echo MISSING)"
    printf 'sqlite3 %s\n' "$(sqlite3 --version 2>/dev/null | awk '{ print $1; exit }' | grep . || echo MISSING)"
    printf 'chrome %s\n' "$( { [ -n "$_en_c" ] && "$_en_c" --version 2>/dev/null; } | sed 's/[[:space:]]*$//' | grep . || echo MISSING)"
    printf 'os %s\n' "$(uname -sr)"
  } > "$1"
  sed 's/^/env: /' "$1"
  if [ -f tools/env-expected.txt ]; then
    if ! diff tools/env-expected.txt "$1" > "$1.diff" 2>&1; then
      echo "env: differs from tools/env-expected.txt (a red row below may be the machine, not the code):"
      sed 's/^/env:   /' "$1.diff"
    fi
  else
    echo "env: tools/env-expected.txt is missing"
  fi
}
env_report "out/$P-env.txt"

# ---- stored baselines: rule "current <= baseline"; lower them when possible, never raise silently
BASE_DATA_THEME=0         # "[data-theme=" occurrences in the page (structure runs over token attributes instead)
BASE_TOKREAD_22_30=0      # token reads in §22–30 (the core radius lives in LAYOUT)
BASE_DATENOW_BAD=0        # Date.now outside the viewer-clock DTG (ingest, lastSeenAge and loadData use `generated`)
DATENOW_OK='^function dtgTick\('   # D14 viewer clock: the only allowed wall clock, anchored at the line start
DATENOW_STRIP='s,/\*[^*]*\*/,,g;s,//[^"'"'"']*$,,'   # drop block comments and quote-free trailing `//` comments
# (anchor + comment strip: neither a trailing `// dtgString(` nor `/* dtgString( */` can launder a Date.now line)
# ---- floors of the check sets: a row must not turn green because the set it checks got empty or shrank.
# "must not shrink": raise these when the set legitimately grows, never lower them without a reason in the commit text.
MIN_SELFTEST=482          # sh starchorus-collect.sh --selftest 2>&1 | sed -n 's/.*SELFTEST: //p'   (measured: ALL PASS (482 checks), 19 October 2026: the alert log's eleven cases are in)
MIN_SECTIONS=42           # grep -c '==== [0-9]' starchorus.html                              (measured: 00..41)
MIN_SRC_FILES=37          # grep -c '' src/PAGE.list   (measured: 46 = four frame parts and one fragment for each of 00..41; about 80 %)
MIN_FIXTURES=15           # ls tests/fixtures/*.json | wc -l   (measured: 15)
MIN_QUICK_DROPINS=6       # set -- $QUICK_DROPINS $QUICK_DROPINS_MUTATE; echo $#                (doc-drift jq-noregex preflight hak5-package page-server mutation-probe)
MIN_QUICK_ROWS=50         # sh tools/quick.sh | grep -c ' PASS$'   (measured: 66; quick.sh's own rows are also asked for by name)
MIN_DATA_ORACLE_CASES=122 # python3 -B tools/data-oracle.py selftest | sed -n 's/^data-oracle selftest: \([0-9]*\)\/.*/\1/p'   (measured: 140)
MIN_PYFILES=5             # ls tools/*.py | wc -l                                               (cdp.py, gen-testdata.py, fuzz-doc.py, data-oracle.py, doc-truth.py)
# section slices: about 80 % of the measured size; measure: . tools/harness.sh; sec_slice 22 31 | wc -l
MIN_SLICE_UTIL_SPRITES=1200   # §22..§31, measured 1532
MIN_SLICE_INTERACTION=100     # §36..§37, measured 144
MIN_SLICE_SPRITES_INT=800     # §31..§36, measured 1045
MIN_SLICE_INTRO=25            # §39..§40, measured 39
# MIN_FNSCOPE (functions the §14.6 scope check recognises) lives in tools/passivity-check.sh next to the awk it guards.
# The radio pair's own share of the page: the page it started from (0.1.1 and the small items) was 595,327 bytes, and the design (spec §3.11) gives the pair 14,000 bytes over that.
# PHN_MAXB (tools/regress.d/phone.sh) is the cap of the release as a whole; these ceilings hold each feature to its own share, so that room under the cap that other work leaves is
# not used up by it unseen. Raise or drop a share with the change that moves it; the shares must sum to no more than the cap.
BASE_PAGE_BYTES=597362    # wc -c starchorus.html before the radio pair (feat-0.2 at 690de58, after the large-text fix)
MAX_PAIR_BYTES=14000      # what the pair may add to it
MAX_SCOPE_BYTES=12000     # what the Scope (the phone-mode fan) may add
MAX_ALERTS_BYTES=1200     # what the alerts' ring and legend may add
MAX_SCOPE_BT_BYTES=200    # the Scope's fifth lane (Bluetooth marks, radio-pair spec 3.6): counted inside the pair's 14,000, not the Scope's 12,000; scope.sh admits it in its own size row and the total below is unchanged
MAX_PAGE_BYTES=$((BASE_PAGE_BYTES + MAX_PAIR_BYTES + MAX_SCOPE_BYTES + MAX_ALERTS_BYTES))   # 624562, under the release cap of 625000
ACTIVE_GEN="--source iw-scan-ACTIVE --aps 24 --vendor-frac 0.5 --seed 158"   # tests/fixtures/active.json
# The drop-ins tools/quick.sh runs besides these rows. Chrome-free by construction (a row below counts it). Not split out of
# legal/-p10: their Chrome-free parts (denylist selftest/--extended, display LOG) are interleaved with Chrome runs there.
QUICK_DROPINS="doc-drift jq-noregex preflight hak5-package page-server"
QUICK_DROPINS_MUTATE="mutation-probe"   # added by quick.sh only when QUICK_MUTATE=1 (the hook sets it when the checker itself is staged)

# ---- static page rules (token reads "≤ baseline")
rowif "Math.random = 0" [ "$(g 'Math.random')" = 0 ]
# "sort -nc" alone passes on an empty list and on a marker that lost its number; this row demands the count, the
# start at 00 and every number in turn (so a renamed, duplicated or skipped marker is red).
mkbad=0; mk=$(grep '==== [0-9][0-9]* ' "$H" | sed 's/.*==== \([0-9][0-9]*\) .*/\1/' \
  | awk -v M="$MIN_SECTIONS" '{ n = $1 + 0; if (NR == 1 ? n != 0 : n != prev + 1) bad = 1; prev = n } END { printf "%d", NR; exit (bad || NR < M) }') || mkbad=1
rowif "section markers 00..$((mk - 1)): $mk (≥ $MIN_SECTIONS), ascending, gapless" [ "$mkbad" = 0 ]
# §39 (INTRO) holds no theme-id branch: a = b = 0 is the intended state, so the equality alone is 0 == 0.
# Two anchors keep the row from being vacuous: the regex must fire on synthetic branches, and §39 must be a real
# slice that reads the theme voice from tokens (THEME.copy).
a=$(g 'theme === "wargames"\|theme==="wargames"'); b=$(sec_grepc 39 40 "$MIN_SLICE_INTRO" 'theme === "wargames"\|theme==="wargames"') || b=NOSLICE
cp39=$(sec_grepc 39 40 "$MIN_SLICE_INTRO" 'THEME\.copy') || cp39=NOSLICE
live=$(printf '%s\n' 'if (theme === "wargames") x();' 'if (theme==="wargames") y();' | grep -c 'theme === "wargames"\|theme==="wargames"')
wgok=0; [ "$a" = "$b" ] && [ "$live" = 2 ] && ge "$cp39" 1 && wgok=1
rowif "wargames branches ($a) == §39 ($b); regex live $live/2, §39 THEME.copy $cp39 (≥ 1)" [ "$wgok" = 1 ]
sb=$(grep -n '\.shadowBlur *=' "$H" | cut -d: -f1 | secs | sort -un | tr '\n' ' ')
bad=0; for s in $sb; do case $s in 31|33|34) ;; *) bad=1;; esac; done
if [ $bad = 0 ]; then row "shadowBlur sections {$sb} ⊆ {31,33,34}" PASS; else row "shadowBlur sections {$sb}" FAIL; fi
rg=$(grep -n 'createRadialGradient(' "$H" | cut -d: -f1 | secs | sort -un | tr '\n' ' ')
bad=0; for s in $rg; do case $s in 31|33|37) ;; *) bad=1;; esac; done
if [ $bad = 0 ]; then row "radialGradient sections {$rg} ⊆ {31,33,37}" PASS; else row "radialGradient {$rg}" FAIL; fi
# sec_grepc anchors every slice (markers exactly once, size ≥ floor): a broken anchor prints NOSLICE and the row is red
c1=$(sec_grepc 22 31 "$MIN_SLICE_UTIL_SPRITES" 'THEME\.\|TK\[\|TD\.') || c1=NOSLICE
rowif "token reads in 22–30 = $c1 (≤ $BASE_TOKREAD_22_30, target 0)" le "$c1" "$BASE_TOKREAD_22_30"
c2=$(sec_grepc 36 37 "$MIN_SLICE_INTERACTION" 'THEME\.\|TK\[\|TD\.') || c2=NOSLICE; rowif "token reads in 36 = $c2" [ "$c2" = 0 ]
c3=$(sec_grepc 31 36 "$MIN_SLICE_SPRITES_INT" '#[0-9a-fA-F]\{6\}') || c3=NOSLICE; rowif "hex literals in 31–35 = $c3" [ "$c3" = 0 ]
rowif "no Google Fonts" [ "$(g 'fonts.googleapis')" = 0 ]
rowif "upload notice present" [ "$(g 'Everything runs in your browser — nothing is uploaded.')" = 1 ]
# the page ceiling (the base plus every share), and the judge of it on dummies (the exact ceiling passes, one byte more fails, a size that is no number fails; as with le/ge above, "fails" is any status but 0,
# since a test of a text that is no number ends with 2)
page_bytes_ok() { [ "$1" -le "$MAX_PAGE_BYTES" ] 2>/dev/null; }
pbn=0; pbbad=0
pb() {   # pb pass|fail SIZE
  pbn=$((pbn + 1)); page_bytes_ok "$2"; pbr=$?
  if [ "$1" = pass ]; then [ "$pbr" = 0 ]; else [ "$pbr" != 0 ]; fi || { pbbad=$((pbbad + 1)); echo "    page ceiling case $pbn: want $1 for '$2' (status $pbr)"; }
}
pb pass "$MAX_PAGE_BYTES"
pb fail "$((MAX_PAGE_BYTES + 1))"
pb pass "$BASE_PAGE_BYTES"
pb pass "$((BASE_PAGE_BYTES + MAX_PAIR_BYTES))"   # the pair's old ceiling, now inside the new one
pb fail ""
pb fail "x"
rowif "page ceiling judge on dummies ($((pbn - pbbad))/$pbn as expected)" [ "$pbbad" = 0 ]
PG_SZ=$(wc -c < "$H" | tr -d ' ')
rowif "page size $PG_SZ bytes ≤ $MAX_PAGE_BYTES (the base of $BASE_PAGE_BYTES plus the shares: pair $MAX_PAIR_BYTES, Scope $MAX_SCOPE_BYTES, alerts $MAX_ALERTS_BYTES; $((PG_SZ - BASE_PAGE_BYTES)) over the base)" page_bytes_ok "$PG_SZ"
# §11.0 global criterion (MUSS BLEIBEN 12). The first row is anchored on the fallback STATEMENT in
# normalizeDoc, not on the bare string: "YOU ARE HERE" also occurs in demoData and in the S.centerLabel
# default, so a whole-file count of the string survives the deletion of the fallback itself.
rowif "YOU ARE HERE fallback present" [ "$(g 'doc\.center\.label = "YOU ARE HERE"')" = 1 ]
rowif "YOU ARE HERE string present (§11.0)" [ "$(g 'YOU ARE HERE')" -ge 1 ]
# The output goes into a file once; selftest_verdict (harness.sh) judges it: ALL PASS, N ≥ floor, no "SKIP: recon.db tests"
# and sqlite3 present (three blocks are gated on it, only two announce a SKIP), other SKIP lines shown in the name.
# rc 3 (sqlite3 absent on purpose, ALLOW_NO_SQLITE=1) is printed as NOT COVERED, never as a quiet PASS or a misleading FAIL.
selftest_row() {   # selftest_row FILE [HAVE_SQLITE3] [ALLOW_NO_SQLITE]   (the last two only for the dummies below)
  _st_l=$(selftest_verdict "$1" "$MIN_SELFTEST" "${2:-}" "${3:-}"); _st_c=$?
  if [ "$_st_c" = 3 ]; then notcov "collector selftest: $_st_l"; else rowif "collector selftest: $_st_l" [ "$_st_c" = 0 ]; fi
}
if [ "${STATIC_SELFTEST:-1}" = 1 ]; then
  sh starchorus-collect.sh --selftest > "out/$P-selftest.txt" 2>&1
  selftest_row "out/$P-selftest.txt"
else
  echo "note: the collector selftest is not run here (about 20 s; it runs in tools/regress.sh, tier T2)"
fi
# the judge itself must be able to say no: dummy outputs, each with the verdict it has to get (no PATH tricks)
svn=0; svbad=0
sv() {   # sv EXPECTED_RC 'FILE CONTENT' [HAVE_SQLITE3] [ALLOW_NO_SQLITE]   (both default to the plain case, whatever the environment says)
  svn=$((svn + 1)); printf '%s\n' "$2" > "out/$P-sv.txt"
  selftest_verdict "out/$P-sv.txt" "$MIN_SELFTEST" "${3:-1}" "${4:-0}" > /dev/null; [ "$?" = "$1" ] || { svbad=$((svbad + 1)); echo "    verdict case $svn: want rc $1"; }
}
svok="[starchorus] SELFTEST: ALL PASS ($MIN_SELFTEST checks)"
sv 0 "$svok"
sv 0 "$(printf '%s\n%s' '[starchorus]   SKIP: once: overlap test needs sqlite3' "$svok")"
sv 1 "[starchorus] SELFTEST: 3 FAILED"
sv 1 "$(printf '[starchorus] SELFTEST: ALL PASS (%s checks)' "$((MIN_SELFTEST - 1))")"
sv 1 "$(printf '%s\n%s' '[starchorus]   SKIP: recon.db tests (sqlite3 not installed here)' "$svok")"
sv 1 "$svok" 0
sv 1 ""
# the one deliberate switch: without sqlite3 AND with ALLOW_NO_SQLITE=1 a green selftest is NOT COVERED (rc 3), a red one stays red,
# a missing line stays red, and the switch does nothing while sqlite3 is there
sv 3 "[starchorus] SELFTEST: ALL PASS ($((MIN_SELFTEST - 30)) checks)" 0 1
sv 1 "[starchorus] SELFTEST: 3 FAILED" 0 1
sv 1 "" 0 1
sv 1 "$(printf '%s\n%s' '[starchorus]   SKIP: recon.db tests (sqlite3 not installed here)' "$svok")" 1 1
sv 1 "$svok" 0 0
# ... and the row printer turns rc 3 into the status NOT COVERED (not PASS, not FAIL, counted in $ncov), rc 1 into FAIL, rc 0 into PASS
sr() {   # sr WANT_STATUS 'FILE CONTENT' HAVE ALLOW
  svn=$((svn + 1)); printf '%s\n' "$2" > "out/$P-sv.txt"
  _sr_o=$(selftest_row "out/$P-sv.txt" "$3" "$4")
  case $_sr_o in *" NOT COVERED") _sr_o="NOT COVERED" ;; *" PASS") _sr_o=PASS ;; *" FAIL") _sr_o=FAIL ;; *) _sr_o="?" ;; esac
  [ "$_sr_o" = "$1" ] || { svbad=$((svbad + 1)); echo "    row case $svn: want status $1, got '$_sr_o'"; }
}
sr PASS "$svok" 1 0
sr "NOT COVERED" "[starchorus] SELFTEST: ALL PASS ($((MIN_SELFTEST - 30)) checks)" 0 1
sr FAIL "$svok" 0 0
sr FAIL "[starchorus] SELFTEST: 3 FAILED" 0 1
rowif "selftest_verdict on dummies ($((svn - svbad))/$svn as expected)" [ "$svbad" = 0 ]
# preflight (harness.sh) has to name exactly the tools that are missing and return 2; the lookups are real (a tool that cannot exist),
# only "chrome" is stubbed through its own function _pf_chrome, because a real Chrome cannot be hidden from cdp.py. The sqlite3 switch
# and the whole-script exit codes are probed end to end by tools/regress.d/preflight.sh (a PATH without that tool).
pfn=0; pfbad=0
pf() {   # pf EXPECTED_RC 'EXPECTED MISSING NAMES' 'SETUP' TOOL...
  pfn=$((pfn + 1)); _pfe=$1; _pfw=$2; _pfs=$3; shift 3
  _pfo=$( ( eval "$_pfs"; preflight "$@" ) 2>&1 ); _pfrc=$?
  _pfg=$(printf '%s\n' "$_pfo" | sed -n 's/^MISSING: \([^ ]*\).*/\1/p' | tr '\n' ' ')
  if ! { [ "$_pfrc" = "$_pfe" ] && [ "$_pfg" = "$_pfw" ]; }; then pfbad=$((pfbad + 1)); echo "    preflight case $pfn: want rc $_pfe and '$_pfw', got rc $_pfrc and '$_pfg'"; fi
}
pf 0 "" : sh awk
pf 2 "starchorus-no-such-tool-a " : starchorus-no-such-tool-a
pf 2 "starchorus-no-such-tool-a starchorus-no-such-tool-b " : starchorus-no-such-tool-a sh starchorus-no-such-tool-b
pf 2 "chrome " '_pf_chrome() { return 1; }' sh chrome
pf 0 "" '_pf_chrome() { return 0; }' chrome
rowif "preflight on dummies ($((pfn - pfbad))/$pfn as expected)" [ "$pfbad" = 0 ]
# tm_check (the timing file judge) must refuse a file that lacks a drop-in, the total, an integer or is empty
tmn=0; tmbad=0
tmc() {   # tmc EXPECTED_RC 'FILE CONTENT' 'DROP-IN NAMES'
  tmn=$((tmn + 1)); printf '%s\n' "$2" > "out/$P-tm.txt"
  # shellcheck disable=SC2086   # the names are a word list on purpose
  tm_check "out/$P-tm.txt" $3 > /dev/null; [ "$?" = "$1" ] || { tmbad=$((tmbad + 1)); echo "    timing case $tmn: want rc $1"; }
}
tmok=$(printf '%s\n' 'phase static rows                         3 s' 'drop-in a-b                              4 s' 'drop-in c                                5 s' 'total                                   12 s')
tmc 0 "$tmok" "a-b c"
tmc 1 "$tmok" "a-b c d"
tmc 1 "$tmok" ""
tmc 1 "$(printf '%s\n' "$tmok" | sed '/^total/d')" "a-b c"
tmc 1 "$(printf '%s\n' "$tmok" | sed 's/^drop-in c  *5 s/drop-in c  x s/')" "a-b c"
tmc 1 "$(printf '%s\n' "$tmok" "drop-in c                                6 s")" "a-b c"
tmc 1 "" "a-b"
rm -f "out/$P-tm.txt"
tm_check "out/$P-no-such-timing.txt" a-b > /dev/null 2>&1 && tmbad=$((tmbad + 1)) && echo "    timing case: a missing file must be refused"
rowif "timing judge on dummies ($((tmn + 1 - tmbad))/$((tmn + 1)) as expected)" [ "$tmbad" = 0 ]
rowif "shellcheck collector" shellcheck -s sh starchorus-collect.sh
# sec_slice must refuse a broken range: dummy pages with each defect, expected rc 2, and the intact one rc 0
ssn=0; ssbad=0
ss() {   # ss EXPECTED_RC MIN 'PAGE TEXT' (markers 10 and 20 asked for)
  ssn=$((ssn + 1)); printf '%s\n' "$3" > "out/$P-ss.txt"
  _sec_slice_in "out/$P-ss.txt" 10 20 "$2" > /dev/null 2>&1; [ "$?" = "$1" ] || { ssbad=$((ssbad + 1)); echo "    slice case $ssn: want rc $1"; }
}
ss 0 3 "$(printf '// ==== 10 A ====\nx\n// ==== 20 B ====\ny')"
ss 2 1 "$(printf '// ==== 11 A ====\nx\n// ==== 20 B ====')"
ss 2 1 "$(printf '// ==== 10 A ====\nx\n// ==== 21 B ====')"
ss 2 1 "$(printf '// ==== 10 A ====\n// ==== 10 A ====\n// ==== 20 B ====')"
ss 2 1 "$(printf '// ==== 10 A ====\n// ==== 20 B ====\n// ==== 20 B ====')"
ss 2 1 "$(printf '// ==== 20 B ====\nx\n// ==== 10 A ====')"
ss 2 4 "$(printf '// ==== 10 A ====\n// ==== 20 B ====')"
ss 2 1 ""
rowif "sec_slice anchors on dummies ($((ssn - ssbad))/$ssn as expected)" [ "$ssbad" = 0 ]

# ---- the page is the build of src/ (tools/build-page.sh). The fragments under src/ are the source; starchorus.html, which the device, the
# Hak5 package and the installer read, is committed as their cat. Three rows: the build equals the page byte for byte; the manifest
# src/PAGE.list is sound; and the judge, which plants each defect in a copy of the tree and wants the checks red for it (and green for
# an intact copy). The hook only checks; it never rebuilds (that would change the index behind the author's back).
src_manifest() {   # src_manifest ROOT: the rules for the fragments below ROOT/src; one finding per line (four blanks in front), no output = sound
  _sm_s=$1/src; _sm_l=$_sm_s/PAGE.list; _sm_k=0; _sm_n=0; _sm_prev=
  if [ ! -s "$_sm_l" ]; then echo "    src/PAGE.list is missing or empty"; return 1; fi
  # shellcheck disable=SC2094   # the manifest is only read, by the loop and by the grep in it; nothing here writes it
  while IFS= read -r _sm_p || [ -n "$_sm_p" ]; do
    _sm_n=$((_sm_n + 1))
    # the four frame parts sit in fixed slots: swapped, the page is still the build of the manifest and its sections still run in turn,
    # so no other rule sees it (shell/js-end.html, the last, is asked for after the loop)
    case $_sm_p in
      shell/head.html) [ "$_sm_n" = 1 ] || echo "    src/PAGE.list line $_sm_n: shell/head.html must be listed first (before section 00)" ;;
      shell/css-end.html) case $_sm_prev in css/09-?*) ;; *) echo "    src/PAGE.list line $_sm_n: shell/css-end.html must be listed directly after section 09" ;; esac ;;
      shell/js-begin.html) case $_sm_prev in html/19-?*) ;; *) echo "    src/PAGE.list line $_sm_n: shell/js-begin.html must be listed directly after section 19" ;; esac ;;
    esac
    _sm_prev=$_sm_p
    case $_sm_p in
      '' | /* | *..* | */*/* | *[!A-Za-z0-9._/-]*) echo "    src/PAGE.list line $_sm_n: '$_sm_p' is no usable path"; continue ;;
      shell/?* | css/?* | html/?* | js/?*) ;;
      *) echo "    src/PAGE.list line $_sm_n: '$_sm_p' is not below shell/, css/, html/ or js/"; continue ;;
    esac
    [ "$(grep -cFx -- "$_sm_p" "$_sm_l")" = 1 ] || echo "    src/$_sm_p is listed more than once"
    _sm_f=$_sm_s/$_sm_p
    [ -f "$_sm_f" ] || { echo "    src/$_sm_p is listed but missing"; continue; }
    [ "$(tr -cd '\r' < "$_sm_f" | wc -c | tr -d ' ')" = 0 ] || echo "    src/$_sm_p holds a CR"
    { [ -s "$_sm_f" ] && [ "$(tail -c 1 "$_sm_f" | wc -l | tr -d ' ')" = 1 ]; } || echo "    src/$_sm_p has no final newline"
    _sm_m=$(grep -c '==== [0-9][0-9]* ' "$_sm_f")   # the marker as harness.sh sec_slice counts it ("17b" has no blank after its digits)
    _sm_b=${_sm_p##*/}
    case $_sm_b in
      [0-9][0-9]-*)   # a section: the name carries its number, the first line is its one marker, and the numbers run 00.. in turn
        _sm_nn=${_sm_b%%-*}; _sm_want=$(printf '%02d' "$_sm_k"); _sm_k=$((_sm_k + 1))
        [ "$_sm_nn" = "$_sm_want" ] || echo "    src/PAGE.list: $_sm_p is out of order (section $_sm_nn where $_sm_want is due)"
        [ "$_sm_m" = 1 ] || echo "    src/$_sm_p holds $_sm_m section markers (want exactly 1)"
        head -n 1 "$_sm_f" | grep -qF -- "==== $_sm_nn " || echo "    src/$_sm_p: its first line is not the marker of section $_sm_nn" ;;
      *) [ "$_sm_m" = 0 ] || echo "    src/$_sm_p is a frame part and holds $_sm_m section markers (want 0)" ;;
    esac
  done < "$_sm_l"
  [ "$_sm_prev" = shell/js-end.html ] || echo "    src/PAGE.list: shell/js-end.html must be listed last (after section 41), the last line is '$_sm_prev'"
  [ "$_sm_k" -ge "$MIN_SECTIONS" ] || echo "    src/PAGE.list names $_sm_k section fragments (want at least $MIN_SECTIONS)"
  [ "$_sm_n" -ge "$MIN_SRC_FILES" ] || echo "    src/PAGE.list names $_sm_n fragments (want at least $MIN_SRC_FILES)"
  # every file below src/ is listed: a fragment the build does not use is dead text that a reader would take for live
  find "$_sm_s" -type f ! -name .DS_Store | LC_ALL=C sort | while IFS= read -r _sm_f; do
    _sm_r=${_sm_f#"$_sm_s"/}
    [ "$_sm_r" = PAGE.list ] || grep -qFx -- "$_sm_r" "$_sm_l" || echo "    src/$_sm_r is not listed in src/PAGE.list"
  done
}
src_verdict() {   # src_verdict ROOT: build-page.sh --check and src_manifest on the tree below ROOT; the findings on stdout, rc 1 when either is red
  _sj_o=$( (cd "$1" && sh tools/build-page.sh --check) 2>&1 ); _sj_rc=$?
  [ "$_sj_rc" = 0 ] || printf '%s\n' "$_sj_o" | sed 's/^/    /'
  _sj_m=$(src_manifest "$1"); [ -z "$_sj_m" ] || printf '%s\n' "$_sj_m"
  [ "$_sj_rc" = 0 ] && [ -z "$_sj_m" ]
}
sp_n=$(grep -c '' src/PAGE.list 2> /dev/null) || sp_n=0
if sp_o=$(sh tools/build-page.sh --check 2>&1); then row "page = build of src/ ($sp_n fragments, $PG_SZ bytes)" PASS
else row "page = build of src/ ($sp_n fragments, $PG_SZ bytes)" FAIL; printf '%s\n' "$sp_o" | sed 's/^/    /'; fi
sp_m=$(src_manifest "$R"); sp_k=$(grep -c '^[a-z]*/[0-9][0-9]-' src/PAGE.list 2> /dev/null) || sp_k=0
if [ -z "$sp_m" ]; then row "src manifest: $sp_n fragments (≥ $MIN_SRC_FILES), sections 00..$((sp_k - 1)) in order, once each, no CR" PASS
else row "src manifest: $sp_n fragments (≥ $MIN_SRC_FILES), sections 00..$((sp_k - 1)) in order, once each, no CR" FAIL; printf '%s\n' "$sp_m"; fi
# The judge: every defect planted in a copy of the tree (src/, the page and the builder), each with the words its finding has to hold, so
# that a rule which went blind cannot hide behind another rule that is still red. Where a rule is the only one that can see the defect
# (a CR, a missing final newline, a marker that names another section, the order), the copy's page is rebuilt first, so that the byte
# comparison is green and only the manifest rule stands between the defect and a green row. The intact copy's page is rebuilt too: were
# the committed page stale, the row "page = build of src/" is red for that, and the judge must not be red for the same cause (two rows
# for one fault); it judges the rules only, on a tree that is sound.
spn=0; spbad=0
sp_flip() { LC_ALL=C sed "$2s/^./X/" "$1" > "$1.new" && mv "$1.new" "$1"; }   # sp_flip FILE N: the first byte of line N becomes X
sp_swap() { sed -e 's|^js/22-util\.js$|@|' -e 's|^js/23-normalize\.js$|js/22-util.js|' -e 's|^@$|js/23-normalize.js|' src/PAGE.list > src/PAGE.new && mv src/PAGE.new src/PAGE.list; }
sp_cr() { sed "$2s/\$/$(printf '\r')/" "$1" > "$1.new" && mv "$1.new" "$1"; }   # sp_cr FILE N: a CR at the end of line N
sp_nonl() { printf '%s' "$(cat "$1")" > "$1.new" && mv "$1.new" "$1"; }   # sp_nonl FILE: the final newline(s) taken away
sp_mark() { sed '1s/==== 22 /==== 23 /' src/js/22-util.js > src/js/22-util.new && mv src/js/22-util.new src/js/22-util.js; }   # the marker names another section
sp_fswap() { awk -v a="$1" -v b="$2" '$0 == a { print b; next } $0 == b { print a; next } { print }' src/PAGE.list > src/PAGE.new && mv src/PAGE.new src/PAGE.list; }   # sp_fswap A B: the two names change places in the manifest
sp_few() { head -n $((MIN_SRC_FILES - 1)) src/PAGE.list > src/PAGE.new && mv src/PAGE.new src/PAGE.list && find src -type f ! -name PAGE.list | while IFS= read -r _sf_f; do grep -qFx -- "${_sf_f#src/}" src/PAGE.list || rm -f "$_sf_f"; done; }   # one fragment short of the floor, the rest gone from the disk too
sp_case() {   # sp_case pass|fail 'WORDS THE FINDINGS HOLD' 'WHAT IS WRONG' 'SHELL TEXT THAT PLANTS IT (run inside the copy)'
  spn=$((spn + 1)); _sp_d="out/$P-srcjudge"; rm -rf "$_sp_d"; mkdir -p "$_sp_d/tools"
  if cp -R src "$_sp_d/" && cp tools/build-page.sh "$_sp_d/tools/" && cp starchorus.html "$_sp_d/"; then
    ( cd "$_sp_d" && eval "$4" ) > /dev/null 2>&1
    _sp_o=$(src_verdict "$_sp_d"); _sp_rc=$?
  else _sp_o="the copy could not be made"; _sp_rc=-1; fi
  _sp_ok=0
  if [ "$1" = pass ]; then [ "$_sp_rc" = 0 ] && _sp_ok=1
  elif [ "$_sp_rc" != 0 ] && printf '%s\n' "$_sp_o" | grep -qF -- "$2"; then _sp_ok=1; fi
  [ "$_sp_ok" = 1 ] || { spbad=$((spbad + 1)); echo "    src judge case $spn ($3): want $1${2:+ with \"$2\"}, got rc $_sp_rc:"; printf '%s\n' "$_sp_o" | head -n 4 | cut -c1-170; }
  rm -rf "$_sp_d"
}
sp_case pass '' 'the intact copy, its page rebuilt first so that only the rules are judged' 'sh tools/build-page.sh'
sp_case fail 'differs from the build' 'one byte changed in the page' 'sp_flip starchorus.html 4'
sp_case fail 'differs from the build' 'one byte changed in a fragment' 'sp_flip src/js/22-util.js 2'
sp_case fail 'missing' 'a listed fragment is gone' 'rm src/js/30-step.js'
sp_case fail 'not listed' 'a fragment nobody lists' 'echo x > src/js/extra.js'
sp_case fail 'differs from the build' 'two fragments swapped in the manifest, the page not rebuilt' 'sp_swap'
sp_case fail 'out of order' 'two fragments swapped in the manifest, the page rebuilt' 'sp_swap && sh tools/build-page.sh'
sp_case fail 'holds a CR' 'a CR in a fragment, the page rebuilt' 'sp_cr src/js/22-util.js 2 && sh tools/build-page.sh'
sp_case fail 'no final newline' 'a fragment without its final newline, the page rebuilt' 'sp_nonl src/js/40-debug-api.js && sh tools/build-page.sh'
sp_case fail 'not the marker of section 22' 'a marker that names another section, the page rebuilt' 'sp_mark && sh tools/build-page.sh'
# the frame parts: one swap of a pair gives two findings, so each end of it is asked for by its own words
sp_case fail 'shell/head.html must be listed first' 'head.html and js-end.html swapped in the manifest, the page rebuilt: the first slot' 'sp_fswap shell/head.html shell/js-end.html && sh tools/build-page.sh'
sp_case fail 'shell/js-end.html must be listed last' 'head.html and js-end.html swapped in the manifest, the page rebuilt: the last slot' 'sp_fswap shell/head.html shell/js-end.html && sh tools/build-page.sh'
sp_case fail 'shell/css-end.html must be listed directly after section 09' 'css-end.html and js-begin.html swapped in the manifest, the page rebuilt: the end of the style block' 'sp_fswap shell/css-end.html shell/js-begin.html && sh tools/build-page.sh'
sp_case fail 'shell/js-begin.html must be listed directly after section 19' 'css-end.html and js-begin.html swapped in the manifest, the page rebuilt: the start of the script' 'sp_fswap shell/css-end.html shell/js-begin.html && sh tools/build-page.sh'
sp_case fail 'listed more than once' 'shell/js-end.html listed twice, the page rebuilt' 'echo shell/js-end.html >> src/PAGE.list && sh tools/build-page.sh'
sp_case fail 'is a frame part and holds' 'a section marker in a frame part, the page rebuilt' 'echo "/* ==== 05 stray */" >> src/shell/css-end.html && sh tools/build-page.sh'
sp_case fail "fragments (want at least $MIN_SRC_FILES)" 'one fragment fewer than the floor MIN_SRC_FILES, the page rebuilt' 'sp_few && sh tools/build-page.sh'
sp_case fail 'starchorus.html is missing' 'the page is gone from the copy' 'rm starchorus.html'
rowif "src checks on dummies ($((spn - spbad))/$spn as expected)" [ "$spbad" = 0 ]
# information only, no ceiling per fragment yet: where the page's bytes are (the whole table: sh tools/build-page.sh --list)
sp_i=$(sh tools/build-page.sh --list 2> /dev/null | awk 'NF == 2 { sub(/^[a-z]+\//, "", $2); printf "%s%s %s", (n++ ? ", " : ""), $2, $1 }')
echo "note: src/ bytes per fragment (information only, no ceiling): ${sp_i:-no list}"

# ---- theme branches, baselines, wall clock
tc=""; tcbad=0
for id in foundation wargames whitehall; do
  re="[=!]==?[[:space:]]*[\"'\`]${id}[\"'\`]|[\"'\`]${id}[\"'\`][[:space:]]*[=!]==?|[=!]==?[[:space:]]*THEMES(\\.${id}([^A-Za-z0-9_]|\$)|\\[[\"'\`]${id}[\"'\`]\\])|THEMES(\\.${id}|\\[[\"'\`]${id}[\"'\`]\\])[[:space:]]*[=!]==?|case[[:space:]]+[\"'\`]${id}[\"'\`]|(includes|indexOf|startsWith|endsWith|match|test)\\([[:space:]]*[\"'\`/]${id}|/${id}/[a-z]*\\.test\\(|\\[[^]]*[\"'\`]${id}[\"'\`][^]]*\\]\\.(includes|indexOf)\\("
  n=$(grep -nE "$re" "$H" | cut -d: -f1 | secs | grep -vcx 39); tc="$tc $id:$n"; [ "$n" = 0 ] || tcbad=1
done
gre='(S\.ui\.theme|THEME\.meta\.id|getTheme\(\)|dataset\.theme)[[:space:]]*[=!]==?|[=!]==?[[:space:]]*(S\.ui\.theme|THEME\.meta\.id|getTheme\(\)|dataset\.theme)'
n=$(grep -nE "$gre" "$H" | cut -d: -f1 | secs | grep -vcx 39); tc="$tc selector:$n"; [ "$n" = 0 ] || tcbad=1
rowif "theme-id comparisons outside §39:$tc" [ "$tcbad" = 0 ]
dt=$(grep -o '\[data-theme[~^$*|]\{0,1\}=' "$H" | wc -l | tr -d ' ')
rowif "[data-theme= = $dt (≤ baseline $BASE_DATA_THEME)" [ "$dt" -le "$BASE_DATA_THEME" ]
dn=$(sed "$DATENOW_STRIP" "$H" | grep 'Date\.now' | grep -vcE "$DATENOW_OK")
rowif "Date.now outside DTG clock = $dn (≤ $BASE_DATENOW_BAD)" [ "$dn" -le "$BASE_DATENOW_BAD" ]
# the dump is line-numbered, so it cannot reuse the anchored $DATENOW_OK: it prints every Date.now line
[ "$dn" -le "$BASE_DATENOW_BAD" ] || grep -n 'Date\.now' "$H" | cut -c1-140 | sed 's/^/    /'
nd=$(grep -cE 'new Date\([[:space:]]*\)' "$H"); bd=$(grep -E '(^|[^.A-Za-z0-9_$])Date[[:space:]]*\(' "$H" | grep -vc 'new Date')
pn=$(grep -n 'performance\.now' "$H" | cut -d: -f1 | secs | grep -vcx 40)
rowif "new Date()=$nd Date()=$bd perf.now∉§40=$pn (0/0/0)" [ "$nd/$bd/$pn" = 0/0/0 ]

# ---- passivity/legal, shell hygiene, fixtures, self-containment
sh tools/passivity-check.sh > "out/$P-passivity.txt" 2>&1; pc=$?
cat "out/$P-passivity.txt"
rowif "passivity-check.sh (exit $pc)" [ "$pc" = 0 ]
# starchorus-serve.sh (the nc listener) is on this list too. tools/regress.d/doc-truth.sh compares the
# two lists written here with the shell files the repository really has, both ways, with reasoned exceptions.
{ printf '%s\n' starchorus-collect.sh starchorus-display.sh payload.sh starchorus-serve.sh; find library -type f -name '*.sh' | LC_ALL=C sort; } > "out/$P-shfiles.txt"
scn=0; scbad=0
while IFS= read -r sf; do scn=$((scn + 1)); shellcheck "$sf" > /dev/null 2>&1 || { scbad=$((scbad + 1)); echo "    shellcheck: $sf"; }; done < "out/$P-shfiles.txt"
rowif "shellcheck collector/display/payload ($scn files)" [ "$scbad" = 0 ]
set -- tools/*.sh; for x in tools/regress.d/*.sh; do [ -f "$x" ] && set -- "$@" "$x"; done
printf '%s\n' "$@" > "out/$P-shfiles-tools.txt"   # the list as checked (read by tools/regress.d/doc-truth.sh)
rowif "shellcheck tools/*.sh + regress.d ($# files)" shellcheck -x -P SCRIPTDIR "$@"
rowif "starchorus-display.sh copies identical" cmp -s starchorus-display.sh library/user/reconnaissance/starchorus/starchorus-display.sh
vn=0; vbad=0
for fj in "$F"/*.json; do
  case $fj in */legacy.json) lg=--legacy;; *) lg=;; esac; vn=$((vn + 1))
  # shellcheck disable=SC2086   # $lg is empty or one flag
  python3 tools/gen-testdata.py --validate "$fj" $lg > /dev/null 2>&1 || { vbad=$((vbad + 1)); echo "    invalid: $fj"; }
done
fxok=0; [ "$vbad" = 0 ] && ge "$vn" "$MIN_FIXTURES" && fxok=1
rowif "fixtures validate ($vn files ≥ $MIN_FIXTURES)" [ "$fxok" = 1 ]
# shellcheck disable=SC2086   # ACTIVE_GEN is a flag list
python3 tools/gen-testdata.py $ACTIVE_GEN --out "out/$P-active.json" 2>/dev/null
rowif "active.json = gen-testdata $ACTIVE_GEN" cmp -s "out/$P-active.json" "$F/active.json"
# self-containment covers the WHOLE harness, not just tools/*.sh|*.py: the drop-ins and the eval sources
# are exactly where a change is most likely to bake in an absolute path. The git hook is part of it.
set -- tools/*.sh tools/*.py .githooks/pre-commit
for x in tools/regress.d/*.sh tools/evals/*; do [ -f "$x" ] && set -- "$@" "$x"; done
sx=$(cat "$@" | grep -v '^[[:space:]]*#' | grep -cE '[/]Users[/]|[/]home[/]')
rowif "harness self-contained ($# files, abs paths: $sx)" [ "$sx" = 0 ]
# python files must at least compile (compile() only: no __pycache__ appears in the work tree). The dummy proves the
# check can say no; the floor keeps an emptied glob from passing.
printf 'def f(:\n' > "out/$P-badpy.txt"; pycompile "out/$P-badpy.txt" > /dev/null 2>&1; pcneg=$?
set -- tools/*.py; pcn=$#; pcok=0; pycompile "$@" && ge "$pcn" "$MIN_PYFILES" && [ "$pcneg" = 1 ] && pcok=1
rowif "python3 tools/*.py compile ($pcn files ≥ $MIN_PYFILES, dummy syntax error caught: rc $pcneg)" [ "$pcok" = 1 ]
# The run-time network judge (net_verdict, harness.sh; used by regress.d/net-runtime.sh on real runs) must be able to say no:
# dummy reports and server logs, each with the verdict it has to get. Chrome-free; the real runs are in tier T2.
nvn=0; nvbad=0
NVR='{"method":"GET","url":"http://127.0.0.1:5/"},{"method":"GET","url":"http://127.0.0.1:5/starchorus.json?_=0"},{"method":"GET","url":"http://127.0.0.1:5/starchorus.json?_=5"},{"method":"GET","url":"data:font/woff2;base64,AAAA"}'
NVL='127.0.0.1 - - [d] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [d] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [d] "GET /starchorus.json?_=0 HTTP/1.1" 200 -
127.0.0.1 - - [d] "GET /starchorus.json?_=5 HTTP/1.1" 200 -'
nv() {   # nv EXPECTED_RC 'REQUEST OBJECTS (comma list, or "-" for no "requests" key)' 'SERVER LOG TEXT (or -)' MIN_POLLS
  nvn=$((nvn + 1))
  if [ "$2" = - ]; then printf '{"url":"http://127.0.0.1:5/"}\n' > "out/$P-nv.json"
  else printf '{"url":"http://127.0.0.1:5/","requests":[%s]}\n' "$2" > "out/$P-nv.json"; fi
  if [ "$3" = - ]; then nvl=-; else printf '%s\n' "$3" > "out/$P-nv.log"; nvl="out/$P-nv.log"; fi
  net_verdict "out/$P-nv.json" "$nvl" "$4" > /dev/null; [ "$?" = "$1" ] || { nvbad=$((nvbad + 1)); echo "    net case $nvn: want rc $1"; }
}
nv 0 "$NVR" "$NVL" 2
nv 0 "$NVR"',{"method":"GET","url":"http://127.0.0.1:5/favicon.ico"},{"method":"GET","url":"data:image/png;base64,AAAA"}' - 2
nv 1 "$NVR"',{"method":"POST","url":"http://127.0.0.1:5/x"}' - 2
nv 1 "$NVR"',{"method":"GET","url":"http://127.0.0.1:9/x"}' - 2
nv 1 "$NVR"',{"method":"GET","url":"http://example.invalid/starchorus.json"}' - 2
nv 1 "$NVR"',{"method":"GET","url":"http://127.0.0.1:5/cgi-bin/x?c=1"}' - 2
nv 1 "$NVR"',{"method":"WEBSOCKET","url":"ws://127.0.0.1:5/"}' - 2
nv 1 "$NVR"',{"method":"POST","url":"data:text/plain,x"}' - 2
nv 1 '{"method":"GET","url":"http://127.0.0.1:5/"},{"method":"GET","url":"http://127.0.0.1:5/favicon.ico"}' - 2
nv 1 '{"method":"GET","url":"http://127.0.0.1:5/starchorus.json?_=0"},{"method":"GET","url":"http://127.0.0.1:5/starchorus.json?_=5"}' - 2
nv 1 '{"method":"GET","url":"http://127.0.0.1:5/"}' - 1
nv 1 "$NVR" - 3
nv 1 - - 2
nv 1 "$NVR" "$NVL
127.0.0.1 - - [d] \"POST /starchorus.json HTTP/1.1\" 501 -" 2
nv 1 "$NVR" "$NVL
127.0.0.1 - - [d] \"GET /admin HTTP/1.1\" 404 -" 2
nv 1 "$NVR" "$NVL
127.0.0.1 - - [d] \"GET /starchorus.json?_=9 HTTP/1.1\" 200 -
127.0.0.1 - - [d] \"GET /starchorus.json?_=14 HTTP/1.1\" 200 -" 2
nv 1 "$NVR" "no request line here" 2
rowif "net_verdict on dummies ($((nvn - nvbad))/$nvn as expected)" [ "$nvbad" = 0 ]
# The ingest-fuzz judge (fuzz_verdict, harness.sh; used by regress.d/ingest-fuzz.sh) must be able to say no as well: dummy
# reports of the two evals, each with the verdict it has to get. Chrome-free; the real runs are in tier T2.
fzn=0; fzbad=0; FZMIN=33; FZANC=30
FZS='"sinks":{"tip":9,"detail":9,"source":2,"legend":3,"chan":9,"paste":6,"drop":3,"anchors":30},"ms":1000'
FZC='"classes":{"1":5,"2":5,"3":5,"4":5,"5":5,"6":5},"n":30'
FZM="{$FZC,\"findings\":[],$FZS}"; FZB='{"classes":{"7":3},"n":3,"findings":[],"ms":1000}'
FZF='["4:x","load threw: RangeError"]'; FZE='["6:a","anchor: AP tooltip holds masked text"]'; FZN='["3:b","load threw: TypeError"]'
fz() {   # fz EXPECTED_RC MODE 'MAIN RESULT' 'BIG RESULT' ['OPEN LIST TEXT']
  fzn=$((fzn + 1))
  python3 -c 'import json,sys; json.dump({"eval":[{"value":sys.argv[1]},{"value":sys.argv[2]}]}, open(sys.argv[3],"w"))' "$3" "$4" "out/$P-fz.json"
  fzo=-; if [ -n "${5:-}" ]; then printf '%s\n' "$5" > "out/$P-fz.open"; fzo="out/$P-fz.open"; fi
  fuzz_verdict "out/$P-fz.json" "$2" "$FZMIN" "$FZANC" "$fzo" > /dev/null; [ "$?" = "$1" ] || { fzbad=$((fzbad + 1)); echo "    fuzz case $fzn: want rc $1"; }
}
fz 0 run "$FZM" "$FZB"
fz 1 run "{$FZC,\"findings\":[$FZF],$FZS}" "$FZB"
fz 0 run "{$FZC,\"findings\":[$FZF],$FZS}" "$FZB" '4:*|page|dummy'
fz 1 run "$FZM" "$FZB" '4:*|page|dummy'
fz 1 run '{"classes":{"1":6,"2":6,"3":6,"4":6,"6":6},"n":30,'"$FZS"'}' "$FZB"
fz 1 run '{"classes":{"1":4,"2":4,"3":4,"4":4,"5":4,"6":4},"n":24,"findings":[],'"$FZS"'}' "$FZB"
fz 1 run "{$FZC,\"findings\":[],$(printf '%s' "$FZS" | sed 's/"anchors":30/"anchors":29/')}" "$FZB"
fz 1 run "{$FZC,\"findings\":[],$(printf '%s' "$FZS" | sed 's/"paste":6/"paste":0/')}" "$FZB"
fz 1 run "$FZM" '{"classes":{"7":3},"n":3,"findings":['"$FZF"'],"ms":1000}'
fz 1 run "{$FZC,\"findings\":[$FZF,$FZE],$FZS}" "$FZB" '4:*|page|dummy'   # a new finding next to a listed one must not be swallowed by the glob
fz 1 run "{$FZC,\"findings\":[[\"4:x\",\"load threw: RangeError\"]],$FZS}" "$FZB" '5:*|page|dummy'   # a glob of another class must not match
fz 1 run "not json" "$FZB"
fz 0 probe "{$FZC,\"findings\":[$FZE,$FZN],$FZS}" "$FZB"
fz 1 probe "{$FZC,\"findings\":[$FZE],$FZS}" "$FZB"
fz 1 probe "{$FZC,\"findings\":[$FZN],$FZS}" "$FZB"
fz 1 probe "$FZM" "$FZB"
fz 1 probe "{$FZC,\"findings\":[$FZE,$FZN,$FZF],$FZS}" "$FZB"
fz 1 probe "{$FZC,\"findings\":[$FZE,$FZN,[\"3:c\",\"errors(): boom\"]],$FZS}" "$FZB"   # a 3: finding that is not a load throw is unplanned
fz 1 probe "{$FZC,\"findings\":[$FZE,[\"3:c\",\"errors(): boom\"]],$FZS}" "$FZB"   # ... and does not count as the null-entry fault seen
rowif "fuzz_verdict on dummies ($((fzn - fzbad))/$fzn as expected)" [ "$fzbad" = 0 ]
# The input-order judge (order_verdict, harness.sh; used by regress.d/order-invariance.sh) must be able to say no too: dummy reports of the
# one eval, each with the verdict it has to get. Chrome-free; the real runs are in tier T2.
orn=0; orbad=0; ORMIN=15
ORF='{"name":"a","lists":[{"l":"aps","n":6,"checked":true,"moved":10},{"l":"unassociated","n":2,"checked":false,"moved":0}],"runs":10,"iter":[3,3],"settled":[true]}'
ORF2='{"name":"b","lists":[{"l":"aps","n":9,"checked":true,"moved":10}],"runs":10,"iter":[3,4],"settled":[true]}'
ORX='"seeds":10,"minn":5,"ms":1000'
ORM='"mixer":{"lists":17,"ok":17,"bad":[]}'
ORD='["a#seed1","node x: [1,2] vs [3,4]"]'; ORE='["b#seed2","layoutInfo [1] vs [2]"]'; ORL='["a#3","load failed: boom"]'
or_() {   # or_ EXPECTED_RC MODE 'REPORT BODY' ['OPEN LIST TEXT']    (the second eval of the run, for mixerprobe, is the same object)
  orn=$((orn + 1))
  python3 -c 'import json,sys; json.dump({"eval":[{"value":sys.argv[1]},{"value":sys.argv[1]}]}, open(sys.argv[2],"w"))' "{$3}" "out/$P-or.json"
  oro=-; if [ -n "${4:-}" ]; then printf '%s\n' "$4" > "out/$P-or.open"; oro="out/$P-or.open"; fi
  order_verdict "out/$P-or.json" "$2" "$ORMIN" "$oro" > /dev/null; [ "$?" = "$1" ] || { orbad=$((orbad + 1)); echo "    order case $orn: want rc $1"; }
}
or_ 0 run "\"fixtures\":[$ORF,$ORF2],$ORX,$ORM,\"findings\":[]"
or_ 1 run "\"fixtures\":[$ORF,$ORF2],$ORX,$ORM,\"findings\":[$ORD]"
or_ 0 run "\"fixtures\":[$ORF,$ORF2],$ORX,$ORM,\"findings\":[$ORD]" 'a#*|page|dummy'
or_ 1 run "\"fixtures\":[$ORF,$ORF2],$ORX,$ORM,\"findings\":[]" 'a#*|page|dummy'
or_ 1 run "\"fixtures\":[$ORF,$ORF2],$ORX,$ORM,\"findings\":[$ORD,$ORE]" 'a#*|page|dummy'
or_ 1 run "\"fixtures\":[$ORF,$ORF2],$ORX,$ORM,\"findings\":[$ORD]" 'b#*|page|dummy'
or_ 1 run "\"fixtures\":[$ORF,$ORF2],$ORX,\"mixer\":{\"lists\":14,\"ok\":14,\"bad\":[]},\"findings\":[]"
or_ 1 run "\"fixtures\":[$ORF,$ORF2],$ORX,\"mixer\":{\"lists\":17,\"ok\":16,\"bad\":[\"a:aps moved 3/10\"]},\"findings\":[]"
or_ 1 run "\"fixtures\":[$(printf '%s' "$ORF" | sed 's/"runs":10/"runs":4/'),$ORF2],$ORX,$ORM,\"findings\":[]"
or_ 1 run "\"fixtures\":[],$ORX,$ORM,\"findings\":[]"
or_ 1 run "\"fixtures\":[$ORF,$ORF2],\"seeds\":5,\"minn\":5,\"ms\":1,$ORM,\"findings\":[]"
or_ 1 run "\"fixtures\":[$ORF,$ORF2],$ORX,$ORM,\"findings\":[$ORL]"
or_ 1 run "\"findings\":[[\"setup\",\"STARCHORUS._internals missing\"]]"
or_ 0 probe "\"fixtures\":[$ORF,$ORF2],$ORX,$ORM,\"findings\":[$ORD,$ORE]"
or_ 1 probe "\"fixtures\":[$ORF,$ORF2],$ORX,$ORM,\"findings\":[$ORD]"
or_ 1 probe "\"fixtures\":[$ORF,$ORF2],$ORX,$ORM,\"findings\":[]"
or_ 1 probe "\"fixtures\":[$ORF,$ORF2],$ORX,$ORM,\"findings\":[$ORD,$ORE,$ORL]"
or_ 0 mixerprobe "\"fixtures\":[$ORF],$ORX,\"mixer\":{\"lists\":17,\"ok\":0,\"bad\":[\"a:aps moved 0/10\"]},\"findings\":[]"
or_ 1 mixerprobe "\"fixtures\":[$ORF],$ORX,$ORM,\"findings\":[]"
or_ 1 mixerprobe "\"fixtures\":[$ORF],$ORX,\"mixer\":{\"lists\":17,\"ok\":3,\"bad\":[]},\"findings\":[]"
rowif "order_verdict on dummies ($((orn - orbad))/$orn as expected)" [ "$orbad" = 0 ]
# The data oracle (tools/data-oracle.py; used by regress.d/data-oracle.sh on real runs) must be able to say no too, and its model
# must hold against hand-computed answers: `selftest` runs the model over the hand documents and the judge over dummy runs (a page
# that agrees is green; every field, list and mode that is off, a missing document or mode, a moved rule constant, a stale known-open
# entry, a blind or over-broad probe are red) and the ground-truth check over broken copies of devices.json. Chrome-free.
dosf=$(python3 -B tools/data-oracle.py selftest 2> /dev/null); dosr=$?
dosn=$(printf '%s\n' "$dosf" | sed -n 's/^data-oracle selftest: //p')
# "N/M cases as expected" is the ONLY green form: N = M (no "-- FAIL" tail), M at least the floor. Empty output (a selftest that never ran, e.g. a broken
# __main__ guard) or a run with fewer cases (a loop that ran empty) is red, not "exit 0".
dosok=0; dosm=${dosn%% *}
if printf '%s\n' "$dosn" | grep -Eq '^[0-9]+/[0-9]+ cases as expected$' && [ "$dosr" = 0 ] && [ "${dosm%/*}" = "${dosm#*/}" ] && ge "${dosm#*/}" "$MIN_DATA_ORACLE_CASES"; then dosok=1; fi
rowif "data-oracle selftest (${dosn:-no output}; at least $MIN_DATA_ORACLE_CASES cases)" [ "$dosok" = 1 ]
[ "$dosok" = 1 ] || printf '%s\n' "$dosf" | cut -c1-300 | sed 's/^/    /'

# ---- the tier-1 wiring. The quick drop-ins must exist and stay Chrome-free (a Chrome run in the hook would make it
# slow and the hook would start to be skipped); the hook must be executable, shellcheck-clean and call tools/quick.sh;
# the environment report and tools/env-expected.txt must name the same keys.
qdn=0; qdbad=""
for qd in $QUICK_DROPINS $QUICK_DROPINS_MUTATE; do
  qdn=$((qdn + 1)); qf="tools/regress.d/$qd.sh"
  if [ -f "$qf" ]; then
    qdc=$(grep -v '^[[:space:]]*#' "$qf" | grep -cE 'runq|runseq|cdp\.py|verify\.sh')
    [ "$qdc" = 0 ] || qdbad="$qdbad $qd(Chrome:$qdc)"
  else qdbad="$qdbad $qd(missing)"; fi
done
# the floor keeps an emptied list from passing: with no drop-in named, nothing above could be wrong
qdok=0; [ -z "$qdbad" ] && ge "$qdn" "$MIN_QUICK_DROPINS" && qdok=1
rowif "quick drop-ins exist and are Chrome-free ($qdn ≥ $MIN_QUICK_DROPINS: $QUICK_DROPINS $QUICK_DROPINS_MUTATE)" [ "$qdok" = 1 ]
[ "$qdok" = 1 ] || echo "   ${qdbad:-too few}  (edit QUICK_DROPINS in tools/static.sh: a quick drop-in must not start Chrome; MIN_QUICK_DROPINS only goes up)"
HK=.githooks/pre-commit
# The call is pinned as a whole line: it must START with the subshell and END with the exit code capture, so a trailing
# comment, an `echo`, a `true` or a `:` in front cannot pass for it (the hook's behaviour is proved by hook-behavior, T2).
hkc=0
# shellcheck disable=SC2016   # the $ are literal text of the hook line, matched as such
[ -f "$HK" ] && hkc=$(grep -c '^( cd "\$tmp" && sh tools/quick\.sh hook ) > "\$tmp/quick\.out" 2>&1; rc=\$?$' "$HK")
hkok=0; [ -f "$HK" ] && [ -x "$HK" ] && [ "$hkc" -ge 1 ] && shellcheck -s sh "$HK" > /dev/null 2>&1 && hkok=1
rowif "git hook $HK: executable, shellcheck clean, runs sh tools/quick.sh ($hkc)" [ "$hkok" = 1 ]
ek=$(sed 's/^\([a-z0-9]*\) .*/\1/' "out/$P-env.txt" | tr '\n' ' '); xk=$(sed 's/^\([a-z0-9]*\) .*/\1/' tools/env-expected.txt 2>/dev/null | tr '\n' ' ')
ekok=0; [ -n "$ek" ] && [ "$ek" = "$xk" ] && ekok=1
rowif "environment report keys ($ek) = tools/env-expected.txt" [ "$ekok" = 1 ]
