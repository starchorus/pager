# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/mutation-probe.sh -- the passivity checker has to be able to say no.
# GUARDS AGAINST: a rule of passivity-check.sh that drifted, was emptied or lost ONE alternative of its regex (importScripts,
#                 hostapd, DEAUTH, sendBeacon ...) stays green, because nothing ever plants a violation.
# NEGATIVE PROBE: `window\.open\(|` taken from NETX, the object prefix of the location alternative, one
#                 alternative each from NETX/TX_WORDS/SEC6_RE/NETSURF_RE/BT_WORDS/BT_WRAP_RE, the evidence lines of a family, switching the
#                 sqlite3 rule to whole-line reading, each Bluetooth row (tool words outside the allowlist, the lines of bt_begin, word forms,
#                 wrappers, command position, the pinned apcli_ro lines) to reading nothing => "GREEN (BLIND!)", exit 1, these rows red; the same for the
#                 row of the built names (§14.6d command words from an expansion): the row, its detection, its wrapper words, the report of a new line and of a vanished pin;
#                 its second row (§14.6e command names from a glob, find -exec, xargs or alias): the row, the glob test, each of find's options, the placeholder and the
#                 missing command of xargs, the alias, the end of a case pattern and the `${ }` state (their controls go red), a quoted wrapper; the pinned lines of the
#                 transmit row (the row, a vanished pin, a pin that covers every copy) and three of the new alternatives (`--meta`, one image each); the three rows of the device probe (tools/device-probe.sh,
#                 which runs on the device: its scope fill, its 'named tools' with a pinned list of lines, its 'programs'): a sending, scanning, Bluetooth or network tool, an `iw` that sets something, a built or
#                 globbed command word, a program no list names, an edited, a vanished and a copied pinned line, `date -s`, `sed -i` and `sort -o`, every spelling of a write outside /dev/null and the private directory (redirections of every form, the destination of cp, mv and tee, the assignment of T and OUT), a function that hands `command` a program of its own name and a command before a `case` on the same line, the action of a `trap` that runs a string, a case inside a group on a body line of an open case, an expansion after `$T/` and a call of `vset` that is not given digits, a here-document whose delimiter has a quote in the middle or whose bare-delimiter body is expanded, `command run_limited`, the floor of write targets read, a `name() { :; }` planted where it defines nothing (in a here-document body, a string or a comment) with a call of that name or a `trap` that names it, a function head or closing brace in such a text that gave the pins another function, a line that looks like a comment inside a string, a bare here-document or after a backslash, a head inside a function, a line with two here-documents of which the first is bare, each part of the rows blinded once, and the family of network words (`alt pnet`); and for the collector, both Overview copies, both payload.sh, the listener and library/, which the same reader now reads whole: a head in a here-document body or a string with a device call, a word of the Bluetooth stack or a built name behind it (`main-head-`), a comment-looking line in a string, a here-document or after a backslash (`main-comment-`), a head inside a function (`main-nested-`, `main-brace-indented`), a built name or a glob in the body of a bare here-document and with two here-documents on a line (`main-heredoc-`, `main-two-heredocs`), the default and the guard of the `iw scan` opt-in behind a comment sign, moved or copied (`main-iw-`), a built name or a glob below a function head in a here-document body, quoted or bare, or in a string, also in a body nested in it and in the handler that the listener writes (`main-script-`; the part before the first head stays text), and a here-document delimiter that is not a plain name (`main-odd-delimiter`), each of those parts blinded once. Mutations that wait for lines of the collector's Bluetooth code are PENDING (listed, not red) until they exist.
#                 (as of 24 October 2026) the rows §14.6g (outward and state-changing programs) and §14.6h (program-text sinks) and the launch rule of §14.6f: for each the row, the name test, each verb list,
#                 the second rule (a write into /sys, /proc/sys or a device file), the wrappers with a path or an option that takes a word, the programs that run their operand, the escaped newline in a
#                 word, the name that is not spelled in one piece, the reader of the shells, of find, of the interpreters and of an exec of a built word, the system( rule, both floors, the comparison with the
#                 pins and the message exemption of the docroot row => "GREEN (BLIND!)", and the alternatives of the three new word lists (347 alternatives in all as of 26 October 2026). The review of the same day (round two) adds the prefix reading of the verbs of `ip` and `tc`, the commands of `iw` that read, the action of a `trap`, the awk command pipes, the shells and interpreters that read their program from the standard input or a file, the programs that run their operand, the path rule of §14.6h and the launch rules of §14.6f: each is blinded once as well.
# NOT PROVEN:     proves only that the source guard bites, not the behaviour of the running page (that is net-runtime.sh); one
#                 example per alternative, not every spelling (header of tools/passivity-mutate.sh).
# Sourced by tools/regress.sh with cwd = repo root; chrome-free (tools/quick.sh sources it too when QUICK_MUTATE=1, which the hook sets when the checker or this probe is staged). The probe is about 1,400
# independent checker runs of 3 to 4 s of one core each (the mutations, the images of --meta, the alternatives), and it is cut into SHARDS (tools/passivity-mutate.sh --shard I/N): N shards of the default run and M of --meta, all started at the same time into out/PREFIX-pmut.I and out/PREFIX-pmeta.J. N+M is the size of the pool:
# STARCHORUS_MUTATE_JOBS (digits, 1 to 64), by default the number of CPUs less two, at most ten (a checker run starts its own helpers, so the gain flattens near eight: on 14 cores 20 runs took 79 s one at a
# time, 41 s two, 21 s four, 13 s eight and 10 s twelve at a time). The images of --meta are as much work as the mutations all told (a child run is a checker run with preliminaries of its own, and nineteen of
# them run the alternative probe, 84 s each), so the pool is cut in halves and the odd shard goes to --meta; STARCHORUS_MUTATE_JOBS=1 runs the two modes one after the other. The shards share nothing but the
# files they are started from; each has its own temporary directory. Then one merge per mode (--merge, and --meta --merge) writes out/PREFIX-pmut.txt and out/PREFIX-pmeta.txt, which the two rows below read exactly as
# before: the same lines in the order of the tables, the same summaries, the same exit statuses. A shard that is missing or was cut short, or shards that do not add up, make the merge red (never green with fewer
# entries). Measured on 30 October 2026 on 14 cores with the default ten shards: 956 s (16 minutes); the main shards took 810 to 917 s (the alternative probe is the long entry of one of them), the --meta shards 851 to 952 s.
# The two halves it replaced took 3,939 s and 4,349 s on the same machine (the longer one was --meta).
# MEMO:           the probe is a pure function of its inputs, so a run whose inputs are those of the last GREEN run is not repeated: the stored lines are written to out/PREFIX-pmut.txt and out/PREFIX-pmeta.txt under a leading
#                 note ("not rerun") and the rows are judged on them as on a fresh run (a "note:" line says so in the transcript too). The memo is out/mutation-memo (STARCHORUS_MUTATE_MEMO_DIR); its key is the SHA-256
#                 over the bytes of this drop-in, tools/passivity-mutate.sh and tools/passivity-check.sh, the page, tools/denylist-check.sh with its three lists, every file of the shell scope and the device probe as the checker
#                 lists them (`sh tools/passivity-check.sh --files`: the resolved glob of library/ and each of its files), and over the programs that run them (the path and checksum of sh, awk, grep, sed ... and uname -srvm).
#                 Any doubt runs the probe in full: an input that changed, vanished, is no plain file or cannot be hashed, no memo or a damaged one (the stored lines are hashed too), a memo made by another version of
#                 the probe (this drop-in is an input, so any change to it is one), STARCHORUS_MUTATE_FRESH set (anything but 0), no tool for SHA-256, or a list of inputs that the checker does not bear out (in a copy that
#                 holds only the listed files it has to say what it says in the repository, checked on every full run). A red run is never stored, nor one whose inputs changed while it ran.
# A shell starts a background job with SIGINT ignored, which the job cannot take back, so Ctrl-C would stop this script and leave the shards running for
# some ten minutes (in the hook, in an export that is already removed). While it waits, this script therefore passes INT and TERM on to every shard as TERM, which
# they trap (their temporary directories go), waits for them to end, and exits 130; the traps are cleared again once they have ended.
# Only MUT_* names are set (the functions of this file are mut_*).
MUT_out="out/$P-pmut.txt"; MUT_outm="out/$P-pmeta.txt"
MUT_memo=${STARCHORUS_MUTATE_MEMO_DIR:-out/mutation-memo}
MUT_fmt=1        # the version of the memo's layout; it is part of the key
MUT_abs=$(pwd -P)

