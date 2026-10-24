# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/cycle-census.sh -- what one cycle of the collector costs the Pager's core, counted in processes, and that the cheaper
# batch of 0.2.6 reads what the old one read.
#
# GUARDS AGAINST:  the collector's cycle growing processes again (a date, a df, a mktemp, an awk pass that only moves text, a readlink per descriptor): the
#                  number of external programs a cycle starts is counted with a farm of logging stand-ins (date, ls, df, cp, rm, sqlite3, tr, awk, mktemp,
#                  tail, wc, mv, sleep, head, sed, grep and the others a cycle may start, each logs its name and runs the real program) around a first pass,
#                  a skipped cycle (recon.db unchanged), a full pass on a busy night (recon.db changed) and a full pass that keeps its document, on a
#                  synthetic recon.db of the documented device scale (21,123 rows of type 4, 338 of type 5, 1,461 of type 8, 22,606 devices, 29 access
#                  points and 299 stations in the window; names made up, addresses 02:00:00:xx:xx:xx), seeded. The totals and the programs that matter
#                  are CEILINGS set to the values measured on 24 October 2026 on the development machine (macOS; GNU `ls` on Linux starts fewer, so a
#                  ceiling set on a Mac holds there too). A ceiling is only ever LOWERED: when a lever takes a process out, lower the number in the same
#                  commit. It also guards the batch: the batch of a cycle with the window cut out once (the temporary table) answers byte for byte what the
#                  same batch on the table itself answers (sqlite3 required: NOT COVERED without it), and the shell's own reading of the batch's output: a
#                  build with STARCHORUS_HOPINFO=1 and STARCHORUS_MAX_AGE=0 (the collector's own default window, 2 MB of output at the documented scale) must not
#                  cost more CPU than three times a build with HOPINFO=0 and a second over (a section read from the end of that text costs the square of its
#                  distance: 30 s of CPU for three builds against 1.1 s on the development machine under dash, 24 October 2026); and a build whose reduced batch
#                  meets a thousand new stations in its tail (CLI and PRB without a winner yet, three thousand rows) must not cost more than three times the same
#                  builds with that one asked as a first batch and a second over (a tail cut before its row test costs the square of its rows: 16.7 s against 0.14 s).
# NEGATIVE PROBE:  the same census over a copy of the collector whose cycle starts three more `date`s must be over its ceiling (the row's judge is run on it and
#                  must say no); the batch comparison is run on a batch whose temporary table keeps only the rows of types 4 and 5 (the access points are lost) and must say "differs";
#                  the CPU judge of the hop builds is run on the figures of a hop section read from the end (30,070 ms against 1,090 ms), that of the tail builds on the
#                  figures of a tail cut before its row test (16,700 ms against 140 ms; both development machine, dash, 24 October 2026), and must say no.
# NOT PROVEN:      the cost on the device (a start there is about 10 ms, the compute, by the estimate of the sighting of 24 October 2026, 60 to 300 times the development machine's: the figures are processes and
#                  a ratio of CPU times on this machine, information only; the device readings D1 to D3, D7 and D12 listed in docs/device-notes.md section 6a measure the Pager); the
#                  count on a Linux machine with GNU ls (fewer starts, a ceiling holds); the Bluetooth and Traffic layers (opt-in, off here); the first
#                  pass after a restart builds the vendor index (done before the first counted cycle).
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only CCN_* globals are set.

CCN_D="out/$P-cycle-census"; rm -rf "$CCN_D"; mkdir -p "$CCN_D/bin" "$CCN_D/out" "$CCN_D/ram" "$CCN_D/alerts"
CCN_OK=1
command -v sqlite3 >/dev/null 2>&1 || CCN_OK=0

# ---- the synthetic database (seeded; the generator is written here and run with python3 -I)
cat > "$CCN_D/gen.py" <<'PY'
# a recon.db at the scale documented for the device on 14 October 2026: ssid 21,123 rows of type 4, 338 of type 5, 1,461 of type 8, wifi_device 22,606; 29 access
# points and 299 stations inside a one-hour window. Seeded; every name and address is made up (02:00:00:xx:xx:xx, Net-nnn, Probe-nnnn).
import random, sqlite3, sys, os
out, now = sys.argv[1], int(sys.argv[2]); random.seed(7)
if os.path.exists(out): os.remove(out)
db = sqlite3.connect(out)
db.executescript("""
CREATE TABLE ssid(hash INT PRIMARY KEY, wifi_device INT, scan INT, type INT, bssid TEXT, ssid BLOB, hidden INT, time INT, signal INT, freq INT, channel INT, encryption INT, UNIQUE(hash) ON CONFLICT REPLACE);
CREATE TABLE wifi_device(hash INT PRIMARY KEY, scan INT, mac TEXT, time INT, signal INT, freq INT, packets INT, UNIQUE(hash) ON CONFLICT REPLACE);
CREATE TABLE scan(id INTEGER PRIMARY KEY, uuid TEXT, time INT, name TEXT);
""")
def mac(): return "020000" + "".join("%02X" % random.randrange(256) for _ in range(3))
enc = [0, 17184063752, 6597073961232, 2216207319320, 17184063752]
aps = [(mac(), "Net-%03d" % i, random.choice([2412, 2437, 2462, 5180, 5220, 5500, 5745, 5955]), random.choice(enc)) for i in range(150)]
now_aps = aps[:29]
h = 1
rows8 = []
for a in now_aps:
    for k in range(10): rows8.append((a, now - random.randrange(3500)))
