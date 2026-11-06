# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/watch-marks.sh -- the collector's watch.list marks on the page (0.2.7). A record that carries "watched": true (an access point, a
#   station, a Bluetooth address) wears the pin mark, which stations and Bluetooth marks never wore; it is drawn and labelled like a pinned star; a
#   listed rotating Bluetooth address is a mark of its own and comes first; the tooltip, the sheet, the legend, the JSON export and one SITREP line say
#   so. A listed phone hotspot or own transmitter stays unmarked (P3). Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only WM_*
#   globals are set.
#
# GUARDS AGAINST: a mark that needs a click; a click that takes the mark away (it toggles the operator's pin alone); an arc on a station or a
#   Bluetooth mark for a pin; a mark on a hotspot or an own transmitter; a listed rotating address folded into its company's mark or ranked past the
#   48 that are drawn; a listed station inside a bubble or hidden in its cloud, or one that stays in its bubble after it joins the list because the
#   layout did not run for the change; forced labels that break the text budget; a word the judges refuse; any of it on a document without the key.
# NEGATIVE PROBE: one-line copies of the page (served to headless Chrome on 127.0.0.1 only) -- no station arc, no P3 test, the address folded, the
#   old order of the marks, a bubble that takes a watched station, a list change that leaves the layout alone, an export without the key: each turns
#   exactly its own keys red.
# NOT PROVEN: that the collector writes the marks (its self-test, 'watch list: ...'); the arc in 3D and in the Scope (2D pixels only); a finger on a
#   phone (the click is a synthetic pointer event).
#
# Runs WITHOUT ?fixed: nodes must fade in for the pixel rows. Every address is in the 02:00:00 prefix, every name made up.

WM_FX="out/$P-wm.json"   # the marked document; each eval derives the unmarked one by deleting the key
cat > "$WM_FX" <<'EOF'
{"generated": 1789300000, "source": "recon-db", "center": {"label": "This device", "max_age": 3600, "interval": 30, "own_bssids": ["02:00:00:00:0d:04"], "bt_window": 6, "bt_hold": 120},
 "aps": [{"bssid": "02:00:00:00:0d:01", "watched": true, "ssid": "HomeNet", "channel": 6, "band": "2.4GHz", "freq": 2437, "rssi": -50, "security": "WPA2/PSK/CCMP", "clients": [], "last_seen": 1789299996},
  {"bssid": "02:00:00:00:0d:02", "ssid": "Meadow", "channel": 36, "band": "5GHz", "freq": 5180, "rssi": -62, "security": "WPA2/PSK/CCMP", "clients": [], "last_seen": 1789299996},
  {"bssid": "02:00:00:00:0d:03", "watched": true, "ssid": "Meadow hotspot", "channel": 11, "band": "2.4GHz", "freq": 2462, "rssi": -58, "security": "WPA2/PSK/CCMP", "clients": [], "last_seen": 1789299996},
  {"bssid": "02:00:00:00:0d:04", "watched": true, "ssid": "Lantern", "channel": 1, "band": "2.4GHz", "freq": 2412, "rssi": -68, "security": "WPA2/PSK/CCMP", "clients": [], "last_seen": 1789299996}],
 "unassociated": [{"mac": "02:00:00:00:0e:01", "watched": true, "rssi": -66, "last_seen": 1789299990, "vendor": "Vendor G"},
  {"mac": "02:00:00:00:0e:02", "rssi": -72, "last_seen": 1789299990, "vendor": "Vendor H"}],
 "bluetooth": [{"addr": "02:00:00:00:0f:01", "watched": true, "addr_type": "public", "rssi": -55, "reports": 2, "last_seen": 1789299996},
  {"addr": "02:00:00:00:0f:02", "watched": true, "addr_type": "random-resolvable", "rssi": -63, "reports": 1, "last_seen": 1789299996, "company": 65535, "company_name": "Maker A"},
  {"addr": "02:00:00:00:0f:03", "addr_type": "random-resolvable", "rssi": -64, "reports": 1, "last_seen": 1789299996, "company": 65535, "company_name": "Maker A"},
  {"addr": "02:00:00:00:0f:04", "addr_type": "random-resolvable", "rssi": -65, "reports": 1, "last_seen": 1789299996, "company": 65535, "company_name": "Maker A"}]}
