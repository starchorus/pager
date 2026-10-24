# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/installer.sh -- tools/install.sh against stand-ins for ssh and scp, run for real; and the collector's own self-test under dash.
# GUARDS AGAINST: an installer that sends one more remote command than its header promises ("Remote commands (nothing else is ever sent)"),
#                 uploads in another order or to another place, takes a damaged upload for an intact one (the read-back compares every file),
#                 goes on to the self-tests and the smoke test after an upload failed, or accepts a summary whose band counters are blank;
#                 a command sent only on a failure path (the "nothing else" judge reads the log of every run of the real installer, twenty-eight
#                 of them, not only the clean ones, and every branch of install.sh after its first remote command is reached by at least one of
#                 them: each die, WARN and FAIL from the failed mkdir to the smoke test, the repo's Overview without --selftest included); a cleanup that no longer closes the master connection with one `-O exit` as its last call;
#                 a device with cksum where one file's CRC differs (only that file is read back, and its bytes decide).
#                 The doc-drift drop-in reads only the installer's --dry-run plan; nothing before this file ran the installer's real flow.
#                 Second part: a collector that passes its self-test under the machine's sh and fails it under dash (a bashism), in the self-test's
#                 own process or in one of the children it starts with `sh`, goes unseen (the run puts dash in the place of sh on its PATH).
# NEGATIVE PROBE: (a) a copy of install.sh with one more remote command (`uname -a`, sent after the exec bits), a copy that passes `; uname -a` as a
#                 second argument to every ssh call (the stand-in logs what ssh would send: all arguments after the host, joined by blanks), a copy that
#                 opens a port forward through the master connection (-O forward) => the "nothing else" judge is red on each log, the options judge
#                 on the forward; copies with a tab in the mkdir command, a line break in it, or a tab in one destination of FILES, each followed
#                 by `uname -a` (on a device the remote shell would run it) => the "nothing else" judge is red on each log; five copies that call
#                 ssh or scp other than by the bare name (/usr/bin/ssh, command -p scp, slogin, "$HOME"/bin/scp, a PATH= of their own) => the
#                 bare-name row is red on each; the same judges on the real log are green; copies that send the collector's --stop only when
#                 its self-test is red, or only when the smoke test is red (the clean judge stays green on their clean run) => the judge of
#                 every run is red on their failure runs and names --stop; a copy that sends --stop only when --once exits non-zero (a branch only
#                 a run of section 6a reaches) => the same. (b) a stand-in scp that damages one file on upload => the judge of the clean
#                 run (exit 0, 'integrity verified ... identical') is red on that run, and the installer itself exits 1 and names the file.
#                 (c) the judges are run on dummy logs that plant each fault (an extra command, a changed option, a third host, a forward, an -O call other
#                 than the cleanup's `-O exit`, a file sent to another path, a read of a file that was never sent, a tab or a line break inside a command
#                 or a path, raw or as the stand-ins log it, a short line, an unknown kind, an scp to or from a path outside the two directories) and
#                 each must be red; the intact log must be green; the row also requires all 43 cases to have run.
# NOT PROVEN:     what the real ssh and scp do (the stand-ins answer as the device is documented to answer in docs/device-notes.md; the Pager's
#                 BusyBox, the master connection, the password prompt and the host key question are not played); that the device's files are
#                 the right ones afterwards (the fake remote root is a directory on this machine); that the installer's text is true about a
#                 device (its header is checked for the command kinds it names, not for how a command behaves there). The branches before the
#                 first remote command (an unknown option, an invalid host, a missing source file, differing Overview copies, an unreadable version
#                 or window, a missing local tool, no temp directory: all exit 2) and the INT/TERM traps are reached by no run, so a command sent
#                 only there would pass every row; so would one sent only by the --dry-run path (doc-drift reads its plan). The dash run uses dash
#                 on this machine, not the device's ash (BusyBox), and it cannot see what a /proc-less or applet-poor system does. Dash stands in for sh on the PATH of that one run only;
#                 a script that names /bin/sh by its path would still get the machine's. The bare-name row reads the installer's text: a client
#                 reached through a variable that holds a path ("$SSH" set to /usr/bin/ssh) would get past it.
# Sourced by tools/regress.sh (T2) with cwd = repo root; Chrome-free. Only INS_* names and ins_* functions are set. Nothing connects anywhere:
# the installer runs with a PATH farm in which ssh and scp ARE the stand-ins (the real ones, slogin, sftp and ssh-keyscan are not on it), against a documentation address
# (TEST-NET-2); the stand-ins refuse any other host. Not run in tools/quick.sh (T1): some forty installer runs and the collector self-test (two minutes or so).
#
# The stand-ins log one line per call (TAB separated: kind, host, options, then command | source and destination; a tab or a line break inside
# a field is logged as \001 / \002, so it cannot split a field or a line, and every judge first checks the shape of each line) and act on a fake remote root.
#   ssh      mkdir -p, chmod +x (INS_X_CHMOD=fail makes it fail), cksum (answers "not found", exit 127, like the Pager's BusyBox; with real
#            lines when INS_X_CKSUM=ok, lines with other numbers when =other, a line that is no use when =junk),
#            the control socket of a master connection that came up (a plain file at its ControlPath, so the cleanup's -O exit is sent),
#            sh <script> --selftest (a result line; INS_X_SELFTEST for the collector, INS_X_DSELFTEST for the Overview: fail, noline, rc = ALL PASS
#            with a non-zero exit, and for the Overview old = no --selftest), the --once capture (writes starchorus.json; INS_X_ONCE_RC its exit),
#            head -c 400 (INS_X_HEAD=fail makes it fail), the Overview's --once summary (INS_X_SUMMARY picks the text);
#            every other command is logged and answered "not found" (127)
#   scp      -O upload (INS_X_CORRUPT=<name> damages that file on its way, INS_X_UPFAIL=<n> fails the nth upload) and the read-back
#            (INS_X_NOREAD=<name> makes that read fail)
INS_T=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-ins.XXXXXX") || INS_T=""
if [ -z "$INS_T" ] || [ ! -d "$INS_T" ]; then
  row "installer against stand-ins: no temp directory" FAIL
