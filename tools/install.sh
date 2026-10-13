#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/install.sh -- installs Starchorus onto the device FROM THE FILES OF THIS REPO and
# verifies the result. Dev machine only (POSIX sh; needs ssh, scp, cksum, cmp). Nothing here runs on the device.
#
# usage: sh tools/install.sh [--host HOST] [--dry-run]        (any cwd, any path -- also one with spaces)
#        sh tools/install.sh --help
#   host: --host, else the environment variable STARCHORUS_HOST, else the built-in default (DEFAULT_HOST below).
#
# It only copies files over ssh/scp and runs the collector's and dashboard's own passive checks on the device.
# It transmits NOTHING over the air and adds no active function (SECURITY.md); the only network use is that
# human-started ssh/scp session.
#   1. finds the repo from its own path; exit 2 if a source file is missing or the two starchorus-display.sh copies
#      (repo root / library/.../starchorus) differ -- the payload directory must ship the same dashboard;
#   2. prints "file -> version" (page: version: "x.y.z"; collector/display/payload: "# Version:" header) BEFORE
#      it touches the device, and the same real versions at the end;
#   3. opens ONE ssh master connection (one password prompt), uploads with scp -O (legacy protocol: the device
#      has no sftp-server), chmod +x, then compares cksum (CRC + size) of every file, local vs device (cksum
#      is not yet measured on the device: see "NOT YET MEASURED" below);
#   4. runs the collector's and the dashboard's own --selftest, one passive collector --once, and a dashboard
#      smoke test: "--once summary" must show a digit after "2.4:", "5:" and "6:" (blank counters are the
#      symptom of jq filters aborting on the device, e.g. regex builtins: docs/device-notes.md 2a) and must not
#      say "jq incomplete".
# Remote commands (nothing else is ever sent): mkdir -p, chmod, cksum, "sh <installed script> --selftest",
# "cd <dir> && ... ./starchorus-collect.sh --once", head of starchorus.json, "sh <installed display script> --once summary".
# No package manager, no config, no service control, no AP-service calls.
# NOT YET MEASURED ON THE DEVICE (open device verifications, docs/device-notes.md): the BusyBox applet "cksum"
# and the option "head -c". So a cksum that gives no usable output (or values that disagree) is never read as
# "the upload is damaged": the bytes decide. Each affected file is copied back with scp (still only a file
# transfer) into the private temp directory and compared with cmp; only a byte difference is reported as a
# damaged upload. If a file can be neither checked by cksum nor read back, the run FAILS with "integrity NOT
# verified" (a different message) and still runs the other checks. The closing lines say which way the
# integrity was established and what cksum / head -c did on the device, so the result can be recorded.
# Privacy (P9): only versions, counts and checksums are printed. The content of starchorus.json (MAC/SSID values of
# third parties) is never echoed, so the output is safe to paste into an issue or a PR.
# Exit: 0 = installed and every check passed (warnings possible), 1 = a check failed or the device could not
# be reached, 2 = usage / setup problem (unknown option, missing source file, differing display-script copies).
set -u

LOOT=/root/loot/starchorus
PLDIR=/root/payloads/user/reconnaissance/starchorus
PLSRC=library/user/reconnaissance/starchorus      # in the repo; NOT the root-level payload.sh (generic wrapper)
DEFAULT_HOST=172.16.52.1

# repo file | target on the device | x = chmod +x. The page becomes index.html; the display-script copy for the payload
# directory is the one under $PLSRC, so the cmp below decides whether both places get identical bytes.
FILES="starchorus-collect.sh|$LOOT/starchorus-collect.sh|x
starchorus.html|$LOOT/index.html|-
starchorus-display.sh|$LOOT/starchorus-display.sh|x
starchorus-serve.sh|$LOOT/starchorus-serve.sh|x
$PLSRC/payload.sh|$PLDIR/payload.sh|x
$PLSRC/starchorus-display.sh|$PLDIR/starchorus-display.sh|x"

