#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/passivity-check.sh -- static passivity + legal checks (spec §14.2, §14.6, §14.7).
# usage: sh tools/passivity-check.sh [--files|--regexes]   (any cwd; reads repo files only, sends nothing; --files = print the shell file list of the §14.6 scope;
#        --regexes = print "NAME<TAB>regex" of the alternation families the rows use, tools/passivity-mutate.sh splits them per alternative)
# Prints one PASS/FAIL row per check; exit 0 = all PASS, 1 = at least one FAIL, 2 = setup problem.
# Every row here has a planted violation in tools/passivity-mutate.sh: a row renamed or a rule widened makes that script
# say which name/mutation to adjust. The sqlite3 (-readonly) and starchorus-serve.sh rows are covered the same way.
set -u
here=$(cd "$(dirname "$0")" && pwd -P) || exit 2
R=$(cd "$here/.." && pwd -P) || exit 2
cd "$R" || exit 2
H=starchorus.html
DISPLAY_COPY=library/user/reconnaissance/starchorus/starchorus-display.sh
# shellcheck disable=SC2015   # every term is a side-effect-free [ -f ] test; || is the intended guard clause
[ -f "$H" ] && [ -f starchorus-collect.sh ] && [ -f starchorus-display.sh ] && [ -f "$DISPLAY_COPY" ] || { echo "passivity-check: repo files missing" >&2; exit 2; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-pc.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT TERM
fail=0
row() { printf '%-44s %s\n' "$1" "$2"; [ "$2" = PASS ] || fail=1; }
rowif() { _n=$1; shift; if "$@"; then row "$_n" PASS; else row "$_n" FAIL; fi; }
show() { sed 's/^/    /' | cut -c1-200; }   # stdin as indented evidence under a FAIL row
lines() { wc -l < "$1" | tr -d ' '; }

# Shell files of the §14.6 check: collector, both dashboards, root payload.sh, the nc listener starchorus-serve.sh (it is in the
# denylist file set, so it belongs to the shell scope too), every file under library/ except its Markdown docs (the payload
# directory ships to the device as a whole, so a helper without the .sh suffix is in scope too). `--files` prints this list and
# exits (tools/regress.d/doc-truth.sh compares it with the shell files the repository really has, both ways).
{ printf '%s\n' starchorus-collect.sh starchorus-display.sh payload.sh starchorus-serve.sh; find library -type f ! -name '*.md' | LC_ALL=C sort; } | awk '!seen[$0]++' > "$tmp/shfiles"
[ "${1:-}" != --files ] || { cat "$tmp/shfiles"; exit 0; }
# Regex families: ONE definition of every alternation the rows below use. `--regexes` prints them; tools/passivity-mutate.sh
# splits each at its top-level `|` and demands one planted violation per ALTERNATIVE (a thinned-out alternative stays unseen by
# a row-level probe). Keep them flat: a new alternative goes on the top level, and needs one line in that script's table.
NETSURF_RE='method:|POST|XMLHttpRequest|WebSocket|EventSource|sendBeacon'
# Navigation is a command path too: `document.location = "/cgi-bin/x?cmd=…"` sends the query to the device
# just as a fetch would, bare or object-prefixed (document./window./top./parent./self.). A JS-built anchor
# (createElement("a") + .click() / download=) is the same hole without the word "location".
NETX='RTCPeerConnection|WebTransport|serviceWorker|new (Shared)?Worker\(|importScripts|import\(|window\.open\(|location\.(assign|replace)\(|(^|[^A-Za-z0-9_])((document|top|parent|self|window)\.)?location(\.href)?[[:space:]]*=[^=]|createElement\(["'"'"'`]a["'"'"'`]\)|\.click\(|download=|<form|<iframe|new Image\(|<link|<script[^>]+src=|@import|url\(["'"'"']?https?:'
SEC6_RE='_pineap|PINEAPPLE_|WIGLE_|DEAUTH|SSID_POOL|GPS_GET'
TX_WORDS='aireplay(-ng)?|mdk[34]|hostapd|airbase(-ng)?|hcxdumptool|wpa_supplicant|nmcli|iwlist'
IW_VERBS='connect|ibss[[:space:]]+join|mesh[[:space:]]+join'
TX_RE="(^|[^A-Za-z0-9_-])($TX_WORDS)([^A-Za-z0-9_]|\$)|(^|[^A-Za-z_])iw[[:space:]].*[[:space:]]($IW_VERBS)([^A-Za-z_]|\$)"
[ "${1:-}" != --regexes ] || {
  for _n in NETSURF_RE NETX SEC6_RE TX_WORDS IW_VERBS; do
    case $_n in NETSURF_RE) _v=$NETSURF_RE;; NETX) _v=$NETX;; SEC6_RE) _v=$SEC6_RE;; TX_WORDS) _v=$TX_WORDS;; *) _v=$IW_VERBS;; esac
    printf '%s\t%s\n' "$_n" "$_v"
  done; exit 0; }
