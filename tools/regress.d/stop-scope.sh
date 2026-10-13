# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/stop-scope.sh -- a `stop` stops what that script started,
# and nothing else on the device. Behavioural, Chrome-free, dev machine only: the scripts under test run for real, with
# stand-ins for the device programs in a throw-away directory (nothing listens, nothing is sent, no real port is bound).
#   starchorus-serve.sh stop   stops only its serve loop, the nc of that loop and the handler processes of its own handler
#                         file (pidfiles, checked against the command line) -- never another process with "netcat" (or
#                         "starchorus-serve.sh", or "nc … -p PORT…") in its command line that someone else started.
#   payload.sh (root)     busybox httpd daemonizes unless it gets -f, so $! would be empty or foreign (the collector started
#                         just before) and `stop` would leave the server running; httpd.pid must hold our server's pid.
#   bind                  every server listens on the management address by default (br-lan from a stand-in `ip`), on an
#                         explicit address, or on 0.0.0.0 only for `all`; a nc without -s does not start unless `all`; the
#                         stop matcher takes -p ADDR:PORT as well as -p PORT and still needs our own -h directory; and no
#                         server start line in the three scripts listens on every interface by default (static).
# Stand-ins, all in $STP_T/bin (first on PATH): nc (a GNU-netcat listener that never gets a client; `-h` names -s like
# GNU netcat 0.7.1), busybox (the applet list names httpd; `httpd` without -f forks a server and returns at once, like the
# real applet; with -f it stays in the foreground), ps (BusyBox `ps w` lists EVERY process; macOS/procps `ps w` only those
# with a terminal, so the stand-in maps it to `ps -A -ww -o pid= -o args=`), ip (`ip -4 -o addr` prints $STP_T/ip.out).
# $STP_T/nos/nc is an nc whose help has no -s. The decoys are processes a stop must NOT touch.
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only STP_* globals and stp_* functions are set.

STP_T=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-stp.XXXXXX") || STP_T=""
if [ -z "$STP_T" ] || [ ! -d "$STP_T" ]; then
  row "stop scope: no temp directory" FAIL
else
mkdir -p "$STP_T/bin" "$STP_T/decoy" "$STP_T/other" "$STP_T/nos"
# shellcheck disable=SC2016   # script text for the stand-ins, expanded when they run
printf '#!/bin/sh\n# stand-in GNU netcat: -h prints help naming -s; otherwise a listener that never gets a client\n[ "$1" = -h ] && { echo "  -s, --source=ADDRESS       local source address (ip or hostname)"; exit 0; }\nwhile :; do sleep 1; done\n' > "$STP_T/bin/nc"
# shellcheck disable=SC2016
printf '#!/bin/sh\n# stand-in nc without -s: -h prints help without it\n[ "$1" = -h ] && { echo "  -l  listen mode"; echo "  -p PORT  local port"; exit 0; }\nwhile :; do sleep 1; done\n' > "$STP_T/nos/nc"
# shellcheck disable=SC2016
printf '#!/bin/sh\n# stand-in ip: ip -4 -o addr prints the prepared file\ncat "%s/ip.out"\n' "$STP_T" > "$STP_T/bin/ip"
STP_IPBR='1: lo    inet 127.0.0.1/8 scope host lo\       valid_lft forever preferred_lft forever
5: br-lan    inet 172.16.52.1/24 brd 172.16.52.255 scope global br-lan\       valid_lft forever preferred_lft forever
9: wlan0cli    inet 192.168.77.50/24 brd 192.168.77.255 scope global wlan0cli\       valid_lft forever preferred_lft forever'
printf '%s\n' "$STP_IPBR" > "$STP_T/ip.out"
printf '#!/bin/sh\n# stand-in BusyBox ps w: every process, pid first\nexec /bin/ps -A -ww -o pid= -o args=\n' > "$STP_T/bin/ps"
cat > "$STP_T/bin/busybox" <<'STP_BB'
#!/bin/sh
# stand-in busybox: --list names httpd; httpd daemonizes without -f (fork, parent returns 0), stays in the foreground with -f
case "$1" in
  --list) echo httpd; exit 0 ;;
  httpd) case " $* " in *" -f "*) exec sh "$(dirname "$0")/httpd-srv" "$@" ;; *) sh "$(dirname "$0")/httpd-srv" "$@" >/dev/null 2>&1 & exit 0 ;; esac ;;
