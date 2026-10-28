// ==== 36 INTERACTION ====
function hitRadius(n, touch) {
  const pad = n.kind === "ap" ? HIT.apPad : (n.kind === "bubble" ? HIT.bubblePad : HIT.clientPad);
  return Math.max(n.px + pad, touch ? HIT.touchMinPx : HIT.minPx);
}
function nodeAt(mx, my, touch) {
  // §8.8a clouds take part in both hit tests
  if (tS < 0.5 || scopeOn) {
    // 2D: nearest wins (clients/stars over bubbles); the Scope: as drawn
    let best = null, bd = Infinity;
    const near = (n, r) => { const d = hyp(n.sx - mx, n.sy - my); if (d <= r && d < bd && (!scopeOn || n.alphaDraw >= 0.25)) { bd = d; best = n; } };
    S.clients.forEach(n => { if (n.target !== 1) return; if (n.bubble != null && n.bubbleBlend >= 0.98 && !scopeOn) return; if (n.randOut && !(n.alphaDraw >= 0.25)) return; near(n, hitRadius(n, touch)); });
    if (S.ui.random === "cloud") S.clouds.forEach(k => { if (k.target !== 1) return; near(k, hitRadius(k, touch)); });
    if (S.ui.filters.bt) S.bt.forEach(k => { if (k.target === 1 && k.rank < BT.drawMax) near(k, hitRadius(k, touch)); });
    S.aps.forEach(n => { if (n.target !== 1 || (isEssFolded(n.id) && !scopeOn)) return; near(n, hitRadius(n, touch)); });
    if (!scopeOn) S.bubbles.forEach(b => { if (b.target !== 1 && b.alpha <= 0.02) return; near(b, b.px + HIT.bubblePad); });
    return best ? best.id : null;
  }
  // 3D: projected hit-test from near to far, first covering wins
  const cands = [];
  S.aps.forEach(n => { if (n.target === 1 && n.alphaDraw >= 0.25 && !isEssFolded(n.id)) cands.push(n); });
  S.clients.forEach(n => { if (n.target !== 1) return; if (n.bubble != null && n.bubbleBlend > 0.5) return; if (n.alphaDraw >= 0.25) cands.push(n); });
  S.bubbles.forEach(b => { if ((b.target === 1 || b.alpha > 0.02) && b.alphaDraw >= 0.25) cands.push(b); });
  S.clouds.forEach(k => { if (k.target === 1 && k.alphaDraw >= 0.25) cands.push(k); });
  S.bt.forEach(k => { if (k.target === 1 && k.rank < BT.drawMax && k.alphaDraw >= 0.25) cands.push(k); });
  cands.sort((a, b) => a.zc - b.zc);
  for (const n of cands) { const r = hitRadius(n, touch); const dx = mx - n.sx, dy = my - n.sy; if (dx * dx + dy * dy <= r * r) return n.id; }
  return null;
}
function nodeById(id) { return S.aps.get(id) || S.clients.get(id) || S.bubbles.get(id) || S.clouds.get(id) || S.bt.get(id); }
function expandCloud(id) { const k = S.clouds.get(id); if (!k || k.target !== 1) return false; k.expandedUntil = S.clock + CLOUD.expandMs / 1000; S.dirty = true; return true; }
function setHover(id) {
  if (S.hover === id) return;
  S.hover = id; S.dirty = true;
  const n = id ? nodeById(id) : null;
  if (n) showTip(n); else hideTip();
}
function select(id) {
  if (id == null) { deselect(); return null; }
  const n = nodeById(id); if (!n || n.kind === "bt") return null;   // no sheet for a mark in this release
  S.locked = id; S.dirty = true;
  const fc = S.aps.has(id) ? essOfFolded(id) : null; if (fc) expandEss(fc.id);   // §8.8 click a folded ESS node → expand 6 s
  if (tS >= 0.5 && !scopeOn) flyTo(n);               // 3D: turn the node to the front + dolly in; the device stays centred
  return openDetail(id);
}
function deselect() {
  S.locked = null; closeDetail(); S.dirty = true;
  if (tS >= 0.5) { const pre = camPreset("3d"); startTween({ target: [0, 0, 0], dist: pre.dist }); }
  return null;
}
let lastPinClick = { id: null, t: -Infinity };
function clickPin(id, t) {   // §5.6/§9.2, MUSS BLEIBEN 10: a click on a star toggles its pin (clients additively); bubbles are aggregates → no pin
  if (!S.aps.has(id) && !S.clients.has(id)) return false;
  const dbl = id === lastPinClick.id && t - lastPinClick.t < HIT.pinDebounceMs;   // double click: no second toggle (PointerEvent.timeStamp, UI only — not a data/render clock)
  lastPinClick = { id, t };
  if (!dbl) { if (S.pinned.has(id)) S.pinned.delete(id); else S.pinned.add(id); S.dirty = true; }
  return S.pinned.has(id);
}
let drag = null; const pointers = new Map(); let pinchBase = 0, pinchZoom0 = 1, pinchDist0 = 1;
function interacted() { S.cam.ramp = 0; S.cam.idleAt = S.clock; }
canvasHud.addEventListener("pointerdown", (e) => {
  try { canvasHud.setPointerCapture(e.pointerId); } catch (_) { }
  pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if (pointers.size > 1) {
    const p = Array.from(pointers.values()); pinchBase = Math.hypot(p[0].x - p[1].x, p[0].y - p[1].y) || 1;
    pinchZoom0 = S.cam.zoom2d; pinchDist0 = S.cam.distT; drag = null;
  } else {
    drag = { id: e.pointerId, downX: e.clientX, downY: e.clientY, lastX: e.clientX, lastY: e.clientY, moved: false, is3d: tS >= 0.5, touch: e.pointerType === "touch" };
  }
  interacted();
});
canvasHud.addEventListener("pointermove", (e) => {
  if (pointers.has(e.pointerId)) pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if (pointers.size >= 2) {                       // pinch
    if (scopeOn) return;
    const p = Array.from(pointers.values()); const d = Math.hypot(p[0].x - p[1].x, p[0].y - p[1].y) || 1; const ratio = d / pinchBase;
    if (tS >= 0.5) { S.cam.distT = clamp(pinchDist0 / ratio, CFG3D.distMin, CFG3D.distMax); S.cam.tween = null; }
    else setZoom2d(pinchZoom0 * ratio);
    interacted(); S.dirty = true; return;
  }
  if (drag && drag.id === e.pointerId) {
    const thr = drag.touch ? CFG3D.touchThresholdPx : CFG3D.dragThresholdPx;
    if (!drag.moved) { if (Math.hypot(e.clientX - drag.downX, e.clientY - drag.downY) < thr) return; drag.moved = true; drag.lastX = drag.downX; drag.lastY = drag.downY; }
    const dx = e.clientX - drag.lastX, dy = e.clientY - drag.lastY; drag.lastX = e.clientX; drag.lastY = e.clientY;
    if (drag.is3d) applyOrbit(dx, dy);   // 2D drag has no effect: the device is the fixed anchor (no pan)
    interacted(); return;
  }
  const id = nodeAt(e.clientX, e.clientY, e.pointerType === "touch");
  setHover(id);
  if (id) { positionTip(nodeById(id), e.clientX, e.clientY); canvasHud.style.cursor = "pointer"; }
  else canvasHud.style.cursor = "default";
});
function endPointer(e) {
  try { canvasHud.releasePointerCapture(e.pointerId); } catch (_) { }
  const wasDrag = drag && drag.id === e.pointerId;
  const clicked = wasDrag && !drag.moved && e.type == "pointerup" && !e.button;
  pointers.delete(e.pointerId);
  if (wasDrag) { drag = null; if (clicked) { const id = nodeAt(e.clientX, e.clientY, e.pointerType === "touch"); if (id) { clickPin(id, e.timeStamp); select(id); } else if (!phoneOn) deselect(); else { if (S.locked || !detail.hidden) deselect(); setSheet("peek"); } } }   // phone: empty sky collapses the sheet, an unlocked 3D camera stays
  if (pointers.size < 2) pinchBase = 0;
}
canvasHud.addEventListener("pointerup", endPointer);
canvasHud.addEventListener("pointercancel", endPointer);
canvasHud.addEventListener("pointerleave", (e) => { if (!drag && pointers.size === 0) setHover(null); });
canvasHud.addEventListener("wheel", (e) => {
  e.preventDefault();
  if (scopeOn) return;
  const norm = e.deltaMode === 1 ? e.deltaY * 16 : e.deltaMode === 2 ? e.deltaY * 100 : e.deltaY;
  interacted();
  if (tS >= 0.5) { S.cam.distT = clamp(S.cam.distT * Math.exp(norm * CFG3D.wheelK), CFG3D.distMin, CFG3D.distMax); S.cam.tween = null; }
  else setZoom2d(S.cam.zoom2d * Math.exp(-norm * CFG3D.wheelK));   // about the device, not the cursor
  S.dirty = true;
}, { passive: false });
// hold the browser's own pinch-zoom of the page back (WebKit gesture events, §9.7); the sky zooms on canvasHud
for (const g of ["gesturestart", "gesturechange", "gestureend"]) document.addEventListener(g, (e) => e.preventDefault(), { passive: false });
function shortcutsAllowed() { const a = document.activeElement; return a == null || a === document.body || a === canvasHud || a === el("panels-pill"); }
// 3D camera steps, shared by the arrow/+/- keys and the #cam-* buttons
const CAM_STEP = {
  left: (c) => { c.azT -= CFG3D.btnAz; },
  right: (c) => { c.azT += CFG3D.btnAz; },
  up: (c) => { c.elT = clamp(c.elT + CFG3D.btnEl, CFG3D.elMin, CFG3D.elMax); },
  down: (c) => { c.elT = clamp(c.elT - CFG3D.btnEl, CFG3D.elMin, CFG3D.elMax); },
  in: (c) => { c.distT = clamp(c.distT / CFG3D.btnZoom, CFG3D.distMin, CFG3D.distMax); },
  out: (c) => { c.distT = clamp(c.distT * CFG3D.btnZoom, CFG3D.distMin, CFG3D.distMax); },
};
const CAM_KEY = { arrowleft: "left", arrowright: "right", arrowup: "up", arrowdown: "down", "+": "in", "=": "in", "-": "out" };
const KEY_ACT = { t: () => toggleTheme(), v: () => { setView(S.ui.view === "3d" ? "2d" : "3d"); renderCaption(); }, r: () => setToggle("rotate", !S.ui.rotate), s: () => setToggle("spin", !S.ui.spin),
  c: () => toggleCrt(), " ": () => setToggle("paused", !S.ui.paused),
  l: () => setToggle("labels", !S.ui.labels), o: () => setToggle("orbits", !S.ui.orbits), k: () => setToggle("links", !S.ui.links),
  a: () => setToggle("agg", !S.ui.agg), e: () => setToggle("vendor", !S.ui.vendor), n: () => setToggle("nebula", !S.ui.nebula),
  g: () => setToggle("groups", !S.ui.groups),
  d: () => setToggle("deviceLinks", !S.ui.deviceLinks), m: () => setToggle("essMerge", !S.ui.essMerge),
  p: () => setToggle("affinity", !S.ui.affinity), w: () => setToggle("observations", !S.ui.observations), b: () => setToggle("baselineDiff", !S.ui.baselineDiff), i: () => setToggle("inventory", !S.ui.inventory), f: () => { S.homeOpen = !S.homeOpen; if (S.homeOpen) S.dx = null; applyDrawer(); },
  q: () => setDx("air"), j: () => setDx("time"), h: () => setDx("rec"), y: () => cycleChanMode(), u: () => setPanels(!S.ui.panels),
  "[": () => cyclePinned(-1), "]": () => cyclePinned(1), x: () => cycleRandom(),
  "1": () => toggleBand("2.4"), "2": () => toggleBand("5"), "3": () => toggleBand("6"), "4": () => toggleBand("bt") };
