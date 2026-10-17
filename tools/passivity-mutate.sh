#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/passivity-mutate.sh -- proves that every rule family of tools/passivity-check.sh can turn red.
# usage: sh tools/passivity-mutate.sh [--only NAME|alts] [--meta]      (any cwd; dev machine; sends nothing, opens no socket)
#   (default)    unmutated copy first (must be exit 0), then one FRESH copy per mutation with exactly ONE changed/added
#                line; the set of red rows must equal the pinned set; then the alternative probe (below).
#                Exit 0 = every line below matches, 1 = a miss, 2 = setup.
#   --only NAME  one mutation (used by --meta and for debugging); --only alts = the alternative probe alone
#   --meta       the probe of the probe: blinds one rule family, or ONE alternative of one, in an image of the checker and
#                demands that THIS script then reports GREEN (BLIND!) for the matching mutation / alternative.
# Alternative probe: the regex families of the checker (`--regexes`: NETSURF_RE, NETX, TX_WORDS, IW_VERBS, SEC6_RE) are split at
# their top-level `|`, DERIVED from the checker, not typed here. Every alternative needs exactly one planted sample in the
# table `alt` below (sample matches its own alternative and no other; count of alternatives pinned as MIN_ALTS_*): all
# samples of one file go in one copy, one checker run, and each must show up as its own line in the evidence of the expected
# row (the checker prints the offending lines under a red row). A thinned-out alternative is then `GREEN (BLIND!)`, a new
# or renamed one `UNCOVERED`, a table entry nobody's regex contains `ORPHAN`.
#
# GUARDS AGAINST: a rule of passivity-check.sh whose regex drifted (e.g. an object-prefixed `document.location = ...` that NETX
#                 does not match), was emptied, or lost ONE alternative (importScripts, hostapd, DEAUTH, sendBeacon ...) stays
#                 green forever, because nothing ever plants a violation.
# NEGATIVE PROBE: `sh tools/passivity-mutate.sh --meta` (also a regress row): NETX loses `window\.open\(|`, or the location
#                 alternative loses its object prefix, or one alternative of NETX/TX_WORDS/SEC6_RE/NETSURF_RE goes, or the
#                 sqlite3 rule reads the whole line again, or the hcitool row counts only `hcitool lescan` and lets other hcitool
#                 words through ⇒ the matching mutation/alternative prints GREEN (BLIND!), exit 1.
# NOT PROVEN:     proves nothing about behaviour, only that the SOURCE guard bites (a sqlite3 call through a variable or
#                 `command`, a method check outside the `case` in starchorus-serve.sh: seen by no rule, hence by no
#                 mutation); one example per alternative does not prove that every OTHER spelling of the same alternative hits
#                 (`location  =` with two blanks, other upper/lower case); alternatives in nested groups
#                 (`(assign|replace)`, `(-ng)?`) count as one, as do the alternatives of the rules without a family (`iw scan`, URLs,
#                 denylist words: there each has one line in the table); the alternatives probe reads the evidence lines under a
#                 red row, not its counter (the counter is the business of the row mutations). Every mutation is a text copy that never
#                 runs (the only call in copies is the checker itself, which only reads; see self_guard()).
# Rows are matched by prefix (their numbers change with the code). Mutations only ever touch COPIES in mktemp -d.
# Owners: the pinned sets belong to L; a legitimate K change that renames a row makes this script say which name to adjust.
# shellcheck disable=SC2016   # the mutation texts below are literal shell/JS source, not expansions
set -u
set -f
LC_ALL=C; export LC_ALL
here=$(cd "$(dirname "$0")" && pwd -P) || exit 2
R=$(cd "$here/.." && pwd -P) || exit 2
if ! { [ -f "$R/tools/passivity-check.sh" ] && [ -f "$R/starchorus.html" ]; }; then echo "passivity-mutate: repo files missing" >&2; exit 2; fi
me="$here/$(basename "$0")"

MIN_MUT=12    # mutations in the table (≥); count: sh tools/passivity-mutate.sh | grep -c '^mutation '
# alternatives per regex family (≥, only ever raised); count: sh tools/passivity-mutate.sh | grep -c '^alt <family> ' (family: netsurf 6, netx 19, tx 19, iw 3, sec6 21)
MIN_ALTS_NETSURF=6; MIN_ALTS_NETX=19; MIN_ALTS_TX=19; MIN_ALTS_IW=3; MIN_ALTS_SEC6=21
MIN_ROWS=13   # PASS rows of the unmutated copy (≥); count: sh tools/passivity-check.sh | grep -c ' PASS$'

# ---- 0 · the probe may only ever RUN the checker (and itself for --meta) on a copy: grep our own executable lines
self_guard() {
  _code=$(grep -v '^[[:space:]]*#' "$me")
  _cmd='(^|[;&|(])[[:space:]]*sh[[:space:]]'          # a line that starts the shell on something
  _n0=$(printf '%s\n' "$_code" | grep -cE "$_cmd")
  _n1=$(printf '%s\n' "$_code" | grep -cE "${_cmd}+tools/passivity-check\.sh")
  _n2=$(printf '%s\n' "$_code" | grep -cE "${_cmd}+\"\\\$_img/tools/passivity-mutate\.sh\"")
  _n3=$(printf '%s\n' "$_code" | grep -cE '[r]egress\.sh|[s]tatic\.sh|[q]uick\.sh|--[s]elftest|(^|[^A-Za-z_])(bash|dash|zsh|exec|eval|source)[[:space:]]|^[[:space:]]*"?\$[A-Za-z_{}]+/[^[:space:]]*\.sh')
  [ "$_n0/$_n1/$_n2/$_n3" = 2/1/1/0 ] || { echo "passivity-mutate: self guard failed (shell starts $_n0, checker $_n1, meta $_n2, forbidden $_n3; want 2/1/1/0)" >&2; return 1; }
}
self_guard || exit 2