# ---- the memo
mut_h256() {   # the SHA-256 of the files named, in the lines that sha256sum prints; of the standard input when none is named; 1 when this machine has no tool for it
  if command -v sha256sum > /dev/null 2>&1; then sha256sum "$@"
  elif command -v shasum > /dev/null 2>&1; then shasum -a 256 "$@"
  else return 1; fi
}
mut_manifest() {   # the text whose hash is the key: the version of the memo, the hash of every input, the programs that run them; 1 when an input is no plain file, is missing or cannot be hashed
  printf 'starchorus-mutation-probe-memo %s\n' "$MUT_fmt"
  sh tools/passivity-check.sh --files > "out/$P-pmut-scope.txt" 2> /dev/null || return 1
  { printf '%s\n' tools/regress.d/mutation-probe.sh tools/passivity-mutate.sh tools/passivity-check.sh starchorus.html tools/denylist-check.sh tools/denylist.txt tools/denylist-words.txt tools/denylist-cs.txt
    cat "out/$P-pmut-scope.txt"; } | LC_ALL=C sort -u > "out/$P-pmut-inputs.txt" || return 1
  [ "$(wc -l < "out/$P-pmut-inputs.txt" | tr -d ' ')" -ge 12 ] || return 1
  while IFS= read -r MUT_f; do
    { [ -f "$MUT_f" ] && [ ! -L "$MUT_f" ]; } || return 1
    mut_h256 "$MUT_f" || return 1
  done < "out/$P-pmut-inputs.txt"
  for MUT_t in sh awk grep sed sort find cp mv rm mkdir mktemp cat cut tr head tail wc cmp diff date basename dirname; do
    MUT_pp=$(command -v "$MUT_t" 2> /dev/null) || MUT_pp=""
    case $MUT_pp in /*) printf 'tool %s %s %s\n' "$MUT_t" "$MUT_pp" "$(cksum < "$MUT_pp" 2> /dev/null)" ;; *) printf 'tool %s %s\n' "$MUT_t" "${MUT_pp:-missing}" ;; esac
  done
  printf 'os %s\n' "$(uname -srvm)"
}
mut_keyof() {   # mut_keyof FILE: writes the manifest to FILE and the SHA-256 of it into MUT_k; 1 when that cannot be done
  mut_manifest > "$1" 2> /dev/null || return 1
  MUT_k=$(mut_h256 < "$1") || return 1
  MUT_k=${MUT_k%% *}
  case $MUT_k in *[!0-9a-f]*) return 1 ;; esac
  [ "${#MUT_k}" = 64 ]
}
mut_lookup() {   # 0 when the memo holds the result for exactly the inputs of MUT_key: the two reports are written, under a note; else MUT_why says why not
  MUT_why="no stored result"
  [ -f "$MUT_memo/entry" ] || return 1
  MUT_why="the stored entry is damaged"
  { read -r MUT_l1 && read -r MUT_l2 && read -r MUT_l3 && read -r MUT_l4 && read -r MUT_l5 && read -r MUT_l6; } < "$MUT_memo/entry" || return 1
  if [ "$MUT_l1" != "starchorus-mutation-probe-memo $MUT_fmt" ]; then MUT_why="the stored result was made by another version of the probe"; return 1; fi
  if [ "$MUT_l2" != "key $MUT_key" ]; then
    MUT_why="inputs changed"
    if [ -f "$MUT_memo/manifest" ]; then
      MUT_chg=$(diff "$MUT_memo/manifest" "out/$P-pmut-manifest.txt" | awk 'NF == 3 && ($1 == "<" || $1 == ">") && length($2) == 64 { print $3 }' | LC_ALL=C sort -u | head -n 6 | tr '\n' ' ')
      MUT_why="inputs changed: ${MUT_chg:-the programs or the system}"
    fi
    return 1
  fi
  [ -f "$MUT_memo/main.out" ] && [ -f "$MUT_memo/meta.out" ] || return 1
  MUT_hm=$(mut_h256 < "$MUT_memo/main.out") || return 1; MUT_hx=$(mut_h256 < "$MUT_memo/meta.out") || return 1
  [ "main ${MUT_hm%% *}" = "$MUT_l3" ] && [ "meta ${MUT_hx%% *}" = "$MUT_l4" ] || return 1
  [ "$(grep -c '^passivity mutation probe: [0-9]' "$MUT_memo/main.out")" = 1 ] && [ "$(grep -c '^passivity meta probe: [0-9]' "$MUT_memo/meta.out")" = 1 ] || return 1
  MUT_note="mutation probe: unchanged inputs since $(printf '%.12s' "$MUT_key"); verdicts replayed from $MUT_memo, not rerun (stored by the run of ${MUT_l5#when }, ${MUT_l6#secs } s)"
  { printf '%s\n' "$MUT_note"; cat "$MUT_memo/main.out"; } > "$MUT_out" || return 1
  { printf '%s\n' "$MUT_note"; cat "$MUT_memo/meta.out"; } > "$MUT_outm" || return 1
  MUT_why=""
}
mut_store() {   # keeps the reports of this run for the next run with the same inputs; 1, and nothing kept, when it must not (an input changed meanwhile, no tool, no room)
  mut_keyof "out/$P-pmut-manifest2.txt" || return 1
  [ "$MUT_k" = "$MUT_key" ] || return 1
  MUT_new="$MUT_memo.new.$$"; rm -rf "$MUT_new"; mkdir -p "$MUT_new" || return 1
  if ! { cp "out/$P-pmut-manifest.txt" "$MUT_new/manifest" && cp "$MUT_out" "$MUT_new/main.out" && cp "$MUT_outm" "$MUT_new/meta.out"; }; then rm -rf "$MUT_new"; return 1; fi
  if ! { MUT_hm=$(mut_h256 < "$MUT_new/main.out") && MUT_hx=$(mut_h256 < "$MUT_new/meta.out"); }; then rm -rf "$MUT_new"; return 1; fi
  { printf 'starchorus-mutation-probe-memo %s\n' "$MUT_fmt"; printf 'key %s\n' "$MUT_key"; printf 'main %s\n' "${MUT_hm%% *}"; printf 'meta %s\n' "${MUT_hx%% *}"
    printf 'when %s\n' "$(date '+%Y-%m-%d %H:%M')"; printf 'secs %s\n' "$MUT_secs"; } > "$MUT_new/entry" || { rm -rf "$MUT_new"; return 1; }
  rm -rf "$MUT_memo.old"
  if [ -e "$MUT_memo" ]; then mv "$MUT_memo" "$MUT_memo.old" || { rm -rf "$MUT_new"; return 1; }; fi
  mv "$MUT_new" "$MUT_memo" || { rm -rf "$MUT_new"; return 1; }
  rm -rf "$MUT_memo.old"
}

# ---- the size of the pool: STARCHORUS_MUTATE_JOBS (digits, 1 to 64), else the number of CPUs less two, at most ten, at least one
MUT_bad=""
if [ -n "${STARCHORUS_MUTATE_JOBS:-}" ]; then
  MUT_p=$STARCHORUS_MUTATE_JOBS
  case $MUT_p in
    *[!0-9]*|???*) MUT_bad=$STARCHORUS_MUTATE_JOBS ;;
    *) MUT_p=${MUT_p#0}; MUT_p=${MUT_p:-0}; { [ "$MUT_p" -ge 1 ] && [ "$MUT_p" -le 64 ]; } || MUT_bad=$STARCHORUS_MUTATE_JOBS ;;
  esac
else
  MUT_p=$(getconf _NPROCESSORS_ONLN 2> /dev/null) || MUT_p=""
  case $MUT_p in ''|*[!0-9]*) MUT_p=$(sysctl -n hw.ncpu 2> /dev/null) || MUT_p="" ;; esac
  case $MUT_p in ''|*[!0-9]*) MUT_p=$(nproc 2> /dev/null) || MUT_p="" ;; esac
  case $MUT_p in ''|*[!0-9]*) MUT_p=4 ;; esac
  MUT_p=$((MUT_p - 2)); [ "$MUT_p" -le 10 ] || MUT_p=10; [ "$MUT_p" -ge 1 ] || MUT_p=1
fi
if [ -n "$MUT_bad" ]; then
  row "passivity mutation probe: STARCHORUS_MUTATE_JOBS is \"$MUT_bad\", want digits from 1 to 64 (nothing was run)" FAIL
else
  # half and half, the odd shard to --meta; with one the two modes run one after the other
  if [ "$MUT_p" -ge 2 ]; then
    MUT_m=$(((MUT_p * 52 + 50) / 100)); [ "$MUT_m" -ge 1 ] || MUT_m=1; [ "$MUT_m" -le $((MUT_p - 1)) ] || MUT_m=$((MUT_p - 1))
    MUT_n=$((MUT_p - MUT_m)); MUT_seq=0
  else MUT_n=1; MUT_m=1; MUT_seq=1; fi

  # ---- the memo: the key of the inputs, and the stored result when it is the one of these inputs
  MUT_key=""; MUT_note=""; MUT_why=""; MUT_hit=0; MUT_t0=$(date +%s)
  if mut_keyof "out/$P-pmut-manifest.txt"; then MUT_key=$MUT_k; else MUT_why="the inputs cannot be listed or hashed (an input is no plain file, or there is no sha256sum or shasum)"; fi
  case ${STARCHORUS_MUTATE_FRESH:-} in
    ''|0) if [ -n "$MUT_key" ] && mut_lookup; then MUT_hit=1; fi ;;
    *) MUT_why="STARCHORUS_MUTATE_FRESH is set" ;;
  esac

  if [ "$MUT_hit" = 1 ]; then
    MUT_rc=0; MUT_rcm=0
    echo "note: $MUT_note"
  else
    echo "note: mutation probe: full run in $MUT_n + $MUT_m shards (${MUT_why:-no reason given})"
    # ---- the shards. The proof that the list of inputs is complete runs beside them: the checker in the repository and in a copy that holds only the listed files
    MUT_pids=""; MUT_proof=0
    trap 'kill $MUT_pids 2>/dev/null; wait $MUT_pids 2>/dev/null; trap - INT TERM; exit 130' INT TERM
    # nothing of an earlier run may be mistaken for a result of this one (a shard that never started would leave its old file behind)
    rm -f "out/$P-pmut."[0-9]* "out/$P-pmeta."[0-9]* "out/$P-pmut-ref.txt" "out/$P-pmut-ref.rc" "out/$P-pmut-pruned.txt" "out/$P-pmut-pruned.rc"
    if [ -n "$MUT_key" ]; then
      MUT_pd="out/$P-pmut-pruned"; rm -rf "$MUT_pd"; mkdir -p "$MUT_pd" && MUT_proof=1
      while IFS= read -r MUT_f; do
        case $MUT_f in tools/passivity-mutate.sh|tools/regress.d/mutation-probe.sh) continue ;; esac   # the probe itself is no input of the checker
        mkdir -p "$MUT_pd/$(dirname "$MUT_f")" && cp "$MUT_f" "$MUT_pd/$MUT_f" || MUT_proof=0
      done < "out/$P-pmut-inputs.txt"
    fi
    MUT_i=0
    while [ "$MUT_i" -lt "$MUT_n" ]; do
      sh tools/passivity-mutate.sh --shard "$MUT_i/$MUT_n" > "out/$P-pmut.$MUT_i" 2>&1 & MUT_pids="$MUT_pids $!"
      MUT_i=$((MUT_i + 1))
    done
    if [ "$MUT_seq" = 1 ]; then
      # shellcheck disable=SC2086   # a word list of process ids on purpose
      wait $MUT_pids; MUT_pids=""
    fi
    MUT_i=0
    while [ "$MUT_i" -lt "$MUT_m" ]; do
      sh tools/passivity-mutate.sh --meta --shard "$MUT_i/$MUT_m" > "out/$P-pmeta.$MUT_i" 2>&1 & MUT_pids="$MUT_pids $!"
      MUT_i=$((MUT_i + 1))
    done
    if [ "$MUT_proof" = 1 ]; then
      ( sh tools/passivity-check.sh > "out/$P-pmut-ref.txt" 2>&1; echo $? > "out/$P-pmut-ref.rc" ) & MUT_pids="$MUT_pids $!"
      ( cd "$MUT_pd" && sh tools/passivity-check.sh > "$MUT_abs/out/$P-pmut-pruned.txt" 2>&1; echo $? > "$MUT_abs/out/$P-pmut-pruned.rc" ) & MUT_pids="$MUT_pids $!"
    fi
    for MUT_x in $MUT_pids; do wait "$MUT_x"; done
    trap - INT TERM
    # ---- one merge per mode
    MUT_f=""; MUT_i=0; while [ "$MUT_i" -lt "$MUT_n" ]; do MUT_f="$MUT_f out/$P-pmut.$MUT_i"; MUT_i=$((MUT_i + 1)); done
    # shellcheck disable=SC2086   # a word list of file names on purpose (none has a blank in it)
    sh tools/passivity-mutate.sh --merge $MUT_f > "$MUT_out" 2>&1; MUT_rc=$?
    MUT_f=""; MUT_i=0; while [ "$MUT_i" -lt "$MUT_m" ]; do MUT_f="$MUT_f out/$P-pmeta.$MUT_i"; MUT_i=$((MUT_i + 1)); done
    # shellcheck disable=SC2086
    sh tools/passivity-mutate.sh --meta --merge $MUT_f > "$MUT_outm" 2>&1; MUT_rcm=$?
    # ---- keep the result when it is green, the list of inputs is borne out and nothing changed meanwhile
    MUT_secs=$(($(date +%s) - MUT_t0))
    if [ "$MUT_rc" = 0 ] && [ "$MUT_rcm" = 0 ] && [ -n "$MUT_key" ]; then
      if [ "$MUT_proof" = 1 ] && cmp -s "out/$P-pmut-ref.txt" "out/$P-pmut-pruned.txt" && [ "$(cat "out/$P-pmut-ref.rc")" = "$(cat "out/$P-pmut-pruned.rc")" ]; then
        mut_store || echo "note: mutation probe: the result was not stored (an input changed while it ran, or there was no room)"
      else echo "note: mutation probe: the result was not stored (the checker does not say the same in a copy that holds only the listed inputs, or the proof could not run)"; fi
    fi
    [ -z "${MUT_pd:-}" ] || rm -rf "$MUT_pd"
  fi

  # ---- the rows, from the two reports
  MUT_sum=$(sed -n 's/^passivity mutation probe: //p' "$MUT_out" | tail -n 1)
  MUT_ok=0; [ "$MUT_rc" = 0 ] && [ -n "$MUT_sum" ] && MUT_ok=1
  rowif "passivity mutation probe: ${MUT_sum:-no summary line} (exit $MUT_rc)" [ "$MUT_ok" = 1 ]
  [ "$MUT_ok" = 1 ] || grep -E 'BLIND|WRONG|SETUP|UNCOVERED|not yet red|not green|self guard' "$MUT_out" | cut -c1-200 | sed 's/^/    /'
  MUT_sum=$(sed -n 's/^passivity meta probe: //p' "$MUT_outm" | tail -n 1)
  MUT_ok=0; [ "$MUT_rcm" = 0 ] && [ -n "$MUT_sum" ] && MUT_ok=1
  rowif "passivity probe bites: ${MUT_sum:-no summary line} (exit $MUT_rcm)" [ "$MUT_ok" = 1 ]
  [ "$MUT_ok" = 1 ] || sed 's/^/    /' "$MUT_outm" | cut -c1-200
fi
