# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/remote-id.sh -- Remote ID on the page (0.2.7). A Bluetooth record that carries bluetooth[].remote_id is a mark of its own (never folded
# into a mark of rotating addresses, never joined to another address that broadcasts the same id); its tooltip and its sheet say what the broadcast says,
# as text: the aircraft type, the status, the id, the position and the operator position as numbers with seven decimals, the altitude in m, 'as broadcast,
# not checked'. The CSV gains ten columns on the right and the SITREP a block only while a record has Remote ID; the JSON carries remote_id as it stands.
# The document is generated (gen-testdata.py --remote-id, into out/ only): no stored fixture carries Remote ID, so no row that reads them moves.
#   R1 the generator, the documented document, and the validator (twenty-six broken remote_id, one at the kept edge; R1b a NaN literal is not JSON to it) · R2 the page keeps of each broken remote_id exactly the keys
#   the validator does not refuse · R3 the marks · R4 the tooltips, word for word · R5 the sheets (a real click too; a mark without Remote ID selects
#   nothing; no input, identity or pin; no storage key) · R6 the selection ring in three themes · R7 the exports, word for word · R8 without Remote ID the
#   exports and marks are those of a page copy with the feature planted out · R9 hostile text · R10 a position is never carried into a later capture ·
#   R11 the words (one named phrase let through, with a control and a leak dummy) · R12 the page's word lists are the validator's · R14 GET only ·
#   R15 planted copies · R16 operator to aircraft, the one figure the page works out from a broadcast, in ten scenes · R16b its three probes · R17 the
#   plan of the two positions under the sheet's rows, to scale and north up, in thirteen scenes · R18 the plan in three themes · R19 the plan on a phone ·
#   R20 every aircraft among the drawn marks · R20b the plan's eleven probes
# GUARDS AGAINST: a validator that takes a document the browser cannot parse (a NaN or Infinity literal) or a position that prints as 0/0; a record with Remote ID folded into the mark of its company and ring, or two addresses joined by the id they broadcast; a word, an id or a
#                 number that is not on the contract's lists or in its range shown as if broadcast; text from the air that becomes markup; a position from
#                 an earlier capture shown with a later one; a sheet for a mark without Remote ID, or one with an input, an identity or a pin; a selected
#                 mark without its ring; an export that changes for a capture without Remote ID; a word of P10, of direction or distance, or track, pilot,
#                 locate, scanner, away, near in anything the feature prints; the page's word lists drifting from the validator's; a figure worked out from one
#                 pair, with lat and lon swapped, on a flat earth or the long way across the seam; the figure in the JSON or the CSV; a plan with east and
#                 west or north and south swapped, its ends mislabelled, without the freshness of its mark, with two close points drawn far apart or their labels
#                 dragged onto the other point, an altitude printed without one, a scale bar whose drawn length is not its label's, a figure under its own
#                 line, or a colour or style set on the drawing itself; an aircraft
#                 that is not among the drawn and hit marks while stronger addresses are about; a direction word beyond the one named phrase, or a dead exception.
# NEGATIVE PROBE: R15 runs the evals on planted copies of the page, each differing from it in the lines named: the sheet's esc removed, a sheet for every
#                 mark, Remote ID folded again, the position carried over from the capture before, no ring in drawBt, and a word outside its list kept;
#                 each turns exactly its own keys red; R16b's three copies (the cosine term swapped, a flat earth, a figure from one pair) turn
#                 exactly their scenes red (the one-pair copy in the SITREP as well, which lists every record); R20b's eleven copies (east and west swapped,
#                 north and south swapped, the close-range cap gone, the ends mislabelled, the freshness dropped, the stacked labels fixed upward, a style on
#                 the drawing itself, an altitude always printed, the bar drawn at the wrong length, the figure back on its line, the ranking removed) turn
#                 exactly their scenes red; R11 reads its ok dummy once more without the exception (red on the note's 'north') and a leak dummy must stay flagged.
#                 R8's copy (normRid, the group key and the export rows planted out) must differ from the page in
#                 the capture with Remote ID only. The word judges flag a dummy, the list judge a changed word.
# NOT PROVEN:     a broadcast heard by a Pager (the decoder is checked against the standard and synthetic packs in the collector's self-test, not in
#                 the field); the sheet in the Scope's fan and in 3D after the camera's flight (the same openDetail as on the desktop and the phone, not run there); how a
#                 newcomer reads 'as broadcast, not checked'; the figure on a real broadcast, whose operator position may be a take-off point or held from
#                 an earlier capture without an age.
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only RI_* globals and ri_* functions (with their _ri_* locals) are set.

RI_T="out/$P-ri"; mkdir -p "$RI_T"
RI_FX="$RI_T/remote-id.json"
RI_Q="?poll=0&spin=0&intro=0&debug=1"
RI_RDY="window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'"
ri_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }
# ri_run NAME EVAL [PAGE]: one run on the generated document, on PAGE (a planted copy) when given; RI_V = the eval's value (normalised JSON), RI_E = the page's error count
ri_run() {
  _ri_n=$1; _ri_e=$2; _ri_k=$H; if [ -n "${3:-}" ]; then H=$3; fi
  runq "$RI_FX" "$RI_Q" "$RI_T/$_ri_n" --fps 0 --wait 3 --ready "$RI_RDY" --eval-timeout 120 --eval "$_ri_e" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
  H=$_ri_k
  RI_V=$(evalv "$RI_T/$_ri_n.json" 1 | ri_nj); RI_E=$(evalv "$RI_T/$_ri_n.json" 2)
}
ri_row() {   # ri_row LABEL WANT_JSON: RI_V against WANT_JSON (normalised) and RI_E against 0
  _ri_w=$(printf '%s' "$2" | ri_nj)
  if [ "$RI_V" = "$_ri_w" ] && [ "$RI_E" = 0 ]; then row "$1" PASS
  else row "$1 (err ${RI_E:-?})" FAIL; echo "    got:  $(printf '%s' "$RI_V" | cut -c1-700)"; echo "    want: $_ri_w"; fi
}
# the preamble of every eval: the served document, a loader with a mutation, the addresses by their last octet, the live marks (a mark of the boot sky that still fades is not one)
RI_JS='const I=STARCHORUS._internals,S=I.S,sleep=STARCHORUS.wait,o={};await sleep(900);const fx=await (await fetch("starchorus.json")).json(),G=fx.generated;
const ld=(mut,gen,label)=>{const d=JSON.parse(JSON.stringify(fx));if(gen!=null)d.generated=gen;if(mut)mut(d);return STARCHORUS.load(d,label||"ri");};
const A=(n)=>"02:00:00:00:0d:0"+n,M=(n)=>"bt:"+A(n),E=(i)=>document.getElementById(i),live=()=>[...S.bt.values()].filter(k=>k.target===1).map(k=>k.id).sort();'
RI_RID='["Aircraft=multirotor · airborne","ID=TEST-ID.0001 · serial","Position=lat 0.5000000, lon -30.2500000","Altitude=120.5 m","Operator position=lat 0.7500000, lon -30.5000000","Operator ID=OP-TEST_01","Operator–aircraft=39,300 m (derived, horizontal)"]'
RI_NOTE='Remote ID · as broadcast, not checked'

# ---- R1 the document and the validator
python3 tools/gen-testdata.py --remote-id --out "$RI_FX" 2>/dev/null; RI_G=$?
python3 tools/gen-testdata.py --remote-id --out "$RI_T/again.json" 2>/dev/null
RI_VAL=$(python3 tools/gen-testdata.py --validate "$RI_FX" 2>&1 | tail -n 1)
RI_GT=$(python3 - "$RI_FX" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); bt = d["bluetooth"]; rs = [b["remote_id"] for b in bt if "remote_id" in b]
pos = [(r[p + "lat"], r[p + "lon"]) for r in rs for p in ("", "operator_") if p + "lat" in r]
ids = [r[k] for r in rs for k in ("uas_id", "operator_id") if k in r]
ok = len(bt) == 7 and len(rs) == 4 and all(b["addr"].startswith("02:00:00:00:0d:") for b in bt) and len(pos) == 3 and all(-1 <= a <= 1 and -31 <= o <= -29 for a, o in pos) \
     and len(ids) == 3 and all(i.startswith(("TEST-", "OP-TEST")) for i in ids)
print("ok" if ok else "bt=%d rid=%d pos=%s ids=%s" % (len(bt), len(rs), pos, ids))
PY
)
RI_OK=0; if [ "$RI_G" = 0 ] && cmp -s "$RI_FX" "$RI_T/again.json" && [ "$RI_GT" = ok ]; then case $RI_VAL in *" OK") RI_OK=1 ;; esac; fi
rowif "remote id: gen-testdata.py --remote-id writes the same bytes twice, the document validates and is the documented one (seven addresses 02:00:00:00:0d:*, four with remote_id, three positions on the open Atlantic, TEST ids) [$RI_VAL; $RI_GT]" [ "$RI_OK" = 1 ]
RI_VB=$(python3 - "$RI_FX" <<'PY'
import copy, importlib.util, json, sys
spec = importlib.util.spec_from_file_location("g", "tools/gen-testdata.py"); g = importlib.util.module_from_spec(spec); sys.dont_write_bytecode = True; spec.loader.exec_module(g)
doc = json.load(open(sys.argv[1]))
def mut(f):
    d = copy.deepcopy(doc); f(d["bluetooth"][0]); return d
def up(**kw):
    return lambda b: b["remote_id"].update(kw)
cases = [
  ("not an object", lambda b: b.update(remote_id="x")), ("empty", lambda b: b.update(remote_id={})), ("a list", lambda b: b.update(remote_id=[b["remote_id"]])),
  ("key order", lambda b: b.update(remote_id=dict(reversed(list(b["remote_id"].items()))))), ("unknown key", up(speed=3)),
  ("ua_type", up(ua_type="drone")), ("status", up(status="flying")), ("id_type", up(id_type="ssn")),
  ("uas_id quote", up(uas_id='TE"ST')), ("uas_id 21", up(uas_id="T" * 21)), ("uas_id empty", up(uas_id="")), ("uas_id number", up(uas_id=12345)),
  ("operator_id blank", up(operator_id="OP TEST")), ("lat 91", up(lat=91)), ("lon -181", up(lon=-181)),
  ("lat alone", lambda b: b["remote_id"].pop("lon")), ("operator_lat alone", lambda b: b["remote_id"].pop("operator_lon")),
  ("lat text", up(lat="0.5")), ("lat true", up(lat=True)), ("alt_m text", up(alt_m="120.5")),
  ("alt_m 40000", up(alt_m=40000)), ("alt_m -1000", up(alt_m=-1000)), ("lat NaN", up(lat=float("nan"))), ("0/0", up(lat=0, lon=0)), ("rounds to 0/0", up(lat=1e-9, lon=0)),
  ("prints as 0/0 at the edge", up(lat=5e-8, lon=0)),   # the double 5e-8 lies just below 0.00000005 and prints as 0.0000000
]
bad = [n for n, f in cases if not any("remote_id" in p for p in g.validate(mut(f)))]
kept = [p for p in g.validate(mut(up(lat=5.0000000000000004e-8, lon=0, alt_m=31767.5))) if "remote_id" in p]   # the next double above 5e-8 prints as 0.0000001: kept, with the altitude at its top
print("%d/%d %s%s%s" % (len(cases) - len(bad), len(cases), "clean" if not g.validate(doc) else "fixture refused", "" if not bad else " not refused: " + ", ".join(bad), " kept edge ok" if not kept else " kept edge refused: " + "; ".join(kept)))
PY
)
rowif "remote id: the validator refuses twenty-six broken remote_id (not an object, empty, a list, another key order, an unknown key, a word of no list for each of the three lists, an id with a quote, of 21 characters, empty or a number, an operator id with a blank, lat 91, lon -181, lat without lon twice, lat as text or true, alt_m as text, 40000 or -1000, lat NaN, a position of 0/0, one that rounds to it at seven places and one at the edge, lat 5e-8, which prints as 0.0000000) and passes the document and one at the kept edge (the next double above 5e-8, altitude 31767.5) [$RI_VB]" [ "$RI_VB" = "26/26 clean kept edge ok" ]

