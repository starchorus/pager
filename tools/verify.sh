#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# verify.sh -- load starchorus.html with a fixture in headless Chrome and judge the result.
#
# Usage: tools/verify.sh HTML FIXTURE|demo PREFIX [extra cdp.py args...]
#
#   HTML     the page under test (usually starchorus.html)
#   FIXTURE  a starchorus.json to serve next to it, or the word "demo" (no starchorus.json:
#            the page keeps its built-in sample sky and every poll 404s, as expected)
#   PREFIX   output prefix: writes PREFIX.png (screenshot), PREFIX.json (report),
#            PREFIX.server.log (http.server log)
#   extra    passed through to tools/cdp.py, e.g. --eval "window.STARCHORUS && STARCHORUS.stats()"
#            --click 720,450 --key Escape (a later --wait/--fps overrides the defaults)
#
# Exit 0 = page ran clean (no exceptions, no real console errors, fps >= 30).
# Exit 1 = real errors / exceptions, fps < 30 or fps unmeasured. Exit 2 = usage / setup.
#
# Expected 404s are NOT errors: /favicon.ico always, /starchorus.json in demo mode.
# Dev-machine tool (macOS/Linux, POSIX sh + python3). Nothing here runs on the device.

set -u

usage() { echo "usage: $0 HTML FIXTURE|demo PREFIX [cdp.py args...]" >&2; exit 2; }
[ $# -ge 3 ] || usage
html=$1; fixture=$2; prefix=$3; shift 3

here=$(cd "$(dirname "$0")" && pwd) || exit 2
cdp="$here/cdp.py"
[ -f "$cdp" ] || { echo "verify: $cdp missing" >&2; exit 2; }
[ -f "$html" ] || { echo "verify: HTML not found: $html" >&2; exit 2; }
if [ "$fixture" != "demo" ] && [ ! -f "$fixture" ]; then
    echo "verify: fixture not found: $fixture" >&2; exit 2
fi
command -v python3 >/dev/null 2>&1 || { echo "verify: python3 required" >&2; exit 2; }

case $prefix in
    */*) mkdir -p "$(dirname "$prefix")" || exit 2 ;;
esac

tmp=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-verify.XXXXXX") || exit 2
srvpid=""
# shellcheck disable=SC2317,SC2329  # invoked via trap (SC2317 on ShellCheck < 0.10, SC2329 on >= 0.10)
cleanup() {
    if [ -n "$srvpid" ]; then kill "$srvpid" 2>/dev/null; wait "$srvpid" 2>/dev/null; fi
    rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

cp "$html" "$tmp/index.html" || exit 2
if [ "$fixture" != "demo" ]; then
    python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$fixture" \
        || { echo "verify: fixture is not valid JSON: $fixture" >&2; exit 2; }
    cp "$fixture" "$tmp/starchorus.json" || exit 2
fi

port=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1])') || exit 2
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$tmp" >"$prefix.server.log" 2>&1 &
srvpid=$!

# wait until the server answers (max ~5 s)
i=0
until python3 -c 'import sys,urllib.request; urllib.request.urlopen(sys.argv[1], timeout=1)' "http://127.0.0.1:$port/" >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge 25 ]; then echo "verify: http.server did not come up on port $port" >&2; exit 2; fi
    sleep 0.2
done

url="http://127.0.0.1:$port/"
if ! python3 "$cdp" "$url" --shot "$prefix.png" --wait 6 --fps 3 --json "$@" >"$prefix.json.tmp"; then
    echo "verify: cdp.py failed (driver error), see $prefix.json.tmp" >&2
    exit 2
fi

# Post-process: filter the expected 404s, add a verdict block, print the summary.
python3 - "$prefix.json.tmp" "$prefix.json" "$fixture" "$html" <<'PY'
import json, sys
src, dst, fixture, html = sys.argv[1:5]
rep = json.load(open(src, encoding="utf-8"))
demo = fixture == "demo"

def expected(entry):
    blob = " ".join(str(entry.get(k) or "") for k in ("url", "text"))
    return "favicon.ico" in blob or (demo and "starchorus.json" in blob and "404" in blob)

console = rep.get("console") or []
errors = [c for c in console if c.get("type") in ("error", "assert")]
real_errors = [c for c in errors if not expected(c)]
filtered = [c for c in errors if expected(c)]
exceptions = rep.get("exceptions") or []
warnings = [c for c in console if c.get("type") in ("warning", "warn")]
fps = rep.get("fps")
fps_ok = isinstance(fps, (int, float)) and fps >= 30
ok = fps_ok and not real_errors and not exceptions
rep["verify"] = {
    "html": html, "fixture": fixture, "mode": "demo" if demo else "fixture",
    "fps": fps, "fps_ok": fps_ok, "min_fps": 30,
    "error_count_raw": rep.get("error_count"),
    "expected_404_filtered": len(filtered),
    "real_errors": real_errors, "exceptions": exceptions,
    "pass": ok,
}
json.dump(rep, open(dst, "w", encoding="utf-8"), indent=1, ensure_ascii=False)

print("verify:      %s  <-  %s" % (html, fixture))
print("fps:         %s  (min 30)%s" % (fps, "" if fps_ok else "  ** TOO LOW / UNMEASURED **"))
print("error_count: %d raw, %d expected 404 filtered, %d real, %d exceptions" % (
    len(errors), len(filtered), len(real_errors), len(exceptions)))
for e in real_errors:
    print("  ERROR:", json.dumps(e, ensure_ascii=False)[:600])
for e in exceptions:
    print("  EXCEPTION:", json.dumps(e, ensure_ascii=False)[:600])
for w in warnings[:10]:
    print("  warn:", (w.get("text") or "")[:300])
for e in rep.get("eval") or []:
    print("eval:", e["expr"][:80], "=>", json.dumps(e["value"], ensure_ascii=False)[:500])
if rep.get("screenshot"):
    print("screenshot:  %s" % rep["screenshot"])
print("report:      %s" % dst)
print("result:      %s" % ("PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
PY
rc=$?
rm -f "$prefix.json.tmp"
exit $rc
