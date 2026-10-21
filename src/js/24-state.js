// ==== 24 STATE ====
const S = {
  aps: new Map(), clients: new Map(), groups: new Map(), hist: new Map(), bubbles: new Map(),
  devices: new Map(), deviceOf: new Map(), essClusters: new Map(), essOf: new Map(), essBySsid: new Map(), essExpand: new Map(),
  identity: new Map(), clouds: new Map(), cloudOrder: [],   // §8.8a
  bt: new Map(), btOrder: [], btLvl: new Map(), btDoc: null, act: new Map(), actN: 0,
  ui: { theme: "foundation", view: "2d", labels: true, orbits: true, links: true, paused: false,
        agg: true, vendor: false, nebula: true, groups: true, rotate: true, spin: true, crt: true, autoLod: true, help: false,
        deviceLinks: false, essMerge: false, affinity: true, observations: false, baselineDiff: false, inventory: false,
        random: "cloud", panels: true, scope: false, sheet: "peek", legendCard: false,   // §9.8: panels, scope (saved); the sheet and its legend card (not)
        filters: { "2.4": true, "5": true, "6": true, bt: true } },
  queryLocked: new Set(),
  view: { blend: 0, blendT: 0 },
  cam: { az: 0, el: CFG3D.el, dist: 3, target: [0, 0, 0], azT: 0, elT: CFG3D.el, distT: 3, targetT: [0, 0, 0], tween: null, ramp: 0, idleAt: 0, zoom2d: 1 },
  anim: { fadeInK: 5.1, fadeOutK: 3.3, breathePeriodS: 6, breatheAmp: 0.06, blendK: 5.1,
          autoRotateRadPerS: 0.05, cameraEaseMs: 1200, cameraEasing: null,
          edgeTravelDotSpeed: 0, flareMax: 2, flareEnabled: true, flareLenFactor: 6 },
  apOrder: [], clientOrder: [],
  mode: "demo", source: "", note: "", generated: null, centerLabel: "YOU ARE HERE", maxAgeS: null, pollIntervalS: null,
  sourceKind: "none", sourceLabel: "", sourceKey: "", sourceApCount: 0, liveFeed: false, lastGen: null, stalePolls: 0, staleMs: 0, lostPolls: 0, gaps: [], fresh: false, ingestSeq: 0,   // D3/D4 (§38)
  captureSeq: 0, ev: { lastGen: null, arrived: 0, departed: 0, newStations: 0, newInClouds: 0 },   // D2: one event record per source (see eventsBegin)
  sky: { seq: 0, ref: new Map(), t0: null, resets: 0, dev: [] }, crowding: { level: 1, busiest: null },   // D11: per-source EWMA reference of channel occupancy (skyUpdate), crowding 1–5
  pinned: new Set(), hover: null, locked: null,
  clock: 0, skyA: 0, dirty: true, settling: false, settlePhase: 0, settleCapped: false, relayHold: false, relayT0: 0, layoutDirty: true, fixedTime: null, moving: false,
  perf: { fps: 0, frameMs: 16.6, lod: 0, lodBase: 0, dpr: 1, dprStep: 0, dprStart: 0, down: 0, capMs: 0, lateMs: 1.4 * RENDER.budgetMs,
          slowRun: 0, fastRun: 0, ambRun: 0, bT0: 0, bN: 0, bLate: 0, bMin: Infinity, bMin2: Infinity, upT: 0, upAt: 0, upWait: 0, probe: -1, probeMs: 0, probeT: -1e9, rSeen: 0,
          rendered: 0, rafTicks: 0, fpsAt: 0, samples: [], drawCalls: { drawImage: 0, fillRect: 0, stroke: 0, fillText: 0, shadowBlur: 0, gradient: 0, cue: 0, traffic: 0 } },
  countCalls: true,
  themeErrors: 0, errors: [],
  twinkles: 0, revealed: 0, labelsDrawn: 0, labelCollisions: 0, labelsOutside: 0, nodeCount: 0, nFreeTotal: 0,
  security: Object.fromEntries(Object.keys(ENCODING.security).map(k => [k, 0])),
  chg: new Map(), baseline: null, base: { set: false, size: 0, new: 0, gone: 0, changed: 0, ghosts: 0, sizeCl: 0, newCl: 0, goneCl: 0, ghostsCl: 0 }, ghosts: new Map(),
  watch: [], obs: [], obsFirst: new Map(), alerts: [], obsProbe: { firstGen: null },
  rules: [], notes: new Map(), inv: { sort: "rssi", dir: -1, filter: {} }, homing: null, homeOpen: false, homePeak: { bssid: null, dbm: null, gen: null, polls: 0 },
  recvT0: null, dx: null, chanMode: "bars", timeScale: "10m", wfBand: "2.4", threshold: null, long: new Map(), chanPeak: new Map(), rec: null, replay: null,   // analysis drawers (air|time|rec), channel-bar mode, operator threshold, long RSSI history, peak hold, recorder/replay (memory only)
  hop: null, own: { bssids: new Set(), ssids: new Set() },   // channels[] of the last document (null = none: absence is never "gone"); own transmitters, in memory only
  persistOn: false, persistFade: 0, travelDots: 0, probeArcs: 0,
};
const canvasBg = document.getElementById("bg"), canvasSky = document.getElementById("sky"), canvasHud = document.getElementById("hud");
const ctxBg = canvasBg.getContext("2d"), ctxSky = canvasSky.getContext("2d"), ctxHud = canvasHud.getContext("2d");
let W = 0, H = 0, CX = 0, CY = 0, skyH = 0, skyR = { x: 0, y: 0, w: 0, h: 0 }, maxRadius = 300, inner = 64, hudDpr = 1;
const mqReduce = window.matchMedia ? window.matchMedia("(prefers-reduced-motion: reduce)") : { matches: false };
let rmApi = null, reduceMotion = false;
const mqPhone = window.matchMedia ? window.matchMedia(PHONE.query) : { matches: false };   // D21 (§37 applyPhone)
let phoneOn = false, scopeOn = false;
const SC = { g: null, st: 0, sg: "", cs: -1, ri: -1, t0: -1e9, dur: 1.8, ph: null, lv: "live", sf: -1, unk: false };
function updateReduceMotion() {
  reduceMotion = rmApi !== null ? rmApi : (mqReduce.matches || query.rm1);
  document.documentElement.dataset.rm = reduceMotion ? "1" : "0";
  return reduceMotion;
}
function setReducedMotion(on) { rmApi = on == null ? null : !!on; updateReduceMotion(); S.dirty = true; return reduceMotion; }
if (mqReduce.addEventListener) mqReduce.addEventListener("change", () => { updateReduceMotion(); S.dirty = true; });
updateReduceMotion();
const PERSIST_KEYS = ["theme", "view", "random", "labels", "orbits", "links", "agg", "vendor", "nebula", "groups", "rotate", "spin", "crt", "deviceLinks", "essMerge", "affinity", "observations", "baselineDiff", "inventory", "panels", "scope"];
function readStored() {
  const raw = safeStorage.get(STORAGE_KEY); if (!raw) return null;
  try { const o = JSON.parse(raw); return isObj(o) ? o : null; } catch (e) { return null; }
}
function loadUi() {
  const o = readStored(); if (!o || o.v !== 2) return;
  if (o.theme && THEMES[o.theme]) S.ui.theme = o.theme;
  if (o.view === "2d" || o.view === "3d") S.ui.view = o.view;
  if (RANDOM_MODES.indexOf(o.random) >= 0) S.ui.random = o.random;
  for (const k of PERSIST_KEYS.slice(3)) if (typeof o[k] === "boolean") S.ui[k] = o[k];
}
let saveTimer = 0;
function saveUi() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    const prev = readStored() || {};
    const out = { v: 2 };
    for (const k of PERSIST_KEYS) {
      if (S.queryLocked.has(k)) { if (prev[k] !== undefined) out[k] = prev[k]; }
      else out[k] = S.ui[k];
    }
    safeStorage.set(STORAGE_KEY, JSON.stringify(out));
  }, 250);
}

