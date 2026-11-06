# Repository map

An index for working in pieces: where each part of the repository is found with `grep`, which drop-ins cover it,
and which documents a change touches. It describes nothing. What each part is: `docs/ONBOARDING.md` (The parts);
what a page fragment holds: `docs/architecture.md` §1; what a tool or a drop-in does: `tools/README.md`. The
tables are read by `tools/affected.sh` and held to the tree by the drop-in `repo-map`, which runs in T1 and in the
full run.

## How to work in pieces

1. **Find the part.** `grep -n -F 'NAME' docs/MAP.md` gives its row and every drop-in that names it. Read only the
   span you need: `grep -n -F 'ANCHOR' FILE`, then `sed -n 'A,Bp' FILE`. A line of the built page:
   `sh tools/build-page.sh --where N`.
2. **Change it.** A page fragment lives under `src/`: edit it, run `sh tools/build-page.sh`, and stage the fragment
   together with the rebuilt `starchorus.html`.
3. **Run what it reaches.** `sh tools/affected.sh` names the drop-ins that the paths changed against `HEAD` reach
   (or name the paths: `sh tools/affected.sh PATH...`); `--run` runs them alone. One drop-in alone:
   `sh tools/quick.sh only NAME`.
4. **Commit.** The hook runs T1 for code and the documents mode for documents; a document the code filter names by
   path, such as this map or `tools/README.md`, gets both, and a commit that adds or deletes a Markdown file or a
   shell script runs T1 as well (`repo-map` keeps the map true to the tree).
5. **The gate.** Before a push or a release the full run, `sh tools/regress.sh PREFIX`, is the gate. The list of
   `tools/affected.sh` only says where to start: a drop-in that runs the whole page sees every fragment, and
   `--wide` adds those.

## Editing this map

- The tables below are read by machine. A row is one line; its cells are separated by a vertical bar; the
  first cell is one code span, its key. Keys, paths, anchors and subjects are code spans, one blank apart, with no
  backtick or vertical bar inside; nothing else stands between them. A cell without anchors is empty.
- A path is written from the top of the repository. In a group or a subject, `*` matches any run of characters
  within one directory level. Any other code span that looks like a path must exist too, so a placeholder is
  written in angle brackets: `tools/regress.d/<name>.sh`.
- An anchor is a fixed string that occurs in its file; the anchors of a region occur inside the region. Anchors are
  given for long files and for regions; a short file is read whole.
- A region is named by the start of its title, the text after the run of `-` or `=` of its marker line. The rows of
  a script follow its marker lines in order. A copy of a script that is identical byte for byte has no rows.
- A drop-in's subjects are group words, fragment names and paths. The drop-in `repo-map` checks what a drop-in's own
  text shows: its section slices name their fragments, a Chrome run or a read of the page names `page`, and every
  file of the repository that its text names is covered by a subject.
- No counts. Sections of the specification are written §N.N.

## Groups

A word for a set of paths, used as a subject of the drop-ins below. A changed path reaches a drop-in when it is
the drop-in's own file, when a group, fragment or path that the drop-in names covers it, or when it belongs to
`all`, which reaches every drop-in. A changed `starchorus.html` counts as `page` unless a path under `src/` changed
with it: the page is their build, and T1 proves that they agree. `tools/affected.sh` applies these rules.

| Group | Paths |
|---|---|
| `page` | `starchorus.html` `src/PAGE.list` `tools/build-page.sh` `tools/cdp.py` |
| `collector` | `starchorus-collect.sh` |
| `overview` | `starchorus-display.sh` `library/user/reconnaissance/starchorus/starchorus-display.sh` |
| `payload` | `payload.sh` `library/user/reconnaissance/starchorus/payload.sh` `library/user/reconnaissance/starchorus/alert-deauth.sh` |
| `serve` | `starchorus-serve.sh` |
| `fixtures` | `tests/fixtures/*` |
| `hooks` | `.githooks/pre-commit` `tools/install-hooks.sh` |
| `docs` | `*.md` `docs/*.md` `library/user/reconnaissance/starchorus/README.md` `packaging/hak5/README.md` `tools/README.md` `tools/bench/README.md` `.github/PULL_REQUEST_TEMPLATE.md` |
| `tools` | `tools/*` `tools/evals/*` `tools/regress.d/*` |
| `all` | `tools/harness.sh` |

## Page fragments

One row per line of `src/PAGE.list`, in build order; a fragment's name is its file name without the extension
(`37-ui`, `head`). What each fragment holds: `docs/architecture.md` §1.0 (the build), §1.1 (head and CSS), §1.2
(DOM), §1.3 (JavaScript).

