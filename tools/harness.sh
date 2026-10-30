#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/harness.sh -- shared helpers of the Starchorus browser harness (docs/architecture.md §11.0).
# SOURCE it, do not run it:  . tools/harness.sh     (from the repo, or set STARCHORUS_ROOT=/path/to/repo)
# Defines R (repo root) F (fixtures) H (page) QS_SEQ STARCHORUS_FIXED EV_TEXT EV_THAW and the functions
# below. Apart from those names nothing in a caller's shell is touched: every function-internal variable
# uses the reserved prefixes _rq_* (runq) / _rs_* (runseq) / _sc_* (root probe) / _pf_* (preflight) / _tm_* (timing), so a drop-in may keep its
# own f/q/p/i/rc/T/PORT/SRV across a call (regress.sh has a row for it).
#   runq FIXTURE|demo "QUERY" PREFIX [--delay S] [cdp args]  one headless run with URL query -> PREFIX.json (and PREFIX.png when RUNQ_SHOT=1;
#                                                 no row reads a screenshot, so by default none is taken: RUNQ_SHOT unset or 0)
#                                                 --ready [EXPR] among the cdp args: the run goes on as soon as the page is ready (bare: fonts
#                                                 loaded, STARCHORUS there, a frame painted) and --wait becomes the ceiling; for sites that need
#                                                 the page booted, not time passed (an animation, a poll count, fps keep the plain wait)
#   runseq FIXTURE|demo PREFIX [cdp args]         runq with QS_SEQ (?poll=0&spin=0&intro=0&fixed=…), no fps pass
#   chk PREFIX.json [demo]                        exceptions / real console errors -> exit 1
#   secof LINE                                    section number (==== NN ====) of a line of the page
#   evals PREFIX.json | evalv PREFIX.json N       all eval values (JSON, one per line) | the N-th (strings raw)
#   ev3 'EXPR' [ms] | ev3eq 'EXPR' [ms]           JS source: EXPR in all three themes -> JSON map | true
#   nomatch PREFIX.json N 'REGEX'                 exit 0 iff string eval N has no (case-insensitive) match
#   sec_slice NN MM [MIN]                         page lines from marker "==== NN " through "==== MM " -> stdout;
#                                                 anchored: each marker exactly once, MM after NN, >= MIN lines
#                                                 (default 1), else a message on stderr and return 2 (never an empty
#                                                 range that a `grep -c` row would read as "0 hits = PASS")
#   sec_grepc NN MM MIN 'BRE'                     count of matching lines inside that slice; return 2 on a broken anchor
#   selftest_verdict FILE MIN [HAVE_SQLITE3] [ALLOW_NO_SQLITE]
#                                                 judge a saved `starchorus-collect.sh --selftest` output -> label on stdout,
#                                                 exit 0 iff ALL PASS, N >= MIN, no "SKIP: recon.db tests", sqlite3 present;
#                                                 exit 3 = NOT COVERED (sqlite3 absent, ALLOW_NO_SQLITE=1, what ran says ALL PASS)
#   preflight TOOL...                             is every tool there? one "MISSING: TOOL" line on stderr per absent tool, return 2 (the
#                                                 callers exit 2 instead of running rows that would only fail as a follow-up). "chrome" =
#                                                 what cdp.py finds; "sqlite3" is the one deliberate switch: absent + ALLOW_NO_SQLITE=1
#                                                 passes, and the collector selftest row then says NOT COVERED (see selftest_verdict)
#   path_farm DIR TOOL...                         DIR = symlinks to every tool of the current PATH except TOOL... (probe: "PATH without jq")
#   PF_TOOLS_QUICK / PF_TOOLS_FULL                the tools tools/quick.sh (T1) / tools/regress.sh (T2) need; each list was verified by a
#                                                 run with a PATH that holds nothing else (see tools/README.md)
#   tm_begin FILE | tm_lap LABEL | tm_total       wall time in whole seconds per phase/drop-in into FILE ("LABEL  N s"), then the sum
#   tm_check FILE NAME...                         judge such a file: every drop-in NAME once with an integer, and a total; label on stdout
#   pycompile FILE...                             syntax-check python files with compile(); writes no __pycache__
#   net_verdict REPORT.json LOG|- MIN_POLLS       judge the requests a run REALLY made (cdp.py "requests", CDP Network):
#                                                 one label line "N requests: ..." on stdout, exit 0 iff every request is a
#                                                 GET to the page's own origin on a path of NET_PATHS (or a data: URL), the page,
#                                                 >= MIN_POLLS starchorus.json polls and >= 2 requests were seen, and (LOG = a
#                                                 verify.sh PREFIX.server.log) the server saw only GET on those paths too
#   fuzz_verdict REPORT.json MODE MIN_M MIN_ANCHORS OPENFILE|-
#                                                 judge a run of tools/evals/ingest-fuzz.js (two evals: "main", "big"): one label
#                                                 line on stdout. MODE run: exit 0 iff all seven classes ran, >= MIN_M mutants, every
#                                                 sink driven, >= MIN_ANCHORS positive anchors, and the findings are EXACTLY those
#                                                 OPENFILE lists ("glob|owner|cause" per line: a new finding is red, a listed one that
#                                                 is gone is red too: "please remove"). MODE probe (the sensor's own proof): exit 0
#                                                 iff the run is RED for the two planted faults (unescaped SSID, null entries not
#                                                 skipped) and for nothing else
#   order_verdict REPORT.json MODE MIN_LISTS OPENFILE|-
#                                                 judge a run of tools/evals/order-invariance.js (one eval): one label line on stdout.
#                                                 MODE run: exit 0 iff every fixture ran its permutations, >= MIN_LISTS lists (n >= 5) were
#                                                 shuffled and each moved in >= 9 of 10 seeds (the mixer mixes), and the findings are EXACTLY
#                                                 those OPENFILE lists ("glob|owner|cause"; new = red, listed but gone = red "please remove").
#                                                 MODE probe (the sensor's own proof, page copy without a sort): exit 0 iff the run is RED
#                                                 because the layout followed the input order (>= 2 fixtures) and for nothing else.
#                                                 MODE mixerprobe (second eval of the same run, "mixer" mode with an identity shuffle): exit 0
#                                                 iff no list counts as moved (the mixer check is RED, and only it)
# Dev machine only (POSIX sh + python3 + Chrome); nothing here runs on the device or sends anything.
# shellcheck disable=SC2034   # F/H/QS_SEQ/EV_TEXT/EV_THAW are used by the scripts that source this file

