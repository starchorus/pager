#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/passivity-mutate.sh -- proves that every rule family of tools/passivity-check.sh can turn red.
# usage: sh tools/passivity-mutate.sh [--only NAME|alts] [--meta] [--shard I/N | --merge FILE...]      (any cwd; dev machine; sends nothing, opens no socket)
#   (default)    unmutated copy first (must be exit 0), then one FRESH copy per mutation with exactly ONE changed/added
#                line; the set of red rows must equal the pinned set; then the alternative probe (below).
#                Exit 0 = every line below matches, 1 = a miss, 2 = setup.
#   --only NAME  one mutation (used by --meta and for debugging); --only alts = the alternative probe alone
#   --meta       the probe of the probe: blinds one rule family, or ONE alternative of one, in an image of the checker and
#                demands that THIS script then reports GREEN (BLIND!) for the matching mutation / alternative.
#   --shard I/N  the default run, or --meta, cut into N shards: this is shard I (0 to N-1); it runs the entries of the table that are its turn, prints their lines tagged for the merge and
#                then its sums (no verdict, exit 0). tools/regress.d/mutation-probe.sh starts the shards of both modes at the same time (SHARDS, below).
#   --merge FILE...   the N shard files of ONE mode (--meta before --merge for the meta mode): checks that they add up, prints the lines of the entries in the order of the table and then the
#                verdict of the summed counters, which is what the run without shards prints, line for line, with its exit status.
# Alternative probe: the regex families of the checker (`--regexes`: NETSURF_RE, NETX, TX_WORDS, IW_VERBS, SEC6_RE, BT_WORDS, BT_WRAP_RE, PNET_WORDS, OUT_WORDS, CHG_VERBS, TC_NOUNS)
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
#                 and what it compares (an edited pinned line, a vanished one, a copy of one); the `dyn-ok-` controls must stay green. The two `dyn-limit-` entries
#                 (`-eval`, `-awk`) were controls that wrote down what the row does not read (a built string handed to eval or to an awk system()); the row '§14.6h' reads those places now, and they are mutations with that row red.
# BUILT NAMES, THE SECOND ROW: '§14.6e command names from a glob, find -exec, xargs or alias' is the second verdict of the same pass. The `dyn-glob`, `dyn-glob-star`, `dyn-bracket` and
#                 `dyn-iw-glob` mutations plant a glob character in a command word, the `dyn-find-` ones `find` with each of `-exec`, `-execdir`, `-ok` and `-okdir`, the `dyn-xargs-` ones an
#                 `xargs` whose command is its replacement string (`{}` and one of its own) or is missing, `dyn-alias` an alias; the `dyn-ok-` controls (a glob in a for-list, a case pattern
#                 or as an argument, the test `[ ]`, a `${ }` with a blank or a parenthesis, `find` without `-exec`, an `alias` that only looks) stay green (`xargs` with its own command is red on the row '§14.6h' only: `dyn-ok-xargs-literal`). The two
#                 `dyn-limit-` ones that were added (a glob only handed to `ln`, a built string piped into `sh`) were controls too; the row '§14.6h' pins both places now (`ln` and a pipe into a shell), and they are mutations with that row red.
# DOCROOT:        the row '§14.6f docroot of the page servers' reads every docroot argument on a code line of the shell scope whose ARG names STARCHORUS_DIR (`-h ARG`, `--directory ARG` and `--directory=ARG` on any line; on a line that
#                 names a page server also the argument glued to the option, a cluster of options that ends in h, `-d ARG` and an abbreviated long option) and wants it to be exactly "$STARCHORUS_DIR/www" (the directory that holds
#                 the two links, not the whole of STARCHORUS_DIR), with a floor of lines so that it cannot turn green because they went; every line of a here-document body is read. The `docroot-` mutations plant the whole directory
#                 in the launcher (`docroot-whole-launcher`, `-whole-uhttpd-launcher`: pinned lines, so the row of the built names is red as well) and in each form of the argument in the payload of the library (`-uhttpd-whole`,
#                 `-python-whole`, `-python-whole-eq`, `-attached`, `-cluster`, `-cluster-attached`, `-python-d`, `-python-d-attached`, `-python-abbrev`, `-python-abbrev-eq`), the right directory written otherwise (`-unquoted`,
#                 `-braced`, `-suffix-outside`), a sub-directory (`-subdir`), the whole directory in a quoted here-document body, in a line after a here-document opener inside a string and in a bare one (`-heredoc-quoted`,
#                 `-heredoc-in-string`, `-heredoc-bare`, `-heredoc-after`), the right directory with text glued on after the closing quote (`-www-parent`, `-www-parent-quoted`: the word is the whole
#                 directory), python's `-d` and `--dir` on a line continued from the one that names the server (`-python-d-continued`, `-python-abbrev-continued`), and a line that loses its argument (`-floor`: the floor and the pin). The controls `docroot-ok-www`, `-ok-python-d-www`, `-ok-cluster-www`, `-ok-comment`,
#                 `-ok-test-d` (a `[ -d ]` test on a line that names no page server) and `-ok-continued-www` (the right directory on a continued line) stay green. Each part of the row is blinded once in the meta probe.
#                 Since 24 October 2026 the row also holds that on a line that names a page server and is no message EVERY docroot argument is exactly "$STARCHORUS_DIR/www", and that a launch (the server as the command of a simple command, also
#                 behind a wrapper, a path, a keyword or $NICE) with no docroot option at all is red. `docroot-ok-other-dir`, `-limit-alias` and `-limit-cd` are mutations with the row red now (the names stay); the six forms of the sighting are
#                 `-limit-alias` (a variable), `-limit-cd` (`-h .` after a cd), `-no-directory`, `-config-file`, `-root-dir` (`-ok-other-dir` is the same with /www) and `-printf-pipe`; `docroot-launch-` plants the other launches without an option, `docroot-echo-` the ways round the message exemption, `docroot-two-docroots`,
#                 `-python-other-dir`, `-cluster-other-dir` and `-function-argument` other arguments; the controls `docroot-ok-message`, `-ok-command-v`, `-ok-pidof` and the limits `-limit-config-beside` (the right directory beside a configuration file) stay green.
# DEVICE PROBE:   tools/device-probe.sh runs on the device and is in the scope of the checker with three rows of its own ('device-probe.sh scope fill', 'named tools', 'programs'; row 7d there). The `probe-`
#                 mutations plant into a copy of the probe what the rows read: a sending, scanning, Bluetooth or network tool (also in a function that has the name of an allowlisted function of the collector), an
#                 `iw` that sets something, a built or globbed command word, a program no list names, a function with the name of a listed program, and the pinned lines (one changed by one character, one gone, one
#                 copied into another function); `probe-pin-in-collector` shows that a pin of the probe does not cover the same line in the collector, and `probe-limit-collector-curl` that a `curl` in the collector
#                 is red on the row '§14.6g' (it was a control until that row came: the collector was not read for the network words, which PNET_WORDS keeps for the probe). The `probe-ok-` controls (read commands, calls of its own functions, a comment, a case pattern, builtins) stay green. Every part of
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
# OUTWARD:        the row '§14.6g outward and state-changing programs' reads the literal command words of the shell scope (the reader of row 7d, names as the shell finds them) and is red for a program of OUT_WORDS (curl, wget, ping, ssh,
#                 telnet, nslookup, ntpd, opkg, nc, ftpput, mail, wifi, uci, nft, rfkill ...), for iw, ip and tc with a changing verb (CHG_VERBS; tc also TC_NOUNS), for ifconfig given more than an interface, for a redirection, tee or dd of= into /sys,
#                 /proc/sys, /dev/tcp or /dev/udp, for a name among the arguments of a program that runs its operand (flock, start-stop-daemon, su -c ...), for a start script by its path and for a name that is not spelled in one piece on its line.
#                 The `out-` mutations plant one line of each family in the collector (the sighting's lines: the 22 programs and verbs, then every word of the list by the alternative probe: `alt out`, `alt chg`, `alt tcn`), one in the payload
#                 of the library, the root payload, both Overview copies, the listener and a helper without the suffix, and the forms the reader reads (behind nice, env, timeout, exec, command, busybox, xargs, with a path, in quotes, after a
#                 separator, a keyword, in a substitution, a pipe, a case arm, a redirection, across a line, in a here-document with a bare delimiter, in a script text and above the first head of the handler); `out-wrapper-path`, `-env-u`,
#                 `-sudo-u`, `-stdbuf-o`, `-exec-a` and `-env-split-string` plant the wrappers with a path or an option that takes a word, `out-glued-` a word that an escaped newline or quotes put together; `out-sys-` every spelling of the
#                 second rule; `out-pin-` the six pins edited, gone, copied into another function and into another file; `out-floor-pins` and `-cmds` raise the two floors; `out-probe-curl` is red on the rows of the probe and not on this one.
#                 The `out-ok-` controls (a comment, a string, an awk program, a quoted here-document, a presence test, names that only start with a word of the list, reads with ip, iw and ifconfig, reads from /sys, descriptors, /dev/null,
#                 private tee and dd) stay green, and the `out-limit-` ones write down what the row does not read (a path from a variable, a program copied to another name, a trap string, an awk getline, a built name).
#                 `dyn-limit-eval`, `-awk`, `-ln` and `-pipe-sh`, `dyn-ok-xargs-literal`, `probe-limit-collector-curl` and the docroot entries `-ok-other-dir`, `-limit-alias` and `-limit-cd` were controls and are mutations now: the new rows read them.
# SINKS:          the row '§14.6h program-text sinks' pins the places where a program text is made or taken and run: eval, ln, xargs, `.` and source as command words, a shell with -c or without a file operand (a pipe into a shell, -s, a
#                 here-document), find -exec, su and script -c, an interpreter with -c, an exec of a built word, and the awk function system( on a code line. The `sink-` mutations plant each of them (also behind a wrapper, with a path,
#                 in quotes, across lines, in a here-document with a bare delimiter, in the lower part of the handler of the listener and in the part above its first head, which the head `init() {` makes code), in the payload of the library,
#                 the root payload, both Overview copies, the listener and a helper; `sink-pin-` the pins edited, gone, copied (a fifth copy of a line that is pinned four times) and copied into another file. The `sink-ok-` controls (the words
#                 in a comment, a string, an awk program and a quoted here-document, `exec` in a comment and as a redirection only or with a literal command, `sh FILE`, `find -print`, names that only contain a word, a `.` as an argument) stay green; the
#                 `sink-limit-shell-file` control writes down that a shell run on a file the script wrote is not read.
# ROUND TWO:      the review of 24 October 2026 on the rows 6g, 6h and 6f, and the bypasses found while the first fixes were tested. Everything below only ADDS; a control that the new reading turns red is a mutation with its name kept and a
#                 comment at its line (`out-limit-verb-expansion`, `-trap-string`, `-getline`, `sink-ok-shell-file`, `sink-limit-shell-file`, and the nine of the first round); an old blinding that the new reading made redundant is replaced by one that
#                 shows the same thing (`probe-fdef-cont-blind`, `docroot-floor-blind` and the other docroot blinds: the line they planted is red for a second reason now), the others keep their target. `ip` and `tc` take every unambiguous prefix of
#                 a verb (`out-ip-abbrev-`, `out-tc-abbrev`, `out-ip-batch-abbrev`, `-long`), `iw` is red for every command that does not read (`out-iw-` one command from each family: switch, offchannel, roc, ocb, auth, measurement, vendor, ap, cac,
#                 mpath, mesh, wowlan, coalesce, reg reload, a command from an expansion; `out-ok-iw-more` and `-options` the commands that read), the list of programs grew (`out-dbclient`, `-ether-wake`, `-whois`, `-openssl`, `-host`, `-mosquitto`,
#                 `-mount`, `-fw4`, `-mtd`, `-sysupgrade`, `-firstboot`, `-fw-setenv`, `-devmem`, `-i2cset`, `-hwclock`, `-macchanger`, `-wl`; the alternative probe plants every word) and so did the verb rules (`out-date-`, `out-iwinfo-scan`,
#                 `out-logger-`, `out-logread-remote`, `out-route-`, `out-arp-`, `out-hostname-`, `out-sys-sed`, `-sys-truncate`; the controls `out-ok-clock-reads`, `-log-reads`, `-net-reads`, `-sed-reads`, `-names-new`). The action of a trap
#                 is read as code (`out-trap-` a string, a name, a nested trap, three deep, in the payload, the Overview, the listener's handler; `sink-trap-` the forms that are a record of the row 6h: an expansion, a string over several lines,
#                 a glued string, an option, four deep; `out-ok-traps` the actions that run nothing). The row 6h reads an awk command pipe and `awk -f` (`sink-awk-`), the shells and interpreters that read their program from the standard input or
#                 a file (`sink-sh-`, `sink-interp-`, `sink-run-file-`; `sink-ok-shell-self`, `-shell-plus`, `-shell-twice`, `-interp-flags`), `tcpdump -z` and the options of `tar` that run a program (`sink-tcpdump-z`, `sink-tar-`), the dot commands
#                 of the sqlite3 shell (`sink-sqlite-`), a program run by a path outside the system directories (`sink-path-`; `sink-ok-path-system`) and states a limit (`sink-limit-written-program`: a script that the script wrote into a directory of
#                 the PATH and runs by its name). The docroot row reads a docroot named only in a comment, python's `-m` in a cluster or glued, and the programs that run their operand (`docroot-launch-comment`, `docroot-python-`, one
#                 `docroot-launch-` for each of the seventeen programs, `docroot-ok-` the same with the right directory). Each new rule is blinded once in the meta probe (`out-prefix-`, `out-iw-`, `out-date-`, `out-trap-`, `sink-`, `docroot-` ...).
#                 The third round (24 October 2026): the docroot option per simple command (`docroot-launch-second-`, `-brace`, `-backtick`, `-quoted-option`; `docroot-ok-redirect-before`, `-brace-www`, `-background-www`), a verb or option from an
#                 expansion (`out-verb-expansion-`; `out-ok-expansion-reads`, `-show-filter`), the BusyBox applets of ip (`out-ip-applet-`; `out-ok-ip-applets`), the operand runners and `builtin` (`out-runner-`, `out-builtin`, `-builtin-command`; `out-ok-builtin`),
#                 `watch`, `run-parts`, `flock -c` and the long forms of `su --command` on row 6h (`sink-watch`, `sink-run-parts`, `sink-flock-c`, `sink-su-`, `sink-runuser-c-glued`, `sink-wrapped-chpst-sh`; `sink-ok-flock-long`), and a limit (`sink-limit-sed-e`).
#                 `docroot-launch-watch` is red on row 6h as well now (watch is a sink by name). Each new rule is blinded once in the meta probe (`docroot-per-command-`, `-brace-`, `-backtick-`, `-quoted-option-`, `-descriptor-`, `out-verb-expansion-`,
#                 `out-route-expansion-`, `out-arp-expansion-`, `out-iwinfo-`, `out-logger-`, `out-logread-expansion-`, `out-ip-applet-`, `out-runner-`, `out-builtin-`, `sink-watch-`, `sink-run-parts-`, `sink-flock-c-`, `sink-command-`, `sink-glued-c-`, `sink-runner-chpst-`).
#                 Its second half (26 October 2026): the names OUT_WORDS gained (BusyBox's other network applets and flash writers, the scanners, the mDNS tools, lftp and ncftp, SNMP, at and batch, the modem tools, the page servers that are not
#                 route A's), one family each outside the collector (`out-applet-`, `out-flash-`, `out-scan-`, `out-mdns-`, `out-ftp-`, `out-snmp-`, `out-at-`, `out-modem-`, `out-server-` one per server; the alternative probe plants every name), and
#                 `bridge` read by its verbs as `ip` is (`out-bridge-`; `out-ok-bridge-reads`), each blinded in the meta probe (`out-bridge-`, `alt-out-`, `out-server-lighttpd-blind`). Two blinds of the first half aimed at code that a later rule
#                 covers twice and were retargeted, names kept: `docroot-comment-blind` (the code of the line is the whole line again) and `sink-wrapped-blind` (the wrapped shell of `sink-wrapped-strace`, since flock -c reads the `-c` of flock-sh).
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
# SHARDS:         the entries of a table (mut, mutr1, metaprobe, and the alternative probe as one entry) are independent: each is judged on a copy of its own and adds only to sums and to a set of rows.
#                 So N shards can share the table: shard I runs the entries whose turn it is (the n-th goes to shard n mod N; the long ones, the alternative probe and the images whose child runs it,
#                 are counted apart so that no shard gets them together), prints the lines of each tagged with its number, and ends with its sums (PART, COV), the names of the entries that failed to
#                 set up (SN) and END (which shard of how many, how many entries the table has, how many it ran). --merge refuses files that do not add up (a shard missing or cut short, another N,
#                 entries not run exactly once: never green with fewer entries), puts the lines back in the order of the table and lets the verdict below read the summed counters, so there is one verdict,
#                 not a second implementation of it. Nothing is started here: the shards are started by tools/regress.d/mutation-probe.sh, and self_guard() counts what it always counted. The unmutated
#                 copy is checked by every shard of the default run (a red one ends them at once), its line is printed by shard 0.
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

MIN_MUT=796    # mutations in the table, controls not counted (≥, PENDING ones included); count: sh tools/passivity-mutate.sh | grep -c '^mutation ' (927 lines: 796 and 131 controls; as of 26 October 2026)
# alternatives per regex family (≥, only ever raised; raised with every name V-13 of docs/device-notes.md adds); count: sh tools/passivity-mutate.sh | grep -c '^alt <family> '
# (family: netsurf 6, netx 19, tx 32, iw 3, sec6 21, bt 43, btwrap 15, pnet 31, out 108, chg 12, tcn 3)
MIN_ALTS_NETSURF=6; MIN_ALTS_NETX=19; MIN_ALTS_TX=32; MIN_ALTS_IW=3; MIN_ALTS_SEC6=21; MIN_ALTS_BT=44; MIN_ALTS_BTWRAP=15; MIN_ALTS_PNET=31; MIN_ALTS_OUT=163; MIN_ALTS_CHG=12; MIN_ALTS_TCN=3
MIN_ROWS=27   # PASS rows of the unmutated copy (≥); count: sh tools/passivity-check.sh | grep -c ' PASS$'   (13 before the Bluetooth rows, minus the replaced hcitool row, plus seven, plus the row of the built names, plus the row of the glob, find, xargs and alias, plus the three rows of the device probe, plus the row of the docroot of the page servers, plus the rows of the outward programs and of the program-text sinks)

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
ROWS='§14.6 scope fill|HTML network surface|fetch( =|other network APIs|URLs outside|§14.6 device calls|§14.6 allowlist names|iw scan opt-in|transmit tools invoked|§14.6b Bluetooth words|Bluetooth allowlist names|Bluetooth lines in bt_begin|Bluetooth word forms|Bluetooth wrappers|Bluetooth command position|apcli_ro literal lines|§14.6d command words from an expansion|§14.6e command names from a glob|§14.6f docroot of the page servers|§14.6g outward and state-changing programs|§14.6h program-text sinks|sqlite3 read-only|starchorus-serve.sh: GET|device-probe.sh scope fill|device-probe.sh named tools|device-probe.sh programs|§14.7 denylist'

sel=""; meta=0; SHARD_I=0; SHARD_N=0; MERGE=0   # SHARD_N: 0 = no shards (the run as it always was), N >= 1 = this is shard SHARD_I of N, -1 = merging shard files
usage() { echo "usage: sh $0 [--only NAME] [--meta] [--shard I/N | --merge FILE...]" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case $1 in
    --only) sel=${2:-}; [ -n "$sel" ] || { echo "usage: --only NAME" >&2; exit 2; }; shift 2 ;;
    --meta) meta=1; shift ;;
    --shard) case ${2:-} in */*) SHARD_I=${2%%/*}; SHARD_N=${2#*/} ;; *) usage ;; esac
             case $SHARD_I in [0-9]|[0-9][0-9]) ;; *) usage ;; esac; case $SHARD_N in [0-9]|[0-9][0-9]) ;; *) usage ;; esac
             SHARD_I=${SHARD_I#0}; SHARD_I=${SHARD_I:-0}; SHARD_N=${SHARD_N#0}; SHARD_N=${SHARD_N:-0}
             { [ "$SHARD_N" -ge 1 ] && [ "$SHARD_N" -le 64 ] && [ "$SHARD_I" -lt "$SHARD_N" ]; } || usage
             shift 2 ;;
    --merge) MERGE=1; shift; break ;;   # what is left are the shard files
    *) usage ;;
  esac
done
if [ "$MERGE" = 1 ]; then { [ $# -gt 0 ] && [ -z "$sel" ] && [ "$SHARD_N" = 0 ]; } || usage; SHARD_N=-1; fi
if [ "$SHARD_N" -gt 0 ] && [ -n "$sel" ]; then usage; fi

nmut=0; nok=0; ngreen=0; nwrong=0; nctl=0; nctlok=0; nsetup=0; npend=0; setup_names=""; covered="|"
nm=0; nmok=0; na=0; naok=0; nablind=0; nawrong=0; nauncov=0; nasetup=0; nafam=0; naderived=0   # --meta's and the alternative probe's counters, here for a shard of either mode to print them all
seen_sel=0
TAB=$(printf '\t')

# ---- shards (see SHARDS in the header; tools/regress.d/mutation-probe.sh starts them)
_eidx=0; _gh=0; _gl=0; _gown=0
job_run() {   # job_run BODY ARG...: the body of an entry, by name (plain calls, so that ShellCheck sees that the bodies are used)
  case $1 in
    mut_one) shift; mut_one "$@" ;;
    mutr1_one) shift; mutr1_one "$@" ;;
    metaprobe_one) shift; metaprobe_one "$@" ;;
    alt_probe) alt_probe ;;
    *) echo "passivity-mutate: job_run: no entry body named $1" >&2; exit 2 ;;
  esac
}
# job HEAVY BODY ARG...: one entry of a table (HEAVY 1 = one of the long ones). Without shards BODY runs where it stands. A shard runs it when it is its turn (the n-th light entry goes to shard n mod N, the
# n-th long one likewise) and prints its lines as "L<TAB>entry<TAB>line<TAB>text", with a line "SN" for the name of an entry that failed to set up; a merge runs nothing.
job() {
  _jh=$1; shift
  [ "$SHARD_N" != 0 ] || { job_run "$@"; return $?; }
  [ "$SHARD_N" -gt 0 ] || return 0
  _eidx=$((_eidx + 1))
  if [ "$_jh" = 1 ]; then _gh=$((_gh + 1)); _gt=$(((_gh - 1) % SHARD_N)); else _gl=$((_gl + 1)); _gt=$(((_gl - 1) % SHARD_N)); fi
  [ "$_gt" = "$SHARD_I" ] || return 0
  _gown=$((_gown + 1)); _gn0=$setup_names
  job_run "$@" > "$tmp/job.out" 2>&1
  awk -v J="$_eidx" '{ printf "L\t%d\t%d\t%s\n", J, NR, $0 }' "$tmp/job.out"
  [ "$setup_names" = "$_gn0" ] || printf 'SN\t%s\t%s\n' "$_eidx" "${setup_names#"$_gn0"}"
}
# the last lines of a shard: its sums (PART, in the order merge_run reads them), the rows it saw red (COV) and the proof that it ended (END: which shard of how many, how many entries the table has, how many it ran, of which mode)
shard_end() {
  printf 'PART\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$nmut" "$nok" "$ngreen" "$nwrong" "$nctl" "$nctlok" "$nsetup" "$npend" "$nm" "$nmok" "$na" "$naok" "$nablind" "$nawrong" "$nauncov" "$nasetup" "$nafam" "$naderived"
  printf 'COV\t%s\n' "$covered"
  if [ "$meta" = 1 ]; then _gm=x; else _gm=m; fi
  printf 'END\t%s\t%s\t%s\t%s\t%s\n' "$SHARD_I" "$SHARD_N" "$_eidx" "$_gown" "$_gm"
}
# merge_run FILE...: the files of the N shards of one mode. Prints the lines of the entries in the order of the table, sets the counters that the verdict reads and returns 0; or says why the files do not add up
# (a shard missing, cut short, twice, of another N, or entries not run exactly once) with a line of the probe's own prefix, and returns 1: a merge never reads green for want of entries.
merge_run() {
  if [ "$meta" = 1 ]; then _mp='passivity meta probe'; _mm=x; else _mp='passivity mutation probe'; _mm=m; fi
  _mc=0; _mn=""; _mt=""; _mo=0; _mi=" "; _mred=""
  for _mf in "$@"; do
    _mc=$((_mc + 1))
    [ -r "$_mf" ] || { printf '%s: SETUP-ERROR the shard file %s is missing\n' "$_mp" "$_mf"; return 1; }
    if awk -F'\t' '$1 == "RED" { f = 1 } END { exit !f }' "$_mf"; then [ -n "$_mred" ] || _mred=$_mf; continue; fi
    _me=$(awk -F'\t' '$1 == "END" { n++; r = $2 " " $3 " " $4 " " $5 " " $6 } END { if (n == 1) print r }' "$_mf")
    _ei=""; _en=""; _et=""; _eo=""; _ek=""; _ex=""
    IFS=' ' read -r _ei _en _et _eo _ek _ex <<EOF
$_me
EOF
    _bad=0; for _v in "$_ei" "$_en" "$_et" "$_eo"; do case $_v in ''|*[!0-9]*) _bad=1 ;; esac; done
    if [ "$_bad" = 1 ] || [ -n "$_ex" ]; then printf '%s: SETUP-ERROR the shard file %s has no (or a second) END line: that shard was stopped or failed\n' "$_mp" "$_mf"; return 1; fi
    if [ "$_ek" != "$_mm" ]; then printf '%s: SETUP-ERROR the shard file %s is of the other mode (the default run and --meta each have their own shards and their own merge)\n' "$_mp" "$_mf"; return 1; fi
    [ -n "$_mn" ] || { _mn=$_en; _mt=$_et; }
    if [ "$_en" != "$_mn" ] || [ "$_et" != "$_mt" ] || [ "$_ei" -ge "$_en" ]; then printf '%s: SETUP-ERROR the shard file %s says shard %s of %s over %s entries, the first one says %s shards over %s entries\n' "$_mp" "$_mf" "$_ei" "$_en" "$_et" "$_mn" "$_mt"; return 1; fi
    case $_mi in *" $_ei "*) printf '%s: SETUP-ERROR shard %s is in two of the files (%s)\n' "$_mp" "$_ei" "$_mf"; return 1 ;; esac
    _mi="$_mi$_ei "; _mo=$((_mo + _eo))
  done
  if [ -n "$_mred" ]; then   # the unmutated copy was not green: the shard that said so tells it, as the run without shards does
    awk -F'\t' '$1 == "L"' "$_mred" | sort -t "$TAB" -k2,2n -k3,3n | cut -f4-
    awk -F'\t' '$1 == "E" { print $2 }' "$_mred" >&2
    return 1
  fi
  if [ "$_mc" != "$_mn" ] || [ "$_mo" != "$_mt" ]; then printf '%s: SETUP-ERROR %s shard file(s) for %s shards, and they ran %s of %s entries: nothing is proven\n' "$_mp" "$_mc" "$_mn" "$_mo" "$_mt"; return 1; fi
  awk -F'\t' '$1 !~ /^(L|SN|PART|COV|END|RED|E)$/ { print "passivity-mutate: not a shard line: " $0 > "/dev/stderr" }' "$@"
  awk -F'\t' '$1 == "L"' "$@" | sort -t "$TAB" -k2,2n -k3,3n | cut -f4-
  awk -F'\t' -v N="$_mn" '$1 == "PART" { n++; for (i = 2; i <= 19; i++) { if ($i !~ /^[0-9]+$/) b = 1; s[i] += $i } }
    END { if (n != N || b) print "bad"; else for (i = 2; i <= 19; i++) printf "%d%s", s[i], (i < 19 ? " " : "\n") }' "$@" > "$tmp/m.sum"
  _bad=0; IFS=' ' read -r nmut nok ngreen nwrong nctl nctlok nsetup npend nm nmok na naok nablind nawrong nauncov nasetup nafam naderived _ex < "$tmp/m.sum"
  case $nmut$nok$ngreen$nwrong$nctl$nctlok$nsetup$npend$nm$nmok$na$naok$nablind$nawrong$nauncov$nasetup$nafam$naderived in ''|*[!0-9]*) _bad=1 ;; esac
  if [ "$_bad" = 1 ]; then printf '%s: SETUP-ERROR the sums of the shards (PART lines) are missing or not numbers: nothing is proven\n' "$_mp"; return 1; fi
  awk -F'\t' '$1 == "COV" { print $2 }' "$@" > "$tmp/m.cov"
  covered="|"; while IFS= read -r _cv; do covered="$covered${_cv#|}"; done < "$tmp/m.cov"
  awk -F'\t' '$1 == "SN"' "$@" | sort -t "$TAB" -k2,2n > "$tmp/m.sn"
  setup_names=""; while IFS="$TAB" read -r _sk _si _ss; do setup_names="$setup_names$_ss"; done < "$tmp/m.sn"
  return 0
}

# mut NAME FILE KIND ARG1 ARG2 EXPECT   (EXPECT = "|"-separated row prefixes that must be red, and only those; "" = stays green)
# (a call of the table is a job, see job() above; mut_one is what one job does)
mut_one() {
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
mutr1_one() {
  [ -z "$sel" ] || [ "$sel" = "$1" ] || return 0
  if [ -n "$pending" ] && [ -f "$base/$2" ]; then
    case $3 in fnline) _tl="^$4() {" ;; *) _tl=$4 ;; esac
    if [ "$(nlit "$base/$2" "$_tl")" = 0 ]; then
      seen_sel=1; npend=$((npend + 1))
      printf 'mutation %s: PENDING (its target is not in %s yet; the checker still announces: %s)\n' "$1" "$2" "$pending"; return 0
    fi
  fi
  mut_one "$@"
}
mut() { job 0 mut_one "$@"; }
mutr1() { job 0 mutr1_one "$@"; }

