# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/display-selftest.sh -- starchorus-display.sh: the on-device --selftest and the visible
# "jq incomplete" marker. Background: the device's jq has no Oniguruma and fetch() discards stderr, so a jq filter
# that fails at call time leaves blank band counters or a wrong open/WEP line with no error at all. The filters
# are regex-free (jq-noregex.sh pins them), and the five builtins they rely on -- endswith, until, index, string
# slicing, tostring -- were measured on the device (docs/device-notes.md 2a, V-12), but every row of
# jq-noregex.sh runs on the dev machine only. The two things below make such a gap loud instead of silent; every
# row runs against BOTH starchorus-display.sh copies.
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only DST_* names are set.
#
# One generated wrapper "jq" (PATH shim) has three modes, all off = the real jq:
#   STARCHORUS_NRX=1          the device's jq: the regex family fails at CALL time (same model as jq-noregex.sh)
#   STARCHORUS_BREAK=NAME     that one one-argument builtin fails at CALL time (negative control: NAME=endswith)
#   STARCHORUS_HANG=FILE      the first "jq -r" (the summary's one program, run on the selftest fixture) touches FILE, then waits
#                        until FILE.go exists (10 s at most): the script is held inside its e2e step, fixture on disk
#
# S1 real jq   : --selftest exits 0, "ALL PASS (N checks)" with N = the number of PASS lines, no FAIL line.
# S2 device jq : the same under STARCHORUS_NRX=1 (the regex family fails at call time): still ALL PASS -- the selftest
#                calls no regex builtin anywhere, so a check that quietly started to need one goes red here.
# S3 negative  : STARCHORUS_BREAK=endswith -> exit 1, a FAIL line naming endswith, the other builtins still PASS (the
#                report pinpoints instead of just going red), FAILED (k of N) adds up; and --once summary / top /
#                bands each print the red "jq incomplete" line exactly once.
# S4 healthy   : --once summary / top / bands on every fixture, real jq and device jq: no such line, real output.
# S5 vacuity   : both wrapper modes bite (and only then); the selftest carries >= 40 checks and a PASS line for
#                every required builtin, table function and end-to-end check, so it cannot shrink unnoticed.
# S6 no jq     : a PATH without jq -> "FAIL: jq present", "FAILED (1 of 1)", exit 1, no err_dialog text.
# S7 tempfile  : the selftest fixture is gone after a run and after SIGTERM in the middle of one (the trap); the
#                fixture must exist at the moment the signal is sent, else the row proves nothing.
# S8 no regex   : jq-noregex.sh R1 scans the shipped source for regex-builtin calls as written; a shell-quote split such as
#                te''st( (the shell joins the two pieces) slips past a scan of the text as written. This row joins every
#                '' pair back together first and applies R1's own patterns: ZERO call sites in either display script copy. A
#                detector self-check (a split call on a code line is found, the same text in a comment is not) keeps the
#                row from going green on a scan that silently stopped seeing anything. What no text scan can see (a name
#                assembled at run time) is covered by S2: the regex family fails at call time there.
# S9 one jq     : the Overview starts one jq process per screen render (--once: the one health probe on first use plus the
#                screen's program; interactive: the probe once, then one program per CHANGED capture and none while the file is
#                unchanged, a draw of it again by key A included); GEN moves only with `generated`. Driven by a stand-in
#                WAIT_FOR_INPUT that answers A four times, the capture swapped at its third call (after the draw that call was armed
#                with: the stand-in waits for that frame), then B (the stand-in LIST_PICKER leaves with exit 0): 3 jq, 5 renders,
#                GEN 1 1 1 2 2, "Reading..." twice (the first draw and the one on the new capture), one stat probe, and no `timeout`
#                before WAIT_FOR_INPUT: a logging stand-in `timeout` in front of jq sees the two program runs and nothing else. The replaced capture has the same size and lands in the same minute as the
#                old one (the collector's steady state: only `generated` moves on), so only the inode tells them apart: a
#                fingerprint that loses the inode, or does not follow a symlink (the capture is read through one in a second run),
#                goes red. A stand-in "stat" fails like the device's missing applet: the stat-or-ls decision is taken once per process.
# S10 slow jq   : a jq that sleeps 3 s, STARCHORUS_JQ_CAP=1 and a stand-in `timeout` that ends it with 124 (sleep and kill; macOS has none):
#                the two slow lines ("This scan took over 20 s to read." / "Try Settings > Show Last: 1 h.") once per draw, "Reading..."
#                once, the frame, no waiting line; the verdict is cached per capture: A on the same file starts no second jq. Only a jq that ran
#                under the limit can be too slow: one killed from outside (exit 137, as by the out-of-memory killer) without it (--once never
#                sets a limit, whether or not the box has a `timeout`) is no data, the waiting line, as it always was; the same 137 from a run
#                under `timeout` is the slow verdict (a stand-in jq that exits 137 and the logging stand-in `timeout`).
# S11 strikes   : three junk or empty answers in a row that come back within 1 s of their arm (or on a box with no clock) end the Overview (rc 0,
#                one draw, three waits, no list); a known key in between starts the count again, and so does an answer that took 1 s or more
#                (a slow UI is waited out, however often: no quitting to the menu by itself; 99 hundredths count, 100 do not); BACK, Escape and a
#                lower-case b are B and a lower-case a is A, so none of them is a strike; the same words padded with spaces, a tab and a CR are the same keys. S12 updown: UP and DOWN cause no draw, no exit and no strike. S13 leftright: RIGHT and LEFT step
#                through summary, top, bands, devices, probes, clients, bluetooth, air and wrap (summary <-> air); B opens the list "Overview"
#                with its eight rows in order and the cursor on the screen B came from; a row picked is drawn, an unknown label leaves; the
#                Bluetooth screen of a capture that has Bluetooth is drawn whole (heading, the figures, the strongest companies, the frame),
#                at most 12 lines of at most 40 columns.
# S14 notimeout : no code line of either copy puts `timeout` before WAIT_FOR_INPUT, and exactly one code line calls it (a killed UI command
#                can leave a waiter in the UI daemon that swallows the next press); a detector self-check keeps the row from going green blind.
# S15 armed     : the wait is open BEFORE the draw is (measured on the device, 16 October 2026: a press made while no wait is open is lost, and B
#                is then taken by the Pager UI), and the draw ENDS with the first key (a wait takes one key, and a draw that went on would run
#                with none open). A stand-in jq sleeps 2 s on the screen's program; the key stand-in answers the moment it has started
#                ("@" words): the answer is taken and acted on at once (A: the screen again; B: the list; RIGHT: the next screen; UP: the same
#                screen again, because its draw was cut), the jq of the ended draw is ended too and nothing of it is kept (the program runs
#                again), also under a `timeout` that does not pass a signal on (the children of the `timeout` are ended first).
# S16 frame     : every draw ends with `Last scan HH:MM:SS (N s ago)` (UTC, from `generated`) and `A: Refresh   B: Back`, the summary also with
#                the page's address; older than three intervals the red `No new scan for N min.` takes the place of the time; with no capture
#                since Start: the waiting line, the keys, no time, and one program run however often the screen is drawn (D5). The Bluetooth screen of
#                radio-pair (fresh `generated`) ends with the same Last scan line and the keys, twelve lines at most: that line is the specification's
#                'Last scan' of that screen (it dates the capture, not a scan window of its own; `--once` prints a screen without the frame).
# S17 nopending: no waiter is left behind by a way out that is not a signal: B out of the list, three strikes, the payload gone after a key
#                (a stand-in kills the fake payload while it answers) and gone before the first arm. The stand-in writes its pid to a file and
#                kill -0 must fail for each; one pid per wait, so the row cannot pass on a run that never waited; and no Overview run of
#                this drop-in leaves its temp dir (starchorus-ov.*) behind.
# S18 trap      : the Overview ended by a signal while a stand-in waiter is pending (it holds for 30 s): TERM (exit 143) when the screen is
#                drawn and the shell waits in take, HUP (129) likewise, TERM during the draw (the shell waits for its jq in `wait`, so its trap
#                runs at once and ends the jq too); the waiter is gone within a second (3 s allowed for the draw), the temp dir is
#                removed. The waiter must have been running and the dir there at the moment of the signal. Under sh and, when installed, dash.
# S19 parent    : parent_gone starts no process (no sed or cut: a stand-in notes every one, against a control run) and reads the parent from
#                field 4 of the shell's own stat file (a fake proc directory), also with a command name that holds spaces and brackets;
#                another parent ends the Overview before it arms or draws; a stat file without a number there does not.
# S20 keyerr    : a key file that cannot be written: an error dialog at the start (a read-only temp dir), a named failure later (the key file
#                made read-only while the waiter runs), exit 1 in both, and not three empty answers; the temp dir is removed.
# The radio pair (Bluetooth screen, activity bars): S1 and S2 carry the new helper checks and the end-to-end checks of screen_bluetooth and screen_bands
#                (so an edit of btlist, btco, bar8 or actbar, or one that lets a record of the wrong type through, is red there), S5 names them so they cannot
#                be dropped, S9 counts one jq for the new screen, S13 walks eight screens and draws the Bluetooth screen of radio-pair whole.
#                NEGATIVE PROBES (a copy of the display script in each case): RIGHT from Stations going to Air (the new screen skipped) => S13 red, nothing else;
#                fixed addresses counted as random-static only => S1 and S2 red (the count line of screen_bluetooth); the bar's cells inverted => S1 and S2
#                red (bar8, actbar, screen_bands); the cap of company lines `bt_max=7` raised to 12 in both copies => S1, S2 and S5 red, nothing else (the four checks
#                'the cap on eleven companies' of the selftest: a capture of fourteen records in eleven companies, drawn plain, under a void window, under the ACTIVE claim
#                and under both, must show 7, 6, 6 and 5 company lines and ten lines at most; the jq slice of seven keeps the plain draw at seven, so it is the void draw that
#                shows seven where six are wanted; S5 names the four, so a dropped check is red as well); the parity drop-in holds the same cap against the
#                page's rules on its own documents (bt-many, bt-many-void, bt-many-active, bt-many-av).
# S1-S3, S6 and S7 run under sh and, when installed, dash as well (the device's shell is BusyBox ash, dash is the
# nearest thing a dev machine has; bash, which is what sh often is, runs its EXIT trap on SIGTERM by itself, dash
# does not, so S7 only means something for the TERM trap of the script under dash). S4, the bulk sweep, uses sh.

