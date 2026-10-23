#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/passivity-mutate.sh -- proves that every rule family of tools/passivity-check.sh can turn red.
# usage: sh tools/passivity-mutate.sh [--only NAME|alts] [--meta]      (any cwd; dev machine; sends nothing, opens no socket)
#   (default)    unmutated copy first (must be exit 0), then one FRESH copy per mutation with exactly ONE changed/added
#                line; the set of red rows must equal the pinned set; then the alternative probe (below).
#                Exit 0 = every line below matches, 1 = a miss, 2 = setup.
#   --only NAME  one mutation (used by --meta and for debugging); --only alts = the alternative probe alone
#   --meta       the probe of the probe: blinds one rule family, or ONE alternative of one, in an image of the checker and
#                demands that THIS script then reports GREEN (BLIND!) for the matching mutation / alternative.
# Alternative probe: the regex families of the checker (`--regexes`: NETSURF_RE, NETX, TX_WORDS, IW_VERBS, SEC6_RE, BT_WORDS, BT_WRAP_RE, PNET_WORDS)
# are split at their top-level `|`, DERIVED from the checker, not typed here. Every alternative needs exactly one planted sample in the
# table `alt` below (sample matches its own alternative and no other; count of alternatives pinned as MIN_ALTS_*): all
# samples of one file go in one copy, one checker run, and each must show up as its own line in the evidence of the expected
# row (the checker prints the offending lines under a red row). A thinned-out alternative is then `GREEN (BLIND!)`, a new
# or renamed one `UNCOVERED`, a table entry nobody's regex contains `ORPHAN`.
#
# GUARDS AGAINST: a rule of passivity-check.sh whose regex drifted (e.g. an object-prefixed `document.location = ...` that NETX
#                 does not match), was emptied, or lost ONE alternative (importScripts, hostapd, DEAUTH, sendBeacon ...) stays
#                 green forever, because nothing ever plants a violation.
# NEGATIVE PROBE: `sh tools/passivity-mutate.sh --meta` (also a regress row): NETX loses `window\.open\(|`, or the location
#                 alternative loses its object prefix, or one alternative of NETX/TX_WORDS/SEC6_RE/NETSURF_RE/BT_WORDS/BT_WRAP_RE
#                 goes, or the sqlite3 rule reads the whole line again, or one of the Bluetooth rows (tool words outside the
#                 allowlist, the lines of bt_begin, word forms, wrappers, command position, the pinned apcli_ro lines) stops
#                 reading what it reads ⇒ the matching mutation/alternative prints GREEN (BLIND!), exit 1. The row of the built names (command
#                 word from an expansion, §14.6d) is blinded one part at a time too: the row itself, the detection of an expansion in a command
#                 word, the wrapper words, the report of a line that is not pinned, the report of a pin without a line.
# BUILT NAMES:    the row '§14.6d command words from an expansion' reads every code line of the shell scope and lists each simple command whose command word
#                 holds an expansion, against a pinned list of the lines that stand. The `dyn-` mutations plant what it reads (the review's plant, in which a
#                 function outside the Bluetooth allowlist puts `hci` and `tool` together and starts the result, and every form of an expansion in a command word)
#                 and what it compares (an edited pinned line, a vanished one, a copy of one); the `dyn-ok-` controls and the two `dyn-limit-` controls must stay green:
#                 what the row does not read (a built string handed to eval or to an awk system()) is written down as a test.
# BUILT NAMES, THE SECOND ROW: '§14.6e command names from a glob, find -exec, xargs or alias' is the second verdict of the same pass. The `dyn-glob`, `dyn-glob-star`, `dyn-bracket` and
#                 `dyn-iw-glob` mutations plant a glob character in a command word, the `dyn-find-` ones `find` with each of `-exec`, `-execdir`, `-ok` and `-okdir`, the `dyn-xargs-` ones an
#                 `xargs` whose command is its replacement string (`{}` and one of its own) or is missing, `dyn-alias` an alias; the `dyn-ok-` controls (a glob in a for-list, a case pattern
#                 or as an argument, the test `[ ]`, a `${ }` with a blank or a parenthesis, `find` without `-exec`, `xargs` with its own command, an `alias` that only looks) and the two
#                 `dyn-limit-` ones that were added (a glob only handed to `ln`, a built string piped into `sh`) must stay green: the limits are written down as tests.
# DEVICE PROBE:   tools/device-probe.sh runs on the device and is in the scope of the checker with three rows of its own ('device-probe.sh scope fill', 'named tools', 'programs'; row 7d there). The `probe-`
#                 mutations plant into a copy of the probe what the rows read: a sending, scanning, Bluetooth or network tool (also in a function that has the name of an allowlisted function of the collector), an
#                 `iw` that sets something, a built or globbed command word, a program no list names, a function with the name of a listed program, and the pinned lines (one changed by one character, one gone, one
#                 copied into another function); `probe-pin-in-collector` shows that a pin of the probe does not cover the same line in the collector, and `probe-limit-collector-curl` that the collector is
#                 not read for the network words (they belong to the probe only). The `probe-ok-` controls (read commands, calls of its own functions, a comment, a case pattern, builtins) stay green. Every part of
#                 the probe rows is blinded once in the meta probe, and the family PNET_WORDS has a sample per alternative (`alt pnet`).
# DEVICE PROBE, WRITES: the row 'device-probe.sh programs' also holds that the probe writes nowhere but its private directory. The `probe-redirect-` mutations plant every spelling of a redirection that leaves /dev/null and `$T`
#                 (glued to the word before it, a descriptor number, `9>`, `>|`, `<>`, inside `$( )` bare and quoted, after a group, with `..` in the path, to a variable), `probe-append-etc` the `>>` into /etc, `probe-cp-root` and
#                 `probe-cp-option-t` the destination of cp (`tee` and `mv` are unlisted programs, so `probe-tee-etc` and `probe-mv-etc` are red by the list of programs as well), `probe-assign-` the assignment of T and OUT to
#                 another place, `probe-for-var` and `probe-read-var` a `for` or `read` that names a variable of the row, and `probe-write-pin-gone` an exception of the row that vanishes. `date -s`, `sed -i`, `sort -o` and a pinned sed
#                 command given a file on its next line are planted too (`probe-date-set`, `probe-sed-inplace`, `probe-sort-output`, `probe-sed-continued`): those programs are pinned, so any new line of them is red. `probe-command-function`
#                 is the top-level function `mv() { command mv "$@"; }` with a call, `probe-case-pipeline` and `probe-case-pipeline-alt` a command before a `case` on the same line (its `)` drops nothing),
#                 `probe-case-stray-paren` a `)` that closes no case item at all (not valid shell, never run: it drops nothing either). These plant
#                 `mv`, which the write rule also reds (its destination is outside `$T`), so the `-read` variants (and the stray `)`) plant `od`, an unlisted program that writes nothing, and the meta probe blinds against those. The controls
#                 `probe-ok-redirects`, `probe-ok-assign`, `probe-ok-command-v`, `probe-ok-case-lines` (a pattern at the start of a line in an open case, one inside an item) and `probe-ok-case-fallthrough` stay green;
#                 `probe-limit-awk-write` writes down that an awk program is not read. The `;&` of the fallthrough control shares one expression with `;;` in the checker, so only the pair is blinded.
# DEVICE PROBE, THE READER: the row 'device-probe.sh programs' also reads what the probe hands to the shell as a string or hides from the reader. The `probe-trap-` mutations plant the actions of a `trap` that run a string (an `iw` that sets a type,
#                 an `iw ... del`, an `sh -c`, a `date -s`, a `rm -rf`, a `mv` with a write behind it, a program by name, an expansion, an `exit` with more behind it, `command trap`, `trap --`, a trap inside `$( )`); the control `probe-ok-trap` (a function of the
#                 probe, `exit N`, `-`, an empty string) stays green. `probe-case-nested-subshell`, `-subst` and `-backtick` plant a case inside `( )`, `$( )` and backticks on a body line of an open case item (its pattern `)` used to pop the group, and
#                 the `)` after `esac` dropped every name of the line), `probe-case-built-` a built command word before such a case, inside `( )` or inside `$( )` or backticks (the flags a line had before the item began stay); the controls
#                 `probe-ok-case-nested` and `probe-ok-case-nested-lines` stay green. `probe-redirect-expansion`, `probe-redirect-arg`, `probe-assign-out-expansion`, `probe-assign-b-arg` and `probe-cp-expansion` plant an expansion after `$T/` (the sample
#                 `printf v > "$T/v.$1"` of the control `probe-ok-redirects` is `probe-redirect-arg` now, and the control has a literal name); `probe-write-vset-edited` and `probe-write-vset-twice` the pinned exception for the line of `vset`,
#                 `probe-vset-variable` and `probe-vset-path` a call of `vset` that is not given digits. `probe-heredoc-quote-mid`, `-quote-end` and `-hyphen` plant a delimiter that the shell reads otherwise than the reader (`<<wait"x"` ends at `waitx`),
#                 `probe-heredoc-body-subst` and `-body-backtick` a `$(` and a backtick in the body of a here-document with a bare delimiter; `probe-ok-heredoc` (quoted delimiters with a `$(` in the body, a bare one with a plain body) stays green.
#                 `probe-command-run-limited` is `command run_limited` (no program has that name), the control `probe-ok-command-plain` `command cat`, and `probe-writes-floor` raises the floor MIN_PROBE_WRITES. Each new rule is blinded once in the meta probe.
# DEVICE PROBE, THE VIEW: the probe is read whole by one reader, and the lists the rows lean on (the functions it defines, its function heads and which function a line belongs to, which lines are comments) come from that reading, no longer from a
#                 text scan of the raw file. The `probe-fn-` mutations plant a `name() { :; }` where it defines nothing, and then a call of that name or a `trap` that names it: in the body of a quoted and of a bare here-document, in a
#                 string that runs over several lines (single and double quotes) and in a comment (`probe-fn-heredoc-call`, `-heredoc-trap`, `-heredoc-bare`, `-string-call`, `-string-trap`, `-dstring-call`, `-comment-call`), and the forms that are no
#                 definition for the calls either (`-indented-call`, `-after-semicolon`, `-subshell-call`, `-continued`, `-odd-name`); `probe-shadow-nested` a function named like a listed program that is not at the start of a line. `probe-no-main-heredoc`,
#                 `probe-pin-fn-heredoc`, `-pin-fn-string` and `-pin-fn-close-heredoc` plant a function head, and a closing brace, in a body or a string, where they gave the lines after them another function (the pins) and passed the fill probe;
#                 `probe-string-comment-line` and `-comment-curl` a line that looks like a comment inside a string (it ends the string and a command follows), `probe-heredoc-body-comment` one in a bare here-document (a `$(` in it is run),
#                 `probe-continued-comment` one after a backslash, `probe-string-head-reset` a line that looks like a head inside a string (it used to start the reading afresh). The controls `probe-ok-string-lines`, `probe-ok-heredoc-lines`
#                 (lines that look like comments, heads, closing braces and definitions, of a listed program too, in strings and here-documents: text), `probe-ok-continued` and `probe-ok-fn-toplevel` (the same name, a genuine function at the start of a
#                 line: its calls and a `trap` are the probe's own) stay green. Each part of the reader that decides this is blinded once in the meta probe (the column, depth, continued line and name of a definition, the list of all definitions,
#                 the three conditions of a clean line, the heads, the closing brace, the code lines, the second run). `probe-pin-fn-string` is red for two reasons (the pins, and the string state lost at a head) and is the one mutation no single blind shows.
# MAIN TOOLS, THE READER: the collector, both Overview copies, both payload.sh, the listener and library/ are read whole by the reader that reads the device probe (shview in the checker): the function a line belongs to, the function heads and
#                 the comment lines come from that reading, no longer from a scan of the text, and a line in a here-document body, a string, a comment or after a backslash that looks like a head, a closing brace or a comment starts, ends and hides
#                 nothing. The `main-head-` mutations plant a head in such a text with a device call behind it: `zz_evil() { cat <<'e' >/dev/null`, `apcli_ro() {` in the body, `e`, `WIFI_CONNECT zz` (`-heredoc-wifi`; `-heredoc-block` has the head of
#                 `zz_evil` on its own line, `-heredoc-bare` a bare delimiter), the same with a word of SEC6_RE and the head of apcli_stub (`-heredoc-sec6`), with a word of the Bluetooth stack and the head of bt_stub (`-heredoc-bt`), in a single and a
#                 double quoted string (`-string-single`, `-string-double`) and in the payload of the library (`-heredoc-payload`, `-string-payload`). The `main-comment-` ones plant a line that looks like a comment, which was dropped unread, in a string
#                 (`-string`, `-string-payload`: a quote in it ends the string and a call stands behind it), in a quoted and in a bare here-document (`-heredoc`, `-heredoc-bare`) and after a backslash (`-continued`: the command behind the comment line was
#                 read as an argument of the command before). `main-nested-definition`, `-bt` and `main-brace-indented` plant a head inside a function (a nested definition; a function above it that lost its closing brace at the start of a line): neither it nor
#                 the lines after it have a function, and the fill row names it; `main-nested-indented` is the indented definition, which was red before. `main-heredoc-bare-built`, `-backtick`, `-glob`, `-find`, `-multiline` and `main-heredoc-then-built`
#                 plant a built name or a glob in the body of a here-document with a bare delimiter (read as text with its expansions as code; the last one is a built name on the line after the document, to show that the state ends with it),
#                 `main-two-heredocs`, `-second` and `-payload` the same with two here-documents on a line (the line is bare if either delimiter is); `probe-heredoc-two-bodies`, `-backtick` and `-second` plant a `$(` or a backtick in the bare body of
#                 two here-documents on a line in the probe, `probe-nested-head` a head inside a function there. `main-iw-default-comment`, `-guard-comment`, `-guard-fake-head` and `-guard-moved` plant the default of the opt-in and the guard of
#                 `iw scan` behind a comment sign, a copy of the head with the guard in a here-document in front of the real head, and a comment line between the head and the guard. The controls `main-ok-apcli-line`, `-apcli-call` and `-bt-line` (a word
#                 of the lists as the first line of a genuine function, a call), `-heredoc-lines` (lines that look like heads, comments and closing braces, of apcli_ro too, in quoted and bare here-documents and in strings: text; the built name in the quoted body stands before its first head), `-heredoc-plain`
#                 (plain expansions, quotes and escaped expansions in a bare body, and a `$( )` over several lines), `-two-heredocs` (two quoted, built names in their bodies), `-nested-function` (an indented definition with a name of its own) and
#                 `-iw-guard`, `-script-plain` (a script text with a case pattern that is a glob, a command substitution, a parameter expansion and plain words, in a quoted and a bare here-document and in a string) and `-delimiters` (`<<-name`, `<<"name"`, `<<name`), and `probe-ok-heredoc-two`, stay green. Written down as limits, and green: `main-limit-second-definition` (a second
#                 top-level function with the name of an allowlisted one holds what the allowlist allows, as the first does; the planted `-planted` mutations above rely on defining such a function), `main-limit-quoted-script` (a script that a quoted here-document
#                 writes out, a `#!` line and a built command word, with no function head in it, is text: a program text that is built and then run) and `main-limit-before-head` (the part of a quoted body before its first function head is text as well). Each new part
#                 of the checker is blinded once in the meta probe (the head and the comment line in a text, the three conditions of a clean line against the plants of the collector, the nested head and its report, the body of a bare here-document, the AND over the
#                 delimiters, the text state and its end, the verdicts of the pass, the reading of the opt-in).
# MAIN TOOLS, SCRIPT TEXTS: a here-document body (quoted or bare) and a string that goes over several lines are text up to the first function head at the start of one of their lines; from that head to the delimiter or to the end of the string the text is a script, which the
#                 rows 6d and 6e read once more as code (the earlier reader read the lines after such a head as code, by accident: the handler that starchorus-serve.sh writes for the nc listener is such a text, and a built command word planted in the lower part of it was
#                 red on row 6d at 8b1d4bf and stays red). The `main-script-` mutations plant a built name below a head in a quoted body (`-quoted-built`, in the payload of the library `-quoted-payload`; `-quoted-glob` a glob), in a bare body (`-bare-built`: plain text there, so only
#                 the second reading sees it), in a single and a double quoted string (`-string-built`, `-string-payload`), in a body nested in a script text (`-nested`), and in the handler of the listener itself (`-handler`, a line added to the real text); `-reset-head` and
#                 `-reset-close` leave a quote open in one function of the text, and the built name stands in the next function (a head begins a segment, so does the line after a closing brace; the state of the reader starts afresh there); `-head-decoy` puts the head of
#                 `apcli_selftest` in a here-document in front of the renamed real one (a head in a script text is no function of the file: the names of the allowlists read the functions only). The `main-odd-delimiter` mutations plant a delimiter that is not a plain name, bare
#                 or wholly in quotes (`<<e"x"` ends at `ex`, `<<$zz_x`), where the reader ended the body at another line than the shell and took the lines after it for code: the first row names it. The controls `main-ok-script-plain`, `main-ok-delimiters` and
#                 `main-limit-before-head` stay green. Each part is blinded once in the meta probe (the head in a body, the head in a string, the second reading, the hand-over of the lines, the verdicts of the second reading, the two ways a segment begins, the
#                 heads that stay out of the functions, the delimiter test and its report).
# TRANSMIT ROW:   its three pinned lines (the `airmon-ng` last resort of create_monitor, the Nmap OUI path) have an edited, a vanished and a copied-elsewhere mutation (`tx-pin-`).
# PENDING:        the Bluetooth allowlist and the fifth apcli_ro line belong to the collector's Bluetooth code. While the checker still
#                 announces them (`sh tools/passivity-check.sh --pending` is not empty: BT_NOT_YET, APCLI_NOT_YET), a mutation whose
#                 target text is one of those lines (`mutr1` in the table) is reported PENDING, not run, and the run can be green
#                 without it; the rows are proven on the base meanwhile by the `-planted` mutations, which define a function of
#                 BT_FUNCS in the copy instead of editing one. Once the announcements are empty, a missing target is a SETUP-ERROR
#                 like any other, so a pending mutation can never be left behind unnoticed.
# NOT PROVEN:     proves nothing about behaviour, only that the SOURCE guard bites (a sqlite3 call through a variable or
#                 `command`, a method check outside the `case` in starchorus-serve.sh: seen by no rule, hence by no
#                 mutation); one example per alternative does not prove that every OTHER spelling of the same alternative hits
#                 (`location  =` with two blanks, other upper/lower case); alternatives in nested groups
#                 (`(assign|replace)`, `(-ng)?`) count as one, as do the alternatives of the rules without a family (`iw scan`, URLs,
#                 denylist words: there each has one line in the table); the alternatives probe reads the evidence lines under a
#                 red row, not its counter (the counter is the business of the row mutations). Every mutation is a text copy that never
#                 runs (the only call in copies is the checker itself, which only reads; see self_guard()).
# Rows are matched by prefix (their numbers change with the code). Mutations only ever touch COPIES in mktemp -d.
# Owners: the pinned sets belong to L; a legitimate K change that renames a row makes this script say which name to adjust.
# shellcheck disable=SC2016   # the mutation texts below are literal shell/JS source, not expansions
set -u
set -f
LC_ALL=C; export LC_ALL
here=$(cd "$(dirname "$0")" && pwd -P) || exit 2
R=$(cd "$here/.." && pwd -P) || exit 2
if ! { [ -f "$R/tools/passivity-check.sh" ] && [ -f "$R/starchorus.html" ]; }; then echo "passivity-mutate: repo files missing" >&2; exit 2; fi
me="$here/$(basename "$0")"

MIN_MUT=298    # mutations in the table, controls not counted (≥, PENDING ones included); count: sh tools/passivity-mutate.sh | grep -c '^mutation ' (358 lines: 298 and 60 controls)
# alternatives per regex family (≥, only ever raised; raised with every name V-13 of docs/device-notes.md adds); count: sh tools/passivity-mutate.sh | grep -c '^alt <family> '
# (family: netsurf 6, netx 19, tx 32, iw 3, sec6 21, bt 43, btwrap 15, pnet 31)
MIN_ALTS_NETSURF=6; MIN_ALTS_NETX=19; MIN_ALTS_TX=32; MIN_ALTS_IW=3; MIN_ALTS_SEC6=21; MIN_ALTS_BT=43; MIN_ALTS_BTWRAP=15; MIN_ALTS_PNET=31
MIN_ROWS=24   # PASS rows of the unmutated copy (≥); count: sh tools/passivity-check.sh | grep -c ' PASS$'   (13 before the Bluetooth rows, minus the replaced hcitool row, plus seven, plus the row of the built names, plus the row of the glob, find, xargs and alias, plus the three rows of the device probe)

# ---- 0 · the probe may only ever RUN the checker (and itself for --meta) on a copy: grep our own executable lines
self_guard() {
  _code=$(grep -v '^[[:space:]]*#' "$me")
  _cmd='(^|[;&|(])[[:space:]]*sh[[:space:]]'          # a line that starts the shell on something
  _n0=$(printf '%s\n' "$_code" | grep -cE "$_cmd")
  _n1=$(printf '%s\n' "$_code" | grep -cE "${_cmd}+tools/passivity-check\.sh")
  _n2=$(printf '%s\n' "$_code" | grep -cE "${_cmd}+\"\\\$_img/tools/passivity-mutate\.sh\"")
  _n3=$(printf '%s\n' "$_code" | grep -cE '[r]egress\.sh|[s]tatic\.sh|[q]uick\.sh|--[s]elftest|(^|[^A-Za-z_])(bash|dash|zsh|exec|eval|source)[[:space:]]|^[[:space:]]*"?\$[A-Za-z_{}]+/[^[:space:]]*\.sh')
  [ "$_n0/$_n1/$_n2/$_n3" = 2/1/1/0 ] || { echo "passivity-mutate: self guard failed (shell starts $_n0, checker $_n1, meta $_n2, forbidden $_n3; want 2/1/1/0)" >&2; return 1; }
}
self_guard || exit 2

tmp=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-pm.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT TERM

# ---- the pristine image every mutation starts from: what passivity-check.sh reads, and nothing else
base="$tmp/base"; work="$tmp/work"
mkdir -p "$base" || exit 2
for f in starchorus.html starchorus-collect.sh starchorus-display.sh payload.sh starchorus-serve.sh; do
  [ -f "$R/$f" ] || { echo "passivity-mutate: $f missing" >&2; exit 2; }
  cp "$R/$f" "$base/$f" || exit 2
done
cp -R "$R/tools" "$base/tools" && cp -R "$R/library" "$base/library" || exit 2

# The ONLY place a copy is executed. The checker reads files under its own root and prints rows; it starts nothing.
run_check() { ( cd "$1" && sh tools/passivity-check.sh ${2:+"$2"} ); }
# what the checker still announces as not there yet: the collector's Bluetooth functions and the fifth apcli_ro line (see PENDING above)
pending=$(run_check "$base" --pending 2>/dev/null | tr '\n' ' ' | sed 's/ $//')