else
INS_HOST=198.51.100.7                   # TEST-NET-2: not routable; the stand-ins accept no other host
INS_SH=$(command -v sh); INS_IN="$R/tools/install.sh"
INS_B="$INS_T/bin"; INS_DEV="$INS_T/dev"; INS_L=/root/loot/starchorus; INS_PL=/root/payloads/user/reconnaissance/starchorus
mkdir -p "$INS_B"
INS_TAB=$(printf '\t')
# the seven targets, in the order of FILES in tools/install.sh (the page becomes index.html)
INS_DESTS="$INS_L/starchorus-collect.sh $INS_L/index.html $INS_L/starchorus-display.sh $INS_L/starchorus-serve.sh $INS_PL/payload.sh $INS_PL/starchorus-display.sh $INS_PL/alert-deauth.sh"
# the PATH of a run: every tool of this machine's PATH except ssh and scp (the stand-ins take their place) and the other clients of the ssh
# family that reach a host (slogin is a link to ssh on some systems; sftp, ssh-keyscan): a call by one of those names finds nothing
path_farm "$INS_B" ssh scp slogin sftp ssh-keyscan
rm -f "$INS_B/ssh" "$INS_B/scp"   # path_farm did it already; a link left here would be written THROUGH by the next lines
cat > "$INS_B/ssh" <<'INS_X'
#!/bin/sh
# stand-in ssh: logs the call, acts on the fake remote root $INS_X_DEV, answers as the device is documented to answer
opts=""; ctl=0; host=""; mst=0; cpath=""
while [ $# -gt 0 ]; do
  case $1 in
    -o) case $2 in ControlMaster=auto) mst=1 ;; ControlPath=*) cpath=${2#ControlPath=} ;; esac; opts="$opts -o $2"; shift 2 ;;
    -O) opts="$opts -O $2"; ctl=1; shift 2 ;;
    -*) opts="$opts $1"; shift ;;
    *) host=${1#root@}; shift; break ;;
  esac
done
cmd=$*   # what ssh sends: every argument after the host, joined by blanks (a second argument is part of the remote command)
vis() { printf '%s' "$1" | tr '\t\n' '\001\002'; }   # a tab or a line break inside a word is logged as \001 / \002: it can never split a log field or a line
printf 'ssh\t%s\t%s\t%s\n' "$(vis "$host")" "$(vis "${opts# }")" "$(vis "$cmd")" >> "$INS_X_LOG"
[ "$host" = "$INS_X_HOST" ] || { echo "ssh: Could not resolve hostname $host" >&2; exit 255; }
[ "$ctl" = 0 ] || exit 0
[ "${INS_X_NOSSH:-0}" = 0 ] || { echo "ssh: connect to host $host port 22: Connection refused" >&2; exit 255; }
# a master connection that came up leaves its control socket behind (a plain file here), as the real ssh does: the installer's cleanup
# then closes it with `ssh -o ControlPath=... -O exit`, and that call is logged and judged like every other one
[ "$mst" = 0 ] || [ -z "$cpath" ] || [ -e "$cpath" ] || : > "$cpath"
d=$INS_X_DEV; L=/root/loot/starchorus
case $cmd in
  "mkdir -p "*) set -- $cmd; shift 2; for p in "$@"; do mkdir -p "$d$p" || exit 1; done ;;
  "chmod +x "*)
    [ "${INS_X_CHMOD:-ok}" = ok ] || { echo "chmod: $L/starchorus-collect.sh: Read-only file system" >&2; exit 1; }
    set -- $cmd; shift 2; for p in "$@"; do [ -f "$d$p" ] || { echo "chmod: $p: No such file or directory" >&2; exit 1; }; chmod +x "$d$p"; done ;;
  "cksum "*)
    case ${INS_X_CKSUM:-none} in
      ok)    set -- $cmd; shift; for p in "$@"; do printf '%s %s\n' "$(cksum < "$d$p" | awk '{ print $1 " " $2 }')" "$p"; done ;;
      other) set -- $cmd; shift; for p in "$@"; do printf '%s %s\n' "$(cksum < "$d$p" | awk '{ print $1 + 1 " " $2 }')" "$p"; done ;;   # another algorithm: lines, other numbers
      junk)  echo "cksum: unrecognised option"; exit 1 ;;                                                                          # an applet that gives no usable output
      *)     echo "ash: cksum: not found"; exit 127 ;;
    esac ;;
  "sh $L/starchorus-collect.sh --selftest")
    [ -f "$d$L/starchorus-collect.sh" ] || { echo "sh: can't open $L/starchorus-collect.sh" >&2; exit 127; }
    case ${INS_X_SELFTEST:-pass} in
      fail)   echo "[starchorus] SELFTEST: FAILED (1 of 482)"; echo "[starchorus]   FAIL: a stand-in check"; exit 1 ;;
      noline) echo "sh: syntax error: unexpected end of file"; exit 2 ;;
      rc)     echo "[starchorus] SELFTEST: ALL PASS (482 checks)"; exit 3 ;;
    esac
    echo "[starchorus] SELFTEST: ALL PASS (482 checks)" ;;
  "sh $L/starchorus-display.sh --selftest")
    [ -f "$d$L/starchorus-display.sh" ] || { echo "sh: can't open $L/starchorus-display.sh" >&2; exit 127; }
    case ${INS_X_DSELFTEST:-pass} in
      fail)   echo "[display-selftest] SELFTEST: FAILED (1 of 300)"; echo "[display-selftest]   FAIL: a stand-in check"; exit 1 ;;
      noline) echo "sh: syntax error: unexpected end of file"; exit 2 ;;
      old)    echo "Starchorus"; exit 0 ;;                                                                                     # an older Overview: no --selftest, no result line
      rc)     echo "[display-selftest] SELFTEST: ALL PASS (300 checks)"; exit 4 ;;
    esac
    echo "[display-selftest] SELFTEST: ALL PASS (300 checks)" ;;
  "cd $L && STARCHORUS_OUTDIR=$L STARCHORUS_MAX_AGE="*" ./starchorus-collect.sh --once")
    [ -x "$d$L/starchorus-collect.sh" ] || { echo "ash: ./starchorus-collect.sh: Permission denied" >&2; exit 126; }
    printf '{"generated": 1789300000, "source": "iw-scan-ACTIVE", "aps": []}\n' > "$d$L/starchorus.json"
    echo "[starchorus] one cycle done (stand-in)"
    exit "${INS_X_ONCE_RC:-0}" ;;
  "head -c 400 $L/starchorus.json")
    [ "${INS_X_HEAD:-ok}" = ok ] || { echo "head: $L/starchorus.json: I/O error" >&2; exit 1; }
    [ -f "$d$L/starchorus.json" ] || { echo "head: $L/starchorus.json: No such file or directory" >&2; exit 1; }
    head -c 400 "$d$L/starchorus.json" ;;
  "STARCHORUS_JSON=$L/starchorus.json STARCHORUS_DISPLAY_PLAIN=1 sh $L/starchorus-display.sh --once summary")
    [ -f "$d$L/starchorus-display.sh" ] || { echo "sh: can't open $L/starchorus-display.sh" >&2; exit 127; }
    echo "Starchorus"
    case ${INS_X_SUMMARY:-ok} in
      ok)     printf 'APs 4   \302\267   2.4:1  5:2  6:1\n' ;;
      blank)  printf 'APs 0   \302\267   2.4:  5:  6:\n' ;;
      five)   printf 'APs 4   \302\267   2.4:1  5:  6:1\n' ;;
      spaced) printf 'APs 4   \302\267   2.4: 1  5: 2  6: 1\n' ;;
      jq)     echo "jq incomplete"; printf 'APs 4   \302\267   2.4:1  5:2  6:1\n' ;;
      noband) echo "no networks to show" ;;
    esac
    exit "${INS_X_SMOKE_RC:-0}" ;;
  *) echo "ash: $cmd: not found" >&2; exit 127 ;;
esac
INS_X
cat > "$INS_B/scp" <<'INS_X'
#!/bin/sh
# stand-in scp (the legacy protocol, -O): an upload to root@HOST:PATH or a read-back from it
opts=""
while [ $# -gt 2 ]; do
  case $1 in -o) opts="$opts -o $2"; shift 2 ;; *) opts="$opts $1"; shift ;; esac
