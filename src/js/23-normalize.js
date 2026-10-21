// ==== 23 NORMALIZE ====
function normMac(x) {
  let s = String(x).trim().toLowerCase().replace(/-/g, ":");
  if (/^[0-9a-f]{12}$/.test(s)) s = s.match(/../g).join(":");
  return s;
}
const isMac = (m) => /^[0-9a-f]{2}(:[0-9a-f]{2}){5}$/.test(m);
const idOr = (x, fallback) => x != null && String(x).trim() !== "" ? normMac(x) : fallback;
const strOrNull = (x, max) => typeof x === "string" ? stripCtl(x, max).trim() || null : null;   // "" → null
const dbmOrNull = (x) => { const v = numOrNull(x); return v == null ? null : clamp(v, -120, 0); };
function ulBit(mac) { const c = mac.charAt(1); return c === "2" || c === "6" || c === "a" || c === "e"; }
function secClass(s, akm, cipher) {   // the collector's label AND, when present, its AKM/cipher detail (OWE before WPA3: libwifi sets the WPA3 class bit for OWE)
  const u = String(s || "").toUpperCase().trim(), ak = Array.isArray(akm) ? akm : [];
  if ((ak.includes("owe") && !ak.some(x => /^(psk|sae|1x)/.test(x))) || u.includes("OWE")) return "owe";
  if (u.includes("ENTERPRISE") || u.includes("802.1X") || ak.some(x => /^1x|^fils/.test(x))) return "enterprise";
  const pw = cipher && Array.isArray(cipher.pairwise) ? cipher.pairwise : [];
  if ((u.includes("TKIP") && !u.includes("CCMP") && !u.includes("GCMP")) || (pw.includes("tkip") && !pw.some(x => /^(ccmp|gcmp)/.test(x)))) return "tkip-weak";
  if ((u.includes("WPA3") && u.includes("WPA2")) || (ak.includes("sae") && ak.some(x => /^psk/.test(x))) || /SAE.*PSK|PSK.*SAE/.test(u)) return "wpa3-transition";
  if (u.includes("WPA3") || u.includes("SAE")) return "wpa3";
  if (u.includes("WEP")) return "wep";
  if (u.includes("WPA2") || u.includes("RSN") || u.includes("CCMP")) return "wpa2";
  if (u.includes("WPA") || u.includes("PSK") || u.includes("TKIP") || u.includes("SECURED")) return "wpa";
  if (u === "" || u === "OPEN" || u === "NONE" || u === "ESS") return "open";
  return "unknown";
}
function bandOf(band, freq, channel) {
  const b = String(band ?? "").trim().replace(/\s*ghz$/i, "");
  if (b === "2.4" || b === "5" || b === "6") return b;
  if (freq != null) { if (freq >= 5925) return "6"; if (freq >= 5000) return "5"; if (freq >= 2400) return "2.4"; }
  if (channel != null) { if (channel > 177) return "6"; if (channel >= 32 && channel <= 177) return "5"; if (channel >= 1 && channel <= 14) return "2.4"; }
  return "unknown";
}
function freshOf(lastSeen, gen) {   // D1 → { ageS, tier }: tier 0..3, null = undated (no capture time, last_seen ≤ 0, or later than generated + 300 s)
  if (gen == null || lastSeen == null || !(lastSeen > 0)) return { ageS: null, tier: null };
  const age = gen - lastSeen;
  if (age < -FRESH.futureS) return { ageS: null, tier: null };
  const a = Math.max(0, age); let t = 0;
  while (t < FRESH.tiersS.length && a >= FRESH.tiersS[t]) t++;
  return { ageS: a, tier: t };
}
function freshReach() {   // D1: a tier the collector's age window can never reach (max_age ≤ its lower bound) is hidden, not shown as an empty stage
  const lo = [0].concat(FRESH.tiersS), m = S.maxAgeS;
  return lo.map(b => !(m > 0) || b < m);
}
function normClient(c, fallbackId) {
  const mac = idOr(c.mac, fallbackId), rssi = dbmOrNull(c.rssi), vendor = strOrNull(c.vendor, 48);
  let probes = null;
  if (Array.isArray(c.probes)) {
    const seen = new Set();
    for (const s of c.probes) {
      if (typeof s !== "string") continue;
      const v = stripCtl(s, 32).trim();
      if (!v || seen.has(v)) continue;
      seen.add(v);
      if (seen.size >= 8) break;
    }
    if (seen.size) probes = Array.from(seen);
  }
  return { mac, rssi, vendor, last_seen: numOrNull(c.last_seen), packets: numOrNull(c.packets), probes,
    randomized: c.randomized === true || (!vendor && ulBit(mac)) };
}
function normBt(r) {   // §3.1 bluetooth[]: the strongest 256, null without an array
  if (!Array.isArray(r)) return null;
  const m = new Map();
  for (const b of r.slice(0, 2000)) {
    if (!isObj(b)) continue;
    const addr = normMac(b.addr), rssi = dbmOrNull(b.rssi), co = numOrNull(b.company);
    if (isMac(addr) && rssi != null && !(m.has(addr) && m.get(addr).rssi >= rssi)) m.set(addr, { addr, addr_type: BT_TYPES.includes(b.addr_type) ? b.addr_type : "random", rssi, reports: numOrNull(b.reports), last_seen: numOrNull(b.last_seen),
      company: co >= 0 && co < 65536 && co % 1 === 0 ? co : null, company_name: strOrNull(b.company_name, 48), name: strOrNull(b.name, 32), connectable: b.connectable === true });
  }
  return Array.from(m.values()).sort((a, b) => b.rssi - a.rssi || cmpStr(a.addr, b.addr)).slice(0, BT.cap);
}
const normAct = (r) => Array.isArray(r) ? r.slice(0, 69).flatMap(x => { const f = isObj(x) ? numOrNull(x.freq) : null, s = isObj(x) ? numOrNull(x.share) : null; return f > 0 && s > 0 && s <= 1 ? [{ freq: f, share: s }] : []; }) : null;   // §3.1 activity[]
function normalizeDoc(raw) {
  if (!isObj(raw) || !Array.isArray(raw.aps)) return null;
  const strs = (v, n, m) => Array.isArray(v) ? v.filter(x => typeof x === "string").map(x => stripCtl(x, m)).filter(Boolean).slice(0, n) : null;
  const rc = isObj(raw.center) ? raw.center : {};
  const doc = {
    generated: numOrNull(raw.generated),
    source: typeof raw.source === "string" ? stripCtl(raw.source, 32) : "",
    note: stripCtl(raw.note, 120),
    center: { label: rc.label != null ? stripCtl(rc.label, 40).trim() : "",
      max_age: numOrNull(rc.max_age) >= 0 ? numOrNull(rc.max_age) : null,   // D1: collector age window (0 = whole record)
      interval: numOrNull(rc.interval) > 0 ? numOrNull(rc.interval) : null,
      // this device's own transmitters (interface MACs / operator file): kept in memory for the exclusion logic only; never rendered, exported or stored
      own_bssids: Array.isArray(rc.own_bssids) ? rc.own_bssids.map(normMac).filter(isMac).slice(0, 16) : [],
      own_ssids: strs(rc.own_ssids, 32, 32) || [], bt_window: numOrNull(rc.bt_window), bt_hold: numOrNull(rc.bt_hold) },
    // optional alerts[] {type, t, ap, n}: local-live (P6)
    alerts: Array.isArray(raw.alerts) ? raw.alerts.slice(0, 20).map(x => {
      if (!isObj(x) || x.type !== "deauth") return null;
      const ap = normMac(x.ap);
      const n = numOrNull(x.n);
      return isMac(ap) && n != null && n > 0 ? { type: "deauth", t: numOrNull(x.t), ap, n: Math.round(n) } : null;
    }).filter(Boolean) : [],
    // optional homing reading {bssid, dbm, peak, t} for ONE target the device (or STARCHORUS_HOMING_BSSID) chose; validated at ingest (an observed key present this capture — an AP or a station; own transmitters refused)
    homing: isObj(raw.homing) && numOrNull(raw.homing.dbm) != null ? { bssid: normMac(raw.homing.bssid), dbm: dbmOrNull(raw.homing.dbm), peak: numOrNull(raw.homing.peak), t: numOrNull(raw.homing.t) } : null,
    // hop awareness: per frequency the last time anything was heard and (flagged) the driver's busy percentage / noise.
    channels: Array.isArray(raw.channels) ? raw.channels.slice(0, 200).map(c => {
      const f = isObj(c) ? numOrNull(c.freq) : null;
      if (!(f > 0)) return null;
      const b = numOrNull(c.busy_pct);
      return { freq: f, last_heard: numOrNull(c.last_heard), busy_pct: b == null ? null : clamp(Math.round(b), 0, 100), noise: numOrNull(c.noise) };
    }).filter(Boolean) : null,
    aps: [], unassociated: [], bluetooth: normBt(raw.bluetooth), activity: normAct(raw.activity),
  };
  if (!doc.center.label) doc.center.label = "YOU ARE HERE";
  const apMap = new Map();
  raw.aps.forEach((a, i) => {
    if (!isObj(a)) return;
    const bssid = idOr(a.bssid, "ap" + i), rssi = dbmOrNull(a.rssi);
    const channel = numOrNull(a.channel), freq = numOrNull(a.freq);
    let width = numOrNull(a.width); if (width != null && ![20, 40, 80, 160, 320].includes(width)) width = null;
    const vendor = strOrNull(a.vendor, 48), phy = strOrNull(a.phy, 8);
    let caps = null;
    if (Array.isArray(a.caps)) caps = a.caps.filter(x => typeof x === "string").map(x => stripCtl(x, 24)).slice(0, 12);
    else if (typeof a.caps === "string") caps = a.caps.split(",").map(x => stripCtl(x, 24).trim()).filter(Boolean).slice(0, 12);
    let cipher = null;   // optional, APs only
    if (isObj(a.cipher)) cipher = { group: typeof a.cipher.group === "string" ? stripCtl(a.cipher.group, 16) : null, pairwise: strs(a.cipher.pairwise, 8, 16) || [] };
    let resp = numOrNull(a.responded_ssids); resp = resp != null && resp >= 2 ? Math.round(resp) : null;
    const ap = { bssid, ssid: stripCtl(a.ssid, 32), channel, freq, band: bandOf(a.band, freq, channel), bandF: bandOf(a.band, freq, null), rssi,
      security: stripCtl(a.security, 48), vendor, rate: numOrNull(a.rate), width, last_seen: numOrNull(a.last_seen), phy, caps,
      beacons: numOrNull(a.beacons), packets: numOrNull(a.packets), akm: strs(a.akm, 12, 24), cipher, auth: strs(a.auth, 6, 16), responded_ssids: resp, clients: [] };
    const cl = Array.isArray(a.clients) ? a.clients : [];
    cl.forEach((c, j) => { if (!isObj(c)) return; ap.clients.push(normClient(c, bssid + ":c" + j)); });
    const prev = apMap.get(bssid);
    if (!prev) { apMap.set(bssid, ap); return; }
    // merge duplicate bssid: strongest RSSI, first non-empty value per field
    if (ap.rssi != null && (prev.rssi == null || ap.rssi > prev.rssi)) prev.rssi = ap.rssi;
    const empty = (v) => v === null || v === "" || v === undefined;
    for (const k of ["ssid", "channel", "freq", "security", "vendor", "rate", "width", "last_seen", "phy", "caps", "beacons", "packets", "akm", "cipher", "auth", "responded_ssids"]) if (empty(prev[k]) && !empty(ap[k])) prev[k] = ap[k];
    if (prev.band === "unknown" && ap.band !== "unknown") prev.band = ap.band;
    if (prev.bandF === "unknown" && ap.bandF !== "unknown") prev.bandF = ap.bandF;
    const have = new Set(prev.clients.map(c => c.mac));
    for (const c of ap.clients) if (!have.has(c.mac)) { have.add(c.mac); prev.clients.push(c); }
  });
  const assocMacs = new Set();
  apMap.forEach(ap => {
    if (ap.rssi == null) ap.rssi = -75;
    const uniq = [];
    for (const c of ap.clients) { if (assocMacs.has(c.mac)) continue; assocMacs.add(c.mac); uniq.push(c); }   // first AP wins
    ap.clients = uniq;
    doc.aps.push(ap);
  });
  const freeSeen = new Set();
  (Array.isArray(raw.unassociated) ? raw.unassociated : []).forEach((c, j) => {
    if (!isObj(c)) return;
    const n = normClient(c, "free" + j);
    if (assocMacs.has(n.mac) || freeSeen.has(n.mac)) return;   // associated wins; duplicate free entries collapse
    freeSeen.add(n.mac); doc.unassociated.push(n);
  });
  return doc;
}
function demoData() {
  const macFrom = (oui, seed, randomized) => {
    const h = hashInt(seed);
    let b0 = (h >>> 24) & 255, b1 = (h >>> 16) & 255, b2 = (h >>> 8) & 255;
    if (oui) return oui + ":" + [b0, b1, b2].map(v => v.toString(16).padStart(2, "0")).join(":");
    const b3 = h & 255, b4 = (hashInt(seed + "x") >>> 8) & 255;
    b0 = randomized ? ((b0 & 0xf0) | (hash(seed + "u") > 0.5 ? 0x0a : 0x0e)) : (b0 & 0xfc);
    return [b0, b1, b2, b3, b4, (hashInt(seed + "y") >>> 16) & 255].map(v => v.toString(16).padStart(2, "0")).join(":");
  };
  const mk = (ssid, band, ch, rssi, sec, nCl, oui, vendor, extra) => {
    const bssid = macFrom(oui, ssid + "|" + band, false);
    const clients = Array.from({ length: nCl }, (_, j) => ({ mac: macFrom(null, ssid + band + j, false), rssi: rssi - 6 - (j * 3) - (hash(ssid + j) * 10 | 0) }));
    const ap = { ssid, bssid, band, channel: ch, rssi, security: sec, clients };
    if (vendor) ap.vendor = vendor;
    if (extra) Object.assign(ap, extra);
    return ap;
  };
  const freeOui = [["3c:22:fb", "Vendor G"], ["8c:f5:a3", "Vendor H"], ["24:6f:28", "Vendor I"], ["dc:a6:32", "Vendor J"]];   // neutral placeholder vendor names
  const unassociated = [];
  for (let i = 0; i < 16; i++) {
    const randomized = i === 4 || i === 9 || i === 14;
    const rssi = -58 - Math.round(hash("probe" + i) * 30);
    const c = { mac: randomized ? macFrom(null, "probe" + i, true) : macFrom(freeOui[i % 4][0], "probe" + i, false) };
    if (!(i === 6 || i === 12)) c.rssi = rssi;          // two without rssi (path "n/a")
    if (!randomized) c.vendor = freeOui[i % 4][1];
    unassociated.push(c);
  }
  const GEN = 1789300000;   // the demo is dated (same reference as the fixtures) and its APs span every freshness tier of D1
  const demoAges = [4, 12, 45, 130, 70, 240, 320, 520, 760, 1400, 20];   // seconds before `generated`, per AP in the list below
  const doc = {
    generated: GEN,
    center: { label: "YOU ARE HERE" },
    source: "demo",
    aps: [
      mk("HomeWiFi", "2.4", 6, -44, "WPA2", 4, "44:4e:6d", "Vendor A", { width: 40, rate: 300, phy: "n" }),
      mk("HomeWiFi", "5", 44, -47, "WPA2", 3, "44:4e:6d", "Vendor A", { width: 80, rate: 866, phy: "ac" }),
      mk("Neighbour-A1", "2.4", 11, -63, "WPA2", 2, "7c:03:ab", "Vendor B"),
      mk("Town-Hotspot", "2.4", 1, -71, "Open", 0, "00:e0:fc", "Vendor C"),
      mk("Hub-4432", "5", 100, -58, "WPA3", 2, "58:97:bd", null, { width: 80, rate: 1201, phy: "ax" }),
      mk("Campus", "5", 36, -66, "WPA2", 1, "24:de:c6", "Vendor D"),
      mk("", "2.4", 3, -55, "WPA2", 1, "b8:27:eb", "Vendor E"),
      mk("MeshNode-Garden", "6", 37, -69, "WPA3", 1, "24:a4:3c", null, { width: 160, rate: 2402, phy: "ax" }),
      mk("GuestNet", "2.4", 9, -78, "Open", 0, "f0:9f:c2", "Vendor F"),
      mk("Legacy-Net", "2.4", 4, -82, "WEP", 0, "9c:3d:cf", null),
      mk("Office-5G", "5", 149, -52, "WPA3", 3, "50:c7:bf", null),
    ],
    unassociated,
  };
  doc.aps.forEach((a, i) => { a.last_seen = GEN - demoAges[i]; });
  doc.activity = [[2412, 0.12], [2422, 0.05], [2427, 0.03], [2437, 0.3], [2452, 0.06], [2462, 0.18], [5180, 0.07], [5220, 0.09], [5500, 0.04], [5745, 0.06]].map(([freq, share]) => ({ freq, share }));
  return doc;
}