# ---- mutation helpers (text only; no sed -i)
# lines of FILE containing the literal TEXT; a leading "^" anchors TEXT at the start of the line (the only special character:
# "selftest() {" alone is also a piece of "apcli_selftest() {")
nlit() { _t=$2 awk 'BEGIN { t = ENVIRON["_t"]; a = 0; if (substr(t, 1, 1) == "^") { a = 1; t = substr(t, 2) } }
  { i = index($0, t); if (a ? i == 1 : i > 0) n++ } END { print n + 0 }' "$1"; }
# replace the literal OLD by NEW in FILE (every line that has it; callers guarantee exactly one such line); "^" as in nlit
subst_lit() { _o=$2 _n=$3 awk 'BEGIN { o = ENVIRON["_o"]; n = ENVIRON["_n"]; a = 0; if (substr(o, 1, 1) == "^") { a = 1; o = substr(o, 2) } }
  { i = index($0, o); if (a ? i == 1 : i > 0) $0 = substr($0, 1, i - 1) n substr($0, i + length(o)); print }' "$1" > "$1.new" && mv "$1.new" "$1"; }
ensure_nl() { [ -z "$(tail -c 1 "$1")" ] || printf '\n' >> "$1"; }

# apply KIND FILE A B inside $work; returns 1 with a message when the target line is missing (phantom guard)
apply() {
  _kind=$1; _f="$work/$2"; _a=$3; _b=$4
  if [ "$_kind" = newfile ]; then   # a NEW file (no .sh suffix, say) with one function holding the text: the scope must reach it
    [ ! -e "$_f" ] || { echo "file $2 already exists (newfile wants a new one)" >&2; return 1; }
    printf '%s\n' '#!/bin/sh' 'zz_probe() {' "    $_a" '    :' '}' > "$_f" || return 1
    return 0
  fi
  [ -f "$_f" ] || { echo "no such file $2" >&2; return 1; }
  cp "$_f" "$tmp/before" || return 1
  case $_kind in
    append)   ensure_nl "$_f"; printf '%s\n' "$_a" >> "$_f" ;;
    fnappend) ensure_nl "$_f"; printf '%s\n' 'zz_probe() {' "    $_a" '    :' '}' >> "$_f" ;;
    subst)    _c=$(nlit "$_f" "$_a"); [ "$_c" = 1 ] || { echo "target text found on $_c lines of $2 (want exactly 1): $_a" >&2; return 1; }
              subst_lit "$_f" "$_a" "$_b" ;;
    fndef)    ensure_nl "$_f"; printf '%s\n' "$_a() {" "    $_b" '    :' '}' >> "$_f" ;;   # a function of that NAME holding the line B (a name of BT_FUNCS: the planted copy defines it)
    fnline)   _c=$(nlit "$_f" "^$_a() {"); [ "$_c" = 1 ] || { echo "function head $_a() { found on $_c lines of $2 (want exactly 1)" >&2; return 1; }
              _fa=$_a _fb=$_b awk 'BEGIN { h = ENVIRON["_fa"] "() {"; t = ENVIRON["_fb"] } { print } index($0, h) == 1 { print "    " t }' "$_f" > "$_f.new" && mv "$_f.new" "$_f" ;;   # the line B as the first line of function A
    denylist) _e=$(grep -v '^[[:space:]]*$' "$work/tools/denylist.txt" | head -n 1)
              [ -n "$_e" ] || { echo "tools/denylist.txt has no entry" >&2; return 1; }
              ensure_nl "$_f"; printf '%s\n' "// $_e" >> "$_f" ;;
    *) echo "unknown kind $_kind" >&2; return 1 ;;
  esac
  cmp -s "$tmp/before" "$_f" && { echo "mutation left $2 unchanged" >&2; return 1; }
  return 0
}

# ---- the rows of passivity-check.sh, by name prefix. Every one must be red at least once (coverage line below).
ROWS='§14.6 scope fill|HTML network surface|fetch( =|other network APIs|URLs outside|§14.6 device calls|§14.6 allowlist names|iw scan opt-in|transmit tools invoked|§14.6b Bluetooth words|Bluetooth allowlist names|Bluetooth lines in bt_begin|Bluetooth word forms|Bluetooth wrappers|Bluetooth command position|apcli_ro literal lines|§14.6d command words from an expansion|§14.6e command names from a glob|sqlite3 read-only|starchorus-serve.sh: GET|device-probe.sh scope fill|device-probe.sh named tools|device-probe.sh programs|§14.7 denylist'

sel=""; meta=0
while [ $# -gt 0 ]; do
  case $1 in
    --only) sel=${2:-}; [ -n "$sel" ] || { echo "usage: --only NAME" >&2; exit 2; }; shift 2 ;;
    --meta) meta=1; shift ;;
    *) echo "usage: sh $0 [--only NAME] [--meta]" >&2; exit 2 ;;
  esac
done

nmut=0; nok=0; ngreen=0; nwrong=0; nctl=0; nctlok=0; nsetup=0; npend=0; setup_names=""; covered="|"
seen_sel=0

# mut NAME FILE KIND ARG1 ARG2 EXPECT   (EXPECT = "|"-separated row prefixes that must be red, and only those; "" = stays green)
mut() {
  _name=$1; _file=$2; _kind=$3; _a=$4; _b=$5; _exp=$6
  [ -z "$sel" ] || [ "$sel" = "$_name" ] || return 0
  seen_sel=1
  rm -rf "$work"; cp -R "$base" "$work" || { nsetup=$((nsetup + 1)); setup_names="$setup_names $_name"; return 0; }
  if ! apply "$_kind" "$_file" "$_a" "$_b" 2> "$tmp/err"; then
    printf 'mutation %s: SETUP-ERROR %s\n' "$_name" "$(cat "$tmp/err")"; nsetup=$((nsetup + 1)); setup_names="$setup_names $_name"; return 0
  fi
  run_check "$work" > "$tmp/out" 2>&1; _rc=$?
  # red rows: lines ending in FAIL that are not indented evidence
  grep ' FAIL$' "$tmp/out" | grep -v '^    ' > "$tmp/red"
  _got=""; _extra=""; _missing=""; _redp=""
  while IFS= read -r _r; do
    _hit=0; _ifs=$IFS; IFS='|'
    for _p in $_exp; do case $_r in "$_p"*) _hit=1; _got="$_got|$_p" ;; esac; done
    IFS=$_ifs
    [ "$_hit" = 1 ] || _extra="$_extra [$(printf '%s' "$_r" | cut -c1-60)]"
    _ifs=$IFS; IFS='|'; for _p in $ROWS; do case $_r in "$_p"*) covered="$covered$_p|"; _redp="${_redp}[$_p]" ;; esac; done; IFS=$_ifs
  done < "$tmp/red"
  _ifs=$IFS; IFS='|'; for _p in $_exp; do case "$_got|" in *"|$_p|"*|*"|$_p") ;; *) _missing="$_missing [$_p]" ;; esac; done; IFS=$_ifs
  _show=$_redp
  if [ -z "$_exp" ]; then
    nctl=$((nctl + 1))
    if [ "$_rc" = 0 ] && [ -z "$_extra" ]; then nctlok=$((nctlok + 1)); printf 'mutation %s: GREEN as expected (control, no row red)\n' "$_name"
    else nwrong=$((nwrong + 1)); printf 'mutation %s: WRONG-ROW red:%s (expected none)\n' "$_name" "$_extra"; fi
    return 0
  fi
  nmut=$((nmut + 1))
  if [ "$_rc" -ge 2 ]; then nwrong=$((nwrong + 1)); printf 'mutation %s: WRONG-ROW checker exit %s\n' "$_name" "$_rc"
  elif [ -n "$_missing" ]; then ngreen=$((ngreen + 1)); printf 'mutation %s: GREEN (BLIND!) missing red:%s (expected %s)%s\n' "$_name" "$_missing" "$_exp" "$([ -n "$_extra" ] && printf ', also red:%s' "$_extra")"
  elif [ -n "$_extra" ]; then nwrong=$((nwrong + 1)); printf 'mutation %s: WRONG-ROW red %s (expected %s)\n' "$_name" "$_show" "$_exp"
  else nok=$((nok + 1)); printf 'mutation %s: RED %s (expected %s)\n' "$_name" "$_show" "$_exp"; fi
}

# mutr1: like mut, for a mutation whose target is a line of the collector's Bluetooth code (bt_begin, bt_end, bt_selftest, the recon_channels line). While the
# checker announces that work (PENDING in the header) a target that is not in the base yet makes it PENDING instead of a SETUP-ERROR; with nothing
# announced it is exactly mut, so the first run after the collector has that code either bites or names the line to adapt.
mutr1() {
  [ -z "$sel" ] || [ "$sel" = "$1" ] || return 0
  if [ -n "$pending" ] && [ -f "$base/$2" ]; then
    case $3 in fnline) _tl="^$4() {" ;; *) _tl=$4 ;; esac
    if [ "$(nlit "$base/$2" "$_tl")" = 0 ]; then
      seen_sel=1; npend=$((npend + 1))
      printf 'mutation %s: PENDING (its target is not in %s yet; the checker still announces: %s)\n' "$1" "$2" "$pending"; return 0
    fi
  fi
  mut "$@"
}

