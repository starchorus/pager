# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# shellcheck disable=SC2016   # the evals are JS in single quotes; a $ in them is JS
# tools/regress.d/scope.sh -- the Scope (D22, docs/architecture.md §9.8b): the phone-mode fan, the Pager at its foot, arcs = received signal (dBm),
# lanes = bands by channel, one arc that contracts per capture, snow when the feed is not live. Sourced by tools/regress.sh with cwd = repo root,
# after the core rows. Only SCP_* globals and scp_* functions are set.
#
# GUARDS AGAINST: a point whose radius is not its signal (to 0.5 px) or that sits outside its band's lane; a lane order that does not follow the channel,
#                 that moves with the order of the input or that moves a station when its signal changes; an angle that is read as a direction
#                 (a caption, a word or an aria text that says so); an arc that runs outward, a new blip that shows before the front has passed it,
#                 a wave that plays under reduced motion; a frame drawn while nothing moves, or no frame while the feed is stale; a stale or an offline
#                 feed that looks live (no snow, a solid rim, no chip word); a strip that counts differently from the capture; a Scope on the wide
#                 desktop, on by default, or lost on a reload; a 44 px button that is not there; chrome that overlaps, runs off the screen or sets text
#                 under 13 px; the sky's controls that lose a state; a Scope that transmits, reads a clock, or draws from a random number; a folded ESS member
#                 that a tap cannot pick, or a count badge drawn for a set the Scope draws apart; a strip that changes its form and leaves the fan's top where it
#                 was; a Scope that grows past its own share while the alerts' share is under its own (the pooled row would not see it); a document or a word of
#                 the page that says how near a network is (near the Pager, the nearest ring).
# NEGATIVE PROBE: one-line copies of the page (served to headless Chrome on 127.0.0.1 only): an outward wave, a frame every tick, a nudged radius, the
#                 bands ignored, no Z, no snow, a direction caption, a POST, the lamps loop over every .lamps, no word fitting, the 3D ring labels, the
#                 phosphor trail on idle frames, a note that never shows, a Bluetooth lane that overflows the fan, ticks that touch, a nudge that turns over
#                 in a narrow lane, a legend row of the wrong kind or one that never shows, a tap that skips a folded ESS member, the count badge drawn in the
#                 Scope, a strip whose change of form leaves the fan where it was: each turns exactly its row red (the unmutated page is the control: the rows
#                 themselves). The static judges have dummies that must be flagged (a forbidden pattern, a size one byte over, a marker that is gone, words of direction
#                 and of distance).
# NOT PROVEN:     iOS WebKit, a real finger, the battery (the numbers are headless software raster: the frame cost row is a ceiling, not a phone's time);
#                 that a newcomer does not read the fan as a field of view (docs/architecture.md §9.8b, the check on the phone); how the Scope looks at
#                 a width the rows do not name; how the trail of the wave looks in WarGames, where the phosphor persistence is on while the arc runs (the Scope draws
#                 the front and two trail strokes in every theme); the Scope's own growth is a measure by markers, not a diff against the old page (a marker that
#                 moves is a red row, a new Scope line that matches no marker is counted as Scope, and a line trimmed since 8e75fe4 outside the Scope counts in its
#                 favour: the series trimmed 104 bytes of the alerts[] ingest note and 34 of the lamps note, so the figure reads about 138 bytes lower than a strict diff would).
# Runs at 390x844 with --mobile unless a row says otherwise. Rows that need the sky settled use ?fixed (the wave is then done: phase 1); the
# wave, the idle and the reduced-motion rows run on the live clock.

SCP_T="out/$P-scp"; mkdir -p "$SCP_T"
SCP_BASE=610563   # wc -c starchorus.html before the Scope and the alerts' ring (feat-0.2 at 8e75fe4: 610,779), lowered by 617 on 24 October 2026 by the owner, on purpose, with BASE_PAGE_BYTES in tools/static.sh: the 14 unread chart tokens left the themes (900 bytes) and the fixes of the same commit cost 239 (the page went from 624,161 to 623,500), and the pooled ceiling (this base + 13,400 = 623,562) leaves 62 bytes where it left 18 (445 under MAX_PAGE_BYTES in tools/static.sh); they are held for two later items, a longer stripCtl (about 60) and a stepped pulse (about 30), which together need about 90 and do not fit as planned; raised by 401 on 26 October 2026 with BASE_PAGE_BYTES for the invisible-characters mark
SCP_Q="?poll=0&spin=0&intro=0&fixed=$STARCHORUS_FIXED&debug=1&scope=1"
SCP_LQ="?poll=0&spin=0&intro=0&debug=1&scope=1"   # the live clock
# --ready: the fonts are loaded, the capture is in and a frame has been painted after both (the layout rows read font metrics and the loaded stations; the --wait of each run stays the ceiling).
# scp_run adds it to every run on a frozen clock (?fixed=), whose state does not depend on how long the page has run; the frame-cost runs keep the whole wait (a page that has only just booted
# is the colder one), and so do the live-clock rows (idle, reduced motion, Bluetooth lane, ESS merge: what fades, ages or settles) and the runs with steps.
SCP_RDY='document.fonts.ready.then(() => new Promise(r => requestAnimationFrame(() => r(!!window.STARCHORUS && STARCHORUS.stats().sourceKind !== "demo"))))'
SCP_FNS="scopeGeom scopePlace scopeStep scopeWantsFrame drawScopeBg scopeWave drawScope applyScope renderScope"

# ---- static: anchors, no token read in the theme-free code, no transmit, clock or random in the Scope's code, the page's size share
# the shares are static.sh's (one source); a drop-in run by hand without it reads them from there
[ -n "${MAX_SCOPE_BYTES:-}" ] || MAX_SCOPE_BYTES=$(sed -n 's/^MAX_SCOPE_BYTES=\([0-9][0-9]*\).*/\1/p' tools/static.sh)
[ -n "${MAX_ALERTS_BYTES:-}" ] || MAX_ALERTS_BYTES=$(sed -n 's/^MAX_ALERTS_BYTES=\([0-9][0-9]*\).*/\1/p' tools/static.sh)
[ -n "${MAX_SCOPE_BT_BYTES:-}" ] || MAX_SCOPE_BT_BYTES=$(sed -n 's/^MAX_SCOPE_BT_BYTES=\([0-9][0-9]*\).*/\1/p' tools/static.sh)
scp_n() { sec_grepc "$1" "$2" "$3" "$4" || echo NOSLICE; }
SCP_A="$(scp_n 20 21 90 '^const SCOPE = ')/$(scp_n 20 21 90 'key: "Z",.*btn: "t-scope"')/$(scp_n 21 22 300 'scope: { strip: \[')/$(scp_n 21 22 300 'k = scopeOn ? 13 : 0')"
SCP_A="$SCP_A/$(scp_n 24 25 50 '^const SC = ')/$(scp_n 26 27 400 '^function scopeGeom(')/$(scp_n 26 27 400 '^function scopePlace(')/$(scp_n 30 31 200 '^function scopeStep(')"
SCP_A="$SCP_A/$(scp_n 30 31 200 '^function scopeWantsFrame(')/$(scp_n 34 35 450 '^function drawScopeBg(')/$(scp_n 34 35 450 '^function drawScope(')/$(scp_n 37 38 1000 '^function applyScope(')/$(scp_n 37 38 1000 '^function renderScope(')"
rowif "scope: anchors SCOPE, key Z, copy.scope x3, 13 px font, SC, scopeGeom/scopePlace (26), scopeStep/scopeWantsFrame (30), drawScopeBg/drawScope (34), applyScope/renderScope (37) [$SCP_A]" [ "$SCP_A" = 1/1/3/1/1/1/1/1/1/1/1/1/1 ]
# a function body = from its line to the closing brace at the line start; the one-line consts are matched by name
SCP_CODE="$SCP_T/code.txt"; : > "$SCP_CODE"
# shellcheck disable=SC2086   # a word list on purpose
for SCP_F in $SCP_FNS; do awk -v FN="$SCP_F" '$0 ~ ("^function " FN "\\(") , /^}/' "$H" >> "$SCP_CODE"; done
for SCP_C in thv scXY scL scR scU wavePhase; do grep "^const $SCP_C = " "$H" >> "$SCP_CODE"; done
SCP_CN=$(wc -l < "$SCP_CODE" | tr -d ' ')
# theme-free: the geometry, the placement, the tick and the frame rule read no token (the drawing functions may)
SCP_TF=0
for SCP_F in scopeGeom scopePlace scopeStep scopeWantsFrame; do SCP_X=$(awk -v FN="$SCP_F" '$0 ~ ("^function " FN "\\(") , /^}/' "$H" | grep -cE 'THEME|[^A-Za-z]TD\.|[^A-Za-z]TK[^A-Za-z]'); SCP_TF=$((SCP_TF + SCP_X)); done
SCP_TF=$((SCP_TF + $(grep -E '^const (thv|scXY|scR|scU) = ' "$H" | grep -cE 'THEME|[^A-Za-z]TD\.|[^A-Za-z]TK[^A-Za-z]')))
rowif "scope: the geometry, the placement, the tick and the frame rule read no theme token (scopeGeom, scopePlace, scopeStep, scopeWantsFrame, thv, scXY, scR, scU: $SCP_TF reads)" [ "$SCP_TF" = 0 ]
SCP_BAD='Math\.random|Date\.now|performance\.now|new Date|createRadialGradient|shadowBlur|AudioContext|new Audio|vibrate\(|fetch\(|XMLHttpRequest|sendBeacon|WebSocket|EventSource|new Image|navigator\.|localStorage|sessionStorage|setInterval|\.send\('
SCP_H=$(grep -cE "$SCP_BAD" "$SCP_CODE")
# the judge can say no: a dummy with each of three offences must be flagged by the same pattern
printf '%s\n' 'x = Math.random();' 'fetch("/x", { method: "POST" });' 'navigator.vibrate(5);' > "$SCP_T/dummy.txt"
SCP_HD=$(grep -cE "$SCP_BAD" "$SCP_T/dummy.txt")
rowif "scope: the Scope's code ($SCP_CN lines) has no request, clock, random number, sound, vibration or storage of its own ($SCP_H hits); the pattern flags a dummy ($SCP_HD/3)" [ "$SCP_CN" -ge 100 ] 2>/dev/null && [ "$SCP_H/$SCP_HD" = 0/3 ]
[ "$SCP_H" = 0 ] || grep -nE "$SCP_BAD" "$SCP_CODE" | cut -c1-160 | sed 's/^/    /'
SCP_SZ=$(wc -c < "$H" | tr -d ' ')
SCP_CEIL=$((MAX_SCOPE_BYTES + MAX_ALERTS_BYTES + MAX_SCOPE_BT_BYTES))   # the alerts' ring and the Scope's fifth lane (the pair's: radio-pair spec 3.6, counted in its 14,000) are the other two shares on this page after 8e75fe4
scp_share_ok() { [ "$1" -le $((SCP_BASE + SCP_CEIL)) ] 2>/dev/null; }
SCP_JB=0; scp_share_ok $((SCP_BASE + SCP_CEIL)) || SCP_JB=1; scp_share_ok $((SCP_BASE + SCP_CEIL + 1)) && SCP_JB=1; scp_share_ok x && SCP_JB=1
rowif "scope: the page grew by $((SCP_SZ - SCP_BASE)) bytes since 8e75fe4 (the Scope's share $MAX_SCOPE_BYTES, with the alerts' ring $MAX_ALERTS_BYTES and the fifth lane $MAX_SCOPE_BT_BYTES: $SCP_CEIL); the judge refuses one byte more or a size that is no number (bad: $SCP_JB)" [ "$SCP_JB" = 0 ] 2>/dev/null
scp_share_ok "$SCP_SZ" || { row "scope: the page is over the Scope's, the alerts' and the fifth lane's shares together ($SCP_SZ bytes)" FAIL; }