tmp=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-pm.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT TERM

# ---- the pristine image every mutation starts from: what passivity-check.sh reads, and nothing else
base="$tmp/base"; work="$tmp/work"
mkdir -p "$base" || exit 2
for f in starchorus.html starchorus-collect.sh starchorus-display.sh payload.sh starchorus-serve.sh; do
  [ -f "$R/$f" ] || { echo "passivity-mutate: $f missing" >&2; exit 2; }
  cp "$R/$f" "$base/$f" || exit 2
done
cp -R "$R/tools" "$base/tools" && cp -R "$R/library" "$base/library" || exit 2

# The ONLY place a copy is executed. The checker reads files under its own root and prints rows; it starts nothing.
run_check() { ( cd "$1" && sh tools/passivity-check.sh ${2:+"$2"} ); }

# ---- mutation helpers (text only; no sed -i)
# lines of FILE containing the literal TEXT; a leading "^" anchors TEXT at the start of the line (the only special character:
# "selftest() {" alone is also a piece of "apcli_selftest() {")
nlit() { _t=$2 awk 'BEGIN { t = ENVIRON["_t"]; a = 0; if (substr(t, 1, 1) == "^") { a = 1; t = substr(t, 2) } }
  { i = index($0, t); if (a ? i == 1 : i > 0) n++ } END { print n + 0 }' "$1"; }
# replace the literal OLD by NEW in FILE (every line that has it; callers guarantee exactly one such line); "^" as in nlit
subst_lit() { _o=$2 _n=$3 awk 'BEGIN { o = ENVIRON["_o"]; n = ENVIRON["_n"]; a = 0; if (substr(o, 1, 1) == "^") { a = 1; o = substr(o, 2) } }
  { i = index($0, o); if (a ? i == 1 : i > 0) $0 = substr($0, 1, i - 1) n substr($0, i + length(o)); print }' "$1" > "$1.new" && mv "$1.new" "$1"; }
ensure_nl() { [ -z "$(tail -c 1 "$1")" ] || printf '\n' >> "$1"; }

# apply KIND FILE A B inside $work; returns 1 with a message when the target line is missing (phantom guard)
apply() {
  _kind=$1; _f="$work/$2"; _a=$3; _b=$4
  if [ "$_kind" = newfile ]; then   # a NEW file (no .sh suffix, say) with one function holding the text: the scope must reach it
    [ ! -e "$_f" ] || { echo "file $2 already exists (newfile wants a new one)" >&2; return 1; }
    printf '%s\n' '#!/bin/sh' 'zz_probe() {' "    $_a" '    :' '}' > "$_f" || return 1
    return 0
  fi
  [ -f "$_f" ] || { echo "no such file $2" >&2; return 1; }
  cp "$_f" "$tmp/before" || return 1
  case $_kind in
    append)   ensure_nl "$_f"; printf '%s\n' "$_a" >> "$_f" ;;
    fnappend) ensure_nl "$_f"; printf '%s\n' 'zz_probe() {' "    $_a" '    :' '}' >> "$_f" ;;
    subst)    _c=$(nlit "$_f" "$_a"); [ "$_c" = 1 ] || { echo "target text found on $_c lines of $2 (want exactly 1): $_a" >&2; return 1; }
              subst_lit "$_f" "$_a" "$_b" ;;
    denylist) _e=$(grep -v '^[[:space:]]*$' "$work/tools/denylist.txt" | head -n 1)
              [ -n "$_e" ] || { echo "tools/denylist.txt has no entry" >&2; return 1; }
              ensure_nl "$_f"; printf '%s\n' "// $_e" >> "$_f" ;;
    *) echo "unknown kind $_kind" >&2; return 1 ;;
  esac
  cmp -s "$tmp/before" "$_f" && { echo "mutation left $2 unchanged" >&2; return 1; }
  return 0
}

# ---- the rows of passivity-check.sh, by name prefix. Every one must be red at least once (coverage line below).
ROWS='§14.6 scope fill|HTML network surface|fetch( =|other network APIs|URLs outside|§14.6 device calls|§14.6 allowlist names|iw scan opt-in|transmit tools invoked|hcitool: only|sqlite3 read-only|starchorus-serve.sh: GET|§14.7 denylist'

sel=""; meta=0
while [ $# -gt 0 ]; do
  case $1 in
    --only) sel=${2:-}; [ -n "$sel" ] || { echo "usage: --only NAME" >&2; exit 2; }; shift 2 ;;
    --meta) meta=1; shift ;;
    *) echo "usage: sh $0 [--only NAME] [--meta]" >&2; exit 2 ;;
  esac
done

nmut=0; nok=0; ngreen=0; nwrong=0; nctl=0; nctlok=0; nsetup=0; setup_names=""; covered="|"
seen_sel=0