DST_PAY=library/user/reconnaissance/starchorus/starchorus-display.sh
DST_COPIES="root:starchorus-display.sh pay:$DST_PAY"
DST_D=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-dst.XXXXXX" 2>/dev/null) || { DST_D="$R/out/$P-dst"; rm -rf "$DST_D"; mkdir -p "$DST_D"; }
DST_BIN="$DST_D/bin"; DST_T="$DST_D/tmp"; mkdir -p "$DST_BIN" "$DST_T" "$DST_D/nojq"
DST_JQ=$(command -v jq); DST_SH=$(command -v sh); case $DST_SH in /*) ;; *) DST_SH=/bin/sh ;; esac
DST_MARK='jq incomplete on this device -- counts may be blank. Run: sh starchorus-display.sh --selftest'
DST_KEEP=0
DST_SHELLS="sh"; if command -v dash >/dev/null 2>&1; then DST_SHELLS="sh dash"; fi

cat > "$DST_BIN/jq" <<'DSTJQ'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- STARCHORUS_NRX / STARCHORUS_BREAK / STARCHORUS_HANG, see that file
set -u
REAL=${STARCHORUS_REAL_JQ:-}
[ -x "$REAL" ] || { echo "dst-jq: STARCHORUS_REAL_JQ is not an executable jq" >&2; exit 2; }
PRELUDE=
if [ "${STARCHORUS_NRX:-0}" = 1 ]; then
  PRELUDE='def _noregex: error("jq was compiled without ONIGURUMA regex library.\n             match/test/sub and related functions are not available.");
def test(a): _noregex; def test(a;b): _noregex;
def match(a): _noregex; def match(a;b): _noregex;
def capture(a): _noregex; def capture(a;b): _noregex;
def scan(a): _noregex; def scan(a;b): _noregex;
def split(a;b): _noregex;
def splits(a): _noregex; def splits(a;b): _noregex;
def sub(a;b): _noregex; def sub(a;b;c): _noregex;
def gsub(a;b): _noregex; def gsub(a;b;c): _noregex;
'
fi
if [ -n "${STARCHORUS_BREAK:-}" ]; then
  PRELUDE="$PRELUDE""def $STARCHORUS_BREAK(a): error(\"$STARCHORUS_BREAK is broken (simulated by the regress wrapper)\");
"
fi
if [ -n "${STARCHORUS_HANG:-}" ]; then
  case " $* " in *" -r "*)
    : > "$STARCHORUS_HANG"; n=0
    while [ ! -e "$STARCHORUS_HANG.go" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done ;;
  esac
fi
total=$#; i=0; seen=0
while [ "$i" -lt "$total" ]; do
  a=$1; shift; i=$((i + 1))
  case $a in
    -f|--from-file|--arg|--argjson|--args|--jsonargs|--slurpfile|--rawfile|-L|--indent|--)
      echo "dst-jq: $a is not modelled by this wrapper" >&2; exit 2 ;;
    -*) set -- "$@" "$a"; continue ;;
  esac
  if [ "$seen" = 0 ]; then seen=1; set -- "$@" "$PRELUDE$a"; else set -- "$@" "$a"; fi
done
exec "$REAL" "$@"
DSTJQ
chmod +x "$DST_BIN/jq"

dst_st() {  # dst_st TAG COPY [NRX] [BREAK] [SHELL]: the selftest -> $DST_D/TAG.out, exit status in DST_RC
  PATH="$DST_BIN:$PATH" STARCHORUS_NRX="${3:-0}" STARCHORUS_BREAK="${4:-}" STARCHORUS_REAL_JQ="$DST_JQ" TMPDIR="$DST_T" \
    "${5:-sh}" "$2" --selftest > "$DST_D/$1.out" 2>&1
  DST_RC=$?
}
dst_once() {  # dst_once TAG COPY SCREEN JSON [NRX] [BREAK] [SHELL]: one --once screen -> $DST_D/TAG.out
  PATH="$DST_BIN:$PATH" STARCHORUS_NRX="${5:-0}" STARCHORUS_BREAK="${6:-}" STARCHORUS_REAL_JQ="$DST_JQ" STARCHORUS_DISPLAY_PLAIN=1 \
    "${7:-sh}" "$2" --once "$3" "$4" > "$DST_D/$1.out" 2>&1
}
dst_read() {  # dst_read FILE: final line, PASS-line count, FAIL-line count of a selftest output
  DST_LAST=$(tail -n 1 "$1")
  DST_NP=$(grep -c '^\[display-selftest\]   PASS: ' "$1")
  DST_NF=$(grep -c '^\[display-selftest\]   FAIL: ' "$1")
}
dst_count() {  # dst_count DIR: how many selftest fixtures (mktemp starchorus-display-st.*) DIR holds
  _dst_c=0; for _dst_f in "$1"/starchorus-display-st.*; do [ -e "$_dst_f" ] && _dst_c=$((_dst_c + 1)); done; echo "$_dst_c"
}
dst_allpass() {  # dst_allpass FILE: 0 iff FILE is a complete ALL PASS run (exit 0, no FAIL, >= 40 checks, the summary adds up)
  dst_read "$1"
  [ "$DST_RC" = 0 ] && [ "$DST_NF" = 0 ] && [ "$DST_NP" -ge 40 ] \
    && [ "$DST_LAST" = "[display-selftest] SELFTEST: ALL PASS ($DST_NP checks)" ]
}

# ---- S1 / S2: ALL PASS under the real jq and under the device-like jq (no regex builtin is called)
DST_S1=0; DST_S2=0; DST_X1=0
for DST_X in $DST_SHELLS; do
  for DST_E in $DST_COPIES; do
    DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X1=$((DST_X1 + 1))
    dst_st "s1-$DST_G-$DST_X" "$DST_C" 0 "" "$DST_X"
    if dst_allpass "$DST_D/s1-$DST_G-$DST_X.out"; then DST_S1=$((DST_S1 + 1))
    else echo "    selftest, real jq, $DST_G copy, $DST_X: rc=$DST_RC last='$DST_LAST' pass=$DST_NP fail=$DST_NF"; fi
    dst_st "s2-$DST_G-$DST_X" "$DST_C" 1 "" "$DST_X"
    if dst_allpass "$DST_D/s2-$DST_G-$DST_X.out"; then DST_S2=$((DST_S2 + 1))
    else echo "    selftest, device-like jq, $DST_G copy, $DST_X: rc=$DST_RC last='$DST_LAST' pass=$DST_NP fail=$DST_NF"; fi
  done
done
if [ "$DST_S1" = "$DST_X1" ]; then row "display --selftest ALL PASS, real jq ($DST_NP checks x 2 copies x $DST_SHELLS)" PASS
else row "display --selftest on the real jq: $DST_S1/$DST_X1 runs pass" FAIL; DST_KEEP=1; fi
if [ "$DST_S2" = "$DST_X1" ]; then row "display --selftest ALL PASS, device-like jq without regex ($DST_X1 runs)" PASS
else row "display --selftest on the device-like jq: $DST_S2/$DST_X1 runs pass" FAIL; DST_KEEP=1; fi

# ---- S3: negative control -- one builtin (endswith) fails at call time
DST_S3=0; DST_X3=0
for DST_X in $DST_SHELLS; do
  for DST_E in $DST_COPIES; do
    DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_O="$DST_D/s3-$DST_G-$DST_X.out"; DST_X3=$((DST_X3 + 1))
    dst_st "s3-$DST_G-$DST_X" "$DST_C" 0 endswith "$DST_X"
    dst_read "$DST_O"
    DST_TOT=$((DST_NP + DST_NF)); DST_M=0
    for DST_S in summary top bands; do
      dst_once "s3-$DST_G-$DST_X-$DST_S" "$DST_C" "$DST_S" "$F/many-clients.json" 0 endswith "$DST_X"
      [ "$(grep -cxF "$DST_MARK" "$DST_D/s3-$DST_G-$DST_X-$DST_S.out")" = 1 ] && DST_M=$((DST_M + 1))
    done
    if [ "$DST_RC" = 1 ] && [ "$DST_NF" -ge 2 ] && [ "$DST_NP" -ge 30 ] && [ "$DST_M" = 3 ] \
       && [ "$DST_LAST" = "[display-selftest] SELFTEST: FAILED ($DST_NF of $DST_TOT)" ] \
       && grep -q '^\[display-selftest\]   FAIL: jq builtin endswith' "$DST_O" \
       && grep -qxF '[display-selftest]   PASS: jq builtin until' "$DST_O" \
       && grep -qxF '[display-selftest]   PASS: jq builtin index' "$DST_O" \
       && grep -qxF '[display-selftest]   PASS: jq builtin tostring' "$DST_O"; then DST_S3=$((DST_S3 + 1))
    else echo "    negative control, $DST_G copy, $DST_X: rc=$DST_RC last='$DST_LAST' pass=$DST_NP fail=$DST_NF marker on $DST_M/3 screens"; fi
  done
done
if [ "$DST_S3" = "$DST_X3" ]; then row "endswith broken: exit 1, FAIL names it, marker on 3 screens ($DST_X3 runs)" PASS
else row "negative control (endswith broken): $DST_S3/$DST_X3 runs as expected" FAIL; DST_KEEP=1; fi

# ---- S4: healthy jq -> no marker, real output, on every fixture, both jq builds, both copies
DST_CELL=0; DST_HIT=0; DST_EMPTY=0; DST_SANE=0; DST_FIX=0
for DST_J in "$F"/*.json; do
  DST_B=$(basename "$DST_J" .json); DST_FIX=$((DST_FIX + 1))
  for DST_E in $DST_COPIES; do
    DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}
    for DST_N in 0 1; do
      for DST_S in summary top bands; do
        DST_CELL=$((DST_CELL + 1)); DST_O="$DST_D/s4-$DST_G-$DST_N-$DST_B-$DST_S.out"
        dst_once "s4-$DST_G-$DST_N-$DST_B-$DST_S" "$DST_C" "$DST_S" "$DST_J" "$DST_N"
        grep -qF 'jq incomplete' "$DST_O" && { DST_HIT=$((DST_HIT + 1)); echo "    marker on a healthy jq: $DST_G nrx=$DST_N $DST_B/$DST_S"; }
        [ -s "$DST_O" ] || DST_EMPTY=$((DST_EMPTY + 1))
        # the summary must still carry real band counts ("2.4:<digit>"); empty-none legitimately has none
        if [ "$DST_S" = summary ]; then
          case $DST_B in empty-none) DST_SANE=$((DST_SANE + 1)) ;;
            *) grep -q '2\.4:[0-9]' "$DST_O" && DST_SANE=$((DST_SANE + 1)) ;;
          esac
        fi
      done
    done
  done
done
if [ "$DST_HIT" = 0 ] && [ "$DST_EMPTY" = 0 ] && [ "$DST_SANE" = $((DST_FIX * 4)) ] && [ "$DST_CELL" -ge 100 ]; then
  row "healthy jq: no marker on summary/top/bands ($DST_CELL cells, $DST_SANE summaries with counts)" PASS
else row "healthy jq: marker on $DST_HIT/$DST_CELL cells, $DST_EMPTY empty, counts $DST_SANE/$((DST_FIX * 4))" FAIL; DST_KEEP=1; fi

# ---- S5: vacuity guards -- the simulation bites, and the selftest cannot shrink unnoticed
DST_V1=$(STARCHORUS_NRX=1 STARCHORUS_REAL_JQ="$DST_JQ" "$DST_BIN/jq" -n '"abc"|test("b")' 2>&1); DST_C1=$?
DST_V2=$(STARCHORUS_NRX=0 STARCHORUS_REAL_JQ="$DST_JQ" "$DST_BIN/jq" -n '"abc"|test("b")' 2>&1); DST_C2=$?
DST_V3=$(STARCHORUS_BREAK=endswith STARCHORUS_REAL_JQ="$DST_JQ" "$DST_BIN/jq" -n '"a"|endswith("a")' 2>&1); DST_C3=$?
DST_V4=$(STARCHORUS_REAL_JQ="$DST_JQ" "$DST_BIN/jq" -n '"a"|endswith("a")' 2>&1); DST_C4=$?
case $DST_V1 in *"without ONIGURUMA"*) DST_W1=ok ;; *) DST_W1=missing ;; esac
case $DST_V3 in *"endswith is broken"*) DST_W3=ok ;; *) DST_W3=missing ;; esac
DST_MISS=""
for DST_B in endswith until index "string slice" tostring ascii_downcase ascii_upcase rtrimstr ltrimstr contains \
             startswith split/1 group_by sort_by unique add select "syntax // (alternative operator)" 'syntax '"\uXXXX escapes" \
             "add over strings"; do
  case $DST_B in "syntax "*) DST_PFX="PASS: jq $DST_B" ;; *) DST_PFX="PASS: jq builtin $DST_B" ;; esac
  grep -qF "$DST_PFX" "$DST_D/s1-root-sh.out" || DST_MISS="$DST_MISS [$DST_B]"
done
for DST_B in bandnorm secupper isopenwep sectag jq_healthy "screen_summary: band counters" "screen_summary: band counts" \
             "screen_summary: open/WEP" btlist btco bar8 actbar "screen_summary: the Bluetooth figure" "screen_bands: a band" \
             "screen_bluetooth: addresses" "screen_bluetooth: the strongest company" "screen_bluetooth: the cap on eleven companies, plain:" \
             "screen_bluetooth: the cap on eleven companies, a void window:" "screen_bluetooth: the cap on eleven companies, the ACTIVE claim:" \
             "screen_bluetooth: the cap on eleven companies, a void window under the ACTIVE claim:"; do
  grep -qF "PASS: $DST_B" "$DST_D/s1-root-sh.out" || DST_MISS="$DST_MISS [$DST_B]"
done
if [ "$DST_C1/$DST_C2/$DST_V2/$DST_W1" = 5/0/true/ok ] && [ "$DST_C3/$DST_C4/$DST_V4/$DST_W3" = 5/0/true/ok ] && [ -z "$DST_MISS" ]; then
  row "wrappers bite (nrx 5/0, break 5/0); selftest has every probe" PASS
else
  row "vacuity: nrx $DST_C1/$DST_C2/$DST_V2/$DST_W1, break $DST_C3/$DST_C4/$DST_V4/$DST_W3, missing:$DST_MISS" FAIL; DST_KEEP=1
fi

# ---- S6: no jq on PATH -> the selftest still reports (not the err_dialog + exit 1 of a normal run)
DST_S6=0; DST_X6=0
for DST_X in $DST_SHELLS; do
  DST_XP=$(command -v "$DST_X"); case $DST_XP in /*) ;; *) DST_XP=$DST_SH ;; esac
  for DST_E in $DST_COPIES; do
    DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_O="$DST_D/s6-$DST_G-$DST_X.out"; DST_X6=$((DST_X6 + 1))
    env PATH="$DST_D/nojq" "$DST_XP" "$DST_C" --selftest > "$DST_O" 2>&1; DST_RC=$?
    if [ "$DST_RC" = 1 ] && grep -qxF '[display-selftest]   FAIL: jq present' "$DST_O" \
       && [ "$(tail -n 1 "$DST_O")" = '[display-selftest] SELFTEST: FAILED (1 of 1)' ] && ! grep -q 'ERROR' "$DST_O"; then
      DST_S6=$((DST_S6 + 1))
    else echo "    no-jq selftest, $DST_G copy, $DST_X: rc=$DST_RC, $(wc -l < "$DST_O" | tr -d ' ') line(s)"; fi
  done
done
if [ "$DST_S6" = "$DST_X6" ]; then row "selftest without jq: FAIL jq present, FAILED (1 of 1), exit 1 ($DST_X6 runs)" PASS
else row "selftest without jq: $DST_S6/$DST_X6 runs as expected" FAIL; DST_KEEP=1; fi

# ---- S7: the mktemp fixture is removed after a run and after SIGTERM in the middle of one
DST_LEFT=0; DST_LIVE=0; DST_TERM=0; DST_PIDS=""; DST_X7=0
for DST_X in $DST_SHELLS; do
  for DST_E in $DST_COPIES; do
    DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_TAG="$DST_G-$DST_X"; DST_X7=$((DST_X7 + 1))
    mkdir -p "$DST_T/$DST_TAG-a" "$DST_T/$DST_TAG-b"
    PATH="$DST_BIN:$PATH" STARCHORUS_REAL_JQ="$DST_JQ" TMPDIR="$DST_T/$DST_TAG-a" "$DST_X" "$DST_C" --selftest > /dev/null 2>&1
    DST_LEFT=$((DST_LEFT + $(dst_count "$DST_T/$DST_TAG-a")))
    rm -f "$DST_D/hang-$DST_TAG" "$DST_D/hang-$DST_TAG.go"
    PATH="$DST_BIN:$PATH" STARCHORUS_REAL_JQ="$DST_JQ" TMPDIR="$DST_T/$DST_TAG-b" STARCHORUS_HANG="$DST_D/hang-$DST_TAG" \
      "$DST_X" "$DST_C" --selftest > "$DST_D/s7-$DST_TAG.out" 2>&1 &
    DST_PIDS="$DST_PIDS $DST_TAG:$!"
  done
done
for DST_E in $DST_PIDS; do   # each is held in the wrapper once it has its fixture: count it, then send TERM
  DST_TAG=${DST_E%%:*}; DST_P=${DST_E#*:}; DST_W=0
  while [ ! -e "$DST_D/hang-$DST_TAG" ] && [ "$DST_W" -lt 100 ]; do sleep 0.1; DST_W=$((DST_W + 1)); done
  DST_LIVE=$((DST_LIVE + $(dst_count "$DST_T/$DST_TAG-b")))
  kill -TERM "$DST_P" 2>/dev/null
  : > "$DST_D/hang-$DST_TAG.go"   # release the wrapper; the shell only runs its TERM trap once that child is done
done
for DST_E in $DST_PIDS; do
  DST_TAG=${DST_E%%:*}; DST_P=${DST_E#*:}
  wait "$DST_P"; DST_RC=$?
  [ "$DST_RC" = 143 ] && DST_TERM=$((DST_TERM + 1))
  DST_LEFT=$((DST_LEFT + $(dst_count "$DST_T/$DST_TAG-b")))
done
if [ "$DST_LEFT" = 0 ] && [ "$DST_LIVE" = "$DST_X7" ] && [ "$DST_TERM" = "$DST_X7" ]; then
  row "selftest fixture removed after a run and after SIGTERM ($DST_X7 runs, $DST_SHELLS)" PASS
else row "selftest fixture: $DST_LEFT left over, $DST_LIVE/$DST_X7 existed at the signal, $DST_TERM/$DST_X7 exit 143" FAIL; DST_KEEP=1; fi

# ---- S8: no regex-builtin call in either display script copy, also after joining the shell's '' pairs
DST_RX1='(^|[^A-Za-z0-9_.])(test|match|sub|gsub|capture|scan|splits)[[:space:]]*\('   # = JQR_RE of jq-noregex.sh R1
DST_RX2='(^|[^A-Za-z0-9_.])split[[:space:]]*\([^)]*;'                                     # = JQR_RE2
# detector self-check: a split call on a code line is found, the same text in a comment line is not
DST_DET=$(printf '%s\n' "  jq -n '\"a\" | te''st(\"b\")'" "  # jq -n '\"a\" | te''st(\"b\")'" \
          | sed "s/''//g" | grep -nE "$DST_RX1|$DST_RX2" | grep -vE '^[0-9]+:[[:space:]]*#' | cut -d: -f1 | tr '\n' ' ')
DST_S8=0; DST_X8=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X8=$((DST_X8 + 1))
  DST_H=$(sed "s/''//g" "$DST_C" | grep -nE "$DST_RX1|$DST_RX2" | grep -vE '^[0-9]+:[[:space:]]*#')
  DST_HN=$(printf '%s' "$DST_H" | grep -c .)
  if [ "$DST_DET" = "1 " ] && [ "$DST_HN" = 0 ]; then DST_S8=$((DST_S8 + 1))
  else
    echo "    no-regex pin, $DST_G copy: $DST_HN call site(s) after joining '' pairs (want 0), detector '$DST_DET' (want '1 ')"
    [ -z "$DST_H" ] || printf '%s\n' "$DST_H" | sed 's|^|      line |'
  fi
done
if [ "$DST_S8" = "$DST_X8" ]; then row "display: no regex-builtin call, also after joining '' pairs ($DST_X8 copies)" PASS
else row "display no-regex pin: $DST_S8/$DST_X8 copies as expected" FAIL; DST_KEEP=1; fi

# ---- stand-ins of the device for S9 to S16 (generated): its LOG, LIST_PICKER and WAIT_FOR_INPUT, so that the script takes its device path
# (it detects the device by LIST_PICKER), a counting "jq" in front of the real one, and the missing "stat".
#   WAIT_FOR_INPUT answers one word of STARCHORUS_KEYS per call ("-", or no word left, = no answer at once, as a broken key path would
#   behave). The Overview starts it in the BACKGROUND before it draws, and a draw ends with the first key that has come (it prints
#   nothing more and ends the jq that is running), so WHEN the stand-in answers decides what a row sees. A plain word is a press made
#   after the screen is complete, as a person's is: the stand-in first waits until the frame of the draw it was armed for is out, when
#   that pass draws at all (the first, after A, a, LEFT or RIGHT, after a row was picked from the list, and after an early Up, Down or
#   junk word that ended a draw: a pass that follows Up, Down or junk that came late draws nothing). Frames are counted in
#   STARCHORUS_OUT, the Overview's output, against the count at the end of the call before. A word with a leading "!" is a press made at
#   once, wherever the draw is; one with a leading "@" a press made at "Reading...": it waits until the jq stand-in has started the
#   screen's program (STARCHORUS_JQ_STARTED exists) and answers then. Both end the draw they come in; rows that use them make the draw
#   long (the "sleepjq" stand-in), so that the answer lands inside it every time. It records its pid (one line per call) in
#   STARCHORUS_PIDS. At call number STARCHORUS_SWAP_AT it replaces the capture atomically (copy, then rename), as the collector does
#   (STARCHORUS_SWAP_TARGET: the file that is replaced when the Overview reads it through a link), after the wait for the frame, so the
#   swap falls between two draws and not into one. STARCHORUS_GAPS (a file, one number of hundredths of a second per call) moves the
#   uptime file under STARCHORUS_PROC on by that much before it answers, so the script sees a key that took that long.
#   STARCHORUS_PAD=1: every answer comes padded as a device may print it, spaces and a tab around the word and a CR at the end.
#   STARCHORUS_HOLD_AT=N: call N never answers, it becomes `sleep 30` (the same pid), a waiter nobody presses a key for.
#   STARCHORUS_KILL_AT=N with STARCHORUS_KILL_PID (a file): call N ends that process (the fake payload), and waits until it is gone,
#   before it answers. STARCHORUS_SABOTAGE_AT=N: call N makes the Overview's key file read-only (the shell cannot write the answer, as
#   on a full file system), then answers.
#   LIST_PICKER writes its arguments to the UI log and answers a line of STARCHORUS_PICKS (no line = exit 0 and no answer, a cancel); an
#   answer marks that the next pass draws (the wait for the frame). ERROR_DIALOG writes its text to the UI log.
#   Four "timeout" stand-ins live in directories of their own and join the PATH only where a row asks for one (macOS has no timeout):
#   tmolog logs the command word and runs the command, tmokill also ends the command after the time and answers 124 as GNU and BusyBox
#   do, tmofork runs the command as a child and waits for it, and does NOT end it when it is itself ended (the worst case of the
#   unknown implementation: a `timeout` that leaves its command running).
mkdir -p "$DST_D/cnt" "$DST_D/dev9" "$DST_D/tmolog" "$DST_D/tmokill" "$DST_D/tmofork" "$DST_D/slowjq" "$DST_D/sleepjq" "$DST_D/killjq" "$DST_D/noproc" "$DST_D/rodir" "$DST_D/forkcnt"
cat > "$DST_D/cnt/jq" <<'DSTCNT'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- one line per jq process, then the real jq
echo x >> "${STARCHORUS_JQ_COUNT:?}"
exec "${STARCHORUS_REAL_JQ:?}" "$@"
DSTCNT
cat > "$DST_D/slowjq/jq" <<'DSTSLOW'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- one line per jq process; the program run of a screen (the "-r" call) takes 3 s, the health probe does not
echo x >> "${STARCHORUS_JQ_COUNT:?}"
case " $* " in *" -r "*) exec sleep 3 ;; esac
exec "${STARCHORUS_REAL_JQ:?}" "$@"
DSTSLOW
cat > "$DST_D/sleepjq/jq" <<'DSTSLEEP'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- one line per jq process; the program run of a screen (the "-r" call) says it has
# started (STARCHORUS_JQ_STARTED is touched; the "@" key words wait for that), notes its pid in STARCHORUS_JQ_PIDS, sleeps
# STARCHORUS_JQ_SLEEP seconds (1 by default) and then runs the real jq. A TERM ends it at once and is noted in
# STARCHORUS_JQ_STARTED.killed (the sleep is waited for, so the trap runs now and not after the sleep); a sleep that is ended from
# outside (the Overview ends the children of a `timeout` first) ends it too. The health probe (no "-r") does not sleep.
echo x >> "${STARCHORUS_JQ_COUNT:?}"
case " $* " in *" -r "*)
  [ -z "${STARCHORUS_JQ_PIDS:-}" ] || echo "$$" >> "$STARCHORUS_JQ_PIDS"
  [ -z "${STARCHORUS_JQ_STARTED:-}" ] || : > "$STARCHORUS_JQ_STARTED"
  sleep "${STARCHORUS_JQ_SLEEP:-1}" & sp=$!
  trap '[ -z "${STARCHORUS_JQ_STARTED:-}" ] || : > "$STARCHORUS_JQ_STARTED.killed"; kill "$sp" 2>/dev/null; exit 143' TERM
  wait "$sp" || { [ -z "${STARCHORUS_JQ_STARTED:-}" ] || : > "$STARCHORUS_JQ_STARTED.killed"; exit 143; } ;;
esac
exec "${STARCHORUS_REAL_JQ:?}" "$@"
DSTSLEEP
cat > "$DST_D/killjq/jq" <<'DSTKILL'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- a jq that is killed from outside (the out-of-memory killer): the program run of a screen (the "-r" call) ends with 137, the health probe does not
case " $* " in *" -r "*) exit 137 ;; esac
exec "${STARCHORUS_REAL_JQ:?}" "$@"
DSTKILL
cat > "$DST_D/dev9/LOG" <<'DSTLOG'
#!/bin/sh
c=; case "$1" in red|blue) c="[$1]"; shift;; esac; printf 'LOG%s %s\n' "$c" "$*"
DSTLOG
cat > "$DST_D/dev9/LIST_PICKER" <<'DSTPICK'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- the arguments to the UI log, then the answer of line N of STARCHORUS_PICKS, if any
{ printf 'PICKER'; for a in "$@"; do printf '|%s' "$a"; done; echo; } >> "${STARCHORUS_UI_LOG:-/dev/null}"
n=$(cat "${STARCHORUS_PICKS_N:-/dev/null}" 2>/dev/null || echo 0); n=$((n + 1)); [ -z "${STARCHORUS_PICKS_N:-}" ] || echo "$n" > "$STARCHORUS_PICKS_N"
a=; [ -z "${STARCHORUS_PICKS:-}" ] || a=$(sed -n "${n}p" "$STARCHORUS_PICKS")
[ -z "$a" ] || { : > "${STARCHORUS_CALLS:?}.picked"; printf '%s\n' "$a"; }   # a row was picked: the next pass draws
exit 0
DSTPICK
cat > "$DST_D/dev9/ERROR_DIALOG" <<'DSTERR'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- the text to the UI log
echo "ERROR $*" >> "${STARCHORUS_UI_LOG:-/dev/null}"
exit 0
DSTERR
cat > "$DST_D/dev9/WAIT_FOR_INPUT" <<'DSTWAIT'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- see the comment above it there
echo "$$" >> "${STARCHORUS_PIDS:-/dev/null}"
n=$(cat "${STARCHORUS_CALLS:?}" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$STARCHORUS_CALLS"
echo "WAIT $n" >> "${STARCHORUS_UI_LOG:-/dev/null}"
[ "$n" != "${STARCHORUS_HOLD_AT:-0}" ] || exec sleep 30
k=$(sed -n "${n}p" "${STARCHORUS_KEYS:?}")
pk=; [ "$n" -le 1 ] || pk=$(sed -n "$(($n - 1))p" "$STARCHORUS_KEYS")
# when is the press made: "!" at once, "@" once the jq of the screen's program runs, else after the draw this wait was armed for
when=late; case $k in '!'*) when=now; k=${k#!} ;; '@'*) when=jq; k=${k#@} ;; esac
pwhen=late; case $pk in '!'*) pwhen=now; pk=${pk#!} ;; '@'*) pwhen=jq; pk=${pk#@} ;; esac
fc() { grep -c '^LOG A: Refresh   B: Back$' "${STARCHORUS_OUT:?}"; }
fp=$(cat "$STARCHORUS_CALLS.fc" 2>/dev/null || echo 0)   # frames out when the call before ended
# does this pass draw? the first one; after A, a, LEFT, RIGHT; after a row was picked; after an early Up, Down or junk (it cut the draw it came in)
due=0
if [ "$n" -le 1 ] || [ -e "$STARCHORUS_CALLS.picked" ]; then due=1
else case $pk in A|a|LEFT|RIGHT) due=1 ;; *) [ "$pwhen" = late ] || due=1 ;; esac; fi
rm -f "$STARCHORUS_CALLS.picked"
case $when in
  late) if [ "$due" = 1 ]; then w=0; while [ "$(fc)" -le "$fp" ] && [ "$w" -lt 400 ]; do sleep 0.05; w=$((w + 1)); done; fi ;;
  jq)   w=0; while [ ! -e "${STARCHORUS_JQ_STARTED:?}" ] && [ "$w" -lt 400 ]; do sleep 0.05; w=$((w + 1)); done ;;
esac
t=${STARCHORUS_SWAP_TARGET:-$STARCHORUS_JSON}
if [ "$n" = "${STARCHORUS_SWAP_AT:-0}" ]; then cp "$STARCHORUS_SWAP_WITH" "$t.new" && mv "$t.new" "$t"; fi
if [ "$n" = "${STARCHORUS_KILL_AT:-0}" ]; then
  p=$(cat "${STARCHORUS_KILL_PID:?}"); kill "$p" 2>/dev/null
  w=0; while kill -0 "$p" 2>/dev/null && [ "$w" -lt 100 ]; do sleep 0.05; w=$((w + 1)); done
fi
if [ "$n" = "${STARCHORUS_SABOTAGE_AT:-0}" ]; then for d in "${TMPDIR:-/tmp}"/starchorus-ov.*/key; do chmod 444 "$d" 2>/dev/null; done; fi
if [ -n "${STARCHORUS_GAPS:-}" ] && [ -r "${STARCHORUS_PROC:-/nonexistent}/uptime" ]; then
  g=$(sed -n "${n}p" "$STARCHORUS_GAPS"); g=${g:-0}
  read -r u _ < "$STARCHORUS_PROC/uptime"; i=${u%%.*}; f=${u#*.}; cs=$((i * 100 + ${f#0} + g))
  printf '%d.%02d 0.00\n' $((cs / 100)) $((cs % 100)) > "$STARCHORUS_PROC/uptime"
fi
fc > "$STARCHORUS_CALLS.fc"
if [ -n "$k" ] && [ "$k" != - ]; then if [ -n "${STARCHORUS_PAD:-}" ]; then printf ' \t%s \t\r\n' "$k"; else echo "$k"; fi; fi
exit 0
DSTWAIT
cat > "$DST_D/tmolog/timeout" <<'DSTTMOLOG'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- timeout SECS CMD...: logs CMD's name, runs it
echo "$2" >> "${STARCHORUS_TMO_LOG:?}"
shift
exec "$@"
DSTTMOLOG
cat > "$DST_D/tmokill/timeout" <<'DSTTMOKILL'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- timeout SECS CMD...: logs CMD's name, runs it, sends TERM after SECS seconds; 124 then
echo "$2" >> "${STARCHORUS_TMO_LOG:?}"
t=$1; shift
"$@" &
p=$!
( sleep "$t"; : > "$STARCHORUS_TMO_LOG.hit"; kill "$p" 2>/dev/null ) > /dev/null 2>&1 &
w=$!
wait "$p"; rc=$?
kill "$w" 2>/dev/null
if [ -e "$STARCHORUS_TMO_LOG.hit" ]; then rm -f "$STARCHORUS_TMO_LOG.hit"; exit 124; fi
exit "$rc"
DSTTMOKILL
cat > "$DST_D/tmofork/timeout" <<'DSTTMOFORK'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- timeout SECS CMD...: runs CMD as a child and waits for it. Ended with TERM it dies at once
# and leaves CMD running (no forwarding), the worst case of a `timeout` whose implementation nobody measured. STARCHORUS_TMO_PIDS gets its own
# pid (one line per call), so a row can see whether it outlived the Overview.
shift
[ -z "${STARCHORUS_TMO_PIDS:-}" ] || echo "$$" >> "$STARCHORUS_TMO_PIDS"
"$@" &
wait "$!"
DSTTMOFORK
cat > "$DST_D/rodir/mktemp" <<'DSTRO'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- the real `mktemp -d`, then the directory is made read-only: the Overview's first write into it fails
d=$(PATH=${STARCHORUS_REAL_PATH:?} mktemp "$@") || exit 1
chmod 555 "$d"
echo "$d"
DSTRO
for DST_T in sed cut; do
  cat > "$DST_D/forkcnt/$DST_T" <<DSTFC
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- notes that a process was started for $DST_T, then runs the real one
echo $DST_T >> "\${STARCHORUS_FORK_LOG:?}"
exec "\$(PATH=\$STARCHORUS_REAL_PATH command -v $DST_T)" "\$@"
DSTFC
done
cat > "$DST_D/payload" <<'DSTPAYLOAD'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- a fake payload: it records its pid (STARCHORUS_KILL_PID), runs the Overview as its CHILD
# with its own pid as STARCHORUS_PARENT_PID, and waits for it. Used as the shell of dst_ov (DST_OVSH) by the row that ends the payload
echo "$$" > "${STARCHORUS_KILL_PID:?}"
STARCHORUS_PARENT_PID=$$ sh "$@"
exit $?
DSTPAYLOAD
cat > "$DST_D/dev9/stat" <<'DSTSTAT'
#!/bin/sh
echo "$*" >> "${STARCHORUS_STAT_LOG:?}"
exit 1
DSTSTAT
chmod +x "$DST_D/cnt/jq" "$DST_D/slowjq/jq" "$DST_D/sleepjq/jq" "$DST_D/killjq/jq" "$DST_D/dev9/LOG" "$DST_D/dev9/LIST_PICKER" "$DST_D/dev9/WAIT_FOR_INPUT" "$DST_D/dev9/ERROR_DIALOG" "$DST_D/dev9/stat" "$DST_D/payload" \
         "$DST_D/tmolog/timeout" "$DST_D/tmokill/timeout" "$DST_D/tmofork/timeout" "$DST_D/rodir/mktemp" "$DST_D/forkcnt/sed" "$DST_D/forkcnt/cut"

# dst_ov TAG COPY "KEYS" [VAR=value ...]: the Overview of COPY on the device path against the stand-ins, one answer per word of KEYS. Files
# in $DST_D: TAG.out (what it LOGged), TAG.ui (the UI commands it called, in order), TAG.calls (how many times it waited), TAG.pids (the pid of
# each waiter), TAG.jq (one line per jq process), TAG.stat, TAG.json (the capture: a copy of $DST_OVSRC, else many-clients.json), TAG.tmp (the
# TMPDIR of the run: the Overview's own temp dir lives there, and DST_OVLEFT adds up what a run left in it). The PATH is $DST_OVPATH in front of
# the stand-ins; the extra VAR=value words go to the script's environment last, so they override; the shell is $DST_OVSH, else sh.
# STARCHORUS_PROC points at an empty directory unless a row says otherwise: no /proc/uptime, no clock, so a Linux dev machine's own uptime
# cannot make the script judge an answer by time. Exit status in DST_RC.
DST_OVLEFT=0; DST_OVRUNS=0
dst_ovleft() { _dst_c=0; for _dst_f in "$1"/starchorus-ov.*; do [ -e "$_dst_f" ] && _dst_c=$((_dst_c + 1)); done; echo "$_dst_c"; }   # dst_ovleft DIR: Overview temp dirs in DIR
dst_ov() {
  _o_t=$1; _o_c=$2; _o_k=$3; shift 3
  # shellcheck disable=SC2086   # one answer per word, on purpose
  printf '%s\n' $_o_k > "$DST_D/$_o_t.keys"
  rm -f "$DST_D/$_o_t.calls" "$DST_D/$_o_t.pids"; : > "$DST_D/$_o_t.ui"; : > "$DST_D/$_o_t.jq"; : > "$DST_D/$_o_t.stat"
  rm -rf "$DST_D/$_o_t.tmp"; mkdir -p "$DST_D/$_o_t.tmp"
  cp "${DST_OVSRC:-$F/many-clients.json}" "$DST_D/$_o_t.json"
  env PATH="${DST_OVPATH:+$DST_OVPATH:}$DST_D/dev9:$DST_D/cnt:$PATH" STARCHORUS_REAL_JQ="$DST_JQ" STARCHORUS_JQ_COUNT="$DST_D/$_o_t.jq" \
      STARCHORUS_KEYS="$DST_D/$_o_t.keys" STARCHORUS_CALLS="$DST_D/$_o_t.calls" STARCHORUS_UI_LOG="$DST_D/$_o_t.ui" \
      STARCHORUS_OUT="$DST_D/$_o_t.out" STARCHORUS_PIDS="$DST_D/$_o_t.pids" TMPDIR="$DST_D/$_o_t.tmp" \
      STARCHORUS_STAT_LOG="$DST_D/$_o_t.stat" STARCHORUS_JSON="$DST_D/$_o_t.json" STARCHORUS_DIR="$DST_D/none" \
      STARCHORUS_PROC="$DST_D/noproc" "$@" "${DST_OVSH:-sh}" "$_o_c" > "$DST_D/$_o_t.out" 2>&1
  DST_RC=$?
  DST_OVRUNS=$((DST_OVRUNS + 1)); DST_OVLEFT=$((DST_OVLEFT + $(dst_ovleft "$DST_D/$_o_t.tmp")))
}
dst_alive() {   # dst_alive FILE: how many of the pids listed in FILE (one per line) are still there
  _dst_n=0; [ -r "$1" ] || { echo 0; return; }
  while read -r _dst_p; do if [ -n "$_dst_p" ] && kill -0 "$_dst_p" 2>/dev/null; then _dst_n=$((_dst_n + 1)); fi; done < "$1"
  echo "$_dst_n"
}
dst_cnt() { grep -cxF "$1" "$2"; }   # dst_cnt LINE FILE: how many lines of FILE are exactly LINE
dst_ui() { grep -c "^$1" "$DST_D/$2.ui"; }   # dst_ui WORD TAG: how many UI calls of that kind (WAIT, PICKER) the run made
dst_views() {   # dst_views FILE: the screens drawn, in order, one letter each: s summary, t top, b bands, d devices, p probes, c clients, l Bluetooth LE, a air
  sed -n -e 's/^LOG\[blue\] Starchorus  ~  .*/s/p' -e 's/^LOG\[blue\] Strongest networks (GEN .*/t/p' -e 's/^LOG\[blue\] Bands & security (GEN .*/b/p' \
         -e 's/^LOG\[blue\] Logical grouping (GEN .*/d/p' -e 's/^LOG\[blue\] Probe requests (GEN .*/p/p' -e 's/^LOG\[blue\] Stations (GEN .*/c/p' \
         -e 's/^LOG\[blue\] Bluetooth LE (GEN .*/l/p' -e 's/^LOG\[blue\] Air quality (GEN .*/a/p' "$1" | tr -d '\n'
}
DST_HUB="PICKER|Overview|Summary|Strongest Networks|Bands & Security|Devices & Merges|Probe Requests|Stations|Bluetooth|Air Quality"

# ---- S9: one jq process per screen render, none while the capture is unchanged; keys, not a timer, drive the Overview
# (a) --once: summary / top / bands = the probe + the program, every other screen = the program. (b) the Overview: A four times, the capture
# replaced at the third wait (a new `generated`, the same size; the stand-in does it after the third draw, so the fourth is the first to see
# it), then B; once with the file itself and once through a symlink to it. A logging "timeout" is in front of jq's real path: the two program
# runs go through it (the probe does not), and no UI command ever does.
DST_S9=0; DST_X9=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X9=$((DST_X9 + 1)); DST_T9="$DST_D/s9-$DST_G"
  # (a) --once: summary / top / bands = the probe + the program, every other screen = the program
  DST_W9=""
  for DST_S in summary top bands devices probes clients bluetooth air; do
    : > "$DST_T9.jq"
    PATH="$DST_D/cnt:$PATH" STARCHORUS_JQ_COUNT="$DST_T9.jq" STARCHORUS_REAL_JQ="$DST_JQ" STARCHORUS_DISPLAY_PLAIN=1 \
      sh "$DST_C" --once "$DST_S" "$F/many-clients.json" > /dev/null 2>&1
    DST_N9=$(grep -c x "$DST_T9.jq")
    case $DST_S in summary|top|bands) DST_WANT=2 ;; *) DST_WANT=1 ;; esac
    [ "$DST_N9" = "$DST_WANT" ] || DST_W9="$DST_W9 $DST_S=$DST_N9(want $DST_WANT)"
  done
  # (b) the Overview: five renders, the capture replaced before the fourth, once with the file itself and once through a symlink to it
  jq -c . "$F/few-clients.json" > "$DST_T9.base"; jq -c '.generated += 30' "$F/few-clients.json" > "$DST_T9.next"
  DST_L9=""
  for DST_V in file link; do
    DST_TG="s9-$DST_G-$DST_V"; rm -f "$DST_D/$DST_TG.lnk"; : > "$DST_D/$DST_TG.tmo"
    DST_J9="$DST_D/$DST_TG.json"
    if [ "$DST_V" = link ]; then ln -s "$DST_TG.json" "$DST_D/$DST_TG.lnk"; DST_J9="$DST_D/$DST_TG.lnk"; fi
    DST_OVSRC="$DST_T9.base"; DST_OVPATH="$DST_D/tmolog"
    dst_ov "$DST_TG" "$DST_C" "A A A A B" STARCHORUS_SWAP_AT=3 STARCHORUS_SWAP_WITH="$DST_T9.next" STARCHORUS_SWAP_TARGET="$DST_D/$DST_TG.json" \
      STARCHORUS_JSON="$DST_J9" STARCHORUS_TMO_LOG="$DST_D/$DST_TG.tmo"
    DST_OVSRC=; DST_OVPATH=
    DST_O="$DST_D/$DST_TG.out"
    DST_N9=$(grep -c x "$DST_D/$DST_TG.jq")
    DST_GENS=$(sed -n 's/^LOG GEN \([0-9][0-9]*\) .*/\1/p' "$DST_O" | tr '\n' ' ')
    DST_R9=$(grep -c '^LOG\[blue\] Starchorus  ~  ' "$DST_O")
    DST_P9=$(grep -c . "$DST_D/$DST_TG.stat")
    DST_B9=$(dst_cnt 'LOG Reading...' "$DST_O")
    DST_K9=$(grep -c . "$DST_D/$DST_TG.tmo"); DST_K9J=$(grep -cx jq "$DST_D/$DST_TG.tmo")
    DST_UW=$(dst_ui WAIT "$DST_TG"); DST_UP=$(dst_ui PICKER "$DST_TG")
    # the probe on first use, then the program for the first capture and for the replaced one = 3 jq processes in 5 renders (the time
    # of the scan is shell arithmetic, no jq of its own); "Reading..." with the first draw and with the one on the new capture; the two
    # program runs under timeout and nothing else under it; five waits (four answers A, then B), the list opened once (and it leaves); stat once
    if [ "$DST_RC/$DST_N9/$DST_R9/$DST_GENS/$DST_P9/$DST_B9/$DST_K9/$DST_K9J/$DST_UW/$DST_UP" != "0/3/5/1 1 1 2 2 /1/2/2/2/5/1" ]; then
      DST_L9="$DST_L9 $DST_V: rc $DST_RC, $DST_N9 jq (want 3), $DST_R9 renders (want 5), GEN '$DST_GENS' (want '1 1 1 2 2 '), $DST_P9 stat probes (want 1), $DST_B9 Reading... (want 2), timeout calls $DST_K9 of which jq $DST_K9J (want 2 and 2), $DST_UW waits (want 5), $DST_UP lists (want 1);"
    fi
  done
  if [ -z "$DST_W9" ] && [ -z "$DST_L9" ]; then DST_S9=$((DST_S9 + 1))
  else echo "    one-jq, $DST_G copy: --once off by:${DST_W9:- none}; loop:${DST_L9:- ok}"; fi