esac
exit 1
STP_BB
printf '#!/bin/sh\n# stand-in httpd server process (argv keeps "httpd -h DIR -p PORT")\nwhile :; do sleep 1; done\n' > "$STP_T/bin/httpd-srv"
printf '#!/bin/sh\nwhile :; do sleep 1; done\n' > "$STP_T/decoy/netcat"
printf '#!/bin/sh\nwhile :; do sleep 1; done\n' > "$STP_T/other/starchorus-serve.sh"
printf '#!/bin/sh\nwhile :; do sleep 1; done\n' > "$STP_T/decoy/httpd"
chmod +x "$STP_T/bin/"* "$STP_T/decoy/"* "$STP_T/other/"* "$STP_T/nos/"*
STP_PATH="$STP_T/bin:$PATH"
stp_alive() { kill -0 "$1" 2>/dev/null; }
stp_gone() { # stp_gone PID... -> 0 once none of them runs (up to ~5 s)
  stp_i=0
  while [ "$stp_i" -lt 10 ]; do
    stp_any=0; for stp_p; do stp_alive "$stp_p" && stp_any=1; done
    [ "$stp_any" = 0 ] && return 0
    sleep 1; stp_i=$((stp_i + 2))
  done
  return 1
}
stp_pids() { PATH="$STP_PATH" ps w | awk -v t="$1" 'index($0, t) && !/awk/ { print $1 }' | tr '\n' ' '; }   # stp_pids TEXT
stp_waitfile() { stp_i=0; while [ ! -s "$1" ] && [ "$stp_i" -lt 10 ]; do sleep 1; stp_i=$((stp_i + 1)); done; [ -s "$1" ]; }

