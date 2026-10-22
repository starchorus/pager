# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/device-probe.sh -- the device probe (tools/device-probe.sh) on this machine, without a device.
# GUARDS AGAINST: a probe whose list of open verifications has drifted: a V-number that the header contract does not name (with the slug vname
#                 prints), that has no vname entry, no vset, no one-line question, a summary loop that stops short of the last one, a section function that is
#                 not called by name from main (or fewer of them than section banners); a `--list` that fails, prints another number of lines than there are verifications, or writes anything; a guard that no
#                 longer refuses on this machine; V-14 (flock, tail -c, /bin/bash with [[:xdigit:]] in a case) that reports "ok" for a tail that
#                 refuses -c or ignores it, for a bash whose case gives another answer, or that fails on a machine without flock or without bash; a run
#                 that is not silent, leaves its temp directory behind, or whose summary lacks V-14; a literal shell of V-14 that sources the
#                 BASH_ENV file of its environment; a V-14 section that redirects anywhere but /dev/null and its private directory; a passivity
#                 checker that no longer reads the probe (tools/passivity-check.sh lists it in --files, and its three 'device-probe.sh' rows are
#                 red for a sending, scanning, network or changing command anywhere in the probe, the V-14 code included); a probe that shellcheck dislikes.
# NEGATIVE PROBE: planted copies of the probe, each of which must make one named part red: the V-14 line out of the header contract (header:14), vname 14
#                 out (vname:14), the question of V-14 out (question:14), NV=13 (bound), the call of the last section out (call:sect_alertenv, and in a
#                 run "V-14 not observed"), of a middle one (sect_oui) and of the first (sect_jq), the --list handler out (list), a write to /root/ planted into the V-14 code (redirect), a `curl`, a
#                 `hcitool ... scan` and an `iw ... set` planted into the V-14 code of a copy that the passivity checker then reads (its probe rows red), an
#                 unquoted variable (shellcheck), a tail check that always says ok (the run with a tail that ignores -c no longer finds WRONG-OUTPUT), and
#                 the two literal shells without the empty BASH_ENV and ENV in front of them (a run with a BASH_ENV file in its environment then sources it).
#                 The stand-in runs are negative controls of V-14 itself: a tail that refuses -c, a tail that ignores it, a bash that gives the wrong
#                 answer, a bash that is not executable, no bash, no flock.
# NOT PROVEN:     anything on the device: BusyBox's ash, its flock and tail, whether /bin/bash exists there (the stand-ins are what such tools are assumed
#                 to print), and how the firmware starts an alert payload (docs/device-notes.md 5c). The passivity checker reads this probe, whole, with three rows
#                 of its own and a pinned list of the lines that deliberately name a tool or start a program (tools/passivity-check.sh, row 7d; `--files`
#                 prints it after the shell scope); what an awk or sed program in it does with its text is read by nobody (review). The redirection scan below
#                 (the V-14 section only, not the other nine sections) is the one static guard that stays in this file.
# Sourced by tools/regress.sh (T2) and tools/quick.sh (T1) with cwd = repo root; Chrome-free, no network, no device. About three seconds: nine
# runs of the probe in forced mode (STARCHORUS_PROBE_FORCE=1, an empty root, GAP 1, no self-test), 0.3 s each. Sets only DPR_* names. It needs bash
# (the stand-in /bin/bash is a link to the machine's), ls and readlink on the machine: harness.sh PF_TOOLS_QUICK names them, so the preflight stops first.
# The runs use a PATH of symlinks to every tool of the real PATH except flock, busybox and bash, with a directory of stand-ins in front, and a
# root directory of their own for /bin/bash; the probe reads the machine's other files as it would on the device (read only), and writes nowhere
# but the temp directory of the run.

# shellcheck disable=SC2016   # the single quotes below hold program text and patterns for awk, grep and the shells under test: the $ are meant literally
DPR_P=tools/device-probe.sh
DPR_SH=$(command -v sh)
DPR_MINLINES=50          # code lines of the V-14 section the scan reads; measure: DPR_region tools/device-probe.sh | grep -c .   (the row's own count; measured: 63)

# the leading comment block of a probe text = its header contract; the code = every other line, a trailing comment cut off
DPR_head() { awk '/^[^#]/ && NF { exit } { print }' "$1"; }
DPR_code() { grep -v '^[[:space:]]*#' "$1" | sed 's/[[:space:]][[:space:]]*#[[:space:]].*$//'; }
# the code of section 10 (V-14) alone
DPR_region() { awk '/^# =+ 10\. /{ f = 1; next } /^# =+ summary/{ f = 0 } f' "$1" | grep -v '^[[:space:]]*#' | sed 's/[[:space:]][[:space:]]*#[[:space:]].*$//'; }
DPR_slug() { sed -n "s/^ *$2) echo \([a-z0-9-][a-z0-9-]*\) ;;\$/\1/p" "$1" | head -n 1; }   # DPR_slug FILE N -> the name vname gives V-N