# the Scope's own growth. The pooled row above lets the three shares borrow from one another (the alerts could shrink and the Scope take the room); this one pins the Scope with its
# fifth lane to its own 12,000 + 200 by subtracting what the alerts' ring and legend measure, found by their markers in the page: the eleven segments below, each of which must be in
# the page exactly as often as listed (a marker that moved or went is "BROKEN", not a smaller number). The measure reproduces the alerts' share as it was at the commit that
# put the ring in (1,184 bytes with the frame step it then had in wargamesAnimating, 76 bytes) and as it is now (1,268 with the step in the tick).
cat > "$SCP_T/alm.py" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
SEGS = [
    ("tokens", r'alert: "#[0-9a-f]{6}", ', 3),
    ("css", r'\["--status-alert", "status\.alert", ""\], ', 1),
    ("contrast", r'  \["status\.alert", "surface\.base", 3, "canvas: alert ring"\],\n', 1),
    ("node", r'const alertNode = .*\n', 1),
    ("var", r'let alAt = Infinity;\n', 1),
    ("reset", r'  alAt = Infinity;\n', 1),
    ("cue", r'  const cm = THEME\.render\.changeCue, e2 = S\.clock \* 2 \| 0;\n', 1),
    ("ring", r'  for \(const a of S\.alerts\) \{ const n = alertNode\(a\);.*\n', 1),
    ("legend", r"  rows\.push\('<div class=\"legrow note\" id=\"leg-alert\".*\n", 1),
    ("vis", r'vis\("leg-alert", S\.alerts\.some\(alertNode\)\); ', 1),
    ("step", r'  \} else if \(S\.fixedTime == null && !S\.ui\.paused && S\.clock >= alAt\) \{.*\n', 1),
]
tot = 0
for name, rx, want in SEGS:
    m = [len(x.group(0).encode("utf-8")) for x in re.finditer(rx, s)]
    if len(m) != want:
        print("BROKEN:" + name); sys.exit(0)
    tot += sum(m)
print(tot)
PY
scp_alm() { python3 -B "$SCP_T/alm.py" "$1" 2>&1 | head -n 1; }   # scp_alm PAGE -> the bytes of the alerts' segments, or BROKEN:name
scp_own_ok() { [ "$1" -le $((MAX_SCOPE_BYTES + MAX_SCOPE_BT_BYTES)) ] 2>/dev/null; }   # the Scope's own ceiling: its share and the fifth lane's allowance
SCP_AL=$(scp_alm "$H")
case $SCP_AL in ''|*[!0-9]*) SCP_OWN=$SCP_AL ;; *) SCP_OWN=$((SCP_SZ - SCP_BASE - SCP_AL)) ;; esac
# the judge can say no: the ceiling itself passes, one byte more and a text do not; a page without one marker is BROKEN (a dummy: the legend row deleted)
SCP_OJ=0; scp_own_ok $((MAX_SCOPE_BYTES + MAX_SCOPE_BT_BYTES)) || SCP_OJ=1; scp_own_ok $((MAX_SCOPE_BYTES + MAX_SCOPE_BT_BYTES + 1)) && SCP_OJ=1; scp_own_ok BROKEN:ring && SCP_OJ=1
grep -v 'id="leg-alert"' "$H" > "$SCP_T/alm-dummy.html"
SCP_OD=$(scp_alm "$SCP_T/alm-dummy.html")
SCP_OK=0; [ "$SCP_OJ" = 0 ] && [ "$SCP_OD" = BROKEN:legend ] && scp_own_ok "$SCP_OWN" && SCP_OK=1
rowif "scope: the Scope's own growth is $SCP_OWN bytes (the page's $((SCP_SZ - SCP_BASE)) since 8e75fe4 less $SCP_AL for the alerts' ring and legend by their markers), at most $((MAX_SCOPE_BYTES + MAX_SCOPE_BT_BYTES)) (the Scope's $MAX_SCOPE_BYTES and the fifth lane's $MAX_SCOPE_BT_BYTES); the judge refuses one byte more (bad: $SCP_OJ) and a page without a marker is $SCP_OD" [ "$SCP_OK" = 1 ]

# the film names of the spec's rule 8 stay on the word denylist (the list is only ever added to; denylist-check --selftest pins its older entries)
SCP_DW=$(grep -c -x -e nostromo -e weyland -e m314 tools/denylist-words.txt)
rowif "scope: tools/denylist-words.txt carries nostromo, weyland and m314 ($SCP_DW of 3)" [ "$SCP_DW" = 3 ]

# ---- the judge (Python, one place): each check takes the JSON a run returned and says "ok" or what is wrong
cat > "$SCP_T/judge.py" <<'PY'
import json, re, sys
TH = ("foundation", "wargames", "whitehall")
def ok(bad): print("ok" if not bad else "; ".join(bad))
def geom(v, n):
    d = json.loads(v); bad = []
    for t in TH:
        m = re.match(r"^ok (\d+)$", str(d.get(t, "")))
        if not m or int(m.group(1)) < int(n): bad.append("%s: %s" % (t, d.get(t)))
    if d.get("errors") != 0: bad.append("errors %s" % d.get("errors"))
    return bad
def toggle(v):
    d = json.loads(v); want = {"def": "off,false,false,none,none,flex,block|sheet-row|44x44|true", "click": "on,true,true,grid,grid,none,none|true|true", "zoff": "off,false,false,none,none,flex,block",
          "zon": "on,true,true,grid,grid,none,none", "saved": True, "help": True, "errors": 0}
    return ["%s: %s" % (k, d.get(k)) for k in want if d.get(k) != want[k]]
def desk(v, w):
    d = json.loads(v); return [] if (d.get("boot"), d.get("z"), d.get("errors")) == tuple(w.split("|")[:2]) + (0,) else ["got %s / %s" % (d.get("boot"), d.get("z"))]
def persist(v):   # the five values of the reload run, in order
    r = json.loads(v); want = [["on", True], ["on", True, True], ["off", False, True], ["on", True, True]]
    got = [json.loads(x) for x in r if x != "r"]
    return [] if got == want else ["got %s" % got]
def angle(v):
    d = json.loads(v); want = {"order": [True, True, True], "lanes": "2.4/5/6/6/true/sta,sta,sta,sta", "reversed": True, "rssi": [True, True], "chan": [True, True], "errors": 0}
    return ["%s: %s" % (k, d.get(k)) for k in want if d.get(k) != want[k]]
def strip(v, fx, clouds):
    d = json.loads(v); f = json.load(open(fx)); bad = []
    macs = {c["mac"] for a in f["aps"] for c in a.get("clients", [])} | {c["mac"] for c in f.get("unassociated", [])}
    rs = [a["rssi"] for a in f["aps"] if a.get("rssi") is not None]
    want = [str(len(f["aps"])), str(len(macs)), str(int(clouds)), ("%d dBm" % max(rs)) if rs else "—", "0"]
    for t in TH:
        x = d[t]
        if x["n"] != want: bad.append("%s numbers %s want %s" % (t, x["n"], want))
        if x["w"] != x["want"] or len(x["w"]) != 5: bad.append("%s words %s" % (t, x["w"]))
        if x["cl"] != int(clouds): bad.append("%s stats clouds %s" % (t, x["cl"]))
    if [x["lamps"][0] for x in (d["foundation"], d["wargames"], d["whitehall"])][1] is not False or d["wargames"]["lamps"][1] != 8: bad.append("lamps %s" % [d[t]["lamps"] for t in TH])
    if d.get("errors") != 0: bad.append("errors")
    return bad
def live(v):
    d = json.loads(v); bad = []
    if d["live"] != "live|RX only · nothing is transmitted|Live": bad.append("live " + d["live"])
    if d["stale"] != "stale|RX only · nothing is transmitted · Stale|Stale": bad.append("stale " + d["stale"])
    if d["offline"] != "offline|RX only · nothing is transmitted · Link down|Link down": bad.append("offline " + d["offline"])   # WarGames' word for the chip
    if not (d["snow"][0] and d["snow"][1]): bad.append("snow %s" % d["snow"])
    if not (d["dash"][0] == 0 and d["dash"][1] >= 20 and d["dash"][2] >= 20): bad.append("rim dashes %s" % d["dash"])
    if d["alarm"] != 0: bad.append("alarm pixels %s" % d["alarm"])
    if d["errors"] != 0: bad.append("errors")
    return bad
def wave(v):
    d = json.loads(v); bad = []
    if not d["q"] >= 0.75: bad.append("q %s" % d["q"])
    if d["nw"] != [True, False]: bad.append("nw %s" % d["nw"])
    if d["p03"] != [0, 0.85, True] or d["p06"] != [0, 0.85, True]: bad.append("before the front: %s %s" % (d["p03"], d["p06"]))
    if d["p09"] != [0.85, 0.85, True]: bad.append("after the front: %s" % d["p09"])
    if d["arcGone"] is not True: bad.append("the arc does not contract")
    if d["errors"] != 0: bad.append("errors")
    return bad
def idle(v):
    d = json.loads(v); bad = []
    if d["idle"] != 0 or d["idle2"] != 0: bad.append("frames at rest %s / %s" % (d["idle"], d["idle2"]))
    if d["stale"][0] != "stale" or not 3 <= d["stale"][1] <= 6: bad.append("stale frames %s" % d["stale"])
    if d["wave"] is not True: bad.append("no wave")
    if d["errors"] != 0: bad.append("errors")
    return bad
def rm(v):
    d = json.loads(v)
    want = {"rm": "1", "newBlip": [True, 0.85, False, False], "snow": ["stale", True, True], "still": True, "errors": 0}
    return ["%s: %s" % (k, d.get(k)) for k in want if d.get(k) != want[k]]
def panels(v):
    d = json.loads(v)
    want = {"hidden": "off,hidden,hidden,grid,visible,grid,flex,on", "fit": [True, True, True, True], "blips": True, "back": "on,visible,visible,on", "errors": 0}
    return ["%s: %s" % (k, d.get(k)) for k in want if d.get(k) != want[k]]
def select(v):
    r = json.loads(v); a, b = json.loads(r[0]), json.loads(r[1])
    return [] if (a[0], a[1], b[0], b[3]) == ("detail", "peek", "controls", None) and a[2] and a[3] else ["got %s / %s" % (a, b)]
def rand(v):
    d = json.loads(v); want = {"cloud": ["cloud", "6/41/1/162/6,162,1"], "show": ["show", "6/162/0/162/6,162,0"], "hide": ["hide", "6/23/0/23/6,23,0"], "back": ["cloud", "6/41/1/162/6,162,1"], "errors": 0}
    return ["%s: %s" % (k, d.get(k)) for k in want if d.get(k) != want[k]]
def legend(v):
    d = json.loads(v); want = {"legendScope": [False] * 6, "legendSky": [True] * 6, "view": ["3d", True], "card": ["detail", "half", True], "errors": [],
            "rowOn": [True, "lanes = band, channel · arcs = signal (dBm) · not direction, not range"], "rowOff": [False]}
    return ["%s: %s" % (k, d.get(k)) for k in want if d.get(k) != want[k]]
def direction(v):
    t = json.loads(v)
    for a in ("not direction", "never a direction", "not range", "arcs = signal (dBm)"): t = t.replace(a, "")
    h = re.findall(r"(?i)\b(direction|bearing|heading|compass|north|south|east|west|ahead|behind|degrees?|metres?|meters?|feet|miles?|km|distance|range|nearby|closer|farther|(?:near|close to|next to) (?:the )?pager|(?:nearest|closest) (?:ring|arc))\b|°", t)
    return ["claims: %s" % h] if h else []
def fit(v):   # the strip at a narrow size: every theme says ok (cells inside the panel and the screen, 13 px words, a unit that keeps its case)
    d = json.loads(v); bad = ["%s: %s" % (t, d.get(t)) for t in TH if not str(d.get(t, "")).startswith("ok")]
    return bad + (["errors %s" % d.get("errors")] if d.get("errors") != 0 else [])
def lamps(v):
    d = json.loads(v); bad = []
    if not (isinstance(d.get("n"), list) and len(d["n"]) == 4 and d["n"][0] >= 10 and d["n"] == [d.get("want")] * 4): bad.append("lamps per AP %s, the strip has %s" % (d.get("n"), d.get("want")))
    if d.get("label") != [None, None, None, None]: bad.append("the strip took a counter's label %s" % d.get("label"))
    if d.get("bar") != [8, True]: bad.append("the bar's counter %s" % d.get("bar"))
    if d.get("errors") != 0: bad.append("errors %s" % d.get("errors"))
    return bad
def note(v):   # 568x320: Whitehall has no room for the fan and says so; the other themes have it; back in Whitehall the note comes again
    d = json.loads(v)
    want = {"whitehall": "none|note|true|true", "foundation": "fan|-|true|true", "wargames": "fan|-|true|true", "whitehall2": "none|note|true|true",
            "text": "Too little room for the scope: turn the phone upright", "errors": 0}
    return ["%s: %s" % (k, d.get(k)) for k in want if d.get(k) != want[k]]
