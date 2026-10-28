// ==== 26 LAYOUT 2D ====
function rssiToRadius(dbm) { return inner + (1 - rssiT(dbm)) * (maxRadius - inner); }
function basePxMax(node) {
  if (node.kind !== "ap") return 5;
  return LAYOUT.basePxMaxCore + Math.min(node.clientCount, LAYOUT.clientBonusCap) * LAYOUT.clientBonusPx;
}
function starZonePx(ap) { const b = basePxMax(ap); return Math.max(3.0 * b, b + LAYOUT.starZoneExtraPx); }
function orbitZonePx(ap) {
  if ((ap.orbitCount ?? ap.clientCount) >= LAYOUT.hexAbove) return 72 + LAYOUT.clientMinDistPx / 2;
  return ap.orbitRcap + LAYOUT.clientMinDistPx / 2;
}
function aggDensity(n) { const denom = Math.PI * Math.max(1, maxRadius * maxRadius - inner * inner); return n * (LAYOUT.clientMinDistPx + 2) * (LAYOUT.clientMinDistPx + 2) / denom; }
function aggForced() { const n = S.nFreeTotal; return n > LAYOUT.forceAggAbove || aggDensity(n) > LAYOUT.forceAggDensity; }
const PHI_GOLD = 2.399963;
function placeAPs() {
  const list = S.apOrder.filter(ap => S.ui.filters[ap.band] !== false);
  const dense = list.length > LAYOUT.apDenseAbove;
  const gap = dense ? LAYOUT.apMinGapDensePx : LAYOUT.apMinGapPx;
  // dense fields spread APs over a wide radial band (RSSI stays readable to ±6 px in sparse fields, spec §4.1)
  const nudges = dense ? [0, 6, -6, 12, -12, 18, -18, 24, -24, 30, -30] : [0, LAYOUT.apNudgePx, -LAYOUT.apNudgePx];
  // The placed stars by grid cell. A star decides a spot only while it leaves less than `gap`, i.e. sits closer than gap + both
  // cores (+ 1e-6 against rounding): gapAt scans the cells that box touches and finds the exact smallest gap whenever it is
  // < gap. With no star there the spot is free, which is all the caller reads then. A gap that cannot beat `bar` (the best
  // so far, always < gap) is returned at once: the caller ignores it.
  const pcell = gap + 2 * (LAYOUT.basePxMaxCore + LAYOUT.clientBonusCap * LAYOUT.clientBonusPx), pgrid = new Map();
  let bpTop = 0;   // largest core placed so far
  for (const ap of list) {
    ap.a0 = hash(ap.bssid) * Math.PI * 2;
    let a0 = ap.a0;
    if (ap.groupKey) { const g = S.groups.get(ap.groupKey); if (g && g.members.length >= 2) a0 = a0 + LAYOUT.groupPull * wrapPi(g.meanA0 - a0); }
    const r = rssiToRadius(ap.rssi), bp = basePxMax(ap);
    const cand = [];
    if (ap.angleT != null) cand.push(ap.angleT);
    for (let k = 0; k < LAYOUT.apCandidates; k++) cand.push(a0 + k * PHI_GOLD);
    const gapAt = (ang, rad, bar) => {
      let g = Infinity; const x = Math.cos(ang) * rad, y = Math.sin(ang) * rad, reach = gap + bp + bpTop + 1e-6;
      const gx1 = Math.floor((x + reach) / pcell), gy0 = Math.floor((y - reach) / pcell), gy1 = Math.floor((y + reach) / pcell);
      for (let gx = Math.floor((x - reach) / pcell); gx <= gx1; gx++) for (let gy = gy0; gy <= gy1; gy++) {
        const arr = pgrid.get(gx * CELLP + gy); if (!arr) continue;
        for (const p of arr) { const gg = hyp(x - p.x, y - p.y) - (bp + p.bp); if (gg < g) { g = gg; if (g <= bar) return g; } }
      }
      return g;
    };
    let best = null, bestGap = -Infinity, bestR = r, found = false;
    for (let ni = 0; ni < nudges.length && !found; ni++) {
      const rad = r + nudges[ni];
      if (rad < inner) continue;
      // hysteresis angle only counts at the un-nudged radius
      const start = ap.angleT != null && ni ? 1 : 0;
      for (let ci = start; ci < cand.length; ci++) {
        const g = gapAt(cand[ci], rad, bestGap);
        if (g >= gap) { best = cand[ci]; bestGap = g; bestR = rad; found = true; break; }
        if (g > bestGap) { bestGap = g; best = cand[ci]; bestR = rad; }
      }
    }
    ap.angleT = best; ap.radiusT = bestR / maxRadius;
    const p = { x: Math.cos(best) * bestR, y: Math.sin(best) * bestR, bp }, pk = Math.floor(p.x / pcell) * CELLP + Math.floor(p.y / pcell);
    const arr = pgrid.get(pk); if (arr) arr.push(p); else pgrid.set(pk, [p]);
    if (bp > bpTop) bpTop = bp;
  }
  for (const ap of S.apOrder) {
    if (ap.angle == null) { ap.angle = ap.angleT; ap.radius = ap.radiusT; ap.wx = Math.cos(ap.angle) * ap.radius; ap.wz = Math.sin(ap.angle) * ap.radius; }
  }
  const all = list, nA = all.length, px = new Float64Array(nA), py = new Float64Array(nA);
  for (let i = 0; i < nA; i++) { const o = all[i]; px[i] = Math.cos(o.angleT) * o.radiusT * maxRadius; py[i] = Math.sin(o.angleT) * o.radiusT * maxRadius; }
  for (let i = 0; i < nA; i++) {
    const ap = all[i], ax = px[i], ay = py[i];
    let bestD = Infinity;
    for (let j = 0; j < nA; j++) {
      if (j === i) continue;
      const dx = ax - px[j], dy = ay - py[j];
      if (dx >= bestD || dx <= -bestD || dy >= bestD || dy <= -bestD) continue;   // cannot beat the best (hypot >= |dx|, |dy|)
      const d = hyp(dx, dy); if (d < bestD) bestD = d;
    }
    ap.orbitRcap = bestD === Infinity ? LAYOUT.orbitMaxPx : clamp(0.5 * bestD - 4, LAYOUT.orbitMinPx, LAYOUT.orbitMaxPx);
  }
}
function homeOfClient(c) {
  c.homeAngle = hash(c.mac) * Math.PI * 2;
  c.homeR = rssiToRadius(c.rssi ?? -85) / maxRadius;
  c.jitterR = (hash(c.mac + "r") - 0.5) * 2 * LAYOUT.clientJitterPx / maxRadius;
  const r = c.homeR + c.jitterR;
  c.homeX = Math.cos(c.homeAngle) * r; c.homeZ = Math.sin(c.homeAngle) * r;
  c.lx = c.homeX; c.lz = c.homeZ;
}
function orbitOfClient(c, ap) {   // a lane keeps the phase of an orbit that goes on; a hex slot sits at its angle plus the cluster's turn
  c.orbitTilt = (hash(c.mac + "i") - 0.5) * LAYOUT.orbitTilt;
  if ((ap.orbitCount ?? ap.clientCount) >= LAYOUT.hexAbove) {
    const rank = c.rank; let ringR, base, cnt;
    if (rank < 7) { ringR = 2 * LAYOUT.hexBPx; base = 0; cnt = 7; }
    else if (rank < 19) { ringR = 3.25 * LAYOUT.hexBPx; base = 7; cnt = 12; }
    else { ringR = 72 + ((rank - 19) / 18 | 0) * 8; base = 19; cnt = 18; }
    const dir = hash(ap.id + "d") > 0.5 ? 1 : -1;   // one direction per AP (§4.3, overall rotation): the cluster turns as a whole, its slots never cross
    c.orbitR = ringR;
    c.orbitPhase = ((rank - base) % cnt) / cnt * Math.PI * 2 + dir * ap.hexA;   // a kept slot gets the phase it has, a moved one its place in the turned cluster
    c.orbitSpeed = dir * LAYOUT.hexSpinRadPerS;
    return;
  }
  const keep = ap.orbitKeep && c.orbitPhase === c.orbitPhase;   // NaN: a new orbit (ingest/applyAffinity); orbitKeep false: the AP left hex
  const lane = c.rank % LAYOUT.orbitLanes;
  let r = LAYOUT.orbitMinPx + hash(c.mac + "o") * LAYOUT.orbitSpreadPx + lane * LAYOUT.orbitRankPx;
  r = Math.min(r, ap.orbitRcap);
  c.orbitR = r;
  if (!keep) c.orbitPhase = hash(c.mac) * Math.PI * 2;
  c.orbitSpeed = (hash(c.mac + "d") > 0.5 ? 1 : -1) * LAYOUT.orbitSpeedBase * Math.pow(LAYOUT.orbitSpeedRefPx / r, LAYOUT.orbitSpeedExp);
}
// --- spread relaxation (positional, deterministic, no random, no dt) ---
let settleActive = [], settleObstacles = [], settleIterTotal = 0, settleConverged = false;
let p0x = null, p0z = null, cxi = null, czi = null, sX = null, sZ = null;   // sX/sZ: the actives' lx/lz while relaxIter runs
const CELLP = 100003, PHASE1_CAP = 32;   // phase-1 spreads all free clients, then hands off to aggregation (converged or capped)
function buildObstacles(withBubbles) {
  settleObstacles.length = 0; obsGridVer++;
  for (const ap of S.apOrder) {
    if (S.ui.filters[ap.band] === false) continue;
    const x = Math.cos(ap.angleT) * ap.radiusT, z = Math.sin(ap.angleT) * ap.radiusT;
    let zonePx = starZonePx(ap);
    if (ap.clientCount > 0) zonePx = Math.max(zonePx, orbitZonePx(ap));   // real associations only: probe orbits (§8.9) are no obstacle
    settleObstacles.push({ x, z, zone: zonePx / maxRadius });
  }
  if (withBubbles) S.bubbles.forEach(b => { if (b.target === 1) settleObstacles.push({ x: b.cxT, z: b.czT, zone: (b.rT + LAYOUT.bubbleZonePx) / maxRadius }); });
}
function buildActive(phase) {   // phase 2 leaves the aggregated clients to their bubbles; §8.8a: no randOut, the shown clouds
  settleActive = S.clientOrder.filter(c => c.free && c.target === 1 && !c.randOut && !(phase === 2 && c.bubble != null));
  if (S.ui.random === "cloud") for (const k of S.cloudOrder) settleActive.push(k);
}
let sD = 0, sCell = 0, sTolW = 0, sCoreKeep = 0;
const settleGrid = new Map();
function settleConstants() {
  sD = LAYOUT.clientMinDistPx / maxRadius; sCell = 2 * sD;
  sTolW = LAYOUT.radialTolPx / maxRadius; sCoreKeep = (inner - LAYOUT.coreZonePx) / maxRadius + sD / 2;
  const N = settleActive.length;
  if (!p0x || p0x.length < N) { const n = Math.max(1, N); p0x = new Float32Array(n); p0z = new Float32Array(n); cxi = new Int32Array(n); czi = new Int32Array(n); sX = new Float64Array(n); sZ = new Float64Array(n); }
}
let spStart = new Int32Array(0), spHead = new Int32Array(0), spIdx = new Int32Array(0);
function settlePairPass() {   // O(n) grid-hashed pair repulsion, each unordered pair once (i<j), in-place (sX/sZ)
  const A = settleActive, N = A.length, D = sD, push = LAYOUT.pushFactor, X = sX, Z = sZ;
  let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
  for (let i = 0; i < N; i++) {
    cxi[i] = Math.floor(X[i] / sCell); czi[i] = Math.floor(Z[i] / sCell);
    const gx = cxi[i], gz = czi[i];
    if (gx < minX) minX = gx; if (gx > maxX) maxX = gx; if (gz < minZ) minZ = gz; if (gz > maxZ) maxZ = gz;
  }
  // Dense grid (one ring of padding) bucketed by a counting sort, so every cell lists its indices ascending, exactly
  // like the Map buckets filled in index order: same pairs in the same order, without hashing or per-cell arrays.
  // Cell c is spIdx[spHead[c]..spStart[c]); i runs ascending and is the head of its own cell, so dropping it there
  // first leaves only j > i in every list. A sparse, far-flung field falls back to the Map.
  const gw = maxX - minX + 3, gh = maxZ - minZ + 3, cells = gw * gh;
  const dense = N > 0 && cells <= 64 * N;
  if (dense) {
    if (spStart.length < cells + 1) { spStart = new Int32Array(cells + 1); spHead = new Int32Array(cells + 1); } else spStart.fill(0, 0, cells + 1);
    if (spIdx.length < N) spIdx = new Int32Array(Math.max(N, 64));
    for (let i = 0; i < N; i++) { const c = (cxi[i] - minX + 1) * gh + (czi[i] - minZ + 1); cxi[i] = c; spStart[c + 1]++; }   // cxi now holds the dense cell
    for (let c = 0; c < cells; c++) { spHead[c] = spStart[c]; spStart[c + 1] += spStart[c]; }
    for (let i = 0; i < N; i++) spIdx[spStart[cxi[i]]++] = i;   // leaves spStart[c] on the end of cell c
  } else {
    settleGrid.clear();
    for (let i = 0; i < N; i++) { const k = cxi[i] * CELLP + czi[i]; let arr = settleGrid.get(k); if (!arr) { arr = []; settleGrid.set(k, arr); } arr.push(i); }
  }
  const row = dense ? gh | 0 : 0;
  for (let i = 0; i < N; i++) {
    const gx = cxi[i], gz = czi[i]; let ax = X[i], az = Z[i];
    if (dense) spHead[gx]++;
    for (let dx = -1; dx <= 1; dx++) for (let dz = -1; dz <= 1; dz++) {
      let arr, t0, t1;
      if (dense) { const c = gx + dx * row + dz; arr = spIdx; t0 = spHead[c]; t1 = spStart[c]; if (t0 === t1) continue; }
      else { arr = settleGrid.get((gx + dx) * CELLP + (gz + dz)); if (!arr) continue; t0 = 0; t1 = arr.length; }
      for (let t = t0; t < t1; t++) {
        const j = arr[t]; if (j <= i) continue;
        const ddx = X[j] - ax, ddz = Z[j] - az;
        if ((Math.abs(ddx) >= D) | (Math.abs(ddz) >= D)) continue;   // outside the box → outside the disc (hypot >= |ddx|, |ddz| exactly), skips the costly hypot; one branch
        const d = hyp(ddx, ddz);
        if (d >= D) continue;
        let nx, nz;
        if (d < 1e-6) { const ang = hash(A[i].mac + A[j].mac) * Math.PI * 2; nx = Math.cos(ang); nz = Math.sin(ang); }
        else { nx = ddx / d; nz = ddz / d; }
        const pd = (D - d) / 2 * push;
        ax -= nx * pd; az -= nz * pd; X[j] += nx * pd; Z[j] += nz * pd;
      }
    }
    X[i] = ax; Z[i] = az;
  }
}
function settleRadialHome() {   // radial leash (±radialTolPx) then tangential home restoration
  const A = settleActive, N = A.length, tolW = sTolW, X = sX, Z = sZ;
  for (let i = 0; i < N; i++) {
    const a = A[i], rHome = a.homeR + a.jitterR; let x = X[i], z = Z[i]; const rNow = hyp(x, z);
    if (Math.abs(rNow - rHome) > tolW && rNow > 1e-6) { const rt = rNow > rHome ? rHome + tolW : rHome - tolW; x = x / rNow * rt; z = z / rNow * rt; }
    X[i] = x + (a.homeX - x) * LAYOUT.homePull; Z[i] = z + (a.homeZ - z) * LAYOUT.homePull;
  }
}
// Zone grid for settleObstacle and settleDetrap: a dense grid over the zones' bounding box. Cell c lists, ascending
// (ogIdx[ogStart[c]..ogStart[c+1])), every zone whose box [x - need, x + need] touches it. That takes no slack: a
// coordinate below fl(x - need) is <= x - need exactly (no double lies strictly between a real and its rounding), so
// its box test fails, and floor(v / cell) is monotone. So a cell's list holds every zone a point in that cell can
// violate, whatever the cell size. Rebuilt when the obstacles (buildObstacles) or the scale (buf) change.
let obsGridVer = 0, obsGridKey = -1, obsGridBuf = NaN, obsGridCell = 1, ogX0 = 0, ogZ0 = 0, ogW = 0, ogH = 0;
let ogStart = new Int32Array(1), ogIdx = new Int32Array(0), obX = new Float64Array(0), obZ = obX, obNeed = obX;
function obstacleGrid(buf) {
  if (obsGridKey === obsGridVer && obsGridBuf === buf) return;
  obsGridKey = obsGridVer; obsGridBuf = buf;
  const obs = settleObstacles, M = obs.length;
  if (obX.length < M) { obX = new Float64Array(M); obZ = new Float64Array(M); obNeed = new Float64Array(M); }
  let cell = 0; for (let o = 0; o < M; o++) { const ob = obs[o]; obX[o] = ob.x; obZ[o] = ob.z; cell += obNeed[o] = ob.zone + buf; }
  cell = M ? Math.max(cell / M, 1e-6) / 2 : 1;
  let x0 = 0, z0 = 0, gw = 0, gh = 0;
  for (;;) {   // cells double until a far-flung field fits a small grid; a zone with non-finite bounds is listed nowhere
    let x1 = -Infinity, z1 = -Infinity; x0 = z0 = Infinity;
    for (let o = 0; o < M; o++) {
      const need = obNeed[o], a = Math.floor((obX[o] - need) / cell), b = Math.floor((obX[o] + need) / cell), c = Math.floor((obZ[o] - need) / cell), d = Math.floor((obZ[o] + need) / cell);
      if (a < x0) x0 = a; if (b > x1) x1 = b; if (c < z0) z0 = c; if (d > z1) z1 = d;
    }
    gw = x1 - x0 + 1; gh = z1 - z0 + 1;
    if (!(gw > 0 && gh > 0)) { gw = gh = 0; break; }
    if (gw * gh <= 64 * M + 4096) break;
    cell *= 2;
  }
  const cells = gw * gh;
  if (ogStart.length < cells + 1) ogStart = new Int32Array(cells + 1); else ogStart.fill(0, 0, cells + 1);
  for (let pass = 0; pass < 2 && cells; pass++) {   // count, then fill from the last zone down: ascending lists, ogStart[c] ends on the cell's start
    if (pass) {
      let n = 0;
      for (let c = 0; c < cells; c++) { n += ogStart[c]; ogStart[c] = n; }
      ogStart[cells] = n;
      if (ogIdx.length < n) ogIdx = new Int32Array(n);
    }
    for (let o = M - 1; o >= 0; o--) {
      const need = obNeed[o], a = Math.floor((obX[o] - need) / cell) - x0, b = Math.floor((obX[o] + need) / cell) - x0, c = Math.floor((obZ[o] - need) / cell) - z0, d = Math.floor((obZ[o] + need) / cell) - z0;
      for (let gx = a; gx <= b; gx++) for (let gz = c; gz <= d; gz++) { if (pass) ogIdx[--ogStart[gx * gh + gz]] = o; else ogStart[gx * gh + gz]++; }
    }
  }
  obsGridCell = cell; ogX0 = x0; ogZ0 = z0; ogW = gw; ogH = gh;
}
function settleObstacle() {   // project each client out of every violated zone (one sweep, in obstacle order), then out of the core
  const A = settleActive, N = A.length, core = sCoreKeep, X = sX, Z = sZ;
  obstacleGrid(sD * 0.5);
  const cell = obsGridCell, x0 = ogX0, z0 = ogZ0, gw = ogW, gh = ogH, start = ogStart, idx = ogIdx, oX = obX, oZ = obZ, oNeed = obNeed;
  for (let i = 0; i < N; i++) {
    let x = X[i], z = Z[i];
    // Walk the zones of the client's cell in ascending order; after a projection moves it, continue with the
    // higher-numbered zones of its new cell. Zones outside the cell cannot be violated, so this visits exactly the
    // zones the full ascending scan would act on, in the same order.
    for (let oMin = 0, moved = true; moved;) {
      moved = false;
      const gx = Math.floor(x / cell) - x0, gz = Math.floor(z / cell) - z0;
      if (!(gx >= 0 && gx < gw && gz >= 0 && gz < gh)) break;   // off the grid (or NaN): no zone in reach
      for (let c = gx * gh + gz, t = start[c], e = start[c + 1]; t < e; t++) {
        const o = idx[t]; if (o < oMin) continue;
        const need = oNeed[o], ox = oX[o], oz = oZ[o], ddx = x - ox, ddz = z - oz;
        if ((Math.abs(ddx) >= need) | (Math.abs(ddz) >= need)) continue;   // same exact box reject as settlePairPass
        const d = hyp(ddx, ddz);
        if (d >= need) continue;
        if (d < 1e-6) { const ang = hash(A[i].mac + "o" + o) * Math.PI * 2; x = ox + Math.cos(ang) * need; z = oz + Math.sin(ang) * need; }
        else { x = ox + ddx / d * need; z = oz + ddz / d * need; }
        oMin = o + 1; moved = true; break;
      }
    }
    if (Math.max(Math.abs(x), Math.abs(z)) < core) {   // outside the core's box → outside the core
      const rr = hyp(x, z);
      if (rr < core) { if (rr < 1e-6) { x = core; z = 0; } else { x = x / rr * core; z = z / rr * core; } }
    }
    X[i] = x; Z[i] = z;
  }
}
function relaxIter() {
  const A = settleActive, N = A.length, X = sX, Z = sZ;
  for (let i = 0; i < N; i++) { const a = A[i]; p0x[i] = X[i] = a.lx; p0z[i] = Z[i] = a.lz; }   // the passes work on plain doubles, written back below
  settlePairPass(); settleRadialHome();
  settleObstacle(); settlePairPass(); settleObstacle();
  let maxD = 0;
  for (let i = 0; i < N; i++) { const a = A[i], x = X[i], z = Z[i], dd = hyp(x - p0x[i], z - p0z[i]); a.lx = x; a.lz = z; if (dd > maxD) maxD = dd; }
  return maxD * maxRadius;
}
function spreadStep(iters) {
  const N = settleActive.length;
  if (!N) { settleConverged = true; S.settling = false; return 0; }
  settleConstants();
  let done = 0;
  for (let it = 0; it < iters; it++) {
    if (settleIterTotal >= LAYOUT.settleMaxIter) { S.settleCapped = true; break; }
    settleIterTotal++; done++;
    if (relaxIter() < LAYOUT.settleEpsPx) { settleConverged = true; S.settling = false; return done; }
  }
  settleConverged = false;
  const capped = settleIterTotal >= LAYOUT.settleMaxIter;
  if (capped) S.settleCapped = true;
  S.settling = !capped;
  return done;
}
// A whole phase 1 in one call (the synchronous part of settleLayout) starts every free client at its home, so its outcome is
// a pure function of the clients (order, MAC, home), the obstacles, the scale and the LAYOUT constants the relaxation reads
// (fixed in the page itself; ?debug=1 hands LAYOUT out writable). A relayout with the very same input (a poll that delivers
// the same capture again, the aggregation toggle) takes the positions and the iteration count of the last run.
let p1Key = null, p1Mac = [], p1Out = null, p1Iter = 0, p1Conv = false;
function spreadPhase1() {   // = spreadStep(PHASE1_CAP) at iteration 0
  if (!(LAYOUT.settleMaxIter > PHASE1_CAP)) return spreadStep(PHASE1_CAP);   // the iteration cap could end phase 1 (S.settleCapped): not memoised
  const A = settleActive, N = A.length, obs = settleObstacles, M = obs.length, key = new Float64Array(10 + 4 * N + 3 * M);
  let k = 10, same = p1Key !== null && p1Key.length === key.length;
  key[0] = maxRadius; key[1] = inner; key[2] = N;
  key[3] = LAYOUT.pushFactor; key[4] = LAYOUT.homePull; key[5] = LAYOUT.clientMinDistPx; key[6] = LAYOUT.radialTolPx; key[7] = LAYOUT.coreZonePx; key[8] = LAYOUT.settleEpsPx; key[9] = LAYOUT.settleMaxIter;
  for (let i = 0; i < N; i++) { const a = A[i]; key[k++] = a.homeX; key[k++] = a.homeZ; key[k++] = a.homeR; key[k++] = a.jitterR; if (same && a.mac !== p1Mac[i]) same = false; }
  for (let o = 0; o < M; o++) { const ob = obs[o]; key[k++] = ob.x; key[k++] = ob.z; key[k++] = ob.zone; }
  for (let i = 0; same && i < k; i++) if (!Object.is(key[i], p1Key[i])) same = false;
  if (same) {
    for (let i = 0; i < N; i++) { A[i].lx = p1Out[2 * i]; A[i].lz = p1Out[2 * i + 1]; }
    settleIterTotal = p1Iter; settleConverged = p1Conv; S.settling = !p1Conv;
    return p1Iter;
  }
  const used = spreadStep(PHASE1_CAP);
  p1Key = key; p1Mac = A.map(a => a.mac); p1Out = new Float64Array(2 * N); p1Iter = used; p1Conv = settleConverged;
  for (let i = 0; i < N; i++) { p1Out[2 * i] = A[i].lx; p1Out[2 * i + 1] = A[i].lz; }
  return used;
}
function settleDetrap() {
  // Dense/forced fields: the star zones tile the crowded radial band, so relaxation can leave singles wedged
  // in overlapping zones. Place the remaining singles greedily instead — each at the first spot (golden-angle scan
  // around its home, widening radially) that clears every obstacle and stays >= clientMinDistPx from earlier singles.
  const A = settleActive;
  if (!A.length || !aggForced()) return;
  settleConstants();
  const D = sD, cell = sCell, M = settleObstacles.length, tol = sTolW, core = sCoreKeep;
  const grid = new Map();
  const addGrid = (x, z) => { const k = Math.floor(x / cell) * CELLP + Math.floor(z / cell); let arr = grid.get(k); if (!arr) { arr = []; grid.set(k, arr); } arr.push([x, z]); };
  // Most scanned spots sit inside some zone. settleObstacle's zone grid (same radius: zone + D/2) finds it among the
  // few zones of the spot's cell, box test first (hypot >= |dx|, |dz| exactly). It only ever answers "inside"; a spot
  // that is used is still cleared by the full scan (clearOf), so the result never rests on the grid listing every zone.
  obstacleGrid(D / 2);
  const gCell = obsGridCell, x0 = ogX0, z0 = ogZ0, gw = ogW, gh = ogH, oX = obX, oZ = obZ, oR = obNeed;
  // cov marks the fine cells (a quarter of a grid cell wide) that lie wholly inside one zone: the far corner is inside
  // by a 1e-6 margin, orders above the rounding in floor(v / f) and hypot (1e-16 of coordinates that are at most some
  // hundred zone radii). A spot in such a cell is inside untested.
  const f = gCell / 4, cw = gw * 4, ch = gh * 4, fx0 = x0 * 4, fz0 = z0 * 4, cov = new Uint8Array(cw * ch);
  for (let o = 0; o < M; o++) {
    const ox = oX[o], oz = oZ[o], r = oR[o] * (1 - 1e-6);
    const a = Math.max(0, Math.floor((ox - r) / f) - fx0), b = Math.min(cw - 1, Math.floor((ox + r) / f) - fx0), c = Math.max(0, Math.floor((oz - r) / f) - fz0), d = Math.min(ch - 1, Math.floor((oz + r) / f) - fz0);
    for (let i = a; i <= b; i++) {
      const lx = (i + fx0) * f, ax = Math.max(Math.abs(lx - ox), Math.abs(lx + f - ox));
      for (let j = c; j <= d; j++) { const lz = (j + fz0) * f, az = Math.max(Math.abs(lz - oz), Math.abs(lz + f - oz)); if (ax * ax + az * az < r * r) cov[i * ch + j] = 1; }
    }
  }
  const start = ogStart, idx = ogIdx;
  const inZone = (x, z) => {
    const fx = Math.floor(x / f) - fx0, fz = Math.floor(z / f) - fz0;
    if (fx >= 0 && fx < cw && fz >= 0 && fz < ch && cov[fx * ch + fz]) return true;
    const gx = Math.floor(x / gCell) - x0, gz = Math.floor(z / gCell) - z0;
    if (!(gx >= 0 && gx < gw && gz >= 0 && gz < gh)) return false;
    for (let c = gx * gh + gz, t = start[c], e = start[c + 1]; t < e; t++) {
      const o = idx[t], r = oR[o], dx = x - oX[o], dz = z - oZ[o];
      if (Math.max(Math.abs(dx), Math.abs(dz)) < r && hyp(dx, dz) - r < 0) return true;
    }
    return false;
  };
  const clearOf = (x, z, lo) => {   // clearance to obstacles (>= 0 = outside every zone) of a spot outside the core
    // The caller only reads the sign, and the value itself only when it is >= 0 and above lo: so the scan stops on a
    // negative or once the minimum is down to lo; a zone whose box distance already reaches the running minimum is
    // skipped (box test, see above).
    let m = hyp(x, z) - core; if (m !== m) m = Infinity;   // a NaN core clearance (zero-size viewport) never lowers the minimum
    for (let o = 0; o < M; o++) {
      const r = oR[o], dx = x - oX[o], dz = z - oZ[o];
      if (Math.abs(dx) - r >= m || Math.abs(dz) - r >= m) continue;
      const q = hyp(dx, dz) - r; if (q < m) { m = q; if (m < 0 || m <= lo) return m; }
    }
    return m;
  };
  const nnDist = (x, z) => {   // distance to nearest already-placed single
    const gx = Math.floor(x / cell), gz = Math.floor(z / cell); let m = Infinity;
    for (let dx = -1; dx <= 1; dx++) for (let dz = -1; dz <= 1; dz++) { const arr = grid.get((gx + dx) * CELLP + (gz + dz)); if (!arr) continue; for (const p of arr) { const q = hyp(x - p[0], z - p[1]); if (q < m) m = q; } }
    return m;
  };
  const radials = [0];   // 0, ±tol, ±2·tol … ±7·tol
  for (let i = 1; i <= 7; i++) radials.push(i * tol, -i * tol);
  const SCAN = 220, cosK = new Float64Array(SCAN), sinK = new Float64Array(SCAN);   // the scan angles depend on the client only, not on the radial
  for (const c of A) {
    const homeR = c.homeR + c.jitterR, homeA = c.homeAngle;
    let fx = null, fz = 0, bestScore = -Infinity, bx = 0, bz = 0, filled = 0;   // filled: scan angles of this client already in cosK/sinK
    for (let ri = 0; ri < radials.length && fx === null; ri++) {
      const rad = homeR + radials[ri]; if (rad < core) continue;
      for (let k = 0; k < SCAN; k++) {
        if (k === filled) { const ang = homeA + k * PHI_GOLD; cosK[k] = Math.cos(ang); sinK[k] = Math.sin(ang); filled++; }   // on demand: most singles take one of their first spots
        const x = cosK[k] * rad, z = sinK[k] * rad;
        if (!(Math.max(Math.abs(x), Math.abs(z)) > core) && hyp(x, z) - core < 0) continue;   // in the core (box test, see above)
        if (inZone(x, z)) continue;
        const nn = nnDist(x, z);
        if (nn < D && nn <= bestScore) continue;   // too close to a neighbour to beat the fallback (score <= nn)
        const co = clearOf(x, z, nn < D ? bestScore : -Infinity);
        if (co >= 0) {
          if (nn >= D) { fx = x; fz = z; break; }
          const score = Math.min(co, nn);      // fallback: best obstacle-clear spot even if a bit close to a neighbour
          if (score > bestScore) { bestScore = score; bx = x; bz = z; }
        }
      }
    }
    if (fx === null && bestScore > -Infinity) { fx = bx; fz = bz; }
    if (fx === null) { fx = c.lx; fz = c.lz; }
    c.lx = fx; c.lz = fz; addGrid(fx, fz);
  }
}
// settleDetrap() is a pure function of the singles (order, home, relaxed position), the obstacles, the scale and the three
// LAYOUT constants of settleConstants(): a relayout that ends on the very same input (a poll that delivers the same capture
// again) takes the spots of the last run.
let dtKey = null, dtOut = null;
function detrapSingles() {
  const A = settleActive, N = A.length, obs = settleObstacles, M = obs.length;
  if (!N || !aggForced()) return;   // settleDetrap's own gate
  const key = new Float64Array(6 + 5 * N + 3 * M);
  let k = 6, same = dtKey !== null && dtKey.length === key.length;
  key[0] = maxRadius; key[1] = inner; key[2] = N; key[3] = LAYOUT.clientMinDistPx; key[4] = LAYOUT.radialTolPx; key[5] = LAYOUT.coreZonePx;
  for (let i = 0; i < N; i++) { const c = A[i]; key[k++] = c.homeR; key[k++] = c.jitterR; key[k++] = c.homeAngle; key[k++] = c.lx; key[k++] = c.lz; }
  for (let o = 0; o < M; o++) { const ob = obs[o]; key[k++] = ob.x; key[k++] = ob.z; key[k++] = ob.zone; }
  for (let i = 0; same && i < k; i++) if (!Object.is(key[i], dtKey[i])) same = false;
  if (!same) { settleDetrap(); dtKey = key; dtOut = new Float64Array(2 * N); for (let i = 0; i < N; i++) { dtOut[2 * i] = A[i].lx; dtOut[2 * i + 1] = A[i].lz; } }
  else for (let i = 0; i < N; i++) { A[i].lx = dtOut[2 * i]; A[i].lz = dtOut[2 * i + 1]; }
}
function runSettlePhases(budget) {
  let remaining = budget;
  while (S.settlePhase !== 0 && remaining > 0) {
    let stepBudget = remaining;
    if (S.settlePhase === 1) stepBudget = Math.min(remaining, Math.max(1, PHASE1_CAP - settleIterTotal));
    const used = S.settlePhase === 1 && stepBudget === PHASE1_CAP ? spreadPhase1() : spreadStep(stepBudget);   // = PHASE1_CAP only at iteration 0
    remaining -= used;
    if (S.settleCapped) {   // out of iteration budget: still aggregate + place so the layout is usable
      if (S.settlePhase === 1) { rebuildBubbles(); buildActive(2); buildObstacles(true); }
      S.settlePhase = 0; detrapSingles(); break;
    }
    if (S.settlePhase === 1) {
      if (!settleConverged && settleIterTotal < PHASE1_CAP) break;   // frame budget spent, keep spreading next frame
      rebuildBubbles(); S.settlePhase = 2; buildActive(2); buildObstacles(true);
    } else {
      if (!settleConverged) break;   // phase-2 needs more iterations next frame
      S.settlePhase = 0; detrapSingles();
    }
  }
  S.settling = S.settlePhase !== 0;
}
function settleLayout(maxIter) {
  if (!S.layoutDirty) return settleIterTotal;
  S.layoutDirty = false;
  placeAPs();
  for (const ap of S.apOrder) {
    const hex = (ap.orbitCount ?? ap.clientCount) >= LAYOUT.hexAbove;
    ap.orbitKeep = ap.orbitHex === hex;   // lanes ↔ hex: every orbit of that AP starts anew
    ap.orbitHex = hex;
    if (!ap.orbitKeep) ap.hexA = 0;
  }
  let shown = false;
  for (const c of S.clientOrder) {
    if (c.free) { if (c.placed) shown = true; homeOfClient(c); if (!c.placed) { c.wx = c.lx; c.wz = c.lz; c.placed = true; } }
    else {
      const ap = S.aps.get(c.parent);
      if (ap) {
        orbitOfClient(c, ap);
        if (!c.placed) {
          c.wx = ap.wx + Math.cos(c.orbitPhase) * c.orbitR / maxRadius;
          c.wz = ap.wz + Math.sin(c.orbitPhase) * c.orbitR / maxRadius;
          c.placed = true;
        }
      }
    }
  }
  for (const k of S.cloudOrder) { if (k.placed) shown = true; homeOfClient(k); if (!k.placed) { k.wx = k.lx; k.wz = k.lz; k.placed = true; } }   // §8.8a
  S.bt.forEach(k => { homeOfClient(k); if (!k.placed) { k.wx = k.lx; k.wz = k.lz; k.placed = true; } });
  // stations on screen wait for the settled layout instead of following the relaxation from their homes; not when this interrupts
  // a running relaxation (relayouts faster than the settle would freeze them)
  S.relayHold = shown && S.settlePhase === 0;
  S.relayT0 = S.clock;
  settleIterTotal = 0; S.settleCapped = false; S.settlePhase = 1;
  buildActive(1); buildObstacles(false);
  runSettlePhases(maxIter);
  return settleIterTotal;
}
function countFreeLayout() { let k = 0; S.clients.forEach(n => { if (n.target === 1 && n.free && !n.randOut) k++; }); return S.ui.random === "cloud" ? k + S.cloudOrder.length : k; }   // S.nFreeTotal (§8.8a)
function heldFree(n) { return S.relayHold && S.settlePhase !== 0 && n.bubble == null && n.born < S.relayT0; }   // a free single that was on screen before this relayout (settleLayout): its display waits; one that arrived with it follows the relaxation. Bubbles and APs are not held, so a held single may wait inside a disc or zone until the glide
function freeSingles() {
  const a = S.clientOrder.filter(c => c.free && c.target === 1 && !c.randOut && c.bubble == null && !(c.alphaDraw < 0.5));
  if (S.ui.random === "cloud") for (const k of S.cloudOrder) if (!(k.alphaDraw < 0.5)) a.push(k);
  return a;
}
function layoutInfo() {
  const list = S.apOrder;
  let apMinGapPx = Infinity, apRadiusErrPx = 0;
  for (let i = 0; i < list.length; i++) {
    const a = list[i];
    apRadiusErrPx = Math.max(apRadiusErrPx, Math.abs(a.radiusT * maxRadius - rssiToRadius(a.rssi)));
    const ax = Math.cos(a.angleT) * a.radiusT * maxRadius, ay = Math.sin(a.angleT) * a.radiusT * maxRadius;
    for (let j = i + 1; j < list.length; j++) {
      const b = list[j];
      if (S.ui.filters[a.band] === false || S.ui.filters[b.band] === false) continue;
      const bx = Math.cos(b.angleT) * b.radiusT * maxRadius, by = Math.sin(b.angleT) * b.radiusT * maxRadius;
      const d = Math.hypot(ax - bx, ay - by) - (basePxMax(a) + basePxMax(b));
      if (d < apMinGapPx) apMinGapPx = d;
    }
  }
  const free = freeSingles();
  let minD = Infinity, overlaps = 0; const nn = [];
  for (let i = 0; i < free.length; i++) {
    let best = Infinity;
    for (let j = 0; j < free.length; j++) {
      if (i === j) continue;
      const d = Math.hypot(free[i].sx - free[j].sx, free[i].sy - free[j].sy);
      if (d < best) best = d;
      if (j > i && d < 7) overlaps++;
    }
    if (best < minD) minD = best;
    nn.push(best === Infinity ? 0 : best);
  }
  nn.sort((a, b) => a - b);
  const pick = (q) => nn.length ? nn[Math.min(nn.length - 1, Math.floor(q * nn.length))] : 0;
  let inStar = 0, inHalo = 0, inOrbit = 0;
  for (const c of free) {
    let s = false, h = false, o = false;
    for (const ap of S.apOrder) {
      if (S.ui.filters[ap.band] === false) continue;
      const d = Math.hypot(c.sx - ap.sx, c.sy - ap.sy);
      if (d < starZonePx(ap)) s = true;
      if (d < 3.0 * basePxMax(ap)) h = true;
      if (ap.clientCount > 0 && d < orbitZonePx(ap)) o = true;
    }
    if (s) inStar++; if (h) inHalo++; if (o) inOrbit++;
  }
  return { minClientDistancePx: r3(free.length > 1 && minD !== Infinity ? minD : 0), p5ClientDistancePx: r3(pick(0.05)), medianClientDistancePx: r3(pick(0.5)),
    overlapsPx: overlaps, clientsInStarZone: inStar, clientsInApHalo: inHalo, freeInOrbitZone: inOrbit,
    apMinGapPx: r3(apMinGapPx === Infinity ? 0 : apMinGapPx), apRadiusErrPx: r3(apRadiusErrPx), clusterCount: S.bubbles.size,
    settled: S.settlePhase === 0 && !S.settleCapped, iterations: settleIterTotal, labelsDrawn: S.labelsDrawn, labelCollisions: S.labelCollisions, labelsOutside: S.labelsOutside };
}