# mut NAME FILE KIND ARG1 ARG2 EXPECT   (EXPECT = "|"-separated row prefixes that must be red, and only those; "" = stays green)
mut() {
  _name=$1; _file=$2; _kind=$3; _a=$4; _b=$5; _exp=$6
  [ -z "$sel" ] || [ "$sel" = "$_name" ] || return 0
  seen_sel=1
  rm -rf "$work"; cp -R "$base" "$work" || { nsetup=$((nsetup + 1)); setup_names="$setup_names $_name"; return 0; }
  if ! apply "$_kind" "$_file" "$_a" "$_b" 2> "$tmp/err"; then
    printf 'mutation %s: SETUP-ERROR %s\n' "$_name" "$(cat "$tmp/err")"; nsetup=$((nsetup + 1)); setup_names="$setup_names $_name"; return 0
  fi
  run_check "$work" > "$tmp/out" 2>&1; _rc=$?
  # red rows: lines ending in FAIL that are not indented evidence
  grep ' FAIL$' "$tmp/out" | grep -v '^    ' > "$tmp/red"
  _got=""; _extra=""; _missing=""; _redp=""
  while IFS= read -r _r; do
    _hit=0; _ifs=$IFS; IFS='|'
    for _p in $_exp; do case $_r in "$_p"*) _hit=1; _got="$_got|$_p" ;; esac; done
    IFS=$_ifs
    [ "$_hit" = 1 ] || _extra="$_extra [$(printf '%s' "$_r" | cut -c1-60)]"
    _ifs=$IFS; IFS='|'; for _p in $ROWS; do case $_r in "$_p"*) covered="$covered$_p|"; _redp="${_redp}[$_p]" ;; esac; done; IFS=$_ifs
  done < "$tmp/red"
  _ifs=$IFS; IFS='|'; for _p in $_exp; do case "$_got|" in *"|$_p|"*|*"|$_p") ;; *) _missing="$_missing [$_p]" ;; esac; done; IFS=$_ifs
  _show=$_redp
  if [ -z "$_exp" ]; then
    nctl=$((nctl + 1))
    if [ "$_rc" = 0 ] && [ -z "$_extra" ]; then nctlok=$((nctlok + 1)); printf 'mutation %s: GREEN as expected (control, no row red)\n' "$_name"
    else nwrong=$((nwrong + 1)); printf 'mutation %s: WRONG-ROW red:%s (expected none)\n' "$_name" "$_extra"; fi
    return 0
  fi
  nmut=$((nmut + 1))
  if [ "$_rc" -ge 2 ]; then nwrong=$((nwrong + 1)); printf 'mutation %s: WRONG-ROW checker exit %s\n' "$_name" "$_rc"
  elif [ -n "$_missing" ]; then ngreen=$((ngreen + 1)); printf 'mutation %s: GREEN (BLIND!) missing red:%s (expected %s)%s\n' "$_name" "$_missing" "$_exp" "$([ -n "$_extra" ] && printf ', also red:%s' "$_extra")"
  elif [ -n "$_extra" ]; then nwrong=$((nwrong + 1)); printf 'mutation %s: WRONG-ROW red %s (expected %s)\n' "$_name" "$_show" "$_exp"
  else nok=$((nok + 1)); printf 'mutation %s: RED %s (expected %s)\n' "$_name" "$_show" "$_exp"; fi
}

# ============================== meta: the probe of the probe ==============================
if [ "$meta" = 1 ]; then
  nm=0; nmok=0
  # metaprobe NAME BLIND_FILE OLD NEW ONLY WANT: in an image of the repo, break the checker as described, then the copy of THIS
  # script run with `--only ONLY` must print a line starting with WANT (fixed text) and exit non-zero.
  metaprobe() {
    nm=$((nm + 1)); _img="$tmp/img$nm"; mkdir -p "$_img" || exit 2
    cp -R "$base/." "$_img/" || exit 2
    _c=$(nlit "$_img/$2" "$3")
    [ "$_c" = 1 ] || { printf 'meta %s: SETUP-ERROR target text on %s lines of %s (want 1)\n' "$1" "$_c" "$2"; return 0; }
    subst_lit "$_img/$2" "$3" "$4"
    sh "$_img/tools/passivity-mutate.sh" --only "$5" > "$tmp/meta.out" 2>&1; _mrc=$?
    if [ "$_mrc" != 0 ] && grep -qF -- "$6" "$tmp/meta.out"; then
      nmok=$((nmok + 1)); printf 'meta %s: detected (%s => exit %s, %s)\n' "$1" "$5" "$_mrc" "$6"
    else printf 'meta %s: NOT DETECTED, exit %s: %s\n' "$1" "$_mrc" "$(head -n 3 "$tmp/meta.out" | cut -c1-120 | tr '\n' ';')"; fi
  }
  # (a) NETX loses one alternative: window.open would pass unseen
  metaprobe netx-window-open tools/passivity-check.sh 'window\.open\(|' '' window-open 'mutation window-open: GREEN (BLIND!)'
  # (b) the object prefix of the location alternative is gone, the class excludes "." (an object-prefixed assignment escapes)
  metaprobe netx-location-prefix tools/passivity-check.sh '(^|[^A-Za-z0-9_])((document|top|parent|self|window)\.)?location' '(^|[^A-Za-z0-9_.])location' doc-location 'mutation doc-location: GREEN (BLIND!)'
  # (c) ONE alternative of a family goes (a row-level probe never saw these): the alternative probe names it
  metaprobe alt-netx-importscripts tools/passivity-check.sh 'importScripts|' '' alts 'alt netx importScripts: GREEN (BLIND!)'
  metaprobe alt-tx-hostapd tools/passivity-check.sh '|hostapd' '' alts 'alt tx hostapd: GREEN (BLIND!)'
  metaprobe alt-sec6-deauth tools/passivity-check.sh 'DEAUTH|' '' alts 'alt sec6 DEAUTH: GREEN (BLIND!)'
  metaprobe alt-netsurf-beacon tools/passivity-check.sh '|sendBeacon' '' alts 'alt netsurf sendBeacon: GREEN (BLIND!)'
  # (c2) the alternative stays in the regex, but the evidence the row prints no longer reads it (another family there): not listed
  metaprobe alt-netx-evidence-unwired tools/passivity-check.sh 'grep -nE "$NETX" "$H"' 'grep -nE "$NETSURF_RE" "$H"' alts 'alt netx RTCPeerConnection: GREEN (BLIND!) line'
  # (d) the sqlite3 rule must read only the code part of the line: reading the whole line lets a trailing `# -readonly` pass
  metaprobe sqlite-whole-line tools/passivity-check.sh 'if ((" " substr(seg, 1, cut - 1) " ") !~' 'if ((" " t " ") !~' sqlite-comment-flag 'mutation sqlite-comment-flag: GREEN (BLIND!)'
  # (e) the hcitool row counts only `hcitool lescan` without `--passive` and lets every other hcitool word through
  metaprobe hcitool-others-ignored tools/passivity-check.sh '[ "$nhi/$nhl" = 0/0 ]' '[ "$nhl" = 0 ]' bt-hcitool-other 'mutation bt-hcitool-other: GREEN (BLIND!)'
  printf 'passivity meta probe: %s/%s blinded checkers detected\n' "$nmok" "$nm"
  [ "$nm" -ge 2 ] && [ "$nmok" = "$nm" ]; exit $?