def btlane(v):
    d = json.loads(v); bad = []
    base = "2.4:-1.0000/-0.5628 5:-0.5228/0.0456 6:0.0856/0.3479 sta:0.3879/1.0000"
    on = d["on"].split()
    if [x.split(":")[0] for x in on] != ["2.4", "5", "6", "sta", "bt"] or not on[0].startswith("2.4:-1.0000/") or not on[-1].endswith("/1.0000"): bad.append("with marks: %s" % d["on"])
    if d["off"] != base: bad.append("filter off (the four lanes of the old widths): %s" % d["off"])
    if d["back"] != d["on"]: bad.append("filter on again: %s" % d["back"])
    if not (d["n"][0] == d["n"][1] and d["n"][0] >= 5): bad.append("marks placed %s" % d["n"])
    if d["marks"] != "ok": bad.append(d["marks"])
    if d["hit"] is not True or d["leg"] is not True: bad.append("hit %s legend %s" % (d["hit"], d["leg"]))
    return bad + (["errors"] if d.get("errors") != 0 else [])
def ticks(v):
    d = json.loads(v); bad = []
    for t in TH:
        x = d.get(t)
        if not x: bad.append(t + ": none"); continue
        if x["touch"]: bad.append("%s: ticks touch %s" % (t, x["touch"]))
        if x["n"] < 3: bad.append("%s: only %s ticks" % (t, x["n"]))
        if x["bgMin"] < 13 or x["hudMin"] < 13: bad.append("%s: canvas text of %s / %s px" % (t, x["bgMin"], x["hudMin"]))
    return bad + (["errors"] if d.get("errors") != 0 else [])
def nudge(v):
    d = json.loads(v); want = {"out": "none", "n": 4, "errors": 0}
    return ["%s: %s" % (k, d.get(k)) for k in want if d.get(k) != want[k]]
def ring3d(v):
    d = json.loads(v); want = {"blend": ["3d", 1], "labels": "foundation:0:0:0 wargames:0:0:0 whitehall:0:0:0", "errors": 0}
    return ["%s: %s" % (k, d.get(k)) for k in want if d.get(k) != want[k]]
def perf(v, n, ms):
    d = json.loads(v); bad = []
    if d[0] != int(n): bad.append("blips %s want %s" % (d[0], n))
    if d[1] > float(ms): bad.append("mean %s ms over %s" % (d[1], ms))
    if d[3] != 0: bad.append("errors")
    return bad
def ess(v):   # devices.json with ESS merge on: 3 folded members in 2 merged sets; in the Scope every one can be tapped and no count badge is drawn, in the sky none can and both badges are
    d = json.loads(v); want = {"folded": 3, "merged": 2, "scope": [3, 0], "sky": [0, 2], "errors": 0}
    return ["%s: %s" % (k, d.get(k)) for k in want if d.get(k) != want[k]]
def stripgeom(v):   # an ingest that flips the strip's classes (t, n) moves the fan's top with it: the geometry follows the strip's height
    d = json.loads(v); bad = []
    for t in TH:
        x = d.get(t)
        if not x or len(x) != 3: bad.append(t + ": none"); continue
        if len({r.split("|")[1] for r in x}) < 2: bad.append("%s: the strip never changed height %s" % (t, x))
        for r in x:
            c, h, top, want = r.split("|")
            if abs(float(top) - float(want)) > 0.5: bad.append("%s: fan top %s, strip says %s (%s)" % (t, top, want, c))
    return bad + (["errors"] if d.get("errors") != 0 else [])
ok(globals()[sys.argv[1]](*sys.argv[2:]))
PY
scp_j() { python3 -B "$SCP_T/judge.py" "$@" 2>&1 | head -n 1; }   # scp_j CHECK ARGS...: ok, or what is wrong
scp_ev() { evalv "$1" 1; }
# scp_run NAME 'EVAL' FIXTURE QUERY WIDTH HEIGHT [more cdp args]: one run of the page (the page served is $H) -> out/$P-scp-NAME.json
scp_run() { _sr_n=$1; _sr_e=$2; _sr_f=$3; _sr_q=$4; _sr_w=$5; _sr_h=$6; shift 6
  case $_sr_q in *fixed=*) case $_sr_n in bench*) ;; *) set -- "$@" --ready "$SCP_RDY" ;; esac ;; esac
  runq "$_sr_f" "$_sr_q" "$SCP_T-$_sr_n" --width "$_sr_w" --height "$_sr_h" --mobile --wait 2 --fps 0 --eval-timeout 90 --eval "$_sr_e" "$@" >/dev/null 2>&1; }
