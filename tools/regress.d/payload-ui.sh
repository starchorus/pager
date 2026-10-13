# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/payload-ui.sh -- the device payload's interface (library/user/reconnaissance/starchorus/payload.sh): menu,
# switches, options, the settings file and the CLI, run for real against stand-ins. Chrome-free, dev machine only.
# GUARDS AGAINST: a settings file that is sourced (a line runs a command) or that reaches a key outside the list; the environment
#                 losing against the file; a menu choice without effect or with the wrong preselection; a Back/cancel that
#                 changes a setting or starts something; a window of "All" or above 6 h without a confirmation; a start without
#                 the confirmation, or with every service switched off; a UI command called off the device (it would block);
#                 a stop that sweeps more than our port; the collector's opt-in transmitting source reachable from the payload;
#                 a page server on every interface without bind=all (the default must be br-lan's address); a self-contained
#                 payload directory that does not install itself, or that overwrites an installed collector.
# NEGATIVE PROBE: pl_load replaced by `. "$SETTINGS"` => rows "hostile file" (canary) and "static" red; pl_valid without the
#                 1471 case => "CLI set" and "menu validation" red; ui_confirm without the answer comparison => "start flow" red
#                 (`=0` starts); the line `pl_heavy` removed => "menu validation" red; the preselection in the On/Off picker wrong
#                 => "menu shows state" red; the gate without `[ $# = 0 ]` => "gate" red.
# NOT PROVEN:     nothing on the device: the real UI commands, their cancel result (exit code/output) and the visible line width
#                 are unconfirmed (docs/device-notes.md §7); the stand-ins answer according to the protocol below. No real
#                 web server, no real port, nothing under BusyBox ash (dash, if present, as a second POSIX shell).
# Stand-ins, all under $PUI_T: one UI script linked as LIST_PICKER, NUMBER_PICKER, CONFIRMATION_DIALOG, ERROR_DIALOG, LOG,
# START_SPINNER, STOP_SPINNER. It appends "NAME<TAB>ARG<TAB>ARG..." to $PUI_LOG; the two pickers and the confirmation take the next
# line of $PUI_ANS: "=text" prints text and exits 0, "!n" exits n without output, an empty line prints nothing (exit 0), and past
# the last line it exits 2 (cancel), so no run can wait for input. Every run is under a 20 s limit (python3, killpg) with a clean
# environment and a PATH of symlinks to a few basic tools: no uhttpd, no python3, no nc, so no server starts unless a case puts
# the stand-in uhttpd on the PATH. setsid is a stand-in (exec), ps a stand-in that lists nothing (or, in the page case, every
# process, like BusyBox `ps w`), ip a stand-in that prints $PUI_T/ip.out (br-lan 172.16.52.1 unless a case changes it). The stand-in collector records its STARCHORUS_* environment and runs until --stop; the stand-in
# dashboard touches a marker file. Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only PUI_* globals and
# pui_* functions are set.

PUI_T=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-pui.XXXXXX") || PUI_T=""
# Collapse doubled slashes (a TMPDIR ending in '/' yields '.../T//starchorus-pui.X'); `ps` reports the resolved
# single-slash path, so the leak sweep at the end and the all-process ps stand-in must match that form.
[ -z "$PUI_T" ] || PUI_T=$(printf %s "$PUI_T" | tr -s /)
if [ -z "$PUI_T" ] || [ ! -d "$PUI_T" ]; then
  row "payload ui: no temp directory" FAIL