fi

# ============================== unmutated image first ==============================
if [ -z "$sel" ]; then
  run_check "$base" > "$tmp/base.out" 2>&1; brc=$?
  bpass=$(grep -c ' PASS$' "$tmp/base.out"); bfail=$(grep -c ' FAIL$' "$tmp/base.out")
  # every pinned row name must exist as a PASS row here, or the table talks about rows that are gone (phantom)
  phantom=""; _ifs=$IFS; IFS='|'
  for _p in $ROWS; do _p=$_p awk 'index($0, ENVIRON["_p"]) == 1 { f = 1 } END { exit !f }' "$tmp/base.out" || phantom="$phantom [$_p]"; done
  IFS=$_ifs
  printf 'unmutated image: checker exit %s, %s PASS rows (≥ %s), %s FAIL, rows not printed:%s\n' "$brc" "$bpass" "$MIN_ROWS" "$bfail" "${phantom:- none}"
  if [ "$brc" != 0 ] || [ "$bpass" -lt "$MIN_ROWS" ] || [ -n "$phantom" ]; then
    echo "passivity mutation probe: the unmutated copy is not green (or a pinned row name is gone): nothing to compare against" >&2
    sed 's/^/    /' "$tmp/base.out" | cut -c1-160 >&2; exit 1
  fi
fi

