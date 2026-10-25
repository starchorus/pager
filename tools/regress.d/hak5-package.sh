# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/hak5-package.sh -- the payload directory for Hak5's library (tools/hak5-package.sh), built into a temp dir.
# GUARDS AGAINST: a package that misses a file the payload needs at run time, or carries one it should not (tests, tools,
#                 fixtures, dev files); a packaged file that is not the repo's bytes (a stale or edited copy); a payload header
#                 without Title/Description/Author/Version/Category, a version that is not the page's, a category other than
#                 the directory's, a companion alert without its header or its bash shebang; a companion alert that writes
#                 anything but one line of times and addresses (a message, an upper-case address, a text that is no address),
#                 keeps more than 2,000 lines, or fails; personal data (an e-mail address, a home directory, a key) in any packaged file; a
#                 missing or altered LICENSE; a generator that leaves a stale file behind or writes despite differing
#                 Overview copies, or that removes the repo's own payload sources when told to build into the repo root (also when the root, the payload directory or a path
#                 inside it is written in other letter case on a case-insensitive file system, which a string comparison misses); a packaged payload that cannot install itself from its own directory.
# NEGATIVE PROBE: a file added to the generator's map, or the page packaged under its repo name => "file list" red; README.md
#                 source edited after the build => "byte-identical" red; the Category line changed => "header" red; the
#                 cmp guard removed from the generator => "refuses" red; the root-or-source guard removed => "OUTDIR = the repo root" red; the identity
#                 test (test -ef) removed => "in other letter case" red (tried on a copy; NOT COVERED where the file system is case-sensitive); pl_install removed from the payload => "installs" red.
#                 The companion alert: out of the map, not executable in the repo, an Author line or the licence line removed, another
#                 Version or shebang => "file list" / "header" red; its lower-casing, address test, message-free line, cap (a limit of
#                 2,001 or a tail of 1,999), umask, flock call or exit status changed => "companion alert" red (each tried on a copy).
# NOT PROVEN:     that Hak5 accepts the directory (their review is by hand); anything on the device; the payload's first-run
#                 install under BusyBox (payload-ui.sh runs it with stand-ins under sh/dash); the companion alert under the device's
#                 shell and its own flock or tail (the run here has a stand-in flock and the machine's other tools).
# Sourced by tools/regress.sh (T2) and tools/quick.sh (T1) with cwd = repo root; Chrome-free, no network. Sets only HKP_* names.

HKP_T=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-hkp.XXXXXX") || HKP_T=""
if [ -z "$HKP_T" ] || [ ! -d "$HKP_T" ]; then
  row "hak5 package: no temp directory" FAIL
else
HKP_REL=library/user/reconnaissance/starchorus
# the expected map, typed here on purpose (not read from the generator): packaged name = repo source
HKP_MAP="LICENSE=LICENSE
README.md=packaging/hak5/README.md
index.html=starchorus.html
payload.sh=$HKP_REL/payload.sh
starchorus-collect.sh=starchorus-collect.sh
starchorus-display.sh=$HKP_REL/starchorus-display.sh
starchorus-serve.sh=starchorus-serve.sh
alert-deauth.sh=$HKP_REL/alert-deauth.sh"
HKP_O="$HKP_T/out dir"; HKP_P="$HKP_O/$HKP_REL"
HKP_GO=$(cd / && sh "$R/tools/hak5-package.sh" "$HKP_O" 2>&1); HKP_RC=$?

# ---- 1 · the file list: exactly the eight files, nothing else in the tree, scripts executable, the generator's --list agrees
HKP_BAD=""
[ "$HKP_RC" = 0 ] || HKP_BAD="$HKP_BAD rc$HKP_RC"
HKP_HAVE=$(cd "$HKP_O" 2>/dev/null && find . -type f | sed 's#^\./##' | LC_ALL=C sort | tr '\n' ' ')
HKP_WANT=$(printf '%s\n' "$HKP_MAP" | sed "s#=.*##; s#^#$HKP_REL/#" | LC_ALL=C sort | tr '\n' ' ')
[ "$HKP_HAVE" = "$HKP_WANT" ] || HKP_BAD="$HKP_BAD files[$HKP_HAVE]"
HKP_DIRS=$(cd "$HKP_O" 2>/dev/null && find . -type d | LC_ALL=C sort | tr '\n' ' ')
[ "$HKP_DIRS" = ". ./library ./library/user ./library/user/reconnaissance ./library/user/reconnaissance/starchorus " ] || HKP_BAD="$HKP_BAD dirs"
for HKP_f in payload.sh starchorus-collect.sh starchorus-display.sh starchorus-serve.sh alert-deauth.sh; do [ -x "$HKP_P/$HKP_f" ] || HKP_BAD="$HKP_BAD noexec:$HKP_f"; done
# the package makes its scripts executable whatever the source's mode is, so the companion alert's own mode in the repo (what a commit carries) is looked at too
[ -x "$HKP_REL/alert-deauth.sh" ] || HKP_BAD="$HKP_BAD repo-noexec"
HKP_LS=$(sh tools/hak5-package.sh --list | tr '\t' '=' | LC_ALL=C sort)
[ "$HKP_LS" = "$(printf '%s\n' "$HKP_MAP" | LC_ALL=C sort)" ] || HKP_BAD="$HKP_BAD list"
case $HKP_HAVE in *test*|*fixture*|*tools*|*.py*|*.githooks*|*.github*) HKP_BAD="$HKP_BAD devfile" ;; esac
rowif "hak5 package: 8 files in $HKP_REL (the companion alert among them), nothing else, scripts executable (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]
[ "$HKP_RC" = 0 ] || printf '%s\n' "$HKP_GO" | sed 's/^/    /' | head -n 5

