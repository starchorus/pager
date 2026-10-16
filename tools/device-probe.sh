#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
#
# device-probe.sh -- ONE read-only ssh session that answers the open device verifications
#                    (docs/device-notes.md, the open device verifications and 2a).
#
# THIS FILE RUNS ON THE DEVICE. Everything else in tools/ runs on the dev machine; this is the one exception:
# the human pipes it into a device shell over ssh and types the ssh password himself (nothing here ever sees it):
#
#     ssh root@<device> sh -s < tools/device-probe.sh | tee probe.txt
#
# CONTRACT, in plain words (read only, send nothing, change nothing):
#   * It transmits nothing over the air and configures nothing. It is passive and read-only.
#   * No AP-service command line tool of any kind, no package manager, no config change (uci set/commit), no
#     service start/stop, no Wi-Fi scan, no packet capture, no network call (curl, wget, nc, ping, ...), and it
#     never reads handshake or capture files under /root/loot. Only read commands: cat, ls, grep, wc, head, df,
#     readlink, find, iw dev/phy info, iw survey dump, jq on literals, sqlite3 -readonly on COPIES.
#   * The live recon.db is never opened. It is COPIED with cp into a private mktemp -d directory under /tmp
#     (RAM on the device) and, in this script's own code, only the copies are opened, only through sqlite3
#     -readonly (the single sq() function).
#   * It writes nowhere but that private directory (mode 0700). A trap removes it on EXIT, INT, TERM, HUP, PIPE.
#   * The one place that starts other programs is section 8: the INSTALLED Starchorus collector's --status and
#     --selftest (and the display script's --selftest when that script has the flag). Their TMPDIR, all STARCHORUS_*DIR
#     variables and a template-less mktemp are pinned into the private directory. By the selftest source they
#     only feed synthetic data (databases built inside that directory) to the collector's parsers, and a run
#     with tripwires on a dev machine saw no capture, scan, network or package tool called. It can take minutes on
#     the MIPS CPU: skip it with STARCHORUS_PROBE_SKIP_SELFTEST=1.
#   * Privacy (rule P9: the pasted output ends up in the repo): everything that comes out of recon.db is a count,
#     a column name, a numeric range or a distribution -- never an SSID, BSSID, MAC, client identifier or per-
#     device row. File and directory NAMES are the one other place where a device can leak (an SSID or a BSSID
#     used as a file name), so they are printed only from fixed word lists: a /root/loot directory only when it is
#     named "starchorus" or "handshakes", a candidate path (section 6) only component by component when the component
#     is made of generic words (WORDS below). Any other name prints as <withheld> and is only counted. As a last
#     net (a filter, not a proof: skim the output before pasting) every MAC-shaped string -- six octets joined by
#     : . _ - , three dotted 4-digit groups, or a run of 12+ hex digits -- becomes <mac-withheld> before printing.
#   * The output is OBSERVATIONS, not facts: "seen on this device at this moment". "== summary ==" lists every
#     open verification as "V-<id> <name>: OBSERVED <value>" or "NOT-OBSERVABLE <reason>"; the ids are fixed
#     (vname below). Whatever needs a forbidden command stays NOT-OBSERVABLE.
#
# Safety guard: unless STARCHORUS_PROBE_FORCE=1 it refuses to run (exit 2) when uname -s is not Linux or
# /etc/openwrt_release is missing, so an accidental `sh tools/device-probe.sh` on the dev machine does nothing.
#
# Knobs (env; over ssh: ssh root@<device> 'STARCHORUS_PROBE_GAP=15 sh -s' < tools/device-probe.sh):
#   STARCHORUS_PROBE_FORCE=1           skip the guard (tests on a dev machine)
#   STARCHORUS_PROBE_RECON_DB=PATH     probe this recon.db instead of /root/recon/recon.db and /mmc/root/recon/recon.db
#   STARCHORUS_PROBE_GAP=SECONDS       gap between the two recon.db copies (default 10, 1..120)
#   STARCHORUS_PROBE_SKIP_SELFTEST=1   skip the installed collector's/display script's --selftest (section 8; can take minutes)
#   STARCHORUS_PROBE_ROOT=DIR          test hook: prefix for /root /etc /lib /sys /mmc (empty on the device)
#   STARCHORUS_PROBE_INSTALL_DIR=DIR   test hook: where Starchorus is installed (default /root/loot/starchorus)
#
# `sh -s` reads the script from stdin, so no command may ever read stdin (it would swallow the rest of the
# script). Everything lives in functions; main() is called with stdin from /dev/null, and sqlite3 gets its SQL
# as an argument. POSIX sh / BusyBox ash only: no local, no [[ ]], no arrays, no process substitution.

# ---------------------------------------------------------------------------------------------- guard
if [ "${STARCHORUS_PROBE_FORCE:-0}" != 1 ]; then
    if [ "$(uname -s 2>/dev/null)" != Linux ] || [ ! -f /etc/openwrt_release ]; then
        echo "device-probe: this script is for the device (Linux with /etc/openwrt_release); refusing to run here." >&2
        echo "device-probe: usage: ssh root@<device> sh -s < tools/device-probe.sh | tee probe.txt" >&2
        exit 2
    fi
fi

set -u
umask 077
RF=${STARCHORUS_PROBE_ROOT:-}
GAP=${STARCHORUS_PROBE_GAP:-10}
case $GAP in ''|*[!0-9]*) GAP=10 ;; esac
if [ "$GAP" -lt 1 ] || [ "$GAP" -gt 120 ]; then GAP=10; fi
T=""; OUT=""; SLPID=""; BGPID=""; RL_RC=0; RED=0; DIFF_XTRA=""
V6_DB="recon.db not read"; V6_DB_OK=0; V6_PHY="iw not read"; V6_PHY_OK=0

# ---------------------------------------------------------------------------------------------- cleanup
# The only thing ever deleted is the private directory this run created itself (name check).
# shellcheck disable=SC2317,SC2329   # invoked via trap (SC2317 on ShellCheck < 0.10, SC2329 on >= 0.10)
cleanup() {
    if [ -n "$SLPID" ]; then kill "$SLPID" 2>/dev/null; fi
    if [ -n "$BGPID" ]; then kill "$BGPID" 2>/dev/null; fi
    case $T in */starchorus-probe.*) rm -rf "$T" ;; esac
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
trap 'exit 141' PIPE

# ---------------------------------------------------------------------------------------------- helpers
have() { command -v "$1" >/dev/null 2>&1; }
clean() { tr -cd '\011\012\040-\176'; }              # printable ASCII only (no escape sequences, no raw bytes)
isnum() { case $1 in ''|*[!0-9]*) return 1 ;; esac; return 0; }
say() { printf '%s\n' "$*" >> "$OUT"; }
kv() { printf '%s: %s\n' "$1" "$2" >> "$OUT"; }
vset() { printf '%s\n' "$2" > "$T/v.$1"; }           # summary line of open verification $1

# Last net (rule P9), stdin -> stdout. Three MAC-shaped forms become <mac-withheld>: six hex octets joined by
# : . _ - (any mix), three dotted 4-digit groups, and a bare run of 12+ hex digits (the recon.db form, also inside
# a longer name) that has a letter in it or is exactly 12 long. A run of 13+ decimal digits stays (a millisecond
# time is not a MAC). Deliberately over-eager: an OS build hash of 12+ hex digits is withheld too (counter below).
scrub() {
    sed -E -e 's/([0-9A-Fa-f]{2}[:._-]){5}[0-9A-Fa-f]{2}/<mac-withheld>/g' \
           -e 's/[0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4}/<mac-withheld>/g' |
    awk '{
        s = $0; o = ""
        while (match(s, /[0-9A-Fa-f]+/)) {
            r = substr(s, RSTART, RLENGTH)
            if (RLENGTH >= 12 && (RLENGTH == 12 || r ~ /[A-Fa-f]/)) r = "<mac-withheld>"
            o = o substr(s, 1, RSTART - 1) r
            s = substr(s, RSTART + RLENGTH)
        }
        print o s
    }'
}

# Print what the section collected. Last net (rule P9): a MAC-shaped string never leaves this function.
flush() {
    [ -s "$OUT" ] || return 0
    clean < "$OUT" | scrub > "$T/flushed"
    RED=$((RED + $(grep -c '<mac-withheld>' "$T/flushed")))
    cut -c1-400 "$T/flushed"
    : > "$OUT"
}
heading() { flush; printf '\n== %s. %s ==\n' "$1" "$2"; }

# bytes of a regular file (ls -l field 5; -L follows a symlink), epoch mtime, KiB free on the fs of $1
# shellcheck disable=SC2012   # ls -l field 5 is the portable size (BusyBox stat may lack -c); the argument is our own path
fsize() { ls -lL "$1" 2>/dev/null | awk 'NR==1 {print $5}'; }
mtime_epoch() {
    _m=$(stat -c %Y "$1" 2>/dev/null) || _m=""                                # GNU / BusyBox
    if ! isnum "$_m"; then _m=$(stat -f %m "$1" 2>/dev/null) || _m=""; fi     # BSD (dev machine)
    if ! isnum "$_m"; then _m=$(date -r "$1" +%s 2>/dev/null) || _m=""; fi    # BusyBox date -r
    if isnum "$_m"; then printf '%s' "$_m"; fi
}
df_avail_kb() { df -kP "$1" 2>/dev/null | tail -n 1 | awk '{print $(NF-2)}'; }

