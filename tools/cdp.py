#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
Minimal Chrome DevTools Protocol driver (Python stdlib only, no node/playwright).

Launches a headless Chrome, opens a URL, collects console messages + uncaught
exceptions, optionally runs JS expressions, measures frame rate and takes a
screenshot. Used by the Starchorus verification steps (not shipped to the device).

Usage:
  python3 tools/cdp.py URL [--shot out.png] [--wait 4] [--fps 2]
                          [--eval "expr" ...] [--click X,Y] [--key Key]
                          [--step KIND:ARG ...] [--eval-timeout 30]
                          [--width 1440 --height 900] [--mobile] [--virtual-time] [--json]

Order: navigate -> --wait -> --click/--key (+ --after-wait) -> fps over --fps s -> --eval list
-> --step list (eval:EXPR | click:X,Y | clickat:EXPR returning [x,y] | key:KEY | wait:S | size:WxH
   | drag:X1,Y1,X2,Y2,MS (mouse) | touch:X1,Y1,X2,Y2,MS (one finger; equal points = a tap) | vtime:MS)
-> screenshot. A promise result is awaited; an expression with a top-level `await` is retried in
REPL mode. Chrome picks a free DevTools port itself, so concurrent runs never share a browser.
--mobile: a phone viewport (mobile metrics, touch emulation: `pointer: coarse` and `hover: none` match).
--virtual-time: the page's clock is held from before the navigation and moves only in vtime:MS steps, by MS virtual
milliseconds each (timers fire in order, a pending fetch holds the clock; no frames are drawn). Evals between the
steps run while the clock stands, so they must not wait on a timer (STARCHORUS.wait would never return).