| Fragment | Anchors |
|---|---|
| `src/shell/head.html` | `<title>Starchorus</title>` |
| `src/css/00-embedded-font.css` |  |
| `src/css/01-reset-base.css` |  |
| `src/css/02-theme-tokens.css` | `--surface-base:` |
| `src/css/03-panels-hud.css` | `.panel::before, .panel::after {` `:root[data-banner="on"] {` `#masthead .badge {` `#stats .cell {` `#source .desc {` `.legrow {` `#scope-foot .l` |
| `src/css/04-controls.css` |  |
| `src/css/05-tooltip-detail.css` |  |
| `src/css/06-channel-bar.css` |  |
| `src/css/07-crt-overlays.css` |  |
| `src/css/08-logon.css` |  |
| `src/css/09-responsive-motion.css` | `@media (max-width: 1099px)` `@media (pointer: coarse)` `:root[data-phone="on"] {` `#sheet-grab {` `:root[data-scope=on]` |
| `src/shell/css-end.html` |  |
| `src/html/10-stage.html` |  |
| `src/html/11-masthead-stats.html` |  |
| `src/html/12-source.html` |  |
| `src/html/13-legend.html` |  |
| `src/html/14-controls.html` | `id="sheet"` `id="controls"` `id="grp-bands"` `id="t-random"` `id="t-scope"` `id="cam"` |
| `src/html/15-channel-bar.html` |  |
| `src/html/16-tooltip-detail.html` |  |
| `src/html/17-paste-dialog.html` |  |
| `src/html/18-intro.html` |  |
| `src/html/19-help.html` |  |
| `src/shell/js-begin.html` |  |
| `src/js/20-config.js` | `const LAYOUT = {` `const KEYS = [` `const CLOUD = {` `const SCOPE =` `const POLL =` |
| `src/js/21-themes-encoding.js` | `THEMES.foundation = {` `THEMES.wargames = {` `THEMES.whitehall = {` `const ENCODING = {` `const CSS_MIRROR =` `function validateTheme(` `function applyTheme(` |
| `src/js/22-util.js` |  |
| `src/js/23-normalize.js` | `function normalizeDoc(` `function normClient(` `function normBt(` `function normRid(` `function demoData(` |
| `src/js/24-state.js` | `const S = {` `const PERSIST_KEYS =` |
| `src/js/25-ingest.js` | `function ingest(` `function applyAffinity(` `function eventsSettle(` `function rebuildOrders(` |
| `src/js/26-layout-2d.js` | `function placeAPs(` `function orbitOfClient(` `// --- spread relaxation` `function settleLayout(` `function layoutInfo(` `// §9.8b the Scope` `function scopePlace(` |
| `src/js/27-aggregation.js` |  |
| `src/js/28-layout-3d-camera.js` | `function p3Of(` `function projectAll(` `function stepCamera(` `function setView(` |
| `src/js/29-analyzer.js` | `// ---- Baseline (persisted` `// ---- Watchlist (SSIDs only` `// ---- Homing (browser side)` `// ---- channel/air/history/replay models` `// §8.8 G1` `// §8.8a random clouds (model` `function rebuildBt(` |
| `src/js/30-step.js` | `function tick(` `function stepNodes(` `function budgetBegin(` `function resize(` |
| `src/js/31-sprites.js` | `function getSprite(` `function bakeSprite(` |
| `src/js/32-particles.js` | `function spawnPass(` `function stepParticles(` `function drawParticles(` `function stepFlares(` |
| `src/js/33-render-pipeline.js` |  |
| `src/js/34-render-layers.js` | `function drawBackground(` `function drawScope(` `function drawEdgesWargames(` `function drawClients(` `function drawBt(` `function drawStars(` `function drawFlares(` |
| `src/js/35-render-hud.js` | `function labelCandidateList(` `function drawHud(` |
| `src/js/36-interaction.js` | `function nodeAt(` `const KEY_ACT =` |
| `src/js/37-ui.js` | `// ---- inventory drawer` `// ---- export (text formats` `// ---- drawers: air quality` `function buildLegend(` `function openDetail(` `function layoutEdges(` `// ---- §9.8 phone mode` |
| `src/js/38-data-source.js` | `function tryPoll(` `function loadData(` `function setSourcePanel(` `function dtgTick(` |
| `src/js/39-intro.js` |  |
| `src/js/40-debug-api.js` | `function statsObj(` `const CONTRAST_PAIRS =` `window.STARCHORUS = Object.freeze({` |
| `src/js/41-boot.js` | `(function boot() {` |
| `src/shell/js-end.html` |  |