# ---- 2 · every packaged file is its repo source, byte for byte (the page as index.html)
HKP_BAD=""
HKP_IFS=$IFS; IFS='
'
for HKP_l in $HKP_MAP; do
  cmp -s "$HKP_P/${HKP_l%%=*}" "${HKP_l#*=}" || HKP_BAD="$HKP_BAD ${HKP_l%%=*}"
done
IFS=$HKP_IFS
cmp -s starchorus-display.sh "$HKP_P/starchorus-display.sh" || HKP_BAD="$HKP_BAD display-root"
rowif "hak5 package: every file byte-identical to its repo source (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

# ---- 3 · the payload header Hak5 asks for: Title, Description, Author, Version (= the page's), Category (= the directory's); the companion alert has the same
#           header without a Category (an alert payload sits in a category of the firmware's own), a bash shebang and the licence line
HKP_BAD=""
HKP_HD=$(head -n 15 "$HKP_P/payload.sh" 2>/dev/null)
HKP_PV=$(sed -n 's/^  version: "\([0-9][0-9A-Za-z.-]*\)",$/\1/p' starchorus.html | head -n 1)
for HKP_k in Title Description Author; do printf '%s\n' "$HKP_HD" | grep -q "^# $HKP_k: [^ ]" || HKP_BAD="$HKP_BAD $HKP_k"; done
[ "$(printf '%s\n' "$HKP_HD" | sed -n 's/^# Version: //p')" = "${HKP_PV:-none}" ] || HKP_BAD="$HKP_BAD Version"
[ "$(printf '%s\n' "$HKP_HD" | sed -n 's/^# Category: //p')" = reconnaissance ] || HKP_BAD="$HKP_BAD Category"
[ "$(sed -n 1p "$HKP_P/payload.sh" 2>/dev/null)" = "#!/bin/bash" ] || HKP_BAD="$HKP_BAD shebang"
printf '%s\n' "$HKP_HD" | grep -q '^# SPDX-License-Identifier: GPL-3.0-or-later$' || HKP_BAD="$HKP_BAD SPDX"
HKP_AH=$(head -n 15 "$HKP_P/alert-deauth.sh" 2>/dev/null)
for HKP_k in Title Description Author; do printf '%s\n' "$HKP_AH" | grep -q "^# $HKP_k: [^ ]" || HKP_BAD="$HKP_BAD alert-$HKP_k"; done
[ "$(printf '%s\n' "$HKP_AH" | sed -n 's/^# Version: //p')" = "${HKP_PV:-none}" ] || HKP_BAD="$HKP_BAD alert-Version"
[ "$(sed -n 1p "$HKP_P/alert-deauth.sh" 2>/dev/null)" = "#!/bin/bash" ] || HKP_BAD="$HKP_BAD alert-shebang"
printf '%s\n' "$HKP_AH" | grep -q '^# SPDX-License-Identifier: GPL-3.0-or-later$' || HKP_BAD="$HKP_BAD alert-SPDX"
rowif "hak5 package: payload header Title/Description/Author/Version $HKP_PV/Category reconnaissance, and the companion alert's header (bash shebang, no Category) (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

