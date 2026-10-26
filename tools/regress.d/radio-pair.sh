# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/radio-pair.sh -- the 0.2 radio pair on the page: passive Bluetooth marks (rotating addresses of one company in one ring
# fold into one mark), the traffic cue on stations and channel activity as a whisker in the channel bar. Sourced by tools/regress.sh with cwd = repo
# root, after the core rows. Only RP_* globals are set.
#
# GUARDS AGAINST: a mark drawn by angle instead of the free-station radius; a mark that blinks at a ring boundary; a void window that
#   blanks the marks; a layer that moves the Wi-Fi sky, appears on a 0.1 document or changes with the order of bluetooth[]; activity that
#   leaks into the visited set of the D19 ghosts and the Watchlist; a cue that is normalised by the busiest station, aliases with a batch
#   writer or outlives the feed; a hostile Bluetooth or station text that runs script; a new function that grows past its limit.
# NEGATIVE PROBE: one-line copies of the page (served to headless Chrome on 127.0.0.1 only) -- marks by angle, hysteresis 0, activity in
#   S.hop, a rate over the last two samples only, no cue floor, no stale guard, marks drawn without their age, a hit test over marks that are not
#   drawn: each turns exactly its own row red (the unmutated page is the control: the rows themselves).
# NOT PROVEN: that a scan on the Pager sees what the fixture shows (device checks A1-A16 of the specification, docs/device-notes.md 2b); the Bluetooth
#   detail sheet, the tags, the CSV rows, the SITREP line, bt(), two of the three cue idioms (the halo and the bloom), the Air line, the hover line, the
#   whisker title and the reveal fade are not in this release (docs/architecture.md 14.10, 'Not in 0.2.0', lists them): no row proves what is not there,
#   and the doc-drift drop-in keeps the user-facing documents from claiming them.
#
# Runs WITHOUT ?fixed: nodes must fade in for the drawing checks. The fixture is served as starchorus.json, so an eval may fetch it and
# derive its variants (a void window, a moved address, a rated station, 300 records) from this one file.

RP_FX="$F/radio-pair.json"
RP_Q="?poll=0&spin=0&intro=0&debug=1"
# --ready for the runs whose eval loads what it reads or reads only what stands right after the boot (counts, texts, DOM, positions after settle(), data-derived rates), and
# whose own sleeps carry the fades; the page's age at the first read does not enter a figure. Not reduced motion (RP_EV_RM): it compares marks between frames of the boot
# layout, so it keeps the whole wait. A run on a served fixture is ready when the boot poll has replaced the built-in sky (its apsTotal is above 0 from the first frame,
# so a count would be met at once); the demo run takes the bare --ready.
RP_RDY="window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'"
RP_READY_RUNS=" ing fill id void cell drawn rank key tip host ord abs sky demo rate cue bud apart exp mut-angle mut-hysteresis mut-hop mut-twosamples mut-floor mut-stale mut-fresh mut-rank "
rp_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }
# rp_run NAME EVAL_FILE_TEXT [FIXTURE] [QUERY] [cdp args]: one run, the value of the eval (normalised JSON) in RP_V and the page's error count in RP_E
rp_run() {
  _rp_n=$1; _rp_e=$2; _rp_f=${3:-$RP_FX}; _rp_q=${4:-$RP_Q}; if [ $# -ge 4 ]; then shift 4; else shift $#; fi
  case $RP_READY_RUNS in
    *" $_rp_n "*) if [ "$_rp_f" = demo ]; then set -- "$@" --ready; else set -- "$@" --ready "$RP_RDY"; fi ;;
  esac
  runq "$_rp_f" "$_rp_q" "out/$P-rp-$_rp_n" --fps 0 --wait 3 --eval-timeout 120 --eval "$_rp_e" --eval "STARCHORUS.errors().length" "$@" >/dev/null 2>&1
  RP_V=$(evalv "out/$P-rp-$_rp_n.json" 1 | rp_nj); RP_E=$(evalv "out/$P-rp-$_rp_n.json" 2)
}
rp_row() {   # rp_row LABEL WANT_JSON: compare RP_V with WANT_JSON (normalised) and RP_E with 0
  _rp_w=$(printf '%s' "$2" | rp_nj)
  if [ "$RP_V" = "$_rp_w" ] && [ "$RP_E" = 0 ]; then row "$1" PASS
  else row "$1 (err ${RP_E:-?})" FAIL; echo "    got:  $(printf '%s' "$RP_V" | cut -c1-600)"; echo "    want: $_rp_w"; fi
}
# the preamble of every eval: the served fixture, the state, a loader with a mutation and a label
RP_JS='const I=STARCHORUS._internals,S=I.S,sleep=STARCHORUS.wait,o={};await sleep(900);const fx=await (await fetch("starchorus.json")).json(),G=fx.generated;
const ld=(mut,gen,label)=>{const d=JSON.parse(JSON.stringify(fx));if(gen!=null)d.generated=gen;if(mut)mut(d);return STARCHORUS.load(d,label||"rp");};'

# ---- the fixture and the contract: radio-pair.json is the generator's output and validates; the validator and the fuzz key list know the new fields
python3 tools/gen-testdata.py --radio --out "out/$P-radio.json" 2>/dev/null
RP_VAL=$(python3 tools/gen-testdata.py --validate "$RP_FX" 2>&1 | tail -1)
if cmp -s "out/$P-radio.json" "$RP_FX" && [ "${RP_VAL% OK}" != "$RP_VAL" ]; then row "radio: radio-pair.json = gen-testdata --radio, and it validates" PASS
else row "radio: radio-pair.json = gen-testdata --radio, and it validates [$RP_VAL]" FAIL; fi

RP_VB=$(python3 - "$RP_FX" <<'PY'
import copy, importlib.util, json, sys
spec = importlib.util.spec_from_file_location("g", "tools/gen-testdata.py"); g = importlib.util.module_from_spec(spec); sys.dont_write_bytecode = True; spec.loader.exec_module(g)
doc = json.load(open(sys.argv[1]))
def mut(f):
    d = copy.deepcopy(doc); f(d); return d
cases = [
  ("unsorted", lambda d: d["bluetooth"].reverse()), ("duplicate addr", lambda d: d["bluetooth"].append(dict(d["bluetooth"][0]))),
  ("addr_type", lambda d: d["bluetooth"][0].update(addr_type="static")), ("connectable false", lambda d: d["bluetooth"][0].update(connectable=False)),
  ("company range", lambda d: d["bluetooth"][0].update(company=65536)), ("upper-case addr", lambda d: d["bluetooth"][0].update(addr="02:00:00:00:04:0A")),
  ("reports 0", lambda d: d["bluetooth"][0].update(reports=0)), ("unknown key", lambda d: d["bluetooth"][0].update(uuid="x")),
  ("window without array", lambda d: d.pop("bluetooth")), ("hold without window", lambda d: d["center"].pop("bt_window")),
  ("activity unsorted", lambda d: d["activity"].reverse()), ("activity share 0", lambda d: d["activity"][0].update(share=0)),
  ("activity sum", lambda d: d["activity"][0].update(share=0.9)), ("activity below 2400", lambda d: d["activity"][0].update(freq=1000)),
  ("packets negative", lambda d: d["unassociated"][0].update(packets=-1)), ("packets text", lambda d: d["unassociated"][0].update(packets="x")),
]
bad = [n for n, f in cases if not g.validate(mut(f))]
print("ok" if not g.validate(doc) and not bad else "clean=%s unflagged=%s" % (g.validate(doc), bad))
PY
)
rowif "radio: the validator flags 16 broken variants of the fixture (order, duplicate, type, range, key, window, activity, packets) and passes the fixture [$RP_VB]" [ "$RP_VB" = ok ]

