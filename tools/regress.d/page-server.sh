# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/page-server.sh -- starchorus-serve.sh: what the page server sends, and how long one client may hold it.
# Behavioural, Chrome-free, dev machine only: the script and the handler it writes run for real, with stand-ins for the device
# programs in a throw-away directory (an nc that plays a scripted client, ps, sed -i, a wc that lets the collector's mv land):
# nothing listens, nothing is sent, no real port is bound. A copy of the script has its limits shortened (IDLE and SLOW to a
# second, LIFE to two); its other text is the script's.
#   P1 answers    GET and HEAD of both files, a 404, a POST, a missing file: status, Content-Length = the bytes that follow, body =
#                 the file, Cache-Control no-store on starchorus.json and max-age=60 on the page, Connection: close, the 404 byte
#                 for byte as it always was; under every shell found here (sh, dash, bash). BusyBox ash, the device's shell, is
#                 not on this machine: its read -t, tr and /proc are read from its source and documentation, not run (tools/README.md).
#   P2 CORS       no Access-Control-* header in any of those answers; a handler that sends one is caught
#   P3 snapshot   starchorus.json replaced by mv between the measuring and the sending: the answer is still one file, with its own
#                 length; the copy is mode 600 and gone afterwards; no copy possible -> 503, never a short body; a "copy" that only
#                 links to the live file is caught
#   P4 limits     (handler alone, every shell found here) a client that sends nothing, or none at all, is given up after IDLE and its
#                 nc stopped -- also where the shell has no read -t (dash, or a handler made to believe so); a late client likewise;
#                 one that stops in the headers is answered after SLOW (read -t shells), or ended after LIFE (without); one that does
#                 not read its answer is given up after LIFE and its nc stopped; a pid in the pidfile that is not our nc is left
#                 alone; every limit has a control (a long one) that is still waiting when the limit would have struck. The idle nc
#                 is stopped from its /proc entry, in one look, where the system has one (a fake /proc here: ps is not called, the
#                 same handler without it does call ps), and from ps where not
#   P5 server     (script + handler + FIFO + stand-in nc) a request is answered and the next one too; a silent client is dropped
#                 and the next one served; a quiet listener is replaced after IDLE; an answer nobody reads is ended; stop ends all
#                 of it and removes the copy a killed handler left, of its port only
# Sourced by tools/regress.sh and tools/quick.sh with cwd = repo root, after the core rows. Only SRV_* names and srv_* functions are set.

SRV_T=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-srv.XXXXXX") || SRV_T=""
if [ -z "$SRV_T" ] || [ ! -d "$SRV_T" ]; then
  row "page server: no temp directory" FAIL
else
SRV_PORT=18299; SRV_KEEP=0; SRV_CR=$(printf '\r')
SRV_SED=$(command -v sed); SRV_WC=$(command -v wc); SRV_SH=$(command -v sh)
SRV_D="$SRV_T/data"; SRV_TMP="$SRV_T/tmp"; SRV_Q="$SRV_T/q"; SRV_ST="$SRV_T/stand"; SRV_B="$SRV_T/bin"
mkdir -p "$SRV_D" "$SRV_TMP" "$SRV_Q" "$SRV_ST"
export SRV_SED SRV_WC SRV_Q

# ---- data: a page, three versions of the capture (A, B of another length, BIG larger than any pipe)
{ printf '<!doctype html><title>page</title>\n'; awk 'BEGIN { for (i = 1; i <= 40; i++) printf "<p>line %d of the page</p>\n", i }'; } > "$SRV_D/index.html"
SRV_JA="$SRV_T/json.a"; SRV_JB="$SRV_T/json.b"; SRV_JBIG="$SRV_T/json.big"
printf '{"generated":1,"aps":[]}\n' > "$SRV_JA"
awk 'BEGIN { printf "{\"generated\":2,\"aps\":[\n"; for (i = 1; i <= 30; i++) printf "{\"i\":%d,\"ssid\":\"net-%d\"},\n", i, i; printf "{}]}\n" }' > "$SRV_JB"
awk 'BEGIN { for (i = 1; i <= 12000; i++) printf "{\"mac\":\"aa:bb:cc:dd:%02x:%02x\",\"i\":%d}\n", int(i / 256), i % 256, i }' > "$SRV_JBIG"
cp "$SRV_JA" "$SRV_D/starchorus.json"
printf 'HTTP/1.0 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: 9\r\nConnection: close\r\n\r\nnot found' > "$SRV_T/404.exp"
printf 'HTTP/1.0 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: 9\r\nConnection: close\r\n\r\n' > "$SRV_T/404h.exp"

# ---- stand-ins (all in $SRV_ST; the PATH directories link them in beside the basic tools)
cat > "$SRV_ST/ps" <<'SRV_X'
#!/bin/sh
# stand-in BusyBox ps w: every process, pid first; a call is logged when $SRV_PSLOG names a file
[ -z "$SRV_PSLOG" ] || echo ps >> "$SRV_PSLOG"
exec /bin/ps -A -ww -o pid= -o args=
SRV_X
cat > "$SRV_ST/sed" <<'SRV_X'
#!/bin/sh
# stand-in BusyBox sed: -i SCRIPT FILE edits in place (BSD sed wants a suffix after -i); anything else is the real sed
if [ "$1" = -i ]; then "$SRV_SED" "$2" "$3" > "$3.new" && mv "$3.new" "$3"; else exec "$SRV_SED" "$@"; fi
SRV_X
cat > "$SRV_ST/nc" <<'SRV_X'
#!/bin/sh
# stand-in GNU netcat (listener, -c): -h names -s; otherwise it takes the first client queued in $SRV_Q -- a sh snippet whose stdout
# is the request and whose stdin is the answer -- when it starts, or, with none queued, is a listener nobody calls. Looking only once
# keeps a client from reaching the handler at the edge of its IDLE: it arrives a few milliseconds into the round.
[ "$1" = -h ] && { echo "  -s, --source=ADDRESS       local source address (ip or hostname)"; exit 0; }
echo "$$" >> "$SRV_Q/nc.started"; [ -z "$SRV_NCPID" ] || echo "$$" > "$SRV_NCPID"
# with $SRV_PROC (a fake /proc) it also has an entry there, as the kernel would give it: its command line, NUL after each word
[ -z "$SRV_PROC" ] || { mkdir -p "$SRV_PROC/$$"; { printf 'nc\0'; for a in "$@"; do printf '%s\0' "$a"; done; } > "$SRV_PROC/$$/cmdline"; }
for c in "$SRV_Q"/*.client; do [ -f "$c" ] && break; c=""; done
if [ -n "$c" ]; then
    mv "$c" "$c.taken"; echo "$$ ${c##*/}" >> "$SRV_Q/nc.took"
    . "$c.taken"