# ---- R1b a document with a NaN literal is not JSON to the validator, as it is not to the browser: json.load would take NaN, Infinity and -Infinity, JSON.parse never does,
# so a document that validated could have shown nothing; now one PROBLEM line, FAILED and exit 1, no traceback
sed 's/120\.5/NaN/' "$RI_FX" > "$RI_T/nan.json"
python3 tools/gen-testdata.py --validate "$RI_T/nan.json" > "$RI_T/nan.txt" 2>&1; RI_VNR=$?
RI_VN=$(tr '\n' ' ' < "$RI_T/nan.txt")
RI_VNOK=0; case $RI_VN in "PROBLEM: NaN is not JSON"*"nan.json: FAILED ") [ "$RI_VNR" = 1 ] && [ "$(grep -c . "$RI_T/nan.txt")" = 2 ] && RI_VNOK=1 ;; esac
rowif "remote id: a document with a NaN literal is not JSON to the validator, as to the browser: one PROBLEM line naming it, FAILED, exit $RI_VNR, no traceback [$RI_VN]" [ "$RI_VNOK" = 1 ]

# ---- R2 the page drops what the validator refuses, key by key, and keeps the rest in the contract's order (the same twenty-six mutations of 02:00:00:00:0d:01, and one at the kept edge)
RI_EV_PAR="(async()=>{$RI_JS"'
const V={notobj:r=>{r.remote_id="x";},empty:r=>{r.remote_id={};},list:r=>{r.remote_id=[r.remote_id];},order:r=>{r.remote_id=Object.fromEntries(Object.entries(r.remote_id).reverse());},unknown:r=>{r.remote_id.speed=3;},
 ua:r=>{r.remote_id.ua_type="drone";},status:r=>{r.remote_id.status="flying";},idt:r=>{r.remote_id.id_type="ssn";},quote:r=>{r.remote_id.uas_id="TE\"ST";},long:r=>{r.remote_id.uas_id="T".repeat(21);},
 idempty:r=>{r.remote_id.uas_id="";},idnum:r=>{r.remote_id.uas_id=12345;},opblank:r=>{r.remote_id.operator_id="OP TEST";},lat91:r=>{r.remote_id.lat=91;},lon181:r=>{r.remote_id.lon=-181;},
 latalone:r=>{delete r.remote_id.lon;},opalone:r=>{delete r.remote_id.operator_lon;},lattext:r=>{r.remote_id.lat="0.5";},lattrue:r=>{r.remote_id.lat=true;},alttext:r=>{r.remote_id.alt_m="120.5";},
 alt40k:r=>{r.remote_id.alt_m=40000;},altlow:r=>{r.remote_id.alt_m=-1000;},latnan:r=>{r.remote_id.lat=NaN;},zero:r=>{r.remote_id.lat=0;r.remote_id.lon=0;},round0:r=>{r.remote_id.lat=1e-9;r.remote_id.lon=0;},edge:r=>{r.remote_id.lat=5e-8;r.remote_id.lon=0;},
 kept:r=>{r.remote_id.lat=5.0000000000000004e-8;r.remote_id.lon=0;r.remote_id.alt_m=31767.5;}};
const K=["ua_type","id_type","uas_id","status","lat","lon","alt_m","operator_lat","operator_lon","operator_id"],out=[];let g=G;
for(const [n,f] of Object.entries(V)){ld(d=>f(d.bluetooth.find(b=>b.addr===A(1))),g+=30,"ri-par");await sleep(20);const r=JSON.parse(STARCHORUS.exportText("json")).bluetooth.find(x=>x.addr===A(1)).remote_id;
 out.push(n+":"+(r?K.filter(k=>!(k in r)).join("+")+(Object.keys(r).join()===K.filter(k=>k in r).join()?"":"!order"):"none"));}
o.parity=out.join(" ");o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RI_W_PAR='{"errors":0,"parity":"notobj:none empty:none list:none order: unknown: ua:ua_type status:status idt:id_type quote:uas_id long:uas_id idempty:uas_id idnum:uas_id opblank:operator_id lat91:lat+lon lon181:lat+lon latalone:lat+lon opalone:operator_lat+operator_lon lattext:lat+lon lattrue:lat+lon alttext:alt_m alt40k:alt_m altlow:alt_m latnan:lat+lon zero:lat+lon round0:lat+lon edge:lat+lon kept:"}'
ri_run par "$RI_EV_PAR"
ri_row "remote id: of each of the twenty-six broken remote_id the page keeps exactly the keys the validator does not refuse, in the contract's order (nothing of a non-object, an empty object or a list; a key order put right; an unknown key, a word of no list, a bad id, a lone, out-of-range, NaN or non-numeric position, a position of 0/0 exact, at seven places or at the edge 5e-8, and a text or out-of-range altitude dropped); one at the kept edge (the next double above 5e-8, altitude 31767.5) keeps every key" "$RI_W_PAR"

# ---- R3 the marks: seven addresses in six marks; the four with Remote ID are marks of their own (0d:01 and 0d:04 broadcast one id and stay two marks); the two
# rotating addresses of Maker A in ring 1 without it fold as before
RI_EV_ING="(async()=>{$RI_JS"'
const b=STARCHORUS.stats().bluetooth,L=live().map(id=>S.bt.get(id));o.counts=[b.addresses,b.marks,b.rotating,b.fixed].join("/");
o.members=L.map(k=>k.id.slice(3)+"="+k.n+(k.rot?"r":"f")).sort().join(" ");
o.sameId=L.filter(k=>k.m.some(r=>r.remote_id&&r.remote_id.uas_id==="TEST-ID.0001")).map(k=>k.id).sort().join(" ");
o.folded=S.bt.get("bt:65535:1").m.map(r=>r.addr+(r.remote_id?"+rid":"")).join(" ");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RI_W_ING='{"counts":"7/6/5/2","errors":0,"folded":"02:00:00:00:0d:05 02:00:00:00:0d:06","members":"02:00:00:00:0d:01=1r 02:00:00:00:0d:02=1r 02:00:00:00:0d:03=1f 02:00:00:00:0d:04=1r 02:00:00:00:0d:07=1f 65535:1=2r","sameId":"bt:02:00:00:00:0d:01 bt:02:00:00:00:0d:04"}'
ri_run ing "$RI_EV_ING"
ri_row "remote id: marks: 7 addresses in 6 marks (5 rotating, 2 fixed); each address with Remote ID is a mark of its own, the two that broadcast TEST-ID.0001 are two marks, and the two rotating addresses of Maker A without it fold into bt:65535:1 as before" "$RI_W_ING"

# ---- R4 the tooltips, word for word: the Bluetooth line as before, then the note and one row per field that was broadcast; none of it for a mark without Remote ID
RI_EV_TIP="(async()=>{$RI_JS"'
ld(d=>{d.aps=[];d.unassociated=[];},G,"ri-tip");await sleep(1600);
const tip=(id)=>{const n=STARCHORUS.nodeScreen(id);if(STARCHORUS.hover(n.sx,n.sy)!==id)return "miss";const b=E("tip-body"),q=(s)=>{const e=b.querySelector(s);return e?e.textContent:null;};return {ssid:q(".ssid"),sub:q(".sub"),rows:[...b.querySelectorAll(".grid .k")].map(k=>k.textContent+"="+k.nextElementSibling.textContent)};};
for(const id of live())o[id]=tip(id);STARCHORUS.hover(5,5);
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RI_W_TIP='{"bt:02:00:00:00:0d:01":{"rows":'"$RI_RID"',"ssid":"Bluetooth LE · Maker A · 1 rotating address · -50 dBm · not a device count","sub":"'"$RI_NOTE"'"},
"bt:02:00:00:00:0d:02":{"rows":["Aircraft=gyroplane","ID=utm"],"ssid":"Bluetooth LE · company not advertised · 1 rotating address · -58 dBm · not a device count","sub":"'"$RI_NOTE"'"},
"bt:02:00:00:00:0d:03":{"rows":["Aircraft=ground","Position=lat -0.2500000, lon -29.7500000","Altitude=15.0 m"],"ssid":"Bluetooth LE · company not advertised · -66 dBm · public address · last heard in a window 12 s ago","sub":"'"$RI_NOTE"'"},
"bt:02:00:00:00:0d:04":{"rows":["Aircraft=multirotor","ID=TEST-ID.0001 · serial"],"ssid":"Bluetooth LE · Maker A · 1 rotating address · -52 dBm · not a device count","sub":"'"$RI_NOTE"'"},
"bt:02:00:00:00:0d:07":{"rows":[],"ssid":"Bluetooth LE · company not advertised · -70 dBm · public address · last heard in a window 30 s ago","sub":null},
"bt:65535:1":{"rows":[],"ssid":"Bluetooth LE · Maker A · 2 rotating addresses · -51 dBm strongest · not a device count","sub":null},"errors":0}'
ri_run tip "$RI_EV_TIP"
ri_row "remote id: tooltips word for word: the Bluetooth line as before, '$RI_NOTE', and Aircraft, ID, Position (lat, lon to seven decimals), Altitude (m), Operator position and Operator ID, each only when broadcast, and Operator–aircraft (the horizontal distance the page works out when both positions are broadcast); a mark without Remote ID keeps its one line" "$RI_W_TIP"