done
src=$1; dst=$2; d=$INS_X_DEV
vis() { printf '%s' "$1" | tr '\t\n' '\001\002'; }   # as in the stand-in ssh: a tab or a line break inside a path cannot split a log field or a line
case $dst in
  root@*:*)
    host=${dst#root@}; host=${host%%:*}; path=${dst#*:}
    printf 'scp-up\t%s\t%s\t%s\t%s\n' "$(vis "$host")" "$(vis "${opts# }")" "$(vis "$src")" "$(vis "$path")" >> "$INS_X_LOG"
    [ "$host" = "$INS_X_HOST" ] || { echo "scp: Could not resolve hostname $host" >&2; exit 255; }
    n=$(( $(cat "$INS_X_LOG.up" 2> /dev/null || echo 0) + 1 )); echo "$n" > "$INS_X_LOG.up"
    [ "${INS_X_UPFAIL:-0}" != "$n" ] || { echo "scp: $path: Failure" >&2; exit 1; }
    [ -d "$d${path%/*}" ] || { echo "scp: $path: No such file or directory" >&2; exit 1; }
    cat "$src" > "$d$path" || exit 1   # a new file with the default mode, as scp makes it: the exec bit has to come from the chmod
    [ "${INS_X_CORRUPT:-}" != "${path##*/}" ] || printf 'x' >> "$d$path" ;;
  *)
    host=${src#root@}; host=${host%%:*}; path=${src#*:}
    printf 'scp-get\t%s\t%s\t%s\t%s\n' "$(vis "$host")" "$(vis "${opts# }")" "$(vis "$path")" "$(vis "$dst")" >> "$INS_X_LOG"
    [ "$host" = "$INS_X_HOST" ] || { echo "scp: Could not resolve hostname $host" >&2; exit 255; }
    [ "${INS_X_NOREAD:-}" != "${path##*/}" ] || { echo "scp: $path: Permission denied" >&2; exit 1; }
    [ -f "$d$path" ] || { echo "scp: $path: No such file or directory" >&2; exit 1; }
    cp "$d$path" "$dst" || exit 1 ;;
esac
INS_X
chmod +x "$INS_B/ssh" "$INS_B/scp"

ins_run() {   # ins_run NAME [VAR=value ...] -> INS_RC, $INS_T/NAME.out (installer output), $INS_T/NAME.log (the stand-ins' log); INS_IN = the installer
  INS_in=$1; shift
  rm -rf "$INS_DEV"; mkdir -p "$INS_DEV"; : > "$INS_T/$INS_in.log"; rm -f "$INS_T/$INS_in.log.up"
  ( env -u STARCHORUS_HOST PATH="$INS_B" INS_X_LOG="$INS_T/$INS_in.log" INS_X_DEV="$INS_DEV" INS_X_HOST="$INS_HOST" "$@" \
      "$INS_SH" "$INS_IN" --host "$INS_HOST" ) > "$INS_T/$INS_in.out" 2>&1 < /dev/null; INS_RC=$?
  # every run of the real installer (not of a mutated copy) is recorded: the row "nothing else, in every run" judges all of them
  [ "$INS_IN" != "$R/tools/install.sh" ] || case " $INS_RUNS " in *" $INS_in "*) ;; *) INS_RUNS="$INS_RUNS $INS_in" ;; esac
}
INS_RUNS=""
# the shape of every log line, the first rule of every judge: a known kind, exactly its number of fields (ssh 4, scp 5) and no tab or line break
# inside a word (the stand-ins log those as \001 / \002). Without it a command could hide a second one behind a tab, in a field nobody reads.
# shellcheck disable=SC2016   # awk program text: its $1 and NF are awk's, not the shell's
INS_AWK_SHAPE='
    BEGIN { ctl = sprintf("[%c%c]", 1, 2) }
    $1 != "ssh" && $1 != "scp-up" && $1 != "scp-get" { print "log line " NR ": a call of an unknown kind (" $1 ")"; next }
    NF != ($1 == "ssh" ? 4 : 5) { print "log line " NR " (" $1 "): " NF " fields, not " ($1 == "ssh" ? 4 : 5) " (a tab inside a word)"; next }
    $0 ~ ctl { print "log line " NR " (" $1 "): a tab or a line break inside a word"; next }'
ins_kinds() {   # ins_kinds LOG -> the order of operations as words, a run of one kind as kind*N ("mkdir up*7 chmod cksum get*7 csel dsel once head smoke")
  awk -F'\t' '
    function emit(k) { if (k == last) { n++ } else { flush(); last = k; n = 1 } }
    function flush() { if (last != "") out = out (out == "" ? "" : " ") last (n > 1 ? "*" n : "") }
    $1 != "ssh" && $1 != "scp-up" && $1 != "scp-get" { emit("UNKNOWN"); next }
    $1 == "scp-up" { emit("up"); next }
    $1 == "scp-get" { emit("get"); next }
    $1 == "ssh" && $3 !~ /(^| )-O / {
      c = $4; k = "OTHER"
      if (c ~ /^mkdir -p /) k = "mkdir"; else if (c ~ /^chmod /) k = "chmod"; else if (c ~ /^cksum /) k = "cksum"
      else if (c ~ /starchorus-collect\.sh --selftest$/) k = "csel"; else if (c ~ /starchorus-display\.sh --selftest$/) k = "dsel"
      else if (c ~ /\.\/starchorus-collect\.sh --once$/) k = "once"; else if (c ~ /^head -c /) k = "head"; else if (c ~ /--once summary$/) k = "smoke"
      emit(k)
    }
    END { flush(); print out }' "$1"
}
ins_cmds_bad() {   # ins_cmds_bad LOG -> the remote commands the header's list does not allow, one per line (empty = nothing else was sent); a -O call (forward, cancel, ...) other than the cleanup's `-O exit` is one of them,
                   # and so is a log line of the wrong shape, and an scp whose remote path is not one of the two directories (legacy scp -O hands that path to the remote shell)
  awk -F'\t' "$INS_AWK_SHAPE"'
    BEGIN {
      dp = "/root/(loot/starchorus|payloads/user/reconnaissance/starchorus)/[A-Za-z0-9._-]+"
      n = 0
      ok[++n] = "^mkdir -p /root/loot/starchorus /root/payloads/user/reconnaissance/starchorus$"
      ok[++n] = "^chmod [+]x " dp "( " dp ")*$"
      ok[++n] = "^cksum " dp "( " dp ")*$"
      ok[++n] = "^sh /root/loot/starchorus/starchorus-collect[.]sh --selftest$"
      ok[++n] = "^sh /root/loot/starchorus/starchorus-display[.]sh --selftest$"
      ok[++n] = "^cd /root/loot/starchorus && STARCHORUS_OUTDIR=/root/loot/starchorus STARCHORUS_MAX_AGE=[0-9]+ [.]/starchorus-collect[.]sh --once$"
      ok[++n] = "^head -c 400 /root/loot/starchorus/starchorus[.]json$"
      ok[++n] = "^STARCHORUS_JSON=/root/loot/starchorus/starchorus[.]json STARCHORUS_DISPLAY_PLAIN=1 sh /root/loot/starchorus/starchorus-display[.]sh --once summary$"
    }
    $1 == "ssh" && $3 ~ /(^| )-O / { o = $3; gsub(/ControlPath=[^ ]*/, "ControlPath=<cm>", o); if (o != "-o ControlPath=<cm> -O exit" || $4 != "") print "ssh -O " $3 " " $4; next }
    $1 == "ssh" { g = 0; for (i = 1; i <= n; i++) if ($4 ~ ok[i]) g = 1; if (!g) print $4; next }
    $1 == "scp-up" && $5 !~ ("^" dp "$") { print "scp upload to a path not on the list: " $5; next }
    $1 == "scp-get" && $4 !~ ("^" dp "$") { print "scp read of a path not on the list: " $4; next }' "$1"
}
ins_opts_bad() {   # ins_opts_bad LOG -> calls whose options are not exactly the master-connection set (no forwarding, no agent, no other host); a log line of the wrong shape
  awk -F'\t' "$INS_AWK_SHAPE"'
    { o = $3; gsub(/ControlPath=[^ ]*/, "ControlPath=<cm>", o) }
    $1 == "ssh" && $3 ~ /(^| )-O / && (o != "-o ControlPath=<cm> -O exit" || $4 != "") { print $1 ": " $3 " " $4 }   # only the cleanup call is allowed: -o ControlPath=<cm> -O exit, no command
    $1 == "ssh" && $3 !~ /(^| )-O / && o != "-o ControlMaster=auto -o ControlPath=<cm> -o ControlPersist=300 -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15" { print $1 ": " $3 }
    ($1 == "scp-up" || $1 == "scp-get") && o != "-O -o ControlMaster=auto -o ControlPath=<cm> -o ControlPersist=300 -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15" { print $1 ": " $3 }
    $2 != host { print $1 ": host " $2 }' host="$INS_HOST" "$1"
}
ins_scp_bad() {   # ins_scp_bad LOG GETS -> uploads that are not exactly the seven targets in order (once each); reads of a file that was not sent; GETS = wanted number of reads; a log line of the wrong shape
  awk -F'\t' -v dests="$INS_DESTS" -v gets="$2" "$INS_AWK_SHAPE"'
    BEGIN { nd = split(dests, want, " ") }
    $1 == "scp-up" { u++; if (u > nd || $5 != want[u]) print "upload " u ": " $5; sent[$5] = 1 }
    $1 == "scp-get" { g++; if (!($4 in sent)) print "read-back of a file that was not sent: " $4 }
    END { if (u != nd) print "uploads: " u " (want " nd ")"; if (g != gets) print "read-backs: " g " (want " gets ")" }' "$1"
}
ins_clean_judge() {   # ins_clean_judge NAME GETS: the whole of the clean-run claim in one status (0 = holds): exit 0, order, nothing else, options, scp, no "differ"/"NOT verified"
  [ "$INS_RC" = 0 ] || return 1
  [ -z "$(ins_cmds_bad "$INS_T/$1.log")" ] && [ -z "$(ins_opts_bad "$INS_T/$1.log")" ] && [ -z "$(ins_scp_bad "$INS_T/$1.log" "$2")" ] || return 1
  ! grep -q 'differ between the repo and the device\|integrity NOT verified\|\[FAIL\]' "$INS_T/$1.out"
}

# fairness: the farm has the stand-ins and no real ssh/scp; the installer is the real one and has the header the judges rely on
INS_fair=1
[ "$(PATH=$INS_B command -v ssh)" = "$INS_B/ssh" ] && [ "$(PATH=$INS_B command -v scp)" = "$INS_B/scp" ] || INS_fair=0
for INS_x in slogin sftp ssh-keyscan; do [ -z "$(PATH=$INS_B command -v "$INS_x")" ] || INS_fair=0; done
[ -x "$INS_B/awk" ] && [ -x "$INS_B/cksum" ] && [ -x "$INS_B/mktemp" ] || INS_fair=0
[ -f "$INS_IN" ] || INS_fair=0
INS_hd=$(sed -n '/^# Remote commands (nothing else is ever sent):/,/^# No package manager/p' "$INS_IN" 2> /dev/null | tr '\n' ' ')
INS_hok=1
for INS_w in 'mkdir -p' 'chmod' 'cksum' '--selftest' '--once' 'head of starchorus.json' '--once summary' 'nothing else is ever sent' 'No package manager, no config, no service control'; do
  case "$INS_hd $(grep -m 1 '^# No package manager' "$INS_IN" 2> /dev/null)" in *"$INS_w"*) ;; *) INS_hok=0 ;; esac
done
rowif "installer header names the seven kinds of remote command this drop-in judges (and 'nothing else is ever sent')" [ "$INS_hok" = 1 ]

# the stand-ins only see what reaches them through PATH: the installer must call ssh and scp by their bare names. A path to the binary
# (/usr/bin/ssh, "$HOME"/bin/scp), `command -p`, a PATH= of its own, or another client of the family would reach the real one, unlogged.
ins_bare_bad() {   # ins_bare_bad FILE -> the code lines (comment lines left out; the phrase "ssh/scp" of the prose taken out) that reach a client other than by its bare name
  sed -e '/^[[:space:]]*#/d' -e 's|ssh/scp||g' "$1" \
    | grep -E '/(ssh|scp|slogin|sftp|ssh-keyscan)([^A-Za-z0-9_-]|$)|command[[:space:]]+-[A-Za-z]*p|(^|[^A-Za-z0-9_-])(slogin|sftp|ssh-keyscan)([^A-Za-z0-9_-]|$)|(^|[^A-Za-z0-9_])PATH=' | cut -c1-160
}
INS_bb=$(ins_bare_bad "$INS_IN")
INS_bn=$(sed '/^[[:space:]]*#/d' "$INS_IN" | grep -cE '(^|[{;(&|[:space:]])(ssh|scp) ')
INS_bv=0; INS_br=0
# shellcheck disable=SC2016   # sed scripts: "$HOME" is meant to land in the copy unexpanded
for INS_x in 's|^rsh()     { ssh |rsh()     { /usr/bin/ssh |' 's|^rcp()     { scp |rcp()     { command -p scp |' 's|^rsh_cap() { ssh |rsh_cap() { slogin |' \
             's|^rget()    { scp |rget()    { "$HOME"/bin/scp |' 's|then ssh -o|then PATH=/usr/bin:/bin ssh -o|'; do
  INS_bv=$((INS_bv + 1)); sed "$INS_x" "$INS_IN" > "$INS_T/bare.sh"
  ! cmp -s "$INS_T/bare.sh" "$INS_IN" && [ -n "$(ins_bare_bad "$INS_T/bare.sh")" ] && INS_br=$((INS_br + 1))