## Scripts

The programs outside `tools/`. What each one is: `docs/ONBOARDING.md` (The parts); what the collector may read and
run: `SECURITY.md` and `docs/architecture.md` §14.6; the screens and keys of the Overview: `docs/display-paths.md`;
the payload: `library/user/reconnaissance/starchorus/README.md`.

| Script | Anchors |
|---|---|
| `starchorus-collect.sh` | `# Version:` `# Contract:` `PASSIVITY CONTRACT` `# CONFIG (override via environment` `# OPTIONAL JSON FIELDS` |
| `starchorus-display.sh` | `# Version:` `# Contract:` `JQ_SUMMARY=` |
| `library/user/reconnaissance/starchorus/starchorus-display.sh` | `# Version:` |
| `starchorus-serve.sh` | `# Version:` `stop_serve() {` `<<'HANDLER_EOF'` `serve_exit() {` |
| `library/user/reconnaissance/starchorus/payload.sh` | `# Version:` `# Contract:` |
| `payload.sh` | `# Version:` `web_prepare()` |
| `library/user/reconnaissance/starchorus/alert-deauth.sh` | `# Version:` `# Contract:` |
| `.githooks/pre-commit` | `verdict()` `run_docs()` |

## Regions

A region runs from a marker line of a script to the line before the next one.

| Script | Region | Anchors |
|---|---|---|
| `starchorus-collect.sh` | `configuration` | `interval_value()` `max_age_value()` `alert_window()` |
| `starchorus-collect.sh` | `small helpers` | `clean_ctrl()` `pid_ours()` `replace_loops()` |
| `starchorus-collect.sh` | `--stop / --status` | `stop_instances()` `status_instances()` |
| `starchorus-collect.sh` | `interface setup` | `mgmt_iface()` `setup_monitor_iface()` |
| `starchorus-collect.sh` | `recon DB locate` | `find_recon_db()` |
| `starchorus-collect.sh` | `source decision` | `resolve_source()` |
| `starchorus-collect.sh` | `capture: start` | `start_airodump()` |
| `starchorus-collect.sh` | `teardown` | `cleanup()` |
| `starchorus-collect.sh` | `BLUETOOTH: ONE PASSIVE LE SCAN WINDOW PER CYCLE` | `bt_begin()` `bt_end()` `bt_blue5_read()` `bt_sweep()` |
| `starchorus-collect.sh` | `reading a window` | `AWK_BT=` `bt_parse()` `bt_judge()` |
| `starchorus-collect.sh` | `the per-cycle layers` | `AWK_LAYERS=` `add_layers()` `run_layers()` |
| `starchorus-collect.sh` | `AWK LIBRARIES` | `AWK_JSON_HELPERS=` |
| `starchorus-collect.sh` | `VENDOR LOOKUP` | `setup_vendor()` `setup_btco()` `btco_fill()` `AWK_VENDOR=` |
| `starchorus-collect.sh` | `cache write serialisation` | `cache_lock()` `add_vendor()` `vendor_merge()` |
| `starchorus-collect.sh` | `JSON: airodump CSV` | `build_from_csv()` |
| `starchorus-collect.sh` | `JSON: tcpdump burst` | `build_from_tcpdump()` `parse_tcpdump_text()` |
| `starchorus-collect.sh` | `JSON: recon DB` | `recondb_query()` `recon_workcopy()` |
| `starchorus-collect.sh` | `encryption_info -> security label` | `AWK_SEC=` `AWK_RECONDB=` `build_from_recondb()` |
| `starchorus-collect.sh` | `JSON: the AP service's own recon lists` | `AWK_PINEAP=` `build_from_apcli()` |
| `starchorus-collect.sh` | `JSON: iw scan (ACTIVE!)` | `build_from_iwscan()` |
| `starchorus-collect.sh` | `spec §14.6: the AP-service CLI allowlist` | `apcli_ro()` `apcli_selftest()` |
| `starchorus-collect.sh` | `survey rows, channels[], center extras` | `channels_json()` `add_center()` `doc_whole()` |
| `starchorus-collect.sh` | `empty document` | `write_empty()` |
| `starchorus-collect.sh` | `recon.db: a cycle with nothing new` | `recon_unchanged()` `wl_apply()` |
| `starchorus-collect.sh` | `one cycle` | `run_cycle()` |
| `starchorus-collect.sh` | `the loop's pace, and the hourly line` | `pace_begin()` `cycle_step()` |
| `starchorus-collect.sh` | `selftest support for the Bluetooth window` | `bt_tmo()` `bt_stub()` |
| `starchorus-collect.sh` | `selftest: reading a window` | `bt_parse_selftest()` |
| `starchorus-collect.sh` | `selftest: the per-cycle layers` | `lay_selftest()` |
| `starchorus-collect.sh` | `selftest: the window against stand-ins` | `bt_selftest()` |
| `starchorus-collect.sh` | `SELF TEST` | `json_ok()` `selftest()` `usage()` |
| `starchorus-collect.sh` | `main` | `echo $$ > "$LOOP_PIDFILE"` `cycle_step` |
| `starchorus-display.sh` | `device command shims` | `keyname()` `ov_reader()` `ov_cleanup()` |
| `starchorus-display.sh` | `data access (jq, read-only)` | `fetch()` `JQLIB=` `jq_healthy()` |
| `starchorus-display.sh` | `screens` | `screen_summary()` `screen_bluetooth()` `alert_line()` |
| `starchorus-display.sh` | `the frame that ends every draw` | `stale_line()` `frame()` |
| `starchorus-display.sh` | `--selftest (read-only device check)` | `display_selftest()` |
| `starchorus-display.sh` | `main loop` | `render()` `step()` |
| `library/user/reconnaissance/starchorus/payload.sh` | `device UI shims` | `ui_pick()` `pl_install()` |
| `library/user/reconnaissance/starchorus/payload.sh` | `processes: identity, pidfiles, servers` | `pl_pidof()` `pl_fast_stop()` `stop_servers()` |
| `library/user/reconnaissance/starchorus/payload.sh` | `start, status` | `pl_serve()` `pl_col_launch()` `pl_status()` `pl_skew()` |
| `library/user/reconnaissance/starchorus/payload.sh` | `menu (device only)` | `pl_overview()` `pl_wait_up()` `pl_start_flow()` |
| `library/user/reconnaissance/starchorus/payload.sh` | `Settings (2.5)` | `pl_save()` `pl_set_page()` |
| `library/user/reconnaissance/starchorus/payload.sh` | `Alerts (2.5a)` | `pl_alert_install()` `pl_settings()` `pl_menu()` |
| `library/user/reconnaissance/starchorus/payload.sh` | `dispatch` | `pl_start; exit $? ;;` |
| `payload.sh` | `pick a static file server` | `serve()` `our_servers()` |