done
if [ "$DST_S9" = "$DST_X9" ]; then row "display: one jq per screen render, none for the same capture drawn again, also for a same-size replacement and a symlink; Reading... twice, no timeout before WAIT_FOR_INPUT (3 jq, 5 renders, GEN 1 1 1 2 2, $DST_X9 copies)" PASS
else row "display one-jq: $DST_S9/$DST_X9 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S10: a capture jq cannot read in time (a jq that sleeps 3 s, a cap of 1 s, a "timeout" that ends it with 124): the two slow lines instead
# of numbers, "Reading..." once, the frame, and the verdict is kept: A on the same file draws the lines again and starts no second jq
DST_S10=0; DST_X10=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X10=$((DST_X10 + 1)); DST_L10=""
  DST_OVPATH="$DST_D/tmokill:$DST_D/slowjq"
  for DST_K in "B:1" "A A B:3"; do
    DST_KS=${DST_K%:*}; DST_ND=${DST_K#*:}; DST_TG="s10-$DST_G-$DST_ND"; : > "$DST_D/$DST_TG.tmo"
    dst_ov "$DST_TG" "$DST_C" "$DST_KS" STARCHORUS_JQ_CAP=1 STARCHORUS_TMO_LOG="$DST_D/$DST_TG.tmo"
    DST_O="$DST_D/$DST_TG.out"
    DST_A1=$(dst_cnt 'LOG This scan took over 20 s to read.' "$DST_O"); DST_A2=$(dst_cnt 'LOG Try Settings > Show Last: 1 h.' "$DST_O")
    DST_AW=$(dst_cnt 'LOG Waiting for the first scan.' "$DST_O"); DST_AB=$(dst_cnt 'LOG Reading...' "$DST_O")
    DST_AF=$(dst_cnt 'LOG A: Refresh   B: Back' "$DST_O"); DST_AJ=$(grep -c x "$DST_D/$DST_TG.jq"); DST_AK=$(grep -c . "$DST_D/$DST_TG.tmo")
    # one health probe and one capped program run, however many draws; each draw: both lines, the frame
    if [ "$DST_RC/$DST_A1/$DST_A2/$DST_AW/$DST_AB/$DST_AF/$DST_AJ/$DST_AK" != "0/$DST_ND/$DST_ND/0/1/$DST_ND/2/1" ]; then
      DST_L10="$DST_L10 [$DST_KS] rc $DST_RC, slow lines $DST_A1/$DST_A2 (want $DST_ND), waiting $DST_AW (want 0), Reading... $DST_AB (want 1), frames $DST_AF (want $DST_ND), jq $DST_AJ (want 2), timeout $DST_AK (want 1);"
    fi
  done
  DST_OVPATH=
  # a jq killed from outside (exit 137): without the limit (--once) it is no data, the waiting line and not the slow lines; under it, in the
  # Overview, it is the slow verdict. The --once run goes through the real PATH on purpose: with or without a `timeout` on the box it sets none.
  DST_TG="s10k-$DST_G"
  env PATH="$DST_D/killjq:$PATH" STARCHORUS_REAL_JQ="$DST_JQ" STARCHORUS_DISPLAY_PLAIN=1 STARCHORUS_DIR="$DST_D/none" sh "$DST_C" --once summary "$F/many-clients.json" > "$DST_D/$DST_TG.out" 2>&1
  DST_A1=$(dst_cnt 'This scan took over 20 s to read.' "$DST_D/$DST_TG.out"); DST_AW=$(dst_cnt 'Waiting for the first scan.' "$DST_D/$DST_TG.out")
  [ "$DST_A1/$DST_AW" = 0/1 ] || DST_L10="$DST_L10 [--once, jq killed with 137] slow lines $DST_A1 (want 0), waiting $DST_AW (want 1);"
  DST_OVPATH="$DST_D/tmolog:$DST_D/killjq"; DST_TG="s10l-$DST_G"; : > "$DST_D/$DST_TG.tmo"
  dst_ov "$DST_TG" "$DST_C" "B" STARCHORUS_JQ_CAP=1 STARCHORUS_TMO_LOG="$DST_D/$DST_TG.tmo"
  DST_OVPATH=
  DST_A1=$(dst_cnt 'LOG This scan took over 20 s to read.' "$DST_D/$DST_TG.out"); DST_AW=$(dst_cnt 'LOG Waiting for the first scan.' "$DST_D/$DST_TG.out")
  [ "$DST_RC/$DST_A1/$DST_AW" = 0/1/0 ] || DST_L10="$DST_L10 [Overview, jq killed with 137 under timeout] rc $DST_RC, slow lines $DST_A1 (want 1), waiting $DST_AW (want 0);"
  if [ -z "$DST_L10" ]; then DST_S10=$((DST_S10 + 1)); else echo "    slow jq, $DST_G copy:$DST_L10"; fi
done
if [ "$DST_S10" = "$DST_X10" ]; then row "display: a capture jq cannot read in 20 s gives the two slow lines once per draw, one jq run, none for A on the same file ($DST_X10 copies)" PASS
else row "display slow jq: $DST_S10/$DST_X10 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S11 strikes: three junk or empty answers in a row that come back at once (within 1 s, or with no clock to tell) end the Overview (exit 0,
# one draw, three waits, the list never opened, no busy loop); an answer it knows in between starts the count again, and so does one that took
# a second or more: that is a UI taking its time (a timeout in the client, a wake from sleep, a word nobody knows), not a broken key path
DST_S11=0; DST_X11=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X11=$((DST_X11 + 1)); DST_L11=""
  dst_ov "s11a-$DST_G" "$DST_C" "X - Q A B"
  DST_A=$(dst_views "$DST_D/s11a-$DST_G.out"); DST_AW=$(dst_ui WAIT "s11a-$DST_G"); DST_AP=$(dst_ui PICKER "s11a-$DST_G")
  if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP" != 0/s/3/0 ]; then DST_L11="$DST_L11 junk, empty, junk: rc $DST_RC, screens '$DST_A' (want s), $DST_AW waits (want 3), $DST_AP lists (want 0);"; fi
  dst_ov "s11b-$DST_G" "$DST_C" "X Q A X - B"
  DST_A=$(dst_views "$DST_D/s11b-$DST_G.out"); DST_AW=$(dst_ui WAIT "s11b-$DST_G"); DST_AP=$(dst_ui PICKER "s11b-$DST_G")
  if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP" != 0/ss/6/1 ]; then DST_L11="$DST_L11 two strikes, A, two strikes, B: rc $DST_RC, screens '$DST_A' (want ss), $DST_AW waits (want 6), $DST_AP lists (want 1);"; fi
  # with a clock (the WAIT_FOR_INPUT stand-in moves /proc/uptime on by STARCHORUS_GAPS hundredths per wait; the display judges the time from the
  # arm to the end of the wait, which the waiter's own clock gives it). The first wait is an A that took 1.5 s: it redraws from the cache, so
  # nothing is read, and the answers after it are judged by their own time alone.
  # tag|keys|gaps|waits|screens|lists
  for DST_Q in "slowempty|A - - - - - - B|150 150 150 150 150 150 150 150|8|ss|1" "slowjunk|A X Y Z Q X B|150 150 150 150 150 150 150|7|ss|1" \
               "quick3|A - - - B|150 20 20 20 20|4|ss|0" "quickjunk|A X Y Z B|150 20 20 20 20|4|ss|0" \
               "mixed|A - - X - - B|150 20 20 150 20 20 20|7|ss|1" "edge99|A - - - B|150 99 99 99 99|4|ss|0" "edge100|A - - - B|150 100 100 100 100|5|ss|1"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QK=$(printf '%s' "$DST_Q" | cut -d'|' -f2); DST_QG=$(printf '%s' "$DST_Q" | cut -d'|' -f3)
    DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f4); DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f5); DST_QL=$(printf '%s' "$DST_Q" | cut -d'|' -f6)
    DST_PD="$DST_D/s11-$DST_G-$DST_QT.proc"; rm -rf "$DST_PD"; mkdir -p "$DST_PD"; echo "1000.00 5000.00" > "$DST_PD/uptime"
    # shellcheck disable=SC2086   # one gap per word, on purpose
    printf '%s\n' $DST_QG > "$DST_D/s11-$DST_G-$DST_QT.gaps"
    dst_ov "s11-$DST_G-$DST_QT" "$DST_C" "$DST_QK" STARCHORUS_PROC="$DST_PD" STARCHORUS_GAPS="$DST_D/s11-$DST_G-$DST_QT.gaps"
    DST_A=$(dst_views "$DST_D/s11-$DST_G-$DST_QT.out"); DST_AW=$(dst_ui WAIT "s11-$DST_G-$DST_QT"); DST_AP=$(dst_ui PICKER "s11-$DST_G-$DST_QT")
    if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP" != "0/$DST_QV/$DST_QW/$DST_QL" ]; then
      DST_L11="$DST_L11 [$DST_QT: keys $DST_QK, gaps $DST_QG] rc $DST_RC, screens '$DST_A' (want $DST_QV), $DST_AW waits (want $DST_QW), $DST_AP lists (want $DST_QL);"
    fi
  done
  # the words other payloads of the library test for are the two buttons and no strikes (the header of the script and the docs say so): after two
  # junk answers BACK, Escape and a lower-case b go one level up (the list opens), a lower-case a draws the screen again; a third junk word would
  # have ended the Overview before the list. tag|keys|waits|screens|lists
  for DST_Q in "back|X X BACK|3|s|1" "escape|X X Escape|3|s|1" "lowerb|X X b|3|s|1" "lowera|X X a X X B|6|ss|1"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QK=$(printf '%s' "$DST_Q" | cut -d'|' -f2)
    DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f3); DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f4); DST_QL=$(printf '%s' "$DST_Q" | cut -d'|' -f5)
    dst_ov "s11w-$DST_G-$DST_QT" "$DST_C" "$DST_QK"
    DST_A=$(dst_views "$DST_D/s11w-$DST_G-$DST_QT.out"); DST_AW=$(dst_ui WAIT "s11w-$DST_G-$DST_QT"); DST_AP=$(dst_ui PICKER "s11w-$DST_G-$DST_QT")
    if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP" != "0/$DST_QV/$DST_QW/$DST_QL" ]; then
      DST_L11="$DST_L11 [$DST_QT: keys $DST_QK] rc $DST_RC, screens '$DST_A' (want $DST_QV), $DST_AW waits (want $DST_QW), $DST_AP lists (want $DST_QL);"
    fi
  done
  # the same words as the device may print them, padded with spaces and a tab and ended by a CR (take strips them): known keys act, junk stays
  # a strike. tag|keys|waits|screens|lists
  for DST_Q in "padstrikes|X X A X X B|6|ss|1" "padnav|UP DOWN LEFT RIGHT B|5|sas|1" "padb|B|1|s|1" "padback|X BACK|2|s|1"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QK=$(printf '%s' "$DST_Q" | cut -d'|' -f2)
    DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f3); DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f4); DST_QL=$(printf '%s' "$DST_Q" | cut -d'|' -f5)
    dst_ov "s11d-$DST_G-$DST_QT" "$DST_C" "$DST_QK" STARCHORUS_PAD=1
    DST_A=$(dst_views "$DST_D/s11d-$DST_G-$DST_QT.out"); DST_AW=$(dst_ui WAIT "s11d-$DST_G-$DST_QT"); DST_AP=$(dst_ui PICKER "s11d-$DST_G-$DST_QT")
    if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP" != "0/$DST_QV/$DST_QW/$DST_QL" ]; then
      DST_L11="$DST_L11 [$DST_QT padded: keys $DST_QK] rc $DST_RC, screens '$DST_A' (want $DST_QV), $DST_AW waits (want $DST_QW), $DST_AP lists (want $DST_QL);"
    fi
  done
  if [ -z "$DST_L11" ]; then DST_S11=$((DST_S11 + 1)); else echo "    strikes, $DST_G copy:$DST_L11"; fi