# Enclosing top-level shell function of every matching line; comment-only lines skipped. A one-line
# function `f() { …; }` does not open a scope, so hits there count as "outside" (conservative).
# FNDEF is the ONE definition of "a function head the scope check recognises" (shared by the scope awk and the
# fill probe below through ENVIRON, so the two cannot drift apart).
FNDEF='^[A-Za-z_][A-Za-z0-9_]*[ \t]*\([ \t]*\)[ \t]*\{?[ \t]*(#.*)?$'
export FNDEF
# shellcheck disable=SC2016   # awk program: $0 is awk's field, not a shell expansion
FNSCOPE='BEGIN { RE = ENVIRON["SCOPE_RE"]; DEF = ENVIRON["FNDEF"] }
FNR == 1 { fn = "-" }
$0 ~ DEF { fn = $0; sub(/[ \t]*\(.*/, "", fn) }
{ if ($0 ~ RE && $0 !~ /^[ \t]*#/) print FILENAME ":" FNR ":" fn ":" $0 }
/^}/ { fn = "-" }'
scoped() { # scoped ERE → "file:line:function:text" over $tmp/shfiles (ERE via ENVIRON: no awk -v escape mangling)
  while IFS= read -r _f; do SCOPE_RE=$1 awk "$FNSCOPE" "$_f"; done < "$tmp/shfiles"
}
# shellcheck disable=SC2016   # awk program
fnlist() { # "file:function" of every function head the scope check recognises, over $tmp/shfiles
  while IFS= read -r _f; do
    awk 'BEGIN { DEF = ENVIRON["FNDEF"] } $0 ~ DEF { fn = $0; sub(/[ \t]*\(.*/, "", fn); print FILENAME ":" fn }' "$_f"
  done < "$tmp/shfiles"
}

# 0 · fill probe: every "outside the allowlist" / "stray" row below reads its hits through scoped(); a file list that
# lost a shell file, or a function head the awk no longer recognises, would turn those rows green by looking at
# less. So the scope is checked by NAME and by a floor, not just counted.
MIN_FNSCOPE=95   # functions recognised over the shell files: fnlist | wc -l  (103: collector 58, each display script 21, each payload.sh 1, starchorus-serve.sh 1)
fnlist > "$tmp/fns"
nfn=$(lines "$tmp/fns"); nsh=$(lines "$tmp/shfiles")
miss=""
for w in starchorus-collect.sh starchorus-display.sh starchorus-serve.sh "$DISPLAY_COPY" payload.sh library/user/reconnaissance/starchorus/payload.sh; do
  grep -qxF "$w" "$tmp/shfiles" || miss="$miss $w"
done
while IFS= read -r w; do [ -f "$w" ] || miss="$miss $w(no such file)"; done < "$tmp/shfiles"   # a listed file that is gone is read as empty
for w in build_from_iwscan run_cycle selftest; do grep -qxF "starchorus-collect.sh:$w" "$tmp/fns" || miss="$miss starchorus-collect.sh:$w()"; done
fillok=0; [ "$nsh" -ge 4 ] && [ "$nfn" -ge "$MIN_FNSCOPE" ] && [ -z "$miss" ] && fillok=1
rowif "§14.6 scope fill: $nsh files, $nfn functions (≥ $MIN_FNSCOPE), unseen:${miss:- none}" [ "$fillok" = 1 ]

# 1-4 · browser page: the only network call is fetch("starchorus.json…") (§14.2 Passiv; operator-tools.sh repeats 1+2 for homing)
n=$(grep -cE "$NETSURF_RE" "$H")
rowif "HTML network surface = $n (want 0)" [ "$n" = 0 ]
[ "$n" = 0 ] || grep -nE "$NETSURF_RE" "$H" | show
# the target is exactly starchorus.json (a query string may follow, nothing else: "starchorus.json.bak" is another file)
nf=$(grep -o 'fetch(' "$H" | wc -l | tr -d ' '); nw=$(grep -oE 'fetch\("starchorus\.json[?"]' "$H" | wc -l | tr -d ' ')
rowif "fetch( = $nf, to starchorus.json = $nw (want 1/1)" [ "$nf/$nw" = 1/1 ]
nx=$(grep -cE "$NETX" "$H")
rowif "other network APIs in page = $nx (want 0)" [ "$nx" = 0 ]
[ "$nx" = 0 ] || grep -nE "$NETX" "$H" | show
# external URLs only in the font-licence header (section 00 / before the first marker)
nu=$(awk '/==== [0-9]+ /{match($0,/==== [0-9]+/); s=substr($0,RSTART+5,RLENGTH-5)} /https?:\/\//{if (s+0 != 0) n++} END{print n+0}' "$H")
rowif "URLs outside the §00 licence header = $nu" [ "$nu" = 0 ]

# 5 · §14.6 static check: device CLI words only inside the allowlist functions
SEC6_FUNCS=' apcli_ro apcli_stub apcli_selftest '   # the allowlist + its stub factory + its selftest
scoped "$SEC6_RE" > "$tmp/s6"
: > "$tmp/s6bad"; while IFS= read -r ln; do
  fn=$(printf '%s\n' "$ln" | cut -d: -f3)
  case "$SEC6_FUNCS" in *" $fn "*) ;; *) printf '%s\n' "$ln" >> "$tmp/s6bad" ;; esac
