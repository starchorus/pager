# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/preflight.sh -- a missing tool is "MISSING: tool" and exit 2, never a pile of follow-up FAILs.
# GUARDS AGAINST: a preflight that was dropped, moved behind the first row, or that names the wrong tool; a sqlite3 switch that
#                 turns the collector selftest into a quiet PASS (or a misleading FAIL) instead of "NOT COVERED".
# NEGATIVE PROBE: preflight call removed from regress.sh/quick.sh => rows 1 and 4 red; PF_TOOLS_QUICK without jq =>
#                 row 1 red ("no MISSING: jq"); the NOT-COVERED redirection in selftest_verdict removed => row 3 red.
# NOT PROVEN:     a missing Chrome is checked only through the stub function _pf_chrome (static.sh), not with a really
#                 hidden Chrome; no tool versions (env_report prints them, without a pin); nothing under BusyBox.
# Sourced by tools/regress.sh (T2: all four rows, both scripts) and tools/quick.sh (T1: quick.sh only, no Chrome/sqlite3/selftest
# needed; it must not depend on the tools T2 adds) with cwd = repo root; Chrome-free. Only PFL_* names are set. The probes run the two
# scripts with a PATH farm (symlinks to every tool of the real PATH except the one under test) in STARCHORUS_PREFLIGHT_ONLY mode, which
# stops right after the preflight, so no row is ever run by a probe. A run started by a probe skips this file (PFL_INNER).
PFL_run() {   # PFL_run FARM SCRIPT [ALLOW_NO_SQLITE, default 0] -> output (stdout+stderr) in $PFL_o, exit status in $PFL_rc; SCRIPT = quick|regress
  PFL_o=$( cd / && PATH="$1" STARCHORUS_PREFLIGHT_ONLY=1 PFL_INNER=1 ALLOW_NO_SQLITE="${3:-0}" "$PFL_sh" "$R/tools/$2.sh" pfprobe 2>&1 ); PFL_rc=$?
}
PFL_msg=""; PFL_t=""; PFL_sh=$(command -v sh)
if [ "${PFL_INNER:-0}" = 1 ]; then
  row "preflight probe: nested run (skipped on purpose)" PASS