done
if [ "$DST_S11" = "$DST_X11" ]; then row "display strikes: three junk or empty answers in a row that come back at once end the Overview (rc 0, one draw, 3 waits), a known key or a slow answer starts the count again ($DST_X11 copies)" PASS
else row "display strikes: $DST_S11/$DST_X11 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S12 updown: UP and DOWN are ignored: no draw, no exit, no strike (five of them in a row would be strikes if they counted), the next A still draws
DST_S12=0; DST_X12=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X12=$((DST_X12 + 1))
  dst_ov "s12-$DST_G" "$DST_C" "UP DOWN UP DOWN UP A DOWN B"
  DST_A=$(dst_views "$DST_D/s12-$DST_G.out"); DST_AW=$(dst_ui WAIT "s12-$DST_G"); DST_AP=$(dst_ui PICKER "s12-$DST_G")
  if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP" = 0/ss/8/1 ]; then DST_S12=$((DST_S12 + 1))
  else echo "    updown, $DST_G copy: rc $DST_RC, screens '$DST_A' (want ss: the first draw and the one for A), $DST_AW waits (want 8), $DST_AP lists (want 1)"; fi
done
if [ "$DST_S12" = "$DST_X12" ]; then row "display updown: UP and DOWN cause no draw, no exit and no strike; the next A still draws ($DST_X12 copies)" PASS
else row "display updown: $DST_S12/$DST_X12 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S13 leftright: RIGHT steps to the next screen in the order of the list (summary, top, bands, devices, probes, clients, bluetooth, air), LEFT to
# the previous, both wrap round (summary <-> air); B opens the list with the cursor on the screen B came from (the default is the last row of
# the call), a row picked is drawn, a label that is not offered leaves. S13b, the next row: the Bluetooth screen of a capture that has Bluetooth
# (the radio-pair fixture) is drawn whole: at most 12 lines (the heading, the figures, up to seven companies and the frame's two) of at most 40
# columns, the count line the fixture's (9 addresses, 7 rotating, 2 fixed), the companies' counts adding up to the 9, the keys line last.
DST_S13=0; DST_X13=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X13=$((DST_X13 + 1)); DST_L13=""
  # LEFT from the summary = air; RIGHT x9 = summary (the wrap), top, bands, devices, probes, clients, bluetooth, air, summary (the wrap again);
  # LEFT x8 = air, bluetooth, clients, probes, devices, bands, top, summary; B opens the list
  dst_ov "s13a-$DST_G" "$DST_C" "LEFT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT LEFT LEFT LEFT LEFT LEFT LEFT LEFT LEFT B"
  DST_A=$(dst_views "$DST_D/s13a-$DST_G.out"); DST_AW=$(dst_ui WAIT "s13a-$DST_G"); DST_AP=$(dst_ui PICKER "s13a-$DST_G")
  if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP" != 0/sastbdpclasalcpdbts/19/1 ]; then
    DST_L13="$DST_L13 walk: rc $DST_RC, screens '$DST_A' (want sastbdpclasalcpdbts), $DST_AW waits (want 19), $DST_AP lists (want 1);"
  fi
  printf '%s\n' Stations "Not A Row" > "$DST_D/s13b-$DST_G.pk"; rm -f "$DST_D/s13b-$DST_G.pn"
  dst_ov "s13b-$DST_G" "$DST_C" "B B" STARCHORUS_PICKS="$DST_D/s13b-$DST_G.pk" STARCHORUS_PICKS_N="$DST_D/s13b-$DST_G.pn"
  DST_A=$(dst_views "$DST_D/s13b-$DST_G.out"); DST_PL=$(grep '^PICKER' "$DST_D/s13b-$DST_G.ui")
  DST_P1=$(printf '%s\n' "$DST_PL" | sed -n 1p); DST_P2=$(printf '%s\n' "$DST_PL" | sed -n 2p)
  # the list: its title and eight rows in this order and spelling, the cursor (the last argument) on Summary for the first B, on Stations (the
  # screen just picked) for the second; the answer to the second is a label that is not offered: leave
  if [ "$DST_RC/$DST_A/$DST_P1/$DST_P2" != "0/sc/$DST_HUB|Summary/$DST_HUB|Stations" ]; then
    DST_L13="$DST_L13 list: rc $DST_RC, screens '$DST_A' (want sc), first call [$DST_P1], second [$DST_P2] (want $DST_HUB|Summary and ...|Stations);"
  fi
  # the new row of the list: Bluetooth is a row, picking it draws that screen, and B there offers the list with the cursor on it
  printf '%s\n' Bluetooth "Not A Row" > "$DST_D/s13c-$DST_G.pk"; rm -f "$DST_D/s13c-$DST_G.pn"
  dst_ov "s13c-$DST_G" "$DST_C" "B B" STARCHORUS_PICKS="$DST_D/s13c-$DST_G.pk" STARCHORUS_PICKS_N="$DST_D/s13c-$DST_G.pn"
  DST_A=$(dst_views "$DST_D/s13c-$DST_G.out"); DST_PL=$(grep '^PICKER' "$DST_D/s13c-$DST_G.ui")
  DST_P2=$(printf '%s\n' "$DST_PL" | sed -n 2p)
  if [ "$DST_RC/$DST_A/$DST_P2" != "0/sl/$DST_HUB|Bluetooth" ]; then
    DST_L13="$DST_L13 bluetooth row: rc $DST_RC, screens '$DST_A' (want sl), second call [$DST_P2] (want ...|Bluetooth);"
  fi
  if [ -z "$DST_L13" ]; then DST_S13=$((DST_S13 + 1)); else echo "    leftright, $DST_G copy:$DST_L13"; fi