RP_FZ=$(python3 - <<'PY'
import importlib.util, json, os, sys, tempfile
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("fz", "tools/fuzz-doc.py"); fz = importlib.util.module_from_spec(spec); spec.loader.exec_module(fz)
gen = fz.load_contract(); fx = fz.Fixtures("tests/fixtures", gen, fz.page_fields("starchorus.html"))
keys = set(fx.fields["bt"]); hints = fx.hint["bt"]
muts, big = fz.build(fx, 20260918, "fuzz-canary.tmp", 50)
names = [m["n"] for m in muts]
want = {"addr", "addr_type", "rssi", "reports", "last_seen", "company", "company_name", "name", "connectable"}
mine = [n for n in names if ":bt." in n]
ok = want <= keys and hints.get("name") == "str" and hints.get("company_name") == "str" and hints.get("reports") == "num" and hints.get("last_seen") == "num" and hints.get("company") == "num" and len(mine) > 100 \
     and any(n.startswith("1:bt.addr:missing") for n in names) and any(n.startswith("6:bt.company_name:h") for n in names) and any(n.startswith("3:bluetooth[0]=") for n in names) \
     and {"bluetooth", "activity"} <= set(fx.fields["top"]) and "packets" in fx.fields["client"] and "ssid_recorded" not in fx.fields["ap"]
print("ok" if ok else "keys=%s hints=%s mutants=%d" % (sorted(keys ^ want), hints, len(mine)))
PY
)
rowif "radio: the fuzz key list derives bluetooth[] (nine keys, text and number hints read from normBt), activity and station packets, and no key for a name on record; mutants exist for each [$RP_FZ]" [ "$RP_FZ" = ok ]

# ---- size: each new function inside its limit (the specification's, three of them measured: rebuildBt, btTip, pkRate), the page inside the cap
RP_FNB=$(python3 - "$H" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
LIM = {"normBt": 900, "rebuildBt": 1800, "drawBt": 700, "btTip": 500, "pkRate": 680, "drawActivity": 600}
bad = []
for n, lim in LIM.items():
    m = re.search(r"^function %s\(.*?^\}" % n, t, re.S | re.M)
    b = len(m.group(0).encode()) if m else -1
    if not 0 < b <= lim: bad.append("%s %d/%d" % (n, b, lim))
m = re.search(r'    case "traffic": \{.*?\n    \}\n', t, re.S)
b = len(m.group(0).encode()) if m else -1
if not 0 < b <= 600: bad.append("traffic bake %d/600" % b)
print("ok:%d" % len(t.encode()) if not bad and len(t.encode()) <= 625000 else "bad: %s page %d" % (",".join(bad), len(t.encode())))
PY
)
rowif "radio: page size: normBt 900, rebuildBt 1800, drawBt 700, btTip 500, pkRate 680, drawActivity 600, the traffic bake 600 bytes, the page <= 625000 [$RP_FNB]" [ "${RP_FNB%%:*}" = ok ]

# ---- Bluetooth: ingest. Nine addresses fold into six marks (three rotating Maker A addresses in ring 1 are ONE mark, two without a company
# in ring 2 are ONE, the public and the static address are marks of their own), every mark sits at the radius of its signal on the shared
# rings (2D and 3D, the same in all themes), a fixed address is filled, a rotating one hollow, a folded one has a dot.
RP_EV_ING="(async()=>{$RP_JS"'
const TH=["foundation","wargames","whitehall"],b=STARCHORUS.stats().bluetooth;
o.counts=[b.addresses,b.marks,b.rotating,b.fixed,b.shown,b.window,b.hold,b.void].join("/");
o.marks=[...new Set(JSON.parse(STARCHORUS.exportText("json")).bluetooth.map(x=>x.mark))].sort().join(" ");
o.members=[...S.bt.values()].map(k=>k.id.slice(3)+"="+k.n+(k.rot?"r":"f")).sort().join(" ");
const pos=[];for(const t of TH){STARCHORUS.setTheme(t);STARCHORUS.frame();pos.push(JSON.stringify([...S.bt.values()].map(k=>{const n=STARCHORUS.nodeScreen(k.id);return [k.id,n.sx,n.sy]}).sort()));}
STARCHORUS.setTheme("foundation");o.posSame=pos.every(x=>x===pos[0]);
STARCHORUS.settle();const sk=STARCHORUS.phone().sky,R=sk.r,inner=Math.min(96,Math.max(64,0.22*R)),rr=(d)=>inner+(1-Math.max(0,Math.min(1,(d+90)/60)))*(R-inner),bad=[];
for(const k of S.bt.values()){const r=Math.hypot(k.lx,k.lz)*R,n=STARCHORUS.nodeScreen(k.id);if(Math.abs(r-rr(k.rssi))>12.01||Math.abs(Math.hypot(n.sx-sk.cx,n.sy-sk.cy)-r)>0.7)bad.push(k.id);}
o.radius2d=bad.length?bad.join(","):"ok";
STARCHORUS.setView("3d");await sleep(1600);const bad3=[];for(const k of S.bt.values()){if(Math.abs(k.p3[0]-k.lx)>1e-6||Math.abs(k.p3[2]-k.lz)>0.016)bad3.push(k.id);}o.radius3d=bad3.length?bad3.join(","):"ok";
STARCHORUS.setView("2d");await sleep(1600);
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run ing "$RP_EV_ING"
rp_row "radio: bluetooth ingest: 9 addresses, 6 marks, 7 rotating, 2 fixed, window 6 s, hold 120 s; the marks as listed; every mark at the radius of its signal (2D and 3D), at the same place in all three themes" \
  '{"counts":"9/6/7/2/6/6/120/false","errors":0,"marks":"bt:-:2 bt:-:3 bt:02:00:00:00:04:08 bt:02:00:00:00:04:09 bt:65535:1 bt:65535:2","members":"-:2=2r -:3=1r 02:00:00:00:04:08=1f 02:00:00:00:04:09=1f 65535:1=3r 65535:2=1r","posSame":true,"radius2d":"ok","radius3d":"ok"}'

# the glyph: the pixel at the centre of a mark. Only the marks are on this sky (no star or station near them): a fixed address is filled, a folded one has its dot,
# a single rotating one is hollow; the same in all three themes
RP_EV_FILL="(async()=>{$RP_JS"'
ld(d=>{d.aps=[];d.unassociated=[];},G,"only-bt");await sleep(1700);
const cen=(id)=>{const n=STARCHORUS.nodeScreen(id);return STARCHORUS.pixel("sky",Math.floor(n.sx),Math.floor(n.sy)).a;},all=[];
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);STARCHORUS.frame();await sleep(200);STARCHORUS.frame();all.push([...S.bt.values()].map(k=>k.id.slice(3)+":"+(cen(k.id)>=150?"solid":"open")).sort().join(" "));}
o.fill=all[0];o.same=all.every(x=>x===all[0]);o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run fill "$RP_EV_FILL"
rp_row "radio: bluetooth marks: filled for a fixed address, a dot in a folded mark, hollow for one rotating address; the same in every theme" \
  '{"errors":0,"fill":"-:2:solid -:3:open 02:00:00:00:04:08:solid 02:00:00:00:04:09:solid 65535:1:solid 65535:2:open","same":true}'