# ---- 4 · no personal data, no live-service default; the README says what Hak5's readers need; the LICENSE is the GPL
HKP_BAD=""
# e-mail addresses and keys case-insensitive; home directories case-sensitive (the page's comment "arrows/Home/End" is not one)
HKP_PD=$(($(cat "$HKP_P"/* 2>/dev/null | grep -ciE '[a-z0-9._%+-]+@[a-z0-9-]+\.[a-z]{2,}|PRIVATE KEY|api[_-]?key[ =:]+[a-z0-9]{8}') + $(cat "$HKP_P"/* 2>/dev/null | grep -cE '[/]Users[/]|[/]home[/][a-z]')))
[ "$HKP_PD" = 0 ] || HKP_BAD="$HKP_BAD personal:$HKP_PD"
HKP_URL=$(grep -ohE 'https?://[A-Za-z0-9.-]+' "$HKP_P/payload.sh" "$HKP_P/starchorus-serve.sh" | grep -cvE '^http://$|https?://<device-ip>' )
[ "$HKP_URL" = 0 ] || HKP_BAD="$HKP_BAD url:$HKP_URL"
HKP_RM="$HKP_P/README.md"
for HKP_s in 'https://github.com/starchorus/pager' 'not affiliated with, sponsored or endorsed by Hak5' 'trademarks of Hak5 LLC' \
  'GPL-3.0-or-later' '**Payloads**, then **Reconnaissance**, then **Starchorus**' 'never transmits' '## Network exposure' \
  '/root/loot/starchorus/settings.conf'; do
  grep -qF "$HKP_s" "$HKP_RM" 2>/dev/null || HKP_BAD="$HKP_BAD readme[$HKP_s]"
done
grep -qE '\]\((\.\./|[a-z-]+\.md|tools/|docs/)' "$HKP_RM" 2>/dev/null && HKP_BAD="$HKP_BAD readme-relative-link"
{ [ "$(sed -n 1p "$HKP_P/LICENSE" 2>/dev/null | tr -s ' ' | sed 's/^ //')" = "GNU GENERAL PUBLIC LICENSE" ] && grep -q 'Version 3, 29 June 2007' "$HKP_P/LICENSE"; } || HKP_BAD="$HKP_BAD license"
rowif "hak5 package: no personal data or remote URL, README complete, LICENSE = GPL v3 (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

# ---- 5 · the generator: a rebuild drops a stale file; differing Overview copies are refused and nothing is written
HKP_BAD=""
: > "$HKP_P/stale.txt"
(cd / && sh "$R/tools/hak5-package.sh" "$HKP_O" >/dev/null 2>&1) || HKP_BAD="$HKP_BAD rebuild"
[ ! -e "$HKP_P/stale.txt" ] || HKP_BAD="$HKP_BAD stale"
HKP_C="$HKP_T/copy"; mkdir -p "$HKP_C/tools" "$HKP_C/$HKP_REL" "$HKP_C/packaging/hak5"
for HKP_f in tools/hak5-package.sh starchorus-collect.sh starchorus.html starchorus-display.sh starchorus-serve.sh LICENSE \
  packaging/hak5/README.md "$HKP_REL/payload.sh" "$HKP_REL/starchorus-display.sh" "$HKP_REL/alert-deauth.sh"; do cp "$HKP_f" "$HKP_C/$HKP_f"; done
(cd / && sh "$HKP_C/tools/hak5-package.sh" "$HKP_T/ctl" >/dev/null 2>&1) || HKP_BAD="$HKP_BAD control"
printf '# drift\n' >> "$HKP_C/$HKP_REL/starchorus-display.sh"
(cd / && sh "$HKP_C/tools/hak5-package.sh" "$HKP_T/neg" >/dev/null 2>&1); HKP_NR=$?
{ [ "$HKP_NR" = 2 ] && [ ! -e "$HKP_T/neg/$HKP_REL" ]; } || HKP_BAD="$HKP_BAD refuses:rc$HKP_NR"
rm -f "$HKP_C/$HKP_REL/payload.sh"
(cd / && sh "$HKP_C/tools/hak5-package.sh" "$HKP_T/neg2" >/dev/null 2>&1); HKP_NR=$?
[ "$HKP_NR" = 2 ] || HKP_BAD="$HKP_BAD missing:rc$HKP_NR"
rowif "hak5 package: rebuild drops a stale file, differing Overview copies and a missing source refused (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

# ---- 5b · an OUTDIR that would make the target the repo's own copy of the payload is refused before anything is removed (scratch copy of the tree, never the real one):
#            OUTDIR = the repo root written as ".", absolutely, with a trailing slash, as library/.. and through a symbolic link, OUTDIR = the payload directory itself,
#            "./nosuch/.." and an OUTDIR whose library, library/user or target is a symbolic link into the copy (nothing is made either):
#            exit 2, the message names the cause, every source still there byte for byte; a sibling OUTDIR inside the copy still builds, and the copy's sources are untouched
HKP_BAD=""
HKP_Q="$HKP_T/qcopy"; mkdir -p "$HKP_Q/tools" "$HKP_Q/$HKP_REL" "$HKP_Q/packaging/hak5"
for HKP_f in tools/hak5-package.sh starchorus-collect.sh starchorus.html starchorus-display.sh starchorus-serve.sh LICENSE \
  packaging/hak5/README.md "$HKP_REL/payload.sh" "$HKP_REL/starchorus-display.sh" "$HKP_REL/alert-deauth.sh"; do cp "$HKP_f" "$HKP_Q/$HKP_f"; done
ln -s "$HKP_Q" "$HKP_T/qlink"
: > "$HKP_Q/$HKP_REL/planted.txt"   # a file of the copy's payload directory that no build makes: a target swapped in over that directory loses it
hkp_same() {   # hkp_same: every file of the copy is still the repo's bytes
  for _hf in starchorus-collect.sh starchorus.html starchorus-display.sh starchorus-serve.sh LICENSE packaging/hak5/README.md \
    "$HKP_REL/payload.sh" "$HKP_REL/starchorus-display.sh" "$HKP_REL/alert-deauth.sh"; do
    cmp -s "$_hf" "$HKP_Q/$_hf" || return 1
  done
}
hkp_refuse() {   # hkp_refuse LABEL OUTDIR: run from inside the copy; exit 2 with a message, the sources untouched
  _hl=$1; _ho=$2
  _hm=$(cd "$HKP_Q" && sh tools/hak5-package.sh "$_ho" 2>&1); _hr=$?
  [ "$_hr" = 2 ] || HKP_BAD="$HKP_BAD $_hl:rc$_hr"
  case $_hm in *"hak5-package: "*"choose another output directory"*|*"hak5-package: the output directory is the repo root"*) ;; *) HKP_BAD="$HKP_BAD $_hl:message" ;; esac
  hkp_same || HKP_BAD="$HKP_BAD $_hl:source-lost"
  [ -e "$HKP_Q/$HKP_REL/planted.txt" ] || HKP_BAD="$HKP_BAD $_hl:planted-lost"
  [ ! -e "$HKP_Q/$HKP_REL.tmp" ] && [ ! -e "$HKP_Q/$HKP_REL.old" ] || HKP_BAD="$HKP_BAD $_hl:leftover"
  set -- "$HKP_Q/$HKP_REL".old.*; [ ! -e "$1" ] || HKP_BAD="$HKP_BAD $_hl:leftover-old-pid"
  [ ! -e "$HKP_Q/nosuch" ] || HKP_BAD="$HKP_BAD $_hl:made-nosuch"
}
hkp_refuse dot .
hkp_refuse abs "$HKP_Q"
hkp_refuse slash "$HKP_Q/"
hkp_refuse updown "$HKP_Q/library/.."
hkp_refuse link "$HKP_T/qlink/"
hkp_refuse linkdot "$HKP_T/qlink/tools/.."
# a link to the payload directory, followed by .., beside a decoy directory of the same name: as text the path names the decoy, on the file system it is
# the parent of the real payload directory, so the target would sit inside the sources (the tool resolves with cd -P)
mkdir -p "$HKP_T/xd/starchorus"; ln -s "$HKP_Q/$HKP_REL" "$HKP_T/xd/plink"
hkp_refuse linkdecoy "$HKP_T/xd/plink/../starchorus"
[ ! -e "$HKP_Q/$HKP_REL/library" ] || HKP_BAD="$HKP_BAD linkdecoy:nested"
hkp_refuse payloaddir "$HKP_REL"
# the target is resolved, not only OUTDIR: a ".." after a directory that does not exist yet, and a link anywhere along OUTDIR/library/user/reconnaissance
hkp_refuse nosuchdots ./nosuch/..
hkp_refuse nosuchabs "$HKP_Q/nosuch/.."
mkdir -p "$HKP_T/xl1" "$HKP_T/xl2/library" "$HKP_T/xl3/library/user/reconnaissance"
ln -s "$HKP_Q/library" "$HKP_T/xl1/library"                       # OUTDIR/library is a link to the copy's library
ln -s "$HKP_Q/library/user" "$HKP_T/xl2/library/user"             # OUTDIR/library/user is a link to the copy's library/user
ln -s "$HKP_Q/$HKP_REL" "$HKP_T/xl3/$HKP_REL"                     # the target itself is a link to the copy's payload directory
hkp_refuse linklib "$HKP_T/xl1"
hkp_refuse linkuser "$HKP_T/xl2"
hkp_refuse linktarget "$HKP_T/xl3"
# the same from another working directory, the copy's generator called by its absolute path
(cd "$HKP_Q/library" && sh "$HKP_Q/tools/hak5-package.sh" .. >/dev/null 2>&1); HKP_NR=$?
{ [ "$HKP_NR" = 2 ] && hkp_same; } || HKP_BAD="$HKP_BAD updir:rc$HKP_NR"
# a directory of its own inside the copy builds, and the payload's sources stay
(cd "$HKP_Q" && sh tools/hak5-package.sh out/pkg >/dev/null 2>&1) || HKP_BAD="$HKP_BAD sibling"
{ hkp_same && cmp -s starchorus-collect.sh "$HKP_Q/out/pkg/$HKP_REL/starchorus-collect.sh"; } || HKP_BAD="$HKP_BAD sibling-bytes"
rowif "hak5 package: OUTDIR = the repo root (., absolute, trailing slash, library/.., through a link), the payload directory, ./nosuch/.. or a link along OUTDIR/library/user/reconnaissance is refused with exit 2 before anything is removed or made, the sources stay; a directory beside them still builds (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

# ---- 5c · the same by identity, not only by string: on a case-insensitive file system (macOS by default) the copy's root, its last component, a link to the
#            copy's library/user/reconnaissance and a link to its payload directory, each written in other letter case, name the same directories and are refused
#            likewise (exit 2, every source still there, nothing left beside it); on a case-sensitive file system these paths name nothing, so the row is NOT COVERED
HKP_BAD=""
HKP_QU=$(printf '%s\n' "$HKP_Q" | LC_ALL=C tr '[:lower:]' '[:upper:]')
if [ "$HKP_QU" != "$HKP_Q" ] && [ -d "$HKP_QU" ] && [ "$HKP_QU" -ef "$HKP_Q" ]; then
  mkdir -p "$HKP_T/xc1/library/user" "$HKP_T/xc2/library/user/reconnaissance"
  ln -s "$HKP_QU/library/user/reconnaissance" "$HKP_T/xc1/library/user/reconnaissance"   # OUTDIR's library/user/reconnaissance is the copy's, in upper case
  ln -s "$HKP_QU/$HKP_REL" "$HKP_T/xc2/$HKP_REL"                                       # the target is a link to the copy's payload directory, in upper case
  hkp_refuse case "$HKP_QU"
  hkp_refuse caselast "${HKP_Q%/*}/QCOPY"
  hkp_refuse caseslash "$HKP_QU/"
  hkp_refuse caselib "$HKP_T/xc1"
  hkp_refuse casetarget "$HKP_T/xc2"
  (cd "${HKP_Q%/*}" && sh "$HKP_Q/tools/hak5-package.sh" QCOPY >/dev/null 2>&1); HKP_NR=$?
  { [ "$HKP_NR" = 2 ] && hkp_same; } || HKP_BAD="$HKP_BAD caserel:rc$HKP_NR"
  rowif "hak5 package: OUTDIR = the repo root in other letter case (whole path, last component, trailing slash, relative), or a link in other case to its library/user/reconnaissance or payload directory, is refused with exit 2 on this case-insensitive file system, the sources stay (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]
else
  notcov "hak5 package: OUTDIR = the repo root in other letter case (the file system here is case-sensitive, so the case-variant paths name nothing)"
fi

# ---- 5d · the payload directory itself, and a path inside it, written in other letter case (from inside the copy): refused like their exact spelling in 5b
#            (exit 2, every source still there, nothing left beside it), and no package is built inside the copy's payload directory (no library/ appears there);
#            NOT COVERED on a case-sensitive file system, where these paths name nothing
HKP_BAD=""
HKP_RU=$(printf %s "$HKP_REL" | LC_ALL=C tr '[:lower:]' '[:upper:]')
if [ -d "$HKP_Q/$HKP_RU" ] && [ "$HKP_Q/$HKP_RU" -ef "$HKP_Q/$HKP_REL" ]; then
  hkp_refuse casepayload "$HKP_RU"
  [ ! -e "$HKP_Q/$HKP_REL/library" ] || HKP_BAD="$HKP_BAD casepayload:built-inside"
  hkp_refuse casesub "$HKP_RU/sub"
  [ ! -e "$HKP_Q/$HKP_REL/library" ] || HKP_BAD="$HKP_BAD casesub:built-inside"
  [ ! -e "$HKP_Q/$HKP_REL/sub" ] || HKP_BAD="$HKP_BAD casesub:made-sub"
  rowif "hak5 package: OUTDIR = the payload directory in other letter case, or a path inside it, is refused with exit 2 on this case-insensitive file system, the sources stay and nothing is built inside them (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]
else
  notcov "hak5 package: OUTDIR = the payload directory in other letter case (the file system here is case-sensitive, so the case-variant paths name nothing)"
fi

# ---- 6 · the packaged payload installs itself from its own directory: `get` and `set` (they start nothing) against an
#           empty data directory leave the four run-time files there, byte-identical and executable, and settings.conf beside them
HKP_BAD=""
HKP_L="$HKP_T/loot dir"
HKP_G=$(cd / && env -i PATH="$PATH" STARCHORUS_DIR="$HKP_L" sh "$HKP_P/payload.sh" get port 2>"$HKP_T/err"); HKP_RC=$?
[ "$HKP_RC/$HKP_G" = "0/port=8199 (default)" ] || HKP_BAD="$HKP_BAD get:$HKP_RC"
grep -q '^Starchorus: installed from ' "$HKP_T/err" || HKP_BAD="$HKP_BAD note"
for HKP_f in index.html starchorus-collect.sh starchorus-display.sh starchorus-serve.sh; do
  cmp -s "$HKP_P/$HKP_f" "$HKP_L/$HKP_f" || HKP_BAD="$HKP_BAD installs:$HKP_f"
done
for HKP_f in starchorus-collect.sh starchorus-display.sh starchorus-serve.sh; do [ -x "$HKP_L/$HKP_f" ] || HKP_BAD="$HKP_BAD noexec:$HKP_f"; done
[ "$(cd "$HKP_L" 2>/dev/null && find . -type f | LC_ALL=C sort | tr '\n' ' ')" = "./index.html ./starchorus-collect.sh ./starchorus-display.sh ./starchorus-serve.sh " ] || HKP_BAD="$HKP_BAD extra"
(cd / && env -i PATH="$PATH" STARCHORUS_DIR="$HKP_L" sh "$HKP_P/payload.sh" set port 8300 >/dev/null 2>"$HKP_T/err2") || HKP_BAD="$HKP_BAD set"
[ "$(cat "$HKP_L/settings.conf" 2>/dev/null)" = "port=8300" ] || HKP_BAD="$HKP_BAD settings"
[ ! -s "$HKP_T/err2" ] || HKP_BAD="$HKP_BAD reinstall"
[ ! -e "$HKP_P/settings.conf" ] || HKP_BAD="$HKP_BAD settings-in-payload-dir"
rowif "hak5 package: the packaged payload installs itself into an empty data dir, settings.conf there (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

# ---- 7 · the companion alert, run from the package with the variables of a stand-in event (synthetic addresses): one line of tab-separated fields in the order the collector
#           reads, addresses in lower case and "-" for what is no address or is not set, the message not written, the log private, the cap at 2,000 lines (1,999 stay,
#           the 2,001st drops the oldest), flock asked for once per event when it is there and not needed when it is not, exit 0 when the directory cannot be made.
#           The tools it may use are linked into a PATH of their own, so the run does not depend on the machine's flock.
HKP_BAD=""
HKP_AL="$HKP_P/alert-deauth.sh"; HKP_AD="$HKP_T/al dir"; HKP_AB="$HKP_T/albin"; HKP_FL="$HKP_T/flock.log"
mkdir -p "$HKP_AB"
for HKP_f in date tr wc tail mv mkdir rm; do ln -s "$(command -v "$HKP_f")" "$HKP_AB/$HKP_f"; done
hkp_ev() {   # hkp_ev DIR PATH [VAR=value ...]: one event, the way the firmware hands it over (the environment only); prints the exit status
  _hd=$1; _hp=$2; shift 2
  (cd / && env -i PATH="$_hp" STARCHORUS_ALERT_DIR="$_hd" "$@" "$HKP_AL" >/dev/null 2>&1); echo $?
}
# shellcheck disable=SC2086   # HKP_EV1 is a list of VAR=value words on purpose
hkp_ev1() { hkp_ev "$1" "$2" $HKP_EV1; }   # hkp_ev1 DIR PATH: the stand-in event below
HKP_EV1="_ALERT=deauth_flood_detected _ALERT_DENIAL_MESSAGE=flood_from_02:00:5e:00:00:ee _ALERT_DENIAL_SOURCE_MAC_ADDRESS=AA:BB:CC:00:00:01 _ALERT_DENIAL_DESTINATION_MAC_ADDRESS=ff:ff:ff:ff:ff:ff _ALERT_DENIAL_AP_MAC_ADDRESS=02:00:5E:00:00:0A _ALERT_DENIAL_CLIENT_MAC_ADDRESS=not-a-mac"
HKP_T0=$(date +%s)
HKP_RC=$(hkp_ev1 "$HKP_AD" "$HKP_AB")
HKP_LG="$HKP_AD/alerts.log"; HKP_T1=$(date +%s)
[ "$HKP_RC" = 0 ] || HKP_BAD="$HKP_BAD rc$HKP_RC"
[ "$(wc -l < "$HKP_LG" 2>/dev/null | tr -d ' ')" = 1 ] || HKP_BAD="$HKP_BAD lines"
HKP_F=$(awk -F'\t' -v a="$HKP_T0" -v b="$HKP_T1" 'NF == 6 && $1 ~ /^[0-9]+$/ && $1 >= a && $1 <= b && $2 == "deauth" && $3 == "02:00:5e:00:00:0a" && $4 == "aa:bb:cc:00:00:01" && $5 == "ff:ff:ff:ff:ff:ff" && $6 == "-" { n++ } END { print n + 0 }' "$HKP_LG" 2>/dev/null)
[ "$HKP_F" = 1 ] || HKP_BAD="$HKP_BAD fields"
grep -qE 'flood|:ee' "$HKP_LG" 2>/dev/null && HKP_BAD="$HKP_BAD message"
[ "$(find "$HKP_LG" -perm 600 2>/dev/null)" = "$HKP_LG" ] || HKP_BAD="$HKP_BAD mode"
[ ! -e "$HKP_AD/alerts.lock" ] || HKP_BAD="$HKP_BAD lock-without-flock"
# nothing set at all: the time and four dashes
rm -f "$HKP_LG"
[ "$(hkp_ev "$HKP_AD" "$HKP_AB")" = 0 ] || HKP_BAD="$HKP_BAD rc-empty"
[ "$(awk -F'\t' 'NF == 6 && $1 ~ /^[0-9]+$/ && $2 == "deauth" && $3 == "-" && $4 == "-" && $5 == "-" && $6 == "-" { n++ } END { print n + 0 }' "$HKP_LG" 2>/dev/null)" = 1 ] || HKP_BAD="$HKP_BAD empty-event"
# the cap: 1,999 lines and one event make 2,000 with the oldest still there; one more event drops the oldest
awk 'BEGIN { for (i = 1; i <= 1999; i++) printf "%d\tdeauth\t02:00:00:00:00:01\t-\t-\t-\n", 1000000000 + i }' > "$HKP_LG"
hkp_ev1 "$HKP_AD" "$HKP_AB" >/dev/null; HKP_C1="$(wc -l < "$HKP_LG" | tr -d ' ')/$(sed -n 1p "$HKP_LG" | cut -f1)"
hkp_ev1 "$HKP_AD" "$HKP_AB" >/dev/null; HKP_C2="$(wc -l < "$HKP_LG" | tr -d ' ')/$(sed -n 1p "$HKP_LG" | cut -f1)/$(tail -n 1 "$HKP_LG" | cut -f3)"
[ "$HKP_C1" = 2000/1000000001 ] || HKP_BAD="$HKP_BAD cap1:$HKP_C1"
[ "$HKP_C2" = 2000/1000000002/02:00:5e:00:00:0a ] || HKP_BAD="$HKP_BAD cap2:$HKP_C2"
[ "$(cd "$HKP_AD" && find . -type f | tr '\n' ' ')" = "./alerts.log " ] || HKP_BAD="$HKP_BAD leftovers"
# its own directory: with STARCHORUS_DIR pointing elsewhere the log still lands in STARCHORUS_ALERT_DIR, and nothing is written where a page server would serve it
HKP_OD="$HKP_T/other dir"; mkdir -p "$HKP_OD"; rm -f "$HKP_LG"
# shellcheck disable=SC2086   # HKP_EV1 is a list of VAR=value words on purpose
hkp_ev "$HKP_AD" "$HKP_AB" STARCHORUS_DIR="$HKP_OD" $HKP_EV1 >/dev/null
[ "$(wc -l < "$HKP_LG" 2>/dev/null | tr -d ' ')" = 1 ] && [ "$(find "$HKP_OD" -type f 2>/dev/null | wc -l | tr -d ' ')" = 0 ] || HKP_BAD="$HKP_BAD own-dir"
# shellcheck disable=SC2016   # the literal ${...} of the companion's text is what the pin asks for
rowif "hak5 package: the companion's log directory is its own (DIR=\${STARCHORUS_ALERT_DIR:-/root/loot/starchorus-alerts} pinned 1, a use of STARCHORUS_DIR 0)" [ "$(grep -c '^DIR=\${STARCHORUS_ALERT_DIR:-/root/loot/starchorus-alerts}$' "$HKP_AL")/$(grep -cE '\$\{?STARCHORUS_DIR\b' "$HKP_AL")" = 1/0 ]
# flock where there is one: asked for once per event, as `flock -x 9`, and the line is written all the same
printf '#!/bin/sh\necho "flock $*" >> "%s"\nexit 0\n' "$HKP_FL" > "$HKP_AB/flock"; chmod +x "$HKP_AB/flock"; : > "$HKP_FL"; rm -f "$HKP_LG"
hkp_ev1 "$HKP_AD" "$HKP_AB" >/dev/null; hkp_ev1 "$HKP_AD" "$HKP_AB" >/dev/null
[ "$(cat "$HKP_FL")" = "$(printf 'flock -x 9\nflock -x 9')" ] || HKP_BAD="$HKP_BAD flock:$(tr '\n' '|' < "$HKP_FL")"
[ "$(wc -l < "$HKP_LG" | tr -d ' ')" = 2 ] || HKP_BAD="$HKP_BAD lines-with-flock"
[ -e "$HKP_AD/alerts.lock" ] || HKP_BAD="$HKP_BAD no-lockfile"
# a directory that cannot be made: exit 0, nothing written
: > "$HKP_T/afile"
[ "$(hkp_ev1 "$HKP_T/afile/sub" "$HKP_AB")" = 0 ] || HKP_BAD="$HKP_BAD rc-nodir"
rowif "hak5 package: the companion alert writes one line EPOCH deauth AP SOURCE DESTINATION CLIENT (lower-case addresses, - for a text that is none or unset, no message), private, keeps 2,000 lines, asks flock once per event, exits 0 (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

# ---- 9 · the release tool (tools/release.sh, 0.2.5): the Pager archive and SHA256SUMS, the same bytes on one machine. Built twice into two directories: identical bytes; every entry root/root with uid and gid 0 and
#          the one time of the commit (or of SOURCE_DATE_EPOCH where there is no commit), the four directories first and then the eight files in sorted order; SHA256SUMS holds exactly nine lines, the archive and the
#          files inside it by their path in the archive, each the hash of those bytes, and `sha256sum -c` / `shasum -a 256 -c` passes after the archive is unpacked beside it; a changed source file in a copy of
#          the tree changes the sum of the archive and of that file and of no other (negative), the unchanged copy gives the archive of the real tree byte for byte; no OUTDIR, and an OUTDIR that already
#          holds a release, are refused with exit 2 and the old files stay; an OUTDIR that is the repo root or lies inside it is refused before anything is made and the failed run leaves no directory
HKP_BAD=""
HKP_EP=$(git -C "$R" log -1 --format=%ct HEAD 2>/dev/null); case $HKP_EP in ''|*[!0-9]*) HKP_EP=1700000000; HKP_SDE=1 ;; *) HKP_SDE=0 ;; esac
HKP_R1="$HKP_T/rel 1"; HKP_R2="$HKP_T/rel 2"; HKP_RA=starchorus-$(sed -n 's/^# Version: *\([0-9][0-9A-Za-z.-]*\)$/\1/p' "$R/$HKP_REL/payload.sh" | head -n 1)-pager.tar.gz
if [ "$HKP_SDE" = 1 ]; then
  (cd / && SOURCE_DATE_EPOCH=$HKP_EP sh "$R/tools/release.sh" "$HKP_R1" > "$HKP_T/rel1.out" 2>&1); HKP_C1=$?
  (cd / && SOURCE_DATE_EPOCH=$HKP_EP sh "$R/tools/release.sh" "$HKP_R2" > "$HKP_T/rel2.out" 2>&1); HKP_C2=$?
else
  (cd / && sh "$R/tools/release.sh" "$HKP_R1" > "$HKP_T/rel1.out" 2>&1); HKP_C1=$?
  (cd / && sh "$R/tools/release.sh" "$HKP_R2" > "$HKP_T/rel2.out" 2>&1); HKP_C2=$?
fi
[ "$HKP_C1/$HKP_C2" = 0/0 ] || HKP_BAD="$HKP_BAD rc$HKP_C1/$HKP_C2"
cmp -s "$HKP_R1/$HKP_RA" "$HKP_R2/$HKP_RA" || HKP_BAD="$HKP_BAD archives-differ"
cmp -s "$HKP_R1/SHA256SUMS" "$HKP_R2/SHA256SUMS" || HKP_BAD="$HKP_BAD sums-differ"
[ "$(cd "$HKP_R1" && find . | sed 's#^\./##' | LC_ALL=C sort | tr '\n' ' ')" = ". SHA256SUMS $HKP_RA " ] || HKP_BAD="$HKP_BAD other-files"
# shellcheck disable=SC2016   # the program is python's
HKP_PY='import sys, tarfile
t = tarfile.open(sys.argv[1]); ep = int(sys.argv[2]); ms = t.getmembers(); bad = []
if len(ms) != 12: bad.append("members %d" % len(ms))
for m in ms:
    if (m.uid, m.gid, m.uname, m.gname) != (0, 0, "root", "root"): bad.append("owner " + m.name)
    if m.mtime != ep: bad.append("time " + m.name)
    if m.pax_headers: bad.append("pax " + m.name)
d = [m.name for m in ms if m.isdir()]; f = [m.name for m in ms if m.isreg()]
if d != ["library", "library/user", "library/user/reconnaissance", "library/user/reconnaissance/starchorus"] or ms[:4] != [m for m in ms if m.isdir()]: bad.append("dirs " + ",".join(d))
if f != sorted(f) or len(f) != 8: bad.append("files not 8 sorted")
print(" ".join(bad) if bad else "ok")'
HKP_PO=$(python3 -I -c "$HKP_PY" "$HKP_R1/$HKP_RA" "$HKP_EP" 2>&1); [ "$HKP_PO" = ok ] || HKP_BAD="$HKP_BAD tar[$HKP_PO]"
HKP_X="$HKP_T/unpacked"; mkdir -p "$HKP_X"; tar -xzf "$HKP_R1/$HKP_RA" -C "$HKP_X" 2>/dev/null; cp "$HKP_R1/$HKP_RA" "$HKP_R1/SHA256SUMS" "$HKP_X/"
HKP_LS=$(cd "$HKP_X" && find library -type f | LC_ALL=C sort | tr '\n' ' '); HKP_LW=$(sed '1d; s/^[0-9a-f]*  //' "$HKP_R1/SHA256SUMS" | tr '\n' ' ')
[ "$HKP_LS" = "$HKP_LW" ] || HKP_BAD="$HKP_BAD sums-list"
[ "$(sed -n 1p "$HKP_R1/SHA256SUMS" | sed 's/^[0-9a-f]*  //')/$(wc -l < "$HKP_R1/SHA256SUMS" | tr -d ' ')" = "$HKP_RA/9" ] || HKP_BAD="$HKP_BAD sums-first"
HKP_CHK=$(cd "$HKP_X" && if command -v sha256sum >/dev/null 2>&1; then sha256sum -c SHA256SUMS; else shasum -a 256 -c SHA256SUMS; fi 2>&1); HKP_CR=$?
[ "$HKP_CR" = 0 ] && [ "$(printf '%s\n' "$HKP_CHK" | grep -c ': OK$')" = 9 ] || HKP_BAD="$HKP_BAD check($HKP_CR)"
# a copy of the tree (what the tool reads), unchanged and with one source changed
# (a copy of its own, built here from every source the package step reads, the root starchorus-display.sh included: nothing is borrowed from section 5's copy)
HKP_C="$HKP_T/relcopy"; mkdir -p "$HKP_C/tools" "$HKP_C/$HKP_REL" "$HKP_C/packaging/hak5"
for HKP_f in tools/release.sh tools/hak5-package.sh starchorus-collect.sh starchorus.html starchorus-display.sh starchorus-serve.sh LICENSE \
  packaging/hak5/README.md "$HKP_REL/payload.sh" "$HKP_REL/starchorus-display.sh" "$HKP_REL/alert-deauth.sh"; do cp "$HKP_f" "$HKP_C/$HKP_f"; done
(cd / && SOURCE_DATE_EPOCH=$HKP_EP sh "$HKP_C/tools/release.sh" "$HKP_T/rel c" > "$HKP_T/relc.out" 2>&1); HKP_C3=$?
cmp -s "$HKP_R1/$HKP_RA" "$HKP_T/rel c/$HKP_RA" || HKP_BAD="$HKP_BAD copy-differs"
echo '# a changed line' >> "$HKP_C/starchorus-serve.sh"
(cd / && SOURCE_DATE_EPOCH=$HKP_EP sh "$HKP_C/tools/release.sh" "$HKP_T/rel d" > "$HKP_T/reld.out" 2>&1); HKP_C4=$?
HKP_DF=$(diff "$HKP_R1/SHA256SUMS" "$HKP_T/rel d/SHA256SUMS" | grep -c '^>')
[ "$HKP_C3/$HKP_C4/$HKP_DF" = 0/0/2 ] && [ "$(diff "$HKP_R1/SHA256SUMS" "$HKP_T/rel d/SHA256SUMS" | sed -n 's/^> [0-9a-f]*  //p' | tr '\n' ' ')" = "$HKP_RA $HKP_REL/starchorus-serve.sh " ] || HKP_BAD="$HKP_BAD negative($HKP_C3/$HKP_C4/$HKP_DF)"
# an OUTDIR in the repo is refused before anything is made (tried in the copy, never in the real tree): the repo root as ".", absolute, with a trailing slash and as library/.., the payload
# directory, a path inside it, a directory that does not exist yet inside the repo, and a link to the repo: exit 2 with the reason named, the copy byte for byte as it was, no directory made;
# the same copy still builds into a directory outside it (the control, so that the refusals are the OUTDIR's and not a broken copy)
mkdir -p "$HKP_T/rel link" && ln -s "$HKP_C" "$HKP_T/rel link/clink"
HKP_FP0=$(cd "$HKP_C" && find . | LC_ALL=C sort | cksum)$(cd "$HKP_C" && find . -type f | LC_ALL=C sort | while IFS= read -r HKP_f; do cksum < "$HKP_f"; done | cksum)
hkp_relref() {   # hkp_relref LABEL OUTDIR: run from inside the copy
  _hl=$1; _ho=$2
  _hm=$(cd "$HKP_C" && SOURCE_DATE_EPOCH=$HKP_EP sh tools/release.sh "$_ho" 2>&1); _hr=$?
  [ "$_hr" = 2 ] || HKP_BAD="$HKP_BAD $_hl:rc$_hr"
  case $_hm in *"release: "*"lies inside the repo"*) ;; *) HKP_BAD="$HKP_BAD $_hl:message" ;; esac
  [ "$(cd "$HKP_C" && find . | LC_ALL=C sort | cksum)$(cd "$HKP_C" && find . -type f | LC_ALL=C sort | while IFS= read -r HKP_f; do cksum < "$HKP_f"; done | cksum)" = "$HKP_FP0" ] || HKP_BAD="$HKP_BAD $_hl:copy-changed"
}
hkp_relref dot .
hkp_relref abs "$HKP_C"
hkp_relref slash "$HKP_C/"
hkp_relref updown "$HKP_C/library/.."
hkp_relref payload "$HKP_REL"
hkp_relref inside "$HKP_C/$HKP_REL/sub"
hkp_relref newdir "$HKP_C/nosuch/deeper"
hkp_relref tools tools
hkp_relref link "$HKP_T/rel link/clink"
hkp_relref linknew "$HKP_T/rel link/clink/nosuch"
HKP_RCU=$(printf '%s\n' "$HKP_C" | LC_ALL=C tr '[:lower:]' '[:upper:]')
if [ "$HKP_RCU" != "$HKP_C" ] && [ -d "$HKP_RCU" ] && [ "$HKP_RCU" -ef "$HKP_C" ]; then hkp_relref case "$HKP_RCU"; hkp_relref casenew "$HKP_RCU/nosuch"; fi   # a case-insensitive file system only
(cd / && SOURCE_DATE_EPOCH=$HKP_EP sh "$HKP_C/tools/release.sh" "$HKP_T/rel e" > "$HKP_T/rele.out" 2>&1) || HKP_BAD="$HKP_BAD outside-control"
# nothing left behind by a run that fails after the OUTDIR is accepted: no archive or temp file, and no directory made, when the package step cannot run (a source missing)
mv "$HKP_C/LICENSE" "$HKP_C/LICENSE.away"
(cd / && SOURCE_DATE_EPOCH=$HKP_EP sh "$HKP_C/tools/release.sh" "$HKP_T/rel f" > "$HKP_T/relf.out" 2>&1); HKP_C7=$?
mv "$HKP_C/LICENSE.away" "$HKP_C/LICENSE"
{ [ "$HKP_C7" = 2 ] && [ ! -e "$HKP_T/rel f" ]; } || HKP_BAD="$HKP_BAD failed-run:rc$HKP_C7"
# no OUTDIR, and an OUTDIR that holds a release already
(cd / && sh "$R/tools/release.sh" > "$HKP_T/rel0.out" 2>&1); HKP_C5=$?
HKP_H1=$(cksum < "$HKP_R1/SHA256SUMS")
if [ "$HKP_SDE" = 1 ]; then (cd / && SOURCE_DATE_EPOCH=$HKP_EP sh "$R/tools/release.sh" "$HKP_R1" > "$HKP_T/rel9.out" 2>&1); HKP_C6=$?
else (cd / && sh "$R/tools/release.sh" "$HKP_R1" > "$HKP_T/rel9.out" 2>&1); HKP_C6=$?; fi
[ "$HKP_C5/$HKP_C6" = 2/2 ] && [ "$(cksum < "$HKP_R1/SHA256SUMS")" = "$HKP_H1" ] || HKP_BAD="$HKP_BAD refusals($HKP_C5/$HKP_C6)"
rowif "hak5 package: tools/release.sh builds the archive twice with the same bytes, root/root uid 0 gid 0 and one time on every entry, SHA256SUMS = the archive and the 8 files inside it, checked OK after unpacking; a changed source changes exactly its sum and the archive's; no OUTDIR, an existing release or an OUTDIR in the repo (root, payload directory, a path inside it, a link, a new directory in it) is refused and nothing is made, a failed run leaves no directory (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]
[ -z "$HKP_BAD" ] || { sed 's/^/    /' "$HKP_T/rel1.out" | head -n 5; printf '%s\n' "$HKP_CHK" | grep -v ': OK$' | head -n 5; }

rm -rf "$HKP_T"
fi
