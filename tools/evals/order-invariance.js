// SPDX-License-Identifier: GPL-3.0-or-later
// tools/evals/order-invariance.js -- the Chrome side of the input-order check (driver tools/regress.d/order-invariance.sh).
// A function expression like ingest-fuzz.js: the driver appends the argument, "run" or "mixer" ("mixer" only shuffles and counts, no
// document is loaded: the driver's proof that a mixer that does not mix is caught). The bundle is fetched from "starchorus.json?bundle=order".
// The bundle is {order: {NAME: DOC}}: the fixtures, as they are. Needs ?debug=1 (STARCHORUS._internals.S) and ?fixed=... (clock frozen).
// Per fixture: load the document as it is (twice: the reference must be reproducible), then SEEDS times with aps[], every
// aps[].clients[] and unassociated[] shuffled by a Fisher-Yates over a fixed-seed LCG (seed k, k = 1..SEEDS; lists shorter
// than MINN are left alone and counted as skipped). After each load: settle(), frame(); the canonical digest is the string of
// nodes() sorted by id (id, kind, sx, sy to 0.1 px) plus the 10 geometric fields of layoutInfo() plus the data counters of stats() (CNT). NOT in the digest: settled/iterations
// (settled must be equal too, as a finding of its own; iterations may depend on the order and are only reported) and
// labelsDrawn/labelCollisions (render-dependent).
// WHY the state is emptied before each load: the page keeps its Maps (S.aps, S.clients, S.hist) across load(); a node that is
// already there keeps its place in the Map, so a second document with the same nodes in another order would reach the layout in
// the FIRST order and the check would compare a state with itself (the "placebo" of the brief). Emptying them makes every run
// what a fresh page would do with that document; the sort in the source is then the only thing between the order and the layout.
// The return value is a JSON string {ms, seeds, minn, fixtures:[{name, lists:[{l, n, checked, moved}], runs, iter:[..], settled:[..]}],
// mixer:{lists, ok, bad:[..]}, findings:[[name, why]...]}; no findings = every permutation gave the reference digest.
(async (MODE) => {
  const W = window.STARCHORUS, S = W._internals && W._internals.S;
  const T0 = performance.now();
  if (!S) return JSON.stringify({ findings: [["setup", "STARCHORUS._internals missing: run with ?debug=1"]] });
  const B = await (await fetch("starchorus.json?bundle=order", { cache: "no-store" })).json();
  const SEEDS = 10, MINN = 5;
  const GEO = ["minClientDistancePx", "p5ClientDistancePx", "medianClientDistancePx", "overlapsPx", "clientsInStarZone", "clientsInApHalo", "freeInOrbitZone", "apMinGapPx", "apRadiusErrPx", "clusterCount"];
  // the data counters of stats() that must not depend on the order either (measured equal in the first run; a key that is missing is a finding)
  const CNT = ["aps", "apsTotal", "clients", "free", "assoc", "groups", "bands", "bandsTotal", "security", "devices", "essMerged", "alarms", "hidden", "identities"];
  const clone = (o) => JSON.parse(JSON.stringify(o));
  const lcg = (seed) => { let x = seed >>> 0; return () => { x = (Math.imul(x, 1664525) + 1013904223) >>> 0; return x / 4294967296; }; };
  const shuffle = (a, rnd) => { const b = a.slice(); for (let i = b.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); const t = b[i]; b[i] = b[j]; b[j] = t; } return b; };
  const key = (o) => JSON.stringify(o);
  // the seed k of run k: spread over the 32 bits (small seeds 1..10 would give near-identical first draws)
  const seedOf = (k) => Math.imul(k, 2654435761) >>> 0;
  // one permuted copy of a document; lists[] tells for every list (name, n) whether it was shuffled and whether it moved
  const permute = (doc, k) => {
    const d = clone(doc), rnd = lcg(seedOf(k)), lists = [];
    const one = (name, arr, set) => {
      const n = arr.length;
      if (n < MINN) { lists.push({ l: name, n, checked: false, moved: false, same: true }); return; }
      const b = shuffle(arr, rnd);
      const moved = b.some((x, i) => key(x) !== key(arr[i]));
      const same = key(b.map(key).sort()) === key(arr.map(key).sort());
      set(b); lists.push({ l: name, n, checked: true, moved, same });
    };
    one("aps", d.aps, (b) => { d.aps = b; });
    for (const a of d.aps) one("aps[" + a.bssid + "].clients", a.clients, (b) => { a.clients = b; });
    one("unassociated", d.unassociated, (b) => { d.unassociated = b; });
    return { d, lists };
  };
  const r1 = (v) => { const x = Math.round(v * 10) / 10; return x === 0 ? 0 : x; };   // no "-0"
  const run = (doc) => {
    S.aps.clear(); S.clients.clear(); S.hist.clear(); S.errors.length = 0;
    const res = W.load(doc, "order");
    W.settle(); W.frame();
    const ns = W.nodes().map((n) => [n.id, n.kind, r1(n.sx), r1(n.sy)]).sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));
    const L = W.layoutInfo(), st = W.stats() || {};
    const cn = CNT.map((k) => (k in st ? st[k] : "MISSING:" + k));
    return { ok: !!(res && res.ok), digest: key([ns, GEO.map((k) => L[k]), cn]), n: ns.length, settled: L.settled, iterations: L.iterations, err: S.errors.length ? String(S.errors[0]) : "" };
  };
  const findings = [], fixtures = [];
  const mixBad = [], mix = { lists: 0, ok: 0 };
  const add = (n, why) => { if (findings.length < 40) findings.push([n, String(why).slice(0, 200)]); };
  for (const name of Object.keys(B.order)) {
    const doc = B.order[name], fx = { name, lists: [], runs: 0, iter: [], settled: [] };
    let a = null;
    if (MODE === "run") {
      a = run(clone(doc)); const a2 = run(clone(doc));
      if (!a.ok || a.err) add(name, "reference load failed: " + (a.err || "not ok"));
      if (a.digest !== a2.digest) add(name, "the reference is not reproducible (two loads of the same document differ)");
      fx.n = a.n; fx.iter.push(a.iterations); fx.settled.push(a.settled);
    }
    const moved = {}, seen = {};
    for (let k = 1; k <= SEEDS; k++) {
      const { d, lists } = permute(doc, k);
      for (const l of lists) { seen[l.l] = l; if (l.checked) { moved[l.l] = (moved[l.l] || 0) + (l.moved ? 1 : 0); if (!l.same) add(name, "the shuffle of " + l.l + " lost or invented an entry"); } }
      fx.runs++;
      if (MODE !== "run") continue;
      const r = run(d); fx.iter.push(r.iterations); fx.settled.push(r.settled);
      if (!r.ok || r.err) add(name + "#" + k, "load failed: " + (r.err || "not ok"));
      else if (r.settled !== a.settled) add(name + "#seed" + k, "settled " + a.settled + " vs " + r.settled);
      else if (r.digest !== a.digest) {
        const x = JSON.parse(a.digest), y = JSON.parse(r.digest); let why = "digest differs";
        for (let i = 0; i < x[0].length && i < y[0].length; i++) if (key(x[0][i]) !== key(y[0][i])) { why = "node " + x[0][i][0] + ": " + key(x[0][i].slice(2)) + " vs " + key(y[0][i].slice(2)); break; }
        if (why === "digest differs" && key(x[1]) !== key(y[1])) why = "layoutInfo " + key(x[1]) + " vs " + key(y[1]);
        if (why === "digest differs" && key(x[2]) !== key(y[2])) why = "stats " + key(x[2]) + " vs " + key(y[2]);
        if (x[0].length !== y[0].length) why = "node count " + x[0].length + " vs " + y[0].length;
        add(name + "#seed" + k, why);
      }
    }
    for (const l of Object.keys(seen)) {
      fx.lists.push({ l, n: seen[l].n, checked: seen[l].checked, moved: moved[l] || 0 });
      if (seen[l].checked) { mix.lists++; if ((moved[l] || 0) >= SEEDS - 1) mix.ok++; else mixBad.push(name + ":" + l + " moved " + (moved[l] || 0) + "/" + SEEDS); }
    }
    fixtures.push(fx);
  }
  return JSON.stringify({ ms: Math.round(performance.now() - T0), seeds: SEEDS, minn: MINN, fixtures, mixer: { lists: mix.lists, ok: mix.ok, bad: mixBad.slice(0, 10) }, findings });
})