else
    while :; do sleep 1; done
fi
SRV_X
cat > "$SRV_ST/wc" <<'SRV_X'
#!/bin/sh
# stand-in wc: counts as wc does, logs what the copy looks like, then lets the collector's mv land (once): $SRV_D/.next
# becomes starchorus.json
"$SRV_WC" "$@"; r=$?
ls -l "$TMPDIR"/starchorus-http-* >> "$SRV_D/wc.log" 2>/dev/null
[ -f "$SRV_D/.next" ] && mv "$SRV_D/.next" "$SRV_D/starchorus.json"
exit $r
SRV_X
# shellcheck disable=SC2016   # script text for the stand-ins, expanded when they run
printf '#!/bin/sh\n# stand-in cp that does not copy: its "copy" is a link, read when the name is read\nrm -f "$2"; ln -s "$1" "$2"\n' > "$SRV_ST/cp-link"
printf '#!/bin/sh\n# stand-in cp that always fails\nexit 1\n' > "$SRV_ST/cp-fail"
printf '#!/bin/sh\n# a process that is not our nc (no -p PORT -c in its command line)\nwhile :; do sleep 1; done\n' > "$SRV_ST/decoy"
chmod +x "$SRV_ST"/*
srv_mkbin() {   # srv_mkbin DIR [NAME...]: DIR holds the basic tools, the stand-ins nc ps sed and the stand-ins named (wc ...)
  mkdir -p "$1"; srv_bd=$1; shift
  for srv_n in awk cat chmod cp date grep head ln ls mkdir mkfifo mktemp mv rm sleep tail tr wc; do
    srv_p=$(command -v "$srv_n") && case $srv_p in /*) ln -sf "$srv_p" "$srv_bd/$srv_n" ;; esac
  done
  for srv_n in nc ps sed "$@"; do ln -sf "$SRV_ST/${srv_n%%:*}" "$srv_bd/${srv_n##*:}"; done
}
srv_mkbin "$SRV_B"; srv_mkbin "$SRV_T/binw" wc; srv_mkbin "$SRV_T/binl" wc cp-link:cp; srv_mkbin "$SRV_T/binf" cp-fail:cp

# ---- shells: every one found here (not the same binary twice); SRV_RTS = those with read -t, SRV_RT = the first of them
srv_has_rt() { "$1" -c 'read -t 1 -r v </dev/null 2>/dev/null; [ $? -le 1 ]' 2>/dev/null; }
SRV_SHELLS=""; SRV_SHN=0; SRV_RTS=""; SRV_RT=""; SRV_DASH=""
for srv_c in sh dash bash; do
  srv_p=$(command -v "$srv_c") || continue
  case $srv_p in /*) ;; *) continue ;; esac
  srv_dup=0; for srv_o in $SRV_SHELLS; do cmp -s "$srv_p" "$srv_o" && srv_dup=1; done
  [ "$srv_dup" = 0 ] || continue
  SRV_SHELLS="$SRV_SHELLS $srv_p"; SRV_SHN=$((SRV_SHN + 1))
  if srv_has_rt "$srv_p"; then SRV_RTS="$SRV_RTS $srv_p"; [ -n "$SRV_RT" ] || SRV_RT=$srv_p
  elif [ "$srv_c" = dash ] || [ -z "$SRV_DASH" ]; then SRV_DASH=$srv_p; fi
done

# ---- helpers
srv_nfiles() { srv_nf=0; for srv_f in "$1"/* "$1"/.[!.]*; do [ -e "$srv_f" ] && srv_nf=$((srv_nf + 1)); done; echo "$srv_nf"; }   # entries in a directory
srv_size() { echo $(($(wc -c < "$1"))); }   # bytes of a file, as a plain number
srv_until() {   # srv_until SECONDS CMD...: 0 as soon as CMD succeeds, 1 after SECONDS
  srv_i=0; srv_nn=$(($1 * 5)); shift
  while [ "$srv_i" -lt "$srv_nn" ]; do "$@" && return 0; sleep 0.2; srv_i=$((srv_i + 1)); done
  "$@"
}
srv_pids() { "$SRV_ST/ps" | awk -v t="$1" 'index($0, t) && !/awk/ { print $1 }' | tr '\n' ' '; }   # pids whose command line holds TEXT
srv_parse() {   # srv_parse FILE: an answer -> SRV_HEAD (header lines, CR removed), SRV_HLEN (bytes up to the blank line), FILE.body
  SRV_HEAD=""; SRV_HLEN=0
  while IFS= read -r srv_l; do
    SRV_HLEN=$((SRV_HLEN + ${#srv_l} + 1)); srv_l=${srv_l%"$SRV_CR"}
    [ -n "$srv_l" ] || break
    SRV_HEAD="$SRV_HEAD$srv_l
"
  done < "$1"
  tail -c +$((SRV_HLEN + 1)) "$1" > "$1.body"
}
srv_hdr() { printf '%s' "$SRV_HEAD" | sed -n "s/^$1: *//p"; }   # the value of one header of the parsed answer
srv_whole() {   # srv_whole OUTFILE FILE: OUTFILE is a whole 200 answer that carries FILE
  srv_parse "$1"
  [ "$(printf '%s' "$SRV_HEAD" | sed -n 1p)" = "HTTP/1.0 200 OK" ] && [ "$(srv_hdr Content-Length)" = "$(srv_size "$2")" ] && cmp -s "$1.body" "$2"
}
srv_ask() {   # srv_ask SHELL HANDLER TAG 'REQUEST LINE' [PATH]: that request on stdin, the answer to TAG.out, parsed
  printf '%s\r\nHost: x\r\nAccept: */*\r\n\r\n' "$4" | PATH="${5:-$SRV_B}" TMPDIR="$SRV_TMP" SRV_D="$SRV_D" "$1" "$2" > "$SRV_T/$3.out" 2>"$SRV_T/$3.err"
  srv_parse "$SRV_T/$3.out"
}
srv_bad() { SRV_BADS="$SRV_BADS [$1]"; }
srv_note() { SRV_NANS=$((SRV_NANS + 1)); SRV_CORS=$((SRV_CORS + $(printf '%s' "$SRV_HEAD" | grep -ci '^access-control-'))); }
srv_file() {   # srv_file SHELL TAG 'REQUEST' FILE CACHE-CONTROL: a 200 answer that is that file (HEAD: its length, no body)
  srv_ask "$1" "$SRV_H" "$2" "$3"; srv_note
  [ "$(printf '%s' "$SRV_HEAD" | sed -n 1p)" = "HTTP/1.0 200 OK" ] || srv_bad "$2 status"
  [ "$(srv_hdr Content-Length)" = "$(srv_size "$4")" ] || srv_bad "$2 Content-Length"
  case $3 in
    HEAD*) [ "$(srv_size "$SRV_T/$2.out.body")" = 0 ] || srv_bad "$2 HEAD body" ;;
    *) cmp -s "$SRV_T/$2.out.body" "$4" || srv_bad "$2 body" ;;
  esac
  [ "$(srv_hdr Cache-Control)" = "$5" ] || srv_bad "$2 Cache-Control"
  [ "$(srv_hdr Connection)" = close ] || srv_bad "$2 Connection"
}
srv_404() {   # srv_404 SHELL TAG 'REQUEST' EXPECTED-FILE: the answer is exactly that file
  srv_ask "$1" "$SRV_H" "$2" "$3"; srv_note
  cmp -s "$SRV_T/$2.out" "$4" || srv_bad "$2 bytes"
}

