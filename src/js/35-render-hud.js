// ==== 35 RENDER HUD ====
const measureCache = new Map();
let labelGrid = null;
function textWidth(ctx, font, text) {
  const key = font + "|" + text; let w = measureCache.get(key);
  if (w === undefined) { ctx.font = font; w = ctx.measureText(text).width; if (measureCache.size < 2000) measureCache.set(key, w); }
  return w;
}
function labelDevCarriers() {   // §8.8: device id → the one member that carries the device label (null while device links are off)
  if (!S.ui.deviceLinks) return null;
  const m = new Map(); S.devices.forEach(d => m.set(d.id, deviceHubId(d))); return m;
}
// which APs may carry a name label, and in which order: theme-free (no fonts, raster, text budget or maxLabels cap);
// drawHud walks it, fonts and raster only place; STARCHORUS.labelCandidates() returns it for cross-theme tests.
function labelCandidateList(devCarrier) {
  const trans = S.view.blend > 0.02 && S.view.blend < 0.98;
  const prio = (n) => (n.id === S.locked ? 4 : 0) + (n.id === S.hover ? 3 : 0) + (S.pinned.has(n.id) ? 2 : 0);
  const cand = [];
  for (const ap of S.apOrder) {
    if (ap.hidden) continue;
    const forced = isForced(ap.id);
    if (trans && !forced) continue;   // during 2D↔3D transition only Hover/Pinned/Locked labels
    if (!forced && (ap.alphaDraw <= 0.6 || ap.px < 5 * Math.min(1, S.cam.zoom2d))) continue;   // zoomed out in 2D the bound shrinks with the stars
    if (!(ap.ssidKnown ?? ap.ssid)) continue;   // nothing to write
    if (devCarrier) { const dev = S.devices.get(S.deviceOf.get(ap.id)); if (dev && devCarrier.get(dev.id) !== ap.id && !forced) continue; }   // §8.8 one label per physical device
    cand.push(ap);
  }
  if (anyForced()) cand.sort((a, b) => prio(b) - prio(a) || (b.rssi * b.alphaDraw - a.rssi * a.alphaDraw));
  else cand.sort((a, b) => b.rssi * b.alphaDraw - a.rssi * a.alphaDraw);   // every prio is 0
  return cand;
}
function drawHud() {
  const ctx = ctxHud;
  ctx.globalAlpha = 1; curAlpha = 1;
  let labelsDrawn = 0, collisions = 0;
  const is3d = !scopeOn && S.view.blend > 0.5, view = is3d ? "3d" : "2d";
  const trans = S.view.blend > 0.02 && S.view.blend < 0.98;
  // Baked sprites (core text, 3D ring posts, cloud tags, device ×n counters, security glyphs, cursor glyph) are blitted, not fillText:
  // they spend no slot of RENDER.maxText; only the counted fT() draws take one from the budget.
  let budget = RENDER.maxText[view];
  const gw = Math.max(1, Math.ceil(W / RENDER.labelGridPx)), gh = Math.max(1, Math.ceil(H / RENDER.labelRowPx));
  if (!labelGrid || labelGrid.length !== gw * gh) labelGrid = new Uint8Array(gw * gh); else labelGrid.fill(0);
  const occupy = (x, y, w, h) => {
    const c0 = Math.max(0, Math.floor(x / RENDER.labelGridPx)), c1 = Math.min(gw - 1, Math.floor((x + w) / RENDER.labelGridPx));
    const r0 = Math.max(0, Math.floor(y / RENDER.labelRowPx)), r1 = Math.min(gh - 1, Math.floor((y + h) / RENDER.labelRowPx));
    for (let r = r0; r <= r1; r++) for (let c = c0; c <= c1; c++) if (labelGrid[r * gw + c]) return false;
    for (let r = r0; r <= r1; r++) for (let c = c0; c <= c1; c++) labelGrid[r * gw + c] = 1;
    return true;
  };
  // §6.6: a label box keeps labelMarginPx from the edge of the sky box (the viewport outside phone mode). place() takes the first free position that needs no
  // move, else the first free one moved inside, else drops the label; a label whose star lies off the sky (onSky) is dropped too. labelsOutside is counted
  // at the end over the drawn list (entries with a width w), not by place().
  const sk = skyR, m = RENDER.labelMarginPx, lx0 = sk.x + m, lx1 = sk.x + sk.w - m, ly0 = sk.y + m, ly1 = sk.y + sk.h - m;
  const onSky = (x, y, r) => x + r >= sk.x && x - r <= sk.x + sk.w && y + r >= sk.y && y - r <= sk.y + sk.h;
  const place = (ps, w, h) => {
    if (w > lx1 - lx0 || h > ly1 - ly0) return null;
    for (let pass = 0; pass < 2; pass++) for (const p of ps) {
      const x = clamp(p[0], lx0, lx1 - w), y = clamp(p[1], ly0, ly1 - h);
      if ((x !== p[0] || y !== p[1]) === (pass === 0) || !occupy(x, y, w, h)) continue;   // pass 0: as it lies; pass 1: moved inside
      return [x, y];
    }
    return null;
  };
  ctx.lineJoin = "round"; ctx.lineWidth = 2; ctx.textAlign = "left"; ctx.textBaseline = "alphabetic";
  // core text (fixed)
  if (!scopeOn) {
    const font = TD.fontHud, text = S.centerLabel, w = textWidth(ctx, font, text);   // D16: data strings are never transformed
    // one string that changes only with the source, so it is baked rather than re-rastered every frame: a fixed
    // post must not take a slot from the access point names. A pathological label longer than SPRITE_TEXT_MAX
    // keeps the counted fillText path, so no single string can bake a huge bitmap.
    const baked = text.length > 0 && text.length <= SPRITE_TEXT_MAX;
    if (baked || budget > 0) {
      occupy(CX - w / 2, CY + 14, w, 12);   // core text owns its cells
      if (baked) blitFixed(ctx, getSprite("text", "secondary", text, "hud"), CX, CY + 20);
      else { ctx.font = font; ctx.strokeStyle = THEME.surface.base; ctx.fillStyle = THEME.ink.secondary; fT(ctx, text, CX - w / 2, CY + 24, true); budget--; }
      labelsDrawn++;
      S.labelsList.push({ id: "__center__", kind: "label", text, x: r3(CX - w / 2), y: r3(CY + 14), w: r3(w), sprite: baked });
    }
  }
  // ring-dBm (fixed post): 3D at projected ring point (§6.6); 2D labels stay baked on #bg
  if (is3d) {
    // LAYOUT.rings: a fixed set of dBm values, baked once per theme
    for (const dbm of LAYOUT.rings) {
      const Rw = rssiToRadius(dbm) / maxRadius; projPt(0, 0, Rw, _pp);
      if (!_pp.vis) continue;
      const rt = dbm + " dBm", rw = textWidth(ctx, TD.fontHud, rt);
      blitFixed(ctx, getSprite("text", "muted", rt, "hud"), _pp.sx + 3 + rw / 2, _pp.sy - 7);
      S.labelsList.push({ id: "__ring__" + dbm, kind: "ring", text: rt, x: r3(_pp.sx), y: r3(_pp.sy), sprite: true });
    }
  }
  // §8.8 folded-ESS badges are sprites drawn in #sky — reserve their raster cells so labels step aside
  if (S.ui.essMerge) S.essClusters.forEach(c => { const f = essOfFolded(c.id); if (!f) return; const L = S.aps.get(f.leadId); if (L && L.alphaDraw > 0.05) occupy(L.sx - 16, L.sy - L.px - 17, 32, 16); });
  // §8.8a cloud tags (kept with L off), after the centre post
  if (S.ui.random === "cloud") for (const k of S.cloudOrder) {
    if (k.alphaDraw <= 0.3) continue;
    const tag = k.n + " · " + (TD.upper ? "RANDOM" : "random"), w = textWidth(ctx, TD.fontLabel, tag), r = k.px;
    if (!onSky(k.sx, k.sy, r)) continue;
    const at = place([[k.sx + r + 4, k.sy - 6], [k.sx - r - 4 - w, k.sy - 6], [k.sx - w / 2, k.sy + r + 3]], w, 12);
    if (!at) continue;
    ctx.globalAlpha = Math.min(1, k.alphaDraw); blitFixed(ctx, getSprite("text", "secondary", tag, "label"), at[0] + w / 2, at[1] + 6); ctx.globalAlpha = 1;
    S.labelsList.push({ id: k.id, kind: "cloud", text: tag, x: r3(at[0]), y: r3(at[1]), w: r3(w), sprite: true });
  }
  const devCarrier = labelDevCarriers();
  // AP labels: candidates from labelCandidateList()
  const cand = S.ui.labels ? labelCandidateList(devCarrier) : [];   // L / #t-labels off = no AP labels, facets, ×n, vendor lines, badges or cursor; core text, 3D ring posts, group labels (G) and glyph sprites stay
  const lod = S.perf.lod;
  const maxL = phoneOn ? RENDER.mobile.maxLabels : RENDER.maxLabels[lod][is3d ? 1 : 0];
  // vendor label for pinned / hovered / locked clients (§8.7), toggle-gated (E) and a node label (L), after the forced APs (§6.6)
  let cvDone = !(S.ui.vendor && S.ui.labels && anyForced());
  const cvLines = () => {
    cvDone = true;
    S.clients.forEach(c => {
      if (budget <= 0) return;
      if (c.target !== 1 || c.alphaDraw <= 0.3) return;
      if (c.bubble != null && c.bubbleBlend >= 0.5) return;
      if (!isForced(c.id) || !onSky(c.sx, c.sy, c.px)) return;
      const vt = c.randomized ? "randomised" : c.vendor; if (!vt) return;
      const vw = textWidth(ctx, font, vt);
      const vq = place([[c.sx - vw / 2, c.sy + c.px + 4]], vw, 12);
      if (!vq) return;
      ctx.font = font; ctx.strokeStyle = THEME.surface.base; ctx.fillStyle = THEME.ink.secondary;
      fT(ctx, vt, vq[0], vq[1] + 10, true); budget--; labelsDrawn++;
      S.labelsList.push({ id: c.id, kind: "vendor", text: vt, x: r3(vq[0]), y: r3(vq[1]), w: r3(vw) });
    });
  };
  let apLabels = 0, cursorAt = null, res = 0;
  const font = TD.fontLabel, wb = a => a.clientCount > 0 && lod < 3 && !scopeOn;
  const gfont = "400 10px " + THEME.font.ui, hg = S.hover ? (S.aps.get(S.hover) || {}).groupKey : null, glist = [];
  if (S.ui.groups && !trans && !scopeOn) {
    S.groups.forEach(g => { if (g.members.length < 2 || isEssFoldedSet(g.key)) return; const forced = g.key === hg; if (g.members.length < 3 && !forced) return; glist.push({ g, forced }); });
    glist.sort((a, b) => (b.forced - a.forced) || (b.g.members.length - a.g.members.length));
  }
  if (S.ui.vendor) {   // §6.6: slots kept for badges and groups
    res = Math.min(glist.length, RENDER.maxGroupLabels[view]); cand.forEach(a => { res += wb(a); });
  }
  for (const [ci, ap] of cand.entries()) {
    if (!cvDone && !isForced(ap.id)) cvLines();
    res -= wb(ap);
    if (budget <= 0) break;
    const forced = isForced(ap.id);
    if (apLabels >= maxL && !forced) continue;
    if (!onSky(ap.sx, ap.sy, ap.px)) continue;
    const dev = S.ui.deviceLinks ? S.devices.get(S.deviceOf.get(ap.id)) : null;
    const carrier = dev && devCarrier.get(dev.id) === ap.id;
    let raw = ap.ssidKnown ?? ap.ssid; if (!raw) continue;
    if (carrier) raw = ssidBase(raw) && dev.memberIds.every(id => { const a = S.aps.get(id); return !a || ssidBase(apSsid(a)) === ssidBase(raw); }) ? raw.replace(/[-_ ]?(2\.?4|5|6)\s?g(hz)?$/i, "") : raw;
    let text = raw;
    const enc = ENCODING.band[ap.band]; if (enc && !carrier && !scopeOn) text += " · " + enc.suffix;   // device label: bands shown as facets instead
    const w = textWidth(ctx, font, text), px = ap.px;
    const nFacet = carrier ? dev.bands.filter(b => b !== "unknown").length : 0, ext = carrier ? 5 + nFacet * 7 + 20 : 0;   // facets + ×n ride in the label's own rectangle
    const rest = Math.min(cand.length - 1 - ci, forced ? 99 : maxL - apLabels - 1);
    const vt = S.ui.vendor && ap.vendor && budget > rest + 1 + res + wb(ap) ? ap.vendor : "", vw = vt ? textWidth(ctx, font, vt) : 0, rw = Math.max(w + ext, vw);   // §8.7: one rectangle
    const at = (cw, up) => [[ap.sx - cw / 2, ap.sy - px - up], [ap.sx - cw / 2, ap.sy + px + 6], [ap.sx + px + 6, ap.sy - 6]], vb = vt ? place(at(rw, 26), rw, 24) : null;
    const positions = at(w + ext, 14), placed = vb || (() => { const placed = place(positions, w + ext, 12); return placed; })();
    if (!placed) { collisions++; continue; }
    ctx.font = font; ctx.strokeStyle = THEME.surface.base; ctx.fillStyle = forced ? THEME.ink.primary : THEME.ink.secondary;
    fT(ctx, text, placed[0], placed[1] + 10, true); budget--; apLabels++; labelsDrawn++;
    S.labelsList.push({ id: ap.id, kind: "label", text, x: r3(placed[0]), y: r3(placed[1]), w: r3(w + ext) });
    if (TD.cursorBlink && (ap.id === S.hover || ap.id === S.locked)) cursorAt = { x: placed[0] + w, y: placed[1] + 10 };   // one cursor (hover wins over locked)
    if (carrier) {   // §8.8 one device label + band facet dots (2.4/5/6) + "×n" member count
      const fy = placed[1] + 5;
      let fx = placed[0] + w + 5;
      for (const b of dev.bands) { if (b === "unknown") continue; ctx.fillStyle = TD.bandCore[b] || TD.bandCore.unknown; ctx.beginPath(); ctx.arc(fx, fy, 2.3, 0, Math.PI * 2); ctx.fill(); S.labelsList.push({ id: ap.id, kind: "facet", text: b, x: r3(fx), y: r3(fy) }); fx += 7; }
      blitFixed(ctx, getSprite("devcount", "secondary", dev.memberIds.length, "sharp"), fx + 7, fy);
      S.labelsList.push({ id: dev.id, kind: "counter", text: "×" + dev.memberIds.length, x: r3(fx + 7), y: r3(fy) });
    }
    if (vb) {
      ctx.fillStyle = THEME.ink.secondary; fT(ctx, vt, placed[0], placed[1] + 22, true); budget--;
      S.labelsList.push({ id: ap.id, kind: "vendor", text: vt, x: r3(placed[0]), y: r3(placed[1] + 12), w: r3(vw) });
    }
    if (ap.clientCount > 0 && lod < 3 && budget > 0 && !scopeOn) {
      const bt = String(ap.clientCount), bf = TD.fontMonoSmall, bx = ap.sx + px + 2, by = ap.sy + px + 2;
      const bq = place([[bx, by]], 14, 12);
      if (bq) {
        ctx.font = bf; ctx.fillStyle = THEME.ink.secondary; ctx.strokeStyle = THEME.surface.base;
        fT(ctx, bt, bq[0], bq[1] + 9, true); budget--;
        S.labelsList.push({ id: ap.id, kind: "badge", text: bt, x: r3(bq[0]), y: r3(bq[1]), w: 14 });
      }
    }
  }
  if (!cvDone) cvLines();
  // group labels at the constellation centroid (§8.6): ≥3 members, or any member hovered/locked
  if (glist.length) {
    let gDrawn = 0; const gMax = RENDER.maxGroupLabels[view];
    for (const { g, forced } of glist) {
      if (budget <= 0 || (gDrawn >= gMax && !forced)) continue;
      let cx = 0, cy = 0, nv = 0;
      for (const id of g.members) { const ap = S.aps.get(id); if (ap && ap.alphaDraw > 0.05) { cx += ap.sx; cy += ap.sy; nv++; } }
      if (nv === 0) continue; cx /= nv; cy /= nv;
      if (!onSky(cx, cy, 0)) continue;
      let text = g.key;
      const ws = worstSec(g.members); if (ws && SEC_RANK[ws] <= 2 && ENCODING.security[ws].glyph) text += " " + ENCODING.security[ws].glyph;   // the weakest member of the constellation (open/WEP "!", TKIP "~")
      const w = textWidth(ctx, gfont, text);
      const gq = place([[cx - w / 2, cy - 6]], w, 12);
      if (!gq) continue;
      ctx.font = gfont; ctx.strokeStyle = THEME.surface.base; ctx.fillStyle = THEME.ink.muted;
      fT(ctx, text, gq[0], gq[1] + 10, true); budget--; labelsDrawn++; gDrawn++;
      S.labelsList.push({ id: "__group__" + g.key, kind: "group", text, x: r3(gq[0]), y: r3(gq[1]), w: r3(w) });
    }
  }
  // security / alarm glyphs; alarm "!" blinks 1 Hz but is always listed
  const blink = TD.cursorBlink && !reduceMotion ? ((S.clock % 1.06) < 0.53) : true;
  for (const ap of S.apOrder) {
    if (ap.alphaDraw <= 0.4 || ap.hidden) continue;
    const enc = ENCODING.security[ap.sec]; if (!enc || !enc.glyph) continue;
    const cp = enc.glyph.codePointAt(0);
    const colorKey = enc.tone === "alarm" ? "alarm" : enc.tone === "strong" ? "strong" : enc.tone === "muted" ? "muted" : "neutral";
    const rr = ap.px + ENCODING.ringOffsetPx, gx = enc.tone === "alarm" ? ap.sx + rr * Math.SQRT1_2 : ap.sx + ap.px + 4, gy = enc.tone === "alarm" ? ap.sy - rr * Math.SQRT1_2 : ap.sy - ap.px - 4;   // D6: the "!" sits in the ring's NE gap
    if (!(enc.tone === "alarm" && !blink)) {
      const s = getSprite("glyph", colorKey, cp, "sharp");
      ctx.globalAlpha = Math.min(1, ap.alphaDraw); blitFixed(ctx, s, gx, gy); ctx.globalAlpha = 1;
    }
    S.labelsList.push({ id: ap.id, kind: "glyph", text: enc.glyph, x: r3(gx), y: r3(gy) });
  }
  // cursor block at the end of the hovered/locked label (Wargames)
  if (cursorAt && (reduceMotion || (S.clock % 1.06) < 0.53)) {
    const cw = textWidth(ctx, TD.fontLabel, "▮");   // one glyph, one bake — the blink is the blit, not a re-raster
    blitFixed(ctx, getSprite("text", "ink", "▮", "label"), cursorAt.x + 1 + cw / 2, cursorAt.y - 4);
    S.labelsList.push({ id: "__cursor__", kind: "cursor", text: "▮", x: r3(cursorAt.x + 1), y: r3(cursorAt.y - 10), sprite: true });
  }
  S.labelsDrawn = labelsDrawn; S.labelCollisions = collisions;
  S.labelsOutside = S.labelsList.filter(l => l.w && (l.x < sk.x - 0.5 || l.y < sk.y - 0.5 || l.x + l.w > sk.x + sk.w + 0.5 || l.y + 12 > sk.y + sk.h + 0.5)).length;
}

