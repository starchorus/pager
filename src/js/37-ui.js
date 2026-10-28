// ==== 37 UI ====
const el = (id) => document.getElementById(id);
const legend = el("legend"), statsEl = el("stats"), tip = el("tip"), detail = el("detail"),
  detailTitle = el("detail-title"), detailBody = el("detail-body"), help = el("help"), helpList = el("help-list"),
  pasteWrap = el("paste-wrap"), pasteTa = el("paste-ta"), pasteErr = el("paste-err"),
  sourceDesc = el("source-desc"), srcCenter = el("src-center"), modeChip = el("mode-chip");
// persistent tooltip structure: a body div (innerHTML) + one persistent sparkline canvas (never re-created per hover, §8.1/R44)
tip.innerHTML = '<div id="tip-body"></div><canvas id="tip-spark" width="120" height="28" hidden></canvas>';
const tipBody = el("tip-body"), tipSpark = el("tip-spark"), detailSpark = el("detail-spark"), legendBody = el("legend-body");
let sparkFocus = { id: null, cross: -1 }, detailShown = null;   // detailShown: the node or bubble whose sheet #detail holds (openDetail)
function fmtBand(b) { return b === "unknown" ? "? GHz" : b + " GHz"; }
function heardWord(n) { return n.freshTier == null ? ENCODING.fresh.undated : ENCODING.fresh.words[n.freshTier]; }   // D1 tier word
function freshZero() { return { t0: 0, t1: 0, t2: 0, t3: 0, undated: 0 }; }
function fmtSignal(dbm) {   // D9: "-58 dBm (53 %, good)"; the level word is the theme's voice (copy.signal); null → "n/a"
  if (dbm == null || !Number.isFinite(dbm)) return "n/a";
  return dbm + " dBm (" + signalPct(dbm) + " %, " + THEME.copy.signal[signalLevel(dbm)] + ")";
}
function toggleBand(b) {
  S.ui.filters[b] = !S.ui.filters[b];
  const btn = document.querySelector('[data-band="' + b + '"]'); if (btn) { btn.classList.toggle("on", S.ui.filters[b]); btn.setAttribute("aria-pressed", String(S.ui.filters[b])); }
  if (b === "bt") { updateStats(); S.dirty = true; return; }
  refreshEssLeads(); applyAffinity(); S.nFreeTotal = countFreeLayout();   // a filtered AP hands its ESS lead and its probe orbiters over
  S.layoutDirty = true; settleLayout(LAYOUT.settleSyncIter);
  computeGroupEdges(); securityCounts(); rebuildChannelStats(); rebuildInterference();
  updateStats(); S.dirty = true;   // updateStats() ends in layoutEdges() → drawChannelBar()
}
const THEME_CYCLE = ["foundation", "wargames", "whitehall"];
function nextTheme(id) { const i = THEME_CYCLE.indexOf(id); return THEME_CYCLE[(i + 1) % THEME_CYCLE.length]; }
function toggleTheme() { applyTheme(nextTheme(S.ui.theme), { intro: true }); }
function toggleCrt() { if (THEME.crt.userToggle) setToggle("crt", !S.ui.crt); }
function applyCrt() { const crt = el("crt"); if (crt) crt.classList.toggle("on", THEME.crt.userToggle && S.ui.crt); }
function setToggle(key, on) {
  S.ui[key] = on;
  if (key === "paused") { const b = el("t-pause"); if (b) b.textContent = on ? "Resume" : "Pause"; }
  if (key === "agg") { S.layoutDirty = true; settleLayout(LAYOUT.settleSyncIter); }
  if (key === "crt") applyCrt();
  if (key === "scope") { applyScope(); resize(); }
  if (key === "observations" || key === "inventory") {   // one drawer at a time (see applyDrawer)
    if (on) { dropToggle(key === "observations" ? "inventory" : "observations"); S.homeOpen = false; S.dx = null; }
    applyDrawer();
  }
  if (key === "baselineDiff") { baselineRecompute(); obsCompute(); renderObs(); renderInv(); }
  if (key === "affinity") { if (applyAffinity()) { S.nFreeTotal = countFreeLayout(); S.layoutDirty = true; settleLayout(LAYOUT.settleSyncIter); } }
  syncButton(key, on);
  if (PERSIST_KEYS.indexOf(key) >= 0) { S.queryLocked.delete(key); saveUi(); }
  updateControlsLook(); updateStats(); S.dirty = true;
  return on;
}
const BTN_OF = { labels: "t-labels", orbits: "t-orbits", links: "t-links", paused: "t-pause", agg: "t-agg", vendor: "t-vendor", nebula: "t-nebula", groups: "t-groups", rotate: "t-rotate", spin: "t-spin", crt: "t-crt", deviceLinks: "t-devices", essMerge: "t-merge", affinity: "t-probes", observations: "t-obs", baselineDiff: "t-baseline", inventory: "t-inv", scope: "t-scope" };
function syncPressed(id, on) { const b = el(id); if (b) { b.classList.toggle("on", !!on); b.setAttribute("aria-pressed", String(!!on)); } }
function syncButton(key, on) { syncPressed(BTN_OF[key], on); }
function dropToggle(key) { if (S.ui[key]) { S.ui[key] = false; syncButton(key, false); } }   // flag and button only
function setToggles(o) {
  if (!o || typeof o !== "object") return getToggles();
  for (const key of Object.keys(o)) {
    if (key === "bands") { const bb = o.bands || {}; for (const b of Object.keys(bb)) { if (S.ui.filters[b] !== !!bb[b]) toggleBand(b); } continue; }
    if (key === "help") { toggleHelp(!!o.help); continue; }
    if (key === "panels") { setPanels(!!o.panels); continue; }
    if (key === "random") { setRandomMode(o.random); continue; }
    if (key === "autoLod") { S.ui.autoLod = !!o.autoLod; S.dirty = true; continue; }
    if (key in S.ui && typeof S.ui[key] === "boolean") setToggle(key, !!o[key]);   // switches only
  }
  return getToggles();
}
function getToggles() {   // the BTN_OF keys (in their order), then the rest
  const o = {}; for (const key of Object.keys(BTN_OF)) o[key] = S.ui[key];
  return Object.assign(o, { autoLod: S.ui.autoLod, help: S.ui.help, panels: S.ui.panels, random: S.ui.random, theme: S.ui.theme, view: S.ui.view, bands: { "2.4": S.ui.filters["2.4"], "5": S.ui.filters["5"], "6": S.ui.filters["6"], bt: S.ui.filters.bt } });
}
function updateControlsLook() {
  const tt = el("t-theme"); if (tt) { const lb = THEMES[nextTheme(S.ui.theme)].meta.label; tt.textContent = lb.charAt(0) + lb.slice(1).toLowerCase(); }
  const tv = el("t-view"); if (tv) tv.textContent = S.ui.view === "3d" ? "2D" : "3D";
  const flat = S.ui.view !== "3d"; el("cam").classList.toggle("flat", flat);
  for (const k of ["left", "right", "up", "down"]) { const b = el("cam-" + k); if (b) b.hidden = flat; }   // 2D: only +, − and reset
  el("t-rotate").hidden = flat;   // the auto-rotation is 3D only
  const crtBtn = el("t-crt"); if (crtBtn) crtBtn.hidden = !THEME.crt.userToggle;
  syncRandomButton();
  for (const key of Object.keys(BTN_OF)) syncButton(key, S.ui[key]);
  const agg = el("t-agg"); if (agg) { const forced = aggForced(); agg.classList.toggle("forced", forced && !S.ui.agg); }
  legendVisibility();
  layoutEdges();
}
function skyTitle() {   // the stats-cell tooltip: the theme's voice (copy.skyVoice) over the same theme-free numbers
  const c = S.crowding, sk = skyStatsObj(), bt = ["2.4", "5", "6"].map(b => b + " GHz " + sk.band[b].shown).join(" · ");
  return THEME.copy.skyVoice + " · " + sk.n + " APs · " + bt + " · crowding " + c.level + "/5" + (c.busiest ? " (busiest: " + c.busiest.band + " GHz ch " + c.busiest.channel + ")" : "") +
    (sk.deviations.length ? " · " + sk.deviations.length + " channel deviation" + (sk.deviations.length > 1 ? "s" : "") : "");
}
// ---- inventory drawer: chips (counts and value filters), a sortable table linked to the canvas (screen-reader twin); stations appear as counts only
function invApRows() {
  const f = S.inv.filter, ap = S.apOrder.filter(n => !eventSkip(n) && S.ui.filters[n.band] !== false);
  const pass = (n) => (!f.band || n.band === f.band) && (!f.sec || n.sec === f.sec) && (!f.identity || identityOf(n.id) === f.identity) && (!f.vendor || (n.vendor || "—") === f.vendor);
  return { all: ap, rows: ap.filter(pass) };
}
function invRandomChip() {   // §8.8a
  const s = S._stats || {}; if (!s.randomized) return "";
  return '<span class="chip">' + s.randomized + ' randomised' + (s.clouds ? ' · ' + s.inClouds + ' in ' + s.clouds + (s.clouds === 1 ? ' cloud' : ' clouds') : '') + '</span>';
}
function renderInv() {
  const ib = el("inv-body"); if (!ib || !S.ui.inventory) return;
  const { all, rows } = invApRows(), f = S.inv.filter, key = S.inv.sort, dir = S.inv.dir;
  const val = { ssid: (n) => (aliasOf(n.id) || n.ssidKnown || n.ssid || "").toLowerCase(), bssid: (n) => n.bssid, band: (n) => n.band, ch: (n) => n.channel ?? 999, rssi: rssiOf, sec: (n) => n.sec, heard: (n) => n.freshTier ?? 9 }[key] || ((n) => n.rssi);
  rows.sort((a, b) => cmpStr(val(a), val(b)) * dir || (a.bssid < b.bssid ? -1 : 1));
  const ssids = new Set(all.map(n => n.ssidKnown || n.ssid).filter(Boolean)), chans = new Set(all.map(n => n.band + "/" + n.channel));
  const chips = (title, field, entries) => '<h4>' + title + '</h4><div class="chips">' + entries.concat(f[field] && !entries.some(e => e[0] === f[field]) ? [[f[field], 0]] : []).map(([v, c]) => '<button class="chip' + (f[field] === v ? " on" : "") + '" data-f="' + field + '" data-v="' + esc(v) + '">' + esc(v) + " " + c + "</button>").join("") + "</div>";
  const tally = (fn) => { const m = new Map(); for (const n of all) { const v = fn(n); m.set(v, (m.get(v) || 0) + 1); } return Array.from(m.entries()).sort((a, b) => b[1] - a[1]); };
  let h = '<h4>Inventory</h4><div class="chips"><span class="chip">' + ssids.size + ' SSIDs</span><span class="chip">' + all.length + ' APs</span><span class="chip">' + (S._stats ? S._stats.clients + S._stats.randomHidden : 0) + ' stations (count only)</span>' + invRandomChip() + '<span class="chip">' + chans.size + ' channels</span><span class="chip">' + rows.length + " of " + all.length + " shown</span></div>";
  h += chips("Band", "band", tally(n => n.band)) + chips("Security", "sec", tally(n => n.sec)) + chips("Identity", "identity", tally(n => identityOf(n.id))) + chips("Vendor", "vendor", tally(n => n.vendor || "—").slice(0, 8));
  const th = (k, t) => '<th data-sort="' + k + '">' + t + (key === k ? (dir > 0 ? " ▲" : " ▼") : "") + "</th>";
  h += "<table><thead><tr>" + th("ssid", "SSID") + th("bssid", "BSSID") + th("band", "Band") + th("ch", "Ch") + th("rssi", "dBm") + th("sec", "Security") + th("heard", "Heard") + "</tr></thead><tbody>";
  for (const n of rows.slice(0, INV_ROWS)) h += '<tr data-id="' + esc(n.id) + '"><td>' + esc(aliasOf(n.id) || n.ssidKnown || n.ssid || "(hidden)") + "</td><td>" + esc(n.bssid) + "</td><td>" + esc(fmtBand(n.band)) + "</td><td>" + (n.channel ?? "—") + "</td><td>" + (n.rssi ?? "—") + "</td><td>" + esc(n.sec) + "</td><td>" + esc(heardWord(n)) + "</td></tr>";
  h += "</tbody></table>" + (rows.length > INV_ROWS ? '<div class="obsnote">first ' + INV_ROWS + " rows shown</div>" : "");
  h += '<div class="chips"><button class="chip" id="inv-friend">Friend · ' + rows.length + ' shown</button><button class="chip" id="inv-neutral">Neutral · ' + rows.length + ' shown</button></div>';
  h += '<h4>Library</h4><textarea id="lib-ta" aria-label="Library text" placeholder="aa:bb:cc:dd:ee:ff friend&#10;aa:bb:cc:??:??:?? neutral"></textarea><div class="chips"><button class="chip" id="lib-import">Import</button><button class="chip" id="lib-export">Export</button></div><div class="obsnote" id="lib-msg">One observed key per line (MAC class — an access point or a station), or an OUI rule with ? or * for friend/neutral/suspect. Only observed keys are accepted.</div>';
  const oldTa = el("lib-ta"), oldMsg = el("lib-msg"), keepTa = oldTa ? { v: oldTa.value, m: oldMsg ? oldMsg.textContent : "", f: document.activeElement === oldTa, s: oldTa.selectionStart, e: oldTa.selectionEnd } : null;   // a poll re-renders the drawer: typed text must survive
  ib.innerHTML = h;
  if (keepTa) { const ta2 = el("lib-ta"); ta2.value = keepTa.v; el("lib-msg").textContent = keepTa.m; if (keepTa.f) { ta2.focus(); try { ta2.setSelectionRange(keepTa.s, keepTa.e); } catch (e) { /* not selectable */ } } }
  for (const b of ib.querySelectorAll(".chip[data-f]")) b.addEventListener("click", () => { const fl = S.inv.filter, k = b.getAttribute("data-f"), v = b.getAttribute("data-v"); if (fl[k] === v) delete fl[k]; else fl[k] = v; renderInv(); });
  for (const t of ib.querySelectorAll("th[data-sort]")) t.addEventListener("click", () => { const k = t.getAttribute("data-sort"); if (S.inv.sort === k) S.inv.dir = -S.inv.dir; else { S.inv.sort = k; S.inv.dir = 1; } renderInv(); });
  for (const r of ib.querySelectorAll("tr[data-id]")) r.addEventListener("click", () => { const id = r.getAttribute("data-id"); S.pinned.add(id); select(id); });
  for (const [bid, cls] of [["inv-friend", "friend"], ["inv-neutral", "neutral"]]) { const b = el(bid); if (b) b.addEventListener("click", () => { libraryAssign(cls, { ids: rows.map(n => n.id) }); }); }   // bulk assign (never suspect, P7)
  const ta = el("lib-ta"), msg = el("lib-msg");
  if (ta) ta.addEventListener("keydown", (e) => e.stopPropagation());
  const li = el("lib-import"), le = el("lib-export");
  if (li) li.addEventListener("click", () => { const r = libraryImport(ta.value); el("lib-msg").textContent = r.added + " set, " + r.rules + " rule(s)" + (r.message ? " · " + r.message : ""); });
  if (le) le.addEventListener("click", () => { ta.value = libraryExport(); msg.textContent = "Exported: observed keys (APs and stations)."; });
}
function renderHome() {
  const hb = el("home-body"); if (!hb || !S.homeOpen) return;
  const h = S.homing;
  let x = "<h4>Homing</h4>";
  if (!h) x += '<div class="obsnote">No homing access point is set. Choose one at the collector (STARCHORUS_HOMING_BSSID) or on the device; the page never sends anything.</div>';
  else {
    const n = S.aps.get(h.bssid), pct = Math.round(100 * rssiT(h.dbm)), pk = Math.round(100 * rssiT(h.peak ?? h.dbm));
    x += '<div class="obsrow"><span>' + esc((n && (aliasOf(n.id) || n.ssidKnown || n.ssid)) || h.bssid) + "</span></div>";
    x += '<div class="meter">' + esc(fmtSignal(h.dbm)) + "</div>";
    x += '<div class="bar" role="meter" aria-valuemin="0" aria-valuemax="100" aria-valuenow="' + pct + '"><i style="width:' + pct + '%"></i><b style="left:' + pk + '%"></b></div>';
    x += '<div class="obsnote">peak ' + (h.peak == null ? "—" : h.peak + " dBm") + ' · coarse: one reading per poll, no direction</div>';
  }
  x += '<div class="chips"><button class="chip' + (S.homeTone ? " on" : "") + '" id="home-tone" aria-pressed="' + !!S.homeTone + '">Tone ' + (S.homeTone ? "on" : "off") + "</button></div>";
  hb.innerHTML = x;
  const tb = el("home-tone");
  if (tb) tb.addEventListener("click", () => { S.homeTone = !S.homeTone; if (S.homeTone && !homeCtx) { try { homeCtx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { homeCtx = null; } } renderHome(); });
}
// ---- export (text formats, local): access points AND stations (a received association may be filed); mobile hotspots and own transmitters (and an own/mobile parent) left out
function exportModel() {
  const withNotes = (o, id) => { const nt = S.notes.get(id); if (nt && nt.a) o.alias = nt.a; if (nt && nt.t.length) o.tags = nt.t.slice(); return o; };   // alias/tags only: note text is NOT exported
  const aps = S.apOrder.filter(n => !eventSkip(n)).map(n => withNotes({ bssid: n.bssid, ssid: n.ssidKnown || n.ssid || "", band: n.band, channel: n.channel, security: n.security || ENCODING.security[n.sec].label, class: n.sec, rssi: n.rssi, heard: heardWord(n) }, n.id));
  let mob = 0; S.aps.forEach(n => { if (n.target === 1 && n.mobile) mob++; });
  const clouds = S.cloudOrder.length > 0;
  // stations are first-class rows with their AP association (a received-only directed-frame value): an association is filed only
  // when the PARENT is a real, non-own, non-mobile AP (eventSkip), so a station never drags an own or hotspot BSSID into the file;
  // a derived probe orbit (affinity) is not an association.
  const stations = S.clientOrder.filter(n => n.target === 1 && !eventSkip(n)).map(n => {
    const par = (!n.free && !n.affinity && n.parent && !eventSkip(S.aps.get(n.parent))) ? n.parent : null;
    const o = { mac: n.mac, vendor: n.vendor || "", band: n.band || "", rssi: n.rssi, randomized: !!n.randomized, probes: (n.probes || []).slice(), association: par, heard: heardWord(n) };
    if (clouds && n.cloud != null) o.cloud = n.cloud;
    if (n.fps != null) o.rate = Math.round(n.fps * 10) / 10;
    return withNotes(o, n.id);
  });
  const sc = { free: 0, associated: 0 }; stations.forEach(x => { if (x.association) sc.associated++; else sc.free++; });
  const out = { footer: EXPORT_FOOTER, generated: S.generated, source: S.sourceKind, aps, stations, station_counts: sc, mobile_hotspots: mob, crowding: S.crowding.level };
  if (clouds) {   // §8.8a only with a live cloud
    sc.randomised = stations.filter(x => x.randomized).length; sc.in_clouds = stations.filter(x => x.cloud != null).length;
    out.clouds = S.cloudOrder.map(k => ({ id: k.id, addresses: k.n, rssi: k.rssi, rssi_min: k.rssiMin, rssi_max: k.rssiMax, first_heard: k.first, last_heard: k.last, cadence_s: k.cadenceS, bursts: k.bursts,
      probes: k.probes.slice(), estimate: (cloudMixed(k) ? "possibly one or more nearby devices changing their address" : "probably one nearby device changing its address") + "; not a device count" }));
  }
  if (S.btDoc) {   // §1.8
    const { shown, void: vd, ...bc } = btStats(); out.bluetooth = []; out.bluetooth_counts = bc;
    S.btOrder.forEach(k => k.m.forEach(({ last_seen: ls, ...r }) => out.bluetooth.push({ ...r, heard: heardWord({ freshTier: freshOf(ls, S.generated).tier }), mark: k.id })));
  }
  return out;
}
function exportText(fmt) {
  const m = exportModel();
  if (fmt === "csv") {
    const q = (v) => { const s = v == null ? "" : String(v), t = /^[=+@\t\r-]/.test(s) && !isFinite(s) ? "'" + s : s; return /[",\r\n]/.test(t) ? '"' + t.replace(/"/g, '""') + '"' : t; };
    const head = "kind,bssid,ssid,band,channel,security,rssi,heard,alias,tags,association,randomized,probes,cloud";   // one table, a leading kind column, every row the same width
    const apRow = (a) => ["ap", a.bssid, a.ssid, a.band, a.channel, a.security, a.rssi, a.heard, a.alias || "", (a.tags || []).join(" "), "", "", "", ""];
    const stRow = (x) => ["station", x.mac, "", x.band, "", "", x.rssi, x.heard, x.alias || "", (x.tags || []).join(" "), x.association || "", x.randomized ? "1" : "", (x.probes || []).join(" "), x.cloud || ""];
    return [head].concat(m.aps.map(a => apRow(a).map(q).join(","))).concat(m.stations.map(x => stRow(x).map(q).join(","))).concat(["# " + EXPORT_FOOTER]).join("\n") + "\n";
  }
  if (fmt === "sitrep") {
    const by = (fn) => { const c = {}; for (const a of m.aps) c[fn(a)] = (c[fn(a)] || 0) + 1; return Object.keys(c).sort().map(k => k + " " + c[k]).join(" · "); };
    const top = m.aps.slice().sort((a, b) => rssiOf(b) - rssiOf(a)).slice(0, 5).map(a => "  " + (a.alias || a.ssid || "(hidden)") + " · " + a.bssid + " · " + fmtBand(a.band) + (a.channel != null ? " ch " + a.channel : "") + " · " + a.rssi + " dBm");
    const cl = m.clouds || null, outside = cl ? m.stations.filter(x => x.cloud == null) : m.stations;
    const staTop = outside.slice().sort((a, b) => rssiOf(b) - rssiOf(a) || (a.mac < b.mac ? -1 : 1)).slice(0, STA_SITREP_MAX)
      .map(x => "  " + (x.alias || x.mac) + " · " + fmtBand(x.band) + (x.rssi != null ? " · " + x.rssi + " dBm" : "") + " · " + (x.association ? "assoc " + x.association : x.probes.length ? "named probes " + x.probes.length : "free"));
    const cap = m.generated != null ? new Date(m.generated * 1000).toISOString().slice(0, 19) + "Z" : "undated";
    return ["SITREP · Starchorus", EXPORT_FOOTER, "", "Capture: " + cap + " · source: " + m.source,
      "Access points: " + m.aps.length + " · stations: " + m.stations.length + " (" + m.station_counts.free + " free, " + m.station_counts.associated + " associated) · mobile hotspots: " + m.mobile_hotspots]
      .concat(cl ? ["Randomised: " + m.station_counts.randomised + " · " + m.station_counts.in_clouds + " of them in " + cl.length + (cl.length === 1 ? " cloud" : " clouds") + " (an estimate, not a device count)"] : [],
      ["Bands: " + by(a => a.band), "Security: " + by(a => a.class), "Crowding: " + m.crowding + " of 5", "", "Strongest:"], top, ["", "Stations (strongest " + Math.min(outside.length, STA_SITREP_MAX) + " of " + outside.length + (cl ? " outside clouds" : "") + "):"], staTop,
      cl ? ["", "Clouds of randomised addresses (an estimate):"].concat(cl.map(c => "  " + c.id + " · " + c.addresses + " addresses · " + c.rssi + " dBm (" + c.rssi_min + " to " + c.rssi_max + ")" + (c.cadence_s != null ? " · " + cadText(c.cadence_s) : "") + " · named probes " + c.probes.length)) : [],
      ["", "Observations:"], S.obs.length ? S.obs.map(o => "  " + o.text) : ["  none"], ["", EXPORT_FOOTER]).join("\n") + "\n";
  }
  return JSON.stringify(m, null, 1) + "\n";
}
function exportPng() {   // the canvases as they are, plus the footer; returned as a data: URL (shown, never sent)
  const c = document.createElement("canvas"); c.width = canvasSky.width; c.height = canvasSky.height + 20; const x = c.getContext("2d");
  x.fillStyle = THEME.surface.base; x.fillRect(0, 0, c.width, c.height);
  for (const cv of [canvasBg, canvasSky, canvasHud]) if (cv.width > 0) x.drawImage(cv, 0, 0, c.width, canvasSky.height);
  x.fillStyle = THEME.ink.secondary; x.font = "12px " + THEME.font.ui; x.textBaseline = "middle"; x.fillText(EXPORT_FOOTER, 10, c.height - 10);
  return c.toDataURL("image/png");
}
function openExport() { el("export-wrap").style.display = "flex"; refreshExport(); el("export-fmt").focus(); }
function closeExport() { el("export-wrap").style.display = "none"; document.activeElement.blur(); }
function refreshExport() { el("export-ta").value = exportText(el("export-fmt").value); el("export-png").hidden = true; el("export-msg").textContent = ""; }
el("btn-export").addEventListener("click", openExport);
for (const k of ["air", "time", "rec"]) el("t-" + k).addEventListener("click", () => setDx(k));
el("t-chan").addEventListener("click", () => cycleChanMode());
el("t-random").addEventListener("click", () => cycleRandom());
el("export-close").addEventListener("click", closeExport);
el("export-wrap").addEventListener("click", (e) => { if (e.target === el("export-wrap")) closeExport(); });
el("export-fmt").addEventListener("change", refreshExport);
el("export-copy").addEventListener("click", () => { const t = el("export-ta").value, ok = () => { el("export-msg").textContent = "Copied."; }, no = () => { el("export-ta").focus(); el("export-ta").select(); el("export-msg").textContent = "Select and copy (Ctrl/Cmd+C)."; }; try { navigator.clipboard.writeText(t).then(ok, no); } catch (e) { no(); } });
el("export-print").addEventListener("click", () => { el("export-printable").textContent = exportText("sitrep"); window.print(); });
el("export-snap").addEventListener("click", () => { const im = el("export-png"); im.src = exportPng(); im.hidden = false; el("export-msg").textContent = "Right-click or long-press the image to save it."; });
// ---- drawers: air quality, signal over time, recording/replay
function setDx(name) { S.dx = S.dx === name ? null : name; if (S.dx) { S.homeOpen = false; dropToggle("inventory"); dropToggle("observations"); } applyDrawer(); return S.dx; }
const CHAN_MODES = ["bars", "spectrum", "waterfall"];
function setChanMode(m) {
  if (CHAN_MODES.indexOf(m) < 0) return S.chanMode;
  S.chanMode = m;
  const b = el("t-chan");
  if (b) {
    b.textContent = m === "bars" ? "▤" : m === "spectrum" ? "◠" : "▦";
    b.setAttribute("aria-label", "Channel view: " + m);
    b.title = "Channel view: " + m + " (click or [Y] for the next)";
  }
  drawChannelBar(); S.dirty = true;
  return m;
}
// §8.8a the Random switch (X): a view of the model; it changes what is drawn, hit and counted as visible, nothing else.
const RANDOM_LOOK = { cloud: ["one node per cloud", "one by one"], show: ["one by one", "hidden"], hide: ["hidden", "one node per cloud"] };
function syncRandomButton() {
  const b = el("t-random"); if (!b) return;
  const m = S.ui.random, L = RANDOM_LOOK[m] || RANDOM_LOOK.cloud, a = "Randomised addresses: " + L[0];
  b.classList.toggle("on", m !== "show"); b.dataset.state = m; b.setAttribute("aria-label", a); b.title = a + " [X] · next: " + L[1];
}
function setRandomMode(m) {
  if (RANDOM_MODES.indexOf(m) < 0) return S.ui.random;
  S.ui.random = m; syncRandomButton(); applyRandom();
  // §8.8a: release a lock or hover on a node the new mode no longer draws
  if (S.locked && ((m !== "cloud" && S.clouds.has(S.locked)) || (m === "hide" && (S.clients.get(S.locked) || {}).randOut))) deselect();
  if (S.hover && ((S.clients.get(S.hover) || {}).randOut || S.clouds.has(S.hover))) setHover(null);
  applyAffinity(); S.nFreeTotal = countFreeLayout(); S.layoutDirty = true; settleLayout(LAYOUT.settleSyncIter);
  S.queryLocked.delete("random"); saveUi();
  updateControlsLook(); updateStats(); S.dirty = true; return m;
}
function cycleRandom() { return setRandomMode(RANDOM_MODES[(RANDOM_MODES.indexOf(S.ui.random) + 1) % RANDOM_MODES.length]); }
function cloudMixed(k) { return !k.kept && k.rhythm < CLOUD.mixedShare; }   // §8.8a: its bursts keep no one rhythm (two devices of one period, or one that scans unevenly)
function cadText(s) { return s < 90 ? "about every " + Math.round(s) + " s" : "about every " + Math.round(s / 60) + " min"; }
function cycleChanMode() { return setChanMode(CHAN_MODES[(CHAN_MODES.indexOf(S.chanMode) + 1) % CHAN_MODES.length]); }
const fmtDbm = (v) => v == null ? "—" : v + " dBm";
function skyLine() {   // the Compendium line — our own wording from skyStats; uncertainty in words; never a device, an SSID or a MAC
  const sk = skyStatsObj(), N = sk.n; if (N === 0) return "The local sky is empty.";
  const nm = { "2.4": "2.4 GHz", "5": "5 GHz", "6": "6 GHz" }, bands = ["2.4", "5", "6"].filter(b => sk.band[b].count != null).sort((a, b) => sk.band[b].count - sk.band[a].count || (a < b ? -1 : 1));
  let t = N + (N === 1 ? " star is" : " stars are") + " in view";
  if (bands.length) { const c = sk.band[bands[0]]; t += "; most of them sit on " + nm[bands[0]] + (c.p != null ? " (about " + Math.round(c.p * 10) + " in 10, somewhere between " + Math.round(c.lo * 10) + " and " + Math.round(c.hi * 10) + ")" : " (counted, not estimated: fewer than " + sk.minN + " stars)"); }
  t += ". The air is " + AIR_WORDS[S.crowding.level - 1] + ". ";
  t += sk.ref.warm ? (sk.deviations.length ? sk.deviations.length + (sk.deviations.length === 1 ? " channel differs" : " channels differ") + " from the usual picture." : "The usual picture holds.") : "The usual picture is still forming (" + sk.ref.captures + " of " + SKY.warm + " captures).";
  return t;
}
function vaultObj() { return S.sky.dev.map(d => ({ band: d.band, channel: d.channel, count: d.count, ref: d.ref, dir: d.dir })); }   // the shared deviations, by band and channel only
// one lamp per access point, ordered by channel then BSSID — the channel axis with recency on it. "Lit" is D1's T0
// (heard < 1 min); undated APs look like T0 everywhere else on the page, so they are lit here too. Access points
// only, never a client or a person; a lamp carries no name — its title says band and channel, nothing else.
function lampStripObj() {
  const max = THEME.chrome.lampStrip.max | 0;
  if (max <= 0) return { shown: false, lamps: [], total: 0, lit: 0, more: 0 };
  const ch = (n) => n.channel ?? 9999;
  const aps = S.apOrder.slice().sort((a, b) => ch(a) - ch(b) || cmpStr(a.id, b.id));
  const lamps = aps.slice(0, max).map(n => ({ id: n.id, band: n.band, channel: n.channel ?? null, on: n.freshTier == null || n.freshTier === 0 }));
  // `lit` counts EVERY access point heard in the last minute, not only the ones that got a lamp: the caption
  // reads "n of <total>", and a capped numerator over an uncapped total would simply be a false number.
  return { shown: true, lamps, total: aps.length, lit: aps.reduce((s, n) => s + (n.freshTier == null || n.freshTier === 0 ? 1 : 0), 0), more: Math.max(0, aps.length - lamps.length) };
}
function renderAir() {
  const ab = el("air-body"); if (!ab || S.dx !== "air") return;
  const a = airQuality(); let h = "<h4>Air quality</h4>";
  if (!S.apOrder.length) { ab.innerHTML = h + '<div class="note">No access points in view.</div>'; return; }
  if (THEME.chrome.lampStrip.max > 0) {
    const ls = lampStripObj(), lc = THEME.copy.lampStrip;
    h += '<div class="strip" id="lamp-strip"><div>' + esc(lc.title) + '</div><div class="lamps">'
      + ls.lamps.map(l => '<i data-bssid="' + esc(l.id) + '"' + (l.on ? ' class="on" style="background: ' + esc(bandColorOf(l.band)) + '"' : "")
        + ' title="' + esc(fmtBand(l.band) + " · ch " + (l.channel == null ? "?" : l.channel)) + '"></i>').join("")
      + '</div><div class="cap">' + ls.lit + " of " + ls.total + (ls.more ? " · " + ls.more + " " + esc(lc.more) : "") + "</div></div>";
  }
  if (THEME.chrome.compendium.show) h += '<div class="compendium" id="compendium"><h4>' + esc(THEME.copy.compendium.title) + "</h4><div>" + esc(skyLine()) + "</div></div>";
  if (THEME.chrome.vault.show) {   // the Vault — the D11 deviations in Foundation's voice: "busier / quieter than this sky usually is", never a threat
    const v = vaultObj(), vc = THEME.copy.vault;
    h += '<div class="vault" id="vault"><h4>' + esc(vc.title) + "</h4>" + (v.length ? v.map(d => "<div>" + esc(fmtBand(d.band) + " ch " + d.channel + ": " + (d.dir === "up" ? vc.up : vc.down) + " (" + d.count + " stars, usually about " + Math.round(d.ref) + ")") + "</div>").join("") : "<div>Nothing stands out from the usual picture.</div>") + "</div>";
  }
  if (THEME.chrome.crowdSign.show) {   // the crowding sign — five steps, monochrome, never blinks or escalates; the caption says what it is not
    const cs = THEME.copy.crowdSign;
    h += '<div class="sign" id="crowd-sign" role="img" aria-label="' + esc(cs.title) + " " + a.level + ' of 5"><div>' + esc(cs.title) + '</div><div class="steps">' + cs.steps.map((t, i) => '<i class="' + (i < a.level ? "on" : "") + '">' + esc(t) + "</i>").join("") + '</div><div class="cap">' + esc(cs.caption) + "</div></div>";
  }
  h += '<div class="row"><span>Overall</span><b>' + esc(a.word) + " · " + a.level + " of 5</b></div>";
  if (a.busiest) h += '<div class="row"><span>Busiest</span><span>' + esc(fmtBand(a.busiest.band)) + " ch " + a.busiest.channel + "</span></div>";
  for (const band of ["2.4", "5", "6"]) {
    const b = a.bands[band]; if (!b) continue;
    h += "<h4>" + esc(fmtBand(band)) + "</h4>";
    h += '<div class="row"><span>' + plu(b.aps, "AP") + " on " + plu(b.channels, "channel") + '</span><span title="Estimated lower bound: heard access points only">beacons ≥ ' + b.beaconPctSum + " % est.</span></div>";
    for (const t of b.top) h += '<div class="row"><span>ch ' + t.ch + (t.dfs ? " · DFS" : "") + "</span><span>" + t.co + " co · " + t.adjacent + " adjacent · max " + esc(fmtDbm(t.maxDbm)) + "</span></div>";
    if (b.quietest) h += '<div class="row"><span>least occupied of ' + AIR_SETS[band].join("/") + '</span><span>ch ' + b.quietest.ch + " (" + b.quietest.co + " co · " + b.quietest.adjacent + " adjacent)</span></div>";
  }
  const as = a.assumptions;
  h += '<div class="note">An observation of this sky, not advice. Beacon airtime is an estimate: one beacon per access point every ' + as.beaconMs + " ms, " + as.beaconBytes + " bytes at " + as.mbps["2.4"] + " Mbit/s (2.4 GHz) or " + as.mbps["5"] + " Mbit/s (5 and 6 GHz) — a lower bound from what was heard. Widths are assumed 20 MHz where the collector gives none.</div>";
  ab.innerHTML = h;
  // hovering a lamp points at its own star, the same as hovering the star (the listeners go with the markup)
  for (const lamp of ab.querySelectorAll("#lamp-strip .lamps i[data-bssid]")) {
    lamp.addEventListener("pointerenter", () => { const n = S.aps.get(lamp.getAttribute("data-bssid")); if (n) { S.hover = n.id; S.dirty = true; } });
    lamp.addEventListener("pointerleave", () => { setHover(null); });
  }
}
function drawTimeChart(cv, tm) {
  const cssW = cv.clientWidth || 240, cssH = 96, d = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
  cv.width = Math.floor(cssW * d); cv.height = Math.floor(cssH * d);
  const ctx = cv.getContext("2d"); ctx.setTransform(d, 0, 0, d, 0, 0); ctx.clearRect(0, 0, cssW, cssH);
  const L = 26, T = 6, B = 14, w = cssW - L - 4, hh = cssH - T - B, lo = -100, hi = -20, yOf = (v) => T + (1 - (clamp(v, lo, hi) - lo) / (hi - lo)) * hh;
  ctx.strokeStyle = THEME.line.hairline; ctx.lineWidth = 1; ctx.fillStyle = THEME.ink.muted; ctx.font = "400 8px " + THEME.font.ui; ctx.textAlign = "right"; ctx.textBaseline = "middle";
  for (const v of [-20, -50, -80]) { ctx.beginPath(); ctx.moveTo(L, yOf(v) + 0.5); ctx.lineTo(L + w, yOf(v) + 0.5); ctx.stroke(); ctx.fillText(String(v), L - 3, yOf(v)); }
  ctx.textAlign = "left"; ctx.textBaseline = "alphabetic";
  ctx.fillText("−" + Math.round(tm.window * tm.intervalS / (tm.scale === "1m" ? 1 : 60)) + (tm.scale === "1m" ? " s" : " min"), L, cssH - 3);
  ctx.textAlign = "right"; ctx.fillText("now", L + w, cssH - 3);
  const n = tm.window;
  tm.curves.forEach((c, ci) => {
    ctx.strokeStyle = bandColorOf(c.band); ctx.lineWidth = 1.5; ctx.setLineDash(ci % 2 ? [4, 2] : []); ctx.beginPath(); let pen = false;
    const off = n - c.samples.length;   // a shorter series is right-aligned: it ends "now"
    c.samples.forEach((v, i) => { if (v == null) { pen = false; return; } const x = L + (off + i) / Math.max(1, n - 1) * w, y = yOf(v); if (!pen) { ctx.moveTo(x, y); pen = true; } else ctx.lineTo(x, y); });
    ctx.stroke();
  });
  ctx.setLineDash([]);
  if (tm.threshold != null) { ctx.strokeStyle = THEME.ink.secondary; ctx.lineWidth = 1; ctx.setLineDash([6, 3]); ctx.beginPath(); ctx.moveTo(L, yOf(tm.threshold) + 0.5); ctx.lineTo(L + w, yOf(tm.threshold) + 0.5); ctx.stroke(); ctx.setLineDash([]); }
}
function renderTime() {
  const tb = el("time-body"); if (!tb || S.dx !== "time") return;
  const tm = timeModel(), oldIn = el("thr-in"), keep = oldIn ? { v: oldIn.value, f: document.activeElement === oldIn } : null;
  let h = "<h4>Signal over time</h4>";
  h += '<div class="chips">' + Object.keys(TIME_SCALES).map(k => '<button class="chip' + (tm.scale === k ? " on" : "") + '" data-scale="' + k + '">' + (k === "1m" ? "1 min" : k === "10m" ? "10 min" : "1 h") + "</button>").join("") + "</div>";
  h += '<canvas id="time-cv" role="img" aria-label="Signal curves"></canvas>';
  h += "<table><thead><tr><th>Network</th><th>min</th><th>max</th><th>mean</th><th>now</th></tr></thead><tbody>";
  for (const c of tm.curves) h += "<tr><td>" + esc(c.label) + "</td><td>" + (c.min ?? "—") + "</td><td>" + (c.max ?? "—") + "</td><td>" + (c.mean ?? "—") + "</td><td>" + (c.last ?? "—") + "</td></tr>";
  h += "</tbody></table>";
  h += '<h4>Threshold</h4><div class="chips"><input id="thr-in" type="number" min="-100" max="-20" step="1" placeholder="dBm" aria-label="Signal threshold in dBm" value="' + (S.threshold ?? "") + '" style="width:64px"><button class="chip" id="thr-set">Set</button><button class="chip" id="thr-clear">Clear</button></div>';
  h += '<div class="note">' + (tm.threshold == null ? "A threshold draws a dashed line here and a dashed ring on the map." : tm.above + " access points at or above " + tm.threshold + " dBm now (dashed ring on the map).") + "</div>";
  h += '<div class="note">One sample per capture; gaps stay gaps. ' + tm.window + " samples at " + (tm.spacingFrom === "observed" ? "the observed " + r3(tm.intervalS) + " s spacing" : tm.spacingFrom === "announced" ? "the announced " + tm.intervalS + " s interval" : "an assumed " + tm.intervalS + " s spacing") + (tm.limited ? " (the memory holds " + LONG_LEN + ")" : "") + ". The network is the selected access point's SSID, else the pinned ones, else the three strongest.</div>";
  tb.innerHTML = h;
  drawTimeChart(el("time-cv"), tm);
  for (const b of tb.querySelectorAll("[data-scale]")) b.addEventListener("click", () => { S.timeScale = b.getAttribute("data-scale"); renderTime(); });
  const ti = el("thr-in"); if (keep) { ti.value = keep.v; if (keep.f) ti.focus(); }
  ti.addEventListener("keydown", (e) => { e.stopPropagation(); if (e.key === "Enter") { setThreshold(ti.value === "" ? null : +ti.value); } });
  el("thr-set").addEventListener("click", () => setThreshold(ti.value === "" ? null : +ti.value));
  el("thr-clear").addEventListener("click", () => setThreshold(null));
}
function setThreshold(v) { S.threshold = v == null || !Number.isFinite(+v) ? null : clamp(Math.round(+v), -100, -20); S.dirty = true; renderTime(); return S.threshold; }
function renderRec() {
  const rb = el("rec-body"); if (!rb || S.dx !== "rec") return;
  const r = recObj(), rp = S.replay, i = rp ? rp.i : r.count - 1, sl = el("rec-slider");
  if (rp && sl === document.activeElement) { sl.max = r.count - 1; sl.value = i; el("rec-live").disabled = false; return recLabel(); }   // the slider in use keeps its element
  let h = "<h4>Recording</h4>";
  h += '<div class="note">' + r.count + " of " + r.max + " captures held in memory · about " + (r.bytes / 1048576).toFixed(1) + " MB of " + (r.maxBytes / 1048576) + " MB (estimated). Complete captures; never saved, gone when the page closes.</div>";
  if (!r.count) { rb.innerHTML = h + '<div class="note">Nothing recorded yet: a capture is recorded when its <code>generated</code> time is new.</div>'; return; }
  h += '<div class="chips"><button class="chip" id="rec-prev" title="Previous capture">◀</button><button class="chip' + (rp && rp.play ? " on" : "") + '" id="rec-play">' + (rp && rp.play ? "Pause" : "Play") + '</button><button class="chip" id="rec-next" title="Next capture">▶</button><button class="chip" id="rec-live"' + (rp ? "" : " disabled") + '>Back to live</button><button class="chip" id="rec-clear">Clear</button></div>';
  h += '<input id="rec-slider" type="range" min="0" max="' + (r.count - 1) + '" value="' + i + '" aria-label="Capture in the recording">';
  const gen = r.snapshots[i] ? r.snapshots[i].generated : null;
  h += '<div class="row" id="rec-pos">' + recPosHtml(rp, i, r, gen) + "</div>";
  h += '<div class="note">' + (rp ? "A replay is a view: nothing is written to the event record, the change log or the sky reference. " + (rp.buffered ? rp.buffered + (rp.buffered === 1 ? " newer capture arrived and is kept; it shows" : " newer captures arrived and are kept; they show") + " after Back to live." : "New captures keep being recorded and show after Back to live.") : "Move the slider or step to look back; the live feed keeps recording.") + " The channel bar's Waterfall view draws these captures as channel by time.</div>";
  rb.innerHTML = h;
  el("rec-slider").addEventListener("input", (e) => { replayTo(+e.target.value, { quiet: true }); });
  el("rec-prev").addEventListener("click", () => { replayTo((rp ? rp.i : r.count - 1) - 1); });
  el("rec-next").addEventListener("click", () => { if (rp) replayTo(rp.i + 1); });
  el("rec-play").addEventListener("click", () => { if (!S.replay) replayTo(0); S.replay.play = !S.replay.play; S.replay.acc = 0; renderRec(); });
  el("rec-live").addEventListener("click", () => { replayExit(); });
  el("rec-clear").addEventListener("click", () => { recClear(); });
}
function recPosHtml(rp, i, r, gen) { return "<span>" + (rp ? "Replay " : "Newest ") + (i + 1) + " of " + r.count + "</span><span>" + (Number.isFinite(gen) ? new Date(gen * 1000).toISOString().slice(11, 19) + "Z" : "undated") + "</span>"; }
function recLabel() {
  const e = el("rec-pos"); if (!e || !S.rec) return;
  const r = recObj(), rp = S.replay, i = rp ? rp.i : r.count - 1;
  e.innerHTML = recPosHtml(rp, i, r, r.snapshots[i] ? r.snapshots[i].generated : null);
}
function recClear() {
  if (S.replay) replayExit();
  S.rec = recEmpty(); S.rec.key = S.sourceKey;
  if (S.chanMode === "waterfall") drawChannelBar();
  renderRec();
  return true;
}
function waterfallModel(band) {   // channel × time from the recorded captures: each cell = the strongest AP on that channel in that capture (null = none heard)
  const r = S.rec; if (!r || !r.docs.length || !BAND_HZ[band]) return { band, channels: [], cols: [], cells: [] };
  const cols = r.docs.map(d => ({ n: d.n, generated: d.gen })), chans = new Set(), grid = r.docs.map(d => { const m = new Map(); for (const a of d.doc.aps) { if (a.band !== band || a.channel == null) continue; chans.add(a.channel); if (a.rssi != null && (!m.has(a.channel) || a.rssi > m.get(a.channel))) m.set(a.channel, a.rssi); else if (!m.has(a.channel)) m.set(a.channel, null); } return m; });
  const channels = Array.from(chans).sort((a, b) => a - b);
  return { band, channels, cols, cells: channels.map(ch => grid.map(m => m.has(ch) ? m.get(ch) : null)) };
}
function applyDrawer() {   // the legend's box hosts one body at a time: legend | observations | inventory | homing | air | time | rec (D15: still one panel, no new overlap)
  const d = S.homeOpen ? "home" : S.dx ? S.dx : S.ui.inventory ? "inv" : S.ui.observations ? "obs" : "legend";
  const was = document.documentElement.dataset.drawer; document.documentElement.dataset.drawer = d; document.documentElement.dataset.obs = d === "obs" ? "on" : "off";
  for (const [id, k] of [["legend-body", "legend"], ["obs-body", "obs"], ["inv-body", "inv"], ["home-body", "home"], ["air-body", "air"], ["time-body", "time"], ["rec-body", "rec"]]) { const e = el(id); if (e) e.hidden = d !== k; }
  for (const [id, k] of [["t-air", "air"], ["t-time", "time"], ["t-rec", "rec"]]) syncPressed(id, S.dx === k);
  syncPressed("t-home", S.homeOpen);
  renderObs(); renderInv(); renderHome(); renderAir(); renderTime(); renderRec();
  if (d !== was) { const b = el(d + "-body"); if (b) b.scrollTop = 0; }   // another body is shown: it opens at the top (the browser would bring back its old offset); one that stays keeps it
  layoutEdges();
}
function renderObs() {
  const ob = el("obs-body"); if (!ob || !S.ui.observations || document.activeElement === el("obs-watch-in")) return;
  let h = "", last = null;
  for (const r of S.obs) { if (r.group !== last) { h += "<h4>" + esc(r.group) + "</h4>"; last = r.group; } h += '<div class="obsrow hint"><span class="dot"></span><span>' + esc(r.text) + "</span></div>"; }
  if (!S.obs.length) h += '<div class="obsnote">Nothing to report yet — hints appear once they hold for two captures.</div>';
  h += '<h4>Watchlist</h4>';
  for (const w of S.watch) h += '<div class="obsrow"><span class="dot"></span><span>' + esc(w) + ' <button class="btn" data-unwatch="' + esc(w) + '" title="Stop watching">×</button></span></div>';
  h += '<input id="obs-watch-in" type="text" maxlength="32" placeholder="watch an SSID (Enter)" aria-label="Watch an SSID">';
  h += '<div class="obsnote">Derived hints, not an assessment. Baseline (stations: MAC and signal only), watchlist and identities stay in this browser.</div>';
  h += '<button class="btn" id="obs-clear" title="Delete the saved baseline, watchlist and identities from this browser">Clear local data</button>';
  ob.innerHTML = h;
  const inp = el("obs-watch-in");
  if (inp) inp.addEventListener("keydown", (e) => { e.stopPropagation(); if (e.key === "Enter") { inp.blur(); watchSet(inp.value, true); renderObs(); const i2 = el("obs-watch-in"); if (i2) i2.focus(); } });
  for (const b of ob.querySelectorAll("[data-unwatch]")) b.addEventListener("click", () => { watchSet(b.getAttribute("data-unwatch"), false); renderObs(); });
  const cl = el("obs-clear"); if (cl) cl.addEventListener("click", () => clearLocalData());
}
function clearLocalData() {   // P8: every starchorus.* key, in one call (SECURITY.md §4 lists them)
  setToggle("baselineDiff", false);   // first: it saves the ui key, which the loop then removes
  for (const k of [STORAGE_KEY, IDENTITY_KEY, BASELINE_KEY, WATCH_KEY, LIB_KEY, NOTES_KEY]) safeStorage.remove(k);
  clearTimeout(saveTimer);   // the queued ui save
  S.identity.clear(); S.baseline = null; S.watch = []; S.obsWatchSeen = new Set(); S.rules = []; S.notes.clear(); recClear();   // the recording is memory only, but "clear" means clear
  baselineRecompute(); obsCompute(); renderObs(); S.dirty = true; return true;
}
function updateStats() {
  let apsTotal = 0, aps = 0, free = 0, assoc = 0, bandUnknown = 0;
  const bandsT = { "2.4": 0, "5": 0, "6": 0 }, bands = { "2.4": 0, "5": 0, "6": 0 };
  // D1: per tier, all present nodes | the drawn ones (APs: filter and ESS fold; stations: see freshVisCl)
  const fresh = freshZero(), freshVis = freshZero();
  S.aps.forEach(n => {
    if (n.target !== 1) return; apsTotal++;
    const fk = n.freshTier == null ? "undated" : "t" + n.freshTier; fresh[fk]++;
    const on = S.ui.filters[n.band] !== false;
    const drawn = on && !isEssFolded(n.id);
    if (drawn) { aps++; freshVis[fk]++; if (n.band === "unknown") bandUnknown++; }
    if (n.band in bandsT) { bandsT[n.band]++; if (drawn) bands[n.band]++; }
  });
  let probing = 0, randomized = 0, rndFree = 0;
  const freshCl = freshZero(), freshVisCl = freshZero();
  S.clients.forEach(n => {
    if (n.target !== 1) return;
    const loose = n.free || n.affinity;
    if (loose) free++; else assoc++;
    if (n.affinity) probing++;
    if (n.randomized) { randomized++; if (loose) rndFree++; }
    const fk = n.freshTier == null ? "undated" : "t" + n.freshTier; freshCl[fk]++;
    const ap = n.parent ? S.aps.get(n.parent) : null; if (n.free || (ap && ap.target === 1 && S.ui.filters[ap.band] !== false)) freshVisCl[fk]++;   // the draw rule of stepNodes
  });
  const hiddenRnd = S.ui.random === "hide" ? rndFree : 0; free -= hiddenRnd;   // §8.8a hidden: not visible, still counted in the model
  let inClouds = 0; for (const k of S.cloudOrder) inClouds += k.n; const nClouds = S.cloudOrder.length;
  const clients = free + assoc;
  const alarms = S.security.open + S.security.wep;
  el("n-ap").textContent = String(apsTotal); el("n-ap").title = String(apsTotal); el("bar-ap").textContent = String(apsTotal); el("bar-cl").textContent = String(clients);
  el("n-cl").textContent = String(clients); el("n-cl").title = free + " free · " + assoc + " associated" + (probing ? " · " + probing + " on probe orbits (derived)" : "")
    + (randomized ? " · " + randomized + " randomised" + (nClouds ? ", " + inClouds + " of them in " + nClouds + (nClouds === 1 ? " cloud" : " clouds") : "") : "") + (hiddenRnd ? " · " + hiddenRnd + " hidden" : "");
  for (const [id, b] of [["n-24", "2.4"], ["n-5", "5"], ["n-6", "6"]]) { el(id).textContent = String(bands[b]); el(id).title = String(bandsT[b]); }
  const alarmCell = el("n-alarm-cell"); if (alarmCell) alarmCell.hidden = alarms === 0;
  const alarmNum = el("n-alarm"); if (alarmNum) { const num = alarmNum.querySelector(".num"); if (num) num.textContent = String(alarms); alarmNum.title = String(alarms); }
  let ng = 0; S.groups.forEach(g => { if (g.members.length >= 2) ng++; });
  el("n-groups").textContent = String(ng);
  const dated = fresh.t0 + fresh.t1 + fresh.t2 + fresh.t3, reach = freshReach();
  const cc = el("n-crowd-cell"); if (cc) { cc.hidden = apsTotal === 0; el("n-crowd").textContent = String(S.crowding.level); }
  const fc = el("n-fresh-cell"), rc = el("n-record-cell");
  if (fc) { fc.hidden = dated === 0; el("n-fresh").textContent = String(fresh.t0); el("n-fresh").title = ENCODING.fresh.words.map((w, i) => w + " " + fresh["t" + i]).join(" · ") + " · " + ENCODING.fresh.undated + " " + fresh.undated; }
  if (rc) { rc.hidden = dated === 0 || !reach[3]; el("n-record").textContent = String(fresh.t3); el("n-record").title = String(fresh.t3); }
  const bc = el("n-bt-cell"), bs = btStats();   // §3.4 addresses, kept while the filter hides the marks; a dash when a void window left nothing
  if (bc) { bc.hidden = !bs; if (bs) { const n = el("n-bt"); n.textContent = bs.void && !bs.addresses ? "–" : bs.addresses >= BT.cap ? BT.cap + "+" : String(bs.addresses); n.title = bs.void ? "no valid scan this cycle; showing what was heard before" : bs.addresses + " addresses heard in the last " + bs.hold / 60 + " min, in " + bs.marks + " marks · LE, passive scan"; } }
  S._stats = { apsTotal, aps, free, assoc, clients, bands, bandsT, alarms, groups: ng, probing, bandUnknown, fresh, freshVis, freshCl, freshVisCl, randomized, randomisedFree: rndFree, clouds: nClouds, inClouds, randomHidden: hiddenRnd };
  if (cc && apsTotal > 0) el("n-crowd").title = skyTitle();
  updateLegendCounts();
  renderObs(); renderInv(); renderHome(); renderTote(); renderAir(); renderTime(); renderRec(); renderScope();
  layoutEdges();
}
// §9.4 legend = the canvas marks: every colour is a mirrored token (var(--x) → CSS_MIRROR path) that the
// draw code in §31–35 uses for that mark; ring width/dash/double come from ENCODING. STARCHORUS.legendRows() checks it.
const swFrame = (inner) => '<svg class="sw" viewBox="0 0 12 12" aria-hidden="true">' + inner + '</svg>';   // the 12 × 12 frame of every swatch except the ring's (14 × 14)
function svgSwatch(shape, fillVar, strokeVar, strokeW = 1.5, dotVar = null) {
  let inner;
  if (shape === "diamond") inner = '<path d="M6 1 11 6 6 11 1 6Z"';
  else if (shape === "hexagon") inner = '<path d="M6 1 10.3 3.5v5L6 11 1.7 8.5v-5Z"';
  else if (shape === "square") inner = '<rect x="1.6" y="1.6" width="8.8" height="8.8"';
  else inner = '<circle cx="6" cy="6" r="5"';
  const fill = fillVar ? ' fill="var(' + fillVar + ')"' : ' fill="none"';
  const stroke = strokeVar ? ' stroke="var(' + strokeVar + ')" stroke-width="' + strokeW + '"' : '';
  const dot = dotVar ? '<circle cx="6" cy="6" r="1.5" fill="var(' + dotVar + ')"/>' : '';
  return swFrame(inner + fill + stroke + '/>' + dot);
}
function bandSwatch(b) {   // core sprites (§31): filled shape if render.shapeFill, else 1-px outline + centre dot, colour band.<b>.core
  const e = ENCODING.band[b] || ENCODING.band.unknown, v = "--band-" + (b === "2.4" ? "24" : b);
  return THEME.render.shapeFill ? svgSwatch(e.shape, v) : svgSwatch(e.shape, null, v, 1, v);
}
function clientSwatch(ringVar, rnd) {   // client/clientAssoc (disc + surface rim) or clientCross (render.clientShape); ringVar = band ring when associated; rnd = the D8 randomised mark
  const ring = ringVar ? '<circle cx="6" cy="6" r="5" fill="none" stroke="var(' + ringVar + ')" stroke-width="1"/>' : '';
  const mark = THEME.render.clientShape === "cross"
    ? (rnd && THEME.render.clientRandomizedMark === "crossX" ? '<path d="M3.7 3.7l4.6 4.6M8.3 3.7l-4.6 4.6" fill="none" stroke="var(--client)" stroke-width="1"/>' : '<path d="M3.5 6h5M6 3.5v5" fill="none" stroke="var(--client)" stroke-width="1"/>')
    : (rnd && THEME.render.clientRandomizedMark === "hollow" ? '<circle cx="6" cy="6" r="2.6" fill="none" stroke="var(--client)" stroke-width="1.4"/>' : '<circle cx="6" cy="6" r="3" fill="var(--client)" stroke="var(--surface-base)" stroke-width="1"/>');
  return swFrame(ring + mark);
}
function gapRingPath(cx, cy, rad, mid = -Math.PI / 4, gapDeg = ENCODING.gapDeg) {   // a full circle minus a gap centred at `mid` (default: the D6 60° gap at NE)
  const g = gapDeg * Math.PI / 360, a0 = mid + g, a1 = mid - g;
  const pt = (a) => (cx + rad * Math.cos(a)).toFixed(2) + " " + (cy + rad * Math.sin(a)).toFixed(2);
  return "M" + pt(a0) + "A" + rad + " " + rad + " 0 1 1 " + pt(a1);
}
function ringSwatch(enc, strokeVar, r) {   // drawApRings (§34): ENCODING width/dash/double; the alarm ring has its NE gap; the wash is the aura ornament
  let s = '<svg class="sw ring" viewBox="0 0 14 14" aria-hidden="true">';
  if (enc.tone === "alarm" && THEME.status.alarmAura === "wash") s += '<circle cx="7" cy="7" r="6.5" fill="var(--status-alarm-wash)"/>';
  const ring = (rad) => '<circle class="ring" cx="7" cy="7" r="' + rad + '" fill="none" stroke="var(' + strokeVar + ')" stroke-width="' + enc.widthPx + '"' + (enc.dash ? ' stroke-dasharray="' + enc.dash.join(" ") + '"' : '') + '/>';
  if (enc.ring === "gap") s += '<path class="ring" d="' + gapRingPath(7, 7, r) + '" fill="none" stroke="var(' + strokeVar + ')" stroke-width="' + enc.widthPx + '"/>';
  else if (enc.ring !== "none") { s += ring(r); if (enc.ring === "double") s += ring(r + ENCODING.doubleRingGapPx); }
  return s + '</svg>';
}
function identitySwatch(e) {   // D7: the frame's form in ink.primary, exactly what drawIdentityFrame strokes
  const d = e.frame === "diamond" ? '<path d="M6 1 11 6 6 11 1 6Z"' : e.frame === "rect" ? '<rect x="0.8" y="2.6" width="10.4" height="6.8"' : '<rect x="1.8" y="1.8" width="8.4" height="8.4"';
  return swFrame(d + ' fill="none" stroke="var(--ink-primary)" stroke-width="1.5"' + (e.dash ? ' stroke-dasharray="' + e.dash.join(" ") + '"' : '') + '/>');
}
function freshSwatch(alpha) { return swFrame('<circle cx="6" cy="6" r="4.5" fill="var(--ink-secondary)" fill-opacity="' + alpha + '"/>'); }   // D1: the tier's alpha on a neutral disc
const SEC_TONE_VAR = { alarm: "--status-alarm", strong: "--status-ring-strong", neutral: "--status-ring-neutral", muted: "--ink-muted" };   // = drawHud glyph colorKey
function derivedSwatch() {   // D17/D10: every derived row carries the same hatch — a theme-free "computed, not measured" mark
  return swFrame('<rect x="1.5" y="1.5" width="9" height="9" fill="none" stroke="var(--ink-muted)" stroke-width="1"/><path d="M2 10L10 2M2 6L6 2M6 10L10 6" fill="none" stroke="var(--ink-muted)" stroke-width="1"/>');
}
function pinSwatch() {   // D5: the notched arc drawPinMark strokes (ink.secondary)
  const r = 4.6, g = ENCODING.pin.gapDeg * Math.PI / 360, a0 = -Math.PI / 2 + g, a1 = -Math.PI / 2 - g + 2 * Math.PI, nt = 1.6, f = (v) => v.toFixed(2);
  const tick = (a) => 'M' + f(6 + Math.cos(a) * (r - nt)) + ' ' + f(6 + Math.sin(a) * (r - nt)) + 'L' + f(6 + Math.cos(a) * (r + nt)) + ' ' + f(6 + Math.sin(a) * (r + nt));
  return swFrame('<path d="' + gapRingPath(6, 6, r, -Math.PI / 2, ENCODING.pin.gapDeg) + tick(a0) + tick(a1) + '" fill="none" stroke="var(--ink-secondary)" stroke-width="1.5"/>');
}
const derivedRow = (id, kind, text) => '<div class="legrow note" id="' + id + '" data-kind="' + kind + '" hidden>' + derivedSwatch() + '<span>' + text + '</span></div>';
function buildLegend() {   // D10: one builder, four blocks (Measured / Derived / Operator / Look), the same rows in every theme; visibility in legendVisibility()
  const rows = [], H = THEME.copy.legendHeads, block = (key) => '<h4 class="lblock" id="leg-block-' + key + '">' + esc(H[key]) + '</h4>';
  rows.push(block("measured"));
  rows.push('<h4>Bands</h4>');
  for (const [b, id] of [["2.4", "leg-24"], ["5", "leg-5"], ["6", "leg-6"]]) {
    const e = ENCODING.band[b];
    rows.push('<div class="legrow" data-kind="band-' + (b === "2.4" ? "24" : b) + '">' + bandSwatch(b) + '<span>' + e.legend + '</span><span class="cnt" id="' + id + '"></span></div>');
  }
  // "Band ?" = AP without band/freq/channel: drawn by drawStars as ENCODING.band.unknown in band.unknown.core; row only while such a star is drawn
  rows.push('<div class="legrow" id="leg-band-unknown" data-kind="band-unknown" hidden>' + bandSwatch("unknown") + '<span>' + ENCODING.band.unknown.legend + '</span><span class="cnt"></span></div>');
  rows.push('<div class="sep"></div><h4>Clients</h4>');
  rows.push('<div class="legrow" data-kind="client-free">' + clientSwatch(null) + '<span>free client</span></div>');
  rows.push('<div class="legrow" data-kind="client-assoc">' + clientSwatch("--band-24") + '<span>associated</span></div>');
  rows.push('<div class="legrow" id="leg-random" data-kind="client-random" hidden>' + clientSwatch(null, true) + '<span>randomised MAC<span class="lsub" id="leg-random-cl"></span></span><span class="cnt"></span></div>');   // D8: only while such a client is present
  rows.push('<div class="legrow" data-kind="bubble">' + svgSwatch("circle", "--bubble-fill", "--bubble-stroke", 1) + '<span>n clients (bubble)</span></div>');
  rows.push('<div class="legrow" id="leg-bt" data-kind="bt" hidden>' + swFrame('<path d="M6 1.5 10.6 10.2H1.4Z" fill="var(--bt-mark)" stroke="var(--bt-mark)" stroke-width="1.25"/>') + '<span>Bluetooth LE (passive scan)<br><span class="lsub" id="leg-bt-sub"></span></span><span class="cnt"></span></div>');
  rows.push('<div class="sep"></div><h4>Security</h4>');
  for (const sec of Object.keys(ENCODING.security)) {
    const e = ENCODING.security[sec];
    const ringVar = e.tone === "alarm" ? "--status-alarm" : e.tone === "strong" ? "--status-ring-strong" : "--status-ring-neutral";
    const glyph = e.glyph ? '<span class="glyph" style="color:var(' + (SEC_TONE_VAR[e.tone] || SEC_TONE_VAR.neutral) + ')">' + esc(e.glyph) + '</span>' : '<span class="glyph"></span>';
    rows.push('<div class="legrow" id="leg-' + sec + '" data-kind="sec-' + sec + '">' + ringSwatch(e, ringVar, 3.5) + glyph + '<span>' + e.label + '</span><span class="cnt"></span></div>');
  }
  rows.push('<div class="sep" id="leg-fresh-sep" hidden></div><h4 id="leg-fresh-h" hidden>Heard</h4>');
  for (let i = 0; i < ENCODING.fresh.words.length; i++) rows.push('<div class="legrow" id="leg-fresh-' + i + '" data-kind="fresh-t' + i + '" hidden>' + freshSwatch(ENCODING.fresh.alpha[i]) + '<span>' + esc(ENCODING.fresh.words[i]) + '</span><span class="cnt"></span></div>');
  rows.push('<div class="tote" id="tote" hidden></div>');
  rows.push('<div class="legrow" id="leg-fresh-u" data-kind="fresh-undated" hidden>' + freshSwatch(ENCODING.fresh.alpha[0]) + '<span>' + esc(ENCODING.fresh.undated) + '</span><span class="cnt"></span></div>');
  rows.push('<div class="sep"></div>');
  rows.push('<div class="legrow note" data-kind="hidden">' + ringSwatch(ENCODING.hidden, "--status-hidden", 5.5) + '<span>hidden SSID</span></div>');
  rows.push('<div class="legrow note" id="leg-alert" data-kind="alert" hidden>' + ringSwatch({ ring: "solid", widthPx: 1.5 }, "--status-alert", 5.5) + '<span>alert ring = many deauth/disassoc frames heard for this AP</span></div>');
  rows.push('<div class="legrow note" id="leg-activity" data-kind="activity" hidden>' + swFrame('<path d="M6 1.5v9" stroke="var(--ink-primary)" stroke-width="1.5"/>') + '<span>thin line in a channel bar = share of frames heard (relative)</span></div>');
  rows.push('<div class="legrow note" id="leg-cue" data-kind="traffic" hidden>' + swFrame('<circle cx="6" cy="6" r="4.8" fill="none" stroke="var(--client)" stroke-dasharray="1 2"/><circle cx="6" cy="6" r="1.8" fill="var(--client)"/>') + '<span>station ' + (THEME.render.trafficCue || "ticks") + ' = frames heard from it per second (depends on where the radio listens)</span></div>');
  rows.push('<div class="legrow note" id="leg-geometry" data-kind="geometry">rings = received signal (dBm), not range · direction is not measured</div>');
  rows.push('<div class="legrow note" id="leg-scope" data-kind="scope" hidden>lanes = band, channel · arcs = signal (dBm) · not direction, not range</div>');
  rows.push(block("derived"));
  rows.push(derivedRow("leg-nebula", "nebula", "channel overlap (derived, width unknown → 20 MHz)"));
  rows.push(derivedRow("leg-groups", "groups", "same ESSID"));
  rows.push(derivedRow("leg-devices", "devices", "linked radios · likely same device (heuristic)"));
  rows.push(derivedRow("leg-merge", "merge", "merged SSID · one node per ESS (count = APs)"));
  rows.push(derivedRow("leg-probes", "probes", "dashed orbit = named probe for this network (derived, not associated)"));
  // probe arcs are drawn only by drawEdgesWargames' render.probeArc block (§34) → same condition here (not the CRT toggle)
  rows.push(derivedRow("leg-arc", "arc", esc(copyFor("legArc"))));
  rows.push(derivedRow("leg-crowding", "crowding", "crowding 1–5 = the busiest channel's overlap (derived)"));
  rows.push(derivedRow("leg-deviation", "deviation", "dashed cap on a channel bar = outside its usual range (derived)"));
  rows.push(derivedRow("leg-ghost", "ghost", "dashed ring = in the baseline, not heard on the channels visited (derived)"));
  rows.push(block("operator"));
  rows.push('<div class="legrow note" data-kind="id-head">identity (APP-6, set in detail):</div>');
  for (const k of ["friend", "neutral", "hostile"]) rows.push('<div class="legrow note" data-kind="id-' + k + '">' + identitySwatch(ENCODING.identity[k]) + '<span>' + esc(ENCODING.identity[k].label) + '</span></div>');
  rows.push('<div class="legrow note" data-kind="selected">' + swFrame('<circle cx="6" cy="6" r="4.6" fill="none" stroke="var(--accent-selection)" stroke-width="1.5"/>') + '<span>selected</span></div>');
  rows.push('<div class="legrow note" data-kind="pinned">' + pinSwatch() + '<span>pinned</span></div>');
  rows.push(block("look"));
  rows.push('<div class="legrow note" id="leg-height" data-kind="height" hidden>height = band (2.4 below · 5 mid · 6 above)</div>');
  rows.push('<div id="leg-rx">' + esc(copyFor("legRx")) + '</div>');
  legendBody.innerHTML = rows.join("");
  updateLegendCounts(); renderTote();
  layoutEdges();
}
function legendVisibility() {   // D10: a mark's row exists exactly while that mark can be drawn (derived rows follow their toggle AND their data)
  const st = S._stats || { groups: 0, probing: 0, apsTotal: 0 };
  const vis = (id, on) => { const e = el(id); if (e) e.hidden = !on || (scopeOn && /^leg-(nebula|groups|devices|merge|probes|arc|crowding|deviation|ghost)$/.test(id)); };
  vis("leg-nebula", S.ui.nebula && analyzer.pairs.length > 0);
  vis("leg-groups", S.ui.groups && st.groups > 0);
  vis("leg-devices", S.ui.deviceLinks && deviceClusterCount() > 0);
  vis("leg-merge", S.ui.essMerge && essMergedCount() > 0);
  vis("leg-probes", S.ui.affinity && st.probing > 0);
  vis("leg-arc", !!(THEME.render.probeArc && THEME.line.edge.style === "parabola"));
  vis("leg-crowding", st.apsTotal > 0);
  vis("leg-deviation", S.sky.dev.length > 0);
  vis("leg-ghost", S.base.ghosts + S.base.ghostsCl > 0);   // station ghosts share the mark
  vis("leg-height", S.ui.view === "3d"); vis("leg-scope", scopeOn);
  const anyDerived = ["nebula", "groups", "devices", "merge", "probes", "arc", "crowding", "deviation", "ghost"].some(k => { const e = el("leg-" + k); return e && !e.hidden; });
  vis("leg-block-derived", anyDerived);
  vis("leg-block-look", S.ui.view === "3d");
  const bo = S.ui.filters.bt && S.btOrder.length > 0 && S.perf.lod < 3, txt = (id, t) => { const e = el(id); if (e) e.textContent = t; };
  const bb = document.querySelector('[data-band="bt"]'); if (bb) bb.hidden = !S.btDoc;
  vis("leg-alert", S.alerts.some(alertNode)); vis("leg-bt", bo); vis("leg-activity", S.actN > 0); vis("leg-cue", !captureStale() && S.clientOrder.some(c => c.cue));
  txt("leg-geometry", "rings = received signal (dBm), not range · " + (bo ? "Bluetooth and Wi-Fi share the rings, not the scale · " : "") + "direction is not measured");
}
function updateLegendCounts() {
  const s = S._stats || { bands: { "2.4": 0, "5": 0, "6": 0 }, bandUnknown: 0 };
  const set = (id, v) => { const e = el(id); if (e) e.textContent = String(v); };
  set("leg-24", s.bands["2.4"]); set("leg-5", s.bands["5"]); set("leg-6", s.bands["6"]);
  const cntRow = (id, n, show) => { const r = el(id); if (r) { r.hidden = !show; r.querySelector(".cnt").textContent = String(n); } };   // a counted row, shown while its mark can be drawn
  const nr = s.randomized || 0, nu = s.bandUnknown || 0;
  cntRow("leg-random", nr, nr !== 0); cntRow("leg-band-unknown", nu, nu !== 0);
  const bs = btStats(), lb = el("leg-bt");
  if (lb) { lb.querySelector(".cnt").textContent = String(bs ? bs.addresses : 0); el("leg-bt-sub").textContent = bs ? "addresses heard in the last " + bs.hold / 60 + " min" + (bs.window ? " (" + bs.window + "-s scans)" : "") + " · filled = fixed address · one hollow mark = rotating addresses of one company in one ring · key 4, not X" : ""; }
  const lc = el("leg-random-cl"), kc = s.clouds || 0; if (lc) lc.textContent = kc ? " · " + (s.inClouds || 0) + " in " + kc + (kc === 1 ? " cloud" : " clouds") : "";
  for (const k of Object.keys(ENCODING.security)) cntRow("leg-" + k, S.security[k], S.security[k] > 0);   // D10: a security class without an AP has no mark on the canvas
  // D1: the freshness rows exist exactly while a dated node (AP or station) is drawn; a tier the collector window cannot
  // reach is dropped. "undated" counts APs only, and only next to dated ones: a station without last_seen is the norm on
  // every source but recon.db, so it would be noise, while an undated AP among dated ones is worth a row.
  const fv = s.freshVis || freshZero(), fvc = s.freshVisCl || freshZero(), reach = freshReach();
  const tierN = (i) => fv["t" + i] + fvc["t" + i], dated = tierN(0) + tierN(1) + tierN(2) + tierN(3) > 0;
  for (let i = 0; i < 4; i++) cntRow("leg-fresh-" + i, tierN(i), dated && reach[i]);
  cntRow("leg-fresh-u", fv.undated, dated && fv.undated > 0);
  for (const id of ["leg-fresh-sep", "leg-fresh-h"]) { const e = el(id); if (e) e.hidden = !dated; }
  legendVisibility();
}
function buildHelp() {
  helpList.innerHTML = KEYS.map(k => '<dt><kbd>' + esc(k.key) + '</kbd></dt><dd>' + esc(k.desc) + '</dd>').join("");
  for (const k of KEYS) if (k.btn) { const b = el(k.btn); if (b) b.title = k.desc + " [" + k.key + "]"; }   // §9.6 KEYS = single source for titles
}
function toggleHelp(on) {
  S.ui.help = on === undefined ? !S.ui.help : !!on;
  if (S.ui.help && !S.ui.panels) setPanels(true);   // the overlay is a panel
  help.hidden = !S.ui.help; S.dirty = true;
  if (phoneOn) layoutEdges();
}
function positionTip(n, mx, my) {
  tip.style.left = (mx || n.sx) + "px"; tip.style.top = (my || n.sy) + "px"; tip.style.opacity = "1";
}
function hideTip() { tip.style.opacity = "0"; }
function bandChip(band) { return '<span class="chip" style="background:var(--band-' + (band === "2.4" ? "24" : band) + ')"></span>'; }
function apChan(ap) {
  let s = fmtBand(ap.band);
  if (ap.channel != null) s += " · ch " + ap.channel;
  s += ap.width != null ? " · " + ap.width + " MHz" : " · 20 MHz assumed";
  return s;
}
function bubbleSummary(b) {
  const parts = [b.n + " clients"];
  if (b.meanRssi != null) parts.push("mean " + b.meanRssi + " dBm");
  for (const [v, c] of b.vendors.slice(0, 3)) parts.push(v + " " + c);
  if (b.randomized) parts.push(b.randomized + " randomised");
  return parts.join(" · ");
}
function probeWords(list, max) {   // a station's probes in one wording: wildcard probes are dropped at every source, so only named ones exist
  if (!list || !list.length) return "no named probe heard";
  const l = max && list.length > max ? list.slice(0, max).concat("+" + (list.length - max)) : list;
  return (list.length === 1 ? "named probe: " : "named probes: ") + l.join(", ");
}
function probeCell(list) { return esc(probeWords(list)) + (list && list.length ? ' <span style="color:var(--ink-muted)">' + esc(copyFor("probeHint")) + '</span>' : ""); }
function btTip(k) {   // §3.5 the tooltip line (plain text)
  return "Bluetooth LE · " + (k.companyName || (k.company != null ? "company id " + k.company : "company not advertised")) + " · " + (k.rot ? k.n + " rotating address" + (k.n > 1 ? "es · " + k.m[0].rssi + " dBm strongest" : " · " + k.rssi + " dBm") + " · not a device count" : k.rssi + " dBm · " + k.m[0].addr_type.replace("random-", "") + " address · last heard in a window " + fmtAge(S.generated - k.lastSeen));
}
function showTip(n) {
  const kv = (k, v, cls = "v") => '<span class="k">' + k + '</span><span class="' + cls + '">' + v + '</span>';   // one row of the tooltip grid
  let html = "";
  if (n.kind === "bt") html = '<div class="ssid">' + esc(btTip(n)) + "</div>";
  else if (n.kind === "cloud") {   // §8.8a
    html += '<div class="ssid">random cloud</div><div class="sub">' + esc(n.n + " randomised addresses" + (n.cadenceS != null && !cloudMixed(n) ? " · " + cadText(n.cadenceS) : "")) + '</div><div class="grid">';
    html += kv("Signal", esc(fmtSignal(n.rssi) + " · range " + n.rssiMin + " to " + n.rssiMax + " dBm")) + kv("Heard", esc(heardWord(n)));
    html += kv("Probes", esc(probeWords(n.probes)));
    html += '</div>';
  } else if (n.kind === "bubble") {
    html += '<div class="ssid">density bubble</div><div class="sub">' + esc(bubbleSummary(n)) + '</div>';
    const macs = n.members.slice(0, 8).map(m => esc(fmtMac(m))).join("<br>");
    if (macs) html += '<div class="grid">' + kv("MACs", macs, "v mono") + '</div>';
  } else if (n.kind === "ap") {
    const al = aliasOf(n.id), name = al ? '<div class="ssid">' + esc(al) + '</div>' : n.hidden ? '<div class="ssid hidden">(hidden SSID)</div>' : '<div class="ssid">' + esc(n.ssidKnown || n.ssid) + '</div>';
    html += name + '<div class="sub">' + esc(n.bssid) + (al && !n.hidden ? " · " + esc(n.ssidKnown || n.ssid) : "") + (n.hid ? " · invisible characters removed" : "") + '</div><div class="grid">';
    html += kv("Vendor", esc(n.vendor || "—"), "v mono") + kv("Band", bandChip(n.band) + apChan(n)) + kv("Signal", esc(fmtSignal(n.rssi)));
    if (n.freshTier != null) html += kv("Heard", esc(ENCODING.fresh.words[n.freshTier]));
    html += kv("Security", esc(n.security || ENCODING.security[n.sec].label)) + kv("Clients", n.clientCount);
    const ov = overlapText(n, 2); if (ov) html += kv("Overlaps", esc(ov));
    if (n.groupKey) { const g = S.groups.get(n.groupKey); if (g && g.members.length >= 2) html += kv("Group", esc(g.key + " · " + g.members.length + " BSSIDs")); }
    const dev = S.devices.get(S.deviceOf.get(n.id));
    if (dev) html += kv("Device", esc("likely same device · " + dev.memberIds.length + " radios · " + dev.bands.filter(b => b !== "unknown").join("/") + " GHz"));
    const ec = S.essClusters.get(S.essOf.get(n.id));
    if (ec) html += kv("ESS", esc(ec.ssid + " · " + ec.apCount + " APs / " + ec.deviceIds.length + " devices"));
    html += '</div>';
  } else {
    html += '<div class="ssid">client · ' + clientOrbitText(n) + '</div><div class="sub">' + esc(n.mac) + '</div><div class="grid">';
    html += kv("Vendor", n.randomized ? "randomised" : esc(n.vendor || "—"), "v mono");
    html += kv("Probes", esc(probeWords(n.probes, 3)));
    html += kv("Signal", esc(fmtSignal(n.rssi))) + '</div>';
  }
  tipBody.innerHTML = html; tip.style.opacity = "1";
  // mini-sparkline for APs with ≥3 samples — persistent canvas, drawn only on hover change
  const h = n.kind === "ap" ? S.hist.get(n.id) : null;
  if (h && h.n >= 3) { tipSpark.hidden = false; drawSparkline(tipSpark, h, bandColorOf(n.band), { axis: false }); }
  else tipSpark.hidden = true;
}
function overlapText(ap, max) {   // §8.2 "SSID (co-channel, ch 6) · SSID (adjacent, ch 8 · 40 MHz)"; "derived" suffix when assumed
  if (!ap.interfere || !ap.interfere.length) return "";
  const parts = []; let anyAssumed = false;
  for (const it of ap.interfere.slice(0, max || 2)) {
    const o = S.aps.get(it.id); if (!o) continue;
    const nm = o.ssidKnown || o.ssid || o.bssid;
    let s = nm + " (" + (it.kind === "co" ? "co-channel" : "adjacent") + ", ch " + o.channel + (o.width != null ? " · " + o.width + " MHz" : "") + ")";
    if (o.width == null || ap.width == null) anyAssumed = true;
    parts.push(s);
  }
  if (!parts.length) return "";
  return parts.join(" · ") + (anyAssumed ? " · derived, width unknown → 20 MHz" : "");
}
function lastSeenAge(n) { if (!(n.last_seen > 0) || S.generated == null) return null; return S.generated - n.last_seen; }   // capture-relative; D1: a zero stamp is no time
function row(k, v, cls) { return '<tr><th>' + esc(k) + '</th><td' + (cls ? ' class="' + cls + '"' : '') + '>' + v + '</td></tr>'; }
function cloudSheet(kc) {   // §8.8a the sheet of a random cloud: an estimate from signal and timing; it never counts devices
  const g = S.generated;
  let body = '<div class="obsnote">' + (kc.kept ? 'Probably the same nearby device as before, though its rhythm is no longer clear: the addresses still here are kept together.' : cloudMixed(kc) ? 'Possibly one or more nearby devices changing their address: the same signal, heard in bursts that keep no one rhythm.' : 'Probably one nearby device changing its address: the same signal, heard in bursts at a steady rhythm.') + ' An estimate from signal and timing only; it does not count devices.</div><table>';
  body += row("Addresses", esc(kc.n + " · randomised (locally administered)"));
  body += row("Signal", esc(fmtSignal(kc.rssi) + " · range " + kc.rssiMin + " to " + kc.rssiMax + " dBm"));
  body += row("Rhythm", esc((cloudMixed(kc) ? "no one rhythm · " : kc.cadenceS != null ? cadText(kc.cadenceS) + " · " : "") + kc.bursts + (kc.bursts === 1 ? " burst" : " bursts")));
  body += row("First heard", esc(fmtAge(g != null && kc.first != null ? g - kc.first : null)));
  body += row("Last heard", esc(fmtAge(g != null && kc.last != null ? g - kc.last : null)));
  body += row("Freshness", esc(heardWord(kc)));
  body += row("Probes", probeCell(kc.probes));
  body += '</table><div class="chips"><button class="chip" id="cloud-show">Show the addresses</button></div><div class="cloud-members" style="max-height:180px;overflow:auto;margin-top:8px">';
  const ms = kc.members.map(m => S.clients.get(m)).filter(Boolean).sort((a, b) => (b.last_seen ?? -Infinity) - (a.last_seen ?? -Infinity) || cmpStr(a.mac, b.mac));
  for (const c of ms.slice(0, CLOUD.listMax)) body += '<div class="legrow" style="cursor:pointer" data-member="' + esc(c.mac) + '"><span class="mono">' + esc(fmtMac(c.mac)) + '</span> · ' + (c.rssi != null ? c.rssi + " dBm" : "n/a") + ' · ' + esc(fmtAge(lastSeenAge(c))) + '</div>';
  if (ms.length > CLOUD.listMax) body += '<div class="obsnote">first ' + CLOUD.listMax + ' shown</div>';
  return body + '</div><div class="obsnote">Random [X]: one node per cloud, one by one, or hidden. Enter shows the addresses of the selected cloud again.</div>';
}
function openDetail(id) {
  const opening = id !== detailShown;
  if (opening) { detailShown = id; detail.scrollTop = 0; }   // another node opens at the top; a re-open of the same one (poll, theme, toggle) keeps the reader's offset
  const bb = S.bubbles.get(id), kc = bb ? null : S.clouds.get(id);   // the two aggregates, a density bubble (§4.6) and a random cloud (§8.8a): one sheet with a member list
  if (bb || kc) {
    detail.hidden = false; detailSpark.hidden = true;
    const title = kc ? kc.n + " randomised addresses" : bb.n + " clients", expand = () => kc ? expandCloud(id) : expandBubble(id);
    detailTitle.textContent = title;
    let body;
    if (kc) body = cloudSheet(kc);
    else {
      body = "<table>";
      body += row("Members", String(bb.n));
      body += row("Mean signal", bb.meanRssi != null ? bb.meanRssi + " dBm" : "—");
      if (bb.vendors.length) body += row("Vendors", esc(bb.vendors.slice(0, 5).map(v => v[0] + " (" + v[1] + ")").join(" · ")));
      if (bb.randomized) body += row("Randomised", String(bb.randomized));
      body += "</table>";
      body += '<div class="bubble-members" style="max-height:180px;overflow:auto;margin-top:8px">';
      for (const m of bb.members) { const c = S.clients.get(m); if (!c) continue; body += '<div class="legrow" style="cursor:pointer" data-member="' + esc(m) + '"><span class="mono">' + esc(fmtMac(m)) + '</span> · ' + (c.randomized ? "randomized" : esc(c.vendor || "—")) + ' · ' + (c.rssi != null ? c.rssi + " dBm" : "n/a") + '</div>'; }
      body += '</div>';
    }
    detailBody.innerHTML = body;
    if (!kc || opening) expand();   // a cloud expands when its sheet opens, not again when a poll re-opens it
    for (const rowEl of detailBody.querySelectorAll("[data-member]")) rowEl.addEventListener("click", () => { const mid = rowEl.getAttribute("data-member"); expand(); S.pinned.add(mid); select(mid); });
    if (kc) {
      const sb = el("cloud-show"); if (sb) sb.addEventListener("click", expand);
      if (kc.hist.n >= 2) { if (sparkFocus.id !== id) sparkFocus = { id, cross: -1 }; detailSpark.hidden = false; drawSparkline(detailSpark, kc.hist, THEME.render.clientCore, { axis: true, cross: sparkFocus.cross }); }
      else sparkFocus = { id: null, cross: -1 };
    }
    layoutEdges();
    return title;
  }
  const n = S.aps.get(id) || S.clients.get(id); if (!n) { closeDetail(); return null; }
  detail.hidden = false;
  const localRows = (withLast) => {   // history, last seen, freshness, then identity source and alias / notes / tags (this browser only): the same for an AP and a station
    let t = "";
    const hh = S.hist.get(n.id);
    if (hh && hh.n) { const info = STARCHORUS.hist(n.id); if (info) t += row("History", esc("min " + (info.min ?? "—") + " · max " + (info.max ?? "—") + (withLast ? " · last " + (info.last ?? "—") : "") + " · " + info.n + " samples")); }
    t += row("Last seen", n.last_seen != null ? esc(fmtAge(lastSeenAge(n))) : "—");
    t += row("Freshness", esc(heardWord(n)));
    const nt = S.notes.get(n.id) || { a: "", n: "", t: [] };
    if (identitySource(n.id) === "rule-matched") t += row("Identity", esc(identityOf(n.id) + " (rule-matched)"));
    return t + '<tr><th>Alias</th><td><input id="nt-a" maxlength="24" value="' + esc(nt.a) + '"></td></tr><tr><th>Notes</th><td><input id="nt-n" maxlength="120" value="' + esc(nt.n) + '"></td></tr><tr><th>Tags</th><td><input id="nt-t" maxlength="52" placeholder="up to 4, comma separated" value="' + esc(nt.t.join(", ")) + '"></td></tr>';
  };
  let title, body = "<table>";
  if (n.kind === "ap") {
    title = n.hidden ? "(hidden SSID)" : (n.ssidKnown || n.ssid || "(hidden SSID)");
    detailTitle.textContent = title;
    body += row("BSSID", esc(n.bssid), "mono");
    if (n.hid) body += row("SSID", "invisible characters removed");
    body += row("Vendor", esc(n.vendor || "—"));
    body += row("Band", esc(fmtBand(n.band)));
    body += row("Channel", n.channel != null ? String(n.channel) : "—");
    body += row("Frequency", n.freq != null ? n.freq + " MHz" : "—");
    body += row("Width", n.width != null ? n.width + " MHz" : "— (20 MHz assumed for overlap)");
    body += row("PHY", '<span class="est">' + esc(phyEstimate(n)) + '</span>');
    body += row("Max rate", n.rate != null ? n.rate + " Mbit/s" : "—");
    body += row("Caps", n.caps && n.caps.length ? esc(n.caps.join(" · ")) : "—");
    body += row("Security", esc((n.security || ENCODING.security[n.sec].label) + " (" + n.sec + ")"));
    body += row("PMF", '<span class="est" title="802.11w, derived from the security class or the 6 GHz band">' + esc(pmfDerived(n)) + '</span>');
    if (n.akm && n.akm.length) body += row("AKM", esc(n.akm.join(" · ")));   // what the collector decoded from libwifi's encryption_info
    if (n.cipher && (n.cipher.group || (n.cipher.pairwise && n.cipher.pairwise.length))) body += row("Cipher", esc([n.cipher.group ? "group " + n.cipher.group : "", n.cipher.pairwise && n.cipher.pairwise.length ? "pairwise " + n.cipher.pairwise.join(" · ") : ""].filter(Boolean).join(" · ")));
    if (n.auth && n.auth.length) body += row("Auth scheme", esc(n.auth.join(" · ")));
    if (n.respondedSsids) body += row("Answers for", esc(n.respondedSsids + " different SSIDs (multi-SSID responder; a count, no names)"));
    if (n.packets != null) body += row("Frames", esc(n.packets + " (as reported by the source)"));
    body += row("Clients", String(n.clientCount));
    body += row("Signal", n.rssi != null ? esc(fmtSignal(n.rssi)) : "—");
    body += localRows(true);
    const cl = S.chg.get(n.id);   // what changed on this AP since this source was first read (DS channel, security class, SSID, band)
    if (cl && cl.length) body += row("Changes", esc(cl.map(c => (c.kind === "channel" ? "ch " : c.kind + " ") + (c.from == null || c.from === "" ? "—" : c.from) + " → " + (c.to == null || c.to === "" ? "—" : c.to)).join(" · ")));
    if (S.ui.baselineDiff && S.baseline && n.baseState) body += row("Baseline", esc(n.baseState === "new" ? "not in the baseline" : n.baseState === "changed" ? "changed against the baseline" : "as in the baseline"));
    if (n.revealAt != null && n.revealAt > 0) body += row("Name revealed", esc(fmtAge(S.clock - n.revealAt)));
    body += row("Beacons", n.beacons != null ? String(n.beacons) : "—");
    const ov = overlapText(n, 3); body += row("Overlaps", ov ? esc(ov) : "—");
    const gk = n.groupKey ? S.groups.get(n.groupKey) : null;
    if (gk && gk.members.length >= 2) { const list = gk.members.map(id => { const a = S.aps.get(id); return a ? ((a.ssidKnown || a.ssid || a.bssid) + " (" + fmtBand(a.band) + (a.channel != null ? " ch " + a.channel : "") + ")") : id; }).join(" · "); body += row("Group", esc(list)); }
    if (n.channel != null && n.band !== "unknown") { const m = analyzer.channels[n.band], e = m && m.get(n.channel); if (e) body += row("Channel use", esc("ch " + n.channel + " · " + fmtBand(n.band) + " · " + e.count + " APs · " + (e.assumed ? "20 MHz assumed" : e.widthMax + " MHz"))); }
    const dev = S.devices.get(S.deviceOf.get(n.id));
    if (dev) {
      body += row("Device", esc("likely same device · " + dev.memberIds.length + " radios (heuristic)"));
      const rlist = dev.memberIds.map(id => { const a = S.aps.get(id); return a ? (a.bssid + " · " + fmtBand(a.band) + (a.channel != null ? " ch " + a.channel : "")) : id; }).join(" · ");
      body += row("Radios", esc(rlist));
      const sbase = ssidBase(n.ssidKnown ?? n.ssid);
      if (sbase) body += row("SSID base", esc(sbase));
      body += row("Vendor (device)", esc(dev.vendor || "—"));
      if (dev.reason.length) body += row("Why grouped", esc(dev.reason.join(" · ")));
    }
    const ec = S.essClusters.get(S.essOf.get(n.id));
    if (ec) {
      body += row("ESS (SSID)", esc(ec.ssid + " · " + ec.apCount + " APs · " + ec.deviceIds.length + " devices"));
      const elist = ec.memberIds.map(id => { const a = S.aps.get(id); return a ? (a.bssid + " (" + fmtBand(a.band) + ", " + (a.rssi != null ? a.rssi + " dBm" : "n/a") + ")") : id; }).join(" · ");
      body += row("ESS members", esc(elist));
      let strong = null; for (const id of ec.memberIds) { const a = S.aps.get(id); if (a && (strong == null || rssiOf(a) > rssiOf(strong))) strong = a; }
      if (strong) body += row("Strongest", esc((strong.rssi != null ? strong.rssi + " dBm" : "n/a") + " · " + strong.bssid));
      const vend = Array.from(new Set(ec.memberIds.map(id => { const a = S.aps.get(id); return a && a.vendor; }).filter(Boolean)));
      if (vend.length) body += row("ESS vendors", esc(vend.join(" · ")));
    }
  } else {
    title = n.mac; detailTitle.textContent = title;
    body += row("MAC", esc(n.mac), "mono");
    body += row("Vendor", n.randomized ? "randomised (locally administered)" : esc(n.vendor || "—"));
    body += row("Signal", esc(fmtSignal(n.rssi)));
    body += row("Orbit", clientOrbitText(n));
    body += row("Probes", probeCell(n.probes));
    if (n.packets != null) body += row("Frames heard", esc(n.fps != null ? "about " + n.fps.toFixed(1) + "/s over the last " + Math.round(n.pk[n.pk.length - 1][0] - n.pk[0][0]) + " s" : "— (one capture so far)"));   // §3.8
    body += localRows(false);
  }
  body += "</table>";
  const cur = identityOf(n.id);   // any observed node (AP or station) can be classified
  body += '<div class="idlabel">Identity (APP-6 · you classify it)</div><div class="idrow">' +
    ["unknown", "friend", "neutral", "hostile"].map(k => { const e = ENCODING.identity[k]; return '<button class="idbtn' + (cur === k ? " on" : "") + '" data-identity="' + k + '" style="--idc:' + e.color + '">' + esc(e.btn) + '</button>'; }).join("") +
    '</div>';
  const ae = document.activeElement, keepNt = ae && /^nt-[ant]$/.test(ae.id || "") && detailBody.contains(ae) && detailBody.getAttribute("data-nt") === n.id ? { id: ae.id, v: ae.value, s: ae.selectionStart, e: ae.selectionEnd } : null;   // a poll re-opens the sheet: typed text must survive
  detailBody.innerHTML = body; detailBody.setAttribute("data-nt", n.id);
  if (keepNt) { const i = detailBody.querySelector("#" + keepNt.id); if (i) { i.value = keepNt.v; i.focus(); try { i.setSelectionRange(keepNt.s, keepNt.e); } catch (e) { /* not selectable */ } } }
  for (const b of detailBody.querySelectorAll("[data-identity]")) b.addEventListener("click", () => setIdentity(n.id, b.getAttribute("data-identity")));
  // alias / notes / tags: typed text stays out of the key handlers, saved on change (this browser only)
  for (const [id, f] of [["nt-a", "alias"], ["nt-n", "note"], ["nt-t", "tags"]]) {
    const inp = detailBody.querySelector("#" + id); if (!inp) continue;
    inp.addEventListener("keydown", (e) => e.stopPropagation());
    inp.addEventListener("change", () => { notesSet(n.id, { [f]: f === "tags" ? inp.value.split(",") : inp.value }); renderInv(); });
  }
  const h = n.kind === "ap" ? S.hist.get(n.id) : null;
  if (h && h.n >= 1) { detailSpark.hidden = false; if (sparkFocus.id !== n.id) sparkFocus = { id: n.id, cross: -1 }; drawSparkline(detailSpark, h, bandColorOf(n.band), { marks: changeMarks(n.id), axis: true, cross: sparkFocus.cross }); }
  else { detailSpark.hidden = true; sparkFocus = { id: null, cross: -1 }; }
  layoutEdges();
  return title;
}
function closeDetail() { detail.scrollTop = 0; detail.hidden = true; detailSpark.hidden = true; sparkFocus = { id: null, cross: -1 }; detailShown = null; if (S.locked) { S.locked = null; S.dirty = true; } layoutEdges(); }
function histSamples(h) { const s = [], t = []; for (let i = 0; i < h.n; i++) { const idx = (h.head - h.n + i + HISTORY_LEN * 2) % HISTORY_LEN; s.push(h.buf[idx]); t.push(h.ts[idx]); } return { s, t }; }
function clientOrbitText(n) {   // escaped, for the two innerHTML templates (tooltip, detail)
  if (n.free) return "unassociated";
  const ap = S.aps.get(n.parent) || {}, name = esc(ap.ssidKnown || ap.ssid || n.parent);
  return n.affinity ? "probe orbit · looking for " + esc(n.probeVia || "") + " · not associated (derived)" : "orbits " + name;
}
function changeMarks(id) { const a = S.chg.get(id); return a ? a.map(c => c.t).filter(t => t != null) : null; }   // capture times of an AP's logged changes
function drawSparkline(canvas, h, color, opts) {   // §8.1 persistent-canvas RSSI sparkline (no per-hover allocation)
  opts = opts || {}; const CW = canvas.width, CH = canvas.height, ctx = canvas.getContext("2d");
  ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, CW, CH);
  if (!h || h.n < 1) return;
  const { s, t } = histSamples(h);
  const yMin = -100, yMax = -20, axis = !!opts.axis;
  const padL = axis ? 22 : 2, padR = axis ? 22 : 2, padT = 3, padB = axis ? 11 : 3;
  const x0 = padL, x1 = CW - padR, y0 = padT, y1 = CH - padB;
  const xOf = (i) => s.length <= 1 ? (x0 + x1) / 2 : x0 + (x1 - x0) * i / (s.length - 1);
  const yOf = (v) => y1 - (clamp(v, yMin, yMax) - yMin) / (yMax - yMin) * (y1 - y0);
  ctx.strokeStyle = THEME.line.hairline; ctx.lineWidth = 1;
  for (const gv of [-80, -50]) { const y = Math.round(yOf(gv)) + 0.5; ctx.beginPath(); ctx.moveTo(x0, y); ctx.lineTo(x1, y); ctx.stroke(); }
  if (axis) { ctx.fillStyle = THEME.ink.muted; ctx.font = "400 8px " + THEME.font.ui; ctx.textBaseline = "middle"; ctx.textAlign = "right"; ctx.fillText("-50", x0 - 3, yOf(-50)); ctx.fillText("-80", x0 - 3, yOf(-80)); }
  // segments (break on -128 gaps); area wash then line
  let seg = [];
  const flush = () => {
    if (!seg.length) return;
    ctx.beginPath(); ctx.moveTo(seg[0][0], y1); for (const p of seg) ctx.lineTo(p[0], p[1]); ctx.lineTo(seg[seg.length - 1][0], y1); ctx.closePath();
    ctx.globalAlpha = THEME.chart.areaAlpha; ctx.fillStyle = color; ctx.fill(); ctx.globalAlpha = 1;
    ctx.beginPath(); ctx.moveTo(seg[0][0], seg[0][1]); for (let i = 1; i < seg.length; i++) ctx.lineTo(seg[i][0], seg[i][1]);
    ctx.strokeStyle = color; ctx.lineWidth = THEME.chart.lineWidthPx; ctx.lineJoin = "round"; ctx.lineCap = "round"; ctx.stroke();
    seg = [];
  };
  for (let i = 0; i < s.length; i++) { if (s[i] === -128) { flush(); continue; } seg.push([xOf(i), yOf(s[i])]); }
  flush();
  if (opts.marks && opts.marks.length) {   // a small triangle on the axis at every capture where this AP's channel/security/SSID/band changed
    ctx.fillStyle = THEME.ink.secondary;
    for (const mt of opts.marks) { const i = t.indexOf(mt); if (i < 0) continue; const mx = xOf(i); ctx.beginPath(); ctx.moveTo(mx, y1 - 5); ctx.lineTo(mx - 3, y1); ctx.lineTo(mx + 3, y1); ctx.closePath(); ctx.fill(); }
  }
  // endpoint marker on last valid sample
  let lastIdx = -1; for (let i = s.length - 1; i >= 0; i--) if (s[i] !== -128) { lastIdx = i; break; }
  if (lastIdx >= 0) {
    const mx = xOf(lastIdx), my = yOf(s[lastIdx]);
    ctx.beginPath(); ctx.arc(mx, my, THEME.chart.markerRadiusPx, 0, Math.PI * 2); ctx.fillStyle = color; ctx.fill();
    ctx.strokeStyle = THEME.surface.base; ctx.lineWidth = THEME.chart.markerRingPx; ctx.stroke();
    if (axis) { ctx.fillStyle = THEME.ink.secondary; ctx.font = "400 9px " + THEME.font.ui; ctx.textAlign = "left"; ctx.textBaseline = "middle"; ctx.fillText(s[lastIdx] + " dBm", Math.min(mx + 6, CW - 2), my); }
  }
  // crosshair (keyboard/hover on detail)
  if (axis && opts.cross != null && opts.cross >= 0 && opts.cross < s.length && s[opts.cross] !== -128) {
    const cx = xOf(opts.cross), cy = yOf(s[opts.cross]);
    ctx.strokeStyle = THEME.ink.secondary; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(cx + 0.5, y0); ctx.lineTo(cx + 0.5, y1); ctx.stroke();
    ctx.beginPath(); ctx.arc(cx, cy, 3, 0, Math.PI * 2); ctx.fillStyle = THEME.ink.primary; ctx.fill();
  }
}
function bandColorOf(band) { return TD.bandCore[band] || TD.bandCore.unknown; }
// D15 edge-panel layout (theme-free; reads only DOM boxes, never THEME). CSS owns the anchors (edge rule with
// --chrome-top/--chrome-bot); this resolves collisions by publishing --lay-* variables on :root:
// #stats centred in the free top gap, compact + wrapped (balanced rows) when one line does not fit; #legend
// capped below the top panels over its column and scrolls; #chanbar between legend and controls, docked above
// #controls when that gap is < chanMinPx, else collapsed; #detail between the top panels and the bottom-right
// panels (a docked channel bar yields to the detail when it would leave < detailMinPx). Phone mode: phoneLayout() only, no --lay-* (§9.8).
const edgeState = { stats: "line", chan: "none", legendMaxH: null, detailTop: null, detailMaxH: null };
const LAY_VARS = ["--lay-stats-x", "--lay-stats-w", "--lay-legend-maxh", "--lay-chan-x", "--lay-chan-w", "--lay-chan-b", "--lay-detail-top", "--lay-detail-maxh"];
const EDGE_SCROLLERS = ["legend-body", "obs-body", "inv-body", "home-body", "air-body", "time-body", "rec-body", "detail"].map(el).filter(Boolean);   // what scrolls inside a capped panel
function statsFitWidth(cells, room) {   // smallest content width that keeps the minimum row count (greedy wrap → balanced rows)
  const rows = (w) => { let n = 1, x = 0; for (const c of cells) { if (x > 0 && x + c > w) { n++; x = 0; } x += c; } return n; };
  const maxC = Math.max(0, ...cells); if (room <= maxC) return maxC;
  const need = rows(room); let best = room;
  for (let i = 0; i < cells.length; i++) { let s = 0; for (let j = i; j < cells.length; j++) { s += cells[j]; if (s >= maxC && s < best && rows(s) <= need) best = s; } }
  return best;
}
function fitMasthead() {   // the name under a wide face or a minimum font size: tighter letters, then room for the clock or the lamps (CSS above)
  const mh = el("masthead"), mb = el("mast-brand"); if (!mh || !mb || mb.parentElement !== mh) return;
  mh.classList.remove("tight", "clear-right");
  // the extent of dot, name and version on the first line: not the flex box (as wide as the panel) and not the cursor, which may touch the lamps
  const ext = () => { const r = document.createRange(); r.setStartBefore(mb.firstChild); r.setEndAfter(mb.childNodes[1]); const nm = r.getBoundingClientRect(), v = el("mast-ver"), vr = v ? v.getBoundingClientRect() : null;
    return (vr && vr.top < nm.bottom) ? { left: nm.left, right: Math.max(nm.right, vr.right), top: nm.top, bottom: nm.bottom } : nm; };
  if (ext().right > mb.getBoundingClientRect().right + 0.5 || mb.scrollWidth > mb.clientWidth + 1) mh.classList.add("tight");
  const deco = mh.querySelector(".plotclock, .lamps");   // the badge sits above the cap height and is left alone
  if (deco) { const a = ext(), d = deco.getBoundingClientRect(); if (a.right > d.left + 1 && a.top < d.bottom && a.bottom > d.top) mh.classList.add("clear-right"); }
}
function layoutEdges() {
  const rs = document.documentElement.style, vw = window.innerWidth, vh = window.innerHeight, G = EDGE.gapPx;
  const set = (k, v) => { rs.removeProperty(k); rs.setProperty(k, v); };   // re-appended, see the note below
  const boxOf = (e) => { if (!e || e.hidden || !e.getClientRects().length) return null; const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0 ? r : null; };
  const over = (list, a, b) => list.filter(r => r && r.right > a && r.left < b);
  const chan = el("chanbar");
  statsEl.classList.remove("fit");
  edgeState.stats = "line"; edgeState.chan = "none"; edgeState.legendMaxH = edgeState.detailTop = edgeState.detailMaxH = null;
  if (phoneOn) { for (const k of LAY_VARS) rs.removeProperty(k); edgeState.stats = edgeState.chan = "phone"; phoneLayout(false); drawChannelBar(); return edgeState; }   // §9.8: --ph-* only
  for (const k of PH_VARS) rs.removeProperty(k);
  // No variable is off :root at a measuring reflow: one that changes there restyles the whole page, one that is back with the
  // value it had restyles :root alone. .raw lays a panel out as without its variables, and comes off where the pass sets them
  // (or removes them for good) — so every box below is read in the state a pass that starts from a bare :root reads it in.
  fitMasthead();
  const scr = EDGE_SCROLLERS.map(e => e.scrollTop);   // measured without their caps, the scrollers lose their offset: keep where the reader was
  for (const e of [statsEl, legend, detail]) e.classList.add("raw");
  const mast = boxOf(el("masthead")), src = boxOf(el("source")), ctl = boxOf(el("controls"));
  // 1 · stats in the free top gap
  const lo = (mast ? mast.right : 0) + G, hi = (src ? src.left : vw) - G;
  let st = boxOf(statsEl);
  if (st) {
    let w = st.width;
    if (w > hi - lo) {
      statsEl.classList.add("fit");
      const frame = statsEl.getBoundingClientRect().width - statsEl.clientWidth;   // borders
      const cells = Array.from(statsEl.children).filter(c => !c.hidden && !c.classList.contains("ph-label")).map(c => c.getBoundingClientRect().width);
      w = Math.ceil(statsFitWidth(cells, hi - lo - frame - 1) + frame) + 1;   // +1: sub-pixel slack for the flex wrap
      set("--lay-stats-w", w + "px"); edgeState.stats = "fit";
    } else rs.removeProperty("--lay-stats-w");
    const cx = Math.max(lo + w / 2, Math.min(hi - w / 2, vw / 2));
    set("--lay-stats-x", (Math.round(cx * 2) / 2) + "px");
  } else { rs.removeProperty("--lay-stats-x"); rs.removeProperty("--lay-stats-w"); }
  statsEl.classList.remove("raw");
  if (st) st = boxOf(statsEl);
  const top = [mast, st, src];
  // 2 · legend capped below whatever sits above its column
  let leg = boxOf(legend);
  if (leg) {
    const above = over(top, leg.left, leg.right).reduce((m, r) => Math.max(m, r.bottom + G), mast ? mast.top : 20);
    const cap = Math.max(0, Math.floor(leg.bottom - above));
    set("--lay-legend-maxh", cap + "px"); edgeState.legendMaxH = cap;
  } else rs.removeProperty("--lay-legend-maxh");
  legend.classList.remove("raw");
  if (leg) leg = boxOf(legend);
  // 3 · channel bar
  let cr = null;
  if (S._stats && S._stats.apsTotal > 0 && chan) {
    const ch = parseFloat(getComputedStyle(chan).height) || 78, edgeB = ctl ? ctl.bottom : vh - 20;
    const a = leg ? leg.right + G : 20, b = ctl ? ctl.left - G : vw - 20;
    const clearOf = (l, r, t) => over(top, l, r).every(x => t >= x.bottom + G);
    if (b - a >= EDGE.chanMinPx) {
      const w = Math.min(EDGE.chanMaxPx, b - a), cx = Math.max(a + w / 2, Math.min(b - w / 2, vw / 2));
      if (clearOf(cx - w / 2, cx + w / 2, edgeB - ch)) { cr = { left: cx - w / 2, right: cx + w / 2, top: edgeB - ch, bottom: edgeB, cx, w }; edgeState.chan = "between"; }
    }
    if (!cr && ctl) {
      const w = Math.min(EDGE.chanMaxPx, Math.max(ctl.width, EDGE.chanMinPx), ctl.right - a), bottom = ctl.top - G;
      if (w >= EDGE.chanMinPx && clearOf(ctl.right - w, ctl.right, bottom - ch)) { cr = { left: ctl.right - w, right: ctl.right, top: bottom - ch, bottom, cx: ctl.right - w / 2, w }; edgeState.chan = "docked"; }
    }
    if (!cr) edgeState.chan = "collapsed";
  }
  // 4 · detail between the top panels and the bottom-right panels of its column
  const d = boxOf(detail);
  if (d) {
    const t = over(top, d.left, d.right).reduce((m, r) => Math.max(m, r.bottom + G), mast ? mast.top : 20);
    const bottomOf = (list) => over(list, d.left, d.right).reduce((m, r) => Math.min(m, r.top - G), ctl ? ctl.bottom : vh - 20);
    let bt = bottomOf([ctl, cr]);
    if (bt - t < EDGE.detailMinPx && edgeState.chan === "docked") { cr = null; edgeState.chan = "collapsed"; bt = bottomOf([ctl]); }
    edgeState.detailTop = Math.round(t); edgeState.detailMaxH = Math.max(0, Math.floor(bt - t));
    set("--lay-detail-top", edgeState.detailTop + "px"); set("--lay-detail-maxh", edgeState.detailMaxH + "px");
  } else { rs.removeProperty("--lay-detail-top"); rs.removeProperty("--lay-detail-maxh"); }
  detail.classList.remove("raw");
  if (cr) { set("--lay-chan-x", (Math.round(cr.cx * 2) / 2) + "px"); set("--lay-chan-w", Math.floor(cr.w) + "px"); set("--lay-chan-b", Math.round(vh - cr.bottom) + "px"); }
  else for (const k of ["--lay-chan-x", "--lay-chan-w", "--lay-chan-b"]) rs.removeProperty(k);
  drawChannelBar();
  EDGE_SCROLLERS.forEach((e, i) => { if (scr[i]) e.scrollTop = scr[i]; });   // clamped by the browser if the content got shorter
  return edgeState;
}
let chanHover = null;
function drawChannelBar() {   // §8.2 three small multiples (2.4 | 5 | 6), shared y-axis; only on ingest/filter/theme/resize/hover
  const box = el("chanbar"), cv = el("chan"); if (!box || !cv) return;
  const total = S._stats ? S._stats.apsTotal : 0;
  box.hidden = !(total > 0) || edgeState.chan === "collapsed";
  if (box.hidden || !box.clientWidth) { if (S.actN) { S.actN = 0; legendVisibility(); } return; }
  const cssW = box.clientWidth - (phoneOn ? 0 : 20), cssH = 66; cv.style.width = cssW + "px"; cv.style.height = cssH + "px";   // less the padding (none in the sheet)
  const d = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
  cv.width = Math.floor(cssW * d); cv.height = Math.floor(cssH * d);
  const ctx = cv.getContext("2d"); ctx.setTransform(d, 0, 0, d, 0, 0); ctx.clearRect(0, 0, cssW, cssH);
  const bands = ["2.4", "5", "6"];
  let maxCount = 1; for (const b of bands) analyzer.channels[b].forEach(e => { if (e.count > maxCount) maxCount = e.count; });
  const gap = 16, segW = (cssW - gap * 2) / 3, top = 12, botY = cssH - 12;
  let unknownN = 0; S.aps.forEach(n => { if (n.target === 1 && (n.band === "unknown" || n.channel == null)) unknownN++; });
  ctx.textBaseline = "alphabetic";
  let aMax = 0, nw = 0; if (S.act.size && S.chanMode === "bars") for (const b of bands) analyzer.channels[b].forEach((e, ch) => { aMax = Math.max(aMax, S.act.get(freqFromChannel(ch, b)) || 0); });   // §3.7 one scale for all bands
  const devSet = new Set(S.sky.dev.map(d => d.band + "/" + d.channel));   // D11: derived deviation marks (dashed cap), the same in every theme
  for (let bi = 0; bi < 3; bi++) {
    const band = bands[bi], m = analyzer.channels[band], x0 = bi * (segW + gap);
    const chans = Array.from(m.keys()).sort((a, b) => a - b);
    ctx.fillStyle = THEME.ink.muted; ctx.font = "400 9px " + THEME.font.ui; ctx.textAlign = "left";
    ctx.fillText(band + (TD.upper ? " GHZ" : " GHz"), x0, top - 3);
    ctx.strokeStyle = THEME.line.hairline; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(x0, botY + 0.5); ctx.lineTo(x0 + segW, botY + 0.5); ctx.stroke();
    if (S.chanMode === "waterfall") { drawWaterfallBand(ctx, band, x0, segW, top, botY); continue; }
    if (chans.length === 0) { ctx.fillText("—", x0, botY - 2); continue; }   // fill, font and alignment are still the band label's
    if (S.chanMode === "spectrum") { drawSpectrumBand(ctx, band, x0, segW, top, botY, devSet); continue; }
    const n = chans.length, bw = Math.max(6, Math.min(THEME.chart.barMaxPx, segW / n - THEME.chart.barGapPx));
    const step = segW / n; let peakCh = chans[0], peakCount = -1;
    for (let ci = 0; ci < n; ci++) { const ch = chans[ci], e = m.get(ch); if (e.count > peakCount) { peakCount = e.count; peakCh = ch; } }
    for (let ci = 0; ci < n; ci++) {
      const ch = chans[ci], e = m.get(ch), bx = x0 + ci * step + (step - bw) / 2;
      const h = (botY - top) * e.count / maxCount, by = botY - h;
      const hovered = chanHover && chanHover.band === band && chanHover.ch === ch;
      ctx.fillStyle = hovered ? THEME.ink.primary : bandColorOf(band);
      const r = Math.min(THEME.chart.barRadiusPx, bw / 2, h);
      ctx.beginPath(); ctx.moveTo(bx, by + h); ctx.lineTo(bx, by + r); ctx.quadraticCurveTo(bx, by, bx + r, by); ctx.lineTo(bx + bw - r, by); ctx.quadraticCurveTo(bx + bw, by, bx + bw, by + r); ctx.lineTo(bx + bw, by + h); ctx.closePath(); ctx.fill();
      if (aMax > 0) nw += drawActivity(ctx, bx + bw / 2, botY, top, S.act.get(freqFromChannel(ch, band)), aMax);
      if (devSet.has(band + "/" + ch)) { ctx.strokeStyle = THEME.ink.secondary; ctx.lineWidth = 1; ctx.setLineDash([2, 2]); ctx.beginPath(); ctx.moveTo(bx - 1, by - 3.5); ctx.lineTo(bx + bw + 1, by - 3.5); ctx.stroke(); ctx.setLineDash([]); }
      if (ch === peakCh) { ctx.fillStyle = THEME.ink.secondary; ctx.font = "400 8px " + THEME.font.ui; ctx.textAlign = "center"; ctx.fillText(String(ch), bx + bw / 2, botY + 9); }
    }
  }
  if (S.actN !== nw) { S.actN = nw; legendVisibility(); }
  const tt = el("chan-tip");
  if (chanHover && tt) { const txt = hoverChannelText(chanHover.band, chanHover.ch); if (txt) { tt.textContent = txt; tt.style.display = "block"; } else tt.style.display = "none"; }
  else if (tt) tt.style.display = "none";
  box.title = (S.chanMode === "spectrum" ? "Spectrum: each access point as a bracket over its width at its signal; tint = DFS channels; dot = strongest; tick = peak hold" : S.chanMode === "waterfall" ? "Waterfall: channel by time from the recording; brighter = stronger" : "APs per channel") + " · widths assumed 20 MHz where unknown" + (unknownN ? " · ? band: " + unknownN : "") + (S.sky.dev.length ? " · dashed cap = outside the usual range for this sky (derived)" : "");
}
function drawActivity(ctx, x, botY, top, share, aMax) {   // §3.7 whisker: share / aMax of the bar, 2 px at least
  if (!(share > 0)) return 0;
  const h = Math.max(2, (botY - top) * share / aMax);
  ctx.globalAlpha = 0.85; ctx.fillStyle = THEME.ink.primary; ctx.fillRect(x - 1.5, botY - h, 3, h); ctx.globalAlpha = 1; return 1;
}
function spectrumX(band, f, x0, segW) { const b = BAND_HZ[band]; return x0 + (f - b[0]) / (b[1] - b[0]) * segW; }
function drawSpectrumBand(ctx, band, x0, segW, top, botY, devSet) {   // every AP as a bracket over its span at its signal; DFS tint, max signal, peak hold, D11 deviation cap (theme tokens only)
  const yOf = (dbm) => botY - rssiT(dbm) * (botY - top), col = bandColorOf(band), mdl = channelModel().bands[band];
  if (band === "5") {   // DFS tint (static table)
    ctx.fillStyle = THEME.line.hairlineSoft; ctx.globalAlpha = 0.6;
    for (const r of mdl) if (r.dfs) { const xa = spectrumX(band, r.freq - 10, x0, segW), xb = spectrumX(band, r.freq + 10, x0, segW); ctx.fillRect(xa, top, Math.max(1, xb - xa), botY - top); }
    ctx.globalAlpha = 1;
  }
  ctx.lineWidth = 1; ctx.strokeStyle = col; ctx.globalAlpha = 0.45;
  for (const ap of S.apOrder) {
    if (ap.band !== band || ap.channel == null || ap.rssi == null || S.ui.filters[band] === false) continue;
    const sp = channelSpan(ap); if (!sp) continue;
    const xa = spectrumX(band, sp[0], x0, segW), xb = spectrumX(band, sp[1], x0, segW), y = yOf(ap.rssi);
    ctx.beginPath(); ctx.moveTo(xa, botY); ctx.lineTo(xa, y); ctx.lineTo(xb, y); ctx.lineTo(xb, botY); ctx.stroke();
  }
  ctx.globalAlpha = 1;
  for (const r of mdl) {
    const cx = spectrumX(band, r.freq, x0, segW), hov = chanHover && chanHover.band === band && chanHover.ch === r.ch;
    if (r.maxDbm != null) { ctx.fillStyle = hov ? THEME.ink.primary : col; ctx.fillRect(cx - 1.5, yOf(r.maxDbm) - 1.5, 3, 3); }
    if (r.peakDbm != null && r.maxDbm != null && r.peakDbm > r.maxDbm) { ctx.strokeStyle = THEME.ink.secondary; ctx.beginPath(); ctx.moveTo(cx - 3, yOf(r.peakDbm) + 0.5); ctx.lineTo(cx + 3, yOf(r.peakDbm) + 0.5); ctx.stroke(); }
    if (devSet.has(band + "/" + r.ch)) { ctx.strokeStyle = THEME.ink.secondary; ctx.setLineDash([2, 2]); ctx.beginPath(); ctx.moveTo(cx - 5, top - 1.5); ctx.lineTo(cx + 5, top - 1.5); ctx.stroke(); ctx.setLineDash([]); }
  }
}
function drawWaterfallBand(ctx, band, x0, segW, top, botY) {   // channel × time from the recorded captures; the cell's opacity follows the strongest AP heard on that channel
  const wf = waterfallModel(band), nc = wf.channels.length, nt = wf.cols.length;
  if (!nc || !nt) { ctx.fillStyle = THEME.ink.muted; ctx.font = "400 9px " + THEME.font.ui; ctx.fillText(nt ? "—" : "no recording", x0, botY - 2); return; }
  const cw = segW / nt, rh = (botY - top) / nc, col = bandColorOf(band);
  ctx.fillStyle = col;
  for (let ci = 0; ci < nc; ci++) for (let ti = 0; ti < nt; ti++) {
    const v = wf.cells[ci][ti]; if (v == null) continue;
    ctx.globalAlpha = 0.2 + 0.8 * rssiT(v);
    ctx.fillRect(x0 + ti * cw, top + ci * rh, Math.max(1, cw), Math.max(1, rh - (rh > 3 ? 0.5 : 0)));
  }
  ctx.globalAlpha = 1;
  if (S.replay) { const x = x0 + (S.replay.i + 0.5) * cw; ctx.strokeStyle = THEME.ink.primary; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(x + 0.5, top); ctx.lineTo(x + 0.5, botY); ctx.stroke(); }
}
function chanAtPointer(clientX) {   // map a pointer x on #chan back to {band, ch}
  const cv = el("chan"); if (!cv) return null; const rect = cv.getBoundingClientRect();
  const cssW = rect.width, x = clientX - rect.left; const gap = 16, segW = (cssW - gap * 2) / 3;
  const bi = x < segW ? 0 : x < segW + gap + segW ? 1 : 2, band = ["2.4", "5", "6"][bi], x0 = bi * (segW + gap);
  const m = analyzer.channels[band], chans = Array.from(m.keys()).sort((a, b) => a - b); if (!chans.length) return null;
  const n = chans.length, step = segW / n, rel = x - x0; if (rel < 0 || rel > segW) return null;
  if (S.chanMode === "spectrum") { const b = BAND_HZ[band], f = b[0] + rel / segW * (b[1] - b[0]); let best = null, bd = Infinity; for (const ch of chans) { const fc = freqFromChannel(ch, band); if (fc != null && Math.abs(fc - f) < bd) { bd = Math.abs(fc - f); best = ch; } } return best == null ? null : { band, ch: best }; }
  if (S.chanMode === "waterfall") return null;
  const ci = Math.max(0, Math.min(n - 1, Math.floor(rel / step)));
  return { band, ch: chans[ci] };
}
el("detail-close").addEventListener("click", () => deselect());
el("t-theme").addEventListener("click", () => toggleTheme());
el("t-view").addEventListener("click", () => { setView(S.ui.view === "3d" ? "2d" : "3d"); renderCaption(); });
for (const key of Object.keys(BTN_OF)) { const b = el(BTN_OF[key]); if (b) b.addEventListener("click", () => setToggle(key, !S.ui[key])); }
el("baseline-set").addEventListener("click", () => { baselineSet(); if (!S.ui.baselineDiff) setToggle("baselineDiff", true); else { obsCompute(); renderObs(); updateStats(); } });
el("baseline-clear").addEventListener("click", () => { baselineClear(); obsCompute(); renderObs(); updateStats(); });
for (const b of document.querySelectorAll("[data-band]")) b.addEventListener("click", () => toggleBand(b.getAttribute("data-band")));
el("help-close").addEventListener("click", () => toggleHelp(false));
// §8.1 keyboard on the focusable detail sparkline: arrows/Home/End move the crosshair, Esc releases; never fires shortcuts
detailSpark.addEventListener("keydown", (e) => {
  const id = sparkFocus.id || S.locked; if (!id) return;
  const kh = S.clouds.get(id), h = S.hist.get(id) || (kh && kh.hist); if (!h || !h.n) return;
  const info = histSamples(h), last = info.s.length - 1;
  let cur = sparkFocus.cross < 0 ? last : sparkFocus.cross;
  const k = e.key;
  if (k === "ArrowLeft") cur = Math.max(0, cur - 1);
  else if (k === "ArrowRight") cur = Math.min(last, cur + 1);
  else if (k === "Home") cur = 0;
  else if (k === "End") cur = last;
  else if (k === "Escape") { e.preventDefault(); e.stopPropagation(); detailSpark.blur(); return; }
  else return;
  sparkFocus.cross = cur; e.preventDefault(); e.stopPropagation();
  const ap = S.aps.get(id);
  drawSparkline(detailSpark, h, ap ? bandColorOf(ap.band) : kh ? THEME.render.clientCore : THEME.ink.primary, { marks: ap ? changeMarks(ap.id) : null, axis: true, cross: cur });
  const v = info.s[cur];
  detailSpark.setAttribute("aria-label", "Signal history: " + (v === -128 ? "gap" : v + " dBm") + " · sample " + (cur + 1) + " of " + info.s.length);
});
function cyclePinned(dir) {   // [ / ] step through pinned nodes
  const arr = Array.from(S.pinned).filter(nodeById); if (!arr.length) return;
  let i = arr.indexOf(S.locked);
  i = i < 0 ? (dir > 0 ? 0 : arr.length - 1) : ((i + dir) % arr.length + arr.length) % arr.length;
  select(arr[i]);
}
// camera buttons (#cam-*)
const wire = (id, fn) => { const b = el(id); if (b) b.addEventListener("click", fn); };
for (const k of Object.keys(CAM_STEP)) wire("cam-" + k, () => {
  if (tS < 0.5 && (k === "in" || k === "out")) setZoom2d(S.cam.zoom2d * (k === "in" ? CFG3D.btnZoom : 1 / CFG3D.btnZoom));   // 2D: zoom about the device
  else { CAM_STEP[k](S.cam); S.cam.tween = null; }
  interacted(); S.dirty = true;
});
wire("cam-reset", () => resetCamera());
// §8.2 channel-bar hover/click (redraw only on hover change; click pins that channel's APs for 6 s)
(() => {
  const cv = el("chan"); if (!cv) return;
  cv.addEventListener("pointermove", (e) => {
    const hit = chanAtPointer(e.clientX);
    const same = hit && chanHover && hit.band === chanHover.band && hit.ch === chanHover.ch;
    if (!hit && !chanHover) return;
    if (same) return;
    chanHover = hit;
    cv.style.cursor = hit ? "pointer" : "default";
    drawChannelBar();
  });
  cv.addEventListener("pointerleave", () => { if (chanHover) { chanHover = null; drawChannelBar(); } });
  cv.addEventListener("click", (e) => {
    const hit = chanAtPointer(e.clientX); if (!hit) return;
    const m = analyzer.channels[hit.band], entry = m && m.get(hit.ch); if (!entry) return;
    // the 6 s highlight adds and later removes only the ids it pinned itself (`temp`): a pin that already existed
    // at click time survives. Known gap: re-pinning an id of `temp` inside the 6 s does not take it out of `temp`,
    // so that pin still expires with the highlight -- only the selected one (S.locked) is kept.
    const ids = entry.aps.slice(), temp = ids.filter(id => !S.pinned.has(id));
    for (const id of temp) S.pinned.add(id);
    if (ids.length) select(ids[0]);
    S.dirty = true;
    setTimeout(() => { for (const id of temp) if (S.locked !== id) S.pinned.delete(id); S.dirty = true; }, 6000);
  });
})();

// ---- §9.8 phone mode (D21): the panels move into #bar and #sheet and back (same elements); the sheet is peek, half or full, one card at a time.
const DE = document.documentElement, PH_VARS = ["--ph-banner-t", "--ph-banner-b", "--ph-top", "--ph-bar-b", "--ph-sheet-h", "--ph-sky-cx"];
const PH_MOVES = [["mast-brand", "bar", 1], ["mode-chip", "bar"], ["grp-bands", "sheet-lead", 1]].concat(["controls", "chanbar", "stats", "source", "masthead", "legend", "detail", "help"].map(id => [id, "sheet-body"]));   // [id, new parent, first]
const PH_TITLE = { obs: "Observations", inv: "Inventory", home: "Homing", air: "Air quality", time: "Signal over time", rec: "Recording", legend: "Legend", help: "Keyboard shortcuts" };
let phHome = null, phCard = null, phBase = "peek", phDock = null;
function applyPhone() {   // → true when the mode changed
  const on = query.phone === "1" || (query.phone !== "0" && mqPhone.matches), ds = DE.dataset;
  if (!phHome) phHome = PH_MOVES.map(([id]) => { const e = el(id); return [e, e.parentNode, e.nextSibling]; });   // each next sibling is a whitespace node: the way back is exact
  if (on === phoneOn && ds.phone) return false;
  phoneOn = on; ds.phone = on ? "on" : "off";
  if (on) for (const [id, to, first] of PH_MOVES) { const p = el(to); p.insertBefore(el(id), first ? p.firstChild : null); }
  else {
    for (const [e, p, nx] of phHome.slice().reverse()) p.insertBefore(e, nx);
    for (const k of ["card", "sheet", "dock", "sheetDrag"]) delete ds[k];
    for (const k of PH_VARS) DE.style.removeProperty(k);
    el("bar").className = "panel ph-only"; delete edgeState.sheet;
  }
  phCard = phDock = null; S.ui.sheet = "peek"; S.ui.legendCard = false;
  applyScope();
  updateControlsLook();
  return true;
}
function applyScope() {
  const on = phoneOn && S.ui.scope;
  if (on !== scopeOn) { scopeOn = on; SC.cs = -1; SC.sg = ""; SC.g = null; TD = deriveStrings(THEME); clearSprites(); regulatorStart(); canvasHud.setAttribute("aria-label", on ? "Scope: signal on arcs, lanes by band" : "Wireless sky"); }
  DE.dataset.scope = on ? "on" : "off"; renderScope(); S.dirty = true;
}
function renderScope() {
  if (!scopeOn) return;
  const T = THEME.copy.scope, ls = liveness(), st = S._stats || {}, aps = S.apOrder.filter(a => S.ui.filters[a.band] !== false), cl = S.ui.random === "cloud" ? st.clouds | 0 : 0;
  const sp = el("scope-strip"), cs = sp.classList, c0 = cs.value;
  sp.replaceChildren(...[aps.length, st.clients | 0, cl, aps.length ? aps[0].rssi + " dBm" : "—", eventsObj().newAps].flatMap((v, i) => [["b", v], ["i", T.strip[i]]].map(([t, x]) => Object.assign(document.createElement(t), { textContent: x }))));
  cs.remove("t", "n");
  for (const x of "tn") if (sp.scrollWidth > sp.clientWidth + 1) cs.add(x);
  el("sc-rx").textContent = copyFor("legRx") + (ls === "live" ? "" : " · " + modeChip.textContent);
  if (ls !== SC.lv || cs.value !== c0) { SC.lv = ls; resize(); }
}
function phoneCardOf() { const d = DE.dataset.drawer || "legend"; return S.ui.help ? "help" : !detail.hidden ? "detail" : d !== "legend" ? "drawer" : S.ui.legendCard ? "legend" : "controls"; }
function setSheet(d) { if (phoneOn && /^(peek|half|full)$/.test(d)) { S.ui.sheet = d; layoutEdges(); } return S.ui.sheet; }
function toggleSheet() { return setSheet(S.ui.sheet === "peek" ? "half" : "peek"); }
function closeCard() {   // × and Esc: the card on top goes; → true when one did
  const c = phCard && phCard.split(":")[0];
  if (c === "help") toggleHelp(false);
  else if (c === "detail") deselect();
  else if (c === "drawer") { for (const k of ["observations", "inventory"]) if (S.ui[k]) setToggle(k, false); S.dx = null; S.homeOpen = false; applyDrawer(); }
  else if (c === "legend") S.ui.legendCard = false;
  else return false;
  layoutEdges(); return true;
}
function phoneLayout(fromResize) {   // D21 the phone pass of layoutEdges(): theme-free, DOM boxes only
  const ds = DE.dataset, vh = innerHeight, set = (k, v) => DE.style.setProperty(k, v), box = (i) => el(i).getBoundingClientRect(), ae = document.activeElement;
  if (!(phDock && ae && /^(INPUT|TEXTAREA|SELECT)$/.test(ae.tagName))) phDock = innerWidth > vh ? "side" : "bottom";   // not while typing
  ds.dock = phDock;
  if (ds.banner === "on") { set("--ph-banner-t", el("classbar-top").offsetHeight + "px"); set("--ph-banner-b", el("classbar-bot").offsetHeight + "px"); set("--ph-top", Math.ceil(box("dtg").bottom) + "px"); }   // the banners wrap on a phone
  else for (const k of PH_VARS.slice(0, 3)) DE.style.removeProperty(k);
  const barEl = el("bar"), cnt = el("bar-counts"); barEl.classList.remove("tight", "tighter", "tightest");
  for (const c of scopeOn ? [] : ["tight", "tighter", "tightest"]) { if (cnt.firstElementChild.getBoundingClientRect().left - box("bar-counts").left >= 4) break; barEl.classList.add(c); }   // closer letters, no words, no counts
  const bar = barEl.getBoundingClientRect(); set("--ph-bar-b", Math.ceil(bar.bottom) + "px");
  const card = phoneCardOf(), key = card + ":" + (card === "drawer" ? ds.drawer : card === "detail" ? detailShown : ""), ctl = card === "controls", title = el("sheet-title"), body = el("sheet-body"), tg = el("sheet-toggle");
  ds.card = card;   // first: the CSS shows this card before it is measured
  el("sheet-lead").hidden = el("t-legend").hidden = !ctl; title.hidden = el("sheet-close").hidden = ctl;
  title.textContent = card === "detail" ? detailTitle.textContent : PH_TITLE[card === "drawer" ? ds.drawer : card] || "";
  el("sheet-prev").hidden = el("sheet-next").hidden = !(card === "detail" && S.pinned.size >= 2);
  const sc = el("t-scope"), row = el("sheet-row"), room = row.clientWidth - [...row.children].reduce((s, c) => s + (c === sc || !c.scrollWidth ? 0 : c.scrollWidth + 8), -8) >= 52;
  sc.hidden = !ctl; if (room !== (sc.parentNode === row)) (room ? row : el("grp-look")).insertBefore(sc, room ? el("t-legend") : null);
  syncPressed("t-legend", S.ui.legendCard); el("sheet").setAttribute("aria-label", ctl ? "Controls" : title.textContent);
  const bottom = box("sheet").bottom, peek = el("sheet-head").offsetHeight, full = Math.min(peek + body.scrollHeight, Math.max(peek, Math.floor(bottom - bar.bottom - PHONE.gapPx)));
  const half = phDock === "side" ? full : Math.min(full, clamp(Math.floor(bottom - (bar.bottom + bottom - peek) / 2 - PHONE.centreClearPx), peek, Math.round(vh * PHONE.halfFrac)));   // clear of the device
  if (key !== phCard) {   // another card, drawer or node (the first pass stays collapsed)
    if (phCard && phCard.startsWith("controls")) phBase = S.ui.sheet;
    if (phCard !== null) S.ui.sheet = ctl ? phBase : card === "detail" ? phDetailDetent(half, bottom) : S.ui.sheet === "peek" ? "half" : S.ui.sheet;
    phCard = key; body.scrollTop = 0;
  }
  const open = (ds.sheet = S.ui.sheet) !== "peek", sb = skyBox();
  tg.textContent = open ? "⌄" : "⌃"; tg.setAttribute("aria-expanded", open); tg.setAttribute("aria-label", (open ? "Collapse" : "Expand") + " the sheet");
  const h = open ? (S.ui.sheet === "half" ? half : full) : peek;
  if (ds.sheetDrag !== "on") set("--ph-sheet-h", h + "px");
  set("--ph-sky-cx", Math.round(sb.x + sb.w / 2) + "px");
  edgeState.sheet = { card, detent: S.ui.sheet, dock: phDock, peek, half, full, h };
  if (!fromResize && (Math.abs(sb.x + sb.w / 2 - CX) > 0.5 || Math.abs(sb.y + sb.h / 2 - CY) > 0.5 || Math.abs(sb.h - skyH) > 0.5)) { clearTimeout(resizeTimer); resizeTimer = setTimeout(resize, 100); }   // theme, banners, fonts
  return edgeState.sheet;
}
function phDetailDetent(half, bottom) {   // half, or collapsed when the star would sit under it (3D: the camera turns it to the front)
  if (phDock === "side") return S.ui.sheet === "peek" ? "half" : S.ui.sheet;
  const n = nodeById(S.locked || detailShown);
  return (tS >= 0.5 && !scopeOn) || (n && n.sy >= bottom - half - PHONE.starClearPx) ? "peek" : "half";
}
function skyBox() {   // the free rectangle for the sky
  if (!phoneOn) return { x: 0, y: 0, w: W, h: H };
  const bar = el("bar").getBoundingClientRect(), sh = el("sheet").getBoundingClientRect(), ban = DE.dataset.banner === "on", bx = (x, y, r, b) => ({ x, y, w: Math.max(40, r - x), h: Math.max(40, b - y) });
  if (!S.ui.panels) return bx(0, bar.top, W, sh.bottom - 52);   // above the pill
  if (phDock === "side") return bx(Math.max(bar.right, sh.right) + PHONE.gapPx, ban ? el("dtg").getBoundingClientRect().bottom + 4 : 0, W - bar.left, ban ? H - el("classbar-bot").offsetHeight : H);
  return bx(0, bar.bottom + 4, W, sh.bottom - el("sheet-head").offsetHeight - 4);
}
function setPanels(on) {   // §9.8 Hide panels, at every size; saved unless ?panels locks it
  on = !!on; if (on === S.ui.panels) return on;
  const ae = document.activeElement, pill = el("panels-pill");
  S.ui.panels = on; DE.dataset.panels = on ? "on" : "off";
  if (!on && S.ui.help) toggleHelp(false);
  S.queryLocked.delete("panels"); saveUi();
  if (phoneOn) resize(); else S.dirty = true;
  if (!on && ae && ae.closest && ae.closest(".panel")) pill.focus();
  else if (on && ae === pill) el(phoneOn ? "sheet-toggle" : "t-panels").focus();
  return on;
}
(() => {   // the head: a drag moves the sheet (reduced motion too), a release or a flick picks a height, a tap toggles
  const head = el("sheet-head"), sh = el("sheet"), ds = DE.dataset, stop = (e) => { e.stopPropagation(); e.preventDefault(); };
  let g = null;
  head.addEventListener("pointerdown", (e) => { if (phoneOn && e.button === 0) g = { id: e.pointerId, y0: e.clientY, h0: sh.getBoundingClientRect().height, y: e.clientY, t: e.timeStamp, v: 0, btn: !!e.target.closest("button") }; });
  window.addEventListener("pointermove", (e) => {   // uncaptured: a tap keeps its button
    const s = edgeState.sheet; if (!g || e.pointerId !== g.id || !s) return;
    if (!g.moved) { if (Math.abs(e.clientY - g.y0) < PHONE.dragPx) return; g.moved = true; ds.sheetDrag = "on"; }
    if (e.timeStamp > g.t) g.v = (e.clientY - g.y) / (e.timeStamp - g.t);   // px/ms (PointerEvent.timeStamp: UI only)
    g.y = e.clientY; g.t = e.timeStamp;
    DE.style.setProperty("--ph-sheet-h", clamp(g.h0 - (e.clientY - g.y0), s.peek, s.full) + "px");
  });
  const end = (e) => {
    if (!g || e.pointerId !== g.id) return;
    const d = g; g = null; delete ds.sheetDrag;
    if (!d.moved) { if (!d.btn && e.type === "pointerup" && head.contains(e.target)) toggleSheet(); return; }
    window.addEventListener("click", stop, true); setTimeout(() => window.removeEventListener("click", stop, true), 0);   // nor does a drag press it
    const s = edgeState.sheet, h = sh.getBoundingClientRect().height, hs = [s.peek, s.half, s.full];
    let i = 0;
    if (Math.abs(d.v) < PHONE.flickPxMs) hs.forEach((x, k) => { if (Math.abs(x - h) < Math.abs(hs[i] - h)) i = k; });   // the nearest height
    else if (d.v < 0) { i = hs.findIndex(x => x > h + 1); if (i < 0) i = 2; }   // a flick: the next height that way
    else for (let k = 2; k >= 0; k--) if (hs[k] < h - 1) { i = k; break; }
    setSheet(["peek", "half", "full"][i]);
  };
  window.addEventListener("pointerup", end); window.addEventListener("pointercancel", end);
})();
for (const [id, fn] of [["sheet-toggle", toggleSheet], ["t-legend", () => { S.ui.legendCard = !S.ui.legendCard; layoutEdges(); }], ["sheet-close", closeCard], ["sheet-prev", () => cyclePinned(-1)],
  ["sheet-next", () => cyclePinned(1)], ["t-panels", () => setPanels(false)], ["panels-pill", () => setPanels(true)], ["t-help", () => toggleHelp(true)], ["t-home", KEY_ACT.f]]) el(id).addEventListener("click", fn);
el("sheet-body").addEventListener("scroll", () => { if (phoneOn && S.ui.sheet === "half" && el("sheet-body").scrollTop > 8) setSheet("full"); }, { passive: true });