# ---- the script under test: a copy with short limits and the shebangs on a shell that has read -t
SRV_S="$SRV_T/starchorus-serve.sh"   # the name matters: stop looks for "starchorus-serve" in the command line of the loop
"$SRV_SED" -e 's/^IDLE=[0-9]*/IDLE=1/' -e 's/^SLOW=[0-9]*/SLOW=1/' -e 's/^LIFE=[0-9]*/LIFE=2/' \
    -e "s|^#!/bin/sh\$|#!${SRV_RT:-/bin/sh}|" "$R/starchorus-serve.sh" > "$SRV_S"
SRV_CN=$(grep -c '^IDLE=1 \|^SLOW=1 \|^LIFE=2 ' "$SRV_S")
srv_start() {   # srv_start PATH: the server in the background, SRV_PID its pid
  STARCHORUS_DIR="$SRV_D" STARCHORUS_PORT=$SRV_PORT STARCHORUS_BIND=127.0.0.1 TMPDIR="$SRV_TMP" PATH="$1" "${SRV_RT:-sh}" "$SRV_S" </dev/null >/dev/null 2>"$SRV_T/serve.err" &
  SRV_PID=$!
}
srv_stop() { STARCHORUS_DIR="$SRV_D" STARCHORUS_PORT=$SRV_PORT TMPDIR="$SRV_TMP" PATH="$1" "${SRV_RT:-sh}" "$SRV_S" stop >/dev/null 2>&1; }
srv_ncn() { [ -f "$SRV_Q/nc.started" ] && echo $(($(wc -l < "$SRV_Q/nc.started"))) || echo 0; }   # nc processes started so far
srv_lastnc() { tail -n 1 "$SRV_Q/nc.started" 2>/dev/null; }
# shellcheck disable=SC2317,SC2329   # named as an argument of srv_until
srv_ncmore() { [ "$(srv_ncn)" -gt "$1" ]; }   # more than N nc processes have started
# shellcheck disable=SC2317,SC2329   # named as an argument of srv_until
srv_haveresp() { [ -s "$SRV_Q/resp.$1" ]; }
srv_client() {   # srv_client DIR NN KIND [PATH]: queue a scripted client: get (sends the request, reads the answer), hdr (stops after one header),
  # late (the request after 2.5 s), silent, stall (sends it, never reads)
  { case $3 in
      get)    printf '%s\n' "printf 'GET $4 HTTP/1.0\\r\\nHost: x\\r\\n\\r\\n'" "cat > \"\$SRV_Q/resp.$2\"" ;;
      hdr)    printf '%s\n' "printf 'GET $4 HTTP/1.0\\r\\nHost: x\\r\\n'" "cat > \"\$SRV_Q/resp.$2\"" ;;
      late)   printf '%s\n' 'sleep 2.5' "printf 'GET $4 HTTP/1.0\\r\\n\\r\\n'" "cat > \"\$SRV_Q/resp.$2\"" ;;
      silent) printf '%s\n' 'while :; do sleep 1; done' ;;
      stall)  printf '%s\n' "printf 'GET $4 HTTP/1.0\\r\\n\\r\\n'" 'while :; do sleep 1; done' ;;
    esac; } > "$1/$2.client.new" && mv "$1/$2.client.new" "$1/$2.client"
}