while len(rows8) < 1461:
    a = random.choice(aps[29:]); rows8.append((a, now - random.randrange(4000, 86400 * 7)))
for a, t in rows8:
    fr = a[2]; ch = (fr - 2407) // 5 if fr < 3000 else (fr - 5000) // 5
    db.execute("INSERT INTO ssid VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", (h, 0, 1, 8, a[0], a[1].encode(), 0, t, -random.randrange(40, 92), fr, ch, a[3])); h += 1
for k in range(338):
    inw = k <= 60; a = random.choice(now_aps) if inw else random.choice(aps[29:])
    t = now - random.randrange(3500) if inw else now - random.randrange(4000, 86400 * 7)
    db.execute("INSERT INTO ssid VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", (h, 0, 1, 5, a[0], ("Net-%03d" % random.randrange(150)).encode(), 0, t, -random.randrange(40, 92), a[2], 6, a[3])); h += 1
devs = []
for d in range(22606):
    t = now - random.randrange(3500) if d < 299 else now - random.randrange(4000, 86400 * 7)
    devs.append((100000 + d, mac(), t))
    db.execute("INSERT INTO wifi_device VALUES (?,?,?,?,?,?,?)", (100000 + d, 1 + d % 22, devs[-1][1], t, -random.randrange(40, 92), 0, random.randrange(1, 90000)))
pool = ["Probe-%04d" % i for i in range(1500)]
for k in range(21123):
    d = devs[k % 22606] if k >= 1000 else devs[k % 299]
    t = d[2] if k >= 1000 else now - random.randrange(3500)
    db.execute("INSERT INTO ssid VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", (h, d[0], 1, 4, "FFFFFFFFFFFF", random.choice(pool).encode(), 0, t, -random.randrange(40, 92), 0, 0, 0)); h += 1
db.commit(); db.execute("VACUUM"); db.close()
PY
CCN_NOW=$(date +%s)
if [ "$CCN_OK" = 1 ]; then
  python3 -I -B "$CCN_D/gen.py" "$CCN_D/recon.db" "$CCN_NOW" || CCN_OK=0
  # an OUI file of made-up names (nmap form), so that the vendor pass is on
  CCN_I=0; while [ "$CCN_I" -lt 300 ]; do printf '%02X%02X%02X Census Maker %s\n' $((CCN_I / 256)) $((CCN_I % 256)) 17 "$CCN_I"; CCN_I=$((CCN_I + 1)); done > "$CCN_D/oui.txt"
fi

# ---- the farm: one stand-in per program a cycle may start; each logs its name and runs the real one (PATH is put back for it)
CCN_NAMES="date ls df cp rm sqlite3 tr awk mktemp tail wc mv sleep head sed grep cat cut sort find mkdir readlink basename dirname id uname chmod timeout nice ps stat touch kill dd od xargs tee cmp ln expr uniq jq"
# shellcheck disable=SC2016  # the stand-ins' text: the variables are theirs
for CCN_N in $CCN_NAMES; do
  printf '#!/bin/sh\nprintf "%%s\\n" "%s" >> "$CEN_LOG"\nPATH=$CEN_REALPATH\nexec %s "$@"\n' "$CCN_N" "$CCN_N" > "$CCN_D/bin/$CCN_N"; chmod +x "$CCN_D/bin/$CCN_N"