die() { _c=$1; shift; printf 'install: %s\n' "$*" >&2; exit "$_c"; }
say() { printf '%s\n' "$*"; }
usage() {
  cat <<'EOF'
usage: sh tools/install.sh [--host HOST] [--dry-run]
       sh tools/install.sh --help

Installs Starchorus onto the device from the files of this repo, verifies the upload by
checksum (cksum; not yet measured on the device -- if it gives no usable output the files are read back with
scp and compared byte for byte) and runs the collector's and dashboard's own passive checks on the device.
It only copies files over ssh/scp; it transmits nothing over the air.

  --host HOST    Device address (default: environment variable STARCHORUS_HOST, else the built-in default address)
  -n, --dry-run  print the file table with versions and the exact ssh/scp commands; connect to nothing
  -h, --help     this text

Exit: 0 = installed and verified, 1 = a check failed, 2 = usage/setup problem (unknown option, missing
source file, the two starchorus-display.sh copies differ).
EOF
}

# ---------------------------------------------------------------- options (strict: anything else exits 2)
HOST=${STARCHORUS_HOST:-$DEFAULT_HOST}
DRY=0
while [ $# -gt 0 ]; do
  case $1 in
    --host)     [ $# -ge 2 ] || die 2 "--host needs a value (see --help)"; HOST=$2; shift 2 ;;
    --host=*)   HOST=${1#--host=}; shift ;;
    -n|--dry-run) DRY=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    -*)         die 2 "unknown option: $1 (see --help)" ;;
    *)          die 2 "unexpected argument: $1 (see --help)" ;;
  esac
done
# the host lands in ssh/scp words: letters, digits, dot, dash, underscore only (no user@, no option lookalike)
case $HOST in
  ''|-*|.*|*[!A-Za-z0-9._-]*) die 2 "invalid host '$HOST' (letters, digits, . - _ only; e.g. $DEFAULT_HOST)" ;;
esac

# ---------------------------------------------------------------- repo root, source files, versions
HERE=$(cd "$(dirname -- "$0")" && pwd -P) || die 2 "cannot resolve the script directory"
ROOT=$(cd "$HERE/.." && pwd -P) || die 2 "cannot resolve the repo root"

missing=0
while IFS='|' read -r rel _dest _x; do
  if [ ! -f "$ROOT/$rel" ]; then printf 'install: source file missing: %s\n' "$rel" >&2; missing=$((missing + 1)); fi
done <<EOF
$FILES
EOF
[ "$missing" = 0 ] || die 2 "$missing source file(s) missing under $ROOT -- run it from a complete checkout of the repo"
cmp -s "$ROOT/starchorus-display.sh" "$ROOT/$PLSRC/starchorus-display.sh" ||
  die 2 "starchorus-display.sh differs between the repo root and $PLSRC/ -- the two copies must be identical; nothing was installed"

page_ver() { sed -n 's/^[[:space:]]*version:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' "$1" | head -n 1; }
hdr_ver()  { sed -n 's/^#[[:space:]]*Version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$1" | head -n 1; }
ver_of() {   # ver_of REPO-RELATIVE-FILE -> its version, or "-" when the file carries none
  case $1 in *.html) _v=$(page_ver "$ROOT/$1") ;; *) _v=$(hdr_ver "$ROOT/$1") ;; esac
  printf '%s' "${_v:--}"
}
VER_PAGE=$(ver_of starchorus.html); VER_COLLECT=$(ver_of starchorus-collect.sh)
VER_DASH=$(ver_of starchorus-display.sh);   VER_PAYLOAD=$(ver_of "$PLSRC/payload.sh")
for _pair in "starchorus.html:$VER_PAGE" "starchorus-collect.sh:$VER_COLLECT" "starchorus-display.sh:$VER_DASH"; do
  [ "${_pair#*:}" != - ] || die 2 "cannot read the version of ${_pair%%:*} -- is this a complete checkout of the repo?"
