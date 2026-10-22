# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/device-probe.sh -- the device probe (tools/device-probe.sh) on this machine, without a device.
# GUARDS AGAINST: a probe whose list of open verifications has drifted: a V-number that the header contract does not name (with the slug vname
#                 prints), that has no vname entry, no vset, no one-line question, a summary loop that stops short of the last one, a section that is
#                 not called; a `--list` that fails, prints another number of lines than there are verifications, or writes anything; a guard that no
#                 longer refuses on this machine; V-14 (flock, tail -c, /bin/bash with [[:xdigit:]] in a case) that reports "ok" for a tail that
#                 refuses -c or ignores it, for a bash whose case gives another answer, or that fails on a machine without flock or without bash; a run
#                 that is not silent, leaves its temp directory behind, or whose summary lacks V-14; a V-14 section that names a sending, scanning,
#                 changing or network tool (the passivity checker's own families plus a list of network and change tools) or redirects anywhere but
#                 /dev/null and its private directory; a probe that shellcheck dislikes.
# NEGATIVE PROBE: planted copies of the probe, each of which must make one named part red: the V-14 line out of the header contract (header:14), vname 14
#                 out (vname:14), the question of V-14 out (question:14), NV=13 (bound), the call of the section out (call, and in a run "V-14 not
#                 observed"), the --list handler out (list), a `curl`, a `hcitool ... scan` and a write to /root/ planted into the V-14 code (scan), an
#                 unquoted variable (shellcheck), and a tail check that always says ok (the run with a tail that ignores -c no longer finds WRONG-OUTPUT).
#                 The stand-in runs are negative controls of V-14 itself: a tail that refuses -c, a tail that ignores it, a bash that gives the wrong
#                 answer, a bash that is not executable, no bash, no flock.
# NOT PROVEN:     anything on the device: BusyBox's ash, its flock and tail, whether /bin/bash exists there (the stand-ins are what such tools are assumed
#                 to print), and how the firmware starts an alert payload (docs/device-notes.md 5c). The passivity checker does NOT read this probe:
#                 tools/passivity-check.sh covers the collector, the Overview copies, both payload.sh and library/ (`--files`), and tools/* is exempt
#                 as a whole (tools/regress.d/doc-truth.sh says so), although this one file runs on the device. The only static guard of the probe's text
#                 is the V-14 scan below (the V-14 section only, not the other nine); the checker's own row in static.sh stays green on its own scope.
# Sourced by tools/regress.sh (T2) and tools/quick.sh (T1) with cwd = repo root; Chrome-free, no network, no device. About three seconds: seven
# runs of the probe in forced mode (STARCHORUS_PROBE_FORCE=1, an empty root, GAP 1, no self-test), 0.3 s each. Sets only DPR_* names.
# The runs use a PATH of symlinks to every tool of the real PATH except flock, busybox and bash, with a directory of stand-ins in front, and a
# root directory of their own for /bin/bash; the probe reads the machine's other files as it would on the device (read only), and writes nowhere
# but the temp directory of the run.

# shellcheck disable=SC2016   # the single quotes below hold program text and patterns for awk, grep and the shells under test: the $ are meant literally
DPR_P=tools/device-probe.sh
DPR_SH=$(command -v sh)
DPR_MINLINES=50          # code lines of the V-14 section the scan reads; measure: DPR_region tools/device-probe.sh | wc -l   (measured: 64)
DPR_NET='curl|wget|nc|ncat|netcat|socat|ping6?|ssh|scp|sftp|telnet|ftp|tftp|uci|opkg|ifconfig|ip|iw|iwinfo|sqlite3|tcpdump|wifi|service|reload_config|kill|pkill|reboot|poweroff|halt|mount|umount|rm|mv|cp|dd|tee|chmod|chown|ln|mkdir|touch|nice|setsid|env|eval|xargs'

# the leading comment block of a probe text = its header contract; the code = every other line, a trailing comment cut off
DPR_head() { awk '/^[^#]/ && NF { exit } { print }' "$1"; }
DPR_code() { grep -v '^[[:space:]]*#' "$1" | sed 's/[[:space:]][[:space:]]*#[[:space:]].*$//'; }
# the code of section 10 (V-14) alone
DPR_region() { awk '/^# =+ 10\. /{ f = 1; next } /^# =+ summary/{ f = 0 } f' "$1" | grep -v '^[[:space:]]*#' | sed 's/[[:space:]][[:space:]]*#[[:space:]].*$//'; }
DPR_slug() { sed -n "s/^ *$2) echo \([a-z0-9-][a-z0-9-]*\) ;;\$/\1/p" "$1" | head -n 1; }   # DPR_slug FILE N -> the name vname gives V-N
DPR_rx() { sh tools/passivity-check.sh --regexes | awk -F'\t' -v n="$1" '$1 == n { print $2; exit }'; }   # one regex family of the passivity checker

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
  printf '%s\n' "$DPR_c" | grep -q '^    sect_alertenv$' || DPR_bad="$DPR_bad call"
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

