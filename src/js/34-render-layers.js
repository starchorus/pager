// ==== 34 RENDER LAYERS ====
function blit(ctx, s, sx, sy, px) {
  const scale = s.tier > 0 ? px / s.tier : 1;
  const w = s.w * scale, h = s.h * scale;
  dI(ctx, s.c, sx - w / 2, sy - h / 2, w, h);
}
function blitFixed(ctx, s, sx, sy) { dI(ctx, s.c, sx - s.w / 2, sy - s.h / 2, s.w, s.h); }
function rebuildBackground() {
  if (!W || !H) return;
  const ctx = ctxBg, d = S.perf.dpr;
  ctx.setTransform(d, 0, 0, d, 0, 0);
  ctx.clearRect(0, 0, W, H);
  ctx.globalAlpha = 1;
  const sf = THEME.render.starfield;
  if (sf.density > 0) {
    const rnd = mulberry32(0x5EED), n = Math.floor(W * H / sf.density);
    ctx.fillStyle = sf.color;
    for (let i = 0; i < n; i++) { const x = rnd() * W, y = rnd() * H, a = lerp(sf.alpha[0], sf.alpha[1], rnd()); ctx.globalAlpha = a; ctx.fillRect(x, y, 1, 1); }
    ctx.globalAlpha = 1;
  }
  if (scopeOn) { drawScopeBg(ctx); return; }
  bgZoom = S.cam.zoom2d;
  if (tS !== 0) return;   // rings/grid/labels are baked into #bg only in 2D; 3D draws projected rings on #sky (drawRings)
  const z = bgZoom, R = maxRadius * z;   // the RSSI reference scales with zoom2d about the device, so rings and field always agree
  ctx.strokeStyle = THEME.line.ring; ctx.lineWidth = 1;   // D9: reference rings >= 3:1; spokes/grid stay line.hairline
  for (const dbm of LAYOUT.rings) { const r = rssiToRadius(dbm) * z; ctx.beginPath(); ctx.arc(CX, CY, r, 0, Math.PI * 2); ctx.stroke(); }
  const g = THEME.render.grid;
  ctx.strokeStyle = THEME.line.hairline;
  if (g.spokes > 0) { ctx.beginPath(); for (let i = 0; i < g.spokes; i++) { const a = i / g.spokes * Math.PI * 2; ctx.moveTo(CX, CY); ctx.lineTo(CX + Math.cos(a) * R, CY + Math.sin(a) * R); } ctx.stroke(); }
  if (g.dotStepPx > 0) { ctx.fillStyle = THEME.line.hairline; const st = g.dotStepPx; for (let x = CX % st; x < W; x += st) for (let y = CY % st; y < H; y += st) { const dx = x - CX, dy = y - CY; if (dx * dx + dy * dy <= R * R) ctx.fillRect(x, y, 1, 1); } }
  ctx.font = TD.fontHud; ctx.fillStyle = THEME.ink.muted; ctx.textAlign = "left"; ctx.textBaseline = "alphabetic";
  for (const dbm of LAYOUT.rings) { const r = rssiToRadius(dbm) * z; ctx.fillText(dbm + " dBm", CX + 3, CY - r - 3); }
}
function drawScopeBg(c) {
  const g = SC.g; if (!g || !g.lanes) return;
  const edge = (k) => scL(c, t => scXY(g, g.rNear + (g.rFar - g.rNear) * t, k)), ring = (r) => scL(c, t => scXY(g, r, 2 * t - 1));
  c.lineWidth = 1;
  c.strokeStyle = THEME.line.hairline; for (const l of g.lanes.slice(1)) edge(l.k0 - SCOPE.gap / 2);
  c.strokeStyle = THEME.line.ring; for (const d of LAYOUT.rings) ring(scR(g, d));
  c.strokeStyle = THEME.line.baseline; c.setLineDash(SC.lv === "live" ? [] : [4, 4]); ring(g.rFar); ring(g.rNear); edge(-1); edge(1); c.setLineDash([]);
  c.font = TD.fontLabel; c.textAlign = "center";
  let lx = -1e9;
  for (const l of g.lanes) {
    const tk = SCOPE.ticks[l.key], wpx = Math.abs(scXY(g, g.rFar, l.k1)[0] - scXY(g, g.rFar, l.k0)[0]), p = scXY(g, g.rFar + (tk ? 26 : 10), (l.k0 + l.k1) / 2), nm = l.key === "sta" ? THEME.copy.scope.strip[1] : l.key === "bt" ? "BT" : l.key === "6" && SC.unk ? "6 · ?" : ENCODING.band[l.key].legend;
    c.fillStyle = THEME.ink.muted; for (const ch of tk || []) { const t = scXY(g, g.rFar + 8, l.k0 + (SCOPE.pad + (1 - 2 * SCOPE.pad) * scU(l.key, ch)) * (l.k1 - l.k0)), w = textWidth(c, c.font, ch) / 2; if (t[0] - w < lx + 3) continue; lx = t[0] + w; c.fillText(ch, t[0], t[1]); }
    c.fillStyle = THEME.ink.secondary; for (const t of [nm, nm.split(" ")[0]]) { const s = TD.upper ? t.toUpperCase() : t; if (textWidth(c, c.font, s) <= wpx + 8) { c.fillText(s, p[0], p[1]); break; } }
  }
  c.textAlign = "left"; c.fillStyle = THEME.ink.muted;
  LAYOUT.rings.forEach((d, i) => { const e = scXY(g, scR(g, d), 1), s = i ? String(d) : d + " dBm", w = textWidth(c, c.font, s), o = e[0] + 7 + w <= W - 4; c.fillText(s, o ? e[0] + 7 : e[0] - 5 - w, o ? e[1] + 4 : e[1] - 6); });
}
const wavePhase = () => SC.ph ?? (reduceMotion || S.ui.paused || S.fixedTime != null ? 1 : clamp((S.clock - SC.t0) / SC.dur, 0, 1));
function scopeWave() { SC.t0 = S.clock; SC.dur = clamp(2 * THEME.motion.fadeInMs, 1200, 1800) / 1000; }
function drawScope() {
  const g = SC.g, ctx = ctxSky; if (!g) return;
  const p = wavePhase(), rf = g.rFar - (g.rFar - g.rNear) * p, lv = SC.lv, cx = CX, cy = CY;
  SC.sf = Math.floor(S.clock * 2);
  for (const M of [S.aps, S.clients, S.clouds, S.bt]) for (const n of M.values()) {
    const s = n.sc;
    if (!s || s.st !== SC.st || (s.nw && p < s.q)) { n.alphaDraw = 0; continue; }
    n.sx = s.x; n.sy = s.y; n.px = s.px; n.fog = n.zc = 1;
    n.alphaDraw = (n.target === 1 ? 1 : n.alpha) * (isForced(n.id) ? 1 : SCOPE.rest);
  }
  if (p < 1) {
    ctx.strokeStyle = THEME.accent.selection;
    for (const [d, w, al] of SCOPE.arcs) if (rf + d <= g.rFar + 1) { ctx.lineWidth = w; setAlpha(ctx, al); scL(ctx, t => scXY(g, rf + d, 2 * t - 1)); }
    setAlpha(ctx, 1);
  }
  CX = g.ox; CY = g.py;
  drawGlows(); drawClients(); drawClouds(); drawBt(); drawStars(); drawChangeCues(); drawRecvRing();
  if (lv !== "live") {
    const w = g.b.w, h = g.py - g.top, rnd = mulberry32(reduceMotion ? 1 : 1 + (SC.sf & 1));
    ctx.fillStyle = THEME.ink.muted; setAlpha(ctx, 0.8);
    for (let i = w * h / SCOPE.snow[lv === "stale" ? 0 : 1]; i-- > 0;) ctx.fillRect(g.b.x + (rnd() * w | 0), g.top + (rnd() * h | 0), 1, 1);
    setAlpha(ctx, 1);
  }
  drawHud();
  CX = cx; CY = cy;
}
let bg3dState = null, bgZoom = 1;
function drawBackground() {
  const want3d = tS > 0;
  if (bg3dState !== want3d || (!want3d && bgZoom !== S.cam.zoom2d)) { bg3dState = want3d; rebuildBackground(); }
  if (want3d) { const c = S.cam, ox = -Math.sin(c.az) * CFG3D.parallaxPx * tS, oy = -(c.el - CFG3D.el) * CFG3D.parallaxPx * tS; canvasBg.style.transform = "translate(" + ox.toFixed(2) + "px," + oy.toFixed(2) + "px)"; }
  else if (canvasBg.style.transform) canvasBg.style.transform = "";
}
// one point of a projected ground-plane (y = 0) polyline; the pen lifts where a point is not visible
function groundXZ(ctx, x, z, tmp, pen) {
  projPt(x, 0, z, tmp);
  if (!tmp.vis) return false;
  if (pen) ctx.lineTo(tmp.sx, tmp.sy); else ctx.moveTo(tmp.sx, tmp.sy);
  return true;
}
// the unit circle at the 65 ring steps, once: the very doubles Math.cos / Math.sin give for θ = i / 64 · 2π
const RING_COS = new Float64Array(65), RING_SIN = new Float64Array(65);
for (let i = 0; i <= 64; i++) { const th = i / 64 * (Math.PI * 2); RING_COS[i] = Math.cos(th); RING_SIN[i] = Math.sin(th); }
function drawRings() {
  if (tS <= 0) return;
  const ctx = ctxSky, tmp = {};
  cameraBasis();
  ctx.lineWidth = 1;
  setAlpha(ctx, 1); ctx.strokeStyle = THEME.line.ring;   // D9
  for (const dbm of LAYOUT.rings) { const rad = rssiToRadius(dbm) / maxRadius; ctx.beginPath(); let pen = false; for (let i = 0; i <= 64; i++) pen = groundXZ(ctx, RING_COS[i] * rad, RING_SIN[i] * rad, tmp, pen); sT(ctx); }
  const g = THEME.render.grid;
  if (g.spokes > 0) {
    ctx.strokeStyle = THEME.line.hairline; ctx.beginPath();
    for (let i = 0; i < g.spokes; i++) { const a = i / g.spokes * Math.PI * 2; projPt(0, 0, 0, tmp); if (!tmp.vis) continue; ctx.moveTo(tmp.sx, tmp.sy); projPt(Math.cos(a), 0, Math.sin(a), tmp); if (tmp.vis) ctx.lineTo(tmp.sx, tmp.sy); }
    sT(ctx);
  }
  // plumb lines (APs at LOD ≤ 1, bubbles, hover/locked/pinned)
  const lod = S.perf.lod, tmp2 = {};
  ctx.strokeStyle = THEME.line.hairlineSoft; setAlpha(ctx, CFG3D.plumbAlpha * tS);
  ctx.beginPath();
  const plumb = (n) => { if (!n.p) return; projPt(n.p[0], n.p[1], n.p[2], tmp); projPt(n.p[0], 0, n.p[2], tmp2); if (tmp.vis && tmp2.vis) { ctx.moveTo(tmp.sx, tmp.sy); ctx.lineTo(tmp2.sx, tmp2.sy); } };
  const forced = anyForced();
  if (lod <= 1 || forced) S.aps.forEach(n => { if (n.alphaDraw <= 0.02) return; if (lod <= 1 || isForced(n.id)) plumb(n); });
  S.bubbles.forEach(b => { if (b.alpha > 0.02) plumb(b); });
  if (forced) S.clients.forEach(n => { if (n.alphaDraw > 0.02 && isForced(n.id)) plumb(n); });
  sT(ctx); setAlpha(ctx, 1);
}
function drawShadows() {
  if (tS <= 0.5 || S.perf.lod >= 2) return;
  const ctx = ctxSky, tmp = {}, sinEl = Math.max(0.05, Math.sin(S.cam.el));
  ctx.fillStyle = THEME.render.shadow;
  const foot = (n) => { if (!n.p) return; projPt(n.p[0], 0, n.p[2], tmp); if (!tmp.vis) return; const r = n.px * 0.8; setAlpha(ctx, (n.fog ?? 1) * tS); ctx.beginPath(); ctx.ellipse(tmp.sx, tmp.sy, r, r * sinEl, 0, 0, Math.PI * 2); ctx.fill(); };
  S.aps.forEach(n => { if (n.alphaDraw > 0.02) foot(n); });
  S.bubbles.forEach(b => { if (b.alpha > 0.02) foot(b); });
  setAlpha(ctx, 1);
}
function drawNebula() {   // §8.2 Layer 3 — neutral interference wash between colliding stars (drawn only when toggled)
  if (!S.ui.nebula || !analyzer.pairs.length) return;
  const ctx = ctxSky, sprite = getSprite("nebula", "nebula", 0, "sharp");
  // D17: theme-free; the alpha carries the overlap score, so it never breathes, and the three dashed cross-strokes
  // read as derived, not measured, in every theme.
  const baseA = 0.11;
  ctx.globalCompositeOperation = "source-over";
  for (const p of analyzer.pairs) {
    const a = S.aps.get(p.a), b = S.aps.get(p.b);
    if (!a || !b || a.alphaDraw <= 0.02 || b.alphaDraw <= 0.02) continue;
    const dx = b.sx - a.sx, dy = b.sy - a.sy, len = hyp(dx, dy);
    const mx = (a.sx + b.sx) / 2, my = (a.sy + b.sy) / 2, ang = Math.atan2(dy, dx);
    const L = Math.max(20, len * 0.9), Wd = 18 + 22 * Math.min(1, p.score);
    const fog = Math.min(a.fog ?? 1, b.fog ?? 1);
    ctx.save();
    ctx.translate(mx, my); ctx.rotate(ang);
    ctx.globalAlpha = clamp(baseA * Math.min(1, p.score) * (tS > 0 ? fog : 1), 0, 1);
    dI(ctx, sprite.c, -L / 2, -Wd / 2, L, Wd);
    ctx.globalAlpha = clamp(baseA * 1.5 * Math.min(1, p.score), 0, 1);
    ctx.strokeStyle = THEME.render.nebula; ctx.lineWidth = 1; ctx.setLineDash([2, 3]);
    for (let i = -1; i <= 1; i++) { const x = i * L * 0.22; ctx.beginPath(); ctx.moveTo(x, -Wd / 2); ctx.lineTo(x, Wd / 2); ctx.stroke(); }
    ctx.setLineDash([]);
    ctx.restore();
  }
  ctx.globalAlpha = 1; curAlpha = 1;
}
function drawConstellations() {   // §8.6 Layer 4 — same-ESSID MST edges (hairline); labels drawn in drawHud
  if (!S.ui.groups || !S.groups.size) return;
  const ctx = ctxSky;
  setAlpha(ctx, 1);
  ctx.strokeStyle = THEME.line.hairlineSoft; ctx.lineWidth = 1;
  let drew = false; ctx.beginPath();
  S.groups.forEach(g => {
    if (g.members.length < 2 || isEssFoldedSet(g.key)) return;   // §8.8 folded ESS: no inner constellation lines
    for (const e of g.edges) {
      const a = S.aps.get(g.members[e[0]]), b = S.aps.get(g.members[e[1]]);
      if (!a || !b || a.alphaDraw <= 0.05 || b.alphaDraw <= 0.05) continue;
      ctx.moveTo(a.sx, a.sy); ctx.lineTo(b.sx, b.sy); drew = true;
    }
  });
  if (drew) sT(ctx);
  const hg = S.hover ? (S.aps.get(S.hover) || {}).groupKey : null;   // hover lifts the whole set to solid hairline
  if (hg && !isEssFoldedSet(hg)) { const g = S.groups.get(hg); if (g && g.members.length >= 2) { ctx.strokeStyle = THEME.line.hairline; let d2 = false; ctx.beginPath(); for (const e of g.edges) { const a = S.aps.get(g.members[e[0]]), b = S.aps.get(g.members[e[1]]); if (a && b) { ctx.moveTo(a.sx, a.sy); ctx.lineTo(b.sx, b.sy); d2 = true; } } if (d2) sT(ctx); } }
}
function drawDeviceLinks() {   // §8.8 thin ties between sibling radios of one physical AP; look ONLY via tokens
  if (!S.ui.deviceLinks || !S.devices.size || S.perf.lod >= 3) return;
  const ctx = ctxSky, bracket = THEME.render.deviceTie === "bracket";
  ctx.strokeStyle = THEME.line.device; ctx.lineWidth = 1;
  S.devices.forEach(dev => {
    const hub = S.aps.get(deviceHubId(dev)); if (!hub || hub.alphaDraw <= 0.05) return;
    for (const mid of dev.memberIds) {
      if (mid === hub.id) continue;
      const m = S.aps.get(mid); if (!m || m.alphaDraw <= 0.05) continue;
      setAlpha(ctx, 0.9 * Math.min(hub.alphaDraw, m.alphaDraw));
      ctx.beginPath();
      if (bracket) {
        const my = (hub.sy + m.sy) / 2;
        ctx.moveTo(hub.sx, hub.sy); ctx.lineTo(hub.sx, my); ctx.lineTo(m.sx, my); ctx.lineTo(m.sx, m.sy);
      } else {
        const x0 = hub.sx, y0 = hub.sy, x1 = m.sx, y1 = m.sy, dx = x1 - x0, dy = y1 - y0, len = Math.hypot(dx, dy) || 1;
        const nx = -dy / len, ny = dx / len, cv = 0.18;
        ctx.moveTo(x0, y0); ctx.quadraticCurveTo((x0 + x1) / 2 + nx * cv * len, (y0 + y1) / 2 + ny * cv * len, x1, y1);
      }
      sT(ctx);
    }
  });
  setAlpha(ctx, 1);
}
// hub / label carrier of a device = strongest member that is currently drawn (a band-filtered lead hands over)
function deviceHubId(dev) {
  let best = null;
  for (const mid of dev.memberIds) {
    const a = S.aps.get(mid); if (!a || a.alphaDraw <= 0.05) continue;
    if (!best || rssiOf(a) > rssiOf(best)) best = a;
  }
  return best ? best.id : dev.leadId;
}
function rssiOf(n) { return n.rssi ?? -999; }   // sort key: an unknown signal ranks last
function drawGlows() {
  if (!TD.glowOn) return;
  const ctx = ctxSky, a = S.anim;
  const breathe = !reduceMotion && a.breathePeriodS > 0 && a.breatheAmp > 0;   // §7.2 idle breathing
  ctx.globalCompositeOperation = THEME.render.composite;
  for (const ap of S.apOrder) {
    if (ap.alphaDraw <= 0.02) continue;
    const soft = TD.bokehSoft && (tS > 0 ? ap.fog < 0.6 : rssiT(ap.rssi) < 0.25);
    const tier = tierFor(ap.px), colorKey = TD.bandColorKey[ap.band] || "unknown";
    const s = getSprite("glow", colorKey, tier, soft ? "soft" : "sharp");
    let bpx = ap.px;
    if (breathe) bpx *= 1 + a.breatheAmp * Math.sin(2 * Math.PI * S.clock / a.breathePeriodS + ap.phase);
    let al = ap.alphaDraw;
    if (THEME.render.changeCue === "glowPulse" && !reduceMotion) { const cq = cueAge(ap); if (cq >= 0) { al = Math.min(1, al * (1 + 0.6 * ap.cueAmp * (1 - cq))); if (S.countCalls) DC.cue++; } }   // D18 glowPulse
    setAlpha(ctx, al); blit(ctx, s, ap.sx, ap.sy, bpx);
  }
  setAlpha(ctx, 1);
  ctx.globalCompositeOperation = "source-over";
}
function bezPt(x0, y0, cx, cy, x1, y1, t) {
  const mt = 1 - t;
  return [mt * mt * x0 + 2 * mt * t * cx + t * t * x1, mt * mt * y0 + 2 * mt * t * cy + t * t * y1];
}
function drawEdges() {
  S.travelDots = 0; S.probeArcs = 0;
  if (THEME.line.edge.style === "parabola") drawEdgesWargames();
  else drawEdgesBezier();
}
// every drawn association link (client → its drawn AP); at LOD >= 2 only the forced ones
function eachLink(fn) {
  const forcedOnly = S.perf.lod >= 2;
  if (forcedOnly && !anyForced()) return;
  for (const c of S.clientOrder) {
    if (c.free || c.affinity || c.alphaDraw <= 0.05) continue;
    const ap = S.aps.get(c.parent); if (!ap || ap.alphaDraw <= 0.05) continue;
    if (forcedOnly && !isForced(c.id) && !isForced(ap.id)) continue;
    fn(c, ap);
  }
}
function strokeLinks(ctx) {   // the link path twice: soft 3 px glow @ .25 (no shadowBlur), then the 1 px line
  setAlpha(ctx, 1);
  ctx.lineWidth = 3; ctx.strokeStyle = TD.edgeGlow; sT(ctx);
  ctx.lineWidth = 1; ctx.strokeStyle = TD.edgeStroke; sT(ctx);
}
function drawEdgesBezier() {
  if (!S.ui.links || THEME.line.edge.style !== "bezier") return;   // Foundation Bézier connectors
  const ctx = ctxSky, curv = THEME.line.edge.curvature;
  let n = 0;
  ctx.beginPath();
  eachLink((c, ap) => {
    const x0 = c.sx, y0 = c.sy, x1 = ap.sx, y1 = ap.sy, dx = x1 - x0, dy = y1 - y0, len = hyp(dx, dy) || 1;
    const side = hash(c.id) > 0.5 ? 1 : -1, nx = -dy / len, ny = dx / len;
    const cxp = (x0 + x1) / 2 + nx * curv * len * side, cyp = (y0 + y1) / 2 + ny * curv * len * side;
    ctx.moveTo(x0, y0); ctx.quadraticCurveTo(cxp, cyp, x1, y1); n++;
  });
  if (n > 0) strokeLinks(ctx);
}
// Wargames: parabolic arcs (control point screen-up), AP→client travel dots, passive probe arcs to core.
function drawEdgesWargames() {
  const ctx = ctxSky, curv = THEME.line.edge.curvature;
  const rm = reduceMotion, spd = S.anim.edgeTravelDotSpeed, dots = [];
  const travel = (id) => rm ? 0.5 : (((S.clock * spd + hash(id)) % 1) + 1) % 1;   // a dot's place on its arc, 0..1
  // (1) connection arcs with travel dots (associated clients)
  if (S.ui.links) {
    let n = 0; ctx.beginPath();
    eachLink((c, ap) => {
      const x0 = ap.sx, y0 = ap.sy, x1 = c.sx, y1 = c.sy, chord = hyp(x1 - x0, y1 - y0) || 1;
      const mx = (x0 + x1) / 2, my = (y0 + y1) / 2 - curv * chord;   // control point always screen-up
      ctx.moveTo(x0, y0); ctx.quadraticCurveTo(mx, my, x1, y1); n++;
      const p = bezPt(x0, y0, mx, my, x1, y1, travel(c.id));   // AP → client
      dots.push([p[0], p[1], "neutral"]); S.travelDots++;   // D17: travel dots are Look — neutral in every theme, the link itself is neutral too
    });
    if (n > 0) strokeLinks(ctx);
  }
  // (2) passive probe arcs (client/bubble → core), only in probeArc themes
  if (THEME.render.probeArc) {
    const born = [], seen = new Set();
    // persistent arcs for hovered / locked free clients and bubbles
    for (const id of [S.hover, S.locked]) {
      if (id == null || seen.has(id)) continue;
      const c = S.clients.get(id);
      if (c && c.free && c.alphaDraw > 0.02) { born.push({ node: c, age: -1, key: "neutral" }); seen.add(id); continue; }
      const b = S.bubbles.get(id);
      if (b && b.alpha > 0.05) { born.push({ node: b, age: -1, key: "neutral" }); seen.add(id); }
    }
    // appearance arcs (1.2 s), suppressed under reduced motion; capped 12 strongest (RSSI)
    if (!rm) {
      const appear = [];
      for (const c of S.clientOrder) {
        if (!c.free || c.alphaDraw <= 0.05 || seen.has(c.id)) continue;
        if (THEME.render.arrivalArcs && (c.newSeq !== S.captureSeq || S.captureSeq < 2 || c.newT0 == null)) continue;   // an arc is an arrival — not every poll's re-born node
        const age = S.clock - (THEME.render.arrivalArcs ? c.newT0 : c.born); if (age < 0 || age >= 1.2) continue;
        appear.push({ node: c, age, key: "neutral", rssi: c.rssi ?? -100 });
      }
      if (!THEME.render.arrivalArcs) S.bubbles.forEach(b => {
        if (b.alpha <= 0.05 || seen.has(b.id)) return;
        const age = S.clock - b.born; if (age < 0 || age >= 1.2) return;
        appear.push({ node: b, age, key: "neutral", rssi: b.meanRssi ?? -100 });
      });
      appear.sort((a, b) => b.rssi - a.rssi);
      for (let i = 0; i < Math.min(12, appear.length); i++) born.push(appear[i]);
    }
    for (const arc of born) {
      const node = arc.node, x0 = node.sx, y0 = node.sy, x1 = CX, y1 = CY, chord = Math.hypot(x1 - x0, y1 - y0) || 1;
      const mx = (x0 + x1) / 2, my = (y0 + y1) / 2 - curv * chord;
      const persistent = arc.age < 0, u = persistent ? travel(node.id) : arc.age / 1.2;
      const alpha = persistent ? 0.45 : 0.45 * (1 - arc.age / 1.2);
      ctx.beginPath(); ctx.moveTo(x0, y0); ctx.quadraticCurveTo(mx, my, x1, y1);
      setAlpha(ctx, alpha); ctx.lineWidth = 1; ctx.strokeStyle = TD.edgeStroke; sT(ctx);
      if (!rm || persistent) { const p = bezPt(x0, y0, mx, my, x1, y1, u); dots.push([p[0], p[1], arc.key]); }   // dot runs client → centre
      S.probeArcs++;
    }
    setAlpha(ctx, 1);
  }
  // (3) all travel/probe dots as baked bloom sprites (drawImage → no live shadowBlur)
  if (dots.length) {
    setAlpha(ctx, 1);
    for (const d of dots) blitFixed(ctx, getSprite("dot", d[2], 2, "sharp"), d[0], d[1]);
  }
}
function drawOrbits() {   // §4.3 Layer 7 — trailing 60° arc behind each orbiting client; associated solid, probe orbit dashed
  if (!S.ui.orbits || S.perf.lod > 1 || (S.view.blend > 0.02 && S.view.blend < 0.98)) return;
  const ctx = ctxSky, is3d = tS >= 0.5, z = S.cam.zoom2d, span = Math.PI / 3, SEG = 8;
  for (let pass = 0; pass < 2; pass++) {
    let n = 0; ctx.beginPath();
    for (const c of S.clientOrder) {
      if (c.free || !!c.affinity !== (pass === 1) || c.alphaDraw <= 0.05 || c.orbitR == null) continue;
      if (c.bubble != null && c.bubbleBlend > 0.5) continue;
      const ap = S.aps.get(c.parent); if (!ap || ap.alphaDraw <= 0.05) continue;
      const dir = c.orbitSpeed >= 0 ? 1 : -1, a1 = c.orbitPhase, a0 = a1 - dir * span;
      if (!is3d) {
        const r = c.orbitR * z, b0 = a0 + S.skyA, b1 = a1 + S.skyA;   // phases are world angles; the sky spin turns them on screen
        ctx.moveTo(ap.sx + Math.cos(b0) * r, ap.sy + Math.sin(b0) * r); ctx.arc(ap.sx, ap.sy, r, b0, b1, dir < 0);
      } else {
        const R = c.orbitR / maxRadius, i = c.orbitTilt || 0, hex = (ap.orbitCount ?? ap.clientCount) >= LAYOUT.hexAbove, o = ap.p;   // ap.p: spun + eased, like the dots
        let started = false;
        for (let k = 0; k <= SEG; k++) {
          const ph = a0 + (a1 - a0) * k / SEG;
          if (hex) skyPt(o, Math.cos(ph) * R, CFG3D.hexY, Math.sin(ph) * R, _pp);
          else skyPt(o, R * Math.cos(ph), R * Math.sin(ph) * Math.sin(i), R * Math.sin(ph) * Math.cos(i), _pp);
          if (!_pp.vis) { started = false; continue; }
          if (started) ctx.lineTo(_pp.sx, _pp.sy); else { ctx.moveTo(_pp.sx, _pp.sy); started = true; }
        }
      }
      n++;
    }
    if (!n) continue;
    setAlpha(ctx, pass === 1 ? 0.85 : 1); ctx.lineWidth = 1;
    if (pass === 1) { ctx.strokeStyle = THEME.line.device; ctx.setLineDash([2, 3]); } else ctx.strokeStyle = THEME.line.hairlineSoft;
    sT(ctx); ctx.setLineDash([]);
  }
  setAlpha(ctx, 1);
}
function drawClients() {
  const ctx = ctxSky, lod = S.perf.lod;
  ctx.fillStyle = THEME.render.clientCore;
  for (const c of S.clientOrder) {
    if (c.alphaDraw <= 0.02) continue;
    const forced = isForced(c.id);
    let sx = c.sx, sy = c.sy, px = c.px, alpha = c.alphaDraw;
    if (c.bubble != null && c.bubbleBlend > 0.001 && !scopeOn) {
      if (c.bubbleBlend >= 0.98 && !forced) continue;
      const b = S.bubbles.get(c.bubble);
      if (b) { const s = smoothstep(0, 1, c.bubbleBlend); sx = lerp(c.sx, b.sx, s); sy = lerp(c.sy, b.sy, s); alpha = c.alphaDraw * (1 - c.bubbleBlend); px = c.px * (1 - 0.4 * c.bubbleBlend); }
    }
    const asRect = !forced && (lod >= 3 || (lod >= 2 && !(px >= 4 && c.fog >= 0.5)));
    // D1: freshness (freshA) dims the dot only, as it dims the star; the lodRect floor keeps a far station legible.
    if (asRect) { setAlpha(ctx, Math.max(alpha, 0.85) * c.freshA); fR(ctx, sx - 1.5, sy - 1.5, RENDER.lodRectPx, RENDER.lodRectPx); }
    else {
      const tier = tierFor(px);
      const kind = (c.free || c.affinity) ? TD.clientKind : (TD.clientKind === "clientCross" ? "clientCross" : "clientAssoc");
      const colorKey = (c.free || c.affinity) ? "client" : (TD.bandColorKey[c.band] || "unknown");   // D8: band ring only for real association (probe orbits are derived)
      const rm = c.randomized ? THEME.render.clientRandomizedMark : null;   // D8: hollow | crossX
      const variant = kind === "clientCross" ? "L" + (c.rssi == null ? 2 : signalLevel(c.rssi)) + (rm === "crossX" ? "x" : "") : rm === "hollow" ? "rnd" : "sharp";
      if (c.cue && c.glow > 0.02 && lod <= 1) { setAlpha(ctx, alpha * c.glow); blit(ctx, getSprite("traffic", "client", tier, "L" + c.gl), sx, sy, px); if (S.countCalls) DC.traffic++; }   // §3.8 under the station
      const s = getSprite(kind, colorKey, tier, variant);
      setAlpha(ctx, alpha * c.freshA); blit(ctx, s, sx, sy, px);
    }
    if (S.identity.size || S.rules.length) { const idn = identityOf(c.id); if (idn !== "unknown") { setAlpha(ctx, alpha); drawIdentityFrame(ctx, sx, sy, px + 4, ENCODING.identity[idn]); } }   // D7: a classified station wears the frame, like a star
  }
  setAlpha(ctx, 1);
}
function drawBt() {   // §3.3 the strongest 48 marks, up to LOD 2
  if (!S.bt.size || S.perf.lod > 2) return;
  const ctx = ctxSky;
  for (const k of S.bt.values()) {
    if (k.alphaDraw <= 0.02 || k.rank >= BT.drawMax) continue;
    setAlpha(ctx, k.alphaDraw * k.freshA); blit(ctx, getSprite("bt", "bt", tierFor(k.px), k.rot ? (k.n > 1 ? "hd" : "h") : "f"), k.sx, k.sy, k.px);
  }
  setAlpha(ctx, 1);
}
function drawClouds() {   // §8.8a one glyph per shown cloud, the theme's randomised mark
  if (!S.clouds.size) return;
  const ctx = ctxSky, rm = THEME.render.clientRandomizedMark;
  for (const k of S.clouds.values()) {
    if (k.alphaDraw <= 0.02) continue;
    const variant = TD.clientKind === "clientCross" ? "L" + signalLevel(k.rssi) + (rm === "crossX" ? "x" : "") : rm === "hollow" ? "rnd" : "sharp";
    setAlpha(ctx, (cloudExpanded(k.id) ? k.alphaDraw * AGG.expandAlpha : k.alphaDraw) * k.freshA);
    blit(ctx, getSprite(TD.clientKind, "client", tierFor(k.px), variant), k.sx, k.sy, k.px);
    drawSelectionMarks(ctx, k, k.alpha);
  }
  setAlpha(ctx, 1);
}
function drawBubbles() {
  const ctx = ctxSky;
  S.bubbles.forEach(b => {
    if (b.alpha <= 0.02) return;
    const expanded = b.expandedUntil != null && b.expandedUntil > S.clock;
    const fogB = tS > 0 ? Math.max(b.fog ?? 1, CFG3D.bubbleFogFloor) : 1;
    const aDraw = (expanded ? b.alpha * AGG.expandAlpha : b.alpha) * fogB;
    setAlpha(ctx, aDraw);
    ctx.fillStyle = THEME.render.bubbleFill;
    ctx.beginPath(); ctx.arc(b.sx, b.sy, b.px, 0, Math.PI * 2); ctx.fill();
    ringArc(THEME.render.bubbleStroke, 1, null, aDraw, b.sx, b.sy, b.px, 0, Math.PI * 2);
    if (THEME.render.bubbleTicks) for (let i = 0; i < 4; i++) { const ang = i * Math.PI / 2; ringSeg(THEME.render.bubbleStroke, 1, aDraw, b.sx + Math.cos(ang) * (b.px - 3), b.sy + Math.sin(ang) * (b.px - 3), b.sx + Math.cos(ang) * (b.px + 3), b.sy + Math.sin(ang) * (b.px + 3)); }
    drawSelectionMarks(ctx, b, b.alpha);
    if (!expanded && b.px >= AGG.minCounterPx && aDraw >= AGG.minCounterAlpha) {
      const cs = getSprite("counter", "ink", b.n, "sharp");
      setAlpha(ctx, aDraw); blitFixed(ctx, cs, b.sx, b.sy - 4);
      const sub = getSprite("counter", "secondary", 0, "sharp");
      blitFixed(ctx, sub, b.sx, b.sy + 7);
      S.labelsList.push({ id: b.id, kind: "counter", text: String(b.n), x: r3(b.sx), y: r3(b.sy - 4) });
    }
  });
  ringFlush(ctx);
  setAlpha(ctx, 1);
}
function drawSelectionMarks(ctx, n, alpha) {   // selection ring when locked, pin mark (outside the ring) when pinned
  if (n.id === S.locked) {
    setAlpha(ctx, alpha); ctx.strokeStyle = THEME.accent.selection; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc(n.sx, n.sy, n.px + ENCODING.selectionRingOffsetPx, 0, Math.PI * 2); sT(ctx);
  }
  if (S.pinned.has(n.id)) { setAlpha(ctx, alpha); drawPinMark(ctx, n.sx, n.sy, n.px + ENCODING.selectionRingOffsetPx + (n.id === S.locked ? 5 : 0)); }
}
function drawPinMark(ctx, x, y, r) {   // D5: a 290° arc, gap at 12 o'clock, a radial notch at each end
  const g = ENCODING.pin.gapDeg * Math.PI / 360, a0 = -Math.PI / 2 + g, a1 = -Math.PI / 2 - g + 2 * Math.PI, nt = ENCODING.pin.notchPx;
  ctx.strokeStyle = THEME.ink.secondary; ctx.lineWidth = 1.5;
  ctx.beginPath(); ctx.arc(x, y, r, a0, a1);
  for (const a of [a0, a1]) { const c = Math.cos(a), sn = Math.sin(a); ctx.moveTo(x + c * (r - nt), y + sn * (r - nt)); ctx.lineTo(x + c * (r + nt), y + sn * (r + nt)); }
  sT(ctx);
}
function drawIdentityFrame(ctx, x, y, r, enc) {   // §8.10 / D7 identity frame: form only, ink.primary (suspect dashed)
  ctx.strokeStyle = THEME.ink.primary; ctx.lineWidth = 1.5;
  if (enc.dash) ctx.setLineDash(enc.dash);
  ctx.beginPath();
  if (enc.frame === "diamond") { ctx.moveTo(x, y - r); ctx.lineTo(x + r, y); ctx.lineTo(x, y + r); ctx.lineTo(x - r, y); ctx.closePath(); }
  else if (enc.frame === "rect") { const w = r * 1.35, h = r * 0.9; ctx.rect(x - w, y - h, 2 * w, 2 * h); }
  else if (enc.frame === "square") { ctx.rect(x - r, y - r, 2 * r, 2 * r); }
  else { if (enc.dash) ctx.setLineDash([]); return; }
  sT(ctx);
  if (enc.dash) ctx.setLineDash([]);
}
// vector-faithful marks: ring and tick strokes are BUNDLED — every arc/segment that shares (colour, width, dash, alpha) goes into one path and one stroke()
// The buckets outlive the batch (kind → colour → width → dash pattern → alpha step, nested like spriteKeys: no key string is built in the frame). ringOrder[0..ringN)
// lists the buckets of the running batch in first-use order = stroke order. The coordinates of a batch sit in ringV as records of 6 (five values, then the
// index of the bucket's next record or -1), so a batch allocates nothing once ringV has grown to its size.
const ringBatch = new Map(), ringDash = new WeakMap(), ringOrder = [];
let ringN = 0, ringV = new Float64Array(1536), ringTop = 0;
const ringSub = (m, k) => { let s = m.get(k); if (!s) { s = new Map(); m.set(k, s); } return s; };
function ringBucket(arc, stroke, lw, dash, alpha) {
  let dk = ""; if (dash) { dk = ringDash.get(dash); if (dk === undefined) { dk = dash.join(","); ringDash.set(dash, dk); } }   // dash arrays are constant tokens: joined once each
  const m = ringSub(ringSub(ringSub(ringSub(ringBatch, arc), stroke), lw), dk), step = Math.round(clamp(alpha, 0, 1) * RENDER.alphaSteps);   // the step setAlpha quantises to
  let b = m.get(step); if (!b) { b = { arc, stroke, lw, dash, alpha, head: -1, tail: -1 }; m.set(step, b); }
  if (b.head < 0) { b.dash = dash; b.alpha = alpha; ringOrder[ringN++] = b; }   // the first use in a batch decides the dash array and the alpha that are set
  return b;
}
function ringRec(b, c0, c1, c2, c3, c4) {
  const i = ringTop; ringTop += 6;
  if (ringTop > ringV.length) { const g = new Float64Array(2 * ringV.length); g.set(ringV); ringV = g; }
  ringV[i] = c0; ringV[i + 1] = c1; ringV[i + 2] = c2; ringV[i + 3] = c3; ringV[i + 4] = c4; ringV[i + 5] = -1;
  if (b.head < 0) b.head = i; else ringV[b.tail + 5] = i;
  b.tail = i;
}
function ringArc(stroke, lw, dash, alpha, x, y, r, a0, a1) { ringRec(ringBucket(true, stroke, lw, dash, alpha), x, y, r, a0, a1); }
function ringSeg(stroke, lw, alpha, x0, y0, x1, y1) { ringRec(ringBucket(false, stroke, lw, null, alpha), x0, y0, x1, y1, 0); }
function ringFlush(ctx) {
  const v = ringV;
  for (let o = 0; o < ringN; o++) {
    const b = ringOrder[o];
    setAlpha(ctx, b.alpha); ctx.strokeStyle = b.stroke; ctx.lineWidth = b.lw; ctx.setLineDash(b.dash || []); ctx.beginPath();
    if (b.arc) for (let i = b.head; i >= 0; i = v[i + 5]) { const x = v[i], y = v[i + 1], r = v[i + 2], a0 = v[i + 3], a1 = v[i + 4]; ctx.moveTo(x + Math.cos(a0) * r, y + Math.sin(a0) * r); ctx.arc(x, y, r, a0, a1); }
    else for (let i = b.head; i >= 0; i = v[i + 5]) { ctx.moveTo(v[i], v[i + 1]); ctx.lineTo(v[i + 2], v[i + 3]); }
    sT(ctx); b.head = -1;
  }
  ringN = 0; ringTop = 0; ctx.setLineDash([]); setAlpha(ctx, 1);
}
function drawApRings(ctx, ap, alpha) {
  const enc = ENCODING.security[ap.sec];
  const r = ap.px + ENCODING.ringOffsetPx;
  if (enc && enc.tone === "alarm") {
    if (THEME.status.alarmAura === "wash") { ctx.fillStyle = THEME.status.alarmWash; ctx.beginPath(); ctx.arc(ap.sx, ap.sy, ap.px * 2.2, 0, Math.PI * 2); ctx.fill(); }   // ornament only
    const g = ENCODING.gapDeg * Math.PI / 360, ne = -Math.PI / 4;   // half gap, NE direction (canvas y is down)
    ringArc(THEME.status.alarm, enc.widthPx, null, alpha, ap.sx, ap.sy, r, ne + g, ne - g + 2 * Math.PI);
  } else if (enc && enc.ring !== "none") {
    const col = enc.tone === "strong" ? THEME.status.ringStrong : THEME.status.ringNeutral;
    ringArc(col, enc.widthPx, enc.dash || null, alpha, ap.sx, ap.sy, r, 0, Math.PI * 2);
    if (enc.ring === "double") ringArc(col, enc.widthPx, enc.dash || null, alpha, ap.sx, ap.sy, r + ENCODING.doubleRingGapPx, 0, Math.PI * 2);
  }
  if (ap.hidden) ringArc(THEME.status.hidden, ENCODING.hidden.widthPx, ENCODING.hidden.dash, alpha, ap.sx, ap.sy, ap.px + ENCODING.hidden.offsetPx, 0, Math.PI * 2);
}
function coreBeatScale() {   // the core beats in place, <= 1 Hz, no rings
  const cb = THEME.render.coreBeat;
  return cb.enabled && !reduceMotion ? 1 + cb.amp * Math.sin(2 * Math.PI * cb.hz * S.clock) : 1;
}
function drawStars() {
  const ctx = ctxSky;
  const coreS = getSprite("core", "ink", 0, "sharp"), sc = coreBeatScale();
  setAlpha(ctx, 1); if (sc === 1) blitFixed(ctx, coreS, CX, CY); else dI(ctx, coreS.c, CX - coreS.w * sc / 2, CY - coreS.h * sc / 2, coreS.w * sc, coreS.h * sc);
  for (const ap of S.apOrder) {
    if (ap.alphaDraw <= 0.02) continue;
    const tier = tierFor(ap.px);
    const enc = ENCODING.band[ap.band] || ENCODING.band.unknown;
    const shapeKind = TD.coreKind[enc.shape];
    const colorKey = TD.bandColorKey[ap.band] || "unknown";
    const soft = TD.bokehSoft && (tS > 0 ? ap.fog < 0.6 : rssiT(ap.rssi) < 0.25);
    const s = getSprite(shapeKind, colorKey, tier, soft ? "soft" : "sharp");
    const ph = THEME.render.phosphor;   // the afterglow of a star is its freshness (T0 bright … T3 none); a separate soft bloom, one sprite per band colour and size
    if (ph.enabled && !soft) { const pa = ph.alpha[ap.freshTier ?? 0]; if (pa > 0) { setAlpha(ctx, ap.alphaDraw * pa); blit(ctx, getSprite("phosphor", colorKey, tier, "soft"), ap.sx, ap.sy, ap.px); } }
    setAlpha(ctx, ap.alphaDraw * ap.freshA); blit(ctx, s, ap.sx, ap.sy, ap.px);   // D1: freshness dims the star and its ring only (labels, hit-test and selection keep alphaDraw)
    drawApRings(ctx, ap, ap.alphaDraw * ap.freshA);
    const npm = THEME.render.newPlotMark; if (npm.enabled && isNewAp(ap) && !eventSkip(ap)) ringArc(THEME.ink.secondary, 1, npm.dash, ap.alphaDraw, ap.sx, ap.sy, ap.px + npm.offsetPx, 0, Math.PI * 2);   // a new plot's own dashed mark (D2: new for 3 captures) — not the identity channel
    if (S.identity.size || S.rules.length) { const idn = identityOf(ap.id); if (idn !== "unknown") { setAlpha(ctx, ap.alphaDraw); drawIdentityFrame(ctx, ap.sx, ap.sy, ap.px + 6, ENCODING.identity[idn]); } }
    const fc = essOfFolded(ap.id);   // §8.8 folded-ESS lead carries a count badge (= member APs), baked sprite
    if (fc && fc.leadId === ap.id && ap.alphaDraw > 0.05 && !scopeOn) {
      const cs = getSprite("counter", "ink", fc.apCount, "sharp");
      setAlpha(ctx, Math.max(ap.alphaDraw, AGG.minCounterAlpha)); blitFixed(ctx, cs, ap.sx, ap.sy - ap.px - 9);
      ctx.strokeStyle = THEME.line.device; ctx.lineWidth = 1; ctx.setLineDash(ENCODING.merge.dash);   // merged-set ring (D17 pattern)
      ctx.beginPath(); ctx.arc(ap.sx, ap.sy, ap.px + ENCODING.selectionRingOffsetPx + ENCODING.merge.extraPx, 0, Math.PI * 2); sT(ctx); ctx.setLineDash([]);
      S.labelsList.push({ id: fc.id, kind: "counter", text: String(fc.apCount), x: r3(ap.sx), y: r3(ap.sy - ap.px - 9) });
    }
    drawSelectionMarks(ctx, ap, ap.alphaDraw);
  }
  const cm = THEME.render.changeCue, e2 = S.clock * 2 | 0;
  alAt = Infinity;
  for (const a of S.alerts) { const n = alertNode(a); if (n && n.alphaDraw > 0.02) { alAt = reduceMotion ? Infinity : cm === "glowPulse" && !scopeOn ? 0 : (e2 + 1) / 2; ringArc(THEME.status.alert, 1.5, null, n.alphaDraw * (reduceMotion ? 1 : cm === "glowPulse" ? 0.7 + 0.3 * Math.sin(S.clock * 3) : cm === "bloomPulse" ? 0.3 + 0.7 * hash(a.ap.slice(-2) + e2 * 97) : 0.4 + 0.6 * (e2 >> 1 & 1)), n.sx, n.sy, n.px + ENCODING.hidden.offsetPx + 1.5, 0, Math.PI * 2); } }
  ringFlush(ctx);
  setAlpha(ctx, 1);
}
// D18 change cue (token render.changeCue): one short mark on an AP whose RSSI jumped ≥ 3 dB against the previous capture. glowPulse rides on
// drawGlows (Foundation); bloomPulse = one expanding band-colour ring (WarGames); tick = a short static stroke at the star's upper left (Whitehall,
// no twinkle). Reduced motion: a static tick that stays for exactly one capture. Time comes from S.clock only (frozen under ?fixed → age 0).
function cueAge(ap) {   // 0..1 while the cue plays, -1 otherwise
  if (ap.cueSeq !== S.captureSeq || S.captureSeq === 0) return -1;
  if (reduceMotion) return 0;
  const a = (S.clock - ap.cueT0) / CUE_S;
  return a >= 0 && a < 1 ? a : -1;
}
function drawChangeCues() {
  const mode = reduceMotion ? "tick" : THEME.render.changeCue;
  if (mode === "glowPulse") return;
  const ctx = ctxSky, k = Math.SQRT1_2;
  for (const ap of S.apOrder) {
    if (ap.alphaDraw <= 0.05) continue;
    const a = cueAge(ap); if (a < 0) continue;
    if (mode === "bloomPulse") {
      setAlpha(ctx, ap.alphaDraw * (0.4 + 0.6 * ap.cueAmp) * (1 - a)); ctx.strokeStyle = TD.bandCore[ap.band] || THEME.ink.primary; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.arc(ap.sx, ap.sy, ap.px + 4 + 10 * a, 0, Math.PI * 2); sT(ctx);
    } else {
      setAlpha(ctx, ap.alphaDraw); ctx.strokeStyle = THEME.ink.primary; ctx.lineWidth = 1.5;
      const r0 = ap.px + 5, r1 = ap.px + 11;
      ctx.beginPath(); ctx.moveTo(ap.sx - r0 * k, ap.sy - r0 * k); ctx.lineTo(ap.sx - r1 * k, ap.sy - r1 * k); sT(ctx);
    }
    if (S.countCalls) DC.cue++;
  }
  setAlpha(ctx, 1);
}
const _pg = {};
function drawGhosts() {   // D19: baseline APs not heard on the visited channels — dashed rings at a frozen place; not in layout, labels, stats or hit-test
  if (!S.ghosts.size) return;
  const ctx = ctxSky, z = S.cam.zoom2d || 1; if (tS > 0) cameraBasis();
  ctx.strokeStyle = THEME.ink.muted; ctx.lineWidth = 1; ctx.setLineDash(ENCODING.ghost.dash); setAlpha(ctx, 0.8);
  S.ghosts.forEach(g => {
    const rr = rssiToRadius(g.rssi) / maxRadius, wx = Math.cos(g.ang) * rr, wz = Math.sin(g.ang) * rr; let sx, sy;
    if (tS === 0) { sx = CX + (wx * skyC - wz * skyS) * z * maxRadius; sy = CY + (wx * skyS + wz * skyC) * z * maxRadius; }
    else { projPt(wx * skyC - wz * skyS, 0, wx * skyS + wz * skyC, _pg); if (!_pg.vis) return; sx = _pg.sx; sy = _pg.sy; }
    ctx.beginPath(); ctx.arc(sx, sy, ENCODING.ghost.r, 0, Math.PI * 2); sT(ctx);
  });
  ctx.setLineDash([]); setAlpha(ctx, 1);
}
const _pth = {};
function recvRingObj() {   // the receive ring CONTRACTS onto the core (fromPx → toPx over ms) when a capture brought something new; never outward, none under reduced motion
  const rr = THEME.render.recvRing;
  if (!rr.enabled || reduceMotion || S.recvT0 == null) return { active: false, px: null, alpha: 0 };
  const a = (S.clock - S.recvT0) / (rr.ms / 1000); if (a < 0 || a >= 1) return { active: false, px: null, alpha: 0 };
  return { active: true, px: r3(lerp(rr.fromPx, rr.toPx, a)), alpha: r3(0.9 - 0.5 * a) };
}
function drawRecvRing() { const o = recvRingObj(); if (!o.active) return; const ctx = ctxSky; ctx.strokeStyle = THEME.ink.primary; ctx.lineWidth = 1; setAlpha(ctx, o.alpha); ctx.beginPath(); ctx.arc(CX, CY, o.px, 0, Math.PI * 2); sT(ctx); setAlpha(ctx, 1); }
function drawThreshold() {   // the operator's signal threshold as a dashed ring at its RSSI radius (the same radius rule as the reference rings)
  if (S.threshold == null) return;
  const ctx = ctxSky, r = rssiToRadius(S.threshold); ctx.strokeStyle = THEME.ink.secondary; ctx.lineWidth = 1; ctx.setLineDash([6, 4]); setAlpha(ctx, 0.9);
  if (tS === 0) { ctx.beginPath(); ctx.arc(CX, CY, r * (S.cam.zoom2d || 1), 0, Math.PI * 2); ctx.stroke(); }
  else { cameraBasis(); const rr = r / maxRadius; let pen = false; ctx.beginPath(); for (let i = 0; i <= 64; i++) pen = groundXZ(ctx, RING_COS[i] * rr, RING_SIN[i] * rr, _pth, pen); ctx.stroke(); }   // 65 points of the circle (i / 64 · 2π) from the RING_COS / RING_SIN tables
  ctx.setLineDash([]); setAlpha(ctx, 1);
}
function drawFlares() {
  if (!S.anim.flareEnabled) return;   // Foundation only (wargames lensFlare disabled)
  const ctx = ctxSky, a = S.anim, HL = 42, lenF = a.flareLenFactor || 6;
  const breathe = !reduceMotion && a.breathePeriodS > 0;
  ctx.globalCompositeOperation = "lighter";
  for (const ap of S.apOrder) {
    if (ap.flare <= 0.02 || ap.alphaDraw <= 0.02) continue;
    if (tS > 0 && ap.fog <= 0.6) continue;   // 3D: only near stars carry a flare
    const s = getSprite("flare", "flare", 0, "sharp");
    const desired = Math.min(lenF * ap.basePx, HL);
    let scale = desired / HL;
    if (breathe) scale *= 1 + 0.06 * Math.sin(2 * Math.PI * S.clock / a.breathePeriodS + ap.phase);
    if (tS > 0) scale *= ap.scale || 1;
    const w = s.w * scale, h = s.h * scale;
    setAlpha(ctx, clamp(ap.flare * ap.alphaDraw, 0, 1));
    dI(ctx, s.c, ap.sx - w / 2, ap.sy - h / 2, w, h);
  }
  setAlpha(ctx, 1);
  ctx.globalCompositeOperation = "source-over";
}