scp_row() {   # scp_row LABEL RESULT: PASS iff the judge said "ok"
  if [ "$2" = ok ]; then row "$1" PASS; else row "$1" FAIL; echo "    $2" | cut -c1-400; fi
}
# the evals, one per topic (JS: the page's _internals S and SC, the DOM, the debug API; no assertion in them, the judge above decides)
SCP_EVG='(async()=>{const I=STARCHORUS._internals,S=I.S,SC=I.SC,E=i=>document.getElementById(i),R=e=>e.getBoundingClientRect(),o={};
const vis=e=>!!e&&e.getClientRects().length>0&&getComputedStyle(e).display!=="none"&&getComputedStyle(e).visibility!=="hidden"&&R(e).width>0;
const ovl=()=>{const L=["bar","sheet","classbar-top","classbar-bot","dtg","panels-pill","scope-strip","scope-foot"].map(E).filter(vis),r=[];for(let i=0;i<L.length;i++)for(let j=i+1;j<L.length;j++){const a=R(L[i]),b=R(L[j]),w=Math.min(a.right,b.right)-Math.max(a.left,b.left),h=Math.min(a.bottom,b.bottom)-Math.max(a.top,b.top);if(w>0.5&&h>0.5)r.push(L[i].id+"/"+L[j].id)}return r};
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await STARCHORUS.wait(700);const g=SC.g,bad=[];
 if(!g||document.documentElement.dataset.scope!=="on"){o[t]="no scope";continue}
 const b=g.b,sl=R(E("sc-ps"));let n=0;
 if(!(g.ox-g.half>=b.x-0.5&&g.ox+g.half<=b.x+b.w+0.5&&g.oy-g.rFar>=g.top+I.SCOPE.rim-0.5&&Math.abs(g.py-(sl.top+sl.height/2))<0.5))bad.push("fan");
 for(const M of [S.aps,S.clients,S.clouds])for(const nd of M.values()){const s=nd.sc;if(!s||s.st!==SC.st)continue;n++;
  const rssi=nd.rssi==null?-85:nd.rssi,want=g.rNear+(1-Math.min(1,Math.max(0,(rssi+90)/60)))*(g.rFar-g.rNear),rr=Math.hypot(s.x-g.ox,s.y-g.oy);
  if(Math.abs(rr-want)>0.5)bad.push("r:"+nd.id);
  const th=rr*Math.sin(g.th)<=g.half?g.th:Math.asin(g.half/rr),a=Math.atan2(s.x-g.ox,g.oy-s.y)/th,lane=g.lanes.find(l=>a>=l.k0-0.5*Math.PI/180/th&&a<=l.k1+0.5*Math.PI/180/th);
  const wl=nd.kind==="ap"?({"2.4":1,"5":1,"6":1}[nd.band]?nd.band:"6"):"sta";
  if(!lane||lane.key!==wl)bad.push("lane:"+nd.id);
  if(s.x<b.x||s.x>b.x+b.w||s.y<g.top||s.y>g.py)bad.push("out:"+nd.id)}
 const ov=ovl();if(ov.length)bad.push("overlap "+ov);
 if(document.documentElement.scrollWidth!==innerWidth)bad.push("wide");
 const tc=I.THEMES[t].copy,k=E("scope-foot").children;
 if(k[0].textContent!=="lanes = band, channel\nnot direction"||k[2].textContent!=="arcs = signal (dBm)\nnot range"||E("sc-rx").textContent!==tc.rx.legRx)bad.push("captions");
 const fs=[...E("scope-strip").querySelectorAll("i"),E("scope-foot"),E("sc-rx")].map(e=>parseFloat(getComputedStyle(e).fontSize));if(Math.min(...fs)<13)bad.push("font "+Math.min(...fs));
 o[t]=bad.join(";")||"ok "+n}
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
SCP_EVT='(async()=>{const I=STARCHORUS._internals,S=I.S,E=i=>document.getElementById(i),DE=document.documentElement,W=STARCHORUS.wait,o={};
const R=e=>{const r=e.getBoundingClientRect();return Math.round(r.width)+"x"+Math.round(r.height)},cs=(e,p)=>getComputedStyle(e)[p];
const key=k=>document.body.dispatchEvent(new KeyboardEvent("keydown",{key:k,bubbles:true}));
const st=()=>[DE.dataset.scope,S.ui.scope,E("t-scope").getAttribute("aria-pressed"),cs(E("scope-strip"),"display"),cs(E("scope-foot"),"display"),cs(E("bar-counts").firstElementChild,"display"),cs(E("t-view"),"display")].join();
o.def=[st(),E("t-scope").parentNode.id,R(E("t-scope")),STARCHORUS.phone().on].join("|");
E("t-scope").dispatchEvent(new MouseEvent("click",{bubbles:true}));await W(400);
o.click=[st(),STARCHORUS.getToggles().scope,E("t-scope").classList.contains("on")].join("|");
key("z");await W(300);o.zoff=st();
key("z");await W(300);o.zon=st();
await W(400);o.saved=(STARCHORUS.storageDump()||{}).scope;
o.help=/Scope \(phone layout\)/.test(E("help-list").textContent)&&E("t-scope").title.indexOf("[Z]")>0;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
SCP_EVD='(async()=>{const I=STARCHORUS._internals,S=I.S,E=i=>document.getElementById(i),DE=document.documentElement,W=STARCHORUS.wait,o={};
const cs=(e,p)=>getComputedStyle(e)[p];
const key=k=>document.body.dispatchEvent(new KeyboardEvent("keydown",{key:k,bubbles:true}));
const st=()=>[DE.dataset.phone,DE.dataset.scope,S.ui.scope,cs(E("t-scope"),"display"),cs(E("scope-strip"),"display"),cs(E("scope-foot"),"display")].join();
await W(300);o.boot=st();key("z");await W(300);o.z=st();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
SCP_EVP='(async()=>{const E=i=>document.getElementById(i);E("t-scope").dispatchEvent(new MouseEvent("click",{bubbles:true}));await STARCHORUS.wait(300);return JSON.stringify([document.documentElement.dataset.scope,STARCHORUS.storageDump().scope])})()'
SCP_RD='JSON.stringify([document.documentElement.dataset.scope,STARCHORUS.getToggles().scope,(STARCHORUS.storageDump()||{}).scope])'
SCP_EVA='(async()=>{const I=STARCHORUS._internals,S=I.S,SC=I.SC,W=STARCHORUS.wait,o={};
const mk=(g,aps,sta)=>({source:"recon-db",generated:g,center:{label:"T",interval:30},aps,unassociated:sta});
const ap=(n,band,ch,rssi,extra)=>Object.assign({bssid:"02:00:00:00:00:"+("0"+n.toString(16)).slice(-2),ssid:"N"+n,rssi},band?{band,channel:ch}:{},extra||{});
const aps=[ap(1,"2.4",1,-50),ap(2,"2.4",6,-56),ap(3,"2.4",11,-62),ap(4,"5",36,-52),ap(5,"5",100,-58),ap(6,"5",149,-64),ap(7,"6",5,-66),ap(8,"6",101,-70),ap(9,null,null,-74)];
const sta=[{mac:"02:aa:00:00:00:01",rssi:-60},{mac:"02:aa:00:00:00:02",rssi:-61},{mac:"02:aa:00:00:00:03",rssi:-62},{mac:"02:aa:00:00:00:04",rssi:-90}];
const snap=()=>{const m={};for(const M of [S.aps,S.clients,S.clouds])for(const n of M.values())if(n.sc&&n.sc.st===SC.st)m[n.id]=n.sc;return m};
const lane=k=>SC.g.lanes.find(l=>k>=l.k0&&k<=l.k1).key;
STARCHORUS.load(mk(1000,aps,sta),"a");await W(300);const A=snap();
const k=id=>A["02:00:00:00:00:"+id].k;
o.order=[k("01")<k("02")&&k("02")<k("03"),k("04")<k("05")&&k("05")<k("06"),k("07")<k("08")];
o.lanes=[lane(k("01")),lane(k("04")),lane(k("07")),lane(k("09")),SC.unk,Object.keys(A).filter(i=>i.startsWith("02:aa")).map(i=>lane(A[i].k)).join()].join("/");
STARCHORUS.load(mk(1030,aps.slice().reverse(),sta.slice().reverse()),"a");await W(300);const B=snap();
o.reversed=JSON.stringify(Object.keys(A).sort().map(i=>[i,A[i].x.toFixed(3),A[i].y.toFixed(3)]))===JSON.stringify(Object.keys(B).sort().map(i=>[i,B[i].x.toFixed(3),B[i].y.toFixed(3)]));
const sta2=sta.map(s=>Object.assign({},s,{rssi:s.rssi===-60?-75:s.rssi}));
STARCHORUS.load(mk(1060,aps,sta2),"a");await W(300);const C=snap();
o.rssi=[C["02:aa:00:00:00:01"].k===A["02:aa:00:00:00:01"].k,C["02:aa:00:00:00:01"].r>A["02:aa:00:00:00:01"].r];
const aps3=aps.map(a=>a.ssid==="N2"?Object.assign({},a,{channel:11}):a);
STARCHORUS.load(mk(1090,aps3,sta),"a");await W(300);const D=snap();
o.chan=[D["02:00:00:00:00:02"].k>A["02:00:00:00:00:02"].k,lane(D["02:00:00:00:00:02"].k)==="2.4"];
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
SCP_EVS='(async()=>{const I=STARCHORUS._internals,W=STARCHORUS.wait,E=i=>document.getElementById(i),o={};
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await W(500);const k=[...E("scope-strip").children];
 o[t]={n:k.filter((e,i)=>i%2===0).map(e=>e.textContent),w:k.filter((e,i)=>i%2===1).map(e=>e.textContent),want:I.THEMES[t].copy.scope.strip,cl:STARCHORUS.stats().clouds,lamps:[E("scope-lamps").hidden,E("scope-lamps").children.length]}}
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
SCP_EVL='(async()=>{const I=STARCHORUS._internals,S=I.S,SC=I.SC,W=STARCHORUS.wait,E=i=>document.getElementById(i),o={};
const doc={source:"recon-db",generated:1789299990,center:{label:"T",interval:30},aps:[{bssid:"02:00:00:00:00:01",ssid:"Net-A",band:"2.4",channel:6,rssi:-45,security:"WPA2"},{bssid:"02:00:00:00:00:02",ssid:"Net-B",band:"5",channel:44,rssi:-58,security:"WPA2"},{bssid:"02:00:00:00:00:03",ssid:"Net-C",band:"2.4",channel:11,rssi:-64,security:"WPA2"}],unassociated:[{mac:"02:aa:00:00:00:01",rssi:-60}]};
const sky=()=>{const c=E("sky"),d=c.getContext("2d").getImageData(0,0,c.width,c.height).data;let n=0;for(let i=3;i<d.length;i+=4)if(d[i])n++;return n};
const alarmPx=(t)=>{const al=I.THEMES[t].status.alarm,m=/^#(..)(..)(..)$/.exec(al);if(!m)return -1;const w=[1,2,3].map(i=>parseInt(m[i],16)),c=E("bg"),d=c.getContext("2d").getImageData(0,0,c.width,c.height).data;let n=0;for(let i=0;i<d.length;i+=4)if(d[i+3]>200&&Math.abs(d[i]-w[0])<3&&Math.abs(d[i+1]-w[1])<3&&Math.abs(d[i+2]-w[2])<3)n++;return n};
const dash=()=>{const g=SC.g,x=g.ox-g.half;let z=0;for(let y=Math.ceil(g.oy-g.rFar+40);y<g.oy-g.rFar+140;y++){let m=0;for(let dx=-1;dx<=1;dx++)m=Math.max(m,STARCHORUS.pixel("bg",x+dx,y).a);if(m===0)z++}return z};
const st=()=>[SC.lv,E("sc-rx").textContent,E("mode-chip").textContent].join("|");
STARCHORUS.load(doc,"stand-in",{mode:"live"});await W(500);STARCHORUS.frame();o.live=st();const n0=sky(),d0=dash();
S.staleMs=1e9;STARCHORUS.load(doc,"stand-in",{mode:"live"});await W(500);STARCHORUS.frame();o.stale=st();const n1=sky(),d1=dash();
S.lostPolls=5;STARCHORUS.load(doc,"stand-in",{mode:"live"});await W(500);STARCHORUS.frame();o.offline=st();const n2=sky(),d2=dash();
o.snow=[n1-n0>=60,n2-n1>=150,n1-n0,n2-n1];o.dash=[d0,d1,d2];
o.alarm=alarmPx(STARCHORUS.getTheme());
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
SCP_EVW='(async()=>{const I=STARCHORUS._internals,S=I.S,SC=I.SC,W=STARCHORUS.wait,o={};
const mk=(g,aps)=>({source:"recon-db",generated:g,center:{label:"T",interval:30},aps,unassociated:[]});
const ap=(n,ch,rssi)=>({bssid:"02:00:00:00:00:0"+n,ssid:"N"+n,band:"2.4",channel:ch,rssi,security:"WPA2"});
STARCHORUS.load(mk(1000,[ap(1,1,-62),ap(2,11,-70)]),"w");await W(300);
STARCHORUS.load(mk(1030,[ap(1,1,-62),ap(2,11,-70),ap(3,6,-42)]),"w");await W(300);
const g=SC.g,span=g.rFar-g.rNear,n3=S.aps.get("02:00:00:00:00:03"),n1=S.aps.get("02:00:00:00:00:01"),q=n3.sc.q;
const arc=p=>{const y=g.oy-(g.rFar-span*p);let m=0;for(let dx=-3;dx<=3;dx++)for(let dy=-1;dy<=1;dy++)m=Math.max(m,STARCHORUS.pixel("sky",g.ox+dx,y+dy).a);return m>0};
const at=p=>{SC.ph=p;S.dirty=true;STARCHORUS.frame();return [+n3.alphaDraw.toFixed(2),+n1.alphaDraw.toFixed(2),arc(p)]};
o.q=+q.toFixed(2);o.nw=[n3.sc.nw,n1.sc.nw];
o.p03=at(0.3);o.p06=at(0.6);o.p09=at(0.9);
SC.ph=0.6;S.dirty=true;STARCHORUS.frame();o.arcGone=!arc(0.3)&&arc(0.6);
SC.ph=null;o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
SCP_EVI='(async()=>{const I=STARCHORUS._internals,S=I.S,SC=I.SC,W=STARCHORUS.wait,o={};
await W(500);o.idle=(await STARCHORUS.measure(2)).renderedFrames;
const doc={source:"recon-db",generated:1789299990,center:{label:"T",interval:30},aps:[{bssid:"02:00:00:00:00:01",ssid:"Net-A",band:"2.4",channel:6,rssi:-45,security:"WPA2"}],unassociated:[]};
STARCHORUS.load(doc,"s",{mode:"live"});await W(300);
S.staleMs=1e9;STARCHORUS.load(doc,"s",{mode:"live"});await W(300);
o.stale=[SC.lv,(await STARCHORUS.measure(2)).renderedFrames];
doc.generated+=30;S.staleMs=0;S.lostPolls=0;STARCHORUS.load(doc,"s",{mode:"live"});
o.wave=(await STARCHORUS.measure(1)).renderedFrames>=30;
await W(3500);o.idle2=(await STARCHORUS.measure(2)).renderedFrames;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
SCP_EVR='(async()=>{const I=STARCHORUS._internals,S=I.S,SC=I.SC,W=STARCHORUS.wait,o={};
const mk=(g,aps)=>({source:"recon-db",generated:g,center:{label:"T",interval:30},aps,unassociated:[]});
const ap=(n,ch,rssi)=>({bssid:"02:00:00:00:00:0"+n,ssid:"N"+n,band:"2.4",channel:ch,rssi,security:"WPA2"});
STARCHORUS.load(mk(1000,[ap(1,1,-62),ap(2,11,-70)]),"w",{mode:"live"});await W(300);
STARCHORUS.load(mk(1030,[ap(1,1,-62),ap(2,11,-70),ap(3,6,-42)]),"w",{mode:"live"});await W(200);STARCHORUS.frame();
const g=SC.g,span=g.rFar-g.rNear,n3=S.aps.get("02:00:00:00:00:03");
const arc=p=>{const y=g.oy-(g.rFar-span*p);let m=0;for(let dx=-3;dx<=3;dx++)for(let dy=-1;dy<=1;dy++)m=Math.max(m,STARCHORUS.pixel("sky",g.ox+dx,y+dy).a);return m>0};
o.rm=document.documentElement.dataset.rm;
o.newBlip=[n3.sc.nw,+n3.alphaDraw.toFixed(2),arc(0.3),arc(0.6)];
const sky=()=>{const c=document.getElementById("sky"),d=c.getContext("2d").getImageData(0,0,c.width,c.height).data;let n=0,h=0;for(let i=3;i<d.length;i+=4)if(d[i]){n++;h=(h*31+i+d[i])|0}return n+":"+h};
S.staleMs=1e9;STARCHORUS.load(mk(1030,[ap(1,1,-62),ap(2,11,-70),ap(3,6,-42)]),"w",{mode:"live"});await W(300);STARCHORUS.frame();
const a=sky();await W(700);STARCHORUS.frame();const b=sky();
o.snow=[SC.lv,a===b,+a.split(":")[0]>0];
const a2=(S.dirty=true,STARCHORUS.frame(),sky());o.still=a2===a;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
SCP_EVU='(async()=>{const I=STARCHORUS._internals,S=I.S,SC=I.SC,W=STARCHORUS.wait,E=i=>document.getElementById(i),DE=document.documentElement,o={};
const R=e=>e.getBoundingClientRect(),cs=(e,p)=>getComputedStyle(e)[p];
const key=k=>document.body.dispatchEvent(new KeyboardEvent("keydown",{key:k,bubbles:true}));
await W(300);key("u");await W(500);
const st=R(E("scope-strip")),ft=R(E("scope-foot")),pl=R(E("panels-pill")),g=SC.g;
o.hidden=[DE.dataset.panels,cs(E("bar"),"visibility"),cs(E("sheet"),"visibility"),cs(E("scope-strip"),"display"),cs(E("scope-strip"),"visibility"),cs(E("scope-foot"),"display"),cs(E("panels-pill"),"display"),DE.dataset.scope].join();
o.fit=[st.top>=0&&st.bottom<=innerHeight&&ft.bottom<=pl.top+0.5,g.py<ft.bottom&&g.py>ft.top,pl.height>=44,E("pill-chip").textContent===E("mode-chip").textContent];
const n=[...S.aps.values()].filter(x=>x.sc&&x.alphaDraw>0.3).length;o.blips=n>5;
key("u");await W(500);o.back=[DE.dataset.panels,cs(E("bar"),"visibility"),cs(E("sheet"),"visibility"),DE.dataset.scope].join();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
SCP_EVX='(async()=>{const I=STARCHORUS._internals,S=I.S,SC=I.SC,W=STARCHORUS.wait,o={};
const key=k=>document.body.dispatchEvent(new KeyboardEvent("keydown",{key:k,bubbles:true}));
const cnt=()=>{const c={ap:0,client:0,cloud:0};for(const M of [S.aps,S.clients,S.clouds])for(const n of M.values())if(n.sc&&n.sc.st===SC.st)c[n.kind]++;const k=document.getElementById("scope-strip").children;return c.ap+"/"+c.client+"/"+c.cloud+"/"+STARCHORUS.stats().clients+"/"+k[0].textContent+","+k[2].textContent+","+k[4].textContent};
await W(400);o.cloud=[S.ui.random,cnt()];
key("x");await W(400);o.show=[S.ui.random,cnt()];
key("x");await W(400);o.hide=[S.ui.random,cnt()];
key("x");await W(400);o.back=[S.ui.random,cnt()];
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
SCP_EVY='(async()=>{const I=STARCHORUS._internals,S=I.S,W=STARCHORUS.wait,E=i=>document.getElementById(i),o={};
const vis=id=>{const e=E(id);return !!e&&!e.hidden};
STARCHORUS.setToggles({nebula:true,groups:true,devices:true,deviceLinks:true,merge:true,essMerge:true});await W(300);
o.rowOn=[vis("leg-scope"),(E("leg-scope")||{}).textContent];
o.legendScope=["leg-nebula","leg-groups","leg-devices","leg-merge","leg-crowding","leg-block-derived"].map(vis);
STARCHORUS.setToggles({scope:false});await W(300);
o.rowOff=[vis("leg-scope")];
o.legendSky=["leg-nebula","leg-groups","leg-devices","leg-merge","leg-crowding","leg-block-derived"].map(vis);
STARCHORUS.setToggles({scope:true});await W(300);
STARCHORUS.setView("3d");await W(600);
const ap=[...S.aps.values()].filter(n=>n.sc&&n.alphaDraw>0.3).sort((a,b)=>a.sy-b.sy)[0];
o.view=[S.ui.view,STARCHORUS.hitTest(ap.sx,ap.sy)===ap.id];
STARCHORUS.select(ap.id);await W(400);
o.card=[STARCHORUS.phone().card,STARCHORUS.phone().detent,S.cam.tween===null];
STARCHORUS.deselect();STARCHORUS.setView("2d");await W(500);
o.errors=STARCHORUS.errors();return JSON.stringify(o)})()'
SCP_EVT2='(async()=>{const I=STARCHORUS._internals,W=STARCHORUS.wait,E=i=>document.getElementById(i),out=[];
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await W(500);
 out.push(E("scope-strip").textContent,E("scope-foot").textContent,E("t-scope").getAttribute("aria-label"),E("t-scope").title,E("sc-rx").textContent,document.getElementById("hud").getAttribute("aria-label"),I.THEMES[t].copy.scope.strip.join(" "))}