done
if [ "$DST_S13" = "$DST_X13" ]; then row "display leftright: LEFT/RIGHT step through the eight screens and wrap (summary <-> air); B opens the list on the screen it came from, Bluetooth is a row ($DST_X13 copies)" PASS
else row "display leftright: $DST_S13/$DST_X13 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S13b: the Bluetooth screen of radio-pair, drawn by the Overview itself (six RIGHT from the summary), whole. NOT COVERED while the fixture is
# not there yet (tests/fixtures/radio-pair.json comes with the page track; the parity drop-in has the row that is red for its absence).
if [ ! -s "$F/radio-pair.json" ]; then notcov "display bluetooth screen of radio-pair, drawn by the Overview (needs tests/fixtures/radio-pair.json)"
else
  DST_S13B=0; DST_X13B=0
  for DST_E in $DST_COPIES; do
    DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X13B=$((DST_X13B + 1)); DST_L13=""
    DST_OVSRC="$F/radio-pair.json"
    dst_ov "s13d-$DST_G" "$DST_C" "RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT B"
    DST_OVSRC=
    DST_A=$(dst_views "$DST_D/s13d-$DST_G.out")
    DST_BL=$(awk '/^LOG\[blue\] Bluetooth LE \(GEN /{ f = 1 } f { print } f && /^LOG A: Refresh   B: Back$/ { exit }' "$DST_D/s13d-$DST_G.out" | sed 's/^LOG\(\[[a-z]*\]\)\{0,1\} //')
    DST_BN=$(printf '%s\n' "$DST_BL" | grep -c .)
    DST_BW=$(printf '%s\n' "$DST_BL" | LC_ALL=C awk 'length($0) > 40' | grep -c .)
    DST_BS=$(printf '%s\n' "$DST_BL" | sed -n 's/^ -\{0,1\}[0-9]* dBm  .*  (\([0-9]*\))$/\1/p' | awk '{ t += $1 } END { print t + 0 }')
    DST_BC=$(printf '%s\n' "$DST_BL" | grep -cx '9 addresses (7 rotating, 2 fixed)')
    DST_BK=$(printf '%s\n' "$DST_BL" | tail -n 1)
    if [ "$DST_RC/$DST_A/$DST_BC/$DST_BS/$DST_BW/$DST_BK" != '0/stbdpcl/1/9/0/A: Refresh   B: Back' ] || [ "$DST_BN" -gt 12 ] || [ "$DST_BN" -lt 5 ]; then
      DST_L13="$DST_L13 radio-pair: rc $DST_RC, screens '$DST_A' (want stbdpcl), count line x$DST_BC (want 1), companies add up to $DST_BS (want 9), $DST_BW lines over 40 columns (want 0), last line '$DST_BK', $DST_BN lines (5 to 12);"
    fi
    if [ -z "$DST_L13" ]; then DST_S13B=$((DST_S13B + 1)); else echo "    bluetooth screen, $DST_G copy:$DST_L13"; fi
  done
  if [ "$DST_S13B" = "$DST_X13B" ]; then row "display bluetooth screen of radio-pair is whole: heading, 9 addresses (7 rotating, 2 fixed), companies adding up to 9, the frame, 12 lines of 40 columns at most ($DST_X13B copies)" PASS
  else row "display bluetooth screen of radio-pair: $DST_S13B/$DST_X13B copies as expected" FAIL; DST_KEEP=1; fi
