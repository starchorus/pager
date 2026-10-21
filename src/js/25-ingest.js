// ==== 25 INGEST ====
function newAp(id) {
  return { id, kind: "ap", essBlend: 0, essFolded: false, bssid: id, ssid: "", ssidKnown: null, band: "unknown", bandF: "unknown", channel: null, freq: null, rssi: -75, security: "", sec: "unknown",
    hidden: true, clientCount: 0, vendor: null, rate: null, last_seen: null, width: null, phy: null, caps: null, beacons: null,
    a0: 0, angleT: null, radiusT: 0.5, angle: null, radius: 0.5, wx: 0, wz: 0, p3: [0, 0, 0], p: [0, 0, 0], jitY: hash(id + "y"),
    sx: 0, sy: 0, zc: 1, px: 0, fog: 1, lod: 0, alphaDraw: 0, basePx: 0, basePxMax: LAYOUT.basePxMaxCore,
    target: 1, alpha: 0, born: 0, phase: hash(id + "p") * Math.PI * 2, capSeq: -1, newSeq: -1, changedSeq: -1, cueSeq: -1, cueT0: 0, cueAmp: 0, revealAt: null,
    akm: null, cipher: null, auth: null, respondedSsids: null, packets: null, mobile: false, groupKey: null, interfere: [], sparkDirty: true, flare: 0, flareT: 0, ageS: null, freshTier: null, freshA: 1, freshAT: 1,
    pStart: -1, pCount: 0, pState: null, pT0: 0, orbitRcap: LAYOUT.orbitMaxPx, hexA: 0, seen: false };
}
function newClient(mac) {
  return { id: mac, kind: "client", mac, rssi: null, vendor: null, last_seen: null, packets: null, randomized: false, pk: null, fps: null, gl: 0, cue: false, glow: 0,
    parent: null, free: true, band: null, homeAngle: 0, homeR: 0.5, jitterR: 0, lx: 0, lz: 0, wx: 0, wz: 0, placed: false,   // placed: wx/wz hold a position (a flag instead of null, so both stay plain number fields and the per-frame writes allocate nothing)
    orbitR: 32, orbitPhase: 0, orbitSpeed: 0, orbitTilt: 0, rank: 0, p3: [0, 0, 0], p: [0, 0, 0], jitY: hash(mac + "h"), jitZ: hash(mac + "z"),
    sx: 0, sy: 0, zc: 1, px: 0, fog: 1, lod: 0, alphaDraw: 0, basePx: 3.5, basePxMax: 5,
    target: 1, alpha: 0, born: 0, bubble: null, bubbleBlend: 0, capSeq: -1, newSeq: -1, cloud: null, randOut: false,
    ageS: null, freshTier: null, freshA: 1, freshAT: 1, sparkDirty: true, baseState: null };
}
function histPush(node, rssi, gen) {
  let h = S.hist.get(node.id);
  if (!h) { h = { buf: new Int8Array(HISTORY_LEN), ts: new Float64Array(HISTORY_LEN), head: 0, n: 0, lastGen: null, lastSeq: 0, cl: false }; S.hist.set(node.id, h); }
  h.cl = node.kind === "client";   // the kind follows the writer, so a MAC that moves from station to AP leaves the station cap
  if (gen != null && gen === h.lastGen) return;
  h.buf[h.head] = rssi == null ? -128 : clamp(Math.round(rssi), -120, 0);
  h.ts[h.head] = gen ?? NaN;   // undated sample (document without `generated`): no wall-clock stamp (§2 determinism)
  h.head = (h.head + 1) % HISTORY_LEN; h.n = Math.min(HISTORY_LEN, h.n + 1); h.lastGen = gen; h.lastSeq = S.ingestSeq;
  node.sparkDirty = true;
}
// One push per station of this capture, after both client loops. A MAC that is also a LIVE AP keeps the AP's series (the
// AP pushed first; an undated document would otherwise push twice); a fading AP no longer owns it. At most HIST_CL_MAX station series: room is made by dropping
// series of stations NOT in this capture, longest unheard first; if there is still none, a NEW station gets no series (an
// existing one is never evicted for it), so a present station's history cannot thrash under rotating randomised MACs.
function histPushCl(seenCl, gen) {
  const liveAp = (id) => { const a = S.aps.get(id); return !!a && a.target !== 0; };
  const want = [];
  seenCl.forEach(id => {
    const c = S.clients.get(id);
    if (liveAp(id) || !c) return;
    if (c.cloud != null) { S.hist.delete(id); return; }   // §8.8a: a cloud keeps the series
    want.push(id);
  });
  let ncl = 0; S.hist.forEach(h => { if (h.cl) ncl++; });
  let add = 0; for (const id of want) if (!S.hist.has(id)) add++;
  if (ncl + add > HIST_CL_MAX) {
    const stale = []; S.hist.forEach((h, id) => { if (h.cl && !seenCl.has(id) && !liveAp(id)) stale.push([h.lastSeq, id]); });
    stale.sort((a, b) => a[0] - b[0] || (a[1] < b[1] ? -1 : 1));
    for (let i = 0; i < stale.length && ncl + add > HIST_CL_MAX; i++) { S.hist.delete(stale[i][1]); ncl--; }
  }
  for (const id of want) { if (!S.hist.has(id)) { if (ncl >= HIST_CL_MAX) continue; ncl++; } const cn = S.clients.get(id); histPush(cn, cn.rssi, gen); }
}
function pkRate(n, p, gen) {   // §3.8 frames/s over three captures; n.gl = cue level
  const s = n.pk || (n.pk = []), l = s[s.length - 1];
  if (gen == null || p == null || (l && (p < l[1] || gen - l[0] > Math.max(90, 2 * (S.pollIntervalS || 0) + 15)))) s.length = 0;   // restart on a fall or a gap
  if (gen != null && p != null && !(s.length && s[s.length - 1][0] === gen)) { s.push([gen, p]); if (s.length > 3) s.shift(); }
  const e = s[s.length - 1], r = s.length > 1 ? (e[1] - s[0][1]) / (e[0] - s[0][0]) : null, t = r == null ? 0 : Math.min(1, Math.log10(1 + r) / Math.log10(1 + GLOW.rateFull));
  n.fps = r; n.gl = t < GLOW.min ? 0 : Math.ceil(t * 3);
}
// D2 event record. State (counters, per-node arrival/change/cue marks) belongs to ONE source; a source change resets it, and the
// first capture of a source produces no arrivals or departures. A "capture" is a distinct `generated` (no `generated`: no capture,
// no event). Arrival / departure come only from comparing consecutive captures — node.capSeq is the last capture a node was in —
// never from target/born (an AP that comes back is born again). Stations follow the same rule: an arrival is node.newSeq, a
// departure is counted in eventsSettle like an AP's, and both are exposed per station.
const NEW_CAPTURES = 3, CUE_DB = 3, CUE_S = 0.9;   // "new" lasts 3 captures · RSSI jump that raises the change cue (dB) · cue pulse length (s of S.clock)
function eventsReset() {
  // every register below belongs to the one source (rule above)
  S.captureSeq = 0; S.ev = { lastGen: null, arrived: 0, departed: 0, newStations: 0, departedStations: 0, newInClouds: 0 };
  S.clouds.clear(); S.cloudOrder = []; S.bt.clear(); S.btOrder = []; S.btLvl.clear();   // §8.8a, §3.1
  S.long = new Map(); S.chanPeak = new Map(); S.recvT0 = null;
  S.chg = new Map();
  S.obsFirst = new Map(); S.obsProbe = { firstGen: null }; S.obsWatchSeen = new Set();
  S.sky = { seq: 0, ref: new Map(), t0: null, resets: 0, dev: [] };
  S.aps.forEach(n => { n.capSeq = -1; n.newSeq = -1; n.changedSeq = -1; n.cueSeq = -1; });
  S.clients.forEach(n => { n.capSeq = -1; n.newSeq = -1; n.pk = null; });
}
function eventsBegin(gen, newSource) {   // → true when this ingest is a new capture of the current source
  if (newSource) eventsReset();
  if (gen == null || gen === S.ev.lastGen) return false;
  S.captureSeq++; S.ev.lastGen = gen;
  S.ev.arrived = S.ev.departed = S.ev.newStations = S.ev.departedStations = S.ev.newInClouds = 0;
  return true;
}
const isNewAp = (n) => n.newSeq > 0 && S.captureSeq - n.newSeq < NEW_CAPTURES;
// P3: a probable phone hotspot / ad-hoc network (locally administered BSSID outside every G1 device cluster, hotspot-like SSID or IBSS) raises no
// event, joins no baseline, no watchlist match and no observation; it is only counted ("mobile hotspots: n").
function isMobileLikely(n) {
  if (!ulBit(n.bssid)) return false;
  const dev = S.devices.get(S.deviceOf.get(n.id));
  if (dev && dev.memberIds.length >= 2) return false;
  return MOBILE_SSID_RE.test(n.ssidKnown || n.ssid || "") || !!(n.caps && n.caps.includes("IBSS"));
}
const eventSkip = (n) => !n || n.mobile || S.own.bssids.has(n.id);   // mobile hotspots and this device's own transmitters
const alertNode = (a) => { const n = S.aps.get(a.ap); return eventSkip(n) || S.ui.filters[n.band] === false ? null : n; };
let alAt = Infinity;
function chgPush(id, seq, t, kind, from, to) {
  let a = S.chg.get(id);
  if (!a) { if (S.chg.size >= CHG_BSSIDS) S.chg.delete(S.chg.keys().next().value); a = []; S.chg.set(id, a); }
  a.push({ seq, t, kind, from, to }); if (a.length > CHG_MAX) a.shift();
}
function eventsSettle(pend, gen, seq, seenAp, seenCl) {   // recount the capture's events without mobile/own APs, then write the change log
  let ar = 0, dp = 0, dps = 0;
  S.aps.forEach(n => {
    if (eventSkip(n)) return;
    if (n.newSeq === seq) ar++;
    if (!seenAp.has(n.id) && n.capSeq === seq - 1) dp++;
  });
  S.clients.forEach(n => { if (!seenCl.has(n.id) && n.capSeq === seq - 1) dps++; });   // a station in the previous capture and not in this one
  if (seq > 1) { S.ev.arrived = ar; S.ev.departed = dp; S.ev.departedStations = dps; }
  for (const [id, kind, from, to] of pend) if (!eventSkip(S.aps.get(id))) chgPush(id, seq, gen, kind, from, to);
}
function ingest(doc, opts = {}) {
  // a replay is a VIEW: it rebuilds the nodes for the picture and writes to no engine
  // (events, change log, sky reference, history, long history, peak hold, homing)
  const now = S.clock, rp = !!opts.replay;
  const gen = doc.generated ?? null;   // capture time only; no wall-clock fallback (§2 determinism)
  if (!rp) S.ingestSeq++;
  const cap = rp ? false : eventsBegin(gen, !!opts.newSource), seq = S.captureSeq, cmp = cap && seq > 1, pend = [];   // cmp: a previous capture of this source exists; pend: change-log entries, settled once G1 clusters are known (P3)
  const seenAp = new Set(), seenCl = new Set();
  let changed = false;
  S.source = doc.source; S.note = doc.note; S.generated = doc.generated; S.centerLabel = doc.center.label;
  // the built-in demo skips normalizeDoc, hence the fallbacks
  S.hop = doc.channels || null;
  S.act = new Map((doc.activity || []).map(x => [x.freq, x.share]));   // not S.hop: D19 and the Watchlist read that
  S.own = { bssids: new Set(doc.center.own_bssids || []), ssids: new Set(doc.center.own_ssids || []) };
  S.maxAgeS = doc.center.max_age;   // D1: the collector's age window (null = unknown)
  S.pollIntervalS = doc.center.interval && Math.min(doc.center.interval, POLL.maxIntervalS);   // D3: the announced cadence, capped (null = unknown)
  for (const a of doc.aps) {
    let n = S.aps.get(a.bssid); const isNew = !n;
    if (!n) { n = newAp(a.bssid); S.aps.set(a.bssid, n); changed = true; n.born = now; if (opts.resume) resumeMarks(opts.resume.aps, n); }
    if (n.target !== 1) { n.target = 1; n.born = now; changed = true; }
    if (cap) {   // D2/D18: judged against the values the previous capture left on the node, before they are overwritten
      if (cmp && n.capSeq !== seq - 1) { n.newSeq = seq; S.ev.arrived++; }
      else if (cmp) {
        const ns = secClass(a.security, a.akm, a.cipher);   // same classifier as n.sec below (akm/cipher decide some classes); freq is NOT compared (DS channel only)
        const p0 = pend.length;
        for (const [k, from, to] of [["channel", n.channel, a.channel], ["security", n.sec, ns], ["ssid", n.ssid, a.ssid], ["band", n.band, a.band]]) if (from !== to) pend.push([n.id, k, from, to]);
        if (pend.length > p0) n.changedSeq = seq;
        if (n.rssi != null && a.rssi != null && Math.abs(a.rssi - n.rssi) >= CUE_DB) { n.cueSeq = seq; n.cueT0 = S.clock; n.cueAmp = Math.min(1, Math.abs(a.rssi - n.rssi) / 12); S.twinkles++; }
      }
      n.capSeq = seq;
    }
    if (n.rssi !== a.rssi || n.ssid !== a.ssid || n.band !== a.band) changed = true;   // placement: radius, constellation pull (SSID), band filter
    if (a.ssid) {
      if (n.seen && n.hidden) { n.revealAt = now; S.revealed++; }
      n.ssidKnown = a.ssid; n.hidden = false;
    } else if (n.ssidKnown == null) n.hidden = true;
    n.seen = true;
    n.ssid = a.ssid; n.band = a.band; n.bandF = a.bandF ?? bandOf(a.band, a.freq, null); n.channel = a.channel; n.freq = a.freq; n.rssi = a.rssi;   // bandF: band/freq only (the demo skips normalizeDoc)
    n.security = a.security; n.sec = secClass(a.security, a.akm, a.cipher);
    n.akm = a.akm; n.cipher = a.cipher; n.auth = a.auth; n.respondedSsids = a.responded_ssids; n.packets = a.packets;
    n.vendor = a.vendor; n.rate = a.rate; n.width = a.width; n.last_seen = a.last_seen; n.phy = a.phy; n.caps = a.caps; n.beacons = a.beacons;
    const fr = freshOf(a.last_seen, gen); n.ageS = fr.ageS; n.freshTier = fr.tier;   // D1
    n.freshAT = ENCODING.fresh.alpha[fr.tier ?? 0]; if (isNew) n.freshA = n.freshAT;
    n.clientCount = a.clients.length;
    n.basePxMax = basePxMax(n);
    n.groupKey = (n.ssidKnown ?? n.ssid).trim() || null;
    if (!rp) histPush(n, a.rssi, gen);
    if (cap) longPush(n.id, a.rssi, seq);
    seenAp.add(n.id);
    const sorted = a.clients.slice().sort((x, y) => cmpStr(x.mac, y.mac));
    sorted.forEach((c, rank) => {
      let cn = S.clients.get(c.mac); const cNew = !cn;
      if (!cn) { cn = newClient(c.mac); S.clients.set(c.mac, cn); changed = true; cn.born = now; if (opts.resume) resumeMarks(opts.resume.cl, cn); }
      if (cap) { if (cmp && cn.capSeq !== seq - 1) { cn.newSeq = seq; cn.newT0 = S.clock; S.ev.newStations++; } cn.capSeq = seq; }
      if (cNew || cn.free || cn.affinity || cn.parent !== n.id) cn.orbitPhase = NaN;   // a new orbit: orbitOfClient() starts its phase
      if (cn.target !== 1 || cn.free || cn.affinity || cn.parent !== n.id || cn.rssi !== c.rssi) changed = true;
      cn.target = 1; cn.parent = n.id; cn.free = false; cn.band = n.band; cn.rank = rank;
      cn.rssi = c.rssi; cn.vendor = c.vendor; cn.last_seen = c.last_seen; cn.packets = c.packets; cn.randomized = c.randomized;
      if (!rp) pkRate(cn, c.packets, gen);
      cn.probes = c.probes; cn.affinity = false; cn.probeVia = null;
      const fc = freshOf(c.last_seen, gen); cn.ageS = fc.ageS; cn.freshTier = fc.tier;   // D1: the station's own last_seen, never its AP's
      cn.freshAT = ENCODING.fresh.alpha[fc.tier ?? 0]; if (cNew) cn.freshA = cn.freshAT;
      seenCl.add(c.mac);
    });
  }
  for (const c of doc.unassociated) {
    if (seenCl.has(c.mac)) continue;
    let cn = S.clients.get(c.mac); const cNew = !cn;
    if (!cn) { cn = newClient(c.mac); S.clients.set(c.mac, cn); changed = true; cn.born = now; if (opts.resume) resumeMarks(opts.resume.cl, cn); }
    if (cap) { if (cmp && cn.capSeq !== seq - 1) { cn.newSeq = seq; cn.newT0 = S.clock; S.ev.newStations++; } cn.capSeq = seq; }
    if (cn.target !== 1 || !(cn.free || cn.affinity) || cn.rssi !== c.rssi) changed = true;
    if (!cn.affinity) { cn.parent = null; cn.free = true; cn.band = null; }   // applyAffinity() below decides the orbit
    cn.target = 1;
    if (String(cn.probes) !== String(c.probes) || cn.vendor !== c.vendor || cn.randomized !== c.randomized) changed = true;   // vendor/randomized: the bubble's summary
    cn.rssi = c.rssi; cn.vendor = c.vendor; cn.last_seen = c.last_seen; cn.packets = c.packets; cn.randomized = c.randomized; cn.probes = c.probes;
    if (!rp) pkRate(cn, c.packets, gen);
    const fc = freshOf(c.last_seen, gen); cn.ageS = fc.ageS; cn.freshTier = fc.tier;   // D1
    cn.freshAT = ENCODING.fresh.alpha[fc.tier ?? 0]; if (cNew) cn.freshA = cn.freshAT;
    seenCl.add(c.mac);
  }
  if (cmp) S.aps.forEach(n => { if (!seenAp.has(n.id) && n.capSeq === seq - 1) S.ev.departed++; });   // D2: in the previous capture, not in this one
  S.aps.forEach(n => { if (!seenAp.has(n.id) && n.target !== 0) { n.target = 0; changed = true; } });
  S.clients.forEach(n => { if (!seenCl.has(n.id) && n.target !== 0) { n.target = 0; changed = true; } });
  if (rebuildClouds(gen, rp)) changed = true;   // §8.8a, before the station history
  rebuildBt(doc, gen, rp);
  if (!rp) { const r = []; S.clients.forEach(c => { c.cue = false; if (c.gl > 0 && c.target === 1) r.push(c); }); r.sort((a, b) => b.fps - a.fps || cmpStr(a.mac, b.mac)).slice(0, GLOW.max).forEach(c => { c.cue = true; }); }   // §3.8 the 24 highest rates carry the cue
  // history sweep: a vanished node's history goes HIST_KEEP_S of capture time after its last sample, or HIST_KEEP_INGESTS ingests when undated (no wall clock)
  if (!rp) histPushCl(seenCl, gen);   // station RSSI history
  const live = (m) => !!m && m.target !== 0;   // a series stays while a present node of EITHER kind carries its key (a MAC can be heard as both)
  if (!rp) S.hist.forEach((h, id) => { if (!live(S.aps.get(id)) && !live(S.clients.get(id)) && (gen != null && h.lastGen != null ? Math.abs(gen - h.lastGen) > HIST_KEEP_S : S.ingestSeq - h.lastSeq > HIST_KEEP_INGESTS)) S.hist.delete(id); });
  if (cap) longSweep(seq);
  rebuildOrders();
  rebuildGroups();
  rebuildDevices();
  S.aps.forEach(n => { n.mobile = isMobileLikely(n); });
  if (cap) {
    eventsSettle(pend, gen, seq, seenAp, seenCl);
    // something new was heard → the receive ring contracts once (not a live cloud's new burst, §8.8a)
    if (cmp && (S.ev.arrived > 0 || S.ev.newStations > S.ev.newInClouds)) S.recvT0 = S.clock;
  }
  rebuildEss();
  if (applyRandom()) changed = true;   // §8.8a, before the probe orbits
  if (applyAffinity()) changed = true;
  let free = 0, assoc = 0;
  S.clients.forEach(n => { if (n.target === 1) { if (n.free || n.affinity) free++; else assoc++; } });
  const freeLayout = countFreeLayout();
  if (S.nFreeTotal !== freeLayout) changed = true;   // the free set was resized since the last layout: aggForced() answers anew
  S.nFreeTotal = freeLayout;
  if (changed) S.layoutDirty = true;
  settleLayout(LAYOUT.settleSyncIter);
  if (opts.newSource) S.relayHold = false;   // another source is another sky: its first layout is not held
  computeGroupEdges();
  securityCounts(); rebuildChannelStats(); rebuildInterference();
  if (cap) { skyUpdate(); chanPeakUpdate(); }
  S.alerts = doc.alerts || [];
  if (!rp) homingIngest(doc.homing || null, seenAp, seenCl, gen);
  baselineRecompute();
  if (cap || gen == null) obsCompute();
  regulatorStart();
  updateStats();   // ends in layoutEdges() → drawChannelBar() with the fresh S._stats/analyzer counts
  if (S.locked && !(S.aps.has(S.locked) || S.clients.has(S.locked) || liveCloud(S.locked) || (S.bt.get(S.locked) || {}).target === 1)) closeDetail();
  else if (S.locked) openDetail(S.locked);
  S.dirty = true;
  return { aps: seenAp.size, clients: seenCl.size, free, assoc };
}
// Probe orbits (derived, passive): an unassociated client whose probe requests name a network that is visible
// right now orbits one of its APs on a dashed "probe orbit". Real association always wins. Deterministic: probes
// scanned in received order; the least-loaded, then strongest matching AP wins (S.apOrder is RSSI-sorted).
function applyAffinity() {
  const bySsid = new Map();   // groupKey → visible APs of that SSID (RSSI-desc, S.apOrder order)
  for (const ap of S.apOrder) {
    if (!ap.groupKey || S.ui.filters[ap.band] === false) continue;
    let a = bySsid.get(ap.groupKey);
    if (!a) { a = []; bySsid.set(ap.groupKey, a); }
    a.push(ap);
  }
  S.aps.forEach(ap => { ap.orbitCount = ap.clientCount; });
  // capacity: an AP without ≥ hexAbove real clients keeps single orbits (lanes) — probe orbiters never push it into
  // the large hex zone; a hex AP may fill its remaining hex slots (7 + 12 + 18).
  const cap = (ap) => ap.clientCount >= LAYOUT.hexAbove ? 37 : LAYOUT.hexAbove - 1;
  let changed = false;
  for (const c of S.clientOrder) {
    if (!c.free && !c.affinity) continue;
    if (c.randOut) { if (c.affinity) { changed = true; c.affinity = false; c.free = true; c.parent = null; c.band = null; c.probeVia = null; } continue; }   // §8.8a
    let best = null, via = null;
    if (S.ui.affinity && c.probes) for (const s of c.probes) {
      const list = bySsid.get(s); if (!list) continue;
      for (const ap of list) {   // least-loaded AP of the probed network, then strongest (ESS members share the load)
        if (ap.orbitCount >= cap(ap)) continue;
        if (!best || ap.orbitCount < best.orbitCount || (ap.orbitCount === best.orbitCount && ap.rssi > best.rssi)) { best = ap; via = s; }
      }
    }
    if (best) {
      // moved = a new orbit (orbitOfClient() starts its phase); a new slot alone only marks the layout dirty
      const moved = !c.affinity || c.parent !== best.id;
      if (moved) c.orbitPhase = NaN;
      if (moved || c.rank !== best.orbitCount) changed = true;
      c.affinity = true; c.free = false; c.parent = best.id; c.band = best.band; c.probeVia = via;
      c.rank = best.orbitCount; best.orbitCount++;   // after the real clients' ranks → stable lanes
    } else if (c.affinity) {
      changed = true; c.affinity = false; c.free = true; c.parent = null; c.band = null; c.probeVia = null;
    }
  }
  return changed;
}
function rebuildOrders() {
  const aps = []; S.aps.forEach(n => { if (n.target === 1) aps.push(n); });
  aps.sort((a, b) => b.rssi - a.rssi || cmpStr(a.bssid, b.bssid));
  S.apOrder = aps;
  const cls = []; S.clients.forEach(n => { if (n.target === 1) cls.push(n); });
  cls.sort((a, b) => cmpStr(a.mac, b.mac));
  S.clientOrder = cls;
}