DPR_scan() {   # DPR_scan FILE -> DPR_sbad = deny | redirect | empty; DPR_sn = code lines of section 10 read
  DPR_sbad=""; DPR_rg=$(DPR_region "$1"); DPR_sn=$(printf '%s\n' "$DPR_rg" | grep -c .)
  DPR_tx=$(DPR_rx TX_WORDS); DPR_bt=$(DPR_rx BT_WORDS); DPR_s6=$(DPR_rx SEC6_RE); DPR_iwv=$(DPR_rx IW_VERBS)
  { [ -n "$DPR_tx" ] && [ -n "$DPR_bt" ] && [ -n "$DPR_s6" ] && [ -n "$DPR_iwv" ] && ge "$DPR_sn" "$DPR_MINLINES"; } || DPR_sbad="$DPR_sbad empty(lines=$DPR_sn,families:${DPR_tx:+tx }${DPR_bt:+bt }${DPR_s6:+sec6 }${DPR_iwv:+iw})"
  DPR_dh=$(printf '%s\n' "$DPR_rg" | grep -E "(^|[^A-Za-z0-9_-])($DPR_tx|$DPR_bt|$DPR_NET)([^A-Za-z0-9_]|\$)|($DPR_s6)|(^|[^A-Za-z_])iw[[:space:]].*[[:space:]]($DPR_iwv)([^A-Za-z_]|\$)")
  [ -z "$DPR_dh" ] || DPR_sbad="$DPR_sbad deny($(printf '%s\n' "$DPR_dh" | head -n 1 | cut -c1-50))"
  # every redirection of the section goes to /dev/null or to a file of the private directory ($T/ae.NAME)
  DPR_rd=$(printf '%s\n' "$DPR_rg" | grep -oE '[0-9]*>>?[[:space:]]*[^[:space:];|&)]+' | sed -E 's/^[0-9]*>>?[[:space:]]*//' | grep -vE '^(/dev/null|"\$T/ae\.[a-z]+")$')
  [ -z "$DPR_rd" ] || DPR_sbad="$DPR_sbad redirect($(printf '%s\n' "$DPR_rd" | head -n 1 | cut -c1-40))"
}