done < "$tmp/s6"
rowif "§14.6 device calls outside allowlist = $(lines "$tmp/s6bad") (hits $(lines "$tmp/s6"))" [ ! -s "$tmp/s6bad" ]
[ -s "$tmp/s6bad" ] && show < "$tmp/s6bad"
# The allowlist is one-sided by itself (a name nobody defines allows nothing and hides a typo), so the other
# direction is checked too: every SEC6_FUNCS name is defined in a shell file or announced in SEC6_NOT_YET.
SEC6_NOT_YET=' '              # announced, not defined yet (space-padded; empty: every listed name is defined)
cut -d: -f2 "$tmp/fns" | LC_ALL=C sort -u > "$tmp/fnames"
unex=""; stale=""; nlist=0
for f in $SEC6_FUNCS; do
  nlist=$((nlist + 1))
  if grep -qxF "$f" "$tmp/fnames"; then case "$SEC6_NOT_YET" in *" $f "*) stale="$stale $f";; esac
  else case "$SEC6_NOT_YET" in *" $f "*) ;; *) unex="$unex $f";; esac; fi
done
for f in $SEC6_NOT_YET; do case "$SEC6_FUNCS" in *" $f "*) ;; *) unex="$unex $f(only in NOT_YET)";; esac; done
rowif "§14.6 allowlist names: $nlist listed, undefined and not announced:${unex:- none}" [ -z "$unex" ]
for f in $stale; do echo "    hint: $f is defined and still in SEC6_NOT_YET: please remove"; done

