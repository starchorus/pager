#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# denylist-check.sh -- legal denylist (spec §14.7). Read-only.
#
# usage: sh tools/denylist-check.sh              # §14.7 set: starchorus.html + both starchorus-display.sh
#        sh tools/denylist-check.sh --extended   # §14.7 set + index.html, collector, payload scripts, serve, fixtures
#        sh tools/denylist-check.sh --selftest   # proves the grep semantics AND the list contents:
#                                                # one fixture line per §14.7-enumerated item, all must hit
#        sh tools/denylist-check.sh FILE...      # explicit files (relative to the repo root)
#
# Three lists; one entry per line, no comments, no blank lines (a blank pattern matches every line):
#   tools/denylist.txt        case-insensitive substring   = the literal §14.7 check `grep -ciFf`; every entry
#                             has >= 6 chars or a space/punctuation, so base64 cannot spell it by chance
#   tools/denylist-words.txt  case-insensitive whole word  = short names that hide inside ordinary words
#                             (hari/sharing, mule/formule, cleon/nucleon, norad/noradrenaline) and the
#                             everyday phrases that are DEFCON level names or game titles (fade out, chess)
#   tools/denylist-cs.txt     case-SENSITIVE whole word    = classification markings and org acronyms
#                             ("OFFICIAL" must not hit "RedHatOfficial" in the verbatim OFL notice)
# The word and cs lists run on the text with base64 data: URIs blanked (embedded font); line numbers stay.
# Docs and README are out of scope (non-affiliation notes are allowed there).
# Exit 0 = every count 0 and lists well-formed; 1 = hit(s), printed as FILE:LINE; 2 = setup error.
set -u
here=$(cd "$(dirname "$0")" && pwd) || exit 2
root=$(cd "$here/.." && pwd) || exit 2
L1="$here/denylist.txt"; L2="$here/denylist-words.txt"; L3="$here/denylist-cs.txt"

strip() { sed -E 's#data:[A-Za-z0-9/+.-]*;base64,[A-Za-z0-9+/=]*#data:,#g' "$1"; }

lint() {
    bad=0
    for l in "$L1" "$L2" "$L3"; do
        [ -s "$l" ] || { echo "denylist: missing or empty list $l" >&2; return 2; }
        n=$(grep -c -e '^$' -e '^[[:space:]]' -e '[[:space:]]$' "$l")
        [ "$n" = 0 ] || { echo "denylist: $n blank/padded line(s) in $l" >&2; bad=1; }
        n=$(tr -cd '\r' < "$l" | wc -c | tr -d ' ')
        [ "$n" = 0 ] || { echo "denylist: CR characters in $l" >&2; bad=1; }
    done
    n=$(awk 'length($0) < 6 && $0 ~ /^[A-Za-z0-9+\/=]+$/' "$L1" | wc -l | tr -d ' ')
    [ "$n" = 0 ] || { echo "denylist: $n short base64-like entries in denylist.txt (belong in denylist-words.txt)" >&2; bad=1; }
    return $bad
}

hitlines() {   # all hits of FILE as "list LINE:text"
    grep -niFf "$L1" "$1" | sed 's/^/ci   /'
    strip "$1" | grep -niwFf "$L2" | sed 's/^/word /'
    strip "$1" | grep -nwFf "$L3" | sed 's/^/cs   /'
}

check() {      # check FILE -> "c1 c2 c3 FILE"; 1 on any hit
    [ -f "$1" ] || { echo "denylist: no such file $1" >&2; return 2; }
    c1=$(grep -ciFf "$L1" "$1"); c2=$(strip "$1" | grep -ciwFf "$L2"); c3=$(strip "$1" | grep -cwFf "$L3")
    printf '%s %s %s %s\n' "$c1" "$c2" "$c3" "$1"
    [ "$c1$c2$c3" = 000 ] && return 0
    hitlines "$1" | cut -c1-170 | sed "s|^|  $1 |"
    return 1
}

