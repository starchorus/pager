#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/dump-themes.sh -- dump what the spec quotes from the page, as JSON (via the headless harness, ?debug=1):
#   sh tools/dump-themes.sh themes   [out.json]   the three theme token blocks (STARCHORUS._internals.THEMES)
#   sh tools/dump-themes.sh contrast [out.json]   the WCAG ratios of CONTRAST_PAIRS in every theme (STARCHORUS.contrast)
# tools/spec-sync.py writes (or, with --check, verifies) docs/architecture.md §3.8 and §7.0a from these two files; the "spec binding" rows (tools/regress.d/doc-binding.sh) run the check.
R=$(cd "$(dirname "$0")/.." && pwd)
STARCHORUS_ROOT=$R; export STARCHORUS_ROOT
# shellcheck disable=SC1091
. "$R/tools/harness.sh" || exit 2
what=${1:-themes}
case $what in
  themes)   ev='JSON.stringify(STARCHORUS._internals.THEMES)' ;;
  contrast) ev='JSON.stringify(["foundation","wargames","whitehall"].map(t=>STARCHORUS.contrast(undefined,t)))' ;;
  *) echo "usage: dump-themes.sh themes|contrast [out.json]" >&2; exit 2 ;;
esac
# the harness report goes to $R/out (harness.sh creates it), not to an out/ under the caller's cwd: from any other
# directory the relative path did not exist and the dump failed with "no value"
runq demo "?poll=0&spin=0&intro=0&debug=1" "$R/out/dump-$what" --wait 1 --fps 0 --eval "$ev" >/dev/null 2>&1
v=$(evalv "$R/out/dump-$what.json" 1) || exit 1
[ -n "$v" ] || { echo "dump-themes: no value" >&2; exit 1; }
if [ -n "$2" ]; then printf '%s\n' "$v" > "$2"; else printf '%s\n' "$v"; fi