# ============================== meta: the probe of the probe ==============================
if [ "$meta" = 1 ]; then
  nm=0; nmok=0
  # metaprobe NAME BLIND_FILE OLD NEW ONLY WANT: in an image of the repo, break the checker as described, then the copy of THIS
  # script run with `--only ONLY` must print a line starting with WANT (fixed text) and exit non-zero. (A call is a job, see job() above; the images whose child runs the alternative probe are the long ones.)
  metaprobe_one() {
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
  metaprobe() { case ${5:-} in alts) job 1 metaprobe_one "$@" ;; *) job 0 metaprobe_one "$@" ;; esac; }
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
  metaprobe dyn6e-wrapper-quote-blind tools/passivity-check.sh 'if (bn ~ /^(exec|command|nohup|setsid|nice|env|time|xargs|busybox|timeout|sudo|stdbuf)$/)' 'if (dtok ~ /^(exec|command|nohup|setsid|nice|env|time|xargs|busybox|timeout|sudo|stdbuf)$/)' dyn-wrapper-quoted 'mutation dyn-wrapper-quoted: GREEN (BLIND!)'
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
  metaprobe probe-record-blind tools/passivity-check.sh 'function rec(nm) { if ((CMDS != "" || NMS != "") && !dtexp && !dtglob) REC[++nrec] = nm }' 'function rec(nm) { nrec = nrec }' probe-ok-read 'mutation probe-ok-read: WRONG-ROW'
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
  metaprobe probe-fdef-cont-blind tools/passivity-check.sh '&& !cont && col' '&& col' probe-fn-continued-bare 'mutation probe-fn-continued-bare: GREEN (BLIND!)'
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
  metaprobe main-heredoc-line-end-blind tools/passivity-check.sh 'if (top != "q" && top != "d" && top != "H") { if (!DCONT) dfin();' 'if (top != "q" && top != "d") { if (!DCONT) dfin();' main-ok-heredoc-plain 'mutation main-ok-heredoc-plain: WRONG-ROW'
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
  # (j) the row of the docroot of the page servers (§14.6f), one part at a time: the row, the test of the argument, the `--directory=` form, the floor, the report; the mutation that plants what the part sees must say GREEN (BLIND!)
  metaprobe docroot-row-blind tools/passivity-check.sh '[ "$drok" = 1 ]' 'true' docroot-uhttpd-whole 'mutation docroot-uhttpd-whole: GREEN (BLIND!)'
  metaprobe docroot-arg-blind tools/passivity-check.sh 'if (arg != "\"$STARCHORUS_DIR/www\"") bad = 1' 'if (0) bad = 1' docroot-uhttpd-whole 'mutation docroot-uhttpd-whole: GREEN (BLIND!)'
  metaprobe docroot-arg-blind-python tools/passivity-check.sh 'if (arg != "\"$STARCHORUS_DIR/www\"") bad = 1' 'if (0) bad = 1' docroot-python-whole 'mutation docroot-python-whole: GREEN (BLIND!)'
  metaprobe docroot-equals-blind tools/passivity-check.sh '([ \t]+|=))" }' '([ \t]+))"; LAUNCH = "zz_never" }' docroot-python-whole-eq 'mutation docroot-python-whole-eq: GREEN (BLIND!)'
  metaprobe docroot-floor-blind tools/passivity-check.sh '[ "$ndr" -ge "$MIN_DOCROOT_LINES" ] && drok=1' 'drok=1' docroot-floor-vanished 'mutation docroot-floor-vanished: GREEN (BLIND!)'
  metaprobe docroot-report-blind tools/passivity-check.sh 'if (hit) { n++; if (bad) print rec > BADS }' 'if (hit) { n++ }' docroot-whole-launcher 'mutation docroot-whole-launcher: GREEN (BLIND!)'
  metaprobe docroot-spellings-blind-attached tools/passivity-check.sh 're = srv ? RE2 : RE1; if (srv && t ~ LAUNCH && launch(t)) hit = 1' 're = RE1' docroot-attached 'mutation docroot-attached: GREEN (BLIND!)'
  metaprobe docroot-spellings-blind-cluster tools/passivity-check.sh 're = srv ? RE2 : RE1; if (srv && t ~ LAUNCH && launch(t)) hit = 1' 're = RE1' docroot-cluster 'mutation docroot-cluster: GREEN (BLIND!)'
  metaprobe docroot-spellings-blind-python-d tools/passivity-check.sh 're = srv ? RE2 : RE1; if (srv && t ~ LAUNCH && launch(t)) hit = 1' 're = RE1' docroot-python-d 'mutation docroot-python-d: GREEN (BLIND!)'
  metaprobe docroot-spellings-blind-python-abbrev-eq tools/passivity-check.sh 're = srv ? RE2 : RE1; if (srv && t ~ LAUNCH && launch(t)) hit = 1' 're = RE1' docroot-python-abbrev-eq 'mutation docroot-python-abbrev-eq: GREEN (BLIND!)'
  metaprobe docroot-spellings-blind-control tools/passivity-check.sh 're = srv ? RE2 : RE1; if (srv && t ~ LAUNCH && launch(t)) hit = 1' 're = RE2' docroot-ok-test-d 'mutation docroot-ok-test-d: WRONG-ROW'
  metaprobe docroot-word-blind tools/passivity-check.sh 'w = w substr(s, 1, e + 1); s = substr(s, e + 2) }' 'return w substr(s, 1, e + 1) }' docroot-www-parent-quoted 'mutation docroot-www-parent-quoted: GREEN (BLIND!)'
  metaprobe docroot-continued-blind tools/passivity-check.sh 'if (match(t, /\\+$/) && RLENGTH % 2 == 1)' 'if (0)' docroot-python-d-continued-grep 'mutation docroot-python-d-continued-grep: GREEN (BLIND!)'
  # (k) the rows 6g and 6h, one part at a time. 6g: the row, the name test against the list, a verb missing from CHG_VERBS, a noun missing from TC_NOUNS, the second rule (the redirection, tee, dd of= and the paths of /proc/sys, /dev/tcp), the wrappers (a path, an option
  #     that takes a word), the programs that run the command they are given, the escaped newline in a word, the name that is not spelled in one piece, the start script, the pin comparison (new, vanished) and the two floors. The pins (iw, ip, ifconfig) are found
  #     through the verbs, so a verb part that the pins need turns the unmutated copy red: those are shown by a control that goes red (WRONG-ROW), as for the built names above.
  metaprobe out-row-blind tools/passivity-check.sh '[ "$g_ok" = 1 ]' 'true' out-curl 'mutation out-curl: GREEN (BLIND!)'
  metaprobe out-name-blind tools/passivity-check.sh 'if (n ~ RE) hit = 1 }' 'if (0) hit = 1 }' out-curl 'mutation out-curl: GREEN (BLIND!)'
  metaprobe out-name-blind-payload tools/passivity-check.sh 'if (n ~ RE) hit = 1 }' 'if (0) hit = 1 }' out-payload-curl 'mutation out-payload-curl: GREEN (BLIND!)'
  metaprobe out-verb-blind-flush tools/passivity-check.sh "CHG_VERBS='set|add|del|delete|flush|" "CHG_VERBS='set|add|del|delete|" out-ip-route-flush 'mutation out-ip-route-flush: GREEN (BLIND!)'
  metaprobe out-verb-blind-replace tools/passivity-check.sh '|change|replace|append|' '|change|append|' out-ip-route-replace 'mutation out-ip-route-replace: GREEN (BLIND!)'
  metaprobe out-verb-blind-delete tools/passivity-check.sh "CHG_VERBS='set|add|del|delete|" "CHG_VERBS='set|add|del|" out-ip-addr-delete 'mutation out-ip-addr-delete: GREEN (BLIND!)'
  metaprobe out-noun-blind-class tools/passivity-check.sh "TC_NOUNS='qdisc|class|filter'" "TC_NOUNS='qdisc|filter'" out-tc-class 'mutation out-tc-class: GREEN (BLIND!)'
  # (retargeted, round 3: the pinned `ip link set "$X" up` lines stay hits without the verb, since a word from an expansion before a read verb is red too, so the blinded verb is proven on a literal `ip link set` instead; the name stays)
  metaprobe out-verb-blind-pins tools/passivity-check.sh "CHG_VERBS='set|add|del|" "CHG_VERBS='zz_none|add|del|" out-ip-down 'mutation out-ip-down: GREEN (BLIND!)'
  metaprobe out-ifconfig-blind tools/passivity-check.sh 'if (++ifc == 2) REC[++nrec] = "chg:ifconfig"' 'if (++ifc == 99) REC[++nrec] = "chg:ifconfig"' out-ok-ifconfig 'mutation out-ok-ifconfig: WRONG-ROW'
  metaprobe out-ifconfig-first-blind tools/passivity-check.sh 'if (ifc == 0 && (a == "-a" || a == "-s" || a == "-v")) return; if (++ifc == 2)' 'if (++ifc == 2)' out-ok-ifconfig 'mutation out-ok-ifconfig: WRONG-ROW'
  metaprobe out-sys-blind tools/passivity-check.sh 'if (NMS != "") dsys()' 'if (0) dsys()' out-sys-echo 'mutation out-sys-echo: GREEN (BLIND!)'
  metaprobe out-sys-glued-blind tools/passivity-check.sh 'if (p > n) { sysn = 1; return }' 'if (p > n) { return }' out-sys-echo 'mutation out-sys-echo: GREEN (BLIND!)'
  metaprobe out-sys-tee-blind tools/passivity-check.sh 'if (a !~ /^-/ && syspath(a)) REC[++nrec] = "sys:tee"' 'if (0) REC[++nrec] = "sys:tee"' out-sys-tee 'mutation out-sys-tee: GREEN (BLIND!)'
  metaprobe out-sys-dd-blind tools/passivity-check.sh 'if (a ~ /^of=/ && syspath(substr(a, 4))) REC[++nrec] = "sys:dd"' 'if (0) REC[++nrec] = "sys:dd"' out-sys-dd 'mutation out-sys-dd: GREEN (BLIND!)'
  metaprobe out-sys-proc-blind tools/passivity-check.sh ' || v ~ /^\/proc\/sys/' '' out-sys-proc 'mutation out-sys-proc: GREEN (BLIND!)'
  metaprobe out-dev-blind tools/passivity-check.sh ' || (v ~ /^\/dev\// && v !~ /^\/dev\/(null|zero|full|stdout|stderr|tty|fd\/[0-9]+)$/)' '' out-dev-tcp 'mutation out-dev-tcp: GREEN (BLIND!)'
  metaprobe out-dev-blind-write tools/passivity-check.sh ' || (v ~ /^\/dev\// && v !~ /^\/dev\/(null|zero|full|stdout|stderr|tty|fd\/[0-9]+)$/)' '' out-dev-write 'mutation out-dev-write: GREEN (BLIND!)'
  metaprobe out-dev-blind-dd tools/passivity-check.sh ' || (v ~ /^\/dev\// && v !~ /^\/dev\/(null|zero|full|stdout|stderr|tty|fd\/[0-9]+)$/)' '' out-dev-dd 'mutation out-dev-dd: GREEN (BLIND!)'
  metaprobe out-cp-blind tools/passivity-check.sh 'if (++cpn >= 2 && syspath(a)) REC[++nrec] = "sys:cp"' 'if (++cpn >= 2 && 0) REC[++nrec] = "sys:cp"' out-cp-sys 'mutation out-cp-sys: GREEN (BLIND!)'
  metaprobe out-cp-target-blind tools/passivity-check.sh 'if (cpt) { cpt = 0; if (syspath(a)) REC[++nrec] = "sys:cp"; return }' 'if (cpt) { cpt = 0; return }' out-cp-target 'mutation out-cp-target: GREEN (BLIND!)'
  metaprobe out-cp-target-long-blind tools/passivity-check.sh 'if (a ~ /^--target-directory=/) { if (syspath(substr(a, 20))) REC[++nrec] = "sys:cp"; return }' 'if (a ~ /^--target-directory=/) { return }' out-cp-target-long 'mutation out-cp-target-long: GREEN (BLIND!)'
  metaprobe out-module-blind tools/passivity-check.sh 'else if (pym) { pym = 0; if (a !~ /^http\.server$/) REC[++nrec] = "chg:module" }' 'else if (pym) { pym = 0 }' out-python-module 'mutation out-python-module: GREEN (BLIND!)'
  metaprobe out-sys-normal-blind tools/passivity-check.sh 'v = dnorm(w); gsub(/\/+/, "/", v)' 'v = dnorm(w)' out-sys-slashes 'mutation out-sys-slashes: GREEN (BLIND!)'
  metaprobe out-sys-quote-blind tools/passivity-check.sh 'function dnorm(w,   v) { v = w; gsub(/["\047\\]/, "", v); return v }' 'function dnorm(w,   v) { v = w; return v }' out-sys-quoted 'mutation out-sys-quoted: GREEN (BLIND!)'
  metaprobe out-wrapper-path-blind tools/passivity-check.sh 'bn = dn; sub(/^.*\//, "", bn)   # a wrapper' 'bn = dn   # a wrapper' out-wrapper-path 'mutation out-wrapper-path: GREEN (BLIND!)'
  metaprobe out-wrapper-option-blind-env tools/passivity-check.sh 'if (dwopt(dwc, dtok)) { dsk = 1; return }' 'if (0) { dsk = 1; return }' out-env-u 'mutation out-env-u: GREEN (BLIND!)'
  metaprobe out-wrapper-option-blind-sudo tools/passivity-check.sh 'if (dwopt(dwc, dtok)) { dsk = 1; return }' 'if (0) { dsk = 1; return }' out-sudo-u 'mutation out-sudo-u: GREEN (BLIND!)'
  metaprobe out-wrapper-option-blind-stdbuf tools/passivity-check.sh 'if (dwopt(dwc, dtok)) { dsk = 1; return }' 'if (0) { dsk = 1; return }' out-stdbuf-o 'mutation out-stdbuf-o: GREEN (BLIND!)'
  metaprobe out-wrapper-option-blind-a tools/passivity-check.sh 'if (dwopt(dwc, dtok)) { dsk = 1; return }' 'if (0) { dsk = 1; return }' out-exec-a 'mutation out-exec-a: GREEN (BLIND!)'
  metaprobe out-wrapped-blind tools/passivity-check.sh 'if (b ~ OUTRE) REC[++nrec] = "chg:wrapped"' 'if (0) REC[++nrec] = "chg:wrapped"' out-flock 'mutation out-flock: GREEN (BLIND!)'
  metaprobe out-wrapped-blind-start-stop tools/passivity-check.sh 'if (b ~ OUTRE) REC[++nrec] = "chg:wrapped"' 'if (0) REC[++nrec] = "chg:wrapped"' out-start-stop 'mutation out-start-stop: GREEN (BLIND!)'
  metaprobe out-continuation-blind tools/passivity-check.sh '{ if (!DCONT) dfin(); if (!DCONT && top' '{ dfin(); if (!DCONT && top' out-glued-continuation 'mutation out-glued-continuation: GREEN (BLIND!)'
  metaprobe out-glued-blind tools/passivity-check.sh 'if (index(t, n) == 0) hit = 1' 'if (0) hit = 1' out-glued-continuation-bt 'mutation out-glued-continuation-bt: GREEN (BLIND!)'
  metaprobe out-initd-blind tools/passivity-check.sh 'else if (n ~ /^\/etc\/(init|rc)\.d\//) hit = 1' 'else if (0) hit = 1' out-initd 'mutation out-initd: GREEN (BLIND!)'
  metaprobe out-blank-name-blind tools/passivity-check.sh 'else { sub(/[ \t].*/, "", n); sub(/^.*\//, "", n); if (n ~ RE) hit = 1 }' 'else { sub(/^.*\//, "", n); if (n ~ RE) hit = 1 }' out-env-split-string 'mutation out-env-split-string: GREEN (BLIND!)'
  metaprobe out-ip-batch-blind tools/passivity-check.sh '(dcmd == "ip" && a ~ /^-(b|batch)$/)' '(0)' out-ip-batch 'mutation out-ip-batch: GREEN (BLIND!)'
  metaprobe out-su-c-blind tools/passivity-check.sh '(dcmd == "su" || dcmd == "runuser" || dcmd == "script") && a ~ /^-[A-Za-z]*c$/' '0' out-su-c 'mutation out-su-c: GREEN (BLIND!)'
  metaprobe out-new-blind tools/passivity-check.sh '[ ! -s "$tmp/g_new" ] && [ ! -s "$tmp/g_gone" ] &&' '[ ! -s "$tmp/g_gone" ] &&' out-pin-copy 'mutation out-pin-copy: GREEN (BLIND!)'
  metaprobe out-gone-blind tools/passivity-check.sh '[ ! -s "$tmp/g_new" ] && [ ! -s "$tmp/g_gone" ] && [ "$g_p" -ge "$MIN_6G_PINS" ] &&' '[ ! -s "$tmp/g_new" ] &&' out-pin-gone 'mutation out-pin-gone: GREEN (BLIND!)'
  metaprobe out-floor-pins-blind tools/passivity-check.sh ' && [ "$g_p" -ge "$MIN_6G_PINS" ] &&' ' &&' out-floor-pins 'mutation out-floor-pins: GREEN (BLIND!)'
  metaprobe out-floor-cmds-blind tools/passivity-check.sh ' && [ "$g_n" -ge "$MIN_6G_CMDS" ] && g_ok=1' ' && g_ok=1' out-floor-cmds 'mutation out-floor-cmds: GREEN (BLIND!)'
  # 6h: the row, the commands the reader finds, the shells (a -c in a cluster, a shell that has no operand), find -exec, an interpreter, an exec of a built word, the text rule for system(, and the comparison with the pins
  metaprobe sink-row-blind tools/passivity-check.sh '[ "$s_ok" = 1 ]' 'true' sink-"ev"al 'mutation sink-eval: GREEN (BLIND!)'
  metaprobe sink-dot-blind tools/passivity-check.sh 'if (n ~ /^(eval|ln|xargs|\.|source)$/) hit[r] = 1' 'if (n ~ /^(eval|ln)$/) hit[r] = 1' sink-dot 'mutation sink-dot: GREEN (BLIND!)'
  metaprobe sink-source-blind tools/passivity-check.sh 'if (n ~ /^(eval|ln|xargs|\.|source)$/) hit[r] = 1' 'if (n ~ /^(eval|ln|xargs|\.)$/) hit[r] = 1' sink-"sour"ce 'mutation sink-source: GREEN (BLIND!)'
  metaprobe sink-xargs-blind tools/passivity-check.sh 'if (n ~ /^(eval|ln|xargs|\.|source)$/) hit[r] = 1' 'if (n ~ /^(eval|ln|\.|source)$/) hit[r] = 1' sink-xargs 'mutation sink-xargs: GREEN (BLIND!)'
  metaprobe sink-stdin-blind tools/passivity-check.sh 'if (hit[r] || nsh[r] > nop[r]) print r' 'if (hit[r]) print r' sink-pipe-sh 'mutation sink-pipe-sh: GREEN (BLIND!)'
  metaprobe sink-stdin-blind-next-line tools/passivity-check.sh 'if (hit[r] || nsh[r] > nop[r]) print r' 'if (hit[r]) print r' sink-pipe-next-line 'mutation sink-pipe-next-line: GREEN (BLIND!)'
  metaprobe sink-stdin-operand-blind tools/passivity-check.sh 'else if (a !~ /^-/ && ++shops == 1) REC[++nrec] = "snk:shell-file"' 'else if (0) REC[++nrec] = "snk:shell-file"' sink-ok-shell-self 'mutation sink-ok-shell-self: WRONG-ROW'
  # (retargeted on 24 October 2026: a shell given a FILE is red whatever its options, so the mutation of the cluster now gives it the script itself, which is the one file that is no program text)
  metaprobe sink-shell-cluster-blind tools/passivity-check.sh 'a ~ /^-[A-Za-z]*c[A-Za-z]*$/) REC[++nrec] = "snk:shell-c"' 'a ~ /^-c$/) REC[++nrec] = "snk:shell-c"' sink-sh-c-cluster-self 'mutation sink-sh-c-cluster-self: GREEN (BLIND!)'
  metaprobe sink-find-blind tools/passivity-check.sh 'if (dcmd == "find") { if (a ~ /^-(execdir|exec|okdir|ok)$/) REC[++nrec] = "snk:find-exec"; return }' 'if (dcmd == "find") { return }' sink-find-"ex"ec 'mutation sink-find-exec: GREEN (BLIND!)'
  metaprobe sink-interp-blind tools/passivity-check.sh '/^(python|python2|python3|perl|lua|ruby|php|node)$/' '/^(python|python2|python3|lua|ruby|php|node)$/' sink-interp-perl 'mutation sink-interp-perl: GREEN (BLIND!)'
  metaprobe sink-exec-built-blind tools/passivity-check.sh 'if (NMS != "" && wx && (dtexp || (dtglob && dtok !~ /^\[\[?$/))) REC[++nrec] = "snk:exec-built"' 'if (0) REC[++nrec] = "snk:exec-built"' sink-exec-built-wrapped 'mutation sink-exec-built-wrapped: GREEN (BLIND!)'
  metaprobe sink-exec-built-blind-plain tools/passivity-check.sh 'if (NMS != "" && wx && (dtexp || (dtglob && dtok !~ /^\[\[?$/))) REC[++nrec] = "snk:exec-built"' 'if (0) REC[++nrec] = "snk:exec-built"' sink-exec-built 'mutation sink-exec-built: GREEN (BLIND!)'
  metaprobe sink-su-blind tools/passivity-check.sh 'if ($1 ~ /^snk:/ && $1 != "snk:shell-file") hit[r] = 1' 'if (0) hit[r] = 1' sink-ok-comment 'mutation sink-ok-comment: WRONG-ROW'
  metaprobe sink-system-blind tools/passivity-check.sh "scoped_n '(^|[^A-Za-z0-9_])system[[:space:]]*\\(' > \"\$tmp/s_text\"" "scoped_n 'zz_none' > \"\$tmp/s_text\"" sink-system 'mutation sink-system: GREEN (BLIND!)'
  metaprobe sink-new-blind tools/passivity-check.sh '[ ! -s "$tmp/s_new" ] && [ ! -s "$tmp/s_gone" ] && s_ok=1' '[ ! -s "$tmp/s_gone" ] && s_ok=1' sink-pin-copy 'mutation sink-pin-copy: GREEN (BLIND!)'
  metaprobe sink-gone-blind tools/passivity-check.sh '[ ! -s "$tmp/s_new" ] && [ ! -s "$tmp/s_gone" ] && s_ok=1' '[ ! -s "$tmp/s_new" ] && s_ok=1' sink-pin-gone 'mutation sink-pin-gone: GREEN (BLIND!)'
  metaprobe sink-handler-head-blind starchorus-serve.sh 'init() {   # does nothing and is never called: a function head, so that tools/passivity-check.sh reads the lines below as code' 'init0() { :; }   # no head' sink-script-handler-top 'mutation sink-script-handler-top: GREEN (BLIND!)'
  # 6f: the launch rule, the message exemption (its three conditions), and the rule that every docroot argument of a server line counts
  # (retargeted, round 3: the per-command test, launch(c0, 1), reads a launch as well, so the four below blind the recognition of the server inside launch(), which both readings use; the names stay)
  metaprobe docroot-launch-blind tools/passivity-check.sh 'if (b ~ /^(uhttpd|httpd)$/) return 1' 'if (0) return 1' docroot-launch-bare 'mutation docroot-launch-bare: GREEN (BLIND!)'
  metaprobe docroot-launch-blind-config tools/passivity-check.sh 'if (b ~ /^(uhttpd|httpd)$/) return 1' 'if (0) return 1' docroot-config-file 'mutation docroot-config-file: GREEN (BLIND!)'
  metaprobe docroot-launch-blind-cd tools/passivity-check.sh 'if (b ~ /^python[0-9.]*$/ && pymod(w, j + 1, nw)) return 1' 'if (0) return 1' docroot-no-directory 'mutation docroot-no-directory: GREEN (BLIND!)'
  metaprobe docroot-launch-blind-wrapped tools/passivity-check.sh 'if (c ~ /^(uhttpd|httpd)$/) return 1' 'if (0) return 1' docroot-launch-wrapped 'mutation docroot-launch-wrapped: GREEN (BLIND!)'
  metaprobe docroot-launch-wrapper-blind tools/passivity-check.sh 'for (k = j + 1; k <= nw && k <= j + 12; k++) {' 'for (k = j + 1; k <= nw && k <= j; k++) {' docroot-launch-env-u 'mutation docroot-launch-env-u: GREEN (BLIND!)'
  metaprobe docroot-launch-wrapper-blind-wrapped tools/passivity-check.sh 'for (k = j + 1; k <= nw && k <= j + 12; k++) {' 'for (k = j + 1; k <= nw && k <= j; k++) {' docroot-launch-wrapped 'mutation docroot-launch-wrapped: GREEN (BLIND!)'
  metaprobe docroot-launch-python-option-blind tools/passivity-check.sh 'for (m = k; m < nw; m++) if (w[m] == "-m"' 'for (m = k; m < k + 1; m++) if (w[m] == "-m"' docroot-launch-python-option 'mutation docroot-launch-python-option: GREEN (BLIND!)'
  metaprobe docroot-launch-path-blind tools/passivity-check.sh 'sub(/^.*\//, "", b); return b }   # the name of a word' 'sub(/^.*\//, "", b); if (0) return b; return x }   # the name of a word' docroot-launch-path-wrapper 'mutation docroot-launch-path-wrapper: GREEN (BLIND!)'
  metaprobe docroot-launch-word-blind tools/passivity-check.sh 'if (b !~ /^(\/?[A-Za-z0-9_.+-]+\/)*[A-Za-z0-9_.+-]+$/) return ""; ' '' docroot-ok-awk-pattern 'mutation docroot-ok-awk-pattern: WRONG-ROW'
  metaprobe docroot-launch-command-v-blind tools/passivity-check.sh 'if (b == "command" && w[j + 1] ~ /^-[vV]$/) continue' 'if (0) continue' docroot-ok-command-v 'mutation docroot-ok-command-v: WRONG-ROW'
  # (retargeted, round 3: the per-command test on the same line reads a launch with no option too; both are blinded together; the name stays)
  metaprobe docroot-found-blind tools/passivity-check.sh 'if (hit && !found) bad = 1; if (srv && t0 ~ LAUNCH && launch(c0, 1)) { hit = 1; bad = 1 }' '' docroot-launch-bare 'mutation docroot-launch-bare: GREEN (BLIND!)'
  metaprobe docroot-every-argument-blind tools/passivity-check.sh 'if (!srv && index(arg, "STARCHORUS_DIR") == 0) continue' 'if (index(arg, "STARCHORUS_DIR") == 0) continue' docroot-two-docroots 'mutation docroot-two-docroots: GREEN (BLIND!)'
  metaprobe docroot-message-blind tools/passivity-check.sh 'srv = (!ismsg(t) && t ~' 'srv = (t ~' docroot-ok-message 'mutation docroot-ok-message: WRONG-ROW'
  metaprobe docroot-message-subst-blind tools/passivity-check.sh '|| t ~ /`/ || t ~ /\$\(/) return 0' ') return 0' docroot-echo-subst 'mutation docroot-echo-subst: GREEN (BLIND!)'
  metaprobe docroot-message-separator-blind tools/passivity-check.sh 'return (b !~ /[;|]/ && b !~ /(^|[^<>])&/)' 'return 1' docroot-echo-then 'mutation docroot-echo-then: GREEN (BLIND!)'
  metaprobe docroot-message-background-blind tools/passivity-check.sh 'return (b !~ /[;|]/ && b !~ /(^|[^<>])&/)' 'return (b !~ /[;|]/)' docroot-echo-background 'mutation docroot-echo-background: GREEN (BLIND!)'
  # (f) round 2 of the review (24 October 2026): the abbreviated verbs of ip and tc, the commands of iw that read, the programs and verbs added to the row 6g, the action of a trap and the awk command pipes, the shells and interpreters that read their program from the standard input or a file, the docroot row. Every new rule is blinded once
  # (retargeted, round 3: `out-ip-abbrev-ls` and `-lise` plant "$zz_if", which the expansion rule reads before a verb that reads, so the prefix is proven on their literal twins; the names stay)
  metaprobe out-prefix-blind-ls tools/passivity-check.sh 'if (index(v[i], w) == 1) return 1' 'if (0) return 1' out-ip-abbrev-ls-literal 'mutation out-ip-abbrev-ls-literal: GREEN (BLIND!)'
  metaprobe out-prefix-blind-lise tools/passivity-check.sh 'if (index(v[i], w) == 1) return 1' 'if (0) return 1' out-ip-abbrev-lise-literal 'mutation out-ip-abbrev-lise-literal: GREEN (BLIND!)'
  metaprobe out-prefix-blind-aa tools/passivity-check.sh 'if (index(v[i], w) == 1) return 1' 'if (0) return 1' out-ip-abbrev-aa 'mutation out-ip-abbrev-aa: GREEN (BLIND!)'
  metaprobe out-prefix-blind-rd tools/passivity-check.sh 'if (index(v[i], w) == 1) return 1' 'if (0) return 1' out-ip-abbrev-rd 'mutation out-ip-abbrev-rd: GREEN (BLIND!)'
  metaprobe out-prefix-blind-fl tools/passivity-check.sh 'if (index(v[i], w) == 1) return 1' 'if (0) return 1' out-ip-abbrev-fl 'mutation out-ip-abbrev-fl: GREEN (BLIND!)'
  metaprobe out-prefix-blind-tc tools/passivity-check.sh 'if (index(v[i], w) == 1) return 1' 'if (0) return 1' out-tc-abbrev 'mutation out-tc-abbrev: GREEN (BLIND!)'
  metaprobe out-prefix-noun-blind tools/passivity-check.sh '(dcmd == "tc" && (a ~ TCNRE || pfx(a, TCNL)))' '(dcmd == "tc" && (a ~ TCNRE))' out-tc-abbrev-noun 'mutation out-tc-abbrev-noun: GREEN (BLIND!)'
  metaprobe out-prefix-verb-blind tools/passivity-check.sh '(dcmd != "iw" && pfx(a, CHGL))' '(0)' out-ip-abbrev-addr-de 'mutation out-ip-abbrev-addr-de: GREEN (BLIND!)'
  metaprobe out-batch-abbrev-blind tools/passivity-check.sh '(dcmd == "ip" && (a ~ /^--(b|ba|bat|batc|batch)$/ || a ~ /^-(ba|bat|batc)$/))' '(0)' out-ip-batch-abbrev 'mutation out-ip-batch-abbrev: GREEN (BLIND!)'
  metaprobe out-batch-long-blind tools/passivity-check.sh 'a ~ /^--(b|ba|bat|batc|batch)$/ ||' 'a ~ /^--zz_never$/ ||' out-ip-batch-long 'mutation out-ip-batch-long: GREEN (BLIND!)'
  metaprobe out-restore-blind tools/passivity-check.sh '|exec|restore' '|exec' out-ip-restore 'mutation out-ip-restore: GREEN (BLIND!)'
  metaprobe out-iw-default-blind tools/passivity-check.sh 'iws = 9; REC[++nrec] = "chg:iw"' 'iws = 9' out-iw-switch 'mutation out-iw-switch: GREEN (BLIND!)'
  metaprobe out-iw-default-blind-vendor tools/passivity-check.sh 'iws = 9; REC[++nrec] = "chg:iw"' 'iws = 9' out-iw-vendor 'mutation out-iw-vendor: GREEN (BLIND!)'
  metaprobe out-iw-default-blind-offchannel tools/passivity-check.sh 'iws = 9; REC[++nrec] = "chg:iw"' 'iws = 9' out-iw-offchannel 'mutation out-iw-offchannel: GREEN (BLIND!)'
  metaprobe out-iw-name-blind tools/passivity-check.sh 'if (iws == 1) { iws = 2; return }' 'if (iws == 1) { iws = 3; return }' out-iw-switch 'mutation out-iw-switch: GREEN (BLIND!)'
  metaprobe out-iw-expansion-blind tools/passivity-check.sh 'iws = 9; REC[++nrec] = "chg:iw"' 'iws = 9' out-limit-verb-expansion 'mutation out-limit-verb-expansion: GREEN (BLIND!)'
  metaprobe out-iw-sub-blind-reg-reload tools/passivity-check.sh 'if (a !~ iwsub) REC[++nrec] = "chg:iw"' 'if (0) REC[++nrec] = "chg:iw"' out-iw-reg-reload 'mutation out-iw-reg-reload: GREEN (BLIND!)'
  metaprobe out-iw-sub-blind-station-new tools/passivity-check.sh 'if (a !~ iwsub) REC[++nrec] = "chg:iw"' 'if (0) REC[++nrec] = "chg:iw"' out-iw-station-new 'mutation out-iw-station-new: GREEN (BLIND!)'
  metaprobe out-iw-sub-blind-wowlan tools/passivity-check.sh 'if (a !~ iwsub) REC[++nrec] = "chg:iw"' 'if (0) REC[++nrec] = "chg:iw"' out-iw-wowlan 'mutation out-iw-wowlan: GREEN (BLIND!)'
  metaprobe out-iw-sub-blind-mpath-new tools/passivity-check.sh 'if (a !~ iwsub) REC[++nrec] = "chg:iw"' 'if (0) REC[++nrec] = "chg:iw"' out-iw-mpath-new 'mutation out-iw-mpath-new: GREEN (BLIND!)'
  metaprobe out-iw-sub-blind-survey-other tools/passivity-check.sh 'if (a !~ iwsub) REC[++nrec] = "chg:iw"' 'if (0) REC[++nrec] = "chg:iw"' out-iw-survey-other 'mutation out-iw-survey-other: GREEN (BLIND!)'
  metaprobe out-iw-reg-blind tools/passivity-check.sh 'if (a == "reg") { iws = 4; iwsub = "^get$"; return }' 'if (0) { iws = 4; iwsub = "^get$"; return }' out-ok-iw-reads 'mutation out-ok-iw-reads: WRONG-ROW'
  metaprobe out-iw-survey-blind tools/passivity-check.sh 'if (a ~ /^(survey|station|mpath|mpp)$/) { iws = 4; iwsub = "^(dump|get)$"; return }' 'if (0) { iws = 4; iwsub = "^(dump|get)$"; return }' out-ok-iw-reads 'mutation out-ok-iw-reads: WRONG-ROW'
  metaprobe out-iw-wowlan-blind tools/passivity-check.sh 'if (a ~ /^(wowlan|coalesce)$/) { iws = 4; iwsub = "^show$"; return }' 'if (0) { iws = 4; iwsub = "^show$"; return }' out-ok-iw-more 'mutation out-ok-iw-more: WRONG-ROW'
  metaprobe out-iw-readlist-blind tools/passivity-check.sh 'if (a ~ /^(info|link|scan|event|features|commands|help|version|list|channels|get)$/) { iws = 3; return }' 'if (0) { iws = 3; return }' out-ok-iw-more 'mutation out-ok-iw-more: WRONG-ROW'
  metaprobe out-iw-selector-blind tools/passivity-check.sh 'if (iws == 0 && a ~ /^(dev|phy|wiphy|wdev)$/) { iws = 1; return }' 'if (0) { iws = 1; return }' out-ok-iw-reads 'mutation out-ok-iw-reads: WRONG-ROW'
  metaprobe out-iw-options-blind tools/passivity-check.sh 'if (iws == 0 && a ~ /^-/) return' 'if (0) return' out-ok-iw-options 'mutation out-ok-iw-options: WRONG-ROW'
  metaprobe out-iw-done-blind tools/passivity-check.sh 'if (iws == 3 || iws == 9) return' 'if (0) return' out-ok-iw-more 'mutation out-ok-iw-more: WRONG-ROW'
  metaprobe out-date-s-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*s/ || a ~ /^--s(e(t)?)?(=|$)/' 'if (a ~ /^zz_never/ || a ~ /^--s(e(t)?)?(=|$)/' out-date-set 'mutation out-date-set: GREEN (BLIND!)'
  metaprobe out-date-s-cluster-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*s/ || a ~ /^--s(e(t)?)?(=|$)/' 'if (a ~ /^-s/ || a ~ /^--s(e(t)?)?(=|$)/' out-date-set-cluster 'mutation out-date-set-cluster: GREEN (BLIND!)'
  metaprobe out-date-long-blind tools/passivity-check.sh '|| a ~ /^--s(e(t)?)?(=|$)/ ||' '||' out-date-set-long 'mutation out-date-set-long: GREEN (BLIND!)'
  metaprobe out-date-digits-blind tools/passivity-check.sh '|| a ~ /^[0-9]/ ||' '||' out-date-digits 'mutation out-date-digits: GREEN (BLIND!)'
  metaprobe out-date-expansion-blind tools/passivity-check.sh '|| (a ~ /\$/ && a !~ /^\$[@*]$/)) REC[++nrec] = "chg:date"' ') REC[++nrec] = "chg:date"' out-date-expansion 'mutation out-date-expansion: GREEN (BLIND!)'
  metaprobe out-date-passthrough-blind tools/passivity-check.sh '(a ~ /\$/ && a !~ /^\$[@*]$/)' '(a ~ /\$/)' out-ok-clock-reads 'mutation out-ok-clock-reads: WRONG-ROW'
  metaprobe out-date-arg-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*[drfD]$/ || a ~ /^--(date|reference|file)$/) { dato = 1; return }' 'if (0) { dato = 1; return }' out-ok-clock-reads 'mutation out-ok-clock-reads: WRONG-ROW'
  metaprobe out-logger-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*n/ || a ~ /^--server/) REC[++nrec] = "chg:logger"' 'if (a ~ /^--server/) REC[++nrec] = "chg:logger"' out-logger-remote 'mutation out-logger-remote: GREEN (BLIND!)'
  metaprobe out-logger-server-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*n/ || a ~ /^--server/) REC[++nrec] = "chg:logger"' 'if (a ~ /^-[A-Za-z]*n/) REC[++nrec] = "chg:logger"' out-logger-server 'mutation out-logger-server: GREEN (BLIND!)'
  metaprobe out-logread-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*r$/ || a ~ /^--remote/) REC[++nrec] = "chg:logread"' 'if (0) REC[++nrec] = "chg:logread"' out-logread-remote 'mutation out-logread-remote: GREEN (BLIND!)'
  metaprobe out-iwinfo-blind tools/passivity-check.sh 'if (a == "scan") REC[++nrec] = "chg:iwinfo"' 'if (0) REC[++nrec] = "chg:iwinfo"' out-iwinfo-scan 'mutation out-iwinfo-scan: GREEN (BLIND!)'
  metaprobe sink-awk-file-blind tools/passivity-check.sh 'if (a ~ /^-f/ || a ~ /^--file/) REC[++nrec] = "snk:awk-file"' 'if (a ~ /^--file/) REC[++nrec] = "snk:awk-file"' sink-awk-file 'mutation sink-awk-file: GREEN (BLIND!)'
  metaprobe sink-awk-file-long-blind tools/passivity-check.sh 'if (a ~ /^-f/ || a ~ /^--file/) REC[++nrec] = "snk:awk-file"' 'if (a ~ /^-f/) REC[++nrec] = "snk:awk-file"' sink-awk-file-long 'mutation sink-awk-file-long: GREEN (BLIND!)'
  metaprobe out-trap-read-blind tools/passivity-check.sh '&& ++trn == 1) tact(dtok)' '&& ++trn == 99) tact(dtok)' out-trap-double 'mutation out-trap-double: GREEN (BLIND!)'
  metaprobe out-trap-main-blind tools/passivity-check.sh 'BT_TRAPS="$tmp/tr1" BT_TLEV=0 awk' 'BT_TRAPS=/dev/null BT_TLEV=0 awk' out-trap-double 'mutation out-trap-double: GREEN (BLIND!)'
  metaprobe out-trap-script-blind tools/passivity-check.sh 'BT_TRAPS="$tmp/tr2" BT_TLEV=s awk' 'BT_TRAPS=/dev/null BT_TLEV=s awk' out-trap-script-handler 'mutation out-trap-script-handler: GREEN (BLIND!)'
  metaprobe out-trap-levels-blind tools/passivity-check.sh 'cat "$tmp/tr1" "$tmp/tr2" > "$tmp/tin"; _lv=1' ': > "$tmp/tin"; _lv=1' out-trap-double 'mutation out-trap-double: GREEN (BLIND!)'
  metaprobe out-trap-nested-blind tools/passivity-check.sh 'BT_TRAPS="$tmp/tout" BT_TLEV=$_lv awk' 'BT_TRAPS=/dev/null BT_TLEV=$_lv awk' out-trap-nested 'mutation out-trap-nested: GREEN (BLIND!)'
  metaprobe out-trap-name-blind tools/passivity-check.sh 'if (w ~ /^[A-Za-z_][A-Za-z0-9_]*$/) { tline(w); return }' 'if (0) { tline(w); return }' out-trap-name 'mutation out-trap-name: GREEN (BLIND!)'
  metaprobe out-trap-single-blind tools/passivity-check.sh 'if (w ~ /^\047[^\047]*\047$/ && !dmulti) { tline(substr(w, 2, length(w) - 2)); return }' 'if (0) { tline(substr(w, 2, length(w) - 2)); return }' out-limit-trap-string 'mutation out-limit-trap-string: GREEN (BLIND!)'
  metaprobe out-trap-double-blind tools/passivity-check.sh 'if (w ~ /^"([^"\\]|\\.)*"$/ && !dmulti) {' 'if (0) {' out-trap-double 'mutation out-trap-double: GREEN (BLIND!)'
  metaprobe out-trap-unescape-blind tools/passivity-check.sh 'if (c == "\\" && substr(v, i + 1, 1) ~ /["$`\\]/) { i++; c = substr(v, i, 1) }' 'if (0) { i++; c = substr(v, i, 1) }' sink-trap-escaped 'mutation sink-trap-escaped: GREEN (BLIND!)'
  metaprobe out-trap-multiline-blind tools/passivity-check.sh '&& !dmulti) { tline(substr(w, 2, length(w) - 2)); return }' ') { tline(substr(w, 2, length(w) - 2)); return }' sink-trap-multiline 'mutation sink-trap-multiline: GREEN (BLIND!)'
  metaprobe out-trap-multiline-set-blind tools/passivity-check.sh 'if ((top == "q" || top == "d") && dint) dmulti = 1' 'if (0) dmulti = 1' sink-trap-multiline 'mutation sink-trap-multiline: GREEN (BLIND!)'
  metaprobe out-trap-fallback-blind tools/passivity-check.sh 'REC[++nrec] = "snk:trap"' 'nrec = nrec' sink-trap-option 'mutation sink-trap-option: GREEN (BLIND!)'
  metaprobe out-trap-fallback-blind-glued tools/passivity-check.sh 'REC[++nrec] = "snk:trap"' 'nrec = nrec' sink-trap-glued 'mutation sink-trap-glued: GREEN (BLIND!)'
  metaprobe out-trap-depth-blind tools/passivity-check.sh '[ "$_lv" -le 3 ]; do' '[ "$_lv" -le 2 ]; do' out-trap-three 'mutation out-trap-three: GREEN (BLIND!)'
  metaprobe out-trap-deep-record-blind tools/passivity-check.sh '[ ! -s "$tmp/tin" ] || awk "$UNMARK" "$tmp/tin"' 'true || awk "$UNMARK" "$tmp/tin"' sink-trap-deep 'mutation sink-trap-deep: GREEN (BLIND!)'
  metaprobe sink-getline-blind tools/passivity-check.sh 'scoped_n '"'"'\|&?[[:space:]]*getline'"'"'' ':' sink-awk-getline-var 'mutation sink-awk-getline-var: GREEN (BLIND!)'
  metaprobe sink-getline-coproc-blind tools/passivity-check.sh 'scoped_n '"'"'\|&?[[:space:]]*getline'"'"'' 'scoped_n '"'"'\|[[:space:]]*getline'"'"'' sink-awk-getline-coproc 'mutation sink-awk-getline-coproc: GREEN (BLIND!)'
  metaprobe sink-print-pipe-blind tools/passivity-check.sh 'scoped '"'"'(^|[^A-Za-z0-9_])print[^|]*[^|]\|&?[[:space:]]*"[^$]'"'"'' ':' sink-awk-print-pipe 'mutation sink-awk-print-pipe: GREEN (BLIND!)'
  metaprobe sink-print-dollar-blind tools/passivity-check.sh '[[:space:]]*"[^$]'"'"'' '[[:space:]]*"'"'"'' sink-ok-comment 'mutation sink-ok-comment: WRONG-ROW'
  metaprobe sink-interp-stdin-blind tools/passivity-check.sh 'if (n ~ /^(python[0-9.]*|perl|lua|ruby|php|node)$/) nsh[r]++' 'if (0) nsh[r]++' sink-interp-stdin 'mutation sink-interp-stdin: GREEN (BLIND!)'
  metaprobe sink-interp-stdin-blind-perl tools/passivity-check.sh 'if (n ~ /^(python[0-9.]*|perl|lua|ruby|php|node)$/) nsh[r]++' 'if (0) nsh[r]++' sink-interp-perl-stdin 'mutation sink-interp-perl-stdin: GREEN (BLIND!)'
  metaprobe sink-run-file-interp-blind tools/passivity-check.sh '{ REC[++nrec] = "snk:shell-file"; REC[++nrec] = "snk:run-file" }' '{ REC[++nrec] = "snk:shell-file" }' sink-run-file-python 'mutation sink-run-file-python: GREEN (BLIND!)'
  metaprobe sink-run-file-interp-blind-perl tools/passivity-check.sh '{ REC[++nrec] = "snk:shell-file"; REC[++nrec] = "snk:run-file" }' '{ REC[++nrec] = "snk:shell-file" }' sink-run-file-perl 'mutation sink-run-file-perl: GREEN (BLIND!)'
  metaprobe sink-run-file-blind tools/passivity-check.sh 'a != "$0" && ++shrun == 1) REC[++nrec] = "snk:run-file"' '0 && ++shrun == 1) REC[++nrec] = "snk:run-file"' sink-ok-comment 'mutation sink-ok-comment: WRONG-ROW'
  metaprobe sink-run-file-self-blind tools/passivity-check.sh 'a !~ /^-/ && a != "$0" && ++shrun' 'a !~ /^-/ && ++shrun' sink-ok-shell-self 'mutation sink-ok-shell-self: WRONG-ROW'
  metaprobe sink-shell-s-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*s/) { shs = 1; return 0 }' 'if (0) { shs = 1; return 0 }' sink-sh-s-self 'mutation sink-sh-s-self: GREEN (BLIND!)'
  metaprobe sink-shell-s-operand-blind tools/passivity-check.sh 'if (a !~ /^-/ && shs) return 1' 'if (0) return 1' sink-sh-s-self 'mutation sink-sh-s-self: GREEN (BLIND!)'
  metaprobe sink-shell-o-blind tools/passivity-check.sh 'if (a ~ /^[-+][A-Za-z]*[oO]$/ ||' 'if (a ~ /^zz_never$/ ||' sink-sh-o-self 'mutation sink-sh-o-self: GREEN (BLIND!)'
  metaprobe sink-shell-big-o-blind tools/passivity-check.sh 'if (a ~ /^[-+][A-Za-z]*[oO]$/ ||' 'if (a ~ /^[-+][A-Za-z]*o$/ ||' sink-sh-big-o-self 'mutation sink-sh-big-o-self: GREEN (BLIND!)'
  metaprobe sink-shell-rcfile-blind tools/passivity-check.sh '|| a ~ /^--(rcfile|init-file)$/) { sho = 1; return 1 }' ') { sho = 1; return 1 }' sink-sh-rcfile-self 'mutation sink-sh-rcfile-self: GREEN (BLIND!)'
  metaprobe sink-shell-plus-blind tools/passivity-check.sh 'if (a ~ /^\+/) return 1' 'if (0) return 1' sink-ok-shell-plus 'mutation sink-ok-shell-plus: WRONG-ROW'
  metaprobe sink-shell-twice-blind tools/passivity-check.sh 'print (++occ[k] > 1 ? k "#" occ[k] : k) "\t" $0 > NMS' 'print k "\t" $0 > NMS' sink-sh-two-on-a-line 'mutation sink-sh-two-on-a-line: GREEN (BLIND!)'
  metaprobe sink-shell-twice-blind-control tools/passivity-check.sh 'print (++occ[k] > 1 ? k "#" occ[k] : k) "\t" $0 > NMS' 'print k "\t" $0 > NMS' sink-ok-shell-twice 'mutation sink-ok-shell-twice: WRONG-ROW'
  metaprobe sink-shell-twice-strip-blind tools/passivity-check.sh 'sub(/#[0-9]+$/, "", $1); print' 'print' sink-ok-shell-twice 'mutation sink-ok-shell-twice: WRONG-ROW'
  metaprobe sink-interp-flags-blind tools/passivity-check.sh 'if (a ~ /^--(version|help)$/ || a ~ /^-[VhvH?]$/)' 'if (0)' sink-ok-interp-flags 'mutation sink-ok-interp-flags: WRONG-ROW'
  metaprobe sink-interp-c-versioned-blind tools/passivity-check.sh 'if (dcmd ~ /^python[0-9]*\.[0-9.]+$/) REC[++nrec] = "snk:interp-c"' 'if (0) REC[++nrec] = "snk:interp-c"' sink-interp-c-versioned 'mutation sink-interp-c-versioned: GREEN (BLIND!)'
  metaprobe sink-interp-module-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*m$/) { ipm = 1; return }' 'if (0) { ipm = 1; return }' sink-interp-module-versioned 'mutation sink-interp-module-versioned: GREEN (BLIND!)'
  metaprobe sink-interp-module-name-blind tools/passivity-check.sh '&& dcmd ~ /^python[0-9]*\.[0-9.]+$/) REC[++nrec] = "chg:module"; return }' '&& 0) REC[++nrec] = "chg:module"; return }' sink-interp-module-versioned 'mutation sink-interp-module-versioned: GREEN (BLIND!)'
  metaprobe sink-interp-module-glued-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*m[A-Za-z_.]+$/) {' 'if (0) {' sink-interp-module-glued 'mutation sink-interp-module-glued: GREEN (BLIND!)'
  # docroot-comment-blind was aimed at the third test of one() (a launch in the code of the line, a docroot option only in its comment); since the per-command test (launch(c0, 1), 24 October 2026)
  # reads the same code part and is red for every line that test is red for, it aims at what both read instead: the code of the line, c0, is the whole line again (retargeted 26 October 2026)
  metaprobe docroot-comment-blind tools/passivity-check.sh 'c0 = cutc(t)' 'c0 = t' docroot-launch-comment 'mutation docroot-launch-comment: GREEN (BLIND!)'
  metaprobe docroot-cut-blind tools/passivity-check.sh 'if (c == "#" && (i == 1 || substr(s, i - 1, 1) ~ /[ \t;&|(]/)) return substr(s, 1, i - 1)' 'if (0) return substr(s, 1, i - 1)' docroot-launch-comment 'mutation docroot-launch-comment: GREEN (BLIND!)'
  metaprobe docroot-cut-quote-blind tools/passivity-check.sh 'if (c == "\"" || c == "\047") { q = c; continue }' 'if (0) { q = c; continue }' docroot-ok-hash-quoted 'mutation docroot-ok-hash-quoted: WRONG-ROW'
  metaprobe docroot-cut-word-blind tools/passivity-check.sh '(i == 1 || substr(s, i - 1, 1) ~ /[ \t;&|(]/)' '(1)' docroot-ok-hash-in-word 'mutation docroot-ok-hash-in-word: WRONG-ROW'
  metaprobe docroot-python-cluster-blind tools/passivity-check.sh 'if (m < nw && w[m] ~ /^-[A-Za-z]+m$/ && base(w[m + 1]) == "http.server") return 1' 'if (0) return 1' docroot-python-cluster-m 'mutation docroot-python-cluster-m: GREEN (BLIND!)'
  metaprobe docroot-python-cluster-blind-um tools/passivity-check.sh 'if (m < nw && w[m] ~ /^-[A-Za-z]+m$/ && base(w[m + 1]) == "http.server") return 1' 'if (0) return 1' docroot-python-cluster-um 'mutation docroot-python-cluster-um: GREEN (BLIND!)'
  metaprobe docroot-python-simple-blind tools/passivity-check.sh 'if (m < nw && w[m] ~ /^-[A-Za-z]*m$/ && base(w[m + 1]) == "SimpleHTTPServer") return 1' 'if (0) return 1' docroot-python-cluster-simple 'mutation docroot-python-cluster-simple: GREEN (BLIND!)'
  metaprobe docroot-python-simple-blind-py2 tools/passivity-check.sh 'if (m < nw && w[m] ~ /^-[A-Za-z]*m$/ && base(w[m + 1]) == "SimpleHTTPServer") return 1' 'if (0) return 1' docroot-python2-simple 'mutation docroot-python2-simple: GREEN (BLIND!)'
  metaprobe docroot-python-glued-blind tools/passivity-check.sh 'if (w[m] ~ /^-[A-Za-z]*m(http\.server|SimpleHTTPServer)$/) return 1' 'if (0) return 1' docroot-python-glued-simple 'mutation docroot-python-glued-simple: GREEN (BLIND!)'
  metaprobe docroot-equals-blind-only tools/passivity-check.sh '([ \t]+|=))" }' '([ \t]+))" }' docroot-python-eq-nolaunch 'mutation docroot-python-eq-nolaunch: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-flock tools/passivity-check.sh '|builtin|flock|ionice|' '|builtin|ionice|' docroot-launch-flock 'mutation docroot-launch-flock: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-ionice tools/passivity-check.sh '|flock|ionice|chrt|' '|flock|chrt|' docroot-launch-ionice 'mutation docroot-launch-ionice: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-chrt tools/passivity-check.sh '|flock|ionice|chrt|taskset|chroot|' '|flock|ionice|taskset|chroot|' docroot-launch-chrt 'mutation docroot-launch-chrt: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-taskset tools/passivity-check.sh '|chrt|taskset|chroot|' '|chrt|chroot|' docroot-launch-taskset 'mutation docroot-launch-taskset: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-chroot tools/passivity-check.sh '|taskset|chroot|start-stop-daemon|' '|taskset|start-stop-daemon|' docroot-launch-chroot 'mutation docroot-launch-chroot: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-start-stop-daemon tools/passivity-check.sh '|chroot|start-stop-daemon|setpriv|' '|chroot|setpriv|' docroot-launch-start-stop-daemon 'mutation docroot-launch-start-stop-daemon: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-setpriv tools/passivity-check.sh '|start-stop-daemon|setpriv|unshare|' '|start-stop-daemon|unshare|' docroot-launch-setpriv 'mutation docroot-launch-setpriv: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-unshare tools/passivity-check.sh '|setpriv|unshare|nsenter|' '|setpriv|nsenter|' docroot-launch-unshare 'mutation docroot-launch-unshare: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-nsenter tools/passivity-check.sh '|unshare|nsenter|watch|' '|unshare|watch|' docroot-launch-nsenter 'mutation docroot-launch-nsenter: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-watch tools/passivity-check.sh '|nsenter|watch|doas|' '|nsenter|doas|' docroot-launch-watch 'mutation docroot-launch-watch: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-doas tools/passivity-check.sh '|watch|doas|su|' '|watch|su|' docroot-launch-doas 'mutation docroot-launch-doas: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-su tools/passivity-check.sh '|watch|doas|su|runuser|strace|' '|watch|doas|runuser|strace|' docroot-launch-su 'mutation docroot-launch-su: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-runuser tools/passivity-check.sh '|su|runuser|strace|' '|su|strace|' docroot-launch-runuser 'mutation docroot-launch-runuser: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-strace tools/passivity-check.sh '|runuser|strace|ltrace|' '|runuser|ltrace|' docroot-launch-strace 'mutation docroot-launch-strace: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-ltrace tools/passivity-check.sh '|strace|ltrace|script|' '|strace|script|' docroot-launch-ltrace 'mutation docroot-launch-ltrace: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-script tools/passivity-check.sh '|ltrace|script|cpulimit)' '|ltrace|cpulimit)' docroot-launch-script 'mutation docroot-launch-script: GREEN (BLIND!)'
  metaprobe docroot-wrapper-blind-cpulimit tools/passivity-check.sh '|script|cpulimit)' '|script)' docroot-launch-cpulimit 'mutation docroot-launch-cpulimit: GREEN (BLIND!)'
  # the third round: the docroot option per simple command (blinded, the line-wide `found` decides again), the brace keywords, the backtick as a separator, the descriptor copy that ends no command
  metaprobe docroot-per-command-blind tools/passivity-check.sh 'launch(c0, 1)) { hit = 1; bad = 1 }' 'launch(c0, 1)) { hit = 1 }' docroot-launch-second-amp 'mutation docroot-launch-second-amp: GREEN (BLIND!)'
  metaprobe docroot-per-command-blind-python tools/passivity-check.sh 'launch(c0, 1)) { hit = 1; bad = 1 }' 'launch(c0, 1)) { hit = 1 }' docroot-launch-second-python 'mutation docroot-launch-second-python: GREEN (BLIND!)'
  metaprobe docroot-per-command-blind-subshell tools/passivity-check.sh 'launch(c0, 1)) { hit = 1; bad = 1 }' 'launch(c0, 1)) { hit = 1 }' docroot-launch-second-subshell 'mutation docroot-launch-second-subshell: GREEN (BLIND!)'
  metaprobe docroot-per-command-own-blind tools/passivity-check.sh 'if (match(v, RE2)) continue }' 'if (0) continue }' docroot-ok-www 'mutation docroot-ok-www: WRONG-ROW'
  metaprobe docroot-brace-blind tools/passivity-check.sh 'w[j] ~ /^(then|do|else|elif|if|while|until|!|\{|\})$/' 'w[j] ~ /^(then|do|else|elif|if|while|until|!)$/' docroot-launch-brace 'mutation docroot-launch-brace: GREEN (BLIND!)'
  metaprobe docroot-backtick-blind tools/passivity-check.sh 'ns = split(u, seg, /[;&|()`]/)' 'ns = split(u, seg, /[;&|()]/)' docroot-launch-backtick 'mutation docroot-launch-backtick: GREEN (BLIND!)'
  metaprobe docroot-quoted-option-blind tools/passivity-check.sh 'gsub(/\047[^\047]*\047/, "Q", v); ' '' docroot-launch-quoted-option 'mutation docroot-launch-quoted-option: GREEN (BLIND!)'
  metaprobe docroot-descriptor-blind tools/passivity-check.sh 'gsub(/[<>]&/, ">_", u); ' '' docroot-ok-redirect-before 'mutation docroot-ok-redirect-before: WRONG-ROW'
  # the third round on the rows 6g and 6h: each new reading blinded once (and the read verbs and exemptions blinded against their controls)
  metaprobe out-verb-expansion-ip-blind tools/passivity-check.sh 'else if (a ~ /\$/) REC[++nrec] = "chg:" dcmd }' 'else if (0) REC[++nrec] = "chg:" dcmd }' out-verb-expansion-ip 'mutation out-verb-expansion-ip: GREEN (BLIND!)'
  metaprobe out-verb-expansion-tc-blind tools/passivity-check.sh 'else if (a ~ /\$/) REC[++nrec] = "chg:" dcmd }' 'else if (0) REC[++nrec] = "chg:" dcmd }' out-verb-expansion-tc 'mutation out-verb-expansion-tc: GREEN (BLIND!)'
  metaprobe out-verb-expansion-reads-blind tools/passivity-check.sh 'if (a ~ /^(show|list|lst|ls|get|help|monitor)$/) ipr = 1; else if (a ~ /\$/)' 'if (a ~ /\$/)' out-ok-expansion-reads 'mutation out-ok-expansion-reads: WRONG-ROW'
  metaprobe out-route-expansion-blind tools/passivity-check.sh 'if (dcmd == "route" && a ~ /\$/)' 'if (0)' out-verb-expansion-route 'mutation out-verb-expansion-route: GREEN (BLIND!)'
  metaprobe out-arp-expansion-blind tools/passivity-check.sh 'else if (a ~ /\$/) REC[++nrec] = "chg:arp" }' 'else if (0) REC[++nrec] = "chg:arp" }' out-verb-expansion-arp 'mutation out-verb-expansion-arp: GREEN (BLIND!)'
  metaprobe out-iwinfo-expansion-blind tools/passivity-check.sh 'if (a ~ /\$/ && (ifc >= 2 || dtok' 'if (0 && (ifc >= 2 || dtok' out-verb-expansion-iwinfo 'mutation out-verb-expansion-iwinfo: GREEN (BLIND!)'
  metaprobe out-iwinfo-split-blind tools/passivity-check.sh '(ifc >= 2 || dtok !~ /^"[^"]*"$/))' '(ifc >= 2))' out-verb-expansion-iwinfo-split 'mutation out-verb-expansion-iwinfo-split: GREEN (BLIND!)'
  metaprobe out-iwinfo-device-blind tools/passivity-check.sh '(ifc >= 2 || dtok !~ /^"[^"]*"$/))' '(1))' out-ok-expansion-reads 'mutation out-ok-expansion-reads: WRONG-ROW'
  metaprobe out-logger-expansion-blind tools/passivity-check.sh 'else if (a ~ /\$/ && a !~ /^-[tp]./) REC[++nrec] = "chg:logger" }' 'else if (0) REC[++nrec] = "chg:logger" }' out-verb-expansion-logger 'mutation out-verb-expansion-logger: GREEN (BLIND!)'
  metaprobe out-logger-message-blind tools/passivity-check.sh 'else if (a ~ /\$/ && a !~ /^-[tp]./) REC[++nrec] = "chg:logger" }' 'else if (0) REC[++nrec] = "chg:logger" }' out-verb-expansion-logger-message 'mutation out-verb-expansion-logger-message: GREEN (BLIND!)'
  metaprobe out-logger-dashdash-blind tools/passivity-check.sh 'else if (a == "--") ipr = 1; ' '' out-ok-expansion-reads 'mutation out-ok-expansion-reads: WRONG-ROW'
  metaprobe out-logread-expansion-blind tools/passivity-check.sh 'else if (a ~ /\$/ && a !~ /^-[le]./) REC[++nrec] = "chg:logread" }' 'else if (0) REC[++nrec] = "chg:logread" }' out-verb-expansion-logread 'mutation out-verb-expansion-logread: GREEN (BLIND!)'
  metaprobe out-ip-applet-blind tools/passivity-check.sh 'if (dcmd ~ /^ip(link|addr|route|rule|neigh|tunnel)$/) dcmd = "ip"' 'if (0) dcmd = "ip"' out-ip-applet-link 'mutation out-ip-applet-link: GREEN (BLIND!)'
  metaprobe out-ip-applet-tunnel-blind tools/passivity-check.sh '/^ip(link|addr|route|rule|neigh|tunnel)$/' '/^ip(link|addr|route|rule|neigh)$/' out-ip-applet-tunnel 'mutation out-ip-applet-tunnel: GREEN (BLIND!)'
  metaprobe out-runner-chpst-blind tools/passivity-check.sh '|cpulimit|chpst|setuidgid|' '|cpulimit|setuidgid|' out-runner-chpst 'mutation out-runner-chpst: GREEN (BLIND!)'
  metaprobe out-runner-softlimit-blind tools/passivity-check.sh '|envdir|softlimit)$/' '|envdir)$/' out-runner-softlimit 'mutation out-runner-softlimit: GREEN (BLIND!)'
  metaprobe out-builtin-blind tools/passivity-check.sh 'if (bn == "builtin") bn = "nohup"' 'if (0) bn = "nohup"' out-builtin 'mutation out-builtin: GREEN (BLIND!)'
  metaprobe sink-watch-blind tools/passivity-check.sh 'if (n ~ /^(watch|run-parts)$/) hit[r] = 1' 'if (n ~ /^(run-parts)$/) hit[r] = 1' sink-watch 'mutation sink-watch: GREEN (BLIND!)'
  metaprobe sink-run-parts-blind tools/passivity-check.sh 'if (n ~ /^(watch|run-parts)$/) hit[r] = 1' 'if (n ~ /^(watch)$/) hit[r] = 1' sink-run-parts 'mutation sink-run-parts: GREEN (BLIND!)'
  metaprobe sink-flock-c-blind tools/passivity-check.sh '(dcmd == "flock" && a ~ /^-[A-Za-z]*c/) ||' '(0) ||' sink-flock-c 'mutation sink-flock-c: GREEN (BLIND!)'
  metaprobe sink-command-long-blind tools/passivity-check.sh 'a ~ /^--c(o(m(m(a(n(d)?)?)?)?)?)?(=|$)/ || ' '' sink-su-command-eq 'mutation sink-su-command-eq: GREEN (BLIND!)'
  metaprobe sink-command-session-blind tools/passivity-check.sh ' || a ~ /^--session-command/)' ')' sink-su-session-command 'mutation sink-su-session-command: GREEN (BLIND!)'
  metaprobe sink-glued-c-blind tools/passivity-check.sh '(dcmd ~ /^(su|runuser|script)$/ && a ~ /^-[A-Za-z]*c./) ||' '(0) ||' sink-runuser-c-glued 'mutation sink-runuser-c-glued: GREEN (BLIND!)'
  metaprobe sink-runner-chpst-blind tools/passivity-check.sh '|cpulimit|chpst|setuidgid|' '|cpulimit|setuidgid|' sink-wrapped-chpst-sh 'mutation sink-wrapped-chpst-sh: GREEN (BLIND!)'
  metaprobe out-route-blind tools/passivity-check.sh 'if (dcmd == "route") { if (a ~ VRBRE) REC[++nrec] = "chg:route"; return }' 'if (dcmd == "route") { return }' out-route-add 'mutation out-route-add: GREEN (BLIND!)'
  metaprobe out-arp-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*[sdf]/) REC[++nrec] = "chg:arp"' 'if (0) REC[++nrec] = "chg:arp"' out-arp-set 'mutation out-arp-set: GREEN (BLIND!)'
  metaprobe out-arp-delete-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*[sdf]/) REC[++nrec] = "chg:arp"' 'if (a ~ /^-[A-Za-z]*[sf]/) REC[++nrec] = "chg:arp"' out-arp-del 'mutation out-arp-del: GREEN (BLIND!)'
  metaprobe out-hostname-file-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*F/ || a !~ /^-/) REC[++nrec] = "chg:hostname"' 'if (a !~ /^-/) REC[++nrec] = "chg:hostname"' out-hostname-file 'mutation out-hostname-file: GREEN (BLIND!)'
  metaprobe out-hostname-set-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*F/ || a !~ /^-/) REC[++nrec] = "chg:hostname"' 'if (a ~ /^-[A-Za-z]*F/) REC[++nrec] = "chg:hostname"' out-hostname-set 'mutation out-hostname-set: GREEN (BLIND!)'
  metaprobe out-hostname-reads-blind tools/passivity-check.sh '|| a !~ /^-/) REC[++nrec] = "chg:hostname"' '|| 1) REC[++nrec] = "chg:hostname"' out-ok-net-reads 'mutation out-ok-net-reads: WRONG-ROW'
  metaprobe sink-tcpdump-z-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*z$/ || a ~ /^--postrotate-command/)' 'if (a ~ /^zz_never$/ || a ~ /^--postrotate-command/)' sink-tcpdump-z 'mutation sink-tcpdump-z: GREEN (BLIND!)'
  metaprobe sink-tcpdump-z-cluster-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*z$/ || a ~ /^--postrotate-command/)' 'if (a ~ /^-z$/ || a ~ /^--postrotate-command/)' sink-tcpdump-z-cluster 'mutation sink-tcpdump-z-cluster: GREEN (BLIND!)'
  metaprobe sink-tcpdump-z-long-blind tools/passivity-check.sh '|| a ~ /^--postrotate-command/) REC[++nrec] = "snk:tcpdump-z"' ') REC[++nrec] = "snk:tcpdump-z"' sink-tcpdump-z-long 'mutation sink-tcpdump-z-long: GREEN (BLIND!)'
  metaprobe sink-tcpdump-z-case-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*z$/ || a ~ /^--postrotate-command/)' 'if (a ~ /^-[A-Za-z]*[zZ]$/ || a ~ /^--postrotate-command/)' sink-ok-tcpdump 'mutation sink-ok-tcpdump: WRONG-ROW'
  metaprobe sink-tar-action-blind tools/passivity-check.sh 'a ~ /^--(checkpoint-action|to-command|use-compress-program|rsh-command|info-script|new-volume-script)/' 'a ~ /^--(to-command|use-compress-program|rsh-command|info-script|new-volume-script)/' sink-tar-action 'mutation sink-tar-action: GREEN (BLIND!)'
  metaprobe sink-tar-to-command-blind tools/passivity-check.sh 'a ~ /^--(checkpoint-action|to-command|use-compress-program|rsh-command|info-script|new-volume-script)/' 'a ~ /^--(checkpoint-action|use-compress-program|rsh-command|info-script|new-volume-script)/' sink-tar-to-command 'mutation sink-tar-to-command: GREEN (BLIND!)'
  metaprobe sink-tar-short-blind tools/passivity-check.sh '|| a ~ /^-[A-Za-z]*[FI]$/) REC[++nrec] = "snk:tar-exec"' ') REC[++nrec] = "snk:tar-exec"' sink-tar-compress 'mutation sink-tar-compress: GREEN (BLIND!)'
  metaprobe sink-tar-reads-blind tools/passivity-check.sh '|| a ~ /^-[A-Za-z]*[FI]$/) REC[++nrec] = "snk:tar-exec"' '|| a ~ /^-[A-Za-z]*[FIf]$/) REC[++nrec] = "snk:tar-exec"' sink-ok-tar 'mutation sink-ok-tar: WRONG-ROW'
  metaprobe out-sys-sed-blind tools/passivity-check.sh 'if (a ~ /^-[A-Za-z]*i/ || a ~ /^--in-place/) sedi = 1;' 'if (a ~ /^zz_never/) sedi = 1;' out-sys-sed 'mutation out-sys-sed: GREEN (BLIND!)'
  metaprobe out-sys-sed-path-blind tools/passivity-check.sh 'else if (sedi && syspath(a)) REC[++nrec] = "sys:sed"' 'else if (sedi && 0) REC[++nrec] = "sys:sed"' out-sys-sed-suffix 'mutation out-sys-sed-suffix: GREEN (BLIND!)'
  metaprobe out-sys-sed-reads-blind tools/passivity-check.sh 'else if (sedi && syspath(a)) REC[++nrec] = "sys:sed"' 'else if (syspath(a)) REC[++nrec] = "sys:sed"' out-ok-sed-reads 'mutation out-ok-sed-reads: WRONG-ROW'
  metaprobe out-sys-truncate-blind tools/passivity-check.sh 'if (dcmd == "truncate") { if (a !~ /^-/ && syspath(a)) REC[++nrec] = "sys:truncate"; return }' 'if (dcmd == "truncate") { return }' out-sys-truncate 'mutation out-sys-truncate: GREEN (BLIND!)'
  metaprobe sink-sqlite-blind tools/passivity-check.sh 'scoped '"'"'(^|[^A-Za-z0-9_])\.(shell|system)([[:space:]]|")'"'"'' ':' sink-sqlite-shell 'mutation sink-sqlite-shell: GREEN (BLIND!)'
  metaprobe sink-sqlite-system-blind tools/passivity-check.sh '\.(shell|system)([[:space:]]|")' '\.(shell)([[:space:]]|")' sink-sqlite-system 'mutation sink-sqlite-system: GREEN (BLIND!)'
  metaprobe sink-sqlite-heredoc-blind tools/passivity-check.sh 'scoped '"'"'(^|[^A-Za-z0-9_])\.(shell|system)([[:space:]]|")'"'"'' ':' sink-sqlite-heredoc 'mutation sink-sqlite-heredoc: GREEN (BLIND!)'
  metaprobe out-noclobber-blind tools/passivity-check.sh '(c == "|" && substr(t, i - 1, 1) != ">")' 'c == "|"' out-sys-noclobber 'mutation out-sys-noclobber: WRONG-ROW'
  metaprobe sink-path-run-blind tools/passivity-check.sh 'if ($1 !~ /^(snk|chg|sys):/ && p ~ /\// && p !~' 'if ($1 !~ /^(snk|chg|sys):/ && 0 && p !~' sink-ok-comment 'mutation sink-ok-comment: WRONG-ROW'
  metaprobe sink-path-initd-blind tools/passivity-check.sh ' && p !~ /^\/etc\/(init|rc)\.d\//) hit[r] = 1' ') hit[r] = 1' out-initd 'mutation out-initd: WRONG-ROW'
  metaprobe sink-path-system-blind tools/passivity-check.sh 'p !~ /^\/(usr\/)?(local\/)?s?bin\/[^\/]+$/ &&' 'p !~ /^zz_never$/ &&' sink-ok-path-system 'mutation sink-ok-path-system: WRONG-ROW'
  # sink-wrapped-blind blinded the same rule and demanded sink-wrapped-flock-sh green; since flock -c is a sink of its own (sink-flock-c, 24 October 2026) the `-c` of that `sh` is read as flock's and the line
  # stays red, so the probe demands the wrapped shell that only this rule reads: `strace -f sh` (retargeted 26 October 2026; sink-flock-c-blind holds the other half)
  metaprobe sink-wrapped-blind tools/passivity-check.sh 'if (b ~ /^(sh|bash|ash|dash|ksh|zsh|busybox|python[0-9.]*|perl|lua|ruby|php|node|awk|gawk|mawk|nawk|find|xargs)$/) REC[++nrec] = "snk:wrapped"' 'if (0) REC[++nrec] = "snk:wrapped"' sink-wrapped-strace 'mutation sink-wrapped-strace: GREEN (BLIND!)'
  metaprobe sink-wrapped-blind-python tools/passivity-check.sh '|busybox|python[0-9.]*|perl|lua|ruby|php|node|awk|gawk|mawk|nawk|find|xargs)$/) REC[++nrec] = "snk:wrapped"' '|busybox|perl|lua|ruby|php|node|awk|gawk|mawk|nawk|find|xargs)$/) REC[++nrec] = "snk:wrapped"' sink-wrapped-chroot-python 'mutation sink-wrapped-chroot-python: GREEN (BLIND!)'
  metaprobe sink-wrapped-blind-awk tools/passivity-check.sh '|node|awk|gawk|mawk|nawk|find|xargs)$/) REC[++nrec] = "snk:wrapped"' '|node|find|xargs)$/) REC[++nrec] = "snk:wrapped"' sink-wrapped-awk 'mutation sink-wrapped-awk: GREEN (BLIND!)'
  # the third round of the review, second half (26 October 2026): `bridge` loses its verb rule, its batch option or its expansion rule, and OUT_WORDS loses one of the names it gained (a family each)
  metaprobe out-bridge-blind tools/passivity-check.sh 'dcmd == "tc" || dcmd == "bridge") { if (a ~ VRBRE' 'dcmd == "tc") { if (a ~ VRBRE' out-bridge-set 'mutation out-bridge-set: GREEN (BLIND!)'
  metaprobe out-bridge-batch-blind tools/passivity-check.sh ' || (dcmd == "bridge" && a ~ /^--?(b|ba|bat|batc|batch)$/)' '' out-bridge-batch 'mutation out-bridge-batch: GREEN (BLIND!)'
  metaprobe out-bridge-expansion-blind tools/passivity-check.sh '|| dcmd == "bridge") && !ipr)' ') && !ipr)' out-bridge-expansion 'mutation out-bridge-expansion: GREEN (BLIND!)'
  metaprobe alt-out-nameif tools/passivity-check.sh '|nameif|nbd-client' '|nbd-client' alts 'alt out nameif: GREEN (BLIND!)'
  metaprobe alt-out-mtr tools/passivity-check.sh '|mtr|fping' '|fping' alts 'alt out =mtr: GREEN (BLIND!)'
  metaprobe alt-out-avahi tools/passivity-check.sh '|avahi-publish|avahi-publish-service' '|avahi-publish-service' alts 'alt out =avahi-publish: GREEN (BLIND!)'
  metaprobe alt-out-lighttpd tools/passivity-check.sh '|lighttpd|nginx' '|nginx' alts 'alt out lighttpd: GREEN (BLIND!)'
  metaprobe out-server-lighttpd-blind tools/passivity-check.sh '|lighttpd|nginx' '|nginx' out-server-lighttpd 'mutation out-server-lighttpd: GREEN (BLIND!)'
  metaprobe sink-wrapped-blind-ash tools/passivity-check.sh 'if (b ~ /^(sh|bash|ash|dash|ksh|zsh|busybox' 'if (b ~ /^(bash|ash|dash|ksh|zsh|busybox' sink-wrapped-ionice-file 'mutation sink-wrapped-ionice-file: GREEN (BLIND!)'
  if [ "$SHARD_N" -gt 0 ]; then shard_end; exit 0; fi   # a shard of --meta leaves its sums, the merge judges them
  if [ "$MERGE" = 1 ]; then merge_run "$@" || exit 1; fi
  printf 'passivity meta probe: %s/%s blinded checkers detected\n' "$nmok" "$nm"
  [ "$nm" -ge 2 ] && [ "$nmok" = "$nm" ]; exit $?
