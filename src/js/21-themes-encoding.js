// ==== 21 THEMES & ENCODING ====
// D4 copy tokens: every passivity claim and every source word on the page. THEME.copy carries the same keys in all three
// themes (validateThemes); a theme may re-voice values. copy.rx.* = the claim sites while the source is passive,
// copy.active.* = the same sites when doc.source matches /ACTIVE/i (the collector's opt-in iw scan sent probe requests).
// Every THEME.copy starts with ...COPY_SITES and overrides a site in place, so COPY_SITES' key order is THEME.copy's
// (spec-sync quotes THEMES key by key).
const COPY_ACTIVE = "ACTIVE SCAN · the collector sent probe requests", COPY_RX_MODE = "MODE: RX ONLY — NOTHING IS TRANSMITTED";
const COPY_SITES = {
  rx: {
    meta: "A strictly passive Wi-Fi landscape visualiser — access points as stars, clients as satellites. RX only, nothing is transmitted.",
    tag: "passive observation · rx only — access points are stars, their clients orbit as satellites; distance from the centre tracks signal strength.",
    motto: "Observation only — it listens, it never transmits.",
    legRx: "RX only · nothing is transmitted", legArc: "arc = heard probe (rx only)", probeHint: "(heard probe requests, rx only)" },
  active: {
    meta: "A Wi-Fi landscape visualiser — access points as stars, clients as satellites. " + COPY_ACTIVE + ".",
    tag: COPY_ACTIVE + " — access points are stars, their clients orbit as satellites; distance from the centre tracks signal strength.",
    motto: "Wi-Fi landscape visualiser.",
    legRx: COPY_ACTIVE, legArc: "arc = heard probe", probeHint: "(heard probe requests)" },
  chip: { demo: "Sample", live: "Live", stale: "Stale", offline: "Offline", recorded: "Recorded", active: "Active scan", none: "No feed" },
  badge: { demo: "Simulation", live: "Live RX", stale: "Stale", offline: "Offline", recorded: "Recorded", active: "Active scan", none: "No feed" },   // the source badge (masthead): chrome text, never a data string
  crowdSign: { title: "Channel crowding", caption: "derived from channel overlap · not a security assessment", steps: ["1", "2", "3", "4", "5"] },
  lamps: "capture counter, binary",
  tote: { title: "Plot freshness", labels: ["HEARD", "RECENT", "FADING", "ON RECORD"], undated: "undated" },   // one lamp per D1 tier (T0..T3), a row per band
  clock: "sector clock",
  lampStrip: { title: "Heard this minute", more: "more" },   // one lamp per access point, channel-sorted; lit = D1 tier T0 (heard < 1 min), undated counts as heard
  caption: "observer and capture time",                      // the aria-label of the place-and-time caption
  compendium: { title: "Compendium of the Local Sky" },   // Foundation's voice for the sky summary
  vault: { title: "Vault", up: "busier than this sky usually is", down: "quieter than this sky usually is" },
  logonListen: { rx: "", active: "" },
  logonMode: { demo: COPY_RX_MODE + " · SAMPLE SKY", live: COPY_RX_MODE + " · LIVE FEED", recorded: COPY_RX_MODE + " · RECORDED CAPTURE",
    none: COPY_RX_MODE + " · NO FEED", active: "MODE: " + COPY_ACTIVE.toUpperCase() },
  bannerBot: { demo: "SIMULATED TRAFFIC · NOTHING IS TRANSMITTED · RX ONLY", live: "LIVE FEED · NOTHING IS TRANSMITTED · RX ONLY",
    recorded: "RECORDED CAPTURE · NOTHING IS TRANSMITTED · RX ONLY", none: "NO FEED · NOTHING IS TRANSMITTED · RX ONLY",
    active: COPY_ACTIVE.toUpperCase() },
};
const THEMES = {};
THEMES.foundation = {
  meta: { id: "foundation", label: "Foundation", isDefault: true },
  copy: { ...COPY_SITES,
    logonHead: ["STARCHORUS  ·  OBSERVATION TERMINAL", "LOGON: OBSERVER"], logonTail: ["…LOADING SKY"],
    bannerTop: "EXERCISE · STARCHORUS · NOT A GOVERNMENT SYSTEM",
    signal: ["excellent", "good", "weak", "marginal"], skyVoice: "Compendium",
    scope: { strip: ["Stars", "Satellites", "Clouds", "Brightest", "New"] },
    legendHeads: { measured: "Measured", derived: "Derived", operator: "Operator", look: "Look" } },
  surface: { base: "#05070d", deep: "#05070d", raised: "#0a1122",
    gradient: "radial-gradient(120% 120% at 50% 42%, #0a1122 0%, #080b16 46%, #05070d 100%)",
    panelFill: "rgba(8,11,22,0.80)", panelBorder: "rgba(233,228,216,0.16)", panelBlurPx: 12, panelRadiusPx: 3,
    panelShadow: "0 12px 40px rgba(0,0,0,0.55)" },   // flat slabs: a 3 px radius and a warm pearl edge; the blur stays
  ink: { primary: "#dfe7fb", secondary: "#9aa7c4", muted: "#6f7c9c", onFill: "#05070d" },
  line: { hairline: "rgba(233,228,216,0.20)", hairlineSoft: "rgba(233,228,216,0.09)", baseline: "rgba(140,165,220,0.30)", ring: "rgba(140,165,220,0.56)", widthPx: 1, device: "rgba(233,228,216,0.40)",
    edge: { style: "bezier", curvature: 0.18, color: "rgba(233,228,216,0.18)", widthPx: 1, glowPx: 6 } },
  band: { "2.4": { core: "#038d86", glow: "rgba(255,224,170,0.42)" }, "5": { core: "#2896f5", glow: "rgba(255,224,170,0.42)" },
    "6": { core: "#7153dd", glow: "rgba(255,224,170,0.42)" }, unknown: { core: "#7c828c", glow: "rgba(255,224,170,0.24)" } },
  status: { alarm: "#e0b95a", alarmWash: "rgba(224,185,90,0.10)", alarmAura: "none", alert: "#e5484d", ringNeutral: "#9aa7c4", ringStrong: "#dfe7fb", glyphInk: "#9aa7c4", hidden: "#6f7c9c" },
  accent: { selection: "#e9e4d8", selectionWash: "rgba(233,228,216,0.12)", focusRing: "#e9e4d8", flare: "rgba(255,220,180,0.20)",
    toggleOn: "#e9e4d8", toggleInk: "#05070d", toggleBorder: "#e9e4d8" },
  rssi: { dbmMin: -90, dbmMax: -30, glowRadiusFactor: [1.2, 3.0], glowAlpha: 0.45,
    bloomPx: [0, 0] },
  glow: { mode: "mono", color: "rgba(255,224,170,1)", maxBlurPx: 28, ringGlowPx: 0 },
  font: { ui: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", "Inter", "Segoe UI", system-ui, sans-serif',
    mono: 'ui-monospace, "SF Mono", Menlo, "JetBrains Mono", Consolas, monospace', transform: "none", letterSpacing: "0.04em",
    headingVariant: "small-caps",   // encyclopedic type — panel and legend headings in small capitals (a CSS font-variant, never a font file)
    sizesPx: { label: 11, hud: 11, tip: 12, title: 13, hero: 22 }, weight: { label: 400, title: 600, hero: 600 },
    numeric: { hero: "proportional", axis: "tabular" } },
  crt: { scanlineOpacity: 0, scanlinePeriodPx: 0, scanlineWidthPx: 0, vignetteAlpha: 0, vignetteInner: 1, persistenceAlpha: 0, flickerAmp: 0, userToggle: false },
  particles: { perNode: [6, 24], spreadFactor: 1.8, sigmaFactor: 0.6, lifeMs: [2400, 4200], sizePx: [0.6, 1.4], alpha: [0.25, 0.60],
    driftPxPerS: 4, gatherMs: 900, dissolveMs: 1400, maxTotal: 2400, color: "rgba(255,214,150,1)",
    cohesion: { scale: [1, 1.3, 1.7, 2.3], alpha: [1, 0.85, 0.65, 0.45] },   // the dust's cohesion IS freshness — T0 dense and bright … T3 a loose haze (the core, radius and hit-test do not change)
    spiral: { dawnRad: 1.4, duskRad: 0.9 },                                // dawn: new dust spirals IN; dusk: leaving dust drifts OUT along a spiral (radians of turn)
    lit: true, shade: "rgba(176,122,60,1)" },   // the grains are LIT, not emitting — the side facing the centre is warm dust, the far side this bronze shade (ΔE 18.4 to alarm, so the ornament rule holds)
  motion: { autoRotateRadPerS: 0.05, breathePeriodMs: 6000, breatheAmp: 0.06, fadeInMs: 900, fadeOutMs: 1400, cameraEaseMs: 1200,
    cameraEasing: "easeInOutCubic", edgeTravelDotSpeed: 0, edgeTravelDotPx: 0, cursorBlinkMs: 0, introStyle: "coalesce", logonCharMs: [28, 58] },
  depth: { bokeh: { enabled: true, farSoftness: 2.4, nearSoftness: 1.0 },
    lensFlare: { enabled: true, maxStars: 2, lengthFactor: 6, alpha: 0.18 } },
  chart: { lineWidthPx: 2, lineJoin: "round", markerRadiusPx: 4, markerRingPx: 2, areaAlpha: 0.10, gridStyle: "solid", gridWidthPx: 1,
    barMaxPx: 24, barRadiusPx: 4, barGapPx: 2, labelPolicy: "endpoint", tooltip: true, crosshair: true, legend: "auto", hitTargetPx: 24,
    textToken: "ink.secondary", axisTextToken: "ink.muted", axisNumeric: "tabular", deemphasis: "#6f7c9c", sparklinePoints: 60, refetchHoldAlpha: 0.6 },
  render: { clientCore: "#dfe7fb", clientRing: "band", clientShape: "disc", bubbleFill: "rgba(210,214,224,0.10)", bubbleStroke: "rgba(210,214,224,0.75)",
    nebula: "rgba(210,214,224,1)", starfield: { density: 5200, color: "#aebbe0", alpha: [0.12, 0.62], twinkleFrac: 0.15 },
    grid: { spokes: 0, dotStepPx: 0 }, shadow: "rgba(0,0,0,0.12)", composite: "source-over", shapeFill: true, probeArc: false, deviceTie: "bezier", changeCue: "glowPulse", clientRandomizedMark: "hollow", bubbleTicks: false, btMark: "#d77fa8",
    phosphor: { enabled: false, alpha: [0, 0, 0, 0], radiusFactor: 0 }, recvRing: { enabled: false, fromPx: 0, toPx: 0, ms: 0 }, arrivalArcs: false,
    coreMark: "sun", newPlotMark: { enabled: false, dash: [3, 3], offsetPx: 6 }, coreBeat: { enabled: true, hz: 0.8, amp: 0.07 } },   // the core beats in place (<= 1 Hz), no outward rings
  look: { clock: { p1: "#7c828c", p2: "#9aa7c4", p3: "#6f7c9c" } },
  chrome: { ink: "#e9e4d8", bezel: { color: "rgba(0,0,0,0)", widthPx: 0, gapPx: 0, bracketPx: 0 }, banner: { show: false, fill: "rgba(0,0,0,0)", ink: "#e9e4d8", rule: "rgba(0,0,0,0)" },
    badge: { show: false }, crowdSign: { show: false }, lamps: { show: false, count: 8 }, clock: { show: false }, tote: { show: false }, compendium: { show: true }, vault: { show: true },
    lampStrip: { max: 0, off: "#3d3d3d" }, plaqueTip: { show: false }, caption: { show: true } },   // per-AP lamp strip (WarGames), plaque tooltip (Whitehall), observer-and-capture caption (Foundation)
};
THEMES.wargames = {
  meta: { id: "wargames", label: "WARGAMES", isDefault: false },
  copy: { ...COPY_SITES, chip: { ...COPY_SITES.chip, offline: "Link down" }, badge: { ...COPY_SITES.badge, offline: "Link down" },
    logonListen: { rx: "LISTEN ONLY · STARCHORUS SENDS NO FRAMES", active: "" },
    logonHead: ["STARCHORUS  ·  OBSERVATION TERMINAL", "LOGON: OBSERVER"], logonTail: ["…LOADING SKY"],
    bannerTop: "EXERCISE · STARCHORUS · NOT A GOVERNMENT SYSTEM",
    signal: ["MAX", "STRONG", "WEAK", "MIN"], skyVoice: "SKY SUMMARY",
    scope: { strip: ["NETS", "STATIONS", "CLOUDS", "PEAK", "NEW"] },
    legendHeads: { measured: "Measured", derived: "Derived", operator: "Operator", look: "Look" } },
  surface: { base: "#000000", deep: "#000000", raised: "#000000", gradient: null, panelFill: "rgba(0,0,0,0.85)", panelBorder: "#0f234b",
    panelBlurPx: 0, panelRadiusPx: 0, panelShadow: "none" },
  ink: { primary: "#e6e6dc", secondary: "#a7a7a7", muted: "#808080", onFill: "#000000" },
  line: { hairline: "#0f234b", hairlineSoft: "rgba(15,35,75,0.60)", baseline: "#0f234b", ring: "#287878", widthPx: 1, device: "rgba(154,154,144,0.70)",
    edge: { style: "parabola", curvature: 0.28, color: "rgba(167,167,167,0.45)", widthPx: 1, glowPx: 6 } },
  band: { "2.4": { core: "#2ab42a", glow: "self" }, "5": { core: "#6ad2f9", glow: "self" }, "6": { core: "#8457a2", glow: "self" }, unknown: { core: "#808080", glow: "self" } },
  status: { alarm: "#fa4809", alarmWash: "rgba(250,72,9,0.10)", alarmAura: "wash", alert: "#ff3b3b", ringNeutral: "#a7a7a7", ringStrong: "#e6e6dc", glyphInk: "#a7a7a7", hidden: "#808080" },
  accent: { selection: "#e6e6dc", selectionWash: "rgba(230,230,220,0.10)", focusRing: "#e6e6dc", flare: "rgba(0,0,0,0)",
    toggleOn: "#287878", toggleInk: "#ffffff", toggleBorder: "#287878" },
  rssi: { dbmMin: -90, dbmMax: -30, glowRadiusFactor: [0, 0], glowAlpha: 0, bloomPx: [4, 12] },
  glow: { mode: "self", color: null, maxBlurPx: 12, ringGlowPx: 4 },
  font: { ui: 'ui-monospace, "SF Mono", Menlo, "IBM Plex Mono", "Courier New", monospace', mono: 'ui-monospace, "SF Mono", Menlo, "IBM Plex Mono", "Courier New", monospace',
    transform: "uppercase", letterSpacing: "0.12em", headingVariant: "normal", sizesPx: { label: 11, hud: 11, tip: 12, title: 13, hero: 22 },
    weight: { label: 400, title: 600, hero: 600 }, numeric: { hero: "proportional", axis: "tabular" } },
  crt: { scanlineOpacity: 0.10, scanlinePeriodPx: 3, scanlineWidthPx: 1, vignetteAlpha: 0.45, vignetteInner: 0.60, persistenceAlpha: 0.25, flickerAmp: 0.015, userToggle: true },
  particles: { perNode: [0, 0], spreadFactor: 0, sigmaFactor: 0, lifeMs: [0, 0], sizePx: [0, 0], alpha: [0, 0], driftPxPerS: 0, gatherMs: 0, dissolveMs: 0, maxTotal: 0, color: null,
    cohesion: { scale: [1, 1, 1, 1], alpha: [1, 1, 1, 1] }, spiral: { dawnRad: 0, duskRad: 0 }, lit: false, shade: null },
  motion: { autoRotateRadPerS: 0.12, breathePeriodMs: 0, breatheAmp: 0, fadeInMs: 250, fadeOutMs: 400, cameraEaseMs: 600, cameraEasing: "easeOutQuad",
    edgeTravelDotSpeed: 0.35, edgeTravelDotPx: 1.5, cursorBlinkMs: 530, introStyle: "typed", logonCharMs: [28, 58] },
  depth: { bokeh: { enabled: false, farSoftness: 1.0, nearSoftness: 1.0 },
    lensFlare: { enabled: false, maxStars: 0, lengthFactor: 0, alpha: 0 } },
  chart: { lineWidthPx: 2, lineJoin: "round", markerRadiusPx: 4, markerRingPx: 2, areaAlpha: 0.10, gridStyle: "solid", gridWidthPx: 1,
    barMaxPx: 24, barRadiusPx: 4, barGapPx: 2, labelPolicy: "endpoint", tooltip: true, crosshair: true, legend: "auto", hitTargetPx: 24,
    textToken: "ink.secondary", axisTextToken: "ink.muted", axisNumeric: "tabular", deemphasis: "#808080", sparklinePoints: 60, refetchHoldAlpha: 0.6 },
  render: { clientCore: "#e6e6dc", clientRing: "band", clientShape: "cross", bubbleFill: "rgba(0,0,0,0.60)", bubbleStroke: "#a7a7a7",
    nebula: "rgba(154,154,144,1)", starfield: { density: 0, color: "#000000", alpha: [0, 0], twinkleFrac: 0 },
    grid: { spokes: 8, dotStepPx: 48 }, shadow: "rgba(0,0,0,0)", composite: "source-over", shapeFill: false, probeArc: true, deviceTie: "bracket", changeCue: "bloomPulse", clientRandomizedMark: "crossX", bubbleTicks: true, btMark: "#e87ac8",
    phosphor: { enabled: true, alpha: [0.55, 0.34, 0.16, 0], radiusFactor: 2.4 },   // the star's afterglow = freshness (T0..T3), one soft sprite per band colour and size, blitted with a per-tier alpha
    recvRing: { enabled: true, fromPx: 18.5, toPx: 10.5, ms: 300 }, arrivalArcs: true,   // a ring that CONTRACTS onto the core when a station arrives (never outward); arcs only for arrivals
    coreMark: "reticle", newPlotMark: { enabled: false, dash: [3, 3], offsetPx: 6 }, coreBeat: { enabled: false, hz: 0, amp: 0 } },
  look: { clock: { p1: "#808080", p2: "#a7a7a7", p3: "#8b8b80" } },
  chrome: { ink: "#e6e6dc", bezel: { color: "#287878", widthPx: 1, gapPx: 0, bracketPx: 10 }, banner: { show: false, fill: "rgba(0,0,0,0)", ink: "#e6e6dc", rule: "rgba(0,0,0,0)" },
    badge: { show: true }, crowdSign: { show: true }, lamps: { show: true, count: 8 }, clock: { show: false }, tote: { show: false }, compendium: { show: false }, vault: { show: false },
    lampStrip: { max: 48, off: "#3d3d3d" }, plaqueTip: { show: false }, caption: { show: false } },   // one lamp per access point, channel-sorted; lit = heard in the last minute. The lit colour is the band's own, read at draw time (chrome never stores a band colour)
};

