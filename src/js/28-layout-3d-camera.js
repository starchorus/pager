// ==== 28 LAYOUT 3D & CAMERA ====
let tS = 0;                                   // smoothstep(blend): scene render weight (0 = 2D, 1 = 3D)
let nodeEaseDt = 0;                           // dt for per-node p easing (set by step(); 0 for frame()/settle())
const camB = { eye: [0, 0, 0], r: [1, 0, 0], u: [0, 1, 0], f: [0, 0, -1], F: 1 };
const free3dRank = new Map(); let free3dSig = "";
// Sky spin (§4.2a): the display rotates the whole world rigidly about the device (origin, y axis) by S.skyA.
// Applied only here, between layout and screen — lx/lz, angleT/radiusT, orbits and layoutInfo() stay untouched.
let skyC = 1, skyS = 0;                        // cos/sin of S.skyA, refreshed once per step (stepSky, §30)
function skyPt(o, x, y, z, out) { return projPt(o[0] + x * skyC - z * skyS, o[1] + y, o[2] + x * skyS + z * skyC, out); }   // spun origin o + world offset (spun here)
const yBandOf = (n) => CFG3D.yBand[n.band] ?? 0;
function F3Dof() { return (skyH / 2) / Math.tan(CFG3D.fovDeg / 2 * Math.PI / 180); }   // skyH = H outside phone mode
function camPreset(mode) {
  if (mode === "3d") { const F = F3Dof(); return { el: CFG3D.el, az: CFG3D.azStart, dist: F / (CFG3D.distFactor * maxRadius), F }; }
  return { el: Math.PI / 2 - 0.001, az: 0, dist: 20, F: 20 * maxRadius };
}
function ensureFreeRanks() {
  let cnt = 0; S.clients.forEach(n => { if (n.free && n.target === 1) cnt++; });
  const sig = S.clients.size + ":" + cnt;
  if (sig === free3dSig) return cnt;
  free3dSig = sig; free3dRank.clear();
  const arr = []; S.clients.forEach(n => { if (n.free && n.target === 1) arr.push(n); });
  arr.sort((a, b) => (hash(a.mac) - hash(b.mac)) || cmpStr(a.mac, b.mac));
  for (let i = 0; i < arr.length; i++) free3dRank.set(arr[i].mac, i);
  return cnt;
}
function freeY(n, nFree) {
  if (nFree <= CFG3D.fibonacciAbove) return (n.jitY - 0.5) * CFG3D.freeYSpread;
  const k = free3dRank.get(n.mac) || 0;
  return (1 - 2 * (k + 0.5) / nFree) * CFG3D.freeYSpread / 2;
}
function p3Of(node, nFree) {
  const p = node.p3;
  if (node.kind === "cloud" || node.kind === "bt") {   // §8.8a
    const h = heldFree(node);
    p[0] = h ? node.wx : node.lx; p[1] = (node.jitY - 0.5) * CFG3D.freeYSpread; p[2] = (h ? node.wz : node.lz) + (node.jitZ - 0.5) * CFG3D.freeZJitter;
    return p;
  }
  if (node.kind === "ap") {
    p[0] = node.wx; p[1] = yBandOf(node) + (node.jitY - 0.5) * CFG3D.yJitter; p[2] = node.wz;
    return p;
  }
  const ap = (!node.free && node.parent) ? S.aps.get(node.parent) : null;
  if (ap) {
    const ap3 = ap.p3, R = node.orbitR / maxRadius, phi = node.orbitPhase;
    if ((ap.orbitCount ?? ap.clientCount) >= LAYOUT.hexAbove) {              // flat hex cluster plane
      p[0] = ap3[0] + Math.cos(phi) * R; p[1] = ap3[1] + CFG3D.hexY; p[2] = ap3[2] + Math.sin(phi) * R;
    } else {                                             // tilted orbit plane
      const i = node.orbitTilt;
      p[0] = ap3[0] + R * Math.cos(phi); p[1] = ap3[1] + R * Math.sin(phi) * Math.sin(i); p[2] = ap3[2] + R * Math.sin(phi) * Math.cos(i);
    }
  } else {
    if (node.lx == null) { node.lx = node.wx || 0; node.lz = node.wz || 0; }
    const h = heldFree(node);   // as in stepNodes(): the held display, not the running relaxation
    p[0] = h ? node.wx : node.lx; p[1] = freeY(node, nFree); p[2] = (h ? node.wz : node.lz) + (node.jitZ - 0.5) * CFG3D.freeZJitter;
  }
  return p;
}
function cameraBasis() {
  const c = S.cam, el = c.el, az = c.az, dist = c.dist, t = c.target, e = camB.eye;
  e[0] = t[0] + dist * Math.cos(el) * Math.sin(az); e[1] = t[1] + dist * Math.sin(el); e[2] = t[2] + dist * Math.cos(el) * Math.cos(az);
  let fx = t[0] - e[0], fy = t[1] - e[1], fz = t[2] - e[2]; const fl = Math.hypot(fx, fy, fz) || 1; fx /= fl; fy /= fl; fz /= fl;
  camB.f[0] = fx; camB.f[1] = fy; camB.f[2] = fz;
  let rx = -fz, ry = 0, rz = fx; const rl = Math.hypot(rx, ry, rz) || 1; rx /= rl; ry /= rl; rz /= rl;
  camB.r[0] = rx; camB.r[1] = ry; camB.r[2] = rz;
  camB.u[0] = ry * fz - rz * fy; camB.u[1] = rz * fx - rx * fz; camB.u[2] = rx * fy - ry * fx;
  const v = S.view;
  camB.F = v.blend === 1 ? F3Dof() : v.blend === 0 ? 20 * maxRadius : c.F;
}
const _pp = { sx: 0, sy: 0, zc: 1, vis: true };
function projPt(x, y, z, out) {
  const e = camB.eye, r = camB.r, u = camB.u, f = camB.f;
  const dx = x - e[0], dy = y - e[1], dz = z - e[2];
  const zc = dx * f[0] + dy * f[1] + dz * f[2]; out.zc = zc;
  if (zc < CFG3D.nearHard) { out.vis = false; return out; }
  const s = camB.F / zc; out.sx = CX + s * (dx * r[0] + dy * r[1] + dz * r[2]); out.sy = CY - s * (dx * u[0] + dy * u[1] + dz * u[2]); out.vis = true; return out;
}
function fogOf(zc, dist) {
  const fogNear = smoothstep(CFG3D.nearHard, CFG3D.nearSoft, zc);
  const sFar = smoothstep(dist + CFG3D.farStart, dist + CFG3D.farEnd, zc);
  return { fog: fogNear * lerp(1, lerp(CFG3D.fogNearAlpha, CFG3D.fogFarAlpha, sFar), tS), sFar };
}
function project(node, kindFactor, minPx, maxPx) {
  const dist = S.cam.dist;
  projPt(node.p[0], node.p[1], node.p[2], _pp);
  node.zc = _pp.zc;
  if (!_pp.vis) { node.sx = -10000; node.sy = -10000; node.fog = 0; node.alphaDraw = 0; node.px = minPx; node.scale = 0; return; }
  node.sx = _pp.sx; node.sy = _pp.sy;
  const scale = lerp(1, dist / _pp.zc, tS); node.scale = scale;
  const fr = fogOf(_pp.zc, dist); node.fog = fr.fog;
  const forced = isForced(node.id);
  node.alphaDraw = node.alpha * node.fog * (forced ? 1 : kindFactor);
  node.px = clamp(node.basePx * lerp(1, (dist / _pp.zc) * lerp(1, CFG3D.sizeFarFactor, fr.sFar), tS), minPx, maxPx);
}
function easeP(n, tx, ty, tz, e) {   // e = Math.exp(-CFG3D.kNode * dt), one per frame
  const p = n.p;
  if (!n.pInit) { p[0] = tx; p[1] = ty; p[2] = tz; n.pInit = true; return; }
  p[0] = easeBy(p[0], tx, e); p[1] = easeBy(p[1], ty, e); p[2] = easeBy(p[2], tz, e);
}
function easeSky(n, x, y, z, e) { easeP(n, x * skyC - z * skyS, y, x * skyS + z * skyC, e); }   // n.p lives in the spun (display) frame
function projectAll() {
  const dt = nodeEaseDt; nodeEaseDt = 0;
  if (tS === 0) { project2D(); return; }
  cameraBasis();
  const nFree = ensureFreeRanks(), e = Math.exp(-CFG3D.kNode * dt);
  let count = 0;
  for (const n of S.aps.values()) {
    const p3 = p3Of(n, nFree); easeSky(n, lerp(n.wx, p3[0], tS), lerp(0, p3[1], tS), lerp(n.wz, p3[2], tS), e);   // 2D world → 3D layout by tS
    project(n, 1, CFG3D.minPxAp, CFG3D.maxPxAp); essDrawFactor(n);
    if (n.target === 1) count++;
  }
  for (const n of S.clients.values()) {
    if (!n.placed) { n.wx = n.lx; n.wz = n.lz; n.placed = true; }
    const p3 = p3Of(n, nFree); easeSky(n, lerp(n.wx, p3[0], tS), lerp(0, p3[1], tS), lerp(n.wz, p3[2], tS), e);
    project(n, n.free ? 0.85 : 0.95, CFG3D.minPxClient, CFG3D.maxPxClient);
    if (n.target === 1 && !n.randOut && (n.bubble == null || n.bubbleBlend < 0.5)) count++;
  }
  for (const M of [S.clouds, S.bt]) for (const k of M.values()) {   // §8.8a
    if (!k.placed) { k.wx = k.lx; k.wz = k.lz; k.placed = true; }
    const p3 = p3Of(k, nFree), px3 = k.kind === "bt" ? BT.px3d : CLOUD.px3d; easeSky(k, lerp(k.wx, p3[0], tS), lerp(0, p3[1], tS), lerp(k.wz, p3[2], tS), e);
    project(k, 0.85, px3[0], px3[1]);
    if (k.target === 1 && btOn(k)) count++;
  }
  for (const b of S.bubbles.values()) {
    let mx = 0, my = 0, mz = 0, cnt = 0;
    for (const m of b.members) { const c = S.clients.get(m); if (!c) continue; mx += c.p3[0]; my += c.p3[1]; mz += c.p3[2]; cnt++; }
    if (cnt > 0) { mx /= cnt; my /= cnt; mz /= cnt; } else { mx = b.cx; my = 0; mz = b.cz; }
    if (!b.p) b.p = [b.cx, 0, b.cz];
    easeSky(b, lerp(b.cx, mx, tS), lerp(0, my, tS), lerp(b.cz, mz, tS), e);
    b.basePx = b.r; project(b, 1, CFG3D.minPxBubble, 1e4); b.alphaDraw = b.alpha * b.fog;
    if (b.target === 1 || b.alpha > 0.02) count++;
  }
  S.nodeCount = count;
}
function project2D() {   // the device (world origin) is pinned to CX,CY — zoom scales about it, there is no pan
  const z = S.cam.zoom2d, c = skyC, s = skyS;
  const flat = (n, x, y, px) => { n.sx = CX + (x * c - y * s) * z * maxRadius; n.sy = CY + (x * s + y * c) * z * maxRadius; n.zc = 1; n.fog = 1; n.scale = 1; n.px = px * z; };
  let count = 0;
  for (const n of S.aps.values()) { flat(n, n.wx, n.wz, n.basePx); n.alphaDraw = n.alpha; essDrawFactor(n); if (n.target === 1) count++; }
  for (const n of S.clients.values()) {
    if (!n.placed) { n.wx = n.lx; n.wz = n.lz; n.placed = true; }
    flat(n, n.wx, n.wz, n.basePx);
    n.alphaDraw = n.alpha * (n.free ? 0.85 : 0.95);
    if (isForced(n.id)) n.alphaDraw = n.alpha;
    if (n.target === 1 && !n.randOut && (n.bubble == null || n.bubbleBlend < 0.5)) count++;
  }
  for (const M of [S.clouds, S.bt]) for (const k of M.values()) {   // §8.8a
    flat(k, k.wx, k.wz, k.basePx);
    k.alphaDraw = isForced(k.id) ? k.alpha : k.alpha * 0.85;
    if (k.target === 1 && btOn(k)) count++;
  }
  for (const b of S.bubbles.values()) { flat(b, b.cx, b.cz, b.r); b.alphaDraw = b.alpha; if (b.target === 1 || b.alpha > 0.02) count++; }
  S.nodeCount = count;
}
function startTween(to) {
  const c = S.cam;
  const ms = reduceMotion ? 150 : S.anim.cameraEaseMs;
  const fn = reduceMotion ? (u => u) : (S.anim.cameraEasing || easeInOutCubic);
  c.tween = { e: 0, ms, fn,
    from: { az: c.az, el: c.el, dist: c.dist, target: c.target.slice() },
    to: { az: to.az ?? c.az, el: to.el ?? c.el, dist: to.dist ?? c.dist, target: (to.target || c.target).slice() } };
  S.dirty = true;
}
function stepCamera(dt) {
  const c = S.cam, v = S.view;
  if (v.blend !== v.blendT) return;          // transition drives the camera (stepBlend)
  if (v.blend < 0.5) { c.ramp = 0; return; } // 2D steady: projection unused
  if (c.tween) {
    const tw = c.tween, u = tw.fn(clamp((tw.e += dt * 1e3) / tw.ms, 0, 1));
    c.az = c.azT = tw.from.az + wrapPi(tw.to.az - tw.from.az) * u;
    c.el = c.elT = clamp(lerp(tw.from.el, tw.to.el, u), CFG3D.elMin, CFG3D.elMax);
    c.dist = c.distT = clamp(Math.exp(lerp(Math.log(tw.from.dist), Math.log(tw.to.dist), u)), CFG3D.distMin, CFG3D.distMax);
    for (let i = 0; i < 3; i++) c.target[i] = c.targetT[i] = lerp(tw.from.target[i], tw.to.target[i], u);
    if (u >= 1) c.tween = null;
    c.az3D = c.az; S.dirty = true; return;
  }
  if (!reduceMotion && S.ui.rotate && !S.ui.paused) {
    const idleOk = c.idleAt === 0 || (S.clock - c.idleAt) >= CFG3D.idleResumeMs / 1000;
    if (idleOk) c.ramp = ease(c.ramp, 1, CFG3D.autoRamp, dt);
    if (c.ramp > 0) { c.az += S.anim.autoRotateRadPerS * c.ramp * dt; c.azT = c.az; S.dirty = true; }
  } else c.ramp = 0;
  const kA = reduceMotion ? CFG3D.kReduced : CFG3D.kAz, kE = reduceMotion ? CFG3D.kReduced : CFG3D.kEl, kD = reduceMotion ? CFG3D.kReduced : CFG3D.kDist, kT = reduceMotion ? CFG3D.kReduced : CFG3D.kTarget;
  const az0 = c.az, el0 = c.el, d0 = c.dist;
  c.az = easeAngle(c.az, c.azT, kA, dt);
  c.el = clamp(ease(c.el, c.elT, kE, dt), CFG3D.elMin, CFG3D.elMax);
  c.dist = clamp(Math.exp(ease(Math.log(c.dist), Math.log(c.distT), kD, dt)), CFG3D.distMin, CFG3D.distMax);
  for (let i = 0; i < 3; i++) c.target[i] = ease(c.target[i], c.targetT[i], kT, dt);
  c.az3D = c.az;
  if (c.az !== az0 || c.el !== el0 || c.dist !== d0) S.dirty = true;
}
function stepBlend(dt) {
  const v = S.view, c = S.cam;
  if (v.blend !== v.blendT) {
    const k = reduceMotion ? CFG3D.kReduced : CFG3D.kBlend;
    v.blend = v.blendT + (v.blend - v.blendT) * Math.exp(-k * dt);   // ease towards blendT (no-op at dt = 0)
    if (Math.abs(v.blend - v.blendT) < 1e-3) { v.blend = v.blendT; snapCamera(v.blend >= 0.5 ? "3d" : "2d"); }
    else {
      const p2 = camPreset("2d"), p3 = camPreset("3d"), s = smoothstep(0, 1, v.blend);
      c.el = c.elT = lerp(p2.el, p3.el, s);
      c.dist = c.distT = Math.exp(lerp(Math.log(p2.dist), Math.log(p3.dist), s));
      c.F = Math.exp(lerp(Math.log(p2.F), Math.log(p3.F), s));
      c.az = c.azT = c.az3D * s;
    }
    S.dirty = true;
  }
  tS = smoothstep(0, 1, v.blend);
}
function snapCamera(mode) {
  const pre = camPreset(mode), c = S.cam;
  c.el = c.elT = pre.el; c.dist = c.distT = pre.dist; c.F = pre.F;
  c.az = c.azT = c.az3D = mode === "3d" ? CFG3D.azStart : 0;
  c.target[0] = c.target[1] = c.target[2] = 0; c.targetT[0] = c.targetT[1] = c.targetT[2] = 0;
  c.tween = null; c.ramp = 0; c.idleAt = 0;
}
function flyTo(node) {   // never re-target — turn the node to the front of the device and dolly in only as far as keeps it on screen
  if (!node || !node.p) return;
  const rho = Math.hypot(node.p[0], node.p[2]), y = node.p[1], el = S.cam.el, ce = Math.cos(el), se = Math.sin(el);
  // in front of the device the node sits (rho·sin el − y·cos el)·F/zc below CY, zc = dist − rho·cos el − y·sin el → keep it within focusFrac of the half-height
  const keep = rho * ce + y * se + Math.max(0, rho * se - y * ce) / (Math.tan(CFG3D.fovDeg / 2 * Math.PI / 180) * CFG3D.focusFrac);
  startTween({ target: [0, 0, 0], dist: clamp(Math.max(S.cam.dist * CFG3D.centerZoom, keep), CFG3D.distMin, CFG3D.distMax), az: Math.atan2(node.p[0], node.p[2]) });
}
function applyOrbit(dx, dy) {
  const c = S.cam; c.az -= dx * CFG3D.dragRadPerPx; c.azT = c.az;
  c.el = clamp(c.el + dy * CFG3D.dragRadPerPx, CFG3D.elMin, CFG3D.elMax); c.elT = c.el;
  c.az3D = c.az; c.tween = null; c.ramp = 0; c.idleAt = S.clock; S.dirty = true;
}
function setZoom2d(z) { S.cam.zoom2d = clamp(z, CFG3D.zoom2dMin, CFG3D.zoom2dMax); S.dirty = true; }   // always about the device (no pan)
function resetCamera() {
  S.locked = null; closeDetail();
  S.cam.zoom2d = 1;
  if (S.view.blend >= 0.5) { const pre = camPreset("3d"); startTween({ target: [0, 0, 0], dist: pre.dist, az: CFG3D.azStart, el: pre.el }); S.cam.az3D = CFG3D.azStart; }
  else S.cam.tween = null;
  S.dirty = true;
}
function setView(v, opts = {}) {
  v = v === "3d" ? "3d" : "2d";
  const wasBlend = S.view.blend;
  S.ui.view = v;
  S.view.blendT = v === "3d" ? 1 : 0;
  if (opts.snap) { S.view.blend = S.view.blendT; tS = smoothstep(0, 1, S.view.blend); snapCamera(v); }
  else {
    if (v === "3d" && wasBlend < 0.5) { S.cam.az3D = CFG3D.azStart; S.cam.az = 0; S.cam.azT = 0; }
    else if (v === "2d") S.cam.az3D = wrapPi(S.cam.az);
    S.cam.tween = null;
  }
  if (opts.persist !== false) { S.queryLocked.delete("view"); saveUi(); }
  rebuildBackground(); updateControlsLook(); S.dirty = true;
  return v;
}

