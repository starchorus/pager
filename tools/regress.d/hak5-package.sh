# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/hak5-package.sh -- the payload directory for Hak5's library (tools/hak5-package.sh), built into a temp dir.
# GUARDS AGAINST: a package that misses a file the payload needs at run time, or carries one it should not (tests, tools,
#                 fixtures, dev files); a packaged file that is not the repo's bytes (a stale or edited copy); a payload header
#                 without Title/Description/Author/Version/Category, a version that is not the page's, a category other than
#                 the directory's, a companion alert without its header or its bash shebang; a companion alert that writes
#                 anything but one line of times and addresses (a message, an upper-case address, a text that is no address),
#                 keeps more than 2,000 lines, or fails; personal data (an e-mail address, a home directory, a key) in any packaged file; a
#                 missing or altered LICENSE; a generator that leaves a stale file behind or writes despite differing
#                 Overview copies; a packaged payload that cannot install itself from its own directory.
# NEGATIVE PROBE: a file added to the generator's map, or the page packaged under its repo name => "file list" red; README.md
#                 source edited after the build => "byte-identical" red; the Category line changed => "header" red; the
#                 cmp guard removed from the generator => "refuses" red; pl_install removed from the payload => "installs" red.
#                 The companion alert: out of the map, not executable in the repo, an Author line or the licence line removed, another
#                 Version or shebang => "file list" / "header" red; its lower-casing, address test, message-free line, cap (a limit of
#                 2,001 or a tail of 1,999), umask, flock call or exit status changed => "companion alert" red (each tried on a copy).
# NOT PROVEN:     that Hak5 accepts the directory (their review is by hand); anything on the device; the payload's first-run
#                 install under BusyBox (payload-ui.sh runs it with stand-ins under sh/dash); the companion alert under the device's
#                 shell and its own flock or tail (the run here has a stand-in flock and the machine's other tools).
# Sourced by tools/regress.sh (T2) and tools/quick.sh (T1) with cwd = repo root; Chrome-free, no network. Sets only HKP_* names.

HKP_T=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-hkp.XXXXXX") || HKP_T=""
if [ -z "$HKP_T" ] || [ ! -d "$HKP_T" ]; then
  row "hak5 package: no temp directory" FAIL
else
HKP_REL=library/user/reconnaissance/starchorus
# the expected map, typed here on purpose (not read from the generator): packaged name = repo source
HKP_MAP="LICENSE=LICENSE
README.md=packaging/hak5/README.md
index.html=starchorus.html
payload.sh=$HKP_REL/payload.sh
starchorus-collect.sh=starchorus-collect.sh
starchorus-display.sh=$HKP_REL/starchorus-display.sh
starchorus-serve.sh=starchorus-serve.sh
alert-deauth.sh=$HKP_REL/alert-deauth.sh"
HKP_O="$HKP_T/out dir"; HKP_P="$HKP_O/$HKP_REL"
HKP_GO=$(cd / && sh "$R/tools/hak5-package.sh" "$HKP_O" 2>&1); HKP_RC=$?

# ---- 1 · the file list: exactly the eight files, nothing else in the tree, scripts executable, the generator's --list agrees
HKP_BAD=""
[ "$HKP_RC" = 0 ] || HKP_BAD="$HKP_BAD rc$HKP_RC"
HKP_HAVE=$(cd "$HKP_O" 2>/dev/null && find . -type f | sed 's#^\./##' | LC_ALL=C sort | tr '\n' ' ')
HKP_WANT=$(printf '%s\n' "$HKP_MAP" | sed "s#=.*##; s#^#$HKP_REL/#" | LC_ALL=C sort | tr '\n' ' ')
[ "$HKP_HAVE" = "$HKP_WANT" ] || HKP_BAD="$HKP_BAD files[$HKP_HAVE]"
HKP_DIRS=$(cd "$HKP_O" 2>/dev/null && find . -type d | LC_ALL=C sort | tr '\n' ' ')
[ "$HKP_DIRS" = ". ./library ./library/user ./library/user/reconnaissance ./library/user/reconnaissance/starchorus " ] || HKP_BAD="$HKP_BAD dirs"
for HKP_f in payload.sh starchorus-collect.sh starchorus-display.sh starchorus-serve.sh alert-deauth.sh; do [ -x "$HKP_P/$HKP_f" ] || HKP_BAD="$HKP_BAD noexec:$HKP_f"; done
# the package makes its scripts executable whatever the source's mode is, so the companion alert's own mode in the repo (what a commit carries) is looked at too
[ -x "$HKP_REL/alert-deauth.sh" ] || HKP_BAD="$HKP_BAD repo-noexec"
HKP_LS=$(sh tools/hak5-package.sh --list | tr '\t' '=' | LC_ALL=C sort)
[ "$HKP_LS" = "$(printf '%s\n' "$HKP_MAP" | LC_ALL=C sort)" ] || HKP_BAD="$HKP_BAD list"
case $HKP_HAVE in *test*|*fixture*|*tools*|*.py*|*.githooks*|*.github*) HKP_BAD="$HKP_BAD devfile" ;; esac
rowif "hak5 package: 8 files in $HKP_REL (the companion alert among them), nothing else, scripts executable (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]
[ "$HKP_RC" = 0 ] || printf '%s\n' "$HKP_GO" | sed 's/^/    /' | head -n 5