# ---- Bluetooth: identity. An address that moves inside its ring, or past a boundary by less than 3 dB, changes nothing on screen (the same node, still
# fully drawn); one that is more than 3 dB past moves to the neighbouring mark, and comes back only when it is more than 3 dB past again; a record
# that is only held (last heard 100 s ago) is still in its mark, dimmed by its own age
RP_EV_ID="(async()=>{$RP_JS"'
const setR=(addr,r)=>(d)=>{d.bluetooth.find(b=>b.addr===addr).rssi=r;d.bluetooth.sort((a,b)=>b.rssi-a.rssi||(a.addr<b.addr?-1:1));};
const A3="02:00:00:00:04:03",st=()=>[...S.bt.values()].filter(k=>k.target===1).map(k=>k.id.slice(3)+"="+k.n).sort().join(" ");
ld(null,G,"rp-id");await sleep(1500);const k1=S.bt.get("bt:65535:1");o.base=st();
ld(setR(A3,-61),G+30,"rp-id");await sleep(100);o.in3db=st();o.sameNode=S.bt.get("bt:65535:1")===k1;o.alpha=Math.round(S.bt.get("bt:65535:1").alpha*100)/100;
ld(setR(A3,-64),G+60,"rp-id");await sleep(100);o.past3db=st();
ld(setR(A3,-58),G+90,"rp-id");await sleep(100);o.backIn3db=st();
ld(setR(A3,-55),G+120,"rp-id");await sleep(100);o.backPast=st();
ld(d=>{d.bluetooth.find(b=>b.addr===A3).last_seen=G+150-100;},G+150,"rp-id");await sleep(100);o.held=[st(),S.bt.get("bt:65535:1").freshTier,S.bt.get("bt:65535:1").n].join("|");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RP_WANT_ID='{"alpha":1,"backIn3db":"-:2=2 -:3=1 02:00:00:00:04:08=1 02:00:00:00:04:09=1 65535:1=2 65535:2=2","backPast":"-:2=2 -:3=1 02:00:00:00:04:08=1 02:00:00:00:04:09=1 65535:1=3 65535:2=1","base":"-:2=2 -:3=1 02:00:00:00:04:08=1 02:00:00:00:04:09=1 65535:1=3 65535:2=1","errors":0,"held":"-:2=2 -:3=1 02:00:00:00:04:08=1 02:00:00:00:04:09=1 65535:1=3 65535:2=1|1|3","in3db":"-:2=2 -:3=1 02:00:00:00:04:08=1 02:00:00:00:04:09=1 65535:1=3 65535:2=1","past3db":"-:2=2 -:3=1 02:00:00:00:04:08=1 02:00:00:00:04:09=1 65535:1=2 65535:2=2","sameNode":true}'
rp_run id "$RP_EV_ID"
rp_row "radio: bluetooth identity: 3 dB past a ring boundary changes nothing (same node, alpha 1), more than 3 dB moves the address to the next mark, and back only past 3 dB again; a held record stays in its mark, dimmed" "$RP_WANT_ID"

# ---- Bluetooth: a void window (bt_window 0, nothing carried) keeps what was heard before and lets each mark run out by its own age: gone once its newest
# report is older than bt_hold; the button stays; a valid window that heard nothing carries nothing; a document without the array hides the layer
RP_EV_VOID="(async()=>{$RP_JS"'
const voidw=(d)=>{d.bluetooth=[];d.center.bt_window=0;},sn=()=>{const b=STARCHORUS.stats().bluetooth;return b?[b.addresses,b.marks,b.void,b.window].join("/"):"null";},btn=()=>document.querySelector("[data-band=bt]").hidden;
const tiers=()=>[...S.bt.values()].filter(k=>k.target===1).map(k=>k.freshTier).join("");
ld(null,G,"rp-void");await sleep(300);o.valid=sn();o.btn0=btn();
ld(voidw,G+30,"rp-void");await sleep(300);o.void30=sn();o.tiers30=tiers();o.btn1=btn();
ld(voidw,G+100,"rp-void");await sleep(1600);o.void100=sn();
ld(voidw,G+200,"rp-void");await sleep(1600);o.void200=sn();o.btn2=btn();
ld(d=>{d.bluetooth=[];},G+230,"rp-void");await sleep(300);o.emptyValid=sn();
ld(null,G+260,"rp-void");await sleep(300);o.back=sn();
ld(d=>{delete d.bluetooth;delete d.center.bt_window;delete d.center.bt_hold;},G+290,"rp-void");await sleep(300);o.none=sn()+"|"+btn();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run void "$RP_EV_VOID"
rp_row "radio: bluetooth void window: marks kept and dimmed by their own age (tiers 000110 after 30 s), the two older than the 120 s hold gone after 100 s and all after 200 s, the button stays; an empty valid window carries nothing; no array = layer off" \
  '{"back":"9/6/false/6","btn0":false,"btn1":false,"btn2":false,"emptyValid":"0/0/false/6","errors":0,"none":"null|true","tiers30":"000110","valid":"9/6/false/6","void100":"7/4/true/0","void200":"0/0/true/0","void30":"9/6/true/0"}'

# ---- Bluetooth: the counter cell. It shows while the capture has an array, holds the addresses (not the marks) and says so in its title; the filter does not take the count away;
# a void window that still holds records says so in the title, one that left nothing reads a dash; an empty valid window reads 0; the cap reads 256+; no array, no cell
RP_EV_CELL="(async()=>{$RP_JS"'
const cell=document.getElementById("n-bt-cell"),num=document.getElementById("n-bt"),rd=()=>[cell.hidden,num.textContent,num.title].join("|");
ld(null,G,"rp-cell");await sleep(600);o.valid=rd();
STARCHORUS.setToggles({bands:{bt:false}});await sleep(300);o.filterOff=rd();STARCHORUS.setToggles({bands:{bt:true}});
const voidw=(d)=>{d.bluetooth=[];d.center.bt_window=0;};
ld(voidw,G+30,"rp-cell");await sleep(300);o.voidHeld=rd();
ld(voidw,G+200,"rp-cell");await sleep(1600);o.voidGone=rd();
ld(d=>{d.bluetooth=[];},G+230,"rp-cell");await sleep(300);o.emptyValid=rd();
const bt=[];for(let i=0;i<300;i++)bt.push({addr:"02:00:00:00:05:"+i.toString(16).padStart(2,"0"),addr_type:i%3?"random-resolvable":"public",rssi:-30-Math.floor(i/4),reports:1,last_seen:G+260-3,company:i%2?65535:null});
ld(d=>{d.bluetooth=bt;},G+260,"rp-cell");await sleep(600);o.cap=[num.textContent,/^256 addresses heard in the last 2 min, in \d+ marks · LE, passive scan$/.test(num.title)].join("|");
ld(d=>{delete d.bluetooth;delete d.center.bt_window;delete d.center.bt_hold;},G+290,"rp-cell");await sleep(300);o.none=cell.hidden;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RP_WANT_CELL='{"cap":"256+|true","emptyValid":"false|0|0 addresses heard in the last 2 min, in 0 marks · LE, passive scan","errors":0,"filterOff":"false|9|9 addresses heard in the last 2 min, in 6 marks · LE, passive scan","none":true,"valid":"false|9|9 addresses heard in the last 2 min, in 6 marks · LE, passive scan","voidGone":"false|–|no valid scan this cycle; showing what was heard before","voidHeld":"false|9|no valid scan this cycle; showing what was heard before"}'
rp_run cell "$RP_EV_CELL"
rp_row "radio: bluetooth counter cell: 9 addresses in 6 marks with its title, kept while the filter hides the marks, 'no valid scan' in the title of a void window, a dash when it left nothing, 0 for an empty valid window, 256+ at the cap, no cell without an array" "$RP_WANT_CELL"

# ---- Bluetooth: what is DRAWN. The opacity of a mark on the canvas follows its own age (D1: 1 / .85 / .7 / .55 by tier), read from the pixel at the centre of a filled mark in each theme;
# a record that has aged to 'on record' is not drawn as if heard now
RP_EV_DRAWN="(async()=>{$RP_JS"'
const add=[["0c",-60,400],["0d",-70,1000]];
ld(d=>{d.aps=[];d.unassociated=[];d.bluetooth=d.bluetooth.filter(b=>b.addr==="02:00:00:00:04:09"||b.addr==="02:00:00:00:04:08");add.forEach(([n,r,age])=>d.bluetooth.push({addr:"02:00:00:00:04:"+n,addr_type:"public",rssi:r,reports:1,last_seen:G-age}));},G,"rp-drawn");await sleep(1900);
const ids=["bt:02:00:00:00:04:09","bt:02:00:00:00:04:08","bt:02:00:00:00:04:0c","bt:02:00:00:00:04:0d"],res=[];
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);STARCHORUS.frame();await sleep(250);STARCHORUS.frame();
 const a=ids.map(id=>{const n=STARCHORUS.nodeScreen(id);return STARCHORUS.pixel("sky",Math.floor(n.sx),Math.floor(n.sy)).a;});
 res.push((a[0]>=150?"drawn":"faint")+": "+[100,85,70,55].map((w,i)=>Math.abs(100*a[i]/a[0]-w)<=3).join(" "));}