# ---- starchorus-serve.sh stop: its own loop, nc and handler go; a netcat, another starchorus-serve.sh and an nc on port PORT0 stay
STP_SD="$STP_T/serve"; mkdir -p "$STP_SD"; : > "$STP_SD/index.html"; STP_PORT=18199
sh "$STP_T/decoy/netcat" -l -p 9 </dev/null >/dev/null 2>&1 & STP_D1=$!
sh "$STP_T/other/starchorus-serve.sh" </dev/null >/dev/null 2>&1 & STP_D2=$!
sh "$STP_T/bin/nc" -l -p "${STP_PORT}0" -c </dev/null >/dev/null 2>&1 & STP_D3=$!
STARCHORUS_DIR="$STP_SD" STARCHORUS_PORT=$STP_PORT PATH="$STP_PATH" sh "$R/starchorus-serve.sh" </dev/null >/dev/null 2>"$STP_T/serve.err" & STP_S=$!
stp_waitfile "$STP_SD/starchorus-serve.pid"; stp_waitfile "$STP_SD/.starchorus-http-nc.pid"
STP_NC=$(sed -n 1p "$STP_SD/.starchorus-http-nc.pid" 2>/dev/null)
STP_H=$(stp_pids "$STP_SD/.starchorus-http-handler.sh")
STP_UP=0; stp_alive "$STP_S" && [ -n "$STP_NC" ] && stp_alive "$STP_NC" && [ -n "$STP_H" ] && STP_UP=1
STP_NCA=$(/bin/ps -o args= -p "${STP_NC:-0}" 2>/dev/null)   # the nc's listening arguments, checked in the bind rows below
STARCHORUS_DIR="$STP_SD" STARCHORUS_PORT=$STP_PORT PATH="$STP_PATH" sh "$R/starchorus-serve.sh" stop >/dev/null 2>&1
# shellcheck disable=SC2086   # STP_H is a pid list on purpose
stp_gone "$STP_S" ${STP_NC:-} $STP_H; STP_OWN=$?
STP_LEFT=$(stp_pids "$STP_SD/"); STP_FILES=""
for stp_f in "$STP_SD/starchorus-serve.pid" "$STP_SD/.starchorus-http-nc.pid" "$STP_SD/.starchorus-http.fifo"; do [ -e "$stp_f" ] && STP_FILES="$STP_FILES ${stp_f##*/}"; done
STP_DEC=""; stp_alive "$STP_D1" || STP_DEC="$STP_DEC netcat"; stp_alive "$STP_D2" || STP_DEC="$STP_DEC other-starchorus-serve.sh"; stp_alive "$STP_D3" || STP_DEC="$STP_DEC nc-port-${STP_PORT}0"
if [ "$STP_UP" = 1 ] && [ "$STP_OWN" = 0 ] && [ -z "$STP_LEFT" ] && [ -z "$STP_FILES" ] && [ -z "$STP_DEC" ]; then row "stop scope: starchorus-serve.sh stop: its loop, nc, handler stopped (up $STP_UP, gone $([ "$STP_OWN" = 0 ] && echo yes || echo no), left:${STP_LEFT:- none}, files:${STP_FILES:- none}); decoys killed:${STP_DEC:- none}" PASS
else row "stop scope: starchorus-serve.sh stop: its loop, nc, handler stopped (up $STP_UP, gone $([ "$STP_OWN" = 0 ] && echo yes || echo no), left:${STP_LEFT:- none}, files:${STP_FILES:- none}); decoys killed:${STP_DEC:- none}" FAIL; fi
# the loop's own TERM trap also stops its nc (a kill of the loop alone, as a payload runner or `kill` would send it)
STARCHORUS_DIR="$STP_SD" STARCHORUS_PORT=$STP_PORT PATH="$STP_PATH" sh "$R/starchorus-serve.sh" </dev/null >/dev/null 2>>"$STP_T/serve.err" & STP_S=$!
rm -f "$STP_SD/.starchorus-http-nc.pid"; stp_waitfile "$STP_SD/.starchorus-http-nc.pid"; STP_NC=$(sed -n 1p "$STP_SD/.starchorus-http-nc.pid" 2>/dev/null)
kill "$STP_S" 2>/dev/null
stp_gone "$STP_S" "${STP_NC:-$STP_S}"; STP_TR=$?
STP_LEFT=$(stp_pids "$STP_SD/")
if [ -n "$STP_NC" ] && [ "$STP_TR" = 0 ] && [ -z "$STP_LEFT" ]; then row "stop scope: starchorus-serve.sh: TERM to the loop stops its nc and handler too (nc ${STP_NC:-none}, gone $([ "$STP_TR" = 0 ] && echo yes || echo no), left:${STP_LEFT:- none})" PASS
else row "stop scope: starchorus-serve.sh: TERM to the loop stops its nc and handler too (nc ${STP_NC:-none}, gone $([ "$STP_TR" = 0 ] && echo yes || echo no), left:${STP_LEFT:- none})" FAIL; fi
# shellcheck disable=SC2046,SC2086
kill $STP_D1 $STP_D2 $STP_D3 $(stp_pids "$STP_SD/") 2>/dev/null
wait "$STP_D1" "$STP_D2" "$STP_D3" 2>/dev/null   # reap the decoys quietly (no "Terminated" job lines in the table)

