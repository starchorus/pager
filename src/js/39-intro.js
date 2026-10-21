// ==== 39 INTRO ====
function logonLines() {   // D4/D13: theme voice from copy tokens; the mode line follows the current source
  const c = THEME.copy, ls = c.logonListen[S.sourceKind === "active" ? "active" : "rx"];   // the listen-only line is a passivity claim: it lives in the copy tokens and is absent when the source is active
  return c.logonHead.concat([c.logonMode[S.sourceKind] || c.logonMode.none], ls ? [ls] : [], c.logonTail);
}
function bannerLines() {   // classbar (visible in Whitehall): the {src} slot is the collector's source name, upper-cased chrome (never an SSID or another data string)
  const c = THEME.copy, src = String(S.source || "unknown").toUpperCase().replace(/[^A-Z0-9 .:_-]/g, "").slice(0, 24) || "UNKNOWN";
  return [c.bannerTop, (c.bannerBot[S.sourceKind] || c.bannerBot.none).replace("{src}", src)];
}
let introTimers = [], introRunning = false, logonWait = null, coalesceUntil = -1;
const COALESCE_S = 1.8, COALESCE_MUL = 2;   // the dust gathers from twice its usual distance over twice its usual time
// D13: one "already seen" flag per theme id, so each theme still introduces itself once per session.
function introKey() { return "introShown." + THEME.meta.id; }
function introSeen() { return sessionFlag(introKey()); }
// D13: the intro style is a token. §39 may know theme ids, but with a token it does not have to.
function runIntro() {
  // switching themes while the previous theme's intro is still running ends that one first — otherwise the
  // new theme's intro would silently never start, which is the very thing the per-theme flag exists to prevent
  if (introRunning) { endCoalesce(); skipLogon(); }
  const style = THEME.motion.introStyle;
  if (style === "typed") runLogon();
  else if (style === "coalesce") runCoalesce();
}
// no black screen and no typed text — the real capture's own dust condenses into the sky.
// Frozen time means a measured run, so it is skipped there: no screenshot and no digest may move because of it.
function runCoalesce() {
  if (introRunning || S.fixedTime != null) return;
  introRunning = true; sessionFlag(introKey(), true);
  coalesceUntil = S.clock + COALESCE_S;
  S.dirty = true; S.moving = true;
  document.addEventListener("pointerdown", skipIntro);
  document.addEventListener("keydown", skipIntro);
  introTimers.push(setTimeout(endCoalesce, COALESCE_S * 1000));
}
function endCoalesce() {
  if (coalesceUntil < 0) return;
  coalesceUntil = -1; introRunning = false; S.dirty = true; S.moving = true;
  document.removeEventListener("pointerdown", skipIntro);
  document.removeEventListener("keydown", skipIntro);
}
// read by stepParticles (§32): 2 while the intro condenses, 1 otherwise
function introGatherMul() { return coalesceUntil > 0 && S.clock < coalesceUntil ? COALESCE_MUL : 1; }
function skipIntro() { if (coalesceUntil > 0) { endCoalesce(); return true; } return skipLogon(); }
function runLogon() {
  if (introRunning) return; introRunning = true; sessionFlag(introKey(), true);
  const intro = el("intro"), pre = el("intro-text");
  intro.style.display = "block"; pre.textContent = "";
  let li = 0, ci = 0, out = "", line = null;
  const rnd = mulberry32(0x109104);
  const step = () => {
    const n = logonLines().length;
    if (li >= n) { introTimers.push(setTimeout(endLogon, 400)); return; }
    if (line === null) line = logonLines()[li];   // D13: a line is computed when its typing starts, then frozen
    if (ci < line.length) { out += line[ci++]; pre.textContent = out + "▮"; introTimers.push(setTimeout(step, lerp(THEME.motion.logonCharMs[0], THEME.motion.logonCharMs[1], rnd()))); }   // a visible cursor while it types
    else { out += "\n"; li++; ci = 0; line = null; pre.textContent = out + "▮"; introTimers.push(setTimeout(step, li === n - 1 ? 1200 : 350)); }
  };
  if (firstPollDone) step();   // D13: typing starts after the first completed poll (success or 404), at the latest after 1 s
  else { logonWait = step; introTimers.push(setTimeout(releaseLogon, 1000)); }
}
function releaseLogon() { const f = logonWait; logonWait = null; if (f) f(); }
function endLogon() {
  const intro = el("intro"); intro.classList.add("out"); introTimers.push(setTimeout(() => { intro.style.display = "none"; intro.classList.remove("out"); introRunning = false; }, 300));
}
function skipLogon() {
  if (!introRunning) return false;
  introTimers.forEach(clearTimeout); introTimers = []; logonWait = null;
  el("intro-text").textContent = logonLines().join("\n");
  const intro = el("intro"); intro.classList.remove("out"); intro.style.display = "none"; introRunning = false;
  return true;
}
el("intro-skip").addEventListener("click", skipLogon);
el("intro").addEventListener("click", skipLogon);
dtgTick(); setInterval(dtgTick, 1000);