DPR_check() {   # DPR_check FILE -> DPR_bad = the parts that fail ("" = all hold)
  DPR_bad=""; DPR_h=$(DPR_head "$1"); DPR_c=$(DPR_code "$1")
  DPR_nv=$(printf '%s\n' "$DPR_c" | sed -n 's/^NV=\([0-9][0-9]*\)$/\1/p' | head -n 1)
  DPR_hm=$(printf '%s\n' "$DPR_h" | sed -n 's/^#[[:space:]][[:space:]]*V-\([0-9][0-9]*\) [a-z].*/\1/p' | sort -n | tail -n 1)
  DPR_nn=$(printf '%s\n' "$DPR_c" | grep -cE '^ *[0-9]+\) echo [a-z0-9-]+ ;;$')
  { ge "${DPR_nv:-0}" 14 && [ "$DPR_nv" = "$DPR_hm" ] && [ "$DPR_nv" = "$DPR_nn" ]; } || DPR_bad="$DPR_bad bound(NV=${DPR_nv:-none},header=${DPR_hm:-none},vname=$DPR_nn)"
  DPR_top=${DPR_nv:-0}; ge "$DPR_top" 14 || DPR_top=14   # the list never gets shorter than V-1 to V-14, whatever NV says
  DPR_i=1
  while [ "$DPR_i" -le "$DPR_top" ]; do
    DPR_sl=$(DPR_slug "$1" "$DPR_i")
    [ -n "$DPR_sl" ] || DPR_bad="$DPR_bad vname:$DPR_i"
    printf '%s\n' "$DPR_h" | grep -Eq "^#[[:space:]]+V-$DPR_i ${DPR_sl:-NOSLUG}([[:space:]]|\$)" || DPR_bad="$DPR_bad header:$DPR_i"
    printf '%s\n' "$DPR_c" | grep -Eq "(^|[^A-Za-z0-9_])vset ${DPR_i}[[:space:]]" || DPR_bad="$DPR_bad vset:$DPR_i"
    printf '%s\n' "$DPR_c" | grep -Eq "^ *$DPR_i\) echo \"" || DPR_bad="$DPR_bad question:$DPR_i"
    DPR_i=$((DPR_i + 1))
  done
  # every section function is called by name from main (one line "    sect_NAME"), and there are as many of them as section banners (10 as of 0.2.5)
  DPR_ns=$(printf '%s\n' "$DPR_c" | grep -cE '^sect_[a-z0-9_]+\(\) \{'); DPR_nb=$(grep -cE '^# =+ [0-9]+\. ' "$1")
  { ge "$DPR_ns" 10 && [ "$DPR_ns" = "$DPR_nb" ]; } || DPR_bad="$DPR_bad sections(defined=$DPR_ns,banners=$DPR_nb)"
  printf '%s\n' "$DPR_c" | sed -n 's/^\(sect_[a-z0-9_]*\)() {.*/\1/p' > "$DPR_T/sects.txt"
  while IFS= read -r DPR_f; do
    printf '%s\n' "$DPR_c" | grep -qx "    $DPR_f" || DPR_bad="$DPR_bad call:$DPR_f"
  done < "$DPR_T/sects.txt"
  # --list: exit 0, nothing on stderr, one line "V-N slug: question" for each verification, and nothing written (TMPDIR is an empty directory)
  if printf '%s\n' "$DPR_c" | grep -q '^if \[ "\${1:-}" = --list \]; then$'; then
    rm -rf "${DPR_T:?}/lt"; mkdir "$DPR_T/lt"
    DPR_lo=$(TMPDIR="$DPR_T/lt" STARCHORUS_PROBE_FORCE=0 "$DPR_SH" "$1" --list < /dev/null 2> "$DPR_T/lt.err"); DPR_lrc=$?
    DPR_ln=$(printf '%s\n' "$DPR_lo" | grep -c '^V-[0-9]')
    DPR_lg=""; DPR_i=1
    while [ "$DPR_i" -le "$DPR_top" ]; do
      DPR_sl=$(DPR_slug "$1" "$DPR_i")
      printf '%s\n' "$DPR_lo" | sed -n "${DPR_i}p" | grep -Eq "^V-$DPR_i ${DPR_sl:-NOSLUG}: [A-Z].{20,}\$" || DPR_lg="$DPR_lg $DPR_i"
      DPR_i=$((DPR_i + 1))
    done
    { [ "$DPR_lrc" = 0 ] && [ ! -s "$DPR_T/lt.err" ] && [ "$DPR_ln" = "$DPR_top" ] && [ -z "$DPR_lg" ] && [ -z "$(ls -A "$DPR_T/lt")" ]; } \
      || DPR_bad="$DPR_bad list(rc=$DPR_lrc,lines=$DPR_ln,badlines:${DPR_lg:-none})"
  else DPR_bad="$DPR_bad list(no handler)"; fi
  # the guard still refuses on a machine that is no device (without --list and without the force switch): exit 2, nothing on stdout
  if [ "$(uname -s)" = Linux ] && [ -f /etc/openwrt_release ]; then :
  else
    DPR_go=$(TMPDIR="$DPR_T/lt" STARCHORUS_PROBE_FORCE=0 "$DPR_SH" "$1" < /dev/null 2> /dev/null); DPR_grc=$?
    { [ "$DPR_grc" = 2 ] && [ -z "$DPR_go" ]; } || DPR_bad="$DPR_bad guard(rc=$DPR_grc)"
  fi
}

