// ==== 20 CONFIG ====
const LAYOUT = {
  rssiMin: -90, rssiMax: -30, rings: [-40, -60, -80],   // D9/U2: the device's own thresholds (its signal.json); they bound the four signal levels
  innerPx: 96, innerMinPx: 64, innerFrac: 0.22, outerFrac: 0.92,
  apMinGapPx: 34, apMinGapDensePx: 22, apDenseAbove: 60, apCandidates: 16, apNudgePx: 6, groupPull: 0.15,
  clientBonusPx: 0.35, clientBonusCap: 8,
  coreRadiusPx: [4, 8],   // star core radius over rssiT, theme-free: star size, label eligibility (px >= 5), hit radius (px + HIT.apPad)
  basePxMaxCore: 8,       // = coreRadiusPx[1]: layout spacing reserves exactly the largest drawn core (basePxMax, spec 4.1)
  orbitTilt: 0.7,
  clientJitterPx: 12, clientMinDistPx: 14, radialTolPx: 10, homePull: 0.05, pushFactor: 0.9,
  starZoneExtraPx: 18, coreZonePx: 10, bubbleZonePx: 4,
  settleEpsPx: 0.2, settleSyncIter: 32, settlePerFrame: 2, settleMaxIter: 600,
  orbitMinPx: 32, orbitSpreadPx: 18, orbitRankPx: 3, orbitLanes: 6, orbitMaxPx: 65, hexAbove: 8, hexBPx: 16,
  orbitSpeedBase: 0.45, orbitSpeedRefPx: 32, orbitSpeedExp: 1.5, hexSpinRadPerS: 0.08,
  skySpinRadPerS: 2 * Math.PI / 300,   // sky spin (§4.2a): the whole sky turns rigidly around the device, one turn in 5 min
  forceAggAbove: 600, forceAggDensity: 0.20
};
const AGG = { cellPx: 32, minCell: (nFree) => nFree <= 200 ? 4 : 3, minCluster: (nFree) => nFree <= 200 ? 6 : 8, maxCellsPerBubble: 4,
  keepFrac: 0.75, rMinPx: 14, rMaxPx: 46, expandMs: 6000, expandAlpha: 0.35, kPos: 4, minCounterPx: 9, minCounterAlpha: 0.5 };
// §8.8 logical AP grouping: purely client-side heuristic, theme-free and deterministic (seed-free).
const DEVICE = { mbssidBits: 3, seqWindow: 4, radioWindow: 16, seqTight: 2, essExpandMs: 6000 };
// §8.8a random clouds (theme-free); JQLIB `clouds` in starchorus-display.sh uses the same values as literals.
const CLOUD = { bandDb: 3, shiftEps: 0.01, shiftMax: 8, burstS: 2, burstCap: 1500, minAddr: 8, minBursts: 6, minHits: 5, cadMinS: 15, cadMaxS: 300, tolFrac: 0.1, tolMinS: 2,
  lagMax: 3, candMax: 6, streamMax: 5, zK: 6, hMin: 2, ratio: 2, fundFrac: 0.8, kCap: 3, alpha: 0.001, margin: 3, muMax: 0.5, muMaxMore: 0.8,
  joinDb: 6, mergeDb: 12, coincide: 0.6, mergeShare: 0.8, mixedShare: 0.6, keepAddr: 2, keepFrac: 0.5,
  expandMs: 6000, pxBase: 5, pxGain: 1.5, px3d: [4.5, 11], listMax: 300 };
const RANDOM_MODES = ["cloud", "show", "hide"];
const BT = { pxBase: 4, pxGain: 1.5, px3d: [4, 10], hystDb: 3, cap: 256, drawMax: 48 }, GLOW = { rateFull: 5, min: 0.05, max: 24 };
const BT_TYPES = ["public", "random-static", "random-resolvable", "random-nonresolvable", "random"];
const CFG3D = { el: 0.42, azStart: 0, fovDeg: 50, distFactor: 0.8, distMin: 1.1, distMax: 9, elMin: -0.15, elMax: 1.45,
  yBand: { "2.4": -0.10, "5": 0, "6": 0.10, unknown: 0 }, yJitter: 0.04, freeYSpread: 0.36, freeZJitter: 0.03,
  fibonacciAbove: 60, hexY: 0.02,
  dragRadPerPx: 0.0055, wheelK: 0.0012, btnAz: 0.35, btnEl: 0.2, btnZoom: 1.25, dragThresholdPx: 4, touchThresholdPx: 10,
  kAz: 7, kEl: 7, kDist: 5, kTarget: 4, kNode: 3, kBlend: 3.5, kReduced: 40, autoRamp: 1.2, idleResumeMs: 6000,
  nearHard: 0.10, nearSoft: 0.45, farStart: 0.35, farEnd: 1.8, centerZoom: 0.55,
  fogNearAlpha: 1, fogFarAlpha: 0.33, sizeFarFactor: 0.58,   // depth fog + far size, theme-free (they gate 3D px, alphaDraw, labels, hit-test)
  minPxClient: 3.5, minPxAp: 5, maxPxClient: 9, maxPxAp: 44, minPxBubble: 9, bubbleFogFloor: 0.5,
  plumbAlpha: 0.35, parallaxPx: 14,
  zoom2dMin: 0.5, zoom2dMax: 4, focusFrac: 0.55 };
