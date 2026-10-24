#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/hak5-package.sh -- builds the self-contained payload directory for Hak5's payload library
# (hak5/wifipineapplepager-payloads) FROM THE FILES OF THIS REPO. Dev machine only (POSIX sh); it reads the repo and writes
# one directory tree, nothing else: no network, no device, no git.
#
# usage: sh tools/hak5-package.sh [OUTDIR]     (any cwd; OUTDIR defaults to out/hak5 in the repo, a relative OUTDIR is
#                                               taken from the current directory)
#        sh tools/hak5-package.sh --list       (print "packaged-name<TAB>repo-source" per file and exit)
#
# Result: OUTDIR/library/user/reconnaissance/starchorus/ with exactly the files of the map below, each a byte copy of its
# repo source (the page under the name the payload serves, index.html). The payload copies the collector, page, Overview
# and netcat server into /root/loot/starchorus on its first run (BUNDLE in its header), so the directory runs on its own.
# alert-deauth.sh is the companion alert payload: it travels in the directory under a name other than payload.sh (the library's
# UpdatePayloads takes every payload.sh for a payload of its own) and is put into the firmware's alert tree by the payload's Settings row 'Alerts', or by hand (README).
# Not packaged: tests, tools, fixtures, the repo's own docs and anything else for development. The target directory is
# replaced as a whole (built beside it, then swapped in), so a file that has left the map does not linger; nothing outside it is
# touched (the old directory is set aside as starchorus.old.PID, so a sibling called starchorus.old is left alone). It refuses,
# before anything is removed or made, an OUTDIR that makes the target the repo's own copy of the payload (OUTDIR = the repo root,
# "." from there included, or any path whose target, resolved through every link along OUTDIR/library/user/reconnaissance/starchorus,
# is, holds or lies in a source; a ".." after a directory that does not exist yet is refused as unresolvable). Paths are compared
# as strings and by identity (test -ef), so the repo, its payload directory or a path inside that, spelt in other letter case on a
# case-insensitive file system, is refused too.
# Exit: 0 = built, 2 = usage or setup problem (missing source, differing Overview copies, unwritable OUTDIR, an OUTDIR that
# would overwrite a source).
set -u

PKGREL=library/user/reconnaissance/starchorus
# packaged name | repo source | x = executable. The Overview comes from the payload directory; static.sh keeps it
# byte-identical to the root copy.
MAP="payload.sh|$PKGREL/payload.sh|x
starchorus-collect.sh|starchorus-collect.sh|x
index.html|starchorus.html|-
starchorus-display.sh|$PKGREL/starchorus-display.sh|x
starchorus-serve.sh|starchorus-serve.sh|x
alert-deauth.sh|$PKGREL/alert-deauth.sh|x
README.md|packaging/hak5/README.md|-
LICENSE|LICENSE|-"

die() { _c=$1; shift; printf 'hak5-package: %s\n' "$*" >&2; exit "$_c"; }

R=$(cd "$(dirname "$0")/.." && pwd) || die 2 "cannot find the repo"

case ${1:-} in
    --list) printf '%s\n' "$MAP" | awk -F'|' '{ print $1 "\t" $2 }'; exit 0 ;;
    -h|--help) sed -n '3,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die 2 "unknown option: $1 (see --help)" ;;
