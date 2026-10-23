# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/payload-ui.sh -- the device payload's interface (library/user/reconnaissance/starchorus/payload.sh): the menu of
# the menu specification (STOPPED/RUNNING, Start, Stop, the Overview, Open on Phone, Settings), its process safety, the
# settings file and the CLI, run for real against stand-ins; and the Overview contract of starchorus-display.sh, run for real
# against the same stand-ins. Chrome-free, dev machine only.
# GUARDS AGAINST: a settings file that is sourced (a line runs a command) or that reaches a key outside the list; the environment
#                 losing against the file; a pidfile whose pid was reused (after a reboot) read as RUNNING, or signalled by a stop;
#                 a Stop that waits out the collector's sleep, or ends before the loop is really gone; a Start that asks, that
#                 leaves a failed collector looking started, or that hands the Overview an older capture; a queued key press
#                 after a spinner or the Overview that starts or stops again; a locked (environment) row that writes; Reset
#                 without its question; a Settings change applied with a question, or one flipped back applied at all; a page
#                 started on a port that is taken; a UI command called off the device (it would block); a stop that sweeps
#                 more than our port; the collector's opt-in transmitting source reachable from the payload; a page server on
#                 every interface without bind=all; a self-contained payload directory that does not install itself, or that
#                 overwrites an installed collector; an Overview with its own Start/Stop menu, a "bye", the word dashboard, or a
#                 first line that waits for jq; a payload updated on its own that goes unnoticed at the same version (the
#                 "# Contract:" number); a restart that finds its own old listener still on the port; a debounce that never lets
#                 go of a picker that fails at once; a QR code answered by a second screen after B; an argument order read from a
#                 name that holds both roles; a niceness row that goes red only because the runner is niced (macOS); a Start that
#                 opens the Overview before the first capture of that Start exists (it would show "Waiting for the first scan."
#                 and never refresh), or one that waits for a capture it will not show (no Overview, no jq), for an earlier run's
#                 file, or on after the collector has gone; a spinner left up when the payload is killed; a TERM trap that holds
#                 the signal back while the Overview runs; an Overview with a `timeout` in front of a UI command, keys that mean
#                 something else on another screen, Up/Down read as strikes, a press that is lost, or a screen that does not say
#                 how old its numbers are; an Overview that draws while no key wait is open (a press made then is lost, not buffered:
#                 measured on the device, 16 October 2026), that throws away a press made during `Reading...` or goes on drawing (and
#                 reading with jq) after one has come, so that a second press finds no wait open for the rest of the draw; one that
#                 leaves its waiter or its temp directory behind when it ends; an Overview that holds the payload's stdout open while it waits
#                 for a key (a killed payload would then hang the payload runner for as long as nobody presses one); three instant
#                 empty answers that do not end it; a route-A page server (uhttpd, python3) given the whole of STARCHORUS_DIR, which holds
#                 settings.conf, the pid files, the logs, homing.target and, when /tmp has no room, cap/recon_copy.db (a copy of the recon
#                 database, every address and name in it), instead of $STARCHORUS_DIR/www with its two links and nothing else; a www that
#                 is not ours (a file, a symbolic link, another entry, a link to a directory) used all the same, or written through; a link
#                 that does not follow the capture the collector renames into place; a server of the build before (given the whole directory,
#                 a uhttpd outlives a payload update) that a Start or a Stop leaves running; a docroot read by a prefix match, which
#                 passes the whole directory as well.
# NEGATIVE PROBE: pl_own reduced to `kill -0` => "pid reuse" red; pl_kill_sleeps emptied => "Stop is quick" red; the marker write
#                 removed from pl_start => "Start" red (since=); PL_ARMED never set => "debounce" red; the locked case removed
#                 from pl_settings => "locked" red; pl_apply without its comparison => "apply" red (flip-back spinner); pl_port_busy
#                 returning 1 => "web page toggles" red; the `exec` put back in front of the Overview => "Start" red (no L4);
#                 pl_skew comparing the version only => "launch" red; role() without its both-roles rule => "Open on Phone" red;
#                 pl_port_gone emptied => "web page" red (kept, again); the cap on the ignored answers removed => "debounce" red
#                 (capped); ui_qr without its clock test => "Open on Phone" red (dismissed); pl_wait_capture not called => "firstcap"
#                 red (the Overview opens on cap=no); its `! -ot` test reduced to `-s` => "capwait" red (an earlier run's file ends
#                 the wait at once); its pl_col_up test removed => "capgonefast" red (the whole cap is waited out); the call made
#                 without the DASHBOARD and pl_ov_ok test => "nowaitfast" red; the spinner traps removed from ui_spin_start =>
#                 "spintrap" red (no STOP_SPINNER);
#                 the traps left in place when the spinner stops (ui_spin_stop without its `trap -`), or a TERM trap set before the
#                 Overview runs => "ovterm" red (the payload outlives the TERM while the Overview runs); the `>/dev/null 2>&1` taken
#                 off the Overview's command line in pl_overview => "ovpipe" red (the payload's stdout stays open after the TERM);
#                 the strike rule removed from the display => "strikesq" red (the three instant empty answers wait for the next key);
#                 the arm put behind the draw => "armed" red (no wait open while jq runs); the gate taken out of log() or the watcher
#                 out of ov_jq => "armed" red (the draw goes on after the key, the jq is not ended); the settle rule put back =>
#                 "nosettlecode" red; the arm made before the exit test => "nopending:strikes" red (a fourth
#                 waiter is left pending); the EXIT trap without its kill of the waiter, or one that kills only the subshell that holds
#                 it (the stand-in is that subshell's child) => "nopending:term" red; a TERM that no trap turns into an exit =>
#                 "nopending:term:dash" red (bash runs an EXIT trap for a signal, dash does not); the temp directory not removed =>
#                 "tmpdir" red.
# Served directory (section 28). NEGATIVE PROBES: the -h of the uhttpd line put back to "$STARCHORUS_DIR" => served-root red (notwhole, exact), the
#                 same in pl_serve for --directory => the python3 row red; pl_web_prepare without its test of a symbolic link => served-foreign red
#                 (symlink:kept: a link made behind www); without its test of a foreign entry => served-foreign red (regular, extra, dotfile); its
#                 test of a link to a directory taken out => dirlink red; the fall to the nc mini-server removed => nc:ran red; pl_pids reduced to
#                 the www form => served-old red (the old server is left); the rows read the docroot with the match anchored at the end of the line,
#                 so a server given "$PUI_D/www/x" or the whole directory is not counted as ours.
# The Traffic and Bluetooth rows (radio pair): sections 5, 15, 16 and 18 carry the two new rows in every list of the Settings (and the
#                 CLI keys), section 15b flips, locks and applies them, section 21 walks the eight screens of the Overview. NEGATIVE PROBES: the 'Traffic' row left out of pl_settings
#                 => the Settings rows, 15b and the web-page row red (rows, locked, staysoff ...), nothing else; pl_applykeys without 'traffic bluetooth' =>
#                 only 15b red (a:restarted, a:value, a:spin, b:flipback: leaving Settings restarts nothing); RIGHT from Stations going to Air in the
#                 Overview => the Overview row red (list, views, keys, reading, walk, walkcursor, btblock ...).
# The Alerts row (section 15c; GUARDS AGAINST an install without its question, one that is not the README's three steps or leaves a half script in
#                 the firmware's alert tree, a remove that takes more than our payload.sh and our empty directory, a second path under the alert tree,
#                 a row that locks for the wrong value of STARCHORUS_ALERTS or says the wrong thing when it does, an install made beside a copy that the
#                 firmware's switch renamed to DISABLED.starchorus, and an argument or plain path that reaches the tree or a UI command). NEGATIVE PROBES: the
#                 question taken out of pl_alert_install => a:c2, d:none red; its chmod taken out => a:calls, f:chmod:*, i:real red (cp keeps the
#                 source's mode, so only the notes of the calls see it); the cleanup after a failed install taken out => f:cp/chmod/mv:clean, i:real red;
#                 the lock taken off the row => e:rows, e:p2 red (planted copy e3:nolock); the old lock, for any value => e2:rows red (e3:oldlock);
#                 no look for the renamed copy => k1:real red (k3:second makes the second copy); no removal of it => k2:both red (k3:left); and the five
#                 mutants of i: (a recursive remove and a glob remove of the directory and of its renamed twin, a second path).
# NOT PROVEN:     nothing on the device: the real UI commands, PROMPT_QR's argument order and exit status, the visible line width, BusyBox ash
#                 (dash, if present, as a second POSIX shell for the headless start), /proc (the stand-ins answer through `ps`, a
#                 fake uptime and a fake net/tcp); that the Pager's uhttpd follows the two links of www or lists the directory, and that its
#                 BusyBox `ln -s` makes them (the servers are stand-ins that keep their command line, `ln` is the runner's: section 28 reads
#                 what a browser could have been given, not what a server does with it). docs/device-notes.md §7 records what the device itself settled (M1 to M7, measured
#                 on 16 October 2026) and what is still open.
# Stand-ins, all under $PUI_T: one UI script linked as LIST_PICKER, NUMBER_PICKER, CONFIRMATION_DIALOG, ERROR_DIALOG, LOG, PROMPT,
# PROMPT_QR, START_SPINNER, STOP_SPINNER, WAIT_FOR_INPUT. It appends "NAME<TAB>ARG<TAB>ARG..." to $PUI_LOG; the pickers, the
# confirmation and WAIT_FOR_INPUT take the next line of $PUI_ANS: "=text" prints text and exits 0, "!n" exits n without output,
# "r:n:text" prints text AND exits n, an empty line prints nothing (exit 0); a leading "q" marks an answer that is quick on the fake
# clock (the fake uptime advances 0.2 s instead of 5 s: to the Overview that is an empty or unknown answer that came back within its
# strike limit of one second); an "x" in front (after any q) first ends the process whose pid
# is in $PUI_T/parent.pid, the payload that started the Overview, so that it has gone when the key comes; "~" blocks until it
# is killed, as a WAIT_FOR_INPUT does while nobody presses a key (the "ovpipe" row and the TERM row of "nopending" use it), "z"
# blocks for 4 s and then says B (a waiter that an Overview must not have left pending: the "nopending" rows); past the last line a
# picker exits 2 (cancel) and WAIT_FOR_INPUT says B, so no run can wait for input. WAIT_FOR_INPUT is blocking like the device's,
# one call per key, but the Overview's key reader runs it as a background child that writes into its own file and calls it again the
# moment it has an answer (a press made while no wait is open is lost: measured on the device, 16 October 2026), so its call may land
# before or among the LOG lines of the draw it follows: the rows count the waits (pui_x, pui_used) and never read a wait's place in
# the log. A B, Left or Right ends the draw that is running and an A, Up or Down does not, so WHEN a stand-in answers decides what a
# row sees. A plain answer is a press made after the screen is complete, as a person's is: the stand-in waits until the frame of the
# draw that the call before led to is out (`A: Refresh   B: Back`, counted in the log against the count when the call before ended),
# when there is one: the first call, after A, a, LEFT or RIGHT, after a row was picked from the list, and after an early answer, whose
# draw goes on or is cut for the next screen. After a plain Up, Down, an unknown word or an empty answer there is no draw and the
# stand-in does not wait. A leading "i" is a press made at once, wherever the draw is; a leading "j" a press made at `Reading...`:
# the stand-in waits until the jq stand-in under $PUI_T/jqs has started the program run ($PUI_T/jq.started exists) and answers
# then. A B, Left or Right ends the draw it comes in, an A, Up or Down does not (rows that use "j" make the draw long, so that the
# answer lands inside it every time). Every call writes its log line with one write, and a
# WAIT_FOR_INPUT notes its pid in $PUI_T/wait.pids, so that a row can see whether a waiter outlived the Overview. A jq under
# $PUI_T/jqs takes two seconds before it reads a capture file: it says it has started (jq.started, and a line in jq.starts), is
# ended at once by a TERM (jq.killed) and otherwise notes how many WAIT_FOR_INPUT calls had been logged by the time it woke and
# the mode of the directories in $TMPDIR. STOP_SPINNER
# also notes whether this Start's capture existed at that moment ($PUI_T/spin.cap: yes|no, one line per call). PROMPT_QR exits 1
# at once when $PUI_T/qr.fail exists, and exits 3 after a person's time (5 s) when qr.b exists. The stand-in `timeout` notes
# its duration and the command word in $PUI_T/timeout.log, so a row can see what was put under it.
# STARCHORUS_PROC is $PUI_T/proc (an uptime file, and net/tcp when a case takes a port), STARCHORUS_MARKER
# $PUI_T/started. Every run is under a 20 s limit (python3, killpg) with a clean environment and a PATH of symlinks to a few
# basic tools: no uhttpd, no python3, no nc, so no server starts unless a case puts the stand-in uhttpd on the PATH (the runs that start one
# have $PUI_T/lnb, the directory of ln, as well: the page directory is made of links; section 28 takes it away once). setsid and
# timeout are stand-ins (exec), ip prints $PUI_T/ip.out, ps is BusyBox `ps w` over the processes under $PUI_T only (pid first;
# `-o` queries go to the real ps). The stand-in collector keeps the real one's protocol: starchorus-loop.pid, "loop RUNNING
# (pid N)" on stderr, a --stop that signals the pidfile's pid only while it runs a collector, a TERM trap and a foreground
# sleep of STARCHORUS_INTERVAL per cycle (col.fail: exits at once; col.deaf: ignores TERM). It writes {"generated":<now>} to
# starchorus.json when the loop starts, as a first cycle would (col.nojson: never; col.late N: N seconds after it started; col.short
# N: it dies after N seconds, leaving its pidfile, like a crash). The stand-in Overview records what it was handed, whether this
# Start's capture existed when it opened (cap=yes|no) and its niceness, then returns, as after B (display.hold: it stays up, like
# an Overview left open). Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only PUI_* globals and pui_*
# functions are set.

PUI_T=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-pui.XXXXXX") || PUI_T=""
# Collapse doubled slashes (a TMPDIR ending in '/' yields '.../T//starchorus-pui.X'); `ps` reports the resolved
# single-slash path, so the leak sweep at the end and the ps stand-in must match that form.
[ -z "$PUI_T" ] || PUI_T=$(printf %s "$PUI_T" | tr -s /)
if [ -z "$PUI_T" ] || [ ! -d "$PUI_T" ]; then
  row "payload ui: no temp directory" FAIL
else
PUI_PL="$R/library/user/reconnaissance/starchorus/payload.sh"
PUI_DS="$R/starchorus-display.sh"
PUI_D="$PUI_T/d"; PUI_LOG="$PUI_T/log"; PUI_ANS="$PUI_T/ans"; PUI_ALL="$PUI_T/all.log"
PUI_TAB=$(printf '\t')
PUI_VER=$(sed -n 's/^# Version:[[:space:]]*\([0-9][0-9A-Za-z.-]*\).*/\1/p' "$PUI_PL" | head -n 1)
pui_hc() { sed -n 's/^# Contract:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$R/$1" | head -n 1; }   # pui_hc FILE -> its "# Contract:" number
PUI_CON=$(sed -n 's/^# Contract:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$PUI_PL" | head -n 1)
mkdir -p "$PUI_T/sys" "$PUI_T/bin" "$PUI_T/ui" "$PUI_T/srv" "$PUI_T/decoy" "$PUI_T/tpl" "$PUI_T/jq" "$PUI_T/lnb" "$PUI_T/proc" "$PUI_T/qrm" "$PUI_T/qru" "$PUI_T/qra" "$PUI_T/qrb" "$PUI_T/uino" "$PUI_T/ovx" "$PUI_T/jqs" "$PUI_T/tmp"
for pui_t in sh dash cat grep awk mv rm sleep sed wc tr env sort dirname basename touch mkdir head cp chmod date cut nice; do
  pui_p=$(command -v "$pui_t" 2>/dev/null) && case $pui_p in /*) ln -s "$pui_p" "$PUI_T/sys/$pui_t" ;; esac
done
pui_p=$(command -v jq 2>/dev/null) && case $pui_p in /*) ln -s "$pui_p" "$PUI_T/jq/jq" ;; esac
# ln has a directory of its own: the runs that start a page server have it (the payload makes the two links of its page directory with it),
# and section 28 takes it away once (PUI_PGN)
pui_p=$(command -v ln 2>/dev/null) && case $pui_p in /*) ln -s "$pui_p" "$PUI_T/lnb/ln" ;; esac
# what the Overview adds to the basic tools: the fingerprint of the capture (stat where it takes -c, else ls) that its cache
# is keyed on; without either, nothing would ever be cached and every redraw would run jq again
for pui_t in stat ls mktemp tail rmdir; do
  pui_p=$(command -v "$pui_t" 2>/dev/null) && case $pui_p in /*) ln -s "$pui_p" "$PUI_T/ovx/$pui_t" ;; esac
done
PUI_PS=$(command -v ps)
# What `nice -n 19` gives in the runner's own shell: 19 on Linux, but base + 19 up to 20 on macOS, where a job started with `&`
# (or `nice`) is already niced. The rows compare the collector's and the Overview's niceness with this, not with a fixed 19.
# shellcheck disable=SC2016   # the script text of sh -c, expanded when it runs
PUI_NICE=$(nice -n 19 sh -c '"$0" -o nice= -p $$' "$PUI_PS" 2>/dev/null | tr -d ' ')
case $PUI_NICE in ''|*[!0-9]*) PUI_NICE=19 ;; esac
printf '#!/bin/sh\n# stand-in setsid\nexec "$@"\n' > "$PUI_T/bin/setsid"
cat > "$PUI_T/bin/timeout" <<'PUI_TMO'
#!/bin/sh
# stand-in timeout: nothing is bounded here (the UI stand-ins answer at once); the duration and the command word are noted
[ -z "${PUI_T:-}" ] || printf '%s\t%s\n' "$1" "$2" >> "$PUI_T/timeout.log"
shift
exec "$@"
PUI_TMO
printf '#!/bin/sh\n# stand-in ip: ip -4 -o addr prints the prepared file\ncat "%s/ip.out"\n' "$PUI_T" > "$PUI_T/bin/ip"
PUI_IPBR='1: lo    inet 127.0.0.1/8 scope host lo\       valid_lft forever preferred_lft forever
5: br-lan    inet 172.16.52.1/24 brd 172.16.52.255 scope global br-lan\       valid_lft forever preferred_lft forever
9: wlan0cli    inet 192.168.77.50/24 brd 192.168.77.255 scope global wlan0cli\       valid_lft forever preferred_lft forever'
printf '%s\n' "$PUI_IPBR" > "$PUI_T/ip.out"
# stand-in BusyBox `ps w`: only the processes under our own temp dir (pid first), so the payload's real sweep can only ever
# reach our stand-ins and decoys, never a developer's own server or a parallel run in another worktree; `-o` queries (the
# parent/child lookup of Stop, a niceness, the stand-in collector's own check) go to the real ps.
cat > "$PUI_T/bin/ps" <<PUI_PSX
#!/bin/sh
# stand-in ps
case " \$* " in *" -o "*) exec "$PUI_PS" "\$@" ;; esac
"$PUI_PS" -A -ww -o pid= -o args= | grep -F "$PUI_T"
PUI_PSX
# shellcheck disable=SC2016   # script text for the stand-in, expanded when it runs
printf '#!/bin/sh\n# stand-in uhttpd: daemonizes (its argv keeps -p PORT -h DIR) and returns at once\nsh "$(dirname "$0")/uhttpd-srv" "$@" </dev/null >/dev/null 2>&1 &\nexit 0\n' > "$PUI_T/srv/uhttpd"
printf '#!/bin/sh\nwhile :; do sleep 1; done\n' > "$PUI_T/srv/uhttpd-srv"
printf '#!/bin/sh\nwhile :; do sleep 1; done\n' > "$PUI_T/decoy/uhttpd"
printf '#!/bin/sh\n# a process that is not ours (a pid reused after a reboot)\nwhile :; do sleep 1; done\n' > "$PUI_T/decoy/other"
cat > "$PUI_T/ui/pui-ui" <<'PUI_UI'
#!/bin/sh
# stand-in device UI command (one script, linked under every name)
n=$(basename "$0")
# one line, one write: the Overview's waiter runs in the background, so its call can come between the writes of a LOG call
l=$n; tb=$(printf '\t'); for a; do l=$l$tb$a; done
printf '%s\n' "$l" >> "$PUI_LOG"
tick() {   # the fake clock: advance the uptime by $1 seconds
  if [ -f "${STARCHORUS_PROC:-/nonexistent}/uptime" ]; then
    awk -v d="$1" '{ printf "%.2f %.2f\n", $1 + d, $2 }' "$STARCHORUS_PROC/uptime" > "$STARCHORUS_PROC/uptime.new" \
      && mv "$STARCHORUS_PROC/uptime.new" "$STARCHORUS_PROC/uptime"
  fi
}
case $n in
  LIST_PICKER|NUMBER_PICKER|CONFIRMATION_DIALOG|WAIT_FOR_INPUT)
    [ "$n" != WAIT_FOR_INPUT ] || echo $$ >> "$PUI_T/wait.pids"   # which process: a row looks for one that outlived the Overview
    c=$(cat "$PUI_ANS.n" 2>/dev/null || echo 0); c=$((c + 1)); echo "$c" > "$PUI_ANS.n"
    if [ "$c" -gt "$(wc -l < "$PUI_ANS" | tr -d ' ')" ]; then
      [ "$n" = WAIT_FOR_INPUT ] && { echo B; exit 0; }
      exit 2
    fi
    a=$(sed -n "${c}p" "$PUI_ANS")
    w=late
    if [ "$n" = WAIT_FOR_INPUT ]; then
      # when is the press made (see the header of this file): "i" at once, "j" when the jq stand-in has started its program, else after the
      # draw this wait was armed for. A draw is due in this pass after the first call, A, a, LEFT, RIGHT, a row picked from the list, and an
      # early answer that ended a draw; the next frame (`A: Refresh   B: Back`) is then what is waited for (12 s at most)
      case $a in i*) w=now; a=${a#i} ;; j*) w=jq; a=${a#j} ;; esac
      wn=$(cat "$PUI_ANS.w" 2>/dev/null || echo 0); wn=$((wn + 1)); echo "$wn" > "$PUI_ANS.w"
      pw=late; pk=; read -r pw pk < "$PUI_ANS.prev" 2>/dev/null || :
      fp=$(cat "$PUI_ANS.fc" 2>/dev/null || echo 0); due=0
      if [ "$wn" -le 1 ] || [ -e "$PUI_ANS.picked" ]; then due=1
      else case $pk in A|a|LEFT|RIGHT) due=1 ;; *) [ "$pw" = late ] || due=1 ;; esac; fi
      rm -f "$PUI_ANS.picked"
      case $w in
        late) if [ "$due" = 1 ]; then k=0; while [ "$(grep -c "^LOG${tb}A: Refresh   B: Back\$" "$PUI_LOG")" -le "$fp" ] && [ "$k" -lt 240 ]; do sleep 0.05; k=$((k + 1)); done; fi ;;
        jq)   k=0; while [ ! -e "$PUI_T/jq.started" ] && [ "$k" -lt 240 ]; do sleep 0.05; k=$((k + 1)); done ;;
      esac
    fi
    # the fake clock: an answer takes 5 s, a queued one ("q" in front) 0.2 s
    dt=5; case $a in q*) dt=0.2; a=${a#q} ;; esac
    tick "$dt"
    case $a in x*) a=${a#x}; kill "$(cat "$PUI_T/parent.pid")" 2>/dev/null; sleep 1 ;; esac   # the payload has gone before this key
    if [ "$n" = WAIT_FOR_INPUT ]; then   # what this call was, for the next one
      case $a in "="*) kt=${a#=} ;; *) kt= ;; esac
      printf '%s %s\n' "$w" "$kt" > "$PUI_ANS.prev"
      grep -c "^LOG${tb}A: Refresh   B: Back\$" "$PUI_LOG" > "$PUI_ANS.fc"
    fi
    case $a in z*) sleep 4; echo B; exit 0 ;; esac   # a waiter that is still pending 4 s later (and then says B into nothing)
    case $a in
      "~"*)  while :; do sleep 1; done ;;
      "="*)  [ "$n" != LIST_PICKER ] || : > "$PUI_ANS.picked"; printf '%s\n' "${a#=}"; exit 0 ;;
      "!"*)  exit "${a#!}" ;;
      "r:"*) rest=${a#r:}; printf '%s\n' "${rest#*:}"; exit "${rest%%:*}" ;;
      *)     exit 0 ;;
    esac ;;
  START_SPINNER) echo 7 ;;
  STOP_SPINNER)  # was this Start's capture (not empty, not older than the marker) there when the spinner went?
    c=no; j="${STARCHORUS_DIR:-/nonexistent}/starchorus.json"
    [ -s "$j" ] && [ ! "$j" -ot "${STARCHORUS_MARKER:-/nonexistent}" ] && c=yes
    echo "$c" >> "$PUI_T/spin.cap" ;;
  PROMPT_QR) [ -e "$PUI_T/qr.fail" ] && exit 1             # fails at once
             [ -e "$PUI_T/qr.b" ] && { tick 5; exit 3; } ;;  # B after a person's time: the pickers' exit 3
esac
exit 0
PUI_UI
# a jq that takes two seconds before it reads a capture file ($PUI_T/jqs, first on the PATH of the "armed" runs): it says it has started
# (a line in jq.starts, and jq.started, which the "j" answers wait for), and a TERM ends it at once (jq.killed; the sleep is waited
# for, so the trap runs now, and one that is ended from outside ends it too: the Overview ends the children of a `timeout` first).
# A run that is left alone notes how many WAIT_FOR_INPUT calls the UI stand-in had logged by then, and the mode of every directory in
# $TMPDIR (the Overview's own); the real jq does the work
cat > "$PUI_T/jqs/jq" <<'PUI_JQS'
#!/bin/sh
for a; do
  case $a in *.json)
    echo x >> "$PUI_T/jq.starts"; : > "$PUI_T/jq.started"
    sleep 2 & sp=$!
    trap ': > "$PUI_T/jq.killed"; kill "$sp" 2>/dev/null; exit 143' TERM
    wait "$sp" || { : > "$PUI_T/jq.killed"; exit 143; }
    grep -c '^WAIT_FOR_INPUT' "$PUI_LOG" >> "$PUI_T/jq.waits"
    for d in "${TMPDIR:-/tmp}"/*/; do [ ! -d "$d" ] || ls -ld "$d" | cut -c1-10 >> "$PUI_T/jq.mode"; done
    break ;;
  esac
done
exec "$PUI_T/jq/jq" "$@"
PUI_JQS
for pui_t in LIST_PICKER NUMBER_PICKER CONFIRMATION_DIALOG ERROR_DIALOG LOG PROMPT PROMPT_QR START_SPINNER STOP_SPINNER WAIT_FOR_INPUT; do
  ln -s pui-ui "$PUI_T/ui/$pui_t"
  [ "$pui_t" = PROMPT_QR ] || ln -s ../ui/pui-ui "$PUI_T/uino/$pui_t"     # the device without PROMPT_QR
done
# four PROMPT_QR wrappers whose own text names the argument order (a usage line; the variable the first argument lands in), two of
# them naming it ambiguously (a name that holds both a message word and a QR word: no sign, so the URL alone is passed)
printf '#!/bin/sh\n# Usage: PROMPT_QR [message] [data]\nexec "%s/ui/PROMPT_QR" "$@"\n' "$PUI_T" > "$PUI_T/qrm/PROMPT_QR"
# shellcheck disable=SC2016   # script text for the stand-in, expanded when it runs
printf '#!/bin/sh\n# shows a QR code\nQR_DATA="$1"\nexec "%s/ui/PROMPT_QR" "$@"\n' "$PUI_T" > "$PUI_T/qru/PROMPT_QR"
# shellcheck disable=SC2016   # script text for the stand-in, expanded when it runs
printf '#!/bin/sh\n# shows a QR code\nQR_MESSAGE="$1"\nexec "%s/ui/PROMPT_QR" "$@"\n' "$PUI_T" > "$PUI_T/qra/PROMPT_QR"
printf '#!/bin/sh\n# Usage: PROMPT_QR <qr_text> <url>\nexec "%s/ui/PROMPT_QR" "$@"\n' "$PUI_T" > "$PUI_T/qrb/PROMPT_QR"
cat > "$PUI_T/tpl/starchorus-collect.sh" <<PUI_COL
#!/bin/sh
# stand-in collector (see the header of payload-ui.sh)
d=\$(cd "\$(dirname "\$0")" && pwd); pf="\$d/starchorus-loop.pid"
ours() { [ -n "\$1" ] && "$PUI_PS" -p "\$1" -o args= 2>/dev/null | grep -q starchorus-collect; }
wcap() { printf '{"generated":%s}\n' "\$(date +%s)" > "\$d/starchorus.json.tmp" && mv "\$d/starchorus.json.tmp" "\$d/starchorus.json"; }
case \$1 in
  --stop) p=\$(cat "\$pf" 2>/dev/null); if ours "\$p"; then kill "\$p" 2>/dev/null && echo "[starchorus] stopped collector loop pid \$p" >&2; fi
          rm -f "\$pf"; exit 0 ;;
  --status) p=\$(cat "\$pf" 2>/dev/null); if ours "\$p"; then echo "[starchorus] loop RUNNING (pid \$p)" >&2; else echo "[starchorus] loop not running" >&2; fi
            exit 0 ;;