_sc_root_ok() { [ -f "$1/starchorus.html" ] && [ -f "$1/tools/cdp.py" ]; }
R=""
# 1. STARCHORUS_ROOT  2. the directory above the sourcing script (tools/regress.sh, tools/passivity-check.sh)
# 3. the git top level of $PWD  4. $PWD      ("--": a login shell's $0 is "-bash"/"-zsh")
for _sc_c in "${STARCHORUS_ROOT:-}" "$(cd "$(dirname -- "$0")/.." 2>/dev/null && pwd -P)" \
             "$(git rev-parse --show-toplevel 2>/dev/null)" "$PWD"; do
  if [ -n "$_sc_c" ] && _sc_root_ok "$_sc_c"; then R=$_sc_c; break; fi
done
unset _sc_c
if [ -z "$R" ]; then
  echo "harness: repo root not found (run inside the repo or set STARCHORUS_ROOT)" >&2
  # shellcheck disable=SC2317   # exit is reached when the file is executed instead of sourced
  return 2 2>/dev/null || exit 2
fi
F="$R/tests/fixtures"
H="$R/starchorus.html"
STARCHORUS_FIXED=${STARCHORUS_FIXED:-1789300000}
QS_SEQ="?poll=0&spin=0&intro=0&fixed=$STARCHORUS_FIXED"
mkdir -p "$R/out"