// WHITEHALL — in the style of WWII fighter-control plotting tables and filter rooms and by table-top exercise
// practice. No connection to any government; not a government system. The EXERCISE banner is fictional
// framing, never a real classification or handling marking. APP-6 identity language (frame shape + colour)
// applies only to the operator-set identity frames; the band cores stay the data truth. Wireframe markers
// on a dark table ground, teleprinter mono, plotting grid (no radar sweep, no bearings).
THEMES.whitehall = {
  meta: { id: "whitehall", label: "WHITEHALL", isDefault: false },
  copy: { ...COPY_SITES, chip: { ...COPY_SITES.chip, offline: "No link" }, badge: { ...COPY_SITES.badge, offline: "No link" }, logonMode: { demo: "MODE: RX ONLY - NOTHING IS TRANSMITTED - SAMPLE SKY", live: "MODE: RX ONLY - NOTHING IS TRANSMITTED - LIVE FEED", recorded: "MODE: RX ONLY - NOTHING IS TRANSMITTED - RECORDED CAPTURE",
      none: "MODE: RX ONLY - NOTHING IS TRANSMITTED - NO FEED", active: "MODE: ACTIVE SCAN - THE COLLECTOR SENT PROBE REQUESTS" },
    bannerBot: { demo: "SIMULATED PLOTS · PASSIVE RECEIVE ONLY · NOT A GOVERNMENT SYSTEM", live: "REAL-WORLD DATA · NOT EXERCISE PLAY · {src} · LIVE · NOT A GOVERNMENT SYSTEM",
      recorded: "REAL-WORLD DATA · NOT EXERCISE PLAY · {src} · RECORDED · NOT A GOVERNMENT SYSTEM", none: "ENDEX · NO FEED · NOT A GOVERNMENT SYSTEM",
      active: "ACTIVE SCAN · THE COLLECTOR SENT PROBE REQUESTS · {src} · NOT A GOVERNMENT SYSTEM" },
    logonHead: ["STARTEX", "STARCHORUS - PLOTTING TERMINAL", "CONNECTING TO FEED..."], logonTail: ["EXERCISE - NOT A GOVERNMENT SYSTEM", "...PLOTTING"],
    bannerTop: "EXERCISE – EXERCISE – EXERCISE · NOT A GOVERNMENT SYSTEM",
    signal: ["STRONG", "GOOD", "WEAK", "FAINT"], skyVoice: "SITREP",
    scope: { strip: ["NETWORKS", "STATIONS", "CLOUDS", "STRONGEST", "NEW PLOTS"] },
    legendHeads: { measured: "Plots", derived: "Filter room · derived", operator: "Operator", look: "Look" } },
  surface: { base: "#0a0f0b", deep: "#070b08", raised: "#0c130d",
    gradient: "radial-gradient(120% 120% at 50% 44%, #0d160f 0%, #0a0f0b 52%, #070b08 100%)",
    panelFill: "rgba(8,14,9,0.86)", panelBorder: "#3b4738", panelBlurPx: 0, panelRadiusPx: 2, panelShadow: "none" },
  ink: { primary: "#d7dad1", secondary: "#96a08f", muted: "#7d8674", onFill: "#0a0f0b" },
  line: { hairline: "rgba(215,218,209,0.14)", hairlineSoft: "rgba(215,218,209,0.07)", baseline: "rgba(215,218,209,0.24)", ring: "rgba(215,218,209,0.42)", widthPx: 1, device: "rgba(215,218,209,0.55)",
    edge: { style: "bezier", curvature: 0.16, color: "rgba(215,218,209,0.28)", widthPx: 1, glowPx: 6 } },
  band: { "2.4": { core: "#3fb950", glow: "self" }, "5": { core: "#3e7cff", glow: "self" }, "6": { core: "#c77dff", glow: "self" }, unknown: { core: "#c8ccc4", glow: "self" } },
  status: { alarm: "#e5484d", alarmWash: "rgba(229,72,77,0.12)", alarmAura: "wash", alert: "#e5484d", ringNeutral: "#96a08f", ringStrong: "#d7dad1", glyphInk: "#96a08f", hidden: "#7d8674" },
  accent: { selection: "#f4f5ef", selectionWash: "rgba(244,245,239,0.12)", focusRing: "#f4f5ef", flare: "rgba(0,0,0,0)",
    toggleOn: "#d7dad1", toggleInk: "#0a0f0b", toggleBorder: "#d7dad1" },
  rssi: { dbmMin: -90, dbmMax: -30, glowRadiusFactor: [0, 0], glowAlpha: 0, bloomPx: [3, 10] },
  glow: { mode: "self", color: null, maxBlurPx: 10, ringGlowPx: 3 },
  font: { ui: '"Starchorus Sans", "Frutiger", "Segoe UI", system-ui, "Helvetica Neue", Arial, sans-serif', mono: 'ui-monospace, "SF Mono", Menlo, "Consolas", "DejaVu Sans Mono", monospace',
    transform: "uppercase", letterSpacing: "0.04em", headingVariant: "normal", sizesPx: { label: 11, hud: 11, tip: 12, title: 13, hero: 22 },
    weight: { label: 500, title: 600, hero: 600 }, numeric: { hero: "tabular", axis: "tabular" } },
  crt: { scanlineOpacity: 0, scanlinePeriodPx: 0, scanlineWidthPx: 0, vignetteAlpha: 0, vignetteInner: 1, persistenceAlpha: 0, flickerAmp: 0, userToggle: false },
  particles: { perNode: [0, 0], spreadFactor: 0, sigmaFactor: 0, lifeMs: [0, 0], sizePx: [0, 0], alpha: [0, 0], driftPxPerS: 0, gatherMs: 0, dissolveMs: 0, maxTotal: 0, color: null,
    cohesion: { scale: [1, 1, 1, 1], alpha: [1, 1, 1, 1] }, spiral: { dawnRad: 0, duskRad: 0 }, lit: false, shade: null },
  motion: { autoRotateRadPerS: 0.06, breathePeriodMs: 0, breatheAmp: 0, fadeInMs: 300, fadeOutMs: 500, cameraEaseMs: 800, cameraEasing: "easeOutQuad",
    edgeTravelDotSpeed: 0, edgeTravelDotPx: 0, cursorBlinkMs: 0, introStyle: "typed", logonCharMs: [37.5, 37.5] },   // a teleprinter types at a constant 37.5 ms per character
  depth: { bokeh: { enabled: false, farSoftness: 1.0, nearSoftness: 1.0 },
    lensFlare: { enabled: false, maxStars: 0, lengthFactor: 0, alpha: 0 } },
  chart: { lineWidthPx: 2, lineJoin: "round", markerRadiusPx: 4, markerRingPx: 2, areaAlpha: 0.10, gridStyle: "solid", gridWidthPx: 1,
    barMaxPx: 24, barRadiusPx: 0, barGapPx: 2, labelPolicy: "endpoint", tooltip: true, crosshair: true, legend: "auto", hitTargetPx: 24,
    textToken: "ink.secondary", axisTextToken: "ink.muted", axisNumeric: "tabular", deemphasis: "#7d8674", sparklinePoints: 60, refetchHoldAlpha: 0.6 },
  render: { clientCore: "#d7dad1", clientRing: "band", clientShape: "cross", bubbleFill: "rgba(10,15,11,0.60)", bubbleStroke: "#7d8674",
    nebula: "rgba(150,160,143,1)", starfield: { density: 0, color: "#000000", alpha: [0, 0], twinkleFrac: 0 },
    grid: { spokes: 12, dotStepPx: 40 }, shadow: "rgba(0,0,0,0)", composite: "source-over", shapeFill: false, probeArc: false, deviceTie: "bracket", changeCue: "tick", clientRandomizedMark: "crossX", bubbleTicks: false, btMark: "#a8509a",
    phosphor: { enabled: false, alpha: [0, 0, 0, 0], radiusFactor: 0 }, recvRing: { enabled: false, fromPx: 0, toPx: 0, ms: 0 }, arrivalArcs: false,
    coreMark: "ownship", newPlotMark: { enabled: true, dash: [3, 3], offsetPx: 9 }, coreBeat: { enabled: false, hz: 0, amp: 0 } },   // an unframed ship symbol at the centre; a new plot gets its own dashed mark (not the identity channel)
  look: { clock: { p1: "#8a4a44", p2: "#a08a4a", p3: "#4a6a8f" } },   // the sector clock's three period colours: ornament, DOM dial only, never data
  chrome: { ink: "#d7dad1", bezel: { color: "rgba(0,0,0,0)", widthPx: 0, gapPx: 0, bracketPx: 0 }, banner: { show: true, fill: "#0c130d", ink: "#d7dad1", rule: "#7a1414" },
    badge: { show: false }, crowdSign: { show: false }, lamps: { show: false, count: 8 }, clock: { show: true }, tote: { show: true }, compendium: { show: false }, vault: { show: false },
    lampStrip: { max: 0, off: "#3d3d3d" }, plaqueTip: { show: true }, caption: { show: false } },   // the plaque tooltip — the same rows as every theme, laid out as corner blocks around the shape swatch
};