esac
[ $# -le 1 ] || die 2 "at most one argument, the output directory"
OUT=${1:-$R/out/hak5}
case $OUT in /*) ;; *) OUT=$(pwd)/$OUT ;; esac

# every source present, and the two Overview copies identical, before anything is written
printf '%s\n' "$MAP" | while IFS='|' read -r _n _s _x; do
    [ -f "$R/$_s" ] || die 2 "source file missing: $_s"
done || exit 2
cmp -s "$R/starchorus-display.sh" "$R/$PKGREL/starchorus-display.sh" \
    || die 2 "the two starchorus-display.sh copies differ (repo root and $PKGREL)"

DST=$OUT/$PKGREL

# The target directory is replaced as a whole, so it must not be, hold or sit inside anything this script copies from: the repo
# keeps the payload's own sources under the same relative path (PKGREL), and an OUTDIR of "." from the repo root would name them.
# The target itself is resolved, not only OUTDIR: a link anywhere along OUTDIR/PKGREL (library, library/user, the target) is followed,
# and a ".." that follows a directory which does not exist yet cannot be resolved, so it is refused. Everything is compared in its
# physical form and refused before a single path is removed or made.
# phys PATH: the physical path of PATH, which need not exist (the deepest existing directory is resolved, the rest appended)
phys() {
    _p=$1; _rest=
    while [ "$_p" != / ] && [ ! -d "$_p" ]; do
        _rest=/${_p##*/}$_rest
        case $_p in */*) _p=${_p%/*} ;; *) _p=. ;; esac
        [ -n "$_p" ] || _p=/
    done
    case $_rest in */..|*/../*) return 1 ;; esac
    _d=$(cd -P "$_p" 2>/dev/null && pwd -P) || return 1   # -P: a link followed by .. is resolved as the kernel resolves it, not as text
    case $_d in /) printf '%s\n' "$_rest" ;; *) printf '%s%s\n' "$_d" "$_rest" ;; esac
}
RP=$(cd "$R" && pwd -P) || die 2 "cannot resolve the repo"
OUTP=$(phys "$OUT") || die 2 "cannot resolve $OUT (a '..' after a directory that does not exist, or no such place): choose another output directory"
[ "$OUTP" != "$RP" ] || die 2 "the output directory is the repo root ($OUT): the target would be the payload's own sources"
# two physical forms of the target: where the swap acts (the resolved parent plus the name: DST, DST.tmp and DST.old.PID sit there)
# and where DST leads when it is itself a link to a directory
PARP=$(phys "$OUT/${PKGREL%/*}") || die 2 "cannot resolve $OUT/${PKGREL%/*}: choose another output directory"
TGTP=$(phys "$DST") || die 2 "cannot resolve $DST: choose another output directory"
for DSTP in "$PARP/${PKGREL##*/}" "$TGTP"; do
    case $DSTP in
        "$RP/$PKGREL"|"$RP/$PKGREL"/*|"$RP/$PKGREL.tmp"|"$RP/$PKGREL.tmp"/*|"$RP/$PKGREL.old"|"$RP/$PKGREL.old"/*|"$RP/$PKGREL.old."*)
            die 2 "the target $DSTP lies in the repo's own payload directory ($PKGREL): choose another output directory" ;;
    esac
    printf '%s\n' "$MAP" | while IFS='|' read -r _n _s _x; do
        case $_s in */*) _sd=$(cd "$R/${_s%/*}" 2>/dev/null && pwd -P) || exit 1 ;; *) _sd=$RP ;; esac
        _sp=$_sd/${_s##*/}
        case "$_sp" in
            "$DSTP"|"$DSTP"/*|"$DSTP.tmp"|"$DSTP.tmp"/*) printf 'hak5-package: %s\n' "the target $DSTP is, or holds, the source $_s: choose another output directory" >&2; exit 1 ;;
        esac
        case "$DSTP" in
            "$_sp"/*|"$_sp") printf 'hak5-package: %s\n' "the target $DSTP lies inside the source $_s: choose another output directory" >&2; exit 1 ;;
        esac
    done || exit 2
done

# ... and by identity: pwd -P keeps the letter case it was given, so on a case-insensitive file system (macOS by default) the repo
# written in other case passes every string test above while naming the same directories. test -ef (same device and inode, false
# for a path that does not exist) closes that: OUTDIR is not the repo root, OUTDIR's library/user/reconnaissance is not the repo's,
# and none of the places the swap acts on (the target, target.tmp, target.old.PID) is a source or any directory above one, up to /.
OLD=$DST.old.$$
if [ "$OUT" -ef "$R" ]; then die 2 "the output directory is the repo root ($OUT): the target would be the payload's own sources"; fi
if [ "$OUT/${PKGREL%/*}" -ef "$R/${PKGREL%/*}" ]; then
    die 2 "$OUT/${PKGREL%/*} is the repo's own ${PKGREL%/*}: the target would be the payload's own sources; choose another output directory"
fi
printf '%s\n' "$MAP" | while IFS='|' read -r _n _s _x; do
    case $_s in */*) _sd=$(cd "$R/${_s%/*}" 2>/dev/null && pwd -P) || exit 1 ;; *) _sd=$RP ;; esac
    _a=$_sd/${_s##*/}
    while :; do
        for _t in "$DST" "$DST.tmp" "$OLD"; do
            if [ "$_t" -ef "$_a" ]; then
                printf 'hak5-package: %s\n' "$_t is the same file or directory as $_a, which is or holds the source $_s: choose another output directory" >&2; exit 1
            fi
        done
        [ "$_a" != / ] || break
        _a=${_a%/*}; [ -n "$_a" ] || _a=/
    done
done || exit 2
# ... and the other direction by identity, the twin of the string test "lies in the repo's own payload directory" above: neither OUTDIR
# nor the target, in any of their physical forms, nor any directory above them up to /, is the repo's payload directory (or its .tmp
# or .old beside it), so the payload directory written in other letter case, or a path inside it, is refused as its exact spelling is.
for _w in "$OUTP" "$PARP/${PKGREL##*/}" "$TGTP"; do
    while :; do
        for _t in "$R/$PKGREL" "$R/$PKGREL.tmp" "$R/$PKGREL.old"; do
            if [ "$_w" -ef "$_t" ]; then
                die 2 "$_w is the same directory as $_t, the repo's own payload directory ($PKGREL) or one beside it: choose another output directory"
            fi
        done
        [ "$_w" != / ] || break
        _w=${_w%/*}; [ -n "$_w" ] || _w=/
    done
done

mkdir -p "$OUT/library/user/reconnaissance" || die 2 "cannot create $OUT"
rm -rf "$DST.tmp" || die 2 "cannot clear $DST.tmp"
mkdir "$DST.tmp" || die 2 "cannot create $DST.tmp"
printf '%s\n' "$MAP" | while IFS='|' read -r _n _s _x; do
    cp "$R/$_s" "$DST.tmp/$_n" || exit 1
    if [ "$_x" = x ]; then chmod 755 "$DST.tmp/$_n"; else chmod 644 "$DST.tmp/$_n"; fi || exit 1
done || { rm -rf "$DST.tmp"; die 2 "copy into $DST failed"; }
# swap, not delete-then-build: the old directory is moved aside first and removed once the new one stands
# (the name carries this process's id, so a sibling the user already had called starchorus.old is never touched)
rm -rf "$OLD" || die 2 "cannot clear $OLD"
if [ -e "$DST" ] || [ -L "$DST" ]; then mv "$DST" "$OLD" || { rm -rf "$DST.tmp"; die 2 "cannot move $DST aside"; }; fi
mv "$DST.tmp" "$DST" || die 2 "cannot rename $DST.tmp"
rm -rf "$OLD"

n=$(printf '%s\n' "$MAP" | wc -l | tr -d ' ')
v=$(sed -n 's/^# Version: *\([0-9][0-9A-Za-z.-]*\)$/\1/p' "$DST/payload.sh" | head -n 1)
printf 'hak5-package: %s files, payload %s -> %s\n' "$n" "${v:-?}" "$DST"
