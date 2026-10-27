# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/operator-tools.sh -- the operator's tools on top of the observations.
#   library (import/export, OUI rules, bulk assign) · notes (alias/notes/tags) · inventory table · homing ·
#   export (json/csv/sitrep, PNG snapshot, print) · P1/P2/P6/P7/P8 · D15 with the drawers · keys and query
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only OPS_* globals are set.
#
# Not covered (documented, not faked): the clipboard write itself (navigator.clipboard needs a user gesture in a real browser; the fallback text is checked),
# window.print()'s dialog (stubbed), and the WebAudio tone of the homing meter (off by default; the toggle and its state are checked).

OPS_Q="?poll=0&spin=0&intro=0&debug=1"
ops_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }

# ---- library, rules, bulk assign, notes; P2 (observed APs only) and P7 (a rule never assigns suspect)
OPS_EVL='(async()=>{
const ap=(n,ch,ssid,extra)=>Object.assign({bssid:"02:00:00:00:06:"+String(n).padStart(2,"0"),ssid:ssid==null?"lib"+n:ssid,band:"2.4",channel:ch,freq:2407+5*ch,rssi:-50-n,security:"WPA2"},extra||{});
const id=(n)=>"02:00:00:00:06:"+String(n).padStart(2,"0"),o={};
const doc=(g,extra)=>Object.assign({source:"recon-db",generated:g,aps:[ap(1,1,"corp"),ap(2,6,"corp"),ap(3,11,"guest"),ap(4,6,"other"),ap(5,1,"pub",{security:"Open"})],unassociated:[{mac:"3c:22:fb:10:20:31",rssi:-70}]},extra||{});
STARCHORUS.load(doc(100),"lib");
o.err0=STARCHORUS.errors().length;o.clientOnly=STARCHORUS.libraryImport("3c:22:fb:10:20:31 friend").message;
// single entries, a rule, a client MAC (ACCEPTED), a suspect wildcard rule (ACCEPTED), a bad rule, an unheard MAC, comments
const t=["# my library",id(1)+" friend","3c:22:fb:10:20:31 friend","02:00:00:??:??:?? neutral","aa:bb:cc:??:??:?? suspect",id(3)+" suspect","de:ad:be:ef:00:99 neutral","zz:zz:zz:?? friend",id(4)+" banana"].join("\n");
const r=STARCHORUS.libraryImport(t);o.added=r.added;o.rules=r.rules;o.rej=r.rejected.length;o.msg=r.message;
o.rejWhy=r.rejected.map(x=>x.why).sort().join("|");
o.ident=[1,2,3,4,5].map(n=>STARCHORUS.identity(id(n))).join(",");
o.src=[1,2,3,4,5].map(n=>STARCHORUS.identitySource(id(n))).join(",");
o.clientIdent=STARCHORUS.identity("3c:22:fb:10:20:31");o.identKeys=Object.keys(STARCHORUS.identities()).sort().join(",");
const ex=STARCHORUS.libraryExport();o.exFirst=ex.split("\n")[0].slice(0,40);o.exHasClient=/3c:22:fb/.test(ex);o.exLines=ex.trim().split("\n").filter(l=>l&&l[0]!=="#").join("|");
o.stored=Object.keys(localStorage).filter(k=>k.indexOf("starchorus.")===0).sort().join(",");
o.bulk=STARCHORUS.libraryAssign("friend",{ssid:"corp"});o.bulkBad=STARCHORUS.libraryAssign("hostile",{ssid:"corp"});o.bulkNone=STARCHORUS.libraryAssign("friend",{ssid:"nobody"});
STARCHORUS.load(doc(105,{aps:[ap(1,1,"corp")]}),"lib");const ex2=STARCHORUS.libraryExport();o.exAfter=ex2.trim().split("\n").filter(l=>l&&l[0]!=="#").join("|");
STARCHORUS.load(doc(110),"lib");
const nt=STARCHORUS.notes(id(2),{alias:"B"+String.fromCharCode(7)+"uro",note:"second floor",tags:["a","b","c","d","e"]});
o.note=JSON.stringify(nt);o.noteClient=STARCHORUS.notes("3c:22:fb:10:20:31",{alias:"x"});o.noteUnknown=STARCHORUS.notes("de:ad:be:ef:00:99",{alias:"x"});
o.noteStore=Object.keys(JSON.parse(localStorage.getItem("starchorus.notes.v1")||"{}")).join(",");
STARCHORUS.hoverNode(id(2));o.tip=/Buro/.test(document.getElementById("tip").innerText);STARCHORUS.hoverNode(null);
STARCHORUS.select(id(2));const d=document.getElementById("detail-body");o.detailInputs=["nt-a","nt-n","nt-t"].map(i=>!!d.querySelector("#"+i)).join();o.detailAlias=d.querySelector("#nt-a").value;
d.querySelector("#nt-a").value="Lab";d.querySelector("#nt-a").dispatchEvent(new Event("change"));o.aliasEdit=STARCHORUS.notes(id(2)).alias;STARCHORUS.deselect();
STARCHORUS.notes(id(2),{alias:"",note:"",tags:[]});o.noteGone=STARCHORUS.notes(id(2))===null&&!localStorage.getItem("starchorus.notes.v1");
STARCHORUS.notes(id(1),{alias:"Front",note:"secret note text",tags:["x"]});const ej=STARCHORUS.exportText("json");o.exAlias=/"alias": "Front"/.test(ej);o.exNote=/secret note text/.test(ej+STARCHORUS.exportText("csv")+STARCHORUS.exportText("sitrep"));
STARCHORUS.clearLocalData();o.cleared=Object.keys(localStorage).filter(k=>k.indexOf("starchorus.")===0).join(",")||"none";o.afterClear=[STARCHORUS.identity(id(1)),STARCHORUS.notes(id(1))===null,STARCHORUS.libraryExport().trim().split("\n").length].join();
o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$OPS_Q" "out/$P-ops-lib" --wait 2 --fps 0 --eval-timeout 90 --eval "$OPS_EVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
OPS_L=$(evalv "out/$P-ops-lib.json" 1 | ops_nj); OPS_LE=$(evalv "out/$P-ops-lib.json" 2)
OPS_LW='{"added":3,"afterClear":"unknown,true,1","aliasEdit":"Lab","bulk":2,"bulkBad":2,"bulkNone":0,"cleared":"none","clientIdent":"friend","clientOnly":"","detailAlias":"Buro","detailInputs":"true,true,true","err0":0,"errors":0,"exAfter":"3c:22:fb:10:20:31 friend|02:00:00:00:06:01 suspect|02:00:00:??:??:?? neutral|aa:bb:cc:??:??:?? hostile","exAlias":true,"exFirst":"# Starchorus library · observed keys (AP","exHasClient":true,"exLines":"3c:22:fb:10:20:31 friend|02:00:00:00:06:01 friend|02:00:00:00:06:03 suspect|02:00:00:??:??:?? neutral|aa:bb:cc:??:??:?? hostile","exNote":false,"ident":"friend,neutral,hostile,neutral,neutral","identKeys":"02:00:00:00:06:01,02:00:00:00:06:03,3c:22:fb:10:20:31","msg":"3 rejected","note":"{\"alias\":\"Buro\",\"note\":\"second floor\",\"tags\":[\"a\",\"b\",\"c\",\"d\"]}","noteClient":{"alias":"x","note":"","tags":[]},"noteGone":false,"noteStore":"02:00:00:00:06:02,3c:22:fb:10:20:31","noteUnknown":null,"rej":3,"rejWhy":"not a valid rule|not observed|unknown class","rules":2,"src":"manual,rule-matched,manual,rule-matched,rule-matched","stored":"starchorus.identity.v1,starchorus.library.v1,starchorus.ui.v1","tip":true}'
if [ "$OPS_L" = "$OPS_LW" ] && [ "$OPS_LE" = 0 ]; then
  row "library: import ACCEPTS a station and a suspect wildcard rule, rejects an unheard MAC, rules match by OUI (rule-matched), bulk assign incl. hostile, export lists observed keys incl. the station; notes (alias/note/tags <= 4, control chars stripped) on a station tood for stations, alias in the tip and export, no note text exported, Clear local data empties both new keys" PASS
