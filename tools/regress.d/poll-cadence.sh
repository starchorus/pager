# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/poll-cadence.sh -- D3 in time: the stale threshold from center.interval, the self-scheduling poll, the
# replay banner (captures, not polls) and the time axis (the observed capture spacing).
# GUARDS AGAINST: a chip that goes stale on the old 6-poll count when the collector announces a slower cadence (the payload's
#                 30 s); the four liveness widgets drifting apart; a fixed 5 s poll; a failed poll counted as a stale tick;
#                 the replay banner counting polls; a time axis drawn at the announced interval instead of the real spacing; a document
#                 that switches the stale limit off or stretches the wait past a timer (an interval of 3000000, captures 10^7 s
#                 apart); a fault after the request that ends the polling for good; a Pager that cannot be reached (a dropped
#                 connection, HTTP 500) called 'Stale' as if its capture were old, or a Pager that answers with an old capture
#                 called 'Offline'; an outage that begins while the capture is ageing read 'Stale' for the rest of the threshold
#                 (the rule counts unanswered polls, not silent time); an answer after an outage, or one that is no document, that leaves the page 'Offline'; a
#                 source line that says 'Live from' while the Pager cannot be reached; a status other than 200 (204) taken for an answer.
# NEGATIVE PROBE: the expected waits and flip times come from a second statement of the rules (Python, below), not from the
#                 page; a page copy with the stale threshold back on the plain six ticks must be red (standing row), and so must
#                 one without the two caps and one without the guards after the request; four page copies without the offline
#                 distinction (never offline, always offline when stale, an answer that does not end the outage, one that
#                 is no document and counts as silence, a 204 that counts as an answer) must each be red.
# NOT PROVEN:     the cadence against a real collector (a scripted server answers by request count, not by time), timer
#                 behaviour in a background tab, any browser but Chrome.
# Headless time control: cdp.py --virtual-time holds the page clock from before the navigation; vtime:MS steps move it (timers
# fire in order, a pending fetch holds the clock), so a 135 s threshold takes a second. The server is a stand-in written here:
# the k-th starchorus.json request gets the k-th entry of a script (a `generated` value, x = an HTTP 500, n = an HTTP 204,
# d = the connection dropped without an answer, j = a 200 whose body is no document), the last repeats.
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only CAD_* globals and cad_* functions are set.

CAD_D="out/$P-cad"; mkdir -p "$CAD_D"
cp "$H" "$CAD_D/index.html"
cat > "$CAD_D/srv.py" <<'PY'
import sys, json, socket, http.server, socketserver, functools
port, root, script, iv, log = int(sys.argv[1]), sys.argv[2], sys.argv[3].split(","), sys.argv[4], sys.argv[5]
n = [0]
class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        if self.path.split("?")[0] != "/starchorus.json":
            return http.server.SimpleHTTPRequestHandler.do_GET(self)
        k = n[0]; n[0] += 1; g = script[min(k, len(script) - 1)]
        with open(log, "a") as f: f.write("%d %s\n" % (k, g))
        if g == "x":
            self.send_error(500); return
        if g == "n":
            self.send_response(204); self.end_headers(); return
        if g == "d":
            self.close_connection = True; self.connection.shutdown(socket.SHUT_RDWR); return
        if g == "j":
            b = b"no document"; self.send_response(200); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b); return
        doc = {"source": "recon-db", "generated": int(g), "center": {"label": "This device"}, "unassociated": [],
               "aps": [{"bssid": "02:00:00:00:0f:01", "ssid": "c", "band": "2.4", "channel": 6, "rssi": -50}]}
        if iv != "-": doc["center"]["interval"] = int(iv)
        b = json.dumps(doc).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json"); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