const ENCODING = {
  band: { "2.4": { shape: "circle", legend: "2.4 GHz", suffix: "2.4" }, "5": { shape: "diamond", legend: "5 GHz", suffix: "5" },
          "6": { shape: "hexagon", legend: "6 GHz", suffix: "6" }, unknown: { shape: "square", legend: "Band ?", suffix: "?" } },   // an AP whose band is unknown is a square (no other band uses one)
  security: {
    open:    { ring: "gap",    widthPx: 1.5, dash: null,   glyph: "!", tone: "alarm",   label: "OPEN" },   // D6: ONE mark for open and WEP — a ring with a 60° gap at NE,
    wep:     { ring: "gap",    widthPx: 1.5, dash: null,   glyph: "!", tone: "alarm",   label: "WEP"  },   // where the "!" sits; the wash is only an ornament (status.alarmAura)
    wpa:     { ring: "thin",   widthPx: 1,   dash: null,   glyph: "",  tone: "neutral", label: "WPA"  },
    wpa2:    { ring: "double", widthPx: 1,   dash: null,   glyph: "",  tone: "neutral", label: "WPA2" },
    wpa3:    { ring: "solid",  widthPx: 1.5, dash: null,   glyph: "3", tone: "strong",  label: "WPA3" },
    owe:     { ring: "thin",   widthPx: 1,   dash: null,   glyph: "◇", tone: "neutral", label: "OWE"  },
    // classes from the collector's AKM/cipher detail: 802.1X, WPA2+WPA3 transition, TKIP as the only pairwise cipher
    enterprise:        { ring: "thin",   widthPx: 1,   dash: [5, 2], glyph: "E", tone: "neutral", label: "ENTERPRISE" },
    "wpa3-transition": { ring: "double", widthPx: 1.5, dash: null,   glyph: "3", tone: "strong",  label: "WPA3/2" },
    "tkip-weak":       { ring: "thin",   widthPx: 1,   dash: [1, 3], glyph: "~", tone: "neutral", label: "TKIP" },
    unknown: { ring: "none",   widthPx: 0,   dash: null,   glyph: "?", tone: "muted",   label: "?"    },
  },
  // D1 minimal, theme-free freshness mark: star + ring alpha per tier. Undated APs look like T0.
  fresh: { alpha: [1, 0.85, 0.7, 0.55], words: ["heard < 1 min", "heard < 5 min", "heard < 15 min", "on record"], undated: "undated" },
  ringOffsetPx: 4, doubleRingGapPx: 3, selectionRingOffsetPx: 13, gapDeg: 60, pin: { gapDeg: 70, notchPx: 3 },   // D5: a pin is a notched arc (ink.secondary), never the selection ring
  hidden: { ring: "dashed", dash: [4, 4], widthPx: 1, offsetPx: 10 },
  merge: { dash: [6, 2, 1, 2], extraPx: 3 },   // D17: the merged-ESS ring has its own pattern (dash-dot), never the hidden-SSID ring's [4,4]
  ghost: { dash: [2, 2], r: 5 },   // D19: a baseline AP that is not heard now (derived): a small dashed ring at its frozen place
  // Manual identity (NATO APP-6 language): the operator sets it, the tool never asserts it; unknown (the default) draws nothing.
  // D7: the CANVAS draws the frame form only (rectangle friend · square neutral · dashed diamond suspect) in ink.primary — APP-6
  // allows a monochrome display; the APP-6 "light" colours below appear only in the detail panel, beside the words. The
  // storage key stays `hostile`.
  identity: {
    unknown: { color: "#ffff80", frame: "none",    btn: "Unknown", label: "unknown" },
    friend:  { color: "#80e0ff", frame: "rect",    btn: "Friend",  label: "friend · allow-list" },
    neutral: { color: "#aaffaa", frame: "square",  btn: "Neutral", label: "neutral" },
    hostile: { color: "#ff8080", frame: "diamond", btn: "Suspect", label: "suspect", dash: [3, 2] },
  },
};