else
  row "library (err ${OPS_LE:-?})" FAIL
  echo "    got:  $(printf '%s' "$OPS_L" | cut -c1-700)"; echo "    want: $OPS_LW"
fi

# ---- inventory + export + homing (one page run each)
OPS_EVI='(async()=>{
await STARCHORUS.wait(1500);const o={};
const ids=STARCHORUS.inventory();o.all=ids.length;o.aps=STARCHORUS.stats().aps;
STARCHORUS.setToggles({inventory:true});await STARCHORUS.wait(300);const ib=document.getElementById("inv-body");
o.rows=ib.querySelectorAll("tbody tr").length;o.chips=[...ib.querySelectorAll(".chip")].slice(0,6).map(c=>c.textContent).join("|");
o.legendHidden=getComputedStyle(document.getElementById("legend-body")||document.body).display;o.drawer=document.documentElement.dataset.drawer;
o.noStationMac=!/[0-9a-f]{2}(:[0-9a-f]{2}){5}/i.test([...ib.querySelectorAll("tbody tr")].filter(r=>!ids.includes(r.getAttribute("data-id"))).map(r=>r.innerText).join(" "));
// sort by dBm ascending then descending; the strongest AP is first when descending
const th=ib.querySelector("th[data-sort=rssi]");th.click();const first1=document.querySelector("#inv-body tbody tr").getAttribute("data-id");
document.querySelector("#inv-body th[data-sort=rssi]").click();const first2=document.querySelector("#inv-body tbody tr").getAttribute("data-id");
o.sortFlip=first1!==first2;
// a filter chip narrows the table; the API filter agrees
const b5=[...document.querySelectorAll("#inv-body .chip[data-f=band]")].find(c=>/^5/.test(c.textContent));if(b5){b5.click();}
o.band5=document.querySelectorAll("#inv-body tbody tr").length;o.apiBand5=STARCHORUS.inventory({band:"5"}).length;
STARCHORUS.inventory({});
// a row click selects (and pins) the AP
const tr=document.querySelector("#inv-body tbody tr");const rid=tr.getAttribute("data-id");tr.click();o.rowSelect=(document.getElementById("detail-body").innerText.indexOf(rid)>=0);STARCHORUS.deselect();
const bf=[...document.querySelectorAll("#inv-body .chip[data-f=band]")].find(c=>/^5/.test(c.textContent));if(bf)bf.click();
const shown=STARCHORUS.inventory({band:"5"});document.getElementById("inv-friend").click();o.bulkShown=shown.length;o.bulkFriend=Object.values(STARCHORUS.identities()).filter(v=>v==="friend").length;o.bulkOther=STARCHORUS.identity(STARCHORUS.inventory({band:"2.4"})[0]);
STARCHORUS.inventory({});
STARCHORUS.setToggles({inventory:false});o.drawerOff=document.documentElement.dataset.drawer;
// 600 APs: the table keeps 300 rows (P8 budget), the note says so
const many=[];for(let i=0;i<600;i++)many.push({bssid:"02:00:0b:"+(i>>8).toString(16).padStart(2,"0")+":"+(i&255).toString(16).padStart(2,"0")+":01",ssid:"m"+i,band:"5",channel:36,rssi:-40-(i%50),security:"WPA2"});
STARCHORUS.load({source:"recon-db",generated:500,aps:many,unassociated:[]},"many");STARCHORUS.setToggles({inventory:true});await STARCHORUS.wait(300);
o.cap=document.querySelectorAll("#inv-body tbody tr").length;o.capNote=/first 300 rows shown/.test(document.getElementById("inv-body").innerText);
STARCHORUS.setToggles({inventory:false});
// a poll re-renders the drawer and the detail sheet: text being typed must survive (library box, alias field)
STARCHORUS.setToggles({inventory:true});await STARCHORUS.wait(200);const lt=document.getElementById("lib-ta");lt.value="02:00:00:00:00:00 friend";lt.focus();
const cur=STARCHORUS.inventory().length?1:0;const d0=await fetch("starchorus.json").then(r=>r.json());d0.generated=(d0.generated||0)+5;STARCHORUS.load(d0,"again");await STARCHORUS.wait(200);
o.keepLib=[document.getElementById("lib-ta").value,document.activeElement===document.getElementById("lib-ta")].join();
STARCHORUS.setToggles({inventory:false});const a0=STARCHORUS.nodes("ap")[0].id;STARCHORUS.select(a0);const ni=document.querySelector("#detail-body #nt-n");ni.focus();ni.value="typing";
d0.generated+=5;STARCHORUS.load(d0,"again");await STARCHORUS.wait(200);const ni2=document.querySelector("#detail-body #nt-n");o.keepNote=[ni2.value,document.activeElement===ni2].join();STARCHORUS.deselect();
o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq "$F/many-clients.json" "$OPS_Q" "out/$P-ops-inv" --wait 3 --ready "window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'" --fps 0 --eval-timeout 90 --eval "$OPS_EVI" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
OPS_I=$(evalv "out/$P-ops-inv.json" 1 | ops_nj); OPS_IE=$(evalv "out/$P-ops-inv.json" 2)
OPS_IW=$(printf '%s' '{"all":25,"apiBand5":12,"aps":25,"band5":12,"bulkFriend":12,"bulkOther":"unknown","bulkShown":12,"cap":300,"capNote":true,"chips":"14 SSIDs|25 APs|216 stations (count only)|75 randomised|17 channels|25 of 25 shown","drawer":"inv","drawerOff":"legend","errors":0,"keepLib":"02:00:00:00:00:00 friend,true","keepNote":"typing,true","legendHidden":"none","noStationMac":true,"rowSelect":true,"rows":25,"sortFlip":true}' | ops_nj)
if [ "$OPS_I" = "$OPS_IW" ] && [ "$OPS_IE" = 0 ]; then
  row "inventory: typed text survives a poll re-render, count chips, bulk friend on the shown rows only, table = the APs on screen (25), no station MAC, sort flips, band chip = API filter (12), a row selects, drawer shares the legend, 600 APs -> 300 rows + note" PASS
