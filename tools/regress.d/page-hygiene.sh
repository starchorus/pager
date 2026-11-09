# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/page-hygiene.sh -- the page's hit test, its sheet ages and a handful of small rules (0.2.8).
# GUARDS AGAINST: a 2D hit test that answers at the spot of a star whose band is filtered off (the hit, the hover and the label of a
#                 pinned one); a tooltip that keeps old data after a capture or stays when its node has gone; a held toggle key or a
#                 held ? that fires again, and a held key that is no shortcut losing its default; a 'Name revealed' row counted on the
#                 animation clock instead of capture time; a BSSID that appears twice whose name and hidden mark come from different
#                 records; a name cut at 32 units ending in half a surrogate pair; the library import taking constructor or toString
#                 for a class; a SITREP station line with a bare ' GHz'; a capture time before 1970 taken for a date; one exception in
#                 a frame ending the animation.
# NEGATIVE PROBE: each row read red against the page of 0.2.7 (the hit test without the alphaDraw rule: after/hover not null and the
#                 label kept; the tooltip unchanged; the key fired twice; the sheet row on S.clock; hid from the first record; a lone
#                 surrogate kept; constructor accepted; the middle dot and a bare ' GHz'; a six-digit year in the SITREP for -7e10;
#                 no frame rendered after the throw). The Tab key guards against a blanket repeat rule and is not red on 0.2.7.
# NOT PROVEN:     a very small sky (the inner radius against the ring: no screen reading tells an angle of null from a placed one);
#                 a real pointer click into the dark (the shared root, nodeAt, is what the rows read); the rule for stations, bubbles,
#                 clouds and Bluetooth marks (read for the star only); a held Esc (one layer per press).
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only PGH_* globals and the helper pgh_nj are set.

PGH_Q="?poll=0&spin=0&intro=0&debug=1"
PGH_RDY='document.fonts.ready.then(() => new Promise(r => requestAnimationFrame(() => r(!!window.STARCHORUS && STARCHORUS.nodes("ap").length > 0 && STARCHORUS.stats().sourceKind !== "demo"))))'
pgh_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }

# ---- a. the hit test, the label of a pinned star, the tooltip, a held key
PGH_EVA='(async()=>{const o={};const W=(ms)=>STARCHORUS.wait(ms);const G=1700000000;const B=(i)=>"02:00:00:00:66:0"+i;
const ap=(i,b,ch)=>({bssid:B(i),ssid:"Probe "+i,band:b,channel:ch,rssi:-50-5*i,security:"WPA2"});
STARCHORUS.setView("2d");STARCHORUS.setToggles({bands:{"2.4":true,"5":true,"6":true}});
STARCHORUS.load({source:"recon-db",generated:G,aps:[ap(1,"2.4",6),ap(2,"5",36),ap(3,"5",40)],unassociated:[{mac:"02:00:00:00:77:01",rssi:-61}]},"pgh");
await W(1500);STARCHORUS.frame();
const s=STARCHORUS.nodeScreen(B(2));o.before=STARCHORUS.hitTest(s.sx,s.sy)===B(2);
STARCHORUS.pin(B(2),true);STARCHORUS.setToggles({bands:{"5":false}});await W(3000);STARCHORUS.frame();
const n=STARCHORUS.node(B(2));o.faded=n.alphaDraw<=0.25;o.after=STARCHORUS.hitTest(s.sx,s.sy);o.hover=STARCHORUS.hover(s.sx,s.sy);
o.label=[STARCHORUS.labelCandidates().includes(B(2)),STARCHORUS.labels().some(l=>l.id===B(2))].join();
STARCHORUS.pin(B(2),false);STARCHORUS.setToggles({bands:{"5":true}});await W(3000);STARCHORUS.frame();
const s2=STARCHORUS.nodeScreen(B(2));o.back=STARCHORUS.hitTest(s2.sx,s2.sy)===B(2);
STARCHORUS.hoverNode(B(1));const t1=(document.getElementById("tip-body").innerText.match(/Signal\s*([^\n]*)/)||[])[1]||"";
STARCHORUS.load({source:"recon-db",generated:G+30,aps:[Object.assign(ap(1,"2.4",6),{rssi:-80}),ap(2,"5",36),ap(3,"5",40)],unassociated:[]},"pgh2");await W(200);
const t2=(document.getElementById("tip-body").innerText.match(/Signal\s*([^\n]*)/)||[])[1]||"";o.tip=[t1.indexOf("-55")>=0,t2.indexOf("-80")>=0].join();
STARCHORUS.load({source:"recon-db",generated:G+60,aps:[ap(2,"5",36),ap(3,"5",40)],unassociated:[]},"pgh3");await W(200);
o.tipGone=document.getElementById("tip").style.opacity==="0";
const th0=STARCHORUS.getTheme();window.dispatchEvent(new KeyboardEvent("keydown",{key:"t",repeat:true,bubbles:true}));const th1=STARCHORUS.getTheme();
window.dispatchEvent(new KeyboardEvent("keydown",{key:"t",bubbles:true}));const th2=STARCHORUS.getTheme();STARCHORUS.setTheme(th0);o.key=[th0===th1,th2!==th1].join();
const hp=document.getElementById("help");const hh=hp.hidden;window.dispatchEvent(new KeyboardEvent("keydown",{key:"?",repeat:true,bubbles:true}));const hh1=hp.hidden;window.dispatchEvent(new KeyboardEvent("keydown",{key:"?",bubbles:true}));const hh2=hp.hidden;if(!hh2)window.dispatchEvent(new KeyboardEvent("keydown",{key:"?",bubbles:true}));o.help=[hh===hh1,hh2!==hh1].join();
const tb=new KeyboardEvent("keydown",{key:"Tab",repeat:true,bubbles:true,cancelable:true});window.dispatchEvent(tb);const tt=new KeyboardEvent("keydown",{key:"t",repeat:true,bubbles:true,cancelable:true});window.dispatchEvent(tt);o.tab=[!tb.defaultPrevented,tt.defaultPrevented].join();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$F/field-probes.json" "$PGH_Q" "out/$P-pgh-a" --width 1280 --height 800 --wait 3 --ready "$PGH_RDY" --fps 0 --eval-timeout 90 --eval "$PGH_EVA" >/dev/null 2>&1
PGH_SA=$(evalv "out/$P-pgh-a.json" 1 | pgh_nj)
PGH_WA=$(printf '%s' '{"after":null,"back":true,"before":true,"errors":0,"faded":true,"hover":null,"help":"true,true","key":"true,true","label":"false,false","tab":"true,true","tip":"true,true","tipGone":true}' | pgh_nj)
rowif "page hygiene: the 2D hit test answers only on a drawn star (its spot is dark after the band is filtered off, hit and hover null, no label though pinned, hit again with the band back); the tooltip takes the new signal after a capture and goes with its node; a held toggle key or a held ? fires once, a held Tab keeps its default" [ "$PGH_SA" = "$PGH_WA" ]
[ "$PGH_SA" = "$PGH_WA" ] || { echo "    got:  $PGH_SA"; echo "    want: $PGH_WA"; }