## Tools

Every file under `tools/` except the drop-ins and the documents; a key that ends in `/` covers the files below it.
What a tool does: `tools/README.md` (Tools).

| Tool | Anchors |
|---|---|
| `tools/affected.sh` | |
| `tools/build-page.sh` | |
| `tools/cdp.py` | `def find_chrome(` `def main(` |
| `tools/check-colors.py` | `def oklab(` |
| `tools/data-oracle.py` | `def model(` `def judge(` `def truth(` `def selftest(` |
| `tools/denylist-check.sh` | `--extended` `--selftest` |
| `tools/denylist-cs.txt` | |
| `tools/denylist-words.txt` | |
| `tools/denylist.txt` | |
| `tools/device-probe.sh` | `# Starchorus device-probe` |
| `tools/doc-truth.py` | `def listing(` `def chk_lists(` `def chk_fixtures(` `def chk_prose(` `def chk_figures(` `def chk_contract(` |
| `tools/dump-themes.sh` | |
| `tools/env-expected.txt` | |
| `tools/evals/` | |
| `tools/fresh-check.sh` | |
| `tools/fuzz-doc.py` | `def page_fields(` `def build(` |
| `tools/gen-testdata.py` | `def build_devices_doc(` `def build_alerts_doc(` `def build_radio_doc(` `def build_remote_id_doc(` `def validate(` |
| `tools/hak5-package.sh` | |
| `tools/harness.sh` | `runq() {` `sec_slice() {` `selftest_verdict() {` `preflight() {` `tm_begin() {` |
| `tools/install-hooks.sh` | |
| `tools/install.sh` | `usage()` `--dry-run` |
| `tools/passivity-check.sh` | `scoped() {` `apcli_scan() {` `pin_cmp() {` |
| `tools/passivity-mutate.sh` | `# ---- the rows of passivity-check` `apply() {` `job_run() {` |
| `tools/quick.sh` | `QMODE=std` `QUICK_DOCS_DROPINS=` |
| `tools/regress.sh` | `DROPINS="` |
| `tools/release.sh` | |
| `tools/spec-sync.py` | |
| `tools/static.sh` | `QUICK_DROPINS="` `MIN_QUICK_DROPINS=` `QUICK_CHROME_RE=` `# ---- floors of the check sets` `# ---- the tier-1 wiring` |
| `tools/verify.sh` | |
| `tools/bench/` | |