else
  row "inventory (err ${OPS_IE:-?})" FAIL
  echo "    got:  $(printf '%s' "$OPS_I" | cut -c1-700)"; echo "    want: $OPS_IW"
fi

OPS_EVX='(async()=>{
await STARCHORUS.wait(1500);const o={};
const macs=(s)=>s.match(/[0-9a-f]{2}(:[0-9a-f]{2}){5}/gi)||[];
const clients=STARCHORUS.nodes("client").map(n=>n.id),aps=STARCHORUS.nodes("ap").map(n=>n.id);
const J=JSON.parse(STARCHORUS.exportText("json"));o.keys=Object.keys(J).join(",");o.apKeys=Object.keys(J.aps[0]).join(",");o.nAps=J.aps.length;o.stationCounts=JSON.stringify(J.station_counts);
const C=STARCHORUS.exportText("csv"),T=STARCHORUS.exportText("sitrep");
const F="Starchorus · passive observation · not a government system · no official marking";
o.footers=[J.footer===F,C.indexOf(F)>=0,T.split(F).length-1].join();
o.csvHead=C.split("\n")[0];o.csvRows=C.trim().split("\n").length;
o.stationLeak=[STARCHORUS.exportText("json"),C,T].some(t=>clients.some(c=>t.indexOf(c)>=0));
// P6 co-location: an associated station in J.stations carries its parent AP bssid, and that bssid is a real exported AP
const assocSt=J.stations.find(x=>x.association);o.assocColo=!!assocSt&&aps.includes(assocSt.association)&&J.aps.some(a=>a.bssid===assocSt.association);
o.apsAll=J.aps.every(a=>aps.includes(a.bssid));
o.sitrepHead=T.split("\n").slice(0,2).join(" / ").slice(0,120);
o.det=[STARCHORUS.exportText("json")===STARCHORUS.exportText("json"),STARCHORUS.exportText()===STARCHORUS.exportText("json")].join();
const dialog=async()=>{const w=document.getElementById("export-wrap");let printed=0;const p=window.print;window.print=()=>{printed++};
 document.getElementById("btn-export").click();await STARCHORUS.wait(100);const r={open:getComputedStyle(w).display!=="none",ta:document.getElementById("export-ta").value.indexOf(F)>=0};
 const f=document.getElementById("export-fmt");f.value="csv";f.dispatchEvent(new Event("change"));r.csv=/^kind,bssid/.test(document.getElementById("export-ta").value);
 f.value="sitrep";f.dispatchEvent(new Event("change"));r.sitrep=/^SITREP/.test(document.getElementById("export-ta").value);
 document.getElementById("export-snap").click();const im=document.getElementById("export-png");r.png=/^data:image\/png/.test(im.src)&&!im.hidden;
 document.getElementById("export-print").click();r.printed=printed;r.printable=document.getElementById("export-printable").textContent.indexOf(F)>=0;window.print=p;
 window.dispatchEvent(new KeyboardEvent("keydown",{key:"Escape"}));r.esc=getComputedStyle(w).display==="none";document.getElementById("btn-export").click();document.getElementById("export-close").click();r.closed=getComputedStyle(w).display==="none";return r;};
o.dialog=JSON.stringify(await dialog());
// own BSSIDs and a probable phone hotspot never appear in an export
STARCHORUS.load({source:"recon-db",generated:900,center:{label:"x",own_bssids:["02:00:00:00:07:02"]},aps:[{bssid:"02:00:00:00:07:01",ssid:"shown",band:"2.4",channel:6,rssi:-50,security:"WPA2"},{bssid:"02:00:00:00:07:02",ssid:"mine",band:"2.4",channel:6,rssi:-40,security:"WPA2"},{bssid:"da:bb:cc:00:07:03",ssid:"iPhone of X",band:"2.4",channel:6,rssi:-45,security:"WPA2"}],unassociated:[{mac:"3c:22:fb:10:20:99",rssi:-70}]},"own");
const J2=JSON.parse(STARCHORUS.exportText("json"));o.own=J2.aps.map(a=>a.bssid).join(",");o.mobile=J2.mobile_hotspots;
// own transmitters and phone hotspots stay OUT of every export (P6 does not change that); a plain station appears
o.txtOwn=/mine|iPhone of X|da:bb:cc:00:07:03|02:00:00:00:07:02/.test(STARCHORUS.exportText("json")+STARCHORUS.exportText("csv")+STARCHORUS.exportText("sitrep"));
o.txtSta=/3c:22:fb:10:20:99/.test(STARCHORUS.exportText("json")+STARCHORUS.exportText("csv")+STARCHORUS.exportText("sitrep"));
o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq "$F/many-clients.json" "$OPS_Q" "out/$P-ops-exp" --wait 3 --ready "window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'" --fps 0 --eval-timeout 90 --eval "$OPS_EVX" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
OPS_X=$(evalv "out/$P-ops-exp.json" 1 | ops_nj); OPS_XE=$(evalv "out/$P-ops-exp.json" 2)
OPS_XW='{"apKeys":"bssid,ssid,band,channel,security,class,rssi,heard","apsAll":true,"assocColo":true,"csvHead":"kind,bssid,ssid,band,channel,security,rssi,heard,alias,tags,association,randomized,probes,cloud","csvRows":243,"det":"true,true","dialog":"{\"open\":true,\"ta\":true,\"csv\":true,\"sitrep\":true,\"png\":true,\"printed\":1,\"printable\":true,\"esc\":true,\"closed\":true}","errors":0,"footers":"true,true,2","keys":"footer,generated,source,aps,stations,station_counts,mobile_hotspots,crowding","mobile":1,"nAps":25,"own":"02:00:00:00:07:01","sitrepHead":"SITREP · Starchorus / Starchorus · passive observation · not a government system · no official marking","stationCounts":"{\"free\":180,\"associated\":36}","stationLeak":true,"txtOwn":false,"txtSta":true}'
if [ "$OPS_X" = "$OPS_XW" ] && [ "$OPS_XE" = 0 ]; then
  row "export: json/csv/sitrep with stations as first-class rows (P6), a station MAC AND its association present (co-located), own BSSIDs and phone hotspots still left out, footer + dialog intact" PASS
else
  row "export (err ${OPS_XE:-?})" FAIL
  echo "    got:  $(printf '%s' "$OPS_X" | cut -c1-700)"; echo "    want: $OPS_XW"
fi