done
# sqlite3 also keeps the batch it is given, one file per cycle (the comparison of the batch forms below reads it)
# shellcheck disable=SC2016  # the stand-in's text
printf '#!/bin/sh\nprintf "sqlite3\\n" >> "$CEN_LOG"\nPATH=$CEN_REALPATH\ntee "$CEN_SQLDIR/$CEN_CYC.sql" | sqlite3 "$@"\n' > "$CCN_D/bin/sqlite3"; chmod +x "$CCN_D/bin/sqlite3"
# the driver: sources the collector's functions (its text up to the main section), runs four cycles and a fifth, marking each in the log. The changes to recon.db between
# them are made with the real PATH (not counted). 1 first pass (keeps its document) · 2 skipped · 3 a write: a full pass on a busy night, no document kept · 4 the database
# quiet again: a full pass that keeps its document · 5 skipped.
cat > "$CCN_D/drive.sh" <<'DRV'
. "$CEN_FUNCS"
mkdir -p "$OUTDIR" "$CAPDIR" "$PIDDIR"
setup_vendor 2>/dev/null
RESOLVED=recondb
mark() { printf '== %s\n' "$1" >> "$CEN_LOG"; CEN_CYC=$1; export CEN_CYC; }
age() { PATH=$CEN_REALPATH touch -t "$CEN_OLD" "$RECON_DB"; }
age
mark c1; run_cycle 2>>"$CEN_ERR" >/dev/null
mark c2; run_cycle 2>>"$CEN_ERR" >/dev/null
PATH=$CEN_REALPATH sqlite3 "$RECON_DB" "insert into ssid values (9000001,100000,1,4,'FFFFFFFFFFFF','Probe-0001',0,$(PATH=$CEN_REALPATH date +%s),-60,0,0,0);" 2>/dev/null
mark c3; run_cycle 2>>"$CEN_ERR" >/dev/null
age
mark c4; run_cycle 2>>"$CEN_ERR" >/dev/null
mark c5; run_cycle 2>>"$CEN_ERR" >/dev/null
mark end
echo "skips=$RS_SKIPS"
DRV
# ccn_run FUNCS-FILE TAG: the census of one collector text; the log in $CCN_D/TAG.log, the stderr in TAG.err
ccn_run() {
  cp "$CCN_D/recon.db" "$CCN_D/work-$2.db"
  : > "$CCN_D/$2.log"; : > "$CCN_D/$2.err"; rm -rf "$CCN_D/out-$2" "$CCN_D/ram-$2"; mkdir -p "$CCN_D/out-$2" "$CCN_D/ram-$2"
  CEN_OLD=$(python3 -I -B -c 'import time; print(time.strftime("%Y%m%d%H%M.%S", time.localtime(time.time() - 120)))')
  mkdir -p "$CCN_D/sql-$2"
  env CEN_SQLDIR="$R/$CCN_D/sql-$2" CEN_LOG="$R/$CCN_D/$2.log" CEN_ERR="$R/$CCN_D/$2.err" CEN_REALPATH="$PATH" CEN_FUNCS="$R/$1" CEN_OLD="$CEN_OLD" PATH="$R/$CCN_D/bin:$PATH" \
    STARCHORUS_OUTDIR="$R/$CCN_D/out-$2" STARCHORUS_RECON_DB="$R/$CCN_D/work-$2.db" STARCHORUS_SOURCE=recondb STARCHORUS_MAX_AGE=3600 STARCHORUS_INTERVAL=30 \
    STARCHORUS_VENDOR=1 STARCHORUS_OUI_FILE="$R/$CCN_D/oui.txt" STARCHORUS_TMPDIR="$R/$CCN_D/ram-$2" STARCHORUS_ALERT_DIR="$R/$CCN_D/alerts" STARCHORUS_BLUETOOTH=0 \
    STARCHORUS_TRAFFIC=0 STARCHORUS_CREATE_MON=0 STARCHORUS_HOMING_BSSID= \
    sh "$R/$CCN_D/drive.sh" > "$CCN_D/$2.out" 2>&1
}
# ccn_n TAG CYCLE [PROGRAM]: the starts in cycle c1..c5 (of one program)
ccn_n() { awk -v c="$2" -v p="${3:-}" '/^==/ { cur = $2; next } cur == c && (p == "" || $1 == p) { n++ } END { print n + 0 }' "$CCN_D/$1.log"; }
ccn_judge() { [ "$1" -le "$2" ] 2>/dev/null; }   # COUNT CEILING