class S(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True
S(("127.0.0.1", port), functools.partial(H, directory=root)).serve_forever()
PY
# The rules, stated a second time: every poll from the boot poll on, its wait, the poll time without a new capture.
cat > "$CAD_D/model.py" <<'PY'
import sys, json
def run(script, iv, horizon):
    STEP, LEAD, PMS, GUESS, OFFP = 2000, 3000, 5000, 1.1, 3
    after = 1000 * max(30, 2 * iv + 15) if iv else 6 * PMS
    t = wait = since = stale = lost = 0; k = 0; gaps = []; last = None; lastold = live = False; out = []
    while t <= horizon:
        g = script[min(k, len(script) - 1)]; k += 1; ok = g not in ("x", "d", "j", "n"); fresh = False
        if ok:
            g = int(g)
            if last is not None and g > last: gaps = (gaps + [g - last])[-3:]
            fresh = last is None or g != last
            stale = 0 if fresh else stale + (wait if k > 1 else PMS); last = g; live = True; lost = 0
        elif live: stale += wait; lost = 0 if g == "j" else lost + 1   # an answer that is no document is an answer; the others are unanswered polls
        known = lastold and wait <= STEP; lastold = ok and not fresh; since = 0 if fresh else since + wait
        out.append({"t": t, "wait": wait, "ok": ok, "fresh": fresh, "stale": stale >= after, "off": stale >= after and lost >= OFFP})
        if not live: nxt = PMS
        elif fresh:
            s = sorted(gaps); n = len(s); sp = (s[n // 2] if n % 2 else (s[n // 2 - 1] + s[n // 2]) / 2) if n else None
            nxt = max(STEP, round(1000 * (sp if sp is not None else (GUESS * iv if iv else PMS / 1000)) - LEAD)) if (known or sp is None) else STEP
        else: nxt = STEP if since < after else PMS
        wait = nxt; t += nxt
    return out, after
script, iv, horizon, what = sys.argv[1].split(","), (int(sys.argv[2]) if sys.argv[2] != "-" else None), int(sys.argv[3]), sys.argv[4]
polls, after = run(script, iv, horizon)
if what == "flip":   # the virtual time of the poll that turns the chip stale
    print(next(p["t"] for p in polls if p["stale"]))
elif what == "off":  # … turns offline (stale, and the last OFFP polls got no answer)
    print(next(p["t"] for p in polls if p["off"]))
elif what[:2] == "at":   # the virtual time of request N (0-based)
    print(polls[int(what[2:])]["t"])
else:                # the waits of the scheduled polls (the boot poll has none) and the requests the server sees
    print(json.dumps([p["wait"] for p in polls[1:]], separators=(",", ":")) + " " + str(len(polls)))
PY
cad_run() {   # cad_run NAME SCRIPT INTERVAL QUERY [cdp args...] -> $CAD_D/NAME.json (cdp report) and NAME.log (the polls answered)
  CAD_N=$1; CAD_S=$2; CAD_I=$3; CAD_Q=$4; shift 4
  rm -f "$CAD_D/$CAD_N.log"; : > "$CAD_D/$CAD_N.log"
  CAD_PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])')
  python3 "$CAD_D/srv.py" "$CAD_PORT" "$CAD_D" "$CAD_S" "$CAD_I" "$CAD_D/$CAD_N.log" >/dev/null 2>&1 & CAD_PID=$!
  CAD_K=0; until python3 -c 'import sys,urllib.request;urllib.request.urlopen(sys.argv[1],timeout=1)' "http://127.0.0.1:$CAD_PORT/" >/dev/null 2>&1; do
    CAD_K=$((CAD_K + 1)); [ "$CAD_K" -ge 25 ] && break; sleep 0.2; done
  python3 tools/cdp.py "http://127.0.0.1:$CAD_PORT/$CAD_Q" --virtual-time --wait 0.3 --fps 0 --json "$@" > "$CAD_D/$CAD_N.json" 2>/dev/null
  kill "$CAD_PID" 2>/dev/null; wait "$CAD_PID" 2>/dev/null
}
# the liveness widgets in one line: chip, its title, masthead dot, source badge (WarGames), lamps frozen, panels pill, captureStale
CAD_W='(()=>{const c=document.getElementById("mode-chip"),d=document.querySelector("#masthead .brand .dot"),b=STARCHORUS.badge(),p=STARCHORUS.pollPlan();return [c.textContent,c.title||"-",d.dataset.live,b.kind,STARCHORUS.lamps().frozen,document.getElementById("pill-chip").textContent,STARCHORUS.stats().captureStale,p.staleAfterS,Math.round(performance.now())].join("|")})()'

# ---- stale threshold = max(30 s, 2 × interval + 15 s) of poll time; without center.interval the six 5 s ticks (30 s) as before
CAD_BAD=""
for CAD_IV in - 5 30 60; do
  CAD_F=$(python3 "$CAD_D/model.py" 1000 "$CAD_IV" 400000 flip)
  CAD_A=$((CAD_F - 500)); CAD_B=$((CAD_F + 500))
  cad_run "st-$CAD_IV" 1000 "$CAD_IV" "?intro=0&spin=0&theme=wargames" --step "vtime:$CAD_A" --step "eval:$CAD_W" --step vtime:1000 --step "eval:$CAD_W"
  CAD_L=$(evalv "$CAD_D/st-$CAD_IV.json" 1); CAD_S=$(evalv "$CAD_D/st-$CAD_IV.json" 2)
  CAD_T=$(python3 -c 'import sys;v=sys.argv[1];print(30 if v=="-" else max(30,2*int(v)+15))' "$CAD_IV")
  case $CAD_L in "Live|-|live|live|false|Live|false|$CAD_T|$CAD_A") ;; *) CAD_BAD="$CAD_BAD $CAD_IV:live[$CAD_L]" ;; esac
  case $CAD_S in "Stale|no new capture for "*" polls|stale|stale|true|Stale|true|$CAD_T|$CAD_B") ;; *) CAD_BAD="$CAD_BAD $CAD_IV:stale[$CAD_S]" ;; esac
done
rowif "D3 stale after max(30 s, 2 × interval + 15 s): interval none/5/30/60 → 30/30/75/135 s, chip + title, dot, badge, lamps, pill flip together (virtual time)" [ -z "$CAD_BAD" ]
[ -z "$CAD_BAD" ] || echo "    got:$CAD_BAD"