OPS_EVH='(async()=>{
await STARCHORUS.wait(600);const o={};
const ap=(n,rssi)=>({bssid:"02:00:00:00:08:"+String(n).padStart(2,"0"),ssid:"h"+n,band:"2.4",channel:6,freq:2437,rssi:rssi==null?-60:rssi,security:"WPA2"});
const doc=(g,h,extra)=>Object.assign({source:"recon-db",generated:g,aps:[ap(1,-60),ap(2,-70)],unassociated:[{mac:"3c:22:fb:10:20:31",rssi:-70}]},h===undefined?{}:{homing:h},extra||{});
const H=()=>{const h=STARCHORUS.homing();return h?[h.bssid.slice(-5),h.dbm,h.peak].join("/"):"none"};
STARCHORUS.load(doc(100),"home");o.none=H();
STARCHORUS.load(doc(105,{bssid:"02:00:00:00:08:01",dbm:-60,peak:-60,t:105}),"home");o.first=H();
STARCHORUS.load(doc(110,{bssid:"02:00:00:00:08:01",dbm:-48,peak:-48,t:110}),"home");o.up=H();
STARCHORUS.load(doc(115,{bssid:"02:00:00:00:08:01",dbm:-70,peak:-48,t:115}),"home");o.down=H();
const seq=[];for(let i=0;i<13;i++){STARCHORUS.load(doc(120+5*i,{bssid:"02:00:00:00:08:01",dbm:-70,peak:-70,t:120+5*i}),"home");seq.push(STARCHORUS.homing().peak);}o.decay=seq[0]+"..."+seq[seq.length-1];
STARCHORUS.load(doc(300,{bssid:"02:00:00:00:08:01",dbm:-55,peak:-55,t:300}),"home");STARCHORUS.load(doc(300,{bssid:"02:00:00:00:08:01",dbm:-20,peak:-20,t:300}),"home");o.sameGen=H();
STARCHORUS.load(doc(310,{bssid:"3c:22:fb:10:20:31",dbm:-40,peak:-40,t:310}),"home");o.client=H();
STARCHORUS.load(doc(315,{bssid:"de:ad:be:ef:00:01",dbm:-40,peak:-40,t:315}),"home");o.unknown=H();
STARCHORUS.load(doc(320,{bssid:"02:00:00:00:08:02",dbm:-40,peak:-40,t:320},{center:{label:"x",own_bssids:["02:00:00:00:08:02"]}}),"home");o.own=H();
STARCHORUS.load(doc(325,{bssid:"02:00:00:00:08:02",dbm:"x"}),"home");o.junk=H();
STARCHORUS.load(doc(330,{bssid:"02:00:00:00:08:02",dbm:-52,peak:-50,t:330}),"home");o.retarget=H();
// the drawer
o.open=STARCHORUS.openHoming(true);await STARCHORUS.wait(200);const hb=document.getElementById("home-body");
o.drawer=[document.documentElement.dataset.drawer,hb.hidden].join();o.meter=(hb.innerText.match(/-?\d+ dBm[^\n]*/)||[""])[0].slice(0,40);o.bar=!!hb.querySelector("[role=meter]");
o.coarse=/coarse: one reading per poll/.test(hb.innerText);o.tone=hb.querySelector("#home-tone").getAttribute("aria-pressed");
STARCHORUS.load(doc(340,null),"home");await STARCHORUS.wait(100);o.emptyNote=/No homing access point is set/.test(hb.innerText);
o.close=STARCHORUS.openHoming(false);o.drawerOff=document.documentElement.dataset.drawer;
// key F toggles it too
window.dispatchEvent(new KeyboardEvent("keydown",{key:"f"}));o.keyOn=document.documentElement.dataset.drawer;window.dispatchEvent(new KeyboardEvent("keydown",{key:"f"}));o.keyOff=document.documentElement.dataset.drawer;
o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$OPS_Q" "out/$P-ops-home" --wait 2 --ready --fps 0 --eval-timeout 90 --eval "$OPS_EVH" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
OPS_H=$(evalv "out/$P-ops-home.json" 1 | ops_nj); OPS_HE=$(evalv "out/$P-ops-home.json" 2)
OPS_HW='{"bar":true,"client":"20:31/-40/-40","close":false,"coarse":true,"decay":"-48...-70","down":"08:01/-70/-48","drawer":"home,false","drawerOff":"legend","emptyNote":true,"errors":0,"first":"08:01/-60/-60","junk":"none","keyOff":"legend","keyOn":"home","meter":"-52 dBm (63 %, good)","none":"none","open":true,"own":"none","retarget":"08:02/-52/-50","sameGen":"08:01/-20/-55","tone":"false","unknown":"none","up":"08:01/-48/-48"}'
if [ "$OPS_H" = "$OPS_HW" ] && [ "$OPS_HE" = 0 ]; then
  row "homing: an AP OR a present station (unknown/own/junk still refused), peak hold, decay after 12 polls, same capture is no new poll, meter + coarse note, tone off, key F" PASS
else
  row "homing (err ${OPS_HE:-?})" FAIL
  echo "    got:  $(printf '%s' "$OPS_H" | cut -c1-700)"; echo "    want: $OPS_HW"
fi

# ---- keys I/F, query, buttons, help entries
OPS_EVK='(async()=>{
const key=(k)=>window.dispatchEvent(new KeyboardEvent("keydown",{key:k})),o={};
o.start=[STARCHORUS.getToggles().inventory,document.documentElement.dataset.drawer].join();
key("i");o.on=[STARCHORUS.getToggles().inventory,document.documentElement.dataset.drawer].join();
await STARCHORUS.wait(400);const st=STARCHORUS.storageDump()||{};o.persisted=st.inventory;
key("i");o.off=[STARCHORUS.getToggles().inventory,document.documentElement.dataset.drawer].join();
o.buttons=["t-inv","btn-export"].map(i=>!!document.getElementById(i)).join();
const h=document.getElementById("help-list").innerText;o.help=[/Inventory/.test(h),/Homing meter/.test(h)].join();
document.getElementById("t-inv").click();o.btn=document.documentElement.dataset.drawer;document.getElementById("t-inv").click();
// the typing fields keep letters away from the hotkeys
STARCHORUS.setToggles({inventory:true});await STARCHORUS.wait(200);const ta=document.getElementById("lib-ta");ta.focus();ta.dispatchEvent(new KeyboardEvent("keydown",{key:"i",bubbles:true}));o.typing=STARCHORUS.getToggles().inventory;
return JSON.stringify(o);})()'
runq demo "$OPS_Q" "out/$P-ops-keys" --wait 2 --ready --fps 0 --eval "$OPS_EVK" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
OPS_K=$(evalv "out/$P-ops-keys.json" 1 | ops_nj); OPS_KE=$(evalv "out/$P-ops-keys.json" 2)
OPS_KW=$(printf '%s' '{"start":"false,legend","on":"true,inv","persisted":true,"off":"false,legend","buttons":"true,true","help":"true,true","btn":"inv","typing":true}' | ops_nj)
if [ "$OPS_K" = "$OPS_KW" ] && [ "$OPS_KE" = 0 ]; then row "operator keys I/F, buttons, help entries; typing in the library box does not fire hotkeys [$OPS_K]" PASS
else row "operator keys I/F, buttons, help entries; typing in the library box does not fire hotkeys [$OPS_K]" FAIL; fi
runq demo "$OPS_Q&inv=1" "out/$P-ops-query" --wait 2 --ready --fps 0 --eval "JSON.stringify([STARCHORUS.getToggles().inventory,document.documentElement.dataset.drawer])" >/dev/null 2>&1
OPS_QV=$(evalv "out/$P-ops-query.json" 1)
rowif "inventory: ?inv=1 overrides the start state [$OPS_QV]" [ "$OPS_QV" = '[true,"inv"]' ]