esac
[ -e "\$d/col.fail" ] && { echo "[starchorus] no usable passive source; wrote an empty document" >&2; exit 1; }
# the first capture lands with the loop, as a first cycle would write it (col.nojson: none; col.late N: N s later, by this loop only)
[ -e "\$d/col.nojson" ] || [ -s "\$d/col.late" ] || wcap
echo \$\$ > "\$pf"
env | grep '^STARCHORUS_' | sort > "\$d/col.env.tmp" && mv "\$d/col.env.tmp" "\$d/col.env"
echo "\$\$" >> "\$d/col.starts"
echo "[starchorus] collecting every \${STARCHORUS_INTERVAL}s (loop pid \$\$)" >&2
if [ ! -e "\$d/col.nojson" ] && [ -s "\$d/col.late" ]; then
  ( sleep "\$(cat "\$d/col.late")"; [ "\$(cat "\$pf" 2>/dev/null)" = \$\$ ] && wcap ) </dev/null >/dev/null 2>&1 &
fi
if [ -s "\$d/col.short" ]; then sleep "\$(cat "\$d/col.short")"; exit 0; fi   # dies on its own, the pidfile left behind
if [ -e "\$d/col.deaf" ]; then trap '' TERM; else trap '[ "\$(cat "\$pf" 2>/dev/null)" = \$\$ ] && rm -f "\$pf"; exit 143' TERM; fi
while [ -d "\$d" ]; do sleep "\${STARCHORUS_INTERVAL:-30}"; done
PUI_COL
cat > "$PUI_T/tpl/starchorus-display.sh" <<PUI_DSP
#!/bin/sh
# stand-in Overview: records what it was handed, whether this Start's capture existed when it opened (not empty, not older than
# the marker) and its niceness, then returns (as after B); with display.hold it stays up, like an Overview left open
d=\$(dirname "\$0")
j="\$d/starchorus.json"; c=no
[ -s "\$j" ] && [ ! "\$j" -ot "\${STARCHORUS_MARKER:-/nonexistent}" ] && c=yes
{ echo "since=\${STARCHORUS_SINCE:-}"; echo "url=\${STARCHORUS_PAGE_URL:-}"; echo "parent=\${STARCHORUS_PARENT_PID:-}"; echo "cap=\$c"
  echo "nice=\$("$PUI_PS" -o nice= -p \$\$ | tr -d ' ')"; } > "\$d/display.env"