# ---- 2 · every packaged file is its repo source, byte for byte (the page as index.html)
HKP_BAD=""
HKP_IFS=$IFS; IFS='
'
for HKP_l in $HKP_MAP; do
  cmp -s "$HKP_P/${HKP_l%%=*}" "${HKP_l#*=}" || HKP_BAD="$HKP_BAD ${HKP_l%%=*}"
done
IFS=$HKP_IFS
cmp -s starchorus-display.sh "$HKP_P/starchorus-display.sh" || HKP_BAD="$HKP_BAD display-root"
rowif "hak5 package: every file byte-identical to its repo source (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

# ---- 3 · the payload header Hak5 asks for: Title, Description, Author, Version (= the page's), Category (= the directory's); the companion alert has the same
#           header without a Category (an alert payload sits in a category of the firmware's own), a bash shebang and the licence line
HKP_BAD=""
HKP_HD=$(head -n 15 "$HKP_P/payload.sh" 2>/dev/null)
HKP_PV=$(sed -n 's/^  version: "\([0-9][0-9A-Za-z.-]*\)",$/\1/p' starchorus.html | head -n 1)
for HKP_k in Title Description Author; do printf '%s\n' "$HKP_HD" | grep -q "^# $HKP_k: [^ ]" || HKP_BAD="$HKP_BAD $HKP_k"; done
[ "$(printf '%s\n' "$HKP_HD" | sed -n 's/^# Version: //p')" = "${HKP_PV:-none}" ] || HKP_BAD="$HKP_BAD Version"
[ "$(printf '%s\n' "$HKP_HD" | sed -n 's/^# Category: //p')" = reconnaissance ] || HKP_BAD="$HKP_BAD Category"
[ "$(sed -n 1p "$HKP_P/payload.sh" 2>/dev/null)" = "#!/bin/bash" ] || HKP_BAD="$HKP_BAD shebang"
printf '%s\n' "$HKP_HD" | grep -q '^# SPDX-License-Identifier: GPL-3.0-or-later$' || HKP_BAD="$HKP_BAD SPDX"
HKP_AH=$(head -n 15 "$HKP_P/alert-deauth.sh" 2>/dev/null)
for HKP_k in Title Description Author; do printf '%s\n' "$HKP_AH" | grep -q "^# $HKP_k: [^ ]" || HKP_BAD="$HKP_BAD alert-$HKP_k"; done
[ "$(printf '%s\n' "$HKP_AH" | sed -n 's/^# Version: //p')" = "${HKP_PV:-none}" ] || HKP_BAD="$HKP_BAD alert-Version"
[ "$(sed -n 1p "$HKP_P/alert-deauth.sh" 2>/dev/null)" = "#!/bin/bash" ] || HKP_BAD="$HKP_BAD alert-shebang"
printf '%s\n' "$HKP_AH" | grep -q '^# SPDX-License-Identifier: GPL-3.0-or-later$' || HKP_BAD="$HKP_BAD alert-SPDX"
rowif "hak5 package: payload header Title/Description/Author/Version $HKP_PV/Category reconnaissance, and the companion alert's header (bash shebang, no Category) (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