# ---- D15: inventory drawer (widest content) and homing drawer keep the edge panels apart, three viewports of the core rows are unchanged
eval "$(grep '^EDG_OVL=' tools/regress.d/edge-layout.sh)"
for OPS_VP in 1440x900 1000x640; do
  runq "$F/field-probes.json" "?poll=0&spin=0&intro=0&inv=1" "out/$P-ops-d15i-$OPS_VP" --width "${OPS_VP%x*}" --height "${OPS_VP#*x}" --wait 4 --ready "window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'" --fps 0 --eval "$EDG_OVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
  OPS_OV=$(evalv "out/$P-ops-d15i-$OPS_VP.json" 1); OPS_OVE=$(evalv "out/$P-ops-d15i-$OPS_VP.json" 2)
  if [ "$OPS_OV" = 0 ] && [ "$OPS_OVE" = 0 ]; then row "operator drawers: D15 overlap 0 with the inventory drawer open $OPS_VP (err ${OPS_OVE:-?}) [$(printf '%s' "$OPS_OV" | cut -c1-60)]" PASS
  else row "operator drawers: D15 overlap 0 with the inventory drawer open $OPS_VP (err ${OPS_OVE:-?}) [$(printf '%s' "$OPS_OV" | cut -c1-60)]" FAIL; fi
  runq "$F/field-probes.json" "?poll=0&spin=0&intro=0" "out/$P-ops-d15h-$OPS_VP" --width "${OPS_VP%x*}" --height "${OPS_VP#*x}" --wait 4 --ready "window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'" --fps 0 --eval "(async()=>{STARCHORUS.openHoming(true);await STARCHORUS.wait(300);return 1})()" --eval "$EDG_OVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
  OPS_OV=$(evalv "out/$P-ops-d15h-$OPS_VP.json" 2); OPS_OVE=$(evalv "out/$P-ops-d15h-$OPS_VP.json" 3)
  if [ "$OPS_OV" = 0 ] && [ "$OPS_OVE" = 0 ]; then row "operator drawers: D15 overlap 0 with the homing drawer open $OPS_VP (err ${OPS_OVE:-?}) [$(printf '%s' "$OPS_OV" | cut -c1-60)]" PASS
  else row "operator drawers: D15 overlap 0 with the homing drawer open $OPS_VP (err ${OPS_OVE:-?}) [$(printf '%s' "$OPS_OV" | cut -c1-60)]" FAIL; fi
done

# ---- static: keys, passivity of the new code, versions, docs
OPS_KEYS=$(grep -oE '"starchorus\.[a-z]+\.v[0-9]+"' starchorus.html | sort -u | tr '\n' ' ')
rowif "P8 the page's local-storage keys are exactly ui/identity/baseline/watch/library/notes [$OPS_KEYS]" [ "$OPS_KEYS" = '"starchorus.baseline.v1" "starchorus.identity.v1" "starchorus.library.v1" "starchorus.notes.v1" "starchorus.ui.v1" "starchorus.watch.v1" ' ]
OPS_SEC=$(grep -c 'starchorus.library.v1\|starchorus.notes.v1' SECURITY.md)
rowif "P8 SECURITY.md lists the library and notes keys with their limits ($OPS_SEC)" [ "$OPS_SEC" -ge 2 ]
OPS_NET=$(grep -cE 'method:|POST|XMLHttpRequest|WebSocket|EventSource|sendBeacon' starchorus.html); OPS_FE=$(grep -c 'fetch(' starchorus.html)
if [ "$OPS_NET" = 0 ] && [ "$OPS_FE" = 1 ]; then row "operator tools passivity: no send path in the page (method:/POST/XHR/WebSocket/EventSource/sendBeacon = $OPS_NET, fetch( = $OPS_FE)" PASS
else row "operator tools passivity: no send path in the page (method:/POST/XHR/WebSocket/EventSource/sendBeacon = $OPS_NET, fetch( = $OPS_FE)" FAIL; fi
OPS_EXPD=$(awk '/^function exportModel\(/,/^function openExport\(/' starchorus.html | grep -cE 'Math\.random|Date\.now|new Date\(\)')
OPS_EXPS=$(awk '/^function exportModel\(/,/^function openExport\(/' starchorus.html | grep -cE 'S\.clientOrder|\.mac\b')
if [ "$OPS_EXPS" -ge 1 ] && [ "$OPS_EXPD" = 0 ]; then row "export reads the station register (S.clientOrder/.mac: $OPS_EXPS) but keeps no clock/random ($OPS_EXPD)" PASS; else row "export reads the station register ($OPS_EXPS) / clock-free ($OPS_EXPD)" FAIL; fi
OPS_DL=$(grep -cE 'createElement\("a"\)|\.click\(\)|download=|location(\.href)? *=' starchorus.html)
rowif "export stays on the page: no anchor download, no navigation ($OPS_DL)" [ "$OPS_DL" = 0 ]
# Homing accepts an AP or a present station (behaviour in the homing run above). The gate requires presence THIS capture
# (seenAp OR seenCl) and refuses our own transmitters (own.bssids). This structural row pins those three references
# so a rewrite that drops the presence or own-refusal check turns it red.
OPS_HOMG=$(awk '/^function homingIngest\(/,/^}/' starchorus.html)
OPS_HOME=$(printf '%s\n' "$OPS_HOMG" | grep -c 'seenAp.has'); OPS_HOMC=$(printf '%s\n' "$OPS_HOMG" | grep -c 'seenCl.has'); OPS_HOMO=$(printf '%s\n' "$OPS_HOMG" | grep -c 'own.bssids.has')
if [ "$OPS_HOME" -ge 1 ] && [ "$OPS_HOMC" -ge 1 ] && [ "$OPS_HOMO" -ge 1 ]; then row "homing gate: present AP or station (seenAp/seenCl $OPS_HOME/$OPS_HOMC), own transmitters still refused ($OPS_HOMO)" PASS
else row "homing gate: present AP or station (seenAp/seenCl $OPS_HOME/$OPS_HOMC), own transmitters still refused ($OPS_HOMO)" FAIL; fi
OPS_V=$(sed -n 's/^# Version:      \([0-9][0-9A-Za-z.-]*\)$/\1/p' starchorus-collect.sh | head -n 1)
rowif "collector version 0.2.6 [$OPS_V] (the project-wide version row is in station-outputs.sh)" [ "$OPS_V" = 0.2.6 ]
# --help prints the header's USAGE/CONFIG block whole: first line "USAGE:", last line the end of the STARCHORUS_OUI_FILE entry.
OPS_HLP=$(sh starchorus-collect.sh --help 2>/dev/null)
OPS_HL1=$(printf '%s\n' "$OPS_HLP" | head -n 1); OPS_HLN=$(printf '%s\n' "$OPS_HLP" | wc -l | tr -d ' ')
OPS_HLZ=$(printf '%s\n' "$OPS_HLP" | tail -n 1 | grep -c 'one log line\.  (default auto)$')
rowif "collector --help: USAGE/CONFIG block whole (first [$OPS_HL1], $OPS_HLN lines, ends with the OUI entry: $OPS_HLZ)" [ "$OPS_HL1|$OPS_HLZ" = "USAGE:|1" ]
OPS_HB=$(grep -c "^HOMING_BSSID=\${STARCHORUS_HOMING_BSSID:-}" starchorus-collect.sh)
rowif "homing is opt-in: no target unless STARCHORUS_HOMING_BSSID / homing.target is set ($OPS_HB)" [ "$OPS_HB" = 1 ]