DPR_lockform() {   # DPR_lockform PROBE COMPANION -> DPR_lf = the parts that fail ("" = all hold): the probe takes its lock the way the companion does
  DPR_lf=""; DPR_lc=$(DPR_code "$1"); DPR_cc=$(DPR_code "$2")
  # the companion has one line `( flock -x 9; ... ) ... 9> "$DIR/alerts.lock"`: the form the probe copies; the probe has one line of that form on a file of its private directory, takes no other lock,
  # and opens no descriptor with `exec` (a lock taken in the main shell would never be let go)
  [ "$(printf '%s\n' "$DPR_cc" | grep -cE '^[[:space:]]*\( flock -x 9; .* \) .*9> "\$DIR/alerts\.lock"')" = 1 ] || DPR_lf="$DPR_lf companion"
  [ "$(printf '%s\n' "$DPR_lc" | grep -cE '^[[:space:]]*\( flock -x 9; .* \) .*9> "\$T/ae\.lock"')" = 1 ] || DPR_lf="$DPR_lf form"
  [ "$(printf '%s\n' "$DPR_lc" | grep -v '^[[:space:]]*kv ' | grep -cE '(^|[^A-Za-z0-9_])flock -[a-z]')" = 1 ] || DPR_lf="$DPR_lf count"
  ! printf '%s\n' "$DPR_lc" | grep -qE '(^|[^A-Za-z0-9_])exec[[:space:]]+[0-9]*[<>]' || DPR_lf="$DPR_lf exec"
}

DPR_scan() {   # DPR_scan FILE -> DPR_sbad = redirect | empty; DPR_sn = code lines of section 10 read. (The tools it names are read by the passivity checker, row 5b below.)
  DPR_sbad=""; DPR_rg=$(DPR_region "$1"); DPR_sn=$(printf '%s\n' "$DPR_rg" | grep -c .)
  ge "$DPR_sn" "$DPR_MINLINES" || DPR_sbad="$DPR_sbad empty(lines=$DPR_sn)"
  # every redirection of the section goes to /dev/null or to a file of the private directory ($T/ae.NAME)
  DPR_rd=$(printf '%s\n' "$DPR_rg" | grep -oE '[0-9]*>>?[[:space:]]*[^[:space:];|&)]+' | sed -E 's/^[0-9]*>>?[[:space:]]*//' | grep -vE '^(/dev/null|"\$T/ae\.[a-z]+")$')
  [ -z "$DPR_rd" ] || DPR_sbad="$DPR_sbad redirect($(printf '%s\n' "$DPR_rd" | head -n 1 | cut -c1-40))"
}

# one forced run of a probe text on this machine: DPR_run NAME STANDIN_DIR ROOT [PROBE [BASH_ENV_FILE]] -> $DPR_T/NAME.out, NAME.err, the run's TMPDIR NAME.tmp, DPR_rc
# (BASH_ENV is empty in every run unless the fifth argument names a file: the user's own BASH_ENV must not reach the probe)
DPR_run() {
  rm -rf "${DPR_T:?}/$1.tmp"; mkdir "$DPR_T/$1.tmp"
  BASH_ENV="${5:-}" PATH="$2:$DPR_FARM" TMPDIR="$DPR_T/$1.tmp" STARCHORUS_PROBE_FORCE=1 STARCHORUS_PROBE_ROOT="$3" STARCHORUS_PROBE_GAP=1 STARCHORUS_PROBE_SKIP_SELFTEST=1 \
    "$DPR_SH" "${4:-$R/$DPR_P}" < /dev/null > "$DPR_T/$1.out" 2> "$DPR_T/$1.err"; DPR_rc=$?
}
DPR_want=""; DPR_k=1
while [ "$DPR_k" -le 14 ]; do DPR_want="$DPR_want V-$DPR_k"; DPR_k=$((DPR_k + 1)); done
DPR_common() {   # DPR_common NAME -> DPR_cbad: exit 0, silent stderr, section 10, V-1..V-14 in order in the summary, V-14 OBSERVED, temp dir empty afterwards, no MAC-shaped line
  DPR_cbad=""; DPR_o="$DPR_T/$1.out"
  [ "$DPR_rc" = 0 ] || DPR_cbad="$DPR_cbad rc=$DPR_rc"
  [ ! -s "$DPR_T/$1.err" ] || DPR_cbad="$DPR_cbad stderr"
  grep -q '^== 10\. alert payload environment ' "$DPR_o" || DPR_cbad="$DPR_cbad no-section-10"
  [ "$(sed -n '/^== summary ==/,$p' "$DPR_o" | grep -oE '^V-[0-9]+' | tr '\n' ' ' | sed 's/ $//; s/^/ /')" = "$DPR_want" ] || DPR_cbad="$DPR_cbad summary-order"
  grep -q '^V-14 alert-companion-environment: OBSERVED ' "$DPR_o" || DPR_cbad="$DPR_cbad v14-not-observed"
  [ -z "$(ls -A "$DPR_T/$1.tmp")" ] || DPR_cbad="$DPR_cbad tempdir-left"
  grep -q '^privacy-filter: 0 output line' "$DPR_o" || DPR_cbad="$DPR_cbad mac-shaped"
}
DPR_need() {   # DPR_need NAME LABEL REGEX -> adds LABEL to DPR_abad unless a line of the run's output matches
  grep -Eq "$3" "$DPR_T/$1.out" || DPR_abad="$DPR_abad $2"
}
DPR_nonl() {   # DPR_nonl NAME LABEL REGEX -> adds LABEL to DPR_abad when a line DOES match
  ! grep -Eq "$3" "$DPR_T/$1.out" || DPR_abad="$DPR_abad $2"
}
DPR_plant() {   # DPR_plant NAME AWK-PROGRAM -> $DPR_T/NAME.sh = the probe through that awk program; DPR_pbad gets noplant:NAME when the copy equals the probe
  awk "$2" "$R/$DPR_P" > "$DPR_T/$1.sh"
  ! cmp -s "$R/$DPR_P" "$DPR_T/$1.sh" || DPR_pbad="$DPR_pbad noplant:$1"
}

