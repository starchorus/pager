# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/doc-drift.sh -- documentation, version, doc drift. Sourced by tools/regress.sh
# with cwd = repo root, after the core rows. Only DRF_* globals are set; no Chrome run (all rows static).
#
# R6 ties the three places that carry the version together, so a bump can never land in only one of them.
# R7 keeps the documentation from drifting: the README avoids theme words (transport-like, NORAD, PPI,
# bearing-grid, phosphor-green), the spec chapter §14 stays complete (D1-D20, P1-P10, U1-U4 with U1 still open),
# and neither the spec nor the README carries a film quotation. The README's two statements
# about the source line are checked against the page itself (COPY_ACTIVE and the stale chip label are read
# out of starchorus.html), so a re-voicing of the copy tokens turns the row red instead of silently
# making the README wrong.
# U3 on the device: the payload's window/interval defaults (3600/30) and that tools/install.sh takes the window from the
# payload (its dry run, also on a copy with another default); the installer's --status/--stop hints carry STARCHORUS_OUTDIR.

DRF_S=docs/architecture.md

# ---- R6: version html = spec §10
DRF_V=$(sed -n 's/^  version: "\([0-9.]*\)",$/\1/p' starchorus.html)
DRF_P=$(sed -n 's/^  version: "\([0-9.]*\)",$/\1/p' "$DRF_S")
if [ -n "$DRF_V" ] && [ "$DRF_V" = "$DRF_P" ]; then
  row "version html = spec §10 ($DRF_V)" PASS
else
  row "version html ${DRF_V:-?} / spec ${DRF_P:-?}" FAIL
fi

# ---- R7: README avoids these theme words, spec §14 complete
DRF_A=$(grep -ciE 'transport-(like|style)' README.md)
DRF_B=$(grep -ciw -e norad -e ppi -e 'phosphor-green' -e 'bearing-grid' README.md)
DRF_D=$(awk '/^## 14\./,0' "$DRF_S" | grep -oE '\| D([1-9]|1[0-9]|20) \|' | sort -u | wc -l | tr -d ' ')
DRF_P10=$(awk '/^## 14\./,0' "$DRF_S" | grep -oE '\*\*P([1-9]|10)\*\*' | sort -u | wc -l | tr -d ' ')
DRF_U=$(awk '/^## 14\./,0' "$DRF_S" | grep -oE '^\| U[1-4] \|' | sort -u | wc -l | tr -d ' ')
if [ "$DRF_A$DRF_B" = 00 ] && [ "$DRF_D/$DRF_P10/$DRF_U" = 20/10/4 ]; then
  row "doc drift: README theme words 0, spec §14 D20/P10/U4" PASS
else
  row "doc drift: README $DRF_A/$DRF_B, spec §14 $DRF_D/$DRF_P10/$DRF_U" FAIL
fi

# ---- spec chapter shape: one heading, ten sections, U1 still open, the three analysis toggles in §14.8, every
# button id that §14.8 names exists in the page (a toggle the page does not have may not be documented).
DRF_H=$(grep -c '^## 14\. Guiding principles and decisions$' "$DRF_S")
DRF_SEC=$(grep -cE '^### 14\.([1-9]|10) ' "$DRF_S")
DRF_U1=$(awk '/^## 14\./,0' "$DRF_S" | grep -c '^| U1 .*open')
DRF_T=$(awk '/^### 14\.8/,/^### 14\.9/' "$DRF_S" | grep -oE 't-(obs|inv|baseline)' | sort -u | wc -l | tr -d ' ')
DRF_TM=""
for DRF_I in $(awk '/^### 14\.8/,/^### 14\.9/' "$DRF_S" | grep -oE "\`t-[a-z]+\`" | tr -d '`' | sort -u); do
  grep -q "id=\"$DRF_I\"" starchorus.html || DRF_TM="$DRF_TM $DRF_I"
done
if [ "$DRF_H/$DRF_SEC/$DRF_U1/$DRF_T" = 1/10/1/3 ] && [ -z "$DRF_TM" ]; then
  row "spec §14 shape (1 chapter, 10 sections, U1 open, 3 toggles, all §14.8 buttons in the page)" PASS