EOF
WM_Q="?poll=0&spin=0&intro=0&debug=1"
WM_RDY="window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'"
wm_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }
# wm_run NAME EVAL [FIXTURE] [QUERY]: one run, the value of the eval (normalised JSON) in WM_V
wm_run() { runq "${3:-$WM_FX}" "${4:-$WM_Q}" "out/$P-wm-$1" --fps 0 --wait 3 --ready "$WM_RDY" --eval-timeout 150 --eval "$2" >/dev/null 2>&1; WM_V=$(evalv "out/$P-wm-$1.json" 1 | wm_nj); }
wm_row() {   # wm_row LABEL WANT_JSON
  _wm_w=$(printf '%s' "$2" | wm_nj)
  if [ "$WM_V" = "$_wm_w" ]; then row "$1" PASS; else row "$1" FAIL; echo "    got:  $(printf '%s' "$WM_V" | cut -c1-600)"; echo "    want: $_wm_w"; fi
}
# the preamble: the served document F and its unmarked copy P, the pixel reader, the click
WM_JS='const sleep=STARCHORUS.wait,o={},D=Math.PI/180;await sleep(900);const F=await (await fetch("starchorus.json")).json(),G=F.generated;
const plain=(d)=>{const c=JSON.parse(JSON.stringify(d));for(const k of ["aps","unassociated","bluetooth"])for(const x of c[k]||[])delete x.watched;return c;};
const pxl=(id,ang,r)=>{const n=STARCHORUS.nodeScreen(id),x=Math.round(n.sx+Math.cos(ang)*r),y=Math.round(n.sy+Math.sin(ang)*r);let b=0;for(let dx=-1;dx<=1;dx++)for(let dy=-1;dy<=1;dy++)b=Math.max(b,STARCHORUS.pixel("sky",x+dx,y+dy).a);return b;};
const hud=document.getElementById("hud");let pid=60;const click=(id)=>{const n=STARCHORUS.nodeScreen(id),e={clientX:n.sx,clientY:n.sy,pointerId:++pid,pointerType:"mouse",button:0,buttons:1,bubbles:true,isPrimary:true};hud.dispatchEvent(new PointerEvent("pointerdown",e));hud.dispatchEvent(new PointerEvent("pointerup",Object.assign({},e,{buttons:0})));};
STARCHORUS.setReducedMotion(true);STARCHORUS.setToggles({crt:false,labels:false,orbits:false,links:false,nebula:false,groups:false});'

# ---- the document validates, marked and unmarked (the contract's rule: watched only when true, right after the address)
python3 - "$WM_FX" "out/$P-wm-plain.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for k in ("aps", "unassociated", "bluetooth"):
    for x in d[k]: x.pop("watched", None)
json.dump(d, open(sys.argv[2], "w"))
PY
WM_VA=$(python3 tools/gen-testdata.py --validate "$WM_FX" 2>&1 | tail -1); WM_VB=$(python3 tools/gen-testdata.py --validate "out/$P-wm-plain.json" 2>&1 | tail -1)
WM_VOK=0; [ "${WM_VA% OK}" != "$WM_VA" ] && [ "${WM_VB% OK}" != "$WM_VB" ] && WM_VOK=1
rowif "watch marks: the test document validates with and without the key [$WM_VA | $WM_VB]" [ "$WM_VOK" = 1 ]

# ---- the arc: in each theme the pin mark at px+13 (on at 6 o'clock, the gap at 12) on the watched access point, station and Bluetooth address, read
# against the same place of the unmarked copy; none on the listed phone hotspot (P3) or the two unlisted controls
WM_EV_ARC="(async()=>{$WM_JS"'
F.bluetooth=F.bluetooth.slice(0,1);const P=plain(F);
const ids=["02:00:00:00:0d:01","02:00:00:00:0e:01","bt:02:00:00:00:0f:01","02:00:00:00:0d:03","02:00:00:00:0d:04","02:00:00:00:0d:02","02:00:00:00:0e:02"];
const read=()=>{STARCHORUS.frame();return ids.map(id=>{const r=STARCHORUS.nodeScreen(id).px+13;return [pxl(id,90*D,r),pxl(id,-90*D,r)];});};
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);STARCHORUS.load(F,"wm-arc");await sleep(1600);const on=read();STARCHORUS.load(P,"wm-arc");await sleep(600);const off=read();
 o[t]=ids.map((id,i)=>on[i][0]-off[i][0]>=100&&on[i][0]-on[i][1]>=70&&Math.abs(on[i][1]-off[i][1])<=20?1:0).join("");}
STARCHORUS.load(F,"wm-arc");await sleep(300);const h=STARCHORUS.node("02:00:00:00:0d:03");o.p3=[h.mobile,h.watched,STARCHORUS.node("02:00:00:00:0d:04").watched].join("/");o.wl=STARCHORUS.stats().wl;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
WM_WANT_ARC='{"errors":0,"foundation":"1110000","p3":"true/false/false","wargames":"1110000","whitehall":"1110000","wl":2}'
wm_run arc "$WM_EV_ARC"
wm_row "watch marks: the pin mark on the watched access point, station and Bluetooth address in all three themes, against the unmarked copy; none on the listed phone hotspot or own transmitter (P3: stats().wl 2) or the unlisted controls" "$WM_WANT_ARC"