KEY_ACT.z = () => { if (phoneOn) setToggle("scope", !S.ui.scope); };
window.addEventListener("keydown", (e) => {
  const k = (e.key || "").toLowerCase();
  if (k === "escape") {
    // Esc closes one layer per press, topmost first: paste, export, help, selection, hover; on a phone then a drawer or the
    // legend card, then the sheet (§9.8).
    if (getComputedStyle(pasteWrap).display !== "none") { closePaste(); e.preventDefault(); return; }
    if (el("export-wrap").style.display === "flex") { closeExport(); e.preventDefault(); return; }
    if (!help.hidden) { toggleHelp(false); e.preventDefault(); return; }
    if (S.locked) { deselect(); e.preventDefault(); return; }
    if (S.hover) { setHover(null); e.preventDefault(); return; }
    if (phoneOn && closeCard()) { e.preventDefault(); return; }
    if (phoneOn && S.ui.sheet !== "peek") { setSheet("peek"); e.preventDefault(); return; }
    return;
  }
  if (!shortcutsAllowed() || e.metaKey || (e.ctrlKey && !e.altKey)) return;   // Cmd/Ctrl + a key is the browser's; AltGr (Ctrl+Alt) types [ ]
  if (k === "?") { toggleHelp(); e.preventDefault(); return; }
  if (k === "enter" && liveCloud(S.locked)) { expandCloud(S.locked); e.preventDefault(); return; }   // §8.8a
  // camera keys (3D orbit / 2D zoom around centre / reset)
  const c = S.cam; let camHandled = true;
  if (k === "0") resetCamera();
  else if (tS >= 0.5) {
    const step = CAM_STEP[CAM_KEY[k]];
    if (step) { step(c); c.tween = null; } else camHandled = false;
  } else {
    if (k === "+" || k === "=") setZoom2d(S.cam.zoom2d * CFG3D.btnZoom);
    else if (k === "-") setZoom2d(S.cam.zoom2d / CFG3D.btnZoom);
    else camHandled = false;
  }
  if (camHandled) { interacted(); S.dirty = true; e.preventDefault(); return; }
  if (KEY_ACT[k]) { KEY_ACT[k](); e.preventDefault(); }
});