done
INS_ok=0; [ -z "$INS_bb" ] && [ "$INS_bn" -ge 5 ] && [ "$INS_bv" = 5 ] && [ "$INS_br" = 5 ] && INS_ok=1
rowif "installer calls ssh and scp by their bare names only ($INS_bn call lines; no path to the binary, no command -p, no PATH= of its own, no slogin/sftp/ssh-keyscan), so every call reaches the stand-ins; $INS_br of $INS_bv copies with such a call are caught" [ "$INS_ok" = 1 ]
[ -z "$INS_bb" ] || printf '%s\n' "$INS_bb" | sed 's/^/    not a bare name: /'

# ---- 1. the device as it is (no cksum applet): the read-back compares all seven files
ins_run dev
INS_k=$(ins_kinds "$INS_T/dev.log"); INS_kw="mkdir up*7 chmod cksum get*7 csel dsel once head smoke"
INS_nc=$(grep -c "^ssh$INS_TAB" "$INS_T/dev.log")
INS_ok=0; [ "$INS_fair" = 1 ] && [ "$INS_RC" = 0 ] && [ "$INS_k" = "$INS_kw" ] && INS_ok=1
rowif "installer run 1 (device without cksum, stand-ins first on PATH $INS_fair): exit $INS_RC (want 0), order [$INS_k]" [ "$INS_ok" = 1 ]
[ "$INS_RC" = 0 ] || { tail -n 12 "$INS_T/dev.out" | cut -c1-200 | sed 's/^/    /'; }
INS_bad=$(ins_cmds_bad "$INS_T/dev.log")
INS_ok=0; [ "$INS_nc" -ge 8 ] && [ -z "$INS_bad" ] && [ -z "$(ins_opts_bad "$INS_T/dev.log")" ] && INS_ok=1
rowif "installer sends nothing but the header's remote commands ($INS_nc ssh calls, all of them on the list; options exactly the master set; no other host)" [ "$INS_ok" = 1 ]
[ -z "$INS_bad" ] || printf '%s\n' "$INS_bad" | cut -c1-200 | sed 's/^/    not on the list: /'
INS_sb=$(ins_scp_bad "$INS_T/dev.log" 7)
rowif "installer's scp: seven uploads in the order of FILES, every one to its target, seven read-backs of files that were sent" [ -z "$INS_sb" ]
[ -z "$INS_sb" ] || printf '%s\n' "$INS_sb" | sed 's/^/    /'
INS_cmpbad=0
while IFS= read -r INS_x; do
  INS_rel=${INS_x%%|*}; INS_dst=${INS_x#*|}
  cmp -s "$R/$INS_rel" "$INS_DEV$INS_dst" || INS_cmpbad=$((INS_cmpbad + 1))
done <<INS_E
starchorus-collect.sh|$INS_L/starchorus-collect.sh
starchorus.html|$INS_L/index.html
starchorus-display.sh|$INS_L/starchorus-display.sh
starchorus-serve.sh|$INS_L/starchorus-serve.sh
library/user/reconnaissance/starchorus/payload.sh|$INS_PL/payload.sh
library/user/reconnaissance/starchorus/starchorus-display.sh|$INS_PL/starchorus-display.sh
library/user/reconnaissance/starchorus/alert-deauth.sh|$INS_PL/alert-deauth.sh
INS_E
INS_exec=0
for INS_x in $INS_DESTS; do [ -x "$INS_DEV$INS_x" ] && INS_exec=$((INS_exec + 1)); done
INS_ok=0; [ "$INS_cmpbad" = 0 ] && [ "$INS_exec" = 6 ] && INS_ok=1
rowif "installer: the fake remote root holds the seven files byte for byte ($INS_cmpbad differ), $INS_exec of 7 executable (all but the page)" [ "$INS_ok" = 1 ]
rowif "installer integrity, device without cksum: all 7 files read back and compared, said so in one [PASS] line" \
  grep -q 'the device has no cksum; integrity verified by reading all 7 files back with scp and comparing the bytes (identical)' "$INS_T/dev.out"
rowif "installer smoke test, clean run: the band counters are filled ('2.4:1  5:2  6:1') and reported as a pass" \
  grep -q '\[PASS\] band counters filled: APs 4 .* 2.4:1 5:2 6:1' "$INS_T/dev.out"

# ---- 2. a device that does have cksum: no read-back at all
ins_run ck INS_X_CKSUM=ok
INS_k=$(ins_kinds "$INS_T/ck.log")
INS_ok=0; [ "$INS_RC" = 0 ] && [ "$INS_k" = "mkdir up*7 chmod cksum csel dsel once head smoke" ] && grep -q 'cksum identical for all 7 files (CRC + size)' "$INS_T/ck.out" && ins_clean_judge ck 0 && INS_ok=1
rowif "installer run 2 (device with cksum): exit $INS_RC (want 0), order [$INS_k] (no read-back), 'cksum identical for all 7 files'" [ "$INS_ok" = 1 ]

# ---- 3. a damaged upload: the read-back finds it, the run stops before the self-tests and the smoke test
ins_run bad INS_X_CORRUPT=payload.sh
INS_k=$(ins_kinds "$INS_T/bad.log")
INS_c3=0; [ "$INS_RC" = 1 ] && grep -q 'differ between the repo and the device' "$INS_T/bad.out" && grep -q "$INS_PL/payload.sh: bytes differ after the read-back" "$INS_T/bad.out" \
  && grep -q 'the upload is not intact' "$INS_T/bad.out" && [ "$INS_k" = "mkdir up*7 chmod cksum get*7" ] && INS_c3=1
rowif "installer, one file damaged on upload: exit $INS_RC (want 1), the file named, 'the upload is not intact', stops after the read-back [$INS_k]" [ "$INS_c3" = 1 ]
[ "$INS_c3" = 1 ] || tail -n 8 "$INS_T/bad.out" | cut -c1-200 | sed 's/^/    /'
INS_neg=1; ins_clean_judge bad 7 && INS_neg=0
INS_neg2=1; INS_RC=0; ins_clean_judge bad 7 && INS_neg2=0   # exit status forged to 0: the OUTPUT alone ("differ ...") must make the judge red
INS_RC=1
INS_ok=0; [ "$INS_neg" = 1 ] && [ "$INS_neg2" = 1 ] && INS_ok=1   # both halves in one status: rowif judges only the test it is given
rowif "installer, negative control: the judge of the clean run is RED on the damaged run (by status $INS_neg, by output alone $INS_neg2)" [ "$INS_ok" = 1 ]
# the judge is not red for everything: it is green on the clean run
ins_run dev; rowif "installer, positive control: the same judge is green on the clean run" ins_clean_judge dev 7
# ---- 3b. a device WITH cksum and one damaged file: cksum settles six, only the seventh is read back (the mixed path), and its bytes decide
ins_run ckbad INS_X_CKSUM=ok INS_X_CORRUPT=payload.sh
INS_k=$(ins_kinds "$INS_T/ckbad.log"); INS_sb=$(ins_scp_bad "$INS_T/ckbad.log" 1)
INS_ok=0; [ "$INS_RC" = 1 ] && grep -q '1 of 7 file(s) not settled by cksum -- reading them back with scp and comparing the bytes' "$INS_T/ckbad.out" \
  && grep -q "$INS_PL/payload.sh: bytes differ (cksum local [0-9]* [0-9]*, device [0-9]* [0-9]*)" "$INS_T/ckbad.out" && grep -q 'the upload is not intact' "$INS_T/ckbad.out" \
  && [ "$INS_k" = "mkdir up*7 chmod cksum get" ] && [ -z "$INS_sb" ] && grep -q "^scp-get$INS_TAB.*$INS_TAB$INS_PL/payload.sh$INS_TAB" "$INS_T/ckbad.log" && INS_ok=1
rowif "installer, device with cksum and one file damaged: cksum settles six, the seventh alone is read back and named with both CRCs, exit $INS_RC (want 1), stops after the read-back [$INS_k]" [ "$INS_ok" = 1 ]
[ "$INS_ok" = 1 ] || { [ -z "$INS_sb" ] || printf '%s\n' "$INS_sb" | sed 's/^/    /'; tail -n 8 "$INS_T/ckbad.out" | cut -c1-200 | sed 's/^/    /'; }

# ---- 4. a read-back that fails: integrity NOT verified (a different message), the other checks still run
ins_run nr INS_X_NOREAD=index.html
INS_k=$(ins_kinds "$INS_T/nr.log")
INS_c4=0; [ "$INS_RC" = 1 ] && grep -q 'integrity NOT verified for 1 of 7 file' "$INS_T/nr.out" && grep -q "$INS_L/index.html: could not be read back" "$INS_T/nr.out" \
  && grep -q 'Integrity: NOT verified for 1 of 7 file' "$INS_T/nr.out" && grep -q 'INSTALL NOT VERIFIED' "$INS_T/nr.out" && [ "$INS_k" = "mkdir up*7 chmod cksum get*7 csel dsel once head smoke" ] && INS_c4=1
rowif "installer, one read-back fails: 'integrity NOT verified for 1 of 7', the file named, the other checks still run, exit $INS_RC (want 1), 'INSTALL NOT VERIFIED'" [ "$INS_c4" = 1 ]
[ "$INS_c4" = 1 ] || tail -n 12 "$INS_T/nr.out" | cut -c1-200 | sed 's/^/    /'

# ---- 5. an upload that fails stops the run: nothing after it is sent (no exec bits, no cksum, no self-test, no capture, no smoke test)
ins_run up3 INS_X_UPFAIL=3
INS_k=$(ins_kinds "$INS_T/up3.log")
INS_c5=0; [ "$INS_RC" = 1 ] && grep -q 'upload failed: starchorus-display.sh -> '"$INS_L"'/starchorus-display.sh' "$INS_T/up3.out" && [ "$INS_k" = "mkdir up*3" ] && ! grep -q 'smoke test' "$INS_T/up3.out" && INS_c5=1
rowif "installer, the third upload fails: exit $INS_RC (want 1), 'upload failed' names the file, nothing after it is sent [$INS_k]" [ "$INS_c5" = 1 ]
[ "$INS_c5" = 1 ] || tail -n 6 "$INS_T/up3.out" | cut -c1-200 | sed 's/^/    /'
ins_run nossh INS_X_NOSSH=1
INS_k=$(ins_kinds "$INS_T/nossh.log")
INS_ok=0; [ "$INS_RC" = 1 ] && grep -q 'cannot reach or authenticate' "$INS_T/nossh.out" && [ "$INS_k" = mkdir ] && INS_ok=1
rowif "installer, the device cannot be reached: exit $INS_RC (want 1), 'nothing was installed', one call sent [$INS_k]" [ "$INS_ok" = 1 ]

# ---- 6. the on-device self-tests: a red collector self-test is a failed run; the smoke test's digit rule
ins_run st INS_X_SELFTEST=fail
INS_ok=0; [ "$INS_RC" = 1 ] && grep -q '\[FAIL\] collector selftest: FAILED (1 of 482)' "$INS_T/st.out" && grep -q 'INSTALL NOT VERIFIED' "$INS_T/st.out" && INS_ok=1
rowif "installer, the collector self-test answers FAILED: exit $INS_RC (want 1), '[FAIL] collector selftest: FAILED (1 of 482)', 'INSTALL NOT VERIFIED'" [ "$INS_ok" = 1 ]
INS_sbad=""; INS_sn=0
ins_smoke() {   # ins_smoke KIND WANT_RC 'WANT TEXT or empty' [VAR=value]
  INS_sn=$((INS_sn + 1)); INS_sk=$1; INS_sw=$2; INS_st=$3; shift 3
  ins_run "sm$INS_sn" INS_X_SUMMARY="$INS_sk" "$@"
  [ "$INS_RC" = "$INS_sw" ] || { INS_sbad="$INS_sbad $INS_sk(rc $INS_RC want $INS_sw)"; return; }
  [ -z "$INS_st" ] || grep -qF -- "$INS_st" "$INS_T/sm$INS_sn.out" || INS_sbad="$INS_sbad $INS_sk(no '$INS_st')"
}
ins_smoke ok 0 '[PASS] band counters filled'
ins_smoke blank 1 "no digit after '2.4:'; no digit after '5:'; no digit after '6:'"
ins_smoke five 1 "Overview summary broken: no digit after '5:' ("
ins_smoke spaced 1 "no digit after '2.4:'; no digit after '5:'; no digit after '6:'"
ins_smoke jq 1 "output says 'jq incomplete'"
ins_smoke noband 1 'no band line (2.4: 5: 6:) in the summary'
ins_smoke ok 1 'Overview exited 3' INS_X_SMOKE_RC=3
rowif "installer smoke test: a digit has to follow each colon at once ($INS_sn cases: filled, blank, one band blank, 'spaced', 'jq incomplete', no band line, a non-zero exit)${INS_sbad:+ -- $INS_sbad}" [ -z "$INS_sbad" ]

# ---- 6a. every other branch after the first remote command, each reached by a run of its own (a command sent only on one of them would
#      otherwise pass the judge of every run below): a failed chmod; a cksum that gives no usable output, one whose numbers differ while the
#      bytes are identical, and with one read-back failing; a collector self-test without a result line, or ALL PASS with a non-zero exit; an
#      Overview self-test that is red, without a result line, missing (an older Overview), or ALL PASS with a non-zero exit; a non-zero --once;
#      a failed head; a repo Overview without --selftest (a copy root whose tools/install.sh is the real installer byte for byte)
INS_KW_ALL="mkdir up*7 chmod cksum get*7 csel dsel once head smoke"
INS_qbad=""; INS_qn=0
ins_branch() {   # ins_branch NAME WANT_RC 'WANT KINDS' 'WANT TEXT' [VAR=value ...]
  INS_qn=$((INS_qn + 1)); INS_qm=$1; INS_qw=$2; INS_qk=$3; INS_qt=$4; shift 4
  ins_run "$INS_qm" "$@"; INS_k=$(ins_kinds "$INS_T/$INS_qm.log")
  [ "$INS_RC" = "$INS_qw" ] || INS_qbad="$INS_qbad $INS_qm(rc $INS_RC want $INS_qw)"
  [ "$INS_k" = "$INS_qk" ] || INS_qbad="$INS_qbad $INS_qm(order [$INS_k])"
  grep -qF -- "$INS_qt" "$INS_T/$INS_qm.out" || INS_qbad="$INS_qbad $INS_qm(no '$INS_qt')"
}
ins_branch chm 1 "mkdir up*7 chmod" 'install: chmod +x failed on the device' INS_X_CHMOD=fail
ins_branch ckj 0 "$INS_KW_ALL" '[WARN] cksum gave no usable output on the device (cksum: unrecognised option); integrity verified instead by reading all 7 files back' INS_X_CKSUM=junk
ins_branch cko 0 "$INS_KW_ALL" '[WARN] cksum did not confirm 7 file(s) (line missing, or other numbers), but the bytes read back are identical' INS_X_CKSUM=other
ins_branch ckn 1 "$INS_KW_ALL" "$INS_L/index.html: could not be read back (cksum local " INS_X_CKSUM=other INS_X_NOREAD=index.html
grep -q 'integrity NOT verified for 1 of 7 file' "$INS_T/ckn.out" || INS_qbad="$INS_qbad ckn(no 'integrity NOT verified')"
ins_branch cs1 1 "$INS_KW_ALL" '[FAIL] collector selftest gave no result line (exit 2); last lines:' INS_X_SELFTEST=noline
ins_branch cs2 1 "$INS_KW_ALL" '[FAIL] collector selftest says ALL PASS but exited 3' INS_X_SELFTEST=rc
ins_branch ds1 1 "$INS_KW_ALL" '[FAIL] Overview (starchorus-display.sh) selftest: FAILED (1 of 300)' INS_X_DSELFTEST=fail
ins_branch ds2 1 "$INS_KW_ALL" '[FAIL] Overview (starchorus-display.sh) selftest gave no result line (exit 2); last lines:' INS_X_DSELFTEST=noline
ins_branch ds3 0 "$INS_KW_ALL" '[WARN] Overview (starchorus-display.sh) has no --selftest on the device (older version?)' INS_X_DSELFTEST=old
ins_branch ds4 1 "$INS_KW_ALL" '[FAIL] Overview (starchorus-display.sh) selftest says ALL PASS but exited 4' INS_X_DSELFTEST=rc
ins_branch onc 0 "$INS_KW_ALL" '[WARN] collector --once exited 2' INS_X_ONCE_RC=2
ins_branch hd 0 "$INS_KW_ALL" "[WARN] no readable starchorus.json at $INS_L after --once (head -c 400: exit 1: head: $INS_L/starchorus.json: I/O error)" INS_X_HEAD=fail
# the repo's Overview without --selftest: a copy root (the real installer copied byte for byte, the Overview copies with the flag renamed)
INS_Q="$INS_T/qroot"; mkdir -p "$INS_Q/tools" "$INS_Q/library/user/reconnaissance/starchorus"
cp "$R/tools/install.sh" "$INS_Q/tools/install.sh"
for INS_x in starchorus-collect.sh starchorus.html starchorus-serve.sh; do ln -s "$R/$INS_x" "$INS_Q/$INS_x"; done
for INS_x in payload.sh alert-deauth.sh; do ln -s "$R/library/user/reconnaissance/starchorus/$INS_x" "$INS_Q/library/user/reconnaissance/starchorus/$INS_x"; done
sed 's/--selftest/--no-such-flag/g' "$R/starchorus-display.sh" > "$INS_Q/starchorus-display.sh"
cp "$INS_Q/starchorus-display.sh" "$INS_Q/library/user/reconnaissance/starchorus/starchorus-display.sh"
INS_qsame=0; cmp -s "$INS_Q/tools/install.sh" "$R/tools/install.sh" && ! grep -qF -- '--selftest' "$INS_Q/starchorus-display.sh" && INS_qsame=1
INS_IN="$INS_Q/tools/install.sh"
ins_branch odisp 0 "mkdir up*7 chmod cksum get*7 csel once head smoke" '[WARN] starchorus-display.sh in this repo has no --selftest yet -- the Overview selftest was skipped'
INS_IN="$R/tools/install.sh"
[ "$INS_qsame" = 1 ] && INS_RUNS="$INS_RUNS odisp"   # the copy IS the real installer: its run is one of the real installer's runs
INS_ok=0; [ -z "$INS_qbad" ] && [ "$INS_qn" = 13 ] && [ "$INS_qsame" = 1 ] && INS_ok=1
rowif "installer's other failure branches, each reached by a run of its own ($INS_qn of 13: chmod fails; cksum no use, other numbers, other numbers and a read-back fails; collector self-test without a result line, ALL PASS with exit 3; Overview self-test red, without a result line, missing, ALL PASS with exit 4; --once exit 2; head fails; the repo's Overview without --selftest)${INS_qbad:+ -- $INS_qbad}" [ "$INS_ok" = 1 ]

# ---- 6b. the header's promise on EVERY run of the real installer, the failure paths included (a command sent only when a check fails
#      would pass every row above, which judge the commands on the clean runs only), and the cleanup call that closes the master connection
ins_every_bad() {   # ins_every_bad NAME ... -> INS_eo: "NAME: what" for every log with a command not on the list, an option not in the master set or a line
                    # of the wrong shape (empty = nothing else in any of them); INS_ejn = the logs judged (not in a subshell, so both survive)
  INS_ejn=0; : > "$INS_T/every.txt"
  for INS_e in "$@"; do
    [ -s "$INS_T/$INS_e.log" ] || { echo "$INS_e: no log" >> "$INS_T/every.txt"; continue; }
    INS_ejn=$((INS_ejn + 1))
    { ins_cmds_bad "$INS_T/$INS_e.log"; ins_opts_bad "$INS_T/$INS_e.log"; } | cut -c1-160 | sed "s/^/$INS_e: /" >> "$INS_T/every.txt"
  done
  INS_eo=$(cat "$INS_T/every.txt")
}
INS_ALL="bad chm ck ckbad ckj ckn cko cs1 cs2 dev ds1 ds2 ds3 ds4 hd nossh nr odisp onc sm1 sm2 sm3 sm4 sm5 sm6 sm7 st up3"   # sorted (C): the runs of the real installer above, failure runs included
INS_rs=$(printf '%s' "$INS_RUNS" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort | tr '\n' ' '); INS_rs=${INS_rs% }
# shellcheck disable=SC2086   # INS_ALL is a word list on purpose
ins_every_bad $INS_ALL; INS_eb=$INS_eo
# shellcheck disable=SC2086   # INS_ALL is a word list on purpose
INS_na=$(printf '%s\n' $INS_ALL | wc -l | tr -d ' ')
INS_ok=0; [ "$INS_rs" = "$INS_ALL" ] && [ "$INS_na" = 28 ] && [ "$INS_ejn" = 28 ] && [ -z "$INS_eb" ] && INS_ok=1
rowif "installer sends nothing but the header's remote commands in every run, the failure paths included ($INS_ejn of 28 logs judged: clean, cksum, damaged, unreadable, failed upload, unreachable, red self-test, seven smoke cases, the thirteen other failure branches; runs recorded = the list: $([ "$INS_rs" = "$INS_ALL" ] && echo yes || echo "no [$INS_rs]"))" [ "$INS_ok" = 1 ]
[ -z "$INS_eb" ] || printf '%s\n' "$INS_eb" | sed 's/^/    /'
# the cleanup: a run whose master connection came up closes it with one `-O exit` call, its last call; the run that never connected sends none
INS_cxbad=""; INS_cxn=0
for INS_e in $INS_ALL; do
  INS_cxc=$(grep -c "^ssh$INS_TAB$INS_HOST$INS_TAB-o ControlPath=[^$INS_TAB]* -O exit$INS_TAB\$" "$INS_T/$INS_e.log")
  if [ "$INS_e" = nossh ]; then [ "$INS_cxc" = 0 ] || INS_cxbad="$INS_cxbad $INS_e($INS_cxc)"
  else
    INS_cxl=$(tail -n 1 "$INS_T/$INS_e.log" | cut -f 3)
    case $INS_cxc:$INS_cxl in "1:-o ControlPath="*" -O exit") INS_cxn=$((INS_cxn + 1)) ;; *) INS_cxbad="$INS_cxbad $INS_e($INS_cxc)" ;; esac
  fi
