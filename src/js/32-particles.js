// ==== 32 PARTICLES ====
// Dust particle pool (Foundation look): interleaved Float32Array (x, y, homeDx, homeDy, phase, expireClock, size, baseAlpha)
// per particle; contiguous per-AP blocks tracked by node.pStart / node.pCount with a small free-list allocator.
// Section 32 reads THEME.particles / TD directly (allowed: 32 ∉ 22–30).
const PMAX = 2400, PSTRIDE = 8;
const PF = new Float32Array(PMAX * PSTRIDE);
const particles = { count: 0, pooled: 0 };   // pooled = allocated pool slots (=== count unless a block leaked)
let pBump = 0, pFree = [];
function pReclaimAll() { pBump = 0; pFree.length = 0; }
function palloc(count) {
  for (let i = 0; i < pFree.length; i++) if (pFree[i].count === count) return pFree.splice(i, 1)[0].start;
  for (let i = 0; i < pFree.length; i++) if (pFree[i].count > count) { const b = pFree[i], s = b.start; b.start += count; b.count -= count; return s; }
  if (pBump + count <= PMAX) { const s = pBump; pBump += count; return s; }
  return -1;
}
function pfree(start, count) {   // coalescing free list: the pool lives across polls, so fragmentation must not accumulate
  if (count <= 0) return;
  pFree.push({ start, count }); pFree.sort((a, b) => a.start - b.start);
  for (let i = pFree.length - 1; i > 0; i--) { const a = pFree[i - 1], b = pFree[i]; if (a.start + a.count === b.start) { a.count += b.count; pFree.splice(i, 1); } }
  const last = pFree[pFree.length - 1]; if (last && last.start + last.count === pBump) { pBump = last.start; pFree.pop(); }
}
let pTier = -1;   // LOD tier the pool was filled for: 0 full · 1 half (lod 1–2) · 2 none (lod 3)
function particlesRestartCurves() { S.aps.forEach(n => { if (n.pState === "gather" || n.pState === "dissolve") n.pT0 = S.clock; }); }   // §6.1 visibilitychange: restart running curves, keep resting dust
function pUnset(n) { n.pStart = -1; n.pCount = 0; n.pState = null; }   // the AP holds no particle block
function particlesReset() {
  particles.count = 0; particles.pooled = 0; pReclaimAll();
  S.aps.forEach(n => { n.pState = null; n.pStart = -1; n.pCount = 0; n.pT0 = 0; n.pAlphaMul = 1; });
}
function spawnFor(node, count) {
  const start = palloc(count);
  if (start < 0) { pUnset(node); return; }
  const tp = THEME.particles, rng = mulberry32(hashInt(node.id));
  const spread = tp.spreadFactor * node.basePx, sigma = tp.sigmaFactor * spread;
  const lifeLo = tp.lifeMs[0], lifeHi = tp.lifeMs[1], szLo = tp.sizePx[0], szHi = tp.sizePx[1];
  const aLo = tp.alpha[0], aHi = tp.alpha[1];
  for (let k = 0; k < count; k++) {
    const b = (start + k) * PSTRIDE;
    const u1 = Math.max(1e-6, rng()), u2 = rng();
    const r = sigma * Math.sqrt(-2 * Math.log(u1)), ang = 2 * Math.PI * u2;
    const hx = r * Math.cos(ang), hy = r * Math.sin(ang);
    PF[b + 2] = hx; PF[b + 3] = hy;
    PF[b + 4] = rng() * Math.PI * 2;
    PF[b + 6] = szLo + rng() * (szHi - szLo);
    PF[b + 7] = lerp(aLo, aHi, Math.floor(rng() * 4) / 3);   // 4 pre-quantised base-alpha steps
    PF[b + 5] = S.clock + (lifeLo + rng() * (lifeHi - lifeLo)) / 1000;
    PF[b] = node.sx + hx; PF[b + 1] = node.sy + hy;
  }
  node.pStart = start; node.pCount = count; node.pState = "gather"; node.pT0 = S.clock; node.pAlphaMul = 0;
}
function spawnPass(lod) {
  const tp = THEME.particles, cap = Math.min(tp.maxTotal, lod >= 1 ? 1200 : 2400);
  let used = 0; S.aps.forEach(n => { if (n.pStart >= 0) used += n.pCount; });
  const list = []; let want = 0;
  S.aps.forEach(n => {
    if (n.target !== 1 || n.pStart >= 0) return;
    if (S.ui.filters[n.band] === false) { pUnset(n); return; }
    let per = Math.round(lerp(tp.perNode[0], tp.perNode[1], rssiT(n.rssi)));
    if (lod >= 3) per = 0; else if (lod >= 1) per = Math.round(per * 0.5);
    if (per > 0) { list.push([n, per]); want += per; }
    else pUnset(n);
  });
  const avail = Math.max(0, Math.min(cap, PMAX) - used), scale = want > avail ? avail / want : 1;
  for (const [n, per] of list) {
    const c = Math.round(per * scale);
    if (c > 0) spawnFor(n, c);
    else pUnset(n);
  }
}
function stepParticles(liveDt) {
  const tp = THEME.particles;
  if (!tp || tp.maxTotal <= 0 || tp.perNode[1] <= 0) { if (particles.count !== 0 || pBump !== 0) particlesReset(); return; }
  const lod = S.perf.lod, now = S.clock, tier = lod >= 3 ? 2 : lod >= 1 ? 1 : 0;
  if (tier !== pTier) { if (pTier >= 0 && (particles.count > 0 || pBump > 0)) particlesReset(); pTier = tier; }   // budget follows the LOD tier
  let needSpawn = false, active = false;
  S.aps.forEach(n => { if (n.target === 1 && n.pStart < 0 && lod < 3 && S.ui.filters[n.band] !== false) needSpawn = true; });
  if (needSpawn) spawnPass(lod);
  const gMul = introGatherMul();   // 2 while the coalescing intro condenses the sky, 1 the rest of the time
  const gS = Math.max(0.001, tp.gatherMs * gMul / 1000), dS = Math.max(0.001, tp.dissolveMs / 1000);
  const amp = reduceMotion ? 0 : tp.driftPxPerS * 0.3, rm = reduceMotion;
  let total = 0;
  S.aps.forEach(n => {
    if (n.pStart < 0 || n.pCount <= 0) return;
    // dissolve trigger for dying / filtered-out APs
    if ((n.target !== 1 || S.ui.filters[n.band] === false) && n.pState !== "dissolve") { n.pState = "dissolve"; n.pT0 = now; }
    if (n.pState === "gather" && now - n.pT0 >= gS) n.pState = "idle";
    if (n.pState === "dissolve" && now - n.pT0 >= dS) { pfree(n.pStart, n.pCount); pUnset(n); return; }
    // dawn spirals IN, dusk drifts OUT along a spiral (a turn that unwinds as the dust settles / grows as it leaves)
    let fac = 1, aMul = 1, rot = 0;
    if (n.pState === "gather") {
      const uu = clamp((now - n.pT0) / gS, 0, 1);
      if (rm) {
        aMul = clamp((now - n.pT0) / 0.15, 0, 1);
      } else {
        const u = easeOutCubic(uu);
        fac = 1 + 3.0 * gMul * (1 - u); aMul = u; rot = tp.spiral.dawnRad * (1 - u);
      }
      active = true;
    }
    else if (n.pState === "dissolve") {
      const uu = clamp((now - n.pT0) / dS, 0, 1);
      if (rm) {
        aMul = 1 - clamp((now - n.pT0) / 0.15, 0, 1);
      } else {
        const e = easeInCubic(uu);
        fac = 1 + 2.5 * e; aMul = 1 - uu; rot = -tp.spiral.duskRad * e;
      }
      active = true;
    }
    // cohesion follows freshness (dense and bright when just heard, a loose haze on record); it eases towards its tier, never jumps
    const co = tp.cohesion, ti = n.freshTier == null ? 0 : n.freshTier, ct = co.scale[ti], ca = co.alpha[ti];
    if (n.cohNow == null || rm || S.fixedTime != null) {
      n.cohNow = ct; n.cohA = ca;
    } else if (liveDt > 0) {
      const kk = 1 - Math.exp(-liveDt / 0.8);
      n.cohNow += (ct - n.cohNow) * kk; n.cohA += (ca - n.cohA) * kk;
      active = active || Math.abs(ct - n.cohNow) > 0.01;
    }
    fac *= n.cohNow; aMul *= n.cohA;
    const cr = Math.cos(rot), sr = Math.sin(rot);
    n.pAlphaMul = aMul;
    const idle = n.pState === "idle";
    for (let k = 0; k < n.pCount; k++) {
      const b = (n.pStart + k) * PSTRIDE, hx = PF[b + 2] * cr - PF[b + 3] * sr, hy = PF[b + 2] * sr + PF[b + 3] * cr;
      let dx = 0, dy = 0;
      if (idle && !rm) { const ph = PF[b + 4]; dx = amp * Math.sin(ph + 0.7 * now); dy = amp * Math.cos(ph + 0.5 * now); }
      if (idle && liveDt > 0 && now >= PF[b + 5]) { const fr = (PF[b + 6] - tp.sizePx[0]) / Math.max(1e-6, tp.sizePx[1] - tp.sizePx[0]); PF[b + 5] = now + lerp(tp.lifeMs[0], tp.lifeMs[1], fr) / 1000; }
      PF[b] = n.sx + hx * fac + dx; PF[b + 1] = n.sy + hy * fac + dy;
    }
    total += n.pCount;
  });
  particles.count = total;
  let fr = 0; for (const b of pFree) fr += b.count; particles.pooled = pBump - fr;   // allocated slots
  if (total > 0 && !rm && liveDt > 0) active = true;
  if (active) S.moving = true;
}
function drawParticles() {
  if (particles.count <= 0) return;
  const tp = THEME.particles; if (!tp || tp.maxTotal <= 0) return;
  const ctx = ctxSky;
  ctx.globalCompositeOperation = THEME.render.composite;
  setAlpha(ctx, 1);
  // The grains do not emit, they are LIT. The only light is the observer at the centre, which is the
  // RX-only viewpoint made visible: the side of a cloud facing the centre is warm dust, the far side is bronze
  // shade. `lit` picks the palette per grain; freshness still reads through the four alpha steps of both.
  const fills = TD.particleFill, shades = TD.particleShade, lit = TD.particleLit;
  let curTier = -1, curLit = -1;
  S.aps.forEach(n => {
    if (n.pStart < 0 || n.pCount <= 0) return;
    const nd = clamp(n.alphaDraw, 0, 1), aMul = (n.pAlphaMul == null ? 1 : n.pAlphaMul) * nd;
    if (aMul <= 0.02) return;
    const lx = CX - n.sx, ly = CY - n.sy;   // from this star towards the observer
    for (let k = 0; k < n.pCount; k++) {
      const b = (n.pStart + k) * PSTRIDE, a = PF[b + 7] * aMul;
      if (a <= 0.02) continue;
      const tier = a < 0.31 ? 0 : a < 0.43 ? 1 : a < 0.54 ? 2 : 3;
      const side = lit ? (((PF[b] - n.sx) * lx + (PF[b + 1] - n.sy) * ly) > 0 ? 1 : 0) : 1;
      if (tier !== curTier || side !== curLit) { ctx.fillStyle = side ? fills[tier] : shades[tier]; curTier = tier; curLit = side; }
      const s = PF[b + 6];
      fR(ctx, PF[b] - s, PF[b + 1] - s, 2 * s, 2 * s);
    }
  });
  ctx.globalCompositeOperation = "source-over";
}
function dustObj() {   // per freshness tier the mean dust radius around its star and the mean alpha (aggregates only)
  const t = [0, 1, 2, 3].map(() => ({ aps: 0, radius: 0, alpha: 0, n: 0 }));
  let lit = 0, shade = 0;   // the same lit/shade split drawParticles uses — grains facing the observer, and grains in shadow
  S.aps.forEach(n => {
    if (n.pStart < 0 || n.pCount <= 0) return; const b0 = t[n.freshTier == null ? 0 : n.freshTier]; b0.aps++;
    const lx = CX - n.sx, ly = CY - n.sy;
    for (let k = 0; k < n.pCount; k++) { const b = (n.pStart + k) * PSTRIDE; b0.radius += Math.hypot(PF[b] - n.sx, PF[b + 1] - n.sy); b0.alpha += PF[b + 7] * (n.pAlphaMul == null ? 1 : n.pAlphaMul); b0.n++;
      if (((PF[b] - n.sx) * lx + (PF[b + 1] - n.sy) * ly) > 0) lit++; else shade++; }
  });
  return { tiers: t.map(x => ({ aps: x.aps, meanRadius: x.n ? r3(x.radius / x.n) : null, meanAlpha: x.n ? r3(x.alpha / x.n) : null })),
    litSide: TD.particleLit ? { on: true, lit, shade, shadeColor: TD.particleShade[3] } : { on: false, lit: 0, shade: 0, shadeColor: null } };
}
function particleDigest() {
  let h = 2166136261 >>> 0;
  S.aps.forEach(n => {
    if (n.pStart < 0 || n.pCount <= 0) return;
    for (let k = 0; k < n.pCount; k++) {
      const b = (n.pStart + k) * PSTRIDE;
      h ^= (Math.round(PF[b]) & 0xffff); h = Math.imul(h, 16777619);
      h ^= (Math.round(PF[b + 1]) & 0xffff); h = Math.imul(h, 16777619);
    }
  });
  return h >>> 0;
}
// Lens-flare selection with 3-dB hysteresis against the weakest current carrier (Foundation).
function flareCount() { let n = 0; S.aps.forEach(a => { if (a.flare > 0.5) n++; }); return n; }
function stepFlares(dt) {
  const max = S.anim.flareMax | 0;
  const visible = (n) => n.target === 1 && n.alpha > 0.05 && S.ui.filters[n.band] !== false && n.rssi != null;
  if (max <= 0 || !S.anim.flareEnabled) {
    S.aps.forEach(n => { n.flareT = 0; });
  } else {
    const vis = []; S.aps.forEach(n => { if (visible(n)) vis.push(n); });
    vis.sort((a, b) => (b.rssi - a.rssi) || cmpStr(a.bssid, b.bssid));
    S.aps.forEach(n => { if (n.flareT === 1 && !visible(n)) n.flareT = 0; });
    const carriers = vis.filter(n => n.flareT === 1);
    const nonCarriers = vis.filter(n => n.flareT !== 1);
    let ni = 0;
    while (carriers.length < max && ni < nonCarriers.length) { nonCarriers[ni].flareT = 1; carriers.push(nonCarriers[ni]); ni++; }
    let guard = 0;
    while (guard++ < max + 2) {
      let strong = null; for (const n of vis) { if (n.flareT !== 1) { strong = n; break; } }
      if (!strong) break;
      let weak = null; for (const n of vis) { if (n.flareT === 1 && (weak === null || n.rssi < weak.rssi)) weak = n; }
      if (!weak) break;
      if (strong.rssi >= weak.rssi + 3) { weak.flareT = 0; strong.flareT = 1; } else break;
    }
  }
  let moving = false;
  S.aps.forEach(n => {
    const tgt = n.flareT ? 1 : 0;
    if (reduceMotion) { if (n.flare !== tgt) { n.flare = tgt; moving = true; } return; }
    if (Math.abs(n.flare - tgt) > 1e-3) { n.flare = ease(n.flare, tgt, 7.67, dt); if (Math.abs(n.flare - tgt) <= 1e-3) n.flare = tgt; moving = true; }
  });
  if (moving) S.moving = true;
}

