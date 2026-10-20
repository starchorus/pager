# Starchorus – Architecture of `starchorus.html`

This file is the functional reference for the page `starchorus.html` (Starchorus 0.2.0-dev.1) and for the parts of
`starchorus-collect.sh` that define its data format. It describes what the code is and why it is built that way.
Where numbers appear, they are the values in the code; the machine-generated blocks (§3.8, §7.0a) and the bound
lists (§2.7 query parameters, §9.6 keys, §10 API) are checked against the code by the regression (`tools/regress.d/doc-binding.sh`).

**Strictly passive.** The page sends nothing except `fetch("starchorus.json?_=…", {cache:"no-store"})` in the same
directory. No radar sweep (it would suggest active scanning), no third-party requests, no external
font link; the typeface is embedded (section 00). The collector only reads (monitor interface, recon database
read-only, local OUI files and, opt-in, a passive Bluetooth LE scan) and writes `starchorus.json` and its cache to `$CAPDIR`. The only marked
exception is the opt-in scan `STARCHORUS_ALLOW_ACTIVE=1` (`source: "iw-scan-ACTIVE"`, §14.2).

**Data on the device.** The device's recon database delivers `aps[].clients` **empty**; all stations
appear in `unassociated` (senders of probe requests). `clients[]` is only populated with airodump CSV. The page is
therefore built to remain just as legible with 100 % free clients (sky rotation §4.2a, probe orbits §8.9,
probe arcs §7.3).

**JSON contract (stable).** `{generated, center:{label}, source, aps:[{bssid, ssid, channel, band, freq, rssi,
security, clients:[{mac, rssi}]}], unassociated:[{mac, rssi}]}`. New fields are additive and optional only; a
`starchorus.json` without them runs unchanged. Read optionally: per AP `vendor`, `randomized`, `rate`,
`last_seen`, `width`, `phy`, `caps`, `beacons`, `packets`, `akm[]`, `cipher{group, pairwise[]}`, `auth[]`,
`responded_ssids`; per station `vendor`, `randomized`, `last_seen`, `packets`, `probes[]`; `center.max_age`,
`center.interval`, `center.own_bssids`, `center.own_ssids`, `center.bt_window` and `center.bt_hold`; top-level `channels[{freq, last_heard, busy_pct, noise}]`,
`alerts[]`, `homing`, and, from the opt-in switches, `bluetooth[{addr, addr_type, rssi, reports, last_seen, company, company_name, name,
connectable}]` (passive LE scan: addresses, never devices) and `activity[{freq, share}]` (a relative share of the frames the device heard per
frequency, never a count; kept apart from `channels[]` so that nothing a 0.1 page reads as 'visited' can grow). The collector emits a field **only when a value is present** (never `null`). `own_*` stay
in memory only and are never displayed or exported. The collector's field list is in its header comment,
the device facts in `docs/device-notes.md`.

---

## 0. Central idea and choreography principles

**One renderer, three lighting moods.** Layout, physics, data mapping, aggregation, camera and hit test know nothing of
the theme. Only sprites, renderer, particles, HUD, intro and DOM chrome read `THEME`; every branch is a
token query (`THEME.particles.perNode[1] > 0`, `THEME.crt.persistenceAlpha > 0`, `THEME.line.edge.style`,
`THEME.render.clientShape`), never a comparison with a theme ID outside section 39 (logon).

**Determinism as contract.** Same input (document, viewport, toggles) → same final positions, regardless of
frame rate, array order and time of day. No `Math.random()`; all randomness from `hash(id + salt)` (FNV-1a) or
`mulberry32(seed)` with a fixed seed. Time comes from `generated` (data) and `S.clock` (animation), never from a wall clock
(sole exception: the viewer's clock, D14).

**No allocation in the frame.** Persistent arrays/TypedArrays, preformatted colour strings, sprite keys from a cache,
no closures in loops.

**Choreography** (numbers are token values, §3.8):

| Principle | Foundation | WarGames |
|---|---|---|
| Appearance | **Condense**: particles contract in 900 ms, the core brightens out of the cloud (easeOutCubic position, easeInQuad alpha) | **Snap**: 250 ms, the wireframe draws itself as a line (stroke alpha 0→1), bloom briefly ×1.5 |
| Disappearance | **Dissolve**: 1400 ms, particles drift outwards (easeInCubic), the core alpha falls last | 400 ms, the wireframe alpha falls, persistence carries the afterglow |
| Rest | Breathing: glow ×(1 ± 0.06), period 6 s, phase per node from the hash | Cursor blinks 530 ms, flicker ±1.5 % ≤ 2 Hz, otherwise still |
| Motion | Auto-orbit 0.05 rad/s (126 s per revolution) | 0.12 rad/s (52 s), travelling dots 0.35 edges/s |
| Attention | Gold only for the alarm; selection in the brightest neutral (pearl), the shape distinguishes | Red only for the alarm; selection in the brightest neutral |
| Depth | Bokeh (soft sprites distant/faint), lens flare on 1–2 stars | Alpha/size only, the wireframe stays sharp |
| Reduced motion | No rotation, no breathing, no particle drift; position, camera and blend easings snap, opacity fades stay | No rotation, no flicker/blinking, no travelling dots, no logon |

Whitehall (the third theme) follows the same principles with its own token values (§7.1a).

---

## 1. File structure (one file, marker comments for `grep`)

One HTML file with no external reference. Every section begins with exactly one marker: CSS `/* ==== NN NAME ==== */`,
DOM `<!-- ==== NN NAME ==== -->`, JS `// ==== NN NAME ====`. No other comment begins with `====`.
`grep -n "==== " starchorus.html` is the table of contents; the numbers are globally unique, ascending and
have gaps (reserve). 'Section NN' in this file always means such a marker.

### 1.1 `<head>` and CSS

| Marker | Content |
|---|---|
| `/* ==== 00 EMBEDDED FONT … ==== */` | `@font-face` 'Starchorus Sans' as a `data:` URI (woff2); the typeface is Overpass under the SIL OFL 1.1, the licence notice is in the comment. No network fetch. |
| `/* ==== 01 RESET & BASE ==== */` | `color-scheme: dark`; `body` with `background-color: var(--surface-base)`, `background-image: var(--surface-gradient)`, `font-family: var(--font-ui)`, `font-size: var(--size-hud)`, `letter-spacing: var(--letter-spacing)` (no `font` shorthand: `--font-ui` is only the family stack); `[hidden] {display:none !important}`; `#stage` fixed, three canvases `#bg`, `#sky`, `#hud` stacked (`touch-action:none`); only `#hud` receives pointer events. |
| `/* ==== 02 THEME TOKENS (CSS-SPIEGEL) ==== */` | `:root { … }` with the Foundation values as a static first-paint copy of all `CSS_MIRROR` variables (§3.2). No static block for other themes: `applyTheme()` mirrors all variables via `style.setProperty` from `THEME` (single source of truth = JS). `data-theme` is set but carries no CSS rule; structure runs only through token attributes: `data-banner` (from `chrome.banner.show`; sets `--chrome-top/--chrome-bot`), `data-cursor`, `data-plaque` and `data-rm`. |
| `/* ==== 03 PANELS & HUD ==== */` | `.panel` (fill/border/radius/blur/shadow from variables), `#masthead`, `#stats`, `#source`, `#legend`, `.cursor` (`:root[data-cursor="off"] .cursor {display:none}`; CSS cannot evaluate `0ms`, hence the attribute). Corner brackets `.panel::before/::after` from `chrome.bezel`. Banners `#classbar-top/-bot` and `#dtg` only with `data-banner="on"`. **Edge panel rule (D15):** `#masthead, #stats, #source` at the top at `--chrome-top + 20px`, `#legend, #controls` at the bottom at `--chrome-bot + 20px`; collisions are resolved by `layoutEdges()` (section 37) via `--lay-*` variables (§9.8a). **Hide panels** (`:root[data-panels="off"]`, §9.8): every `.panel` except `#detail` and the two dialogues goes to `visibility: hidden` with its box kept; `#panels-pill` takes its place. |
| `/* ==== 04 CONTROLS ==== */` | `#controls .group .glabel .btn .btn.on`, band buttons with band colour and `--ink-on-fill`, toggles with `accent.toggle*`, `#cam`, `:focus-visible` with `--accent-focus`; `#t-panels` absolutely placed in the empty corner of the Bands row (it moves no other box). |
| `/* ==== 05 TOOLTIP & DETAIL ==== */` | `#tip` (`position:fixed; pointer-events:none`, above the cursor), `canvas#tip-spark` (120×28), `#detail` (right, below `#source`, scrollable), `canvas#detail-spark` (240×64, focusable), shortcut overlay `#help` (`dl` in two columns, `kbd` in `--font-mono`). |
| `/* ==== 06 CHANNEL BAR ==== */` | `#chanbar` (position from `layoutEdges()`: between legend and controls, 280–640 px wide; if the gap is too small, docked above `#controls`, otherwise collapsed), `canvas#chan`, `#chan-tip`, `#t-chan`. |
| `/* ==== 07 CRT OVERLAYS ==== */` | `#crt` (fixed, `pointer-events:none`, z-index 20); `#crt.on` draws scanlines (`repeating-linear-gradient`) and vignette (`radial-gradient`) from the `--crt-*` variables. `applyCrt()` sets `.on` only with `crt.userToggle`. |
| `/* ==== 08 LOGON (WARGAMES INTRO) ==== */` | `#intro` (fixed, z-index 50, black, mono, upper case), `#intro pre`, `#intro .skip`, `.out` (fade-out in 300 ms); the place/time caption `#caption`. |
| `/* ==== 09 RESPONSIVE & MOTION ==== */` | `< 1100 px`: `#masthead, #source` at most 300 px; `< 900 px`: `.motto` off, more compact controls; **phone mode** (D21, §9.8): the rules for `#bar`, `#sheet` and the panels inside it, keyed on `:root[data-phone="on"]` or on `#sheet` (the panels are there only on a phone), and outside it nothing. **Reduced motion only via the attribute** `:root[data-rm="1"]` (section 24 sets it from media query ∨ `?rm=1` ∨ `setReducedMotion`; the media query is only the source of the JS value, not a CSS selector, so that tests can switch it without emulation): cursor and dots without animation, no panel fade or sheet transition, `#crt` and `#intro` off. `@media (pointer:coarse)`: buttons ≥ 36 px (44 px in phone mode). |

### 1.2 DOM (`<body>`)

| Marker | Elements (IDs from 'MUST REMAIN', §9.9, in bold) |
|---|---|
| `<!-- ==== 10 STAGE ==== -->` | `#stage` > `canvas#bg`, **`canvas#sky`**, `canvas#hud` (`role="img"`); `div#crt`, `#caption`, `#classbar-top`, `#classbar-bot`, `#dtg`; the phone status bar `#bar.ph-only` (`#bar-counts` > `#bar-ap`, `#bar-cl`) and the panels pill `button#panels-pill` (`#pill-dot`, `#pill-chip`). |
| `<!-- ==== 11 MASTHEAD & STATS ==== -->` | **`#masthead`** (`#mast-badge`, `#lamps`, `#plotclock` – visible depending on theme; `#mast-brand.brand .dot` 'STARCHORUS' `.ver` (the version, small and dim, filled at boot from `STARCHORUS.version`) `.cursor`; `.tag`; `.motto`; on a phone the label 'About' and `#t-help`), **`#stats`** (on a phone the label 'Sky') with **`#n-ap`** ('Stars'), **`#n-cl`** ('Satellites', `title="n free · m associated"`), **`#n-24`, `#n-5`, `#n-6`**, `#n-fresh`, `#n-record`, `#n-alarm` (only > 0), `#n-groups`, `#n-crowd`; every counter carries the unfiltered number in its `title`. |
| `<!-- ==== 12 SOURCE ==== -->` | **`#source`**, **`#mode-chip`**, **`#source-desc`**, **`#btn-load`** ('Load…'), `#src-center` (`center.label`). |
| `<!-- ==== 13 LEGEND ==== -->` | **`#legend`** > **`#legend-body`** (built by `buildLegend()`, §9.4) and the drawers `#obs-body`, `#inv-body`, `#home-body`, `#air-body`, `#time-body`, `#rec-body`, which share the one legend box (D15). |
| `<!-- ==== 14 CONTROLS ==== -->` | the phone sheet `#sheet.ph-only` (`#sheet-head` > `#sheet-grab`, `#sheet-row` > `#sheet-lead`, `#sheet-prev`, `h2#sheet-title`, `#sheet-next`, `#t-legend`, `#sheet-close`, `#sheet-toggle`; `#sheet-body`), then **`#controls`**, groups 'Bands' `#grp-bands` (**`button.btn[data-band="2.4"|"5"|"6"]`**), 'View' `#grp-view` (**`#t-labels`, `#t-orbits`, `#t-links`, `#t-pause`**, `#t-random`: the Random switch, three states in `data-state`, §8.8a), 'Watch' `#grp-watch` (`#t-obs`, `#t-baseline`, `#baseline-set`, `#baseline-clear`, `#t-inv`, `#btn-export`), 'Analyse' `#grp-analyse` (`#t-air`, `#t-time`, `#t-rec`, on a phone `#t-home`), 'Look' `#grp-look` (`#t-theme`, `#t-view`, `#t-rotate`, `#t-spin`, `#t-crt` only with `crt.userToggle`, `#t-panels`), 'Layers' `#grp-layers` (`#t-agg`, `#t-vendor`, `#t-nebula`, `#t-groups`, `#t-devices`, `#t-merge`, `#t-probes`), 'Camera' `#cam` (3D only; on a phone zoom and reset in 2D too): `#cam-left/-right/-up/-down/-in/-out/-reset`. Toggles carry `aria-pressed` and their shortcut in the `title`. |
| `<!-- ==== 15 CHANNEL BAR ==== -->` | `#chanbar` > (on a phone the label 'Channels') `canvas#chan`, `#t-chan`, `#chan-tip`. |
| `<!-- ==== 16 TOOLTIP & DETAIL ==== -->` | **`#tip`** (`role="tooltip"`); `#detail` (`aria-live="polite"`: `h3#detail-title`, `#detail-close`, `#detail-body`, `canvas#detail-spark`). |
| `<!-- ==== 17 PASTE DIALOG ==== -->` | **`#paste-wrap` > `#paste-box`** (`h3` 'Load a starchorus.json capture', explanatory text **verbatim** with 'Everything runs in your browser — nothing is uploaded.'), **`#paste-ta`**, **`#paste-err`**, **`#paste-cancel`**, **`#paste-ok`** ('Render'). |
| `<!-- ==== 17b EXPORT DIALOG … ==== -->` | `#export-wrap` > `#export-box` (`role="dialog"`): format choice `#export-fmt` (JSON, CSV, SITREP), `#export-ta`, `#export-png`, buttons Copy/Print/Snapshot; `#export-printable` for printing. Local only, nothing is uploaded (§8.12). |
| `<!-- ==== 18 INTRO ==== -->` | `#intro` > `pre#intro-text`, `button#intro-skip` ('SKIP ▮'). |
| `<!-- ==== 19 HELP ==== -->` | `#help.panel` (`hidden`, `role="dialog"`, `aria-label="Keyboard shortcuts"`) > `h3`, `dl#help-list` (built by `buildHelp()` from `KEYS`), one `p` (PMF, §8.3), `button#help-close`. On a desktop it sits 96 px above the bottom and is at most `100vh − 112px` high, scrolling inside itself (`overflow-y: auto`); in the phone sheet it has no cap. Opened with `?` or `STARCHORUS.setToggles({help:true})`; closes with `Esc`, `?` or `#help-close`. |

### 1.3 JavaScript (one `<script>`, IIFE, `"use strict"`)

Order = dependency order; nothing reaches forward except through the hoisting of function declarations.
Tokens (`THEME`, `TK`, `TD`) are **never** read in sections 22–30 and 36. Whatever layout, step, camera and
aggregation need from the theme is placed beforehand in **`S.anim`** (§2.6): a theme-free object of numbers that `fillAnim()` fills in
`applyTheme()`.

| Marker | Content / functions |
|---|---|
| `// ==== 20 CONFIG ====` | `LAYOUT`, `AGG`, `DEVICE`, `CLOUD`, `RANDOM_MODES` (§8.8a), `CFG3D`, `RENDER`, `LOD`, `HIT`, `KEYS` (§9.6), `EDGE` (§9.8a), `PHONE` (§9.8), `POLL_MS 5000`, `HISTORY_LEN 60`, `HIST_KEEP_S 300`, `STORAGE_KEY "starchorus.ui.v1"`, `STALE_POLLS 6`, `STALE`, `POLL` (§9.5), `FRESH`, the upper limits of the registers (`CHG_MAX`, `BASELINE_MAX`, `GHOST_MAX`, `HIST_CL_MAX`, `BASELINE_CL_MAX`, `WATCH_MAX`, `NOTES_MAX`, `RULES_MAX`, …), `EXPORT_FOOTER`, `MOBILE_SSID_RE` – theme-free constants only. |
| `// ==== 21 THEMES & ENCODING ====` | `COPY_ACTIVE`, `COPY_RX_MODE`, `COPY_SITES` (§3.1), `THEMES = {foundation, wargames, whitehall}` (§3.8), `ENCODING` (§3.7), `validateThemes()`/`validateTheme()`/`auditThemes()`, `let THEME`, `TK`, `TD`, `CSS_MIRROR` (§3.2), `flatten`, `deriveStrings`, `mirrorCss`, `fillAnim`, `applyTheme(id, {intro, persist})`, `CONTRAST_PAIRS`. |
| `// ==== 22 UTIL ====` | `hash(str)` (FNV-1a 32 bit → 0..1), `hashInt`, `mulberry32`, `clamp`, `lerp`, `smoothstep`, `ease(cur, tgt, k, dt) = tgt + (cur − tgt)·exp(−k·dt)`, `easeAngle`, `wrapPi`, easing curves, `rssiT`, `esc(s)`, `fmtMac`, `fmtAge`, `safeStorage` (get/set/remove in try/catch), `sessionFlag`, `query`. **Snap rule:** `ease()` and `easeAngle()` return exactly `tgt` as soon as `abs(cur − tgt) < 1e-6` (in log space `ln dist`: `2e-3`). Thus all easings end exactly on the target in finite time. |
| `// ==== 23 NORMALIZE ====` | `normalizeDoc(raw) → Doc|null` (§2.8), `secClass()`, `bandOf()`, `demoData()` (§2.9). |
| `// ==== 24 STATE ====` | `S` (§2), `loadUi()/saveUi()` (with `S.queryLocked`), `PERSIST_KEYS`, `reduceMotion` (media query ∨ `?rm=1` ∨ `setReducedMotion`) together with `dataset.rm`. |
| `// ==== 25 INGEST ====` | `ingest(doc, opts)`: create/update nodes, `target`, history, freshness, events (D2), groups, `applyAffinity()`, `layoutDirty`, `updateStats()`. |
| `// ==== 26 LAYOUT 2D ====` | `rssiToRadius`, `basePxMax(node)`, `starZonePx(ap)`, `placeAPs()`, `homeOfClient()` (stations and clouds), `spreadStep(iters)`, `settleLayout(maxIter)`, `countFreeLayout()`, `freeSingles()`, `layoutInfo()`. |
| `// ==== 27 AGGREGATION ====` | `rebuildBubbles()`, `stepBubbles(dt)`, `expandBubble(id)`. |
| `// ==== 28 LAYOUT 3D & CAMERA ====` | `p3Of` (also a cloud, §5.1), `cameraBasis`, `project`, `projectAll`, `stepCamera`, `stepBlend`, `flyTo`, `resetCamera`, `setView(v, {persist})`, `setZoom2d(z)` (around the observer, no pan), `skyPt`/`easeSky` (§4.2a). |
| `// ==== 29 ANALYZER ====` | Channel span, overlap, `rebuildInterference()`, `rebuildChannelStats()`, `phyEstimate`, `securityCounts()`, `rebuildGroups()`, `rebuildDevices()`, `rebuildEss()`, the random clouds (`newCloud`, `cloudBands`, `cloudBursts`, `cloudRhythm`, `rebuildClouds(gen, rp)`, `applyRandom()`, `pubCloud`, `liveCloud`, `cloudExpanded`, §8.8a), baseline, change log, observations, library, inventory, homing, channel/time/recording models (§8). |
| `// ==== 30 STEP ====` | `tick(t)`, `step(dt)`, `stepNodes(dt, liveDt)`, `stepClouds(dt)` (§8.8a), `stepSky(liveDt)`: alpha, position, orbit, twinkle, breathing, bubble blend, camera, dirty logic, governor measurement (§6); all theme timings from `S.anim`. |
| `// ==== 31 SPRITES ====` | `spriteCache`, `getSprite(kind, colorKey, tier, variant)`, `bakeSprite()`, `clearSprites()`; also the text sprites `counter`, `glyph`, `devcount` and `text` (§6.3). |
| `// ==== 32 PARTICLES ====` | Particle pool (`Float32Array`), spawn, step, drawing, `particlesReset`, `particlesRestartCurves`, coalescing free list (§7.2). |
| `// ==== 33 RENDER PIPELINE ====` | `render()`, `beginFrame()` (clears `#sky` or the persistence fill, and `#hud`), `endFrame()`, draw-call wrappers `dI/fR/sT/fT` (§10), `S.countCalls`, governor `budget.*` (§6.5). |
| `// ==== 34 RENDER LAYERS ====` | `drawBackground`, `drawRings`, `drawShadows`, `drawNebula`, `drawConstellations`, `drawDeviceLinks`, `drawGlows`, `drawEdges`, `drawOrbits`, `drawClients`, `drawClouds` (§8.8a), `drawBubbles`, `drawStars` (with `drawApRings`, `drawIdentityFrame`, `drawSelectionMarks`), `drawChangeCues`, `drawGhosts`, `drawRecvRing`, `drawThreshold`, `drawFlares`. |
| `// ==== 35 RENDER HUD ====` | `drawHud()`: ring labelling, labels with collision grid and text budget (§6.6), group labels, badges, glyphs, bubble counters, cloud tags (§8.8a), core text, cursor. No `clearRect` here (layer 0). |
| `// ==== 36 INTERACTION ====` | `nodeAt(mx, my)`, pointer (hover/click/drag/pinch), wheel, keyboard, `setHover`, `clickPin` (§5.6), `select`, `deselect`, `nodeById`, `expandCloud(id)` (§8.8a). |
| `// ==== 37 UI ====` | Controls binding, `setToggle(key, on)`, the Random switch (`setRandomMode(m)`, `cycleRandom()`, `syncRandomButton()`, `cadText(s)`, §8.8a), `updateStats`, `buildLegend`, `legendVisibility`, `buildHelp`, `showTip`, `openDetail`, `drawSparkline`, `drawChannelBar`, the drawers, `layoutEdges()`; phone mode (§9.8): `applyPhone`, `phoneCardOf`, `phoneLayout`, `phDetailDetent`, `skyBox`, `setSheet`, `toggleSheet`, `closeCard`, `setPanels`, the sheet gestures. |
| `// ==== 38 DATA SOURCE ====` | `sourceKindOf`, `setSource`, `staleAfterMs`, `captureStale`, `captureOffline`, `liveness`, `noteStalePoll`, `tryPoll()` (§9.9 item 1), `captureSpacing`, `pollNextMs`, `pollArm` (the cadence, §9.5), `copyFor(site)`, `setSourcePanel`, `renderSourceTruth`, `loadData(obj, label, opts)`, `sourceHint`, paste dialog, drag and drop. |
| `// ==== 39 INTRO ====` | `logonLines()`, `bannerLines()`, `runLogon()`, `releaseLogon()`, `endLogon()`, `skipLogon()` – via `THEME.copy` and `THEME.motion.introStyle`. |
| `// ==== 40 DEBUG API ====` | `window.STARCHORUS = Object.freeze({…})` (§10; `clouds()`, `expandCloud()`), error collector (`window.onerror`, `unhandledrejection`). |
| `// ==== 41 BOOT ====` | `loadUi()` + query overrides (→ `S.queryLocked`), `validateThemes()` (once, symmetrical), `applyTheme(start, {intro: !query.intro0, persist: !query.theme})` (starts the logon itself), `data-panels`, `buildHelp()`, `applyPhone()`, `applyDrawer()`, `setView(start, {persist: !query.view, snap: true})`, `resize()`, load the demo, `tryPoll()` (with `?demo=1` instead `releaseLogon()` and no poll), then (without `?poll=0`) `pollArm(pollNextMs(…))`, `requestAnimationFrame(tick)`. |

Convention: new helper functions go into the section whose marker carries their main callers. An assignment
`.shadowBlur =` may appear only in 31, 33 and 34, `createRadialGradient(` only in 31, 33 and 37; in practice both appear
only in 31 (sprite baking). The counter keys `perf().drawCalls.shadowBlur`/`gradient` remain and are 0.

---

## 2. State model

### 2.1 AP node (`S.aps: Map<id, ApNode>`)

```js
ApNode = {
  id, kind: "ap",                    // id = bssid (lowercase) || "ap"+i
  // --- Input (normalised, §2.8) ---
  bssid, ssid: string ("" = hidden), ssidKnown: string|null,   // last non-empty name (§8.5)
  band: "2.4"|"5"|"6"|"unknown", channel, freq, rssi (default -75), security (raw), sec: SecClass, hidden, clientCount,
  vendor, rate, last_seen, width, phy, caps, beacons, packets, akm, cipher, auth, respondedSsids,   // optional
  ageS, freshTier,                   // D1 (§14.3)
  mobile,                            // P3: probable mobile hotspot (§14.5)
  // --- Layout 2D (world units, 1.0 = maxRadius; theme-free) ---
  a0, angleT, radiusT,               // hash base angle, target angle after collision search, target radius
  angle, radius,                     // eased (angle via shortest path k=3/s, radius k=2.2/s)
  wx, wz,                            // 2D world = (cos·radius, sin·radius)
  p3: [x,y,z], p: [x,y,z],           // 3D target / actual
  sx, sy, zc, px, fog, lod,          // projection per frame
  basePx,                            // core radius px (theme-free, §3.4) – hit test, label offset, drawing
  basePxMax,                         // theme-free maximum (§4.1) – the only size used for layout spacing
  // --- Lifecycle ---
  target: 1|0, alpha, born, phase, twinkleUntil, twinkleAmp, revealAt,
  // --- Analyzer ---
  groupKey, interfere: [{id, score, kind}] (max 6), sparkDirty, flare: 0..1, flareT: 0|1,
  // --- Foundation particles (pointers into the pool) ---
  pStart, pCount, pState: "gather"|"idle"|"dissolve"|null, pT0   // pin state lives in S.pinned
};
```

### 2.2 Client node (`S.clients: Map<mac, ClientNode>`)

```js
ClientNode = {
  id, kind: "client", mac, rssi: int|null, vendor, last_seen, packets, probes,
  randomized: bool,                  // field === true OR U/L bit (2nd hex digit ∈ {2,6,a,e}) and no vendor
  parent: apId|null, free: bool, band,             // band only when associated (from the AP)
  ageS, freshTier, isNew,            // D1/D2 per station
  homeAngle, homeR, jitterR,         // §4.2 (world, deterministic)
  lx, lz,                            // layout position after relaxation (world)
  wx, wz,                            // drawn 2D world (eased towards lx, lz; k=3/s)
  orbitR, orbitPhase, orbitSpeed, orbitTilt, rank, // associated or probe orbit (§4.3, §8.9)
  p3, p, sx, sy, zc, px, fog, lod, basePx,
  target, alpha, born,
  bubble: bubbleId|null, bubbleBlend: 0..1,
  cloud: cloudId|null,               // §8.8a model: the random cloud it belongs to, set for every present station on every rebuild
  randOut: bool                      // §8.8a view: folded into a shown cloud (Random: cloud) or hidden (Random: hide, randomised and not associated)
};
```

### 2.3 ESSID groups (`S.groups: Map<key, Group>`)

`key = (ssidKnown ?? ssid).trim()` (case-sensitive, non-empty only). `Group = { key, members: [apId…] (rssi desc), hub,
edges: [[a,b]…] (MST §8.6), meanA0 (mean of the hash base angles, §4.1), cx, cz, bands }`. Only groups
with ≥ 2 members are drawn; `#n-groups` counts these.

### 2.4 RSSI history (`S.hist: Map<key, Hist>`)

```js
Hist = { buf: Int8Array(60), ts: Float64Array(60), head: 0, n: 0, lastGen: null, lastSeq: 0 }
push(h, rssi, gen):
  if (gen != null && gen === h.lastGen) return          // same poll → no new sample
  h.buf[h.head] = rssi == null ? -128 : clamp(rssi, -120, 0); h.ts[h.head] = gen ?? NaN
  h.head = (h.head + 1) % 60; h.n = min(60, h.n + 1); h.lastGen = gen; h.lastSeq = S.ingestSeq
  if (h.n ≥ 2 && prev != -128 && |rssi − prev| ≥ 3) node.twinkleUntil = clock + 0.6, node.twinkleAmp = min(1, |Δ|/12)
```
Source: every `ingest()` from a poll (`generated` as the stamp), paste/drop/`STARCHORUS.load`, the demo once. **No
wall clock:** a document without `generated` stamps `NaN` (undated); `STARCHORUS.hist().ts` returns `null` for it. The
history **survives** the node's exit: the sweep on every ingest deletes an entry whose node has gone only once
`|generated − h.lastGen| > HIST_KEEP_S` (300 s of capture time, whatever the poll cadence); a document without `generated` counts
`S.ingestSeq − h.lastSeq > HIST_KEEP_INGESTS` (= `HIST_KEEP_S`·1000/`POLL_MS` = 60 ingests) instead.
`-128` = gap (the sparkline breaks). Stations have their own series, capped separately (`HIST_CL_MAX`), so that
rotating randomised MACs never displace an AP.

### 2.5 Aggregate bubbles (`S.bubbles: Map<id, Bubble>`)

```js
Bubble = { id: "b:"+gx+":"+gz (anchor cell, stable), members: [mac…], n, cx, cz (world, mean of the home positions),
           r (px), p3, p, sx, sy, zc, px, alpha, target, born, meanRssi, vendors: Map<string,int>,
           randomizedCount, expandedUntil: clock|null }
```

### 2.5a Random clouds (`S.clouds: Map<id, CloudNode>`, `S.cloudOrder`: the live ones by id; §8.8a)

```js
CloudNode = { id: "rc:xxxxxxxx", kind: "cloud", mac: id /* hash key of the relaxation only, never shown */,
  members: [mac…] (ascending), n, core, joined, centre, rssi, rssiMin, rssiMax, first, last,   // first/last: capture times
  bursts, cadenceS, rhythm (share of the gaps between its bursts that are one, two or three periods), probes: [≤ 8], anchor, kept,
  ageS, freshTier (D1 of the newest member), freshA, freshAT,
  homeAngle, homeR, jitterR, homeX, homeZ, lx, lz, wx, wz, placed, jitY, jitZ,   // §4.2, like a free station
  p3, p, sx, sy, zc, px, fog, scale, basePx, basePxMax: 7, bubble: null,
  target, alpha, alphaDraw, born, expandedUntil: clock|null,
  hist: Hist }                       // one sample per capture, on the node and never in S.hist (keyed by observed MACs)
```

### 2.6 View/theme/UI state and persistence

```js
S.ui = { theme: "foundation"|"wargames"|"whitehall", view: "2d"|"3d",
         labels: true, orbits: true, links: true, paused: false,
         agg: true, vendor: false, nebula: true, groups: true, rotate: true, spin: true, crt: true, autoLod: true,
         help: false,                                                        // shortcut overlay (not persisted)
         random: "cloud"|"show"|"hide",                                      // the Random switch (§8.8a, persisted)
         panels: true, sheet: "peek"|"half"|"full", legendCard: false,       // Hide panels (persisted); the phone sheet and its legend card (not, §9.8)
         scope: false,                                                       // the Scope, phone layout only (persisted, §9.8b)
         deviceLinks: false, essMerge: false, affinity: true, observations: false, baselineDiff: false, inventory: false,
         filters: { "2.4": true, "5": true, "6": true } };
S.queryLocked = Set<key>;           // UI keys from query parameters (§2.7): saveUi() omits them until they are changed via UI/API
S.view = { blend: 0, blendT: 0 };   // 0 = 2D … 1 = 3D; stepBlend snaps to exactly 0/1 (§5.7)
S.cam  = { az, el, dist, target: [0,0,0], azT, elT, distT, targetT, tween, ramp, idleAt, zoom2d: 1 };   // 2D zoom around the observer, no pan
S.anim = {                          // theme-free injection, filled by fillAnim() in applyTheme(); the sole theme source for 22–30 and 36
  fadeInK, fadeOutK,                         // K = 4.6·1000/ms of motion.fadeInMs / fadeOutMs (the alpha easing reaches 99 % after ms)
  breathePeriodS, breatheAmp,                // 0 = no breathing
  blendK,                                    // bubble blend, K from motion.fadeInMs
  autoRotateRadPerS, cameraEaseMs, cameraEasing, edgeTravelDotSpeed, flare* };
S.apOrder, S.clientOrder;         // persistent sort lists, rebuilt on every ingest (§4.0, §5.5)
S.mode = "demo"|"live";             // "demo" only for the built-in demo
S.sourceKind = "demo"|"live"|"recorded"|"active"|"none";   // D4 source truth (section 38), basis of copyFor()
S.sourceLabel, S.sourceKey, S.sourceApCount;                // label, change key (kind|route|label|doc.source), AP count
S.liveFeed;                          // fed by the poll or by STARCHORUS.load(…, {mode:"live"}) – only this can go stale (D3)
S.lastGen, S.stalePolls, S.staleMs, S.lostPolls, S.gaps, S.fresh, S.ingestSeq;   // D3: polls and poll time without a new `generated`, polls without an answer, the last three capture gaps (§9.5)
S.pinned = Set; S.hover; S.locked;
S.skyA (sky rotation, rad), S.clock (does not run while paused; stands still under fixedTime), S.dirty, S.settling, S.layoutDirty, S.fixedTime;
S.perf = { fps, frameMs (EMA α 0.1), lod, dpr, dprStep, drawCalls: {drawImage, fillRect, stroke, fillText, shadowBlur, gradient} };
S.themeErrors;                       // findings from validateThemes()/validateTheme() (§3.1)
S.errors;                            // window.onerror + unhandledrejection + API errors (strings, max 50)
```
Persistence (`localStorage[STORAGE_KEY]`, JSON, debounced 250 ms, all accesses in `try/catch`):
`{v: 2, theme, view, random, labels, orbits, links, agg, vendor, nebula, groups, rotate, spin, crt, deviceLinks, essMerge, affinity,
observations, baselineDiff, inventory, panels, scope}` (`PERSIST_KEYS`; names at index 0–2, booleans from index 3 onwards). **Not** persisted: `paused`,
`filters`, `help`, camera, pins, `autoLod` and everything concerning the analysis drawers (§2.6a). Invalid values →
defaults. `saveUi()` does not write keys in `S.queryLocked` (the stored value remains) until the key is changed via the UI
or `STARCHORUS.set*`; `setToggle` and `setRandomMode` always, and `applyTheme`/`setView` with `persist: true` (the default), remove it
from `queryLocked`; the boot (41) calls `applyTheme`/`setView` with `persist: false`.

### 2.6a Analysis state (memory; persistent only where stated)

The page writes **six** `localStorage` keys and no others (`SECURITY.md` §4 names each with its upper limit):
`starchorus.ui.v1`, `starchorus.identity.v1`, `starchorus.baseline.v1` (≤ 500 APs, ≤ 2000 stations with RSSI only),
`starchorus.watch.v1` (≤ 20 SSIDs), `starchorus.library.v1` (≤ 20 OUI rules), `starchorus.notes.v1` (≤ 200 entries).
In addition there is the `sessionStorage` key `starchorus.introShown.<theme>` (§7.3). Everything else lives **in memory only**:

| State | Content |
|---|---|
| `S.ev`, `S.captureSeq`, `n.capSeq/newSeq/changedSeq/cueSeq` | D2 event log (one source; the first capture produces no arrivals) |
| `S.chg` | Change log per BSSID (≤ 12 entries, ≤ 500 BSSIDs) |
| `S.sky`, `S.crowding` | D11 reference (EWMA per channel, deviations), crowding 1–5 |
| `S.base`, `S.ghosts`, `S.obs`, `S.watch` | Baseline comparison, ghosts (D19), observations, watchlist |
| `S.rules`, `S.notes`, `S.inv`, `S.homing`, `S.homePeak` | Library rules, alias/notes/tags, inventory sorting/filter, homing |
| `S.long`, `S.chanPeak`, `S.threshold`, `S.dx`, `S.chanMode` | Long-term RSSI (720 values per AP), channel peak values, threshold, open analysis drawer, channel mode |
| `S.rec`, `S.replay` | Recording (complete captures, ≤ 120 / 8 MB) and running playback (a **view**: no model advances) |
| `S.recvT0` | Time of the last arrival, for the reception ring |
| `S.own` | Own BSSIDs/SSIDs from `center.own_*` (never displayed or exported) |

All models belong to **one source** (D2): a change of source resets them. Time comes from `generated` and
`S.clock`, never from a wall clock.

### 2.7 Query overrides (take precedence over localStorage, are **not** persisted)

| Parameter | Effect |
|---|---|
| `?theme=foundation|wargames|whitehall` | Start theme |
| `?view=2d|3d` | Start view (the blend starts at 1, no transition) |
| `?rm=1` | `reduceMotion = true` regardless of the media query |
| `?intro=0` | Suppress the logon (screenshots) |
| `?debug=1` | `STARCHORUS._internals` populated (otherwise `undefined`) |
| `?storage=fail` | `safeStorage` throws internally on every access (error-path test) – the page must boot |
| `?fixed=<ms>` | `setFixedTime(ms)` at boot (deterministic screenshots) |
| `?agg=0|1`, `?autolod=0|1`, `?crt=0|1` | Toggle start values |
| `?spin=0|1`, `?deviceLinks=0|1`, `?essMerge=0|1`, `?affinity=0|1` | Toggle start values (sky rotation, device links, ESS merge, probe orbits) |
| `?obs=0|1`, `?baseline=0|1`, `?inv=0|1` | Start values for observations, baseline diff and inventory |
| `?pollto=<ms>` | Tests only: shorten the 4 s deadline of a poll (100–60000) |
| `?poll=0` | Tests only: the first `tryPoll()` runs, the cadence is not armed (no race between the poll and `STARCHORUS.load()` evals; without the parameter §9.9 item 1 applies unchanged) |
| `?demo=1` | Hold the built-in sample sky and never poll `starchorus.json`: the chip reads 'Sample' from the start, no request is made (not even by `STARCHORUS.pollNow()`), and the logon is released at the boot, as the first completed poll releases it. `?poll=0` keeps its meaning (without `?demo=1` its first poll runs) |
| `?phone=1|0` | Phone mode (§9.8) on or off whatever the viewport (otherwise `PHONE.query` decides) |
| `?panels=0|1` | Hide panels at the start (§9.8); like every override it is not saved |
| `?scope=1|0` | The Scope at the start (§9.8b); it shows only in phone mode, and it is not saved |
| `?random=cloud|show|hide` | The Random switch at the start (§8.8a): one node per cloud, one by one, hidden |

All query values land in `S.queryLocked` (§2.6) and are stored only after a user/API change to the same
key: `?theme=wargames&intro=0` leaves `storageDump()` reporting `null` or a different theme.

### 2.8 Input normalisation (`normalizeDoc`, section 23)

The contract stands; all rules are tolerant, no path throws.

| Field | Rule |
|---|---|
| `aps` missing / not an array | Document rejected (poll: `return false`, silent, counts as a failed poll; paste: error text in `#paste-err`) |
| `aps[i]` not an object | Entry skipped |
| `unassociated` missing / not an array | `[]`; non-object entries skipped |
| `source` | String or `""`; `"none"` → valid empty document: the sky empties softly, source panel 'No capture source · <note>' (`note` escaped, max 80 characters), chip 'No feed' (`sourceKind` `none`, never stale). A `source` matching `/ACTIVE/i` sets `sourceKind` `active` – taking precedence over any arrival route – and switches all passivity statements to the ACTIVE copy (D4, §9.5) |
| `center.label` | String (max 40 characters, control characters removed) → core text and `#src-center`; missing → **'YOU ARE HERE'** |
| `generated` | Finite number → timestamp and age reference; otherwise `null` (everything undated) |
| `bssid` | `String(x).trim().toLowerCase()`, `-` → `:`, 12 hex digits without separators → with `:`; missing → `"ap"+i` |
| `ssid` | String; `null`/missing → `""` (hidden); control characters removed; max 32 characters; always escaped on display |
| `band` | `"2.4"/"5"/"6"` or with suffix `/\s*ghz$/i`; otherwise from `freq` (≥ 5925 → 6, ≥ 5000 → 5, ≥ 2400 → 2.4); otherwise from `channel` (> 177 → 6; 32..177 → 5; 1..14 → 2.4; 6 GHz channels ≤ 177 cannot be told apart from 5 GHz without `band`/`freq` and end up on 5); otherwise `"unknown"` (own encoding: square; `#n-24/-5/-6` do not count `unknown`). The node also keeps `bandF`, the band from `band`/`freq` alone and never from `channel`, for the PMF row (§8.3) |
| `channel`, `freq`, `rssi`, `rate`, `width`, `last_seen`, `beacons`, `packets` | `Number.isFinite(+x) ? +x : null`; `rssi` clamped to [−120, 0]; `width` only ∈ {20, 40, 80, 160, 320}; `rssi` missing → −75 (AP) / `null` (client; the layout uses −85, size t = 0.25) |
| `security` | Raw string (max 48); `secClass(security, akm, cipher)`: AKM `owe` (without `psk`/`sae`/`1x…`) or text `OWE` → `owe` (before WPA3, because OWE sets the WPA3 class bit); `ENTERPRISE`/`802.1X` or a `1x…`/`fils…` AKM → `enterprise`; `TKIP` without `CCMP`/`GCMP`, or `pairwise` only `tkip` → `tkip-weak`; `WPA3` **and** `WPA2`, or AKM `sae` **and** `psk…`, or the text `SAE` **and** `PSK` → `wpa3-transition`; otherwise `WPA3`/`SAE` → `wpa3`; `WEP` → `wep`; `WPA2`/`RSN`/`CCMP` → `wpa2`; `WPA`/`PSK`/`TKIP`/`SECURED` → `wpa`; empty/`OPEN`/`NONE`/`ESS` → `open`; otherwise `unknown` |
| `vendor` | String, trimmed, max 48 characters, otherwise `null` (displayed as '—') |
| `phy` | String (`a/b/g/n/ac/ax/be`, also `"g/n"`), max 8, otherwise `null` → estimate §8.3 |
| `caps` | Array or string (split at `,`) → array of strings (max 12), otherwise `null` |
| `randomized` | `=== true` → true; otherwise U/L bit heuristic, only if there is no `vendor` |
| `clients[]` | Missing/not an array → `[]`; `mac` missing → `"<bssid>:c<j>"`; `unassociated[].mac` missing → `"free"+j`; `mac` normalised like `bssid` |
| `bluetooth` | Optional array (opt-in `STARCHORUS_BLUETOOTH=1`; absent = off, or no controller or tool). At most 256 entries: `addr` normalised like a station MAC and kept only when it is one; `addr_type` one of `public`, `random-static`, `random-resolvable`, `random-nonresolvable`, `random` (anything else is `random`); `rssi` clamped like a station's (an entry without one is skipped); `reports` and `last_seen` numbers; `company` an integer 0…65535; `company_name` string, max 48; `name` control characters removed, max 32; `connectable` only when `=== true`. A duplicate address keeps the stronger entry. A document without the array has none for the page (no button, counter or legend row). `center.bt_window` (seconds; `0` = no valid window this cycle, the array then holds only carried records) and `center.bt_hold` (seconds a record is carried after its window) are kept as numbers. Text from the air (`name`, `company_name`) is handled like an SSID: escaped on display |
| `activity` | Optional array of `{freq, share}` (opt-in `STARCHORUS_TRAFFIC=1`): entries with a numeric `freq` and `0 < share ≤ 1`, at most 69. A share of the frames heard on listed frequencies, never a count. It never feeds `channels[]`, the hop information, the baseline ghosts or the Watchlist's 'not heard now' |
| `alerts` | Optional array of `{type, t, ap, n}` (the collector writes it while `alerts.log` holds reports of the last `STARCHORUS_ALERT_WINDOW` seconds, §14.6): `type` is `deauth`, `ap` a MAC, `n` a number above 0, at most 20 entries; the page drops any other entry. `n` counts the firmware's reports, not frames; there is no channel and no signal strength, and the report's source address is not carried. Local and live (P6) |
| `packets` of a station | Cumulative frame counter of that MAC's rows heard in the last 300 s (opt-in Traffic, recon database source), absolute; the page derives a rate from consecutive captures (nothing on first sight, nothing after a drop, which is a new recon session). Access points get none |
| Duplicates | Same `bssid` twice → **merge**: `rssi = max`, `clients` united (by `mac`), missing fields from the later entry, non-empty `ssid` wins; same `mac` both associated **and** free → associated wins; same `mac` under two APs → the first AP wins |

A document without optional fields shows '—'; the U/L bit heuristic for `randomized` still applies. PHY appears only
as an estimate when `rate` is present.

### 2.9 Demo data (`demoData()`)

Built-in sample capture for starting without `starchorus.json`: 11 APs with unique BSSIDs (real OUI prefixes,
hash from SSID and band), `vendor` on some of the APs, `width/rate/phy` on a few, one hidden SSID, one 6 GHz AP,
open and WEP networks; 17 associated clients with unique MACs and 16 free clients (RSSI −58…−88) with real OUIs,
of which 3 are randomised (2nd hex digit `a`/`e`) without `vendor` and 2 without `rssi` ('n/a' path). SSIDs and `vendor` are
neutral placeholders (such as 'HomeWiFi', 'Office-5G', 'Vendor A'), not brand or product names. `generated: 1789300000`,
`center.label: "YOU ARE HERE"`, `source: "demo"`; every AP has a `last_seen` 4…1400 s before `generated`, so that all
freshness tiers (D1) occur. 'HomeWiFi' on 2.4 and 5 GHz forms a constellation. Counters: `#n-ap` 11,
`#n-cl` 33.

---

## 3. Theme system

### 3.1 Schema

A theme is a pure data object. Its top-level groups are listed in §3.8 (`meta, copy, surface, ink,
line, band, status, accent, rssi, glow, font, crt, particles, motion, depth, chart, render, chrome, look`). All three
themes fill **every** key. The schema is **symmetric**: `validateThemes()` (section 21, once at boot before
the first `applyTheme`) flattens all themes (`flatten`, arrays are leaves) and requires the same set of key paths in
every theme – there is no reference theme; a path missing from any theme is an error of exactly that theme.
Every leaf has the same kind in all themes (`number`/`string`/`boolean`/`array`; `null` = 'none' matches any kind;
arrays compare as `array` without length). Each finding → `console.warn` + `S.themeErrors++`; only afterwards, and only if
there is a finding, does `fillMissing` supply missing paths from a theme that carries them (crash protection, not a design fallback).
`validateTheme(t)` checks only values per theme (resolution of the `CSS_MIRROR` paths, `null` rule §3.2,
`rssi.dbmMin/dbmMax` = `LAYOUT`). `STARCHORUS.themeAudit()` returns the boot finding `{ids, union, keyCount, missing, kinds,
errors}` (before any supplementing), `themeAudit(true)` a fresh one over the current `THEMES`. Invariant:
`STARCHORUS.stats().themeErrors === 0` and `STARCHORUS.themeAudit().errors === 0` (three key sets of equal size).

**Copy tokens `copy` (D4).** Every statement the page makes about passivity and every source word is a token, with the same
63 leaf paths in all three themes: `copy.rx{meta, tag, motto, legRx, legArc, probeHint}` · `copy.active{… the same
keys}` · `copy.chip{demo, live, stale, offline, recorded, active, none}` · `copy.badge{…}` · `copy.logonMode{demo, live,
recorded, none, active}` · `copy.bannerBot{… the same five}` · `copy.logonListen{rx, active}` · the voice tokens
(`crowdSign`, `lamps`, `tote`, `clock`, `lampStrip`, `caption`, `compendium`, `vault`, `signal`, `skyVoice`,
`legendHeads`, `scope{strip[]}`) · per theme `logonHead[]`, `logonTail[]`, `bannerTop`. The shared values come from the theme-free
constants `COPY_SITES`/`COPY_ACTIVE`/`COPY_RX_MODE` (section 21); every `THEME.copy` begins with `...COPY_SITES` and may
reword individual values (`chip.offline` and `badge.offline` read 'Offline', in WarGames 'Link down', in Whitehall 'No link'). The only reader of the passivity statements is
`copyFor(site) = THEME.copy[sourceKind === "active" ? "active" : "rx"][site]` (section 38); chip, logon and
banner maps are indexed by `sourceKind`. Rule (regression run): the phrases
`rx only|nothing (is )?transmitted|never transmits|nothing sent|receive[- ]only|listen only|passive rx|nothing leaves`
appear in the page only in the head before the first marker or in section 00, in section 11 (first frame before the script,
identical to `copy.rx`) and in section 21 (the tokens).

### 3.2 CSS ↔ JS

- Section 02 carries the Foundation values statically (first paint without flicker).
- `applyTheme(id)` sets `document.documentElement.dataset.theme = id` and mirrors every `CSS_MIRROR` variable via
  `root.style.setProperty(name, TD.css[name])`. `CSS_MIRROR` (section 21) is a list of **triples**
  `[variable, tokenPath, suffix]`; `mirrorCss()` builds, once per theme,
  `TD.css[name] = tokenValue === null ? "none" : String(tokenValue) + suffix`. CSS reads only variables. `applyTheme` also sets
  `dataset.banner` (from `chrome.banner.show`), `dataset.cursor` (`motion.cursorBlinkMs > 0`) and
  `dataset.plaque` (from `chrome.plaqueTip.show`).

| Variable | Token path | Suffix | Variable | Token path | Suffix |
|---|---|---|---|---|---|
| `--surface-base` | `surface.base` | – | `--accent-selection` | `accent.selection` | – |
| `--surface-deep` | `surface.deep` | – | `--accent-wash` | `accent.selectionWash` | – |
| `--surface-raised` | `surface.raised` | – | `--accent-focus` | `accent.focusRing` | – |
| `--surface-gradient` | `surface.gradient` | – (`null` → `none`) | `--toggle-on` | `accent.toggleOn` | – |
| `--panel-fill` | `surface.panelFill` | – | `--toggle-ink` | `accent.toggleInk` | – |
| `--panel-border` | `surface.panelBorder` | – | `--toggle-border` | `accent.toggleBorder` | – |
| `--panel-blur` | `surface.panelBlurPx` | `px` | `--chrome-ink` | `chrome.ink` | – |
| `--panel-radius` | `surface.panelRadiusPx` | `px` | `--clock-p1` / `-p2` / `-p3` | `look.clock.p1` / `p2` / `p3` | – |
| `--panel-shadow` | `surface.panelShadow` | – | `--banner-fill` | `chrome.banner.fill` | – |
| `--ink-primary` | `ink.primary` | – | `--banner-ink` | `chrome.banner.ink` | – |
| `--ink-secondary` | `ink.secondary` | – | `--banner-rule` | `chrome.banner.rule` | – |
| `--ink-muted` | `ink.muted` | – | `--client` | `render.clientCore` | – |
| `--ink-on-fill` | `ink.onFill` | – | `--bubble-fill` | `render.bubbleFill` | – |
| `--line-hairline` | `line.hairline` | – | `--bubble-stroke` | `render.bubbleStroke` | – |
| `--line-soft` | `line.hairlineSoft` | – | `--font-ui` | `font.ui` | – |
| `--line-baseline` | `line.baseline` | – | `--font-mono` | `font.mono` | – |
| `--band-24` | `band.2.4.core` | – | `--text-transform` | `font.transform` | – |
| `--band-5` | `band.5.core` | – | `--letter-spacing` | `font.letterSpacing` | – |
| `--band-6` | `band.6.core` | – | `--heading-variant` | `font.headingVariant` | – |
| `--band-unknown` | `band.unknown.core` | – | `--lamp-off` | `chrome.lampStrip.off` | – |
| `--status-alarm` | `status.alarm` | – | `--size-label` / `-hud` / `-tip` / `-title` / `-hero` | `font.sizesPx.*` | `px` |
| `--status-alarm-wash` | `status.alarmWash` | – | `--crt-scanline-opacity` | `crt.scanlineOpacity` | – |
| `--status-ring-neutral` | `status.ringNeutral` | – | `--crt-scanline-period` | `crt.scanlinePeriodPx` | `px` |
| `--status-ring-strong` | `status.ringStrong` | – | `--crt-scanline-width` | `crt.scanlineWidthPx` | `px` |
| `--status-glyph` | `status.glyphInk` | – | `--crt-vignette-alpha` / `-inner` | `crt.vignetteAlpha` / `crt.vignetteInner` | – |
| `--status-hidden` | `status.hidden` | – | `--cursor-blink-ms` | `motion.cursorBlinkMs` | `ms` |
| `--bezel-color` | `chrome.bezel.color` | – | `--bezel-width` / `--bezel-gap` / `--bracket-size` | `chrome.bezel.widthPx` / `gapPx` / `bracketPx` | `px` |

  `null` rule: only `surface.gradient` may be `null` → `none` (a valid `background-image` value); any other
  `null` value of a mirrored path is a schema error (`validateTheme`, `S.themeErrors++`).
- `TK = flatten(THEME)` (path → value); `TD` = precomputed strings and flags (the CSS mirror values, band core
  colours, fonts, edge and particle colours, glow and shape switches). The hot path reads only `TD` and sprites,
  never `THEME.x.y.z` chains.
- `STARCHORUS.themeCheck()` compares every `CSS_MIRROR` variable via `getComputedStyle(...).getPropertyValue(name)`
  with **`TD.css[name]`** and returns `{ok, mismatches: [[name, css, js]…]}`.

### 3.3 `applyTheme(id, {intro, persist})` – switching at runtime without a reload

```
applyTheme(id, opts = {intro: true, persist: true}):
  if (!THEMES[id]) id = "foundation"
  THEME = THEMES[id]; TK = flatten(THEME); TD = deriveStrings(THEME); fillAnim()   // S.anim (§2.6)
  S.ui.theme = id; if (opts.persist !== false) { S.queryLocked.delete("theme"); saveUi() }
  set dataset.theme/cursor/banner/plaque; mirrorCss()
  if (changed) { clearSprites(); particlesReset(); measureCache.clear(); ctxSky.clearRect(0, 0, W, H) }   // no remnants of the old theme
  applyCrt(); rebuildBackground()
  buildLegend(); updateControlsLook(); if (S.locked) openDetail(S.locked)   // each ends in layoutEdges()
  renderSourceTruth(); if (changed) renderCaption(); updateStats(); S.dirty = true
  if (changed && introRunning) { endCoalesce(); skipLogon() }            // a switch ends the running intro
  if (changed && !reduceMotion && opts.intro !== false && !query.intro0 && !introSeen()) runIntro()   // D13: flag per theme ID
```
Camera, layout, bubbles and blend stay unchanged → `layoutInfo()` is identical before and after the switch.
`fillAnim()`: `fadeInK = 4.6·1000/motion.fadeInMs`, `fadeOutK = 4.6·1000/motion.fadeOutMs`, `blendK = 4.6·1000/motion.fadeInMs`,
`breathePeriodS = motion.breathePeriodMs/1000`, `cameraEasing` from `motion.cameraEasing`, the rest 1:1 from
`motion.*`/`depth.*`. Boot calls `applyTheme` with `persist: false`
when the theme comes from `?theme=`; `STARCHORUS.setTheme()` and `#t-theme` use the default `persist: true`.

### 3.4 Theme independence (check rule)

Layout (26–28), aggregation (27), analyser (29), step (30) and hit test (36) do **not** reference `THEME`/`TK`/`TD`:
`basePx = lerp(LAYOUT.coreRadiusPx[0], LAYOUT.coreRadiusPx[1], t) + min(clientCount, 8)·LAYOUT.clientBonusPx` is
theme-free, as are depth fog and far size (`CFG3D.fogNearAlpha/fogFarAlpha/sizeFarFactor`, §5.4). Star size,
label eligibility (`labelCandidateList`, §6.6) and hit radius (§5.5) are therefore the same in all themes; themes choose
only the look. Checkable:
```
awk '/==== 22 UTIL/,/==== 31 SPRITES/' starchorus.html | grep -c 'THEME\.\|TK\[\|TD\.'           → 0
awk '/==== 36 INTERACTION/,/==== 37 UI/' starchorus.html | grep -c 'THEME\.\|TK\[\|TD\.'         → 0
awk '/==== 31 SPRITES/,/==== 36 INTERACTION/' starchorus.html | grep -c '#[0-9a-fA-F]\{6\}'      → 0   (no hex literal in the renderer)
```
Layout distances (spread, orbit, bubble radius, exclusion zones, AP collision search) are computed solely from
`LAYOUT` and `basePxMax` (§4.1). All themes therefore have exactly the same layout, the same label candidates and
the same hit areas. `THEME.rssi.dbmMin/dbmMax` are informative and must equal `LAYOUT.rssiMin/rssiMax`.

### 3.5 Foundation (default)

A calm star chart: near-black with an indigo tint, cool band colours (teal/azure/indigo), gold only for the alarm and
pearl for the selection (shape tells them apart), dust clouds of particles, glow and bokeh, small capitals in the
chrome. The logon is `coalesce`: no overlay; the dust of the real capture condenses (§7.3). The values in §3.8, the branches in §7.1/§7.1a and the description in §7.2 are authoritative.

### 3.6 WarGames

A situation wall: black ground, navy grid with spokes and dot grid, wireframe stars with baked bloom,
'+' clients, monospaced capitals, blinking cursor, CRT overlay (scanlines, vignette, persistence; `C`), parabolic arcs with
a travelling dot, and probe arcs. Besides colour, the bands carry **shape** (circle/diamond/hexagon), because the palette
is not sufficient for deuteranopia (red↔green); the alarm is strictly red and always additionally shape + '!'. §3.8,
§7.1/§7.1a and §7.3 are authoritative.

Whitehall (the third theme) is a plotting table: plot grid with 12 spokes, chalk selection, freshness lamps per band,
sector clock, an exercise banner (every line ends with 'NOT A GOVERNMENT SYSTEM') and a teleprinter logon at a
constant rate. Its branches are in §7.1a.

### 3.7 `ENCODING` (shared, not a theme token)

```js
const ENCODING = {
  band: { "2.4": { shape: "circle",  legend: "2.4 GHz", suffix: "2.4" }, "5": { shape: "diamond", legend: "5 GHz", suffix: "5" },
          "6":   { shape: "hexagon", legend: "6 GHz",   suffix: "6" },   unknown: { shape: "square", legend: "Band ?", suffix: "?" } },
  security: {
    open:              { ring: "gap",    widthPx: 1.5, dash: null,   glyph: "!", tone: "alarm",   label: "OPEN" },   // D6: one mark for open and WEP,
    wep:               { ring: "gap",    widthPx: 1.5, dash: null,   glyph: "!", tone: "alarm",   label: "WEP" },    // ring with a 60° gap at NE, the "!" sits there
    wpa:               { ring: "thin",   widthPx: 1,   dash: null,   glyph: "",  tone: "neutral", label: "WPA" },
    wpa2:              { ring: "double", widthPx: 1,   dash: null,   glyph: "",  tone: "neutral", label: "WPA2" },
    wpa3:              { ring: "solid",  widthPx: 1.5, dash: null,   glyph: "3", tone: "strong",  label: "WPA3" },
    owe:               { ring: "thin",   widthPx: 1,   dash: null,   glyph: "◇", tone: "neutral", label: "OWE" },
    enterprise:        { ring: "thin",   widthPx: 1,   dash: [5, 2], glyph: "E", tone: "neutral", label: "ENTERPRISE" },
    "wpa3-transition": { ring: "double", widthPx: 1.5, dash: null,   glyph: "3", tone: "strong",  label: "WPA3/2" },
    "tkip-weak":       { ring: "thin",   widthPx: 1,   dash: [1, 3], glyph: "~", tone: "neutral", label: "TKIP" },
    unknown:           { ring: "none",   widthPx: 0,   dash: null,   glyph: "?", tone: "muted",   label: "?" },
  },
  fresh: { alpha: [1, 0.85, 0.7, 0.55], words: ["heard < 1 min", "heard < 5 min", "heard < 15 min", "on record"], undated: "undated" },   // D1
  ringOffsetPx: 4, doubleRingGapPx: 3, selectionRingOffsetPx: 13, gapDeg: 60, pin: { gapDeg: 70, notchPx: 3 },   // D5
  hidden: { ring: "dashed", dash: [4, 4], widthPx: 1, offsetPx: 10 },
  merge: { dash: [6, 2, 1, 2], extraPx: 3 },   // D17: its own pattern, never the [4,4] of the hidden ring
  ghost: { dash: [2, 2], r: 5 },               // D19
  identity: { unknown: { frame: "none" }, friend: { frame: "rect" }, neutral: { frame: "square" }, hostile: { frame: "diamond", dash: [3, 2], btn: "Suspect" } },   // §8.10
};
```
Band = colour (theme) × shape × label suffix × legend; security = ring shape + glyph, colour only for the alarm;
selection = solid ring at r + 13 (differs from the security ring at r + 4 by radius and shape); pin =
notched arc (D5), never the selection ring. `rssiT` lives only in UTIL (`LAYOUT.rssiMin/Max`); there is no second version.

### 3.8 Token blocks of all three themes (verbatim, generated by machine from the code)

These three blocks are authoritative: `JSON.stringify(STARCHORUS._internals.THEMES[id])`, one line per top-level
key. **`tools/spec-sync.py` generates them** (`sh tools/dump-themes.sh themes out/themes.json`, then
`python3 tools/spec-sync.py out/themes.json out/contrast.json docs/architecture.md`); the regression (`tools/regress.d/doc-binding.sh`) checks with
`--check` that they are **deep-equal** to the code – a changed token without updated documentation makes it fail. All
three themes carry the same keys (`validateThemes`, regression `tools/regress.d/theme-schema.sh`).

<!-- spec-sync:themes:begin -->
```json
// THEMES.foundation
{
  "meta": {"id": "foundation", "label": "Foundation", "isDefault": true},
  "copy": {"rx": {"meta": "A strictly passive Wi-Fi landscape visualiser — access points as stars, clients as satellites. RX only, nothing is transmitted.", "tag": "passive observation · rx only — access points are stars, their clients orbit as satellites; distance from the centre tracks signal strength.", "motto": "Observation only — it listens, it never transmits.", "legRx": "RX only · nothing is transmitted", "legArc": "arc = heard probe (rx only)", "probeHint": "(heard probe requests, rx only)"}, "active": {"meta": "A Wi-Fi landscape visualiser — access points as stars, clients as satellites. ACTIVE SCAN · the collector sent probe requests.", "tag": "ACTIVE SCAN · the collector sent probe requests — access points are stars, their clients orbit as satellites; distance from the centre tracks signal strength.", "motto": "Wi-Fi landscape visualiser.", "legRx": "ACTIVE SCAN · the collector sent probe requests", "legArc": "arc = heard probe", "probeHint": "(heard probe requests)"}, "chip": {"demo": "Sample", "live": "Live", "stale": "Stale", "offline": "Offline", "recorded": "Recorded", "active": "Active scan", "none": "No feed"}, "badge": {"demo": "Simulation", "live": "Live RX", "stale": "Stale", "offline": "Offline", "recorded": "Recorded", "active": "Active scan", "none": "No feed"}, "crowdSign": {"title": "Channel crowding", "caption": "derived from channel overlap · not a security assessment", "steps": ["1", "2", "3", "4", "5"]}, "lamps": "capture counter, binary", "tote": {"title": "Plot freshness", "labels": ["HEARD", "RECENT", "FADING", "ON RECORD"], "undated": "undated"}, "clock": "sector clock", "lampStrip": {"title": "Heard this minute", "more": "more"}, "caption": "observer and capture time", "compendium": {"title": "Compendium of the Local Sky"}, "vault": {"title": "Vault", "up": "busier than this sky usually is", "down": "quieter than this sky usually is"}, "logonListen": {"rx": "", "active": ""}, "logonMode": {"demo": "MODE: RX ONLY — NOTHING IS TRANSMITTED · SAMPLE SKY", "live": "MODE: RX ONLY — NOTHING IS TRANSMITTED · LIVE FEED", "recorded": "MODE: RX ONLY — NOTHING IS TRANSMITTED · RECORDED CAPTURE", "none": "MODE: RX ONLY — NOTHING IS TRANSMITTED · NO FEED", "active": "MODE: ACTIVE SCAN · THE COLLECTOR SENT PROBE REQUESTS"}, "bannerBot": {"demo": "SIMULATED TRAFFIC · NOTHING IS TRANSMITTED · RX ONLY", "live": "LIVE FEED · NOTHING IS TRANSMITTED · RX ONLY", "recorded": "RECORDED CAPTURE · NOTHING IS TRANSMITTED · RX ONLY", "none": "NO FEED · NOTHING IS TRANSMITTED · RX ONLY", "active": "ACTIVE SCAN · THE COLLECTOR SENT PROBE REQUESTS"}, "logonHead": ["STARCHORUS  ·  OBSERVATION TERMINAL", "LOGON: OBSERVER"], "logonTail": ["…LOADING SKY"], "bannerTop": "EXERCISE · STARCHORUS · NOT A GOVERNMENT SYSTEM", "signal": ["excellent", "good", "weak", "marginal"], "skyVoice": "Compendium", "scope": {"strip": ["Stars", "Satellites", "Clouds", "Brightest", "New"]}, "legendHeads": {"measured": "Measured", "derived": "Derived", "operator": "Operator", "look": "Look"}},
  "surface": {"base": "#05070d", "deep": "#05070d", "raised": "#0a1122", "gradient": "radial-gradient(120% 120% at 50% 42%, #0a1122 0%, #080b16 46%, #05070d 100%)", "panelFill": "rgba(8,11,22,0.80)", "panelBorder": "rgba(233,228,216,0.16)", "panelBlurPx": 12, "panelRadiusPx": 3, "panelShadow": "0 12px 40px rgba(0,0,0,0.55)"},
  "ink": {"primary": "#dfe7fb", "secondary": "#9aa7c4", "muted": "#6f7c9c", "onFill": "#05070d"},
  "line": {"hairline": "rgba(233,228,216,0.20)", "hairlineSoft": "rgba(233,228,216,0.09)", "baseline": "rgba(140,165,220,0.30)", "ring": "rgba(140,165,220,0.56)", "widthPx": 1, "device": "rgba(233,228,216,0.40)", "edge": {"style": "bezier", "curvature": 0.18, "color": "rgba(233,228,216,0.18)", "widthPx": 1, "glowPx": 6}},
  "band": {"5": {"core": "#2896f5", "glow": "rgba(255,224,170,0.42)"}, "6": {"core": "#7153dd", "glow": "rgba(255,224,170,0.42)"}, "2.4": {"core": "#038d86", "glow": "rgba(255,224,170,0.42)"}, "unknown": {"core": "#7c828c", "glow": "rgba(255,224,170,0.24)"}},
  "status": {"alarm": "#e0b95a", "alarmWash": "rgba(224,185,90,0.10)", "alarmAura": "none", "alert": "#e5484d", "ringNeutral": "#9aa7c4", "ringStrong": "#dfe7fb", "glyphInk": "#9aa7c4", "hidden": "#6f7c9c"},
  "accent": {"selection": "#e9e4d8", "selectionWash": "rgba(233,228,216,0.12)", "focusRing": "#e9e4d8", "flare": "rgba(255,220,180,0.20)", "toggleOn": "#e9e4d8", "toggleInk": "#05070d", "toggleBorder": "#e9e4d8"},
  "rssi": {"dbmMin": -90, "dbmMax": -30, "glowRadiusFactor": [1.2, 3], "glowAlpha": 0.45, "bloomPx": [0, 0]},
  "glow": {"mode": "mono", "color": "rgba(255,224,170,1)", "maxBlurPx": 28, "ringGlowPx": 0},
  "font": {"ui": "-apple-system, BlinkMacSystemFont, \"SF Pro Display\", \"Helvetica Neue\", \"Inter\", \"Segoe UI\", system-ui, sans-serif", "mono": "ui-monospace, \"SF Mono\", Menlo, \"JetBrains Mono\", Consolas, monospace", "transform": "none", "letterSpacing": "0.04em", "headingVariant": "small-caps", "sizesPx": {"label": 11, "hud": 11, "tip": 12, "title": 13, "hero": 22}, "weight": {"label": 400, "title": 600, "hero": 600}, "numeric": {"hero": "proportional", "axis": "tabular"}},
  "crt": {"scanlineOpacity": 0, "scanlinePeriodPx": 0, "scanlineWidthPx": 0, "vignetteAlpha": 0, "vignetteInner": 1, "persistenceAlpha": 0, "flickerAmp": 0, "userToggle": false},
  "particles": {"perNode": [6, 24], "spreadFactor": 1.8, "sigmaFactor": 0.6, "lifeMs": [2400, 4200], "sizePx": [0.6, 1.4], "alpha": [0.25, 0.6], "driftPxPerS": 4, "gatherMs": 900, "dissolveMs": 1400, "maxTotal": 2400, "color": "rgba(255,214,150,1)", "cohesion": {"scale": [1, 1.3, 1.7, 2.3], "alpha": [1, 0.85, 0.65, 0.45]}, "spiral": {"dawnRad": 1.4, "duskRad": 0.9}, "lit": true, "shade": "rgba(176,122,60,1)"},
  "motion": {"autoRotateRadPerS": 0.05, "breathePeriodMs": 6000, "breatheAmp": 0.06, "fadeInMs": 900, "fadeOutMs": 1400, "cameraEaseMs": 1200, "cameraEasing": "easeInOutCubic", "edgeTravelDotSpeed": 0, "edgeTravelDotPx": 0, "cursorBlinkMs": 0, "introStyle": "coalesce", "logonCharMs": [28, 58]},
  "depth": {"bokeh": {"enabled": true, "farSoftness": 2.4, "nearSoftness": 1}, "lensFlare": {"enabled": true, "maxStars": 2, "lengthFactor": 6, "alpha": 0.18}},
  "chart": {"lineWidthPx": 2, "lineJoin": "round", "markerRadiusPx": 4, "markerRingPx": 2, "areaAlpha": 0.1, "gridStyle": "solid", "gridWidthPx": 1, "barMaxPx": 24, "barRadiusPx": 4, "barGapPx": 2, "labelPolicy": "endpoint", "tooltip": true, "crosshair": true, "legend": "auto", "hitTargetPx": 24, "textToken": "ink.secondary", "axisTextToken": "ink.muted", "axisNumeric": "tabular", "deemphasis": "#6f7c9c", "sparklinePoints": 60, "refetchHoldAlpha": 0.6},
  "render": {"clientCore": "#dfe7fb", "clientRing": "band", "clientShape": "disc", "bubbleFill": "rgba(210,214,224,0.10)", "bubbleStroke": "rgba(210,214,224,0.75)", "nebula": "rgba(210,214,224,1)", "starfield": {"density": 5200, "color": "#aebbe0", "alpha": [0.12, 0.62], "twinkleFrac": 0.15}, "grid": {"spokes": 0, "dotStepPx": 0}, "shadow": "rgba(0,0,0,0.12)", "composite": "source-over", "shapeFill": true, "probeArc": false, "deviceTie": "bezier", "changeCue": "glowPulse", "clientRandomizedMark": "hollow", "bubbleTicks": false, "btMark": "#d77fa8", "phosphor": {"enabled": false, "alpha": [0, 0, 0, 0], "radiusFactor": 0}, "recvRing": {"enabled": false, "fromPx": 0, "toPx": 0, "ms": 0}, "arrivalArcs": false, "coreMark": "sun", "newPlotMark": {"enabled": false, "dash": [3, 3], "offsetPx": 6}, "coreBeat": {"enabled": true, "hz": 0.8, "amp": 0.07}},
  "look": {"clock": {"p1": "#7c828c", "p2": "#9aa7c4", "p3": "#6f7c9c"}},
  "chrome": {"ink": "#e9e4d8", "bezel": {"color": "rgba(0,0,0,0)", "widthPx": 0, "gapPx": 0, "bracketPx": 0}, "banner": {"show": false, "fill": "rgba(0,0,0,0)", "ink": "#e9e4d8", "rule": "rgba(0,0,0,0)"}, "badge": {"show": false}, "crowdSign": {"show": false}, "lamps": {"show": false, "count": 8}, "clock": {"show": false}, "tote": {"show": false}, "compendium": {"show": true}, "vault": {"show": true}, "lampStrip": {"max": 0, "off": "#3d3d3d"}, "plaqueTip": {"show": false}, "caption": {"show": true}}
}
```

```json
// THEMES.wargames
{
  "meta": {"id": "wargames", "label": "WARGAMES", "isDefault": false},
  "copy": {"rx": {"meta": "A strictly passive Wi-Fi landscape visualiser — access points as stars, clients as satellites. RX only, nothing is transmitted.", "tag": "passive observation · rx only — access points are stars, their clients orbit as satellites; distance from the centre tracks signal strength.", "motto": "Observation only — it listens, it never transmits.", "legRx": "RX only · nothing is transmitted", "legArc": "arc = heard probe (rx only)", "probeHint": "(heard probe requests, rx only)"}, "active": {"meta": "A Wi-Fi landscape visualiser — access points as stars, clients as satellites. ACTIVE SCAN · the collector sent probe requests.", "tag": "ACTIVE SCAN · the collector sent probe requests — access points are stars, their clients orbit as satellites; distance from the centre tracks signal strength.", "motto": "Wi-Fi landscape visualiser.", "legRx": "ACTIVE SCAN · the collector sent probe requests", "legArc": "arc = heard probe", "probeHint": "(heard probe requests)"}, "chip": {"demo": "Sample", "live": "Live", "stale": "Stale", "offline": "Link down", "recorded": "Recorded", "active": "Active scan", "none": "No feed"}, "badge": {"demo": "Simulation", "live": "Live RX", "stale": "Stale", "offline": "Link down", "recorded": "Recorded", "active": "Active scan", "none": "No feed"}, "crowdSign": {"title": "Channel crowding", "caption": "derived from channel overlap · not a security assessment", "steps": ["1", "2", "3", "4", "5"]}, "lamps": "capture counter, binary", "tote": {"title": "Plot freshness", "labels": ["HEARD", "RECENT", "FADING", "ON RECORD"], "undated": "undated"}, "clock": "sector clock", "lampStrip": {"title": "Heard this minute", "more": "more"}, "caption": "observer and capture time", "compendium": {"title": "Compendium of the Local Sky"}, "vault": {"title": "Vault", "up": "busier than this sky usually is", "down": "quieter than this sky usually is"}, "logonListen": {"rx": "LISTEN ONLY · STARCHORUS SENDS NO FRAMES", "active": ""}, "logonMode": {"demo": "MODE: RX ONLY — NOTHING IS TRANSMITTED · SAMPLE SKY", "live": "MODE: RX ONLY — NOTHING IS TRANSMITTED · LIVE FEED", "recorded": "MODE: RX ONLY — NOTHING IS TRANSMITTED · RECORDED CAPTURE", "none": "MODE: RX ONLY — NOTHING IS TRANSMITTED · NO FEED", "active": "MODE: ACTIVE SCAN · THE COLLECTOR SENT PROBE REQUESTS"}, "bannerBot": {"demo": "SIMULATED TRAFFIC · NOTHING IS TRANSMITTED · RX ONLY", "live": "LIVE FEED · NOTHING IS TRANSMITTED · RX ONLY", "recorded": "RECORDED CAPTURE · NOTHING IS TRANSMITTED · RX ONLY", "none": "NO FEED · NOTHING IS TRANSMITTED · RX ONLY", "active": "ACTIVE SCAN · THE COLLECTOR SENT PROBE REQUESTS"}, "logonHead": ["STARCHORUS  ·  OBSERVATION TERMINAL", "LOGON: OBSERVER"], "logonTail": ["…LOADING SKY"], "bannerTop": "EXERCISE · STARCHORUS · NOT A GOVERNMENT SYSTEM", "signal": ["MAX", "STRONG", "WEAK", "MIN"], "skyVoice": "SKY SUMMARY", "scope": {"strip": ["NETS", "STATIONS", "CLOUDS", "PEAK", "NEW"]}, "legendHeads": {"measured": "Measured", "derived": "Derived", "operator": "Operator", "look": "Look"}},
  "surface": {"base": "#000000", "deep": "#000000", "raised": "#000000", "gradient": null, "panelFill": "rgba(0,0,0,0.85)", "panelBorder": "#0f234b", "panelBlurPx": 0, "panelRadiusPx": 0, "panelShadow": "none"},
  "ink": {"primary": "#e6e6dc", "secondary": "#a7a7a7", "muted": "#808080", "onFill": "#000000"},
  "line": {"hairline": "#0f234b", "hairlineSoft": "rgba(15,35,75,0.60)", "baseline": "#0f234b", "ring": "#287878", "widthPx": 1, "device": "rgba(154,154,144,0.70)", "edge": {"style": "parabola", "curvature": 0.28, "color": "rgba(167,167,167,0.45)", "widthPx": 1, "glowPx": 6}},
  "band": {"5": {"core": "#6ad2f9", "glow": "self"}, "6": {"core": "#8457a2", "glow": "self"}, "2.4": {"core": "#2ab42a", "glow": "self"}, "unknown": {"core": "#808080", "glow": "self"}},
  "status": {"alarm": "#fa4809", "alarmWash": "rgba(250,72,9,0.10)", "alarmAura": "wash", "alert": "#ff3b3b", "ringNeutral": "#a7a7a7", "ringStrong": "#e6e6dc", "glyphInk": "#a7a7a7", "hidden": "#808080"},
  "accent": {"selection": "#e6e6dc", "selectionWash": "rgba(230,230,220,0.10)", "focusRing": "#e6e6dc", "flare": "rgba(0,0,0,0)", "toggleOn": "#287878", "toggleInk": "#ffffff", "toggleBorder": "#287878"},
  "rssi": {"dbmMin": -90, "dbmMax": -30, "glowRadiusFactor": [0, 0], "glowAlpha": 0, "bloomPx": [4, 12]},
  "glow": {"mode": "self", "color": null, "maxBlurPx": 12, "ringGlowPx": 4},
  "font": {"ui": "ui-monospace, \"SF Mono\", Menlo, \"IBM Plex Mono\", \"Courier New\", monospace", "mono": "ui-monospace, \"SF Mono\", Menlo, \"IBM Plex Mono\", \"Courier New\", monospace", "transform": "uppercase", "letterSpacing": "0.12em", "headingVariant": "normal", "sizesPx": {"label": 11, "hud": 11, "tip": 12, "title": 13, "hero": 22}, "weight": {"label": 400, "title": 600, "hero": 600}, "numeric": {"hero": "proportional", "axis": "tabular"}},
  "crt": {"scanlineOpacity": 0.1, "scanlinePeriodPx": 3, "scanlineWidthPx": 1, "vignetteAlpha": 0.45, "vignetteInner": 0.6, "persistenceAlpha": 0.25, "flickerAmp": 0.015, "userToggle": true},
  "particles": {"perNode": [0, 0], "spreadFactor": 0, "sigmaFactor": 0, "lifeMs": [0, 0], "sizePx": [0, 0], "alpha": [0, 0], "driftPxPerS": 0, "gatherMs": 0, "dissolveMs": 0, "maxTotal": 0, "color": null, "cohesion": {"scale": [1, 1, 1, 1], "alpha": [1, 1, 1, 1]}, "spiral": {"dawnRad": 0, "duskRad": 0}, "lit": false, "shade": null},
  "motion": {"autoRotateRadPerS": 0.12, "breathePeriodMs": 0, "breatheAmp": 0, "fadeInMs": 250, "fadeOutMs": 400, "cameraEaseMs": 600, "cameraEasing": "easeOutQuad", "edgeTravelDotSpeed": 0.35, "edgeTravelDotPx": 1.5, "cursorBlinkMs": 530, "introStyle": "typed", "logonCharMs": [28, 58]},
  "depth": {"bokeh": {"enabled": false, "farSoftness": 1, "nearSoftness": 1}, "lensFlare": {"enabled": false, "maxStars": 0, "lengthFactor": 0, "alpha": 0}},
  "chart": {"lineWidthPx": 2, "lineJoin": "round", "markerRadiusPx": 4, "markerRingPx": 2, "areaAlpha": 0.1, "gridStyle": "solid", "gridWidthPx": 1, "barMaxPx": 24, "barRadiusPx": 4, "barGapPx": 2, "labelPolicy": "endpoint", "tooltip": true, "crosshair": true, "legend": "auto", "hitTargetPx": 24, "textToken": "ink.secondary", "axisTextToken": "ink.muted", "axisNumeric": "tabular", "deemphasis": "#808080", "sparklinePoints": 60, "refetchHoldAlpha": 0.6},
  "render": {"clientCore": "#e6e6dc", "clientRing": "band", "clientShape": "cross", "bubbleFill": "rgba(0,0,0,0.60)", "bubbleStroke": "#a7a7a7", "nebula": "rgba(154,154,144,1)", "starfield": {"density": 0, "color": "#000000", "alpha": [0, 0], "twinkleFrac": 0}, "grid": {"spokes": 8, "dotStepPx": 48}, "shadow": "rgba(0,0,0,0)", "composite": "source-over", "shapeFill": false, "probeArc": true, "deviceTie": "bracket", "changeCue": "bloomPulse", "clientRandomizedMark": "crossX", "bubbleTicks": true, "btMark": "#e87ac8", "phosphor": {"enabled": true, "alpha": [0.55, 0.34, 0.16, 0], "radiusFactor": 2.4}, "recvRing": {"enabled": true, "fromPx": 18.5, "toPx": 10.5, "ms": 300}, "arrivalArcs": true, "coreMark": "reticle", "newPlotMark": {"enabled": false, "dash": [3, 3], "offsetPx": 6}, "coreBeat": {"enabled": false, "hz": 0, "amp": 0}},
  "look": {"clock": {"p1": "#808080", "p2": "#a7a7a7", "p3": "#8b8b80"}},
  "chrome": {"ink": "#e6e6dc", "bezel": {"color": "#287878", "widthPx": 1, "gapPx": 0, "bracketPx": 10}, "banner": {"show": false, "fill": "rgba(0,0,0,0)", "ink": "#e6e6dc", "rule": "rgba(0,0,0,0)"}, "badge": {"show": true}, "crowdSign": {"show": true}, "lamps": {"show": true, "count": 8}, "clock": {"show": false}, "tote": {"show": false}, "compendium": {"show": false}, "vault": {"show": false}, "lampStrip": {"max": 48, "off": "#3d3d3d"}, "plaqueTip": {"show": false}, "caption": {"show": false}}
}
```

```json
// THEMES.whitehall
{
  "meta": {"id": "whitehall", "label": "WHITEHALL", "isDefault": false},
  "copy": {"rx": {"meta": "A strictly passive Wi-Fi landscape visualiser — access points as stars, clients as satellites. RX only, nothing is transmitted.", "tag": "passive observation · rx only — access points are stars, their clients orbit as satellites; distance from the centre tracks signal strength.", "motto": "Observation only — it listens, it never transmits.", "legRx": "RX only · nothing is transmitted", "legArc": "arc = heard probe (rx only)", "probeHint": "(heard probe requests, rx only)"}, "active": {"meta": "A Wi-Fi landscape visualiser — access points as stars, clients as satellites. ACTIVE SCAN · the collector sent probe requests.", "tag": "ACTIVE SCAN · the collector sent probe requests — access points are stars, their clients orbit as satellites; distance from the centre tracks signal strength.", "motto": "Wi-Fi landscape visualiser.", "legRx": "ACTIVE SCAN · the collector sent probe requests", "legArc": "arc = heard probe", "probeHint": "(heard probe requests)"}, "chip": {"demo": "Sample", "live": "Live", "stale": "Stale", "offline": "No link", "recorded": "Recorded", "active": "Active scan", "none": "No feed"}, "badge": {"demo": "Simulation", "live": "Live RX", "stale": "Stale", "offline": "No link", "recorded": "Recorded", "active": "Active scan", "none": "No feed"}, "crowdSign": {"title": "Channel crowding", "caption": "derived from channel overlap · not a security assessment", "steps": ["1", "2", "3", "4", "5"]}, "lamps": "capture counter, binary", "tote": {"title": "Plot freshness", "labels": ["HEARD", "RECENT", "FADING", "ON RECORD"], "undated": "undated"}, "clock": "sector clock", "lampStrip": {"title": "Heard this minute", "more": "more"}, "caption": "observer and capture time", "compendium": {"title": "Compendium of the Local Sky"}, "vault": {"title": "Vault", "up": "busier than this sky usually is", "down": "quieter than this sky usually is"}, "logonListen": {"rx": "", "active": ""}, "logonMode": {"demo": "MODE: RX ONLY - NOTHING IS TRANSMITTED - SAMPLE SKY", "live": "MODE: RX ONLY - NOTHING IS TRANSMITTED - LIVE FEED", "recorded": "MODE: RX ONLY - NOTHING IS TRANSMITTED - RECORDED CAPTURE", "none": "MODE: RX ONLY - NOTHING IS TRANSMITTED - NO FEED", "active": "MODE: ACTIVE SCAN - THE COLLECTOR SENT PROBE REQUESTS"}, "bannerBot": {"demo": "SIMULATED PLOTS · PASSIVE RECEIVE ONLY · NOT A GOVERNMENT SYSTEM", "live": "REAL-WORLD DATA · NOT EXERCISE PLAY · {src} · LIVE · NOT A GOVERNMENT SYSTEM", "recorded": "REAL-WORLD DATA · NOT EXERCISE PLAY · {src} · RECORDED · NOT A GOVERNMENT SYSTEM", "none": "ENDEX · NO FEED · NOT A GOVERNMENT SYSTEM", "active": "ACTIVE SCAN · THE COLLECTOR SENT PROBE REQUESTS · {src} · NOT A GOVERNMENT SYSTEM"}, "logonHead": ["STARTEX", "STARCHORUS - PLOTTING TERMINAL", "CONNECTING TO FEED..."], "logonTail": ["EXERCISE - NOT A GOVERNMENT SYSTEM", "...PLOTTING"], "bannerTop": "EXERCISE – EXERCISE – EXERCISE · NOT A GOVERNMENT SYSTEM", "signal": ["STRONG", "GOOD", "WEAK", "FAINT"], "skyVoice": "SITREP", "scope": {"strip": ["NETWORKS", "STATIONS", "CLOUDS", "STRONGEST", "NEW PLOTS"]}, "legendHeads": {"measured": "Plots", "derived": "Filter room · derived", "operator": "Operator", "look": "Look"}},
  "surface": {"base": "#0a0f0b", "deep": "#070b08", "raised": "#0c130d", "gradient": "radial-gradient(120% 120% at 50% 44%, #0d160f 0%, #0a0f0b 52%, #070b08 100%)", "panelFill": "rgba(8,14,9,0.86)", "panelBorder": "#3b4738", "panelBlurPx": 0, "panelRadiusPx": 2, "panelShadow": "none"},
  "ink": {"primary": "#d7dad1", "secondary": "#96a08f", "muted": "#7d8674", "onFill": "#0a0f0b"},
  "line": {"hairline": "rgba(215,218,209,0.14)", "hairlineSoft": "rgba(215,218,209,0.07)", "baseline": "rgba(215,218,209,0.24)", "ring": "rgba(215,218,209,0.42)", "widthPx": 1, "device": "rgba(215,218,209,0.55)", "edge": {"style": "bezier", "curvature": 0.16, "color": "rgba(215,218,209,0.28)", "widthPx": 1, "glowPx": 6}},
  "band": {"5": {"core": "#3e7cff", "glow": "self"}, "6": {"core": "#c77dff", "glow": "self"}, "2.4": {"core": "#3fb950", "glow": "self"}, "unknown": {"core": "#c8ccc4", "glow": "self"}},
  "status": {"alarm": "#e5484d", "alarmWash": "rgba(229,72,77,0.12)", "alarmAura": "wash", "alert": "#e5484d", "ringNeutral": "#96a08f", "ringStrong": "#d7dad1", "glyphInk": "#96a08f", "hidden": "#7d8674"},
  "accent": {"selection": "#f4f5ef", "selectionWash": "rgba(244,245,239,0.12)", "focusRing": "#f4f5ef", "flare": "rgba(0,0,0,0)", "toggleOn": "#d7dad1", "toggleInk": "#0a0f0b", "toggleBorder": "#d7dad1"},
  "rssi": {"dbmMin": -90, "dbmMax": -30, "glowRadiusFactor": [0, 0], "glowAlpha": 0, "bloomPx": [3, 10]},
  "glow": {"mode": "self", "color": null, "maxBlurPx": 10, "ringGlowPx": 3},
  "font": {"ui": "\"Starchorus Sans\", \"Frutiger\", \"Segoe UI\", system-ui, \"Helvetica Neue\", Arial, sans-serif", "mono": "ui-monospace, \"SF Mono\", Menlo, \"Consolas\", \"DejaVu Sans Mono\", monospace", "transform": "uppercase", "letterSpacing": "0.04em", "headingVariant": "normal", "sizesPx": {"label": 11, "hud": 11, "tip": 12, "title": 13, "hero": 22}, "weight": {"label": 500, "title": 600, "hero": 600}, "numeric": {"hero": "tabular", "axis": "tabular"}},
  "crt": {"scanlineOpacity": 0, "scanlinePeriodPx": 0, "scanlineWidthPx": 0, "vignetteAlpha": 0, "vignetteInner": 1, "persistenceAlpha": 0, "flickerAmp": 0, "userToggle": false},
  "particles": {"perNode": [0, 0], "spreadFactor": 0, "sigmaFactor": 0, "lifeMs": [0, 0], "sizePx": [0, 0], "alpha": [0, 0], "driftPxPerS": 0, "gatherMs": 0, "dissolveMs": 0, "maxTotal": 0, "color": null, "cohesion": {"scale": [1, 1, 1, 1], "alpha": [1, 1, 1, 1]}, "spiral": {"dawnRad": 0, "duskRad": 0}, "lit": false, "shade": null},
  "motion": {"autoRotateRadPerS": 0.06, "breathePeriodMs": 0, "breatheAmp": 0, "fadeInMs": 300, "fadeOutMs": 500, "cameraEaseMs": 800, "cameraEasing": "easeOutQuad", "edgeTravelDotSpeed": 0, "edgeTravelDotPx": 0, "cursorBlinkMs": 0, "introStyle": "typed", "logonCharMs": [37.5, 37.5]},
  "depth": {"bokeh": {"enabled": false, "farSoftness": 1, "nearSoftness": 1}, "lensFlare": {"enabled": false, "maxStars": 0, "lengthFactor": 0, "alpha": 0}},
  "chart": {"lineWidthPx": 2, "lineJoin": "round", "markerRadiusPx": 4, "markerRingPx": 2, "areaAlpha": 0.1, "gridStyle": "solid", "gridWidthPx": 1, "barMaxPx": 24, "barRadiusPx": 0, "barGapPx": 2, "labelPolicy": "endpoint", "tooltip": true, "crosshair": true, "legend": "auto", "hitTargetPx": 24, "textToken": "ink.secondary", "axisTextToken": "ink.muted", "axisNumeric": "tabular", "deemphasis": "#7d8674", "sparklinePoints": 60, "refetchHoldAlpha": 0.6},
  "render": {"clientCore": "#d7dad1", "clientRing": "band", "clientShape": "cross", "bubbleFill": "rgba(10,15,11,0.60)", "bubbleStroke": "#7d8674", "nebula": "rgba(150,160,143,1)", "starfield": {"density": 0, "color": "#000000", "alpha": [0, 0], "twinkleFrac": 0}, "grid": {"spokes": 12, "dotStepPx": 40}, "shadow": "rgba(0,0,0,0)", "composite": "source-over", "shapeFill": false, "probeArc": false, "deviceTie": "bracket", "changeCue": "tick", "clientRandomizedMark": "crossX", "bubbleTicks": false, "btMark": "#a8509a", "phosphor": {"enabled": false, "alpha": [0, 0, 0, 0], "radiusFactor": 0}, "recvRing": {"enabled": false, "fromPx": 0, "toPx": 0, "ms": 0}, "arrivalArcs": false, "coreMark": "ownship", "newPlotMark": {"enabled": true, "dash": [3, 3], "offsetPx": 9}, "coreBeat": {"enabled": false, "hz": 0, "amp": 0}},
  "look": {"clock": {"p1": "#8a4a44", "p2": "#a08a4a", "p3": "#4a6a8f"}},
  "chrome": {"ink": "#d7dad1", "bezel": {"color": "rgba(0,0,0,0)", "widthPx": 0, "gapPx": 0, "bracketPx": 0}, "banner": {"show": true, "fill": "#0c130d", "ink": "#d7dad1", "rule": "#7a1414"}, "badge": {"show": false}, "crowdSign": {"show": false}, "lamps": {"show": false, "count": 8}, "clock": {"show": true}, "tote": {"show": true}, "compendium": {"show": false}, "vault": {"show": false}, "lampStrip": {"max": 0, "off": "#3d3d3d"}, "plaqueTip": {"show": true}, "caption": {"show": false}}
}
```
<!-- spec-sync:themes:end -->


## 4. 2D layout (theme-independent, deterministic, sections 26–27)

Frame of reference: world units, `1.0 = maxRadius = LAYOUT.outerFrac · min(W, H)/2` px; origin = the observer (the
device, core); 2D world `(wx, wz)`, screen `sx = CX + wx·maxRadius`, `sy = CY + wz·maxRadius`. All distances in `LAYOUT`
are **CSS pixels** and are converted to world units with `/maxRadius`, so that minimum distances hold regardless of device.
`inner = clamp(LAYOUT.innerFrac·maxRadius, innerMinPx, innerPx)` (scaled, so that the core does not eat half the radius
on small viewports). `rssiT(dbm) = clamp((dbm + 90)/60, 0, 1)`, `rssiToRadius(dbm) = inner + (1 − t)·(maxRadius − inner)`
(px). **Distance = signal, not range;** direction is not measured (legend line 'geometry', D10). The rings
sit at −40/−60/−80 dBm (the device's signal thresholds) and bound four signal tiers (D9). All values in this
section live in `LAYOUT`/`AGG` (section 20):

```js
LAYOUT = {
  rssiMin: -90, rssiMax: -30, rings: [-40, -60, -80],
  innerPx: 96, innerMinPx: 64, innerFrac: 0.22, outerFrac: 0.92,
  apMinGapPx: 34, apMinGapDensePx: 22, apDenseAbove: 60, apCandidates: 16, apNudgePx: 6, groupPull: 0.15,
  clientBonusPx: 0.35, clientBonusCap: 8,
  coreRadiusPx: [4, 8],          // core radius via rssiT: star size, label eligibility (px ≥ 5), hit (px + HIT.apPad)
  basePxMaxCore: 8,              // = coreRadiusPx[1]: the layout reserves exactly the largest drawn core
  orbitTilt: 0.7,                // tilt of the 3D orbit plane (rad, §4.3/§5.1)
  clientJitterPx: 12, clientMinDistPx: 14, radialTolPx: 10, homePull: 0.05, pushFactor: 0.9,
  starZoneExtraPx: 18, coreZonePx: 10, bubbleZonePx: 4,
  settleEpsPx: 0.2, settleSyncIter: 32, settlePerFrame: 2, settleMaxIter: 600,
  orbitMinPx: 32, orbitSpreadPx: 18, orbitRankPx: 3, orbitLanes: 6, orbitMaxPx: 65, hexAbove: 8, hexBPx: 16,
  orbitSpeedBase: 0.45, orbitSpeedRefPx: 32, orbitSpeedExp: 1.5, hexSpinRadPerS: 0.08,
  skySpinRadPerS: 2 * Math.PI / 300,   // sky rotation (§4.2a): one revolution in 5 min
  forceAggAbove: 600, forceAggDensity: 0.20
};
```

`basePxMax(node) = LAYOUT.basePxMaxCore + min(node.clientCount, clientBonusCap)·clientBonusPx` for APs (8–10.8 px), `5`
for clients (maximum from §4.4); set during ingest (never `undefined` on the layout path) and the **only** size that
26–28 calculate with.

### 4.0 Identity and order (ingest, section 25)

- Identity: AP = `bssid`, client = `mac` (both normalised, §2.8). A client that appears in `aps[].clients` **and** in
  `unassociated` is created **once**: associated wins; if it appears under two APs, the first AP in the
  document wins. Duplicate BSSIDs are merged before ingest.
- Order in the layout is **never** array order: APs are sorted by `(rssi desc, bssid asc)`, clients by
  `mac asc` (`S.apOrder`, `S.clientOrder`: persistent arrays, re-sorted on every ingest). Hence
  `load(doc)` and `load({...doc, aps: doc.aps.slice().reverse()})` produce the same layout.
- `layoutDirty = true` on: ingest that changes the set, an `rssi`, an SSID or a band, an assignment (association,
  probe orbit), the probes, the vendor/randomisation of a free client or the number of free clients; resize, band filter,
  toggles `agg` and probes, `STARCHORUS.settle()`. A poll that delivers the same capture again (the device writes every 30 s,
  the page polls a few times per capture, §9.5) leaves the layout alone. The layout run is synchronous on the ingest path (only ≤ 2
  relaxation iterations run per frame, §4.2).

### 4.1 AP placement: hash base angle + group pull + golden-angle collision search (index-independent)

```
placeAPs():                                            // on layoutDirty
  list = S.apOrder (rssi desc, bssid asc) filtered to target = 1 and band filter on
  gap = list.length > LAYOUT.apDenseAbove ? apMinGapDensePx (22) : apMinGapPx (34)
  for ap in list:
    ap.a0 = hash(ap.bssid)·2π                          // base angle: depends only on the BSSID
    a0 = ap.a0
    if (ap.groupKey && S.groups.get(ap.groupKey).members.length ≥ 2)
      a0 = a0 + LAYOUT.groupPull (0.15) · wrapPi(group.meanA0 − a0)   // gentle ESSID attraction, radius unchanged
    r = rssiToRadius(ap.rssi)
    cand = []
    if (ap.angleT != null) cand.push(ap.angleT)        // hysteresis: old angle first, if still free
    for k in 0..apCandidates−1: cand.push(a0 + k·PHI_GOLD)   // 2.399963 rad → Fibonacci spiral around a0
    best = null; bestGap = −∞
    for a in cand:
      g = min over placed p: hypot(Δx, Δy) − (basePxMax(ap) + basePxMax(p))   // px, Euclidean, theme-independent
      if g ≥ gap: best = a; break
      if g > bestGap: bestGap = g; best = a
    if (bestGap < 12 && best did not come from the hysteresis):             // radial nudge (once)
      for dr in [+apNudgePx, −apNudgePx]: repeat the search with r + dr; take the first result with g ≥ gap
    ap.angleT = best; ap.radiusT = r/maxRadius; placed.push({x, y, basePxMax: basePxMax(ap)})
  // group.meanA0 = atan2(Σ sin a0_i, Σ cos a0_i) over the members (base angles, not final angles → no feedback)
```

- `meanA0` is formed in `rebuildGroups()` (before `placeAPs`) from the **base angles**; placement therefore remains a
  pure function of the set `{(bssid, rssi, ssid)}`.
- Determinism: same set → same angles; on equal RSSI, `bssid` decides. The hysteresis is merely a
  candidate with priority; because the old angle was itself a spiral candidate, a fresh run of the same set gives
  the same result (double and reverse load deliver identical `layoutInfo()` and `nodes("ap")` positions ±1e-6).
- Movement: `angle = easeAngle(angle, angleT, 3, dt)` (shortest path), `radius = ease(radius, radiusT, 2.2, dt)`. A new
  AP starts at `angleT/radiusT` with `alpha 0` (it does not visibly fly in).
- `placeAPs`, `orbitRcap`, star zones, bubble obstacles and `layoutInfo()` use `basePxMax` exclusively; `ap.basePx`
  serves hit test, label eligibility/offset and drawing.
- Metrics: `layoutInfo().apMinGapPx` (smallest core-to-core distance), `apRadiusErrPx` (max |radius −
  rssiToRadius|·maxRadius, target ≤ 6).

### 4.2 Free clients: hash angle + radius jitter + spread relaxation

Angle from the MAC hash, distance from the signal, then pushed apart – with a grid, minimum distance,
hash direction instead of randomness, exclusion zones and a radial tether.

**Home position** (deterministic, world):
```
homeAngle = hash(mac)·2π
homeR     = rssiToRadius(rssi ?? −85)/maxRadius
jitterR   = (hash(mac + "r") − 0.5)·2·clientJitterPx/maxRadius        // ±12 px: breaks up the discrete dBm rings
lx, lz    = polar(homeAngle, homeR + jitterR)                          // starting value of the relaxation
```

**Obstacles** (exclusion zones in px, grid 64 px):

| Obstacle | Radius (centre → edge kept clear) |
|---|---|
| Star without clients | `starZonePx(ap) = max(3.0·basePxMax(ap), basePxMax(ap) + starZoneExtraPx)` (glow up to 3·basePx, hidden ring up to basePx + 10, glyph/badge up to + 18) |
| Star with clients | `max(starZonePx(ap), orbitZonePx(ap))` with `orbitZonePx = orbitRcap(ap) + clientMinDistPx/2` (single orbits) or `72 + clientMinDistPx/2` (hex cluster from `hexAbove`) – free clients never lie on the paths of associated ones |
| Core | `inner − coreZonePx` |
| Bubble (§4.6) | `r + bubbleZonePx` – only for **non-members** (members are excluded from the relaxation, no circularity) |

**Relaxation** (position-based, no velocities, no `dt`, no randomness):
```
spreadStep(iters):
  D = clientMinDistPx / maxRadius; cell = 2·D
  active = free clients with target = 1, bubble = null, not randOut – in S.clientOrder (mac asc) – then the shown clouds (S.cloudOrder, §8.8a)
  for it in 1..iters:
    p0 = copy (Float32Array) of (lx, lz) of all active
    // 1) grid hashing O(n): Int32Array head[cells], next[n]; no objects
    // 2) pair repulsion in 3×3 neighbour cells, each pair once (i < j), in place, fixed order:
    for (i, j) with d = |pi − pj| < D:
      n = d < 1e-6 ? unit(hash(i.mac + j.mac)·2π) : (pj − pi)/d            // deterministic direction on coincidence
      push = (D − d)/2 · pushFactor; pi −= n·push; pj += n·push
    // 3) obstacles: if |p − o| < zone + D/2: p = o + unit(p − o)·(zone + D/2)
    // 4) radial tether: |rNow − (homeR + jitterR)|·maxRadius ≤ radialTolPx – the RSSI stays readable
    // 5) restoring pull: p += (home − p)·homePull
    if max |p − p0|·maxRadius < settleEpsPx: S.settling = false; return it
  S.settling = true
```
- **Budget:** `settleLayout()` runs synchronously on the ingest/resize/toggle path with `settleSyncIter` iterations, then per
  frame `settlePerFrame`, while `S.settling`; hard upper limit `settleMaxIter` per `layoutDirty` (after that
  `layoutInfo().settled = false`). `STARCHORUS.settle(maxIter = 600)` drives synchronously to convergence.
- **Two-phase settle with aggregation:** `settleLayout()` (all free clients) → `rebuildBubbles()` (§4.6) →
  `settleLayout()` only for non-members, with bubbles as obstacles. Members keep their layout position (for
  expanding).
- **Display position:** `wx = ease(wx, lx, 3, dt)`, `wz = ease(wz, lz, 3, dt)` (≈ 330 ms glide, snap rule §1.3); new
  clients start **at** their layout position. A relayout of a sky that is already standing (`S.relayHold`: a free client
  had already been placed, the previous relaxation had finished, same source) holds the display of the free single clients
  until the relaxation has finished; they then glide to their place once, rather than following the intermediate states from
  their home. The same applies in 3D (§5.1). Only clients present before the relayout are held (new clients follow the
  relaxation); bubble members follow their bubble; a relayout that interrupts a running relaxation does not hold (otherwise
  the display would stand still under rapid captures). Bubbles and APs are not held: a held client may stand inside a bubble
  or star zone until it glides. `STARCHORUS.settle()` additionally sets `wx/wz = lx/lz` and
  `angle/radius = angleT/radiusT` synchronously and restarts orbit phases and hex rotation, so that metrics and `nodes()`
  do not depend on the dt sequence. Free clients
  do not drift individually (that would constantly create new overlaps); movement comes from the rigid sky rotation (§4.2a).
- **Random clouds (§8.8a):** cloud members and hidden addresses are outside the relaxation; a shown cloud is inside it, with the
  home rules above on its id and mean signal (so the core keep holds it off the centre label). Members keep their homes (that is
  where an expanded cloud shows them).
- Determinism: same input (set, viewport, toggles) → bit-identical `lx/lz`; `nodes()`/`layoutInfo()`/
  `nodeScreen()` round pixel values to 1e-3 (§10). A theme change alters nothing (§3.3).

### 4.2a Sky rotation 'Sky spin' (sections 28/30)

Without association data, practically all clients on the device are free and would stand still. Individually drifting free clients
would be shoved around by star and orbit zones; so the **whole sky rotates rigidly about the observer**: APs, free
and associated clients, probe orbiters, bubbles and orbit arcs rotate about the origin at **one** angular velocity. A
rigid rotation preserves every distance – the radius of each node (= RSSI) as well as all pair, zone and
orbit distances –, so all metrics from §4.7 stay exact, the spread state stays valid and aggregation stays
event-driven (bubbles travel along, no rebuild, no flicker).

```
S.skyA += LAYOUT.skySpinRadPerS · liveDt          // one revolution in 5 min, theme-independent (section 30, stepSky)
          only when S.ui.spin && !reduceMotion && liveDt > 0      // pause, reduced motion: the sky stands still (no jump)
S.fixedTime ≠ null: S.skyA = (spin ? skySpinRadPerS · clock : 0) mod 2π   // pure function of the frozen clock
Display (section 28 only): (x, z) → (x·cos θ − z·sin θ, x·sin θ + z·cos θ), θ = S.skyA
  2D: sx = CX + (wx·cos θ − wz·sin θ)·zoom2d·maxRadius, sy = CY + (wx·sin θ + wz·cos θ)·zoom2d·maxRadius   (bubbles: cx/cz)
  3D: the target pT (§5.1) is rotated before p eases towards it
  Orbit arcs (§4.3): 2D arc angle + θ; 3D offset rotated about ap.p (skyPt)
```
- Layout truth (`lx/lz`, `angleT/radiusT`, `orbitPhase`), settle, aggregation and `layoutInfo()` remain untouched; at
  θ = 0 (`?spin=0`) the display is bit-identical to the unrotated layout.
- The grid (rings, spokes, dot lattice, ring labels) stands still: it is the observer's frame of reference;
  core and centre label stay fixed at `CX, CY`. No sweep beam, no guide line – the whole sky turns as in
  a planetarium; nothing 'scans' (R39).
- Toggle `spin` (key `S`, button 'Spin', **default on**), query `?spin=0|1`, in `PERSIST_KEYS`. In 3D the
  rotation adds to the camera auto-rotation (§5.3).
- Position comparisons over time or between separate runs use `?spin=0` or `?fixed=`; the
  `layoutInfo()` metrics are rotation-invariant.
- Cost: while rotating, `S.moving = true` (every frame renders); an empty sky stays idle (§6.8).

### 4.3 Associated clients: orbits outside all star elements

```
lane       = rank mod orbitLanes (6); rank = index in the AP's client list sorted by mac
orbitR     = orbitMinPx (32) + hash(mac + "o")·orbitSpreadPx (18) + lane·orbitRankPx (3)      // 32..65 px
orbitRcap  = clamp(0.5·distToNearestOtherAp − 4, orbitMinPx, orbitMaxPx (65))                  // from angleT/radiusT, theme-independent
orbitR     = min(orbitR, orbitRcap)
orbitPhase = hash(mac)·2π; dir = hash(mac + "d") > 0.5 ? 1 : −1                           // start only for a new orbit (see below)
orbitSpeed = dir · orbitSpeedBase · (orbitSpeedRefPx / orbitR)^orbitSpeedExp rad/s             // Kepler: faster inside
orbitTilt  = (hash(mac + "i") − 0.5)·LAYOUT.orbitTilt rad                                     // 3D only (§5.1)
phase     += orbitSpeed·liveDt;  wx = ap.wx + cos(phase)·orbitR/maxRadius;  wz = ap.wz + sin(phase)·orbitR/maxRadius
```
- 32 px lies outside the largest star zone; clients never circle inside the glow.
- A relayout leaves the phase of a lane orbit that carries on as it is (even at a different rank: that changes only the
  radius). It is set afresh only for a new orbit: a new client, a different AP, a switch between probe orbit (§8.9) and
  genuine association, or a switch of the AP from hex cluster to lanes.
- From `hexAbove` (8) clients per AP: hex cluster instead of single orbits: 7 slots at `2·hexBPx`, a further 12 at `3.25·hexBPx`,
  the rest at 72 px; slot = `rank`; overall rotation `hexSpinRadPerS` about the AP, one direction per AP
  (`hash(bssid + "d")`): phase = slot angle + direction · `ap.hexA` (the cluster's rotation since the switch to hex), so that
  a relayout puts every slot at its rotated position and the slots never cross. No client orbit takes part in the spreading
  (the path is the decluttering).
- Collision with other stars: `orbitRcap` keeps the path below half the distance to the nearest AP; if a slot still lies
  in another star's zone, the phase is shifted deterministically by `+π/orbitLanes` (at most 6 attempts).
- Distinguishability: free = core `render.clientCore` + 1-px border in `surface.base`; associated = additionally a ring in
  the star's `band.core` (D8: the band ring only on genuine association); shape per `render.clientShape` (`disc` or
  `cross`, the cross arm scales with the signal tier). Randomised MACs carry the mark `render.clientRandomizedMark`;
  tooltip 'randomised (locally administered)'.
- Orbit traces: associated get a **trailing 60° arc** (`line.hairlineSoft`), probe orbiters dashed (§8.9), free
  clients **no** arc (identical dBm values would otherwise form circle remnants). Layer 7, one path, only `S.ui.orbits`, LOD ≤ 1.

### 4.4 Visibility guarantee (size, border, alpha, order)

| Quantity | Value |
|---|---|
| Client core radius | `basePx = 3.5 + 1.5·t` (3.5–5 px; RSSI missing → t 0.25); hover +0.5 |
| Minimum drawing size | `px ≥ 3.5` in 2D, in 3D `CFG3D.minPxClient 3.5` – a client is never smaller than 7 px in diameter. Applies at LOD ≤ 1 and always for hover/locked/pinned; from LOD 2 (§6.4) single clients are drawn as a `3×3`-px rect in `render.clientCore` (batch), bubbles remain sprites |
| Border/halo | Sprite: 1-px border `surface.base` (separates from the glow) + halo or baked bloom per theme |
| Alpha | free 0.85, associated 0.95, hover/locked/pinned 1.0; in 3D × fog |
| Hit area | `max(px + HIT.clientPad, HIT.minPx)` px; touch `max(px + 10, HIT.touchMinPx)` |

Drawing order (§6.2): star **glows** → connections → orbit arcs → **clients** → bubbles → star **cores** + rings.
Clients lie above every glow and beneath the cores; a client exactly behind a core is ruled out by the star zone
(`clientsInStarZone === 0`).

### 4.5 Star size and client badge

Star size = RSSI + client bonus `+0.35 px/Client, Cap 8`; in addition the badge (§8.7) as a readable number. The bonus is
small (≤ 2.8 px) and feeds into `basePx` and hence into star zone, hit test and label offset.

### 4.6 Aggregation into density bubbles (section 27, event-driven)

```js
AGG = { cellPx: 32, minCell: (nFree) => nFree <= 200 ? 4 : 3, minCluster: (nFree) => nFree <= 200 ? 6 : 8, maxCellsPerBubble: 4,
        keepFrac: 0.75, rMinPx: 14, rMaxPx: 46, expandMs: 6000, expandAlpha: 0.35, kPos: 4, minCounterPx: 9, minCounterAlpha: 0.5 };
```
```
forced = nFree > LAYOUT.forceAggAbove || density > LAYOUT.forceAggDensity
         density = nFree·(clientMinDistPx + 2)² / (π·(maxRadius² − inner²))
rebuildBubbles():                     // only from the settle (phase 1 → 2, or when phase 1 runs out of iterations); never per frame
  // the phase-2 relaxation does NOT call it (no rebuild cycle)
  if (!S.ui.agg && !forced) { all bubbles.target = 0; all client.bubble = null; return }
  grid cellPx over (lx, lz)·maxRadius of the free clients with target = 1
  occupied = cells with count ≥ minCell(nFree), in key order (gz asc, gx asc)
  BFS over occupied (8-neighbourhood, deterministic), a cluster grows up to maxCellsPerBubble cells;
     further neighbouring cells open the next cluster (→ density map instead of a giant bubble)
  for cluster: if members.length ≥ minCluster(nFree):
     anchor = cell with maximum count (tie: smaller key); id = "b:" + gx + ":" + gz
     cx, cz = mean of the layout positions; r = clamp(8 + 4·sqrt(n), rMinPx, rMaxPx)
     existing bubble with the same id → update targets (ease k = kPos); otherwise new (alpha 0 → 1)
  Hysteresis: an existing bubble remains while members ≥ keepFrac·minCluster; below that target = 0
  then settleLayout() for non-members (bubbles as obstacle r + bubbleZonePx)
```
- **Transition single ↔ bubble** (animated): `client.bubbleBlend = ease(→ bubble ? 1 : 0, S.anim.blendK, dt)`; drawn at
  `lerp(own position, bubble centre, smoothstep(blend))`, alpha `·(1 − blend)`, size `·(1 − 0.4·blend)`; bubble alpha
  = max(blend of the members). Members with `blend ≥ 0.98` are neither drawn nor hit.
- **Appearance:** circle `render.bubbleFill` + border `render.bubbleStroke` 1 px (wireframe themes: circle + 4 ticks); the counter
  `n` is a baked text sprite (`counter`, `ink.primary`), below it 'clients' in `ink.secondary` – no `fillText`
  per frame. **Minimum legibility:** the counter appears only when the drawn radius `px` (2D: `r·zoom2d`; 3D: projected) is `≥ minCounterPx` and `alphaDraw ≥ minCounterAlpha`;
  in 3D the fog alpha for the counter is raised to `max(fog, CFG3D.bubbleFogFloor)` (§5.4).
- **Hover/click:** hit area `r + HIT.bubblePad`; tooltip '<n> clients · mean −71 dBm · top vendors · n randomised' + up
  to 8 MACs; click → detail panel (member list scrollable, vendor distribution top 5 as small bars), selection ring.
- **Expanding:** a click on a bubble **or** on a member in the list sets `expandedUntil = clock + expandMs`: the
  members are drawn individually at their layout positions, the bubble remains as an outline with `alpha·expandAlpha`;
  afterwards they condense back. `STARCHORUS.expandBubble(id)` triggers the same.
- **Toggle `#t-agg`:** off → no bubbles, except when `forced` (button stays operable, class `.forced` + `title`).
- **3D:** the bubble sits at the `p3` mean of its members; cluster formation stays in 2D layout space (stable against the
  camera).
- Stability: anchor ID from the densest cell, hysteresis, rebuild only on events, animated blend → no flicker
  at the threshold.
- **Random clouds (§8.8a):** bubbles never contain a cloud member (the cloud is the fold) or a hidden address, and a cloud is
  never a cell; every present station outside the active set has `bubble = null`.

### 4.7 Metrics `layoutInfo()` (section 26, debug path, O(n) over the grid)

```
minClientDistancePx    smallest nearest-neighbour distance over FREE single clients (target 1, not in a bubble, alphaDraw ≥ 0.5)
p5ClientDistancePx, medianClientDistancePx                       // same set
overlapsPx             pairs < 7 px among these free single clients
clientsInStarZone      free single clients within starZonePx(ap) (incl. orbit zone) of a visible star
clientsInApHalo        free single clients within 3.0·basePxMax(ap) (glow reach; subset of clientsInStarZone)
freeInOrbitZone        free single clients within orbitZonePx(ap) of a star with clientCount > 0 (target 0)
apMinGapPx, apRadiusErrPx, clusterCount (= bubbles), settled, iterations, labelsDrawn, labelCollisions
labelsOutside          drawn label boxes (core text, names, vendor lines, badges, group labels, cloud tags) that leave the sky box; 0 (§6.6)
                       counted at the end of the frame over the list of drawn labels (each box entry carries its width),
                       not inside the placement, so a label drawn without it is counted too
```
`layoutInfo()` is a function of the **layout values** (`angleT/radiusT`, `lx/lz`, `basePxMax`, viewport) and of the drawn
`sx/sy` after `settle()`, never of the faded-in sprite size. Field classes: **geometric** `minClientDistancePx,
p5ClientDistancePx, medianClientDistancePx, overlapsPx, clientsInStarZone, clientsInApHalo, freeInOrbitZone, apMinGapPx,
apRadiusErrPx, clusterCount`; **layout state** `settled, iterations`; **render/font-dependent** `labelsDrawn,
labelCollisions, labelsOutside`. Theme invariance: with a frozen clock (`setFixedTime(0)` after fade-in), running
`setTheme(x); await wait(300); settle(); frame()` per theme yields identical geometric and state fields in all three themes; only the
render/font-dependent fields may differ.

---

## 5. 3D mode 'Disc' (section 28; camera, fog and far size theme-independent)

The radar plane remains (XZ = 2D layout, distance = RSSI); the third axis **y** carries the band; 2D is the top view
of the same scene (camera preset). World unit `1.0 = maxRadius`, y up. `motion.*`/`depth.bokeh` reach this
section only via `S.anim`.

```js
CFG3D = { el: 0.42, azStart: 0, fovDeg: 50, distFactor: 0.8, distMin: 1.1, distMax: 9, elMin: -0.15, elMax: 1.45,
          yBand: { "2.4": -0.10, "5": 0, "6": 0.10, unknown: 0 }, yJitter: 0.04, freeYSpread: 0.36, freeZJitter: 0.03,
          fibonacciAbove: 60, hexY: 0.02,
          dragRadPerPx: 0.0055, wheelK: 0.0012, btnAz: 0.35, btnEl: 0.2, btnZoom: 1.25, dragThresholdPx: 4, touchThresholdPx: 10,
          kAz: 7, kEl: 7, kDist: 5, kTarget: 4, kNode: 3, kBlend: 3.5, kReduced: 40, autoRamp: 1.2, idleResumeMs: 6000,
          nearHard: 0.10, nearSoft: 0.45, farStart: 0.35, farEnd: 1.8, centerZoom: 0.55,
          fogNearAlpha: 1, fogFarAlpha: 0.33, sizeFarFactor: 0.58,   // theme-independent: drive px/alphaDraw → label eligibility and hits
          minPxClient: 3.5, minPxAp: 5, maxPxClient: 9, maxPxAp: 44, minPxBubble: 9, bubbleFogFloor: 0.5,
          plumbAlpha: 0.35, parallaxPx: 14,
          zoom2dMin: 0.5, zoom2dMax: 4, focusFrac: 0.55 };
```

### 5.1 Scene construction from the 2D layout (`p3Of(node)`)

```
AP:      p3 = [wx, yBand[band] + (hash(id + "y") − 0.5)·yJitter, wz]                 // height = band (subtle)
Assoc.:  R = orbitR/maxRadius; i = orbitTilt; φ = phase
         p3 = AP.p3 + R·[cos φ, sin φ·sin i, sin φ·cos i]                           // tilted orbital plane
         Hex cluster: slots in the plane y = AP.p3.y + hexY, overall rotation as in 2D
Free:    p3 = [lx, hFree, lz + (hash(mac + "z") − 0.5)·freeZJitter]                  // held (§4.2): wx/wz instead of lx/lz
         hFree = nFree ≤ fibonacciAbove ? (hash(mac + "h") − 0.5)·freeYSpread
                                         : (1 − 2·(k + 0.5)/nFree)·freeYSpread/2, k = rank by hash(mac)   // shell of even thickness
Bubble:  p3 = mean of the members' p3 (every rebuild)
Cloud:   p3 = [lx, (hash(id + "h") − 0.5)·freeYSpread, lz + (hash(id + "z") − 0.5)·freeZJitter]   // §8.8a; held: wx/wz
2D target: p2 = [wx, 0, wz]
Actual:  pT = spin(lerp(p2, p3, tS)) (§4.2a); p = ease(p, pT, kNode, dt) component-wise, snap < 1e-6
```
The spread result enters XZ **unchanged** (no second layout); the 3D top view matches 2D.

**Supporting cues for the third axis** (height alone is only a small offset):
1. **Legend line** in 3D: 'height = band (2.4 below · 5 mid · 6 above)' (`#leg-height`, §9.4).
2. **Plumb lines** for APs (LOD ≤ 1), bubbles and hovered/locked/pinned nodes: a hairline from `p` to the plane in
   `line.hairlineSoft` (alpha `plumbAlpha·fog·tS`), one path per frame.
3. **Ground shadow**: an ellipse in `render.shadow` at the foot point `[x, 0, z]` for APs and bubbles, only when `tS > 0.5` and
   LOD < 2.
4. **Starfield parallax**: the static `#bg` image is drawn in 3D offset by `(−sin(az)·parallaxPx, −(el − 0.42)·parallaxPx)·tS` px;
   themes without a starfield use the projected dot lattice at y = 0 instead.
5. **Rings as ellipses** (projected polylines) + spokes at y = 0.

### 5.2 Projection and camera

```
cameraBasis(): eye = target + dist·[cos el·sin az, sin el, cos el·cos az]; f = norm(target − eye)
               r = norm(cross(f, [0,1,0])); u = cross(r, f); F = (H/2)/tan(fov/2)
project(p):    d = p − eye; xc = d·r; yc = d·u; zc = d·f; if zc < nearHard → invisible
               s = F/zc; sx = CX + s·xc; sy = CY − s·yc; scale = lerp(1, dist/zc, tS)
Preset 3D:     el 0.42, az 0, dist = F3D/(distFactor·maxRadius), F3D = (H/2)/tan(25°)
Preset 2D:     el π/2 − 0.001, dist 20, F = 20·maxRadius (quasi-orthographic)
```
**Bit-identical 2D path:** at `tS = 0` (exactly, through the blend snap §5.7) **no** projection runs: `sx/sy` as in §4.2a,
`zc = 1`, `px = basePx·zoom2d`, `fog = 1`. Hit test, labels and bubbles use the same numbers; after `setView("3d")` →
`setView("2d")` the `nodes()` positions are bit-identical (`===`).

`S.cam` (§2.6): target (`azT, elT, distT, targetT`) and actual (`az, el, dist, target`). Two kinds of movement:
- **Easing** (dt-based): `az = easeAngle(az, azT, kAz, dt)`, `el = ease(…, kEl)`, `ln dist = ease(…, kDist)` (log space),
  `target = ease(…, kTarget)`. Drag writes `az/el` **and** `azT/elT` directly (no lag); wheel/buttons set only targets.
- **Tween** (click focus, reset, view change): `S.cam.tween = {t0: clock, ms, from, to, fn}` with
  `ms = S.anim.cameraEaseMs`, `fn = S.anim.cameraEasing` (reduced motion: 150 ms linear); per frame
  `u = fn(clamp((clock − t0)/ms))`, values = `lerp(from, to, u)` (angles by shortest path, dist in log space); actual **and** target
  are set; drag/wheel/keyboard abort the tween.
- Limits: `dist ∈ [distMin, distMax]`, `el ∈ [elMin, elMax]`, `az` free.

### 5.3 Auto-rotation

`az += autoRate·ramp·dt; azT = az` only when `tS > 0.5 && S.ui.rotate && !paused && !reduceMotion && tween === null` (the
rotation shifts target **and** actual, otherwise the easing would pull `az` back); `autoRate = S.anim.autoRotateRadPerS`.
`ramp = ease(ramp, 1, autoRamp, dt)`; `pointerdown`/wheel/keyboard camera → `ramp = 0`, `idleAt = clock`; after
`idleResumeMs` it starts again. `#t-rotate` off = permanently off. The camera target is **always** the observer
(`target = [0,0,0]`) – even with a locked node the scene turns about the core.

### 5.4 Depth fog, size, bokeh, bubble floors

```
fogNear = smoothstep(nearHard, nearSoft, zc)
sFar    = smoothstep(dist + farStart, dist + farEnd, zc)
fog     = fogNear · lerp(1, lerp(CFG3D.fogNearAlpha, CFG3D.fogFarAlpha, sFar), tS)
alphaDraw = alpha · fog · kindFactor (AP 1, assoc. 0.95, free 0.85, bubble 1)
px      = clamp(basePx · lerp(1, (dist/zc)·lerp(1, CFG3D.sizeFarFactor, sFar), tS), minPx, maxPx)   // minPx client 3.5 / AP 5 / bubble 9
Bubbles: alphaHud = alpha · max(fog, bubbleFogFloor); counter only when r·scale ≥ minPxBubble && alphaHud ≥ 0.5 (§4.6)
Bokeh (TD.bokehSoft = depth.bokeh.enabled): sFar > 0.5 or (2D: t < 0.25) → sprite variant "soft"; never ctx.filter. Without bokeh: variant "sharp"
```

### 5.5 Draw order and hit test

There is no depth-sorted list of nodes. Each layer (§6.2) draws its own kind of mark in a fixed order: the APs from
`S.apOrder` (rssi desc, bssid asc), the stations from `S.clientOrder` (mac asc), the bubbles and clouds from their maps. A node
that has faded out is deleted from its map in the same step (`stepNodes`: alpha < 0.02, target 0). Hit test (`nodeAt`, section 36)
in projected coordinates: in 3D the candidates are sorted by `zc` from **near to far** on each call and the first hit wins,
in 2D the nearest centre within its radius wins; hit when `(mx − sx)² + (my − sy)² ≤ max(px + pad, HIT.minPx)²` (AP 6, client 5,
bubble 4; touch min 16), only `alphaDraw ≥ 0.25`; bubble members with `blend > 0.5` cannot be hit.
One hit test per frame. Connections are drawn before all nodes in three depth buckets with the
fog alpha of the bucket mean.

### 5.6 Input (3D and 2D)

| Input | 3D (`tS ≥ 0.5`) | 2D (`tS < 0.5`) |
|---|---|---|
| Drag (pointer, `setPointerCapture`, threshold 4 px mouse / 10 px touch; once exceeded, the whole path since `pointerdown` counts) | `az −= dx·dragRadPerPx`, `el += dy·dragRadPerPx` (clamped), direct | no effect – the observer is the fixed anchor; there is no 2D pan |
| Wheel / trackpad pinch | `distT ·= exp(deltaY·wheelK)`, clamped | zoom **about the observer**, not about the cursor: `zoom2d' = clamp(zoom2d·exp(−deltaY·wheelK), 0.5, 4)` (the sky can shrink to half; the rings stay centred on the device); rings, grid and ring labels scale along (`#bg` is re-baked), core and ring origin stay at `CX, CY` |
| Two fingers | pinch → `distT`, midpoint drift → orbit | pinch → `zoom2d` |
| Buttons `#cam-*` | ⟲/⟳ `azT ∓ btnAz`, ▲/▼ `elT ± btnEl`, +/− `distT ÷/· btnZoom`, ⌂ reset tween | only +/− (`zoom2d ·/÷ btnZoom`, clamped 0.5–4) and ⌂ (reset, `zoom2d 1`); the four orbit arrows are hidden, on the desktop and on the phone; on a desktop window 620 px high or less the 2D Camera row gives way (D15, §9.8a) |
| Keyboard (§9.6) | ←/→ azimuth, ↑/↓ elevation, `+`/`−` zoom, `0` reset | `+`/`−` zoom about the observer, `0` reset |
| Click on node | `select(node)`: `locked = id`, tween **without re-targeting** (`target` stays `[0,0,0]`): `az → atan2(p.x, p.z)` (the node turns in front of the core), `dist` such that the node stays ≤ `focusFrac` of half the height below `CY`; detail panel; AP additionally pin toggle | pin toggle (AP; client additive) **and** detail panel; no centring (the rings remain the reference) |
| Click on empty space / `Esc` / ⌂ | `deselect()`: tween back, detail closes | detail closes; pins remain |
| Double click | like click, without a second pin toggle (`HIT.pinDebounceMs`, same node, `PointerEvent.timeStamp` – pure interaction time); bubbles are selected, never pinned | ditto |

Reset (`#cam-reset`, `0`, `STARCHORUS.resetCamera()`): preset of the current mode, `locked = null`, `zoom2d 1`, close the
detail. In both modes the observer always lies exactly at `CX, CY`.

### 5.7 2D ↔ 3D transition (`setView(v)`)

```
S.view.blendT = v === "3d" ? 1 : 0; blend = ease(blend, blendT, kBlend, dt); if (|blend − blendT| < 1e-3) blend = blendT   // snap → tS exactly 0/1
tS = smoothstep(0, 1, blend)   // reduced motion: k = kReduced (≈ 150 ms)
Camera:  el = lerp(π/2 − 0.001, el3D, tS); ln dist = lerp(ln 20, ln dist3D, tS); ln F = lerp(ln(20·maxRadius), ln F3D, tS)  // dolly zoom without a jump
         az = az3D·tS (back in 2D the ring labels are at the top)
Nodes:   pT = lerp(p2, p3, tS); fog/size weighted by tS (§5.4); sky rotation identical in both paths
Rings:   tS = 0 → static from #bg; tS > 0 → projected polylines on #sky (layer 2), #bg rings with alpha 1 − tS
While 0.02 < blend < 0.98: no auto-rotation, no spread step, aggregation frozen, labels only hover/pinned/locked
setView(v, {persist = true, snap = false}): snap → blend = blendT immediately (boot with ?view=)
```

### 5.8 Reduced motion (3D)

No auto-rotation, no idle resume; all camera easings with `k = kReduced`; tweens 150 ms linear; mode blend
≈ 150 ms; drag/wheel/buttons fully functional; drawing only when `dirty`. Source: `reduceMotion` (section 24).

### 5.9 LOD rules in 3D (supplementing §6.4)

1. Rects per §6.4 (from LOD 2); additionally in 3D, from LOD 1, distant single clients (`sFar > 0.7`) as `3×3` `fillRect` in the batch,
   except bubbles (always sprite) and hover/locked/pinned.
2. Connections from `nodeCount > 400` only for the hovered/locked AP; orbit arcs off from 400.
3. Labels ≤ `RENDER.maxLabels[lod][1]`; group labels ≤ `RENDER.maxGroupLabels["3d"]`; total ≤ `RENDER.maxText["3d"]` (§6.6).
4. Plumb lines only for APs at LOD ≤ 1, otherwise only hover/locked/pinned/bubbles; ground shadow off from LOD 2.
5. Projection of all nodes in one `Float32Array`.
6. Particles in 3D at the projected node, scaled by `scale`; distant nodes (`sFar > 0.5`) without particles (the bokeh sprite
   carries the softness).

---

## 6. Render pipeline per frame (sections 30–35)

```js
RENDER = { maxDpr: 2, dprSteps: [2, 1.5, 1.25, 1], hudMinDpr: 1.5, budgetMs: 16.6, lateK: 1.1, panelK: 1.25,
           blockMs: 1000, settleMs: 250, lateFrac: 0.25, okFrac: 0.05, slowBlocks: 2, upBlocks: 3,   // controller (§6.5)
           upMs: 15000, upMaxMs: 120000, failMs: 60000, capRatio: 0.85, probeGapMs: 60000, emaAlpha: 0.1,
           maxLabels: [[24, 16], [18, 12], [12, 8], [8, 6]],     // [lod] → [2d, 3d] (§6.4)
           maxText: { "2d": 30, "3d": 24 },                       // hard fillText budget per frame on #hud (§6.6)
           maxGroupLabels: { "2d": 6, "3d": 4 }, labelGridPx: 64, labelRowPx: 24, labelMarginPx: 6,
           mobile: { maxLabels: 12, dprCap: 1.5, lodBias: 1 },   // phone mode (§9.8)
           spriteTiers: [2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32], spriteCap: 128, alphaSteps: 32,
           flareMax: 2, nebulaMax: 40, persistFadeFrames: 20, dtMax: 0.05, lodRectPx: 3 };
LOD    = { l1: 250, l2: 600, l3: 1000 };            // nodeCount thresholds (APs + individually drawn clients + bubbles)
HIT    = { apPad: 6, clientPad: 5, bubblePad: 4, minPx: 12, touchMinPx: 16, pinDebounceMs: 250 };
```

### 6.1 Frame sequence (`tick`, section 30)

```
tick(t):
  if (S.fixedTime != null) { dt = 0; liveDt = 0; clock = S.fixedTime/1000; lastT = t }   // setFixedTime: time stands still (§10)
  else { dt = lastT ? clamp((t − lastT)/1000, 1/240, RENDER.dtMax) : 1/60; lastT = t
         liveDt = paused ? 0 : dt; clock += liveDt }
  budget.beginFrame(t)                                                   // §6.5 measures the rAF interval
  stepCamera(dt); stepBlend(dt)                                          // 28
  if (S.settling && !blending) spreadStep(LAYOUT.settlePerFrame)         // 26
  stepNodes(dt, liveDt)   // alpha (S.anim.fadeInK/fadeOutK), position, orbit phase (liveDt), twinkle/breathing, bubble blend, basePx, delete at alpha < 0.02 && target 0
  stepSky(liveDt); stepParticles(liveDt)
  projectAll()                                                           // 28 (2D path at tS = 0)
  animating = auto-rotation, easing, settle, blend, bubble blend, twinkle, tween, sky rotation, particles (without reduced motion),
              travelling dots, persistence decay, flicker, cursor blink
  if (S.fixedTime != null) animating = false                              // frozen: only dirty renders
  if (dirty || animating) { render(); dirty = false }
  budget.endFrame(); perf.tick(t)                                        // stats().fps counts rAF ticks
  requestAnimationFrame(tick)
```
- Pause freezes `clock` (orbits, breathing, twinkle, travelling dots, particle drift, cursor, sky rotation); fade-in/fade-out,
  layout easing and the camera run on `dt`. Paused and nothing moving → no `render()`. Under persistence, a further
  `persistFadeFrames` frames are rendered after the last moving frame (the trails fade out), then one full draw,
  then idle – no half-faded frame freezes.
- `visibilitychange` (hidden → visible): `lastT = lastBudgetT = 0` (the controller judges afresh, §6.5), clear `#sky`,
  `particlesRestartCurves()` (only nodes in `gather`/`dissolve` restart their curve; resting dust stays, no pool reset),
  `dirty = true`.
- `resize()` (debounced 100 ms): canvas size × `dpr`, `CX/CY/maxRadius/inner`, `rebuildBackground()`, `layoutDirty = true`
  (settle synchronous), sprites cleared only on a DPR change, `dirty = true`.

### 6.2 Canvases and layer order

Three canvases (§1.1): `#bg` (static, offscreen bitmap), `#sky` (scene; the only layer with persistence), `#hud`
(text/HUD, `clearRect` in layer 0), above them the CSS overlay `#crt` (costs no canvas time). Text **never** sits on
`#sky`; projected 3D grids are scene geometry and sit on `#sky`. Order in `render()`:

| # | Canvas | Function | Content / batching |
|---|---|---|---|
| 0 | `#sky` + `#hud` | `beginFrame` | `#hud`: always `clearRect`. `#sky`: `clearRect`, or with `crt.persistenceAlpha > 0 && S.ui.crt` `destination-out` with `rgba(0,0,0,P)` (the layer becomes more transparent by P, `#bg` shows through) |
| 1 | `#bg` | `drawBackground` | Offscreen bitmap, rebuilt on resize/theme/`inner`/`zoom2d`: starfield (seeded `mulberry32`, density `render.starfield.density`, relative positions → stable on resize), rings `line.ring`, spokes and dot grid (`render.grid`), ring labels in 2D; in 3D with parallax (§5.1) |
| 2 | `#sky` | `drawRings` | at `tS > 0` projected rings/spokes/dot grid and plumb lines, beneath all nodes |
| 3 | `#sky` | `drawShadows`, `drawNebula` | ground shadows (3D) and ≤ `nebulaMax` interference sprites (§8.2) |
| 4 | `#sky` | `drawConstellations` | ESSID MST edges, one path in `line.hairlineSoft`; the hover group in `line.hairline` |
| 5 | `#sky` | `drawGlows` | halo/bloom sprites per AP, `globalAlpha` quantised to 1/32 |
| 6 | `#sky` | `drawEdges` | client↔AP curves in three depth buckets, one path per bucket; travelling dots and probe arcs (§7.3) |
| 7 | `#sky` | `drawOrbits` | associated 60° arcs, probe orbits dashed; one path, only `S.ui.orbits`, LOD ≤ 1 |
| 8 | `#sky` | `drawDeviceLinks` | device connections between sibling stars (§8.8), only with `deviceLinks` |
| 9 | `#sky` | `drawClients` | sprites in `order` (far → near); LOD rects collected (`Int16Array`) → one `fillStyle`, one `fillRect` loop |
| 10 | `#sky` | `drawBubbles` | circle + outline; expanded bubbles dimmed |
| 11 | `#sky` | `drawStars` | core sprite per band shape, security rings (`drawApRings`) in paths **per style**, identity frame, selection ring and pin mark, twinkle ring |
| 12 | `#sky` | `drawRecvRing`, `drawGhosts`, `drawThreshold`, `drawChangeCues` | receive ring (WarGames), ghosts of the baseline (D19), the operator's threshold ring, change cues (D18) |
| 13 | `#sky` | `drawFlares`, `drawParticles` | ≤ 2 streak sprites; dust particles, one `fillStyle` per alpha step |
| 14 | `#hud` | `drawHud` | (no `clearRect`) labels (grid + text budget §6.6), group labels, badges, glyphs, bubble counters, core text, ring dBm in 3D, cursor |
| 15 | DOM | Overlays | `#crt` (CSS); flicker as `#sky.style.opacity = 1 − flickerAmp·noise` (≤ 2 Hz, seeded, not under reduced motion) |

With the Scope on (§9.8b) `render()` takes a shorter road after `beginFrame`: `drawScope()` draws the marks of rows 5, 9, 11, 12
and 14 on the fan (`#bg` holds the lanes, the rings and the words, rebuilt by `scopeGeom()`/`scopePlace()`), and the frame ends.
Rows 2 to 4, 6 to 8, 10 and 13 are not drawn.

### 6.3 Sprite cache (section 31)

```
key = THEME.meta.id + "|" + kind + "|" + colorKey + "|" + tier + "|" + variant
kind ∈ {glow, core, coreDiamond, coreHex, coreSquare, client, clientAssoc, clientCross, flare, nebula, phosphor, dot,
        counter (bubble count or 'clients' line), glyph (security/alarm glyph, tier = code point), devcount (device counter),
        text (core text, 3D ring dBm, cursor)}
tier ∈ RENDER.spriteTiers (px core radius) or number/code point; variant ∈ {sharp, soft}
getSprite(): Map lookup; missing → bakeSprite(): OffscreenCanvas (fallback document.createElement("canvas")), setTransform(dpr);
  radial gradient (halo), core, outline; bloom via shadowBlur ONCE at bake time.
Drawing: tier = smallest tier ≥ px (downscale only → sharp); dI(spr, sx − w/2, sy − w/2, w, w); globalAlpha quantised to 1/32.
Invalidation: theme change, DPR change. Cap spriteCap (LRU); stats().sprites / spriteBytes.
```
Hot-path rule (layers 5–14): no `createRadialGradient`, no `shadowBlur`, no `arc()` per client, no `fillText` per
bubble/glyph – only `drawImage`, `fillRect` and one `stroke()` per path group. The draw-call wrappers `dI/fR/sT/fT` (section 33:
`drawImage`, `fillRect`, `stroke`, `fillText` including the `strokeText` halo, counted once) count when `S.countCalls` is set (§10).

### 6.4 LOD levels (`nodeCount` = APs + individually drawn clients + bubbles + shown random clouds; start from the node count, controller §6.5)

| LOD | Starts at | Clients | Particles | Connections | Orbit arcs | Labels | Aggregation | Nebula |
|---|---|---|---|---|---|---|---|---|
| 0 | < 250 | sprite with halo (px ≥ 6), without halo (3 ≤ px < 6) | full | all associated | yes | 24 / 16 | toggle | ≤ 40 |
| 1 | 250–600 | as 0 | half | all | yes | 18 / 12 | toggle | ≤ 40 |
| 2 | 600–1000 | sprite only at px ≥ 4 && fog ≥ 0.5, otherwise `3×3` rect | APs only | hover/locked/pinned only | off | 12 / 8 | toggle (+ `forced`) | ≤ 20 |
| 3 | > 1000 | `3×3` rect except hover/locked/pinned; bubbles as sprites | off | hover/locked only | off | 8 / 6 | forced | hover AP only |

Column 'Labels' = `RENDER.maxLabels[lod]` (2D / 3D); all text items together are additionally subject to `RENDER.maxText`
(§6.6). `stats().lod` reports the level; `S.ui.autoLod = false` (`?autolod=0`, `setToggles({autoLod:false})`) freezes it
for measurements.

### 6.5 Frame budget controller (hysteresis, both directions)

```
Metric: the rAF interval only (not JS time: rasterisation runs after the callback); frameMs = EMA (α 0.1) for stats()/perf() only
Ladder (better → worse): [LOD+0/DPR 2] → LOD+1 → LOD+2 → LOD+3 → DPR 1.5 → DPR 1.25 → DPR 1
  S.perf.down = rungs below the starting step (only the controller changes it); lod/dprStep = starting step + down, LOD first up to 3, then DPR
Start values (regulatorStart, every capture, in both directions): LOD from nodeCount (mobile + lodBias); dprStart = min(devicePixelRatio,
  maxDpr, (nodeCount > 500 || nFreeTotal > 600) ? 1.5 : 2, nodeCount > 900 ? 1.25 : 2, mobile ? dprCap : 2), at boot as well (the
  state's dpr 1 is not a start value). A small capture after a large one returns to its starting step; down stays (capped to the ladder)
  Hysteresis of the starting step: it rises at its threshold but falls only once 1.1 × the counts are below it as well – a live feed
  hovering around 250/500/600/900/1000 nodes does not flip LOD/DPR (resize, sprites, #bg) on every poll
Block: blockMs and ≥ 8 rendered frames, starting settleMs after every change and after resume; idle frames (no render) do not count
  f = share of late frames (interval > lateMs); bMin2 = second-shortest interval of the block (a single outlier does not count)
Target and period: tgt = max(budgetMs, capMs) – never more than 60 fps demanded; lo = 25 % quantile of the last 120 intervals
  lateMs = max((m + 0.4)·lo, lateK·tgt), m = max(1, ⌊tgt/lo + 0.05⌋) vsyncs of lo: 60 Hz 23.3 ms, 120 Hz 20 ms, 144 Hz 18.3 ms, 50 Hz panel 28 ms
  lo > panelK·budgetMs (≤ 48 Hz, no plausible panel) or capMs known (period possibly a vsync multiple) or bMin2 > lateK·tgt
  (a 50 Hz panel and a 100 Hz panel at 2 vsyncs look the same; the probe tells them apart): lateMs = lateK·tgt
Degrade: f ≥ lateFrac in slowBlocks blocks → down + 1
Cap probe: slow AND bMin2 > lateK·tgt in slowBlocks blocks (multiples only: a cap of the display/browser, or our own load?) →
  one jump to the floor, one block measures. Floor bMin2 ≥ capRatio·before: a cap (30 fps power saving, 24/40/48 Hz) → capMs = bMin2,
  back to the old step (2 changes). Otherwise load: stay on the floor and climb back up; if the floor misses tgt as well, its interval
  becomes capMs (the best there is). Slow on the floor without a target frame → capMs = bMin2. At most every probeGapMs; capMs lapses
  as soon as lo < capRatio·capMs (power saving off, another display, load gone)
Improve: f ≤ okFrac in upBlocks blocks → down − 1, never beyond the starting step. The interval shows no headroom (60 Hz: 15 ms and
  1.5 ms of rasterisation both give 16.7 ms), so it is tried
No pumping: if a step up turns slow within failMs, back after one block; the next step up no earlier than upMs later,
  twice as late after each further retreat, at most upMaxMs. If a step holds for failMs, the back-off lapses; a new starting step
  (different sky size) clears it, as does a newly learnt cap (a new target: retreats against the old one say nothing about it)
autoLod off: no controller; LOD frozen, sky DPR = the capture's start value; a DPR change clears the sprites
#hud keeps dpr ≥ hudMinDpr when devicePixelRatio ≥ 2 (text stays sharp)
```
`stats().dpr`, `stats().dprStep`, `stats().lod` and `perf()` (§10) make the controller testable. Limits: judder that does not
depend on quality and yields no pure multiples drives the sky to the floor until it stops; a learnt cap remains as long as the
load holds the frames at its interval; the boundary between panel and multiple lies at panelK·budgetMs = 20.75 ms (144 Hz at
3 vsyncs, 20.8 ms, is probed, and a 48 or 50 Hz panel costs a probe in exchange; 165 Hz at 3 vsyncs, 18.2 ms, counts as a panel);
between two steps each attempt upwards costs roughly 1.3 s of late frames (after 15, 30, 60, 120 s); a different devicePixelRatio
(window dragged to another display) takes effect only with the next capture or the controller's next step change (both call
`regulatorStart()`; `resize()` does not).

### 6.6 Label grid with alternative positions and text budget (section 35)

**Text budget** (hard, per frame): `fillText` calls on `#hud` ≤ `RENDER.maxText[view]` (2D 30, 3D 24). The budget is a
rasterisation budget and belongs to the data: *text whose wording is fixed in the code is baked; text that comes from the data
is counted.* Baked (`text` sprite, one `drawImage`, no place in the budget): the core text, the dBm posts of the rings in 3D
(`LAYOUT.rings` is a fixed set; the 2D labelling sits on `#bg` anyway) and the cursor. A core text of length 0
or over `SPRITE_TEXT_MAX` (32 characters) falls back to the counted path, so that no single string produces a large
bitmap. The budget goes, in order of priority, to: locked → hover → pinned (APs and clients) → group labels
(≤ `maxGroupLabels`) → top-N APs by `rssi·alphaDraw` (N = `maxLabels[lod]`) → badges (§8.7) → vendor lines; whatever
exceeds it is dropped from the end. Bubble counters and security/alarm glyphs are sprites (`counter`, `glyph`), but still
occupy grid cells (labels move out of their way).

Grid `labelGridPx × labelRowPx` as a `Uint8Array`, zeroed each frame; width from a `measureText` cache
(`Map<font + text, width>`, invalidated on theme/SSID/vendor). Rectangle above the star; occupied → alternative below the
star, then to the right, otherwise discarded (no shifting by random amounts). **Inside the sky:** a box that would leave the sky box
(`skyBox()`: the whole viewport outside phone mode, §9.8) is moved inside, to within `labelMarginPx` (6 px) of its edge, horizontally and
vertically alike, and the same rule serves 2D and 3D, AP names, vendor lines, badges, group labels and cloud tags (the kinds that go through `place()`). The core text is fixed, and three things follow their own rules and are neither moved nor counted: the Wargames cursor block after a hovered label (it can sit about 2 px past a label that was moved to the margin), the security glyphs and the dBm posts of the 3D rings. A position that
needs no move is tried before one that does, so a star at the edge keeps a label beside it where there is room; a box wider or
taller than the room is dropped like a colliding one, and so is the label of a star (group centre, cloud) that lies off the sky, which
is never pulled to the edge. Which APs may carry a label, and in which
order, is decided by `labelCandidateList()` (theme-free): not hidden, SSID known, outside a 2D↔3D transition,
`alphaDraw > 0.6 && px ≥ 5·min(1, zoom2d)` (the bound shrinks with the stars when zoomed out in 2D; in 3D `px` is never below 5) (or locked/hover/pinned), with device links only the carrier per device; sorted locked 4 /
hover 3 / pinned 2, then `rssi·alphaDraw`. Fonts, grid, text budget and `maxLabels` then decide only **which**
candidates are drawn (`labels()` is an ordered subsequence of `STARCHORUS.labelCandidates()`). Hidden APs never
(§8.5). Text = `strokeText` in `surface.base` + `fillText` (legible over glows); capitals according to `font.transform`, the
band suffix from `ENCODING.band.suffix` in all themes. The vendor line (§8.7) counts as a rectangle of its own.

**Cursor and labels toggle.** The cursor (themes with `motion.cursorBlinkMs > 0`) sits at the locked or hovered
label (at most one per frame, hover wins); if that label was not drawn, there is no cursor. It appears as
`{ id: "__cursor__", kind: "cursor", text: "▮", sprite: true }` in `labels()`. Invariant (two-sided):
`perf().drawCalls.fillText` = number of listed text entries (`label`/`ring`/`vendor`/`badge`/`group`/`cursor`) **without**
the `sprite` flag, and the entries **with** the flag remain in the list – otherwise 'baked' could not be told apart from
'lost'. If `L` (`#t-labels`) is off, `drawHud` does not call `labelCandidateList()` at all: no
AP labels, facets, '×n', vendor lines, client badges, client vendor labels and no cursor – not even for pinned,
hovered or locked stars. `labelCandidateList()` itself stays independent of the toggle (the eligibility model).

### 6.7 Persistence with alpha compensation (layer 0)

`destination-out` with `P = crt.persistenceAlpha`: after 8 frames at P 0.25 roughly 10 % remains. A static mark with alpha
`a` would brighten to `a'/(P + (1 − P)·a')`; every `globalAlpha` on `#sky` under persistence is therefore
**compensated**: `a' = a·P/(1 − a·(1 − P))` (in `setAlpha`, section 33). Gradients inside sprites may
'bloom' slightly (an intended phosphor effect). `#t-crt` off → `clearRect` (no trail); theme change → one `clearRect`;
reduced motion: persistence stays (no motion stimulus), flicker off. In the running steady state the alpha of a
star position lies within ±12 % of the value without persistence.

### 6.8 Dirty/idle

`dirty = true` on data, hover, click, resize, toggle, theme, camera input, `STARCHORUS.frame()`. Idle (not
`animating`, not `dirty`) → no `render()`; `stats().fps` keeps counting rAF ticks, `perf()`/`measure()` report
`renderedFrames` separately (paused, Foundation, 2D → at most a handful of renders in 2 s).

---

## 7. The looks as token branches of the same pipeline (sections 31–35, 39)

### 7.0 Rendering tokens `render.*`

The group `render` extends the schema from §3.1. All colours for aggregates and ornaments are **neutral/monochrome**:
nebula, bubbles and shadows carry neither band nor status colour. The values per theme are in §3.8.

| Token | Meaning |
|---|---|
| `clientCore` | core colour of all clients |
| `clientRing` | `"band"`: associated clients carry a ring in their AP's `band.core`, free ones an outline in `surface.base` |
| `clientShape` | `disc` or `cross` (wireframe) |
| `clientRandomizedMark` | mark for randomised MACs (D8) |
| `bubbleFill`, `bubbleStroke`, `bubbleTicks` | bubble area (recessive), 1 px outline (≥ 3:1), wireframe ticks |
| `nebula` | base colour of the interference nebula, alpha from the score – **never** `band.*` or `status.*` |
| `starfield{density, color, alpha, twinkleFrac}` | starfield on `#bg` (density 0 = none) |
| `grid{spokes, dotStepPx}` | spokes and dot grid (0 = none) |
| `shadow` | ground shadow in 3D |
| `composite` | composite mode for particles/flare |
| `shapeFill` | star core filled or as wireframe |
| `probeArc` | passive probe arc of free clients (§7.3) |
| `deviceTie` | shape of the device connection (§8.8) |
| `changeCue` | style of the change cue (D18: `glowPulse`/`bloomPulse`/`tick`) |
| `phosphor`, `arrivalArcs`, `recvRing`, `coreMark`, `coreBeat`, `newPlotMark` | the theme branches from §7.1a |

Rules: an area may be < 3:1 (wash), a 1 px outline or a line needs ≥ 3:1, text ≥ 4.5:1. Every number that states a
condition (alarm counter, security counter, bubble counter) carries a **text token** (`ink.primary/secondary`) and
beside it a swatch/glyph in the status colour – never numbers in status or data colour. The measured values are in §7.0a.

### 7.0a Contrast table (WCAG 2.x, machine-generated from the code; all three themes)

Every row of `CONTRAST_PAIRS` with its ratio per theme (`STARCHORUS.contrast(undefined, id)`); a '✗' after a
value would be a breach of the target. Text ≥ 4.5 : 1, reference rings and marks ≥ 3 : 1 (regression run `tools/regress.d/contrast.sh`). Generated and
checked as in §3.8 (`tools/spec-sync.py --check`); what is deliberately left out of the list is named in §14.4.

<!-- spec-sync:contrast:begin -->
| Foreground | Background | Minimum | Use | Foundation | WarGames | Whitehall |
|---|---|---|---|---|---|---|
| `ink.primary` | `surface.base` | ≥ 4.5 | canvas: hovered/locked label, cursor | 16.27 | 16.72 | 13.66 |
| `ink.secondary` | `surface.base` | ≥ 4.5 | canvas: AP/centre/vendor label, client badge, device ×n | 8.34 | 8.73 | 7.11 |
| `ink.muted` | `surface.base` | ≥ 4.5 | canvas: 3D ring dBm label, group label, '?' glyph | 4.83 | 5.32 | 5.10 |
| `ink.muted` | `ground` | ≥ 4.5 | canvas: 2D ring dBm label (baked on #bg, no halo) | 4.51 | 5.32 | 4.86 |
| `status.ringNeutral` | `surface.base` | ≥ 4.5 | canvas: OWE glyph; WPA/WPA2/OWE ring | 8.34 | 8.73 | 7.11 |
| `status.ringStrong` | `surface.base` | ≥ 4.5 | canvas: WPA3 glyph; WPA3 ring | 16.27 | 16.72 | 13.66 |
| `status.alarm` | `surface.base` | ≥ 4.5 | canvas: alarm glyph; WEP ring | 10.80 | 6.00 | 4.94 |
| `ink.primary` | `render.bubbleFill` | ≥ 4.5 | canvas: bubble count | 13.75 | 16.72 | 13.66 |
| `ink.secondary` | `render.bubbleFill` | ≥ 4.5 | canvas: bubble caption | 7.05 | 8.73 | 7.11 |
| `ink.primary` | `surface.panelFill` | ≥ 4.5 | DOM: panel text | 15.96 | 16.72 | 13.78 |
| `ink.secondary` | `surface.panelFill` | ≥ 4.5 | DOM: labels, desc, legend counts; chanbar peak; sparkline value | 8.19 | 8.73 | 7.17 |
| `ink.muted` | `surface.panelFill` | ≥ 4.5 | DOM: notes, motto, #leg-rx, #src-center; chanbar/sparkline axis | 4.74 | 5.32 | 5.14 |
| `status.glyphInk` | `surface.panelFill` | ≥ 4.5 | DOM: legend glyph base colour (.legrow .glyph) | 8.19 | 8.73 | 7.17 |
| `status.alarm` | `surface.panelFill` | ≥ 4.5 | DOM: legend alarm glyph, paste error | 10.59 | 6.00 | 4.98 |
| `status.ringNeutral` | `surface.panelFill` | ≥ 4.5 | DOM: legend OWE glyph (neutral tone) | 8.19 | 8.73 | 7.17 |
| `status.ringStrong` | `surface.panelFill` | ≥ 4.5 | DOM: legend WPA3 glyph (strong tone) | 15.96 | 16.72 | 13.78 |
| `ink.secondary` | `['line.hairlineSoft', 'surface.panelFill']` | ≥ 4.5 | DOM: .btn / .filebtn label | 6.90 | 7.55 | 6.37 |
| `ink.primary` | `['line.hairlineSoft', 'surface.panelFill']` | ≥ 4.5 | DOM: .btn hover, live mode chip | 13.46 | 14.45 | 12.24 |
| `accent.selection` | `['accent.selectionWash', 'surface.panelFill']` | ≥ 4.5 | DOM: demo mode chip | 12.20 | 14.28 | 13.37 |
| `line.ring` | `surface.base` | ≥ 3 | canvas: RSSI reference ring (2D #bg, 3D #sky) | 3.17 | 4.05 | 3.21 |
| `line.ring` | `ground` | ≥ 3 | canvas: RSSI reference ring over the page gradient | 3.19 | 4.05 | 3.22 |
| `status.hidden` | `surface.base` | ≥ 3 | canvas: hidden-SSID ring | 4.83 | 5.32 | 5.10 |
| `status.alert` | `surface.base` | ≥ 3 | canvas: alert ring | 5.15 | 5.94 | 4.94 |
| `render.bubbleStroke` | `surface.base` | ≥ 3 | canvas: bubble outline | 7.89 | 8.73 | 5.10 |
| `accent.selection` | `surface.base` | ≥ 3 | canvas: selection ring | 15.88 | 16.72 | 17.64 |
| `render.btMark` | `surface.base` | ≥ 3 | canvas: Bluetooth mark | 7.18 | 8.05 | 3.94 |
| `accent.focusRing` | `surface.panelFill` | ≥ 3 | DOM: keyboard focus outline | 15.58 | 16.72 | 17.78 |
| `ink.onFill` | `ink.primary` | ≥ 4.5 | DOM: active-scan chip | 16.27 | 16.72 | 13.66 |
| `accent.toggleInk` | `accent.toggleOn` | ≥ 4.5 | DOM: .btn.toggle.on label (D12) | 15.88 | 5.19 | 13.66 |
| `chrome.banner.ink` | `chrome.banner.fill` | ≥ 4.5 | DOM: classbar text (D12) | 15.88 | 16.72 | 13.31 |
| `chrome.ink` | `surface.base` | ≥ 4.5 | DOM: #dtg, .cursor, #intro, live chip (D12) | 15.88 | 16.72 | 13.66 |
<!-- spec-sync:contrast:end -->

### 7.1 Branch table (token → function; everything else is shared)

| Function (section) | Token / condition | Foundation | WarGames | Whitehall |
|---|---|---|---|---|
| `beginFrame` (33) | `crt.persistenceAlpha > 0 && S.ui.crt` | `clearRect` | `destination-out` @ 0.25 + alpha compensation | `clearRect` |
| `rebuildBackground` (34) | `render.starfield`, `render.grid`, `surface.gradient` | starfield + rings | rings + 8 spokes + dot grid, no starfield | rings + 12 spokes + dot grid |
| Glow sprite (31) | `glow.mode/color`, `rssi.glowRadiusFactor/glowAlpha` | mono halo in `glow.color` | no glow sprite, bloom in the core | no glow sprite |
| Core sprite (31) | `render.shapeFill`, `rssi.bloomPx`, `band.*.core` | filled shape | wireframe 1 px, bloom baked in | wireframe |
| Client sprite (31) | `render.clientShape/clientCore/clientRing`, `depth.bokeh` | disc; `soft` variant | '+'; `sharp` only | '+'; `sharp` only |
| `drawEdges` (34) | `line.edge.style/curvature/color`, `motion.edgeTravelDot*`, `render.probeArc` | quadratic Bézier | parabola (control point always towards the top of the screen), travelling dots, probe arcs | Bézier |
| `drawParticles` (32) | `particles.perNode[1] > 0` | dust cloud | nothing (pool 0) | nothing (pool 0) |
| `drawFlares` (34) | `depth.lensFlare.enabled` | ≤ 2 streaks with hysteresis | nothing | nothing |
| `drawShadows` (34) | `render.shadow` | ground shadow 3D | transparent | transparent |
| `drawBubbles` (34) | `render.bubbleFill/Stroke`, `render.bubbleTicks` | filled circle + outline | wireframe circle + ticks | per token |
| `drawHud` (35) | `font.transform/letterSpacing/ui`, `motion.cursorBlinkMs` | mixed case | mono, capitals, `▮` cursor at the hovered/locked label | capitals |
| Alarm glyph (35) | `status.alarm`, `motion.cursorBlinkMs > 0` | static | blinks in time with the cursor, static under reduced motion | static |
| Fade-in/fade-out (30 via `S.anim`) | `motion.fadeInMs/fadeOutMs` | 900 / 1400 ms | 250 / 400 ms | 300 / 500 ms |
| Breathing/twinkle (30 via `S.anim`) | `motion.breathePeriodMs > 0`, `rssi.bloomPx` | glow ×(1 ± 0.06) | no breathing; twinkle = bloom pulse | no breathing |
| Camera tween (28 via `S.anim`) | `motion.cameraEaseMs/cameraEasing` | 1200 ms easeInOutCubic | 600 ms easeOutQuad | 800 ms easeOutQuad |
| Auto-rotation (28 via `S.anim`) | `motion.autoRotateRadPerS` | 0.05 | 0.12 | 0.06 |
| Bokeh (34 via `TD.bokehSoft`) | `depth.bokeh.enabled` | soft | sharp | sharp |
| Travelling dots (30 via `S.anim`), cursor (`TD.cursorBlink`) | `motion.edgeTravelDotSpeed/cursorBlinkMs` | 0 / 0 | 0.35 / 530 | 0 / 0 |
| CSS chrome (02–09) | `chrome.*`, `crt.userToggle`, variables | glass panels, blur | black panels, corner brackets, `#crt` | flat panels, banner |
| Intro (39) | `motion.introStyle` | `coalesce` | `typed` | `typed` |
| Legend (37) | `ENCODING` + `band/status/render` | filled shapes | wireframe swatches | wireframe swatches |

### 7.1a The theme branches of the analysis and chrome functions (token → function)

| Function (section) | Token / condition | Foundation | WarGames | Whitehall |
|---|---|---|---|---|
| Star freshness (34) | `render.phosphor` | off | afterglow by freshness level (soft bloom blit) | off |
| Dust (32) | `particles.cohesion`, `particles.spiral` | radius and alpha by freshness (`cohesion`), dawn/dusk rotation (`spiral`) | neutral (pool 0) | neutral (pool 0) |
| Arrival (34) | `render.arrivalArcs`, `render.recvRing` | off | arc only for new stations; shrinking receive ring | off |
| Core (31/34) | `render.coreMark`, `render.coreBeat` | `sun`, heartbeat | `reticle` | `ownship` |
| New plot (34) | `render.newPlotMark` | off | off | dashed ring for 3 captures |
| Ring strokes (34) | theme-free | **one** `stroke()` per (colour, width, dash, alpha) | ditto | ditto |
| Masthead (37) | `chrome.badge`, `chrome.lamps`, `chrome.clock` | — | source badge, 8 capture lamps (binary counter) | sector clock (hand from `generated`) |
| Legend (37) | `chrome.tote` | — | — | 'Plot freshness': four lamps T0–T3 per band |
| Air drawer (37) | `chrome.crowdSign`, `chrome.compendium`, `chrome.vault` | Compendium + Vault | crowding sign | — |
| Lamp strip (37) | `chrome.lampStrip{max, off}`, `copy.lampStrip` | off (`max 0`) | one 6×6 lamp per AP, by channel then BSSID, capped; lit at freshness T0; **the lit colour is `band.*.core`, read at draw time**, the token holds only the dark slot (D12) | off |
| Plaque tooltip (05/21) | `chrome.plaqueTip.show` → `:root[data-plaque]` | off | off | the same lines, side by side in pairs; not one field more, not one fewer |
| Caption (38) | `chrome.caption.show`, `copy.caption` | `center.label` · `generated` as `HH:MM UTC`, briefly on a theme/view change; the place is a data string and is never rewritten (D16); no capture time, no caption | off | off |
| Lit dust (32) | `particles.lit`, `particles.shade`, `render.composite` | warm dust on the facing side, shadow on the far side (`particles.shade`), `source-over` | off | off |
| Small capitals (02/21) | `font.headingVariant` → `--heading-variant` | `small-caps` (with `font.transform: none`) | `normal` | `normal` |
| Banner (39) | `chrome.banner`, `copy.bannerTop/bannerBot` | off | off | exercise banner (every line ends with 'NOT A GOVERNMENT SYSTEM') |
| Logon (39) | `motion.introStyle`, `motion.logonCharMs`, `copy.logon*` | `coalesce`: no overlay, the dust condenses | typed, jitter 28–58 ms per character | teleprinter: `STARTEX`, constant 37.5 ms per character |

### 7.2 Foundation

**Dust particles** (section 32). Pool `Float32Array(maxTotal·8)` + free list. Per AP `count = round(lerp(perNode[0],
perNode[1], t))`, clients 0 (except hover/locked, a brief flare-up); global cap `particles.maxTotal` (distributed
proportionally). Gaussian distribution around the core (`σ = sigmaFactor·spread`, `spread = spreadFactor·basePx`, Box-Muller from
`mulberry32(hashInt(id))` → deterministic cloud per node). Own motion from phase and `clock` (no randomness per frame).
Size and alpha from `particles.sizePx/alpha` in pre-quantised steps, `fillRect` per particle. Lifetime
`particles.lifeMs` with respawn in the same seed slot. Freshness and light shape the cloud (`cohesion`, `spiral`, `lit`,
`shade`, §7.1a).

Choreography (§0):
```
gather   (gatherMs, appearing):      u = easeOutCubic(min(1, (clock − pT0)/gatherS))
   pos = home + (home − core)·3.0·(1 − u); particleAlpha ·= u; coreAlpha = u²     // the core brightens out of the cloud
dissolve (dissolveMs, disappearing): u = easeInCubic(min(1, (clock − pT0)/dissolveS))
   pos = home + (home − core)·2.5·u; particleAlpha ·= 1 − u; coreAlpha = 1 − smoothstep(0.4, 1, u)   // the core goes last
idle: drift + breathing
Bubble transition (§4.6): members use gather with target = bubble centre
Reduced motion: no drift, gather/dissolve as a short alpha transition without any change of position
```
Section 32 reads `THEME.particles` directly (permitted: 32 lies outside 22–30).

**Reset only on a change of source.** `loadData()` calls `particlesReset()` only when `setSource()` reports a change
(source kind · arrival route · label · `doc.source`) or the load comes from paste/drop – every pasted or dropped file
is a new recording (D2). A poll of the same `starchorus.json` keeps the dust: new BSSIDs run `gather`,
vanished ones `dissolve`, all others stay `idle`. A deleted node returns its block at once; the free list
merges neighbouring blocks and lowers the bump pointer, so that no fragmentation arises. If the LOD level of the
particle count changes, the pool is refilled once; `applyTheme` resets on a genuine change.
`_internals.particles.pooled` (only with `?debug=1`) gives the occupied pool slots and, without a leak, equals `count`.

**Lens flare** (`depth.lensFlare.maxStars`, `RENDER.flareMax`): candidates = visible APs by `rssi·alphaDraw`;
**hysteresis 3 dB**: a candidate without a flare displaces the **weakest current carrier** if and only if it is ≥ 3 dB
brighter; changes as a cross-fade via `node.flare` (`stats().flares` counts `flare > 0.5`). Without history the two
brightest carry one. Sprite `flare`: horizontal streak (`lengthFactor·basePx`) in `accent.flare`, plus a faint vertical one;
in 3D only at `fog > 0.6`. Reduced motion: static.

**Bokeh:** `soft` sprite variant at `t < 0.25` (2D) or `sFar > 0.5` (3D): soft halo (`depth.bokeh.farSoftness`),
dimmed core; never `ctx.filter`.

**RSSI monochrome:** the core colour is `band.core` at constant opacity; the magnitude lies only in core radius,
glow radius/alpha and particle count. Only the band and the alarm (gold) carry colour; the selection is the brightest neutral, and
the shape tells them apart.

**Connections:** `quadraticCurveTo` with control point `mid + n̂·curvature·|chord|·side` (`side` from the edge hash,
constant per edge) in `line.edge.color`; constellations less curved, in `line.hairlineSoft`. No `shadowBlur`.

### 7.3 WarGames and the typed logons

**Line art/wireframe:** star core as an outline (circle/diamond/hexagon/square) in `band.core`, stroke alpha via the signal,
centre point; clients as '+'; all hairlines on half pixels; situation-wall ground = rings in `line.ring` + 8 spokes +
dot grid in `line.hairline`, **no** starfield, no gradient.

**Phosphor bloom:** `shadowBlur = lerp(bloomPx[0], bloomPx[1], t)` (cap `glow.maxBlurPx`) **baked** into the sprites.
No live `shadowBlur` in the frame path: it is set only while a sprite is baked (§6.3), never on paths with many segments (rings, arcs).

**Persistence:** §6.7. **Scanlines + vignette:** CSS `#crt` (§1.1); the toggle `#t-crt` (visible only with `crt.userToggle`)
switches scanlines, vignette **and** persistence; `?crt=0|1`. Flicker ±`crt.flickerAmp` as `#sky.style.opacity`
(≤ 2 Hz, seeded), 0 under reduced motion.

**Type/cursor:** `font.mono`, capitals, wide letter-spacing; cursor block `▮` (CSS `steps(1)`, `motion.cursorBlinkMs`)
in the masthead and on `#hud` at the hovered/locked label. Reduced motion: the cursor stands still.

**Parabolic arcs with travelling dot:** client↔AP curve `quadraticCurveTo(mid.x, mid.y − curvature·|chord|)` (control point always
towards the top of the screen); travelling dot `u = frac(clock·edgeTravelDotSpeed + hash(edgeId))` on the curve, direction AP → client
(beacon metaphor), neutral colour (D17), all dots in one path; at LOD > 1 only the edges of the hovered/locked AP.

**Passive substitute without association data** (`clients[]` empty → no edges): the signature element must be visible even with
100 % free clients, without suggesting active behaviour. `render.probeArc`:
- **Appearance** of a free client: a one-off **probe arc client → core** (parabola as above, fading out, travelling dot
  from the client to the centre = 'we heard its probe request'); capped at 12 simultaneous arcs, and for larger
  ingest bursts only the strongest.
- **Hover/locked** on a free client or a bubble: a persistent probe arc for as long as the hover/lock lasts.
- Legend line 'arc = heard probe (rx only)' (`copy.rx.legArc`). Reduced motion: arcs static, without a travelling dot.

**Alarm** in `status.alarm` (D6): open and WEP carry the same mark – a ring with a 60° gap at NE, with the '!' there; an
area only as ornament (`status.alarmAura`). Red never as an area, never for nebula, bubbles or interference. The shape carries
the meaning (red↔green cannot be told apart under deuteranopia). Alarm counter `#n-alarm`: number in `ink.primary`, preceded by
a swatch in `status.alarm`.

**Intro** (section 39; `runIntro()` branches on `motion.introStyle`; not under reduced motion, not with `?intro=0`, only
at theme start = boot or switch, **once per session and per theme ID** via `sessionStorage`
`starchorus.introShown.<theme>` in try/catch, D13). `typed` types the lines below; `coalesce` shows no overlay but
lets the dust of the real capture converge from twice the distance, aborts on a click or key and does not run while
time is frozen; `none` does nothing.
```
Lines = copy.logonHead + [copy.logonMode[sourceKind]] + [copy.logonListen, if set] + copy.logonTail
WarGames/Foundation voice:  "STARCHORUS  ·  OBSERVATION TERMINAL" / "LOGON: OBSERVER" / mode line / "…LOADING SKY"
Mode line:   demo "MODE: RX ONLY — NOTHING IS TRANSMITTED · SAMPLE SKY" | live "… · LIVE FEED" | recorded "… · RECORDED CAPTURE" |
             none "… · NO FEED" | active "MODE: ACTIVE SCAN · THE COLLECTOR SENT PROBE REQUESTS"
Whitehall:   "STARTEX" / "STARCHORUS - PLOTTING TERMINAL" / "CONNECTING TO FEED..." / mode line /
             "EXERCISE - NOT A GOVERNMENT SYSTEM" / "...PLOTTING"
Rhythm: motion.logonCharMs per character (WarGames/Foundation voice 28–58 ms seeded, Whitehall constant 37.5 ms).
Timing (D13): the overlay appears at once; typing starts from the first completed poll (success, 404 or network error →
releaseLogon()), after 1 s at the latest. Each line is computed when its typing begins and then frozen, so that the mode line
names the source that the first poll delivered.
Skip: click/tap/key/"SKIP ▮"/STARCHORUS.skipIntro() → skipLogon() FIRST writes the complete text of all lines into
#intro-text, then class .out, then display:none. The sky keeps running behind it (poll, ingest, layout, render) – a pure
overlay. After the logon, renderSourceTruth() keeps the hidden #intro-text current.
```
Section 39 contains no theme ID check; the call goes via `THEME.motion.introStyle`, the voice via `THEME.copy`.
`grep -c "MODE: RX ONLY — NOTHING IS TRANSMITTED"` = 1 (the one constant `COPY_RX_MODE`). The classification bar
(`#classbar-top/-bot`, only with `chrome.banner.show`) is `bannerLines()` = `[copy.bannerTop, copy.bannerBot[sourceKind]]`.

---

## 8. Analysis functions (all passive, display only; sections 29, 35, 37)

### 8.1 RSSI sparkline per AP + twinkle

Data source §2.4 (ring buffer of 60 samples, `−128` = gap, dedup via `generated`, survives the node's exit). Drawn according to
`chart.*`: line 2 px in the AP's `band.core`, area wash, y fixed at −100…−20 dBm, gridlines, end-point marker, end label
'−48 dBm' in `ink.secondary`, tick text in `ink.muted` (tabular). Places: **Tooltip** `canvas#tip-spark` 120×28 (no axis,
only from 3 samples onwards) and **Detail** `canvas#detail-spark` 240×64 (with axis, crosshair snaps to samples, table twin
min/max/last/samples). **Keyboard:** `canvas#detail-spark` is focusable (`tabindex="0"`, `aria-label="Signal
history"`, focus ring `accent.focusRing`); when it has focus, `←/→` move the crosshair (`aria-live` text '−48 dBm · 12 s ago'),
`Home/End` jump to the ends, `Esc` releases focus – the tooltip is never the only way. Both canvases are
**persistent in the DOM** (no `createElement` per hover; drawn only on a hover change or `sparkDirty`). On refetch
the curve stays in place at `chart.refetchHoldAlpha`, no skeleton. **Twinkle** at `|Δ| ≥ 3 dB` between two polls: a
brief glow or bloom pulse and an expanding 1 px ring; no additional text marker. `stats().twinkles`.

### 8.2 Channel occupancy, overlap, interference nebula (section 29, theme-free)

```
freqFromChannel(ch, band): 2.4 → 2407 + 5·ch (ch 14 → 2484); 5 → 5000 + 5·ch; 6 → 5950 + 5·ch (ch 2 → 5935)
channelSpan(ap):  w = ap.width ?? 20; f = ap.freq ?? freqFromChannel(ap.channel, ap.band); [f − w/2, f + w/2, w, assumed: ap.width == null]
overlapScore(a, b): same band, both channels known; ov = max(0, min(a.hi, b.hi) − max(a.lo, b.lo)) / min(wa, wb)
                  co = |fa − fb| < 2.5 MHz; adj = ov > 0 && !co
                  I = ov · min(t_a, t_b) · (co ? 1.0 : 0.7)          // both strong at the observer → strongest interaction
rebuildInterference(): per band all pairs (only on ingest/filter); per AP the top-6 partners with I ≥ 0.15;
                  global list top RENDER.nebulaMax by I → nebula layer; stats().interferencePairs
rebuildChannelStats(): per band map channel → {count, aps[], widthMax, assumed}
```
**The 20 MHz assumption is visible** (without `width`, `assumed` is true for all APs and adjacent-channel overlap on 5/6 GHz
practically never occurs): (1) legend row 'channel overlap (derived, width unknown → 20 MHz)'; (2) channel-bar tooltip
'width 20 MHz (assumed)'; (3) AP tooltip/detail 'Overlaps: … (co-channel, ch 6) · … (adjacent, ch 8 · 40 MHz)' with the
addition 'derived, width unknown → 20 MHz' when `assumed`; (4) `title` of the channel bar 'APs per channel · widths assumed
20 MHz where unknown'.

**Nebula** (layer 3): ellipse sprite `nebula` in `render.nebula`, stretched along the connection (rotation via
`setTransform`, ≤ `nebulaMax` calls), alpha proportional to `I`; in 3D between the projected points. **Neutral:** never
`band.*`, never `status.*` (interference is not an alarm). Toggle `#t-nebula` (`N`); LOD ≤ 1 up to 40 pairs, LOD 2 up to 20,
LOD 3 only the hovered AP.

**Channel bar** `#chanbar` (section 37, following `chart.*`): three small multiples 2.4 | 5 | 6 with a shared y axis (APs per
channel), bars ≤ `chart.barMaxPx` in `band.core`, the occupancy of wide channels as a wash beneath the channels they cover, only the
tallest bar per segment labelled; deviation marks from D11 as a dashed cap; hover → `#chan-tip`
(`textContent`: channel, band, count, width, overlaps, SSID list); clicking a bar briefly pins the APs of that
channel. The band filter acts on the sky **and** the bar; APs without a band do not appear in the bar. `#t-chan` (`Y`) switches
Bars → Spectrum → Waterfall (§8.13). Redrawn only on ingest/filter/theme/resize/hover.

### 8.3 Network details in the detail panel (consistent table)

Rows (missing → '—'; all values via `textContent`): SSID / '(hidden SSID)' · BSSID · Vendor · Band · Channel · Frequency ·
Width (missing → '— (20 MHz assumed for overlap)') · PHY (`phy` raw; otherwise an estimate prefixed '≈ ' with the note that the
collector reports no PHY) · Max rate · Caps · Security (raw + class from `ENCODING`, plus AKM/cipher/auth if supplied) ·
PMF (derived, below) · Clients · Signal + sparkline + min/max/last · Last seen (`fmtAge` relative to `generated`; outside
[generated − 86400, generated + 60] the raw value) · Freshness (D1) · Overlaps (§8.2) · Group/device (§8.6, §8.8) ·
Change log (§8.11) · Identity, alias, notes (§8.10, §8.12).

```
phyEstimate(ap): if ap.phy → ap.phy (without ≈); r = ap.rate; if r == null → "—"
  2.4 GHz:  r ≤ 11 → "≈ b"; r ≤ 54 → "≈ g"; r ≤ 600 → "≈ n"; r ≤ 1147 → "≈ ax"; else "≈ be"
  5 GHz:    r ≤ 54 → "≈ a"; r ≤ 600 → "≈ n"; r < 866 → "≈ ac"; r ≤ 3467 → "≈ ac/ax"; else "≈ ax/be"
  6 GHz:    r ≤ 2402 → "≈ ax"; else "≈ be"                     // 6 GHz starts with Wi-Fi 6E → at least ax
  unknown:  r ≤ 54 → "≈ legacy"; else "≈ n+"
```
This one table applies to the tooltip, the detail and `STARCHORUS.node(id).phyEstimate`. Examples: `rate 866, band 5` → '≈ ac/ax';
`rate 300, band 2.4` → '≈ n'; `phy "g/n"` → 'g/n'.

**PMF** (detail panel only: no legend row, no counter, nothing in the Overview). `pmfDerived(ap)` reads 'yes (derived)' for the classes
in which the standard guarantees Protected Management Frames (802.11w): pure WPA3 (`sec` `wpa3`, so neither the WPA2/WPA3 transition nor
enterprise), OWE (`owe`) and a 6 GHz network, the band taken from the `band`/`freq` fields alone (`bandF`: a channel number above 177
puts a node on 6 GHz for the layout, but never for this row); every other network reads 'unknown', never 'no', because the beacon's own
capability flags are not read. The value is marked derived like the PHY estimate (class `.est`, with a `title`). PMF is spelt out once, as
'Protected Management Frames', in a line under the key list of the help (`?`), because a `title` shows on no phone; the line stays within two
lines at 1440x900 and 375x812 in every theme (a row in `collector-fields.sh` counts them). Also `STARCHORUS.node(id).pmf` (§10).

### 8.4 Security overview

Encoding from `ENCODING.security` (ring form + glyph as a `glyph` sprite; colour only for the alarm). `securityCounts()` (on
ingest/filter) → legend: per class a ring swatch + glyph + label + count; a class without an AP has no row. Stats:
`#n-alarm` (only > 0): alarm swatch + number in `ink.primary` + label 'open/wep'. The tooltip shows the raw string + class.
`stats().security` counts per class of `ENCODING.security`, `stats().alarms` the open and WEP networks.

### 8.5 Hidden SSIDs and reveal

`hidden = ssid === ""`: no label, outer dashed ring `[4,4]` at `basePx + 10` in `status.hidden`, tooltip
'(hidden SSID)'. If a later ingest supplies a name for the same BSSID: `ssidKnown = ssid`, `revealAt = clock`,
`hidden = false`; the label is drawn from the next frame and the hidden ring is no longer drawn, with no fade of its own (the node's own fade-in is the only one), and the detail says 'name revealed 12 s ago'.
**Memory:** if an even later poll returns `""` again, `ssidKnown` remains as the label (italic, `title="last seen name"`).
`stats().revealed`. The group key uses `ssidKnown ?? ssid`. A hidden network shows no name: on the device measured on 17 October 2026 every hidden beacon row holds zero bytes only and no row of any type holds a name for a hidden BSSID (device-notes §4a), so the collector blanks the name of a hidden row, as it has done since the first release, and there is no field for one.

### 8.6 ESSID/roaming constellations

Groups §2.3 (`rebuildGroups()` before `placeAPs()`, supplies `meanA0` for the angular pull §4.1). Edges: **MST** (Prim, up to 24
members; beyond that a star topology to the hub) over 2D layout distances; layer 4 in `line.hairlineSoft`; group label at the
centroid only with ≥ 3 members or on hover over a member; member labels carry the band suffix. Hover highlights all
edges of the group and shows 'Roaming set: 3 BSSIDs · 2.4/5/5'. Toggle `#t-groups` (`G`). Positions: only the gentle
angular pull (the radius = RSSI remains the truth). `#n-groups` and `stats().groups` count groups with ≥ 2 members.

### 8.7 Client count per AP and vendor on the label

Badge to the SE of the star: `clientCount` (only > 0), 9 px `ink.secondary` on a small plate in `surface.base`; only at `px ≥ 5`,
in 3D with fog alpha, not at LOD 3; in the label grid as a rectangle of its own; subject to the text budget §6.6 (priority after
the AP labels). **Vendor on the label** (`#t-vendor`, `S.ui.vendor`, persisted): second line in `ink.secondary` below the
SSID label for **APs** and for **pinned/hovered/locked clients** ('3c:22:fb:…:a1 · Apple'; randomised →
'randomised'); the bubble counter gets the top vendor as a second line. On collision only the vendor line is dropped.

### 8.8 Logical AP grouping

Purely **client-side** derivation from existing fields (`bssid`, `ssid`, `band`, `vendor`) – without any change to the collector and
without new JSON fields. Passive (display only), **theme-free** and **deterministic** (union-find, no randomness; identical
input → identical `STARCHORUS.devices()`/`essClusters()`). Configuration
`DEVICE = { mbssidBits: 3, seqWindow: 4, radioWindow: 16, seqTight: 2, essExpandMs: 6000 }` (section 20). Built in
section 29 (`rebuildDevices()`, `rebuildEss()`) on every ingest, idempotent; first G1 (device identity), then G2 over
the device nodes.

**G1 – Device grouping (several BSSIDs/radios → one physical device).** APs only; locally administered BSSIDs
(U/L bit) are excluded from the OUI logic. The same **OUI** is mandatory, bytes 0–4 identical.
- **Consecutive BSSIDs (strongest signal, across bands):** `|Δ(Byte5)| ≤ DEVICE.seqTight` → one device **without**
  an SSID/vendor gate and across bands. Reason 'consecutive BSSID'. Takes precedence over the two following rules.
- **Multi-BSSID (one radio):** same band, byte 5 differs only in the low `mbssidBits` **or**
  `|Δ(Byte5)| ≤ DEVICE.seqWindow`.
- **Multi-radio (one box, different bands):** different known band, `|Δ(Byte5)| ≤ DEVICE.radioWindow` **and**
  (the SSID base matches after stripping the band markers `/[-_ ]?(2\.?4|5|6)\s?g(hz)?$/i` **or** the same `vendor`).

Cluster id = smallest BSSID, members in ascending `bssid` order, lead = RSSI maximum. **Per member** a `reason`
(the rule that binds it to a partner, e.g. `"vBSSID (+2 vs :41)"`, `"2.4+5 GHz same box (SSID base)"`). Displayed via the
toggle `deviceLinks` (key `D`, button 'Devices'): thin connections between sibling stars as a **separate layer**
(`drawDeviceLinks`); the look comes **exclusively** from tokens (`render.deviceTie`, colour `line.device`). Label dedup:
one device label + band facets + member counter as a sprite. **No layout shift**, so that `layoutInfo()`
remains theme-invariant. The tooltip/detail of each member shows the whole device (BSSIDs, bands/channels, SSID base, vendor,
`reason`) via `esc()`/`textContent`.

**G2 – ESS collapse (same SSID across several devices → one node).** An ESS = ≥ 2 **distinct devices** (G1 clusters)
with exactly the same non-empty SSID. Toggle `essMerge` (key `M`, button 'Merge SSID'): each set folds into one
node at its strongest member with a counter badge (= number of APs) and its own ring pattern (`ENCODING.merge`), expandable
(click or `expandEss`, `DEVICE.essExpandMs`); reduced motion → immediately. Folded members are hidden, removed from the
hit test and not counted in `stats().visibleAps`. If `groups` **and** `essMerge` are both on, the inner constellation lines
are dropped for folded sets.

**API / state / UI.** `STARCHORUS.devices()` (`{id, members[], bands[], vendor, reason[]}`), `deviceOf(bssid)`,
`essClusters()` (`{ssid, id, deviceIds[], apCount, expanded}`), `expandEss(id)`; `stats()` reports `devices`, `essMerged` and
`affinity`. `deviceLinks`/`essMerge` live in `S.ui` and `PERSIST_KEYS`; `?deviceLinks=1`/`?essMerge=1` take precedence and are
not persisted. The legend rows `#leg-devices`/`#leg-merge` appear only when the toggle is on and there is something to
show.

### 8.8a Random clouds (one nearby device that changes its address)

A phone or laptop that scans with a fresh randomised MAC for every burst of probe requests leaves a trail of short-lived
addresses: over the payload's one-hour window one device next to the Pager becomes a couple of hundred satellites at one
signal, a burst about every 47 s. Density bubbles (§4.6) fold them by screen position only, into several blobs for what is
one device. The page folds them by **signal and rhythm** into one node per cloud, in the model (section 29, theme-free,
deterministic, the input order never matters), so that 2D and 3D, labels, hit test, detail, legend, inventory, observations,
baseline, history and export all meet one cloud.

```js
CLOUD = { bandDb: 3, shiftEps: 0.01, shiftMax: 8, burstS: 2, burstCap: 1500, minAddr: 8, minBursts: 6, minHits: 5, cadMinS: 15, cadMaxS: 300, tolFrac: 0.1, tolMinS: 2,
  lagMax: 3, candMax: 6, streamMax: 5, zK: 6, hMin: 2, ratio: 2, fundFrac: 0.8, kCap: 3, alpha: 0.001, margin: 3, muMax: 0.5, muMaxMore: 0.8,
  joinDb: 6, mergeDb: 12, coincide: 0.6, mergeShare: 0.8, mixedShare: 0.6, keepAddr: 2, keepFrac: 0.5,
  expandMs: 6000, pxBase: 5, pxGain: 1.5, px3d: [4.5, 11], listMax: 300 };
RANDOM_MODES = ["cloud", "show", "hide"];
```

**Eligible:** a present station (`target = 1`) with a randomised MAC (`randomized`: the field `true`, or the U/L bit without a
vendor), not really associated (free or on a probe orbit), with an RSSI, D1-dated (`generated` present, `last_seen > 0`, at most
300 s ahead), and not this device's own transmitter (`center.own_bssids`, as in the export). An undated capture has no clouds: signal
alone would merge unrelated devices.

**The rule** (`cloudsOf(E)`, called by `rebuildClouds(gen, rp)`, in `ingest` after the client loops and the target sweep, before the
station history; stateless, so a page that has run for an hour and a page that has just loaded the same capture show the same members):
1. **Bands.** The eligible stations sorted (RSSI desc, MAC asc); while at least `minAddr` are left: seed = the RSSI value held by
   most of them (a tie: the stronger); up to `shiftMax` times, the window `r ≥ c − bandDb ∧ r ≤ c + bandDb` (exactly this form, not
   `abs`) gives the mean `m` (summed in that order) and `c = m`, until `|m − c| < shiftEps`. The window is a band and leaves the list.
2. **Bursts** per band: its `last_seen` values ascending; a gap `> burstS` starts the next burst, whose start is its first time. Only the newest
   `burstCap` bursts of a band are examined (about 20 hours of one device at every 47 s); an older address stays single.
3. **Streams** (the rhythm, `cloudStreams`). A rhythm is a period that the burst starts show far more often than unrelated bursts would. Two
   judges look for it in a band, the first until it finds no more (at most `streamMax` times, a stream's bursts leaving the band's list each
   time), the second on what is left; a rhythm is never a fixed grid (a device's gap is its period or a little more), so neither asks for one.
   *Pairs.* Candidates are the commonest whole-second gaps from a burst to each of the next `lagMax` bursts, between `cadMinS` and `cadMaxS`, at most
   `candMax`, one per tolerance (a gap within `tol` of one already taken is left out; a tie: the shorter). For a candidate `c`, `tol = max(tolMinS,
   tolFrac·c)`; the hits are the pairs `(i, j)`, `i < j ≤ i + lagMax`, with `|S[j] − S[i] − c| ≤ tol`, the bursts that take part are its support, and
   `side` is the mean of the pairs whose gap lies in the two bands beside the window (`c − 3·tol ≤ gap < c − tol` and `c + tol < gap ≤ c + 3·tol`):
   what this band shows by chance, its crowding, its minimum spacing and any other device included. The chance level is `E = max(1, side, P)`,
   `P` being what `n` unrelated bursts over `T` s would give as Poisson arrivals at `λ = n/T`: `P = n · e^(−λc) · (λ + λ²c + λ³c²/2) · 2·tol`, with
   `e^(−x)` as `(1 − x/1024)^1024` by ten squarings (the device's jq has no `exp` or `pow`; page and Overview do the same arithmetic). A candidate
   counts when it has ≥ `minHits` hits, a support of ≥ `minBursts` bursts, at least `ratio` times as many hits as `max(1, side)`, and `hits − E − hMin > 0`
   with `(hits − E − hMin)² ≥ zK²·E`. The one with the largest `(hits − E − hMin)²/E` wins (a tie: the shorter), unless a candidate (counting or not)
   about half or a third of it (within `tol` of the winner) has at least `fundFrac` of its hits: that is the fundamental and is taken instead. A burst
   held by one hit only, to a burst held by three or more, is a chance partner and is dropped. What is left is a **stream**; its period is the upper
   median of the hits' distances.
   *Chains.* In a band too dense for that (several devices at one signal, a crowd) pairs are everywhere and the first judge says nothing; there a device
   is told by a chain of bursts that keeps its phase: each burst one, two … `km ≤ kCap` periods after the one before it (each link within `tol`; the
   longest chain, a tie: the smaller miss), against the longest chain that bursts of that density make by chance. For each candidate and `km = 1, 2 …`
   while `km·2·tol·n/T ≤ μmax` (`muMax`, and `muMaxMore` from the second chain of a band, when what is left is thinner): a chain of `L` bursts over a span
   that holds `ns` bursts in `T'` s has `μ = km·2·tol·ns/T'` links by chance per burst; it counts when `μ ≤ μmax` and `L ≥ need(ns, μ) + margin`, `need(n, μ)`
   being the smallest `l` with `n·μ^(l−1) ≤ alpha` (worked out by repeated multiplication, no logarithm); the next `km` is tried only while the chain grows.
   The longest counting chain wins (a tie: the shorter period), its bursts leave the list, and the search runs again. Its period is the upper median of
   its link lengths over their multiples. A crowd gives no counting chain (it is too dense for `μmax`, or its longest chain is what chance makes), and
   two devices of one period, 8 s apart, are two chains. In simulated noise (tens of thousands of generated crowds and hours, none with a device) the
   two judges together give a cloud in about one scene in 2500 at the densest tried (1500 addresses in 15 minutes) and in none of 10 000 at the density
   of a house; the price is time: a lone, perfectly regular device needs 11 bursts to stand clear (any period), and a real one with the odd late burst a
   few more. Until then its addresses are singles or bubbles.
4. **Clouds.** The streams of all bands, the longest first (a tie: band, then stream order). A stream's **core** is the band's addresses inside its
   bursts. A stream joins an accepted cloud whose centre is within `mergeDb` when ≥ `coincide` of its bursts coincide (within `burstS`) with the
   cloud's (the same device heard in another signal band: a wide spread) or when its period is the cloud's, or a whole number of them up to `kCap`
   (a band that holds every other burst), within `tol`, and the two burst lists
   together (a start within `burstS` of another is the same burst) keep the rhythm, `cloudShare` ≥ `mergeShare` (a device that drifted from one band to
   the next, or a rhythm cut in two); the cloud's bursts are then the two lists together and its period the shorter one. Any other stream with ≥ `minAddr` core addresses is a cloud.
   The period shown, `cadenceS`, is the stream's own (a device's, not a gap between the bursts of two); `rhythm` is the share of the cloud's gaps between
   burst starts within `max(tolMinS, tolFrac·m·period)` of `m` periods, `m = 1 … kCap`. A rhythm below `mixedShare` is **mixed**: no one rhythm holds the
   bursts (two devices of one period, or one that scans unevenly), and the page says so rather than claim a steady one.
5. **Join.** Every other eligible station (RSSI desc, MAC asc) joins the first cloud with a band centre (its own, and those of the streams merged
   into it) within `joinDb` and one of whose bursts (± `burstS`) holds its `last_seen`. Period, bursts and share stay those of the stream. An off-rhythm address in the same band
   stays single (or in a bubble): the cloud holds what keeps the rhythm.

Cloud values: `rssi` = the members' mean (summed RSSI desc, MAC asc) rounded half away from zero, as jq's `round`; `rssiMin`,
`rssiMax`; `first`, `last` (capture times); `bursts`, `cadenceS`, `rhythm`; `probes` = the members' distinct probed SSIDs by count,
then name, at most 8; `core` = the stream's addresses (merged streams included), `joined` = the loose ones that joined. Probed SSIDs
are listed, **never** part of the key: one device probes for several.

**Identity, keep rule, death.** A new cloud's id is `"rc:" + hashInt(anchor)` in eight hex digits, the anchor being its core address
with the smallest (time, MAC); a clash with any existing entry takes `:2`, `:3` … The accepted clouds are decided first, then matched:
an accepted cloud takes over a cloud of the last rebuild (live, or only just faded) when they share at least `keepFrac` of the smaller
of the two, the most shared first (a tie: the smaller id), each cloud claimed once; the cloud keeps its node: id, home, alpha, history,
expand timer, pin. A cloud that no accepted one claims is **kept** while at least `keepAddr` of its own addresses are still here and in no
other cloud (`kept: true`): it never takes in a new address and never grows, it only runs down as its oldest bursts leave the collector's
window, so a device that has stopped fades gracefully instead of vanishing at the threshold. With fewer it fades out and its addresses
are single again (`cloud = null`). A rebuild reports a change (relayout) only when a member list, the set of clouds or a rounded signal
changes: the same capture polled again moves nothing. A change of source clears the clouds. A replay rebuilds them as a view (matched as on
a poll, no history) and leaves a cloud that fades during it in place, so Back to live takes up the same cloud with its id, series and pin.

**What the model does with them.** Members have no RSSI series of their own (an existing one is dropped); the cloud keeps one on its
node (`hist(id)`), one sample per capture. Members are never stored in the baseline (`baselineEligible`: an address that lives for one
burst) but count as present in the diff (a baselined station that a cloud takes in is not gone), never orbit (§8.9, `applyAffinity` releases them), never enter a bubble (§4.6). Events (D2): `S.ev.newInClouds` counts, once per
capture, the addresses new in it that joined a cloud live before it; the receive ring contracts only when `arrived > 0` or
`newStations > newInClouds`, so a device bursting every 47 s no longer pulses it at every capture; `newStations` stays the honest address
count. Observation (group 'Stations', key `s-clouds`, under the dwell gate): '121 randomised addresses in 1 cloud: probably one nearby
device changing its address' ('… in 2 clouds: possibly one or more nearby devices changing their address': two clouds can be one device
whose signal moved).

**The Random switch** (`S.ui.random`, key `X`, `#t-random` in the View group, `?random=cloud|show|hide`, persisted; §9.1): `cloud` (the
default) shows one node per cloud, `show` the addresses one by one as before, `hide` none of the randomised free addresses and no cloud.
It is a **view** (`applyRandom()` sets `randOut`): the clouds, `c.cloud`, baseline, observations, export, history and events are the
same in all three states; only what is drawn, hit and counted as visible changes.

| | `cloud` (default) | `show` | `hide` |
|---|---|---|---|
| Model (`S.clouds`, `c.cloud`, baseline, observations, export, history, events) | built | built (the same) | built (the same) |
| Free layout (relaxation) | members out, the shown cloud in | everyone, as before; no cloud | every randomised free address out; no cloud |
| Bubbles | never a member | as before | never a randomised free address |
| Drawn (2D/3D) | the cloud and its tag; members only while expanded or selected | the addresses | no randomised free address, no cloud |
| Hit test | the cloud; members only while `alphaDraw ≥ 0.25` | the addresses | none of them |
| Probe orbits | members excluded | as before | randomised free excluded |
| Satellites (`#n-cl`, `#bar-cl`), `stats().clients/free` | total | total | total − hidden |
| Legend 'randomised MAC' count | all randomised | the same | the same |
| Detail | the cloud's sheet | the stations' sheets | closes when the selected node is hidden |

**Drawing.** A shown cloud is one satellite in the theme's randomised mark (`render.clientRandomizedMark`, D8; no new token or
colour) at the radius of its mean signal, `basePx = pxBase + pxGain·rssiT(rssi)` (3D clamped to `px3d`), dimmed by its freshness. Its tag
'121 · random' ('121 · RANDOM' where the theme sets the HUD in capitals) is a baked text sprite placed right, left or below it where
the label grid is free, after the centre post has claimed its cells: no slot of the text budget, and it stays with `L` off, like
the bubble counters. A click selects it (never a pin); `Enter`, the detail or 'Show the addresses' expand it for `expandMs`: the
members appear at their homes and the cloud dims to `AGG.expandAlpha`.

**Wording.** A cloud is an estimate from signal and timing, never a device count: the number shown is always the number of
addresses, the plain-language line says 'Probably one nearby device changing its address' (a kept cloud: 'Probably the same nearby device as
before, though its rhythm is no longer clear'; a mixed one: 'Possibly one or more nearby devices changing their address: the same signal, heard in
bursts that keep no one rhythm', its Rhythm row 'no one rhythm · n bursts', no period in the tooltip, and the observation and the export's `estimate`
in the plural form of 'two clouds').

**The Overview** (`starchorus-display.sh`, JQLIB `clouds`: `rndfree`, `cl_bands`, `cl_bursts`, `cl_cands`, `cl_hits`, `cl_chance`, `cl_expm`, `cl_chain`, `cl_need`, `cl_median`, `cl_drop`, `cl_streams`, `cl_ongap`, `cl_share`, `cl_union`, `cl_in`) applies the same rule to each
capture on its own, inside the screen's one jq program, without the keep rule: a first load of the page and the Overview agree
(`tools/regress.d/clouds.sh` compares them on documents at every threshold). Deliberate divergences: numeric strings in `rssi` or
`last_seen` do not count there, and its vendor test does not strip control characters.

### 8.9 Probe orbits (passive affinity, derived)

The recon database supplies free clients **without** an AP binding – otherwise they would have no 'planet'. The collector
therefore optionally emits the **requested SSIDs** per station (`probes[]`, at most 8, from received probe requests; purely
receiving). `applyAffinity()` (section 25, after `rebuildGroups`) lets a free client orbit the **visible** network SSID
it is asking for: the least occupied AP of that SSID, with the same capacity as for real clients. Toggle
`affinity` (key `P`, button 'Probes', **default on**), `?affinity=0|1`, in `PERSIST_KEYS`. The orbiter is recognisable as *derived,
not associated*: free look without a band ring, **dashed** path in `line.device`, **no** link and no
travelling dot (nothing is exchanged), tooltip/detail 'probe orbit · looking for <SSID> · not associated (derived)'.
Real associations always win. Probe orbiters count as `free` in `stats()`, `stats().affinity` gives their number, and they
are **not** an obstacle for the spread relaxation, so that the layout remains theme-invariant.

**Wording.** Every source drops wildcard probes, so `probes[]` holds named probes only and the JSON cannot say whether a station also
sent a wildcard one: the words 'broadcast probe' are never written (`tools/regress.d/neutral-language.sh` counts them: 0). One helper,
`probeWords(list, max)`, gives a station (and a random cloud) its words in the tooltip, the detail panel and the cloud sheet: 'named
probe: <SSID>', several 'named probes: a, b' (the tooltip shows three, then '+n'), none 'no named probe heard'. The legend line reads
'dashed orbit = named probe for this network (derived, not associated)'. The Overview uses the same words within its 50 columns: the
Probes screen 'N client(s) with a named probe:' with one line 'named: <SSID>  (xN)' per name, or 'No named probe heard.'; the Stations
screen 'named probe' for a free station that has one.

### 8.10 Manual identity (set by the operator)

Purely **manual** classification per observed identifier (AP or station) – the operator classifies, the tool never does so
automatically (passive → no statement about intent). Values: `friend` (allow list, rectangle), `neutral` (square), `hostile`
(label 'Suspect', dashed diamond), default `unknown` (no frame). Shapes fixed in `ENCODING.identity` (theme-free);
**on the canvas only the shape in `ink.primary`** (D7); the conventional colours appear only in the detail panel next to the word.
Set in the detail panel (four buttons), persisted in `localStorage["starchorus.identity.v1"]`; the legend shows the three
classes in the 'Operator' block. API §10: `setIdentity(key, id)`, `identity(key)`, `identities()`, `identitySource(key)`;
`stats().identities`. No automatic finding.

### 8.11 Observe and compare (display only)

Change log per AP (DS channel, security class, SSID, band; ≤ `CHG_MAX` entries, ≤ `CHG_BSSIDS` BSSIDs; never `freq`);
baseline (≤ 500 APs, ≤ 2000 stations with RSSI only, never an association) with diff and ghosts (D19: without `channels[]` never
'gone'); Observations (neutral, derived hints; only after two held captures; look-alike only against the
confirmed set; toggle `W`); watchlist (`aps[].ssid` only). Phone hotspots (P3) and the operator's own transmitters produce nothing.

### 8.12 Tools (display only)

Library (text import/export, OUI rules friend/neutral only, P7), alias/notes/tags (≤ 200 observed identifiers), export
(JSON/CSV/SITREP, PNG snapshot, print; APs and their stations, only values from frames addressed to all
(P6), `EXPORT_FOOTER` in every output; excluding own transmitters and phone hotspots; the CSV has a trailing `cloud` column, the id of the
random cloud a station belongs to, §8.8a), inventory (count chips, with the hidden randomised addresses still counted in the stations chip, value filter, sortable
table, `I`), homing meter (`F`) for the identifier chosen at the collector (clocked by the poll, sound off; for this the collector
additionally supplies `homing`), security lock on the constellation label.

### 8.13 Channel, time, playback (display only)

Channel view (Bars · Spectrum · Waterfall; DFS table, max signal and peak hold, **estimated** beacon occupancy with
visible assumptions), air quality (`Q`: neutral words, co-/adjacent-channel counts), signal over time (`J`: 1 min/10 min/1 h,
ESS curves, threshold as line and ring), recording and playback (`H`: complete captures in memory, ≤ 120 / 8 MB; the
playback is a view: no model advances, polls are recorded and shown after 'Back to live').

---

## 9. UI and controls (sections 36–38)

### 9.1 Controls (`#controls`, bottom right)

| Group | Element | Key | Behaviour | Persisted |
|---|---|---|---|---|
| Bands | `[data-band="2.4"\|"5"\|"6"]` | `1/2/3` | Filter: AP + associated clients are hidden, free ones remain; the counters `#n-*` show the **filtered** value, `title` the unfiltered number; the channel bar follows | no |
| View | `#t-labels`, `#t-orbits`, `#t-links`, `#t-pause` | `L/O/K/Space` | Labels off = no AP labels (not even pinned/hovered/locked) together with facets, '×n', vendor lines, client badges and cursor (§6.6); core text, 3D ring posts, group labels and glyphs remain; pause text 'Pause'/'Resume'; Links = curves **and** travelling dots/probe arcs | yes (except pause) |
| View | `#t-random` ('Random') | `X` | Randomised addresses (§8.8a), cycled by a press like the channel view: one node per cloud (`.on`) → one by one → hidden (`.on`, struck through); `data-state`, `aria-label` and `title` name the state and the next one; the text stays 'Random' | yes |
| Watch | `#t-obs`, `#t-baseline` (+ `#baseline-set`, `#baseline-clear`), `#t-inv`, `#btn-export` | `W`, `B`, `I` | Observations, baseline diff, inventory (drawers, §8.11/§8.12), export dialogue | yes (toggles) |
| Analyse | `#t-air`, `#t-time`, `#t-rec` | `Q`, `J`, `H` | Air quality, signal over time, recording/playback (§8.13) | no |
| Look | `#t-theme` | `T` | cycles through the three themes; text = name of the next theme; `applyTheme()` | yes |
| Look | `#t-view` | `V` | '3D'/'2D'; `setView()`; shows/hides the four orbit arrows of `#cam` | yes |
| Look | `#t-rotate` | `R` | Auto-rotation (effective only in 3D) | yes |
| Look | `#t-spin` | `S` | Sky rotation about the observer (§4.2a), 2D and 3D, default on | yes |
| Look | `#t-crt` | `C` | Scanlines + vignette + persistence; visible only with `crt.userToggle` | yes |
| Look | `#t-panels` ('Hide panels'), `#panels-pill` | `U` | Hide panels (§9.8): the sky alone; the pill (dot + chip) brings them back | yes |
| Look (phone) | `#t-scope` ('Scope', 44 px, in the sheet's row) | `Z` | The Scope (§9.8b): phone layout only; no button on the desktop | yes |
| Layers | `#t-agg` | `A` | Aggregation; `.forced` + `title` when forced (§4.6) | yes |
| Layers | `#t-vendor` | `E` | Vendor on the label (§8.7) | yes |
| Layers | `#t-nebula` | `N` | Interference nebula | yes |
| Layers | `#t-groups` | `G` | Constellations | yes |
| Layers | `#t-devices`, `#t-merge`, `#t-probes` | `D`, `M`, `P` | Device links, ESS merge, probe orbits (§8.8, §8.9) | yes |
| Camera | `#cam-left/-right/-up/-down/-in/-out/-reset` | Arrows, `+/−`, `0` | §5.6; `#cam` is there in both views, in 3D with all seven buttons and in 2D with `+`, `−` and reset only (titles 'Zoom in [+]', 'Zoom out [−]', 'Reset [0]'), except that on a desktop window 620 px high or less the 2D row is hidden (`#cam.flat`, a media query), because the D15 rules at 760×600 and 1000×500 need its 40 px; `+`, `−`, `0` and the wheel still zoom there | – |
| Analyse (phone) | `#t-home` ('Homing'), `#t-help` (in About) | `F`, `?` | Homing meter and the shortcut list, which have no button on the desktop | no |

'Random' sits in the View group, not Layers: Layers is the widest group and sets the width of `#controls`, so a button there
moves the channel bar and the detail (measured 73–74 px at 1440×900 and 1000×640; at 1000×640 in Whitehall the docked channel bar
collapses); in View every desktop panel box stays as it was (`tools/regress.d/clouds.sh`).

All toggles carry `aria-pressed`, a `title` with the shortcut, the class `.on` and `:focus-visible` in `accent.focusRing`. **Shortcuts
apply only when `document.activeElement` is `null`, `document.body`, `canvas#hud` or `#panels-pill`**, and never with Cmd or Ctrl held
(Ctrl+U stays view-source; AltGr, which is Ctrl+Alt, still types `[` and `]`) – on a focused button
`Enter`/`Space` trigger only the native activation; in input fields and on `canvas#detail-spark` (§8.1) their own
keys apply. `?` opens the overlay `#help` (`S.ui.help`, not persisted; with the panels hidden it brings them back); `?`/`Esc`/`#help-close` close it. `Esc`:
order is dialogues (`#paste-wrap`, export) → `#help` → detail/lock → hover → in phone mode a drawer or the legend card → the sheet (collapses).

### 9.2 Detail panel (`#detail`)

Opens on a click on an AP, client or bubble (2D and 3D) and via `STARCHORUS.select(id)`; on the right below `#source` (in phone mode
the Detail card of the sheet, §9.8); `aria-live="polite"`; content via `textContent`. Header: title (SSID / MAC / 'n clients') + cursor span,
vendor line, `#detail-close`; `Esc` closes it (and releases the camera lock). Content per type: AP → §8.3 + client list; client →
MAC, vendor, randomised ('locally administered'), signal, freshness, orbit (SSID/BSSID, probe orbit or 'unassociated'),
Probes ('named probe: <SSID>', with the theme's probe note; 'no named probe heard' without), identity/notes, pin button; bubble → count, mean RSSI, vendor distribution, member list (scrollable, capped),
row click → expand + select the member (§4.6); random cloud (§8.8a) → title 'n randomised addresses', a lead ('Probably one nearby
device changing its address: the same signal, heard in bursts at a steady rhythm. An estimate from signal and timing only; it does not
count devices.'; for a kept cloud 'Probably the same nearby device as before, though its rhythm is no longer clear: the addresses still here are
kept together.', for a mixed one 'Possibly one or more nearby devices changing their address: the same signal, heard in bursts that keep no one
rhythm.', each with the same last sentence), rows Addresses ('n · randomised (locally administered)'), Signal ('-29 dBm (100 %, …) · range -34 to -28 dBm'),
Rhythm ('about every 47 s · 30 bursts'; 'no one rhythm · 153 bursts' when mixed), First heard, Last heard, Freshness, Probes (the same words, with the theme's probe note; 'no named probe heard' without),
'Show the addresses' (expands it), the members newest first (MAC · dBm · age; at most `CLOUD.listMax`, then 'first 300 shown'; a row
click expands, pins and selects that address) and the note 'Random [X]: one node per cloud, one by one, or hidden. Enter shows the
addresses of the selected cloud again.'; the sparkline shows the cloud's series in `render.clientCore`; opening it expands it once
(a re-open on a poll does not). The panel stays open after `load()` if the node still
exists; otherwise it closes. Pin: a click on an AP toggles `pinned`, and likewise on a client (additive).

### 9.3 Tooltip (`#tip`)

Above the cursor (`translate(-50%, calc(-100% − 14px))`, mirrored at the edges), cursor `pointer`. AP: SSID (hidden in italics),
BSSID, **Vendor** ('—'), band with shape + '5 GHz · ch 44 · 80 MHz' (without width: '20 MHz assumed'), signal + mini sparkline,
security (class + glyph), clients, freshness, overlaps (max 2, with 'derived'), group/device. Client: 'client · orbits
<SSID>' / 'client · unassociated' / probe orbit, MAC, **Vendor** ('—' or 'randomised'), Probes ('named probe: <SSID>', 'named probes: a, b',
three names at most and then '+n'; 'no named probe heard'), signal ('n/a' without RSSI). Bubble:
§4.6. Random cloud (§8.8a): 'random cloud', 'n randomised addresses · about every 47 s', Signal with its range, Heard, Probes (the same words); no sparkline. With `data-plaque="on"` the same rows side by side in pairs. Values in `ink.primary`, keys in `ink.secondary`.
Touch: a tap shows the tooltip briefly, a second tap opens the detail. One hit test per frame.

### 9.4 Legend (`#legend`, `buildLegend()`, rebuilt per theme)

**One builder, four blocks (D10):** Measured / Derived / Operator / Look (headings from `copy.legendHeads`). A row is
visible exactly when its mark can be drawn (`legendVisibility()`, `updateLegendCounts()`). Swatches are
inline SVG with `fill/stroke: var(--…)`: every swatch/glyph colour is a `CSS_MIRROR` variable of **the same token** with which
sections 31–35 draw the mark (identity: `data-enc` → `ENCODING.identity`); ring width, dashing and double ring
come from `ENCODING`. Ornaments (glow/bloom/halo, ticks) are not part of the swatch. Check: `STARCHORUS.legendRows()` (§10)
and the regression run `tools/regress.d/legend.sh` (`tools/evals/legend-truth.js`).

Rows in this order (`data-kind` in brackets):
1. **Measured** – bands (`band-24`, `band-5`, `band-6`: shape in `--band-*`, filled with `render.shapeFill`, otherwise outline +
   centre dot, with counter `#leg-24/-5/-6`); 'Band ?' (`band-unknown`, square) only while a star without a band is being
   drawn. Clients: 'free client' (`client-free`), 'associated' (`client-assoc`, with band ring), 'randomised MAC'
   (`client-random`, only while such a client is present; its count is every present randomised station whatever the Random switch,
   and the sub-label `#leg-random-cl` adds ' · m in k cloud(s)', m the addresses in them, while there are random clouds, §8.8a), 'n clients (bubble)' (`bubble`). Security (`sec-<klasse>` per
   class of `ENCODING.security`, only with an AP): ring swatch as in `drawApRings` + glyph in the colour of its tone + label + count.
   Freshness 'Heard' (`fresh-t0` … `fresh-t3`, `fresh-undated`; only while dated nodes are present; unreachable levels
   are dropped) and, in Whitehall, the freshness lamps (`#tote`). 'hidden SSID' (`hidden`), the alert row (`alert`, 0.2: only while an
   alerted access point is drawn; a ring swatch in `status.alert`; 'alert ring = many deauth/disassoc frames heard for this AP', §14.6) and the geometry row (`geometry`):
   'rings = received signal (dBm), not range · direction is not measured'; while the Scope is on (§9.8b) its note row (`scope`): 'lanes =
   band, channel · arcs = signal (dBm) · not direction, not range', which repeats the foot's two captions (the geometry row stays).
2. **Derived** – 'channel overlap (derived, width unknown → 20 MHz)' (`#leg-nebula`), 'same ESSID' (`#leg-groups`), 'linked
   radios · likely same device (heuristic)' (`#leg-devices`), 'merged SSID · one node per ESS (count = APs)' (`#leg-merge`),
   'dashed orbit = named probe for this network (derived, not associated)' (`#leg-probes`), `copyFor("legArc")` (`#leg-arc`, exactly
   when `render.probeArc` and `line.edge.style === "parabola"`), crowding (`#leg-crowding`), deviation (`#leg-deviation`),
   ghost (`#leg-ghost`); each row follows its toggle **and** its data.
3. **Operator** – identity (`id-head`, `id-friend`, `id-neutral`, `id-hostile`), 'selected' (`selected`), 'pinned' (`pinned`).
4. **Look** – 'height = band (2.4 below · 5 mid · 6 above)' (`height`, 3D only).
5. Footer `#leg-rx` (all themes, always): `copyFor("legRx")` – passive 'RX only · nothing is transmitted', with `sourceKind`
   `active` the ACTIVE row.

### 9.5 Stats (`#stats`), source, masthead

`#n-ap` 'Stars', `#n-cl` 'Satellites' (`title="n free · m associated"`, then the probe orbits, ' · r randomised, i of them in k
cloud(s)' and, with Random hidden, ' · h hidden'; the number is the visible total, which only Random hidden lowers, §8.8a), `#n-24`, `#n-5`, `#n-6` (filtered; `title`
unfiltered), `#n-fresh` ('heard < 1 min'), `#n-record` ('on record'), `#n-alarm` (only > 0; alarm swatch + number in a
text token), `#n-groups` ('ESSID sets'), `#n-crowd` ('crowding /5'). `STARCHORUS.stats()` returns filtered and unfiltered
counts. `#source`: mode chip = `THEME.copy.chip[state]` with `state = sourceKind`, where a poll-fed `live` feed becomes
`stale` when stale and `offline` when the Pager cannot be reached (class `mode <state>`, `offline` with the class `stale` as well; a
stale or offline ACTIVE feed keeps the text 'Active scan' and additionally gets the class `stale`, visible by the dashed edge); when
stale, the `title` says 'no new capture for n polls' (every poll since the last new `generated`, failed ones included), when
offline 'The Pager could not be reached; the last capture was at HH:MM UTC.' (the time of the last `generated`, as the caption
says it) – the number never appears in the chip, so that `#source` keeps its height. `#source-desc`: 'Simulated sky. Load a starchorus.json to see
your own sky.' (`demo`) / 'Live from <b>label</b> · HH:MM:SS' (poll-fed, UTC from `generated`; 'Last capture from <b>label</b> · HH:MM:SS' when the Pager cannot be reached) / 'Showing <b>label</b> ·
N APs' (paste/drop/API) / 'No capture source · note' / after an unreadable file 'Could not read <b>name</b> · still showing
the previous sky' (the source remains). This is the **only** `innerHTML` path besides the tooltip: fixed templates,
`label`/`note`/`name` exclusively via `esc()` (max 80 characters, control characters removed). Masthead `.tag`/`.motto`,
`meta[name=description]`, `#leg-rx`, `#leg-arc`, the probe note in the detail, the logon mode line and the banner come from
`copyFor(site)` or `THEME.copy` (§3.1); `renderSourceTruth()` rewrites them on every change of theme, source and
liveness. The `.tag` is the permanent passivity notice – **except** with `sourceKind` `active`: then it
reads, as everywhere else, 'ACTIVE SCAN · the collector sent probe requests'. The passive `.motto` reads 'Observation only — it
listens, it never transmits.' and with `active` 'Wi-Fi landscape visualiser.'.

**Liveness (D3/U4).** Staleness is measured in **poll time**: what the cadence waited, with no clock read. A scheduled poll
counts the wait before it (plus `POLL_TIMEOUT_MS` when it hit its deadline); a poll by hand (`STARCHORUS.pollNow()`) and a live
API load (`load(doc, label, {mode:'live'})`) count one `POLL_MS` tick, as every poll did before. `S.staleMs` adds up the poll time
of a poll-fed document that brings the same source with the same `generated` (`null === null` counts as unchanged – freshness
cannot then be proven) and of every failed or unusable poll (404, network error, deadline expired, JSON error, response
without an `aps` array); a failed poll adds only its time, it is no extra tick. `S.stalePolls` counts those polls (for the chip's
title). A new `generated` or a change of source resets both. `captureStale()` = poll-fed ∧ `sourceKind ≠ none` ∧
`staleMs ≥ staleAfterMs()`, where `staleAfterMs()` = max(30 s, 2 × `center.interval` + 15 s) when the document announces an
interval (the payload announces 30 s → 75 s; the collector's default 5 s → 30 s; an interval is read as at most
`POLL.maxIntervalS`, 600 s, so a broken document cannot switch the limit off), and `STALE_POLLS` × `POLL_MS` = 30 s, as
always, when it does not. Demo, Recorded and None never become stale; a poll-fed ACTIVE document does. The mode chip and its
`title`, the masthead dot, the WarGames source badge, the IMSAI lamps (frozen) and the panels pill all read `captureStale()`, so
they flip together.

**Offline.** Stale does not say why. `S.lostPolls` counts the polls that got no answer from the server (network
error, deadline expired, any status but 200) since the last one that did; any 200, a document or not, sets it to 0 (a 200 with
no document adds only the stale time: the server answered, the capture is what is missing). `captureOffline()` =
`captureStale()` ∧ `lostPolls ≥ OFFLINE_POLLS` (3): the capture is stale and the last three polls have gone
unanswered, so the capture may well be current and the page has simply not heard. `liveness()` names the state: `live`, `stale`
or `offline`. Offline reads `copy.chip.offline` / `copy.badge.offline` ('Offline'; WarGames 'Link down'; Whitehall 'No link') in
the chip's and the badge's stale styling (dashed, dimmed; no alarm colour); the dot, the lamps and the pill behave as for
stale, and the chip's `title`, the dot's `title` and the pill's `aria-label` carry the sentence above. 'Stale' stays for a
server that answers while `generated` stands still. The rule counts polls, not silent time, so an outage that begins while the
capture is already ageing still reads 'Offline' from the stale threshold on: the page asks every 2 s while it waits for a capture,
and three of those have gone unanswered within seconds. Only an outage that begins within the last two polls before the threshold
reads 'Stale' for one or two polls first. The first answer ends the outage: a new `generated` brings 'Live', the
old one 'Stale' (not 'Live'). The page reads no clock, so the time is the last capture's, not the moment the link went.
Demo, Recorded, None and a replay are untouched, and a page that has never been answered keeps the sample sky.
`STARCHORUS.stats().captureOffline` reports it.

**Cadence.** One poll at a time, each armed when the one before has ended (`pollArm`, `pollNextMs`, section 38). The capture
**spacing** is the median of the last three gaps between distinct `generated` values of the source (`captureSpacing()`); before
the first gap the first guess is 1.1 × `center.interval`, without an interval `POLL_MS` (5 s). After a new capture the next poll
comes 3 s before the next one is due (spacing − 3 s, at least 2 s), then one every 2 s until it arrives or the capture is
stale; once stale, and while no poll-fed capture is shown (demo, a pasted file, a page without `starchorus.json`), every
`POLL_MS`. A failed poll is retried at the next 2 s step. A capture that is already there at the first poll after the lead
may have been waiting for any time, so the 2 s steps take over until the next capture, which then sets the phase. With the
payload's 30 s cycle that is about three polls per capture, each within 2 s of the capture. A spacing is read as at most 600 s as
well. A poll that throws after the request counts as a failed one (`STARCHORUS.errors()` has the fault) and the next is armed all
the same: nothing between two polls can end the chain. `STARCHORUS.pollPlan()` reports
the spacing, the threshold, the poll time and the waits of the last 60 scheduled polls. `?poll=0` arms nothing; `?demo=1` makes no poll at all (§2.7).

**Poll deadline.** `tryPoll()` returns the same pending promise while a fetch is in progress, and has a deadline: after
`POLL_TIMEOUT_MS` (4 s; `?pollto=<ms>` shortens it, for tests only) an `AbortController` aborts the fetch, and the poll
counts as a failed one (`noteStalePoll()`). A hanging server or a half-open connection therefore cannot keep the chip
on 'Live', and while it stays silent the chip turns 'Offline'. The only network call remains `fetch("starchorus.json…")`.

### 9.6 Keyboard

`T` theme · `V` 2D/3D · `R` rotation · `S` sky rotation · `C` CRT · `Space` pause · `L` labels · `O` orbits · `K` links ·
`A` aggregation · `E` vendor · `N` nebula · `G` groups · `D` device links · `M` ESS merge · `P` probe orbits ·
`W` Observations · `I` inventory · `B` baseline diff · `F` homing meter · `Q` air quality · `J` signal over time ·
`H` recording/playback · `Y` channel view (Bars → Spectrum → Waterfall) · `1/2/3` band filter · arrows/`+`/`−`/`0` camera
or 2D zoom · `[`/`]` step through pinned nodes (opens the detail) · `Esc` (§9.1) · `?` shortcut overlay · `Tab` through all
buttons, `Enter`/`Space` on a focused button (native activation only) · `←/→/Home/End` on the focused
`canvas#detail-spark` (§8.1) · `U` hide or show the panels (§9.8) · `X` Random: one node per cloud → one by one → hidden (§8.8a) ·
`Z` the Scope (phone layout only, §9.8b) · `Enter` with a random cloud selected shows its addresses again. Every letter has a use now. The drawers (Observations, Inventory, Homing, Air, Time, Record)
share the **one** legend box (D15); only one is ever open. The table `KEYS` (section 20) is the only
source for `title` attributes and `#help-list`. In tests cdp switches the theme with `--key t` (with `?intro=0`; otherwise the
logon appears in the screenshot).

### 9.7 Touch

Pointer events (`touch-action: none`), distinguished by `pointerType`: one-finger drag = orbit (3D) / no effect (2D, no
pan), tap = brief tooltip, second tap = detail, two fingers = pinch (+ drift); a tap acts like a click (pin toggle +
detail, §5.6); no separate long-press is assigned. Drag threshold 10 px; hit radius `max(px + 10, 16)`; buttons ≥ 36 px
with `pointer: coarse`, every tap target ≥ 44 × 44 px in phone mode. In phone mode a tap on empty sky collapses the sheet
(and closes the detail; an unlocked 3D camera stays where the fingers left it); the sheet's head takes drags and flicks (§9.8).

### 9.8 Phone mode (D21)

**When.** `PHONE.query` = `(max-width: 720px), (max-height: 460px) and (pointer: coarse)`: every phone upright, every phone on
its side, a desktop window up to 720 px wide; no desktop window above that and no iPad. `?phone=1|0` overrides. It replaces
the old small mode (which hid the stats, the legend with every drawer, the channel bar and the camera). `phoneOn` is the one
flag: `regulatorStart` and the §35 label cap take `RENDER.mobile` from it (12 labels, DPR cap 1.5, LOD +1). Outside phone mode
nothing changes: no `--ph-*` variable, no `.ph-only` element, the sky on the viewport centre (`skyBox()` = the viewport).
Before the script runs, a phone-sized page keeps its panels hidden (a media rule on `:root:not([data-phone])`), so the
desktop chrome does not flash while the page loads over the device's slow server.

**Layout.** `applyPhone()` moves the panels – the same elements, ids and listeners – and moves them back when the mode ends
(their original places are recorded once): the brand `#mast-brand` and `#mode-chip` into the status bar `#bar`, the Bands group
into the sheet's head, and `#controls`, `#chanbar`, `#stats`, `#source`, `#masthead`, `#legend`, `#detail`, `#help` into
`#sheet-body`. Nothing is duplicated: the chip that says Live / Stale / Offline / Sample is the one chip (D4).
- **Status bar** `#bar` (44 px, `role="group"`, 'Status'): dot + STARCHORUS, the counts `#bar-ap` 'stars' and `#bar-cl`
  'satellites' (mirrors of `#n-ap`/`#n-cl`), the chip. When they do not fit, the brand closes up (`.tight`), then the words are
  only read aloud (`.tighter`), then the counts go (`.tightest`; the Sky section keeps them).
- **Sheet** `#sheet` (`role="region"`, labelled with its card): a head (grabber, row) and `#sheet-body`, the one scroller
  (`overscroll-behavior: contain`). Three heights: **peek** (the head, 66 px), **half** (at most half the view and never over
  the device at rest: the half sheet's top stays `PHONE.centreClearPx` below the sky centre), **full** (up to 8 px below the
  bar); never taller than its content. Every load and every change of mode starts at peek.
- **Cards**, one at a time, derived on every pass: help > detail > a drawer > legend > controls. Controls: the Bands group,
  Legend and the chevron in the head; in the body View, Look (with Hide panels), Layers, Camera, Watch, Analyse (with Homing),
  then Channels, Sky (the stats as a four-column grid), Source (with Load…) and About (masthead, theme ornaments, Help). The
  other cards show their title (the detail's is the data string, D16), ‹ › with two or more pinned nodes, and ×. Leaving the
  controls remembers their height; a card opens at half if the sheet is lower; a new drawer or node opens at the top. A detail
  opens collapsed (its title row) when its star would sit under the half sheet, and always in 3D (the camera turns the star to
  the front).
- **Input.** The chevron `#sheet-toggle` (`aria-expanded`), a tap on the head, the grabber: peek ↔ half. A drag on the head moves
  the sheet with the finger (reduced motion too: direct manipulation is not decoration; from collapsed the body is shown for the
  length of the drag); on release a flick (≥ 0.4 px/ms) goes
  to the next height that way, otherwise the nearest one; a drag that began on a button does not press it. Scrolling the body at
  half opens it fully. A tap on empty sky collapses it. `Esc` closes a drawer or the legend card, then collapses.
- **On its side** (`data-dock="side"`, wider than high): the bar and the sheet form a left column (`clamp(300px, 42vw, 360px)`,
  half = full) and the sky centres in the free area to its right. The dock does not flip while a text field has the focus (a
  soft keyboard shortens the view).
- **The sky** is centred in `skyBox()`: between the bar and the collapsed sheet (upright), right of the column (on its side),
  above the pill (panels hidden); `outerFrac` unchanged. `F3Dof()` takes the box's height.
- **Whitehall** on a phone: the banners wrap (9 px) instead of losing the disclaimer; their measured heights (`--ph-banner-t/-b`)
  replace `--chrome-top/-bot`; the DTG sits under the top banner, the bar under the DTG, the sheet 8 px above the bottom banner.
- **iOS**: `viewport-fit=cover` with the safe-area insets on the bar, the sheet, the banners, the dialogues and the logon's
  skip button; `100dvh`; `text-size-adjust: 100%`; inputs at 16 px so that nothing zooms on focus; `touch-action: manipulation`
  on buttons, `none` on the bar, the head and the pill; no tap highlight. The paste and export dialogues open at the top.
- `phoneLayout()` is the phone pass of `layoutEdges()` (theme-free, DOM boxes only): it publishes `--ph-banner-t/-b`, `--ph-top`,
  `--ph-bar-b`, `--ph-sheet-h`, `--ph-sky-cx` and `edgeState.sheet`, never a `--lay-*` variable, and calls `resize()` when the
  sky's box moved (theme, banners, fonts). `STARCHORUS.phone()`, `setSheet(d)`.

**Hide panels** (every size): `U`, `#t-panels`, `?panels=0|1`, `setToggles({panels})`; `S.ui.panels` is saved in
`starchorus.ui.v1`. Every panel goes but `#detail` (it still opens on a click or tap; on a phone the sheet shows for the Detail
card) and the two dialogues; the boxes keep their size, so no layout moves on the desktop. The Whitehall banners, the DTG, the
CRT and the caption stay. `#panels-pill` (bottom right on the desktop, bottom centre on a phone, out of the way of a Detail
card) mirrors the dot and the chip, so Live / Stale / Offline is never hidden; it brings the panels back. Focus moves from a panel
control to the pill, and from the pill back to `#t-panels` or the chevron. On a phone the sky re-centres over the screen.

**A check on a real iPhone.** 1 Portrait from the Pager's address: the bar clear of the Dynamic Island, the sky
centred, a slim sheet above the home indicator, no sideways scroll. 2 Chevron up and down; drag the grabber to full, flick it
down; at half, scroll the controls (the sheet opens fully). 3 Labels, 3D, the 5 GHz filter; pinch and drag the sky in 3D, the
sheet stays. 4 Tap a star (the detail with its name and ×, the star still visible), ×, tap empty sky (collapses). 5 Legend,
Observe, Inventory (scroll the table sideways), Air, Time, Record, Homing in turn: one at a time, × back to the controls. 6
Rotate with the sheet at full: a left column, the sky right of it, the notch clear; rotate back. 7 WarGames (brackets, cursor)
and Whitehall (both banners whole with 'NOT A GOVERNMENT SYSTEM', the clock under the top one). 8 Hide panels, tap a star,
close it, the pill brings the panels back; hide, reload (still hidden), bring them back; pinch on the bar and on the pill does
not zoom the page. 9 Source → Load…: the dialogue at the top, typing does not zoom, the keyboard does not cover Render; in the
detail's Alias field the keyboard leaves the field visible. 10 Reduce Motion: the sheet snaps, the dots stand still. 11 Both
Safari tab layouts (Compact and Bottom) against the sheet; VoiceOver reads 'STARCHORUS, 11 stars, 33 satellites, Sample' and
'Expand the sheet, button, collapsed'. 12 First paint from the Pager's address typed into Safari: no desktop chrome before the sheet appears.

### 9.8b The Scope (D22, phone layout only)

A second view of the same capture for a small screen: a fan standing on the Pager, 60° wide, with the sky's own nodes on it. It
is a view of what was heard, drawn by the same `drawGlows`, `drawClients`, `drawClouds`, `drawStars` and `drawHud` (sprites,
labels, selection and change cues unchanged) and never a sweep. It is **named** 'Scope', never 'Scanner' or 'Motion'; the page
never says it looks for anything.

**When.** `scopeOn = phoneOn && S.ui.scope`: phone mode only (≤ 720 px, a phone on its side, `?phone=1`). The button `#t-scope` (44×44,
in `#sheet-row` before the legend button; on a phone on its side, where the row has no room, it moves to the Look group), the key
`Z` and `?scope=1|0` (not saved) switch it; `S.ui.scope` is saved in `starchorus.ui.v1` and is **off by default**. The wide desktop
has no button, no strip and no foot (`:root:not([data-scope=on])` hides them), and `?scope=1` there changes nothing. Hide panels (`U`)
keeps the strip and the foot and hides the bar and the sheet. A saved 3D view stays saved and comes back with the Scope off.

**Geometry** (theme-free; `SCOPE`, `scopeGeom()`; `scopePlace()` places). The apex O lies below the Pager (the foot's centre, `#sc-ps`);
the fan opens upward through ±30° (`SCOPE.half`), narrowing to the box where it would leave it (`thv`). **Radius = signal**: `r = rNear
+ (1 − rssiT(dBm))·(rFar − rNear)` with `rNear = max(34, 0.18·L)` (L is the length of the fan, from the Pager's mark to the strip); the rings are drawn at the sky's own −40/−60/−80 dBm (D9); the innermost
ring is the strongest signal. The radius never moves, whatever the capture. **Angle =
a place in a lane, never a direction.** The lanes are the bands: 2.4 GHz, 5 GHz, 6 GHz, stations (widths 0.4372/0.5684/0.2623/0.6121 in
units of the fan's half-angle, a gap of 0.04 between them, so that the three bands and the stations share the fan). While Bluetooth marks
are present and the filter (`4`) is on, `scopePlace()` adds a fifth lane, 'BT', after the stations (width 0.35, and every width and gap
is scaled by 0.8368 so that the fan still spans −1…1); a mark sits in it at `hash(id + "sc")`, its radius is its signal like every blip, and
the lane goes again with the marks or the filter. Without marks the four lanes are exactly the ones above (the lanes are built in
`scopePlace()` for this reason, not in `scopeGeom()`). A network sits at
`scU(band, channel)` along its lane (channels ascend; 1/6/11, 36/100/149 are marked), a station or a cloud at `hash(id + "sc")` (the
sky's own stable hash, so a station keeps its place when its signal changes). A network whose band is unknown goes into the 6 lane
and the lane is named '6 · ?'. Networks are nudged sideways (never along the radius) where they would overlap; stations are not.
A lane that is narrower than two blips keeps the ideal place and accepts the overlap (the nudge would turn over there). Channel ticks
are drawn left to right, and a tick that would touch the one before it is left out. The result is stored on the node as
`n.sc = {k, r, x, y, px, st, nw, q}`. `SC.g` is `null` when the fan would be shorter than 120 px (a small phone on its side, with the
Whitehall banners): the Scope then draws no fan, and the foot's RX line adds the theme-free note 'Too little room for the scope: turn the
phone upright'. The line is rewritten before every measure, so a roomier window brings the fan back.

**A wave per capture.** `scopeStep` (the tick's body in the Scope: `stepNodes`, `stepClouds`, no rotation, bubbles or particles)
re-places the nodes when `S.ingestSeq`, the Random switch or the band filters change and starts a **wave** on a new capture or a
replay step. A wave is **one arc that contracts** from the far rim to the near one in `clamp(2·fadeInMs, 1200, 1800)` ms: three strokes
of decreasing width and alpha (`SCOPE.arcs`) in `accent.selection`; a node that is new in the capture (`nw`) stays hidden until the front
has passed its radius (`q`), then appears. It never runs outward, there is no sweep and nothing rotates (R39). Reduced motion
(`reduceMotion`), pause and fixed time draw no arc and no wait: the new node shows at once. At rest the page draws **no frame**
(`scopeWantsFrame()`: the wave and 1.5 s after it, then 2 a second while the feed is not live). WarGames' phosphor persistence
(`S.persistOn`, set in `beginFrame`) is on only while the arc runs and never arms the idle trail (`persistFade`) in the Scope: idle and snow
frames clear the canvas, so a stale feed costs 2 frames a second there too.

**Stale and offline.** `SC.lv` follows `liveness()`. A live feed is drawn clean with a solid rim. A stale or an offline feed shows
**snow** (damped specks, `SCOPE.snow`: 1 per 1600 px² stale, 1 per 400 px² offline, redrawn twice a second, standing still under
reduced motion) over the fan, the rim dashed, and the chip's own word appended to `#sc-rx` ('RX only · nothing is transmitted ·
Stale'; in WarGames 'Link down' for offline, in Whitehall 'No link'). Never the alarm colour: a stale feed is not an alarm.

**Chrome.** In the Scope the bar shows the brand, the lamps (WarGames: eight IMSAI lamps, `#scope-lamps`) and the chip; the sky's
counts, the 3D button, the layer group and the camera are hidden (they have no meaning on the fan; their state is kept). The number
strip `#scope-strip` (five fields: networks, stations, clouds, strongest signal, new networks) is read from the same model as the stats;
its words are `copy.scope.strip[5]` in each theme (Foundation 'Stars / Satellites / Clouds / Brightest / New'; WarGames 'NETS /
STATIONS / CLOUDS / PEAK / NEW'; Whitehall 'NETWORKS / STATIONS / CLOUDS / STRONGEST / NEW PLOTS'). The foot `#scope-foot` carries the
captions **'lanes = band, channel / not direction'**, **'arcs = signal (dBm) / not range'** and **'RX only'** (from `copy.rx.legRx`,
D4). No word or number label in the Scope is smaller than 13 px (`fontString` takes the floor in the Scope; the strip's words are 13 px,
its numbers 20 px); the small glyphs inside a mark (the security glyph, the count of a folded ESS) keep the sky's sizes. Words are cut to
fit, never shrunk: when the strip is wider than its panel it first takes the theme's letter-spacing off (class `t`), then hides the words
and keeps the five numbers (class `n`; they stay in the page for a screen reader); a lane name drops to its first word, and a tick that
would touch another is left out. The strip never wraps a number, and its unit keeps its case ('-48 dBm' in every theme; the foot's caption is in the theme's capitals). No sound, no
vibration, no request of its own.

**Input.** A touch on a blip selects it (the same detail card in the sheet; no camera flight, a saved 3D view is not entered), a touch
on empty fan closes it. Wheel and pinch do nothing. The legend hides the derived rows (nebula, groups, devices, merge, crowding) while
the Scope is on and shows a note row, `scope`, that repeats the two captions ('lanes = band, channel · arcs = signal (dBm) · not
direction, not range'); the geometry row stays. A saved 3D view is not entered: the 3D ring labels are not drawn in the Scope.

**Not in 0.2.0.** The first design drew more than the code does, and these are specified and not there: the note `#scope-note`
with `copy.scope.empty` ('Nothing heard in this capture') and `staleNote()` (so `copy.scope` holds the strip words only, 63 leaf paths in all, not 64: an empty
capture shows the empty fan, and a stale or an unreachable feed says so in the chip's word on the foot's RX line); blips dimmed to ×0.6 when
stale and ×0.4 when offline (the snow and the dashed rim say it); the sample sky's demo wave every 10 s (the arc runs on entering the
Scope and on each capture); a 3 px dot for each station above 150 (stations stay sprites at any count; the 300-blip bench is the proof);
the ticks at 9 px (they are 13 px); and the alerts' ring flicker: the alerts' code adds the term to the frame rule (`scopeWantsFrame()`: only
while an alert is live, under 3 Hz, also under reduced motion) and the drawing to `drawScope()`, which the Scope's fixed draw list does not
carry on its own.

**Cost.** At most 12,000 bytes of the page (`MAX_SCOPE_BYTES`, one share of the page cap, `tools/static.sh`); the fifth lane's code is counted in the
radio pair's share, not in this one (`MAX_SCOPE_BT_BYTES`, an allowance inside the pair's 14,000); `tools/regress.d/scope.sh` also pins the Scope's own growth (the page's growth since the base of the Scope less the bytes of the alerts' ring and legend, found by their markers, at most the Scope's share and the fifth lane's allowance; the row prints the number) and
reads the geometry, the lanes, the wave, the idle, the strip against a recount of the fixture, the captions, the storage key and the
absence of any send path. **A check on a real iPhone** (not proven by the harness): 1 Turn it on in the sheet's row: the fan
stands on the Pager, the strip above it, the foot below. 2 Read it as signal only: a strong signal sits on the inner arcs, by the Pager's mark,
in whatever lane. 3 Wait for a capture: one arc contracts and new points appear as it passes. 4 Turn on Reduce Motion: no arc. 5 Take the device
out of range for a minute: snow and the word 'Stale', then 'Offline'. 6 A newcomer asked 'which way is the network?' should say it
cannot be told from this view.

### 9.8a Edge-panel layout D15 (outside phone mode, theme-free)

A single edge-panel rule with `--chrome-top/--chrome-bot` (banner from `chrome.banner.show`). `layoutEdges()` (section 37, reads
only DOM boxes, never `THEME`; constants in `EDGE`) resolves collisions: `#stats` centred in the free header gap, otherwise `.fit`
(compact + wrapping, minimal number of rows, balanced; always below 1100 px); `#legend` with a `max-height` reaching to `EDGE.gapPx` below
the top panels of its column, scrolling in `#legend-body`; `#chanbar` between legend and controls (≥ `EDGE.chanMinPx`), otherwise
docked above `#controls`, otherwise collapsed; `#detail` between the header row and controls/channel bar (≥ `EDGE.detailMinPx`);
below 900 px `.motto` off; below 1100 px `#masthead`/`#source` at most 300 px. Called on every size change (theme,
resize, stats, source, legend, controls, detail, font) + `ResizeObserver` (rAF-deferred). Measurement uses the class
`.raw` (section 03): it lays out `#stats`, `#legend` and `#detail` as the plain CSS would, while the `--lay-*` values stay on
`:root`. The scroll offsets of the legend, the drawers and `#detail` survive a pass; a newly opened drawer and the detail of a
different node start at the top. Target: intersection area 0 for all
visible edge panels at 1440×900, 1280×800, 1000×640 and 760×600, in three themes, without and with `#detail`.
`STARCHORUS.edgeLayout()` reports the decisions.

### 9.9 Invariants ('MUST STAY', numbered; code comments cite the numbers)

1 Poll `fetch("starchorus.json?_=" + clock.toFixed(0), {cache:"no-store"})` immediately, then on the cadence of §9.5 (spacing −
3 s after a capture, 2 s steps until the next, `POLL_MS` 5000 once stale or without a poll-fed capture; the only
network call; `tryPoll()` returns its promise and starts no second fetch while one is in progress; `STARCHORUS.pollNow()`
triggers exactly this poll; with `?demo=1`, §2.7, there is none). Success → chip 'Live' + timestamp from `generated`, **only as long as the feed is not stale**
(§9.5; from `staleAfterMs()` of poll time onwards chip 'Stale', or 'Offline' when the last three polls got no answer); a fetch that has not answered after `POLL_TIMEOUT_MS` is aborted and counts
as a failed poll. Other errors pass without a message; a response without an `aps` array is ignored; the poll continues after
load/paste (the source panel names the source unambiguously; `?poll=0` for tests only). During playback
polls are buffered and shown only after 'Back to live' · 2 JSON contract + tolerances (§2.8; band derivation ends at
`unknown`; empty `clients[]` work) · 3 Paste dialogue: IDs and sequence (textarea, 'Render', 'Cancel', `Esc`, click on the
backdrop, error text in `#paste-err`) · 4 Drag & drop → `loadData(obj, dateiname)`, invalid → notice in the source panel ·
5 `loadData()` soft (`ingest` sets whatever the capture no longer contains to `target = 0`) + 'Showing <b>esc(label)</b> · N APs' · 6 Demo at boot
(`sourceKind` `demo`), chip 'Sample' (`copy.chip.demo`), text verbatim; the demo is never stale. Further chip states from
`S.sourceKind` + `captureStale`/`captureOffline` (D4): 'Live' · 'Stale' · 'Offline' · 'Recorded' (paste/drop/API) · 'Active scan' (`/ACTIVE/i` in
`doc.source`, takes precedence) · 'No feed' (`source:"none"` or no document) · 7 Band-filter semantics (§9.1) · 8 Toggle +
pause semantics ('Resume'; fade-in/out and radius easing continue) · 9 Tooltip above the cursor, cursor `pointer` ·
10 Pin by clicking a star (label alpha 1; clients additive) · 11 Counter IDs · 12 Layout semantics: centre = observer
with text `center.label`, fallback **'YOU ARE HERE'**, distance = RSSI, rings **−40/−60/−80** labelled (four signal levels
in between, D9; ring stroke `line.ring` ≥ 3:1) · 13 Encoding: band = colour **+ shape**, security = ring style, hidden (tooltip
'(hidden SSID)'), the client count enlarges the star (+ badge) · 14 stable, index-independent placement · 15 Fade-in/
fade-out · 16 `prefers-reduced-motion` · 17 DPR cap 2 (adaptive below that) · 18 offline, no external link ·
19 Passivity: only the poll; paste text **verbatim** 'Everything runs in your browser — nothing is uploaded.' (`grep -c` = 1);
every passivity claim comes from `THEME.copy` (D4) and, when `sourceKind === "active"`, is replaced by 'ACTIVE SCAN · the collector
sent probe requests' or dropped · 20 Phone mode per §9.8 + focus rings (edge-panel layout outside it: §9.8a) · 21 Random clouds
(§8.8a) come from the model only; their members never enter bubbles; the Random switch changes only what is drawn, hit and counted as
visible · 22 The Scope (§9.8b) is phone layout only, off by default, saved in `starchorus.ui.v1`; it draws only during a wave and
while the feed is not live; its angle is a place in a lane and its radius is the signal, and no text or aria label says otherwise.

---

## 10. Test/debug API `window.STARCHORUS` (section 40) and query overrides

Read and control only; no network function; no persistence side effect except via `setToggles`/`setTheme`/`setView` and the
tools that save explicitly (baseline, identity, library, notes, watchlist – like a click in the UI). The
setters call **the same** functions as the UI (no special path; `persist: true`, they lift `S.queryLocked` for the key).
All pixel/world values in return values (`nodes`, `node`, `nodeScreen`, `layoutInfo`, `bubbles`, `labels`, `camera`) are rounded to
1e-3 so that separate runs are string-identical. All return values are JSON-serialisable; **every method catches its own
errors** and returns `{error: String(e)}` instead of throwing (the error also lands in `S.errors`). Stations and APs
are released only as observed values or counts (§14.5). `Object.freeze` on the object; `_internals` only with
`?debug=1`.

```js
window.STARCHORUS = Object.freeze({
  version: "0.2.0-dev.1",
  // Theme / View
  setTheme(id) → string,                 // "foundation"|"wargames"|"whitehall"; like #t-theme, without intro; returns the active theme
  getTheme() → string,
  setView(v) → string,                   // "2d"|"3d"; starts the blend
  getView() → { mode, blend },
  setReducedMotion(on) → boolean,        // central toggle (like ?rm=1); null = back to the media query
  // Data
  load(obj, label = "API", opts?) → { ok, aps, clients, free, assoc, sourceKind, error? },   // = loadData(); invalid → ok:false without exception;
                                         //   only opts.mode === "live" makes the source poll-fed (can go stale), otherwise "recorded";
                                         //   same source as the previous load (kind · route · label · doc.source) → the particles stay
  loadDemo() → like load, with sourceKind "demo" (chip 'Sample'),
  // State
  stats() → { aps, apsTotal, clients, clientsTotal, free, assoc, groups, bubbles, visibleClients, visibleAps, alarms, hidden, revealed,
              bands, bandsTotal, security, fresh: {t0,t1,t2,t3,undated}, freshClients: {…}, events: {captureSeq, arrived, departed, changed,
              cues, newAps, newStations, departedStations, newStationsText}, crowding, deviations, baseline, observations, changeEntries, watch,
              hop, own (counts only), theme, view, mode, source, generated, centerLabel, sourceKind, sourceLabel, liveFeed, stalePolls,
              captureStale, captureOffline, fps, frameMs, lod, dpr, dprStep, autoLod, nodes, sprites, spriteBytes, particles, flares, travelDots, probeArcs,
              labels, twinkles, interferencePairs, blend, settling, forcedAgg, themeErrors, storageFailed, introShown, paused, devices,
              essMerged, affinity, identities, library, chanMode, coreBeat, threshold, recording, replay, drawer, inventory,
              randomised, randomisedFree, clouds, inClouds, visibleClouds, randomMode, randomHidden },   // §8.8a: free/assoc/clients/visibleClients are
                                         //   visible counts (Random hidden takes the hidden addresses out); events also carry newInClouds
  layoutInfo() → §4.7 object,
  camera() → { az, el, dist, target: [x,y,z], locked, autoRot, ramp, blend, zoom2d, sky, spin, tween: bool },   // sky = S.skyA (rad)
  setCamera({az?, el?, dist?, target?}, snap = true) → camera(),   // target and (with snap) actual; aborts a tween
  resetCamera() → camera(),
  setZoom2d(z) → camera(),               // always about the observer
  setToggles({labels, orbits, links, paused, agg, vendor, nebula, groups, rotate, spin, crt, autoLod, help, deviceLinks, essMerge, affinity,
              observations, baselineDiff, inventory, panels, random, bands: {"2.4": bool, …}}) → getToggles(),   // switches, and random ("cloud"|"show"|"hide";
                                         //   an unknown value is ignored); any other key whose S.ui value is no boolean is ignored
  getToggles() → {…},                    // with panels and random
  select(id | null) → string | null,     // like a click, but **without** the pin toggle (lock in 3D, detail panel); returns the detail title
  deselect() → null,
  hover(x, y) → id | null,               // simulates pointermove at CSS pixels (tooltip appears)
  hoverNode(id | null) → id | null,      // hover directly (tooltip at the nodeScreen position)
  hoverChannel(band, ch | null) → string | null,   // hover over the channel bar; returns the #chan-tip text
  pin(id, on?) → boolean,
  expandBubble(id) → boolean,            // §4.6 expand
  expandEss(id) → boolean,               // §8.8 G2 expand
  expandCloud(id) → boolean,             // §8.8a: a live cloud's addresses show for CLOUD.expandMs
  clouds() → Array<{ id, kind, n, core, joined, members, rssi, rssiMin, rssiMax, centre, first, last, bursts, cadenceS, rhythm, probes,
                     kept, shown, expanded, pinned, freshTier, ageS, sx, sy, px, zc, alphaDraw }>,   // §8.8a the live random clouds, by id
  hitTest(x, y) → id | null,             // pure hit test without side effect
  node(id) → { …public fields (§2.1/§2.2), phyEstimate, pmf, sx, sy, zc, px, fog, alphaDraw, bubble, bubbleBlend, pinned, cloud, randOut } | null,
                                         //   a cloud id returns its clouds() entry
  nodes(filter?) → Array<{ id, kind, sx, sy, px, zc, alphaDraw, visible, bubble, vendor, width, rssi }>,   // filter: "ap"|"client"|"free"|"assoc"|"bubble"|"cloud";
                                         //   clouds are not in the unfiltered list (as bubbles)
  nodeScreen(id) → { sx, sy, px, zc, fog, visible } | null,   // also a cloud id (as hoverNode)
  bubbles() → Array<{ id, n, sx, sy, r, expanded, members: string[] }>,
  labels() → Array<{ id, kind: "label"|"vendor"|"group"|"badge"|"counter"|"facet"|"ring"|"glyph"|"cursor"|"cloud", text, x, y, sprite }>,
                                         //   drawn in the last frame; every HUD text appears in it exactly once; sprite separates baked from counted (§6.6)
  labelCandidates() → string[],          // AP IDs with label eligibility in priority order; theme-free = labelCandidateList()
  channels() → { "2.4": {ch: count…}, "5": …, "6": …, overlaps: [{a, b, score, kind, assumed}] },
  groups() → Array<{ key, members: string[], bands: string[] }>,
  devices(), deviceOf(bssid), essClusters(),   // §8.8
  hist(key) → { n, last, min, max, samples: number[], ts: (number|null)[] } | null,   // ts null = document without generated; a cloud id → the cloud's series
  skyStats() → { n, ok, minN, band, security, hidden, crowding: {level, busiest}, deviations: [{band, channel, count, ref, dir}], ref },
                                         // D11: aggregates only, no MAC/BSSID/SSID; cell = {count|null, shown, p, lo, hi} (< 5 suppressed, p/lo/hi only from N ≥ 30, Wilson 95 %)
  themeCheck() → { ok, mismatches: [[name, css, js]…] },
  themeAudit(live?) → { ids, union, keyCount, missing, kinds, errors },   // boot finding; live = true checks THEMES now
  contrast(pairs?, themeId?) → Array<{ fg, bg, ratio, fgHex, bgHex, min?, pass?, what?, error? }> | { error },
                                         //   WCAG 2.x (0.01); side = token path | "#rrggbb"/rgb()/rgba() | "ground" | layer list [top…bottom];
                                         //   without pairs → CONTRAST_PAIRS (§7.0a, §14.4); themeId computes another theme without switching
  legendRows() → Array<{ kind, id, visible, cnt, paints: Array<{ prop, raw, tok, css, val }>, rings: Array<{ w, dash }> }>,   // §9.4
  edgeLayout() → { stats, chan, legendMaxH, detailTop, detailMaxH, sheet? },   // §9.8a, runs layoutEdges() idempotently (read only); stats/chan "phone" in phone mode
  phone() → { on, sky: { cx, cy, r }, card?, detent?, dock?, peek?, half?, full?, h? },   // §9.8; the sheet's fields only in phone mode
  setSheet(d) → string,                  // "peek"|"half"|"full" in phone mode (otherwise unchanged); returns the height in force
  setPanels(on) → boolean,               // Hide panels (§9.8), like U; saved
  // Control for tests
  settle(maxIter = 600) → layoutInfo(),  // synchronous: settleLayout → rebuildBubbles → settleLayout(non-members); display = layout; draws 1 frame
  frame() → void,                        // forces exactly one render frame
  wait(ms) → Promise<void>,              // time passes (setTimeout); the way to wait in evals
  measure(seconds = 2) → Promise<{ fps, renderedFrames, rafFrames, p50Ms, p95Ms, maxMs, drawCalls }>,
  perf() → { frameMs: {ema, p50, p95, max}, fps, lod, dpr, drawCalls: {drawImage, fillRect, stroke, fillText, shadowBlur, gradient} },
  setFixedTime(ms | null) → void,        // freezes time: dt = liveDt = 0, clock = ms/1000, one render when dirty, then idle (§6.1)
  skipIntro() → boolean,                 // true if a logon was running
  logonLines() → string[],               // logon lines of the current theme for the current source
  logonTiming() → number[],              // motion.logonCharMs
  bannerLines() → string[],              // [copy.bannerTop, copy.bannerBot[sourceKind]]
  pollNow() → Promise<{ ok, fresh, stalePolls, captureStale, sourceKind }>,   // triggers the existing poll now (one POLL_MS tick of poll time); if one is already running, the same Promise is returned
  pollPlan() → { spacingS, staleAfterS, staleS, sinceS, nextMs, log: number[] },   // §9.5: observed spacing (null before two captures), threshold, poll time, the next wait, the waits of the last 60 scheduled polls
  pixel(canvasId, x, y) → { r, g, b, a },   // getImageData at CSS pixels (dpr-aware) on "bg"|"sky"|"hud"
  particleDigest() → number,             // Σ (x + y) over live particles (standstill check)
  storageDump() → object | null,         // localStorage[STORAGE_KEY] parsed
  resetStorage() → boolean,
  errors() → string[],                   // window.onerror + unhandledrejection + API errors since boot (max 50)
  _internals: undefined | { S, THEMES, TK, TD, LAYOUT, AGG, CFG3D, RENDER, spriteCache, particles: { count, pooled }, SC, SCOPE }   // only ?debug=1
});
```
Rules: `stats().fps` = rAF ticks of the last second (also during idle skip); `measure()` additionally returns `renderedFrames`.
`errors()` collects from boot and is `[]` in normal operation. `layoutInfo()` and `nodes()` work in **drawn**
screen coordinates. The query overrides are in §2.7; they win over localStorage and are not persisted.

### 10.1 The model and tool API

All functions catch their own errors (`{error}`) and release only observed values, counts or aggregates;
`_internals` only with `?debug=1`.

| Function | Purpose |
|---|---|
| `themeAudit(live?)`, `themeCheck()`, `contrast(pairs?, id?)`, `legendRows()`, `labelCandidates()`, `edgeLayout()`, `logonLines()` | theme-free checks: key symmetry, CSS↔token, WCAG ratios, legend truth, label eligibility, edge-panel layout |
| `pollNow()`, `pollPlan()`, `stats().fresh/events/crowding`, `skyStats()`, `load(doc, label, {mode})` | live display, cadence and staleness, freshness, events, aggregates (D1–D3, D11) |
| `phone()`, `setSheet(d)`, `setPanels(on)` | phone mode and Hide panels (§9.8, D21) |
| `changes(bssid)`, `baseline()`, `setBaseline()`, `clearBaseline()`, `observations()`, `watch(ssid?, on?)`, `clearLocalData()` | change log, baseline, observations, watchlist, delete everything local |
| `setIdentity(key, id)`, `identity(key)`, `identities()`, `identitySource(key)`, `libraryImport(text)`, `libraryExport()`, `libraryAssign(cls, filter)`, `notes(key, patch?)` | identity, library, alias/notes/tags (observed identifiers only, `observed()`) |
| `exportText(fmt)`, `exportPng()`, `inventory(filter?)`, `homing()`, `openHoming(on?)` | export, inventory, homing |
| `channelView()`, `airQuality()`, `timeSeries(scale?)`, `setTimeScale(sc)`, `setThreshold(dbm)`, `setChannelMode(m)`, `waterfall(band)`, `openDrawer(name)` | channel, air-quality and time models, drawers |
| `recording()`, `replay(i)`, `replayInfo()`, `replayExit()`, `clearRecording()` | recording and replay (counts only) |
| `recvRing()`, `lamps()`, `badge()`, `lampStrip()` | WarGames: receive ring, capture lamps, source badge, lamp strip per AP |
| `tote()`, `plotClock()`, `logonTiming()`, `bannerLines()` | Whitehall: freshness lamps, sector clock, teleprinter cadence, banner |
| `dust()`, `skyLine()`, `vault()`, `caption()` | Foundation: dust by freshness (`dust().litSide`: lit and shaded grains), Compendium line, Vault, place·time caption |
| `hover(x,y)`, `hoverNode(id)`, `hoverChannel(band,ch)`, `hitTest(x,y)`, `expandBubble(id)`, `expandEss(id)`, `devices()`, `deviceOf(bssid)`, `essClusters()` | pointer and groups |
| `clouds()`, `expandCloud(id)`, `nodes("cloud")`, `stats().randomised/randomisedFree/clouds/inClouds/visibleClouds/randomMode/randomHidden`, `getToggles().random`, `setToggles({random})` | random clouds and the Random switch (§8.8a) |

## 11. Test environment (development machine)

The tools are described in `tools/README.md` (which also holds the fixture table with the sizes of every file in `tests/fixtures/`).
This section defines how browser runs address the page and which criteria every regression run checks.

`tools/verify.sh HTML FIXTURE|demo PREFIX [cdp-Args]` starts `python3 -m http.server` on a free port, calls
`tools/cdp.py` with `--wait 6 --fps 3 --json`, filters the expected 404s for `favicon.ico` and – in demo mode only –
`starchorus.json`; exit 0 = no exceptions, no real console errors, fps ≥ 30.

**Sequence of `tools/cdp.py`:** load page → pump for `--wait` s → `--click`/`--key` (then `--after-wait`) →
**fps measurement over `--fps` s** → `--eval` expressions (one after another; a returned Promise is awaited, timeout
`--eval-timeout` = 30 s; an expression with top-level `await` runs in REPL mode) → `--step` list (`eval:EXPR` · `click:X,Y` ·
`clickat:EXPR` → `[x,y]` · `key:KEY` · `wait:S` · `size:WxH`) → screenshot → report. Chrome picks its own DevTools port;
parallel runs never share a browser. Consequences: (1) The report's fps figure applies to the state **at load time** –
theme/view for the measurement are set via query parameters (§2.7), never via `--eval`. (2) fps after a change triggered via
`--eval` is measured by `STARCHORUS.measure(sec)`. (3) Time passes in evals only via `STARCHORUS.wait(ms)`. (4) The
screenshot shows the state after the last eval; call `STARCHORUS.settle()` or `wait()` beforehand. (5) Every run has a
fresh profile – persistence is checked within a run via `STARCHORUS.storageDump()`. (6) `prefers-reduced-motion`
is switched via `?rm=1`. (7) cdp.py rasterises headless with `--disable-gpu` (software): absolute fps figures are pessimistic;
`perf().drawCalls` is the hardware-independent primary criterion.

### 11.0 Harness (mind the cdp.py order: wait → click/key → fps → evals → steps → shot)

```sh
. tools/harness.sh        # sets R (repo root, determined relatively; path with spaces → always quote), F, H; mkdir out/
sh tools/regress.sh base  # full non-regression (table; exit 0 = every row PASS), from any cwd
sh tools/passivity-check.sh              # static passivity/licence checks alone
sh tools/fresh-check.sh worktree|clone   # the regression runs from a fresh clone
# (a) standard run without query parameters (verify.sh sets --wait 6 --fps 3 --json, PASS verdict, 404 filter):
sh "$R/tools/verify.sh" "$H" "$F/many-clients.json" "$R/out/many" \
   --eval "STARCHORUS.errors().length" --eval "JSON.stringify(STARCHORUS.stats())"
# (b) run with query parameters: runq FIXTURE|demo "QUERY" PREFIX [cdp-Args…] → PREFIX.png + PREFIX.json; chk PREFIX.json [demo]
runq "$F/field-scale.json" "?theme=wargames&view=3d&intro=0" "$R/out/scale-3d" \
   --eval "STARCHORUS.errors().length" --eval "JSON.stringify(STARCHORUS.camera())" ; chk "$R/out/scale-3d.json"
# (c) sequence run (data/event logic): runseq = runq with ?poll=0&spin=0&intro=0&fixed=$STARCHORUS_FIXED, without fps measurement
runseq "$F/active.json" "$R/out/seq" --eval "await STARCHORUS.wait(300), STARCHORUS.stats().source"
# (d) the same expression in all three themes: ev3 → JSON {theme: value}, ev3eq → true if equal
runq "$F/many-clients.json" "?intro=0&poll=0&spin=0" "$R/out/t3" --fps 0 --eval "$(ev3 'STARCHORUS.perf().drawCalls.fillText')"
```
Rules: `fps ≥ threshold` from `PREFIX.json`, `exceptions == []`, console errors only `favicon.ico` (and `starchorus.json` in
demo mode). Time in evals only via `await STARCHORUS.wait(ms)` in an async IIFE or as top-level `await`. **Every eval
that calls `STARCHORUS.load()`/`loadDemo()` and then waits or checks state runs with `?poll=0`** (otherwise the
poll ingests the fixture in between). Screenshots with `STARCHORUS.setFixedTime(0)` as the last eval, when idle preceded by
`STARCHORUS.frame()`. Double-load determinism = two separate cdp runs with an identical eval, compared via `diff`.
Marker section of a line: `secof LINE` from `tools/harness.sh`.

**Sequence runs** (`runseq`): under `?fixed=` from boot, dt = 0 and no node fades in (alphaDraw 0, only the centre label;
`hitTest` still hits) – label, budget and screenshot evals in sequence runs begin with `--eval "$EV_THAW"` (thaw
briefly, freeze back to the query time, one frame). `?fixed` is in milliseconds. Visual, label and
budget comparisons never use `?fixed` from boot, but `?poll=0&spin=0&intro=0`, and freeze in the eval after the fade-in.
**Drop-ins:** thematic check rows live in `tools/regress.d/<name>.sh` (sourced by `regress.sh`, checked by
shellcheck; `rowif` for a condition, otherwise `if/then/else`, never `A && row PASS || row FAIL`).

**Global mandatory criteria for every regression run** (`sh tools/regress.sh`; fixtures `demo`, `legacy`, `few-clients`, `many-clients`,
`field-scale`, `single-ap`, `empty-none`, `devices`, `field-probes`, `active`):
```
verify.sh PASS (0 exceptions, 0 real console errors, fps ≥ 30) for all 10 runs, Foundation 2D
--eval "STARCHORUS.errors().length"                       → 0
--eval "STARCHORUS.stats().themeErrors"                   → 0
themeCheck().ok in all three themes                       → true
Theme invariance: setFixedTime(0); per theme setTheme; await wait(300); settle(); frame() → geometric + state fields of
  layoutInfo() equal in all three themes (§4.7), 2D and ?view=3d
--eval "(STARCHORUS.frame(), STARCHORUS.perf().drawCalls.fillText)"   → ≤ 30 in 2D runs, ≤ 24 in ?view=3d runs (RENDER.maxText), per theme
Stress run field-scale 2D/3D (all APs pinned, vendor on, lock) → ≤ 30 / ≤ 24 per theme, cursor included
grep -c "fonts.googleapis" starchorus.html                                   → 0
grep -c "Everything runs in your browser — nothing is uploaded." starchorus.html → 1
grep -c "YOU ARE HERE" starchorus.html                                       → ≥ 1
grep -n "==== " starchorus.html | awk -F'==== ' '{print $2+0}' | sort -nc    → no output, exit 0 (numerically sorted)
awk '/==== 22 UTIL/,/==== 31 SPRITES/' starchorus.html | grep -c 'THEME\.\|TK\[\|TD\.'      → 0
awk '/==== 36 INTERACTION/,/==== 37 UI/' starchorus.html | grep -c 'THEME\.\|TK\[\|TD\.'     → 0
awk '/==== 31 SPRITES/,/==== 36 INTERACTION/' starchorus.html | grep -c '#[0-9a-fA-F]\{6\}'   → 0
STARCHORUS.themeAudit().errors → 0, three key sets of equal size · labelCandidates(), hit-test grid and nodes().px equal in all three themes
Theme ID comparisons (every ID, every spelling) and comparisons on S.ui.theme/THEME.meta.id/getTheme()/dataset.theme outside section 39 → 0
grep -o '[data-theme=' starchorus.html → 0 · Date.now only in the viewer's clock (D14) · new Date() without argument / Date() / performance.now outside 40 → 0
grep -n '\.shadowBlur *=' → sections ⊆ {31, 33, 34} · grep -n 'createRadialGradient(' → sections ⊆ {31, 33, 37}
grep -c "Math.random" starchorus.html → 0
L off → 0 AP labels (only the centre) in 3 themes × 2D/3D · click pins/unpins · probe orbits without band ring · fillText = listed
  text entries without sprite flag · same load keeps particleDigest(), pooled === count
sh tools/passivity-check.sh → exit 0 (denylist via sh tools/denylist-check.sh) · shellcheck (collector, both starchorus-display.sh,
  both payload.sh, library/**, tools/*.sh, tools/regress.d/*.sh) · cmp of both starchorus-display.sh
python3 tools/gen-testdata.py --validate tests/fixtures/*.json (legacy.json with --legacy) → OK · active.json = generator output (ACTIVE_GEN)
Documentation binding: STARCHORUS.version = spec §10 · spec §14 complete (D1–D21, P1–P10, U1–U4 with U1 open, ten sections) · no
  film quotation in spec or README · README quotes COPY_ACTIVE and the page's chip label verbatim · §3.8/§7.0a = code
```

## 12. Risks and countermeasures (with section anchor)

| # | Risk | Effect | Countermeasure (anchor) |
|---|---|---|---|
| R1 | Persistence overlay smears text/HUD | unreadable labels, counters | three canvases: text only on `#hud` (`clearRect`), background on `#bg`, persistence only on `#sky` via `destination-out` (§6.2, §6.7) |
| R2 | Persistence brightens static marks | neon instead of phosphor, contrasts tip over | alpha compensation `a' = a·P/(1 − a·(1−P))` in `setAlpha`; no `lighter` under persistence (§6.7) |
| R3 | `shadowBlur` cost | frame rate | bloom baked into sprites, no live `shadowBlur` in the frame path; travelling dots are baked bloom sprites (§6.3, §7.3) |
| R4 | Full orbit circles = ring moiré | 'mush ring' | 60° arcs only for associated clients, no arcs for free clients, LOD ≤ 1 (§4.3) |
| R5 | DPR 2 quadruples the raster | < 60 fps on high-resolution displays | controller with hysteresis in both directions, start cap by node count, `#hud` sharp (§6.5) |
| R6 | Hit test in 3D hits hidden/distant nodes | wrong tooltip/detail | 3D candidates sorted near→far (`zc`), first hit, `alphaDraw ≥ 0.25`, bubble members not hittable (§5.5) |
| R7 | Determinism broken (randomness, dt-dependent relaxation, array index) | jumping nodes, non-reproducible screenshots | seeded PRNG only for star field/particles, relaxation without dt in `mac` order, AP angle from hash + spiral, sorting at ingest, `setFixedTime` (§4.0–4.2, §10) |
| R8 | Relaxation does not converge at extreme density | permanent `settling`, CPU | density rule forces aggregation, two-phase settle, iteration cap, stop at `settleEpsPx` (§4.2, §4.6) |
| R9 | Bubbles flicker at the threshold / giant bubbles | restlessness, density information lost | anchor ID from the densest cell, hysteresis, rebuild only on events, cluster cap of 4 cells (§4.6) |
| R10 | Bubbles hide individual clients permanently | loss of information | tooltip with top vendors and MACs, member list, expand, toggle (except when forced), `visibleClients` (§4.6) |
| R11 | Bubble counter unreadable in 3D | number too small / too faint | `minPxBubble`, `bubbleFogFloor`, otherwise no counter (§4.6, §5.4) |
| R12 | Client sprites touch despite spreading | not individually recognisable | `clientMinDistPx` ≥ sprite diameter; `minClientDistancePx`, `overlapsPx` (§4.2, §4.4) |
| R13 | Clients in the star glow | clumps | star zone as obstacle, orbits ≥ 32 px, clients drawn over glows; `clientsInStarZone === 0` (§4.2–4.4) |
| R14 | `localStorage` throws (private mode, quota, `file://`) | boot aborts | `safeStorage` in `try/catch`, defaults, debounced; `?storage=fail` boots (§2.6, §2.7) |
| R15 | Old/broken JSON (`null` entries, strings, missing arrays) | exception at ingest, poll loop dies | `normalizeDoc` with type check per field, skip entries, `tryPoll` catches everything (§2.8) |
| R16 | Client in `clients[]` and `unassociated` / duplicate BSSID | duplicate nodes | associated wins, first AP wins, BSSID merge (§2.8, §4.0) |
| R17 | Band not derivable | wrong band colour | `unknown` band with its own shape, not in the channel bar/`#n-24` (§2.8, §8.2) |
| R18 | Channel width unknown → nebula looks 'measured' | misreading | 20 MHz assumption visible in legend, channel bar, tooltip, detail; `assumed` in `channels()` (§8.2) |
| R19 | Interference nebula read as alarm/band | misinterpretation | `render.nebula` neutral, never `status.*`/`band.*`; legend row 'derived' (§7.0, §8.2) |
| R20 | Numbers in status/data colour | contrast unproven | numbers in `ink.*`, status as swatch/glyph beside them (§7.0, §8.4, §9.5) |
| R21 | Red↔green under deuteranopia | alarm invisible | alarm always as shape (gap ring) + '!' + label; red is an extra (§7.3) |
| R22 | Security level and hidden at the same time | rings collide | hidden ring at r + 10 `[4,4]`, security ring at r + 4 (`ENCODING`) |
| R23 | Reduced motion half implemented | barrier | one central toggle feeds camera, particles, breathing, flicker, blinking, travelling dots, probe arcs, intro, easing (§0, §5.8, §7) |
| R24 | Fonts offline / different metrics | label grid wrong | embedded font + system stacks, `measureText` cache per font, grid with measured widths (§1.1, §6.6) |
| R25 | Logon blocks or starts several times | waiting time | only at theme start, once per session and theme ID, skippable, the sky runs behind it, `?intro=0`, off under reduced motion (§7.3) |
| R26 | Theme switch with old sprites/particles/trails | remnants of the old theme | `applyTheme` empties the sprite cache, pool, measure cache and `#sky`; the sprite key contains the theme ID (§3.3, §6.3) |
| R27 | Label flood | stars covered, most expensive HUD item | top N + grid + alternative positions, hard budget `RENDER.maxText`, baked counters/glyphs, hidden without label (§6.3, §6.6) |
| R28 | Particle pool grows with many APs | too many rects, neon | global cap proportional, clients without particles, small grains with low alpha (§7.2) |
| R29 | Camera tween vs. drag vs. auto-rotation | judder | drag aborts the tween and sets `ramp 0`; the tween writes target and actual; rotation only when `tween === null` (§5.2, §5.3) |
| R30 | 2D hit test/layout drifts through the projection path | pins/tooltips off target | no projection at `tS = 0`; bit-identical after the return (§5.2) |
| R31 | 2D pan / 3D re-targeting loses the ring reference | observer no longer in the middle | no 2D pan, zoom only about the observer, rings scale with `zoom2d`; 3D target stays `[0,0,0]` (§5.3, §5.6) |
| R32 | 2D↔3D blend during spreading/aggregation | jumping positions | spreading and rebuild pause during the blend; dolly zoom via `ln F` (§5.7) |
| R33 | Tab switch: `dt` jump, frozen persistence frame | jumps after the return | `dt ≤ dtMax`, `visibilitychange` → `lastT = 0`, clear `#sky`, restart curves (§6.1) |
| R34 | Idle skip leaves screenshots stale / `fps` misleading when idle | wrong measurement | `STARCHORUS.frame()`, `stats().fps` counts rAF ticks, `measure().renderedFrames` separate (§6.8, §10) |
| R35 | Headless measurement ≠ target hardware | threshold too strict/lax | `perf().drawCalls` as primary criterion alongside fps (§11) |
| R36 | XSS via SSID/vendor/note/label | script execution | exactly two `innerHTML` paths (tooltip, `#source-desc`) from fixed templates with `esc()` for every data value; otherwise `textContent`; control characters removed, lengths capped (§2.8, §9.5) |
| R37 | `OffscreenCanvas`/`PointerEvent` missing | sprite baking/input fails | fallback `document.createElement("canvas")`; no `ctx.filter` (§6.3) |
| R38 | The wireframe signature is invisible without association data | theme looks empty | probe arcs client → core on appearance (capped) and on hover/lock, worded passively (§7.3) |
| R39 | Motion metaphors suggest active scanning | loss of trust | no radar sweep; travelling dot AP → client or client → core (heard probe); permanent passivity notices in masthead, legend, logon, paste text (§0, §9.4, §9.5) |
| R40 | Collector fields missing | empty columns, wrong heuristic | display '—', PHY only with '≈' from `rate`; the collector emits fields only when they have a value (§8.3) |
| R41 | Sprite memory (tiers × colours × variants × themes) | memory pressure | LRU cap `spriteCap`, fixed tier table, invalidation on theme/DPR, `stats().spriteBytes` (§6.3) |
| R42 | The draw lists drift from the maps | zombie drawings | a node leaves its map in the same step it finishes fading (`stepNodes`: alpha < 0.02, target 0); `S.apOrder`/`S.clientOrder` are rebuilt on every ingest (§4.0, §5.5) |
| R43 | The poll overwrites a loaded file | confusion | deliberately so (contract); the source panel names the source unambiguously (§9.9) |
| R44 | Allocations per hover with many nodes | GC judder | `canvas#tip-spark`/`#detail-spark` persistent, sparkline rebuilt only on hover change/ingest (§8.1) |
| R45 | Poll race in tests | flaky evals | `?poll=0` for every `load()` eval; without the parameter §9.9 point 1 applies unchanged (§2.7, §11.0) |
| R46 | Theme values in the layout | layout differs per theme | `basePxMax` as the only layout size; `ap.basePx` only for hit test/label/drawing (§4.1, §4.7) |
| R47 | Exponential easings never end exactly | determinism unattainable | snap rule in UTIL, blend snap → `tS` exactly 0/1, `settle()` sets display = layout, API rounds to 1e-3 (§1.3, §4.2, §5.7, §10) |
| R48 | Movement of free clients creates overlaps | clumps, covered stars | no individual drift; only the rigid sky rotation (§4.2a) |
| R49 | The Scope's angle is read as a direction to the device | a wrong idea of where a network is | a lane is a band, never a bearing; the captions 'lanes = band, channel / not direction' and 'arcs = signal (dBm) / not range' sit in the foot; no word of direction anywhere in the Scope; the radius is the signal alone and never moves; tested by word list and by geometry (`tools/regress.d/scope.sh`, §9.8b) |

### 12.1 Risks of the analysis and theme functions

| # | Risk | Effect | Countermeasure |
|---|---|---|---|
| RK1 | A missing theme token is **silently** filled from another theme by the crash guard (for instance when a comment comments out the rest of a token line) | wrong look without an error | `validateThemes` counts (`themeErrors`), the global regression rows and `tools/regress.d/theme-schema.sh` flag it; never put a `//` comment in the middle of a token line |
| RK2 | The recording holds complete captures (including stations) in memory | personal data in working memory | memory only, ≤ 120 / 8 MB, never saved or exported, `recording()` counts only, 'Clear local data' deletes it (`SECURITY.md` §4) |
| RK3 | The beacon occupancy is an estimate (102.4 ms interval, 200 bytes, 1/6 Mbit/s) | false expectation | always 'est.' with the assumptions beside it; never called a measurement |
| RK4 | The device's `jq` has no regex functions | empty rows on the device | `jq-noregex.sh`/`display-selftest.sh`: static check, run under two jq builds byte-identical, self-test (`docs/device-notes.md` 2a) |
| RK5 | Device-dependent points (meaning of `time`/`packets`, `iw survey`, signal cadence for homing) have not been checked on the device | wrong display on the device | behind toggles, off by default; `docs/device-notes.md` §5a/§5b gives the one-liner for each question, every command needs approval |
| RK6 | Passivity claims could remain in place with an active source | false statement | all claims go through the copy tokens (D4); regression `tools/regress.d/source-truth.sh` |

## 13. Manual visual check (checklist)

In a normal Chrome window (local `http.server`), viewport 1440×900 and 800×480, in all three themes (`?theme=`), 2D and 3D
(`?view=`), with `demo`, `few-clients`, `many-clients` and `field-scale`.

- [ ] No console errors; `STARCHORUS.errors()` empty; hover and click respond immediately.
- [ ] Centre shows `center.label` (demo: 'YOU ARE HERE'); rings −40/−60/−80 labelled and readable.
- [ ] Counters match the fixture table in `tools/README.md`; the band filter changes the numbers, `title` shows the unfiltered one.
- [ ] Passivity notices (masthead tag, legend footer, logon) visible; on an ACTIVE capture, the ACTIVE line everywhere.
- [ ] Legend (§9.4): shapes as on the canvas; each row only while its mark is drawn.
- [ ] Tooltip and detail panel: all rows from §8.3/§9.3, '—' for missing fields, '≈' for estimated PHY.
- [ ] Theme switch (`T`) without reload: no remnants of the old theme, the stars stay put.
- [ ] `?` lists all keys from §9.6; `Tab` + `Space` toggles only the focused button; the sparkline is focusable via `Tab`.
- [ ] Free clients individually recognisable, none in the glow; associated ones with band ring and 60° arc; bubbles with readable counter, expandable.
- [ ] 3D: recognisable depth (elliptical rings, plumb lines, ground shadows), calm auto-rotation that stops on drag; 2D↔3D without a jump.
- [ ] WarGames: logon once per session, skippable; scanlines/vignette can be switched off with `C`; alarms strictly red with gap ring and '!'.
- [ ] Reduced motion (`?rm=1`): no rotation, no breathing, no drift, no flicker/blinking, no logon; controls fully functional.
- [ ] Scope (phone width, `?scope=1`): the fan stands on the Pager; the three captions are whole; one arc contracts per capture and new points appear as it passes; stale shows snow and the chip's word (§9.8b).

---

## 14. Guiding principles and decisions

### 14.1 Scope

This chapter gathers the binding rules and design decisions of the page, the collector and the Overview. Code comments
and regression rows cite the identifiers D1–D21, P1–P10 and U1–U4; where an older sentence in another section
departs from them, this chapter prevails. The regression checks that the chapter stays complete
(`tools/regress.d/doc-drift.sh`).

### 14.2 Hard rules

- **Passive.** Starchorus sends no frames: no deauth/disassoc, no probe requests or active scans, no
  association, no injection, no AP of its own, no active function of the AP service; on Bluetooth no inquiry, no scan request, no
  advertising, no connection: passive LE scan only (§14.6). The only marked exception is the
  opt-in `STARCHORUS_ALLOW_ACTIVE=1` (`source: "iw-scan-ACTIVE"`). No write or command path from the browser to the device (no
  POST/PUT, no CGI/handler file, no commands via query, no WebSocket/SSE/`sendBeacon`); the page's only network access is
  `fetch("starchorus.json…")`.
- **Device calls** (AP service CLI, the device's display commands, the two Bluetooth tools) only via the allowlists in §14.6.
- **JSON contract** stable; new fields additive and optional; old `starchorus.json` files keep working.
- **Determinism.** No `Math.random`; no `Date.now()` in data, freshness, event, render or debug logic; time comes from
  `generated`, animation from `S.clock`, tests use `setFixedTime`. The only wall clock is the viewer's clock `dtgTick` (D14);
  pure interaction timestamps (`PointerEvent.timeStamp`, §5.6) do not count.
- **Look only via tokens** carried by all three themes; `validateThemes()` checks symmetrically; no theme-ID check
  outside section 39, for any theme ID; no `[data-theme=…]` rules (structure runs via token attributes such as
  `data-banner`, `data-cursor`, `data-plaque`, `data-rm`).
- **Budgets.** `fillText` ≤ 30 (2D) / ≤ 24 (3D) in every theme, cursor included; chrome text only as DOM; `shadowBlur` only
  in {31, 33, 34}, `createRadialGradient` only in {31, 33, 37}; no hex literals in 31–35; token reads in 22–30 and 36 = 0;
  `spriteCache.size ≤ spriteCap`, no re-baking in an idle frame.
- **Privacy** (§14.5) and **law** (§14.7) are binding.

### 14.3 Decisions D1–D22

| # | Topic | Decision (core) |
|---|---|---|
| D1 | Freshness | `FRESH.tiersS = [60, 300, 900]`: T0 < 1 min · T1 < 5 min · T2 < 15 min · T3 on record · undated; for APs and stations, each from its **own** `last_seen` (`stats().fresh` counts APs, `stats().freshClients` stations); age = `generated − last_seen`; `last_seen ≤ 0` → undated, up to +300 s in the future → T0, beyond that undated, without `generated` everything is undated; undated looks like T0 but is counted and named; tiers that the collection window (`center.max_age`) makes unreachable are hidden; words and limits are provisional until the recon database's update cycle has been checked on the device |
| D2 | Events | state belongs to a source (`sourceKind` + label), a change of source resets it, the first capture of a source produces no arrivals/departures; one counter `S.captureSeq`; arrival/departure only from the set comparison of consecutive captures (never from `target`/`born`); `changedSeq` on DS channel, security class, SSID, band; RSSI jump ≥ 3 dB = change cue; 'New' lasts 3 captures; stations: arrival `node.isNew`, departure in `events.departedStations`, no station 'change'; the arrival arcs carry no identifiers (≤ 12), small numbers are shown in bands ('<5') |
| D3 | Liveness indicator | for poll-fed sources the poll time without a new `generated` (`S.staleMs`: the cadence's waits, one `POLL_MS` tick per poll by hand or live API load; a failed poll adds only its time); reset on a new `generated` or a change of source; stale from max(30 s, 2 × `center.interval` + 15 s), without an interval from 6 × 5 s as before; chip, masthead dot, badge, lamps and pill flip together; a server that has not answered the last three polls (`S.lostPolls`: network error, deadline, any status but 200; any 200 resets it) reads 'Offline' (WarGames 'Link down', Whitehall 'No link') in the same widgets and the stale styling from the stale threshold on (a 'Stale' of one or two polls first only when the outage began just before it), 'Stale' staying for a server that answers with an old capture, and the first answer ends it ('Live' on a new `generated`, otherwise 'Stale'); demo/recorded/none never stale; hooks `STARCHORUS.pollNow()` and `load(doc, label, {mode:'live'})`; masthead dot in all themes (steady = live, dimmed = stale); poll timeout 4 s; the poll cadence follows the observed capture spacing (§9.5) |
| D4 | Source | `sourceKind`: none · active (`/ACTIVE/i` in `doc.source`, takes precedence) · demo · live · recorded (paste/drop/API; the API may pass `{mode:'live'}`); all passivity claims via one copy-token group with the same keys in all themes; for `active` instead 'ACTIVE SCAN · the collector sent probe requests' |
| D5 | Selection/pin | selection = brightest neutral per theme; pin ≠ lock: notched arc in `ink.secondary` |
| D6 | Open/WEP | one `ENCODING` mark: ring with a 60° gap at NE ('!'); a filled area only as the ornament `status.alarmAura` |
| D7 | Identity | on the canvas only the shape in `ink.primary`; colours only in the detail panel next to the text; the key `hostile` and `starchorus.identity.v1` remain; no exercise 'X' |
| D8 | Clients | mandatory token `render.clientRandomizedMark`; band ring only for genuine association; the cross arm scales with the signal level; the client detail without 'Last seen' |
| D9 | Rings | theme-free, at −40/−60/−80 dBm (U2); ring strokes ≥ 3:1, ring labels ≥ 4.5:1; angles never labelled; spokes and dots = ornament; signal % = `round(100·rssiT(dBm))`; level words via copy token (`copy.signal`) |
| D10 | Legend | one builder, blocks Measured / Derived / Operator / Look; a row is visible exactly when its mark can be drawn; geometry row 'rings = received signal (dBm), not range · direction is not measured' |
| D11 | Aggregates | `skyStats` (Wilson 95 %, N ≥ 30, cells < 5 suppressed, no identifiers) and `crowding` 1–5 theme-free, in all themes and identical on the Overview; deviation marks on `#chanbar` in all themes; tokens only choose the voice (`copy.skyVoice`) |
| D12 | Chrome | uniform tokens `accent.toggleOn/toggleInk/toggleBorder`, `chrome.ink`, `chrome.bezel{color, widthPx, gapPx, bracketPx}`, `chrome.banner{show, fill, ink, rule}`; chrome never in band or alarm colours (data-bearing colours are read at draw time, not copied into chrome tokens) |
| D13 | Intro | `motion.introStyle` (coalesce/typed/none); session marker per theme ID; the logon types after the first poll or after 1 s at the latest; the mode line is computed only when typing starts |
| D14 | Clocks | the Whitehall clock is called 'viewer clock (UTC)' and is the only wall clock; capture time comes from `generated` |
| D15 | Layout | one theme-free edge-panel rule (`--chrome-top/--chrome-bot`); overlap area 0 at 1440×900, 1280×800, 1000×640 and 760×600, with and without `#detail`; the drawers share the legend box |
| D16 | Data strings | SSID, vendor, group key and `center.label` are never transformed (upper case only in the chrome) |
| D17 | Links, derived data | client–AP links and roaming dots neutral; derived overlays with theme-free dashing/hatching; the merge ring with its own pattern; no breathing on data-bearing alpha |
| D18 | Change cue | `render.changeCue` (glowPulse/bloomPulse/tick), visible in all themes; reduced motion: static mark for one capture |
| D19 | Ghosts | `S.ghosts` for APs and stations (≤ 40 each, capped separately), frozen, not in layout/labels/stats/hit test; baseline-gone (derived, dashed) and aged (measured, dimmed); without hop data (`channels[]`) never 'gone' |
| D20 | Names | the theme label 'WHITEHALL' is a descriptive street name (no coat of arms, no classification); no event motion without a change, the decorative sky rotation remains; skyStats reference and operator baseline kept separate; the optional field for frame clusters is called `alerts[]` |
| D21 | Phone mode | up to 720 px wide or a phone on its side (`?phone=1\|0`): the panels move into a status bar and a bottom sheet with three heights and one card at a time; nothing is duplicated (one chip, D4); the sky centres in the free rectangle; every tap target ≥ 44 px; the desktop above the bound is unchanged to the pixel; Hide panels (`U`) at every size, saved, the Whitehall disclaimer and the status pill stay (§9.8) |
| D22 | Scope | a phone-only fan view (§9.8b), named 'Scope': 60° from the Pager, lanes = bands (2.4 / 5 / 6 / stations, and Bluetooth while marks are heard) by channel or stable hash, radius = received signal (dBm); one arc contracts per capture, no sweep (R39), no sound, none under reduced motion; snow when the feed is not live; five-field number bar; captions 'lanes = band, channel / not direction', 'arcs = signal (dBm) / not range', 'RX only'; words per theme in `copy.scope`; off by default, `starchorus.ui.v1`, `?scope=1\|0`, key `Z`; at most 12,000 bytes of the page (owner, 19 Oct 2026; the fifth lane's bytes are the radio pair's) |

### 14.4 Colour roles (validator `tools/check-colors.py`)

ΔE = OKLab × 100 after alpha compositing over `surface.base`; C = OKLCH chroma, L = OKLCH lightness.

| Role | Token paths | Rule |
|---|---|---|
| band | `band.{2.4,5,6}.core` | hue 2.4 GHz 140–190°, 5 GHz 220–265°, 6 GHz 285–315°; the three data bands pairwise ΔE ≥ 15 |
| unknown | `band.unknown.core` | C < 0.05; ΔE ≥ 10 from `status.ringNeutral` and `render.bubbleStroke` |
| alarm | `status.alarm` | ΔE ≥ 15 from band, selection, pin, chrome, aggregate |
| alert | `status.alert` | hue 15–40° (red); ΔE ≥ 15 from the three band cores and from selection; it may equal the alarm colour (Whitehall's does) |
| identity (canvas) | identity frame | = `ink.primary` (shape only) |
| selection | `accent.selection`, `accent.focusRing` | C < 0.05, L ≥ 0.85 |
| chrome | `chrome.*`, `accent.toggle*` | ΔE ≥ 15 from band and alarm |
| aggregate | `render.bubbleStroke`, `line.edge.color`, `render.nebula`, `line.device` | C < 0.05 |
| ornament | `particles.color`, `glow.color`, `accent.flare`, `render.starfield.color`, `look.clock` (the DOM dial only) | ΔE ≥ 8 from alarm; never a data-bearing colour |

The regression (`tools/regress.d/ap-models.sh`) runs the validator over the token sets of the three themes and proves with
negative controls (6 GHz on yellow, selection on terminal green or the alarm colour, tinted aggregate stroke, chrome in a band colour)
that it fires.

**Scope of `CONTRAST_PAIRS`.** The list is the **test set**, not the totality of all token combinations: every
listed pair meets its minimum in all three themes (text ≥ 4.5, rings/marks ≥ 3; §7.0a). Deliberately not listed and
therefore unchecked (comment above `CONTRAST_PAIRS`): `ink.onFill` on band fills (`.btn.b*.on`; Foundation 6 GHz works out
at 3.82:1) and on `accent.selection` (`.btn.toggle.on`), the light banner text on a dark red ground and the
`ENCODING.identity` colours on `.idbtn` (detail panel only). Separately, the CRT vignette lies over the panels and lowers
text in the screen corners below the computed token ratio (measured `#leg-rx` 3.34:1, `#src-center` 4.18:1).

### 14.5 Privacy P1–P10 (binding)

- **P1** Stations are observed objects like APs: freshness, history, arrival/departure, baseline and ghosts apply to them too;
  export, report and recording include them, limited by P6 and the caps in P8. Small numbers of new stations are
  shown in bands ('<5').
- **P2** Identity, notes and homing accept only **observed** identifiers – AP or station, present or in the baseline
  (`observed()`; rejection 'not observed'). The watchlist matches only SSID text, never an identifier.
- **P3** A probable phone hotspot (`n.mobile`: locally administered BSSID outside every G1 cluster,
  hotspot-typical SSID per `MOBILE_SSID_RE`, or IBSS) produces no event, no baseline, no watchlist hit, no
  observation; it appears only as the count 'mobile hotspots: n'.
- **P4** Protected SSIDs = SSIDs of APs the operator has marked as friend (not freely enterable); watchlist SSIDs match only
  `aps[].ssid`; the count of probes for a protected SSID is banded only (0 / <5 / ≥5), only after 10 minutes of
  capture time, without timestamps and without identifiers, and is not exported.
- **P5** Association counts from the AP service are neither read nor shown; should such a field be added, the rule is: display
  banded (0 / '<5' / value from 5), never in history, log, baseline, events, recording or export.
- **P6** Exports, reports and PNG contain only values from frames addressed to all (beacons, probe requests/
  responses) and the received station → AP association; values from directed frames (such as clusters in `alerts[]`) stay
  local and live (DE TDDDG §5, UK WTA 2006 s48, US 18 USC 2511; `SECURITY.md` lists this as legally sensitive).
- **P7** Wildcard rules and bulk assignment only for friend/neutral (a rule fixes at least the three OUI octets);
  suspect only individually per observed identifier; wildcard hits appear as 'rule-matched'.
- **P8** Every persistent store has a cap (baseline ≤ 500 APs and ≤ 2000 stations; recordings in memory only);
  'Clear local data' and `STARCHORUS.clearLocalData()` delete all `starchorus.*` keys; `SECURITY.md` §4 lists each one.
- **P9** Fixtures and self-tests are synthetic (`tools/gen-testdata.py --seed`, constructed bitmasks, stub outputs);
  no extracts of the recon database, raw output of the AP service CLI or screenshots of real environments in the repo; device results
  only as schema/counts with placeholders in `docs/device-notes.md`.
- **P10** Neutral language, machine-checked: visible texts (DOM of all themes after all fixtures, LOG of both
  `starchorus-display.sh`, export/report) do not match
  `/\b(evil[ -]?twin|rogue|attack(er)?|threat|intru(der|sion)|malicious|spoof(ed|ing)?|karma|bandit|target|deauth flood)\b/i`
  (exceptions: the storage key `hostile`, the operator label 'Suspect'). Checked permanently in
  `tools/regress.d/neutral-language.sh`.

### 14.6 Device calls: allowlist (binding)

- Exactly one function `apcli_ro <id>` in `starchorus-collect.sh` with four literal command lines for three read-only
  commands of the AP service CLI: `recon_aps` (the recon list of APs as JSON) and `recon_devices` (the APs and stations as JSON;
  the device has no `RECON CLIENTS`), the latter also as `recon_devices_recent`, the same list newest first and cut at 400
  entries, and `recon_channels` (`RECON CHANNELS format=json`: the AP service's frame count per frequency, which the collector reads as
  relative channel activity, never as devices, on the first cycle and then every second one: the AP service counts over a window of 20 to 30 s, so the cycle in between
  publishes the answer of the cycle before, and an answer that gave nothing usable is called for again on the next cycle). The id `present` runs no command, it only asks whether the CLI exists. No `eval`, no
  command name from a variable, no argument (the lines carry only the optional prefix `timeout 10`). The function runs only with
  `STARCHORUS_APCLI_RO=1` (default off), with one exception: `recon_channels` is gated on `STARCHORUS_TRAFFIC=1` alone (one command, one
  opt-in), so switching Traffic on does not make `recon_aps`, `recon_devices` or `recon_devices_recent` callable, and `STARCHORUS_APCLI_RO=1`
  does not make `recon_channels` callable. The command exits 1 while printing valid JSON, so its answer is judged by its text. The one caller
  of the three lists is the opt-in source `STARCHORUS_SOURCE=pineap` (by default the one bounded `recon_devices_recent`; with
  `STARCHORUS_PINEAP_CALLS=full` `recon_aps` and `recon_devices`), which switches the flag on for itself. The self-test checks
  the rejection rules with a logging stub (permitted IDs → exactly the expected line; forbidden inputs, the former `monitor` id
  among them, extra arguments, and each id without its own switch → exit ≠ 0 without a stub call) and the source with a stub that prints fixture JSON.
  The three recon commands are verified on the device (`docs/device-notes.md`, V-3 and §6a: the transmit counters stayed the same); for
  `RECON CHANNELS` that holds for single calls and for ten minutes of calls every cycle (the V-3 extension, 18 October 2026, `docs/device-notes.md` §6a), which is twice the rate of the calls made now.
- Bluetooth: exactly one function, `bt_begin`, starts a Bluetooth tool, and it does so with two literal lines, each pinned to the
  controller `hci0` (a hot-plugged adapter can never take the scan): `btmon -i hci0` first, and `hcitool -i hci0 lescan --passive
  --duplicates` only once `btmon` holds its monitor socket, both under `timeout -s INT` as dead-man timers. No tool name comes from a
  variable and no argument from outside (the seconds are validated integers, the paths fixed). The window is opt-in
  (`STARCHORUS_BLUETOOTH=1`, default off) and lasts 5 s per cycle by default (`STARCHORUS_BT_WINDOW`, 5 to 15). A passive scan sends no
  scan request; the three HCI commands of a window (scan parameters, enable, disable) pass from the host to the controller inside the
  device and are not radio transmissions
  (device-notes §2b). Each tool is tracked by two pids, the `timeout` wrapper and the tool itself, and every signal goes by pid to the tool,
  after `bt_is` has checked by command name that the pid still runs it: SIGINT to `hcitool`, repeated, then at most one SIGTERM and **never
  SIGKILL** (it ends the scan only from its SIGINT handler); `btmon` may be escalated, as it holds no controller state; a wrapper is signalled
  only after its tool is gone; the start-up sweep sends SIGINT only. The collector never calls `hciconfig`, `btmgmt`, `bluetoothctl` or any
  other tool of the stack and never changes the controller's state: a scan that was left running is detected (a missing
  `Scanning: Disabled` block, or the next window failing to set its parameters), logged and left to the owner (device-notes §2b). The
  runtime witness reads it back each cycle: a window counts only when `btmon`'s text shows the collector's own `LE Set Scan Parameters` block with
  `Type: Passive` before the first report, the scan enabled, no `Type: Active` block, no extended scan command or report and frame numbers that
  increase; otherwise it is void and the layer carries its held records. A name is at most 29 bytes (a legacy advertisement holds 31, less two
  header bytes), but the Apple manufacturer decoder of BlueZ 5.72 prints its bytes as text without bounding them to the advertisement (A10 of
  device-notes §2b), so a line the air writes can run on to about 36 bytes. The grammar therefore acts only on lines that no such text reaches
  (headers, over 40 bytes and not starting with a blank; `Event type`, at least 38) or in positions a forged line cannot take; a forged `Address type`
  or `Address` line can only drop the report of its own sender, by the order of the labels. The length alone does not keep a header out of a name: a
  29-byte name that holds `]: < HCI Event: plen 1 #0 1.0` makes a 54-byte line which a test that finds the marker anywhere would count as a header and
  as frame 0, and the window would be void by order, so the main rule asks for a first byte other than a blank before it asks whether a line is a header.
  An advertiser cannot forge the witness. The witness checks what was asked of the controller; an observation of the air itself would need a
  separate sniffer. The window is stopped within about 3 s of a signal (the first SIGINT to a scan younger than a second waits for its first
  second, since a scan that has not installed its handler would die of it with the controller still scanning), and a collector killed with
  SIGKILL leaves its tools to their dead-man timers and to the next start's sweep.
- The receiver is never held on a channel or a BSSID; there is no radio-controlling command in the code.
- `starchorus-display.sh` uses only the device's display commands `LOG`, `LIST_PICKER`, `ERROR_DIALOG` and
  `WAIT_FOR_INPUT` (`docs/device-notes.md` §7). The display keeps a key reader running from its first screen on: a background process that runs a `WAIT_FOR_INPUT`, without a time limit,
  takes its answer, appends it to a queue and opens the next wait at once, so a press during `Reading...` is kept, in order (a press made while
  no wait is open is lost: `docs/device-notes.md` §7, M1). A B, Left or Right ends the draw that is running (nothing more is printed, the `jq` that
  is running is ended); an A, Up or Down lets it finish, and an A pressed during it is answered by it. The reader ends itself on a B, so no wait
  is open while the list of screens, a wait of its own, shows; a press that falls between one wait ending and the next being registered, or
  between a B and the list, is still lost. The queue is an append-only file in a private temporary directory, read by line number, which also
  holds the reader's counts (replaced by a rename, never rewritten in place), the pid of its wait and the output of the screen's `jq` and which the display
  removes when it ends; an exit trap ends the reader and its wait and waits for the reader (about 2 s at most, about 10 s where `sleep` has no fractions) before it removes the directory, ignoring a further TERM, INT or HUP for that time. A reader that has gone without its mark
  (killed, or with no room to write it) is found by its pid and ends the Overview with 'Overview could not read a key.'. It sends a signal only to processes it started itself: the reader, its wait, its `jq` (and what
  `timeout` started for it) and the watcher of that `jq`.
  Nothing on the display redraws by itself (between draws the shell naps 0.2 s at a time and looks at two small files); no UI command is ever put under `timeout` (only the Overview's own `jq` is, where
  `timeout` exists). No upload, no location query.
- Static check (`tools/passivity-check.sh`, with mutation probe `tools/passivity-mutate.sh`): calls of the AP service CLI
  and of the device's transmitting or upload commands, across the collector, both `starchorus-display.sh`, both `payload.sh`
  and `library/**`, hit only lines of the allowlist function. Besides the AP service's own words, the firmware's other active or
  outward commands are denied by name (the full list is `SEC6_RE`) and by the prefixes `WIFI_PCAP_`, `OPENVPN_`, `WIREGUARD_`, `AUTOSSH_`,
  `DNSSPOOF_` and `PINEAPPLE_`, and the Bluetooth verbs that transmit are denied by name as well (`hcitool` with `scan`, `inq`, `cc`, `lecc`,
  `leadv` or `cmd`, `l2ping`, `btmgmt`, `gatttool`, `bluetoothctl scan on`, `hciconfig` with anything but `-a`): defence in depth only. The list of
  transmitting tools (`TX_WORDS`) also names, each as an alternative of its own, `aireplay-ng`, `mdk3`, `mdk4`, `hostapd`, `hostapd_cli`, `airbase-ng`, `hcxdumptool`,
  `wpa_supplicant`, `wpa_cli`, `nmcli`, `iwlist`, `iwconfig`, `airmon-ng`, `besside-ng`, `reaver`, `bully`, `nmap`, `hping3`, `arping`, `mausezahn`, `tcpreplay` and `bettercap`, read wherever they stand in
  a code line (a log text too: a text names the tool by its role, or spells the product Nmap with a capital). Three lines of the collector must name one and are pinned byte
  for byte, each once, with file and function (the same comparison as for the pinned lists below): the two lines of the last resort of `create_monitor` (`if have airmon-ng` and
  `airmon-ng start "$base"`, the 0.1 fallback when `iw phy ... interface add` failed, with `STARCHORUS_CREATE_MON` on: it changes an interface and sends nothing) and the path of
  the OUI file that comes with Nmap in `find_oui_file`, which is read and never run; an edited line, a copy in another place and a pin without a line are red. The
  Bluetooth stack is denied **by tool**, not by verb: `BT_WORDS` names every program and path of BlueZ that the project knows of or that a
  contributor might reach for (`hcitool`, `btmon`, `hciconfig`, `bluetoothctl`, `btmgmt`, `bluetoothd`, `gatttool`, `l2ping`, `l2test`,
  `rctest`, `sdptool`, `rfcomm`, `hcidump`, `btattach`, `bccmd`, `bdaddr`, `hciattach`, `hid2hci`, `btgatt-client`, `btgatt-server`, `obexd`,
  `ciptool`, `avinfo`, `isotest`, `meshctl`, `mesh-cfgclient`, `bluetooth-meshd`, `btproxy`, `bluemoon`, `mpris-proxy`, `hex2hcd`, `obexctl`, `bluetooth-player`, `btinfo`, `scotest`, `hcieventmask`, the bus tools `dbus-send`, `busctl` and `gdbus`
  and the service name `org.bluez`, which together are the D-Bus route to a discovery, `rfkill`, the Bluetooth init script and the kernel's debug
  directory; the device's own listing of its BlueZ files is not taken yet, and V-13 adds every name it finds), read on the normal form of a line (the
  quotes and backslashes removed, adjacent string literals joined, so a name split by them is still the name), and a word
  of the family may stand only inside the functions of `BT_FUNCS` (`bt_begin`, `bt_end`, `bt_busy`, `bt_sweep`, `bt_stub`, `bt_selftest`), in code,
  in a string or in a log text alike. So `hciconfig` with any argument (or none), `bluetoothctl scan le`, `scan bredr`, `advertise`, `connect`
  and `pair`, `sdptool`, `rfcomm`, `btgatt-client`, `l2test`, `rctest`, `gatttool` and `btmgmt` are denied everywhere, whatever the verb or the
  option order; the only exceptions are the two literal lines of `bt_begin` and read-only reads of `/sys/class/bluetooth`, which holds no word of
  the family. Inside the allowlist: in `bt_begin` every line that holds a tool word or `timeout` is one of seven enumerated lines (the two
  literals once each, the three `have` tests, the two `bt_kid` lookups); in the other functions, the test code apart, a tool word stands only as the
  last argument of `bt_is "$VAR" WORD` or `bt_kid "$VAR" WORD`; in every one of them no command wrapper (`eval`, `sh -c`, `ash -c`, `busybox`,
  `env`, `xargs`, `nohup`, `setsid`, `nice`, `start-stop-daemon`, `exec`, `source`, `time`, the dot command, `command` other than `command -v`), no
  command word that is a `$` expansion (a variable, `$( )` or a backtick expression, quoted or not), no glob in a command word and, outside
  `bt_begin`, no `timeout`; and in `bt_stub` and `bt_selftest` no tool as a command. A name that is only built when a line runs is looked for
  twice: inside those functions by the rule above, and in every shell file of the scope by two rows of their own (`§14.6d command words from an
  expansion` and `§14.6e command names from a glob, find -exec, xargs or alias`, mode `dyn` of the awk of the wrapper rows, one pass with two verdicts). That row reads the raw text of every code line, with quotes nested inside `$( )`, a quote or a
  `$( )` that goes on over several lines and a trailing backslash joining two lines, and lists each simple command whose command word holds an
  expansion: `$name`, `${...}`, `$( )` or a backtick expression, quoted or not, a word that merely starts with a path (`/usr/bin/hci$x`), behind
  `NAME=value` and redirections, and behind the wrapper words `exec`, `command` (but not `command -v`), `env`, `nice`, `nohup`, `setsid`, `time`,
  `xargs`, `busybox`, `timeout [-s SIG] N`, `sudo` and `stdbuf` (a quoted name does not hide a wrapper). The state of the reader also knows `${ }`, inside which blanks, parentheses and glob
  characters are text. The lines that stand today are a pinned list, byte for byte with the function they stand
  in (`-` outside every function): the `nice` prefix of the launchers in both `payload.sh`, the fixture builder `$rsq` of the collector's self-test, the
  Overview's `screen_$1` dispatch (both copies), the page server's `$NC` and `$HANDLER`, the stop call of the payload, and the four `$ap_to _pineap` lines of
  `apcli_ro` (taken from the pins below). A line that is not on the list, a listed line that changed and a listed line that is gone are red, so every
  new command word of this kind is read and signed off on purpose. The second row (§14.6e) reads the same text and is red for a command word that holds an
  unquoted glob character (`*`, `?`, `[`: `/usr/bin/hc?tool`, `/usr/bin/hci[t]ool`, `/usr/sbin/i[w]`; `[` and `[[` alone are the test), for `find` with `-exec`, `-execdir`, `-ok` or `-okdir`
  (its command is whatever `find` turns up), for an `xargs` whose command is its own replacement string (`-I{} {}`, `-I X X`, `-i`, `--replace=`: the command comes from stdin)
  or is missing (it then runs `echo` over what it reads), and for any `alias` definition. It compares with a pinned list in the same way; nothing of that kind stands in the
  scope today, so the list is empty and a first line is a new one. A glob in a for-list, in a case pattern or as an argument is no command word. **What these rows do not read:** a
  glob that is only handed on as an argument (`ln -s /usr/bin/hc?tool x`, then `x ...`; `cp`), a program text that is built and then run (`eval`, `sh -c`, a pipe into `sh`, an awk
  `system()`, a `jq` program given a built string, `. file`), a name made by a function the script defines, and a wrapper behind options these rows do not know; for those the static
  check says nothing (the tool names themselves are still red outside the allowlist, wherever they stand in the text), and the guarantee rests on review. The run-time witness (the
  Bluetooth paragraph above: what was asked of the controller is read back from the monitor each window) covers only the collector's own window, so it cannot vouch for a scan that
  was started outside one. The mutation probe pins that limit: a built name (`zz_a=hci; zz_b=tool; "$zz_a$zz_b" -i hci0 lescan`) outside `BT_FUNCS` is red, and an `eval`
  or an awk `system()` over a built string, a glob that is only handed to `ln` and a built string piped into `sh` are controls that stay green, so a change in what the rows read shows up as a change in the controls. The five
  `_pineap` lines of `apcli_ro` are pinned byte for byte, each once, so a sixth line, a changed argument or a command name from a variable is
  red. A device check per command needs approval per command; the yardstick is that the transmit counters of the monitor interfaces are the same
  before and after.

- The alert log (`STARCHORUS_ALERTS`, default 1; nothing is read unless the file exists) and its companion file. **Companion:** `library/user/reconnaissance/starchorus/alert-deauth.sh`, a
  bash file with the Hak5 header (Title, Description, Author, Version) that is not named `payload.sh`, so that the library's UpdatePayloads takes it for no payload of its own; the Hak5 package carries it
  beside `payload.sh`; the Settings row 'Alerts' of the payload installs it (below), or the owner copies it by hand to `/root/payloads/alerts/deauth_flood_detected/starchorus/payload.sh` and makes it executable (README, Alerts).
  The firmware runs it once per event of its alert `deauth_flood_detected` and hands the event over in environment variables only. **It reads** `_ALERT_DENIAL_AP_MAC_ADDRESS`,
  `_ALERT_DENIAL_SOURCE_MAC_ADDRESS`, `_ALERT_DENIAL_DESTINATION_MAC_ADDRESS`, `_ALERT_DENIAL_CLIENT_MAC_ADDRESS`, `STARCHORUS_ALERT_DIR` (default `/root/loot/starchorus-alerts`, a directory of its own outside the one the page server serves; the firmware's run of the file sets nothing, so the installed copy uses the default, and the variable is an override for the tests) and the clock; the
  alert name and the message text, which the firmware also sets, are not used (the message is free text, and P9 keeps the log to times and addresses). **It writes** one line to `$STARCHORUS_ALERT_DIR/alerts.log`,
  `EPOCH<TAB>deauth<TAB>AP<TAB>SOURCE<TAB>DESTINATION<TAB>CLIENT`: the four addresses in lower case, each `-` when it is unset or is not six pairs of hex digits, the file private (mode 600), kept to its last 2,000
  lines (`tail` into `alerts.log.<pid>`, then `mv`), the append and the cut under `flock -x` on `alerts.lock` in the same directory (without `flock`, or when its file cannot be opened, they run unlocked). The commands it
  starts are `date`, `tr`, `wc`, `tail`, `mv`, `mkdir`, `rm` and `flock`; it calls no UI command (`ALERT`, `LOG`, `VIBRATE`, `LED`, `RINGTONE` are the owner's choice and are not made), nothing of the AP service,
  and no network, and it exits 0 whatever happens. It is in the shell scope of the static check (every file under `library/` that is not Markdown), with the same rows as the other scripts.
  **Install (the payload's Settings row 'Alerts').** `library/user/reconnaissance/starchorus/payload.sh` shows the row after 'Bluetooth': ON while `payload.sh` is in `/root/payloads/alerts/deauth_flood_detected/starchorus`, OFF while it is not
  (the tree is `STARCHORUS_ALERT_TREE` in tests only), and 'OFF (firmware)' while only `DISABLED.starchorus` is there (the firmware's rename of that directory when the alert is switched off on its Alerts page; 22 characters, and the lock's label wins when both
  apply): a press then installs nothing and shows P3, 'Switched off on the / firmware Alerts page. / Switch it on there.', because a second, enabled copy would run beside the one the owner switched off. A press asks (CONFIRMATION_DIALOG) and then runs the README's steps, `mkdir -p`, `cp` of the `alert-deauth.sh` found beside the payload (`_PAYLOAD_HOME`, the payload's own directory, the install
  paths) to `payload.sh.tmp`, `chmod +x`, and `mv -f` to `payload.sh`, so that the firmware never finds half a script; a failed step removes the temporary file and, if it is empty, the directory. On an ON row the press asks and runs `rm -f` on that
  `payload.sh` and its temporary file and `rmdir` on that directory (empty only), and, when a stale `DISABLED.starchorus` copy is there too, `rm -f` on its `payload.sh` and `rmdir` on its directory (empty only), nothing else. The row writes one LOG line on success, ends in an error dialogue on failure and is
  `(locked)` while `STARCHORUS_ALERTS` is set to anything but 1 (the collector reads the log only for 1, so P2 says 'The collector ignores the alert log: STARCHORUS_ALERTS is not 1'); for 1 or unset it is free.
  It is the only place the payload writes outside its own directories and the only action it takes on the alert tree: it toggles no switch of the firmware; an alert placed in the tree may run at once (not yet measured), and switching it off stays with the firmware's Alerts page; no radio, network or controller command is added, and the plain paths
  (arguments, `STARCHORUS_PAYLOAD_PLAIN=1`) cannot reach it. `tools/regress.d/payload-ui.sh` (section 15c) pins every line of the payload that names the directory or its renamed twin.
  **Presentation, the Overview.** The summary (`screen_summary`) prints one red line after the open/WEP line when `alerts[]` names access points that the capture holds: `Many deauth/disassoc frames for 2 APs` (`1 AP` for one; at most 38 columns, for 20), from the one
  jq program of the screen (`alertaps` in JQLIB, a record `alaps`: no jq of its own, no regex). `alerts[]` is cut at 20 as the page cuts it, an entry counts when it is an object of type `deauth` with a numeric count above 0, its address is folded as
  the page folds one and counted once, and only an address that `aps[]` holds counts, and none that `center.own_bssids` names, because the page draws its note and its ring for an access point it knows and for no other, and not for its own transmitters. The page leaves out a third kind, a mobile hotspot
  (an SSID that names a phone, or an ad-hoc network, `MOBILE_SSID_RE`); the jq program reads no names for this count, so the Overview can count one access point that the page does not draw, and a numeric string as a count (`"9"`) is a number on the page and is skipped here, as for the other counts. The line is at most 40 columns, ASCII and neutral (the P10 words stay
  out), it is the only red line besides the open/WEP, jq-incomplete and no-new-scan lines (`tools/regress.d/display-parity.sh` pins its text, once, inside `alert_line`, with controls), no other screen marks an alerted access point, and it is drawn
  with the summary and never by itself. The report times, the counts per access point and the addresses are not shown there.
  **Presentation, the page.** An alerted access point gets a second ring in `drawStars` (section 34, 1,200 bytes of page at most): the alert colour of the theme (the token `THEME.status.alert`, red in all three: `#e5484d` in Foundation and Whitehall, `#ff3b3b` in WarGames; the alarm colour of Foundation is amber, which is also the open/WEP ring, so the alert
  has a token of its own, `--status-alert` in the CSS mirror, with a contrast pair in §7.0a and a colour role in §14.4), one and a half pixels wide, at `px + hidden.offsetPx + 1.5` (11.5, so from 10.75 to 12.25 beyond the star's edge), through the ring batch like the others. That is a band of its own: the radii already taken are the security ring at 4 (the outer circle of a double ring, WPA2 and WPA3 transition, at 7), the identity frame at 6, the new-plot mark at 9 (Whitehall), the hidden-SSID ring at 10, the selection ring at 13 (the pin mark at 13, or 18 when locked, the merged-ESS ring at 16), and the alert ring sits between the hidden-SSID ring and the selection ring, clear of the security rings and the identity frame, so that a WPA2 access point under alert still reads as a double ring plus one more. It does not sit clear of those two: the hidden-SSID ring ends at 10.5 (0.25 px inside the alert ring) and the selection ring begins at 12.25 (13 less half of 1.5), so the alert ring touches the selection ring of a locked access point and lies 0.25 px outside the dashed ring of a hidden one. The free band is 1.75 px wide; a ring that kept 0.5 px from both would be 0.75 px wide, too thin for the canvas rows to read at the flicker's low levels, so the contact is stated and not engineered away. `tools/regress.d/alerts.sh` (R12) computes the gaps from the page and is red for a ring that moves, until this sentence is read again. Which access points: those that `alerts[]` names and the page holds and notes
  (`alertNode`: `S.aps` has the address, it is no mobile hotspot and no own transmitter, the rule of the Observations note, and its band is not filtered off), at once, without the note's dwell of two captures; the ring is drawn only while the star is (`alphaDraw` above 0.02). The ring flickers in the theme's own idiom, taken from its
  cue token `render.changeCue` so that the flicker adds no cue table to the themes: `glowPulse` (Foundation) a slow smooth pulse of its alpha between 0.4 and 1 (about 0.5 Hz), `bloomPulse` (WarGames) a phosphor flicker, a seeded alpha in 0.3 to 1 that changes twice a second
  and differs per access point, `tick` (Whitehall) a chalk blink, its alpha switching between 0.4 and 1 every second; nothing steps more than twice a second (the rule of the CRT flicker, Layer 14). Under reduced motion the ring stands steady at full alpha; with `?fixed` it
  is a pure function of the frozen clock. The frame loop is asked for each step of the flicker, not for every frame: the draw notes the clock time of the ring's next step (`alAt`: the next half second for the seeded flicker and the chalk blink, every frame for Foundation's smooth pulse, never under reduced motion or with no ring drawn)
  and the frame loop (`tick`) renders one frame when no `?fixed` is set, the page is not paused, the clock has reached that time and nothing else asks for a frame, so that a sky that does not spin still shows the step, at two frames a second rather than sixty. That frame clears the canvas first and arms no phosphor fade: in WarGames with its persistence on (the default) an earlier version asked for the step through `wargamesAnimating`, which armed the 20-frame fade after every step and cost 22 frames a step, 44 a second (measured: 30 to 35 frames in 0.7 s against 1 or 2 now). The legend row `alert`
  (§9.4) exists exactly while such a ring can be drawn (`alertNode` over `alerts[]`: with the band filtered off the row goes with the ring). No ray from a source to a target: the source address of a report is whatever the frames claim and the page does not show it. `tools/regress.d/alerts.sh` reads the ring from the canvas in all three
  themes, in steps of the frozen clock, against the same sky without its alerts, with the token swapped, with own transmitters, and counts the frames the loop renders and the levels the ring takes (in WarGames with its persistence on as well, and in the Scope, where Foundation's pulse is held to the half second); planted copies of the page (ring at the old radius, no flicker, flicker under reduced motion, no frame request, a request every frame, a legend row that ignores the band filter, a step that arms the phosphor fade again, and in the Scope no frame request and Foundation's pulse asked for on every frame) each turn their own key red.
  **Differences from the design brief (0.2; the owner is to confirm the first).** The brief asked for an Overview line with the number of reports and the time of the last one (two access points, so many events, last heard so many seconds ago). The line gives the number of access points only: the owner is
  to say whether that is enough, since the report count of an access point is `n` and the time of its newest report `t` in `alerts[]`, so both could be shown. The brief also asked for a '!' on the strongest-networks line of an alerted access point; it is not drawn, because '!' on that screen already
  means open or WEP. In the Scope (§9.8b) the blip of an alerted access point carries the same ring, drawn by the `drawStars` that the Scope calls, and blinks in the same rhythm: the same step asks for the same single frame, and the reduced-motion rule is the same (steady, no frames). Foundation's smooth pulse is sampled at the half second there too (`alAt` is `0`, every frame, only outside the Scope), so that an alert costs the Scope two frames a second and never sixty; at rest, with no alert, it still draws none. The ring and the legend row show from the first capture that carries the report, while the Observations note waits for its dwell of two captures (the firmware's
  report is an event with a window of its own, 600 s by default, not a state that has to hold).
  **Collector:** with the switch on, `alerts_look` tests with builtins whether `$OUTDIR/alerts.log` is a readable regular non-empty file (so a Pager without it pays no process; a directory or a pipe, which `tail`
  would wait on for ever, is said once per episode and read as no file), the layers pass takes a snapshot of its last 256 KiB (mode 600, in `$TMPDIR_RAM`, removed after the cycle) and the one awk of the layers
  (`AWK_LAYERS`, now with a fourth input beside the Bluetooth records, the Traffic answer and the held records) writes `alerts[]` before `aps`: lines of the last `STARCHORUS_ALERT_WINDOW` seconds, grouped by AP,
  `n` the count and `t` the newest epoch, sorted by `t` descending and then by address, cut at 20. A line is skipped, and counted, when its epoch is not digits, its type is not `deauth`, its AP is not an address, or its
  epoch is more than 60 s ahead of the cycle's clock; a blank line is nothing; the skipped lines are said once per episode, like an unreadable file. No entry writes no key. The snapshot is the only copy of the log's
  addresses that the collector makes; its own log lines say how many lines were skipped and never what they held.
  **What the data cannot say.** There is no channel, no RSSI and no count of frames: the firmware hands over four addresses and nothing else, so `n` counts reports (how many times the firmware launched the companion,
  which may be once per burst or once per frame, unmeasured) and `t` is the time the companion ran, not the time of a frame. SOURCE is the address the frames claim; in a burst of such frames it is usually spoofed (a forged
  deauthentication typically claims the access point's own address as its sender; this is an inference from how such frames are made, not something measured here), so it is kept in the log, carried by no document and shown nowhere, and the page draws no line from a source to an access point: that would claim a geometry the data does
  not have. A client address in a report is the address the frames name, not proof that the client was disturbed. Whether the Pager's own deauth frames, sent by another payload, raise the firmware's alert is **unknown until
  measured** (`docs/device-notes.md` §5c, g8): until then an alert may be the owner's own test, and nothing in the log tells it apart. The counts stay local and live (P6).

### 14.7 Law (binding)

- **No film quotations or assets, no book/series texts or names, no film/series melodies.** Code comments
  describe the themes neutrally as styles.
- **No real classification or handling markings** (OFFICIAL, OFFICIAL-SENSITIVE, SECRET, TOP SECRET, NOFORN,
  UK EYES ONLY, RECIPIENTS ONLY, NOT PROTECTIVELY MARKED). The EXERCISE banner is a fictional framing; Starchorus is not a
  government system.
- **No crowns, coats of arms, roundels or insignia; no real organisations or places as UI identity** (COBR, PJHQ,
  Northwood, Bentley Priory, SIS/MI6, GCHQ, MOD, RAF, ROC, Cabinet Office, HMG, Home Office, GOV.UK). The theme label
  'WHITEHALL' remains (D20).
- **No proprietary fonts** (GDS Transport, Johnston, Rail Alphabet). Embedded is Overpass under the SIL OFL 1.1 as
  'Starchorus Sans' (`OFL.txt`); 'Frutiger' appears in the Whitehall stack only as a never-reached fallback behind it.
- **Audio:** own sounds only; `AudioContext` only after a user gesture; never speak an SSID or MAC.
- **Denylist.** Three lists, one line per entry, no comments, no blank lines:
  `tools/denylist.txt` – case-insensitive, substring (film quotations, game-menu titles, code words, names from the books,
  multi-part markings, organisation and font names; every entry ≥ 6 characters or containing a space/punctuation);
  `tools/denylist-words.txt` – case-insensitive, whole word (short names hidden inside ordinary words, the
  level names of the alarm scale, generic game titles); `tools/denylist-cs.txt` – case-sensitive, whole word (classifications and
  organisation abbreviations; this way 'OFFICIAL' does not hit 'RedHatOfficial' in the verbatim OFL notice). The word and cs lists run
  on the text without base64 `data:` URIs. Check `sh tools/denylist-check.sh` = 0 hits for `starchorus.html` and both
  `starchorus-display.sh`; this literally includes `grep -ciFf tools/denylist.txt <file>` = 0. `--extended` also
  checks the collector, payloads, `index.html`, `starchorus-serve.sh`, `tools/gen-testdata.py` and `tests/fixtures/*.json`. The
  documentation is exempt. Known gap: 'Home Office' is in none of the three lists and is therefore not checked.
  Runtime cross-check in the regression: the rendered text of all themes (`innerText` including CSS upper case, `[title]`, meta,
  logon, banner) and the LOG of both `starchorus-display.sh`.
- **Non-affiliation.** The theme names are style labels; Starchorus has no connection with the rights holders of
  works, organisations or authorities of the same name, is not a government system and bears no real classification.

### 14.8 Toggles, keys and storage of the analysis functions

| Function | `S.ui` | Default | Key | Button | Query | Persisted | Storage |
|---|---|---|---|---|---|---|---|
| Observations | `observations` | off | W | `t-obs` | `?obs=0/1` | yes | `starchorus.watch.v1` (watchlist, ≤ 20) |
| Inventory table | `inventory` | off | I | `t-inv` | `?inv=0/1` | yes | — |
| Baseline diff | `baselineDiff` | off | B | `t-baseline` (+ Set/Clear) | `?baseline=0/1` | yes | `starchorus.baseline.v1` (≤ 500 APs, ≤ 2000 stations) |
| Homing display | — (action, `S.homeOpen`) | — | F | — | — | no | memory only; sound off |
| Air quality · signal over time · recording/playback | `S.dx` (`air`\|`time`\|`rec`) | — | Q · J · H | `t-air` · `t-time` · `t-rec` (group 'Analyse') | — | no | memory only (recording ≤ 120 / 8 MB, long-term history ≤ 720, threshold) |
| Channel mode (Bars · Spectrum · Waterfall) | `S.chanMode` | bars | Y | `t-chan` in the channel bar | — | no | memory only |
| Library, notes, export | — | — | — | inventory, detail, 'Export' | — | — | `starchorus.library.v1` (≤ 20 rules), `starchorus.notes.v1` (≤ 200) |
| Hide panels (§9.8) | `panels` | on | U | `t-panels` (+ `panels-pill`) | `?panels=0/1` | yes | `starchorus.ui.v1` |
| Random clouds (§8.8a) | `random` (`cloud`\|`show`\|`hide`) | cloud | X | `t-random` (group 'View') | `?random=cloud/show/hide` | yes | `starchorus.ui.v1` |
| Scope (§9.8b; phone layout only) | `scope` | off | Z | `t-scope` (sheet row) | `?scope=1/0` | yes | `starchorus.ui.v1` |

`PERSIST_KEYS` holds names at index 0–2 (`theme`, `view`, `random`) and only booleans from index 3 onwards; a new toggle must also
update `getToggles`, `BTN_OF` (booleans only), §2.6/§2.7/§9.6 and `KEYS`. No letter is free now (Z is the Scope).

### 14.9 Design questions U1–U4

| # | Question | Answer | Effect |
|---|---|---|---|
| U1 | Whitehall as a fixed, north-up plotting table (sky rotation off there)? | **open** – until answered, 'no' applies | the sky rotation runs in Whitehall too |
| U2 | Rings at the device's signal thresholds −40/−60/−80? | yes | `LAYOUT.rings`, §9.9 item 12, four signal levels (D9) |
| U3 | Which window of the recon database does `STARCHORUS_MAX_AGE` read by default? | payload on the device: one hour (`3600`, cycle 30 s); collector run by hand: the whole database (`0`) | the device's CPU does not process the whole database on every pass, so the payload reads a one-hour window; within the window the page dims by freshness instead of discarding and hides unreachable tiers via `center.max_age` |
| U4 | 'Live' chip only while not stale, otherwise 'Stale' (or 'Offline' when the Pager has not answered the last three polls); buffer polls during playback? | yes | §9.5, §9.9 items 1 and 6, §8.13 |

### 14.10 Excluded and open

Excluded are new active paths (probe requests, FTM/RTT, ANQP/GAS), speed/connection tests, LAN discovery,
joining/captive portals, cloud upload/sync, WIPS containment/deauth, a hotspot of its own, active functions of the
AP service, any control of the device from the browser, payload capture, handshake/PMKID display, Zigbee, Bluetooth inquiry,
active LE scans, advertising, connections and GATT, fingerprinting/de-randomisation (Bluetooth addresses included: a rotating address is never
linked to another across a rotation), genuine spectrum analysis/direction finding, drone Remote ID. Anything device-dependent (semantics of `time`
in the recon database, `freq`, the fields of the AP service CLI, `iw survey`, 6 GHz, own BSSIDs, `packets`, the passive Bluetooth window, the unit
of `RECON CHANNELS`) is never treated as fact until checked on the device and stays behind toggles (default off); `docs/device-notes.md` lists the
open questions with the identifiers V-1 … V-13 from `tools/device-probe.sh` (V-13: the Bluetooth controller and tools, from files alone).

**Gate for the Bluetooth default.** The summary's APs line with the Bluetooth figure is at most 45 characters (three-digit counts, '256+'), and how many characters fit on one console
line of the Pager is measured only as 'at least 40' (`docs/device-notes.md`, M6; the 50-digit line and the line with the middle dot are not yet run). The fallback for a shorter line (the
figure leaves the summary, the hub row reads 'Bluetooth (23)') is not built. Until M6 has passed, the Bluetooth setting stays off by default and the release pass does not switch it on.

**Not in 0.2.0.** The radio pair was specified wider than the page's size ceiling allowed, and the integration cut it to fit (0.2 may grow to 625,000 bytes,
and the pair was held to the share of that which the rest of the release left it). What is in the code is what the README, SECURITY.md and CHANGELOG describe; these are specified and not
there, and no row proves them:

- a detail sheet for a Bluetooth mark (the member list, the 'addresses, not devices' note): a mark has a tooltip, a click selects nothing;
- the baked tag ('n · BT') on a folded mark: a folded mark has a dot, its count is in the tooltip and in the legend and counter;
- the `bt()` function of the test API: `stats().bluetooth` is the whole of it;
- the SITREP line for Bluetooth, and Bluetooth rows or columns in the CSV export (the CSV is the 0.1 table; the JSON export has `bluetooth` and
  `bluetooth_counts`);
- two of the three idioms of the traffic cue (a halo, a bloom): the cue is four short ticks round the dot in every theme;
- the Air drawer's activity line, the channel tooltip's activity line and the title of the whisker;
- the fade of a revealed name (§8.5 above: there never was one in the code; a name now simply appears).

What is in: the layer with its marks and key `4`, the legend row and its geometry clause, the counter 'BT addresses' with its dash for a void
window, the activity whiskers, the cue on stations, the frame rate in a station's detail, the JSON export, the Overview's figure, screen and
bars, the Scope's fifth lane (§9.8b: marks only, a tap picks one, no sheet) and the payload's two rows. Whether to cut the rest of the layer into 0.2.1 as the cut order of the design says, or to keep it as it is, is the
owner's decision (design question Q7); this list says what keeping it means.

**Where the code differs from the specification** (the specification is not rewritten here; the code is what the other documents describe):

- *The Bluetooth screen's 'Last scan' line.* Specification §4.2 draws `Last scan 12:04:31 (42 s ago)` as a line of that screen. It is the frame that ends every draw of every screen (`stamp`, called by `frame`
  after `render`): the time of the capture's `generated` in UTC and its age, replaced by the red 'No new scan for N min.' when the capture is more than three intervals old. It dates the capture,
  not a Bluetooth window of its own, and `--once` prints a screen without its frame. The Bluetooth screen of the radio-pair fixture is held to end with it in `display-selftest` (S16); the screen
  itself is ten lines at most, so with the frame's two it is twelve.
- *A void window.* The specification ends the count line with ' - no valid scan now' when that fits in 40 columns, else lets the 'Last scan' line say it. The screen has a line of its own at the end,
  'No valid scan now; showing held records.', and takes one company line for it; the ACTIVE claim takes one as well, so a screen has seven company lines, six under either and five under both
  (`display-parity` and the self-test of the display script hold the cap on a capture of eleven companies).
- *The cut of a company name.* The specification's filter cuts a name at 23 characters; the screen cuts at 22, so that a three-digit signal and a three-digit count make 40 columns and not 41.
- *The header of `btmon`.* Specification §2.4 and the row A1 of its appendix still show `#n [hci0] t`. `btmon -i hci0` prints no tag (`> HCI Event: LE Meta Event (0x3e) plen 29   #5 1.546345`, the device
  measurement A1 of 17 October), and the collector's reader accepts both shapes; only the specification's wording is out of date.