Exit code 0 on success (even if the page logged errors -- check the report),
1 on driver failure. The report (JSON) lists console entries, exceptions,
eval results (--eval, then eval/clickat steps, in order) and measured fps.
It also lists every request the page actually made (CDP Network domain) under "requests":
[{method, url, type}], in the order sent: redirects and sendBeacon pings included, url cut to 200 characters,
a WebSocket as {method: "WEBSOCKET"}. That is the run-time evidence the passivity rows of tools/regress.sh
lack (they read the source text); tools/harness.sh net_verdict judges it. Additive: no consumer reads it strictly.
"""
import argparse, base64, json, os, socket, struct, subprocess, sys, tempfile, time, urllib.request

CHROME_CANDIDATES = [
    os.environ.get("CHROME_BIN", ""),
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    "/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser",
]


def find_chrome():
    for c in CHROME_CANDIDATES:
        if c and os.path.exists(c):
            return c
    sys.exit("no chrome binary found; set CHROME_BIN")


class WS:
    """Tiny RFC6455 client: text frames only, client-side masking, no extensions."""

    def __init__(self, url):
        assert url.startswith("ws://")
        rest = url[5:]
        hostport, _, path = rest.partition("/")
        host, _, port = hostport.partition(":")
        self.sock = socket.create_connection((host, int(port or 80)), timeout=30)
        key = base64.b64encode(os.urandom(16)).decode()
        req = ("GET /%s HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
               "Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n") % (path, hostport, key)
        self.sock.sendall(req.encode())
        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise RuntimeError("websocket handshake failed")
            buf += chunk
        head, _, self.rbuf = buf.partition(b"\r\n\r\n")
        if b" 101 " not in head.split(b"\r\n")[0]:
            raise RuntimeError("websocket upgrade refused: " + head.decode(errors="replace"))

    def send(self, text):
        data = text.encode()
        hdr = bytearray([0x81])
        n = len(data)
        if n < 126:
            hdr.append(0x80 | n)
        elif n < 65536:
            hdr.append(0x80 | 126); hdr += struct.pack(">H", n)
        else:
            hdr.append(0x80 | 127); hdr += struct.pack(">Q", n)
        mask = os.urandom(4)
        hdr += mask
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
        self.sock.sendall(bytes(hdr) + masked)

    def _read_exact(self, n):
        while len(self.rbuf) < n:
            chunk = self.sock.recv(max(65536, n - len(self.rbuf)))
            if not chunk:
                raise RuntimeError("websocket closed")
            self.rbuf += chunk
        out, self.rbuf = self.rbuf[:n], self.rbuf[n:]
        return out

    def recv(self):
        """Returns the next complete text message (handles fragmentation, ping, close)."""
        message = b""
        while True:
            b0, b1 = self._read_exact(2)
            fin, opcode = b0 & 0x80, b0 & 0x0F
            n = b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._read_exact(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._read_exact(8))[0]
            if b1 & 0x80:  # server frames are never masked, but be safe
                mask = self._read_exact(4)
                payload = bytes(b ^ mask[i % 4] for i, b in enumerate(self._read_exact(n)))
            else:
                payload = self._read_exact(n)
            if opcode == 0x8:
                raise RuntimeError("websocket closed by peer")
            if opcode == 0x9:  # ping -> pong
                self.sock.sendall(bytes([0x8A, 0x80]) + b"\x00\x00\x00\x00")
                continue
            if opcode == 0xA:
                continue
            message += payload
            if fin:
                return message.decode()


class CDP:
    def __init__(self, ws_url):
        self.ws = WS(ws_url)
        self.next_id = 0
        self.events = []

    def call(self, method, params=None, timeout=30):
        self.next_id += 1
        mid = self.next_id
        self.ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
        deadline = time.time() + timeout
        # The socket has its own 30 s read timeout: without narrowing it to what is left of THIS call, a silent eval longer
        # than 30 s would die with a bare socket.timeout traceback and --eval-timeout above 30 would have no effect.
        try:
            while True:
                left = deadline - time.time()
                if left <= 0:
                    break
                self.ws.sock.settimeout(left)
                try:
                    msg = json.loads(self.ws.recv())
                except socket.timeout:
                    break
                if msg.get("id") == mid:
                    if "error" in msg:
                        raise RuntimeError("%s -> %s" % (method, msg["error"]))
                    return msg.get("result", {})
                if "method" in msg:
                    self.events.append(msg)
        finally:
            self.ws.sock.settimeout(30)
        raise RuntimeError("timeout waiting for " + method)

    def pump(self, seconds):
        """Collect events for a while without sending anything."""
        self.ws.sock.settimeout(0.25)
        end = time.time() + seconds
        try:
            while time.time() < end:
                try:
                    msg = json.loads(self.ws.recv())
                except socket.timeout:
                    continue
                if "method" in msg:
                    self.events.append(msg)
        finally:
            self.ws.sock.settimeout(30)

    def evaluate(self, expr, await_promise=True, timeout=30):
        p = {"expression": expr, "awaitPromise": await_promise, "returnByValue": True}
        r = self.call("Runtime.evaluate", p, timeout=timeout)
        ex = r.get("exceptionDetails")
        if ex and "await is only valid" in str((ex.get("exception") or {}).get("description") or ex.get("text")):
            # top-level `await` ("await STARCHORUS.pollNow()"): a SyntaxError is raised before anything runs,
            # so retry once in REPL mode. Only then -- replMode would NOT unwrap a promise-valued result.
            p["replMode"] = True
            r = self.call("Runtime.evaluate", p, timeout=timeout)
        if "exceptionDetails" in r:
            ex = r["exceptionDetails"]
            return {"error": ex.get("exception", {}).get("description") or ex.get("text")}
        return r.get("result", {}).get("value")


def fmt_console_arg(a):
    if "value" in a:
        return str(a["value"])
    return a.get("description") or a.get("type", "?")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("url")
    ap.add_argument("--shot", help="write PNG screenshot here")
    ap.add_argument("--wait", type=float, default=4.0, help="seconds to let the page run before measuring")
    ap.add_argument("--fps", type=float, default=2.0, help="seconds over which to count animation frames (0 = skip)")
    ap.add_argument("--eval", action="append", default=[], help="JS expression to evaluate after wait (repeatable)")
    ap.add_argument("--click", action="append", default=[], help="X,Y css px to click after wait (repeatable)")
    ap.add_argument("--key", action="append", default=[], help="key to press after clicks (repeatable), e.g. Escape")
    ap.add_argument("--after-wait", type=float, default=1.0, help="seconds to wait after clicks/keys before shot")
    ap.add_argument("--width", type=int, default=1440)
    ap.add_argument("--height", type=int, default=900)
    ap.add_argument("--scale", type=float, default=1.0, help="device scale factor")
    ap.add_argument("--mobile", action="store_true", help="mobile metrics + touch emulation (a phone)")
    ap.add_argument("--virtual-time", action="store_true", help="hold the page clock from the start; vtime:MS steps move it")
    ap.add_argument("--json", action="store_true", help="print the full JSON report")
    ap.add_argument("--keep-profile", action="store_true")
    ap.add_argument("--eval-timeout", type=float, default=30.0, help="seconds per --eval/--step eval (default 30; values above 30 are honoured by the socket as well)")
    ap.add_argument("--step", action="append", default=[],
                    help="ordered action after the --eval list, before the shot (repeatable): "
                         "eval:EXPR | click:X,Y | clickat:EXPR (EXPR -> [x,y]) | key:KEY | wait:SECONDS | size:WxH | "
                         "drag:X1,Y1,X2,Y2,MS | touch:X1,Y1,X2,Y2,MS | vtime:MS")
    args = ap.parse_args()

    chrome = find_chrome()
    profile = tempfile.mkdtemp(prefix="starchorus-cdp-")
    # Port 0 = Chrome picks a free port and writes it to <profile>/DevToolsActivePort. A fixed,
    # pid-derived port could collide with a concurrent run and silently drive the OTHER Chrome.
    proc = subprocess.Popen([
        chrome, "--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
        "--hide-scrollbars", "--mute-audio", "--disable-extensions", "--disable-background-timer-throttling",
        "--disable-renderer-backgrounding", "--remote-debugging-port=0",
        "--remote-allow-origins=*", "--user-data-dir=" + profile,
        "--window-size=%d,%d" % (args.width, args.height), "about:blank",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    report = {"url": args.url, "console": [], "exceptions": [], "eval": [], "fps": None, "requests": []}
    try:
        port = None
        for _ in range(200):
            try:
                with open(os.path.join(profile, "DevToolsActivePort")) as f:
                    port = int(f.readline().strip())
                break
            except (OSError, ValueError):
                time.sleep(0.05)
        if not port:
            sys.exit("chrome did not report a DevTools port")
        target = None
        for _ in range(100):
            try:
                with urllib.request.urlopen("http://127.0.0.1:%d/json/list" % port, timeout=2) as r:
                    lst = json.load(r)
                pages = [t for t in lst if t.get("type") == "page"]
                if pages:
                    target = pages[0]
                    break
            except Exception:
                pass
            time.sleep(0.1)
        if not target:
            sys.exit("chrome did not expose a page target")
        cdp = CDP(target["webSocketDebuggerUrl"])
        cdp.call("Emulation.setDeviceMetricsOverride", {"width": args.width, "height": args.height,
                                                        "deviceScaleFactor": args.scale, "mobile": args.mobile})
        if args.mobile:
            cdp.call("Emulation.setTouchEmulationEnabled", {"enabled": True, "maxTouchPoints": 5})
        if args.virtual_time:
            cdp.call("Emulation.setVirtualTimePolicy", {"policy": "pause"})
        cdp.call("Runtime.enable")
        cdp.call("Log.enable")
        cdp.call("Network.enable")   # the requests the page really makes (see "requests" in the report)
        cdp.call("Page.enable")
        cdp.call("Page.navigate", {"url": args.url})
        cdp.pump(args.wait)
        for c in args.click:
            x, y = [float(v) for v in c.split(",")]
            for t in ("mousePressed", "mouseReleased"):
                cdp.call("Input.dispatchMouseEvent", {"type": t, "x": x, "y": y, "button": "left", "clickCount": 1})
            cdp.pump(0.3)
        for k in args.key:
            cdp.call("Input.dispatchKeyEvent", {"type": "keyDown", "key": k})
            cdp.call("Input.dispatchKeyEvent", {"type": "keyUp", "key": k})
            cdp.pump(0.3)
        if args.click or args.key:
            cdp.pump(args.after_wait)
        if args.fps > 0:
            ms = int(args.fps * 1000)
            report["fps"] = cdp.evaluate(
                "new Promise(res=>{let n=0,t0=performance.now();function f(){n++;if(performance.now()-t0<%d)requestAnimationFrame(f);else res(Math.round(n*1000/(performance.now()-t0)));}requestAnimationFrame(f);})" % ms,
                timeout=args.fps + 20)
        for e in args.eval:
            report["eval"].append({"expr": e, "value": cdp.evaluate(e, timeout=args.eval_timeout)})
        for st in args.step:
            kind, _, arg = st.partition(":")
            if kind == "eval":
                report["eval"].append({"expr": arg, "value": cdp.evaluate(arg, timeout=args.eval_timeout)})
            elif kind in ("click", "clickat"):
                if kind == "clickat":
                    xy = cdp.evaluate(arg, timeout=args.eval_timeout)
                    report["eval"].append({"expr": st, "value": xy})
                    if not (isinstance(xy, list) and len(xy) == 2):
                        continue
                else:
                    xy = [float(v) for v in arg.split(",")]
                x, y = float(xy[0]), float(xy[1])
                cdp.call("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x, "y": y})
                for t in ("mousePressed", "mouseReleased"):
                    cdp.call("Input.dispatchMouseEvent", {"type": t, "x": x, "y": y, "button": "left", "clickCount": 1})
                cdp.pump(0.3)
            elif kind == "key":
                cdp.call("Input.dispatchKeyEvent", {"type": "keyDown", "key": arg})
                cdp.call("Input.dispatchKeyEvent", {"type": "keyUp", "key": arg})
                cdp.pump(0.3)
            elif kind == "wait":
                cdp.pump(float(arg))
            elif kind == "size":
                w, h = [int(v) for v in arg.lower().split("x")]
                cdp.call("Emulation.setDeviceMetricsOverride", {"width": w, "height": h,
                                                                "deviceScaleFactor": args.scale, "mobile": args.mobile})
                cdp.pump(0.5)   # the page debounces resize (100 ms)
            elif kind in ("drag", "touch"):
                x1, y1, x2, y2, ms = [float(v) for v in arg.split(",")]
                n = 0 if (x1, y1) == (x2, y2) else max(2, int(ms // 16))   # a move every ~16 ms, like a display frame
                mouse = kind == "drag"
                send = (lambda p: cdp.call("Input.dispatchMouseEvent", p)) if mouse else (lambda p: cdp.call("Input.dispatchTouchEvent", p))
                send({"type": "mousePressed", "x": x1, "y": y1, "button": "left", "clickCount": 1} if mouse else {"type": "touchStart", "touchPoints": [{"x": x1, "y": y1}]})
                for i in range(1, n + 1):
                    time.sleep(ms / 1000.0 / n)
                    x, y = x1 + (x2 - x1) * i / n, y1 + (y2 - y1) * i / n
                    send({"type": "mouseMoved", "x": x, "y": y, "button": "left", "buttons": 1} if mouse else {"type": "touchMove", "touchPoints": [{"x": x, "y": y}]})
                send({"type": "mouseReleased", "x": x2, "y": y2, "button": "left", "clickCount": 1} if mouse else {"type": "touchEnd", "touchPoints": []})
                cdp.pump(0.4)
            elif kind == "vtime":
                cdp.call("Emulation.setVirtualTimePolicy", {"policy": "pauseIfNetworkFetchesPending", "budget": float(arg)})
                done, end = False, time.time() + 120
                cdp.ws.sock.settimeout(0.5)
                try:
                    while not done and time.time() < end:
                        try:
                            msg = json.loads(cdp.ws.recv())
                        except socket.timeout:
                            continue
                        if msg.get("method") == "Emulation.virtualTimeBudgetExpired":
                            done = True
                        elif "method" in msg:
                            cdp.events.append(msg)
                finally:
                    cdp.ws.sock.settimeout(30)
                if not done:
                    sys.exit("vtime: the virtual time budget did not expire")
                cdp.call("Emulation.setVirtualTimePolicy", {"policy": "pause"})
            else:
                sys.exit("unknown --step kind: " + st)
        if args.shot:
            r = cdp.call("Page.captureScreenshot", {"format": "png"}, timeout=60)
            with open(args.shot, "wb") as f:
                f.write(base64.b64decode(r["data"]))
            report["screenshot"] = args.shot
        cdp.pump(0.2)
        for ev in cdp.events:
            m, p = ev["method"], ev.get("params", {})
            if m == "Runtime.consoleAPICalled":
                report["console"].append({"type": p.get("type"), "text": " ".join(fmt_console_arg(a) for a in p.get("args", []))})
            elif m == "Runtime.exceptionThrown":
                d = p.get("exceptionDetails", {})
                report["exceptions"].append({"text": d.get("text"), "desc": (d.get("exception") or {}).get("description"),
                                             "line": d.get("lineNumber"), "col": d.get("columnNumber")})
            elif m == "Network.requestWillBeSent":   # every request, redirect hops included (a redirect fires it again)
                r = p.get("request", {})
                report["requests"].append({"method": r.get("method"), "url": (r.get("url") or "")[:200], "type": p.get("type")})
            elif m == "Network.webSocketCreated":    # a WebSocket has no requestWillBeSent
                report["requests"].append({"method": "WEBSOCKET", "url": (p.get("url") or "")[:200], "type": "WebSocket"})
            elif m == "Log.entryAdded":
                e = p.get("entry", {})
                report["console"].append({"type": e.get("level"), "source": e.get("source"), "text": e.get("text"), "url": e.get("url")})
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except Exception:
            proc.kill()
        if not args.keep_profile:
            subprocess.call(["rm", "-rf", profile])

    errors = [c for c in report["console"] if c.get("type") in ("error", "assert")] + report["exceptions"]
    report["error_count"] = len(errors)
    if args.json:
        print(json.dumps(report, indent=1))
    else:
        print("url:        ", report["url"])
        print("fps:        ", report["fps"])
        print("errors:     ", report["error_count"])
        print("requests:   ", len(report["requests"]))
        for e in errors:
            print("  ERROR:", json.dumps(e))
        others = [c for c in report["console"] if c.get("type") not in ("error", "assert")]
        for c in others[:20]:
            print("  console[%s]: %s" % (c.get("type"), c.get("text")))
        for e in report["eval"]:
            print("eval:", e["expr"][:80], "=>", json.dumps(e["value"])[:400])
        if report.get("screenshot"):
            print("screenshot: ", report["screenshot"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