# ---- R5 the sheets: a mark with Remote ID opens one in the aggregate branch (no input, no identity buttons, no pin, no member list), a mark without selects
# nothing; a real click through the canvas handlers does the same; nothing reaches the browser's storage
RI_EV_SHEET="(async()=>{$RI_JS"'
ld(d=>{d.aps=[];d.unassociated=[];},G,"ri-sheet");await sleep(1600);
const sheet=(id)=>{const t=STARCHORUS.select(id),b=E("detail-body"),r={title:t,hidden:E("detail").hidden,locked:STARCHORUS.camera().locked};if(!r.hidden){r.notes=[...b.querySelectorAll(".obsnote")].map(e=>e.textContent);r.rows=[...b.querySelectorAll("tr")].map(x=>x.cells[0].textContent+"="+x.cells[1].textContent);r.inputs=b.querySelectorAll("input,textarea,button,[data-identity],[data-member]").length;}STARCHORUS.deselect();return r;};
for(const id of live())o[id]=sheet(id);
const hud=E("hud");let pid=40;const click=(x,y)=>{const q={clientX:x,clientY:y,pointerId:++pid,pointerType:"mouse",button:0,buttons:1,bubbles:true,isPrimary:true};hud.dispatchEvent(new PointerEvent("pointerdown",q));hud.dispatchEvent(new PointerEvent("pointerup",Object.assign({},q,{buttons:0})));};
const n1=STARCHORUS.nodeScreen(M(1));click(n1.sx,n1.sy);await sleep(200);o.click=[STARCHORUS.camera().locked,E("detail").hidden,E("detail-title").textContent,[...S.pinned].filter(x=>/^bt:/.test(x)).length].join("|");
STARCHORUS.deselect();const n7=STARCHORUS.nodeScreen(M(7));click(n7.sx,n7.sy);await sleep(200);o.click7=[STARCHORUS.camera().locked,E("detail").hidden].join("|");
o.storage=JSON.stringify(STARCHORUS.storageDump()||{}).search(/0d:0|remote|TEST-ID|OP-TEST/i);
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RI_W_SHEET='{"bt:02:00:00:00:0d:01":{"hidden":false,"inputs":0,"locked":"bt:02:00:00:00:0d:01","notes":["Bluetooth LE · Maker A · 1 rotating address · -50 dBm · not a device count","'"$RI_NOTE"'"],"rows":["Address=02:00:00:00:0d:01","Freshness=heard < 1 min","Aircraft=multirotor · airborne","ID=TEST-ID.0001 · serial","Position=lat 0.5000000, lon -30.2500000","Altitude=120.5 m","Operator position=lat 0.7500000, lon -30.5000000","Operator ID=OP-TEST_01","Operator–aircraft=39,300 m (derived, horizontal)"],"title":"Remote ID"},
"bt:02:00:00:00:0d:02":{"hidden":false,"inputs":0,"locked":"bt:02:00:00:00:0d:02","notes":["Bluetooth LE · company not advertised · 1 rotating address · -58 dBm · not a device count","'"$RI_NOTE"'"],"rows":["Address=02:00:00:00:0d:02","Freshness=heard < 1 min","Aircraft=gyroplane","ID=utm"],"title":"Remote ID"},
"bt:02:00:00:00:0d:03":{"hidden":false,"inputs":0,"locked":"bt:02:00:00:00:0d:03","notes":["Bluetooth LE · company not advertised · -66 dBm · public address · last heard in a window 12 s ago","'"$RI_NOTE"'"],"rows":["Address=02:00:00:00:0d:03","Name=Meadow-1","Freshness=heard < 1 min","Aircraft=ground","Position=lat -0.2500000, lon -29.7500000","Altitude=15.0 m"],"title":"Remote ID"},
"bt:02:00:00:00:0d:04":{"hidden":false,"inputs":0,"locked":"bt:02:00:00:00:0d:04","notes":["Bluetooth LE · Maker A · 1 rotating address · -52 dBm · not a device count","'"$RI_NOTE"'"],"rows":["Address=02:00:00:00:0d:04","Freshness=heard < 1 min","Aircraft=multirotor","ID=TEST-ID.0001 · serial"],"title":"Remote ID"},
"bt:02:00:00:00:0d:07":{"hidden":true,"locked":null,"title":null},"bt:65535:1":{"hidden":true,"locked":null,"title":null},
"click":"bt:02:00:00:00:0d:01|false|Remote ID|0","click7":"|true","errors":0,"storage":-1}'
ri_run sheet "$RI_EV_SHEET"
ri_row "remote id: sheets: a mark with Remote ID opens 'Remote ID' (its Bluetooth line, Address, Name when advertised, Freshness, the broadcast's rows and the derived row Operator–aircraft, '$RI_NOTE'; no input, identity button, member row or pin), a click on the canvas does the same; a mark without Remote ID selects nothing; no storage key holds any of it" "$RI_W_SHEET"

# ---- R6 the selection ring of a selected mark, read from #sky at four points of its radius (px + 13) in each theme: present in the selection token while
# selected, gone when let go; a mark without Remote ID cannot be selected, so it has none
RI_EV_RING="(async()=>{$RI_JS"'
ld(d=>{d.aps=[];d.unassociated=[];d.bluetooth=d.bluetooth.filter(b=>b.addr===A(1)||b.addr===A(7));},G,"ri-ring");await sleep(1800);STARCHORUS.setToggles({crt:false});
const pxl=(id,ang,r)=>{const n=STARCHORUS.nodeScreen(id),x=Math.round(n.sx+Math.cos(ang)*r),y=Math.round(n.sy+Math.sin(ang)*r);let b={a:0,r:0,g:0,b:0};for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++){const p=STARCHORUS.pixel("sky",x+dx,y+dy);if(p.a>b.a)b=p;}return b;};
const ring=(id)=>{const r=STARCHORUS.nodeScreen(id).px+13;return [0,90,180,270].map(a=>pxl(id,a*Math.PI/180,r));},res=[];
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await sleep(150);
 STARCHORUS.select(M(1));STARCHORUS.frame();await sleep(100);STARCHORUS.frame();const on=ring(M(1));
 STARCHORUS.deselect();STARCHORUS.frame();await sleep(100);STARCHORUS.frame();const off=ring(M(1));
 const sel=I.THEMES[t].accent.selection,hx=(i)=>parseInt(sel.slice(i,i+2),16),near=(p)=>Math.abs(p.r-hx(1))<=30&&Math.abs(p.g-hx(3))<=30&&Math.abs(p.b-hx(5))<=30;
 const seen=on.filter((p,i)=>p.a>=120&&p.a-off[i].a>=70&&near(p)).length;
 STARCHORUS.select(M(7));STARCHORUS.frame();const m7=ring(M(7)).filter(p=>p.a>=120).length;
 res.push(t+":"+seen+"/"+m7+"/"+String(STARCHORUS.camera().locked));}
STARCHORUS.setTheme("foundation");o.ring=res.join(" ");o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RI_W_RING='{"errors":0,"ring":"foundation:4/0/null wargames:4/0/null whitehall:4/0/null"}'
ri_run ring "$RI_EV_RING"
ri_row "remote id: the selection ring: at all four points of px + 13 in the selection token while the mark with Remote ID is selected (alpha at least 120 and 70 over the same points let go), in Foundation, WarGames and Whitehall; a mark without Remote ID stays unselected and ringless" "$RI_W_RING"

