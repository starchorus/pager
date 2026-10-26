// ==== 22 UTIL ====
function hashInt(str) {
  let h = 2166136261 >>> 0; str = String(str);
  for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
function hash(str) { return hashInt(str) / 4294967296; }
function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const clamp = (v, lo, hi) => v < lo ? lo : v > hi ? hi : v;
const cmpStr = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const lerp = (a, b, t) => a + (b - a) * t;
function smoothstep(e0, e1, x) { const t = clamp((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t); }
function ease(cur, tgt, k, dt) {
  if (Math.abs(cur - tgt) < 1e-6) return tgt;
  return tgt + (cur - tgt) * Math.exp(-k * dt);
}
const easeBy = (cur, tgt, e) => Math.abs(cur - tgt) < 1e-6 ? tgt : tgt + (cur - tgt) * e;   // ease() with e = Math.exp(-k * dt) hoisted out of a per-node loop
// Math.hypot(x, y) for the per-pair and per-node loops without the builtin's call, which boxes both arguments and allocates a scratch array and the result
// (~15 MB of garbage per poll of a big feed). V8 scales both magnitudes by the larger one m, adds the squares (the larger scales to exactly 1, and the
// compensation term of its sum is exactly 0 for two terms) and scales the root back by m: the same operations here, hence the same bits.
// WebKit and Gecko call a libm hypot that rounds differently for a third of all pairs, enough to regroup a dense field. HYP_SCALED is false there
// (on its pairs the scaled form is off by more than 1 ulp, libm by less) and every call takes the builtin, as do zero, NaN and Infinity.
const HYP_SCALED = [[1, 6], [5, 6], [9, 232], [139, 212]].every(([a, b]) => Math.hypot(a, b) === Math.sqrt(1 + (a / b) * (a / b)) * b);
function hyp(x, y) {
  const ax = Math.abs(x), ay = Math.abs(y), m = ax > ay ? ax : ay;
  if (!(HYP_SCALED && m > 0 && m < Infinity) || ax !== ax) return Math.hypot(x, y);
  const q = (ax > ay ? ay : ax) / m;
  return Math.sqrt(1 + q * q) * m;
}
function wrapPi(a) { a = (a + Math.PI) % (2 * Math.PI); if (a < 0) a += 2 * Math.PI; return a - Math.PI; }
function easeAngle(cur, tgt, k, dt) {
  const d = wrapPi(tgt - cur);
  if (Math.abs(d) < 1e-6) return tgt;
  return cur + d * (1 - Math.exp(-k * dt));
}
const easeInOutCubic = (u) => u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2;
const easeOutQuad = (u) => 1 - (1 - u) * (1 - u);
const easeOutCubic = (u) => 1 - Math.pow(1 - u, 3);
const easeInCubic = (u) => u * u * u;
const rssiT = (dbm) => clamp((dbm - LAYOUT.rssiMin) / (LAYOUT.rssiMax - LAYOUT.rssiMin), 0, 1);
// D9: four signal levels, bounded by the rings; percent = round(100·rssiT); the level WORD is a copy token (theme voice).
function signalLevel(dbm) { let l = 0; for (const r of LAYOUT.rings) if (dbm < r) l++; return l; }   // 0 = strongest
const signalPct = (dbm) => Math.round(100 * rssiT(dbm));

const esc = (s) => String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const fmtMac = (m) => String(m).toLowerCase();
function fmtAge(sec) {
  if (sec == null || !Number.isFinite(sec)) return "—";
  if (sec < 0) sec = 0;
  if (sec < 90) return Math.round(sec) + " s ago";
  if (sec < 5400) return Math.round(sec / 60) + " min ago";
  return Math.round(sec / 3600) + " h ago";
}
const query = (() => {
  const q = {};
  try { new URLSearchParams(location.search).forEach((v, k) => { q[k] = v; }); } catch (e) { /* no query */ }
  q.intro0 = q.intro === "0"; q.poll0 = q.poll === "0"; q.demo1 = q.demo === "1"; q.rm1 = q.rm === "1"; q.debug1 = q.debug === "1";
  return q;
})();
const storageState = { failed: false };
const storageTry = (fn, failed) => { try { if (query.storage === "fail") throw new Error("storage disabled"); return fn(); } catch (e) { storageState.failed = true; return failed; } };   // ?storage=fail: a browser that refuses storage
const safeStorage = {
  get: (key) => storageTry(() => localStorage.getItem(key), null),
  set: (key, val) => storageTry(() => { localStorage.setItem(key, val); return true; }, false),
  remove: (key) => storageTry(() => { localStorage.removeItem(key); return true; }, false),
};
function sessionFlag(name, set) {
  try {
    if (set === undefined) return sessionStorage.getItem("starchorus." + name) === "1";
    sessionStorage.setItem("starchorus." + name, set ? "1" : "0"); return !!set;
  } catch (e) { return false; }
}
const r3 = (v) => (typeof v === "number" && Number.isFinite(v)) ? Math.round(v * 1000) / 1000 : v;
let stripN = 0;   // what the last stripCtl removed (the name's hid mark)
function stripCtl(x, max) { if (x == null) return ""; const t = String(x).replace(/[\x00-\x1f\x7f-\x9f\u200b-\u200f\u202a-\u202e\u2060-\u2069\ufeff]/g, ""); stripN = String(x).length - t.length; return t.slice(0, max); }
const plu = (n, w) => `${n} ${w}${n - 1 ? "s" : ""}`;
function numOrNull(x) { if (x === null || x === undefined || x === "" || typeof x === "boolean") return null; const v = +x; return Number.isFinite(v) ? v : null; }
const isObj = (x) => !!x && typeof x === "object" && !Array.isArray(x);