done
INS_ok=0; [ "$INS_cxn" = 27 ] && [ -z "$INS_cxbad" ] && INS_ok=1
rowif "installer's cleanup closes the master connection: one '-O exit' call, the last of the run, in $INS_cxn of 27 runs that connected, none in the run that could not; the judges above accept it${INS_cxbad:+ -- wrong:$INS_cxbad}" [ "$INS_ok" = 1 ]

# ---- 7. the judges bite: dummy logs with one planted fault each (the intact log is green)
INS_O="-o ControlMaster=auto -o ControlPath=/x/cm -o ControlPersist=300 -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15"
INS_jn=0; INS_jbad=0
ins_dummy() {   # ins_dummy WANT JUDGE 'log line' ... -> JUDGE on a log made of the lines (WANT = red | green)
  INS_jw=$1; INS_jj=$2; shift 2; INS_jn=$((INS_jn + 1)); : > "$INS_T/dummy.log"
  for INS_jl in "$@"; do printf '%s\n' "$INS_jl" >> "$INS_T/dummy.log"; done
  case $INS_jj in
    cmds) INS_jo=$(ins_cmds_bad "$INS_T/dummy.log") ;;
    opts) INS_jo=$(ins_opts_bad "$INS_T/dummy.log") ;;
    scp7) INS_jo=$(ins_scp_bad "$INS_T/dummy.log" 0) ;;
  esac
  if [ "$INS_jw" = red ]; then [ -n "$INS_jo" ] || { INS_jbad=$((INS_jbad + 1)); echo "    judge case $INS_jn ($INS_jj): want red, got green"; }
  else [ -z "$INS_jo" ] || { INS_jbad=$((INS_jbad + 1)); echo "    judge case $INS_jn ($INS_jj): want green, got: $INS_jo"; }; fi
}
INS_sl() { printf 'ssh\t%s\t%s\t%s' "${3:-$INS_HOST}" "${2:-$INS_O}" "$1"; }
ins_dummy green cmds "$(INS_sl 'mkdir -p /root/loot/starchorus /root/payloads/user/reconnaissance/starchorus')" "$(INS_sl "chmod +x $INS_L/a.sh $INS_PL/b.sh")" \
  "$(INS_sl "cksum $INS_L/a.sh $INS_PL/b.sh")" "$(INS_sl "sh $INS_L/starchorus-collect.sh --selftest")" \
  "$(INS_sl "cd $INS_L && STARCHORUS_OUTDIR=$INS_L STARCHORUS_MAX_AGE=3600 ./starchorus-collect.sh --once")" "$(INS_sl "head -c 400 $INS_L/starchorus.json")"