o.tiers=ids.map(id=>S.bt.get(id).freshTier).join("");o.drawn=res;o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RP_WANT_DRAWN='{"drawn":["drawn: true true true true","drawn: true true true true","drawn: true true true true"],"errors":0,"tiers":"0123"}'
rp_run drawn "$RP_EV_DRAWN"
rp_row "radio: bluetooth drawn opacity: read from the canvas, the centre of a filled mark is, against the one heard 4 s ago, 85 % at 75 s, 70 % at 400 s and 55 % at 1000 s old (the tiers of D1, within 3 points), in all three themes" "$RP_WANT_DRAWN"

# ---- Bluetooth: the hit test finds what is drawn: of 120 fixed addresses only the strongest 48 are drawn, and only those can be hovered or selected
RP_EV_RANK="(async()=>{$RP_JS"'
const bt=[];for(let i=0;i<120;i++)bt.push({addr:"02:00:00:00:05:"+i.toString(16).padStart(2,"0"),addr_type:"public",rssi:-30-Math.floor(i/2),reports:1,last_seen:G-3});
ld(d=>{d.aps=[];d.unassociated=[];d.bluetooth=bt;},G+10,"rp-rank");await sleep(1900);STARCHORUS.frame();
const ks=[...S.bt.values()].filter(k=>k.target===1).sort((a,b)=>a.rank-b.rank);let hit=0,drawn=0,under=0,undrawn=0;
for(const k of ks){const n=STARCHORUS.nodeScreen(k.id),h=STARCHORUS.hitTest(n.sx,n.sy);if(k.rank<48){drawn++;if(h===k.id)hit++;}else{undrawn++;if(h===k.id)under++;}}
o.marks=ks.length;o.drawn=drawn;o.undrawn=undrawn;o.hitDrawn=hit>=24;o.hitUndrawn=under;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RP_WANT_RANK='{"drawn":48,"errors":0,"hitDrawn":true,"hitUndrawn":0,"marks":120,"undrawn":72}'
rp_run rank "$RP_EV_RANK"
rp_row "radio: bluetooth hit test: 120 fixed addresses, 48 drawn; the drawn ones can be hit (at least half of them: the rest sit under a stronger neighbour), none of the 72 that are not drawn can" "$RP_WANT_RANK"

# ---- Bluetooth: the filter. Key 4 and the BT button hide the marks and the legend row (with its geometry clause), aria-pressed follows, the counts keep the total; it is
# not saved, X does not touch it; no button without an array
RP_EV_KEY="(async()=>{$RP_JS"'
await sleep(900);const key=(k)=>window.dispatchEvent(new KeyboardEvent("keydown",{key:k})),btn=document.querySelector("[data-band=bt]"),bs=()=>{const b=STARCHORUS.stats().bluetooth;return [b.addresses,b.marks,b.shown].join("/")};
const row=()=>STARCHORUS.legendRows().find(r=>r.kind==="bt"),geo=()=>document.getElementById("leg-geometry").textContent;
o.on=[btn.hidden,btn.getAttribute("aria-pressed"),bs(),row().visible,row().cnt,STARCHORUS.getToggles().bands.bt].join("|");
o.geoOn=geo();o.sub=document.getElementById("leg-bt-sub").textContent;
key("4");await sleep(1500);STARCHORUS.frame();
o.off=[btn.getAttribute("aria-pressed"),btn.classList.contains("on"),bs(),row().visible,STARCHORUS.getToggles().bands.bt].join("|");o.geoOff=geo();
const n0=STARCHORUS.nodeScreen("bt:65535:1");o.hit=STARCHORUS.hitTest(n0.sx,n0.sy);
await new Promise(r=>setTimeout(r,400));o.saved=JSON.stringify(STARCHORUS.storageDump()||{}).indexOf("bt")>=0;
key("4");await sleep(1500);o.again=[btn.getAttribute("aria-pressed"),bs()].join("|");
STARCHORUS.setToggles({random:"hide"});await sleep(300);o.xHide=bs();STARCHORUS.setToggles({random:"cloud"});
btn.click();await sleep(200);o.click=[btn.getAttribute("aria-pressed"),STARCHORUS.getToggles().bands.bt].join("|");btn.click();
ld(d=>{delete d.bluetooth;delete d.center.bt_window;delete d.center.bt_hold;},G+30,"rp-none");await sleep(300);
o.none=[btn.hidden,STARCHORUS.stats().bluetooth,row().visible].join("|");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run key "$RP_EV_KEY"
rp_row "radio: bluetooth filter: key 4 and the BT button hide the marks and the legend row with its geometry clause (aria-pressed follows, the counts keep the 9), not saved, X leaves it alone, no button without an array" \
  '{"again":"true|9/6/6","click":"false|false","errors":0,"geoOff":"rings = received signal (dBm), not range · direction is not measured","geoOn":"rings = received signal (dBm), not range · Bluetooth and Wi-Fi share the rings, not the scale · direction is not measured","hit":null,"none":"true||false","off":"false|false|9/6/0|false|false","on":"false|true|9/6/6|true|9|true","saved":false,"sub":"addresses heard in the last 2 min (6-s scans) · filled = fixed address · one hollow mark = rotating addresses of one company in one ring · key 4, not X","xHide":"9/6/6"}'

# ---- Bluetooth: the tooltip says who, how many, how strong and (for a fixed address) how long ago, in one line; a company id without a name says so, an
# address without manufacturer data says 'company not advertised'; a click selects nothing (no pin, no sheet in this release)
RP_EV_TIP="(async()=>{$RP_JS"'
fx.aps=[];fx.unassociated=[];fx.bluetooth.push({addr:"02:00:00:00:04:0a",addr_type:"random-resolvable",rssi:-95,reports:1,last_seen:G-2,company:65534},{addr:"02:00:00:00:04:0b",addr_type:"random",rssi:-45,reports:1,last_seen:G-2});
STARCHORUS.load(fx,"rp-tip");await sleep(1600);
const tip=(id)=>{const n=STARCHORUS.nodeScreen(id);STARCHORUS.hover(n.sx,n.sy);return document.getElementById("tip-body").textContent;};
for(const id of ["bt:65535:1","bt:02:00:00:00:04:09","bt:-:2","bt:65535:2","bt:02:00:00:00:04:08","bt:-:3","bt:65534:3","bt:-:1"])o[id]=tip(id);
STARCHORUS.hover(5,5);o.select=STARCHORUS.select("bt:65535:1");o.detailHidden=document.getElementById("detail").hidden;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run tip "$RP_EV_TIP"
rp_row "radio: bluetooth tooltip: 'Bluetooth LE · Maker A · 3 rotating addresses · -50 dBm strongest · not a device count', the public and the static address with their age, 'company not advertised', 'company id N'; a click selects nothing" \
  '{"bt:-:1":"Bluetooth LE · company not advertised · 1 rotating address · -45 dBm · not a device count","bt:-:2":"Bluetooth LE · company not advertised · 2 rotating addresses · -66 dBm strongest · not a device count","bt:-:3":"Bluetooth LE · company not advertised · 1 rotating address · -83 dBm · not a device count","bt:02:00:00:00:04:08":"Bluetooth LE · company not advertised · -77 dBm · static address · last heard in a window 75 s ago","bt:02:00:00:00:04:09":"Bluetooth LE · Maker A · -63 dBm · public address · last heard in a window 4 s ago","bt:65534:3":"Bluetooth LE · company id 65534 · 1 rotating address · -95 dBm · not a device count","bt:65535:1":"Bluetooth LE · Maker A · 3 rotating addresses · -50 dBm strongest · not a device count","bt:65535:2":"Bluetooth LE · Maker A · 1 rotating address · -72 dBm · not a device count","detailHidden":true,"errors":0,"select":null}'