# ============================== meta: the probe of the probe ==============================
if [ "$meta" = 1 ]; then
  nm=0; nmok=0
  # metaprobe NAME BLIND_FILE OLD NEW ONLY WANT: in an image of the repo, break the checker as described, then the copy of THIS
  # script run with `--only ONLY` must print a line starting with WANT (fixed text) and exit non-zero.
  metaprobe() {
    nm=$((nm + 1)); _img="$tmp/img$nm"; mkdir -p "$_img" || exit 2
    cp -R "$base/." "$_img/" || exit 2
    _c=$(nlit "$_img/$2" "$3")
    [ "$_c" = 1 ] || { printf 'meta %s: SETUP-ERROR target text on %s lines of %s (want 1)\n' "$1" "$_c" "$2"; return 0; }
    subst_lit "$_img/$2" "$3" "$4"
    sh "$_img/tools/passivity-mutate.sh" --only "$5" > "$tmp/meta.out" 2>&1; _mrc=$?
    if [ "$_mrc" != 0 ] && grep -qF -- "$6" "$tmp/meta.out"; then
      nmok=$((nmok + 1)); printf 'meta %s: detected (%s => exit %s, %s)\n' "$1" "$5" "$_mrc" "$6"
    else printf 'meta %s: NOT DETECTED, exit %s: %s\n' "$1" "$_mrc" "$(head -n 3 "$tmp/meta.out" | cut -c1-120 | tr '\n' ';')"; fi
  }
  # (a) NETX loses one alternative: window.open would pass unseen
  metaprobe netx-window-open tools/passivity-check.sh 'window\.open\(|' '' window-open 'mutation window-open: GREEN (BLIND!)'
  # (b) the object prefix of the location alternative is gone, the class excludes "." (an object-prefixed assignment escapes)
  metaprobe netx-location-prefix tools/passivity-check.sh '(^|[^A-Za-z0-9_])((document|top|parent|self|window)\.)?location' '(^|[^A-Za-z0-9_.])location' doc-location 'mutation doc-location: GREEN (BLIND!)'
  # (c) ONE alternative of a family goes (a row-level probe never saw these): the alternative probe names it
  metaprobe alt-netx-importscripts tools/passivity-check.sh 'importScripts|' '' alts 'alt netx importScripts: GREEN (BLIND!)'
  metaprobe alt-tx-hostapd tools/passivity-check.sh '|hostapd|airbase' '|airbase' alts 'alt tx =hostapd: GREEN (BLIND!)'
  metaprobe alt-sec6-deauth tools/passivity-check.sh 'DEAUTH|' '' alts 'alt sec6 DEAUTH: GREEN (BLIND!)'
  metaprobe alt-netsurf-beacon tools/passivity-check.sh '|sendBeacon' '' alts 'alt netsurf sendBeacon: GREEN (BLIND!)'
  # (c2) the alternative stays in the regex, but the evidence the row prints no longer reads it (another family there): not listed
  metaprobe alt-netx-evidence-unwired tools/passivity-check.sh 'grep -nE "$NETX" "$H"' 'grep -nE "$NETSURF_RE" "$H"' alts 'alt netx RTCPeerConnection: GREEN (BLIND!) line'
  # (d) the sqlite3 rule must read only the code part of the line: reading the whole line lets a trailing `# -readonly` pass
  metaprobe sqlite-whole-line tools/passivity-check.sh 'if ((" " substr(seg, 1, cut - 1) " ") !~' 'if ((" " t " ") !~' sqlite-comment-flag 'mutation sqlite-comment-flag: GREEN (BLIND!)'
  # (e) the Bluetooth rows, one at a time: each stops reading what it reads, and the mutation that plants its violation (a `-planted`
  #     one, which needs nothing of the collector's Bluetooth code) must say GREEN (BLIND!)
  metaprobe bt-words-blind tools/passivity-check.sh '(hits $(lines "$tmp/bt"))" [ ! -s "$tmp/btbad" ]' '(hits $(lines "$tmp/bt"))" true' bt-outside 'mutation bt-outside: GREEN (BLIND!)'
  metaprobe bt-begin-blind tools/passivity-check.sh '[ ! -s "$tmp/btbbad" ] && [ "$btb_p" = 1/1 ] && btb_ok=1' 'btb_ok=1' bt-begin-planted 'mutation bt-begin-planted: GREEN (BLIND!)'
  metaprobe bt-forms-blind tools/passivity-check.sh 'if (t ~ BT) print $0 > BAD }' 'if (0) print $0 > BAD }' bt-form-planted 'mutation bt-form-planted: GREEN (BLIND!)'
  metaprobe bt-varexec-blind tools/passivity-check.sh 'else if (s ~ /^["\047]?\$/) bad = 1' 'else if (0) bad = 1' bt-varexec-planted 'mutation bt-varexec-planted: GREEN (BLIND!)'
  metaprobe bt-timeout-blind tools/passivity-check.sh 'else if (fn != "bt_begin" && u ~ /^timeout([ \t]|$)/) bad = 1' 'else if (0) bad = 1' bt-timeout-planted 'mutation bt-timeout-planted: GREEN (BLIND!)'
  metaprobe bt-cmdpos-blind tools/passivity-check.sh '[ ! -s "$tmp/bt_cmdpos" ] ;;' 'true ;;' bt-cmdpos-planted 'mutation bt-cmdpos-planted: GREEN (BLIND!)'
  metaprobe apcli-unpinned-blind tools/passivity-check.sh '[ "$ap_bad" = 0 ] && [ -z "$ap_off$ap_dup$ap_unk" ] && ap_ok=1' '[ -z "$ap_off$ap_dup$ap_unk" ] && ap_ok=1' apcli-fifth-line 'mutation apcli-fifth-line: GREEN (BLIND!)'
  metaprobe bt-normal-form-blind tools/passivity-check.sh 'if (NORM == "1") { gsub(/\\/, "", l); gsub(/"[ \t]+"/, "", l); gsub(/["\047]/, "", l) }' 'if (NORM == "1") { l = l }' bt-split-quote 'mutation bt-split-quote: GREEN (BLIND!)'
  metaprobe bt-cmd-expansion-blind tools/passivity-check.sh 'if (MODE == "wrap" && CWX) bad = 1' 'if (0) bad = 1' bt-cmd-subst 'mutation bt-cmd-subst: GREEN (BLIND!)'
  metaprobe bt-glob-blind tools/passivity-check.sh 'if (cw !~ /^\[\[?$/ && cw ~ /[?*\[]/) bad = 1' 'if (0) bad = 1' bt-glob 'mutation bt-glob: GREEN (BLIND!)'
  metaprobe alt-bt-dbus tools/passivity-check.sh '|dbus-send' '' alts 'alt bt dbus-send: GREEN (BLIND!)'
  metaprobe alt-btwrap-time tools/passivity-check.sh '|^time([[:space:]]|$)' '' alts 'alt btwrap ^time: GREEN (BLIND!)'
  metaprobe alt-bt-btgatt tools/passivity-check.sh '|btgatt-client' '' alts 'alt bt btgatt-client: GREEN (BLIND!)'
  metaprobe alt-btwrap-nohup tools/passivity-check.sh '|^nohup([[:space:]]|$)' '' alts 'alt btwrap ^nohup: GREEN (BLIND!)'
  # (f) the row of the built names (§14.6d), one part at a time: the row reads nothing, the wrapper words are no wrappers, the pinned list reports no new line, or no
  #     vanished one; the mutation that plants what that part sees must say GREEN (BLIND!). With the detection of an expansion in a command word off, the row is red for
  #     another reason (every pin has lost its line, so a mutation still reads RED), and what shows the loss is a control that goes red: WRONG-ROW.
  metaprobe dyn-row-blind tools/passivity-check.sh '[ "$dyn_ok" = 1 ]' 'true' dyn-split-name 'mutation dyn-split-name: GREEN (BLIND!)'
  metaprobe dyn-expansion-blind tools/passivity-check.sh 'if (dtexp) dbad = 1' 'if (0) dbad = 1' dyn-ok-assign 'mutation dyn-ok-assign: WRONG-ROW'
  metaprobe dyn-wrapper-blind tools/passivity-check.sh '/^(exec|command|nohup|setsid|nice|env|time|xargs|busybox|timeout|sudo|stdbuf)$/' '/^(zz_none)$/' dyn-wrapper-nice 'mutation dyn-wrapper-nice: GREEN (BLIND!)'
  metaprobe dyn-new-line-blind tools/passivity-check.sh 'else print $0 > NEW }' 'else np++ }' dyn-split-name 'mutation dyn-split-name: GREEN (BLIND!)'
  metaprobe dyn-gone-pin-blind tools/passivity-check.sh 'print k > GONE; print np + 0' 'print k > "/dev/null"; print np + 0' dyn-pin-gone 'mutation dyn-pin-gone: GREEN (BLIND!)'
  # (g) the second row of the pass (§14.6e), one part at a time: the row, the glob test, find, the placeholder of xargs, xargs without a command, the alias, and the two things that
  #     keep the row from flagging what it must not: the end of a case pattern and the `${ }` that holds a blank or a parenthesis (their controls go red when it is blind)
  metaprobe dyn6e-row-blind tools/passivity-check.sh '[ "$dyn_ok2" = 1 ]' 'true' dyn-glob 'mutation dyn-glob: GREEN (BLIND!)'
  metaprobe dyn6e-glob-blind tools/passivity-check.sh 'if (dtglob && dtok !~ /^\[\[?$/) dbad2 = 1' 'if (0) dbad2 = 1' dyn-bracket 'mutation dyn-bracket: GREEN (BLIND!)'
  metaprobe dyn6e-find-blind tools/passivity-check.sh 'if (dcmd == "find" && a ~ /^-(exec|execdir|ok|okdir)$/) dbad2 = 1' 'if (0) dbad2 = 1' dyn-find-"ex"ec 'mutation dyn-find-exec: GREEN (BLIND!)'
  metaprobe dyn6e-find-okdir-blind tools/passivity-check.sh 'a ~ /^-(exec|execdir|ok|okdir)$/' 'a ~ /^-(exec|execdir|ok)$/' dyn-find-okdir 'mutation dyn-find-okdir: GREEN (BLIND!)'
  metaprobe dyn6e-xargs-blind tools/passivity-check.sh 'if (dwc == "xargs" && (index(dn, "{}") > 0 || (dxr != "" && index(dn, dxr) > 0))) dbad2 = 1' 'if (0) dbad2 = 1' dyn-xargs-placeholder 'mutation dyn-xargs-placeholder: GREEN (BLIND!)'
  metaprobe dyn6e-xargs-custom-blind tools/passivity-check.sh '(index(dn, "{}") > 0 || (dxr != "" && index(dn, dxr) > 0))' '(index(dn, "{}") > 0)' dyn-xargs-custom 'mutation dyn-xargs-custom: GREEN (BLIND!)'
  metaprobe dyn6e-xargs-missing-blind tools/passivity-check.sh 'function dxend() { if (dwr && dwc == "xargs") { dbad2 = 1; dwr = 0 } }' 'function dxend() { dwr = dwr }' dyn-xargs-missing 'mutation dyn-xargs-missing: GREEN (BLIND!)'
  metaprobe dyn6e-alias-blind tools/passivity-check.sh 'else if (dcmd == "alias" && index(a, "=") > 0) dbad2 = 1' 'else if (0) dbad2 = 1' dyn-alias 'mutation dyn-alias: GREEN (BLIND!)'
  metaprobe dyn6e-case-pattern-blind tools/passivity-check.sh 'else { dbad = bsep; dbad2 = bsep2 };' 'else { dbad = bsep };' dyn-ok-glob-case 'mutation dyn-ok-glob-case: WRONG-ROW'
  metaprobe dyn6e-brace-blind tools/passivity-check.sh 'if (top == "B") {' 'if (0) {' dyn-ok-param-expansion 'mutation dyn-ok-param-expansion: WRONG-ROW'
  metaprobe dyn6e-wrapper-quote-blind tools/passivity-check.sh 'if (dn ~ /^(exec|command|nohup|setsid|nice|env|time|xargs|busybox|timeout|sudo|stdbuf)$/)' 'if (dtok ~ /^(exec|command|nohup|setsid|nice|env|time|xargs|busybox|timeout|sudo|stdbuf)$/)' dyn-wrapper-quoted 'mutation dyn-wrapper-quoted: GREEN (BLIND!)'
  # (h) the pinned lines of the transmit row: the row reads nothing, a pin without a line goes unreported. (That a pin covers one line only is held by the mutations `tx-pin-elsewhere` and
  #     `dyn-pin-twice`; the decrement of the pin cannot be blinded alone, since the report of the pins without a line reads the same counter, so no image of the checker shows it.)
  metaprobe tx-row-blind tools/passivity-check.sh '[ "$tx_ok" = 1 ]' 'true' transmit-tool 'mutation transmit-tool: GREEN (BLIND!)'
  metaprobe tx-pin-gone-blind tools/passivity-check.sh 'tx_ok=0; [ ! -s "$tmp/tx" ] && [ ! -s "$tmp/tx_gone" ] && tx_ok=1' 'tx_ok=0; [ ! -s "$tmp/tx" ] && tx_ok=1' tx-pin-gone 'mutation tx-pin-gone: GREEN (BLIND!)'
  metaprobe alt-tx-nmap tools/passivity-check.sh '|nmap|iwconfig' '|iwconfig' alts 'alt tx nmap: GREEN (BLIND!)'
  metaprobe alt-tx-hostapd-cli tools/passivity-check.sh '|hostapd_cli' '' alts 'alt tx hostapd_cli: GREEN (BLIND!)'
  metaprobe alt-bt-scotest tools/passivity-check.sh '|scotest|hcieventmask' '|hcieventmask' alts 'alt bt scotest: GREEN (BLIND!)'
  # (i) the rows of tools/device-probe.sh (row 7d), one part at a time. Each row, the reports of a line that is not pinned and of a pin without a line, the fill, the list of unlisted commands and the
  #     shadowing of a listed program stop reading what they read; each of the nine kinds of line that make up the hits of 'named tools' is left out once (a sending tool, a Bluetooth word, a network word,
  #     a device call, an `iw scan`, the sqlite3 word, a built command word, a glob, a program of PROBE_PINNED); the recording of the command names, the end of a case pattern and the function definition
  #     (`name()` is no command) are blinded and the controls go red. The mutation that plants what the part sees must say GREEN (BLIND!) (or, for a control, WRONG-ROW). A family whose
  #     hits include pinned lines that no other family hits (Bluetooth, network, sqlite3, built names, programs) turns the unmutated row red when it is blinded (the pins lose their lines), so it
  #     is shown by the control `probe-ok-read` going red (WRONG-ROW), as the row of the built names is.
  metaprobe probe-named-row-blind tools/passivity-check.sh '[ "$pn_ok" = 1 ]' 'true' probe-iw-set 'mutation probe-iw-set: GREEN (BLIND!)'
  metaprobe probe-new-line-blind tools/passivity-check.sh '[ ! -s "$tmp/pnew" ] && [ ! -s "$tmp/pgone" ] && pn_ok=1' '[ ! -s "$tmp/pgone" ] && pn_ok=1' probe-pin-twice 'mutation probe-pin-twice: GREEN (BLIND!)'
  metaprobe probe-gone-pin-blind tools/passivity-check.sh '[ ! -s "$tmp/pnew" ] && [ ! -s "$tmp/pgone" ] && pn_ok=1' '[ ! -s "$tmp/pnew" ] && pn_ok=1' probe-pin-gone 'mutation probe-pin-gone: GREEN (BLIND!)'
  metaprobe probe-fill-blind tools/passivity-check.sh '[ "$pfok" = 1 ]' 'true' probe-head-oneliner 'mutation probe-head-oneliner: GREEN (BLIND!)'
  metaprobe probe-unlisted-blind tools/passivity-check.sh 'pg_ok=0; [ ! -s "$tmp/punl" ] && [ ! -s "$tmp/pshadow" ]' 'pg_ok=0; [ ! -s "$tmp/pshadow" ]' probe-unlisted-read 'mutation probe-unlisted-read: GREEN (BLIND!)'
  metaprobe probe-shadow-blind tools/passivity-check.sh 'pg_ok=0; [ ! -s "$tmp/punl" ] && [ ! -s "$tmp/pshadow" ]' 'pg_ok=0; [ ! -s "$tmp/punl" ]' probe-shadow 'mutation probe-shadow: GREEN (BLIND!)'
  metaprobe probe-hits-tx-blind tools/passivity-check.sh ' p_tx ' ' ' probe-aireplay 'mutation probe-aireplay: GREEN (BLIND!)'
  metaprobe probe-hits-bt-blind tools/passivity-check.sh ' p_bt ' ' ' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-hits-net-blind tools/passivity-check.sh ' p_net ' ' ' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-hits-sec6-blind tools/passivity-check.sh 'in p_sec6 ' 'in ' probe-pineap 'mutation probe-pineap: GREEN (BLIND!)'
  metaprobe probe-hits-scan-blind tools/passivity-check.sh ' p_scan ' ' ' probe-iw-scan-path 'mutation probe-iw-scan-path: GREEN (BLIND!)'
  metaprobe probe-hits-sqlite-blind tools/passivity-check.sh ' p_sq ' ' ' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-hits-built-blind tools/passivity-check.sh ' pdyn_bad ' ' ' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-hits-glob-blind tools/passivity-check.sh ' pdyn_bad2 ' ' ' probe-glob 'mutation probe-glob: GREEN (BLIND!)'
  metaprobe probe-hits-program-blind tools/passivity-check.sh ' pprog pcont; do' ' pcont; do' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-record-blind tools/passivity-check.sh 'function rec(nm) { if (CMDS != "" && !dtexp && !dtglob) REC[++nrec] = nm }' 'function rec(nm) { nrec = nrec }' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-case-pattern-blind tools/passivity-check.sh 'if (dsp == 0) { if (cpat[0]) nrec = rmark[0]; if' 'if (dsp == 0) { if' probe-ok-case-pattern 'mutation probe-ok-case-pattern: WRONG-ROW'
  metaprobe probe-funcdef-blind tools/passivity-check.sh 'if (fdef && nrec == n0 + 1) nrec--;' '' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe alt-pnet-curl tools/passivity-check.sh "PNET_WORDS='curl|" "PNET_WORDS='" alts 'alt pnet curl: GREEN (BLIND!)'
  metaprobe alt-pnet-socat tools/passivity-check.sh '|socat|ping6?' '|ping6?' alts 'alt pnet socat: GREEN (BLIND!)'
  metaprobe alt-pnet-halt tools/passivity-check.sh '|poweroff|halt' '|poweroff' alts 'alt pnet halt: GREEN (BLIND!)'
  # (j) the writes of the probe, the command word after `command`, the case items and the pinned programs date, sed and sort (row 7d, 'programs' and 'named tools'), one part at a time. A part
  #     whose lines the unmutated probe needs (an exception that stands in the list of writes, the continuation of the privacy filter's sed, a `case` with a pattern in it) turns the unmutated row
  #     red when it is blinded, and the control `probe-ok-read` (or the control of the case form) goes red: WRONG-ROW. The others have a mutation that goes GREEN (BLIND!).
  metaprobe probe-write-new-blind tools/passivity-check.sh '[ ! -s "$tmp/pwnew" ] && [ ! -s "$tmp/pwgone" ] && [ "$pnc" -ge "$MIN_PROBE_CMDS" ] && pg_ok=1' '[ ! -s "$tmp/pwgone" ] && [ "$pnc" -ge "$MIN_PROBE_CMDS" ] && pg_ok=1' probe-append-etc 'mutation probe-append-etc: GREEN (BLIND!)'
  metaprobe probe-write-gone-blind tools/passivity-check.sh '[ ! -s "$tmp/pwgone" ] && [ "$pnc" -ge "$MIN_PROBE_CMDS" ] && pg_ok=1' '[ "$pnc" -ge "$MIN_PROBE_CMDS" ] && pg_ok=1' probe-write-pin-gone 'mutation probe-write-pin-gone: GREEN (BLIND!)'
  metaprobe probe-write-judge-blind tools/passivity-check.sh 'function okw(w,   v) { v = unq(w); return (v == "/dev/null"' 'function okw(w,   v) { v = unq(w); return (1 || v == "/dev/null"' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-write-assign-blind tools/passivity-check.sh 'if (nm != "T" && nm != "OUT" && nm != "A" && nm != "B") return 1' 'return 1' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-write-redirect-blind tools/passivity-check.sh 'if (c == ">" && WRF != "") {' 'if (0) {' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-write-input-blind tools/passivity-check.sh 'if (c == "<" && WRF != "") {' 'if (0) {' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-write-copy-blind tools/passivity-check.sh 'if (dcmd == "cp" || dcmd == "mv" || dcmd == "tee") {' 'if (0) {' probe-cp-root 'mutation probe-cp-root: GREEN (BLIND!)'
  metaprobe probe-write-for-blind tools/passivity-check.sh '} else if (dcmd == "for" && dforv) {' '} else if (0) {' probe-for-var 'mutation probe-for-var: GREEN (BLIND!)'
  metaprobe probe-write-read-blind tools/passivity-check.sh 'else if (dcmd == "read" && a !~ /^-/) WREC' 'else if (0) WREC' probe-read-var 'mutation probe-read-var: GREEN (BLIND!)'
  metaprobe probe-command-tag-blind tools/passivity-check.sh 'rec((ac ? "!" : "") dn); sub(/^.*\//, "", dn); dcmd = dn; dcase(1, dn)' 'rec(dn); sub(/^.*\//, "", dn); dcmd = dn; dcase(1, dn)' probe-command-function-read 'mutation probe-command-function-read: GREEN (BLIND!)'
  metaprobe probe-case-only-blind tools/passivity-check.sh 'if (cpat[0]) nrec = rmark[0]; if (CMDS' 'nrec = rmark[0]; if (CMDS' probe-case-stray-paren 'mutation probe-case-stray-paren: GREEN (BLIND!)'
  metaprobe probe-case-in-mark-blind tools/passivity-check.sh 'cpat[dsp] = 1; rmark[dsp] = nrec; pdb[dsp] = dbad; pdb2[dsp] = dbad2 } }' 'cpat[dsp] = 1; pdb[dsp] = dbad; pdb2[dsp] = dbad2 } }' probe-case-pipeline-read 'mutation probe-case-pipeline-read: GREEN (BLIND!)'
  metaprobe probe-case-in-blind tools/passivity-check.sh 'cdepth[dsp]++; cpat[dsp] = 1; rmark[dsp] = nrec;' 'cdepth[dsp]++; rmark[dsp] = nrec;' probe-ok-case-pattern 'mutation probe-ok-case-pattern: WRONG-ROW'
  metaprobe probe-case-sep-blind tools/passivity-check.sh 'cpat[dsp] = (i > 1 && substr(t, i - 1, 1) == ";")' 'cpat[dsp] = 0' probe-ok-case-pattern 'mutation probe-ok-case-pattern: WRONG-ROW'
  metaprobe probe-case-line-blind tools/passivity-check.sh 'cpat[dsp] = (cdepth[dsp] > 0 && (dsp == 0 || DST[dsp] ~ /^[SKP]$/)) ? 1 : 0 }' 'cpat[dsp] = 0 }' probe-ok-case-lines 'mutation probe-ok-case-lines: WRONG-ROW'
  metaprobe probe-continued-blind tools/passivity-check.sh '{ cont = (($0 in h) && $0 ~ /\\$/) }' '{ cont = 0 }' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-hits-cont-blind tools/passivity-check.sh ' pcont; do' '; do' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-date-plain-blind tools/passivity-check.sh "PROBE_PINNED=' busybox chmod cp date find" "PROBE_PLAIN=\"\$PROBE_PLAIN date \"; PROBE_PINNED=' busybox chmod cp find" probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-sed-plain-blind tools/passivity-check.sh " run_limited sed sh sort sqlite3 timeout '" " run_limited sh sort sqlite3 timeout '; PROBE_PLAIN=\"\$PROBE_PLAIN sed \"" probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-sort-plain-blind tools/passivity-check.sh " run_limited sed sh sort sqlite3 timeout '" " run_limited sed sh sqlite3 timeout '; PROBE_PLAIN=\"\$PROBE_PLAIN sort \"" probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  # (k) the trap action, the callers of vset, the expansion after `$T/`, the here-document, a case inside a group and the word after `command` (row 7d), one part at a time. Parts that the unmutated probe needs (the
  #     function name as an action, `exit N`, a here-document with a bare or a quoted delimiter, a case at the start of a line inside a group, the vset line among the writes) turn the unmutated row red when they are blinded, and
  #     a control goes red instead: WRONG-ROW. The others have a mutation that goes GREEN (BLIND!).
  metaprobe probe-trap-call-blind tools/passivity-check.sh 'if (dcmd == "trap") dtrap(dtok); else if' 'if (0) dtrap(dtok); else if' probe-trap-iw-set 'mutation probe-trap-iw-set: GREEN (BLIND!)'
  metaprobe probe-trap-exit-loose-blind tools/passivity-check.sh 'v ~ /^exit [0-9]+$/ ||' 'v ~ /^exit / ||' probe-trap-exit-more 'mutation probe-trap-exit-more: GREEN (BLIND!)'
  metaprobe probe-trap-function-loose-blind tools/passivity-check.sh '&& index(PFN, " " v " ") > 0)) return' '&& 1)) return' probe-trap-program 'mutation probe-trap-program: GREEN (BLIND!)'
  metaprobe probe-trap-function-blind tools/passivity-check.sh '|| (v ~ /^[A-Za-z_][A-Za-z0-9_]*$/ && index(PFN, " " v " ") > 0)) return' ') return' probe-ok-trap 'mutation probe-ok-trap: WRONG-ROW'
  metaprobe probe-trap-dash-blind tools/passivity-check.sh 'if (v == "-" || v == "" ||' 'if (v == "" ||' probe-ok-trap 'mutation probe-ok-trap: WRONG-ROW'
  metaprobe probe-trap-empty-blind tools/passivity-check.sh 'if (v == "-" || v == "" ||' 'if (v == "-" ||' probe-ok-trap 'mutation probe-ok-trap: WRONG-ROW'
  metaprobe probe-trap-single-quote-blind tools/passivity-check.sh 'else if (w ~ /^\047[^\047]*\047$/ || w ~ /^"[^"]*"$/)' 'else if (w ~ /^"[^"]*"$/)' probe-ok-trap 'mutation probe-ok-trap: WRONG-ROW'
  metaprobe probe-trap-double-quote-blind tools/passivity-check.sh 'else if (w ~ /^\047[^\047]*\047$/ || w ~ /^"[^"]*"$/)' 'else if (w ~ /^\047[^\047]*\047$/)' probe-ok-trap 'mutation probe-ok-trap: WRONG-ROW'
  metaprobe probe-vset-call-blind tools/passivity-check.sh 'else if (dcmd == "vset" && dtok !~ /^[0-9]+$/) REC[++nrec] = "vset-argument"' 'else if (0) REC[++nrec] = "vset-argument"' probe-vset-variable 'mutation probe-vset-variable: GREEN (BLIND!)'
  metaprobe probe-vset-digits-blind tools/passivity-check.sh 'dtok !~ /^[0-9]+$/) REC' 'dtok !~ /^[0-9a-z.\/]+$/) REC' probe-vset-path 'mutation probe-vset-path: GREEN (BLIND!)'
  metaprobe probe-write-expansion-blind tools/passivity-check.sh 'r ~ /^[A-Za-z0-9_.\/-]+$/)' 'r ~ /^[A-Za-z0-9_.$\/{}-]+$/)' probe-ok-redirects 'mutation probe-ok-redirects: WRONG-ROW'
  metaprobe probe-heredoc-delimiter-blind tools/passivity-check.sh 'if (!DHDQ && wd !~ /^[A-Za-z_][A-Za-z0-9_]*$/) REC[++nrec] = "here-document" }' 'if (0) REC[++nrec] = "here-document" }' probe-heredoc-quote-mid 'mutation probe-heredoc-quote-mid: GREEN (BLIND!)'
  metaprobe probe-heredoc-bare-blind tools/passivity-check.sh 'if (!DHDQ && wd !~ /^[A-Za-z_][A-Za-z0-9_]*$/) REC' 'if (!DHDQ) REC' probe-ok-heredoc 'mutation probe-ok-heredoc: WRONG-ROW'
  metaprobe probe-heredoc-quoted-blind tools/passivity-check.sh 'DHDQ = (wd ~ /^(\047[A-Za-z_][A-Za-z0-9_]*\047|"[A-Za-z_][A-Za-z0-9_]*")$/);' 'DHDQ = 0;' probe-ok-heredoc 'mutation probe-ok-heredoc: WRONG-ROW'
  metaprobe probe-heredoc-body-blind tools/passivity-check.sh 'else if (CMDS != "" && !hdq && (index(t, "$(") > 0' 'else if (0 && (index(t, "$(") > 0' probe-heredoc-body-subst 'mutation probe-heredoc-body-subst: GREEN (BLIND!)'
  metaprobe probe-heredoc-backtick-blind tools/passivity-check.sh '|| index(t, "`") > 0)) print "here-document' ')) print "here-document' probe-heredoc-body-backtick 'mutation probe-heredoc-body-backtick: GREEN (BLIND!)'
  metaprobe probe-heredoc-quoted-body-blind tools/passivity-check.sh 'else if (CMDS != "" && !hdq && (index' 'else if (CMDS != "" && (index' probe-ok-heredoc 'mutation probe-ok-heredoc: WRONG-ROW'
  metaprobe probe-case-group-blind tools/passivity-check.sh 'if (CMDS != "" && cpat[dsp]) { nrec = rmark[dsp];' 'if (0 && cpat[dsp]) { nrec = rmark[dsp];' probe-case-nested-subst 'mutation probe-case-nested-subst: GREEN (BLIND!)'
  metaprobe probe-case-group-flags-blind tools/passivity-check.sh 'if (CMDS != "" && cpat[dsp]) { nrec = rmark[dsp];' 'if (0 && cpat[dsp]) { nrec = rmark[dsp];' probe-case-built-group 'mutation probe-case-built-group: GREEN (BLIND!)'
  metaprobe probe-case-level-blind tools/passivity-check.sh 'if (dsp != 0 && CMDS == "") return' 'if (dsp != 0) return' probe-case-nested-subst 'mutation probe-case-nested-subst: GREEN (BLIND!)'
  metaprobe probe-case-group-line-blind tools/passivity-check.sh '(dsp == 0 || DST[dsp] ~ /^[SKP]$/)' 'dsp == 0' probe-ok-case-nested-lines 'mutation probe-ok-case-nested-lines: WRONG-ROW'
  metaprobe probe-case-flags-blind tools/passivity-check.sh 'if (CMDS != "" && cpat[0]) { dbad = pdb[0]; dbad2 = pdb2[0] }' 'if (0) { dbad = pdb[0]; dbad2 = pdb2[0] }' probe-case-built-name 'mutation probe-case-built-name: GREEN (BLIND!)'
  metaprobe probe-case-esac-blind tools/passivity-check.sh '{ cdepth[dsp]--; cpat[dsp] = 0 }' '{ cdepth[dsp]-- }' probe-case-built-subst 'mutation probe-case-built-subst: GREEN (BLIND!)'
  metaprobe probe-command-strip-blind tools/passivity-check.sh 'm = n; sub(/^!/, "", m);' 'm = n;' probe-ok-command-plain 'mutation probe-ok-command-plain: WRONG-ROW'
  metaprobe probe-command-run-limited-blind tools/passivity-check.sh 'if (n == "!run_limited") { print r > UNL; next }' 'if (0) { print r > UNL; next }' probe-command-run-limited 'mutation probe-command-run-limited: GREEN (BLIND!)'
  metaprobe probe-writes-floor-blind tools/passivity-check.sh '[ "$pnw" -ge "$MIN_PROBE_WRITES" ] && ' '' probe-writes-floor 'mutation probe-writes-floor: GREEN (BLIND!)'
  # (l) the probe is read whole, by one reader: its functions (`name()` met at the start of a line with nothing open), the function a line belongs to, and which lines are comments come from the reader, not from a scan of the raw
  #     text (row 7d). Each part of that is blinded once: the column, the depth, the continued line and the name of a definition, the list of all definitions (the shadow test), the three conditions under which a line is "clean" (no
  #     here-document body, nothing open, no line going on), the heads, the closing brace, what goes into the code lines, the second run with the functions. Parts that the unmutated probe needs (the heads, the closing
  #     brace that gives the lines after a function no function, the call of the recorder, the second run) turn the unmutated row red when blinded, and a control goes red instead: WRONG-ROW.
  metaprobe probe-fdef-column-blind tools/passivity-check.sh 'if (dsp == 0 && !cont && col == length(nm) + 1) print nm > FDEFS' 'if (dsp == 0 && !cont) print nm > FDEFS' probe-fn-indented-call 'mutation probe-fn-indented-call: GREEN (BLIND!)'
  metaprobe probe-fdef-semicolon-blind tools/passivity-check.sh 'if (dsp == 0 && !cont && col == length(nm) + 1) print nm > FDEFS' 'if (dsp == 0 && !cont) print nm > FDEFS' probe-fn-after-semicolon 'mutation probe-fn-after-semicolon: GREEN (BLIND!)'
  metaprobe probe-fdef-top-blind tools/passivity-check.sh 'if (dsp == 0 && !cont && col' 'if (!cont && col' probe-fn-subshell-call 'mutation probe-fn-subshell-call: GREEN (BLIND!)'
  metaprobe probe-fdef-cont-blind tools/passivity-check.sh '&& !cont && col' '&& col' probe-fn-continued 'mutation probe-fn-continued: GREEN (BLIND!)'
  metaprobe probe-fdef-name-blind tools/passivity-check.sh 'if (nm !~ /^[A-Za-z_][A-Za-z0-9_]*$/) return' 'if (0) return' probe-fn-odd-name 'mutation probe-fn-odd-name: GREEN (BLIND!)'
  metaprobe probe-adef-blind tools/passivity-check.sh 'print nm > ADEFS' 'print nm > "/dev/null"' probe-shadow-nested 'mutation probe-shadow-nested: GREEN (BLIND!)'
  metaprobe probe-shadow-all-blind tools/passivity-check.sh 'done < "$tmp/padef"' 'done < "$tmp/pfn"' probe-shadow-nested 'mutation probe-shadow-nested: GREEN (BLIND!)'
  metaprobe probe-fdef-call-blind tools/passivity-check.sh 'if (fdef && VIEW != "") ddef(i, cl);' 'if (0) ddef(i, cl);' probe-ok-fn-toplevel 'mutation probe-ok-fn-toplevel: WRONG-ROW'
  metaprobe probe-pfn-run-blind tools/passivity-check.sh 'pclear; pread "$(tr '"'"'\n'"'"' '"'"' '"'"' < "$tmp/pfn")"' 'pclear; pread ""' probe-ok-trap 'mutation probe-ok-trap: WRONG-ROW'
  metaprobe probe-view-head-blind tools/passivity-check.sh 'if (vclean && t ~ DEFRE) {' 'if (t ~ DEFRE) {' probe-pin-fn-heredoc 'mutation probe-pin-fn-heredoc: GREEN (BLIND!)'
  metaprobe probe-view-head-fill-blind tools/passivity-check.sh 'if (vclean && t ~ DEFRE) {' 'if (t ~ DEFRE) {' probe-no-main-heredoc 'mutation probe-no-main-heredoc: GREEN (BLIND!)'
  metaprobe probe-view-head-reset-blind tools/passivity-check.sh 'if (vclean && t ~ DEFRE) {' 'if (t ~ DEFRE) {' probe-string-head-reset 'mutation probe-string-head-reset: GREEN (BLIND!)'
  metaprobe probe-view-heads-blind tools/passivity-check.sh 'print vfn > VHEADS' 'print vfn > "/dev/null"' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-view-close-blind tools/passivity-check.sh 'if (vclean && t ~ /^}/) vclose = 1' 'if (t ~ /^}/) vclose = 1' probe-pin-fn-close-heredoc 'mutation probe-pin-fn-close-heredoc: GREEN (BLIND!)'
  metaprobe probe-view-close-reset-blind tools/passivity-check.sh 'if (vclose) { vfn = "-"; vclose = 0 }' 'if (vclose) { vclose = 0 }' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
  metaprobe probe-view-comment-blind tools/passivity-check.sh 'vcom = (vclean && t ~ /^[ \t]*#/)' 'vcom = (t ~ /^[ \t]*#/)' probe-string-comment-curl 'mutation probe-string-comment-curl: GREEN (BLIND!)'
  metaprobe probe-view-heredoc-blind tools/passivity-check.sh 'vclean = (hd == "" && dsp == 0 && !DCONT)' 'vclean = (dsp == 0 && !DCONT)' probe-heredoc-body-comment 'mutation probe-heredoc-body-comment: GREEN (BLIND!)'
  metaprobe probe-view-open-blind tools/passivity-check.sh 'vclean = (hd == "" && dsp == 0 && !DCONT)' 'vclean = (hd == "" && !DCONT)' probe-string-comment-line 'mutation probe-string-comment-line: GREEN (BLIND!)'
  metaprobe probe-view-continued-blind tools/passivity-check.sh 'vclean = (hd == "" && dsp == 0 && !DCONT)' 'vclean = (hd == "" && dsp == 0)' probe-continued-comment 'mutation probe-continued-comment: GREEN (BLIND!)'
  metaprobe probe-view-code-blind tools/passivity-check.sh 'if (t != "" && !vcom) print $0 > VIEW' 'if (t != "") print $0 > VIEW' probe-ok-comment 'mutation probe-ok-comment: WRONG-ROW'
  # (m) the main tools are read whole by the same reader (shview, row 6d and every row that reads the code lines): the function of a line, the heads, the comment lines, a definition nested in a function, the body of a here-document with a bare
  #     delimiter (read as text with its expansions as code) and the quotedness of a line with two here-documents are blinded one part at a time. A head in a body or a string is taken for a head again, a comment-looking line in a string, in a
  #     here-document or after a backslash is dropped again, a nested head switches the function again, a bare body is skipped again, the last delimiter alone decides again; the plants of the collector and of the payload of the library
  #     that use exactly that must say GREEN (BLIND!). The reader that decides a clean line is the one of the probe: the blinds of the probe above and these below cut the same lines, and each is shown by a plant of its own.
  metaprobe main-head-blind-heredoc tools/passivity-check.sh 'if (vclean && t ~ DEFRE) {' 'if (t ~ DEFRE) { vfn = "-";' main-head-heredoc-wifi 'mutation main-head-heredoc-wifi: GREEN (BLIND!)'
  metaprobe main-head-blind-block tools/passivity-check.sh 'if (vclean && t ~ DEFRE) {' 'if (t ~ DEFRE) { vfn = "-";' main-head-heredoc-block 'mutation main-head-heredoc-block: GREEN (BLIND!)'
  metaprobe main-head-blind-bare tools/passivity-check.sh 'if (vclean && t ~ DEFRE) {' 'if (t ~ DEFRE) { vfn = "-";' main-head-heredoc-bare 'mutation main-head-heredoc-bare: GREEN (BLIND!)'
  metaprobe main-head-blind-sec6 tools/passivity-check.sh 'if (vclean && t ~ DEFRE) {' 'if (t ~ DEFRE) { vfn = "-";' main-head-heredoc-sec6 'mutation main-head-heredoc-sec6: GREEN (BLIND!)'
  metaprobe main-head-blind-bt tools/passivity-check.sh 'if (vclean && t ~ DEFRE) {' 'if (t ~ DEFRE) { vfn = "-";' main-head-heredoc-bt 'mutation main-head-heredoc-bt: GREEN (BLIND!)'
  metaprobe main-head-blind-single tools/passivity-check.sh 'if (vclean && t ~ DEFRE) {' 'if (t ~ DEFRE) { vfn = "-";' main-head-string-single 'mutation main-head-string-single: GREEN (BLIND!)'
  metaprobe main-head-blind-double tools/passivity-check.sh 'if (vclean && t ~ DEFRE) {' 'if (t ~ DEFRE) { vfn = "-";' main-head-string-double 'mutation main-head-string-double: GREEN (BLIND!)'
  metaprobe main-head-blind-payload tools/passivity-check.sh 'if (vclean && t ~ DEFRE) {' 'if (t ~ DEFRE) { vfn = "-";' main-head-heredoc-payload 'mutation main-head-heredoc-payload: GREEN (BLIND!)'
  metaprobe main-head-blind-string-payload tools/passivity-check.sh 'if (vclean && t ~ DEFRE) {' 'if (t ~ DEFRE) { vfn = "-";' main-head-string-payload 'mutation main-head-string-payload: GREEN (BLIND!)'
  metaprobe main-nested-blind tools/passivity-check.sh 'if (vfn == "-" || VNEST == "") { vfn = nm; print vfn > VHEADS } else {' 'if (1) { vfn = nm; print vfn > VHEADS } else {' main-nested-definition 'mutation main-nested-definition: GREEN (BLIND!)'
  metaprobe main-nested-blind-bt tools/passivity-check.sh 'if (vfn == "-" || VNEST == "") { vfn = nm; print vfn > VHEADS } else {' 'if (1) { vfn = nm; print vfn > VHEADS } else {' main-nested-bt 'mutation main-nested-bt: GREEN (BLIND!)'
  metaprobe main-nested-blind-brace tools/passivity-check.sh 'if (vfn == "-" || VNEST == "") { vfn = nm; print vfn > VHEADS } else {' 'if (1) { vfn = nm; print vfn > VHEADS } else {' main-brace-indented 'mutation main-brace-indented: GREEN (BLIND!)'
  metaprobe main-nested-report-blind tools/passivity-check.sh 'else { print nm > VNEST; vfn = "-" }' 'else { vfn = "-" }' main-nested-definition 'mutation main-nested-definition: GREEN (BLIND!)'
  metaprobe main-nested-function-blind tools/passivity-check.sh 'else { print nm > VNEST; vfn = "-" }' 'else { print nm > VNEST }' main-brace-indented 'mutation main-brace-indented: GREEN (BLIND!)'
  metaprobe main-nested-collect-blind tools/passivity-check.sh 'awk -v F="$_f" '"'"'{ print F ":" $0 }'"'"' "$tmp/e1" >> "$tmp/nested"' ':' main-nested-definition 'mutation main-nested-definition: GREEN (BLIND!)'
  metaprobe main-nested-fill-blind tools/passivity-check.sh 'done < "$tmp/nested"' 'done < /dev/null' main-nested-bt 'mutation main-nested-bt: GREEN (BLIND!)'
  metaprobe main-clean-heredoc-blind tools/passivity-check.sh 'vclean = (hd == "" && dsp == 0 && !DCONT)' 'vclean = (dsp == 0 && !DCONT)' main-head-heredoc-wifi 'mutation main-head-heredoc-wifi: GREEN (BLIND!)'
  metaprobe main-clean-open-blind tools/passivity-check.sh 'vclean = (hd == "" && dsp == 0 && !DCONT)' 'vclean = (hd == "" && !DCONT)' main-head-string-single 'mutation main-head-string-single: GREEN (BLIND!)'
  metaprobe main-clean-continued-blind tools/passivity-check.sh 'vclean = (hd == "" && dsp == 0 && !DCONT)' 'vclean = (hd == "" && dsp == 0)' main-comment-continued 'mutation main-comment-continued: GREEN (BLIND!)'
  metaprobe main-comment-blind-string tools/passivity-check.sh 'vcom = (vclean && t ~ /^[ \t]*#/)' 'vcom = (t ~ /^[ \t]*#/)' main-comment-string 'mutation main-comment-string: GREEN (BLIND!)'
  metaprobe main-comment-blind-string-payload tools/passivity-check.sh 'vcom = (vclean && t ~ /^[ \t]*#/)' 'vcom = (t ~ /^[ \t]*#/)' main-comment-string-payload 'mutation main-comment-string-payload: GREEN (BLIND!)'
  metaprobe main-comment-blind-heredoc tools/passivity-check.sh 'vcom = (vclean && t ~ /^[ \t]*#/)' 'vcom = (t ~ /^[ \t]*#/)' main-comment-heredoc 'mutation main-comment-heredoc: GREEN (BLIND!)'
  metaprobe main-comment-blind-bare tools/passivity-check.sh 'vcom = (vclean && t ~ /^[ \t]*#/)' 'vcom = (t ~ /^[ \t]*#/)' main-comment-heredoc-bare 'mutation main-comment-heredoc-bare: GREEN (BLIND!)'
  metaprobe main-comment-blind-continued tools/passivity-check.sh 'vcom = (vclean && t ~ /^[ \t]*#/)' 'vcom = (t ~ /^[ \t]*#/)' main-comment-continued 'mutation main-comment-continued: GREEN (BLIND!)'
  metaprobe main-heredoc-body-blind tools/passivity-check.sh 'else if (CMDS == "" && MODE == "dyn" && !hdq) hbody(t)' 'else if (0) hbody(t)' main-heredoc-bare-built 'mutation main-heredoc-bare-built: GREEN (BLIND!)'
  metaprobe main-heredoc-body-blind-glob tools/passivity-check.sh 'else if (CMDS == "" && MODE == "dyn" && !hdq) hbody(t)' 'else if (0) hbody(t)' main-heredoc-bare-glob 'mutation main-heredoc-bare-glob: GREEN (BLIND!)'
  metaprobe main-heredoc-body-blind-backtick tools/passivity-check.sh 'else if (CMDS == "" && MODE == "dyn" && !hdq) hbody(t)' 'else if (0) hbody(t)' main-heredoc-bare-backtick 'mutation main-heredoc-bare-backtick: GREEN (BLIND!)'
  metaprobe main-heredoc-bare-blind tools/passivity-check.sh 'else if (CMDS == "" && MODE == "dyn" && !hdq) hbody(t)' 'else if (CMDS == "" && MODE == "dyn") hbody(t)' main-ok-two-heredocs 'mutation main-ok-two-heredocs: WRONG-ROW'
  metaprobe main-heredoc-quoted-blind tools/passivity-check.sh 'hdq = !DHDB }' 'hdq = 0 }' main-ok-heredoc-lines 'mutation main-ok-heredoc-lines: WRONG-ROW'
  metaprobe main-heredoc-last-wins tools/passivity-check.sh 'if (!DHDQ) DHDB = 1;' 'DHDB = !DHDQ;' main-two-heredocs 'mutation main-two-heredocs: GREEN (BLIND!)'
  metaprobe main-heredoc-last-wins-payload tools/passivity-check.sh 'if (!DHDQ) DHDB = 1;' 'DHDB = !DHDQ;' main-two-heredocs-payload 'mutation main-two-heredocs-payload: GREEN (BLIND!)'
  metaprobe probe-heredoc-last-wins tools/passivity-check.sh 'if (!DHDQ) DHDB = 1;' 'DHDB = !DHDQ;' probe-heredoc-two-bodies 'mutation probe-heredoc-two-bodies: GREEN (BLIND!)'
  metaprobe probe-heredoc-last-wins-backtick tools/passivity-check.sh 'if (!DHDQ) DHDB = 1;' 'DHDB = !DHDQ;' probe-heredoc-two-backtick 'mutation probe-heredoc-two-backtick: GREEN (BLIND!)'
  metaprobe main-heredoc-text-blind tools/passivity-check.sh 'if (top == "d" || top == "H") { dtext(c); continue }' 'if (top == "d") { dtext(c); continue }' main-ok-heredoc-plain 'mutation main-ok-heredoc-plain: WRONG-ROW'
  metaprobe main-heredoc-end-blind tools/passivity-check.sh 'function hend() { if (!hbo) return; hbo = 0; dsp = hbi; dpop(); DCONT = 0 }' 'function hend() { if (!hbo) return; hbo = 0; DCONT = 0 }' main-ok-nested-function 'mutation main-ok-nested-function: WRONG-ROW'
  metaprobe main-heredoc-line-end-blind tools/passivity-check.sh 'if (top != "q" && top != "d" && top != "H") { dfin();' 'if (top != "q" && top != "d") { dfin();' main-ok-heredoc-plain 'mutation main-ok-heredoc-plain: WRONG-ROW'
  metaprobe main-view-verdicts-blind tools/passivity-check.sh 'cat "$tmp/b1" >> "$tmp/dyn_bad"; cat "$tmp/b2" >> "$tmp/dyn_bad2"' 'cat "$tmp/b1" >> "$tmp/dyn_bad"' main-heredoc-bare-glob 'mutation main-heredoc-bare-glob: GREEN (BLIND!)'
  metaprobe main-view-builtin-blind tools/passivity-check.sh 'cat "$tmp/b1" >> "$tmp/dyn_bad"; cat "$tmp/b2" >> "$tmp/dyn_bad2"' 'cat "$tmp/b2" >> "$tmp/dyn_bad2"' main-ok-nested-function 'mutation main-ok-nested-function: WRONG-ROW'
  metaprobe main-view-heads-blind tools/passivity-check.sh 'awk -v F="$_f" '"'"'{ print F ":" $0 }'"'"' "$tmp/h1" >> "$tmp/fns"' ': > "$tmp/h1"' main-ok-nested-function 'mutation main-ok-nested-function: WRONG-ROW'
  metaprobe main-iw-default-blind tools/passivity-check.sh 'if (index(codepart(t), L) > 0) n++' 'if (index(t, L) > 0) n++' main-iw-default-comment 'mutation main-iw-default-comment: GREEN (BLIND!)'
  metaprobe main-iw-guard-comment-blind tools/passivity-check.sh 'index(codepart(t), G) > 0) ok = 1' 'index(t, G) > 0) ok = 1' main-iw-guard-comment 'mutation main-iw-guard-comment: GREEN (BLIND!)'
  metaprobe main-iw-guard-head-blind tools/passivity-check.sh 'if (fn == "build_from_iwscan" && t ~ /^build_from_iwscan' 'if (t ~ /^build_from_iwscan' main-iw-guard-fake-head 'mutation main-iw-guard-fake-head: GREEN (BLIND!)'
  metaprobe main-iw-guard-line-blind tools/passivity-check.sh 'if (ln + 0 == hl + 1 && index(' 'if (index(' main-iw-guard-moved 'mutation main-iw-guard-moved: GREEN (BLIND!)'
  # (m) the script texts (a function head at the start of a line in a here-document body or a string, and the text from there to its end read as code once more), one part at a time: the head in a body, the head in a string, the second
  #     reading and what it hands back (the built names, the globs), the hand-over of the lines, the two ways a segment begins, the heads that stay out of the functions of the file, and the delimiters that the shell reads otherwise
  metaprobe main-script-head-blind tools/passivity-check.sh 'u != hd && (hscr || t ~ DEFRE))' 'u != hd && (hscr || 0))' main-script-quoted-built 'mutation main-script-quoted-built: GREEN (BLIND!)'
  metaprobe main-script-head-blind-bare tools/passivity-check.sh 'u != hd && (hscr || t ~ DEFRE))' 'u != hd && (hscr || 0))' main-script-bare-built 'mutation main-script-bare-built: GREEN (BLIND!)'
  metaprobe main-script-head-blind-payload tools/passivity-check.sh 'u != hd && (hscr || t ~ DEFRE))' 'u != hd && (hscr || 0))' main-script-quoted-payload 'mutation main-script-quoted-payload: GREEN (BLIND!)'
  metaprobe main-script-head-blind-handler tools/passivity-check.sh 'u != hd && (hscr || t ~ DEFRE))' 'u != hd && (hscr || 0))' main-script-handler 'mutation main-script-handler: GREEN (BLIND!)'
  metaprobe main-script-string-blind tools/passivity-check.sh 'DST[dsp] == "d") && t ~ DEFRE) sstr = dsp' 'DST[dsp] == "d") && 0) sstr = dsp' main-script-string-built 'mutation main-script-string-built: GREEN (BLIND!)'
  metaprobe main-script-string-blind-payload tools/passivity-check.sh 'DST[dsp] == "d") && t ~ DEFRE) sstr = dsp' 'DST[dsp] == "d") && 0) sstr = dsp' main-script-string-payload 'mutation main-script-string-payload: GREEN (BLIND!)'
  metaprobe main-script-reading-blind tools/passivity-check.sh 'if [ -s "$tmp/s1" ]; then' 'if false; then' main-script-quoted-built 'mutation main-script-quoted-built: GREEN (BLIND!)'
  metaprobe main-script-handover-blind tools/passivity-check.sh '"@" sseg substr($0, p) > SCRF' '"@" sseg substr($0, p) > "/dev/null"' main-script-quoted-built 'mutation main-script-quoted-built: GREEN (BLIND!)'
  metaprobe main-script-built-blind tools/passivity-check.sh 'awk "$UNMARK" "$tmp/k1" >> "$tmp/dyn_bad"; awk "$UNMARK" "$tmp/k2" >> "$tmp/dyn_bad2"' 'awk "$UNMARK" "$tmp/k2" >> "$tmp/dyn_bad2"' main-script-quoted-built 'mutation main-script-quoted-built: GREEN (BLIND!)'
  metaprobe main-script-glob-blind tools/passivity-check.sh 'awk "$UNMARK" "$tmp/k1" >> "$tmp/dyn_bad"; awk "$UNMARK" "$tmp/k2" >> "$tmp/dyn_bad2"' 'awk "$UNMARK" "$tmp/k1" >> "$tmp/dyn_bad"' main-script-quoted-glob 'mutation main-script-quoted-glob: GREEN (BLIND!)'
  metaprobe main-script-segment-head-blind tools/passivity-check.sh 'if (h || sclose) sseg++' 'if (sclose) sseg++' main-script-reset-head 'mutation main-script-reset-head: GREEN (BLIND!)'
  metaprobe main-script-segment-close-blind tools/passivity-check.sh 'if (h || sclose) sseg++' 'if (h) sseg++' main-script-reset-close 'mutation main-script-reset-close: GREEN (BLIND!)'
  metaprobe main-script-nested-blind tools/passivity-check.sh 'if (h || sclose) sseg++' 'if (0) sseg++' main-script-nested 'mutation main-script-nested: GREEN (BLIND!)'
  metaprobe main-script-heads-blind tools/passivity-check.sh 'cat "$tmp/t1" >> "$tmp/sheads"' 'cat "$tmp/t1" >> "$tmp/sheads"; awk -v F="$_f" '"'"'{ print F ":" $0 }'"'"' "$tmp/t1" >> "$tmp/fns"' main-script-head-decoy 'mutation main-script-head-decoy: GREEN (BLIND!)'
  metaprobe main-odd-delimiter-blind tools/passivity-check.sh 'else if (ODDF != "" && !DHDQ' 'else if (0 && !DHDQ' main-odd-delimiter 'mutation main-odd-delimiter: GREEN (BLIND!)'
  metaprobe main-odd-delimiter-blind-payload tools/passivity-check.sh 'else if (ODDF != "" && !DHDQ' 'else if (0 && !DHDQ' main-odd-delimiter-payload 'mutation main-odd-delimiter-payload: GREEN (BLIND!)'
  metaprobe main-odd-delimiter-blind-expansion tools/passivity-check.sh 'else if (ODDF != "" && !DHDQ' 'else if (0 && !DHDQ' main-odd-delimiter-expansion 'mutation main-odd-delimiter-expansion: GREEN (BLIND!)'
  metaprobe main-odd-delimiter-report-blind tools/passivity-check.sh 'done < "$tmp/odd.u"' 'done < /dev/null' main-odd-delimiter 'mutation main-odd-delimiter: GREEN (BLIND!)'
  printf 'passivity meta probe: %s/%s blinded checkers detected\n' "$nmok" "$nm"
  [ "$nm" -ge 2 ] && [ "$nmok" = "$nm" ]; exit $?
