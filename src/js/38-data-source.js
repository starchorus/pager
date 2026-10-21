// ==== 38 DATA SOURCE ====
// D4 source truth (theme-free): what the sky shows and how it arrived. D3 liveness: a poll-fed document is stale after staleAfterMs() of
// poll time without a new `generated` (demo, recorded and none never are). Poll time is what the cadence waited; no clock is read.
function sourceKindOf(doc, via) {
  if (!doc || doc.source === "none") return "none";
  if (/ACTIVE/i.test(doc.source || "")) return "active";   // the collector's opt-in iw scan transmitted: wins over every arrival path
  return via === "demo" ? "demo" : via === "live" ? "live" : "recorded";
}
const srcKeyOf = (doc, label, via) => sourceKindOf(doc, via) + "|" + via + "|" + String(label) + "|" + (doc.source || "");
function setSource(doc, label, via, tickMs) {   // → true when the source changed (kind, arrival path, label or doc.source)
  const kind = sourceKindOf(doc, via), lbl = String(label), key = srcKeyOf(doc, label, via);
  const changed = key !== S.sourceKey, gen = doc.generated ?? null;
  if (changed) S.gaps = [];
  else if (Number.isFinite(gen) && Number.isFinite(S.lastGen) && gen > S.lastGen) { S.gaps.push(gen - S.lastGen); if (S.gaps.length > POLL.gaps) S.gaps.shift(); }   // the observed capture spacing
  S.fresh = changed || via !== "live" || gen !== S.lastGen;
  if (S.fresh) S.stalePolls = S.staleMs = 0; else { S.stalePolls++; S.staleMs += tickMs ?? POLL_MS; }   // same live source, same capture → one stale tick
  S.sourceKey = key; S.sourceKind = kind; S.sourceLabel = lbl; S.liveFeed = via === "live"; S.lastGen = gen; S.sourceApCount = doc.aps.length;
  return changed;
}
// Chip, masthead dot, source badge, lamps and the panels pill all read captureStale(): they flip together.
function staleAfterMs() { const iv = S.pollIntervalS; return iv > 0 ? 1000 * Math.max(STALE.floorS, STALE.mul * iv + STALE.slackS) : STALE_POLLS * POLL_MS; }
function captureStale() { return !S.replay && S.liveFeed && S.sourceKind !== "none" && S.staleMs >= staleAfterMs(); }
// Offline (D3): stale, and the server has answered none of the last OFFLINE_POLLS polls (network error, deadline, non-200): the page has not heard from it, which is not the same as a capture that is old.
function captureOffline() { return captureStale() && S.lostPolls >= OFFLINE_POLLS; }
const liveness = () => captureOffline() ? "offline" : captureStale() ? "stale" : "live";   // what a poll-fed feed is called; a feed that is not stale is "live"
function noteStalePoll(tickMs, heard) {   // a failed poll: only its time counts (heard: see captureOffline)
  if (!S.liveFeed) return;
  const ms = tickMs ?? POLL_MS;
  S.stalePolls++; S.staleMs += ms;
  if (!heard) S.lostPolls++;
  renderSourceTruth();
}
let pollPromise = null, firstPollDone = false;
// D3: a poll that never answers ends after POLL_TIMEOUT_MS: the request is aborted and the tick counts like a failed poll,
// so a hung server or a half-open connection cannot keep the chip on "Live". `?pollto=<ms>` shortens it for tests only.
const POLL_TIMEOUT_MS = Number.isFinite(+query.pollto) && +query.pollto >= 100 ? Math.min(+query.pollto, 60000) : 4000;
function tryPoll(tickMs) {   // MUSS BLEIBEN 1: the page's only network call; returns the in-flight promise (no double request). tickMs: the poll time it stands for
  if (query.demo1) return Promise.resolve({ ok: false });   // ?demo=1 (§2.7): nothing is requested
  if (pollPromise) return pollPromise;
  const ac = typeof AbortController === "function" ? new AbortController() : null;
  let late = false, heard = false; const tick = () => (tickMs ?? POLL_MS) + (late ? POLL_TIMEOUT_MS : 0);   // a deadline adds its time
  const timer = ac ? setTimeout(() => { late = true; ac.abort(); }, POLL_TIMEOUT_MS) : 0;
  pollPromise = fetch("starchorus.json?_=" + S.clock.toFixed(0), ac ? { cache: "no-store", signal: ac.signal } : { cache: "no-store" })
    .then(r => { if (r.status !== 200) return Promise.reject(r.status); heard = true; S.lostPolls = 0; return r.json(); })   // any 200 is the server answering
    .then(raw => guard(() => loadData(raw, "starchorus.json", { mode: "live", tickMs: tick() })), () => null)
    .then(r => {
      const ok = !!(r && r.ok);
      clearTimeout(timer); pollPromise = null;
      if (!ok) guard(() => noteStalePoll(tick(), heard));   // nothing here may end the chain
      if (!firstPollDone) { firstPollDone = true; guard(releaseLogon); }   // D13: the logon waits for the first completed poll
      return { ok, fresh: ok && !!r.fresh, stalePolls: S.stalePolls, captureStale: captureStale(), sourceKind: S.sourceKind };
    })
    .catch(e => { pushError(e); return { ok: false }; });   // a fault is a failed poll
  return pollPromise;
}
// One poll at a time, armed when the last has ended (§9.9 item 1); without a live capture, and once stale, every POLL_MS. A capture already
// there at the first poll after the lead may be late by any amount: the steps take over until the next one.
function captureSpacing() { const g = S.gaps.slice().sort((a, b) => a - b), n = g.length; return n ? (n % 2 ? g[n >> 1] : (g[n / 2 - 1] + g[n / 2]) / 2) : null; }   // s, observed
const pollPlan = { timer: 0, wait: 0, since: 0, lastOld: false, log: [] };
function pollNextMs(r) {
  const ok = !!(r && r.ok), fresh = ok && !!r.fresh, known = pollPlan.lastOld && pollPlan.wait <= POLL.stepMs;   // known: the poll before saw the old capture, one step ago
  pollPlan.lastOld = ok && !fresh;
  pollPlan.since = fresh ? 0 : pollPlan.since + pollPlan.wait;
  if (!S.liveFeed) return POLL_MS;
  if (fresh) { const s = captureSpacing(); return known || s === null ? Math.max(POLL.stepMs, Math.round(1000 * Math.min(s ?? (S.pollIntervalS > 0 ? POLL.guessMul * S.pollIntervalS : POLL_MS / 1000), POLL.maxIntervalS) - POLL.leadMs)) : POLL.stepMs; }   // a first capture: the first guess
  return pollPlan.since < staleAfterMs() ? POLL.stepMs : POLL_MS;
}
function pollArm(ms) {
  clearTimeout(pollPlan.timer); pollPlan.wait = ms;
  pollPlan.timer = setTimeout(() => tryPoll(ms).then(r => {
    pollPlan.log.push(ms); if (pollPlan.log.length > POLL.logMax) pollPlan.log.shift();   // the waits of the last scheduled polls
    pollArm(pollNextMs(r));
  }), ms);
}
function pollPlanObj() { return { spacingS: captureSpacing(), staleAfterS: staleAfterMs() / 1000, staleS: S.staleMs / 1000, sinceS: pollPlan.since / 1000, nextMs: pollPlan.wait, log: pollPlan.log.slice() }; }
function copyFor(site) { return THEME.copy[S.sourceKind === "active" ? "active" : "rx"][site]; }   // D4: every claim site reads here
const metaDescEl = document.querySelector('meta[name="description"]'), mastTag = document.querySelector("#masthead .tag"),
  mastMotto = document.querySelector("#masthead .motto"), mastDot = document.querySelector("#masthead .brand .dot");