# the probe bites: a page copy whose threshold is the plain six POLL_MS ticks again goes stale at 30 s with interval 30
sed 's/^function staleAfterMs() {.*/function staleAfterMs() { return STALE_POLLS * POLL_MS; }/' "$H" > "$CAD_D/index.html"
CAD_NB=$(grep -c '^function staleAfterMs() { return STALE_POLLS \* POLL_MS; }$' "$CAD_D/index.html")
cad_run neg 1000 30 "?intro=0&spin=0&theme=wargames" --step vtime:40000 --step "eval:$CAD_W"
CAD_NV=$(evalv "$CAD_D/neg.json" 1)
cp "$H" "$CAD_D/index.html"
rowif "D3 stale probe bites: the six-tick threshold on an announced 30 s interval is stale at 40 s (mutation $CAD_NB) [${CAD_NV%%|*}]" [ "$CAD_NB/${CAD_NV%%|*}" = 1/Stale ]

# ---- offline: a Pager that does not answer (dropped connection, HTTP 500) is 'Offline', not 'Stale', once the capture is stale and
# the last three polls got no answer: the capture is not known to be old, the page has heard nothing. A server that answers with the
# old capture stays 'Stale', and so does the page when the server comes back with it. Interval 30 → stale at 75 s, and by then far more
# than three polls have gone unanswered, so the chip goes from Live to Offline. The script: three captures, 40 dead requests, then the server
# is back (a new capture, or the old one); the model gives the poll that turns the chip (request 40) and the one that is answered
# (request 43). The `generated` values are real times: 11:47 UTC is the last capture before the outage.
CAD_G0=1789300000
CAD_DEAD=$(printf ',d%.0s' $(seq 1 40))
CAD_O1="$CAD_G0,$((CAD_G0 + 30)),$((CAD_G0 + 60))$CAD_DEAD,$((CAD_G0 + 200))"   # … back with a new capture
CAD_O2="$CAD_G0,$((CAD_G0 + 30)),$((CAD_G0 + 60))$CAD_DEAD,$((CAD_G0 + 60))"    # … back with the capture it had
CAD_OF=$(python3 "$CAD_D/model.py" "$CAD_O1" 30 400000 off); CAD_OB=$(python3 "$CAD_D/model.py" "$CAD_O1" 30 400000 at43)
CAD_SF=$(python3 "$CAD_D/model.py" "$CAD_G0" 30 400000 flip)
CAD_QO="?intro=0&spin=0&debug=1&theme=wargames"
# chip, its class and title, dot, badge kind and text, captureStale, captureOffline, pill chip and aria-label, page time
CAD_WO='(()=>{const c=document.getElementById("mode-chip"),d=document.querySelector("#masthead .brand .dot"),b=STARCHORUS.badge(),s=STARCHORUS.stats();return [c.textContent,c.className,c.title||"-",d.dataset.live,b.kind,b.text,s.captureStale,s.captureOffline,document.getElementById("pill-chip").textContent,document.getElementById("panels-pill").getAttribute("aria-label"),Math.round(performance.now())].join("|")})()'
# the words: the chip as rendered in each theme, and the copy table's chip and badge word
CAD_TH='(()=>{const T=STARCHORUS._internals.THEMES,o=["foundation","wargames","whitehall"].map(t=>{STARCHORUS.setTheme(t);return document.getElementById("mode-chip").textContent+"/"+T[t].copy.chip.offline+"/"+T[t].copy.badge.offline});STARCHORUS.setTheme("wargames");return o.join(" ")})()'
CAD_NOTE='The Pager could not be reached; the last capture was at 11:47 UTC.'
CAD_WS='document.getElementById("source-desc").textContent'   # the source line under the chip
cad_live() { printf 'Live|mode live|-|live|live|Live RX|false|false|Live|Show the panels · Live|%s' "$1"; }
cad_off() { printf 'Link down|mode offline stale|%s|stale|offline|Link down|true|true|Link down|Show the panels · Link down · %s|%s' "$CAD_NOTE" "$CAD_NOTE" "$1"; }
cad_stale_ok() { case $1 in "Stale|mode stale|no new capture for "*" polls|stale|stale|Stale|true|false|Stale|Show the panels · Stale · no new capture for "*" polls|$2") return 0 ;; esac; return 1; }
CAD_A=$((CAD_OF - 500)); CAD_B=$((CAD_OF + 500)); CAD_R=$((CAD_OB + 500))
cad_run off1 "$CAD_O1" 30 "$CAD_QO" --step "vtime:$CAD_A" --step "eval:$CAD_WO" --step vtime:1000 --step "eval:$CAD_WO" --step "eval:$CAD_TH" --step "vtime:$((CAD_OB - CAD_OF))" --step "eval:$CAD_WO"
CAD_X1=$(evalv "$CAD_D/off1.json" 1); CAD_X2=$(evalv "$CAD_D/off1.json" 2); CAD_X3=$(evalv "$CAD_D/off1.json" 3); CAD_X4=$(evalv "$CAD_D/off1.json" 4)
rowif "D3 offline: a Pager that answers nothing is 'Link down' from the stale threshold (75 s) on, in chip (class stale), title, dot (as stale), badge, pill and its aria-label; before that Live, never Stale; a new capture from the server → Live again (virtual time $CAD_A, $CAD_B, $CAD_R)" \
  [ "$CAD_X1/$CAD_X2/$CAD_X4" = "$(cad_live "$CAD_A")/$(cad_off "$CAD_B")/$(cad_live "$CAD_R")" ]