fi

# ---- S14 notimeout: no code line of either copy puts `timeout` before WAIT_FOR_INPUT (nor anywhere on a line that holds it), and exactly one code line
# calls it; S9 showed the same at run time (the only commands under the stand-in timeout were jq). A UI command killed by timeout can leave a waiter in
# the UI daemon that swallows the next press. Detector self-check: a planted line is found, the same text in a comment is not.
DST_NTRE='timeout.*WAIT_FOR_INPUT|WAIT_FOR_INPUT.*timeout'
dst_code() { sed -e 's/^[[:space:]]*#.*$//' -e 's/[[:space:]]#.*$//'; }   # stdin as code: comments dropped, whole-line and trailing
# shellcheck disable=SC2016   # the planted lines are literal script text
DST_NTD=$(printf '%s\n' '  timeout 4 WAIT_FOR_INPUT > "$OV_RAW" 2>/dev/null &' '  # timeout 4 WAIT_FOR_INPUT' '  WAIT_FOR_INPUT > "$OV_RAW" 2>/dev/null &   # never timeout' \
          | dst_code | grep -cE "$DST_NTRE")
DST_S14=0; DST_X14=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X14=$((DST_X14 + 1))
  DST_NH=$(dst_code < "$DST_C" | grep -cE "$DST_NTRE"); DST_NU=$(dst_code < "$DST_C" | grep -c 'WAIT_FOR_INPUT')
  if [ "$DST_NTD" = 1 ] && [ "$DST_NH" = 0 ] && [ "$DST_NU" = 1 ]; then DST_S14=$((DST_S14 + 1))
  else echo "    notimeout, $DST_G copy: $DST_NH code line(s) with timeout and WAIT_FOR_INPUT (want 0), $DST_NU code line(s) calling WAIT_FOR_INPUT (want 1), detector $DST_NTD (want 1)"; fi
done
if [ "$DST_S14" = "$DST_X14" ]; then row "display notimeout: no code line puts timeout before WAIT_FOR_INPUT, one code line calls it ($DST_X14 copies)" PASS
else row "display notimeout: $DST_S14/$DST_X14 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S15 armed: the key wait is open before the draw is, and the draw ends with the first key. A jq stand-in sleeps 2 s on the screen's program, and the
# key stand-in answers with a "@" word, the moment that program has started: a press at "Reading...", whenever the machine happens to be
# slow or fast. Four things follow from the design, and each is looked at: (1) the answer is taken (the wait was open while the draw ran): A gives a
# second draw, B opens the list, RIGHT draws the next screen; (2) the draw it came in ended: its jq was ended (the stand-in notes
# .killed; it would have run 1 s more) and no heading of that screen is printed; (3) nothing of that run was kept: the same screen's program runs
# again in the draw that follows (a cut run is no verdict on the capture), so A shows 3 jq (the probe, the ended run, the second run) and not 2;
# (4) an Up that came in a draw that was cut draws that screen again, as no half screen is to stay as the last thing on the console.
# (6) the ended draw prints no more once the key has come: no "Waiting for the first scan." (what a screen says when its jq has nothing to show, and
# that is what an ended jq looks like to it) and no frame, so the frames are those of the whole draws alone.
# tag|keys|screens|waits|lists|jq processes|Reading... lines|frames. The probe and a program run are one jq each; "Reading..." comes once per draw
# that has to run jq (the ended draw has it too; RIGHT's second screen has a program of its own).
DST_S15=0; DST_X15=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X15=$((DST_X15 + 1)); DST_L15=""
  for DST_Q in "A|@A B|s|2|1|3|2|1" "B|@B|-|1|1|2|1|0" "RIGHT|@RIGHT B|t|2|1|3|2|1" "UP|@UP B|s|2|1|3|2|1"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QK=$(printf '%s' "$DST_Q" | cut -d'|' -f2); DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f3)
    DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f4); DST_QL=$(printf '%s' "$DST_Q" | cut -d'|' -f5); DST_QJ=$(printf '%s' "$DST_Q" | cut -d'|' -f6)
    DST_QB=$(printf '%s' "$DST_Q" | cut -d'|' -f7); DST_QF=$(printf '%s' "$DST_Q" | cut -d'|' -f8); [ "$DST_QV" != - ] || DST_QV=
    DST_TG="s15-$DST_G-$DST_QT"; rm -f "$DST_D/$DST_TG.st" "$DST_D/$DST_TG.st.killed"
    DST_OVPATH="$DST_D/sleepjq"
    dst_ov "$DST_TG" "$DST_C" "$DST_QK" STARCHORUS_JQ_STARTED="$DST_D/$DST_TG.st" STARCHORUS_JQ_SLEEP=2
    DST_OVPATH=
    DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG")
    DST_AJ=$(grep -c x "$DST_D/$DST_TG.jq"); DST_AB=$(dst_cnt 'LOG Reading...' "$DST_D/$DST_TG.out"); DST_AD=no; [ ! -e "$DST_D/$DST_TG.st.killed" ] || DST_AD=yes
    DST_AN=$(dst_cnt 'LOG Waiting for the first scan.' "$DST_D/$DST_TG.out"); DST_AF=$(dst_cnt 'LOG A: Refresh   B: Back' "$DST_D/$DST_TG.out")
    if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP/$DST_AJ/$DST_AB/$DST_AD/$DST_AN/$DST_AF" != "0/$DST_QV/$DST_QW/$DST_QL/$DST_QJ/$DST_QB/yes/0/$DST_QF" ]; then
      DST_L15="$DST_L15 [$DST_QT: keys $DST_QK] rc $DST_RC, screens '$DST_A' (want '$DST_QV'), $DST_AW waits (want $DST_QW), $DST_AP lists (want $DST_QL), $DST_AJ jq (want $DST_QJ), Reading... $DST_AB (want $DST_QB), the jq of the first draw ended: $DST_AD (want yes), waiting lines $DST_AN (want 0), frames $DST_AF (want $DST_QF);"
    fi
  done
  # (5) a jq that is under a `timeout` which does not pass the signal on is ended all the same (the children of the `timeout` first), and so is the
  # `timeout`: neither is there when the Overview ends; one run, A at "Reading..." then B
  DST_TG="s15-$DST_G-tree"; rm -f "$DST_D/$DST_TG.st" "$DST_D/$DST_TG.st.killed" "$DST_D/$DST_TG.jqp" "$DST_D/$DST_TG.tmp.pids"
  DST_OVPATH="$DST_D/tmofork:$DST_D/sleepjq"
  dst_ov "$DST_TG" "$DST_C" "@A B" STARCHORUS_JQ_STARTED="$DST_D/$DST_TG.st" STARCHORUS_JQ_PIDS="$DST_D/$DST_TG.jqp" STARCHORUS_TMO_PIDS="$DST_D/$DST_TG.tmp.pids" STARCHORUS_JQ_SLEEP=3
  DST_OVPATH=
  DST_NJ=$(grep -c . "$DST_D/$DST_TG.jqp"); DST_AL=$(dst_alive "$DST_D/$DST_TG.jqp"); DST_NT=$(grep -c . "$DST_D/$DST_TG.tmp.pids"); DST_AT=$(dst_alive "$DST_D/$DST_TG.tmp.pids")
  DST_AD=no; [ ! -e "$DST_D/$DST_TG.st.killed" ] || DST_AD=yes
  if [ "$DST_RC/$DST_NJ/$DST_AL/$DST_NT/$DST_AT/$DST_AD" != "0/2/0/2/0/yes" ]; then
    DST_L15="$DST_L15 [tree] rc $DST_RC, $DST_NJ program runs (want 2), $DST_AL still there (want 0), $DST_NT timeouts (want 2), $DST_AT still there (want 0), jq of the first draw ended: $DST_AD (want yes);"
  fi
  if [ -z "$DST_L15" ]; then DST_S15=$((DST_S15 + 1)); else echo "    armed, $DST_G copy:$DST_L15"; fi