# ---- a click on a watched star toggles the operator's pin alone: pinned, then not, and the mark stays (selected: at px+18; deselected: at px+13);
# an unlisted star clicked twice has no mark
WM_EV_CLICK="(async()=>{$WM_JS"'
F.bluetooth=F.bluetooth.slice(0,1);STARCHORUS.setTheme("whitehall");STARCHORUS.load(F,"wm-click");await sleep(1600);
const A="02:00:00:00:0d:01",C="02:00:00:00:0d:02",nd=(id)=>STARCHORUS.node(id),arc=(id,d)=>{STARCHORUS.frame();const r=nd(id).px+13+d,on=pxl(id,90*D,r);return on>=120&&pxl(id,-90*D,r)<on-70?1:0;};
click(A);await sleep(300);const a1=[nd(A).pinned,nd(A).watched],r1=arc(A,5);click(A);await sleep(300);const a2=[nd(A).pinned,nd(A).watched],r2=arc(A,5);
STARCHORUS.deselect();await sleep(200);const r3=arc(A,0);o.a=a1.concat(a2).join("/");o.arc=""+r1+r2+r3;
STARCHORUS.frame();const c0=pxl(C,90*D,nd(C).px+13);click(C);await sleep(300);const c1=nd(C).pinned;click(C);await sleep(300);const c2=nd(C).pinned;
STARCHORUS.deselect();await sleep(200);STARCHORUS.frame();o.c=[c1,c2,nd(C).watched].join("/");o.cArc=Math.abs(pxl(C,90*D,nd(C).px+13)-c0)<=20;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
wm_run click "$WM_EV_CLICK"
wm_row "watch marks: a click on a watched star pins it and a second unpins it, the mark stays (selected and after); an unlisted star clicked twice has none" '{"a":"true/true/false/true","arc":"111","c":"true/false/false","cArc":true,"errors":0}'

# ---- Bluetooth: the listed rotating address is a mark of its own (its siblings stay folded), the marks are ordered watched first, the tooltip says
# so; a weak listed address among 60 stronger ones is ranked first, drawn and hit; unmarked, it is 61st and neither
WM_EV_BT="(async()=>{$WM_JS"'
const S=STARCHORUS._internals.S,P=plain(F),st=()=>[...S.bt.values()].filter(k=>k.target===1).map(k=>k.id.slice(3)+"="+k.n).sort().join(" "),ord=()=>S.btOrder.map(k=>k.id).join(" ");
const tip=(id)=>{const n=STARCHORUS.nodeScreen(id);if(!n)return "none";STARCHORUS.hover(n.sx,n.sy);return document.getElementById("tip-body").textContent;};
STARCHORUS.load(F,"wm-bt");await sleep(1600);o.order=ord();o.members=st();o.tips=["bt:02:00:00:00:0f:01","bt:02:00:00:00:0f:02","bt:65535:2"].map(tip);STARCHORUS.hover(5,5);
STARCHORUS.load(P,"wm-bt");await sleep(1600);o.plainOrder=ord();o.plainMembers=st();o.plainTip=tip("bt:65535:2");STARCHORUS.hover(5,5);
const bt=[];for(let i=0;i<60;i++)bt.push({addr:"02:00:00:00:10:"+i.toString(16).padStart(2,"0"),addr_type:"public",rssi:-40-Math.floor(i/2),reports:1,last_seen:G-3});
const rk=async(w)=>{const d=plain(F);d.aps=[];d.unassociated=[];d.bluetooth=bt.concat([Object.assign({addr:"02:00:00:00:10:3c",addr_type:"public",rssi:-88,reports:1,last_seen:G-3},w?{watched:true}:{})]);
 STARCHORUS.load(d,"wm-rank"+(w?1:0));await sleep(1900);STARCHORUS.frame();const k=S.bt.get("bt:02:00:00:00:10:3c"),n=STARCHORUS.nodeScreen(k.id);return [S.btOrder[0].id===k.id,k.rank,STARCHORUS.hitTest(n.sx,n.sy)===k.id].join("/");};
o.rank=await rk(true);o.plainRank=await rk(false);
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
WM_WANT_BT='{"errors":0,"members":"02:00:00:00:0f:01=1 02:00:00:00:0f:02=1 65535:2=2","order":"bt:02:00:00:00:0f:01 bt:02:00:00:00:0f:02 bt:65535:2","plainMembers":"02:00:00:00:0f:01=1 65535:2=3","plainOrder":"bt:02:00:00:00:0f:01 bt:65535:2","plainRank":"false/60/false","plainTip":"Bluetooth LE · Maker A · 3 rotating addresses · -63 dBm strongest · not a device count","rank":"true/0/true","tips":["Bluetooth LE · company not advertised · -55 dBm · public address · last heard in a window 4 s ago · in watch.list","Bluetooth LE · Maker A · 1 rotating address · -63 dBm · not a device count · in watch.list","Bluetooth LE · Maker A · 2 rotating addresses · -64 dBm strongest · not a device count"]}'
wm_run bt "$WM_EV_BT"
wm_row "watch marks: Bluetooth: a listed rotating address is a mark of its own and first, its siblings stay folded, the tooltip says 'in watch.list'; a weak listed address among 60 stronger ones is ranked first, drawn and hit, unmarked it is 61st and neither" "$WM_WANT_BT"