# ---- root payload.sh with busybox httpd: httpd.pid = the pid of OUR server (not empty, not the collector), and stop stops it;
# an httpd of the same port for another directory stays
STP_PD="$STP_T/payload"; mkdir -p "$STP_PD"; : > "$STP_PD/index.html"
cp "$R/payload.sh" "$STP_PD/payload.sh"
cat > "$STP_PD/starchorus-collect.sh" <<'STP_COL'
#!/bin/sh
# stand-in collector: runs until --stop
if [ "$1" = --stop ]; then [ -f "$STARCHORUS_OUTDIR/col.pid" ] && kill "$(cat "$STARCHORUS_OUTDIR/col.pid")" 2>/dev/null; rm -f "$STARCHORUS_OUTDIR/col.pid"; exit 0; fi
echo $$ > "$STARCHORUS_OUTDIR/col.pid"; while :; do sleep 1; done
STP_COL
chmod +x "$STP_PD/starchorus-collect.sh" "$STP_PD/payload.sh"
sh "$STP_T/decoy/httpd" -h "$STP_T/elsewhere" -p "$STP_PORT" </dev/null >/dev/null 2>&1 & STP_D4=$!
(cd "$STP_PD" && STARCHORUS_DIR="$STP_PD" STARCHORUS_PORT=$STP_PORT PATH="$STP_PATH" sh ./payload.sh </dev/null >/dev/null 2>&1)
STP_HP=$(sed -n 1p "$STP_PD/httpd.pid" 2>/dev/null); STP_CP=$(sed -n 1p "$STP_PD/col.pid" 2>/dev/null)
STP_SRV=$(stp_pids "-h $STP_PD -p 172.16.52.1:$STP_PORT")
STP_HPOK=0; [ -n "$STP_HP" ] && [ "$STP_HP" != "$STP_CP" ] && case " $STP_SRV" in *" $STP_HP "*) STP_HPOK=1 ;; esac
(cd "$STP_PD" && STARCHORUS_DIR="$STP_PD" STARCHORUS_PORT=$STP_PORT PATH="$STP_PATH" sh ./payload.sh stop </dev/null >/dev/null 2>&1)
# shellcheck disable=SC2086
stp_gone $STP_SRV ${STP_CP:-}; STP_PST=$?
STP_PLEFT=$(stp_pids "-h $STP_PD -p 172.16.52.1:$STP_PORT")
STP_PDEC=""; stp_alive "$STP_D4" || STP_PDEC=" httpd-of-another-dir"
if [ "$STP_HPOK" = 1 ] && [ "$STP_PST" = 0 ] && [ -z "$STP_PLEFT" ] && [ ! -f "$STP_PD/httpd.pid" ] && [ -z "$STP_PDEC" ]; then row "stop scope: payload.sh busybox httpd: httpd.pid [${STP_HP:-empty}] = our server [${STP_SRV:-none}] (collector ${STP_CP:-none}), stop leaves:${STP_PLEFT:- nothing}, decoys killed:${STP_PDEC:- none}" PASS
else row "stop scope: payload.sh busybox httpd: httpd.pid [${STP_HP:-empty}] = our server [${STP_SRV:-none}] (collector ${STP_CP:-none}), stop leaves:${STP_PLEFT:- nothing}, decoys killed:${STP_PDEC:- none}" FAIL; fi
# shellcheck disable=SC2046,SC2086
kill $STP_D4 $(stp_pids "$STP_PD") ${STP_CP:-} 2>/dev/null
wait "$STP_D4" 2>/dev/null
# ---- bind · starchorus-serve.sh: the nc of the first run above listened on br-lan; explicit, all, and an nc without -s
stp_serve1() {   # stp_serve1 PATH BIND -> STP_NCA (the nc's arguments, "" if none), STP_RC (exit status if it ended), STP_ERR
  rm -f "$STP_SD/.starchorus-http-nc.pid" "$STP_T/serve1.err"
  STARCHORUS_DIR="$STP_SD" STARCHORUS_PORT=$STP_PORT STARCHORUS_BIND=$2 PATH="$1" sh "$R/starchorus-serve.sh" </dev/null >/dev/null 2>"$STP_T/serve1.err" & stp_s1=$!
  stp_i=0; while [ ! -s "$STP_SD/.starchorus-http-nc.pid" ] && stp_alive "$stp_s1" && [ "$stp_i" -lt 8 ]; do sleep 1; stp_i=$((stp_i + 1)); done
  STP_NCA=""; stp_n1=$(sed -n 1p "$STP_SD/.starchorus-http-nc.pid" 2>/dev/null)
  [ -n "$stp_n1" ] && STP_NCA=$(/bin/ps -o args= -p "$stp_n1" 2>/dev/null)
  STARCHORUS_DIR="$STP_SD" STARCHORUS_PORT=$STP_PORT PATH="$1" sh "$R/starchorus-serve.sh" stop >/dev/null 2>&1
  wait "$stp_s1" 2>/dev/null; STP_RC=$?
  STP_ERR=$(cat "$STP_T/serve1.err" 2>/dev/null)
}
STP_BAD=""
case " $STP_NCA " in *" -l -n -s 172.16.52.1 -p $STP_PORT -c "*) ;; *) STP_BAD="$STP_BAD auto[$STP_NCA]" ;; esac
grep -q "http://172.16.52.1:$STP_PORT/" "$STP_T/serve.err" || STP_BAD="$STP_BAD auto-hint"
stp_serve1 "$STP_PATH" 10.20.30.40
case " $STP_NCA " in *" -l -n -s 10.20.30.40 -p $STP_PORT -c "*) ;; *) STP_BAD="$STP_BAD explicit[$STP_NCA]" ;; esac
stp_serve1 "$STP_PATH" all
case " $STP_NCA " in *" -l -p $STP_PORT -c "*) case $STP_NCA in *" -s "*) STP_BAD="$STP_BAD all-has-s" ;; esac ;; *) STP_BAD="$STP_BAD all[$STP_NCA]" ;; esac
case $STP_ERR in *"every network"*) ;; *) STP_BAD="$STP_BAD all-warning" ;; esac
stp_serve1 "$STP_PATH" 0.0.0.0
case " $STP_NCA " in *" -s 172.16.52.1 "*) ;; *) STP_BAD="$STP_BAD zero-is-not-all[$STP_NCA]" ;; esac
stp_serve1 "$STP_T/nos:$STP_PATH" auto
[ -z "$STP_NCA" ] && [ "$STP_RC" = 1 ] && case $STP_ERR in *"no -s"*) true ;; *) false ;; esac || STP_BAD="$STP_BAD nos-auto[$STP_RC:$STP_NCA]"
stp_serve1 "$STP_T/nos:$STP_PATH" all
case " $STP_NCA " in *" -l -p $STP_PORT -c "*) ;; *) STP_BAD="$STP_BAD nos-all[$STP_NCA]" ;; esac
printf '%s\n' "1: lo    inet 127.0.0.1/8 scope host lo" "9: wlan0cli    inet 192.168.77.50/24 scope global wlan0cli" > "$STP_T/ip.out"
stp_serve1 "$STP_PATH" auto
case " $STP_NCA " in *" -s 127.0.0.1 "*) ;; *) STP_BAD="$STP_BAD lo-fallback[$STP_NCA]" ;; esac
case $STP_ERR in *"127.0.0.1 only"*) ;; *) STP_BAD="$STP_BAD lo-note" ;; esac
printf '%s\n' "$STP_IPBR" > "$STP_T/ip.out"
rowif "stop scope: bind: serve.sh nc -s br-lan by default, explicit, all (no -s, warned), 0.0.0.0 -> auto, nc without -s refuses unless all, 127.0.0.1 fallback (bad:${STP_BAD:- none})" [ -z "$STP_BAD" ]