# the cut point of the collector's text, and the census of the collector as it is
CCN_MAIN=$(grep -c '^# -* main$' starchorus-collect.sh)
if [ "$CCN_OK" = 1 ] && [ "$CCN_MAIN" = 1 ]; then
  sed '/^# -* main$/,$d' starchorus-collect.sh > "$CCN_D/funcs.sh"
  ccn_run "$CCN_D/funcs.sh" real
  CCN_C1=$(ccn_n real c1); CCN_C2=$(ccn_n real c2); CCN_C3=$(ccn_n real c3); CCN_C4=$(ccn_n real c4); CCN_C5=$(ccn_n real c5)
  CCN_GNU=0; ls -lnL --full-time / >/dev/null 2>&1 && CCN_GNU=1
  CCN_DONE=$(grep -c '^skips=' "$CCN_D/real.out")
  # The planted copy: three more `date`s in every cycle
  sed 's/^run_cycle() {$/run_cycle() { date >\/dev\/null; date >\/dev\/null; date >\/dev\/null/' "$CCN_D/funcs.sh" > "$CCN_D/funcs-plant.sh"
  CCN_PL=$(grep -c '^run_cycle() { date' "$CCN_D/funcs-plant.sh")
  ccn_run "$CCN_D/funcs-plant.sh" plant
  CCN_P3=$(ccn_n plant c3)
fi

# CEILINGS, 24 October 2026, development machine (macOS, one-true-awk 20200816, sqlite3 CLI; `ls -lnL --full-time` is missing there, so a stamp is an ls and two stat: GNU ls
# on Linux starts fewer, and a ceiling holds). Only ever LOWERED. Before the 0.2.6 levers (the same driver on the base 53bceaa): first 33, skipped 12, busy 30, quiet 32.
CCN_MAX_FIRST=25      # the first pass after a start: a full pass that also keeps its document (cat)
CCN_MAX_SKIP=12       # a cycle with recon.db unchanged: date, ls, 2 stat, date, sed, grep, wc, tail, mv, awk, mv
CCN_MAX_BUSY=21       # a full pass on a busy night (recon.db changed this second): nothing kept
CCN_MAX_QUIET=22      # a full pass that keeps its document for the skips that follow (one cat more)
# per program, the full passes: sqlite3 1 · awk 3 (the document, the vendor pass, the shape check; the first pass adds recondb_pick) · rm 1 (the copy; the first pass 2: the flash copy
# that may be there) · date 2 · cp 1 · no df (the first pass 1), no mktemp, no wc of the kept document
CCN_PROG_BUSY="sqlite3=1 awk=3 rm=1 date=2 cp=1 df=0 mktemp=0 tr=1 wc=2"
CCN_PROG_FIRST="sqlite3=1 awk=4 rm=2 date=2 cp=1 df=1 mktemp=0 tr=1"
CCN_PROG_SKIP="sqlite3=0 awk=1 cp=0 df=0 mktemp=0 date=2 wc=1"
# ccn_prog TAG CYCLE "prog=max ..." -> the programs over their ceiling ("" = none)
ccn_prog() { _cp_bad=""; for _cp_x in $3; do _cp_n=$(ccn_n "$1" "$2" "${_cp_x%%=*}"); [ "$_cp_n" -le "${_cp_x#*=}" ] || _cp_bad="$_cp_bad ${_cp_x%%=*}:$_cp_n>${_cp_x#*=}"; done; printf '%s' "$_cp_bad"; }