# ---- the constellation label carries its weakest member (open/WEP "!", TKIP "~"); WPA2/WPA3 add nothing
OPS_EVG='(async()=>{
const ap=(n,b,ch,sec)=>({bssid:"02:00:00:00:09:"+String(n).padStart(2,"0"),ssid:"grpnet",band:b,channel:ch,rssi:-55-n,security:sec});
const mk=(g,secs)=>({source:"recon-db",generated:g,aps:[ap(1,"2.4",6,secs[0]),ap(2,"5",36,secs[1]),ap(3,"5",100,secs[2])],unassociated:[]});
const o={},lab=()=>STARCHORUS.labels().filter(l=>l.kind==="group").map(l=>l.text).join("|")||"none";
STARCHORUS.load(mk(100,["WPA2","WPA2","WPA2"]),"g");await STARCHORUS.wait(1200);o.g0=STARCHORUS.groups().map(g=>g.key+":"+g.members.length).join();
STARCHORUS.setToggles({groups:true,labels:true});await STARCHORUS.wait(300);STARCHORUS.frame();o.plain=lab();
STARCHORUS.load(mk(105,["WPA2","Open","WPA3"]),"g");await STARCHORUS.wait(1200);STARCHORUS.frame();o.open=lab();
STARCHORUS.load(mk(110,["WPA3","WPA3","WPA3"]),"g");await STARCHORUS.wait(1200);STARCHORUS.frame();o.allWpa3=lab();
STARCHORUS.load(mk(115,["WPA2","WPA2/TKIP","WPA2"]),"g");await STARCHORUS.wait(1200);STARCHORUS.frame();o.tkip=lab();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "$OPS_Q" "out/$P-ops-grp" --wait 2 --ready --fps 0 --eval-timeout 90 --eval "$OPS_EVG" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
OPS_G=$(evalv "out/$P-ops-grp.json" 1 | ops_nj); OPS_GE=$(evalv "out/$P-ops-grp.json" 2)
OPS_GW=$(printf '%s' '{"g0":"grpnet:3","plain":"grpnet","open":"grpnet !","allWpa3":"grpnet","tkip":"grpnet ~","errors":0}' | ops_nj)
if [ "$OPS_G" = "$OPS_GW" ] && [ "$OPS_GE" = 0 ]; then row "constellation label carries its weakest member (open -> !, TKIP -> ~, WPA2/WPA3 nothing) [$OPS_G]" PASS
else row "constellation label carries its weakest member (open -> !, TKIP -> ~, WPA2/WPA3 nothing) [$OPS_G]" FAIL; fi

# ---- 0.2.5, 24 October 2026: the CSV export does not hand a spreadsheet a formula (E1), and the export dialogue takes the focus (E4)
# A text cell that starts with = + - @ TAB or CR gets a leading apostrophe; a cell that is a number (-50) stays one; the comma and quote cases are as they were, and CR is quoted
# like LF. The capture is planted (placeholder names and addresses): four network names a spreadsheet would read as a formula, one that is a plain number, one with a comma, one with
# quotes, an alias and a probed name. Each answer is a 1 or a 0; the page is right when all thirteen are 1. Infinity is no number to a spreadsheet, so "-Infinity" gets its apostrophe too. A leading CR or TAB cannot reach a cell on the real page (stripCtl takes every
# control character out of a name, a probe and an alias), so those two branches of the cell fix run on a copy of the page whose stripCtl lets TAB and CR through (a second run, below):
# the TAB name gets its apostrophe, the CR name gets it and is quoted like LF. E4 rides on the same run: after a click on Export, document.activeElement
# is inside #export-box (the format list), where a keyboard or screen-reader user starts.
OPS_EVC='(async()=>{
const b=(n)=>"02:00:00:00:0c:"+String(n).padStart(2,"0"),ap=(n,ssid)=>({bssid:b(n),ssid:ssid,band:"2.4",channel:6,rssi:-50-n,security:"WPA2"});
STARCHORUS.load({source:"recon-db",generated:900,aps:[ap(1,"=1+1"),ap(2,"@SUM(A1)"),ap(3,"-2+3"),ap(4,"+cmd"),ap(5,"-50"),ap(6,"Cafe, Bar"),ap(7,"say \"hi\""),ap(8,"plain"),ap(9,"-Infinity")],
 unassociated:[{mac:"3c:22:fb:10:20:41",rssi:-70,probes:["=HYPERLINK(\"http://x\",\"y\")"]}]},"csv");
await STARCHORUS.wait(800);STARCHORUS.notes(b(8),{alias:"=ALIAS()"});
const A=String.fromCharCode(39),C=STARCHORUS.exportText("csv").split("\n"),row=(s)=>C.find(l=>l.indexOf(s)===0)||"",cell=(s,i)=>row("ap,"+b(s)+",").split(",")[i];
const r=[cell(1,2)===A+"=1+1",cell(2,2)===A+"@SUM(A1)",cell(3,2)===A+"-2+3",cell(4,2)===A+"+cmd",cell(5,2)==="-50",
 row("ap,"+b(6)+",").indexOf(",\"Cafe, Bar\",")>0,row("ap,"+b(7)+",").indexOf(",\"say \"\"hi\"\"\",")>0,
 /^-5\d$/.test(cell(1,6))&&/^-5\d$/.test(cell(8,6)),row("ap,"+b(8)+",").indexOf(","+A+"=ALIAS(),")>0,
 row("station,3c:22:fb:10:20:41").indexOf(",\""+A+"=HYPERLINK(\"\"http://x\"\",\"\"y\"\")\",")>0,
 C.filter(l=>l.indexOf("ap,")===0).length===9,C[0].split(",").length===14,cell(9,2)===A+"-Infinity"].map(x=>x?1:0).join("");