# ---- the handler the real script wrote: start the copy once (its stand-in nc idle), take the handler file, stop it
srv_start "$SRV_B"
srv_until 6 test -s "$SRV_D/.starchorus-http-nc.pid"; srv_until 2 test -x "$SRV_D/.starchorus-http-handler.sh"
srv_stop "$SRV_B"; wait "$SRV_PID" 2>/dev/null
SRV_H="$SRV_T/handler.sh"; cp "$SRV_D/.starchorus-http-handler.sh" "$SRV_H" 2>/dev/null
SRV_HOK=0
if [ -s "$SRV_H" ] && [ "$SRV_CN" = 3 ] && ! grep -q '__DIR__\|__PORT__' "$SRV_H" && [ "$(grep -c "^DIR=\"$SRV_D\"\$" "$SRV_H")" = 1 ] \
   && [ "$(grep -c "^PORT=$SRV_PORT\$" "$SRV_H")" = 1 ] && [ "$(grep -c '^IDLE=1 ' "$SRV_H")" = 1 ]; then SRV_HOK=1; fi
rowif "page server: the script writes its handler with directory and port baked in, limits as set ($SRV_CN/3)" [ "$SRV_HOK" = 1 ]
[ "$SRV_HOK" = 1 ] || { SRV_KEEP=1; echo "    serve.err: $(head -n 3 "$SRV_T/serve.err" 2>/dev/null | tr '\n' '|')"; }

if [ "$SRV_HOK" = 1 ]; then
# ---- P1 / P2 answers under every shell, and the CORS header
SRV_BADS=""; SRV_NANS=0; SRV_CORS=0
for SRV_X in $SRV_SHELLS; do
  SRV_N=$(basename "$SRV_X")
  srv_file "$SRV_X" "$SRV_N-json" 'GET /starchorus.json?_=123 HTTP/1.1' "$SRV_JA" no-store
  srv_file "$SRV_X" "$SRV_N-root" 'GET / HTTP/1.1' "$SRV_D/index.html" max-age=60
  srv_file "$SRV_X" "$SRV_N-index" 'GET /index.html?x=1 HTTP/1.0' "$SRV_D/index.html" max-age=60
  srv_file "$SRV_X" "$SRV_N-hjson" 'HEAD /starchorus.json HTTP/1.1' "$SRV_JA" no-store
  srv_file "$SRV_X" "$SRV_N-hroot" 'HEAD / HTTP/1.1' "$SRV_D/index.html" max-age=60
  srv_404 "$SRV_X" "$SRV_N-nope" 'GET /nope HTTP/1.1' "$SRV_T/404.exp"
  srv_404 "$SRV_X" "$SRV_N-hnope" 'HEAD /nope HTTP/1.1' "$SRV_T/404h.exp"
  srv_404 "$SRV_X" "$SRV_N-post" 'POST /starchorus.json HTTP/1.1' "$SRV_T/404.exp"
  mv "$SRV_D/starchorus.json" "$SRV_D/starchorus.gone"
  srv_404 "$SRV_X" "$SRV_N-absent" 'GET /starchorus.json HTTP/1.1' "$SRV_T/404.exp"
  mv "$SRV_D/starchorus.gone" "$SRV_D/starchorus.json"
done
rowif "page server: GET/HEAD/404/POST/absent file answered, Content-Length = body, cache headers ($SRV_NANS answers, $SRV_SHN shells; bad:${SRV_BADS:- none})" \
  [ -z "$SRV_BADS" ] && [ "$SRV_NANS" -ge 9 ]
# negative control: the handler with that header added is seen by the same count
# shellcheck disable=SC2016   # sed script, not shell
"$SRV_SED" 's/"Cache-Control: \$cc"/"Cache-Control: $cc" "Access-Control-Allow-Origin: *"/' "$SRV_H" > "$SRV_T/cors.h"
srv_ask "${SRV_RT:-sh}" "$SRV_T/cors.h" cors 'GET /starchorus.json HTTP/1.1'
SRV_CORSMUT=$(printf '%s' "$SRV_HEAD" | grep -ci '^access-control-')
rowif "page server: no Access-Control header in $SRV_NANS answers ($SRV_CORS found); a handler that sends one is seen ($SRV_CORSMUT)" \
  [ "$SRV_CORS" = 0 ] && [ "$SRV_CORSMUT" = 1 ] && ! cmp -s "$SRV_H" "$SRV_T/cors.h"

