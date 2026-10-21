// ==== 31 SPRITES ====
const spriteCache = new Map();
const spriteKeys = new Map();      // kind → colorKey → tier → variant → key string (built once, no concatenation in the frame)
const spriteSlots = [];            // call i of a frame mostly asks for the sprite call i of the frame before got: a slot answers only while its four key parts match, and all slots go when a sprite leaves the cache
let spriteUse = 0, spriteBytes = 0, spriteSlot = 0;
function spriteKey(kind, colorKey, tier, variant) {
  let a = spriteKeys.get(kind); if (!a) { a = new Map(); spriteKeys.set(kind, a); }
  let b = a.get(colorKey); if (!b) { b = new Map(); a.set(colorKey, b); }
  let c = b.get(tier); if (!c) { c = new Map(); b.set(tier, c); }
  let k = c.get(variant); if (!k) { k = THEME.meta.id + "|" + kind + "|" + colorKey + "|" + tier + "|" + variant; c.set(variant, k); }
  return k;
}
function clearSprites() { spriteCache.clear(); spriteKeys.clear(); spriteSlots.length = 0; spriteBytes = 0; }
function tierFor(px) {
  const t = RENDER.spriteTiers;
  for (let i = 0; i < t.length; i++) if (t[i] >= px) return t[i];
  return t[t.length - 1];
}
function makeCanvas(w, h) {
  if (typeof OffscreenCanvas !== "undefined") { try { return new OffscreenCanvas(w, h); } catch (e) { /* fallback below */ } }
  const c = document.createElement("canvas"); c.width = w; c.height = h; return c;
}
function colorOfKey(colorKey) {
  switch (colorKey) {
    case "b24": return TD.bandCore["2.4"]; case "b5": return TD.bandCore["5"]; case "b6": return TD.bandCore["6"]; case "unknown": return TD.bandCore.unknown;
    case "client": return THEME.render.clientCore; case "glow": case "mono": return THEME.glow.color || THEME.ink.secondary;
    case "alarm": return THEME.status.alarm; case "sel": return THEME.accent.selection;
    case "ink": return THEME.ink.primary; case "secondary": return THEME.ink.secondary; case "neutral": return THEME.status.ringNeutral; case "strong": return THEME.status.ringStrong; case "muted": return THEME.ink.muted;
    case "bt": return THEME.render.btMark;
    case "nebula": return THEME.render.nebula;
    default: return THEME.ink.primary;
  }
}
function shapePath(c, r, shape) {
  c.beginPath();
  if (shape === "diamond") { c.moveTo(0, -r); c.lineTo(r, 0); c.lineTo(0, r); c.lineTo(-r, 0); c.closePath(); }
  else if (shape === "square") { const q = r * 0.86; c.rect(-q, -q, 2 * q, 2 * q); }
  else if (shape === "hexagon") { for (let i = 0; i < 6; i++) { const a = Math.PI / 6 + i * Math.PI / 3; const x = Math.cos(a) * r, y = Math.sin(a) * r; if (i === 0) c.moveTo(x, y); else c.lineTo(x, y); } c.closePath(); }
  else c.arc(0, 0, r, 0, Math.PI * 2);
}
function getSprite(kind, colorKey, tier, variant) {
  const i = spriteSlot++, m = spriteSlots[i];
  if (m && m.kind === kind && m.colorKey === colorKey && m.tier === tier && m.variant === variant) { m.s.use = ++spriteUse; return m.s; }   // same key, sprite still cached: no Map lookup, same LRU stamp
  const key = spriteKey(kind, colorKey, tier, variant);
  let s = spriteCache.get(key);
  if (!s) {
    s = bakeSprite(kind, colorKey, tier, variant);
    if (spriteCache.size >= RENDER.spriteCap) {
      let oldK = null, oldU = Infinity;
      spriteCache.forEach((v, k) => { if (v.use < oldU) { oldU = v.use; oldK = k; } });
      if (oldK !== null) { spriteBytes -= spriteCache.get(oldK).bytes; spriteCache.delete(oldK); spriteSlots.length = 0; }
    }
    spriteCache.set(key, s); spriteBytes += s.bytes;
  }
  if (m) { m.kind = kind; m.colorKey = colorKey; m.tier = tier; m.variant = variant; m.s = s; } else spriteSlots[i] = { kind, colorKey, tier, variant, s };
  s.use = ++spriteUse;
  return s;
}
// The text budget (RENDER.maxText) is a raster budget, and it belongs to the strings that actually vary —
// access point names, vendor names, group keys. Text whose vocabulary is fixed by the CODE (the ring posts'
// dBm values, the WarGames cursor glyph, the centre post) is baked once and blitted, so it costs a drawImage
// instead of a slot. spriteTextFont keeps the three roles in one place; measuring uses its own context so a
// bake in the middle of drawHud can never leave a font behind on the HUD context.
let _measCtx = null;
function measureContext() { if (!_measCtx) _measCtx = makeCanvas(8, 8).getContext("2d"); return _measCtx; }
function spriteTextFont(role) { return role === "monoSmall" ? TD.fontMonoSmall : role === "label" ? TD.fontLabel : TD.fontHud; }
const SPRITE_TEXT_MAX = 32;   // a longer string is left to fillText: one runaway label must not bake a huge bitmap
function bakeSprite(kind, colorKey, tier, variant) {
  // #hud is rastered at hudDpr, not S.perf.dpr: RENDER.hudMinDpr keeps HUD text crisp while the governor
  // scales the sky down. A "text" sprite is blitted onto #hud, so it must be baked at that same scale --
  // otherwise the baked posts would be upscaled and soft next to the names that fT() still draws directly.
  const dpr = kind === "text" ? hudDpr : S.perf.dpr, pad = 3;
  const soft = variant === "soft";
  const mult = kind === "phosphor" ? THEME.render.phosphor.radiusFactor : kind === "glow" ? TD.glowMult : (kind === "client" || kind === "clientAssoc" || kind === "clientCross") ? 2.2 : 1.6;   // kinds with a fixed box below ignore it
  const cr = LAYOUT.coreRadiusPx, t = clamp((tier - cr[0]) / Math.max(1, cr[1] - cr[0]), 0, 1);   // bloom ramp over the theme-free core range
  let side = Math.ceil(2 * tier * mult * (soft ? 1.3 : 1) + 2 * pad), w = side, h = side;
  if (kind === "counter") { w = 32; h = 16; }
  else if (kind === "text") { w = Math.ceil(textWidth(measureContext(), spriteTextFont(variant), String(tier))) + 2 * pad + 2; h = 18; }
  else if (kind === "devcount") { w = 22; h = 12; }
  else if (kind === "glyph") { w = 16; h = 16; }
  else if (kind === "dot") { const gl = THEME.line.edge.glowPx || 6; w = h = Math.ceil(2 * (2 + gl) + 2 * pad); }
  else if (kind === "core") { w = h = 2 * 48 + 2 * pad; }
  else if (kind === "flare") { const HL = 42; w = Math.ceil(2 * HL + 2 * pad); h = Math.ceil(2 * HL * 0.35 + 2 * pad); }
  else if (kind === "nebula") { w = h = 2 * 24 + 2 * pad; }
  const cv = makeCanvas(Math.ceil(w * dpr), Math.ceil(h * dpr));
  const c = cv.getContext("2d");
  c.setTransform(dpr, 0, 0, dpr, 0, 0);
  c.translate(w / 2, h / 2);
  const color = colorOfKey(colorKey);
  const bloom = THEME.rssi.bloomPx[1] > 0 ? lerp(THEME.rssi.bloomPx[0], THEME.rssi.bloomPx[1], t) : 0;
  const base = THEME.surface.base;
  const disc = (r) => { c.beginPath(); c.arc(0, 0, r, 0, Math.PI * 2); };   // centred circle path
  const radial = (R, stops) => { const g = c.createRadialGradient(0, 0, 0, 0, 0, R); for (const [o, col] of stops) g.addColorStop(o, col); c.fillStyle = g; disc(R); c.fill(); };
  switch (kind) {
    case "glow": case "phosphor": {
      radial(tier * mult * (soft ? 1.3 : 1), soft ? [[0, rgbaOf(color, 0.5)], [0.4, rgbaOf(color, 0.22)], [1, rgbaOf(color, 0)]]
        : [[0, rgbaOf(color, 1)], [0.25, rgbaOf(color, 0.55)], [0.6, rgbaOf(color, 0.16)], [1, rgbaOf(color, 0)]]);
      break;
    }
    case "coreCircle": case "coreDiamond": case "coreHex": case "coreSquare": {
      const shape = kind === "coreDiamond" ? "diamond" : kind === "coreHex" ? "hexagon" : kind === "coreSquare" ? "square" : "circle";
      if (soft) { radial(tier * mult * 1.3, [[0, rgbaOf(color, 0.5)], [0.5, rgbaOf(color, 0.18)], [1, rgbaOf(color, 0)]]); break; }
      if (THEME.render.shapeFill) {
        shapePath(c, tier, shape); c.fillStyle = color; c.fill();
        c.fillStyle = rgbaOf(THEME.ink.primary, 0.9); disc(tier * 0.45); c.fill();
      } else {
        if (bloom > 0) { c.shadowColor = color; c.shadowBlur = bloom; }
        shapePath(c, tier, shape); c.strokeStyle = color; c.lineWidth = 1; c.stroke();
        c.shadowBlur = 0;   // crisp centre dot (no bloom → stable centre pixel under persistence)
        disc(2.2); c.fillStyle = color; c.fill();
      }
      break;
    }
    case "client": case "clientAssoc": {
      const r = tier, halo = colorOfKey("glow");
      if (soft) { radial(r * mult * 1.3, [[0, rgbaOf(THEME.render.clientCore, 0.5)], [0.5, rgbaOf(halo, 0.15)], [1, rgbaOf(halo, 0)]]); break; }
      if (TD.glowOn) radial(r * 2.2, [[0, rgbaOf(halo, 0.25)], [1, rgbaOf(halo, 0)]]);
      if (kind === "clientAssoc") { disc(r + 2); c.strokeStyle = color; c.lineWidth = 1; c.stroke(); }
      disc(r + 0.5); c.strokeStyle = rgbaOf(base, 0.9); c.lineWidth = 1; c.stroke();
      if (variant === "rnd") { disc(r - 0.3); c.strokeStyle = THEME.render.clientCore; c.lineWidth = 1.4; c.stroke(); }   // D8 hollow = randomised MAC
      else { disc(r); c.fillStyle = THEME.render.clientCore; c.fill(); }
      break;
    }
    case "clientCross": {
      const lm = /^L(\d)(x?)$/.exec(variant), lvl = lm ? +lm[1] : 2, xm = !!(lm && lm[2]);   // D8: arm length = signal level (0 strongest); "x" = randomised MAC drawn as an X
      const arm = [4, 3.25, 2.5, 1.75][Math.min(3, lvl)], cc = THEME.render.clientCore;
      if (THEME.rssi.bloomPx[1] > 0) { c.shadowColor = cc; c.shadowBlur = 4; }
      c.strokeStyle = cc; c.lineWidth = 1;
      c.beginPath();
      if (xm) { const q = arm * 0.78; c.moveTo(-q, -q + 0.5); c.lineTo(q, q + 0.5); c.moveTo(q, -q + 0.5); c.lineTo(-q, q + 0.5); }
      else { c.moveTo(-arm, 0.5); c.lineTo(arm, 0.5); c.moveTo(0.5, -arm); c.lineTo(0.5, arm); }
      c.stroke();
      if (colorKey !== "client") { c.shadowColor = color; disc(tier + 2); c.strokeStyle = color; c.stroke(); }
      c.shadowBlur = 0;
      break;
    }
    case "bt": {   // §3.3 triangle: filled = fixed, hollow = rotating, hd = folded
      c.beginPath(); c.moveTo(0, -tier); c.lineTo(tier * 0.9, tier * 0.7); c.lineTo(-tier * 0.9, tier * 0.7); c.closePath();
      c.lineWidth = 1.25; c.strokeStyle = color; c.stroke();
      if (variant !== "h") { if (variant === "hd") disc(1.5); c.fillStyle = color; c.fill(); }
      break;
    }
    case "traffic": {   // §3.8 cue level L1..L3: four ticks at 45 degrees
      const r0 = Math.min(4, tier) + 1.5; c.strokeStyle = THEME.render.clientCore; c.lineWidth = 1; c.beginPath(); c.rotate(Math.PI / 4);
      for (let i = 0; i < 4; i++) { c.moveTo(0, -r0); c.lineTo(0, -r0 - 0.5 - 1.5 * +variant[1]); c.rotate(Math.PI / 2); }
      c.stroke();
      break;
    }
    case "core": {
      if (THEME.render.coreMark === "ownship") {   // an unframed ship symbol (the observer); form only, ink.primary — no ring, no halo
        c.fillStyle = THEME.ink.primary; c.beginPath(); c.moveTo(0, -10); c.lineTo(4.5, -2); c.lineTo(3.5, 8); c.lineTo(-3.5, 8); c.lineTo(-4.5, -2); c.closePath(); c.fill();
        c.fillStyle = THEME.surface.base; disc(1.2); c.fill();
        break;
      }
      if (THEME.render.shapeFill) { const halo = colorOfKey("glow"); radial(46, [[0, rgbaOf(halo, 0.35)], [0.5, rgbaOf(halo, 0.08)], [1, rgbaOf(halo, 0)]]); }
      c.fillStyle = THEME.ink.primary; disc(4.5); c.fill();
      c.strokeStyle = rgbaOf(THEME.ink.secondary, 0.7); c.lineWidth = 1; disc(10.5); c.stroke();
      if (!THEME.render.shapeFill) { c.setLineDash([2, 3]); disc(18.5); c.strokeStyle = rgbaOf(THEME.ink.muted, 0.6); c.stroke(); c.setLineDash([]); }
      break;
    }
    case "devcount": {
      c.textAlign = "center"; c.textBaseline = "middle"; c.font = "400 9px " + THEME.font.ui; c.fillStyle = THEME.ink.secondary;
      c.fillText("×" + tier, 0, 0.5);
      break;
    }
    case "text": {   // a fixed-vocabulary HUD string with the same halo the counted path draws (fT(..., true))
      c.textAlign = "center"; c.textBaseline = "middle"; c.font = spriteTextFont(variant);
      c.lineJoin = "round"; c.lineWidth = 2; c.strokeStyle = base; c.strokeText(String(tier), 0, 0);
      c.fillStyle = color; c.fillText(String(tier), 0, 0);
      break;
    }
    case "counter": {
      c.textAlign = "center"; c.textBaseline = "middle";
      if (tier === 0) { c.font = "400 8px " + THEME.font.ui; c.fillStyle = THEME.ink.secondary; c.fillText(TD.upper ? "CLIENTS" : "clients", 0, 0); }   // caption is text (>= 4.5:1 on bubbleFill)
      else { c.font = THEME.font.weight.hero + " 12px " + THEME.font.ui; c.fillStyle = THEME.ink.primary; c.fillText(String(tier), 0, 0); }
      break;
    }
    case "glyph": {
      c.textAlign = "center"; c.textBaseline = "middle";
      c.font = "700 11px " + THEME.font.mono;
      if (bloom > 0) { c.shadowColor = color; c.shadowBlur = 4; }
      c.lineWidth = 2; c.strokeStyle = rgbaOf(base, 0.9); c.strokeText(String.fromCodePoint(tier), 0, 0.5);
      c.fillStyle = color; c.fillText(String.fromCodePoint(tier), 0, 0.5);
      c.shadowBlur = 0;
      break;
    }
    case "flare": {
      const HL = 42, HLV = HL * 0.35, fc = THEME.accent.flare, pa = parseColor(fc)[3] || 1;
      const hg = c.createLinearGradient(-HL, 0, HL, 0);
      hg.addColorStop(0, rgbaOf(fc, 0)); hg.addColorStop(0.5, rgbaOf(fc, 1)); hg.addColorStop(1, rgbaOf(fc, 0));
      c.fillStyle = hg; c.fillRect(-HL, -0.75, 2 * HL, 1.5);
      const vg = c.createLinearGradient(0, -HLV, 0, HLV), vm = pa > 0 ? 0.08 / pa : 0.44;
      vg.addColorStop(0, rgbaOf(fc, 0)); vg.addColorStop(0.5, rgbaOf(fc, vm)); vg.addColorStop(1, rgbaOf(fc, 0));
      c.fillStyle = vg; c.fillRect(-0.75, -HLV, 1.5, 2 * HLV);
      break;
    }
    case "dot": {   // travel / probe-arc dot, 1.5 px core with baked phosphor bloom
      const gl = THEME.line.edge.glowPx || 6;
      if (gl > 0) { c.shadowColor = color; c.shadowBlur = gl; }
      c.fillStyle = color; disc(1.5); c.fill();
      c.shadowBlur = 0;
      break;
    }
    case "nebula": {   // §8.2 neutral interference wash (chroma < 0.1, never band/status colour)
      radial(24, [[0, rgbaOf(color, 1)], [0.55, rgbaOf(color, 0.35)], [1, rgbaOf(color, 0)]]);
      break;
    }
  }
  return { c: cv, w, h, bytes: Math.ceil(w * dpr) * Math.ceil(h * dpr) * 4, use: 0, tier, kind, dpr };   // kind/dpr: tests check that HUD text is baked at the HUD scale
}