ccn_skips() { ccn_judge "$CCN_C2" "$CCN_MAX_SKIP" && ccn_judge "$CCN_C5" "$CCN_MAX_SKIP"; }
ccn_probe() { [ "$CCN_PL" = 1 ] && [ "$CCN_P3" = "$((CCN_C3 + 3))" ] && ! ccn_judge "$CCN_P3" "$CCN_MAX_BUSY"; }
# The batch of a busy full pass (cycle 3: HAS_TIME known, a window, so the reduced batch with the temporary table), and the same batch with the table itself: the
# statements of the groups read ssid, the CREATE, its PRAGMA and the row that says the table is there are gone (that one marker row is the only line the table's answer has more). Both run read-only on the same copy; the answers must be the same bytes. CPU ratio: information.
ccn_batches() {
  CCN_BQ="$CCN_D/sql-real/c3.sql"
  [ -s "$CCN_BQ" ] || return 1
  grep -q 'CREATE TEMP TABLE rwin' "$CCN_BQ" || return 1
  sed -e '/^PRAGMA temp_store=MEMORY;$/d' -e '/^CREATE TEMP TABLE rwin AS/d' -e "/^SELECT '#STARCHORUS_RWOK#' FROM sqlite_temp_master/d" -e 's/FROM rwin/FROM ssid/g' "$CCN_BQ" > "$CCN_D/batch-plain.sql"
  grep -q rwin "$CCN_D/batch-plain.sql" && return 1
  # the planted form: the temporary table keeps rows of type 4 and 5 only, so the access points are lost
  sed 's/AND type IN (4,5,8);/AND type IN (4,5);/' "$CCN_BQ" > "$CCN_D/batch-plant.sql"
  cmp -s "$CCN_BQ" "$CCN_D/batch-plant.sql" && return 1
  return 0
}
ccn_q() { sqlite3 -readonly -noheader -separator "$(printf '\t')" "$CCN_D/work-real.db" < "$1" 2> /dev/null; }
ccn_same() { ccn_q "$CCN_BQ" | grep -v '^#STARCHORUS_RWOK#$' > "$CCN_D/out-rwin.txt"; ccn_q "$CCN_D/batch-plain.sql" > "$CCN_D/out-plain.txt"; cmp -s "$CCN_D/out-rwin.txt" "$CCN_D/out-plain.txt" && [ -s "$CCN_D/out-rwin.txt" ]; }
ccn_differs() { ccn_q "$CCN_D/batch-plant.sql" > "$CCN_D/out-plant.txt"; ! cmp -s "$CCN_D/out-plant.txt" "$CCN_D/out-plain.txt"; }
ccn_cpu() {   # median CPU (ms) of 10 runs each of the two batches, as "plain rwin"
  python3 -I -B - "$CCN_D" <<'PY'
import resource, subprocess, sys
d = sys.argv[1]
def cpu(sql):
    t = []
    for _ in range(10):
        r0 = resource.getrusage(resource.RUSAGE_CHILDREN)
        subprocess.run(["sqlite3", "-readonly", "-noheader", "-separator", "\t", d + "/work-real.db"], stdin=open(sql), capture_output=True)
        r1 = resource.getrusage(resource.RUSAGE_CHILDREN); t.append((r1.ru_utime - r0.ru_utime) + (r1.ru_stime - r0.ru_stime))
    t.sort(); return t[5] * 1000
a, b = cpu(d + "/batch-plain.sql"), cpu(d + "/sql-real/c3.sql")
print("%.1f %.1f" % (a, b))
PY
}