done
# The test capture uses the installed payload's own window, read from its default (STARCHORUS_MAX_AGE:-N), not a copy typed
# here: a typed copy would go stale the moment the payload default changes (the payload reads a 1 h window, U3).
# shellcheck disable=SC2016  # the literal ${STARCHORUS_MAX_AGE:- of the payload text is matched, nothing is meant to expand
MAX_AGE=$(sed -n 's/^export STARCHORUS_MAX_AGE="\${STARCHORUS_MAX_AGE:-\([0-9][0-9]*\)}".*/\1/p' "$ROOT/$PLSRC/payload.sh" | head -n 1)
[ -n "$MAX_AGE" ] || die 2 "cannot read the STARCHORUS_MAX_AGE default of $PLSRC/payload.sh -- nothing was installed"

ALLDEST=""; XDEST=""; NFILES=0
while IFS='|' read -r _rel dest x; do
  ALLDEST="$ALLDEST $dest"; NFILES=$((NFILES + 1)); [ "$x" = x ] && XDEST="$XDEST $dest"
done <<EOF
$FILES
EOF
ALLDEST=${ALLDEST# }; XDEST=${XDEST# }

# ---------------------------------------------------------------- what would be / is run (one source of truth)
shq() {   # shell-quote one word, for DISPLAY only (the real calls pass the words as separate arguments)
  case $1 in
    ''|*[!A-Za-z0-9._/:=@%+,-]*) printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")" ;;
    *) printf '%s' "$1" ;;
  esac
}
# ONE master connection (one password prompt); every later ssh/scp reuses it. accept-new as in the ad-hoc
# installer; nothing else is relaxed. The value of ControlPath never contains a blank (checked below), so the
# option string can be split into words on purpose.
mk_opts() { SSH_OPTS="-o ControlMaster=auto -o ControlPath=$1 -o ControlPersist=300 -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15"; }
CMD_MKDIR="mkdir -p $LOOT $PLDIR"
CMD_CHMOD="chmod +x $XDEST"
CMD_CKSUM="cksum $ALLDEST"
CMD_CSELF="sh $LOOT/starchorus-collect.sh --selftest"
CMD_PSELF="sh $LOOT/starchorus-display.sh --selftest"
CMD_ONCE="cd $LOOT && STARCHORUS_OUTDIR=$LOOT STARCHORUS_MAX_AGE=$MAX_AGE ./starchorus-collect.sh --once"
CMD_HEAD="head -c 400 $LOOT/starchorus.json"
# STARCHORUS_DISPLAY_PLAIN=1: text on stdout even if the ssh session happens to see the device's LOG command
CMD_SMOKE="STARCHORUS_JSON=$LOOT/starchorus.json STARCHORUS_DISPLAY_PLAIN=1 sh $LOOT/starchorus-display.sh --once summary"
# Manual control, printed as hints only (never run here). The payload's loop keeps its pidfile in STARCHORUS_OUTDIR=$LOOT;
# without it --status would look in the collector's default output directory and report "not running" while the loop runs.
CMD_STATUS="cd $LOOT && STARCHORUS_OUTDIR=$LOOT ./starchorus-collect.sh --status"
CMD_STOP="cd $LOOT && STARCHORUS_OUTDIR=$LOOT ./starchorus-collect.sh --stop"

print_table() {
  printf '  %-56s %-8s %s\n' "file (repo)" "version" "-> target on the device"
  while IFS='|' read -r rel dest _x; do
    printf '  %-56s %-8s -> %s\n' "$rel" "$(ver_of "$rel")" "$dest"
  done <<EOF
$FILES
EOF
}

say "Starchorus installer  ->  root@$HOST"
say "Files from the repo (page $VER_PAGE, collector $VER_COLLECT, display $VER_DASH):"
print_table

if [ "$DRY" = 1 ]; then
  mk_opts '<tmpdir>/cm'
  say ""
  say "DRY RUN: nothing is connected, nothing is copied. A real run executes, in this order"
  say "(<tmpdir> is a private temp directory that a real run creates and removes):"
  n=1
  plan() { printf '%3d. %s\n' "$n" "$1"; n=$((n + 1)); }
  plan "ssh $SSH_OPTS root@$HOST $(shq "$CMD_MKDIR")"
  while IFS='|' read -r rel dest _x; do
    plan "scp -O $SSH_OPTS $(shq "$ROOT/$rel") root@$HOST:$dest"
  done <<EOF