# one forced run of a probe text on this machine: DPR_run NAME STANDIN_DIR ROOT [PROBE] -> $DPR_T/NAME.out, NAME.err, the run's TMPDIR NAME.tmp, DPR_rc
DPR_run() {
  rm -rf "${DPR_T:?}/$1.tmp"; mkdir "$DPR_T/$1.tmp"
  PATH="$2:$DPR_FARM" TMPDIR="$DPR_T/$1.tmp" STARCHORUS_PROBE_FORCE=1 STARCHORUS_PROBE_ROOT="$3" STARCHORUS_PROBE_GAP=1 STARCHORUS_PROBE_SKIP_SELFTEST=1 \
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
mkdir "$DPR_T/s-none" "$DPR_T/s-ul" "$DPR_T/s-bb" "$DPR_T/s-tailerr" "$DPR_T/s-tailign"
printf '#!/bin/sh\necho "flock from util-linux 2.99 (stand-in)"\n' > "$DPR_T/s-ul/flock"; chmod +x "$DPR_T/s-ul/flock"
printf '#!/bin/sh\ncase ${0##*/} in flock) echo "flock: unrecognized option --version" >&2; echo "Usage: flock [-sxun] FILE PROG" >&2; exit 1 ;; esac\ncase ${1:-} in --list) echo ls; echo flock ;; *) echo "BusyBox v1.36.1 (stand-in) multi-call binary." ;; esac\n' > "$DPR_T/s-bb/busybox"
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

# ---- 2 · a forced run on this machine with a real bash, a util-linux-looking flock and the real tail: section 10 and the summary
DPR_run r1 "$DPR_T/s-ul" "$DPR_T/r-good"; DPR_common r1; DPR_c1=$DPR_cbad
rowif "device probe: forced run (empty root, GAP 1, no self-test): exit 0, silent, section 10, V-1 to V-14 in order, V-14 OBSERVED, temp dir removed (bad:${DPR_c1:- none})" [ -z "$DPR_c1" ] && [ -n "$DPR_BASH" ]

# ---- 3 · the readings of V-14: util-linux flock, BusyBox flock, no flock and no bash; tail -c 4 gives the last four bytes
DPR_abad=""
DPR_need r1 r1-flock-path "^flock\\.path: $DPR_T/s-ul/flock\$"
DPR_need r1 r1-flock-kind '^flock\.kind: util-linux \(--version said: flock from util-linux 2\.99'
DPR_need r1 r1-tail4 "^tail\\.c4: ok \\(tail -c 4 of the ten bytes 0123456789 printed '6789'\\)\$"
DPR_need r1 r1-tail1 '^tail\.c1: ok '
DPR_need r1 r1-tailbig '^tail\.c262144: ok '
DPR_need r1 r1-bash-path '^bash\.path: /bin/bash present'
DPR_need r1 r1-bash-case '^bash\.xdigit_case: ok$'
DPR_need r1 r1-sh-case '^sh\.xdigit_case: ok$'
DPR_need r1 r1-summary "^V-14 alert-companion-environment: OBSERVED flock: $DPR_T/s-ul/flock, util-linux; tail -c 4 of 0123456789 printed '6789' \\(ok\\), -c 1 ok, -c 262144 ok; /bin/bash: present, .*case with \\[\\[:xdigit:\\]\\] under bash: ok, under sh: ok\$"
DPR_run r2 "$DPR_T/s-bb" "$DPR_T/r-good"; DPR_common r2; DPR_abad="$DPR_abad$DPR_cbad"
DPR_need r2 r2-flock-kind '^flock\.kind: BusyBox applet \(--version said: flock: unrecognized option --version; busybox applet list names flock: yes\)$'
DPR_need r2 r2-summary '^V-14 .* flock: .*/s-bb/flock, BusyBox applet; tail -c 4 '
DPR_run r3 "$DPR_T/s-none" "$DPR_T/r-none"; DPR_common r3; DPR_abad="$DPR_abad$DPR_cbad"
DPR_need r3 r3-flock-absent '^flock\.path: absent '
DPR_need r3 r3-bash-absent '^bash\.path: absent '
DPR_nonl r3 r3-bash-case-ran '^bash\.xdigit_case: '
DPR_need r3 r3-sh-case '^sh\.xdigit_case: ok$'
DPR_need r3 r3-summary '^V-14 .* flock: absent; tail -c 4 .*; /bin/bash: absent; case with \[\[:xdigit:\]\] under bash: not-run, under sh: ok$'
rowif "device probe V-14 readings: util-linux flock, BusyBox flock (applet list), none; tail -c 4 prints 6789; /bin/bash present with the case ok, or absent (bad:${DPR_abad:- none})" [ -z "$DPR_abad" ]

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
rowif "device probe V-14 negative controls: tail refusing -c = ERROR, tail ignoring -c = WRONG-OUTPUT (while -c 262144 still passes), a wrong bash = WRONG-OUTPUT, an unrunnable bash named (bad:${DPR_abad:- none})" [ -z "$DPR_abad" ]

# ---- 5 · V-14 sends nothing: the section's code against the checker's own families (read with --regexes) and a list of network and change tools; redirections
DPR_scan "$DPR_PROBE"
DPR_s1=$DPR_sbad; DPR_s1n=$DPR_sn
rowif "device probe: the V-14 section ($DPR_s1n code lines) names no sending, scanning, Bluetooth, network or change tool and redirects only to /dev/null or its private directory (bad:${DPR_s1:- none})" [ -z "$DPR_s1" ]

# ---- 6 · shellcheck on the probe
DPR_sc=0; shellcheck "$DPR_PROBE" > "$DPR_T/sc.out" 2>&1 && DPR_sc=1
rowif "device probe: shellcheck clean" [ "$DPR_sc" = 1 ]
[ "$DPR_sc" = 1 ] || sed 's/^/    /' "$DPR_T/sc.out" | head -n 12

# ---- 7 · planted copies: each must turn exactly the part it is aimed at red (none of the copies that carry a tool name is ever run)
DPR_pbad=""; DPR_pn=0
DPR_plant p-h14 '/^#   V-14 alert-companion-environment/ { next } { print }'
DPR_check "$DPR_T/p-h14.sh"; DPR_pn=$((DPR_pn + 1)); case $DPR_bad in *header:14*) ;; *) DPR_pbad="$DPR_pbad p-h14:${DPR_bad:-green}" ;; esac
DPR_plant p-v14 '/^        14\) echo alert-companion-environment ;;$/ { next } { print }'
DPR_check "$DPR_T/p-v14.sh"; DPR_pn=$((DPR_pn + 1)); case $DPR_bad in *vname:14*) ;; *) DPR_pbad="$DPR_pbad p-v14:${DPR_bad:-green}" ;; esac
DPR_plant p-q14 '/^        14\) echo "Has the device a flock/ { next } { print }'
DPR_check "$DPR_T/p-q14.sh"; DPR_pn=$((DPR_pn + 1)); case $DPR_bad in *question:14*) ;; *) DPR_pbad="$DPR_pbad p-q14:${DPR_bad:-green}" ;; esac
DPR_plant p-nv '/^NV=14/ { sub(/NV=14/, "NV=13") } { print }'
DPR_check "$DPR_T/p-nv.sh"; DPR_pn=$((DPR_pn + 1)); case $DPR_bad in *bound*) ;; *) DPR_pbad="$DPR_pbad p-nv:${DPR_bad:-green}" ;; esac
DPR_plant p-call '/^    sect_alertenv$/ { next } { print }'
DPR_check "$DPR_T/p-call.sh"; DPR_pn=$((DPR_pn + 1)); case $DPR_bad in *call*) ;; *) DPR_pbad="$DPR_pbad p-call:${DPR_bad:-green}" ;; esac
DPR_run pc "$DPR_T/s-ul" "$DPR_T/r-good" "$DPR_T/p-call.sh"; DPR_common pc; DPR_pn=$((DPR_pn + 1)); case $DPR_cbad in *v14-not-observed*) ;; *) DPR_pbad="$DPR_pbad p-call-run:${DPR_cbad:-green}" ;; esac
DPR_plant p-nolist '/^if \[ "\$\{1:-\}" = --list \]; then$/ { skip = 1 } skip { if ($0 == "fi") skip = 0; next } { print }'
DPR_check "$DPR_T/p-nolist.sh"; DPR_pn=$((DPR_pn + 1)); case $DPR_bad in *list*) ;; *) DPR_pbad="$DPR_pbad p-nolist:${DPR_bad:-green}" ;; esac
DPR_plant p-curl '{ print } /^    printf .0123456789. > "\$T\/ae\.tail"$/ { print "    curl http://127.0.0.1/ > /dev/null" }'
DPR_scan "$DPR_T/p-curl.sh"; DPR_pn=$((DPR_pn + 1)); case $DPR_sbad in *deny*) ;; *) DPR_pbad="$DPR_pbad p-curl:${DPR_sbad:-green}" ;; esac
DPR_plant p-scan '{ print } /^    printf .0123456789. > "\$T\/ae\.tail"$/ { print "    hcitool -i hci0 scan > /dev/null" }'
DPR_scan "$DPR_T/p-scan.sh"; DPR_pn=$((DPR_pn + 1)); case $DPR_sbad in *deny*) ;; *) DPR_pbad="$DPR_pbad p-scan:${DPR_sbad:-green}" ;; esac
DPR_plant p-write '{ print } /^    printf .0123456789. > "\$T\/ae\.tail"$/ { print "    printf x > /root/leak" }'
DPR_scan "$DPR_T/p-write.sh"; DPR_pn=$((DPR_pn + 1)); case $DPR_sbad in *redirect*) ;; *) DPR_pbad="$DPR_pbad p-write:${DPR_sbad:-green}" ;; esac
DPR_plant p-sc '{ print } /^    printf .0123456789. > "\$T\/ae\.tail"$/ { print "    echo $T" }'
DPR_sc=0; shellcheck "$DPR_T/p-sc.sh" > /dev/null 2>&1 && DPR_sc=1; DPR_pn=$((DPR_pn + 1)); [ "$DPR_sc" = 0 ] || DPR_pbad="$DPR_pbad p-sc:green"
# a tail check that always says ok: the run with a tail that ignores -c must then no longer find WRONG-OUTPUT
DPR_plant p-tailok '/^    elif \[ "\$AE_OUT" = "\$_aw" \]; then AE_ST=ok$/ { sub(/\[ "\$AE_OUT" = "\$_aw" \]/, ":") } { print }'
DPR_run pt "$DPR_T/s-tailign" "$DPR_T/r-noexec" "$DPR_T/p-tailok.sh"; DPR_abad=""
DPR_need pt pt-tail4 "^tail\\.c4: WRONG-OUTPUT\\(got '0123456789', want '6789'\\) "
DPR_pn=$((DPR_pn + 1)); [ -n "$DPR_abad" ] || DPR_pbad="$DPR_pbad p-tailok:green"
DPR_pk=$((DPR_pn - $(printf '%s\n' "$DPR_pbad" | wc -w)))
rowif "device probe: planted copies go red ($DPR_pk/$DPR_pn): V-14 out of the header contract, of vname, of the questions; NV 13; the section call out (also in a run); the --list handler out; curl, hcitool scan and a write to /root in the V-14 code; an unquoted variable; a tail check that always passes (bad:${DPR_pbad:- none})" [ -z "$DPR_pbad" ]
rm -rf "${DPR_T:?}"
fi