[ "$CAD_X1/$CAD_X2/$CAD_X4" = "$(cad_live "$CAD_A")/$(cad_off "$CAD_B")/$(cad_live "$CAD_R")" ] || echo "    got: $CAD_X1  $CAD_X2  $CAD_X4"
rowif "D3 offline words: Foundation 'Offline', WarGames 'Link down', Whitehall 'No link', in the chip and in the badge's copy [$CAD_X3]" \
  [ "$CAD_X3" = "Offline/Offline/Offline Link down/Link down/Link down No link/No link/No link" ]

# HTTP 500 is silence too; a 200 with no document is not. The page is told 5 s and gets captures 60 s apart, so the poll that meets the
# broken document comes 57 s after the last capture, past the 30 s limit: stale at once (the server answered, it is the capture that is
# missing), where counting that poll's wait as silence would read 'Link down'.
CAD_O5=$(printf '%s' "$CAD_O1" | sed 's/,d/,x/g')
# The no-document answer is followed by dead polls (the last entry repeats): it does not count as one of them, so 'Link down' comes at the
# third dead poll (request 6, from the model), and the page still reads Stale one poll before that; the probe (d) below counts it and is a poll early.
CAD_O6="$CAD_G0,$CAD_G0,$((CAD_G0 + 60)),j,d"
CAD_JF=$(python3 "$CAD_D/model.py" "$CAD_O6" 5 400000 flip); CAD_J5=$(( $(python3 "$CAD_D/model.py" "$CAD_O6" 5 400000 at5) + 500 )); CAD_J6=$(( $(python3 "$CAD_D/model.py" "$CAD_O6" 5 400000 off) + 500 ))
cad_run off5 "$CAD_O5" 30 "$CAD_QO" --step "vtime:$CAD_B" --step "eval:$CAD_WO" --step "eval:$CAD_WS"
cad_run off6 "$CAD_O6" 5 "$CAD_QO" --step "vtime:$((CAD_JF + 500))" --step "eval:$CAD_WO" --step "vtime:$((CAD_J5 - CAD_JF - 500))" --step "eval:$CAD_WO" --step "vtime:$((CAD_J6 - CAD_J5))" --step "eval:$CAD_WO"
CAD_V1=$(evalv "$CAD_D/off5.json" 1); CAD_V2=$(evalv "$CAD_D/off6.json" 1); CAD_V5=$(evalv "$CAD_D/off6.json" 2); CAD_V6=$(evalv "$CAD_D/off6.json" 3)
CAD_VJ="$(cad_stale_ok "$CAD_V2" "$((CAD_JF + 500))" && echo stale)/$(cad_stale_ok "$CAD_V5" "$CAD_J5" && echo stale)/$([ "$CAD_V6" = "$(cad_off "$CAD_J6")" ] && echo off)/$([ "$((CAD_J6 - CAD_J5))" = 5000 ] && echo onepoll)"
rowif "D3 offline: HTTP 500 counts as silence like a dropped connection ('Link down' at $CAD_B); a 200 with no document is an answer, not silence: Stale at $((CAD_JF + 500)), still Stale after two dead polls ($CAD_J5), 'Link down' at the third ($CAD_J6) [$CAD_VJ]" \
  [ "$CAD_V1/$CAD_VJ" = "$(cad_off "$CAD_B")/stale/stale/off/onepoll" ]
[ "$CAD_V1" = "$(cad_off "$CAD_B")" ] || echo "    got: $CAD_V1"
[ "$CAD_VJ" = stale/stale/off/onepoll ] || echo "    got: $CAD_V2  $CAD_V5  $CAD_V6"

# any status but 200 is silence: a 204 (no content) from a server that is up reads 'Link down' like the dropped connection and the 500
CAD_O8=$(printf '%s' "$CAD_O1" | sed 's/,d/,n/g')
cad_run off8 "$CAD_O8" 30 "$CAD_QO" --step "vtime:$CAD_B" --step "eval:$CAD_WO"
CAD_N1=$(evalv "$CAD_D/off8.json" 1)
rowif "D3 offline: an HTTP 204 counts as silence (any status but 200): 'Link down' at $CAD_B [${CAD_N1%%|*}]" [ "$CAD_N1" = "$(cad_off "$CAD_B")" ]
[ "$CAD_N1" = "$(cad_off "$CAD_B")" ] || echo "    got: $CAD_N1"

# a server that answers: the old capture is Stale (not Offline) from the same threshold on, with the title of before
cad_run off2 "$CAD_G0" 30 "$CAD_QO" --step "vtime:$((CAD_SF - 500))" --step "eval:$CAD_WO" --step vtime:1000 --step "eval:$CAD_WO" --step "eval:$CAD_WS"
CAD_Y1=$(evalv "$CAD_D/off2.json" 1); CAD_Y2=$(evalv "$CAD_D/off2.json" 2); CAD_Y3=$(evalv "$CAD_D/off2.json" 3)
rowif "D3 an answering server with an old capture is Stale, not offline: Live at $((CAD_SF - 500)), Stale at $((CAD_SF + 500)) (captureOffline false)" \
  [ "$(cad_stale_ok "$CAD_Y2" "$((CAD_SF + 500))" && echo ok)/$CAD_Y1" = "ok/$(cad_live "$((CAD_SF - 500))")" ]