# ---- bind · root payload.sh: -p ADDR:PORT per STARCHORUS_BIND; stop matches -p PORT and -p ADDR:PORT of our directory only
stp_root() {   # stp_root BIND -> STP_RA (our server's args), STP_RERR; leaves the server running (stp_root_stop ends it)
  rm -f "$STP_PD/httpd.pid"
  (cd "$STP_PD" && STARCHORUS_DIR="$STP_PD" STARCHORUS_PORT=$STP_PORT STARCHORUS_BIND=$1 PATH="$STP_PATH" sh ./payload.sh </dev/null >/dev/null 2>"$STP_T/root.err")
  STP_RA=$(/bin/ps -o args= -p "$(sed -n 1p "$STP_PD/httpd.pid" 2>/dev/null)" 2>/dev/null); STP_RERR=$(cat "$STP_T/root.err" 2>/dev/null)
}
stp_root_stop() { (cd "$STP_PD" && STARCHORUS_DIR="$STP_PD" STARCHORUS_PORT=$STP_PORT PATH="$STP_PATH" sh ./payload.sh stop </dev/null >/dev/null 2>&1); }
STP_BAD=""
stp_root auto
case "$STP_RA " in *" -p 172.16.52.1:$STP_PORT "*) ;; *) STP_BAD="$STP_BAD auto[$STP_RA]" ;; esac
case $STP_RERR in *"http://172.16.52.1:$STP_PORT/"*) ;; *) STP_BAD="$STP_BAD auto-hint" ;; esac
stp_root_stop
stp_root 10.20.30.40
case "$STP_RA " in *" -p 10.20.30.40:$STP_PORT "*) ;; *) STP_BAD="$STP_BAD explicit[$STP_RA]" ;; esac
stp_root_stop
stp_root all
case "$STP_RA " in *" -p 0.0.0.0:$STP_PORT "*) ;; *) STP_BAD="$STP_BAD all[$STP_RA]" ;; esac
case $STP_RERR in *"(all interfaces)"*) ;; *) STP_BAD="$STP_BAD all-hint" ;; esac
stp_root_stop
stp_root 0.0.0.0
case "$STP_RA " in *" -p 172.16.52.1:$STP_PORT "*) ;; *) STP_BAD="$STP_BAD zero-is-not-all[$STP_RA]" ;; esac
case $STP_RERR in *"ignored"*) ;; *) STP_BAD="$STP_BAD zero-note" ;; esac
stp_root_stop
printf '%s\n' "1: lo    inet 127.0.0.1/8 scope host lo" "4: eth1    inet 172.16.52.1/24 scope global eth1" > "$STP_T/ip.out"
stp_root auto
case "$STP_RA " in *" -p 172.16.52.1:$STP_PORT "*) ;; *) STP_BAD="$STP_BAD no-br-lan[$STP_RA]" ;; esac
stp_root_stop
printf '%s\n' "1: lo    inet 127.0.0.1/8 scope host lo" "9: wlan0cli    inet 192.168.77.50/24 scope global wlan0cli" > "$STP_T/ip.out"
stp_root auto
case "$STP_RA " in *" -p 127.0.0.1:$STP_PORT "*) ;; *) STP_BAD="$STP_BAD lo[$STP_RA]" ;; esac
case $STP_RERR in *"127.0.0.1 only"*) ;; *) STP_BAD="$STP_BAD lo-note" ;; esac
stp_root_stop
printf '%s\n' "$STP_IPBR" > "$STP_T/ip.out"
# no pid file: the sweep stops ours in both forms (-p ADDR:PORT, the old -p PORT), not the same address:port of another
# directory, not the device's own uhttpd on :80/:1471, not a server whose port is only a stray argument
# (started from a command substitution: not jobs of this shell, so their end prints no job line)
STP_O1=$(sh "$STP_T/bin/httpd-srv" httpd -f -h "$STP_PD" -p "172.16.52.1:$STP_PORT" </dev/null >/dev/null 2>&1 & echo $!)
STP_O2=$(sh "$STP_T/bin/httpd-srv" httpd -f -h "$STP_PD" -p "$STP_PORT" </dev/null >/dev/null 2>&1 & echo $!)
STP_D5=$(sh "$STP_T/decoy/httpd" uhttpd -f -p "172.16.52.1:$STP_PORT" -h /www </dev/null >/dev/null 2>&1 & echo $!)
STP_D6=$(sh "$STP_T/decoy/httpd" uhttpd -f -p 172.16.52.1:1471 -p 80 -h /www </dev/null >/dev/null 2>&1 & echo $!)
STP_D7=$(sh "$STP_T/decoy/httpd" uhttpd -f -p 80 -h "$STP_PD" "$STP_PORT" </dev/null >/dev/null 2>&1 & echo $!)
sleep 1
rm -f "$STP_PD/httpd.pid"; stp_root_stop
stp_gone "$STP_O1" "$STP_O2" || STP_BAD="$STP_BAD ours-left"
for stp_p in "$STP_D5" "$STP_D6" "$STP_D7"; do stp_alive "$stp_p" || STP_BAD="$STP_BAD decoy-killed:$stp_p"; done
kill "$STP_O1" "$STP_O2" "$STP_D5" "$STP_D6" "$STP_D7" 2>/dev/null
rowif "stop scope: bind: root payload -p br-lan:PORT by default, explicit, all, 0.0.0.0 -> auto, 172.16.52.1 / 127.0.0.1 fallbacks; stop takes -p ADDR:PORT and -p PORT of our dir only (bad:${STP_BAD:- none})" [ -z "$STP_BAD" ]

