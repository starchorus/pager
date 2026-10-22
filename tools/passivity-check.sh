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
# read it, and what it deliberately names is a pinned line (file, function and text, each once). The rows above do not read it and no allowlist, regex or pin of theirs applies to it.
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
# Enclosing top-level shell function of every matching line; comment-only lines skipped. A one-line
# function `f() { …; }` does not open a scope, so hits there count as "outside" (conservative).
# FNDEF is the ONE definition of "a function head the scope check recognises" (shared by the scope awk and the
# fill probe below through ENVIRON, so the two cannot drift apart).
FNDEF='^[A-Za-z_][A-Za-z0-9_]*[ \t]*\([ \t]*\)[ \t]*\{?[ \t]*(#.*)?$'
export FNDEF
# shellcheck disable=SC2016   # awk program: $0 is awk's field, not a shell expansion
FNSCOPE='BEGIN { RE = ENVIRON["SCOPE_RE"]; DEF = ENVIRON["FNDEF"]; NORM = ENVIRON["SCOPE_NORM"] }
FNR == 1 { fn = "-" }
$0 ~ DEF { fn = $0; sub(/[ \t]*\(.*/, "", fn) }
{ l = $0
  if (NORM == "1") { gsub(/\\/, "", l); gsub(/"[ \t]+"/, "", l); gsub(/["\047]/, "", l) }   # the normal form: backslashes gone, string literals joined, quotes gone (hc\047\047itool, hc\itool, "hci" "tool" are hcitool)
  if (l ~ RE && $0 !~ /^[ \t]*#/) print FILENAME ":" FNR ":" fn ":" $0 }
/^}/ { fn = "-" }'
scoped() { # scoped ERE → "file:line:function:text" over $tmp/shfiles (ERE via ENVIRON: no awk -v escape mangling)
  while IFS= read -r _f; do SCOPE_RE=$1 SCOPE_NORM=0 awk "$FNSCOPE" "$_f"; done < "$tmp/shfiles"
}
scoped_n() { # the same, the hit read on the normal form of the line (the text printed is the line as it stands)
  while IFS= read -r _f; do SCOPE_RE=$1 SCOPE_NORM=1 awk "$FNSCOPE" "$_f"; done < "$tmp/shfiles"
}
# shellcheck disable=SC2016   # awk program
fnlist() { # "file:function" of every function head the scope check recognises, over $tmp/shfiles
  while IFS= read -r _f; do
    awk 'BEGIN { DEF = ENVIRON["FNDEF"] } $0 ~ DEF { fn = $0; sub(/[ \t]*\(.*/, "", fn); print FILENAME ":" fn }' "$_f"
  done < "$tmp/shfiles"
}

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
MIN_FNSCOPE=127  # functions recognised over the shell files: fnlist | wc -l  (measured 270; the floor is 0.1.1's 95 plus the 32 collector functions of the radio pair)
fnlist > "$tmp/fns"
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
d=$(grep -cF 'ALLOW_ACTIVE=${STARCHORUS_ALLOW_ACTIVE:-0}' starchorus-collect.sh)
# shellcheck disable=SC2016
g=$(awk '/^build_from_iwscan\(\)[ \t]*\{/{getline; print; exit}' starchorus-collect.sh | grep -cF '[ "$ALLOW_ACTIVE" = "1" ] || return 1')
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
scoped '.' > "$tmp/code"           # every code line with its function, for the rows that read whole lines
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
# rows 5 and 6 · simple commands, read one at a time (BTSEG): the line is masked (blanks and separators inside quotes are text), cut at ;
# & | ( ) and backticks, and at $( ; keywords (then do else if ...) and `VAR=value` prefixes are dropped; what is left starts with the
# command word. wrap = in every function of BT_FUNCS: no wrapper of BT_WRAP_RE, no command word that is a `$` expansion (`$VAR`, `$(...)`, a backtick
# expression, quoted or not), no glob in a command word, no `timeout` outside bt_begin. cmdpos = in bt_stub and bt_selftest: no tool word of the stack as the command word (also after `timeout [-s SIG] N`,
# quoted, or with a path in front). The body of a here-document is text and is skipped (its first line, the command, is read).
# dyn = row 6d, over every line of every shell file of the scope, functions and top level alike (BT_SEG_FNS is `*`): it does not use mask() and cmds() above but reads the raw
# text with a stack of its own (dyn() below) and lists each simple command whose command word holds an expansion; the row compares what it lists with a pinned list.
# shellcheck disable=SC2016   # awk program
BTSEG='BEGIN { WRAP = ENVIRON["BT_WRAP_RE"]; CMDW = ENVIRON["BT_CMD_RE"]; MODE = ENVIRON["BT_MODE"]; FNS = ENVIRON["BT_SEG_FNS"]; CMDS = ENVIRON["BT_CMDS"] }
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
function darg(   a) {   # a word that is an argument of the simple command being read (dcmd = its name): `find ... -exec` and its three kin, `alias NAME=...`
  if (dcmd == "") return
  a = dtok; gsub(/["\047\\]/, "", a)
  if (dcmd == "find" && a ~ /^-(exec|execdir|ok|okdir)$/) dbad2 = 1
  else if (dcmd == "alias" && index(a, "=") > 0) dbad2 = 1
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
# expansion or a glob are left to rows 6d and 6e. A case pattern (`a|b) ...`) is read like a command word until the `)` shows what it was: the names recorded since the last `;`, `&` or line start are then dropped.
function rec(nm) { if (CMDS != "" && !dtexp && !dtglob) REC[++nrec] = nm }
function dxend() { if (dwr && dwc == "xargs") { dbad2 = 1; dwr = 0 } }   # `xargs` with no command of its own: it runs echo over what it reads (with -I its command would come from stdin)
function dfin(   dn) {   # the token that has just ended
  if (!dint) return
  dint = 0
  if (drd) { drd = 0; return }
  if (!dtcs) { darg(); return }
  dn = dtok; gsub(/["\047\\]/, "", dn)   # quotes and backslashes in a name do not hide it (a quoted find, a split exec, a backslash before xargs)
  if (dwr) {
    if (dsk) { dsk = 0; return }
    if (dwc == "xargs" && dxarg(dn)) return
    if (dtok ~ /^-[vV]$/ && dwc == "command") { dcs = 0; dwr = 0; return }
    if (dtok ~ /^-[nsk]$/) { dsk = 1; return }
    if (dtok ~ /^-/) return
    if (dwc == "timeout" && !dwd) { dwd = 1; return }
    if (dwc == "xargs" && (index(dn, "{}") > 0 || (dxr != "" && index(dn, dxr) > 0))) dbad2 = 1   # the command is the replacement string: it comes from stdin
    dwr = 0
  }
  if (dtok ~ /^(then|do|else|elif|if|while|until|!|\{|\})$/) return
  if (dn ~ /^(exec|command|nohup|setsid|nice|env|time|xargs|busybox|timeout|sudo|stdbuf)$/) { rec(dn); dwr = 1; dwc = dn; dwd = 0; dsk = 0; if (dn == "xargs") { dxo = ""; dxr = ""; dxe = 0 }; return }
  if (dtok ~ /^[A-Za-z_][A-Za-z0-9_]*=/) return
  if (dtok ~ /^[0-9]*[<>]/) { if (dtok ~ /^[0-9]*(>>|>[|]|>&|<&|<|>)$/) drd = 1; return }
  if (dtexp) dbad = 1
  if (dtglob && dtok !~ /^\[\[?$/) dbad2 = 1   # a glob in the command word: the name is whatever the directory holds when the line runs (`[` and `[[` are the test)
  rec(dn); sub(/^.*\//, "", dn); dcmd = dn
  dcs = 0; dwr = 0
}
function dpush(ty) { DST[++dsp] = ty; DSI[dsp] = dint; DSC[dsp] = dtcs; DSK[dsp] = dtok; DSE[dsp] = dtexp; DSS[dsp] = dcs; DSG[dsp] = dtglob; DSM[dsp] = dcmd; dcmd = "" }
function dpop() { dint = DSI[dsp]; dtcs = DSC[dsp]; dtok = DSK[dsp]; dtexp = DSE[dsp]; dcs = DSS[dsp]; dtglob = DSG[dsp]; dcmd = DSM[dsp]; dsp-- }
function dtext(c) { if (!dint) { dint = 1; dtcs = dcs; dtok = ""; dtexp = 0; dtglob = 0 } dtok = dtok c }
function dreset() { dcs = 1; dint = 0; dtcs = 0; dtok = ""; dtexp = 0; dtglob = 0; drd = 0; dwr = 0; dsk = 0; dwd = 0; dsp = 0; dcmd = ""; dxo = ""; dxr = ""; dxe = 0 }
function dyn(t,   i, n, c, top, bsep, bsep2, u, nx) {
  n = length(t); dbad = 0; dbad2 = 0; bsep = 0; bsep2 = 0; DCONT = 0; DHDW = ""; nrec = 0; rmark = 0
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
    if (top == "d") { dtext(c); continue }
    if (c == "\047") { dtext(c); DST[++dsp] = "q"; continue }
    if (c == "\"") { dtext(c); DST[++dsp] = "d"; continue }
    if (c == "#" && !dint) break
    if (c == " " || c == "\t") { dfin(); continue }
    if (c == ";" || c == "|" || (c == "&" && substr(t, i - 1, 1) !~ /[<>]/)) { dfin(); dxend(); drd = 0; dwr = 0; dcs = 1; if (c != "|") { bsep = dbad; bsep2 = dbad2; rmark = nrec }; continue }
    if (c == "<" && nx == "<" && substr(t, i + 2, 1) == "<") { dtext("<<<"); i += 2; continue }
    if (c == "<" && nx == "<") {   # a here-document: its delimiter word, for the caller
      u = substr(t, i + 2); DHDD = (substr(u, 1, 1) == "-"); if (DHDD) u = substr(u, 2)
      sub(/^[ \t]+/, "", u); sub(/^["\047]/, "", u); sub(/[^A-Za-z0-9_].*$/, "", u)
      if (u ~ /^[A-Za-z_]/) DHDW = u
      dtext("<<"); i++; continue }
    if (c == "(") { fdef = (nx == ")" && dint && dtcs); n0 = nrec; dfin(); if (fdef && nrec == n0 + 1) nrec--; dpush("P"); dint = 0; dcs = 1; continue }   # `name()` defines a function: the name is not a command
    if (c == ")") {
      dfin(); dxend()
      if (dsp == 0) { nrec = rmark; dbad = bsep; dbad2 = bsep2; dcs = 1; continue }   # a `)` that closes nothing ends a case pattern: its words are no commands
      if (top == "S") { dpop(); dtext(")"); continue }
      dsp--; dcs = 1; continue }
    dtext(c); if (index("*?[", c) > 0) dtglob = 1
  }
  top = (dsp > 0) ? DST[dsp] : ""
  if (top != "q" && top != "d") { dfin(); if (!DCONT && top != "A" && top != "a") { dxend(); dcs = 1; drd = 0; dwr = 0 } }   # a newline ends a simple command, unless it is escaped or inside a quote
  return dbad
}
{ fn = $0; sub(/^[^:]*:[^:]*:/, "", fn); sub(/:.*/, "", fn)
  if (FNS != "*" && index(FNS, " " fn " ") == 0) next
  t = $0; for (k = 0; k < 3; k++) t = substr(t, index(t, ":") + 1)
  if (MODE == "dyn") { fl = $0; sub(/:.*/, "", fl); if (fl != curfile || fn != dfn) { curfile = fl; dfn = fn; dreset() } }   # a new file or function starts with nothing open
  if (fn != hdfn) hd = ""
  if (hd != "") { u = t; if (hddash) sub(/^\t+/, "", u); if (u == hd) hd = ""; next }   # the body of a here-document is text, not a command of the function
  nread++
  if (MODE == "dyn") {
    if (dyn(t)) print $0 > BAD
    if (dbad2) print $0 > BAD2
    if (CMDS != "") for (j = 1; j <= nrec; j++) print REC[j] "\t" $0 > CMDS
    if (DHDW != "") { hd = DHDW; hdfn = fn; hddash = DHDD }
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
# BT_FUNCS. This row reads every code line of every shell file of the scope (BTSEG, mode dyn) and lists each simple command whose COMMAND WORD holds an expansion: `$VAR`,
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
: > "$tmp/dyn_bad"; : > "$tmp/dyn_n"; : > "$tmp/dyn_new"; : > "$tmp/dyn_gone"
: > "$tmp/dyn_bad2"
BT_WRAP_RE='' BT_CMD_RE='' BT_MODE=dyn BT_SEG_FNS='*' awk -v BAD="$tmp/dyn_bad" -v BAD2="$tmp/dyn_bad2" -v NREAD="$tmp/dyn_n" "$BTSEG" "$tmp/code"
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
# A pin is an exact line, never a pattern. Row 'named tools': the union of every line that a denylist hits, that holds a built command word (6d) or a glob (6e), or whose command is one of PROBE_PINNED, must
# be a pinned line, and every pin must have its line. Row 'programs': every simple command the probe starts is a function of the probe itself, a builtin or keyword (PROBE_BUILTINS), a plain read-only
# program (PROBE_PLAIN) or one of PROBE_PINNED (whose lines are pinned); any other name, a path or a `.` is an unlisted command. Not read, as for the other scripts: a program text that is built and
# then run, and what an awk or sed program does with its text (review; the run rows of tools/regress.d/device-probe.sh show what the probe does on a machine).
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
PPINS
grep -v '^##' "$tmp/ppins0" | sed "s|^|$PROBE:|" > "$tmp/ppins"
PROBE_BUILTINS=' : [ break case cd command continue done echo esac exit fi for printf read return set shift trap umask wait '
PROBE_PLAIN=' awk cat cut date df grep head jq ls readlink sed sleep sort stat tail tr uname wc '
PROBE_PINNED=' busybox chmod cp find flock iw kill mkdir mktemp rm run_limited sh sqlite3 timeout '
MIN_PROBE_FNS=32       # function heads of the probe that the scope check recognises (measured: 36; the one-line functions are not heads)
MIN_PROBE_LINES=800    # code lines of the probe that the rows read (measured: 949)
MIN_PROBE_CMDS=800     # simple commands of the probe whose name the pass records (measured: 969)
pscoped() { [ -f "$PROBE" ] || return 0; SCOPE_RE=$1 SCOPE_NORM=0 awk "$FNSCOPE" "$PROBE"; }
pscoped_n() { [ -f "$PROBE" ] || return 0; SCOPE_RE=$1 SCOPE_NORM=1 awk "$FNSCOPE" "$PROBE"; }
pscoped '.' > "$tmp/pcode"
: > "$tmp/pdyn_bad"; : > "$tmp/pdyn_bad2"; : > "$tmp/pdyn_n"; : > "$tmp/pcmds"
BT_WRAP_RE='' BT_CMD_RE='' BT_MODE=dyn BT_SEG_FNS='*' BT_CMDS="$tmp/pcmds" awk -v BAD="$tmp/pdyn_bad" -v BAD2="$tmp/pdyn_bad2" -v NREAD="$tmp/pdyn_n" "$BTSEG" "$tmp/pcode"
# the functions the probe defines (the heads `name() {` and the one-line forms: a call of any of them is not an unlisted command), the function heads that the scope check recognises (they give the pins their
# function), and the lines whose command is one of PROBE_PINNED
{ [ ! -f "$PROBE" ] || awk '/^[ \t]*#/ { next } /^[A-Za-z_][A-Za-z0-9_]*[ \t]*\([ \t]*\)/ { f = $0; sub(/[ \t]*\(.*/, "", f); print f }' "$PROBE"; } | LC_ALL=C sort -u > "$tmp/pfn"
{ [ ! -f "$PROBE" ] || awk 'BEGIN { DEF = ENVIRON["FNDEF"] } $0 ~ DEF { f = $0; sub(/[ \t]*\(.*/, "", f); print f }' "$PROBE"; } | LC_ALL=C sort -u > "$tmp/pheads"
awk -F'\t' -v PI="$PROBE_PINNED" '{ n = $1; sub(/^[^\t]*\t/, ""); if (index(PI, " " n " ") > 0) print }' "$tmp/pcmds" > "$tmp/pprog"
pscoped_n "$SEC6_RE" > "$tmp/p_sec6"
pscoped_n "$TX_RE" > "$tmp/p_tx"
pscoped_n "$BT_RE" > "$tmp/p_bt"
pscoped_n "$PNET_RE" > "$tmp/p_net"
pscoped_n '(^|[^A-Za-z_])iw([[:space:]]+dev[[:space:]]+[^[:space:]|;]+)?[[:space:]]+scan([^A-Za-z_]|$)' > "$tmp/p_scan"   # the test of the row 'iw scan opt-in only', same text
pscoped_n '(^|[^A-Za-z0-9_-])sqlite3([^A-Za-z0-9_]|$)' > "$tmp/p_sq"
: > "$tmp/ph0"; for _f in p_sec6 p_tx p_bt p_net p_scan p_sq pdyn_bad pdyn_bad2 pprog; do cat "$tmp/$_f" >> "$tmp/ph0"; done
awk '!seen[$0]++' "$tmp/ph0" > "$tmp/ph"
: > "$tmp/pnew"; : > "$tmp/pgone"
pp=$(pin_cmp "$tmp/ph" "$tmp/ppins" "$tmp/pnew" "$tmp/pgone" 1)
pn_ok=0; [ ! -s "$tmp/pnew" ] && [ ! -s "$tmp/pgone" ] && pn_ok=1
# the fill of this part: a probe that lost its function heads, or a pass that reads less, would turn the rows green by looking at less
pnfn=$(lines "$tmp/pheads"); pnl=$(lines "$tmp/pcode"); pnc=$(lines "$tmp/pcmds"); pmiss=""
[ -f "$PROBE" ] || pmiss="$pmiss $PROBE(no such file)"
for w in sq run_limited cleanup sect_alertenv main; do grep -qxF "$w" "$tmp/pheads" || pmiss="$pmiss $w()"; done
pfok=0; [ "$pnfn" -ge "$MIN_PROBE_FNS" ] && [ "$pnl" -ge "$MIN_PROBE_LINES" ] && [ "$pnc" -ge "$MIN_PROBE_CMDS" ] && [ -z "$pmiss" ] && pfok=1
rowif "device-probe.sh scope fill: $pnfn functions (≥ $MIN_PROBE_FNS), $pnl code lines (≥ $MIN_PROBE_LINES), $pnc commands read (≥ $MIN_PROBE_CMDS), unseen:${pmiss:- none}" [ "$pfok" = 1 ]
rowif "device-probe.sh named tools: $(lines "$tmp/ph") lines hold one (sending $(lines "$tmp/p_tx"), Bluetooth $(lines "$tmp/p_bt"), network $(lines "$tmp/p_net"), device call $(lines "$tmp/p_sec6"), iw scan $(lines "$tmp/p_scan"), sqlite3 $(lines "$tmp/p_sq"), built name $(lines "$tmp/pdyn_bad"), glob $(lines "$tmp/pdyn_bad2"), program $(lines "$tmp/pprog")), pinned $pp of $(lines "$tmp/ppins"), not pinned $(lines "$tmp/pnew"), pins without a line $(lines "$tmp/pgone")" [ "$pn_ok" = 1 ]
[ ! -s "$tmp/pnew" ] || { show < "$tmp/pnew"; echo "    hint: the line names a tool or starts a program: if that is meant, read it and add it (function:text) with its reason to the pinned list of row 7d"; }
[ ! -s "$tmp/pgone" ] || { sed 's/^/    pin without a line: /' "$tmp/pgone" | cut -c1-200; echo "    hint: a pinned line changed or went: change the pinned list of row 7d with it"; }
# programs: the name of every simple command, against the lists
: > "$tmp/punl"; : > "$tmp/pnames"
LC_ALL=C awk -F'\t' -v FNL="$(tr '\n' ' ' < "$tmp/pfn")" -v BI="$PROBE_BUILTINS" -v PL="$PROBE_PLAIN" -v PI="$PROBE_PINNED" -v UNL="$tmp/punl" -v NAMES="$tmp/pnames" '
  BEGIN { nf = split(FNL, fa, " "); for (i = 1; i <= nf; i++) fn[fa[i]] = 1 }
  { n = $1; r = $0; sub(/^[^\t]*\t/, "", r); seen[n]++
    if (index(PI, " " n " ") > 0 || index(BI, " " n " ") > 0 || index(PL, " " n " ") > 0 || (n in fn)) next
    print r > UNL }
  END { for (k in seen) print k > NAMES }' "$tmp/pcmds"
# a function of the probe that has the name of a listed program would stand in for it
: > "$tmp/pshadow"
while IFS= read -r w; do [ "$w" != run_limited ] || continue; case "$PROBE_BUILTINS$PROBE_PLAIN$PROBE_PINNED" in *" $w "*) printf '%s\n' "$w" >> "$tmp/pshadow" ;; esac; done < "$tmp/pfn"
pg_ok=0; [ ! -s "$tmp/punl" ] && [ ! -s "$tmp/pshadow" ] && [ "$pnc" -ge "$MIN_PROBE_CMDS" ] && pg_ok=1
rowif "device-probe.sh programs: $pnc commands in $pnl lines, $(lines "$tmp/pnames") names, unlisted commands $(lines "$tmp/punl"), functions with the name of a listed program $(lines "$tmp/pshadow")" [ "$pg_ok" = 1 ]
[ ! -s "$tmp/punl" ] || { show < "$tmp/punl"; echo "    hint: the probe starts a program that no list names: a read command goes into PROBE_PLAIN, one whose arguments decide goes into PROBE_PINNED with its lines pinned, or it must go"; }
[ ! -s "$tmp/pshadow" ] || sed 's/^/    function with the name of a listed program: /' "$tmp/pshadow"

# 8 · §14.7 legal denylist: ONE implementation, tools/denylist-check.sh (lists tools/denylist*.txt).
# Its default run covers exactly the §14.7 files (page + both starchorus-display.sh) and contains the literal
# `grep -ciFf tools/denylist.txt …`; exit 0 = no hit, 1 = hits (file:line), 2 = setup problem or a
# missing list. A missing script fails too (sh exits 127).
sh tools/denylist-check.sh > "$tmp/dl" 2>&1; dl=$?
rowif "§14.7 denylist-check.sh (exit $dl, want 0)" [ "$dl" = 0 ]
[ "$dl" = 0 ] || show < "$tmp/dl"

exit $fail