else
  PFL_t=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-pf.XXXXXX") || PFL_t=
  if [ -z "$PFL_t" ]; then
    rowif "preflight probes: mktemp" [ -n "$PFL_t" ]
  else
    mkdir "$PFL_t/nojq" "$PFL_t/nosql"; path_farm "$PFL_t/nojq" jq; path_farm "$PFL_t/nosql" sqlite3
    # T2 also probes regress.sh (needs Chrome, sqlite3, ... on the farm); in T1 (STATIC_SELFTEST=0) only quick.sh is probed
    PFL_scripts="quick"; PFL_t2=0
    if [ "${STATIC_SELFTEST:-1}" = 1 ]; then PFL_scripts="quick regress"; PFL_t2=1; fi
    # fairness: the farm really lacks the tool and really has the others
    PFL_fair=0
    [ ! -e "$PFL_t/nojq/jq" ] && [ -x "$PFL_t/nojq/python3" ] && [ ! -e "$PFL_t/nosql/sqlite3" ] && [ -x "$PFL_t/nosql/jq" ] && PFL_fair=1
    [ "$PFL_t2" = 0 ] || [ -x "$PFL_t/nojq/sqlite3" ] || PFL_fair=0
    # 1. no jq: both scripts exit 2, name jq (and only jq), print no row
    PFL_msg="";
    for PFL_s in $PFL_scripts; do
      PFL_run "$PFL_t/nojq" "$PFL_s"
      PFL_n=$(printf '%s\n' "$PFL_o" | grep -c '^MISSING: ')
      PFL_rows=$(printf '%s\n' "$PFL_o" | grep -c -E ' (PASS|FAIL)$')
      { [ "$PFL_rc" = 2 ] && printf '%s\n' "$PFL_o" | grep -q '^MISSING: jq$' && [ "$PFL_n" = 1 ] && [ "$PFL_rows" = 0 ]; } \
        || PFL_msg="$PFL_msg $PFL_s: rc $PFL_rc, $PFL_n MISSING line(s), $PFL_rows row(s);"
    done
    [ "$PFL_fair" = 1 ] || PFL_msg="$PFL_msg the PATH farm is not what it should be;"
    rowif "preflight: PATH without jq: $PFL_scripts exit 2, name only jq, run no row${PFL_msg:+ ($PFL_msg )}" [ -z "$PFL_msg" ]
    # 2. no sqlite3: T1 does not need it; T2 stops with the hint unless the switch says otherwise
    PFL_msg=""
    PFL_run "$PFL_t/nosql" quick;   { [ "$PFL_rc" = 0 ] && printf '%s\n' "$PFL_o" | grep -q '^preflight: ok (T1)$'; } || PFL_msg="$PFL_msg T1 rc $PFL_rc;"
    if [ "$PFL_t2" = 1 ]; then
      PFL_run "$PFL_t/nosql" regress; { [ "$PFL_rc" = 2 ] && printf '%s\n' "$PFL_o" | grep -q '^MISSING: sqlite3 .*ALLOW_NO_SQLITE=1'; } || PFL_msg="$PFL_msg T2 without switch rc $PFL_rc;"
      PFL_run "$PFL_t/nosql" regress 1; { [ "$PFL_rc" = 0 ] && printf '%s\n' "$PFL_o" | grep -q '^preflight: ok (T2)$'; } || PFL_msg="$PFL_msg T2 with switch rc $PFL_rc;"
    fi
    [ "$PFL_fair" = 1 ] || PFL_msg="$PFL_msg the PATH farm is not what it should be;"
    PFL_nm="T1 ok"; [ "$PFL_t2" = 0 ] || PFL_nm="$PFL_nm, T2 exit 2 with the hint, ALLOW_NO_SQLITE=1 passes"
    rowif "preflight: PATH without sqlite3: $PFL_nm${PFL_msg:+ ($PFL_msg )}" [ -z "$PFL_msg" ]
    # 3. the switch end to end: the REAL collector selftest without sqlite3 is judged NOT COVERED (T2 only: 20 s)
    if [ "${STATIC_SELFTEST:-1}" = 1 ]; then
      ( cd "$R" && PATH="$PFL_t/nosql" "$PFL_sh" starchorus-collect.sh --selftest ) > "$PFL_t/st.txt" 2>&1
      PFL_v=$(selftest_verdict "$PFL_t/st.txt" "$MIN_SELFTEST" 0 1); PFL_vc=$?
      PFL_n=$(sed -n 's/.*SELFTEST: ALL PASS (\([0-9][0-9]*\) checks).*/\1/p' "$PFL_t/st.txt" | tail -n 1)
      PFL_okc=0; [ "$PFL_fair" = 1 ] && [ "$PFL_vc" = 3 ] && PFL_okc=1
      rowif "selftest without sqlite3 (PATH farm): ${PFL_n:-no} checks ran, verdict NOT COVERED (rc $PFL_vc, want 3)" [ "$PFL_okc" = 1 ]
      [ "$PFL_okc" = 1 ] || { printf '%s\n' "$PFL_v" | cut -c1-200 | sed 's/^/    /'; tail -n 5 "$PFL_t/st.txt" | cut -c1-200 | sed 's/^/    /'; }
    else
      echo "note: selftest without sqlite3 is not probed here (20 s; it runs in tools/regress.sh, tier T2)"
    fi
    # 4. order in the scripts: the preflight comes before the probe-mode exit, and both before the first row (static.sh)
    PFL_msg=""
    for PFL_s in quick regress; do
      PFL_f="$R/tools/$PFL_s.sh"
      PFL_a=$(grep -n '^preflight [$]PF_TOOLS_' "$PFL_f" | head -n 1 | cut -d: -f1)
      PFL_b=$(grep -n 'STARCHORUS_PREFLIGHT_ONLY' "$PFL_f" | grep -v '^[0-9]*:#' | head -n 1 | cut -d: -f1)
      PFL_c=$(grep -n -F ". \"\$R/tools/static.sh\"" "$PFL_f" | head -n 1 | cut -d: -f1)
      { [ -n "$PFL_a" ] && [ -n "$PFL_b" ] && [ -n "$PFL_c" ] && [ "$PFL_a" -lt "$PFL_b" ] && [ "$PFL_b" -lt "$PFL_c" ]; } \
        || PFL_msg="$PFL_msg $PFL_s.sh: preflight line ${PFL_a:-none}, probe exit ${PFL_b:-none}, first rows ${PFL_c:-none};"
    done
    rowif "preflight comes first in quick.sh and regress.sh (before the probe exit and the first row)${PFL_msg:+ ($PFL_msg )}" [ -z "$PFL_msg" ]
    rm -rf "$PFL_t"
  fi
fi