# ---- P3 snapshot: the collector's mv lands between the measuring and the sending (the wc stand-in lands it)
srv_swap() {   # srv_swap TAG PATH: GET starchorus.json with a replacement (B) staged to land after the length is taken -> SRV_SWAPPED
  cp "$SRV_JA" "$SRV_D/starchorus.json"; cp "$SRV_JB" "$SRV_D/.next"; rm -f "$SRV_D/wc.log"
  srv_ask "${SRV_RT:-sh}" "$SRV_H" "$1" 'GET /starchorus.json HTTP/1.1' "$2"
  SRV_SWAPPED=0; [ ! -e "$SRV_D/.next" ] && cmp -s "$SRV_D/starchorus.json" "$SRV_JB" && SRV_SWAPPED=1
  cp "$SRV_JA" "$SRV_D/starchorus.json"; rm -f "$SRV_D/.next"
}
srv_swap swap "$SRV_T/binw"
SRV_CL=$(srv_hdr Content-Length); SRV_BL=$(srv_size "$SRV_T/swap.out.body"); SRV_LEFT=$(srv_nfiles "$SRV_TMP")
SRV_MODE=$(sed -n 's/^\(-[rwx-]*\).*/\1/p' "$SRV_D/wc.log" 2>/dev/null | head -n 1)
SRV_P3=0
[ "$SRV_SWAPPED" = 1 ] && [ "$SRV_CL" = "$SRV_BL" ] && cmp -s "$SRV_T/swap.out.body" "$SRV_JA" && [ "$SRV_LEFT" = 0 ] && [ "$SRV_MODE" = "-rw-------" ] && SRV_P3=1
rowif "page server: starchorus.json replaced in mid-answer: Content-Length $SRV_CL = body $SRV_BL, one file; copy mode ${SRV_MODE:-none}, left in /tmp: $SRV_LEFT" [ "$SRV_P3" = 1 ]
srv_swap link "$SRV_T/binl"
SRV_CL=$(srv_hdr Content-Length); SRV_BL=$(srv_size "$SRV_T/link.out.body")
rowif "page server: a copy that only links to the live file is caught (Content-Length $SRV_CL, body $SRV_BL)" [ "$SRV_SWAPPED" = 1 ] && [ "$SRV_CL" != "$SRV_BL" ]
rm -f "$SRV_TMP"/starchorus-http-*
# no copy possible: nowhere to put it, and a cp that fails -> 503 with its own length, no body of the file, nothing left behind
SRV_BADS=""
printf '%s\r\nHost: x\r\n\r\n' 'GET /starchorus.json HTTP/1.1' | PATH="$SRV_B" TMPDIR="$SRV_T/no-such-dir" "${SRV_RT:-sh}" "$SRV_H" > "$SRV_T/notmp.out" 2>/dev/null
srv_parse "$SRV_T/notmp.out"
[ "$(printf '%s' "$SRV_HEAD" | sed -n 1p)" = "HTTP/1.0 503 Service Unavailable" ] && [ "$(srv_hdr Content-Length)" = "$(srv_size "$SRV_T/notmp.out.body")" ] && [ "$(cat "$SRV_T/notmp.out.body")" = unavailable ] || srv_bad "no TMPDIR"
srv_ask "${SRV_RT:-sh}" "$SRV_H" cpfail 'GET /starchorus.json HTTP/1.1' "$SRV_T/binf"
[ "$(printf '%s' "$SRV_HEAD" | sed -n 1p)" = "HTTP/1.0 503 Service Unavailable" ] && [ "$(srv_hdr Content-Length)" = "$(srv_size "$SRV_T/cpfail.out.body")" ] && [ "$(cat "$SRV_T/cpfail.out.body")" = unavailable ] || srv_bad "cp fails"
[ "$(srv_nfiles "$SRV_TMP")" = 0 ] || srv_bad "left behind"
rowif "page server: no copy possible (no /tmp, cp fails) -> 503 with its own length, nothing left (bad:${SRV_BADS:- none})" [ -z "$SRV_BADS" ]