[ "$(cad_stale_ok "$CAD_Y2" "$((CAD_SF + 500))" && echo ok)" = ok ] || echo "    got: $CAD_Y1  $CAD_Y2"

# the source line is the one place a phone shows more than the chip's word: it must not say 'Live from' while the Pager cannot be
# reached (the capture is the last one, not a live one), and still says it while the server answers with an old capture
CAD_V3=$(evalv "$CAD_D/off5.json" 2)
rowif "D3 the source line: 'Last capture from starchorus.json · 11:47:40' while the Pager cannot be reached, 'Live from starchorus.json · 11:46:40' while it answers with an old capture (stale)" \
  [ "$CAD_V3/$CAD_Y3" = "Last capture from starchorus.json · 11:47:40/Live from starchorus.json · 11:46:40" ]
[ "$CAD_V3/$CAD_Y3" = "Last capture from starchorus.json · 11:47:40/Live from starchorus.json · 11:46:40" ] || echo "    got: $CAD_V3  $CAD_Y3"

# an outage that begins while the capture is already ageing (ten answers with the old capture first, about 20 s of poll time): by the
# stale threshold more than three polls have gone unanswered, so the chip goes from Live straight to 'Link down', with no Stale phase
# (the rule counts unanswered polls; counting silent time from the last answer would read Stale here for most of a minute).
CAD_OLD=""; for CAD_I in 1 2 3 4 5 6 7 8 9 10; do CAD_OLD="$CAD_OLD,$((CAD_G0 + 60))"; done
CAD_O7="$CAD_G0,$((CAD_G0 + 30)),$((CAD_G0 + 60))$CAD_OLD$CAD_DEAD"
CAD_E7=$(python3 "$CAD_D/model.py" "$CAD_O7" 30 400000 flip); CAD_F7=$(python3 "$CAD_D/model.py" "$CAD_O7" 30 400000 off)
cad_run off7 "$CAD_O7" 30 "$CAD_QO" --step "vtime:$((CAD_E7 - 500))" --step "eval:$CAD_WO" --step vtime:1000 --step "eval:$CAD_WO"
CAD_W1=$(evalv "$CAD_D/off7.json" 1); CAD_W2=$(evalv "$CAD_D/off7.json" 2)
CAD_W7="$([ "$CAD_F7" = "$CAD_E7" ] && echo same)/$([ "$CAD_W1" = "$(cad_live "$((CAD_E7 - 500))")" ] && echo live)/$([ "$CAD_W2" = "$(cad_off "$((CAD_E7 + 500))")" ] && echo off)"
rowif "D3 offline after an old capture: Live at $((CAD_E7 - 500)), 'Link down' at $((CAD_E7 + 500)) with no Stale in between (the model's stale and offline polls are one, $CAD_E7) [$CAD_W7]" \
  [ "$CAD_W7" = same/live/off ]
[ "$CAD_W7" = same/live/off ] || echo "    got: $CAD_W1  $CAD_W2"
# … and the one case that still reads Stale first: the outage begins at the poll that turns the chip stale. After the third capture the
# page asks every 2 s (37 answers with the old capture take it to the poll before the threshold), so the stale poll is the first
# unanswered one: Stale with one and with two unanswered polls (the stale cadence is 5 s), 'Link down' at the third, 10 s after the flip.
# The steps are fixed 5 s (a negative or zero virtual-time step would hang cdp.py); the model's own off − flip = 10 s is a check of the row.
CAD_OLD=""; for CAD_I in $(seq 1 37); do CAD_OLD="$CAD_OLD,$((CAD_G0 + 60))"; done
CAD_O9="$CAD_G0,$((CAD_G0 + 30)),$((CAD_G0 + 60))$CAD_OLD$CAD_DEAD"
CAD_E9=$(python3 "$CAD_D/model.py" "$CAD_O9" 30 400000 flip); CAD_F9=$(python3 "$CAD_D/model.py" "$CAD_O9" 30 400000 off)
cad_run off9 "$CAD_O9" 30 "$CAD_QO" --step "vtime:$((CAD_E9 + 500))" --step "eval:$CAD_WO" --step vtime:5000 --step "eval:$CAD_WO" --step vtime:5000 --step "eval:$CAD_WO"
CAD_U1=$(evalv "$CAD_D/off9.json" 1); CAD_U2=$(evalv "$CAD_D/off9.json" 2); CAD_U3=$(evalv "$CAD_D/off9.json" 3)
CAD_U9="$([ "$((CAD_F9 - CAD_E9))" = 10000 ] && echo twopolls)/$(cad_stale_ok "$CAD_U1" "$((CAD_E9 + 500))" && echo stale)/$(cad_stale_ok "$CAD_U2" "$((CAD_E9 + 5500))" && echo stale)/$([ "$CAD_U3" = "$(cad_off "$((CAD_E9 + 10500))")" ] && echo off)"
rowif "D3 an outage that begins at the stale poll: Stale at $((CAD_E9 + 500)) and $((CAD_E9 + 5500)) (one and two unanswered polls), 'Link down' at $((CAD_E9 + 10500)) (the third; model off − flip = $((CAD_F9 - CAD_E9)) ms), two polls of Stale at most [$CAD_U9]" \
  [ "$CAD_U9" = twopolls/stale/stale/off ]