# ============================== the table: Name | file | mutation | rows that must be red ==============================
# name             | file               | kind      | text (old / new)                                        | expected red rows
# ---- page: the network surface
mut post-bare        starchorus.html    append   'var zz = {method:"POST"};' ''                                  'HTML network surface'
mut fetch-post       starchorus.html    append   'fetch("/x",{method:"POST"});' ''                               'HTML network surface|fetch( ='
mut fetch-second     starchorus.html    append   'fetch("starchorus.json");' ''                                       'fetch( ='
mut fetch-target     starchorus.html    subst    'fetch("starchorus.json?_=' 'fetch("starchorus.json.bak?_='               'fetch( ='
mut doc-location     starchorus.html    append   'document.location = "/cgi-bin/x?c=1";' ''                      'other network APIs'
mut window-open      starchorus.html    append   'window.open("/x");' ''                                         'other network APIs'
mut anchor-click     starchorus.html    append   'document.createElement("a").click();' ''                       'other network APIs'
mut new-image        starchorus.html    append   'new Image().src="/x";' ''                                      'other network APIs'
mut new-image-abs    starchorus.html    append   'new Image().src="http://127.0.0.1:9/x";' ''                    'other network APIs|URLs outside'
mut url-outside      starchorus.html    append   '// https://example.invalid/' ''                                'URLs outside'
mut denylist-entry   starchorus.html    denylist '' ''                                                           '§14.7 denylist'
# ---- collector: transmit tools, opt-in scan, device CLI, read-only recon.db
mut transmit-tool    starchorus-collect.sh     fnappend 'aireplay-ng -0 1 wlan0mon' ''                                  'transmit tools invoked'
mut iw-scan-stray    starchorus-collect.sh     fnappend 'iw dev wlan0 scan' ''                                          'iw scan opt-in'
mut default-flip     starchorus-collect.sh     subst    'ALLOW_ACTIVE=${STARCHORUS_ALLOW_ACTIVE:-0}' 'ALLOW_ACTIVE=${STARCHORUS_ALLOW_ACTIVE:-1}' 'iw scan opt-in'
mut guard-removed    starchorus-collect.sh     subst    '[ "$ALLOW_ACTIVE" = "1" ] || return 1' ':'                      'iw scan opt-in'
mut apcli-call       starchorus-collect.sh     fnappend '_pineap RECON ALL' ''                                          '§14.6 device calls'
mut readonly-gone    starchorus-collect.sh     subst    'sqlite3 -readonly -noheader' 'sqlite3 -noheader'               'sqlite3 read-only'
mut sqlite-write-fn  starchorus-collect.sh     fnappend 'sqlite3 "$db" "DELETE FROM t"' ''                              'sqlite3 read-only'
mut sqlite-vanished  starchorus-collect.sh     subst    'sqlite3 -readonly -noheader' 'sq_lite -readonly -noheader'     'sqlite3 read-only'
mut sqlite-comment-flag starchorus-collect.sh  fnappend 'sqlite3 "$db" "DELETE FROM t" # -readonly' ''                   'sqlite3 read-only'
mut sqlite-two-calls starchorus-collect.sh     fnappend 'sqlite3 -readonly a "SELECT 1"; sqlite3 "$db" "DELETE FROM t"' '' 'sqlite3 read-only'
mut sqlite-flag-in-string starchorus-collect.sh fnappend 'sqlite3 "$db" "SELECT '"'"'-readonly '"'"'"' ''                'sqlite3 read-only'
mut sqlite-after-hash starchorus-collect.sh    fnappend 'printf "%s #" x; sqlite3 "$db" "DELETE FROM t"' ''            'sqlite3 read-only'
# ---- the firmware's outward commands by prefix, and the Bluetooth tools: a prefix hits what it has not listed by name (WIFI_PCAP_ + anything);
# `hcitool lescan --passive` is the one hcitool call that passes, a second call on the same line or a spelling that is not the literal does not
mut prefix-family    starchorus-collect.sh     fnappend 'WIFI_PCAP_NEW_VERB x' ''                                       '§14.6 device calls'
mut prefix-vpn       starchorus-collect.sh     fnappend 'OPENVPN_NEW_VERB x' ''                                         '§14.6 device calls'
mut bt-transmit      starchorus-collect.sh     fnappend 'l2ping -c 1 x' ''                                              'transmit tools invoked'
mut bt-hcitool-scan  starchorus-collect.sh     fnappend 'hcitool scan' ''                                               'transmit tools invoked|hcitool: only'
mut bt-hcitool-lescan starchorus-collect.sh    fnappend 'hcitool lescan' ''                                             'hcitool: only'
mut bt-hcitool-lescan-opt starchorus-collect.sh fnappend 'hcitool lescan --duplicates --passive' ''                     'hcitool: only'
mut bt-hcitool-other starchorus-collect.sh     fnappend 'hcitool name x' ''                                             'hcitool: only'
mut bt-hcitool-second starchorus-collect.sh    fnappend 'hcitool lescan --passive; hcitool name x' ''                   'hcitool: only'
mut bt-hcitool-display starchorus-display.sh   fnappend 'hcitool lescan' ''                                             'hcitool: only'
mut bt-hcitool-helper library/user/reconnaissance/starchorus/helper newfile 'hcitool name x' ''                         'hcitool: only'
mut bt-hciconfig-up  starchorus-collect.sh     fnappend 'hciconfig hci0 up' ''                                          'transmit tools invoked'
mut bt-hciconfig-a-up starchorus-collect.sh    fnappend 'hciconfig -a hci0 leadv' ''                                    'transmit tools invoked'
# ---- display script (one of the two copies; the cmp of the copies belongs to static checks, not here)
mut display-transmit starchorus-display.sh       fnappend 'mdk4 wlan0mon d' ''                                            'transmit tools invoked'
# ---- the listener (starchorus-serve.sh is in the §14.6 shell scope: a transmit tool in it is seen, and losing it from the list is named)
mut serve-transmit   starchorus-serve.sh       fnappend 'aireplay-ng -0 1 wlan0mon' ''                                  'transmit tools invoked'
# ---- the payload directory ships to the device as a whole: its payload.sh and a helper WITHOUT the .sh suffix are in scope
mut library-payload-transmit library/user/reconnaissance/starchorus/payload.sh fnappend 'aireplay-ng -0 1 wlan0mon' '' 'transmit tools invoked'
mut library-helper-transmit library/user/reconnaissance/starchorus/helper newfile 'mdk4 wlan0mon d' ''              'transmit tools invoked'
mut serve-out-of-scope tools/passivity-check.sh subst 'payload.sh starchorus-serve.sh; find' 'payload.sh; find'          '§14.6 scope fill'
mut serve-third-path starchorus-serve.sh       subst    '/|/index.html) f=' '/|/index.html|/x) f='                      'starchorus-serve.sh: GET'
mut serve-post       starchorus-serve.sh       subst    'case "$method" in GET|HEAD) : ;;' 'case "$method" in GET|HEAD|POST) : ;;' 'starchorus-serve.sh: GET'
mut serve-no-block   starchorus-serve.sh       subst    'case "$path" in' 'case "$pth" in'                              'starchorus-serve.sh: GET'
# ---- the checker's own guards
mut sec6-undefined   tools/passivity-check.sh subst "SEC6_FUNCS=' apcli_ro apcli_stub apcli_selftest '" "SEC6_FUNCS=' apcli_ro apcli_stub apcli_selftest zz_undefined '" '§14.6 allowlist names'
# a function head the scope awk no longer recognises: its hits are read as "outside", and the fill probe names the loss
mut fnhead-oneliner  starchorus-collect.sh     subst    'run_cycle() {' 'run_cycle() { :'                                '§14.6 scope fill'
mut fnhead-selftest  starchorus-collect.sh     subst    '^selftest() {' 'selftest() { :'                                  '§14.6 scope fill|sqlite3 read-only'
# ---- control: a comment line is not a call (scoped() skips comments); a deviation here would be a finding
mut comment-only     starchorus-collect.sh     fnappend '# aireplay-ng -0 1 wlan0mon' ''                                ''
mut sqlite-ok-comment starchorus-collect.sh    fnappend 'sqlite3 -readonly -noheader "$db" "SELECT 1"   # read only' ''  ''
mut sqlite-ok-two    starchorus-collect.sh     fnappend 'sqlite3 -readonly "$db" "SELECT 1" && sqlite3 -readonly "$db" "SELECT 2"' '' ''
mut bt-hcitool-passive-ok starchorus-collect.sh fnappend 'hcitool lescan --passive' ''                                     ''
mut bt-btmon-ok      starchorus-collect.sh     fnappend 'btmon -w /tmp/x' ''                                            ''
mut bt-hciconfig-ok  starchorus-collect.sh     fnappend 'hciconfig -a | head -n 5; hciconfig; hciconfig -a >/tmp/x' ''  ''