# ---- bind · static: no server start line in the three scripts listens on every interface by default. Every uhttpd/busybox
# httpd start carries -p "$ADDR:" / -p "$PL_ADDR:", every python http.server --bind, the nc's arguments are the two `set --`
# lines of starchorus-serve.sh (one with -s "$ADDR", the other only under ADDR = 0.0.0.0), and 0.0.0.0 is produced only in an
# `all)` branch.
STP_SF="payload.sh library/user/reconnaissance/starchorus/payload.sh starchorus-serve.sh"
# shellcheck disable=SC2086   # file list
STP_ST=$(awk '
  /^[[:space:]]*#/ { next }
  { l = $0; sub(/[[:space:]]#.*/, "", l) }
  l ~ /(^|[[:space:]])(uhttpd|busybox httpd) -/ { n++; if (l !~ /-p "\$(PL_)?ADDR:/) { bad++; print "bad: " FILENAME ": " l } }
  l ~ /http\.server "\$/ { n++; py++; if (l !~ /--bind "\$(PL_)?ADDR"/) { bad++; print "bad: " FILENAME ": " l } }
  l ~ /\$NC" "\$@"/ { n++ }
  l ~ /(echo |ADDR=)0\.0\.0\.0/ && l !~ /all\)/ { bad++; print "bad zero: " FILENAME ": " l }
  END { print "n=" n + 0 " py=" py + 0 " bad=" bad + 0 }' $STP_SF)
STP_SN=$(printf '%s\n' "$STP_ST" | sed -n 's/^n=\([0-9]*\) py=\([0-9]*\) bad=\([0-9]*\)$/\1 \2 \3/p')
# shellcheck disable=SC2016   # the patterns are literal script text
STP_NS=$(grep -c '^[[:space:]]*set -- -l' starchorus-serve.sh)
# shellcheck disable=SC2016
STP_NSS=$(grep -c '^[[:space:]]*set -- -l -n -s "\$ADDR" -p "\$PORT" -c$' starchorus-serve.sh)
# shellcheck disable=SC2016
STP_NALL=$(grep -A2 '^if \[ "\$ADDR" = 0\.0\.0\.0 \]; then$' starchorus-serve.sh | grep -c '^[[:space:]]*set -- -l -p "\$PORT" -c$')
# shellcheck disable=SC2086
set -- $STP_SN
rowif "stop scope: bind static: ${1:-0} server start lines (${2:-0} python), none on every interface by default; nc set -- $STP_NS (-s $STP_NSS, all-only $STP_NALL) (bad ${3:-?})" \
  [ "${3:-1}" = 0 ] && ge "${1:-0}" 6 && [ "${2:-0}" = 2 ] && [ "$STP_NS/$STP_NSS/$STP_NALL" = 2/1/1 ]
[ "${3:-1}" = 0 ] || printf '%s\n' "$STP_ST" | grep '^bad' | sed 's/^/    /' | head -n 6

# whatever a FAILED stop left behind (every stand-in and handler runs from $STP_T), so a red run leaves no process either
# shellcheck disable=SC2046
kill $(stp_pids "$STP_T/") 2>/dev/null
rm -rf "$STP_T"
fi