# ---- Bluetooth: text from the air is text. A hostile company name or name runs no script in the tooltip, the escaped text is there, control characters are stripped
RP_EV_HOST="(async()=>{$RP_JS"'
fx.aps=[];fx.unassociated=[];const H=["<img src=x onerror=window.__x=1>","\"><script>window.__x=1</script>","A\u0000\u0007B\r\nC"];
fx.bluetooth=H.map((h,i)=>({addr:"02:00:00:00:06:0"+i,addr_type:"random-resolvable",rssi:-50-12*i,reports:1,last_seen:G-3,company:60000+i,company_name:h,name:h}));
STARCHORUS.load(fx,"rp-host");await sleep(1600);
const tip=(id)=>{const n=STARCHORUS.nodeScreen(id);STARCHORUS.hover(n.sx,n.sy);const b=document.getElementById("tip-body");return [b.textContent,b.querySelector("img,script")===null];};
o.t=[...S.bt.keys()].sort().map(k=>tip(k));o.noScript=window.__x===undefined;o.exp=JSON.parse(STARCHORUS.exportText("json")).bluetooth.map(b=>b.company_name).sort();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run host "$RP_EV_HOST"
rp_row "radio: hostile strings: a hostile company name runs no script in the tooltip, the escaped text is there, no <img> or <script> in it, control characters gone" \
  '{"errors":0,"exp":["\"><script>window.__x=1</script>","<img src=x onerror=window.__x=1>","ABC"],"noScript":true,"t":[["Bluetooth LE · <img src=x onerror=window.__x=1> · 1 rotating address · -50 dBm · not a device count",true],["Bluetooth LE · \"><script>window.__x=1</script> · 1 rotating address · -62 dBm · not a device count",true],["Bluetooth LE · ABC · 1 rotating address · -74 dBm · not a device count",true]]}'

# ---- Bluetooth: order and cap. Six orders of bluetooth[] give the same counts, marks and positions; 300 records keep the strongest 256 addresses
RP_EV_ORD="(async()=>{$RP_JS"'
const lcg=(s)=>()=>{s=(s*1103515245+12345)&0x7fffffff;return s/0x7fffffff;};
const dig=()=>JSON.stringify([STARCHORUS.stats().bluetooth,[...S.bt.values()].filter(k=>k.target===1).map(k=>{const n=STARCHORUS.nodeScreen(k.id);return [k.id,k.n,k.rssi,k.lx,k.lz,n.sx,n.sy]}).sort()]);
const ds=[],orders=new Set();
for(const seed of [0,1,2,3,4,5]){const d=JSON.parse(JSON.stringify(fx));if(seed){const r=lcg(seed*7919),a=d.bluetooth;for(let i=a.length-1;i>0;i--){const j=Math.floor(r()*(i+1));[a[i],a[j]]=[a[j],a[i]];}}
 orders.add(d.bluetooth.map(b=>b.addr).join());STARCHORUS.load(d,"rp-ord"+seed);await sleep(250);STARCHORUS.settle();ds.push(dig());}
o.same=ds.every(x=>x===ds[0]);o.orders=orders.size;
const bt=[];for(let i=0;i<300;i++)bt.push({addr:"02:00:00:00:05:"+i.toString(16).padStart(2,"0"),addr_type:i%3?"random-resolvable":"public",rssi:-30-Math.floor(i/4),reports:1,last_seen:G-3,company:i%2?65535:null});
ld(d=>{d.aps=[];d.unassociated=[];d.bluetooth=bt;},G+10,"rp-cap");await sleep(800);
const ex=JSON.parse(STARCHORUS.exportText("json")).bluetooth,want=bt.slice().sort((a,c)=>c.rssi-a.rssi||(a.addr<c.addr?-1:1)).slice(0,256).map(x=>x.addr).sort().join();
o.cap=[STARCHORUS.stats().bluetooth.addresses,ex.length,want===ex.map(x=>x.addr).sort().join(),Math.min(...ex.map(x=>x.rssi))].join("/");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run ord "$RP_EV_ORD"
rp_row "radio: bluetooth order invariance (six distinct orders of bluetooth[]: the same counts, marks and positions) and cap (300 records: the strongest 256 addresses, weakest -93 dBm)" \
  '{"cap":"256/256/true/-93","errors":0,"orders":6,"same":true}'

# ---- Bluetooth: reduced motion. With ?rm=1 no mark moves or changes size from frame to frame (opacity may ease)
RP_EV_RM="(async()=>{$RP_JS"'
await sleep(1500);const snap=()=>[...S.bt.values()].map(k=>{const n=STARCHORUS.nodeScreen(k.id);return [k.id,n.sx,n.sy,n.px]}).sort(),far=(x,y)=>Math.max(...x.map((r,i)=>Math.max(Math.abs(r[1]-y[i][1]),Math.abs(r[2]-y[i][2]),Math.abs(r[3]-y[i][3]))));
const a=snap();STARCHORUS.frame();await sleep(1200);STARCHORUS.frame();const b=snap();STARCHORUS.setView("3d");await sleep(3000);STARCHORUS.frame();const c=snap();await sleep(1500);STARCHORUS.frame();
o.still=far(a,b)===0;o.rm=document.documentElement.dataset.rm;o.n=S.bt.size;o.threeD=far(c,snap())<0.25;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run rm "$RP_EV_RM" "$RP_FX" "$RP_Q&rm=1"
rp_row "radio: reduced motion: no mark moves or changes size between frames (2D and 3D)" '{"errors":0,"n":6,"rm":"1","still":true,"threeD":true}'

# ---- 0.1 documents: no layer on any fixture without the new arrays, and the layers leave the Wi-Fi sky where it was (stars and stations at the same
# place with and without the Bluetooth array, the activity array and the station counters)
RP_EV_ABS='(async()=>{const sleep=STARCHORUS.wait,o={};await sleep(1200);const st=STARCHORUS.stats(),btn=document.querySelector("[data-band=bt]"),rows=STARCHORUS.legendRows();
o.v=[btn.hidden,st.bluetooth===null,st.glow.stations,st.activity.channels,["bt","activity","traffic"].map(k=>rows.find(r=>r.kind===k).visible).join("/")].join(",");o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RP_ABS=""; RP_ABSN=0
for RP_F in "$F"/*.json; do
  [ "${RP_F##*/}" = radio-pair.json ] && continue
  rp_run abs "$RP_EV_ABS" "$RP_F" "$RP_Q"; RP_ABSN=$((RP_ABSN + 1))
  [ "$RP_V" = '{"errors":0,"v":"true,true,0,0,false/false/false"}' ] || RP_ABS="$RP_ABS ${RP_F##*/}:$RP_V"
done
rowif "radio: absent = 0.1: on all $RP_ABSN fixtures without the arrays the BT button is hidden, stats().bluetooth is null, no cue, no whisker, no legend row of the new layers [${RP_ABS:-none off}]" [ -z "$RP_ABS" ]
RP_EV_SKY="(async()=>{$RP_JS"'
const snap=()=>{STARCHORUS.settle();return JSON.stringify([STARCHORUS.nodes("ap"),STARCHORUS.nodes("client")].map(l=>l.map(n=>[n.id,n.sx,n.sy,n.px]).sort()));};
await sleep(800);const a=snap();ld(d=>{delete d.bluetooth;delete d.activity;delete d.center.bt_window;delete d.center.bt_hold;d.unassociated.forEach(u=>delete u.packets);},G+5,"rp-sky");await sleep(300);const b=snap();
o.same=a===b;o.n=JSON.parse(a)[0].length+"/"+JSON.parse(a)[1].length;o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run sky "$RP_EV_SKY"
rp_row "radio: the layers leave the Wi-Fi sky where it was: the 10 stars and 20 stations sit at the same place with and without bluetooth[], activity[] and station packets" '{"errors":0,"n":"10/20","same":true}'