else
  row "spec §14 shape $DRF_H/$DRF_SEC/$DRF_U1/$DRF_T (want 1/10/1/3), §14.8 buttons missing in the page:${DRF_TM:- none}" FAIL
fi

# ---- no film quotation in spec or README; the font provenance (Highway Gothic) is named in README and page
DRF_F=$(grep -ci 'shall we play' "$DRF_S" README.md | sed 's/^[^:]*://' | paste -sd/ -)
DRF_HG=$(grep -c 'Highway Gothic' README.md)
DRF_HGH=$(grep -c 'Highway Gothic' starchorus.html)
if [ "$DRF_F" = 0/0 ] && [ "$DRF_HG" -ge 1 ] && [ "$DRF_HGH" -ge 1 ]; then
  row "docs: no film quotation ($DRF_F), Highway Gothic in README+page" PASS
else
  row "docs: film quotation $DRF_F, Highway Gothic $DRF_HG/$DRF_HGH" FAIL
fi

# ---- the README's two source-line statements quote the page verbatim (copy tokens, not hand-written prose)
DRF_ACT=$(sed -n 's/^const COPY_ACTIVE = "\([^"]*\)".*/\1/p' starchorus.html | head -n 1)
DRF_CHIP=$(sed -n 's/^  chip: {.*stale: "\([^"]*\)".*/\1/p' starchorus.html | head -n 1)
if [ -n "$DRF_ACT" ] && [ -n "$DRF_CHIP" ] &&
   [ "$(grep -cF "$DRF_ACT" README.md)" -ge 1 ] && [ "$(grep -cF "'$DRF_CHIP'" README.md)" -ge 1 ]; then
  row "README quotes COPY_ACTIVE + chip '$DRF_CHIP' verbatim" PASS
else
  row "README misses COPY_ACTIVE (${DRF_ACT:-?}) or chip (${DRF_CHIP:-?})" FAIL
fi

# ---- U3 on the device: the payload reads a 1 h window every 30 s (the device's CPU cannot process the whole record each
# cycle), and tools/install.sh's test capture takes that window FROM the payload. The dry run prints the exact --once
# command, so the installer's parsed value is read from its own output, not from a second copy of its sed. A copy of the
# repo files with a different payload default must move the dry run with it (the value is read, not typed in install.sh).
DRF_PL=library/user/reconnaissance/starchorus/payload.sh
# shellcheck disable=SC2016  # literal ${...}/$VAR of the scanned script text, nothing is meant to expand
DRF_MA=$(sed -n 's/^export STARCHORUS_MAX_AGE="\${STARCHORUS_MAX_AGE:-\([0-9][0-9]*\)}".*/\1/p' "$DRF_PL" | head -n 1)
# shellcheck disable=SC2016  # literal ${...}/$VAR of the scanned script text, nothing is meant to expand
DRF_IV=$(sed -n 's/^export STARCHORUS_INTERVAL="\${STARCHORUS_INTERVAL:-\([0-9][0-9]*\)}".*/\1/p' "$DRF_PL" | head -n 1)
DRF_DRY=$(sh tools/install.sh --dry-run 2>&1); DRF_DRC=$?
DRF_IM=$(printf '%s\n' "$DRF_DRY" | sed -n 's/.* STARCHORUS_MAX_AGE=\([0-9][0-9]*\) \.\/starchorus-collect\.sh --once.*/\1/p' | head -n 1)
DRF_NT=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-drf.XXXXXX") || DRF_NT=""
DRF_NM=""
if [ -n "$DRF_NT" ] && mkdir -p "$DRF_NT/tools" "$DRF_NT/library/user/reconnaissance/starchorus"; then
  cp tools/install.sh "$DRF_NT/tools/"
  cp starchorus-collect.sh starchorus.html starchorus-display.sh starchorus-serve.sh "$DRF_NT/"
  cp library/user/reconnaissance/starchorus/starchorus-display.sh "$DRF_NT/library/user/reconnaissance/starchorus/"
  # shellcheck disable=SC2016  # literal ${...}/$VAR of the scanned script text, nothing is meant to expand
  sed 's/^\(export STARCHORUS_MAX_AGE="\${STARCHORUS_MAX_AGE:-\)[0-9][0-9]*}"/\11234}"/' "$DRF_PL" > "$DRF_NT/$DRF_PL"
  DRF_NM=$(sh "$DRF_NT/tools/install.sh" --dry-run 2>&1 | sed -n 's/.* STARCHORUS_MAX_AGE=\([0-9][0-9]*\) \.\/starchorus-collect\.sh --once.*/\1/p' | head -n 1)
  rm -rf "$DRF_NT"