# ---- P4 limits, the handler alone, in the wiring the serve loop gives it: its stdin is a FIFO that the stand-in nc writes, its stdout
# a pipe into that nc. Every case runs in the background in a directory of its own, the cases of all shells side by side. The
# handler "waits" if it is still there at the end of the watch: a limit that works ends it early, its control (a long limit) does not.
srv_alive() { [ -n "$1" ] && "$SRV_ST/ps" | awk -v p="$1" -v t="$2" '$1 == p && index($0, t) { f = 1 } END { exit !f }'; }   # pid running, text in its command line
srv_kase() {   # srv_kase SHELL TAG LIMIT KIND [SED-SCRIPT] [decoy]: KIND = quiet hdr late stall (a client script of srv_client) -> TAG.res
  srv_kd="$SRV_T/$2.d"; srv_kq="$SRV_T/$2.q"; mkdir -p "$srv_kd" "$srv_kq"
  cp "$SRV_D/index.html" "$srv_kd/index.html"; cp "$SRV_JA" "$srv_kd/starchorus.json"
  [ "$4" != stall ] || cp "$SRV_JBIG" "$srv_kd/starchorus.json"
  "$SRV_SED" -e "s|^DIR=.*|DIR=\"$srv_kd\"|" -e "${5:-s/zz-no-match//}" "$SRV_H" > "$SRV_T/$2.h"
  case $4 in quiet) srv_client "$srv_kq" 01 silent ;; *) srv_client "$srv_kq" 01 "$4" /starchorus.json ;; esac
  mkfifo "$SRV_T/$2.fifo"; rm -f "$SRV_T/$2.hdone"; srv_np="$srv_kd/.starchorus-http-nc.pid"
  srv_dp=""
  if [ "$6" = decoy ]; then
    "$SRV_SH" "$SRV_ST/decoy" </dev/null >/dev/null 2>&1 & srv_dp=$!; echo "$srv_dp" > "$srv_np"; srv_np=""
    mkdir -p "$SRV_T/proc/$srv_dp"; printf 'sh\0%s\0' "$SRV_ST/decoy" > "$SRV_T/proc/$srv_dp/cmdline"   # its entry in the fake /proc
  fi
  # shellcheck disable=SC2094  # reading+writing the FIFO in one pipeline IS the wiring under test
  ( ( PATH="$SRV_B" TMPDIR="$SRV_TMP" SRV_PSLOG="$SRV_T/$2.ps" "$1" "$SRV_T/$2.h" < "$SRV_T/$2.fifo"; : > "$SRV_T/$2.hdone" ) \
    | PATH="$SRV_B" SRV_Q="$srv_kq" SRV_NCPID="$srv_np" SRV_PROC="$SRV_T/proc" "$SRV_SH" "$SRV_ST/nc" -l -n -s 127.0.0.1 -p "$SRV_PORT" -c > "$SRV_T/$2.fifo" ) >/dev/null 2>&1 &
  srv_w=0; while [ ! -f "$SRV_T/$2.hdone" ] && [ "$srv_w" -lt $(($3 * 10)) ]; do sleep 0.1; srv_w=$((srv_w + 1)); done
  srv_wt=no; [ -f "$SRV_T/$2.hdone" ] || srv_wt=yes
  srv_ncp=$(tail -n 1 "$srv_kq/nc.started" 2>/dev/null); srv_up=no; srv_alive "$srv_ncp" "-p $SRV_PORT -c" && srv_up=yes
  srv_dc=no; [ -z "$srv_dp" ] || { srv_alive "$srv_dp" "$SRV_ST/decoy" && srv_dc=yes; }
  srv_pn=0; [ -f "$SRV_T/$2.ps" ] && srv_pn=$(grep -c ps "$SRV_T/$2.ps")   # calls of ps by the handler
  echo "tenths=$srv_w waiting=$srv_wt nc=$srv_up decoy=$srv_dc ps=$srv_pn" > "$SRV_T/$2.res"
  # shellcheck disable=SC2046,SC2086   # pid lists on purpose
  kill $(srv_pids "$SRV_T/$2.h") $srv_dp $srv_ncp 2>/dev/null
}
srv_res() { sed -n "s/.*$2=\([a-z0-9]*\).*/\1/p" "$SRV_T/$1.res" 2>/dev/null; }   # srv_res TAG KEY
srv_quick() { [ "$(srv_res "$1" waiting)" = no ]; }   # srv_quick TAG: the handler was gone before the watch ended
srv_job() { ( srv_kase "$@" ) >/dev/null 2>&1 & SRV_JOBS="$SRV_JOBS $!"; }   # a case in the background, all of them side by side
# Sed scripts that make a copy of the handler into another one. NRT: a handler that believes its shell has no read -t, whatever the
# shell (the device's shell may differ from every shell found here). FAKEPROC: its /proc is a directory of ours, where the stand-in nc
# and the decoy have an entry. NOPROC: no /proc to look at (macOS has none; a Linux machine would take its own). LI: an IDLE of 100 s,
# for the cases that test another limit, so that a slow start on a loaded machine is not taken for a client that says nothing.
SRV_NRT='s#^RT=0; .*#RT=0#'; SRV_LI='s/^IDLE=1[[:space:]]/IDLE=100 /'; SRV_FAKEPROC="s#/proc/#$SRV_T/proc/#g"; SRV_NOPROC='s#^PR=0; .*#PR=0#'
mkdir -p "$SRV_T/proc/self"; : > "$SRV_T/proc/self/cmdline"
SRV_JOBS=""; SRV_NRTT=""   # SRV_NRTT: the header cases that run without read -t (each has a control, its tag + L)
for SRV_X in $SRV_SHELLS; do
  SRV_N=$(basename "$SRV_X")
  srv_job "$SRV_X" "$SRV_N-quiet" 4 quiet
  srv_job "$SRV_X" "$SRV_N-quietL" 4 quiet "$SRV_LI"
  srv_job "$SRV_X" "$SRV_N-decoy" 4 quiet "" decoy
  srv_job "$SRV_X" "$SRV_N-stall" 4 stall "$SRV_LI"
  srv_job "$SRV_X" "$SRV_N-stallL" 4 stall "$SRV_LI;s/^LIFE=2[[:space:]]/LIFE=100 /"
  srv_job "$SRV_X" "$SRV_N-late" 4 late
done
for SRV_X in $SRV_RTS; do
  SRV_N=$(basename "$SRV_X")
  srv_job "$SRV_X" "$SRV_N-hdr" 4 hdr "$SRV_LI"
  srv_job "$SRV_X" "$SRV_N-hdrL" 4 hdr "$SRV_LI;s/^SLOW=1[[:space:]]/SLOW=100 /;s/^LIFE=2[[:space:]]/LIFE=100 /"
done
# without read -t: the first read -t shell, made to believe it has none, and dash where there is one
if [ -n "$SRV_RT" ]; then
  srv_job "$SRV_RT" nrt-quiet 4 quiet "$SRV_NRT"
  srv_job "$SRV_RT" nrt-quietL 4 quiet "$SRV_NRT;$SRV_LI"
  srv_job "$SRV_RT" nrt-hdr 4 hdr "$SRV_NRT;$SRV_LI"
  srv_job "$SRV_RT" nrt-hdrL 4 hdr "$SRV_NRT;$SRV_LI;s/^LIFE=2[[:space:]]/LIFE=100 /"
  SRV_NRTT="nrt-hdr"
fi
for SRV_X in $SRV_DASH; do
  SRV_N=$(basename "$SRV_X")
  srv_job "$SRV_X" "$SRV_N-hdr" 4 hdr "$SRV_LI"
  srv_job "$SRV_X" "$SRV_N-hdrL" 4 hdr "$SRV_LI;s/^LIFE=2[[:space:]]/LIFE=100 /"
  SRV_NRTT="$SRV_NRTT $SRV_N-hdr"
done
for SRV_X in $SRV_RT $SRV_DASH; do
  SRV_N=$(basename "$SRV_X")
  srv_job "$SRV_X" "$SRV_N-proc" 4 quiet "$SRV_FAKEPROC"
  srv_job "$SRV_X" "$SRV_N-procdecoy" 4 quiet "$SRV_FAKEPROC" decoy
  srv_job "$SRV_X" "$SRV_N-noproc" 4 quiet "$SRV_NOPROC"