# ---- the demo carries the whiskers (and no Bluetooth: see NOT PROVEN) and its two counts are unchanged
RP_EV_DEMO='(async()=>{const sleep=STARCHORUS.wait,o={};await sleep(2500);STARCHORUS.frame();const st=STARCHORUS.stats();o.counts=[document.getElementById("n-ap").textContent,document.getElementById("n-cl").textContent].join("/");
o.layers=[st.bluetooth===null,st.activity.channels,st.activity.max,STARCHORUS.legendRows().find(r=>r.kind==="activity").visible,document.querySelector("[data-band=bt]").hidden].join("/");o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run demo "$RP_EV_DEMO" demo "$RP_Q"
rp_row "radio: demo: #n-ap 11 and #n-cl 33 unchanged, ten whiskers from the demo's own channels (largest share .3), the legend row for them, no Bluetooth layer" '{"counts":"11/33","errors":0,"layers":"true/10/0.3/true/true"}'

# ---- the traffic cue: the rate of a station is its counter's delta over the last captures (at most three), never over a quieter or restarted run.
# Loads 40 s apart: +80 frames = 2.0/s, level 2; +3 = below the floor, not drawn; a counter that fell, a first sight, a spacing over the limit: no rate;
# deltas of 0 and double in turn = one steady rate (1.0/s, level 2: GLOW.rateFull is 5 frames/s, the measured 95th percentile, A8)
RP_EV_RATE="(async()=>{$RP_JS"'
const A="02:00:00:00:02:01",B="02:00:00:00:02:02",C="02:00:00:00:02:03",D="02:00:00:00:02:04",E="02:00:00:00:02:05";
const lp=(m,g,label)=>ld(d=>{d.aps=[];d.bluetooth=[];d.unassociated.forEach(u=>{if(m[u.mac]!==undefined)u.packets=m[u.mac];else delete u.packets;});},g,label);
const nd=(id)=>{const n=STARCHORUS.node(id);return n?[n.fps,n.glow].join("/"):"gone";};
lp({[A]:1520,[B]:310,[C]:48,[D]:9},G,"rp-rate");o.first=[A,B,C,D,E].map(nd).join(" ");
lp({[A]:1600,[B]:313,[C]:40,[D]:9,[E]:5},G+40,"rp-rate");o.second=[A,B,C,D,E].map(nd).join(" ");
lp({[A]:1600,[B]:313},G+40,"rp-rate");o.sameCapture=nd(A);
lp({[A]:1700},G+180,"rp-rate");o.gap=nd(A);
lp({[B]:100},G+300,"rp-alt");lp({[B]:100},G+340,"rp-alt");const a1=nd(B);lp({[B]:180},G+380,"rp-alt");const a2=nd(B);lp({[B]:180},G+420,"rp-alt");o.alt=[a1,a2,nd(B)].join(" ");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run rate "$RP_EV_RATE"
rp_row "radio: cue rate: +80 frames in 40 s = 2/s level 2, +3 = 0.075/s level 0, a counter that fell, a first sight and a 140 s spacing give no rate, 0 and double in turn give 0 then a steady 1/s level 2 (rateFull 5)" \
  '{"alt":"0/0 1/2 1/2","errors":0,"first":"/0 /0 /0 /0 /0","gap":"/0","sameCapture":"2/2","second":"2/2 0.075/0 /0 0/0 /0"}'

# ---- the cue is seen in every theme: the pixels in the zone of the ticks (45 degrees, 5.5 to 9.5 px out) hold more with the cue than without it (the same
# station, the same place, the counter then falling back); the legend names it exactly while a station carries it; a feed that is not live shows none
RP_EV_CUE="(async()=>{$RP_JS"'
const A="02:00:00:00:02:01",lp=(pk,g,label)=>ld(d=>{d.aps=[];d.bluetooth=[];d.unassociated=d.unassociated.slice(0,1);d.unassociated[0].packets=pk;},g,label);
const ldl=(pk,g,label)=>{const d=JSON.parse(JSON.stringify(fx));d.generated=g;d.aps=[];d.bluetooth=[];d.unassociated=d.unassociated.slice(0,1);d.unassociated[0].packets=pk;return STARCHORUS.load(d,label,{mode:"live"});};
const zone=()=>{const n=STARCHORUS.nodeScreen(A);let s=0;for(const th of [45,135,225,315])for(let d=5.5;d<=9.5;d+=0.5)s+=STARCHORUS.pixel("sky",Math.round(n.sx+d*Math.cos(th*Math.PI/180)),Math.round(n.sy+d*Math.sin(th*Math.PI/180))).a;return s;};
const nd=()=>{const n=STARCHORUS.node(A);return [n.fps,n.glow].join("/")},leg=()=>{const r=STARCHORUS.legendRows().find(x=>x.kind==="traffic");return r.visible+":"+document.querySelector("#leg-cue span").textContent;};
const TH=["foundation","wargames","whitehall"],on=[],off=[];
lp(1000,G,"rp-vis");lp(1100,G+40,"rp-vis");await sleep(1800);o.on=nd();
for(const t of TH){STARCHORUS.setTheme(t);STARCHORUS.frame();await sleep(200);STARCHORUS.frame();on.push(zone());}
o.legOn=leg();lp(50,G+80,"rp-vis");await sleep(1800);o.off=nd();
for(const t of TH){STARCHORUS.setTheme(t);STARCHORUS.frame();await sleep(200);STARCHORUS.frame();off.push(zone());}
o.legOff=leg().split(":")[0];o.seen=TH.map((t,i)=>on[i]-off[i]>=300).join();
STARCHORUS.setTheme("foundation");
ldl(1000,G+300,"rp-live");ldl(1100,G+340,"rp-live");await sleep(1800);const st=()=>STARCHORUS.stats();o.live=[nd(),st().glow.stations,st().captureStale,leg().split(":")[0]].join("/");
S.staleMs=1e9;STARCHORUS.frame();await sleep(1800);STARCHORUS.frame();o.stale=[st().glow.stations,JSON.stringify(st().glow.levels),STARCHORUS.perf().drawCalls.traffic,st().captureStale].join("/");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run cue "$RP_EV_CUE"
rp_row "radio: cue visible in all three themes (ticks at 45 degrees add >= 300 alpha over the same station without the cue), legend row 'station ticks = …' exactly while a station carries it, none on a stale feed (stations 0, levels 0/0/0, no blit)" \
  '{"errors":0,"legOff":"false","legOn":"true:station ticks = frames heard from it per second (depends on where the radio listens)","live":"2.5/3/1/false/true","off":"/0","on":"2.5/3","seen":"true,true,true","stale":"0/[0,0,0]/0/true"}'

# ---- the cue's budget and words: with 40 rated stations exactly 24 are drawn with it (the 24 highest rates), no gradient is built in the frame;
# the station sheet states the rate and its real span, or that there is one capture so far
RP_EV_BUD="(async()=>{$RP_JS"'
const mk=(g,k)=>{const d=JSON.parse(JSON.stringify(fx));d.generated=g;d.aps=[];d.bluetooth=[];d.unassociated=[];for(let i=0;i<40;i++)d.unassociated.push({mac:"02:00:00:00:07:"+i.toString(16).padStart(2,"0"),rssi:-45-i,last_seen:g-5,vendor:"Vendor G",packets:1000+(k?Math.round((0.6+i*0.5)*40):0)});return d;};
STARCHORUS.setToggles({agg:false});STARCHORUS.load(mk(G,0),"rp-bud");STARCHORUS.load(mk(G+40,1),"rp-bud");await sleep(2000);STARCHORUS.frame();
const st=STARCHORUS.stats();o.stations=st.glow.stations;o.max=st.glow.max;o.levels=st.glow.levels.reduce((a,b)=>a+b,0);o.blits=STARCHORUS.perf().drawCalls.traffic;o.gradient=STARCHORUS.perf().drawCalls.gradient;
const cs=[...S.clients.values()],top=cs.filter(c=>c.cue).map(c=>c.fps).sort((a,b)=>a-b)[0];o.highest=cs.filter(c=>!c.cue&&c.fps!=null).every(c=>c.fps<=top);
const sheet=(id)=>{STARCHORUS.select(id);const r=[...document.querySelectorAll("#detail-body tr")].map(x=>x.cells[0].textContent+"="+x.cells[1].textContent).filter(x=>/^Frames/.test(x)).join(";");STARCHORUS.deselect();return r;};
o.sheet=sheet("02:00:00:00:07:27");
ld(d=>{d.aps=[];d.bluetooth=[];d.unassociated=d.unassociated.slice(0,2);},G+400,"rp-one");o.one=sheet("02:00:00:00:02:01");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run bud "$RP_EV_BUD"
rp_row "radio: cue budget and words: 40 rated stations, exactly 24 cue blits for the 24 highest rates, no gradient in the frame; 'Frames heard: about 20.1/s over the last 40 s' and '— (one capture so far)'" \
  '{"blits":24,"errors":0,"gradient":0,"highest":true,"levels":24,"max":24,"one":"Frames heard=— (one capture so far)","sheet":"Frames heard=about 20.1/s over the last 40 s","stations":24}'