fi

# ============================== unmutated image first ==============================
if [ -z "$sel" ]; then
  run_check "$base" > "$tmp/base.out" 2>&1; brc=$?
  bpass=$(grep -c ' PASS$' "$tmp/base.out"); bfail=$(grep -c ' FAIL$' "$tmp/base.out")
  # every pinned row name must exist as a PASS row here, or the table talks about rows that are gone (phantom)
  phantom=""; _ifs=$IFS; IFS='|'
  for _p in $ROWS; do _p=$_p awk 'index($0, ENVIRON["_p"]) == 1 { f = 1 } END { exit !f }' "$tmp/base.out" || phantom="$phantom [$_p]"; done
  IFS=$_ifs
  printf 'unmutated image: checker exit %s, %s PASS rows (≥ %s), %s FAIL, rows not printed:%s\n' "$brc" "$bpass" "$MIN_ROWS" "$bfail" "${phantom:- none}"
  if [ "$brc" != 0 ] || [ "$bpass" -lt "$MIN_ROWS" ] || [ -n "$phantom" ]; then
    echo "passivity mutation probe: the unmutated copy is not green (or a pinned row name is gone): nothing to compare against" >&2
    sed 's/^/    /' "$tmp/base.out" | cut -c1-160 >&2; exit 1
  fi
fi

# ============================== the table: Name | file | mutation | rows that must be red ==============================
# name             | file               | kind      | text (old / new)                                        | expected red rows
# ---- page: the network surface
mut post-bare        starchorus.html    append   'var zz = {method:"POST"};' ''                                  'HTML network surface'
mut fetch-post       starchorus.html    append   'fetch("/x",{method:"POST"});' ''                               'HTML network surface|fetch( ='
mut fetch-second     starchorus.html    append   'fetch("starchorus.json");' ''                                       'fetch( ='
mut fetch-target     starchorus.html    subst    'fetch("starchorus.json?_=' 'fetch("starchorus.json.bak?_='               'fetch( ='
mut doc-location     starchorus.html    append   'document.location = "/cgi-bin/x?c=1";' ''                      'other network APIs'
mut window-open      starchorus.html    append   'window.open("/x");' ''                                         'other network APIs'
mut anchor-click     starchorus.html    append   'document.createElement("a").click();' ''                       'other network APIs'
mut new-image        starchorus.html    append   'new Image().src="/x";' ''                                      'other network APIs'
mut new-image-abs    starchorus.html    append   'new Image().src="http://127.0.0.1:9/x";' ''                    'other network APIs|URLs outside'
mut url-outside      starchorus.html    append   '// https://example.invalid/' ''                                'URLs outside'
mut denylist-entry   starchorus.html    denylist '' ''                                                           '§14.7 denylist'
# ---- collector: transmit tools, opt-in scan, device CLI, read-only recon.db
mut transmit-tool    starchorus-collect.sh     fnappend 'aireplay-ng -0 1 wlan0mon' ''                                  'transmit tools invoked'
mut iw-scan-stray    starchorus-collect.sh     fnappend 'iw dev wlan0 scan' ''                                          'iw scan opt-in'
mut default-flip     starchorus-collect.sh     subst    'ALLOW_ACTIVE=${STARCHORUS_ALLOW_ACTIVE:-0}' 'ALLOW_ACTIVE=${STARCHORUS_ALLOW_ACTIVE:-1}' 'iw scan opt-in'
mut guard-removed    starchorus-collect.sh     subst    '[ "$ALLOW_ACTIVE" = "1" ] || return 1' ':'                      'iw scan opt-in'
mut apcli-call       starchorus-collect.sh     fnappend '_pineap RECON ALL' ''                                          '§14.6 device calls'
mut readonly-gone    starchorus-collect.sh     subst    'sqlite3 -readonly -noheader' 'sqlite3 -noheader'               'sqlite3 read-only'
mut sqlite-write-fn  starchorus-collect.sh     fnappend 'sqlite3 "$db" "DELETE FROM t"' ''                              'sqlite3 read-only'
mut sqlite-vanished  starchorus-collect.sh     subst    'sqlite3 -readonly -noheader' 'sq_lite -readonly -noheader'     'sqlite3 read-only'
mut sqlite-comment-flag starchorus-collect.sh  fnappend 'sqlite3 "$db" "DELETE FROM t" # -readonly' ''                   'sqlite3 read-only'
mut sqlite-two-calls starchorus-collect.sh     fnappend 'sqlite3 -readonly a "SELECT 1"; sqlite3 "$db" "DELETE FROM t"' '' 'sqlite3 read-only'
mut sqlite-flag-in-string starchorus-collect.sh fnappend 'sqlite3 "$db" "SELECT '"'"'-readonly '"'"'"' ''                'sqlite3 read-only'
mut sqlite-after-hash starchorus-collect.sh    fnappend 'printf "%s #" x; sqlite3 "$db" "DELETE FROM t"' ''            'sqlite3 read-only'
# ---- the firmware's outward commands by prefix: a prefix hits what it has not listed by name (WIFI_PCAP_ + anything)
mut prefix-family    starchorus-collect.sh     fnappend 'WIFI_PCAP_NEW_VERB x' ''                                       '§14.6 device calls'
mut prefix-vpn       starchorus-collect.sh     fnappend 'OPENVPN_NEW_VERB x' ''                                         '§14.6 device calls'
# ---- the Bluetooth stack, denied BY TOOL (§14.6). Fourteen mutations of the table that fixed it, in its order (the last column is the one row that turns red);
# the targets of the ones written `mutr1` are lines of the collector's Bluetooth code (bt_begin, bt_end, the fifth apcli_ro line), so they wait as PENDING
# while the checker announces them. The texts that would trip the guard at the top of this script when written out (a command word
# followed by a blank: the shell's re-reading, running and sourcing words, also inside the name of a mutation) are written with an empty pair of quotes in them.
mutr1 bt-active-scan     starchorus-collect.sh     subst    'lescan --passive --duplicates > /dev/null 2> "$BT_F.err" &' 'lescan --duplicates > /dev/null 2> "$BT_F.err" &' 'Bluetooth lines in bt_begin'
mutr1 bt-extra-line      starchorus-collect.sh     subst    'BT_SPID=$!; BT_ARM=""' 'BT_SPID=$!; BT_ARM=""; timeout -s INT 8 hcitool -i hci0 lescan --passive --duplicates --privacy > /dev/null &' 'Bluetooth lines in bt_begin'
mut   bt-outside         starchorus-collect.sh     fnappend 'btmon -i hci0 > /dev/null &' ''                                '§14.6b Bluetooth words'
mut   bt-display         starchorus-display.sh     fnappend 'hcitool -i hci0 lescan --passive' ''                           '§14.6b Bluetooth words'
mut   bt-undefined       tools/passivity-check.sh  subst    "BT_FUNCS=' bt_begin" "BT_FUNCS=' zz_undefined bt_begin"        'Bluetooth allowlist names'
mutr1 bt-var-name        starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); bt_x=hcitool'               'Bluetooth word forms'
mutr1 bt-var-"ex"ec      starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); "$BT_TOOL" -i hci0 lescan'  'Bluetooth wrappers|§14.6d command words'
mutr1 bt-"ev"al          starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); ev''al "$bt_c"'              'Bluetooth wrappers'
mutr1 bt-busybox         starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); busybox sh -c "$bt_c"'      'Bluetooth wrappers'
mutr1 bt-timeout-outside starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); timeout 5 sleep 1'          'Bluetooth wrappers'
# the spec names no unique line of bt_selftest, so the line is added as its first: the planted tool word is a command there
mutr1 bt-selftest-cmd    starchorus-collect.sh     fnline   'bt_selftest' 'hcitool -i hci0 dev'                             'Bluetooth command position'
mutr1 apcli-extra-arg    starchorus-collect.sh     subst    'RECON CHANNELS format=json ;;' 'RECON CHANNELS format=json all ;;' 'apcli_ro literal lines|§14.6d command words'
mut   apcli-fifth-line   starchorus-collect.sh     subst    'ap_to=""; have timeout && ap_to="timeout 10"' 'ap_to=""; have timeout && ap_to="timeout 10"; $ap_to _pineap RECON CLIENTS format=json' 'apcli_ro literal lines|§14.6d command words'
mutr1 apcli-variable-prefix starchorus-collect.sh  subst    '$ap_to _pineap RECON CHANNELS' '$ap_x _pineap RECON CHANNELS'    'apcli_ro literal lines|§14.6d command words'
# ---- the same rules proven on the base before the collector has the functions: a function of BT_FUNCS is DEFINED in the copy with one bad line
mut   bt-begin-planted   starchorus-collect.sh     fndef    'bt_begin' 'timeout -s INT 8 hcitool -i hci0 lescan --duplicates > /dev/null &' 'Bluetooth lines in bt_begin'
mut   bt-form-planted    starchorus-collect.sh     fndef    'bt_busy' 'bt_x=hcitool'                                         'Bluetooth word forms'
mut   bt-varexec-planted starchorus-collect.sh     fndef    'bt_sweep' '"$BT_TOOL" -i hci0 lescan'                           'Bluetooth wrappers|§14.6d command words'
mut   bt-eval-planted    starchorus-collect.sh     fndef    'bt_sweep' 'ev''al "$bt_c"'                                       'Bluetooth wrappers'
mut   bt-timeout-planted starchorus-collect.sh     fndef    'bt_busy' 'timeout 5 sleep 1'                                    'Bluetooth wrappers'
mut   bt-cmdpos-planted  starchorus-collect.sh     fndef    'bt_stub' 'hcitool -i hci0 dev'                                  'Bluetooth command position'
# ---- the review's finding: every tool of the stack is denied by NAME, whatever the verb (one line each; the alternative probe below has every
# name once). The transmit row still sees the verbs it lists; the rest is seen by the tool rule alone.
mut bt-tool-bluetoothctl starchorus-collect.sh     fnappend 'bluetoothctl scan le; bluetoothctl scan bredr; bluetoothctl advertise on; bluetoothctl connect 02:00:00:00:00:01; bluetoothctl pair 02:00:00:00:00:01' '' '§14.6b Bluetooth words'
mut bt-tool-sdp-rfcomm   starchorus-collect.sh     fnappend 'sdptool browse local; rfcomm connect hci0 02:00:00:00:00:01; btgatt-client -d 02:00:00:00:00:01; l2test -n 02:00:00:00:00:01; rctest -n 02:00:00:00:00:01' '' '§14.6b Bluetooth words'
mut bt-tool-gatt-mgmt    starchorus-collect.sh     fnappend 'gatttool -b 02:00:00:00:00:01 -I; btmgmt power on; hciconfig hci0 up' '' 'transmit tools invoked|§14.6b Bluetooth words'
mut bt-transmit      starchorus-collect.sh     fnappend 'l2ping -c 1 x' ''                                              'transmit tools invoked|§14.6b Bluetooth words'
mut bt-hcitool-scan  starchorus-collect.sh     fnappend 'hcitool scan' ''                                               'transmit tools invoked|§14.6b Bluetooth words'
mut bt-hcitool-lescan starchorus-collect.sh    fnappend 'hcitool lescan' ''                                             '§14.6b Bluetooth words'
mut bt-hcitool-lescan-opt starchorus-collect.sh fnappend 'hcitool lescan --duplicates --passive' ''                     '§14.6b Bluetooth words'
mut bt-hcitool-passive-outside starchorus-collect.sh fnappend 'hcitool lescan --passive' ''                             '§14.6b Bluetooth words'
mut bt-hcitool-other starchorus-collect.sh     fnappend 'hcitool name x' ''                                             '§14.6b Bluetooth words'
mut bt-hcitool-second starchorus-collect.sh    fnappend 'hcitool lescan --passive; hcitool name x' ''                   '§14.6b Bluetooth words'
mut bt-hcitool-display starchorus-display.sh   fnappend 'hcitool lescan' ''                                             '§14.6b Bluetooth words'
mut bt-hcitool-helper library/user/reconnaissance/starchorus/helper newfile 'hcitool name x' ''                         '§14.6b Bluetooth words'
mut bt-btmon-write   starchorus-collect.sh     fnappend 'btmon -w /tmp/x' ''                                            '§14.6b Bluetooth words'
mut bt-hciconfig-up  starchorus-collect.sh     fnappend 'hciconfig hci0 up' ''                                          'transmit tools invoked|§14.6b Bluetooth words'
mut bt-hciconfig-a-up starchorus-collect.sh    fnappend 'hciconfig -a hci0 leadv' ''                                    'transmit tools invoked|§14.6b Bluetooth words'
mut bt-hciconfig-read starchorus-collect.sh    fnappend 'hciconfig -a | head -n 5; hciconfig; hciconfig -a >/tmp/x' ''  '§14.6b Bluetooth words'
# ---- the second review's bypasses: a tool name split by quotes, a backslash or a string join (read on the normal form of the line), the D-Bus route to
# bluetoothd (denied by the names of the bus tools and of the service), and inside the functions of the allowlist a command word that is built when the line
# runs (a `$( )` or backtick expansion, quoted or not, a glob) or that goes through `time`. The two controls are an assignment from a substitution and a substitution
# as an argument: neither is a command word.
mut bt-split-quote       starchorus-collect.sh     fnappend "hc''itool -i hci0 cmd 8 0x0c" ''                               '§14.6b Bluetooth words'
mut bt-split-backslash   starchorus-collect.sh     fnappend 'hc\itool -i hci0 cmd 8 0x0c' ''                                '§14.6b Bluetooth words'
mut bt-split-dq          starchorus-collect.sh     fnappend '"hci""tool" -i hci0 cmd 8 0x0c' ''                             '§14.6b Bluetooth words'
mut bt-sh-c-split        starchorus-collect.sh     fnappend "sh -c 'hci''tool -i hci0 cmd 8 0x0c'" ''                       '§14.6b Bluetooth words'
mut bt-awk-system        starchorus-collect.sh     fnappend 'awk "BEGIN { system(\"hci\" \"tool -i hci0 cmd\") }"' ''      '§14.6b Bluetooth words'
mut bt-split-display     starchorus-display.sh     fnappend "hc''itool -i hci0 cmd 8 0x0c" ''                               '§14.6b Bluetooth words'
mut bt-dbus-send         starchorus-collect.sh     fnappend 'dbus-send --system --dest=org.bluez /org/bluez/hci0 org.bluez.Adapter1.StartDiscovery' '' '§14.6b Bluetooth words'
mut bt-busctl            starchorus-collect.sh     fnappend 'busctl call org.bluez /org/bluez/hci0 org.bluez.Adapter1 StartDiscovery' '' '§14.6b Bluetooth words'
mut bt-cmd-subst         starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); $(bt_pick) -i hci0 lescan'  'Bluetooth wrappers|§14.6d command words'
mut bt-cmd-subst-quoted  starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); "$(bt_pick)" -i hci0 lescan' 'Bluetooth wrappers|§14.6d command words'
mut bt-cmd-backtick      starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); `bt_pick` -i hci0 lescan'   'Bluetooth wrappers|§14.6d command words'
mut bt-time              starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); time "$BT_TOOL" -i hci0 lescan' 'Bluetooth wrappers|§14.6d command words'
mut bt-glob              starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); /usr/bin/hcito?l -i hci0 lescan' 'Bluetooth wrappers|§14.6e command names'
mut bt-stub-glob         starchorus-collect.sh     fnline   'bt_stub' '/usr/bin/hcito?l -i hci0 dev'                         'Bluetooth wrappers|§14.6e command names'
mut bt-ok-assign         starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); zz_x=$(bt_now); zz_y="$(bt_now)"' ''
mut bt-ok-argument       starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); echo "$(bt_now)" > /dev/null; echo "[$(bt_now)] arm [$bt_t0]" > /dev/null' ''
# ---- a command whose NAME is built when the line runs, anywhere in the scope (row '§14.6d': every simple command whose command word holds an expansion, against a
# pinned list). dyn-split-name is the review's plant: a function outside BT_FUNCS puts `hci` and `tool` together and starts the result, a name that no line spells.
# Then every form the row reads: a variable, `${ }`, `$( )`, a backtick expression, a word that only starts with a path, behind a wrapper word, behind `NAME=value`, after a
# pipe, in a case arm, inside a substitution, behind a redirection, on the line after a pipe, outside every function, in the other shell files of the scope; and the
# pinned list itself (an edited pinned line, a vanished one, a second copy of one). The controls stay green: assignments from a substitution, expansions as arguments, a
# `$` word in a case pattern, a `$` inside quotes, a quote that goes on over two lines. The two limits are controls too, so that they are written down in a test: a built
# string handed to eval or to an awk system() is not read (SECURITY.md says so). Names and texts that would trip the guard at the top of this script are written with an empty pair of quotes.
mut dyn-split-name       starchorus-collect.sh     fnappend 'zz_a=hci; zz_b=tool; "$zz_a$zz_b" -i hci0 lescan'            '' '§14.6d command words'
mut dyn-var-name         starchorus-collect.sh     fnappend '$zz_cmd -i hci0 lescan'                                      '' '§14.6d command words'
mut dyn-braced           starchorus-collect.sh     fnappend '${zz_cmd} -i hci0 lescan'                                    '' '§14.6d command words'
mut dyn-subst            starchorus-collect.sh     fnappend '$(zz_pick) -i hci0 lescan'                                   '' '§14.6d command words'
mut dyn-subst-quoted     starchorus-collect.sh     fnappend '"$(zz_pick)" -i hci0 lescan'                                 '' '§14.6d command words'
mut dyn-backtick         starchorus-collect.sh     fnappend '`zz_pick` -i hci0 lescan'                                    '' '§14.6d command words'
mut dyn-path-prefix      starchorus-collect.sh     fnappend '/usr/bin/hci$zz_b -i hci0 lescan'                            '' '§14.6d command words'
mut dyn-wrapper-nice     starchorus-collect.sh     fnappend 'nice "$zz_a$zz_b" -i hci0 lescan'                            '' '§14.6d command words'
mut dyn-wrapper-env      starchorus-collect.sh     fnappend 'env X=1 "$zz_a$zz_b" -i hci0 lescan'                         '' '§14.6d command words'
mut dyn-wrapper-"ex"ec   starchorus-collect.sh     fnappend 'ex''ec "$zz_a$zz_b" -i hci0 lescan'                          '' '§14.6d command words'
mut dyn-wrapper-timeout  starchorus-collect.sh     fnappend 'timeout -s INT 6 "$zz_a$zz_b" -i hci0 lescan'                '' '§14.6d command words'
mut dyn-assign-prefix    starchorus-collect.sh     fnappend 'zz_x=1 "$zz_a$zz_b" -i hci0 lescan'                          '' '§14.6d command words'
mut dyn-subst-prefix     starchorus-collect.sh     fnappend 'zz_x=$(zz_f) "$zz_a$zz_b" -i hci0 lescan'                    '' '§14.6d command words'
mut dyn-pipe             starchorus-collect.sh     fnappend 'echo x | "$zz_a$zz_b" -i hci0 lescan'                        '' '§14.6d command words'
mut dyn-case-arm         starchorus-collect.sh     fnappend 'case x in x) "$zz_a$zz_b" -i hci0 lescan ;; esac'           '' '§14.6d command words'
mut dyn-in-substitution  starchorus-collect.sh     fnappend 'zz_x=$("$zz_a$zz_b" -i hci0 lescan)'                         '' '§14.6d command words'
mut dyn-redirect-first   starchorus-collect.sh     fnappend '>/dev/null "$zz_a$zz_b" -i hci0 lescan'                      '' '§14.6d command words'
mut dyn-continued        starchorus-collect.sh     fnappend 'echo x |
    "$zz_a$zz_b" -i hci0 lescan'                                                                                        '' '§14.6d command words'
