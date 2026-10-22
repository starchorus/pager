#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/passivity-check.sh -- static passivity + legal checks (spec §14.2, §14.6, §14.7).
# usage: sh tools/passivity-check.sh [--files|--regexes|--pending]   (any cwd; reads repo files only, sends nothing; --files = print the shell file list of the §14.6 scope, then tools/device-probe.sh;
#        --regexes = print "NAME<TAB>regex" of the alternation families the rows use, tools/passivity-mutate.sh splits them per alternative;
#        --pending = print what is announced and not there yet (BT_NOT_YET, APCLI_NOT_YET), one name per line: empty once the collector has them all)
# Prints one PASS/FAIL row per check; exit 0 = all PASS, 1 = at least one FAIL, 2 = setup problem. Besides the names of the Bluetooth stack (rows 6b), the row 6d lists every command
# of the shell scope whose NAME is built when the line runs (a command word that holds an expansion), and the row 6e every command whose name a glob, `find -exec`, `xargs` or an alias makes,
# each against a pinned list.
# Every row here has a planted violation in tools/passivity-mutate.sh: a row renamed or a rule widened makes that script
# say which name/mutation to adjust. The sqlite3 (-readonly) and starchorus-serve.sh rows are covered the same way.
# tools/device-probe.sh is the one file of tools/ that runs on the device. It is in the scope with three rows of its own (row 7d below, 'device-probe.sh ...'): the same denylists
# read it, and what it deliberately names is a pinned line (file, function and text, each once); its 'programs' row also holds that it writes nowhere but its private directory (every redirection, every destination of cp, mv and tee), and that the action of every trap, the delimiter and the body of every here-document and the argument of every vset call are forms the reader can read.
# The probe is read whole, by one reader, and the lists those rows lean on (its functions, its function heads, its code lines) come from that reading, from no text scan of the raw file: a line in a comment, a here-document body or a string
# that looks like a function head, a comment or a closing brace is none of these, and a line that looks like a comment inside a string or after a backslash is code.
# The rows above do not read it and no allowlist, regex or pin of theirs applies to it.
# The files of the other scope (the collector, both Overview copies, both payload.sh, starchorus-serve.sh and library/) are read the same way: whole, file by file, by the one reader (shview below), and the function a line belongs to
# (the allowlists and the pins), the function heads and the comment lines come from that reading. A function head, a closing brace or a comment-looking line inside a here-document body, a string or after a backslash is text, a
# head inside a function is a definition nested in its body, and the body of a here-document with a bare delimiter is expanded when it runs, so a `$( )` or a backtick expression in it is read as code.
set -u
here=$(cd "$(dirname "$0")" && pwd -P) || exit 2
R=$(cd "$here/.." && pwd -P) || exit 2
cd "$R" || exit 2
H=starchorus.html
DISPLAY_COPY=library/user/reconnaissance/starchorus/starchorus-display.sh
# shellcheck disable=SC2015   # every term is a side-effect-free [ -f ] test; || is the intended guard clause
[ -f "$H" ] && [ -f starchorus-collect.sh ] && [ -f starchorus-display.sh ] && [ -f "$DISPLAY_COPY" ] || { echo "passivity-check: repo files missing" >&2; exit 2; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-pc.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT TERM
fail=0
row() { printf '%-44s %s\n' "$1" "$2"; [ "$2" = PASS ] || fail=1; }
rowif() { _n=$1; shift; if "$@"; then row "$_n" PASS; else row "$_n" FAIL; fi; }
show() { sed 's/^/    /' | cut -c1-200; }   # stdin as indented evidence under a FAIL row
lines() { wc -l < "$1" | tr -d ' '; }

# Shell files of the §14.6 check: collector, both Overview copies, root payload.sh, the nc listener starchorus-serve.sh (it is in the
# denylist file set, so it belongs to the shell scope too), every file under library/ except its Markdown docs (the payload
# directory ships to the device as a whole, so a helper without the .sh suffix is in scope too). `--files` prints this list, then tools/device-probe.sh, and
# exits (tools/regress.d/doc-truth.sh compares it with the shell files the repository really has, both ways).
{ printf '%s\n' starchorus-collect.sh starchorus-display.sh payload.sh starchorus-serve.sh; find library -type f ! -name '*.md' | LC_ALL=C sort; } | awk '!seen[$0]++' > "$tmp/shfiles"
# The device probe: the one file of tools/ that runs on the device (it is piped into a device shell over ssh). It is in the scope, but not in the list above: the rows above (and every
# allowlist, regex and pin they hold) read only that list and stay as strict as they were; the probe has the rows 'device-probe.sh ...' (7d below) with a pinned list of its own.
PROBE=tools/device-probe.sh
printf '%s\n' "$PROBE" > "$tmp/pfiles"
[ "${1:-}" != --files ] || { cat "$tmp/shfiles" "$tmp/pfiles"; exit 0; }
# Regex families: ONE definition of every alternation the rows below use. `--regexes` prints them; tools/passivity-mutate.sh
# splits each at its top-level `|` and demands one planted violation per ALTERNATIVE (a thinned-out alternative stays unseen by
# a row-level probe). Keep them flat: a new alternative goes on the top level, and needs one line in that script's table.
NETSURF_RE='method:|POST|XMLHttpRequest|WebSocket|EventSource|sendBeacon'
# Navigation is a command path too: `document.location = "/cgi-bin/x?cmd=…"` sends the query to the device
# just as a fetch would, bare or object-prefixed (document./window./top./parent./self.). A JS-built anchor
# (createElement("a") + .click() / download=) is the same hole without the word "location".
NETX='RTCPeerConnection|WebTransport|serviceWorker|new (Shared)?Worker\(|importScripts|import\(|window\.open\(|location\.(assign|replace)\(|(^|[^A-Za-z0-9_])((document|top|parent|self|window)\.)?location(\.href)?[[:space:]]*=[^=]|createElement\(["'"'"'`]a["'"'"'`]\)|\.click\(|download=|<form|<iframe|new Image\(|<link|<script[^>]+src=|@import|url\(["'"'"']?https?:'
SEC6_RE='_pineap|PINEAPPLE_|WIGLE_|DEAUTH|SSID_POOL|GPS_GET'
# The firmware's other active or outward commands, by name and by prefix (a trailing `_` is a prefix: every command that starts
# so is denied, whatever the firmware adds to the family later). PINEAPPLE_ above already covers PINEAPPLE_LOOT_ARCHIVE.
SEC6_RE=$SEC6_RE'|WIFI_CONNECT|WIFI_DISCONNECT|WIFI_MGMT_AP|WIFI_OPEN_AP|WIFI_WPA_AP|WIFI_PCAP_|INSTALL_FIRMWARE'
SEC6_RE=$SEC6_RE'|OPENVPN_|WIREGUARD_|AUTOSSH_|SSH_ADD_KNOWN_HOST|DNSSPOOF_|SYSTEM_DNS|GPS_CONFIGURE|FIND_CLIENT_IP'
TX_WORDS='aireplay(-ng)?|mdk[34]|hostapd|airbase(-ng)?|hcxdumptool|wpa_supplicant|nmcli|iwlist'
# More that send frames or packets, scan a network, replay a capture, or change or drive a radio (the control programs of hostapd and wpa_supplicant, the monitor-mode switch of
# the aircrack family, the WPS attacks). Each is its own alternative with its own sample in tools/passivity-mutate.sh. Like the names above they are read wherever they stand in a
# code line (a log text too, so a text names the tool by its role, or spells the product's name with a capital: Nmap); the lines of the collector that must name one are pinned below.
TX_WORDS=$TX_WORDS'|nmap|iwconfig|tcpreplay|airmon(-ng)?|mausezahn|hping3?|arping|bettercap|wpa_cli|hostapd_cli|besside(-ng)?|reaver|bully'
# The named Bluetooth verbs that transmit (inquiry, paging, connecting, advertising, raw commands, `bluetoothctl scan on`, GATT access,
# and `hciconfig` with anything after an optional `-a`, which can change an adapter's state). By verb: it is defence in depth only, and
# the rows 6b below, which deny every tool of the stack by NAME (BT_WORDS), are what actually keeps a verb nobody listed out. The passive
# route (`btmon -i hci0` and `hcitool -i hci0 lescan --passive --duplicates`) is not here on purpose: it is the two literal lines of
# bt_begin, which those rows pin.
TX_WORDS=$TX_WORDS'|hcitool[[:space:]]+scan|hcitool[[:space:]]+inq|hcitool[[:space:]]+cc|hcitool[[:space:]]+lecc'
TX_WORDS=$TX_WORDS'|hcitool[[:space:]]+leadv|hcitool[[:space:]]+cmd|l2ping|bluetoothctl[[:space:]]+(.*[[:space:]])?scan[[:space:]]+on'
TX_WORDS=$TX_WORDS'|btmgmt|gatttool|hciconfig([[:space:]]+-a)*[[:space:]]+([^[:space:];&|)<>#-][^[:space:]]*|-[^a[:space:]][^[:space:]]*|-a[A-Za-z0-9_]+)'
IW_VERBS='connect|ibss[[:space:]]+join|mesh[[:space:]]+join'
TX_RE="(^|[^A-Za-z0-9_-])($TX_WORDS)([^A-Za-z0-9_]|\$)|(^|[^A-Za-z_])iw[[:space:]].*[[:space:]]($IW_VERBS)([^A-Za-z_]|\$)"
# The Bluetooth stack, denied BY TOOL (docs/architecture.md §14.6), not by verb. BT_WORDS names every program and path of BlueZ that the device has or that
# a contributor might reach for; a word of this family may stand only inside the functions of BT_FUNCS (below) and there only in the
# forms the Bluetooth rows enforce. So a verb or an option nobody listed cannot pass: `hcitool -i hci0 scan`, `bluetoothctl scan le`,
# `bluetoothctl advertise on`, `bluetoothctl connect`, `sdptool browse`, `rfcomm connect`, `btgatt-client`, `l2test`, `rctest`, `btmgmt`,
# `gatttool` and `hciconfig` with any argument (or none) are all red wherever they stand. The D-Bus route to bluetoothd is denied by the name of the bus tools (dbus-send, busctl, gdbus) and of the service (org.bluez): `dbus-send --dest=org.bluez`
# starts a discovery as well as `hcitool` does. The only exceptions are the two literal lines of
# bt_begin and read-only reads of /sys/class/bluetooth, which holds no word of this family. TX_WORDS above stays as defence in depth.
# The words are read after the quotes and backslashes of a line are deleted (and adjacent string literals joined): `hc'"''"'itool`, `hc\itool`, `"hci""tool"` and an awk
# `"hci" "tool"` are `hcitool`. A name that is only BUILT when the line runs (a glob, a substitution, a variable) is not a word of any line: inside BT_FUNCS
# (the test code included) a command word that is a glob, a `$` expansion or a backtick expansion is red (row 'Bluetooth wrappers'); in every shell file of the scope the rows 6d
# (a command word that holds an expansion) and 6e (a glob in a command word, `find -exec`, an `xargs` whose command is a placeholder or missing, an alias) read the same forms. What no
# row reads: a glob that is only an argument (`ln -s /usr/bin/hc?tool x`, `cp`), a program text that is built and run (`eval`, `sh -c`, a pipe into `sh`, an awk `system()`), and
# a name that a function of the script makes; for those the guarantee is review, and the run-time witness covers only the collector's own Bluetooth window.
# Every name V-13 of docs/device-notes.md finds in the device's BlueZ directories is added here, one alternative each, and one sample in
# tools/passivity-mutate.sh (MIN_ALTS_BT there is raised with it).
BT_WORDS='hcitool|btmon|hciconfig|bluetoothctl|btmgmt|bluetoothd|gatttool|l2ping|l2test|rctest|sdptool|rfcomm|hcidump|btattach|bccmd|bdaddr|hciattach|hid2hci|btgatt-client|btgatt-server|obexd|rfkill|init\.d/bluetooth|/sys/kernel/debug/bluetooth|dbus-send|busctl|gdbus|org\.bluez|ciptool|avinfo|isotest|meshctl|mesh-cfgclient|bluetooth-meshd|btproxy|bluemoon|mpris-proxy|hex2hcd|obexctl|bluetooth-player|btinfo|scotest|hcieventmask'
# Command wrappers: inside a function of BT_FUNCS no simple command may begin with one of these (the command word is read after any
# keyword, separator or `VAR=value`), because they let a tool name or an argument travel in a string or a variable. `command -v` stays
# allowed. Every alternative starts with `^`: the family is tested against one simple command at a time, and the anchor keeps `ash -c`
# apart from `sh -c`.
BT_WRAP_RE='^eval([[:space:]]|$)|^sh[[:space:]]+-c([[:space:]]|$)|^ash[[:space:]]+-c([[:space:]]|$)|^busybox([[:space:]]|$)|^env([[:space:]]|$)|^xargs([[:space:]]|$)|^nohup([[:space:]]|$)|^setsid([[:space:]]|$)|^nice([[:space:]]|$)|^start-stop-daemon([[:space:]]|$)|^exec([[:space:]]|$)|^source([[:space:]]|$)|^time([[:space:]]|$)|^\.[[:space:]]|^command[[:space:]]+([^-[:space:]]|-([^v]|v[^[:space:]]))'
BT_RE="(^|[^A-Za-z0-9_-])($BT_WORDS)([^A-Za-z0-9_-]|\$)"
# Used by the rows of tools/device-probe.sh only (row 7d): the tools that talk over a network, capture, install, configure, start or stop a service or switch the device off. The probe may name
# one of them only in a pinned line (a presence test by name, a usage text); the collector and the other scripts are not read for these words. A hyphen is part of a name (`airodump-ng`), not a boundary.
PNET_WORDS='curl|wget|nc|ncat|netcat|socat|ping6?|traceroute|ssh|scp|sftp|telnet|ftp|tftp|uci|opkg|ifconfig|ip|iptables|tcpdump|airodump-ng|dumpcap|tshark|service|reload_config|wifi|pkill|killall|reboot|poweroff|halt'
PNET_RE="(^|[^A-Za-z0-9_-])($PNET_WORDS)([^A-Za-z0-9_-]|\$)"
[ "${1:-}" != --regexes ] || {
  for _n in NETSURF_RE NETX SEC6_RE TX_WORDS IW_VERBS BT_WORDS BT_WRAP_RE PNET_WORDS; do
    case $_n in NETSURF_RE) _v=$NETSURF_RE;; NETX) _v=$NETX;; SEC6_RE) _v=$SEC6_RE;; TX_WORDS) _v=$TX_WORDS;; IW_VERBS) _v=$IW_VERBS;; BT_WORDS) _v=$BT_WORDS;; PNET_WORDS) _v=$PNET_WORDS;; *) _v=$BT_WRAP_RE;; esac
    printf '%s\t%s\n' "$_n" "$_v"
  done; exit 0; }
