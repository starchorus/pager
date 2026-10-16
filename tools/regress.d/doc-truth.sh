# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/doc-truth.sh -- lists and numbers that were typed by hand are derived from their source (tools/doc-truth.py).
# GUARDS AGAINST: a hand-typed list (shell files of the shellcheck/passivity checks) or number in prose (check counts, fixture sizes, versions)
#                 goes stale unseen (a shell file in no shell list, a check count that no longer matches, a version that is not the current one).
# NEGATIVE PROBE: one break per check in a copy (unlisted script, renamed source literal, wrong number, header bump,
#                 swapped run list, ...) => red; the row "probes bite" repeats this every time (dummy copy, nothing runs in it).
# NOT PROVEN:     that the text around a number is right (header against page binds a number, not a sentence); prose in words is
#                 not read (nor a statement that runs over more than one line break); tools/* is exempted from the §14.6 scope as a
#                 whole (a new file there is never checked against the scope; only "exception alive" keeps watch); the two payload.sh (root against library/...) are different files; only their version is bound here.
# Sourced by tools/regress.sh (T2) with cwd = repo root, after tools/static.sh (it wrote out/$P-shfiles*.txt). Sets only DTR_* names.
# The listing uses git where root is a git work tree (state before/after the commit) and a walk otherwise (fresh-check worktree, the probe copy).

# shellcheck disable=SC2016   # the probe texts are literal document text (backticks), not expansions
# Exceptions (--exception) / sources without a fixture (--no-fixture): reason per entry; every entry has to be alive (the checker says "please remove" for a stale one).
# The shellcheck list has no exception at all: every shell file of the repository is checked (an entry would be GLOB=REASON passed to `lists`).
DTR_SCOPE_EXC='tools/*=developer tools: they run only on the development machine, never on the device, and carry the search words of the §14.6 rules on purpose as test data'
DTR_NOFIX='tcpdump=collector path with security "Secured", entered by no viewer run; tests/fixtures is the contract corpus, a further fixture needs a decision of its own'
DTR_NOFIX2='pineap=opt-in source of the recon lists of the AP service; its document comes from a stub run in the collector self-test, and a fixture would add a source the viewer runs have no reason to enter'
DTR_dt="tools/doc-truth.py"

sh tools/passivity-check.sh --files > "out/$P-dtr-pcfiles.txt" 2>/dev/null
DTR_SCL="--list out/$P-shfiles.txt --list out/$P-shfiles-tools.txt"
DTR_PCL="--list out/$P-dtr-pcfiles.txt"

dtr_run() {   # dtr_run ROOT CHECK [ARGS...] -> DTR_out (label line + detail lines), DTR_rc
  _dtr=$1; _dtc=$2; shift 2
  DTR_out=$(python3 -B "$R/$DTR_dt" "$_dtc" --root "$_dtr" "$@" 2>&1); DTR_rc=$?
}
dtr_row() {   # dtr_row NAME CHECK [ARGS...]: a real check on the real tree is one row; the label line carries the measured numbers
  _dtn=$1; _dtc=$2; shift 2
  dtr_run "$R" "$_dtc" "$@"
  rowif "doc truth $_dtn: $(printf '%s\n' "$DTR_out" | sed -n 1p)" [ "$DTR_rc" = 0 ]
  [ "$DTR_rc" = 0 ] || printf '%s\n' "$DTR_out" | sed '1d' | cut -c1-220
}
# shellcheck disable=SC2086   # DTR_SCL / DTR_PCL are flag lists on purpose (relative paths without blanks)
{
  dtr_row "shellcheck lists" lists $DTR_SCL
  dtr_row "§14.6 scope list" lists $DTR_PCL --exception "$DTR_SCOPE_EXC"
}
dtr_row "SOURCES = collector" sources
dtr_row "source census" census --no-fixture "$DTR_NOFIX" --no-fixture "$DTR_NOFIX2"
dtr_row "tools/README.md fixture table" fixtures
dtr_row "prose" prose
dtr_row "spec §11.0 run list = regress.sh loop" runlist
dtr_row "script headers = page version" headers