# The shell's own reading of the output at the window the collector starts with (STARCHORUS_MAX_AGE=0: every station of the database, 2 MB of text): three builds with the hop
# section asked for and three without, the CPU time (shell and sqlite3 together, the lower of two runs) of each; the first build learns the schema, the others are the reduced batch.
cat > "$CCN_D/hop.sh" <<'DRV'
. "$CEN_FUNCS"
mkdir -p "$OUTDIR" "$CAPDIR"
MAX_AGE=0; HOPINFO=$CEN_HOP; RESOLVED=recondb; VENDOR=0; CYC_NOW=$CEN_NOW
n=0; while [ "$n" -lt 3 ]; do build_from_recondb "$CEN_NOW" > /dev/null 2>&1; n=$((n + 1)); done
DRV
CCN_HSH="sh"; if command -v dash >/dev/null 2>&1; then CCN_HSH=dash; fi      # the device's shell is an ash: dash where there is one, the byte locale either way (a UTF-8 locale makes bash several times slower on a 2 MB string)
ccn_hopcpu() {   # HOP (0|1) -> the CPU ms of three builds, the lower of two runs, "" if it could not be taken
  _hc_b=""
  for _hc_i in 1 2; do
    cp "$CCN_D/recon.db" "$CCN_D/work-hop.db"; rm -rf "$CCN_D/ram-hop" "$CCN_D/out-hop"; mkdir -p "$CCN_D/ram-hop" "$CCN_D/out-hop"
    _hc_t=$(env CEN_FUNCS="$R/$CCN_D/funcs.sh" CEN_HOP="$1" CEN_NOW="$CCN_NOW" STARCHORUS_OUTDIR="$R/$CCN_D/out-hop" STARCHORUS_RECON_DB="$R/$CCN_D/work-hop.db" STARCHORUS_SOURCE=recondb \
      STARCHORUS_TMPDIR="$R/$CCN_D/ram-hop" STARCHORUS_VENDOR=0 STARCHORUS_BLUETOOTH=0 STARCHORUS_TRAFFIC=0 STARCHORUS_CREATE_MON=0 STARCHORUS_HOMING_BSSID= LC_ALL=C CCN_SH="$CCN_HSH" \
      python3 -I -B -c 'import os, resource, subprocess, sys
r0 = resource.getrusage(resource.RUSAGE_CHILDREN)
subprocess.run([os.environ["CCN_SH"], sys.argv[1]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
r1 = resource.getrusage(resource.RUSAGE_CHILDREN)
print(round(((r1.ru_utime - r0.ru_utime) + (r1.ru_stime - r0.ru_stime)) * 1000))' "$R/$CCN_D/hop.sh" 2>/dev/null)
    case $_hc_t in ''|*[!0-9]*) return 1 ;; esac
    if [ -z "$_hc_b" ] || [ "$_hc_t" -lt "$_hc_b" ]; then _hc_b=$_hc_t; fi
  done
  printf '%s' "$_hc_b"
}
ccn_hop_bad() { ! ccn_hop_ok "$@"; }
ccn_hop_ok() { [ "$1" -le $((3 * $2 + 1000)) ] 2>/dev/null; }   # CPU ms with the hop section, CPU ms without: at most three times and a second over

# A tail with rows: the access points of the database and no station in the window, so that CLI and PRB have no winner and their alternatives sit in the tail of the reduced
# batch; then a thousand stations arrive at once, two probes each (the payload starts recon and the collector together: the first cycles see access points, no station), and
# the next build's tail has three thousand rows. Two runs of the same three builds, the third one either as it comes (the reduced batch, its tail full, asked again as a first
# batch) or as a first batch from the start (the winners forgotten before it): the CPU of the first run must stay within three times the second's and a second over.
cat > "$CCN_D/tail.sh" <<'DRV'
. "$CEN_FUNCS"
mkdir -p "$OUTDIR" "$CAPDIR"
MAX_AGE=3600; HOPINFO=0; RESOLVED=recondb; VENDOR=0; CYC_NOW=$CEN_NOW
build_from_recondb "$CEN_NOW" > /dev/null 2>&1
build_from_recondb "$CEN_NOW" > /dev/null 2>&1
sqlite3 "$RECON_DB" < "$CEN_BURST" 2>/dev/null
[ "$CEN_FRESH" != 1 ] || { HAS_TIME=""; RQ_WIN=""; RDB_SCH=""; }
build_from_recondb "$CEN_NOW" > /dev/null 2>&1
DRV
ccn_tailcpu() {   # FRESH (0|1) -> the CPU ms of the three builds, the lower of two runs, "" if it could not be taken
  _tc_b=""
  for _tc_i in 1 2; do
    cp "$CCN_D/notsta.db" "$CCN_D/work-tail.db"; rm -rf "$CCN_D/ram-tail" "$CCN_D/out-tail"; mkdir -p "$CCN_D/ram-tail" "$CCN_D/out-tail"
    _tc_t=$(env CEN_FUNCS="$R/$CCN_D/funcs.sh" CEN_FRESH="$1" CEN_NOW="$CCN_NOW" CEN_BURST="$R/$CCN_D/burst.sql" STARCHORUS_OUTDIR="$R/$CCN_D/out-tail" STARCHORUS_RECON_DB="$R/$CCN_D/work-tail.db" \
      STARCHORUS_SOURCE=recondb STARCHORUS_TMPDIR="$R/$CCN_D/ram-tail" STARCHORUS_VENDOR=0 STARCHORUS_BLUETOOTH=0 STARCHORUS_TRAFFIC=0 STARCHORUS_CREATE_MON=0 STARCHORUS_HOMING_BSSID= LC_ALL=C CCN_SH="$CCN_HSH" \
      python3 -I -B -c 'import os, resource, subprocess, sys
r0 = resource.getrusage(resource.RUSAGE_CHILDREN)
subprocess.run([os.environ["CCN_SH"], sys.argv[1]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
r1 = resource.getrusage(resource.RUSAGE_CHILDREN)
print(round(((r1.ru_utime - r0.ru_utime) + (r1.ru_stime - r0.ru_stime)) * 1000))' "$R/$CCN_D/tail.sh" 2>/dev/null)
    case $_tc_t in ''|*[!0-9]*) return 1 ;; esac
    if [ -z "$_tc_b" ] || [ "$_tc_t" -lt "$_tc_b" ]; then _tc_b=$_tc_t; fi
  done
  printf '%s' "$_tc_b"
}
ccn_tail_mk() {   # the database without stations and the burst (a thousand stations, made-up 02:00:00 addresses and names), by the real sqlite3 on a copy
  cp "$CCN_D/recon.db" "$CCN_D/notsta.db" && sqlite3 "$CCN_D/notsta.db" "DELETE FROM ssid WHERE type=4;" </dev/null 2>/dev/null || return 1
  python3 -I -B - "$CCN_D/burst.sql" "$CCN_NOW" <<'PY'
import sys
out, now = sys.argv[1], int(sys.argv[2])
with open(out, "w") as f:
    f.write("BEGIN;\n")
    for i in range(1000):
        dev = 900000 + i; mac = "020000%06X" % (0x400000 + i)
        f.write("INSERT INTO wifi_device VALUES (%d,1,'%s',%d,-66,0,3);\n" % (dev, mac, now - 100))
        f.write("INSERT INTO ssid VALUES (%d,%d,1,4,'FFFFFFFFFFFF','Burst-%04d',0,%d,-66,0,0,0);\n" % (8000000 + 2 * i, dev, i, now - 100))
        f.write("INSERT INTO ssid VALUES (%d,%d,1,4,'FFFFFFFFFFFF','BurstB-%04d',0,%d,-67,0,0,0);\n" % (8000001 + 2 * i, dev, i, now - 101))
    f.write("COMMIT;\n")
PY
}

if [ "$CCN_OK" != 1 ]; then
  notcov "cycle census: sqlite3 or the synthetic database is missing here"
  notcov "cycle census: batch forms (sqlite3 required)"
  notcov "cycle census: the hop section at the start window (sqlite3 required)"
  notcov "cycle census: a tail with a thousand stations (sqlite3 required)"
elif [ "$CCN_MAIN" != 1 ] || [ "$CCN_DONE" != 1 ]; then
  row "cycle census: the collector's text has one main section to cut at ($CCN_MAIN) and the driver ran to its end ($CCN_DONE)" FAIL
else
  # the census measures what it says it does: the cycles were what the driver meant them to be
  CCN_S="$(ccn_n real c1 sqlite3)/$(ccn_n real c2 sqlite3)/$(ccn_n real c3 sqlite3)/$(ccn_n real c4 sqlite3)/$(ccn_n real c5 sqlite3)"
  rowif "cycle census: the cycles were a first pass, a skip, a busy full pass, a quiet full pass, a skip (sqlite3 starts $CCN_S, want 1/0/1/1/0)" [ "$CCN_S" = 1/0/1/1/0 ]
  rowif "cycle census: the first pass starts $CCN_C1 processes (ceiling $CCN_MAX_FIRST; 33 before 0.2.6; ls --full-time here: $CCN_GNU)" ccn_judge "$CCN_C1" "$CCN_MAX_FIRST"
  rowif "cycle census: a skipped cycle starts $CCN_C2 and $CCN_C5 (ceiling $CCN_MAX_SKIP; the same before 0.2.6)" ccn_skips
  rowif "cycle census: a busy full pass starts $CCN_C3 processes (ceiling $CCN_MAX_BUSY; 30 before 0.2.6)" ccn_judge "$CCN_C3" "$CCN_MAX_BUSY"
  rowif "cycle census: a full pass that keeps its document starts $CCN_C4 processes (ceiling $CCN_MAX_QUIET; 32 before 0.2.6)" ccn_judge "$CCN_C4" "$CCN_MAX_QUIET"
  CCN_B=$(ccn_prog real c3 "$CCN_PROG_BUSY")$(ccn_prog real c4 "$CCN_PROG_BUSY")$(ccn_prog real c1 "$CCN_PROG_FIRST")$(ccn_prog real c2 "$CCN_PROG_SKIP")$(ccn_prog real c5 "$CCN_PROG_SKIP")
  rowif "cycle census: per program (full pass: $CCN_PROG_BUSY; first: df 1; skip: $CCN_PROG_SKIP), over:${CCN_B:- none}" [ -z "$CCN_B" ]
  # the probe: three more dates in a cycle read over the ceiling, and the judge says so
  rowif "cycle census probe bites: a collector that starts three more dates a cycle reads $CCN_P3 on the busy pass against the ceiling $CCN_MAX_BUSY (judged red)" ccn_probe
  # the batch forms
  if ccn_batches; then
    CCN_CPU=$(ccn_cpu 2>/dev/null); CCN_SAME=0; ccn_same && CCN_SAME=1
    rowif "cycle census: the batch with the temporary table answers byte for byte what the batch on ssid answers ($(wc -c < "$CCN_D/out-plain.txt" | tr -d ' ') bytes; CPU ms plain/rwin ${CCN_CPU:-?}, information)" [ "$CCN_SAME" = 1 ]
    rowif "cycle census probe bites: a temporary table that keeps only types 4 and 5 answers differently (judged red)" ccn_differs
  else
    row "cycle census: the captured batch of the busy pass has the temporary table and a plain form can be made of it" FAIL
  fi
  # the hop section: read from the start of the output, so the build costs what it costs without it
  CCN_H1=$(ccn_hopcpu 1); CCN_H0=$(ccn_hopcpu 0)
  if [ -n "$CCN_H1" ] && [ -n "$CCN_H0" ]; then
    rowif "cycle census: three builds at STARCHORUS_MAX_AGE=0 with the hop section cost $CCN_H1 ms of CPU against $CCN_H0 ms without it (at most three times and a second over)" ccn_hop_ok "$CCN_H1" "$CCN_H0"
  else
    notcov "cycle census: the hop builds' CPU could not be taken (python3 resource, a sh that runs the driver)"
  fi
  rowif "cycle census probe bites: the same judge on the figures of a hop section read from the end of the text (30,070 ms against 1,090 ms) says no" ccn_hop_bad 30070 1090
  rowif "cycle census probe holds: 300 ms against 270 ms (a plain build) is within the limit" ccn_hop_ok 300 270
  # the tail with rows: its row test comes before the cut that counts from the start (rq_tail), so a full tail costs a pass asked again, not the square of its rows
  CCN_T1=""; CCN_T0=""
  if ccn_tail_mk; then CCN_T1=$(ccn_tailcpu 0); CCN_T0=$(ccn_tailcpu 1); fi
  if [ -n "$CCN_T1" ] && [ -n "$CCN_T0" ]; then
    rowif "cycle census: three builds whose third finds a thousand new stations in the tail of the reduced batch cost $CCN_T1 ms of CPU against $CCN_T0 ms when the third is a first batch (at most three times and a second over)" ccn_hop_ok "$CCN_T1" "$CCN_T0"
  else
    notcov "cycle census: the tail builds' CPU could not be taken (python3 resource, a sh that runs the driver)"
  fi
  rowif "cycle census probe bites: the same judge on the figures of a tail cut before its row test (16,700 ms against 140 ms; development machine, dash, 24 October 2026) says no" ccn_hop_bad 16700 140
fi

# ---- the cases of the self-test for the cheaper cycle all ran (their lines in the self-test output of tools/static.sh or regress.sh, as collector-fields.sh reads the others):
# a renamed or dropped case would otherwise go quietly. The two that need a tool the machine may lack (python3 for the socket of the Bluetooth stand-in, sqlite3 for the child
# of the vendor case) may say SKIP instead.
ccn_fam() {   # FILE -> the families that have neither a PASS nor (for the two) a SKIP line in the self-test output FILE
  _cf_m=""
  for _cf_p in 'recon batch: the window is cut out once' 'recon batch: the document is the same bytes from the first batch' 'recon batch: a tie (one BSSID' 'recon batch: the first batch asks' \
               'recon batch: a group that had no winner' 'recondb_pick own:' 'recon batch: the winners are dropped with HAS_TIME' 'recon batch: HOPINFO asks ssid' \
               'recon batch: a pass with no access point' 'recon batch: a file that changes shape under' 'recon batch: HOP is asked right behind' 'recon batch: the final awk takes one access point' \
               'run_cycle: the clock is read once' 'ram_room: df runs at' 'recon copy: a cached yes' 'recon copy: the stale flash copy' 'run_cycle: a full pass keeps its document' \
               'loop pace:' 'loop pace: the window' 'hourly line:' 'recondb_failed: by builtins' 'bt_ready: a monitor that holds a socket' 'bt_judge: the verdicts' "vendor: run_cycle's pass gathers" \
               'vendor: the gathering file is swept' 'vendor: a collector removes its own gathering file' 'recon batch: a file with the legacy table beside ssid' \
               'recon batch: a batch that goes through the pick keeps' 'rq_tail: a tail with rows'; do
    grep -qF "PASS: $_cf_p" "$1" && continue
    case $_cf_p in
      'bt_ready:'*) grep -qF 'SKIP: bt_ready on a real socket' "$1" && continue ;;
      'vendor: a collector removes'*) grep -qF 'SKIP: vendor: the end of the gathering file' "$1" && continue ;;
    esac
    _cf_m="$_cf_m [$_cf_p]"
  done
  printf '%s' "$_cf_m"
}
if [ -s "out/$P-selftest.txt" ]; then
  CCN_FM=$(ccn_fam "out/$P-selftest.txt")
  rowif "cycle census: the self-test cases for the cheaper cycle all ran (missing:${CCN_FM:- none})" [ -z "$CCN_FM" ]
  CCN_FB=$(grep -v 'PASS: loop pace:\|PASS: hourly line:' "out/$P-selftest.txt" > "out/$P-ccn-st.txt"; ccn_fam "out/$P-ccn-st.txt")
  case $CCN_FB in *'[loop pace:]'*'[hourly line:]'*) CCN_FBO=1 ;; *) CCN_FBO=0 ;; esac
  rowif "cycle census: that family row bites (an output without the pace and the hourly line cases names them)" [ "$CCN_FBO" = 1 ]
else
  notcov "cycle census: the self-test cases for the cheaper cycle (no out/$P-selftest.txt: run tools/static.sh or tools/regress.sh first)"
fi