document.getElementById("btn-export").click();await STARCHORUS.wait(100);
const foc=document.getElementById("export-box").contains(document.activeElement)?1:0;document.getElementById("export-close").click();
return r+"|"+foc;})()'
runq demo "$OPS_Q" "out/$P-ops-csv" --wait 2 --ready --fps 0 --eval-timeout 90 --eval "$OPS_EVC" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
OPS_C=$(evalv "out/$P-ops-csv.json" 1); OPS_CE=$(evalv "out/$P-ops-csv.json" 2)
rowif "export CSV: names that start with = + - @ get a leading apostrophe (a probe and an alias too), a number stays a number, comma and quote cases as before [$OPS_C]" [ "$OPS_C/$OPS_CE" = "1111111111111|1/0" ]
# negative controls: a copy of the page without the fix of the cell (the old q) must read red on the first four, "-Infinity", the alias and the probe, and a copy without the focus call red on the focus
python3 - "$H" "out/$P-ops-csv-nofix.html" "out/$P-ops-csv-nofocus.html" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
new_q = 'const q = (v) => { const s = v == null ? "" : String(v), t = /^[=+@\\t\\r-]/.test(s) && !isFinite(s) ? "\'" + s : s; return /[",\\r\\n]/.test(t) ? \'"\' + t.replace(/"/g, \'""\') + \'"\' : t; };'
old_q = 'const q = (v) => { const t = v == null ? "" : String(v); return /[",\\n]/.test(t) ? \'"\' + t.replace(/"/g, \'""\') + \'"\' : t; };'
foc = 'refreshExport(); el("export-fmt").focus(); }'
a = s.replace(new_q, old_q) if s.count(new_q) == 1 else s + "\n<!-- the cell fix was not found exactly once -->\n"
b = s.replace(foc, 'refreshExport(); }') if s.count(foc) == 1 else s + "\n<!-- the focus call was not found exactly once -->\n"
open(sys.argv[2], "w", encoding="utf-8").write(a)
open(sys.argv[3], "w", encoding="utf-8").write(b)
PY
# the two branches the real page cannot reach: a copy of the page whose stripCtl lets TAB and CR through (a leading TAB or CR in a name), with and without the fix of the cell
OPS_EVT='(async()=>{
const b=(n)=>"02:00:00:00:0c:"+String(n).padStart(2,"0"),ap=(n,ssid)=>({bssid:b(n),ssid:ssid,band:"2.4",channel:6,rssi:-50-n,security:"WPA2"});
const A=String.fromCharCode(39),T=String.fromCharCode(9),R=String.fromCharCode(13);
STARCHORUS.load({source:"recon-db",generated:900,aps:[ap(1,T+"=1+1"),ap(2,R+"=2"),ap(3,"plain")],unassociated:[]},"csv");
await STARCHORUS.wait(800);
const C=STARCHORUS.exportText("csv").split("\n"),row=(s)=>C.find(l=>l.indexOf(s)===0)||"",cell=(s,i)=>row("ap,"+b(s)+",").split(",")[i];
return [cell(1,2)===A+T+"=1+1",cell(2,2)==="\""+A+R+"=2\"",cell(3,2)==="plain"].map(x=>x?1:0).join("");})()'
python3 - "$H" "out/$P-ops-csv-loose.html" "out/$P-ops-csv-loose-nofix.html" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
strip = 'String(x).replace(/[\\x00-\\x1f\\x7f-\\x9f\\u200b-\\u200f\\u202a-\\u202e\\u2060-\\u2069\\ufeff]/g, "")'
loose = 'String(x).replace(/[\\x00-\\x08\\x0a-\\x0c\\x0e-\\x1f\\x7f-\\x9f\\u200b-\\u200f\\u202a-\\u202e\\u2060-\\u2069\\ufeff]/g, "")'
new_q = 'const q = (v) => { const s = v == null ? "" : String(v), t = /^[=+@\\t\\r-]/.test(s) && !isFinite(s) ? "\'" + s : s; return /[",\\r\\n]/.test(t) ? \'"\' + t.replace(/"/g, \'""\') + \'"\' : t; };'
old_q = 'const q = (v) => { const t = v == null ? "" : String(v); return /[",\\n]/.test(t) ? \'"\' + t.replace(/"/g, \'""\') + \'"\' : t; };'
if s.count(strip) != 1 or s.count(new_q) != 1:
    s += "\n<!-- stripCtl or the cell fix was not found exactly once -->\n"
    a = b = s
else:
    a = s.replace(strip, loose)
    b = a.replace(new_q, old_q)
open(sys.argv[2], "w", encoding="utf-8").write(a)
open(sys.argv[3], "w", encoding="utf-8").write(b)
PY
OPS_HK=$H; H="out/$P-ops-csv-loose.html"
runq demo "$OPS_Q" "out/$P-ops-csv-l1" --wait 2 --ready --fps 0 --eval-timeout 90 --eval "$OPS_EVT" >/dev/null 2>&1
H="out/$P-ops-csv-loose-nofix.html"
runq demo "$OPS_Q" "out/$P-ops-csv-l2" --wait 2 --ready --fps 0 --eval-timeout 90 --eval "$OPS_EVT" >/dev/null 2>&1
H=$OPS_HK
OPS_L1=$(evalv "out/$P-ops-csv-l1.json" 1); OPS_L2=$(evalv "out/$P-ops-csv-l2.json" 1)
rowif "export CSV: a leading TAB gets its apostrophe and a leading CR gets it and is quoted (on a copy whose stripCtl lets both through) [$OPS_L1], and the copy with the old cell code reads both raw [$OPS_L2]" [ "$OPS_L1/$OPS_L2" = "111/001" ]
OPS_HK=$H; H="out/$P-ops-csv-nofix.html"   # runq serves $H: point it at a copy for one call, then put it back
runq demo "$OPS_Q" "out/$P-ops-csv-n1" --wait 2 --ready --fps 0 --eval-timeout 90 --eval "$OPS_EVC" >/dev/null 2>&1
H="out/$P-ops-csv-nofocus.html"
runq demo "$OPS_Q" "out/$P-ops-csv-n2" --wait 2 --ready --fps 0 --eval-timeout 90 --eval "$OPS_EVC" >/dev/null 2>&1
H=$OPS_HK
OPS_CN1=$(evalv "out/$P-ops-csv-n1.json" 1); OPS_CN2=$(evalv "out/$P-ops-csv-n2.json" 1)
rowif "export CSV: the controls bite: without the cell fix the formula names, the alias and the probe read raw [$OPS_CN1], without the focus call the focus stays outside the dialogue [$OPS_CN2]" [ "$OPS_CN1/$OPS_CN2" = "0000111100110|1/1111111111111|0" ]