return JSON.stringify(out.join("\n"))})()'
SCP_EVB='(async()=>{const I=STARCHORUS._internals,S=I.S,SC=I.SC,W=STARCHORUS.wait;await W(400);
let n=0;for(const M of [S.aps,S.clients,S.clouds])for(const nd of M.values())if(nd.sc&&nd.sc.st===SC.st)n++;
SC.ph=0.5;const t=[];for(let i=0;i<60;i++){S.dirty=true;const t0=performance.now();STARCHORUS.frame();t.push(performance.now()-t0)}SC.ph=null;
return JSON.stringify([n,+(t.reduce((a,b)=>a+b,0)/t.length).toFixed(2),+Math.max(...t).toFixed(1),STARCHORUS.errors().length])})()'
# a saved 3D view (?view=3d: the blend is 1 from the start): the Scope draws no 3D ring label, no empty core label, and nothing lies on the RX line
SCP_EV3='(async()=>{const I=STARCHORUS._internals,S=I.S,W=STARCHORUS.wait,E=i=>document.getElementById(i),o={};
const out=[];for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await W(600);S.dirty=true;STARCHORUS.frame();
 const L=S.labelsList||[],rx=E("sc-rx").getBoundingClientRect();
 out.push([t,L.filter(l=>l.kind==="ring").length,L.filter(l=>l.id==="__center__").length,L.filter(l=>l.w&&l.x<rx.right&&l.x+l.w>rx.left&&l.y<rx.bottom&&l.y+14>rx.top).length].join(":"))}