## Drop-ins

One row per file of `tools/regress.d`. Subjects: the groups, fragments and paths whose change the drop-in should
see, that is the fragments whose text it pins and the files it reads or runs. What a drop-in proves and its
negative probes: `tools/README.md` (Drop-ins) and the drop-in's own header.

| Drop-in | Subjects |
|---|---|
| `alerts` | `page` `fixtures` `20-config` `23-normalize` `25-ingest` `29-analyzer` `30-step` `34-render-layers` `37-ui` `tools/check-colors.py` `tools/gen-testdata.py` `tools/regress.d/neutral-language.sh` `tools/regress.d/scope.sh` |
| `ap-models` | `page` `fixtures` `23-normalize` `34-render-layers` `38-data-source` `tools/check-colors.py` `tools/gen-testdata.py` |
| `cdp-ready` | `page` `fixtures` `docs/architecture.md` `tools/README.md` |
| `channel-time` | `page` `fixtures` `25-ingest` `29-analyzer` `37-ui` `SECURITY.md` `tools/regress.d/edge-layout.sh` |
| `clouds` | `page` `overview` `fixtures` `14-controls` `20-config` `23-normalize` `24-state` `25-ingest` `29-analyzer` `30-step` `36-interaction` `37-ui` `41-boot` `tools/gen-testdata.py` |
| `collector-fields` | `page` `collector` `payload` `fixtures` `19-help` `README.md` `packaging/hak5/README.md` `tools/gen-testdata.py` `tools/regress.sh` `tools/static.sh` |
| `contrast` | `page` `04-controls` `31-sprites` `34-render-layers` `35-render-hud` `40-debug-api` |
| `cycle-census` | `collector` `tools/regress.sh` `tools/static.sh` |
| `data-oracle` | `page` `fixtures` `29-analyzer` `37-ui` `40-debug-api` `tools/README.md` `tools/data-oracle.py` `tools/evals/data-oracle.js` `tools/gen-testdata.py` |
| `device-probe` | `page` `collector` `overview` `payload` `serve` `tools/denylist-check.sh` `tools/denylist-cs.txt` `tools/denylist-words.txt` `tools/denylist.txt` `tools/device-probe.sh` `tools/passivity-check.sh` |
| `display-parity` | `page` `overview` `fixtures` `tools/gen-testdata.py` |
| `display-selftest` | `overview` `fixtures` |
| `doc-binding` | `page` `overview` `20-config` `21-themes-encoding` `22-util` `40-debug-api` `CONTRIBUTING.md` `SECURITY.md` `docs/architecture.md` `library/user/reconnaissance/starchorus/README.md` `tools/dump-themes.sh` `tools/passivity-check.sh` `tools/regress.sh` `tools/spec-sync.py` |
| `doc-drift` | `page` `collector` `overview` `payload` `serve` `00-embedded-font` `11-masthead-stats` `20-config` `21-themes-encoding` `37-ui` `40-debug-api` `CHANGELOG.md` `INSTALL.md` `README.md` `SECURITY.md` `docs/architecture.md` `library/user/reconnaissance/starchorus/README.md` `packaging/hak5/README.md` `tools/install.sh` |
| `doc-truth` | `page` `collector` `overview` `payload` `serve` `fixtures` `docs` `tools` `tools/doc-truth.py` `tools/static.sh` |
| `edge-layout` | `page` `fixtures` `30-step` `37-ui` `38-data-source` `41-boot` |
| `hak5-package` | `page` `collector` `overview` `payload` `serve` `LICENSE` `README.md` `index.html` `packaging/hak5/README.md` `tools/hak5-package.sh` `tools/release.sh` |
| `hook-behavior` | `page` `hooks` `41-boot` `CONTRIBUTING.md` `DESIGN-DECISIONS.md` `README.md` `ROADMAP.md` `docs/MAP.md` `docs/architecture.md` `tools/README.md` `tools/quick.sh` |
| `ingest-fuzz` | `page` `overview` `fixtures` `22-util` `23-normalize` `37-ui` `38-data-source` `tools/evals/ingest-fuzz.js` `tools/fuzz-doc.py` `tools/gen-testdata.py` |
| `installer` | `page` `collector` `overview` `payload` `serve` `INSTALL.md` `index.html` `tools/install.sh` `tools/static.sh` |
| `jq-noregex` | `overview` `fixtures` |
| `labels-particles` | `page` `fixtures` `20-config` `30-step` `32-particles` `34-render-layers` `35-render-hud` `36-interaction` `37-ui` `38-data-source` `39-intro` |
| `legal` | `page` `collector` `overview` `payload` `serve` `fixtures` `tools/denylist-check.sh` `tools/denylist-cs.txt` `tools/denylist-words.txt` `tools/denylist.txt` `tools/gen-testdata.py` |
| `legend` | `page` `fixtures` `02-theme-tokens` `13-legend` `21-themes-encoding` `31-sprites` `34-render-layers` `35-render-hud` `37-ui` `tools/evals/legend-truth.js` |
| `mutation-probe` | `page` `collector` `overview` `payload` `serve` `tools/denylist-check.sh` `tools/denylist-cs.txt` `tools/denylist-words.txt` `tools/denylist.txt` `tools/passivity-check.sh` `tools/passivity-mutate.sh` |
| `net-runtime` | `page` `fixtures` `12-source` `22-util` `37-ui` `38-data-source` `tools/verify.sh` |
| `neutral-language` | `page` `overview` `fixtures` |
| `observations` | `page` `fixtures` `29-analyzer` `SECURITY.md` `tools/regress.d/edge-layout.sh` |
| `operator-tools` | `page` `collector` `fixtures` `05-tooltip-detail` `20-config` `22-util` `29-analyzer` `37-ui` `SECURITY.md` `tools/regress.d/edge-layout.sh` |
| `order-invariance` | `page` `fixtures` `25-ingest` `tools/evals/order-invariance.js` `tools/static.sh` |
| `page-server` | `serve` |
| `payload-ui` | `collector` `overview` `payload` `serve` `fixtures` `index.html` `tools/install.sh` |
| `phone` | `page` `fixtures` `03-panels-hud` `09-responsive-motion` `14-controls` `20-config` `35-render-hud` `37-ui` `40-debug-api` `tools/regress.d/scope.sh` |
| `poll-cadence` | `page` `10-stage` `20-config` `25-ingest` `38-data-source` |
| `preflight` | `collector` `tools/quick.sh` `tools/regress.sh` `tools/static.sh` |
| `radio-pair` | `page` `fixtures` `20-config` `23-normalize` `25-ingest` `29-analyzer` `30-step` `34-render-layers` `36-interaction` `37-ui` `tools/denylist-check.sh` `tools/denylist-cs.txt` `tools/denylist-words.txt` `tools/denylist.txt` `tools/fuzz-doc.py` `tools/gen-testdata.py` |
| `remote-id` | `page` `05-tooltip-detail` `23-normalize` `29-analyzer` `34-render-layers` `36-interaction` `37-ui` `tools/denylist-check.sh` `tools/denylist-cs.txt` `tools/denylist-words.txt` `tools/denylist.txt` `tools/gen-testdata.py` `tools/regress.d/neutral-language.sh` `tools/regress.d/scope.sh` |
| `repo-map` | `page` `collector` `overview` `payload` `serve` `hooks` `docs` `tools` `src/*/*` |
| `scope` | `page` `fixtures` `09-responsive-motion` `14-controls` `20-config` `21-themes-encoding` `24-state` `26-layout-2d` `29-analyzer` `30-step` `34-render-layers` `37-ui` `tools/denylist-words.txt` `tools/evals/legend-truth.js` `tools/gen-testdata.py` |
| `shell-dialect` | `collector` `overview` `payload` `serve` `tools` |
| `small-screen` | `page` `fixtures` `tools/regress.d/edge-layout.sh` |
| `source-truth` | `page` `overview` `fixtures` `head` `11-masthead-stats` `21-themes-encoding` |
| `station-inventory` | `page` `fixtures` `20-config` `25-ingest` `29-analyzer` `37-ui` `40-debug-api` |
| `station-models` | `page` `fixtures` `20-config` `25-ingest` `29-analyzer` |
| `station-outputs` | `page` `collector` `overview` `payload` `serve` `fixtures` `37-ui` `README.md` `docs/architecture.md` `tools/device-probe.sh` |
| `station-tools` | `page` `fixtures` `29-analyzer` `34-render-layers` |
| `stop-scope` | `collector` `payload` `serve` |
| `text-budget` | `page` `fixtures` `20-config` `30-step` `31-sprites` `35-render-hud` `36-interaction` |
| `theme-details` | `page` `fixtures` `21-themes-encoding` `29-analyzer` `37-ui` `39-intro` `tools/check-colors.py` |
| `theme-foundation` | `page` `fixtures` `12-source` `17-paste-dialog` `25-ingest` `37-ui` `38-data-source` |
| `theme-schema` | `page` `fixtures` `21-themes-encoding` `41-boot` |
| `theme-wargames` | `page` `fixtures` `21-themes-encoding` `34-render-layers` `tools/regress.d/edge-layout.sh` |
| `theme-whitehall` | `page` `fixtures` `00-embedded-font` `21-themes-encoding` `38-data-source` `tools/regress.d/edge-layout.sh` |
| `watch-marks` | `page` `fixtures` `25-ingest` `27-aggregation` `29-analyzer` `34-render-layers` `37-ui` `tools/denylist-check.sh` `tools/denylist-cs.txt` `tools/denylist-words.txt` `tools/denylist.txt` `tools/gen-testdata.py` `tools/regress.d/neutral-language.sh` `tools/regress.d/scope.sh` |