function toteObj() {   // per band the count of APs in each D1 freshness tier (T0..T3); undated and band-unknown APs are counted apart
  const t = { "2.4": [0, 0, 0, 0], "5": [0, 0, 0, 0], "6": [0, 0, 0, 0] }; let undated = 0, unknown = 0;
  S.apOrder.forEach(n => { if (n.freshTier == null) { undated++; return; } if (!t[n.band]) { unknown++; return; } t[n.band][n.freshTier]++; });
  return { bands: t, undated, unknown, labels: THEME.copy.tote.labels.slice(), shown: !!THEME.chrome.tote.show };
}
function renderTote() {
  const el0 = el("tote"); if (!el0) return; const o = toteObj();
  el0.hidden = !o.shown; if (!o.shown) return;
  let h = '<h4>' + esc(THEME.copy.tote.title) + '</h4><div class="tr"><span></span>' + o.labels.map(l => "<span>" + esc(l) + "</span>").join("") + "</div>";
  for (const b of ["2.4", "5", "6"]) h += '<div class="tr"><span>' + esc(b) + "</span>" + o.bands[b].map((n, i) => '<i class="lamp' + (n ? " on" : "") + '" title="' + esc(fmtBand(b) + " · " + o.labels[i] + ": " + n) + '">' + (n || "") + "</i>").join("") + "</div>";
  if (o.undated) h += '<div class="tr"><span></span><span style="grid-column: 2 / 6">' + o.undated + " " + esc(THEME.copy.tote.undated) + "</span></div>";
  el0.innerHTML = h;
}
function plotClockObj() {   // the sector clock: 5-minute periods in three colours over the hour; the hand and the period come from the capture's `generated` (never a wall clock)
  const g = S.generated, ok = Number.isFinite(g);
  const sec = ok ? ((g % 3600) + 3600) % 3600 : null;
  return { shown: !!THEME.chrome.clock.show, generated: ok ? g : null, angleDeg: ok ? r3(sec / 10) : null, period: ok ? Math.floor(sec / 300) : null, colour: ok ? Math.floor(sec / 300) % 3 : null };
}
function renderClock() {
  const c = el("plotclock"); if (!c) return; const o = plotClockObj();
  c.hidden = !o.shown; if (!o.shown) return;
  const h = el("plotclock-hand"); h.style.display = o.generated == null ? "none" : "block"; if (o.generated != null) h.style.transform = "rotate(" + o.angleDeg + "deg)";
  c.setAttribute("aria-label", THEME.copy.clock + (o.period == null ? ", no capture time" : ", period " + (o.period + 1) + " of 12"));
}
const staleNote = () => captureOffline() ? "The Pager could not be reached" + (Number.isFinite(S.generated) ? "; the last capture was at " + utcHM(S.generated) : "") + "." : "no new capture for " + S.stalePolls + " polls";
function renderBadge() {   // the source badge in the masthead (token chrome.badge.show); chrome text from copy.badge, never a data string
  const b = el("mast-badge"); if (!b) return;
  b.hidden = !THEME.chrome.badge.show; if (b.hidden) return;
  const k = S.replay ? "recorded" : S.sourceKind, chip = k === "live" ? liveness() : k, cp = THEME.copy.badge;
  b.textContent = cp[chip] || cp.none; b.dataset.kind = chip;
  b.title = chip === "active" ? cp.active + " · " + String(S.source || "").slice(0, 40) : chip === "stale" || chip === "offline" ? staleNote() : (cp[chip] || cp.none);
}
function utcHM(g) { return new Date(g * 1000).toISOString().slice(11, 16) + " UTC"; }   // a capture time, as the caption and the offline note say it
// the place-and-time caption: where the observer is and when the capture was made, said once on a theme or view
// change and then gone. The place is `center.label`, a data string: printed as it stands, never upper-cased (D16).
// The time comes from `generated`, never from a wall clock, so with no capture time there is no caption.
function captionObj() {
  const g = S.generated, ok = Number.isFinite(g);
  return { shown: !!THEME.chrome.caption.show, place: String(S.centerLabel || ""), time: ok ? utcHM(g) : null };
}
let captionTimer = null, captionFade = null;
function renderCaption() {
  const c = el("caption"); if (!c) return;
  const o = captionObj();
  if (captionTimer) { clearTimeout(captionTimer); captionTimer = null; }
  if (captionFade) { clearTimeout(captionFade); captionFade = null; }
  if (!o.shown || o.time == null || !o.place) { c.hidden = true; c.classList.remove("out"); return; }
  c.innerHTML = '<span class="place">' + esc(o.place) + "</span> · " + esc(o.time);
  c.setAttribute("aria-label", THEME.copy.caption);
  c.hidden = false; c.classList.remove("out");
  captionTimer = setTimeout(() => {
    c.classList.add("out"); captionTimer = null;
    captionFade = setTimeout(() => { c.hidden = true; c.classList.remove("out"); captionFade = null; }, 450);
  }, 1600);
}
function lampsObj() { const lo = THEME.chrome.lamps, n = lo.count, v = S.captureSeq % (1 << n), bits = []; for (let i = n - 1; i >= 0; i--) bits.push((v >> i) & 1); return { value: v, bits, frozen: captureStale(), shown: !!lo.show }; }
function renderLamps() {   // IMSAI-style lamps = the capture counter in binary; a stale feed freezes them
  const o = lampsObj();
  for (const l of document.querySelectorAll("#lamps,#scope-lamps")) {
    l.hidden = !o.shown; if (!o.shown) continue;
    if (l.childElementCount !== o.bits.length) { l.textContent = ""; for (let i = 0; i < o.bits.length; i++) l.appendChild(document.createElement("i")); }
    Array.prototype.forEach.call(l.children, (e, i) => e.classList.toggle("on", o.bits[i] === 1));
    l.dataset.frozen = o.frozen ? "1" : "0"; l.dataset.value = String(o.value); l.setAttribute("aria-label", THEME.copy.lamps + " " + o.value);
  }
}
function setSourcePanel() {   // §9.5: fixed templates; label/note only via esc() (max 80 chars)
  const k = S.replay ? "recorded" : S.sourceKind, ls = liveness(), stale = ls !== "live", chip = k === "live" ? ls : k;
  modeChip.textContent = THEME.copy.chip[chip];
  modeChip.className = "mode " + chip + (stale && chip !== "stale" ? " stale" : "");
  const ts = Number.isFinite(S.generated) ? new Date(S.generated * 1000).toISOString().slice(11, 19) : "—";
  let d;
  if (k === "demo") d = 'Simulated sky. Load a <b>starchorus.json</b> to see your own sky.';
  else if (k === "none") d = 'No capture source · ' + esc((S.note || "").slice(0, 80));
  else if (S.replay) d = 'Replay <b>' + (S.replay.i + 1) + ' of ' + S.rec.docs.length + '</b> · ' + ts + (S.replay.buffered ? ' · ' + S.replay.buffered + (S.replay.buffered === 1 ? ' newer capture kept' : ' newer captures kept') : '');
  else if (S.liveFeed) d = (ls === "offline" ? 'Last capture from <b>' : 'Live from <b>') + esc(S.sourceLabel.slice(0, 80)) + '</b> · ' + ts;
  else d = 'Showing <b>' + esc(S.sourceLabel.slice(0, 80)) + '</b> · ' + S.sourceApCount + ' APs';
  sourceDesc.innerHTML = d;
  if (stale) modeChip.title = staleNote(); else modeChip.removeAttribute("title");
  if (mastDot) {   // D3: the masthead dot is the same liveness signal in every theme (chrome only, no band/alarm colour)
    const st = S.liveFeed && !S.replay && k !== "none" ? (stale ? "stale" : "live") : "off";
    mastDot.dataset.live = st;
    mastDot.title = st === "live" ? "live feed" : st === "stale" ? staleNote() : "not a live feed";
    el("pill-dot").dataset.live = st;
  }
  el("pill-chip").textContent = modeChip.textContent;   // the pill mirrors the chip
  el("panels-pill").setAttribute("aria-label", "Show the panels · " + modeChip.textContent + (stale ? " · " + staleNote() : ""));
  srcCenter.textContent = S.centerLabel;
  renderBadge(); renderLamps(); renderClock(); renderTote();
  layoutEdges();
}
function renderSourceTruth() {   // D4: every claim site; re-run on theme switch, source change and liveness change
  setSourcePanel();
  if (metaDescEl) metaDescEl.setAttribute("content", copyFor("meta"));
  if (mastTag) mastTag.textContent = copyFor("tag");
  if (mastMotto) mastMotto.textContent = copyFor("motto");
  const la = el("leg-arc"), las = la && la.querySelector("span"); if (las) las.textContent = copyFor("legArc");
  const lr = el("leg-rx"); if (lr) lr.textContent = copyFor("legRx");
  legendVisibility(); renderScope();
  const b = bannerLines(); el("classbar-top").textContent = b[0]; el("classbar-bot").textContent = b[1];
  const it = el("intro-text"); if (it && !introRunning && it.textContent) it.textContent = logonLines().join("\n");
}
function loadData(raw, label, opts = {}) {
  const doc = normalizeDoc(raw);
  if (!doc) { if (opts.paste) { pasteErr.textContent = "Could not parse: expected { aps: [ … ] }"; } return { ok: false, error: "invalid document" }; }
  const via = opts.mode === "live" || opts.mode === "demo" ? opts.mode : "recorded";
  if (S.replay) {   // U4: a replay is a view; live polls are still recorded but only shown after "Back to live"; anything else is a new source and ends it
    if (via === "live" && !opts.resume) { const fresh = recAppend(doc, srcKeyOf(doc, label, via)); S.replay.pending = doc; if (fresh) S.replay.buffered++; renderRec(); setSourcePanel(); return { ok: true, replay: true, fresh, aps: doc.aps.length, clients: 0, free: 0, assoc: 0, sourceKind: "recorded" }; }   // counts captures
    S.replay = null; applyDrawer();
  }
  const changed = setSource(doc, label, via, opts.tickMs) || opts.paste === true || opts.drop === true;   // before ingest: the detail panel that ingest re-opens reads the new source's copy; paste/drop are always a new capture (D2)
  if (changed) S.gaps = [];
  S.mode = via === "demo" ? "demo" : "live";
  recAppend(doc, S.sourceKey);   // the normalised capture, as held in memory (distinct `generated` only)
  const res = ingest(doc, { newSource: changed, resume: opts.resume });
  if (changed) particlesReset();   // only a new source re-gathers (§7.2); the same source keeps its dust — new APs gather, gone APs dissolve
  renderSourceTruth();
  S.dirty = true;
  return { ok: true, fresh: S.fresh, aps: res.aps, clients: res.clients, free: res.free, assoc: res.assoc, sourceKind: S.sourceKind };
}
function sourceHint(name) { sourceDesc.innerHTML = 'Could not read <b>' + esc(String(name).slice(0, 80)) + '</b> · still showing the previous sky'; }
// paste dialog + drag/drop
function openPaste() { pasteWrap.style.display = "flex"; pasteErr.textContent = ""; pasteTa.focus(); }
function closePaste() { pasteWrap.style.display = "none"; }
el("btn-load").addEventListener("click", openPaste);
el("paste-cancel").addEventListener("click", closePaste);
pasteWrap.addEventListener("click", (e) => { if (e.target === pasteWrap) closePaste(); });
el("paste-ok").addEventListener("click", () => {
  let obj; try { obj = JSON.parse(pasteTa.value); } catch (e) { pasteErr.textContent = "Invalid JSON: " + e.message; return; }
  const r = loadData(obj, "pasted capture", { paste: true });
  if (r.ok) closePaste();
});
window.addEventListener("dragover", (e) => e.preventDefault());
window.addEventListener("drop", (e) => {
  e.preventDefault(); const f = e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0]; if (!f) return;
  f.text().then(txt => { let obj; try { obj = JSON.parse(txt); } catch (err) { sourceHint(f.name); return; } if (!loadData(obj, f.name, { drop: true }).ok) sourceHint(f.name); });
});

// DTG clock (Whitehall chrome): DDHHMMZ MMM YY, UTC. Frozen under fixed time so screenshots stay
// deterministic; visible only in the Whitehall theme (CSS). Not in the render/fillText path.
const DTG_MON = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
function dtg2(n) { return (n < 10 ? "0" : "") + n; }
function dtgString(ms) { const d = new Date(ms); return dtg2(d.getUTCDate()) + dtg2(d.getUTCHours()) + dtg2(d.getUTCMinutes()) + "Z " + DTG_MON[d.getUTCMonth()] + " " + String(d.getUTCFullYear()).slice(2); }
function dtgTick() { const e = el("dtg"); if (!e) return; e.textContent = dtgString(S.fixedTime ?? Date.now()); }