# ---- 0.2.5, 26 October 2026: five small defects of the controls (the audit of every control, 26 October). One run reads B1 (the library's Import says what it
# did: #lib-msg is the node that is in the document after the click, and its text is the message), B3 (#t-rotate is hidden in 2D and shown in 3D, and back),
# B4 (Clear local data switches the baseline toggle and its button off, and leaves no starchorus.* key behind) and B5 (the help lists Enter and =); B2 (the
# help's Close button inside the viewport) is read at two sizes. Each has a sensor: a copy of the page with the old code reads the figure the defect gave.
OPS_EVU='(async()=>{const o={},E=(i)=>document.getElementById(i),shown=(e)=>!e.hidden&&getComputedStyle(e).display!=="none",R=E("t-rotate");
o.b3=[shown(R)];STARCHORUS.setView("3d");await STARCHORUS.wait(400);o.b3.push(shown(R));STARCHORUS.setView("2d");await STARCHORUS.wait(400);o.b3.push(shown(R));o.b3=o.b3.join();
const id=STARCHORUS.nodes("ap")[0].id;STARCHORUS.setToggles({inventory:true});await STARCHORUS.wait(200);
E("lib-ta").value=id+" friend\nde:ad:be:ef:00:99 neutral";E("lib-import").click();const m=E("lib-msg");o.b1=[document.contains(m),m.textContent].join("|");STARCHORUS.setToggles({inventory:false});
const dts=Array.from(document.querySelectorAll("#help-list dt")).map(d=>d.textContent);o.b5=[dts.indexOf("Enter")>=0,dts.indexOf("=")>=0,dts.indexOf("+ / −")<dts.indexOf("="),dts.indexOf("Enter")<dts.indexOf("Esc")].join();
STARCHORUS.setBaseline();STARCHORUS.setToggles({baselineDiff:true});const bt=E("t-baseline"),on=[STARCHORUS.getToggles().baselineDiff,bt.getAttribute("aria-pressed")].join();
STARCHORUS.clearLocalData();o.b4=[on,STARCHORUS.getToggles().baselineDiff,bt.getAttribute("aria-pressed"),bt.classList.contains("on"),Object.keys(localStorage).filter(k=>k.indexOf("starchorus.")===0).length].join("|");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
OPS_EVH='(async()=>{const o=[],E=(i)=>document.getElementById(i),inside=(e)=>{const b=e.getBoundingClientRect();return b.width>0&&b.top>=0&&b.left>=0&&b.bottom<=innerHeight&&b.right<=innerWidth};
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);STARCHORUS.setToggles({help:true});await STARCHORUS.wait(300);
const dl=E("help-list"),dt=dl.querySelectorAll("dt"),first=dt[0],last=dt[dt.length-1],box=(e)=>e.getBoundingClientRect();
dl.scrollTop=0;const top=box(first).top>=box(dl).top-1;dl.scrollTop=dl.scrollHeight;const end=box(last).bottom<=box(dl).bottom+1;
const c=E("help-close"),near=getComputedStyle(c).display==="none"?inside(E("sheet-close")):inside(c);
o.push([t,near,top&&end].join(":"));STARCHORUS.setToggles({help:false});}
return o.join(",")})()'
runq demo "$OPS_Q" "out/$P-ops-ctl" --wait 2 --ready --fps 0 --eval-timeout 90 --eval "$OPS_EVU" >/dev/null 2>&1
runq demo "$OPS_Q" "out/$P-ops-help-d" --wait 2 --ready --fps 0 --width 1440 --height 900 --eval-timeout 90 --eval "$OPS_EVH" >/dev/null 2>&1
runq demo "$OPS_Q" "out/$P-ops-help-m" --wait 2 --ready --fps 0 --mobile --width 390 --height 844 --eval-timeout 90 --eval "$OPS_EVH" --eval "$OPS_EVU" >/dev/null 2>&1
python3 - "$H" "out/$P-ops-ctl-old.html" <<'PY'
import sys
s = open(sys.argv[1], encoding="utf-8").read()
back = [('el("lib-msg").textContent = r.added', 'msg.textContent = r.added'),
  ('  el("t-rotate").hidden = flat;   // the auto-rotation is 3D only\n', ''),
  ('  setToggle("baselineDiff", false);   // first: it saves the ui key, which the loop then removes\n', ''),
  ('  { key: "=", desc: "Zoom in, like +" },\n', ''),
  ('  { key: "Enter", desc: "Show a selected random cloud\'s addresses" },\n', ''),
  ('max-height: calc(100vh - 112px); display: flex; flex-direction: column; z-index: 40;', 'max-height: calc(100vh - 112px); overflow-y: auto; z-index: 40;'),
  ('margin: 0; min-height: 0; overflow-y: auto; font-size', 'margin: 0; font-size')]
for a, b in back:
    if s.count(a) != 1:
        s += "\n<!-- a fix was not found exactly once -->\n"; break
    s = s.replace(a, b)
open(sys.argv[2], "w", encoding="utf-8").write(s)
PY
OPS_HK=$H; H="out/$P-ops-ctl-old.html"
runq demo "$OPS_Q" "out/$P-ops-ctl-o1" --wait 2 --ready --fps 0 --eval-timeout 90 --eval "$OPS_EVU" >/dev/null 2>&1
runq demo "$OPS_Q" "out/$P-ops-help-o" --wait 2 --ready --fps 0 --width 1440 --height 900 --eval-timeout 90 --eval "$OPS_EVH" >/dev/null 2>&1
H=$OPS_HK
OPS_U=$(evalv "out/$P-ops-ctl.json" 1 | ops_nj); OPS_UO=$(evalv "out/$P-ops-ctl-o1.json" 1 | ops_nj)
OPS_HD=$(evalv "out/$P-ops-help-d.json" 1); OPS_HM=$(evalv "out/$P-ops-help-m.json" 1); OPS_HO=$(evalv "out/$P-ops-help-o.json" 1); OPS_UM=$(evalv "out/$P-ops-help-m.json" 2 | ops_nj)
OPS_UOS=$(printf '%s' "$OPS_UO" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["b1"].split("|",1)[1].startswith("1 set"),d["b3"],d["b4"],d["b5"])' 2>/dev/null)
OPS_UW='{"b1":"true|1 set, 0 rule(s) · 1 rejected: not observed","b3":"false,true,false","b4":"true,true|false|false|false|0","b5":"true,true,true,true","errors":0}'
OPS_UWN=$(printf '%s' "$OPS_UW" | ops_nj)
rowif "controls (26 October 2026): after a DOM-driven Import #lib-msg is in the document and says '1 set, 0 rule(s) · 1 rejected: not observed'; #t-rotate is hidden in 2D, shown in 3D and hidden again in 2D; Clear local data turns baselineDiff and the button off and leaves no starchorus.* key; the help lists = after + / − and Enter before Esc [$OPS_U]" [ "$OPS_U" = "$OPS_UWN" ]
rowif "controls: the same on a phone (390 x 844, touch): Import, Rotate in the sheet's controls, Clear local data and the help list [$OPS_UM]" [ "$OPS_UM" = "$OPS_UWN" ]
rowif "controls: the sensor bites: a copy of the page with the old code (the message written to the rebuilt panel's old node, no hiding of Rotate, no reset of the baseline toggle, no Enter and = in the help) reads Import-message-fixed/Rotate/baseline/help = [$OPS_UOS]" [ "$OPS_UOS" = "False true,true,true true,true|true|true|true|0 false,false,false,true" ]
rowif "help (26 October 2026): #help-close is inside the viewport at 1440 x 900 in all three themes, and on a phone at 390 x 844 (where the sheet's own close stands in for it), and the whole list can be scrolled to, first entry to last [desktop $OPS_HD; phone $OPS_HM]" [ "$OPS_HD/$OPS_HM" = "foundation:true:true,wargames:true:true,whitehall:true:true/foundation:true:true,wargames:true:true,whitehall:true:true" ]
rowif "help: the sensor bites: a copy with the old style (the whole panel scrolls, the button below the list) has #help-close outside the viewport at 1440 x 900 [$OPS_HO]" [ "$OPS_HO" = "foundation:true:true,wargames:false:true,whitehall:false:true" ]
