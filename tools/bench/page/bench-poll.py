#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
bench-poll.py -- what one poll costs the page: STARCHORUS.load() of a capture that is new, and of the same capture again.

WHAT IT MEASURES: on an instrumented COPY of the page (make-instr.py) it loads the fixture ten times as a new capture (generated moves on) and
ten times as the one it already has (the poll that finds nothing new), and prints the mean load time and the ten dearest wrapped functions per
load (ingest, layoutEdges, updateStats, ...). Headless Chrome, software compositing, no GPU.
HOW TO RUN:
  python3 -B -I tools/bench/page/make-instr.py ROOT/starchorus.html OUTDIR/instr.html
  python3 -B -I tools/bench/page/bench-poll.py OUTDIR ROOT OUTDIR/instr.html FIXTURE WxH SCALE MOBILE       (e.g. 1440x900 2 0)
  Needs python3 and Google Chrome (found as tools/cdp.py finds it). No device, no network (127.0.0.1 only). ROOT is only read.
WRITES ONLY under OUTDIR: a temporary www and Chrome profile that are removed again. The result is one JSON line on stdout.
DETERMINISTIC: the sizes (bytes of the capture) and the error count (0). NOISE: the milliseconds (+-10 percent on a quiet machine); same-run ratios.
Not part of any gate.
"""
import functools
import http.server
import importlib.util
import json
import os
import shutil
import socketserver
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request

if len(sys.argv) != 8:
    sys.exit(__doc__)
out_dir, root, instr, fixture, size, scale, mobile = sys.argv[1:8]
w, h = [int(v) for v in size.split("x")]
os.makedirs(out_dir, exist_ok=True)
spec = importlib.util.spec_from_file_location("cdp", os.path.join(root, "tools", "cdp.py"))
cdp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cdp)
tmp = tempfile.mkdtemp(prefix="bench-www-", dir=out_dir)
shutil.copy(instr, os.path.join(tmp, "index.html"))
shutil.copy(fixture, os.path.join(tmp, "starchorus.json"))


class H(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


class S(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


srv = S(("127.0.0.1", 0), functools.partial(H, directory=tmp))
port = srv.server_address[1]
threading.Thread(target=srv.serve_forever, daemon=True).start()
profile = tempfile.mkdtemp(prefix="bench-prof-", dir=out_dir)
proc = subprocess.Popen([cdp.find_chrome(), "--headless=new", "--disable-gpu", "--no-first-run", "--disable-background-timer-throttling",
                         "--disable-renderer-backgrounding", "--remote-debugging-port=0", "--remote-allow-origins=*", "--user-data-dir=" + profile,
                         "--window-size=%d,%d" % (w, h), "about:blank"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    pc = 0
    for _ in range(200):
        try:
            pc = int(open(os.path.join(profile, "DevToolsActivePort")).readline().strip())
            break
        except Exception:
            time.sleep(0.05)
    pages = []
    for _ in range(100):
        try:
            pages = [t for t in json.load(urllib.request.urlopen("http://127.0.0.1:%d/json/list" % pc, timeout=2)) if t.get("type") == "page"]
            if pages:
                break
        except Exception:
            pass
        time.sleep(0.1)
    c = cdp.CDP(pages[0]["webSocketDebuggerUrl"])
    c.call("Emulation.setDeviceMetricsOverride", {"width": w, "height": h, "deviceScaleFactor": float(scale), "mobile": mobile == "1"})
    for m in ("Runtime", "Page"):
        c.call(m + ".enable")
    c.call("Page.navigate", {"url": "http://127.0.0.1:%d/?poll=0&intro=0&debug=1&spin=0" % port})
    c.pump(5)
    c.evaluate("window.__inst()")
    js = """(async()=>{const raw=await (await fetch('starchorus.json',{cache:'no-store'})).text();
      const t0=performance.now();let doc;for(let i=0;i<20;i++)doc=JSON.parse(raw);const parseMs=(performance.now()-t0)/20;
      const out={bytes:raw.length,parseMs:+parseMs.toFixed(3)};
      const load=(g)=>{const d=JSON.parse(raw);d.generated=g;const t=performance.now();STARCHORUS.load(d,'live',{mode:'live',tickMs:30000});return performance.now()-t};
      const B=()=>JSON.parse(JSON.stringify(window.__b));
      load(1789300000);await STARCHORUS.wait(300);
      for(const k in window.__b){window.__b[k].n=0;window.__b[k].ms=0}
      const fresh=[];for(let i=1;i<=10;i++){fresh.push(load(1789300000+30*i));await STARCHORUS.wait(120)}
      out.freshLoadMs=+(fresh.reduce((a,b)=>a+b,0)/fresh.length).toFixed(2);out.freshBreak=B();
      for(const k in window.__b){window.__b[k].n=0;window.__b[k].ms=0}
      const same=[];for(let i=0;i<10;i++){same.push(load(1789300000+300));await STARCHORUS.wait(120)}
      out.sameLoadMs=+(same.reduce((a,b)=>a+b,0)/same.length).toFixed(2);out.sameBreak=B();
      out.errors=STARCHORUS.errors().length;return JSON.stringify(out)})()"""
    r = json.loads(c.evaluate(js, timeout=120))

    def top(bk, n):
        skip = ("render", "step", "tick", "budgetBegin", "perfTick", "projectAll", "stepParticles", "stepNodes", "stepClouds", "stepSky",
                "stepBubbles", "stepFlares", "scopeStep", "drawScope", "drawScopeBg")
        return sorted(((k, round(v["ms"] / max(1, n), 3)) for k, v in bk.items() if v["n"] and k not in skip), key=lambda x: -x[1])[:12]

    print(json.dumps({"fixture": os.path.basename(fixture), "bytes": r["bytes"], "jsonParseMs": r["parseMs"], "fresh_load_ms": r["freshLoadMs"],
                      "same_capture_load_ms": r["sameLoadMs"], "fresh_top_ms_per_load": top(r["freshBreak"], 10),
                      "same_top_ms_per_load": top(r["sameBreak"], 10), "errors": r["errors"]}))
finally:
    proc.terminate()
    srv.shutdown()
    shutil.rmtree(tmp, ignore_errors=True)
    shutil.rmtree(profile, ignore_errors=True)