# ---- activity kept apart: it never enters the visited set of the D19 ghosts or the Watchlist's 'not heard now'. The baseline holds the 5 GHz channel-100 AP and the Watchlist
# its SSID; the next captures lack the AP, have no channels[] and activity on 5500 MHz: no ghost, no 'not heard now'. Control: the same captures with channels[] naming 5500
# give one ghost and the Watchlist line
RP_EV_APART="(async()=>{$RP_JS"'
const AP="02:00:00:00:01:0b",HUB="Hub-4432";
const lb=(m,g)=>ld(d=>{d.bluetooth=[];if(m)m(d);},g,"rp-apart");const B=()=>{const b=STARCHORUS.baseline();return [b.new,b.gone,b.changed,b.ghosts].join("/")},obs=()=>STARCHORUS.observations().filter(x=>x.group==="Watchlist").map(x=>x.text).join("|");
const ch=(g)=>(d)=>{d.channels=[{freq:5500,last_heard:g}];};
lb(ch(G),G);STARCHORUS.setBaseline();STARCHORUS.setToggles({baselineDiff:true});STARCHORUS.watch(HUB,true);lb(ch(G+30),G+30);o.present=obs();
const gone=(d)=>{d.aps=d.aps.filter(a=>a.bssid!==AP);delete d.channels;d.activity=[{freq:5500,share:0.5},{freq:2412,share:0.5}];};
lb(gone,G+60);lb(gone,G+75);o.hopNull=STARCHORUS.stats().hop===null;o.noHop=B();o.watchNoHop=obs();o.activity=STARCHORUS.stats().activity.channels;
lb(d=>{gone(d);d.channels=[{freq:5500,last_heard:G+90}];},G+90);lb(d=>{gone(d);d.channels=[{freq:5500,last_heard:G+120}];},G+120);o.control=B()+"|"+obs();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run apart "$RP_EV_APART"
rp_row "radio: activity kept apart: activity on 5500 MHz with no channels[] gives S.hop null, no ghost, no 'not heard now'; with channels[] it does (control)" \
  '{"activity":2,"control":"0/1/0/1|watched SSID not heard now: Hub-4432","errors":0,"hopNull":true,"noHop":"0/0/0/0","present":"watched SSID present: Hub-4432","watchNoHop":""}'

# ---- exports: JSON carries bluetooth[] (nine addresses with the mark each is drawn in, the heard word, no exact time) and bluetooth_counts, and a station's rate; the CSV is the 0.1 table
# (14 columns, every row as wide: Bluetooth addresses are not in it)
RP_EV_EXP="(async()=>{$RP_JS"'
const A="02:00:00:00:02:01";ld(d=>{d.unassociated.forEach(u=>{if(u.mac===A)u.packets=1000;else delete u.packets;});},G,"rp-exp");ld(d=>{d.unassociated.forEach(u=>{if(u.mac===A)u.packets=1100;else delete u.packets;});},G+40,"rp-exp");await sleep(300);
const J=JSON.parse(STARCHORUS.exportText("json")),csv=STARCHORUS.exportText("csv").split("\n");
o.keys=Object.keys(J).join(",");o.apKeys=[...new Set(J.aps.flatMap(a=>Object.keys(a)))].sort().join();o.bt=J.bluetooth.length+":"+Object.keys(J.bluetooth[0]).join(",");o.counts=JSON.stringify(J.bluetooth_counts);o.noTime=JSON.stringify(J.bluetooth).indexOf("last_seen")<0;
o.rate=J.stations.filter(s=>s.rate!==undefined).map(s=>s.mac+"="+s.rate).join(",");
o.head=csv[0];o.widths=[...new Set(csv.filter(l=>l&&l[0]!=="#").map(l=>l.split(",").length))].join();o.csvBt=csv.filter(l=>/^bluetooth,/.test(l)).length;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
rp_run exp "$RP_EV_EXP"
rp_row "radio: exports: JSON bluetooth[] (9 addresses, the mark of each, a heard word, no exact time), bluetooth_counts, no name field on a hidden network, a station rate of 2.5; the CSV is the 0.1 table, 14 columns, every row as wide, no Bluetooth row" \
  '{"apKeys":"band,bssid,channel,class,heard,rssi,security,ssid","bt":"9:addr,addr_type,rssi,reports,company,company_name,name,connectable,heard,mark","counts":"{\"addresses\":9,\"marks\":6,\"rotating\":7,\"fixed\":2,\"window\":6,\"hold\":120}","csvBt":0,"errors":0,"head":"kind,bssid,ssid,band,channel,security,rssi,heard,alias,tags,association,randomized,probes,cloud","keys":"footer,generated,source,aps,stations,station_counts,mobile_hotspots,crowding,bluetooth,bluetooth_counts","noTime":true,"rate":"02:00:00:00:02:01=2.5","widths":"14"}'
RP_DB=$(grep -c 'doc.unassociated.length \* 160 + (doc.bluetooth ? doc.bluetooth.length \* 150 : 0);' "$H")
rowif "radio: docBytes counts bluetooth[] at 150 bytes a record ($RP_DB)" [ "$RP_DB" = 1 ]

# ---- neutral language (P10) and the legal denylist over everything the new layers print: the legend, the tooltips of a folded, a public and a static mark, the sheet of the
# named hidden network and of a rated station, the Air drawer and the exports, in all three themes
RP_P10_RE='(?a)\b(evil[ -]?twin|rogue|attack(er)?|threat|intru(der|sion)|malicious|spoof(ed|ing)?|karma|bandit|target|deauth flood)\b'
RP_EV_TXT="(async()=>{$RP_JS"'
const seen=new Set(),add=(s)=>{for(const l of String(s==null?"":s).split("\n")){const t=l.trim();if(t)seen.add(t);}};
const d0=JSON.parse(JSON.stringify(fx));d0.unassociated.forEach(u=>{if(u.mac==="02:00:00:00:02:01")u.packets=1000;});STARCHORUS.load(d0,"rp-txt");d0.generated+=40;d0.unassociated.forEach(u=>{if(u.mac==="02:00:00:00:02:01")u.packets=1100;});STARCHORUS.load(d0,"rp-txt");await sleep(1800);
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);STARCHORUS.openDrawer(null);await sleep(300);STARCHORUS.frame();add(document.getElementById("legend").innerText);
 for(const id of ["bt:65535:1","bt:02:00:00:00:04:09","bt:02:00:00:00:04:08","bt:-:3"]){const n=STARCHORUS.nodeScreen(id);STARCHORUS.hover(n.sx,n.sy);add(document.getElementById("tip-body").textContent);}
 for(const id of ["02:00:00:00:01:06","02:00:00:00:02:01"]){STARCHORUS.select(id);add(document.getElementById("detail-title").textContent);add(document.getElementById("detail-body").innerText);const n=STARCHORUS.nodeScreen(id);STARCHORUS.hover(n.sx,n.sy);add(document.getElementById("tip-body").textContent);STARCHORUS.deselect();}
 STARCHORUS.hover(5,5);add(document.body.innerText);for(const e of document.querySelectorAll("[title],[aria-label]")){add(e.getAttribute("title"));add(e.getAttribute("aria-label"));}STARCHORUS.openDrawer("air");await sleep(200);add(document.getElementById("air-body").innerText);}
