// SPDX-License-Identifier: GPL-3.0-or-later
// tools/evals/data-oracle.js -- the Chrome side of the data oracle (driver tools/regress.d/data-oracle.sh, judge
// tools/data-oracle.py). A function expression like order-invariance.js: the driver appends the argument ("run"). It only OBSERVES:
// it reads what the page reports and hands it over; every expected value is computed on the other side, by the model in Python.
// The bundle is fetched from "starchorus.json?bundle=oracle" and is {oracle: {NAME: DOC}} (the fixtures as they are + the hand documents).
// Needs ?debug=1 (STARCHORUS._internals.S) and ?fixed=... (clock frozen). Per document and per essMerge mode (off, on): the page state is
// emptied (a second document would otherwise meet the nodes of the first), STARCHORUS.load(DOC), settle(), then read stats() (the
// counters the model knows), devices(), essClusters(), the AP node ids and deviceOf(id) for every AP. essMerge is restored to off.
// The return value is a JSON string {ms, fixtures:[{name, modes:{off:{err,stats,devices,ess,apIds,deviceOf}, on:{...}}}], findings:[[name, why]]}.
(async (MODE) => {
  const W = window.STARCHORUS, S = W._internals && W._internals.S;
  const T0 = performance.now();
  if (!S) return JSON.stringify({ findings: [["setup", "STARCHORUS._internals missing: run with ?debug=1"]] });
  const B = await (await fetch("starchorus.json?bundle=oracle", { cache: "no-store" })).json();
  const KEYS = ["apsTotal", "aps", "clients", "free", "assoc", "groups", "bands", "bandsTotal", "security", "alarms", "hidden", "devices", "essMerged"];
  const clone = (o) => JSON.parse(JSON.stringify(o));
  const findings = [], fixtures = [];
  for (const name of Object.keys(B.oracle)) {
    const fx = { name, modes: {} };
    for (const mode of ["off", "on"]) {
      W.setToggles({ essMerge: mode === "on" });
      S.aps.clear(); S.clients.clear(); S.hist.clear(); S.errors.length = 0;
      const res = W.load(clone(B.oracle[name]), "oracle");
      W.settle();
      if (!res || !res.ok || S.errors.length) { fx.modes[mode] = { err: (res && res.error) || (S.errors.length ? String(S.errors[0]) : "load not ok") }; continue; }
      const st = W.stats() || {}, stats = {};
      for (const k of KEYS) stats[k] = k in st ? st[k] : "MISSING";
      const apIds = W.nodes("ap").map((n) => n.id).sort();
      const deviceOf = {};
      for (const id of apIds) { const d = W.deviceOf(id); deviceOf[id] = d ? d.id : null; }
      fx.modes[mode] = {
        stats,
        devices: (W.devices() || []).map((d) => ({ id: d.id, members: d.members.slice() })),
        ess: (W.essClusters() || []).map((e) => ({ ssid: e.ssid, id: e.id, deviceIds: e.deviceIds.slice(), apCount: e.apCount, expanded: e.expanded })),
        apIds, deviceOf,
      };
    }
    fixtures.push(fx);
  }
  W.setToggles({ essMerge: false });
  return JSON.stringify({ ms: Math.round(performance.now() - T0), fixtures, findings });
})