// §9.8b the Scope
const thv = (g, r) => r * Math.sin(g.th) <= g.half ? g.th : Math.asin(g.half / r);
const scXY = (g, r, k) => { const a = k * thv(g, r); return [g.ox + r * Math.sin(a), g.oy - r * Math.cos(a)]; };
const scL = (c, f) => { c.beginPath(); for (let i = 0; i <= 40; i++) { const q = f(i / 40); c.lineTo(q[0], q[1]); } c.stroke(); };
const scR = (g, d) => g.rNear + (1 - rssiT(d)) * (g.rFar - g.rNear);
const scU = (b, ch) => ch == null ? 0.5 : clamp(b === "5" ? (ch - 32) / 145 : b === "6" ? 0.8 * (ch - 1) / 232 : (ch - 1) / 13, 0, 1);
function scopeGeom() {
  const b = skyBox(), set = (k, v) => DE.style.setProperty(k, Math.round(v) + "px");
  set("--sc-x", b.x + 8); set("--sc-w", b.w - 16); set("--sc-y", b.y); set("--sc-b", H - b.y - b.h);
  const ps = el("sc-ps").getBoundingClientRect(), top = b.y + el("scope-strip").offsetHeight + 4, py = ps.top + ps.height / 2, L = py - top - SCOPE.rim, rNear = Math.max(34, 0.18 * L), oy = py - SCOPE.near + rNear;
  el("sc-no").hidden = L >= SCOPE.minL;
  if (L < SCOPE.minL) return SC.g = null;
  return SC.g = { b, top, py, oy, rNear, ox: b.x + b.w / 2, rFar: oy - top - SCOPE.rim, th: SCOPE.half * Math.PI / 180, half: b.w / 2 - 10 };
}
function scopePlace(wave) {
  const g = SC.g, ls = { "2.4": [], "5": [], "6": [], sta: [], bt: S.ui.filters.bt ? S.btOrder.slice(0, BT.drawMax) : [] }, u = ls.bt.length ? 0.8368 : 1;
  let k = -1;
  g.lanes = SCOPE.lanes.concat(u < 1 ? [["bt", 0.35]] : []).map(([key, w]) => { const l = { key, k0: k, k1: k += w * u }; k += SCOPE.gap * u; return l; });
  SC.st++; SC.unk = false;
  for (const a of S.apOrder) if (S.ui.filters[a.band] !== false) ls[a.band in ls ? a.band : (SC.unk = true, "6")].push(a);
  for (const c of S.clientOrder) if (!c.randOut) ls.sta.push(c);
  if (S.ui.random === "cloud") ls.sta.push(...S.cloudOrder);
  for (const l of g.lanes) {
    const done = [];
    for (const n of ls[l.key]) {
      const ap = n.kind === "ap", r = scR(g, n.rssi ?? -85), t = r * thv(g, r), px = ap ? n.basePx * SCOPE.size : n.basePx, f = px + 3, h = hash(n.id + "sc");
      const ideal = l.k0 + (SCOPE.pad + (1 - 2 * SCOPE.pad) * (!ap ? h : n.band === "unknown" ? 0.8 + 0.2 * h : scU(n.band, n.channel))) * (l.k1 - l.k0);
      let k = ideal, q = scXY(g, r, k);
      for (let j = 1; j < 9 && n.kind !== "client" && l.k1 - l.k0 > 2 * f / t && done.some(p => hyp(p[0] - q[0], p[1] - q[1]) < p[2] + f + 2); j++) q = scXY(g, r, k = clamp(ideal + (j & 1 ? 1 : -1) * (j + 1 >> 1) * (2 * f + 2) / t, l.k0 + f / t, l.k1 - f / t));
      n.sc = { k, r, x: q[0], y: q[1], px, st: SC.st, nw: wave ? !n.sc || SC.cs < 0 : !!n.sc && n.sc.nw, q: (g.rFar - r) / (g.rFar - g.rNear) };
      if (n.kind !== "client") done.push([q[0], q[1], f]);
    }
  }
  rebuildBackground();
}

