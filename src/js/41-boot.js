// ==== 41 BOOT ====
S.labelsList = [];
(function boot() {
  loadUi();
  loadIdentity(); loadBaseline(); loadWatch(); loadLibrary();
  // query overrides win over localStorage and are not persisted
  if (query.theme && THEMES[query.theme]) { S.ui.theme = query.theme; S.queryLocked.add("theme"); }
  if (query.view === "2d" || query.view === "3d") { S.ui.view = query.view; S.queryLocked.add("view"); }
  if (RANDOM_MODES.indexOf(query.random) >= 0) { S.ui.random = query.random; S.queryLocked.add("random"); }
  for (const [v, key] of [[query.agg, "agg"], [query.crt, "crt"], [query.autolod, "autoLod"], [query.deviceLinks, "deviceLinks"], [query.essMerge, "essMerge"],
    [query.affinity, "affinity"], [query.spin, "spin"], [query.baseline, "baselineDiff"], [query.obs, "observations"], [query.inv, "inventory"], [query.panels, "panels"], [query.scope, "scope"]]) {
    if (v === "0" || v === "1") { S.ui[key] = v === "1"; S.queryLocked.add(key); }
  }
  validateThemes();   // symmetric, once, all themes, before the first applyTheme
  el("mast-ver").textContent = window.STARCHORUS.version;   // the masthead shows the version, read from the frozen API object so the number is written once
  document.documentElement.dataset.panels = S.ui.panels ? "on" : "off";
  buildHelp(); syncRandomButton(); applyDrawer(); applyPhone();   // the drawer first: a saved one does not open the sheet
  if (mqPhone.addEventListener) mqPhone.addEventListener("change", resize); else if (mqPhone.addListener) mqPhone.addListener(resize);   // older Safari
  const startTheme = S.ui.theme, startView = S.ui.view;
  // ?fixed= must be known BEFORE the first applyTheme: applyTheme ends in runIntro(), and the coalescing
  // intro refuses to start under frozen time.
  if (query.fixed !== undefined) { const v = +query.fixed; if (Number.isFinite(v)) S.fixedTime = v; }
  applyTheme(startTheme, { intro: !query.intro0, persist: !S.queryLocked.has("theme") });
  resize();
  setView(startView, { persist: !S.queryLocked.has("view"), snap: true });
  const demo = demoData(); setSource(demo, "demo", "demo"); ingest(demo, { newSource: true }); renderSourceTruth();
  if (query.demo1) { firstPollDone = true; guard(releaseLogon); }   // ?demo=1: no poll; the logon is released as the first poll does
  else { const boot = tryPoll(); if (!query.poll0) boot.then(r => pollArm(pollNextMs(r))); }   // §9.9 item 1
  // The embedded font loads async; once ready, drop the measured and baked text, redraw #bg and repaint,
  // so canvas labels leave the fallback face (Whitehall).
  try {
    if (document.fonts && document.fonts.load) {
      Promise.all([document.fonts.load('500 12px "Starchorus Sans"'), document.fonts.load('400 12px "Starchorus Sans"')])
        .then(() => { measureCache.clear(); clearSprites(); rebuildBackground(); S.dirty = true; layoutEdges(); if (W > 0) render(); })
        .catch(() => {});
    }
  } catch (e) {}
  if (window.ResizeObserver) {   // D15 safety net: any chrome size change (fonts, copy, buttons) re-runs the theme-free layout next frame
    let rq = 0; const ro = new ResizeObserver(() => { if (!rq) rq = requestAnimationFrame(() => { rq = 0; layoutEdges(); }); });
    for (const id of ["masthead", "stats", "source", "legend", "controls", "bar"]) { const e = el(id); if (e) ro.observe(e); }
  }
  requestAnimationFrame(tick);
})();