fi
rowif "payload defaults MAX_AGE 3600 / INTERVAL 30; install.sh --once takes the payload's (dry run $DRF_IM, exit $DRF_DRC; copy with 1234 -> ${DRF_NM:-?})" \
  [ "$DRF_MA/$DRF_IV/$DRF_IM/$DRF_DRC/$DRF_NM" = 3600/30/3600/0/1234 ]

# ---- the installer's closing hints for manual control name the payload's output directory: without STARCHORUS_OUTDIR,
# --status looks in the collector's default directory and reports "not running" while the payload's loop runs.
# Read from the dry run (it prints the same two hints) and from the source: every --status/--stop line of install.sh sets
# STARCHORUS_OUTDIR=$LOOT, the closing text uses those two commands, $LOOT is the payload's STARCHORUS_DIR (= its OUTDIR).
# The payload's directory line is a fixed path or, overridable for tests, "${STARCHORUS_DIR:-/path}": both forms are read, and
# exactly one such line must exist (a second, later assignment would make the parsed default a lie).
# shellcheck disable=SC2016  # literal ${...} of the scanned script text, nothing is meant to expand
DRF_PD=$(sed -n -e 's/^STARCHORUS_DIR=\(\/[^ }]*\)$/\1/p' -e 's/^STARCHORUS_DIR=\${STARCHORUS_DIR:-\(\/[^ }]*\)}$/\1/p' "$DRF_PL" | head -n 1)
DRF_PDN=$(grep -c '^[[:space:]]*STARCHORUS_DIR=' "$DRF_PL")
# shellcheck disable=SC2016  # literal ${...}/$VAR of the scanned script text, nothing is meant to expand
DRF_PO=$(grep -c '^export STARCHORUS_OUTDIR="\$STARCHORUS_DIR"$' "$DRF_PL")
DRF_LT=$(sed -n 's/^LOOT=\(\/[^ ]*\)$/\1/p' tools/install.sh | head -n 1)
DRF_HS=$(printf '%s\n' "$DRF_DRY" | grep -c "^  ssh root@[^ ]* 'cd $DRF_PD && STARCHORUS_OUTDIR=$DRF_PD \./starchorus-collect\.sh --status'$")
DRF_HP=$(printf '%s\n' "$DRF_DRY" | grep -c "^  ssh root@[^ ]* 'cd $DRF_PD && STARCHORUS_OUTDIR=$DRF_PD \./starchorus-collect\.sh --stop'$")
DRF_SL=$(grep -cE 'collect\.sh --(status|stop)' tools/install.sh)
# shellcheck disable=SC2016  # literal ${...}/$VAR of the scanned script text, nothing is meant to expand
DRF_SO=$(grep -E 'collect\.sh --(status|stop)' tools/install.sh | grep -c 'STARCHORUS_OUTDIR=\$LOOT ')
# shellcheck disable=SC2016  # literal ${...}/$VAR of the scanned script text, nothing is meant to expand
DRF_HC=$(grep -cE '^  ssh root@\$HOST \$\(shq "\$CMD_(STATUS|STOP)"\)$' tools/install.sh)
DRF_HOK=0
[ -n "$DRF_PD" ] && [ "$DRF_PDN" = 1 ] && [ "$DRF_LT" = "$DRF_PD" ] && [ "$DRF_PO/$DRF_HS/$DRF_HP/$DRF_HC" = 1/1/1/2 ] && [ "$DRF_SL" -ge 2 ] && [ "$DRF_SO" = "$DRF_SL" ] && DRF_HOK=1
rowif "install hints carry STARCHORUS_OUTDIR=$DRF_PD (dry run $DRF_HS/$DRF_HP, source $DRF_SO/$DRF_SL, closing $DRF_HC/2, LOOT $DRF_LT, payload OUTDIR $DRF_PO, DIR lines $DRF_PDN)" [ "$DRF_HOK" = 1 ]
