// SPDX-License-Identifier: GPL-3.0-or-later
// tools/evals/ingest-fuzz.js -- the Chrome side of the ingest fuzz (driver tools/regress.d/ingest-fuzz.sh).
// A function expression: the driver appends the argument, "main" or "big" ("main" runs every mutant of the bundle in 2D and again
// in 3D, then the paste/drop/label sinks; "big" runs the class-7 documents alone, so that a hang only hits that class).
// Needs ?debug=1 (STARCHORUS._internals.S.errors is emptied per mutant, so an error is attributed to ITS mutant; the 50-entry cap of
// errors() would otherwise hide everything after the fiftieth) and a served starchorus.json that is the tools/fuzz-doc.py bundle.
// Per mutant: STARCHORUS.load() (never throws: {ok:false} for a rejected document, {error} only for a caught exception); a rejected
// document leaves the display alone (stats() before == after); settle(), frame(); no error entered errors() (also one that only
// fires in the next frame); every number of stats()/layoutInfo() and every sx/sy of nodes() is finite; loading the same mutant
// twice gives the same counters; loading the good carrier afterwards gives the good counters again (garbage does not poison the
// world); and no prototype was polluted. SSID sinks (tooltip, detail panel, #source-desc, legend, chanbar tip): each driven for
// each mutant, the panels must hold no img/script/iframe/on* element and window.__x stays undefined; for the "all text" mutants
// (a=1) the masked text (&lt;) must also be FOUND in the panel, so the check cannot pass on an empty panel.
// The return value is a JSON string {n, classes, findings:[[mutant, why]...], ms, sinks:{...}}; [] findings = all true.
(async (MODE) => {
  const W = window.STARCHORUS, S = W._internals && W._internals.S;
  const T0 = performance.now();
  if (!S) return JSON.stringify({ findings: [["setup", "STARCHORUS._internals missing: run with ?debug=1"]] });
  const B = await (await fetch("starchorus.json?bundle=" + MODE, { cache: "no-store" })).json();
  const FZ = B.fuzz, GOOD = JSON.parse(JSON.stringify(B)); delete GOOD.fuzz;
  const FIXED = +new URLSearchParams(location.search).get("fixed");
  const findings = [], counts = {}, sinks = { tip: 0, detail: 0, source: 0, legend: 0, chan: 0, paste: 0, drop: 0, anchors: 0 };
  // at most 8 per kind of finding (its first 12 characters), so that one systematic fault cannot crowd the others out of the list
  const kinds = {};
  const add = (n, why) => { const k = String(why).slice(0, 12); kinds[k] = (kinds[k] || 0) + 1; if (findings.length < 60 && kinds[k] <= 8) findings.push([n, String(why).slice(0, 200)]); };
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  const clearErr = () => { S.errors.length = 0; delete window.__x; };   // __x is re-armed per mutant, so a hit names ITS mutant
  const isNum = (v) => typeof v === "number";
  const bad = (o, p, out) => { if (isNum(o)) { if (!Number.isFinite(o)) out.push(p); } else if (o && typeof o === "object") for (const k of Object.keys(o)) bad(o[k], p + "." + k, out); return out; };
  // the data counters that must not depend on time, layout or the machine (measured in the first run); a missing key is a finding
  const KEYS = ["aps", "apsTotal", "clients", "free", "assoc", "groups", "bands", "bandsTotal", "security", "sourceKind", "sourceLabel", "devices", "essMerged", "alarms", "hidden", "affinity", "identities", "mode"];
  const sub = () => { const s = W.stats(); if (!s || s.error) return "ERR:" + (s && s.error); return JSON.stringify(KEYS.map((k) => (k in s ? s[k] : "MISSING:" + k))); };
  const proto = () => Object.getOwnPropertyNames(Object.prototype).sort().join() + "|" + ({}).polluted + "|" + ({}).x;
  const P0 = proto();
  const DANGER = ["IMG", "SCRIPT", "IFRAME", "OBJECT", "EMBED", "LINK", "META", "STYLE", "FRAME", "BASE"];
  const PANELS = ["#tip", "#detail", "#source-desc", "#legend", "#chan-tip", "#paste-wrap", "#intro"];
  const panelBad = () => {
    const o = [];
    for (const sel of PANELS) { const c = document.querySelector(sel); if (!c) { o.push(sel + " missing"); continue; }
      for (const e of c.querySelectorAll("*")) { if (DANGER.includes(e.tagName)) o.push(sel + " has <" + e.tagName.toLowerCase() + ">"); for (const a of e.attributes) if (/^on/i.test(a.name)) o.push(sel + " has " + a.name); } }
    if (window.__x !== undefined) o.push("window.__x is set: script ran");
    return o;
  };
  const html = (sel) => (document.querySelector(sel) || { innerHTML: "" }).innerHTML;
  const cnt = (c) => { counts[c] = (counts[c] || 0) + 1; };

  // ---- the sinks of one loaded document. anchor: the document is an "all text fields hostile" one
  const drive = (m) => {
    const hs = m.h;   // the hostile text this mutant carries (only known for the anchor mutants), "" otherwise
    const masked = hs && hs.indexOf("<") >= 0;
    const aps = W.nodes("ap"), cls = W.nodes("client");
    const need = (cond, what) => { if (!cond) add(m.n, "anchor: " + what); else sinks.anchors++; };
    if (aps.length) {
      const id = aps[0].id;
      W.hoverNode(id); sinks.tip++;
      const t = html("#tip-body"); if (m.a && masked) need(t.indexOf("&lt;") >= 0 && t.indexOf(hs) < 0, "AP tooltip holds masked text and not the raw one");
      W.hoverNode(null);
      W.select(id); sinks.detail++;
      const d = html("#detail-body"); if (m.a && masked) need(d.indexOf("&lt;") >= 0 && d.indexOf(hs) < 0, "AP detail holds masked text and not the raw one");
      W.deselect();
      const ap = W.node(id);
      if (ap && ap.band && ap.channel != null) { const tx = W.hoverChannel(ap.band, ap.channel); sinks.chan++; if (tx != null && typeof tx !== "string") add(m.n, "hoverChannel returned " + typeof tx); if (document.querySelectorAll("#chan-tip *").length) add(m.n, "chanbar tip holds elements"); }
    }
    if (cls.length) {
      const id = cls[0].id;
      W.hoverNode(id); sinks.tip++;
      const t = html("#tip-body"); if (m.a && masked) need(t.indexOf("&lt;") >= 0 && t.indexOf(hs) < 0, "client tooltip holds masked text and not the raw one");
      W.hoverNode(null);
      W.select(id); sinks.detail++;
      const d = html("#detail-body"); if (m.a && masked) need(d.indexOf("&lt;") >= 0 && d.indexOf(hs) < 0, "client detail holds masked text and not the raw one");
      W.deselect();
    }
    for (const b of W.nodes("bubble")) { W.select(b.id); sinks.detail++; W.hover(b.sx, b.sy); sinks.tip++; W.deselect(); break; }
    if (m.a && m.d && m.d.source === "none") { const sd = html("#source-desc"); sinks.source++; if (masked) need(sd.indexOf("&lt;") >= 0 && sd.indexOf(hs) < 0, "#source-desc holds the note masked and not raw"); }
    for (const p of panelBad()) add(m.n, p);
  };

  const step = async (m, view, extra) => {
    clearErr(); if (view === "2d") cnt(m.c);
    const pre = sub(), preN = W.nodes().length;
    const res = W.load(m.d, "fuzz");
    if (!res || typeof res !== "object") { add(m.n, "load returned " + typeof res); return; }
    const rej = res.ok === false;
    if (res.error && !rej) { add(m.n, "load threw: " + res.error); return; }
    if (rej) { const post = sub(); if (post !== pre) add(m.n, "rejected document changed the display: " + pre.slice(0, 60) + " -> " + post.slice(0, 60)); if (W.nodes().length !== preN) add(m.n, "rejected document changed the node list"); }
    W.settle(); W.frame();
    if (!rej) {
      const s1 = sub();
      for (const p of bad(W.stats(), "stats", [])) add(m.n, "non-finite " + p);
      for (const p of bad(W.layoutInfo(), "layoutInfo", [])) add(m.n, "non-finite " + p);
      for (const n of W.nodes()) if (!Number.isFinite(n.sx) || !Number.isFinite(n.sy)) { add(m.n, "non-finite sx/sy of " + String(n.id).slice(0, 30)); break; }
      if (s1.indexOf("MISSING:") >= 0 || s1.indexOf("ERR:") === 0) add(m.n, "stats() lost a counter: " + s1.slice(0, 80));
      if (extra) {
        W.load(m.d, "fuzz"); W.settle(); W.frame();
        const s2 = sub(); if (s2 !== s1) add(m.n, "the second load of the same document differs: " + s1.slice(0, 50) + " vs " + s2.slice(0, 50));
        drive(m);
      }
    }
    await wait(view === "2d" ? 25 : 0);   // an error or handler that only fires in a later task still lands on this mutant
    const er = S.errors.slice(); if (er.length) add(m.n, "errors(): " + er[0]);
    if (window.__x !== undefined) add(m.n, "window.__x set after the wait");
    if (extra) { W.load(GOOD, "fuzz"); W.settle(); const back = sub(); if (back !== GOOD_SUB) add(m.n, "the good document no longer loads to the same counters after it: " + back.slice(0, 60)); }
    if (proto() !== P0) add(m.n, "Object.prototype changed");
    clearErr();
  };
  const toView = async (v) => {
    W.setFixedTime(null); W.setView(v);
    const want = v === "3d" ? 1 : 0, t = performance.now();
    while (Math.abs(W.getView().blend - want) > 0.001 && performance.now() - t < 8000) await wait(50);
    W.setFixedTime(Number.isFinite(FIXED) ? FIXED : null); W.frame();
    return W.getView().blend;
  };

  W.load(GOOD, "fuzz"); W.settle(); W.frame();
  const GOOD_SUB = sub();
  if (S.errors.length) add("boot", "errors() before the first mutant: " + S.errors[0]);   // a page that does not boot cleanly makes every later finding unfair
  clearErr();
  if (MODE === "main") {
    // the hostile text an anchor mutant carries is read back from the document: the SSID of its first AP, or its note (source none)
    for (const m of FZ.mutants) m.h = !m.a || !m.d ? "" : String((Array.isArray(m.d.aps) && m.d.aps[0] && m.d.aps[0].ssid) || m.d.note || "");
    for (const m of FZ.mutants) await step(m, "2d", true);
    const v3 = await toView("3d");
    if (v3 < 0.999) add("3d", "the 3D view did not settle (blend " + v3 + ")");
    for (const m of FZ.mutants) await step(m, "3d", false);
    await toView("2d");
    // ---- sinks that are not fed by a mutant document: the source label (setSourcePanel, sourceHint), the paste dialog, the drop
    const labels = FZ.mutants.filter((m) => m.a).map((m) => m.h).filter((h, i, a) => h && a.indexOf(h) === i);
    for (const hs of labels.concat(["<img src=x onerror=window.__x=1>", "<b>evil</b>"])) {
      clearErr(); W.load(GOOD, hs); sinks.source++;
      const sd = html("#source-desc");
      if (hs.indexOf("<") >= 0) { if (!(sd.indexOf("&lt;") >= 0) || sd.indexOf(hs.slice(0, 80)) >= 0) add("label:" + hs.slice(0, 20), "anchor: #source-desc holds the label masked and not raw"); else sinks.anchors++; }
      for (const p of panelBad()) add("label:" + hs.slice(0, 20), p);
      if (S.errors.length) add("label:" + hs.slice(0, 20), "errors(): " + S.errors[0]);
    }
    // paste dialog (spec 9.9 point 3): invalid JSON, a JSON that is no document, a good one
    const ta = document.getElementById("paste-ta"), pe = document.getElementById("paste-err"), ok = document.getElementById("paste-ok"), wrap = document.getElementById("paste-wrap");
    W.load(GOOD, "fuzz"); W.settle(); const keep = sub();
    document.getElementById("btn-load").click();
    for (const [txt, want] of [["{ not json", /^Invalid JSON/], ['{"aps":"x"}', /^Could not parse/], ["[]", /^Could not parse/], ["null", /^Could not parse/], ['<img src=x onerror=window.__x=1>', /^Invalid JSON/], ['{"aps":[],"__proto__":{"polluted":1}}', null]]) {
      ta.value = txt; pe.textContent = ""; ok.click(); sinks.paste++;
      if (want) { if (!want.test(pe.textContent)) add("paste:" + txt.slice(0, 20), "#paste-err says [" + pe.textContent.slice(0, 40) + "]"); if (wrap.style.display === "none") add("paste:" + txt.slice(0, 20), "the dialog closed on a bad document"); if (sub() !== keep) add("paste:" + txt.slice(0, 20), "a bad paste changed the display"); }
      for (const p of panelBad()) add("paste:" + txt.slice(0, 20), p);
    }
    if (({}).polluted !== undefined) add("paste", "a pasted __proto__ key polluted Object.prototype");
    document.getElementById("paste-cancel").click();
    // drop of an invalid file (spec 9.9 point 4): the name is shown by sourceHint(): escaped, and the previous sky stays
    W.load(GOOD, "fuzz"); W.settle(); const keep2 = sub();
    for (const nm of ["<img src=x onerror=window.__x=1>.json", "<b>evil</b>.json", "a‮b.json"]) {
      const dt = new DataTransfer(); dt.items.add(new File(["{ broken"], nm, { type: "application/json" }));
      window.dispatchEvent(new DragEvent("drop", { dataTransfer: dt, cancelable: true })); sinks.drop++;
      await wait(120);
      const sd = html("#source-desc");
      if (nm.indexOf("<") >= 0) { if (sd.indexOf("Could not read") < 0 || sd.indexOf("&lt;") < 0 || sd.indexOf(nm.slice(0, 20)) >= 0) add("drop:" + nm.slice(0, 20), "anchor: hint masked and present: " + sd.slice(0, 80)); else sinks.anchors++; }
      if (sub() !== keep2) add("drop:" + nm.slice(0, 20), "a bad drop changed the display");
      for (const p of panelBad()) add("drop:" + nm.slice(0, 20), p);
    }
    // legend (static rows, rebuilt on a theme switch): nothing dynamic reaches it, so the anchor is that it is there
    for (const t of ["wargames", "whitehall", "foundation"]) { W.setTheme(t); sinks.legend++; if (html("#legend").indexOf("legrow") < 0) add("legend", "the legend has no rows in " + t); for (const p of panelBad()) add("legend:" + t, p); }
    await wait(500);
    if (window.__x !== undefined) add("end", "window.__x set after 500 ms");
    if (proto() !== P0) add("end", "Object.prototype changed");
    if (S.errors.length) add("end", "errors(): " + S.errors[0]);
  } else {
    for (const m of FZ.big) { const t = performance.now(); await step(m, "2d", false); m.ms = Math.round(performance.now() - t); }
  }
  return JSON.stringify({ mode: MODE, classes: counts, n: Object.values(counts).reduce((a, b) => a + b, 0), findings, sinks, ms: Math.round(performance.now() - T0), big: MODE === "main" ? undefined : FZ.big.map((m) => [m.n, m.ms]) });
})