const CSS_MIRROR = [
  ["--surface-base", "surface.base", ""], ["--surface-deep", "surface.deep", ""], ["--surface-raised", "surface.raised", ""],
  ["--surface-gradient", "surface.gradient", ""], ["--panel-fill", "surface.panelFill", ""], ["--panel-border", "surface.panelBorder", ""],
  ["--panel-blur", "surface.panelBlurPx", "px"], ["--panel-radius", "surface.panelRadiusPx", "px"], ["--panel-shadow", "surface.panelShadow", ""],
  ["--ink-primary", "ink.primary", ""], ["--ink-secondary", "ink.secondary", ""], ["--ink-muted", "ink.muted", ""], ["--ink-on-fill", "ink.onFill", ""],
  ["--line-hairline", "line.hairline", ""], ["--line-soft", "line.hairlineSoft", ""], ["--line-baseline", "line.baseline", ""],
  ["--band-24", "band.2.4.core", ""], ["--band-5", "band.5.core", ""], ["--band-6", "band.6.core", ""], ["--band-unknown", "band.unknown.core", ""],
  ["--status-alarm", "status.alarm", ""], ["--status-alarm-wash", "status.alarmWash", ""], ["--status-alert", "status.alert", ""], ["--status-ring-neutral", "status.ringNeutral", ""],
  ["--status-ring-strong", "status.ringStrong", ""], ["--status-glyph", "status.glyphInk", ""], ["--status-hidden", "status.hidden", ""],
  ["--accent-selection", "accent.selection", ""], ["--accent-wash", "accent.selectionWash", ""], ["--accent-focus", "accent.focusRing", ""],
  ["--toggle-on", "accent.toggleOn", ""], ["--toggle-ink", "accent.toggleInk", ""], ["--toggle-border", "accent.toggleBorder", ""], ["--chrome-ink", "chrome.ink", ""],
  ["--clock-p1", "look.clock.p1", ""], ["--clock-p2", "look.clock.p2", ""], ["--clock-p3", "look.clock.p3", ""],
  ["--banner-fill", "chrome.banner.fill", ""], ["--banner-ink", "chrome.banner.ink", ""], ["--banner-rule", "chrome.banner.rule", ""],
  ["--client", "render.clientCore", ""], ["--bubble-fill", "render.bubbleFill", ""], ["--bubble-stroke", "render.bubbleStroke", ""], ["--bt-mark", "render.btMark", ""],
  ["--font-ui", "font.ui", ""], ["--font-mono", "font.mono", ""], ["--text-transform", "font.transform", ""], ["--letter-spacing", "font.letterSpacing", ""],
  ["--heading-variant", "font.headingVariant", ""], ["--lamp-off", "chrome.lampStrip.off", ""],
  ["--size-label", "font.sizesPx.label", "px"], ["--size-hud", "font.sizesPx.hud", "px"], ["--size-tip", "font.sizesPx.tip", "px"],
  ["--size-title", "font.sizesPx.title", "px"], ["--size-hero", "font.sizesPx.hero", "px"],
  ["--crt-scanline-opacity", "crt.scanlineOpacity", ""], ["--crt-scanline-period", "crt.scanlinePeriodPx", "px"], ["--crt-scanline-width", "crt.scanlineWidthPx", "px"],
  ["--crt-vignette-alpha", "crt.vignetteAlpha", ""], ["--crt-vignette-inner", "crt.vignetteInner", ""],
  ["--cursor-blink-ms", "motion.cursorBlinkMs", "ms"],
  ["--bezel-color", "chrome.bezel.color", ""], ["--bezel-width", "chrome.bezel.widthPx", "px"], ["--bezel-gap", "chrome.bezel.gapPx", "px"],
  ["--bracket-size", "chrome.bezel.bracketPx", "px"],
];