ins_dummy red cmds "$(INS_sl 'uname -a')"
ins_dummy red cmds "$(INS_sl "sh $INS_L/starchorus-collect.sh --selftest; reboot")"
ins_dummy red cmds "$(INS_sl "sh $INS_L/starchorus-collect.sh --status")"
ins_dummy red cmds "$(INS_sl "sh $INS_L/starchorus-collect.sh --stop")"
ins_dummy red cmds "$(INS_sl "chmod +x /etc/passwd")"
ins_dummy red cmds "$(INS_sl "cksum $INS_L/a.sh /etc/shadow")"
ins_dummy red cmds "$(INS_sl "mkdir -p $INS_L /tmp/x")"
ins_dummy red cmds "$(INS_sl "head -c 400 /etc/passwd")"
ins_dummy red cmds "$(INS_sl "opkg install x")"
ins_dummy red cmds "$(INS_sl "mkdir -p $INS_L $INS_PL ; uname -a")"
INS_CX='-o ControlPath=/x/cm -O exit'
ins_dummy green cmds "$(INS_sl '' "$INS_CX")"
ins_dummy red cmds "$(INS_sl '' "$INS_O -O forward -L8080:127.0.0.1:80")"
ins_dummy red cmds "$(INS_sl '' '-o ControlPath=/x/cm -O cancel')"
ins_dummy red cmds "$(INS_sl '' "$INS_CX -L8080:127.0.0.1:80")"
ins_dummy red cmds "$(INS_sl 'uname -a' "$INS_CX")"
ins_dummy green opts "$(INS_sl '' "$INS_CX")"
ins_dummy red opts "$(INS_sl '' "$INS_O -O forward -L8080:127.0.0.1:80")"
ins_dummy red opts "$(INS_sl '' "$INS_CX -L8080:127.0.0.1:80")"
ins_dummy red opts "$(INS_sl 'uname -a' "$INS_CX")"
ins_dummy green opts "$(INS_sl 'true')"
ins_dummy red opts "$(INS_sl 'true' "$INS_O -L 8080:127.0.0.1:80")"
ins_dummy red opts "$(INS_sl 'true' "$INS_O -A")"
ins_dummy red opts "$(INS_sl 'true' '-o ControlMaster=auto')"
ins_dummy red opts "$(INS_sl 'true' "$INS_O" 203.0.113.9)"
ins_dummy red opts "$(printf 'scp-up\t%s\t%s\t%s\t%s' "$INS_HOST" "$INS_O" /a "$INS_L/x")"
ins_dummy green opts "$(printf 'scp-up\t%s\t-O %s\t%s\t%s' "$INS_HOST" "$INS_O" /a "$INS_L/x")"
INS_up() { printf 'scp-up\t%s\t-O %s\t/x\t%s' "$INS_HOST" "$INS_O" "$1"; }
INS_all=""; for INS_x in $INS_DESTS; do INS_all="$INS_all
$(INS_up "$INS_x")"; done
INS_dl=$(printf '%s\n' "$INS_all" | sed '1d')
ins_bite() {   # ins_bite red|green NAME LOG GETS: the scp judge on a log file
  INS_jn=$((INS_jn + 1)); INS_bo=$(ins_scp_bad "$3" "$4")
  if [ "$1" = red ]; then [ -n "$INS_bo" ] || { INS_jbad=$((INS_jbad + 1)); echo "    judge case: $2 is not red"; }
  else [ -z "$INS_bo" ] || { INS_jbad=$((INS_jbad + 1)); echo "    judge case: $2 is not green: $INS_bo"; }; fi
}
printf '%s\n' "$INS_dl" > "$INS_T/dummy.log"
ins_bite green 'the seven uploads in order' "$INS_T/dummy.log" 0
printf '%s\n' "$INS_dl" | awk 'NR == 2 { held = $0; next } { print } NR == 3 { print held }' > "$INS_T/dummy2.log"          # uploads 2 and 3 swapped
ins_bite red 'two uploads swapped' "$INS_T/dummy2.log" 0
{ printf '%s\n' "$INS_dl"; printf 'scp-get\t%s\t-O %s\t%s\t/y\n' "$INS_HOST" "$INS_O" /root/loot/starchorus/settings.conf; } > "$INS_T/dummy3.log"
ins_bite red 'a read of a file that was never sent' "$INS_T/dummy3.log" 1
printf '%s\n' "$INS_dl" | sed "s|$INS_L/index.html|/root/index.html|" > "$INS_T/dummy4.log"
ins_bite red 'an upload to another path' "$INS_T/dummy4.log" 0
# the shape of a line: a tab or a line break inside a word, raw (more fields) or as the stand-ins log it (\001 / \002), a short line, an unknown kind;
# and the remote path of an scp, which the legacy protocol hands to the remote shell
INS_C1=$(printf '\001'); INS_C2=$(printf '\002')
ins_dummy red cmds "$(printf 'ssh\t%s\t%s\t%s\t%s' "$INS_HOST" "$INS_O" "mkdir -p $INS_L $INS_PL" '; uname -a')"
ins_dummy red cmds "$(INS_sl "mkdir -p $INS_L $INS_PL$INS_C1; uname -a")"
ins_dummy red cmds "$(INS_sl "mkdir -p $INS_L $INS_PL${INS_C2}uname -a")"
ins_dummy red cmds "$(printf 'ssh\t%s\t%s' "$INS_HOST" "$INS_O")"
ins_dummy red cmds "$(printf 'rsh\t%s\t%s\t%s' "$INS_HOST" "$INS_O" 'uname -a')"
ins_dummy green cmds "$INS_dl" "$(printf 'scp-get\t%s\t-O %s\t%s\t/y' "$INS_HOST" "$INS_O" "$INS_L/index.html")"
ins_dummy red cmds "$(printf 'scp-up\t%s\t-O %s\t/x\t%s\t%s' "$INS_HOST" "$INS_O" "$INS_PL/alert-deauth.sh" '; uname -a')"
ins_dummy red cmds "$(INS_up "$INS_PL/alert-deauth.sh$INS_C1; uname -a")"
ins_dummy red cmds "$(INS_up /etc/x)"
ins_dummy red cmds "$(printf 'scp-get\t%s\t-O %s\t%s\t/y' "$INS_HOST" "$INS_O" /etc/shadow)"
ins_dummy red opts "$(printf 'ssh\t%s\t%s\t%s\t%s' "$INS_HOST" "$INS_O" 'true' '; uname -a')"
ins_dummy red scp7 "$(printf '%s\n' "$INS_dl" | sed '$d')" "$(printf 'scp-up\t%s\t-O %s\t/x\t%s\t%s' "$INS_HOST" "$INS_O" "$INS_PL/alert-deauth.sh" '; uname -a')"
INS_ok=0; [ "$INS_jbad" = 0 ] && [ "$INS_jn" -ge 43 ] && INS_ok=1   # every case as expected, and none of the 43 left out: one status, as rowif judges only the test it is given
rowif "installer judges bite on dummy logs ($((INS_jn - INS_jbad))/$INS_jn as expected: an extra command, a chained one, --status, --stop, a foreign path, a forward (-L and -O forward), an -O exit with a command or an option, a changed option, a third host, swapped, mis-sent and read-back files, a tab or a line break inside a command or a path, a short line, an unknown kind, an scp to or from a path not on the list)" [ "$INS_ok" = 1 ]