fi

# ============================== unmutated image first ==============================
base_check() {   # the line on stdout; 1, with the reason on stderr, when the unmutated copy is not green (nothing is run against it then)
  run_check "$base" > "$tmp/base.out" 2>&1; brc=$?
  bpass=$(grep -c ' PASS$' "$tmp/base.out"); bfail=$(grep -c ' FAIL$' "$tmp/base.out")
  # every pinned row name must exist as a PASS row here, or the table talks about rows that are gone (phantom)
  phantom=""; _ifs=$IFS; IFS='|'
  for _p in $ROWS; do _p=$_p awk 'index($0, ENVIRON["_p"]) == 1 { f = 1 } END { exit !f }' "$tmp/base.out" || phantom="$phantom [$_p]"; done
  IFS=$_ifs
  printf 'unmutated image: checker exit %s, %s PASS rows (≥ %s), %s FAIL, rows not printed:%s\n' "$brc" "$bpass" "$MIN_ROWS" "$bfail" "${phantom:- none}"
  if [ "$brc" != 0 ] || [ "$bpass" -lt "$MIN_ROWS" ] || [ -n "$phantom" ]; then
    echo "passivity mutation probe: the unmutated copy is not green (or a pinned row name is gone): nothing to compare against" >&2
    sed 's/^/    /' "$tmp/base.out" | cut -c1-160 >&2; return 1
  fi
}
if [ -z "$sel" ] && [ "$MERGE" = 0 ]; then
  if [ "$SHARD_N" -gt 0 ]; then   # a shard: every shard checks it (a red one ends them all at once), shard 0 prints the line; a red one leaves the line and the reason as lines of its own for the merge
    base_check > "$tmp/base.o" 2> "$tmp/base.e"; _brc=$?
    if [ "$_brc" != 0 ]; then
      awk '{ printf "L\t0\t%d\t%s\n", NR, $0 }' "$tmp/base.o"; awk '{ printf "E\t%s\n", $0 }' "$tmp/base.e"; printf 'RED\n'; exit 1
    fi
    [ "$SHARD_I" != 0 ] || awk '{ printf "L\t0\t%d\t%s\n", NR, $0 }' "$tmp/base.o"
  else base_check || exit 1; fi
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
mut readonly-gone    starchorus-collect.sh     subst    'sqlite3 -readonly -noheader $RQ_BAIL' 'sqlite3 -noheader $RQ_BAIL'               'sqlite3 read-only'   # the recondb_query call, one of the two outside the self-test; the self-test asks its own databases with the same words
mut sqlite-write-fn  starchorus-collect.sh     fnappend 'sqlite3 "$db" "DELETE FROM t"' ''                              'sqlite3 read-only'
mut sqlite-vanished  starchorus-collect.sh     subst    'sqlite3 -readonly -noheader $RQ_BAIL' 'sq_lite -readonly -noheader $RQ_BAIL'     'sqlite3 read-only'
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
mutr1 bt-"ev"al          starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); ev''al "$bt_c"'              'Bluetooth wrappers|§14.6h program-text'
mutr1 bt-busybox         starchorus-collect.sh     subst    'bt_t0=$(bt_now)' 'bt_t0=$(bt_now); busybox sh -c "$bt_c"'      'Bluetooth wrappers|§14.6h program-text'
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
mut   bt-eval-planted    starchorus-collect.sh     fndef    'bt_sweep' 'ev''al "$bt_c"'                                       'Bluetooth wrappers|§14.6h program-text'
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
mut bt-split-quote       starchorus-collect.sh     fnappend "hc''itool -i hci0 cmd 8 0x0c" ''                               '§14.6b Bluetooth words|§14.6g outward'
mut bt-split-backslash   starchorus-collect.sh     fnappend 'hc\itool -i hci0 cmd 8 0x0c' ''                                '§14.6b Bluetooth words|§14.6g outward'
mut bt-split-dq          starchorus-collect.sh     fnappend '"hci""tool" -i hci0 cmd 8 0x0c' ''                             '§14.6b Bluetooth words|§14.6g outward'
mut bt-sh-c-split        starchorus-collect.sh     fnappend "sh -c 'hci''tool -i hci0 cmd 8 0x0c'" ''                       '§14.6b Bluetooth words|§14.6h program-text'
mut bt-awk-system        starchorus-collect.sh     fnappend 'awk "BEGIN { system(\"hci\" \"tool -i hci0 cmd\") }"' ''      '§14.6b Bluetooth words|§14.6h program-text'
mut bt-split-display     starchorus-display.sh     fnappend "hc''itool -i hci0 cmd 8 0x0c" ''                               '§14.6b Bluetooth words|§14.6g outward'
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
# `$` word in a case pattern, a `$` inside quotes, a quote that goes on over two lines. The two limits were controls, written down in a test: a built string handed to eval or to an awk system() was not read.
# Row 6h pins those places now (an eval, an awk system(), a pipe into a shell and ln are program-text sinks), so `dyn-limit-eval` and `dyn-limit-awk` are mutations with the row 6h red, and the names stay as they were. Names and texts that would trip the guard at the top of this script are written with an empty pair of quotes.
mut dyn-split-name       starchorus-collect.sh     fnappend 'zz_a=hci; zz_b=tool; "$zz_a$zz_b" -i hci0 lescan'            '' '§14.6d command words'
mut dyn-var-name         starchorus-collect.sh     fnappend '$zz_cmd -i hci0 lescan'                                      '' '§14.6d command words'
mut dyn-braced           starchorus-collect.sh     fnappend '${zz_cmd} -i hci0 lescan'                                    '' '§14.6d command words'
mut dyn-subst            starchorus-collect.sh     fnappend '$(zz_pick) -i hci0 lescan'                                   '' '§14.6d command words'
mut dyn-subst-quoted     starchorus-collect.sh     fnappend '"$(zz_pick)" -i hci0 lescan'                                 '' '§14.6d command words'
mut dyn-backtick         starchorus-collect.sh     fnappend '`zz_pick` -i hci0 lescan'                                    '' '§14.6d command words'
mut dyn-path-prefix      starchorus-collect.sh     fnappend '/usr/bin/hci$zz_b -i hci0 lescan'                            '' '§14.6d command words'
mut dyn-wrapper-nice     starchorus-collect.sh     fnappend 'nice "$zz_a$zz_b" -i hci0 lescan'                            '' '§14.6d command words'
mut dyn-wrapper-env      starchorus-collect.sh     fnappend 'env X=1 "$zz_a$zz_b" -i hci0 lescan'                         '' '§14.6d command words'
mut dyn-wrapper-"ex"ec   starchorus-collect.sh     fnappend 'ex''ec "$zz_a$zz_b" -i hci0 lescan'                          '' '§14.6d command words|§14.6h program-text'
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
# ---- the docroot of the page servers (§14.6f): the directory a route-A server is given must be "$STARCHORUS_DIR/www", never the whole of STARCHORUS_DIR
mut docroot-whole-launcher       payload.sh  subst 'busybox httpd -f -h "$STARCHORUS_DIR/www"' 'busybox httpd -f -h "$STARCHORUS_DIR"' '§14.6d command words|§14.6f docroot'
mut docroot-whole-uhttpd-launcher payload.sh subst 'uhttpd -f -p "$ADDR:$STARCHORUS_PORT" -h "$STARCHORUS_DIR/www"' 'uhttpd -f -p "$ADDR:$STARCHORUS_PORT" -h "$STARCHORUS_DIR"' '§14.6d command words|§14.6f docroot'
mut docroot-uhttpd-whole         library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -p 1:2 -h "$STARCHORUS_DIR"' '' '§14.6f docroot'
mut docroot-python-whole         library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -m http.server 1 --directory "$STARCHORUS_DIR"' '' '§14.6f docroot'
mut docroot-python-whole-eq      library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -m http.server 1 --directory="$STARCHORUS_DIR"' '' '§14.6f docroot'
mut docroot-unquoted             library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -p 1:2 -h $STARCHORUS_DIR/www' '' '§14.6f docroot'
mut docroot-braced               library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -p 1:2 -h "${STARCHORUS_DIR}"' '' '§14.6f docroot'
mut docroot-suffix-outside       library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -p 1:2 -h "$STARCHORUS_DIR"/www' '' '§14.6f docroot'
mut docroot-subdir               library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -p 1:2 -h "$STARCHORUS_DIR/cap"' '' '§14.6f docroot'
mut docroot-floor                payload.sh  subst '--directory "$STARCHORUS_DIR/www" >/dev/null 2>&1 & srv=$!' '--directory "$zz_d" >/dev/null 2>&1 & srv=$!' '§14.6d command words|§14.6f docroot'
mut docroot-floor-vanished           payload.sh  subst '$NICE python3 -m http.server "$STARCHORUS_PORT" --bind "$ADDR" --directory "$STARCHORUS_DIR/www" >/dev/null 2>&1 & srv=$!' '$NICE python3 -m zzserver "$STARCHORUS_PORT" --bind "$ADDR" >/dev/null 2>&1 & srv=$!' '§14.6d command words|§14.6f docroot'
mut docroot-attached                 library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -p 1:2 -h"$STARCHORUS_DIR"' '' '§14.6f docroot'
mut docroot-cluster                  library/user/reconnaissance/starchorus/payload.sh fnappend 'busybox httpd -fh "$STARCHORUS_DIR" -p 1:2' '' '§14.6f docroot'
mut docroot-cluster-attached         library/user/reconnaissance/starchorus/payload.sh fnappend 'busybox httpd -fh"$STARCHORUS_DIR" -p 1:2' '' '§14.6f docroot'
mut docroot-python-d                 library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -m http.server 1 -d "$STARCHORUS_DIR"' '' '§14.6f docroot'
mut docroot-python-d-attached        library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -m http.server 1 -d"$STARCHORUS_DIR"' '' '§14.6f docroot'
mut docroot-python-abbrev            library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -m http.server 1 --dir "$STARCHORUS_DIR"' '' '§14.6f docroot'
mut docroot-python-abbrev-eq         library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -m http.server 1 --dir="$STARCHORUS_DIR"' '' '§14.6f docroot'
mut docroot-ok-www               library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -p 1:2 -h "$STARCHORUS_DIR/www"' '' ''
mut docroot-ok-comment           library/user/reconnaissance/starchorus/payload.sh fnappend '# uhttpd -p 1:2 -h "$STARCHORUS_DIR"' '' ''
mut docroot-heredoc-quoted       library/user/reconnaissance/starchorus/payload.sh fnappend "cat <<'zz_e' > /dev/null
uhttpd -p 1:2 -h \"\$STARCHORUS_DIR\"
zz_e" '' '§14.6f docroot'
mut docroot-heredoc-in-string    library/user/reconnaissance/starchorus/payload.sh fnappend "echo \"<<'zz_e'\" > /dev/null
uhttpd -p 1:2 -h \"\$STARCHORUS_DIR\"
zz_e" '' '§14.6f docroot'
mut docroot-heredoc-bare         library/user/reconnaissance/starchorus/payload.sh fnappend "cat <<zz_e > /dev/null
\$(uhttpd -p 1:2 -h \"\$STARCHORUS_DIR\")
zz_e" '' '§14.6f docroot'
mut docroot-heredoc-after        library/user/reconnaissance/starchorus/payload.sh fnappend "cat <<'zz_e' > /dev/null
text
zz_e
uhttpd -p 1:2 -h \"\$STARCHORUS_DIR\"" '' '§14.6f docroot'
mut docroot-ok-python-d-www          library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -m http.server 1 -d "$STARCHORUS_DIR/www"' '' ''
mut docroot-ok-cluster-www           library/user/reconnaissance/starchorus/payload.sh fnappend 'busybox httpd -fh "$STARCHORUS_DIR/www" -p 1:2' '' ''
mut docroot-ok-test-d                library/user/reconnaissance/starchorus/payload.sh fnappend '[ -d "$STARCHORUS_DIR" ]' '' ''
# (flipped on 24 October 2026: was a control (an argument that does not name STARCHORUS_DIR); the row 6f reads it now: a mutation, the name stays)
mut docroot-ok-other-dir         library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -p 1:2 -h /www' '' '§14.6f docroot'
# (flipped on 24 October 2026: was a control (a directory that reaches the argument through a variable, written down as a limit); the row 6f reads it now: a mutation, the name stays)
mut docroot-limit-alias          library/user/reconnaissance/starchorus/payload.sh fnappend 'zz_d=$STARCHORUS_DIR; uhttpd -p 1:2 -h "$zz_d"' '' '§14.6f docroot'
mut docroot-www-parent              library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -p 1:2 -h "$STARCHORUS_DIR/www"/..' '' '§14.6f docroot'
mut docroot-www-parent-quoted       library/user/reconnaissance/starchorus/payload.sh fnappend "uhttpd -p 1:2 -h \"\$STARCHORUS_DIR/www\"'/..'" '' '§14.6f docroot'
mut docroot-python-d-continued      library/user/reconnaissance/starchorus/payload.sh fnappend "python3 -m http.server 1 \\
        -d \"\$STARCHORUS_DIR\"" '' '§14.6f docroot'
mut docroot-python-abbrev-continued library/user/reconnaissance/starchorus/payload.sh fnappend "python3 -m http.server 1 \\
        --dir \"\$STARCHORUS_DIR\"" '' '§14.6f docroot'
mut docroot-python-d-continued-grep library/user/reconnaissance/starchorus/payload.sh fnappend "ps w | grep python \\
        -d \"\$STARCHORUS_DIR\"" '' '§14.6f docroot'
mut docroot-ok-continued-www        library/user/reconnaissance/starchorus/payload.sh fnappend "python3 -m http.server 1 \\
        -d \"\$STARCHORUS_DIR/www\"" '' ''
# (flipped on 24 October 2026: was a control (a relative `-h .` after a cd, written down as a limit); the row 6f reads it now: a mutation, the name stays)
mut docroot-limit-cd                library/user/reconnaissance/starchorus/payload.sh fnappend 'cd "$STARCHORUS_DIR" && uhttpd -p 1:2 -h .' '' '§14.6f docroot'
# The three entries above whose names say ok or limit (`-ok-other-dir`, `-limit-alias`, `-limit-cd`) were controls: they wrote down what the row could not see (an argument that does not name STARCHORUS_DIR, a directory that reaches the argument through a variable,
# a relative `-h .` after a cd). The row reads them now (on a line that names a page server every docroot argument must be exactly "$STARCHORUS_DIR/www"), so they are mutations with the row 6f red, and the names stay as they were.
# The six forms of the sighting (alias, `-h .`, no directory after a cd, a configuration file, `-h /root`, a message that pipes into a shell) and the other launches that give no docroot option at all (the server as the command, behind a wrapper, a path, a keyword, a variable such as $NICE):
mut docroot-root-dir                library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 -h /root' '' '§14.6f docroot'
mut docroot-no-directory            library/user/reconnaissance/starchorus/payload.sh fnappend '(cd "$STARCHORUS_DIR" && python3 -m http.server 1)' '' '§14.6f docroot'
mut docroot-config-file             library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 -c /tmp/zz.conf' '' '§14.6f docroot'
mut docroot-printf-pipe             library/user/reconnaissance/starchorus/payload.sh fnappend 'printf "uhttpd -f -p 1:2 -h %s\n" "$STARCHORUS_DIR" | s''h &' '' '§14.6f docroot|§14.6h program-text'
mut docroot-launch-bare             library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-python           library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -m http.server 1' '' '§14.6f docroot'
mut docroot-launch-httpd            library/user/reconnaissance/starchorus/payload.sh fnappend 'busybox httpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-nice             library/user/reconnaissance/starchorus/payload.sh fnappend 'nice -n 19 uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-variable         library/user/reconnaissance/starchorus/payload.sh fnappend '$PL_NICE uhttpd -f -p 1:2' '' '§14.6d command words|§14.6f docroot'
mut docroot-launch-wrapped          library/user/reconnaissance/starchorus/payload.sh fnappend 'ex''ec setsid nice -n 19 timeout 5 uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-path             library/user/reconnaissance/starchorus/payload.sh fnappend '/usr/sbin/uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-keyword          library/user/reconnaissance/starchorus/payload.sh fnappend 'if uhttpd -f -p 1:2; then :; fi' '' '§14.6f docroot'
mut docroot-launch-pipe             library/user/reconnaissance/starchorus/payload.sh fnappend 'echo x | uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-python-versioned library/user/reconnaissance/starchorus/payload.sh fnappend 'python3.11 -m http.server 1' '' '§14.6f docroot'
mut docroot-launch-env-u            library/user/reconnaissance/starchorus/payload.sh fnappend 'env -u X uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-timeout-s        library/user/reconnaissance/starchorus/payload.sh fnappend 'timeout -s INT 5 uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-path-wrapper     library/user/reconnaissance/starchorus/payload.sh fnappend '/usr/bin/env uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-sudo-u           library/user/reconnaissance/starchorus/payload.sh fnappend 'sudo -u root python3 -m http.server 1' '' '§14.6f docroot'
mut docroot-launch-exec-a           library/user/reconnaissance/starchorus/payload.sh fnappend 'ex''ec -a x uhttpd -p 1:2' '' '§14.6f docroot'
mut docroot-launch-command          library/user/reconnaissance/starchorus/payload.sh fnappend 'command uhttpd -p 1:2' '' '§14.6f docroot'
mut docroot-launch-python-option    library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -u -m http.server 1' '' '§14.6f docroot'
mut docroot-launch-python-bytecode  library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -B -m http.server 1' '' '§14.6f docroot'
mut docroot-launch-continued        library/user/reconnaissance/starchorus/payload.sh fnappend "uhttpd -f \\
        -p 1:2" '' '§14.6f docroot'
mut docroot-echo-then               library/user/reconnaissance/starchorus/payload.sh fnappend 'echo x; uhttpd -f -p 1:2 -h /root' '' '§14.6f docroot'
mut docroot-echo-subst              library/user/reconnaissance/starchorus/payload.sh fnappend 'echo "$(uhttpd -f -p 1:2 -h /root)"' '' '§14.6f docroot'
mut docroot-echo-background         library/user/reconnaissance/starchorus/payload.sh fnappend 'echo x & uhttpd -f -p 1:2 -h /root' '' '§14.6f docroot'
mut docroot-two-docroots            library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 -h "$STARCHORUS_DIR/www" -h /root' '' '§14.6f docroot'
mut docroot-python-other-dir        library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -m http.server 1 --directory /srv' '' '§14.6f docroot'
mut docroot-cluster-other-dir       library/user/reconnaissance/starchorus/payload.sh fnappend 'busybox httpd -fh /srv -p 1:2' '' '§14.6f docroot'
mut docroot-function-argument       library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 -h "$(zz_dir)"' '' '§14.6f docroot'
# what stays green on purpose: a message that names a server (the opkg hints of both payloads are two of them), the server as the argument of command -v, pidof or grep, a launch with the right directory beside a configuration file (the file may name another directory:
# written down as a limit), and a message with a docroot option
mut docroot-ok-message              library/user/reconnaissance/starchorus/payload.sh fnappend 'echo "uhttpd -f -p 1:2 -h /root" >&2' '' ''
mut docroot-ok-command-v            library/user/reconnaissance/starchorus/payload.sh fnappend 'command -v uhttpd >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1' '' ''
mut docroot-ok-pidof                library/user/reconnaissance/starchorus/payload.sh fnappend 'ps w | grep -qx httpd; kill -0 "$(cat "$STARCHORUS_DIR/httpd.pid")"' '' ''
mut docroot-ok-awk-pattern          library/user/reconnaissance/starchorus/payload.sh fnappend "awk '!/httpd|http\\.server/ { print }' < /dev/null" '' ''
mut docroot-ok-kill-pidof           library/user/reconnaissance/starchorus/payload.sh fnappend 'kill $(pidof uhttpd) 2>/dev/null; echo hint python3 -m http.server' '' ''
mut docroot-limit-config-beside     library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 -h "$STARCHORUS_DIR/www" -c /tmp/zz.conf' '' ''
mut docroot-limit-built-name        library/user/reconnaissance/starchorus/payload.sh fnappend 'zz_s=uhttp; "${zz_s}d" -f -p 1:2 -h /root' '' '§14.6d command words'
# ---- round 2 of the review (24 October 2026) on the docroot row: a docroot that only a comment names, python's -m in a cluster of options or glued to its module, the programs that run the command they are given, and `=` alone
mut docroot-launch-comment           library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 # -h "$STARCHORUS_DIR/www"' '' '§14.6f docroot'
mut docroot-python-cluster-m         library/user/reconnaissance/starchorus/payload.sh fnappend '(cd / && python3 -Im http.server 1)' '' '§14.6f docroot'
mut docroot-python-cluster-um        library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -um http.server 1' '' '§14.6f docroot'
mut docroot-python-glued-m           library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -mhttp.server 1' '' '§14.6f docroot'
mut docroot-python-glued-simple     library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -mSimpleHTTPServer 1' '' '§14.6f docroot'
mut docroot-python-cluster-simple    library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -um SimpleHTTPServer 1' '' '§14.6f docroot'
mut docroot-python2-simple           library/user/reconnaissance/starchorus/payload.sh fnappend 'python2 -m SimpleHTTPServer 1' '' '§14.6f docroot|§14.6g outward'
mut docroot-python-eq-nolaunch       library/user/reconnaissance/starchorus/payload.sh fnappend 'set -- python3 --directory=/srv' '' '§14.6f docroot'
mut docroot-launch-flock             library/user/reconnaissance/starchorus/payload.sh fnappend 'flock /tmp/zz_lock uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-ionice            library/user/reconnaissance/starchorus/payload.sh fnappend 'ionice -c 3 uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-chrt              library/user/reconnaissance/starchorus/payload.sh fnappend 'chrt -r 10 uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-taskset           library/user/reconnaissance/starchorus/payload.sh fnappend 'taskset 1 uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-chroot            library/user/reconnaissance/starchorus/payload.sh fnappend 'chroot /tmp/zz_root uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-start-stop-daemon library/user/reconnaissance/starchorus/payload.sh fnappend 'start-stop-daemon -S -x /usr/sbin/uhttpd -- -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-setpriv           library/user/reconnaissance/starchorus/payload.sh fnappend 'setpriv --reuid=1 uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-unshare           library/user/reconnaissance/starchorus/payload.sh fnappend 'unshare -m uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-nsenter           library/user/reconnaissance/starchorus/payload.sh fnappend 'nsenter -t 1 uhttpd -f -p 1:2' '' '§14.6f docroot'
# (widened, round 3: watch runs its operands through a shell and is a sink of row 6h by name now)
mut docroot-launch-watch             library/user/reconnaissance/starchorus/payload.sh fnappend 'watch -n 5 uhttpd -f -p 1:2' '' '§14.6f docroot|§14.6h program-text'
mut docroot-launch-doas              library/user/reconnaissance/starchorus/payload.sh fnappend 'doas -u root uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-su                library/user/reconnaissance/starchorus/payload.sh fnappend 'su -c "uhttpd -f -p 1:2" nobody' '' '§14.6f docroot|§14.6h program-text'
mut docroot-launch-runuser           library/user/reconnaissance/starchorus/payload.sh fnappend 'runuser -u nobody -- uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-strace            library/user/reconnaissance/starchorus/payload.sh fnappend 'strace -f uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-ltrace            library/user/reconnaissance/starchorus/payload.sh fnappend 'ltrace uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-launch-script            library/user/reconnaissance/starchorus/payload.sh fnappend 'script -q -c "uhttpd -f -p 1:2" /dev/null' '' '§14.6f docroot|§14.6h program-text'
mut docroot-launch-cpulimit          library/user/reconnaissance/starchorus/payload.sh fnappend 'cpulimit -l 50 -- uhttpd -f -p 1:2' '' '§14.6f docroot'
mut docroot-ok-hash-quoted           library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 -x '\''a # b'\'' -h "$STARCHORUS_DIR/www"' '' ''
mut docroot-ok-hash-in-word          library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 ${zz_a#x} -h "$STARCHORUS_DIR/www"' '' ''
mut docroot-ok-wrapper-www           library/user/reconnaissance/starchorus/payload.sh fnappend 'flock /tmp/zz_lock uhttpd -f -p 1:2 -h "$STARCHORUS_DIR/www"' '' ''
mut docroot-ok-start-stop-www        library/user/reconnaissance/starchorus/payload.sh fnappend 'start-stop-daemon -S -x /usr/sbin/uhttpd -- -f -p 1:2 -h "$STARCHORUS_DIR/www"' '' ''
mut docroot-ok-python-cluster-www    library/user/reconnaissance/starchorus/payload.sh fnappend 'python3 -Im http.server 1 --directory "$STARCHORUS_DIR/www"' '' ''
mut docroot-ok-www-comment           library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 -h "$STARCHORUS_DIR/www" # the www directory' '' ''
# ---- the third round of the review (24 October 2026) on row 6f: a docroot option is decided per simple command, not per line, so one docroot on a line clears no other launch on it; a brace group and a backtick expression end a simple command as a
# separator does; a descriptor copy (`2>&1`) ends none (`docroot-ok-redirect-before`, `-ok-brace-www`, `-ok-background-www` stay green)
mut docroot-launch-second-amp        library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 -h "$STARCHORUS_DIR/www" & uhttpd -f -p 3:4' '' '§14.6f docroot'
mut docroot-launch-second-python     library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 -h "$STARCHORUS_DIR/www"; python3 -m http.server 3' '' '§14.6f docroot'
mut docroot-launch-second-subshell   library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 -h "$STARCHORUS_DIR/www" && (uhttpd -f -p 3:4)' '' '§14.6f docroot'
mut docroot-launch-brace             library/user/reconnaissance/starchorus/payload.sh fnappend '{ uhttpd -f -p 1:2; }' '' '§14.6f docroot'
mut docroot-launch-backtick          library/user/reconnaissance/starchorus/payload.sh fnappend 'zz_x=`uhttpd -f -p 1:2`' '' '§14.6f docroot'
mut docroot-ok-redirect-before       library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f 2>&1 -p 1:2 -h "$STARCHORUS_DIR/www"' '' ''
mut docroot-ok-brace-www             library/user/reconnaissance/starchorus/payload.sh fnappend '{ uhttpd -f -p 1:2 -h "$STARCHORUS_DIR/www"; }' '' ''
mut docroot-ok-background-www        library/user/reconnaissance/starchorus/payload.sh fnappend 'uhttpd -f -p 1:2 -h "$STARCHORUS_DIR/www" >/dev/null 2>&1 & zz_s=$!' '' ''
mut docroot-launch-quoted-option     library/user/reconnaissance/starchorus/payload.sh fnappend "uhttpd -f -p 1:2 -r 'x -h \"\$STARCHORUS_DIR/www\" x'" '' '§14.6f docroot'
mut dyn-ok-assign        starchorus-collect.sh     fnappend 'zz_x=$(zz_f); zz_y="$(zz_f)"; zz_n=$(( $(zz_f) + 30 ))'      '' ''
mut dyn-ok-argument      starchorus-collect.sh     fnappend 'echo "$(zz_f)" "$zz_x" $zz_y; command -v "$zz_x" > /dev/null; for zz_i in "$@"; do echo "$zz_i"; done' '' ''
mut dyn-ok-case-pattern  starchorus-collect.sh     fnappend 'case "$zz_x" in $zz_y|z) : ;; esac'                          '' ''
mut dyn-ok-quoted-text   starchorus-collect.sh     fnappend "echo '\$zz_a \$(zz_c) \"\$zz_b\"'"                           '' ''
mut dyn-ok-multiline     starchorus-collect.sh     fnappend 'echo "a
    $zz_b c"'                                                                                                           '' ''
# (flipped on 24 October 2026: was a control (a built string handed to eval, written down as a limit); the row 6h pins the place now: a mutation, the name stays)
mut dyn-limit-"ev"al     starchorus-collect.sh     fnappend 'ev''al "$zz_a$zz_b -i hci0 lescan"'                          '' '§14.6h program-text'
# (flipped on 24 October 2026: was a control (a built string handed to an awk system(), written down as a limit); the row 6h reads it now: a mutation, the name stays)
mut dyn-limit-awk        starchorus-collect.sh     fnappend "awk -v zz_c=\"\$zz_a\$zz_b\" 'BEGIN { system(zz_c \" -i hci0 lescan\") }'" '' '§14.6h program-text'
# ---- the second row of the same pass (§14.6e): a name that a glob, find, xargs or an alias makes when the line runs. The review's plants, each in a function outside the
# allowlist: a glob character in the command word (`?`, `[`, `*`; the Wi-Fi side too: a bracket in `iw`), `find` with `-exec`, `-execdir`, `-ok` or `-okdir`, `xargs` whose
# command is the replacement string (`{}` and a string of its own) or is missing, and an alias. Quoted names do not hide a wrapper ("exec" "$x"). The controls stay green: a glob in
# a for-list, in a case pattern or as an argument, the test `[ ]` and `[[ ]]`, a `${ }` that holds a blank or a parenthesis, `find` without `-exec`, `xargs` with a command of its
# own, `alias` that only looks. The two limits were controls as well (a glob that is only handed to `ln`, a built string piped into `sh`); the row 6h pins both places now, so `dyn-limit-ln` and `dyn-limit-pipe-sh` are mutations with the row 6h red.
# The texts that would trip the guard at the top of this script (the word before a blank) are written with an empty pair of quotes.
mut dyn-glob             starchorus-collect.sh     fnappend '/usr/bin/hc?tool -i hci0 lescan'                             '' '§14.6e command names'
mut dyn-glob-star        starchorus-collect.sh     fnappend '/usr/bin/hci* -i hci0 lescan'                                '' '§14.6e command names'
mut dyn-bracket          starchorus-collect.sh     fnappend '/usr/bin/hci[t]ool -i hci0 lescan'                           '' '§14.6e command names'
mut dyn-iw-glob          starchorus-collect.sh     fnappend '/usr/sbin/i[w] dev wlan1mon scan'                            '' '§14.6e command names'
mut dyn-find-"ex"ec      starchorus-collect.sh     fnappend 'find /usr/bin -name hci\*l -ex''ec {} -i hci0 lescan \;'       '' '§14.6e command names|§14.6h program-text'
mut dyn-find-execdir     starchorus-collect.sh     fnappend 'find /usr/bin -name hci\*l -execdir {} -i hci0 lescan \;'      '' '§14.6e command names|§14.6h program-text'
mut dyn-find-ok          starchorus-collect.sh     fnappend 'find /usr/bin -name hci\*l -ok {} -i hci0 lescan \;'           '' '§14.6e command names|§14.6h program-text'
mut dyn-find-okdir       starchorus-collect.sh     fnappend 'find /usr/bin -name hci\*l -okdir {} -i hci0 lescan \;'        '' '§14.6e command names|§14.6h program-text'
mut dyn-xargs-placeholder starchorus-collect.sh    fnappend 'printf "%s\n" tool | xargs -I{} {} -i hci0 lescan'           '' '§14.6e command names|§14.6h program-text'
mut dyn-xargs-custom     starchorus-collect.sh     fnappend 'printf "%s\n" tool | xargs -I X X -i hci0 lescan'             '' '§14.6e command names|§14.6h program-text'
mut dyn-xargs-missing    starchorus-collect.sh     fnappend 'printf "%s\n" tool | xargs -n 1'                              '' '§14.6e command names|§14.6h program-text'
mut dyn-alias            starchorus-collect.sh     fnappend 'alias zz_s="$zz_a$zz_b"; zz_s -i hci0 lescan'                '' '§14.6e command names'
mut dyn-wrapper-quoted   starchorus-collect.sh     fnappend '"exec" "$zz_a$zz_b" -i hci0 lescan'                          '' '§14.6d command words|§14.6h program-text'
mut dyn-ok-glob-for      starchorus-collect.sh     fnappend 'for zz_f in /usr/bin/hci* /tmp/zz?; do echo "$zz_f"; done'    '' ''
mut dyn-ok-glob-case     starchorus-collect.sh     fnappend 'case "$zz_x" in a*|b?) : ;; [0-9]*) : ;; *) : ;; esac'        '' ''
mut dyn-ok-glob-arg      starchorus-collect.sh     fnappend 'ls /usr/bin/hci* > /dev/null; rm -f /tmp/zz_*.tmp; echo ?'    '' ''
mut dyn-ok-test-bracket  starchorus-collect.sh     fnappend '[ -f /tmp/x ] && [ -d /tmp ] || [[ "$zz_a" = a* ]]; zz_t=$([ -n "$zz_a" ] && echo y)' '' ''
mut dyn-ok-param-expansion starchorus-collect.sh   fnappend 'zz_y=${zz_x%) *}; zz_m=${zz_n%% *}; zz_p=${zz_q##*") "}; zz_r="${zz_s:-a b)}"' '' ''
mut dyn-ok-find-plain    starchorus-collect.sh     fnappend 'find /tmp -name "*.zz" -print; find . -type f | sort; echo find -ex''ec' '' ''
# (flipped on 24 October 2026: was a control (an xargs with a command of its own); the row 6h pins every xargs now: a mutation, the name stays)
mut dyn-ok-xargs-literal starchorus-collect.sh     fnappend 'printf "%s\n" a | xargs rm -f; printf "%s\n" a | xargs -I{} echo {}; printf "%s\n" a | xargs -n 1 -P 2 -- echo' '' '§14.6h program-text'
mut dyn-ok-alias-lookup  starchorus-collect.sh     fnappend 'alias; alias -p; alias zz_s'                                 '' ''
# (flipped on 24 October 2026: was a control (a glob handed to ln, written down as a limit); the row 6h pins the ln now: a mutation, the name stays)
mut dyn-limit-ln         starchorus-collect.sh     fnappend 'ln -sf /usr/bin/hc?tool /tmp/zz_t; /tmp/zz_t -i hci0 lescan' '' '§14.6h program-text'
# (flipped on 24 October 2026: was a control (a built string piped into a shell, written down as a limit); the row 6h pins it now: a mutation, the name stays)
mut dyn-limit-pipe-sh    starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_a$zz_b -i hci0 lescan" | sh'               '' '§14.6h program-text'
# ---- outward and state-changing programs (row '§14.6g'): the literal command words of the shipped scope, read by the reader of row 7d. One mutation per family of the list in the collector (the sighting's planted lines: a
# program that connects out, installs, configures or switches something, the verbs of `iw`, `ip`, `tc` and `ifconfig` that set, and a redirection into /sys), one in the payload of the library, one in the Overview, one in the
# listener and one in a helper without the suffix; then every form of a command word the reader reads (behind a wrapper, a path, quotes, a separator, a keyword, a substitution, a pipe, a case arm, a redirection, the text of a
# here-document with a bare delimiter, the lower part of a script text); the pins (an edited one, one that is gone, a copy in another function and in another file); the controls (the six pins stand in the base; a comment, a string, a
# quoted here-document, an awk program, a presence test, a function whose name only starts with a word of the list, `ip link show`, `iw dev wlan0 info`, `ifconfig wlan0`, a read from /sys) stay green; the probe's own tools/device-probe.sh
# is not read for these words (its rows are 7d). The texts that would trip the guard at the top of this script (the word before a blank) are written with an empty pair of quotes.
mut out-curl             starchorus-collect.sh     fnappend 'curl http://192.0.2.1/'                                      '' '§14.6g outward'
mut out-wget             starchorus-collect.sh     fnappend 'wget http://192.0.2.1/'                                      '' '§14.6g outward'
mut out-ping             starchorus-collect.sh     fnappend 'ping -c 1 192.0.2.1'                                         '' '§14.6g outward'
mut out-ssh              starchorus-collect.sh     fnappend 'ssh root@192.0.2.1'                                          '' '§14.6g outward'
mut out-telnet           starchorus-collect.sh     fnappend 'telnet 192.0.2.1'                                            '' '§14.6g outward'
mut out-nslookup         starchorus-collect.sh     fnappend 'nslookup example.invalid'                                    '' '§14.6g outward'
mut out-ntpd             starchorus-collect.sh     fnappend 'ntpd -q -p 192.0.2.1'                                        '' '§14.6g outward'
mut out-opkg             starchorus-collect.sh     fnappend 'opkg install zz'                                             '' '§14.6g outward'
mut out-nc               starchorus-collect.sh     fnappend 'nc 192.0.2.1 80'                                             '' '§14.6g outward'
mut out-ftpput           starchorus-collect.sh     fnappend 'ftpput 192.0.2.1 zz'                                         '' '§14.6g outward'
mut out-mail             starchorus-collect.sh     fnappend 'mail -s x y'                                                 '' '§14.6g outward'
mut out-iw-txpower       starchorus-collect.sh     fnappend 'iw dev wlan0 set txpower fixed 3000'                         '' '§14.6g outward'
mut out-iw-channel       starchorus-collect.sh     fnappend 'iw dev wlan0 set channel 6'                                  '' '§14.6g outward'
mut out-iw-antenna       starchorus-collect.sh     fnappend 'iw phy phy0 set antenna 1 1'                                 '' '§14.6g outward'
mut out-ip-down          starchorus-collect.sh     fnappend 'ip link set wlan1mon down'                                   '' '§14.6g outward'
mut out-ifconfig-down    starchorus-collect.sh     fnappend 'ifconfig wlan1mon down'                                      '' '§14.6g outward'
mut out-wifi-down        starchorus-collect.sh     fnappend 'wifi down'                                                   '' '§14.6g outward'
mut out-uci-set          starchorus-collect.sh     fnappend 'uci set wireless.radio0.disabled=1'                          '' '§14.6g outward'
mut out-tc-qdisc         starchorus-collect.sh     fnappend 'tc qdisc add dev wlan0 root netem delay 10ms'                '' '§14.6g outward'
mut out-nft              starchorus-collect.sh     fnappend 'nft add rule inet filter input drop'                         '' '§14.6g outward'
mut out-sys-echo         starchorus-collect.sh     fnappend 'echo 1 > /sys/class/net/wlan0/flags'                         '' '§14.6g outward'
mut out-rfkill           starchorus-collect.sh     fnappend 'rfkill block wifi'                                           '' '§14.6g outward|§14.6b Bluetooth words'
mut out-payload-curl     library/user/reconnaissance/starchorus/payload.sh fnappend 'curl http://192.0.2.1/'              '' '§14.6g outward'
mut out-payload-root-curl payload.sh               fnappend 'curl http://192.0.2.1/'                                      '' '§14.6g outward'
mut out-display-curl     starchorus-display.sh     fnappend 'curl http://192.0.2.1/'                                      '' '§14.6g outward'
mut out-display-copy-curl library/user/reconnaissance/starchorus/starchorus-display.sh fnappend 'curl http://192.0.2.1/'  '' '§14.6g outward'
mut out-serve-curl       starchorus-serve.sh       fnappend 'curl http://192.0.2.1/'                                      '' '§14.6g outward'
mut out-helper-curl      library/user/reconnaissance/starchorus/helper newfile 'curl http://192.0.2.1/'                   '' '§14.6g outward'
mut out-top-level        starchorus-collect.sh     append   'curl http://192.0.2.1/'                                      '' '§14.6g outward'
# the verbs: `iw`, `ip` and `tc` with a changing verb (CHG_VERBS, for tc also the nouns), `ifconfig` with more than an interface, the path of a start script
mut out-iw-del           starchorus-collect.sh     fnappend 'iw dev wlan0 del'                                            '' '§14.6g outward'
mut out-iw-interface-add starchorus-collect.sh     fnappend 'iw phy phy0 interface add zz0 type monitor'                  '' '§14.6g outward'
mut out-iw-disconnect    starchorus-collect.sh     fnappend 'iw dev wlan0 disconnect'                                     '' '§14.6g outward'
mut out-iw-reg-set       starchorus-collect.sh     fnappend 'iw reg set DE'                                               '' '§14.6g outward'
mut out-ip-addr-add      starchorus-collect.sh     fnappend 'ip addr add 192.0.2.7/24 dev wlan0'                          '' '§14.6g outward'
mut out-ip-addr-delete   starchorus-collect.sh     fnappend 'ip addr delete 192.0.2.7/24 dev wlan0'                       '' '§14.6g outward'
mut out-ip-route-flush   starchorus-collect.sh     fnappend 'ip route flush table main'                                   '' '§14.6g outward'
mut out-ip-route-replace starchorus-collect.sh     fnappend 'ip route replace default dev wlan0'                          '' '§14.6g outward'
mut out-ip-route-change  starchorus-collect.sh     fnappend 'ip route change default dev wlan0'                           '' '§14.6g outward'
mut out-ip-route-append  starchorus-collect.sh     fnappend 'ip route append default dev wlan0'                           '' '§14.6g outward'
mut out-ip-route-prepend starchorus-collect.sh     fnappend 'ip route prepend default dev wlan0'                          '' '§14.6g outward'
mut out-ip-option-first  starchorus-collect.sh     fnappend 'ip -s link set wlan0 down'                                   '' '§14.6g outward'
mut out-tc-class         starchorus-collect.sh     fnappend 'tc class show dev wlan0'                                     '' '§14.6g outward'
mut out-tc-filter        starchorus-collect.sh     fnappend 'tc filter show dev wlan0'                                    '' '§14.6g outward'
mut out-tc-del           starchorus-collect.sh     fnappend 'tc qdisc del dev wlan0 root'                                 '' '§14.6g outward'
mut out-ifconfig-promisc starchorus-collect.sh     fnappend 'ifconfig wlan1mon -promisc'                                  '' '§14.6g outward'
mut out-ifconfig-address starchorus-collect.sh     fnappend 'ifconfig wlan0 192.0.2.7 netmask 255.255.255.0'              '' '§14.6g outward'
mut out-ifconfig-up-redirect starchorus-collect.sh fnappend 'ifconfig wlan0 up > /dev/null 2>&1'                          '' '§14.6g outward'
mut out-initd            starchorus-collect.sh     fnappend '/etc/init.d/network restart'                                 '' '§14.6g outward'
# the form of the command word: behind a wrapper, with a path, in quotes, after a separator, a keyword, a substitution, a pipe, a redirection; in the text of a here-document with a bare delimiter, in a script text
mut out-nice             starchorus-collect.sh     fnappend 'nice -n 19 curl http://192.0.2.1/'                           '' '§14.6g outward'
mut out-env              starchorus-collect.sh     fnappend 'env X=1 curl http://192.0.2.1/'                              '' '§14.6g outward'
mut out-timeout          starchorus-collect.sh     fnappend 'timeout -s INT 5 curl http://192.0.2.1/'                     '' '§14.6g outward'
mut out-"ex"ec           starchorus-collect.sh     fnappend 'ex''ec curl http://192.0.2.1/'                               '' '§14.6g outward'
mut out-command          starchorus-collect.sh     fnappend 'command curl http://192.0.2.1/'                              '' '§14.6g outward'
mut out-busybox          starchorus-collect.sh     fnappend 'busybox wget http://192.0.2.1/'                              '' '§14.6g outward'
mut out-xargs            starchorus-collect.sh     fnappend 'echo http://192.0.2.1/ | xargs curl'                         '' '§14.6g outward|§14.6h program-text'
mut out-path             starchorus-collect.sh     fnappend '/usr/bin/curl http://192.0.2.1/'                             '' '§14.6g outward'
mut out-quoted           starchorus-collect.sh     fnappend '"curl" http://192.0.2.1/'                                    '' '§14.6g outward'
mut out-split-quotes     starchorus-collect.sh     fnappend 'cu""rl http://192.0.2.1/'                                    '' '§14.6g outward'
mut out-backslash        starchorus-collect.sh     fnappend '\curl http://192.0.2.1/'                                     '' '§14.6g outward'
mut out-and              starchorus-collect.sh     fnappend 'true && curl http://192.0.2.1/'                              '' '§14.6g outward'
mut out-subst            starchorus-collect.sh     fnappend 'zz_x=$(curl http://192.0.2.1/)'                              '' '§14.6g outward'
mut out-backtick         starchorus-collect.sh     fnappend 'zz_x=`curl http://192.0.2.1/`'                               '' '§14.6g outward'
mut out-pipe             starchorus-collect.sh     fnappend 'echo x | curl -T - http://192.0.2.1/'                        '' '§14.6g outward'
mut out-case-arm         starchorus-collect.sh     fnappend 'case x in x) curl http://192.0.2.1/ ;; esac'                 '' '§14.6g outward'
mut out-keyword          starchorus-collect.sh     fnappend 'if curl http://192.0.2.1/; then :; fi'                       '' '§14.6g outward'
mut out-while            starchorus-collect.sh     fnappend 'while ping -c 1 192.0.2.1; do :; done'                       '' '§14.6g outward'
mut out-redirect-first   starchorus-collect.sh     fnappend '>/dev/null curl http://192.0.2.1/'                           '' '§14.6g outward'
mut out-assign-prefix    starchorus-collect.sh     fnappend 'zz_x=1 curl http://192.0.2.1/'                               '' '§14.6g outward'
mut out-group            starchorus-collect.sh     fnappend '{ curl http://192.0.2.1/; }'                                 '' '§14.6g outward'
mut out-subshell         starchorus-collect.sh     fnappend '( curl http://192.0.2.1/ )'                                  '' '§14.6g outward'
mut out-continued        starchorus-collect.sh     fnappend 'echo x |
    curl -T - http://192.0.2.1/'                                                                                        '' '§14.6g outward'
mut out-heredoc-bare     starchorus-collect.sh     fnappend 'cat <<zz_e > /dev/null
$(curl http://192.0.2.1/)
zz_e'                                                                                                                   '' '§14.6g outward'
mut out-string-substitution starchorus-collect.sh  fnappend 'echo "x $(curl http://192.0.2.1/) y"'                        '' '§14.6g outward'
mut out-script-handler   starchorus-serve.sh       subst    '    kill -0 "$np" 2>/dev/null || return' '    kill -0 "$np" 2>/dev/null || return
    curl http://192.0.2.1/'                                                                                             '§14.6g outward'
mut out-script-handler-top starchorus-serve.sh     subst    'PR=0; [ -r /proc/self/cmdline ] && PR=1' 'PR=0; [ -r /proc/self/cmdline ] && PR=1; curl http://192.0.2.1/' '§14.6g outward'
# the second small rule: a redirection, tee or dd of= into /sys, /proc/sys, /dev/tcp or /dev/udp
mut out-sys-append       starchorus-collect.sh     fnappend 'echo 1 >> /sys/class/net/wlan0/flags'                        '' '§14.6g outward'
mut out-sys-glued        starchorus-collect.sh     fnappend 'echo 1>/sys/class/net/wlan0/flags'                           '' '§14.6g outward'
mut out-sys-quoted       starchorus-collect.sh     fnappend "echo 1 > '/sys/class/net/wlan0/flags'"                       '' '§14.6g outward'
mut out-sys-dquoted      starchorus-collect.sh     fnappend 'echo 1 > "/sys/class/net/wlan0/flags"'                       '' '§14.6g outward'
mut out-sys-noclobber    starchorus-collect.sh     fnappend 'echo 1 >| /sys/class/net/wlan0/flags'                        '' '§14.6g outward'
mut out-sys-descriptor   starchorus-collect.sh     fnappend 'echo 1 2> /sys/class/net/wlan0/flags'                        '' '§14.6g outward'
mut out-sys-slashes      starchorus-collect.sh     fnappend 'echo 1 > //sys//class/net/wlan0/flags'                       '' '§14.6g outward'
mut out-sys-dot          starchorus-collect.sh     fnappend 'echo 1 > /./sys/class/net/wlan0/flags'                       '' '§14.6g outward'
mut out-sys-proc         starchorus-collect.sh     fnappend 'echo 1 > /proc/sys/net/ipv4/ip_forward'                      '' '§14.6g outward'
mut out-sys-sysrq        starchorus-collect.sh     fnappend 'echo b > /proc/sysrq-trigger'                                '' '§14.6g outward'
mut out-sys-first        starchorus-collect.sh     fnappend '> /sys/class/net/wlan0/flags echo 1'                         '' '§14.6g outward'
mut out-sys-tee          starchorus-collect.sh     fnappend 'echo 1 | tee /sys/class/net/wlan0/flags'                     '' '§14.6g outward'
mut out-sys-tee-append   starchorus-collect.sh     fnappend 'echo 1 | tee -a /sys/class/net/wlan0/flags'                  '' '§14.6g outward'
mut out-sys-dd           starchorus-collect.sh     fnappend 'echo 1 | dd of=/sys/class/net/wlan0/flags'                   '' '§14.6g outward'
mut out-dev-tcp          starchorus-collect.sh     fnappend 'ex''ec 3<>/dev/tcp/192.0.2.1/80'                             '' '§14.6g outward'
mut out-dev-udp          starchorus-collect.sh     fnappend 'echo x > /dev/udp/192.0.2.1/9'                               '' '§14.6g outward'
mut out-dev-write        starchorus-collect.sh     fnappend 'echo x > /dev/mtd0'                                          '' '§14.6g outward'
mut out-dev-dd           starchorus-collect.sh     fnappend 'dd if=/tmp/zz_f of=/dev/mtdblock3'                           '' '§14.6g outward'
mut out-cp-sys           starchorus-collect.sh     fnappend 'cp /tmp/zz_f /sys/class/net/wlan0/flags'                     '' '§14.6g outward'
mut out-cp-target        starchorus-collect.sh     fnappend 'cp -t /sys/class/net/wlan0 /tmp/zz_f'                        '' '§14.6g outward'
mut out-cp-target-long   starchorus-collect.sh     fnappend 'cp --target-directory=/sys/class/net/wlan0 /tmp/zz_f'        '' '§14.6g outward'
mut out-mv-dev           starchorus-collect.sh     fnappend 'mv /tmp/zz_f /dev/mtd0'                                      '' '§14.6g outward'
mut out-python-module    starchorus-collect.sh     fnappend 'python3 -m smtplib'                                          '' '§14.6g outward'
# the wrappers with an option that takes a word, or a path, and the programs that run the command they are given
mut out-wrapper-path     starchorus-collect.sh     fnappend '/usr/bin/env curl http://192.0.2.1/'                         '' '§14.6g outward'
mut out-timeout-path     starchorus-collect.sh     fnappend '/usr/bin/timeout 5 curl http://192.0.2.1/'                   '' '§14.6g outward'
mut out-busybox-path     starchorus-collect.sh     fnappend '/bin/busybox wget http://192.0.2.1/'                         '' '§14.6g outward'
mut out-env-u            starchorus-collect.sh     fnappend 'env -u PATH curl http://192.0.2.1/'                          '' '§14.6g outward'
mut out-sudo-u           starchorus-collect.sh     fnappend 'sudo -u root curl http://192.0.2.1/'                         '' '§14.6g outward'
mut out-stdbuf-o         starchorus-collect.sh     fnappend 'stdbuf -o 0 curl http://192.0.2.1/'                          '' '§14.6g outward'
mut out-exec-a           starchorus-collect.sh     fnappend 'ex''ec -a zz curl http://192.0.2.1/'                         '' '§14.6g outward'
mut out-env-split-string starchorus-collect.sh     fnappend 'env -S "curl http://192.0.2.1/"'                             '' '§14.6g outward'
mut out-flock            starchorus-collect.sh     fnappend 'flock /tmp/zz_lock curl http://192.0.2.1/'                   '' '§14.6g outward'
mut out-start-stop       starchorus-collect.sh     fnappend 'start-stop-daemon -S -b -x curl -- http://192.0.2.1/'        '' '§14.6g outward'
mut out-ionice           starchorus-collect.sh     fnappend 'ionice -c 3 wget http://192.0.2.1/'                          '' '§14.6g outward'
mut out-chroot           starchorus-collect.sh     fnappend 'chroot /tmp/zz_root curl http://192.0.2.1/'                  '' '§14.6g outward'
mut out-su-c             starchorus-collect.sh     fnappend 'su -c "curl http://192.0.2.1/" nobody'                       '' '§14.6g outward|§14.6h program-text'
mut out-ip-batch         starchorus-collect.sh     fnappend 'ip -batch /tmp/zz_cmds'                                      '' '§14.6g outward'
mut out-ip-netns-"ex"ec    starchorus-collect.sh     fnappend 'ip netns ex''ec zz curl http://192.0.2.1/'                   '' '§14.6g outward'
# a name that is spelled in pieces: an escaped newline in the middle of a word (the two lines are the one word curl, or hcitool: the text rows read each line alone), quotes or a backslash inside it
mut out-glued-continuation starchorus-collect.sh   fnappend 'cu\
rl http://192.0.2.1/'                                                                                                   '' '§14.6g outward'
mut out-glued-continuation-bt starchorus-collect.sh fnappend 'hci\
tool -i hci0 lescan'                                                                                                    '' '§14.6g outward'
mut out-glued-quotes-bt  starchorus-collect.sh     fnappend 'hc""itool -i hci0 lescan'                                    '' '§14.6g outward|§14.6b Bluetooth words'
mut out-glued-backslash  starchorus-collect.sh     fnappend 'c\url http://192.0.2.1/'                                     '' '§14.6g outward'
# the pins: an edited one, one that is gone, a copy in another function, a copy in another file
mut out-pin-edited       starchorus-collect.sh     subst    'have ifconfig && ifconfig "$newif" up 2>/dev/null' 'have ifconfig && ifconfig "$newif" down 2>/dev/null' '§14.6g outward'
mut out-pin-gone         starchorus-collect.sh     subst    'if have iw; then iw dev "$MONIF" del 2>/dev/null; fi' 'if have iw; then :; fi'  '§14.6g outward'
mut out-pin-copy         starchorus-collect.sh     fnappend 'have ifconfig && ifconfig "$newif" up 2>/dev/null'           '' '§14.6g outward'
mut out-pin-copy-twin    starchorus-collect.sh     fnappend 'have ip && ip link set "$MONIF" up 2>/dev/null'              '' '§14.6g outward'
mut out-pin-elsewhere    payload.sh                fnappend 'have ifconfig && ifconfig "$newif" up 2>/dev/null'           '' '§14.6g outward'
mut out-pin-extra-option starchorus-collect.sh     subst    'have ip && ip link set "$newif" up 2>/dev/null' 'have ip && ip link set "$newif" up promisc on 2>/dev/null' '§14.6g outward'
# the probe is not read for these words: its rows are 7d (a pinned line in the collector does not cover the probe either: probe-pin-in-collector)
mut out-probe-curl       tools/device-probe.sh     fnappend 'curl http://192.0.2.1/'                                      '' 'device-probe.sh named tools|device-probe.sh programs'
# what stays green: a comment, a string, an awk program, a quoted here-document, a presence test, a name that only starts with a word of the list, reads (ip link show, iw dev wlan0 info and survey dump, ifconfig wlan0, a read from /sys), a descriptor copy, /dev/null
mut out-ok-comment       starchorus-collect.sh     fnappend '# curl http://192.0.2.1/ ; iw dev wlan0 set channel 6 ; echo 1 > /sys/x'  '' ''
mut out-ok-string        starchorus-collect.sh     fnappend 'echo "curl http://192.0.2.1/ ; ip link set wlan0 down ; wifi down ; iw dev wlan0 set channel 6 ; echo 1 > /sys/x"' '' ''
mut out-ok-single-quoted starchorus-collect.sh     fnappend "echo 'curl http://192.0.2.1/ ; nc 192.0.2.1 80 ; echo 1 > /sys/x'" '' ''
mut out-ok-awk           starchorus-collect.sh     fnappend "awk 'BEGIN { print \"curl x\"; print \"1\" > \"/sys/x\" }' < /dev/null" '' ''
mut out-ok-heredoc-quoted starchorus-collect.sh    fnappend "cat <<'zz_e' > /dev/null
curl http://192.0.2.1/
ip link set wlan0 down
echo 1 > /sys/class/net/wlan0/flags
zz_e" '' ''
mut out-ok-presence      starchorus-collect.sh     fnappend 'have curl; command -v wget >/dev/null; type ping >/dev/null 2>&1; [ -x /usr/bin/ssh ]; which uci >/dev/null 2>&1; have nc; have ip || have ifconfig' '' ''
mut out-ok-name          starchorus-collect.sh     fnappend 'zz_mail_note() { :; }; zz_mail_note; echo ping-pong; curlew=1; ip_addr=1; nc_port=2; sshd_ok=1; zz_wifi_state=1' '' ''
mut out-ok-reads         starchorus-collect.sh     fnappend 'ip link show wlan0; ip -s link; ip route get 192.0.2.1; ip addr show; ip -4 -o addr; ip neigh show' '' ''
mut out-ok-iw-reads      starchorus-collect.sh     fnappend 'iw dev; iw dev wlan0 info; iw dev wlan0 survey dump; iw phy phy0 info; iw reg get; iw dev wlan0 station dump; iw --version' '' ''
mut out-ok-ifconfig      starchorus-collect.sh     fnappend 'ifconfig wlan0; ifconfig -a; ifconfig -a wlan0; ifconfig wlan0 > /tmp/zz.txt 2>&1' '' ''
mut out-ok-sys-reads     starchorus-collect.sh     fnappend 'cat /sys/class/net/wlan0/address; [ -r /sys/class/net/wlan0/flags ]; read zz_a < /proc/sys/kernel/hostname; ls /sys/class/net > /dev/null' '' ''
mut out-ok-descriptors   starchorus-collect.sh     fnappend 'echo x >&2; echo y 2>&1; echo z > /dev/null 2>&1; ex''ec 3>&1 4>&2' '' ''
mut out-ok-copies       starchorus-collect.sh     fnappend 'cp /sys/class/net/wlan0/address /tmp/zz_a; mv /tmp/zz_a /tmp/zz_b; cp -a /tmp/zz_x /tmp/zz_y; install -m 600 /tmp/zz_a /tmp/zz_b; cp -t /tmp/zz_d /tmp/zz_a' '' ''
mut out-ok-dev          starchorus-collect.sh     fnappend 'echo x > /dev/null; echo y > /dev/stderr; echo z > /dev/tty 2>/dev/null; head -c 1 < /dev/zero > /dev/null; python3 --version' '' ''
mut out-ok-tee-private   starchorus-collect.sh     fnappend 'echo x | tee /tmp/zz_t > /dev/null; echo y | dd of=/tmp/zz_d 2> /dev/null' '' ''
mut out-ok-listener-expansion starchorus-collect.sh fnappend 'zz_nc=$(command -v nc); [ -x "$zz_nc" ] && echo "[starchorus-serve] no nc at $zz_nc" >&2' '' ''
# (flipped on 24 October 2026, round 2: `iw` lists the commands that read, so a command that an expansion makes is red now; it was a limit written down as a control, the name stays)
mut out-limit-verb-expansion starchorus-collect.sh fnappend 'iw dev wlan0 $zz_verb channel 6'                             '' '§14.6g outward'
mut out-limit-sys-variable starchorus-collect.sh   fnappend 'echo 1 > "$zz_sysfs/flags"'                                  '' ''
mut out-limit-built-name starchorus-collect.sh     fnappend 'zz_c=cur; "${zz_c}l" http://192.0.2.1/'                      '' '§14.6d command words'
# (flipped, round 2: a program run by a path outside the system directories is a pinned line of the row 6h now; the same copy run by its plain name stays unseen: `out-limit-copied-program-path`)
mut out-limit-copied-program starchorus-collect.sh fnappend 'cp /bin/true /tmp/zz_c; /tmp/zz_c http://192.0.2.1/'         '' '§14.6h program-text'
mut out-limit-copied-program-path starchorus-collect.sh fnappend 'mkdir -p /tmp/zz_bin; cp /bin/true /tmp/zz_bin/zz_c; PATH=/tmp/zz_bin:$PATH zz_c http://192.0.2.1/' '' ''
# (flipped, round 2: the action of a trap is read as code now; it was a limit written down as a control, the name stays)
mut out-limit-trap-string starchorus-collect.sh    fnappend "trap 'curl http://192.0.2.1/' EXIT"                          '' '§14.6g outward'
# (flipped, round 2: an awk command pipe is a program text the row 6h pins; it was a limit written down as a control, the name stays)
mut out-limit-getline    starchorus-collect.sh     fnappend "awk 'BEGIN { \"curl http://192.0.2.1/\" | getline zz_y }' < /dev/null" '' '§14.6h program-text'
# the two floors of the row, raised in a copy of the checker: the pins that were found, the command words that were read
mut out-floor-pins       tools/passivity-check.sh  subst    'MIN_6G_PINS=6 ' 'MIN_6G_PINS=7 '                             '§14.6g outward'
mut out-floor-cmds       tools/passivity-check.sh  subst    'MIN_6G_CMDS=5000 ' 'MIN_6G_CMDS=500000 '                     '§14.6g outward'
mut out-limit-single-quoted-command starchorus-collect.sh fnappend "awk 'BEGIN { system(\"curl http://192.0.2.1/\") }' < /dev/null" '' '§14.6h program-text'
# ---- program-text sinks (row '§14.6h'): the places where a program text is made or taken and run. One mutation per sink of the list (eval, a shell with -c, a pipe into a shell, a shell that reads its standard input, an awk system(,
# `. FILE` and source, xargs, find -exec, ln, an exec of a built word, an interpreter with -c) in the collector, the forms the reader reads (behind a wrapper, with a path, in quotes, across lines, in a here-document with a bare delimiter,
# in the lower part of a script text and in the part above its first function head, which the head `init() {` of the page server's handler now makes code), one in the payload of the library, the Overview, the listener and a helper,
# the pins (an edited one, one that is gone, a copy in another function and in another file, a fifth copy of a line that is pinned four times) and the controls: the words in a comment, in a string, in an awk program and in a quoted
# here-document are no sinks, `exec` as a plain word in a comment and as a redirection only, `sh FILE`, `find ... -print`. Four of the five limits of the row are written down as controls too (a shell run on a file the script wrote,
# a program copied to another name, a `trap` with a string, an awk `"cmd" | getline`). The texts that would trip the guard at the top of this script (the word before a blank) are written with an empty pair of quotes.
mut sink-"ev"al            starchorus-collect.sh     fnappend 'ev''al "$zz_x"'                                              '' '§14.6h program-text'
mut sink-shell-c         starchorus-collect.sh     fnappend 's''h -c "$zz_x"'                                             '' '§14.6h program-text'
mut sink-sh-c-cluster-self starchorus-collect.sh   fnappend 's''h -ec "$0"'                                           '' '§14.6h program-text'
mut sink-shell-c-cluster starchorus-collect.sh     fnappend 's''h -ec "$zz_x"'                                            '' '§14.6h program-text'
mut sink-shell-c-path    starchorus-collect.sh     fnappend '/bin/s''h -c "$zz_x"'                                        '' '§14.6h program-text'
mut sink-shell-c-after-option starchorus-collect.sh fnappend 's''h -x -c "$zz_x"'                                         '' '§14.6h program-text'
mut sink-bash-c          starchorus-collect.sh     fnappend 'ba''sh -c "$zz_x"'                                           '' '§14.6h program-text'
mut sink-busybox-sh      starchorus-collect.sh     fnappend 'busybox s''h -c "$zz_x"'                                     '' '§14.6h program-text'
mut sink-pipe-sh         starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | s''h'                                '' '§14.6h program-text'
mut sink-pipe-"ba"sh       starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | ba''sh'                              '' '§14.6h program-text'
mut sink-pipe-ash        starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | a''sh'                               '' '§14.6h program-text'
mut sink-pipe-env-sh     starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | env s''h'                            '' '§14.6h program-text'
mut sink-pipe-next-line  starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" |
    sh'                                                                                                               '' '§14.6h program-text'
mut sink-sh-stdin-file   starchorus-collect.sh     fnappend 's''h < /tmp/zz_f'                                            '' '§14.6h program-text'
mut sink-sh-s            starchorus-collect.sh     fnappend 's''h -s'                                                     '' '§14.6h program-text'
mut sink-sh-heredoc      starchorus-collect.sh     fnappend 's''h <<'\''zz_e'\''
true
zz_e'                                                                                                                   '' '§14.6h program-text'
mut sink-system          starchorus-collect.sh     fnappend "awk 'BEGIN { system(\"true\") }' < /dev/null"                '' '§14.6h program-text'
mut sink-system-spaced   starchorus-collect.sh     fnappend "awk 'BEGIN { system (\"true\") }' < /dev/null"               '' '§14.6h program-text'
mut sink-system-in-string starchorus-collect.sh    fnappend 'echo "the awk function system( is read as text, a string too"' '' '§14.6h program-text'
mut sink-dot             starchorus-collect.sh     fnappend '. /tmp/zz_f'                                                 '' '§14.6h program-text'
mut sink-dot-subst       starchorus-collect.sh     fnappend 'zz_x=$(. /tmp/zz_f)'                                         '' '§14.6h program-text'
mut sink-"sour"ce          starchorus-collect.sh     fnappend 'sour''ce /tmp/zz_f'                                          '' '§14.6h program-text'
mut sink-xargs           starchorus-collect.sh     fnappend 'printf "%s\n" a | xargs rm -f'                               '' '§14.6h program-text'
mut sink-xargs-placeholder starchorus-collect.sh   fnappend 'printf "%s\n" a | xargs -I{} {} x'                           '' '§14.6e command names|§14.6h program-text'
mut sink-find-"ex"ec     starchorus-collect.sh     fnappend 'find /tmp -name zz -ex''ec rm {} \;'                         '' '§14.6e command names|§14.6h program-text'
mut sink-find-ok         starchorus-collect.sh     fnappend 'find /tmp -name zz -ok rm {} \;'                             '' '§14.6e command names|§14.6h program-text'
mut sink-ln              starchorus-collect.sh     fnappend 'ln -s /usr/bin/hc?tool /tmp/zz_t'                            '' '§14.6h program-text'
mut sink-ln-quoted       starchorus-collect.sh     fnappend '"ln" -s a b'                                                 '' '§14.6h program-text'
mut sink-ln-wrapped      starchorus-collect.sh     fnappend 'nice ln -s a b'                                              '' '§14.6h program-text'
mut sink-exec-built      starchorus-collect.sh     fnappend 'ex''ec "$zz_x"'                                              '' '§14.6d command words|§14.6h program-text'
mut sink-exec-built-wrapped starchorus-collect.sh  fnappend 'ex''ec nice "$zz_x"'                                         '' '§14.6d command words|§14.6h program-text'
mut sink-exec-glob       starchorus-collect.sh     fnappend 'ex''ec /usr/bin/hc?tool'                                     '' '§14.6e command names|§14.6h program-text'
mut sink-interp-python   starchorus-collect.sh     fnappend 'python3 -c "$zz_x"'                                          '' '§14.6h program-text'
mut sink-interp-perl     starchorus-collect.sh     fnappend 'perl -e "$zz_x"'                                             '' '§14.6h program-text'
mut sink-wrapped-"ev"al    starchorus-collect.sh     fnappend 'nice ev''al "$zz_x"'                                         '' '§14.6h program-text'
mut sink-quoted-"ev"al     starchorus-collect.sh     fnappend '"ev""al" "$zz_x"'                                            '' '§14.6g outward|§14.6h program-text'
mut sink-backslash-"ev"al  starchorus-collect.sh     fnappend '\ev''al "$zz_x"'                                             '' '§14.6h program-text'
mut sink-heredoc-bare    starchorus-collect.sh     fnappend 'cat <<zz_e > /dev/null
$(eval;)
zz_e'                                                                                                                   '' '§14.6h program-text'
mut sink-script-handler  starchorus-serve.sh       subst    '    kill -0 "$np" 2>/dev/null || return' '    kill -0 "$np" 2>/dev/null || return
    eval; :'                                                                                                     '§14.6h program-text'
mut sink-script-handler-top starchorus-serve.sh    subst    'PR=0; [ -r /proc/self/cmdline ] && PR=1' 'PR=0; [ -r /proc/self/cmdline ] && PR=1; ev''al "$zz_x"' '§14.6h program-text'
mut sink-payload-"ev"al    library/user/reconnaissance/starchorus/payload.sh fnappend 'ev''al "$zz_x"'                       '' '§14.6h program-text'
mut sink-payload-root-"ev"al payload.sh              fnappend 'ev''al "$zz_x"'                                              '' '§14.6h program-text'
mut sink-display-"ev"al    starchorus-display.sh     fnappend 'ev''al "$zz_x"'                                              '' '§14.6h program-text'
mut sink-display-copy-"ev"al library/user/reconnaissance/starchorus/starchorus-display.sh fnappend 'ev''al "$zz_x"'          '' '§14.6h program-text'
mut sink-serve-"ev"al      starchorus-serve.sh       fnappend 'ev''al "$zz_x"'                                              '' '§14.6h program-text'
mut sink-helper-"ev"al     library/user/reconnaissance/starchorus/helper newfile 'ev''al "$zz_x"'                            '' '§14.6h program-text'
mut sink-top-level       starchorus-collect.sh     append   'ev''al "$zz_x"'                                              '' '§14.6h program-text'
# the pins
mut sink-pin-edited      starchorus-display.sh     subst    'ev''al "R_$k=\$v N_$k=\$i"' 'ev''al "R_$k=\$v N_$k=\$i; :"'      '§14.6h program-text'
mut sink-pin-gone        starchorus-collect.sh     subst    'ev''al "${ixd#*:}"' ': "${ixd#*:}"'                             '§14.6h program-text'
mut sink-pin-copy        starchorus-collect.sh     fnappend 'ev''al "${ixd#*:}"'                                          '' '§14.6h program-text'
mut sink-pin-copy-file   payload.sh                fnappend 'ev''al "${ixd#*:}"'                                          '' '§14.6h program-text'
mut sink-pin-fifth-copy  starchorus-collect.sh     fnappend 's''h -c '\''exit 0'\'' & dpid=$!; wait "$dpid" 2>/dev/null'   '' '§14.6h program-text'
mut sink-pin-ln-edited   payload.sh                subst    'ln -sf ../index.html "$wd/index.html"' 'ln -sf ../index.htm "$wd/index.html"' '§14.6h program-text'
mut sink-pin-python-edited starchorus-collect.sh   subst    "python3 -c 'import sys,json; json.load(sys.stdin)'" "python3 -c 'import sys,json; json.load(sys.stdin); print(1)'" '§14.6h program-text'
# what stays green: a comment, a string, an awk program, a quoted here-document, the word exec in a comment and as a redirection only, a shell given a file, find without -exec, names that only contain a word of the list
mut sink-ok-comment      starchorus-collect.sh     fnappend '# ev''al x ; s''h -c y ; ln -s a b ; ex''ec "$x" ; xargs rm ; . /tmp/zz_f'  '' ''
mut sink-ok-exec-comment starchorus-collect.sh     fnappend '# ex''ec is a plain word in this comment'                    '' ''
mut sink-ok-string       starchorus-collect.sh     fnappend 'echo "ev''al and s''h -c and xargs and ln -s and . /tmp/zz_f are words in this string"' '' ''
mut sink-ok-single-quoted starchorus-collect.sh    fnappend "echo 'ev''al x; s''h -c y; xargs rm; ln -s a b'"             '' ''
mut sink-ok-awk          starchorus-collect.sh     fnappend 'awk '\''BEGIN { print "ev''al s''h -c ln xargs" }'\'' < /dev/null' '' ''
mut sink-ok-heredoc-quoted starchorus-collect.sh   fnappend 'cat <<'\''zz_e'\'' > /dev/null
eval;
/bin/sh -c y
xargs rm
ln -s a b
exec;
zz_e'                                                                                                                   '' ''
mut sink-ok-exec-redirect starchorus-collect.sh    fnappend 'ex''ec 4>&2 2>/dev/null; ex''ec 2>&4 4>&-'                    '' ''
mut sink-ok-exec-literal starchorus-collect.sh     fnappend 'ex''ec sleep 1'                                              '' ''
# (flipped, round 2: a shell given a FILE is pinned by the row 6h, the file may hold a text that the script wrote; it was a control and a limit written down, the names stay)
mut sink-ok-shell-file   starchorus-collect.sh     fnappend 's''h "$STARCHORUS_DIR/zz.sh" --zz'                           '' '§14.6h program-text'
mut sink-ok-find-print   starchorus-collect.sh     fnappend 'find /tmp -name zz -print; find . -type f | sort'            '' ''
mut sink-ok-names        starchorus-collect.sh     fnappend 'evaluate() { :; }; evaluate; zz_ln=1; lnx=2; [ -L /tmp/zz ]; echo ln; cd ..; ls .; cp -r . /tmp/zz_c' '' ''
mut sink-ok-dot-argument starchorus-collect.sh     fnappend 'set -- . ..; for zz_d in . ..; do ls "$zz_d"; done; cd . && pwd' '' ''
mut sink-limit-shell-file starchorus-collect.sh    fnappend 'printf "%s\n" "true" > /tmp/zz_f; s''h /tmp/zz_f'            '' '§14.6h program-text'
# ---- the review of 24 October 2026 (round 2) on the rows 6g and 6h. Everything below only ADDS; the entries it flips are named where they stand (`out-limit-verb-expansion`, `-trap-string`, `-getline`, `sink-ok-shell-file`, `sink-limit-shell-file`).
# `ip` and `tc` take every unambiguous prefix of a verb or an object, so an abbreviated verb is read as the verb it can stand for (the objects `ip a` and `ip r` are prefixes of verbs too, and red with them: the row errs on the side of red). `ip -ba FILE` is `ip -batch FILE`.
mut out-ip-abbrev-ls     starchorus-collect.sh     fnappend 'ip l s "$zz_if" down'                                        '' '§14.6g outward'
mut out-ip-abbrev-lise   starchorus-collect.sh     fnappend 'ip li se "$zz_if" down'                                      '' '§14.6g outward'
mut out-ip-abbrev-ls-literal starchorus-collect.sh fnappend 'ip l s wlan1mon down'                                       '' '§14.6g outward'
mut out-ip-abbrev-lise-literal starchorus-collect.sh fnappend 'ip li se wlan1mon down'                                   '' '§14.6g outward'
mut out-ip-abbrev-aa     starchorus-collect.sh     fnappend 'ip a a 192.0.2.1/24 dev wlan0'                               '' '§14.6g outward'
mut out-ip-abbrev-rd     starchorus-collect.sh     fnappend 'ip r d default'                                              '' '§14.6g outward'
mut out-ip-abbrev-addr-de starchorus-collect.sh    fnappend 'ip addr de 192.0.2.7/24 dev wlan0'                           '' '§14.6g outward'
mut out-ip-abbrev-fl     starchorus-collect.sh     fnappend 'ip route fl table main'                                     '' '§14.6g outward'
mut out-tc-abbrev        starchorus-collect.sh     fnappend 'tc q a dev wlan0 root netem delay 10ms'                      '' '§14.6g outward'
mut out-tc-abbrev-noun   starchorus-collect.sh     fnappend 'tc qd show dev wlan0'                                        '' '§14.6g outward'
mut out-ip-batch-abbrev  starchorus-collect.sh     fnappend 'ip -ba /tmp/zz_cmds'                                         '' '§14.6g outward'
mut out-ip-batch-long    starchorus-collect.sh     fnappend 'ip --batch /tmp/zz_cmds'                                     '' '§14.6g outward'
mut out-ip-restore       starchorus-collect.sh     fnappend 'ip addr restore'                                             '' '§14.6g outward'
mut out-ok-ip-words      starchorus-collect.sh     fnappend 'ip addr show dev wlan0; ip -br link; ip route show table main; ip link show type bridge; ip -s -d link show wlan0 master br0; ip -4 -o addr show scope global' '' ''
# `iw` matches its commands whole, and only the commands that read are listed (info, link, scan, survey dump, station dump or get, reg get, wowlan show, event, features, commands, help, version, list, channels, get, mpath or mpp dump or get): every other command is red,
# whatever it does. (`scan` is listed because the row `iw scan opt-in only` holds the one guarded line of the collector.)
mut out-iw-switch        starchorus-collect.sh     fnappend 'iw dev wlan0 switch channel 6'                               '' '§14.6g outward'
mut out-iw-offchannel    starchorus-collect.sh     fnappend 'iw dev wlan0 offchannel 2412 100'                            '' '§14.6g outward'
mut out-iw-roc           starchorus-collect.sh     fnappend 'iw dev wlan0 roc start 2412 100'                             '' '§14.6g outward'
mut out-iw-ocb           starchorus-collect.sh     fnappend 'iw dev wlan0 ocb join 5890 10MHz'                            '' '§14.6g outward'
mut out-iw-auth          starchorus-collect.sh     fnappend 'iw dev wlan0 auth open 2412 00:11:22:33:44:55'               '' '§14.6g outward'
mut out-iw-measurement   starchorus-collect.sh     fnappend 'iw dev wlan0 measurement ftm_request /tmp/zz_cfg'            '' '§14.6g outward'
mut out-iw-vendor        starchorus-collect.sh     fnappend 'iw dev wlan0 vendor send 0x001122 0x01'                      '' '§14.6g outward'
mut out-iw-ap-start      starchorus-collect.sh     fnappend 'iw dev wlan0 ap start /tmp/zz_cfg'                           '' '§14.6g outward'
mut out-iw-cac           starchorus-collect.sh     fnappend 'iw dev wlan0 cac trigger channel 52'                         '' '§14.6g outward'
mut out-iw-mpath-new     starchorus-collect.sh     fnappend 'iw dev wlan0 mpath new 00:11:22:33:44:55 next_hop 00:11:22:33:44:66' '' '§14.6g outward'
mut out-iw-mesh-leave    starchorus-collect.sh     fnappend 'iw dev wlan0 mesh leave'                                     '' '§14.6g outward'
mut out-iw-wowlan        starchorus-collect.sh     fnappend 'iw phy phy0 wowlan enable any'                               '' '§14.6g outward'
mut out-iw-coalesce      starchorus-collect.sh     fnappend 'iw phy phy0 coalesce enable /tmp/zz_cfg'                     '' '§14.6g outward'
mut out-iw-reg-reload    starchorus-collect.sh     fnappend 'iw reg reload'                                               '' '§14.6g outward'
mut out-iw-station-new   starchorus-collect.sh     fnappend 'iw dev wlan0 station new 00:11:22:33:44:55'                  '' '§14.6g outward'
mut out-iw-survey-other  starchorus-collect.sh     fnappend 'iw dev wlan0 survey zz'                                      '' '§14.6g outward'
mut out-iw-before-selector starchorus-collect.sh   fnappend 'iw zz_nothing'                                               '' '§14.6g outward'
mut out-iw-ibss-leave    starchorus-collect.sh     fnappend 'iw dev wlan0 ibss leave'                                     '' '§14.6g outward'
mut out-iw-payload-switch library/user/reconnaissance/starchorus/payload.sh fnappend 'iw dev wlan0 switch channel 6'      '' '§14.6g outward'
mut out-iw-display-offchannel starchorus-display.sh fnappend 'iw dev wlan0 offchannel 2412 100'                           '' '§14.6g outward'
mut out-ok-iw-more       starchorus-collect.sh     fnappend 'iw dev wlan0 link; iw phy phy0 channels; iw dev wlan0 get power_save; iw phy phy0 wowlan show; iw dev wlan0 mpath dump; iw event; iw list; iw features; iw commands; iw help; iw reg get; iw dev wlan0 station get 00:11:22:33:44:55' '' ''
mut out-ok-iw-options    starchorus-collect.sh     fnappend 'iw --debug dev wlan0 info; iw -t dev wlan0 link'             '' ''
# the programs the first list left out (OUT_WORDS: the alternative probe plants every word; these are the families: another ssh client, Wake-on-LAN, lookups and the TLS client, MQTT, the firewall front ends, flash and boot environment, raw registers, mount, the clock), and the verb rules for
# `date` (-s, --set, an operand of digits or from an expansion), `logger -n`, `logread -r`, `iwinfo ... scan`
mut out-dbclient         starchorus-collect.sh     fnappend 'dbclient root@192.0.2.1'                                     '' '§14.6g outward'
mut out-ether-wake       starchorus-collect.sh     fnappend 'ether-wake 00:11:22:33:44:55'                                '' '§14.6g outward'
mut out-whois            starchorus-collect.sh     fnappend 'whois example.invalid'                                       '' '§14.6g outward'
mut out-openssl          starchorus-collect.sh     fnappend 'openssl s_client -connect 192.0.2.1:443'                     '' '§14.6g outward'
mut out-host             starchorus-collect.sh     fnappend 'host example.invalid'                                        '' '§14.6g outward'
mut out-mosquitto        starchorus-collect.sh     fnappend 'mosquitto_pub -h 192.0.2.1 -t zz -m zz'                      '' '§14.6g outward'
mut out-mount            starchorus-collect.sh     fnappend 'mount -t nfs 192.0.2.1:/zz /mnt'                             '' '§14.6g outward'
mut out-fw4              starchorus-collect.sh     fnappend 'fw4 reload'                                                  '' '§14.6g outward'
mut out-mtd              starchorus-collect.sh     fnappend 'mtd write /tmp/zz_img firmware'                              '' '§14.6g outward'
mut out-sysupgrade       starchorus-collect.sh     fnappend 'sysupgrade -n /tmp/zz_img'                                   '' '§14.6g outward'
mut out-firstboot        starchorus-collect.sh     fnappend 'firstboot -y'                                                '' '§14.6g outward'
mut out-fw-setenv        starchorus-collect.sh     fnappend 'fw_setenv zz_a zz_b'                                         '' '§14.6g outward'
mut out-devmem           starchorus-collect.sh     fnappend 'devmem 0x10000000 32 1'                                      '' '§14.6g outward'
mut out-i2cset           starchorus-collect.sh     fnappend 'i2cset -y 0 0x50 0 1'                                        '' '§14.6g outward'
mut out-hwclock          starchorus-collect.sh     fnappend 'hwclock -w'                                                  '' '§14.6g outward'
mut out-date-set         starchorus-collect.sh     fnappend 'date -s "tomorrow 10:00"'                                    '' '§14.6g outward'
mut out-date-set-long    starchorus-collect.sh     fnappend 'date --set="tomorrow 10:00"'                                 '' '§14.6g outward'
mut out-date-set-cluster starchorus-collect.sh     fnappend 'date -us "tomorrow 10:00"'                                   '' '§14.6g outward'
mut out-date-digits      starchorus-collect.sh     fnappend 'date 102412002026'                                           '' '§14.6g outward'
mut out-date-expansion   starchorus-collect.sh     fnappend 'date "$zz_stamp"'                                            '' '§14.6g outward'
mut out-iwinfo-scan      starchorus-collect.sh     fnappend 'iwinfo wlan0 scan'                                           '' '§14.6g outward'
mut out-logger-remote    starchorus-collect.sh     fnappend 'logger -n 192.0.2.1 zz'                                      '' '§14.6g outward'
mut out-logger-server    starchorus-collect.sh     fnappend 'logger --server 192.0.2.1 zz'                                '' '§14.6g outward'
mut out-logread-remote   starchorus-collect.sh     fnappend 'logread -r 192.0.2.1 514'                                    '' '§14.6g outward'
mut out-payload-dbclient library/user/reconnaissance/starchorus/payload.sh fnappend 'dbclient root@192.0.2.1'              '' '§14.6g outward'
mut out-display-sysupgrade starchorus-display.sh   fnappend 'sysupgrade -n /tmp/zz_img'                                   '' '§14.6g outward'
mut out-ok-clock-reads   starchorus-collect.sh     fnappend 'date +%s; date -u +%FT%TZ; date -d @5 +%s; command date "$@"; date -d 1024 +%s; date -r /tmp/zz_f; date +%Y'  '' ''
mut out-ok-log-reads     starchorus-collect.sh     fnappend 'logger -t zz hello; logread | tail -n 5; logread -f; logread -l 50; iwinfo wlan0 info; iwinfo wlan0 assoclist; iwinfo wlan0 freqlist' '' ''
mut out-ok-names-new     starchorus-collect.sh     fnappend 'hostname; zz_host=1; mountpoint -q /tmp; zz_openssl=1; echo mount; command -v host >/dev/null; have mtd; [ -x /sbin/sysupgrade ]' '' ''
# the action of a trap is shell text that runs when the signal comes: a plain name or one string on a line is read as code (what it runs is a command word of the scope), any other form is a record of the row 6h
# (`out-limit-trap-string` was a control that wrote this down; it is a mutation now, the name stays)
mut out-trap-double      starchorus-collect.sh     fnappend 'trap "curl http://192.0.2.1/" EXIT'                          '' '§14.6g outward'
mut out-trap-name        starchorus-collect.sh     fnappend 'trap curl EXIT'                                              '' '§14.6g outward'
mut out-trap-nested      starchorus-collect.sh     fnappend "trap 'trap \"curl http://192.0.2.1/\" EXIT' EXIT"            '' '§14.6g outward'
mut out-trap-after-exit  starchorus-collect.sh     fnappend "trap 'rm -f /tmp/zz_f; curl http://192.0.2.1/; exit 130' INT" '' '§14.6g outward'
mut out-trap-iw          starchorus-collect.sh     fnappend "trap 'iw dev wlan0 switch channel 6' TERM"                   '' '§14.6g outward'
mut out-trap-payload     library/user/reconnaissance/starchorus/payload.sh fnappend "trap 'curl http://192.0.2.1/' EXIT"  '' '§14.6g outward'
mut out-trap-display     starchorus-display.sh     fnappend "trap 'curl http://192.0.2.1/' EXIT"                          '' '§14.6g outward'
mut out-trap-top-level   starchorus-collect.sh     append   "trap 'curl http://192.0.2.1/' EXIT"                          '' '§14.6g outward'
mut out-trap-script-handler starchorus-serve.sh    subst    '    kill -0 "$np" 2>/dev/null || return' '    kill -0 "$np" 2>/dev/null || return
    trap '\''curl http://192.0.2.1/'\'' EXIT'                                                                      '§14.6g outward'
mut sink-trap-ev         starchorus-collect.sh     fnappend "trap 'ev''al \"\$zz_x\"' EXIT"                               '' '§14.6h program-text'
mut sink-trap-sh-c       starchorus-collect.sh     fnappend 'trap "s''h -c zz_x" EXIT'                                    '' '§14.6h program-text'
mut sink-trap-multiline  starchorus-collect.sh     fnappend "trap 'true
    curl http://192.0.2.1/' EXIT"                                                                                      '' '§14.6h program-text'
mut sink-trap-glued      starchorus-collect.sh     fnappend "trap 'true'\"\$zz_x\" EXIT"                                  '' '§14.6h program-text'
mut sink-trap-option     starchorus-collect.sh     fnappend 'trap -- true EXIT'                                           '' '§14.6h program-text'
mut out-trap-three      starchorus-collect.sh     fnappend 'trap "trap \"trap \\\"curl http://192.0.2.1/\\\" EXIT\" EXIT" EXIT' '' '§14.6g outward'
mut sink-trap-deep       starchorus-collect.sh     fnappend 'trap "trap \"trap \\\"trap \\\\\\\"curl http://192.0.2.1/\\\\\\\" EXIT\\\" EXIT\" EXIT" EXIT' '' '§14.6h program-text'
mut sink-trap-built      starchorus-collect.sh     fnappend 'trap "$zz_x" EXIT'                                           '' '§14.6d command words'
mut sink-trap-escaped    starchorus-collect.sh     fnappend 'trap "\$zz_x" EXIT'                                          '' '§14.6d command words'
mut sink-trap-name-ev    starchorus-collect.sh     fnappend 'trap ev''al EXIT'                                            '' '§14.6h program-text'
mut out-ok-traps         starchorus-collect.sh     fnappend "trap - INT; trap '' TERM HUP; trap 'exit 130' INT; trap 'rm -f \"\$zz_f\"; exit 143' TERM; trap zz_stop EXIT; trap \"kill \\\"\\\$zz_p\\\" 2>/dev/null; exit 0\" TERM" '' ''
# an awk program that starts a command (`"cmd" | getline`, `cmd | getline`, `print x | "cmd"`, `|&`) and one that is read from a file are program texts too: the row 6h reads them as text on a code line
# (`out-limit-getline` was a control; it is a mutation now, the name stays)
mut sink-awk-getline-var starchorus-collect.sh     fnappend "awk 'BEGIN { zz_c = \"wget -q x\"; zz_c | getline }' < /dev/null" '' '§14.6h program-text'
mut sink-awk-getline-coproc starchorus-collect.sh  fnappend "awk 'BEGIN { \"date\" |& getline zz_y }' < /dev/null"        '' '§14.6h program-text'
mut sink-awk-print-pipe  starchorus-collect.sh     fnappend "awk 'BEGIN { print \"x\" | \"s''h\" }' < /dev/null"           '' '§14.6h program-text'
mut sink-awk-printf-pipe starchorus-collect.sh     fnappend "awk 'BEGIN { printf \"%s\\n\", \"x\" | \"cat\" }' < /dev/null" '' '§14.6h program-text'
mut sink-awk-file        starchorus-collect.sh     fnappend 'awk -f /tmp/zz.awk < /dev/null'                              '' '§14.6h program-text'
mut sink-awk-file-glued  starchorus-collect.sh     fnappend 'awk -f/tmp/zz.awk < /dev/null'                               '' '§14.6h program-text'
mut sink-awk-file-long   starchorus-collect.sh     fnappend 'gawk --file=/tmp/zz.awk < /dev/null'                         '' '§14.6h program-text'
mut sink-awk-getline-payload library/user/reconnaissance/starchorus/payload.sh fnappend "awk 'BEGIN { \"date\" | getline zz_y }' < /dev/null" '' '§14.6h program-text'
mut sink-ok-awk-redirect starchorus-collect.sh     fnappend "awk 'BEGIN { print 1 > \"/dev/null\"; getline zz_l < \"/dev/null\" }' < /dev/null" '' ''
# a shell or an interpreter that reads its program from its standard input, in the spellings the first reading missed: `sh -s ARG` (the operand is a positional parameter), /dev/stdin, /dev/fd/0, /proc/self/fd/0, the argument of -o (and -O, --rcfile), a plus option, and an interpreter with no script (or `-`)
mut sink-sh-s-arg        starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | s''h -s zz_arg'                       '' '§14.6h program-text'
mut sink-sh-dev-stdin    starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | s''h /dev/stdin'                      '' '§14.6h program-text'
mut sink-sh-o-option     starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | s''h -o errexit'                      '' '§14.6h program-text'
mut sink-sh-o-cluster    starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | s''h -eo errexit'                     '' '§14.6h program-text'
mut sink-sh-plus-option  starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | s''h +x'                              '' '§14.6h program-text'
mut sink-sh-rcfile       starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | ba''sh --rcfile /dev/null'            '' '§14.6h program-text'
mut sink-sh-big-o        starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | ba''sh -O extglob'                    '' '§14.6h program-text'
mut sink-sh-minus        starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | s''h -'                               '' '§14.6h program-text'
mut sink-sh-s-self       starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | s''h -s "$0"'                          '' '§14.6h program-text'
mut sink-sh-o-self       starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | s''h -o "$0"'                          '' '§14.6h program-text'
mut sink-sh-big-o-self   starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | ba''sh -O "$0"'                        '' '§14.6h program-text'
mut sink-sh-rcfile-self  starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | ba''sh --rcfile "$0"'                  '' '§14.6h program-text'
mut sink-sh-two-on-a-line starchorus-collect.sh    fnappend 's''h "$0" --zz; printf "%s\n" "$zz_x" | s''h'                   '' '§14.6h program-text'
mut sink-interp-stdin    starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | python3'                             '' '§14.6h program-text'
mut sink-interp-minus-py starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | python3 -'                           '' '§14.6h program-text'
mut sink-interp-versioned starchorus-collect.sh    fnappend 'printf "%s\n" "$zz_x" | python3.11'                          '' '§14.6h program-text'
mut sink-interp-perl-stdin starchorus-collect.sh   fnappend 'printf "%s\n" "$zz_x" | perl'                                '' '§14.6h program-text'
mut sink-interp-minus-lua starchorus-collect.sh     fnappend 'printf "%s\n" "$zz_x" | lua -'                               '' '§14.6h program-text'
mut sink-interp-ruby-stdin starchorus-collect.sh   fnappend 'printf "%s\n" "$zz_x" | ruby'                                '' '§14.6h program-text'
mut sink-interp-node-stdin starchorus-collect.sh   fnappend 'printf "%s\n" "$zz_x" | node'                                '' '§14.6h program-text'
mut sink-interp-php-r    starchorus-collect.sh     fnappend 'php -r "$zz_x"'                                              '' '§14.6h program-text'
mut sink-interp-node-p   starchorus-collect.sh     fnappend 'node -p "$zz_x"'                                             '' '§14.6h program-text'
mut sink-interp-node-evl starchorus-collect.sh    fnappend 'node --ev''al "$zz_x"'                                         '' '§14.6h program-text'
mut sink-interp-c-versioned starchorus-collect.sh   fnappend 'python3.11 -c "$zz_x"'                                      '' '§14.6h program-text'
mut sink-interp-module-glued starchorus-collect.sh fnappend 'python3 -msmtplib'                                           '' '§14.6g outward'
mut sink-interp-module-versioned starchorus-collect.sh fnappend 'python3.11 -m smtplib'                                   '' '§14.6g outward'
mut sink-ok-interp-flags starchorus-collect.sh     fnappend 'python3 --version; python3 -V; perl -v; lua -v; ruby --version; node --version; php --version; python3 --help'  '' ''
mut sink-ok-shell-self   starchorus-collect.sh     fnappend 's''h "$0" --zz'                                              '' ''
mut sink-ok-shell-plus   starchorus-collect.sh     fnappend 's''h +x "$0" --zz'                                           '' ''
mut sink-ok-shell-twice  starchorus-collect.sh     fnappend 's''h "$0" --zz; ba''sh "$0" --zz'                              '' ''
# a shell given a FILE, an interpreter given a script and awk -f read a text that the script may have written: the row 6h pins each line (the self-test's stand-ins are five); "$0", the script itself, is the one exception
# (`sink-ok-shell-file` and `sink-limit-shell-file` were controls that wrote this down; they are mutations now, the names stay)
mut sink-run-file-ex     starchorus-collect.sh     fnappend 'ex''ec s''h /tmp/zz_f'                                       '' '§14.6h program-text'
mut sink-run-file-wrapped starchorus-collect.sh    fnappend 'nice s''h /tmp/zz_f'                                         '' '§14.6h program-text'
mut sink-run-file-busybox starchorus-collect.sh    fnappend 'busybox ash /tmp/zz_f'                                       '' '§14.6h program-text'
mut sink-run-file-options starchorus-collect.sh    fnappend 's''h -e -x /tmp/zz_f'                                        '' '§14.6h program-text'
mut sink-run-file-python starchorus-collect.sh     fnappend 'python3 /tmp/zz_f.py'                                        '' '§14.6h program-text'
mut sink-run-file-perl   starchorus-collect.sh     fnappend 'perl /tmp/zz_f.pl'                                           '' '§14.6h program-text'
mut sink-run-file-payload library/user/reconnaissance/starchorus/payload.sh fnappend 's''h /tmp/zz_f'                      '' '§14.6h program-text'
mut sink-run-file-display starchorus-display.sh    fnappend 's''h /tmp/zz_f'                                              '' '§14.6h program-text'
mut sink-run-file-pin-edited starchorus-collect.sh subst    's''h "$tdir/own/airodump-ng" </dev/null' 's''h "$tdir/own/airodump-ng2" </dev/null' '§14.6h program-text'
mut sink-run-file-pin-gone starchorus-collect.sh   subst    '( s''h "$tdir/own/$SELF_BASE" </dev/null >/dev/null 2>&1 & echo $! > "$tdir/own/l.pid" )' ': ' '§14.6h program-text'
mut sink-run-file-pin-copy starchorus-collect.sh   fnappend '( s''h "$tdir/own/$SELF_BASE" </dev/null >/dev/null 2>&1 & echo $! > "$tdir/own/l.pid" )' '' '§14.6h program-text'
# ---- the bypasses found while testing the first fixes (round 2): the programs that change an interface or a radio by name, the routing table, the neighbour table and the host name, a program run by a path outside the system directories, `tcpdump -z`, the options of `tar` that run a program,
# `sed -i` and `truncate` on a path of /sys, and the dot commands of the sqlite3 shell that run one. What stays unseen is written down as controls: an awk program that writes a file (`print 1 > "/sys/x"`: the control `out-ok-awk` above), a script that the script wrote into a directory of the PATH and runs by its name.
mut out-macchanger                 starchorus-collect.sh fnappend 'macchanger -r wlan0' '' '§14.6g outward'
mut out-wl                         starchorus-collect.sh fnappend 'wl up' '' '§14.6g outward'
mut out-route-add                  starchorus-collect.sh fnappend 'route add default gw 192.0.2.1' '' '§14.6g outward'
mut out-route-del                  starchorus-collect.sh fnappend 'route del default' '' '§14.6g outward'
mut out-arp-set                    starchorus-collect.sh fnappend 'arp -s 192.0.2.1 00:11:22:33:44:55' '' '§14.6g outward'
mut out-arp-del                    starchorus-collect.sh fnappend 'arp -d 192.0.2.1' '' '§14.6g outward'
mut out-hostname-set               starchorus-collect.sh fnappend 'hostname zz-pager' '' '§14.6g outward'
mut out-hostname-file              starchorus-collect.sh fnappend 'hostname -F/tmp/zz_name' '' '§14.6g outward'
mut out-ok-net-reads               starchorus-collect.sh fnappend 'route -n; arp -a; arp -n; hostname; hostname -s; hostname -f' '' ''
mut out-sys-sed                    starchorus-collect.sh fnappend 'sed -i s/a/b/ /sys/class/net/wlan0/flags' '' '§14.6g outward'
mut out-sys-sed-suffix             starchorus-collect.sh fnappend 'sed -n -i.bak s/a/b/p /proc/sys/net/ipv4/ip_forward' '' '§14.6g outward'
mut out-sys-truncate               starchorus-collect.sh fnappend 'truncate -s 0 /sys/class/net/wlan0/flags' '' '§14.6g outward'
mut out-ok-sed-reads               starchorus-collect.sh fnappend 'sed -n s/a/b/p /sys/class/net/wlan0/flags; sed -i s/a/b/ /tmp/zz_f; truncate -s 0 /tmp/zz_f' '' ''
mut sink-tcpdump-z                 starchorus-collect.sh fnappend 'tcpdump -i wlan1mon -w /tmp/zz.pcap -G 5 -z /tmp/zz_run' '' '§14.6h program-text'
mut sink-tcpdump-z-cluster         starchorus-collect.sh fnappend 'tcpdump -lz /tmp/zz_run -i wlan1mon' '' '§14.6h program-text'
mut sink-tcpdump-z-long            starchorus-collect.sh fnappend 'tcpdump -i wlan1mon -w /tmp/zz.pcap -G 5 --postrotate-command=/tmp/zz_run' '' '§14.6h program-text'
mut sink-ok-tcpdump                starchorus-collect.sh fnappend 'tcpdump -i wlan1mon -l -e -s 256 -w /tmp/zz.pcap -Z nobody; timeout 5 tcpdump -i wlan1mon -c 1' '' ''
mut sink-tar-action                starchorus-collect.sh fnappend 'tar --checkpoint=1 --checkpoint-action=exec=zz -cf /dev/null /tmp' '' '§14.6h program-text'
mut sink-tar-to-command            starchorus-collect.sh fnappend 'tar -xf /tmp/zz.tar --to-command=zz' '' '§14.6h program-text'
mut sink-tar-compress              starchorus-collect.sh fnappend 'tar -I zz -cf /tmp/zz.tar /tmp' '' '§14.6h program-text'
mut sink-ok-tar                    starchorus-collect.sh fnappend 'tar -cf /tmp/zz.tar /tmp; tar -xzf /tmp/zz.tgz -C /tmp; tar -tf /tmp/zz.tar' '' ''
mut sink-sqlite-shell              starchorus-collect.sh fnappend "sqlite3 -readonly /tmp/zz.db '.shell zz_run'" '' '§14.6h program-text'
mut sink-sqlite-system             starchorus-collect.sh fnappend "sqlite3 -readonly /tmp/zz.db '.system zz_run'" '' '§14.6h program-text'
mut sink-sqlite-heredoc            starchorus-collect.sh fnappend "sqlite3 -readonly /tmp/zz.db <<'zz_e' > /dev/null
.shell zz_run
zz_e" '' '§14.6h program-text'
mut sink-ok-sqlite-dot             starchorus-collect.sh fnappend "sqlite3 -readonly /tmp/zz.db '.tables' > /dev/null; echo 'the shell and the system'" '' ''
mut sink-path-run                  starchorus-collect.sh fnappend '/tmp/zz_run' '' '§14.6h program-text'
mut sink-path-run-dot              starchorus-collect.sh fnappend './zz_run' '' '§14.6h program-text'
mut sink-path-run-up               starchorus-collect.sh fnappend '../zz_run --zz' '' '§14.6h program-text'
mut sink-path-run-wrapped          starchorus-collect.sh fnappend 'nice -n 5 /tmp/zz_run' '' '§14.6h program-text'
mut sink-path-run-quoted           starchorus-collect.sh fnappend '"/tmp/zz_run"' '' '§14.6h program-text'
mut sink-path-run-payload          library/user/reconnaissance/starchorus/payload.sh fnappend '/tmp/zz_run' '' '§14.6h program-text'
mut sink-path-run-display          starchorus-display.sh fnappend './zz_run' '' '§14.6h program-text'
mut sink-path-pin-edited           payload.sh subst './starchorus-collect.sh --stop' './starchorus-collect.sh --stop --zz' '§14.6h program-text'
mut sink-ok-path-system            starchorus-collect.sh fnappend '/usr/bin/true; /bin/true; /sbin/true; /usr/sbin/true; /usr/local/bin/true; /usr/bin/env true' '' ''
mut sink-limit-written-program     starchorus-collect.sh fnappend 'mkdir -p /tmp/zz_bin; printf "%s\n" "curl http://192.0.2.1/" > /tmp/zz_bin/zz_x; chmod +x /tmp/zz_bin/zz_x; PATH=/tmp/zz_bin:$PATH zz_x' '' ''
# a program of the row 6h behind a program that runs its operand: `flock FILE sh -c ...`, `chroot DIR python3 -c ...`, `start-stop-daemon -x /bin/sh` (the words of the shell are arguments of the wrapper for the reader)
mut sink-wrapped-flock-sh          starchorus-collect.sh fnappend 'flock /tmp/zz_lock s''h -c "$zz_x"' '' '§14.6h program-text'
mut sink-wrapped-start-stop-sh     starchorus-collect.sh fnappend 'start-stop-daemon -S -x /bin/s''h -- -c true' '' '§14.6h program-text'
mut sink-wrapped-chroot-python     starchorus-collect.sh fnappend 'chroot /tmp/zz_root python3 -c true' '' '§14.6h program-text'
mut sink-wrapped-ionice-file       starchorus-collect.sh fnappend 'ionice -c 3 s''h /tmp/zz_f' '' '§14.6h program-text'
mut sink-wrapped-awk               starchorus-collect.sh fnappend 'flock /tmp/zz_lock awk -f /tmp/zz.awk' '' '§14.6h program-text'
mut sink-wrapped-strace            starchorus-collect.sh fnappend 'strace -f s''h' '' '§14.6h program-text'
mut sink-ok-wrapped-plain          starchorus-collect.sh fnappend 'flock /tmp/zz_lock sleep 1; ionice -c 3 nice true; chroot /tmp/zz_root true; strace -f true' '' ''
# ---- the third round of the review (24 October 2026) on the rows 6g and 6h. A word from an expansion before a verb that reads is red for ip and tc (as iwarg has it for iw), for route and arp before a read option, for the command of iwinfo
# (its device may be a quoted expansion), for logger before `--` (the tag and the priority apart) and for logread (the count and the pattern apart); the BusyBox applets iplink, ipaddr, iproute, iprule, ipneigh and iptunnel are read as ip; chpst, setuidgid,
# envuidgid, envdir and softlimit run their operand like flock does; `builtin NAME` is read as a wrapper; watch and run-parts are sinks of row 6h by name, and so are flock -c and the long and glued forms of su, runuser and script with a command
# string. `out-ok-expansion-reads`, `-ip-applets` and `-builtin` stay green; `sink-limit-sed-e` writes down that a sed program that runs a command (GNU sed `e`) is text the reader does not read.
mut out-verb-expansion-ip          starchorus-collect.sh fnappend 'ip link "$zz_v" wlan0 down' '' '§14.6g outward'
mut out-verb-expansion-ip-object   starchorus-collect.sh fnappend 'ip "$zz_o" wlan0 down' '' '§14.6g outward'
mut out-verb-expansion-tc          starchorus-collect.sh fnappend 'tc "$zz_x" dev wlan0' '' '§14.6g outward'
mut out-verb-expansion-route       starchorus-collect.sh fnappend 'route "$zz_v" default gw 192.0.2.1' '' '§14.6g outward'
mut out-verb-expansion-arp         starchorus-collect.sh fnappend 'arp "$zz_o" 192.0.2.1' '' '§14.6g outward'
mut out-verb-expansion-iwinfo      starchorus-collect.sh fnappend 'iwinfo wlan0 "$zz_c"' '' '§14.6g outward'
mut out-verb-expansion-iwinfo-split starchorus-collect.sh fnappend 'iwinfo $zz_x' '' '§14.6g outward'
mut out-verb-expansion-logger      starchorus-collect.sh fnappend 'logger $zz_o hello' '' '§14.6g outward'
mut out-verb-expansion-logger-message starchorus-collect.sh fnappend 'logger -t zz "$zz_m"' '' '§14.6g outward'
mut out-verb-expansion-logread     starchorus-collect.sh fnappend 'logread $zz_o' '' '§14.6g outward'
mut out-ok-expansion-reads         starchorus-collect.sh fnappend 'ip link show "$zz_if"; ip -o addr show dev "$zz_if"; ip route get "$zz_a"; iwinfo "$zz_if" info; logger -t zz -- "$zz_m"; logger -p user.info -t "$zz_t" -- x; logread -l "$zz_n"; arp -n "$zz_h"' '' ''
mut out-ip-applet-link             starchorus-collect.sh fnappend 'iplink set wlan0 down' '' '§14.6g outward'
mut out-ip-applet-addr             starchorus-collect.sh fnappend 'ipaddr add 192.0.2.7/24 dev wlan0' '' '§14.6g outward'
mut out-ip-applet-route            starchorus-collect.sh fnappend 'iproute del default' '' '§14.6g outward'
mut out-ip-applet-rule             starchorus-collect.sh fnappend 'iprule add from all lookup 5' '' '§14.6g outward'
mut out-ip-applet-neigh            starchorus-collect.sh fnappend 'ipneigh flush dev wlan0' '' '§14.6g outward'
mut out-ip-applet-tunnel           starchorus-collect.sh fnappend 'iptunnel del zz0' '' '§14.6g outward'
mut out-ok-ip-applets              starchorus-collect.sh fnappend 'iplink show; ipaddr; iproute; iprule; ipneigh show; iptunnel show' '' ''
mut out-runner-chpst               starchorus-collect.sh fnappend 'chpst -u nobody curl http://192.0.2.1/' '' '§14.6g outward'
mut out-runner-setuidgid           starchorus-collect.sh fnappend 'setuidgid nobody curl http://192.0.2.1/' '' '§14.6g outward'
mut out-runner-envuidgid           starchorus-collect.sh fnappend 'envuidgid nobody curl http://192.0.2.1/' '' '§14.6g outward'
mut out-runner-envdir              starchorus-collect.sh fnappend 'envdir /tmp/zz_env curl http://192.0.2.1/' '' '§14.6g outward'
mut out-runner-softlimit           starchorus-collect.sh fnappend 'softlimit -m 100000 curl http://192.0.2.1/' '' '§14.6g outward'
mut out-builtin                    starchorus-collect.sh fnappend 'builtin curl http://192.0.2.1/' '' '§14.6g outward'
mut out-ok-builtin                 starchorus-collect.sh fnappend 'builtin echo x; builtin cd /tmp; builtin printf "%s\n" x' '' ''
mut sink-watch                     starchorus-collect.sh fnappend 'watch -n 1 "$zz_x"' '' '§14.6h program-text'
mut sink-run-parts                 starchorus-collect.sh fnappend 'run-parts /tmp/zz_d' '' '§14.6h program-text'
mut sink-flock-c                   starchorus-collect.sh fnappend 'flock /tmp/zz_l -c "$zz_x"' '' '§14.6h program-text'
mut sink-flock-c-first             starchorus-collect.sh fnappend 'flock -c "$zz_x" /tmp/zz_l' '' '§14.6h program-text'
mut sink-su-command-eq             starchorus-collect.sh fnappend 'su --command="$zz_x" nobody' '' '§14.6h program-text'
mut sink-su-command-abbrev         starchorus-collect.sh fnappend 'su --comm "$zz_x" nobody' '' '§14.6h program-text'
mut sink-su-session-command        starchorus-collect.sh fnappend 'su --session-command "$zz_x" nobody' '' '§14.6h program-text'
mut sink-runuser-c-glued           starchorus-collect.sh fnappend 'runuser -c"$zz_x" nobody' '' '§14.6h program-text'
mut sink-wrapped-chpst-sh          starchorus-collect.sh fnappend 'chpst -u nobody s''h -c "$zz_x"' '' '§14.6h program-text'
mut sink-limit-sed-e               starchorus-collect.sh fnappend "sed 'e true' /dev/null" '' ''
# the bypass attempts of the same round against the new reading: the applet behind busybox, the expansion behind command, builtin before command, a cluster with -c for flock; `flock --conflict-exit-code` and `ip link show ... up` (a filter) read
mut out-ip-applet-busybox          starchorus-collect.sh fnappend 'busybox iplink set wlan0 down' '' '§14.6g outward'
mut out-verb-expansion-command     starchorus-collect.sh fnappend 'command ip "$zz_v" wlan0 down' '' '§14.6g outward'
mut out-builtin-command            starchorus-collect.sh fnappend 'builtin command curl http://192.0.2.1/' '' '§14.6g outward'
mut sink-flock-c-cluster           starchorus-collect.sh fnappend 'flock -xc "$zz_x" /tmp/zz_l' '' '§14.6h program-text'
mut sink-ok-flock-long             starchorus-collect.sh fnappend 'flock --conflict-exit-code 1 /tmp/zz_l true' '' ''
mut out-ok-expansion-show-filter   starchorus-collect.sh fnappend 'ip link show "$zz_if" up' '' ''
# the third round of the review, second half (26 October 2026): the names OUT_WORDS gained, one family each outside the collector (the alternative probe plants every name in the collector), the page servers that are not route A's one by one
# in the payloads (row 6f reads the docroot of the three only; these are red by name), the same names behind busybox and behind a program that runs its operand, and `bridge`, read by its verbs as `ip` is
mut out-applet-udhcpd              starchorus-display.sh fnappend 'udhcpd /tmp/zz.conf' '' '§14.6g outward'
mut out-applet-busybox-nameif      starchorus-collect.sh fnappend 'busybox nameif -c /tmp/zz.mactab' '' '§14.6g outward'
mut out-flash-flashcp              starchorus-collect.sh fnappend 'flashcp /tmp/zz.bin /dev/mtd3' '' '§14.6g outward'
mut out-scan-mtr                   library/user/reconnaissance/starchorus/payload.sh fnappend 'mtr -r -c 1 192.0.2.1' '' '§14.6g outward'
mut out-mdns-avahi                 starchorus-serve.sh fnappend 'avahi-publish -s zz _http._tcp 80' '' '§14.6g outward'
mut out-ftp-lftp                   starchorus-display.sh fnappend 'lftp 192.0.2.1' '' '§14.6g outward'
mut out-snmp-set                   payload.sh fnappend 'snmpset -v2c -c zz 192.0.2.1 sysName.0 s zz' '' '§14.6g outward'
mut out-at-now                     starchorus-collect.sh fnappend 'echo true | at now' '' '§14.6g outward'
mut out-modem-uqmi                 library/user/reconnaissance/starchorus/payload.sh fnappend 'uqmi -d /dev/cdc-wdm0 --set-device-operating-mode online' '' '§14.6g outward'
mut out-server-lighttpd            library/user/reconnaissance/starchorus/payload.sh fnappend 'lighttpd -f /tmp/zz.conf' '' '§14.6g outward'
mut out-server-nginx               payload.sh fnappend 'nginx -c /tmp/zz.conf' '' '§14.6g outward'
mut out-server-mini-httpd          library/user/reconnaissance/starchorus/payload.sh fnappend 'mini_httpd -p 1 -d /' '' '§14.6f docroot|§14.6g outward'
mut out-server-thttpd              payload.sh fnappend 'thttpd -p 1' '' '§14.6g outward'
mut out-server-darkhttpd           library/user/reconnaissance/starchorus/payload.sh fnappend 'darkhttpd /tmp --port 1' '' '§14.6g outward'
mut out-server-wrapped             library/user/reconnaissance/starchorus/payload.sh fnappend 'flock /tmp/zz_l lighttpd -f /tmp/zz.conf' '' '§14.6g outward'
mut out-bridge-set                 starchorus-collect.sh fnappend 'bridge link set dev eth0 state 0' '' '§14.6g outward'
mut out-bridge-abbrev              starchorus-collect.sh fnappend 'bridge vlan a vid 5 dev eth0' '' '§14.6g outward'
mut out-bridge-batch               starchorus-collect.sh fnappend 'bridge -batch /tmp/zz' '' '§14.6g outward'
mut out-bridge-expansion           starchorus-collect.sh fnappend 'bridge "$zz_v" dev eth0' '' '§14.6g outward'
mut out-ok-bridge-reads            starchorus-collect.sh fnappend 'bridge link show; bridge fdb show; bridge monitor' '' ''
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
mut fnhead-selftest  starchorus-collect.sh     subst    '^selftest() {' 'selftest() { :'                                  '§14.6 scope fill|sqlite3 read-only|§14.6d command words|§14.6h program-text'
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
zz_eof' '' '§14.6e command names|§14.6h program-text'
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
mut probe-fn-continued-bare tools/device-probe.sh fnappend '\
nft() { :; }
nft dev wlan0'                                                                                                          '' 'device-probe.sh programs'
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
# (flipped on 24 October 2026: was a control (the collector is not read for the network words of the probe); the row 6g reads the collector for them now: a mutation, the name stays)
mut probe-limit-collector-curl starchorus-collect.sh fnappend 'curl http://192.0.2.1/' ''                              '§14.6g outward'

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
# (the `iw` of the row 6g lists the commands that read, so the three commands of the transmit row are red there as well since 24 October 2026: tolerated on the same line, the row they prove is the first)
alt iw 'connect'                'iw dev wlan0mon connect x'                       'transmit tools invoked|§14.6g outward'
alt iw 'ibss['                  'iw dev wlan0mon ibss join x 2412'                'transmit tools invoked|§14.6g outward'
alt iw 'mesh['                  'iw dev wlan0mon mesh join x'                     'transmit tools invoked|§14.6g outward'
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
alt bt 'rfkill'                 'rfkill list'                                     '§14.6b Bluetooth words|§14.6g outward'
alt bt 'init\.d/bluetooth'      '/etc/init.d/bluetooth start'                     '§14.6b Bluetooth words|§14.6g outward'
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
alt bt 'blue5ctl'               'blue5ctl status'                                 '§14.6b Bluetooth words'
# btwrap: the wrappers, planted as simple commands inside ONE function of the allowlist (a copy of bt_busy, row Bluetooth wrappers); the three
# words that the guard at the top of this script reads as a command are written with an empty pair of quotes inside them
alt btwrap '^eval'                 'ev''al "$x"'                                      'Bluetooth wrappers|§14.6h program-text'
alt btwrap '^sh[[:space:]]+-c'     'sh -c "x"'                                        'Bluetooth wrappers|§14.6h program-text'
alt btwrap '^ash[[:space:]]+-c'    'ash -c "x"'                                       'Bluetooth wrappers|§14.6h program-text'
alt btwrap '^busybox'              'busybox ls'                                       'Bluetooth wrappers'
alt btwrap '^env'                  'env X=1 true'                                     'Bluetooth wrappers'
alt btwrap '^xargs'                'xargs ls'                                         'Bluetooth wrappers|§14.6h program-text'
alt btwrap '^nohup'                'nohup ls'                                         'Bluetooth wrappers'
alt btwrap '^setsid'               'setsid ls'                                        'Bluetooth wrappers'
alt btwrap '^nice'                 'nice ls'                                          'Bluetooth wrappers'
alt btwrap '^start-stop-daemon'    'start-stop-daemon -S -x /bin/true'                'Bluetooth wrappers'
alt btwrap '^exec'                 'ex''ec true'                                      'Bluetooth wrappers'
alt btwrap '^source'               'sour''ce /tmp/x'                                  'Bluetooth wrappers|§14.6h program-text'
alt btwrap '^time'                 'time ls'                                          'Bluetooth wrappers'
alt btwrap '^\.[[:space:]]'        '. /tmp/x'                                         'Bluetooth wrappers|§14.6h program-text'
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


# out, chg, tcn: the programs of row '§14.6g' (OUT_WORDS), the verbs after which iw, ip and tc change something (CHG_VERBS) and the nouns of tc (TC_NOUNS), each planted as a command in a function of a copy of the collector. A word that is the
# beginning of another alternative (nc and ncat, ping and ping6, ftp and ftpput, ssh and sshd, mail and sendmail) is keyed with a leading = (the whole alternative); the sample of rfkill is red on the Bluetooth row as well
alt out 'curl'             'curl http://192.0.2.1/'                             '§14.6g outward'
alt out '=wget'            'wget http://192.0.2.1/'                             '§14.6g outward'
alt out '=nc'              'nc 192.0.2.1 80'                                    '§14.6g outward'
alt out 'ncat'             'ncat 192.0.2.1 80'                                  '§14.6g outward'
alt out 'netcat'           'netcat 192.0.2.1 80'                                '§14.6g outward'
alt out 'socat'            'socat - TCP:192.0.2.1:80'                           '§14.6g outward'
alt out '=ping'            'ping -c 1 192.0.2.1'                                '§14.6g outward'
alt out 'ping6'            'ping6 -c 1 2001:db8::1'                             '§14.6g outward'
alt out '=traceroute'      'traceroute 192.0.2.1'                               '§14.6g outward'
alt out 'traceroute6'      'traceroute6 2001:db8::1'                            '§14.6g outward'
alt out 'tracepath'        'tracepath 192.0.2.1'                                '§14.6g outward'
alt out '=ssh'             'ssh root@192.0.2.1'                                 '§14.6g outward'
alt out 'scp'              'scp zz root@192.0.2.1:/tmp/'                        '§14.6g outward'
alt out 'sftp'             'sftp root@192.0.2.1'                                '§14.6g outward'
alt out '=telnet'          'telnet 192.0.2.1'                                   '§14.6g outward'
alt out '=ftp'             'ftp 192.0.2.1'                                      '§14.6g outward'
alt out '=ftpput'           'ftpput 192.0.2.1 zz'                                '§14.6g outward'
alt out '=ftpget'           'ftpget 192.0.2.1 zz'                                '§14.6g outward'
alt out '=tftp'             'tftp 192.0.2.1'                                     '§14.6g outward'
alt out 'rsync'            'rsync zz 192.0.2.1::x'                              '§14.6g outward'
alt out 'uci'              'uci set wireless.radio0.disabled=1'                 '§14.6g outward'
alt out 'opkg'             'opkg install zz'                                    '§14.6g outward'
alt out 'iptables'         'iptables -A INPUT -j DROP'                          '§14.6g outward'
alt out 'ip6tables'        'ip6tables -A INPUT -j DROP'                         '§14.6g outward'
alt out 'nft'              'nft add rule inet filter input drop'                '§14.6g outward'
alt out 'dumpcap'          'dumpcap -i wlan1mon'                                '§14.6g outward'
alt out 'tshark'           'tshark -i wlan1mon'                                 '§14.6g outward'
alt out '=service'         'service uhttpd restart'                             '§14.6g outward'
alt out 'reload_config'    'reload_config'                                      '§14.6g outward'
alt out 'wifi'             'wifi down'                                          '§14.6g outward'
alt out 'ubus'             'ubus call network reload'                           '§14.6g outward'
alt out 'pkill'            'pkill uhttpd'                                       '§14.6g outward'
alt out 'killall'          'killall uhttpd'                                     '§14.6g outward'
alt out 'reboot'           'reboot'                                             '§14.6g outward'
alt out 'poweroff'         'poweroff'                                           '§14.6g outward'
alt out 'halt'             'halt'                                               '§14.6g outward'
alt out 'nslookup'         'nslookup example.invalid'                           '§14.6g outward'
alt out 'dig'              'dig example.invalid'                                '§14.6g outward'
alt out '=ntpd'            'ntpd -q -p 192.0.2.1'                               '§14.6g outward'
alt out 'ntpdate'          'ntpdate 192.0.2.1'                                  '§14.6g outward'
alt out 'sendmail'         'sendmail -t'                                        '§14.6g outward'
alt out '=mail'            'mail -s x y'                                        '§14.6g outward'
alt out 'sysctl'           'sysctl -w net.ipv4.ip_forward=1'                    '§14.6g outward'
alt out 'rfkill'             'rfkill list'                                        '§14.6g outward|§14.6b Bluetooth words'
alt out 'modprobe'         'modprobe zz'                                        '§14.6g outward'
alt out 'insmod'           'insmod zz.ko'                                       '§14.6g outward'
alt out 'rmmod'            'rmmod zz'                                           '§14.6g outward'
alt out 'ifup'             'ifup wan'                                           '§14.6g outward'
alt out 'ifdown'           'ifdown wan'                                         '§14.6g outward'
alt out 'iwpriv'           'iwpriv wlan0 zz 1'                                  '§14.6g outward'
alt out '=udhcpc'           'udhcpc -i wlan0'                                    '§14.6g outward'
alt out 'dhclient'         'dhclient wlan0'                                     '§14.6g outward'
alt out 'brctl'            'brctl addbr zz0'                                    '§14.6g outward'
alt out 'swconfig'         'swconfig dev switch0 set reset 1'                   '§14.6g outward'
alt out 'ethtool'          'ethtool -s eth0 speed 10'                           '§14.6g outward'
alt out '=iperf'           'iperf -c 192.0.2.1'                                 '§14.6g outward'
alt out 'iperf3'           'iperf3 -c 192.0.2.1'                                '§14.6g outward'
alt out 'lynx'             'lynx http://192.0.2.1/'                             '§14.6g outward'
alt out 'w3m'              'w3m http://192.0.2.1/'                              '§14.6g outward'
alt out 'elinks'           'elinks http://192.0.2.1/'                           '§14.6g outward'
alt out 'aria2c'           'aria2c http://192.0.2.1/'                           '§14.6g outward'
alt out 'axel'             'axel http://192.0.2.1/'                             '§14.6g outward'
alt out 'wget2'            'wget2 http://192.0.2.1/'                            '§14.6g outward'
alt out 'nping'            'nping 192.0.2.1'                                    '§14.6g outward'
alt out 'tcpsvd'           'tcpsvd 0.0.0.0 9 true'                              '§14.6g outward'
alt out 'udpsvd'           'udpsvd 0.0.0.0 9 true'                              '§14.6g outward'
alt out 'telnetd'          'telnetd -l /bin/true'                               '§14.6g outward'
alt out '=ftpd'             'ftpd /tmp'                                          '§14.6g outward'
alt out 'dropbear'         'dropbear -p 22'                                     '§14.6g outward'
alt out 'sshd'             'sshd -D'                                            '§14.6g outward'
alt out 'rdate'            'rdate 192.0.2.1'                                    '§14.6g outward'
alt out 'crontab'           'crontab -l'                                         '§14.6g outward'
alt out 'uclient-fetch'     'uclient-fetch http://192.0.2.1/'                    '§14.6g outward'
alt out 'ntpclient'         'ntpclient -s -h 192.0.2.1'                          '§14.6g outward'
alt out 'dnsmasq'           'dnsmasq -k'                                         '§14.6g outward'
alt out '=dhcpd'             'dhcpd -f'                                           '§14.6g outward'
alt out 'dbclient'          'dbclient root@192.0.2.1'                            '§14.6g outward'
alt out 'ether-wake'        'ether-wake 00:11:22:33:44:55'                       '§14.6g outward'
alt out 'etherwake'         'etherwake 00:11:22:33:44:55'                        '§14.6g outward'
alt out 'whois'             'whois example.invalid'                              '§14.6g outward'
alt out 'openssl'           'openssl s_client -connect 192.0.2.1:443'            '§14.6g outward'
alt out '=host'             'host example.invalid'                               '§14.6g outward'
alt out 'nsupdate'          'nsupdate -k /tmp/zz_key'                            '§14.6g outward'
alt out 'mosquitto_pub'     'mosquitto_pub -h 192.0.2.1 -t zz -m zz'             '§14.6g outward'
alt out 'mosquitto_sub'     'mosquitto_sub -h 192.0.2.1 -t zz'                   '§14.6g outward'
alt out 'fw3'               'fw3 reload'                                         '§14.6g outward'
alt out 'fw4'               'fw4 reload'                                         '§14.6g outward'
alt out '=mtd'              'mtd write /tmp/zz_img firmware'                     '§14.6g outward'
alt out 'sysupgrade'        'sysupgrade -n /tmp/zz_img'                          '§14.6g outward'
alt out 'firstboot'         'firstboot -y'                                       '§14.6g outward'
alt out 'fw_setenv'         'fw_setenv zz_a zz_b'                                '§14.6g outward'
alt out 'devmem'            'devmem 0x10000000 32 1'                             '§14.6g outward'
alt out 'i2cset'            'i2cset -y 0 0x50 0 1'                               '§14.6g outward'
alt out '=mount'            'mount -t nfs 192.0.2.1:/zz /mnt'                    '§14.6g outward'
alt out 'umount'            'umount /mnt'                                        '§14.6g outward'
alt out 'hwclock'           'hwclock -w'                                         '§14.6g outward'
alt out 'chronyd'           'chronyd -q'                                         '§14.6g outward'
alt out 'chronyc'           'chronyc makestep'                                   '§14.6g outward'
alt out 'sntp'              'sntp -s 192.0.2.1'                                  '§14.6g outward'
alt out 'htpdate'           'htpdate -s 192.0.2.1'                               '§14.6g outward'
alt out 'macchanger'         'macchanger -r wlan0'                                '§14.6g outward'
alt out '=wl'               'wl up'                                              '§14.6g outward'
alt out 'nvram'             'nvram set zz=1'                                     '§14.6g outward'
alt out 'blue5'             'blue5 start'                                        '§14.6g outward'
alt out 'wlanconfig'        'wlanconfig ath0 create wlandev wifi0'               '§14.6g outward'
alt out 'vconfig'           'vconfig add eth0 5'                                 '§14.6g outward'
alt out 'ifenslave'         'ifenslave bond0 eth0'                               '§14.6g outward'
alt out 'batctl'            'batctl if add eth0'                                 '§14.6g outward'
alt out 'tunctl'            'tunctl -t zz0'                                      '§14.6g outward'
# the third round of the review (26 October 2026): BusyBox's other network applets and flash writers, the scanners, the mDNS tools, the other ftp clients, SNMP, at and batch, the modem tools and the page servers that are not route A's
alt out '=dnsd'              'dnsd -c /tmp/zz.conf'                               '§14.6g outward'
alt out 'fakeidentd'         'fakeidentd -b 0.0.0.0'                              '§14.6g outward'
alt out 'ifplugd'            'ifplugd -i eth0'                                    '§14.6g outward'
alt out 'nameif'             'nameif -c /tmp/zz.mactab'                             '§14.6g outward'
alt out 'nbd-client'         'nbd-client 192.0.2.1 10809 /dev/nbd0'               '§14.6g outward'
alt out 'pscan'              'pscan 192.0.2.1'                                    '§14.6g outward'
alt out 'slattach'           'slattach -p slip /dev/ttyS0'                        '§14.6g outward'
alt out 'ssl_client'         'ssl_client -s 3'                                    '§14.6g outward'
alt out '=tftpd'             'tftpd -c /tmp'                                      '§14.6g outward'
alt out 'udhcpc6'            'udhcpc6 -i wlan0'                                   '§14.6g outward'
alt out '=udhcpd'            'udhcpd /tmp/zz.conf'                                '§14.6g outward'
alt out 'zcip'               'zcip eth0 /bin/true'                                '§14.6g outward'
alt out '=inetd'             'inetd /tmp/zz.conf'                                 '§14.6g outward'
alt out 'flashcp'            'flashcp /tmp/zz.bin /dev/mtd3'                      '§14.6g outward'
alt out 'flash_eraseall'     'flash_eraseall /dev/mtd3'                           '§14.6g outward'
alt out 'flash_lock'         'flash_lock /dev/mtd3'                               '§14.6g outward'
alt out 'flash_unlock'       'flash_unlock /dev/mtd3'                             '§14.6g outward'
alt out 'nandwrite'          'nandwrite /dev/mtd3 /tmp/zz.bin'                    '§14.6g outward'
alt out '=mtr'               'mtr -r 192.0.2.1'                                   '§14.6g outward'
alt out 'fping'              'fping 192.0.2.1'                                    '§14.6g outward'
alt out 'arp-scan'           'arp-scan -l'                                        '§14.6g outward'
alt out 'masscan'            'masscan 192.0.2.0/24 -p80'                          '§14.6g outward'
alt out 'zmap'               'zmap -p 80'                                         '§14.6g outward'
alt out '=avahi-publish'     'avahi-publish -s zz _http._tcp 80'                  '§14.6g outward'
alt out 'avahi-publish-service' 'avahi-publish-service zz _http._tcp 80'             '§14.6g outward'
alt out 'avahi-publish-address' 'avahi-publish-address zz.local 192.0.2.7'           '§14.6g outward'
alt out 'avahi-browse'       'avahi-browse -a'                                    '§14.6g outward'
alt out 'avahi-resolve'      'avahi-resolve -n zz.local'                          '§14.6g outward'
alt out 'avahi-daemon'       'avahi-daemon -D'                                    '§14.6g outward'
alt out 'avahi-set-host-name' 'avahi-set-host-name zz'                             '§14.6g outward'
alt out 'umdns'              'umdns'                                              '§14.6g outward'
alt out 'lftp'               'lftp 192.0.2.1'                                     '§14.6g outward'
alt out '=ncftp'             'ncftp 192.0.2.1'                                    '§14.6g outward'
alt out 'ncftpput'           'ncftpput 192.0.2.1 / /tmp/zz'                       '§14.6g outward'
alt out 'ncftpget'           'ncftpget 192.0.2.1 /tmp zz'                         '§14.6g outward'
alt out 'snmpget'            'snmpget -v2c -c public 192.0.2.1 sysName.0'         '§14.6g outward'
alt out 'snmpset'            'snmpset -v2c -c private 192.0.2.1 sysName.0 s zz'   '§14.6g outward'
alt out '=snmpwalk'          'snmpwalk -v2c -c public 192.0.2.1'                  '§14.6g outward'
alt out 'snmpbulkwalk'       'snmpbulkwalk -v2c -c public 192.0.2.1'              '§14.6g outward'
alt out 'snmptrap'           'snmptrap -v2c -c public 192.0.2.1 '\'''\'' 1.3.6.1' '§14.6g outward'
alt out '=snmpd'             'snmpd -f'                                           '§14.6g outward'
alt out '=at'                'at now'                                             '§14.6g outward'
alt out '=batch'             'batch'                                              '§14.6g outward'
alt out 'pppd'               'pppd call zz'                                       '§14.6g outward'
alt out 'uqmi'               'uqmi -d /dev/cdc-wdm0 --get-signal-info'            '§14.6g outward'
alt out 'qmicli'             'qmicli -d /dev/cdc-wdm0 --nas-get-signal-info'      '§14.6g outward'
alt out 'mmcli'              'mmcli -L'                                           '§14.6g outward'
alt out 'comgt'              'comgt -d /dev/ttyUSB2 sig'                          '§14.6g outward'
alt out 'gcom'               'gcom -d /dev/ttyUSB2 sig'                           '§14.6g outward'
alt out 'lighttpd'           'lighttpd -f /tmp/zz.conf'                           '§14.6g outward'
alt out 'nginx'              'nginx -c /tmp/zz.conf'                              '§14.6g outward'
alt out 'mini_httpd'         'mini_httpd -p 1'                                    '§14.6g outward'
alt out 'thttpd'             'thttpd -p 1'                                        '§14.6g outward'
alt out 'darkhttpd'          'darkhttpd /tmp'                                     '§14.6g outward'
alt chg 'set'              'ip link set wlan1mon down'                          '§14.6g outward'
alt chg 'add'              'iw phy phy0 interface add zz0 type monitor'         '§14.6g outward'
alt chg '=del'             'ip link del zz0'                                    '§14.6g outward'
alt chg 'delete'           'ip addr delete 192.0.2.7/24 dev wlan0'              '§14.6g outward'
alt chg 'flush'            'ip route flush table main'                          '§14.6g outward'
alt chg 'change'           'ip route change default dev wlan0'                  '§14.6g outward'
alt chg 'replace'          'ip route replace default dev wlan0'                 '§14.6g outward'
alt chg 'append'           'ip route append default dev wlan0'                  '§14.6g outward'
alt chg 'prepend'          'ip route prepend default dev wlan0'                 '§14.6g outward'
alt chg 'disconnect'       'iw dev wlan0 disconnect'                            '§14.6g outward'
alt chg 'exec'             'ip netns ex''ec zz true'                            '§14.6g outward'
alt chg 'restore'          'ip addr restore'                                    '§14.6g outward'
alt tcn 'qdisc'            'tc qdisc show dev wlan0'                            '§14.6g outward'
alt tcn 'class'            'tc class show dev wlan0'                            '§14.6g outward'
alt tcn 'filter'           'tc filter show dev wlan0'                           '§14.6g outward'

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
min_alts() { case $1 in netsurf) echo "$MIN_ALTS_NETSURF";; netx) echo "$MIN_ALTS_NETX";; tx) echo "$MIN_ALTS_TX";; iw) echo "$MIN_ALTS_IW";; bt) echo "$MIN_ALTS_BT";; btwrap) echo "$MIN_ALTS_BTWRAP";; pnet) echo "$MIN_ALTS_PNET";; out) echo "$MIN_ALTS_OUT";; chg) echo "$MIN_ALTS_CHG";; tcn) echo "$MIN_ALTS_TCN";; *) echo "$MIN_ALTS_SEC6";; esac; }
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
  for _spec in netsurf:NETSURF_RE netx:NETX tx:TX_WORDS iw:IW_VERBS sec6:SEC6_RE bt:BT_WORDS btwrap:BT_WRAP_RE pnet:PNET_WORDS out:OUT_WORDS chg:CHG_VERBS tcn:TC_NOUNS; do
    _fam=${_spec%%:*}; _var=${_spec#*:}
    _re=$(awk -F'\t' -v N="$_var" '$1 == N { print $2; exit }' "$tmp/rx")
    split_alts "$_re" > "$tmp/alts.$_fam"; _n=$(grep -c '' "$tmp/alts.$_fam")
    nafam=$((nafam + 1)); naderived=$((naderived + _n))
    # a sample is read with the boundaries its family has in the checker (a word of TX_WORDS or BT_WORDS stands between characters that are no part of a name: hostapd_cli is no hostapd)
    case $_fam in tx) _pre='(^|[^A-Za-z0-9_-])('; _suf=')([^A-Za-z0-9_]|$)' ;; bt|pnet|out|chg|tcn) _pre='(^|[^A-Za-z0-9_-])('; _suf=')([^A-Za-z0-9_-]|$)' ;; *) _pre='('; _suf=')' ;; esac
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
  run_group starchorus-collect.sh fn 'out chg tcn'
  printf 'alternatives: %s/%s planted samples red on their row (%s families, %s alternatives derived), %s uncovered, %s blind, %s wrong-row\n' "$naok" "$na" "$nafam" "$naderived" "$nauncov" "$nablind" "$nawrong"
}
alt_ok() { [ "$na" -ge 1 ] && [ "$naok" = "$na" ] && [ "$nauncov" = 0 ] && [ "$nablind" = 0 ] && [ "$nawrong" = 0 ] && [ "$nasetup" = 0 ]; }

if [ "$sel" = alts ]; then alt_probe; alt_ok; exit $?; fi
if [ -n "$sel" ]; then
  [ "$seen_sel" = 1 ] || { echo "passivity-mutate: no mutation named $sel" >&2; exit 2; }
  [ "$nsetup" = 0 ] && [ "$ngreen" = 0 ] && [ "$nwrong" = 0 ]; exit $?
fi
if [ "$SHARD_N" -gt 0 ]; then job 1 alt_probe; shard_end; exit 0; fi   # a shard of the default run: the alternative probe is one (long) entry, then its sums; the merge judges them
if [ "$MERGE" = 1 ]; then merge_run "$@" || exit 1; else alt_probe; fi

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