[ "$CAD_U9" = twopolls/stale/stale/off ] || echo "    got: $CAD_U1  $CAD_U2  $CAD_U3"

# … and after an outage the old capture, answered, ends the outage: Offline until then, Stale (not Live, not Offline) after
cad_run off3 "$CAD_O2" 30 "$CAD_QO" --step "vtime:$CAD_B" --step "eval:$CAD_WO" --step "vtime:$((CAD_OB - CAD_OF))" --step "eval:$CAD_WO"
CAD_Z1=$(evalv "$CAD_D/off3.json" 1); CAD_Z2=$(evalv "$CAD_D/off3.json" 2)
rowif "D3 the server back with the old capture: Offline until it answers, then Stale (not Live, not Offline) [${CAD_Z2%%|*}]" \
  [ "$CAD_Z1/$(cad_stale_ok "$CAD_Z2" "$CAD_R" && echo ok)" = "$(cad_off "$CAD_B")/ok" ]
[ "$(cad_stale_ok "$CAD_Z2" "$CAD_R" && echo ok)" = ok ] || echo "    got: $CAD_Z1  $CAD_Z2"

# a Pager that never answered leaves the sample sky alone: demo is no live feed, so nothing is stale or offline
cad_run off4 d - "$CAD_QO" --step vtime:200000 --step "eval:$CAD_WO"
CAD_D1=$(evalv "$CAD_D/off4.json" 1)
rowif "D3 a Pager that never answered changes nothing: Sample, not stale, not offline, 200 s on [$CAD_D1]" \
  [ "$CAD_D1" = "Sample|mode demo|-|off|demo|Simulation|false|false|Sample|Show the panels · Sample|200000" ]

# the probes bite: (a) never offline → the dead server reads Stale (the field fault); (b) every stale feed offline → the answering server
# reads Link down; (c) an answer that does not end the outage → the old capture, answered, still reads Link down; (d) a 200 that is no
# document counted as silence → reads Link down a poll early (at $CAD_J5, where the page reads Stale); (e) any 2xx taken for an answer → the 204 server reads Stale
cad_probe() {   # cad_probe 'sed script' PATTERN -> the page copy in $CAD_D/index.html, $CAD_PN = the lines that now read PATTERN
  sed "$1" "$H" > "$CAD_D/index.html"; CAD_PN=$(grep -c "$2" "$CAD_D/index.html")
}
cad_probe 's/^function captureOffline() {.*/function captureOffline() { return false; }/' '^function captureOffline() { return false; }$'
cad_run offa "$CAD_O1" 30 "$CAD_QO" --step "vtime:$CAD_B" --step "eval:$CAD_WO"
CAD_PA=$(evalv "$CAD_D/offa.json" 1); CAD_MA=$CAD_PN
cad_probe 's/^function captureOffline() {.*/function captureOffline() { return captureStale(); }/' '^function captureOffline() { return captureStale(); }$'
cad_run offb "$CAD_G0" 30 "$CAD_QO" --step "vtime:$((CAD_SF + 500))" --step "eval:$CAD_WO"
CAD_PB=$(evalv "$CAD_D/offb.json" 1); CAD_MB=$CAD_PN
cad_probe 's/heard = true; S.lostPolls = 0; return r.json();/heard = true; return r.json();/' 'heard = true; return r.json();'
cad_run offc "$CAD_O2" 30 "$CAD_QO" --step "vtime:$CAD_R" --step "eval:$CAD_WO"
CAD_PC=$(evalv "$CAD_D/offc.json" 1); CAD_MC=$CAD_PN
cad_probe 's/heard = true; S.lostPolls = 0; return r.json();/S.lostPolls = 0; return r.json();/' 'S.lostPolls = 0; return r.json();'
cad_run offd "$CAD_O6" 5 "$CAD_QO" --step "vtime:$CAD_J5" --step "eval:$CAD_WO"
CAD_PD=$(evalv "$CAD_D/offd.json" 1); CAD_MD=$CAD_PN
cad_probe 's/if (r.status !== 200) return Promise.reject(r.status);/if (!r.ok) return Promise.reject(r.status);/' 'if (!r.ok) return Promise.reject(r.status);'
cad_run offe "$CAD_O8" 30 "$CAD_QO" --step "vtime:$CAD_B" --step "eval:$CAD_WO"
CAD_PE=$(evalv "$CAD_D/offe.json" 1); CAD_ME=$CAD_PN
cp "$H" "$CAD_D/index.html"
rowif "D3 offline probes bite: never offline → the dead Pager reads '${CAD_PA%%|*}' (mutation $CAD_MA); always offline when stale → the answering one reads '${CAD_PB%%|*}' (mutation $CAD_MB); answers that do not end the outage → '${CAD_PC%%|*}' (mutation $CAD_MC); an answer that is no document taken for silence → '${CAD_PD%%|*}' (mutation $CAD_MD); any 2xx taken for an answer → '${CAD_PE%%|*}' (mutation $CAD_ME)" \
  [ "$CAD_MA/${CAD_PA%%|*} $CAD_MB/${CAD_PB%%|*} $CAD_MC/${CAD_PC%%|*} $CAD_MD/${CAD_PD%%|*} $CAD_ME/${CAD_PE%%|*}" = "1/Stale 1/Link down 1/Link down 1/Link down 1/Stale" ]

