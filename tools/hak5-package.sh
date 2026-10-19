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
# replaced as a whole, so a file that has left the map does not linger; nothing outside it is touched.
# Exit: 0 = built, 2 = usage or setup problem (missing source, differing Overview copies, unwritable OUTDIR).
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
    -h|--help) sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
mkdir -p "$OUT/library/user/reconnaissance" || die 2 "cannot create $OUT"
rm -rf "$DST.tmp" "$DST" || die 2 "cannot clear $DST"
mkdir "$DST.tmp" || die 2 "cannot create $DST.tmp"
printf '%s\n' "$MAP" | while IFS='|' read -r _n _s _x; do
    cp "$R/$_s" "$DST.tmp/$_n" || exit 1
    if [ "$_x" = x ]; then chmod 755 "$DST.tmp/$_n"; else chmod 644 "$DST.tmp/$_n"; fi || exit 1
done || { rm -rf "$DST.tmp"; die 2 "copy into $DST failed"; }
mv "$DST.tmp" "$DST" || die 2 "cannot rename $DST.tmp"

n=$(printf '%s\n' "$MAP" | wc -l | tr -d ' ')
v=$(sed -n 's/^# Version: *\([0-9][0-9A-Za-z.-]*\)$/\1/p' "$DST/payload.sh" | head -n 1)
printf 'hak5-package: %s files, payload %s -> %s\n' "$n" "${v:-?}" "$DST"