runq() {   # runq FIXTURE|demo "QUERY" PREFIX [--delay S] [cdp-Args…] → PREFIX.json, and PREFIX.png with RUNQ_SHOT=1; Exit = cdp.py
  # --delay S (must come first, default 0) holds every starchorus.json response back S seconds -- the only way
  # to observe code that runs before the first poll answers (D13 logon gate). S=0 keeps the plain server.
  # RUNQ_SHOT=1 also writes the screenshot PREFIX.png (evidence for the eye; no row reads it, and taking it costs 0.2 to 0.4 s and some 700 kB a run;
  # without it a run also ends that much sooner after its last step, so late console messages and requests have a window shorter by about as much).
  # A run that fails before cdp.py starts (mktemp, either cp: a renamed fixture) must not leave the previous run's PREFIX.json or PREFIX.png
  # behind: callers discard runq's status and read the report, so a stale file would be judged as if this run had happened. A missing report
  # reads red in every consumer (chk, evalv, cdr_ready). The old report goes only once the fixture is safely copied, never before: a FIXTURE
  # may be PREFIX.json itself (tools/regress.d/ingest-fuzz.sh, lines 96 and 123), and the redirect to PREFIX.json below does not happen
  # until cdp.py starts. So _rq_stale runs right after the fixture copy and on each early-failure path before return 2.
  _rq_f=$1; _rq_q=$2; _rq_p=$3; shift 3
  _rq_d=0
  if [ "${1:-}" = --delay ]; then _rq_d=$2; shift 2; fi
  _rq_t=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-runq.XXXXXX") || { _rq_stale; return 2; }
  # INT/TERM while runq runs: without a trap the server (python3 -m http.server, then PPID 1) and the
  # starchorus-runq.* directory stayed behind. The trap runs after the foreground cdp.py returns (that is how sh handles a signal
  # during a foreground command; Ctrl-C reaches cdp.py directly, as before), cleans up and re-raises the signal, so the
  # caller ends exactly as it did. No caller holds an INT/TERM trap across a call (grep -n 'trap ' tools/*.sh tools/regress.d/*.sh: mutation-probe.sh sets one only while it waits for its two halves, and clears it before it returns).
  _rq_srv=""; trap '_rq_abort INT' INT; trap '_rq_abort TERM' TERM
  cp "$H" "$_rq_t/index.html" || { _rq_end; _rq_stale; return 2; }
  [ "$_rq_f" = demo ] || cp "$_rq_f" "$_rq_t/starchorus.json" || { _rq_end; _rq_stale; return 2; }
  _rq_stale   # the fixture is copied (it may have been PREFIX.json itself): the old report must not outlive this point
  _rq_port=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')
  if [ "$_rq_d" = 0 ]; then
    python3 -m http.server "$_rq_port" --bind 127.0.0.1 --directory "$_rq_t" >/dev/null 2>&1 & _rq_srv=$!
  else
    cat > "$_rq_t/_slow.py" <<'PY'
import sys, time, functools, http.server, socketserver
delay = float(sys.argv[2])
class H(http.server.SimpleHTTPRequestHandler):
    def send_head(self):
        if self.path.split("?")[0].endswith("starchorus.json"): time.sleep(delay)
        return http.server.SimpleHTTPRequestHandler.send_head(self)
    def log_message(self, *a): pass
class S(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True
S(("127.0.0.1", int(sys.argv[1])), functools.partial(H, directory=sys.argv[3])).serve_forever()
PY
    python3 "$_rq_t/_slow.py" "$_rq_port" "$_rq_d" "$_rq_t" >/dev/null 2>&1 & _rq_srv=$!
  fi
  _rq_i=0; until python3 -c 'import sys,urllib.request;urllib.request.urlopen(sys.argv[1],timeout=1)' "http://127.0.0.1:$_rq_port/" >/dev/null 2>&1; do
    _rq_i=$((_rq_i+1)); [ "$_rq_i" -ge 25 ] && break; sleep 0.2; done
  if [ "${RUNQ_SHOT:-0}" = 1 ]; then set -- --shot "$_rq_p.png" "$@"; fi
  python3 "$R/tools/cdp.py" "http://127.0.0.1:$_rq_port/$_rq_q" --wait 6 --fps 3 --json "$@" > "$_rq_p.json"; _rq_rc=$?
  _rq_end; return $_rq_rc
}
_rq_stale() { rm -f "$_rq_p.json" "$_rq_p.png"; }   # runq: drop the previous run's report and screenshot (reasons in the comment inside runq)
_rq_end() {   # runq's cleanup on every path: server down, directory gone, no trap left behind
  trap - INT TERM
  [ -z "$_rq_srv" ] || { kill "$_rq_srv" 2>/dev/null; wait "$_rq_srv" 2>/dev/null; }
  case $_rq_t in */starchorus-runq.??????) rm -rf "$_rq_t" ;; esac   # only what runq's mktemp made
}
# shellcheck disable=SC2317,SC2329   # invoked via trap (SC2317 on ShellCheck < 0.10, SC2329 on >= 0.10)
_rq_abort() { _rq_end; kill -s "$1" $$; }   # cleanup, then die of the same signal as without the trap
runseq() { # runseq FIXTURE|demo PREFIX [cdp-Args…] → runq with QS_SEQ and --fps 0 (sequence/data evals)
  _rs_f=$1; _rs_p=$2; shift 2
  runq "$_rs_f" "$QS_SEQ" "$_rs_p" --fps 0 "$@"
}
chk() {    # chk PREFIX.json [demo]  → prints fps/exceptions/errors/evals; Exit 1 on exceptions or real errors
  python3 - "$1" "${2:-fixture}" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); demo=sys.argv[2]=="demo"
bad=[c for c in r.get("console") or [] if c.get("type") in ("error","assert") and "favicon.ico" not in json.dumps(c)
     and not (demo and "starchorus.json" in json.dumps(c))]
