#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/quick.sh -- tier T1: the fast, Chrome-free checks. Run by .githooks/pre-commit on the index.
# usage: sh tools/quick.sh [PREFIX]        (any cwd; writes out/PREFIX-*; prints the environment, the rows and a summary line)
#        sh tools/quick.sh docs [PREFIX]   the DOCUMENTS mode (see below; default prefix qd)
# exit 0 = every row PASS, 1 = at least one FAIL, 2 = setup problem.
# One source: the rows are tools/static.sh (also run first by tools/regress.sh) plus the drop-ins named in QUICK_DROPINS
# (tools/static.sh; each is verified Chrome-free by a row) plus `denylist-check.sh --selftest` and `--extended`.
#   QUICK_MUTATE=1   also run the passivity mutation probe (drop-in mutation-probe, whose two halves run at the same time: about 21 minutes); the hook sets it when
#                    tools/passivity-check.sh or tools/passivity-mutate.sh is staged. Without it that probe is T2 only.
# The collector selftest (about 20 s) is not part of T1 either (STATIC_SELFTEST=0): it runs in tools/regress.sh.
# NOT proven: that the RUNNING page is passive (source text only; the runtime network comes in T2), anything under BusyBox,
# anything on the device. Green here does not replace tools/regress.sh.
# Documents mode (`docs`): the three drop-ins that bind the documents to the code and nothing else: doc-drift (version, spec chapter,
#   the installer's plan), doc-binding (spec tables, STARCHORUS functions, hotkeys and query parameters against the page) and doc-truth
#   (hand-typed lists and numbers against their sources). It does not source the static rows; it writes the two shell-file lists doc-truth
#   reads (the same two commands as tools/static.sh, and a row says when static.sh has changed them) and takes row/rowif/ge from static.sh
#   itself. About fifteen seconds. Unlike T1 it NEEDS CHROME: doc-binding dumps the themes and the API of the running page through the
#   harness (runq), so the preflight adds chrome and a machine without it is "MISSING: chrome", exit 2. The hook runs this mode when a
#   document is staged (.githooks/pre-commit). Summary line: `quick docs: N PASS, M FAIL, T s`.
# Preflight: python3, shellcheck, jq and the POSIX tools it uses (harness.sh PF_TOOLS_QUICK); missing -> "MISSING: tool", exit 2.
# Wall time per phase and drop-in: out/PREFIX-timing.txt. STARCHORUS_PREFLIGHT_ONLY=1 stops after the preflight (probe mode).
# Dev machine only; nothing here runs on the device or sends anything.
# shellcheck source-path=SCRIPTDIR source=harness.sh
. "$(dirname "$0")/harness.sh" || exit 2
# Preflight: a missing tool is exit 2 with "MISSING: tool", not a pile of follow-up FAILs. T1 needs no Chrome and no sqlite3.
QMODE=std; QK_EXTRA=""
if [ "${1:-}" = docs ]; then QMODE=docs; QK_EXTRA=chrome; shift; fi
# shellcheck disable=SC2086   # the tool list is a word list on purpose
preflight $PF_TOOLS_QUICK $QK_EXTRA || exit 2
[ "${STARCHORUS_PREFLIGHT_ONLY:-0}" != 1 ] || { echo "preflight: ok (T1${QK_EXTRA:+, documents mode})"; exit 0; }   # probe mode of tools/regress.d/preflight.sh
P=${1:-qk}; [ "$QMODE" != docs ] || P=${1:-qd}; cd "$R" || exit 2
if [ "$QMODE" = docs ]; then
  # row/rowif/ge/g/le/secs/notcov and the counters are taken from static.sh itself (from `fail=0` to `secs()`), so that there is one
  # definition of how a row is printed; static.sh is NOT sourced as a whole (its rows are the T1 rows, minutes of work).
  qh="out/$P-rowfns.sh"; mkdir -p out
  sed -n '/^fail=0$/,/^secs() /p' tools/static.sh > "$qh"
  # shellcheck disable=SC1090   # generated from static.sh just above
  . "./$qh"
  for qf in row rowif ge; do
    command -v "$qf" > /dev/null 2>&1 || { echo "quick docs: cannot take $qf from tools/static.sh (the block from 'fail=0' to 'secs()' has moved)" >&2; exit 2; }
  done
  QUICK_DOCS_DROPINS="doc-drift doc-binding doc-truth"
  t0=$(date +%s)
  out="out/$P-quick.txt"
  tm_begin "out/$P-timing.txt"
  # shellcheck disable=SC2094   # the group reads its own output file on purpose (rows per drop-in), never rewrites it
  {
    # the lists doc-truth compares with the shell files the repository has: the two commands of tools/static.sh (the shellcheck rows)
    { printf '%s\n' starchorus-collect.sh starchorus-display.sh payload.sh starchorus-serve.sh; find library -type f -name '*.sh' | LC_ALL=C sort; } > "out/$P-shfiles.txt"
    set -- tools/*.sh; for x in tools/regress.d/*.sh; do [ -f "$x" ] && set -- "$@" "$x"; done
    printf '%s\n' "$@" > "out/$P-shfiles-tools.txt"
    # drift guard: static.sh must still write them the way the two lines above do, or this mode would hand doc-truth another list
    qs1=$(grep -cF "{ printf '%s\\n' starchorus-collect.sh starchorus-display.sh payload.sh starchorus-serve.sh; find library -type f -name '*.sh' | LC_ALL=C sort; } > \"out/\$P-shfiles.txt\"" tools/static.sh)
    qs2=$(grep -cF "set -- tools/*.sh; for x in tools/regress.d/*.sh; do [ -f \"\$x\" ] && set -- \"\$@\" \"\$x\"; done" tools/static.sh)
    qs3=$(grep -cF "printf '%s\\n' \"\$@\" > \"out/\$P-shfiles-tools.txt\"" tools/static.sh)
    rowif "documents mode: the shell-file lists are written as tools/static.sh writes them" [ "$qs1/$qs2/$qs3" = 1/1/1 ]
    tm_lap "phase file lists"
    for d in $QUICK_DOCS_DROPINS; do
      [ -f "tools/regress.d/$d.sh" ] || { row "quick docs drop-in $d exists" FAIL; continue; }
      qb=$(grep -c ' PASS$' "$out")
      # shellcheck disable=SC1090   # named just above; the static rows shellcheck every drop-in
      . "./tools/regress.d/$d.sh"
      qa=$(($(grep -c ' PASS$' "$out") - qb))
      rowif "quick docs drop-in $d ran ($qa rows)" [ "$qa" -ge 1 ]
      tm_lap "drop-in $d"
    done
  } > "$out" 2>&1
  tm_total
  cat "$out"
  np=$(grep -c ' PASS$' "$out"); nf=$(grep -c ' FAIL$' "$out")
  echo "quick docs: $np PASS, $nf FAIL, $(($(date +%s) - t0)) s"
  [ "$fail" = 0 ] && [ "$nf" = 0 ] && [ "$np" -ge 1 ]
  exit $?
fi
STATIC_SELFTEST=0   # read by tools/static.sh
t0=$(date +%s)
out="out/$P-quick.txt"
tm_begin "out/$P-timing.txt"   # wall time per phase and drop-in (whole seconds), like tools/regress.sh writes it
# shellcheck disable=SC2094   # the group reads its own output file on purpose (rows per drop-in), never rewrites it
{
  # shellcheck source-path=SCRIPTDIR source=static.sh
  . "$R/tools/static.sh"
  tm_lap "phase static.sh rows"
  qd=$QUICK_DROPINS; [ "${QUICK_MUTATE:-0}" = 1 ] && qd="$qd $QUICK_DROPINS_MUTATE"
  # jq-noregex RUNS the display script copies (--once, under a jq wrapper). A staged display script that already failed the static rules above
  # (passivity, legal, shellcheck, cmp) is not run by the hook: the drop-ins wait until those rows are green.
  if [ "$fail" != 0 ]; then
    echo "note: quick drop-ins not run ($qd): a static row above is red, and staged scripts that failed it are not executed"
  else
    for d in $qd; do
      [ -f "tools/regress.d/$d.sh" ] || { row "quick drop-in $d exists" FAIL; continue; }
      qb=$(grep -c ' PASS$' "$out")
      # shellcheck disable=SC1090   # named in QUICK_DROPINS; the static rows shellcheck every drop-in
      . "./tools/regress.d/$d.sh"
      # a drop-in that ran must have said something green: the count is a row, tools/regress.sh asks for it by name
      qa=$(($(grep -c ' PASS$' "$out") - qb))
      rowif "quick drop-in $d ran ($qa rows)" [ "$qa" -ge 1 ]
      tm_lap "drop-in $d"
    done
  fi
  if qo=$(sh tools/denylist-check.sh --selftest 2>&1); then
    row "denylist selftest ($(printf '%s\n' "$qo" | sed -n 's/^selftest: positives hit \([0-9/]*\), negatives hit \([0-9/]*\)$/pos \1, neg \2/p'))" PASS
  else row "denylist selftest (grep semantics)" FAIL; printf '%s\n' "$qo" | sed 's/^/    /'; fi
  qo=$(sh tools/denylist-check.sh --extended 2>&1); qrc=$?
  qn=$(printf '%s\n' "$qo" | grep -c '^[0-9][0-9]* [0-9][0-9]* [0-9][0-9]* ')
  if [ "$qrc" = 0 ]; then row "denylist --extended = 0 ($qn files)" PASS
  else row "denylist --extended = 0 ($qn files, exit $qrc)" FAIL; printf '%s\n' "$qo" | grep -v '^0 0 0 ' | cut -c1-170 | sed 's/^/    /'; fi
  tm_lap "phase denylist rows"
} > "$out" 2>&1
tm_total
cat "$out"
np=$(grep -c ' PASS$' "$out"); nf=$(grep -c ' FAIL$' "$out")
echo "quick: $np PASS, $nf FAIL, $(($(date +%s) - t0)) s"
[ "$fail" = 0 ] && [ "$nf" = 0 ] && [ "$np" -ge 1 ]
exit $?
