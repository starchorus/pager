# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/cdp-ready.sh -- the readiness wait of tools/cdp.py (--ready [EXPR]): a run goes on as soon as the page
# says it is ready, and --wait stays the ceiling. Sourced by tools/regress.sh with cwd = repo root. Only CDR_* globals
# and the cdr_* helpers are set.
#
# Five runs, about ten seconds: bare --ready on the demo page (met, fonts loaded, STARCHORUS there); a data expression
# on a fixture (false until the boot poll has loaded the capture, then true); an expression that never comes true (the
# ceiling is kept, the evals still run); one that throws on every probe (the same, exit 0); and a run without --ready,
# whose report has no "ready" block at all (what every site gets today). A sixth is refused before Chrome starts:
# --ready with --virtual-time. The three documents that describe the option are bound by a grep row.

cdr_ready() {   # cdr_ready PREFIX.json FIELD -> that field of the report's "ready" block, or "none" when the block is absent
  python3 -c 'import json,sys
r=json.load(open(sys.argv[1])).get("ready"); print("none" if r is None else json.dumps(r.get(sys.argv[2])))' "$1" "$2" 2>/dev/null
}
cdr_le() { python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) <= float(sys.argv[2]) else 1)' "$1" "$2" 2>/dev/null; }   # A <= B, decimals
cdr_docs() { grep -q -- '--ready' tools/README.md && grep -q -- '--ready' docs/architecture.md && grep -q -- '--ready' tools/harness.sh; }

# ---- 1. bare --ready on the demo page: met, fonts loaded, STARCHORUS there
runq demo "?poll=0&spin=0&intro=0" "out/$P-cdr-bare" --fps 0 --wait 6 --ready \
  --eval "document.fonts.status" --eval "!!window.STARCHORUS" >/dev/null 2>&1
CDR_M=$(cdr_ready "out/$P-cdr-bare.json" met); CDR_A=$(cdr_ready "out/$P-cdr-bare.json" after)
CDR_F=$(evalv "out/$P-cdr-bare.json" 1); CDR_S=$(evalv "out/$P-cdr-bare.json" 2)
if [ "$CDR_M" = true ] && [ "$CDR_F" = loaded ] && [ "$CDR_S" = true ]; then
  row "cdp.py --ready (bare): met after ${CDR_A} s of a 6 s ceiling, fonts loaded, STARCHORUS there" PASS
else
  row "cdp.py --ready (bare): met, fonts loaded, STARCHORUS there" FAIL; echo "    met=$CDR_M after=$CDR_A fonts=$CDR_F starchorus=$CDR_S"
fi

# ---- 2. a data expression: false while the capture is not yet loaded, true once the boot poll has applied it
runq "$F/few-clients.json" "?poll=0&spin=0&intro=0" "out/$P-cdr-data" --fps 0 --wait 6 \
  --ready "window.STARCHORUS && STARCHORUS.stats().apsTotal > 0" --eval "STARCHORUS.stats().apsTotal" >/dev/null 2>&1
CDR_M=$(cdr_ready "out/$P-cdr-data.json" met); CDR_A=$(cdr_ready "out/$P-cdr-data.json" after); CDR_N=$(evalv "out/$P-cdr-data.json" 1)
if [ "$CDR_M" = true ] && ge "${CDR_N:-0}" 1; then
  row "cdp.py --ready EXPR: the capture is loaded (apsTotal $CDR_N) after ${CDR_A} s" PASS
else
  row "cdp.py --ready EXPR: the capture is loaded" FAIL; echo "    met=$CDR_M after=$CDR_A apsTotal=$CDR_N"
fi

# ---- 3. an expression that never comes true: the ceiling (1 s) is kept within 0.6 s, probes were made, the evals still run
runq demo "?poll=0&spin=0&intro=0" "out/$P-cdr-never" --fps 0 --wait 1 --ready "false" --eval "1+1" >/dev/null 2>&1
CDR_M=$(cdr_ready "out/$P-cdr-never.json" met); CDR_A=$(cdr_ready "out/$P-cdr-never.json" after)
CDR_P=$(cdr_ready "out/$P-cdr-never.json" probes); CDR_V=$(evalv "out/$P-cdr-never.json" 1)
if [ "$CDR_M" = false ] && cdr_le 1 "${CDR_A:-0}" && cdr_le "${CDR_A:-9}" 1.6 && ge "${CDR_P:-0}" 3 && [ "$CDR_V" = 2 ]; then
  row "cdp.py --ready never true: ceiling kept (${CDR_A} s of 1, $CDR_P probes), evals run" PASS
else
  row "cdp.py --ready never true: ceiling kept, probes made, evals run" FAIL; echo "    met=$CDR_M after=$CDR_A probes=$CDR_P eval=$CDR_V"
fi

# ---- 4. an expression that throws on every probe: "not yet" each time, the ceiling is kept, no driver failure
runq demo "?poll=0&spin=0&intro=0" "out/$P-cdr-throws" --fps 0 --wait 1 --ready "STARCHORUS.noSuchThing.x" --eval "2+2" >/dev/null 2>&1; CDR_RC=$?
CDR_M=$(cdr_ready "out/$P-cdr-throws.json" met); CDR_V=$(evalv "out/$P-cdr-throws.json" 1)
if [ "$CDR_RC" = 0 ] && [ "$CDR_M" = false ] && [ "$CDR_V" = 4 ]; then
  row "cdp.py --ready that throws on every probe: not met, exit 0, evals run" PASS
else
  row "cdp.py --ready that throws on every probe: not met, exit 0, evals run" FAIL; echo "    rc=$CDR_RC met=$CDR_M eval=$CDR_V"
fi

# ---- 5. without --ready the report has no "ready" block: the fixed wait, as every site gets today
runq demo "?poll=0&spin=0&intro=0" "out/$P-cdr-none" --fps 0 --wait 1 --eval "3+3" >/dev/null 2>&1
CDR_M=$(cdr_ready "out/$P-cdr-none.json" met); CDR_V=$(evalv "out/$P-cdr-none.json" 1)
rowif "cdp.py without --ready: no ready block in the report, the fixed wait as before" [ "$CDR_M/$CDR_V" = none/6 ]

# ---- 6. --ready with --virtual-time is refused before Chrome starts (no frame would ever be drawn)
CDR_E=$(python3 tools/cdp.py "http://127.0.0.1:9/" --virtual-time --ready --wait 0.3 --fps 0 --json 2>&1 >/dev/null); CDR_RC=$?
case $CDR_E in *"not with --virtual-time"*) CDR_OK=1 ;; *) CDR_OK=0 ;; esac
rowif "cdp.py --ready with --virtual-time is refused (exit $CDR_RC, before Chrome)" [ "$CDR_RC/$CDR_OK" = 1/1 ]

# ---- 7. the documents that describe the option name it
rowif "cdp.py --ready is described in tools/README.md, docs/architecture.md, tools/harness.sh" cdr_docs