$FILES
EOF
  plan "ssh $SSH_OPTS root@$HOST $(shq "$CMD_CHMOD")"
  plan "ssh $SSH_OPTS root@$HOST $(shq "$CMD_CKSUM")    # then CRC + size compared with the local files"
  say "     cksum is not yet measured on the device. Only for a file whose cksum is missing or differs, a real run"
  say "     also reads it back (file copy, then cmp with the repo file; <n> = 1..$NFILES):"
  while IFS='|' read -r _rel dest _x; do
    say "       scp -O $SSH_OPTS root@$HOST:$dest <tmpdir>/back/<n>"
  done <<EOF
$FILES
EOF
  plan "ssh $SSH_OPTS root@$HOST $(shq "$CMD_CSELF")"
  plan "ssh $SSH_OPTS root@$HOST $(shq "$CMD_PSELF")"
  plan "ssh $SSH_OPTS root@$HOST $(shq "$CMD_ONCE")"
  plan "ssh $SSH_OPTS root@$HOST $(shq "$CMD_HEAD")    # only generated/source are printed"
  plan "ssh $SSH_OPTS root@$HOST $(shq "$CMD_SMOKE")"
  say "Printed at the end as hints for manual control (never run by the installer):"
  say "  ssh root@$HOST $(shq "$CMD_STATUS")"
  say "  ssh root@$HOST $(shq "$CMD_STOP")"
  exit 0
fi

# ---------------------------------------------------------------- real run
for _t in ssh scp cksum mktemp; do command -v "$_t" >/dev/null 2>&1 || die 2 "$_t not found on this machine"; done
# private work directory: captured remote output + the control socket (a unix socket path is limited to ~100
# characters, so a long or odd $TMPDIR falls back to /tmp)
base=${TMPDIR:-/tmp}
case $base in *[!A-Za-z0-9._/-]*) base=/tmp ;; esac
[ "${#base}" -le 60 ] || base=/tmp
WORK=$(mktemp -d "${base%/}/starchorus-inst.XXXXXX") || die 2 "cannot create a temp directory"
CM=$WORK/cm
mk_opts "$CM"
# shellcheck disable=SC2317,SC2329   # invoked via trap (SC2317 on ShellCheck < 0.10, SC2329 on >= 0.10)
cleanup() {
  [ -n "$WORK" ] || return 0
  if [ -e "$CM" ]; then ssh -o "ControlPath=$CM" -O exit "root@$HOST" >/dev/null 2>&1 </dev/null; fi
  rm -rf "$WORK"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# SC2086: SSH_OPTS is a word list on purpose (mk_opts); SC2029: the remote command is built on this side on purpose
# shellcheck disable=SC2086,SC2029
rsh()     { ssh $SSH_OPTS "root@$HOST" "$1" </dev/null; }                  # rsh CMD          (terminal I/O)
# shellcheck disable=SC2086,SC2029
rsh_cap() { ssh $SSH_OPTS "root@$HOST" "$2" </dev/null >"$1" 2>&1; }       # rsh_cap OUT CMD  (stdout+stderr -> OUT)
# shellcheck disable=SC2086
rcp()     { scp -O $SSH_OPTS "$1" "root@$HOST:$2" </dev/null; }            # rcp SRC DEST
# shellcheck disable=SC2086
rget()    { scp -O $SSH_OPTS "root@$HOST:$1" "$2" </dev/null; }            # rget DEVICE-PATH LOCAL-FILE (read-back)

indent() { LC_ALL=C sed 's/^/      /'; }
# firstline FILE: the first line of a captured output, ONLY if it is short plain text (a tool's error message).
# Anything else (a JSON line with MAC/SSID values, binary) is not shown at all: privacy rule P9.
firstline() {
  _l=$(LC_ALL=C sed -n '1p' "$1" | LC_ALL=C cut -c1-100)
  if printf '%s\n' "$_l" | LC_ALL=C grep -Eq "^[A-Za-z0-9 ._:/()'-]*\$"; then printf '%s' "${_l:-no output}"
  else printf '%s' "not shown: not plain text"; fi
}
NPASS=0; NWARN=0; NFAIL=0; PROBLEMS=""
res() {   # res PASS|WARN|FAIL text -- WARN and FAIL are marked with "!!" and repeated in the closing summary
  case $1 in
    PASS) NPASS=$((NPASS + 1)); printf '   [PASS] %s\n' "$2" ;;
    WARN) NWARN=$((NWARN + 1)); printf '!! [WARN] %s\n' "$2"; PROBLEMS="${PROBLEMS}  WARN  $2