# ---- the words and the exports: tooltip, sheet, legend, JSON, SITREP and the API, against the unmarked copy
WM_EV_TXT="(async()=>{$WM_JS"'
const P=plain(F),A="02:00:00:00:0d:01",B="02:00:00:00:0d:02",Hs="02:00:00:00:0d:03",Ow="02:00:00:00:0d:04",S1="02:00:00:00:0e:01",S2="02:00:00:00:0e:02";
const tip=(id)=>{STARCHORUS.hoverNode(id);return document.getElementById("tip-body").textContent;},leg=()=>document.getElementById("leg-pin").textContent;
const row=(id)=>{STARCHORUS.select(id);const r=[...document.querySelectorAll("#detail-body tr")].map(x=>x.cells[0].textContent+"="+x.cells[1].textContent).filter(x=>/^Listed=/.test(x)).join(";");STARCHORUS.deselect();return r;};
STARCHORUS.load(F,"wm-txt");await sleep(1200);o.tips=[A,B,S1,S2].map(id=>/in watch\.list$/.test(tip(id))?1:0).join("");STARCHORUS.hoverNode(null);
o.rows=[A,B,S1,S2].map(row);o.legend=leg();
const J=JSON.parse(STARCHORUS.exportText("json"));o.json=[J.aps.map(a=>a.bssid+(a.watched?"*":"")).join(" "),J.stations.map(x=>x.mac+(x.watched?"*":"")).join(" "),J.bluetooth.filter(b=>b.watched).map(b=>b.addr+">"+b.mark).join(" "),J.mobile_hotspots].join("|");
const T=STARCHORUS.exportText("sitrep").split("\n"),i=T.findIndex(l=>/^Access points:/.test(l));o.sitrep=T.slice(i,i+2);
o.api=[A,B,Hs,Ow,S1,S2].map(id=>STARCHORUS.node(id).watched?1:0).join("")+"/"+STARCHORUS.stats().wl;
STARCHORUS.load(P,"wm-txt");await sleep(600);o.plain=[leg(),STARCHORUS.exportText("json").indexOf("\"watched\""),STARCHORUS.exportText("sitrep").split("\n").filter(l=>/^Watched:/.test(l)).length,STARCHORUS.stats().wl,row(A)].join("|");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
WM_WANT_TXT='{"api":"100010/2","errors":0,"json":"02:00:00:00:0d:01* 02:00:00:00:0d:02|02:00:00:00:0e:01* 02:00:00:00:0e:02|02:00:00:00:0f:01>bt:02:00:00:00:0f:01 02:00:00:00:0f:02>bt:02:00:00:00:0f:02|1","legend":"pinned, or in watch.list","plain":"pinned|-1|0|0|","rows":["Listed=in watch.list on the device; edit that file to take the mark off","","Listed=in watch.list on the device; edit that file to take the mark off",""],"sitrep":["Access points: 2 · stations: 2 (2 free, 0 associated) · mobile hotspots: 1","Watched: 2 (in watch.list on the device)"],"tips":"1010"}'
wm_run txt "$WM_EV_TXT"
wm_row "watch marks: words and exports: 'in watch.list' in the tooltips of the two watched records, the sheet row 'Listed', the legend 'pinned, or in watch.list', watched: true in JSON (hotspot and own transmitter not exported), 'Watched: 2 (in watch.list on the device)' after the SITREP counts, node().watched and stats().wl 2; none of it unmarked" "$WM_WANT_TXT"

# ---- the judges over what the marks add: the lines of legend, tooltips, sheets and exports (3 themes) that the marked document has and the unmarked one
# has not; P10, the legal denylist, the direction and distance words and track/pilot/locate/scanner find nothing; a dummy with 'track the target north' is flagged
WM_EV_HARV="(async()=>{$WM_JS"'
const P=plain(F),harv=async(d)=>{const seen=new Set(),add=(s)=>{for(const l of String(s==null?"":s).split("\n")){const t=l.trim();if(t)seen.add(t);}};STARCHORUS.load(d,"wm-harv");await sleep(1200);
 for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await sleep(200);add(document.getElementById("legend").innerText);
  for(const id of ["02:00:00:00:0d:01","02:00:00:00:0e:01"]){STARCHORUS.hoverNode(id);add(document.getElementById("tip-body").textContent);STARCHORUS.select(id);add(document.getElementById("detail-body").innerText);STARCHORUS.deselect();}
  for(const k of STARCHORUS._internals.S.btOrder){const n=STARCHORUS.nodeScreen(k.id);STARCHORUS.hover(n.sx,n.sy);add(document.getElementById("tip-body").textContent);}STARCHORUS.hover(5,5);}
 for(const f of ["json","csv","sitrep"])add(STARCHORUS.exportText(f));return seen;};
