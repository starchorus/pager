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
#                WAIT_FOR_INPUT that answers A four times, the capture swapped at its third call (after the draw the call before led to
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
# S11 strikes   : three junk or empty answers in a row that come back within 1 s of their wait being opened (or on a box with no clock) end the Overview (rc 0,
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
#                is then taken by the Pager UI), and a draw ENDS for a key that asks for another screen. A stand-in jq sleeps 2 s on the screen's
#                program; the key stand-in answers the moment it has started ("@" words): the answer is taken and acted on at once. B: the list;
#                RIGHT, LEFT: the next / previous screen; the jq of the ended draw is ended too and nothing of it is kept (the next screen's
#                program runs), also under a `timeout` that does not pass a signal on (the children of the `timeout` are ended first). A and UP
#                are taken as well but leave the draw running (0.1.1 ended it on any key and drew the screen again): one whole draw, its jq not ended.
# S16 frame     : every draw ends with `Last scan HH:MM:SS (N s ago)` (UTC, from `generated`) and `A: Refresh   B: Back`, the summary also with
#                the page's address; older than three intervals the red `No new scan for N min.` takes the place of the time; with no capture
#                since Start: the waiting line, the keys, no time, and one program run however often the screen is drawn (D5). The Bluetooth screen of
#                radio-pair (fresh `generated`) ends with the same Last scan line and the keys, twelve lines at most: that line is the specification's
#                'Last scan' of that screen (it dates the capture, not a scan window of its own; `--once` prints a screen without the frame).
# S17 nopending: no waiter is left behind by a way out that is not a signal: B out of the list, three strikes, the payload gone after a key
#                (a stand-in kills the fake payload while it answers; the key reader has opened its next wait by then, which the exit ends) and
#                gone before the first wait. The stand-in writes its pid to a file and kill -0 must fail for each; one pid per wait, so the row
#                cannot pass on a run that never waited; and no Overview run of this drop-in leaves its temp dir (starchorus-ov.*) behind.
# S18 trap      : the Overview ended by a signal while a stand-in waiter is pending (it holds for 30 s): TERM (exit 143) when the screen is
#                drawn and the shell waits in take, HUP (129) likewise, TERM during the draw (the shell waits for its jq in `wait`, so its trap
#                runs at once and ends the jq too); the waiter is gone within a second (3 s allowed for the draw), the temp dir is
#                removed. The waiter must have been running and the dir there at the moment of the signal. Under sh and, when installed, dash.
# S19 parent    : parent_gone starts no process (no sed or cut: a stand-in notes every one, against a control run) and reads the parent from
#                field 4 of the shell's own stat file (a fake proc directory), also with a command name that holds spaces and brackets;
#                another parent ends the Overview before it waits or draws; a stat file without a number there does not.
# S20 keyerr    : a queue that cannot be written: an error dialog at the start (a read-only temp dir), a named failure later (the queue file
#                made read-only while the key reader runs), exit 1 in both, and not three empty answers; the temp dir is removed.
# S21 queue     : keys pressed in one draw are kept, in order, and none is lost: the UI as measured on the device (M1: a press is lost where no wait
#                is open) with a presser that presses 0.1 s apart (RIGHT then B; X X A X X B; LEFT RIGHT RIGHT B). S22 aanswered: an A during a draw
#                is answered by the finished draw (one screen, one jq run, however many A), an A after the screen draws it again. S23 bcut: a B
#                during a draw ends it, the list opens, no wait is open while it shows. S24 lrcut: LEFT and RIGHT during a draw end it and switch
#                screens; several in one draw skip the screens between. S25 udquiet: UP and DOWN during a draw change nothing and leave no residue.
#                S26 reader: no waiter left by the key reader after A Up B, the payload gone at the second key, TERM and HUP with the third wait
#                held, TERM 0 to 80 ms after the start; ov_cleanup holds no $!. S27 probe: the first draw's health probe ends on B, Left, Right.
# S28 deadreader: the key reader killed from outside (KILL: no trap runs, so its `done` mark is never written, as when the file system is full) is a named
#                failure and not a poll without end: with or without a B pressed afterwards (the wait it left open takes it where nobody reads), the Overview
#                ends with exit 1 and "Overview could not read a key." within 6 s, opens no other wait and no list, and leaves no waiter and no temp dir.
#                S29 slowterm: a wait that is slow to end on TERM (0.3 s) and an `rm` that pauses between unlinking the temp dir's files and removing the dir
#                (a stand-in; the real one does it in a moment): TERM to the Overview leaves no starchorus-ov.* directory, because the cleanup waits for the
#                reader before it removes the directory, and the reader's last write lands in a directory that is still there or not at all.
#                S30 readerpin: text pins on both copies, each with a detector self-check: the reader replaces its count file (and the file with its wait's pid)
#                by renaming a finished sibling onto it and never truncates it in place, so a one-shot read of either finds the old content or the new and
#                never an empty file; the reader's EXIT trap writes `done` only where the directory still is; ov_cleanup asks for the reader's end
#                (kill -0 on OV_RPID) before it removes the directory; ov_await asks the same about the reader when no key is queued.
#                S31 secondterm: TERM, then TERM every 0.05 s while the cleanup waits for a reader that takes 0.6 s to end on TERM (the slow stand-in of S29): no starchorus-ov.*
#                directory and no waiter is left, exit 143, under sh and dash. A second terminating signal ran `exit` from inside the EXIT trap, and the shell left before
#                the line that removes the directory; ov_cleanup now ignores TERM, INT and HUP for its own, bounded, time. At least four more TERM must have been sent
#                while the Overview was there, so that the row cannot pass blind. S32 cleanpin: the first code line of ov_cleanup is `trap '' TERM INT HUP`, on both copies,
#                with a detector self-check (a signal first, a commented trap and a trap for TERM alone are not it).
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
#   behave). The Overview's key reader calls it again as soon as it has an answer, and a draw ends only for a B, Left or Right that has
#   come (it prints nothing more and ends the jq that is running), so WHEN the stand-in answers decides what a row sees. A plain word is
#   a press made after the screen is complete, as a person's is: the stand-in first waits until the frame of the draw that the call
#   before led to is out, when there is one (the first call, after A, a, LEFT or RIGHT, after a row was picked from the list, and after
#   an early word of any kind: the draw it came in goes on, or is cut and the next screen is drawn, and either ends in a frame; after a
#   plain Up, Down or junk word there is no draw and it answers at once). Frames are counted in
#   STARCHORUS_OUT, the Overview's output, against the count at the end of the call before. A word with a leading "!" is a press made at
#   once, wherever the draw is; one with a leading "@" a press made at "Reading...": it waits until the jq stand-in has started the
#   screen's program (STARCHORUS_JQ_STARTED exists) and answers then, so that several "@" words are several keys in one draw. Rows
#   that use them make the draw long (the "sleepjq" stand-in), so that the answers land inside it every time. It records its pid (one
#   line per call) in STARCHORUS_PIDS. At call number STARCHORUS_SWAP_AT it replaces the capture atomically (copy, then rename), as the collector does
#   (STARCHORUS_SWAP_TARGET: the file that is replaced when the Overview reads it through a link), after the wait for the frame, so the
#   swap falls between two draws and not into one. STARCHORUS_GAPS (a file, one number of hundredths of a second per call) moves the
#   uptime file under STARCHORUS_PROC on by that much before it answers, so the script sees a key that took that long.
#   STARCHORUS_PAD=1: every answer comes padded as a device may print it, spaces and a tab around the word and a CR at the end.
#   STARCHORUS_HOLD_AT=N: call N never answers, it becomes `sleep 30` (the same pid), a waiter nobody presses a key for.
#   STARCHORUS_SLOWTERM_AT=N: the same, but call N is slow to end: told to (TERM), it takes STARCHORUS_SLOWTERM seconds (0.3 by default) before it
#   goes, as a UI command that has to unregister first may.
#   STARCHORUS_KILL_AT=N with STARCHORUS_KILL_PID (a file): call N ends that process (the fake payload), and waits until it is gone,
#   before it answers. STARCHORUS_SABOTAGE_AT=N: call N makes the Overview's queue file read-only (the reader cannot append the answer,
#   as on a full file system), then answers.
#   STARCHORUS_UISIM=DIR: the UI as measured (M1), instead of the words of STARCHORUS_KEYS: a call registers itself (DIR/open holds its
#   pid) and waits for a press to be handed to it (DIR/press); the presser, a background process of the row, presses each key of its
#   list at the delay given, and a key that finds no wait open is lost and noted in DIR/lost. Rows that use it ask: is a key pressed in
#   a gap between two waits kept? A reader that opens its next wait at once finds one open every time.
#   LIST_PICKER writes its arguments to the UI log and answers a line of STARCHORUS_PICKS (no line = exit 0 and no answer, a cancel); an
#   answer marks that the next pass draws (the wait for the frame). It also notes how many of the pids in STARCHORUS_PIDS are alive
#   (waits open while the list shows) in STARCHORUS_UI_LOG.open. ERROR_DIALOG writes its text to the UI log.
#   Four "timeout" stand-ins live in directories of their own and join the PATH only where a row asks for one (macOS has no timeout):
#   tmolog logs the command word and runs the command, tmokill also ends the command after the time and answers 124 as GNU and BusyBox
#   do, tmofork runs the command as a child and waits for it, and does NOT end it when it is itself ended (the worst case of the
#   unknown implementation: a `timeout` that leaves its command running).
mkdir -p "$DST_D/cnt" "$DST_D/dev9" "$DST_D/tmolog" "$DST_D/tmokill" "$DST_D/tmofork" "$DST_D/slowjq" "$DST_D/sleepjq" "$DST_D/killjq" "$DST_D/noproc" "$DST_D/rodir" "$DST_D/forkcnt" "$DST_D/slowrm"
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
# outside (the Overview ends the children of a `timeout` first) ends it too. The health probe ("-n", no "-r") does not sleep, unless
# STARCHORUS_JQ_PSLEEP gives it a time: it then starts, notes its pid and is ended like a program run.
echo x >> "${STARCHORUS_JQ_COUNT:?}"
nap=; case " $* " in *" -r "*) nap=${STARCHORUS_JQ_SLEEP:-1} ;; *" -n "*) nap=${STARCHORUS_JQ_PSLEEP:-} ;; esac
if [ -n "$nap" ]; then
  [ -z "${STARCHORUS_JQ_PIDS:-}" ] || echo "$$" >> "$STARCHORUS_JQ_PIDS"
  [ -z "${STARCHORUS_JQ_STARTED:-}" ] || : > "$STARCHORUS_JQ_STARTED"
  sleep "$nap" & sp=$!
  trap '[ -z "${STARCHORUS_JQ_STARTED:-}" ] || : > "$STARCHORUS_JQ_STARTED.killed"; kill "$sp" 2>/dev/null; exit 143' TERM
  wait "$sp" || { [ -z "${STARCHORUS_JQ_STARTED:-}" ] || : > "$STARCHORUS_JQ_STARTED.killed"; exit 143; }
fi
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
if [ -n "${STARCHORUS_PIDS:-}" ] && [ -r "$STARCHORUS_PIDS" ] && [ -n "${STARCHORUS_UI_LOG:-}" ]; then   # how many waits are open while the list shows
  o=0; while read -r p; do if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then o=$((o + 1)); fi; done < "$STARCHORUS_PIDS"; echo "$o" >> "$STARCHORUS_UI_LOG.open"
fi
n=$(cat "${STARCHORUS_PICKS_N:-/dev/null}" 2>/dev/null || echo 0); n=$((n + 1)); [ -z "${STARCHORUS_PICKS_N:-}" ] || echo "$n" > "$STARCHORUS_PICKS_N"
a=; [ -z "${STARCHORUS_PICKS:-}" ] || a=$(sed -n "${n}p" "$STARCHORUS_PICKS")
[ -z "$a" ] || { : > "${STARCHORUS_CALLS:?}.picked"; printf '%s\n' "$a"; }   # a row was picked: the next pass draws
exit 0
DSTPICK
cat > "$DST_D/dev9/ERROR_DIALOG" <<'DSTERR'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- the text to the UI log; with the UI model also whether the wait registered as open is still alive at
# this moment (a dead reader's orphan would take the press meant for the dialog): up to 0.3 s for the shell to collect one that was just ended
if [ -n "${STARCHORUS_UISIM:-}" ] && [ -s "$STARCHORUS_UISIM/open" ]; then
  w=$(cat "$STARCHORUS_UISIM/open"); i=0
  while kill -0 "$w" 2>/dev/null && [ "$i" -lt 3 ]; do sleep 0.1; i=$((i + 1)); done
  ! kill -0 "$w" 2>/dev/null || echo "ERROR-WAIT-OPEN" >> "${STARCHORUS_UI_LOG:-/dev/null}"