DPR_T=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-dpr.XXXXXX") || DPR_T=""
if [ -z "$DPR_T" ] || [ ! -d "$DPR_T" ]; then
  row "device probe: no temp directory" FAIL
else
DPR_PROBE="$R/$DPR_P"
DPR_BASH=$(command -v bash)
DPR_TAIL=$(command -v tail)
DPR_FARM="$DPR_T/farm"; mkdir "$DPR_FARM"; path_farm "$DPR_FARM" flock busybox bash
# stand-ins, one directory each (a directory with nothing in it for "no flock")
mkdir "$DPR_T/s-none" "$DPR_T/s-ul" "$DPR_T/s-bb" "$DPR_T/s-tailerr" "$DPR_T/s-tailign" "$DPR_T/s-lockfail"
printf '#!/bin/sh\necho "flock from util-linux 2.99 (stand-in)"\n' > "$DPR_T/s-ul/flock"; chmod +x "$DPR_T/s-ul/flock"
printf '#!/bin/sh\ncase ${1:-} in -x) echo "flock: 9: Bad file descriptor" >&2; exit 1 ;; *) echo "flock from util-linux 2.99 (stand-in)" ;; esac\n' > "$DPR_T/s-lockfail/flock"; chmod +x "$DPR_T/s-lockfail/flock"
printf '#!/bin/sh\ncase ${0##*/} in flock) case ${1:-} in -x) exit 0 ;; esac; echo "flock: unrecognized option --version" >&2; echo "Usage: flock [-sxun] FILE PROG" >&2; exit 1 ;; esac\ncase ${1:-} in --list) echo ls; echo flock ;; *) echo "BusyBox v1.36.1 (stand-in) multi-call binary." ;; esac\n' > "$DPR_T/s-bb/busybox"
chmod +x "$DPR_T/s-bb/busybox"; ln -s busybox "$DPR_T/s-bb/flock"
printf '#!/bin/sh\nfor a in "$@"; do case $a in -c) echo "tail: invalid option -- c" >&2; exit 1 ;; esac; done\nexec "%s" "$@"\n' "$DPR_TAIL" > "$DPR_T/s-tailerr/tail"
printf '#!/bin/sh\ncase ${1:-} in -c) cat "$3" ;; *) exec "%s" "$@" ;; esac\n' "$DPR_TAIL" > "$DPR_T/s-tailign/tail"
chmod +x "$DPR_T/s-tailerr/tail" "$DPR_T/s-tailign/tail"
# roots: a real bash, no bash, a bash that gives the wrong answer, a bash that is not executable
mkdir -p "$DPR_T/r-good/bin" "$DPR_T/r-none" "$DPR_T/r-wrong/bin" "$DPR_T/r-noexec/bin"
[ -z "$DPR_BASH" ] || ln -s "$DPR_BASH" "$DPR_T/r-good/bin/bash"
printf '#!/bin/sh\ncase ${1:-} in --version) echo "GNU bash, version 0.0.0(1)-release (stand-in)" ;; -c) echo match; echo match ;; esac\n' > "$DPR_T/r-wrong/bin/bash"; chmod +x "$DPR_T/r-wrong/bin/bash"
printf '#!/bin/sh\n' > "$DPR_T/r-noexec/bin/bash"; chmod 600 "$DPR_T/r-noexec/bin/bash"

# ---- 1 · the probe's own list of verifications: header contract, code, --list, guard
DPR_check "$DPR_PROBE"
DPR_b1=$DPR_bad
rowif "device probe: V-1 to V-14 in the header contract (slug of vname), vname, vset, question, NV and the call; --list exits 0 with one line each and writes nothing; the guard refuses here (bad:${DPR_b1:- none})" [ -z "$DPR_b1" ]

DPR_COMPANION=library/user/reconnaissance/starchorus/alert-deauth.sh
DPR_lockform "$DPR_PROBE" "$R/$DPR_COMPANION"
rowif "device probe: the lock of V-14 is the companion's: one line with a subshell, \`flock -x 9\` and fd 9 opened on a file of the private directory, as in $DPR_COMPANION; no other lock, no \`exec 9>\` (bad:${DPR_lf:- none})" [ -z "$DPR_lf" ]