mut dyn-top-level        starchorus-collect.sh     append   '"$zz_a$zz_b" -i hci0 lescan'                                 '' '§14.6d command words'
mut dyn-display          starchorus-display.sh     fnappend '"$zz_a$zz_b" -i hci0 lescan'                                 '' '§14.6d command words'
mut dyn-payload          library/user/reconnaissance/starchorus/payload.sh fnappend '"$zz_a$zz_b" -i hci0 lescan'         '' '§14.6d command words'
mut dyn-serve            starchorus-serve.sh       fnappend '"$zz_a$zz_b" -i hci0 lescan'                                 '' '§14.6d command words'
mut dyn-helper           library/user/reconnaissance/starchorus/helper newfile '"$zz_a$zz_b" -i hci0 lescan'              '' '§14.6d command words'
mut dyn-pin-edited       payload.sh                subst    'NICE uhttpd -f -p' 'NICE "$zz_a$zz_b" -f -p'                      '§14.6d command words'
mut dyn-pin-gone         payload.sh                subst    '$NICE busybox httpd' 'nice busybox httpd'                         '§14.6d command words'
mut dyn-pin-twice        payload.sh                append   '$NICE ./starchorus-collect.sh >/dev/null 2>"$STARCHORUS_DIR/collect.log" &' '' '§14.6d command words'
mut dyn-ok-assign        starchorus-collect.sh     fnappend 'zz_x=$(zz_f); zz_y="$(zz_f)"; zz_n=$(( $(zz_f) + 30 ))'      '' ''
mut dyn-ok-argument      starchorus-collect.sh     fnappend 'echo "$(zz_f)" "$zz_x" $zz_y; command -v "$zz_x" > /dev/null; for zz_i in "$@"; do echo "$zz_i"; done' '' ''
mut dyn-ok-case-pattern  starchorus-collect.sh     fnappend 'case "$zz_x" in $zz_y|z) : ;; esac'                          '' ''
mut dyn-ok-quoted-text   starchorus-collect.sh     fnappend "echo '\$zz_a \$(zz_c) \"\$zz_b\"'"                           '' ''
mut dyn-ok-multiline     starchorus-collect.sh     fnappend 'echo "a
    $zz_b c"'                                                                                                           '' ''
mut dyn-limit-"ev"al     starchorus-collect.sh     fnappend 'ev''al "$zz_a$zz_b -i hci0 lescan"'                          '' ''
mut dyn-limit-awk        starchorus-collect.sh     fnappend "awk -v zz_c=\"\$zz_a\$zz_b\" 'BEGIN { system(zz_c \" -i hci0 lescan\") }'" '' ''
# ---- the second row of the same pass (§14.6e): a name that a glob, find, xargs or an alias makes when the line runs. The review's plants, each in a function outside the
# allowlist: a glob character in the command word (`?`, `[`, `*`; the Wi-Fi side too: a bracket in `iw`), `find` with `-exec`, `-execdir`, `-ok` or `-okdir`, `xargs` whose
# command is the replacement string (`{}` and a string of its own) or is missing, and an alias. Quoted names do not hide a wrapper ("exec" "$x"). The controls stay green: a glob in
# a for-list, in a case pattern or as an argument, the test `[ ]` and `[[ ]]`, a `${ }` that holds a blank or a parenthesis, `find` without `-exec`, `xargs` with a command of its
# own, `alias` that only looks. The two limits are controls as well: a glob that is only handed to `ln` and a built string piped into `sh` are not read (SECURITY.md says so).
# The texts that would trip the guard at the top of this script (the word before a blank) are written with an empty pair of quotes.
mut dyn-glob             starchorus-collect.sh     fnappend '/usr/bin/hc?tool -i hci0 lescan'                             '' '§14.6e command names'
mut dyn-glob-star        starchorus-collect.sh     fnappend '/usr/bin/hci* -i hci0 lescan'                                '' '§14.6e command names'
mut dyn-bracket          starchorus-collect.sh     fnappend '/usr/bin/hci[t]ool -i hci0 lescan'                           '' '§14.6e command names'
mut dyn-iw-glob          starchorus-collect.sh     fnappend '/usr/sbin/i[w] dev wlan1mon scan'                            '' '§14.6e command names'
mut dyn-find-"ex"ec      starchorus-collect.sh     fnappend 'find /usr/bin -name hci\*l -ex''ec {} -i hci0 lescan \;'       '' '§14.6e command names'
mut dyn-find-execdir     starchorus-collect.sh     fnappend 'find /usr/bin -name hci\*l -execdir {} -i hci0 lescan \;'      '' '§14.6e command names'
mut dyn-find-ok          starchorus-collect.sh     fnappend 'find /usr/bin -name hci\*l -ok {} -i hci0 lescan \;'           '' '§14.6e command names'
mut dyn-find-okdir       starchorus-collect.sh     fnappend 'find /usr/bin -name hci\*l -okdir {} -i hci0 lescan \;'        '' '§14.6e command names'
mut dyn-xargs-placeholder starchorus-collect.sh    fnappend 'printf "%s\n" tool | xargs -I{} {} -i hci0 lescan'           '' '§14.6e command names'
mut dyn-xargs-custom     starchorus-collect.sh     fnappend 'printf "%s\n" tool | xargs -I X X -i hci0 lescan'             '' '§14.6e command names'
mut dyn-xargs-missing    starchorus-collect.sh     fnappend 'printf "%s\n" tool | xargs -n 1'                              '' '§14.6e command names'
mut dyn-alias            starchorus-collect.sh     fnappend 'alias zz_s="$zz_a$zz_b"; zz_s -i hci0 lescan'                '' '§14.6e command names'
mut dyn-wrapper-quoted   starchorus-collect.sh     fnappend '"exec" "$zz_a$zz_b" -i hci0 lescan'                          '' '§14.6d command words'
mut dyn-ok-glob-for      starchorus-collect.sh     fnappend 'for zz_f in /usr/bin/hci* /tmp/zz?; do echo "$zz_f"; done'    '' ''
mut dyn-ok-glob-case     starchorus-collect.sh     fnappend 'case "$zz_x" in a*|b?) : ;; [0-9]*) : ;; *) : ;; esac'        '' ''
mut dyn-ok-glob-arg      starchorus-collect.sh     fnappend 'ls /usr/bin/hci* > /dev/null; rm -f /tmp/zz_*.tmp; echo ?'    '' ''
mut dyn-ok-test-bracket  starchorus-collect.sh     fnappend '[ -f /tmp/x ] && [ -d /tmp ] || [[ "$zz_a" = a* ]]; zz_t=$([ -n "$zz_a" ] && echo y)' '' ''
mut dyn-ok-param-expansion starchorus-collect.sh   fnappend 'zz_y=${zz_x%) *}; zz_m=${zz_n%% *}; zz_p=${zz_q##*") "}; zz_r="${zz_s:-a b)}"' '' ''
mut dyn-ok-find-plain    starchorus-collect.sh     fnappend 'find /tmp -name "*.zz" -print; find . -type f | sort; echo find -ex''ec' '' ''
mut dyn-ok-xargs-literal starchorus-collect.sh     fnappend 'printf "%s\n" a | xargs rm -f; printf "%s\n" a | xargs -I{} echo {}; printf "%s\n" a | xargs -n 1 -P 2 -- echo' '' ''
mut dyn-ok-alias-lookup  starchorus-collect.sh     fnappend 'alias; alias -p; alias zz_s'                                 '' ''
mut dyn-limit-ln         starchorus-collect.sh     fnappend 'ln -sf /usr/bin/hc?tool /tmp/zz_t; /tmp/zz_t -i hci0 lescan' '' ''
mut dyn-limit-pipe-sh    starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_a$zz_b -i hci0 lescan" | sh'               '' ''
# ---- the pinned lines of the transmit row (the airmon-ng last resort of create_monitor, the Nmap OUI path): an edited one, one that is gone, one more copy elsewhere
mut tx-pin-edited        starchorus-collect.sh     subst    'out=$(airmon-ng start "$base" 2>/dev/null)' 'out=$(airmon-ng start "$base" check kill 2>/dev/null)' 'transmit tools invoked'
mut tx-pin-gone          starchorus-collect.sh     subst    'if have airmon-ng; then' 'if have zz_mon; then'                  'transmit tools invoked'
mut tx-pin-elsewhere     starchorus-collect.sh     fnappend 'out=$(airmon-ng start "$base" 2>/dev/null)'                    '' 'transmit tools invoked'
# ---- display script (one of the two copies; the cmp of the copies belongs to static checks, not here)
mut display-transmit starchorus-display.sh       fnappend 'mdk4 wlan0mon d' ''                                            'transmit tools invoked'
# ---- the listener (starchorus-serve.sh is in the §14.6 shell scope: a transmit tool in it is seen, and losing it from the list is named)
mut serve-transmit   starchorus-serve.sh       fnappend 'aireplay-ng -0 1 wlan0mon' ''                                  'transmit tools invoked'
# ---- the payload directory ships to the device as a whole: its payload.sh and a helper WITHOUT the .sh suffix are in scope
mut library-payload-transmit library/user/reconnaissance/starchorus/payload.sh fnappend 'aireplay-ng -0 1 wlan0mon' '' 'transmit tools invoked'
mut library-helper-transmit library/user/reconnaissance/starchorus/helper newfile 'mdk4 wlan0mon d' ''              'transmit tools invoked'
mut serve-out-of-scope tools/passivity-check.sh subst 'payload.sh starchorus-serve.sh; find' 'payload.sh; find'          '§14.6 scope fill|§14.6d command words'
mut serve-third-path starchorus-serve.sh       subst    '/|/index.html) f=' '/|/index.html|/x) f='                      'starchorus-serve.sh: GET'
mut serve-post       starchorus-serve.sh       subst    'case "$method" in GET|HEAD) : ;;' 'case "$method" in GET|HEAD|POST) : ;;' 'starchorus-serve.sh: GET'
mut serve-no-block   starchorus-serve.sh       subst    'case "$path" in' 'case "$pth" in'                              'starchorus-serve.sh: GET'
# ---- the checker's own guards
mut sec6-undefined   tools/passivity-check.sh subst "SEC6_FUNCS=' apcli_ro apcli_stub apcli_selftest '" "SEC6_FUNCS=' apcli_ro apcli_stub apcli_selftest zz_undefined '" '§14.6 allowlist names'
# a function head the scope awk no longer recognises: its hits are read as "outside", and the fill probe names the loss
mut fnhead-oneliner  starchorus-collect.sh     subst    'run_cycle() {' 'run_cycle() { :'                                '§14.6 scope fill'
mut fnhead-selftest  starchorus-collect.sh     subst    '^selftest() {' 'selftest() { :'                                  '§14.6 scope fill|sqlite3 read-only|§14.6d command words'
# ---- control: a comment line is not a call (scoped() skips comments); a deviation here would be a finding
mut comment-only     starchorus-collect.sh     fnappend '# aireplay-ng -0 1 wlan0mon' ''                                ''
mut sqlite-ok-comment starchorus-collect.sh    fnappend 'sqlite3 -readonly -noheader "$db" "SELECT 1"   # read only' ''  ''
mut sqlite-ok-two    starchorus-collect.sh     fnappend 'sqlite3 -readonly "$db" "SELECT 1" && sqlite3 -readonly "$db" "SELECT 2"' '' ''
mut bt-comment       starchorus-collect.sh     fnappend '# hcitool cc 02:00:00:00:00:01' ''                             ''
mut bt-sysfs-ok      starchorus-collect.sh     fnappend 'ls /sys/class/bluetooth; [ -d /sys/class/bluetooth/hci0 ]' ''  ''
# ---- the shell scope is read whole, by one reader (the collector, both Overview copies, both payload.sh, the listener and library/): the function a line belongs to, the function heads and the comment lines come from that
# reading, not from a scan of the text. A line in a here-document body, a string or after a backslash that looks like a function head, a closing brace or a comment is text: the poison was a head in such a text (the lines after it
# took the function of the head, and with it the allowlist of apcli_ro or of BT_FUNCS) and a comment-looking line (dropped unread, so a quote in it ended a string and a command stood behind it). The plants are the review's:
# `zz_evil() { cat <<'e' >/dev/null` with `apcli_ro() {` in the body and a device call behind it, the same with a word of SEC6_RE and with a function of BT_FUNCS, in a single and a double quoted string and in a bare
# here-document, a comment-looking line in a string, in a quoted and a bare here-document and after a backslash, a definition nested in a function (at the start of a line, and indented), and in the payload of the library.
mut main-head-heredoc-wifi    starchorus-collect.sh append "zz_evil() { cat <<'e' >/dev/null
apcli_ro() {
e
WIFI_CONNECT zz
}" '' '§14.6 device calls'
mut main-head-heredoc-block   starchorus-collect.sh append "zz_evil() {
    cat <<'e' >/dev/null
apcli_ro() {
e
    WIFI_CONNECT zz
}" '' '§14.6 device calls'
mut main-head-heredoc-bare    starchorus-collect.sh append "zz_evil() {
    cat <<e >/dev/null
apcli_ro() {
e
    WIFI_CONNECT zz
}" '' '§14.6 device calls'
mut main-head-heredoc-sec6    starchorus-collect.sh append "zz_evil() { cat <<'e' >/dev/null
apcli_stub() {
e
DEAUTH zz
}" '' '§14.6 device calls'
mut main-head-heredoc-bt      starchorus-collect.sh append "zz_evil() { cat <<'e' >/dev/null
bt_stub() {
e
zz_x=hcitool
}" '' '§14.6b Bluetooth words'
mut main-head-string-single   starchorus-collect.sh append "zz_evil() { zz_s='
apcli_ro() {
'
WIFI_CONNECT zz
}" '' '§14.6 device calls'
mut main-head-string-double   starchorus-collect.sh append 'zz_evil() { zz_s="
apcli_ro() {
"
WIFI_CONNECT zz
}' '' '§14.6 device calls'
mut main-head-heredoc-payload library/user/reconnaissance/starchorus/payload.sh append "zz_evil() { cat <<'e' >/dev/null
apcli_ro() {
e
WIFI_CONNECT zz
}" '' '§14.6 device calls'
mut main-head-string-payload  library/user/reconnaissance/starchorus/payload.sh append "zz_evil() { zz_s='
apcli_ro() {
'
WIFI_CONNECT zz
}" '' '§14.6 device calls'
mut main-comment-string       starchorus-collect.sh fnappend "zz_x='
# '; WIFI_CONNECT zz; : '
'" '' '§14.6 device calls'
mut main-comment-heredoc      starchorus-collect.sh fnappend "cat <<'zz_eof' >/dev/null
# hcitool -i hci0 dev
zz_eof" '' '§14.6b Bluetooth words'
mut main-comment-heredoc-bare starchorus-collect.sh fnappend 'cat <<zz_eof >/dev/null
# $($zz_a$zz_b -i hci0 lescan)
zz_eof' '' '§14.6d command words'
mut main-comment-continued    starchorus-collect.sh fnappend 'cat /etc/hostname \
# a comment between the two lines
$zz_a$zz_b -i hci0 lescan' '' '§14.6d command words'
mut main-comment-string-payload library/user/reconnaissance/starchorus/payload.sh fnappend "zz_x='
# '; WIFI_CONNECT zz; : '
'" '' '§14.6 device calls'
mut main-nested-definition    starchorus-collect.sh append 'zz_evil() {
apcli_ro() {
WIFI_CONNECT zz
}
}' '' '§14.6 device calls|§14.6 scope fill'
mut main-nested-indented      starchorus-collect.sh append 'zz_evil() {
    apcli_ro() {
        WIFI_CONNECT zz
    }
}' '' '§14.6 device calls'
mut main-nested-bt            starchorus-collect.sh append 'zz_evil() {
bt_stub() {
zz_x=hcitool
}
}' '' '§14.6b Bluetooth words|§14.6 scope fill'
mut main-brace-indented       starchorus-collect.sh append 'apcli_stub() {
    :
  }