" ;;
    *)    NFAIL=$((NFAIL + 1)); printf '!! [FAIL] %s\n' "$2"; PROBLEMS="${PROBLEMS}  FAIL  $2
" ;;
  esac
}
# the last line naming "SELFTEST:" of a captured output
sumline() { LC_ALL=C grep 'SELFTEST:' "$1" | tail -n 1; }

say ""
say "==> connecting to root@$HOST (enter the root password once) ..."
rsh "$CMD_MKDIR" || die 1 "cannot reach or authenticate on root@$HOST (mkdir failed) -- nothing was installed"

say "==> uploading from the repo (scp -O)"
while IFS='|' read -r rel dest _x; do
  rcp "$ROOT/$rel" "$dest" || die 1 "upload failed: $rel -> $dest (the install is incomplete)"
  say "  $rel -> $dest"
done <<EOF
$FILES
EOF

say "==> setting exec bits"
rsh "$CMD_CHMOD" || die 1 "chmod +x failed on the device"

say "==> integrity: cksum (CRC + size) local vs device"
# The cksum applet of the device's BusyBox is NOT yet measured (see the header). "No usable output" (applet
# missing, other output format) is a different fact from "the upload is damaged", so the two are told apart:
# cksum settles a file only when its CRC + size line is present and equal; every other file is decided by
# reading it back and comparing the bytes.
rsh_cap "$WORK/cksum.out" "$CMD_CKSUM"; ck_rc=$?
nusable=$(LC_ALL=C grep -Ec '^[0-9]+ [0-9]+ /' "$WORK/cksum.out")
ck_line=$(firstline "$WORK/cksum.out")
: > "$WORK/cand"
while IFS='|' read -r rel dest _x; do
  lsum=$(cksum < "$ROOT/$rel" | awk '{ print $1 " " $2 }')
  rsum=$(awk -v p="$dest" '$3 == p { print $1 " " $2; exit }' "$WORK/cksum.out")
  [ "$lsum" = "$rsum" ] || printf '%s|%s|%s|%s\n' "$rel" "$dest" "$lsum" "${rsum:--}" >> "$WORK/cand"
done <<EOF
$FILES
EOF
ncand=$(wc -l < "$WORK/cand" | tr -d ' ')
INTEG=""; SEEN_CKSUM="no usable output (exit $ck_rc: $ck_line)"
if [ "$nusable" != 0 ]; then SEEN_CKSUM="prints CRC + size lines (exit $ck_rc)"; fi
if [ "$ncand" = 0 ]; then
  res PASS "cksum identical for all $NFILES files (CRC + size)"
  INTEG="cksum (CRC + size) identical for all $NFILES files"