# ---- 2 · a forced run on this machine with a real bash, a util-linux-looking flock and the real tail: section 10 and the summary
DPR_run r1 "$DPR_T/s-ul" "$DPR_T/r-good"; DPR_common r1; DPR_c1=$DPR_cbad
[ -n "$DPR_BASH" ] || DPR_c1="$DPR_c1 no-bash"   # the stand-in root links the machine's bash: without one the run has nothing to read (harness.sh PF_TOOLS_QUICK names bash)
rowif "device probe: forced run (empty root, GAP 1, no self-test): exit 0, silent, section 10, V-1 to V-14 in order, V-14 OBSERVED, temp dir removed (bad:${DPR_c1:- none})" [ -z "$DPR_c1" ]

# ---- 3 · the readings of V-14: util-linux flock, BusyBox flock, no flock and no bash; tail -c 4 gives the last four bytes
DPR_abad=""
DPR_need r1 r1-flock-path "^flock\\.path: $DPR_T/s-ul/flock\$"
DPR_need r1 r1-flock-kind '^flock\.kind: util-linux \(--version said: flock from util-linux 2\.99'
DPR_need r1 r1-flock-lock '^flock\.lock: ok \(flock -x 9 exited 0 in a subshell on a file of the private directory, as the alert companion takes it; the lock ended with the subshell\)$'
DPR_need r1 r1-tail4 "^tail\\.c4: ok \\(tail -c 4 of the ten bytes 0123456789 printed '6789'\\)\$"
DPR_need r1 r1-tail1 '^tail\.c1: ok '
DPR_need r1 r1-tailbig '^tail\.c262144: ok '
DPR_need r1 r1-bash-path '^bash\.path: /bin/bash present'
DPR_need r1 r1-bash-case '^bash\.xdigit_case: ok$'
DPR_need r1 r1-sh-case '^sh\.xdigit_case: ok$'
DPR_need r1 r1-summary "^V-14 alert-companion-environment: OBSERVED flock: $DPR_T/s-ul/flock, util-linux, lock ok; tail -c 4 of 0123456789 printed '6789' \\(ok\\), -c 1 ok, -c 262144 ok; /bin/bash: present, .*case with \\[\\[:xdigit:\\]\\] under bash: ok, under sh: ok\$"
DPR_run r2 "$DPR_T/s-bb" "$DPR_T/r-good"; DPR_common r2; DPR_abad="$DPR_abad$DPR_cbad"
DPR_need r2 r2-flock-kind '^flock\.kind: BusyBox applet \(--version said: flock: unrecognized option --version; busybox applet list names flock: yes\)$'
DPR_need r2 r2-flock-lock '^flock\.lock: ok '
DPR_need r2 r2-summary '^V-14 .* flock: .*/s-bb/flock, BusyBox applet, lock ok; tail -c 4 '
DPR_run r3 "$DPR_T/s-none" "$DPR_T/r-none"; DPR_common r3; DPR_abad="$DPR_abad$DPR_cbad"
DPR_need r3 r3-flock-absent '^flock\.path: absent '
DPR_nonl r3 r3-lock-ran '^flock\.lock: '
DPR_need r3 r3-bash-absent '^bash\.path: absent '
DPR_nonl r3 r3-bash-case-ran '^bash\.xdigit_case: '
DPR_need r3 r3-sh-case '^sh\.xdigit_case: ok$'
DPR_need r3 r3-summary '^V-14 .* flock: absent; tail -c 4 .*; /bin/bash: absent; case with \[\[:xdigit:\]\] under bash: not-run, under sh: ok$'
rowif "device probe V-14 readings: util-linux flock, BusyBox flock (applet list), none, each with the lock it takes (or no lock without flock); tail -c 4 prints 6789; /bin/bash present with the case ok, or absent (bad:${DPR_abad:- none})" [ -z "$DPR_abad" ]

