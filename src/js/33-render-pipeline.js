// ==== 33 RENDER PIPELINE ====
const DC = S.perf.drawCalls;
let curAlpha = 1;
function setAlpha(ctx, a) {
  let q = Math.round(clamp(a, 0, 1) * RENDER.alphaSteps) / RENDER.alphaSteps;
  if (S.persistOn && ctx === ctxSky) {   // §6.7 alpha compensation so steady-state brightness matches no-persistence
    const P = THEME.crt.persistenceAlpha;
    q = q * P / (1 - q * (1 - P));
  }
  if (q !== curAlpha) { ctx.globalAlpha = q; curAlpha = q; }
}
function dI(ctx, img, x, y, w, h) { ctx.drawImage(img, x, y, w, h); if (S.countCalls) DC.drawImage++; }
function fR(ctx, x, y, w, h) { ctx.fillRect(x, y, w, h); if (S.countCalls) DC.fillRect++; }
function sT(ctx) { ctx.stroke(); if (S.countCalls) DC.stroke++; }
function fT(ctx, text, x, y, halo) { if (halo) ctx.strokeText(text, x, y); ctx.fillText(text, x, y); if (S.countCalls) DC.fillText++; }
// DC.shadowBlur / DC.gradient stay 0: the hot path neither blurs live nor builds gradients (bloom and halos are baked in §31)
function isForced(id) { return id === S.hover || id === S.locked || S.pinned.has(id); }   // hovered, locked or pinned: always drawn and labelled
function anyForced() { return S.hover != null || S.locked != null || S.pinned.size > 0; }   // false: isForced() is false for every node (an id is never null), so a scan that only looks for forced nodes finds none
function beginFrame() {
  spriteSlot = 0;
  ctxHud.clearRect(0, 0, W, H);
  const P = THEME.crt.persistenceAlpha;
  S.persistOn = P > 0 && S.ui.crt && !(scopeOn && wavePhase() >= 1);
  if (S.persistOn) {   // §6.7 phosphor persistence: fade #sky towards transparent, #bg shows through (no black rect)
    ctxSky.globalCompositeOperation = "destination-out";
    ctxSky.globalAlpha = 1;
    ctxSky.fillStyle = "rgba(0,0,0," + P + ")";
    ctxSky.fillRect(0, 0, W, H);
    ctxSky.globalCompositeOperation = "source-over";
  } else {
    ctxSky.clearRect(0, 0, W, H);
  }
  ctxSky.globalAlpha = 1; ctxHud.globalAlpha = 1; curAlpha = 1;
  if (S.labelsList) S.labelsList.length = 0;
}
function endFrame() { ctxSky.globalAlpha = 1; ctxHud.globalAlpha = 1; curAlpha = 1; ctxSky.globalCompositeOperation = "source-over"; }
function render() {
  DC.drawImage = 0; DC.fillRect = 0; DC.stroke = 0; DC.fillText = 0; DC.cue = 0; DC.traffic = 0;
  beginFrame();
  if (scopeOn) { drawScope(); endFrame(); return; }
  drawBackground(); drawRings(); drawShadows(); drawNebula(); drawConstellations();
  drawGlows(); drawEdges(); drawOrbits(); drawDeviceLinks();
  drawClients(); drawClouds(); drawBt(); drawBubbles(); drawStars();
  drawRecvRing(); drawGhosts(); drawThreshold(); drawChangeCues(); drawFlares(); drawParticles();
  drawHud();
  endFrame();
  if (S.anim.flickerAmp > 0 && !reduceMotion) {   // Layer 14: seeded ≤2 Hz flicker on #sky (canvas readback unaffected)
    const ph = Math.floor(S.clock * 2);
    canvasSky.style.opacity = (1 - S.anim.flickerAmp * hash(ph + "flk")).toFixed(4);
  } else if (canvasSky.style.opacity) canvasSky.style.opacity = "";
}

