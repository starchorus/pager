#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/fresh-check.sh -- proves "regress runs from a fresh clone". Dev machine only.
# usage: sh tools/fresh-check.sh worktree [PREFIX]  before a commit: copy of `git ls-files -co --exclude-standard`
#        sh tools/fresh-check.sh clone    [PREFIX]  after a commit:  `git clone` of the checked-out branch
# The copy lives in a directory whose name contains a space (quoting test) and regress runs from "/"
# (cwd test) without STARCHORUS_ROOT. It proves: nothing gitignored (out/) is needed, no
# absolute path is baked in, and every row passes there. Exit = regress exit (2 = setup). KEEP=1 keeps it.
set -u
here=$(cd "$(dirname "$0")" && pwd -P) || exit 2
R=$(cd "$here/.." && pwd -P) || exit 2
mode=${1:-worktree}; P=${2:-fc}
base=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-fresh.XXXXXX") || exit 2
dst="$base/starchorus fresh"
# shellcheck disable=SC2317,SC2329   # invoked via trap (SC2317 on ShellCheck < 0.10, SC2329 on >= 0.10)
cleanup() { if [ "${KEEP:-0}" = 1 ]; then echo "fresh-check: kept $dst" >&2; else rm -rf "$base"; fi; }
trap cleanup EXIT
trap 'exit 130' INT TERM
case $mode in
  worktree)
    mkdir -p "$dst" || exit 2
    python3 - "$R" "$dst" <<'PY' || exit 2
import os, shutil, subprocess, sys
src, dst = sys.argv[1:3]
out = subprocess.run(["git", "-C", src, "ls-files", "-z", "-co", "--exclude-standard"],
                     check=True, capture_output=True).stdout
n = 0
for p in filter(None, out.decode("utf-8", "surrogateescape").split("\0")):
    s = os.path.join(src, p)
    if not os.path.isfile(s):          # tracked but deleted in the work tree
        continue
    d = os.path.join(dst, p)
    os.makedirs(os.path.dirname(d), exist_ok=True)
    shutil.copy2(s, d)
    n += 1
print("fresh-check: copied %d files (tracked + untracked, not ignored)" % n, file=sys.stderr)
PY
    ;;
  clone)
    [ -z "$(git -C "$R" status --porcelain)" ] || echo "fresh-check: work tree is dirty; the clone tests HEAD only" >&2
    git clone -q "$R" "$dst" || exit 2 ;;
  *) echo "usage: $0 worktree|clone [PREFIX]" >&2; exit 2 ;;
esac
if [ -e "$dst/out" ]; then echo "fresh-check: out/ is part of the checkout (must stay gitignored)" >&2; exit 2; fi
(unset STARCHORUS_ROOT; cd / && sh "$dst/tools/regress.sh" "$P"); rc=$?
if [ ! -f "$dst/out/$P-demo.json" ]; then echo "fresh-check: regress did not write into the copy's out/" >&2; rc=2; fi
echo "fresh-check ($mode): regress exit $rc"
exit $rc