echo x >> "\$d/display.calls"
[ ! -e "\$d/display.hold" ] || while [ -d "\$d" ]; do sleep 1; done
PUI_DSP
chmod +x "$PUI_T/bin/"* "$PUI_T/ui/pui-ui" "$PUI_T/srv/"* "$PUI_T/decoy/"* "$PUI_T/tpl/"* "$PUI_T/qrm/"* "$PUI_T/qru/"* "$PUI_T/qra/"* "$PUI_T/qrb/"* "$PUI_T/jqs/"*
PUI_HL="$PUI_T/bin:$PUI_T/sys"                          # headless: no UI command
PUI_UIP="$PUI_T/ui:$PUI_T/bin:$PUI_T/jq:$PUI_T/sys"     # the device UI stand-ins first, jq present
PUI_NJQ="$PUI_T/ui:$PUI_T/bin:$PUI_T/sys"               # the same without jq
PUI_PGP="$PUI_T/srv:$PUI_T/lnb:$PUI_T/bin:$PUI_T/sys"              # headless with the stand-in uhttpd (and ln: the page directory is made of links)
PUI_PGU="$PUI_T/ui:$PUI_T/srv:$PUI_T/lnb:$PUI_T/bin:$PUI_T/jq:$PUI_T/sys"   # the device with the stand-in uhttpd
PUI_PGN="$PUI_T/srv:$PUI_T/bin:$PUI_T/sys"                          # the stand-in uhttpd and no ln (section 28: www cannot be made, so no route A)
: > "$PUI_ALL"
# the 20 s limit: its own session, killed as a group on timeout (exit 124); the payload's output lands in $PUI_T/out
PUI_TO='import os, signal, subprocess, sys
out = open(sys.argv[1], "w")
p = subprocess.Popen(sys.argv[2:], stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
try:
    sys.exit(p.wait(timeout=20))
except subprocess.TimeoutExpired:
    os.killpg(p.pid, signal.SIGKILL)
    sys.exit(124)'
PUI_ABORT=0
pui_run() {   # pui_run PATH [VAR=VALUE...] SHELL PAYLOAD [ARG...] -> PUI_RC (124 = timeout); output in $PUI_T/out, UI calls in $PUI_LOG
  pui_rp=$1; shift
  # once one run has hit the 20 s limit, later runs return 124 at once (no output), so the remaining rows fail fast
  # instead of each waiting the full 20 s -- a payload that blocks cannot make the drop-in take minutes.
  if [ "$PUI_ABORT" = 1 ]; then PUI_RC=124; : > "$PUI_T/out"; : > "$PUI_LOG"; return; fi
  python3 -c "$PUI_TO" "$PUI_T/out" env -i PATH="$pui_rp" STARCHORUS_DIR="$PUI_D" PUI_LOG="$PUI_LOG" PUI_ANS="$PUI_ANS" PUI_T="$PUI_T" \
    STARCHORUS_ALERT_TREE="$PUI_T/alerts" STARCHORUS_PROC="$PUI_T/proc" STARCHORUS_MARKER="$PUI_T/started" "$@"; PUI_RC=$?
  [ "$PUI_RC" = 124 ] && PUI_ABORT=1
  cat "$PUI_LOG" >> "$PUI_ALL" 2>/dev/null; : > "$PUI_LOG"
}
pui_kd() {    # pui_kd TEXT -> kill -9 every process whose command line holds TEXT (the stand-ins of a case)
  # shellcheck disable=SC2046
  kill -9 $("$PUI_PS" -A -ww -o pid= -o args= | awk -v t="$1" 'index($0, t) && !/awk/ { print $1 }') 2>/dev/null
}
pui_new() {   # pui_new [SETTINGS LINE...] -> a fresh payload directory with the stand-ins (no line: no settings file)
  pui_kd "$PUI_D/"; pui_kd "-h $PUI_D"; rm -rf "$PUI_D"; mkdir -p "$PUI_D"
  cp "$PUI_T/tpl/starchorus-collect.sh" "$PUI_T/tpl/starchorus-display.sh" "$PUI_D/"
  [ $# = 0 ] || printf '%s\n' "$@" > "$PUI_D/settings.conf"
  : > "$PUI_LOG"; : > "$PUI_ANS"; rm -f "$PUI_ANS.n" "$PUI_T/started" "$PUI_T/qr.fail" "$PUI_T/qr.b" "$PUI_T/proc/net/tcp" "$PUI_T/spin.cap" "$PUI_T/timeout.log"
  printf '1000.00 900.00\n' > "$PUI_T/proc/uptime"
  printf '%s\n' "$PUI_IPBR" > "$PUI_T/ip.out"
}
pui_ans() { if [ $# = 0 ]; then : > "$PUI_ANS"; else printf '%s\n' "$@" > "$PUI_ANS"; fi; rm -f "$PUI_ANS.n" "$PUI_ANS.w" "$PUI_ANS.prev" "$PUI_ANS.fc" "$PUI_ANS.picked"; }   # pui_ans ANSWER... (one per picker/confirmation/key)
pui_used() { cat "$PUI_ANS.n" 2>/dev/null || echo 0; }                # answers taken, EOF calls included
pui_cpid() { sed -n 1p "$PUI_D/starchorus-loop.pid" 2>/dev/null; }    # the collector loop's pid, from its pidfile
pui_up() { pui_c=$(pui_cpid); [ -n "$pui_c" ] && kill -0 "$pui_c" 2>/dev/null; }
pui_col() { pui_i=0; while [ ! -s "$PUI_D/col.env" ] && [ "$pui_i" -lt 8 ]; do sleep 1; pui_i=$((pui_i + 1)); done; [ -s "$PUI_D/col.env" ]; }
pui_nocol() { sleep 1; [ ! -e "$PUI_D/col.env" ]; }                   # the payload returned; a started collector would have written by now
pui_env() { sed -n "s/^$1=//p" "$PUI_D/col.env" 2>/dev/null; }       # pui_env STARCHORUS_VAR -> its value in the collector
pui_gone() { pui_i=0; while kill -0 "$1" 2>/dev/null && [ "$pui_i" -lt 6 ]; do sleep 1; pui_i=$((pui_i + 1)); done; ! kill -0 "$1" 2>/dev/null; }
pui_is() { pui_l=$1; shift; "$@" || PUI_BAD="$PUI_BAD $pui_l"; }      # pui_is LABEL TEST... -> LABEL joins PUI_BAD when TEST fails
pui_logc() { grep -c "$1" "$PUI_T/case.log"; }                        # count UI calls of the last run (copy in case.log)
pui_x() {     # pui_x NAME ARG... -> how many UI calls of the last run were exactly NAME<TAB>ARG<TAB>...
  pui_xl=$1; shift; for pui_xa; do pui_xl="$pui_xl$PUI_TAB$pui_xa"; done
  grep -cxF -- "$pui_xl" "$PUI_T/case.log"
}
pui_run_ui() { : > "$PUI_LOG"; pui_run "$@"; tail -n "+$PUI_MARK" "$PUI_ALL" > "$PUI_T/case.log"; PUI_MARK=$(($(wc -l < "$PUI_ALL") + 1)); }
PUI_MARK=1
# the same under a signal. The payload runs in its own session; this waits until FILE holds a line that starts with PATTERN (any
# line when PATTERN is empty), gives the payload a moment to get past what it just logged, sends TERM to the payload ONLY (not to
# what it started) and prints "STATUS SECONDS": the exit status (a death by the signal itself is -15, a trapped `exit 143` 143, 124
# = still there 6 s after the TERM, killed) and the seconds the payload took to end.
PUI_TM='import os, signal, subprocess, sys, time
out = open(sys.argv[1], "w")
f, pat = sys.argv[2], sys.argv[3]
p = subprocess.Popen(sys.argv[4:], stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
t = time.time()
while p.poll() is None and time.time() - t < 15:
    try:
        if any(l.startswith(pat) for l in open(f)):
            break
    except OSError:
        pass
    time.sleep(0.05)
if p.poll() is None:
    time.sleep(0.3)
    t = time.time()
    os.kill(p.pid, signal.SIGTERM)
    try:
        rc = p.wait(timeout=6)
    except subprocess.TimeoutExpired:
        p.kill(); p.wait(); rc = 124
else:
    t = time.time(); rc = p.returncode
print("%d %.1f" % (rc, time.time() - t))'
pui_term() {   # pui_term FILE PATTERN PATH [VAR=VALUE...] SHELL PAYLOAD -> PUI_TRC, PUI_TDT (see PUI_TM); the UI calls go to case.log
  pui_tf=$1; pui_tpat=$2; pui_rp=$3; shift 3
  : > "$PUI_LOG"
  PUI_TR=$(python3 -I -c "$PUI_TM" "$PUI_T/out" "$pui_tf" "$pui_tpat" env -i PATH="$pui_rp" STARCHORUS_DIR="$PUI_D" PUI_LOG="$PUI_LOG" \
    PUI_ANS="$PUI_ANS" PUI_T="$PUI_T" STARCHORUS_ALERT_TREE="$PUI_T/alerts" STARCHORUS_PROC="$PUI_T/proc" STARCHORUS_MARKER="$PUI_T/started" "$@")
  PUI_TRC=${PUI_TR% *}; PUI_TDT=${PUI_TR#* }
  cat "$PUI_LOG" >> "$PUI_ALL" 2>/dev/null; : > "$PUI_LOG"
  tail -n "+$PUI_MARK" "$PUI_ALL" > "$PUI_T/case.log"; PUI_MARK=$(($(wc -l < "$PUI_ALL") + 1))
}
# the same, for the payload's OUTPUT: stdout is a pipe, as the payload runner's is. After the TERM (to the payload only) it waits for
# EOF on that pipe, 6 s at most, and prints "STATUS SECONDS": 0 = EOF after SECONDS, 124 = the pipe was still open after 6 s (something
# the payload started holds it), 125 = the payload had ended before the TERM was sent (the case proves nothing). The whole session is
# killed at the end, so no stand-in is left behind, whatever happened.
PUI_TE='import os, select, signal, subprocess, sys, time
f, pat = sys.argv[1], sys.argv[2]
p = subprocess.Popen(sys.argv[3:], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True)
t = time.time()
seen = False
while p.poll() is None and not seen and time.time() - t < 15:
    try:
        seen = any(l.startswith(pat) for l in open(f))
    except OSError:
        pass
    if not seen:
        time.sleep(0.05)
if p.poll() is not None or not seen:
    res = "125 0.0"
else:
    time.sleep(0.3)
    os.kill(p.pid, signal.SIGTERM)
    t = time.time()
    fd = p.stdout.fileno()
    eof = False
    while time.time() - t < 6:
        if select.select([fd], [], [], 0.1)[0] and not os.read(fd, 65536):
            eof = True
            break
    res = "%d %.1f" % (0 if eof else 124, time.time() - t)
try:
    os.killpg(p.pid, signal.SIGKILL)
except OSError:
    pass
p.wait()
print(res)'
pui_eof() {   # pui_eof FILE PATTERN PATH [VAR=VALUE...] SHELL PAYLOAD -> PUI_ERC, PUI_EDT (see PUI_TE); the UI calls go to case.log
  pui_tf=$1; pui_tpat=$2; pui_rp=$3; shift 3
  : > "$PUI_LOG"
  PUI_TR=$(python3 -I -c "$PUI_TE" "$pui_tf" "$pui_tpat" env -i PATH="$pui_rp" STARCHORUS_DIR="$PUI_D" PUI_LOG="$PUI_LOG" \
    PUI_ANS="$PUI_ANS" PUI_T="$PUI_T" STARCHORUS_ALERT_TREE="$PUI_T/alerts" STARCHORUS_PROC="$PUI_T/proc" STARCHORUS_MARKER="$PUI_T/started" "$@")
  PUI_ERC=${PUI_TR% *}; PUI_EDT=${PUI_TR#* }
  cat "$PUI_LOG" >> "$PUI_ALL" 2>/dev/null; : > "$PUI_LOG"
  tail -n "+$PUI_MARK" "$PUI_ALL" > "$PUI_T/case.log"; PUI_MARK=$(($(wc -l < "$PUI_ALL") + 1))
}
pui_now() { python3 -I -c 'import time; print(int(time.time() * 10))'; }   # now, in tenths of a second
pui_get() { pui_run "$PUI_HL" sh "$PUI_PL" get "$1"; sed -n "s/^$1=\([^ ]*\) (\(.*\))$/\1 \2/p" "$PUI_T/out"; }   # -> "VALUE SOURCE"
pui_bg() {    # pui_bg FILE ARG... -> a detached process (not a child of this shell); its pid in PUI_BGP
  ( sh "$@" </dev/null >/dev/null 2>&1 & echo $! > "$PUI_T/bg.pid" ); PUI_BGP=$(cat "$PUI_T/bg.pid")
}
pui_srv() { pui_wsrv "172.16.52.1:$1" | wc -l | tr -d ' '; }   # pui_srv PORT -> our stand-in servers on PORT, given $PUI_D/www and nothing else
pui_asrv() {   # pui_asrv PORT -> our stand-in servers on PORT given $PUI_D or any directory below it (www among them): for the "none left" checks, which must count a server given the whole directory too
  "$PUI_PS" -A -ww -o args= | awk -v t="uhttpd-srv -p 172.16.52.1:$1 -h $PUI_D" 'index($0, t) && !/awk/ { r = substr($0, index($0, t) + length(t)); if (r == "" || r ~ /^\//) n++ } END { print n + 0 }'
}
pui_wsrv() {   # pui_wsrv ADDR:PORT -> the pids of our stand-in uhttpd on ADDR:PORT whose directory is exactly $PUI_D/www: the match ends the line, so $PUI_D/www/x or $PUI_D/wwwx is not it, and neither is $PUI_D alone
  "$PUI_PS" -A -ww -o pid= -o args= | awk -v t="uhttpd-srv -p $1 -h $PUI_D/www" '{ n = length($0) - length(t) + 1 } n >= 1 && substr($0, n) == t && !/awk/ { print $1 }'
}
pui_nsrv() {   # pui_nsrv -> "ALL/WWW": the stand-in uhttpd started from this directory (any -h that holds $PUI_D) / those given exactly $PUI_D/www (line-end anchored)
  "$PUI_PS" -A -ww -o args= | awk -v d="$PUI_D" -v t=" -h $PUI_D/www" '/uhttpd-srv -p / && index($0, d) && !/awk/ { a++; n = length($0) - length(t) + 1; if (n >= 1 && substr($0, n) == t) w++ } END { print a + 0 "/" w + 0 }'
}
pui_no() { for pui_f; do [ ! -e "$pui_f" ] || return 1; done; }      # pui_no FILE... -> none of them exists
pui_tcp() {   # pui_tcp PORT... -> a fake /proc/net/tcp with a listener on every address at each PORT
  mkdir -p "$PUI_T/proc/net"
  { printf '  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode\n'
    pui_ti=0; for pui_tp; do
      printf '   %d: 00000000:%04X 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 4242 1 0 100 0 0 10 0\n' "$pui_ti" "$pui_tp"
      pui_ti=$((pui_ti + 1)); done; } > "$PUI_T/proc/net/tcp"
}
PUI_RUN="LIST_PICKER${PUI_TAB}Starchorus: Running"
PUI_STOP="LIST_PICKER${PUI_TAB}Starchorus: Stopped${PUI_TAB}Start${PUI_TAB}Settings"

# ---- 1 · headless, no settings file: the defaults reach the collector, no Overview, stop leaves nothing; also under dash
PUI_BAD=""; PUI_SH="sh"; [ -e "$PUI_T/sys/dash" ] && PUI_SH="sh dash"
for pui_sh in $PUI_SH; do
  pui_new; pui_run_ui "$PUI_HL" "$pui_sh" "$PUI_PL"
  pui_is "$pui_sh:rc$PUI_RC" [ "$PUI_RC" = 0 ]
  pui_is "$pui_sh:started" pui_col
  pui_is "$pui_sh:env" [ "$(pui_env STARCHORUS_MAX_AGE)/$(pui_env STARCHORUS_INTERVAL)/$(pui_env STARCHORUS_PORT)/$(pui_env STARCHORUS_OUTDIR)" = "3600/30/8199/$PUI_D" ]
  pui_is "$pui_sh:flags" [ "$(pui_env STARCHORUS_VENDOR)/$(pui_env STARCHORUS_OWN)/$(pui_env STARCHORUS_SURVEY)" = 1/0/0 ]
  pui_is "$pui_sh:btflags" [ "$(pui_env STARCHORUS_BLUETOOTH)/$(pui_env STARCHORUS_TRAFFIC)" = 0/0 ]   # both off by default, and exported as 0
  pui_is "$pui_sh:overview" [ ! -e "$PUI_D/display.calls" ]
  pui_is "$pui_sh:nofile" [ ! -e "$PUI_D/settings.conf" ]
  pui_is "$pui_sh:marker" [ -s "$PUI_T/started" ]
  pui_is "$pui_sh:nice" [ "$("$PUI_PS" -o nice= -p "$(pui_cpid)" 2>/dev/null | tr -d ' ')" = "$PUI_NICE" ]
  PUI_CP=$(pui_cpid)
  pui_run "$PUI_HL" "$pui_sh" "$PUI_PL" stop
  pui_is "$pui_sh:stop" pui_gone "${PUI_CP:-0}"
  pui_is "$pui_sh:stoprc" [ "$PUI_RC/${PUI_CP:+pid}" = 0/pid ]
  pui_is "$pui_sh:nomarker" [ ! -e "$PUI_T/started" ]
done
pui_is nicefloor ge "$PUI_NICE" 19
rowif "payload ui: headless start = defaults 3600/30/8199/OUTDIR at nice 19, marker, no Overview; stop ($PUI_SH; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 2 · the settings file is applied; 3 · the environment beats the file
PUI_BAD=""
pui_new "window=600" "port=8300" "vendor=off"; pui_run "$PUI_HL" sh "$PUI_PL"
pui_is started pui_col
pui_is values [ "$(pui_env STARCHORUS_MAX_AGE)/$(pui_env STARCHORUS_PORT)/$(pui_env STARCHORUS_VENDOR)/$(pui_env STARCHORUS_INTERVAL)" = 600/8300/0/30 ]
rowif "payload ui: settings file applied (window 600, port 8300, vendor off; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]
PUI_BAD=""
pui_new "port=8300" "window=600"; pui_run "$PUI_HL" STARCHORUS_PORT=9001 sh "$PUI_PL"
pui_is started pui_col
pui_is port [ "$(pui_env STARCHORUS_PORT)/$(pui_env STARCHORUS_MAX_AGE)" = 9001/600 ]
pui_is src [ "$(pui_run "$PUI_HL" STARCHORUS_PORT=9001 sh "$PUI_PL" get port; cat "$PUI_T/out")" = "port=9001 (env)" ]
rowif "payload ui: environment beats file (STARCHORUS_PORT 9001 over port=8300; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 4 · a hostile file: invalid values fall back to the defaults, nothing in it runs, nothing outside the key list gets through
#           (own, collector and dashboard are environment-only switches: a file line for them is skipped like any unknown key)
PUI_BAD=""
# shellcheck disable=SC2016   # the $(...) lines are file content that must NOT run
pui_new "port=1471" "port=80" "interval=0" "window=abc" "STARCHORUS_ALLOW_ACTIVE=1" "source=iwscan" "iface=wlan9" \
  "x=\$(touch $PUI_T/canary)" "port=\$(touch $PUI_T/canary)" "window=600;touch $PUI_T/canary" "window='600'" 'port="8300"' \
  "window=0600" " port=8300" "$(printf 'interval=45\r')" "vendor=OFF" "own=on" "collector=off" "dashboard=off"
pui_run "$PUI_HL" sh "$PUI_PL"
pui_is started pui_col
pui_is values [ "$(pui_env STARCHORUS_MAX_AGE)/$(pui_env STARCHORUS_PORT)/$(pui_env STARCHORUS_INTERVAL)/$(pui_env STARCHORUS_VENDOR)/$(pui_env STARCHORUS_OWN)" = 3600/8199/45/1/0 ]
pui_is active [ "$(grep -c 'ALLOW_ACTIVE\|SOURCE\|IFACE' "$PUI_D/col.env")" = 0 ]
pui_is canary [ ! -e "$PUI_T/canary" ]
pui_is canary2 [ ! -e "$PUI_D/canary" ]
pui_run "$PUI_HL" sh "$PUI_PL" get
pui_is get [ "$(grep -c '(file)' "$PUI_T/out")/$(grep -ci 'active\|source\|own\|collector\|dashboard' "$PUI_T/out")" = 1/0 ]
rowif "payload ui: hostile file -> defaults, CRLF read, no key outside the list, no command run (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 5 · CLI: every key round-trips through set/get; refusals exit 2 and leave the file byte-identical; reset
PUI_BAD=""; pui_new
for pui_kv in window=600 interval=60 port=8300 vendor=off survey=on page=off bluetooth=on traffic=on window=0 window=86400; do
  pui_run "$PUI_HL" sh "$PUI_PL" set "${pui_kv%%=*}" "${pui_kv#*=}"
  pui_is "set:$pui_kv" [ "$PUI_RC" = 0 ]
  pui_is "get:$pui_kv" [ "$(pui_get "${pui_kv%%=*}")" = "${pui_kv#*=} file" ]
done
pui_is sparse [ "$(wc -l < "$PUI_D/settings.conf" | tr -d ' ')" = 8 ]
cp "$PUI_D/settings.conf" "$PUI_T/before.conf"
for pui_bad in "port 1471" "port 80" "port 70000" "allow_active 1" "foo 1" "source iwscan" "window abc" "window 59" "window 86401" \
  "interval 4" "interval 3601" "vendor yes" "window 0600" "STARCHORUS_ALLOW_ACTIVE 1" "port" "own on" "collector off" "dashboard off" \
  "bluetooth yes" "bluetooth 1" "bluetooth" "traffic ON" "traffic true" "bt_window 6" "recorded_names 0"; do
  # shellcheck disable=SC2086   # the key and value are split on purpose
  pui_run "$PUI_HL" sh "$PUI_PL" set $pui_bad
  pui_is "refuse:$pui_bad" [ "$PUI_RC" = 2 ]
done
pui_run "$PUI_HL" sh "$PUI_PL" get foo; pui_is "get-foo" [ "$PUI_RC" = 2 ]
pui_run "$PUI_HL" sh "$PUI_PL" frobnicate; pui_is "unknown-cmd" [ "$PUI_RC" = 2 ]
pui_is unchanged cmp -s "$PUI_T/before.conf" "$PUI_D/settings.conf"
pui_is notmp [ ! -e "$PUI_D/settings.conf.tmp" ]
pui_is nocol pui_nocol
pui_run "$PUI_HL" sh "$PUI_PL" reset
pui_is reset [ "$PUI_RC" = 0 ]
pui_is resetfile [ ! -e "$PUI_D/settings.conf" ]
pui_is default [ "$(pui_get port)/$(pui_get window)/$(pui_get vendor)/$(pui_get page)/$(pui_get bluetooth)/$(pui_get traffic)" = "8199 default/3600 default/on default/on default/off default/off default" ]
rowif "payload ui: CLI set/get/reset (bluetooth and traffic too), refusals (own/collector/dashboard, a Bluetooth value that is not on or off) exit 2, file untouched, no .tmp (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 6 · a failing grep during a set (it cannot read the old file) does not truncate settings.conf: rc 1, byte-identical
PUI_BAD=""; pui_new "port=8300" "window=600" "interval=45" "vendor=off"
cp "$PUI_D/settings.conf" "$PUI_T/before.conf"
mkdir -p "$PUI_T/fg"
printf '#!/bin/sh\necho "window=600"\nexit 2\n' > "$PUI_T/fg/grep"; chmod +x "$PUI_T/fg/grep"
pui_run "$PUI_T/fg:$PUI_HL" sh "$PUI_PL" set interval 60
pui_is rc [ "$PUI_RC" = 1 ]
pui_is identical cmp -s "$PUI_T/before.conf" "$PUI_D/settings.conf"
pui_is notmp [ ! -e "$PUI_D/settings.conf.tmp" ]
rm -rf "$PUI_T/fg"
rowif "payload ui: a failing grep leaves settings.conf byte-identical (rc 1, no .tmp; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 7 · plain start with both services off: a note, exit 1, and a collector that is already running is NOT stopped
PUI_BAD=""; pui_new "page=off"
pui_run "$PUI_HL" sh "$PUI_PL" start
pui_is started pui_col
PUI_CP=$(pui_cpid)
pui_run "$PUI_HL" STARCHORUS_COLLECTOR=0 sh "$PUI_PL" start
pui_is bothoff_rc [ "$PUI_RC" = 1 ]
pui_is bothoff_msg [ "$(grep -ci 'no service on' "$PUI_T/out")" = 1 ]
pui_is bothoff_alive kill -0 "${PUI_CP:-0}"
pui_run "$PUI_HL" sh "$PUI_PL" stop
pui_is stopped pui_gone "${PUI_CP:-0}"
rowif "payload ui: plain start with both services off notes it, exits 1, stops nothing (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 8 · environment edge cases: an empty variable counts as unset (the file value wins, source "file"); a set made
#           while a real environment override is in force still writes and says so on stderr
PUI_BAD=""; pui_new "port=8300" "window=600"
pui_run "$PUI_HL" STARCHORUS_PORT= sh "$PUI_PL" get port
pui_is emptyport [ "$(cat "$PUI_T/out")" = "port=8300 (file)" ]
pui_run "$PUI_HL" STARCHORUS_MAX_AGE= sh "$PUI_PL" get window
pui_is emptywin [ "$(cat "$PUI_T/out")" = "window=600 (file)" ]
pui_run "$PUI_HL" STARCHORUS_PORT=9001 sh "$PUI_PL" set port 8400
pui_is setrc [ "$PUI_RC" = 0 ]
pui_is note [ "$(grep -c 'set in the environment' "$PUI_T/out")" = 1 ]
pui_is saved [ "$(pui_get port)" = "8400 file" ]
rowif "payload ui: empty env var is unset; set under an env override writes and notes it (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 9 · the device gate: with the UI commands present, an argument or STARCHORUS_PAYLOAD_PLAIN=1 never calls one
PUI_BAD=""; pui_new
pui_run_ui "$PUI_UIP" sh "$PUI_PL" status
pui_is status [ "$(grep -c '^Window 1 h, every 30 s$' "$PUI_T/out")/$(wc -l < "$PUI_T/case.log" | tr -d ' ')" = 1/0 ]
for pui_c in get "set port 8300" reset; do
  # shellcheck disable=SC2086   # the command words are split on purpose
  pui_run_ui "$PUI_UIP" sh "$PUI_PL" $pui_c
  pui_is "cli:$pui_c" [ "$PUI_RC/$(wc -l < "$PUI_T/case.log" | tr -d ' ')" = 0/0 ]
done
pui_run_ui "$PUI_UIP" STARCHORUS_PAYLOAD_PLAIN=1 sh "$PUI_PL"
pui_is plain [ "$PUI_RC/$(wc -l < "$PUI_T/case.log" | tr -d ' ')" = 0/0 ]
pui_is plaincol pui_col
pui_is plainoverview [ ! -e "$PUI_D/display.calls" ]
pui_run_ui "$PUI_UIP" sh "$PUI_PL" start
pui_is start [ "$PUI_RC/$(wc -l < "$PUI_T/case.log" | tr -d ' ')" = 0/0 ]
pui_run_ui "$PUI_UIP" sh "$PUI_PL" stop
pui_is stop [ "$PUI_RC/$(wc -l < "$PUI_T/case.log" | tr -d ' ')" = 0/0 ]
rowif "payload ui: gate: arguments and STARCHORUS_PAYLOAD_PLAIN=1 call no UI command (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 10 · launch: L1 first, STOPPED with the cursor on Start, B leaves silently and starts nothing; E1 without a collector,
#            E12 with STARCHORUS_COLLECTOR=0, both exit 1 without a menu; a differing installed version is reported once
PUI_BAD=""; pui_new
pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is first [ "$(sed -n 1p "$PUI_T/case.log")" = "LOG${PUI_TAB}blue${PUI_TAB}Starchorus listens only." ]
pui_is stopped [ "$(pui_x "$PUI_STOP" Start)" = 1 ]
pui_is calls [ "$(wc -l < "$PUI_T/case.log" | tr -d ' ')" = 2 ]
pui_is nocol pui_nocol
pui_is nofile [ ! -e "$PUI_D/settings.conf" ]
pui_new; rm -f "$PUI_D/starchorus-collect.sh"
pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is e1 [ "$PUI_RC/$(pui_x ERROR_DIALOG 'Starchorus is not installed.')/$(pui_logc '^LIST_PICKER')" = 1/1/0 ]
pui_new; pui_ans "!2"; pui_run_ui "$PUI_UIP" STARCHORUS_COLLECTOR=0 sh "$PUI_PL"
pui_is e12 [ "$PUI_RC/$(pui_x ERROR_DIALOG 'Collector disabled by\nSTARCHORUS_COLLECTOR=0.')/$(pui_logc '^LIST_PICKER')" = 1/1/0 ]
pui_new; printf '# Version: 0.0.9\n' >> "$PUI_D/starchorus-collect.sh"
pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is skew [ "$(pui_x ERROR_DIALOG "Installed 0.0.9, payload $PUI_VER.\\nRun tools/install.sh.")/$(pui_x LOG red "Installed 0.0.9, payload $PUI_VER.")/$(pui_x "$PUI_STOP" Start)" = 1/1/1 ]
pui_is skewver [ -n "$PUI_VER" ]
# the same version with an older contract (an installed file whose header has no "# Contract:" line is contract 1: every build
# before the line existed): a payload updated on its own is caught at the same version too; the Overview is judged like the
# collector; a matching contract is no skew; a file with no version header is not judged
PUI_SKD="Installed files differ from\\nthe payload.\\nRun tools/install.sh."
pui_new; printf '# Version: %s\n' "$PUI_VER" >> "$PUI_D/starchorus-collect.sh"
pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is skewc [ "$(pui_x ERROR_DIALOG "$PUI_SKD")/$(pui_x LOG red 'Installed files differ from the payload.')/$(pui_x "$PUI_STOP" Start)" = 1/1/1 ]
pui_new; printf '# Version: %s\n# Contract: %s\n' "$PUI_VER" "$PUI_CON" >> "$PUI_D/starchorus-display.sh"
pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is skewmatch [ "$(pui_logc '^ERROR_DIALOG')/$(pui_logc '^LOG	red')/$(pui_x "$PUI_STOP" Start)" = 0/0/1 ]
pui_new; printf '# Version: %s\n# Contract: 1\n' "$PUI_VER" >> "$PUI_D/starchorus-display.sh"
pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is skewdisplay [ "$(pui_x ERROR_DIALOG "$PUI_SKD")" = 1 ]
pui_run "$PUI_HL" sh "$PUI_PL" status
pui_is skewcli [ "$(grep -c "installed starchorus-display.sh is $PUI_VER (contract 1), this payload is $PUI_VER (contract $PUI_CON); run tools/install.sh" "$PUI_T/out")" = 1 ]
# all three scripts carry the contract number, and the same one
pui_is contractnum [ -n "$PUI_CON" ]
pui_is contract [ "$PUI_CON/$PUI_CON/$PUI_CON" = "$(pui_hc starchorus-collect.sh)/$(pui_hc starchorus-display.sh)/$(pui_hc library/user/reconnaissance/starchorus/starchorus-display.sh)" ]
# a collector of the previous contract (what a payload of this build meets when only the payload was replaced): the dialogue, once
pui_new; printf '# Version: %s\n# Contract: %s\n' "$PUI_VER" "$((PUI_CON - 1))" >> "$PUI_D/starchorus-collect.sh"
pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is skewprev [ "$(pui_x ERROR_DIALOG "$PUI_SKD")/$(pui_x LOG red 'Installed files differ from the payload.')/$(pui_x "$PUI_STOP" Start)" = 1/1/1 ]
rowif "payload ui: launch: L1 first, STOPPED/Start, B silent; E1, E12 exit 1; version and contract skew reported once (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 11 · Start (no question): spinner, marker, the collector at nice 19, E3 without a server program, the Overview as a
#            child at nice 19 with SINCE = the marker and the payload's pid; back to RUNNING with the cursor on Overview, and
#            B there leaves with L4 while everything keeps running (with exec the payload would have ended in the Overview)
PUI_BAD=""; pui_new
pui_ans "=Start" "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is up pui_up
pui_is noquestion [ "$(pui_logc '^CONFIRMATION_DIALOG')" = 0 ]
pui_is spin [ "$(pui_x START_SPINNER Starting)/$(pui_x STOP_SPINNER 7)" = 1/1 ]
pui_is e3 [ "$(pui_x ERROR_DIALOG 'No web server found.\nThe Overview still works.')" = 1 ]
pui_is overview [ "$(wc -l < "$PUI_D/display.calls" 2>/dev/null | tr -d ' ')" = 1 ]
pui_is since [ "$(sed -n 's/^since=//p' "$PUI_D/display.env" 2>/dev/null)" = "$(cat "$PUI_T/started" 2>/dev/null)" ]
pui_is marker [ -s "$PUI_T/started" ]
pui_is parent [ -n "$(sed -n 's/^parent=\([0-9][0-9]*\)$/\1/p' "$PUI_D/display.env" 2>/dev/null)" ]
pui_is ovnice [ "$(sed -n 's/^nice=//p' "$PUI_D/display.env" 2>/dev/null)" = "$PUI_NICE" ]
pui_is colnice [ "$("$PUI_PS" -o nice= -p "$(pui_cpid)" 2>/dev/null | tr -d ' ')" = "$PUI_NICE" ]
pui_is running [ "$(pui_x "$PUI_RUN" Overview Stop Settings Overview)" = 1 ]
pui_is l4 [ "$(pui_x LOG blue 'Still running.')/$(pui_x LOG blue 'Open Starchorus to stop it.')/$(pui_logc 'Web page:')" = 1/1/0 ]
pui_is order [ "$(grep -n 'Still running' "$PUI_T/case.log" | cut -d: -f1)" -gt "$(grep -n '^LIST_PICKER	Starchorus: Running' "$PUI_T/case.log" | cut -d: -f1)" ]
PUI_CP=$(pui_cpid)
# relaunch while it runs: L1, RUNNING with the cursor on Overview; Stop is quick (the loop's sleep child is ended: the
# stand-in sleeps 30 s per cycle, so without it the trap would wait), the loop is really gone, marker gone, L3, STOPPED/Start
pui_ans "=Stop" "!2"; PUI_T0=$(date +%s); pui_run_ui "$PUI_UIP" sh "$PUI_PL"; PUI_DT=$(($(date +%s) - PUI_T0))
pui_is rc2 [ "$PUI_RC" = 0 ]
pui_is relaunch [ "$(pui_x "$PUI_RUN" Overview Stop Settings Overview)" = 1 ]
pui_is gone pui_gone "${PUI_CP:-0}"
pui_is quick [ "$PUI_DT" -le 5 ]
pui_is stopspin [ "$(pui_x START_SPINNER Stopping)" = 1 ]
pui_is l3 [ "$(pui_x LOG green 'Stopped.')" = 1 ]
pui_is marker [ ! -e "$PUI_T/started" ]
pui_is cursor [ "$(pui_x "$PUI_STOP" Start)" = 1 ]
pui_is silent [ "$(pui_logc 'Still running')" = 0 ]
# The first capture of this Start. The Overview never refreshes by itself, so Start keeps its spinner up until a capture that is
# not older than the marker exists (up to STARCHORUS_FIRST_CAP tenths of a second, 200 by default) and opens the Overview either way.
# The stand-in collector writes its capture 2 s after the loop started (col.late): the capture was there when the spinner went
# (spin.cap) and when the Overview opened (cap), with one STOP_SPINNER and one Overview.
pui_new; echo 2 > "$PUI_D/col.late"
pui_ans "=Start" "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is firstcap [ "$PUI_RC/$(sed -n 1p "$PUI_T/spin.cap" 2>/dev/null)/$(sed -n 's/^cap=//p' "$PUI_D/display.env" 2>/dev/null)/$(pui_x STOP_SPINNER 7)/$(wc -l < "$PUI_D/display.calls" 2>/dev/null | tr -d ' ')" = 0/yes/yes/1/1 ]
pui_run "$PUI_HL" sh "$PUI_PL" stop
# No capture ever (col.nojson), and an earlier run's file lies there (2000, older than the marker: it does not count): the spinner
# stays up for the cap (2 s here), then stops and the Overview opens on cap=no: exit 0, one STOP_SPINNER, no hang.
pui_new; : > "$PUI_D/col.nojson"
printf '{"generated":946684800}\n' > "$PUI_D/starchorus.json"; touch -t 200001010000 "$PUI_D/starchorus.json"
pui_ans "=Start" "!2"; PUI_CT0=$(pui_now); pui_run_ui "$PUI_UIP" STARCHORUS_FIRST_CAP=20 sh "$PUI_PL"; PUI_CDT=$(($(pui_now) - PUI_CT0))
pui_is capcap [ "$PUI_RC/$(sed -n 1p "$PUI_T/spin.cap" 2>/dev/null)/$(sed -n 's/^cap=//p' "$PUI_D/display.env" 2>/dev/null)/$(pui_x STOP_SPINNER 7)/$(wc -l < "$PUI_D/display.calls" 2>/dev/null | tr -d ' ')" = 0/no/no/1/1 ]
pui_is capwait [ "$PUI_CDT" -ge 18 ]
pui_is capwaitmax [ "$PUI_CDT" -le 100 ]
pui_run "$PUI_HL" sh "$PUI_PL" stop
# The collector dies 2 s after it started, leaving no capture: the wait ends with it, not at the cap (10 s here).
pui_new; : > "$PUI_D/col.nojson"; echo 2 > "$PUI_D/col.short"
pui_ans "=Start" "!2"; PUI_CT0=$(pui_now); pui_run_ui "$PUI_UIP" STARCHORUS_FIRST_CAP=100 sh "$PUI_PL"; PUI_CDT=$(($(pui_now) - PUI_CT0))
pui_is capgone [ "$PUI_RC/$(sed -n 's/^cap=//p' "$PUI_D/display.env" 2>/dev/null)/$(pui_x STOP_SPINNER 7)/$(wc -l < "$PUI_D/display.calls" 2>/dev/null | tr -d ' ')" = 0/no/1/1 ]
pui_is capgonefast [ "$PUI_CDT" -le 70 ]
pui_run "$PUI_HL" sh "$PUI_PL" stop
# The Overview is not to open (STARCHORUS_DASHBOARD=0, or no jq): nothing is waited for, however long the cap and however empty
# the directory.
pui_new; : > "$PUI_D/col.nojson"
pui_ans "=Start" "!2"; PUI_CT0=$(pui_now); pui_run_ui "$PUI_UIP" STARCHORUS_DASHBOARD=0 STARCHORUS_FIRST_CAP=100 sh "$PUI_PL"; PUI_CDT=$(($(pui_now) - PUI_CT0))
pui_is nowait [ "$PUI_RC/$(pui_x STOP_SPINNER 7)/$([ -e "$PUI_D/display.calls" ] && echo ov)" = 0/1/ ]
pui_is nowaitfast [ "$PUI_CDT" -le 50 ]
pui_run "$PUI_HL" sh "$PUI_PL" stop
pui_new; : > "$PUI_D/col.nojson"
pui_ans "=Start" "!2"; PUI_CT0=$(pui_now); pui_run_ui "$PUI_NJQ" STARCHORUS_FIRST_CAP=100 sh "$PUI_PL"; PUI_CDT=$(($(pui_now) - PUI_CT0))
pui_is nowaitjq [ "$PUI_RC/$(pui_x STOP_SPINNER 7)/$([ -e "$PUI_D/display.calls" ] && echo ov)" = 0/1/ ]
pui_is nowaitjqfast [ "$PUI_CDT" -le 50 ]
pui_run "$PUI_HL" sh "$PUI_PL" stop
# A spinner that is up when the payload is killed is stopped first (the runner would hang on the START_SPINNER child otherwise):
# TERM while Start waits for a capture that does not come: STOP_SPINNER 7 once, status 143 (the trap's exit), within 2 s, no
# Overview. With the Overview open (display.hold: it stays up) the same TERM must end the payload at once by the signal itself
# (-15): a trap held over from the spinner would wait for the Overview to return.
for pui_sh in $PUI_SH; do
  pui_new; : > "$PUI_D/col.nojson"
  pui_ans "=Start" "!2"; pui_term "$PUI_LOG" START_SPINNER "$PUI_UIP" "$pui_sh" "$PUI_PL"
  pui_is "spintrap:$pui_sh" [ "$PUI_TRC/$(pui_x START_SPINNER Starting)/$(pui_x STOP_SPINNER 7)/$([ -e "$PUI_D/display.calls" ] && echo ov)" = 143/1/1/ ]
  pui_is "spintrapfast:$pui_sh" [ "${PUI_TDT%.*}" -le 2 ]
  pui_run "$PUI_HL" sh "$PUI_PL" stop
  pui_new; : > "$PUI_D/display.hold"
  pui_ans "=Start" "!2"; pui_term "$PUI_D/display.calls" "" "$PUI_UIP" "$pui_sh" "$PUI_PL"
  pui_is "ovterm:$pui_sh" [ "$PUI_TRC/$(pui_x STOP_SPINNER 7)" = -15/1 ]
  pui_is "ovtermfast:$pui_sh" [ "${PUI_TDT%.*}" -le 2 ]
  pui_run "$PUI_HL" sh "$PUI_PL" stop
done
rowif "payload ui: Start without a question, Overview as a child (nice 19, SINCE, parent), RUNNING/Overview, B = L4; Stop is quick ($PUI_DT s) and complete; the spinner stays up for the first capture, a TERM stops it (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 12 · pid reuse: a pidfile naming a process that is not ours (the loop's and the airodump's) is deleted at launch,
#            gives no false RUNNING, and neither the menu nor `payload.sh stop` signals that process; with the marker left
#            by a crashed run, L6 is written once and the marker goes
PUI_BAD=""; pui_new
pui_bg "$PUI_T/decoy/other"; PUI_DEC=$PUI_BGP
printf '%s\n' "$PUI_DEC" > "$PUI_D/starchorus-loop.pid"; printf '%s\n' "$PUI_DEC" > "$PUI_D/starchorus-airodump.pid"
pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is stopped [ "$(pui_x "$PUI_STOP" Start)" = 1 ]
pui_is pidfiles pui_no "$PUI_D/starchorus-loop.pid" "$PUI_D/starchorus-airodump.pid"
pui_is alive kill -0 "$PUI_DEC"
pui_is nol6 [ "$(pui_logc 'had stopped')" = 0 ]
printf '%s\n' "$PUI_DEC" > "$PUI_D/starchorus-loop.pid"
pui_run "$PUI_HL" sh "$PUI_PL" stop
pui_is clistop kill -0 "$PUI_DEC"
printf '%s\n' "$PUI_DEC" > "$PUI_D/starchorus-loop.pid"
pui_run "$PUI_HL" sh "$PUI_PL" status
pui_is clistatus [ "$(grep -c '^loop not running$' "$PUI_T/out")" = 1 ]
printf '%s\n' "$PUI_DEC" > "$PUI_D/starchorus-loop.pid"; date +%s > "$PUI_T/started"
pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is l6 [ "$(pui_x LOG red 'Collector had stopped.')/$(pui_x LOG red 'See collect.log.')" = 1/1 ]
pui_is markergone [ ! -e "$PUI_T/started" ]
pui_is alive2 kill -0 "$PUI_DEC"
kill "$PUI_DEC" 2>/dev/null
rowif "payload ui: pid reuse: stale pidfiles deleted at launch, no false RUNNING, nothing foreign signalled; crash -> L6 once (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 13 · a loop that lingers after Stop (it ignores TERM): after 10 s it and its airodump get kill -9 (identity-checked),
#            Stop still ends on STOPPED with L3; a collector that cannot start: E2, L7 (the log's last line, 40 characters),
#            STOPPED/Start, no marker, no Overview
PUI_BAD=""; pui_new; : > "$PUI_D/col.deaf"
pui_run "$PUI_HL" sh "$PUI_PL" start; pui_col
PUI_CP=$(pui_cpid)
printf '#!/bin/sh\nwhile :; do sleep 1; done\n' > "$PUI_D/airodump-ng"
pui_bg "$PUI_D/airodump-ng"; PUI_ADP=$PUI_BGP; printf '%s\n' "$PUI_ADP" > "$PUI_D/starchorus-airodump.pid"
pui_ans "=Stop" "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is loopgone pui_gone "${PUI_CP:-0}"
pui_is adgone pui_gone "${PUI_ADP:-0}"
pui_is l3 [ "$(pui_x LOG green 'Stopped.')/$(pui_logc '^ERROR_DIALOG')" = 1/0 ]
pui_is stopped [ "$(pui_x "$PUI_STOP" Start)" = 1 ]
pui_new; : > "$PUI_D/col.fail"
pui_ans "=Start" "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is e2 [ "$(pui_x ERROR_DIALOG 'Could not start.\nSee the log.')" = 1 ]
pui_is l7 [ "$(pui_x LOG red 'no usable passive source; wrote an empty')" = 1 ]
pui_is e2stopped [ "$(pui_x "$PUI_STOP" Start)" = 2 ]
pui_is e2marker [ ! -e "$PUI_T/started" ]
pui_is e2overview [ ! -e "$PUI_D/display.calls" ]
rowif "payload ui: a lingering loop gets kill -9 after 10 s (airodump too), STOPPED; a failed Start: E2, L7, STOPPED (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 14 · debounce: right after the Overview a queued B is ignored (RUNNING drawn again); right after the Stop spinner a
#            queued Start is ignored (STOPPED drawn again); an answer that took a human's time is taken
PUI_BAD=""; pui_new
pui_ans "=Start" "q!2" "=Stop" "q=Start" "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is starts [ "$(wc -l < "$PUI_D/col.starts" 2>/dev/null | tr -d ' ')" = 1 ]
pui_is running [ "$(pui_logc "^$PUI_RUN")" = 2 ]
pui_is stopped [ "$(pui_logc "^$PUI_STOP")" = 3 ]
pui_is nol4 [ "$(pui_logc 'Still running')" = 0 ]
pui_is down [ ! -s "$PUI_D/starchorus-loop.pid" ]
pui_new
pui_ans "=Start" "=Stop" "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is human [ "$(pui_x LOG green 'Stopped.')/$(pui_logc "^$PUI_RUN")" = 1/1 ]
# a picker that keeps failing at once (the UI session gone): three answers are ignored, the fourth ends the payload (L4), the
# menu is not drawn for ever (without the cap this run would only end at the 20 s limit)
pui_new
pui_ans "=Start" "q!2" "q!2" "q!2" "q!2" "q!2" "q!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is capped [ "$PUI_RC/$(pui_logc "^$PUI_RUN")/$(pui_used)/$(pui_x LOG blue 'Still running.')" = 0/4/5/1 ]
rowif "payload ui: debounce: a queued B after the Overview and a queued Start after Stop are ignored, a real press is not, a failing picker ends it (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 15 · Settings: rows and title-case labels, the cursor on row 1, ON/OFF flips in place (cursor stays, L8a/L8b/L8c on
#            switching on), sub-lists titled by the row with the cursor on the current value (row 1 for a custom one), Port
#            through NUMBER_PICKER (E7 for 1471), B in a sub-list changes nothing, leaving while STOPPED applies nothing
PUI_BAD=""; pui_new "interval=45"
pui_ans "=Settings" "=Vendor Names: ON" "=Vendor Names: OFF" "=Channel Load: OFF" "=Refresh: 45 s" "=1 min" "=Show Last: 1 h" \
  "!2" "=Show Last: 1 h" "=All (may be slow)" "=Port: 8199" "=1471" "=Port: 8199" "=8300" "r:2:Port: 8300" "!2"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is rows [ "$(pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 45 s' 'Show Last: 1 h' 'Vendor Names: ON' 'Channel Load: OFF' 'Traffic: OFF' 'Bluetooth: OFF' 'Alerts: OFF' 'Port: 8199' 'Reset to Defaults' 'Web Page: ON')" = 1 ]
pui_is flipcursor [ "$(pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 45 s' 'Show Last: 1 h' 'Vendor Names: OFF' 'Channel Load: OFF' 'Traffic: OFF' 'Bluetooth: OFF' 'Alerts: OFF' 'Port: 8199' 'Reset to Defaults' 'Vendor Names: OFF')" = 1 ]
pui_is l8a [ "$(pui_x LOG 'Vendor names: device makers.')" = 1 ]
pui_is l8bc [ "$(pui_x LOG 'Channel load: busy time per')/$(pui_x LOG 'channel, in Air quality.')" = 1/1 ]
pui_is custom [ "$(pui_x LIST_PICKER 'Refresh: 45 s' '10 s' '30 s' '1 min' '2 min' '10 s')" = 1 ]
pui_is window [ "$(pui_x LIST_PICKER 'Show Last: 1 h' '2 min' '10 min' '1 h' '6 h' 'All (may be slow)' '1 h')" = 2 ]
pui_is e7 [ "$(pui_x NUMBER_PICKER Port 8199)/$(pui_x ERROR_DIALOG 'Use 1024 to 65535, not 1471.')" = 2/1 ]
pui_is last [ "$(pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 1 min' 'Show Last: All' 'Vendor Names: ON' 'Channel Load: ON' 'Traffic: OFF' 'Bluetooth: OFF' 'Alerts: OFF' 'Port: 8300' 'Reset to Defaults' 'Port: 8300')" = 1 ]
pui_is file [ "$(LC_ALL=C sort "$PUI_D/settings.conf" | tr '\n' ' ')" = "interval=60 port=8300 survey=on vendor=on window=0 " ]
pui_is noapply [ "$(pui_logc '^START_SPINNER')/$(pui_logc 'Settings applied')" = 0/0 ]
pui_is back [ "$(pui_x "$PUI_STOP" Settings)" = 1 ]
pui_is nocol pui_nocol
rowif "payload ui: Settings rows, flips in place, L8, sub-lists with cursor and custom value, Port/E7, Back changes nothing (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 15b · the two rows after Channel Load, 'Traffic' and 'Bluetooth' (both off by default, both collector keys): they flip in place with one
#             press and the cursor stays on the row; switching on logs L8d / L8e, one line each, exactly as the specification words them, and
#             switching off logs nothing; the file holds the key; a key the environment sets reads '(locked)' and P1 names its variable;
#             leaving Settings while RUNNING restarts the collector alone, once, with both new values (marker kept), and a change flipped
#             back applies nothing; the collector gets 0 and 0 by default and 1 once switched on
PUI_BAD=""; pui_new
pui_ans "=Settings" "=Traffic: OFF" "=Bluetooth: OFF" "=Traffic: ON" "=Bluetooth: ON" "=Traffic: OFF" "!2" "!2"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is rows [ "$(pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 30 s' 'Show Last: 1 h' 'Vendor Names: ON' 'Channel Load: OFF' 'Traffic: OFF' 'Bluetooth: OFF' 'Alerts: OFF' 'Port: 8199' 'Reset to Defaults' 'Web Page: ON')" = 1 ]
pui_is traffic_on [ "$(pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 30 s' 'Show Last: 1 h' 'Vendor Names: ON' 'Channel Load: OFF' 'Traffic: ON' 'Bluetooth: OFF' 'Alerts: OFF' 'Port: 8199' 'Reset to Defaults' 'Traffic: ON')" = 2 ]   # after the first and after the last flip
pui_is bluetooth_on [ "$(pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 30 s' 'Show Last: 1 h' 'Vendor Names: ON' 'Channel Load: OFF' 'Traffic: ON' 'Bluetooth: ON' 'Alerts: OFF' 'Port: 8199' 'Reset to Defaults' 'Bluetooth: ON')" = 1 ]
pui_is traffic_off [ "$(pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 30 s' 'Show Last: 1 h' 'Vendor Names: ON' 'Channel Load: OFF' 'Traffic: OFF' 'Bluetooth: ON' 'Alerts: OFF' 'Port: 8199' 'Reset to Defaults' 'Traffic: OFF')" = 1 ]
pui_is bluetooth_off [ "$(pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 30 s' 'Show Last: 1 h' 'Vendor Names: ON' 'Channel Load: OFF' 'Traffic: OFF' 'Bluetooth: OFF' 'Alerts: OFF' 'Port: 8199' 'Reset to Defaults' 'Bluetooth: OFF')" = 1 ]
pui_is l8d [ "$(pui_x LOG 'Traffic: channel activity and frame rates.')" = 2 ]
pui_is l8e [ "$(pui_x LOG 'Bluetooth: passive LE scan, 5 s per refresh.')" = 1 ]
# L8e names the window the collector will use: STARCHORUS_BT_WINDOW as the collector reads it (9; 07 is 7; 4, 16 and text are 5)
for pui_w in 9:9 07:7 4:5 16:5 abc:5; do
  pui_new; pui_ans "=Settings" "=Bluetooth: OFF" "!2" "!2"
  pui_run_ui "$PUI_UIP" STARCHORUS_BT_WINDOW="${pui_w%%:*}" sh "$PUI_PL"
  pui_is "l8e_${pui_w%%:*}" [ "$(pui_x LOG "Bluetooth: passive LE scan, ${pui_w#*:} s per refresh.")" = 1 ]
done
pui_new; pui_ans "=Settings" "=Traffic: OFF" "=Bluetooth: OFF" "=Traffic: ON" "=Bluetooth: ON" "=Traffic: OFF" "!2" "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is file [ "$(LC_ALL=C sort "$PUI_D/settings.conf" | tr '\n' ' ')" = "bluetooth=off traffic=on " ]
pui_is noapply [ "$(pui_logc '^START_SPINNER')/$(pui_logc 'Settings applied')" = 0/0 ]
pui_is nocol pui_nocol
# locked: STARCHORUS_TRAFFIC / STARCHORUS_BLUETOOTH in the environment (a 0 counts as set, like every other key): the row shows the value and
# (locked), a press shows P1 naming the variable and writes nothing
pui_new
pui_ans "=Settings" "=Traffic: ON (locked)" "=Bluetooth: OFF (locked)" "!2" "!2"
pui_run_ui "$PUI_UIP" STARCHORUS_TRAFFIC=1 STARCHORUS_BLUETOOTH=0 sh "$PUI_PL"
pui_is lockedrows [ "$(pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 30 s' 'Show Last: 1 h' 'Vendor Names: ON' 'Channel Load: OFF' 'Traffic: ON (locked)' 'Bluetooth: OFF (locked)' 'Alerts: OFF' 'Port: 8199' 'Reset to Defaults' 'Web Page: ON')" = 1 ]
pui_is p1t [ "$(pui_x PROMPT 'Set by STARCHORUS_TRAFFIC.\nUnset it to change it here.')" = 1 ]
pui_is p1b [ "$(pui_x PROMPT 'Set by STARCHORUS_BLUETOOTH.\nUnset it to change it here.')" = 1 ]
pui_is lockedfile [ ! -e "$PUI_D/settings.conf" ]
pui_is locknoflip [ "$(pui_logc '^LOG	Traffic: channel')/$(pui_logc '^LOG	Bluetooth: passive')" = 0/0 ]
pui_is lockedcol pui_nocol
# apply on leaving while RUNNING: both flipped in one visit = one restart of the collector alone, both switched on in it, marker kept;
# a change flipped back in a second visit applies nothing
pui_new
pui_ans "=Start" "=Settings" "=Traffic: OFF" "=Bluetooth: OFF" "!2" "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
PUI_CP=$(sed -n 1p "$PUI_D/col.starts" 2>/dev/null); PUI_MK=$(cat "$PUI_T/started" 2>/dev/null)
pui_is a:rc [ "$PUI_RC" = 0 ]
pui_is a:restarted [ "$(wc -l < "$PUI_D/col.starts" | tr -d ' ')" = 2 ]
pui_is a:oldgone pui_gone "${PUI_CP:-0}"
pui_is a:up pui_up
pui_is a:value [ "$(pui_env STARCHORUS_BLUETOOTH)/$(pui_env STARCHORUS_TRAFFIC)" = 1/1 ]
pui_is a:spin [ "$(pui_x START_SPINNER Applying)/$(pui_x LOG blue 'Settings applied.')" = 1/1 ]
pui_is a:noquestion [ "$(pui_logc '^CONFIRMATION_DIALOG')" = 0 ]
PUI_CP=$(pui_cpid)
pui_ans "=Settings" "=Bluetooth: ON" "=Bluetooth: OFF" "!2" "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is b:flipback [ "$(pui_logc '^START_SPINNER')/$(pui_logc 'Settings applied')/$(wc -l < "$PUI_D/col.starts" | tr -d ' ')" = 0/0/2 ]
pui_is b:samepid [ "$(pui_cpid)" = "$PUI_CP" ]
pui_is b:markerkept [ "${PUI_MK:-none}" = "$(cat "$PUI_T/started" 2>/dev/null)" ]
# the CLI: `set bluetooth on` reaches the collector at the next start, as 1
pui_run "$PUI_HL" sh "$PUI_PL" stop
pui_new; pui_run "$PUI_HL" sh "$PUI_PL" set bluetooth on
pui_is cli:set [ "$PUI_RC/$(pui_get bluetooth)/$(pui_get traffic)" = "0/on file/off default" ]
pui_run "$PUI_HL" sh "$PUI_PL"
pui_is cli:started pui_col
pui_is cli:env [ "$(pui_env STARCHORUS_BLUETOOTH)/$(pui_env STARCHORUS_TRAFFIC)" = 1/0 ]
pui_run "$PUI_HL" sh "$PUI_PL" stop
rowif "payload ui: Traffic and Bluetooth rows after Channel Load flip in place, L8d/L8e, lock with P1, restart the collector once on leaving, set bluetooth on (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 15c · the 'Alerts' row after Bluetooth: ON while our payload.sh is in our one directory of the firmware's alert tree, OFF while it is
#             not. A press asks first (C2 to install, C3 to remove). Install = the README's steps (mkdir -p, cp, chmod +x) through a temporary file
#             and a rename: the file is byte-identical to the companion beside the payload and executable, no .tmp is left, L8f; No (or a cancel)
#             installs nothing and does not even create the tree. Remove takes our payload.sh and our directory if it is empty (a file of somebody
#             else's in it stays, and so does the firmware's own parent directory), L8g. A failed step is E14 / E15 with no .tmp and no empty
#             directory of ours left. A companion that is not beside the payload is E13, before any question; _PAYLOAD_HOME finds it when the payload
#             runs from a copy elsewhere (the device runs it from /tmp). STARCHORUS_ALERTS in the environment, set to anything but 1, locks the row (P2: the collector then
#             ignores the log); a copy that the firmware's switch renamed to DISABLED.starchorus reads 'OFF (firmware)' (P3, no install; Remove takes it too). The tree
#             is $PUI_T/alerts (STARCHORUS_ALERT_TREE, set for every run); stand-ins for mkdir, cp, chmod, mv, rm and rmdir under $PUI_T/alb note
#             each call in alert.cmds and fail on demand (alert.fail.NAME) for a path of the tree. The notes are read by their tabs, so a companion
#             path with a space in it (tools/fresh-check.sh clones into one) is one argument; a control note with such a path proves the reading.
#             The static row pins every line of the payload that names the directory (a new or changed one is red), with three planted mutants as
#             controls.
mkdir -p "$PUI_T/alb"
cat > "$PUI_T/alb/tpl" <<'PUI_ALB'
#!/bin/sh
# stand-in for a tool the Alerts row calls: notes the call (alert.cmds), fails when alert.fail.NAME exists and an argument is a path of the alert tree, else the real tool
n=$(basename "$0"); tb=$(printf '\t'); l=$n; for a; do l=$l$tb$a; done
printf '%s\n' "$l" >> "$PUI_T/alert.cmds"
if [ -e "$PUI_T/alert.fail.$n" ]; then case "$*" in *"$PUI_T/alerts"*) exit 1 ;; esac; fi
exec REAL "$@"
PUI_ALB
for pui_t in mkdir cp chmod mv rm rmdir; do
  pui_p=$(command -v "$pui_t" 2>/dev/null) && case $pui_p in /*) sed "s|REAL|$pui_p|" "$PUI_T/alb/tpl" > "$PUI_T/alb/$pui_t"; chmod +x "$PUI_T/alb/$pui_t" ;; esac
done
PUI_ALP="$PUI_T/ui:$PUI_T/alb:$PUI_T/bin:$PUI_T/jq:$PUI_T/sys"   # the device UI stand-ins, then the stand-ins above
PUI_AT="$PUI_T/alerts/deauth_flood_detected/starchorus"
PUI_AD="$PUI_T/alerts/deauth_flood_detected/DISABLED.starchorus"   # where the firmware's switch puts our directory when the owner switches the alert off on its Alerts page
PUI_AC="$R/library/user/reconnaissance/starchorus/alert-deauth.sh"
pui_alx() {   # pui_alx ALERTS_ROW CURSOR -> how many Settings lists had the default rows, that Alerts row and the cursor on CURSOR
  pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 30 s' 'Show Last: 1 h' 'Vendor Names: ON' 'Channel Load: OFF' 'Traffic: OFF' 'Bluetooth: OFF' "$1" 'Port: 8199' 'Reset to Defaults' "$2"
}
pui_not() { ! "$@"; }   # the negation of a command, for pui_is
pui_alclean() { [ -z "$(find "$PUI_T/alerts" -name '*.tmp' 2>/dev/null)" ] && [ ! -e "$PUI_AT" ]; }   # no .tmp anywhere in the tree and no directory of ours
pui_alnew() { rm -rf "$PUI_T/alerts"; rm -f "$PUI_T/alert.cmds" "$PUI_T/alert.fail."*; pui_new; }   # no tree, no notes, a fresh payload directory
pui_alins() { [ -x "$PUI_AT/payload.sh" ] && cmp -s "$PUI_AC" "$PUI_AT/payload.sh"; }               # our payload.sh is there, executable, the companion byte for byte
pui_alcalls() {   # -> the notes that name the tree on one line (the tree, the DISABLED directory, the companion's path and the tab shown as AT,
  # AD, SRC and a space; the path is taken between its tabs, whole, so that a space in it -- the fresh clone's directory has one -- does not split it)
  pui_tb=$(printf '\t')
  { grep -F "$PUI_T/alerts" "$PUI_T/alert.cmds" 2>/dev/null || :; } | sed -e "s|$PUI_AT|AT|g" -e "s|$PUI_AD|AD|g" -e "s|${pui_tb}[^${pui_tb}]*/alert-deauth\.sh${pui_tb}|${pui_tb}SRC${pui_tb}|" | tr '\t' ' ' | tr '\n' '|'
}
pui_altree() { if [ -d "$PUI_T/alerts" ]; then (cd "$PUI_T/alerts" && find . | LC_ALL=C sort | tr '\n' ' '); else echo none; fi; }
# n. the reading of the notes: a planted note whose companion path holds a space reads as SRC whole (the fresh clone's directory is such a path)
PUI_BAD=""; pui_alnew; printf 'cp\t%s/a b/alert-deauth.sh\t%s/payload.sh.tmp\n' "$PUI_T" "$PUI_AT" > "$PUI_T/alert.cmds"
pui_is n:space [ "$(pui_alcalls)" = "cp SRC AT/payload.sh.tmp|" ]
# a. OFF -> yes: the row flips to ON with the cursor on it, C2 once, exactly the notes below, L8f, nothing else written
pui_alnew
pui_ans "=Settings" "=Alerts: OFF" "=1" "!2" "!2"
pui_run_ui "$PUI_ALP" sh "$PUI_PL"
pui_is a:rc [ "$PUI_RC" = 0 ]
pui_is a:off [ "$(pui_alx 'Alerts: OFF' 'Web Page: ON')" = 1 ]
pui_is a:c2 [ "$(pui_x CONFIRMATION_DIALOG "Install the alert\\ncompanion? It may run at\\nonce; switch it off on\\nthe firmware Alerts page.")/$(pui_logc '^CONFIRMATION_DIALOG')" = 1/1 ]
pui_is a:on [ "$(pui_alx 'Alerts: ON' 'Alerts: ON')" = 1 ]
pui_is a:file pui_alins
pui_is a:calls [ "$(pui_alcalls)" = "rm -f AT/payload.sh.tmp|mkdir -p AT|cp SRC AT/payload.sh.tmp|chmod +x AT/payload.sh.tmp|mv -f AT/payload.sh.tmp AT/payload.sh|" ]
pui_is a:tree [ "$(pui_altree)" = ". ./deauth_flood_detected ./deauth_flood_detected/starchorus ./deauth_flood_detected/starchorus/payload.sh " ]
pui_is a:log [ "$(pui_x LOG "Alerts: the firmware's reports are noted.")/$(pui_logc '^ERROR_DIALOG')/$(pui_logc '^START_SPINNER')" = 1/0/0 ]
pui_is a:nosettings [ ! -e "$PUI_D/settings.conf" ]
pui_is a:nocol pui_nocol
# b. ON -> a No (an answer of 0, then a cancel): nothing asked twice, nothing touched, no log
rm -f "$PUI_T/alert.cmds"; pui_new
pui_ans "=Settings" "=Alerts: ON" "=0" "=Alerts: ON" "!2" "!2" "!2"
pui_run_ui "$PUI_ALP" sh "$PUI_PL"
pui_is b:on [ "$(pui_alx 'Alerts: ON' 'Web Page: ON')/$(pui_alx 'Alerts: ON' 'Alerts: ON')" = 1/2 ]
pui_is b:c3 [ "$(pui_x CONFIRMATION_DIALOG "Remove the alert\\ncompanion?")/$(pui_logc '^CONFIRMATION_DIALOG')" = 2/2 ]
pui_is b:kept pui_alins
pui_is b:calls [ -z "$(pui_alcalls)" ]
pui_is b:nolog [ "$(pui_logc '^LOG	Alerts:')/$(pui_logc '^ERROR_DIALOG')" = 0/0 ]
# c. ON -> yes, with a file of somebody else's in our directory: our payload.sh goes, the directory and the file stay; then yes without it: the directory goes too, the firmware's parent stays
printf 'not ours\n' > "$PUI_AT/other.txt"; rm -f "$PUI_T/alert.cmds"; pui_new
pui_ans "=Settings" "=Alerts: ON" "=1" "!2" "!2"
pui_run_ui "$PUI_ALP" sh "$PUI_PL"
pui_is c:off [ "$(pui_alx 'Alerts: OFF' 'Alerts: OFF')" = 1 ]
pui_is c:calls [ "$(pui_alcalls)" = "rm -f AT/payload.sh AT/payload.sh.tmp|rmdir AT|" ]
pui_is c:tree [ "$(pui_altree)" = ". ./deauth_flood_detected ./deauth_flood_detected/starchorus ./deauth_flood_detected/starchorus/other.txt " ]
pui_is c:log [ "$(pui_x LOG 'Alerts: companion removed.')/$(pui_logc '^ERROR_DIALOG')" = 1/0 ]
rm -f "$PUI_AT/other.txt"; mkdir -p "$PUI_AT"; cp "$PUI_AC" "$PUI_AT/payload.sh"; chmod +x "$PUI_AT/payload.sh"; rm -f "$PUI_T/alert.cmds"; pui_new
pui_ans "=Settings" "=Alerts: ON" "=1" "!2" "!2"
pui_run_ui "$PUI_ALP" sh "$PUI_PL"
pui_is c2:tree [ "$(pui_altree)" = ". ./deauth_flood_detected " ]
pui_is c2:calls [ "$(pui_alcalls)" = "rm -f AT/payload.sh AT/payload.sh.tmp|rmdir AT|" ]
# d. OFF -> a No: not even the tree is made
pui_alnew
pui_ans "=Settings" "=Alerts: OFF" "=0" "!2" "!2"
pui_run_ui "$PUI_ALP" sh "$PUI_PL"
pui_is d:none [ "$(pui_altree)/$(pui_alcalls)/$(pui_logc '^LOG	Alerts:')" = "none//0" ]
# e. STARCHORUS_ALERTS is the collector's read switch (only 1 reads alerts.log, which an installed companion feeds). Set to anything but 1 (0 here) the row is locked, and P2 says
# what that means (the collector ignores the log); no question, nothing written
pui_alnew
pui_ans "=Settings" "=Alerts: OFF (locked)" "!2" "!2"
pui_run_ui "$PUI_ALP" STARCHORUS_ALERTS=0 sh "$PUI_PL"
pui_is e:rows [ "$(pui_alx 'Alerts: OFF (locked)' 'Web Page: ON')" = 1 ]
pui_is e:p2 [ "$(pui_x PROMPT 'The collector ignores the\nalert log: STARCHORUS_ALERTS\nis not 1. Unset it to\nuse this row.')/$(pui_logc '^CONFIRMATION_DIALOG')" = 1/0 ]
pui_is e:none [ "$(pui_altree)/$(pui_alcalls)" = "none/" ]
# e2. set to 1 (the collector's default) the row is free: no lock, a press asks C3, and a No keeps the file
mkdir -p "$PUI_AT"; cp "$PUI_AC" "$PUI_AT/payload.sh"; chmod +x "$PUI_AT/payload.sh"; pui_new
pui_ans "=Settings" "=Alerts: ON" "=0" "!2" "!2"
pui_run_ui "$PUI_ALP" STARCHORUS_ALERTS=1 sh "$PUI_PL"
pui_is e2:rows [ "$(pui_alx 'Alerts: ON' 'Web Page: ON')/$(pui_x CONFIRMATION_DIALOG 'Remove the alert\ncompanion?')/$(pui_logc '^PROMPT')" = 1/1/0 ]
pui_is e2:kept pui_alins
# e3. the controls of e and e2 (planted copies of the payload, run from $PUI_T so _PAYLOAD_HOME says where the companion is): with the lock taken off the row, STARCHORUS_ALERTS=0 shows an
# open 'Alerts: OFF' (e:rows would be red); with the old test, which locked for any value, STARCHORUS_ALERTS=1 shows 'Alerts: ON (locked)' (e2:rows would be red)
# shellcheck disable=SC2016   # sed programs: the payload's own text, not to be expanded here
sed '/^\[ "\${STARCHORUS_ALERTS:-1}" = 1 \] || PL_ENV=/d' "$PUI_PL" > "$PUI_T/alm5.sh"
# shellcheck disable=SC2016   # (as above)
sed 's/^\[ "\${STARCHORUS_ALERTS:-1}" = 1 \] || PL_ENV=/[ -z "${STARCHORUS_ALERTS:+x}" ] || PL_ENV=/' "$PUI_PL" > "$PUI_T/alm6.sh"
pui_alnew; pui_ans "=Settings" "=Alerts: OFF" "!2" "!2" "!2"
pui_run_ui "$PUI_ALP" _PAYLOAD_HOME="$(dirname "$PUI_AC")" STARCHORUS_ALERTS=0 sh "$PUI_T/alm5.sh"
pui_is e3:nolock [ "$(pui_alx 'Alerts: OFF' 'Web Page: ON')/$(pui_alx 'Alerts: OFF (locked)' 'Web Page: ON')" = 1/0 ]
pui_alnew; mkdir -p "$PUI_AT"; cp "$PUI_AC" "$PUI_AT/payload.sh"; chmod +x "$PUI_AT/payload.sh"; pui_new
pui_ans "=Settings" "=Alerts: ON (locked)" "!2" "!2"
pui_run_ui "$PUI_ALP" _PAYLOAD_HOME="$(dirname "$PUI_AC")" STARCHORUS_ALERTS=1 sh "$PUI_T/alm6.sh"
pui_is e3:oldlock [ "$(pui_alx 'Alerts: ON (locked)' 'Web Page: ON')/$(pui_alx 'Alerts: ON' 'Web Page: ON')" = 1/0 ]
pui_is e3:diff [ "$(diff "$PUI_PL" "$PUI_T/alm5.sh" | grep -c '^<')/$(diff "$PUI_PL" "$PUI_T/alm6.sh" | grep -c '^<')" = 1/1 ]
# f. a failed step: E14 and nothing left (no .tmp, no empty directory of ours), the row still OFF; a failed remove: E15, the file stays
for pui_f in mkdir cp chmod mv; do
  pui_alnew; : > "$PUI_T/alert.fail.$pui_f"
  pui_ans "=Settings" "=Alerts: OFF" "=1" "!2" "!2"
  pui_run_ui "$PUI_ALP" sh "$PUI_PL"
  pui_is "f:$pui_f:e14" [ "$(pui_x ERROR_DIALOG 'Could not install the\nalert companion.')/$(pui_logc '^LOG	Alerts:')" = 1/0 ]
  pui_is "f:$pui_f:row" [ "$(pui_alx 'Alerts: OFF' 'Alerts: OFF')" = 1 ]
  pui_is "f:$pui_f:clean" pui_alclean
done
pui_alnew; mkdir -p "$PUI_AT"; cp "$PUI_AC" "$PUI_AT/payload.sh"; chmod +x "$PUI_AT/payload.sh"; : > "$PUI_T/alert.fail.rm"
pui_ans "=Settings" "=Alerts: ON" "=1" "!2" "!2"
pui_run_ui "$PUI_ALP" sh "$PUI_PL"
pui_is f:rm:e15 [ "$(pui_x ERROR_DIALOG 'Could not remove the\nalert companion.')/$(pui_logc '^LOG	Alerts:')" = 1/0 ]
pui_is f:rm:kept pui_alins
# g. no companion beside the payload: E13 before any question, nothing written; _PAYLOAD_HOME finds one when the payload runs from a copy elsewhere
pui_alnew; mkdir -p "$PUI_T/nocomp"; cp "$PUI_PL" "$PUI_T/nocomp/payload.sh"
pui_ans "=Settings" "=Alerts: OFF" "!2" "!2"
pui_run_ui "$PUI_ALP" sh "$PUI_T/nocomp/payload.sh"
pui_is g:e13 [ "$(pui_x ERROR_DIALOG 'alert-deauth.sh is not\nbeside the payload.')/$(pui_logc '^CONFIRMATION_DIALOG')/$(pui_altree)" = 1/0/none ]
pui_alnew
pui_ans "=Settings" "=Alerts: OFF" "=1" "!2" "!2"
pui_run_ui "$PUI_ALP" _PAYLOAD_HOME="$(dirname "$PUI_AC")" sh "$PUI_T/nocomp/payload.sh"
pui_is g:home pui_alins
rm -rf "$PUI_T/nocomp"
# h. plain and argument paths: no UI command, no tree, and no settings key behind the row
pui_alnew
for pui_c in status get "get alerts" "set alerts on"; do
  # shellcheck disable=SC2086   # the command words are split on purpose
  pui_run_ui "$PUI_ALP" sh "$PUI_PL" $pui_c
  case $pui_c in "get alerts"|"set alerts on") pui_ex=2 ;; *) pui_ex=0 ;; esac
  pui_is "h:$pui_c" [ "$PUI_RC/$(wc -l < "$PUI_T/case.log" | tr -d ' ')/$(pui_altree)" = "$pui_ex/0/none" ]
done
pui_run_ui "$PUI_ALP" STARCHORUS_PAYLOAD_PLAIN=1 sh "$PUI_PL"
pui_is h:plain [ "$PUI_RC/$(wc -l < "$PUI_T/case.log" | tr -d ' ')/$(pui_altree)/$(pui_alcalls)" = "0/0/none/" ]
pui_run "$PUI_HL" sh "$PUI_PL" stop
pui_run "$PUI_HL" sh "$PUI_PL" get
pui_is h:nokey [ "$PUI_RC/$(grep -c 'alert' "$PUI_T/out")" = 0/0 ]
# k. the firmware's own switch: a payload switched off on its Alerts page is renamed DISABLED.<name> (the directory, beside the enabled one). With only that copy the row reads
# 'Alerts: OFF (firmware)' (22 characters, ASCII; "(locked)" takes its place while STARCHORUS_ALERTS locks the row, so no label passes 28), a press says P3 and installs nothing: a second,
# enabled copy would run beside the one the owner switched off. Remove (from ON) takes a stale copy of that kind too, our payload.sh and our empty directory only.
pui_aldis() {   # pui_aldis -> a fresh payload directory and a tree that holds only the renamed copy of ours
  rm -rf "$PUI_T/alerts"; rm -f "$PUI_T/alert.cmds" "$PUI_T/alert.fail."*; mkdir -p "$PUI_AD"; cp "$PUI_AC" "$PUI_AD/payload.sh"; chmod +x "$PUI_AD/payload.sh"; pui_new
}
pui_alk1() {   # pui_alk1 -> 0 iff the last run was the k1 run below: the 'firmware' row, P3 once, no question, only the renamed copy in the tree
  [ "$(pui_alx 'Alerts: OFF (firmware)' 'Web Page: ON')/$(pui_x PROMPT 'Switched off on the\nfirmware Alerts page.\nSwitch it on there.')/$(pui_logc '^CONFIRMATION_DIALOG')/$(pui_logc '^ERROR_DIALOG')/$(pui_logc '^LOG	Alerts:')" = 1/1/0/0/0 ] \
    && [ "$(pui_altree)" = ". ./deauth_flood_detected ./deauth_flood_detected/DISABLED.starchorus ./deauth_flood_detected/DISABLED.starchorus/payload.sh " ] && [ -z "$(pui_alcalls)" ]
}
pui_aldis; pui_ans "=Settings" "=Alerts: OFF (firmware)" "!2" "!2"
pui_run_ui "$PUI_ALP" sh "$PUI_PL"
pui_is k1:real pui_alk1
pui_is k1:kept [ -x "$PUI_AD/payload.sh" ] && cmp -s "$PUI_AC" "$PUI_AD/payload.sh"
pui_is k1:label [ "$(printf '%s' 'Alerts: OFF (firmware)' | wc -c | tr -d ' ')" -le 28 ] && [ -z "$(printf '%s' 'Alerts: OFF (firmware)' | LC_ALL=C tr -d ' -~')" ]
# k1b. the same tree under STARCHORUS_ALERTS=0: the lock wins, the label stays 'Alerts: OFF (locked)' (22 characters) and P2 is shown
pui_aldis; pui_ans "=Settings" "=Alerts: OFF (locked)" "!2" "!2"
pui_run_ui "$PUI_ALP" STARCHORUS_ALERTS=0 sh "$PUI_PL"
pui_is k1b:row [ "$(pui_alx 'Alerts: OFF (locked)' 'Web Page: ON')/$(pui_logc '^CONFIRMATION_DIALOG')/$(pui_alcalls)" = 1/0/ ]
# k2. both copies (an enabled one and a stale switched-off one, as the old row could leave them): ON; Yes removes both, and with a file of somebody else's in the renamed directory
# that file and the directory stay
pui_alnew; mkdir -p "$PUI_AT" "$PUI_AD"; cp "$PUI_AC" "$PUI_AT/payload.sh"; chmod +x "$PUI_AT/payload.sh"; cp "$PUI_AC" "$PUI_AD/payload.sh"; printf 'not ours\n' > "$PUI_AD/other.txt"; pui_new
pui_ans "=Settings" "=Alerts: ON" "=1" "!2" "!2"
pui_run_ui "$PUI_ALP" sh "$PUI_PL"
pui_is k2:calls [ "$(pui_alcalls)" = "rm -f AT/payload.sh AT/payload.sh.tmp|rmdir AT|rm -f AD/payload.sh|rmdir AD|" ]
pui_is k2:tree [ "$(pui_altree)" = ". ./deauth_flood_detected ./deauth_flood_detected/DISABLED.starchorus ./deauth_flood_detected/DISABLED.starchorus/other.txt " ]
pui_is k2:log [ "$(pui_x LOG 'Alerts: companion removed.')/$(pui_logc '^ERROR_DIALOG')" = 1/0 ]
pui_alnew; mkdir -p "$PUI_AT" "$PUI_AD"; cp "$PUI_AC" "$PUI_AT/payload.sh"; chmod +x "$PUI_AT/payload.sh"; cp "$PUI_AC" "$PUI_AD/payload.sh"; pui_new
pui_ans "=Settings" "=Alerts: ON" "=1" "!2" "!2"
pui_run_ui "$PUI_ALP" sh "$PUI_PL"
pui_is k2:both [ "$(pui_altree)/$(pui_alx 'Alerts: OFF' 'Alerts: OFF')" = ". ./deauth_flood_detected /1" ]
# k3. the controls (planted copies, as in e3 and j): a payload that does not look for the renamed copy offers the install again and makes a second copy (k1:real would be red); one that
# leaves the renamed copy in the remove leaves it there (k2:both would be red)
sed 's|^pl_alert_dis() {.*|pl_alert_dis() { false; }|' "$PUI_PL" > "$PUI_T/alm7.sh"
sed '/^    if pl_alert_dis; then rm -f /d' "$PUI_PL" > "$PUI_T/alm8.sh"
pui_aldis; pui_ans "=Settings" "=Alerts: OFF" "=1" "!2" "!2"
pui_run_ui "$PUI_ALP" _PAYLOAD_HOME="$(dirname "$PUI_AC")" sh "$PUI_T/alm7.sh"
pui_is k3:second [ -x "$PUI_AT/payload.sh" ] && [ -x "$PUI_AD/payload.sh" ] && pui_not pui_alk1
pui_alnew; mkdir -p "$PUI_AT" "$PUI_AD"; cp "$PUI_AC" "$PUI_AT/payload.sh"; chmod +x "$PUI_AT/payload.sh"; cp "$PUI_AC" "$PUI_AD/payload.sh"; pui_new
pui_ans "=Settings" "=Alerts: ON" "=1" "!2" "!2"
pui_run_ui "$PUI_ALP" _PAYLOAD_HOME="$(dirname "$PUI_AC")" sh "$PUI_T/alm8.sh"
pui_is k3:left [ -x "$PUI_AD/payload.sh" ] && [ ! -e "$PUI_AT" ]
pui_is k3:diff [ "$(diff "$PUI_PL" "$PUI_T/alm7.sh" | grep -c '^<')/$(diff "$PUI_PL" "$PUI_T/alm8.sh" | grep -c '^<')" = 1/1 ]
# i. static: every line of the payload that names the directory (or its renamed twin), read as code (comments and trailing comments dropped, blanks squeezed), is on a pinned list; the
# default path is spelt once; five mutants (a recursive remove of the directory, a second path under the alert tree, a glob remove, and the same recursive and glob removes
# of the renamed twin) are red, the real file is green
pui_alpin() {   # pui_alpin FILE -> 0 iff the lines of FILE that name PL_ALERT_DIR or PL_ALERT_DIS are exactly the pinned ones and the default path is spelt once
  sed -e '/^[[:space:]]*#/d' -e 's/[[:space:]]#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]][[:space:]]*/ /g' "$1" > "$PUI_T/alcode.txt"
  [ "$(grep -c '/root/payloads/alerts' "$PUI_T/alcode.txt")" = 1 ] || return 1
  grep 'PL_ALERT_DI[RS]' "$PUI_T/alcode.txt" > "$PUI_T/alseen.txt"
  cmp -s "$PUI_T/alseen.txt" "$PUI_T/alpin.txt"
}
cat > "$PUI_T/alpin.txt" <<'PUI_ALPIN'
PL_ALERT_DIR=${STARCHORUS_ALERT_TREE:-/root/payloads/alerts}/deauth_flood_detected/starchorus
PL_ALERT_DIS=${PL_ALERT_DIR%/*}/DISABLED.starchorus
pl_alert_on() { [ -f "$PL_ALERT_DIR/payload.sh" ]; }
pl_alert_dis() { [ -f "$PL_ALERT_DIS/payload.sh" ]; }
rm -f "$PL_ALERT_DIR/payload.sh.tmp"
if mkdir -p "$PL_ALERT_DIR" 2>/dev/null && cp "$PL_ALSRC" "$PL_ALERT_DIR/payload.sh.tmp" 2>/dev/null \
&& chmod +x "$PL_ALERT_DIR/payload.sh.tmp" 2>/dev/null && mv -f "$PL_ALERT_DIR/payload.sh.tmp" "$PL_ALERT_DIR/payload.sh" 2>/dev/null; then
rm -f "$PL_ALERT_DIR/payload.sh.tmp"; rmdir "$PL_ALERT_DIR" 2>/dev/null
rm -f "$PL_ALERT_DIR/payload.sh" "$PL_ALERT_DIR/payload.sh.tmp" 2>/dev/null
rmdir "$PL_ALERT_DIR" 2>/dev/null
if pl_alert_dis; then rm -f "$PL_ALERT_DIS/payload.sh" 2>/dev/null; rmdir "$PL_ALERT_DIS" 2>/dev/null; fi
PUI_ALPIN
pui_is i:real pui_alpin "$PUI_PL"
# shellcheck disable=SC2016   # sed programs: the payload's own text, not to be expanded here
sed 's|rmdir "\$PL_ALERT_DIR" 2>/dev/null$|rm -rf "$PL_ALERT_DIR" 2>/dev/null|' "$PUI_PL" > "$PUI_T/alm1.sh"
sed 's|^pl_alert_on() {|PL_ALERT_X=/root/payloads/alerts/other; pl_alert_on() {|' "$PUI_PL" > "$PUI_T/alm2.sh"
# shellcheck disable=SC2016   # (as above)
sed 's|rm -f "\$PL_ALERT_DIR/payload.sh" "\$PL_ALERT_DIR/payload.sh.tmp"|rm -f "$PL_ALERT_DIR/"*|' "$PUI_PL" > "$PUI_T/alm3.sh"
pui_is i:mut1 pui_not pui_alpin "$PUI_T/alm1.sh"
pui_is i:mut2 pui_not pui_alpin "$PUI_T/alm2.sh"
pui_is i:mut3 pui_not pui_alpin "$PUI_T/alm3.sh"
# shellcheck disable=SC2016   # (as above)
sed 's|rmdir "\$PL_ALERT_DIS" 2>/dev/null; fi|rm -rf "$PL_ALERT_DIS" 2>/dev/null; fi|' "$PUI_PL" > "$PUI_T/alm9.sh"
# shellcheck disable=SC2016   # (as above)
sed 's|rm -f "\$PL_ALERT_DIS/payload.sh" 2>/dev/null|rm -f "$PL_ALERT_DIS/"* 2>/dev/null|' "$PUI_PL" > "$PUI_T/alm10.sh"
pui_is i:mut4 pui_not pui_alpin "$PUI_T/alm9.sh"
pui_is i:mut5 pui_not pui_alpin "$PUI_T/alm10.sh"
pui_is i:mutdiff [ "$(cmp -s "$PUI_PL" "$PUI_T/alm1.sh" && echo same; cmp -s "$PUI_PL" "$PUI_T/alm2.sh" && echo same; cmp -s "$PUI_PL" "$PUI_T/alm3.sh" && echo same; cmp -s "$PUI_PL" "$PUI_T/alm9.sh" && echo same; cmp -s "$PUI_PL" "$PUI_T/alm10.sh" && echo same)" = "" ]
# j. the control of the question's text (a:c2): a planted copy of the payload that asks the question as it was worded before (one line differs) asks that and not the
# present one, so the pin of a: would be red for it; it runs from $PUI_T, so _PAYLOAD_HOME says where the companion is
python3 -B - "$PUI_PL" "$PUI_T/alm4.sh" <<'PUI_PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
old = "companion? It may run at\\nonce; switch it off on\\nthe firmware Alerts page."
new = "companion? Manage it on\\nthe firmware's Alerts page."
if s.count(old) != 1:
    sys.exit(1)
open(sys.argv[2], "w", encoding="utf-8").write(s.replace(old, new))
PUI_PY
pui_alnew; pui_ans "=Settings" "=Alerts: OFF" "=1" "!2" "!2"
pui_run_ui "$PUI_ALP" _PAYLOAD_HOME="$R/library/user/reconnaissance/starchorus" sh "$PUI_T/alm4.sh"
pui_is j:old [ "$(pui_x CONFIRMATION_DIALOG "Install the alert\\ncompanion? Manage it on\\nthe firmware's Alerts page.")/$(pui_x CONFIRMATION_DIALOG "Install the alert\\ncompanion? It may run at\\nonce; switch it off on\\nthe firmware Alerts page.")" = 1/0 ]
pui_is j:diff [ "$(diff "$PUI_PL" "$PUI_T/alm4.sh" | grep -c '^<')" = 1 ]
rm -rf "$PUI_T/alerts"
rowif "payload ui: Alerts row: ON/OFF by our file in the alert tree; install after C2 (mkdir -p, cp, chmod +x through a rename: byte-identical, executable, no .tmp, L8f), No installs nothing; Remove after C3 takes our file and our empty directory only (L8g); E13/E14/E15; locked (P2) only while STARCHORUS_ALERTS is set to something but 1, free for 1; a copy the firmware's switch renamed to DISABLED.starchorus reads 'Alerts: OFF (firmware)', a press says P3 and makes no second copy, and Remove takes a stale one of ours too; plain paths touch nothing; every line naming the tree or its renamed twin pinned, five mutants red, planted copies (the question's old wording, no lock, the old lock, no look for the renamed copy, no removal of it) fail the pins they stand for (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 16 · locked rows: a key the environment sets reads "(locked)", A shows P1 naming that variable and writes nothing,
#            the cursor stays; the longest locked label fits 28 characters; Reset asks (C1): No keeps everything and the
#            cursor, Yes deletes the file and puts the cursor on row 1
PUI_BAD=""; pui_new "port=8300" "vendor=off"
pui_ans "=Settings" "=Refresh: 45 s (locked)" "=Reset to Defaults" "!1" "=Reset to Defaults" "=1" "!2" "!2"
pui_run_ui "$PUI_UIP" STARCHORUS_INTERVAL=45 STARCHORUS_MAX_AGE=86399 sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is locked [ "$(pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 45 s (locked)' 'Show Last: 86399 s (locked)' 'Vendor Names: OFF' 'Channel Load: OFF' 'Traffic: OFF' 'Bluetooth: OFF' 'Alerts: OFF' 'Port: 8300' 'Reset to Defaults' 'Refresh: 45 s (locked)')" = 1 ]
pui_is p1 [ "$(pui_x PROMPT 'Set by STARCHORUS_INTERVAL.\nUnset it to change it here.')" = 1 ]
pui_is nosub [ "$(pui_logc '^LIST_PICKER	Refresh: ')" = 0 ]
pui_is c1 [ "$(pui_x CONFIRMATION_DIALOG 'Reset all settings?')" = 2 ]
pui_is nokeeps [ "$(pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 45 s (locked)' 'Show Last: 86399 s (locked)' 'Vendor Names: OFF' 'Channel Load: OFF' 'Traffic: OFF' 'Bluetooth: OFF' 'Alerts: OFF' 'Port: 8300' 'Reset to Defaults' 'Reset to Defaults')" = 1 ]
pui_is reset [ "$(pui_x LIST_PICKER Settings 'Web Page: ON' 'Refresh: 45 s (locked)' 'Show Last: 86399 s (locked)' 'Vendor Names: ON' 'Channel Load: OFF' 'Traffic: OFF' 'Bluetooth: OFF' 'Alerts: OFF' 'Port: 8199' 'Reset to Defaults' 'Web Page: ON')" = 1 ]
pui_is file [ ! -e "$PUI_D/settings.conf" ]
rowif "payload ui: locked rows show P1 and write nothing; Reset asks, No keeps, Yes resets with the cursor on row 1 (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 17 · apply on leaving Settings while RUNNING: a collector key restarts the collector alone under "Applying" (new pid,
#            new value, marker kept), L5, back to RUNNING with the cursor on Settings; a change flipped back applies nothing
PUI_BAD=""; pui_new
pui_ans "=Start" "=Settings" "=Refresh: 30 s" "=1 min" "!2" "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
PUI_CP=$(sed -n 1p "$PUI_D/col.starts" 2>/dev/null); PUI_MK=$(cat "$PUI_T/started" 2>/dev/null)
pui_is rc [ "$PUI_RC" = 0 ]
pui_is restarted [ "$(wc -l < "$PUI_D/col.starts" | tr -d ' ')" = 2 ]
pui_is oldgone pui_gone "${PUI_CP:-0}"
pui_is up pui_up
pui_is value [ "$(pui_env STARCHORUS_INTERVAL)" = 60 ]
pui_is spin [ "$(pui_x START_SPINNER Applying)/$(pui_x LOG blue 'Settings applied.')" = 1/1 ]
pui_is cursor [ "$(pui_x "$PUI_RUN" Overview Stop Settings Settings)" = 1 ]
pui_is noquestion [ "$(pui_logc '^CONFIRMATION_DIALOG')" = 0 ]
PUI_CP=$(pui_cpid)
pui_ans "=Settings" "=Vendor Names: ON" "=Vendor Names: OFF" "!2" "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is flipback [ "$(pui_logc '^START_SPINNER')/$(pui_logc 'Settings applied')/$(wc -l < "$PUI_D/col.starts" | tr -d ' ')" = 0/0/2 ]
pui_is samepid [ "$(pui_cpid)" = "$PUI_CP" ]
pui_is markerkept [ "${PUI_MK:-none}" = "$(cat "$PUI_T/started" 2>/dev/null)" ]
rowif "payload ui: leaving Settings applies a change without a question (Applying, L5, marker kept); a flip-back applies nothing (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 18 · the web page with a server program (stand-in uhttpd): Start serves it (L2) and RUNNING offers "Open on Phone";
#            Web Page OFF while RUNNING stops the server at once (the row goes), ON starts it again (L2); a taken port: E4 and
#            the row stays OFF; "Start Web Page" brings it back and goes on to the QR code; a port change while it runs moves
#            the server; a new port that is taken keeps the old one (E8)
PUI_BAD=""; pui_new "port=18601"
PUI_E4='Web page did not start.\nPort 18601 may be in use.'
pui_ans "=Start" "=Settings" "=Web Page: ON" "!2" "=Settings" "=Web Page: OFF" "!2" "!2"; pui_run_ui "$PUI_PGU" sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is l2 [ "$(pui_x LOG blue 'Web page: 172.16.52.1:18601')" = 3 ]
pui_is phone [ "$(pui_x "$PUI_RUN" Overview 'Open on Phone' Stop Settings Overview)" = 1 ]
pui_is offrow [ "$(pui_x "$PUI_RUN" Overview Stop Settings Settings)" = 1 ]
pui_is onrow [ "$(pui_x "$PUI_RUN" Overview 'Open on Phone' Stop Settings Settings)" = 1 ]
pui_is applying [ "$(pui_x START_SPINNER Applying)/$(pui_logc 'Settings applied')" = 2/0 ]
pui_is url [ "$(sed -n 's/^url=//p' "$PUI_D/display.env" 2>/dev/null)" = 172.16.52.1:18601 ]
pui_is file [ "$(sed -n 's/^page=//p' "$PUI_D/settings.conf")" = on ]
pui_is srv [ "$(pui_srv 18601)" = 1 ]
# a taken port (a listener in the fake net/tcp): Web Page OFF -> ON shows E4, nothing is saved, the row stays OFF
pui_tcp 18601
pui_ans "=Settings" "=Web Page: ON" "=Web Page: OFF" "!2" "!2"; pui_run_ui "$PUI_PGU" sh "$PUI_PL"
pui_is e4 [ "$(pui_x ERROR_DIALOG "$PUI_E4")" = 1 ]
pui_is staysoff [ "$(pui_x LIST_PICKER Settings 'Web Page: OFF' 'Refresh: 30 s' 'Show Last: 1 h' 'Vendor Names: ON' 'Channel Load: OFF' 'Traffic: OFF' 'Bluetooth: OFF' 'Alerts: OFF' 'Port: 18601' 'Reset to Defaults' 'Web Page: OFF')" = 2 ]
pui_is filef [ "$(sed -n 's/^page=//p' "$PUI_D/settings.conf")" = off ]
pui_is srvoff [ "$(pui_asrv 18601)" = 0 ]
# Start with the port still taken: E4 after Start (collecting goes on), RUNNING offers "Start Web Page", which fails the same way
pui_run "$PUI_HL" sh "$PUI_PL" set page on
pui_ans "=Stop" "=Start" "=Start Web Page" "!2"; pui_run_ui "$PUI_PGU" sh "$PUI_PL"
pui_is e4start [ "$(pui_x ERROR_DIALOG "$PUI_E4")/$(pui_x START_SPINNER Starting)" = 2/2 ]
pui_is startrow [ "$(pui_x "$PUI_RUN" Overview 'Start Web Page' Stop Settings Overview)/$(pui_x "$PUI_RUN" Overview 'Start Web Page' Stop Settings 'Start Web Page')" = 2/1 ]
pui_is collecting pui_up
# the port free again: "Start Web Page" serves it and goes on to the QR code; a port change while it runs moves the server (L5)
rm -f "$PUI_T/proc/net/tcp"
pui_ans "=Start Web Page" "=Settings" "=Port: 18601" "=18602" "!2" "!2"; pui_run_ui "$PUI_PGU" sh "$PUI_PL"
pui_is qr [ "$(pui_x PROMPT_QR 'http://172.16.52.1:18601/')/$(pui_x LOG blue 'Web page: 172.16.52.1:18601')" = 1/1 ]
pui_is qrcursor [ "$(pui_x "$PUI_RUN" Overview 'Open on Phone' Stop Settings 'Open on Phone')" = 1 ]
pui_is moved [ "$(pui_x LOG blue 'Settings applied.')/$(pui_srv 18602)/$(pui_asrv 18601)" = 1/1/0 ]
# a new port that is taken: the old one is restored and served again, E8 -- also when the old server is slow to let go of its
# port (its listener stays in the fake net/tcp for 2 s after the stop): the restore waits for the port instead of finding it taken
pui_tcp 18602 18603; ( sleep 2; pui_tcp 18603 ) & PUI_BGJ=$!
pui_ans "=Settings" "=Port: 18602" "=18603" "!2" "!2"; pui_run_ui "$PUI_PGU" sh "$PUI_PL"
wait "$PUI_BGJ"
pui_is e8 [ "$(pui_x ERROR_DIALOG 'Port 18603 is in use.\nKept 18602.')/$(pui_logc 'Settings applied')" = 1/0 ]
pui_is kept [ "$(pui_get port)/$(pui_srv 18602)" = "18602 file/1" ]
rm -f "$PUI_T/proc/net/tcp"
pui_run "$PUI_PGP" sh "$PUI_PL" stop
pui_is stopall [ "$(pui_asrv 18601)$(pui_asrv 18602)$(pui_asrv 18603)" = 000 ]
# `start` over a page server of ours with no collector (STARCHORUS_COLLECTOR=0): the old server is stopped and the new one binds
# the same port, even when the old listener is still in the fake net/tcp for 2 s (the stop returns when the port is free)
pui_new "port=18631"
pui_run "$PUI_PGP" STARCHORUS_COLLECTOR=0 sh "$PUI_PL" start
pui_is once [ "$PUI_RC/$(pui_srv 18631)" = 0/1 ]
pui_tcp 18631; ( sleep 2; rm -f "$PUI_T/proc/net/tcp" ) & PUI_BGJ=$!
pui_run "$PUI_PGP" STARCHORUS_COLLECTOR=0 sh "$PUI_PL" start
wait "$PUI_BGJ"
pui_is again [ "$PUI_RC/$(pui_srv 18631)/$(grep -c 'is in use' "$PUI_T/out")" = 0/1/0 ]
pui_run "$PUI_PGP" sh "$PUI_PL" stop
pui_is stopagain [ "$(pui_asrv 18631)" = 0 ]
rowif "payload ui: web page: L2, Open on Phone, OFF/ON at once, taken port E4 (row stays OFF), Start Web Page, port moves, E8 keeps the old one (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 19 · Open on Phone: PROMPT_QR with the page's address and the three-line message; the argument order read from the
#            command's own text (a usage line names the message first; the first argument lands in QR_DATA), the URL alone
#            when it says nothing; PROMPT with the same text when PROMPT_QR fails; E6 when the page has only 127.0.0.1; the
#            cursor back on the row; L4 names the page
PUI_BAD=""; pui_new "port=18611"
PUI_QM='Scan with a phone that is\non the Pager'"'"'s Wi-Fi.\nhttp://172.16.52.1:18611/'
pui_ans "=Start" "=Open on Phone" "!2"; pui_run_ui "$PUI_PGU" sh "$PUI_PL"
pui_is one [ "$(pui_x PROMPT_QR 'http://172.16.52.1:18611/')" = 1 ]
pui_is cursor [ "$(pui_x "$PUI_RUN" Overview 'Open on Phone' Stop Settings 'Open on Phone')" = 1 ]
pui_is l4 [ "$(pui_x LOG blue 'Web page: 172.16.52.1:18611')/$(grep -n 'Web page:' "$PUI_T/case.log" | tail -n 1 | cut -d: -f1)" = "2/$(wc -l < "$PUI_T/case.log" | tr -d ' ')" ]
pui_ans "=Open on Phone" "!2"; pui_run_ui "$PUI_T/qrm:$PUI_PGU" sh "$PUI_PL"
pui_is message [ "$(pui_x PROMPT_QR "$PUI_QM" 'http://172.16.52.1:18611/')" = 1 ]
pui_ans "=Open on Phone" "!2"; pui_run_ui "$PUI_T/qru:$PUI_PGU" sh "$PUI_PL"
pui_is url [ "$(pui_x PROMPT_QR 'http://172.16.52.1:18611/' "$PUI_QM")" = 1 ]
# a name that holds both a message word and a QR word (QR_MESSAGE="$1", a usage line with <qr_text>) says nothing: the URL alone
for pui_q in qra qrb; do
  pui_ans "=Open on Phone" "!2"; pui_run_ui "$PUI_T/$pui_q:$PUI_PGU" sh "$PUI_PL"
  pui_is "both:$pui_q" [ "$(pui_x PROMPT_QR 'http://172.16.52.1:18611/')/$(pui_logc '^PROMPT_QR')" = 1/1 ]
done
: > "$PUI_T/qr.fail"
pui_ans "=Open on Phone" "!2"; pui_run_ui "$PUI_PGU" sh "$PUI_PL"
pui_is prompt [ "$(pui_x PROMPT "$PUI_QM")" = 1 ]
rm -f "$PUI_T/qr.fail"
# the code left with B (a non-zero exit after a person's time, as the pickers do): that is a dismissal, no second screen
: > "$PUI_T/qr.b"
pui_ans "=Open on Phone" "!2"; pui_run_ui "$PUI_PGU" sh "$PUI_PL"
pui_is dismissed [ "$(pui_x PROMPT_QR 'http://172.16.52.1:18611/')/$(pui_logc '^PROMPT	')/$(pui_x "$PUI_RUN" Overview 'Open on Phone' Stop Settings 'Open on Phone')" = 1/0/1 ]
rm -f "$PUI_T/qr.b"
# no PROMPT_QR on the device at all: PROMPT with the same text
pui_ans "=Open on Phone" "!2"; pui_run_ui "$PUI_T/uino:$PUI_T/srv:$PUI_T/lnb:$PUI_T/bin:$PUI_T/jq:$PUI_T/sys" sh "$PUI_PL"
pui_is absent [ "$(pui_x PROMPT "$PUI_QM")/$(pui_logc '^PROMPT_QR')" = 1/0 ]
pui_run "$PUI_PGP" sh "$PUI_PL" stop
printf '%s\n' "1: lo    inet 127.0.0.1/8 scope host lo" "9: wlan0cli    inet 192.168.77.50/24 scope global wlan0cli" > "$PUI_T/ip.out"
pui_ans "=Start" "=Open on Phone" "!2"; pui_run_ui "$PUI_PGU" sh "$PUI_PL"
pui_is e6 [ "$(pui_x ERROR_DIALOG 'No network address.\nConnect USB-C or Wi-Fi.')/$(pui_logc '^PROMPT_QR')" = 1/0 ]
pui_run "$PUI_PGP" sh "$PUI_PL" stop
printf '%s\n' "$PUI_IPBR" > "$PUI_T/ip.out"
rowif "payload ui: Open on Phone: PROMPT_QR (order probed, URL alone by default), PROMPT fallback, E6, cursor, L4 (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 20 · without jq the Overview row is hidden and Start says E11; a page server without a collector at launch is a
#            leftover: stopped, L9
PUI_BAD=""; pui_new
pui_ans "=Start" "!2"; pui_run_ui "$PUI_NJQ" sh "$PUI_PL"
pui_is e11 [ "$(pui_x ERROR_DIALOG 'Overview needs jq.')/$(pui_x "$PUI_RUN" Stop Settings Stop)" = 1/1 ]
pui_is noov [ ! -e "$PUI_D/display.calls" ]
pui_run "$PUI_HL" sh "$PUI_PL" stop
pui_new "port=18621"
pui_bg "$PUI_T/srv/uhttpd-srv" -p 172.16.52.1:18621 -h "$PUI_D/www"; PUI_SRV=$PUI_BGP
pui_ans "!2"; pui_run_ui "$PUI_PGU" sh "$PUI_PL"
pui_is l9 [ "$(pui_x LOG 'Stopped a leftover web page.')/$(pui_x "$PUI_STOP" Start)" = 1/1 ]
pui_is srvgone pui_gone "$PUI_SRV"
rowif "payload ui: no jq: no Overview row, E11 at Start; a leftover page server is stopped at launch (L9) (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 21 · the Overview contract, on the real starchorus-display.sh. Every press acts at once and means the same everywhere (A = this
#            screen again, B = one level up, Left/Right = the neighbouring screen, Up/Down = nothing). A key wait (WAIT_FOR_INPUT, run as
#            a background child of the key reader, which appends every answer to a queue in a private temp directory and calls it
#            again at once) is open while a screen or `Reading...` is drawn: a press made while none is open is lost, not buffered, and
#            B is then taken by the Pager UI itself (M1 and M2, measured on the device, 16 October 2026). A draw ends for a key that
#            asks for another screen, B, Left or Right (it prints nothing more and ends its jq), and that key is acted on at once; an
#            A, Up or Down leaves it running, and an A that came in it is answered by it: a press at `Reading...` is kept (no settle
#            rule) and a second press there finds the next wait open. The list (LIST_PICKER) is its own wait, and the reader ends
#            itself on the B that opens it. No `timeout` in front of a UI command. When the Overview ends no
#            waiter and no temp directory is left: the reader's pending wait is ended by the exit trap, and a TERM ends the
#            waiter through the reader's traps. The first LOG line is blue Overview (it follows the reader's start, so the stand-in's
#            own WAIT_FOR_INPUT line may come first), then the screen; each screen ends with
#            `Last scan HH:MM:SS (N s ago)` (the red `No new scan for N min.` instead when it is old) and `A: Refresh   B: Back`, the
#            summary also with the page's address; B on a screen opens the list of eight (the default is the screen B came from), B
#            there ends the Overview with exit 0; no own menu; `Reading...` before a screen that runs jq; anything else than the known
#            keys is a strike when its wait ended within a second of being opened, three strikes in a row end it (a slow answer is only
#            waited out and resets the count); SINCE newer than the capture -> "Waiting for the first scan."; the payload gone before
#            a draw -> it ends without a line and without a wait, and the payload gone while it waits -> it ends at that key (the
#            reader's next wait is open by then and the exit ends it; killed then, the payload's stdout still reaches EOF at once); no jq -> E11.
#            The waiter answers in the background, so a row reads the waits as a count (pui_x, pui_used), never as a place in the log.
#            The stand-in answers after the screen is complete unless a row says otherwise (see the header: "i" and "j"), so the
#            draws a row sees are whole and the rows below are deterministic; the rows `armed` and `armed2` are the ones that
#            press during a draw.
PUI_BAD=""; pui_new
PUI_OVP="$PUI_T/ui:$PUI_T/bin:$PUI_T/jq:$PUI_T/sys:$PUI_T/ovx"
PUI_OVS="$PUI_T/ui:$PUI_T/bin:$PUI_T/jqs:$PUI_T/sys:$PUI_T/ovx"     # the same with the jq that takes two seconds to read a capture
PUI_OVPATH=""
PUI_HUB="Overview${PUI_TAB}Summary${PUI_TAB}Strongest Networks${PUI_TAB}Bands & Security${PUI_TAB}Devices & Merges${PUI_TAB}Probe Requests${PUI_TAB}Stations${PUI_TAB}Bluetooth${PUI_TAB}Air Quality"
# the real display, in a clean environment whose TMPDIR is ours (the temp directory of the Overview is then ours to look at and to sweep)
pui_ovrun() { rm -f "$PUI_T/wait.pids" "$PUI_T/jq.waits" "$PUI_T/jq.mode" "$PUI_T/jq.starts" "$PUI_T/jq.started" "$PUI_T/jq.killed"; pui_run_ui "${PUI_OVPATH:-$PUI_OVP}" TMPDIR="$PUI_T/tmp" "$@"; }
pui_lt() { awk -F'\t' -v t="$1" '$1 == "LOG" && $NF == t { n++ } END { print n + 0 }' "$PUI_T/case.log"; }       # LOG lines whose text is exactly $1, any colour
pui_lre() { awk -F'\t' -v re="$1" '$1 == "LOG" && $NF ~ re { n++ } END { print n + 0 }' "$PUI_T/case.log"; }   # LOG lines whose text matches the ERE $1, any colour
pui_tok() {   # pui_tok -> the visible steps of the last run as letters, repeated Reading... lines counted once:
  # O heading Overview, R Reading..., S/C/B/Q the summary's / Stations' / Bluetooth's / Air Quality's block heading, L Last scan, N red No new scan,
  # F key line, U Web page, G Waiting, P the list of eight. No letter for a WAIT_FOR_INPUT: its call comes from a background child
  # that is armed before the draw, so its line may fall anywhere among the draw's lines (the count is pui_x WAIT_FOR_INPUT)
  awk -F'\t' '
    function emit(t) { if (t == "R" && last == "R") return; out = out (out == "" ? "" : " ") t; last = t }
    $1 == "LIST_PICKER" { emit("P"); next }
    $1 != "LOG" { next }
    { t = $NF; c = (NF == 3) ? $2 : ""
      if (c == "blue" && t == "Overview") emit("O")
      else if (t == "Reading...") emit("R")
      else if (c == "blue" && index(t, "Starchorus  ~") == 1) emit("S")
      else if (c == "blue" && index(t, "Stations (GEN ") == 1) emit("C")
      else if (c == "blue" && index(t, "Bluetooth LE (GEN ") == 1) emit("B")
      else if (c == "blue" && index(t, "Air quality (GEN ") == 1) emit("Q")
      else if (c == "red" && index(t, "No new scan for ") == 1) emit("N")
      else if (index(t, "Last scan ") == 1) emit("L")
      else if (t == "A: Refresh   B: Back") emit("F")
      else if (index(t, "Web page: ") == 1) emit("U")
      else if (t == "Waiting for the first scan.") emit("G") }
    END { print out }' "$PUI_T/case.log"
}
pui_nw() { pui_x WAIT_FOR_INPUT; }   # the waits of the last run (a stand-in call each, however it ended)
pui_waiters() { if [ -s "$PUI_T/wait.pids" ]; then wc -l < "$PUI_T/wait.pids" | tr -d ' '; else echo 0; fi; }   # stand-in waiters the last run started
pui_nopids_now() {  # none of the stand-in waiters the last run started is alive right now (one left pending, "z" or "~", would be)
  [ -s "$PUI_T/wait.pids" ] || return 0
  while read -r pui_wp; do ! kill -0 "$pui_wp" 2>/dev/null || return 1; done < "$PUI_T/wait.pids"
}
pui_nopids() {  # the same after a signal: every one of them is gone within 6 s (pui_gone), as the Overview's traps end them
  [ -s "$PUI_T/wait.pids" ] || return 0
  while read -r pui_wp; do pui_gone "$pui_wp" || return 1; done < "$PUI_T/wait.pids"
}
# the main run, on a capture from long ago: B pressed (quickly) once the first screen is complete, the list (Stations), A, Right, Left, B, cancel
pui_ans "q=B" "=Stations" "=A" "=RIGHT" "=LEFT" "=B" "!3"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" STARCHORUS_PAGE_URL=172.16.52.1:8199 sh "$PUI_DS"
pui_is rc [ "$PUI_RC/$(pui_used)/$(pui_nw)" = 0/7/5 ]
pui_is first [ "$(awk -F'\t' '$1 == "LOG" { print; exit }' "$PUI_T/case.log")" = "LOG${PUI_TAB}blue${PUI_TAB}Overview" ]
pui_is list [ "$(pui_x LIST_PICKER Overview Summary 'Strongest Networks' 'Bands & Security' 'Devices & Merges' 'Probe Requests' Stations Bluetooth 'Air Quality' Summary)/$(pui_x LIST_PICKER Overview Summary 'Strongest Networks' 'Bands & Security' 'Devices & Merges' 'Probe Requests' Stations Bluetooth 'Air Quality' Stations)" = 1/1 ]
pui_is footer [ "$(pui_lt 'A: Refresh   B: Back')/$(pui_lt 'Web page: 172.16.52.1:8199')" = 5/1 ]
pui_is views [ "$(pui_logc '^LOG	blue	Starchorus  ~')/$(pui_logc '^LOG	blue	Stations (GEN ')/$(pui_logc '^LOG	blue	Bluetooth LE (GEN ')/$(pui_logc 'B: back\|A: screens\|B: menu')" = 1/3/1/0 ]   # RIGHT from Stations is Bluetooth
pui_is stale [ "$(pui_logc '^LOG	red	No new scan for [0-9]* [a-z]*\.$')/$(pui_lre '^Last scan ')" = 5/0 ]
pui_is keys [ "$(pui_tok)" = "O R S N F U P R C N F C N F R B N F C N F P" ]
pui_is reading [ "$(awk -F'\t' '$1 == "LOG" { t = $NF; if (index(t, "Starchorus  ~") == 1 || index(t, "Stations (GEN ") == 1 || index(t, "Bluetooth LE (GEN ") == 1) printf "%s%d", (n++ ? " " : ""), (prev == "Reading..."); prev = t } END { print "" }' "$PUI_T/case.log")" = "1 1 0 1 0" ]
pui_is nomenu [ "$(grep -ci 'dashboard\|bye\|Collector\|Exit' "$PUI_T/case.log")/$(pui_logc '^LIST_PICKER')/$(pui_logc "^LIST_PICKER${PUI_TAB}$PUI_HUB${PUI_TAB}")/$(awk -F'\t' '$1 ~ /^(NUMBER_PICKER|CONFIRMATION_DIALOG|ERROR_DIALOG|PROMPT|PROMPT_QR|START_SPINNER|STOP_SPINNER)$/ { n++ } END { print n + 0 }' "$PUI_T/case.log")" = 0/2/2/0 ]
# the eight screens, on a capture that has Bluetooth (the radio-pair fixture): the Bluetooth screen sits between Stations and Air
# Quality: eight RIGHT presses from the summary are top, bands, devices, probes, stations, Bluetooth, air, summary; the summary and, after LEFT,
# air come again from the cache (no `Reading...`), and B opens the list with the cursor on air. The Bluetooth block is drawn whole: heading, count line, at most 12 lines with the frame, none over 40 columns
PUI_NOFIX=
if [ -s "$F/radio-pair.json" ]; then
pui_ans "=RIGHT" "=RIGHT" "=RIGHT" "=RIGHT" "=RIGHT" "=RIGHT" "=RIGHT" "=RIGHT" "=LEFT" "=B" "!3"
pui_ovrun STARCHORUS_JSON="$F/radio-pair.json" sh "$PUI_DS"
PUI_BB=$(awk -F'\t' '$1 == "LOG" { t = $NF; if (index(t, "Bluetooth LE (GEN ") == 1) f = 1; if (f) { n++; if (length(t) > 40) w++ }
  if (f && t == "A: Refresh   B: Back") { print n + 0 "/" w + 0; exit } }' "$PUI_T/case.log")
PUI_BN=${PUI_BB%/*}
pui_is walk [ "$PUI_RC/$(pui_used)/$(pui_nw)/$(pui_tok)" = "0/11/10/O R S N F R N F R N F R N F R N F R C N F R B N F R Q N F S N F Q N F P" ]
pui_is walkcursor [ "$(pui_x LIST_PICKER Overview Summary 'Strongest Networks' 'Bands & Security' 'Devices & Merges' 'Probe Requests' Stations Bluetooth 'Air Quality' 'Air Quality')" = 1 ]
pui_is btblock [ "${PUI_BB#*/}/$((${PUI_BN:-0} >= 5 && ${PUI_BN:-0} <= 12))" = 0/1 ]
pui_is btfigures [ "$(pui_lt '9 addresses (7 rotating, 2 fixed)')/$(pui_logc '^LOG	blue	Bluetooth LE (GEN [0-9]*)  rx only$')" = 1/1 ]
else PUI_NOFIX=1; fi   # tests/fixtures/radio-pair.json comes with the page track: until then these four are NOT COVERED (below), and the parity drop-in is red for its absence
# a capture without the array: the two lines, the setting is off (or the collector older)
pui_ans "=RIGHT" "=RIGHT" "=RIGHT" "=RIGHT" "=RIGHT" "=RIGHT" "=B" "!3"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" sh "$PUI_DS"
pui_is btoff [ "$PUI_RC/$(pui_lt 'No Bluetooth in this scan.')/$(pui_lt 'Turn it on in Settings > Bluetooth.')/$(pui_lt 'Strongest by company (last 2 min):')" = 0/1/1/0 ]
# a capture that is fresh: the age line, not the red one (the time is the capture's, in UTC)
PUI_G=$(date +%s); PUI_GT=$(jq -n -r --argjson g "$PUI_G" '$g | strftime("%H:%M:%S")')
jq --argjson g "$PUI_G" '.generated = $g' "$F/field-probes.json" > "$PUI_T/fresh.json"
pui_ans "q=B" "!3"
pui_ovrun STARCHORUS_JSON="$PUI_T/fresh.json" sh "$PUI_DS"
pui_is fresh [ "$PUI_RC/$(pui_lre "^Last scan $PUI_GT [(][0-9]+ s ago[)]\$")/$(pui_logc 'No new scan')/$(pui_tok)" = "0/1/0/O R S L F P" ]
# open before the draw, and a draw ends only for a key that asks for another screen. A jq that takes two seconds to read the capture (the stand-in under
# PUI_OVS) finds the key reader's wait already open, and the answer ("j": a press at `Reading...`, made the moment that jq has started) is taken with no
# settle rule and nothing dropped: A. The draw it came in goes on (0.1.1 ended it and drew the screen again): its jq is not ended (no jq.killed, one
# line of jq.starts), the screen is drawn whole once, and the A is answered by that draw; the B after it, pressed once the screen is complete, opens the
# list. The reader's second wait was open while the jq slept (jq.waits). The temp directory of the Overview, which exists by then, is private (drwx------).
PUI_OVPATH=$PUI_OVS
pui_ans "j=A" "=B" "!3"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" sh "$PUI_DS"
PUI_OVPATH=""
pui_is armed [ "$PUI_RC/$(pui_used)/$(pui_nw)/$(pui_lt Reading...)/$(pui_logc '^LOG	blue	Starchorus  ~')/$(pui_logc '^LOG	A: Refresh   B: Back$')/$(pui_logc '^LIST_PICKER')/$(pui_lt 'Waiting for the first scan.')" = "0/3/2/1/1/1/1/0" ]
pui_is armedjq [ "$(wc -l < "$PUI_T/jq.starts" | tr -d ' ')/$([ -e "$PUI_T/jq.killed" ] && echo killed)/$(wc -l < "$PUI_T/jq.waits" | tr -d ' ')/$(awk '{ print ($1 >= 2) ? "open" : "none" }' "$PUI_T/jq.waits")" = "1//1/open" ]
pui_is tmpmode [ "$(sort -u "$PUI_T/jq.mode" 2>/dev/null)" = "drwx------" ]
# B at `Reading...` opens the list at once: the draw ends, the jq is ended, nothing is drawn that screen, and the picker's cancel ends it
PUI_OVPATH=$PUI_OVS
pui_ans "j=B" "!3"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" sh "$PUI_DS"
PUI_OVPATH=""
pui_is armed2 [ "$PUI_RC/$(pui_used)/$(pui_nw)/$(pui_logc '^LOG	blue	Starchorus  ~')/$(pui_logc '^LOG	A: Refresh   B: Back$')/$(pui_logc '^LIST_PICKER')/$(wc -l < "$PUI_T/jq.starts" | tr -d ' ')/$([ -e "$PUI_T/jq.killed" ] && echo killed)/$(pui_lt 'Waiting for the first scan.')" = "0/2/1/0/0/1/1/killed/0" ]
# Up and Down are the console's own: six of them in a row change nothing, draw nothing, are no strikes, and the reader's next wait is open
# already (the B after them still opens the list)
pui_ans "=UP" "=DOWN" "=UP" "=DOWN" "=UP" "=DOWN" "=B" "!3"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" sh "$PUI_DS"
pui_is updown [ "$PUI_RC/$(pui_used)/$(pui_nw)/$(pui_tok)" = "0/8/7/O R S N F P" ]
# anything else than the known keys is a strike when its wait ended within a second of being opened (the fake clock: a queued answer, "q",
# takes 0.2 s), and three of them in a row end the Overview with exit 0, never a busy loop: unknown words, and empty answers (a UI that
# has gone gives those). Three waits, one draw, the list never opened; the fourth answer is never asked for.
pui_ans "q=X" "q=Y" "q=Z" "=B" "!3"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" sh "$PUI_DS"
pui_is strikes [ "$PUI_RC/$(pui_used)/$(pui_nw)/$(pui_logc '^LIST_PICKER')/$(pui_tok)" = "0/3/3/0/O R S N F" ]
pui_ans "q" "q" "q" "=B" "!3"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" sh "$PUI_DS"
pui_is strikesq [ "$PUI_RC/$(pui_used)/$(pui_nw)/$(pui_logc '^LIST_PICKER')/$(pui_tok)" = "0/3/3/0/O R S N F" ]
# the same answers after a real wait (5 s of the fake clock each: a UI that took its time, not a broken key path) are no strikes: four
# empty ones and an unknown word in a row change nothing, and the B after them still opens the list (the picker's cancel ends it)
pui_ans "=A" "" "" "" "=X" "" "=B" "!3"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" sh "$PUI_DS"
pui_is strikesslow [ "$PUI_RC/$(pui_used)/$(pui_nw)/$(pui_tok)" = "0/8/7/O R S N F S N F P" ]
# SINCE newer than the capture: the waiting line, no block, no age line, the key line; the second draw reads nothing again
pui_ans "=A" "=B"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" STARCHORUS_SINCE=9999999999 sh "$PUI_DS"
pui_is waiting [ "$PUI_RC/$(pui_lt 'Waiting for the first scan.')/$(pui_logc 'No new scan')/$(pui_logc 'Last scan')/$(pui_logc 'APs ')/$(pui_tok)" = "0/2/0/0/0/O R G F G F P" ]
# the payload gone before the first draw: nothing is drawn, not even the heading, and no wait is opened (parent_gone comes first); the
# payload gone while the Overview waits ("x" in the answer ends it just before the key comes): it ends at that key and draws nothing
# more; the reader had opened its next wait by then (two waits, the second never answered), and the exit ends it: none is left alive
( sh -c 'exit 0' & echo $! > "$PUI_T/dead.pid" ); sleep 1
pui_ans "=A"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" STARCHORUS_PARENT_PID="$(cat "$PUI_T/dead.pid")" sh "$PUI_DS"
pui_is orphan [ "$PUI_RC/$(wc -l < "$PUI_T/case.log" | tr -d ' ')/$(pui_used)" = 0/0/0 ]
( sleep 60 >/dev/null 2>&1 & echo $! > "$PUI_T/parent.pid" )
pui_ans "x=A" "=A"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" STARCHORUS_PARENT_PID="$(cat "$PUI_T/parent.pid")" sh "$PUI_DS"
pui_okt="$PUI_RC/$(pui_used)/$(pui_nw)/$(pui_tok)"   # the tuple is kept, so that a red row names what diverged (it flickered under full load, twice in about 14 runs)
pui_is orphankey [ "$pui_okt" = "0/2/2/O R S N F" ]; [ "$pui_okt" = "0/2/2/O R S N F" ] || PUI_BAD="$PUI_BAD(got $pui_okt)"
pui_is "orphankey:gone" pui_nopids
kill "$(cat "$PUI_T/parent.pid")" 2>/dev/null
# no waiter left behind. A stand-in waiter that blocks for 4 s ("z") stands for one that would still be pending: after three strikes,
# and after B and a cancelled list, the Overview ends without ever asking for the next wait, so every waiter it started has ended
# by then (looked at the moment it has gone, not after a grace)
pui_ans "q" "q" "q" "z"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" sh "$PUI_DS"
pui_is "nopending:strikes" [ "$PUI_RC/$(pui_used)/$(pui_waiters)" = 0/3/3 ]
pui_is "nopending:strikes:gone" pui_nopids_now
pui_ans "q=B" "!3" "z"
pui_ovrun STARCHORUS_JSON="$F/field-probes.json" sh "$PUI_DS"
pui_is "nopending:hub" [ "$PUI_RC/$(pui_used)/$(pui_waiters)" = 0/2/1 ]
pui_is "nopending:hub:gone" pui_nopids_now
pui_kd "$PUI_T/ui/"
pui_is tmpdir [ -z "$(ls -A "$PUI_T/tmp")" ]
# the same under a TERM while a waiter is pending ("~"): once the first screen has been drawn (its last line is out, and the waiter,
# armed before the draw, has been blocked since) the Overview is sent a TERM; it ends within seconds, its waiter is gone with it
# and so is its temp directory. Under every shell the runner has (dash does not run an EXIT trap for a signal that no TERM trap
# turns into an exit; bash does): the waiter is not the Overview's own child but the child of a subshell, so what the traps kill has
# to reach it.
for pui_sh in $PUI_SH; do
  pui_ans "~"
  rm -f "$PUI_T/wait.pids"
  pui_term "$PUI_LOG" "LOG${PUI_TAB}A: Refresh" "$PUI_OVP" TMPDIR="$PUI_T/tmp" STARCHORUS_JSON="$F/field-probes.json" "$pui_sh" "$PUI_DS"
  pui_is "nopending:term:ended:$pui_sh" [ "$PUI_TRC" != 124 ]
  pui_is "nopending:term:armed:$pui_sh" [ "$(pui_waiters)" = 1 ]
  pui_is "nopending:term:$pui_sh" pui_nopids
  pui_is "tmpdir:term:$pui_sh" [ -z "$(ls -A "$PUI_T/tmp")" ]
  pui_kd "$PUI_T/ui/"
done
# the payload killed (TERM, to the payload only) while the REAL Overview waits for a key, on a WAIT_FOR_INPUT that blocks ("~": nobody presses
# one): the payload's stdout, a pipe as the payload runner's is, must reach EOF within a few seconds. The Overview checks the payload's pid
# only when a key has been taken, so it outlives the payload; if it still held the payload's stdout or stderr (its background waiter included), the runner
# would wait for the pipe until somebody pressed a key. (The stand-in Overview of the rows above returns or sleeps without a pipe of the
# payload; this one is the real one.) The TERM goes out once the frame, the last line of the first draw, is on the console.
for pui_sh in $PUI_SH; do
  pui_new; cp "$PUI_DS" "$PUI_D/starchorus-display.sh"
  pui_ans "=Start" "~"; pui_eof "$PUI_LOG" "LOG${PUI_TAB}A: Refresh" "$PUI_OVP" TMPDIR="$PUI_T/tmp" "$pui_sh" "$PUI_PL"
  pui_is "ovpipe:$pui_sh" [ "$PUI_ERC/$(pui_x WAIT_FOR_INPUT)/$(pui_x STOP_SPINNER 7)" = 0/1/1 ]
  pui_is "ovpipefast:$pui_sh" [ "${PUI_EDT%.*}" -le 3 ]
  pui_run "$PUI_HL" sh "$PUI_PL" stop
done
pui_run_ui "$PUI_NJQ" STARCHORUS_JSON="$F/field-probes.json" sh "$PUI_DS"
pui_is nojq [ "$PUI_RC/$(sed -n 1p "$PUI_T/case.log")/$(pui_x ERROR_DIALOG 'Overview needs jq.')" = "1/LOG${PUI_TAB}blue${PUI_TAB}Overview/1" ]
# no `timeout` in front of a UI command, in either copy and in any run above (jq may run under one: it is no UI client)
PUI_UIW='WAIT_FOR_INPUT|LIST_PICKER|NUMBER_PICKER|CONFIRMATION_DIALOG|ERROR_DIALOG|PROMPT|PROMPT_QR|START_SPINNER|STOP_SPINNER|LOG'
pui_is notimeout [ "$(sed -e '/^[[:space:]]*#/d' -e 's/[[:space:]]#.*//' "$PUI_DS" "$R/library/user/reconnaissance/starchorus/starchorus-display.sh" | grep -cE "(^|[^A-Za-z_])timeout[^|;&]*($PUI_UIW)([^A-Za-z_]|\$)")/$(cat "$PUI_T/timeout.log" 2>/dev/null | awk -F'\t' -v w="^($PUI_UIW)\$" '$2 ~ w { n++ } END { print n + 0 }')" = 0/0 ]
# the settle rule is gone from both copies, comments included (nothing is buffered, so there is nothing to settle)
pui_is nosettlecode [ "$(cat "$PUI_DS" "$R/library/user/reconnaissance/starchorus/starchorus-display.sh" | grep -c 'SETTLE')" = 0 ]
rowif "payload ui: Overview contract: first line, one footer, hub of eight (Bluetooth between Stations and Air Quality), the Bluetooth screen, A/B/Left/Right, Up/Down nothing, the key reader's wait open before the draw and kept open through it, an A at Reading... answered by the draw, no settle rule, strikes, red stale line, waiting, no timeout, no waiter or temp dir left behind, orphan, payload stdout free after a TERM, E11 (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]
[ -z "$PUI_NOFIX" ] || notcov "payload ui: the eight screens walked on radio-pair, the Bluetooth screen whole (needs tests/fixtures/radio-pair.json)"

# ---- 22 · bind: set/get/reset like port; refusals (0.0.0.0 included: every interface is spelt `all`); the environment
#           beats the file, an invalid environment value falls back to the file (never to all) with a note
PUI_BAD=""; pui_new
pui_is default [ "$(pui_get bind)" = "auto default" ]
for pui_v in 10.0.0.7 172.16.52.1 all auto 255.255.255.255; do
  pui_run "$PUI_HL" sh "$PUI_PL" set bind "$pui_v"
  pui_is "set:$pui_v" [ "$PUI_RC" = 0 ]
  pui_is "get:$pui_v" [ "$(pui_get bind)" = "$pui_v file" ]
done
cp "$PUI_D/settings.conf" "$PUI_T/before.conf"
for pui_v in 0.0.0.0 256.1.1.1 01.2.3.4 1.2.3 1.2.3.4.5 ::1 ALL Auto "10.0.0.7 " "" localhost 1.2.3.4:80; do
  pui_run "$PUI_HL" sh "$PUI_PL" set bind "$pui_v"
  pui_is "refuse:[$pui_v]" [ "$PUI_RC" = 2 ]
done
pui_is unchanged cmp -s "$PUI_T/before.conf" "$PUI_D/settings.conf"
pui_new "bind=10.0.0.7" "bind=0.0.0.0"
pui_is lastvalid [ "$(pui_get bind)" = "10.0.0.7 file" ]
pui_run "$PUI_HL" STARCHORUS_BIND=10.9.8.7 sh "$PUI_PL" get bind
pui_is env [ "$(cat "$PUI_T/out")" = "bind=10.9.8.7 (env)" ]
pui_run "$PUI_HL" STARCHORUS_BIND=0.0.0.0 sh "$PUI_PL" get bind
pui_is badenv [ "$(grep -c '^bind=10.0.0.7 (file)$' "$PUI_T/out")/$(grep -c 'STARCHORUS_BIND ignored' "$PUI_T/out")" = 1/1 ]
pui_run "$PUI_HL" STARCHORUS_BIND= sh "$PUI_PL" get bind
pui_is emptyenv [ "$(cat "$PUI_T/out")" = "bind=10.0.0.7 (file)" ]
pui_run "$PUI_HL" STARCHORUS_BIND=all sh "$PUI_PL" reset
pui_run "$PUI_HL" sh "$PUI_PL" get bind
pui_is reset [ "$(cat "$PUI_T/out")" = "bind=auto (default)" ]
pui_is nocol pui_nocol
rowif "payload ui: bind set/get/reset, 0.0.0.0 and malformed addresses refused, env beats file, bad env falls back (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 23 · page on the configured port: status sees it, stop ends it and the collector, a server on another port stays;
#            a port change while the page runs does not orphan the old server (page.port)
PUI_BAD=""; pui_new "port=18299"
pui_bg "$PUI_T/decoy/uhttpd" -p 80 -h /www; PUI_DEC=$PUI_BGP
pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is started pui_col
PUI_SRV=$(pui_wsrv 172.16.52.1:18299 | tr '\n' ' ' | sed 's/ $//')
pui_is srv [ -n "$PUI_SRV" ]
pui_run "$PUI_PGP" sh "$PUI_PL" status
pui_is status [ "$(grep -c '^Page: 172.16.52.1:18299 running$' "$PUI_T/out")/$(grep -c '^loop RUNNING (pid [0-9]*)$' "$PUI_T/out")/$(grep -c 'starchorus\]' "$PUI_T/out")" = 1/1/0 ]
pui_run "$PUI_PGP" sh "$PUI_PL" set port 18300
pui_run "$PUI_PGP" sh "$PUI_PL" status
pui_is statusrun [ "$(grep -c '^Page: 172.16.52.1:18299 running$' "$PUI_T/out")" = 1 ]
PUI_CP=$(pui_cpid)
pui_run "$PUI_PGP" sh "$PUI_PL" stop
for pui_p in $PUI_SRV ${PUI_CP:-0}; do pui_is "gone:$pui_p" pui_gone "$pui_p"; done
pui_is decoy kill -0 "$PUI_DEC"
pui_is portfilegone pui_no "$PUI_D/page.port" "$PUI_D/page.addr"
pui_run "$PUI_PGP" sh "$PUI_PL" status
pui_is down [ "$(grep -c '^Page: 172.16.52.1:18300 not running$' "$PUI_T/out")" = 1 ]
pui_run "$PUI_PGP" sh "$PUI_PL" set page off
pui_run "$PUI_PGP" sh "$PUI_PL" status
pui_is off [ "$(grep -c '^Page: off$' "$PUI_T/out")" = 1 ]
kill "$PUI_DEC" 2>/dev/null
rowif "payload ui: page on its port: status, a port change keeps the old server reachable, stop ends only ours (server ${PUI_SRV:-none}; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 24 · stop matches only OUR own -p [ADDR:]PORT -h our-dir server: a server on the same port (bare or with the same
#           address) with a different -h directory (the device's own uhttpd), and the port sitting in a non-listening
#           argument, all survive; an older server of ours on the bare -p PORT form is stopped too, and O1 (-h of the whole
#           directory) is a server of the build before, which stop ends as well (the new ones are given <dir>/www)
PUI_BAD=""; pui_new "port=18401"
pui_bg "$PUI_T/decoy/uhttpd" -p 18401 -h /www; PUI_D1=$PUI_BGP
pui_bg "$PUI_T/decoy/uhttpd" -p 80 -h /www 18401; PUI_D2=$PUI_BGP
pui_bg "$PUI_T/decoy/uhttpd" -p 172.16.52.1:18401 -h /www; PUI_D3=$PUI_BGP
pui_bg "$PUI_T/srv/uhttpd-srv" -p 18401 -h "$PUI_D"; PUI_O1=$PUI_BGP
pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is started pui_col
PUI_SRV=$(pui_wsrv 172.16.52.1:18401 | tr '\n' ' ' | sed 's/ $//')
pui_is srv [ -n "$PUI_SRV" ]
pui_run "$PUI_PGP" sh "$PUI_PL" stop
for pui_p in $PUI_SRV "$PUI_O1"; do pui_is "gone:$pui_p" pui_gone "$pui_p"; done
pui_is samedir kill -0 "$PUI_D1"
pui_is strayarg kill -0 "$PUI_D2"
pui_is sameaddr kill -0 "$PUI_D3"
kill "$PUI_D1" "$PUI_D2" "$PUI_D3" "$PUI_O1" 2>/dev/null
rowif "payload ui: stop needs -p [ADDR:]PORT AND -h our-dir; same-port/same-address other-dir and stray-arg servers survive (server ${PUI_SRV:-none}; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 25 · bind at start: the page server listens on br-lan's address by default (stand-in ip), an explicit address, or
#           0.0.0.0 only for all; without br-lan 172.16.52.1 when configured, else 127.0.0.1 with a note; the hint, page.addr
#           and Status name the real address, and stop ends each one
PUI_BAD=""
pui_bindcase() {   # pui_bindcase LABEL EXPECTED-ADDR [settings line] -> start, check args/hint/status, stop
  if [ -n "${3:-}" ]; then pui_new "port=18501" "$3"; else pui_new "port=18501"; fi
  [ "${4:-}" = nobr ] && printf '%s\n' "1: lo    inet 127.0.0.1/8 scope host lo" "4: eth1    inet 172.16.52.1/24 scope global eth1" > "$PUI_T/ip.out"
  [ "${4:-}" = lo ] && printf '%s\n' "1: lo    inet 127.0.0.1/8 scope host lo" "9: wlan0cli    inet 192.168.77.50/24 scope global wlan0cli" > "$PUI_T/ip.out"
  pui_run "$PUI_PGP" sh "$PUI_PL"
  pui_is "$1:started" pui_col
  pui_bs=$(pui_wsrv "$2:18501" | tr '\n' ' ')
  pui_is "$1:args" [ -n "$pui_bs" ]
  pui_is "$1:any" [ "$(pui_nsrv)" = 1/1 ]
  pui_is "$1:addrfile" [ "$(cat "$PUI_D/page.addr" 2>/dev/null)" = "$2" ]
  if [ "$2" = 0.0.0.0 ]; then pui_is "$1:hint" grep -q 'http://<device-ip>:18501/ (all interfaces)' "$PUI_T/out"
  else pui_is "$1:hint" grep -q "http://$2:18501/" "$PUI_T/out"; fi
  [ "$2" = 127.0.0.1 ] && pui_is "$1:note" [ "$(grep -c '127.0.0.1 only' "$PUI_T/out")" = 1 ]
  [ "$1" = default ] && pui_is "$1:quiet" [ "$(grep -c 'note' "$PUI_T/out")" = 0 ]
  pui_run "$PUI_PGP" sh "$PUI_PL" status
  pui_is "$1:status" [ "$(grep -c "^Page: $2:18501 running$" "$PUI_T/out")" = 1 ]
  pui_bc=$(pui_cpid)
  pui_run "$PUI_PGP" sh "$PUI_PL" stop
  for pui_p in $pui_bs ${pui_bc:-0}; do pui_is "$1:gone" pui_gone "$pui_p"; done
}
pui_bindcase default 172.16.52.1
pui_bindcase explicit 10.0.0.7 "bind=10.0.0.7"
pui_bindcase all 0.0.0.0 "bind=all"
pui_bindcase nobr 172.16.52.1 "" nobr
pui_bindcase lo 127.0.0.1 "" lo
printf '%s\n' "$PUI_IPBR" > "$PUI_T/ip.out"
rowif "payload ui: bind at start: br-lan by default, explicit, all = 0.0.0.0, 172.16.52.1 / 127.0.0.1 fallbacks; hint, page.addr, status (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 26 · BUNDLE: a self-contained payload directory (tools/hak5-package.sh) installs itself into an empty STARCHORUS_DIR on
#           the first run (files byte-identical, scripts made executable even from 0644 sources, a note on stderr, the
#           settings file in STARCHORUS_DIR, the collector started from there); a second run copies nothing; an installed
#           collector is never overwritten; _PAYLOAD_HOME names the directory when the payload runs from elsewhere; a bundle
#           without index.html, or the same directory, copies nothing; a failed copy leaves no collector and exits 1; on the
#           device the note is one LOG line. The repo's own payload directory (no collector in it) is the install route of
#           every case above.
PUI_BAD=""; PUI_B="$PUI_T/bundle"
pui_bundle() {   # pui_bundle [index] -> a fresh bundle dir (payload + stand-ins, 0644) and an absent STARCHORUS_DIR
  pui_kd "$PUI_D/"; rm -rf "$PUI_D" "$PUI_B"; mkdir -p "$PUI_B"
  cp "$PUI_PL" "$PUI_T/tpl/starchorus-collect.sh" "$PUI_T/tpl/starchorus-display.sh" "$PUI_B/"
  printf '#!/bin/sh\n# stand-in netcat server\nexit 0\n' > "$PUI_B/starchorus-serve.sh"
  [ "${1:-index}" = index ] && printf '<!doctype html><title>stand-in page</title>\n' > "$PUI_B/index.html"
  chmod 644 "$PUI_B/"*
  : > "$PUI_LOG"; : > "$PUI_ANS"; rm -f "$PUI_ANS.n"
}
pui_xall() { for pui_f in starchorus-collect.sh starchorus-display.sh starchorus-serve.sh; do [ -x "$PUI_D/$pui_f" ] || return 1; done; }
pui_same() { for pui_f in index.html starchorus-collect.sh starchorus-display.sh starchorus-serve.sh; do cmp -s "$PUI_B/$pui_f" "$PUI_D/$pui_f" || return 1; done; }
pui_bundle; pui_run "$PUI_HL" sh "$PUI_B/payload.sh" set port 8300
pui_is first:rc [ "$PUI_RC" = 0 ]
pui_is first:same pui_same
pui_is first:exec pui_xall
pui_is first:note [ "$(grep -c "^Starchorus: installed from $PUI_B into $PUI_D\$" "$PUI_T/out")" = 1 ]
pui_is first:settings [ "$(cat "$PUI_D/settings.conf" 2>/dev/null)/$(find "$PUI_B" -name 'settings*' | wc -l | tr -d ' ')" = "port=8300/0" ]
pui_is first:notmp [ "$(find "$PUI_D" -name '*.tmp' | wc -l | tr -d ' ')" = 0 ]
pui_run "$PUI_HL" sh "$PUI_B/payload.sh"
pui_is start:col pui_col
pui_is start:port [ "$(pui_env STARCHORUS_PORT)/$(pui_env STARCHORUS_OUTDIR)" = "8300/$PUI_D" ]
pui_is start:quiet [ "$(grep -c 'installed from' "$PUI_T/out")" = 0 ]
pui_run "$PUI_HL" sh "$PUI_B/payload.sh" stop
printf '# installed by hand\n' >> "$PUI_D/starchorus-collect.sh"; cp "$PUI_D/starchorus-collect.sh" "$PUI_T/inst.sh"
printf '<!-- newer -->\n' >> "$PUI_B/index.html"
pui_run "$PUI_HL" sh "$PUI_B/payload.sh" get port
pui_is keep:collector cmp -s "$PUI_T/inst.sh" "$PUI_D/starchorus-collect.sh"
pui_is keep:page [ "$(grep -c newer "$PUI_D/index.html")" = 0 ]
pui_is keep:get [ "$(cat "$PUI_T/out")" = "port=8300 (file)" ]
pui_bundle; mkdir -p "$PUI_T/elsewhere"; cp "$PUI_PL" "$PUI_T/elsewhere/payload.sh"
pui_run "$PUI_HL" _PAYLOAD_HOME="$PUI_B" sh "$PUI_T/elsewhere/payload.sh" get port
pui_is home:rc [ "$PUI_RC" = 0 ]
pui_is home:same pui_same
pui_bundle noindex; pui_run "$PUI_HL" sh "$PUI_B/payload.sh" get port
pui_is noindex [ "$PUI_RC/$(grep -c 'not installed' "$PUI_T/out")/$(find "$PUI_D" -type f 2>/dev/null | wc -l | tr -d ' ')" = 1/1/0 ]
pui_bundle; pui_run "$PUI_HL" STARCHORUS_DIR="$PUI_B" sh "$PUI_B/payload.sh" get port
pui_is samedir [ "$(grep -c 'installed from' "$PUI_T/out")/$(find "$PUI_B" -name '*.tmp' | wc -l | tr -d ' ')" = 0/0 ]
pui_bundle; : > "$PUI_D"
pui_run "$PUI_HL" sh "$PUI_B/payload.sh" get port
pui_is fail [ "$PUI_RC/$(grep -c 'could not copy' "$PUI_T/out")/$(grep -c 'not installed' "$PUI_T/out")" = 1/1/1 ]
rm -f "$PUI_D"
pui_bundle; pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_B/payload.sh"
pui_is dev:log [ "$PUI_RC/$(pui_logc '^LOG	Installed$')" = 0/1 ]
pui_is dev:same pui_same
# an older collector left in STARCHORUS_DIR (a bundle updated on its own): the dialogue names the file to delete, as there is
# no tools/ on the device in this layout; the files are not touched, and the installer's remedy is the repo layout's
printf '# Version: 0.0.9\n' >> "$PUI_D/starchorus-collect.sh"; cp "$PUI_D/starchorus-collect.sh" "$PUI_T/inst.sh"
pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_B/payload.sh"
pui_is dev:skew [ "$(pui_x ERROR_DIALOG "Installed 0.0.9, payload $PUI_VER.\\nDelete starchorus-collect.sh\\nin $PUI_D.")/$(pui_logc 'tools/install.sh')" = 1/0 ]
pui_is dev:kept cmp -s "$PUI_T/inst.sh" "$PUI_D/starchorus-collect.sh"
rm -f "$PUI_D/starchorus-collect.sh"
pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_B/payload.sh"
pui_is dev:retake [ "$(pui_logc '^ERROR_DIALOG')/$(pui_logc '^LOG	Installed$')" = 0/1 ]
rowif "payload ui: bundle installs itself once into an empty dir, never over an installed collector; a stale one is named, not replaced (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 27 · static: no active-scan path, the file is never sourced, the collector reads no settings file, POSIX-clean; every
# picker title and row of the runs above within 28 characters (the device shows that many), ASCII only, the spinners one word,
# with a floor and every menu seen
PUI_BAD=""
pui_is active [ "$(grep -cE 'ALLOW_ACTIVE|iwscan' "$PUI_PL")" = 0 ]
pui_is source [ "$(sed -e '/^[[:space:]]*#/d' -e 's/[[:space:]]#.*//' "$PUI_PL" | grep -cE '(^|[;&|({[:space:]])(\.|source|eval)[[:space:]]')" = 0 ]
pui_is collector [ "$(grep -c 'settings\.conf' starchorus-collect.sh)" = 0 ]
pui_is noexec [ "$(grep -cE '(^|[;&|[:space:]])exec[[:space:]].*starchorus-display' "$PUI_PL")" = 0 ]
pui_is shn sh -n "$PUI_PL"
pui_is scsh shellcheck -s sh "$PUI_PL"
PUI_LEN=$(awk -F'\t' '$1 == "LIST_PICKER" || $1 == "NUMBER_PICKER" { n++; for (i = 2; i <= NF; i++) if (length($i) > 28) { bad++; print "long:" $i } }
  END { print "n=" n+0 " bad=" bad+0 }' "$PUI_ALL")
PUI_LN=$(printf '%s\n' "$PUI_LEN" | sed -n 's/^n=\([0-9]*\) .*/\1/p'); PUI_LB=$(printf '%s\n' "$PUI_LEN" | sed -n 's/.* bad=\([0-9]*\)$/\1/p')
pui_is len [ "$PUI_LB" = 0 ]
pui_is lenfloor ge "$PUI_LN" 60
[ "$PUI_LB" = 0 ] || printf '%s\n' "$PUI_LEN" | sed 's/^/    /' | head -n 10
pui_is ascii [ "$(grep -v '^LOG' "$PUI_ALL" | LC_ALL=C grep -c '[^ -~	]')/$(sed -e '/^[[:space:]]*#/d' "$PUI_PL" | LC_ALL=C grep -c '[^ -~	]')" = 0/0 ]
pui_is spinners [ "$(awk -F'\t' '$1 == "START_SPINNER" { print $2 }' "$PUI_ALL" | LC_ALL=C sort -u | tr '\n' ' ')" = "Applying Starting Stopping " ]
PUI_MISS=""
for pui_t in "Starchorus: Stopped" "Starchorus: Running" Settings "Refresh: " "Show Last: " Overview; do
  grep -q "^LIST_PICKER	$pui_t" "$PUI_ALL" || PUI_MISS="$PUI_MISS [$pui_t]"
done
grep -q "^NUMBER_PICKER	Port	" "$PUI_ALL" || PUI_MISS="$PUI_MISS num:Port"
pui_is seen [ -z "$PUI_MISS" ]
rowif "payload ui: static (no active path, never sourced, no exec, POSIX) + $PUI_LN picker calls within 28 chars, ASCII, one-word spinners (bad:${PUI_BAD:- none}${PUI_MISS:+, unseen:$PUI_MISS})" [ -z "$PUI_BAD" ]

# ---- 28 · served directory (route A): uhttpd and python3 are given $STARCHORUS_DIR/www, a directory of their own that holds two symbolic
#            links, index.html -> ../index.html and starchorus.json -> ../starchorus.json, and nothing else; never STARCHORUS_DIR itself, which
#            holds settings.conf, the pid files, collect.log, alerts.log, homing.target and, when /tmp has no room, cap/recon_copy.db (a copy of
#            the recon database, every address and name in it). The stand-in uhttpd keeps the -h of its command line, so the rows read what a
#            browser could have been given: the docroot, end-anchored (a prefix match would pass the whole directory as well). The stand-in
#            collector renames its capture into place, as the real one does, and the link reads whatever is there. A www that is not ours (a plain
#            file, a symbolic link, a directory that holds another entry or a file where a link should be) or that cannot be made (no ln) means no
#            route A: no server, the collector goes on, one note names www, nothing in or behind www is touched; with the bundled nc mini-server
#            there it takes over. A server of the build before (-h STARCHORUS_DIR, a uhttpd outlives a payload update) is still found and stopped.
#            The planted-copy CONTROL runs the same names check against the OLD docroot, where the settings, the pid files and the copy of the
#            recon database are planted: it must fail, so the check can tell a directory that holds more than the two links.
pui_whole() { "$PUI_PS" -A -ww -o args= | awk -v d="$PUI_D" '/uhttpd-srv -p / && !/awk/ { for (i = 1; i < NF; i++) if ($i == "-h" && $(i + 1) == d) { n++; break } } END { print n + 0 }'; }   # -> our stand-in uhttpd given the whole directory (-h followed by exactly it)
pui_names() {   # pui_names DIR -> 0 iff DIR is a plain directory that holds exactly index.html and starchorus.json, both symbolic links with the targets ../index.html and ../starchorus.json, and nothing else (dot files included)
  [ -d "$1" ] && [ ! -L "$1" ] || return 1
  [ "$(pui_ls "$1")" = "index.html starchorus.json " ] || return 1
  [ -L "$1/index.html" ] && [ -L "$1/starchorus.json" ] || return 1
  [ "$(readlink "$1/index.html")" = ../index.html ] && [ "$(readlink "$1/starchorus.json")" = ../starchorus.json ]
}
pui_ls() { find "$1" -mindepth 1 -maxdepth 1 | sed 's|.*/||' | LC_ALL=C sort | tr '\n' ' '; }   # pui_ls DIR -> the names in it (dot files too), sorted, each followed by a blank
pui_has() { for pui_f; do [ -e "$pui_f" ] || return 1; done; }      # pui_has PATH... -> all of them exist
pui_alive() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }
pui_dangles() { [ -L "$1" ] && [ ! -e "$1" ]; }                      # pui_dangles PATH -> a symbolic link whose target is not there (yet)
pui_absent() { for pui_f; do [ ! -e "$pui_f" ] && [ ! -L "$pui_f" ] || return 1; done; }   # pui_absent PATH... -> none of them exists, not even as a dangling link
pui_foreign() {   # pui_foreign LABEL [PATH] -> a Start while www is not ours (set up by the caller): no route-A server, no page files, the collector runs, one note names www
  pui_run "${2:-$PUI_PGP}" sh "$PUI_PL"
  pui_is "$1:collector" pui_col
  pui_is "$1:rc" [ "$PUI_RC" = 0 ]
  pui_is "$1:noserver" [ "$(pui_nsrv)/$(pui_whole)" = 0/0/0 ]
  pui_is "$1:note" [ "$(grep -c '/www' "$PUI_T/out")" = 1 ]
  pui_is "$1:nopage" pui_absent "$PUI_D/page.port" "$PUI_D/page.addr" "$PUI_D/httpd.pid"
  pui_run "${2:-$PUI_PGP}" sh "$PUI_PL" stop
}
# served-root: the stand-in uhttpd is given $PUI_D/www, end of line, and never $PUI_D followed by a blank or the end
PUI_BAD=""; pui_new "port=18281"; printf '<!doctype html>\n' > "$PUI_D/index.html"
pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is started pui_col
pui_is rc [ "$PUI_RC" = 0 ]
pui_is exact [ "$(pui_wsrv 172.16.52.1:18281 | wc -l | tr -d ' ')" = 1 ]
pui_is only [ "$(pui_nsrv)" = 1/1 ]
pui_is notwhole [ "$(pui_whole)" = 0 ]
pui_is page [ "$(cat "$PUI_D/page.port" 2>/dev/null)/$(cat "$PUI_D/page.addr" 2>/dev/null)" = 18281/172.16.52.1 ]
pui_run "$PUI_PGP" sh "$PUI_PL" stop
pui_is stopped [ "$(pui_nsrv)" = 0/0 ]
rowif "payload ui: served root (route A): the stand-in uhttpd is given <dir>/www, line-end anchored, and never the whole directory; stop ends it (served-root; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]
# served-names: <dir>/www holds exactly the two links (relative targets) and nothing else, also after a second Start and after Stop
PUI_BAD=""; pui_new "port=18281"; printf '<!doctype html>\n' > "$PUI_D/index.html"
pui_is before pui_absent "$PUI_D/www"
pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is started pui_col
pui_is names pui_names "$PUI_D/www"
pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is again pui_names "$PUI_D/www"
pui_is oneserver [ "$(pui_nsrv)" = 1/1 ]
pui_run "$PUI_PGP" sh "$PUI_PL" stop
pui_is stopnames pui_names "$PUI_D/www"
rm -f "$PUI_D/www/starchorus.json"; ln -s ../elsewhere.json "$PUI_D/www/starchorus.json"       # a link of ours that points elsewhere is made again, not kept
pui_is skewed pui_not pui_names "$PUI_D/www"
pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is repaired pui_names "$PUI_D/www"
pui_run "$PUI_PGP" sh "$PUI_PL" stop
rowif "payload ui: served names: <dir>/www holds exactly index.html and starchorus.json, links to ../index.html and ../starchorus.json, nothing else; a link that points elsewhere is made again (served-names; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]
# served-live: the link reads the capture the collector renames into place; before the first capture it dangles
PUI_BAD=""; pui_new "port=18282"; : > "$PUI_D/col.nojson"; printf 'page one\n' > "$PUI_D/index.html"
pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is started pui_col
pui_is dangles pui_dangles "$PUI_D/www/starchorus.json"
pui_is pageok [ "$(cat "$PUI_D/www/index.html")" = "page one" ]
printf '{"generated":111}\n' > "$PUI_D/starchorus.json.tmp" && mv "$PUI_D/starchorus.json.tmp" "$PUI_D/starchorus.json"
pui_is first [ "$(cat "$PUI_D/www/starchorus.json" 2>/dev/null)" = '{"generated":111}' ]
printf '{"generated":222,"aps":[]}\n' > "$PUI_D/starchorus.json.tmp" && mv "$PUI_D/starchorus.json.tmp" "$PUI_D/starchorus.json"
pui_is second [ "$(cat "$PUI_D/www/starchorus.json" 2>/dev/null)" = '{"generated":222,"aps":[]}' ]
pui_is stilllinks pui_names "$PUI_D/www"
pui_run "$PUI_PGP" sh "$PUI_PL" stop
rowif "payload ui: served live: before the first capture the starchorus.json link dangles (-L, not -e); after the collector's rename it reads the new bytes, again after the next (served-live; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]
# served-foreign: a www that is not ours means no route A, whatever it is; nothing in or behind it is touched
PUI_BAD=""
pui_new "port=18283"; printf 'foreign\n' > "$PUI_D/www"
pui_foreign file
pui_is file:kept [ "$([ -f "$PUI_D/www" ] && [ ! -L "$PUI_D/www" ] && cat "$PUI_D/www")" = foreign ]
pui_new "port=18283"; mkdir "$PUI_T/behind"; ln -s "$PUI_T/behind" "$PUI_D/www"
pui_foreign symlink
pui_is symlink:kept [ -L "$PUI_D/www" ]
pui_is symlink:behind [ "$(pui_ls "$PUI_T/behind")" = "" ]
rm -rf "$PUI_T/behind"
pui_new "port=18283"; mkdir "$PUI_D/www"; printf 'mine\n' > "$PUI_D/www/index.html"
pui_foreign regular
pui_is regular:kept [ "$([ -f "$PUI_D/www/index.html" ] && [ ! -L "$PUI_D/www/index.html" ] && cat "$PUI_D/www/index.html")" = mine ]
pui_is regular:nolink pui_absent "$PUI_D/www/starchorus.json"
pui_new "port=18283"; mkdir "$PUI_D/www"; printf 'x\n' > "$PUI_D/www/notes.txt"
pui_foreign extra
pui_is extra:kept [ "$(pui_ls "$PUI_D/www")" = "notes.txt " ]
pui_new "port=18283"; mkdir "$PUI_D/www"; : > "$PUI_D/www/.hidden"
pui_foreign dotfile
pui_is dotfile:kept [ "$(pui_ls "$PUI_D/www")" = ".hidden " ]
pui_new "port=18283"; mkdir "$PUI_D/www" "$PUI_T/behind"; ln -s "$PUI_T/behind" "$PUI_D/www/index.html"       # a link to a directory: ln -sf would put its link INTO that directory
pui_foreign dirlink
pui_is dirlink:kept [ "$(pui_ls "$PUI_T/behind")" = "" ]
rm -rf "$PUI_T/behind"
pui_new "port=18283"
pui_foreign noln "$PUI_PGN"
printf '#!/bin/sh\necho ran > "%s/serve.ran"\nexit 0\n' "$PUI_D" > "$PUI_T/serve-standin.sh"
mkdir -p "$PUI_T/ncb"; printf '#!/bin/sh\nexit 0\n' > "$PUI_T/ncb/nc"; chmod +x "$PUI_T/ncb/nc"
pui_new "port=18283"; printf 'foreign\n' > "$PUI_D/www"; cp "$PUI_T/serve-standin.sh" "$PUI_D/starchorus-serve.sh"; chmod +x "$PUI_D/starchorus-serve.sh"
pui_run "$PUI_T/ncb:$PUI_PGP" sh "$PUI_PL"                                                         # the nc mini-server takes over: it is no route A and serves only the page and the capture by name
pui_is nc:collector pui_col
pui_is nc:noroutea [ "$(pui_nsrv)/$(pui_whole)" = 0/0/0 ]
sleep 1
pui_is nc:ran [ "$(cat "$PUI_D/serve.ran" 2>/dev/null)" = ran ]
pui_is nc:said grep -q '(nc mini-server)' "$PUI_T/out"
pui_is nc:kept [ "$([ -f "$PUI_D/www" ] && cat "$PUI_D/www")" = foreign ]
pui_run "$PUI_T/ncb:$PUI_PGP" sh "$PUI_PL" stop
rowif "payload ui: served foreign: a www that is a file, a symbolic link, holds another entry, a dot file, a file or a link to a directory where a link should be, or cannot be made (no ln): no route A, the collector runs, one note names www, nothing in or behind it touched; the nc mini-server takes over (served-foreign; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]
# the python3 branch: a stand-in python3 keeps "-m http.server PORT --bind ADDR --directory DIR" in its argv and loops
mkdir -p "$PUI_T/py"; printf '#!/bin/sh\n# stand-in python3: its argv keeps -m http.server PORT --bind ADDR --directory DIR; it serves nothing\nwhile :; do sleep 1; done\n' > "$PUI_T/py/python3"; chmod +x "$PUI_T/py/python3"
PUI_PY="$PUI_T/py:$PUI_T/lnb:$PUI_T/bin:$PUI_T/sys"
PUI_BAD=""; pui_new "port=18284"; printf '<!doctype html>\n' > "$PUI_D/index.html"
pui_run "$PUI_PY" sh "$PUI_PL"
pui_is started pui_col
PUI_HPID=$(cat "$PUI_D/httpd.pid" 2>/dev/null)
pui_is pid pui_alive "$PUI_HPID"
PUI_HARGS=$("$PUI_PS" -o args= -p "${PUI_HPID:-0}" 2>/dev/null)
case $PUI_HARGS in *" -m http.server 18284 --bind 172.16.52.1 --directory $PUI_D/www") ;; *) PUI_BAD="$PUI_BAD argv" ;; esac
case "$PUI_HARGS " in *"--directory $PUI_D "*|*"--directory=$PUI_D "*) PUI_BAD="$PUI_BAD whole" ;; esac
pui_is names pui_names "$PUI_D/www"
pui_is noroutea [ "$(pui_nsrv)" = 0/0 ]
pui_run "$PUI_PY" sh "$PUI_PL" status
pui_is status [ "$(grep -c '^Page: 172.16.52.1:18284 running$' "$PUI_T/out")" = 1 ]
pui_run "$PUI_PY" sh "$PUI_PL" stop
pui_is gone pui_gone "${PUI_HPID:-0}"
pui_is pidfile pui_absent "$PUI_D/httpd.pid" "$PUI_D/page.port"
pui_new "port=18284"; printf '<!doctype html>\n' > "$PUI_D/index.html"
mkdir "$PUI_D/www"; printf 'foreign\n' > "$PUI_D/www/notes.txt"                                       # python3 alone, www not ours: nothing starts
pui_foreign py "$PUI_PY"
rowif "payload ui: served python3: --directory <dir>/www exactly (end of line, never the whole directory), httpd.pid holds the server, status sees it, stop ends it; a www that is not ours starts nothing (served-python; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]
# old-docroot sweep: a server of the build before (-h STARCHORUS_DIR, a uhttpd daemonises and outlives a payload update) is found by its port and directory
# and stopped, beside the new one; the python3 spellings too; a server of another directory on that port is not
PUI_BAD=""; pui_new "port=18285"
pui_bg "$PUI_T/decoy/uhttpd" -p 172.16.52.1:18285 -h /www; PUI_DEC=$PUI_BGP
pui_bg "$PUI_T/srv/uhttpd-srv" -p 172.16.52.1:18285 -h "$PUI_D"; PUI_OLD1=$PUI_BGP
pui_bg "$PUI_T/py/python3" -m http.server 18285 --bind 172.16.52.1 --directory "$PUI_D"; PUI_OLD2=$PUI_BGP
pui_bg "$PUI_T/py/python3" -m http.server 18285 --bind 172.16.52.1 "--directory=$PUI_D"; PUI_OLD3=$PUI_BGP
pui_bg "$PUI_T/py/python3" -m http.server 18285 --bind 172.16.52.1 "--directory=$PUI_D/www"; PUI_NEW3=$PUI_BGP
pui_run "$PUI_PGP" sh "$PUI_PL" status
pui_is oldseen [ "$(grep -c '^Page: 172.16.52.1:18285 running$' "$PUI_T/out")" = 1 ]
pui_run "$PUI_PGP" sh "$PUI_PL" stop
for pui_p in "$PUI_OLD1" "$PUI_OLD2" "$PUI_OLD3" "$PUI_NEW3"; do pui_is "gone:$pui_p" pui_gone "$pui_p"; done
pui_is decoy kill -0 "$PUI_DEC"
kill "$PUI_DEC" 2>/dev/null
pui_new "port=18285"
pui_bg "$PUI_T/srv/uhttpd-srv" -p 172.16.52.1:18285 -h "$PUI_D"; PUI_OLD1=$PUI_BGP
pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is started pui_col
pui_is swept pui_gone "$PUI_OLD1"                                                                   # a Start stops a server of the build before first (page_up sees it by its directory), then starts the new one
PUI_NEW1=$(pui_wsrv 172.16.52.1:18285 | tr '\n' ' ' | sed 's/ $//')
pui_is newone [ -n "$PUI_NEW1" ]
pui_is onlynew [ "$(pui_nsrv)" = 1/1 ]
pui_bg "$PUI_T/srv/uhttpd-srv" -p 172.16.52.1:18285 -h "$PUI_D"; PUI_OLD1=$PUI_BGP               # one of the old build again, beside the new one
pui_is beside pui_alive "$PUI_OLD1"
pui_run "$PUI_PGP" sh "$PUI_PL" stop
for pui_p in $PUI_NEW1 "$PUI_OLD1"; do pui_is "gone2:$pui_p" pui_gone "$pui_p"; done
rowif "payload ui: served old docroot: a server of the build before (-h <dir>, uhttpd or python3 in both spellings) is seen by status and stopped by stop beside the new one; a server of another directory stays (served-old; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]
# planted-copy CONTROL: everything a browser must not reach is planted in the OLD docroot, <dir> itself; the names check run against it must fail,
# and so must it against a www that holds one thing too many, a regular file, a wrong target or a link where a directory should be. Each pui_is below passes
# ONLY because the check returned non-zero.
PUI_BAD=""; pui_new "port=18286"
printf '<!doctype html>\n' > "$PUI_D/index.html"; printf '{"generated":1}\n' > "$PUI_D/starchorus.json"
printf 'window=600\n' > "$PUI_D/settings.conf"; printf '4242\n' > "$PUI_D/starchorus-loop.pid"; mkdir -p "$PUI_D/cap"; printf 'SQLite format 3\n' > "$PUI_D/cap/recon_copy.db"
printf '172.16.52.1\n' > "$PUI_D/homing.target"; printf 'x\n' > "$PUI_D/collect.log"; printf 'x\n' > "$PUI_D/alerts.log"
pui_is plant:old pui_not pui_names "$PUI_D"
pui_is plant:files pui_has "$PUI_D/settings.conf" "$PUI_D/starchorus-loop.pid" "$PUI_D/cap/recon_copy.db" "$PUI_D/homing.target" "$PUI_D/collect.log" "$PUI_D/alerts.log"
pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is started pui_col
pui_is plant:new pui_names "$PUI_D/www"
pui_is plant:oldstill pui_not pui_names "$PUI_D"
pui_is plant:nocopy pui_absent "$PUI_D/www/settings.conf" "$PUI_D/www/cap" "$PUI_D/www/starchorus-loop.pid" "$PUI_D/www/homing.target" "$PUI_D/www/collect.log" "$PUI_D/www/alerts.log"
pui_run "$PUI_PGP" sh "$PUI_PL" stop
PUI_C="$PUI_T/ctl"; rm -rf "$PUI_C"; mkdir -p "$PUI_C"; ln -s ../index.html "$PUI_C/index.html"; ln -s ../starchorus.json "$PUI_C/starchorus.json"
pui_is ctl:good pui_names "$PUI_C"
: > "$PUI_C/.hidden";           pui_is ctl:dotfile pui_not pui_names "$PUI_C"; rm -f "$PUI_C/.hidden"
printf 'x\n' > "$PUI_C/settings.conf"; pui_is ctl:extra pui_not pui_names "$PUI_C"; rm -f "$PUI_C/settings.conf"
rm -f "$PUI_C/index.html"; printf 'x\n' > "$PUI_C/index.html"; pui_is ctl:regular pui_not pui_names "$PUI_C"; rm -f "$PUI_C/index.html"; ln -s ../index.html "$PUI_C/index.html"
rm -f "$PUI_C/starchorus.json"; ln -s starchorus.json "$PUI_C/starchorus.json"; pui_is ctl:target pui_not pui_names "$PUI_C"; rm -f "$PUI_C/starchorus.json"; ln -s ../starchorus.json "$PUI_C/starchorus.json"
rm -f "$PUI_C/starchorus.json"; pui_is ctl:missing pui_not pui_names "$PUI_C"; ln -s ../starchorus.json "$PUI_C/starchorus.json"
pui_is ctl:good2 pui_names "$PUI_C"
mv "$PUI_C" "$PUI_C.real"; ln -s "$PUI_C.real" "$PUI_C"; pui_is ctl:symlinkdir pui_not pui_names "$PUI_C"; rm -f "$PUI_C"; mv "$PUI_C.real" "$PUI_C"
rm -rf "$PUI_C"
rowif "payload ui: served planted-copy control: the names check fails against the old docroot (settings, pid file, cap/recon_copy.db, homing.target, logs planted) and against a directory with one thing too many, a regular file, a wrong target, a missing link or a symbolic link; the new www passes (served-control; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

pui_kd "--directory $PUI_D"; pui_kd "--directory=$PUI_D"      # the python3 stand-ins of the old docroot, if a red case left one

pui_kd "$PUI_D/"
# whatever a red case left behind (every stand-in runs from $PUI_T)
pui_kd "$PUI_T/"
rm -rf "$PUI_T"
fi