# 6-7 · the one marked ACTIVE exception stays opt-in; no transmit tool is ever invoked
# shellcheck disable=SC2016   # literal shell text searched for in the collector
d=$(grep -cF 'ALLOW_ACTIVE=${STARCHORUS_ALLOW_ACTIVE:-0}' starchorus-collect.sh)
# shellcheck disable=SC2016
g=$(awk '/^build_from_iwscan\(\)[ \t]*\{/{getline; print; exit}' starchorus-collect.sh | grep -cF '[ "$ALLOW_ACTIVE" = "1" ] || return 1')
scoped '(^|[^A-Za-z_])iw([[:space:]]+dev[[:space:]]+[^[:space:]|;]+)?[[:space:]]+scan([^A-Za-z_]|$)' | grep -v ':build_from_iwscan:' > "$tmp/scan"
ns=$(lines "$tmp/scan")
rowif "iw scan opt-in only (default $d, guard $g, stray $ns)" [ "$d/$g/$ns" = 1/1/0 ]
[ "$ns" = 0 ] || show < "$tmp/scan"
scoped "$TX_RE" > "$tmp/tx"
rowif "transmit tools invoked = $(lines "$tmp/tx")" [ ! -s "$tmp/tx" ]
[ -s "$tmp/tx" ] && show < "$tmp/tx"