# Sleep that a signal can interrupt at once (a plain foreground sleep defers the trap until it ends). Under
# BusyBox ash the trap may still wait for the sleep to end (see the note in starchorus-collect.sh main loop); the
# worst case is a delay of at most STARCHORUS_PROBE_GAP seconds, the cleanup runs either way.
nap() { sleep "$1" & SLPID=$!; wait "$SLPID" 2>/dev/null; SLPID=""; }

# run_limited SECONDS OUTFILE CMD...  -> RL_RC (124 = timed out). stdin from /dev/null, output to OUTFILE.
# BusyBox timeout forms differ between builds, so a portable poll loop instead of timeout(1).
run_limited() {
    _lim=$1; _of=$2; shift 2
    "$@" > "$_of" 2>&1 < /dev/null &
    BGPID=$!
    _w=0
    while kill -0 "$BGPID" 2>/dev/null; do
        if [ "$_w" -ge "$_lim" ]; then
            kill "$BGPID" 2>/dev/null; sleep 1; kill -9 "$BGPID" 2>/dev/null
            wait "$BGPID" 2>/dev/null; BGPID=""; RL_RC=124; return 0
        fi
        sleep 1; _w=$((_w + 1))
    done
    wait "$BGPID"; RL_RC=$?; BGPID=""
}

# sq DB SQL -- the ONLY place sqlite3 is invoked: always -readonly, always a COPY inside the private dir.
# Its exit code also lands in $T/sq.rc so that a caller inside $( ) can ask sqrc afterwards.
sq() {
    if [ -z "$T" ]; then return 99; fi
    case $1 in "$T"/*) ;; *) printf '99' > "$T/sq.rc"; return 99 ;; esac
    sqlite3 -readonly -noheader "$1" "$2" 2>"$T/sq.err" < /dev/null
    _sr=$?
    printf '%s' "$_sr" > "$T/sq.rc"
    return "$_sr"
}
sqrc() { cat "$T/sq.rc" 2>/dev/null || echo 99; }
sqerr() { head -n 1 "$T/sq.err" 2>/dev/null | clean | cut -c1-110; }
# sqk DB SQL: run and append the (already built "key: value") lines to the report; note a failure.
sqk() {
    sq "$1" "$2" >> "$OUT"
    _kr=$(sqrc)
    if [ "$_kr" -ne 0 ]; then say "note: query failed (rc $_kr): $(sqerr)"; fi
}
hascol() { case $1 in *",$2,"*) return 0 ;; esac; return 1; }      # hascol ",a,b," name
tok() { printf '%s\n' "$1" | sed -n "s/.* $2=\\([-0-9a-zA-Z.]*\\).*/\\1/p" | head -n 1; }   # value of " key=" in a line
hint_add() { _hint="${_hint:+$_hint; }$1"; }                    # append one observation to the running hint text
# Names on a device can carry an SSID or a BSSID (rule P9), so a name is never printed "if it looks harmless" but
# only "if it is on a list". Candidate paths (section 6): a path component is printed only when every token of it
# (split at . _ -) is one of WORDS or a number of at most 3 digits (at most two such numbers per component, so a
# digits-only MAC written with separators cannot pass); otherwise it prints as <withheld>. WORDS holds the
# directory names of the fixed places we look in and the words of the search patterns; extend it in this file if a
# real file you expect comes out withheld. (/root/loot directories use an even shorter list, see section 7.)
WORDS=" root etc config lib hak5 mmc loot starchorus handshakes pineapple pineap pineapd ssid ssids bssid bssids pool pools list lists own mac macs filter filters allow deny txt conf cfg json db csv log bak old new default defaults recon oui init d rc "
# safe_path ABSPATH -> the path without the test-root prefix, each component outside the word list shown as <withheld>
safe_path() {
    printf '%s' "${1#"$RF"}" | tr '\n\r' '??' | awk -F/ -v words="$WORDS" '
        {
            out = ""
            for (i = 1; i <= NF; i++) {
                c = $i
                if (c == "") continue
                ok = (c ~ /^[A-Za-z0-9._-]+$/)
                if (ok) {
                    n = split(tolower(c), t, /[._-]/); nn = 0
                    for (k = 1; k <= n; k++) {
                        if (t[k] ~ /^[0-9][0-9]?[0-9]?$/) { if (++nn > 2) ok = 0 }
                        else if (t[k] != "" && index(words, " " t[k] " ") == 0) ok = 0
                    }
                }
                out = out "/" (ok ? c : "<withheld>")
            }
            print (out == "" ? "/" : out)
        }'
}

# ============================================================================================ 1. jq
# The regex-family calls below are DELIBERATE probes: the observed result (an error, exit 5) is the point.
# Each runs as its own jq process on literals, so a failure cannot affect anything else.
jq_run() {   # jq_run FILTER -> JQ_RC and JQ_OUT (first line of what jq said, cleaned)
    JQ_OUT=$(jq -c -n "$1" 2>&1 < /dev/null); JQ_RC=$?
    JQ_OUT=$(printf '%s\n' "$JQ_OUT" | head -n 1 | clean | cut -c1-110)
}
jq_check() { # jq_check LABEL FILTER WANT -> kv line, JQ_ST = ok | ERROR(...) | WRONG-OUTPUT(...)
    jq_run "$2"
    if [ "$JQ_RC" -ne 0 ]; then JQ_ST="ERROR(exit $JQ_RC: $JQ_OUT)"
    elif [ "$JQ_OUT" = "$3" ]; then JQ_ST=ok
    else JQ_ST="WRONG-OUTPUT(got $JQ_OUT, want $3)"; fi
    kv "jq.$1" "$JQ_ST"
}
rx_check() { # rx_check LABEL FILTER -> kv line; counts the ones that fail with the no-Oniguruma message
    jq_run "$2"
    if [ "$JQ_RC" -eq 0 ]; then RX_ST=works
    else
        case $JQ_OUT in
            *[Oo][Nn][Ii][Gg]*) RX_ST=no-oniguruma ;;
            *) RX_ST="error($JQ_OUT)" ;;
        esac
    fi
    kv "jq.regex.$1" "$RX_ST (exit $JQ_RC)"
    if [ "$RX_ST" = no-oniguruma ]; then RXBAD=$((RXBAD + 1)); fi
}
sect_jq() {
    heading 1 "jq"
    if ! have jq; then
        kv jq "absent"
        vset 12 "NOT-OBSERVABLE jq is not installed"
        return 0
    fi
    kv jq.path "$(command -v jq)"
    kv jq.version "$(jq --version 2>&1 < /dev/null | head -n 1 | clean | cut -c1-60)"
    # the section-2a one-liner, verbatim (compact output; device-notes.md expects [true,"a",0,"5"])
    jq_run '["5 GHZ"|ascii_downcase|endswith("ghz"), ("ab"|until(length==1; .[:-1])), ([" "]|index(" ")), (5|tostring)]'
    if [ "$JQ_RC" -eq 0 ] && [ "$JQ_OUT" = '[true,"a",0,"5"]' ]; then ONE_ST=MATCH; else ONE_ST=DIFFERENT; fi
    kv jq.oneliner_2a "$JQ_OUT (exit $JQ_RC; expected [true,\"a\",0,\"5\"]) -> $ONE_ST"
    # control: a builtin known to work on the device, so a broken jq cannot pass for five broken builtins
    jq_check control '"abc"|startswith("a")' true
    # each of the five builtins on its own
    jq_check endswith '"5 ghz"|endswith("ghz")' true;                                     ST_END=$JQ_ST
    jq_check until '0|until(.>=3;.+1)' 3;                                                 ST_UNT=$JQ_ST
    jq_check index-array '[" "]|index(" ")' 0;                                            ST_IDA=$JQ_ST
    jq_check index-string '"a b"|index(" ")' 1;                                           ST_IDS=$JQ_ST
    jq_check slicing '["abc"|.[1:],.[:-1],.[-1:],.[0:1]]' '["bc","ab","c","a"]';          ST_SLC=$JQ_ST
    jq_check tostring '[(5|tostring),("x"|tostring),(null|tostring)]' '["5","x","null"]'; ST_TOS=$JQ_ST
    # regex family (device-notes 2a: all eight fail at call time with exit 5)
    RXBAD=0
    rx_check test '"abc"|test("b")'
    rx_check match '"abc"|match("b")|.offset'
    rx_check capture '"abc"|capture("(?<x>b)")'
    rx_check scan '"abc"|scan("b")'
    rx_check sub '"abc"|sub("b";"x")'
    rx_check gsub '"abc"|gsub("b";"x")'
    rx_check splits '"abc"|[splits("b")]'
    rx_check split2 '"abc"|split("b";null)'
    kv jq.regex.summary "$RXBAD of 8 report no-oniguruma"
    vset 12 "OBSERVED endswith=$ST_END until=$ST_UNT index=$ST_IDA/$ST_IDS slicing=$ST_SLC tostring=$ST_TOS oneliner=$ONE_ST regex_family_no_oniguruma=$RXBAD/8"
}