# ---- 8. the real mutations: copies of install.sh that send more than the header allows; the judges are red on THEIR logs and green on the real installer's
INS_M="$INS_T/mroot"; mkdir -p "$INS_M/tools" "$INS_M/library/user/reconnaissance/starchorus"
for INS_x in starchorus-collect.sh starchorus.html starchorus-display.sh starchorus-serve.sh; do ln -s "$R/$INS_x" "$INS_M/$INS_x"; done
for INS_x in payload.sh starchorus-display.sh alert-deauth.sh; do ln -s "$R/library/user/reconnaissance/starchorus/$INS_x" "$INS_M/library/user/reconnaissance/starchorus/$INS_x"; done
INS_real=$INS_IN
ins_mut() {   # ins_mut NAME KIND [VAR=value ...] -> INS_MUT (1 = the copy differs from the real installer), INS_RC and the log $INS_T/NAME.log of a run of the copy
  INS_mname=$1; INS_mkind=$2; shift 2
  # shellcheck disable=SC2016   # the awk programs are literal text; the installer's variables are meant to stay unexpanded in what they print
  case $INS_mkind in
    cmd) awk '{ print } /^say "==> setting exec bits"$/ { print "rsh \"uname -a\" >/dev/null" }' "$INS_real" ;;                                        # one more remote command
    arg) awk 'index($0, "rsh()") == 1 { sub(/"\$1" <\/dev\/null/, "\"$1\" \"; uname -a\" </dev/null") } { print }' "$INS_real" ;;                   # a second argument to every rsh: ssh joins it into the command
    fwd) awk '{ print } /^say "==> setting exec bits"$/ { print "ssh $SSH_OPTS -O forward -L8080:127.0.0.1:80 \"root@$HOST\" </dev/null >/dev/null 2>&1" }' "$INS_real" ;;   # a port forward through the master
    tab) awk '$0 == "CMD_MKDIR=\"mkdir -p $LOOT $PLDIR\"" { $0 = "CMD_MKDIR=\"mkdir -p $LOOT $PLDIR\t; uname -a\"" } { print }' "$INS_real" ;;          # a tab, then a second command
    nl)  awk '$0 == "CMD_MKDIR=\"mkdir -p $LOOT $PLDIR\"" { $0 = "CMD_MKDIR=\"mkdir -p $LOOT $PLDIR\nuname -a\"" } { print }' "$INS_real" ;;           # a line break, then a second command
    dtab) awk 'index($0, "$PLSRC/alert-deauth.sh|$PLDIR/alert-deauth.sh|x") == 1 { sub(/[|]x"$/, "\t; uname -a|x\"") } { print }' "$INS_real" ;;   # a tab in one destination of FILES
    stopst) awk '{ print } index($0, "res FAIL \"$_l selftest: ${_s#") > 0 { print "      rsh \"$CMD_STOP\" >/dev/null 2>&1" }' "$INS_real" ;;           # service control, only when a self-test is red
    stopsm) awk '{ print } index($0, "res FAIL \"Overview summary broken:") > 0 { print "  rsh \"$CMD_STOP\" >/dev/null 2>&1" }' "$INS_real" ;;               # service control, only when the smoke test is red
    stopon) awk 'index($0, "else res WARN \"collector --once exited") == 1 { sub(/^else /, "else rsh \"$CMD_STOP\" >/dev/null 2>/dev/null; ") } { print }' "$INS_real" ;;   # service control, only on the --once WARN branch
  esac > "$INS_M/tools/install.sh"
  INS_MUT=0; cmp -s "$INS_M/tools/install.sh" "$INS_real" || INS_MUT=1
  INS_IN="$INS_M/tools/install.sh"; ins_run "$INS_mname" "$@"; INS_IN=$INS_real
}
ins_mut mut cmd; INS_mrc=$INS_RC; INS_mm=$INS_MUT
INS_mb=$(ins_cmds_bad "$INS_T/mut.log")
INS_ok=0; [ "$INS_mm" = 1 ] && [ "$INS_mb" = "uname -a" ] && [ -z "$(ins_cmds_bad "$INS_T/dev.log")" ] && INS_ok=1
rowif "installer, negative probe: a copy that sends 'uname -a' as well (it ran: exit $INS_mrc, the copy differs: $INS_mm) is caught by the 'nothing else' judge: [$INS_mb]" [ "$INS_ok" = 1 ]
# a second argument to rsh: the stand-in logs what ssh would send (all arguments after the host, joined), so the chained command shows
ins_mut mut2 arg; INS_mrc=$INS_RC; INS_mm=$INS_MUT
INS_mb=$(ins_cmds_bad "$INS_T/mut2.log"); INS_mn=$(printf '%s\n' "$INS_mb" | grep -c '; uname -a$')
INS_ok=0; [ "$INS_mm" = 1 ] && [ "$INS_mn" -ge 1 ] && INS_ok=1
rowif "installer, negative probe: a copy that passes a second argument ('; uname -a') to ssh, which ssh joins into the remote command (it ran: exit $INS_mrc, the copy differs: $INS_mm), is caught by the 'nothing else' judge: $INS_mn command(s) not on the list" [ "$INS_ok" = 1 ]
# a port forward through the master connection: an -O call that is not the cleanup's `-O exit`
ins_mut mut3 fwd; INS_mrc=$INS_RC; INS_mm=$INS_MUT
INS_mb=$(ins_cmds_bad "$INS_T/mut3.log"); INS_mo=$(ins_opts_bad "$INS_T/mut3.log")
INS_ok=0; [ "$INS_mm" = 1 ] && printf '%s\n' "$INS_mb" | grep -q -- '-O forward' && printf '%s\n' "$INS_mo" | grep -q -- '-O forward' && ! ins_clean_judge mut3 7 && INS_ok=1
rowif "installer, negative probe: a copy that opens a port forward through the master connection (-O forward; it ran: exit $INS_mrc, the copy differs: $INS_mm) is caught by both the 'nothing else' judge and the options judge" [ "$INS_ok" = 1 ]
# a tab or a line break inside a remote command or an scp path: on a device the remote shell would run what follows it; the stand-ins log it as
# \001 / \002, so it can never land in a log field that no judge reads
INS_tn=0; INS_tc=0; INS_tw=""
for INS_x in tab nl dtab; do
  INS_tn=$((INS_tn + 1)); ins_mut "mt$INS_x" "$INS_x"
  INS_mb=$(ins_cmds_bad "$INS_T/mt$INS_x.log"); INS_mn=$(printf '%s\n' "$INS_mb" | grep -c 'a tab or a line break inside a word')
  if [ "$INS_MUT" = 1 ] && [ "$INS_mn" -ge 1 ] && ! ins_clean_judge "mt$INS_x" 7; then INS_tc=$((INS_tc + 1)); INS_tw="$INS_tw $INS_x:$INS_mn"
  else INS_tw="$INS_tw $INS_x:MISSED(differs $INS_MUT, $INS_mn line(s))"; fi