fi
echo "ERROR $*" >> "${STARCHORUS_UI_LOG:-/dev/null}"
exit 0
DSTERR
cat > "$DST_D/dev9/WAIT_FOR_INPUT" <<'DSTWAIT'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- see the comment above it there
if [ -n "${STARCHORUS_UISIM:-}" ]; then   # the UI model: registered first, so that the gap between two waits is as short as it can be; a press is handed to the wait that is open
  echo "$$" > "$STARCHORUS_UISIM/open"
  echo "$$" >> "${STARCHORUS_PIDS:-/dev/null}"
  n=$(cat "${STARCHORUS_CALLS:?}" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$STARCHORUS_CALLS"
  echo "WAIT $n" >> "${STARCHORUS_UI_LOG:-/dev/null}"
  trap 'rm -f "$STARCHORUS_UISIM/open"; exit 143' TERM
  while [ ! -s "$STARCHORUS_UISIM/press" ]; do sleep 0.01 & wait $!; done
  k=$(cat "$STARCHORUS_UISIM/press"); rm -f "$STARCHORUS_UISIM/press" "$STARCHORUS_UISIM/open"
  echo "$k"; exit 0
fi
echo "$$" >> "${STARCHORUS_PIDS:-/dev/null}"
n=$(cat "${STARCHORUS_CALLS:?}" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$STARCHORUS_CALLS"
echo "WAIT $n" >> "${STARCHORUS_UI_LOG:-/dev/null}"
if [ "$n" = "${STARCHORUS_SLOWTERM_AT:-0}" ]; then   # call N never answers and is slow to leave: told to end, it takes STARCHORUS_SLOWTERM seconds (0.3) about it
  sleep 30 & sp=$!
  trap 'trap "" TERM; kill "$sp" 2>/dev/null; sleep "${STARCHORUS_SLOWTERM:-0.3}"; exit 143' TERM
  wait "$sp"; exit 0
fi
[ "$n" != "${STARCHORUS_HOLD_AT:-0}" ] || exec sleep 30
k=$(sed -n "${n}p" "${STARCHORUS_KEYS:?}")
pk=; [ "$n" -le 1 ] || pk=$(sed -n "$(($n - 1))p" "$STARCHORUS_KEYS")
# when is the press made: "!" at once, "@" once the jq of the screen's program runs, else after the draw the call before led to
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
if [ "$n" = "${STARCHORUS_SABOTAGE_AT:-0}" ]; then for d in "${TMPDIR:-/tmp}"/starchorus-ov.*/queue; do chmod 444 "$d" 2>/dev/null; done; fi
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
cat > "$DST_D/slowrm/rm" <<'DSTSLOWRM'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- `rm -rf DIR` the slow way: the files DIR holds are unlinked at once, then it waits STARCHORUS_RM_PAUSE seconds
# (0.6) and only then removes DIR itself with rmdir, which fails if something has been created in it meanwhile. The real rm does the same in a moment; this one
# widens the window so that a write that lands in it is seen every time. Any other call is the real rm.
real=$(PATH=${STARCHORUS_REAL_PATH:?} command -v rm)
if [ "${1:-}" = -rf ] && [ $# = 2 ] && [ -d "$2" ]; then
  "$real" -f "$2"/* 2>/dev/null
  sleep "${STARCHORUS_RM_PAUSE:-0.6}"
  rmdir "$2"
  exit $?
fi
exec "$real" "$@"
DSTSLOWRM
cat > "$DST_D/reaper" <<'DSTREAPER'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- reaper SIMDIR OUTFILE KEY: the key reader killed from outside, for the UI model of the WAIT_FOR_INPUT stand-in
# (STARCHORUS_UISIM). It waits (15 s at most) until the first screen's frame is in OUTFILE and a wait is open (SIMDIR/open holds its pid), kills the parent of
# that wait, which is the reader, with KILL (no trap runs: no `done` mark is written, as when the file system is full), notes the reader's pid in SIMDIR/reader and,
# 0.05 s later, presses KEY (unless it is "-") into the wait that the dead reader left open, as a person would.
sim=$1; out=$2; key=$3
n=0
while [ "$n" -lt 1500 ]; do
  if [ -s "$sim/open" ] && grep -qxF 'LOG A: Refresh   B: Back' "$out" 2>/dev/null; then break; fi
  sleep 0.01; n=$((n + 1))
done
w=$(cat "$sim/open" 2>/dev/null)
r=$(ps -o ppid= -p "${w:-0}" 2>/dev/null | tr -d ' ')
[ -n "$r" ] || exit 1
echo "$r" > "$sim/reader"
kill -9 "$r"
[ "$key" != - ] || exit 0
sleep 0.05
echo "$key" > "$sim/press.new" && mv "$sim/press.new" "$sim/press"
DSTREAPER
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
cat > "$DST_D/presser" <<'DSTPRESS'
#!/bin/sh
# generated by tools/regress.d/display-selftest.sh -- presser SIMDIR TRIGGER "DELAY:KEY DELAY:KEY ...": the person at the keys, for the UI model of the
# WAIT_FOR_INPUT stand-in (STARCHORUS_UISIM). It waits until the file TRIGGER exists (15 s at most), then presses each key DELAY seconds after the
# one before. A key goes to the wait that is open (SIMDIR/open holds the pid of a live process) and is lost, and noted in SIMDIR/lost, when none is.
sim=$1; trig=$2; spec=$3
n=0; while [ ! -e "$trig" ] && [ "$n" -lt 1500 ]; do sleep 0.01; n=$((n + 1)); done
for p in $spec; do
  sleep "${p%%:*}"; k=${p#*:}
  o=$(cat "$sim/open" 2>/dev/null)
  if [ -n "$o" ] && kill -0 "$o" 2>/dev/null; then echo "$k" > "$sim/press.new" && mv "$sim/press.new" "$sim/press"
  else echo "$k" >> "$sim/lost"; fi
done
DSTPRESS
cat > "$DST_D/dev9/stat" <<'DSTSTAT'
#!/bin/sh
echo "$*" >> "${STARCHORUS_STAT_LOG:?}"
exit 1
DSTSTAT
chmod +x "$DST_D/cnt/jq" "$DST_D/slowjq/jq" "$DST_D/sleepjq/jq" "$DST_D/killjq/jq" "$DST_D/dev9/LOG" "$DST_D/dev9/LIST_PICKER" "$DST_D/dev9/WAIT_FOR_INPUT" "$DST_D/dev9/ERROR_DIALOG" "$DST_D/dev9/stat" "$DST_D/payload" "$DST_D/presser" "$DST_D/reaper" \
         "$DST_D/tmolog/timeout" "$DST_D/tmokill/timeout" "$DST_D/tmofork/timeout" "$DST_D/rodir/mktemp" "$DST_D/slowrm/rm" "$DST_D/forkcnt/sed" "$DST_D/forkcnt/cut"

# dst_ov TAG COPY "KEYS" [VAR=value ...]: the Overview of COPY on the device path against the stand-ins, one answer per word of KEYS. Files
# in $DST_D: TAG.out (what it LOGged), TAG.ui (the UI commands it called, in order), TAG.calls (how many times it waited), TAG.pids (the pid of
# each waiter), TAG.jq (one line per jq process), TAG.stat, TAG.json (the capture: a copy of $DST_OVSRC, else many-clients.json), TAG.tmp (the
# TMPDIR of the run: the Overview's own temp dir lives there, and DST_OVLEFT adds up what a run left in it). The PATH is $DST_OVPATH in front of
# the stand-ins; the extra VAR=value words go to the script's environment last, so they override; the shell is $DST_OVSH, else sh.
# STARCHORUS_PROC points at an empty directory unless a row says otherwise: no /proc/uptime, no clock, so a Linux dev machine's own uptime
# cannot make the script judge an answer by time. Exit status in DST_RC. DST_OVDL (seconds): a deadline; an Overview that has not ended by
# then is ended with TERM (and KILL a moment later) and the status is 124, so a row whose Overview waits for a key that never comes (a
# press that was lost) ends as a failure and not as a hang.
DST_OVLEFT=0; DST_OVRUNS=0
dst_ovleft() { _dst_c=0; for _dst_f in "$1"/starchorus-ov.*; do [ -e "$_dst_f" ] && _dst_c=$((_dst_c + 1)); done; echo "$_dst_c"; }   # dst_ovleft DIR: Overview temp dirs in DIR
dst_ovrun() {   # the Overview itself, in the environment of dst_ov (_o_t, _o_c are its)
  env PATH="${DST_OVPATH:+$DST_OVPATH:}$DST_D/dev9:$DST_D/cnt:$PATH" STARCHORUS_REAL_JQ="$DST_JQ" STARCHORUS_JQ_COUNT="$DST_D/$_o_t.jq" \
      STARCHORUS_KEYS="$DST_D/$_o_t.keys" STARCHORUS_CALLS="$DST_D/$_o_t.calls" STARCHORUS_UI_LOG="$DST_D/$_o_t.ui" \
      STARCHORUS_OUT="$DST_D/$_o_t.out" STARCHORUS_PIDS="$DST_D/$_o_t.pids" TMPDIR="$DST_D/$_o_t.tmp" \
      STARCHORUS_STAT_LOG="$DST_D/$_o_t.stat" STARCHORUS_JSON="$DST_D/$_o_t.json" STARCHORUS_DIR="$DST_D/none" \
      STARCHORUS_PROC="$DST_D/noproc" "$@" "${DST_OVSH:-sh}" "$_o_c"
}
dst_ov() {
  _o_t=$1; _o_c=$2; _o_k=$3; shift 3
  # shellcheck disable=SC2086   # one answer per word, on purpose
  printf '%s\n' $_o_k > "$DST_D/$_o_t.keys"
  rm -f "$DST_D/$_o_t.calls" "$DST_D/$_o_t.pids" "$DST_D/$_o_t.ui.open"; : > "$DST_D/$_o_t.ui"; : > "$DST_D/$_o_t.jq"; : > "$DST_D/$_o_t.stat"
  rm -rf "$DST_D/$_o_t.tmp"; mkdir -p "$DST_D/$_o_t.tmp"
  cp "${DST_OVSRC:-$F/many-clients.json}" "$DST_D/$_o_t.json"
  if [ -z "${DST_OVDL:-}" ]; then
    dst_ovrun "$@" > "$DST_D/$_o_t.out" 2>&1
    DST_RC=$?
  else
    dst_ovrun "$@" > "$DST_D/$_o_t.out" 2>&1 &
    _o_p=$!; _o_w=0
    while kill -0 "$_o_p" 2>/dev/null && [ "$_o_w" -lt $((DST_OVDL * 10)) ]; do sleep 0.1; _o_w=$((_o_w + 1)); done
    if kill -0 "$_o_p" 2>/dev/null; then
      kill "$_o_p" 2>/dev/null; sleep 0.5; kill -9 "$_o_p" 2>/dev/null; wait "$_o_p" 2>/dev/null; DST_RC=124
    else wait "$_o_p"; DST_RC=$?; fi
  fi
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
  # the wait being opened to its end, which the key reader's own clock gives it). The first wait is an A that took 1.5 s: it redraws from the cache, so
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

# ---- S15 armed: the key wait is open before the draw is, and a draw ends for a key that asks for another screen. A jq stand-in sleeps 2 s on the screen's
# program, and the key stand-in answers with a "@" word, the moment that program has started: a press at "Reading...", whenever the machine happens to be
# slow or fast. Five things follow from the design, and each is looked at: (1) the answer is taken (the wait was open while the draw ran): B opens the
# list, RIGHT draws the next screen, and A and UP are taken as well, without a second draw; (2) the draw a B or a RIGHT came in ended: its jq was ended (the
# stand-in notes .killed; it would have run 1 s more) and no heading of that screen is printed; (3) nothing of that run was kept: the next screen's program
# runs in the draw that follows, so RIGHT shows 3 jq (the probe, the ended run, the run for the next screen); (4) an A or an Up that came in a draw does not
# end it (0.1.1 ended the draw on any key and drew the screen again): the draw is whole, its jq is not ended, there is one run and no second draw
# ("Reading..." once, one frame) and the B after it, pressed once that draw is complete, opens the list; (6) the ended draw prints no more once the key has
# come: no "Waiting for the first scan." (what a screen says when its jq has nothing to show, and that is what an ended jq looks like to it) and no frame,
# so the frames are those of the whole draws alone.
# tag|keys|screens|waits|lists|jq processes|Reading... lines|frames|jq of the first draw ended. The probe and a program run are one jq each; "Reading..."
# comes once per draw that has to run jq (the ended draw has it too; RIGHT's second screen has a program of its own).
DST_S15=0; DST_X15=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X15=$((DST_X15 + 1)); DST_L15=""
  for DST_Q in "A|@A B|s|2|1|2|1|1|no" "B|@B|-|1|1|2|1|0|yes" "RIGHT|@RIGHT B|t|2|1|3|2|1|yes" "UP|@UP B|s|2|1|2|1|1|no" "LEFT|@LEFT B|a|2|1|3|2|1|yes"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QK=$(printf '%s' "$DST_Q" | cut -d'|' -f2); DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f3)
    DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f4); DST_QL=$(printf '%s' "$DST_Q" | cut -d'|' -f5); DST_QJ=$(printf '%s' "$DST_Q" | cut -d'|' -f6)
    DST_QB=$(printf '%s' "$DST_Q" | cut -d'|' -f7); DST_QF=$(printf '%s' "$DST_Q" | cut -d'|' -f8); DST_QD=$(printf '%s' "$DST_Q" | cut -d'|' -f9)
    [ "$DST_QV" != - ] || DST_QV=
    DST_TG="s15-$DST_G-$DST_QT"; rm -f "$DST_D/$DST_TG.st" "$DST_D/$DST_TG.st.killed"
    DST_OVPATH="$DST_D/sleepjq"
    dst_ov "$DST_TG" "$DST_C" "$DST_QK" STARCHORUS_JQ_STARTED="$DST_D/$DST_TG.st" STARCHORUS_JQ_SLEEP=2
    DST_OVPATH=
    DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG")
    DST_AJ=$(grep -c x "$DST_D/$DST_TG.jq"); DST_AB=$(dst_cnt 'LOG Reading...' "$DST_D/$DST_TG.out"); DST_AD=no; [ ! -e "$DST_D/$DST_TG.st.killed" ] || DST_AD=yes
    DST_AN=$(dst_cnt 'LOG Waiting for the first scan.' "$DST_D/$DST_TG.out"); DST_AF=$(dst_cnt 'LOG A: Refresh   B: Back' "$DST_D/$DST_TG.out")
    if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP/$DST_AJ/$DST_AB/$DST_AD/$DST_AN/$DST_AF" != "0/$DST_QV/$DST_QW/$DST_QL/$DST_QJ/$DST_QB/$DST_QD/0/$DST_QF" ]; then
      DST_L15="$DST_L15 [$DST_QT: keys $DST_QK] rc $DST_RC, screens '$DST_A' (want '$DST_QV'), $DST_AW waits (want $DST_QW), $DST_AP lists (want $DST_QL), $DST_AJ jq (want $DST_QJ), Reading... $DST_AB (want $DST_QB), the jq of the first draw ended: $DST_AD (want $DST_QD), waiting lines $DST_AN (want 0), frames $DST_AF (want $DST_QF);"
    fi
  done
  # (5) a jq that is under a `timeout` which does not pass the signal on is ended all the same (the children of the `timeout` first), and so is the
  # `timeout`: neither is there when the Overview ends; one run, RIGHT at "Reading..." then B
  DST_TG="s15-$DST_G-tree"; rm -f "$DST_D/$DST_TG.st" "$DST_D/$DST_TG.st.killed" "$DST_D/$DST_TG.jqp" "$DST_D/$DST_TG.tmp.pids"
  DST_OVPATH="$DST_D/tmofork:$DST_D/sleepjq"
  dst_ov "$DST_TG" "$DST_C" "@RIGHT B" STARCHORUS_JQ_STARTED="$DST_D/$DST_TG.st" STARCHORUS_JQ_PIDS="$DST_D/$DST_TG.jqp" STARCHORUS_TMO_PIDS="$DST_D/$DST_TG.tmp.pids" STARCHORUS_JQ_SLEEP=3
  DST_OVPATH=
  DST_NJ=$(grep -c . "$DST_D/$DST_TG.jqp"); DST_AL=$(dst_alive "$DST_D/$DST_TG.jqp"); DST_NT=$(grep -c . "$DST_D/$DST_TG.tmp.pids"); DST_AT=$(dst_alive "$DST_D/$DST_TG.tmp.pids")
  DST_AD=no; [ ! -e "$DST_D/$DST_TG.st.killed" ] || DST_AD=yes
  if [ "$DST_RC/$DST_NJ/$DST_AL/$DST_NT/$DST_AT/$DST_AD" != "0/2/0/2/0/yes" ]; then
    DST_L15="$DST_L15 [tree] rc $DST_RC, $DST_NJ program runs (want 2), $DST_AL still there (want 0), $DST_NT timeouts (want 2), $DST_AT still there (want 0), jq of the first draw ended: $DST_AD (want yes);"
  fi
  if [ -z "$DST_L15" ]; then DST_S15=$((DST_S15 + 1)); else echo "    armed, $DST_G copy:$DST_L15"; fi
done
if [ "$DST_S15" = "$DST_X15" ]; then row "display armed: the wait is open before the draw, a B, Left or Right at Reading... ends that draw (its jq is ended and not kept, also under a timeout that passes no signal on) and is acted on at once; an A or an Up leaves it running and asks for nothing more ($DST_X15 copies)" PASS
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
# while it answers (the Overview must stop at that key; the key reader has opened its next wait by then, so there are two waits, and the second,
# still pending, is ended by the Overview's exit: two pids, none alive), (d) the payload gone before the first wait (a pid that is dead).
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
  # (c) the payload ends during the first wait; the Overview is a child of the fake payload and goes on alone. The reader has started its second wait
  # before the shell has taken the key and asked after the payload: it is pending when the Overview exits, and the exit must end it
  DST_TG="s17-$DST_G-gone"; DST_PF="$DST_D/$DST_TG.payload"; : > "$DST_PF"; DST_SAVE=$DST_OVLEFT
  DST_OVSH="$DST_D/payload"
  dst_ov "$DST_TG" "$DST_C" "A B" STARCHORUS_KILL_PID="$DST_PF" STARCHORUS_KILL_AT=1 2> /dev/null   # the shell's "Terminated" notice for the fake payload goes nowhere
  DST_OVSH=
  DST_W=0; while [ "$(dst_ovleft "$DST_D/$DST_TG.tmp")" != 0 ] && [ "$DST_W" -lt 100 ]; do sleep 0.05; DST_W=$((DST_W + 1)); done   # it ends by itself
  DST_OVLEFT=$((DST_SAVE + $(dst_ovleft "$DST_D/$DST_TG.tmp")))
  DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG")
  DST_NP=$(grep -c . "$DST_D/$DST_TG.pids"); DST_AL=$(dst_alive "$DST_D/$DST_TG.pids")
  if [ "$DST_A/$DST_AW/$DST_AP/$DST_NP/$DST_AL" != s/2/0/2/0 ]; then
    DST_L17="$DST_L17 [payload gone after the first key] screens '$DST_A' (want s), $DST_AW waits (want 2), $DST_AP lists (want 0), $DST_NP pids (want 2), $DST_AL still there (want 0);"
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
  row "display nopending: no waiter left after B out, three strikes, the payload gone after a key or before the first wait; no temp dir left by any of $DST_OVRUNS Overview runs ($DST_X17 copies)" PASS
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
dst_s18_start() {   # dst_s18_start SHELL COPY: the Overview of S18 in the background, its pid in DST_P; the call that holds is number DST_HOLD (1 by default)
  [ -z "$DST_HUPX" ] || set -- python3 "$DST_D/hupdfl.py" "$@"
  env PATH="$DST_PA" STARCHORUS_REAL_JQ="$DST_JQ" STARCHORUS_JQ_COUNT="$DST_D/$DST_TG.jq" \
      STARCHORUS_KEYS="$DST_D/$DST_TG.keys" STARCHORUS_CALLS="$DST_D/$DST_TG.calls" STARCHORUS_UI_LOG="$DST_D/$DST_TG.ui" \
      STARCHORUS_OUT="$DST_D/$DST_TG.out" STARCHORUS_PIDS="$DST_D/$DST_TG.pids" TMPDIR="$DST_D/$DST_TG.tmp" STARCHORUS_HOLD_AT="${DST_HOLD:-1}" \
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
      while [ "$DST_W" -lt 200 ]; do   # the reader's wait is open, and the screen is drawn (idle) or its jq program is running (draw)
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
# and the next draw or nap) and reads the parent from field 4 of the stat file of its own shell. A fake proc directory (STARCHORUS_PROC) holds
# self/stat with the parent the row wants: the payload's own pid (the Overview goes on) or another (it was handed over and ends before it draws or
# waits for anything). `sed` and `cut` stand-ins note every process started for them. The summary's own template line starts a few (that is the draw,
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

# ---- S20 keyerr: the queue cannot be written. (a) At the start: the temp dir is read-only (a `mktemp` stand-in makes it so), the Overview says
# "Overview could not start." in an error dialog, exits 1, starts no reader and draws nothing, and the dir is gone. (b) Later: the stand-in makes the queue file read-only
# at its first wait, so the reader's answer cannot be written and the queue stays empty; that is not an empty answer (three of them would
# be three strikes, and the Overview would end in silence) but a failure, named in an error dialog: "Overview could not read a key.", exit 1,
# no second wait. A read-only file is only a fault for a user who is not root, so the row is skipped for root.
DST_S20=0; DST_X20=0
if [ "$(id -u 2>/dev/null)" = 0 ]; then notcov "display keyerr: a queue that cannot be written (the row needs a user who is not root)"; else
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
if [ "$DST_S20" = "$DST_X20" ] && [ "$DST_OVLEFT" = 0 ]; then row "display keyerr: a queue that cannot be written is an error at the start or a named failure later, not three empty answers ($DST_X20 copies)" PASS
else row "display keyerr: $DST_S20/$DST_X20 copies as expected, $DST_OVLEFT temp dir(s) left" FAIL; DST_KEEP=1; fi
fi

# ---- S21 queue: keys pressed in one draw are kept, in the order they were pressed, and none is lost. This row runs the UI as measured on the device (M1,
# docs/device-notes.md section 7): a press reaches a wait that is open and is LOST when none is. A jq stand-in sleeps 2 s on the screen's program; the presser
# starts when it has started and presses each key 0.1 s after the one before, so the keys fall into one draw and into the gap between one wait and the next (a
# fork and an exec for a key reader that opens its next wait at once; 0.2 s and a jq to end for a shell that opens one wait per draw, whose second press is lost).
# Cases: (rightb) RIGHT, B: the list opens on the screen that RIGHT asked for ("Strongest Networks"), and no screen is drawn; (order) X X A X X B: two strikes,
# an A, two strikes, a B; in that order there are never three strikes in a row, so the list opens, where a queue that mixed the order up (X X X X A) would end the
# Overview at the third X; (three) LEFT, RIGHT, RIGHT, B: three steps and then the list on the screen they lead to. Every press must be taken: nothing in DIR/lost.
# tag|presses|waits|list default
DST_S21=0; DST_X21=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X21=$((DST_X21 + 1)); DST_L21=""
  for DST_Q in "rightb|0:RIGHT 0.1:B|2|Strongest Networks" "order|0:X 0.1:X 0.1:A 0.1:X 0.1:X 0.1:B|6|Summary" "three|0:LEFT 0.1:RIGHT 0.1:RIGHT 0.1:B|4|Strongest Networks"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QP=$(printf '%s' "$DST_Q" | cut -d'|' -f2); DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f3)
    DST_QD=$(printf '%s' "$DST_Q" | cut -d'|' -f4)
    DST_TG="s21-$DST_G-$DST_QT"; rm -rf "$DST_D/$DST_TG.sim" "$DST_D/$DST_TG.st"; mkdir -p "$DST_D/$DST_TG.sim"
    "$DST_D/presser" "$DST_D/$DST_TG.sim" "$DST_D/$DST_TG.st" "$DST_QP" & DST_PR=$!
    DST_OVPATH="$DST_D/sleepjq"; DST_OVDL=15
    dst_ov "$DST_TG" "$DST_C" "-" STARCHORUS_UISIM="$DST_D/$DST_TG.sim" STARCHORUS_JQ_STARTED="$DST_D/$DST_TG.st" STARCHORUS_JQ_SLEEP=2
    DST_OVPATH=; DST_OVDL=
    { kill "$DST_PR"; wait "$DST_PR"; } 2>/dev/null
    DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG")
    DST_AD=$(grep '^PICKER' "$DST_D/$DST_TG.ui" | sed -n 1p); DST_AD=${DST_AD##*|}
    DST_LO=$(tr '\n' ' ' 2>/dev/null < "$DST_D/$DST_TG.sim/lost"); DST_LO=${DST_LO% }
    if [ "$DST_RC/$DST_AW/$DST_AP/$DST_AD/$DST_A/$DST_LO" != "0/$DST_QW/1/$DST_QD//" ]; then
      DST_L21="$DST_L21 [$DST_QT: presses $DST_QP] rc $DST_RC, $DST_AW waits (want $DST_QW), $DST_AP lists (want 1), list on '$DST_AD' (want '$DST_QD'), screens '$DST_A' (want none), presses lost '$DST_LO' (want none);"
    fi
  done
  if [ -z "$DST_L21" ]; then DST_S21=$((DST_S21 + 1)); else echo "    queue, $DST_G copy:$DST_L21"; fi
done
if [ "$DST_S21" = "$DST_X21" ]; then row "display queue: keys pressed 0.1 s apart in one draw are all taken and acted on in the order they came (RIGHT then B opens the list on the next screen; X X A X X B does not end on three strikes; LEFT RIGHT RIGHT B; $DST_X21 copies)" PASS
else row "display queue: $DST_S21/$DST_X21 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S22 aanswered: an A pressed during a draw is answered by that draw once it is finished: one draw, one jq run, no second screen, however many A there are
# (0.1.1 ended the draw on the A and drew the screen again, which started jq again, so on a slow capture an impatient A never showed a screen). The "@" words
# press at "Reading..." (the jq stand-in sleeps 2 s on the program); the plain word after them is pressed once the screen is complete. An A pressed then, and not
# before, draws the screen again: from the cache, with no jq. tag|keys|screens|waits|lists|jq processes|Reading... lines|frames|jq ended
DST_S22=0; DST_X22=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X22=$((DST_X22 + 1)); DST_L22=""
  for DST_Q in "one|@A B|s|2|1|2|1|1|no" "three|@A @A @A B|s|4|1|2|1|1|no" "later|@A A B|ss|3|1|2|1|2|no"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QK=$(printf '%s' "$DST_Q" | cut -d'|' -f2); DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f3)
    DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f4); DST_QL=$(printf '%s' "$DST_Q" | cut -d'|' -f5); DST_QJ=$(printf '%s' "$DST_Q" | cut -d'|' -f6)
    DST_QB=$(printf '%s' "$DST_Q" | cut -d'|' -f7); DST_QF=$(printf '%s' "$DST_Q" | cut -d'|' -f8); DST_QD=$(printf '%s' "$DST_Q" | cut -d'|' -f9)
    DST_TG="s22-$DST_G-$DST_QT"; rm -f "$DST_D/$DST_TG.st" "$DST_D/$DST_TG.st.killed"
    DST_OVPATH="$DST_D/sleepjq"
    dst_ov "$DST_TG" "$DST_C" "$DST_QK" STARCHORUS_JQ_STARTED="$DST_D/$DST_TG.st" STARCHORUS_JQ_SLEEP=2
    DST_OVPATH=
    DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG"); DST_AJ=$(grep -c x "$DST_D/$DST_TG.jq")
    DST_AB=$(dst_cnt 'LOG Reading...' "$DST_D/$DST_TG.out"); DST_AF=$(dst_cnt 'LOG A: Refresh   B: Back' "$DST_D/$DST_TG.out")
    DST_AE=no; [ ! -e "$DST_D/$DST_TG.st.killed" ] || DST_AE=yes
    if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP/$DST_AJ/$DST_AB/$DST_AF/$DST_AE" != "0/$DST_QV/$DST_QW/$DST_QL/$DST_QJ/$DST_QB/$DST_QF/$DST_QD" ]; then
      DST_L22="$DST_L22 [$DST_QT: keys $DST_QK] rc $DST_RC, screens '$DST_A' (want '$DST_QV'), $DST_AW waits (want $DST_QW), $DST_AP lists (want $DST_QL), $DST_AJ jq (want $DST_QJ), Reading... $DST_AB (want $DST_QB), frames $DST_AF (want $DST_QF), jq ended: $DST_AE (want $DST_QD);"
    fi
  done
  if [ -z "$DST_L22" ]; then DST_S22=$((DST_S22 + 1)); else echo "    aanswered, $DST_G copy:$DST_L22"; fi
done
if [ "$DST_S22" = "$DST_X22" ]; then row "display aanswered: an A pressed during a draw is answered by the finished draw (one screen, one jq run, whether one A or three); an A after the screen draws it again from the cache ($DST_X22 copies)" PASS
else row "display aanswered: $DST_S22/$DST_X22 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S23 bcut: a B pressed during a draw ends it at once and goes up: the jq of the draw is ended (the stand-in notes it), nothing of the screen is printed, the list
# opens on that screen, and no wait is open while it shows (the key reader ended itself on the B; a wait open under the list would share the picker's keys: the
# picker stand-in counts the live pids of STARCHORUS_PIDS into UI_LOG.open). Cases: (b) the B alone; (upab) Up, A, B in one draw: the Up is ignored, the A is
# answered by nothing (the draw it came in is cut by the B), the B wins; (idle) a B pressed once the screen is complete: the draw is whole, then the list.
# tag|keys|screens|waits|lists|jq processes|Reading... lines|frames|jq ended|waits open at the list
DST_S23=0; DST_X23=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X23=$((DST_X23 + 1)); DST_L23=""
  for DST_Q in "b|@B|-|1|1|2|1|0|yes|0" "upab|@UP @A @B|-|3|1|2|1|0|yes|0" "idle|B|s|1|1|2|1|1|no|0"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QK=$(printf '%s' "$DST_Q" | cut -d'|' -f2); DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f3)
    DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f4); DST_QL=$(printf '%s' "$DST_Q" | cut -d'|' -f5); DST_QJ=$(printf '%s' "$DST_Q" | cut -d'|' -f6)
    DST_QB=$(printf '%s' "$DST_Q" | cut -d'|' -f7); DST_QF=$(printf '%s' "$DST_Q" | cut -d'|' -f8); DST_QD=$(printf '%s' "$DST_Q" | cut -d'|' -f9)
    DST_QO=$(printf '%s' "$DST_Q" | cut -d'|' -f10); [ "$DST_QV" != - ] || DST_QV=
    DST_TG="s23-$DST_G-$DST_QT"; rm -f "$DST_D/$DST_TG.st" "$DST_D/$DST_TG.st.killed"
    DST_OVPATH="$DST_D/sleepjq"
    dst_ov "$DST_TG" "$DST_C" "$DST_QK" STARCHORUS_JQ_STARTED="$DST_D/$DST_TG.st" STARCHORUS_JQ_SLEEP=2
    DST_OVPATH=
    DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG"); DST_AJ=$(grep -c x "$DST_D/$DST_TG.jq")
    DST_AB=$(dst_cnt 'LOG Reading...' "$DST_D/$DST_TG.out"); DST_AF=$(dst_cnt 'LOG A: Refresh   B: Back' "$DST_D/$DST_TG.out")
    DST_AE=no; [ ! -e "$DST_D/$DST_TG.st.killed" ] || DST_AE=yes
    DST_AO=$(tr '\n' ' ' 2>/dev/null < "$DST_D/$DST_TG.ui.open"); DST_AO=${DST_AO% }
    DST_AD=$(grep '^PICKER' "$DST_D/$DST_TG.ui" | sed -n 1p); DST_AD=${DST_AD##*|}
    DST_AN=$(dst_cnt 'LOG Waiting for the first scan.' "$DST_D/$DST_TG.out")
    if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP/$DST_AJ/$DST_AB/$DST_AF/$DST_AE/$DST_AO/$DST_AD/$DST_AN" != "0/$DST_QV/$DST_QW/$DST_QL/$DST_QJ/$DST_QB/$DST_QF/$DST_QD/$DST_QO/Summary/0" ]; then
      DST_L23="$DST_L23 [$DST_QT: keys $DST_QK] rc $DST_RC, screens '$DST_A' (want '$DST_QV'), $DST_AW waits (want $DST_QW), $DST_AP lists (want $DST_QL), $DST_AJ jq (want $DST_QJ), Reading... $DST_AB (want $DST_QB), frames $DST_AF (want $DST_QF), jq ended: $DST_AE (want $DST_QD), waits open at the list '$DST_AO' (want $DST_QO), list on '$DST_AD' (want Summary), waiting lines $DST_AN (want 0);"
    fi
  done
  if [ -z "$DST_L23" ]; then DST_S23=$((DST_S23 + 1)); else echo "    bcut, $DST_G copy:$DST_L23"; fi
done
if [ "$DST_S23" = "$DST_X23" ]; then row "display bcut: a B pressed during a draw ends it at once (its jq is ended, nothing of the screen is printed) and opens the list, with no wait open while it shows; an Up and an A before it change nothing ($DST_X23 copies)" PASS
else row "display bcut: $DST_S23/$DST_X23 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S24 lrcut: LEFT and RIGHT pressed during a draw end it at once and switch screens, in the order of the list and round its ends. Two or more in one draw skip the
# screens between: they are not drawn at all (no heading, no frame), the last is drawn whole, and the list a B opens next has its cursor on it. How many jq runs and
# "Reading..." lines the skipped screens cost depends on whether the second press is in the queue before the shell looks (a few milliseconds apart), so those two
# are counted for a single press only ("x" = not looked at). tag|keys|screens|waits|lists|list default|jq processes|Reading... lines|frames
DST_S24=0; DST_X24=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X24=$((DST_X24 + 1)); DST_L24=""
  for DST_Q in "right|@RIGHT B|t|2|1|Strongest Networks|3|2|1" "left|@LEFT B|a|2|1|Air Quality|3|2|1" "twice|@RIGHT @RIGHT B|b|3|1|Bands & Security|x|x|1" \
               "round|@LEFT @RIGHT @RIGHT B|t|4|1|Strongest Networks|x|x|1"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QK=$(printf '%s' "$DST_Q" | cut -d'|' -f2); DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f3)
    DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f4); DST_QL=$(printf '%s' "$DST_Q" | cut -d'|' -f5); DST_QD=$(printf '%s' "$DST_Q" | cut -d'|' -f6)
    DST_QJ=$(printf '%s' "$DST_Q" | cut -d'|' -f7); DST_QB=$(printf '%s' "$DST_Q" | cut -d'|' -f8); DST_QF=$(printf '%s' "$DST_Q" | cut -d'|' -f9)
    DST_TG="s24-$DST_G-$DST_QT"; rm -f "$DST_D/$DST_TG.st" "$DST_D/$DST_TG.st.killed"
    DST_OVPATH="$DST_D/sleepjq"
    dst_ov "$DST_TG" "$DST_C" "$DST_QK" STARCHORUS_JQ_STARTED="$DST_D/$DST_TG.st" STARCHORUS_JQ_SLEEP=2
    DST_OVPATH=
    DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG"); DST_AJ=$(grep -c x "$DST_D/$DST_TG.jq")
    DST_AB=$(dst_cnt 'LOG Reading...' "$DST_D/$DST_TG.out"); DST_AF=$(dst_cnt 'LOG A: Refresh   B: Back' "$DST_D/$DST_TG.out")
    DST_AE=no; [ ! -e "$DST_D/$DST_TG.st.killed" ] || DST_AE=yes
    DST_AD=$(grep '^PICKER' "$DST_D/$DST_TG.ui" | sed -n 1p); DST_AD=${DST_AD##*|}
    [ "$DST_QJ" != x ] || DST_AJ=x; [ "$DST_QB" != x ] || DST_AB=x
    if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP/$DST_AD/$DST_AJ/$DST_AB/$DST_AF/$DST_AE" != "0/$DST_QV/$DST_QW/$DST_QL/$DST_QD/$DST_QJ/$DST_QB/$DST_QF/yes" ]; then
      DST_L24="$DST_L24 [$DST_QT: keys $DST_QK] rc $DST_RC, screens '$DST_A' (want '$DST_QV'), $DST_AW waits (want $DST_QW), $DST_AP lists (want $DST_QL), list on '$DST_AD' (want '$DST_QD'), $DST_AJ jq (want $DST_QJ), Reading... $DST_AB (want $DST_QB), frames $DST_AF (want $DST_QF), jq of the first draw ended: $DST_AE (want yes);"
    fi
  done
  if [ -z "$DST_L24" ]; then DST_S24=$((DST_S24 + 1)); else echo "    lrcut, $DST_G copy:$DST_L24"; fi
done
if [ "$DST_S24" = "$DST_X24" ]; then row "display lrcut: LEFT and RIGHT pressed during a draw end it at once and switch screens, round the ends; several in one draw skip the screens between, which are not drawn ($DST_X24 copies)" PASS
else row "display lrcut: $DST_S24/$DST_X24 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S25 udquiet: UP and DOWN pressed during a draw change nothing: the draw runs to its end, whole (its jq is not ended), nothing is drawn again, they are no strikes
# (five of them in a row would be, were they counted), and they are not left in the queue: an A pressed after the screen is complete draws it once more, from the
# cache, exactly as if they had never come. tag|keys|screens|waits|lists|jq processes|Reading... lines|frames|jq ended
DST_S25=0; DST_X25=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X25=$((DST_X25 + 1)); DST_L25=""
  for DST_Q in "updown|@UP @DOWN @UP @DOWN @UP B|s|6|1|2|1|1|no" "thena|@UP @DOWN A B|ss|4|1|2|1|2|no"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QK=$(printf '%s' "$DST_Q" | cut -d'|' -f2); DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f3)
    DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f4); DST_QL=$(printf '%s' "$DST_Q" | cut -d'|' -f5); DST_QJ=$(printf '%s' "$DST_Q" | cut -d'|' -f6)
    DST_QB=$(printf '%s' "$DST_Q" | cut -d'|' -f7); DST_QF=$(printf '%s' "$DST_Q" | cut -d'|' -f8); DST_QD=$(printf '%s' "$DST_Q" | cut -d'|' -f9)
    DST_TG="s25-$DST_G-$DST_QT"; rm -f "$DST_D/$DST_TG.st" "$DST_D/$DST_TG.st.killed"
    DST_OVPATH="$DST_D/sleepjq"
    dst_ov "$DST_TG" "$DST_C" "$DST_QK" STARCHORUS_JQ_STARTED="$DST_D/$DST_TG.st" STARCHORUS_JQ_SLEEP=2
    DST_OVPATH=
    DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG"); DST_AJ=$(grep -c x "$DST_D/$DST_TG.jq")
    DST_AB=$(dst_cnt 'LOG Reading...' "$DST_D/$DST_TG.out"); DST_AF=$(dst_cnt 'LOG A: Refresh   B: Back' "$DST_D/$DST_TG.out")
    DST_AE=no; [ ! -e "$DST_D/$DST_TG.st.killed" ] || DST_AE=yes
    if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP/$DST_AJ/$DST_AB/$DST_AF/$DST_AE" != "0/$DST_QV/$DST_QW/$DST_QL/$DST_QJ/$DST_QB/$DST_QF/$DST_QD" ]; then
      DST_L25="$DST_L25 [$DST_QT: keys $DST_QK] rc $DST_RC, screens '$DST_A' (want '$DST_QV'), $DST_AW waits (want $DST_QW), $DST_AP lists (want $DST_QL), $DST_AJ jq (want $DST_QJ), Reading... $DST_AB (want $DST_QB), frames $DST_AF (want $DST_QF), jq ended: $DST_AE (want $DST_QD);"
    fi
  done
  if [ -z "$DST_L25" ]; then DST_S25=$((DST_S25 + 1)); else echo "    udquiet, $DST_G copy:$DST_L25"; fi
done
if [ "$DST_S25" = "$DST_X25" ]; then row "display udquiet: UP and DOWN pressed during a draw leave it running and change nothing: one whole draw, no strike, no residue (a later A draws once more from the cache) ($DST_X25 copies)" PASS
else row "display udquiet: $DST_S25/$DST_X25 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S26 reader: no waiter is left behind by the key reader, however the Overview ends, and the cleanup names the pids the reader knows. The reader has a wait open at
# every moment a key is not being answered, so each way out is tried with a wait pending after keys that were answered (S17 and S18 do it with the first wait only):
# (a) A, Up, B: the reader ends itself on the B; three waits, none alive, none open while the list shows; (b) the payload gone at the second key: the third wait, opened
# by the reader at once, is pending when the Overview exits, and the exit ends it; (c) TERM, and HUP as S18 does it (its relauncher under nohup, kept), with the third wait
# held for 30 s: all three pids gone within a second, the temp dir removed, exit 143 and 129, under sh and, when installed, dash; (d) TERM 0 to 80 ms after the start,
# whatever the Overview is doing then (setting its traps, making its directory, forking the reader): it ends, and no waiter and no directory are left; (e) ov_cleanup
# holds no `$!`: it takes the reader's pid from OV_RPID and its wait from the file the reader writes (a text check, with a detector self-check); (f) the shell
# killed with KILL, where no cleanup runs: when the reader's pending wait ends, the reader finds its shell gone, opens no other wait and ends.
DST_S26=0; DST_X26=0; DST_Y26=0; DST_HUPNOTE26=""
dst_fn() { awk -v n="$1" 'index($0, n "() {") == 1 { f = 1 } f { print } f && /^}/ { exit }'; }   # dst_fn NAME: the text of that shell function from a script on stdin
# shellcheck disable=SC2016   # the planted text is literal script text
DST_PL=$(printf '%s\n' 'ov_cleanup() {' '    ov_last=$!' '}' | dst_fn ov_cleanup | dst_code | grep -c '\$!')
# shellcheck disable=SC2016
DST_PC=$(printf '%s\n' 'ov_cleanup() {' '    # not $! here' '    kill "$OV_RPID"' '}' | dst_fn ov_cleanup | dst_code | grep -c '\$!')
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X26=$((DST_X26 + 1)); DST_L26=""
  # (a) the reader ends itself on the B: three waits, all gone, none open while the list shows
  DST_TG="s26-$DST_G-b"
  dst_ov "$DST_TG" "$DST_C" "A UP B"
  DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_NP=$(grep -c . "$DST_D/$DST_TG.pids"); DST_AL=$(dst_alive "$DST_D/$DST_TG.pids")
  DST_AO=$(tr '\n' ' ' 2>/dev/null < "$DST_D/$DST_TG.ui.open"); DST_AO=${DST_AO% }
  if [ "$DST_RC/$DST_A/$DST_AW/$DST_NP/$DST_AL/$DST_AO" != "0/ss/3/3/0/0" ]; then
    DST_L26="$DST_L26 [A, Up, B] rc $DST_RC, screens '$DST_A' (want ss), $DST_AW waits (want 3), $DST_NP pids (want 3), $DST_AL still there (want 0), waits open at the list '$DST_AO' (want 0);"
  fi
  # (b) the payload ends during the second wait (the stand-in ends it as it answers); the reader's third wait is pending then
  DST_TG="s26-$DST_G-gone"; DST_PF="$DST_D/$DST_TG.payload"; : > "$DST_PF"; DST_SAVE=$DST_OVLEFT
  DST_OVSH="$DST_D/payload"
  dst_ov "$DST_TG" "$DST_C" "A A B" STARCHORUS_KILL_PID="$DST_PF" STARCHORUS_KILL_AT=2 2> /dev/null
  DST_OVSH=
  DST_W=0; while [ "$(dst_ovleft "$DST_D/$DST_TG.tmp")" != 0 ] && [ "$DST_W" -lt 100 ]; do sleep 0.05; DST_W=$((DST_W + 1)); done
  DST_OVLEFT=$((DST_SAVE + $(dst_ovleft "$DST_D/$DST_TG.tmp")))
  DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG")
  DST_NP=$(grep -c . "$DST_D/$DST_TG.pids"); DST_AL=$(dst_alive "$DST_D/$DST_TG.pids")
  if [ "$DST_A/$DST_AW/$DST_AP/$DST_NP/$DST_AL" != ss/3/0/3/0 ]; then
    DST_L26="$DST_L26 [payload gone at the second key] screens '$DST_A' (want ss), $DST_AW waits (want 3), $DST_AP lists (want 0), $DST_NP pids (want 3), $DST_AL still there (want 0);"
  fi
  # (e) the text of ov_cleanup
  DST_CF=$(dst_code < "$DST_C" | dst_fn ov_cleanup)
  DST_CB=$(printf '%s\n' "$DST_CF" | grep -c '\$!'); DST_CR=$(printf '%s\n' "$DST_CF" | grep -c 'OV_RPID'); DST_CW=$(printf '%s\n' "$DST_CF" | grep -c 'OV_WPF')
  if [ "$DST_PL" != 1 ] || [ "$DST_PC" != 0 ] || [ "$DST_CB" != 0 ] || [ "$DST_CR" -lt 1 ] || [ "$DST_CW" -lt 1 ]; then
    DST_L26="$DST_L26 [ov_cleanup text] the detector finds the planted \$! $DST_PL times (want 1) and the commented one $DST_PC (want 0); \$! in ov_cleanup $DST_CB (want 0), OV_RPID lines $DST_CR and OV_WPF lines $DST_CW (want at least 1 each);"
  fi
  if [ -z "$DST_L26" ]; then DST_S26=$((DST_S26 + 1)); else echo "    reader, $DST_G copy:$DST_L26"; fi
done
# (c) TERM and HUP with the reader's third wait held, and (d) TERM early, under each shell the runner has
for DST_X in $DST_SHELLS; do
  DST_XP=$(command -v "$DST_X"); case $DST_XP in /*) ;; *) DST_XP=$DST_SH ;; esac
  DST_HUPX=""; DST_HUPQ="HUP|129"
  if dst_hupok "$DST_XP"; then :
  elif dst_hupok "$DST_XP" relaunch; then DST_HUPX=1; DST_HUPNOTE26="$DST_HUPNOTE26; HUP put back to default for $DST_X, the runner had it ignored"
  else DST_HUPQ=""; DST_HUPNOTE26="$DST_HUPNOTE26; HUP case not run for $DST_X: the runner has it ignored and python3 could not put it back"; fi
  for DST_E in $DST_COPIES; do
    DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_L26=""; DST_X26=$((DST_X26 + 1))
    # shellcheck disable=SC2086   # DST_HUPQ is one word or none
    for DST_Q in "TERM|143" $DST_HUPQ; do
      DST_QS=${DST_Q%%|*}; DST_QR=${DST_Q#*|}; DST_Y26=$((DST_Y26 + 1)); DST_TG="s26-$DST_G-$DST_X-held-$DST_QS"
      printf '%s\n' A A > "$DST_D/$DST_TG.keys"
      rm -f "$DST_D/$DST_TG.calls" "$DST_D/$DST_TG.pids"; : > "$DST_D/$DST_TG.ui"; : > "$DST_D/$DST_TG.jq"; : > "$DST_D/$DST_TG.stat"; : > "$DST_D/$DST_TG.out"
      rm -rf "$DST_D/$DST_TG.tmp"; mkdir -p "$DST_D/$DST_TG.tmp"; cp "$F/many-clients.json" "$DST_D/$DST_TG.json"
      DST_PA="$DST_D/dev9:$DST_D/cnt:$PATH"; DST_HOLD=3
      dst_s18_start "$DST_XP" "$DST_C"
      DST_HOLD=
      DST_W=0
      while [ "$DST_W" -lt 200 ]; do   # two keys answered, the draws for them out, the third wait pending (held for 30 s)
        if [ "$(cat "$DST_D/$DST_TG.pids" 2>/dev/null | grep -c .)" -ge 3 ] && [ "$(grep -c '^LOG A: Refresh   B: Back$' "$DST_D/$DST_TG.out")" -ge 3 ]; then break; fi
        sleep 0.05; DST_W=$((DST_W + 1))
      done
      DST_UP=$(dst_alive "$DST_D/$DST_TG.pids"); DST_TB=$(dst_ovleft "$DST_D/$DST_TG.tmp")
      kill -"$DST_QS" "$DST_P" 2>/dev/null
      DST_W=0; while [ "$(dst_alive "$DST_D/$DST_TG.pids")" != 0 ] && [ "$DST_W" -lt 10 ]; do sleep 0.1; DST_W=$((DST_W + 1)); done
      DST_GONE=$(dst_alive "$DST_D/$DST_TG.pids")
      if [ "$DST_GONE" != 0 ]; then while read -r DST_WP; do [ -z "$DST_WP" ] || kill "$DST_WP" 2>/dev/null; done < "$DST_D/$DST_TG.pids"; fi
      { wait "$DST_P"; DST_RC=$?; } 2>/dev/null; DST_TA=$(dst_ovleft "$DST_D/$DST_TG.tmp"); DST_NP=$(grep -c . "$DST_D/$DST_TG.pids")
      if [ "$DST_UP/$DST_TB/$DST_NP/$DST_GONE/$DST_RC/$DST_TA" != "1/1/3/0/$DST_QR/0" ]; then
        DST_L26="$DST_L26 [$DST_X $DST_QS, third wait held] waiters running at the signal $DST_UP (want 1), temp dir there $DST_TB (want 1), $DST_NP pids (want 3), still there within a second $DST_GONE (want 0), exit $DST_RC (want $DST_QR), temp dir left $DST_TA (want 0);"
        kill -9 "$DST_P" 2>/dev/null
      fi
    done
    # (d) TERM at 0 to 80 ms after the start: the first wait is held (30 s), so the Overview is alive until the signal
    for DST_DL in 0 0.005 0.01 0.02 0.04 0.08; do
      DST_Y26=$((DST_Y26 + 1)); DST_TG="s26-$DST_G-$DST_X-early-$DST_DL"
      printf '%s\n' A > "$DST_D/$DST_TG.keys"
      rm -f "$DST_D/$DST_TG.calls" "$DST_D/$DST_TG.pids"; : > "$DST_D/$DST_TG.ui"; : > "$DST_D/$DST_TG.jq"; : > "$DST_D/$DST_TG.stat"; : > "$DST_D/$DST_TG.out"
      rm -rf "$DST_D/$DST_TG.tmp"; mkdir -p "$DST_D/$DST_TG.tmp"; cp "$F/many-clients.json" "$DST_D/$DST_TG.json"
      DST_PA="$DST_D/dev9:$DST_D/cnt:$PATH"; DST_HOLD=1
      {   # a shell that the signal reaches before its traps are set dies of it, and the shell running this row prints a notice for that
        dst_s18_start "$DST_XP" "$DST_C"
        DST_HOLD=
        sleep "$DST_DL"; kill -TERM "$DST_P" 2>/dev/null
        DST_W=0; while kill -0 "$DST_P" 2>/dev/null && [ "$DST_W" -lt 30 ]; do sleep 0.1; DST_W=$((DST_W + 1)); done
        DST_ENDED=1; if kill -0 "$DST_P" 2>/dev/null; then DST_ENDED=0; kill -9 "$DST_P" 2>/dev/null; fi
        wait "$DST_P"
      } 2>/dev/null
      DST_W=0; while [ "$(dst_alive "$DST_D/$DST_TG.pids")" != 0 ] && [ "$DST_W" -lt 10 ]; do sleep 0.1; DST_W=$((DST_W + 1)); done
      DST_GONE=$(dst_alive "$DST_D/$DST_TG.pids")
      if [ "$DST_GONE" != 0 ]; then while read -r DST_WP; do [ -z "$DST_WP" ] || kill "$DST_WP" 2>/dev/null; done < "$DST_D/$DST_TG.pids"; fi
      DST_TA=$(dst_ovleft "$DST_D/$DST_TG.tmp")
      if [ "$DST_ENDED/$DST_GONE/$DST_TA" != "1/0/0" ]; then
        DST_L26="$DST_L26 [$DST_X, TERM ${DST_DL} s after the start] ended by itself $DST_ENDED (want 1), waiters still there $DST_GONE (want 0), temp dir left $DST_TA (want 0);"
      fi
    done
    # (f) the shell killed with KILL, where no cleanup runs: the reader's third wait is pending. When it ends (a press: the stand-in is ended), the reader finds its
    # shell gone, opens no other wait and ends, so a reader that outlives its shell takes one more key at most and not every key from then on
    DST_Y26=$((DST_Y26 + 1)); DST_TG="s26-$DST_G-$DST_X-kill"
    printf '%s\n' A A > "$DST_D/$DST_TG.keys"
    rm -f "$DST_D/$DST_TG.calls" "$DST_D/$DST_TG.pids"; : > "$DST_D/$DST_TG.ui"; : > "$DST_D/$DST_TG.jq"; : > "$DST_D/$DST_TG.stat"; : > "$DST_D/$DST_TG.out"
    rm -rf "$DST_D/$DST_TG.tmp"; mkdir -p "$DST_D/$DST_TG.tmp"; cp "$F/many-clients.json" "$DST_D/$DST_TG.json"
    DST_PA="$DST_D/dev9:$DST_D/cnt:$PATH"; DST_HOLD=3
    dst_s18_start "$DST_XP" "$DST_C"
    DST_HOLD=
    DST_W=0
    while [ "$DST_W" -lt 200 ]; do
      if [ "$(cat "$DST_D/$DST_TG.pids" 2>/dev/null | grep -c .)" -ge 3 ] && [ "$(grep -c '^LOG A: Refresh   B: Back$' "$DST_D/$DST_TG.out")" -ge 3 ]; then break; fi
      sleep 0.05; DST_W=$((DST_W + 1))
    done
    DST_HP=$(sed -n 3p "$DST_D/$DST_TG.pids" 2>/dev/null); DST_RP=$(ps -o ppid= -p "${DST_HP:-0}" 2>/dev/null | tr -d ' ')
    kill -9 "$DST_P" 2>/dev/null; { wait "$DST_P"; } 2>/dev/null
    kill "$DST_HP" 2>/dev/null
    DST_W=0; while [ -n "$DST_RP" ] && kill -0 "$DST_RP" 2>/dev/null && [ "$DST_W" -lt 30 ]; do sleep 0.1; DST_W=$((DST_W + 1)); done
    DST_RG=1; if [ -z "$DST_RP" ] || kill -0 "$DST_RP" 2>/dev/null; then DST_RG=0; kill -9 "$DST_RP" 2>/dev/null; fi
    sleep 0.3; DST_NP=$(grep -c . "$DST_D/$DST_TG.pids"); DST_AL=$(dst_alive "$DST_D/$DST_TG.pids")
    if [ "$DST_RG" = 1 ] && [ "$DST_AL" != 0 ]; then while read -r DST_WP; do [ -z "$DST_WP" ] || kill "$DST_WP" 2>/dev/null; done < "$DST_D/$DST_TG.pids"; fi
    rm -rf "$DST_D/$DST_TG.tmp"
    if [ "$DST_RG/$DST_NP/$DST_AL" != "1/3/0" ]; then
      DST_L26="$DST_L26 [$DST_X, shell killed with KILL, third wait ended] the reader ended by itself $DST_RG (want 1), $DST_NP waits in all (want 3), still there $DST_AL (want 0);"
    fi
    if [ -z "$DST_L26" ]; then DST_S26=$((DST_S26 + 1)); else echo "    reader, $DST_G copy under $DST_X:$DST_L26"; fi
  done
done
if [ "$DST_S26" = "$DST_X26" ]; then row "display reader: no waiter left by the key reader after A Up B, the payload gone at the second key, TERM and HUP with the third wait held, TERM 0 to 80 ms after the start; ov_cleanup holds no \$! ($DST_X26 copy and shell combinations, $DST_Y26 signal runs, $DST_SHELLS$DST_HUPNOTE26)" PASS
else row "display reader: $DST_S26/$DST_X26 copy and shell combinations as expected" FAIL; DST_KEEP=1; fi

# ---- S27 probe: the health probe of the first draw is a draw like the others: it runs in the background with a watcher, and a B, Left or Right ends it at once; an A or
# an Up does not. A probe that was ended is no answer and is asked again with the next draw (jq_healthy keeps nothing of it). The jq stand-in sleeps 2 s in the probe
# (STARCHORUS_JQ_PSLEEP) and 1 s on a program, and says it has started when the probe has. Cases: (b) B in the probe: one jq (the probe, ended), no program, no screen,
# the list; (right) RIGHT in the probe: it is ended, and the top screen asks again (a second probe, then the top program: three jq in all); (a) A in the probe: the probe
# finishes and the program runs. tag|keys|screens|waits|lists|jq processes|jq ended|frames
DST_S27=0; DST_X27=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X27=$((DST_X27 + 1)); DST_L27=""
  for DST_Q in "b|@B|-|1|1|1|yes|0" "right|@RIGHT B|t|2|1|3|yes|1" "a|@A B|s|2|1|2|no|1"; do
    DST_QT=$(printf '%s' "$DST_Q" | cut -d'|' -f1); DST_QK=$(printf '%s' "$DST_Q" | cut -d'|' -f2); DST_QV=$(printf '%s' "$DST_Q" | cut -d'|' -f3)
    DST_QW=$(printf '%s' "$DST_Q" | cut -d'|' -f4); DST_QL=$(printf '%s' "$DST_Q" | cut -d'|' -f5); DST_QJ=$(printf '%s' "$DST_Q" | cut -d'|' -f6)
    DST_QD=$(printf '%s' "$DST_Q" | cut -d'|' -f7); DST_QF=$(printf '%s' "$DST_Q" | cut -d'|' -f8); [ "$DST_QV" != - ] || DST_QV=
    DST_TG="s27-$DST_G-$DST_QT"; rm -f "$DST_D/$DST_TG.st" "$DST_D/$DST_TG.st.killed"
    DST_OVPATH="$DST_D/sleepjq"
    dst_ov "$DST_TG" "$DST_C" "$DST_QK" STARCHORUS_JQ_STARTED="$DST_D/$DST_TG.st" STARCHORUS_JQ_PSLEEP=2 STARCHORUS_JQ_SLEEP=1
    DST_OVPATH=
    DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG"); DST_AJ=$(grep -c x "$DST_D/$DST_TG.jq")
    DST_AF=$(dst_cnt 'LOG A: Refresh   B: Back' "$DST_D/$DST_TG.out"); DST_AE=no; [ ! -e "$DST_D/$DST_TG.st.killed" ] || DST_AE=yes
    DST_AM=$(grep -c 'jq incomplete' "$DST_D/$DST_TG.out")
    if [ "$DST_RC/$DST_A/$DST_AW/$DST_AP/$DST_AJ/$DST_AE/$DST_AF/$DST_AM" != "0/$DST_QV/$DST_QW/$DST_QL/$DST_QJ/$DST_QD/$DST_QF/0" ]; then
      DST_L27="$DST_L27 [$DST_QT: keys $DST_QK] rc $DST_RC, screens '$DST_A' (want '$DST_QV'), $DST_AW waits (want $DST_QW), $DST_AP lists (want $DST_QL), $DST_AJ jq (want $DST_QJ), a jq ended: $DST_AE (want $DST_QD), frames $DST_AF (want $DST_QF), 'jq incomplete' lines $DST_AM (want 0);"
    fi
  done
  if [ -z "$DST_L27" ]; then DST_S27=$((DST_S27 + 1)); else echo "    probe, $DST_G copy:$DST_L27"; fi
done
if [ "$DST_S27" = "$DST_X27" ]; then row "display probe: the health probe of the first draw ends at once on a B, Left or Right and is asked again with the next draw; an A lets it finish, and an ended probe leaves no 'jq incomplete' line ($DST_X27 copies)" PASS
else row "display probe: $DST_S27/$DST_X27 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S28 deadreader: the key reader killed from outside is a named failure. KILL (the out-of-memory killer, which the script names as a real actor) runs no
# trap, so the reader's `done` mark is never written; a file system with no room left fails the same write. 0.1.1 saw it, because the shell waited for its
# waiter; the reader's end must be seen by asking for its pid too, or the Overview naps for ever with no wait open, and the next B goes to the Pager UI. The
# "reaper" driver of the row waits for the first frame, kills the parent of the open wait (the reader) with KILL and, in the first case, presses B into the wait the
# dead reader left open (the stand-in takes it and writes it where nobody reads). The Overview must end within 6 s (one still running then is a poll without end, and is ended by the row) with exit 1 and
# the dialog "Overview could not read a key.", one screen, one wait (no other is opened), no list, no waiter left (in the second case the wait is still open when
# the Overview ends: the exit ends it by the pid the reader wrote down) and no temp dir; and when the dialog is called no wait is open any more (the Overview ends the
# orphan first, or it would take the press meant for the dialog). Under sh and, when installed, dash: a child that has died stays a zombie, and
# `kill -0` finds it, until its shell collects it, which shells do at different moments. tag|key pressed after the kill
DST_S28=0; DST_X28=0
for DST_X in $DST_SHELLS; do
  DST_XP=$(command -v "$DST_X"); case $DST_XP in /*) ;; *) DST_XP=$DST_SH ;; esac
  for DST_E in $DST_COPIES; do
    DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X28=$((DST_X28 + 1)); DST_L28=""
    for DST_Q in "bkey|B" "nokey|-"; do
      DST_QT=${DST_Q%%|*}; DST_QP=${DST_Q#*|}; DST_TG="s28-$DST_G-$DST_X-$DST_QT"
      printf '%s\n' - > "$DST_D/$DST_TG.keys"
      rm -f "$DST_D/$DST_TG.calls" "$DST_D/$DST_TG.pids"; : > "$DST_D/$DST_TG.ui"; : > "$DST_D/$DST_TG.jq"; : > "$DST_D/$DST_TG.stat"; : > "$DST_D/$DST_TG.out"
      rm -rf "$DST_D/$DST_TG.tmp" "$DST_D/$DST_TG.sim"; mkdir -p "$DST_D/$DST_TG.tmp" "$DST_D/$DST_TG.sim"; cp "$F/many-clients.json" "$DST_D/$DST_TG.json"
      DST_PA="$DST_D/dev9:$DST_D/cnt:$PATH"; DST_HUPX=""
      export STARCHORUS_UISIM="$DST_D/$DST_TG.sim"
      dst_s18_start "$DST_XP" "$DST_C"
      unset STARCHORUS_UISIM
      "$DST_D/reaper" "$DST_D/$DST_TG.sim" "$DST_D/$DST_TG.out" "$DST_QP" & DST_PR=$!
      DST_W=0; while kill -0 "$DST_P" 2>/dev/null && [ "$DST_W" -lt 60 ]; do sleep 0.1; DST_W=$((DST_W + 1)); done   # 6 s
      DST_ENDED=1; if kill -0 "$DST_P" 2>/dev/null; then DST_ENDED=0; kill "$DST_P" 2>/dev/null; sleep 0.5; kill -9 "$DST_P" 2>/dev/null; fi
      { wait "$DST_P"; DST_RC=$?; } 2>/dev/null
      { kill "$DST_PR"; wait "$DST_PR"; } 2>/dev/null
      DST_W=0; while [ "$(dst_alive "$DST_D/$DST_TG.pids")" != 0 ] && [ "$DST_W" -lt 20 ]; do sleep 0.1; DST_W=$((DST_W + 1)); done
      DST_A=$(dst_views "$DST_D/$DST_TG.out"); DST_AW=$(dst_ui WAIT "$DST_TG"); DST_AP=$(dst_ui PICKER "$DST_TG")
      DST_AE=$(dst_cnt 'ERROR Overview could not read a key.' "$DST_D/$DST_TG.ui"); DST_AO=$(dst_cnt 'ERROR-WAIT-OPEN' "$DST_D/$DST_TG.ui")
      DST_AL=$(dst_alive "$DST_D/$DST_TG.pids"); DST_AT=$(dst_ovleft "$DST_D/$DST_TG.tmp")
      DST_AK=0; [ ! -s "$DST_D/$DST_TG.sim/reader" ] || DST_AK=1   # the reaper found a reader and killed it
      if [ "$DST_AL" != 0 ]; then while read -r DST_WP; do [ -z "$DST_WP" ] || kill "$DST_WP" 2>/dev/null; done < "$DST_D/$DST_TG.pids"; fi
      if [ "$DST_AK/$DST_ENDED/$DST_RC/$DST_A/$DST_AW/$DST_AP/$DST_AE/$DST_AO/$DST_AL/$DST_AT" != "1/1/1/s/1/0/1/0/0/0" ]; then
        DST_L28="$DST_L28 [$DST_X, $DST_QT: key after the kill '$DST_QP'] reader killed $DST_AK (want 1), ended within 6 s $DST_ENDED (want 1: 0 is a poll without end), exit $DST_RC (want 1), screens '$DST_A' (want s), $DST_AW waits (want 1), $DST_AP lists (want 0), dialog $DST_AE (want 1), a wait still open when the dialog came $DST_AO (want 0), waiters still there $DST_AL (want 0), temp dirs left $DST_AT (want 0);"
      fi
    done
    if [ -z "$DST_L28" ]; then DST_S28=$((DST_S28 + 1)); else echo "    deadreader, $DST_G copy:$DST_L28"; fi
  done
done
if [ "$DST_S28" = "$DST_X28" ]; then row "display deadreader: a key reader killed from outside (no trap, no done mark) is a named failure within 6 s: 'could not read a key', exit 1, no other wait, no wait left open when the dialog shows, no waiter and no temp dir left, with or without a B pressed after ($DST_X28 copy and shell combinations, $DST_SHELLS)" PASS
else row "display deadreader: $DST_S28/$DST_X28 copy and shell combinations as expected" FAIL; DST_KEEP=1; fi

# ---- S29 slowterm: TERM to the Overview while a wait is open that is slow to end (0.3 s after the TERM, as a UI command that has to unregister first may be). The
# cleanup sends TERM to the reader and removes the temp dir; the reader's last act is to write its `done` mark into that dir, 0.3 s later, and a write that lands while the
# directory is being removed (after its files are unlinked, before the directory itself goes) leaves a starchorus-ov.* directory behind with that one file. The real rm
# does the unlinking and the rmdir in a moment, so a stand-in rm pauses 0.6 s between the two and makes the window big enough to be hit every time. The cleanup must
# therefore wait for the reader (bounded, about 2 s) before it removes the directory. Under sh and, when installed, dash. The wait must be open and the dir there at the
# signal; the Overview must end within 8 s with exit 143; no waiter and, 0.5 s later too, no starchorus-ov.* directory is left.
DST_S29=0; DST_N29=0; DST_X29=0
for DST_X in $DST_SHELLS; do
  DST_XP=$(command -v "$DST_X"); case $DST_XP in /*) ;; *) DST_XP=$DST_SH ;; esac
  DST_HUPX=""
  for DST_E in $DST_COPIES; do
    DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_L29=""; DST_N29=$((DST_N29 + 1)); DST_X29=$((DST_X29 + 1)); DST_TG="s29-$DST_G-$DST_X"
    printf '%s\n' A > "$DST_D/$DST_TG.keys"
    rm -f "$DST_D/$DST_TG.calls" "$DST_D/$DST_TG.pids"; : > "$DST_D/$DST_TG.ui"; : > "$DST_D/$DST_TG.jq"; : > "$DST_D/$DST_TG.stat"; : > "$DST_D/$DST_TG.out"
    rm -rf "$DST_D/$DST_TG.tmp"; mkdir -p "$DST_D/$DST_TG.tmp"; cp "$F/many-clients.json" "$DST_D/$DST_TG.json"
    DST_PA="$DST_D/slowrm:$DST_D/dev9:$DST_D/cnt:$PATH"
    export STARCHORUS_SLOWTERM_AT=1 STARCHORUS_SLOWTERM=0.3 STARCHORUS_RM_PAUSE=0.6 STARCHORUS_REAL_PATH="$PATH"
    dst_s18_start "$DST_XP" "$DST_C"
    unset STARCHORUS_SLOWTERM_AT STARCHORUS_SLOWTERM STARCHORUS_RM_PAUSE STARCHORUS_REAL_PATH
    DST_W=0
    while [ "$DST_W" -lt 200 ]; do   # the reader's wait is open and the screen is drawn
      if [ -s "$DST_D/$DST_TG.pids" ] && grep -qxF 'LOG A: Refresh   B: Back' "$DST_D/$DST_TG.out"; then break; fi
      sleep 0.05; DST_W=$((DST_W + 1))
    done
    DST_UP=$(dst_alive "$DST_D/$DST_TG.pids"); DST_TB=$(dst_ovleft "$DST_D/$DST_TG.tmp")
    kill -TERM "$DST_P" 2>/dev/null
    DST_W=0; while kill -0 "$DST_P" 2>/dev/null && [ "$DST_W" -lt 80 ]; do sleep 0.1; DST_W=$((DST_W + 1)); done
    DST_ENDED=1; if kill -0 "$DST_P" 2>/dev/null; then DST_ENDED=0; kill -9 "$DST_P" 2>/dev/null; fi
    { wait "$DST_P"; DST_RC=$?; } 2>/dev/null
    DST_TA=$(dst_ovleft "$DST_D/$DST_TG.tmp"); sleep 0.5; DST_TA=$((DST_TA + $(dst_ovleft "$DST_D/$DST_TG.tmp")))
    DST_AL=$(dst_alive "$DST_D/$DST_TG.pids"); DST_NP=$(grep -c . "$DST_D/$DST_TG.pids")
    if [ "$DST_AL" != 0 ]; then while read -r DST_WP; do [ -z "$DST_WP" ] || kill "$DST_WP" 2>/dev/null; done < "$DST_D/$DST_TG.pids"; fi
    if [ "$DST_UP/$DST_TB/$DST_ENDED/$DST_RC/$DST_NP/$DST_AL/$DST_TA" != "1/1/1/143/1/0/0" ]; then
      DST_L29="$DST_L29 [$DST_X TERM, a wait that takes 0.3 s to end] waiter open at the signal $DST_UP (want 1), temp dir there $DST_TB (want 1), ended within 8 s $DST_ENDED (want 1), exit $DST_RC (want 143), $DST_NP waits (want 1), waiters still there $DST_AL (want 0), temp dirs left (twice counted) $DST_TA (want 0);"
    fi
    if [ -z "$DST_L29" ]; then DST_S29=$((DST_S29 + 1)); else echo "    slowterm, $DST_G copy:$DST_L29"; fi
  done
done
if [ "$DST_S29" = "$DST_N29" ]; then row "display slowterm: TERM while a slow-to-end wait is open leaves no starchorus-ov.* directory, though the reader writes its mark 0.3 s later and the directory takes 0.6 s to remove: the cleanup waits for the reader first ($DST_X29 copy and shell combinations, $DST_SHELLS)" PASS
else row "display slowterm: $DST_S29/$DST_N29 copy and shell combinations as expected" FAIL; DST_KEEP=1; fi

# ---- S30 readerpin: text pins on both copies, each with a detector self-check (a planted function is judged, a planted comment is not). (a) The reader replaces the two
# files that the shell reads in one shot and the reader rewrites, OV_CNT (the counts) and OV_WPF (the pid of the open wait, read by the cleanup), by writing a finished
# sibling and renaming it onto them (`mv -f`): a write straight into either is a truncation first, and a read that falls between the truncation and the write finds an
# empty file (ov_counts then fails, a watcher is not told to end a jq, a draw keeps an old count). (b) The reader's EXIT trap writes its `done` mark only where the
# directory still is. (c) ov_cleanup asks for the end of the reader (kill -0 on OV_RPID) before the line that removes the directory. (d) ov_await asks the same about
# the reader when no key is queued (the S28 behaviour, by its text).
dst_pin() { dst_code | dst_fn "$1" | grep -cE "$2"; }   # dst_pin FN ERE: the code lines of the function FN (a script on stdin) that match ERE
dst_first() { dst_code | dst_fn "$1" | DST_FA="$2" DST_FB="$3" awk '$0 ~ ENVIRON["DST_FA"] && !x { x = NR } $0 ~ ENVIRON["DST_FB"] && !y { y = NR } END { print (x > 0 && y > x) ? "ok" : "no" }'; }   # dst_first FN ERE1 ERE2: ok when ERE1 first matches before ERE2 does
# shellcheck disable=SC2016   # the expressions are extended regular expressions, literal on purpose
DST_RB='printf .*> *"\$OV_(CNT|WPF)"'                       # a printf straight into either file
# shellcheck disable=SC2016
DST_RM='mv -f "\$OV_(CNT|WPF)[^"]*" "\$OV_(CNT|WPF)"'       # the rename onto it
# shellcheck disable=SC2016
DST_RMC='mv -f "\$OV_CNT[^"]*" "\$OV_CNT"'
# shellcheck disable=SC2016
DST_RMW='mv -f "\$OV_WPF[^"]*" "\$OV_WPF"'
DST_RT="trap '[^']*-d \"\\\$OV_TMP\"[^']*\"\\\$OV_RDONE\"[^']*' EXIT"
# shellcheck disable=SC2016
DST_RK='kill -0 "\$OV_RPID"'
# shellcheck disable=SC2016   # the planted lines are literal script text
DST_P1=$(printf '%s\n' 'ov_reader() {' '    printf "%s %s\n" "$rd_n" "$rd_e" > "$OV_CNT"' '}' | dst_pin ov_reader "$DST_RB")
# shellcheck disable=SC2016
DST_P2=$(printf '%s\n' 'ov_reader() {' '    printf "%s %s\n" "$rd_n" "$rd_e" > "$OV_CNT.new" && mv -f "$OV_CNT.new" "$OV_CNT"' '    # printf "x" > "$OV_WPF"' '}' | dst_pin ov_reader "$DST_RB|$DST_RM" | tr -d '\n')
# shellcheck disable=SC2016
DST_P3=$(printf '%s\n' 'ov_cleanup() {' '    rm -rf "$OV_TMP"' '    kill -0 "$OV_RPID"' '}' | dst_first ov_cleanup "$DST_RK" 'rm -rf')
# shellcheck disable=SC2016
DST_P4=$(printf '%s\n' 'ov_cleanup() {' '    # kill -0 "$OV_RPID"' '    rm -rf "$OV_TMP"' '}' | dst_first ov_cleanup "$DST_RK" 'rm -rf')
# shellcheck disable=SC2016
DST_P7=$(printf '%s\n' 'ov_cleanup() {' '    kill -0 "$OV_RPID"' '    rm -rf "$OV_TMP"' '}' | dst_first ov_cleanup "$DST_RK" 'rm -rf')
# shellcheck disable=SC2016
DST_P5=$(printf '%s\n' 'ov_reader() {' "    trap 'printf x > \"\$OV_RDONE\"' EXIT" '}' | dst_pin ov_reader "$DST_RT")
# shellcheck disable=SC2016
DST_P6=$(printf '%s\n' 'ov_reader() {' "    trap '[ ! -d \"\$OV_TMP\" ] || printf x > \"\$OV_RDONE\"' EXIT" '}' | dst_pin ov_reader "$DST_RT")
DST_S30=0; DST_X30=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X30=$((DST_X30 + 1)); DST_L30=""
  DST_N1=$(dst_pin ov_reader "$DST_RB" < "$DST_C"); DST_N2=$(dst_pin ov_reader "$DST_RMC" < "$DST_C"); DST_N3=$(dst_pin ov_reader "$DST_RMW" < "$DST_C")
  DST_N4=$(dst_pin ov_reader "$DST_RT" < "$DST_C"); DST_N5=$(dst_first ov_cleanup "$DST_RK" 'rm -rf' < "$DST_C"); DST_N6=$(dst_pin ov_await "$DST_RK" < "$DST_C")
  if [ "$DST_N6" -ge 1 ] 2>/dev/null; then DST_N6=1; fi   # one line or more
  if [ "$DST_P1/$DST_P2/$DST_P3/$DST_P4/$DST_P5/$DST_P6/$DST_P7" != "1/1/no/no/0/1/ok" ]; then
    DST_L30="$DST_L30 detectors: a bare write is found $DST_P1 (want 1), a rename is found and a commented write is not $DST_P2 (want 1), a cleanup that removes first $DST_P3 and one whose only wait is a comment $DST_P4 (want no and no), one that waits first $DST_P7 (want ok), an unguarded trap $DST_P5 and a guarded one $DST_P6 (want 0 and 1);"
  fi
  if [ "$DST_N1/$DST_N2/$DST_N3/$DST_N4/$DST_N5/$DST_N6" != "0/1/1/1/ok/1" ]; then
    DST_L30="$DST_L30 printf straight into OV_CNT or OV_WPF in ov_reader $DST_N1 (want 0), rename onto OV_CNT $DST_N2 and onto OV_WPF $DST_N3 (want 1 each), EXIT trap that writes done only where the dir is $DST_N4 (want 1), ov_cleanup asks for the reader before rm -rf: $DST_N5 (want ok), ov_await asks kill -0 on OV_RPID $DST_N6 (want at least 1);"
  fi
  if [ -z "$DST_L30" ]; then DST_S30=$((DST_S30 + 1)); else echo "    readerpin, $DST_G copy:$DST_L30"; fi
done
if [ "$DST_S30" = "$DST_X30" ]; then row "display readerpin: the reader renames a finished file onto its count and its wait's pid and never truncates them in place; its EXIT trap writes done only where the directory is; ov_cleanup asks for the reader before it removes the directory; ov_await asks for the reader too ($DST_X30 copies)" PASS
else row "display readerpin: $DST_S30/$DST_X30 copies as expected" FAIL; DST_KEEP=1; fi

# ---- S31 secondterm: a second terminating signal while the cleanup waits. TERM, INT and HUP end the Overview through `exit`, which runs ov_cleanup. The cleanup waits for the
# reader (a nap of 0.2 s at the very least, about 2 s at most), and a second signal that came in that wait ran `exit` again from inside the EXIT trap: the shell left at once,
# before the line that removes the temp dir, and a starchorus-ov.* stayed in the device's RAM with the queue, the counts and the screen lines. The cleanup now ignores TERM,
# INT and HUP for its own, bounded, time. The wait is the slow stand-in of S29 (call 1 never answers and takes 0.6 s to end on TERM), so that the cleanup is in its wait for more
# than half a second; the row sends TERM, then TERM again every 0.05 s until the Overview has ended, so that some land in the wait however late the first is acted on (the shell is
# in a nap of 0.2 s when it comes, and the trap runs after it). Under sh and, when installed, dash. The wait must be open and the dir there at the first signal, at least four more
# TERM must have been sent while the Overview was still there (else the row proves nothing), it must end within 8 s with exit 143, and no waiter and no starchorus-ov.* directory
# (0.5 s later too) may be left.
DST_S31=0; DST_N31=0; DST_X31=0
for DST_X in $DST_SHELLS; do
  DST_XP=$(command -v "$DST_X"); case $DST_XP in /*) ;; *) DST_XP=$DST_SH ;; esac
  DST_HUPX=""
  for DST_E in $DST_COPIES; do
    DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_L31=""; DST_N31=$((DST_N31 + 1)); DST_X31=$((DST_X31 + 1)); DST_TG="s31-$DST_G-$DST_X"
    printf '%s\n' A > "$DST_D/$DST_TG.keys"
    rm -f "$DST_D/$DST_TG.calls" "$DST_D/$DST_TG.pids"; : > "$DST_D/$DST_TG.ui"; : > "$DST_D/$DST_TG.jq"; : > "$DST_D/$DST_TG.stat"; : > "$DST_D/$DST_TG.out"
    rm -rf "$DST_D/$DST_TG.tmp"; mkdir -p "$DST_D/$DST_TG.tmp"; cp "$F/many-clients.json" "$DST_D/$DST_TG.json"
    DST_PA="$DST_D/dev9:$DST_D/cnt:$PATH"
    export STARCHORUS_SLOWTERM_AT=1 STARCHORUS_SLOWTERM=0.6
    dst_s18_start "$DST_XP" "$DST_C"
    unset STARCHORUS_SLOWTERM_AT STARCHORUS_SLOWTERM
    DST_W=0
    while [ "$DST_W" -lt 200 ]; do   # the reader's wait is open and the screen is drawn
      if [ -s "$DST_D/$DST_TG.pids" ] && grep -qxF 'LOG A: Refresh   B: Back' "$DST_D/$DST_TG.out"; then break; fi
      sleep 0.05; DST_W=$((DST_W + 1))
    done
    DST_UP=$(dst_alive "$DST_D/$DST_TG.pids"); DST_TB=$(dst_ovleft "$DST_D/$DST_TG.tmp")
    kill -TERM "$DST_P" 2>/dev/null
    DST_NS=0; DST_W=0
    while [ "$DST_W" -lt 160 ]; do   # a TERM every 0.05 s while the Overview is there
      sleep 0.05; kill -0 "$DST_P" 2>/dev/null || break
      kill -TERM "$DST_P" 2>/dev/null; DST_NS=$((DST_NS + 1)); DST_W=$((DST_W + 1))
    done
    DST_ENDED=1; if kill -0 "$DST_P" 2>/dev/null; then DST_ENDED=0; kill -9 "$DST_P" 2>/dev/null; fi
    { wait "$DST_P"; DST_RC=$?; } 2>/dev/null
    DST_TA=$(dst_ovleft "$DST_D/$DST_TG.tmp"); sleep 0.5; DST_TA=$((DST_TA + $(dst_ovleft "$DST_D/$DST_TG.tmp")))
    DST_AL=$(dst_alive "$DST_D/$DST_TG.pids"); DST_NP=$(grep -c . "$DST_D/$DST_TG.pids")
    if [ "$DST_AL" != 0 ]; then while read -r DST_WP; do [ -z "$DST_WP" ] || kill "$DST_WP" 2>/dev/null; done < "$DST_D/$DST_TG.pids"; fi
    DST_NSOK=0; if [ "$DST_NS" -ge 4 ]; then DST_NSOK=1; fi
    if [ "$DST_UP/$DST_TB/$DST_NSOK/$DST_ENDED/$DST_RC/$DST_NP/$DST_AL/$DST_TA" != "1/1/1/1/143/1/0/0" ]; then
      DST_L31="$DST_L31 [$DST_X TERM, then TERM every 0.05 s] waiter open at the first signal $DST_UP (want 1), temp dir there $DST_TB (want 1), $DST_NS more TERM sent while it was there, at least 4 $DST_NSOK (want 1), ended within 8 s $DST_ENDED (want 1), exit $DST_RC (want 143), $DST_NP waits (want 1), waiters still there $DST_AL (want 0), temp dirs left (twice counted) $DST_TA (want 0);"
    fi
    if [ -z "$DST_L31" ]; then DST_S31=$((DST_S31 + 1)); else echo "    secondterm, $DST_G copy:$DST_L31"; fi
  done
done
if [ "$DST_S31" = "$DST_N31" ]; then row "display secondterm: TERM, then TERM every 0.05 s while the cleanup waits for a reader that takes 0.6 s to end leaves no starchorus-ov.* directory and no waiter: the cleanup ignores TERM, INT and HUP for its own bounded time ($DST_X31 copy and shell combinations, $DST_SHELLS)" PASS
else row "display secondterm: $DST_S31/$DST_N31 copy and shell combinations as expected" FAIL; DST_KEEP=1; fi

# ---- S31 control: the second line of defence, proved with the window widened on purpose. Two planted copies of the root copy, run under sh as above:
# (wide) ov_cleanup's first line comes 0.1 s late (a `sleep 0.1` before its `trap ''`), which with the real traps still leaves nothing, because the trap that
# took the first TERM ignores the rest from that moment; (bare) the same copy with that ignore taken out of the three traps of ov_trap_exit, which must leave
# a waiter or a temp dir behind (the fault that was seen once under load, and that the ignore is for). A planted copy that does not differ as meant is red.
dst_s31_one() {   # dst_s31_one SHELL COPY TAG -> DST_T31, the tuple of the main case for that copy
  DST_TG=$3; DST_T31=
  printf '%s\n' A > "$DST_D/$DST_TG.keys"
  rm -f "$DST_D/$DST_TG.calls" "$DST_D/$DST_TG.pids"; : > "$DST_D/$DST_TG.ui"; : > "$DST_D/$DST_TG.jq"; : > "$DST_D/$DST_TG.stat"; : > "$DST_D/$DST_TG.out"
  rm -rf "$DST_D/$DST_TG.tmp"; mkdir -p "$DST_D/$DST_TG.tmp"; cp "$F/many-clients.json" "$DST_D/$DST_TG.json"
  DST_PA="$DST_D/dev9:$DST_D/cnt:$PATH"
  export STARCHORUS_SLOWTERM_AT=1 STARCHORUS_SLOWTERM=0.6
  dst_s18_start "$1" "$2"
  unset STARCHORUS_SLOWTERM_AT STARCHORUS_SLOWTERM
  DST_W=0
  while [ "$DST_W" -lt 200 ]; do
    if [ -s "$DST_D/$DST_TG.pids" ] && grep -qxF 'LOG A: Refresh   B: Back' "$DST_D/$DST_TG.out"; then break; fi
    sleep 0.05; DST_W=$((DST_W + 1))
  done
  DST_UP=$(dst_alive "$DST_D/$DST_TG.pids"); DST_TB=$(dst_ovleft "$DST_D/$DST_TG.tmp")
  kill -TERM "$DST_P" 2>/dev/null
  DST_NS=0; DST_W=0
  while [ "$DST_W" -lt 160 ]; do
    sleep 0.05; kill -0 "$DST_P" 2>/dev/null || break
    kill -TERM "$DST_P" 2>/dev/null; DST_NS=$((DST_NS + 1)); DST_W=$((DST_W + 1))
  done
  DST_ENDED=1; if kill -0 "$DST_P" 2>/dev/null; then DST_ENDED=0; kill -9 "$DST_P" 2>/dev/null; fi
  { wait "$DST_P"; DST_RC=$?; } 2>/dev/null
  DST_TA=$(dst_ovleft "$DST_D/$DST_TG.tmp"); sleep 0.5; DST_TA=$((DST_TA + $(dst_ovleft "$DST_D/$DST_TG.tmp")))
  DST_AL=$(dst_alive "$DST_D/$DST_TG.pids"); DST_NP=$(grep -c . "$DST_D/$DST_TG.pids")
  if [ "$DST_AL" != 0 ]; then while read -r DST_WP; do [ -z "$DST_WP" ] || kill "$DST_WP" 2>/dev/null; done < "$DST_D/$DST_TG.pids"; fi
  DST_NSOK=0; if [ "$DST_NS" -ge 4 ]; then DST_NSOK=1; fi
  DST_T31="$DST_UP/$DST_TB/$DST_NSOK/$DST_ENDED/$DST_RC/$DST_NP/$DST_AL/$DST_TA"
}
sed 's|^ov_cleanup() {$|ov_cleanup() { sleep 0.1|' starchorus-display.sh > "$DST_D/s31-wide.sh"
sed -e 's|^ov_cleanup() {$|ov_cleanup() { sleep 0.1|' -e 's|trap "" TERM INT HUP; exit 1|exit 1|g' starchorus-display.sh > "$DST_D/s31-bare.sh"
DST_T31W=; DST_T31X=; DST_X31C=0
DST_XP=$(command -v sh); case $DST_XP in /*) ;; *) DST_XP=$DST_SH ;; esac
DST_C31W=$(grep -c '^ov_cleanup() { sleep 0.1$' "$DST_D/s31-wide.sh"); DST_C31I=$(grep -o 'trap "" TERM INT HUP; exit 1' "$DST_D/s31-wide.sh" | wc -l | tr -d ' ')
DST_C31B=$(grep -o 'trap "" TERM INT HUP; exit 1' "$DST_D/s31-bare.sh" | wc -l | tr -d ' ')   # the three traps share one line, so occurrences are counted, not lines
if [ "$DST_C31W" = 1 ] && [ "$DST_C31I" = 3 ] && [ "$DST_C31B" = 0 ]; then
  dst_s31_one "$DST_XP" "$DST_D/s31-wide.sh" "s31c-wide"; DST_T31W=$DST_T31
  dst_s31_one "$DST_XP" "$DST_D/s31-bare.sh" "s31c-bare"; DST_T31X=$DST_T31
  case $DST_T31X in */*/*/*/*/*/0/0) ;; *) DST_X31C=1 ;; esac   # red for the right reason: a waiter or a temp dir left
fi
dst_s31c_ok() { [ "$DST_T31W" = "1/1/1/1/143/1/0/0" ] && [ "$DST_X31C" = 1 ]; }
rowif "display secondterm control: with ov_cleanup's first line 0.1 s late (planted copy) the traps that ignore a second signal from the first one on still leave no waiter and no temp dir [$DST_T31W, want 1/1/1/1/143/1/0/0], and the same copy without that ignore leaves some [$DST_T31X, red for that reason $DST_X31C] (planted copies differ as meant: $DST_C31W/$DST_C31I/$DST_C31B, want 1/3/0)" dst_s31c_ok
dst_s31c_ok || DST_KEEP=1

# ---- S32 cleanpin: a text pin on both copies, with a detector self-check (a planted function is judged, a planted comment is not). The first code line of ov_cleanup is
# `trap '' TERM INT HUP`, before the first signal is sent, the first nap and the removal: a signal that is only ignored from a later line can still land between the start of the
# cleanup and that line, and one that is not ignored at all (S31 sees it only for TERM) would run `exit` from inside the EXIT trap. The self-check: a planted cleanup that starts with
# the trap is found, one that signals first, one whose trap is a comment and one that ignores TERM alone are not.
dst_cl1() { dst_code | dst_fn ov_cleanup | awk 'NR > 1 && NF { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); print; exit }'; }   # the first code line of ov_cleanup, trimmed
DST_CLT="trap '' TERM INT HUP"
# shellcheck disable=SC2016   # the planted lines are literal script text
DST_Q1=$(printf '%s\n' 'ov_cleanup() {' "    $DST_CLT" '    kill "$OV_RPID"' '}' | dst_cl1)
# shellcheck disable=SC2016
DST_Q2=$(printf '%s\n' 'ov_cleanup() {' '    kill "$OV_RPID"' "    $DST_CLT" '}' | dst_cl1)
# shellcheck disable=SC2016
DST_Q3=$(printf '%s\n' 'ov_cleanup() {' "    # $DST_CLT" '    kill "$OV_RPID"' '}' | dst_cl1)
# shellcheck disable=SC2016
DST_Q4=$(printf '%s\n' 'ov_cleanup() {' "    trap '' TERM" '    kill "$OV_RPID"' '}' | dst_cl1)
DST_S32=0; DST_X32=0
for DST_E in $DST_COPIES; do
  DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X32=$((DST_X32 + 1)); DST_L32=""
  DST_Q5=$(dst_cl1 < "$DST_C")
  if [ "$DST_Q1" != "$DST_CLT" ] || [ "$DST_Q2" = "$DST_CLT" ] || [ "$DST_Q3" = "$DST_CLT" ] || [ "$DST_Q4" = "$DST_CLT" ]; then
    DST_L32="$DST_L32 detectors: a cleanup that starts with the trap is found '$DST_Q1', one that signals first '$DST_Q2', one whose trap is a comment '$DST_Q3' and one that ignores TERM alone '$DST_Q4' are not (want '$DST_CLT' for the first and anything else for the rest);"
  fi
  if [ "$DST_Q5" != "$DST_CLT" ]; then
    DST_L32="$DST_L32 the first code line of ov_cleanup is '$DST_Q5' (want '$DST_CLT');"
  fi
  if [ -z "$DST_L32" ]; then DST_S32=$((DST_S32 + 1)); else echo "    cleanpin, $DST_G copy:$DST_L32"; fi
done
if [ "$DST_S32" = "$DST_X32" ]; then row "display cleanpin: the first code line of ov_cleanup is trap '' TERM INT HUP, before any signal is sent, any nap and the removal ($DST_X32 copies)" PASS
else row "display cleanpin: $DST_S32/$DST_X32 copies as expected" FAIL; DST_KEEP=1; fi
# ---- S31 alertline (0.2): the summary's alert line, "Deauth/disassoc frames heard: N AP(s)", from alerts[] of the capture. tests/fixtures/alerts.json holds three reports: two for access
# points the capture has (9 and 4 reports) and one for an address it has not, so the line says 2 APs (the page draws a note and a ring for those two and for no other). Per copy, under the
# real and the device-like jq (which has no regex builtin): (a) the line is there once, exactly that text, directly after the open/WEP line, at most 40 columns, ASCII, and neutral (no
# 'attack', no 'flood'); (b) a document without alerts[], with an empty one, with only the unknown address, with entries of the wrong shape (a count of 0 or a text, a type that is not deauth,
# no address, an address that is no string or no address), with alerts[] that is a string or an object, shows no such line and the rest of the screen as before; the same access point
# twice, in two spellings of its address, and 21 entries of which the last names a second access point (the page cuts at 20), say 1 AP, as do junk entries around one good one; an alert
# for an access point that center.own_bssids names (this device's own transmitter, which the page leaves out of its note and its ring) is not counted: both own => no line, one own
# (in the dashed upper-case spelling) => 1 AP, and own_bssids with junk and a quiet access point in it => 2 APs, as without it; every other fixture shows no such line; (c) on the device path (a stand-in LOG that prints the colour word) the alert line is the only red line of the screen; (d) the interactive Overview, three draws
# of the summary of a fresh capture (A A B), shows it three times, red, each directly before the frame, with the two jq runs any summary needs (the probe and the program): the alert adds no
# jq run of its own, and nothing redraws by itself. NEGATIVE PROBES: the record taken out of JQ_SUMMARY or the call out of screen_summary => (a), (c), (d) red; the cut at 20 taken out of
# alertaps => 'cap' red; the test that aps[] holds the address taken out => 'unknown' red; the type test taken out => 'junk' red; every unique taken out => 'dupes' red; the
# own-transmitter test taken out => 'own' and 'own1' red (a planted copy of each script, run in (e) below: it must print the line the real one does not).
DST_AJ="$F/alerts.json"
if [ ! -s "$DST_AJ" ]; then notcov "display alert line (needs tests/fixtures/alerts.json)"
else
  DST_AL='Deauth/disassoc frames heard: 2 APs'; DST_AL1='Deauth/disassoc frames heard: 1 AP'
  dst_alv() { jq -c "$2" "$DST_AJ" > "$DST_D/alv-$1.json"; }   # dst_alv NAME PROGRAM: alerts.json changed by PROGRAM
  dst_alv noalerts 'del(.alerts)'
  dst_alv empty '.alerts = []'
  dst_alv unknown '.alerts = [.alerts[2]]'
  dst_alv junk '.alerts = [1, "x", null, [], {"type":"other","ap":"02:00:5e:a1:00:01","n":3}, {"type":"deauth","ap":"02:00:5e:a1:00:01","n":0}, {"type":"deauth","ap":"02:00:5e:a1:00:01","n":"9"}, {"type":"deauth","n":3}, {"type":"deauth","ap":5,"n":3}, {"type":"deauth","ap":"nonsense","n":3}]'
  dst_alv string '.alerts = "02:00:5e:a1:00:01"'
  dst_alv object '.alerts = {"type":"deauth","ap":"02:00:5e:a1:00:01","n":3}'
  dst_alv folded '.alerts = [{"type":"deauth","t":1,"ap":" 02-00-5E-A1-00-01 ","n":1}]'
  dst_alv dupes '.alerts = [.alerts[0], .alerts[0], {"type":"deauth","t":1,"ap":"02-00-5E-A1-00-01","n":2}]'
  # shellcheck disable=SC2016   # a jq program: its $a is jq's
  dst_alv cap '.alerts as $a | .alerts = ([range(0; 20) | $a[0]] + [$a[1]])'
  dst_alv mixed '.alerts = [1, "x", null, .alerts[1], .alerts[2]]'
  dst_alv own '.center.own_bssids = ["02:00:5e:a1:00:01", "02:00:5e:a1:00:04"]'
  dst_alv own1 '.center.own_bssids = ["02-00-5E-A1-00-01"]'
  dst_alv ownjunk '.center.own_bssids = [5, "nonsense", null, "02:00:5e:a1:00:03"]'
  DST_ALW="noalerts|-
empty|-
unknown|-
junk|-
string|-
object|-
folded|$DST_AL1
dupes|$DST_AL1
cap|$DST_AL1
mixed|$DST_AL1
own|-
own1|$DST_AL1
ownjunk|$DST_AL"   # variant|the line wanted ("-" = none)
  mkdir -p "$DST_D/alb"
  # shellcheck disable=SC2016   # the stand-in's own "$1"/"$*" are meant literally
  printf '#!/bin/sh\nc=; case "$1" in red|blue) c="[$1]"; shift;; esac; printf "LOG%%s %%s\\n" "$c" "$*"\n' > "$DST_D/alb/LOG"
  printf '#!/bin/sh\nexit 0\n' > "$DST_D/alb/LIST_PICKER"; chmod +x "$DST_D/alb/LOG" "$DST_D/alb/LIST_PICKER"
  DST_NOW28=$(date +%s); jq -c --argjson g "$DST_NOW28" '.generated = $g' "$DST_AJ" > "$DST_D/alv-live.json"
  DST_S31=0; DST_X31=0
  for DST_E in $DST_COPIES; do
    DST_G=${DST_E%%:*}; DST_C=${DST_E#*:}; DST_X31=$((DST_X31 + 1)); DST_L31=""
    for DST_N in 0 1; do
      DST_TG="s31-$DST_G-$DST_N"
      # (a) the line on alerts.json
      dst_once "$DST_TG" "$DST_C" summary "$DST_AJ" "$DST_N"; DST_O="$DST_D/$DST_TG.out"
      DST_A1=$(dst_cnt "$DST_AL" "$DST_O"); DST_A2=$(grep -ci 'deauth' "$DST_O")
      DST_A3=$(awk -v l="$DST_AL" '$0 == l { print p } { p = $0 }' "$DST_O")
      DST_A4=$(awk -v l="$DST_AL" '$0 == l && length($0) > 40' "$DST_O" | grep -c .)
      DST_A5=$(grep -xF "$DST_AL" "$DST_O" | LC_ALL=C grep -c '[^ -~]'); DST_A6=$(grep -ci 'attack\|flood' "$DST_O")
      [ "$DST_A1/$DST_A2/$DST_A3/$DST_A4/$DST_A5/$DST_A6" = "1/1/No open/WEP networks/0/0/0" ] \
        || DST_L31="$DST_L31 alerts.json: line x$DST_A1 (want 1), 'deauth' x$DST_A2 (want 1), after '$DST_A3', $DST_A4 over 40 columns, $DST_A5 non-ASCII, $DST_A6 loaded words;"
      # (b) the variants
      while IFS= read -r DST_V; do
        DST_VN=${DST_V%%|*}; DST_VW=${DST_V#*|}
        dst_once "$DST_TG-$DST_VN" "$DST_C" summary "$DST_D/alv-$DST_VN.json" "$DST_N" < /dev/null; DST_O="$DST_D/$DST_TG-$DST_VN.out"
        DST_B1=$(grep -ci 'deauth' "$DST_O"); DST_B2=$(grep -c '^APs 6 ' "$DST_O"); DST_B3=$(tail -n 1 "$DST_O"); DST_B4=$(grep -c 'jq incomplete' "$DST_O")
        if [ "$DST_VW" = - ]; then
          [ "$DST_B1/$DST_B2/$DST_B3/$DST_B4" = "0/1/No open/WEP networks/0" ] || DST_L31="$DST_L31 $DST_VN: 'deauth' x$DST_B1 (want 0), APs line x$DST_B2, last line '$DST_B3', marker x$DST_B4;"
        else
          [ "$DST_B1/$(dst_cnt "$DST_VW" "$DST_O")/$DST_B2/$DST_B3/$DST_B4" = "1/1/1/$DST_VW/0" ] || DST_L31="$DST_L31 $DST_VN: 'deauth' x$DST_B1 (want 1), wanted line x$(dst_cnt "$DST_VW" "$DST_O"), APs line x$DST_B2, last line '$DST_B3', marker x$DST_B4;"
        fi
      done <<DST_ALWEOF
$DST_ALW
DST_ALWEOF
      # (c) the device path: the alert line is the only red one
      PATH="$DST_D/alb:$DST_BIN:$PATH" STARCHORUS_NRX="$DST_N" STARCHORUS_REAL_JQ="$DST_JQ" sh "$DST_C" --once summary "$DST_AJ" > "$DST_D/$DST_TG.dev" 2>&1
      DST_C1=$(grep -c '^LOG\[red\]' "$DST_D/$DST_TG.dev"); DST_C2=$(dst_cnt "LOG[red] $DST_AL" "$DST_D/$DST_TG.dev")
      [ "$DST_C1/$DST_C2" = 1/1 ] || DST_L31="$DST_L31 device path: $DST_C1 red lines (want 1), the alert line red x$DST_C2 (want 1);"
    done
    # every other fixture shows none (real jq)
    DST_D1=0; for DST_J in "$F"/*.json; do
      [ "$DST_J" != "$DST_AJ" ] || continue
      dst_once "s31-$DST_G-all" "$DST_C" summary "$DST_J" 0
      [ "$(grep -ci 'deauth' "$DST_D/s31-$DST_G-all.out")" = 0 ] || DST_D1=$((DST_D1 + 1))
    done
    [ "$DST_D1" = 0 ] || DST_L31="$DST_L31 $DST_D1 other fixtures show an alert line;"
    # (e) the control of the own-transmitter variants: a copy of the script without that test prints the line the real one does not, for both variants, under the real jq
    DST_MO="$DST_D/s31-$DST_G-noown.sh"
    # shellcheck disable=SC2016   # a sed program: the display script's own text, not to be expanded here
    DST_MS='s/ and (\$own | index(\$a)) == null//'
    sed "$DST_MS" "$DST_C" > "$DST_MO"; DST_MD=$(diff "$DST_C" "$DST_MO" | grep -c '^<')
    dst_once "s31-$DST_G-mo0" "$DST_MO" summary "$DST_D/alv-own.json" 0 < /dev/null; dst_once "s31-$DST_G-mo1" "$DST_MO" summary "$DST_D/alv-own1.json" 0 < /dev/null
    DST_ME0=$(dst_cnt "$DST_AL" "$DST_D/s31-$DST_G-mo0.out"); DST_ME1=$(dst_cnt "$DST_AL" "$DST_D/s31-$DST_G-mo1.out")
    [ "$DST_MD/$DST_ME0/$DST_ME1" = 1/1/1 ] || DST_L31="$DST_L31 planted copy without the own-transmitter test: $DST_MD lines differ (want 1), 'own' prints the line x$DST_ME0 (want 1), 'own1' prints a line for two access points x$DST_ME1 (want 1);"
    # (d) the interactive Overview
    DST_OVSRC="$DST_D/alv-live.json"; dst_ov "s31-$DST_G-ov" "$DST_C" "A A B"; DST_OVSRC=; DST_O="$DST_D/s31-$DST_G-ov.out"
    DST_E1=$(dst_views "$DST_O"); DST_E2=$(dst_cnt "LOG[red] $DST_AL" "$DST_O"); DST_E3=$(grep -c '^LOG\[red\]' "$DST_O")
    DST_E4=$(grep -c x "$DST_D/s31-$DST_G-ov.jq"); DST_E5=$(awk -v l="LOG[red] $DST_AL" '$0 == l { f = 1; next } f { if ($0 ~ /^LOG Last scan /) n++; f = 0 } END { print n + 0 }' "$DST_O")
    [ "$DST_RC/$DST_E1/$DST_E2/$DST_E3/$DST_E4/$DST_E5" = "0/sss/3/3/2/3" ] \
      || DST_L31="$DST_L31 interactive: rc $DST_RC, screens '$DST_E1' (want sss), alert line red x$DST_E2 (want 3), red lines $DST_E3 (want 3), $DST_E4 jq (want 2), directly before the frame x$DST_E5 (want 3);"
    if [ -z "$DST_L31" ]; then DST_S31=$((DST_S31 + 1)); else echo "    alert line, $DST_G copy:$DST_L31"; fi
  done
  if [ "$DST_S31" = "$DST_X31" ]; then row "display alert line: 'Deauth/disassoc frames heard: 2 APs' after the open/WEP line (40 columns, ASCII, neutral), none without alerts[] or with junk, one AP per address (folded, cut at 20), none for the device's own transmitters (and a planted copy without that test prints it), none on the other fixtures, the only red line on the device path, three draws show it three times with 2 jq ($DST_X31 copies, each under the real and the device-like jq)" PASS
  else row "display alert line: $DST_S31/$DST_X31 copies as expected" FAIL; DST_KEEP=1; fi
fi

if [ "$DST_KEEP" = 0 ]; then rm -rf "$DST_D"; else echo "    display-selftest scratch kept for inspection: $DST_D"; fi
unset -f dst_cl1 dst_st dst_once dst_read dst_count dst_allpass dst_ov dst_ovrun dst_ovleft dst_alive dst_cnt dst_ui dst_views dst_code dst_fn dst_pin dst_first