# ============================================================================================ 2. tools
sect_tools() {
    heading 2 "tools"
    for _t in sqlite3 tcpdump iw iwinfo jq curl wget nc timeout setsid start-stop-daemon uhttpd python3 airodump-ng; do
        _p=$(command -v "$_t" 2>/dev/null) || _p=""
        if [ -z "$_p" ]; then kv "tool.$_t" absent; continue; fi
        _r=$(readlink -f "$_p" 2>/dev/null) || _r=""
        if [ -z "$_r" ]; then _r=$(readlink "$_p" 2>/dev/null) || _r=""; fi
        case ${_r##*/} in busybox) _via=" (busybox applet)" ;; '') _via="" ;; *) _via=" (resolves to ${_r##*/})" ;; esac
        if [ "$_r" = "$_p" ]; then _via=" (standalone binary)"; fi
        kv "tool.$_t" "$_p$_via"
    done
    if have busybox; then kv busybox.version "$(busybox 2>&1 < /dev/null | head -n 1 | clean | cut -c1-80)"
    else kv busybox.version "no busybox in PATH"; fi
    _sh=$(command -v sh 2>/dev/null) || _sh=""
    kv sh "$_sh -> $(readlink -f "$_sh" 2>/dev/null | clean)"
    if have iw; then kv iw.version "$(iw --version 2>&1 < /dev/null | head -n 1 | clean | cut -c1-60)"; fi
    # timeout: GNU coreutils or the busybox applet? (--version only prints text, it runs no command)
    if have timeout; then
        _tv=$(timeout --version 2>&1 < /dev/null | head -n 1 | clean | cut -c1-70)
        _tr=$(readlink -f "$(command -v timeout)" 2>/dev/null) || _tr=""
        case $_tv in
            *"GNU coreutils"*) _tk="GNU coreutils" ;;
            *) case ${_tr##*/} in busybox) _tk="busybox applet" ;; *) _tk="unknown" ;; esac ;;
        esac
        kv timeout.kind "$_tk (--version said: ${_tv:-nothing})"
    else
        kv timeout.kind "no timeout command"
    fi
}

# ============================================================================================ 3. recon.db
# Which recon.db columns exist decides which queries are issued; every value that comes out of sqlite3 is a
# count, a min/max or a numeric code (typeof-guarded in SQL), never a text column of the observation rows.
cand_db() {   # cand_db PATH -> kv line; DB = first readable candidate
    if [ -f "$1" ]; then
        _s=$(fsize "$1"); _t=$(mtime_epoch "$1")
        kv recon.candidate "$1 exists size_bytes=${_s:-?} mtime_epoch=${_t:-?}"
        if [ -z "$DB" ] && [ -r "$1" ]; then DB=$1; fi
    else
        kv recon.candidate "$1 absent"
    fi
}
# numstat_sql LABEL TABLE COLUMN -> one SELECT yielding "LABEL: n= min= max= distinct= non_numeric=" (names are ours)
numstat_sql() {
    printf '%s' "SELECT '$1: n='||count(*)||' min='||ifnull(CAST(min($3) AS INTEGER),'n/a')||' max='||ifnull(CAST(max($3) AS INTEGER),'n/a')||' distinct='||count(DISTINCT $3)||' non_numeric='||(SELECT count(*) FROM $2 WHERE typeof($3) NOT IN ('integer','real')) FROM $2 WHERE typeof($3) IN ('integer','real');"
}
# band_sql TABLE LABEL WHERE-PREFIX -> rows per band (2.4 = 2400..2499, 5 = 4900..5924, 6 = 5925..7125 MHz)
band_sql() {
    printf '%s' "SELECT '$1.band_rows($2): 2.4='||coalesce(sum(f>=2400 AND f<2500),0)||' 5='||coalesce(sum(f>=4900 AND f<5925),0)||' 6='||coalesce(sum(f>=5925 AND f<=7125),0)||' other='||coalesce(sum(NOT ((f>=2400 AND f<2500) OR (f>=4900 AND f<5925) OR (f>=5925 AND f<=7125))),0)||' in_5955_7115='||coalesce(sum(f>=5955 AND f<=7115),0) FROM (SELECT CAST(freq AS INTEGER) AS f FROM $1 WHERE $3 typeof(freq) IN ('integer','real'));"
}
# diff_sql TABLE KEY COL... -> ATTACH copy B (read-only like the main connection) and compare with copy A: counts only.
# DIFF_XTRA (set by the caller, "" otherwise) is one more "||' name='||(SELECT count(*) ...)" piece appended at the end.
diff_sql() {
    _dt=$1; _dk=$2; shift 2
    _de="'diff.$_dt: rows_a='||(SELECT count(*) FROM main.$_dt)||' rows_b='||(SELECT count(*) FROM b.$_dt)||' new_in_b='||(SELECT count(*) FROM b.$_dt x WHERE NOT EXISTS (SELECT 1 FROM main.$_dt y WHERE y.$_dk=x.$_dk))||' gone_in_b='||(SELECT count(*) FROM main.$_dt y WHERE NOT EXISTS (SELECT 1 FROM b.$_dt x WHERE x.$_dk=y.$_dk))"
    for _dc in "$@"; do
        _de="$_de||' ${_dc}_up='||(SELECT count(*) FROM main.$_dt y JOIN b.$_dt x ON x.$_dk=y.$_dk WHERE x.$_dc>y.$_dc)||' ${_dc}_down='||(SELECT count(*) FROM main.$_dt y JOIN b.$_dt x ON x.$_dk=y.$_dk WHERE x.$_dc<y.$_dc)"
        if [ "$_dc" = time ]; then
            _de="$_de||' max_time_a='||(SELECT ifnull(CAST(max(time) AS INTEGER),'n/a') FROM main.$_dt WHERE typeof(time) IN ('integer','real'))||' max_time_b='||(SELECT ifnull(CAST(max(time) AS INTEGER),'n/a') FROM b.$_dt WHERE typeof(time) IN ('integer','real'))"
        fi
    done
    printf "ATTACH '%s' AS b; SELECT %s%s;" "$B" "$_de" "${DIFF_XTRA:-}"
}
# recon_fail WHY: the recon.db questions cannot be answered
recon_fail() {
    vset 1 "NOT-OBSERVABLE $1"; vset 2 "NOT-OBSERVABLE $1"; vset 10 "NOT-OBSERVABLE $1"
    V6_DB="recon.db not read ($1)"; V6_DB_OK=0
}

