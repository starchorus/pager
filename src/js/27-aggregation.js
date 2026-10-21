// ==== 27 AGGREGATION ====
function newBubble(id, gx, gz) {
  return { id, kind: "bubble", gx, gz, cx: 0, cz: 0, cxT: 0, czT: 0, r: LAYOUT.orbitMinPx, rT: LAYOUT.orbitMinPx,
    sx: 0, sy: 0, zc: 1, fog: 1, px: LAYOUT.orbitMinPx, alpha: 0, target: 1, n: 0, members: [],
    meanRssi: null, vendors: [], randomized: 0, expandedUntil: null, born: S.clock };
}
function rebuildBubbles() {
  const active = S.clientOrder.filter(c => c.free && c.target === 1 && !c.randOut);   // §8.8a
  for (const c of S.clientOrder) if (!c.free || c.randOut) c.bubble = null;
  const nFree = active.length;
  const forced = aggForced();
  if (!S.ui.agg && !forced) {
    S.bubbles.forEach(b => { b.target = 0; });
    for (const c of active) c.bubble = null;
    return;
  }
  const minCell = AGG.minCell(nFree), minCluster = AGG.minCluster(nFree), cellPx = AGG.cellPx;
  const keyOf = (gx, gz) => gx + ":" + gz;
  const cells = new Map();
  for (const c of active) {
    const gx = Math.floor(c.lx * maxRadius / cellPx), gz = Math.floor(c.lz * maxRadius / cellPx), k = keyOf(gx, gz);
    let e = cells.get(k); if (!e) { e = { gx, gz, list: [] }; cells.set(k, e); }
    e.list.push(c);
  }
  const occupied = []; cells.forEach(e => { if (e.list.length >= minCell) occupied.push(e); });
  occupied.sort((a, b) => a.gz - b.gz || a.gx - b.gx);
  const occSet = new Map(); for (const e of occupied) occSet.set(keyOf(e.gx, e.gz), e);
  const visited = new Set(), clusters = [];
  for (const start of occupied) {
    if (visited.has(keyOf(start.gx, start.gz))) continue;
    const cluster = [], queue = [start];
    while (queue.length && cluster.length < AGG.maxCellsPerBubble) {
      const e = queue.shift(), ek = keyOf(e.gx, e.gz);
      if (visited.has(ek)) continue;
      visited.add(ek); cluster.push(e);
      for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) {
        if (dx === 0 && dz === 0) continue;
        const nk = keyOf(e.gx + dx, e.gz + dz);
        if (occSet.has(nk) && !visited.has(nk)) queue.push(occSet.get(nk));
      }
    }
    clusters.push(cluster);
  }
  const live = new Set(), memberOf = new Map();
  for (const cluster of clusters) {
    const members = []; for (const e of cluster) for (const c of e.list) members.push(c);
    let anchor = cluster[0];
    for (const e of cluster) if (e.list.length > anchor.list.length || (e.list.length === anchor.list.length && (e.gz < anchor.gz || (e.gz === anchor.gz && e.gx < anchor.gx)))) anchor = e;
    const id = "b:" + anchor.gx + ":" + anchor.gz;
    const existing = S.bubbles.get(id);
    const threshold = (existing && existing.target === 1) ? AGG.keepFrac * minCluster : minCluster;
    if (members.length < threshold) continue;
    let cx = 0, cz = 0, rssiSum = 0, rssiN = 0, rnd = 0; const vmap = new Map();
    for (const c of members) {
      cx += c.lx; cz += c.lz;
      if (c.rssi != null) { rssiSum += c.rssi; rssiN++; }
      if (c.randomized) rnd++; else if (c.vendor) vmap.set(c.vendor, (vmap.get(c.vendor) || 0) + 1);
    }
    cx /= members.length; cz /= members.length;
    const r = clamp(8 + 4 * Math.sqrt(members.length), AGG.rMinPx, AGG.rMaxPx);
    let b = existing;
    if (!b) { b = newBubble(id, anchor.gx, anchor.gz); b.cx = cx; b.cz = cz; S.bubbles.set(id, b); }
    b.target = 1; b.cxT = cx; b.czT = cz; b.rT = r; b.n = members.length; b.members = members.map(c => c.mac);
    b.meanRssi = rssiN ? Math.round(rssiSum / rssiN) : null; b.randomized = rnd;
    b.vendors = Array.from(vmap.entries()).sort((x, y) => y[1] - x[1]);
    for (const c of members) memberOf.set(c.mac, id);
    live.add(id);
  }
  S.bubbles.forEach(b => { if (!live.has(b.id)) b.target = 0; });
  for (const c of active) c.bubble = memberOf.get(c.mac) || null;
}
function stepBubbles(dt) {
  const a = S.anim, eB = Math.exp(-a.blendK * dt); let moving = false;
  for (const c of S.clients.values()) {
    let tb = 0;
    if (c.bubble != null) { const b = S.bubbles.get(c.bubble); const ex = b && b.expandedUntil != null && b.expandedUntil > S.clock; tb = (b && b.target === 1 && !ex) ? 1 : 0; }
    const nb = easeBy(c.bubbleBlend, tb, eB);
    if (Math.abs(nb - c.bubbleBlend) > 1e-4) moving = true;
    c.bubbleBlend = nb;
  }
  S.bubbles.forEach((b, id) => {
    b.cx = ease(b.cx, b.cxT, AGG.kPos, dt); b.cz = ease(b.cz, b.czT, AGG.kPos, dt); b.r = ease(b.r, b.rT, AGG.kPos, dt);
    if (b.cx !== b.cxT || b.cz !== b.czT || b.r !== b.rT) moving = true;
    const at = b.target === 1 ? 1 : 0;
    const na = ease(b.alpha, at, at > b.alpha ? a.fadeInK : a.fadeOutK, dt);
    if (na !== b.alpha) moving = true;
    b.alpha = na;
    if (b.expandedUntil != null && b.expandedUntil <= S.clock) { b.expandedUntil = null; moving = true; }
    if (b.target === 0 && b.alpha < 0.02) S.bubbles.delete(id);
  });
  if (moving) S.moving = true;
}
function expandBubble(id) { const b = S.bubbles.get(id); if (!b) return false; b.expandedUntil = S.clock + AGG.expandMs / 1000; S.dirty = true; return true; }