done
# shellcheck disable=SC2086   # a pid list on purpose
wait $SRV_JOBS 2>/dev/null
SRV_BADS=""; SRV_NSH=0
for SRV_X in $SRV_SHELLS; do
  SRV_N=$(basename "$SRV_X"); SRV_NSH=$((SRV_NSH + 1))
  { srv_quick "$SRV_N-quiet" && [ "$(srv_res "$SRV_N-quiet" nc)" = no ]; } || srv_bad "$SRV_N quiet"
  { [ "$(srv_res "$SRV_N-quietL" waiting)" = yes ] && [ "$(srv_res "$SRV_N-quietL" nc)" = yes ]; } || srv_bad "$SRV_N quiet control"
done
if [ -n "$SRV_RT" ]; then
  { srv_quick nrt-quiet && [ "$(srv_res nrt-quiet nc)" = no ]; } || srv_bad "no read -t quiet"
  { [ "$(srv_res nrt-quietL waiting)" = yes ] && [ "$(srv_res nrt-quietL nc)" = yes ]; } || srv_bad "no read -t quiet control"
fi
rowif "page server: a client that sends nothing is given up after IDLE and its nc stopped, in every shell, with read -t or without; a long IDLE still waits ($SRV_NSH shells:$SRV_SHELLS; bad:${SRV_BADS:- none})" \
  [ -z "$SRV_BADS" ] && [ "$SRV_NSH" -ge 1 ]
SRV_BADS=""
for SRV_X in $SRV_RTS; do
  SRV_N=$(basename "$SRV_X")
  { srv_quick "$SRV_N-hdr" && srv_whole "$SRV_T/$SRV_N-hdr.q/resp.01" "$SRV_JA"; } || srv_bad "$SRV_N headers"
  { [ "$(srv_res "$SRV_N-hdrL" waiting)" = yes ] && [ ! -s "$SRV_T/$SRV_N-hdrL.q/resp.01" ]; } || srv_bad "$SRV_N headers control"
done
rowif "page server: with read -t a client that stops in the headers is answered after SLOW, whole; a long SLOW still waits (bad:${SRV_BADS:- none})" [ -z "$SRV_BADS" ]
SRV_BADS=""
for SRV_Y in $SRV_NRTT; do
  { srv_quick "$SRV_Y" && [ "$(srv_res "$SRV_Y" nc)" = no ]; } || srv_bad "$SRV_Y"
  { [ "$(srv_res "${SRV_Y}L" waiting)" = yes ] && [ "$(srv_res "${SRV_Y}L" nc)" = yes ]; } || srv_bad "${SRV_Y}L control"
done
rowif "page server: without read -t a client that stops in the headers is ended after LIFE and its nc stopped; a long LIFE still waits (cases:${SRV_NRTT:- none}; bad:${SRV_BADS:- none})" \
  [ -z "$SRV_BADS" ] && [ -n "$SRV_NRTT" ]
SRV_BADS=""
for SRV_X in $SRV_SHELLS; do
  SRV_N=$(basename "$SRV_X")
  { srv_quick "$SRV_N-stall" && [ "$(srv_res "$SRV_N-stall" nc)" = no ]; } || srv_bad "$SRV_N stalled"
  { [ "$(srv_res "$SRV_N-stallL" waiting)" = yes ] && [ "$(srv_res "$SRV_N-stallL" nc)" = yes ]; } || srv_bad "$SRV_N stalled control"
done
rowif "page server: an answer nobody reads is ended after LIFE and its nc stopped; a long LIFE still waits (bad:${SRV_BADS:- none})" [ -z "$SRV_BADS" ]
SRV_BADS=""
for SRV_X in $SRV_SHELLS; do
  SRV_N=$(basename "$SRV_X")
  { [ "$(srv_res "$SRV_N-decoy" nc)" = yes ] && [ "$(srv_res "$SRV_N-decoy" decoy)" = yes ]; } || srv_bad "$SRV_N decoy"
  { srv_quick "$SRV_N-late" && [ "$(srv_res "$SRV_N-late" nc)" = no ] && [ ! -s "$SRV_T/$SRV_N-late.q/resp.01" ]; } || srv_bad "$SRV_N late"
done
rowif "page server: a pid in the pidfile that is no nc of ours is left alone; a late client is given up on, in every shell (bad:${SRV_BADS:- none})" [ -z "$SRV_BADS" ]
SRV_BADS=""; SRV_NPR=0
for SRV_X in $SRV_RT $SRV_DASH; do
  SRV_N=$(basename "$SRV_X"); SRV_NPR=$((SRV_NPR + 1))
  { srv_quick "$SRV_N-proc" && [ "$(srv_res "$SRV_N-proc" nc)" = no ] && [ "$(srv_res "$SRV_N-proc" ps)" = 0 ]; } || srv_bad "$SRV_N /proc"
  { [ "$(srv_res "$SRV_N-procdecoy" nc)" = yes ] && [ "$(srv_res "$SRV_N-procdecoy" decoy)" = yes ] && [ "$(srv_res "$SRV_N-procdecoy" ps)" = 0 ]; } || srv_bad "$SRV_N /proc decoy"
  { srv_quick "$SRV_N-noproc" && [ "$(srv_res "$SRV_N-noproc" nc)" = no ] && [ "$(srv_res "$SRV_N-noproc" ps)" != 0 ]; } || srv_bad "$SRV_N ps control"
done
rowif "page server: an idle nc is stopped from its /proc entry, without a list of the processes; the same handler without /proc does list them; a pid there that is no nc of ours is left alone ($SRV_NPR shells; bad:${SRV_BADS:- none})" \
  [ -z "$SRV_BADS" ] && [ "$SRV_NPR" -ge 1 ]