const on=await harv(F),off=await harv(P);return [...on].filter(l=>!off.has(l)).join("\n");})()'
runq "$WM_FX" "$WM_Q" "out/$P-wm-harv" --fps 0 --wait 3 --ready "$WM_RDY" --eval-timeout 150 --eval "$WM_EV_HARV" >/dev/null 2>&1
evalv "out/$P-wm-harv.json" 1 > "out/$P-wm-harv.txt"; printf 'track the target north of the pager and away\n' > "out/$P-wm-harv-dummy.txt"
WM_DR=$(sed -n 's/^    h = re.findall(r"\(.*\)", t)$/\1/p' tools/regress.d/scope.sh)   # the one definition of the direction and distance words, read where it lives (the Scope judge), as alerts.sh reads it
wm_judge() {   # wm_judge FILE -> "ok" or the hits (P10, direction and distance, track/pilot/locate/scanner)
  python3 - "$1" "$WM_DR" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8", errors="replace").read()
P10 = r"(?a)\b(evil[ -]?twin|rogue|attack(er)?|threat|intru(der|sion)|malicious|spoof(ed|ing)?|karma|bandit|target|deauth flood)\b"
DIR = sys.argv[2] or "(?!)"   # no definition read: nothing matches, and the WM_JR guard below is red
EXTRA = r"\b(track\w*|pilot\w*|locat\w*|scanner\w*|away|near\w*)\b"
need = ["pinned, or in watch.list", "in watch.list on the device; edit that file to take the mark off", "Watched: 2 (in watch.list on the device)", "· in watch.list"]
hits = [m.group(0) for rx in (P10, DIR, EXTRA) for m in re.finditer(rx, t, re.I)]
miss = [n for n in need if n not in t]
print("ok" if not hits and not miss else "hits=%s missing=%s" % (hits[:6], miss))
PY
}
WM_JP=$(grep -cF 'evil[ -]?twin|rogue|attack(er)?|threat|intru(der|sion)|malicious|spoof(ed|ing)?|karma|bandit|target|deauth flood' tools/regress.d/neutral-language.sh)   # the P10 words of wm_judge are the one definition's, byte for byte (a copy that drifts is red)
WM_JR=0; case $WM_DR in *"direction|bearing|heading"*"|°") WM_JR=1 ;; esac   # the definition was read whole from the Scope judge (its head and its tail)
WM_JH=$(wm_judge "out/$P-wm-harv.txt"); WM_JD=$(wm_judge "out/$P-wm-harv-dummy.txt")
WM_JL=$(sh tools/denylist-check.sh "$R/out/$P-wm-harv.txt" >/dev/null 2>&1; echo $?); WM_JN=$(grep -c . "out/$P-wm-harv.txt")
WM_JOK=0; [ "$WM_JH" = ok ] && [ "$WM_JL" = 0 ] && [ "${WM_JD#hits=}" != "$WM_JD" ] && [ "$WM_JN" -ge 5 ] && [ "$WM_JP/$WM_JR" = 1/1 ] && WM_JOK=1
rowif "watch marks: the judges hold over the $WM_JN lines the marks add (P10, legal denylist $WM_JL, direction and distance, track/pilot/locate/scanner/away/near; the word lists are neutral-language.sh's and scope.sh's: $WM_JP/$WM_JR) [$WM_JH]; a dummy is flagged [$(printf '%s' "$WM_JD" | cut -c1-60)]" [ "$WM_JOK" = 1 ]