# ---- R7 the exports, word for word: JSON carries remote_id as normRid keeps it (the contract's order, after connectable), the CSV ten columns more on every row
# and a row per address with Remote ID plus the note, the SITREP one block before the observations
RI_EV_EXP="(async()=>{$RI_JS"'
ld(null,G,"ri-exp");await sleep(300);
const J=JSON.parse(STARCHORUS.exportText("json")),csv=STARCHORUS.exportText("csv").split("\n"),sit=STARCHORUS.exportText("sitrep").split("\n");
o.rid=Object.fromEntries(J.bluetooth.map(b=>[b.addr.slice(-2),b.remote_id||null]));o.ridKeys=J.bluetooth.filter(b=>b.remote_id).map(b=>b.addr.slice(-2)+":"+Object.keys(b.remote_id).join(","));o.keys=Object.keys(J.bluetooth[0]).join(",");
o.head=csv[0];o.widths=[...new Set(csv.filter(l=>l&&l[0]!=="#").map(l=>l.split(",").length))].join();o.csv=csv.filter(l=>/^remote_id,|^# /.test(l));
const i=sit.indexOf("Remote ID · as broadcast, not checked:"),j=sit.indexOf("Observations:");o.sitrep=i<0?null:sit.slice(i-1,j-1);
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RI_W_EXP='{"csv":["remote_id,02:00:00:00:0d:01,,,,,-50,heard < 1 min,,,,,,,,multirotor,serial,TEST-ID.0001,airborne,0.5000000,-30.2500000,120.5,0.7500000,-30.5000000,OP-TEST_01","remote_id,02:00:00:00:0d:04,,,,,-52,heard < 1 min,,,,,,,,multirotor,serial,TEST-ID.0001,,,,,,,","remote_id,02:00:00:00:0d:02,,,,,-58,heard < 1 min,,,,,,,,gyroplane,utm,,,,,,,,","remote_id,02:00:00:00:0d:03,,,,,-66,heard < 1 min,,,,,,,,,,,ground,-0.2500000,-29.7500000,15.0,,,","# '"$RI_NOTE"'","# Starchorus · passive observation · not a government system · no official marking"],
"errors":0,"head":"kind,bssid,ssid,band,channel,security,rssi,heard,alias,tags,association,randomized,probes,cloud,watched,ua_type,id_type,uas_id,status,lat,lon,alt_m,operator_lat,operator_lon,operator_id","keys":"addr,addr_type,rssi,reports,company,company_name,name,connectable,remote_id,heard,mark",
"rid":{"01":{"alt_m":120.5,"id_type":"serial","lat":0.5,"lon":-30.25,"operator_id":"OP-TEST_01","operator_lat":0.75,"operator_lon":-30.5,"status":"airborne","ua_type":"multirotor","uas_id":"TEST-ID.0001"},"02":{"id_type":"utm","ua_type":"gyroplane"},"03":{"alt_m":15,"lat":-0.25,"lon":-29.75,"status":"ground"},"04":{"id_type":"serial","ua_type":"multirotor","uas_id":"TEST-ID.0001"},"05":null,"06":null,"07":null},
"ridKeys":["01:ua_type,id_type,uas_id,status,lat,lon,alt_m,operator_lat,operator_lon,operator_id","04:ua_type,id_type,uas_id","02:ua_type,id_type","03:status,lat,lon,alt_m"],
"sitrep":["","'"$RI_NOTE"':","  02:00:00:00:0d:01 · -50 dBm · heard < 1 min","    Aircraft: multirotor · airborne","    ID: TEST-ID.0001 · serial","    Position: lat 0.5000000, lon -30.2500000","    Altitude: 120.5 m","    Operator position: lat 0.7500000, lon -30.5000000","    Operator ID: OP-TEST_01","    Operator–aircraft: 39,300 m (derived, horizontal)","  02:00:00:00:0d:04 · -52 dBm · heard < 1 min","    Aircraft: multirotor","    ID: TEST-ID.0001 · serial","  02:00:00:00:0d:02 · -58 dBm · heard < 1 min","    Aircraft: gyroplane","    ID: utm","  02:00:00:00:0d:03 · -66 dBm · heard < 1 min","    Aircraft: ground","    Position: lat -0.2500000, lon -29.7500000","    Altitude: 15.0 m"],"widths":"25"}'
ri_run exp "$RI_EV_EXP"
ri_row "remote id: exports word for word: JSON remote_id in the contract's order after connectable, the CSV 25 columns on every row with a remote_id row per address and the note, the SITREP block '$RI_NOTE:' before the observations, with the derived row Operator–aircraft after Operator ID; the JSON and CSV carry no derived figure" "$RI_W_EXP"

# ---- R8 without Remote ID nothing changes: the same capture with remote_id taken off every record gives the same JSON, CSV, SITREP and marks as a copy of
# the page with the feature planted out (normRid's spread, the group key, the export rows), and the CSV is the 14-column table; with Remote ID the two differ
RI_EV_ABS="(async()=>{$RI_JS"'
const dump=()=>[...["json","csv","sitrep"].map(f=>STARCHORUS.exportText(f)),[...S.bt.values()].filter(k=>k.target===1).map(k=>k.id+"="+k.n).sort().join(" ")].join("\n=====\n");
ld(d=>{d.bluetooth.forEach(b=>{delete b.remote_id;});},G,"ri-none");await sleep(300);o.none=dump();o.trace=/remote_id|Remote ID|TEST-ID|OP-TEST/.test(o.none);
const csv=STARCHORUS.exportText("csv").split("\n");o.width=[...new Set(csv.filter(l=>l&&l[0]!=="#").map(l=>l.split(",").length))].join()+"|"+csv[0];
ld(null,G+30,"ri-full");await sleep(300);o.full=dump();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
ri_run abs "$RI_EV_ABS"; RI_VABS=$RI_V; RI_EABS=$RI_E
RI_AV=$(printf '%s' "$RI_VABS" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("%s/%s" % (d["trace"], d["width"]))' 2>/dev/null)
python3 - "$H" "$RI_T/inert.html" <<'PY' ; RI_IC=$?
import sys
t = open(sys.argv[1], encoding="utf-8").read()
for old, new in (("...b.watched === true && { watched: true }, ...normRid(b.remote_id) };", "...b.watched === true && { watched: true } };"),
                 ('const key = "bt:" + (rot && !b.watched && !b.remote_id ? ', 'const key = "bt:" + (rot && !b.watched ? '),
                 ("R = (m.bluetooth || []).filter(b => b.remote_id);", "R = [];")):
    if t.count(old) != 1: sys.exit(1)
    t = t.replace(old, new)
open(sys.argv[2], "w", encoding="utf-8").write(t)
PY
RI_ID=$(diff "$H" "$RI_T/inert.html" 2>/dev/null | grep -c '^<')
ri_run abs-inert "$RI_EV_ABS" "$RI_T/inert.html"
RI_AD=$(python3 - "$RI_VABS" "$RI_V" <<'PY'
import json, sys
a, b = json.loads(sys.argv[1] or "{}"), json.loads(sys.argv[2] or "{}")
print(",".join(sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k))) or "none")
PY
)
RI_OK=0; [ "$RI_IC" = 0 ] && [ "$RI_ID" = 3 ] && [ "$RI_EABS/$RI_E" = 0/0 ] && [ "$RI_AD" = full ] && [ "$RI_AV" = "False/15|kind,bssid,ssid,band,channel,security,rssi,heard,alias,tags,association,randomized,probes,cloud,watched" ] && RI_OK=1
rowif "remote id: without Remote ID the JSON, CSV and SITREP exports and the marks are byte for byte those of a page copy with the feature planted out (normRid's spread, the group key, the export rows: $RI_ID lines), with no trace of it and the 15-column CSV; with Remote ID they differ [differ in: $RI_AD; trace/width $RI_AV]" [ "$RI_OK" = 1 ]

# ---- R9 text from the air is text: a hostile name and company name on a record with Remote ID are shown escaped in its sheet; hostile words, ids and a text
# latitude in remote_id are dropped (what is valid of it stays: the altitude and the operator position)
RI_EV_HOST="(async()=>{$RI_JS"'
const H=["<b>x</b>","\"><script>window.__x=1</script>","<img src=x onerror=window.__x=1>"];
ld(d=>{d.aps=[];d.unassociated=[];const r=d.bluetooth.find(b=>b.addr===A(3));r.name=H[0];r.company=60000;r.company_name=H[1];
 const q=d.bluetooth.find(b=>b.addr===A(1)).remote_id;q.uas_id=H[2];q.operator_id=H[1];q.ua_type=H[2];q.status=H[1];q.id_type=H[0];q.lat=H[0];},G,"ri-host");await sleep(1600);
const bad=(e)=>e.querySelector("img,script,b")!==null;
STARCHORUS.select(M(3));o.sheet3=[bad(E("detail-body")),E("detail-body").textContent.includes(H[0]),E("detail-body").textContent.includes(H[1])].join();STARCHORUS.deselect();
const n1=STARCHORUS.nodeScreen(M(1));STARCHORUS.hover(n1.sx,n1.sy);o.tip1=[bad(E("tip-body")),[...E("tip-body").querySelectorAll(".grid .k")].map(k=>k.textContent).join()].join("|");STARCHORUS.hover(5,5);
STARCHORUS.select(M(1));o.sheet1=[bad(E("detail-body")),[...E("detail-body").querySelectorAll("th")].map(k=>k.textContent).join()].join("|");STARCHORUS.deselect();
o.rid1=JSON.parse(STARCHORUS.exportText("json")).bluetooth.find(b=>b.addr===A(1)).remote_id;
o.noScript=window.__x===undefined;o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RI_W_HOST='{"errors":0,"noScript":true,"rid1":{"alt_m":120.5,"operator_lat":0.75,"operator_lon":-30.5},"sheet1":"false|Address,Freshness,Altitude,Operator position","sheet3":"false,true,true","tip1":"false|Altitude,Operator position"}'
ri_run host "$RI_EV_HOST"
ri_row "remote id: hostile text: a name and a company name with markup are shown as text in the sheet (no element made); markup in the words, the ids and a latitude of remote_id is dropped, the valid altitude and operator position stay; no script ran" "$RI_W_HOST"

# ---- R10 a position is never carried: the next capture of 0d:01 broadcasts its identity and operator only, and the page shows no position, altitude or status for
# it (JSON, sheet, SITREP); 0d:03's position is the one position left
RI_EV_CARRY="(async()=>{$RI_JS"'
ld(null,G,"ri-carry");await sleep(300);
ld(d=>{const r=d.bluetooth.find(b=>b.addr===A(1)).remote_id;for(const k of ["status","lat","lon","alt_m"])delete r[k];},G+30,"ri-carry");await sleep(300);
o.json=Object.keys(JSON.parse(STARCHORUS.exportText("json")).bluetooth.find(b=>b.addr===A(1)).remote_id).join(",");
STARCHORUS.select(M(1));o.sheet=[...E("detail-body").querySelectorAll("th")].map(e=>e.textContent).join(",");STARCHORUS.deselect();
o.pos=STARCHORUS.exportText("sitrep").split("\n").filter(l=>/^    Position: /.test(l)).join("|");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RI_W_CARRY='{"errors":0,"json":"ua_type,id_type,uas_id,operator_lat,operator_lon,operator_id","pos":"    Position: lat -0.2500000, lon -29.7500000","sheet":"Address,Freshness,Aircraft,ID,Operator position,Operator ID"}'
ri_run carry "$RI_EV_CARRY"
ri_row "remote id: a position is never carried into a later capture: 0d:01 without position, altitude and status in the next one has none of them in the JSON, the sheet or the SITREP" "$RI_W_CARRY"