# ---- cadence: the waits the page scheduled = the model's, for a script with a known phase, a late capture, a failed poll,
# a missed capture (the median keeps the spacing) and an end (2 s steps until the threshold, then POLL_MS); interval 30
CAD_SC=1000,1000,1030,1030,1060,1060,x,1060,1090,1150,1150,1150,1180,1180
CAD_M=$(python3 "$CAD_D/model.py" "$CAD_SC" 30 231000 waits)
cad_run cad "$CAD_SC" 30 "?intro=0&spin=0" --step vtime:231000 --step 'eval:JSON.stringify(STARCHORUS.pollPlan().log)'
CAD_G=$(evalv "$CAD_D/cad.json" 1)
CAD_GN=$(wc -l < "$CAD_D/cad.log" | tr -d ' ')
CAD_MW=$(python3 -c 'import json,sys;a=json.loads(sys.argv[1]);b=json.loads(sys.argv[2]);print("ok" if a==b[:len(a)] and len(a)>=40 else "differ")' "${CAD_G:-[]}" "${CAD_M% *}" 2>/dev/null)
rowif "D3 cadence: spacing − 3 s after a capture, 2 s steps to the next, first guess 1.1 × interval, median of 3 gaps, a failed poll retried at the next step, POLL_MS once stale; waits = model, requests $CAD_GN = ${CAD_M#* }" [ "$CAD_MW/$CAD_GN" = "ok/${CAD_M#* }" ]
[ "$CAD_MW" = ok ] || { echo "    page:  $(printf '%s' "$CAD_G" | cut -c1-300)"; echo "    model: $(printf '%s' "${CAD_M% *}" | cut -c1-300)"; }

# ---- a broken document cannot stretch the cadence. center.interval 3000000 is read as the 600 s cap: the stale limit is
# 2 × 600 + 15 = 1215 s (not 6000015 s) and the next poll is 597 s away (one request in 10 s). Capture times 10^7 s apart give
# a spacing that is capped the same way (uncapped the wait is past what a timer holds).
CAD_CAPJS='JSON.stringify([STARCHORUS.pollPlan().staleAfterS,STARCHORUS.pollPlan().nextMs])'
cad_run cap 1000 3000000 "?intro=0&spin=0" --step vtime:10000 --step "eval:$CAD_CAPJS"
CAD_C=$(evalv "$CAD_D/cap.json" 1); CAD_CN=$(wc -l < "$CAD_D/cap.log" | tr -d ' ')
cad_run spc 1000,1000,10001000,10001000,20001000,20001000,30001000,30001000 - "?intro=0&spin=0" --step vtime:10000 --step "eval:$CAD_CAPJS"
CAD_S2=$(evalv "$CAD_D/spc.json" 1); CAD_SN=$(wc -l < "$CAD_D/spc.log" | tr -d ' ')
python3 - "$H" "$CAD_D/index.html" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
a = "S.pollIntervalS = doc.center.interval && Math.min(doc.center.interval, POLL.maxIntervalS);"
b = "Math.min(s ?? (S.pollIntervalS > 0 ? POLL.guessMul * S.pollIntervalS : POLL_MS / 1000), POLL.maxIntervalS)"
assert s.count(a) == 1 and s.count(b) == 1
open(sys.argv[2], "w", encoding="utf-8").write(s.replace(a, "S.pollIntervalS = doc.center.interval;").replace(b, "(s ?? (S.pollIntervalS > 0 ? POLL.guessMul * S.pollIntervalS : POLL_MS / 1000))"))
PY
cad_run capneg 1000 3000000 "?intro=0&spin=0" --step vtime:10000 --step "eval:$CAD_CAPJS"
CAD_CV=$(evalv "$CAD_D/capneg.json" 1)
cad_run spcneg 1000,1000,10001000,10001000,20001000,20001000,30001000,30001000 - "?intro=0&spin=0" --step vtime:10000 --step "eval:$CAD_CAPJS"
CAD_SV=$(evalv "$CAD_D/spcneg.json" 1)
cp "$H" "$CAD_D/index.html"
rowif "D3 interval cap: center.interval 3000000 → stale after 1215 s, next poll in 597 s, 1 request in 10 s [$CAD_C, $CAD_CN]" [ "$CAD_C/$CAD_CN" = "[1215,597000]/1" ]
rowif "D3 spacing cap: captures 10^7 s apart → the next poll in 597 s, 3 requests in 10 s [$CAD_S2, $CAD_SN]" [ "$CAD_S2/$CAD_SN" = "[30,597000]/3" ]
rowif "D3 cap probes bite: uncapped, the stale limit is 6000015 s and the wait 9999997000 ms, past what a timer holds [$CAD_CV $CAD_SV]" [ "${CAD_CV%%,*} $CAD_SV" = "[6000015 [30,9999997000]" ]

