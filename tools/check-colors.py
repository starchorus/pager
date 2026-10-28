#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""tools/check-colors.py -- colour-role validator (docs/architecture.md §14).

Reads the three theme token sets (foundation / wargames / whitehall) and checks that every colour plays its ROLE:
data colours (band, unknown, alarm) stay apart from chrome, selection, aggregates and ornaments in every theme.
dE = OKLab distance x 100 after compositing the colour over `surface.base`; chroma C and OKLCH lightness L are
taken from the token's own rgb (its alpha is a separate property).

  python3 tools/check-colors.py THEMES.json          # THEMES.json: the theme object, or a cdp.py report whose
                                                     # first eval is JSON.stringify(STARCHORUS._internals.THEMES)
  python3 tools/check-colors.py THEMES.json --table  # also print every measured number
  python3 tools/check-colors.py --selftest           # the maths against known colours (no page needed)

Exit 0 = every rule holds in every theme; 1 = at least one FAIL; 2 = usage/input problem.
Stdlib only, no network; a dev-machine tool (nothing here runs on the device).

Rules (role -> token paths -> rule), the table of §4.1:
  band       band.{2.4,5,6}.core            OKLCH hue 2.4 in 140-190, 5 in 220-265, 6 in 285-315; pairwise dE >= 15
  unknown    band.unknown.core              chroma < 0.05; dE >= 10 to status.ringNeutral and render.bubbleStroke
  alarm      status.alarm                   dE >= 15 to band cores, selection, pin (ink.secondary), chrome, aggregate
  alert      status.alert                   OKLCH hue 15-40 (red); dE >= 15 to band cores and selection (it may equal the alarm: Whitehall's does)
  bt         render.btMark                  OKLCH hue 325-360; dE >= 15 to band cores, alarm, selection, chrome and render.clientCore;
                                            dE >= 10 to band.unknown.core, status.ringNeutral and status.hidden
  selection  accent.selection, focusRing    chroma < 0.05 and OKLCH L >= 0.85
  chrome     chrome.*, accent.toggle*       dE >= 15 to band cores and alarm
  aggregate  render.bubbleStroke, line.edge.color, render.nebula, line.device      chroma < 0.05
  ornament   particles.color, glow.color, accent.flare, render.starfield.color, look.clock.*   dE >= 8 to alarm
Fully transparent or null tokens carry no colour and are skipped. A string that starts with #, rgb or hsl but is not
one of #rrggbb, rgb(r, g, b) or rgba(r, g, b, a) (so #rgb, #rrggbbaa, rgb(r g b / a), hsl(...)) cannot be measured: it is a
FAIL (role input), never skipped.
"""
import itertools
import json
import math
import re
import sys

THEMES = ("foundation", "wargames", "whitehall")
BANDS = ("2.4", "5", "6")
HUE = {"2.4": (140, 190), "5": (220, 265), "6": (285, 315)}
HEX = re.compile(r"^#([0-9a-fA-F]{6})$")
RGBA = re.compile(r"^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$")
COLOURISH = re.compile(r"^\s*(#|rgb|hsl)", re.I)   # a string that claims to be a colour; if parse() cannot read it, it is reported, not dropped


def parse(c):
    """CSS colour -> (r, g, b, a) with 0-255 channels, or None (null / unparsable / keyword)."""
    if not isinstance(c, str):
        return None
    c = c.strip()
    m = HEX.match(c)
    if m:
        n = int(m.group(1), 16)
        return ((n >> 16) & 255, (n >> 8) & 255, n & 255, 1.0)
    m = RGBA.match(c)
    if m:
        return (float(m.group(1)), float(m.group(2)), float(m.group(3)), 1.0 if m.group(4) is None else float(m.group(4)))
    return None


def lin(v):
    v /= 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def oklab(rgb):
    r, g, b = (lin(x) for x in rgb[:3])
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (x ** (1 / 3) for x in (l, m, s))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def lch(rgb):
    L, a, b = oklab(rgb)
    return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360


def over(fg, base):
    a = max(0.0, min(1.0, fg[3]))
    return tuple(round(fg[i] * a + base[i] * (1 - a)) for i in range(3))


def dE(x, y):
    p, q = oklab(x), oklab(y)
    return 100 * math.sqrt(sum((p[i] - q[i]) ** 2 for i in range(3)))


def get(t, path):
    """Token lookup; keys may contain a dot ("band.2.4.core"): try the longest matching key first."""
    parts, cur, i = path.split("."), t, 0
    while i < len(parts):
        if not isinstance(cur, dict):
            return None
        for ln in range(len(parts) - i, 0, -1):
            k = ".".join(parts[i:i + ln])
            if k in cur:
                cur = cur[k]
                i += ln
                break
        else:
            return None
    return cur


def leaves(t, path, out):
    v = get(t, path)
    if isinstance(v, dict):
        for k in v:
            leaves(t, path + "." + k, out)
    elif isinstance(v, str) and parse(v) is not None:
        out.append(path)


def unreadable(v, path, out):
    """Appends (path, value) for every string under v that looks like a colour (COLOURISH) but parse() cannot read."""
    if isinstance(v, dict):
        for k in v:
            unreadable(v[k], path + "." + k if path else k, out)
    elif isinstance(v, list):
        for i, x in enumerate(v):
            unreadable(x, "%s[%d]" % (path, i), out)
    elif isinstance(v, str) and COLOURISH.match(v) and parse(v) is None:
        out.append((path, v))


def check(themes):
    rows = []

    def rec(theme, role, ok, msg):
        rows.append((theme, role, ok, msg))

    for th in THEMES:
        t = themes.get(th)
        if not isinstance(t, dict):
            rec(th, "input", False, "theme missing")
            continue
        bad = []
        unreadable(t, "", bad)
        for path, v in bad:   # every other rule skips a token it cannot read, so this is the one place that says so
            rec(th, "input", False, "%s unreadable colour %r (want #rrggbb, rgb(r, g, b) or rgba(r, g, b, a))" % (path, v[:40]))
        base = parse(get(t, "surface.base"))
        if base is None:
            rec(th, "input", False, "surface.base unreadable")
            continue
        base = tuple(base[:3])

        def col(path):
            c = parse(get(t, path))
            return c if c is not None and c[3] > 0 else None

        def flat(path):
            c = col(path)
            return None if c is None else over(c, base)

        band = {b: flat("band.%s.core" % b) for b in BANDS}
        unk = flat("band.unknown.core")
        alarm = flat("status.alarm")

        def expand(roots):   # every colour leaf under the roots
            out = []
            for p in roots:
                leaves(t, p, out)
            return [p for p in out if col(p)]

        sel = [p for p in ("accent.selection", "accent.focusRing") if col(p)]
        pin = [p for p in ("ink.secondary",) if col(p)]   # the pin mark's notched arc (docs/architecture.md D5)
        chrome_paths = expand(("chrome", "accent.toggleOn", "accent.toggleInk", "accent.toggleBorder"))
        agg = [p for p in ("render.bubbleStroke", "line.edge.color", "render.nebula", "line.device") if col(p)]
        orn = expand(("particles.color", "glow.color", "accent.flare", "render.starfield.color", "look.clock"))

        # band: hue windows + pairwise separation
        for b in BANDS:
            if band[b] is None:
                rec(th, "band", False, "band.%s.core missing" % b)
                continue
            _, c, h = lch(band[b])
            lo, hi = HUE[b]
            rec(th, "band", lo <= h <= hi, "band %s hue %.0f deg (want %d-%d) C %.3f" % (b, h, lo, hi, c))
        for x, y in itertools.combinations(BANDS, 2):   # the three data bands apart; "unknown" has its own row below
            if band[x] is not None and band[y] is not None:
                d = dE(band[x], band[y])
                rec(th, "band", d >= 15, "dE band %s vs %s = %.1f (>= 15)" % (x, y, d))

        # unknown: neutral, and apart from the aggregate neutrals
        if unk is None:
            rec(th, "unknown", False, "band.unknown.core missing")
        else:
            _, c, _h = lch(unk)
            rec(th, "unknown", c < 0.05, "unknown C %.3f (< 0.05)" % c)
            for p in ("status.ringNeutral", "render.bubbleStroke"):
                o = flat(p)
                if o is not None:
                    d = dE(unk, o)
                    rec(th, "unknown", d >= 10, "dE unknown vs %s = %.1f (>= 10)" % (p, d))

        # alarm vs everything that must not be mistaken for it
        if alarm is None:
            rec(th, "alarm", False, "status.alarm missing")
        else:
            for b in BANDS:
                if band[b] is not None:
                    d = dE(alarm, band[b])
                    rec(th, "alarm", d >= 15, "dE alarm vs band %s = %.1f (>= 15)" % (b, d))
            for p in sel + pin + chrome_paths + agg:
                o = flat(p)
                if o is not None:
                    d = dE(alarm, o)
                    rec(th, "alarm", d >= 15, "dE alarm vs %s = %.1f (>= 15)" % (p, d))
        if not pin:
            rec(th, "alarm", False, "ink.secondary (the pin mark) missing")

        # alert: the ring of an alerted access point (the firmware's deauth/disassoc alert) is red, and apart from the data bands and from selection
        alert = flat("status.alert")
        if alert is None:
            rec(th, "alert", False, "status.alert missing")
        else:
            _, c, h = lch(alert)
            rec(th, "alert", 15 <= h <= 40, "status.alert hue %.0f deg (want 15-40, red) C %.3f" % (h, c))
            for b in BANDS:
                if band[b] is not None:
                    d = dE(alert, band[b])
                    rec(th, "alert", d >= 15, "dE alert vs band %s = %.1f (>= 15)" % (b, d))
            for p in sel:
                o = flat(p)
                if o is not None:
                    d = dE(alert, o)
                    rec(th, "alert", d >= 15, "dE alert vs %s = %.1f (>= 15)" % (p, d))

        # bt: the Bluetooth mark (a rose between the violet 6 GHz band and the alarms): apart from every data colour and from the neutrals it could be taken for
        btc = flat("render.btMark")
        if btc is None:
            rec(th, "bt", False, "render.btMark missing")
        else:
            _, c, h = lch(btc)
            rec(th, "bt", 325 <= h <= 360, "render.btMark hue %.0f deg (want 325-360) C %.3f" % (h, c))
            far = [("band %s" % b, band[b]) for b in BANDS if band[b] is not None] + ([("status.alarm", alarm)] if alarm else [])
            far += [(p, flat(p)) for p in sel + chrome_paths + ["render.clientCore"] if flat(p) is not None]
            for name, o in far:
                d = dE(btc, o)
                rec(th, "bt", d >= 15, "dE btMark vs %s = %.1f (>= 15)" % (name, d))
            for p in ("band.unknown.core", "status.ringNeutral", "status.hidden"):
                o = flat(p)
                if o is not None:
                    d = dE(btc, o)
                    rec(th, "bt", d >= 10, "dE btMark vs %s = %.1f (>= 10)" % (p, d))

        # selection: the brightest neutral of the theme
        for p in sel:
            L, c, _h = lch(col(p))
            rec(th, "selection", c < 0.05 and L >= 0.85, "%s L %.2f (>= 0.85) C %.3f (< 0.05)" % (p, L, c))
        if len(sel) < 2:
            rec(th, "selection", False, "accent.selection/focusRing missing")

        # chrome: never a band or alarm colour
        for p in chrome_paths:
            o = flat(p)
            worst = min([dE(o, band[b]) for b in BANDS if band[b] is not None] + ([dE(o, alarm)] if alarm else []))
            rec(th, "chrome", worst >= 15, "%s nearest band/alarm dE %.1f (>= 15)" % (p, worst))

        # aggregates: neutral
        for p in agg:
            _L, c, _h = lch(col(p))
            rec(th, "aggregate", c < 0.05, "%s C %.3f (< 0.05)" % (p, c))

        # ornament: apart from the alarm colour, never data-bearing
        for p in orn:
            o = flat(p)
            if alarm is not None and o is not None:
                d = dE(o, alarm)
                rec(th, "ornament", d >= 8, "%s dE to alarm %.1f (>= 8)" % (p, d))

    return rows, sum(1 for r in rows if not r[2])


def selftest():
    fails = 0

    def eq(name, got, want, tol):
        nonlocal fails
        ok = abs(got - want) <= tol
        print("%-4s %s: %.4f (want %.4f +- %g)" % ("ok" if ok else "FAIL", name, got, want, tol))
        fails += not ok

    white, black, red = (255, 255, 255), (0, 0, 0), (255, 0, 0)
    eq("L(white)", oklab(white)[0], 1.0, 0.001)
    eq("L(black)", oklab(black)[0], 0.0, 0.001)
    eq("C(white)", lch(white)[1], 0.0, 0.001)
    eq("dE(white,black)", dE(white, black), 100.0, 0.5)
    L, c, h = lch(red)
    eq("L(red)", L, 0.628, 0.002)
    eq("C(red)", c, 0.2577, 0.002)
    eq("hue(red)", h, 29.23, 0.2)
    eq("over(50% white on black) L", oklab(over((255, 255, 255, 0.5), black))[0], oklab((128, 128, 128))[0], 0.005)
    eq("get band.2.4.core", 1.0 if get({"band": {"2.4": {"core": "#000"}}}, "band.2.4.core") == "#000" else 0.0, 1.0, 0)

    # what the validator must not drop silently: a token it cannot read, and the pin in the alarm comparison. A bare-bones token
    # set (one chrome token, the pin, the alarm, a surface) is enough; every other role is red for its missing tokens and ignored here.
    def mini(chrome_ink, pin):
        t = {"surface": {"base": "#000000"}, "status": {"alarm": "#e0b95a"}, "chrome": {"ink": chrome_ink}}
        if pin is not None:
            t["ink"] = {"secondary": pin}
        return {th: t for th in THEMES}

    def named(themes, role, word, ok):
        return sum(1 for _th, r, good, msg in check(themes)[0] if r == role and word in msg and good == ok)

    for bad_tok in ("#e0b95aff", "#eb5", "rgb(224 185 90)", "hsl(41, 70%, 62%)"):
        eq("unreadable %s is a FAIL, one per theme" % bad_tok, named(mini(bad_tok, "#9aa7c4"), "input", "unreadable colour", False), 3, 0)
    eq("a readable token is not reported unreadable", named(mini("#e0b95a", "#9aa7c4"), "input", "unreadable colour", False), 0, 0)
    eq("rgba() and transparent are not reported unreadable", named(mini("rgba(224, 185, 90, 0.5)", "transparent"), "input", "unreadable colour", False), 0, 0)
    eq("alarm vs a distant pin is measured, one row per theme", named(mini("#e0b95a", "#9aa7c4"), "alarm", "ink.secondary", True), 3, 0)
    eq("alarm vs a pin of the alarm colour is a FAIL, one per theme", named(mini("#e0b95a", "#e0b95a"), "alarm", "ink.secondary", False), 3, 0)
    eq("no pin token is a FAIL, one per theme", named(mini("#e0b95a", None), "alarm", "ink.secondary", False), 3, 0)
    print("selftest %s" % ("FAILED (%d)" % fails if fails else "ok"))
    return 1 if fails else 0


def load(path):
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    if isinstance(d, dict) and "eval" in d:
        d = d["eval"][0]["value"]
    if isinstance(d, str):
        d = json.loads(d)
    return d


def main(argv):
    if "--selftest" in argv:
        return selftest()
    args = [a for a in argv if not a.startswith("--")]
    if len(args) != 1:
        print(__doc__)
        return 2
    try:
        themes = load(args[0])
    except Exception as e:  # noqa: BLE001 -- any unreadable input is a usage error
        print("check-colors: cannot read %s: %s" % (args[0], e), file=sys.stderr)
        return 2
    rows, bad = check(themes)
    table = "--table" in argv
    for th, role, ok, msg in rows:
        if table or not ok:
            print("%-4s %-10s %-9s %s" % ("ok" if ok else "FAIL", th, role, msg))
    print("check-colors: %d checks, %d FAIL (%s)" % (len(rows), bad, ", ".join(THEMES)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