# ============================== alternatives: one planted sample per regex alternative ==============================
# alt FAMILY KEY SAMPLE ROW : KEY is a literal piece of exactly ONE alternative of the family (as `sh tools/passivity-check.sh
# --regexes` prints it), SAMPLE the violation text (planted on its own line; it must match that alternative and no other),
# ROW the row prefix under which the checker has to list that line. Families: netsurf, netx (page); tx, iw, sec6 (collector).
altfile="$tmp/alttab"; : > "$altfile"
alt() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$altfile"; }
alt netsurf 'method:'           'var zz = {method:"x"};'                          'HTML network surface'
alt netsurf 'POST'              'var zz = "POST";'                                'HTML network surface'
alt netsurf 'XMLHttpRequest'    'var zz = new XMLHttpRequest();'                  'HTML network surface'
alt netsurf 'WebSocket'         'var zz = new WebSocket("x");'                    'HTML network surface'
alt netsurf 'EventSource'       'var zz = new EventSource("x");'                  'HTML network surface'
alt netsurf 'sendBeacon'        'navigator.sendBeacon("x");'                      'HTML network surface'
alt netx 'RTCPeerConnection'    'var zz = new RTCPeerConnection();'               'other network APIs'
alt netx 'WebTransport'         'var zz = new WebTransport("x");'                 'other network APIs'
alt netx 'serviceWorker'        'navigator.serviceWorker.register("x");'          'other network APIs'
alt netx 'Shared)?Worker'       'var zz = new Worker("x");'                       'other network APIs'
alt netx 'importScripts'        'importScripts("x");'                             'other network APIs'
alt netx 'import\('             'var zz = import("x");'                           'other network APIs'
alt netx 'window\.open'         'window.open("x");'                               'other network APIs'
alt netx 'location\.(assign'    'location.assign("x");'                           'other network APIs'
alt netx ')?location(\.href)?'  'document.location = "x";'                        'other network APIs'
alt netx 'createElement\('      'var zz = document.createElement("a");'           'other network APIs'
alt netx '\.click\('            'zz.click();'                                     'other network APIs'
alt netx 'download='            'zz.download="x";'                                'other network APIs'
alt netx '<form'                'var zz = "<form>";'                              'other network APIs'
alt netx '<iframe'              'var zz = "<iframe>";'                            'other network APIs'
alt netx 'new Image'            'var zz = new Image();'                           'other network APIs'
alt netx '<link'                'var zz = "<link>";'                              'other network APIs'
alt netx '<script[^>]+src='     'var zz = "<script src=x>";'                      'other network APIs'
alt netx '@import'              'var zz = "@import x";'                           'other network APIs'
alt netx 'url\('                'var zz = "url(https://x.invalid/a)";'            'other network APIs'
alt tx 'aireplay'               'aireplay-ng -0 1 wlan0mon'                       'transmit tools invoked'
alt tx 'mdk['                   'mdk4 wlan0mon d'                                 'transmit tools invoked'
alt tx 'hostapd'                'hostapd /tmp/x.conf'                             'transmit tools invoked'
alt tx 'airbase'                'airbase-ng -e x wlan0mon'                        'transmit tools invoked'
alt tx 'hcxdumptool'            'hcxdumptool -i wlan0mon'                         'transmit tools invoked'
alt tx 'wpa_supplicant'         'wpa_supplicant -i wlan0mon -c /tmp/x'            'transmit tools invoked'
alt tx 'nmcli'                  'nmcli dev wifi list'                             'transmit tools invoked'
alt tx 'iwlist'                 'iwlist wlan0mon frequency'                       'transmit tools invoked'
alt tx 'hcitool[[:space:]]+scan'  'hcitool scan'                                    'transmit tools invoked'
alt tx 'hcitool[[:space:]]+inq'   'hcitool inq'                                     'transmit tools invoked'
alt tx 'hcitool[[:space:]]+cc'    'hcitool cc'                                      'transmit tools invoked'
alt tx 'hcitool[[:space:]]+lecc'  'hcitool lecc'                                    'transmit tools invoked'
alt tx 'hcitool[[:space:]]+leadv' 'hcitool leadv'                                   'transmit tools invoked'
alt tx 'hcitool[[:space:]]+cmd'   'hcitool cmd'                                     'transmit tools invoked'
alt tx 'l2ping'                   'l2ping -c 1 x'                                   'transmit tools invoked'
alt tx 'bluetoothctl['            'bluetoothctl scan on'                            'transmit tools invoked'
alt tx 'btmgmt'                   'btmgmt find'                                     'transmit tools invoked'
alt tx 'gatttool'                 'gatttool -I'                                     'transmit tools invoked'
alt tx 'hciconfig('               'hciconfig hci0 up'                               'transmit tools invoked'
alt iw 'connect'                'iw dev wlan0mon connect x'                       'transmit tools invoked'
alt iw 'ibss['                  'iw dev wlan0mon ibss join x 2412'                'transmit tools invoked'
alt iw 'mesh['                  'iw dev wlan0mon mesh join x'                     'transmit tools invoked'
alt sec6 '_pineap'              '_pineap RECON ALL'                               '§14.6 device calls'
alt sec6 'PINEAPPLE_'           'PINEAPPLE_X=1'                                   '§14.6 device calls'
alt sec6 'WIGLE_'               'WIGLE_X=1'                                       '§14.6 device calls'
alt sec6 'DEAUTH'               'DEAUTH=1'                                        '§14.6 device calls'
alt sec6 'SSID_POOL'            'SSID_POOL=x'                                     '§14.6 device calls'
alt sec6 'GPS_GET'              'GPS_GET=1'                                       '§14.6 device calls'
alt sec6 'WIFI_CONNECT'         'WIFI_CONNECT=1'                                  '§14.6 device calls'
alt sec6 'WIFI_DISCONNECT'      'WIFI_DISCONNECT=1'                               '§14.6 device calls'
alt sec6 'WIFI_MGMT_AP'         'WIFI_MGMT_AP=1'                                  '§14.6 device calls'
alt sec6 'WIFI_OPEN_AP'         'WIFI_OPEN_AP=1'                                  '§14.6 device calls'
alt sec6 'WIFI_WPA_AP'          'WIFI_WPA_AP=1'                                   '§14.6 device calls'
alt sec6 'WIFI_PCAP_'           'WIFI_PCAP_START=1'                               '§14.6 device calls'
alt sec6 'INSTALL_FIRMWARE'     'INSTALL_FIRMWARE=x'                              '§14.6 device calls'
alt sec6 'OPENVPN_'             'OPENVPN_START=1'                                 '§14.6 device calls'
alt sec6 'WIREGUARD_'           'WIREGUARD_START=1'                               '§14.6 device calls'
alt sec6 'AUTOSSH_'             'AUTOSSH_START=1'                                 '§14.6 device calls'
alt sec6 'SSH_ADD_KNOWN_HOST'   'SSH_ADD_KNOWN_HOST=x'                            '§14.6 device calls'
alt sec6 'DNSSPOOF_'            'DNSSPOOF_START=1'                                '§14.6 device calls'
alt sec6 'SYSTEM_DNS'           'SYSTEM_DNS=x'                                    '§14.6 device calls'
alt sec6 'GPS_CONFIGURE'        'GPS_CONFIGURE=1'                                 '§14.6 device calls'
alt sec6 'FIND_CLIENT_IP'       'FIND_CLIENT_IP=x'                                '§14.6 device calls'