# ---- R11 the words: everything the feature prints (tooltips and sheets in three themes, the three exports) holds no P10 word, no word of direction or
# distance, and none of track, pilot, locate, scanner, away, near; the judges flag a dummy and pass the feature's own wording
RI_EV_WORDS="(async()=>{$RI_JS"'
const seen=new Set(),add=(s)=>{for(const l of String(s==null?"":s).split("\n")){const t=l.trim();if(t)seen.add(t);}};
ld(d=>{d.aps=[];d.unassociated=[];},G,"ri-words");await sleep(1600);
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await sleep(200);
 for(const id of live()){const n=STARCHORUS.nodeScreen(id);STARCHORUS.hover(n.sx,n.sy);add(E("tip-body").innerText);add(E("tip-body").textContent);
  if(STARCHORUS.select(id)){const b=E("detail-body");add(E("detail-title").textContent);add(b.innerText);for(const x of b.querySelectorAll("svg text,svg title,svg desc,.legrow.note,[aria-label],[title],[alt]"))add(x.textContent+" "+(x.getAttribute("aria-label")||"")+" "+(x.getAttribute("title")||"")+" "+(x.getAttribute("alt")||""));STARCHORUS.deselect();}}}
STARCHORUS.setTheme("foundation");STARCHORUS.hover(5,5);for(const f of ["json","csv","sitrep"])add(STARCHORUS.exportText(f));
return [...seen].join("\n");})()'
runq "$RI_FX" "$RI_Q" "$RI_T/words" --fps 0 --wait 3 --ready "$RI_RDY" --eval-timeout 120 --eval "$RI_EV_WORDS" >/dev/null 2>&1
evalv "$RI_T/words.json" 1 > "$RI_T/words.txt"
RI_P10=$(sed -n "s/^NTL_P10_RE='\(.*\)'\$/\1/p" tools/regress.d/neutral-language.sh | head -n 1)   # the one definition of the P10 words, read where it lives
RI_DIRW='direction|bearing|heading|compass|north|south|east|west|ahead|behind|degrees?|metres?|meters?|feet|miles?|km|distance|range|nearby|closer|farther'
RI_DIRN=$(grep -cF "$RI_DIRW" tools/regress.d/scope.sh)   # the Scope's word judge holds the same words (a copy that drifts is red)
RI_ALLOW='Drawn to scale, north up'   # the one phrase the direction judge lets through (the owner's word of 3 November 2026 for the plan, for its note alone); RI_DIRW stands
printf '%s\n' 'the pilot is north of the Pager, 30° and 2 km away: track the target' > "$RI_T/words-bad.txt"
printf '%s\n' 'Remote ID · as broadcast, not checked' 'Operator position: lat 0.7500000, lon -30.5000000' 'Altitude: 120.5 m' 'Operator–aircraft: 39,300 m (derived, horizontal)' \
  "$RI_ALLOW, from the two broadcast positions (derived): the operator's position may be from an earlier broadcast, and the Pager is not on it." 'aircraft' 'operator' 'N' 'altitude 120.5 m' '20,000 m' > "$RI_T/words-ok.txt"
printf '%s\n' "$RI_ALLOW, 2 km north of the Pager" 'north up' 'Operator–aircraft: 312 metres' 'DRAWN TO SCALE, NORTH UP' > "$RI_T/words-leak.txt"   # lines the exception must leave flagged
cat > "$RI_T/words.py" <<'PY'
import re, sys
p10, dirw, allow = sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else ""
J = {"p10": p10, "dir": r"(?i)\b(" + dirw + r"|(?:near|close to|next to) (?:the )?pager|(?:nearest|closest) (?:ring|arc))\b|°",
     "more": r"(?i)\b(track(s|ed|ing)?|pilot(s|ed)?|locat(e|es|ed|ing|ion)|scanner|away|near)\b"}
t = open(sys.argv[1], encoding="utf-8", errors="replace").read()
u = re.sub(re.escape(allow), " ", t, flags=re.I) if allow else t   # the one named phrase (the plan's note) leaves the text the direction count reads, and nothing else
print(" ".join("%s:%d" % (k, len(re.findall(v, u if k == "dir" else t, re.I))) for k, v in J.items()), len(t))
PY
RI_WH=$(python3 "$RI_T/words.py" "$RI_T/words.txt" "$RI_P10" "$RI_DIRW" "$RI_ALLOW")
RI_WB=$(python3 "$RI_T/words.py" "$RI_T/words-bad.txt" "$RI_P10" "$RI_DIRW" "$RI_ALLOW")
RI_WC=$(python3 "$RI_T/words.py" "$RI_T/words-ok.txt" "$RI_P10" "$RI_DIRW" "$RI_ALLOW")
RI_WX=$(python3 "$RI_T/words.py" "$RI_T/words-ok.txt" "$RI_P10" "$RI_DIRW")   # the control: without the exception the note's 'north' is counted
RI_WL=$(python3 "$RI_T/words.py" "$RI_T/words-leak.txt" "$RI_P10" "$RI_DIRW" "$RI_ALLOW")
RI_WA=$(grep -c -i -F "$RI_ALLOW" "$RI_T/words.txt")   # the phrase is in what the judges read (the note as written and in capitals): the exception is live
RI_WP=$(grep -c -x -E 'aircraft|operator|N' "$RI_T/words.txt")   # the plan's own words are read one by one
RI_WN=$(grep -c -e 'Operator position' -e 'as broadcast, not checked' -e 'Altitude' "$RI_T/words.txt")
RI_WG=$(grep -c -F '(derived, horizontal)' "$RI_T/words.txt")   # the derived row is in what the judges read (tooltip, sheet, SITREP)
RI_WD=$(sh tools/denylist-check.sh "$R/$RI_T/words.txt" 2>&1); RI_WDR=$?
RI_OK=0
case "$RI_WH|$RI_WB|$RI_WC|$RI_WX|$RI_WL" in "p10:0 dir:0 more:0 "*"|p10:1 dir:3 more:3 "*"|p10:0 dir:0 more:0 "*"|p10:0 dir:1 more:0 "*"|p10:0 dir:4 more:0 "*) [ -n "$RI_P10" ] && [ "$RI_DIRN" = 1 ] && [ "$RI_WN" -ge 3 ] && [ "$RI_WG" -ge 3 ] && [ "$RI_WA" -ge 2 ] && [ "$RI_WP" -ge 3 ] && [ "$RI_WDR" = 0 ] && RI_OK=1 ;; esac
rowif "remote id: words: the tooltips, sheets (the plan's texts one by one) and exports ($RI_WH characters) hold no P10 word, no word of direction or distance beyond the one named phrase '$RI_ALLOW' of the plan's note (the owner's word of 3 November 2026; read $RI_WA times, so the exception is live) and none of track, pilot, locate, scanner, away, near; the legal denylist holds; a dummy is flagged ($RI_WB), the feature's own wording passes ($RI_WC) and fails without the exception ($RI_WX), a leak dummy stays flagged ($RI_WL), the derived row ($RI_WG lines) and the plan's words ($RI_WP) are among what they read; the direction words are the Scope judge's ($RI_DIRN)" [ "$RI_OK" = 1 ]
[ "$RI_WDR" = 0 ] || printf '%s\n' "$RI_WD" | cut -c1-170 | sed 's/^/    /'

# ---- R12 the page's word lists and key order are the validator's (and through collector-fields.sh the decoder's), word for word; a changed word is seen
cat > "$RI_T/lists.py" <<'PY'
import importlib.util, re, sys
spec = importlib.util.spec_from_file_location("g", "tools/gen-testdata.py"); g = importlib.util.module_from_spec(spec); sys.dont_write_bytecode = True; spec.loader.exec_module(g)
t = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'^const RID_KEYS = "([^"]+)"\.split\(" "\), RID_W = \{ ua_type: "([^"]+)",\n  id_type: "([^"]+)", status: "([^"]+)" \};$', t, re.M)
if not m: print("no lists"); sys.exit(0)
got = [x.split(" ") for x in m.groups()]
want = [list(g.RID_KEYS), list(g.RID_UA), list(g.RID_IDT), list(g.RID_STATUS)]
print("same" if got == want else "differ: " + ", ".join(n for n, a, b in zip(("keys", "ua", "idt", "status"), got, want) if a != b))
PY
RI_LS=$(python3 -B "$RI_T/lists.py" "$H")
sed 's/ multirotor gyroplane / quadcopter gyroplane /' "$H" > "$RI_T/lists-dummy.html"
RI_LD=$(python3 -B "$RI_T/lists.py" "$RI_T/lists-dummy.html")
rowif "remote id: the page's RID_KEYS and the three word lists of RID_W are gen-testdata.py's RID_KEYS, RID_UA, RID_IDT and RID_STATUS ($RI_LS); a page with one word changed is seen ($RI_LD)" [ "$RI_LS/$RI_LD" = "same/differ: ua" ]

# ---- R14 the page with Remote ID shown (the sheets, a click, the exports) asks for nothing but GET of its own origin
RI_NV=$(net_verdict "$RI_T/sheet.json" - 0); RI_NC=$?
rowif "remote id: with the sheets open the page makes no request but GET to its own origin: $RI_NV" [ "$RI_NC" = 0 ]