else
  say "  $ncand of $NFILES file(s) not settled by cksum -- reading them back with scp and comparing the bytes"
  mkdir "$WORK/back"; : > "$WORK/rb_bad"; : > "$WORK/rb_unread"; rb_bad=0; rb_unread=0; rb_ok=0; _n=0
  while IFS='|' read -r rel dest lsum rsum; do
    _n=$((_n + 1))
    if rget "$dest" "$WORK/back/$_n" >"$WORK/back/$_n.err" 2>&1; then
      if cmp -s "$ROOT/$rel" "$WORK/back/$_n"; then rb_ok=$((rb_ok + 1))
      else
        rb_bad=$((rb_bad + 1))
        printf '  %s: bytes differ (cksum local %s, device %s)\n' "$dest" "$lsum" "$rsum" >> "$WORK/rb_bad"
      fi
    else
      rb_unread=$((rb_unread + 1))
      printf '  %s: could not be read back (cksum local %s, device %s; scp: %s)\n' "$dest" "$lsum" "$rsum" "$(firstline "$WORK/back/$_n.err")" >> "$WORK/rb_unread"
    fi
  done < "$WORK/cand"
  if [ "$rb_bad" != 0 ]; then   # a real byte difference: the copy on the device is not the repo file
    say "!! [FAIL] $rb_bad file(s) differ between the repo and the device:"; cat "$WORK/rb_bad"
    die 1 "the upload is not intact; run it again (nothing else was checked)"
  fi
  if [ "$rb_unread" != 0 ]; then   # neither checked by cksum nor readable: NOT a statement about the upload's bytes
    res FAIL "integrity NOT verified for $rb_unread of $NFILES file(s): cksum did not settle them and they could not be read back:"
    cat "$WORK/rb_unread"
    INTEG="NOT verified for $rb_unread of $NFILES file(s)"
  elif [ "$nusable" = 0 ]; then
    res WARN "cksum gave no usable output on the device ($ck_line) -- not yet measured there; integrity verified instead by reading all $rb_ok files back with scp and comparing the bytes"
    INTEG="all $rb_ok files read back with scp and compared byte for byte (the device's cksum gave no usable output)"
  else
    res WARN "cksum did not confirm $rb_ok file(s) (line missing, or other numbers), but the bytes read back are identical (another checksum algorithm on the device?)"
    INTEG="cksum identical for $((NFILES - rb_ok)) files; $rb_ok read back with scp and compared byte for byte"
  fi
fi

say "==> selftests on the device (offline: embedded sample data, no radio)"
selftest() {   # selftest LABEL CMD OUTFILE MISSING-IS-OK(1|0)
  _l=$1; _o=$3
  rsh_cap "$_o" "$2"; _rc=$?
  _s=$(sumline "$_o")
  case $_s in
    *"SELFTEST: ALL PASS"*)
      if [ "$_rc" = 0 ]; then res PASS "$_l selftest: ${_s#*SELFTEST: }"
      else res FAIL "$_l selftest says ALL PASS but exited $_rc"; fi ;;
    '')
      if [ "$4" = 1 ] && [ "$_rc" = 0 ]; then
        res WARN "$_l has no --selftest on the device (older version?) -- skipped; reinstall from a current repo"
      else
        res FAIL "$_l selftest gave no result line (exit $_rc); last lines:"; tail -n 3 "$_o" | indent
      fi ;;
    *)
      res FAIL "$_l selftest: ${_s#*SELFTEST: }"
      LC_ALL=C grep 'FAIL' "$_o" | head -n 20 | indent ;;
  esac
}
selftest "collector" "$CMD_CSELF" "$WORK/csel.out" 0
# An older dashboard would not know the flag; the repo copy is checked first so an unknown argument is never
# handed to a dashboard that could fall into its interactive menu loop.
if LC_ALL=C grep -qF -- '--selftest' "$ROOT/starchorus-display.sh"; then
  selftest "dashboard (starchorus-display.sh)" "$CMD_PSELF" "$WORK/psel.out" 1
else
  res WARN "starchorus-display.sh in this repo has no --selftest yet -- the dashboard selftest was skipped"
fi