sect_recon() {
    heading 3 "recon.db (copies only; counts, column names, numeric ranges; nothing per device)"
    DB=""; A="$T/a.db"; B="$T/b.db"; COLS_ssid=""; COLS_wd=""; PK_ssid=""; PK_wd=""; HAVE_A=0; HAVE_B=0
    MT_A=""; MT_B=""; NOW_A=0; NOW_B=0
    if [ -n "${STARCHORUS_PROBE_RECON_DB:-}" ]; then
        kv recon.override "STARCHORUS_PROBE_RECON_DB is set; the default locations are not looked at"
        cand_db "$STARCHORUS_PROBE_RECON_DB"
    else
        cand_db "$RF/root/recon/recon.db"
        cand_db "$RF/mmc/root/recon/recon.db"
    fi
    if [ -z "$DB" ]; then kv recon.db "no readable recon.db found"; recon_fail "no readable recon.db at the candidate locations"; return 0; fi
    if ! have sqlite3; then kv recon.db "sqlite3 is not installed, nothing can be opened"; recon_fail "sqlite3 not installed"; return 0; fi
    kv recon.db.used "$DB (opened only as copies, read-only)"
    kv workspace "$T ($(df -kP "$T" 2>/dev/null | tail -n 1 | awk '{print "fs=" $1 " mount=" $NF}'))"

    # -- copies: 2 by default, fewer when the private dir is RAM-tight (copies may use at most 25 % of free space)
    _sz=$(fsize "$DB"); if ! isnum "$_sz"; then _sz=0; fi
    _kb=$(( (_sz + 1023) / 1024 ))
    _av=$(df_avail_kb "$T"); if ! isnum "$_av"; then _av=0; fi
    COPIES=2
    if [ "$_av" -gt 0 ]; then
        if [ $((_kb * 4)) -gt "$_av" ]; then COPIES=0
        elif [ $((_kb * 8)) -gt "$_av" ]; then COPIES=1; fi
    elif [ "$_kb" -gt 16384 ]; then COPIES=0
    fi
    kv recon.copies "$COPIES planned (db ${_kb} KiB, free ${_av} KiB in the private dir)"
    if [ "$COPIES" -eq 0 ]; then recon_fail "db too large for a RAM copy (${_kb} KiB vs ${_av} KiB free)"; return 0; fi
    if [ -f "$DB-wal" ]; then kv recon.wal "a -wal file sits next to the live db (copied along with each copy)"; fi
    MT_A=$(mtime_epoch "$DB"); NOW_A=$(date +%s); if ! isnum "$NOW_A"; then NOW_A=0; fi
    if cp "$DB" "$A" 2>/dev/null; then HAVE_A=1; fi
    if [ -f "$DB-wal" ]; then cp "$DB-wal" "$A-wal" 2>/dev/null; fi
    flush
    if [ "$HAVE_A" -eq 1 ] && [ "$COPIES" -ge 2 ]; then
        nap "$GAP"
        MT_B=$(mtime_epoch "$DB"); NOW_B=$(date +%s); if ! isnum "$NOW_B"; then NOW_B=0; fi
        if cp "$DB" "$B" 2>/dev/null; then HAVE_B=1; fi
        if [ -f "$DB-wal" ]; then cp "$DB-wal" "$B-wal" 2>/dev/null; fi
    fi
    if [ "$HAVE_A" -ne 1 ]; then kv recon.copy "cp failed; nothing was opened"; recon_fail "the copy of the recon.db failed"; return 0; fi
    kv recon.copy_a "taken at device clock $NOW_A, live mtime ${MT_A:-?}"
    if [ "$HAVE_B" -eq 1 ]; then kv recon.copy_b "taken at device clock $NOW_B ($((NOW_B - NOW_A)) s after copy a), live mtime ${MT_B:-?}"; fi
    _v=$(sq "$A" "SELECT sqlite_version();")
    if [ "$(sqrc)" -ne 0 ]; then
        say "note: copy a did not open ($(sqerr)); recopying once"
        cp "$DB" "$A" 2>/dev/null; _v=$(sq "$A" "SELECT sqlite_version();")
    fi
    if [ "$(sqrc)" -ne 0 ]; then
        kv recon.copy "the copy does not open as a database"
        recon_fail "the recon.db copy did not open ($(sqerr))"; return 0
    fi
    kv sqlite.version "$_v"

    # -- schema: table names, row counts, column names, primary-key columns (names only)
    sq "$A" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" > "$T/tables"
    while IFS= read -r _tn; do
        case $_tn in ''|*[!A-Za-z0-9_]*) kv table "(a table name with unusual characters is not printed)"; continue ;; esac
        _rows=$(sq "$A" "SELECT count(*) FROM \"$_tn\";")
        sq "$A" "PRAGMA table_info(\"$_tn\");" > "$T/ti"
        _cols=$(cut -d'|' -f2 "$T/ti" | tr -cd 'A-Za-z0-9_\n' | tr '\n' ',' | sed 's/,$//')
        _pk=$(awk -F'|' '$6 + 0 > 0 { printf "%s ", $2 }' "$T/ti" | tr -cd 'A-Za-z0-9_ ' | sed 's/ $//')
        kv "table.$_tn" "rows=${_rows:-?} columns=$_cols primary_key=${_pk:--}"
        case $_tn in
            ssid) COLS_ssid=",$_cols,"; PK_ssid=$_pk ;;
            wifi_device) COLS_wd=",$_cols,"; PK_wd=$_pk ;;
        esac
    done < "$T/tables"
    if [ -z "$COLS_ssid" ]; then
        if [ -s "$T/tables" ]; then say "note: no table named ssid; the per-observation analysis is skipped (legacy-style aps table or an unknown layout)"
        else say "note: the copy has no tables at all; nothing to analyse"; fi
        recon_fail "recon.db has no ssid table (tables are listed above)"; V6_DB="no ssid table in recon.db"
        return 0
    fi
    for _c in type bssid apmac stamac time signal freq channel encryption hash scan wifi_device hidden band; do
        if hascol "$COLS_ssid" "$_c"; then _st=present; else _st=absent; fi
        say "column.ssid.$_c: $_st"
    done
    for _c in mac time signal freq packets hash scan; do
        if hascol "$COLS_wd" "$_c"; then _st=present; else _st=absent; fi
        say "column.wifi_device.$_c: $_st"
    done
    AK=""
    if hascol "$COLS_ssid" bssid; then AK=bssid; elif hascol "$COLS_ssid" apmac; then AK=apmac; fi
    TP=""
    if hascol "$COLS_ssid" type; then TP="type IN (5,8) AND"; fi
    flush

    # -- ssid: rows per type (numeric type codes only), time column
    if hascol "$COLS_ssid" type; then
        sqk "$A" "SELECT 'ssid.rows.type_'||type||': '||count(*) FROM ssid WHERE typeof(type)='integer' GROUP BY type ORDER BY type;"
        sqk "$A" "SELECT 'ssid.rows.type_non_integer: '||count(*) FROM ssid WHERE typeof(type)<>'integer';"
        if [ -n "$AK" ]; then
            sqk "$A" "SELECT 'ssid.distinct_ap_keys(type 5,8): '||count(DISTINCT $AK) FROM ssid WHERE type IN (5,8);"
            sqk "$A" "SELECT 'ssid.ap_rows_per_key(type 5,8): max='||ifnull(max(c),0)||' keys_with_more_than_one_row='||coalesce(sum(c>1),0) FROM (SELECT count(*) AS c FROM ssid WHERE type IN (5,8) AND $AK IS NOT NULL GROUP BY $AK);"
            sqk "$A" "SELECT 'ssid.ap_key_ssid_pairs(type 5,8): '||count(*) FROM (SELECT DISTINCT $AK, ssid FROM ssid WHERE type IN (5,8));"
        fi
        if hascol "$COLS_ssid" wifi_device; then
            sqk "$A" "SELECT 'ssid.distinct_probing_devices(type 4, count only): '||count(DISTINCT wifi_device) FROM ssid WHERE type=4;"
        elif hascol "$COLS_ssid" stamac; then
            sqk "$A" "SELECT 'ssid.distinct_probing_devices(type 4, count only): '||count(DISTINCT stamac) FROM ssid WHERE type=4;"
        fi
    fi
    if hascol "$COLS_ssid" scan; then sqk "$A" "SELECT 'ssid.distinct_scan_values: '||count(DISTINCT scan) FROM ssid;"; fi
    if hascol "$COLS_ssid" hash; then sqk "$A" "SELECT 'ssid.hash: distinct='||count(DISTINCT hash)||' rows='||count(*) FROM ssid;"; fi
    V1_BASE=""; V1_TXT=""
    if hascol "$COLS_ssid" time; then
        V1_BASE=$(sq "$A" "SELECT 'ssid.time: n='||count(*)||' min='||ifnull(CAST(min(time) AS INTEGER),'n/a')||' max='||ifnull(CAST(max(time) AS INTEGER),'n/a')||' distinct='||count(DISTINCT time)||' scale='||CASE WHEN count(*)=0 THEN 'n/a' WHEN min(time)>=946684800 AND max(time)<=4102444800 THEN 'unix-seconds-plausible' WHEN min(time)>=946684800000 AND max(time)<=4102444800000 THEN 'unix-milliseconds-plausible' ELSE 'not-unix-epoch' END||' device_now_minus_max_s='||CASE WHEN count(*)>0 AND min(time)>=946684800 AND max(time)<=4102444800 THEN ($NOW_A - CAST(max(time) AS INTEGER)) ELSE 'n/a' END||' non_numeric='||(SELECT count(*) FROM ssid WHERE typeof(time) NOT IN ('integer','real')) FROM ssid WHERE typeof(time) IN ('integer','real');")
        say "$V1_BASE"
        if hascol "$COLS_ssid" type; then
            sqk "$A" "SELECT 'ssid.time_by_type: type_'||type||' n='||count(*)||' min='||CAST(min(time) AS INTEGER)||' max='||CAST(max(time) AS INTEGER) FROM ssid WHERE typeof(type)='integer' AND typeof(time) IN ('integer','real') GROUP BY type ORDER BY type;"
        fi
        if [ -n "$AK" ]; then
            sqk "$A" "SELECT 'ssid.ap_age_buckets(distinct keys, seconds before the newest row, cumulative): le60='||count(DISTINCT CASE WHEN time>=mx-60 THEN $AK END)||' le300='||count(DISTINCT CASE WHEN time>=mx-300 THEN $AK END)||' le900='||count(DISTINCT CASE WHEN time>=mx-900 THEN $AK END)||' le3600='||count(DISTINCT CASE WHEN time>=mx-3600 THEN $AK END)||' all='||count(DISTINCT $AK) FROM ssid, (SELECT max(time) AS mx FROM ssid WHERE typeof(time) IN ('integer','real')) WHERE $TP typeof(time) IN ('integer','real') AND $AK IS NOT NULL AND $AK<>'';"
        fi
    fi
    flush

    # -- time semantics across the two copies (upsert vs append) and the mtime of the live file
    if [ "$HAVE_B" -eq 1 ]; then
        KEY=rowid; KEYN=rowid
        if hascol "$COLS_ssid" hash; then
            case " $PK_ssid " in *" hash "*) KEY="hash"; KEYN="hash (primary key)" ;; *) KEYN="rowid (hash is not a primary key)" ;; esac
        fi
        _cmp=""
        for _c in time signal; do if hascol "$COLS_ssid" "$_c"; then _cmp="$_cmp $_c"; fi; done
        kv diff.join_key "ssid: $KEYN"
        # extra column: rows new in copy b whose AP key (bssid/apmac, AP rows only) copy a already had. That is what
        # separates "a new row per observation" (append) from "a brand-new AP showed up" (says nothing on append/upsert).
        DIFF_XTRA=""
        if [ -n "$AK" ]; then
            _tx=""; _tz=""
            if hascol "$COLS_ssid" type; then _tx="x.type IN (5,8) AND "; _tz="z.type IN (5,8) AND "; fi
            DIFF_XTRA="||' new_in_b_known_ap_key='||(SELECT count(*) FROM b.ssid x WHERE ${_tx}x.$AK IS NOT NULL AND NOT EXISTS (SELECT 1 FROM main.ssid y WHERE y.$KEY=x.$KEY) AND EXISTS (SELECT 1 FROM main.ssid z WHERE ${_tz}z.$AK=x.$AK))"
        fi
        # shellcheck disable=SC2086   # _cmp is a word list of our own column names
        _dl=$(sq "$A" "$(diff_sql ssid "$KEY" $_cmp)")
        DIFF_XTRA=""
        if [ "$(sqrc)" -ne 0 ]; then say "note: diff query failed: $(sqerr)"; _dl=""; fi
        if [ -n "$_dl" ]; then say "$_dl"; fi
        _fm=no; if [ -n "$MT_A" ] && [ "$MT_A" != "$MT_B" ]; then _fm=yes; fi
        kv diff.live_file_mtime "a=${MT_A:-?} b=${MT_B:-?} moved=$_fm"
        if [ -n "$_dl" ] && hascol "$COLS_ssid" time; then
            _nb=$(tok "$_dl" new_in_b); _gb=$(tok "$_dl" gone_in_b); _tu=$(tok "$_dl" time_up); _td=$(tok "$_dl" time_down)
            _ra=$(tok "$_dl" rows_a); _rb=$(tok "$_dl" rows_b); _ma=$(tok "$_dl" max_time_a); _mb=$(tok "$_dl" max_time_b)
            if ! isnum "$_nb"; then _nb=0; fi
            if ! isnum "$_gb"; then _gb=0; fi
            if ! isnum "$_tu"; then _tu=0; fi
            if ! isnum "$_td"; then _td=0; fi
            _ne=$(tok "$_dl" new_in_b_known_ap_key)
            # The hint is built from independent observations, each hedged ("would fit"): a count can suggest a
            # write pattern but never prove it.
            _hint=""
            if [ "$_tu" -gt 0 ]; then hint_add "time was raised on $_tu row(s) present in both copies (would fit an in-place update of time)"; fi
            if [ "$_td" -gt 0 ]; then hint_add "time was lowered on $_td row(s) present in both copies (not what a running last-seen time does; a clock step or a reset would fit)"; fi
            if [ "$_nb" -gt 0 ]; then
                if isnum "$_ne" && [ "$_ne" -gt 0 ]; then hint_add "$_ne new row(s) carry an AP key that copy a already had (would fit a new row per observation; a row key wider than the AP address could look the same)"
                elif isnum "$_ne"; then hint_add "$_nb new row(s), all for AP keys copy a did not have: append vs upsert is NOT decided by that"
                else hint_add "$_nb new row(s) (no AP key column to compare): append vs upsert is NOT decided"; fi
            fi
            if [ "$_gb" -gt 0 ]; then
                if [ "$_nb" -gt 0 ]; then hint_add "$_gb row(s) vanished while others appeared under new keys (delete+insert, or expiry plus new rows; counts alone cannot tell)"
                else hint_add "$_gb row(s) vanished and none appeared (would fit expiry or a delete)"; fi
            fi
            if [ -z "$_hint" ]; then
                if [ "$_ra" = "$_rb" ] && [ "$_ma" = "$_mb" ]; then _hint="no change in row count, row keys, time values or max time between the copies (recon idle, or a cadence slower than the gap)"
                else _hint="row count or max time differ but no per-row change was counted (see the diff line)"; fi
            fi
            _mv=no; if [ -n "$_ma" ] && [ "$_ma" != "$_mb" ]; then _mv=yes; fi
            V1_TXT="gap=$((NOW_B - NOW_A))s ssid rows a=${_ra:-?} b=${_rb:-?} new_in_b=$_nb gone_in_b=$_gb time_raised_in_place=$_tu time_lowered=$_td new_in_b_known_ap_key=${_ne:-n/a} max_time a=${_ma:-?} b=${_mb:-?} moved=$_mv live_file_mtime_moved=$_fm; $_hint"
        fi
    fi
    if [ -n "$V1_TXT" ]; then vset 1 "OBSERVED $V1_TXT"
    elif [ -n "$V1_BASE" ]; then vset 1 "OBSERVED single copy only, so upsert vs append is NOT decided: ${V1_BASE#*: }"
    else vset 1 "NOT-OBSERVABLE the ssid table has no numeric time column, or the comparison failed"; fi
    flush

    # -- freq: bands by numeric range, distinct values, and how channel relates to freq (question: rx frequency?)
    V2_TXT=""
    if hascol "$COLS_ssid" freq; then
        sqk "$A" "$(numstat_sql ssid.freq ssid freq)"
        sqk "$A" "$(band_sql ssid "ap observations" "$TP")"
        if hascol "$COLS_ssid" type; then sqk "$A" "$(band_sql ssid "probe requests" "type=4 AND")"; fi
        if [ -n "$AK" ]; then
            sqk "$A" "SELECT 'ssid.band_distinct_ap_keys: 2.4='||count(DISTINCT CASE WHEN f>=2400 AND f<2500 THEN k END)||' 5='||count(DISTINCT CASE WHEN f>=4900 AND f<5925 THEN k END)||' 6='||count(DISTINCT CASE WHEN f>=5925 AND f<=7125 THEN k END) FROM (SELECT CAST(freq AS INTEGER) AS f, $AK AS k FROM ssid WHERE $TP typeof(freq) IN ('integer','real'));"
        fi
        sq "$A" "SELECT f||'='||n FROM (SELECT CAST(freq AS INTEGER) AS f, count(*) AS n FROM ssid WHERE typeof(freq) IN ('integer','real') GROUP BY f ORDER BY f LIMIT 200);" | awk '{ line = line (line == "" ? "" : " ") $0; if (++c % 10 == 0) { print "ssid.freq_histogram(MHz=rows): " line; line = "" } } END { if (line != "") print "ssid.freq_histogram(MHz=rows): " line }' >> "$OUT"
        if [ "$(sqrc)" -ne 0 ]; then say "note: freq histogram query failed: $(sqerr)"; fi
        if hascol "$COLS_wd" freq; then sqk "$A" "$(band_sql wifi_device "all rows" "")"; fi
        _sixap=$(sq "$A" "SELECT count(*) FROM ssid WHERE $TP typeof(freq) IN ('integer','real') AND CAST(freq AS INTEGER)>=5955 AND CAST(freq AS INTEGER)<=7115;")
        _sixpr=""
        if hascol "$COLS_ssid" type; then _sixpr=$(sq "$A" "SELECT count(*) FROM ssid WHERE type=4 AND typeof(freq) IN ('integer','real') AND CAST(freq AS INTEGER)>=5955 AND CAST(freq AS INTEGER)<=7115;"); fi
        V6_DB="recon.db rows in 5955-7115 MHz: ap_observations=${_sixap:-?} probe_request_observations=${_sixpr:-n/a}"; V6_DB_OK=1
        if hascol "$COLS_ssid" channel; then
            _cv=$(sq "$A" "SELECT 'ssid.channel_vs_freq(ap rows, both numeric): n='||count(*)||' no_channel_derivable_from_freq='||coalesce(sum(dc IS NULL),0)||' agree='||coalesce(sum(dc IS NOT NULL AND ch=dc),0)||' mismatch='||coalesce(sum(dc IS NOT NULL AND ch<>dc),0)||' mismatch_within_4_channels='||coalesce(sum(dc IS NOT NULL AND ch<>dc AND abs(ch-dc)<=4),0) FROM (SELECT ch, CASE WHEN f BETWEEN 2412 AND 2472 THEN (f-2407)/5 WHEN f=2484 THEN 14 WHEN f BETWEEN 5000 AND 5924 THEN (f-5000)/5 WHEN f=5935 THEN 2 WHEN f BETWEEN 5955 AND 7115 THEN (f-5950)/5 END AS dc FROM (SELECT CAST(channel AS INTEGER) AS ch, CAST(freq AS INTEGER) AS f FROM ssid WHERE $TP typeof(freq) IN ('integer','real') AND typeof(channel) IN ('integer','real')));")
            if [ "$(sqrc)" -eq 0 ]; then
                say "$_cv"
                _n=$(tok "$_cv" n); _ag=$(tok "$_cv" agree); _mm=$(tok "$_cv" mismatch); _m4=$(tok "$_cv" mismatch_within_4_channels)
                if isnum "$_mm" && [ "$_mm" -gt 0 ]; then _h="channel and freq disagree on some rows, which would fit freq being the reception frequency and channel the advertised one"
                else _h="no disagreement seen, which cannot tell the two readings apart"; fi
                V2_TXT="ap rows with numeric channel and freq: n=${_n:-?} agree=${_ag:-?} mismatch=${_mm:-?} (within 4 channels ${_m4:-?}); $_h"
            else
                say "note: channel-vs-freq query failed: $(sqerr)"
            fi
        else
            say "note: ssid has no channel column, so freq cannot be compared with an advertised channel"
        fi
    else
        say "note: ssid has no freq column"; V6_DB="ssid has no freq column"
    fi
    if [ -n "$V2_TXT" ]; then vset 2 "OBSERVED $V2_TXT"
    else vset 2 "NOT-OBSERVABLE needs both a numeric channel and a numeric freq column in ssid (see the column lines)"; fi
    flush

    # -- signal / encryption
    if hascol "$COLS_ssid" signal; then
        sqk "$A" "$(numstat_sql ssid.signal ssid signal)"
        sqk "$A" "SELECT 'ssid.signal_typeof: '||typeof(signal)||'='||count(*) FROM ssid GROUP BY typeof(signal);"
        sqk "$A" "SELECT 'ssid.signal_positive_rows: '||count(*) FROM ssid WHERE typeof(signal) IN ('integer','real') AND signal>0;"
    fi
    if hascol "$COLS_wd" signal; then sqk "$A" "$(numstat_sql wifi_device.signal wifi_device signal)"; fi
    if hascol "$COLS_ssid" encryption; then
        sqk "$A" "SELECT 'enc.distinct_integer_values: '||count(DISTINCT encryption)||' non_integer_rows='||(SELECT count(*) FROM ssid WHERE $TP typeof(encryption)<>'integer') FROM ssid WHERE $TP typeof(encryption)='integer';"
        sq "$A" "SELECT 'enc.value: '||encryption||' hex_hi32=0x'||printf('%x',encryption>>32)||' hex_lo32=0x'||printf('%08x',encryption&4294967295)||' rows='||count(*)||' keys='||count(DISTINCT ${AK:-rowid}) FROM ssid WHERE $TP typeof(encryption)='integer' GROUP BY encryption ORDER BY count(*) DESC, encryption LIMIT 40;" > "$T/enc.out"
        if [ "$(sqrc)" -ne 0 ]; then
            sq "$A" "SELECT 'enc.value: '||encryption||' rows='||count(*) FROM ssid WHERE $TP typeof(encryption)='integer' GROUP BY encryption ORDER BY count(*) DESC, encryption LIMIT 40;" > "$T/enc.out"
        fi
        cat "$T/enc.out" >> "$OUT"
    fi
    flush

    # -- wifi_device (clients): counts only; the meaning of packets from the two copies
    V10_TXT=""
    if [ -n "$COLS_wd" ]; then
        sqk "$A" "SELECT 'wifi_device.rows: '||count(*) FROM wifi_device;"
        if hascol "$COLS_wd" mac; then sqk "$A" "SELECT 'wifi_device.distinct_devices(count only): '||count(DISTINCT mac) FROM wifi_device;"; fi
        if hascol "$COLS_wd" time; then sqk "$A" "$(numstat_sql wifi_device.time wifi_device time)"; fi
        if hascol "$COLS_wd" packets; then
            _ps=$(sq "$A" "$(numstat_sql wifi_device.packets wifi_device packets)")
            say "$_ps"
            sqk "$A" "SELECT 'wifi_device.packets_sum_and_zero_rows: sum='||ifnull(CAST(sum(packets) AS INTEGER),'n/a')||' zero_rows='||coalesce(sum(packets=0),0) FROM wifi_device WHERE typeof(packets) IN ('integer','real');"
            V10_TXT="column present: ${_ps#*: }"
            if [ "$HAVE_B" -eq 1 ]; then
                KEYW=rowid
                if hascol "$COLS_wd" hash; then case " $PK_wd " in *" hash "*) KEYW="hash" ;; esac; fi
                _wc=packets
                if hascol "$COLS_wd" time; then _wc="$_wc time"; fi
                if hascol "$COLS_wd" signal; then _wc="$_wc signal"; fi
                # shellcheck disable=SC2086   # _wc is a word list of our own column names
                _wl=$(sq "$A" "$(diff_sql wifi_device "$KEYW" $_wc)")
                if [ "$(sqrc)" -eq 0 ] && [ -n "$_wl" ]; then
                    say "$_wl"
                    _pu=$(tok "$_wl" packets_up); _pd=$(tok "$_wl" packets_down); _wn=$(tok "$_wl" new_in_b); _wr=$(tok "$_wl" rows_a)
                    _tu2=$(tok "$_wl" time_up)
                    if ! isnum "$_pu"; then _pu=0; fi
                    if ! isnum "$_pd"; then _pd=0; fi
                    if [ "$_pd" -gt 0 ]; then _ph="packets fell on some rows present in both copies (does not fit a pure running total)"
                    elif [ "$_pu" -gt 0 ]; then _ph="packets only rose on rows present in both copies (would fit a running total; one gap of two copies cannot prove it)"
                    else _ph="packets did not change on rows present in both copies (idle, or a cadence slower than the gap)"; fi
                    V10_TXT="$V10_TXT; between the copies (${GAP}s) rows_a=${_wr:-?} packets_raised=$_pu packets_lowered=$_pd new_rows=${_wn:-?} time_raised=${_tu2:-?}; $_ph"
                else
                    say "note: wifi_device diff failed: $(sqerr)"
                fi
            fi
        fi
    fi
    if [ -n "$V10_TXT" ]; then vset 10 "OBSERVED wifi_device.packets $V10_TXT"
    else vset 10 "NOT-OBSERVABLE this recon.db has no wifi_device.packets column"; fi
    flush
}