done
if [ "$DST_S15" = "$DST_X15" ]; then row "display armed: the wait is open before the draw, a key at Reading... ends that draw (its jq is ended and not kept, also under a timeout that passes no signal on) and is acted on at once; an Up that cut a draw draws it again ($DST_X15 copies)" PASS
else row "display armed: $DST_S15/$DST_X15 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S16 frame: every draw ends with the time of its scan (UTC, from `generated`) and its age, then `A: Refresh   B: Back`, and the summary alone
# with the page's address; more than three intervals old: the red "No new scan" line instead of the time; no capture yet: only the keys, and
# waiting is cached too (A on the waiting screen starts no second jq: 2 processes in 3 draws, the probe and one program)
DST_S16=0; DST_X16=0
DST_NOW=$(date +%s)
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X16=$((DST_X16 + 1)); DST_L16=""
  DST_GEN16=$((DST_NOW - 42)); DST_EXP=$(printf '%02d:%02d:%02d' $((DST_GEN16 % 86400 / 3600)) $((DST_GEN16 % 3600 / 60)) $((DST_GEN16 % 60)))
  jq -c --argjson g "$DST_GEN16" '.generated = $g' "$F/many-clients.json" > "$DST_D/s16-$DST_G.fresh"
  DST_OVSRC="$DST_D/s16-$DST_G.fresh"; dst_ov "s16a-$DST_G" "$DST_C" "RIGHT B" STARCHORUS_PAGE_URL=http://172.16.52.1:8199/; DST_OVSRC=
  DST_O="$DST_D/s16a-$DST_G.out"
  DST_LS=$(grep -c "^LOG Last scan $DST_EXP ([0-9]* s ago)\$" "$DST_O")
  DST_AGE=$(sed -n "s/^LOG Last scan $DST_EXP (\([0-9]*\) s ago)\$/\1/p" "$DST_O" | sed -n 1p)
  DST_TAIL=$(awk '/^LOG Last scan /{f=NR} f && NR>f && NR<=f+2 {print} END{}' "$DST_O" | sed -n '1,2p' | tr '\n' '|')
  DST_WP=$(dst_cnt 'LOG Web page: 172.16.52.1:8199' "$DST_O"); DST_KL=$(dst_cnt 'LOG A: Refresh   B: Back' "$DST_O")
  case $DST_AGE in ''|*[!0-9]*) DST_AGE=-1 ;; esac
  # two draws (the summary, then top after RIGHT; B opens the list, which leaves): the time and the age on both, the page's address on the summary only
  DST_AOK=0; if [ "$DST_AGE" -ge 42 ] && [ "$DST_AGE" -le 120 ]; then DST_AOK=1; fi
  if [ "$DST_RC/$DST_LS/$DST_AOK/$DST_WP/$DST_KL/$DST_TAIL" != "0/2/1/1/2/LOG A: Refresh   B: Back|LOG Web page: 172.16.52.1:8199|" ]; then
    DST_L16="$DST_L16 fresh: rc $DST_RC, Last scan lines $DST_LS (want 2 with $DST_EXP), age '$DST_AGE' (want 42 to 120), Web page $DST_WP (want 1), key lines $DST_KL (want 2), after the first [$DST_TAIL];"
  fi
  # the Bluetooth screen is a draw like the others (six RIGHT from the summary): its block ends with the same Last scan line, then the keys, twelve lines at most in all. The line
  # is the frame's, the time of `generated` and not of a scan of the Bluetooth window of its own (the specification's 'Last scan' of that screen is this line).
  if [ -s "$F/radio-pair.json" ]; then
    jq -c --argjson g "$DST_GEN16" '.generated = $g' "$F/radio-pair.json" > "$DST_D/s16-$DST_G.bt"
    DST_OVSRC="$DST_D/s16-$DST_G.bt"; dst_ov "s16d-$DST_G" "$DST_C" "RIGHT RIGHT RIGHT RIGHT RIGHT RIGHT B"; DST_OVSRC=
    DST_O="$DST_D/s16d-$DST_G.out"
    DST_BLK=$(awk '/^LOG\[blue\] Bluetooth LE \(GEN /{ f = 1 } f { print } f && /^LOG A: Refresh   B: Back$/ { exit }' "$DST_O")
    DST_BN=$(printf '%s\n' "$DST_BLK" | grep -c .); DST_BTL=$(printf '%s\n' "$DST_BLK" | tail -n 2 | sed -n 1p)
    case $DST_BTL in "LOG Last scan $DST_EXP ("*" s ago)") DST_BTOK=1 ;; *) DST_BTOK=0 ;; esac
    if [ "$DST_RC/$DST_BTOK" != 0/1 ] || [ "$DST_BN" -gt 12 ]; then
      DST_L16="$DST_L16 bluetooth: rc $DST_RC, the line before the keys is '$DST_BTL' (want Last scan $DST_EXP and the age), $DST_BN lines (12 at most);"
    fi
  fi
  # a stale capture: the red line instead (400 s = 6 min, 8000 s = 2 h); no Last scan line
  for DST_Z in "400:6 min" "8000:2 h"; do
    DST_ZS=${DST_Z%%:*}; DST_ZW=${DST_Z#*:}
    jq -c --argjson g "$((DST_NOW - DST_ZS))" '.generated = $g' "$F/many-clients.json" > "$DST_D/s16-$DST_G.old"
    DST_OVSRC="$DST_D/s16-$DST_G.old"; dst_ov "s16b-$DST_G-$DST_ZS" "$DST_C" "A B"; DST_OVSRC=
    DST_O="$DST_D/s16b-$DST_G-$DST_ZS.out"
    DST_RED=$(grep -c "^LOG\[red\] No new scan for $DST_ZW\.\$" "$DST_O"); DST_LS=$(grep -c '^LOG Last scan ' "$DST_O")
    if [ "$DST_RC/$DST_RED/$DST_LS" != 0/2/0 ]; then
      DST_L16="$DST_L16 stale $DST_ZS s: rc $DST_RC, red lines $DST_RED (want 2 for '$DST_ZW'), Last scan lines $DST_LS (want 0);"
    fi
  done
  # no capture yet (STARCHORUS_SINCE after it): the waiting line and the keys on each of three draws, no time, one program run for all of them
  DST_OVSRC="$DST_D/s16-$DST_G.fresh"
  dst_ov "s16c-$DST_G" "$DST_C" "A A B" STARCHORUS_SINCE=9999999999 STARCHORUS_PAGE_URL=http://172.16.52.1:8199/; DST_OVSRC=
  DST_O="$DST_D/s16c-$DST_G.out"
  DST_WL=$(dst_cnt 'LOG Waiting for the first scan.' "$DST_O"); DST_KL=$(dst_cnt 'LOG A: Refresh   B: Back' "$DST_O"); DST_LS=$(grep -c '^LOG Last scan ' "$DST_O")
  DST_AJ=$(grep -c x "$DST_D/s16c-$DST_G.jq"); DST_AB=$(dst_cnt 'LOG Reading...' "$DST_O"); DST_WP=$(dst_cnt 'LOG Web page: 172.16.52.1:8199' "$DST_O")
  if [ "$DST_RC/$DST_WL/$DST_KL/$DST_LS/$DST_AJ/$DST_AB/$DST_WP" != 0/3/3/0/2/1/3 ]; then
    DST_L16="$DST_L16 waiting: rc $DST_RC, waiting lines $DST_WL (want 3), key lines $DST_KL (want 3), Last scan $DST_LS (want 0), jq $DST_AJ (want 2), Reading... $DST_AB (want 1), Web page $DST_WP (want 3);"
  fi
  if [ -z "$DST_L16" ]; then DST_S16=$((DST_S16 + 1)); else echo "    frame, $DST_G copy:$DST_L16"; fi
done
if [ "$DST_S16" = "$DST_X16" ]; then row "display frame: Last scan HH:MM:SS (N s ago), A: Refresh   B: Back, Web page on the summary only, the Bluetooth screen ends with the same Last scan line; red No new scan when old; waiting costs one jq ($DST_X16 copies)" PASS
else row "display frame: $DST_S16/$DST_X16 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S17 nopending: no waiter is left behind by a way out that is not a signal. The stand-in writes its pid to a file (one line per wait) and kill -0
# must fail for every one of them; as many pids as waits, so a run that never waited proves nothing; and no Overview run of this drop-in leaves
# its temp dir behind (every run above too: DST_OVLEFT adds them up). tag|keys|screens|waits: (a) A, then B out of the list, (b) three empty answers
# at once (the strikes), (c) the payload gone after the first key: a fake payload runs the Overview as its child and the stand-in ends the payload
# while it answers (the Overview must stop after that one wait, with no second waiter), (d) the payload gone before the first arm (a pid that is dead).
DST_S17=0; DST_X17=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X17=$((DST_X17 + 1)); DST_L17=""
  for DST_Q in "list|A B|ss|2" "strikes|- - -|s|3"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QK=$(printf '%s' "$DST_Q" | cut -d'|' -f2); DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f3)
    DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f4); DST_TG="s17-$DST_G-$DST_QT"
    dst_ov "$DST_TG" "$DST_C" "$DST_QK"
    DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_NP=$(grep -c . "$DST_D/$DST_TG.pids"); DST_AL=$(dst_alive "$DST_D/$DST_TG.pids")
    if [ "$DST_RC/$DST_A/$DST_AW/$DST_NP/$DST_AL" != "0/$DST_QV/$DST_QW/$DST_QW/0" ]; then
      DST_L17="$DST_L17 [$DST_QT: keys $DST_QK] rc $DST_RC, screens '$DST_A' (want $DST_QV), $DST_AW waits (want $DST_QW), $DST_NP pids (want $DST_QW), $DST_AL still there (want 0);"
    fi
  done
  # (c) the payload ends during the first wait; the Overview is a child of the fake payload and goes on alone
  DST_TG="s17-$DST_G-gone"; DST_PF="$DST_D/$DST_TG.payload"; : > "$DST_PF"; DST_SAVE=$DST_OVLEFT
  DST_OVSH="$DST_D/payload"
  dst_ov "$DST_TG" "$DST_C" "A B" STARCHORUS_KILL_PID="$DST_PF" STARCHORUS_KILL_AT=1 2> /dev/null   # the shell's "Terminated" notice for the fake payload goes nowhere
  DST_OVSH=
  DST_W=0; while [ "$(dst_ovleft "$DST_D/$DST_TG.tmp")" != 0 ] && [ "$DST_W" -lt 100 ]; do sleep 0.05; DST_W=$((DST_W + 1)); done   # it ends by itself
  DST_OVLEFT=$((DST_SAVE + $(dst_ovleft "$DST_D/$DST_TG.tmp")))
  DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG")
  DST_NP=$(grep -c . "$DST_D/$DST_TG.pids"); DST_AL=$(dst_alive "$DST_D/$DST_TG.pids")
  if [ "$DST_A/$DST_AW/$DST_AP/$DST_NP/$DST_AL" != s/1/0/1/0 ]; then
    DST_L17="$DST_L17 [payload gone after the first key] screens '$DST_A' (want s), $DST_AW waits (want 1), $DST_AP lists (want 0), $DST_NP pids (want 1), $DST_AL still there (want 0);"
  fi
  # (d) the payload is gone before the first arm: no draw, no wait
  DST_DEAD=$(sh -c 'echo $$')
  dst_ov "s17-$DST_G-dead" "$DST_C" "A B" STARCHORUS_PARENT_PID="$DST_DEAD"
  DST_A=$(dst_views "$DST_D/s17-$DST_G-dead.out"); DST_AW=$(dst_ui WAIT "s17-$DST_G-dead")
  if [ "$DST_RC/$DST_A/$DST_AW" != "0//0" ]; then
    DST_L17="$DST_L17 [payload gone before the first arm] rc $DST_RC, screens '$DST_A' (want none), $DST_AW waits (want 0);"
  fi
  if [ -z "$DST_L17" ]; then DST_S17=$((DST_S17 + 1)); else echo "    nopending, $DST_G copy:$DST_L17"; fi
done
if [ "$DST_S17" = "$DST_X17" ] && [ "$DST_OVLEFT" = 0 ]; then
  row "display nopending: no waiter left after B out, three strikes, the payload gone after a key or before the first arm; no temp dir left by any of $DST_OVRUNS Overview runs ($DST_X17 copies)" PASS
else row "display nopending: $DST_S17/$DST_X17 copies as expected, $DST_OVLEFT temp dir(s) left by $DST_OVRUNS runs" FAIL; DST_KEEP=1; fi