# 7b · recon.db is only ever READ, and read-only (SECURITY.md, first permitted way): every sqlite3 CALL outside
# selftest() carries -readonly. `have sqlite3` is a presence test, not a call. The floor keeps the row from turning
# green because the one production call vanished or was renamed out of sight of the regex.
# Read per OCCURRENCE, not per line: each `sqlite3` word on a line is one call, and its flag must stand in that call's own
# words: the words up to the next `;` `&` `|`, the next `sqlite3`, a comment start (blank + `#`) or the first quote. So a
# `# -readonly` comment, a second call after a read-only one, and `-readonly` inside a quoted SQL string do not count.
# An occurrence after a `#` is still a call (a `#` inside a string would otherwise hide it).
MIN_SQLITE_CALLS=1   # production calls: scoped sqlite3 words outside selftest(), minus `have sqlite3` (measured: 1, recondb_query)
scoped '(^|[^A-Za-z0-9_-])sqlite3([^A-Za-z0-9_]|$)' > "$tmp/sq0"
# shellcheck disable=SC2016   # awk program
SQAWK='{ t = $0
  for (k = 0; k < 3; k++) t = substr(t, index(t, ":") + 1)          # "file:line:fn:" off, the text stays
  fn = $0; sub(/^[^:]*:[^:]*:/, "", fn); sub(/:.*/, "", fn)
  if (fn == "selftest") next
  while (match(t, /have[ \t]+sqlite3/)) t = substr(t, 1, RSTART - 1) substr(t, RSTART + RLENGTH)
  pos = 1; ncall = 0; bad = 0
  while ((i = index(substr(t, pos), "sqlite3")) > 0) {
    a = pos + i - 1; pos = a + 7
    if (a > 1 && substr(t, a - 1, 1) ~ /[A-Za-z0-9_-]/) continue
    if (substr(t, a + 7, 1) ~ /[A-Za-z0-9_]/) continue
    ncall++
    seg = substr(t, a + 7); cut = length(seg) + 1
    for (k = 1; k <= length(seg); k++) {
      c = substr(seg, k, 1)
      if (c ~ /[;&|"\047`]/ || substr(seg, k, 7) == "sqlite3" || (c == "#" && (k == 1 || substr(seg, k - 1, 1) ~ /[ \t]/))) { cut = k; break }
    }
    if ((" " substr(seg, 1, cut - 1) " ") !~ /[ \t]-readonly[ \t]/) bad = 1
  }
  if (ncall > 0) { print $0 > CALLS; calls += ncall; if (bad) print $0 > BADS }
}
END { print calls + 0 }'
: > "$tmp/sqcall"; : > "$tmp/sqbad"
nsq=$(awk -v CALLS="$tmp/sqcall" -v BADS="$tmp/sqbad" "$SQAWK" "$tmp/sq0")
nsqb=$(lines "$tmp/sqbad")
sqok=0; [ "$nsqb" = 0 ] && [ "$nsq" -ge "$MIN_SQLITE_CALLS" ] && sqok=1
rowif "sqlite3 read-only: $nsq calls outside selftest (≥ $MIN_SQLITE_CALLS), without -readonly $nsqb" [ "$sqok" = 1 ]
[ "$nsqb" = 0 ] || show < "$tmp/sqbad"

# 7c · starchorus-serve.sh (the nc listener, the only part of Starchorus that listens on the device): the request handler accepts
# GET/HEAD only (everything else is turned into a path no branch serves) and serves exactly {/, /index.html,
# /starchorus.json}; the default branch answers 404. Read from the text of the heredoc that writes the handler; the file
# is never run. Pinned as exact strings: a widened method list or a new path is red until this row is changed on
# purpose. Each block must occur exactly once (a renamed `case` would otherwise leave nothing to compare).
SERVE=starchorus-serve.sh
# shellcheck disable=SC2016   # literal handler text searched for in starchorus-serve.sh
SERVE_METHOD='case "$method" in GET|HEAD) : ;; *) path=__BAD__ ;; esac'
SERVE_PATHS='/|/index.html /starchorus.json *'
if [ -f "$SERVE" ]; then
  # shellcheck disable=SC2016
  nmc=$(grep -c '^case "\$method" in' "$SERVE")
  # shellcheck disable=SC2016
  mline=$(grep '^case "\$method" in' "$SERVE" | head -n 1)
  # shellcheck disable=SC2016   # awk program
  awk '/^case "\$path" in[[:space:]]*$/ { inb = 1; blocks++; next }
       inb && /^esac/ { inb = 0; next }
       inb && /^[[:space:]]+[^[:space:]]+\)[[:space:]]/ { p = $1; sub(/\).*/, "", p); pats = pats (pats == "" ? "" : " ") p; if (p == "*" && $0 ~ /f=""/) dflt = 1 }
       END { printf "%d\n%s\n%d\n", blocks, pats, dflt }' "$SERVE" > "$tmp/sv"
  npc=$(sed -n 1p "$tmp/sv"); pats=$(sed -n 2p "$tmp/sv"); dflt=$(sed -n 3p "$tmp/sv")
else
  nmc=0; mline=""; npc=0; pats=""; dflt=0
fi
svok=0; [ "$nmc/$npc/$dflt" = 1/1/1 ] && [ "$mline" = "$SERVE_METHOD" ] && [ "$pats" = "$SERVE_PATHS" ] && svok=1
rowif "starchorus-serve.sh: GET|HEAD only, paths {$pats}, default 404 (blocks $nmc/$npc/$dflt)" [ "$svok" = 1 ]
[ "$svok" = 1 ] || printf '    method line: %s\n    want:        %s\n    paths want:  %s\n' "$mline" "$SERVE_METHOD" "$SERVE_PATHS"

# 8 · §14.7 legal denylist: ONE implementation, tools/denylist-check.sh (lists tools/denylist*.txt).
# Its default run covers exactly the §14.7 files (page + both starchorus-display.sh) and contains the literal
# `grep -ciFf tools/denylist.txt …`; exit 0 = no hit, 1 = hits (file:line), 2 = setup problem or a
# missing list. A missing script fails too (sh exits 127).
sh tools/denylist-check.sh > "$tmp/dl" 2>&1; dl=$?
rowif "§14.7 denylist-check.sh (exit $dl, want 0)" [ "$dl" = 0 ]
[ "$dl" = 0 ] || show < "$tmp/dl"

exit $fail