TAB=$(printf '\t')
# the top-level alternatives of the ERE in $1, one per line (depth 0 of `(...)`, `[...]` classes and `\x` escapes respected)
split_alts() {
  _re=$1 awk 'BEGIN { s = ENVIRON["_re"]; n = length(s); d = 0; cls = 0; cur = ""
    for (i = 1; i <= n; i++) {
      c = substr(s, i, 1)
      if (c == "\\") { cur = cur c substr(s, i + 1, 1); i++; continue }
      if (cls) {
        if (c == "[" && substr(s, i + 1, 1) == ":") { j = index(substr(s, i), ":]"); cur = cur substr(s, i, j + 1); i += j; continue }
        if (c == "]") cls = 0
        cur = cur c; continue }
      if (c == "[") { cls = 1; cur = cur c; if (substr(s, i + 1, 1) == "^") { cur = cur "^"; i++ } continue }
      if (c == "(") d++
      if (c == ")") d--
      if (c == "|" && d == 0) { print cur; cur = ""; continue }
      cur = cur c }
    print cur }'
}
min_alts() { case $1 in netsurf) echo "$MIN_ALTS_NETSURF";; netx) echo "$MIN_ALTS_NETX";; tx) echo "$MIN_ALTS_TX";; iw) echo "$MIN_ALTS_IW";; *) echo "$MIN_ALTS_SEC6";; esac; }
na=0; naok=0; nablind=0; nawrong=0; nauncov=0; nasetup=0; nafam=0; naderived=0

# run_group FILE KIND FAMILIES: every entry of those families planted in ONE copy (kind append = a line, fn = a function), one
# checker run, then each sample's own line must appear in the evidence of its row
run_group() {
  _gf="$work/$1"; _kind=$2; _fams=" $3 "
  rm -rf "$work"; cp -R "$base" "$work" || { nasetup=$((nasetup + 1)); return 0; }
  ensure_nl "$_gf"; _c=$(wc -l < "$_gf" | tr -d ' '); : > "$tmp/grp"
  while IFS="$TAB" read -r _f _k _sm _rw _st; do
    case $_fams in *" $_f "*) ;; *) continue ;; esac
    if [ "$_kind" = fn ]; then
      printf '%s\n' "zz_alt$_c() {" "    $_sm" '    :' '}' >> "$_gf"; _at=$((_c + 2)); _c=$((_c + 4))
    else printf '%s\n' "$_sm" >> "$_gf"; _c=$((_c + 1)); _at=$_c; fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$_f" "$_k" "$_rw" "$_at" "$_st" >> "$tmp/grp"
  done < "$tmp/ents"
  run_check "$work" > "$tmp/aout" 2>&1; _arc=$?
  [ "$_arc" -lt 2 ] || { nasetup=$((nasetup + 1)); echo "alt probe: the checker exited $_arc on the planted copy" >&2; return 0; }
  # evidence: "row<TAB>indented evidence line" for every indented line under a row
  awk 'BEGIN { OFS = "\t" } /^    / { if (row != "") print row, $0; next } { row = $0 }' "$tmp/aout" > "$tmp/ev"
  while IFS="$TAB" read -r _f _k _rw _at _st; do
    na=$((na + 1))
    _rows=$(awk -F'\t' -v L="$_at" '{ e = $2; sub(/^    /, "", e); n = split(e, a, ":"); v = (a[1] ~ /^[0-9]+$/) ? a[1] : a[2]; if (v == L) print $1 }' "$tmp/ev")
    _hit=0; _other=""
    while IFS= read -r _r; do
      [ -n "$_r" ] || continue
      case $_r in "$_rw"*) _hit=1 ;; *) _other="$_other [$(printf '%s' "$_r" | cut -c1-40)]" ;; esac
    done <<EOF
$_rows
EOF
    if [ "$_st" = orphan ]; then nablind=$((nablind + 1)); printf 'alt %s %s: GREEN (BLIND!) no alternative of the checker contains this key any more (removed, or renamed: adjust the table)\n' "$_f" "$_k"
    elif [ "$_hit" = 0 ]; then nablind=$((nablind + 1)); printf 'alt %s %s: GREEN (BLIND!) line %s not listed under "%s"\n' "$_f" "$_k" "$_at" "$_rw"
    elif [ -n "$_other" ]; then nawrong=$((nawrong + 1)); printf 'alt %s %s: WRONG-ROW also listed under:%s\n' "$_f" "$_k" "$_other"
    else naok=$((naok + 1)); printf 'alt %s %s: RED %s (line %s)\n' "$_f" "$_k" "$_rw" "$_at"; fi
  done < "$tmp/grp"
}