zz_next() {
    WIFI_CONNECT zz
}' '' '§14.6 device calls|§14.6 scope fill'
# the opt-in of `iw scan`: its default and the guard line are read from the code lines, not from the raw text. A copy of the default behind a comment sign, a copy of the guard behind one, and a copy of the head with the guard
# inside a here-document in front of the real head (the real function then starts with another line) were green when the text was searched; a comment between the head and the guard moves the guard off the line right after the head
mut main-iw-default-comment   starchorus-collect.sh subst   'ALLOW_ACTIVE=${STARCHORUS_ALLOW_ACTIVE:-0}' 'ALLOW_ACTIVE=${STARCHORUS_ALLOW_ACTIVE:-1} # ALLOW_ACTIVE=${STARCHORUS_ALLOW_ACTIVE:-0}' 'iw scan opt-in'
mut main-iw-guard-comment     starchorus-collect.sh subst   '[ "$ALLOW_ACTIVE" = "1" ] || return 1' ': # [ "$ALLOW_ACTIVE" = "1" ] || return 1' 'iw scan opt-in'
mut main-iw-guard-fake-head   starchorus-collect.sh subst   '^build_from_iwscan() {' "zz_g() { cat <<'e' >/dev/null
build_from_iwscan() {
    [ \"\$ALLOW_ACTIVE\" = \"1\" ] || return 1
e
}
build_from_iwscan() {
    :" 'iw scan opt-in'
mut main-iw-guard-moved       starchorus-collect.sh subst   '^build_from_iwscan() {' 'build_from_iwscan() {
    # a comment between the head and the guard' 'iw scan opt-in'
# a here-document with a bare delimiter is expanded when the document is read: a `$( )` or a backtick expression in its body is code, so a command word that is built or globbed in it is a line of the rows 6d and 6e (it was not read at
# all). The body of one with a quoted delimiter is text. With two documents on a line the body is read when ANY of the delimiters is bare (the last delimiter alone used to decide)
mut main-heredoc-bare-built   starchorus-collect.sh fnappend 'cat <<zz_eof >/dev/null
$($zz_a$zz_b -i hci0 lescan)
zz_eof' '' '§14.6d command words'
mut main-heredoc-bare-backtick starchorus-collect.sh fnappend 'cat <<zz_eof >/dev/null
`$zz_a$zz_b -i hci0 lescan`
zz_eof' '' '§14.6d command words'
mut main-heredoc-bare-glob    starchorus-collect.sh fnappend 'cat <<zz_eof >/dev/null
$(/usr/bin/hc?tool -i hci0 lescan)
zz_eof' '' '§14.6e command names'
mut main-heredoc-bare-find    starchorus-collect.sh fnappend 'cat <<zz_eof >/dev/null
$(find /tmp -name zz -ok sh {} +)
zz_eof' '' '§14.6e command names'
mut main-heredoc-bare-multiline starchorus-collect.sh fnappend 'cat <<zz_eof >/dev/null
a $(echo b
$zz_a$zz_b -i hci0 lescan
) c
zz_eof' '' '§14.6d command words'
mut main-heredoc-then-built   starchorus-collect.sh fnappend 'cat <<zz_eof >/dev/null
plain $(printf x)
zz_eof
$zz_a$zz_b -i hci0 lescan' '' '§14.6d command words'
mut main-two-heredocs         starchorus-collect.sh fnappend "cat <<zz_a <<'zz_b' >/dev/null
\$(\$zz_a\$zz_b -i hci0 lescan)
zz_a
plain
zz_b" '' '§14.6d command words'
mut main-two-heredocs-second  starchorus-collect.sh fnappend "cat <<'zz_a' <<zz_b >/dev/null
plain
zz_a
\$(\$zz_a\$zz_b -i hci0 lescan)
zz_b" '' '§14.6d command words'
mut main-two-heredocs-payload library/user/reconnaissance/starchorus/payload.sh fnappend "cat <<zz_a <<'zz_b' >/dev/null
\$(/usr/bin/hc?tool -i hci0 lescan)
zz_a
plain
zz_b" '' '§14.6e command names'
# script texts: the text of a here-document body or of a string that goes over several lines is text up to the first function head at the start of one of its lines; from that head to its end it is a script, which the rows 6d and 6e read once
# more as code (the earlier reader read the lines after such a head as code, by accident, and the handler that starchorus-serve.sh writes for the nc listener is such a script: a built command word in the lower part of it was red on row 6d, and
# had to stay red). The plants are a built name and a glob below a head in a quoted body (the collector and the payload of the library), a built name in a bare body (plain text there, so only the second reading sees it), in a single and a double
# quoted string, in a body nested in a script text, in the handler itself, after a quote that one function leaves open (the next function is read afresh: the head begins a segment, so does the line after a closing brace), and the head of an allowlisted
# function inside a body (it is no function of the file). A here-document delimiter that is not a plain name, bare or wholly in quotes (`<<e"x"` ends at `ex`, where the reader looked for `e` and took the lines after it for code) is named in the first row.
mut main-script-quoted-built  starchorus-collect.sh fnappend "cat <<'zz_eof' >/dev/null
zz_fn() {
    \$zz_a\$zz_b -i hci0 lescan
}
zz_eof" '' '§14.6d command words'
mut main-script-quoted-glob   starchorus-collect.sh fnappend "cat <<'zz_eof' >/dev/null
zz_fn() {
    /usr/bin/hc?tool -i hci0 lescan
}
zz_eof" '' '§14.6e command names'
mut main-script-quoted-payload library/user/reconnaissance/starchorus/payload.sh fnappend "cat <<'zz_eof' >/dev/null
zz_fn() {
    \$zz_a\$zz_b -i hci0 lescan
}
zz_eof" '' '§14.6d command words'
mut main-script-bare-built    starchorus-collect.sh fnappend 'cat <<zz_eof >/dev/null
zz_fn() {
    $zz_a$zz_b -i hci0 lescan
}
zz_eof' '' '§14.6d command words'
mut main-script-string-built  starchorus-collect.sh fnappend "zz_s='
zz_fn() {
    \$zz_a\$zz_b -i hci0 lescan
}
'" '' '§14.6d command words'
mut main-script-string-payload library/user/reconnaissance/starchorus/payload.sh fnappend 'zz_s="
zz_fn() {
    $zz_a$zz_b -i hci0 lescan
}
"' '' '§14.6d command words'
mut main-script-nested        starchorus-collect.sh fnappend "cat <<'zz_o' >/dev/null
zz_f() {
    cat <<'zz_i' >/dev/null
zz_g() {
    \$zz_a\$zz_b -i hci0 lescan
}
zz_i
}
zz_o" '' '§14.6d command words'
mut main-script-handler       starchorus-serve.sh subst '    kill -0 "$np" 2>/dev/null || return' '    kill -0 "$np" 2>/dev/null || return
    $zz_a$zz_b -i hci0 lescan' '§14.6d command words'
mut main-script-reset-head    starchorus-collect.sh fnappend "cat <<'zz_eof' >/dev/null
zz_f() {
    echo it's
zz_g() {
    \$zz_a\$zz_b -i hci0 lescan
}
zz_eof" '' '§14.6d command words'
mut main-script-reset-close   starchorus-collect.sh fnappend "cat <<'zz_eof' >/dev/null
zz_f() {
    echo it's
}
\$zz_a\$zz_b -i hci0 lescan
zz_eof" '' '§14.6d command words'
mut main-script-head-decoy    starchorus-collect.sh subst '^apcli_selftest() {' "cat <<'zz_eof' >/dev/null
apcli_selftest() {
zz_eof
zz_apcli_selftest() {" '§14.6 device calls|§14.6 allowlist names'
mut main-odd-delimiter        starchorus-collect.sh append "zz_evil() { cat <<e\"x\" >/dev/null
e
apcli_ro() {
ex
WIFI_CONNECT zz
}" '' '§14.6 scope fill'
mut main-odd-delimiter-payload library/user/reconnaissance/starchorus/payload.sh append "zz_evil() { cat <<e\"x\" >/dev/null
e
apcli_ro() {
ex
WIFI_CONNECT zz
}" '' '§14.6 scope fill'
mut main-odd-delimiter-expansion starchorus-collect.sh append 'zz_evil() { cat <<$zz_x >/dev/null
apcli_ro() {
$zz_x
WIFI_CONNECT zz
}' '' '§14.6 scope fill|§14.6d command words'
# the controls: what stays green. A genuine apcli_ro (a line with a word of SEC6_RE as its first line, a call of it), a genuine function of BT_FUNCS, text that only looks like a head, a comment or a closing brace in a quoted and a bare
# here-document and in strings (plain words), a function defined inside a function with a name of its own, a bare here-document with plain expansions (a `$(printf x)`, `$((1 + 2))`, `${zz:-y}`, quotes in the text), a line with
# two here-documents whose bodies are both quoted (built names in them are text), and the two limits that are written down: a second function with the name of an allowlisted one holds what the allowlist allows, as the first
# does (the allowlist is by name; what the allowed functions hold is reviewed, except for the five `_pineap` lines), and the text of a script that a quoted here-document writes out is text (a program text that is built and then run)
mut main-ok-apcli-line        starchorus-collect.sh fnline  'apcli_ro' 'WIFI_CONNECT zz'                                '' ''
mut main-ok-apcli-call        starchorus-collect.sh fnappend 'apcli_ro present; apcli_ro recon_aps'                      '' ''
mut main-ok-bt-line           starchorus-collect.sh fnline  'bt_stub' 'zz_x=hcitool'                                    '' ''
mut main-ok-heredoc-lines     starchorus-collect.sh fnappend "cat <<'zz_eof' >/dev/null
# a line that looks like a comment
\$(\$zz_a\$zz_b -i hci0 lescan)
zz_fn() {
}
apcli_ro() {
zz_eof
cat <<zz_eof2 >/dev/null
# plain \$zz_x text
zz_gn() {
}
apcli_ro() {
zz_eof2
zz_x='
# a line that looks like a comment
apcli_ro() {
}
'
zz_y=\"
# also text
zz_hn() {
}
\"" '' ''
mut main-ok-heredoc-plain     starchorus-collect.sh fnappend 'cat <<zz_eof >/dev/null
a $(printf x) b $((1 + 2)) c ${zz_n:-y} d `printf z` it'"'"'s "quoted" 5 > 3 \$(not run) \`not run\`
$(cat /etc/hostname | tr a b
)
zz_eof
cat /etc/hostname' '' ''
mut main-ok-two-heredocs      starchorus-collect.sh fnappend "cat <<'zz_a' <<\"zz_b\" >/dev/null
\$(\$zz_a\$zz_b -i hci0 lescan)
zz_a
\`/usr/bin/hc?tool -i hci0 lescan\`
zz_b" '' ''
mut main-ok-nested-function   starchorus-collect.sh fnappend 'zz_inner() { :; }
    zz_inner' '' ''
mut main-ok-iw-guard          starchorus-collect.sh subst   '^build_from_iwscan() {' 'build_from_iwscan() {   # the guard is the next line' '' ''
mut main-ok-script-plain      starchorus-collect.sh fnappend "cat <<'zz_eof' >/dev/null
zz_fn() {
    case \$1 in ''|*[!0-9]*) return ;; esac
    zz_x=\$(printf '%s' \"\$1\" | tr a b)
    kill -0 \"\$1\" 2>/dev/null || return
}
zz_eof
cat <<zz_eof2 >/dev/null
zz_gn() {
    echo \$zz_x \$(printf z) \${zz_y:-w}
}
zz_eof2
zz_s='
zz_hn() {
    echo plain text here
}
'" '' ''
mut main-ok-delimiters        starchorus-collect.sh fnappend 'cat <<-zz_e >/dev/null
a
zz_e
cat <<"zz_f" >/dev/null
b
zz_f
cat <<zz_g >/dev/null
c
zz_g' '' ''
mut main-limit-second-definition starchorus-collect.sh append 'apcli_ro() {
    WIFI_CONNECT zz
}' '' ''
mut main-limit-quoted-script  starchorus-collect.sh fnappend "cat <<'zz_eof' >/dev/null
#!/bin/sh
\$zz_a\$zz_b -i hci0 lescan
zz_eof" '' ''
mut main-limit-before-head    starchorus-collect.sh fnappend "cat <<'zz_eof' >/dev/null
\$zz_a\$zz_b -i hci0 lescan
zz_fn() {
}
zz_eof" '' ''

# ---- tools/device-probe.sh (the rows 'device-probe.sh ...', 7d of the checker): a sending, scanning, Bluetooth or network tool in the probe, an `iw` that sets something, a command word that is built or globbed, a program that
# no list names, and the pinned lines (a line changed by one character, a line gone, a line copied into another function). The names of the two allowlisted function families of the collector (BT_FUNCS, SEC6_FUNCS) have
# no standing in the probe. The texts that would trip the guard at the top of this script are written with an empty pair of quotes.
mut probe-iw-set         tools/device-probe.sh   fnappend 'iw dev wlan0 set type monitor' ''                              'device-probe.sh named tools'
mut probe-iw-scan-path   tools/device-probe.sh   fnappend '/usr/sbin/iw dev wlan0 scan' ''                              'device-probe.sh named tools|device-probe.sh programs'
mut probe-hcitool-lescan tools/device-probe.sh   fnappend 'hcitool lescan --passive' ''                                'device-probe.sh named tools|device-probe.sh programs'
mut probe-hcitool-scan   tools/device-probe.sh   fnappend 'hcitool scan' ''                                            'device-probe.sh named tools|device-probe.sh programs'
mut probe-aireplay       tools/device-probe.sh   fnappend 'aireplay-ng -0 1 wlan0mon' ''                               'device-probe.sh named tools|device-probe.sh programs'
mut probe-pineap         tools/device-probe.sh   fnappend '_pineap RECON ALL' ''                                       'device-probe.sh named tools|device-probe.sh programs'
mut probe-nc-call        tools/device-probe.sh   fnappend 'nc 192.0.2.1 80 < /dev/null' ''                             'device-probe.sh named tools|device-probe.sh programs'
mut probe-curl           tools/device-probe.sh   fnappend 'curl http://192.0.2.1/' ''                                  'device-probe.sh named tools|device-probe.sh programs'
mut probe-uci-set        tools/device-probe.sh   fnappend 'uci set wireless.radio0.disabled=1' ''                      'device-probe.sh named tools|device-probe.sh programs'
mut probe-sh-c-curl      tools/device-probe.sh   fnappend 'sh -c "curl http://192.0.2.1/"' ''                          'device-probe.sh named tools'
mut probe-run-limited    tools/device-probe.sh   fnappend 'run_limited 5 "$T/x" uci commit' ''                         'device-probe.sh named tools'
mut probe-sqlite-text    tools/device-probe.sh   fnappend 'echo "sqlite3 is here"' ''                                  'device-probe.sh named tools'
mut probe-sqlite-write   tools/device-probe.sh   subst    'sqlite3 -readonly -noheader "$1" "$2"' 'sqlite3 -noheader "$1" "$2"' 'device-probe.sh named tools'
mut probe-cp-target      tools/device-probe.sh   subst    'cp "$DB-wal" "$B-wal"' 'cp "$DB-wal" "$DB-wal.bak"'          'device-probe.sh named tools|device-probe.sh programs'
mut probe-rm             tools/device-probe.sh   fnappend 'rm -rf /root/loot/zz_x' ''                                  'device-probe.sh named tools'
mut probe-kill           tools/device-probe.sh   fnappend 'kill -9 1' ''                                               'device-probe.sh named tools'
mut probe-expansion      tools/device-probe.sh   fnappend '"$zz_a$zz_b" -i hci0 lescan' ''                             'device-probe.sh named tools'
mut probe-glob           tools/device-probe.sh   fnappend '/usr/bin/hc?tool -i hci0 lescan' ''                         'device-probe.sh named tools'
mut probe-unlisted       tools/device-probe.sh   fnappend 'mv /tmp/zz_a /tmp/zz_b' ''                                  'device-probe.sh programs'
mut probe-dot-"sour"ce   tools/device-probe.sh   fnappend '. /tmp/zz_x' ''                                             'device-probe.sh programs'
mut probe-"ev"al         tools/device-probe.sh   fnappend 'ev''al "$zz_x"' ''                                          'device-probe.sh programs'
mut probe-path-command   tools/device-probe.sh   fnappend '/bin/cat /etc/hostname' ''                                   'device-probe.sh programs'
mut probe-bt-func-name   tools/device-probe.sh   fndef    'bt_begin' 'hcitool -i hci0 lescan'                           'device-probe.sh named tools|device-probe.sh programs'
mut probe-apcli-func-name tools/device-probe.sh  fndef    'apcli_ro' '_pineap RECON ALL'                                'device-probe.sh named tools|device-probe.sh programs'
mut probe-shadow         tools/device-probe.sh   fndef    'cat' ':'                                                     'device-probe.sh programs'
mut probe-pin-edited     tools/device-probe.sh   subst    'wget nc timeout setsid' 'wget nc timeou setsid'              'device-probe.sh named tools'
mut probe-pin-gone       tools/device-probe.sh   subst    "BTP_RE='^(bt|hci|l2|rf|sdp|gatt|obex|bluetooth|bluez|mesh|rctest|avinfo|isotest|ciptool|bccmd|bdaddr|hid2hci|mpris|hex2hcd|scotest)'" "BTP_RE='^(bt|hci)'" 'device-probe.sh named tools'
mut probe-pin-twice      tools/device-probe.sh   fndef    'sect_tools' 'for _t in sqlite3 tcpdump iw iwinfo jq curl wget nc timeout setsid start-stop-daemon uhttpd python3 airodump-ng; do' 'device-probe.sh named tools'
mut probe-no-main        tools/device-probe.sh   subst    '^main() {' 'zz_main() {'                                     'device-probe.sh scope fill|device-probe.sh named tools|device-probe.sh programs'
mut probe-head-oneliner  tools/device-probe.sh   subst    '^cleanup() {' 'cleanup() { :'                                'device-probe.sh scope fill|device-probe.sh named tools'
mut probe-pin-in-collector starchorus-collect.sh fnappend 'for _t in hcitool btmon hciconfig bluetoothctl btmgmt bluetoothd gatttool l2ping rfkill; do' '' 'transmit tools invoked|§14.6b Bluetooth words'
mut probe-lock-edited    tools/device-probe.sh   subst    '( flock -x 9; printf' '( flock -n 9; printf'                'device-probe.sh named tools'
mut probe-lock-second    tools/device-probe.sh   fnappend 'flock -x 8' ''                                              'device-probe.sh named tools'
mut probe-lock-"ex"ec    tools/device-probe.sh   fnappend 'ex''ec 9> /tmp/zz_lock' ''                                 'device-probe.sh programs'
# programs that write by an option of their own (date -s, sed -i, sort -o are pinned programs: every line of them is a pinned line), and the line a pinned command goes on over after a backslash
mut probe-date-set       tools/device-probe.sh   fnappend 'date -s "2020-01-01 00:00"' ''                               'device-probe.sh named tools'
mut probe-sed-inplace    tools/device-probe.sh   fnappend 'sed -i "s/option disabled 0/option disabled 1/" /etc/config/wireless' '' 'device-probe.sh named tools'
mut probe-sort-output    tools/device-probe.sh   fnappend 'sort -o /etc/config/wireless /etc/config/wireless' ''        'device-probe.sh named tools'
mut probe-sed-continued  tools/device-probe.sh   subst    '\.[0-9A-Fa-f]{4}/<mac-withheld>/g'"'"' |' '\.[0-9A-Fa-f]{4}/<mac-withheld>/g'"'"' -i /etc/zz_x |' 'device-probe.sh named tools'
# a write outside /dev/null and the private directory, anywhere in the probe: every form of a redirection, the destination of cp, mv and tee, the variables that stand for a target ('programs' reads them)
mut probe-append-etc     tools/device-probe.sh   fnappend 'printf "option disabled 1\n" >> /etc/config/wireless' ''     'device-probe.sh programs'
mut probe-redirect-glued tools/device-probe.sh   fnappend 'printf x>/etc/zz_x' ''                                      'device-probe.sh programs'
mut probe-redirect-fd    tools/device-probe.sh   fnappend 'echo x 2> /root/zz_err' ''                                   'device-probe.sh programs'
mut probe-redirect-fd9   tools/device-probe.sh   fnappend ': 9> /etc/zz_lock' ''                                       'device-probe.sh programs'
mut probe-redirect-clobber tools/device-probe.sh fnappend 'printf x >| /etc/zz_x' ''                                   'device-probe.sh programs'
mut probe-redirect-rw    tools/device-probe.sh   fnappend ': <> /etc/zz_x' ''                                          'device-probe.sh programs'
mut probe-redirect-subst tools/device-probe.sh   fnappend 'zz_x=$(printf q > /etc/zz_q)' ''                            'device-probe.sh programs'
mut probe-redirect-quoted-subst tools/device-probe.sh fnappend 'zz_x="$(printf q > /etc/zz_q)"' ''                      'device-probe.sh programs'
mut probe-redirect-group tools/device-probe.sh   fnappend '{ printf x; } > /etc/zz_x' ''                               'device-probe.sh programs'
mut probe-redirect-dotdot tools/device-probe.sh  fnappend 'printf x > "$T/../etc/zz_x"' ''                              'device-probe.sh programs'
mut probe-redirect-var   tools/device-probe.sh   fnappend 'printf x > "$zz_f"' ''                                      'device-probe.sh programs'
mut probe-cp-root        tools/device-probe.sh   fnappend 'cp "$DB" /root/leak' ''                                     'device-probe.sh named tools|device-probe.sh programs'
mut probe-cp-option-t    tools/device-probe.sh   fnappend 'cp -t /etc "$DB"' ''                                        'device-probe.sh named tools|device-probe.sh programs'
mut probe-tee-etc        tools/device-probe.sh   fnappend 'tee /etc/zz_x' ''                                           'device-probe.sh programs'
mut probe-mv-etc         tools/device-probe.sh   fnappend 'mv /tmp/zz_a /etc/zz_b' ''                                   'device-probe.sh programs'
mut probe-assign-out     tools/device-probe.sh   fnappend 'OUT=/etc/zz_out' ''                                          'device-probe.sh programs'
mut probe-assign-t       tools/device-probe.sh   fnappend 'T=/etc' ''                                                   'device-probe.sh programs'
mut probe-for-var        tools/device-probe.sh   fnappend 'for A in /etc/zz_a; do :; done' ''                           'device-probe.sh programs'
mut probe-read-var       tools/device-probe.sh   fnappend 'read -r OUT < /dev/null' ''                                 'device-probe.sh programs'
mut probe-write-pin-gone tools/device-probe.sh   subst    '"$@" > "$_of" 2>&1 < /dev/null &' '"$@" > "$T/zz_of" 2>&1 < /dev/null &' 'device-probe.sh named tools|device-probe.sh programs'
# the word after `command` is a program of the PATH even when the file defines a function of that name; a `)` that closes no case item drops nothing before it
mut probe-command-function tools/device-probe.sh append  'mv() { command mv "$@"; }; mv /etc/config/wireless /tmp/zz' '' 'device-probe.sh programs'
mut probe-case-pipeline  tools/device-probe.sh   fnappend 'mv /etc/zz_a /tmp/zz_b | case x in x) : ;; esac' ''           'device-probe.sh programs'
mut probe-case-pipeline-alt tools/device-probe.sh fnappend 'mv /etc/zz_a /tmp/zz_b | case x in a|b) : ;; esac' ''        'device-probe.sh programs'
# the same two with an unlisted program that writes nothing (od), so that only the list of programs can make the row red; the meta probe blinds the parts against these
mut probe-unlisted-read  tools/device-probe.sh   fnappend 'od /etc/hostname' ''                                         'device-probe.sh programs'
mut probe-command-function-read tools/device-probe.sh append 'od() { command od "$@"; }; od /etc/hostname' ''           'device-probe.sh programs'
mut probe-case-pipeline-read tools/device-probe.sh fnappend 'od /etc/zz_a | case x in x) : ;; esac' ''                  'device-probe.sh programs'
mut probe-case-stray-paren tools/device-probe.sh fnappend 'od /etc/zz_a ) : ;;' ''                                      'device-probe.sh programs'
# a trap runs its action string as a command when the signal comes, and the reader reads no string: the action is `-`, an empty string, a function of the probe or `exit N`, anything else is an unlisted command
mut probe-trap-iw-set    tools/device-probe.sh   fnappend 'trap '"'"'iw dev wlan0 set type monitor'"'"' EXIT' ''           'device-probe.sh programs'
mut probe-trap-iw-del    tools/device-probe.sh   fnappend 'trap "iw dev mon0 del" EXIT' ''                             'device-probe.sh programs'
mut probe-trap-sh-c      tools/device-probe.sh   fnappend 'trap '"'"'sh -c "iw dev wlan0 set type monitor"'"'"' EXIT' ''   'device-probe.sh programs'
mut probe-trap-date-set  tools/device-probe.sh   fnappend 'trap '"'"'date -s "2020-01-01 00:00"'"'"' EXIT' ''              'device-probe.sh programs'
mut probe-trap-rm        tools/device-probe.sh   fnappend 'trap '"'"'rm -rf /root/loot/starchorus'"'"' EXIT' ''            'device-probe.sh programs'
mut probe-trap-mv-write  tools/device-probe.sh   fnappend 'trap '"'"'mv /etc/config/wireless /tmp/zz; printf x > /etc/zz'"'"' EXIT' '' 'device-probe.sh programs'
mut probe-trap-program   tools/device-probe.sh   fnappend 'trap od EXIT' ''                                           'device-probe.sh programs'
mut probe-trap-expansion tools/device-probe.sh   fnappend 'trap "$zz_act" EXIT' ''                                    'device-probe.sh programs'
mut probe-trap-exit-more tools/device-probe.sh   fnappend 'trap '"'"'exit 1; od /etc/hostname'"'"' EXIT' ''               'device-probe.sh programs'
mut probe-trap-command   tools/device-probe.sh   fnappend 'command trap '"'"'od /etc/hostname'"'"' EXIT' ''               'device-probe.sh programs'
mut probe-trap-option    tools/device-probe.sh   fnappend 'trap -- '"'"'od /etc/hostname'"'"' EXIT' ''                     'device-probe.sh programs'
mut probe-trap-subst     tools/device-probe.sh   fnappend 'zz_x=$(trap '"'"'od /etc/hostname'"'"' EXIT)' ''                'device-probe.sh programs'
# a case inside ( ), $( ) or backticks, on a body line of an open case item: the `)` of its pattern ends the pattern and closes nothing (it popped the group, and the `)` after `esac` then dropped every name of the line); a built command word before a case on its line stays flagged
mut probe-case-nested-subshell tools/device-probe.sh fnappend 'case "$zz_x" in
        a)
            od /etc/zz_a | (case q in q) esac)
            ;;
    esac' '' 'device-probe.sh programs'
mut probe-case-nested-subst tools/device-probe.sh fnappend 'case "$zz_x" in
        a)
            od /etc/zz_a | cat $(case q in q) esac)
            ;;
    esac' '' 'device-probe.sh programs'
mut probe-case-nested-backtick tools/device-probe.sh fnappend 'case "$zz_x" in
        a)
            od /etc/zz_a | cat `case q in q) esac`
            ;;
    esac' '' 'device-probe.sh programs'
mut probe-case-built-group tools/device-probe.sh  fnappend '"$zz_a$zz_b" /etc/zz_a | (case q in q) esac)' ''                 'device-probe.sh named tools'
mut probe-case-built-subst tools/device-probe.sh  fnappend '$(case q in q) echo od ;; esac) /etc/hostname' ''                 'device-probe.sh named tools'
mut probe-case-built-backtick tools/device-probe.sh fnappend '`case q in q) echo od ;; esac` /etc/hostname' ''                'device-probe.sh named tools'
mut probe-case-built-name tools/device-probe.sh  fnappend '"$zz_a$zz_b" /etc/zz_a | case x in x) : ;; esac' ''        'device-probe.sh named tools'
# the write rule takes no expansion after $T/ (the vset line is a pinned exception, and its callers have to give digits)
mut probe-redirect-expansion tools/device-probe.sh fnappend 'printf x > "$T/$zz_p"' ''                                'device-probe.sh programs'
mut probe-redirect-arg   tools/device-probe.sh   fnappend 'printf v > "$T/v.$1"' ''                                   'device-probe.sh programs'
mut probe-assign-out-expansion tools/device-probe.sh fnappend 'OUT=$T/$zz_p' ''                                       'device-probe.sh programs'
mut probe-assign-b-arg   tools/device-probe.sh   fnappend 'B="$T/$1"' ''                                              'device-probe.sh programs'
mut probe-cp-expansion   tools/device-probe.sh   fnappend 'cp "$DB" "$T/$zz_p"' ''                                    'device-probe.sh named tools|device-probe.sh programs'
mut probe-write-vset-edited tools/device-probe.sh subst  '"$2" > "$T/v.$1"; }' '"$2" > "$T/w.$1"; }'                  'device-probe.sh programs'
mut probe-write-vset-twice tools/device-probe.sh append  'vset() { printf '"'"'%s\n'"'"' "$2" > "$T/v.$1"; }           # summary line of open verification $1' '' 'device-probe.sh programs'
mut probe-vset-variable  tools/device-probe.sh   fnappend 'vset "$zz_n" x' ''                                         'device-probe.sh programs'
mut probe-vset-path      tools/device-probe.sh   fnappend 'vset ../../etc/x y' ''                                     'device-probe.sh programs'
# a here-document: the shell takes the delimiter word up to the first unquoted blank or metacharacter and removes its quotes, so a word that is not a plain name, bare or wholly in quotes ends its body
# where the reader does not look for it (`: <<wait"x"` ends at `waitx`, and the reader would skip to `wait`); the body of one with a bare delimiter is expanded when it runs, and a `$(` or a backtick in it starts a command
mut probe-heredoc-quote-mid tools/device-probe.sh fnappend ': <<wait"x"
waitx
od /etc/zz_a
wait' '' 'device-probe.sh programs'
mut probe-heredoc-quote-end tools/device-probe.sh fnappend ': <<'"'"'wait'"'"'x
waitx
od /etc/zz_a
wait' '' 'device-probe.sh programs'
mut probe-heredoc-hyphen tools/device-probe.sh   fnappend ': <<wait-x
wait-x
od /etc/zz_a
wait' '' 'device-probe.sh programs'
mut probe-heredoc-body-subst tools/device-probe.sh fnappend 'cat <<zz_eof > /dev/null
$(od /etc/zz_a)
zz_eof' '' 'device-probe.sh programs'
mut probe-heredoc-body-backtick tools/device-probe.sh fnappend 'cat <<zz_eof > /dev/null
`od /etc/zz_a`
zz_eof' '' 'device-probe.sh programs'
# the functions of the probe, and the function a line belongs to, come from the reader, not from a text scan of the raw file. A line `name() { :; }` in the body of a here-document (quoted or bare), in a string that runs over several lines or in a
# comment defines nothing, so a call of that name, and a `trap` that names it, stay unlisted commands; a definition that is indented, behind a `;`, in a subshell, after a backslash or with a name that is no plain name is none for the calls either
mut probe-fn-heredoc-call tools/device-probe.sh  fnappend 'cat <<'"'"'zz_eof'"'"' > /dev/null
nft() { :; }
zz_eof
nft dev wlan0' '' 'device-probe.sh programs'
mut probe-fn-heredoc-trap tools/device-probe.sh  fnappend 'cat <<'"'"'zz_eof'"'"' > /dev/null
nft() { :; }
zz_eof
trap nft EXIT' '' 'device-probe.sh programs'
mut probe-fn-heredoc-bare tools/device-probe.sh  fnappend 'cat <<zz_eof > /dev/null
nft() { :; }
zz_eof
nft dev wlan0' '' 'device-probe.sh programs'
mut probe-fn-comment-call tools/device-probe.sh  fnappend '# nft() { :; }
nft dev wlan0' '' 'device-probe.sh programs'
mut probe-fn-string-call tools/device-probe.sh   fnappend 'zz_x='"'"'
nft() { :; }
'"'"'
nft dev wlan0' '' 'device-probe.sh programs'
mut probe-fn-string-trap tools/device-probe.sh   fnappend 'zz_x='"'"'
nft() { :; }
'"'"'
trap nft EXIT' '' 'device-probe.sh programs'
mut probe-fn-dstring-call tools/device-probe.sh  fnappend 'zz_x="
nft() { :; }
"
nft dev wlan0' '' 'device-probe.sh programs'
mut probe-fn-indented-call tools/device-probe.sh fnappend 'nft() { :; }
nft dev wlan0' '' 'device-probe.sh programs'
mut probe-fn-after-semicolon tools/device-probe.sh append 'zz_a() { :; }; nft() { :; }
nft dev wlan0' '' 'device-probe.sh programs'
mut probe-fn-subshell-call tools/device-probe.sh fnappend '(
nft() { :; }
)
nft dev wlan0' '' 'device-probe.sh programs'
mut probe-fn-continued   tools/device-probe.sh   fnappend 'zz_x=\
nft() { :; }
nft dev wlan0' '' 'device-probe.sh programs'
mut probe-fn-odd-name    tools/device-probe.sh   append  'zz-nft() { :; }
zz-nft dev wlan0' '' 'device-probe.sh programs'
# a function head that stands in a here-document body or a string gives the lines after it no function (the pins), and counts as none for the fill; a closing brace in a body does not end a function
mut probe-no-main-heredoc tools/device-probe.sh  subst    '^main() {' 'zz_main() {
    cat <<'"'"'zz_eof'"'"' > /dev/null
main() {
zz_eof' 'device-probe.sh scope fill|device-probe.sh named tools|device-probe.sh programs'
mut probe-pin-fn-heredoc tools/device-probe.sh   subst    '^sect_radio() {' 'sect_zz() {
    cat <<'"'"'zz_eof'"'"' > /dev/null
sect_radio() {
zz_eof' 'device-probe.sh named tools|device-probe.sh programs'
mut probe-pin-fn-string  tools/device-probe.sh   subst    '^sect_radio() {' 'sect_zz() {
    zz_x='"'"'
sect_radio() {
'"'"'' 'device-probe.sh named tools|device-probe.sh programs'
mut probe-pin-fn-close-heredoc tools/device-probe.sh subst '^BTP_RE=' 'zz_f() {
    cat <<'"'"'zz_eof'"'"' > /dev/null
}
zz_eof
BTP_RE=' 'device-probe.sh named tools'
# a line that looks like a comment, in a string that runs over several lines, in a bare here-document or after a backslash, is code: a quote in it ends the string, a `$(` in it is run, and the command after the comment of a continued line is a command
mut probe-string-comment-line tools/device-probe.sh fnappend 'zz_x='"'"'
# '"'"'; od /etc/zz_a; : '"'"'
'"'"'' '' 'device-probe.sh programs'
mut probe-string-comment-curl tools/device-probe.sh fnappend 'zz_x='"'"'
# '"'"'; curl http://192.0.2.1/; : '"'"'
'"'"'' '' 'device-probe.sh named tools|device-probe.sh programs'
mut probe-heredoc-body-comment tools/device-probe.sh fnappend 'cat <<zz_eof > /dev/null
# $(od /etc/zz_a)
zz_eof' '' 'device-probe.sh programs'
mut probe-continued-comment tools/device-probe.sh fnappend 'cat /etc/hostname \
# a comment between the two lines
od /etc/zz_a' '' 'device-probe.sh programs'
# a line that looks like a function head, inside a string, starts no new reading: the string goes on, and ends where the shell ends it
mut probe-string-head-reset tools/device-probe.sh fnappend 'zz_x='"'"'
zz_fn() {
'"'"'; od /etc/zz_a' '' 'device-probe.sh programs'
# a function with the name of a listed program is red wherever it is defined, not only at the start of a line
mut probe-shadow-nested  tools/device-probe.sh   fnappend 'cat() { :; }' ''                                           'device-probe.sh programs'
# the word after `command` is read against the lists without its `!`; no program has the name of a function of the probe (run_limited)
mut probe-command-run-limited tools/device-probe.sh fnappend 'command run_limited 5 "$T/zz_x" true' ''                'device-probe.sh named tools|device-probe.sh programs'
# the floor of write targets read
mut probe-writes-floor   tools/passivity-check.sh subst  'MIN_PROBE_WRITES=60 ' 'MIN_PROBE_WRITES=9999 '              'device-probe.sh scope fill'
mut probe-ok-read        tools/device-probe.sh   fnappend 'cat /etc/openwrt_release | head -n 1 | wc -l; grep -c x /etc/hostname; readlink -f /sys/class/net; ls -1A /root' '' ''
mut probe-ok-functions   tools/device-probe.sh   fnappend 'kv zz_k "$(isnum 5 && echo y)"; say zz; have iw || have jq' '' ''
mut probe-ok-comment     tools/device-probe.sh   fnappend '# curl http://192.0.2.1/ ; hcitool scan ; iw dev wlan0 set channel 6' '' ''
mut probe-ok-case-pattern tools/device-probe.sh  fnappend 'case "$zz_x" in a|b) : ;; zz_c) : ;; *) : ;; esac' '' ''
mut probe-ok-builtins    tools/device-probe.sh   fnappend 'zz_x=$(printf 5); [ -n "$zz_x" ] || return 1; set -- a b; shift; read -r zz_y < /dev/null; trap - INT; printf "%s\n" "$zz_x" > /dev/null' '' ''
# the forms of a write that stay green: /dev/null, a file below $T, the variables the probe sets to one, a descriptor copy, the input redirections, and the assignments the row accepts
mut probe-ok-redirects   tools/device-probe.sh   fnappend 'printf x > /dev/null; printf y >> "$T/zz_y"; printf z 2>&1; printf w >&2; : > "$OUT"; printf q 2> /dev/null > /dev/null; zz_x=$(printf q > "$T/zz_q"); printf v > "$T/v.1"; cat < /dev/null 9> "$T/zz_lock"; printf u 2>"$T/zz.err" 1>&2' '' ''
mut probe-ok-assign      tools/device-probe.sh   fnappend 'OUT=""; A="$T/zz_a"; B=$T/zz_b; T=""; OUT=$T/out; read -r zz_y < /dev/null; for zz_c in a b; do :; done' '' ''
mut probe-ok-command-v   tools/device-probe.sh   fnappend 'command -v zz_x > /dev/null 2>&1' '' ''
mut probe-ok-command-plain tools/device-probe.sh fnappend 'command cat /etc/hostname > /dev/null' '' ''
mut probe-ok-trap        tools/device-probe.sh   fnappend 'trap cleanup EXIT; trap zz_probe INT; trap "exit 5" TERM; trap '"'"'exit 130'"'"' HUP; trap - PIPE; trap "" INT; zz_x=$(trap - EXIT)' '' ''
mut probe-ok-vset        tools/device-probe.sh   fnappend 'vset 5 "x $1"' '' ''
# the forms of a here-document that stay green: a quoted delimiter (the body is text, also with a `$(` in it) and a bare one with a plain body
mut probe-ok-heredoc     tools/device-probe.sh   fnappend 'cat <<'"'"'zz_eof'"'"' > /dev/null
$(od /etc/zz_a)
`od /etc/zz_a`
zz_eof
cat <<"zz_eof" > /dev/null
$(od /etc/zz_a)
zz_eof
cat <<zz_eof > /dev/null
plain $T text ${PATH:-x}
zz_eof' '' ''
# the probe, two here-documents on a line: a body that the shell expands is a `$(` or a backtick in a bare body, and the line is bare when any of its delimiters is
mut probe-heredoc-two-bodies tools/device-probe.sh fnappend "cat <<zz_a <<'zz_b' > /dev/null
\$(od /etc/zz_a)
zz_a
plain
zz_b" '' 'device-probe.sh programs'
mut probe-heredoc-two-backtick tools/device-probe.sh fnappend "cat <<zz_a <<\"zz_b\" > /dev/null
\`od /etc/zz_a\`
zz_a
plain
zz_b" '' 'device-probe.sh programs'
mut probe-heredoc-two-second tools/device-probe.sh fnappend "cat <<'zz_a' <<zz_b > /dev/null
plain
zz_a
\$(od /etc/zz_a)
zz_b" '' 'device-probe.sh programs'
mut probe-ok-heredoc-two     tools/device-probe.sh fnappend "cat <<'zz_a' <<\"zz_b\" > /dev/null
\$(od /etc/zz_a)
zz_a
\`od /etc/zz_b\`
zz_b" '' ''
# text that only looks like definitions, comments and heads stays text: lines in a string, a quoted and a bare here-document that look like a comment, a function head, a closing brace or a definition (of a listed program, too), and a continued command
mut probe-ok-string-lines tools/device-probe.sh  fnappend 'zz_x='"'"'
# a line that looks like a comment
zz_fn() {
}
nft() { :; }
cat() { :; }
'"'"'
zz_y="
# also text
zz_gn() {
}
ls() { :; }
"' '' ''
mut probe-ok-heredoc-lines tools/device-probe.sh fnappend 'cat <<'"'"'zz_eof'"'"' > /dev/null
# a line that looks like a comment
zz_fn() {
}
nft() { :; }
cat() { :; }
$(od /etc/zz_a)
zz_eof
cat <<zz_eof2 > /dev/null
# plain $T text
zz_gn() {
}
ls() { :; }
zz_eof2' '' ''
mut probe-ok-continued   tools/device-probe.sh   fnappend 'cat /etc/hostname \
    /etc/openwrt_release > /dev/null' '' ''
# the same name as a genuine function of the probe, at the start of a line at the top level: its calls and a trap that names it are the probe's own
mut probe-ok-fn-toplevel tools/device-probe.sh   append  'nft() { :; }
nft dev wlan0
trap nft EXIT' '' ''
# a case inside ( ), $( ) or backticks in a case body, and one that begins a line inside an open case of its own group
mut probe-ok-case-nested tools/device-probe.sh   fnappend 'case "$zz_x" in
        a)
            cat /etc/hostname | (case q in q) : ;; r) : ;; esac)
            zz_y=$(case q in q) echo a ;; r) echo b ;; esac)
            zz_z=`case q in q) : ;; esac`
            ;;
    esac' '' ''
mut probe-ok-case-nested-lines tools/device-probe.sh fnappend 'zz_x=$(case q in
            a|b) : ;;
            zz_c|zz_d)
                : ;;
        esac)' '' ''
# the case items: a pattern at the start of a line inside an open case, after `;;` and after `;&` (the last two on one line, patterns with `|`, a case inside an item)
mut probe-ok-case-lines  tools/device-probe.sh   fnappend 'case "$zz_x" in
        a|b) : ;;
        zz_c|zz_d)
            : ;;
        *) case "$zz_y" in zz_e|zz_f) : ;; esac ;;
    esac' '' ''
mut probe-ok-case-fallthrough tools/device-probe.sh fnappend 'case "$zz_x" in a) : ;& zz_c|zz_d) : ;;& zz_e) : ;; esac' '' ''
# written down: what an awk program does with its text is not read (review), so a write from inside one stays green
mut probe-limit-awk-write tools/device-probe.sh  fnappend "awk 'BEGIN { print \"x\" > \"/etc/zz_x\" }' < /dev/null" '' ''
mut probe-limit-collector-curl starchorus-collect.sh fnappend 'curl http://192.0.2.1/' ''                              ''

# ============================== alternatives: one planted sample per regex alternative ==============================
# alt FAMILY KEY SAMPLE ROW : KEY is a literal piece of exactly ONE alternative of the family (as `sh tools/passivity-check.sh
# --regexes` prints it), SAMPLE the violation text (planted on its own line; it must match that alternative and no other),
# ROW the row prefix under which the checker has to list that line. Families: netsurf, netx (page); tx, iw, sec6, bt, btwrap (collector); pnet (tools/device-probe.sh).
altfile="$tmp/alttab"; : > "$altfile"
alt() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$altfile"; }
alt netsurf 'method:'           'var zz = {method:"x"};'                          'HTML network surface'
alt netsurf 'POST'              'var zz = "POST";'                                'HTML network surface'
alt netsurf 'XMLHttpRequest'    'var zz = new XMLHttpRequest();'                  'HTML network surface'
alt netsurf 'WebSocket'         'var zz = new WebSocket("x");'                    'HTML network surface'
alt netsurf 'EventSource'       'var zz = new EventSource("x");'                  'HTML network surface'
alt netsurf 'sendBeacon'        'navigator.sendBeacon("x");'                      'HTML network surface'
alt netx 'RTCPeerConnection'    'var zz = new RTCPeerConnection();'               'other network APIs'
alt netx 'WebTransport'         'var zz = new WebTransport("x");'                 'other network APIs'
alt netx 'serviceWorker'        'navigator.serviceWorker.register("x");'          'other network APIs'
alt netx 'Shared)?Worker'       'var zz = new Worker("x");'                       'other network APIs'
alt netx 'importScripts'        'importScripts("x");'                             'other network APIs'
alt netx 'import\('             'var zz = import("x");'                           'other network APIs'
alt netx 'window\.open'         'window.open("x");'                               'other network APIs'
alt netx 'location\.(assign'    'location.assign("x");'                           'other network APIs'
alt netx ')?location(\.href)?'  'document.location = "x";'                        'other network APIs'
alt netx 'createElement\('      'var zz = document.createElement("a");'           'other network APIs'
alt netx '\.click\('            'zz.click();'                                     'other network APIs'
alt netx 'download='            'zz.download="x";'                                'other network APIs'
alt netx '<form'                'var zz = "<form>";'                              'other network APIs'
alt netx '<iframe'              'var zz = "<iframe>";'                            'other network APIs'
alt netx 'new Image'            'var zz = new Image();'                           'other network APIs'
alt netx '<link'                'var zz = "<link>";'                              'other network APIs'
alt netx '<script[^>]+src='     'var zz = "<script src=x>";'                      'other network APIs'
alt netx '@import'              'var zz = "@import x";'                           'other network APIs'
alt netx 'url\('                'var zz = "url(https://x.invalid/a)";'            'other network APIs'
alt tx 'aireplay'               'aireplay-ng -0 1 wlan0mon'                       'transmit tools invoked'
alt tx 'mdk['                   'mdk4 wlan0mon d'                                 'transmit tools invoked'
alt tx '=hostapd'               'hostapd /tmp/x.conf'                             'transmit tools invoked'
alt tx 'airbase'                'airbase-ng -e x wlan0mon'                        'transmit tools invoked'
alt tx 'hcxdumptool'            'hcxdumptool -i wlan0mon'                         'transmit tools invoked'
alt tx 'wpa_supplicant'         'wpa_supplicant -i wlan0mon -c /tmp/x'            'transmit tools invoked'
alt tx 'nmcli'                  'nmcli dev wifi list'                             'transmit tools invoked'
alt tx 'iwlist'                 'iwlist wlan0mon frequency'                       'transmit tools invoked'
alt tx 'nmap'                   'nmap -sn 10.0.0.0/24'                            'transmit tools invoked'
alt tx 'iwconfig'               'iwconfig wlan1mon channel 6'                     'transmit tools invoked'
alt tx 'tcpreplay'              'tcpreplay -i wlan1mon /tmp/zz.pcap'              'transmit tools invoked'
alt tx 'airmon'                 'airmon-ng start wlan1'                           'transmit tools invoked'
alt tx 'mausezahn'              'mausezahn wlan1mon -c 1'                         'transmit tools invoked'
alt tx 'hping'                  'hping3 -S 10.0.0.1'                              'transmit tools invoked'
alt tx 'arping'                 'arping -c 1 10.0.0.1'                            'transmit tools invoked'
alt tx 'bettercap'              'bettercap -iface wlan1mon'                       'transmit tools invoked'
alt tx 'wpa_cli'                'wpa_cli -i wlan1mon status'                      'transmit tools invoked'
alt tx 'hostapd_cli'            'hostapd_cli status'                              'transmit tools invoked'
alt tx 'besside'                'besside-ng wlan1mon'                             'transmit tools invoked'
alt tx 'reaver'                 'reaver -i wlan1mon -b x'                         'transmit tools invoked'
alt tx 'bully'                  'bully wlan1mon -b x'                             'transmit tools invoked'
alt tx 'hcitool[[:space:]]+scan'  'hcitool scan'                                    'transmit tools invoked|§14.6b Bluetooth words'
alt tx 'hcitool[[:space:]]+inq'   'hcitool inq'                                     'transmit tools invoked|§14.6b Bluetooth words'
alt tx 'hcitool[[:space:]]+cc'    'hcitool cc'                                      'transmit tools invoked|§14.6b Bluetooth words'
alt tx 'hcitool[[:space:]]+lecc'  'hcitool lecc'                                    'transmit tools invoked|§14.6b Bluetooth words'
alt tx 'hcitool[[:space:]]+leadv' 'hcitool leadv'                                   'transmit tools invoked|§14.6b Bluetooth words'
alt tx 'hcitool[[:space:]]+cmd'   'hcitool cmd'                                     'transmit tools invoked|§14.6b Bluetooth words'
alt tx 'l2ping'                   'l2ping -c 1 x'                                   'transmit tools invoked|§14.6b Bluetooth words'
alt tx 'bluetoothctl['            'bluetoothctl scan on'                            'transmit tools invoked|§14.6b Bluetooth words'
alt tx 'btmgmt'                   'btmgmt find'                                     'transmit tools invoked|§14.6b Bluetooth words'
alt tx 'gatttool'                 'gatttool -I'                                     'transmit tools invoked|§14.6b Bluetooth words'
alt tx 'hciconfig('               'hciconfig hci0 up'                               'transmit tools invoked|§14.6b Bluetooth words'
alt iw 'connect'                'iw dev wlan0mon connect x'                       'transmit tools invoked'
alt iw 'ibss['                  'iw dev wlan0mon ibss join x 2412'                'transmit tools invoked'
alt iw 'mesh['                  'iw dev wlan0mon mesh join x'                     'transmit tools invoked'
# bt: every tool and path of the stack, planted in a function that is NOT on the allowlist (row §14.6b). ROW may name rows that are tolerated on the
# same line after a `|`: a name that the transmit row denies by verb as well (btmgmt, gatttool, l2ping) is listed under both.
alt bt 'hcitool'                'hcitool -i hci0 dev'                             '§14.6b Bluetooth words'
alt bt 'btmon'                  'btmon -i hci0'                                   '§14.6b Bluetooth words'
alt bt 'hciconfig'              'hciconfig -a'                                    '§14.6b Bluetooth words'
alt bt 'bluetoothctl'           'bluetoothctl show'                               '§14.6b Bluetooth words'
alt bt 'btmgmt'                 'btmgmt info'                                     '§14.6b Bluetooth words|transmit tools invoked'
alt bt 'bluetoothd'             'bluetoothd -n'                                   '§14.6b Bluetooth words'
alt bt 'gatttool'               'gatttool -I'                                     '§14.6b Bluetooth words|transmit tools invoked'
alt bt 'l2ping'                 'l2ping -c 1 x'                                   '§14.6b Bluetooth words|transmit tools invoked'
alt bt 'l2test'                 'l2test -n x'                                     '§14.6b Bluetooth words'
alt bt 'rctest'                 'rctest -n x'                                     '§14.6b Bluetooth words'
alt bt 'sdptool'                'sdptool browse local'                            '§14.6b Bluetooth words'
alt bt 'rfcomm'                 'rfcomm show'                                     '§14.6b Bluetooth words'
alt bt 'hcidump'                'hcidump -i hci0'                                 '§14.6b Bluetooth words'
alt bt 'btattach'               'btattach -B /dev/x'                              '§14.6b Bluetooth words'
alt bt 'bccmd'                  'bccmd psget x'                                   '§14.6b Bluetooth words'
alt bt 'bdaddr'                 'bdaddr -i hci0'                                  '§14.6b Bluetooth words'
alt bt 'hciattach'              'hciattach /dev/x any'                            '§14.6b Bluetooth words'
alt bt 'hid2hci'                'hid2hci --quiet'                                 '§14.6b Bluetooth words'
alt bt 'btgatt-client'          'btgatt-client -d x'                              '§14.6b Bluetooth words'
alt bt 'btgatt-server'          'btgatt-server -s x'                              '§14.6b Bluetooth words'
alt bt 'obexd'                  'obexd -n'                                        '§14.6b Bluetooth words'
alt bt 'rfkill'                 'rfkill list'                                     '§14.6b Bluetooth words'
alt bt 'init\.d/bluetooth'      '/etc/init.d/bluetooth start'                     '§14.6b Bluetooth words'
alt bt '/sys/kernel/debug/bluetooth' 'cat /sys/kernel/debug/bluetooth/hci0/x'     '§14.6b Bluetooth words'
alt bt 'dbus-send'              'dbus-send --system --dest=x'                     '§14.6b Bluetooth words'
alt bt 'busctl'                 'busctl call x'                                   '§14.6b Bluetooth words'
alt bt 'gdbus'                  'gdbus call --system x'                           '§14.6b Bluetooth words'
alt bt 'org\.bluez'             'zz_x=org.bluez'                                  '§14.6b Bluetooth words'
alt bt 'ciptool'                'ciptool show'                                    '§14.6b Bluetooth words'
alt bt 'avinfo'                 'avinfo x'                                        '§14.6b Bluetooth words'
alt bt 'isotest'                'isotest -n x'                                    '§14.6b Bluetooth words'
alt bt 'meshctl'                'meshctl x'                                       '§14.6b Bluetooth words'
alt bt 'mesh-cfgclient'         'mesh-cfgclient x'                                '§14.6b Bluetooth words'
alt bt 'bluetooth-meshd'        'bluetooth-meshd -n'                              '§14.6b Bluetooth words'
alt bt 'btproxy'                'btproxy -u'                                      '§14.6b Bluetooth words'
alt bt 'bluemoon'               'bluemoon -i x'                                   '§14.6b Bluetooth words'
alt bt 'mpris-proxy'            'mpris-proxy'                                     '§14.6b Bluetooth words'
alt bt 'hex2hcd'                'hex2hcd x y'                                     '§14.6b Bluetooth words'
alt bt 'obexctl'                'obexctl -a x'                                    '§14.6b Bluetooth words'
alt bt 'bluetooth-player'       'bluetooth-player x'                              '§14.6b Bluetooth words'
alt bt 'btinfo'                 'btinfo x'                                        '§14.6b Bluetooth words'
alt bt 'scotest'                'scotest -n x'                                    '§14.6b Bluetooth words'
alt bt 'hcieventmask'           'hcieventmask x'                                  '§14.6b Bluetooth words'
# btwrap: the wrappers, planted as simple commands inside ONE function of the allowlist (a copy of bt_busy, row Bluetooth wrappers); the three
# words that the guard at the top of this script reads as a command are written with an empty pair of quotes inside them
alt btwrap '^eval'                 'ev''al "$x"'                                      'Bluetooth wrappers'
alt btwrap '^sh[[:space:]]+-c'     'sh -c "x"'                                        'Bluetooth wrappers'
alt btwrap '^ash[[:space:]]+-c'    'ash -c "x"'                                       'Bluetooth wrappers'
alt btwrap '^busybox'              'busybox ls'                                       'Bluetooth wrappers'
alt btwrap '^env'                  'env X=1 true'                                     'Bluetooth wrappers'
alt btwrap '^xargs'                'xargs ls'                                         'Bluetooth wrappers'
alt btwrap '^nohup'                'nohup ls'                                         'Bluetooth wrappers'
alt btwrap '^setsid'               'setsid ls'                                        'Bluetooth wrappers'
alt btwrap '^nice'                 'nice ls'                                          'Bluetooth wrappers'
alt btwrap '^start-stop-daemon'    'start-stop-daemon -S -x /bin/true'                'Bluetooth wrappers'
alt btwrap '^exec'                 'ex''ec true'                                      'Bluetooth wrappers'
alt btwrap '^source'               'sour''ce /tmp/x'                                  'Bluetooth wrappers'
alt btwrap '^time'                 'time ls'                                          'Bluetooth wrappers'
alt btwrap '^\.[[:space:]]'        '. /tmp/x'                                         'Bluetooth wrappers'
alt btwrap '^command[[:space:]]+(' 'command ls'                                       'Bluetooth wrappers'
alt sec6 '_pineap'              '_pineap RECON ALL'                               '§14.6 device calls'
alt sec6 'PINEAPPLE_'           'PINEAPPLE_X=1'                                   '§14.6 device calls'
alt sec6 'WIGLE_'               'WIGLE_X=1'                                       '§14.6 device calls'
alt sec6 'DEAUTH'               'DEAUTH=1'                                        '§14.6 device calls'
alt sec6 'SSID_POOL'            'SSID_POOL=x'                                     '§14.6 device calls'
alt sec6 'GPS_GET'              'GPS_GET=1'                                       '§14.6 device calls'
alt sec6 'WIFI_CONNECT'         'WIFI_CONNECT=1'                                  '§14.6 device calls'
alt sec6 'WIFI_DISCONNECT'      'WIFI_DISCONNECT=1'                               '§14.6 device calls'
alt sec6 'WIFI_MGMT_AP'         'WIFI_MGMT_AP=1'                                  '§14.6 device calls'
alt sec6 'WIFI_OPEN_AP'         'WIFI_OPEN_AP=1'                                  '§14.6 device calls'
alt sec6 'WIFI_WPA_AP'          'WIFI_WPA_AP=1'                                   '§14.6 device calls'
alt sec6 'WIFI_PCAP_'           'WIFI_PCAP_START=1'                               '§14.6 device calls'
alt sec6 'INSTALL_FIRMWARE'     'INSTALL_FIRMWARE=x'                              '§14.6 device calls'
alt sec6 'OPENVPN_'             'OPENVPN_START=1'                                 '§14.6 device calls'
alt sec6 'WIREGUARD_'           'WIREGUARD_START=1'                               '§14.6 device calls'
alt sec6 'AUTOSSH_'             'AUTOSSH_START=1'                                 '§14.6 device calls'
alt sec6 'SSH_ADD_KNOWN_HOST'   'SSH_ADD_KNOWN_HOST=x'                            '§14.6 device calls'
alt sec6 'DNSSPOOF_'            'DNSSPOOF_START=1'                                '§14.6 device calls'
alt sec6 'SYSTEM_DNS'           'SYSTEM_DNS=x'                                    '§14.6 device calls'
alt sec6 'GPS_CONFIGURE'        'GPS_CONFIGURE=1'                                 '§14.6 device calls'
alt sec6 'FIND_CLIENT_IP'       'FIND_CLIENT_IP=x'                                '§14.6 device calls'

# pnet: the network, capture, package and service tools that only tools/device-probe.sh is read for, planted in functions of a copy of the probe (row 'device-probe.sh named tools'; the programs row lists a name that no list knows on the same line)
alt pnet 'curl'                 'curl http://192.0.2.1/'                          'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'wget'                 'wget http://192.0.2.1/'                          'device-probe.sh named tools|device-probe.sh programs'
alt pnet '=nc'                  'nc 192.0.2.1 80'                                 'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'ncat'                 'ncat 192.0.2.1 80'                               'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'netcat'               'netcat 192.0.2.1 80'                             'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'socat'                'socat - TCP:192.0.2.1:80'                        'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'ping'                 'ping -c 1 192.0.2.1'                             'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'traceroute'           'traceroute 192.0.2.1'                            'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'ssh'                  'ssh root@192.0.2.1'                              'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'scp'                  'scp zz root@192.0.2.1:/tmp/'                     'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'sftp'                 'sftp root@192.0.2.1'                             'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'telnet'               'telnet 192.0.2.1'                                'device-probe.sh named tools|device-probe.sh programs'
alt pnet '=ftp'                 'ftp 192.0.2.1'                                   'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'tftp'                 'tftp 192.0.2.1'                                  'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'uci'                  'uci show wireless'                               'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'opkg'                 'opkg list'                                       'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'ifconfig'             'ifconfig wlan0'                                  'device-probe.sh named tools|device-probe.sh programs'
alt pnet '=ip'                  'ip link show'                                    'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'iptables'             'iptables -L'                                     'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'tcpdump'              'tcpdump -i wlan1mon'                             'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'airodump-ng'          'airodump-ng wlan1mon'                            'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'dumpcap'              'dumpcap -i wlan1mon'                             'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'tshark'               'tshark -i wlan1mon'                              'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'service'              'service uhttpd restart'                          'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'reload_config'        'reload_config'                                   'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'wifi'                 'wifi reload'                                     'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'pkill'                'pkill uhttpd'                                    'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'killall'              'killall uhttpd'                                  'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'reboot'               'reboot'                                          'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'poweroff'             'poweroff'                                        'device-probe.sh named tools|device-probe.sh programs'
alt pnet 'halt'                 'halt'                                            'device-probe.sh named tools|device-probe.sh programs'

TAB=$(printf '\t')
# the top-level alternatives of the ERE in $1, one per line (depth 0 of `(...)`, `[...]` classes and `\x` escapes respected)
split_alts() {
  _re=$1 awk 'BEGIN { s = ENVIRON["_re"]; n = length(s); d = 0; cls = 0; cur = ""
    for (i = 1; i <= n; i++) {
      c = substr(s, i, 1)
      if (c == "\\") { cur = cur c substr(s, i + 1, 1); i++; continue }
      if (cls) {
        if (c == "[" && substr(s, i + 1, 1) == ":") { j = index(substr(s, i), ":]"); cur = cur substr(s, i, j + 1); i += j; continue }
        if (c == "]") cls = 0
        cur = cur c; continue }
      if (c == "[") { cls = 1; cur = cur c; if (substr(s, i + 1, 1) == "^") { cur = cur "^"; i++ } continue }
      if (c == "(") d++
      if (c == ")") d--
      if (c == "|" && d == 0) { print cur; cur = ""; continue }
      cur = cur c }
    print cur }'
}
# key_in ALT KEY: KEY is a literal piece of ALT, or, written with a leading `=`, all of it (`=hostapd` is the alternative hostapd, not the one of hostapd_cli)
key_in() { case $2 in =*) [ "$1" = "${2#=}" ] ;; *) case $1 in *"$2"*) return 0 ;; esac; return 1 ;; esac; }
min_alts() { case $1 in netsurf) echo "$MIN_ALTS_NETSURF";; netx) echo "$MIN_ALTS_NETX";; tx) echo "$MIN_ALTS_TX";; iw) echo "$MIN_ALTS_IW";; bt) echo "$MIN_ALTS_BT";; btwrap) echo "$MIN_ALTS_BTWRAP";; pnet) echo "$MIN_ALTS_PNET";; *) echo "$MIN_ALTS_SEC6";; esac; }
na=0; naok=0; nablind=0; nawrong=0; nauncov=0; nasetup=0; nafam=0; naderived=0