# ---- the probes: the same checks on a COPY of the tree (no .git, no out/) with exactly one broken input each. Nothing in the copy runs.
DTR_w=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-doctruth.XXXXXX")
DTR_pn=0; DTR_pbad=0
# The copy holds what the checks read in the real tree: in a git work tree the files git sees (tracked or untracked, not ignored;
# an ignored directory, such as a tool's worktree, would bring shell files of its own), elsewhere all but .git and out/.
if [ "$(git -C "$R" rev-parse --show-toplevel 2>/dev/null)" = "$R" ]; then
  (cd "$R" && git ls-files -z -co --exclude-standard \
     | python3 -B -c 'import os, sys; sys.stdout.write("".join(f + "\0" for f in sys.stdin.read().split("\0") if f and os.path.lexists(f)))' \
     | tar --null -T - -cf -) | tar -xf - -C "$DTR_w"
else
  tar -C "$R" --exclude ./out --exclude ./.git -cf - . | tar -xf - -C "$DTR_w"
fi
dtr_mut() {   # dtr_mut FILE MODE A [B]   modes: none | create (file with the line A) | append (line A) | replace (A -> B, A exactly once) | delline (the one line holding A)
  python3 -B -c '
import os, sys
mode, p, a = sys.argv[1:4]; b = sys.argv[4] if len(sys.argv) > 4 else ""
if mode == "none":
    sys.exit(0)
if mode == "create":
    open(p, "w").write(a + "\n"); sys.exit(0)
s = open(p, encoding="utf-8").read()
if mode == "append":
    open(p, "w", encoding="utf-8").write(s + ("" if s.endswith("\n") else "\n") + a + "\n"); sys.exit(0)
if mode == "replace":
    if s.count(a) != 1:
        sys.stderr.write("target text found %d times (want 1): %s\n" % (s.count(a), a)); sys.exit(3)
    open(p, "w", encoding="utf-8").write(s.replace(a, b)); sys.exit(0)
if mode == "delline":
    ls = s.split("\n"); k = [i for i, l in enumerate(ls) if a in l]
    if len(k) != 1:
        sys.stderr.write("target text on %d lines (want 1): %s\n" % (len(k), a)); sys.exit(3)
    del ls[k[0]]; open(p, "w", encoding="utf-8").write("\n".join(ls)); sys.exit(0)
sys.exit(2)
' "$2" "$1" "$3" "${4:-}"
}
dtr_probe() {   # dtr_probe WANT_RC 'WANT TEXT (or empty)' CHECK FILE MODE A B [CHECK ARGS...]   (FILE relative to the copy; restored afterwards)
  _dtw=$1; _dtt=$2; _dtc=$3; _dtn=$4; _dtf="$DTR_w/$4"; _dtm=$5; _dta=$6; _dtb=$7; shift 7
  DTR_pn=$((DTR_pn + 1)); _dto=0
  if [ -f "$_dtf" ]; then cp "$_dtf" "$_dtf.dtorig"; _dto=1; fi
  if ! dtr_mut "$_dtf" "$_dtm" "$_dta" "$_dtb" 2> "$DTR_w/.err"; then
    DTR_pbad=$((DTR_pbad + 1)); echo "    probe $DTR_pn ($_dtc, $_dtn): the break could not be applied: $(cat "$DTR_w/.err")"
  else
    dtr_run "$DTR_w" "$_dtc" "$@"
    [ -z "${DTR_VERBOSE:-}" ] || printf '    probe %s (%s, %s %s): rc %s: %s\n' "$DTR_pn" "$_dtc" "$_dtn" "$_dtm" "$DTR_rc" "$(printf '%s\n' "$DTR_out" | sed -n '2p;3p' | tr '\n' ' ' | cut -c1-170)"   # evidence for the report
    if [ "$DTR_rc" != "$_dtw" ]; then DTR_pbad=$((DTR_pbad + 1)); echo "    probe $DTR_pn ($_dtc, $_dtn $_dtm): want rc $_dtw, got $DTR_rc: $(printf '%s\n' "$DTR_out" | head -n 2 | tr '\n' ' ' | cut -c1-150)"
    elif [ -n "$_dtt" ] && ! printf '%s\n' "$DTR_out" | grep -qF -- "$_dtt"; then DTR_pbad=$((DTR_pbad + 1)); echo "    probe $DTR_pn ($_dtc, $_dtn $_dtm): rc ok but the text '$_dtt' is missing: $(printf '%s\n' "$DTR_out" | head -n 2 | tr '\n' ' ' | cut -c1-150)"; fi
  fi
  if [ "$_dto" = 1 ]; then mv "$_dtf.dtorig" "$_dtf"; else rm -f "$_dtf"; fi
}
# The copy itself has to be green first, or a red probe below would only show that the copy is broken (fairness).
DTR_cbad=""
# shellcheck disable=SC2086
{
  dtr_run "$DTR_w" lists $DTR_SCL; [ "$DTR_rc" = 0 ] || DTR_cbad="$DTR_cbad lists(sc)"
  dtr_run "$DTR_w" lists $DTR_PCL --exception "$DTR_SCOPE_EXC"; [ "$DTR_rc" = 0 ] || DTR_cbad="$DTR_cbad lists(scope)"
}
dtr_run "$DTR_w" census --no-fixture "$DTR_NOFIX" --no-fixture "$DTR_NOFIX2"; [ "$DTR_rc" = 0 ] || DTR_cbad="$DTR_cbad census"
for DTR_c in sources fixtures prose runlist headers; do dtr_run "$DTR_w" "$DTR_c"; [ "$DTR_rc" = 0 ] || DTR_cbad="$DTR_cbad $DTR_c"; done
[ -z "$DTR_cbad" ] || echo "    the unbroken copy is not green for:$DTR_cbad"
grep -v 'starchorus-serve.sh' "out/$P-dtr-pcfiles.txt" > "$DTR_w/l-noserve.txt"
{ cat "out/$P-shfiles.txt"; echo nosuch.sh; } > "$DTR_w/l-phantom.txt"
# shellcheck disable=SC2086
{
  # lists: a shell file nobody lists, the exception that is meant to cover tools/*, a script outside tools/, a list that lost starchorus-serve.sh,
  # a stale exception, an exception that covers a listed file, a listed file that is not there
  dtr_probe 1 'tools/zz-probe.sh' lists tools/zz-probe.sh create ': probe' '' $DTR_SCL
  dtr_probe 0 '' lists tools/zz-probe.sh create ': probe' '' $DTR_PCL --exception "$DTR_SCOPE_EXC"
  dtr_probe 1 'zz-probe.sh' lists zz-probe.sh create ': probe' '' $DTR_PCL --exception "$DTR_SCOPE_EXC"
  dtr_probe 1 'starchorus-serve.sh' lists README.md none '' '' --list "$DTR_w/l-noserve.txt" --exception "$DTR_SCOPE_EXC"
  dtr_probe 1 'matches no shell file: please remove' lists README.md none '' '' $DTR_SCL --exception 'tools/nosuch*=probe'
  dtr_probe 1 'ARE listed' lists README.md none '' '' $DTR_SCL --exception 'starchorus-collect.sh=probe'
  dtr_probe 1 'listed but not in the repository: nosuch.sh' lists README.md none '' '' --list "$DTR_w/l-phantom.txt" --list "out/$P-shfiles-tools.txt"
  # sources: a literal renamed in the collector (awk -v src and the printf), a source the validator does not know, then the census
  dtr_probe 1 "emits no such source" sources starchorus-collect.sh replace '-v src="tcpdump"' '-v src="tcpdumpx"'
  dtr_probe 1 "missing in gen-testdata.py SOURCES" sources starchorus-collect.sh replace '"source": "none",' '"source": "nonex",'
  dtr_probe 1 "the collector emits no such source" sources tools/gen-testdata.py replace 'IWSCAN, "none")' 'IWSCAN, "none", "bogus")'
  dtr_probe 1 'please remove' census tests/fixtures/single-ap.json replace '"source": "recon-db"' '"source": "tcpdump"' --no-fixture "$DTR_NOFIX" --no-fixture "$DTR_NOFIX2"
  dtr_probe 1 'not in SOURCES' census tests/fixtures/single-ap.json replace '"source": "recon-db"' '"source": "bogus"' --no-fixture "$DTR_NOFIX" --no-fixture "$DTR_NOFIX2"
  dtr_probe 1 'occurs in no fixture' census README.md none '' ''
  # fixtures: a wrong AP / free-client / clients[] / band count, a moved generator seed, a row gone
  dtr_probe 1 'many-clients.json: the table says APs = 26' fixtures tools/README.md replace '| `many-clients.json` | 25 APs' '| `many-clients.json` | 26 APs'
  dtr_probe 1 'free clients = 181' fixtures tools/README.md replace '180 free clients' '181 free clients'
  dtr_probe 1 'APs with clients[] = 11' fixtures tools/README.md replace '(10 with `clients[]`)' '(11 with `clients[]`)'
  dtr_probe 1 'APs on 2.4GHz = 11' fixtures tools/README.md replace '10 × 2.4' '11 × 2.4'
  # a row reworded so that its number falls out of the pattern must not stay green: the claim has to be read (derived from the file)
  dtr_probe 1 'no longer states APs' fixtures tools/README.md replace '| `many-clients.json` | 25 APs' '| `many-clients.json` | 99 Access Points'
  dtr_probe 1 'no longer states free clients' fixtures tools/README.md replace '180 free clients' '999 unassociated clients'
  dtr_probe 1 'no longer states APs with clients[]' fixtures tools/README.md replace '(10 with `clients[]`)' '(10 APs with `clients[]`)'
  dtr_probe 1 'does not quote ACTIVE_GEN' fixtures tools/README.md replace '--seed 158' '--seed 159'
  dtr_probe 1 'single-ap.json has no row' fixtures tools/README.md delline '| `single-ap.json` |' ''
  # prose: a hand-typed check count, a collector version claim; a dated count is allowed (control)
  dtr_probe 1 'hand-typed check count' prose README.md append '- `--selftest` green (42 checks) under BusyBox' ''
  dtr_probe 1 'version claim' prose docs/architecture.md append '- The collector `starchorus-collect.sh` is at **version 0.0.9**.' ''
  # the same claims in other words: without the word "Version", other nouns for a check, a plain number after the script name
  dtr_probe 1 'version claim 0.0.9' prose README.md append '- The collector `starchorus-collect.sh` 0.0.9 delivers `vendor`.' ''
  dtr_probe 1 'version claim 0.0.9' prose README.md append '- The dashboard `starchorus-display.sh` v0.0.9 shows it.' ''
  dtr_probe 1 'hand-typed check count' prose README.md append '- `--selftest`: 42 checkpoints green.' ''
  dtr_probe 1 'hand-typed check count' prose README.md append '- `--selftest`: 42 tests green.' ''
  # markdown decoration and other layouts of the same claims: bold / backticks / parentheses around the number, a colon or a table
  # cell between the name and the version, a claim wrapped over the line end
  dtr_probe 1 'hand-typed check count' prose README.md append '- The self-test: **42** checks run.' ''
  dtr_probe 1 'hand-typed check count' prose README.md append '- The self-test: `42` checks run.' ''
  dtr_probe 1 'hand-typed check count' prose README.md append '- The self-test: 42 (checks) run.' ''
  dtr_probe 1 'hand-typed check count' prose README.md append '- The self-test has 42 cases.' ''
  dtr_probe 1 'hand-typed check count' prose README.md append '- The self-test has 42
checks.' ''
  dtr_probe 1 'version claim 0.0.9' prose README.md append '- Collector: 0.0.9 delivers `vendor`.' ''
  dtr_probe 1 'version claim 0.0.9' prose README.md append '| Collector | `starchorus-collect.sh` | 0.0.9 |' ''
  dtr_probe 1 'version claim 0.0.9' prose README.md append '- The collector
0.0.9 delivers `vendor`.' ''
  dtr_probe 0 '' prose README.md append '- Pause 1.2 s after the collector start; collector self-test (as of 2.6.0: 42 green).' ''
  dtr_probe 1 'version claim 0.1.1 about the collector, the header says 0.1.2' prose starchorus-collect.sh replace '# Version:      0.1.1' '# Version:      0.1.2'   # the claim that is true today (the version table of README.md) goes red at the next bump
  dtr_probe 0 '' prose README.md append '- `--selftest` green (42 checks, as of 2.6.0) under BusyBox' ''
  dtr_probe 0 '' prose README.md append '- The collector `starchorus-collect.sh` (since 0.0.2) delivers `vendor`; until `starchorus-display.sh` 0.0.1 X was missing; collector ≥ 0.0.3; the collector answers at (192.0.2.1, §5.6).' ''   # "since/until/≥" say when, not what is current; an IP address is no version
  # a number NEWER than the header is just as stale (one project, one version): higher numbers left over in the docs
  dtr_probe 1 'version claim 1.5 about the collector' prose README.md append '- The collector `starchorus-collect.sh` 1.5 delivers `vendor`; the dashboard `starchorus-display.sh` 1.4 shows it.' ''
  dtr_probe 1 'version claim 1.4 about the display script' prose README.md append '- The dashboard `starchorus-display.sh` 1.4 shows it.' ''
  dtr_probe 1 'version claim 0.2 about the collector' prose README.md append '- A later stage builds collector 0.2.' ''
  # run list of the spec against the loop of regress.sh
  dtr_probe 1 'spec run list' runlist docs/architecture.md replace '`single-ap`, `empty-none`' '`empty-none`, `single-ap`'
  dtr_probe 1 'spec says 9 runs' runlist docs/architecture.md replace 'for all 10 runs' 'for all 9 runs'
  dtr_probe 1 'spec run list' runlist tools/regress.sh replace 'for f in demo legacy few-clients' 'for f in demo few-clients'
  # headers: one script header bumped alone (collector, display script, the library payload), and the page bumped alone
  dtr_probe 1 'starchorus-collect.sh: header 0.1.2, but the page version is 0.1.1' headers starchorus-collect.sh replace '# Version:      0.1.1' '# Version:      0.1.2'
  dtr_probe 1 'starchorus-display.sh: header 0.1.2, but the page version is 0.1.1' headers starchorus-display.sh replace '# Version:      0.1.1' '# Version:      0.1.2'
  dtr_probe 1 'library/user/reconnaissance/starchorus/payload.sh: header 0.1.2' headers library/user/reconnaissance/starchorus/payload.sh replace '# Version: 0.1.1' '# Version: 0.1.2'
  dtr_probe 1 'but the page version is 0.1.2' headers starchorus.html replace '  version: "0.1.1",' '  version: "0.1.2",'
}
rm -rf "$DTR_w"
DTR_pok=0; [ "$DTR_pbad" = 0 ] && [ -z "$DTR_cbad" ] && [ "$DTR_pn" -ge 40 ] && DTR_pok=1
rowif "doc truth probes bite: $((DTR_pn - DTR_pbad))/$DTR_pn broken copies as expected (≥ 40), unbroken copy green: ${DTR_cbad:-yes}" [ "$DTR_pok" = 1 ]