alt_probe() {
  if ! run_check "$base" --regexes > "$tmp/rx" 2> "$tmp/rx.err" || [ ! -s "$tmp/rx" ]; then
    echo "alt probe: the checker prints no regex families (--regexes)" >&2; nasetup=$((nasetup + 1)); return 0; fi
  : > "$tmp/ents"
  for _spec in netsurf:NETSURF_RE netx:NETX tx:TX_WORDS iw:IW_VERBS sec6:SEC6_RE; do
    _fam=${_spec%%:*}; _var=${_spec#*:}
    _re=$(awk -F'\t' -v N="$_var" '$1 == N { print $2; exit }' "$tmp/rx")
    split_alts "$_re" > "$tmp/alts.$_fam"; _n=$(grep -c '' "$tmp/alts.$_fam")
    nafam=$((nafam + 1)); naderived=$((naderived + _n))
    if [ "$_n" -lt "$(min_alts "$_fam")" ]; then
      printf 'alt %s: SETUP-ERROR %s alternatives derived from %s (want at least %s)\n' "$_fam" "$_n" "$_var" "$(min_alts "$_fam")"; nasetup=$((nasetup + 1)); fi
    # every derived alternative needs a sample
    while IFS= read -r _a; do
      _hit=0
      while IFS="$TAB" read -r _f _k _sm _rw; do
        [ "$_f" = "$_fam" ] || continue
        case $_a in *"$_k"*) _hit=$((_hit + 1)) ;; esac
      done < "$altfile"
      [ "$_hit" -ge 1 ] || { nauncov=$((nauncov + 1)); printf 'alt %s: UNCOVERED alternative %s (no sample in the table: add one line, or the alternative is new)\n' "$_fam" "$_a"; }
    done < "$tmp/alts.$_fam"
    # every table entry: one alternative contains its key, that one matches the sample, no other does
    while IFS="$TAB" read -r _f _k _sm _rw; do
      [ "$_f" = "$_fam" ] || continue
      _cnt=0; _own=""
      while IFS= read -r _a; do case $_a in *"$_k"*) _cnt=$((_cnt + 1)); _own=$_a ;; esac; done < "$tmp/alts.$_fam"
      _st=ok
      if [ "$_cnt" = 0 ]; then _st=orphan
      elif [ "$_cnt" -gt 1 ]; then _st=bad; printf 'alt %s %s: SETUP-ERROR key stands in %s alternatives (want 1)\n' "$_fam" "$_k" "$_cnt"; nasetup=$((nasetup + 1))
      else
        _m=0; while IFS= read -r _a; do printf '%s\n' "$_sm" | grep -qE -- "$_a" && _m=$((_m + 1)); done < "$tmp/alts.$_fam"
        if ! { printf '%s\n' "$_sm" | grep -qE -- "$_own" && [ "$_m" = 1 ]; }; then _st=bad; printf 'alt %s %s: SETUP-ERROR sample matches %s alternatives of the family, its own included or not (want exactly its own)\n' "$_fam" "$_k" "$_m"; nasetup=$((nasetup + 1)); fi
      fi
      [ "$_st" = bad ] || printf '%s\t%s\t%s\t%s\t%s\n' "$_f" "$_k" "$_sm" "$_rw" "$_st" >> "$tmp/ents"
    done < "$altfile"
  done
  run_group starchorus.html append 'netsurf netx'
  run_group starchorus-collect.sh fn 'tx iw sec6'
  printf 'alternatives: %s/%s planted samples red on their row (%s families, %s alternatives derived), %s uncovered, %s blind, %s wrong-row\n' "$naok" "$na" "$nafam" "$naderived" "$nauncov" "$nablind" "$nawrong"
}
alt_ok() { [ "$na" -ge 1 ] && [ "$naok" = "$na" ] && [ "$nauncov" = 0 ] && [ "$nablind" = 0 ] && [ "$nawrong" = 0 ] && [ "$nasetup" = 0 ]; }

if [ "$sel" = alts ]; then alt_probe; alt_ok; exit $?; fi
if [ -n "$sel" ]; then
  [ "$seen_sel" = 1 ] || { echo "passivity-mutate: no mutation named $sel" >&2; exit 2; }
  [ "$nsetup" = 0 ] && [ "$ngreen" = 0 ] && [ "$nwrong" = 0 ]; exit $?
fi
alt_probe

# ============================== verdict ==============================
uncovered=""; _ifs=$IFS; IFS='|'; for _p in $ROWS; do case "$covered" in *"|$_p|"*) ;; *) uncovered="$uncovered [$_p]" ;; esac; done; IFS=$_ifs
nrows=$(printf '%s\n' "$ROWS" | tr '|' '\n' | wc -l | tr -d ' ')
printf 'row coverage: every checker row red at least once, not yet red:%s\n' "${uncovered:- none}"
printf 'control mutations: %s/%s stayed green\n' "$nctlok" "$nctl"
# The closing line names a SETUP-ERROR: a legitimate reformatting of a target line in the collector/page (a line break, a
# changed option order) makes the mutation's target text vanish; "N/N red, 0 green" would say nothing about that and exit 1
# without a word on what to adapt. So the row says what to change and where.
if [ "$nsetup" != 0 ] || [ "${nasetup:-0}" != 0 ]; then
  printf 'passivity mutation probe: SETUP-ERROR in %s mutation(s) [%s] and %s alternative table entries: a target text was not found exactly once (or a family too small); %s/%s red on the expected rows, %s green, %s wrong-row; %s/%s alternatives red, %s uncovered. Nothing is proven for the failed ones. Fix: after a legitimate edit of the collector/page/display line, update the target text of that entry in the mut/alt table of tools/passivity-mutate.sh (grep -nE "^mut +(%s) " tools/passivity-mutate.sh) to the new wording of the file, or restore the line; then rerun.\n' \
    "$nsetup" "${setup_names# }" "${nasetup:-0}" "$nok" "$nmut" "$ngreen" "$nwrong" "$naok" "$na" "$nauncov" "$(printf '%s' "${setup_names# }" | tr ' ' '|')"
  exit 1
fi
printf 'passivity mutation probe: %s/%s red on the expected rows, %s green, %s wrong-row; %s/%s alternatives red, %s uncovered\n' "$nok" "$nmut" "$ngreen" "$nwrong" "$naok" "$na" "$nauncov"
[ "$nmut" -ge "$MIN_MUT" ] && [ "$nok" = "$nmut" ] && [ "$nctlok" = "$nctl" ] && [ -z "$uncovered" ] && [ "$nrows" -ge "$MIN_ROWS" ] && alt_ok
exit $?
