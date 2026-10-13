# tools/ — development and test tools

Everything here runs **on the development machine** (macOS or Linux with `python3`, POSIX `sh`,
Google Chrome), with two exceptions that only the person at the keyboard sets off: `install.sh` runs on
the machine and copies the project files to the device over ssh/scp, and `device-probe.sh` is piped
over ssh into a shell on the device and runs there, read-only. None of these tools is installed on the
device. The tools send nothing over the air; they serve an HTML page locally and drive a headless
browser.

Only the Python standard library, POSIX `sh` and Chrome over the DevTools protocol: no npm, node, pip
or brew. Every tool runs from any working directory and from a fresh clone.

```sh
sh tools/quick.sh                   # T1: Chrome-free checks, seconds (also the Git hook)
sh tools/regress.sh base            # T2: full non-regression, needs Chrome (exit 0 = every row PASS)
sh tools/passivity-check.sh         # only the static passivity and legal checks
sh tools/fresh-check.sh worktree    # before the commit: does the regression run from a fresh copy?
sh tools/fresh-check.sh clone       # after the commit: from a git clone
sh tools/install-hooks.sh           # switch on the Git hook for this clone (once per clone)
```

## Test tiers: what each net proves

| Tier | Invocation | When | Proves | Does **not** prove |
|---|---|---|---|---|
| **T1** | `sh tools/quick.sh` (hook: `.githooks/pre-commit`) | every commit that touches a checked path | the Chrome-free rules on the **index**: passivity and legal rules on the source, hygiene of collector, dashboard and fixtures, the documentation bindings from `doc-drift`, `jq` without regex | that the **running** page is passive; the collector self-test; anything under BusyBox; anything on the device |
| **T2** | `sh tools/regress.sh PREFIX` and `sh tools/fresh-check.sh worktree` / `clone` | before commits to the page, collector or dashboard, and before a release | everything in T1 plus the self-test, the mutation probe and every run in headless Chrome (budgets, layout, legend, source, the page's runtime network, legal rules on the rendered text), from a fresh clone | a run under BusyBox or on the device; real GPU rendering (headless renders in a software raster); any `jq` other than the development machine's |
| **T3** | on the device, by hand ([`docs/device-notes.md`](../docs/device-notes.md), `device-probe.sh`) | before a release | the behaviour on the device | — |

**Preflight.** `quick.sh` and `regress.sh` check before the first row that the tools they need are
present (`PF_TOOLS_QUICK` and `PF_TOOLS_FULL` in `harness.sh`). If one is missing, the output is
`MISSING: <tool>` and **exit 2**, rather than a pile of follow-up failures. `sqlite3` is the one
deliberate switch: without it and without `ALLOW_NO_SQLITE=1`, exit 2; with the switch T2 carries on,
the self-test row then reads `NOT COVERED` (neither PASS nor FAIL), and the run ends with
`NOT COVERED: n row(s) …`. `STARCHORUS_PREFLIGHT_ONLY=1` stops after the preflight (probe mode).

**Timing.** The wall time per phase and per drop-in (whole seconds) is written to
`out/PREFIX-timing.txt`; a row at the end of `regress.sh` asks for every drop-in in the directory
by name. `tm_note` writes the measured times of individual evals to the same file. Nothing runs in
parallel; the drop-ins share `out/`.

**Hook.** A green hook does not replace T2. To switch it on: `sh tools/install-hooks.sh` (local
configuration, once per clone); to check it: `sh tools/install-hooks.sh --check`.

## Tools

| File | Purpose |
|---|---|
| `cdp.py` | Minimal driver for the Chrome DevTools protocol (stdlib only). Starts headless Chrome, loads a URL, collects console messages and exceptions, measures the frame rate, evaluates JS expressions (`--eval`, top-level `await` in REPL mode, `--eval-timeout`), clicks and types (`--click`, `--key`), runs ordered steps after the evals (`--step eval:` · `click:X,Y` · `clickat:EXPR` · `key:` · `wait:` · `size:WxH`) and takes a screenshot. Chrome picks the DevTools port itself, so parallel runs never share a browser. The `--json` report lists under `requests` every request the page actually made (`{method, url, type}`, including redirects, `sendBeacon` and `data:`, a WebSocket as `WEBSOCKET`). |
| `verify.sh` | Test runner: `tools/verify.sh HTML FIXTURE\|demo PREFIX [cdp args]`. Copies page and fixture into a temp directory, starts `python3 -m http.server` on a free port, calls `cdp.py`, filters out the expected 404s (`favicon.ico`, and `starchorus.json` in demo mode) and writes `PREFIX.json` (report with a `verify` block), `PREFIX.png` and `PREFIX.server.log`. Exit 0 = clean, 1 = real errors, exceptions or fps < 30, 2 = invocation or setup. |
| `harness.sh` | Shared functions for **sourcing** (`. tools/harness.sh`, from any directory in the repo or with `STARCHORUS_ROOT=…`): `R`/`F`/`H` (repo, fixtures, page), `runq FIXTURE\|demo "QUERY" PREFIX [--delay S] [cdp args]` (its own server, cleans up on INT/TERM as well; `--delay` holds back every `starchorus.json` response by S seconds), `runseq` (sequence run with `?poll=0&spin=0&intro=0&fixed=$STARCHORUS_FIXED`, without fps), `chk`, `evals`/`evalv`, `ev3`/`ev3eq` (one expression in all three themes), `nomatch`, `EV_TEXT` (every text on the page), `EV_THAW` (fade nodes in under `?fixed`), `sec_slice`/`sec_grepc` (a section range of the page with anchors: every marker exactly once, a minimum length, exit 2 otherwise), `selftest_verdict`, `pycompile`, `net_verdict`, `fuzz_verdict`, `order_verdict`, `report_secs`, `tm_begin`/`tm_lap`/`tm_note`/`tm_check`, `preflight` and `path_farm`. `runq`/`runseq` touch only their own `_rq_*`/`_rs_*` names; a regression row checks this with sentinels. |
| `static.sh` | The Chrome-free rows in **one** place (for **sourcing**, after `harness.sh`): page (sections, token reads, hex colours, theme comparisons, clock), the collector self-test and its verdict, `passivity-check.sh`, the shellcheck lists, `cmp` of the dashboard copies, fixture validation, `active.json` = generator output (`ACTIVE_GEN`), self-sufficiency of the harness (no absolute paths), Python `compile`; and with them the baselines (`BASE_*`, lower only), the floors (`MIN_*`, raise only), `QUICK_DROPINS` and the environment report. No `git` in it (the hook runs on an export of the index without `.git`). `STATIC_SELFTEST=0` leaves out the self-test. |
| `quick.sh` | Tier **T1**: `static.sh` without the self-test, the drop-ins from `QUICK_DROPINS` (a row checks that they stay Chrome-free) and `denylist-check.sh --selftest`/`--extended`. Prints the environment, the rows (per drop-in `quick drop-in NAME ran (N rows)`) and `quick: N PASS, M FAIL, T s`. With `QUICK_MUTATE=1` it adds the passivity mutation probe (the hook sets this when `passivity-check.sh` or `passivity-mutate.sh` is staged). If static rows are red, the drop-ins do not run (they execute the dashboard copies). `regress.sh` requires exit 0, `MIN_QUICK_ROWS` and the rows of the drop-ins and the denylist by name. |
| `regress.sh` | Full non-regression, `sh tools/regress.sh PREFIX` from any directory: `static.sh`, the global criteria on ten runs (demo mode and nine fixtures; the run list in spec §11.0 is matched against the `for` loop), fillText budgets in all three themes (2D, 3D and a stress run), hygiene of `runq`, `quick.sh` as a row, the name match of the drop-in set (`DROPINS`), then every drop-in and the timing. Exit 0 = every row PASS, 1 = at least one FAIL, 2 = setup. Spec §9.9 lists which promises of the specification have no standing row. |
| `fresh-check.sh` | Proves 'the regression runs from a fresh clone': `worktree` (before the commit: a copy of `git ls-files -co --exclude-standard`) or `clone` (after the commit), target path with spaces, invoked from `/`. `KEEP=1` keeps the copy. |
| `../.githooks/pre-commit` | Git hook: if a commit touches the page, `index.html`, collector, dashboard, `starchorus-serve.sh`, `payload*`, `library/`, `packaging/`, `tests/`, `tools/`, `.githooks/` or `.github/`, it exports the **index** (not the working tree) with `git checkout-index` into a temp directory and runs `sh tools/quick.sh` there. When red, it shows only the red rows, exit 1. A commit that stages **only** documentation skips it. `git commit --no-verify` is the visible emergency exit and requires a reason **and** substitute evidence in the commit message. |
| `install-hooks.sh` | Sets `core.hooksPath = .githooks` in the **local** Git configuration of this clone (idempotent) and shows where the value comes from. `--check` changes nothing: exit 0 = active and executable, 1 = not active. Deliberately no regression row (a fresh clone does not have this configuration). |
| `env-expected.txt` | Tool versions (shellcheck, python3, jq, sqlite3, Chrome, `uname -sr`) of the last green run. `static.sh` prints the actual values before the rows; a difference is a **note**, not a FAIL. A row checks only that both carry the same keys. |
| `passivity-check.sh` | Static passivity and legal checks. Network surface of the page: no `method:`/`POST`/XHR/WebSocket/EventSource/`sendBeacon`, exactly one `fetch("starchorus.json`, no further network APIs and no navigation as a command path (assignment to `location`, `createElement("a")`, `.click(`, `download=` …), URLs only in the font's licence header. Command words of the AP service only in the allowlist functions `SEC6_FUNCS` (`apcli_ro`, `apcli_stub`, `apcli_selftest`), with the reverse direction (every listed function is defined) and a fill probe (the checked file set contains the collector, both dashboard copies, both `payload.sh` and `starchorus-serve.sh`; floor `MIN_FNSCOPE` of recognised functions). `iw scan` only behind `STARCHORUS_ALLOW_ACTIVE=1`, no transmit tools. Every `sqlite3` call outside `selftest()` carries `-readonly` (floor `MIN_SQLITE_CALLS`). `starchorus-serve.sh` answers only `GET`/`HEAD` on exactly `/`, `/index.html`, `/starchorus.json` (handler text pinned exactly; the file never runs). The denylist is called as one row through `denylist-check.sh`. `--files` prints the checked file list, `--regexes` the regex families. |
| `passivity-mutate.sh` | Proves that `passivity-check.sh` **can** go red: copies the checked files into `mktemp -d`, first runs the unchanged copy (exit 0, every row name present), then per mutation a fresh copy with **exactly one** changed line, and compares the set of red rows **exactly** with the expected one (`RED` / `GREEN (BLIND!)` / `WRONG-ROW` / `SETUP-ERROR` when the target line does not exist exactly once). A control mutation must stay green, and every row of the guard must go red at least once. **Per alternative:** the regex families (`NETSURF_RE`, `NETX`, `TX_WORDS`, `IW_VERBS`, `SEC6_RE`) are split at the top `\|` level; every alternative needs exactly one example that hits only it and stands as evidence under the expected red row (`UNCOVERED` = an alternative without an example). In the copies **only** `sh tools/passivity-check.sh` runs. `--meta` blinds the guard in an image and requires `GREEN (BLIND!)`; `--only NAME` runs one mutation, `--only alts` only the alternatives probe. |
| `denylist-check.sh` | Legal denylist (spec §14.7): checks `starchorus.html` and both dashboard copies against `denylist.txt` (case-insensitive, substring, literal `grep -ciFf`), `denylist-words.txt` (case-insensitive, whole word) and `denylist-cs.txt` (case-sensitive, whole word: classifications, organisation abbreviations). `--extended` also checks the collector, payloads, `index.html`, `starchorus-serve.sh`, `gen-testdata.py` and the fixtures. `--selftest` checks the machine's grep semantics **and the content of the three lists**: the positive fixture carries one line per term listed in §14.7 plus one example of each category that §14.7 only names; the line count is hard-wired, so a deleted list entry turns the row red. Known gap: 'Home Office' is in no list. Exit 0 = no hits, 1 = hits (file:line), 2 = setup. |
| `denylist.txt`, `denylist-words.txt`, `denylist-cs.txt` | The lists: one line per entry, no comments, no blank lines (a blank line would hit every line); short entries (under 6 characters, letters and digits only) belong in `denylist-words.txt`. |
| `doc-truth.py` | **Lists and numbers that would otherwise be typed by hand are derived.** `doc-truth.py CHECK` prints one line, exit 0/1/2: `lists` (every shell file of the repo is in the shellcheck list, or in the file list of `passivity-check.sh --files`, or in a reasoned exception; every exception still matches a file, otherwise 'please remove'), `sources` (`SOURCES` in `gen-testdata.py` = the sources the collector emits, both directions), `census` (every source occurs in a fixture or is listed, with a reason, as an exception), `fixtures` (the [fixture table](#fixtures) below: every fixture has a row, every row a fixture, and the sizes stated — APs, APs with `clients[]`, free clients, band split, `source`, the generator call of `active.json` — are the measured ones; a statement in a form the pattern does not read is red), `prose` (no hand-typed check counts in the documentation, and a version number after the name of the collector or the dashboard is that of the script header, neither older nor newer), `runlist` (run list in spec §11.0 = the loop of `regress.sh`), `headers` (the `# Version:` header of every script that carries one is the page version: one project, one version number). |
| `dump-themes.sh`, `spec-sync.py` | Generate and check the machine-made parts of the specification: `sh tools/dump-themes.sh themes\|contrast out.json` reads the three token blocks or the contrast ratios from the running page; `python3 tools/spec-sync.py [--check] themes.json contrast.json docs/architecture.md` writes (or compares) spec §3.8 and §7.0a between the `spec-sync` markers. |
| `check-colors.py` | Colour-role validator (spec §14.4): reads the token sets of the three themes (`JSON.stringify(STARCHORUS._internals.THEMES)` as a `cdp.py` report or a raw file) and checks band hues, ΔE (OKLab × 100 after alpha compositing over `surface.base`), chroma for unknown, selection and aggregates, the distance of alarm and chrome from data colours and of ornaments from the alarm. `--table` prints every measurement, `--selftest` checks the maths against known colours. Exit 0 = green, 1 = red, 2 = input. |
| `gen-testdata.py` | Generates deterministic `starchorus.json` test data in the collector's JSON contract; the data cover ESSID groups across 2.4/5/6 GHz, channels and frequencies per band, a security mix, RSSI distributions, randomised MACs and optional fields. It also checks files against the contract (`--validate`). The hand-built fixtures come from `--devices`, `--aged` and `--secsuite`; `--stamp FILE` adds `last_seen`. See [Fixtures](#fixtures). |
| `fuzz-doc.py` | Deterministic mutants of `starchorus.json` documents for the ingest fuzz (`--seed`, same seed = same bytes). The field lists are **derived**: contract keys from `gen-testdata.py`, actual keys from the fixtures, keys read (with their type) from the page's `normalizeDoc()`/`normClient()`. Seven classes (field missing, wrong type or not a document, null entries, numeric junk, `__proto__`/duplicates, hostile text, many entries). The bundle under `out/` is itself a valid document with the extra key `fuzz`; `--emit-dir` writes single documents for the dashboard. `--canary PATH` must remain a single shell word (exit 2 otherwise). Writes nothing to `tests/fixtures`. |
| `data-oracle.py` | The **data oracle**: a second, independent statement of the page's data rules (normalisation, device grouping as union-find over the BSSID bytes with the U/L bit, windows and SSID base, ESS sets, the counters of `stats()`) and a judge that compares the page's `stats()`, `devices()`, `essClusters()` and `deviceOf()` after `STARCHORUS.load()` of every fixture **and** of built-in hand documents with hand-computed edge cases, in both `essMerge` modes. Subcommands `bundle`, `judge`, `truth` (the documented ground truth of `devices.json` from the header of `gen-testdata.py`, against the numbers in this README, if it states any) and `selftest` (Chrome-free, part of T1; every compared field is held in turn against a doctored page and must be named). Combinatorics, not geometry. |
| `evals/*.js` | Expressions for `cdp.py --eval` that are too long for a shell line: `legend-truth.js` (legend against tokens and encoding), `ingest-fuzz.js` (load mutants, check sinks), `order-invariance.js` (shuffled lists, canonical digest), `data-oracle.js` (supplies the page's values for the oracle). The evals only observe; expected values are worked out on the Python or shell side. |
| `install.sh` | Installer for the device from the repo files: `sh tools/install.sh [--host HOST] [--dry-run]` (host: `--host`, otherwise `STARCHORUS_HOST`, otherwise the default address stored in the script). Runs on the machine and talks to the device only over ssh/scp (one master connection, `scp -O`), nothing over the air. Refuses (exit 2) if a source file is missing or the dashboard copies differ, names the versions before the upload, then checks every file (`cksum`, otherwise read-back and `cmp`) and runs the self-tests of collector and dashboard, a passive `--once` run and a dashboard test (FAIL on blank band counters or 'jq incomplete'). Remote commands only `mkdir -p`, `chmod`, `cksum`, `sh <script> --selftest`, `--once`, `head -c`. The output holds only versions, counts and checksums. |
| `hak5-package.sh` | Builds the self-contained payload directory for Hak5's payload library: `sh tools/hak5-package.sh [OUTDIR]` (default `out/hak5`) writes `OUTDIR/library/user/reconnaissance/starchorus/` with `payload.sh`, the collector, the page as `index.html`, the dashboard, the fallback server, `README.md` (from `packaging/hak5/README.md`) and `LICENSE`, each a byte copy of its source; `--list` prints the map. It refuses (exit 2, nothing written) when a source is missing or the two dashboard copies differ, and replaces the target directory as a whole. Reads the repo and writes that tree only: no network, no device, no git. |
| `device-probe.sh` | **Runs on the device.** `ssh root@<device> sh -s < tools/device-probe.sh \| tee probe.txt` (the person types the password) answers, in **one read-only session**, the open device verifications from [`docs/device-notes.md`](../docs/device-notes.md) as observations, ending with `V-1` … `V-12`, each `OBSERVED` or `NOT-OBSERVABLE`. The recon database is opened only as a copy in a private `mktemp -d` and only with `sqlite3 -readonly`; no AP service command line, no package manager, no configuration change, no scan, no capture, no network. The output holds only numbers, column names and distributions; file and directory names only from fixed word lists (otherwise `<withheld>`), and MAC-shaped strings are replaced. That is a filter, not a proof: read the output before pasting it into the repo. Refuses (exit 2) without Linux and `/etc/openwrt_release`, unless `STARCHORUS_PROBE_FORCE=1`; `STARCHORUS_PROBE_SKIP_SELFTEST=1` skips the self-tests. |

## Drop-ins

Rows on one topic live as a drop-in in `tools/regress.d/<name>.sh`. The mechanism works as
follows:

- After the static and the core rows, `regress.sh` sources every file `tools/regress.d/*.sh` in
  glob order, with the repo as working directory. Available are `row`/`rowif`, the helpers from
  `harness.sh` (`runq`, `runseq`, `evalv`, `ev3`, `ev3eq`, `nomatch`, `sec_slice` …), `budget` and the
  variables `$P` (prefix), `$F` (fixtures), `$H` (page) and `$R` (repo).
- Each drop-in sets only variables with its own prefix (such as `OPS_*`, `DTR_*`) and is
  shellcheck-clean (`# shellcheck shell=sh`; `rowif` or `if/then/else` rather than
  `A && row PASS || row FAIL`; expansions quoted).
- The set of drop-ins is pinned in `DROPINS` (in `regress.sh`): a renamed or missing drop-in turns
  the name-match row red, rather than silently taking its rows along. Whoever adds a drop-in updates
  `DROPINS` in the same commit.
- The drop-ins in `QUICK_DROPINS` (in `static.sh`) also run in T1; they must be Chrome-free.
  `QUICK_DROPINS_MUTATE` is added with `QUICK_MUTATE=1`.
- Each drop-in gets a line of its own in the timing file.
- Drop-ins are named after their topic (`tools/regress.d/<topic>.sh`); new ones carry a short profile
  in their header (GUARDS AGAINST / NEGATIVE PROBE / NOT PROVEN).

| Drop-in | Checks |
|---|---|
| `legal.sh`, `neutral-language.sh` | **Legal rules and neutral language.** Denylist self-test (semantics and list content), `--extended`, the rendered text of all three themes (both logons, CSS upper case, forcibly visible detail, help and paste dialogue, selected and hovered AP, chanbar tooltips of every occupied channel) and the dashboard LOG against the denylist. Neutral language (spec §14.5, P10): every visible text of the page (text nodes, `title`/`aria-label`/`placeholder`/`alt`/meta) in all themes on demo/active/devices/field-probes, plus the LOG of both dashboard copies for every screen and every fixture (the row reads the screens from the script's `screen_NAME()` functions, with a vacuity guard) and its string literals. Exceptions: the storage key `hostile` and the operator label 'Suspect'. |
| `theme-schema.sh` | **Symmetric theme schema and theme-free geometry.** `STARCHORUS.themeAudit()` without findings, key sets of equal size, a mutation probe in both directions; geometry from `LAYOUT`/`CFG3D` rather than theme tokens; `labelCandidates()`, hit-test grid and node positions the same in all three themes (many-clients 2D/3D, field-probes 2D); drawn labels are an ordered subsequence of the candidates. |
| `source-truth.sh` | **Source and truth of the display.** Switching of the copy tokens on `active.json` in all themes (no passivity sentence any more, ACTIVE line on every surface, chip 'Active scan') with `field-probes.json` as the passive counter-check; liveness ('Stale' after six unchanged polls, reset on a new `generated`; demo, recording and `none` never stale); the logon mode line is computed only when typed and waits for the first poll; ingest without a wall clock; symmetry of the `copy` group; ACTIVE switching in the dashboard. |
| `legend.sh` + `evals/legend-truth.js` | **Legend = drawing.** In all themes the fixed list of legend rows, every painted colour against its token, the tokens per row against a table derived by hand on the test side (which keeps the check from being tautological), ring width and dashing against `ENCODING`, the arc row only in WarGames, the height row only in 3D, the row 'Band ?' only once there is an AP without a band. |
| `labels-particles.sh` | **Labels, click-pin, particles.** With the labels switch `L` off only the centre remains (all themes × 2D/3D); a real pointer click pins and unpins, with the detail; double click, clients, bubbles; probe-orbit clients without a band ring; fillText worst case ≤ 30 / ≤ 24 and `fillText` = the number of listed text entries; particles are reset only on a change of source, a new BSSID collects alone, vanished APs give their block back. Never `?fixed` from boot. |
| `contrast.sh` | **Contrast.** `STARCHORUS.contrast()` in all themes (text ≥ 4.5, rings and marks ≥ 3, every pair passes its own minimum), the API semantics (alpha compositing, a single pair, invalid input yields `{error}`) and the painted ring pixels on `#bg`. |
| `edge-layout.sh` | **Edge panels never overlap.** Pairwise intersection 0 of all visible edge panels and every `.panel`, with and without the detail of each AP, in all themes at 1440×900, 1280×800 and 1000×640, and in 3D with every legend row; the measured layout decisions (`STARCHORUS.edgeLayout()`), the chrome tokens per theme, the responsive view at 640×900, detail taking precedence over the chanbar at 1000×500, and that the legend's scroll offset survives a pass. |
| `doc-drift.sh` | **Documentation binding, purely static (also T1).** `STARCHORUS.version` = spec §10; spec §14 complete (D1–D20, P1–P10, U1–U4 with U1 open, ten sections; every button ID named in §14.8 exists in the page); certain words and the film quotation not in README or spec; 'Highway Gothic' in README and page; `COPY_ACTIVE` and the chip label 'Stale' are read from the page and must appear verbatim in the README; the payload on the device reads one hour by default (`STARCHORUS_MAX_AGE` 3600) every 30 s, and `tools/install.sh --dry-run` takes this window from the payload (also in a copy with a different value); the installer's hints for `--status`/`--stop` set `STARCHORUS_OUTDIR` to the payload's directory (its single `STARCHORUS_DIR` line, fixed or as `${STARCHORUS_DIR:-/path}`). |
| `jq-noregex.sh` | **The device's `jq` has no regex library** (also T1). Static: no regex builtins in either dashboard copy; at run time every screen × every fixture twice through a generated `jq` wrapper that switches between the real and the device `jq` via `STARCHORUS_NRX`, compared byte for byte (with vacuity guards); a table of band and security inputs with expected values against the `JQLIB` cut from the **shipped** script (including the whitespace edge cases at both ends); the top screen with non-text fields from a generated fixture (not in `tests/fixtures`). |
| `display-selftest.sh` | **The dashboard's on-device self-test**, against both copies: `--selftest` under the real and the simulated device `jq`, a negative control (`STARCHORUS_BREAK=endswith`: exit 1, the `FAIL` line names the building block, the red marker 'jq incomplete' appears), no marker with a healthy `jq`, the self-test without `jq`, clean-up of the temp fixture after SIGTERM as well, no regex call even after joining shell `''` pairs. |
| `ap-models.sh` | **Theme-free models and marks.** Freshness against a Python recomputation of `aged.json`, event sequence and change mark in all themes (also with reduced motion), live indicator, poll deadline against a deliberately hanging server (`runq --delay` + `?pollto=`), sky statistics, crowding, signal levels, pixel samples of the marks, the colour-role validator with negative controls, `aged.json` = generator output. |
| `collector-fields.sh` | **The collector's extra fields on the page.** `secsuite.json` = generator output; security classes `owe`/`enterprise`/`tkip-weak`/`wpa3-transition`, `akm`/`cipher`/`auth` in the detail, counters for `channels[]` and `own_*` (never their values in the text), a document without extra fields, the payload's default `STARCHORUS_MAX_AGE`, the four switches off by default. The collector side (bitmasks, allowlist with stub, hop info, survey) is covered by its self-test. |
| `observations.sh` | **What the page remembers and derives.** Change log, baseline and ghosts, observations (two captures of dwell time, look-alike only against the confirmed set, neutral language, watchlist), keys `W`/`B`, persistence, `?obs`/`?baseline`, layout with the drawer open, the storage keys and their mention in `SECURITY.md`. |
| `operator-tools.sh` | **The operator's tools.** Library (import, OUI rules, bulk assignment), notes (no note text in the export), inventory (chips, sorting, filter, ≤ 300 rows), export (JSON/CSV/SITREP, footer, PNG, print), homing (peak hold and decay, tone off), keys `I`/`F`, `?inv=1`, layout with inventory and homing, six storage keys and their mention in `SECURITY.md`, no transmit paths. |
| `channel-time.sh` | **Channel, time, playback.** Channel occupancy and DFS table against a Python recomputation, peak hold, air quality; time series against Python, a threshold across a poll; recording and playback (no engine moves on, a poll during playback, 'Back to live' without invented arrivals, limits of 120 captures / 8 MB, no storage key, mention in `SECURITY.md`); keys `Q`/`J`/`H`/`Y`, one drawer at a time, neutral language in the drawers. |
| `theme-wargames.sh` | **WarGames.** Batched ring strokes (`drawCalls.stroke` ≤ 30 on field-probes), afterglow by freshness, arrival arc and reception ring only for a new station (not with reduced motion, not in other themes), source badge, lamps binary and frozen when stale, crowding sign, logon ('LISTEN ONLY' only with a passive source). |
| `theme-whitehall.sh` | **Whitehall.** Exercise banner per kind of source (every line with a disclaimer), plot-freshness lamps against Python, teleprinter logon (fixed character rate), plot clock from `generated`, own-ship symbol, mark for new plots, the sky keeps turning. |
| `theme-foundation.sh` | **Foundation.** Dust cohesion by freshness, gold only for the alarm, no spiral ornament (grid tokens spokes and dots only), core heartbeat (not with reduced motion, not in other themes), Compendium line and Vault card without names and without a P10 word. |
| `display-parity.sh` | **Dashboard = page.** The summary's figures = the page's `stats()` on every fixture; the strongest channel = `crowdingOf()` on the fixtures and on generated tie and edge documents; the air block = `airQuality()`; red only for an alarm, green nowhere (on the top screen the security field decides, never the SSID text); `GEN` counts only new captures; line template; no LED, buzzer or network commands. |
| `doc-binding.sh` | **Specification = code.** Spec §3.8 and §7.0a deep-equal via `spec-sync.py --check` (with a negative control), every `STARCHORUS` function in §10, every key in §9.6, every query parameter in §2.7, versions of page, spec and dashboard equal; `CONTRIBUTING.md` makes the passivity check binding for every PR and the regression binding before the merge; `SECURITY.md` and the payload README describe the dashboard's outputs. |
| `small-screen.sh` | **Small screen 760×600.** Intersection 0 in all themes with and without the detail and with the Air/Time/Record drawers; `#stats` remains a real panel, the channel bar docks. |
| `theme-details.sh` | **Theme details.** Intro style and one session mark per theme ID (every theme shows its logon), the condensing intro, the lamp strip per AP, the plaque tooltip, lit dust, plate chrome, small capitals and caption; there is exactly one audio path. |
| `text-budget.sh` | **The text budget belongs to the data.** In all themes and both views every counted `fillText` is an AP name, as many as the budget of 30/24 allows; fixed texts (centre, 3D ring dBm, WarGames cursor) are baked sprites; fallback to the counted path for a centre text over 32 characters. |
| `station-inventory.sh` | **Decision points for stations.** The fourteen source locations where the page decides whether a key may be a station, with an exact hit count, and the behaviour on `many-clients.json` (identity, note, import, history, freshness and export accept stations). If a location changes without a decision, the table turns red. |
| `station-models.sh` | **Stations get the APs' models.** Freshness per station against Python (`aged.json`), arrival and departure only from consecutive captures, the caps (`HIST_CL_MAX`, `BASELINE_CL_MAX`, strongest first), baseline and ghosts for stations (RSSI only, never 'gone' without hop data), the page version. |
| `station-tools.sh` | **Identity, notes and homing for stations.** The gate `observed()` (present and baseline station yes, unknown key no), a station's classification and note survive a reload, rules and bulk assignment with `suspect`, `IDENT_MAX` (full = reject), the page version. |
| `station-outputs.sh` | **Stations in the export.** Stations as rows of their own in JSON and CSV with their AP association; own transmitters and phone hotspots never as an association, no note text; the dashboard's station screen (MACs, regex-free, strongest first); neutral language in the export; version 0.1.0 at every location (page, spec §10, script headers, `device-probe.sh`, README). |
| `stop-scope.sh` | **`stop` ends only its own processes** (Chrome-free). Behaviour probe with stand-ins in a throwaway directory: `starchorus-serve.sh stop` ends its loop, that loop's `nc` and the processes of its own handler file, and leaves other `netcat` processes alive; the root `payload.sh` writes the PID of its own `httpd` and ends only that. Bind: with a stand-in `ip`, both scripts listen on the `br-lan` address by default, on an explicit address, or on `0.0.0.0` only for `all` (with the `172.16.52.1` and `127.0.0.1` fallbacks); an `nc` without `-s` does not start unless `all`; the stop matcher takes `-p ADDR:PORT` and `-p PORT` of our directory only; statically, no server start line in the three scripts listens on every interface by default. |
| `payload-ui.sh` | **Operating the device payload** (Chrome-free). The payload under `library/` runs for real, against stand-ins in a throwaway directory: one UI script for every UI command, which logs its calls and takes its answers from a file (at the end 'cancel', never waiting), each run with a 20 s limit and a PATH without a web server. Checked: defaults without a file (also under `dash`), settings file applied, environment before file, a hostile file (invalid values, foreign keys, `$(…)`, CRLF) without effect and without an executed command, `set`/`get`/`reset` with exit 2 and an unchanged file, the menu saves and shows the value, preselection of the switches, cancel and empty answers change nothing, 'All' and a window over 6 h only after yes, start only after yes, 'Auto dash', all services off, the device gate (arguments and `STARCHORUS_PAYLOAD_PLAIN=1` call no UI command), page on the configured port with status and a narrow stop, the `bind` key (set/get/reset, refusals, environment) and the address the page server listens on (stand-in `ip`), statically no path to the active scan, no `source`/`eval`, `shellcheck -s sh`, lengths of the menu texts; the self-contained route (a bundle directory with the payload installs itself once into an empty `STARCHORUS_DIR`, scripts made executable, `_PAYLOAD_HOME` honoured, never over an installed collector, nothing without `index.html` or in the same directory, a failed copy exits 1 without a collector, one LOG line on the device). |
| `hak5-package.sh` | **The package for Hak5's library** (also T1). `tools/hak5-package.sh` into a temp directory (path with a space, called from `/`): exactly the seven files and no other file or directory, scripts executable, `--list` = the map typed in the drop-in; every file byte-identical to its repo source; the payload header (`Title`, `Description`, `Author`, `Version` = the page's, `Category: reconnaissance`, shebang, SPDX); no e-mail address, home directory or key in any file, no remote URL in the scripts, the README's required statements (project link, trademark sentence, licence, menu path, network exposure) without repo-relative links, `LICENSE` = GPL v3; a rebuild drops a stale file, differing dashboard copies and a missing source are refused; the packaged payload installs itself into an empty data directory (`get`/`set`, nothing started) with `settings.conf` beside the files. |
| `data-oracle.sh` + `evals/data-oracle.js` | **Data oracle.** All fixtures and hand documents in both `essMerge` modes, page against model; `devices.json` against the documented ground truth; fixture copies with a broken ground truth must be red; a page copy with three planted faults must be red in exactly the expected classes. Known open findings are held on both sides in `ORC_KNOWN_OPEN` (new = red, healed = red 'please remove'). |
| `doc-truth.sh` | **Documentation truth** (Chrome-free): one row per `doc-truth.py` check, plus `probes bite`: in a copy of the tree one break per check (unlisted script, renamed source literal, wrong number in the fixture table, version bump in only one script header, swapped run list …); each must go red, the controls must stay green, and the unchanged copy must be green beforehand. |
| `hook-behavior.sh` | **The hook stops a violation.** In a throwaway repo made from a copy of the tree: a neutral commit under `tools/` goes through, a staged `fetch(…,{method:"POST"})` in the page is refused (HEAD unchanged). |
| `ingest-fuzz.sh` + `evals/ingest-fuzz.js` | **Ingest fuzz.** Every mutant from `fuzz-doc.py` (2D and 3D): `load()` never throws, a rejected document leaves the display standing, no errors, everything finite, `Object.prototype` untouched. SSID sinks (tooltip, detail, source, legend, chanbar, paste dialogue) run no script, and the escaped text must be there (positive anchor). The probe bites (a page copy without escaping must be red); the dashboard under the real `jq` against hostile SSIDs with a canary file and a positive control; a ratchet on `innerHTML` assignments. Known open findings in `FUZ_KNOWN_OPEN`. |
| `net-runtime.sh` | **Runtime network proof.** `verify.sh` loads the page with `many-clients.json` over three polls; `net_verdict` judges the `requests` from `cdp.py` and, as a cross-check, the server log: only `GET`, only its own origin, only `/`, `/starchorus.json`, `/favicon.ico` or `data:`. A page copy with an appended POST and an image on `127.0.0.1:9` must be red. |
| `order-invariance.sh` + `evals/order-invariance.js` | **Order invariance.** Every fixture unchanged and shuffled with ten fixed seeds (`aps[]`, `clients[]`, `unassociated[]`, only lists with at least five entries); the canonical digest (node positions, geometry fields of `layoutInfo()`, counters of `stats()`) must stay the same. The eval empties the page's maps before every load. The shuffler proves itself, and a page copy without sorting must be red. Known open findings in `ORD_KNOWN_OPEN`. In addition, a poll of the same capture in a running page does not relay out (no iterations, no movement of free stations). |
| `mutation-probe.sh` | **Mutation probe** (Chrome-free, T2): `passivity-mutate.sh` (every mutation and alternative) and `--meta`. |
| `preflight.sh` | **Preflight** (also T1). With a PATH of symlinks to every tool except the one under test, in probe mode `STARCHORUS_PREFLIGHT_ONLY=1`: without `jq` both scripts exit 2 with exactly one `MISSING` line, without `sqlite3` T1 is in order and T2 exits 2, with `ALLOW_NO_SQLITE=1` in order; the real collector self-test without `sqlite3` is judged `NOT COVERED` (T2 only). |

## Fixtures

The fixtures in `tests/fixtures/` are the contract corpus: synthetic documents in the collector's
JSON contract, all generated by `gen-testdata.py`. `doc-truth.py fixtures` checks the sizes in this
table against the files.

| Fixture | Content |
|---|---|
| `many-clients.json` | 25 APs (10 with `clients[]`), 180 free clients, some with `vendor`, extras (`rate`, `width`, `phy`, `randomized`), hidden SSIDs |
| `few-clients.json` | 6 APs (3 with `clients[]`), 5 free clients, some with `vendor` |
| `legacy.json` | 12 APs (5 with `clients[]`), 30 free clients, **exactly the base contract** without optional fields |
| `field-scale.json` | 120 APs, 1200 free clients, `clients[]` empty (as on the database path), some with `vendor`, `last_seen` |
| `empty-none.json` | `source: "none"` with `note`, empty arrays (collector without a source) |
| `single-ap.json` | 1 AP, 0 free clients |
| `devices.json` | 18 APs, ground truth of the device grouping: 3 device clusters, 2 roaming ESSs (built by hand, `--devices`) |
| `field-probes.json` | 60 APs, 500 free clients, some with `probes[]` |
| `active.json` | 24 APs (10 × 2.4 / 12 × 5 / 2 × 6 GHz), **`source: "iw-scan-ACTIVE"`** like the collector's active opt-in scan (`STARCHORUS_ALLOW_ACTIVE=1`): APs only, no clients, the collector's security words, hidden SSIDs, several ESSID groups; `--source iw-scan-ACTIVE --aps 24 --vendor-frac 0.5 --seed 158` |
| `aged.json` | 14 APs (2 with `clients[]`), 2 free clients (5 × 2.4 / 6 × 5 / 3 × 6 GHz), `last_seen` at hand-picked ages against `generated`: every freshness level T0–T3 and 'undated' on both sides of every boundary, plus five stations, one per level (`--aged`) |
| `field-probes-aged.json` | 60 APs, 500 free clients (25 × 2.4 / 32 × 5 / 3 × 6 GHz), like `field-probes.json` but with a mean age of 600 s: all four freshness levels visible |
| `secsuite.json` | 11 APs (2 with `clients[]`), 1 free client (5 × 2.4 / 5 × 5 / 1 × 6 GHz), one AP with `akm`/`cipher`/`auth` per security class, a multiple responder, `channels[]` and the centre extras, like the collector's output on the database path (`--secsuite`) |

**Regenerating.** These commands regenerate every fixture byte for byte (from the repo root).
`--stamp` adds a deterministic `last_seen` per AP for `source: "recon-db"` (mean age 90 s or
`--stamp-mean`) and removes `last_seen` for other sources. The call for `active.json` appears only
once, as `ACTIVE_GEN` in `static.sh`; a row there compares the generator output with the file byte
for byte.

```sh
g() { python3 tools/gen-testdata.py "$@"; }; X=tests/fixtures
g --aps 25 --clients 180 --assoc-frac 0.4 --vendor-frac 0.6 --extras --hidden-frac 0.1 \
   --source airodump-csv --seed 7 --out $X/many-clients.json && g --stamp $X/many-clients.json
g --aps 6 --clients 5 --assoc-frac 0.5 --vendor-frac 0.6 --source airodump-csv --seed 11 --out $X/few-clients.json
g --aps 12 --clients 30 --assoc-frac 0.4 --legacy --source airodump-csv --seed 3 --out $X/legacy.json
g --aps 120 --clients 1200 --vendor-frac 0.5 --seed 42 --out $X/field-scale.json && g --stamp $X/field-scale.json
g --source none --out $X/empty-none.json
g --aps 1 --clients 0 --vendor-frac 1 --seed 5 --out $X/single-ap.json && g --stamp $X/single-ap.json
g --devices --out $X/devices.json && g --stamp $X/devices.json
g --aps 60 --clients 500 --vendor-frac 0.5 --probe-frac 0.45 --seed 11 --out $X/field-probes.json \
   && g --stamp $X/field-probes.json
g --aps 60 --clients 500 --vendor-frac 0.5 --probe-frac 0.45 --seed 11 --out $X/field-probes-aged.json \
   && g --stamp $X/field-probes-aged.json --stamp-mean 600
g $(sed -n 's/^ACTIVE_GEN="\([^"]*\)".*/\1/p' tools/static.sh) --out $X/active.json
g --aged --out $X/aged.json
g --secsuite --out $X/secsuite.json
```

The tables and the order of the random draws in `gen-testdata.py` belong to the fixtures: whoever
changes them changes every generated fixture and regenerates them in the same commit. The hand-built
documents (`--devices`, `--aged`, `--secsuite`) carry their ground truth in the header of
`gen-testdata.py`; `data-oracle.py truth` reads it from there.

**Parameters of `gen-testdata.py`:** `--aps N`, `--clients N` (free clients), `--assoc-frac`
(share of APs with a filled `clients[]`; the rest stay empty, as on the database path), `--vendor-frac`,
`--random-frac` (randomised MACs, second hex digit 2/6/A/E, never with `vendor`), `--hidden-frac`,
`--extras`, `--legacy`, `--probe-frac F` (share of free clients with `probes[]`; about 60 % of them name
a visible network), `--source recon-db|airodump-csv|tcpdump|iw-scan-ACTIVE|none` (`tcpdump`, like
the collector, supplies only BSSID, SSID and RSSI; `iw-scan-ACTIVE` imitates the active opt-in scan:
APs only, no clients, no extras), `--note`, `--center`, `--seed`, `--generated now|TS`, `--compact`,
`--out`; and also `--devices`, `--aged`, `--secsuite`, `--stamp FILE [--stamp-mean S]`. `--validate FILE`
checks a file against the contract, including `source` (only values the collector writes), unknown
keys at the top level and in `center`, and the shape of `none` and `iw-scan-ACTIVE` (with `--legacy`
against the base contract).

## Examples

```sh
# generate test data (deterministic via --seed)
python3 tools/gen-testdata.py --aps 25 --clients 180 --assoc-frac 0.4 \
    --vendor-frac 0.6 --extras --source airodump-csv --seed 7 --out /tmp/starchorus.json

# check a file against the contract (exit 1 on a violation)
python3 tools/gen-testdata.py --validate tests/fixtures/many-clients.json
python3 tools/gen-testdata.py --validate tests/fixtures/legacy.json --legacy

# verify the page with a fixture: screenshot + report to out/many.*
tools/verify.sh starchorus.html tests/fixtures/many-clients.json out/many

# demo mode (without starchorus.json; the 404s for it are filtered out)
tools/verify.sh starchorus.html demo out/demo

# extra arguments are passed through to cdp.py
tools/verify.sh starchorus.html tests/fixtures/field-scale.json out/scale \
    --eval "window.STARCHORUS && STARCHORUS.stats()" --click 720,450 --key Escape

# cdp.py directly (needs its own server)
python3 -m http.server 8123 --bind 127.0.0.1 --directory /path/with/index.html &
python3 tools/cdp.py http://127.0.0.1:8123/ --shot out.png --wait 5 --fps 2 \
    --eval "document.title" --json

# runs of your own with the harness
. tools/harness.sh
runq "$F/devices.json" "?theme=whitehall&intro=0" out/x --eval "STARCHORUS.errors().length"; chk out/x.json
runseq "$F/active.json" out/seq --eval "await STARCHORUS.wait(300), STARCHORUS.stats().source"
runq "$F/many-clients.json" "?intro=0&poll=0&spin=0" out/t --fps 0 \
    --eval "$(ev3 'STARCHORUS.perf().drawCalls.fillText')"      # → {"foundation":n,"wargames":n,"whitehall":n}
# ordered steps after the evals: click a node, check the state, change the viewport
runq "$F/devices.json" "?intro=0&poll=0&spin=0" out/click --fps 0 \
    --step "clickat:(()=>{const n=STARCHORUS.nodeScreen('44:4e:6d:aa:bb:10');return [n.sx,n.sy]})()" \
    --step "eval:STARCHORUS.node('44:4e:6d:aa:bb:10').pinned" --step size:1000x640 --step "eval:innerWidth"
```

`verify.sh` prints a summary (fps, error count raw/filtered/real, exceptions, eval results). Under
`?fixed=…` from boot no node fades in (dt = 0): label and budget evals in `runseq` runs begin with
`--eval "$EV_THAW"`. `--eval-timeout` (30 s) applies per eval; `--step` runs after the `--eval`s and
before the screenshot.

## Limits: what the nets do not see

- **Source ≠ runtime.** T1 and `passivity-check.sh` read text. A request assembled at run time is
  seen only by `net-runtime`, and only during its observation time (about 14 s, one fixture, one
  browser). Sinks with a name computed at run time, and other ways of running text as code (`eval(`,
  `new Function(`, `setAttribute('on…')`), are not seen by the static ratchet.
- **Development `sh` ≠ BusyBox `ash`.** Everything runs under the development machine's `sh`; nothing
  here is measured under BusyBox (NUL, buffer limits and the `awk` dialect may differ). The collector
  self-test under BusyBox belongs to T3.
- **Development `jq` ≠ device `jq`.** `jq-noregex` simulates the missing regex library; whether the
  building blocks used run on the device is shown only by T3.
- **Headless software raster ≠ GPU.** fps, `fillText` budgets and pixel checks run in the software
  raster; real GPU rendering and other browsers are not measured.
- **A second reading ≠ proof of the rule.** The data oracle finds differences between page and model,
  not a rule that is wrong in both. A rule boundary that neither a fixture nor a hand document touches
  is not proven. The page counts SSID lengths in UTF-16 units, the model in code points; the fixtures
  are ASCII.
- **The fixtures are the corpus.** No fixture carries `source: "tcpdump"`; the collector's `Secured`
  path is entered by no page run (the exception is recorded with its reason in
  `regress.d/doc-truth.sh`, and `doc-truth.py census` reports it as soon as a fixture covers it). No
  row checks that dashboard and page have the same defaults (missing `rssi`, `Secured`).
- **Documentation truth binds numbers, not sentences.** `doc-truth.py prose` reads no numbers written
  out in words and no statement that runs over more than one line break; new files under `tools/`
  are not checked against the passivity file list (`tools/*` is exempted there as a whole).
- **The hook is an excerpt.** It runs only for staged paths on the check list and only with the T1
  scope; a commit that stages only documentation skips it, and `doc-truth` is T2.
- **A run is a measurement.** Under load a Chrome run may fail to deliver a report; a repeat on the
  same tree is the evidence, not a code change.

## Conventions for maintainers

1. **No new row without a negative probe in the same commit.** Make the break (first show with
   `grep -c` that the broken place exists), quote the red output, revert, green again. The probe
   breaks something a person might really build; only the **expected** rows go red; the copy must
   boot without errors beforehand. Where possible, as a standing row ('… bites') in the drop-in,
   otherwise as a probe in the commit message.
2. **Mutations are text copies.** A deliberately broken collector, dashboard or page with transmit
   code is never executed: in mutation copies only `sh tools/passivity-check.sh` runs; mutated pages
   run only in headless Chrome against `127.0.0.1` (target `127.0.0.1:9`).
3. **Loosen nothing.** Changes to `passivity-check.sh` and the denylists make rules tighter or keep
   them as strict. If a function needs a word that `NETX` forbids, do it through a function-bound
   allowlist on the pattern of `SEC6_FUNCS`/`scoped()`, with a mutation 'stays red outside', not
   through a further regex alternative.
4. **Raise floors only; lower baselines and budgets only.** Every `MIN_*` floor carries its
   measuring command in its comment; the opposite direction needs a reason in the commit message. No
   pin on the current value where a floor will do.
5. **Numbers only derived or dated.** A number in prose, a comment or a row name is recounted by a
   row or carries 'as of <version>'. Measured times do not belong in row names (otherwise the name
   lists of two runs are never equal), but in the timing file via `tm_note`.
6. **`--no-verify` only with a reason and substitute evidence in the commit message** (which rows
   ran instead, with their output). If the hook is not active, `git config --show-origin --get
   core.hooksPath` shows where the value comes from (a worktree-local value overrides the repo's).
7. **Never upgrade a tool in the same commit as code.** Versions are printed, not enforced; the
   commit that upgrades a tool names the old and the new version and changes nothing else.
8. **Finding before fix.** A real fault in the page, collector or dashboard is reported with
   evidence, not fixed in a tools commit; known open findings are held on both sides in a
   `*_KNOWN_OPEN` list (new = red, healed = red 'please remove').
9. **Rows that legitimate work can turn red say in their FAIL output what to adjust**
   ('please remove', 'extend the list'). The section slices (`sec_slice`/`sec_grepc`) hang on the
   page's section numbers: whoever inserts, deletes or renumbers sections updates the pairs as well;
   a broken pair reports itself as `NOSLICE`.
10. **Do not check a single line by regex when a runtime property can be checked**; no section slice
    or comment stripper of its own in a drop-in (use the helpers from `harness.sh`).
11. **Portable and self-sufficient.** No `sed -i` (always `sed … f > f.new && mv f.new f`); no
    absolute paths in `tools/**`; runnable from any working directory and from a
    fresh clone (`fresh-check.sh`).
12. **Before the commit, a read-through along three lines:** passivity and legal rules (has a rule
    been widened? is there transmit vocabulary in an executable path? denylist, synthetic data,
    neutral language), tooling (fresh clone, another working directory, spaces in the path,
    `shellcheck -s sh`), software (the mutation of the new row seen red; the fix is not itself a gap).
13. **Commit form:** one step, one commit; no commit on a red regression; named files only.
    Body: the gap (with the command that shows it), the change, the evidence (negative probe with red
    output, numbers with their origin), 'deliberately not done'.