for(const f of ["json","csv","sitrep"])add(STARCHORUS.exportText(f));
return [...seen].join("\n");})()'
runq "$RP_FX" "$RP_Q" "out/$P-rp-txt" --fps 0 --wait 3 --ready "$RP_RDY" --eval-timeout 120 --eval "$RP_EV_TXT" >/dev/null 2>&1
evalv "out/$P-rp-txt.json" 1 > "out/$P-rp-txt.txt"
RP_TN=$(wc -l < "out/$P-rp-txt.txt" | tr -d ' ')
RP_TH=$(python3 - "out/$P-rp-txt.txt" "$RP_P10_RE" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8", errors="replace").read()
need = ["Bluetooth LE (passive scan)", "not a device count", "station ticks = frames heard", "Frames heard", "thin line in a channel bar"]
miss = [n for n in need if n not in t]
hits = [m.group(0) for m in re.finditer(sys.argv[2], t, re.I)]
print("ok" if not hits and not miss else "hits=%s missing=%s" % (hits[:5], miss))
PY
)
RP_TD=$(sh tools/denylist-check.sh "$R/out/$P-rp-txt.txt" 2>&1); RP_TDR=$?
RP_TOK=0; [ "$RP_TH" = ok ] && [ "$RP_TDR" = 0 ] && RP_TOK=1
rowif "radio: neutral language (P10) and the legal denylist hold over $RP_TN lines of legend, tooltips, sheets, Air drawer and exports in 3 themes [$RP_TH]" [ "$RP_TOK" = 1 ]
[ "$RP_TDR" = 0 ] || printf '%s\n' "$RP_TD" | cut -c1-170 | sed 's/^/    /'

# ---- the probes bite: one-line copies of the page, each run on the eval its rule keeps right. A copy must differ in exactly the named keys of the answer (the unmutated page
# is the control: the rows above). Each anchor occurs exactly once in the page and each replacement changes exactly that text.
rp_probe() {   # rp_probe NAME EVAL_TEXT WANT_JSON KEYS OLD NEW [OLD NEW ...]   KEYS = the keys of the answer that must differ, sorted, comma-separated
  _pn=$1; _pe=$2; _pw=$3; _pk=$4; shift 4
  if python3 - "$H" "out/$P-rp-mut-$_pn.html" "$@" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read(); a = sys.argv[3:]
for i in range(0, len(a), 2):
    if t.count(a[i]) != 1: sys.exit("anchor %d: %d occurrences" % (i // 2, t.count(a[i])))
    t = t.replace(a[i], a[i + 1])
open(sys.argv[2], "w", encoding="utf-8").write(t)
PY
  then
    RP_HKEEP=$H; H="out/$P-rp-mut-$_pn.html"; rp_run "mut-$_pn" "$_pe"; H=$RP_HKEEP
    _pd=$(python3 - "$RP_V" "$_pw" <<'PY'
import json, sys
g, w = json.loads(sys.argv[1] or "{}"), json.loads(sys.argv[2])
print(",".join(sorted(k for k in set(g) | set(w) if g.get(k) != w.get(k))))
PY
    )
  else _pd="anchor"; fi
  if [ "$_pd" = "$_pk" ]; then RP_PROBES="$RP_PROBES $_pn"; else RP_PBAD="$RP_PBAD [$_pn: differs in '$_pd', want '$_pk']"; fi
}
RP_PROBES=""; RP_PBAD=""
RP_WANT_ING='{"counts":"9/6/7/2/6/6/120/false","errors":0,"marks":"bt:-:2 bt:-:3 bt:02:00:00:00:04:08 bt:02:00:00:00:04:09 bt:65535:1 bt:65535:2","members":"-:2=2r -:3=1r 02:00:00:00:04:08=1f 02:00:00:00:04:09=1f 65535:1=3r 65535:2=1r","posSame":true,"radius2d":"ok","radius3d":"ok"}'
rp_probe angle "$RP_EV_ING" "$RP_WANT_ING" radius2d \
  '    homeOfClient(k);
  });
  S.bt.forEach((k, id) => {' '    k.lx = Math.cos(hash(k.mac) * 6.2832) * 0.5; k.lz = Math.sin(hash(k.mac) * 6.2832) * 0.5;
  });
  S.bt.forEach((k, id) => {' \
  'S.bt.forEach(k => { homeOfClient(k);' 'S.bt.forEach(k => { k.lx = Math.cos(hash(k.mac) * 6.2832) * 0.5; k.lz = Math.sin(hash(k.mac) * 6.2832) * 0.5;'
rp_probe hysteresis "$RP_EV_ID" "$RP_WANT_ID" "backIn3db,in3db" 'hystDb: 3,' 'hystDb: 0,'
RP_WANT_APART='{"activity":2,"control":"0/1/0/1|watched SSID not heard now: Hub-4432","errors":0,"hopNull":true,"noHop":"0/0/0/0","present":"watched SSID present: Hub-4432","watchNoHop":""}'
rp_probe hop "$RP_EV_APART" "$RP_WANT_APART" "hopNull,noHop,watchNoHop" 'S.hop = doc.channels || null;' 'S.hop = doc.channels || (doc.activity && doc.activity.map(a => ({ freq: a.freq }))) || null;'
RP_WANT_RATE='{"alt":"0/0 1/2 1/2","errors":0,"first":"/0 /0 /0 /0 /0","gap":"/0","sameCapture":"2/2","second":"2/2 0.075/0 /0 0/0 /0"}'
rp_probe twosamples "$RP_EV_RATE" "$RP_WANT_RATE" alt 'const e = s[s.length - 1], r = s.length > 1 ? (e[1] - s[0][1]) / (e[0] - s[0][0]) : null,' 'const e = s[s.length - 1], f0 = s[s.length - 2] || s[0], r = s.length > 1 ? (e[1] - f0[1]) / (e[0] - f0[0]) : null,'
rp_probe floor "$RP_EV_RATE" "$RP_WANT_RATE" "alt,second" 'n.gl = t < GLOW.min ? 0 : Math.ceil(t * 3);' 'n.gl = r == null ? 0 : Math.max(1, Math.ceil(t * 3));'
RP_WANT_CUE='{"errors":0,"legOff":"false","legOn":"true:station ticks = frames heard from it per second (depends on where the radio listens)","live":"2.5/3/1/false/true","off":"/0","on":"2.5/3","seen":"true,true,true","stale":"0/[0,0,0]/0/true"}'
rp_probe stale "$RP_EV_CUE" "$RP_WANT_CUE" stale 'const gT = n.cue && !stale ? 1 : 0;' 'const gT = n.cue ? 1 : 0;'
rp_probe fresh "$RP_EV_DRAWN" "$RP_WANT_DRAWN" drawn 'setAlpha(ctx, k.alphaDraw * k.freshA); blit(ctx, getSprite("bt", "bt"' 'setAlpha(ctx, k.alphaDraw); blit(ctx, getSprite("bt", "bt"'
rp_probe rank "$RP_EV_RANK" "$RP_WANT_RANK" hitUndrawn 'if (k.target === 1 && k.rank < BT.drawMax) near(k, hitRadius(k, touch));' 'if (k.target === 1) near(k, hitRadius(k, touch));'
RP_PN=$(echo "$RP_PROBES" | wc -w | tr -d ' ')
RP_PK=0; [ "$RP_PN" = 8 ] && [ -z "$RP_PBAD" ] && RP_PK=1
rowif "radio: the probes bite ($RP_PN of 8: marks by angle, hysteresis 0, activity in S.hop, a rate over two samples, no cue floor, no stale guard, marks drawn without their age, hit test over marks that are not drawn), each turns exactly its keys red${RP_PBAD}" [ "$RP_PK" = 1 ]