# ============================================================================================ 4. radio
sect_radio() {
    heading 4 "radio (interface names, types, channel numbers, driver names; no addresses, no SSIDs)"
    V5_TXT=""
    if ! have iw; then
        kv iw absent
        vset 5 "NOT-OBSERVABLE iw is not installed"
        V6_PHY="iw is not installed"; V6_PHY_OK=0
        finish_v6
        return 0
    fi
    iw dev > "$T/iwdev.txt" 2>&1 < /dev/null; _rc=$?
    if [ "$_rc" -ne 0 ]; then kv iw.dev "failed (exit $_rc): $(head -n 1 "$T/iwdev.txt" | clean | cut -c1-100)"; fi
    awk '
        function emit() { if (name != "") printf "%s %s %s %s\n", name, phy, type, ch }
        /^phy#/ { emit(); name = ""; phy = "phy" substr($1, 5); next }
        $1 == "Interface" { emit(); name = $2; type = "-"; ch = "-"; next }
        /^[[:space:]]*Unnamed/ { emit(); name = ""; next }
        $1 == "type" { type = $2; next }
        $1 == "channel" { ch = $2; next }
        END { emit() }
    ' "$T/iwdev.txt" > "$T/ifaces"
    MON=$(awk '$1 == "wlan1mon" { print $1; exit }' "$T/ifaces")
    if [ -z "$MON" ]; then MON=$(awk '$3 == "monitor" { print $1; exit }' "$T/ifaces"); fi
    MONPHY=""
    if [ -n "$MON" ]; then MONPHY=$(awk -v m="$MON" '$1 == m { print $2; exit }' "$T/ifaces"); fi
    _n=0
    while read -r _if _phy _ty _ch; do
        case $_if in ''|*[!A-Za-z0-9_.-]*) continue ;; esac
        _n=$((_n + 1))
        _d=$(readlink "$RF/sys/class/net/$_if/device/driver" 2>/dev/null) || _d=""; _d=${_d##*/}
        _m=$(readlink "$RF/sys/class/net/$_if/device/driver/module" 2>/dev/null) || _m=""; _m=${_m##*/}
        _pl=$(readlink "$RF/sys/class/net/$_if/phy80211" 2>/dev/null) || _pl=""; _pl=${_pl##*/}
        kv "iface.$_if" "phy=${_phy:--} type=${_ty:--} channel=${_ch:--} driver=${_d:--} module=${_m:--} sysfs_phy=${_pl:--}"
    done < "$T/ifaces"
    kv iface.count "$_n"
    if [ -z "$MON" ]; then
        kv monitor.interface "none (no wlan1mon and no interface of type monitor)"
    else
        kv monitor.interface "$MON (phy ${MONPHY:--})"
        iw dev "$MON" info > "$T/iwinfo.txt" 2>&1 < /dev/null; _irc=$?
        if [ "$_irc" -eq 0 ]; then
            awk '$1 == "ifindex" || $1 == "type" || $1 == "wiphy" || $1 == "channel" || $1 == "txpower" { l = $0; sub(/^[[:space:]]+/, "", l); print "monitor.info: " l }' "$T/iwinfo.txt" >> "$OUT"
        else
            kv monitor.info "iw dev $MON info failed (exit $_irc): $(head -n 1 "$T/iwinfo.txt" | clean | cut -c1-100)"
        fi
        iw dev "$MON" survey dump > "$T/survey.txt" 2>&1 < /dev/null; _src=$?
        SURV_N=0; SURV_TX=0
        if [ "$_src" -eq 0 ]; then
            awk '
                function out() { if (f != "") printf "survey: %s MHz%s noise=%s dBm active=%s busy=%s rx=%s tx=%s (ms)\n", f, iu, noise, act, busy, rx, tx }
                $1 == "frequency:" { out(); f = $2; iu = ($0 ~ /in use/) ? " [in use]" : ""; noise = "-"; act = "-"; busy = "-"; rx = "-"; tx = "-"; next }
                $1 == "noise:" { noise = $2; next }
                $1 == "channel" && $2 == "active" { act = $4; next }
                $1 == "channel" && $2 == "busy" { busy = $4; next }
                $1 == "channel" && $2 == "receive" { rx = $4; next }
                $1 == "channel" && $2 == "transmit" { tx = $4; next }
                END { out() }
            ' "$T/survey.txt" > "$T/survey.parsed"
            SURV_N=$(wc -l < "$T/survey.parsed" | tr -d ' ')
            SURV_TX=$(awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^tx=/) { v = substr($i, 4); if (v ~ /^[0-9]+$/) s += v } } END { print s + 0 }' "$T/survey.parsed")
            kv survey.entries "$SURV_N (sum of channel transmit time on $MON: ${SURV_TX} ms)"
            head -n 60 "$T/survey.parsed" >> "$OUT"
        else
            kv survey "iw dev $MON survey dump failed (exit $_src): $(head -n 1 "$T/survey.txt" | clean | cut -c1-100)"
        fi
        _drv=$(readlink "$RF/sys/class/net/$MON/device/driver" 2>/dev/null) || _drv=""; _drv=${_drv##*/}
        if [ -z "$_drv" ] && [ -n "$MONPHY" ]; then
            _drv=$(readlink "$RF/sys/class/ieee80211/$MONPHY/device/driver" 2>/dev/null) || _drv=""; _drv=${_drv##*/}
        fi
        kv monitor.driver "${_drv:-not readable from sysfs}"
        if [ "$_src" -eq 0 ]; then _sv="survey entries=$SURV_N tx_time_ms_sum=$SURV_TX"; else _sv="survey dump failed (exit $_src)"; fi
        V5_TXT="driver=${_drv:-unreadable} phy=${MONPHY:--} monitor_if=$MON; $_sv"
    fi
    if [ -n "$V5_TXT" ]; then vset 5 "OBSERVED $V5_TXT"; else vset 5 "NOT-OBSERVABLE iw dev listed no wlan1mon and no interface of type monitor"; fi
    flush
    # 6 GHz: frequencies (5955-7115 MHz) the wiphy lists in iw phy <phy> info, per phy; "enabled" = not marked disabled
    awk '{ print $2 }' "$T/ifaces" | sort -u > "$T/phys"
    V6_PHY="no phy info could be read"; V6_PHY_OK=0; _v6all=""; _v6mon=""
    while read -r _phy; do
        case $_phy in ''|phy|*[!A-Za-z0-9_]*) continue ;; esac
        iw phy "$_phy" info > "$T/phyinfo.txt" 2>&1 < /dev/null; _prc=$?
        if [ "$_prc" -ne 0 ]; then kv "phy.$_phy" "iw phy $_phy info failed (exit $_prc): $(head -n 1 "$T/phyinfo.txt" | clean | cut -c1-80)"; continue; fi
        _cnt=$(awk '
            /^[[:space:]]*\* [0-9]+(\.[0-9]+)? MHz/ {
                f = $2 + 0; d = ($0 ~ /disabled/) ? 1 : 0
                if (f >= 2400 && f < 2500) { a++; if (!d) ae++ }
                else if (f >= 4900 && f < 5925) { b++; if (!d) be++ }
                else if (f >= 5955 && f <= 7115) { c++; if (!d) ce++ }
            }
            END { printf "%d %d %d %d %d %d", a, ae, b, be, c, ce }' "$T/phyinfo.txt")
        # shellcheck disable=SC2086   # six integers from awk
        set -- $_cnt
        kv "phy.$_phy" "listed frequencies (not-disabled/total): 2.4GHz=$2/$1 5GHz=$4/$3 6GHz_5955_7115=$6/$5"
        _v6all="$_v6all $_phy=$6/$5"; V6_PHY_OK=1
        if [ "$_phy" = "$MONPHY" ]; then _v6mon="the monitor phy $_phy lists $5 frequencies in 5955-7115 MHz, $6 of them not marked disabled; "; fi
    done < "$T/phys"
    if [ "$V6_PHY_OK" -eq 1 ]; then V6_PHY="${_v6mon}per phy (not-disabled/total in 5955-7115 MHz):$_v6all"; fi
    finish_v6
    flush
}
finish_v6() {
    if [ "$V6_PHY_OK" -eq 1 ] || [ "$V6_DB_OK" -eq 1 ]; then vset 6 "OBSERVED capability: $V6_PHY; reception evidence: $V6_DB"
    else vset 6 "NOT-OBSERVABLE capability: $V6_PHY; reception evidence: $V6_DB"; fi
}

# ============================================================================================ 5. oui.txt
sect_oui() {
    heading 5 "/lib/hak5/oui.txt"
    OUIF=$RF/lib/hak5/oui.txt
    if [ ! -f "$OUIF" ]; then
        kv oui.file "absent ($OUIF)"
        vset 8 "OBSERVED the file does not exist at /lib/hak5/oui.txt"
        return 0
    fi
    # shellcheck disable=SC2012   # ls -l is the requested form (size, date, path) for a fixed path of ours
    _ls=$(ls -lL "$OUIF" 2>/dev/null | clean | cut -c1-120)
    _n=$(wc -l < "$OUIF" 2>/dev/null | tr -d ' ')
    kv oui.file "$_ls"
    kv oui.lines "${_n:-?}"
    head -n 3 "$OUIF" 2>/dev/null | clean | awk '{ gsub(/\t/, "<TAB>"); print "oui.first3: " substr($0, 1, 100) }' >> "$OUT"
    _hex=$(grep -c '(hex)' "$OUIF" 2>/dev/null); _b16=$(grep -c '(base 16)' "$OUIF" 2>/dev/null)
    _nm=$(grep -Ec '^[0-9A-Fa-f]{6}[[:space:]]+[^[:space:]]' "$OUIF" 2>/dev/null)
    _co=$(grep -Ec '^[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}' "$OUIF" 2>/dev/null)
    _da=$(grep -Ec '^[0-9A-Fa-f]{2}-[0-9A-Fa-f]{2}-[0-9A-Fa-f]{2}' "$OUIF" 2>/dev/null)
    _cm=$(grep -c '^#' "$OUIF" 2>/dev/null); _cr=$(grep -c "$(printf '\r')" "$OUIF" 2>/dev/null)
    _tb=$(grep -c "$(printf '\t')" "$OUIF" 2>/dev/null)
    kv oui.shapes "ieee_hex_lines=$_hex ieee_base16_lines=$_b16 six_hex_then_text=$_nm colon_form=$_co dash_form=$_da comment_lines=$_cm crlf_lines=$_cr tab_lines=$_tb"
    _l1=$(head -n 1 "$OUIF" 2>/dev/null | clean | awk '{ gsub(/\t/, "<TAB>"); print substr($0, 1, 70) }')
    vset 8 "OBSERVED exists, lines=${_n:-?}, first line '$_l1'; line shapes: ieee_hex=$_hex ieee_base16=$_b16 six_hex_then_text=$_nm colon=$_co dash=$_da comments=$_cm"
    flush
}

# ============================================================================================ 6. own-BSSID / SSID-pool candidates
# Existence, kind and size only (ls -l fields 1 and 5), plus the path with every name outside WORDS withheld
# (rule P9: an own-BSSID / SSID-pool file may well carry an SSID or a BSSID in its name). The content of these files
# is never read, never counted, never printed.
CANDN=0; CANDW=0
cand() {   # cand PATH: report what exists at PATH
    [ -e "$1" ] || [ -L "$1" ] || return 0
    if grep -qxF -- "$1" "$T/cand.seen" 2>/dev/null; then return 0; fi
    printf '%s\n' "$1" >> "$T/cand.seen"
    # shellcheck disable=SC2012   # only ls -l field 1 (type) and 5 (size) are used; the name is never taken from its output
    _o=$(ls -ldL "$1" 2>/dev/null) || _o=$(ls -ld "$1" 2>/dev/null) || _o=""
    _k=$(printf '%s\n' "$_o" | awk 'NR == 1 { k = substr($1, 1, 1); if (k == "-") print "file"; else if (k == "d") print "dir"; else if (k == "l") print "symlink"; else print "other" }')
    _z=$(printf '%s\n' "$_o" | awk 'NR == 1 { print $5 }')
    if ! isnum "$_z"; then _z="?"; fi
    _cp=$(safe_path "$1")
    case $_cp in *"<withheld>"*) CANDW=$((CANDW + 1)) ;; esac
    say "candidate: ${_k:-?} size_bytes=$_z path=$_cp"
    CANDN=$((CANDN + 1))
}
sect_cands() {
    heading 6 "candidate own-BSSID / SSID-pool files (existence, kind, size; content is never read; unlisted names withheld)"
    : > "$T/cand.seen"
    CANDN=0; CANDW=0
    for _p in "$RF/etc/pineapple" "$RF/etc/config/pineap"* "$RF/etc/config/pineapd" "$RF/root/pineap"* "$RF/root/.pineap"* \
              "$RF/root/"*ssid* "$RF/root/"*bssid* "$RF/root/"*pool* "$RF/mmc/root/"*ssid* "$RF/mmc/root/"*bssid* "$RF/mmc/root/"*pool*; do
        cand "$_p"
        if [ -d "$_p" ]; then
            case $_p in "$RF/etc/"*) for _q in "$_p"/*; do cand "$_q"; done ;; esac
        fi
    done
    find "$RF/etc" "$RF/lib/hak5" -maxdepth 3 \( -name '*ssid*' -o -name '*SSID*' -o -name '*bssid*' -o -name '*pool*' -o -name '*pineap*' \) 2>/dev/null | head -n 40 > "$T/found"
    while IFS= read -r _f; do cand "$_f"; done < "$T/found"
    kv cand.count "$CANDN path(s) found, $CANDW of them with a withheld name; nothing was opened"
    if [ "$CANDW" -gt 0 ]; then say "note: <withheld> = a name outside the word list of this script (it may be an SSID or a BSSID, rule P9); run ls on the patterns yourself on the device to see it"; fi
    if [ "$CANDN" -gt 0 ]; then vset 9 "OBSERVED $CANDN candidate path(s) exist, $CANDW with a name withheld (section 6; kind and size only, content not read, so what they hold is not established)"
    else vset 9 "OBSERVED none of the guessed candidate paths exist (etc/pineapple*, etc/config/pineap*, root/*ssid*|*bssid*|*pool*, name matches under etc and lib/hak5); the real file, if any, is elsewhere"; fi
    flush
}

# ============================================================================================ 7. platform
sect_platform() {
    heading 7 "platform"
    if [ -r "$RF/etc/openwrt_release" ]; then
        grep '^DISTRIB_' "$RF/etc/openwrt_release" 2>/dev/null | clean | cut -c1-120 | sed 's/^/openwrt_release: /' >> "$OUT"
    else
        kv openwrt_release "not readable"
    fi
    kv uname "$(uname -m 2>/dev/null) $(uname -r 2>/dev/null)"
    kv device.clock_epoch "$(date +%s 2>/dev/null)"
    df -kP "$RF/root" "$RF/tmp" 2>&1 | clean | cut -c1-120 | sed 's/^/df: /' >> "$OUT"
    LOOT=$RF/root/loot
    if [ -d "$LOOT" ]; then
        # Rule P9: a directory name can be an SSID or a BSSID, so a name is printed only when it is on a short fixed
        # list (the Starchorus directory and the usual capture directory); every other directory is only counted, and
        # plain files are counted by extension without their names.
        : > "$T/loot.dirs"; _nd=0; _wd=0; _nf=0; _pc=0; _js=0; _ot=0
        ls -1A "$LOOT" 2>/dev/null > "$T/loot.ls"
        while IFS= read -r _e; do
            [ -n "$_e" ] || continue
            if [ -d "$LOOT/$_e" ]; then
                _nd=$((_nd + 1))
                case $_e in
                    starchorus|handshakes) printf '%s\n' "$_e" >> "$T/loot.dirs" ;;
                    *) _wd=$((_wd + 1)) ;;
                esac
            else
                _nf=$((_nf + 1))
                case $_e in
                    *.pcap|*.pcapng|*.cap|*.22000|*.hccapx) _pc=$((_pc + 1)) ;;
                    *.json|*.txt|*.log|*.csv) _js=$((_js + 1)) ;;
                    *) _ot=$((_ot + 1)) ;;
                esac
            fi
        done < "$T/loot.ls"
        kv loot.directories "$_nd ($_wd with a name outside the fixed list starchorus/handshakes; those names are withheld)"
        while IFS= read -r _e; do say "loot.dir: $_e"; done < "$T/loot.dirs"
        kv loot.plain_files "$_nf (capture-type names $_pc, json/txt/log/csv $_js, other $_ot; file names are not printed; nothing inside was opened)"
    else
        kv loot "absent ($LOOT)"
    fi
    flush
}

# ============================================================================================ 8. installed Starchorus
sect_starchorus() {
    heading 8 "installed Starchorus (default /root/loot/starchorus)"
    INST=${STARCHORUS_PROBE_INSTALL_DIR:-$RF/root/loot/starchorus}
    COLL=$INST/starchorus-collect.sh
    PAG=""
    for _c in "$INST/starchorus-display.sh" "$RF/root/payloads/user/reconnaissance/starchorus/starchorus-display.sh"; do
        if [ -f "$_c" ]; then
            kv display.file "$_c ($(grep '^# Version:' "$_c" 2>/dev/null | head -n 1 | clean | cut -c1-40))"
            if [ -z "$PAG" ]; then PAG=$_c; fi
        fi
    done
    if [ ! -f "$COLL" ]; then kv installed "no ($COLL not found)"; return 0; fi
    kv collector.file "$COLL ($(grep '^# Version:' "$COLL" 2>/dev/null | head -n 1 | clean | cut -c1-40))"
    # --status only reads the pidfiles and prints; it never starts or stops anything
    STARCHORUS_OUTDIR="$INST" sh "$COLL" --status > "$T/status.txt" 2>&1 < /dev/null
    clean < "$T/status.txt" | cut -c1-160 | sed 's/^/collector.status: /' >> "$OUT"
    if [ "${STARCHORUS_PROBE_SKIP_SELFTEST:-0}" = 1 ]; then
        kv collector.selftest "skipped (STARCHORUS_PROBE_SKIP_SELFTEST=1)"
        flush
        return 0
    fi
    # own workspace: everything the selftests write lands in the private dir. The selftests call a template-less
    # `mktemp -d`; BSD mktemp ignores TMPDIR for that, so a tiny mktemp wrapper first in PATH pins it to $T/st/tmp.
    mkdir -p "$T/st/tmp" "$T/st/out" "$T/st/bin"
    cat > "$T/st/bin/mktemp" <<MKTEMP_WRAP
#!/bin/sh
PATH="${PATH:-/usr/bin:/bin}"
if [ \$# -eq 0 ]; then exec mktemp "$T/st/tmp/tmp.XXXXXX"; fi
if [ \$# -eq 1 ] && [ "\$1" = -d ]; then exec mktemp -d "$T/st/tmp/tmp.XXXXXX"; fi
exec mktemp "\$@"
MKTEMP_WRAP
    chmod 700 "$T/st/bin/mktemp"
    say "collector.selftest: running (limit 240 s) ..."
    flush
    run_limited 240 "$T/st/collector.txt" env PATH="$T/st/bin:${PATH:-/usr/bin:/bin}" TMPDIR="$T/st/tmp" STARCHORUS_OUTDIR="$T/st/out" STARCHORUS_CAPDIR="$T/st/out/cap" STARCHORUS_PIDDIR="$T/st/out" sh "$COLL" --selftest
    _p=$(grep -c 'PASS:' "$T/st/collector.txt"); _f=$(grep -c 'FAIL:' "$T/st/collector.txt")
    _to=""; if [ "$RL_RC" -eq 124 ]; then _to=" (timed out)"; fi
    kv collector.selftest "exit=$RL_RC$_to pass_lines=$_p fail_lines=$_f"
    grep 'FAIL:' "$T/st/collector.txt" | clean | cut -c1-160 | head -n 20 | sed 's/^/collector.selftest.fail: /' >> "$OUT"
    tail -n 1 "$T/st/collector.txt" | clean | cut -c1-160 | sed 's/^/collector.selftest.last: /' >> "$OUT"
    # the display script's --selftest only when the installed display script really has that flag in code (not just a comment)
    if [ -n "$PAG" ]; then
        if grep -v '^[[:space:]]*#' "$PAG" | grep -q -e '--selftest'; then
            run_limited 90 "$T/st/display.txt" env PATH="$T/st/bin:${PATH:-/usr/bin:/bin}" TMPDIR="$T/st/tmp" STARCHORUS_DIR="$INST" sh "$PAG" --selftest
            _p=$(grep -c 'PASS:' "$T/st/display.txt"); _f=$(grep -c 'FAIL:' "$T/st/display.txt")
            _to=""; if [ "$RL_RC" -eq 124 ]; then _to=" (timed out)"; fi
            kv display.selftest "exit=$RL_RC$_to pass_lines=$_p fail_lines=$_f"
            grep 'FAIL:' "$T/st/display.txt" | clean | cut -c1-160 | head -n 20 | sed 's/^/display.selftest.fail: /' >> "$OUT"
            tail -n 1 "$T/st/display.txt" | clean | cut -c1-160 | sed 's/^/display.selftest.last: /' >> "$OUT"
        else
            kv display.selftest "the installed display script has no --selftest in code; not run"
        fi
    fi
    flush
}

# ============================================================================================ summary
vname() {
    case $1 in
        1) echo recon-db-time-semantics ;;
        2) echo freq-is-rx-frequency ;;
        3) echo apcli-recon-monitor-read-only ;;
        4) echo examine-side-effects-reset ;;
        5) echo radio-driver-and-iw-survey ;;
        6) echo 6ghz-reception ;;
        7) echo deauth-detector-recon-only ;;
        8) echo oui-txt-format ;;
        9) echo own-bssid-ssid-pool-file ;;
        10) echo wifi-device-packets-meaning ;;
        11) echo multi-bssid-undercount ;;
        12) echo jq-endswith-until-index-slicing-tostring ;;
    esac
}

main() {
    T=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-probe.XXXXXX" 2>/dev/null) || { echo "device-probe: cannot create a private temp dir under ${TMPDIR:-/tmp}" >&2; return 2; }
    OUT=$T/out; : > "$OUT"
    say "# Starchorus device-probe 0.1.1: read-only, passive; observations, not facts"
    say "# started (device clock, UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)"
    vset 3 "NOT-OBSERVABLE needs the AP-service command line (its recon and monitor sub-commands), which this read-only probe never calls; recon.db tables and columns are in section 3"
    vset 4 "NOT-OBSERVABLE needs the radio-locking examine command, which changes radio state; not part of the read-only contract"
    vset 7 "NOT-OBSERVABLE needs a real deauth event heard by the alert runtime; there is no read-only way to observe it"
    vset 11 "NOT-OBSERVABLE counting non-transmitted Multiple-BSSID profiles needs beacon information-element parsing or a reference capture, which this read-only probe does not do (the recon.db columns are listed in section 3)"
    sect_jq
    sect_tools
    sect_recon
    sect_radio
    sect_oui
    sect_cands
    sect_platform
    sect_starchorus
    flush
    printf '\n== summary ==\n'
    _i=1
    while [ "$_i" -le 12 ]; do
        say "V-$_i $(vname "$_i"): $(cat "$T/v.$_i" 2>/dev/null || echo 'NOT-OBSERVABLE the section that answers it did not run')"
        _i=$((_i + 1))
    done
    flush
    printf '%s\n' "privacy-filter: $RED output line(s) held a MAC-shaped string; it was replaced by <mac-withheld>"
    printf '%s\n' "temp dir $T is removed on exit"
    return 0
}

main < /dev/null
exit $?