# ---- b. the sheet's revealed age in capture time, the merge of a doubled BSSID, the cut of a long name, the library's words, the SITREP band, an undated capture
PGH_EVB='(async()=>{const o={};const W=(ms)=>STARCHORUS.wait(ms);const G=1700000000;const B="02:00:00:00:66:11",C="02:00:00:00:66:12",D="02:00:00:00:66:13";
const doc=(g,aps,una)=>({source:"recon-db",generated:g,aps:aps,unassociated:una||[]});
const a=(b,ssid,extra)=>Object.assign({bssid:b,ssid:ssid,band:"2.4",channel:6,rssi:-55,security:"WPA2"},extra||{});
STARCHORUS.load(doc(G,[a(B,"")]),"r1");await W(150);o.hidden0=STARCHORUS.node(B).hidden;
STARCHORUS.load(doc(G+600,[a(B,"Lantern")]),"r2");await W(150);o.gen=STARCHORUS.node(B).revealGen===G+600;
STARCHORUS.load(doc(G+1800,[a(B,"Lantern")]),"r3");await W(150);STARCHORUS.setFixedTime(9e6);await W(100);STARCHORUS.frame();
STARCHORUS.select(B);const row=(document.getElementById("detail-body").innerText.match(/Name revealed\s*([^\n]*)/)||[])[1]||"";STARCHORUS.deselect();
o.age=row==="20 min ago";
STARCHORUS.load(doc(G+1900,[a(C,"\u200b\u200b"),a(C,"Named")]),"m1");await W(150);const c=STARCHORUS.node(C);o.merge=[c.ssid==="Named",c.hid===false].join();
STARCHORUS.load(doc(G+1960,[a(D,""),a(D,"\u200b")]),"m2");await W(150);const d=STARCHORUS.node(D);o.merge2=[d.ssid==="",d.hid===true].join();
STARCHORUS.load(doc(G+2000,[a(B,"A".repeat(31)+"\ud83d\ude00")]),"s1");await W(150);const s=STARCHORUS.node(B).ssid;o.cut=[s.length===31,!/[\ud800-\udbff]$/.test(s)].join();
const li=STARCHORUS.libraryImport(B+" constructor\n"+B+" toString\n"+B+" friend");o.lib=[li.added,li.rejected.length,li.rejected.every(r=>r.why==="unknown class")].join();
STARCHORUS.load(doc(G+2100,[a(B,"Lantern")],[{mac:"02:00:00:00:77:02",rssi:-61}]),"t1");await W(150);const sit=STARCHORUS.exportText("sitrep");o.sitrep=[/\? GHz/.test(sit),/ \u00b7  GHz/.test(sit)].join();
STARCHORUS.load(doc(-7e10,[a(B,"Lantern")]),"t2");await W(150);o.undated=/Capture: undated/.test(STARCHORUS.exportText("sitrep"));
STARCHORUS.setFixedTime(null);o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$F/field-probes.json" "$PGH_Q" "out/$P-pgh-b" --width 1280 --height 800 --wait 3 --ready "$PGH_RDY" --fps 0 --eval-timeout 90 --eval "$PGH_EVB" >/dev/null 2>&1
PGH_SB=$(evalv "out/$P-pgh-b.json" 1 | pgh_nj)
PGH_WB=$(printf '%s' '{"age":true,"cut":"true,true","errors":0,"gen":true,"hidden0":true,"lib":"1,2,true","merge":"true,true","merge2":"true,true","sitrep":"true,false","undated":true}' | pgh_nj)
rowif "page hygiene: 'Name revealed' counts from the capture that revealed the name (20 min at a 1,200 s step, the animation clock set far ahead); a doubled BSSID carries name and hidden mark together; a name cut at 32 units ends on a whole character; the library knows its five words; the SITREP says ? GHz for a station without a band; a capture time before 1970 is undated" [ "$PGH_SB" = "$PGH_WB" ]
[ "$PGH_SB" = "$PGH_WB" ] || { echo "    got:  $PGH_SB"; echo "    want: $PGH_WB"; }

# ---- c. one exception in a frame does not end the animation: the first canvas clear made from inside tick() is made to throw once
#         (a clear made elsewhere, as by a toggle's control redraw, passes through), the loop goes on (a frame rendered within the
#         second, and again after a nudge) and the error is recorded once
PGH_EVC='(async()=>{const o={};const e0=STARCHORUS.errors().length;const P=CanvasRenderingContext2D.prototype,orig=P.clearRect;let thrown=0;
P.clearRect=function(){if(String(new Error().stack).indexOf("at tick (")<0)return orig.apply(this,arguments);P.clearRect=orig;thrown++;throw new Error("one frame, by the test");};
STARCHORUS.hoverNode(null);const m=await STARCHORUS.measure(1);P.clearRect=orig;STARCHORUS.hoverNode(null);const m2=await STARCHORUS.measure(0.5);
const errs=STARCHORUS.errors();o.thrown=thrown===1;o.err=errs.length-e0;o.named=/one frame, by the test/.test(String(errs[errs.length-1]||""));o.rendered=m.renderedFrames>=1;o.goesOn=m2.renderedFrames>=1;return JSON.stringify(o);})()'
runq "$F/field-probes.json" "$PGH_Q" "out/$P-pgh-c" --width 1280 --height 800 --wait 3 --ready "$PGH_RDY" --fps 0 --eval-timeout 60 --eval "$PGH_EVC" >/dev/null 2>&1
PGH_SC=$(evalv "out/$P-pgh-c.json" 1 | pgh_nj)
PGH_WC=$(printf '%s' '{"err":1,"goesOn":true,"named":true,"rendered":true,"thrown":true}' | pgh_nj)
rowif "page hygiene: one exception in a frame is recorded once and the animation goes on (the first canvas clear made from inside tick() made to throw once: a frame rendered within the next second, and again after a nudge)" [ "$PGH_SC" = "$PGH_WC" ]
[ "$PGH_SC" = "$PGH_WC" ] || { echo "    got:  $PGH_SC"; echo "    want: $PGH_WC"; }