## Documents

Every Markdown file of the repository, with the headings worth a jump.

| Document | Anchors |
|---|---|
| `README.md` | `## What the page shows` `## Passivity as a design guarantee` `## Payload` `## Configuration` `## Data format` `## Version` |
| `SECURITY.md` | `## 1. Passivity contract` `### Permitted read paths` `### Additional read and output paths` `## 4. Privacy` `### Export` `### On-device Overview` |
| `CHANGELOG.md` | `### Added` |
| `CONTRIBUTING.md` | `## The passivity check is mandatory` `## Further checking tools (optional)` |
| `INSTALL.md` | `## 5. Start Starchorus` `## 7. Stop, update, uninstall` |
| `CODE_OF_CONDUCT.md` | |
| `DESIGN-DECISIONS.md` | |
| `ROADMAP.md` | |
| `docs/architecture.md` | `### 1.0 Source layout` `### 1.3 JavaScript` `### 2.7 Query overrides` `### 2.8 Input normalisation` `### 9.6 Keyboard` `## 10. Test/debug API` `## 14. Guiding principles` |
| `docs/device-notes.md` | `## 2. Tools on board` `## 6a. Load on the device` `## 8. Payload layout and firewall` |
| `docs/display-paths.md` | `## Overview on the device display` |
| `docs/ONBOARDING.md` | `## The parts` `## The gates: the safety net` |
| `docs/MAP.md` | `## How to work in pieces` `## Drop-ins` `## Documentation places` |
| `library/user/reconnaissance/starchorus/README.md` | `## Features` `## Operation` `## Configuration` |
| `packaging/hak5/README.md` | `## Strictly passive` `## Files` `## Settings` |
| `tools/README.md` | `## Test tiers` `## Tools` `## Drop-ins` `## Fixtures` `## Conventions for maintainers` |
| `tools/bench/README.md` | |
| `.github/PULL_REQUEST_TEMPLATE.md` | |