# ---- S18 trap: the Overview ended by a signal while a waiter is pending. The stand-in holds its first wait for 30 s (it becomes `sleep 30`, same pid),
# so the waiter is certainly pending: the shell is in `wait` once the screen is drawn ("idle": TERM and HUP end it at once, exit 143 and 129), or it
# is still in the jq of the draw ("draw": the shell runs its trap when that jq has finished, so the bound is 3 s). In both the waiter (the real
# process of the stand-in, not only the subshell the Overview starts it from) must be gone by the bound, and the temp dir removed. The waiter must
# have been running, and the dir there, at the moment of the signal. Under sh and, when installed, dash (bash runs an EXIT trap on TERM by itself, dash
# does not: the Overview's own TERM trap is what is tested). tag|signal|exit status|bound in tenths of a second
# A shell cannot trap a signal it inherited ignored (POSIX; bash and dash keep to it), and a runner started under `nohup` hands SIGHUP
# down ignored to every process it starts: the HUP case would then go red for the runner's fault, not the Overview's (the signal does
# nothing, the row ends the waiter itself, and the Overview strikes out with exit 0). So each shell is asked once whether a HUP trap works
# in it, started as the row starts it; where it does not, the Overview is started through hupdfl.py, which puts HUP back to default and
# becomes the shell (python3, which the harness has), and the row says so. Should that fail as well, the HUP case is left out and the row
# says that instead.
printf '%s\n' 'import os, signal, sys' 'signal.signal(signal.SIGHUP, signal.SIG_DFL)' 'os.execvp(sys.argv[1], sys.argv[1:])' > "$DST_D/hupdfl.py"
dst_hupok() {   # dst_hupok SHELL [relaunch] -> 0 when a HUP trap works in SHELL (through hupdfl.py with the second argument)
  if [ -n "${2:-}" ]; then python3 "$DST_D/hupdfl.py" "$1" -c 'trap "exit 129" HUP; kill -HUP $$; exit 0' 2>/dev/null
  else "$1" -c 'trap "exit 129" HUP; kill -HUP $$; exit 0' 2>/dev/null; fi
  dst_rc=$?; [ "$dst_rc" = 129 ]
}
dst_s18_start() {   # dst_s18_start SHELL COPY: the Overview of S18 in the background, its pid in DST_P
  [ -z "$DST_HUPX" ] || set -- python3 "$DST_D/hupdfl.py" "$@"
  env PATH="$DST_PA" STARCHORUS_REAL_JQ="$DST_JQ" STARCHORUS_JQ_COUNT="$DST_D/$DST_TG.jq" \
      STARCHORUS_KEYS="$DST_D/$DST_TG.keys" STARCHORUS_CALLS="$DST_D/$DST_TG.calls" STARCHORUS_UI_LOG="$DST_D/$DST_TG.ui" \
      STARCHORUS_OUT="$DST_D/$DST_TG.out" STARCHORUS_PIDS="$DST_D/$DST_TG.pids" TMPDIR="$DST_D/$DST_TG.tmp" STARCHORUS_HOLD_AT=1 \
      STARCHORUS_STAT_LOG="$DST_D/$DST_TG.stat" STARCHORUS_JSON="$DST_D/$DST_TG.json" STARCHORUS_DIR="$DST_D/none" \
      STARCHORUS_PROC="$DST_D/noproc" "$@" > "$DST_D/$DST_TG.out" 2>&1 &
  DST_P=$!
}
DST_S18=0; DST_X18=0; DST_N18=0; DST_HUPNOTE=""
for DST_X in $DST_SHELLS; do
  DST_XP=$(command -v "$DST_X"); case $DST_XP in /*) ;; *) DST_XP=$DST_SH ;; esac
  DST_HUPX=""; DST_HUPQ="idle|HUP|129|10"
  if dst_hupok "$DST_XP"; then :
  elif dst_hupok "$DST_XP" relaunch; then DST_HUPX=1; DST_HUPNOTE="$DST_HUPNOTE; HUP put back to default for $DST_X, the runner had it ignored"
  else DST_HUPQ=""; DST_HUPNOTE="$DST_HUPNOTE; HUP case not run for $DST_X: the runner has it ignored and python3 could not put it back"; fi
  for DST_E in $DST_COPIES; do
    DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_L18=""; DST_N18=$((DST_N18 + 1))
    # shellcheck disable=SC2086   # DST_HUPQ is one word or none
    for DST_Q in "idle|TERM|143|10" $DST_HUPQ "draw|TERM|143|30"; do
      DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QS=$(printf '%s' "$DST_Q" | cut -d'|' -f2)
      DST_QR=$(printf '%s' "$DST_Q" | cut -d'|' -f3); DST_QB=$(printf '%s' "$DST_Q" | cut -d'|' -f4)
      DST_X18=$((DST_X18 + 1)); DST_TG="s18-$DST_G-$DST_X-$DST_QV-$DST_QS"
      printf '%s\n' A > "$DST_D/$DST_TG.keys"
      rm -f "$DST_D/$DST_TG.calls" "$DST_D/$DST_TG.pids"; : > "$DST_D/$DST_TG.ui"; : > "$DST_D/$DST_TG.jq"; : > "$DST_D/$DST_TG.stat"; : > "$DST_D/$DST_TG.out"
      rm -rf "$DST_D/$DST_TG.tmp"; mkdir -p "$DST_D/$DST_TG.tmp"; cp "$F/many-clients.json" "$DST_D/$DST_TG.json"
      DST_PA="$DST_D/dev9:$DST_D/cnt:$PATH"; [ "$DST_QV" != draw ] || DST_PA="$DST_D/sleepjq:$DST_PA"
      dst_s18_start "$DST_XP" "$DST_C"
      DST_W=0
      while [ "$DST_W" -lt 200 ]; do   # the waiter is armed, and the screen is drawn (idle) or its jq program is running (draw)
        if [ -s "$DST_D/$DST_TG.pids" ]; then
          if [ "$DST_QV" = idle ]; then grep -qxF 'LOG A: Refresh   B: Back' "$DST_D/$DST_TG.out" && break
          else [ "$(grep -c x "$DST_D/$DST_TG.jq")" -ge 2 ] && break; fi
        fi
        sleep 0.05; DST_W=$((DST_W + 1))
      done
      DST_WP=$(sed -n 1p "$DST_D/$DST_TG.pids" 2>/dev/null); DST_UP=0; DST_TB=$(dst_ovleft "$DST_D/$DST_TG.tmp")
      if [ -n "$DST_WP" ] && kill -0 "$DST_WP" 2>/dev/null; then DST_UP=1; fi
      kill -"$DST_QS" "$DST_P" 2>/dev/null
      DST_W=0; while [ -n "$DST_WP" ] && kill -0 "$DST_WP" 2>/dev/null && [ "$DST_W" -lt "$DST_QB" ]; do sleep 0.1; DST_W=$((DST_W + 1)); done
      DST_GONE=1; if [ -n "$DST_WP" ] && kill -0 "$DST_WP" 2>/dev/null; then DST_GONE=0; kill "$DST_WP" 2>/dev/null; fi
      wait "$DST_P" 2>/dev/null; DST_RC=$?; DST_TA=$(dst_ovleft "$DST_D/$DST_TG.tmp")
      if [ "$DST_UP/$DST_TB/$DST_GONE/$DST_RC/$DST_TA" != "1/1/1/$DST_QR/0" ]; then
        DST_L18="$DST_L18 [$DST_X $DST_QV $DST_QS] waiter running at the signal $DST_UP (want 1), temp dir there $DST_TB (want 1), waiter gone within $DST_QB tenths $DST_GONE (want 1), exit $DST_RC (want $DST_QR), temp dir left $DST_TA (want 0);"
        kill -9 "$DST_P" 2>/dev/null
      fi
    done
    if [ -z "$DST_L18" ]; then DST_S18=$((DST_S18 + 1)); else echo "    trap, $DST_G copy:$DST_L18"; fi
  done
done
if [ "$DST_S18" = "$DST_N18" ]; then row "display trap: TERM and HUP while a waiter is pending end it within a second and remove the temp dir (exit 143 and 129), TERM during a draw within 3 s ($DST_X18 runs, $DST_SHELLS$DST_HUPNOTE)" PASS
else row "display trap: $DST_S18/$DST_N18 copy and shell combinations as expected ($DST_X18 runs)" FAIL; DST_KEEP=1; fi

# ---- S19 parent: parent_gone starts no process (the old one ran sed and cut each time it was asked, twice per key, between a key being taken
# and the next wait being armed) and reads the parent from field 4 of the stat file of its own shell. A fake proc directory (STARCHORUS_PROC) holds
# self/stat with the parent the row wants: the payload's own pid (the Overview goes on) or another (it was handed over and ends before it draws or
# arms anything). `sed` and `cut` stand-ins note every process started for them. The summary's own template line starts a few (that is the draw,
# not the loop), so the count of a run with STARCHORUS_PARENT_PID set to a live process is compared with a control run of the same keys without it:
# the same number, not one more per check. A command name with spaces and a bracket in it ("(a b) c)") is read right, and a stat file that has no
# number in field 4 does not end the Overview (a dev machine has no /proc: the Overview then goes by the kill -0 alone).
# tag|stat text|screens|waits, three keys each (A, A, B: three draws)
DST_S19=0; DST_X19=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X19=$((DST_X19 + 1)); DST_L19=""
  sleep 60 & DST_LIVE=$!   # a pid that is alive for the length of the row
  DST_TG="s19-$DST_G-control"; : > "$DST_D/$DST_TG.fork"; DST_OVPATH="$DST_D/forkcnt"
  dst_ov "$DST_TG" "$DST_C" "A A B" STARCHORUS_FORK_LOG="$DST_D/$DST_TG.fork" STARCHORUS_REAL_PATH="$PATH"
  DST_OVPATH=
  DST_F0=$(grep -c . "$DST_D/$DST_TG.fork")
  if [ "$DST_RC/$(dst_views "$DST_D/$DST_TG.out")" != 0/sss ] || [ "$DST_F0" -lt 1 ]; then
    DST_L19="$DST_L19 [control] rc $DST_RC, screens '$(dst_views "$DST_D/$DST_TG.out")' (want sss), $DST_F0 sed/cut processes (want at least 1: the summary's template line);"
  fi
  for DST_Q in "mine|1 (sh) S $DST_LIVE 1 1 0 0 0|sss|3" "other|1 (sh) S 424242 1 1 0 0 0||0" "weird|1 (a b) c) S $DST_LIVE 1 1|sss|3" \
               "junk|garbage|sss|3" "noppid|1 (sh) S|sss|3"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QS=$(printf '%s' "$DST_Q" | cut -d'|' -f2)
    DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f3); DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f4)
    DST_PD="$DST_D/s19-$DST_G-$DST_QT.proc"; rm -rf "$DST_PD"; mkdir -p "$DST_PD/self"; printf '%s\n' "$DST_QS" > "$DST_PD/self/stat"
    DST_TG="s19-$DST_G-$DST_QT"; : > "$DST_D/$DST_TG.fork"
    DST_OVPATH="$DST_D/forkcnt"
    dst_ov "$DST_TG" "$DST_C" "A A B" STARCHORUS_PROC="$DST_PD" STARCHORUS_PARENT_PID="$DST_LIVE" STARCHORUS_FORK_LOG="$DST_D/$DST_TG.fork" STARCHORUS_REAL_PATH="$PATH"
    DST_OVPATH=
    DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AF=$(grep -c . "$DST_D/$DST_TG.fork")
    DST_WF=$DST_F0; [ "$DST_QT" != other ] || DST_WF=0
    if [ "$DST_RC/$DST_A/$DST_AW/$DST_AF" != "0/$DST_QV/$DST_QW/$DST_WF" ]; then
      DST_L19="$DST_L19 [$DST_QT: stat '$DST_QS'] rc $DST_RC, screens '$DST_A' (want '$DST_QV'), $DST_AW waits (want $DST_QW), $DST_AF sed/cut processes (want $DST_WF);"
    fi
  done
  kill "$DST_LIVE" 2>/dev/null; wait "$DST_LIVE" 2>/dev/null
  if [ -z "$DST_L19" ]; then DST_S19=$((DST_S19 + 1)); else echo "    parent, $DST_G copy:$DST_L19"; fi
done
if [ "$DST_S19" = "$DST_X19" ]; then row "display parent: parent_gone starts no process and takes the parent from field 4 of the shell's own stat file; another parent ends it before it draws ($DST_X19 copies)" PASS
else row "display parent: $DST_S19/$DST_X19 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S20 keyerr: the key file cannot be written. (a) At the start: the temp dir is read-only (a `mktemp` stand-in makes it so), the Overview says
# "Overview could not start." in an error dialog, exits 1, arms and draws nothing, and the dir is gone. (b) Later: the stand-in makes the key file read-only
# at its first wait, so the waiter's answer cannot be written and the file stays empty; that is not an empty answer (three of them would
# be three strikes, and the Overview would end in silence) but a failure, named in an error dialog: "Overview could not read a key.", exit 1,
# no second wait. A read-only file is only a fault for a user who is not root, so the row is skipped for root.
DST_S20=0; DST_X20=0
if [ "$(id -u 2>/dev/null)" = 0 ]; then notcov "display keyerr: a key file that cannot be written (the row needs a user who is not root)"; else
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X20=$((DST_X20 + 1)); DST_L20=""
  DST_TG="s20-$DST_G-start"; DST_OVPATH="$DST_D/rodir"
  dst_ov "$DST_TG" "$DST_C" "A B" STARCHORUS_REAL_PATH="$PATH"
  DST_OVPATH=
  DST_E1=$(dst_cnt 'ERROR Overview could not start.' "$DST_D/$DST_TG.ui"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_A=$(dst_views "$DST_D/$DST_TG.out")
  DST_FL=$(sed -n 1p "$DST_D/$DST_TG.out")
  if [ "$DST_RC/$DST_E1/$DST_AW/$DST_A/$DST_FL" != "1/1/0//LOG[blue] Overview" ]; then
    DST_L20="$DST_L20 [start] rc $DST_RC, dialog $DST_E1 (want 1), $DST_AW waits (want 0), screens '$DST_A' (want none), first line '$DST_FL' (want LOG[blue] Overview);"
  fi
  DST_TG="s20-$DST_G-late"
  dst_ov "$DST_TG" "$DST_C" "A B" STARCHORUS_SABOTAGE_AT=1
  DST_E2=$(dst_cnt 'ERROR Overview could not read a key.' "$DST_D/$DST_TG.ui"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG")
  if [ "$DST_RC/$DST_E2/$DST_AW/$DST_AP" != "1/1/1/0" ]; then
    DST_L20="$DST_L20 [late] rc $DST_RC, dialog $DST_E2 (want 1), $DST_AW waits (want 1), $DST_AP lists (want 0);"
  fi
  if [ -z "$DST_L20" ]; then DST_S20=$((DST_S20 + 1)); else echo "    keyerr, $DST_G copy:$DST_L20"; fi
done
if [ "$DST_S20" = "$DST_X20" ] && [ "$DST_OVLEFT" = 0 ]; then row "display keyerr: a key file that cannot be written is an error at the start or a named failure later, not three empty answers ($DST_X20 copies)" PASS
else row "display keyerr: $DST_S20/$DST_X20 copies as expected, $DST_OVLEFT temp dir(s) left" FAIL; DST_KEEP=1; fi
fi

if [ "$DST_KEEP" = 0 ]; then rm -rf "$DST_D"; else echo "    display-selftest scratch kept for inspection: $DST_D"; fi
unset -f dst_st dst_once dst_read dst_count dst_allpass dst_ov dst_ovleft dst_alive dst_cnt dst_ui dst_views dst_code
