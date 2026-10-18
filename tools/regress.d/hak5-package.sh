# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/hak5-package.sh -- the payload directory for Hak5's library (tools/hak5-package.sh), built into a temp dir.
# GUARDS AGAINST: a package that misses a file the payload needs at run time, or carries one it should not (tests, tools,
#                 fixtures, dev files); a packaged file that is not the repo's bytes (a stale or edited copy); a payload header
#                 without Title/Description/Author/Version/Category, a version that is not the page's, a category other than
#                 the directory's; personal data (an e-mail address, a home directory, a key) in any packaged file; a
#                 missing or altered LICENSE; a generator that leaves a stale file behind or writes despite differing
#                 Overview copies; a packaged payload that cannot install itself from its own directory.
# NEGATIVE PROBE: a file added to the generator's map, or the page packaged under its repo name => "file list" red; README.md
#                 source edited after the build => "byte-identical" red; the Category line changed => "header" red; the
#                 cmp guard removed from the generator => "refuses" red; pl_install removed from the payload => "installs" red.
# NOT PROVEN:     that Hak5 accepts the directory (their review is by hand); anything on the device; the payload's first-run
#                 install under BusyBox (payload-ui.sh runs it with stand-ins under sh/dash).
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
starchorus-serve.sh=starchorus-serve.sh"
HKP_O="$HKP_T/out dir"; HKP_P="$HKP_O/$HKP_REL"
HKP_GO=$(cd / && sh "$R/tools/hak5-package.sh" "$HKP_O" 2>&1); HKP_RC=$?

# ---- 1 · the file list: exactly the seven files, nothing else in the tree, scripts executable, the generator's --list agrees
HKP_BAD=""
[ "$HKP_RC" = 0 ] || HKP_BAD="$HKP_BAD rc$HKP_RC"
HKP_HAVE=$(cd "$HKP_O" 2>/dev/null && find . -type f | sed 's#^\./##' | LC_ALL=C sort | tr '\n' ' ')
HKP_WANT=$(printf '%s\n' "$HKP_MAP" | sed "s#=.*##; s#^#$HKP_REL/#" | LC_ALL=C sort | tr '\n' ' ')
[ "$HKP_HAVE" = "$HKP_WANT" ] || HKP_BAD="$HKP_BAD files[$HKP_HAVE]"
HKP_DIRS=$(cd "$HKP_O" 2>/dev/null && find . -type d | LC_ALL=C sort | tr '\n' ' ')
[ "$HKP_DIRS" = ". ./library ./library/user ./library/user/reconnaissance ./library/user/reconnaissance/starchorus " ] || HKP_BAD="$HKP_BAD dirs"
for HKP_f in payload.sh starchorus-collect.sh starchorus-display.sh starchorus-serve.sh; do [ -x "$HKP_P/$HKP_f" ] || HKP_BAD="$HKP_BAD noexec:$HKP_f"; done
HKP_LS=$(sh tools/hak5-package.sh --list | tr '\t' '=' | LC_ALL=C sort)
[ "$HKP_LS" = "$(printf '%s\n' "$HKP_MAP" | LC_ALL=C sort)" ] || HKP_BAD="$HKP_BAD list"
case $HKP_HAVE in *test*|*fixture*|*tools*|*.py*|*.githooks*|*.github*) HKP_BAD="$HKP_BAD devfile" ;; esac
rowif "hak5 package: 7 files in $HKP_REL, nothing else, scripts executable (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]
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

# ---- 3 · the payload header Hak5 asks for: Title, Description, Author, Version (= the page's), Category (= the directory's)
HKP_BAD=""
HKP_HD=$(head -n 15 "$HKP_P/payload.sh" 2>/dev/null)
HKP_PV=$(sed -n 's/^  version: "\([0-9][0-9A-Za-z.-]*\)",$/\1/p' starchorus.html | head -n 1)
for HKP_k in Title Description Author; do printf '%s\n' "$HKP_HD" | grep -q "^# $HKP_k: [^ ]" || HKP_BAD="$HKP_BAD $HKP_k"; done
[ "$(printf '%s\n' "$HKP_HD" | sed -n 's/^# Version: //p')" = "${HKP_PV:-none}" ] || HKP_BAD="$HKP_BAD Version"
[ "$(printf '%s\n' "$HKP_HD" | sed -n 's/^# Category: //p')" = reconnaissance ] || HKP_BAD="$HKP_BAD Category"
[ "$(sed -n 1p "$HKP_P/payload.sh" 2>/dev/null)" = "#!/bin/bash" ] || HKP_BAD="$HKP_BAD shebang"
printf '%s\n' "$HKP_HD" | grep -q '^# SPDX-License-Identifier: GPL-3.0-or-later$' || HKP_BAD="$HKP_BAD SPDX"
rowif "hak5 package: payload header Title/Description/Author/Version $HKP_PV/Category reconnaissance (bad:${HKP_BAD:- none})" [ -z "$HKP_BAD" ]

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
  packaging/hak5/README.md "$HKP_REL/payload.sh" "$HKP_REL/starchorus-display.sh"; do cp "$HKP_f" "$HKP_C/$HKP_f"; done
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

rm -rf "$HKP_T"
fi