# The shell files of the scope are read WHOLE, one file at a time, by ONE reader (BTSEG below, mode dyn, with BT_VIEW: shview() runs it), and the lists the rows lean on come from that reading, from no
# scan of the raw text: the code lines "file:line:function:text" (a comment line and an empty line are none; every other line is code, the lines of a here-document body and of a string among them), the
# function of a line (the function whose head stood at the start of a line with nothing open, outside every function) and the function heads (fns). A line inside a here-document body, a string, a comment or after a backslash that looks like a function head, a comment or a closing brace is none of
# these, and a head that comes while a function is open is a definition nested in its body (or the function above it lost its closing brace at the start of a line): the fill row names it, and neither it nor the lines after it have a function. A function `f() { …; }` on one line does not open a scope, so hits there count as "outside" (conservative).
# FNDEF is the ONE definition of "a function head the scope check recognises" (shared by the reader and the fill probe below through ENVIRON, so the two cannot drift apart).
FNDEF='^[A-Za-z_][A-Za-z0-9_]*[ \t]*\([ \t]*\)[ \t]*\{?[ \t]*(#.*)?$'
export FNDEF
# rows 5 and 6 · simple commands, read one at a time (BTSEG): the line is masked (blanks and separators inside quotes are text), cut at ;
# & | ( ) and backticks, and at $( ; keywords (then do else if ...) and `VAR=value` prefixes are dropped; what is left starts with the
# command word. wrap = in every function of BT_FUNCS: no wrapper of BT_WRAP_RE, no command word that is a `$` expansion (`$VAR`, `$(...)`, a backtick
# expression, quoted or not), no glob in a command word, no `timeout` outside bt_begin. cmdpos = in bt_stub and bt_selftest: no tool word of the stack as the command word (also after `timeout [-s SIG] N`,
# quoted, or with a path in front). The body of a here-document is text and is skipped (its first line, the command, is read).
# dyn = row 6d, over every line of every shell file of the scope, functions and top level alike (BT_SEG_FNS is `*`): it does not use mask() and cmds() above but reads the raw
# text with a stack of its own (dyn() below) and lists each simple command whose command word holds an expansion; the row compares what it lists with a pinned list.
# shellcheck disable=SC2016   # awk program
BTSEG='BEGIN { WRAP = ENVIRON["BT_WRAP_RE"]; CMDW = ENVIRON["BT_CMD_RE"]; MODE = ENVIRON["BT_MODE"]; FNS = ENVIRON["BT_SEG_FNS"]; CMDS = ENVIRON["BT_CMDS"]; WRF = ENVIRON["BT_WRITES"]; PFN = " " ENVIRON["BT_PFN"] " "; VIEW = ENVIRON["BT_VIEW"]; VHEADS = ENVIRON["BT_HEADS"]; FDEFS = ENVIRON["BT_FDEFS"]; ADEFS = ENVIRON["BT_ADEFS"]; DEFRE = ENVIRON["FNDEF"]; VNEST = ENVIRON["BT_NESTED"]; vfn = "-" }
function mask(t,   i, n, c, q, sd, bq, out) {
  n = length(t); q = ""; sd = 0; bq = 0; out = ""
  for (i = 1; i <= n; i++) {
    c = substr(t, i, 1)
    if (q == "\047") { if (c == "\047") { q = ""; out = out c } else out = out "_"; continue }
    if (q == "\"") {
      if (sd == 0 && bq == 0) {
        if (c == "\\") { out = out "_"; if (i < n) { i++; out = out "_" } continue }
        if (c == "\"") { q = ""; out = out c; continue }
        if (c == "$" && substr(t, i + 1, 1) == "(") { sd = 1; out = out "$("; i++; continue }
        if (c == "`") { bq = 1; out = out c; continue }
        out = out ((c ~ /[ \t;&|(){}]/) ? "_" : c); continue
      }
      if (bq) { if (c == "`") bq = 0; out = out c; continue }
      if (c == "(") sd++; else if (c == ")") sd--
      out = out c; continue
    }
    if (c == "\\") {   # outside quotes: \i is i (hc\itool is hcitool); an escaped blank or separator is masked
      if (i < n && substr(t, i + 1, 1) ~ /[A-Za-z0-9]/) { out = out c substr(t, i + 1, 1); i++; continue }
      out = out "_"; if (i < n) { i++; out = out "_" } continue }
    if (c == "#" && (i == 1 || substr(t, i - 1, 1) ~ /[ \t;&|(]/)) break
    if (c == "\047" || c == "\"") q = c
    out = out c
  }
  return out
}
function add(s) {
  sub(/^[ \t]+/, "", s)
  while (s ~ /^(then|do|else|elif|if|while|until|!|\{|\})([ \t]|$)/) sub(/^[^ \t]+[ \t]*/, "", s)
  while (s ~ /^[A-Za-z_][A-Za-z0-9_]*=[^ \t]*([ \t]|$)/) sub(/^[^ \t]+[ \t]*/, "", s)
  if (s != "") C[++nc] = s
}
# an expansion ($( or a backtick) after nothing but keywords and complete assignments is the COMMAND WORD of its line: CWX = 1. `NAME=$(...)` and `NAME="$(...)"`
# are assignments, an expansion after a word is an argument.
function cwx(s) {
  if (AFTER) return   # `$(a)$(b)`: the second is part of a word that began before it
  sub(/^[ \t]+/, "", s)
  while (s ~ /^(then|do|else|elif|if|while|until|!|\{|\})([ \t]|$)/) sub(/^[^ \t]+[ \t]*/, "", s)
  while (s ~ /^[A-Za-z_][A-Za-z0-9_]*=[^ \t]*[ \t]/) sub(/^[^ \t]+[ \t]*/, "", s)
  gsub(/["\047]/, "", s)
  if (s == "") CWX = 1
}
function cmds(m,   i, n, c, cur, pd, bq, lastsep) {
  n = length(m); cur = ""; pd = 0; bq = 0; lastsep = 0; nc = 0; AFTER = 0; split("", C); split("", AS)
  for (i = 1; i <= n; i++) {
    c = substr(m, i, 1)
    if (c == "$" && substr(m, i + 1, 2) == "((") { cur = cur "___"; i += 2; continue }
    if (c == "$" && substr(m, i + 1, 1) == "(") { cwx(cur); add(cur); cur = ""; AS[pd++] = AFTER; AFTER = 0; i++; continue }
    if (c == "(") { add(cur); cur = ""; AS[pd++] = AFTER; AFTER = 0; continue }
    if (c == ")") { if (pd > 0) { add(cur); pd--; AFTER = 1 } else nc = lastsep; cur = ""; continue }   # a `)` that closes nothing ends a case pattern: its words are no commands
    if (c == "`") { if (!bq) { cwx(cur); bq = 1; add(cur); cur = ""; AFTER = 0 } else { bq = 0; add(cur); cur = ""; AFTER = 1 } continue }
    if (c == ";" || c == "&") { add(cur); cur = ""; lastsep = nc; AFTER = 0; continue }
    if (c == "|") { add(cur); cur = ""; AFTER = 0; continue }
    if (AFTER) { if (c ~ /[ \t]/) { AFTER = 0; cur = c } continue }   # what is glued to a closed substitution is part of its word, not a command
    cur = cur c
  }
  add(cur)
  return nc
}
# MODE dyn (rows 6d and 6e, two verdicts of one pass; dbad is the first, dbad2 the second): a simple command whose COMMAND WORD holds an expansion (`$VAR`, `${...}`, `$( )`, a backtick expression, quoted or not, also behind
# a wrapper word such as `exec`, `env`, `nice` or `timeout N`): the name of the command is then not in the text. The code is read as the shell would,
# one token at a time, over the raw text of the lines (quotes nest inside `$( )`, a quote or a `$( )` may go on over several lines, a trailing backslash
# joins two lines); DST is the stack of what is open: `$( )` (S), a backtick expression (K), `( )` (P), `$(( ))` (E, A, a), `${ }` (B), a single-quoted (q) or double-quoted (d)
# string. The state starts afresh with every file and every function. dbad = 1 when a command word of the line holds an expansion; dbad2 = 1 when one holds an unquoted glob character (`[` and `[[`
# apart), when a `find` has `-exec`, `-execdir`, `-ok` or `-okdir`, when an `xargs` has no command or its command is its replacement string, or when an `alias` is defined (row 6e).
function dtrap(w,   v) {   # the probe pass: the first argument of `trap`, the action, is a string that the shell runs as a command when the signal comes, and this reader does not read a string. So only an action that runs nothing of its own is accepted: `-`, an empty string, the name of a function of the probe (its body is read like the rest of the code) and `exit N` with N a number, bare or in one pair of quotes; any other action, one with an expansion among them, is an unlisted command
  v = "?"
  if (w ~ /^[A-Za-z0-9_-]+$/) v = w
  else if (w ~ /^\047[^\047]*\047$/ || w ~ /^"[^"]*"$/) v = substr(w, 2, length(w) - 2)
  if (v == "-" || v == "" || v ~ /^exit [0-9]+$/ || (v ~ /^[A-Za-z_][A-Za-z0-9_]*$/ && index(PFN, " " v " ") > 0)) return
  REC[++nrec] = "trap-action"
}
function darg(   a) {   # a word that is an argument of the simple command being read (dcmd = its name): `find ... -exec` and its three kin, `alias NAME=...`
  if (dcmd == "") return
  a = dtok; gsub(/["\047\\]/, "", a)
  if (dcmd == "find" && a ~ /^-(exec|execdir|ok|okdir)$/) dbad2 = 1
  else if (dcmd == "alias" && index(a, "=") > 0) dbad2 = 1
  if (CMDS != "" && ++dtn == 1) { if (dcmd == "trap") dtrap(dtok); else if (dcmd == "vset" && dtok !~ /^[0-9]+$/) REC[++nrec] = "vset-argument" }   # the first argument of trap (above) and of vset (the number in the name of the file it writes: a pinned write below, so a call must hand it digits)
  if (WRF == "") return
  # the probe pass only (WRF): the files that cp, mv and tee write, as "kind<TAB>command number<TAB>word": every word of tee, and of cp and mv the last one (the row reads the last one). `-t DIR` names the destination before the
  # sources, so it is recorded as the word -t, which no rule accepts. The variable of a `for` and every name after `read` are assignments of a value nobody reads: recorded as such.
  if (dcmd == "cp" || dcmd == "mv" || dcmd == "tee") {
    if (a ~ /^--target/ || a ~ /^-[A-Za-z]*t/) WREC[++nwr] = dcmd "\t" dwid "\t-t"
    else if (a !~ /^-/) WREC[++nwr] = dcmd "\t" dwid "\t" dtok
  } else if (dcmd == "for" && dforv) { dforv = 0; WREC[++nwr] = "=\t0\t" a "=$for" }
  else if (dcmd == "read" && a !~ /^-/) WREC[++nwr] = "=\t0\t" a "=$read"
}
function dxarg(a) {   # a word after `xargs`: 1 = one of its options or the argument of one, 0 = the first word that is neither, its command. dxr = the replacement string (-I, -J, -i, --replace)
  if (dxo != "") { if (dxo == "I") dxr = a; dxo = ""; return 1 }
  if (dxe || a !~ /^-/) return 0
  if (a == "--") { dxe = 1; return 1 }
  if (a ~ /^-[IJ]$/) { dxo = "I"; return 1 }
  if (a ~ /^-[IJ]./) { dxr = substr(a, 3); return 1 }
  if (a == "-i" || a == "--replace") { dxr = "{}"; return 1 }
  if (a ~ /^-i./) { dxr = substr(a, 3); return 1 }
  if (a ~ /^--replace=/) { dxr = substr(a, 11); return 1 }
  if (a ~ /^-[LnsPdEaRS]$/ || a ~ /^--(max-args|max-lines|max-chars|max-procs|delimiter|eof|arg-file|process-slot-var)$/) { dxo = "x"; return 1 }
  return 1
}
# CMDS (BT_CMDS, empty for every row above 7d): when set, mode dyn also records the NAME of each simple command, as the command word stands (a path stays a path), for the probe rows. Names that hold an
# expansion or a glob are left to rows 6d and 6e. A case pattern (`a|b) ...`) is read like a command word until the `)` shows what it was: the names recorded since the case item began are then dropped, and
# only then. A case item begins after `case WORD in`, after `;;` or `;&`, and at the start of a line inside an open case (ccase and cdepth follow `case` and `esac` as command words; cpat says that the segment
# being read began an item); a `)` that closes nothing anywhere else (`mv a b | case x in x) ...` is the line this was shut for) drops nothing. All of it is kept for every level of the stack, not for the top level alone
# (ccase, cdepth, cpat and rmark are arrays indexed by dsp, initialised by dpush): `case WORD in` inside `( )`, `$( )` or backticks marks that level, a `)` at a level with an open pattern ends the pattern and does not
# pop the level (it used to pop it, and the `)` after the `esac` then dropped every name of a body line), `esac` ends the pattern, and what the line had flagged (a built command word) before the item began stays flagged
# (pdb, pdb2). The other passes follow the top level only, and read the `)` as they did. A word after `command` (not `-v`, `-V`) is recorded with a `!` in front:
# `command` skips the shell functions, so it names a program of the PATH even when the file defines a function of that name.
# Three more things are recorded as names that no list holds, so that the row programs reports them as unlisted commands: the action of a `trap` that is not `-`, an empty string, the name of a function of the probe (BT_PFN)
# or `exit N` (dtrap: the action is a string that the shell runs and this reader does not read), a call of `vset` whose first argument is not digits (it stands in the name of a file that the pinned write of vset makes), and a
# here-document whose delimiter word is not a plain name, bare or wholly in quotes (dhdword: the shell removes the quotes of the whole word, `<<wait"x"` ends at `waitx`) or whose body holds a `$(` or a backtick while its
# delimiter is bare (the body is then expanded when it runs).
# WRF (BT_WRITES, the probe pass only): mode dyn also records what the code writes, as "kind<TAB>command number<TAB>word<TAB>line": the word after every `>`, `>>` or `>|` (a descriptor copy such as `2>&1` or `>&2` names no file;
# `2>`, `9>` and a `>` glued to the word before it are the same redirection), the words cp, mv and tee write to (darg above), and every assignment `NAME=value` at command position with the variables of `for` and `read`.
# The checker judges them (row 7d, the row programs); this pass only reads. Like the names, nothing of it is read inside a single-quoted string (an awk or sed program): that rests on review.
# VIEW (BT_VIEW, with BT_HEADS, BT_FDEFS and BT_ADEFS; the pass over the probe and the pass over the shell scope, shview): the pass is handed every line of the file and makes the code lines with their function (VIEW), the function heads (VHEADS) and the
# functions the file defines (ddef: FDEFS for those a call or a trap may name, ADEFS for all of them) from what it reads, so that a line inside a here-document body, a string or a comment is none of them (the rule `VIEW != ""` below). A head
# begins a function only outside every function (vfn is "-"), in the pass over the shell scope; there one that comes while a function is open is a definition nested in its body and gives the lines after it no function of its own.
# Here-documents: the delimiter of every `<<` on a line is read (dyn), the body ends at the last of them, and the line is bare when ANY of its delimiters is not wholly in quotes (DHDB; the last delimiter alone used to decide, so `cat <<a <<"b"`
# was a quoted document and a `$(` in the bare body of the first was skipped). The probe pass lists a `$(` or a backtick in such a body (REC "here-document"); the pass over the shell scope (CMDS empty) reads the body as text in which
# `$( )` and backtick expressions are code (hbody: the state H on the stack is the text, a quote does not end it) and takes the verdicts of rows 6d and 6e from them like from any other line.
function rec(nm) { if (CMDS != "" && !dtexp && !dtglob) REC[++nrec] = nm }
function dcase(isc, w) {   # a token that has just ended at the level dsp (the other passes follow the top level only, 0): `case` as a command word opens the pattern, the next two words are its subject and `in`; `esac` closes it and ends its pattern
  if (dsp != 0 && CMDS == "") return
  if (isc) { ccase[dsp] = (w == "case"); if (w == "esac" && cdepth[dsp] > 0) { cdepth[dsp]--; cpat[dsp] = 0 }; return }
  if (ccase[dsp] == 1) { ccase[dsp] = 2; return }
  if (ccase[dsp] == 2) { ccase[dsp] = 0; if (w == "in") { cdepth[dsp]++; cpat[dsp] = 1; rmark[dsp] = nrec; pdb[dsp] = dbad; pdb2[dsp] = dbad2 } }   # `case WORD in`: the first item begins here (what the line had flagged before it stays flagged)
}
function dxend() { if (dwr && dwc == "xargs") { dbad2 = 1; dwr = 0 } }   # `xargs` with no command of its own: it runs echo over what it reads (with -I its command would come from stdin)
function dfin(   dn, ac) {   # the token that has just ended
  if (!dint) return
  dint = 0
  if (wrd) { if (wrd == 1) WREC[++nwr] = ">\t0\t" dtok; wrd = 0; return }   # the word after a `>` (WRF, the probe pass only): where the redirection writes; after a `<` it names a file that is read
  if (drd) { drd = 0; return }
  if (!dtcs) { darg(); dcase(0, dtok); return }
  dn = dtok; gsub(/["\047\\]/, "", dn)   # quotes and backslashes in a name do not hide it (a quoted find, a split exec, a backslash before xargs)
  if (dwr) {
    if (dsk) { dsk = 0; return }
    if (dwc == "xargs" && dxarg(dn)) return
    if (dtok ~ /^-[vV]$/ && dwc == "command") { dcs = 0; dwr = 0; return }
    if (dtok ~ /^-[nsk]$/) { dsk = 1; return }
    if (dtok ~ /^-/) return
    if (dwc == "timeout" && !dwd) { dwd = 1; return }
    if (dwc == "xargs" && (index(dn, "{}") > 0 || (dxr != "" && index(dn, dxr) > 0))) dbad2 = 1   # the command is the replacement string: it comes from stdin
    ac = (dwc == "command"); dwr = 0   # the word after `command` is a program of the PATH, never a function of the file (recorded as !NAME)
  }
  if (dtok ~ /^(then|do|else|elif|if|while|until|!|\{|\})$/) return
  if (dn ~ /^(exec|command|nohup|setsid|nice|env|time|xargs|busybox|timeout|sudo|stdbuf)$/) { rec((ac ? "!" : "") dn); dwr = 1; dwc = dn; dwd = 0; dsk = 0; if (dn == "xargs") { dxo = ""; dxr = ""; dxe = 0 }; return }
  if (dtok ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { if (WRF != "") WREC[++nwr] = "=\t0\t" dtok; return }
  if (dtok ~ /^[0-9]*[<>]/) { if (dtok ~ /^[0-9]*(>>|>[|]|>&|<&|<|>)$/) drd = 1; return }
  if (dtexp) dbad = 1
  if (dtglob && dtok !~ /^\[\[?$/) dbad2 = 1   # a glob in the command word: the name is whatever the directory holds when the line runs (`[` and `[[` are the test)
  rec((ac ? "!" : "") dn); sub(/^.*\//, "", dn); dcmd = dn; dcase(1, dn)
  if (dn == "cp" || dn == "mv" || dn == "tee") dwid = ++dwn   # the number tells the words of one command from those of another (darg)
  dforv = (dn == "for"); dtn = 0
  dcs = 0; dwr = 0
}
function dpush(ty) { DST[++dsp] = ty; DSI[dsp] = dint; DSC[dsp] = dtcs; DSK[dsp] = dtok; DSE[dsp] = dtexp; DSS[dsp] = dcs; DSG[dsp] = dtglob; DSM[dsp] = dcmd; DSR[dsp] = wrd; DSW[dsp] = dwid; DSN[dsp] = dtn; dcmd = ""; wrd = 0; dwid = 0; ccase[dsp] = 0; cdepth[dsp] = 0; cpat[dsp] = 0; rmark[dsp] = nrec; pdb[dsp] = dbad; pdb2[dsp] = dbad2 }
function dpop() { dint = DSI[dsp]; dtcs = DSC[dsp]; dtok = DSK[dsp]; dtexp = DSE[dsp]; dcs = DSS[dsp]; dtglob = DSG[dsp]; dcmd = DSM[dsp]; wrd = DSR[dsp]; dwid = DSW[dsp]; dtn = DSN[dsp]; dsp-- }
function dtext(c) { if (!dint) { dint = 1; dtcs = dcs; dtok = ""; dtexp = 0; dtglob = 0 } dtok = dtok c }
function dreset() { hbo = 0; dcs = 1; dint = 0; dtcs = 0; dtok = ""; dtexp = 0; dtglob = 0; drd = 0; dwr = 0; dsk = 0; dwd = 0; dsp = 0; dcmd = ""; dxo = ""; dxr = ""; dxe = 0; wrd = 0; dwid = 0; dforv = 0; dtn = 0; split("", ccase); split("", cdepth); split("", cpat); split("", rmark); split("", pdb); split("", pdb2) }
function hbody(t) {   # the main pass (CMDS empty): a line of the body of a here-document with a bare delimiter is read as text in which `$( )` and backtick expressions are code, as the shell expands it when the document is read: the state H below the stack is the text (a quote does not end it), what a `$( )` holds is read like any command line, and a built command word or a glob in it is a verdict of the line like on any other line. The lines are not counted among the code lines read
  if (!hbo) { dpush("H"); hbi = dsp; hbo = 1; dint = 0; dcs = 0 }
  dyn(t)
  if (dbad) print $0 > BAD
  if (dbad2) print $0 > BAD2
}
function hend() { if (!hbo) return; hbo = 0; dsp = hbi; dpop(); DCONT = 0 }   # the delimiter line (or a function boundary) ends the body: back to the state the head line left
function dhdword(u,   i, n, c, q, w) {   # the delimiter word of a here-document as the shell reads it: from u (the text after << and an optional -, blanks cut) up to the first unquoted blank or metacharacter, quotes and backslashes as they stand; "?" when a quote stays open on the line
  n = length(u); q = ""; w = ""
  for (i = 1; i <= n; i++) {
    c = substr(u, i, 1)
    if (q == "\047") { w = w c; if (c == "\047") q = ""; continue }
    if (q == "\"") { w = w c; if (c == "\\" && i < n) { i++; w = w substr(u, i, 1) } else if (c == "\"") q = ""; continue }
    if (c == "\\") { w = w c; if (i < n) { i++; w = w substr(u, i, 1) }; continue }
    if (c == "\047" || c == "\"") { q = c; w = w c; continue }
    if (c ~ /[ \t;&|<>()]/) break
    w = w c
  }
  return (q == "" ? w : "?")
}
function ddef(col, cont,   nm) {   # the probe pass (VIEW): `name()` met by the reader, the name being the token that has just been read. Every one is a definition of the file (ADEFS: the shadow test reads them all). Only one that begins a line (column 1), with nothing open and no line before it going on, is a function whose name a call and the action of a `trap` may use (FDEFS): the old form of the list, which a line of a here-document body, a string or a comment could not make
  nm = dtok
  if (nm !~ /^[A-Za-z_][A-Za-z0-9_]*$/) return
  print nm > ADEFS
  if (dsp == 0 && !cont && col == length(nm) + 1) print nm > FDEFS
}
function dyn(t,   i, n, c, top, bsep, bsep2, u, nx, cl, l, wd) {
  cl = DCONT   # the line before ended in a backslash: this one goes on with the same segment
  n = length(t); dbad = 0; dbad2 = 0; bsep = 0; bsep2 = 0; DCONT = 0; DHDW = ""; DHDQ = 0; DHDB = 0; nrec = 0; nwr = 0
  for (l = 0; l <= dsp; l++) { rmark[l] = 0; pdb[l] = 0; pdb2[l] = 0 }
  if (!cl) { for (l = 0; l < dsp; l++) cpat[l] = 0; cpat[dsp] = (cdepth[dsp] > 0 && (dsp == 0 || DST[dsp] ~ /^[SKP]$/)) ? 1 : 0 }   # a line that begins inside an open case (of the level it begins in) begins a case item (or goes on with a body, where a `)` that closes nothing cannot stand)
  for (i = 1; i <= n; i++) {
    c = substr(t, i, 1); nx = substr(t, i + 1, 1); top = (dsp > 0) ? DST[dsp] : ""
    if (top == "q") { dtext(c); if (c == "\047") dsp--; continue }
    if (top != "A" && top != "a") {
      if (c == "\\") { if (i < n) { dtext(c); i++; dtext(substr(t, i, 1)) } else DCONT = 1; continue }
      if (top == "d" && c == "\"") { dtext(c); dsp--; continue }
    }
    if (c == "$" && substr(t, i + 1, 2) == "((") { dtext("$"); dpush("E"); DST[++dsp] = "A"; DST[++dsp] = "A"; i += 2; continue }
    if (c == "$" && nx == "(") { dtext("$"); dtexp = 1; dpush("S"); dint = 0; dcs = 1; i++; continue }
    if (c == "`") {
      if (top == "K") { dfin(); dpop(); dtext("`"); continue }
      dtext("`"); dtexp = 1; dpush("K"); dint = 0; dcs = 1; continue }
    if (top == "A" || top == "a") {   # arithmetic: its blanks, parentheses and operators are not shell syntax
      if (c == "(") DST[++dsp] = "a"
      else if (c == ")") { dsp--; if (dsp > 0 && DST[dsp] == "E") { dpop(); dtext("_") } }
      continue }
    if (c == "$") { dtext(c); if (nx ~ /[A-Za-z0-9_{@*#?!$-]/) dtexp = 1; if (nx == "{") { dtext("{"); i++; DST[++dsp] = "B" }; continue }
    if (top == "B") {   # inside ${ }: blanks, parentheses, separators and glob characters are text; quotes and `$( )` nest
      if (c == "}") { dtext(c); dsp--; continue }
      if (c == "\047") { dtext(c); DST[++dsp] = "q"; continue }
      if (c == "\"") { dtext(c); DST[++dsp] = "d"; continue }
      dtext(c); continue }
    if (top == "d" || top == "H") { dtext(c); continue }
    if (c == "\047") { dtext(c); DST[++dsp] = "q"; continue }
    if (c == "\"") { dtext(c); DST[++dsp] = "d"; continue }
    if (c == "#" && !dint) break
    if (c == " " || c == "\t") { dfin(); continue }
    if (c == ";" || c == "|" || (c == "&" && substr(t, i - 1, 1) !~ /[<>]/)) { dfin(); dxend(); drd = 0; dwr = 0; wrd = 0; dcs = 1; if (c != "|") { bsep = dbad; bsep2 = dbad2; rmark[dsp] = nrec; pdb[dsp] = dbad; pdb2[dsp] = dbad2; if (dsp == 0 || CMDS != "") cpat[dsp] = (i > 1 && substr(t, i - 1, 1) == ";") }; continue }   # `;;` and `;&` end a case item and begin the next
    if (c == "<" && nx == "<" && substr(t, i + 2, 1) == "<") { dtext("<<<"); i += 2; continue }
    if (c == "<" && nx == "<") {   # a here-document: its delimiter word, for the caller
      u = substr(t, i + 2); DHDD = (substr(u, 1, 1) == "-"); if (DHDD) u = substr(u, 2)
      sub(/^[ \t]+/, "", u)
      wd = dhdword(u); DHDQ = (wd ~ /^(\047[A-Za-z_][A-Za-z0-9_]*\047|"[A-Za-z_][A-Za-z0-9_]*")$/); if (!DHDQ) DHDB = 1; if (CMDS != "") { if (!DHDQ && wd !~ /^[A-Za-z_][A-Za-z0-9_]*$/) REC[++nrec] = "here-document" }   # the probe pass: any delimiter that is not a plain name, bare or wholly in quotes is a word this reader would read differently from the shell (`<<wait"x"` ends at `waitx`, not at `wait`): it is an unlisted command
      sub(/^["\047]/, "", u); sub(/[^A-Za-z0-9_].*$/, "", u)
      if (u ~ /^[A-Za-z_]/) DHDW = u
      dtext("<<"); i++; continue }
    if (c == "(") { fdef = (nx == ")" && dint && dtcs); if (fdef && VIEW != "") ddef(i, cl); n0 = nrec; dfin(); if (fdef && nrec == n0 + 1) nrec--; dpush("P"); dint = 0; dcs = 1; continue }   # `name()` defines a function: the name is not a command
    if (c == ")") {
      dfin(); dxend()
      if (dsp == 0) { if (cpat[0]) nrec = rmark[0]; if (CMDS != "" && cpat[0]) { dbad = pdb[0]; dbad2 = pdb2[0] } else { dbad = bsep; dbad2 = bsep2 }; cpat[0] = 0; dcs = 1; continue }   # a `)` that closes nothing ends a case pattern: its words are no commands (the names recorded since the item began go; if no item began, nothing goes)
      if (CMDS != "" && cpat[dsp]) { nrec = rmark[dsp]; dbad = pdb[dsp]; dbad2 = pdb2[dsp]; cpat[dsp] = 0; wrd = 0; dcs = 1; continue }   # the probe pass: the same inside `( )`, `$( )` or backticks, where the `)` of a case pattern ends the pattern and closes nothing (the flags the line had before the item began stay)
      if (top == "S") { dpop(); dtext(")"); continue }
      dsp--; wrd = 0; dcs = 1; continue }
    if (c == ">" && WRF != "") {   # an output redirection (the probe pass only): the next word is where it writes. The digits before it are the descriptor, no word of the command; a word glued before it ends at the `>`
      if (dint && dtok ~ /^[0-9]+$/) dint = 0; else dfin()
      if (nx == ">" || nx == "|") i++
      else if (nx == "&" && substr(t, i + 2, 1) ~ /[0-9-]/) { i += 2; while (substr(t, i + 1, 1) ~ /[0-9-]/) i++; continue }   # `>&2`, `2>&1`, `>&-`: a descriptor, no file
      wrd = 1; continue }
    if (c == "<" && WRF != "") {   # an input redirection (the probe pass only), read like `>` so that no redirection is ever taken for an argument of a wrapper (`timeout 5 cmd`): its word names no command. `<>` opens for writing as well
      if (dint && dtok ~ /^[0-9]+$/) dint = 0; else dfin()
      if (nx == ">") { i++; wrd = 1; continue }
      if (nx == "&" && substr(t, i + 2, 1) ~ /[0-9-]/) { i += 2; while (substr(t, i + 1, 1) ~ /[0-9-]/) i++; continue }
      wrd = 2; continue }
    dtext(c); if (index("*?[", c) > 0) dtglob = 1
  }
  top = (dsp > 0) ? DST[dsp] : ""
  if (top != "q" && top != "d" && top != "H") { dfin(); if (!DCONT && top != "A" && top != "a") { dxend(); dcs = 1; drd = 0; dwr = 0; wrd = 0 } }   # a newline ends a simple command, unless it is escaped or inside a quote
  return dbad
}
VIEW != "" {   # the probe pass (BT_VIEW, mode dyn): the input is every line of the file, "file:line:-:text", comment lines, empty lines and here-document bodies included, and one reader state runs through all of it. This prelude gives each line its function and passes it on to the rule below as "file:line:function:text". A line begins "clean" when nothing is open (no here-document body, no string, no substitution), and the line before did not end in a backslash; only a clean line can be a comment line (it begins with `#`), a function head (FNDEF) or the closing `}` of a function. Anywhere else (in a string that runs over several lines, in a here-document body, after a backslash) a line that looks like a comment, a head or a `}` is text or code like the others. The code lines (not an empty line, not a comment line) go to VIEW, the heads of clean lines to VHEADS
  if (vclose) { vfn = "-"; vclose = 0 }
  fl = $0; sub(/:.*/, "", fl); ln = $0; sub(/^[^:]*:/, "", ln); sub(/:.*/, "", ln)
  t = $0; for (k = 0; k < 3; k++) t = substr(t, index(t, ":") + 1)
  vclean = (hd == "" && dsp == 0 && !DCONT)
  vcom = (vclean && t ~ /^[ \t]*#/)
  if (vclean && t ~ DEFRE) { nm = t; sub(/[ \t]*\(.*/, "", nm); if (vfn == "-" || VNEST == "") { vfn = nm; print vfn > VHEADS } else { print nm > VNEST; vfn = "-" } }   # the pass over the shell scope (VNEST, BT_NESTED, is set): a head begins a function only outside every function; one at the start of a line inside a function, whose closing brace has not come yet, is a definition nested in its body (or the function above it lost its closing brace at the start of a line): it is reported and neither it nor the lines after it have a function, so no allowlist reaches them. The pass over the probe (VNEST empty) lets every head begin a function, as it always did
  if (vclean && t ~ /^}/) vclose = 1
  $0 = fl ":" ln ":" vfn ":" t
  if (t != "" && !vcom) print $0 > VIEW
  if (vcom || (vclean && t == "")) next }
{ fn = $0; sub(/^[^:]*:[^:]*:/, "", fn); sub(/:.*/, "", fn)
  if (FNS != "*" && index(FNS, " " fn " ") == 0) next
  t = $0; for (k = 0; k < 3; k++) t = substr(t, index(t, ":") + 1)
  if (MODE == "dyn") { fl = $0; sub(/:.*/, "", fl); if (fl != curfile || fn != dfn) { curfile = fl; dfn = fn; dreset() } }   # a new file or function starts with nothing open
  if (fn != hdfn) { hd = ""; hend() }
  if (hd != "") { u = t; if (hddash) sub(/^\t+/, "", u); if (u == hd) { hd = ""; hend() } else if (CMDS != "" && !hdq && (index(t, "$(") > 0 || index(t, "`") > 0)) print "here-document\t" $0 > CMDS; else if (CMDS == "" && MODE == "dyn" && !hdq) hbody(t); next }   # the body of a here-document is text, not a command of the function; but the body of one whose delimiter is bare is expanded when it runs, and a `$(` or a backtick in it starts a command (the probe pass: an unlisted command)
  nread++
  if (MODE == "dyn") {
    if (dyn(t)) print $0 > BAD
    if (dbad2) print $0 > BAD2
    if (CMDS != "") for (j = 1; j <= nrec; j++) print REC[j] "\t" $0 > CMDS
    if (WRF != "") for (j = 1; j <= nwr; j++) print WREC[j] "\t" $0 > WRF
    if (DHDW != "") { hd = DHDW; hdfn = fn; hddash = DHDD; hdq = !DHDB }
    next
  }
  CWX = 0; m = mask(t); n = cmds(m); bad = 0
  if (MODE == "wrap" && CWX) bad = 1   # the command word is a $( ) or a backtick expansion: a name that is built when the line runs
  p = index(m, "<<")
  if (p > 0 && substr(m, p + 2, 1) != "<") {
    u = substr(t, p + 2); hddash = (substr(u, 1, 1) == "-"); if (hddash) u = substr(u, 2)
    sub(/^[ \t]+/, "", u); sub(/^["\047]/, "", u); sub(/[^A-Za-z0-9_].*$/, "", u)
    if (u ~ /^[A-Za-z_]/) { hd = u; hdfn = fn }   # a word, not a shift in arithmetic
  }
  for (j = 1; j <= n; j++) {
    s = C[j]; u = s; gsub(/["\047\\]/, "", u)   # quotes and backslashes in the command word do not hide it ("hci""tool", hc\itool are hcitool)
    if (MODE == "wrap") {
      cw = u; sub(/[ \t].*/, "", cw)
      if (cw !~ /^\[\[?$/ && cw ~ /[?*\[]/) bad = 1   # a glob in the command word (/usr/bin/hcito?l): a name that is built when the line runs
      else if (u ~ WRAP) bad = 1
      else if (s ~ /^["\047]?\$/) bad = 1
      else if (fn != "bt_begin" && u ~ /^timeout([ \t]|$)/) bad = 1
    } else {
      if (u ~ /^timeout[ \t]/) { sub(/^timeout[ \t]+/, "", u); sub(/^-s[ \t]+[^ \t]+[ \t]+/, "", u); sub(/^[^ \t]+[ \t]*/, "", u) }
      if (u ~ CMDW) bad = 1
    }
  }
  if (bad) print $0 > BAD }
END { print nread + 0 > NREAD }'
# shellcheck disable=SC2016   # awk program: $0 is awk's field, not a shell expansion
SCOPE='BEGIN { RE = ENVIRON["SCOPE_RE"]; NORM = ENVIRON["SCOPE_NORM"] }
{ l = $0; for (k = 0; k < 3; k++) l = substr(l, index(l, ":") + 1)
  if (NORM == "1") { gsub(/\\/, "", l); gsub(/"[ \t]+"/, "", l); gsub(/["\047]/, "", l) }   # the normal form: backslashes gone, string literals joined, quotes gone (hc\047\047itool, hc\itool, "hci" "tool" are hcitool)
  if (l ~ RE) print $0 }'
# shview: read every file of $tmp/shfiles whole (the file's lines handed over as "file:line:-:text"; one reader state from the first line to the last, none at a function head) and make
#   $tmp/code   the code lines of the scope, "file:line:function:text" (what scoped() reads);  $tmp/fns  "file:function" of every function head;  $tmp/nested  "file:function" of every head that came while a function was open (the fill probe names them);
#   $tmp/dyn_bad, $tmp/dyn_bad2, $tmp/dyn_n   the two verdicts of rows 6d and 6e (the lines that hold a built command word, a glob, find -exec, xargs or alias) and the number of code lines read: the same pass, so the
#   rows 6d and 6e read what the heads and the attribution of the other rows are made from.
shview() {
  : > "$tmp/code"; : > "$tmp/fns"; : > "$tmp/nested"; : > "$tmp/dyn_bad"; : > "$tmp/dyn_bad2"; _tot=0
  while IFS= read -r _f; do
    awk '{ print FILENAME ":" FNR ":-:" $0 }' "$_f" > "$tmp/vraw"
    : > "$tmp/v1"; : > "$tmp/h1"; : > "$tmp/e1"; : > "$tmp/b1"; : > "$tmp/b2"; : > "$tmp/n1"
    BT_WRAP_RE='' BT_CMD_RE='' BT_MODE=dyn BT_SEG_FNS='*' BT_VIEW="$tmp/v1" BT_HEADS="$tmp/h1" BT_NESTED="$tmp/e1" BT_FDEFS=/dev/null BT_ADEFS=/dev/null awk -v BAD="$tmp/b1" -v BAD2="$tmp/b2" -v NREAD="$tmp/n1" "$BTSEG" "$tmp/vraw"
    cat "$tmp/v1" >> "$tmp/code"; cat "$tmp/b1" >> "$tmp/dyn_bad"; cat "$tmp/b2" >> "$tmp/dyn_bad2"
    awk -v F="$_f" '{ print F ":" $0 }' "$tmp/h1" >> "$tmp/fns"; awk -v F="$_f" '{ print F ":" $0 }' "$tmp/e1" >> "$tmp/nested"
    _n=$(cat "$tmp/n1"); _tot=$((_tot + ${_n:-0}))
  done < "$tmp/shfiles"
  printf '%s\n' "$_tot" > "$tmp/dyn_n"
}
scoped() { # scoped ERE → "file:line:function:text" over the code lines of the scope (ERE via ENVIRON: no awk -v escape mangling)
  SCOPE_RE=$1 SCOPE_NORM=0 awk "$SCOPE" "$tmp/code"
}
scoped_n() { # the same, the hit read on the normal form of the line (the text printed is the line as it stands)
  SCOPE_RE=$1 SCOPE_NORM=1 awk "$SCOPE" "$tmp/code"
}
shview

# pin_cmp HITS PINS NEW GONE [WITHFILE]: a hit of a row is a line "file:line:function:text"; a pin is "function:text" (with WITHFILE=1 "file:function:text"), the text with its leading
# blanks cut and otherwise byte for byte. Each pin covers ONE hit, so a copy of a pinned line is a new line. NEW gets the hits no pin covers, GONE the pins no hit used (their
# text); the function prints how many hits were pinned. Rows 6d, 6e and the transmit row use it, so a change here is a change of all three.
# shellcheck disable=SC2016   # awk program
pin_cmp() {
  awk -v PINS="$2" -v NEW="$3" -v GONE="$4" -v WF="${5:-0}" '
    function norm(l,   f, i, t) { f = l; sub(/:.*/, "", f); sub(/^[^:]*:[^:]*:/, "", l); i = index(l, ":"); t = substr(l, i + 1); sub(/^[ \t]+/, "", t); return (WF == 1 ? f ":" : "") substr(l, 1, i) t }
    BEGIN { while ((getline ln < PINS) > 0) want[ln]++ }
    { k = norm($0); if (want[k] > 0) { want[k]--; np++ } else print $0 > NEW }
    END { for (k in want) for (j = 0; j < want[k]; j++) print k > GONE; print np + 0 }' "$1"
}

# The Bluetooth allowlist and the pinned lines of apcli_ro (rows 6b and 6c below). The collector's Bluetooth code defines the functions of
# BT_FUNCS and the fifth `_pineap` line; until the collector has them, the names are announced here (the SEC6_NOT_YET pattern: a listed name that is not
# defined is no failure while it is announced, and one that is defined and still announced is a hint). BT_NOT_YET holds the functions,
# APCLI_NOT_YET the ids of apcli_ro whose pinned line is not there yet. Whoever adds the collector's Bluetooth code empties both; `--pending` prints what
# is still announced, and tools/passivity-mutate.sh lets the mutations that need those lines wait while that list is not empty.
BT_FUNCS=' bt_begin bt_end bt_busy bt_sweep bt_stub bt_selftest '
BT_NOT_YET=' '   # announced, not defined yet (space-padded; empty: every listed name is defined)
APCLI_NOT_YET=' '                                       # announced, its line not in apcli_ro yet (space-padded; empty: all five lines are there)
# The five `_pineap` lines of apcli_ro, byte for byte (leading blanks cut): the per-command sign-off of every AP-service call. A sixth line, a
# changed argument, a command name from a variable: red. `recon_channels` is the opt-in Traffic read (gated on that switch alone).
# shellcheck disable=SC2016   # the pinned lines are literal shell text
printf '%s\n' \
  'present)       [ $# -eq 1 ] || return 2; command -v _pineap >/dev/null 2>&1 ;;' \
  'recon_aps)     [ $# -eq 1 ] || return 2; $ap_to _pineap RECON APS format=json ;;' \
  'recon_devices) [ $# -eq 1 ] || return 2; $ap_to _pineap RECON DEVICES format=json ;;' \
  'recon_devices_recent) [ $# -eq 1 ] || return 2; $ap_to _pineap RECON DEVICES format=json sort=time sortdir=desc limit=400 ;;' \
  'recon_channels) [ $# -eq 1 ] || return 2; [ "$TRAFFIC" = "1" ] || return 3; $ap_to _pineap RECON CHANNELS format=json ;;' > "$tmp/pins"
# shellcheck disable=SC2016   # awk program
apcli_scan() { # the lines of apcli_ro that hold `_pineap`: $tmp/ap_bad = the ones that are not a pin; $tmp/ap_cnt = "n", then "id<TAB>times" per pin
  : > "$tmp/ap_bad"
  scoped '_pineap' | awk -v PINS="$tmp/pins" -v BAD="$tmp/ap_bad" '
    BEGIN { while ((getline ln < PINS) > 0) { id = ln; sub(/\).*/, "", id); pin[ln] = id; cnt[ln] = 0 } }
    { fn = $0; sub(/^[^:]*:[^:]*:/, "", fn); sub(/:.*/, "", fn)
      if (fn != "apcli_ro") next
      t = $0; for (k = 0; k < 3; k++) t = substr(t, index(t, ":") + 1)
      sub(/^[ \t]+/, "", t); n++
      if (t in pin) cnt[t]++; else print $0 > BAD }
    END { print n + 0; for (p in pin) print pin[p] "\t" cnt[p] }' > "$tmp/ap_cnt"
}

# 0 · fill probe: every "outside the allowlist" / "stray" row below reads its hits through scoped(); a file list that
# lost a shell file, or a function head the awk no longer recognises, would turn those rows green by looking at
# less. So the scope is checked by NAME and by a floor, not just counted.
MIN_FNSCOPE=127  # functions recognised over the shell files: the heads the reader takes, $tmp/fns  (measured 291, of 294 lines that have the form of a head: the other three are the stop_nc, guard and short of the here-document that writes the handler of starchorus-serve.sh, text and no function of the file; the floor is 0.1.1's 95 plus the 32 collector functions of the radio pair)
cut -d: -f2 "$tmp/fns" | LC_ALL=C sort -u > "$tmp/fnames"
if [ "${1:-}" = --pending ]; then   # what is announced and not there yet (empty once the collector has the Bluetooth code)
  for f in $BT_FUNCS; do grep -qxF "$f" "$tmp/fnames" || case "$BT_NOT_YET" in *" $f "*) printf '%s\n' "$f" ;; esac; done
  apcli_scan
  for f in $APCLI_NOT_YET; do awk -F'\t' -v I="$f" '$1 == I && $2 == 0 { f = 1 } END { exit !f }' "$tmp/ap_cnt" && printf 'apcli_ro/%s\n' "$f"; done
  exit 0
fi
nfn=$(lines "$tmp/fns"); nsh=$(lines "$tmp/shfiles")
miss=""
for w in starchorus-collect.sh starchorus-display.sh starchorus-serve.sh "$DISPLAY_COPY" payload.sh library/user/reconnaissance/starchorus/payload.sh; do
  grep -qxF "$w" "$tmp/shfiles" || miss="$miss $w"
done
while IFS= read -r w; do [ -f "$w" ] || miss="$miss $w(no such file)"; done < "$tmp/shfiles"   # a listed file that is gone is read as empty
for w in build_from_iwscan run_cycle selftest; do grep -qxF "starchorus-collect.sh:$w" "$tmp/fns" || miss="$miss starchorus-collect.sh:$w()"; done
while IFS= read -r w; do miss="$miss $w(a head inside a function)"; done < "$tmp/nested"   # a definition nested in a body, or a function above it that lost its closing brace at the start of a line: neither it nor what follows has a function
fillok=0; [ "$nsh" -ge 4 ] && [ "$nfn" -ge "$MIN_FNSCOPE" ] && [ -z "$miss" ] && fillok=1
rowif "§14.6 scope fill: $nsh files, $nfn functions (≥ $MIN_FNSCOPE), unseen:${miss:- none}" [ "$fillok" = 1 ]

# 1-4 · browser page: the only network call is fetch("starchorus.json…") (§14.2 Passiv; operator-tools.sh repeats 1+2 for homing)
n=$(grep -cE "$NETSURF_RE" "$H")
rowif "HTML network surface = $n (want 0)" [ "$n" = 0 ]
[ "$n" = 0 ] || grep -nE "$NETSURF_RE" "$H" | show
# the target is exactly starchorus.json (a query string may follow, nothing else: "starchorus.json.bak" is another file)
nf=$(grep -o 'fetch(' "$H" | wc -l | tr -d ' '); nw=$(grep -oE 'fetch\("starchorus\.json[?"]' "$H" | wc -l | tr -d ' ')
rowif "fetch( = $nf, to starchorus.json = $nw (want 1/1)" [ "$nf/$nw" = 1/1 ]
# the one <link> allowed is the inline favicon: a data: URI on a line of its own, which the browser never fetches
NETX_ICON='^<link rel="icon" type="image/svg\+xml" href="data:image/svg\+xml,[^"]*">$'
nx=$(grep -E "$NETX" "$H" | grep -cvE "$NETX_ICON")
rowif "other network APIs in page = $nx (want 0; inline data: favicon exempt)" [ "$nx" = 0 ]
[ "$nx" = 0 ] || grep -nE "$NETX" "$H" | grep -vE "$NETX_ICON" | show
# external URLs only in the font-licence header (section 00 / before the first marker)
nu=$(awk '/==== [0-9]+ /{match($0,/==== [0-9]+/); s=substr($0,RSTART+5,RLENGTH-5)} /https?:\/\//{if (s+0 != 0) n++} END{print n+0}' "$H")
rowif "URLs outside the §00 licence header = $nu" [ "$nu" = 0 ]

# 5 · §14.6 static check: device CLI words only inside the allowlist functions
SEC6_FUNCS=' apcli_ro apcli_stub apcli_selftest '   # the allowlist + its stub factory + its selftest
scoped_n "$SEC6_RE" > "$tmp/s6"
: > "$tmp/s6bad"; while IFS= read -r ln; do
  fn=$(printf '%s\n' "$ln" | cut -d: -f3)
  case "$SEC6_FUNCS" in *" $fn "*) ;; *) printf '%s\n' "$ln" >> "$tmp/s6bad" ;; esac
done < "$tmp/s6"
rowif "§14.6 device calls outside allowlist = $(lines "$tmp/s6bad") (hits $(lines "$tmp/s6"))" [ ! -s "$tmp/s6bad" ]
[ -s "$tmp/s6bad" ] && show < "$tmp/s6bad"
# The allowlist is one-sided by itself (a name nobody defines allows nothing and hides a typo), so the other
# direction is checked too: every SEC6_FUNCS name is defined in a shell file or announced in SEC6_NOT_YET.
SEC6_NOT_YET=' '              # announced, not defined yet (space-padded; empty: every listed name is defined)
unex=""; stale=""; nlist=0
for f in $SEC6_FUNCS; do
  nlist=$((nlist + 1))
  if grep -qxF "$f" "$tmp/fnames"; then case "$SEC6_NOT_YET" in *" $f "*) stale="$stale $f";; esac
  else case "$SEC6_NOT_YET" in *" $f "*) ;; *) unex="$unex $f";; esac; fi
done
for f in $SEC6_NOT_YET; do case "$SEC6_FUNCS" in *" $f "*) ;; *) unex="$unex $f(only in NOT_YET)";; esac; done
rowif "§14.6 allowlist names: $nlist listed, undefined and not announced:${unex:- none}" [ -z "$unex" ]
for f in $stale; do echo "    hint: $f is defined and still in SEC6_NOT_YET: please remove"; done

# 6-7 · the one marked ACTIVE exception stays opt-in; no transmit tool is ever invoked
# shellcheck disable=SC2016   # literal shell text searched for in the collector
# the literal must stand in the code part of a code line (a comment, a here-document body that only looks like one and the tail of a line after a comment sign are not it); a `#` inside a string cuts early, which is red, never green
d=$(L='ALLOW_ACTIVE=${STARCHORUS_ALLOW_ACTIVE:-0}' awk 'BEGIN { L = ENVIRON["L"] }
  function codepart(t,   i, n) { n = length(t); for (i = 1; i <= n; i++) if (substr(t, i, 1) == "#" && (i == 1 || substr(t, i - 1, 1) ~ /[ \t;&|(]/)) return substr(t, 1, i - 1); return t }
  index($0, "starchorus-collect.sh:") == 1 { t = $0; for (k = 0; k < 3; k++) t = substr(t, index(t, ":") + 1); if (index(codepart(t), L) > 0) n++ } END { print n + 0 }' "$tmp/code")
# shellcheck disable=SC2016
# the guard is the line right after the head of build_from_iwscan (the head the reader met: the function of that name, at the start of a line, in the collector), read from the code lines, not from the raw text
g=$(GL='[ "$ALLOW_ACTIVE" = "1" ] || return 1' awk 'BEGIN { G = ENVIRON["GL"] }
  function codepart(t,   i, n) { n = length(t); for (i = 1; i <= n; i++) if (substr(t, i, 1) == "#" && (i == 1 || substr(t, i - 1, 1) ~ /[ \t;&|(]/)) return substr(t, 1, i - 1); return t }
  index($0, "starchorus-collect.sh:") != 1 { next }
  { ln = $0; sub(/^[^:]*:/, "", ln); sub(/:.*/, "", ln); fn = $0; sub(/^[^:]*:[^:]*:/, "", fn); sub(/:.*/, "", fn)
    t = $0; for (k = 0; k < 3; k++) t = substr(t, index(t, ":") + 1)
    if (hl) { if (ln + 0 == hl + 1 && index(codepart(t), G) > 0) ok = 1; exit }
    if (fn == "build_from_iwscan" && t ~ /^build_from_iwscan\(\)[ \t]*\{/) hl = ln + 0 }
  END { print ok + 0 }' "$tmp/code")
scoped_n '(^|[^A-Za-z_])iw([[:space:]]+dev[[:space:]]+[^[:space:]|;]+)?[[:space:]]+scan([^A-Za-z_]|$)' | grep -v ':build_from_iwscan:' > "$tmp/scan"
ns=$(lines "$tmp/scan")
rowif "iw scan opt-in only (default $d, guard $g, stray $ns)" [ "$d/$g/$ns" = 1/1/0 ]
[ "$ns" = 0 ] || show < "$tmp/scan"
# The three lines of the collector that must name a word of TX_WORDS stand in a pinned list, byte for byte (leading blanks cut) with their file and function; each pin covers one line, so a
# copy of one, an edited one and a pin without a line are red. Two are the last resort of create_monitor (the collector made a monitor interface with `airmon-ng start` before the radio
# pair: only when `iw phy ... interface add` failed, and only with STARCHORUS_CREATE_MON on, its default; it is a change of an interface, nothing is sent), the third is the path of the OUI
# file that comes with Nmap (a file that is read, a program that is not started).
cat > "$tmp/txpins" <<'TXPINS'
starchorus-collect.sh:create_monitor:if have airmon-ng; then
starchorus-collect.sh:create_monitor:out=$(airmon-ng start "$base" 2>/dev/null)
starchorus-collect.sh:find_oui_file:for c in /lib/hak5/oui.txt /usr/share/nmap/nmap-mac-prefixes /usr/share/macchanger/OUI.list; do
TXPINS
scoped_n "$TX_RE" > "$tmp/tx0"
: > "$tmp/tx"; : > "$tmp/tx_gone"
tx_p=$(pin_cmp "$tmp/tx0" "$tmp/txpins" "$tmp/tx" "$tmp/tx_gone" 1)
tx_ok=0; [ ! -s "$tmp/tx" ] && [ ! -s "$tmp/tx_gone" ] && tx_ok=1
rowif "transmit tools invoked = $(lines "$tmp/tx") (pinned $tx_p of $(lines "$tmp/txpins"), pins without a line $(lines "$tmp/tx_gone"))" [ "$tx_ok" = 1 ]
[ ! -s "$tmp/tx" ] || show < "$tmp/tx"
[ ! -s "$tmp/tx_gone" ] || { sed 's/^/    pin without a line: /' "$tmp/tx_gone" | cut -c1-200; echo "    hint: a pinned line changed or went: change the pinned list of the transmit row with it"; }

# 6b · the Bluetooth stack, denied BY TOOL (§14.6; BT_WORDS, BT_WRAP_RE and BT_FUNCS above). Six rows. The two literal lines of bt_begin
# are the only way a Bluetooth tool is ever started, and everything about the stack is read from these rows: a word of BT_WORDS (the name of
# any tool or path of BlueZ, whatever the verb or the option order) is red outside BT_FUNCS, whether it stands in code, in a string or in a
# log text; inside BT_FUNCS the forms are enumerated; no wrapper and no command word taken from a variable can start a tool; the test code
# holds no tool at command position.
# Rows read the code through scoped(): top-level text counts as outside every function, comment-only lines are skipped, a line is read as
# it stands (a quote that spans lines is read line by line, a `#` after a blank starts a comment). Sysfs reads (/sys/class/bluetooth) hold no
# word of the family and are not touched.
scoped_n "$BT_RE" > "$tmp/bt"      # every hit of a word of the stack (read on the normal form of the line): file:line:function:text
# $tmp/code (made by shview above): every code line with its function, for the rows that read whole lines
btfn_in() { case "$1" in *" $2 "*) return 0 ;; esac; return 1; }
# row 1 · a word of the stack outside the functions of the allowlist
: > "$tmp/btbad"; while IFS= read -r ln; do
  fn=$(printf '%s\n' "$ln" | cut -d: -f3)
  btfn_in "$BT_FUNCS" "$fn" || printf '%s\n' "$ln" >> "$tmp/btbad"
done < "$tmp/bt"
rowif "§14.6b Bluetooth words outside allowlist = $(lines "$tmp/btbad") (hits $(lines "$tmp/bt"))" [ ! -s "$tmp/btbad" ]
if [ -s "$tmp/btbad" ]; then
  show < "$tmp/btbad"
  echo "    hint: a tool word of the stack is a hit wherever it stands outside BT_FUNCS, in a log text too: name the tool by its role there ('the scan tool')"
fi
# row 2 · the allowlist is one-sided by itself, so every BT_FUNCS name is defined or announced in BT_NOT_YET, and every announced name is listed
unex=""; stale=""; nlist=0
for f in $BT_FUNCS; do
  nlist=$((nlist + 1))
  if grep -qxF "$f" "$tmp/fnames"; then btfn_in "$BT_NOT_YET" "$f" && stale="$stale $f"
  else btfn_in "$BT_NOT_YET" "$f" || unex="$unex $f"; fi
done
for f in $BT_NOT_YET; do btfn_in "$BT_FUNCS" "$f" || unex="$unex $f(only in NOT_YET)"; done
rowif "Bluetooth allowlist names: $nlist listed, undefined and not announced:${unex:- none}" [ -z "$unex" ]
for f in $stale; do echo "    hint: $f is defined and still in BT_NOT_YET: please remove"; done
# row 3 · bt_begin: every line that holds a tool word of the stack or `timeout` is, leading blanks cut, one of seven; the two pinned lines once each
# shellcheck disable=SC2016   # the allowed lines are literal shell text
printf '%s\n' \
  'timeout -s INT "$BT_MON_S" btmon -i hci0 > "$BT_F" 2>/dev/null &' \
  'timeout -s INT "$BT_WIN" hcitool -i hci0 lescan --passive --duplicates > /dev/null 2> "$BT_F.err" &' \
  'have hcitool || return 4' 'have btmon || return 4' 'have timeout || return 4' \
  'BT_MKID=$(bt_kid "$BT_MPID" btmon)' 'BT_SKID=$(bt_kid "$BT_SPID" hcitool)' > "$tmp/btbl"
scoped_n "$BT_RE|(^|[^A-Za-z0-9_-])timeout([^A-Za-z0-9_-]|\$)" > "$tmp/btb0"
: > "$tmp/btbbad"
awk -v LIST="$tmp/btbl" -v BAD="$tmp/btbbad" '
  BEGIN { while ((getline ln < LIST) > 0) { ok[ln] = 1; if (++np <= 2) { pinned[ln] = 1 } } }
  { fn = $0; sub(/^[^:]*:[^:]*:/, "", fn); sub(/:.*/, "", fn)
    if (fn != "bt_begin") next
    t = $0; for (k = 0; k < 3; k++) t = substr(t, index(t, ":") + 1)
    sub(/^[ \t]+/, "", t); n++
    if (!(t in ok)) { print $0 > BAD; next }
    if (t in pinned) seen[t]++ }
  END { for (p in pinned) printf "%d\n", seen[p] + 0; print n + 0 }' "$tmp/btb0" > "$tmp/btb_cnt"
btb_n=$(tail -n 1 "$tmp/btb_cnt"); btb_p=$(head -n 2 "$tmp/btb_cnt" | tr '\n' '/' | sed 's,/$,,')
if grep -qxF bt_begin "$tmp/fnames"; then
  btb_ok=0; [ ! -s "$tmp/btbbad" ] && [ "$btb_p" = 1/1 ] && btb_ok=1
  rowif "Bluetooth lines in bt_begin: $btb_n lines hold a tool word or timeout, others $(lines "$tmp/btbbad"), the two pinned lines $btb_p times each (want 1/1)" [ "$btb_ok" = 1 ]
elif btfn_in "$BT_NOT_YET" bt_begin; then rowif "Bluetooth lines in bt_begin: bt_begin is announced and not defined yet (BT_NOT_YET)" :
else rowif "Bluetooth lines in bt_begin: bt_begin is neither defined nor announced" false; fi
[ ! -s "$tmp/btbbad" ] || show < "$tmp/btbbad"
# row 4 · the other functions of the allowlist (not bt_begin, and not the test code): a tool word stands only as the LAST argument of
# `bt_is "$VAR" WORD` or `bt_kid "$VAR" WORD`, the identity checks that start nothing
BT_FORM_RE='bt_(is|kid)[ \t]+"\$[{]?[A-Za-z_][A-Za-z0-9_]*[}]?"[ \t]+('"$BT_WORDS"')[ \t]*($|[;&|)])'
BT_FORM_FNS=" "; for f in $BT_FUNCS; do case $f in bt_begin|bt_stub|bt_selftest) ;; *) BT_FORM_FNS="$BT_FORM_FNS$f " ;; esac; done
: > "$tmp/btfbad"
# shellcheck disable=SC2016   # awk program
BT_RE=$BT_RE BT_FORM_RE=$BT_FORM_RE BT_FORM_FNS=$BT_FORM_FNS awk -v BAD="$tmp/btfbad" '
  BEGIN { BT = ENVIRON["BT_RE"]; FORM = ENVIRON["BT_FORM_RE"]; FNS = ENVIRON["BT_FORM_FNS"] }
  { fn = $0; sub(/^[^:]*:[^:]*:/, "", fn); sub(/:.*/, "", fn)
    if (index(FNS, " " fn " ") == 0) next
    t = $0; for (k = 0; k < 3; k++) t = substr(t, index(t, ":") + 1)
    gsub(FORM, " ", t)
    gsub(/\\/, "", t); gsub(/"[ \t]+"/, "", t); gsub(/["\047]/, "", t)
    if (t ~ BT) print $0 > BAD }' "$tmp/bt"
rowif "Bluetooth word forms ($(printf '%s' "$BT_FORM_FNS" | sed 's/^ *//; s/ *$//')): tool words outside bt_is/bt_kid = $(lines "$tmp/btfbad")" [ ! -s "$tmp/btfbad" ]
[ ! -s "$tmp/btfbad" ] || show < "$tmp/btfbad"
BT_CMD_RE="^([A-Za-z0-9_./-]*/)?($BT_WORDS)([^A-Za-z0-9_-]|\$)"
for _m in wrap cmdpos; do
  case $_m in wrap) _fns=$BT_FUNCS ;; *) _fns=' bt_stub bt_selftest ' ;; esac
  : > "$tmp/bt_$_m"; : > "$tmp/bt_${_m}_n"
  BT_WRAP_RE=$BT_WRAP_RE BT_CMD_RE=$BT_CMD_RE BT_MODE=$_m BT_SEG_FNS=$_fns awk -v BAD="$tmp/bt_$_m" -v NREAD="$tmp/bt_${_m}_n" "$BTSEG" "$tmp/code"
  _nf=0; for f in $_fns; do grep -qxF "$f" "$tmp/fnames" && _nf=$((_nf + 1)); done
  # shellcheck disable=SC2086   # _fns is a word list on purpose
  _what="$(cat "$tmp/bt_${_m}_n") code lines read in $_nf of $(printf '%s\n' $_fns | grep -c .) functions"
  case $_m in
    wrap) rowif "Bluetooth wrappers: wrapper, command word from a variable, or timeout outside bt_begin = $(lines "$tmp/bt_wrap") ($_what)" [ ! -s "$tmp/bt_wrap" ] ;;
    *) rowif "Bluetooth command position: tool word as a command in bt_stub or bt_selftest = $(lines "$tmp/bt_cmdpos") ($_what)" [ ! -s "$tmp/bt_cmdpos" ] ;;
  esac
  [ ! -s "$tmp/bt_$_m" ] || show < "$tmp/bt_$_m"
done

# 6c · the five `_pineap` lines of apcli_ro, byte for byte (the pins above): every line of apcli_ro that holds `_pineap` is one of them, each
# exactly once (an id of APCLI_NOT_YET may still be missing). The collector's own selftest pins the same lines at run time; this is the
# static guard that a sixth line, a changed argument or a command name taken from a variable cannot pass (SECURITY.md, the sign-off per command).
apcli_scan
ap_n=$(sed -n 1p "$tmp/ap_cnt"); ap_bad=$(lines "$tmp/ap_bad")
ap_off=""; ap_dup=""; ap_ann=""; ap_stale=""; ap_unk=""
while IFS="$(printf '\t')" read -r _id _c; do
  [ "$_id" != "$ap_n" ] || [ -n "$_c" ] || continue
  case $_c in
    1) btfn_in "$APCLI_NOT_YET" "$_id" && ap_stale="$ap_stale $_id" ;;
    0) if btfn_in "$APCLI_NOT_YET" "$_id"; then ap_ann="$ap_ann $_id"; else ap_off="$ap_off $_id"; fi ;;
    *) ap_dup="$ap_dup $_id" ;;
  esac
done < "$tmp/ap_cnt"
for f in $APCLI_NOT_YET; do awk -F'\t' -v I="$f" '$1 == I { f = 1 } END { exit !f }' "$tmp/ap_cnt" || ap_unk="$ap_unk $f"; done   # an announced id that is no pin is a typo
ap_ok=0; [ "$ap_bad" = 0 ] && [ -z "$ap_off$ap_dup$ap_unk" ] && ap_ok=1
rowif "apcli_ro literal lines: $ap_n lines hold _pineap, not pinned $ap_bad, pins missing:${ap_off:- none}, repeated:${ap_dup:- none} (announced, not there yet:${ap_ann:- none}; announced but unknown:${ap_unk:- none})" [ "$ap_ok" = 1 ]
for f in $ap_stale; do echo "    hint: $f is in apcli_ro and still in APCLI_NOT_YET: please remove"; done
[ "$ap_bad" = 0 ] || show < "$tmp/ap_bad"

# 6d · a name that is built when a line runs, anywhere in the shell scope (SECURITY.md, docs/architecture.md §14.6). The rows above read NAMES: a tool put together
# while the script runs (`zz_a=hci; zz_b=tool; "$zz_a$zz_b" -i hci0 lescan`) has no word of BT_WORDS on any line, and the row 'Bluetooth wrappers' reads only the functions of
# BT_FUNCS. This row reads every code line of every shell file of the scope (BTSEG, mode dyn, in the pass of shview that also makes the code lines and the function of each) and the `$( )` and backtick expressions in the bodies of
# here-documents with a bare delimiter (the shell expands those when it runs; the body of a quoted one is text), and lists each simple command whose COMMAND WORD holds an expansion: `$VAR`,
# `${...}`, `$( )` or a backtick expression, quoted or not, also behind a wrapper word (`exec`, `command`, `env`, `nice`, `nohup`, `setsid`, `time`, `xargs`, `busybox`,
# `timeout [-s SIG] N`, `sudo`, `stdbuf`) and after `VAR=value` prefixes and redirections. The lines that stand today are the pinned list below, byte for byte, leading blanks cut,
# each with the function it stands in (`-` = outside every function): the `nice` prefix of the launchers, the fixture builder `$rsq` of the self-test, the screen dispatch
# `screen_$1` of the Overview, the page server's `$NC` and `$HANDLER` and the stop call; the four `$ap_to _pineap` lines of apcli_ro are the pins of row 6c and are taken from there.
# A line that is not pinned, a pinned line that changed and a pin without a line are red: whoever adds or edits such a line reads its command word and changes this list on purpose.
# NOT SEEN, and SECURITY.md says so: a program text that is built and then run (`eval`, `sh -c`, a pipe into `sh`, an awk `system()`, a `. file`), a name made by a function the script
# defines, and a glob that is only handed on as an argument (`ln -s /usr/bin/hc?tool x; x ...`, `cp`). Nothing here reads what a program does, so for those the guarantee is review, and the run-time
# witness of the collector's own Bluetooth window (it sees nothing of a tool that a scan started outside the window). The mutation probe plants every form the rows read, and the forms above as controls.
cat > "$tmp/dynpins" <<'DYNPINS'
-:"$HANDLER" < "$FIFO" | "$NC" "$@" > "$FIFO" &   # "$@" = the listening arguments chosen above
-:$NICE ./starchorus-collect.sh >/dev/null 2>"$STARCHORUS_DIR/collect.log" &
-:elif "$NC" -h 2>&1 </dev/null | grep -qE -- '(^|[[:space:]])-s([ ,]|$)'; then
pl_col_launch:$PL_NICE setsid ./starchorus-collect.sh </dev/null >/dev/null 2>collect.log &
pl_overview:STARCHORUS_SINCE=$pl_since STARCHORUS_PAGE_URL=$pl_pu STARCHORUS_PARENT_PID=$$ $PL_NICE sh "$STARCHORUS_DIR/starchorus-display.sh" >/dev/null 2>&1
pl_serve:$PL_NICE python3 -m http.server "$STARCHORUS_PORT" --bind "$PL_ADDR" --directory "$STARCHORUS_DIR" >/dev/null 2>&1 &
pl_serve:$PL_NICE uhttpd -p "$PL_ADDR:$STARCHORUS_PORT" -h "$STARCHORUS_DIR" || {
pl_serve:STARCHORUS_BIND=$pl_sb $PL_NICE setsid "$STARCHORUS_DIR/starchorus-serve.sh" </dev/null >/dev/null 2>&1 &
pl_serve:STARCHORUS_BIND=$pl_sb $PL_NICE start-stop-daemon -S -b -x "$STARCHORUS_DIR/starchorus-serve.sh"
render:top|bands|devices|probes|clients|bluetooth|air) "screen_$1" ;;
render:top|bands|devices|probes|clients|bluetooth|air) "screen_$1" ;;
selftest:"$rsq" "$ldb" >/dev/null 2>&1 <<SQL
selftest:"$rsq" "$npdb" >/dev/null 2>&1 <<SQL
selftest:"$rsq" "$tdir/recon_pn.db" "INSERT INTO ssid VALUES (3,0,1,8,'AABBCC00000A','New',0,0,-40,2437,6,17184063752);" >/dev/null 2>&1
selftest:i=0; while [ "$i" -lt 150 ]; do printf "INSERT INTO ssid VALUES (%s,0,1,8,'D2D2D2%06d','Grown%s',0,%s,-80,2437,6,8);\n" $((100 + i)) "$i" "$i" $((n0 + 90)); i=$((i + 1)); done | "$rsq" "$kdb" >/dev/null 2>&1
serve:$NICE busybox httpd -f -h "$STARCHORUS_DIR" -p "$ADDR:$STARCHORUS_PORT" & srv=$!
serve:$NICE python3 -m http.server "$STARCHORUS_PORT" --bind "$ADDR" --directory "$STARCHORUS_DIR" >/dev/null 2>&1 & srv=$!
serve:$NICE uhttpd -f -p "$ADDR:$STARCHORUS_PORT" -h "$STARCHORUS_DIR" & srv=$!
stop_servers:"$STARCHORUS_DIR/starchorus-serve.sh" stop >/dev/null 2>&1
DYNPINS
# shellcheck disable=SC2016   # the literal text of the pinned lines
grep -F '$ap_to' "$tmp/pins" | sed 's/^/apcli_ro:/' >> "$tmp/dynpins"
: > "$tmp/dyn_new"; : > "$tmp/dyn_gone"   # $tmp/dyn_bad, dyn_bad2 and dyn_n are the verdicts of the pass shview() made (BTSEG, mode dyn, over every code line of every shell file of the scope)
dyn_p=$(pin_cmp "$tmp/dyn_bad" "$tmp/dynpins" "$tmp/dyn_new" "$tmp/dyn_gone")
dyn_ok=0; [ ! -s "$tmp/dyn_new" ] && [ ! -s "$tmp/dyn_gone" ] && dyn_ok=1
rowif "§14.6d command words from an expansion: $(lines "$tmp/dyn_bad") lines hold one, pinned $dyn_p, not pinned $(lines "$tmp/dyn_new"), pins without a line $(lines "$tmp/dyn_gone") ($(cat "$tmp/dyn_n") code lines read)" [ "$dyn_ok" = 1 ]
[ ! -s "$tmp/dyn_new" ] || { show < "$tmp/dyn_new"; echo "    hint: the command word of that line is built when it runs: name the tool in the line, or read it and add the line (function:text) to the pinned list of row 6d"; }
[ ! -s "$tmp/dyn_gone" ] || { sed 's/^/    pin without a line: /' "$tmp/dyn_gone" | cut -c1-200; echo "    hint: a pinned line changed or went: change the pinned list of row 6d with it"; }

# 6e · a name built by something other than an expansion, anywhere in the shell scope (the same pass as 6d, its second verdict): a command word that holds an unquoted glob character (`*`, `?`, `[`;
# `[` and `[[` themselves are the test: `/usr/bin/hc?tool`, `/usr/bin/hci[t]ool`, `/usr/sbin/i[w]`), `find` with `-exec`, `-execdir`, `-ok` or `-okdir` (the command is then whatever `find` turns up
# or, with `{}` first, what it names), `xargs` whose command is its replacement string (`xargs -I{} {} ...`: the command comes from stdin) or is missing (it then runs `echo` over what it reads),
# and any `alias` definition (`alias zz_s="$zz_a$zz_b"`: a later line runs a name that no line spells). A glob in a for-list, in a case pattern or as an argument is no command word and stays unread.
# The row compares with a pinned list as 6d does; nothing stands there today, so any line is a new one.
cat > "$tmp/dynpins2" <<'DYNPINS2'
DYNPINS2
: > "$tmp/dyn_new2"; : > "$tmp/dyn_gone2"
dyn_p2=$(pin_cmp "$tmp/dyn_bad2" "$tmp/dynpins2" "$tmp/dyn_new2" "$tmp/dyn_gone2")
dyn_ok2=0; [ ! -s "$tmp/dyn_new2" ] && [ ! -s "$tmp/dyn_gone2" ] && dyn_ok2=1
rowif "§14.6e command names from a glob, find -exec, xargs or alias: $(lines "$tmp/dyn_bad2") lines hold one, pinned $dyn_p2, not pinned $(lines "$tmp/dyn_new2"), pins without a line $(lines "$tmp/dyn_gone2") ($(cat "$tmp/dyn_n") code lines read)" [ "$dyn_ok2" = 1 ]
[ ! -s "$tmp/dyn_new2" ] || { show < "$tmp/dyn_new2"; echo "    hint: the command of that line is found by a glob, by find or by xargs, or is an alias: name the tool in the line, or read it and add the line (function:text) to the pinned list of row 6e"; }
[ ! -s "$tmp/dyn_gone2" ] || { sed 's/^/    pin without a line: /' "$tmp/dyn_gone2" | cut -c1-200; echo "    hint: a pinned line changed or went: change the pinned list of row 6e with it"; }

# 7b · recon.db is only ever READ, and read-only (SECURITY.md, first permitted way): every sqlite3 CALL outside
# selftest() carries -readonly. `have sqlite3` is a presence test, not a call. The floor keeps the row from turning
# green because the one production call vanished or was renamed out of sight of the regex.
# Read per OCCURRENCE, not per line: each `sqlite3` word on a line is one call, and its flag must stand in that call's own
# words: the words up to the next `;` `&` `|`, the next `sqlite3`, a comment start (blank + `#`) or the first quote. So a
# `# -readonly` comment, a second call after a read-only one, and `-readonly` inside a quoted SQL string do not count.
# An occurrence after a `#` is still a call (a `#` inside a string would otherwise hide it).
MIN_SQLITE_CALLS=1   # production calls: scoped sqlite3 words outside selftest(), minus `have sqlite3` (measured: 1, recondb_query)
scoped '(^|[^A-Za-z0-9_-])sqlite3([^A-Za-z0-9_]|$)' > "$tmp/sq0"
# shellcheck disable=SC2016   # awk program
SQAWK='{ t = $0
  for (k = 0; k < 3; k++) t = substr(t, index(t, ":") + 1)          # "file:line:fn:" off, the text stays
  fn = $0; sub(/^[^:]*:[^:]*:/, "", fn); sub(/:.*/, "", fn)
  if (fn == "selftest") next
  while (match(t, /have[ \t]+sqlite3/)) t = substr(t, 1, RSTART - 1) substr(t, RSTART + RLENGTH)
  pos = 1; ncall = 0; bad = 0
  while ((i = index(substr(t, pos), "sqlite3")) > 0) {
    a = pos + i - 1; pos = a + 7
    if (a > 1 && substr(t, a - 1, 1) ~ /[A-Za-z0-9_-]/) continue
    if (substr(t, a + 7, 1) ~ /[A-Za-z0-9_]/) continue
    ncall++
    seg = substr(t, a + 7); cut = length(seg) + 1
    for (k = 1; k <= length(seg); k++) {
      c = substr(seg, k, 1)
      if (c ~ /[;&|"\047`]/ || substr(seg, k, 7) == "sqlite3" || (c == "#" && (k == 1 || substr(seg, k - 1, 1) ~ /[ \t]/))) { cut = k; break }
    }
    if ((" " substr(seg, 1, cut - 1) " ") !~ /[ \t]-readonly[ \t]/) bad = 1
  }
  if (ncall > 0) { print $0 > CALLS; calls += ncall; if (bad) print $0 > BADS }
}
END { print calls + 0 }'
: > "$tmp/sqcall"; : > "$tmp/sqbad"
nsq=$(awk -v CALLS="$tmp/sqcall" -v BADS="$tmp/sqbad" "$SQAWK" "$tmp/sq0")
nsqb=$(lines "$tmp/sqbad")
sqok=0; [ "$nsqb" = 0 ] && [ "$nsq" -ge "$MIN_SQLITE_CALLS" ] && sqok=1
rowif "sqlite3 read-only: $nsq calls outside selftest (≥ $MIN_SQLITE_CALLS), without -readonly $nsqb" [ "$sqok" = 1 ]
[ "$nsqb" = 0 ] || show < "$tmp/sqbad"

# 7c · starchorus-serve.sh (the nc listener, the only part of Starchorus that listens on the device): the request handler accepts
# GET/HEAD only (everything else is turned into a path no branch serves) and serves exactly {/, /index.html,
# /starchorus.json}; the default branch answers 404. Read from the text of the heredoc that writes the handler; the file
# is never run. Pinned as exact strings: a widened method list or a new path is red until this row is changed on
# purpose. Each block must occur exactly once (a renamed `case` would otherwise leave nothing to compare).
SERVE=starchorus-serve.sh
# shellcheck disable=SC2016   # literal handler text searched for in starchorus-serve.sh
SERVE_METHOD='case "$method" in GET|HEAD) : ;; *) path=__BAD__ ;; esac'
SERVE_PATHS='/|/index.html /starchorus.json *'
if [ -f "$SERVE" ]; then
  # shellcheck disable=SC2016
  nmc=$(grep -c '^case "\$method" in' "$SERVE")
  # shellcheck disable=SC2016
  mline=$(grep '^case "\$method" in' "$SERVE" | head -n 1)
  # shellcheck disable=SC2016   # awk program
  awk '/^case "\$path" in[[:space:]]*$/ { inb = 1; blocks++; next }
       inb && /^esac/ { inb = 0; next }
       inb && /^[[:space:]]+[^[:space:]]+\)[[:space:]]/ { p = $1; sub(/\).*/, "", p); pats = pats (pats == "" ? "" : " ") p; if (p == "*" && $0 ~ /f=""/) dflt = 1 }
       END { printf "%d\n%s\n%d\n", blocks, pats, dflt }' "$SERVE" > "$tmp/sv"
  npc=$(sed -n 1p "$tmp/sv"); pats=$(sed -n 2p "$tmp/sv"); dflt=$(sed -n 3p "$tmp/sv")
else
  nmc=0; mline=""; npc=0; pats=""; dflt=0
fi
svok=0; [ "$nmc/$npc/$dflt" = 1/1/1 ] && [ "$mline" = "$SERVE_METHOD" ] && [ "$pats" = "$SERVE_PATHS" ] && svok=1
rowif "starchorus-serve.sh: GET|HEAD only, paths {$pats}, default 404 (blocks $nmc/$npc/$dflt)" [ "$svok" = 1 ]
[ "$svok" = 1 ] || printf '    method line: %s\n    want:        %s\n    paths want:  %s\n' "$mline" "$SERVE_METHOD" "$SERVE_PATHS"

# 7d · tools/device-probe.sh: the one file of tools/ that runs on the device (it is piped into a device shell over ssh). Three rows of its own. The rows above read only the list of the shell scope and do not see it,
# so no allowlist, regex or pin of theirs applies to it, and nothing below applies to them. The probe is read with the same denylists (SEC6_RE, TX_RE, BT_RE, the `iw scan` test, the sqlite3 word, the rows
# 6d and 6e) and with PNET_RE, which only it is read for. A function allowlist (BT_FUNCS, SEC6_FUNCS) is never consulted for it: a function of the probe named `bt_begin` or `apcli_ro` has no standing.
# What the probe deliberately names or runs is a pinned line, byte for byte (leading blanks cut) with the function it stands in (`-` = outside every function), each once; the reason stands next to the pin.
# A pin is an exact line, never a pattern. Row 'named tools': the union of every line that a denylist hits, that holds a built command word (6d) or a glob (6e), or whose command is one of PROBE_PINNED (and the lines
# such a command goes on over after a trailing backslash), must be a pinned line, and every pin must have its line. Row 'programs': every simple command the probe starts is a function of the probe itself (not after
# `command`, which skips functions: `mv() { command mv "$@"; }` does not make `mv` a probe function), a builtin or keyword (PROBE_BUILTINS), a plain read-only program (PROBE_PLAIN) or one of PROBE_PINNED (whose lines are
# pinned); any other name, a path or a `.` is an unlisted command; the word after `command` is read against the lists without its `!`, and is never `run_limited`, which is no program. A program that writes by an option of its own is
# not plain: `date` (-s), `sed` (-i, a w command) and `sort` (-o) are pinned, every line of them. A `trap` runs its action as a command when the signal comes, and an action is a string that this row does not read: only `-`, an
# empty string, a function of the probe and `exit N` are accepted, any other is an unlisted command. A here-document is read by its delimiter: a delimiter word that is not a plain name, bare or wholly in quotes, and a body with a
# `$(` or a backtick under a bare delimiter, are unlisted commands too. A function of the probe is a `name()` that the reader meets at the start of a line with nothing open: one that stands in a comment, a here-document body,
# a string, a subshell or behind a `;`, or is indented, is none (its name stays an unlisted command, as a call and as the action of a `trap`), and a function named like a listed program is red wherever it is defined. The same row keeps the probe from writing outside its private directory, on the whole file (below, before the fill of this part). Not read, as for the other
# scripts: a program text that is built and then run, and what an awk or sed program does with its text (review; the run rows of tools/regress.d/device-probe.sh show what the probe does on a machine).
cat > "$tmp/ppins0" <<'PPINS'
## text only: the usage hint the guard prints, which names the ssh command the person types; the probe never starts ssh
-:echo "device-probe: usage: ssh root@<device> sh -s < tools/device-probe.sh | tee probe.txt" >&2
## a presence test by name (command -v for each name in the list): nothing in the list is run; curl, wget, nc, tcpdump and airodump-ng are there to see whether the device has them
sect_tools:for _t in sqlite3 tcpdump iw iwinfo jq curl wget nc timeout setsid start-stop-daemon uhttpd python3 airodump-ng; do
## Bluetooth names, and no Bluetooth tool run: a prefix list for printing plain BlueZ-looking file names, a heading and summary texts that say so, a presence test by name (command -v), and the counting of names in /proc/PID/comm
-:BTP_RE='^(bt|hci|l2|rf|sdp|gatt|obex|bluetooth|bluez|mesh|rctest|avinfo|isotest|ciptool|bccmd|bdaddr|hid2hci|mpris|hex2hcd|scotest)'
sect_bluetooth:heading 9 "bluetooth (sysfs, /proc and file names only; no Bluetooth tool is run, hciconfig included, and nothing is scanned)"
sect_bluetooth:for _t in hcitool btmon hciconfig bluetoothctl btmgmt bluetoothd gatttool l2ping rfkill; do
sect_bluetooth:case $_cn in bluetoothd) _pb=$((_pb + 1)) ;; hcitool) _ph=$((_ph + 1)) ;; btmon) _pm=$((_pm + 1)) ;; esac
sect_bluetooth:kv bluez.processes "bluetoothd=$_pb hcitool=$_ph btmon=$_pm (by /proc/PID/comm; a window of the collector leaves none of the last two)"
sect_bluetooth:vset 13 "OBSERVED $V13_HCI; $V13_NET; BlueZ-like files:$_fl; processes bluetoothd=$_pb hcitool=$_ph btmon=$_pm (files only: no window was run)"
## sqlite3: the one place it is started (read-only, on a copy inside the private directory, the SQL as an argument), and a presence test with two texts that name it
sq:sqlite3 -readonly -noheader "$1" "$2" 2>"$T/sq.err" < /dev/null
sect_recon:if ! have sqlite3; then kv recon.db "sqlite3 is not installed, nothing can be opened"; recon_fail "sqlite3 not installed"; return 0; fi
## read-only iw: the interface list, the information of one interface, the channel survey counters and the capabilities of one phy, each into a file of the private directory; none sets anything or sends a frame
sect_radio:iw dev > "$T/iwdev.txt" 2>&1 < /dev/null; _rc=$?
sect_radio:iw dev "$MON" info > "$T/iwinfo.txt" 2>&1 < /dev/null; _irc=$?
sect_radio:iw dev "$MON" survey dump > "$T/survey.txt" 2>&1 < /dev/null; _src=$?
sect_radio:iw phy "$_phy" info > "$T/phyinfo.txt" 2>&1 < /dev/null; _prc=$?
## version and applet texts, nothing is run: busybox without an argument prints its usage, iw --version and timeout --version print a version, flock --version runs in the private directory and is given no file, busybox --list prints applet names into grep, /bin/bash --version prints a version
sect_tools:if have busybox; then kv busybox.version "$(busybox 2>&1 < /dev/null | head -n 1 | clean | cut -c1-80)"
sect_tools:if have iw; then kv iw.version "$(iw --version 2>&1 < /dev/null | head -n 1 | clean | cut -c1-60)"; fi
sect_tools:_tv=$(timeout --version 2>&1 < /dev/null | head -n 1 | clean | cut -c1-70)
sect_alertenv:_fv=$( (cd "$T" && flock --version 2>&1 < /dev/null) | head -n 1 | clean | cut -c1-70)
sect_alertenv:_fa=no; if have busybox && busybox --list 2> /dev/null < /dev/null | grep -qx flock; then _fa=yes; fi
sect_alertenv:_bv=$("$BASHB" --version 2>&1 < /dev/null | head -n 1 | clean | cut -c1-70)
## the lock, as the alert companion takes it (alert-deauth.sh): flock -x 9 once, in a subshell whose fd 9 is opened on a file of the private directory that no other process opens, so nothing waits; the exit status of flock is written from inside, and the lock ends with the subshell
ae_lock:( flock -x 9; printf '%s' "$?" > "$T/ae.lockrc" ) 2> "$T/ae.lockerr" > /dev/null 9> "$T/ae.lock" < /dev/null; _lr=$?
## the two literals of the case test, run under /bin/bash and under sh with BASH_ENV and ENV empty; no script or file of the device is given to either shell
ae_case:BASH_ENV='' ENV='' "$2" -c 'for s in 3f:A9 3g:A9; do case $s in [[:xdigit:]][[:xdigit:]]:[[:xdigit:]][[:xdigit:]]) echo match ;; *) echo refuse ;; esac; done' > "$T/ae.case" 2>&1 < /dev/null; _cr=$?
## copies of the live recon.db (and its -wal file) into the private directory; the live file is only copied, never opened by the probe
sect_recon:if cp "$DB" "$A" 2>/dev/null; then HAVE_A=1; fi
sect_recon:if [ -f "$DB-wal" ]; then cp "$DB-wal" "$A-wal" 2>/dev/null; fi
sect_recon:if cp "$DB" "$B" 2>/dev/null; then HAVE_B=1; fi
sect_recon:if [ -f "$DB-wal" ]; then cp "$DB-wal" "$B-wal" 2>/dev/null; fi
sect_recon:cp "$DB" "$A" 2>/dev/null; _v=$(sq "$A" "SELECT sqlite_version();")
## lists file names under /etc and /lib/hak5 by name pattern (find without -exec, -delete or -ok): existence only, nothing is opened
sect_cands:find "$RF/etc" "$RF/lib/hak5" -maxdepth 3 \( -name '*ssid*' -o -name '*SSID*' -o -name '*bssid*' -o -name '*pool*' -o -name '*pineap*' \) 2>/dev/null | head -n 40 > "$T/found"
## the installed collector's --status: it reads its pidfiles and prints; it starts and stops nothing
sect_starchorus:STARCHORUS_OUTDIR="$INST" sh "$COLL" --status > "$T/status.txt" 2>&1 < /dev/null
## the private directories of the self-test run, the mode of its mktemp shim and the private temp directory itself, all inside /tmp (RAM on the device)
sect_starchorus:mkdir -p "$T/st/tmp" "$T/st/out" "$T/st/bin"
sect_starchorus:chmod 700 "$T/st/bin/mktemp"
main:T=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-probe.XXXXXX" 2>/dev/null) || { echo "device-probe: cannot create a private temp dir under ${TMPDIR:-/tmp}" >&2; return 2; }
## run_limited starts the command it is handed, in the background, with a time limit; its two callers are the self-tests of the installed Starchorus (collector 240 s, Overview 90 s), run in the private directory on synthetic data, with TMPDIR and the STARCHORUS directories pinned inside it
run_limited:"$@" > "$_of" 2>&1 < /dev/null &
sect_starchorus:run_limited 240 "$T/st/collector.txt" env PATH="$T/st/bin:${PATH:-/usr/bin:/bin}" TMPDIR="$T/st/tmp" STARCHORUS_OUTDIR="$T/st/out" STARCHORUS_CAPDIR="$T/st/out/cap" STARCHORUS_PIDDIR="$T/st/out" sh "$COLL" --selftest
sect_starchorus:run_limited 90 "$T/st/display.txt" env PATH="$T/st/bin:${PATH:-/usr/bin:/bin}" TMPDIR="$T/st/tmp" STARCHORUS_DIR="$INST" sh "$PAG" --selftest
## signals only a background job this run started itself (its own sleep or poll child; kill -0 only asks whether it still runs)
cleanup:if [ -n "$SLPID" ]; then kill "$SLPID" 2>/dev/null; fi
cleanup:if [ -n "$BGPID" ]; then kill "$BGPID" 2>/dev/null; fi
run_limited:while kill -0 "$BGPID" 2>/dev/null; do
run_limited:kill "$BGPID" 2>/dev/null; sleep 1; kill -9 "$BGPID" 2>/dev/null
## removes only the private temp directory this run created, after its name has been checked
cleanup:case $T in */starchorus-probe.*) rm -rf "$T" ;; esac
## date reads the clock and sets nothing: date +%s (the device clock as an epoch number), date -u with a format, and date -r FILE +%s (BusyBox: the mtime of a file); no -s, no argument that is a time
mtime_epoch:if ! isnum "$_m"; then _m=$(date -r "$1" +%s 2>/dev/null) || _m=""; fi    # BusyBox date -r
sect_recon:MT_A=$(mtime_epoch "$DB"); NOW_A=$(date +%s); if ! isnum "$NOW_A"; then NOW_A=0; fi
sect_recon:MT_B=$(mtime_epoch "$DB"); NOW_B=$(date +%s); if ! isnum "$NOW_B"; then NOW_B=0; fi
sect_platform:kv device.clock_epoch "$(date +%s 2>/dev/null)"
main:say "# started (device clock, UTC): $(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null)"
## sed is a filter on a pipe whose program is its own text (the privacy filter's two substitutions, a key=value reader, a line prefix, a trailing comma or blank cut); none is given -i, a w command or a file to change. The privacy filter's command goes on over a backslash: its second line is pinned with the first
scrub:sed -E -e 's/([0-9A-Fa-f]{2}[:._-]){5}[0-9A-Fa-f]{2}/<mac-withheld>/g' \
-:tok() { printf '%s\n' "$1" | sed -n "s/.* $2=\\([-0-9a-zA-Z.]*\\).*/\\1/p" | head -n 1; }   # value of " key=" in a line
sect_recon:_cols=$(cut -d'|' -f2 "$T/ti" | tr -cd 'A-Za-z0-9_\n' | tr '\n' ',' | sed 's/,$//')
sect_recon:_pk=$(awk -F'|' '$6 + 0 > 0 { printf "%s ", $2 }' "$T/ti" | tr -cd 'A-Za-z0-9_ ' | sed 's/ $//')
sect_platform:grep '^DISTRIB_' "$RF/etc/openwrt_release" 2>/dev/null | clean | cut -c1-120 | sed 's/^/openwrt_release: /' >> "$OUT"
sect_platform:df -kP "$RF/root" "$RF/tmp" 2>&1 | clean | cut -c1-120 | sed 's/^/df: /' >> "$OUT"
sect_starchorus:clean < "$T/status.txt" | cut -c1-160 | sed 's/^/collector.status: /' >> "$OUT"
sect_starchorus:grep 'FAIL:' "$T/st/collector.txt" | clean | cut -c1-160 | head -n 20 | sed 's/^/collector.selftest.fail: /' >> "$OUT"
sect_starchorus:tail -n 1 "$T/st/collector.txt" | clean | cut -c1-160 | sed 's/^/collector.selftest.last: /' >> "$OUT"
sect_starchorus:grep 'FAIL:' "$T/st/display.txt" | clean | cut -c1-160 | head -n 20 | sed 's/^/display.selftest.fail: /' >> "$OUT"
sect_starchorus:tail -n 1 "$T/st/display.txt" | clean | cut -c1-160 | sed 's/^/display.selftest.last: /' >> "$OUT"
ae_case:_co=$(clean < "$T/ae.case" | tr '\n' ' ' | sed 's/ *$//' | cut -c1-80)
scrub:-e 's/[0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4}/<mac-withheld>/g' |
## sort -u orders the phy names of a file of the private directory into another; no -o
sect_radio:awk '{ print $2 }' "$T/ifaces" | sort -u > "$T/phys"
PPINS
grep -v '^##' "$tmp/ppins0" | sed "s|^|$PROBE:|" > "$tmp/ppins"
PROBE_BUILTINS=' : [ break case cd command continue done echo esac exit fi for printf read return set shift trap umask wait '
PROBE_PLAIN=' awk cat cut df grep head jq ls readlink sleep stat tail tr uname wc '
PROBE_PINNED=' busybox chmod cp date find flock iw kill mkdir mktemp rm run_limited sed sh sort sqlite3 timeout '
MIN_PROBE_FNS=32       # function heads of the probe that the scope check recognises (measured: 37; the one-line functions are not heads)
MIN_PROBE_LINES=800    # code lines of the probe that the rows read (measured: 959)
MIN_PROBE_CMDS=800     # simple commands of the probe whose name the pass records (measured: 997)
MIN_PROBE_WRITES=60    # redirection targets and destinations of cp, mv and tee that the pass records and the row judges (measured: 126)
# The probe is read whole, as the shell reads it, by ONE reader (BTSEG, mode dyn, with BT_VIEW): its input is every line of the file, comment lines, empty lines, here-document bodies and the lines of a string that runs over several
# lines among them, and the state is one for the whole file (a line that only looks like a function head does not start a new one). The same pass makes the lists the rows lean on, so that none of them comes from a text scan of the
# raw file, which a line of a here-document body or a string (`name() { :; }`, a line that looks like a comment or a `}`) could write to:
#   pcode   the code lines "file:line:function:text" (a comment line and an empty line are none; a here-document body and the lines of a string are), the function being the one whose head stood at the start of a line with nothing open;
#   pheads  those function heads (the scope check's form of a head, which gives the pins their function);
#   pfn     the functions the probe defines: `name()` met by the reader at the start of a line, nothing open (a call of one is no unlisted command, and its name may stand as the action of a `trap`);
#   padef   every `name()` the reader met, wherever it stands (the shadow test reads all of them).
# Two runs: the first makes pfn (the action of a trap may name a function that is defined further down), the second reads with it. All files of a run are emptied first.
# shellcheck disable=SC2016   # awk program
PVSCOPE='BEGIN { RE = ENVIRON["SCOPE_RE"] }
{ l = $0; for (k = 0; k < 3; k++) l = substr(l, index(l, ":") + 1)
  gsub(/\\/, "", l); gsub(/"[ \t]+"/, "", l); gsub(/["\047]/, "", l)   # the normal form, as in SCOPE
  if (l ~ RE) print $0 }'
pscoped_n() { SCOPE_RE=$1 awk "$PVSCOPE" "$tmp/pcode"; }   # the hit read on the normal form of the line, over the code lines of the probe
pclear() { : > "$tmp/praw"; : > "$tmp/pcode"; : > "$tmp/pheads0"; : > "$tmp/pfn0"; : > "$tmp/padef0"; : > "$tmp/pdyn_bad"; : > "$tmp/pdyn_bad2"; : > "$tmp/pdyn_n"; : > "$tmp/pcmds"; : > "$tmp/pwrites"; [ ! -f "$PROBE" ] || awk '{ print FILENAME ":" FNR ":-:" $0 }' "$PROBE" > "$tmp/praw"; }
pread() { BT_WRAP_RE='' BT_CMD_RE='' BT_MODE=dyn BT_SEG_FNS='*' BT_CMDS="$tmp/pcmds" BT_WRITES="$tmp/pwrites" BT_VIEW="$tmp/pcode" BT_HEADS="$tmp/pheads0" BT_FDEFS="$tmp/pfn0" BT_ADEFS="$tmp/padef0" BT_PFN="$1" awk -v BAD="$tmp/pdyn_bad" -v BAD2="$tmp/pdyn_bad2" -v NREAD="$tmp/pdyn_n" "$BTSEG" "$tmp/praw"; }
pclear; pread ""
LC_ALL=C sort -u "$tmp/pfn0" > "$tmp/pfn"
pclear; pread "$(tr '\n' ' ' < "$tmp/pfn")"
LC_ALL=C sort -u "$tmp/pheads0" > "$tmp/pheads"
LC_ALL=C sort -u "$tmp/padef0" "$tmp/pfn" > "$tmp/padef"
# the lines whose command is one of PROBE_PINNED
awk -F'\t' -v PI="$PROBE_PINNED" '{ n = $1; sub(/^[^\t]*\t/, ""); sub(/^!/, "", n); if (index(PI, " " n " ") > 0) print }' "$tmp/pcmds" > "$tmp/pprog"
# the arguments of a command go on over a trailing backslash: the lines after the line of a PROBE_PINNED command, for as long as the line before ends in a backslash, are hits of the same kind
# (`sed -E -e '…' \` could otherwise be given `-i FILE` on its next line, which no pin would see)
awk -v H="$tmp/pprog" 'BEGIN { while ((getline l < H) > 0) h[l] = 1 } cont { print; cont = ($0 ~ /\\$/); next } { cont = (($0 in h) && $0 ~ /\\$/) }' "$tmp/pcode" > "$tmp/pcont"
pscoped_n "$SEC6_RE" > "$tmp/p_sec6"
pscoped_n "$TX_RE" > "$tmp/p_tx"
pscoped_n "$BT_RE" > "$tmp/p_bt"
pscoped_n "$PNET_RE" > "$tmp/p_net"
pscoped_n '(^|[^A-Za-z_])iw([[:space:]]+dev[[:space:]]+[^[:space:]|;]+)?[[:space:]]+scan([^A-Za-z_]|$)' > "$tmp/p_scan"   # the test of the row 'iw scan opt-in only', same text
pscoped_n '(^|[^A-Za-z0-9_-])sqlite3([^A-Za-z0-9_]|$)' > "$tmp/p_sq"
: > "$tmp/ph0"; for _f in p_sec6 p_tx p_bt p_net p_scan p_sq pdyn_bad pdyn_bad2 pprog pcont; do cat "$tmp/$_f" >> "$tmp/ph0"; done
awk '!seen[$0]++' "$tmp/ph0" > "$tmp/ph"
: > "$tmp/pnew"; : > "$tmp/pgone"
pp=$(pin_cmp "$tmp/ph" "$tmp/ppins" "$tmp/pnew" "$tmp/pgone" 1)
pn_ok=0; [ ! -s "$tmp/pnew" ] && [ ! -s "$tmp/pgone" ] && pn_ok=1
# writes: the probe writes nowhere but its private directory, and the rule is read on the whole file, not on one section. Every redirection target (`>`, `>>`, `>|`, `2>`, `9>`, glued or not), every destination of `cp`, `mv` and
# `tee` (the last word of the first two, every word of the third; `-t DIR` is never accepted) must be /dev/null or a file below $T: `$T/name`, `"$T/name"` or `${T}/name`, the name made of letters, digits, `.`, `_`, `-` and `/`
# (no expansion: `$T/$1` is whatever the caller hands over, `../../etc/x` among it), with no `..` in it. The variables the probe sets to such a file stand for one too ($OUT, $A, $B, and $A-wal and $B-wal for the copy of a -wal file), on one condition that this row also reads: T, OUT, A and B are only ever assigned
# an empty string or a file below $T (OUT, A, B) and, for T, nothing but the empty string and the one pinned mktemp -d; a `for` or `read` that names one of them counts as an assignment of something else. A descriptor copy (`2>&1`, `>&2`)
# names no file. The three lines below are the exceptions, each once and byte for byte: what the redirection of one of them writes to is not spelled in the line, or holds an expansion. The third is vset, whose file is named by the
# number of the verification: every call of vset has to give digits as its first argument (row programs, unlisted command otherwise). Not read, as above: a program text of awk or sed (an awk `print > "file"`), `eval`,
# and a variable set by `${NAME:=…}` or `getopts`.
cat > "$tmp/wpins0" <<'WPINS'
## run_limited writes the output of the command it is handed to its second argument; both calls of it (section 8) hand it a file of the private directory (they are pinned lines of their own above)
run_limited:"$@" > "$_of" 2>&1 < /dev/null &
## the private directory itself: the only assignment to T that is not an empty string, the one mktemp -d (a pinned line of its own above)
main:T=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-probe.XXXXXX" 2>/dev/null) || { echo "device-probe: cannot create a private temp dir under ${TMPDIR:-/tmp}" >&2; return 2; }
## vset writes the summary line of one verification into the file v.N of the private directory; the name holds an expansion (the number), so the line is pinned. This row reads every call of vset: the first argument has to be digits as written, never a variable or a path
-:vset() { printf '%s\n' "$2" > "$T/v.$1"; }           # summary line of open verification $1
WPINS
grep -v '^##' "$tmp/wpins0" | sed "s|^|$PROBE:|" > "$tmp/wpins"
# shellcheck disable=SC2016   # awk program
WRAWK='
  function unq(v) { if (v ~ /^"[^"]*"$/ || v ~ /^\047[^\047]*\047$/) return substr(v, 2, length(v) - 2); return v }
  function undert(v,   r) {   # a file below $T: what follows has no leading slash, no .. and only name characters, no expansion (`$T/$1` is whatever the caller hands over)
    if (v !~ /^\$(T|\{T\})\//) return 0
    r = v; sub(/^\$(T|\{T\})\//, "", r)
    return (r != "" && r !~ /^\// && index(r, "..") == 0 && r ~ /^[A-Za-z0-9_.\/-]+$/)
  }
  function okw(w,   v) { v = unq(w); return (v == "/dev/null" || v ~ /^\$(OUT|A|B|\{OUT\}|\{A\}|\{B\})(-wal)?$/ || undert(v)) }
  function okas(w,   nm, v) {   # NAME=value: the variables that stand for a target keep to a file below $T (T itself to the empty string)
    nm = w; sub(/=.*/, "", nm); v = substr(w, length(nm) + 2)
    if (nm != "T" && nm != "OUT" && nm != "A" && nm != "B") return 1
    if (v == "" || v == "\"\"" || v == "\047\047") return 1
    return (nm != "T" && undert(unq(v)))
  }
  { k = $1; id = $2; w = $3; r = $0; sub(/^[^\t]*\t[^\t]*\t[^\t]*\t/, "", r)
    if (k == ">" || k == "tee") { n++; if (!okw(w)) print r > WROUT }
    else if (k == "=") { if (!okas(w)) print r > WROUT }
    else { if (!((k "\t" id) in last)) n++; last[k "\t" id] = w; lr[k "\t" id] = r } }
  END { for (x in last) if (!okw(last[x])) print lr[x] > WROUT; print n + 0 > WRN }'
: > "$tmp/pwr0"
LC_ALL=C awk -F'\t' -v WROUT="$tmp/pwr0" -v WRN="$tmp/pwn" "$WRAWK" "$tmp/pwrites"
pnw=$(cat "$tmp/pwn")
LC_ALL=C sort -u "$tmp/pwr0" > "$tmp/pwr"
: > "$tmp/pwnew"; : > "$tmp/pwgone"
pw=$(pin_cmp "$tmp/pwr" "$tmp/wpins" "$tmp/pwnew" "$tmp/pwgone" 1)
# the fill of this part: a probe that lost its function heads, or a pass that reads less, would turn the rows green by looking at less
pnfn=$(lines "$tmp/pheads"); pnl=$(lines "$tmp/pcode"); pnc=$(lines "$tmp/pcmds"); pmiss=""
[ -f "$PROBE" ] || pmiss="$pmiss $PROBE(no such file)"
for w in sq run_limited cleanup sect_alertenv main; do grep -qxF "$w" "$tmp/pheads" || pmiss="$pmiss $w()"; done
pfok=0; [ "$pnfn" -ge "$MIN_PROBE_FNS" ] && [ "$pnl" -ge "$MIN_PROBE_LINES" ] && [ "$pnc" -ge "$MIN_PROBE_CMDS" ] && [ "$pnw" -ge "$MIN_PROBE_WRITES" ] && [ -z "$pmiss" ] && pfok=1
rowif "device-probe.sh scope fill: $pnfn functions (≥ $MIN_PROBE_FNS), $pnl code lines (≥ $MIN_PROBE_LINES), $pnc commands read (≥ $MIN_PROBE_CMDS), $pnw write targets read (≥ $MIN_PROBE_WRITES), unseen:${pmiss:- none}" [ "$pfok" = 1 ]
rowif "device-probe.sh named tools: $(lines "$tmp/ph") lines hold one (sending $(lines "$tmp/p_tx"), Bluetooth $(lines "$tmp/p_bt"), network $(lines "$tmp/p_net"), device call $(lines "$tmp/p_sec6"), iw scan $(lines "$tmp/p_scan"), sqlite3 $(lines "$tmp/p_sq"), built name $(lines "$tmp/pdyn_bad"), glob $(lines "$tmp/pdyn_bad2"), program $(lines "$tmp/pprog"), continued $(lines "$tmp/pcont")), pinned $pp of $(lines "$tmp/ppins"), not pinned $(lines "$tmp/pnew"), pins without a line $(lines "$tmp/pgone")" [ "$pn_ok" = 1 ]
[ ! -s "$tmp/pnew" ] || { show < "$tmp/pnew"; echo "    hint: the line names a tool or starts a program: if that is meant, read it and add it (function:text) with its reason to the pinned list of row 7d"; }
[ ! -s "$tmp/pgone" ] || { sed 's/^/    pin without a line: /' "$tmp/pgone" | cut -c1-200; echo "    hint: a pinned line changed or went: change the pinned list of row 7d with it"; }
# programs: the name of every simple command, against the lists
: > "$tmp/punl"; : > "$tmp/pnames"
LC_ALL=C awk -F'\t' -v FNL="$(tr '\n' ' ' < "$tmp/pfn")" -v BI="$PROBE_BUILTINS" -v PL="$PROBE_PLAIN" -v PI="$PROBE_PINNED" -v UNL="$tmp/punl" -v NAMES="$tmp/pnames" '
  BEGIN { nf = split(FNL, fa, " "); for (i = 1; i <= nf; i++) fn[fa[i]] = 1 }
  { n = $1; m = n; sub(/^!/, "", m); r = $0; sub(/^[^\t]*\t/, "", r); seen[n]++
    if (n == "!run_limited") { print r > UNL; next }   # the word after `command` is a program of the PATH, and no program has the name of a function of the probe
    if (index(PI, " " m " ") > 0 || index(BI, " " m " ") > 0 || index(PL, " " m " ") > 0 || (n in fn)) next   # the lists are read without the `!` of a program after `command`; a function of the probe is never one (`!NAME` is not in fn)
    print r > UNL }
  END { for (k in seen) print k > NAMES }' "$tmp/pcmds"
# a function of the probe that has the name of a listed program would stand in for it
: > "$tmp/pshadow"
while IFS= read -r w; do [ "$w" != run_limited ] || continue; case "$PROBE_BUILTINS$PROBE_PLAIN$PROBE_PINNED" in *" $w "*) printf '%s\n' "$w" >> "$tmp/pshadow" ;; esac; done < "$tmp/padef"
pg_ok=0; [ ! -s "$tmp/punl" ] && [ ! -s "$tmp/pshadow" ] && [ ! -s "$tmp/pwnew" ] && [ ! -s "$tmp/pwgone" ] && [ "$pnc" -ge "$MIN_PROBE_CMDS" ] && pg_ok=1
rowif "device-probe.sh programs: $pnc commands in $pnl lines, $(lines "$tmp/pnames") names, unlisted commands $(lines "$tmp/punl"), functions with the name of a listed program $(lines "$tmp/pshadow"), writes: $pnw targets read, $(lines "$tmp/pwr") lines write outside /dev/null and \$T, pinned $pw of $(lines "$tmp/wpins"), not pinned $(lines "$tmp/pwnew"), pins without a line $(lines "$tmp/pwgone")" [ "$pg_ok" = 1 ]
[ ! -s "$tmp/punl" ] || { show < "$tmp/punl"; echo "    hint: the probe starts a program that no list names: a read command goes into PROBE_PLAIN, one whose arguments decide goes into PROBE_PINNED with its lines pinned, or it must go. (A trap whose action is not a function of the probe, - or exit N, a here-document with an odd delimiter or an expanded body and a vset that is not given digits are reported here too)"; }
[ ! -s "$tmp/pshadow" ] || sed 's/^/    function with the name of a listed program: /' "$tmp/pshadow"
[ ! -s "$tmp/pwnew" ] || { show < "$tmp/pwnew"; echo "    hint: the line writes to a place that is neither /dev/null nor a file below \$T, or sets T, OUT, A or B to one: the probe writes nowhere but its private directory"; }
[ ! -s "$tmp/pwgone" ] || { sed 's/^/    pin without a line: /' "$tmp/pwgone" | cut -c1-200; echo "    hint: a line that was allowed to write changed or went: change the list of writes in row 7d with it"; }

# 8 · §14.7 legal denylist: ONE implementation, tools/denylist-check.sh (lists tools/denylist*.txt).
# Its default run covers exactly the §14.7 files (page + both starchorus-display.sh) and contains the literal
# `grep -ciFf tools/denylist.txt …`; exit 0 = no hit, 1 = hits (file:line), 2 = setup problem or a
# missing list. A missing script fails too (sh exits 127).
sh tools/denylist-check.sh > "$tmp/dl" 2>&1; dl=$?
rowif "§14.7 denylist-check.sh (exit $dl, want 0)" [ "$dl" = 0 ]
[ "$dl" = 0 ] || show < "$tmp/dl"

exit $fail