# ---- R15 the keys bite: the evals above on planted copies of the page. Fair by construction: each old text exists once, each copy differs from the page in the
# lines it names and boots without an error; the answer must differ from the page's in exactly the keys named. The copies are only served to headless Chrome
# on 127.0.0.1; nothing in them sends.
ri_probe() {   # ri_probe NAME EVAL WANT_JSON KEYS LINES OLD NEW [OLD NEW ...]   KEYS = the keys that must differ, sorted, comma-separated
  _ri_pn=$1; _ri_pe=$2; _ri_pw=$3; _ri_pk=$4; _ri_pl=$5; shift 5
  if python3 - "$H" "$RI_T/mut-$_ri_pn.html" "$@" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read(); a = sys.argv[3:]
for i in range(0, len(a), 2):
    if t.count(a[i]) != 1: sys.exit("anchor %d: %d occurrences" % (i // 2, t.count(a[i])))
    t = t.replace(a[i], a[i + 1])
open(sys.argv[2], "w", encoding="utf-8").write(t)
PY
  then
    _ri_pd=$(diff "$H" "$RI_T/mut-$_ri_pn.html" | grep -c '^<')
    ri_run "mut-$_ri_pn" "$_ri_pe" "$RI_T/mut-$_ri_pn.html"
    _ri_px=$(python3 - "$RI_V" "$(printf '%s' "$_ri_pw" | ri_nj)" <<'PY'
import json, sys
g, w = json.loads(sys.argv[1] or "{}"), json.loads(sys.argv[2])
print(",".join(sorted(k for k in set(g) | set(w) if g.get(k) != w.get(k))))
PY
    )
    [ "$_ri_pd" = "$_ri_pl" ] || _ri_px="$_ri_px (the copy differs in $_ri_pd lines, want $_ri_pl)"
  else _ri_px="anchor"; fi
  if [ "$_ri_px" = "$_ri_pk" ]; then RI_PROBES="$RI_PROBES $_ri_pn"; else RI_PBAD="$RI_PBAD [$_ri_pn: differs in '$_ri_px', want '$_ri_pk']"; fi
}
RI_PROBES=""; RI_PBAD=""
ri_probe esc "$RI_EV_HOST" "$RI_W_HOST" sheet3 1 'if (v) h += row(t, esc(v));' 'if (v) h += row(t, v);'
ri_probe every "$RI_EV_SHEET" "$RI_W_SHEET" "bt:02:00:00:00:0d:07,bt:65535:1,click7" 2 \
  'if (!n || n.kind === "bt" && !n.m[0].remote_id) return null;' 'if (!n) return null;' \
  'kr = kb && kb.m[0].remote_id;' 'kr = kb && (kb.m[0].remote_id || {});'
ri_probe folded "$RI_EV_ING" "$RI_W_ING" "counts,folded,members,sameId" 1 'const key = "bt:" + (rot && !b.watched && !b.remote_id ? ' 'const key = "bt:" + (rot && !b.watched ? '
ri_probe carried "$RI_EV_CARRY" "$RI_W_CARRY" "json,pos,sheet" 1 'Object.assign(k, { m, n: m.length,' 'Object.assign(k, { m: k.m && k.m[0].remote_id && m[0].remote_id ? [{ ...m[0], remote_id: { ...k.m[0].remote_id, ...m[0].remote_id } }] : m, n: m.length,'
ri_probe ring "$RI_EV_RING" "$RI_W_RING" ring 1 '    drawSelectionMarks(ctx, k, k.alpha);   // the selected mark (Remote ID, 0.2.7)
' ''
ri_probe words "$RI_EV_PAR" "$RI_W_PAR" parity 1 'if (w ? w.split(" ").includes(v) :' 'if (w ? typeof v == "string" :'
RI_PN=$(echo "$RI_PROBES" | wc -w | tr -d ' ')
RI_PK=0; [ "$RI_PN" = 6 ] && [ -z "$RI_PBAD" ] && RI_PK=1
rowif "remote id: the probes bite ($RI_PN of 6: the sheet's esc removed, a sheet for every mark, Remote ID folded again, a position carried over, no ring in drawBt, a word outside its list kept), each turns exactly its keys red${RI_PBAD}" [ "$RI_PK" = 1 ]

# ---- R16 operator to aircraft: the one figure the page works out from a broadcast, the horizontal distance between the aircraft's position and the
# operator's (haversine on the mean earth radius, whole metres under 1,000 m and three figures above, grouped by commas), as the last row of the
# tooltip, the sheet and the SITREP block, never in the JSON or the CSV, and never from the Pager; ten scenes of 0d:01: the generated pair, 300 m
# north and east, the same point, across the seam and over the pole (the short way), the antipode, the kept 5e-8 edge, and one pair alone (no row).
# The seam, pole and antipode scenes are synthetic open-sea positions outside the Atlantic box of the generated document (the owner's word of
# 2 November 2026); the ids stay TEST- and OP-TEST.
RI_EV_GAP="(async()=>{$RI_JS"'
const row=()=>{STARCHORUS.select(M(1));const r=[...E("detail-body").querySelectorAll("tr")].map(x=>x.cells[0].textContent+"="+x.cells[1].textContent).filter(x=>x.startsWith("Operator–aircraft="));STARCHORUS.deselect();return r.length?r[0]:"none";};
const sc={full:{},near:{operator_lat:0.4973,operator_lon:-30.25},across:{operator_lat:0.5,operator_lon:-30.2527},same:{operator_lat:0.5,operator_lon:-30.25},seam:{lat:0.5,lon:179.999,operator_lat:0.5,operator_lon:-179.999},pole:{lat:89.999,lon:-30.25,operator_lat:89.999,operator_lon:149.75},anti:{operator_lat:-0.5,operator_lon:149.75},edge:{lat:5.0000000000000004e-8,lon:0,operator_lat:0.0027,operator_lon:0},loneAc:{operator_lat:null,operator_lon:null},loneOp:{lat:null,lon:null,status:null,alt_m:null}};
let g=G;ld(d=>{d.aps=[];d.unassociated=[];},g,"ri-gap");await sleep(1600);
for(const [n,m] of Object.entries(sc)){g+=30;ld(d=>{d.aps=[];d.unassociated=[];const r=d.bluetooth.find(b=>b.addr===A(1)).remote_id;for(const [k,v] of Object.entries(m)){if(v==null)delete r[k];else r[k]=v;}},g,"ri-gap");await sleep(300);o[n]=row();
 if(n==="near"){const p=STARCHORUS.nodeScreen(M(1));STARCHORUS.hover(p.sx,p.sy);o.tip=[...E("tip-body").querySelectorAll(".grid .k")].map(k=>k.textContent+"="+k.nextElementSibling.textContent).filter(x=>x.startsWith("Operator–aircraft=")).join("|")||"none";STARCHORUS.hover(5,5);
  o.sitrep=STARCHORUS.exportText("sitrep").split("\n").filter(l=>/Operator–aircraft/.test(l)).join("|")||"none";o.data=/Operator–aircraft|derived, horizontal/.test(STARCHORUS.exportText("json")+STARCHORUS.exportText("csv"));}}
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RI_W_GAP='{"across":"Operator–aircraft=300 m (derived, horizontal)","anti":"Operator–aircraft=20,000,000 m (derived, horizontal)","data":false,"edge":"Operator–aircraft=300 m (derived, horizontal)","errors":0,"full":"Operator–aircraft=39,300 m (derived, horizontal)","loneAc":"none","loneOp":"none","near":"Operator–aircraft=300 m (derived, horizontal)","pole":"Operator–aircraft=222 m (derived, horizontal)","same":"Operator–aircraft=0 m (derived, horizontal)","seam":"Operator–aircraft=222 m (derived, horizontal)","sitrep":"    Operator–aircraft: 300 m (derived, horizontal)","tip":"Operator–aircraft=300 m (derived, horizontal)"}'
ri_run gap "$RI_EV_GAP"
ri_row "remote id: operator to aircraft: the horizontal distance the page works out from the two broadcast positions, word for word in ten scenes of 0d:01 (39,300 m as generated; 300 m north, east and at the kept edge; 0 m at one point; 222 m the short way across the seam and over the pole; 20,000,000 m at the antipode; no row with one pair alone), the same line in the tooltip and the SITREP, nothing of it in the JSON or CSV" "$RI_W_GAP"
# ---- R16b the figure's probes: a copy with lat and lon swapped in the cosine term, one with a flat earth and no seam, one that works a figure out of one pair
RI_PROBES=""; RI_PBAD=""
ri_probe gswap "$RI_EV_GAP" "$RI_W_GAP" "across,anti,full,pole" 1 'h = a * a + Math.cos(p) * Math.cos(q) * b * b;' 'h = a * a + Math.cos(r.operator_lon * k) * Math.cos(r.lon * k) * b * b;'
ri_probe gflat "$RI_EV_GAP" "$RI_W_GAP" "pole,seam" 1 'const d = 2 * R * Math.asin(Math.min(1, Math.sqrt(h))), t =' 'const d = R * Math.hypot(q - p, l * Math.cos((p + q) / 2)), t ='
ri_probe glone "$RI_EV_GAP" "$RI_W_GAP" "loneAc,loneOp,sitrep" 1 'if (r.lat == null || r.operator_lat == null) return null;' 'if (r.lat == null && r.operator_lat == null) return null;'
RI_GN=$(echo "$RI_PROBES" | wc -w | tr -d ' ')
rowif "remote id: the distance probes bite ($RI_GN of 3: lat and lon swapped in the cosine term, a flat earth without the seam, a figure from one pair, which the SITREP shows for every record of the document), each turns exactly its keys red${RI_PBAD}" [ "$RI_GN/${RI_PBAD:-ok}" = "3/ok" ]

# ---- R17 the plan: under the sheet's rows the two positions drawn to scale and north up (ridPlan), the operator a ring and the aircraft a disc at the
# freshness alpha of its mark, a dashed line between them with the figure, a scale bar of 1, 2 or 5 × 10^n m, the north arrow and the broadcast altitude as
# text; read as the circles' centres and radii (operator first), the paths (the dashed line, the bar and the arrow), every text with its place and anchor,
# the disc's opacity, the attributes the drawing and its parts must not have (no xmlns, href, style or colour: the colours are the theme's tokens, by CSS)
# and the derived note beneath. Thirteen scenes of 0d:01, each heard 4 s before its capture unless said: as generated; 300 m north and east; one point;
# 3 m east (the close-range cap draws 3 m as 18 units, not across the plan) and 2 m south (the stacked labels go outward, the figure to the left); 1,500 m
# at a shallow tilt (the figure clear of its line); across the seam and over the pole (the short way, the drawn length the figure's); heard 90 s ago (the
# disc at 0.85); without an altitude; the aircraft alone and the operator alone (no plan). The seam and pole scenes are synthetic open-sea positions (the
# owner's word of 2 November 2026).
RI_EV_PLAN="(async()=>{$RI_JS"'
const plan=()=>{STARCHORUS.select(M(1));const b=E("detail-body"),v=[...b.querySelectorAll("svg.rp")],r={plans:v.length};if(v.length){const s=v[0],f=(e,a)=>e.getAttribute(a);
 r.c=[...s.querySelectorAll("circle")].map(e=>f(e,"cx")+","+f(e,"cy")+","+f(e,"r")).join("|");r.a=f(s.querySelector("circle.a"),"fill-opacity");r.p=[...s.querySelectorAll("path")].map(e=>(e.getAttribute("class")||"-")+":"+f(e,"d")).join("|");
 r.t=[...s.querySelectorAll("text")].map(e=>e.textContent+"@"+f(e,"x")+","+f(e,"y")+","+f(e,"text-anchor")).join(";");
 r.bad=[s,...s.querySelectorAll("*")].flatMap(e=>[...e.attributes].map(a=>a.name)).filter(n=>/^(xmlns|href|style|fill|stroke|color)$/.test(n)).length+"/"+f(s,"aria-hidden")+"/"+f(s,"viewBox");
 r.note=s.nextElementSibling.className+"="+s.nextElementSibling.textContent;}
 STARCHORUS.deselect();return r;};
const sc={fx:{},north:{operator_lat:0.4973,operator_lon:-30.25},east:{operator_lat:0.5,operator_lon:-30.2527},same:{operator_lat:0.5,operator_lon:-30.25},close:{operator_lat:0.5,operator_lon:-30.250027},south:{operator_lat:0.500018,operator_lon:-30.25},shallow:{operator_lat:0.49651,operator_lon:-30.263033},seam:{lat:0.5,lon:179.999,operator_lat:0.5,operator_lon:-179.999},pole:{lat:89.999,lon:-30.25,operator_lat:89.999,operator_lon:149.75},age:{age:90},noAlt:{alt_m:null},onePair:{operator_lat:null,operator_lon:null},opOnly:{lat:null,lon:null,status:null,alt_m:null}};
let g=G;ld(d=>{d.aps=[];d.unassociated=[];},g,"ri-plan");await sleep(1600);
for(const [n,m] of Object.entries(sc)){g+=30;ld(d=>{d.aps=[];d.unassociated=[];const b=d.bluetooth.find(b=>b.addr===A(1)),r=b.remote_id;b.last_seen=d.generated-(m.age||4);for(const [k,v] of Object.entries(m)){if(k==="age")continue;if(v==null)delete r[k];else r[k]=v;}},g,"ri-plan");await sleep(300);o[n]=plan();}
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RI_W_PLAN='{"fx":{"plans":1,"c":"90.0,20.0,5.5|150.0,80.0,3.5","a":"1","p":"l:M90.0 20.0L150.0 80.0|-:M22 108v4h43.2v-4M8 117v-13m-3 4 3-4 3 4","t":"aircraft@158.5,91.5,start;operator@81.5,14.5,end;39,300 m@113.6,59.4,end;20,000 m@69.2,112.0,start;N@8.0,101.0,middle;altitude 120.5 m@232.0,112.0,end","bad":"0/true/0 0 240 120","note":"legrow note=Drawn to scale, north up, from the two broadcast positions (derived): the operator'"'"'s position may be from an earlier broadcast, and the Pager is not on it."},"north":{"plans":1,"c":"120.0,80.0,5.5|120.0,20.0,3.5","a":"1","p":"l:M120.0 80.0L120.0 20.0|-:M22 108v4h40.0v-4M8 117v-13m-3 4 3-4 3 4","t":"aircraft@120.0,11.0,middle;operator@120.0,95.0,middle;300 m@129.0,53.0,start;200 m@66.0,112.0,start;N@8.0,101.0,middle;altitude 120.5 m@232.0,112.0,end","bad":"0/true/0 0 240 120","note":"legrow note=Drawn to scale, north up, from the two broadcast positions (derived): the operator'"'"'s position may be from an earlier broadcast, and the Pager is not on it."},"east":{"plans":1,"c":"60.0,50.0,5.5|180.0,50.0,3.5","a":"1","p":"l:M60.0 50.0L180.0 50.0|-:M22 108v4h40.0v-4M8 117v-13m-3 4 3-4 3 4","t":"aircraft@192.0,53.0,start;operator@48.0,53.0,end;300 m@120.0,62.0,middle;100 m@66.0,112.0,start;N@8.0,101.0,middle;altitude 120.5 m@232.0,112.0,end","bad":"0/true/0 0 240 120","note":"legrow note=Drawn to scale, north up, from the two broadcast positions (derived): the operator'"'"'s position may be from an earlier broadcast, and the Pager is not on it."},"same":{"plans":1,"c":"120.0,50.0,5.5|120.0,50.0,3.5","a":"1","p":"l:M120.0 50.0L120.0 50.0|-:M22 108v4h30.0v-4M8 117v-13m-3 4 3-4 3 4","t":"aircraft@120.0,41.0,middle;operator@120.0,65.0,middle;0 m@132.0,53.0,start;5 m@56.0,112.0,start;N@8.0,101.0,middle;altitude 120.5 m@232.0,112.0,end","bad":"0/true/0 0 240 120","note":"legrow note=Drawn to scale, north up, from the two broadcast positions (derived): the operator'"'"'s position may be from an earlier broadcast, and the Pager is not on it."},"close":{"plans":1,"c":"111.0,50.0,5.5|129.0,50.0,3.5","a":"1","p":"l:M111.0 50.0L129.0 50.0|-:M22 108v4h30.0v-4M8 117v-13m-3 4 3-4 3 4","t":"aircraft@129.0,41.0,middle;operator@111.0,65.0,middle;3 m@141.0,53.0,start;5 m@56.0,112.0,start;N@8.0,101.0,middle;altitude 120.5 m@232.0,112.0,end","bad":"0/true/0 0 240 120","note":"legrow note=Drawn to scale, north up, from the two broadcast positions (derived): the operator'"'"'s position may be from an earlier broadcast, and the Pager is not on it."},"south":{"plans":1,"c":"120.0,44.0,5.5|120.0,56.0,3.5","a":"1","p":"l:M120.0 44.0L120.0 56.0|-:M22 108v4h30.0v-4M8 117v-13m-3 4 3-4 3 4","t":"aircraft@120.0,71.0,middle;operator@120.0,35.0,middle;2 m@108.0,53.0,end;5 m@56.0,112.0,start;N@8.0,101.0,middle;altitude 120.5 m@232.0,112.0,end","bad":"0/true/0 0 240 120","note":"legrow note=Drawn to scale, north up, from the two broadcast positions (derived): the operator'"'"'s position may be from an earlier broadcast, and the Pager is not on it."},"shallow":{"plans":1,"c":"60.0,66.1,5.5|180.0,33.9,3.5","a":"1","p":"l:M60.0 66.1L180.0 33.9|-:M22 108v4h41.4v-4M8 117v-13m-3 4 3-4 3 4","t":"aircraft@191.6,33.8,start;operator@48.4,72.2,end;1,500 m@123.5,66.2,middle;500 m@67.4,112.0,start;N@8.0,101.0,middle;altitude 120.5 m@232.0,112.0,end","bad":"0/true/0 0 240 120","note":"legrow note=Drawn to scale, north up, from the two broadcast positions (derived): the operator'"'"'s position may be from an earlier broadcast, and the Pager is not on it."},"seam":{"plans":1,"c":"180.0,50.0,5.5|60.0,50.0,3.5","a":"1","p":"l:M180.0 50.0L60.0 50.0|-:M22 108v4h27.0v-4M8 117v-13m-3 4 3-4 3 4","t":"aircraft@48.0,53.0,end;operator@192.0,53.0,start;222 m@120.0,44.0,middle;50 m@53.0,112.0,start;N@8.0,101.0,middle;altitude 120.5 m@232.0,112.0,end","bad":"0/true/0 0 240 120","note":"legrow note=Drawn to scale, north up, from the two broadcast positions (derived): the operator'"'"'s position may be from an earlier broadcast, and the Pager is not on it."},"pole":{"plans":1,"c":"120.0,80.0,5.5|120.0,20.0,3.5","a":"1","p":"l:M120.0 80.0L120.0 20.0|-:M22 108v4h27.0v-4M8 117v-13m-3 4 3-4 3 4","t":"aircraft@120.0,11.0,middle;operator@120.0,95.0,middle;222 m@129.0,53.0,start;100 m@53.0,112.0,start;N@8.0,101.0,middle;altitude 120.5 m@232.0,112.0,end","bad":"0/true/0 0 240 120","note":"legrow note=Drawn to scale, north up, from the two broadcast positions (derived): the operator'"'"'s position may be from an earlier broadcast, and the Pager is not on it."},"age":{"plans":1,"c":"90.0,20.0,5.5|150.0,80.0,3.5","a":"0.85","p":"l:M90.0 20.0L150.0 80.0|-:M22 108v4h43.2v-4M8 117v-13m-3 4 3-4 3 4","t":"aircraft@158.5,91.5,start;operator@81.5,14.5,end;39,300 m@113.6,59.4,end;20,000 m@69.2,112.0,start;N@8.0,101.0,middle;altitude 120.5 m@232.0,112.0,end","bad":"0/true/0 0 240 120","note":"legrow note=Drawn to scale, north up, from the two broadcast positions (derived): the operator'"'"'s position may be from an earlier broadcast, and the Pager is not on it."},"noAlt":{"plans":1,"c":"90.0,20.0,5.5|150.0,80.0,3.5","a":"1","p":"l:M90.0 20.0L150.0 80.0|-:M22 108v4h43.2v-4M8 117v-13m-3 4 3-4 3 4","t":"aircraft@158.5,91.5,start;operator@81.5,14.5,end;39,300 m@113.6,59.4,end;20,000 m@69.2,112.0,start;N@8.0,101.0,middle","bad":"0/true/0 0 240 120","note":"legrow note=Drawn to scale, north up, from the two broadcast positions (derived): the operator'"'"'s position may be from an earlier broadcast, and the Pager is not on it."},"onePair":{"plans":0},"opOnly":{"plans":0},"errors":0}'
ri_run plan "$RI_EV_PLAN"
ri_row "remote id: the plan: under the sheet's rows the two positions to scale and north up, read as circles with their radii, paths, texts and the disc's opacity in thirteen scenes of 0d:01 (as generated; 300 m north and east; one point; 3 m east and 2 m south; 1,500 m at a shallow tilt; the seam and the pole the short way, the drawn length the figure's; heard 90 s ago, the disc at 0.85; without an altitude; no plan with the aircraft alone or the operator alone), with no xmlns, href, style or colour attribute on the drawing or its parts, and the derived note beneath" "$RI_W_PLAN"

# ---- R18 the plan in three themes: the ring's stroke and the disc's fill are the theme's Bluetooth mark token, the texts the secondary ink and the figure
# the primary ink, every path stroked in the secondary ink without a fill and the line dashed (computed styles against THEMES); the plan's text-transform
# is none (its words keep their case where the panel's chrome is in capitals); the plan fits the sheet and every text its frame (a clipped label is red).
# As generated, 300 m east and 300 m north, in Foundation, WarGames and Whitehall.
RI_EV_THEMES="(async()=>{$RI_JS"'
const rgb=(h)=>"rgb("+[1,3,5].map(i=>parseInt(h.slice(i,i+2),16)).join(", ")+")",cs=(e)=>getComputedStyle(e),res=[];
const sc={fx:{},east:{operator_lat:0.5,operator_lon:-30.2527},north:{operator_lat:0.4973,operator_lon:-30.25}};let g=G;ld(d=>{d.aps=[];d.unassociated=[];},g,"ri-themes");await sleep(1600);
for(const [n,m] of Object.entries(sc)){g+=30;ld(d=>{d.aps=[];d.unassociated=[];const b=d.bluetooth.find(b=>b.addr===A(1));b.last_seen=d.generated-4;for(const [k,v] of Object.entries(m))b.remote_id[k]=v;},g,"ri-themes");await sleep(300);
 for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await sleep(200);STARCHORUS.select(M(1));const T=I.THEMES[t],b=E("detail-body"),s=b.querySelector("svg.rp"),sb=s.getBoundingClientRect(),bb=b.getBoundingClientRect();
  const inside=(e)=>{const r=e.getBoundingClientRect();return r.left>=sb.left-0.5&&r.right<=sb.right+0.5&&r.top>=sb.top-0.5&&r.bottom<=sb.bottom+0.5;};
  res.push(n+"/"+t+":"+[cs(s.querySelector("circle.a")).fill===rgb(T.render.btMark),cs(s.querySelector("circle:not(.a)")).stroke===rgb(T.render.btMark),cs(s.querySelector("text")).fill===rgb(T.ink.secondary),cs(s.querySelector("text.f")).fill===rgb(T.ink.primary),cs(s).textTransform==="none",sb.right<=bb.right+0.5&&sb.width>=200,[...s.querySelectorAll("text")].every(inside),[...s.querySelectorAll("path")].every(p=>cs(p).stroke===rgb(T.ink.secondary)&&cs(p).fill==="none"),/^3(px)?, 3(px)?$/.test(cs(s.querySelector("path.l")).strokeDasharray)].map(Number).join(""));
  STARCHORUS.deselect();}}
STARCHORUS.setTheme("foundation");o.themes=res.join(" ");o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RI_W_THEMES='{"errors":0,"themes":"fx/foundation:111111111 fx/wargames:111111111 fx/whitehall:111111111 east/foundation:111111111 east/wargames:111111111 east/whitehall:111111111 north/foundation:111111111 north/wargames:111111111 north/whitehall:111111111"}'
ri_run themes "$RI_EV_THEMES"
ri_row "remote id: the plan in three themes: the disc's fill and the ring's stroke are the theme's Bluetooth mark token, the texts the secondary ink and the figure the primary ink, the plan's text-transform none, the plan inside the sheet and every text inside the plan, every path stroked in the secondary ink without a fill and the line dashed (as generated, 300 m east and 300 m north, in Foundation, WarGames and Whitehall)" "$RI_W_THEMES"

# ---- R19 the plan on a phone (375 × 812, touch): select opens the detail card with the plan at the card's width inside the viewport, the page does not
# scroll sideways, and the figure prints at 11 px or more (9 units of 240 at the plan's width)
RI_EV_PHONE="(async()=>{$RI_JS"'
ld(d=>{d.aps=[];d.unassociated=[];},G,"ri-phone");await sleep(1600);STARCHORUS.select(M(1));await sleep(300);
const s=E("detail-body").querySelector("svg.rp"),r=s?s.getBoundingClientRect():{width:0,right:9e9},fs=s?parseFloat(getComputedStyle(s.querySelector("text.f")).fontSize)*r.width/240:0;
o.phone=[document.documentElement.dataset.phone,document.documentElement.dataset.card,r.width>=280,r.right<=375.5,document.scrollingElement.scrollWidth<=375,fs>=11].join("|");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$RI_FX" "$RI_Q" "$RI_T/phone" --width 375 --height 812 --mobile --fps 0 --wait 3 --ready "$RI_RDY" --eval-timeout 120 --eval "$RI_EV_PHONE" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
RI_V=$(evalv "$RI_T/phone.json" 1 | ri_nj); RI_E=$(evalv "$RI_T/phone.json" 2)
ri_row "remote id: the plan on a phone (375 × 812, touch): select opens the detail card with the plan at least 280 px wide inside the viewport, no sideways scroll, the figure at 11 px or more" '{"errors":0,"phone":"on|detail|true|true|true|true"}'

# ---- R20 every aircraft among the drawn marks: Remote ID ranks right after watched (btCmp, §3.1), so an aircraft at -95 dBm among sixty public addresses
# at -40 is drawn and hit and opens its sheet with the plan, while an address without Remote ID at -96 ranks beyond the 48 drawn (BT.drawMax)
RI_EV_REACH="(async()=>{$RI_JS"'
ld(d=>{d.aps=[];d.unassociated=[];const p=d.bluetooth.find(b=>b.addr===A(7));d.bluetooth.find(b=>b.addr===A(1)).rssi=-95;
 for(let i=0;i<60;i++)d.bluetooth.push({...p,addr:"02:00:00:00:0e:"+i.toString(16).padStart(2,"0"),rssi:-40});d.bluetooth.push({...p,addr:"02:00:00:00:0e:ff",rssi:-96});},G,"ri-reach");await sleep(1600);STARCHORUS.frame();
const k=S.bt.get(M(1)),n=STARCHORUS.nodeScreen(M(1));o.rank=k.rank<48;o.order=S.btOrder.slice(0,4).map(x=>x.id.slice(-5)).join();o.hit=STARCHORUS.hitTest(n.sx,n.sy);
o.sel=STARCHORUS.select(M(1));o.plans=E("detail-body").querySelectorAll("svg.rp").length;STARCHORUS.deselect();o.ctl=S.bt.get("bt:02:00:00:00:0e:ff").rank>=48;o.marks=S.btOrder.length;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
RI_W_REACH='{"ctl":true,"errors":0,"hit":"bt:02:00:00:00:0d:01","marks":67,"order":"0d:04,0d:02,0d:03,0d:01","plans":1,"rank":true,"sel":"Remote ID"}'
ri_run reach "$RI_EV_REACH"
ri_row "remote id: every aircraft among the drawn marks: with sixty public addresses at -40 dBm about, the aircraft at -95 ranks among the 48 drawn (the four marks with Remote ID first, by signal), is hit at its screen point and opens its sheet with the plan, while an address without Remote ID at -96 ranks beyond the 48" "$RI_W_REACH"
# ---- R20b the plan's probes: eleven planted copies, each differing from the page in one line, each turning exactly its scenes red
RI_PROBES=""; RI_PBAD=""
ri_probe pwest "$RI_EV_PLAN" "$RI_W_PLAN" "age,close,east,fx,noAlt,seam,shallow" 1 'return { d, e: d * Math.sin(t), n: d * Math.cos(t) };' 'return { d, e: -d * Math.sin(t), n: d * Math.cos(t) };'
ri_probe psouth "$RI_EV_PLAN" "$RI_W_PLAN" "age,close,fx,noAlt,north,pole,shallow,south" 1 'y = -g.n * s / 2, h = Math.hypot(x, y)' 'y = g.n * s / 2, h = Math.hypot(x, y)'
ri_probe pcap "$RI_EV_PLAN" "$RI_W_PLAN" "close,same,south" 1 'const s = Math.min(120 / Math.abs(g.e), 60 / Math.abs(g.n), 6),' 'const s = Math.min(120 / Math.abs(g.e), 60 / Math.abs(g.n)),'
ri_probe pends "$RI_EV_PLAN" "$RI_W_PLAN" "age,close,east,fx,noAlt,north,pole,same,seam,shallow,south" 1 '+ T(1, "aircraft") + T(-1, "operator") +' '+ T(1, "operator") + T(-1, "aircraft") +'
ri_probe pfresh "$RI_EV_PLAN" "$RI_W_PLAN" "age" 1 '" r="3.5" fill-opacity="'"'"' + k.freshAT + '"'"'"/>' '" r="3.5" fill-opacity="1"/>'
ri_probe pstack "$RI_EV_PLAN" "$RI_W_PLAN" "south" 1 '[x / h, y / h] : [0, y > 0 ? 1 : -1]' '[x / h, y / h] : [0, -1]'
ri_probe proot "$RI_EV_PLAN" "$RI_W_PLAN" "age,close,east,fx,noAlt,north,pole,same,seam,shallow,south" 1 '<svg class="rp" viewBox' '<svg class="rp" style="fill:red" viewBox'
ri_probe palt "$RI_EV_PLAN" "$RI_W_PLAN" "noAlt" 1 '(r.alt_m != null ? t(232, 109, "end", "altitude " + ridV(r, "alt_m") + " m") : "")' 't(232, 109, "end", "altitude " + ridV(r, "alt_m") + " m")'
ri_probe pbar "$RI_EV_PLAN" "$RI_W_PLAN" "age,close,east,fx,noAlt,north,pole,same,seam,shallow,south" 1 "'<path d=\"M22 108v4h' + f(B * s) + 'v-4M8" "'<path d=\"M22 108v4h' + f(B) + 'v-4M8"
ri_probe pnear "$RI_EV_PLAN" "$RI_W_PLAN" "shallow" 1 'q = h > 20 ? 9 + (Math.abs(u[1]) <= 0.4 ? 2.6 * ridM(g.d).length * Math.abs(u[1]) : 0) : 12 + Math.abs(x)' 'q = h > 20 ? 9 : 12 + Math.abs(x)'
ri_probe prank "$RI_EV_REACH" "$RI_W_REACH" "hit,order,rank" 1 ' || !!b.m[0].remote_id - !!a.m[0].remote_id' ''
RI_GN2=$(echo "$RI_PROBES" | wc -w | tr -d ' ')
rowif "remote id: the plan's probes bite ($RI_GN2 of 11: east and west swapped, north and south swapped, the close-range cap gone, the ends mislabelled, the freshness dropped, the stacked labels fixed upward, a style on the drawing itself, an altitude always printed, the bar drawn at the wrong length, the figure back on its line, the ranking removed), each turns exactly its keys red${RI_PBAD}" [ "$RI_GN2/${RI_PBAD:-ok}" = "11/ok" ]