o.blend=[S.ui.view,S.view.blend];o.labels=out.join(" ");o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
# the strip at a narrow size, in each theme: every cell inside the panel and the screen, the words 13 px or more, the strongest signal's unit in its own case
SCP_EVF='(async()=>{const W=STARCHORUS.wait,E=i=>document.getElementById(i),R=e=>e.getBoundingClientRect(),o={};
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await W(700);const s=E("scope-strip"),r=R(s),cs=getComputedStyle(s),bad=[];
 const cr=r.right-parseFloat(cs.borderRightWidth),cl=r.left+parseFloat(cs.borderLeftWidth),cells=[...s.children];   // the edge of the panel: a word may use the padding, never leave the panel
 if(cells.length!==10)bad.push("cells "+cells.length);
 for(const e of cells){const b=R(e);if(b.right>cr+0.5||b.left<cl-0.5||b.right>innerWidth||b.left<0)bad.push("out "+e.textContent+" "+Math.round(b.right)+">"+Math.round(cr))}
 if(s.scrollWidth>s.clientWidth+1)bad.push("scroll "+s.scrollWidth+">"+s.clientWidth);
 const fs=[...s.querySelectorAll("i")].map(e=>parseFloat(getComputedStyle(e).fontSize));if(Math.min(...fs)<13)bad.push("font "+Math.min(...fs));
 const nums=[...s.querySelectorAll("b")];if(nums.some(e=>R(e).width<=0))bad.push("a number has no width");
 if(!/dBm$/.test(nums[3].textContent)||getComputedStyle(nums[3]).textTransform!=="none")bad.push("the unit lost its case: "+nums[3].textContent);
 const ft=R(E("scope-foot"));if(ft.top<r.bottom-0.5||ft.bottom>innerHeight+0.5||document.documentElement.scrollWidth!==innerWidth)bad.push("foot/page");
 o[t]=bad.join("; ")||"ok "+(s.className.replace(/panel|ph-only/g,"").trim()||"full")}
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
# WarGames, the Air drawer: its per-AP lamp strip keeps one lamp per access point after a poll, a second load and the key; the bar's eight capture lamps are a different set
SCP_EVM='(async()=>{const S=STARCHORUS._internals.S,W=STARCHORUS.wait,E=i=>document.getElementById(i),o={};
const key=k=>document.body.dispatchEvent(new KeyboardEvent("keydown",{key:k,bubbles:true}));
const st=()=>{const s=document.querySelector("#lamp-strip .lamps");return s?[s.querySelectorAll("i[data-bssid]").length,s.getAttribute("aria-label")]:[-1,"no strip"]};
STARCHORUS.setTheme("wargames");await W(500);key("q");await W(700);const a=st(),want=STARCHORUS.lampStrip().lamps.length;
await STARCHORUS.pollNow();await W(700);const b=st();
key("q");await W(300);key("q");await W(700);const c=st();
STARCHORUS.setTheme("foundation");await W(300);STARCHORUS.setTheme("wargames");await W(700);const d=st();
o.n=[a[0],b[0],c[0],d[0]];o.want=want;o.label=[a[1],b[1],c[1],d[1]];
const bl=E("scope-lamps");o.bar=[bl.children.length,/^capture counter/.test(bl.getAttribute("aria-label")||"")];
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
# 568x320: a fan that has no room says so (Whitehall), comes back with a roomier theme, and says so again
SCP_EVN='(async()=>{const I=STARCHORUS._internals,SC=I.SC,W=STARCHORUS.wait,E=i=>document.getElementById(i),R=e=>e.getBoundingClientRect(),o={};
const st=()=>{const n=E("sc-no"),ft=R(E("scope-foot")),sp=R(E("scope-strip"));return [SC.g?"fan":"none",!n.hidden&&n.getClientRects().length>0?"note":"-",ft.top>=sp.bottom-0.5&&ft.bottom<=innerHeight+0.5&&ft.left>=0&&ft.right<=innerWidth+0.5,document.documentElement.scrollWidth===innerWidth].join("|")};
for(const t of ["whitehall","foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await W(700);o[o[t]?t+"2":t]=st()}
o.text=E("sc-no").textContent;o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
# radio-pair.json: a fifth lane while Bluetooth marks are heard and the filter (key 4) is on; without them the four lanes are exactly the old ones
SCP_EVQ='(async()=>{const I=STARCHORUS._internals,S=I.S,SC=I.SC,W=STARCHORUS.wait,o={};
const key=k=>document.body.dispatchEvent(new KeyboardEvent("keydown",{key:k,bubbles:true}));
const lanes=()=>SC.g.lanes.map(l=>l.key+":"+l.k0.toFixed(4)+"/"+l.k1.toFixed(4)).join(" ");
await W(400);
const fx=await (await fetch("starchorus.json")).json();STARCHORUS.load(fx,"fx",{mode:"live"});await W(1800);STARCHORUS.frame();
o.on=lanes();const g=SC.g,bl=g.lanes[4],marks=[...S.bt.values()].filter(k=>k.sc&&k.sc.st===SC.st);o.n=[marks.length,S.btOrder.length];
const bad=[];for(const k of marks){const r=Math.hypot(k.sc.x-g.ox,k.sc.y-g.oy),want=g.rNear+(1-Math.min(1,Math.max(0,(k.rssi+90)/60)))*(g.rFar-g.rNear);if(Math.abs(r-want)>0.5)bad.push("r:"+k.id);if(!(k.sc.k>=bl.k0&&k.sc.k<=bl.k1))bad.push("lane:"+k.id)}
o.marks=bad.join(";")||"ok";
const m=[...marks].sort((a,b)=>b.rssi-a.rssi)[0];o.hit=STARCHORUS.hitTest(m.sx,m.sy)===m.id;
o.leg=(()=>{const r=STARCHORUS.legendRows().find(r=>r.kind==="bt");return !!r&&r.visible})();
key("4");await W(600);o.off=lanes();key("4");await W(600);o.back=lanes();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
# four strong 6 GHz networks at 320 px: the lane near the Pager is a few pixels wide, so the nudge would turn over; each point stays inside its lane
SCP_EVC='(async()=>{const I=STARCHORUS._internals,S=I.S,SC=I.SC,W=STARCHORUS.wait,o={};
const mk=(g,aps)=>({source:"recon-db",generated:g,center:{label:"T",interval:30},aps,unassociated:[]});
const ap=(n,ch,rssi)=>({bssid:"02:00:00:00:00:0"+n,ssid:"N"+n,band:"6",channel:ch,rssi,security:"WPA3"});
STARCHORUS.load(mk(1000,[ap(1,5,-34),ap(2,7,-35),ap(3,9,-36),ap(4,11,-37)]),"c");await W(500);
const l6=SC.g.lanes.find(l=>l.key==="6"),out=[];
for(const n of S.aps.values()){const s=n.sc;if(!s||s.st!==SC.st)continue;if(s.k<l6.k0-1e-9||s.k>l6.k1+1e-9)out.push(n.ssid+":"+s.k.toFixed(3))}
o.out=out.join(",")||"none";o.n=[...S.aps.values()].filter(n=>n.sc&&n.sc.st===SC.st).length;o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
# the text the Scope draws on #bg and #hud: ticks that do not touch, and no canvas label under 13 px
SCP_EVK='(async()=>{const S=STARCHORUS._internals.S,W=STARCHORUS.wait,E=i=>document.getElementById(i),o={},rec=[];
for(const id of ["bg","hud"]){const c=E(id).getContext("2d"),f=c.fillText;c.fillText=function(t,x,y){rec.push([id,String(t),x,y,this.measureText(String(t)).width,this.font]);return f.apply(this,arguments)}}
const px=r=>parseFloat(/(\d+(?:\.\d+)?)px/.exec(r[5])[1]);
for(const t of ["wargames","whitehall","foundation"]){rec.length=0;STARCHORUS.setTheme(t);await W(500);S.dirty=true;STARCHORUS.frame();
 const bg=rec.filter(r=>r[0]==="bg"),hud=rec.filter(r=>r[0]==="hud");
 const tk=bg.slice(bg.map(r=>r[1]).lastIndexOf("1")).filter(r=>/^\d+$/.test(r[1])).sort((a,b)=>a[2]-b[2]),touch=[];   // the ticks of the last rebuild: its first tick is the "1"
 for(let i=1;i<tk.length;i++)if(tk[i][2]-tk[i][4]/2<tk[i-1][2]+tk[i-1][4]/2)touch.push(tk[i-1][1]+" "+tk[i][1]);
 o[t]={n:tk.length,touch:touch.join(","),bgMin:Math.min(...bg.map(px)),hudMin:hud.length?Math.min(...hud.map(px)):99}}
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'

# devices.json with the ESS merge on (the live clock: under ?fixed the sky's stars never fade in): the folded members of a merged set are drawn as blips, so each can be tapped and none carries the count badge of the sky's lead; in the sky it is the other way round
SCP_EVE='(async()=>{const I=STARCHORUS._internals,S=I.S,W=STARCHORUS.wait,o={};
STARCHORUS.setToggles({essMerge:true});await W(1500);STARCHORUS.frame();
const fold=()=>[...S.aps.values()].filter(n=>n.essFolded),cnt=()=>STARCHORUS.labels().filter(l=>l.kind==="counter").length,hit=()=>fold().filter(n=>STARCHORUS.hitTest(n.sx,n.sy)===n.id).length;
o.folded=fold().length;o.merged=STARCHORUS.stats().essMerged;o.scope=[hit(),cnt()];
STARCHORUS.setToggles({scope:false});await W(1500);STARCHORUS.frame();o.sky=[hit(),cnt()];
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
# an ingest that flips the strip into its short form (class n: words hidden, 16 px less) and back: the fan's top (SC.g.top) must follow the strip's height (offsetHeight), which an ingest alone used to leave until the next resize
SCP_EVH='(async()=>{const I=STARCHORUS._internals,SC=I.SC,W=STARCHORUS.wait,E=i=>document.getElementById(i),o={};
const doc={source:"recon-db",generated:1000,center:{label:"T",interval:30},aps:[{bssid:"02:00:00:00:00:01",ssid:"A",band:"2.4",channel:6,rssi:-48,security:"WPA2"}],unassociated:[]};
const st=()=>{const s=E("scope-strip");return [s.className.replace(/panel|ph-only/g,"").trim()||"full",s.offsetHeight,Math.round(SC.g.top*10)/10,Math.round((SC.g.b.y+s.offsetHeight+4)*10)/10].join("|")};
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await W(600);
 const w=I.THEMES[t].copy.scope.strip,keep=w[0],r=[];
 doc.generated+=30;STARCHORUS.load(doc,"x");await W(500);r.push(st());
 w[0]="x".repeat(60);doc.generated+=30;STARCHORUS.load(doc,"x");await W(500);r.push(st());   // a first word no panel can hold: the words go (class t, then n)
 w[0]=keep;doc.generated+=30;STARCHORUS.load(doc,"x");await W(500);r.push(st());
 o[t]=r}
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'

# ---- geometry, lanes, captions, text size, overlaps and the sideways scroll: 4 phone sizes x 3 themes (devices.json)
for SCP_Z in 390x844 375x812 430x932 812x375; do
  scp_run "geom-$SCP_Z" "$SCP_EVG" "$F/devices.json" "$SCP_Q" "${SCP_Z%x*}" "${SCP_Z#*x}"
  SCP_R=$(scp_j geom "$(scp_ev "$SCP_T-geom-$SCP_Z.json")" 20)
  scp_row "scope $SCP_Z, 3 themes: every point at its signal's radius (0.5 px) and in its band's lane, the fan inside its box, the Pager in the foot, the captions verbatim, text 13 px or more, no overlap among strip, foot, bar, sheet, banners and pill, no sideways scroll" "$SCP_R"
done

# ---- default off, the button (44 px, in the sheet's row), click, key Z, the sky's controls at rest, the key's help line; the wide desktop has none
scp_run toggle "$SCP_EVT" "$F/devices.json" "?poll=0&spin=0&intro=0&debug=1" 390 844 --ready "$SCP_RDY"
SCP_R=$(scp_j toggle "$(scp_ev "$SCP_T-toggle.json")")
scp_row "scope: off by default; #t-scope is 44x44 in #sheet-row; a click and Z turn it on and off (strip and foot shown, the sky's counts, 3D button and layers rest), saved at once; the key is in the help [Z]" "$SCP_R"
scp_run deskoff "$SCP_EVD" "$F/devices.json" "?poll=0&spin=0&intro=0&debug=1" 1440 900 --wait 2 --ready "$SCP_RDY"
SCP_R1=$(scp_j desk "$(scp_ev "$SCP_T-deskoff.json")" "off,off,false,none,none,none|off,off,false,none,none,none")
runq "$F/devices.json" "?poll=0&spin=0&intro=0&debug=1&scope=1" "$SCP_T-desk" --width 1440 --height 900 --wait 2 --fps 0 --ready "$SCP_RDY" --eval "$SCP_EVD" >/dev/null 2>&1
SCP_R2=$(scp_j desk "$(scp_ev "$SCP_T-desk.json")" "off,off,true,none,none,none|off,off,true,none,none,none")
SCP_D=$(python3 -B -c 'import json,sys; d=json.loads(sys.argv[1]); print(d["boot"] + " " + d["z"])' "$(scp_ev "$SCP_T-desk.json")" 2>&1)
rowif "scope: the wide desktop (1440x900) has no Scope: the button, strip and foot are not shown, ?scope=1 changes nothing and Z does nothing ($SCP_D)" [ "$SCP_R1/$SCP_R2" = ok/ok ]
runq "$F/devices.json" "?poll=0&spin=0&intro=0&debug=1&scope=1&phone=1" "$SCP_T-deskp" --width 1440 --height 900 --wait 2 --fps 0 --ready "$SCP_RDY" --eval "$SCP_EVD" >/dev/null 2>&1
SCP_DP=$(python3 -B -c 'import json,sys; d=json.loads(sys.argv[1]); print(d["boot"] + " " + d["z"] + " " + str(d["errors"]))' "$(scp_ev "$SCP_T-deskp.json")" 2>&1)
runq "$F/devices.json" "?poll=0&spin=0&intro=0&debug=1&scope=1&phone=0" "$SCP_T-ph0" --width 390 --height 844 --mobile --wait 2 --fps 0 --ready "$SCP_RDY" --eval "$SCP_EVD" >/dev/null 2>&1
SCP_P0=$(python3 -B -c 'import json,sys; d=json.loads(sys.argv[1]); print(d["boot"] + " " + str(d["errors"]))' "$(scp_ev "$SCP_T-ph0.json")" 2>&1)
rowif "scope: ?phone=1 on a wide window shows it (on,on,true,flex,grid,grid), Z saves false there; ?phone=0 beats ?scope=1 on a phone [$SCP_DP / $SCP_P0]" [ "$SCP_DP/$SCP_P0" = "on,on,true,flex,grid,grid on,off,false,flex,none,none 0/off,off,true,none,none,none 0" ]

# ---- ?scope and the saved value: a click is saved and comes back on a reload; ?scope=0 overrides it for one load and is not saved; ?scope=1 boots on
runq demo "?poll=0&spin=0&intro=0&debug=1" "$SCP_T-persist" --width 390 --height 844 --mobile --wait 2 --fps 0 --eval "$SCP_EVP" \
  --step "eval:(location.reload(),'r')" --step wait:2.5 --step "eval:$SCP_RD" \
  --step "eval:(location.assign(location.pathname + '?poll=0&spin=0&intro=0&debug=1&scope=0'),'r')" --step wait:2.5 --step "eval:$SCP_RD" \
  --step "eval:(location.assign(location.pathname + '?poll=0&spin=0&intro=0&debug=1&scope=1'),'r')" --step wait:2.5 --step "eval:$SCP_RD" >/dev/null 2>&1
SCP_PV=$(evals "$SCP_T-persist.json" | python3 -B -c 'import json,sys; print(json.dumps([json.loads(l) if l.strip() != "\"r\"" else "r" for l in sys.stdin if l.strip()]))' 2>&1)
SCP_R=$(scp_j persist "$SCP_PV")
scp_row "scope: a click is saved (starchorus.ui.v1, within 300 ms) and the next load is on; ?scope=0 turns it off for that load and the saved value stays; ?scope=1 turns it on [$SCP_PV]" "$SCP_R"

# ---- lanes by band and channel, hash places, no direction: channels ascend within a lane; an unknown band lands in the 6 lane (SC.unk); the same capture in
# the opposite order gives the same points; a station keeps its place when its signal changes; a channel change moves a network only inside its lane
scp_run angle "$SCP_EVA" "$F/devices.json" "$SCP_Q" 390 844
SCP_R=$(scp_j angle "$(scp_ev "$SCP_T-angle.json")")
scp_row "scope: channels 1 < 6 < 11, 36 < 100 < 149, 5 < 101 ascend; an unknown band sits in the 6 lane (and is named there); reversed arrays give the same points; a signal change keeps a station's place; a channel change stays in the lane" "$SCP_R"

# ---- the strip against a recount of the fixtures in Python (networks, stations, the strongest signal, none new in a first capture) and its words per theme
for SCP_FX in devices:0 clouds:1 few-clients:0 empty-none:0; do
  SCP_N=${SCP_FX%:*}; SCP_C=${SCP_FX#*:}
  scp_run "strip-$SCP_N" "$SCP_EVS" "$F/$SCP_N.json" "$SCP_Q" 390 844
  SCP_R=$(python3 -B "$SCP_T/judge.py" strip "$(scp_ev "$SCP_T-strip-$SCP_N.json")" "$F/$SCP_N.json" "$SCP_C" 2>&1 | head -n 1)
  scp_row "scope strip on $SCP_N.json = a Python recount (networks, stations, $SCP_C clouds, the strongest signal, 0 new), the five words = copy.scope.strip of each theme, the lamps of WarGames only" "$SCP_R"
done

# ---- liveness: a stale feed and an unreachable one: snow, a dashed rim, the chip's word in the foot; never the alarm colour on the fan
scp_run live "$SCP_EVL" "$F/devices.json" "$SCP_Q&theme=wargames" 390 844
SCP_R=$(scp_j live "$(scp_ev "$SCP_T-live.json")")
scp_row "scope liveness (WarGames): live has no snow and a solid rim; stale adds specks, a dashed rim and the word Stale to the foot; offline adds more and reads Link down; no pixel of #bg is the alarm colour" "$SCP_R"

# ---- the wave: a new blip waits for the front, the front contracts (never outward), nothing is drawn while nothing moves; reduced motion has no wave
scp_run wave "$SCP_EVW" "$F/devices.json" "$SCP_Q" 390 844
SCP_R=$(scp_j wave "$(scp_ev "$SCP_T-wave.json")")
scp_row "scope wave: a new blip (phase 0.8) is hidden at 0.3 and 0.6 and shown at 0.9, the arc is on its radius at each phase and gone from the old one a phase later (it contracts), the old blip stays" "$SCP_R"
runq demo "$SCP_LQ" "$SCP_T-idle" --width 390 --height 844 --mobile --wait 6 --fps 0 --eval-timeout 90 --eval "$SCP_EVI" >/dev/null 2>&1
SCP_R=$(scp_j idle "$(scp_ev "$SCP_T-idle.json")")
scp_row "scope draws only on a wave: 0 frames in 2 s at rest and again 5 s after a capture, 30 or more in the first second of a wave, 2 a second (3 to 6 in 2 s) while the feed is stale" "$SCP_R"
runq demo "$SCP_LQ&rm=1" "$SCP_T-rm" --width 390 --height 844 --mobile --wait 2 --fps 0 --eval-timeout 60 --eval "$SCP_EVR" >/dev/null 2>&1
SCP_R=$(scp_j rm "$(scp_ev "$SCP_T-rm.json")")
scp_row "scope with reduced motion: a new capture shows its blip at once, no arc, and the snow of a stale feed stands still (two frames 700 ms apart equal)" "$SCP_R"

# ---- a tap on a blip opens its detail (the title is its name), a tap on the empty fan closes it; a finger (touch), not a mouse
runq "$F/devices.json" "$SCP_Q" "$SCP_T-sel0" --width 390 --height 844 --mobile --wait 2 --fps 0 --eval '(async()=>{const I=STARCHORUS._internals,S=I.S,SC=I.SC,g=SC.g;await STARCHORUS.wait(300);STARCHORUS.frame();
const ap=[...S.aps.values()].filter(n=>n.sc&&n.alphaDraw>0.3).sort((a,b)=>b.rssi-a.rssi)[0];let empty=null;
for(let y=g.top+10;y<g.py-60&&!empty;y+=8)for(let x=g.b.x+20;x<g.b.x+g.b.w-20;x+=8){const r=Math.hypot(x-g.ox,y-g.oy);if(r<g.rNear+10||r>g.rFar-10)continue;if(STARCHORUS.hitTest(x,y)===null&&Math.abs(x-g.ox)<g.half*0.9){empty=[x,y];break}}
return JSON.stringify([Math.round(ap.sx),Math.round(ap.sy),ap.ssid,empty])})()' >/dev/null 2>&1
SCP_XY=$(evalv "$SCP_T-sel0.json" 1 | python3 -B -c 'import json,sys; a=json.loads(sys.stdin.read()); print("%d %d %d %d" % (a[0], a[1], a[3][0], a[3][1]))' 2>/dev/null)
# shellcheck disable=SC2086   # the four numbers are a word list on purpose
set -- $SCP_XY 0 0 0 0
SCP_ST='(()=>{const I=STARCHORUS._internals,p=STARCHORUS.phone();return JSON.stringify([p.card,p.detent,document.getElementById("sheet-title").textContent,I.S.locked])})()'
runq "$F/devices.json" "$SCP_Q" "$SCP_T-sel" --width 390 --height 844 --mobile --wait 2 --fps 0 --step "touch:$1,$2,$1,$2,60" --step wait:0.6 --step "eval:$SCP_ST" \
  --step "touch:$3,$4,$3,$4,60" --step wait:0.6 --step "eval:$SCP_ST" >/dev/null 2>&1