const RENDER = { maxDpr: 2, dprSteps: [2, 1.5, 1.25, 1], hudMinDpr: 1.5, budgetMs: 16.6, lateK: 1.1, panelK: 1.25,
  blockMs: 1000, settleMs: 250, lateFrac: 0.25, okFrac: 0.05, slowBlocks: 2, upBlocks: 3, upMs: 15000, upMaxMs: 120000,
  failMs: 60000, capRatio: 0.85, probeGapMs: 60000, emaAlpha: 0.1,
  maxLabels: [[24, 16], [18, 12], [12, 8], [8, 6]],
  maxText: { "2d": 30, "3d": 24 },
  maxGroupLabels: { "2d": 6, "3d": 4 }, labelGridPx: 64, labelRowPx: 24, labelMarginPx: 6,
  mobile: { maxLabels: 12, dprCap: 1.5, lodBias: 1 },
  spriteTiers: [2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32], spriteCap: 128, alphaSteps: 32,
  flareMax: 2, nebulaMax: 40, persistFadeFrames: 20, dtMax: 0.05, lodRectPx: 3 };
const LOD = { l1: 250, l2: 600, l3: 1000 };
const HIT = { apPad: 6, clientPad: 5, bubblePad: 4, minPx: 12, touchMinPx: 16, pinDebounceMs: 250 };
const KEYS = [
  { key: "T", desc: "Cycle theme (Foundation / Wargames / Whitehall)", btn: "t-theme" },
  { key: "V", desc: "Toggle 2D / 3D view", btn: "t-view" },
  { key: "R", desc: "Auto-rotation (3D)", btn: "t-rotate" },
  { key: "S", desc: "Sky spin: the whole sky slowly orbits the device (distance = signal stays exact)", btn: "t-spin" },
  { key: "C", desc: "CRT scanlines, vignette, persistence (Wargames)", btn: "t-crt" },
  { key: "Space", desc: "Pause / resume", btn: "t-pause" },
  { key: "L", desc: "Labels", btn: "t-labels" },
  { key: "O", desc: "Orbit arcs", btn: "t-orbits" },
  { key: "K", desc: "Client links", btn: "t-links" },
  { key: "A", desc: "Aggregate dense clients into bubbles (forced above 600 clients or density 0.20)", btn: "t-agg" },
  { key: "X", desc: "Randomised addresses: one node per cloud · one by one · hidden (cycles)", btn: "t-random" },
  { key: "E", desc: "Vendor names at labels", btn: "t-vendor" },
  { key: "N", desc: "Channel-overlap nebula (derived)", btn: "t-nebula" },
  { key: "G", desc: "Same-ESSID constellations", btn: "t-groups" },
  { key: "D", desc: "Device links (likely same physical AP)", btn: "t-devices" },
  { key: "M", desc: "Merge same-SSID APs into one node", btn: "t-merge" },
  { key: "P", desc: "Probe orbits: clients circle the visible network they probe for (derived, not associated)", btn: "t-probes" },
  { key: "W", desc: "Observations: neutral, derived hints about this sky (replaces the legend while open)", btn: "t-obs" },
  { key: "I", desc: "Inventory: a sortable table of the access points on screen, with filter chips (replaces the legend while open)", btn: "t-inv" },
  { key: "F", desc: "Homing meter for the access point chosen at the collector (coarse: one reading per poll)", btn: "t-home" },
  { key: "Q", desc: "Air quality: per band the busiest channels, co-/adjacent-channel counts, the estimated beacon airtime (replaces the legend while open)" },
  { key: "J", desc: "Signal over time: curves of the selected access point's network, min / max / mean, scales 1 min · 10 min · 1 h, an operator threshold (ring and line)" },
  { key: "H", desc: "Recording and replay: the last captures held in memory; step through them, then Back to live" },
  { key: "Y", desc: "Channel view: bars · spectrum · channel-by-time waterfall", btn: "t-chan" },
  { key: "B", desc: "Baseline diff: what is new, changed or not heard now against the saved baseline (Set / Clear)", btn: "t-baseline" },
  { key: "U", desc: "Hide or show the panels: the sky alone, with a status pill that brings them back", btn: "t-panels" },
  { key: "Z", desc: "Scope (phone layout): signal on arcs, lanes by band, never a direction", btn: "t-scope" },
  { key: "1 / 2 / 3 / 4", desc: "Band filter 2.4 / 5 / 6 GHz · Bluetooth" },
  { key: "← → ↑ ↓", desc: "Orbit camera (3D)" },
  { key: "+ / −", desc: "Zoom (3D) · zoom around the device (2D)" },
  { key: "=", desc: "Zoom in, like +" },
  { key: "0", desc: "Reset camera and 2D zoom" },
  { key: "[ / ]", desc: "Cycle through pinned nodes (opens detail)" },
  { key: "Enter", desc: "Show a selected random cloud's addresses" },
  { key: "Esc", desc: "Close dialogue / help / detail, clear hover" },
  { key: "?", desc: "Keyboard shortcuts overlay", btn: "t-help" },
];
// D15 edge-panel layout (theme-free, px): gap between panels, channel-bar width range, detail minimum, smallPx = the phone bound (read by PHONE.query).
const EDGE = { gapPx: 12, chanMinPx: 280, chanMaxPx: 640, detailMinPx: 160, smallPx: 720 };
// D21 phone mode (§9.8): up to smallPx wide, or a phone on its side; ?phone=1|0 overrides. Drag, flick, room above the half sheet.
const PHONE = { query: "(max-width: " + EDGE.smallPx + "px), (max-height: 460px) and (pointer: coarse)", gapPx: 8, halfFrac: 0.5, dragPx: 8, flickPxMs: 0.4, starClearPx: 24, centreClearPx: 30 };
const SCOPE = { rim: 52, near: 22, half: 30, minL: 120, lanes: [["2.4", 0.4372], ["5", 0.5684], ["6", 0.2623], ["sta", 0.6121]], gap: 0.04, pad: 0.08, size: 1.25, rest: 0.85, snow: [1600, 400], arcs: [[0, 2, 1], [7, 1.5, 0.45], [16, 1, 0.2]], ticks: { "2.4": [1, 6, 11], "5": [36, 100, 149] } };
const POLL_MS = 5000, HISTORY_LEN = 60, HIST_KEEP_S = 300, STORAGE_KEY = "starchorus.ui.v1";
// D3 liveness: a feed is stale after STALE_POLLS ticks of POLL_MS (30 s) without a new `generated`, or, with center.interval, after
// max(floorS, mul × interval + slackS); a stale feed whose last OFFLINE_POLLS polls got no answer is 'Offline', not 'Stale'.
// Cadence (§38 pollNextMs): spacing = the median of the last `gaps` capture gaps (first guess guessMul × interval, else POLL_MS); the next
// poll comes leadMs before the next capture is due, then every stepMs until it arrives. maxIntervalS caps what a document may announce.
const STALE_POLLS = 6;
const STALE = { floorS: 30, mul: 2, slackS: 15 };
const OFFLINE_POLLS = 3;
const POLL = { gaps: 3, guessMul: 1.1, leadMs: 3000, stepMs: 2000, logMax: 60, maxIntervalS: 600 };
const HIST_KEEP_INGESTS = Math.round(HIST_KEEP_S * 1000 / POLL_MS);  // the undated limit of the sweep in ingest(), in ingests
// D1 freshness (theme-free; APs and stations, each from its own last_seen): age = generated − last_seen → T0 < 60 s · T1 < 300 s · T2 < 900 s · T3 on record · undated.
// The words and boundaries are provisional until the device's `time` cadence is verified (docs/architecture.md §14, D1).
const FRESH = { tiersS: [60, 300, 900], futureS: 300 };
// change log per BSSID (session-local, bounded), baseline (persisted, <= 500 APs), ghosts, observations, watchlist.
const CHG_MAX = 12, CHG_BSSIDS = 500, BASELINE_KEY = "starchorus.baseline.v1", BASELINE_MAX = 500, GHOST_MAX = 40;
// Station registers are capped apart from the APs' so that rotating randomised MACs can never crowd out an access point:
// station RSSI series in S.hist, stations in the baseline, station ghosts.
const HIST_CL_MAX = 2400, BASELINE_CL_MAX = 2000, GHOST_CL_MAX = 40;
const WATCH_KEY = "starchorus.watch.v1", WATCH_MAX = 20, OBS_MAX = 12, OBS_DWELL = 2, OBS_PROBE_S = 600;
// library rules (persisted), alias/notes/tags per observed key (AP or station, <= 200), inventory, export, homing.
const LIB_KEY = "starchorus.library.v1", NOTES_KEY = "starchorus.notes.v1", NOTES_MAX = 200, RULES_MAX = 20, INV_ROWS = 300;
const EXPORT_FOOTER = "Starchorus · passive observation · not a government system · no official marking";
const STA_SITREP_MAX = 20;   // the human SITREP caps its station list; JSON and CSV carry the complete set
const MOBILE_SSID_RE = /iphone|android|galaxy|pixel|hotspot|^DIRECT-/i;   // P3