# ---- a fault after the request does not stop the poll. With #pill-chip removed every poll fails inside the page (setSourcePanel
# throws); the page still asks again at the next step (11 requests in 20.5 s of poll time) and reports the fault. The probe page,
# with both guards undone, stops after the poll that met the fault (the boot poll came before the removal).
CAD_EVF='JSON.stringify([STARCHORUS.errors().length>0,STARCHORUS.pollPlan().log.length>=8])'
cad_run flt 1000 - "?intro=0&spin=0" --step vtime:500 --step 'eval:document.getElementById("pill-chip").remove()' --step vtime:20000 --step "eval:$CAD_EVF"
CAD_FV=$(evalv "$CAD_D/flt.json" 2); CAD_FN=$(wc -l < "$CAD_D/flt.log" | tr -d ' ')
sed -e 's/guard(() => noteStalePoll(tick(), heard))/noteStalePoll(tick(), heard)/' -e 's/^    \.catch(e => { pushError(e); return { ok: false }; }).*$/    ;/' "$H" > "$CAD_D/index.html"
CAD_NB=$(cmp -s "$H" "$CAD_D/index.html" && echo 0 || echo 1)
cad_run fltneg 1000 - "?intro=0&spin=0" --step vtime:500 --step 'eval:document.getElementById("pill-chip").remove()' --step vtime:20000 --step "eval:$CAD_EVF"
CAD_FZ=$(wc -l < "$CAD_D/fltneg.log" | tr -d ' ')
cp "$H" "$CAD_D/index.html"
rowif "D3 a fault after the request is a failed poll: polling goes on ($CAD_FN requests in 20 s), the fault is reported [$CAD_FV]" [ "$CAD_FV/$([ "$CAD_FN" -ge 8 ] && echo many)" = "[true,true]/many" ]
rowif "D3 fault probe bites: without the guards the page stops after $CAD_FZ request(s) (mutation $CAD_NB)" [ "$CAD_NB/$([ "$CAD_FZ" -le 3 ] && echo few)" = "1/few" ]

# ---- the replay banner counts captures: seven polls of the capture on show add nothing, the next new one adds one
CAD_EVR='(()=>{const ap={bssid:"02:00:00:00:0e:01",ssid:"r",band:"2.4",channel:6,rssi:-50},mk=g=>({source:"recon-db",generated:g,aps:[ap],unassociated:[]}),live=d=>STARCHORUS.load(d,"rb",{mode:"live"}),sd=()=>document.getElementById("source-desc").textContent.split(" · ").filter((x,i)=>i!==1).join(" · ");for(let i=0;i<5;i++)live(mk(4000+30*i));STARCHORUS.replay(1);const o=[];for(let i=0;i<7;i++)live(mk(4120));o.push(STARCHORUS.replayInfo().buffered,sd());for(let i=0;i<4;i++)live(mk(4150));o.push(STARCHORUS.replayInfo().buffered,sd());live(mk(4180));o.push(STARCHORUS.replayInfo().buffered,sd());STARCHORUS.openDrawer("rec");o.push(/2 newer captures arrived and are kept/.test(document.getElementById("rec-body").textContent));STARCHORUS.replayExit();o.push(STARCHORUS.stats().generated);return o.join("|")})()'
# ---- the time axis uses the observed spacing: one capture → the announced interval, then the median gap (30 s) although 5 s is announced
CAD_EVT='(()=>{const ap={bssid:"02:00:00:00:0e:02",ssid:"t",band:"2.4",channel:6,rssi:-50},mk=(g,iv)=>({source:"recon-db",generated:g,center:iv?{label:"x",interval:iv}:{label:"x"},aps:[ap],unassociated:[]}),f=t=>[t.spacingFrom,t.intervalS,t.window].join(","),o=[];STARCHORUS.load(mk(5000),"tn",{mode:"live"});o.push(f(STARCHORUS.timeSeries("10m")));STARCHORUS.load(mk(6000,5),"ta",{mode:"live"});o.push(f(STARCHORUS.timeSeries("10m")));for(let i=1;i<4;i++)STARCHORUS.load(mk(6000+30*i,5),"ta",{mode:"live"});o.push(f(STARCHORUS.timeSeries("10m")));STARCHORUS.openDrawer("time");o.push(/\b20 samples at the observed 30 s spacing/.test(document.getElementById("time-body").textContent));return o.join("|")})()'
runq demo "?poll=0&spin=0&intro=0" "out/$P-cad-ui" --wait 1 --fps 0 --eval "$CAD_EVR" --eval "$CAD_EVT" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CAD_R=$(evalv "out/$P-cad-ui.json" 1); CAD_X=$(evalv "out/$P-cad-ui.json" 2); CAD_E=$(evalv "out/$P-cad-ui.json" 3)
rowif "replay banner counts captures: 7 polls of the shown capture → 0, a new one → 1 (singular), another → 2 [$CAD_R]" [ "$CAD_R/$CAD_E" = "0|Replay 2 of 5|1|Replay 2 of 6 · 1 newer capture kept|2|Replay 2 of 7 · 2 newer captures kept|true|4180/0" ]
rowif "time axis at the observed spacing: none → assumed 5 s, one capture → announced 5 s, then the median gap 30 s [$CAD_X]" [ "$CAD_X" = "assumed,5,120|announced,5,120|observed,30,20|true" ]