SCP_SV=$(evals "$SCP_T-sel.json" | python3 -B -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))' 2>&1)
SCP_SV=$(python3 -B -c 'import json,sys; print(json.dumps([json.loads(x) for x in json.loads(sys.argv[1])]))' "$SCP_SV" 2>&1)
SCP_R=$(scp_j select "$SCP_SV")
scp_row "scope: a touch on the strongest blip opens its detail in the sheet (title = its name, locked), a touch on empty fan closes it [$SCP_XY]" "$SCP_R"

# ---- Random (X): one cloud and the singles, then every address, then none; the strip follows
scp_run random "$SCP_EVX" "$F/clouds.json" "$SCP_Q" 390 844
SCP_R=$(scp_j rand "$(scp_ev "$SCP_T-random.json")")
scp_row "scope Random on clouds.json: cloud = 6 networks, 41 stations, 1 cloud; show = 162 stations; hide = 23; the strip says 6,162,1 / 6,162,0 / 6,23,0 (the counts of the sky)" "$SCP_R"

# ---- Hide panels (U): the bar and the sheet go, the strip, the foot and the pill stay, the foot clear of the pill
scp_run panels "$SCP_EVU" "$F/devices.json" "$SCP_Q" 390 844
SCP_R=$(scp_j panels "$(scp_ev "$SCP_T-panels.json")")
scp_row "scope with U: bar and sheet hidden, strip and foot shown, the pill (44 px, the chip's word) below the foot, the blips still there; U again brings the panels back" "$SCP_R"

# ---- the legend and the 3D view: the derived rows are not drawn in the Scope (D10), and a saved 3D view does not fly the camera on a tap
scp_run legend "$SCP_EVY" "$F/devices.json" "$SCP_Q" 390 844
SCP_R=$(scp_j legend "$(scp_ev "$SCP_T-legend.json")")
scp_row "scope: the legend hides the derived rows (nebula, groups, devices, merge, crowding and their head) while it is on and shows them again off, and has its own row 'scope' (the two captions in one line) only while it is on; with a saved 3D view a tap still picks the blip and the detail opens at half without a camera tween" "$SCP_R"

# ---- no direction, no distance in any word the Scope shows (the captions say 'not direction' and 'not range' and are taken out first)
scp_run words "$SCP_EVT2" "$F/devices.json" "$SCP_Q" 390 844
SCP_R=$(scp_j direction "$(scp_ev "$SCP_T-words.json")")
scp_row "scope: no word of direction or distance (bearing, heading, compass, a point of the compass, ahead, degrees, metres, distance, range, nearby) in the strip, the foot, the button, the key's help, the aria texts or the theme words" "$SCP_R"
python3 -B -c 'import json; d=json.dumps("lanes = band, channel / not direction / ahead of you")' && printf '%s\n' '"north ahead, 30 degrees"' > "$SCP_T/dir-dummy.json" && SCP_DD=$(scp_j direction "$(cat "$SCP_T/dir-dummy.json")")
printf '%s\n' '"a strong network is near the Pager, the nearest ring is the strongest"' > "$SCP_T/dist-dummy.json" && SCP_DE=$(scp_j direction "$(cat "$SCP_T/dist-dummy.json")")
printf '%s\n' '"a strong signal sits on the inner arcs, by the Pager mark; the innermost ring is the strongest signal"' > "$SCP_T/dist-clean.json" && SCP_DC=$(scp_j direction "$(cat "$SCP_T/dist-clean.json")")
SCP_DK=0; [ "$SCP_DD" != ok ] && [ "$SCP_DE" != ok ] && [ "$SCP_DC" = ok ] && SCP_DK=1
rowif "scope: the word judge says no to a dummy ('north ahead, 30 degrees': $SCP_DD) and to a claim of distance ('near the Pager', 'the nearest ring': $SCP_DE), and yes to the words that say signal and screen only ($SCP_DC)" [ "$SCP_DK" = 1 ]