# ---- 4 · no personal data, no live-service default; the README says what Hak5's readers need; the LICENSE is the GPL
HKP_BAD=""
# e-mail addresses and keys case-insensitive; home directories case-sensitive (the page's comment "arrows/Home/End" is not one)
HKP_PD=$(($(cat "$HKP_P"/* 2>/dev/null | grep -ciE '[a-z0-9._%+-]+@[a-z0-9-]+\.[a-z]{2,}|PRIVATE KEY|api[_-]?key[ =:]+[a-z0-9]{8}') + $(cat "$HKP_P"/* 2>/dev/null | grep -cE '[/]Users[/]|[/]home[/][a-z]')))
[ "$HKP_PD" = 0 ] || HKP_BAD="$HKP_BAD personal:$HKP_PD"
HKP_URL=$(grep -ohE 'https?://[A-Za-z0-9.-]+' "$HKP_P/payload.sh" "$HKP_P/starchorus-serve.sh" | grep -cvE '^http://$|https?://<device-ip>' )
[ "$HKP_URL" = 0 ] || HKP_BAD="$HKP_BAD url:$HKP_URL"
HKP_RM="$HKP_P/README.md"
for HKP_s in 'https://github.com/starchorus/pager' 'not affiliated with, sponsored or endorsed by Hak5' 'trademarks of Hak5 LLC' \
  'GPL-3.0-or-later' '**Payloads**, then **Reconnaissance**, then **Starchorus**' 'never transmits' '## Network exposure' \
  '/root/loot/starchorus/settings.conf'; do
  grep -qF "$HKP_s" "$HKP_RM" 2>/dev/null || HKP_BAD="$HKP_BAD readme[$HKP_s]"
done
grep -qE '\]\((\.\./|[a-z-]+\.md|tools/|docs/)' "$HKP_RM" 2>/dev/null && HKP_BAD="$HKP_BAD readme-relative-link"
{ [ "$(sed -n 1p "$HKP_P/LICENSE" 2>/dev/null | tr -s ' ' | sed 's/^ //')" = "GNU GENERAL PUBLIC LICENSE" ] && grep -q 'Version 3, 29 June 2007' "$HKP_P/LICENSE"; } || HKP_BAD="$HKP_BAD license"
rowif "hak5 package: no personal data or remote URL, README complete, LICENSE = GPL v3 (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

# ---- 5 · the generator: a rebuild drops a stale file; differing Overview copies are refused and nothing is written
HKP_BAD=""
: > "$HKP_P/stale.txt"
(cd / && sh "$R/tools/hak5-package.sh" "$HKP_O" >/dev/null 2>&1) || HKP_BAD="$HKP_BAD rebuild"
[ ! -e "$HKP_P/stale.txt" ] || HKP_BAD="$HKP_BAD stale"
HKP_C="$HKP_T/copy"; mkdir -p "$HKP_C/tools" "$HKP_C/$HKP_REL" "$HKP_C/packaging/hak5"
for HKP_f in tools/hak5-package.sh starchorus-collect.sh starchorus.html starchorus-display.sh starchorus-serve.sh LICENSE \
  packaging/hak5/README.md "$HKP_REL/payload.sh" "$HKP_REL/starchorus-display.sh" "$HKP_REL/alert-deauth.sh"; do cp "$HKP_f" "$HKP_C/$HKP_f"; done
(cd / && sh "$HKP_C/tools/hak5-package.sh" "$HKP_T/ctl" >/dev/null 2>&1) || HKP_BAD="$HKP_BAD control"
printf '# drift\n' >> "$HKP_C/$HKP_REL/starchorus-display.sh"
(cd / && sh "$HKP_C/tools/hak5-package.sh" "$HKP_T/neg" >/dev/null 2>&1); HKP_NR=$?
{ [ "$HKP_NR" = 2 ] && [ ! -e "$HKP_T/neg/$HKP_REL" ]; } || HKP_BAD="$HKP_BAD refuses:rc$HKP_NR"
rm -f "$HKP_C/$HKP_REL/payload.sh"
(cd / && sh "$HKP_C/tools/hak5-package.sh" "$HKP_T/neg2" >/dev/null 2>&1); HKP_NR=$?
[ "$HKP_NR" = 2 ] || HKP_BAD="$HKP_BAD missing:rc$HKP_NR"
rowif "hak5 package: rebuild drops a stale file, differing Overview copies and a missing source refused (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

# ---- 6 · the packaged payload installs itself from its own directory: `get` and `set` (they start nothing) against an
#           empty data directory leave the four run-time files there, byte-identical and executable, and settings.conf beside them
HKP_BAD=""
HKP_L="$HKP_T/loot dir"
HKP_G=$(cd / && env -i PATH="$PATH" STARCHORUS_DIR="$HKP_L" sh "$HKP_P/payload.sh" get port 2>"$HKP_T/err"); HKP_RC=$?
[ "$HKP_RC/$HKP_G" = "0/port=8199 (default)" ] || HKP_BAD="$HKP_BAD get:$HKP_RC"
grep -q '^Starchorus: installed from ' "$HKP_T/err" || HKP_BAD="$HKP_BAD note"
for HKP_f in index.html starchorus-collect.sh starchorus-display.sh starchorus-serve.sh; do
  cmp -s "$HKP_P/$HKP_f" "$HKP_L/$HKP_f" || HKP_BAD="$HKP_BAD installs:$HKP_f"
done
for HKP_f in starchorus-collect.sh starchorus-display.sh starchorus-serve.sh; do [ -x "$HKP_L/$HKP_f" ] || HKP_BAD="$HKP_BAD noexec:$HKP_f"; done
[ "$(cd "$HKP_L" 2>/dev/null && find . -type f | LC_ALL=C sort | tr '\n' ' ')" = "./index.html ./starchorus-collect.sh ./starchorus-display.sh ./starchorus-serve.sh " ] || HKP_BAD="$HKP_BAD extra"
(cd / && env -i PATH="$PATH" STARCHORUS_DIR="$HKP_L" sh "$HKP_P/payload.sh" set port 8300 >/dev/null 2>"$HKP_T/err2") || HKP_BAD="$HKP_BAD set"
[ "$(cat "$HKP_L/settings.conf" 2>/dev/null)" = "port=8300" ] || HKP_BAD="$HKP_BAD settings"
[ ! -s "$HKP_T/err2" ] || HKP_BAD="$HKP_BAD reinstall"
[ ! -e "$HKP_P/settings.conf" ] || HKP_BAD="$HKP_BAD settings-in-payload-dir"
rowif "hak5 package: the packaged payload installs itself into an empty data dir, settings.conf there (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

# ---- 7 · the companion alert, run from the package with the variables of a stand-in event (synthetic addresses): one line of tab-separated fields in the order the collector
#           reads, addresses in lower case and "-" for what is no address or is not set, the message not written, the log private, the cap at 2,000 lines (1,999 stay,
#           the 2,001st drops the oldest), flock asked for once per event when it is there and not needed when it is not, exit 0 when the directory cannot be made.
#           The tools it may use are linked into a PATH of their own, so the run does not depend on the machine's flock.
HKP_BAD=""
HKP_AL="$HKP_P/alert-deauth.sh"; HKP_AD="$HKP_T/al dir"; HKP_AB="$HKP_T/albin"; HKP_FL="$HKP_T/flock.log"
mkdir -p "$HKP_AB"
for HKP_f in date tr wc tail mv mkdir rm; do ln -s "$(command -v "$HKP_f")" "$HKP_AB/$HKP_f"; done
hkp_ev() {   # hkp_ev DIR PATH [VAR=value ...]: one event, the way the firmware hands it over (the environment only); prints the exit status
  _hd=$1; _hp=$2; shift 2
  (cd / && env -i PATH="$_hp" STARCHORUS_DIR="$_hd" "$@" "$HKP_AL" >/dev/null 2>&1); echo $?
}
# shellcheck disable=SC2086   # HKP_EV1 is a list of VAR=value words on purpose
hkp_ev1() { hkp_ev "$1" "$2" $HKP_EV1; }   # hkp_ev1 DIR PATH: the stand-in event below
HKP_EV1="_ALERT=deauth_flood_detected _ALERT_DENIAL_MESSAGE=flood_from_02:00:5e:00:00:ee _ALERT_DENIAL_SOURCE_MAC_ADDRESS=AA:BB:CC:00:00:01 _ALERT_DENIAL_DESTINATION_MAC_ADDRESS=ff:ff:ff:ff:ff:ff _ALERT_DENIAL_AP_MAC_ADDRESS=02:00:5E:00:00:0A _ALERT_DENIAL_CLIENT_MAC_ADDRESS=not-a-mac"
HKP_T0=$(date +%s)
HKP_RC=$(hkp_ev1 "$HKP_AD" "$HKP_AB")
HKP_LG="$HKP_AD/alerts.log"; HKP_T1=$(date +%s)
[ "$HKP_RC" = 0 ] || HKP_BAD="$HKP_BAD rc$HKP_RC"
[ "$(wc -l < "$HKP_LG" 2>/dev/null | tr -d ' ')" = 1 ] || HKP_BAD="$HKP_BAD lines"
HKP_F=$(awk -F'\t' -v a="$HKP_T0" -v b="$HKP_T1" 'NF == 6 && $1 ~ /^[0-9]+$/ && $1 >= a && $1 <= b && $2 == "deauth" && $3 == "02:00:5e:00:00:0a" && $4 == "aa:bb:cc:00:00:01" && $5 == "ff:ff:ff:ff:ff:ff" && $6 == "-" { n++ } END { print n + 0 }' "$HKP_LG" 2>/dev/null)
[ "$HKP_F" = 1 ] || HKP_BAD="$HKP_BAD fields"
grep -qE 'flood|:ee' "$HKP_LG" 2>/dev/null && HKP_BAD="$HKP_BAD message"
[ "$(find "$HKP_LG" -perm 600 2>/dev/null)" = "$HKP_LG" ] || HKP_BAD="$HKP_BAD mode"
[ ! -e "$HKP_AD/alerts.lock" ] || HKP_BAD="$HKP_BAD lock-without-flock"
# nothing set at all: the time and four dashes
rm -f "$HKP_LG"
[ "$(hkp_ev "$HKP_AD" "$HKP_AB")" = 0 ] || HKP_BAD="$HKP_BAD rc-empty"
[ "$(awk -F'\t' 'NF == 6 && $1 ~ /^[0-9]+$/ && $2 == "deauth" && $3 == "-" && $4 == "-" && $5 == "-" && $6 == "-" { n++ } END { print n + 0 }' "$HKP_LG" 2>/dev/null)" = 1 ] || HKP_BAD="$HKP_BAD empty-event"
# the cap: 1,999 lines and one event make 2,000 with the oldest still there; one more event drops the oldest
awk 'BEGIN { for (i = 1; i <= 1999; i++) printf "%d\tdeauth\t02:00:00:00:00:01\t-\t-\t-\n", 1000000000 + i }' > "$HKP_LG"
hkp_ev1 "$HKP_AD" "$HKP_AB" >/dev/null; HKP_C1="$(wc -l < "$HKP_LG" | tr -d ' ')/$(sed -n 1p "$HKP_LG" | cut -f1)"
hkp_ev1 "$HKP_AD" "$HKP_AB" >/dev/null; HKP_C2="$(wc -l < "$HKP_LG" | tr -d ' ')/$(sed -n 1p "$HKP_LG" | cut -f1)/$(tail -n 1 "$HKP_LG" | cut -f3)"
[ "$HKP_C1" = 2000/1000000001 ] || HKP_BAD="$HKP_BAD cap1:$HKP_C1"
[ "$HKP_C2" = 2000/1000000002/02:00:5e:00:00:0a ] || HKP_BAD="$HKP_BAD cap2:$HKP_C2"
[ "$(cd "$HKP_AD" && find . -type f | tr '\n' ' ')" = "./alerts.log " ] || HKP_BAD="$HKP_BAD leftovers"
# flock where there is one: asked for once per event, as `flock -x 9`, and the line is written all the same
printf '#!/bin/sh\necho "flock $*" >> "%s"\nexit 0\n' "$HKP_FL" > "$HKP_AB/flock"; chmod +x "$HKP_AB/flock"; : > "$HKP_FL"; rm -f "$HKP_LG"
hkp_ev1 "$HKP_AD" "$HKP_AB" >/dev/null; hkp_ev1 "$HKP_AD" "$HKP_AB" >/dev/null
[ "$(cat "$HKP_FL")" = "$(printf 'flock -x 9\nflock -x 9')" ] || HKP_BAD="$HKP_BAD flock:$(tr '\n' '|' < "$HKP_FL")"
[ "$(wc -l < "$HKP_LG" | tr -d ' ')" = 2 ] || HKP_BAD="$HKP_BAD lines-with-flock"
[ -e "$HKP_AD/alerts.lock" ] || HKP_BAD="$HKP_BAD no-lockfile"
# a directory that cannot be made: exit 0, nothing written
: > "$HKP_T/afile"
[ "$(hkp_ev1 "$HKP_T/afile/sub" "$HKP_AB")" = 0 ] || HKP_BAD="$HKP_BAD rc-nodir"
rowif "hak5 package: the companion alert writes one line EPOCH deauth AP SOURCE DESTINATION CLIENT (lower-case addresses, - for a text that is none or unset, no message), private, keeps 2,000 lines, asks flock once per event, exits 0 (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

rm -rf "$HKP_T"
fi