# ---- 4 · negative controls of V-14 itself: a tail that refuses -c, a tail that ignores it, a bash that answers wrong, one that cannot run
DPR_abad=""
DPR_run r4 "$DPR_T/s-tailerr" "$DPR_T/r-wrong"; DPR_common r4; DPR_abad="$DPR_abad$DPR_cbad"
DPR_need r4 r4-tail4 "^tail\\.c4: ERROR\\(exit 1: tail: invalid option -- c\\) \\(tail -c 4 of the ten bytes 0123456789 printed ''\\)\$"
DPR_need r4 r4-tail1 '^tail\.c1: ERROR\(exit 1: '
DPR_need r4 r4-tailbig '^tail\.c262144: ERROR\(exit 1: '
DPR_need r4 r4-bash-wrong "^bash\\.xdigit_case: WRONG-OUTPUT\\(got 'match match', want 'match refuse'\\)\$"
DPR_need r4 r4-summary "^V-14 .* printed '' \\(ERROR\\), -c 1 ERROR, -c 262144 ERROR; /bin/bash: present, GNU bash, version 0\\.0\\.0.*under bash: WRONG-OUTPUT, under sh: ok\$"
DPR_nonl r4 r4-says-ok '^tail\.c4: ok'
DPR_run r5 "$DPR_T/s-tailign" "$DPR_T/r-noexec"; DPR_common r5; DPR_abad="$DPR_abad$DPR_cbad"
DPR_need r5 r5-tail4 "^tail\\.c4: WRONG-OUTPUT\\(got '0123456789', want '6789'\\) "
DPR_need r5 r5-tail1 "^tail\\.c1: WRONG-OUTPUT\\(got '0123456789', want '9'\\) "
DPR_need r5 r5-tailbig '^tail\.c262144: ok '
DPR_need r5 r5-bash-noexec '^bash\.path: /bin/bash exists but is not runnable'
DPR_need r5 r5-summary '^V-14 .* \(WRONG-OUTPUT\), -c 1 WRONG-OUTPUT, -c 262144 ok; /bin/bash: exists but is not runnable; case with \[\[:xdigit:\]\] under bash: not-run, under sh: ok$'
DPR_run r7 "$DPR_T/s-lockfail" "$DPR_T/r-good"; DPR_common r7; DPR_abad="$DPR_abad$DPR_cbad"
DPR_need r7 r7-lock-error '^flock\.lock: ERROR\(exit 1: flock: 9: Bad file descriptor\) \(flock -x 9 exited 1 in a subshell on a file of the private directory'
DPR_need r7 r7-tail4 '^tail\.c4: ok '
DPR_need r7 r7-summary "^V-14 .* flock: .*/s-lockfail/flock, util-linux, lock ERROR; tail -c 4 of 0123456789 printed '6789' \\(ok\\), "
DPR_nonl r7 r7-says-ok '^flock\.lock: ok'
rowif "device probe V-14 negative controls: tail refusing -c = ERROR, tail ignoring -c = WRONG-OUTPUT (while -c 262144 still passes), a flock whose lock fails = ERROR (the rest still read), a wrong bash = WRONG-OUTPUT, an unrunnable bash named (bad:${DPR_abad:- none})" [ -z "$DPR_abad" ]

# ---- 5 · V-14 writes nowhere but its private directory: every redirection of the section goes to /dev/null or to a file of the private directory (the tools it names are read by the passivity checker, 5b)
DPR_scan "$DPR_PROBE"
DPR_s1=$DPR_sbad; DPR_s1n=$DPR_sn
rowif "device probe: the V-14 section ($DPR_s1n code lines) redirects only to /dev/null or its private directory (bad:${DPR_s1:- none})" [ -z "$DPR_s1" ]

# ---- 5b · the passivity checker reads the probe (tools/passivity-check.sh, row 7d): --files lists it, its three 'device-probe.sh' rows and every other row are green on it, and a curl, a `hcitool ... scan` and an `iw ... set`
#      planted into the V-14 code turn the rows 'named tools' and 'programs' red, each planted line on its own as evidence. The checker reads the files under its own location, so it runs in a root of its own: a copy of the
#      checker, its lists and the other files it reads, with the probe (as it is, or planted) copied in.
DPR_PC="$DPR_T/pc"; mkdir -p "$DPR_PC/tools"
for DPR_f in starchorus.html starchorus-collect.sh starchorus-display.sh payload.sh starchorus-serve.sh; do cp "$R/$DPR_f" "$DPR_PC/$DPR_f"; done
cp -R "$R/library" "$DPR_PC/library"; cp "$R"/tools/passivity-check.sh "$R"/tools/denylist-check.sh "$R"/tools/denylist*.txt "$DPR_PC/tools/"
DPR_pcrun() {   # DPR_pcrun NAME PROBE -> $DPR_T/NAME.pc = the checker's output on a root whose probe is PROBE; DPR_pcrc = its exit status
  cp "$2" "$DPR_PC/tools/device-probe.sh"
  (cd "$DPR_PC" && sh tools/passivity-check.sh > "$DPR_T/$1.pc" 2>&1 < /dev/null); DPR_pcrc=$?
}
DPR_pcrows() {   # DPR_pcrows NAME -> the rows of the output that begin with 'device-probe.sh' and end in FAIL, one per line
  grep -E '^device-probe\.sh .* FAIL$' "$DPR_T/$1.pc" | cut -d: -f1 | sort -u
}
DPR_pbad5=""
(cd "$R" && sh tools/passivity-check.sh --files) > "$DPR_T/pc-files.txt" 2>&1
grep -qxF "$DPR_P" "$DPR_T/pc-files.txt" || DPR_pbad5="$DPR_pbad5 files-lacks-probe"
DPR_pcrun pc0 "$DPR_PROBE"
[ "$DPR_pcrc" = 0 ] || DPR_pbad5="$DPR_pbad5 unplanted-exit-$DPR_pcrc"
[ "$(grep -cE '^device-probe\.sh .* PASS$' "$DPR_T/pc0.pc")" = 3 ] || DPR_pbad5="$DPR_pbad5 unplanted-rows"
DPR_pbad=""
DPR_plant p-pc '{ print } /^    printf .0123456789. > "\$T\/ae\.tail"$/ { print "    curl http://192.0.2.1/ > /dev/null"; print "    hcitool -i hci0 scan > /dev/null"; print "    iw dev wlan0 set type monitor" }'
case $DPR_pbad in *noplant*) DPR_pbad5="$DPR_pbad5 noplant" ;; esac
DPR_pcrun pc1 "$DPR_T/p-pc.sh"
[ "$DPR_pcrc" = 1 ] || DPR_pbad5="$DPR_pbad5 planted-exit-$DPR_pcrc"
DPR_pcr=$(DPR_pcrows pc1 | tr '\n' ',' | sed 's/,$//')
[ "$DPR_pcr" = "device-probe.sh named tools,device-probe.sh programs" ] || DPR_pbad5="$DPR_pbad5 planted-rows($DPR_pcr)"
for DPR_f in 'curl http://192.0.2.1/' 'hcitool -i hci0 scan' 'iw dev wlan0 set type monitor'; do
  grep -qF "$DPR_f" "$DPR_T/pc1.pc" || DPR_pbad5="$DPR_pbad5 no-evidence($DPR_f)"