# ---- the cost of a frame (a ceiling in headless software raster, not a phone's time): 5, 50 and 300 blips
python3 tools/gen-testdata.py --aps 3 --clients 2 --seed 22 --out "$SCP_T/b5.json" >/dev/null 2>&1
python3 tools/gen-testdata.py --aps 20 --clients 30 --seed 22 --out "$SCP_T/b50.json" >/dev/null 2>&1
python3 tools/gen-testdata.py --aps 60 --clients 240 --seed 22 --out "$SCP_T/b300.json" >/dev/null 2>&1
SCP_PF=""
for SCP_B in 5:3 50:4 300:6; do
  SCP_BN=${SCP_B%:*}; SCP_BM=${SCP_B#*:}
  scp_run "bench$SCP_BN" "$SCP_EVB" "$SCP_T/b$SCP_BN.json" "$SCP_Q" 390 844
  SCP_R=$(scp_j perf "$(scp_ev "$SCP_T-bench$SCP_BN.json")" "$SCP_BN" "$SCP_BM")
  [ "$SCP_R" = ok ] || SCP_PF="$SCP_PF $SCP_BN:$SCP_R"
done
rowif "scope: a frame at wave phase 0.5 costs at most 3, 4 and 6 ms of JS for 5, 50 and 300 blips (headless; the phone's goal is in the spec)${SCP_PF:+ [$SCP_PF]}" [ -z "$SCP_PF" ]

# ---- the network: with the Scope on and a live poll the page asks for nothing but starchorus.json, by GET, from its own origin
runq "$F/many-clients.json" "?spin=0&intro=0&scope=1" "$SCP_T-net" --width 390 --height 844 --mobile --wait 12 --fps 0 --eval 'STARCHORUS.errors().length' >/dev/null 2>&1
SCP_NV=$(net_verdict "$SCP_T-net.json" - 2); SCP_NC=$?
rowif "scope: runtime network with the Scope on: $SCP_NV" [ "$SCP_NC" = 0 ]

# ---- the strip at the narrow sizes of the review: 320x568, 568x320 (a small phone on its side), 640x360 and 667x375: words are cut (tighter, then none), numbers stay, 13 px stays
for SCP_Z in 320x568 568x320 640x360 667x375; do
  scp_run "fit-$SCP_Z" "$SCP_EVF" "$F/devices.json" "$SCP_Q" "${SCP_Z%x*}" "${SCP_Z#*x}"
  SCP_R=$(scp_j fit "$(scp_ev "$SCP_T-fit-$SCP_Z.json")")
  scp_row "scope strip $SCP_Z, 3 themes: the five numbers and the words that fit lie inside the panel and the screen, no sideways scroll, the words 13 px, the unit of the strongest signal in its own case, the foot clear below" "$SCP_R"
done

# ---- WarGames' Air drawer: the lamp strip of access points keeps its lamps (and has no counter's label) when the Scope's second set of lamps is rendered
scp_run lamps "$SCP_EVM" "$F/devices.json" "$SCP_Q" 390 844
SCP_R=$(scp_j lamps "$(scp_ev "$SCP_T-lamps.json")")
scp_row "scope (WarGames, Air drawer): '#lamp-strip .lamps' keeps one lamp per access point after the key, a poll, a second key and a theme round, and takes no 'capture counter' label; the bar's eight capture lamps are their own set" "$SCP_R"

# ---- a saved 3D view: no 3D ring label, no empty core label, nothing on the RX line (the label list of the Scope's frame)
scp_run ring3d "$SCP_EV3" "$F/devices.json" "$SCP_Q&view=3d" 390 844
SCP_R=$(scp_j ring3d "$(scp_ev "$SCP_T-ring3d.json")")
scp_row "scope with a saved 3D view (?view=3d, blend 1): in each theme the label list of a frame holds no ring label ('-40 dBm'), no empty core label and no label on the RX line" "$SCP_R"

# ---- WarGames with the CRT on (the default): the phosphor trail runs only while the arc does; at rest 0 frames and while stale 3 to 6 in 2 s, as in the other themes
runq demo "$SCP_LQ&theme=wargames" "$SCP_T-idlew" --width 390 --height 844 --mobile --wait 6 --fps 0 --eval-timeout 90 --eval "$SCP_EVI" >/dev/null 2>&1
SCP_R=$(scp_j idle "$(scp_ev "$SCP_T-idlew.json")")
scp_row "scope in WarGames (CRT on, persistence): 0 frames in 2 s at rest and 5 s after a capture, 30 or more in the first second of a wave, 3 to 6 in 2 s while the feed is stale" "$SCP_R"

# ---- no room for the fan (568x320, Whitehall's banners): the foot's note appears, a roomier theme brings the fan back, Whitehall again says so
scp_run note "$SCP_EVN" "$F/devices.json" "$SCP_Q" 568 320
SCP_R=$(scp_j note "$(scp_ev "$SCP_T-note.json")")
scp_row "scope 568x320: Whitehall has no fan and the foot says 'Too little room for the scope: turn the phone upright' (inside the screen, clear of the strip), Foundation and WarGames have the fan and no note, Whitehall again has the note" "$SCP_R"

# ---- the fifth lane: Bluetooth marks (radio-pair.json) in a lane of their own after the stations, at their signal's radius; without marks, or with the filter off, the four lanes are exactly the old ones
scp_run bt "$SCP_EVQ" "$F/radio-pair.json" "$SCP_LQ" 390 844
SCP_R=$(scp_j btlane "$(scp_ev "$SCP_T-bt.json")")
scp_row "scope with Bluetooth marks (radio-pair.json): a fifth lane 'bt' after the stations with the fan still spanning -1 to 1, every mark in it at its signal's radius (0.5 px), a tap on a mark picks it, its legend row shows; key 4 takes the lane away and the four lanes are exactly the lanes without marks" "$SCP_R"

# ---- a lane narrower than two blips (the 6 lane near the Pager at 320 px): a crowd of strong networks keeps its places in the lane, the overlap is accepted
scp_run nudge "$SCP_EVC" "$F/devices.json" "$SCP_Q" 320 568
SCP_R=$(scp_j nudge "$(scp_ev "$SCP_T-nudge.json")")
scp_row "scope 320x568: four strong 6 GHz networks (-34 to -37 dBm, channels 5 to 11) each lie inside the 6 lane, though it is narrower than two of them" "$SCP_R"

# ---- the canvas text: ticks do not touch each other (320x568 and 390x844) and no label on #bg or #hud is under 13 px
for SCP_Z in 320x568 390x844; do
  scp_run "ticks-$SCP_Z" "$SCP_EVK" "$F/devices.json" "$SCP_Q" "${SCP_Z%x*}" "${SCP_Z#*x}"
  SCP_R=$(scp_j ticks "$(scp_ev "$SCP_T-ticks-$SCP_Z.json")")
  scp_row "scope $SCP_Z, 3 themes: the channel ticks do not touch, and no text drawn on #bg (ticks, lane names, ring labels) or #hud (labels) is under 13 px" "$SCP_R"
done

# ---- the ESS merge in the Scope: every folded member is drawn as a blip, so each can be tapped, and the sky's count badge of a merged set (it counts members that the sky folds into the lead) is not drawn; the sky keeps both
scp_run ess "$SCP_EVE" "$F/devices.json" "$SCP_LQ" 390 844
SCP_R=$(scp_j ess "$(scp_ev "$SCP_T-ess.json")")
scp_row "scope with the ESS merge on (devices.json: 3 folded members in 2 merged sets): in the Scope each of the 3 can be tapped and no count badge is drawn; with the Scope off none of them is hit and both badges are drawn" "$SCP_R"

# ---- an ingest that changes the strip's form moves the fan with it (the strip's height and the fan's top were measured once, at the last resize)
scp_run stripgeom "$SCP_EVH" "$F/devices.json" "$SCP_Q" 390 844
SCP_R=$(scp_j stripgeom "$(scp_ev "$SCP_T-stripgeom.json")")
scp_row "scope: an ingest that takes the strip's words off (class n) and one that brings them back leave the fan's top where the strip ends (SC.g.top = the box's top + the strip's height + 4 px, within 0.5 px) in all three themes, and the strip does change its height" "$SCP_R"

# ---- the probes bite: page copies with one fault each (served to headless Chrome on 127.0.0.1 only) must turn their row red; the rows above are the control
scp_mut() {   # scp_mut NAME SED_EXPR: a copy of the page with one substitution, which must have happened once
  SCP_MP="$SCP_T/mut-$1.html"; sed "$2" "$H" > "$SCP_MP"; SCP_MN=$(cmp -l "$H" "$SCP_MP" 2>/dev/null | wc -l | tr -d ' ')
  [ "$SCP_MN" != 0 ] || { SCP_MP=""; return 1; }
}
scp_mutrun() { SCP_HK=$H; H=$SCP_MP; "$@"; H=$SCP_HK; }   # runq serves $H: point it at the copy for the one call
SCP_MB=""   # the mutants that did not bite
# an arc that runs outward
scp_mut outward 's/rf = g.rFar - (g.rFar - g.rNear) \* p, lv/rf = g.rNear + (g.rFar - g.rNear) * p, lv/' || SCP_MB="$SCP_MB outward(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mwave "$SCP_EVW" "$F/devices.json" "$SCP_Q" 390 844; [ "$(scp_j wave "$(scp_ev "$SCP_T-mwave.json")")" != ok ] || SCP_MB="$SCP_MB outward"; }
# a frame every tick
scp_mut always 's/S.clock < SC.t0 + SC.dur + 1.5 ||/true ||/' || SCP_MB="$SCP_MB always(no copy)"
[ -z "$SCP_MP" ] || { SCP_HK=$H; H=$SCP_MP; runq demo "$SCP_LQ" "$SCP_T-midle" --width 390 --height 844 --mobile --wait 6 --fps 0 --eval-timeout 90 --eval "$SCP_EVI" >/dev/null 2>&1; H=$SCP_HK; [ "$(scp_j idle "$(scp_ev "$SCP_T-midle.json")")" != ok ] || SCP_MB="$SCP_MB always"; }
# a radius that is not the signal
scp_mut radius 's/r = scR(g, n.rssi ?? -85), t = /r = scR(g, n.rssi ?? -85) + 3, t = /' || SCP_MB="$SCP_MB radius(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mgeom "$SCP_EVG" "$F/devices.json" "$SCP_Q" 390 844; [ "$(scp_j geom "$(scp_ev "$SCP_T-mgeom.json")" 20)" != ok ] || SCP_MB="$SCP_MB radius"; }
# the bands ignored
scp_mut lanes 's/ls\[a.band in ls ? a.band : (SC.unk = true, "6")\].push(a)/ls["2.4"].push(a)/' || SCP_MB="$SCP_MB lanes(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mlane "$SCP_EVG" "$F/devices.json" "$SCP_Q" 390 844; [ "$(scp_j geom "$(scp_ev "$SCP_T-mlane.json")" 20)" != ok ] || SCP_MB="$SCP_MB lanes"; }
# no key Z
scp_mut nokey 's/^KEY_ACT.z = .*$/KEY_ACT.z = () => {};/' || SCP_MB="$SCP_MB nokey(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mtoggle "$SCP_EVT" "$F/devices.json" "?poll=0&spin=0&intro=0&debug=1" 390 844 --ready "$SCP_RDY"; [ "$(scp_j toggle "$(scp_ev "$SCP_T-mtoggle.json")")" != ok ] || SCP_MB="$SCP_MB nokey"; }
# no snow
scp_mut nosnow 's/^  if (lv !== "live") {$/  if (false) {/' || SCP_MB="$SCP_MB nosnow(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mlive "$SCP_EVL" "$F/devices.json" "$SCP_Q&theme=wargames" 390 844; [ "$(scp_j live "$(scp_ev "$SCP_T-mlive.json")")" != ok ] || SCP_MB="$SCP_MB nosnow"; }
# a caption that claims a direction
scp_mut caption 's/^not direction<\/span><span id="sc-ps">/ahead of you<\/span><span id="sc-ps">/;s/^not direction<\/span>/not direction<\/span>/' || SCP_MB="$SCP_MB caption(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mcap "$SCP_EVG" "$F/devices.json" "$SCP_Q" 390 844; [ "$(scp_j geom "$(scp_ev "$SCP_T-mcap.json")" 20)" != ok ] || SCP_MB="$SCP_MB caption"; }
# a request in the Scope's code
scp_mut post 's/^function renderScope() {$/function renderScope() { fetch("\/x", { method: "POST" });/' || SCP_MB="$SCP_MB post(no copy)"
[ -z "$SCP_MP" ] || { SCP_HK=$H; H=$SCP_MP; runq "$F/many-clients.json" "?spin=0&intro=0&scope=1" "$SCP_T-mnet" --width 390 --height 844 --mobile --wait 8 --fps 0 --eval 'STARCHORUS.errors().length' >/dev/null 2>&1; H=$SCP_HK; net_verdict "$SCP_T-mnet.json" - 2 >/dev/null && SCP_MB="$SCP_MB post"; }
# the lamps loop over every .lamps again (the Air drawer's strip is overwritten by the counter's lamps)
scp_mut lamps 's/document.querySelectorAll("#lamps,#scope-lamps")/document.querySelectorAll(".lamps")/' || SCP_MB="$SCP_MB lamps(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mlamps "$SCP_EVM" "$F/devices.json" "$SCP_Q" 390 844; [ "$(scp_j lamps "$(scp_ev "$SCP_T-mlamps.json")")" != ok ] || SCP_MB="$SCP_MB lamps"; }
# no fitting of the strip (320x568: the words of WarGames and Whitehall run over the edge)
scp_mut nofit 's/^  for (const x of "tn") if (sp.scrollWidth > sp.clientWidth + 1) cs.add(x);$//' || SCP_MB="$SCP_MB nofit(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mfit "$SCP_EVF" "$F/devices.json" "$SCP_Q" 320 568; [ "$(scp_j fit "$(scp_ev "$SCP_T-mfit.json")")" != ok ] || SCP_MB="$SCP_MB nofit"; }
# the 3D ring labels drawn in the Scope again
scp_mut ring3d 's/const is3d = !scopeOn && S.view.blend > 0.5/const is3d = S.view.blend > 0.5/' || SCP_MB="$SCP_MB ring3d(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mring "$SCP_EV3" "$F/devices.json" "$SCP_Q&view=3d" 390 844; [ "$(scp_j ring3d "$(scp_ev "$SCP_T-mring.json")")" != ok ] || SCP_MB="$SCP_MB ring3d"; }
# the phosphor fade on every frame again
scp_mut persist 's/S.persistOn = P > 0 \&\& S.ui.crt \&\& !(scopeOn \&\& wavePhase() >= 1);/S.persistOn = P > 0 \&\& S.ui.crt;/;s/S.persistOn \&\& !scopeOn ? RENDER.persistFadeFrames/S.persistOn ? RENDER.persistFadeFrames/' || SCP_MB="$SCP_MB persist(no copy)"
[ -z "$SCP_MP" ] || { SCP_HK=$H; H=$SCP_MP; runq demo "$SCP_LQ&theme=wargames" "$SCP_T-mpersist" --width 390 --height 844 --mobile --wait 6 --fps 0 --eval-timeout 90 --eval "$SCP_EVI" >/dev/null 2>&1; H=$SCP_HK; [ "$(scp_j idle "$(scp_ev "$SCP_T-mpersist.json")")" != ok ] || SCP_MB="$SCP_MB persist"; }
# a note that never shows
scp_mut note 's/el("sc-no").hidden = L >= SCOPE.minL;/el("sc-no").hidden = true;/' || SCP_MB="$SCP_MB note(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mnote "$SCP_EVN" "$F/devices.json" "$SCP_Q" 568 320; [ "$(scp_j note "$(scp_ev "$SCP_T-mnote.json")")" != ok ] || SCP_MB="$SCP_MB note"; }
# a fifth lane that is not squeezed in: the fan would span more than -1 to 1
scp_mut btlane 's/u = ls.bt.length ? 0.8368 : 1;/u = 1;/' || SCP_MB="$SCP_MB btlane(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mbt "$SCP_EVQ" "$F/radio-pair.json" "$SCP_LQ" 390 844; [ "$(scp_j btlane "$(scp_ev "$SCP_T-mbt.json")")" != ok ] || SCP_MB="$SCP_MB btlane"; }
# ticks that touch
scp_mut ticks 's/if (t\[0\] - w < lx + 3) continue; //' || SCP_MB="$SCP_MB ticks(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mticks "$SCP_EVK" "$F/devices.json" "$SCP_Q" 320 568; [ "$(scp_j ticks "$(scp_ev "$SCP_T-mticks.json")")" != ok ] || SCP_MB="$SCP_MB ticks"; }
# a lane too narrow to nudge in: the nudge turns over and puts a point outside its lane
scp_mut nudge 's/ \&\& l.k1 - l.k0 > 2 \* f \/ t//' || SCP_MB="$SCP_MB nudge(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mnudge "$SCP_EVC" "$F/devices.json" "$SCP_Q" 320 568; [ "$(scp_j nudge "$(scp_ev "$SCP_T-mnudge.json")")" != ok ] || SCP_MB="$SCP_MB nudge"; }
# a legend row of a kind the legend check does not know, and one that never shows
scp_mut legendkind 's/data-kind="scope" hidden/data-kind="scopx" hidden/' || SCP_MB="$SCP_MB legendkind(no copy)"
[ -z "$SCP_MP" ] || { SCP_HK=$H; H=$SCP_MP; runq "$F/many-clients.json" "?intro=0&poll=0&spin=0&fixed=$STARCHORUS_FIXED&debug=1" "$SCP_T-mlegk" --fps 0 --wait 3 --ready "$SCP_RDY" --eval "$(cat "$R/tools/evals/legend-truth.js")" >/dev/null 2>&1; H=$SCP_HK; [ "$(evalv "$SCP_T-mlegk.json" 1)" != "[]" ] || SCP_MB="$SCP_MB legendkind"; }
scp_mut legendrow 's/ vis("leg-scope", scopeOn);//' || SCP_MB="$SCP_MB legendrow(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mlegr "$SCP_EVY" "$F/devices.json" "$SCP_Q" 390 844; [ "$(scp_j legend "$(scp_ev "$SCP_T-mlegr.json")")" != ok ] || SCP_MB="$SCP_MB legendrow"; }
# a folded ESS member that a tap in the Scope skips again, and the count badge drawn in the Scope again
scp_mut essnode 's/n.target !== 1 || (isEssFolded(n.id) \&\& !scopeOn)) return; near/n.target !== 1 || isEssFolded(n.id)) return; near/' || SCP_MB="$SCP_MB essnode(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run messn "$SCP_EVE" "$F/devices.json" "$SCP_LQ" 390 844; [ "$(scp_j ess "$(scp_ev "$SCP_T-messn.json")")" != ok ] || SCP_MB="$SCP_MB essnode"; }
scp_mut essbadge 's/ap.alphaDraw > 0.05 \&\& !scopeOn) {/ap.alphaDraw > 0.05) {/' || SCP_MB="$SCP_MB essbadge(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run messb "$SCP_EVE" "$F/devices.json" "$SCP_LQ" 390 844; [ "$(scp_j ess "$(scp_ev "$SCP_T-messb.json")")" != ok ] || SCP_MB="$SCP_MB essbadge"; }
# the strip's classes changed without the geometry following (renderScope as it was: a resize only when the feed's liveness changes)
scp_mut stripgeom 's/if (ls !== SC.lv || cs.value !== c0) { SC.lv = ls; resize(); }/if (ls !== SC.lv) { SC.lv = ls; resize(); }/' || SCP_MB="$SCP_MB stripgeom(no copy)"
[ -z "$SCP_MP" ] || { scp_mutrun scp_run mstripg "$SCP_EVH" "$F/devices.json" "$SCP_Q" 390 844; [ "$(scp_j stripgeom "$(scp_ev "$SCP_T-mstripg.json")")" != ok ] || SCP_MB="$SCP_MB stripgeom"; }
rowif "scope probes bite: an outward arc, a frame every tick, a radius of signal + 3, the bands ignored, no key Z, no snow, a caption that says ahead, a POST in the Scope, the lamps loop over every .lamps, no fitting of the strip, the 3D ring labels, the phosphor fade on idle frames, a note that never shows, a fifth lane that overflows, touching ticks, a nudge that turns over in a narrow lane, a legend row of an unknown kind or that never shows, a folded ESS member a tap skips, the count badge drawn in the Scope, a strip whose change of form leaves the fan where it was each turn their row red (mutants that did not:${SCP_MB:- none})" [ -z "$SCP_MB" ]
