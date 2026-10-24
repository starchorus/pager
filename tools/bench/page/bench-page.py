#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
bench-page.py -- what the page costs while it is open: frames drawn, per-function time, and CPU by Chrome process type.

WHAT IT MEASURES: serves a COPY of the page and one fixture on a local port, starts headless Chrome (--headless=new, a profile of its own) through
tools/cdp.py's classes, lets the page run for 6 s, then measures for SECONDS: the frames the page drew (STARCHORUS.measure, so the query needs
debug=1), the main thread's busy and script share, and the CPU of every Chrome process (ps, by --type=): renderer, gpu-process, browser, network
service. The result is one JSON line on stdout and in OUTDIR/results.jsonl. The page is never changed; options below change the state it is in.
HOW TO RUN:
  python3 -B -I tools/bench/page/bench-page.py OUTDIR ROOT FIXTURE|demo|blank "QUERY" WxH SCALE MOBILE SECONDS [option ...]
    ROOT     the repository (or a copy of it): tools/cdp.py is loaded from it and starchorus.html is the page unless page= names another
    FIXTURE  a capture such as ROOT/tests/fixtures/many-clients.json, or `demo`, or `blank` (an empty page: Chrome's own baseline)
    QUERY    e.g. "?poll=0&intro=0&debug=1" (add &scope=1 for the Scope on a phone viewport)
    WxH SCALE MOBILE   viewport, device scale factor, 1 = mobile emulation with touch (e.g. 1440x900 2 0, or 390x844 3 1)
    options  gpu (use the GPU path; the default is software compositing), hidden (a second tab in front: the page is hidden), pause (press Space
             first), instr (call window.__inst(): the page must be a make-instr.py copy, give it as page=), page=FILE (serve this page),
             dyn=N (the capture's generated moves every N seconds), evalpre=JS (run this in the page before measuring), label=NAME
  Needs python3, Google Chrome (found as tools/cdp.py finds it), ps. No device, no network (127.0.0.1 only), no radio.
  Example, the live dot's pulse smooth against stepped, in one run (see README.md): serve a copy with `steps(8)` replaced by `ease-in-out`.
WRITES ONLY under OUTDIR: results.jsonl, and a temporary www and Chrome profile that are removed again. ROOT is only read.
DETERMINISTIC: the frame counts (measure.renderedFrames and friends) and the request counts. NOISE: every CPU percentage and millisecond: +-15 to
25 percent with the machine shared, and a laptop's thermal state moves it. Use RATIOS between two rows of the same run (repeat each row, and
compare the means), never absolute figures across runs. Not part of any gate.
"""
import functools
import http.server
import importlib.util
import json
import os
import re
import shutil
import socketserver
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request

if len(sys.argv) < 9:
    sys.exit(__doc__)
out_dir, root, fixture, query, size, scale, mobile, secs = sys.argv[1:9]
opts = sys.argv[9:]
gpu = "gpu" in opts
hidden = "hidden" in opts


def opt(prefix, default=""):
    return next((o[len(prefix):] for o in opts if o.startswith(prefix)), default)


label = opt("label=")
page = opt("page=") or os.path.join(root, "starchorus.html")
dyn = int(opt("dyn=", "0"))
w, h = [int(v) for v in size.lower().split("x")]
secs = float(secs)
os.makedirs(out_dir, exist_ok=True)

spec = importlib.util.spec_from_file_location("cdp", os.path.join(root, "tools", "cdp.py"))
cdp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cdp)

tmp = tempfile.mkdtemp(prefix="bench-www-", dir=out_dir)
shutil.copy(page, os.path.join(tmp, "index.html"))
if fixture == "blank":
    open(os.path.join(tmp, "index.html"), "w").write("<!doctype html><title>b</title><body style='background:#000'>")
elif fixture != "demo":
    shutil.copy(fixture, os.path.join(tmp, "starchorus.json"))
reqs = []


class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        reqs.append((time.time(), self.path.split("?")[0]))
        if dyn and self.path.split("?")[0] == "/starchorus.json":
            d = json.load(open(os.path.join(tmp, "starchorus.json")))
            d["generated"] = int(time.time() // dyn * dyn) + 1000000000
            d.setdefault("center", {})["interval"] = dyn
            b = json.dumps(d).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(b)))
            self.end_headers()
            self.wfile.write(b)
            return
        return http.server.SimpleHTTPRequestHandler.do_GET(self)


class S(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


srv = S(("127.0.0.1", 0), functools.partial(H, directory=tmp))
port = srv.server_address[1]
threading.Thread(target=srv.serve_forever, daemon=True).start()

profile = tempfile.mkdtemp(prefix="bench-prof-", dir=out_dir)
flags = [cdp.find_chrome(), "--headless=new", "--no-first-run", "--no-default-browser-check", "--hide-scrollbars", "--mute-audio",
         "--disable-extensions", "--remote-debugging-port=0", "--remote-allow-origins=*", "--user-data-dir=" + profile,
         "--window-size=%d,%d" % (w, h), "about:blank"]
if not gpu:
    flags.insert(2, "--disable-gpu")
if not hidden:
    flags[3:3] = ["--disable-background-timer-throttling", "--disable-renderer-backgrounding"]
proc = subprocess.Popen(flags, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def cpu_by_type():
    out = subprocess.run(["ps", "-axo", "pid=,ppid=,cputime=,command="], capture_output=True, text=True).stdout
    res = {}
    for line in out.splitlines():
        if profile not in line:
            continue
        m = re.match(r"\s*(\d+)\s+(\d+)\s+([\d:.]+)\s+(.*)", line)
        if not m:
            continue
        secs_ = 0.0
        for p in m.group(3).split(":"):
            secs_ = secs_ * 60 + float(p)
        ty = re.search(r"--type=([a-z-]+)", m.group(4))
        ty = ty.group(1) if ty else "browser"
        if ty == "utility":
            sub = re.search(r"--utility-sub-type=([\w.]+)", m.group(4))
            ty = "utility:" + (sub.group(1).split(".")[-1] if sub else "?")
        res[ty] = res.get(ty, 0) + secs_
    return res


try:
    port_c = None
    for _ in range(200):
        try:
            with open(os.path.join(profile, "DevToolsActivePort")) as f:
                port_c = int(f.readline().strip())
                break
        except (OSError, ValueError):
            time.sleep(0.05)
    target = None
    for _ in range(100):
        try:
            lst = json.load(urllib.request.urlopen("http://127.0.0.1:%d/json/list" % port_c, timeout=2))
            pages = [t for t in lst if t.get("type") == "page"]
            if pages:
                target = pages[0]
                break
        except Exception:
            pass
        time.sleep(0.1)
    c = cdp.CDP(target["webSocketDebuggerUrl"])
    c.call("Emulation.setDeviceMetricsOverride", {"width": w, "height": h, "deviceScaleFactor": float(scale), "mobile": mobile == "1"})
    if mobile == "1":
        c.call("Emulation.setTouchEmulationEnabled", {"enabled": True, "maxTouchPoints": 5})
    for m in ("Runtime", "Page", "Performance"):
        c.call(m + ".enable")
    c.call("Page.navigate", {"url": "http://127.0.0.1:%d/%s" % (port, query)})
    c.pump(6.0)
    if hidden:
        # a second tab in front: the first one becomes hidden (a browser-level connection is needed for Target.*)
        ver = json.load(urllib.request.urlopen("http://127.0.0.1:%d/json/version" % port_c, timeout=2))
        b = cdp.CDP(ver["webSocketDebuggerUrl"])
        t2 = b.call("Target.createTarget", {"url": "about:blank"})["targetId"]
        b.call("Target.activateTarget", {"targetId": t2})
        c.pump(1.0)
    if "pause" in opts:
        for t_ in ("keyDown", "keyUp"):
            c.call("Input.dispatchKeyEvent", {"type": t_, "key": " ", "code": "Space", "text": " " if t_ == "keyDown" else ""})
        c.pump(1.5)
    vis = c.evaluate("document.visibilityState")
    inst_r = c.evaluate("window.__inst&&window.__inst()") if "instr" in opts else ""
    for o_ in opts:
        if o_.startswith("evalpre="):
            c.evaluate(o_[8:])
            c.pump(1.0)
    has_dbg = c.evaluate("typeof STARCHORUS!=='undefined' && typeof STARCHORUS.measure==='function'")

    def metrics():
        return {m["name"]: m["value"] for m in c.call("Performance.getMetrics")["metrics"]}

    m0 = metrics()
    p0 = cpu_by_type()
    t0 = time.time()
    r0 = len(reqs)
    if hidden:
        meas = {"hidden": True}
        c.pump(secs)
    else:
        meas = c.evaluate("STARCHORUS.measure(%s)" % secs, timeout=secs + 30) if has_dbg else None
    t1 = time.time()
    m1 = metrics()
    p1 = cpu_by_type()
    dt = t1 - t0
    b = c.evaluate("JSON.stringify(window.__b)")
    perf = c.evaluate("JSON.stringify(STARCHORUS.perf())") if has_dbg else None
    ui = c.evaluate("JSON.stringify((()=>{const I=STARCHORUS._internals;if(!I)return null;const S=I.S;return {aps:S.aps.size,clients:S.clients.size,view:S.ui.view,paused:S.ui.paused,spin:S.ui.spin,rotate:S.ui.rotate,lod:S.perf.lod,dpr:S.perf.dpr,dprStep:S.perf.dprStep,down:S.perf.down,capMs:S.perf.capMs,moving:S.moving}})())")
    out = {"label": label, "fixture": os.path.basename(fixture), "page": os.path.basename(page), "query": query, "size": size, "scale": scale,
           "mobile": mobile, "gpu": gpu, "visibility": vis, "seconds": round(dt, 2), "instrumented": inst_r, "measure": meas,
           "inpage": (json.loads(b) if isinstance(b, str) else None), "perf": (json.loads(perf) if isinstance(perf, str) else None),
           "ui": (json.loads(ui) if isinstance(ui, str) else None),
           "main_thread_busy_pct": round(100 * (m1["TaskDuration"] - m0["TaskDuration"]) / (m1["Timestamp"] - m0["Timestamp"]), 1),
           "script_pct": round(100 * (m1["ScriptDuration"] - m0["ScriptDuration"]) / (m1["Timestamp"] - m0["Timestamp"]), 1),
           "layout_ms": round(1000 * (m1["LayoutDuration"] - m0["LayoutDuration"]), 1),
           "style_ms": round(1000 * (m1["RecalcStyleDuration"] - m0["RecalcStyleDuration"]), 1),
           "cpu_pct_by_proc_type": {k: round(100 * (p1.get(k, 0) - p0.get(k, 0)) / dt, 1) for k in p1},
           "requests_in_window": len(reqs) - r0,
           "poll_times_s": [round(t - t0, 1) for t, pth in reqs if pth == "/starchorus.json" and t >= t0]}
    line = json.dumps(out)
    print(line)
    with open(os.path.join(out_dir, "results.jsonl"), "a") as f:
        f.write(line + "\n")
finally:
    proc.terminate()
    try:
        proc.wait(10)
    except Exception:
        proc.kill()
    srv.shutdown()
    shutil.rmtree(tmp, ignore_errors=True)
    shutil.rmtree(profile, ignore_errors=True)