# ---- a watched station stays out of a bubble (field-probes.json) and is shown on its own while it stays a member of its cloud (clouds.json); both back unmarked
WM_EV_BUB="(async()=>{$WM_JS"'
const nd=(id)=>STARCHORUS.node(id),settled=async()=>{await sleep(2200);STARCHORUS.settle();await sleep(400);};await settled();
const b=STARCHORUS.bubbles().find(x=>x.members.length>=3),M=b.members[0],b0=nd(M).bubble;
const W=JSON.parse(JSON.stringify(F));W.unassociated.find(u=>u.mac===M).watched=true;STARCHORUS.load(W,"wm-bub");await settled();const n1=nd(M),v1=STARCHORUS.nodeScreen(M).visible;
STARCHORUS.load(F,"wm-bub");await settled();o.bubble=[b0!==null,n1.bubble===null,n1.watched,v1,nd(M).bubble!==null].join("/");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
wm_run bub "$WM_EV_BUB" "$F/field-probes.json"
WM_B1=$WM_V
WM_EV_CLD="(async()=>{$WM_JS"'
const nd=(id)=>STARCHORUS.node(id);await sleep(1800);const k=STARCHORUS.clouds()[0],R=k.members[0],a0=nd(R).alphaDraw;
const W=JSON.parse(JSON.stringify(F));W.unassociated.find(u=>u.mac===R).watched=true;STARCHORUS.load(W,"wm-cld");await sleep(1800);const n1=nd(R);
o.cloud=[a0<0.05,n1.watched,n1.cloud===k.id,n1.alphaDraw>0.5].join("/");o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
wm_run cld "$WM_EV_CLD" "$F/clouds.json"
WM_V="[$WM_B1,$WM_V]"
wm_row "watch marks: a watched free station leaves its bubble and is drawn (back in it unmarked); a watched randomised address is shown on its own and stays in its cloud" '[{"bubble":"true/true/true/true/true","errors":0},{"cloud":"true/true/true/true","errors":0}]'

# ---- the layout follows the list by itself: a station that joins the list in a LATER capture leaves its bubble in that capture and is back in it once
# unmarked, with no settle forced (the row above calls STARCHORUS.settle(); here the page's own relayout must run for the changed list, as it does for a
# changed signal: the list is compared capture to capture in ingest). idle() waits for the page's own settle, and returns at once where no layout ran.
WM_EV_FLIP="(async()=>{$WM_JS"'
const nd=(id)=>STARCHORUS.node(id),idle=async()=>{for(let i=0;i<40&&!STARCHORUS.layoutInfo().settled;i++)await sleep(100);await sleep(400);};await sleep(2200);await idle();
const b=STARCHORUS.bubbles().find(x=>x.members.length>=3),M=b.members[0],b0=nd(M).bubble;
const W=JSON.parse(JSON.stringify(F));W.generated+=30;W.unassociated.find(u=>u.mac===M).watched=true;STARCHORUS.load(W,"wm-flip");await idle();const n1=nd(M);
const B=JSON.parse(JSON.stringify(F));B.generated+=60;STARCHORUS.load(B,"wm-flip");await idle();o.flip=[b0!==null,n1.bubble===null,n1.watched,nd(M).bubble!==null].join("/");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
wm_run flip "$WM_EV_FLIP" "$F/field-probes.json"
wm_row "watch marks: the layout follows the list by itself: a station that joins watch.list in a later capture leaves its bubble in that capture and is back in it once unmarked, with no settle forced" '{"errors":0,"flip":"true/true/true/true"}'

# ---- [ and ] step through the pinned and the watched access points and stations (and do nothing unmarked); on a phone the sheet's step arrows show for two watched nodes, not for one
WM_EV_KEY="(async()=>{$WM_JS"'
const key=(k)=>window.dispatchEvent(new KeyboardEvent("keydown",{key:k})),seq=[];STARCHORUS.load(F,"wm-key");await sleep(900);
for(const k of ["]","]","]","["]){key(k);await sleep(100);seq.push(STARCHORUS.camera().locked);}o.seq=seq.join(" ");STARCHORUS.deselect();
STARCHORUS.load(plain(F),"wm-key");await sleep(600);key("]");await sleep(100);o.plain=STARCHORUS.camera().locked;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
wm_run key "$WM_EV_KEY"
WM_K1=$WM_V
WM_EV_PH="(async()=>{$WM_JS"'
const arrows=()=>document.getElementById("sheet-prev").hidden;STARCHORUS.load(F,"wm-ph");await sleep(900);STARCHORUS.select("02:00:00:00:0d:01");await sleep(300);o.two=arrows();STARCHORUS.deselect();
const one=JSON.parse(JSON.stringify(F));delete one.unassociated[0].watched;STARCHORUS.load(one,"wm-ph");await sleep(900);STARCHORUS.select("02:00:00:00:0d:01");await sleep(300);o.one=arrows();STARCHORUS.deselect();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
wm_run ph "$WM_EV_PH" "$WM_FX" "$WM_Q&phone=1"
WM_V="[$WM_K1,$WM_V]"
wm_row "watch marks: ] ] ] [ select the watched access point, the station, the access point, the station; nothing unmarked; on a phone the step arrows show for two watched nodes and not for one" \
  '[{"errors":0,"plain":null,"seq":"02:00:00:00:0d:01 02:00:00:00:0e:01 02:00:00:00:0d:01 02:00:00:00:0e:01"},{"errors":0,"one":true,"two":false}]'

