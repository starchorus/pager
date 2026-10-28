// ==== 30 STEP ====
let lastT = 0, lastBudgetT = 0;
function regulatorStart() {   // §6.5: start levels from this sky (every capture, both ways) + the governor's own offset S.perf.down → lod, dprStep
  const p = S.perf, mobile = phoneOn, last = RENDER.dprSteps.length - 1;
  const start = (k) => {   // [lod, dprStep] for k × the counts
    const n = k * (S.apOrder.length + S.clientOrder.length), cap = Math.min(window.devicePixelRatio || 1, RENDER.maxDpr, (n > 500 || k * S.nFreeTotal > 600) ? 1.5 : 2, n > 900 ? 1.25 : 2, mobile ? (scopeOn ? 2 : RENDER.mobile.dprCap) : 2);
    const i = RENDER.dprSteps.findIndex(d => d <= cap);
    return [Math.min(3, (n > LOD.l3 ? 3 : n > LOD.l2 ? 2 : n > LOD.l1 ? 1 : 0) + (mobile ? RENDER.mobile.lodBias : 0)), i < 0 ? last : i];
  };
  const [l1, s1] = start(1), [l2, s2] = start(1.1);
  const lod = Math.max(l1, Math.min(p.lodBase, l2)), step = Math.max(s1, Math.min(p.dprStart, s2));   // a start rises at its threshold, falls only once 1.1 × the counts are below it (~9 %): a count hovering there does not flip LOD/DPR every poll
  if (lod !== p.lodBase || step !== p.dprStart) p.upWait = p.upAt = p.upT = 0;   // another sky size: back-off cleared (same rule as a new cap in budgetBegin)
  p.lodBase = lod; p.dprStart = step;
  if (!S.ui.autoLod) { applyDpr(step); return; }   // governor off: LOD frozen, sky DPR = the start value (boot dpr 1 is not a start value)
  p.down = Math.min(p.down, 3 - lod + last - step);   // ladder: LOD lodBase..3, then DPR dprStart..last, every rung a real change
  const l = Math.min(3, lod + p.down), s = step + Math.max(0, p.down - (3 - lod));
  if (l !== p.lod || s !== p.dprStep) { p.bT0 = 0; p.slowRun = p.fastRun = p.ambRun = 0; S.dirty = true; }   // measure afresh after the settle frames
  p.lod = l; applyDpr(s);
}
function applyDpr(step) {
  S.perf.dprStep = step;
  const d = Math.min(RENDER.dprSteps[step], window.devicePixelRatio || 1, RENDER.maxDpr);
  if (d === S.perf.dpr && canvasSky.width > 0) return;
  S.perf.dpr = d;
  resizeCanvases();
  clearSprites();
  rebuildBackground();
  S.dirty = true;
}
function budgetBegin(t) {   // §6.5: the rAF interval is the only signal (the raster runs after the callback, JS time misses it)
  const p = S.perf, R = RENDER;
  if (!lastBudgetT) { lastBudgetT = t; p.bT0 = 0; p.slowRun = p.fastRun = p.ambRun = 0; return; }   // first frame or back from a hidden tab: no interval, judge afresh
  const ms = t - lastBudgetT; lastBudgetT = t;
  p.frameMs = p.frameMs + (ms - p.frameMs) * R.emaAlpha;
  p.samples.push(ms); if (p.samples.length > 120) p.samples.shift();
  if (!S.ui.autoLod) { p.bT0 = -1; return; }
  if (p.bT0 < 0) { p.bT0 = 0; regulatorStart(); }   // governor back on: its levels apply at once
  const drew = p.rendered !== p.rSeen; p.rSeen = p.rendered;   // an idle frame (nothing moved) says nothing about the render cost
  if (ms > R.blockMs) { p.bT0 = 0; return; }   // a stall longer than a block (long task, breakpoint) is no render cost; left in, it cuts its block to 8 frames: measure afresh
  if (!p.bT0) { p.bT0 = t + R.settleMs; p.bN = p.bLate = 0; p.bMin = p.bMin2 = Infinity; }   // a block starts after the rebake frames of a change
  if (t < p.bT0 || !drew) return;
  p.bN++; if (ms > p.lateMs) p.bLate++;
  if (ms < p.bMin) { p.bMin2 = p.bMin; p.bMin = ms; } else if (ms < p.bMin2) p.bMin2 = ms;
  if (p.bN < 8 || t - p.bT0 < R.blockMs) return;
  // block end (~1 s): late share f; bMin2 = 2nd-shortest interval of the block (one odd frame ignored); lo = 25th percentile of the last 120
  const f = p.bLate / p.bN, bMin2 = p.bMin2, d0 = p.down, c0 = p.capMs, srt = p.samples.slice().sort((a, b) => a - b), lo = srt[srt.length >> 2];
  const maxDown = 3 - p.lodBase + R.dprSteps.length - 1 - p.dprStart, fresh = p.upT && t - p.upT < R.failMs;
  p.bT0 = t; p.bN = p.bLate = 0; p.bMin = p.bMin2 = Infinity;
  if (p.upT && !fresh) p.upT = p.upWait = 0;   // the last step up held: back-off cleared
  if (p.capMs && lo < R.capRatio * p.capMs) { p.capMs = 0; p.probeT = -1e9; }   // faster than the remembered cap: it is gone (Low Power Mode off, other display, load gone)
  const amb = bMin2 > R.lateK * Math.max(R.budgetMs, p.capMs);   // not one frame at the target period: a display/browser cap or our load? only a probe tells
  if (p.probe >= 0) {   // this block ran at the floor and answers the probe
    if (bMin2 >= R.capRatio * p.probeMs) { p.capMs = bMin2; p.down = p.probe; }   // quality does not move the interval: a cap, back where we were
    else if (amb) p.capMs = bMin2;   // load-bound: even the floor misses the target; climb from its interval
    p.probe = -1;
  } else {
    if (f >= R.lateFrac) { p.slowRun++; p.fastRun = 0; } else if (f <= R.okFrac) { p.fastRun++; p.slowRun = 0; } else p.slowRun = p.fastRun = 0;
    p.ambRun = amb ? p.ambRun + 1 : 0;
    const stuck = p.slowRun >= R.slowBlocks && p.ambRun >= R.slowBlocks;   // slow and amb
    if (fresh && p.slowRun && p.down < maxDown) { p.upWait = Math.min(R.upMaxMs, p.upWait ? 2 * p.upWait : R.upMs); p.upAt = t + p.upWait; p.upT = 0; p.down++; }   // a step up undone soon is retried later and later (no pumping)
    else if (stuck && p.down === maxDown) { p.capMs = bMin2; p.slowRun = p.ambRun = 0; }   // at the floor nothing is left to try: its interval is the best on offer
    else if (stuck && t - p.probeT > R.probeGapMs) { p.probe = p.down; p.probeMs = bMin2; p.probeT = t; p.down = maxDown; }   // cap or load? one jump to the floor tells
    else if (p.slowRun >= R.slowBlocks && p.down < maxDown) p.down++;
    else if (p.down > 0 && p.fastRun >= R.upBlocks && t >= p.upAt) { p.down--; p.upT = t; }   // no frame rate tells headroom: try one rung up, undo if late
  }
  if (p.capMs && !c0) p.upWait = p.upAt = 0;   // a new cap is a new target: step-ups undone under the old one say nothing about it
  // late = 0.4 vsync past the m ≥ 1 periods that fit 60 fps, at least target + 10 %: 60 Hz 23.3 ms, 120 Hz 20 ms, 144 Hz 18.3 ms (the floor), a 50 Hz panel 28 ms. A period above panelK × budget
  // (≤ 48 Hz) is no plausible panel, and a cap's period may be a vsync multiple: both are judged against the target + 10 % alone (30-fps cap 36.7 ms);
  // so is an amb block: a 50 Hz panel and a 100 Hz one at 2 vsyncs look alike, the probe tells them apart
  const tgt = Math.max(R.budgetMs, p.capMs), per = !p.capMs && !amb && lo <= R.panelK * tgt ? lo : 0, m = per ? Math.max(1, Math.floor(tgt / per + 0.05)) : 0;
  p.lateMs = Math.max((m + 0.4) * per, R.lateK * tgt);
  if (p.down !== d0) regulatorStart();
}
function perfTick(t) {
  const p = S.perf; p.rafTicks++;
  if (!p.fpsAt) p.fpsAt = t;
  if (t - p.fpsAt >= 1000) { p.fps = Math.round(p.rafTicks * 1000 / (t - p.fpsAt)); p.rafTicks = 0; p.fpsAt = t; }
}
function stepNodes(dt, liveDt) {
  const a = S.anim, stale = captureStale(); let moving = false;
  const breathing = a.breathePeriodS * liveDt > 0 && !reduceMotion;
  const eIn = Math.exp(-a.fadeInK * dt), eOut = Math.exp(-a.fadeOutK * dt), e3 = Math.exp(-3 * dt);
  for (const n of S.aps.values()) {   // a Map iterator tolerates deleting the current entry, like forEach
    const alphaT = (n.target === 1 && S.ui.filters[n.band] !== false) ? 1 : 0;
    n.alpha = easeBy(n.alpha, alphaT, alphaT > n.alpha ? eIn : eOut);
    if (n.alpha !== alphaT) moving = true;
    if (n.target === 0 && n.alpha < 0.02) { if (n.pStart >= 0) pfree(n.pStart, n.pCount); S.aps.delete(n.id); continue; }   // hand the particle block back (core fade 1.2 s < dissolve 1.4 s)
    n.angle = easeAngle(n.angle, n.angleT, 3, dt); n.radius = ease(n.radius, n.radiusT, 2.2, dt);
    if (n.angle !== n.angleT || n.radius !== n.radiusT) moving = true;
    n.wx = Math.cos(n.angle) * n.radius; n.wz = Math.sin(n.angle) * n.radius;
    n.hexA += LAYOUT.hexSpinRadPerS * liveDt;   // the hex cluster's turn (orbitOfClient), in step with its clients' phases
    const t = rssiT(n.rssi);
    n.basePx = lerp(LAYOUT.coreRadiusPx[0], LAYOUT.coreRadiusPx[1], t) + Math.min(n.clientCount, LAYOUT.clientBonusCap) * LAYOUT.clientBonusPx;
    if (breathing && n.alpha > 0.02) moving = true;
    if (n.cueSeq === S.captureSeq && S.clock - n.cueT0 < CUE_S && liveDt > 0) moving = true;   // D18 cue pulse
    n.freshA = easeBy(n.freshA, n.freshAT, eIn); if (n.freshA !== n.freshAT) moving = true;   // D1: a tier change fades freshA, never pops
  }
  if (S.essClusters.size && stepEss(dt)) moving = true;   // §8.8 G2 fold blend (after AP positions, before orbits)
  for (const n of S.clients.values()) {
    const ap = n.parent ? S.aps.get(n.parent) : null;
    const parentOk = n.free || (ap && ap.target === 1 && S.ui.filters[ap.band] !== false);
    const shownRnd = !n.randOut || (S.ui.random === "cloud" && (cloudExpanded(n.cloud) || isForced(n.id)));   // §8.8a
    const alphaT = (n.target === 1 && parentOk && shownRnd) ? 1 : 0;
    n.alpha = easeBy(n.alpha, alphaT, alphaT > n.alpha ? eIn : eOut);
    if (n.alpha !== alphaT) moving = true;
    n.freshA = easeBy(n.freshA, n.freshAT, eIn); if (n.freshA !== n.freshAT) moving = true;
    const gT = n.cue && !stale ? 1 : 0; n.glow = easeBy(n.glow, gT, eIn); if (n.glow !== gT) moving = true;   // §3.8 the cue fades; none when stale
    if (n.target === 0 && n.alpha < 0.02) { S.clients.delete(n.id); continue; }
    if (ap && !n.free) {
      n.orbitPhase += n.orbitSpeed * liveDt;
      n.wx = ap.wx + Math.cos(n.orbitPhase) * n.orbitR / maxRadius; n.wz = ap.wz + Math.sin(n.orbitPhase) * n.orbitR / maxRadius; n.placed = true;
      if (liveDt > 0 && n.alpha > 0.02) moving = true;
    } else {
      if (!n.placed) { n.wx = n.lx; n.wz = n.lz; n.placed = true; }
      if (!heldFree(n)) {   // during a relayout of a sky on screen: hold, then one glide to the settled spot
        n.wx = easeBy(n.wx, n.lx, e3); n.wz = easeBy(n.wz, n.lz, e3);
        if (n.wx !== n.lx || n.wz !== n.lz) moving = true;
      }
    }
    const t = n.rssi == null ? 0.25 : rssiT(n.rssi);
    n.basePx = 3.5 + 1.5 * t + (S.hover === n.id ? 0.5 : 0);
  }
  S.moving = moving;
}
function stepClouds(dt) {   // §8.8a, and the §3.1 marks
  if (!S.clouds.size && !S.bt.size) return;
  const a = S.anim, eIn = Math.exp(-a.fadeInK * dt), eOut = Math.exp(-a.fadeOutK * dt), e3 = Math.exp(-3 * dt); let moving = false;
  for (const M of [S.clouds, S.bt]) for (const k of M.values()) {
    const alphaT = k.target === 1 && btOn(k) ? 1 : 0;
    k.alpha = easeBy(k.alpha, alphaT, alphaT > k.alpha ? eIn : eOut); if (k.alpha !== alphaT) moving = true;
    if (k.target === 0 && k.alpha < 0.02 && !S.replay) { S.clouds.delete(k.id); S.bt.delete(k.id); continue; }   // a replay keeps it: Back to live takes it up again
    if (!k.placed) { k.wx = k.lx; k.wz = k.lz; k.placed = true; }
    if (!heldFree(k)) { k.wx = easeBy(k.wx, k.lx, e3); k.wz = easeBy(k.wz, k.lz, e3); if (k.wx !== k.lx || k.wz !== k.lz) moving = true; }
    k.basePx = (k.kind === "bt" ? BT.pxBase + BT.pxGain * rssiT(k.rssi) + (k.n > 1 ? 1 : 0) : CLOUD.pxBase + CLOUD.pxGain * rssiT(k.rssi)) + (S.hover === k.id ? 0.5 : 0);
    k.freshA = easeBy(k.freshA, k.freshAT, eIn); if (k.freshA !== k.freshAT) moving = true;
    if (k.expandedUntil != null && k.expandedUntil <= S.clock) { k.expandedUntil = null; moving = true; }
  }
  if (moving) S.moving = true;
}
function stepSky(liveDt) {   // §4.2a: one shared angular rate → rigid, so no pair or zone distance ever changes
  const w = S.ui.spin ? LAYOUT.skySpinRadPerS : 0;
  if (S.fixedTime != null) S.skyA = (w * S.clock) % (2 * Math.PI);   // frozen frame: a pure function of the fixed clock
  else if (w > 0 && liveDt > 0 && !reduceMotion) {                     // paused (liveDt 0) / reduced motion: the sky holds still
    S.skyA = (S.skyA + w * liveDt) % (2 * Math.PI);
    if (S.aps.size || S.clients.size) S.moving = true;
  }
  skyC = Math.cos(S.skyA); skyS = Math.sin(S.skyA);
}
function step(dt, liveDt) {
  stepBlend(dt); stepCamera(dt);
  const transitioning = S.view.blend !== S.view.blendT;
  if (!transitioning && S.settlePhase !== 0) runSettlePhases(LAYOUT.settlePerFrame);
  stepNodes(dt, liveDt); stepClouds(dt);
  stepSky(liveDt);
  stepBubbles(dt);
  stepFlares(dt);
  nodeEaseDt = dt; projectAll(); stepParticles(liveDt);
}
function scopeStep(dt, liveDt) {
  stepNodes(dt, liveDt); stepClouds(dt);
  const ri = S.replay ? S.replay.i : -1, wave = S.captureSeq !== SC.cs || ri !== SC.ri,
    sg = wave || S.dirty ? [S.ingestSeq, S.ui.random, Object.values(S.ui.filters)].join() : SC.sg;
  if (!SC.g || !(wave || sg !== SC.sg)) return;
  if (wave) scopeWave();
  scopePlace(wave); SC.sg = sg; SC.cs = S.captureSeq; SC.ri = ri; S.dirty = true;
}
function scopeWantsFrame() {
  return !!SC.g && !reduceMotion && !S.ui.paused && S.fixedTime == null && (S.clock < SC.t0 + SC.dur + 1.5 || (SC.lv !== "live" && Math.floor(S.clock * 2) !== SC.sf));
}
function wargamesAnimating() {   // travel dots / probe arcs keep the frame (and phosphor persistence) alive
  if (S.fixedTime == null && !S.ui.paused && recvRingObj().active) return true;   // the contracting receive ring
  if (S.anim.edgeTravelDotSpeed <= 0 || S.ui.paused || S.fixedTime != null) return false;
  if (S.ui.links) for (const c of S.clientOrder) { if (!c.free && c.alphaDraw > 0.05) { const ap = S.aps.get(c.parent); if (ap && ap.alphaDraw > 0.05) return true; } }
  if (S.anim.probeArc) {
    for (const id of [S.hover, S.locked]) { if (id == null) continue; const c = S.clients.get(id); if ((c && c.free) || S.bubbles.has(id)) return true; }
    if (!reduceMotion) {
      const arr = S.anim.arrivalArcs;   // only an arrival keeps the frame alive (the theme-free step code reads the S.anim mirror, never THEME)
      for (const c of S.clientOrder) { if (c.free && c.alphaDraw > 0.05) { if (arr && (c.newSeq !== S.captureSeq || S.captureSeq < 2 || c.newT0 == null)) continue; const age = S.clock - (arr ? c.newT0 : c.born); if (age >= 0 && age < 1.2) return true; } }
      if (!arr) { let bb = false; S.bubbles.forEach(b => { if (b.alpha > 0.05) { const age = S.clock - b.born; if (age >= 0 && age < 1.2) bb = true; } }); if (bb) return true; }
    }
  }
  return false;
}
function tick(t) {
  let dt, liveDt;
  if (S.fixedTime != null) { dt = 0; liveDt = 0; S.clock = S.fixedTime / 1000; lastT = t; }
  else {
    dt = lastT ? clamp((t - lastT) / 1000, 1 / 240, RENDER.dtMax) : 1 / 60; lastT = t;
    liveDt = S.ui.paused ? 0 : dt; S.clock += liveDt;
  }
  if (S.replay) replayTick(liveDt);
  budgetBegin(t);
  if (scopeOn) scopeStep(dt, liveDt); else step(dt, liveDt);
  const animating = scopeOn ? scopeWantsFrame() : S.fixedTime == null && (S.moving || S.settling || S.cam.tween !== null || wargamesAnimating());
  if (S.dirty || animating) {
    render(); S.dirty = false; S.perf.rendered++;
    S.persistFade = S.persistOn && !scopeOn ? RENDER.persistFadeFrames : 0;
  } else if (S.persistFade > 0) {   // §6.7 idle trail: let phosphor spurs fade, then one clean full frame
    S.persistFade--; render(); S.perf.rendered++;
    if (S.persistFade === 0 && S.persistOn) { ctxSky.clearRect(0, 0, W, H); render(); S.perf.rendered++; }
  } else if (S.fixedTime == null && !S.ui.paused && S.clock >= alAt) { ctxSky.clearRect(0, 0, W, H); render(); S.perf.rendered++; }   // alert step
  perfTick(t);
  requestAnimationFrame(tick);
}
document.addEventListener("visibilitychange", () => {
  if (!document.hidden) {
    lastT = 0;
    lastBudgetT = 0;
    ctxSky.clearRect(0, 0, W, H);
    particlesRestartCurves();   // §6.1: only running gather/dissolve curves restart; resting dust stays
    S.dirty = true;
  }
});
let resizeTimer = 0;
function resizeCanvases() {
  const d = S.perf.dpr, prevHudDpr = hudDpr;
  hudDpr = Math.max(d, (window.devicePixelRatio || 1) >= 2 ? RENDER.hudMinDpr : 0);
  if (hudDpr !== prevHudDpr) clearSprites();   // baked text carries the HUD scale, so a scale change invalidates it (applyDpr clears anyway; this covers a window dragged between displays)
  for (const [c, ctx, dd] of [[canvasBg, ctxBg, d], [canvasSky, ctxSky, d], [canvasHud, ctxHud, hudDpr]]) {
    c.width = Math.max(1, Math.floor(W * dd)); c.height = Math.max(1, Math.floor(H * dd));
    ctx.setTransform(dd, 0, 0, dd, 0, 0);
  }
}
function resize() {
  applyPhone();
  W = window.innerWidth; H = window.innerHeight;
  if (phoneOn) phoneLayout(true);
  const sb = skyBox(); skyR = sb; CX = sb.x + sb.w / 2; CY = sb.y + sb.h / 2; skyH = sb.h;   // the sky is centred in the free rectangle: the whole viewport outside phone mode
  maxRadius = Math.min(sb.w, sb.h) / 2 * LAYOUT.outerFrac || 1;
  inner = clamp(LAYOUT.innerFrac * maxRadius, LAYOUT.innerMinPx, LAYOUT.innerPx);
  if (scopeOn) { scopeGeom(); SC.sg = ""; renderScope(); }
  resizeCanvases();
  rebuildBackground();
  S.layoutDirty = true;
  settleLayout(LAYOUT.settleSyncIter);
  computeGroupEdges();
  layoutEdges();
  S.dirty = true;
}
window.addEventListener("resize", () => { clearTimeout(resizeTimer); resizeTimer = setTimeout(resize, 100); });