selftest() {
    t=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-deny.XXXXXX") || return 2
    # The positive fixture pins the CONTENT of the three lists, not just the grep semantics: one line per
    # item §14.7 enumerates, plus one example of every category §14.7 names without enumerating it. Because the
    # count below is the number of DISTINCT hit LINES, every term needs its own line (two terms on one
    # line would make the count blind to losing one of them) and deleting any one list entry drops $p.
    # Order: film quote · game-menu title · code word (three categories §14.7 names but does not enumerate,
    # one example each) · defcon · def con · NORAD as a label · the 5 DEFCON level names · the 8
    # classification markings §14.7 enumerates, case-correct so denylist-cs.txt runs · the further markings
    # the cs list carries · the 13 Foundation names · the organisations/places · the proprietary fonts ·
    # one word-boundary probe (the -w list must still fire next to a near-miss on the same line).
    # Not covered, because no list carries it: "Home Office" (§14.7 names it; see tools/README.md).
    cat > "$t/pos" <<'EOF'
SHALL WE PLAY A GAME?
menu entry: Gin Rummy
code word CPE 1704 TKS
var defconLevel = 3;
see you at def con
chart label: NORAD parabolas
Cocked Pistol
Fast Pace
Round House
Double Take
Fade Out
OFFICIAL
OFFICIAL-SENSITIVE
SECRET
TOP SECRET
NOFORN
UK EYES ONLY
RECIPIENTS ONLY
NOT PROTECTIVELY MARKED
CONFIDENTIAL
RESTRICTED
UNCLASSIFIED
CLASSIFIED
FOUO
Encyclopedia Galactica
Seldon
Hari
Mule
psychohistory
Terminus
Trantor
Sandogram
Prime Radiant
Time Vault
Second Foundation
Galactic Empire
Cleon
COBR
PJHQ
Northwood
Bentley Priory
SIS
MI6
GCHQ
MOD
RAF
ROC
Cabinet Office
HMG
GOV.UK
British Army
GDS Transport
Johnston
Rail Alphabet
sharing first, then Hari
EOF
    # The negative fixture must grow in step with the positive one: every near-miss that the page, the
    # OFL notice or ordinary English legitimately contains has to stay at 0 hits.
    cat > "$t/neg" <<'EOF'
file sharing is on
emulate the formulae
nucleon noradrenaline
fades out; fade-out; fadeOutMs
(https://github.com/RedHatOfficial/Overpass)
official guidance, a secret
case-SENSITIVE SECRET_KEY
src: url(data:font/woff2;base64,AAHariAA+RAF/MOD+NORAD/SECRET=)
Foundation · WARGAMES · WHITEHALL · EXERCISE · STARTEX · ENDEX · undef con
ROCket, MODerate, RAFters, SISters, HMGb1
a cocked hat and a fast pacer
EOF
    p=$(hitlines "$t/pos" | sed 's/^[a-z]* *//' | cut -d: -f1 | sort -u | wc -l | tr -d ' ')
    n=$(hitlines "$t/neg" | wc -l | tr -d ' ')
    rm -rf "$t"
    echo "selftest: positives hit $p/55, negatives hit $n/0"
    [ "$p" = 55 ] && [ "$n" = 0 ]
}

cd "$root" || exit 2
lint; rc=$?; [ "$rc" = 2 ] && exit 2
case "${1:-}" in
    --selftest) selftest; s=$?; [ "$rc" = 0 ] && exit $s; exit 1 ;;
    --extended) shift; set -- starchorus.html starchorus-display.sh library/user/reconnaissance/starchorus/starchorus-display.sh \
        index.html starchorus-collect.sh payload.sh library/user/reconnaissance/starchorus/payload.sh starchorus-serve.sh \
        tools/gen-testdata.py tests/fixtures/*.json ;;
    "") set -- starchorus.html starchorus-display.sh library/user/reconnaissance/starchorus/starchorus-display.sh ;;
esac
fail=$rc
for f in "$@"; do check "$f" || fail=1; done
exit $fail