# run_group FILE KIND FAMILIES [FUNCTION]: every entry of those families planted in ONE copy (kind append = a line, fn = a function of its own
# each, or with FUNCTION one function of that name holding every sample), one checker run, then each sample's own line must appear in the evidence
# of its row
run_group() {
  _gf="$work/$1"; _kind=$2; _fams=" $3 "; _gfn=${4:-}
  rm -rf "$work"; cp -R "$base" "$work" || { nasetup=$((nasetup + 1)); return 0; }
  ensure_nl "$_gf"; _c=$(wc -l < "$_gf" | tr -d ' '); : > "$tmp/grp"
  if [ -n "$_gfn" ]; then printf '%s\n' "$_gfn() {" >> "$_gf"; _c=$((_c + 1)); fi
  while IFS="$TAB" read -r _f _k _sm _rw _st; do
    case $_fams in *" $_f "*) ;; *) continue ;; esac
    if [ -n "$_gfn" ]; then printf '%s\n' "    $_sm" >> "$_gf"; _c=$((_c + 1)); _at=$_c
    elif [ "$_kind" = fn ]; then
      printf '%s\n' "zz_alt$_c() {" "    $_sm" '    :' '}' >> "$_gf"; _at=$((_c + 2)); _c=$((_c + 4))
    else printf '%s\n' "$_sm" >> "$_gf"; _c=$((_c + 1)); _at=$_c; fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$_f" "$_k" "$_rw" "$_at" "$_st" >> "$tmp/grp"
  done < "$tmp/ents"
  if [ -n "$_gfn" ]; then printf '%s\n' '    :' '}' >> "$_gf"; fi
  run_check "$work" > "$tmp/aout" 2>&1; _arc=$?
  [ "$_arc" -lt 2 ] || { nasetup=$((nasetup + 1)); echo "alt probe: the checker exited $_arc on the planted copy" >&2; return 0; }
  # evidence: "row<TAB>indented evidence line" for every indented line under a row
  awk 'BEGIN { OFS = "\t" } /^    / { if (row != "") print row, $0; next } { row = $0 }' "$tmp/aout" > "$tmp/ev"
  while IFS="$TAB" read -r _f _k _rw _at _st; do
    na=$((na + 1))
    _rows=$(awk -F'\t' -v L="$_at" '{ e = $2; sub(/^    /, "", e); n = split(e, a, ":"); v = (a[1] ~ /^[0-9]+$/) ? a[1] : a[2]; if (v == L) print $1 }' "$tmp/ev")
    _hit=0; _other=""; _prim=${_rw%%|*}; _tol=""; case $_rw in *'|'*) _tol=${_rw#*|} ;; esac
    while IFS= read -r _r; do
      [ -n "$_r" ] || continue
      case $_r in "$_prim"*) _hit=1; continue ;; esac
      _ok=0; _ifs=$IFS; IFS='|'; for _x in $_tol; do case $_r in "$_x"*) _ok=1 ;; esac; done; IFS=$_ifs   # a row the entry tolerates on the same line
      [ "$_ok" = 1 ] || _other="$_other [$(printf '%s' "$_r" | cut -c1-40)]"
    done <<EOF