# ---- the text budget holds with 40 watched access points (every third of field-scale's 120 by signal): in both views and all three themes the
# counted text stays inside 30/24 and the watched names come before any other; unmarked, the names stay inside maxLabels (24/16)
WM_EV_BUD='(async()=>{const o={},cap={"2d":30,"3d":24},ml=STARCHORUS._internals.RENDER.maxLabels[0],W=new Set();await STARCHORUS.wait(900);
const F=await (await fetch("starchorus.json")).json();F.aps.slice().sort((a,b)=>b.rssi-a.rssi||(a.bssid<b.bssid?-1:1)).forEach((a,i)=>{if(i%3===0){a.watched=true;W.add(a.bssid);}});
STARCHORUS.setReducedMotion(true);STARCHORUS.load(F,"wm-bud");await STARCHORUS.wait(1600);o.wl=STARCHORUS.stats().wl;const ok=[],order=[],plain=[];
for(const v of ["2d","3d"]){STARCHORUS.setView(v);await STARCHORUS.wait(1400);for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await STARCHORUS.wait(700);STARCHORUS.frame();
 const L=STARCHORUS.labels().filter(l=>l.kind==="label"&&l.id!=="__center__"),ft=STARCHORUS.perf().drawCalls.fillText,fi=L.findIndex(l=>!W.has(l.id));
 ok.push(L.length<=cap[v]&&ft<=cap[v]?1:0);order.push(fi<0||L.slice(fi).every(l=>!W.has(l.id))?1:0);}}
STARCHORUS.setView("2d");await STARCHORUS.wait(1400);const P=JSON.parse(JSON.stringify(F));for(const a of P.aps)delete a.watched;STARCHORUS.load(P,"wm-bud");await STARCHORUS.wait(800);
for(const v of ["2d","3d"]){STARCHORUS.setView(v);await STARCHORUS.wait(1400);for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await STARCHORUS.wait(700);STARCHORUS.frame();
 plain.push(STARCHORUS.labels().filter(l=>l.kind==="label"&&l.id!=="__center__").length<=ml[v==="3d"?1:0]?1:0);}}
o.ok=ok.join("");o.order=order.join("");o.plain=plain.join("");o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$F/field-scale.json" "?poll=0&spin=0&intro=0&debug=1&autolod=0" "out/$P-wm-bud" --width 1440 --height 900 --wait 4 --fps 0 --ready "$WM_RDY" --eval-timeout 180 --eval "$WM_EV_BUD" >/dev/null 2>&1
WM_V=$(evalv "out/$P-wm-bud.json" 1 | wm_nj)
wm_row "watch marks: the text budget holds with 40 watched access points: counted text inside 30 (2D) and 24 (3D) in all three themes, the watched names first; unmarked inside maxLabels" '{"errors":0,"ok":"111111","order":"111111","plain":"111111","wl":40}'