let THEME = THEMES.foundation, TK = null, TD = null;

function resolveToken(path, obj = THEME) {
  // "band.2.4.core" → obj.band["2.4"].core (keys may contain a dot: try the longest matching key first)
  const parts = path.split(".");
  let cur = obj, i = 0;
  while (i < parts.length) {
    if (cur == null || typeof cur !== "object") return undefined;
    let found = false;
    for (let len = parts.length - i; len >= 1; len--) {
      const key = parts.slice(i, i + len).join(".");
      if (Object.prototype.hasOwnProperty.call(cur, key)) { cur = cur[key]; i += len; found = true; break; }
    }
    if (!found) return undefined;
  }
  return cur;
}
function flatten(obj, prefix = "", out = {}) {
  for (const k of Object.keys(obj)) {
    const v = obj[k], p = prefix ? prefix + "." + k : k;
    if (v && typeof v === "object" && !Array.isArray(v)) flatten(v, p, out); else out[p] = v;
  }
  return out;
}
// The theme schema is SYMMETRIC — every flattened key path must exist in ALL themes (no reference theme) and every
// leaf has one kind across themes (null = "none" fits any kind; arrays compare as "array"). auditThemes() is pure (no fill,
// no counting); validateThemes() runs it once at boot, counts every finding in S.themeErrors, keeps that boot audit for
// STARCHORUS.themeAudit() and only then (and only if something is wrong) fills absent paths from the first theme that has
// them — a crash guard, never a design fallback (S.themeErrors must stay 0).
function leafKind(v) { return v === null ? "null" : Array.isArray(v) ? "array" : typeof v; }
function auditThemes(themes = THEMES) {
  const ids = Object.keys(themes), flat = {}, all = new Set(), keyCount = {}, missing = {}, kinds = [];
  for (const id of ids) { flat[id] = flatten(themes[id]); keyCount[id] = Object.keys(flat[id]).length; for (const k of Object.keys(flat[id])) all.add(k); }
  const keys = Array.from(all).sort(), has = (id, k) => Object.prototype.hasOwnProperty.call(flat[id], k);
  for (const id of ids) missing[id] = keys.filter(k => !has(id, k));
  for (const k of keys) {
    const ks = ids.map(id => has(id, k) ? leafKind(flat[id][k]) : "-");
    if (new Set(ks.filter(x => x !== "-" && x !== "null")).size > 1) kinds.push(k + " " + ks.join("/"));
  }
  let errors = kinds.length; for (const id of ids) errors += missing[id].length;
  return { ids, union: keys.length, keyCount, missing, kinds, errors };
}
function fillMissing(src, dst) {   // crash guard: copy absent keys only, never overwrite a present one
  for (const k of Object.keys(src)) {
    if (!Object.prototype.hasOwnProperty.call(dst, k)) dst[k] = src[k];
    else if (isObj(src[k]) && isObj(dst[k])) fillMissing(src[k], dst[k]);
  }
}
let themeAuditBoot = null;
function validateThemes() {
  const a = auditThemes();
  for (const id of a.ids) for (const p of a.missing[id]) console.warn("theme: " + id + " lacks token " + p + " (present in " + a.ids.filter(o => !a.missing[o].includes(p)).join(", ") + ")");
  for (const k of a.kinds) console.warn("theme: token kind differs " + k);
  S.themeErrors += a.errors;
  themeAuditBoot = a;
  if (a.errors) for (const id of a.ids) for (const o of a.ids) if (o !== id) fillMissing(THEMES[o], THEMES[id]);
  for (const id of a.ids) validateTheme(THEMES[id]);
  return S.themeErrors;
}
function validateTheme(t) {   // per-theme value checks (the symmetric key check is validateThemes)
  for (const [name, path] of CSS_MIRROR) {
    const v = resolveToken(path, t);
    if (v === null && path !== "surface.gradient") { console.warn("theme: null token " + path + " for " + name); S.themeErrors++; }
    if (v === undefined) { console.warn("theme: unresolved " + path); S.themeErrors++; }
  }
  if (t.rssi.dbmMin !== LAYOUT.rssiMin || t.rssi.dbmMax !== LAYOUT.rssiMax) { console.warn("theme: rssi range differs from LAYOUT"); S.themeErrors++; }
  return S.themeErrors;
}
function parseColor(c) {
  if (typeof c !== "string") return [255, 255, 255, 1];
  const m = /^#([0-9a-f]{6})$/i.exec(c.trim());
  if (m) { const n = parseInt(m[1], 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255, 1]; }
  const r = /rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)/.exec(c);
  if (r) return [+r[1], +r[2], +r[3], r[4] === undefined ? 1 : +r[4]];
  return [255, 255, 255, 1];
}
function rgbaOf(c, a) { const p = parseColor(c); return "rgba(" + p[0] + "," + p[1] + "," + p[2] + "," + (Math.round(p[3] * a * 1000) / 1000) + ")"; }
function fontString(kind, t) {
  const f = t.font, s = f.sizesPx, k = scopeOn ? 13 : 0;
  switch (kind) {
    case "label": return f.weight.label + " " + (k || s.label) + "px " + f.ui;
    case "monoSmall": return "600 " + (k || 9) + "px " + f.mono;
    default: return "400 " + (k || s.hud) + "px " + f.ui;   // "hud"
  }
}
function deriveStrings(t) {
  const d = { css: {}, bandCore: {} };
  for (const [name, path, suffix] of CSS_MIRROR) { const v = resolveToken(path, t); d.css[name] = v === null ? "none" : String(v) + suffix; }
  for (const b of ["2.4", "5", "6", "unknown"]) d.bandCore[b] = t.band[b].core;
  d.fontLabel = fontString("label", t); d.fontHud = fontString("hud", t); d.fontMonoSmall = fontString("monoSmall", t);
  d.edgeStroke = t.line.edge.color; d.edgeGlow = rgbaOf(t.line.edge.color, 0.25);
  const pAlpha = [0.25, 0.37, 0.48, 0.60];
  d.particleFill = pAlpha.map(a => rgbaOf(t.particles.color || t.ink.primary, a));
  // lit dust: the same four alpha steps in the shade colour, so freshness still reads the same on both sides of a grain cloud
  d.particleLit = !!(t.particles.lit && t.particles.shade);
  d.particleShade = d.particleLit ? pAlpha.map(a => rgbaOf(t.particles.shade, a)) : d.particleFill;
  d.upper = t.font.transform === "uppercase";
  d.cursorBlink = t.motion.cursorBlinkMs > 0;
  d.clientKind = t.render.clientShape === "cross" ? "clientCross" : "client";
  d.glowMult = t.rssi.glowRadiusFactor[1];
  d.glowOn = t.rssi.glowRadiusFactor[1] > 0 && t.rssi.glowAlpha > 0;
  d.coreKind = { circle: "coreCircle", diamond: "coreDiamond", hexagon: "coreHex", square: "coreSquare" };
  d.bandColorKey = { "2.4": "b24", "5": "b5", "6": "b6", unknown: "unknown" };
  d.bokehSoft = !!t.depth.bokeh.enabled;
  return d;
}
function mirrorCss() {
  const root = document.documentElement.style;
  for (const [name] of CSS_MIRROR) root.setProperty(name, TD.css[name]);
}
function fillAnim() {
  const m = THEME.motion, d = THEME.depth, a = S.anim, rate = (ms) => 4.6 * 1000 / Math.max(1, ms);   // ease() rate that reaches ~1 % of the gap after ms
  a.fadeInK = rate(m.fadeInMs); a.fadeOutK = rate(m.fadeOutMs);
  a.breathePeriodS = m.breathePeriodMs / 1000; a.breatheAmp = m.breatheAmp;
  a.blendK = rate(m.fadeInMs);
  a.autoRotateRadPerS = m.autoRotateRadPerS; a.cameraEaseMs = m.cameraEaseMs;
  a.cameraEasing = { easeInOutCubic, easeOutQuad, linear: (u) => u }[m.cameraEasing] || easeInOutCubic;
  a.edgeTravelDotSpeed = m.edgeTravelDotSpeed;
  a.flickerAmp = THEME.crt.flickerAmp;
  a.probeArc = !!THEME.render.probeArc; a.arrivalArcs = !!THEME.render.arrivalArcs;
  a.flareMax = d.lensFlare.maxStars | 0; a.flareEnabled = !!d.lensFlare.enabled; a.flareLenFactor = d.lensFlare.lengthFactor || 0;
}
function applyTheme(id, opts = {}) {
  if (!THEMES[id]) id = "foundation";
  // changed = a real switch; re-applying the active theme keeps the theme-bound bitmaps, shows no caption and leaves a running intro alone
  const changed = TK === null || THEME !== THEMES[id];
  THEME = THEMES[id]; TK = flatten(THEME); TD = deriveStrings(THEME); fillAnim();
  S.ui.theme = id;
  if (opts.persist !== false) { S.queryLocked.delete("theme"); saveUi(); }
  const ds = document.documentElement.dataset;
  ds.theme = id;
  ds.cursor = THEME.motion.cursorBlinkMs > 0 ? "on" : "off";
  ds.banner = THEME.chrome.banner.show ? "on" : "off";
  ds.plaque = THEME.chrome.plaqueTip.show ? "on" : "off";   // the tooltip arrangement is a token, never a theme id
  mirrorCss();
  if (changed) {
    clearSprites(); particlesReset(); measureCache.clear();
    ctxSky.clearRect(0, 0, W, H);
  }
  if (!THEME.crt.flickerAmp || reduceMotion) canvasSky.style.opacity = "";
  applyCrt();
  rebuildBackground();
  buildLegend(); updateControlsLook(); if (S.locked) openDetail(S.locked);   // each of these ends in layoutEdges(), which redraws the channel bar
  renderSourceTruth();   // D4: chip, masthead, meta, legend claims and banner in the new theme's copy
  if (changed) renderCaption();
  updateStats();
  if (changed && scopeOn) resize();
  S.dirty = true;
  // re-applying with an empty sprite cache bakes it now (a real switch clears without rebaking until the next frame)
  if (!changed && spriteCache.size === 0 && W > 0) render();
  // D13: the intro is a token (motion.introStyle), and the "already seen" flag is per theme id — switching themes in one session
  // shows each theme's own intro exactly once. A real switch ends the outgoing intro even when the incoming theme has been seen.
  if (changed) {
    if (introRunning) { endCoalesce(); skipLogon(); }
    if (!reduceMotion && opts.intro !== false && !query.intro0 && !introSeen()) runIntro();
  }
  return id;
}

