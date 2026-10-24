// ==== 40 DEBUG API ====
function pushError(s) { S.errors.push(String(s)); if (S.errors.length > 50) S.errors.shift(); }
window.addEventListener("error", (e) => pushError(e.message || e.error || "error"));
window.addEventListener("unhandledrejection", (e) => pushError((e.reason && e.reason.message) || e.reason || "rejection"));
function guard(fn) { try { return fn(); } catch (e) { pushError(e); return { error: String(e) }; } }
function pubNode(n) {
  if (!n) return null;
  if (n.kind === "ap") return { id: n.id, kind: "ap", bssid: n.bssid, ssid: n.ssid, ssidKnown: n.ssidKnown, hidden: n.hidden,
    band: n.band, channel: n.channel, freq: n.freq, rssi: n.rssi, security: n.security, sec: n.sec, vendor: n.vendor, rate: n.rate,
    width: n.width, phy: n.phy, caps: n.caps, beacons: n.beacons, last_seen: n.last_seen, clientCount: n.clientCount, ageS: n.ageS, freshTier: n.freshTier, akm: n.akm, cipher: n.cipher, auth: n.auth, respondedSsids: n.respondedSsids, packets: n.packets, mobile: n.mobile, baseState: n.baseState || null, isNew: isNewAp(n), newSeq: n.newSeq, changedSeq: n.changedSeq, cueSeq: n.cueSeq,
    phyEstimate: phyEstimate(n), pmf: pmfDerived(n), basePxMax: r3(n.basePxMax), flare: r3(n.flare), flareT: n.flareT, pState: n.pState, revealAt: n.revealAt,
    sx: r3(n.sx), sy: r3(n.sy), zc: r3(n.zc), px: r3(n.px), fog: r3(n.fog), alphaDraw: r3(n.alphaDraw), bubble: null, bubbleBlend: 0, pinned: S.pinned.has(n.id) };
  return { id: n.id, kind: "client", mac: n.mac, rssi: n.rssi, vendor: n.vendor, randomized: n.randomized, last_seen: n.last_seen, ageS: n.ageS, freshTier: n.freshTier, isNew: isNewAp(n),
    packets: n.packets, fps: n.fps == null ? null : r3(n.fps), glow: n.cue ? n.gl : 0, parent: n.parent, free: n.free, affinity: !!n.affinity, probeVia: n.probeVia || null, probes: n.probes ? n.probes.slice() : null, band: n.band, basePxMax: r3(n.basePxMax),
    sx: r3(n.sx), sy: r3(n.sy), zc: r3(n.zc), px: r3(n.px), fog: r3(n.fog), alphaDraw: r3(n.alphaDraw), bubble: n.bubble, bubbleBlend: r3(n.bubbleBlend), pinned: S.pinned.has(n.id), cloud: n.cloud || null, randOut: !!n.randOut };
}
function nodeVisible(n) { return n.target === 1 && n.alphaDraw > 0.05 && (n.kind !== "ap" || (S.ui.filters[n.band] !== false && !isEssFolded(n.id))); }
function eventsObj() {   // D2: counters of the LAST capture of this source (per station: STARCHORUS.node(mac).isNew); "<5" is a display rule
  let nw = 0, chg = 0, cue = 0; S.aps.forEach(n => { if (n.target !== 1 || eventSkip(n)) return; if (isNewAp(n)) nw++; if (n.changedSeq === S.captureSeq && S.captureSeq > 0) chg++; if (n.cueSeq === S.captureSeq && S.captureSeq > 0) cue++; });
  const e = S.ev;
  return { captureSeq: S.captureSeq, arrived: e.arrived, departed: e.departed, changed: chg, cues: cue, newAps: nw, newStations: e.newStations, newInClouds: e.newInClouds || 0, departedStations: e.departedStations, newStationsText: e.newStations === 0 ? "0" : e.newStations < 5 ? "<5" : String(e.newStations) };
}
function statsObj() {
  const st = S._stats || { apsTotal: 0, aps: 0, free: 0, assoc: 0, clients: 0, bands: { "2.4": 0, "5": 0, "6": 0 }, bandsT: { "2.4": 0, "5": 0, "6": 0 }, alarms: 0, groups: 0 };
  let vis = 0; S.clients.forEach(n => { if (n.target === 1 && n.alphaDraw > 0.05 && (n.bubble == null || n.bubbleBlend < 0.5)) vis++; });
  let visK = 0; S.clouds.forEach(k => { if (k.target === 1 && k.alphaDraw > 0.05) visK++; });
  let hidden = 0; S.aps.forEach(n => { if (n.target === 1 && n.hidden) hidden++; });
  const gl = [0, 0, 0], stale = captureStale(); S.clients.forEach(c => { if (c.cue && c.target === 1 && !stale && c.gl > 0) gl[c.gl - 1]++; });
  return { aps: st.aps, apsTotal: st.apsTotal, clients: st.clients, clientsTotal: st.clients, free: st.free, assoc: st.assoc,
    randomised: st.randomized || 0, randomisedFree: st.randomisedFree || 0, clouds: st.clouds || 0, inClouds: st.inClouds || 0, visibleClouds: visK, randomMode: S.ui.random, randomHidden: st.randomHidden || 0,   // §8.8a
    groups: st.groups, bubbles: S.bubbles.size, visibleClients: vis, visibleAps: st.aps, alarms: st.alarms, hidden, revealed: S.revealed,
    bands: st.bands, bandsTotal: st.bandsT, security: Object.assign({}, S.security), fresh: Object.assign({}, st.fresh || freshZero()),
    freshClients: Object.assign({}, st.freshCl || freshZero()),   // D1 over the present stations (fresh stays APs only)
    events: eventsObj(), crowding: S.crowding.level, deviations: S.sky.dev.length, baseline: Object.assign({}, S.base), observations: S.obs.length, changeEntries: Array.from(S.chg.values()).reduce((a, x) => a + x.length, 0), watch: S.watch.length,
    hop: S.hop === null ? null : { channels: S.hop.length, busy: S.hop.filter(c => c.busy_pct != null).length }, own: { bssids: S.own.bssids.size, ssids: S.own.ssids.size },   // counts only, never the values
    theme: S.ui.theme, view: S.ui.view, mode: S.mode, source: S.source, generated: S.generated, centerLabel: S.centerLabel,
    sourceKind: S.sourceKind, sourceLabel: S.sourceLabel, liveFeed: S.liveFeed, stalePolls: S.stalePolls, captureStale: captureStale(), captureOffline: captureOffline(),
    fps: S.perf.fps, frameMs: r3(S.perf.frameMs), lod: S.perf.lod, dpr: r3(S.perf.dpr), dprStep: S.perf.dprStep, autoLod: S.ui.autoLod,
    nodes: S.nodeCount, sprites: spriteCache.size, spriteBytes, particles: particles.count, flares: flareCount(), travelDots: S.travelDots, probeArcs: S.probeArcs,
    labels: S.labelsList.length, twinkles: S.twinkles, interferencePairs: analyzer.pairs.length,
    blend: r3(S.view.blend), settling: S.settling, forcedAgg: aggForced(), themeErrors: S.themeErrors,
    storageFailed: storageState.failed, introShown: introSeen(), paused: S.ui.paused,
    devices: deviceClusterCount(), essMerged: essMergedCount(), affinity: st.probing || 0, identities: identityCounts(),
    library: { rules: S.rules.length, notes: S.notes.size }, chanMode: S.chanMode, coreBeat: r3(coreBeatScale()), threshold: S.threshold, recording: S.rec ? S.rec.docs.length : 0, replay: !!S.replay, drawer: S.dx,   // counts and modes only
    inventory: { rows: S.ui.inventory ? invApRows().rows.length : null, filter: Object.assign({}, S.inv.filter) },
    bluetooth: btStats(), glow: { stations: gl[0] + gl[1] + gl[2], max: GLOW.max, levels: gl }, activity: { channels: S.act.size, max: r3(Math.max(0, ...S.act.values())) } };   // §3.10
}
function legendRowsObj() {   // each #legend .legrow → kind, visibility, count, every painted colour + the token it reads, ring styles
  const mirror = new Map(CSS_MIRROR.map(m => [m[0], m[1]]));
  const norm = (c) => { if (c == null || c === "" || c === "none") return null; const p = parseColor(String(c)); return p[0] + "," + p[1] + "," + p[2] + "," + Math.round(p[3] * 100) / 100; };
  const paint = (e, prop, raw, css) => {
    const m = /^var\((--[\w-]+)\)$/.exec(String(raw || "").trim()), enc = e.getAttribute("data-enc");
    const tok = m ? (mirror.get(m[1]) || null) : enc ? "ENCODING." + enc : null;
    const v = m ? (tok ? resolveToken(tok) : null) : enc ? resolveToken(enc, ENCODING) : null;
    return { prop, raw: String(raw), tok, css: norm(css), val: v == null ? null : norm(v) };
  };
  return Array.from(legend.querySelectorAll(".legrow")).map(r => {
    const paints = [], rings = [];
    r.querySelectorAll("svg.sw *").forEach(e => {
      const cs = getComputedStyle(e);
      for (const prop of ["fill", "stroke"]) { const raw = e.getAttribute(prop); if (raw && raw !== "none") paints.push(paint(e, prop, raw, cs[prop])); }
      if (e.classList.contains("ring")) rings.push({ w: r3(parseFloat(cs.strokeWidth)), dash: cs.strokeDasharray === "none" ? [] : cs.strokeDasharray.split(/[\s,]+/).map(parseFloat).filter(Number.isFinite) });
    });
    r.querySelectorAll("span.sw").forEach(e => paints.push(paint(e, "background", e.style.backgroundColor, getComputedStyle(e).backgroundColor)));
    r.querySelectorAll(".glyph").forEach(e => { if (e.textContent) paints.push(paint(e, "color", e.style.color, getComputedStyle(e).color)); });
    const c = r.querySelector(".cnt");
    return { kind: r.dataset.kind || null, id: r.id || null, visible: !r.hidden, cnt: c && c.textContent !== "" ? +c.textContent : null, paints, rings };
  });
}
function deviceClusterCount() { let n = 0; S.devices.forEach(d => { if (d.memberIds.length >= 2) n++; }); return n; }
function essMergedCount() { let n = 0; if (S.ui.essMerge) S.essClusters.forEach((c, id) => { if (c.deviceIds.length >= 2 && !isEssExpanded(id)) n++; }); return n; }
function camObj() {
  const c = S.cam;
  return { az: r3(c.az), el: r3(c.el), dist: r3(c.dist), target: c.target.map(r3), locked: S.locked, autoRot: S.ui.rotate,
    ramp: r3(c.ramp), blend: r3(S.view.blend), zoom2d: r3(c.zoom2d), sky: r3(S.skyA), spin: S.ui.spin, tween: c.tween !== null };
}
// contrast hook — read-only, pure maths (no DOM, no clock, no randomness). A pair side is a token path
// ("ink.muted"), a CSS colour ("#rrggbb", "rgb()/rgba()"), the keyword "ground" (brightest of surface.base and the
// surface.gradient colour stops = the page behind un-haloed #bg text) or a layer list [top, …, bottom]. Layers
// composite bottom-up over surface.base (sRGB-space alpha like canvas/CSS, integer channels like the display); the fg
// composites over the resolved bg; a token whose value is a token path is followed once (none today).
// ratio = WCAG 2.x (relative luminance, 0.05 flare), rounded to 0.01; `pass` compares the unrounded ratio with `min`.
// [fg, bg, min, where]: the text pairs the contrast check covers (4.5) and the ring/mark pairs (3, D9). It is the checked
// set, not every token combination the page paints. Deliberately not listed (spec §14.4): ink.onFill on band fills
// (.btn.b*.on — Foundation b6 computes to 3.82:1) and on accent.selection (.btn.toggle.on), the classbar's
// white-on-dark-red banner, band.2.4.core used as text (#dtg, .cursor, #intro) and the ENCODING identity colours
// on .idbtn. Separate from the list: the WarGames CRT overlay sits above the panels and darkens panel text towards
// the screen corners (measured #leg-rx 3.34:1, #src-center 4.18:1).
const CONTRAST_PAIRS = [
  ["ink.primary", "surface.base", 4.5, "canvas: hovered/locked label, cursor"],
  ["ink.secondary", "surface.base", 4.5, "canvas: AP/centre/vendor label, client badge, device ×n"],
  ["ink.muted", "surface.base", 4.5, "canvas: 3D ring dBm label, group label, '?' glyph"],
  ["ink.muted", "ground", 4.5, "canvas: 2D ring dBm label (baked on #bg, no halo)"],
  ["status.ringNeutral", "surface.base", 4.5, "canvas: OWE glyph; WPA/WPA2/OWE ring"],
  ["status.ringStrong", "surface.base", 4.5, "canvas: WPA3 glyph; WPA3 ring"],
  ["status.alarm", "surface.base", 4.5, "canvas: alarm glyph; WEP ring"],
  ["ink.primary", "render.bubbleFill", 4.5, "canvas: bubble count"],
  ["ink.secondary", "render.bubbleFill", 4.5, "canvas: bubble caption"],
  ["ink.primary", "surface.panelFill", 4.5, "DOM: panel text"],
  ["ink.secondary", "surface.panelFill", 4.5, "DOM: labels, desc, legend counts; chanbar peak; sparkline value"],
  ["ink.muted", "surface.panelFill", 4.5, "DOM: notes, motto, #leg-rx, #src-center; chanbar/sparkline axis"],
  ["status.glyphInk", "surface.panelFill", 4.5, "DOM: legend glyph base colour (.legrow .glyph)"],
  ["status.alarm", "surface.panelFill", 4.5, "DOM: legend alarm glyph, paste error"],
  ["status.ringNeutral", "surface.panelFill", 4.5, "DOM: legend OWE glyph (neutral tone)"],
  ["status.ringStrong", "surface.panelFill", 4.5, "DOM: legend WPA3 glyph (strong tone)"],
  ["ink.secondary", ["line.hairlineSoft", "surface.panelFill"], 4.5, "DOM: .btn / .filebtn label"],
  ["ink.primary", ["line.hairlineSoft", "surface.panelFill"], 4.5, "DOM: .btn hover, live mode chip"],
  ["accent.selection", ["accent.selectionWash", "surface.panelFill"], 4.5, "DOM: demo mode chip"],
  ["line.ring", "surface.base", 3, "canvas: RSSI reference ring (2D #bg, 3D #sky)"],
  ["line.ring", "ground", 3, "canvas: RSSI reference ring over the page gradient"],
  ["status.hidden", "surface.base", 3, "canvas: hidden-SSID ring"],
  ["status.alert", "surface.base", 3, "canvas: alert ring"],
  ["render.bubbleStroke", "surface.base", 3, "canvas: bubble outline"],
  ["accent.selection", "surface.base", 3, "canvas: selection ring"],
  ["render.btMark", "surface.base", 3, "canvas: Bluetooth mark"],
  ["accent.focusRing", "surface.panelFill", 3, "DOM: keyboard focus outline"],
  ["ink.onFill", "ink.primary", 4.5, "DOM: active-scan chip"],
  ["accent.toggleInk", "accent.toggleOn", 4.5, "DOM: .btn.toggle.on label (D12)"],
  ["chrome.banner.ink", "chrome.banner.fill", 4.5, "DOM: classbar text (D12)"],
  ["chrome.ink", "surface.base", 4.5, "DOM: #dtg, .cursor, #intro, live chip (D12)"],
];
const CONTRAST_COLOR_RE = /^(#[0-9a-f]{6}|rgba?\(\s*[\d.]+\s*,\s*[\d.]+\s*,\s*[\d.]+\s*(,\s*[\d.]+\s*)?\))$/i;
function relLum(c) { const f = (v) => { v /= 255; return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }; return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2]); }
function contrastColor(spec, t) {   // token path | CSS colour | "ground" → [r, g, b, a] | null
  let v = typeof spec === "string" ? spec.trim() : null;
  if (v === "ground") {
    const base = contrastColor("surface.base", t); if (!base) return null;
    const under = base.slice(0, 3).map(Math.round), grad = resolveToken("surface.gradient", t);
    let best = under, bestL = relLum(under);
    for (const s of (typeof grad === "string" && grad.match(/#[0-9a-f]{6}\b|rgba?\([^)]*\)/gi)) || []) {
      const c = contrastStack(s, t, under), L = c ? relLum(c) : -1; if (L > bestL) { best = c; bestL = L; }
    }
    return [best[0], best[1], best[2], 1];
  }
  for (let hop = 0; v !== null && hop < 2 && !CONTRAST_COLOR_RE.test(v); hop++) { const r = resolveToken(v, t); v = typeof r === "string" ? r.trim() : null; }
  return v !== null && CONTRAST_COLOR_RE.test(v) ? parseColor(v) : null;
}
function contrastStack(spec, t, under) {   // [top … bottom] composited over the opaque `under` → [r, g, b] | null
  const layers = Array.isArray(spec) ? spec : [spec];
  let cur = under;
  for (let i = layers.length - 1; i >= 0; i--) {
    const c = contrastColor(layers[i], t); if (!c) return null;
    const a = clamp(c[3], 0, 1);
    cur = [0, 1, 2].map(k => Math.round(clamp(c[k], 0, 255) * a + cur[k] * (1 - a)));
  }
  return cur;
}
function contrastPairs(pairs, themeId) {
  const t = themeId == null ? THEME : (Object.prototype.hasOwnProperty.call(THEMES, themeId) ? THEMES[themeId] : null);
  if (!t) return { error: "unknown theme: " + themeId };
  let list = pairs ?? CONTRAST_PAIRS;
  if (!Array.isArray(list)) return { error: "pairs: expected [[fg, bg, min?], …]" };
  if (typeof list[0] === "string") list = [list];   // a single [fg, bg] pair
  const base = contrastColor("surface.base", t), under = base ? base.slice(0, 3).map(Math.round) : null;
  const hex = (c) => "#" + c.map(v => (v < 16 ? "0" : "") + v.toString(16)).join("");
  return list.map(p => {
    const ok = Array.isArray(p), fg = ok ? p[0] : null, bg = ok ? p[1] : null;
    const b = under && contrastStack(bg, t, under), f = b && contrastStack(fg, t, b);
    const o = { fg, bg, ratio: null };
    let r = null;
    if (f) { const x = relLum(f), y = relLum(b); r = (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); o.ratio = Math.round(r * 100) / 100; o.fgHex = hex(f); o.bgHex = hex(b); }
    else o.error = "unresolved " + (b ? "fg" : "bg");
    if (ok && p[2] != null) { o.min = p[2]; o.pass = r !== null && r >= p[2]; }
    if (ok && p[3] != null) o.what = p[3];
    return o;
  });
}
window.STARCHORUS = Object.freeze({
  version: "0.2.5",
  setTheme: (id) => guard(() => applyTheme(id, { intro: false })),
  getTheme: () => guard(() => S.ui.theme),
  setView: (v) => guard(() => setView(v)),
  getView: () => guard(() => ({ mode: S.ui.view, blend: r3(S.view.blend) })),
  setReducedMotion: (on) => guard(() => setReducedMotion(on)),
  load: (obj, label = "API", opts) => guard(() => loadData(obj, label, { mode: opts && opts.mode === "live" ? "live" : "recorded" })),   // D3/D4: {mode:"live"} = poll-fed
  loadDemo: () => guard(() => loadData(demoData(), "demo", { mode: "demo" })),
  pollNow: () => { try { return tryPoll(); } catch (e) { pushError(e); return Promise.resolve({ error: String(e) }); } },   // the regular poll, now (a POLL_MS tick); → {ok, fresh, stalePolls, captureStale, sourceKind}
  pollPlan: () => guard(pollPlanObj),   // D3: the cadence's state
  logonLines: () => guard(() => logonLines()),
  stats: () => guard(statsObj),
  layoutInfo: () => guard(layoutInfo),
  camera: () => guard(camObj),
  setCamera: (o, snap = true) => guard(() => {
    if (o) {
      if (o.az != null) S.cam.azT = S.cam.az = o.az;
      if (o.el != null) S.cam.elT = S.cam.el = o.el;
      if (o.dist != null) S.cam.distT = S.cam.dist = o.dist;
      if (o.target) { S.cam.target = o.target.slice(); S.cam.targetT = o.target.slice(); }
      S.cam.tween = null; S.dirty = true;
    }
    return camObj();
  }),
  resetCamera: () => guard(() => { resetCamera(); return camObj(); }),
  setZoom2d: (z) => guard(() => { setZoom2d(z); return camObj(); }),
  setToggles: (o) => guard(() => setToggles(o)),
  getToggles: () => guard(getToggles),
  select: (id) => guard(() => select(id)),
  deselect: () => guard(() => deselect()),
  hover: (x, y) => guard(() => { const id = nodeAt(x, y, false); setHover(id); return id; }),
  hoverNode: (id) => guard(() => {
    if (id == null) { setHover(null); return null; }
    const n = S.aps.get(id) || S.clients.get(id) || S.clouds.get(id);
    if (!n) return null;
    S.hover = id; showTip(n); positionTip(n, n.sx, n.sy);
    S.dirty = true;
    return id;
  }),
  hoverChannel: (band, ch) => guard(() => hoverChannelText(band, ch)),
  pin: (id, on) => guard(() => {
    const has = S.pinned.has(id);
    const want = on === undefined ? !has : !!on;
    if (want) S.pinned.add(id); else S.pinned.delete(id);
    S.dirty = true;
    return S.pinned.has(id);
  }),
  expandBubble: (id) => guard(() => expandBubble(id)),
  hitTest: (x, y) => guard(() => nodeAt(x, y, false)),
  node: (id) => guard(() => { const n = S.aps.get(id) || S.clients.get(id); return n ? pubNode(n) : pubCloud(S.clouds.get(id)); }),
  nodes: (filter) => guard(() => {
    const out = [];
    const push = (n, kind) => out.push({ id: n.id, kind, sx: r3(n.sx), sy: r3(n.sy), px: r3(n.px), zc: r3(n.zc), alphaDraw: r3(n.alphaDraw), visible: nodeVisible(n), bubble: n.bubble || null, vendor: n.vendor || null, width: n.kind === "ap" ? n.width : null, rssi: n.rssi });
    if (!filter || filter === "ap") S.aps.forEach(n => { if (n.target === 1) push(n, "ap"); });
    if (!filter || filter === "client" || filter === "free" || filter === "assoc") S.clients.forEach(n => { if (n.target !== 1) return; if (filter === "free" && !n.free) return; if (filter === "assoc" && n.free) return; push(n, "client"); });
    if (filter === "cloud") S.clouds.forEach(k => { if (k.target === 1) push(k, "cloud"); });
    if (filter === "bubble") S.bubbles.forEach(b => out.push({ id: b.id, kind: "bubble", sx: r3(b.sx), sy: r3(b.sy), px: r3(b.px), zc: r3(b.zc), alphaDraw: r3(b.alpha), visible: true, bubble: null, vendor: null, width: null, rssi: null }));
    return out;
  }),
  nodeScreen: (id) => guard(() => { const n = S.aps.get(id) || S.clients.get(id) || S.clouds.get(id) || S.bt.get(id); if (n) return { sx: r3(n.sx), sy: r3(n.sy), px: r3(n.px), zc: r3(n.zc), fog: r3(n.fog), visible: nodeVisible(n) }; const b = S.bubbles.get(id); if (b) return { sx: r3(b.sx), sy: r3(b.sy), px: r3(b.px), zc: r3(b.zc), fog: r3(b.fog), visible: b.alpha > 0.05 }; return null; }),
  clouds: () => guard(() => S.cloudOrder.map(pubCloud)),   // §8.8a
  expandCloud: (id) => guard(() => expandCloud(id)),
  bubbles: () => guard(() => { const out = []; S.bubbles.forEach(b => out.push({ id: b.id, n: b.n, sx: r3(b.sx), sy: r3(b.sy), r: r3(b.r), expanded: b.expandedUntil != null && b.expandedUntil > S.clock, members: b.members.slice() })); return out; }),
  labels: () => guard(() => S.labelsList.map(l => ({ id: l.id, kind: l.kind, text: l.text, x: l.x, y: l.y, sprite: !!l.sprite }))),   // sprite = baked once and blitted, so it costs no slot of RENDER.maxText
  labelCandidates: () => guard(() => labelCandidateList(labelDevCarriers()).map(n => n.id)),   // theme-free: see labelCandidateList
  legendRows: () => guard(legendRowsObj),
  channels: () => guard(() => { const o = { "2.4": {}, "5": {}, "6": {}, overlaps: analyzer.overlaps.map(p => ({ a: p.a, b: p.b, band: p.band, kind: p.kind, assumed: p.assumed })) }; for (const b of ["2.4", "5", "6"]) analyzer.channels[b].forEach((e, ch) => { o[b][ch] = e.count; }); return o; }),
  groups: () => guard(() => { const out = []; S.groups.forEach(g => { if (g.members.length >= 2) out.push({ key: g.key, members: g.members.slice(), bands: Array.from(g.bands) }); }); return out; }),
  devices: () => guard(() => { const out = []; S.devices.forEach(d => { if (d.memberIds.length >= 2) out.push(pubDevice(d)); }); out.sort((a, b) => cmpStr(a.id, b.id)); return out; }),
  deviceOf: (bssid) => guard(() => { const id = S.deviceOf.get(String(bssid).toLowerCase()); return id != null ? pubDevice(S.devices.get(id)) : null; }),
  essClusters: () => guard(() => { const out = []; S.essClusters.forEach((c, id) => { out.push({ ssid: c.ssid, id: c.id, deviceIds: c.deviceIds.slice(), apCount: c.apCount, expanded: isEssExpanded(id) }); }); out.sort((a, b) => cmpStr(a.id, b.id)); return out; }),
  expandEss: (id) => guard(() => expandEss(id)),
  setIdentity: (bssid, id) => guard(() => setIdentity(bssid, id)),
  identity: (bssid) => guard(() => identityOf(bssid)),
  identities: () => guard(() => { const o = {}; S.identity.forEach((v, k) => { o[k] = v; }); return o; }),
  hist: (bssid) => guard(() => { const h = S.hist.get(bssid) || (S.clouds.get(bssid) || {}).hist; if (!h) return null; const { s: samples, t } = histSamples(h), ts = t.map(v => Number.isFinite(v) ? v : null), valid = samples.filter(v => v !== -128); return { n: h.n, last: samples.length ? samples[samples.length - 1] : null, min: valid.length ? Math.min(...valid) : null, max: valid.length ? Math.max(...valid) : null, samples, ts }; }),
  themeAudit: (live) => guard(() => JSON.parse(JSON.stringify(live ? auditThemes() : themeAuditBoot))),   // boot audit (before any crash-guard fill) or a fresh one
  themeCheck: () => guard(() => { const cs = getComputedStyle(document.documentElement); const mm = []; for (const [name] of CSS_MIRROR) { const css = cs.getPropertyValue(name).trim(); const js = TD.css[name]; if (css !== js) mm.push([name, css, js]); } return { ok: mm.length === 0, mismatches: mm }; }),
  skyStats: () => guard(skyStatsObj),
  changes: (bssid) => guard(() => (S.chg.get(String(bssid).toLowerCase()) || []).map(c => Object.assign({}, c))),   // the AP's change log (DS channel / security class / SSID / band)
  baseline: () => guard(() => Object.assign({}, S.base)),
  setBaseline: () => guard(baselineSet),
  clearBaseline: () => guard(() => { baselineClear(); return true; }),
  observations: () => guard(() => S.obs.map(o => ({ group: o.group, text: o.text }))),
  watch: (ssid, on) => guard(() => ssid === undefined ? S.watch.slice() : watchSet(ssid, on)),
  dust: () => guard(dustObj),   // per freshness tier the mean dust radius and alpha
  skyLine: () => guard(skyLine),
  vault: () => guard(vaultObj),
  tote: () => guard(toteObj),
  plotClock: () => guard(plotClockObj),
  logonTiming: () => guard(() => THEME.motion.logonCharMs.slice()),
  bannerLines: () => guard(bannerLines),
  recvRing: () => guard(recvRingObj),   // {active, px, alpha} of the contracting receive ring at the current page clock
  lamps: () => guard(lampsObj),
  lampStrip: () => guard(lampStripObj),
  caption: () => guard(captionObj),       // the observer and the capture time, exactly as the caption says them
  badge: () => guard(() => { const b = el("mast-badge"); return b ? { shown: !b.hidden, text: b.textContent, kind: b.dataset.kind || null, title: b.title } : null; }),
  channelView: () => guard(channelModel),   // per band/channel count, max, peak hold, DFS, estimated beacon airtime, co/adjacent, probe activity, deviation
  airQuality: () => guard(airQuality),
  timeSeries: (scale) => guard(() => timeModel(scale)),
  setTimeScale: (sc) => guard(() => { if (TIME_SCALES[sc]) S.timeScale = sc; renderTime(); return S.timeScale; }),
  setThreshold: (dbm) => guard(() => setThreshold(dbm)),
  setChannelMode: (m) => guard(() => setChanMode(m)),
  waterfall: (band) => guard(() => waterfallModel(band || S.wfBand)),
  openDrawer: (name) => guard(() => { if (name === null || name === false) { S.dx = null; applyDrawer(); return null; } return ["air", "time", "rec"].indexOf(name) < 0 ? S.dx : (S.dx === name ? S.dx : setDx(name)); }),
  recording: () => guard(recObj),
  replay: (i) => guard(() => replayTo(i)),
  replayInfo: () => guard(replayObj),
  replayExit: () => guard(replayExit),
  clearRecording: () => guard(recClear),
  libraryImport: (text) => guard(() => libraryImport(text)),   // "MAC class" lines + OUI rules; any observed key accepted (AP or station), a rule may assign friend/neutral/suspect
  libraryExport: () => guard(libraryExport),
  libraryAssign: (cls, filter) => guard(() => libraryAssign(cls, filter)),
  notes: (bssid, patch) => guard(() => patch === undefined ? (S.notes.has(String(bssid).toLowerCase()) ? notesSet(bssid, {}) : null) : notesSet(bssid, patch)),
  identitySource: (bssid) => guard(() => identitySource(bssid)),
  exportText: (fmt) => guard(() => exportText(fmt === "csv" || fmt === "sitrep" ? fmt : "json")),   // local text, access points AND stations (with association + station_counts), footer in every format
  exportPng: () => guard(exportPng),
  homing: () => guard(() => S.homing ? Object.assign({}, S.homing) : null),
  openHoming: (on) => guard(() => { S.homeOpen = on === undefined ? !S.homeOpen : !!on; if (S.homeOpen) S.dx = null; applyDrawer(); return S.homeOpen; }),
  inventory: (filter) => guard(() => { if (filter !== undefined) { S.inv.filter = Object.assign({}, filter || {}); S.dirty = true; } return invApRows().rows.map(n => n.id); }),
  clearLocalData: () => guard(clearLocalData),   // P8: deletes every starchorus.* key this page writes
  contrast: (pairs, themeId) => guard(() => contrastPairs(pairs, themeId)),   // WCAG 2.x ratios, default = CONTRAST_PAIRS
  settle: (maxIter = 600) => guard(() => {
    S.layoutDirty = true;
    S.aps.forEach(n => { n.hexA = 0; });
    S.clientOrder.forEach(n => { n.orbitPhase = NaN; });
    settleLayout(maxIter);
    S.clients.forEach(n => { if (n.free) { n.wx = n.lx; n.wz = n.lz; n.placed = true; } });
    S.clouds.forEach(k => { k.wx = k.lx; k.wz = k.lz; k.placed = true; }); S.bt.forEach(k => { k.wx = k.lx; k.wz = k.lz; k.placed = true; });
    S.aps.forEach(n => { n.angle = n.angleT; n.radius = n.radiusT; n.wx = Math.cos(n.angle) * n.radius; n.wz = Math.sin(n.angle) * n.radius; });
    S.clients.forEach(n => {
      if (n.free) return;
      const ap = S.aps.get(n.parent);
      if (ap) { n.wx = ap.wx + Math.cos(n.orbitPhase) * n.orbitR / maxRadius; n.wz = ap.wz + Math.sin(n.orbitPhase) * n.orbitR / maxRadius; n.placed = true; }
    });
    computeGroupEdges(); projectAll(); render();
    return layoutInfo();
  }),
  frame: () => guard(() => { projectAll(); render(); S.perf.rendered++; }),
  wait: (ms) => new Promise(r => setTimeout(r, ms)),
  measure: (seconds = 2) => new Promise(res => {
    const t0 = performance.now();
    const startR = S.perf.rendered;
    let rafs = 0; let maxMs = 0;
    const samples = []; let last = t0;
    const loop = () => {
      const now = performance.now(); rafs++;
      const d = now - last; last = now;
      if (rafs > 1) { samples.push(d); if (d > maxMs) maxMs = d; }
      if (now - t0 < seconds * 1000) requestAnimationFrame(loop);
      else {
        samples.sort((a, b) => a - b);
        const p = (q) => samples.length ? samples[Math.min(samples.length - 1, Math.floor(q * samples.length))] : 0;
        res({ fps: Math.round(rafs * 1000 / (now - t0)), renderedFrames: S.perf.rendered - startR, rafFrames: rafs, p50Ms: r3(p(0.5)), p95Ms: r3(p(0.95)), maxMs: r3(maxMs), drawCalls: Object.assign({}, S.perf.drawCalls) });
      }
    };
    requestAnimationFrame(loop);
  }),
  perf: () => guard(() => {
    const s = S.perf.samples.slice().sort((a, b) => a - b);
    const p = (q) => s.length ? s[Math.min(s.length - 1, Math.floor(q * s.length))] : 0;
    return { frameMs: { ema: r3(S.perf.frameMs), p50: r3(p(0.5)), p95: r3(p(0.95)), max: r3(s.length ? s[s.length - 1] : 0) }, fps: S.perf.fps, lod: S.perf.lod, dpr: r3(S.perf.dpr), drawCalls: Object.assign({}, S.perf.drawCalls) };
  }),
  setFixedTime: (ms) => guard(() => { S.fixedTime = ms == null ? null : +ms; dtgTick(); S.dirty = true; }),
  skipIntro: () => guard(() => skipIntro()),
  pixel: (id, x, y) => guard(() => {
    const m = { bg: [ctxBg, S.perf.dpr], sky: [ctxSky, S.perf.dpr], hud: [ctxHud, hudDpr] }[id];
    if (!m) return { r: 0, g: 0, b: 0, a: 0 };
    const d = m[1];
    const px = m[0].getImageData(Math.round(x * d), Math.round(y * d), 1, 1).data;
    return { r: px[0], g: px[1], b: px[2], a: px[3] };
  }),
  particleDigest: () => guard(() => particleDigest()),
  storageDump: () => guard(() => readStored()),
  resetStorage: () => guard(() => safeStorage.remove(STORAGE_KEY)),
  errors: () => guard(() => S.errors.slice()),
  edgeLayout: () => guard(() => Object.assign({}, layoutEdges())),
  phone: () => guard(() => Object.assign({ on: phoneOn, sky: { cx: r3(CX), cy: r3(CY), r: r3(maxRadius) } }, phoneOn ? layoutEdges().sheet : {})),   // §9.8
  setSheet: (d) => guard(() => setSheet(d)),
  setPanels: (on) => guard(() => setPanels(on)),
  _internals: query.debug1 ? { S, THEMES, TK, TD, LAYOUT, AGG, CFG3D, RENDER, spriteCache, particles, SC, SCOPE } : undefined,
});