print("fps",r.get("fps"),"exceptions",len(r.get("exceptions") or []),"errors",len(bad))
for e in r.get("exceptions") or []: print("  EXCEPTION:", json.dumps(e, ensure_ascii=False)[:600])
for e in bad: print("  ERROR:", json.dumps(e, ensure_ascii=False)[:600])
for e in r.get("eval") or []: print("eval:",e["expr"][:70],"=>",json.dumps(e["value"],ensure_ascii=False)[:600])
sys.exit(1 if bad or r.get("exceptions") else 0)
PY
}
secof() { awk -v L="$1" '/==== [0-9]+ /{match($0,/==== [0-9]+/); s=substr($0,RSTART+5,RLENGTH-5)} NR==L{print s+0}' "$H"; }
# One pass, no temp file. A marker counts when the line contains "==== NN " (NN two digits, trailing space, so
# "==== 3 " can never match "==== 31 "); the start line and the end line belong to the slice.
_sec_slice_in() {   # _sec_slice_in FILE NN MM MIN
  awk -v A="==== $2 " -v B="==== $3 " -v MIN="$4" '
    { ia = index($0, A) > 0; ib = index($0, B) > 0; if (ia) na++; if (ib) nb++
      if (!done) {
        if (!on && ia && na == 1) on = 1
        if (on) { print; n++; if (ib && !ia) { on = 0; done = 1 } }
      } }
    END { e = 0; Am = substr(A, 1, length(A) - 1); Bm = substr(B, 1, length(B) - 1)
      if (na != 1) { print "sec_slice: marker \"" Am "\" found " na + 0 "x (want exactly 1)" | "cat 1>&2"; e = 1 }
      if (nb != 1) { print "sec_slice: marker \"" Bm "\" found " nb + 0 "x (want exactly 1)" | "cat 1>&2"; e = 1 }
      if (!e && !done) { print "sec_slice: marker \"" Bm "\" does not follow \"" Am "\"" | "cat 1>&2"; e = 1 }
      if (!e && n < MIN) { print "sec_slice: " Am " .. " Bm " is " n + 0 " lines (want >= " MIN ")" | "cat 1>&2"; e = 1 }
      exit e ? 2 : 0 }' "$1"
}
sec_slice() { _sec_slice_in "$H" "$1" "$2" "${3:-1}"; }
sec_grepc() {   # sec_grepc NN MM MIN 'BRE'
  _sg_s=$(sec_slice "$1" "$2" "$3") || return 2
  _sg_n=$(printf '%s\n' "$_sg_s" | grep -c "$4"); printf '%s\n' "$_sg_n"
}
selftest_verdict() {   # selftest_verdict FILE MIN [HAVE_SQLITE3: 1|0, default: command -v sqlite3] [ALLOW_NO_SQLITE: 1|0, default: $ALLOW_NO_SQLITE]
  # exit 0 = covered and green, 1 = FAIL, 3 = NOT COVERED: sqlite3 is missing, the operator said so on purpose (ALLOW_NO_SQLITE=1)
  # and what did run says ALL PASS. A missing sqlite3 without the switch stays a FAIL; a red selftest is a FAIL either way.
  _sv_f=$1; _sv_min=$2; _sv_h=${3:-}; _sv_a=${4:-${ALLOW_NO_SQLITE:-0}}
  if [ -z "$_sv_h" ]; then if command -v sqlite3 >/dev/null 2>&1; then _sv_h=1; else _sv_h=0; fi; fi
  _sv_l=$(sed -n 's/.*SELFTEST: //p' "$_sv_f" 2>/dev/null | tail -n 1)
  _sv_n=$(printf '%s\n' "$_sv_l" | sed -n 's/^ALL PASS (\([0-9][0-9]*\) checks).*/\1/p')
  _sv_why=""
  [ -n "$_sv_n" ] || _sv_why="$_sv_why; no 'ALL PASS (N checks)' line"
  if [ -n "$_sv_n" ] && [ "$_sv_n" -lt "$_sv_min" ]; then _sv_why="$_sv_why; N $_sv_n < $_sv_min"; fi
  grep -q 'SKIP: recon.db tests' "$_sv_f" 2>/dev/null && _sv_why="$_sv_why; SKIP: recon.db tests (block not run)"
  [ "$_sv_h" = 1 ] || _sv_why="$_sv_why; sqlite3 missing (one block falls out without a SKIP line)"
  _sv_sk=$(grep -E 'SKIP:' "$_sv_f" 2>/dev/null | grep -v 'SKIP: recon.db tests' | sed 's/^.*SKIP: //' | tr '\n' ',' | sed 's/,$//')
  if [ "$_sv_h" = 0 ] && [ "$_sv_a" = 1 ] && [ -n "$_sv_n" ]; then
    echo "$_sv_l -- NOT COVERED: sqlite3 missing and ALLOW_NO_SQLITE=1; the recon.db blocks did not run, so the floor of $_sv_min checks does not apply"
    return 3
  fi
  if [ -n "$_sv_why" ]; then echo "${_sv_l:-no SELFTEST line} -- FAIL${_sv_why}"; return 1; fi
  echo "$_sv_l >= $_sv_min${_sv_sk:+ [SKIP: $_sv_sk]}"
}
# ---- preflight: a missing tool is a setup problem (exit 2 with "MISSING: tool"), not thirty follow-up FAILs.
# The lists were measured: quick.sh and regress.sh ran to the end with a PATH that held exactly these tools and nothing else
# (tools/regress.d/preflight.sh keeps the probe alive for the "no jq" case; tools/README.md has the measuring command).
PF_TOOLS_BASE="awk basename cat chmod cmp cp cut date diff dirname find grep head ln mkdir mktemp mv paste rm sed sort tail tr uname wc"
# bash, ls and readlink are the device-probe drop-in's (tools/regress.d/device-probe.sh): it links the machine's bash as the stand-in /bin/bash, tests
# "a temp dir is empty" with ls -A (without ls that test passes on nothing) and the probe reads a link with readlink -f (without it the BusyBox reading fails);
# measured: that drop-in alone, with a PATH of exactly PF_TOOLS_QUICK plus sh, ends with every row PASS
PF_TOOLS_QUICK="$PF_TOOLS_BASE python3 shellcheck jq bash ls readlink"
PF_TOOLS_FULL="$PF_TOOLS_QUICK chrome sqlite3 git tar touch env id ps rmdir sleep uniq"
# what cdp.py would launch; a function of its own so a probe can say "no chrome" without hiding a real one
_pf_chrome() { python3 -B -c 'import sys; sys.path.insert(0, sys.argv[1]); import cdp; print(cdp.find_chrome())' "$R/tools" >/dev/null 2>&1; }
path_farm() {   # path_farm DIR TOOL... -> DIR holds a symlink to every executable on the current PATH except the named tools (probes: "PATH without jq")
  _pf_ifs=$IFS; IFS=:
  for _pf_p in $PATH; do
    [ -d "$_pf_p" ] && ln -s "$_pf_p"/* "$1"/ 2> /dev/null
  done
  IFS=$_pf_ifs; _pf_d=$1; shift
  for _pf_x in "$@"; do rm -f "$_pf_d/$_pf_x"; done
}
preflight() {   # preflight TOOL... -> return 2 and one "MISSING: TOOL" line (stderr) per absent tool; 0 when all are there
  _pf_rc=0
  for _pf_t in "$@"; do
    case $_pf_t in
      chrome)   # find_chrome needs python3, and python3 is reported on its own line
        command -v python3 >/dev/null 2>&1 || continue
        _pf_chrome && continue ;;
      sqlite3)
        command -v sqlite3 >/dev/null 2>&1 && continue
        if [ "${ALLOW_NO_SQLITE:-0}" = 1 ]; then continue; fi
        echo "MISSING: sqlite3 (ALLOW_NO_SQLITE=1 runs without it; the collector selftest row is then reported NOT COVERED)" >&2
        _pf_rc=2; continue ;;
      *) command -v "$_pf_t" >/dev/null 2>&1 && continue ;;
    esac
    echo "MISSING: $_pf_t" >&2; _pf_rc=2
  done
  [ "$_pf_rc" = 0 ] || echo "preflight: a tool is missing, nothing was run (exit 2)" >&2
  return $_pf_rc
}
# ---- wall time: one file per run, "LABEL  N s" per phase and per drop-in, in whole seconds (date +%s), then the total.
# Only measures. Nothing runs in parallel because the drop-ins share out/.
tm_begin() { _tm_f=$1; : > "$_tm_f"; _tm_all=$(date +%s); _tm_last=$_tm_all; }
tm_lap() {   # tm_lap LABEL -> the seconds since the last lap (or tm_begin)
  _tm_now=$(date +%s); printf '%-40s %5d s\n' "$1" "$((_tm_now - _tm_last))" >> "$_tm_f"; _tm_last=$_tm_now
}
tm_total() { _tm_now=$(date +%s); printf '%-40s %5d s\n' total "$((_tm_now - _tm_all))" >> "$_tm_f"; }
tm_note() {   # tm_note LABEL SECONDS -> a measured time that is NOT a lap (an eval's own clock); tm_check ignores it (label must
  # not start with drop-in/phase/total). No-op without tm_begin (a drop-in sourced by hand). Row names carry no seconds:
  # the sorted name list of two runs has to be identical, so measured times go here, not into the row.
  [ -n "${_tm_f:-}" ] || return 0
  printf '%-40s %5d s\n' "$1" "${2:-0}" >> "$_tm_f"
}
report_secs() {   # report_secs REPORT.json [N] -> whole seconds: the sum of the "ms" fields of the first N (default 2) eval results that parse
  python3 - "$1" "${2:-2}" <<'PY' 2>/dev/null || echo 0
import json, sys
ms = 0
try:
    ev = json.load(open(sys.argv[1], encoding="utf-8")).get("eval") or []
    for e in ev[:int(sys.argv[2])]:
        v = e.get("value")
        try: r = json.loads(v) if isinstance(v, str) else None
        except ValueError: r = None
        if isinstance(r, dict): ms += int(r.get("ms") or 0)
except Exception: pass
print(int(round(ms / 1000.0)))
PY
}
tm_check() {   # tm_check FILE NAME... -> label on stdout; exit 0 iff each drop-in NAME has exactly one "drop-in NAME N s" line and a total
  _tm_file=$1; shift
  awk -v names="$*" '
    BEGIN { n = split(names, want, " ") }
    $1 == "drop-in" && $4 == "s" && $3 ~ /^[0-9]+$/ { seen[$2]++; nd++; ds += $3 }
    $1 == "phase" { np++ }
    $1 == "total" && $3 == "s" && $2 ~ /^[0-9]+$/ { tot = $2; nt++ }
    END {
      for (i = 1; i <= n; i++) { if (seen[want[i]] != 1) { miss = miss " " want[i] (seen[want[i]] ? "(x" seen[want[i]] ")" : "") } }
      if (nt != 1) miss = miss " total"
      # no seconds in the label: the total stays in the file; the row name only says that a total line exists
      printf "%d drop-ins timed (%d asked), %d phases, total %s%s\n", nd, n, np, (nt == 1 ? "present" : "MISSING"), (miss != "" ? "; missing or repeated:" miss : "")
      exit (miss != "" || n == 0)
    }' "$_tm_file" 2>/dev/null
}
pycompile() {   # pycompile FILE... -> exit 1 (and one line per bad file) on the first syntax problem of any file
  python3 - "$@" <<'PY'
import sys
bad = 0
for f in sys.argv[1:]:
    try:
        compile(open(f, encoding="utf-8").read(), f, "exec")
    except (SyntaxError, ValueError, OSError) as e:
        print("    compile: %s: %s" % (f, e)); bad += 1
sys.exit(1 if bad else 0)
PY
}
# The paths the page may ask its own server for (measured with tools/verify.sh on many-clients.json:
# the page "/", the poll "/starchorus.json?_=T", the browser's "/favicon.ico"; the embedded font arrives as data: URLs).
# A new legitimate path is added here on purpose, together with the reason in the commit text.
NET_PATHS="/ /starchorus.json /favicon.ico"
net_verdict() {   # net_verdict REPORT.json SERVERLOG|- MIN_POLLS
  python3 - "$1" "$2" "$3" "$NET_PATHS" <<'PY'
import json, re, sys
from urllib.parse import urlsplit
rep_f, log_f, minpoll, paths = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4].split()
why, groups = [], {}
def note(m):
    if m not in why: why.append(m)
try:
    rep = json.load(open(rep_f, encoding="utf-8"))
except Exception as e:
    print("no report (%s) -- FAIL" % e); sys.exit(1)
reqs = rep.get("requests")
if not isinstance(reqs, list):
    print('no "requests" in the report -- FAIL: Network not enabled in cdp.py?'); sys.exit(1)
o = urlsplit(rep.get("url") or ""); origin = (o.scheme, o.netloc)
polls = 0; doc = 0
for q in reqs:
    m, u = str(q.get("method")), str(q.get("url"))
    if u.startswith("data:"): key = m + " data:"        # never leaves the machine: its own class, method still checked
    else:
        s = urlsplit(u); key = m + " " + s.path
        if (s.scheme, s.netloc) != origin: note("origin %s://%s (%s %s)" % (s.scheme, s.netloc, m, u[:60])); key = m + " " + s.scheme + "://" + s.netloc + s.path
        elif s.path not in paths: note("path %s not in {%s}" % (s.path, " ".join(paths)))
        if s.path == "/starchorus.json": polls += 1
        if s.path == "/": doc += 1
    if m != "GET": note("method %s (%s)" % (m, u[:60]))
    groups[key] = groups.get(key, 0) + 1
if len(reqs) < 2: note("only %d requests seen (want >= 2: the page and a poll)" % len(reqs))
if doc < 1: note("the page itself (GET /) was not seen")
if polls < minpoll: note("%d starchorus.json polls (want >= %d)" % (polls, minpoll))
extra = ""
if log_f != "-":
    lines = []
    try:
        for l in open(log_f, encoding="utf-8", errors="replace"):
            m = re.search(r'"([A-Z]+) (\S+) HTTP/[0-9.]+"', l)
            if m: lines.append((m.group(1), urlsplit(m.group(2)).path))
    except OSError as e:
        note("server log unreadable (%s)" % e)
    if not lines: note("server log holds no request line")
    lp = 0
    for m, p in lines:
        if m != "GET" or p not in paths: note("server log: %s %s" % (m, p))
        if p == "/starchorus.json": lp += 1
    # the CDP event of a request that was just sent may not have arrived yet at the end of the run: off by one is not a finding
    if abs(lp - polls) > 1: note("server log %d polls against %d seen by the browser" % (lp, polls))
    extra = "; server log %d lines" % len(lines)
lab = "%d requests: %s%s" % (len(reqs), ", ".join("%s x%d" % (k, groups[k]) for k in sorted(groups)), extra)
print(lab + (" -- FAIL: " + "; ".join(why) if why else "")); sys.exit(1 if why else 0)
PY
}
fuzz_verdict() {   # fuzz_verdict REPORT.json MODE MIN_M MIN_ANCHORS OPENFILE|-
  python3 - "$1" "$2" "$3" "$4" "$5" <<'PY'
import fnmatch, json, re, sys
rep_f, mode, min_m, min_a, open_f = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
why = []
def note(m):
    if m not in why: why.append(m)
try:
    ev = json.load(open(rep_f, encoding="utf-8")).get("eval") or []
except Exception as e:
    print("no report (%s) -- FAIL" % e); sys.exit(1)
runs = []
for i, e in enumerate(ev[:2]):
    v = e.get("value")
    try:
        r = json.loads(v) if isinstance(v, str) else None
    except ValueError:
        r = None
    if not isinstance(r, dict):
        note("eval %d gave no result object (%s)" % (i + 1, str(v)[:80])); continue
    runs.append(r)
if len(runs) != 2:
    note("want two eval results (main, big), got %d" % len(runs))
    print("no fuzz result -- FAIL: " + "; ".join(why)); sys.exit(1)
main, big = runs
finds, seen = [], set()
for r in runs:
    for n, w in r.get("findings") or []:
        if (n, w) not in seen: seen.add((n, w)); finds.append((n, w))
if mode == "probe":
    # a hostile-text mutant (class 6) that goes wrong is the unescaped-SSID fault (its markup may even break a handler: any finding
    # of such a mutant counts); a null-entry mutant (class 3) that throws in load() is the other. Boot errors are "other": unfair copy.
    esc_k = [f for f in finds if f[0].startswith("6:")]
    nul_k = [f for f in finds if f[0].startswith("3:") and f[1].startswith("load threw")]
    # an anchor that finds a sink showing the hostile text unmasked ("... masked and not raw") is the esc fault seen through another
    # sink, not an unplanned finding: with esc reduced to String(s) every masking anchor must fail. Run mode still counts them (the real page masks).
    anch_k = [f for f in finds if f[1].startswith("anchor:") and "masked and not raw" in f[1]]
    other = [f for f in finds if f not in esc_k and f not in nul_k and f not in anch_k]
    if not esc_k: note("BLIND: the unescaped SSID was not seen")
    if not nul_k: note("BLIND: null entries that are not skipped were not seen")
    if other: note("unplanned finding %s: %s" % (other[0][0][:40], other[0][1][:80]))
    # no counts in the label: how many findings a run has depends on timing (window.__x), the row name must not
    print("probe: RED as planted (unescaped SSID %s, null entries %s), %d other findings%s" % ("seen" if esc_k else "MISSED", "seen" if nul_k else "MISSED", len(other), " -- FAIL: " + "; ".join(why) if why else ""))
    sys.exit(1 if why else 0)
classes = {}
for r in runs:
    for c, n in (r.get("classes") or {}).items(): classes[c] = classes.get(c, 0) + n
n_m = sum(classes.values())
for c in "1234567":
    if classes.get(c, 0) < 1: note("class %s ran no mutant" % c)
if n_m < min_m: note("%d mutants (want >= %d)" % (n_m, min_m))
sk = main.get("sinks") or {}
for k in ("tip", "detail", "source", "legend", "chan", "paste", "drop"):
    if not sk.get(k): note("sink %s was never driven" % k)
if (sk.get("anchors") or 0) < min_a: note("%d positive anchors (want >= %d)" % (sk.get("anchors") or 0, min_a))
opens = []
if open_f != "-":
    for l in open(open_f, encoding="utf-8"):
        l = l.rstrip("\n")
        if l.strip(): opens.append(l.split("|"))
used = set()
new = []
for n, w in finds:
    hit = [i for i, o in enumerate(opens) if fnmatch.fnmatchcase(n, o[0])]
    if hit: used.update(hit)
    else: new.append((n, w))
for n, w in new[:3]: note("NEW finding %s: %s" % (n[:50], w[:90]))
if len(new) > 3: note("... and %d more new findings" % (len(new) - 3))
for i, o in enumerate(opens):
    if i not in used: note("known-open entry %r no longer found: please remove" % o[0])
# no seconds in the label: the row name must be identical from run to run; the eval time goes to the timing file
lab = "%d mutants, %d classes, %d anchors, %d known open" % (n_m, len([c for c in classes if classes[c]]), sk.get("anchors") or 0, len(opens))
print(lab + (" -- FAIL: " + "; ".join(why) if why else "")); sys.exit(1 if why else 0)
PY
}
order_verdict() {   # order_verdict REPORT.json MODE MIN_LISTS OPENFILE|-
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import fnmatch, json, sys
rep_f, mode, min_l, open_f = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
why = []
def note(m):
    if m not in why: why.append(m)
try:
    ev = json.load(open(rep_f, encoding="utf-8")).get("eval") or []
    ix = 1 if mode == "mixerprobe" else 0      # mixerprobe judges the SECOND eval of the run ("mixer" mode, broken shuffle)
    v = ev[ix].get("value") if len(ev) > ix else None
    r = json.loads(v) if isinstance(v, str) else None
except Exception as e:
    print("no report (%s) -- FAIL" % e); sys.exit(1)
if not isinstance(r, dict) or not isinstance(r.get("fixtures"), list):
    print("no order result (%s) -- FAIL" % (str(v)[:100] if not isinstance(r, dict) else str((r.get("findings") or [""])[0])[:100])); sys.exit(1)
fx, mixer, finds = r["fixtures"], r.get("mixer") or {}, [tuple(f) for f in (r.get("findings") or [])]
seeds = r.get("seeds") or 0
runs = sum(f.get("runs", 0) for f in fx)
skip_ne = sum(1 for f in fx for l in f.get("lists", []) if not l.get("checked") and l.get("n", 0) > 0)
skip_e = sum(1 for f in fx for l in f.get("lists", []) if l.get("n", 0) == 0)
iter_d = sum(1 for f in fx if len(set(f.get("iter") or [])) > 1)
if not fx: note("no fixture ran")
for f in fx:
    if f.get("runs") != seeds or seeds < 10: note("fixture %s ran %s permutations (want %s >= 10)" % (f.get("name"), f.get("runs"), seeds))
n_l = mixer.get("lists") or 0
if n_l < min_l: note("%d lists were shuffled (want >= %d)" % (n_l, min_l))
if mode == "mixerprobe":
    # the identity "shuffle": no list may count as moved, and no document may have been loaded (mode "mixer")
    if (mixer.get("ok") or 0) != 0: note("BLIND: %d of %d lists still count as shuffled with an identity mixer" % (mixer.get("ok") or 0, n_l))
    if finds: note("unplanned finding %s" % finds[0][0][:40])
    print("mixer probe: RED as planted (identity shuffle: %d of %d lists moved)%s" % (mixer.get("ok") or 0, n_l, " -- FAIL: " + "; ".join(why) if why else "")); sys.exit(1 if why else 0)
if mixer.get("ok") != n_l: note("the mixer moved only %d of %d lists in >= 9 of %d seeds: %s" % (mixer.get("ok") or 0, n_l, seeds, "; ".join(mixer.get("bad") or [])[:120]))
if mode == "probe":
    order = [f for f in finds if f[1].startswith(("node ", "layoutInfo ", "stats ", "node count ", "settled "))]
    other = [f for f in finds if f not in order]
    red_fx = {f[0].split("#")[0] for f in order}
    if len(red_fx) < 2: note("BLIND: only %d fixtures turned red without the sort (want >= 2)" % len(red_fx))
    if other: note("unplanned finding %s: %s" % (other[0][0][:40], other[0][1][:80]))
    print("probe: RED as planted (input order reached the layout in %d fixtures), %d other findings%s" % (len(red_fx), len(other), " -- FAIL: " + "; ".join(why) if why else "")); sys.exit(1 if why else 0)
opens = []
if open_f != "-":
    for l in open(open_f, encoding="utf-8"):
        l = l.rstrip("\n")
        if l.strip(): opens.append(l.split("|"))
used, new = set(), []
for n, w in finds:
    hit = [i for i, o in enumerate(opens) if fnmatch.fnmatchcase(n, o[0])]
    if hit: used.update(hit)
    else: new.append((n, w))
for n, w in new[:3]: note("NEW finding %s: %s" % (n[:40], w[:110]))
if len(new) > 3: note("... and %d more new findings" % (len(new) - 3))
for i, o in enumerate(opens):
    if i not in used: note("known-open entry %r no longer found: please remove" % o[0])
# no seconds in the label: the row name must be identical from run to run; the eval time goes to the timing file
lab = "%d fixtures, %d lists (n>=5) x %d seeds = %d runs checked against the reference, skipped (n<5): %d lists with entries + %d empty, mixer moved %d/%d lists, iterations differ in %d fixtures, %d known open" % (
    len(fx), n_l, seeds, runs, skip_ne, skip_e, mixer.get("ok") or 0, n_l, iter_d, len(opens))
print(lab + (" -- FAIL: " + "; ".join(why) if why else "")); sys.exit(1 if why else 0)
PY
}
evals() {  # evals PREFIX.json → one compact JSON value per eval, in order
  python3 - "$1" <<'PY'
import json,sys
for e in json.load(open(sys.argv[1])).get("eval") or []: print(json.dumps(e["value"],separators=(",",":"),ensure_ascii=False))
PY
}
evalv() {  # evalv PREFIX.json N → value of the N-th eval (1-based); strings raw, others compact JSON; "" if absent
  python3 - "$1" "$2" <<'PY'
import json,sys
try: ev=json.load(open(sys.argv[1])).get("eval") or []
except Exception: ev=[]
i=int(sys.argv[2])-1; v=ev[i]["value"] if 0<=i<len(ev) else ""
print(v if isinstance(v,str) else json.dumps(v,separators=(",",":"),ensure_ascii=False))
PY
}
# ev3 'EXPR' [ms]: for each theme: setTheme → await wait(ms) → frame() → EXPR (awaited; use comma
# expressions, not statements). Returns JSON {"foundation":…,"wargames":…,"whitehall":…}; restores the theme.
ev3() {
  printf '(async()=>{const T0=STARCHORUS.getTheme(),o={};for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await STARCHORUS.wait(%s);STARCHORUS.frame();o[t]=await (async()=>(%s))();}STARCHORUS.setTheme(T0);STARCHORUS.frame();return JSON.stringify(o)})()' "${2:-0}" "$1"
}
# ev3eq 'EXPR' [ms]: true iff JSON.stringify(EXPR) is identical in all three themes, else "f | w | h".
ev3eq() {
  printf '(async()=>{const T0=STARCHORUS.getTheme(),o=[];for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await STARCHORUS.wait(%s);STARCHORUS.frame();o.push(JSON.stringify(await (async()=>(%s))()));}STARCHORUS.setTheme(T0);STARCHORUS.frame();return o[0]===o[1]&&o[0]===o[2]?true:o.join(" | ")})()' "${2:-0}" "$1"
}
nomatch() { # nomatch PREFIX.json N 'PY-REGEX' → exit 0 iff eval N (a string) has no re.I match; prints hits
  python3 - "$1" "$2" "$3" <<'PY'
import json,re,sys
ev=json.load(open(sys.argv[1])).get("eval") or []; i=int(sys.argv[2])-1
v=ev[i]["value"] if 0<=i<len(ev) else None
if not isinstance(v,str): print("nomatch: eval %s is not a string: %r"%(sys.argv[2],v)); sys.exit(2)
hits=sorted({m.group(0) for m in re.finditer(sys.argv[3],v,re.I)})
for h in hits: print("  hit:",h)
sys.exit(1 if hits else 0)
PY
}
# ?fixed=… from boot freezes dt at 0, so nodes never fade in (alphaDraw 0: no AP labels, fillText 1 --
# label/budget evals would be vacuous; hitTest still works). Visual evals in a runseq run start with
# this prelude: thaw 1.5 s, re-freeze at the query's fixed time, one frame. Returns the visible AP count.
EV_THAW='(async()=>{const fx=+new URLSearchParams(location.search).get("fixed");STARCHORUS.setFixedTime(null);await STARCHORUS.wait(1500);STARCHORUS.setFixedTime(Number.isFinite(fx)?fx:null);await STARCHORUS.wait(50);STARCHORUS.frame();return STARCHORUS.nodes("ap").filter(n=>n.visible).length})()'
# Every text a viewer can meet: all text nodes (visible or hidden panels; no script/style) + title,
# aria-label, placeholder, alt, meta content, document.title. Newline-joined string.
EV_TEXT='(()=>{const o=[document.title];const w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT,{acceptNode:n=>/^(SCRIPT|STYLE|NOSCRIPT)$/.test(n.parentNode.nodeName)?NodeFilter.FILTER_REJECT:NodeFilter.FILTER_ACCEPT});while(w.nextNode()){const s=w.currentNode.nodeValue.trim();if(s)o.push(s)}document.querySelectorAll("[title],[aria-label],[placeholder],[alt],meta[content]").forEach(e=>{for(const a of ["title","aria-label","placeholder","alt","content"]){const v=e.getAttribute(a);if(v)o.push(v)}});return o.join("\n")})()'