say "==> one real passive capture (collector --once, STARCHORUS_MAX_AGE=$MAX_AGE as in the payload; 0 = the whole record)"
rsh_cap "$WORK/once.out" "$CMD_ONCE"; rc=$?
tail -n 3 "$WORK/once.out" | indent
if [ "$rc" = 0 ]; then res PASS "collector --once finished"
else res WARN "collector --once exited $rc (source 'none'? see the log above) -- a passive source may be missing"; fi
# "head -c" is not yet measured on the device either: a failing head is reported with its own first error line
# (only if it is plain text, see firstline), not as a vague "no readable starchorus.json".
rsh_cap "$WORK/head.out" "$CMD_HEAD"; head_rc=$?
gen=$(LC_ALL=C sed -n 's/.*"generated":[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$WORK/head.out" | head -n 1)
src=$(LC_ALL=C sed -n 's/.*"source":[[:space:]]*"\([A-Za-z0-9_-]*\)".*/\1/p' "$WORK/head.out" | head -n 1)
say "  starchorus.json: generated=${gen:-?} source=${src:-?}   (content not echoed: MAC/SSID values of third parties)"
SEEN_HEAD="exit $head_rc"
[ "$head_rc" = 0 ] || SEEN_HEAD="exit $head_rc: $(firstline "$WORK/head.out")"
[ -n "$gen" ] || res WARN "no readable starchorus.json at $LOOT after --once (head -c 400: $SEEN_HEAD; head -c is not yet measured on the device)"

say "==> dashboard smoke test (starchorus-display.sh --once summary reads that json)"
rsh_cap "$WORK/sum.out" "$CMD_SMOKE"; rc=$?
head -n 12 "$WORK/sum.out" | indent
problem=""
addp() { problem="${problem:+$problem; }$1"; }
[ "$rc" = 0 ] || addp "dashboard exited $rc"
if LC_ALL=C grep -qi 'jq incomplete' "$WORK/sum.out"; then addp "output says 'jq incomplete'"; fi
band=$(LC_ALL=C grep -F '2.4:' "$WORK/sum.out" | head -n 1)
if [ -z "$band" ]; then
  addp "no band line (2.4: 5: 6:) in the summary"
else
  for _b in 2.4 5 6; do   # a digit must FOLLOW each colon at once: aborting filters print "2.4:  5:  6:"
    _re=$(printf '%s' "$_b" | sed 's/\./\\./g')
    printf '%s\n' "$band" | LC_ALL=C grep -Eq "(^|[^0-9.])$_re:[0-9]" || addp "no digit after '$_b:'"
  done
fi
if [ -z "$problem" ]; then
  res PASS "band counters filled: $(printf '%s' "$band" | tr -s ' ')"
else
  res FAIL "dashboard summary broken: $problem (blank counters = jq filters aborting on the device, docs/device-notes.md 2a)"
fi

# ---------------------------------------------------------------- closing summary (always printed)
say ""
say "==> result: $NPASS passed, $NWARN warning(s), $NFAIL failed"
[ -z "$PROBLEMS" ] || printf '%s' "$PROBLEMS"
say ""
say "Installed on root@$HOST, real versions read from the repo files:"
printf '  %-10s %-8s %s\n' page "$VER_PAGE" "$LOOT/index.html" collector "$VER_COLLECT" "$LOOT/starchorus-collect.sh" \
  display "$VER_DASH" "$LOOT/starchorus-display.sh (+ the copy next to the payload)" payload "$VER_PAYLOAD" "$PLDIR/payload.sh"
say "Integrity: $INTEG"
cat <<EOF

Seen on the device by THIS run (cksum and head -c are not yet recorded in docs/device-notes.md; add these
two lines there after a run you trust, together with the date):
  cksum:   $SEEN_CKSUM
  head -c: $SEEN_HEAD

This installer only copied files over ssh/scp and ran the passive on-device checks; nothing was transmitted
over the air.

If Starchorus was running on the device, stop it before installing and start it again afterwards (files are
overwritten in place). On the device: payload menu -> Reconnaissance -> "Starchorus", pick
"Start" (Services and Options set what starts; settings stay in $LOOT/settings.conf, which this installer never
touches). With a web server on the device (README.md, "Serving the page", A) browse to
http://$HOST:8199/ (or the port set under Options) from this machine; otherwise pull starchorus.json and serve it locally (same section, B).

Manual control over ssh (each is one command; the master session has closed, so it asks again):
  ssh root@$HOST $(shq "$CMD_STATUS")
  ssh root@$HOST $(shq "$CMD_STOP")
EOF
if [ "$NFAIL" = 0 ]; then exit 0; fi
say ""
say "INSTALL NOT VERIFIED: $NFAIL check(s) failed (see above)."
exit 1