## Documentation places

Per kind of change, the places to update in the same commit. Kept by: the check that goes red when the place is
left out, or habit where none does.

| Change | Place | Anchors | Kept by |
|---|---|---|---|
| a page feature | `CHANGELOG.md` | `### Added` | habit: a bullet on top of its subsection |
| a page feature | `docs/architecture.md` | `### 2.8 Input normalisation` | habit: a row for each JSON field the page reads |
| a page feature | `docs/architecture.md` | `## 10. Test/debug API` | doc-binding: every STARCHORUS function |
| a page feature | `docs/architecture.md` | `### 9.6 Keyboard` | doc-binding: every hotkey of KEYS |
| a page feature | `docs/architecture.md` | `### 2.7 Query overrides` | doc-binding: every query parameter |
| a page feature | `docs/architecture.md` | `### 3.8 Token blocks` `### 7.0a Contrast table` | generated: `tools/dump-themes.sh`, then `tools/spec-sync.py` |
| a page feature | `docs/architecture.md` | `### 14.3 Decisions` `### 14.5 Privacy` `### 14.8 Toggles, keys and storage` | doc-drift: the rows and the toggle ids |
| a page feature | `README.md` | `## What the page shows` `## Data format` `## Themes and keys` | doc-drift: a feature that a document names is in the page |
| a page feature | `SECURITY.md` | `## 4. Privacy` `### What the page stores in the browser` `### Export` | the drop-ins that pin the storage keys |
| a page feature | `src/js/23-normalize.js` | `function demoData(` | the owner's rule: the sample sky carries every kind of thing the page shows (§2.9) |
| a page feature | `tools/README.md` | `## Drop-ins` | habit: the row of each drop-in whose coverage changed |
| a page feature | `docs/MAP.md` | `## Drop-ins` | habit, and `repo-map` for section slices: a drop-in that pins a fragment names it |
| a new page fragment | `src/PAGE.list` | | T1: the rows of the manifest |
| a new page fragment | `tools/static.sh` | `MIN_SECTIONS=` `MIN_SRC_FILES=` | floors, raised with their measuring command |
| a new page fragment | `docs/architecture.md` | `### 1.0 Source layout` `### 1.3 JavaScript` | habit |
| a new page fragment | `docs/MAP.md` | `## Page fragments` | `repo-map` |
| a collector feature | `starchorus-collect.sh` | `# CONFIG (override via environment` `# OPTIONAL JSON FIELDS` `usage() {` | operator-tools: the list of layers in the usage text |
| a collector feature | `README.md` | `## Configuration` `## Data format` `## Passivity as a design guarantee` | collector-fields, in part |
| a collector feature | `SECURITY.md` | `### Permitted read paths` `### Additional read and output paths` `### Static check` | the rule of `CONTRIBUTING.md`: a new read or output path is described before the merge |
| a collector feature | `docs/architecture.md` | `**JSON contract (stable).**` `### 2.8 Input normalisation` `### 14.6 Device calls` `### 14.10 Excluded and open` | habit |
| a collector feature | `docs/device-notes.md` | `## 2. Tools on board` | habit: dated facts from the device |
| a collector feature | `tools/gen-testdata.py` | `OPT_AP` `SOURCES` | doc-truth: sources and census |
| a collector feature | `tools/static.sh` | `MIN_SELFTEST=` | floor |
| a collector feature | `docs/MAP.md` | `## Regions` | `repo-map`: a new marker line needs its row |
| an Overview feature | `docs/display-paths.md` | `## Overview on the device display` | habit: the screens and the keys |
| an Overview feature | `README.md` | `## Payload` | habit |
| an Overview feature | `library/user/reconnaissance/starchorus/README.md` | `## Features` | doc-binding: fixed phrases |
| an Overview feature | `SECURITY.md` | `### On-device Overview` | doc-binding |
| an Overview feature | `library/user/reconnaissance/starchorus/starchorus-display.sh` | | T1: the copies are identical |
| a payload feature | `library/user/reconnaissance/starchorus/README.md` | `## Operation` `## Configuration` | habit |
| a payload feature | `packaging/hak5/README.md` | `## Strictly passive` `## Files` `## Settings` | hak5-package: fixed phrases |
| a payload feature | `README.md` | `## Payload` `## Configuration` | habit |
| a payload feature | `INSTALL.md` | `## 5. Start Starchorus` `## 7. Stop, update, uninstall` | habit |
| a payload feature | `docs/device-notes.md` | `## 8. Payload layout and firewall` | the definition of the Contract number |
| a payload feature | `library/user/reconnaissance/starchorus/payload.sh` | `# Contract:` | doc-truth: one Contract number in every script |
| a new drop-in, tool or fixture | `tools/regress.sh` | `DROPINS="` | T2: the row of the drop-in set |
| a new drop-in, tool or fixture | `tools/static.sh` | `QUICK_DROPINS="` `MIN_QUICK_DROPINS=` `MIN_FIXTURES=` | for a quick drop-in or a fixture; floors only go up |
| a new drop-in, tool or fixture | `tools/README.md` | `## Tools` `## Drop-ins` `## Fixtures` | doc-truth: the fixture table |
| a new drop-in, tool or fixture | `docs/MAP.md` | `## Drop-ins` `## Tools` | `repo-map` |
| a new script or document | `docs/MAP.md` | `## Scripts` `## Regions` `## Documents` | `repo-map` |
| a version bump | `src/js/40-debug-api.js` | `version: "` | doc-drift, doc-binding, station-outputs |
| a version bump | `docs/architecture.md` | `version: "` | doc-drift, doc-binding |
| a version bump | `starchorus-collect.sh` | `# Version:` | doc-truth: every script header equals the page |
| a version bump | `README.md` | `## Version` | station-outputs |
| a version bump | `tools/regress.d/station-outputs.sh` | `SOU_VER=` | typed also in display-parity, collector-fields, operator-tools and the probes of doc-truth |
| a version bump | `CHANGELOG.md` | | habit: the unreleased heading becomes the version and its date |
