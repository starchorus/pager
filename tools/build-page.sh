#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/build-page.sh -- builds starchorus.html from the fragments under src/; the manifest src/PAGE.list names them, in order.
# usage: sh tools/build-page.sh            write starchorus.html (a temporary file beside it, then mv)
#        sh tools/build-page.sh --check    build to a temporary file and compare it byte for byte with starchorus.html;
#                                          writes nothing; exit 0 = identical, 1 = different (names the first differing line where
#                                          cmp names one, not for a difference only in length), 2 = the page is missing
#        sh tools/build-page.sh --where N  the fragment and the line in it that hold line N of the built page
#        sh tools/build-page.sh --list     the manifest, one fragment per line, with its byte count
# Building is pure concatenation: cat in manifest order. No minifying, no stripping of comments, no reformatting; the font stays
# base64 in section 00. The built page stays committed and byte-identical to the build: the device, the Hak5 package and
# tools/install.sh read the single file. The pre-commit hook only CHECKS (tools/static.sh, row "page = build of src/"); it never
# rebuilds, because that would change the index behind the author's back. Rebuilding is the author's step, and src/ and the page go
# into one commit.
# Exit 0 = done / identical, 1 = the page differs from the build (--check) or the line is past the page (--where),
# 2 = usage or setup (manifest or fragment missing or unusable, no mktemp; with --check also the page missing).
# Needs only cat cmp mv chmod rm sed wc tr mktemp dirname (harness.sh PF_TOOLS_BASE). No git, no network, no device. Dev machine only.
set -u
root=$(cd "$(dirname "$0")/.." && pwd) || exit 2
src=$root/src; page=$root/starchorus.html
usage() { echo "usage: sh tools/build-page.sh [--check | --list | --where N]" >&2; exit 2; }
mode=build; want=
case "${1:-}:$#" in
  :0) ;;
  --check:1) mode=check ;;
  --list:1) mode=list ;;
  --where:2) mode=where; want=$2; case $want in '' | 0* | *[!0-9]*) usage ;; esac ;;
  *) usage ;;
esac
[ -s "$src/PAGE.list" ] || { echo "build-page: src/PAGE.list is missing or empty" >&2; exit 2; }
set --   # from here on the positional parameters are the fragments, as full paths, in manifest order
while IFS= read -r p || [ -n "$p" ]; do
  case $p in '' | /* | *..* | *[!A-Za-z0-9._/-]*) echo "build-page: src/PAGE.list: unusable path '$p'" >&2; exit 2 ;; esac
  [ -f "$src/$p" ] || { echo "build-page: src/$p (named in src/PAGE.list) is missing" >&2; exit 2; }
  set -- "$@" "$src/$p"
done < "$src/PAGE.list"
if [ "$mode" = list ]; then
  tot=0
  for f in "$@"; do b=$(wc -c < "$f" | tr -d ' '); printf '%8d  %s\n' "$b" "${f#"$src"/}"; tot=$((tot + b)); done
  printf '%8d  total, %d fragments\n' "$tot" "$#"; exit 0
fi
if [ "$mode" = where ]; then
  n=$want
  for f in "$@"; do
    c=$(wc -l < "$f" | tr -d ' ')   # newlines, as cat joins the files
    if [ "$n" -le "$c" ]; then echo "src/${f#"$src"/}:$n"; exit 0; fi
    n=$((n - c))
  done
  echo "build-page: line $want is past the end of the built page" >&2; exit 1
fi
if [ "$mode" = check ]; then dir=${TMPDIR:-/tmp}; else dir=$root; fi   # a build is moved over the page, so it is made beside it
tmp=$(mktemp "$dir/starchorus-page.XXXXXX") || { echo "build-page: mktemp failed" >&2; exit 2; }
trap 'rm -f "$tmp"' EXIT
trap 'exit 130' INT TERM HUP
cat "$@" > "$tmp" || { echo "build-page: cat of the fragments failed" >&2; exit 2; }
if [ "$mode" = build ]; then
  if ! { chmod 644 "$tmp" && mv -f "$tmp" "$page"; }; then echo "build-page: cannot write starchorus.html" >&2; exit 2; fi
  echo "build-page: wrote starchorus.html from $# fragments, $(wc -c < "$page" | tr -d ' ') bytes"; exit 0
fi
[ -f "$page" ] || { echo "build-page: starchorus.html is missing" >&2; exit 2; }
if cmp -s "$tmp" "$page"; then
  echo "build-page: starchorus.html is the build of $# fragments, $(wc -c < "$page" | tr -d ' ') bytes"; exit 0
fi
echo "build-page: starchorus.html differs from the build of src/ ($(wc -c < "$tmp" | tr -d ' ') bytes built, $(wc -c < "$page" | tr -d ' ') in the page)" >&2
d=$(cmp "$tmp" "$page" 2>&1 | sed -n 's/.* line \([0-9][0-9]*\).*/\1/p')
if [ -n "$d" ]; then
  w=$(sh "$0" --where "$d" 2>/dev/null) && echo "build-page: first difference at built line $d, which is $w" >&2
fi
echo "build-page: rebuild with  sh tools/build-page.sh  and commit src/ and starchorus.html together" >&2
exit 1
