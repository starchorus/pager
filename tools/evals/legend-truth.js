// SPDX-License-Identifier: GPL-3.0-or-later
// tools/evals/legend-truth.js -- legend truth check, covering D1/D5/D6/D7/D8/D10/D17 (spec §9.4, §11.0).
// Run as one --eval on a page with ?debug=1 (THEMES via STARCHORUS._internals); returns "[]" when everything holds.
// It compares, in all three themes: the fixed data-kind list; every painted colour against the token the
// swatch reads through CSS_MIRROR (so an undefined variable shows up as black); the set of tokens per kind
// against the table below, which is derived BY HAND from the draw code in §31-35 -- that is the part that
// makes the check non-tautological, and every change of the canvas marks has to update it; the ring
// width/dash/double against ENCODING; the #leg-arc binding including a negative control on crt.userToggle;
// the D10 visibility rules (a derived row exists exactly while its toggle AND its data allow the mark; the
// randomized row (D8) exactly while such a client is present); and the "Band ?" row (hidden here, visible with
// count 1 after a synthetic STARCHORUS.load of a band-less AP with a locally administered BSSID, P9).
// Ornaments (glow/bloom/halo, star highlight, WarGames bubble ticks) are not part of a swatch, by definition.
(async () => {
  const KINDS = ["band-24","band-5","band-6","band-unknown","client-free","client-assoc","client-random","bubble","sec-open","sec-wep","sec-wpa","sec-wpa2","sec-wpa3","sec-owe","sec-enterprise","sec-wpa3-transition","sec-tkip-weak","sec-unknown","fresh-t0","fresh-t1","fresh-t2","fresh-t3","fresh-undated","hidden","geometry","nebula","groups","devices","merge","probes","arc","crowding","deviation","ghost","id-head","id-friend","id-neutral","id-hostile","selected","pinned","height"];
  const RINGS = {"sec-open":[[1.5,""]],"sec-wep":[[1.5,""]],"sec-wpa":[[1,""]],"sec-wpa2":[[1,""],[1,""]],"sec-wpa3":[[1.5,""]],"sec-owe":[[1,""]],"sec-enterprise":[[1,"5,2"]],"sec-wpa3-transition":[[1.5,""],[1.5,""]],"sec-tkip-weak":[[1,"1,3"]],"sec-unknown":[],"hidden":[[1,"4,4"]]};
  const DERIVED = ["nebula","groups","devices","merge","probes","arc","crowding","deviation","ghost"];
  const want = (t) => { const x = t.render.clientShape === "cross"; return {
    "band-24":["band.2.4.core"],"band-5":["band.5.core"],"band-6":["band.6.core"],"band-unknown":["band.unknown.core"],
    "client-free": x ? ["render.clientCore"] : ["render.clientCore","surface.base"],
    "client-assoc": x ? ["band.2.4.core","render.clientCore"] : ["band.2.4.core","render.clientCore","surface.base"],
    "client-random": ["render.clientCore"],
    "bubble":["render.bubbleFill","render.bubbleStroke"],
    "sec-open": t.status.alarmAura === "wash" ? ["status.alarm","status.alarmWash"] : ["status.alarm"],
    "sec-wep": t.status.alarmAura === "wash" ? ["status.alarm","status.alarmWash"] : ["status.alarm"],
    "sec-wpa":["status.ringNeutral"],"sec-wpa2":["status.ringNeutral"],
    "sec-wpa3":["status.ringStrong"],"sec-owe":["status.ringNeutral"],"sec-enterprise":["status.ringNeutral"],"sec-wpa3-transition":["status.ringStrong"],"sec-tkip-weak":["status.ringNeutral"],"sec-unknown":["ink.muted"],"hidden":["status.hidden"],
    "fresh-t0":["ink.secondary"],"fresh-t1":["ink.secondary"],"fresh-t2":["ink.secondary"],"fresh-t3":["ink.secondary"],"fresh-undated":["ink.secondary"],
    "nebula":["ink.muted"],"groups":["ink.muted"],"devices":["ink.muted"],"merge":["ink.muted"],"probes":["ink.muted"],"arc":["ink.muted"],"crowding":["ink.muted"],"deviation":["ink.muted"],"ghost":["ink.muted"],
    "id-friend":["ink.primary"],"id-neutral":["ink.primary"],"id-hostile":["ink.primary"],   // D7: the canvas frame form is drawn in ink.primary in every theme
    "selected":["accent.selection"],"pinned":["ink.secondary"] }; };
  const T = STARCHORUS._internals.THEMES, bad = [], TH = ["foundation","wargames","whitehall"];
  for (const th of TH) {
    STARCHORUS.setTheme(th); await STARCHORUS.wait(50);
    const t = T[th], w = want(t), rows = STARCHORUS.legendRows(), kinds = rows.map(r => r.kind);
    if (new Set(kinds).size !== kinds.length) bad.push(th + ": duplicate kind");
    if (kinds.length !== KINDS.length) bad.push(th + ": " + kinds.length + " rows != " + KINDS.length);
    for (const r of rows) {
      if (!KINDS.includes(r.kind)) { bad.push(th + ": kind " + r.kind); continue; }
      for (const p of r.paints) if (p.tok == null || p.css == null || p.css !== p.val) bad.push(th + ":" + r.kind + ":" + p.prop + " " + p.raw + " css " + p.css + " != " + p.tok + " " + p.val);
      const got = [...new Set(r.paints.map(p => p.tok))].sort().join(" "), exp = (w[r.kind] || []).slice().sort().join(" ");
      if (got !== exp) bad.push(th + ":" + r.kind + ": tokens [" + got + "] != [" + exp + "]");
      if (RINGS[r.kind]) { const g = JSON.stringify(r.rings.map(x => [x.w, x.dash.join(",")])), e = JSON.stringify(RINGS[r.kind]); if (g !== e) bad.push(th + ":" + r.kind + ": rings " + g + " != " + e); }
    }
    const by = (k) => rows.find(r => r.kind === k) || {};
    const st = STARCHORUS.stats(), tg = STARCHORUS.getToggles();
    if (!!by("arc").visible !== !!(t.render.probeArc && t.line.edge.style === "parabola")) bad.push(th + ": arc visibility");
    if (by("band-unknown").visible) bad.push(th + ": Band ? visible without unknown-band star");
    // D10: a row exists exactly while the mark can be drawn (toggle AND data)
    const rule = { nebula: tg.nebula && st.interferencePairs > 0, groups: tg.groups && st.groups > 0, devices: tg.deviceLinks && st.devices > 0, merge: tg.essMerge && st.essMerged > 0,
      probes: tg.affinity && st.affinity > 0, crowding: st.apsTotal > 0, deviation: st.deviations > 0, ghost: st.baseline.ghosts + (st.baseline.ghostsCl || 0) > 0, height: tg.view === "3d", "client-random": STARCHORUS.legendRows().length > 0 && !!by("client-random").visible === true };
    for (const k of Object.keys(rule)) if (k !== "client-random" && !!by(k).visible !== !!rule[k]) bad.push(th + ": " + k + " visible " + !!by(k).visible + " != " + !!rule[k]);
    if (!by("client-random").visible) bad.push(th + ": randomized row hidden although the fixture has randomized clients");
    if (by("client-random").cnt == null || by("client-random").cnt < 1) bad.push(th + ": randomized count " + by("client-random").cnt);
    if (!by("geometry").visible) bad.push(th + ": geometry line hidden");
    for (const k of DERIVED) { const r = by(k); if (r.visible && !r.paints.length) bad.push(th + ": derived row " + k + " without hatch swatch"); }
  }
  const u = T.wargames.crt.userToggle; T.wargames.crt.userToggle = false; STARCHORUS.setTheme("wargames");   // negative control: CRT toggle is not the arc key
  if (document.getElementById("leg-arc").hidden) bad.push("arc follows crt.userToggle"); T.wargames.crt.userToggle = u;
  STARCHORUS.load({ aps: [{ bssid: "02:00:00:00:00:01", ssid: "lab-noband", rssi: -52, security: "WPA2" }, { bssid: "02:00:00:00:00:02", ssid: "lab-24", rssi: -61, channel: 6, security: "WPA2" }] }, "legend-probe");
  for (const th of TH) { STARCHORUS.setTheme(th); const r = STARCHORUS.legendRows().find(r => r.kind === "band-unknown"); if (!r || !r.visible || r.cnt !== 1) bad.push(th + ": Band ? row " + JSON.stringify(r && { v: r.visible, c: r.cnt })); const q = STARCHORUS.legendRows().find(r => r.kind === "client-random"); if (q && q.visible) bad.push(th + ": randomized row visible without a randomized client"); }
  STARCHORUS.setTheme("foundation");
  return JSON.stringify(bad);
})()