# ---- P5 the server itself: script, handler, FIFO and a stand-in nc that plays the clients queued in $SRV_Q. The stand-in looks at the
# queue once, when it starts, so a client reaches the handler a few milliseconds into its round, never at the edge of IDLE.
srv_took() { sed -n "s/^\([0-9]*\) $1\.client\$/\1/p" "$SRV_Q/nc.took" 2>/dev/null | tail -n 1; }   # srv_took NN: pid of the nc that took client NN
srv_notnc() { ! srv_alive "$(srv_took "$1")" "-p $SRV_PORT -c"; }
srv_tookit() { [ -n "$(srv_took "$1")" ]; }
srv_answer() { srv_whole "$SRV_Q/resp.$1" "$2" && [ "$(srv_hdr Cache-Control)" = "$3" ]; }   # srv_answer NN FILE CACHE-CONTROL: client NN got that file, whole
SRV_BADS=""
rm -f "$SRV_Q"/* "$SRV_TMP"/*; cp "$SRV_JA" "$SRV_D/starchorus.json"
srv_client "$SRV_Q" 01 get /starchorus.json; srv_client "$SRV_Q" 02 get /
srv_start "$SRV_B"
srv_until 8 srv_haveresp 02; srv_until 3 srv_ncmore 2
srv_answer 01 "$SRV_JA" no-store || srv_bad "first answer"
srv_answer 02 "$SRV_D/index.html" max-age=60 || srv_bad "second answer"
rowif "page server: a request is answered through nc, FIFO and handler, the next one too, the listener re-opens (bad:${SRV_BADS:- none})" [ -z "$SRV_BADS" ]
SRV_BADS=""
srv_client "$SRV_Q" 03 silent; srv_client "$SRV_Q" 04 get /starchorus.json
srv_until 10 srv_haveresp 04
srv_tookit 03 || srv_bad "silent client never taken"
srv_notnc 03 || srv_bad "silent client's nc still there"
srv_answer 04 "$SRV_JA" no-store || srv_bad "client after the silent one"
rowif "page server: a client that connects and says nothing is dropped, the next client is served (bad:${SRV_BADS:- none})" [ -z "$SRV_BADS" ]
SRV_BADS=""; SRV_N0=$(srv_ncn); SRV_P0=$(srv_lastnc)
srv_until 6 srv_ncmore "$SRV_N0" || srv_bad "no new listener"
srv_alive "$SRV_P0" "-p $SRV_PORT -c" && srv_bad "old listener still there"
rowif "page server: a listener nobody calls is replaced after IDLE (nc $SRV_P0 -> $(srv_lastnc); bad:${SRV_BADS:- none})" [ -z "$SRV_BADS" ]
SRV_BADS=""; cp "$SRV_JBIG" "$SRV_D/starchorus.json"; srv_client "$SRV_Q" 05 stall /starchorus.json; SRV_N0=$(srv_ncn)
srv_until 8 srv_tookit 05; srv_until 8 srv_notnc 05
srv_notnc 05 || srv_bad "stalled client's nc still there"
SRV_N0=$(srv_ncn); srv_until 5 srv_ncmore "$SRV_N0" || srv_bad "no new listener"
[ "$(srv_nfiles "$SRV_TMP")" = 0 ] || srv_bad "copy left behind"
cp "$SRV_JA" "$SRV_D/starchorus.json"
rowif "page server: an answer nobody reads is ended, the listener re-opens, no copy is left (bad:${SRV_BADS:- none})" [ -z "$SRV_BADS" ]
SRV_BADS=""; : > "$SRV_TMP/starchorus-http-$SRV_PORT.left"; : > "$SRV_TMP/starchorus-http-${SRV_PORT}1.keep"
srv_stop "$SRV_B"; wait "$SRV_PID" 2>/dev/null; sleep 0.3
SRV_LEFT=$(srv_pids "$SRV_T/")
[ -z "$SRV_LEFT" ] || srv_bad "processes left: $("$SRV_ST/ps" | awk -v t="$SRV_T/" 'index($0, t) && !/awk/ { print substr($0, 1, 90) }' | tr '\n' '|')"
for SRV_F in starchorus-serve.pid .starchorus-http-nc.pid .starchorus-http.fifo; do [ ! -e "$SRV_D/$SRV_F" ] || srv_bad "$SRV_F left"; done
[ ! -e "$SRV_TMP/starchorus-http-$SRV_PORT.left" ] || srv_bad "own copy left"
[ -e "$SRV_TMP/starchorus-http-${SRV_PORT}1.keep" ] || srv_bad "another port's copy removed"
rowif "page server: stop ends loop, nc and handler and removes the copy of its port only (bad:${SRV_BADS:- none})" [ -z "$SRV_BADS" ]
fi

# ---- clean up: whatever of ours still runs, the scratch directory unless a row asked for it to be kept
# shellcheck disable=SC2046   # a pid list on purpose
kill $(srv_pids "$SRV_T/") 2>/dev/null
if [ "$SRV_KEEP" = 0 ]; then rm -rf "$SRV_T"; else echo "    page-server scratch kept for inspection: $SRV_T"; fi
unset SRV_SED SRV_WC SRV_Q
unset -f srv_mkbin srv_has_rt srv_nfiles srv_size srv_until srv_pids srv_parse srv_hdr srv_ask srv_bad srv_note srv_file srv_404 srv_start srv_stop \
  srv_ncn srv_lastnc srv_ncmore srv_haveresp srv_client srv_swap srv_alive srv_kase srv_res \
  srv_quick srv_job srv_whole srv_took srv_notnc srv_tookit srv_answer
fi