# ---- absent: on every fixture no mark, no word, no key: stats().wl 0, the legend 'pinned', no watched in the JSON, no Watched line,
# no Bluetooth mark of a watched address, node().watched false everywhere (one run over a bundle of the fixtures, as order-invariance.sh builds it);
# then present in the sample sky (STARCHORUS.loadDemo(), the same run): its watched access point, station and Bluetooth address (0.2.7, the sky
# that carries every kind): stats().wl 2 (the access point and the station; the Bluetooth address is a mark, not a node), the legend text, three
# watched keys in the JSON, the SITREP line 'Watched: 2', the watched keyring first among the Bluetooth marks and watched on both nodes
python3 -B - "$F" "out/$P-wm-absent.json" <<'PYEND'
import glob, json, os, sys
o = {os.path.basename(f)[:-5]: json.load(open(f, encoding="utf-8")) for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.json")))}
json.dump({"generated": 1789300000, "center": {"label": "absent"}, "source": "none", "aps": [], "unassociated": [], "absent": o}, open(sys.argv[2], "w"))
PYEND
WM_EV_ABS='(async()=>{const o={},I=STARCHORUS._internals,bad=[];await STARCHORUS.wait(600);const B=(await (await fetch("starchorus.json")).json()).absent;
const one=(name)=>{const j=STARCHORUS.exportText("json"),s=STARCHORUS.exportText("sitrep");if(STARCHORUS.stats().wl!==0||document.getElementById("leg-pin").textContent!=="pinned"||j.indexOf("\"watched\"")>=0||/\nWatched: /.test(s)
 ||I.S.btOrder.some(k=>k.m[0].watched)||STARCHORUS.nodes().some(n=>STARCHORUS.node(n.id).watched))bad.push(name);};
let n=0;for(const [name,doc] of Object.entries(B)){STARCHORUS.load(doc,name);await STARCHORUS.wait(50);one(name);n++;}
STARCHORUS.loadDemo();await STARCHORUS.wait(50);const j=STARCHORUS.exportText("json"),s=STARCHORUS.exportText("sitrep"),W=STARCHORUS.nodes().filter(x=>STARCHORUS.node(x.id).watched).map(x=>x.kind).sort().join();
o.demo=[STARCHORUS.stats().wl,document.getElementById("leg-pin").textContent,(j.match(/"watched": true/g)||[]).length,(s.match(/\nWatched: [^\n]*/)||[""])[0].trim(),I.S.btOrder[0].m[0].watched===true,W].join("|");
o.n=n;o.bad=bad.join(" ");o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
wm_run absent "$WM_EV_ABS" "out/$P-wm-absent.json"
WM_NF=$(find "$F" -maxdepth 1 -name '*.json' | wc -l | tr -d ' ')
wm_row "watch marks: absent on all $WM_NF fixtures (no mark, no word, no key), and present in the sample sky: its watched access point, station and Bluetooth address (wl 2, the legend text, three JSON keys, the SITREP line, the keyring first among the marks)" "{\"bad\":\"\",\"demo\":\"2|pinned, or in watch.list|3|Watched: 2 (in watch.list on the device)|true|ap,client\",\"errors\":0,\"n\":$WM_NF}"

# ---- the probes bite: one-line copies of the page, each run on the eval its rule keeps right, must differ in exactly the named keys of the answer
# (the unmutated page is the control: the rows above). Each anchor occurs exactly once in the page.
wm_probe() {   # wm_probe NAME RUN_ARGS_EVAL WANT_JSON KEYS OLD NEW [FIXTURE]
  _wp_n=$1; _wp_e=$2; _wp_w=$3; _wp_k=$4; _wp_o=$5; _wp_x=$6; _wp_f=${7:-$WM_FX}
  if python3 - "$H" "out/$P-wm-mut-$_wp_n.html" "$_wp_o" "$_wp_x" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
if t.count(sys.argv[3]) != 1: sys.exit("anchor: %d occurrences" % t.count(sys.argv[3]))
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(sys.argv[3], sys.argv[4]))
PY
  then
    WM_HKEEP=$H; H="out/$P-wm-mut-$_wp_n.html"; wm_run "mut-$_wp_n" "$_wp_e" "$_wp_f"; H=$WM_HKEEP
    _wp_d=$(python3 - "$WM_V" "$_wp_w" <<'PY'
import json, sys
g, w = json.loads(sys.argv[1] or "{}"), json.loads(sys.argv[2])
print(",".join(sorted(k for k in set(g) | set(w) if g.get(k) != w.get(k))))
PY
    )
  else _wp_d="anchor"; fi
  if [ "$_wp_d" = "$_wp_k" ]; then WM_PROBES="$WM_PROBES $_wp_n"; else WM_PBAD="$WM_PBAD [$_wp_n: differs in '$_wp_d', want '$_wp_k']"; fi
}
WM_PROBES=""; WM_PBAD=""
wm_probe station "$WM_EV_ARC" "$WM_WANT_ARC" "foundation,wargames,whitehall" \
  '    if (S.wl.has(c.id)) { setAlpha(ctx, alpha); drawPinMark(ctx, sx, sy, px + ENCODING.selectionRingOffsetPx); }   // watch.list only
' ''
wm_probe p3 "$WM_EV_ARC" "$WM_WANT_ARC" "foundation,p3,wargames,whitehall,wl" '!eventSkip(nodeById(id))' 'nodeById(id)'
wm_probe folded "$WM_EV_BT" "$WM_WANT_BT" "members,order,tips" 'rot && !b.watched' 'rot'
wm_probe order "$WM_EV_BT" "$WM_WANT_BT" "rank" '.sort(btCmp)' '.sort((a, b) => b.rssi - a.rssi || cmpStr(a.id, b.id))'
wm_probe bubble "$WM_EV_BUB" '{"bubble":"true/true/true/true/true","errors":0}' "bubble" '&& !c.randOut && !S.wl.has(c.id))' '&& !c.randOut)' "$F/field-probes.json"
wm_probe flip "$WM_EV_FLIP" '{"errors":0,"flip":"true/true/true/true"}' "flip" '[...S.wl].some(id => !wl0.has(id))) changed = true;' '[...S.wl].some(id => !wl0.has(id))) ;' "$F/field-probes.json"
wm_probe export "$WM_EV_TXT" "$WM_WANT_TXT" "json,sitrep" 'if (S.wl.has(id)) o.watched = true; ' ''
WM_PN=$(echo "$WM_PROBES" | wc -w | tr -d ' ')
WM_POK=0; [ "$WM_PN" = 7 ] && [ -z "$WM_PBAD" ] && WM_POK=1
rowif "watch marks: the probes bite ($WM_PN of 7: no station arc, no P3 test, the address folded, the old order, a bubble that takes the station, a list change that leaves the layout alone, an export without the key), each turns exactly its keys red${WM_PBAD}" [ "$WM_POK" = 1 ]