done
[ "$(grep -E ' FAIL$' "$DPR_T/pc1.pc" | grep -vc '^device-probe\.sh ')" = 0 ] || DPR_pbad5="$DPR_pbad5 other-rows-red"
rowif "device probe: the passivity checker reads the probe: --files lists it, its three rows pass on it, and a curl, a hcitool scan and an iw set planted into the V-14 code turn 'named tools' and 'programs' red, each line as evidence, no other row (bad:${DPR_pbad5:- none})" [ -z "$DPR_pbad5" ]

# ---- 6 · shellcheck on the probe
DPR_sc=0; shellcheck "$DPR_PROBE" > "$DPR_T/sc.out" 2>&1 && DPR_sc=1
rowif "device probe: shellcheck clean" [ "$DPR_sc" = 1 ]
[ "$DPR_sc" = 1 ] || sed 's/^/    /' "$DPR_T/sc.out" | head -n 12

# ---- 7 · planted copies: each must turn exactly the part it is aimed at red (none of the copies that carry a tool name is ever run)
DPR_pbad=""; DPR_pn=0; DPR_pf=0
DPR_aim() {   # DPR_aim NAME GOT AIMED -> one planted copy judged: counted in DPR_pn; counted in DPR_pf and listed in DPR_pbad unless GOT (what the check said; "" = green) holds AIMED
  DPR_pn=$((DPR_pn + 1)); DPR_ok=1
  case $2 in *"$3"*) ;; *) DPR_ok=0; DPR_pbad="$DPR_pbad $1:${2:-green}" ;; esac
  case " $DPR_pbad " in *" noplant:$1 "*) DPR_ok=0 ;; esac   # a copy that equals the probe aims at nothing
  [ "$DPR_ok" = 1 ] || DPR_pf=$((DPR_pf + 1))
}
DPR_plant p-h14 '/^#   V-14 alert-companion-environment/ { next } { print }'
DPR_check "$DPR_T/p-h14.sh"; DPR_aim p-h14 "$DPR_bad" header:14
DPR_plant p-v14 '/^        14\) echo alert-companion-environment ;;$/ { next } { print }'
DPR_check "$DPR_T/p-v14.sh"; DPR_aim p-v14 "$DPR_bad" vname:14
DPR_plant p-q14 '/^        14\) echo "Has the device a flock/ { next } { print }'
DPR_check "$DPR_T/p-q14.sh"; DPR_aim p-q14 "$DPR_bad" question:14
DPR_plant p-nv '/^NV=14/ { sub(/NV=14/, "NV=13") } { print }'
DPR_check "$DPR_T/p-nv.sh"; DPR_aim p-nv "$DPR_bad" bound
DPR_plant p-call '/^    sect_alertenv$/ { next } { print }'
DPR_check "$DPR_T/p-call.sh"; DPR_aim p-call "$DPR_bad" call:sect_alertenv
DPR_run pc "$DPR_T/s-ul" "$DPR_T/r-good" "$DPR_T/p-call.sh"; DPR_common pc; DPR_aim p-call-run "$DPR_cbad" v14-not-observed
DPR_plant p-call-oui '/^    sect_oui$/ { next } { print }'
DPR_check "$DPR_T/p-call-oui.sh"; DPR_aim p-call-oui "$DPR_bad" call:sect_oui
DPR_plant p-call-first '/^    sect_jq$/ { next } { print }'
DPR_check "$DPR_T/p-call-first.sh"; DPR_aim p-call-first "$DPR_bad" call:sect_jq
DPR_plant p-nolist '/^if \[ "\$\{1:-\}" = --list \]; then$/ { skip = 1 } skip { if ($0 == "fi") skip = 0; next } { print }'
DPR_check "$DPR_T/p-nolist.sh"; DPR_aim p-nolist "$DPR_bad" list
DPR_plant p-write '{ print } /^    printf .0123456789. > "\$T\/ae\.tail"$/ { print "    printf x > /root/leak" }'
DPR_scan "$DPR_T/p-write.sh"; DPR_aim p-write "$DPR_sbad" redirect
DPR_plant p-sc '{ print } /^    printf .0123456789. > "\$T\/ae\.tail"$/ { print "    echo $T" }'
DPR_scr=""; shellcheck "$DPR_T/p-sc.sh" > /dev/null 2>&1 || DPR_scr=red; DPR_aim p-sc "$DPR_scr" red
# the lock dropped (the call out, nothing else changed): the readings of row 3 then find no flock.lock line
DPR_plant p-nolock '/^        ae_lock$/ { print "        AE_LK=none"; next } { print }'
DPR_run pn "$DPR_T/s-ul" "$DPR_T/r-good" "$DPR_T/p-nolock.sh"; DPR_abad=""
DPR_need pn pn-lock '^flock\.lock: ok '
DPR_aim p-nolock "$DPR_abad" pn-lock
# a lock check that always says ok: the run with a flock whose lock fails must then no longer find the ERROR
DPR_plant p-lockok '/^    if \[ "\$_lc" = 0 \]; then AE_LK=ok$/ { sub(/\[ "\$_lc" = 0 \]/, ":") } { print }'
DPR_run pk "$DPR_T/s-lockfail" "$DPR_T/r-good" "$DPR_T/p-lockok.sh"; DPR_abad=""
DPR_need pk pk-lock-error '^flock\.lock: ERROR\(exit 1: '
DPR_aim p-lockok "$DPR_abad" pk-lock-error
# the lock taken in the main shell (exec 9>, never let go): the form of the companion's line is gone
DPR_plant p-lockexec '/^    \( flock -x 9; printf/ { print "    exec 9> \"$T/ae.lock\"; flock -x 9 2> \"$T/ae.lockerr\"; printf \"%s\" \"$?\" > \"$T/ae.lockrc\"; _lr=0"; next } { print }'
DPR_lockform "$DPR_T/p-lockexec.sh" "$R/$DPR_COMPANION"; DPR_aim p-lockexec "$DPR_lf" form
# a tail check that always says ok: the run with a tail that ignores -c must then no longer find WRONG-OUTPUT
DPR_plant p-tailok '/^    elif \[ "\$AE_OUT" = "\$_aw" \]; then AE_ST=ok$/ { sub(/\[ "\$AE_OUT" = "\$_aw" \]/, ":") } { print }'
DPR_run pt "$DPR_T/s-tailign" "$DPR_T/r-noexec" "$DPR_T/p-tailok.sh"; DPR_abad=""
DPR_need pt pt-tail4 "^tail\\.c4: WRONG-OUTPUT\\(got '0123456789', want '6789'\\) "
DPR_aim p-tailok "$DPR_abad" pt-tail4
# the copy without the empty BASH_ENV and ENV in front of the two literal shells, run with a BASH_ENV file in its environment: the bash of V-14 must source it (the control of row 8)
printf 'printf x > "%s/benv.mark"\n' "$DPR_T" > "$DPR_T/benv.sh"; rm -f "$DPR_T/benv.mark"
DPR_plant p-env '{ sub(/BASH_ENV=[^ ]* ENV=[^ ]* /, "") } { print }'
DPR_run pe "$DPR_T/s-ul" "$DPR_T/r-good" "$DPR_T/p-env.sh" "$DPR_T/benv.sh"
DPR_mk=""; [ ! -e "$DPR_T/benv.mark" ] || DPR_mk=sourced; DPR_aim p-env "$DPR_mk" sourced
DPR_pk=$((DPR_pn - DPR_pf))
rowif "device probe: planted copies go red ($DPR_pk/$DPR_pn): V-14 out of the header contract, of vname, of the questions; NV 13; the call of the last, of a middle and of the first section out (the last also in a run); the --list handler out; a write to /root in the V-14 code; the lock call dropped, a lock check that always says ok (a failing flock then reads ok), the lock taken with exec 9> in the main shell; an unquoted variable; a tail check that always passes; the shells without the empty BASH_ENV and ENV in front of them (they source a BASH_ENV file) (bad:${DPR_pbad:- none})" [ -z "$DPR_pbad" ]

# ---- 8 · the two literal shells source no file of the device: the probe run with a BASH_ENV file in its environment leaves the file unread (the control is the copy of row 7 that does read it)
rm -f "$DPR_T/benv.mark"
DPR_run r6 "$DPR_T/s-ul" "$DPR_T/r-good" "" "$DPR_T/benv.sh"; DPR_common r6; DPR_ebad=$DPR_cbad
[ ! -e "$DPR_T/benv.mark" ] || DPR_ebad="$DPR_ebad sourced"
DPR_abad=""
DPR_need r6 r6-bash-case '^bash\.xdigit_case: ok$'
DPR_need r6 r6-sh-case '^sh\.xdigit_case: ok$'
DPR_ebad="$DPR_ebad$DPR_abad"
rowif "device probe: the literal shells run with BASH_ENV and ENV empty: a BASH_ENV file in the probe's environment is not sourced, V-14 still reads ok (bad:${DPR_ebad:- none})" [ -z "$DPR_ebad" ]
rm -rf "${DPR_T:?}"
fi
