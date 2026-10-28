// ==== 29 ANALYZER ====
function freqFromChannel(ch, band) {
  if (ch == null) return null;
  if (band === "2.4") return ch === 14 ? 2484 : 2407 + 5 * ch;
  if (band === "5") return 5000 + 5 * ch;
  if (band === "6") return ch === 2 ? 5935 : 5950 + 5 * ch;
  return null;
}
function channelSpan(ap) {
  const w = ap.width ?? 20; const f = ap.freq ?? freqFromChannel(ap.channel, ap.band);
  if (f == null) return null;
  return [f - w / 2, f + w / 2, w, ap.width == null];
}
function overlapScore(a, b) {   // §8.2: rebuildInterference passes two APs of one band that both carry a channel
  const sa = channelSpan(a), sb = channelSpan(b); if (!sa || !sb) return null;
  const ov = Math.max(0, Math.min(sa[1], sb[1]) - Math.max(sa[0], sb[0])) / Math.min(sa[2], sb[2]);
  const fa = (sa[0] + sa[1]) / 2, fb = (sb[0] + sb[1]) / 2;
  const co = Math.abs(fa - fb) < 2.5;
  const I = ov * Math.min(rssiT(a.rssi), rssiT(b.rssi)) * (co ? 1.0 : 0.7);
  return { score: I, kind: co ? "co" : (ov > 0 ? "adjacent" : "none"), assumed: sa[3] || sb[3] };
}
const analyzer = { pairs: [], overlaps: [], channels: { "2.4": new Map(), "5": new Map(), "6": new Map() } };
function rebuildInterference() {   // §8.2 — pairwise channel overlap per band, only on ingest/filter
  analyzer.pairs.length = 0; analyzer.overlaps.length = 0;
  S.aps.forEach(n => { n.interfere.length = 0; });
  const perAp = new Map(), global = [];
  const note = (id, o) => { let arr = perAp.get(id); if (!arr) { arr = []; perAp.set(id, arr); } arr.push(o); };
  for (const band of ["2.4", "5", "6"]) {
    const list = S.apOrder.filter(a => a.band === band && a.channel != null && S.ui.filters[band] !== false);
    for (let i = 0; i < list.length; i++) for (let j = i + 1; j < list.length; j++) {
      const a = list[i], b = list[j], r = overlapScore(a, b); if (!r) continue;
      if (r.kind !== "none" && analyzer.overlaps.length < 400) analyzer.overlaps.push({ a: a.id, b: b.id, band, kind: r.kind, assumed: r.assumed });
      if (r.score >= 0.15) {
        note(a.id, { id: b.id, score: r.score, kind: r.kind }); note(b.id, { id: a.id, score: r.score, kind: r.kind });
        global.push({ a: a.id, b: b.id, band, score: r.score, kind: r.kind, assumed: r.assumed });
      }
    }
  }
  perAp.forEach((arr, id) => { arr.sort((x, y) => y.score - x.score); const n = S.aps.get(id); if (n) n.interfere = arr.slice(0, 6); });
  global.sort((x, y) => y.score - x.score);
  analyzer.pairs = global.slice(0, RENDER.nebulaMax);
}
function computeGroupEdges() {   // §8.6 — MST (Prim) over 2D layout targets; star topology above 24 members
  S.groups.forEach(g => {
    g.edges.length = 0; const m = g.members; if (m.length < 2) return;
    const pts = m.map(id => { const ap = S.aps.get(id); if (!ap) return [0, 0]; const a = ap.angleT != null ? ap.angleT : ap.a0, r = ap.radiusT; return [Math.cos(a) * r, Math.sin(a) * r]; });
    if (m.length > 24) { for (let i = 1; i < m.length; i++) g.edges.push([0, i]); return; }
    const n = m.length, inTree = new Array(n).fill(false), best = new Array(n).fill(Infinity), parent = new Array(n).fill(-1);
    best[0] = 0;
    for (let it = 0; it < n; it++) {
      let u = -1, bu = Infinity;
      for (let i = 0; i < n; i++) if (!inTree[i] && best[i] < bu) { bu = best[i]; u = i; }
      if (u < 0) break; inTree[u] = true;
      if (parent[u] >= 0) g.edges.push([parent[u], u]);
      for (let v = 0; v < n; v++) if (!inTree[v]) { const dx = pts[u][0] - pts[v][0], dy = pts[u][1] - pts[v][1], d = dx * dx + dy * dy; if (d < best[v]) { best[v] = d; parent[v] = u; } }
    }
  });
}
function hoverChannelText(band, ch) {   // §8.2 chanbar tooltip text; also STARCHORUS.hoverChannel
  const m = analyzer.channels[band]; if (!m) return null; const e = m.get(+ch); if (!e) return null;
  const parts = ["ch " + ch, band + " GHz", e.count + (e.count === 1 ? " AP" : " APs")];
  parts.push(e.assumed ? "width 20 MHz (assumed)" : "width " + e.widthMax + " MHz");
  const row = channelModel().bands[band].find(r => r.ch === +ch);   // found: channelModel() builds one row per analyzer.channels entry
  // max signal and its peak hold, DFS, the estimated beacon airtime (with its assumptions), probe activity, the D11 deviation
  if (row.maxDbm != null) parts.push("max " + row.maxDbm + " dBm" + (row.peakDbm != null && row.peakDbm > row.maxDbm ? " (peak " + row.peakDbm + ")" : ""));
  if (row.dfs) parts.push("DFS channel");
  parts.push("beacons ≥ " + row.beaconPct + " % of airtime (estimate: " + BEACON.ms + " ms, " + BEACON.bytes + " B at " + BEACON.mbps[band] + " Mbit/s)");
  if (row.probeActivity) parts.push("probe activity heard on channel: " + row.probeActivity + (row.probeActivity === 1 ? " station" : " stations"));
  if (row.deviation) parts.push("outside the usual range for this sky");
  const names = e.aps.map(id => { const ap = S.aps.get(id); return ap ? (ap.ssidKnown || ap.ssid || ap.bssid) : id; }).slice(0, 6);
  if (names.length) parts.push(names.join(", "));
  return parts.join(" · ");
}
function rebuildChannelStats() {
  for (const b of ["2.4", "5", "6"]) analyzer.channels[b].clear();
  for (const ap of S.apOrder) {
    if (ap.band === "unknown" || ap.channel == null) continue;
    const m = analyzer.channels[ap.band]; let e = m.get(ap.channel);
    if (!e) { e = { count: 0, aps: [], widthMax: 0, assumed: true }; m.set(ap.channel, e); }
    e.count++; e.aps.push(ap.id); e.widthMax = Math.max(e.widthMax, ap.width ?? 20); if (ap.width != null) e.assumed = false;
  }
  S.crowding = crowdingOf();
}
// D11 (theme-free, derived): crowding 1–5 = how busy the busiest channel is (Σ rssiT of the APs whose span overlaps it; 1 = least occupied),
// a per-source EWMA reference of the per-channel AP counts, and deviation marks (≥ 6 warm captures, 2 in a row outside
// max(2.5·σ_EWMA, Wilson half-width in APs, 2 APs)). An observer that moved (Jaccard distance of the fresh population > 0.5) resets the reference.
const SKY = { alpha: 0.3, warm: 6, hold: 6, sigmaK: 2.5, minAps: 2, jaccardReset: 0.5, minN: 30, minCell: 5, crowd: [1.5, 3, 5, 8], z: 1.96 };
function wilson(k, n) {   // 95 % Wilson score interval of k/n → { p, lo, hi, half }
  if (!(n > 0)) return { p: null, lo: null, hi: null, half: 0 };
  const z = SKY.z, p = k / n, d = 1 + z * z / n, c = (p + z * z / (2 * n)) / d, h = z * Math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d;
  return { p, lo: Math.max(0, c - h), hi: Math.min(1, c + h), half: h };
}
function crowdingOf() {
  let best = null;
  for (const band of ["2.4", "5", "6"]) analyzer.channels[band].forEach((e, ch) => {
    const o = chanOverlap(band, ch);
    if (o && (!best || o.sum > best.sum)) best = { band, channel: ch, sum: o.sum };
  });
  let level = 1; if (best) for (const t of SKY.crowd) if (best.sum >= t) level++;
  return { level, busiest: best ? { band: best.band, channel: best.channel, sum: r3(best.sum) } : null };
}
function skyUpdate() {   // once per capture, after rebuildChannelStats()
  const sk = S.sky, cur = new Set();
  for (const ap of S.apOrder) if (ap.freshTier == null || ap.freshTier === 0) cur.add(ap.id);   // the population heard just now (undated APs count: they look like T0)
  if (sk.t0 && (sk.t0.size || cur.size)) {
    let inter = 0; cur.forEach(id => { if (sk.t0.has(id)) inter++; });
    const uni = sk.t0.size + cur.size - inter;
    if (1 - inter / uni > SKY.jaccardReset) { sk.ref.clear(); sk.seq = 0; sk.resets++; }   // "observer moved"
  }
  sk.t0 = cur;
  const N = S.apOrder.length, counts = new Map(), warm = sk.seq >= SKY.warm;
  for (const b of ["2.4", "5", "6"]) analyzer.channels[b].forEach((e, ch) => counts.set(b + "/" + ch, e.count));
  sk.dev = [];
  const keys = new Set(counts.keys()); sk.ref.forEach((r, k) => keys.add(k));
  Array.from(keys).sort().forEach(key => {
    const c = counts.get(key) || 0; let r = sk.ref.get(key);
    if (!r) { r = { m: sk.seq === 0 ? c : 0, v: 0, streak: 0 }; sk.ref.set(key, r); }
    if (sk.seq > 0) {
      const diff = c - r.m, thr = Math.max(SKY.sigmaK * Math.sqrt(r.v), wilson(c, N).half * N, SKY.minAps), out = Math.abs(diff) > thr;
      r.streak = out ? r.streak + 1 : 0;
      if (warm && r.streak >= 2) { const [band, ch] = key.split("/"); sk.dev.push({ band, channel: +ch, count: c, ref: r3(r.m), dir: diff > 0 ? "up" : "down" }); }
      // hold the reference while a channel is outside its range (a single outlier must not widen σ and hide the next one); a change that
      // persists for SKY.hold captures becomes the new normal
      if (!(out && r.streak <= SKY.hold)) { r.m += SKY.alpha * diff; r.v = (1 - SKY.alpha) * (r.v + SKY.alpha * diff * diff); }
    }
    if (c === 0 && r.m < 0.05) sk.ref.delete(key);
  });
  sk.seq++;
}
function skyStatsObj() {   // aggregates only: no MAC, BSSID or SSID (D11); cells < 5 are suppressed, proportions need N ≥ 30
  const aps = S.apOrder, N = aps.length, ok = N >= SKY.minN;
  const cell = (k) => {
    if (k < SKY.minCell) return { count: null, shown: "<" + SKY.minCell, p: null, lo: null, hi: null };
    const w = ok ? wilson(k, N) : { p: null, lo: null, hi: null };
    return { count: k, shown: String(k), p: w.p == null ? null : r3(w.p), lo: w.lo == null ? null : r3(w.lo), hi: w.hi == null ? null : r3(w.hi) };
  };
  const band = {}, sec = {}; let hid = 0;
  for (const b of ["2.4", "5", "6", "unknown"]) band[b] = 0;
  for (const k of Object.keys(ENCODING.security)) sec[k] = 0;
  for (const ap of aps) { band[ap.band]++; sec[ap.sec]++; if (ap.hidden) hid++; }
  const out = { n: N, ok, minN: SKY.minN, band: {}, security: {}, hidden: cell(hid), crowding: S.crowding, deviations: S.sky.dev.map(d => Object.assign({}, d)),
    ref: { captures: S.sky.seq, warm: S.sky.seq >= SKY.warm, resets: S.sky.resets } };
  for (const k of Object.keys(band)) out.band[k] = cell(band[k]);
  for (const k of Object.keys(sec)) out.security[k] = cell(sec[k]);
  return out;
}
// ---- Baseline (persisted: <= 500 APs and <= 2000 stations as [rssi] without association), diff and ghosts (D19). Without channels[] hop data nothing is ever "gone"; a baseline AP counts as gone
// only when the frequency of its baseline channel is among the visited ones; own transmitters and probable phone hotspots (P3) are left out.
function baselineEligible(n) { return n.target === 1 && !eventSkip(n) && n.cloud == null; }   // §8.8a: never a cloud member
function loadBaseline() {
  const raw = safeStorage.get(BASELINE_KEY); if (!raw) return;
  try {
    const o = JSON.parse(raw); if (!isObj(o) || o.v !== 1 || !isObj(o.aps)) return;
    const m = new Map();
    for (const k of Object.keys(o.aps).slice(0, BASELINE_MAX)) { const e = o.aps[k]; if (Array.isArray(e) && isMac(k)) m.set(k, [String(e[0] == null ? "" : e[0]).slice(0, 32), numOrNull(e[1]), String(e[2] == null ? "unknown" : e[2]), String(e[3] == null ? "unknown" : e[3]), numOrNull(e[4])]); }
    const st = new Map();   // stations are optional: an older v1 baseline has none and loads unchanged
    if (isObj(o.st)) for (const k of Object.keys(o.st).slice(0, BASELINE_CL_MAX)) { const e = o.st[k]; if (Array.isArray(e) && isMac(k)) st.set(k, [numOrNull(e[0])]); }
    if (m.size || st.size) S.baseline = { t: numOrNull(o.t), aps: m, st };
  } catch (e) { /* a damaged baseline is simply none */ }
}
function saveBaseline() {
  const o = { v: 1, t: S.baseline.t, aps: Object.fromEntries(S.baseline.aps) }; if (S.baseline.st.size) o.st = Object.fromEntries(S.baseline.st);
  safeStorage.set(BASELINE_KEY, JSON.stringify(o));
}
function baselineSet() {
  const m = new Map();
  for (const n of S.apOrder) { if (m.size >= BASELINE_MAX) break; if (baselineEligible(n)) m.set(n.id, [n.ssidKnown || n.ssid || "", n.channel, n.band, n.sec, n.rssi]); }
  const cls = []; S.clients.forEach(n => { if (baselineEligible(n)) cls.push(n); });   // stations, capped apart (BASELINE_CL_MAX)
  cls.sort((a, b) => (b.rssi == null ? -128 : b.rssi) - (a.rssi == null ? -128 : a.rssi) || (a.id < b.id ? -1 : 1));
  const st = new Map(); for (const n of cls) { if (st.size >= BASELINE_CL_MAX) break; st.set(n.id, [n.rssi == null ? null : Math.round(n.rssi)]); }   // rssi only: no association
  S.baseline = (m.size || st.size) ? { t: S.generated, aps: m, st } : null;
  if (S.baseline) saveBaseline(); else safeStorage.remove(BASELINE_KEY);
  baselineRecompute(); return m.size;   // the AP count; baseline().sizeCl carries the stations
}
function baselineClear() { S.baseline = null; safeStorage.remove(BASELINE_KEY); baselineRecompute(); }
function baselineRecompute() {
  const b = { set: !!S.baseline, size: S.baseline ? S.baseline.aps.size : 0, new: 0, gone: 0, changed: 0, ghosts: 0,
    sizeCl: S.baseline ? S.baseline.st.size : 0, newCl: 0, goneCl: 0, ghostsCl: 0 };
  S.ghosts.clear(); S.aps.forEach(n => { n.baseState = null; }); S.clients.forEach(n => { n.baseState = null; });
  if (S.baseline && S.ui.baselineDiff) {
    const visited = S.hop ? new Set(S.hop.map(c => c.freq)) : null, cur = new Map();
    S.aps.forEach(n => { if (baselineEligible(n)) cur.set(n.id, n); });
    cur.forEach((n, id) => {
      const e = S.baseline.aps.get(id);
      if (!e) { b.new++; n.baseState = "new"; }
      else if (e[0] !== (n.ssidKnown || n.ssid || "") || e[1] !== n.channel || e[2] !== n.band || e[3] !== n.sec) { b.changed++; n.baseState = "changed"; }
      else n.baseState = "same";
    });
    S.baseline.aps.forEach((e, id) => {
      if (cur.has(id) || S.own.bssids.has(id) || !visited) return;
      const f = freqFromChannel(e[1], e[2]); if (f == null || !visited.has(f)) return;
      b.gone++;
      if (S.ghosts.size < GHOST_MAX) {
        S.ghosts.set(id, { ang: hash(id + "g") * Math.PI * 2, rssi: e[4] == null ? -75 : e[4], ssid: e[0], band: e[2] });
        b.ghosts++;
      }
    });
    // Stations have no channel of their own and probe on any, so "gone" needs no channel match. No "changed" state: D2's change
    // kinds (channel, security, SSID, band) are AP properties.
    // AP ghosts are placed first, so GHOST_MAX bounds them alone; a MAC now heard as an AP is not gone.
    const curCl = new Set();
    S.clients.forEach(n => {
      if (n.target === 1 && n.cloud != null && !eventSkip(n)) { curCl.add(n.id); return; }   // §8.8a: a cloud member counts as present but carries no baseState
      if (!baselineEligible(n)) return;
      curCl.add(n.id);
      if (S.baseline.st.has(n.id)) n.baseState = "same"; else { b.newCl++; n.baseState = "new"; }
    });
    S.baseline.st.forEach((e, id) => {
      if (curCl.has(id) || (S.aps.has(id) && S.aps.get(id).target === 1) || S.own.bssids.has(id) || !visited) return;
      b.goneCl++;
      if (b.ghostsCl < GHOST_CL_MAX && !S.ghosts.has(id)) {
        S.ghosts.set(id, { ang: hash(id + "g") * Math.PI * 2, rssi: e[0] == null ? -75 : e[0], ssid: "", band: null, cl: true });
        b.ghostsCl++;
      }
    });
  }
  S.base = b; S.dirty = true;
}
// ---- Watchlist (SSIDs only, <= 20, this browser) and the observations: derived, neutral hints; every rule skips own transmitters and mobile hotspots.
function loadWatch() {
  const raw = safeStorage.get(WATCH_KEY); if (!raw) return;
  try { const a = JSON.parse(raw); if (Array.isArray(a)) S.watch = a.filter(x => typeof x === "string" && x && x.length <= 32).slice(0, WATCH_MAX); } catch (e) { /* none */ }
}
function saveWatch() { if (S.watch.length) safeStorage.set(WATCH_KEY, JSON.stringify(S.watch)); else safeStorage.remove(WATCH_KEY); }
function watchSet(ssid, on) {
  const v = stripCtl(ssid, 32).trim(); if (!v) return S.watch.slice();
  const i = S.watch.indexOf(v);
  if (on !== false && i < 0 && S.watch.length < WATCH_MAX) S.watch.push(v); else if (on === false && i >= 0) S.watch.splice(i, 1);
  saveWatch(); obsCompute(); return S.watch.slice();
}
function near1(a, b) {   // exactly one edit apart (substitution, insertion or deletion), or the same text in another case
  if (a === b) return false;
  if (a.toLowerCase() === b.toLowerCase()) return true;
  const la = a.length, lb = b.length; if (Math.abs(la - lb) > 1) return false;
  let i = 0; while (i < la && i < lb && a[i] === b[i]) i++;
  return la === lb ? a.slice(i + 1) === b.slice(i + 1) : la > lb ? a.slice(i + 1) === b.slice(i) : b.slice(i + 1) === a.slice(i);
}
function obsCompute() {
  const tick = S.generated != null ? S.captureSeq : S.ingestSeq;
  const aps = S.apOrder.filter(n => !eventSkip(n)), raw = [];
  const add = (key, group, text) => raw.push({ key, group, text });
  if (S.ui.baselineDiff && S.baseline) {   // Baseline
    const b = S.base;
    if (b.new) add("b-new", "Baseline", b.new + " network(s) not in the baseline");
    if (b.changed) add("b-changed", "Baseline", b.changed + " network(s) changed against the baseline");
    if (b.gone) add("b-gone", "Baseline", b.gone + " baseline network(s) not heard on the channels visited");
  }
  const friends = aps.filter(n => identityOf(n.id) === "friend"), fs = new Set(friends.map(n => n.ssidKnown || n.ssid).filter(Boolean));   // Look-alike (against the OPERATOR-confirmed set only)
  if (fs.size) {
    const same = new Map(), sim = new Map();
    for (const n of aps) {
      if (identityOf(n.id) === "friend") continue; const s0 = n.ssidKnown || n.ssid; if (!s0) continue;
      if (fs.has(s0)) same.set(s0, (same.get(s0) || 0) + 1);
      else for (const f of fs) if (near1(s0, f)) { const k = s0 + "\u0001" + f; sim.set(k, (sim.get(k) || 0) + 1); break; }
    }
    same.forEach((c, s0) => add("same:" + s0, "Look-alike", "same SSID from a BSSID outside your confirmed set: " + s0 + " (" + c + ")"));
    sim.forEach((c, k) => { const [a, f] = k.split("\u0001"); add("sim:" + k, "Look-alike", "SSID close to a confirmed one: " + a + " ~ " + f + " (" + c + ")"); });
  }
  const multi = aps.filter(n => n.respondedSsids >= 2);   // Multi-SSID responders
  if (multi.length) add("multi", "Responders", multi.length + " BSSID(s) answered probes for several SSIDs (up to " + Math.max(...multi.map(n => n.respondedSsids)) + ")");
  if (fs.size && S.generated != null) {   // Probes for a confirmed SSID (P4): tiered 0 / <5 / >=5, only after 10 minutes of capture time, no times, no identities
    if (S.obsProbe.firstGen == null) S.obsProbe.firstGen = S.generated;
    if (S.generated - S.obsProbe.firstGen >= OBS_PROBE_S) {
      let k = 0; for (const c of S.clientOrder) if (!eventSkip(c) && c.probes && c.probes.some(p => fs.has(p))) k++;
      if (k > 0) add("probes", "Probes", "stations probed for a confirmed SSID: " + (k < 5 ? "<5" : "5 or more"));
    }
  }
  for (const w of S.watch) {   // Watchlist (SSIDs of access points only); "lost" needs hop data, as for the baseline
    const hit = aps.some(n => n.groupKey === w);
    if (hit) { S.obsWatchSeen = S.obsWatchSeen || new Set(); S.obsWatchSeen.add(w); add("w+" + w, "Watchlist", "watched SSID present: " + w); }
    else if (S.hop !== null && S.obsWatchSeen && S.obsWatchSeen.has(w)) add("w-" + w, "Watchlist", "watched SSID not heard now: " + w);
  }
  for (const a of S.alerts) { const n = S.aps.get(a.ap); if (n && !eventSkip(n)) add("alert:" + a.ap, "Alerts", "many deauth/disassoc frames heard for this AP: " + (n.ssidKnown || n.ssid || n.bssid) + " (" + a.n + ")"); }   // P6: local-live only
  if (S.cloudOrder.length) {   // §8.8a
    const k = S.cloudOrder.length, a = S.cloudOrder.reduce((x, c) => x + c.n, 0), one = k === 1 && !cloudMixed(S.cloudOrder[0]);
    add("s-clouds", "Stations", a + " randomised addresses in " + k + (k === 1 ? " cloud" : " clouds") + (one ? ": probably one nearby device changing its address" : ": possibly one or more nearby devices changing their address"));
  }
  const cnt = (f) => aps.filter(f).length;   // Configuration hints
  let c = cnt(n => n.sec === "open" || n.sec === "wep"); if (c) add("c-open", "Configuration", c + " open or WEP network(s)");
  c = cnt(n => n.band === "2.4" && n.channel != null && ![1, 6, 11].includes(n.channel)); if (c) add("c-chan", "Configuration", c + " 2.4 GHz network(s) on channels other than 1, 6 and 11");
  if (S.crowding.level >= 4) add("c-crowd", "Configuration", "the busiest channel is crowded (level " + S.crowding.level + " of 5)");
  c = cnt(n => n.hidden); if (c) add("c-hidden", "Configuration", c + " network(s) without a broadcast SSID");
  c = cnt(n => n.hid); if (c) add("c-hid", "Look-alike", c + " SSID(s) carried invisible characters (removed)");
  c = cnt(n => n.sec === "wpa3-transition"); if (c) add("c-trans", "Configuration", c + " network(s) in WPA3/WPA2 transition mode");
  c = cnt(n => n.sec === "tkip-weak"); if (c) add("c-tkip", "Configuration", c + " network(s) that still use TKIP");
  let mob = 0; S.aps.forEach(n => { if (n.target === 1 && n.mobile) mob++; }); if (mob) add("c-mobile", "Configuration", "mobile hotspots: " + mob);
  // dwell gate: a hint is shown once it has held for OBS_DWELL evaluations in a row; a key that vanished starts over
  const keys = new Set(raw.map(r => r.key));
  S.obsFirst.forEach((_, k) => { if (!keys.has(k)) S.obsFirst.delete(k); });
  const out = [];
  for (const r of raw) { if (!S.obsFirst.has(r.key)) S.obsFirst.set(r.key, tick); if (tick - S.obsFirst.get(r.key) >= OBS_DWELL - 1) out.push(r); }
  S.obs = out.slice(0, OBS_MAX);
}
// ---- Homing (browser side): one reading per poll ("coarse"), peak hold that decays after 12 polls without a new maximum. The target (an AP or a
// station) is chosen on the device or with STARCHORUS_HOMING_BSSID; the page never sends anything. A reading for a key not heard this capture, or one of our own transmitters, is refused.
const HOME_DECAY_POLLS = 12;
function homingIngest(h, seenAp, seenCl, gen) {
  const hp = S.homePeak;
  if (!h || !isMac(h.bssid) || (!seenAp.has(h.bssid) && !seenCl.has(h.bssid)) || S.own.bssids.has(h.bssid)) { S.homing = null; hp.bssid = null; return; }
  if (hp.bssid !== h.bssid) { hp.bssid = h.bssid; hp.dbm = null; hp.polls = 0; }
  if (gen !== hp.gen || gen == null) {
    hp.gen = gen; hp.polls++;
    if (hp.dbm == null || h.dbm >= hp.dbm || hp.polls > HOME_DECAY_POLLS) { hp.dbm = Math.max(h.dbm, h.peak != null ? h.peak : h.dbm); hp.polls = 0; }
  }
  S.homing = { bssid: h.bssid, dbm: h.dbm, peak: hp.dbm, t: h.t };
  if (S.homeTone) homeBeep(h.dbm);
}
let homeCtx = null;
function homeBeep(dbm) {   // opt-in tone (user gesture required): pitch follows the level; never speaks or encodes any name
  try {
    if (!homeCtx) return;
    const o = homeCtx.createOscillator(), g = homeCtx.createGain();
    o.frequency.value = 300 + 900 * rssiT(dbm); g.gain.value = 0.05;
    o.connect(g); g.connect(homeCtx.destination);
    o.start(); o.stop(homeCtx.currentTime + 0.08);
  } catch (e) { /* no audio */ }
}
// ---- channel/air/history/replay models (theme-free): channel view, air quality, long RSSI history, recorder and replay ----
// Channel model. DFS is a static table (5 GHz UNII-2/2e); the beacon airtime is an ESTIMATED lower bound from what was heard, never a measurement:
// one beacon per BSSID every 102.4 ms, BEACON.bytes long, sent at 1 Mbit/s (2.4 GHz, long preamble) or 6 Mbit/s (5/6 GHz) — the assumptions are shown next to the number.
const DFS_5G = new Set([52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 144]);
const BEACON = { ms: 102.4, bytes: 200, mbps: { "2.4": 1, "5": 6, "6": 6 }, preUs: { "2.4": 192, "5": 20, "6": 20 } };
const CHAN_PEAK_POLLS = 12, BAND_HZ = { "2.4": [2402, 2482], "5": [5170, 5835], "6": [5945, 7125] };
const AIR_WORDS = ["quiet", "light", "moderate", "busy", "very busy"];   // neutral words for crowding 1–5 (P10)
const AIR_SETS = { "2.4": [1, 6, 11], "5": [36, 40, 44, 48, 149, 153, 157, 161, 165], "6": [] };   // channels without DFS / overlap, offered for "least occupied"
const beaconPct = (band, n) => Math.round(n * (BEACON.preUs[band] + BEACON.bytes * 8 / BEACON.mbps[band]) / (BEACON.ms * 10) * 10) / 10;
function chanMaxDbm(e) { let mx = null; for (const id of e.aps) { const n = S.aps.get(id); if (n && n.rssi != null && (mx == null || n.rssi > mx)) mx = n.rssi; } return mx; }
function chanPeakUpdate() {   // once per capture: the strongest AP per channel, held until 12 captures pass without a new maximum
  const seen = new Set();
  for (const band of ["2.4", "5", "6"]) analyzer.channels[band].forEach((e, ch) => {
    const mx = chanMaxDbm(e); if (mx == null) return;
    const k = band + "/" + ch; seen.add(k);
    const pk = S.chanPeak.get(k);
    if (!pk) S.chanPeak.set(k, { dbm: mx, polls: 0 });
    else if (mx >= pk.dbm) { pk.dbm = mx; pk.polls = 0; }
    else if (++pk.polls > CHAN_PEAK_POLLS) { pk.dbm = mx; pk.polls = 0; }
  });
  S.chanPeak.forEach((pk, k) => { if (!seen.has(k) && ++pk.polls > CHAN_PEAK_POLLS) S.chanPeak.delete(k); });
}
function chanOverlap(band, ch) {   // Σ rssiT of the APs whose span overlaps the channel's own 20 MHz (crowding and load), and the co/adjacent counts
  const f = freqFromChannel(ch, band); if (f == null) return null;
  const lo = f - 10, hi = f + 10; let sum = 0, co = 0, adj = 0;
  for (const ap of S.apOrder) {
    if (ap.band !== band || ap.channel == null) continue;
    const sp = channelSpan(ap); if (!sp || Math.min(sp[1], hi) - Math.max(sp[0], lo) <= 0) continue;
    sum += rssiT(ap.rssi); if (ap.channel === ch) co++; else adj++;
  }
  return { sum, co, adj };
}
function channelLoad(band, ch) { const o = chanOverlap(band, ch); return o ? { load: Math.round(o.sum * 100) / 100, co: o.co, adj: o.adj } : { load: 0, co: 0, adj: 0 }; }
function channelModel() {
  const st = new Map();   // probe activity: stations heard via APs on the channel (a count, no identity)
  S.clients.forEach(c => { if (c.target !== 1 || !c.parent || c.affinity) return; const ap = S.aps.get(c.parent); if (ap && ap.band !== "unknown" && ap.channel != null) { const k = ap.band + "/" + ap.channel; st.set(k, (st.get(k) || 0) + 1); } });
  const dev = new Set(S.sky.dev.map(d => d.band + "/" + d.channel));
  const out = { crowding: S.crowding.level, assumptions: { beaconMs: BEACON.ms, beaconBytes: BEACON.bytes, mbps: Object.assign({}, BEACON.mbps), width: "20 MHz assumed where the collector gives none" }, bands: {} };
  for (const band of ["2.4", "5", "6"]) {
    const rows = [];
    analyzer.channels[band].forEach((e, ch) => {
      const mx = chanMaxDbm(e), pk = S.chanPeak.get(band + "/" + ch), ld = channelLoad(band, ch);
      rows.push({ ch, freq: freqFromChannel(ch, band), count: e.count, maxDbm: mx, peakDbm: pk ? pk.dbm : mx, widthMax: e.assumed ? 20 : e.widthMax, assumed: e.assumed, dfs: band === "5" && DFS_5G.has(ch),
        beaconPct: beaconPct(band, e.count), probeActivity: st.get(band + "/" + ch) || 0, deviation: dev.has(band + "/" + ch), co: ld.co, adjacent: ld.adj, load: ld.load });
    });
    rows.sort((a, b) => a.ch - b.ch); out.bands[band] = rows;
  }
  return out;
}
function airQuality() {   // per band the busiest channels, co-/adjacent-channel counts and the least occupied of the usual set — neutral words, an observation, not advice
  const cm = channelModel(), out = { level: S.crowding.level, word: AIR_WORDS[S.crowding.level - 1], busiest: S.crowding.busiest, assumptions: cm.assumptions, bands: {} };
  for (const band of ["2.4", "5", "6"]) {
    const rows = cm.bands[band]; if (!rows.length) { out.bands[band] = null; continue; }
    const top = rows.slice().sort((a, b) => b.load - a.load || a.ch - b.ch).slice(0, 3).map(r => ({ ch: r.ch, load: r.load, co: r.co, adjacent: r.adjacent, count: r.count, maxDbm: r.maxDbm, dfs: r.dfs, beaconPct: r.beaconPct }));
    const set = AIR_SETS[band].map(ch => Object.assign({ ch }, channelLoad(band, ch))), quiet = set.length ? set.slice().sort((a, b) => a.load - b.load || a.ch - b.ch)[0] : null;
    const sum = rows.reduce((a, r) => a + r.count, 0), beacon = Math.round(rows.reduce((a, r) => a + r.beaconPct, 0) * 10) / 10;
    out.bands[band] = { aps: sum, channels: rows.length, top, quietest: quiet ? { ch: quiet.ch, load: quiet.load, co: quiet.co, adjacent: quiet.adj } : null, beaconPctSum: beacon };
  }
  return out;
}
// Long RSSI history: one Int8 sample per CAPTURE (a distinct `generated`), 720 samples, gaps as -128; time scales convert seconds to samples with the
// observed capture spacing (§38), else the collector's announced interval, else the 5 s poll.
const LONG_LEN = 720, LONG_KEEP = 120, TIME_SCALES = { "1m": 60, "10m": 600, "1h": 3600 };
function longPush(id, dbm, seq) {
  let h = S.long.get(id); if (!h) { h = { buf: new Int8Array(LONG_LEN).fill(-128), head: 0, n: 0, lastSeq: seq }; S.long.set(id, h); }
  h.buf[h.head] = dbm == null ? -128 : clamp(Math.round(dbm), -127, 0); h.head = (h.head + 1) % LONG_LEN; h.n = Math.min(LONG_LEN, h.n + 1); h.lastSeq = seq; h.pushed = seq;
}
function longSweep(seq) {   // a series of an AP that was not in this capture gets a gap sample, and one that has been gone for LONG_KEEP captures is dropped
  S.long.forEach((h, id) => {
    if (h.pushed === seq) return;
    if (seq - h.lastSeq > LONG_KEEP) { S.long.delete(id); return; }
    h.buf[h.head] = -128; h.head = (h.head + 1) % LONG_LEN; h.n = Math.min(LONG_LEN, h.n + 1);
  });
}
function longSeries(id, want) {   // → the newest `want` samples, oldest first, null for a gap
  const h = S.long.get(id); if (!h) return [];
  const n = Math.min(h.n, want, LONG_LEN), out = [];
  for (let i = n; i >= 1; i--) { const v = h.buf[(h.head - i + LONG_LEN * 2) % LONG_LEN]; out.push(v === -128 ? null : v); }
  return out;
}
function timeModel(scale) {
  const sc = TIME_SCALES[scale] ? scale : S.timeScale, sp = captureSpacing(), iv = sp ?? (S.pollIntervalS > 0 ? S.pollIntervalS : POLL_MS / 1000);
  const from = sp != null ? "observed" : S.pollIntervalS > 0 ? "announced" : "assumed";
  const want = Math.max(2, Math.ceil(TIME_SCALES[sc] / iv)), win = Math.min(want, LONG_LEN);
  let ids = [];
  const sel = S.locked && S.aps.get(S.locked);
  if (sel) { const key = sel.groupKey; ids = key ? S.apOrder.filter(a => a.groupKey === key).map(a => a.id) : [sel.id]; }   // the ESS of the selected AP: one curve per BSSID
  else if (S.pinned.size) ids = Array.from(S.pinned).filter(id => S.aps.has(id));
  if (!ids.length) ids = S.apOrder.filter(a => !eventSkip(a)).slice().sort((a, b) => rssiOf(b) - rssiOf(a)).slice(0, 3).map(a => a.id);
  const curves = ids.slice(0, 6).map(id => {
    const n = S.aps.get(id), sm = longSeries(id, win), vs = sm.filter(v => v != null);
    return { id, label: n ? aliasOf(id) || n.ssidKnown || n.ssid || n.bssid : id, band: n ? n.band : "unknown", samples: sm, n: vs.length, min: vs.length ? Math.min(...vs) : null, max: vs.length ? Math.max(...vs) : null, mean: vs.length ? Math.round(10 * vs.reduce((a, b) => a + b, 0) / vs.length) / 10 : null, last: vs.length ? vs[vs.length - 1] : null };
  });
  let above = 0; if (S.threshold != null) S.apOrder.forEach(a => { if (!eventSkip(a) && a.rssi != null && a.rssi >= S.threshold) above++; });
  return { scale: sc, intervalS: iv, spacingFrom: from, window: win, limited: want > LONG_LEN, threshold: S.threshold, above: S.threshold == null ? null : above, curves };
}
// Recorder: the normalised captures as held in memory (complete), at most REC_MAX or REC_BYTES (an estimate) — a memory rule, not a privacy rule; never persisted.
const REC_MAX = 120, REC_BYTES = 8 * 1024 * 1024;
const recEmpty = () => ({ key: null, docs: [], bytes: 0, seqNo: 0, lastGen: null });
const docBytes = (doc) => 1500 + doc.aps.length * 420 + doc.aps.reduce((a, x) => a + x.clients.length * 140, 0) + doc.unassociated.length * 160 + (doc.bluetooth ? doc.bluetooth.length * 150 : 0);
function recAppend(doc, key) {
  if (!S.rec || S.rec.key !== key) { S.rec = recEmpty(); S.rec.key = key; }
  const r = S.rec, gen = doc.generated; if (gen == null || gen === r.lastGen) return false;   // → true when a capture was recorded
  r.lastGen = gen; const bytes = docBytes(doc);
  r.docs.push({ n: ++r.seqNo, gen, bytes, doc: JSON.parse(JSON.stringify(doc)) }); r.bytes += bytes;
  while (r.docs.length > REC_MAX || r.bytes > REC_BYTES) r.bytes -= r.docs.shift().bytes, S.replay && S.replay.i--;
  if (S.replay) S.replay.i = clamp(S.replay.i, 0, r.docs.length - 1);
  return true;
}
function recObj() { const r = S.rec || recEmpty(); return { count: r.docs.length, bytes: r.bytes, max: REC_MAX, maxBytes: REC_BYTES, snapshots: r.docs.map(d => ({ n: d.n, generated: d.gen, aps: d.doc.aps.length, clients: d.doc.aps.reduce((a, x) => a + x.clients.length, 0) + d.doc.unassociated.length, bytes: d.bytes })) }; }
function resumeMarks(map, node) {
  const m = map && map.get(node.id);
  if (m) {
    node.capSeq = m.capSeq; node.newSeq = m.newSeq;
    if ("changedSeq" in m) { node.changedSeq = m.changedSeq; node.cueSeq = m.cueSeq; }
  }
}
function stashMarks() {   // the event marks of the live nodes (a replay may delete and re-create nodes; the marks make "Back to live" continue the event record instead of announcing every AP as new)
  const aps = new Map(), cl = new Map();
  S.aps.forEach((n, id) => aps.set(id, { capSeq: n.capSeq, newSeq: n.newSeq, changedSeq: n.changedSeq, cueSeq: n.cueSeq }));
  S.clients.forEach((n, id) => cl.set(id, { capSeq: n.capSeq, newSeq: n.newSeq }));
  return { aps, cl };
}
function replayObj() { const r = S.replay, n = S.rec ? S.rec.docs.length : 0; return { active: !!r, index: r ? r.i : null, count: n, generated: r && S.rec.docs[r.i] ? S.rec.docs[r.i].gen : null, buffered: r ? r.buffered : 0, playing: !!(r && r.play) }; }
function replayTo(i, opts) {
  const r = S.rec; if (!r || !r.docs.length) return null;
  i = clamp(Math.round(+i || 0), 0, r.docs.length - 1);
  if (!S.replay) S.replay = { i, pending: null, buffered: 0, play: false, acc: 0, marks: stashMarks() };
  S.replay.i = i;
  const rec = r.docs[i];
  ingest(rec.doc, { replay: true });
  setSourcePanel();
  if (opts && opts.quiet) recLabel(); else applyDrawer();   // quiet: the slider that is being dragged keeps its element (a re-render would end the drag)
  S.dirty = true;
  return replayObj();
}
function replayExit() {   // "Back to live": the newest capture (the last one buffered, else the newest recorded) is ingested as a regular capture that continues the event record
  const rp = S.replay; if (!rp) return false;
  const rec = S.rec && S.rec.docs.length ? S.rec.docs[S.rec.docs.length - 1].doc : null, doc = rp.pending || rec;
  S.replay = null;
  if (doc) {
    const st = S.stalePolls, sm = S.staleMs;
    loadData(doc, S.sourceLabel, { mode: S.liveFeed ? "live" : "recorded", resume: rp.marks });
    if (!rp.pending) { S.stalePolls = st; S.staleMs = sm; }
  }
  setSourcePanel(); applyDrawer(); S.dirty = true; return true;
}
function replayTick(dt) {
  const rp = S.replay;
  if (!rp || !rp.play || dt <= 0) return;
  rp.acc += dt;
  if (rp.acc < 1) return;
  rp.acc = 0;
  if (rp.i >= S.rec.docs.length - 1) { rp.play = false; renderRec(); return; }
  replayTo(rp.i + 1);
  renderRec();
}
function phyEstimate(ap) {
  if (ap.phy) return ap.phy;
  const r = ap.rate; if (r == null) return "—";
  switch (ap.band) {
    case "2.4": return r <= 11 ? "≈ b" : r <= 54 ? "≈ g" : r <= 600 ? "≈ n" : r <= 1147 ? "≈ ax" : "≈ be";
    case "5": return r <= 54 ? "≈ a" : r <= 600 ? "≈ n" : r < 866 ? "≈ ac" : r <= 3467 ? "≈ ac/ax" : "≈ ax/be";
    case "6": return r <= 2402 ? "≈ ax" : "≈ be";
    default: return r <= 54 ? "≈ legacy" : "≈ n+";
  }
}
function pmfDerived(ap) {   // 802.11w is mandatory in pure WPA3, OWE and on 6 GHz (bandF: never from the channel number); no other class is judged
  return ap.sec === "wpa3" || ap.sec === "owe" || ap.bandF === "6" ? "yes (derived)" : "unknown";
}
function securityCounts() {
  const c = Object.fromEntries(Object.keys(ENCODING.security).map(k => [k, 0]));
  for (const ap of S.apOrder) c[ap.sec]++;
  S.security = c; return c;
}
function rebuildGroups() {
  S.groups.clear();
  for (const ap of S.apOrder) {
    if (!ap.groupKey) continue;
    let g = S.groups.get(ap.groupKey);
    if (!g) { g = { key: ap.groupKey, members: [], hub: ap.id, edges: [], meanA0: 0, cx: 0, cz: 0, bands: new Set() }; S.groups.set(ap.groupKey, g); }
    g.members.push(ap.id); g.bands.add(ap.band);
  }
  S.groups.forEach(g => {
    let sx = 0, sy = 0;
    for (const id of g.members) { const a0 = hash(id) * Math.PI * 2; sx += Math.sin(a0); sy += Math.cos(a0); }
    g.meanA0 = Math.atan2(sx, sy);
  });
}
// §8.8 G1 — logical DEVICE grouping (likely one physical AP behind several BSSIDs/radios).
// Passive, deterministic (BSSID/SSID/band/vendor only; seed-free), union-find, cluster id = smallest BSSID.
function apBytes(bssid) {
  const parts = String(bssid).split(":");
  if (parts.length !== 6) return null;
  const b = new Array(6);
  for (let i = 0; i < 6; i++) { if (!/^[0-9a-f]{1,2}$/.test(parts[i])) return null; b[i] = parseInt(parts[i], 16) & 255; }
  return b;
}
function bssidLocal(b) { return (b[0] & 0x02) !== 0; }   // U/L bit set → locally administered / randomised
function ssidBase(s) {   // suffix-strip normalisation, tiebreaker only
  let x = String(s == null ? "" : s).toLowerCase();
  x = x.replace(/[-_ ]?(2\.?4|5|6)\s?g(hz)?$/i, "");
  x = x.replace(/[-_ ](2\.?4|5|6)$/, "");
  return x.trim();
}
function apSsid(ap) { return ap.ssidKnown != null ? ap.ssidKnown : ap.ssid; }
function hex2(v) { return (v < 16 ? "0" : "") + v.toString(16); }
// The one pair rule (pure). A = partner, B = member; returns { kind: 0 vBSSID | 1 multi-radio, text } or null.
function linkReason(A, B) {
  const ba = A.b, bb = B.b;
  for (let k = 0; k < 5; k++) if (ba[k] !== bb[k]) return null;      // same OUI (0..2) + bytes 3..4 for both mechanisms
  const d = bb[5] - ba[5], ad = Math.abs(d);
  // Consecutive BSSIDs (same OUI, bytes 0..4 identical, byte 5 within a TIGHT window) are strong
  // evidence of one physical box on their own — a box hands out adjacent MACs to its radios/vSSIDs.
  // This links even across bands and without an SSID/vendor match (e.g. :6e on 5 GHz, :6f on 2.4).
  if (ad !== 0 && ad <= DEVICE.seqTight) return { kind: 0, text: "consecutive BSSID (" + (d >= 0 ? "+" : "−") + ad + " vs :" + hex2(ba[5]) + ")" };
  if (A.ap.band === B.ap.band) {                                       // multi-BSSID (one radio)
    const K = DEVICE.mbssidBits;
    if ((ba[5] >> K) === (bb[5] >> K) || ad <= DEVICE.seqWindow) return { kind: 0, text: "vBSSID (" + (d >= 0 ? "+" : "−") + ad + " vs :" + hex2(ba[5]) + ")" };
    return null;
  }
  if (A.ap.band === "unknown" || B.ap.band === "unknown" || ad > DEVICE.radioWindow) return null;   // multi-radio (one box)
  const bands = [A.ap.band, B.ap.band].sort().join("+") + " GHz same box";
  const sa = ssidBase(apSsid(A.ap)), sb = ssidBase(apSsid(B.ap));
  if (sa !== "" && sa === sb) return { kind: 1, text: bands + " (SSID base)" };
  if (A.ap.vendor && A.ap.vendor === B.ap.vendor) return { kind: 1, text: bands + " (vendor)" };
  return null;
}
function rebuildDevices() {
  S.devices.clear(); S.deviceOf.clear();
  const list = [];
  for (const ap of S.apOrder) {
    if (ap.target !== 1) continue;                      // fading-out APs never define a device
    const b = apBytes(ap.bssid); if (!b) continue;      // synthetic "ap"+i / malformed → no OUI logic
    if (bssidLocal(b)) continue;                        // exclude randomised / locally-administered BSSIDs
    list.push({ ap, b });
  }
  list.sort((x, y) => cmpStr(x.ap.bssid, y.ap.bssid));
  const n = list.length, parent = new Array(n);
  for (let i = 0; i < n; i++) parent[i] = i;
  const find = (i) => { while (parent[i] !== i) { parent[i] = parent[parent[i]]; i = parent[i]; } return i; };
  const union = (i, j) => { const a = find(i), c = find(j); if (a !== c) parent[Math.max(a, c)] = Math.min(a, c); };
  for (let i = 0; i < n; i++) for (let j = i + 1; j < n; j++) if (linkReason(list[i], list[j])) union(i, j);
  const groups = new Map();
  for (let i = 0; i < n; i++) { const r = find(i); let g = groups.get(r); if (!g) { g = []; groups.set(r, g); } g.push(list[i]); }
  groups.forEach(ents => {
    if (ents.length < 2) return;                       // ents are already in ascending BSSID order
    const members = ents.map(e => e.ap);
    const id = members[0].bssid;
    let lead = members[0];
    for (const m of members) if (rssiOf(m) > rssiOf(lead)) lead = m;
    const bands = Array.from(new Set(members.map(m => m.band))).sort();
    let vendor = null; for (const m of members) if (m.vendor) { vendor = m.vendor; break; }
    // one reason PER MEMBER (aligned with memberIds): the rule that actually links it to a partner in
    // this cluster, partners scanned in ascending BSSID order, same-radio vBSSID preferred over multi-radio.
    const reason = ents.map((e, k) => {
      let best = null;
      for (let p = 0; p < ents.length; p++) {
        if (p === k) continue;
        const r = linkReason(ents[p], e); if (!r) continue;
        if (!best || r.kind < best.kind) best = r;
        if (best.kind === 0) break;
      }
      return best ? best.text : "linked";
    });
    const dev = { id, memberIds: members.map(m => m.bssid), leadId: lead.bssid, bands, vendor, reason };
    S.devices.set(id, dev);
    for (const m of members) S.deviceOf.set(m.bssid, id);
  });
}
// §8.8 G2 — ESS collapse: same SSID across ≥2 DISTINCT devices (G1 clusters) fold into one node.
// Keyed by the same trimmed SSID as the §8.6 constellations (ap.groupKey) so both layers agree.
function rebuildEss() {
  S.essClusters.clear(); S.essOf.clear(); S.essBySsid.clear();
  const bySsid = new Map();
  for (const ap of S.apOrder) {
    if (ap.target !== 1 || !ap.groupKey) continue;     // hidden / empty SSIDs never merge
    let e = bySsid.get(ap.groupKey); if (!e) { e = []; bySsid.set(ap.groupKey, e); } e.push(ap);
  }
  bySsid.forEach((aps, ssid) => {
    const devSet = new Set();
    for (const ap of aps) { const cid = S.deviceOf.get(ap.id); devSet.add(cid != null ? cid : ap.id); }
    if (devSet.size < 2) return;                       // needs ≥2 physically distinct devices
    const memberIds = aps.map(a => a.id).sort();
    const id = memberIds[0];
    S.essClusters.set(id, { ssid, id, deviceIds: Array.from(devSet).sort(), memberIds, leadId: memberIds[0], apCount: memberIds.length });
    S.essBySsid.set(ssid, id);
    for (const m of memberIds) S.essOf.set(m, id);
  });
  refreshEssLeads();
  S.essExpand.forEach((_, id) => { if (!S.essClusters.has(id)) S.essExpand.delete(id); });
}
// Lead = strongest member whose band is not filtered (a filtered lead must not take its whole ESS with it).
function refreshEssLeads() {
  S.essClusters.forEach(c => {
    let lead = null, any = null;
    for (const mid of c.memberIds) {
      const a = S.aps.get(mid); if (!a) continue;
      const r = rssiOf(a);
      if (!any || r > rssiOf(any)) any = a;
      if (S.ui.filters[a.band] !== false && (!lead || r > rssiOf(lead))) lead = a;
    }
    c.leadId = (lead || any || { id: c.memberIds[0] }).id;
  });
}
function essOfFolded(apId) {   // the folded ESS cluster this AP belongs to (merge on, ≥2 devices, not expanded) or null
  if (!S.ui.essMerge) return null;
  const cid = S.essOf.get(apId); if (cid == null) return null;
  const c = S.essClusters.get(cid); if (!c || c.deviceIds.length < 2 || isEssExpanded(cid)) return null;
  return c;
}
function isEssExpanded(id) { const u = S.essExpand.get(id); return u != null && u > S.clock; }
function isEssFolded(apId) { const c = essOfFolded(apId); return !!c && c.leadId !== apId; }
function isEssFoldedSet(ssidKey) { const id = S.essBySsid.get(ssidKey); return id != null && !!essOfFolded(id); }
function expandEss(id) {
  if (!S.essClusters.has(id)) return false;
  S.essExpand.set(id, S.clock + DEVICE.essExpandMs / 1000); S.dirty = true; updateStats();
  return true;
}
// Fold/unfold reuses the §4.6 bubble blend: essBlend eases with S.anim.blendK (from motion.fadeInMs, per theme), members slide to
// the lead in world space (orbiting clients follow), fade ·(1 − blend), shrink ·(1 − 0.4·blend). Reduced motion snaps.
function stepEss(dt) {
  let moving = false, changed = false;
  S.aps.forEach(n => {
    const folded = isEssFolded(n.id), tb = folded ? 1 : 0;
    if (folded !== !!n.essFolded) { n.essFolded = folded; changed = true; }
    const nb = reduceMotion ? tb : ease(n.essBlend || 0, tb, S.anim.blendK, dt);
    if (Math.abs(nb - (n.essBlend || 0)) > 1e-4) moving = true;
    n.essBlend = nb;
    if (nb <= 1e-4) return;
    const c = S.essClusters.get(S.essOf.get(n.id)); const L = c ? S.aps.get(c.leadId) : null;
    if (!L || L === n) return;
    const s = smoothstep(0, 1, nb);
    n.wx = lerp(n.wx, L.wx, s); n.wz = lerp(n.wz, L.wz, s);
  });
  if (changed) updateStats();
  return moving;
}
function essDrawFactor(n) { const b = n.essBlend || 0; if (b > 0) { n.alphaDraw *= 1 - b; n.px *= 1 - 0.4 * b; } }
// §8.8a random clouds (model; theme-free, deterministic, order-free): randomised free stations with a capture time and a signal, banded by
// signal and kept where their times form bursts in a rhythm; a loose address inside a burst joins. Probe SSIDs are listed, never a
// key. A band that shares addresses with a live cloud keeps its node and holds down to keepAddr. JQLIB `clouds` is the same rule, stateless.
function newCloud(id) {
  return { id, kind: "cloud", mac: id /* relaxation hash key only */, members: [], n: 0, core: 0, joined: 0, centre: 0, rssi: -90, rssiMin: null, rssiMax: null,
    first: null, last: null, bursts: 0, cadenceS: null, rhythm: 0, probes: [], anchor: "", kept: false, ageS: null, freshTier: null, freshA: 1, freshAT: 1,
    homeAngle: 0, homeR: 0.5, jitterR: 0, homeX: 0, homeZ: 0, lx: 0, lz: 0, wx: 0, wz: 0, placed: false, jitY: hash(id + "h"), jitZ: hash(id + "z"),
    p3: [0, 0, 0], p: [0, 0, 0], sx: 0, sy: 0, zc: 1, px: 0, fog: 1, scale: 1, basePx: CLOUD.pxBase, basePxMax: 7, bubble: null,
    target: 1, alpha: 0, alphaDraw: 0, born: S.clock, expandedUntil: null, sparkDirty: true,
    hist: { buf: new Int8Array(HISTORY_LEN), ts: new Float64Array(HISTORY_LEN), head: 0, n: 0, lastGen: null, lastSeq: 0, cl: false } };   // its own series, not in S.hist
}
function cloudBands(E) {   // E sorted (rssi desc, MAC asc) → { bands: [{ c, W }], rest }: flat-window mean shift
  let L = E; const bands = [];
  while (L.length >= CLOUD.minAddr) {   // a band below minAddr cannot hold a cloud
    const cnt = new Map(); let c = null, top = 0;
    for (const e of L) cnt.set(e.r, (cnt.get(e.r) || 0) + 1);
    cnt.forEach((n, r) => { if (n > top || (n === top && r > c)) { top = n; c = r; } });   // seed: the commonest value, the stronger on a tie
    for (let k = 0; k < CLOUD.shiftMax; k++) {
      let s = 0, n = 0;
      for (const e of L) if (e.r >= c - CLOUD.bandDb && e.r <= c + CLOUD.bandDb) { s += e.r; n++; }
      const m = s / n;
      if (Math.abs(m - c) < CLOUD.shiftEps) break;
      c = m;
    }
    const W = [], R = [];
    for (const e of L) (e.r >= c - CLOUD.bandDb && e.r <= c + CLOUD.bandDb ? W : R).push(e);
    bands.push({ c, W }); L = R;
  }
  return { bands, rest: L };
}
function cloudBursts(ts) {   // ascending times → [[start, end], …]
  const B = [];
  for (let i = 0; i < ts.length; i++) { if (i === 0 || ts[i] - ts[i - 1] > CLOUD.burstS) B.push([ts[i], ts[i]]); else B[B.length - 1][1] = ts[i]; }
  return B;
}
// A rhythm is a period the burst starts of one band show far more often than unrelated bursts would. Two judges, both plain arithmetic (no exp() or pow()):
// 1) pairs of bursts about one period apart against the pairs in the bands beside that window (what this band shows by chance, hard-core spacing and all),
//    floored by the Poisson count; 2) for a band too dense for that, a chain of bursts one period apart (or two, three) that keeps its phase, against the
//    longest chain bursts of that density make by chance. A device's gap is its period or a little more, never a fixed grid, so the first judge counts pairs.
const cloudTol = (c) => Math.max(CLOUD.tolMinS, CLOUD.tolFrac * c);
function cloudExpm(x) { let y = 1 - x / 1024; if (y < 0) return 0; for (let i = 0; i < 10; i++) y *= y; return y; }   // e^-x, ten squarings
function cloudChance(n, T, c) {   // pair hits that n unrelated bursts over T s give at c ± tol, the second within lagMax bursts of the first (Poisson arrivals)
  const lam = n / T; let f = 0, p = lam, q = 1;
  for (let l = 1; l <= CLOUD.lagMax; l++) { f += p * q; p *= lam; q *= c / l; }
  return n * f * cloudExpm(lam * c) * 2 * cloudTol(c);
}
function cloudHits(S, c) {   // burst pairs about c s apart → [i, j, distance], the bursts that take part, and the pairs in the two bands beside the window (mean)
  const tol = cloudTol(c), p = [], sup = new Set(); let a = 0, b = 0;
  for (let i = 0; i < S.length; i++) for (let j = i + 1; j < S.length && j <= i + CLOUD.lagMax; j++) {
    const x = S[j] - S[i], d = x - c;
    if (Math.abs(d) <= tol) { p.push([i, j, x]); sup.add(i); sup.add(j); } else if (d >= -3 * tol && d < -tol) a++; else if (d > tol && d <= 3 * tol) b++;
  }
  return { p, sup: Array.from(sup).sort((x, y) => x - y), side: (a + b) / 2 };
}
function cloudCands(S) {   // the commonest gaps (whole seconds, cadMin to cadMax) to the next lagMax bursts, one per tolerance: a neighbour of a taken gap is left out
  const cnt = new Map();
  for (let l = 1; l <= CLOUD.lagMax; l++) for (let i = 0; i + l < S.length; i++) { const d = Math.round(S[i + l] - S[i]); if (d >= CLOUD.cadMinS && d <= CLOUD.cadMaxS) cnt.set(d, (cnt.get(d) || 0) + 1); }
  const all = Array.from(cnt.entries()).sort((a, b) => b[1] - a[1] || a[0] - b[0]), out = [];
  for (const [d] of all) { if (out.length >= CLOUD.candMax) break; if (!out.some(c => Math.abs(d - c) <= cloudTol(c))) out.push(d); }
  return out;
}
function cloudChain(S, c, km) {   // the longest chain of burst starts one, two … km periods apart (each link within tol, the smaller miss on a tie) → { idx, k }
  const n = S.length, tol = cloudTol(c), f = new Array(n).fill(1), pv = new Array(n).fill(-1), dv = new Array(n).fill(0), kk = new Array(n).fill(0), reach = km * c + tol;
  for (let i = 0; i < n; i++) for (let j = i + 1; j < n && S[j] - S[i] <= reach; j++) {
    const x = S[j] - S[i], k = Math.round(x / c); if (k < 1 || k > km) continue;
    const dev = Math.abs(x - k * c); if (dev > tol) continue;
    const L = f[i] + 1; if (L > f[j] || (L === f[j] && dev < dv[j])) { f[j] = L; pv[j] = i; dv[j] = dev; kk[j] = k; }
  }
  let b = 0; for (let i = 1; i < n; i++) if (f[i] > f[b]) b = i;
  const idx = [], ks = []; for (let i = b; i >= 0; i = pv[i]) { idx.push(i); ks.push(kk[i]); if (pv[i] < 0) break; }
  return { idx: idx.reverse(), k: ks.reverse() };
}
function cloudNeed(n, mu) { let x = n, l = 1; while (x > CLOUD.alpha) { x *= mu; l++; if (l > 400) break; } return l; }   // the longest chain n starts make by chance (each followed with chance mu): n·mu^(l-1) <= alpha
function cloudMedian(a) { const s = a.slice().sort((x, y) => x - y); return s[Math.round((s.length - 1) / 2)]; }
function cloudStreams(S) {   // burst starts ascending → [{ idx, per }]: the clearest rhythm first, its bursts taken out, again up to streamMax; then the chains of a dense band
  const out = [];
  let R = S.map((_, i) => i);
  for (let pass = 0; pass < CLOUD.streamMax && R.length >= CLOUD.minBursts; pass++) {
    const Sr = R.map(i => S[i]), nn = Sr.length, TT = Sr[nn - 1] - Sr[0], ok = [], all = [];
    for (const c of cloudCands(Sr)) {
      const h = cloudHits(Sr, c), E = Math.max(1, h.side, TT > 0 ? cloudChance(nn, TT, c) : 0), x = h.p.length - E - CLOUD.hMin, z2 = x > 0 ? x * x / E : 0, o = { z2, c, h };
      all.push(o);
      if (h.p.length >= CLOUD.minHits && h.sup.length >= CLOUD.minBursts && h.p.length >= CLOUD.ratio * Math.max(1, h.side) && z2 >= CLOUD.zK * CLOUD.zK) ok.push(o);
    }
    if (!ok.length) break;
    let best = ok.slice().sort((a, b) => b.z2 - a.z2 || a.c - b.c)[0];
    for (const o of all.slice().sort((a, b) => a.c - b.c)) if (o !== best && o.h.p.length >= CLOUD.fundFrac * best.h.p.length && o.h.sup.length >= CLOUD.minBursts && [2, 3].some(k => Math.abs(k * o.c - best.c) <= cloudTol(best.c))) { best = o; break; }   // the fundamental, not its multiple
    const deg = new Map(), bump = (i) => deg.set(i, (deg.get(i) || 0) + 1), drop = new Set();   // a burst only one pair holds, to a burst three hold, is a chance partner
    for (const [i, j] of best.h.p) { bump(i); bump(j); }
    for (const [i, j] of best.h.p) { if (deg.get(i) === 1 && deg.get(j) >= 3) drop.add(i); if (deg.get(j) === 1 && deg.get(i) >= 3) drop.add(j); }
    const keep = best.h.sup.filter(i => !drop.has(i)), sup = new Set(keep);
    if (keep.length < CLOUD.minBursts) break;
    out.push({ idx: keep.map(i => R[i]), per: Math.round(cloudMedian(best.h.p.map(q => q[2]))) });
    R = R.filter((_, i) => !sup.has(i));
  }
  for (let pass = 0; pass < CLOUD.streamMax && R.length >= CLOUD.minBursts; pass++) {   // a band too dense for pairs: chains, the first at muMax, later ones (the rest is thinner) at muMaxMore
    const Sr = R.map(i => S[i]), n = Sr.length, T = Sr[n - 1] - Sr[0]; if (!(T > 0)) break;
    const mm = pass ? CLOUD.muMaxMore : CLOUD.muMax; let best = null;
    for (const c of cloudCands(Sr)) {
      const tol = cloudTol(c); let prev = 0;
      for (let km = 1; km <= CLOUD.kCap; km++) {   // as few skipped links as keep the chain: each link more is chance more
        if (km * 2 * tol * n / T > mm) break;
        const ch = cloudChain(Sr, c, km), L = ch.idx.length; if (L <= prev) break; prev = L;
        if (L < CLOUD.minBursts) continue;
        const a = Sr[ch.idx[0]], z = Sr[ch.idx[L - 1]], span = z - a; if (!(span > 0)) continue;
        let ns = 0; for (const s of Sr) if (s >= a && s <= z) ns++;
        const mu = km * 2 * tol * ns / span; if (mu > mm || L < cloudNeed(ns, mu) + CLOUD.margin) continue;
        if (!best || L > best.L || (L === best.L && c < best.c)) best = { c, ch, L };
      }
    }
    if (!best) break;
    const ch = best.ch, sp = []; for (let q = 1; q < ch.idx.length; q++) sp.push((Sr[ch.idx[q]] - Sr[ch.idx[q - 1]]) / ch.k[q]);
    out.push({ idx: ch.idx.map(i => R[i]), per: Math.round(cloudMedian(sp)) });
    const used = new Set(ch.idx.map(i => R[i])); R = R.filter(i => !used.has(i));
  }
  return out;
}
function cloudKin(p, q) { const lo = Math.min(p, q), hi = Math.max(p, q); for (let m = 1; m <= CLOUD.kCap; m++) if (Math.abs(hi - m * lo) <= cloudTol(hi)) return true; return false; }   // one period, or a whole number of them (a band that holds every other burst)
function cloudOnGap(g, cad) { const m = Math.round(g / cad); return m >= 1 && m <= CLOUD.kCap && Math.abs(g - m * cad) <= Math.max(CLOUD.tolMinS, CLOUD.tolFrac * m * cad); }   // one, two or three periods apart
function cloudShare(cb, cad) { let on = 0; for (let i = 1; i < cb.length; i++) if (cloudOnGap(cb[i][0] - cb[i - 1][0], cad)) on++; return cb.length > 1 ? on / (cb.length - 1) : 0; }
function cloudUnion(a, b) {   // two burst lists → one, ascending; a start within burstS of the one before it is the same burst
  const u = a.concat(b).sort((x, y) => x[0] - y[0]), out = [];
  for (const x of u) { if (out.length && x[0] - out[out.length - 1][0] <= CLOUD.burstS) { if (x[1] > out[out.length - 1][1]) out[out.length - 1][1] = x[1]; } else out.push([x[0], x[1]]); }
  return out;
}
function cloudsOf(E) {   // E sorted (rssi desc, MAC asc) → accepted clouds [{ c, cs, core, merged, join, cb, cad, per, share }]; stateless, the Overview's `clouds` is this rule
  const { bands } = cloudBands(E), cand = [];
  bands.forEach((b, bi) => { b.B = cloudBursts(b.W.map(e => e.t).sort((x, y) => x - y)).slice(-CLOUD.burstCap); cloudStreams(b.B.map(x => x[0])).forEach((s, si) => cand.push({ b, bi, si, s })); });   // the newest burstCap bursts of a band
  cand.sort((x, y) => y.s.idx.length - x.s.idx.length || x.bi - y.bi || x.si - y.si);   // the longest chain first
  const acc = [], near = (x, y) => x >= y[0] - CLOUD.burstS && x <= y[1] + CLOUD.burstS;
  for (const { b, s } of cand) {
    const cb = s.idx.map(i => b.B[i]), core = b.W.filter(e => cb.some(y => e.t >= y[0] && e.t <= y[1]));   // the addresses of the stream's own bursts
    // the same bursts seen in another signal band (one device with a wide spread), or bursts that fill in the same rhythm (a device that drifted from band to band)
    const dup = acc.find(a => Math.abs(a.c - b.c) <= CLOUD.mergeDb && (cb.filter(x => a.cb.some(y => near(x[0], y))).length >= CLOUD.coincide * cb.length
      || (cloudKin(a.per, s.per) && cloudShare(cloudUnion(a.cb, cb), Math.min(a.per, s.per)) >= CLOUD.mergeShare)));
    if (dup) { dup.per = dup.cad = Math.min(dup.per, s.per); dup.cs.push(b.c); dup.merged = dup.merged.concat(core); dup.cb = cloudUnion(dup.cb, cb); dup.share = cloudShare(dup.cb, dup.per); }
    else if (core.length >= CLOUD.minAddr) acc.push({ c: b.c, cs: [b.c], core, merged: [], join: [], cb, cad: s.per, per: s.per, share: cloudShare(cb, s.per) });   // the period shown is the fitted one
  }
  const used = new Set(); for (const a of acc) for (const e of a.core.concat(a.merged)) used.add(e.id);
  for (const e of E) if (!used.has(e.id)) for (const a of acc) if (a.cs.some(c => Math.abs(e.r - c) <= CLOUD.joinDb) && a.cb.some(y => near(e.t, y))) { a.join.push(e); break; }   // a loose address heard inside a burst
  return acc;
}
function liveCloud(id) { const k = id != null ? S.clouds.get(id) : null; return !!k && k.target === 1; }
function cloudExpanded(id) { const k = id != null ? S.clouds.get(id) : null; return !!k && k.expandedUntil != null && k.expandedUntil > S.clock; }
function pushCloudHist(k, rssi, gen) {
  const h = k.hist;
  h.buf[h.head] = clamp(Math.round(rssi), -120, 0); h.ts[h.head] = gen;
  h.head = (h.head + 1) % HISTORY_LEN; h.n = Math.min(HISTORY_LEN, h.n + 1); h.lastGen = gen; h.lastSeq = S.ingestSeq; k.sparkDirty = true;
}
function rebuildClouds(gen, rp) {   // → true when a member list, the cloud set or a rounded signal changed
  const E = [];
  S.clients.forEach(c => {
    c.cloud = null;
    if (c.target === 1 && c.randomized && (c.free || c.affinity) && c.rssi != null && c.freshTier != null && !eventSkip(c)) E.push({ id: c.id, r: c.rssi, t: c.last_seen, c });   // own transmitters are no cloud
  });
  E.sort((a, b) => b.r - a.r || cmpStr(a.id, b.id));
  const acc = cloudsOf(E), eOf = new Map(E.map(e => [e.id, e])), taken = new Map();
  acc.forEach((a, ai) => { a.M = a.core.concat(a.merged, a.join); for (const e of a.M) taken.set(e.id, ai); });
  // identity: an accepted cloud takes over a cloud that was live (or has only just faded) when they share at least half of the smaller one, the most shared first
  const prs = [];
  S.clouds.forEach(k => {
    const sh = new Map(); let live = 0;
    for (const m of k.members) if (eOf.has(m)) { live++; const ai = taken.get(m); if (ai != null) sh.set(ai, (sh.get(ai) || 0) + 1); }
    sh.forEach((n, ai) => { if (n >= Math.max(1, Math.ceil(CLOUD.keepFrac * Math.min(live, acc[ai].M.length)))) prs.push({ k, ai, n }); });
  });
  prs.sort((x, y) => y.n - x.n || cmpStr(x.k.id, y.k.id) || x.ai - y.ai);
  const claimed = new Set();
  for (const p of prs) if (!claimed.has(p.k) && acc[p.ai].match == null) { claimed.add(p.k); acc[p.ai].match = p.k; }
  const items = acc.map(a => ({ M: a.M, c: a.c, core: a.core.length + a.merged.length, joined: a.join.length, bursts: a.cb.length, cad: a.cad, share: a.share, kept: false, match: a.match || null, anchor: a.core }));
  // a cloud that no accepted one took over stays while two of its own addresses are still here and in no other cloud: it never grows, it only runs down
  S.clouds.forEach(k => {
    if (claimed.has(k) || k.target !== 1) return;
    const M = k.members.filter(m => eOf.has(m) && !taken.has(m)).map(m => eOf.get(m)); if (M.length < CLOUD.keepAddr) return;
    items.push({ M, c: k.centre, core: M.length, joined: 0, bursts: cloudBursts(M.map(e => e.t).sort((x, y) => x - y)).length, cad: k.cadenceS, share: k.rhythm, kept: true, match: k, anchor: M });
  });
  let changed = false; const live = new Set();
  for (const it of items) {
    const M = it.M.slice().sort((x, y) => y.r - x.r || cmpStr(x.id, y.id));
    let k = it.match; const was = !!k && k.target === 1;
    if (!k) {   // a new cloud: its id hangs on its oldest core address
      let a = it.anchor[0]; for (const e of it.anchor) if (e.t < a.t || (e.t === a.t && cmpStr(e.id, a.id) < 0)) a = e;
      const base = "rc:" + hashInt(a.id).toString(16).padStart(8, "0"); let id = base;
      for (let i = 2; S.clouds.has(id); i++) id = base + ":" + i;
      k = newCloud(id); k.anchor = a.id; S.clouds.set(id, k); changed = true;
    } else if (k.target !== 1) changed = true;   // a cloud that had just faded is back
    let s = 0, lo = Infinity, hi = -Infinity, t0 = Infinity, t1 = -Infinity; const pc = new Map();
    for (const e of M) {
      s += e.r;
      if (e.r < lo) lo = e.r;
      if (e.r > hi) hi = e.r;
      if (e.t < t0) t0 = e.t;
      if (e.t > t1) t1 = e.t;
      if (e.c.probes) for (const p of e.c.probes) pc.set(p, (pc.get(p) || 0) + 1);
    }
    const mean = s / M.length, rssi = mean < 0 ? -Math.round(-mean) : Math.round(mean), members = M.map(e => e.id).sort(cmpStr);
    if (k.rssi !== rssi || k.members.length !== members.length || k.members.some((m, i) => m !== members[i])) changed = true;
    k.members = members; k.n = members.length; k.core = it.core; k.joined = it.joined; k.centre = it.c;   // membership
    k.rssi = rssi; k.rssiMin = lo; k.rssiMax = hi;   // signal
    k.first = t0; k.last = t1;   // time
    k.bursts = it.bursts; k.cadenceS = it.cad; k.rhythm = it.share; k.kept = it.kept;   // rhythm
    k.target = 1; it.was = was;   // lifecycle
    k.probes = Array.from(pc.entries()).sort((x, y) => y[1] - x[1] || cmpStr(x[0], y[0])).slice(0, 8).map(x => x[0]);
    const fr = freshOf(t1, gen); k.ageS = fr.ageS; k.freshTier = fr.tier; k.freshAT = ENCODING.fresh.alpha[fr.tier ?? 0]; if (!it.match) k.freshA = k.freshAT;
    for (const e of M) e.c.cloud = k.id;
    live.add(k.id);
    if (!rp && gen != null && k.hist.lastGen !== gen) pushCloudHist(k, rssi, gen);
  }
  S.clouds.forEach(k => { if (k.target === 1 && !live.has(k.id)) { k.target = 0; k.expandedUntil = null; changed = true; } });
  S.cloudOrder = Array.from(live).sort(cmpStr).map(id => S.clouds.get(id));
  if (!rp && gen != null && gen === S.ev.lastGen && S.ev.cloudGen !== gen) {   // D2, once per capture: new addresses a live cloud took in
    S.ev.cloudGen = gen; let nic = 0;
    for (const it of items) if (it.was) for (const e of it.M) if (e.c.newSeq === S.captureSeq) nic++;
    S.ev.newInClouds = nic;
  }
  return changed;
}
function applyRandom() {   // the Random switch: randOut = folded into a shown cloud or hidden; → true on a change
  const m = S.ui.random; let changed = false;
  S.clients.forEach(c => {
    const out = c.target === 1 && (m === "cloud" ? c.cloud != null : m === "hide" && !!c.randomized && (c.free || !!c.affinity));
    if (out !== !!c.randOut) { c.randOut = out; changed = true; }
  });
  return changed;
}
const btOn = (k) => k.kind === "bt" ? S.ui.filters.bt : S.ui.random === "cloud";   // key 4 for S.bt, X for S.clouds
const btRot = (t) => t !== "public" && t !== "random-static";
function rebuildBt(doc, gen, rp) {   // §3.1 marks: fixed = one mark, rotating = per company and ring (3 dB hysteresis)
  const L = doc.bluetooth, W = doc.center.bt_window ?? null, hold = doc.center.bt_hold ?? 120, keep = !!L && W === 0 && !L.length, grp = new Map(), lv = new Map(), rg = LAYOUT.rings;
  S.btDoc = L ? { window: W, hold, void: W === 0 } : null;
  for (const b of keep ? [] : L || []) {
    const rot = btRot(b.addr_type), p = rot && !rp ? S.btLvl.get(b.addr) : null;
    let l = signalLevel(b.rssi);
    if (p != null && b.rssi >= (rg[p] ?? -999) - BT.hystDb && b.rssi < (rg[p - 1] ?? 999) + BT.hystDb) l = p;
    const key = "bt:" + (rot ? (b.company ?? "-") + ":" + l : b.addr);
    lv.set(b.addr, l); (grp.get(key) || grp.set(key, []).get(key)).push(b);
  }
  if (!keep && !rp) S.btLvl = lv;
  grp.forEach((m, key) => {
    let k = S.bt.get(key); const s = m.reduce((x, b) => x + b.rssi, 0) / m.length;
    if (!k) { k = newCloud(key); k.kind = "bt"; S.bt.set(key, k); }
    m.sort((a, b) => b.rssi - a.rssi || cmpStr(a.addr, b.addr));
    Object.assign(k, { m, n: m.length, rssi: s < 0 ? -Math.round(-s) : Math.round(s), company: m[0].company, companyName: m[0].company_name, rot: btRot(m[0].addr_type), target: 1, lastSeen: Math.max(...m.map(b => b.last_seen ?? 0)) });
    homeOfClient(k);
  });
  S.bt.forEach((k, id) => {   // a void window lets marks run out by their own age
    const fr = freshOf(k.lastSeen, gen); k.freshTier = fr.tier; k.freshAT = ENCODING.fresh.alpha[fr.tier ?? 0];
    if (keep ? gen != null && gen - k.lastSeen > hold : !grp.has(id)) k.target = 0;
  });
  S.btOrder = Array.from(S.bt.values()).filter(k => k.target === 1).sort((a, b) => b.rssi - a.rssi || cmpStr(a.id, b.id)); S.btOrder.forEach((k, i) => { k.rank = i; });
}
function btStats() {   // §3.10 counts over the live marks
  if (!S.btDoc) return null;
  const v = S.btOrder, a = v.reduce((x, k) => x + k.n, 0), r = v.reduce((x, k) => x + (k.rot ? k.n : 0), 0);
  return { addresses: a, marks: v.length, rotating: r, fixed: a - r, shown: S.ui.filters.bt ? v.filter(k => k.alphaDraw > 0.05).length : 0, window: S.btDoc.window, hold: S.btDoc.hold, void: S.btDoc.void };
}
function pubCloud(k) {
  return k ? { id: k.id, kind: "cloud", n: k.n, core: k.core, joined: k.joined, members: k.members.slice(), rssi: k.rssi, rssiMin: k.rssiMin, rssiMax: k.rssiMax, centre: r3(k.centre),
    first: k.first, last: k.last, bursts: k.bursts, cadenceS: k.cadenceS, rhythm: r3(k.rhythm), probes: k.probes.slice(), kept: k.kept, shown: k.target === 1 && S.ui.random === "cloud",
    expanded: cloudExpanded(k.id), pinned: S.pinned.has(k.id), freshTier: k.freshTier, ageS: k.ageS, sx: r3(k.sx), sy: r3(k.sy), px: r3(k.px), zc: r3(k.zc), alphaDraw: r3(k.alphaDraw) } : null;
}
function pubDevice(dev) { return dev ? { id: dev.id, members: dev.memberIds.slice(), bands: dev.bands.slice(), vendor: dev.vendor, reason: dev.reason.slice() } : null; }
// Manual identity classification (per BSSID, persisted, operator-set — never automatic).
const IDENTITY_KEY = "starchorus.identity.v1", IDENT_MAX = 5000;   // P8: a manual entry is never evicted, a new key is refused when full
const identCanAdd = (b) => S.identity.has(b) || S.identity.size < IDENT_MAX;
function identityOf(bssid) { const b = String(bssid).toLowerCase(); return S.identity.get(b) || ruleOf(b) || "unknown"; }
function identitySource(bssid) { const b = String(bssid).toLowerCase(); return S.identity.has(b) ? "manual" : ruleOf(b) ? "rule-matched" : null; }   // P7: a wildcard-rule hit is shown as "rule-matched"
// Identity, library and alias/notes/tags accept any observed KEY — heard as an AP or a station, present this capture or in the
// baseline. Homing has its own gate (homingIngest); the watchlist matches SSID text only, never a key. The check is here, in the
// one function every path goes through — the UI, import and STARCHORUS.setIdentity alike.
function observed(bssid) {
  const b = String(bssid).toLowerCase();
  const a = S.aps.get(b); if (a && a.target === 1) return true;
  const c = S.clients.get(b); if (c && c.target === 1) return true;
  return !!(S.baseline && (S.baseline.aps.has(b) || (S.baseline.st && S.baseline.st.has(b))));
}
const RULE_PAT = /^(?:[0-9a-f?]{2}|\*)(?::(?:[0-9a-f?]{2}|\*)){5}$/;
function ruleRegex(pat) {   // "aa:bb:cc:??:1?:*" -> anchored regex; at least three fixed octets (an OUI), so "*:*:*:*:*:*" cannot exist (P7)
  const p = String(pat).trim().toLowerCase(); if (!RULE_PAT.test(p)) return null;
  const oct = p.split(":"); if (oct.filter(o => /^[0-9a-f]{2}$/.test(o)).length < 3) return null;
  return new RegExp("^" + oct.map(o => o === "*" ? "[0-9a-f]{2}" : o.replace(/\?/g, "[0-9a-f]")).join(":") + "$");
}
function ruleOf(b) { for (const r of S.rules) if (r.re.test(b)) return r.cls; return null; }
function loadLibrary() {
  try {
    const raw = safeStorage.get(LIB_KEY);
    if (raw) {
      const o = JSON.parse(raw);
      if (isObj(o) && Array.isArray(o.rules)) for (const r of o.rules.slice(0, RULES_MAX)) {
        const re = isObj(r) ? ruleRegex(r.pat) : null;
        if (re && (r.cls === "friend" || r.cls === "neutral" || r.cls === "hostile")) S.rules.push({ pat: String(r.pat).toLowerCase(), cls: r.cls, re });
      }
    }
  } catch (e) { /* none */ }
  try {
    const raw = safeStorage.get(NOTES_KEY);
    if (raw) {
      const o = JSON.parse(raw);
      if (isObj(o)) for (const k of Object.keys(o).slice(0, NOTES_MAX)) {
        const e = o[k];
        if (Array.isArray(e) && isMac(k)) S.notes.set(k, { a: stripCtl(e[0], 24), n: stripCtl(e[1], 120), t: Array.isArray(e[2]) ? e[2].map(x => stripCtl(x, 12)).filter(Boolean).slice(0, 4) : [] });
      }
    }
  } catch (e) { /* none */ }
}
function saveLibrary() { if (S.rules.length) safeStorage.set(LIB_KEY, JSON.stringify({ v: 1, rules: S.rules.map(r => ({ pat: r.pat, cls: r.cls })) })); else safeStorage.remove(LIB_KEY); }
function saveNotes() { if (S.notes.size) { const o = {}; S.notes.forEach((e, k) => { o[k] = [e.a, e.n, e.t]; }); safeStorage.set(NOTES_KEY, JSON.stringify(o)); } else safeStorage.remove(NOTES_KEY); }
function notesSet(bssid, patch) {   // alias (<= 24), note (<= 120), up to 4 tags (<= 12) — any observed key (AP or station), <= 200 entries
  const b = String(bssid).toLowerCase(); if (!observed(b)) return null;
  const e = S.notes.get(b) || { a: "", n: "", t: [] }, q = patch || {};
  if ("alias" in q) e.a = stripCtl(q.alias, 24).trim();
  if ("note" in q) e.n = stripCtl(q.note, 120).trim();
  if ("tags" in q) e.t = (Array.isArray(q.tags) ? q.tags : String(q.tags).split(",")).map(x => stripCtl(x, 12).trim()).filter(Boolean).slice(0, 4);
  if (!e.a && !e.n && !e.t.length) S.notes.delete(b);
  else { if (!S.notes.has(b) && S.notes.size >= NOTES_MAX) return null; S.notes.set(b, e); }
  saveNotes(); S.dirty = true; return S.notes.get(b) ? { alias: e.a, note: e.n, tags: e.t.slice() } : { alias: "", note: "", tags: [] };
}
const aliasOf = (id) => { const e = S.notes.get(String(id).toLowerCase()); return e && e.a ? e.a : ""; };
const LIB_CLASS = { friend: "friend", neutral: "neutral", suspect: "hostile", hostile: "hostile", unknown: "unknown" };
function libraryImport(text) {   // "MAC class" per line; "aa:bb:cc:??:??:??" (or *) is a rule (friend/neutral/suspect, never unknown); # starts a comment
  const res = { added: 0, rules: 0, rejected: [], message: "" };
  const rej = (line, why) => res.rejected.push({ line: line.slice(0, 60), why });
  for (const raw of String(text).split(/\r?\n/).slice(0, 2000)) {
    const l = raw.replace(/#.*/, "").trim(); if (!l) continue;
    const [k, c] = l.split(/\s+/), cls = LIB_CLASS[String(c || "").toLowerCase()];
    if (!cls) { rej(l, "unknown class"); continue; }
    if (/[?*]/.test(k)) {
      if (cls === "unknown") { rej(l, "a rule cannot assign unknown"); continue; }
      const re = ruleRegex(k); if (!re) { rej(l, "not a valid rule"); continue; }
      const p = k.toLowerCase(); S.rules = S.rules.filter(r => r.pat != p);
      if (S.rules.length >= RULES_MAX) { rej(l, "too many rules"); continue; }
      S.rules.push({ pat: p, cls, re }); res.rules++; continue;
    }
    const b = normMac(k); if (!isMac(b)) { rej(l, "not a MAC"); continue; }
    if (cls === "unknown") { S.identity.delete(b); continue; }
    if (!observed(b)) { rej(l, "not observed"); continue; }
    if (!identCanAdd(b)) { rej(l, "identity store full"); continue; }
    S.identity.set(b, cls); res.added++;
  }
  saveIdentity(); saveLibrary(); buildLegend(); S.dirty = true; renderInv();
  const n = res.rejected.length; res.message = n ? n + " rejected" + (res.rejected.every(r => r.why === "not observed") ? ": not observed" : "") : "";
  return res;
}
function libraryExport() {   // every observed key with a set class (AP or station); wildcard rules after the single entries
  const out = ["# Starchorus library · observed keys (APs and stations) · " + EXPORT_FOOTER];
  S.identity.forEach((cls, b) => { if (observed(b)) out.push(b + " " + (cls === "hostile" ? "suspect" : cls)); });
  for (const r of S.rules) out.push(r.pat + " " + r.cls);
  return out.join("\n") + "\n";
}
function libraryAssign(cls, filter) {   // bulk assign friend/neutral/suspect to every present AP OR station matching {ssid?, vendor?, band?, sec?, ids?}
  if (cls !== "friend" && cls !== "neutral" && cls !== "hostile") return 0;
  const f = filter || {}; let n = 0;
  const take = (node, isAp) => {
    if (!observed(node.id) || !identCanAdd(node.id)) return;
    if (isAp && eventSkip(node)) return;   // own transmitters / mobile hotspots (AP-only notion) stay out of AP bulk
    if (isAp) { if (f.ssid != null && (node.ssidKnown || node.ssid) !== f.ssid) return; if (f.sec != null && node.sec !== f.sec) return; }
    else if (f.ssid != null || f.sec != null) return;   // a station has no SSID/security of its own: an ssid/sec filter never matches it
    if (f.vendor != null && (node.vendor || null) !== f.vendor) return;
    if (f.band != null && node.band !== f.band) return;
    if (f.ids && !f.ids.includes(node.id)) return;   // the inventory's "shown rows" (or any caller-supplied id set, station ids included)
    S.identity.set(node.id, cls); n++;
  };
  for (const ap of S.apOrder) take(ap, true);
  for (const cl of S.clientOrder) if (cl.target === 1) take(cl, false);
  if (n) { saveIdentity(); buildLegend(); S.dirty = true; renderInv(); }
  return n;
}
const SEC_RANK = { open: 0, wep: 1, "tkip-weak": 2, wpa: 3, wpa2: 4, enterprise: 5, "wpa3-transition": 6, owe: 7, wpa3: 8 };
function worstSec(memberIds) {   // the weakest member of a constellation (unknown classes do not count)
  let w = null, r = 99; for (const id of memberIds) { const n = S.aps.get(id); if (!n || !(n.sec in SEC_RANK)) continue; if (SEC_RANK[n.sec] < r) { r = SEC_RANK[n.sec]; w = n.sec; } }
  return w;
}
function loadIdentity() {
  try { const raw = safeStorage.get(IDENTITY_KEY); if (!raw) return; const o = JSON.parse(raw);
    if (o && typeof o === "object") for (const k of Object.keys(o).slice(0, IDENT_MAX)) { const v = o[k]; if (v === "friend" || v === "neutral" || v === "hostile") S.identity.set(String(k).toLowerCase(), v); }
  } catch (e) {}
}
function saveIdentity() { const o = {}; S.identity.forEach((v, k) => { o[k] = v; }); safeStorage.set(IDENTITY_KEY, JSON.stringify(o)); }
function setIdentity(bssid, id) {
  const b = String(bssid).toLowerCase();
  if (id == null || id === "unknown") S.identity.delete(b);
  else if (id === "friend" || id === "neutral" || id === "hostile") { if (!observed(b) || !identCanAdd(b)) return identityOf(b); S.identity.set(b, id); }
  else return identityOf(b);
  saveIdentity(); buildLegend(); S.dirty = true;
  if (S.locked === b || (S.locked && String(S.locked).toLowerCase() === b)) openDetail(S.locked);
  return identityOf(b);
}
function identityCounts() {
  const c = { friend: 0, neutral: 0, hostile: 0, unknown: 0 };
  S.identity.forEach((v, b) => { if (v in c && observed(b)) c[v]++; });
  // every node without a manual class is tallied by rule match: an AP that matches none is "unknown" (a count, never a list);
  // a station counts only on a rule match, as drawClients does, and has no "unknown" bucket
  S.apOrder.forEach(n => { if (!eventSkip(n) && !S.identity.has(n.id)) { const r = ruleOf(n.id); if (r) c[r]++; else c.unknown++; } });
  S.clientOrder.forEach(n => { if (n.target === 1 && !S.identity.has(n.id)) { const r = ruleOf(n.id); if (r) c[r]++; } });
  return c;
}