else
PUI_PL="$R/library/user/reconnaissance/starchorus/payload.sh"
PUI_D="$PUI_T/d"; PUI_LOG="$PUI_T/log"; PUI_ANS="$PUI_T/ans"; PUI_ALL="$PUI_T/all.log"
mkdir -p "$PUI_T/sys" "$PUI_T/bin" "$PUI_T/psall" "$PUI_T/ui" "$PUI_T/srv" "$PUI_T/decoy" "$PUI_T/tpl"
for pui_t in sh dash cat grep awk mv rm sleep sed wc tr env sort dirname basename touch mkdir head cp chmod; do
  pui_p=$(command -v "$pui_t" 2>/dev/null) && case $pui_p in /*) ln -s "$pui_p" "$PUI_T/sys/$pui_t" ;; esac
done
PUI_PS=$(command -v ps)
printf '#!/bin/sh\n# stand-in setsid\nexec "$@"\n' > "$PUI_T/bin/setsid"
printf '#!/bin/sh\n# stand-in ip: ip -4 -o addr prints the prepared file\ncat "%s/ip.out"\n' "$PUI_T" > "$PUI_T/bin/ip"
PUI_IPBR='1: lo    inet 127.0.0.1/8 scope host lo\       valid_lft forever preferred_lft forever
5: br-lan    inet 172.16.52.1/24 brd 172.16.52.255 scope global br-lan\       valid_lft forever preferred_lft forever
9: wlan0cli    inet 192.168.77.50/24 brd 192.168.77.255 scope global wlan0cli\       valid_lft forever preferred_lft forever'
printf '%s\n' "$PUI_IPBR" > "$PUI_T/ip.out"
printf '#!/bin/sh\n# stand-in ps: lists nothing (a real server of the developer on the same port stays out of reach)\necho "  PID COMMAND"\n' > "$PUI_T/bin/ps"
# stand-in BusyBox `ps w`: only the processes under our own temp dir (pid first). It never lists a developer's own
# server or a parallel regress run in another worktree, so the payload's real sweep can only ever reach our stand-ins
# and our own decoy (which also live under $PUI_T). The port therefore never needs to be unique across runs.
printf '#!/bin/sh\n%s -A -ww -o pid= -o args= | grep -F %s\n' "$PUI_PS" "$PUI_T" > "$PUI_T/psall/ps"
# shellcheck disable=SC2016   # script text for the stand-in, expanded when it runs
printf '#!/bin/sh\n# stand-in uhttpd: daemonizes (its argv keeps -p PORT -h DIR) and returns at once\nsh "$(dirname "$0")/uhttpd-srv" "$@" </dev/null >/dev/null 2>&1 &\nexit 0\n' > "$PUI_T/srv/uhttpd"
printf '#!/bin/sh\nwhile :; do sleep 1; done\n' > "$PUI_T/srv/uhttpd-srv"
printf '#!/bin/sh\nwhile :; do sleep 1; done\n' > "$PUI_T/decoy/uhttpd"
cat > "$PUI_T/ui/pui-ui" <<'PUI_UI'
#!/bin/sh
# stand-in device UI command (one script, linked under every name)
n=$(basename "$0")
{ printf '%s' "$n"; for a; do printf '\t%s' "$a"; done; printf '\n'; } >> "$PUI_LOG"
case $n in
  LIST_PICKER|NUMBER_PICKER|CONFIRMATION_DIALOG)
    c=$(cat "$PUI_ANS.n" 2>/dev/null || echo 0); c=$((c + 1)); echo "$c" > "$PUI_ANS.n"
    [ "$c" -le "$(wc -l < "$PUI_ANS" | tr -d ' ')" ] || exit 2
    a=$(sed -n "${c}p" "$PUI_ANS")
    # "=text" prints text, exit 0; "!n" exits n with no output; "r:n:text" prints text AND exits n (a non-zero exit
    # WITH output, which §4 still reads as Back / No); an empty line prints nothing (exit 0).
    case $a in
      "="*)  printf '%s\n' "${a#=}"; exit 0 ;;
      "!"*)  exit "${a#!}" ;;
      "r:"*) pui_rest=${a#r:}; printf '%s\n' "${pui_rest#*:}"; exit "${pui_rest%%:*}" ;;
      *)     exit 0 ;;
    esac ;;
  START_SPINNER) echo 7 ;;
esac
exit 0
PUI_UI
for pui_t in LIST_PICKER NUMBER_PICKER CONFIRMATION_DIALOG ERROR_DIALOG LOG START_SPINNER STOP_SPINNER; do ln -s pui-ui "$PUI_T/ui/$pui_t"; done
cat > "$PUI_T/tpl/starchorus-collect.sh" <<'PUI_COL'
#!/bin/sh
# stand-in collector: records its STARCHORUS_* environment, runs until --stop
d=$(cd "$(dirname "$0")" && pwd)
case $1 in
  --stop) [ -f "$d/col.pid" ] && kill "$(cat "$d/col.pid")" 2>/dev/null; rm -f "$d/col.pid"; exit 0 ;;
  --status) if [ -f "$d/col.pid" ] && kill -0 "$(cat "$d/col.pid")" 2>/dev/null; then echo "[starchorus] running"; else echo "[starchorus] not running"; fi; exit 0 ;;
esac
# write col.pid BEFORE col.env, so pui_kill (which reads col.pid) never races between the two writes; and die when
# the payload directory is removed, so a stand-in from a failing case cannot outlive its directory.
echo $$ > "$d/col.pid"
env | grep '^STARCHORUS_' | sort > "$d/col.env.tmp" && mv "$d/col.env.tmp" "$d/col.env"
while [ -d "$d" ]; do sleep 1; done
PUI_COL
# shellcheck disable=SC2016   # script text for the stand-in, expanded when it runs
printf '#!/bin/sh\n# stand-in dashboard\ntouch "$(dirname "$0")/display.marker"\n' > "$PUI_T/tpl/starchorus-display.sh"
chmod +x "$PUI_T/bin/"* "$PUI_T/psall/"* "$PUI_T/ui/pui-ui" "$PUI_T/srv/"* "$PUI_T/decoy/"* "$PUI_T/tpl/"*
PUI_HL="$PUI_T/bin:$PUI_T/sys"            # headless: no UI command
PUI_UIP="$PUI_T/ui:$PUI_T/bin:$PUI_T/sys" # the device UI stand-ins first
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
  python3 -c "$PUI_TO" "$PUI_T/out" env -i PATH="$pui_rp" STARCHORUS_DIR="$PUI_D" PUI_LOG="$PUI_LOG" PUI_ANS="$PUI_ANS" "$@"; PUI_RC=$?
  [ "$PUI_RC" = 124 ] && PUI_ABORT=1
  cat "$PUI_LOG" >> "$PUI_ALL" 2>/dev/null; : > "$PUI_LOG"
}
pui_kill() { [ -f "$PUI_D/col.pid" ] && kill "$(cat "$PUI_D/col.pid")" 2>/dev/null; rm -f "$PUI_D/col.pid"; }
pui_new() {   # pui_new [SETTINGS LINE...] -> a fresh payload directory with the stand-ins (no line: no settings file)
  pui_kill; rm -rf "$PUI_D"; mkdir -p "$PUI_D"
  cp "$PUI_T/tpl/starchorus-collect.sh" "$PUI_T/tpl/starchorus-display.sh" "$PUI_D/"
  [ $# = 0 ] || printf '%s\n' "$@" > "$PUI_D/settings.conf"
  : > "$PUI_LOG"; : > "$PUI_ANS"; rm -f "$PUI_ANS.n"
}
pui_ans() { if [ $# = 0 ]; then : > "$PUI_ANS"; else printf '%s\n' "$@" > "$PUI_ANS"; fi; rm -f "$PUI_ANS.n"; }   # pui_ans ANSWER... (one per picker/confirmation call)
pui_used() { cat "$PUI_ANS.n" 2>/dev/null || echo 0; }                # answers taken, EOF calls included
pui_col() { pui_i=0; while [ ! -s "$PUI_D/col.env" ] && [ "$pui_i" -lt 8 ]; do sleep 1; pui_i=$((pui_i + 1)); done; [ -s "$PUI_D/col.env" ]; }
pui_nocol() { sleep 1; [ ! -e "$PUI_D/col.env" ]; }                   # the payload returned; a started collector would have written by now
pui_env() { sed -n "s/^$1=//p" "$PUI_D/col.env" 2>/dev/null; }       # pui_env STARCHORUS_VAR -> its value in the collector
pui_gone() { pui_i=0; while kill -0 "$1" 2>/dev/null && [ "$pui_i" -lt 6 ]; do sleep 1; pui_i=$((pui_i + 1)); done; ! kill -0 "$1" 2>/dev/null; }
pui_is() { pui_l=$1; shift; "$@" || PUI_BAD="$PUI_BAD $pui_l"; }      # pui_is LABEL TEST... -> LABEL joins PUI_BAD when TEST fails
pui_logc() { grep -c "$1" "$PUI_T/case.log"; }                        # count UI calls of the last run (copy in case.log)
pui_run_ui() { : > "$PUI_LOG"; pui_run "$@"; tail -n "+$PUI_MARK" "$PUI_ALL" > "$PUI_T/case.log"; PUI_MARK=$(($(wc -l < "$PUI_ALL") + 1)); }
PUI_MARK=1
pui_get() { pui_run "$PUI_HL" sh "$PUI_PL" get "$1"; sed -n "s/^$1=\([^ ]*\) (\(.*\))$/\1 \2/p" "$PUI_T/out"; }   # -> "VALUE SOURCE"

# ---- 1 · headless, no settings file: the defaults reach the collector, no dashboard, stop leaves nothing; also under dash
PUI_BAD=""; PUI_SH="sh"; [ -e "$PUI_T/sys/dash" ] && PUI_SH="sh dash"
for pui_sh in $PUI_SH; do
  pui_new; pui_run_ui "$PUI_HL" "$pui_sh" "$PUI_PL"
  pui_is "$pui_sh:rc$PUI_RC" [ "$PUI_RC" = 0 ]
  pui_is "$pui_sh:started" pui_col
  pui_is "$pui_sh:env" [ "$(pui_env STARCHORUS_MAX_AGE)/$(pui_env STARCHORUS_INTERVAL)/$(pui_env STARCHORUS_PORT)/$(pui_env STARCHORUS_OUTDIR)" = "3600/30/8199/$PUI_D" ]
  pui_is "$pui_sh:flags" [ "$(pui_env STARCHORUS_VENDOR)/$(pui_env STARCHORUS_OWN)/$(pui_env STARCHORUS_SURVEY)" = 1/0/0 ]
  pui_is "$pui_sh:marker" [ ! -e "$PUI_D/display.marker" ]
  pui_is "$pui_sh:nofile" [ ! -e "$PUI_D/settings.conf" ]
  PUI_CP=$(cat "$PUI_D/col.pid" 2>/dev/null)
  pui_run "$PUI_HL" "$pui_sh" "$PUI_PL" stop
  pui_is "$pui_sh:stop" pui_gone "${PUI_CP:-0}"
  pui_is "$pui_sh:stoprc" [ "$PUI_RC/${PUI_CP:+pid}" = 0/pid ]
done
rowif "payload ui: headless start = defaults 3600/30/8199/OUTDIR, no dashboard, stop ($PUI_SH; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

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
PUI_BAD=""
# shellcheck disable=SC2016   # the $(...) lines are file content that must NOT run
pui_new "port=1471" "port=80" "interval=0" "window=abc" "STARCHORUS_ALLOW_ACTIVE=1" "source=iwscan" "iface=wlan9" \
  "x=\$(touch $PUI_T/canary)" "port=\$(touch $PUI_T/canary)" "window=600;touch $PUI_T/canary" "window='600'" 'port="8300"' \
  "window=0600" " port=8300" "$(printf 'interval=45\r')" "vendor=OFF" "own=1"
pui_run "$PUI_HL" sh "$PUI_PL"
pui_is started pui_col
pui_is values [ "$(pui_env STARCHORUS_MAX_AGE)/$(pui_env STARCHORUS_PORT)/$(pui_env STARCHORUS_INTERVAL)/$(pui_env STARCHORUS_VENDOR)/$(pui_env STARCHORUS_OWN)" = 3600/8199/45/1/0 ]
pui_is active [ "$(grep -c 'ALLOW_ACTIVE\|SOURCE\|IFACE' "$PUI_D/col.env")" = 0 ]
pui_is canary [ ! -e "$PUI_T/canary" ]
pui_is canary2 [ ! -e "$PUI_D/canary" ]
pui_run "$PUI_HL" sh "$PUI_PL" get
pui_is get [ "$(grep -c '(file)' "$PUI_T/out")/$(grep -ci 'active\|source' "$PUI_T/out")" = 1/0 ]
rowif "payload ui: hostile file -> defaults, CRLF read, no key outside the list, no command run (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 5 · CLI: every key round-trips through set/get; refusals exit 2 and leave the file byte-identical; reset
PUI_BAD=""; pui_new
for pui_kv in window=600 interval=60 port=8300 vendor=off own=on survey=on collector=off page=off dashboard=off window=0 window=86400; do
  pui_run "$PUI_HL" sh "$PUI_PL" set "${pui_kv%%=*}" "${pui_kv#*=}"
  pui_is "set:$pui_kv" [ "$PUI_RC" = 0 ]
  pui_is "get:$pui_kv" [ "$(pui_get "${pui_kv%%=*}")" = "${pui_kv#*=} file" ]
done
pui_is sparse [ "$(wc -l < "$PUI_D/settings.conf" | tr -d ' ')" = 9 ]
cp "$PUI_D/settings.conf" "$PUI_T/before.conf"
for pui_bad in "port 1471" "port 80" "port 70000" "allow_active 1" "foo 1" "source iwscan" "window abc" "window 59" "window 86401" \
  "interval 4" "interval 3601" "vendor yes" "window 0600" "STARCHORUS_ALLOW_ACTIVE 1" "port"; do
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
pui_is default [ "$(pui_get port)/$(pui_get window)/$(pui_get vendor)" = "8199 default/3600 default/on default" ]
rowif "payload ui: CLI set/get/reset, refusals exit 2, file untouched, no .tmp (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 6 · menu: a choice is saved, the redrawn menu shows it, switches preselect the current state
PUI_BAD=""; pui_new
pui_ans "=Options" "=Port: 8199" "=8300"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is file [ "$(cat "$PUI_D/settings.conf" 2>/dev/null)" = "port=8300" ]
pui_is redraw [ "$(grep '^LIST_PICKER	Options	' "$PUI_T/case.log" | sed -n 2p | grep -c '	Port: 8300	')" = 1 ]
pui_is numdefault [ "$(grep -c '^NUMBER_PICKER	Port	8199$' "$PUI_T/case.log")" = 1 ]
pui_is nocol pui_nocol
pui_ans "=Services" "=Collector: On" "=Off" "=Web page: On" "=Off"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is pre [ "$(grep -c '^LIST_PICKER	Collector	On	Off	On$' "$PUI_T/case.log")" = 1 ]
pui_is svc [ "$(grep '^LIST_PICKER	Services	' "$PUI_T/case.log" | sed -n 3p)" = "LIST_PICKER	Services	Collector: Off	Web page: Off	Back	Back" ]
pui_ans "=Options" "=Own radios: Off" "=On" "=Survey: Off" "=On" "=Auto dash: On" "=Off" "=Vendor: On" "=Off" \
  "=Interval: 30 s" "=60 s" "=Window: 1 h" "=10 min"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is preoff [ "$(grep -c '^LIST_PICKER	Own radios	On	Off	Off$' "$PUI_T/case.log")" = 1 ]
pui_is prew [ "$(grep -c '^LIST_PICKER	Window	2 min	10 min	1 h	6 h	All	Other	1 h$' "$PUI_T/case.log")" = 1 ]
pui_is last [ "$(grep '^LIST_PICKER	Options	' "$PUI_T/case.log" | tail -n 1)" = "LIST_PICKER	Options	Window: 10 min	Interval: 60 s	Port: 8300	Vendor: Off	Own radios: On	Survey: On	Auto dash: Off	Defaults	Back	Back" ]
pui_is all [ "$(LC_ALL=C sort "$PUI_D/settings.conf" | tr '\n' ' ')" = "collector=off dashboard=off interval=60 own=on page=off port=8300 survey=on vendor=off window=600 " ]
pui_is used [ "$(pui_used)" = 15 ]
rowif "payload ui: menu saves, redraws with the value, preselects the state (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 7 · cancel / Back everywhere: no setting changes, nothing starts; EOF on the main menu = exit 0
PUI_BAD=""; pui_new "interval=60" "# kept"
cp "$PUI_D/settings.conf" "$PUI_T/before.conf"
pui_ans "=Options" "=Window: 1 h" "!2" "=Window: 1 h" "=Other" "!2" "=Port: 8199" "" "=Interval: 60 s" "" "=Vendor: On" "!2" \
  "=Defaults" "!1" "=Bogus" "=Services" "=Collector: On" "!2" "=Web page: On" "=Maybe" "!2" "!2"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is unchanged cmp -s "$PUI_T/before.conf" "$PUI_D/settings.conf"
pui_is used [ "$(pui_used)" = 22 ]
pui_is calls [ "$(pui_logc '^NUMBER_PICKER')/$(pui_logc '^CONFIRMATION_DIALOG')/$(pui_logc '^START_SPINNER')" = 2/1/0 ]
pui_is nocol pui_nocol
pui_is marker [ ! -e "$PUI_D/display.marker" ]
pui_new; pui_ans; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is eof [ "$PUI_RC/$(pui_logc '^LIST_PICKER')/$(pui_used)" = 0/1/1 ]
pui_is eofcol pui_nocol
pui_ans "!2"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is back [ "$PUI_RC/$(pui_logc '^LIST_PICKER')" = 0/1 ]
pui_is nofile [ ! -e "$PUI_D/settings.conf" ]
rowif "payload ui: cancel/empty/unknown answers change nothing, start nothing (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 8 · menu validation: "All" and a window above 6 h only after a yes; invalid numbers are refused with an error dialog
PUI_BAD=""; pui_new
pui_ans "=Options" "=Window: 1 h" "=All" "!1" "=Window: 1 h" "=All" "=1" "=Window: All" "=Other" "=30000" "=0" \
  "=Window: All" "=Other" "=30000" "=1" "=Window: 500 min" "=Other" "=30" "=Port: 8199" "=1471" "=Interval: 30 s" "=Other" "=4" \
  "=Port: 8199" "=80"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is file [ "$(cat "$PUI_D/settings.conf" 2>/dev/null)" = "window=30000" ]
pui_is whole [ "$(pui_logc '^CONFIRMATION_DIALOG	All may lag. Use it?$')" = 2 ]
pui_is long [ "$(pui_logc '^CONFIRMATION_DIALOG	Over 6 h may lag. Use it?$')" = 2 ]
pui_is allshown [ "$(grep '^LIST_PICKER	Options	' "$PUI_T/case.log" | grep -c '	Window: All	')" = 2 ]
pui_is errors [ "$(pui_logc '^ERROR_DIALOG')" = 4 ]
pui_is errtext [ "$(pui_logc '^ERROR_DIALOG	Window: 60-86400 s$')/$(pui_logc '^ERROR_DIALOG	Interval: 5-3600 s$')/$(pui_logc '^ERROR_DIALOG	Port: 1024-65535, not 1471$')" = 1/1/2 ]
pui_is used [ "$(pui_used)" = 27 ]
rowif "payload ui: window All / > 6 h need a yes, invalid numbers refused (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 9 · start flow: only a real yes starts; the file's values reach the collector; Auto dashboard decides the hand-off
PUI_BAD=""; pui_new "window=600" "dashboard=off"
pui_ans "=Start" "!1" "=Start" "=0" "=Start" "" "=Start" "=yes"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is norc [ "$PUI_RC" = 0 ]
pui_is noconf [ "$(pui_logc '^CONFIRMATION_DIALOG	Start collector, web page?$')" = 4 ]
pui_is nostart pui_nocol
pui_is nospin [ "$(pui_logc '^START_SPINNER')" = 0 ]
pui_ans "=Start" "=1"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is started pui_col
pui_is values [ "$(pui_env STARCHORUS_MAX_AGE)/$(pui_env STARCHORUS_PORT)" = 600/8199 ]
pui_is spin [ "$(pui_logc '^START_SPINNER	Starting$')/$(pui_logc '^STOP_SPINNER	7$')" = 1/1 ]
pui_is heading [ "$(pui_logc '^LOG	blue	Window 10 min, every 30 s, port 8199$')" = 1 ]
pui_is noserver [ "$(pui_logc '^LOG	red	No web server$')/$(pui_logc '^LOG	Collecting, no page$')" = 1/1 ]
pui_is nomarker [ ! -e "$PUI_D/display.marker" ]
pui_is back [ "$PUI_RC/$(pui_used)" = 0/3 ]
pui_new "collector=on"; pui_ans "=Start" "=1"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is started2 pui_col
pui_is marker [ -e "$PUI_D/display.marker" ]
pui_is exec [ "$PUI_RC/$(pui_used)" = 0/2 ]
pui_new "page=off"; pui_ans "=Start" "=1"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is msg [ "$(pui_logc '^CONFIRMATION_DIALOG	Start collector?$')" = 1 ]
rowif "payload ui: start only on a yes, values from the file, Auto dashboard on/off (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 10 · every service switched off: Start shows an error, asks nothing, starts nothing
PUI_BAD=""; pui_new "collector=off" "page=off"
pui_ans "=Start"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is err [ "$(pui_logc '^ERROR_DIALOG	No service on$')/$(pui_logc '^CONFIRMATION_DIALOG')" = 1/0 ]
pui_is nocol pui_nocol
pui_is nomarker [ ! -e "$PUI_D/display.marker" ]
rowif "payload ui: all services off -> error, no confirmation, nothing started (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 11 · the device gate: with the UI commands present, an argument or STARCHORUS_PAYLOAD_PLAIN=1 never calls one
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
pui_is plainmarker [ ! -e "$PUI_D/display.marker" ]
pui_run_ui "$PUI_UIP" sh "$PUI_PL" start
pui_is start [ "$PUI_RC/$(wc -l < "$PUI_T/case.log" | tr -d ' ')" = 0/0 ]
rowif "payload ui: gate: arguments and STARCHORUS_PAYLOAD_PLAIN=1 call no UI command (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 12 · page on the configured port: status sees it, stop ends it and the collector, a server on another port stays
PUI_BAD=""; pui_new "port=18299"
PUI_PGP="$PUI_T/srv:$PUI_T/psall:$PUI_T/bin:$PUI_T/sys"
sh "$PUI_T/decoy/uhttpd" -p 80 -h /www </dev/null >/dev/null 2>&1 & PUI_DEC=$!
pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is started pui_col
PUI_SRV=$("$PUI_PS" -A -ww -o pid= -o args= | awk -v t="uhttpd-srv -p 172.16.52.1:18299 -h $PUI_D" 'index($0, t) && !/awk/ { print $1 }' | tr '\n' ' ' | sed 's/ $//')
pui_is srv [ -n "$PUI_SRV" ]
pui_run "$PUI_PGP" sh "$PUI_PL" status
pui_is status [ "$(grep -c '^Page: 172.16.52.1:18299 running$' "$PUI_T/out")/$(grep -c '^running$' "$PUI_T/out")/$(grep -c 'starchorus\]' "$PUI_T/out")" = 1/1/0 ]
PUI_CP=$(cat "$PUI_D/col.pid" 2>/dev/null)
pui_run "$PUI_PGP" sh "$PUI_PL" stop
for pui_p in $PUI_SRV ${PUI_CP:-0}; do pui_is "gone:$pui_p" pui_gone "$pui_p"; done
pui_is decoy kill -0 "$PUI_DEC"
pui_run "$PUI_PGP" sh "$PUI_PL" status
pui_is down [ "$(grep -c '^Page: 172.16.52.1:18299 not running$' "$PUI_T/out")" = 1 ]
pui_run "$PUI_PGP" sh "$PUI_PL" set page off
pui_run "$PUI_PGP" sh "$PUI_PL" status
pui_is off [ "$(grep -c '^Page: off$' "$PUI_T/out")" = 1 ]
kill "$PUI_DEC" 2>/dev/null; wait "$PUI_DEC" 2>/dev/null
rowif "payload ui: page on port 18299: status, stop ends only ours (server ${PUI_SRV:-none}; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 13 · a port change while the page runs does not orphan the old server: status still sees it on the served port,
#           and stop ends it (the served port is recorded in page.port; stop and status also sweep/report it)
PUI_BAD=""; pui_new "port=18299"
pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is started pui_col
PUI_SRV=$("$PUI_PS" -A -ww -o pid= -o args= | awk -v t="uhttpd-srv -p 172.16.52.1:18299 -h $PUI_D" 'index($0, t) && !/awk/ { print $1 }' | tr '\n' ' ' | sed 's/ $//')
pui_is srv [ -n "$PUI_SRV" ]
pui_is portfile [ "$(cat "$PUI_D/page.port" 2>/dev/null)" = 18299 ]
pui_run "$PUI_PGP" sh "$PUI_PL" set port 18300
pui_is setrc [ "$PUI_RC" = 0 ]
pui_run "$PUI_PGP" sh "$PUI_PL" status
pui_is statusrun [ "$(grep -c '^Page: 172.16.52.1:18299 running$' "$PUI_T/out")" = 1 ]
PUI_CP=$(cat "$PUI_D/col.pid" 2>/dev/null)
pui_run "$PUI_PGP" sh "$PUI_PL" stop
for pui_p in $PUI_SRV ${PUI_CP:-0}; do pui_is "gone:$pui_p" pui_gone "$pui_p"; done
pui_is portfilegone [ ! -e "$PUI_D/page.port" ] && [ ! -e "$PUI_D/page.addr" ]
rowif "payload ui: a port change keeps the old server reachable (status on 18299, stop ends it) (server ${PUI_SRV:-none}; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 14 · stop matches only OUR own -p [ADDR:]PORT -h our-dir server: a server on the same port (bare or with the same
#           address) with a different -h directory (the device's own uhttpd), and the port sitting in a non-listening
#           argument, all survive; an older server of ours on the bare -p PORT form is stopped too
PUI_BAD=""; pui_new "port=18401"
sh "$PUI_T/decoy/uhttpd" -p 18401 -h /www </dev/null >/dev/null 2>&1 & PUI_D1=$!
sh "$PUI_T/decoy/uhttpd" -p 80 -h /www 18401 </dev/null >/dev/null 2>&1 & PUI_D2=$!
sh "$PUI_T/decoy/uhttpd" -p 172.16.52.1:18401 -h /www </dev/null >/dev/null 2>&1 & PUI_D3=$!
PUI_O1=$(sh "$PUI_T/srv/uhttpd-srv" -p 18401 -h "$PUI_D" </dev/null >/dev/null 2>&1 & echo $!)   # not a job of this shell: its end prints no job line
pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is started pui_col
PUI_SRV=$("$PUI_PS" -A -ww -o pid= -o args= | awk -v t="uhttpd-srv -p 172.16.52.1:18401 -h $PUI_D" 'index($0, t) && !/awk/ { print $1 }' | tr '\n' ' ' | sed 's/ $//')
pui_is srv [ -n "$PUI_SRV" ]
pui_run "$PUI_PGP" sh "$PUI_PL" stop
for pui_p in $PUI_SRV "$PUI_O1"; do pui_is "gone:$pui_p" pui_gone "$pui_p"; done
pui_is samedir kill -0 "$PUI_D1"
pui_is strayarg kill -0 "$PUI_D2"
pui_is sameaddr kill -0 "$PUI_D3"
kill "$PUI_D1" "$PUI_D2" "$PUI_D3" "$PUI_O1" 2>/dev/null; wait "$PUI_D1" "$PUI_D2" "$PUI_D3" 2>/dev/null
rowif "payload ui: stop needs -p [ADDR:]PORT AND -h our-dir; same-port/same-address other-dir and stray-arg servers survive (server ${PUI_SRV:-none}; bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 15 · a failing grep during a set (it cannot read the old file) does not truncate settings.conf: rc 1, byte-identical
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

# ---- 16 · plain start with both services off: a note, exit 1, and a collector that is already running is NOT stopped
PUI_BAD=""; pui_new "page=off"
pui_run "$PUI_HL" sh "$PUI_PL" start
pui_is started pui_col
PUI_CP=$(cat "$PUI_D/col.pid" 2>/dev/null)
pui_run "$PUI_HL" sh "$PUI_PL" set collector off
pui_run "$PUI_HL" sh "$PUI_PL" start
pui_is bothoff_rc [ "$PUI_RC" = 1 ]
pui_is bothoff_msg [ "$(grep -ci 'no service on' "$PUI_T/out")" = 1 ]
pui_is bothoff_alive kill -0 "${PUI_CP:-0}"
pui_run "$PUI_HL" sh "$PUI_PL" stop
pui_is stopped pui_gone "${PUI_CP:-0}"
rowif "payload ui: plain start with both services off notes it, exits 1, stops nothing (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 17 · environment edge cases: an empty variable counts as unset (the file value wins, source "file"); a set made
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

# ---- 18 · menu Exit logs "Services keep running" only when something is actually running
PUI_BAD=""; pui_new "collector=off" "page=off"
pui_ans "=Exit"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is quiet_rc [ "$PUI_RC" = 0 ]
pui_is quiet [ "$(pui_logc '^LOG	Services keep running$')" = 0 ]
pui_new "page=off" "dashboard=off"
pui_ans "=Start" "=1" "=Exit"; pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is started pui_col
pui_is logged [ "$(pui_logc '^LOG	Services keep running$')" = 1 ]
rowif "payload ui: Exit reports running services only when something runs (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 19 · a non-zero exit WITH output is still Back (a picker) or No (a confirmation): nothing changes
PUI_BAD=""; pui_new "interval=60"
cp "$PUI_D/settings.conf" "$PUI_T/before.conf"
pui_ans "=Options" "=Interval: 60 s" "r:2:120 s" "=Window: 1 h" "=All" "r:3:1" "!2"
pui_run_ui "$PUI_UIP" sh "$PUI_PL"
pui_is rc [ "$PUI_RC" = 0 ]
pui_is unchanged cmp -s "$PUI_T/before.conf" "$PUI_D/settings.conf"
pui_is confirmed [ "$(pui_logc '^CONFIRMATION_DIALOG	All may lag. Use it?$')" = 1 ]
rowif "payload ui: a non-zero exit with output is Back / No, nothing changes (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 20 · bind: set/get/reset like port; refusals (0.0.0.0 included: every interface is spelt `all`); the environment
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

# ---- 21 · bind at start: the page server listens on br-lan's address by default (stand-in ip), an explicit address, or
#           0.0.0.0 only for all; without br-lan 172.16.52.1 when configured, else 127.0.0.1 with a note; the hint, page.addr
#           and Status name the real address, and stop ends each one
PUI_BAD=""
pui_bindcase() {   # pui_bindcase LABEL EXPECTED-ADDR [settings line] -> start, check args/hint/status, stop
  if [ -n "${3:-}" ]; then pui_new "port=18501" "$3"; else pui_new "port=18501"; fi
  pui_run "$PUI_PGP" sh "$PUI_PL"
  pui_is "$1:started" pui_col
  pui_bs=$("$PUI_PS" -A -ww -o pid= -o args= | awk -v t="uhttpd-srv -p $2:18501 -h $PUI_D" 'index($0, t) && !/awk/ { print $1 }' | tr '\n' ' ')
  pui_is "$1:args" [ -n "$pui_bs" ]
  pui_is "$1:any" [ "$("$PUI_PS" -A -ww -o args= | grep -F "$PUI_D" | grep -c 'uhttpd-srv -p ')" = 1 ]
  pui_is "$1:addrfile" [ "$(cat "$PUI_D/page.addr" 2>/dev/null)" = "$2" ]
  if [ "$2" = 0.0.0.0 ]; then pui_is "$1:hint" grep -q 'http://<device-ip>:18501/ (all interfaces)' "$PUI_T/out"
  else pui_is "$1:hint" grep -q "http://$2:18501/" "$PUI_T/out"; fi
  pui_run "$PUI_PGP" sh "$PUI_PL" status
  pui_is "$1:status" [ "$(grep -c "^Page: $2:18501 running$" "$PUI_T/out")" = 1 ]
  pui_bc=$(cat "$PUI_D/col.pid" 2>/dev/null)
  pui_run "$PUI_PGP" sh "$PUI_PL" stop
  for pui_p in $pui_bs ${pui_bc:-0}; do pui_is "$1:gone" pui_gone "$pui_p"; done
}
pui_bindcase default 172.16.52.1
pui_is default:quiet [ "$(grep -c 'note' "$PUI_T/out")" = 0 ]
pui_bindcase explicit 10.0.0.7 "bind=10.0.0.7"
pui_bindcase all 0.0.0.0 "bind=all"
printf '%s\n' "1: lo    inet 127.0.0.1/8 scope host lo" "4: eth1    inet 172.16.52.1/24 scope global eth1" > "$PUI_T/ip.out"
pui_bindcase nobr 172.16.52.1
printf '%s\n' "1: lo    inet 127.0.0.1/8 scope host lo" "9: wlan0cli    inet 192.168.77.50/24 scope global wlan0cli" > "$PUI_T/ip.out"
pui_new "port=18501"; pui_run "$PUI_PGP" sh "$PUI_PL"
pui_is lo:note [ "$(grep -c '127.0.0.1 only' "$PUI_T/out")" = 1 ]
pui_run "$PUI_PGP" sh "$PUI_PL" stop
pui_bindcase lo 127.0.0.1
printf '%s\n' "$PUI_IPBR" > "$PUI_T/ip.out"
rowif "payload ui: bind at start: br-lan by default, explicit, all = 0.0.0.0, 172.16.52.1 / 127.0.0.1 fallbacks; hint, page.addr, status (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

# ---- 22 · static: no active-scan path, the file is never sourced, the collector reads no settings file, POSIX-clean;
# picker titles <= 14 and labels <= 18 characters over every picker call of the runs above (with a floor and every menu seen)
PUI_BAD=""
pui_is active [ "$(grep -cE 'ALLOW_ACTIVE|iwscan' "$PUI_PL")" = 0 ]
pui_is source [ "$(sed -e '/^[[:space:]]*#/d' -e 's/[[:space:]]#.*//' "$PUI_PL" | grep -cE '(^|[;&|({[:space:]])(\.|source|eval)[[:space:]]')" = 0 ]
pui_is collector [ "$(grep -c 'settings\.conf' starchorus-collect.sh)" = 0 ]
pui_is shn sh -n "$PUI_PL"
pui_is scsh shellcheck -s sh "$PUI_PL"
PUI_LEN=$(awk -F'\t' '$1 == "LIST_PICKER" || $1 == "NUMBER_PICKER" { n++; if (length($2) > 14) { bad++; print "title:" $2 } if ($1 == "LIST_PICKER") for (i = 3; i <= NF; i++) if (length($i) > 18) { bad++; print "label:" $i } }
  END { print "n=" n+0 " bad=" bad+0 }' "$PUI_ALL")
PUI_LN=$(printf '%s\n' "$PUI_LEN" | sed -n 's/^n=\([0-9]*\) .*/\1/p'); PUI_LB=$(printf '%s\n' "$PUI_LEN" | sed -n 's/.* bad=\([0-9]*\)$/\1/p')
pui_is len [ "$PUI_LB" = 0 ]
pui_is lenfloor ge "$PUI_LN" 60
[ "$PUI_LB" = 0 ] || printf '%s\n' "$PUI_LEN" | sed 's/^/    /' | head -n 10
PUI_MISS=""
for pui_t in Starchorus Services Options Window Interval Collector "Web page" Vendor "Own radios" Survey "Auto dashboard"; do
  grep -q "^LIST_PICKER	$pui_t	" "$PUI_ALL" || PUI_MISS="$PUI_MISS $pui_t"
done
for pui_t in Port "Window (s)" "Interval (s)"; do grep -q "^NUMBER_PICKER	$pui_t	" "$PUI_ALL" || PUI_MISS="$PUI_MISS num:$pui_t"; done
pui_is seen [ -z "$PUI_MISS" ]
rowif "payload ui: static (no active path, never sourced, POSIX) + $PUI_LN picker calls within 14/18 chars (bad:${PUI_BAD:- none}${PUI_MISS:+, unseen:$PUI_MISS})" [ -z "$PUI_BAD" ]

# ---- 23 · BUNDLE: a self-contained payload directory (tools/hak5-package.sh) installs itself into an empty STARCHORUS_DIR on
#           the first run (files byte-identical, scripts made executable even from 0644 sources, a note on stderr, the
#           settings file in STARCHORUS_DIR, the collector started from there); a second run copies nothing; an installed
#           collector is never overwritten; _PAYLOAD_HOME names the directory when the payload runs from elsewhere; a bundle
#           without index.html, or the same directory, copies nothing; a failed copy leaves no collector and exits 1; on the
#           device the note is one LOG line. The repo's own payload directory (no collector in it) is the install route of
#           every case above.
PUI_BAD=""; PUI_B="$PUI_T/bundle"
pui_bundle() {   # pui_bundle [index] -> a fresh bundle dir (payload + stand-ins, 0644) and an absent STARCHORUS_DIR
  pui_kill; rm -rf "$PUI_D" "$PUI_B"; mkdir -p "$PUI_B"
  cp "$PUI_PL" "$PUI_T/tpl/starchorus-collect.sh" "$PUI_T/tpl/starchorus-display.sh" "$PUI_B/"
  printf '#!/bin/sh\n# stand-in fallback server\nexit 0\n' > "$PUI_B/starchorus-serve.sh"
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
rowif "payload ui: bundle installs itself once into an empty dir, never over an installed collector (bad:${PUI_BAD:- none})" [ -z "$PUI_BAD" ]

pui_kill
# whatever a red case left behind (every stand-in runs from $PUI_T)
# shellcheck disable=SC2046
kill $("$PUI_PS" -A -ww -o pid= -o args= | awk -v t="$PUI_T/" 'index($0, t) && !/awk/ { print $1 }') 2>/dev/null
rm -rf "$PUI_T"
fi