done
rowif "installer, negative probe: copies with a tab in the mkdir command, a line break in it, and a tab in one destination of FILES (each followed by 'uname -a') are caught by the 'nothing else' judge: $INS_tc of $INS_tn [$INS_tw ]" [ "$INS_tc" = 3 ]
# a command sent only on a failure path: copies that send the collector's --stop (service control, which the header rules out) only when
# the collector self-test is red, or only when the smoke test is red. On the clean flow they send nothing more (the clean judge stays green:
# that is the blind spot); the judge of every run is red on their failure runs and names --stop
ins_mut fpok stopst; INS_fm1=$INS_MUT; INS_fblind=0; ins_clean_judge fpok 7 && INS_fblind=1
ins_mut fpst stopst INS_X_SELFTEST=fail; INS_fm2=$INS_MUT; ins_every_bad fpst; INS_fe1=$INS_eo; INS_fj1=$INS_ejn
ins_mut fpsm stopsm INS_X_SUMMARY=blank; INS_fm3=$INS_MUT; ins_every_bad fpsm; INS_fe2=$INS_eo; INS_fj2=$INS_ejn
# shellcheck disable=SC2086   # INS_ALL is a word list on purpose
ins_every_bad $INS_ALL; INS_fe3=$INS_eo; INS_fj3=$INS_ejn
INS_ok=0; [ "$INS_fm1$INS_fm2$INS_fm3" = 111 ] && [ "$INS_fblind" = 1 ] && [ "$INS_fj1$INS_fj2" = 11 ] \
  && printf '%s\n' "$INS_fe1" | grep -q -- '--stop$' && printf '%s\n' "$INS_fe2" | grep -q -- '--stop$' && [ -z "$INS_fe3" ] && [ "$INS_fj3" = 28 ] && INS_ok=1
rowif "installer, negative probe: copies that send --stop only when the collector self-test is red, or only when the smoke test is red (the clean judge is blind to them on the clean flow: $INS_fblind), are caught by the judge of every run on their failure runs; the real installer's 28 logs stay green" [ "$INS_ok" = 1 ]
[ "$INS_ok" = 1 ] || printf '%s\n' "$INS_fe1" "$INS_fe2" "$INS_fe3" | sed '/^$/d; s/^/    /'
# the same on a branch that only a run of 6a reaches: a copy that sends --stop only when --once exits non-zero (a WARN, the run still exits 0)
ins_mut fpok2 stopon; INS_fm4=$INS_MUT; INS_fblind2=0; ins_clean_judge fpok2 7 && INS_fblind2=1
ins_mut fpon stopon INS_X_ONCE_RC=2; INS_fm5=$INS_MUT; INS_frc5=$INS_RC; ins_every_bad fpon; INS_fe4=$INS_eo; INS_fj4=$INS_ejn
INS_ok=0; [ "$INS_fm4$INS_fm5" = 11 ] && [ "$INS_fblind2" = 1 ] && [ "$INS_fj4" = 1 ] && [ "$INS_frc5" = 0 ] && printf '%s\n' "$INS_fe4" | grep -q -- '^fpon: .*--stop$' && INS_ok=1
rowif "installer, negative probe: a copy that sends --stop only when --once exits non-zero (a warning: that run still exits $INS_frc5) passes the clean judge on the clean flow ($INS_fblind2) and is caught by the judge of every run on its --once run" [ "$INS_ok" = 1 ]
[ "$INS_ok" = 1 ] || printf '%s\n' "$INS_fe4" | sed '/^$/d; s/^/    /'

# ---- A7b: the collector's own self-test under dash, the way tools/static.sh runs it (output into a file, judged by selftest_verdict). The self-test starts
#      many children as `sh "$0" --once` and the like; the farm below puts dash in the place of sh, so those children run under dash too.
if command -v dash > /dev/null 2>&1; then
  INS_DASH=$(command -v dash); INS_DF="$INS_T/dashbin"; mkdir -p "$INS_DF"
  path_farm "$INS_DF" sh dash
  rm -f "$INS_DF/sh" "$INS_DF/dash"; ln -s "$INS_DASH" "$INS_DF/sh"; ln -s "$INS_DASH" "$INS_DF/dash"
  # The fairness probe runs under dash with the farm as its PATH, not in this shell: bash (the /bin/sh of the development machine) answers
  # `PATH=... command -v sh` from its command hash once it has run `sh` (regress.sh does, before the drop-ins), and said /bin/sh in the full run.
  # shellcheck disable=SC2016   # the program text is for dash; $1 and the version variables expand there, on purpose
  INS_fv=$("$INS_DASH" -c 'PATH=$1; export PATH; command -v sh; sh -c '\''echo ${BASH_VERSION-no}${ZSH_VERSION-}'\''' _ "$INS_DF" 2>/dev/null)
  INS_dfair=0; case $INS_fv in "$INS_DF/sh"?no) INS_dfair=1 ;; esac   # line 1: the farm's sh is found; line 2: it is not bash and not zsh
  ( PATH="$INS_DF"; export PATH; "$INS_DASH" starchorus-collect.sh --selftest ) > "out/$P-selftest-dash.txt" 2>&1
  INS_dl=$(selftest_verdict "out/$P-selftest-dash.txt" "$MIN_SELFTEST"); INS_dc=$?
  if [ "$INS_dc" = 3 ]; then notcov "collector selftest under dash (and its children, sh = dash): $INS_dl"
  else
    INS_ok=0; [ "$INS_dc" = 0 ] && [ "$INS_dfair" = 1 ] && INS_ok=1   # the verdict and the fairness of the farm in one status
    rowif "collector selftest under dash, its children too (sh = dash on PATH: $INS_dfair): $INS_dl" [ "$INS_ok" = 1 ]
    [ "$INS_dc" = 0 ] || { grep -E 'FAIL|SELFTEST' "out/$P-selftest-dash.txt" | head -n 20 | cut -c1-200 | sed 's/^/    /'; }
  fi
else
  notcov "collector selftest under dash: dash is not installed on this machine, the run did not happen"
fi
fi
[ -z "$INS_T" ] || rm -rf "$INS_T"