$_rows
EOF
    if [ "$_st" = orphan ]; then nablind=$((nablind + 1)); printf 'alt %s %s: GREEN (BLIND!) no alternative of the checker contains this key any more (removed, or renamed: adjust the table)\n' "$_f" "$_k"
    elif [ "$_hit" = 0 ]; then nablind=$((nablind + 1)); printf 'alt %s %s: GREEN (BLIND!) line %s not listed under "%s"\n' "$_f" "$_k" "$_at" "$_rw"
    elif [ -n "$_other" ]; then nawrong=$((nawrong + 1)); printf 'alt %s %s: WRONG-ROW also listed under:%s\n' "$_f" "$_k" "$_other"
    else naok=$((naok + 1)); printf 'alt %s %s: RED %s (line %s)\n' "$_f" "$_k" "$_rw" "$_at"; fi
  done < "$tmp/grp"
}

alt_probe() {
  if ! run_check "$base" --regexes > "$tmp/rx" 2> "$tmp/rx.err" || [ ! -s "$tmp/rx" ]; then
    echo "alt probe: the checker prints no regex families (--regexes)" >&2; nasetup=$((nasetup + 1)); return 0; fi
  : > "$tmp/ents"
  for _spec in netsurf:NETSURF_RE netx:NETX tx:TX_WORDS iw:IW_VERBS sec6:SEC6_RE bt:BT_WORDS btwrap:BT_WRAP_RE pnet:PNET_WORDS; do
    _fam=${_spec%%:*}; _var=${_spec#*:}
    _re=$(awk -F'\t' -v N="$_var" '$1 == N { print $2; exit }' "$tmp/rx")
    split_alts "$_re" > "$tmp/alts.$_fam"; _n=$(grep -c '' "$tmp/alts.$_fam")
    nafam=$((nafam + 1)); naderived=$((naderived + _n))
    # a sample is read with the boundaries its family has in the checker (a word of TX_WORDS or BT_WORDS stands between characters that are no part of a name: hostapd_cli is no hostapd)
    case $_fam in tx) _pre='(^|[^A-Za-z0-9_-])('; _suf=')([^A-Za-z0-9_]|$)' ;; bt|pnet) _pre='(^|[^A-Za-z0-9_-])('; _suf=')([^A-Za-z0-9_-]|$)' ;; *) _pre='('; _suf=')' ;; esac
    if [ "$_n" -lt "$(min_alts "$_fam")" ]; then
      printf 'alt %s: SETUP-ERROR %s alternatives derived from %s (want at least %s)\n' "$_fam" "$_n" "$_var" "$(min_alts "$_fam")"; nasetup=$((nasetup + 1)); fi
    # every derived alternative needs a sample
    while IFS= read -r _a; do
      _hit=0
      while IFS="$TAB" read -r _f _k _sm _rw; do
        [ "$_f" = "$_fam" ] || continue
        key_in "$_a" "$_k" && _hit=$((_hit + 1))
      done < "$altfile"
      [ "$_hit" -ge 1 ] || { nauncov=$((nauncov + 1)); printf 'alt %s: UNCOVERED alternative %s (no sample in the table: add one line, or the alternative is new)\n' "$_fam" "$_a"; }
    done < "$tmp/alts.$_fam"
    # every table entry: one alternative contains its key, that one matches the sample, no other does
    while IFS="$TAB" read -r _f _k _sm _rw; do
      [ "$_f" = "$_fam" ] || continue
      _cnt=0; _own=""
      while IFS= read -r _a; do if key_in "$_a" "$_k"; then _cnt=$((_cnt + 1)); _own=$_a; fi; done < "$tmp/alts.$_fam"
      _st=ok
      if [ "$_cnt" = 0 ]; then _st=orphan
      elif [ "$_cnt" -gt 1 ]; then _st=bad; printf 'alt %s %s: SETUP-ERROR key stands in %s alternatives (want 1)\n' "$_fam" "$_k" "$_cnt"; nasetup=$((nasetup + 1))
      else
        _m=0; while IFS= read -r _a; do printf '%s\n' "$_sm" | grep -qE -- "$_pre$_a$_suf" && _m=$((_m + 1)); done < "$tmp/alts.$_fam"
        if ! { printf '%s\n' "$_sm" | grep -qE -- "$_pre$_own$_suf" && [ "$_m" = 1 ]; }; then _st=bad; printf 'alt %s %s: SETUP-ERROR sample matches %s alternatives of the family, its own included or not (want exactly its own)\n' "$_fam" "$_k" "$_m"; nasetup=$((nasetup + 1)); fi
      fi
      [ "$_st" = bad ] || printf '%s\t%s\t%s\t%s\t%s\n' "$_f" "$_k" "$_sm" "$_rw" "$_st" >> "$tmp/ents"
    done < "$altfile"
  done
  run_group starchorus.html append 'netsurf netx'
  run_group starchorus-collect.sh fn 'tx iw sec6 bt'
  run_group starchorus-collect.sh fn 'btwrap' bt_busy
  run_group tools/device-probe.sh fn 'pnet'
  printf 'alternatives: %s/%s planted samples red on their row (%s families, %s alternatives derived), %s uncovered, %s blind, %s wrong-row\n' "$naok" "$na" "$nafam" "$naderived" "$nauncov" "$nablind" "$nawrong"
}
alt_ok() { [ "$na" -ge 1 ] && [ "$naok" = "$na" ] && [ "$nauncov" = 0 ] && [ "$nablind" = 0 ] && [ "$nawrong" = 0 ] && [ "$nasetup" = 0 ]; }

if [ "$sel" = alts ]; then alt_probe; alt_ok; exit $?; fi
if [ -n "$sel" ]; then
  [ "$seen_sel" = 1 ] || { echo "passivity-mutate: no mutation named $sel" >&2; exit 2; }
  [ "$nsetup" = 0 ] && [ "$ngreen" = 0 ] && [ "$nwrong" = 0 ]; exit $?
fi
alt_probe

# ============================== verdict ==============================
uncovered=""; _ifs=$IFS; IFS='|'; for _p in $ROWS; do case "$covered" in *"|$_p|"*) ;; *) uncovered="$uncovered [$_p]" ;; esac; done; IFS=$_ifs
nrows=$(printf '%s\n' "$ROWS" | tr '|' '\n' | wc -l | tr -d ' ')
printf 'row coverage: every checker row red at least once, not yet red:%s\n' "${uncovered:- none}"
printf 'control mutations: %s/%s stayed green\n' "$nctlok" "$nctl"
# The closing line names a SETUP-ERROR: a legitimate reformatting of a target line in the collector/page (a line break, a
# changed option order) makes the mutation's target text vanish; "N/N red, 0 green" would say nothing about that and exit 1
# without a word on what to adapt. So the row says what to change and where.
if [ "$nsetup" != 0 ] || [ "${nasetup:-0}" != 0 ]; then
  printf 'passivity mutation probe: SETUP-ERROR in %s mutation(s) [%s] and %s alternative table entries: a target text was not found exactly once (or a family too small); %s/%s red on the expected rows, %s green, %s wrong-row; %s/%s alternatives red, %s uncovered. Nothing is proven for the failed ones. Fix: after a legitimate edit of the collector/page/display line, update the target text of that entry in the mut/alt table of tools/passivity-mutate.sh (grep -nE "^mut +(%s) " tools/passivity-mutate.sh) to the new wording of the file, or restore the line; then rerun.\n' \
    "$nsetup" "${setup_names# }" "${nasetup:-0}" "$nok" "$nmut" "$ngreen" "$nwrong" "$naok" "$na" "$nauncov" "$(printf '%s' "${setup_names# }" | tr ' ' '|')"
  exit 1
fi
[ "$npend" = 0 ] || printf 'pending: %s mutation(s) wait for lines of the Bluetooth code of the collector (%s); they run as soon as the checker no longer announces them\n' "$npend" "$pending"
printf 'passivity mutation probe: %s/%s red on the expected rows, %s pending, %s green, %s wrong-row; %s/%s alternatives red, %s uncovered\n' "$nok" "$nmut" "$npend" "$ngreen" "$nwrong" "$naok" "$na" "$nauncov"
[ "$((nmut + npend))" -ge "$MIN_MUT" ] && [ "$nok" = "$nmut" ] && [ "$nctlok" = "$nctl" ] && [ -z "$uncovered" ] && [ "$nrows" -ge "$MIN_ROWS" ] && alt_ok
exit $?
