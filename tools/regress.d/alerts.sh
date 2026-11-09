# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/alerts.sh -- the firmware's deauth/disassoc alert on the page (0.2): a ring in the theme's alert colour (the token status.alert, red in all three themes) round an alerted access point that
# flickers in the theme's own idiom, and a legend row for it. The data is alerts[] of the capture (tests/fixtures/alerts.json: two reports for access
# points the capture holds and one for an address it does not hold); the collector writes it, the page only draws it, and nothing is sent.
#   R1 the fixture is the generator's, it validates, and the validator refuses twelve broken alerts[] · R2 the ring flickers in each theme's idiom (Foundation a slow
#   pulse, WarGames a seeded phosphor flicker in half-second steps, Whitehall a chalk blink of two levels) and stands steady under reduced motion · R3 it is drawn
#   at the alerted access points and at no other, it reads the theme's alert token, and it leaves the pixels of the access point's own rings as they were · R4 the
#   legend row exists exactly while such a ring can be drawn (not with its band filtered off), in the alert token, with the neutral words · R5 the frame loop is asked
#   for each step of the flicker and for nothing else, and the ring takes both its levels on the canvas · R6 the observation notes are as before, two lines, in the SITREP, the JSON and the CSV, word for word, and nothing beyond them of alerts[] in any text export (P6); with a Remote ID address beside the alerts every CSV row has 26 cells, the alert columns before the ten Remote ID columns · R7 no P10
#   word in what the feature says · R8 the running page makes no request but GET to its own origin while the alert is shown · R9 the planted copies of the page
#   (below) · R10 the colour role of the alert token · R11 the Scope's blip of an alerted access point blinks in the ring's rhythm (frames, both levels, reduced motion, paused, Foundation's
#   pulse sampled at the half second) · R12 the ring's band, as section 14.6 states it (it touches the selection ring)
#   Since 0.2.7 the five kinds of STARCHORUS_WIDS=1 (tests/fixtures/wids.json, the ground truth in the header of build_wids_doc): R1b the fixture and three more
#   refusals of the validator · R13 the page knows the validator's six kinds · R14 the words of the six notes and the legend row (P10, direction, distance; three
#   planted words) · R15 the kinds on the page (notes, legend, rings in three themes, friend, own, band filter, the Bluetooth note, inherited type names, exports)
#   · R16 nine planted copies for the keys of R15 and R6 · R17 the dwell key names the kind: a second kind at an alerted address waits its own two captures, a kind that
#   replaces another in one capture waits too, and a planted copy with the old key (by address alone) shows both at once
# GUARDS AGAINST: a ring that does not flicker, flickers faster than twice a second or flickers under reduced motion; a ring drawn for an address the capture does not
#                 hold, for an own transmitter, or at an access point that was not reported; a colour typed in the draw code instead of the theme's token; a legend row that
#                 shows without a ring or hides with one (or with its band filtered off); a flicker that freezes when the sky does not spin (the frame loop is not asked for
#                 it) or that renders sixty frames a second for a change twice a second; a ring that lands on the security ring, its double, the identity frame or the new-plot
#                 mark; an alert that adds a word the neutral-language rule forbids, or a path that sends; a generator that lets a malformed alerts[] through; a step of the flicker that arms the
#                 phosphor fade again (WarGames, persistence on: 22 frames for each step); a Scope whose alerted blip never blinks, or that renders sixty frames a second for it; a ring that moves so
#                 that the band stated in section 14.6 is no longer true. Since 0.2.7: a kind the page does not know, or a type name an object inherits taken for
#                 one; a derived kind's ring or note at a friend, or a deauth one taken from it; a ring for bt_fixed_new; a Bluetooth note without a live fixed
#                 mark of its address; a word in a note that P10, direction or distance forbid; a dwell keyed by the address alone, so that a second kind at an
#                 alerted address, or a kind that replaces another, shows without its two captures; an alert note missing from the SITREP, the JSON or the CSV, or an
#                 entry the page shows no note for, or an address only an entry names, in a text export (P6).
# NEGATIVE PROBE: R9 runs the same evals on planted copies of the page, each differing from it in exactly one line (the old text exists once): the ring back at px + 8,
#                 the flicker factor replaced by 1, the reduced-motion test removed, no frame request, a frame request every frame, and a legend row that ignores the band
#                 filter; a step that arms the phosphor fade again (R5), in the Scope a loop never asked for the step and Foundation's pulse asked for on every frame (R11), and a ring thinned to
#                 1.25 px at 11.4 (R12), are more. Each must turn its own key red (the key and the value are in the label of the row), and the copies must boot without an error. R1's twelve variants
#                 are the validator's own controls (the unbroken fixture is green); R3 compares the same sky with and without its alerts, and swaps the alert token for a
#                 green one; R5 compares with the same page without alerts, under reduced motion and paused; R10 mutates the token sets (amber, a band colour, no token).
#                 R14's three planted words and R16's nine copies (a friend kept, the friend mark, the bulk mark and the library import without the recompute, bt_fixed_new as a Wi-Fi
#                 kind, the kinds looked up with `in`, the note without the live test, the exports without the alerts, alerts[] itself in the exports) and R17's copy with the dwell keyed by the address alone are more.
# NOT PROVEN:     how the flicker looks on a phone or under a real display's refresh; photosensitivity beyond the rule that nothing steps more than twice a second;
#                 an alert from a real flood (none has been measured: docs/device-notes.md section 5c); the five kinds from a real capture (bt_fixed_new was raised on the device on 4 November 2026, in the first cycles of the build with the
#                 rules on, 66 reports for one strong address; the four Wi-Fi kinds have not shown there yet); where the nine stars of wids.json land on a phone;
#                 the PNG snapshot is not read (the ring is proved on the canvas, R3; the exports and entries keys read the three text exports).
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only AL_* globals are set. Runs without ?fixed (nodes must fade in) and freezes the
# clock itself (STARCHORUS.setFixedTime) for the samples; the WarGames persistence is switched off for them (it would blend neighbouring frames), and on in the one frame count of R5 that is about it.

AL_FX="$F/alerts.json"; AL_T="out/$P-al"; mkdir -p "$AL_T"
AL_Q="?poll=0&spin=0&intro=0&debug=1"
# --ready for a run on the served fixture: the boot poll has replaced the built-in sky (its apsTotal is above 0 from the first frame, so a count would be met at once)
AL_RDY="window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'"

# ---- R1 the fixture and the validator
rm -f "$AL_T/gen.json"; AL_GRC=0; python3 tools/gen-testdata.py --alerts --out "$AL_T/gen.json" 2>/dev/null || AL_GRC=$?   # a fresh file, and the generator's own status
AL_VL=$(python3 tools/gen-testdata.py --validate "$AL_FX" 2>&1 | tail -n 1)
AL_OK=0; if [ "$AL_GRC" = 0 ] && cmp -s "$AL_FX" "$AL_T/gen.json"; then case $AL_VL in *" OK") AL_OK=1 ;; esac; fi
rowif "alerts: alerts.json = gen-testdata.py --alerts byte for byte, and it validates" [ "$AL_OK" = 1 ]
[ "$AL_OK" = 1 ] || echo "    validate: $AL_VL"
# twelve broken alerts[]: each must be refused for alerts[] itself (a PROBLEM line naming it), the unbroken fixture not
AL_BROKEN=$(python3 - "$AL_FX" "$AL_T" <<'PY'
import copy, json, subprocess, sys
src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src))
def refused(name, f):
    x = copy.deepcopy(d); f(x)
    p = "%s/v-%s.json" % (out, name)
    json.dump(x, open(p, "w"))
    r = subprocess.run([sys.executable, "tools/gen-testdata.py", "--validate", p], capture_output=True, text=True)
    return r.returncode == 1 and "alerts" in r.stdout
cases = [
    ("type", lambda x: x["alerts"][0].update(type="flood")),
    ("zero", lambda x: x["alerts"][0].update(n=0)),
    ("text", lambda x: x["alerts"][0].update(n="9")),
    ("upper", lambda x: x["alerts"][0].update(ap="02:00:5E:A1:00:01")),
    ("notmac", lambda x: x["alerts"][0].update(ap="nonsense")),
    ("order", lambda x: x.update(alerts=[{"t": e["t"], "type": e["type"], "ap": e["ap"], "n": e["n"]} for e in x["alerts"]])),
    ("extra", lambda x: x["alerts"][0].update(src="02:00:5e:a1:00:09")),
    ("unsorted", lambda x: x["alerts"].reverse()),
    ("dupe", lambda x: x["alerts"].append(dict(x["alerts"][2], t=1))),
    ("many", lambda x: x.update(alerts=[dict(x["alerts"][0], ap="02:00:5e:a1:01:%02x" % i, t=2000000000 - i) for i in range(21)])),
    ("object", lambda x: x.update(alerts=x["alerts"][0])),
    ("negative", lambda x: x["alerts"][2].update(t=-1)),
]
bad = [n for n, f in cases if not refused(n, f)]
r = subprocess.run([sys.executable, "tools/gen-testdata.py", "--validate", src], capture_output=True, text=True)
print("%d/%d unbroken %s%s" % (len(cases) - len(bad), len(cases), "OK" if r.returncode == 0 else "REFUSED", "" if not bad else " not refused: " + " ".join(bad)))
PY
)
rowif "alerts: the validator refuses twelve broken alerts[] (a type outside the six kinds, a count of 0 or a text, an upper-case or no address, another key order, an extra key, unsorted, a repeated access point, 21 entries, an object, a negative time) and passes the fixture [$AL_BROKEN]" [ "$AL_BROKEN" = "12/12 unbroken OK" ]

# ---- R1b the fixture of the five kinds of 0.2.7 (tests/fixtures/wids.json = gen-testdata.py --wids, the ground truth in the header of build_wids_doc): the
# generator's, valid, and three more refusals on its alerts[]: a kind outside the six, a second kind for one address, a name where the address belongs
AL_WX="$F/wids.json"
rm -f "$AL_T/gen-wids.json"; AL_WGRC=0; python3 tools/gen-testdata.py --wids --out "$AL_T/gen-wids.json" 2>/dev/null || AL_WGRC=$?
AL_WVL=$(python3 tools/gen-testdata.py --validate "$AL_WX" 2>&1 | tail -n 1)
AL_OK=0; if [ "$AL_WGRC" = 0 ] && cmp -s "$AL_WX" "$AL_T/gen-wids.json"; then case $AL_WVL in *" OK") AL_OK=1 ;; esac; fi
rowif "alerts: wids.json = gen-testdata.py --wids byte for byte, and it validates" [ "$AL_OK" = 1 ]
[ "$AL_OK" = 1 ] || echo "    validate: $AL_WVL"
AL_WBR=$(python3 - "$AL_WX" "$AL_T" <<'PY'
import copy, json, subprocess, sys
src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src))
def refused(name, f):
    x = copy.deepcopy(d); f(x)
    p = "%s/w-%s.json" % (out, name)
    json.dump(x, open(p, "w"))
    r = subprocess.run([sys.executable, "tools/gen-testdata.py", "--validate", p], capture_output=True, text=True)
    return r.returncode == 1 and "alerts" in r.stdout
old = d["alerts"][-1]["t"] - 1
cases = [
    ("foreign", lambda x: x["alerts"][0].update(type="chan_change")),
    ("twokinds", lambda x: x["alerts"].append(dict(x["alerts"][0], type="sec_weaker", t=old))),
    ("namekey", lambda x: x["alerts"].__setitem__(0, {"type": "own_name", "t": x["alerts"][0]["t"], "ssid": "HomeNet", "n": 2})),
]
bad = [n for n, f in cases if not refused(n, f)]
r = subprocess.run([sys.executable, "tools/gen-testdata.py", "--validate", src], capture_output=True, text=True)
kinds = ",".join(sorted({e["type"] for e in d["alerts"]}))
print("%d/%d unbroken %s kinds %s%s" % (len(cases) - len(bad), len(cases), "OK" if r.returncode == 0 else "REFUSED", kinds, "" if not bad else " not refused: " + " ".join(bad)))
PY
)
rowif "alerts: the validator refuses three broken alerts[] of wids.json (a kind outside the six, a second kind for one address, a name where the address belongs) and passes the fixture with its five kinds and no deauth entry [$AL_WBR]" [ "$AL_WBR" = "3/3 unbroken OK kinds bt_fixed_new,chan_changed,own_name,sec_profiles,sec_weaker" ]

# ---- R2 / R3 the ring, read from the canvas at the point of the ring (the access point's screen position plus its radius plus the ring's offset of two rings' width)
# (the last block of the eval makes both reported access points own transmitters of this device: no ring then, as the note is skipped for them too)
# The eval samples the alpha of #sky there at twelve fixed times (the clock is frozen with setFixedTime; a tick runs before each sample) for the two alerted
# access points, per theme, then again under reduced motion, then against the same sky without its alerts and with the alert token swapped for green.
AL_EVR='(async()=>{const sleep=STARCHORUS.wait,I=STARCHORUS._internals,S=I.S,T=I.THEMES,o={},TM=[0,100,400,500,900,1000,1400,1500,2000,2500,3000,3500],TH=["foundation","wargames","whitehall"];
const A1="02:00:5e:a1:00:01",A4="02:00:5e:a1:00:04",C="02:00:5e:a1:00:02";
await sleep(1500);
const px=(id,o)=>{const n=STARCHORUS.nodeScreen(id);return n?STARCHORUS.pixel("sky",Math.floor(n.sx+n.px+(o===undefined?11.5:o)),Math.round(n.sy)):{r:-1,g:-1,b:-1,a:-1};};
const ser=async(ids)=>{const r=ids.map(()=>[]);for(const ms of TM){STARCHORUS.setFixedTime(ms);await sleep(120);for(let k=0;k<4;k++)STARCHORUS.frame();ids.forEach((id,i)=>r[i].push(px(id).a));}return r;};
const mx=a=>Math.max(...a),mn=a=>Math.min(...a),dist=a=>new Set(a).size,eq=(a,ix)=>ix.every(i=>a[i]===a[ix[0]]);
STARCHORUS.setToggles({crt:false});
const live={};for(const th of TH){STARCHORUS.setTheme(th);live[th]=await ser([A1,A4]);}
const F=live.foundation,W=live.wargames,H=live.whitehall;
o.foundation=F.every(a=>mn(a)>0&&mx(a)>=1.5*mn(a)&&dist(a)>=6&&[[0,1],[4,5],[6,7]].every(([i,j])=>Math.abs(a[i]-a[j])<=0.25*mx(a)));
o.wargames=W.every(a=>[[0,1,2],[3,4],[5,6]].every(g=>eq(a,g))&&dist([0,3,5,7,8,9,10,11].map(i=>a[i]))>=4);
o.whitehall=H.every(a=>eq(a,[0,1,2,3,4,8,9])&&eq(a,[5,6,7,10,11])&&a[0]>0&&a[0]/a[5]>=0.35&&a[0]/a[5]<=0.45);
STARCHORUS.setReducedMotion(true);
const rm={};for(const th of TH){STARCHORUS.setTheme(th);rm[th]=await ser([A1,A4]);}
o.steady=TH.map(th=>rm[th].every((a,i)=>dist(a)===1&&a[0]>=0.95*mx(live[th][i]))?1:0).join("");
const own={},band={};
for(const th of TH){STARCHORUS.setTheme(th);STARCHORUS.setFixedTime(1000);await sleep(120);const ids=[A1,A4,C];
  const sm=()=>{for(let k=0;k<4;k++)STARCHORUS.frame();return ids.map(id=>px(id).a);};
  const w=sm(),keep=S.alerts;S.alerts=[];const z=sm();S.alerts=keep;
  own[th]=(w[0]-z[0]>=60&&w[1]-z[1]>=60&&Math.abs(w[2]-z[2])<=2)?"ok":"bad "+w+"/"+z;
  const bd=()=>[A1,A4].map(id=>{const r=[];for(let o=3;o<=9;o++){const p=px(id,o);r.push(p.r+","+p.g+","+p.b+","+p.a);}return r.join(";");}).join("|");
  const bw=(sm(),bd());S.alerts=[];const bz=(sm(),bd());S.alerts=keep;sm();band[th]=bw===bz?"ok":"moved";
  const al=T[th].status.alert;T[th].status.alert="#00ff00";const g=(sm(),px(A4));T[th].status.alert=al;const q=(sm(),px(A4));
  own[th]+=(g.g>=200&&g.r<=80&&g.b<=80&&q.r>=q.g)?"":" token "+[g.r,g.g,g.b]+"/"+[q.r,q.g,q.b];}
o.where=TH.map(th=>own[th]).join("|");o.band=TH.map(th=>band[th]).join("|");
{STARCHORUS.setTheme("whitehall");
const fx=await (await fetch("starchorus.json")).json();fx.center.own_bssids=[A1,A4];fx.generated+=50;STARCHORUS.load(fx,"al-own");await sleep(1200);
STARCHORUS.setFixedTime(1000);await sleep(120);
const sm2=()=>{for(let k=0;k<4;k++)STARCHORUS.frame();return [A1,A4].map(id=>px(id).a);};
const ow=sm2(),keep=S.alerts;S.alerts=[];const z=sm2();S.alerts=keep;
o.own=(Math.abs(ow[0]-z[0])<=2&&Math.abs(ow[1]-z[1])<=2)?"ok":"bad "+ow+"/"+z;}
STARCHORUS.setReducedMotion(null);STARCHORUS.setFixedTime(null);
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
# al_ring PAGE PREFIX: the ring eval on PAGE (the page, or a planted copy of it); the keys it reads come back in AL_R (all) and AL_RN (the verdict keys)
al_ring() {
  AL_HK=$H; H=$1   # runq serves $H: point it at the copy for this one call, then put it back
  runq "$AL_FX" "$AL_Q" "$2" --fps 0 --wait 3 --eval-timeout 120 --eval "$AL_EVR" >/dev/null 2>&1
  H=$AL_HK
  AL_R=$(evalv "$2.json" 1)
  AL_RN=$(printf '%s' "$AL_R" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({k: d.get(k) for k in ("foundation","wargames","whitehall","steady","where","band","own","errors")}, separators=(",",":")))' 2>/dev/null)
}
al_ring "$H" "$AL_T/ring"
AL_WANT='{"foundation":true,"wargames":true,"whitehall":true,"steady":"111","where":"ok|ok|ok","band":"ok|ok|ok","own":"ok","errors":0}'
rowif "alerts: the ring of an alerted access point flickers in each theme's idiom (Foundation a slow smooth pulse, WarGames a seeded phosphor flicker in steps of half a second, Whitehall a chalk blink of two levels), stands steady under reduced motion, is drawn at the two reported access points and at no other (not at an own transmitter either), reads the theme's alert token, and leaves every pixel of the access point's own rings (3 to 9 px beyond the star: the security ring and its double, the identity frame, the new-plot mark) as it was without the alert [${AL_RN:-no-value}]" [ "$AL_RN" = "$AL_WANT" ]
[ "$AL_RN" = "$AL_WANT" ] || printf '    %s\n' "$(printf '%s' "${AL_R:-no-value}" | cut -c1-300)"

# ---- R4 / R6 / R7 the legend row, the observation notes, the words: one run on the fixture, then variants of it loaded into the same page
AL_EVL='(async()=>{const sleep=STARCHORUS.wait,I=STARCHORUS._internals,S=I.S,o={},TH=["foundation","wargames","whitehall"];
const A1="02:00:5e:a1:00:01",A4="02:00:5e:a1:00:04",U="02:00:5e:a1:00:77";
await sleep(1500);
const fx=await (await fetch("starchorus.json")).json();
let cnt=0;const ld1=async(mut,lab)=>{const d=JSON.parse(JSON.stringify(fx));d.generated+=5*(++cnt);if(mut)mut(d);STARCHORUS.load(d,lab);await sleep(300);};
const ld=async(mut,lab)=>{await ld1(mut,lab);await ld1(mut,lab);};   // a note shows once its alert has held for two captures (the observations dwell), the legend row and the ring at once
const row=()=>STARCHORUS.legendRows().find(r=>r.kind==="alert");
const notes=()=>STARCHORUS.observations().filter(x=>x.group==="Alerts").map(x=>x.text);
const vis=()=>(row().visible?1:0)+"/"+notes().length;
await ld(null,"al-warm");o.start=vis();
o.tokens=TH.map(th=>{STARCHORUS.setTheme(th);const r=row();return r.visible&&r.paints.length>0&&r.paints.every(p=>p.tok==="status.alert"&&p.css===p.val)?1:0;}).join("");
STARCHORUS.setTheme("foundation");
const txt=document.getElementById("leg-alert").textContent;
o.words=txt==="alert ring = an alert for this AP, see Observations";
o.notes=JSON.stringify(notes());
await ld(d=>{d.alerts=[d.alerts[2]];},"al-unknown");o.unknown=vis();
await ld(d=>{d.center.own_bssids=[A1,A4];},"al-own");o.own=vis();
await ld(d=>{d.alerts=[d.alerts[1]];},"al-one");o.one=vis()+"/"+notes().length;
await ld(d=>{delete d.alerts;},"al-none");o.none=vis();
await ld(null,"al-back");o.back=vis();
STARCHORUS.setToggles({bands:{"2.4":false}});await sleep(300);o.off24=vis();   // alert-a is 2.4 GHz and alert-b 5 GHz: one ring can still be drawn, then none
STARCHORUS.setToggles({bands:{"5":false}});await sleep(300);o.off245=vis();
STARCHORUS.setToggles({bands:{"2.4":true,"5":true}});await sleep(300);o.on=vis();
const N=S.obs.filter(x=>x.group==="Alerts"),T=N.map(x=>x.text),sr=STARCHORUS.exportText("sitrep"),js=STARCHORUS.exportText("json"),cs=STARCHORUS.exportText("csv");
const ex=JSON.parse(js).alerts||[],L=cs.split("\n"),rows=L.filter(l=>l.startsWith("alert,")),cell=(r,i)=>r.split(",")[i],same=(w,x)=>!!w.alert&&x.kind===w.alert.kind&&x.address===w.alert.address&&x.count===w.alert.count,inRow=(w,r)=>!!w.alert&&cell(r,1)===w.alert.address&&cell(r,14)===w.alert.kind&&cell(r,15)===String(w.alert.count);
o.exports=[T.length,T.filter(t=>sr.includes("\n  "+t+"\n")).length,N.filter(w=>ex.some(x=>same(w,x))).length,N.filter(w=>rows.some(r=>inRow(w,r))).length].join("/");   // P6: every note in the SITREP, the JSON and the CSV
o.entries=ex.filter(x=>!N.some(w=>same(w,x))).length+rows.filter(r=>!N.some(w=>inRow(w,r))).length+[sr,js,cs].filter(x=>x.includes(U)).length;   // P6: nothing beyond the notes in the JSON or CSV, and no address only an entry names in any text export
o.jsonAlerts=JSON.stringify(ex);o.csvAlerts=rows.concat([L[0].slice(L[0].indexOf(",cloud")+6)]).join("|");   // word for word: the objects, the rows and the two column names
await ld(d=>{d.bluetooth=[{"addr":"02:00:00:00:0d:01","addr_type":"random-resolvable","rssi":-50,"reports":1,"last_seen":d.generated-20,"company":65535,"company_name":"Maker A","remote_id":{"ua_type":"multirotor","id_type":"serial","uas_id":"TEST-ID.0001","status":"airborne","lat":0.5,"lon":-30.25,"alt_m":120.5,"operator_lat":0.75,"operator_lon":-30.5,"operator_id":"OP-TEST_01"}}];d.center.bt_window=6;d.center.bt_hold=120;},"al-wide");   // the Remote ID record of the generator (gen-testdata.py --remote-id) beside the two alerts
const cw=STARCHORUS.exportText("csv").split("\n").filter(l=>l&&!l.startsWith("#"));
o.wide=[cw[0].includes(",cloud,alert,count,ua_type"),cw.every(l=>l.split(",").length===26),cw.filter(l=>l.startsWith("alert,")).length,cw.filter(l=>l.startsWith("remote_id,")).length].join("/");   // alerts and a Remote ID address together: every row 26 cells, the alert columns before the ten Remote ID columns
const all=[txt].concat(notes());o.text=all.join("|");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
# al_legend PAGE PREFIX: the legend eval on PAGE (the page, or a planted copy); the value comes back in AL_L, the keys without the words in AL_LN
al_legend() {
  AL_HK=$H; H=$1   # runq serves $H: point it at the copy for this one call, then put it back
  runq "$AL_FX" "$AL_Q" "$2" --fps 0 --wait 3 --ready "$AL_RDY" --eval-timeout 60 --eval "$AL_EVL" >/dev/null 2>&1
  H=$AL_HK
  AL_L=$(evalv "$2.json" 1)
  AL_LN=$(printf '%s' "$AL_L" | python3 -c 'import json,sys; d=json.load(sys.stdin); d.pop("text",None); print(json.dumps(d,separators=(",",":"),sort_keys=True))' 2>/dev/null)
}
al_legend "$H" "$AL_T/legend"
AL_LWANT='{"back":"1/2","csvAlerts":"alert,02:00:5e:a1:00:01,alert-a,,,,,,,,,,,,deauth,9|alert,02:00:5e:a1:00:04,alert-b,,,,,,,,,,,,deauth,4|,alert,count","entries":0,"errors":0,"exports":"2/2/2/2","jsonAlerts":"[{\"kind\":\"deauth\",\"address\":\"02:00:5e:a1:00:01\",\"name\":\"alert-a\",\"count\":9},{\"kind\":\"deauth\",\"address\":\"02:00:5e:a1:00:04\",\"name\":\"alert-b\",\"count\":4}]","none":"0/0","notes":"[\"many deauth/disassoc frames heard for this AP: alert-a (9)\",\"many deauth/disassoc frames heard for this AP: alert-b (4)\"]","off24":"1/2","off245":"0/2","on":"1/2","one":"1/1/1","own":"0/0","start":"1/2","tokens":"111","unknown":"0/0","wide":"true/true/2/1","words":true}'
rowif "alerts: the legend row is there while a ring is drawn (2 notes) and gone with no alert, with only the unknown address, with both access points an own transmitter and with the bands of both filtered off (still there for one of them); in the alert token in all three themes; with its neutral words; the two observation notes read as before, and they reach the SITREP, the JSON (alerts objects) and the CSV (alert rows), word for word, and nothing beyond the notes does (P6); with a Remote ID address beside them every CSV row has 26 cells [${AL_LN:-no-value}]" [ "$AL_LN" = "$AL_LWANT" ]
[ "$AL_LN" = "$AL_LWANT" ] || printf '    %s\n' "$(printf '%s' "${AL_L:-no-value}" | cut -c1-400)"
AL_P10=$(sed -n "s/^NTL_P10_RE='\(.*\)'\$/\1/p" tools/regress.d/neutral-language.sh | head -n 1)   # the one definition of the P10 words, read where it lives
AL_TXT=$(printf '%s' "$AL_L" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("text",""))' 2>/dev/null)
printf '%s\n' "$AL_TXT" > "$AL_T/words.txt"
AL_HIT=$(python3 - "$AL_T/words.txt" "$AL_P10" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
print(len(re.findall(sys.argv[2], t, re.I)), len(t))
PY
)
AL_HL=${AL_HIT#* }; AL_HITOK=0
case $AL_HIT in "0 "*) [ -n "$AL_P10" ] && [ "${AL_HL:-0}" -ge 100 ] && AL_HITOK=1 ;; esac
rowif "alerts: P10: no forbidden word in the legend row and the two notes ($AL_HL characters read; the regex is read from neutral-language.sh, which is where it lives)" [ "$AL_HITOK" = 1 ]

# ---- R5 the frame loop: the page renders a frame for each step of the flicker, and for nothing else. Whitehall at rest (no orbiting station) renders only when asked,
# so the frames of 0.7 s are the frames the flicker asked for: a step is due every half second, so one or two, never the sixty a second of a loop that is always asked.
# The ring's own pixel on the canvas is sampled every 100 ms for 2.7 s, live: it must take both its levels (the chalk blink switches every second), which a loop that is not
# asked for the step would never show. Without alerts, under reduced motion and paused it renders next to nothing.
AL_EVF='(async()=>{const sleep=STARCHORUS.wait,I=STARCHORUS._internals,S=I.S,o={};
STARCHORUS.setTheme("whitehall");   // Foundation breathes, so its frame loop never rests; Whitehall (and WarGames) render only when asked, and only a sky without an orbiting station is at rest
const fx=await (await fetch("starchorus.json")).json();fx.aps.forEach(a=>{a.clients=[];});STARCHORUS.load(fx,"al-rest");await sleep(3000);
const n=async()=>{const a=S.perf.rendered;await sleep(700);return S.perf.rendered-a;};
const ring=()=>{const q=STARCHORUS.nodeScreen("02:00:5e:a1:00:01");return STARCHORUS.pixel("sky",Math.floor(q.sx+q.px+11.5),Math.round(q.sy)).a;};
o.alerts=await n();
const lv=new Set();for(let k=0;k<27;k++){lv.add(ring());await sleep(100);}o.levels=[...lv].filter(a=>a>0).length;
const keep=S.alerts;S.alerts=[];S.dirty=true;await sleep(300);o.none=await n();S.alerts=keep;S.dirty=true;
STARCHORUS.setReducedMotion(true);await sleep(300);o.rm=await n();STARCHORUS.setReducedMotion(null);
STARCHORUS.setToggles({paused:true});await sleep(300);o.paused=await n();STARCHORUS.setToggles({paused:false});
await sleep(300);o.again=await n();
fx.generated+=60;STARCHORUS.setTheme("wargames");STARCHORUS.setToggles({crt:true});STARCHORUS.load(fx,"al-rest-wg");await sleep(3000);   // WarGames with its phosphor persistence on: a step is one clean frame, it must not arm the 20-frame fade (it did: 30 frames in 0.7 s)
o.wgOn=S.persistOn;o.wg=await n();o.wg2=await n();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
# al_frames PAGE PREFIX: the frame eval on PAGE (the page, or a planted copy); the value comes back in AL_F, its verdict ("ok" or "bad") in AL_FOK
al_frames() {
  AL_HK=$H; H=$1
  runq "$AL_FX" "$AL_Q" "$2" --fps 0 --wait 3 --eval-timeout 60 --eval "$AL_EVF" >/dev/null 2>&1
  H=$AL_HK
  AL_F=$(evalv "$2.json" 1)
  AL_FOK=$(printf '%s' "$AL_F" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("ok" if 1<=d["alerts"]<=6 and 1<=d["again"]<=6 and d["levels"]>=2 and d["none"]<=3 and d["rm"]<=3 and d["paused"]<=3 and d["wgOn"] is True and 1<=d["wg"]<=6 and 1<=d["wg2"]<=6 and d["errors"]==0 else "bad")' 2>/dev/null)
}
al_frames "$H" "$AL_T/frames"
rowif "alerts: the frame loop is asked for each step of the flicker and for nothing else (Whitehall, which rests when nothing moves: between 1 and 6 frames in 0.7 s with alerts, not sixty a second; the ring takes both its levels on the canvas within 2.7 s; without alerts, under reduced motion and paused at most 3 frames each; WarGames with its phosphor persistence on, which used to render 22 frames for every step, also between 1 and 6 frames in 0.7 s) [${AL_F:-no-value}]" [ "$AL_FOK" = ok ]

# ---- R8 the running page, with the alert drawn, asks for nothing but its own page and file (GET, own origin)
AL_NV=$(net_verdict "$AL_T/ring.json" - 0); AL_NC=$?
AL_NOK=0; [ "$AL_NC" = 0 ] && AL_NOK=1
rowif "alerts: with the alert drawn the page makes no request but GET to its own origin: $AL_NV" [ "$AL_NOK" = 1 ]

# ---- R10 the colour role: the alert colour is red and apart from the three bands and from selection in every theme (tools/check-colors.py, spec 14.4). The validator runs
# on the live token sets; three mutations must each turn it red for the alert role: Foundation's alert in its amber alarm colour, Whitehall's in the 5 GHz band colour, and
# WarGames' without the token. The counts are pinned: 18 checks of the role (3 themes x hue, 3 bands, 2 selection tokens) and a green validator on the real tokens.
runq demo "$AL_Q" "$AL_T/themes" --wait 1 --fps 0 --ready --eval 'JSON.stringify(STARCHORUS._internals.THEMES)' >/dev/null 2>&1
AL_CC=$(python3 -B - "$AL_T/themes.json" <<'PY'
import json, subprocess, sys, tempfile
d = json.load(open(sys.argv[1])); t = json.loads(d["eval"][0]["value"])
def run(mut, *a):
    u = json.loads(json.dumps(t)); mut(u)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(u, f); n = f.name
    return subprocess.run([sys.executable, "tools/check-colors.py", n, *a], capture_output=True, text=True)
base = run(lambda u: None, "--table")
role = [l for l in base.stdout.splitlines() if l.split()[:3][2:] == ["alert"]]
def bites(mut):
    r = run(mut)
    return r.returncode == 1 and any(l.startswith("FAIL") and " alert " in l for l in r.stdout.splitlines())
m = [bites(lambda u: u["foundation"]["status"].__setitem__("alert", u["foundation"]["status"]["alarm"])),
     bites(lambda u: u["whitehall"]["status"].__setitem__("alert", u["whitehall"]["band"]["5"]["core"])),
     bites(lambda u: u["wargames"]["status"].pop("alert"))]
print("%d/%d/%s" % (len(role), base.returncode, "".join("1" if x else "0" for x in m)))
PY
)
rowif "alerts: the colour role of the alert ring holds in all three themes (hue red, ΔE ≥ 15 from the bands and selection: 18 checks, validator green) and bites on the amber alarm colour, a band colour and a missing token [$AL_CC]" [ "$AL_CC" = "18/0/111" ]

# ---- R9 the keys bite: the same evals on six planted copies of the page here (the R5 persistence copy and the R11 and R12 copies follow). Fair by construction: each old text exists once, each copy differs from the page in exactly
# that line, and it boots without an error; each must turn its own key red, and the keys that belong to the other rows stay as they are. The copies are only served to
# headless Chrome on 127.0.0.1; nothing in them sends.
# al_plant OUT OLD NEW [OLD NEW ...]: a copy of the page with each OLD replaced by NEW; return 1 unless every OLD is in the page exactly once
al_plant() {
  _ap_o=$1; shift
  python3 -B - "$H" "$_ap_o" "$@" <<'PY'
import sys
src, out, *pairs = sys.argv[1:]
s = open(src, encoding="utf-8").read()
for old, new in zip(pairs[0::2], pairs[1::2]):
    if s.count(old) != 1:
        sys.exit(1)
    s = s.replace(old, new)
open(out, "w", encoding="utf-8").write(s)
PY
}
# al_copy OUT OLD NEW ...: al_plant, then AL_CPR = its status and AL_CPD = the lines of the page that differ in the copy
al_copy() { al_plant "$@"; AL_CPR=$?; AL_CPD=$(diff "$H" "$1" 2>/dev/null | grep -c '^<'); }
AL_FLK='n.alphaDraw * (reduceMotion ? 1 : cm === "glowPulse" ? 0.7 + 0.3 * Math.sin(S.clock * 3) : cm === "bloomPulse" ? 0.3 + 0.7 * hash(a.ap.slice(-2) + e2 * 97) : 0.4 + 0.6 * (e2 >> 1 & 1))'
AL_REQ='!S.ui.paused && S.clock >= alAt) {'
# the ring key: ring_key FILE KEY... prints the value of each key of the ring eval in FILE, comma-separated
al_key() { printf '%s' "$AL_R" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(str(d.get(k)) for k in sys.argv[1:]))' "$@" 2>/dev/null; }

# the ring back at px + 8 (the outer circle of a WPA2 double ring): the band key
al_copy "$AL_T/p-band.html" 'ringArc(THEME.status.alert, 1.5, null, n.alphaDraw' 'ringArc(THEME.status.alert, 2, null, n.alphaDraw' 'n.px + ENCODING.hidden.offsetPx + 1.5, 0, Math.PI * 2)' 'n.px + 2 * ENCODING.ringOffsetPx, 0, Math.PI * 2)'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_ring "$AL_T/p-band.html" "$AL_T/ring-band"; AL_V=$(al_key band errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "moved|moved|moved,0" ] && AL_OK=1
rowif "alerts: the band key bites: the ring put back at px + 8 (the outer circle of a WPA2 double ring) moves the access point's own pixels in all three themes [copy differs in $AL_C1 line, band/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]

# the flicker factor replaced by 1: the three flicker keys
al_copy "$AL_T/p-flat.html" "$AL_FLK" 'n.alphaDraw * 1'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_ring "$AL_T/p-flat.html" "$AL_T/ring-flat"; AL_V=$(al_key foundation wargames whitehall steady errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "False,False,False,111,0" ] && AL_OK=1
rowif "alerts: the flicker keys bite: a ring whose alpha factor is 1 turns the Foundation, WarGames and Whitehall keys red and leaves the steady key green [copy differs in $AL_C1 line, ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]

# the reduced-motion test removed: the steady key
al_copy "$AL_T/p-rm.html" 'n.alphaDraw * (reduceMotion ? 1 : cm === "glowPulse"' 'n.alphaDraw * (cm === "glowPulse"'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_ring "$AL_T/p-rm.html" "$AL_T/ring-rm"; AL_V=$(al_key foundation wargames whitehall steady errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && case $AL_V in "True,True,True,"*",0") [ "$AL_V" != "True,True,True,111,0" ] && AL_OK=1 ;; esac
rowif "alerts: the steady key bites: a ring that still flickers under reduced motion turns the steady key red and leaves the three flicker keys green [copy differs in $AL_C1 line, ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]

# no frame request: the loop is not asked for the step, so the ring never takes its second level and no frame is rendered
al_copy "$AL_T/p-noreq.html" "$AL_REQ" '!S.ui.paused && false) {'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_frames "$AL_T/p-noreq.html" "$AL_T/frames-noreq"
AL_V=$(printf '%s' "$AL_F" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["alerts"], d["levels"])' 2>/dev/null)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_FOK" = bad ] && [ "$AL_V" = "0 1" ] && AL_OK=1
rowif "alerts: the frame key bites (no request): a loop that is never asked for the step renders no frame in 0.7 s and the ring keeps one level [copy differs in $AL_C1 line, frames/levels ${AL_V:-no-value}, verdict ${AL_FOK:-none}]" [ "$AL_OK" = 1 ]

# a request every frame: the sixty frames a second this fix removed
al_copy "$AL_T/p-always.html" "$AL_REQ" '!S.ui.paused && true) {'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_frames "$AL_T/p-always.html" "$AL_T/frames-always"
AL_V=$(printf '%s' "$AL_F" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["alerts"] > 6, d["levels"] >= 2, d["errors"])' 2>/dev/null)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_FOK" = bad ] && [ "$AL_V" = "True True 0" ] && AL_OK=1
rowif "alerts: the frame key bites (every frame): a loop asked for on every frame renders more than 6 frames in 0.7 s, while the ring still takes both levels [copy differs in $AL_C1 line, over 6 frames/both levels/errors ${AL_V:-no-value}, verdict ${AL_FOK:-none}]" [ "$AL_OK" = 1 ]

# a legend row that ignores the band filter: the off245 key
al_copy "$AL_T/p-leg.html" 'return eventSkip(n) || S.ui.filters[n.band] === false ? null : n; };' 'return eventSkip(n) ? null : n; };'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_legend "$AL_T/p-leg.html" "$AL_T/legend-leg"
AL_V=$(printf '%s' "$AL_L" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["off24"], d["off245"], d["on"], d["errors"])' 2>/dev/null)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "1/2 1/2 1/2 0" ] && AL_OK=1
rowif "alerts: the filter key bites: a legend row that ignores the band filter stays when both bands are filtered off [copy differs in $AL_C1 line, off24/off245/on/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]

# the persistence key: an alert step that arms the phosphor fade again (the 22 frames for each step that this fix removed): only WarGames' count goes over 6
al_copy "$AL_T/p-fade.html" 'S.clock >= alAt) { ctxSky.clearRect(0, 0, W, H); render(); S.perf.rendered++; }' 'S.clock >= alAt) { render(); S.perf.rendered++; S.persistFade = S.persistOn ? RENDER.persistFadeFrames : 0; }'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_frames "$AL_T/p-fade.html" "$AL_T/frames-fade"
AL_V=$(printf '%s' "$AL_F" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["alerts"] <= 6, d["again"] <= 6, d["levels"] >= 2, d["wg"] > 6, d["errors"])' 2>/dev/null)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_FOK" = bad ] && [ "$AL_V" = "True True True True 0" ] && AL_OK=1
rowif "alerts: the persistence key bites: a step that arms the phosphor fade again renders more than 6 frames in 0.7 s in WarGames with persistence on, and only there (Whitehall and the ring's levels stay green) [copy differs in $AL_C1 line, Whitehall frames/again/levels, WarGames over 6, errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]

# ---- R12 the ring's band, read from the page's own numbers: the ring runs from 10.75 to 12.25 px beyond the star's edge (1.5 wide at offsetPx + 1.5). The hidden-SSID ring (offset 10, 1 wide) ends
# at 10.5 and the selection ring (offset 13, 1.5 wide) starts at 12.25: the alert ring is 0.25 px clear of the first and touches the second. docs/architecture.md section 14.6 says exactly that; a free band
# of 1.75 px cannot hold a ring that keeps 0.5 px from both and is still a ring the canvas rows can read (0.75 px). This row keeps the sentence true: the gaps are computed from the page, and a ring that is
# moved or thinned is red until the section is read again.
cat > "$AL_T/gap.py" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
def one(rx):
    m = re.findall(rx, s)
    if len(m) != 1: print("BROKEN:" + rx[:30]); sys.exit(0)
    return m[0]
w, d = one(r"ringArc\(THEME\.status\.alert, ([\d.]+), null, n\.alphaDraw .*? n\.px \+ ENCODING\.hidden\.offsetPx \+ ([\d.]+), 0, Math\.PI \* 2\)")
hw, ho = one(r'hidden: \{ ring: "dashed", dash: \[4, 4\], widthPx: ([\d.]+), offsetPx: ([\d.]+) \}')
so = one(r"selectionRingOffsetPx: ([\d.]+)")
sw = one(r"if \(n\.id === S\.locked\) \{\s*setAlpha\(ctx, alpha\); ctx\.strokeStyle = THEME\.accent\.selection; ctx\.lineWidth = ([\d.]+);")
w, d, hw, ho, so, sw = map(float, (w, d, hw, ho, so, sw))
c = ho + d
print("%.3f/%.3f/%.3f/%.3f" % (c - w / 2, c + w / 2, (c - w / 2) - (ho + hw / 2), (so - sw / 2) - (c + w / 2)))
PY
al_gap() { python3 -B "$AL_T/gap.py" "$1" 2>&1 | head -n 1; }   # al_gap PAGE -> inner edge/outer edge/gap to the hidden-SSID ring/gap to the selection ring, in px
AL_GAP=$(al_gap "$H")
al_copy "$AL_T/p-gap.html" 'ringArc(THEME.status.alert, 1.5, null, n.alphaDraw' 'ringArc(THEME.status.alert, 1.25, null, n.alphaDraw' 'n.px + ENCODING.hidden.offsetPx + 1.5, 0, Math.PI * 2); } }' 'n.px + ENCODING.hidden.offsetPx + 1.4, 0, Math.PI * 2); } }'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; AL_GAPP=$(al_gap "$AL_T/p-gap.html")
AL_OK=0; [ "$AL_GAP" = "10.750/12.250/0.250/0.000" ] && [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_GAPP" != "$AL_GAP" ] && AL_OK=1
rowif "alerts: the ring's band is as section 14.6 states it: from 10.75 to 12.25 px beyond the star, 0.25 px clear of the hidden-SSID ring and touching the selection ring [$AL_GAP]; a ring thinned to 1.25 px at 11.4 reads $AL_GAPP and the row is red for it (copy differs in $AL_C1 line)" [ "$AL_OK" = 1 ]

# ---- R11 the Scope (phone fan, spec 2.3 and 2.4): the blip of an alerted access point blinks in the ring's rhythm. The ring is drawn by drawStars, which the Scope calls; what the Scope
# lacked was the frame for each step (its frame rule knew only the wave and the snow). Whitehall, at 390x844 with the wave over: between 1 and 6 frames in 0.7 s, the ring takes both
# its levels on the canvas within 2.7 s; without alerts, under reduced motion (steady, one level) and paused at most 3 frames each.
AL_EVS='(async()=>{const sleep=STARCHORUS.wait,I=STARCHORUS._internals,S=I.S,o={};
STARCHORUS.setTheme("whitehall");
const fx=await (await fetch("starchorus.json")).json();fx.aps.forEach(a=>{a.clients=[];});fx.unassociated=[];fx.generated+=10;STARCHORUS.load(fx,"al-scope");await sleep(4500);   // the wave (1.2 s here) and its 1.5 s of grace are over
o.on=document.documentElement.dataset.scope;
const n=async()=>{const a=S.perf.rendered;await sleep(700);return S.perf.rendered-a;};
const ring=()=>{const q=STARCHORUS.nodeScreen("02:00:5e:a1:00:01");return STARCHORUS.pixel("sky",Math.floor(q.sx+q.px+11.5),Math.round(q.sy)).a;};
o.frames=await n();o.again=await n();
const lv=new Set();for(let k=0;k<27;k++){lv.add(ring());await sleep(100);}o.levels=[...lv].filter(a=>a>0).length;
const keep=S.alerts;S.alerts=[];S.dirty=true;await sleep(300);o.none=await n();S.alerts=keep;S.dirty=true;
STARCHORUS.setReducedMotion(true);await sleep(300);o.rm=await n();
const rl=new Set();for(let k=0;k<12;k++){rl.add(ring());await sleep(100);}o.rmLv=[...rl].filter(a=>a>0).length;STARCHORUS.setReducedMotion(null);
STARCHORUS.setToggles({paused:true});await sleep(300);o.paused=await n();STARCHORUS.setToggles({paused:false});
STARCHORUS.setTheme("foundation");await sleep(1500);o.fnd=await n();o.fnd2=await n();   // the pulse of Foundation is smooth in the sky and asks for every frame there; in the Scope it is sampled at the half second like the others
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
# al_scope PAGE PREFIX: the Scope eval on PAGE (the page, or a planted copy); the value comes back in AL_S, its verdict ("ok" or "bad") in AL_SOK
al_scope() {
  AL_HK=$H; H=$1
  runq "$AL_FX" "$AL_Q&scope=1" "$2" --width 390 --height 844 --mobile --fps 0 --wait 3 --eval-timeout 90 --eval "$AL_EVS" >/dev/null 2>&1
  H=$AL_HK
  AL_S=$(evalv "$2.json" 1)
  AL_SOK=$(printf '%s' "$AL_S" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("ok" if d["on"]=="on" and 1<=d["frames"]<=6 and 1<=d["again"]<=6 and d["levels"]>=2 and d["none"]<=3 and d["rm"]<=3 and d["rmLv"]==1 and d["paused"]<=3 and 1<=d["fnd"]<=6 and 1<=d["fnd2"]<=6 and d["errors"]==0 else "bad")' 2>/dev/null)
}
al_scope "$H" "$AL_T/scope"
rowif "alerts: the Scope blip of an alerted access point blinks in the ring's rhythm (Whitehall, fan on, wave over: between 1 and 6 frames in 0.7 s and both levels of the chalk blink on the canvas within 2.7 s; without alerts, paused and under reduced motion at most 3 frames, and steady in one level under reduced motion; Foundation, whose pulse is smooth in the sky, between 1 and 6 frames in 0.7 s too) [${AL_S:-no-value}]" [ "$AL_SOK" = ok ]
# the Scope key bites: the copy that is never asked for the step renders no frame in the Scope and the blip keeps one level (the same planted copy as the sky's frame key)
al_copy "$AL_T/p-noreq-sc.html" "$AL_REQ" '!S.ui.paused && false) {'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_scope "$AL_T/p-noreq-sc.html" "$AL_T/scope-noreq"
AL_V=$(printf '%s' "$AL_S" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["frames"], d["levels"], d["errors"])' 2>/dev/null)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_SOK" = bad ] && [ "$AL_V" = "0 1 0" ] && AL_OK=1
rowif "alerts: the Scope key bites: a loop that is never asked for the step renders no frame in the Scope and the blip keeps one level [copy differs in $AL_C1 line, frames/levels/errors ${AL_V:-no-value}, verdict ${AL_SOK:-none}]" [ "$AL_OK" = 1 ]
# the Foundation key bites: the smooth pulse asked for on every frame in the Scope as well (the sky's rule) renders more than 6 frames in 0.7 s there and only there
al_copy "$AL_T/p-fnd.html" 'cm === "glowPulse" && !scopeOn ? 0 :' 'cm === "glowPulse" ? 0 :'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_scope "$AL_T/p-fnd.html" "$AL_T/scope-fnd"
AL_V=$(printf '%s' "$AL_S" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["frames"] <= 6, d["levels"] >= 2, d["fnd"] > 6, d["errors"])' 2>/dev/null)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_SOK" = bad ] && [ "$AL_V" = "True True True 0" ] && AL_OK=1
rowif "alerts: the Foundation key bites: a smooth pulse asked for on every frame in the Scope renders more than 6 frames in 0.7 s there, while Whitehall's blip stays within 6 [copy differs in $AL_C1 line, Whitehall frames/levels, Foundation over 6, errors ${AL_V:-no-value}, verdict ${AL_SOK:-none}]" [ "$AL_OK" = 1 ]

# ---- R13 the page knows the validator's kinds: the keys of AL_TXT are AL_TYPES of tools/gen-testdata.py, word for word (a kind the collector
# learns and the page does not know would be dropped without a word, as every kind but deauth was before 0.2.7)
AL_PK=$(sed -n 's/^const AL_TXT = { \(.*\) };.*/\1/p' "$H" | grep -oE '(^|, )[a-z_]+: "' | sed 's/^, //; s/: "$//' | LC_ALL=C sort | tr '\n' ' ')
AL_VK=$(sed -n 's/^AL_TYPES = (\(.*\))  *#.*/\1/p' tools/gen-testdata.py | tr -d '" ' | tr ',' '\n' | grep . | LC_ALL=C sort | tr '\n' ' ')
AL_KOK=0; [ -n "$AL_PK" ] && [ "$AL_PK" = "$AL_VK" ] && [ "$(printf '%s' "$AL_PK" | wc -w | tr -d ' ')" = 6 ] && AL_KOK=1
rowif "alerts: the page knows the validator's six kinds (the keys of AL_TXT: $AL_PK= AL_TYPES)" [ "$AL_KOK" = 1 ]

# ---- R14 the words of the kinds, read from the page source: the six notes of AL_TXT and the legend row's text hold no P10 word (the regex of
# neutral-language.sh), no word of direction or distance (the judge of scope.sh) and none of track, pilot, locate, scanner. The judge bites: three
# copies of the page, each with one planted word in one note, are found once each.
AL_DR=$(sed -n 's/^    h = re.findall(r"\(.*\)", t)$/\1/p' tools/regress.d/scope.sh)   # the one definition of the direction and distance words, read where it lives
cat > "$AL_T/words.py" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
m = re.findall(r'^const AL_TXT = \{ (.*) \};', s, re.M)
l = re.findall(r'id="leg-alert"[^\n]*?<span>([^<]*)</span>', s)
if len(m) != 1 or len(l) != 1 or not sys.argv[2] or not sys.argv[3]:
    print("BROKEN"); sys.exit(0)
txt = re.findall(r'[a-z_]+: "([^"]*)"', m[0]) + l
bad = [t for t in txt if re.search(sys.argv[2], t, re.I) or re.search(sys.argv[3], t) or re.search(r"(?i)\b(track|pilot|locat|scanner|away|near)", t)]
print("%d/%d" % (len(txt), len(bad)))
PY
al_words() { python3 -B "$AL_T/words.py" "$1" "$AL_P10" "$AL_DR" 2>&1 | head -n 1; }   # al_words PAGE -> texts read/texts with a forbidden word
AL_WD=$(al_words "$H"); rm -f "$AL_T/p-w1.html" "$AL_T/p-w2.html" "$AL_T/p-w3.html"
al_plant "$AL_T/p-w1.html" 'own_name: "own name also sent by another transmitter"' 'own_name: "own name also sent by a rogue transmitter"'; AL_WP1=$?
al_plant "$AL_T/p-w2.html" 'chan_changed: "channel changed since first heard"' 'chan_changed: "channel changed since first heard nearby"'; AL_WP2=$?
al_plant "$AL_T/p-w3.html" 'bt_fixed_new: "new fixed Bluetooth address, strong signal"' 'bt_fixed_new: "new fixed Bluetooth address, strong signal: track it"'; AL_WP3=$?
AL_WB="$AL_WP1$AL_WP2$AL_WP3:$(al_words "$AL_T/p-w1.html") $(al_words "$AL_T/p-w2.html") $(al_words "$AL_T/p-w3.html")"
rowif "alerts: the notes of the six kinds and the legend row say no P10 word, no word of direction or distance and none of track, pilot, locate, scanner [$AL_WD]; a copy with one planted word each (rogue, nearby, track) is found once [$AL_WB]" [ "$AL_WD/$AL_WB" = "7/0/000:7/1 7/1 7/1" ]

# ---- R15 the five kinds of 0.2.7 on the page (tests/fixtures/wids.json, the ground truth in the header of build_wids_doc): the five notes exactly, in the order of
# alerts[] and after the dwell of two captures; the legend row with its kind-neutral words; the ring at the five access points with a Wi-Fi kind and at none of the
# others (the own transmitter, the phone hotspot, two without an entry) in all three themes; a friend loses the ring and the note of a derived kind and keeps a deauth
# entry's; an own transmitter loses both; a band filtered off loses the ring and keeps the note; bt_fixed_new is a note only and only while the capture holds that
# address as a fixed Bluetooth mark (not a rotating one, not in the capture it left, never a ring, not even at an access point of that address); a type that only an
# object inherits (constructor, __proto__, toString) is dropped; the SITREP, the JSON and the CSV carry the notes, word for word, and nothing beyond them.
AL_EVW='(async()=>{const sleep=STARCHORUS.wait,I=STARCHORUS._internals,S=I.S,o={},TH=["foundation","wargames","whitehall"];
const P="02:00:00:00:07:",R1=["02","05","06","07","09"].map(x=>P+x),R0=["01","03","04","08"].map(x=>P+x),SP=P+"09",BA="02:00:00:00:09:01";
await sleep(1500);
const fx=await (await fetch("starchorus.json")).json();
let cnt=0;const ld1=async(mut,lab)=>{STARCHORUS.setFixedTime(null);const d=JSON.parse(JSON.stringify(fx));d.generated+=5*(++cnt);if(mut)mut(d);STARCHORUS.load(d,lab);await sleep(300);};
const ld=async(mut,lab)=>{await ld1(mut,lab);await ld1(mut,lab);};   // a note shows once its alert has held for two captures (the observations dwell)
const notes=()=>STARCHORUS.observations().filter(x=>x.group==="Alerts").map(x=>x.text);
const row=()=>STARCHORUS.legendRows().find(r=>r.kind==="alert");
const px=id=>{const n=STARCHORUS.nodeScreen(id);return n?STARCHORUS.pixel("sky",Math.floor(n.sx+n.px+11.5),Math.round(n.sy)).a:-999;};
const sm=ids=>{for(let k=0;k<4;k++)STARCHORUS.frame();return ids.map(px);};
const nmOf=x=>{const p=fx.aps.find(q=>q.bssid===x);return p?p.ssid:null;};
const rings=async ids=>{STARCHORUS.setFixedTime(1000);await sleep(120);const k0=S.alerts,out=[];for(const id of ids){const rid=id.replace(/^bt:/,"");S.alerts=k0;const w=sm([id])[0];S.alerts=k0.some(a=>a.ap===rid)?k0.filter(a=>a.ap!==rid):k0.filter(a=>nmOf(a.ap)!==nmOf(rid));const z=sm([id])[0];out.push(w-z>=60?1:Math.abs(w-z)<=2?0:"?");}S.alerts=k0;return out.join("");};   // a point with an entry against the same sky without the entries of its own address (the ring of a neighbour is in both frames); a point without one against the sky without the entries of every access point of its name, so a ring drawn on a same-name sibling would show (a copy of the sky would read the same twice)
const bt=t=>d=>{d.bluetooth=[{addr:BA,addr_type:t,rssi:-45,reports:5,last_seen:d.generated-20}];d.center.bt_window=6;d.center.bt_hold=120;};
STARCHORUS.setToggles({crt:false});
await ld(null,"wd-warm");
o.notes=JSON.stringify(notes());
o.legend=row().visible+"|"+document.getElementById("leg-alert").textContent;
const rr=[];for(const th of TH){STARCHORUS.setTheme(th);rr.push(await rings(R1.concat(R0)));}o.rings=rr.join("|");
STARCHORUS.setTheme("foundation");const tSP=notes().find(t=>t.includes("Spinney"));
const tup=()=>{const s1=STARCHORUS.exportText("sitrep"),e1=JSON.parse(STARCHORUS.exportText("json")).alerts||[],r1=STARCHORUS.exportText("csv").split("\n").filter(l=>l.startsWith("alert,"));return [!!tSP,notes().includes(tSP),s1.includes("\n  "+tSP+"\n"),e1.some(x=>x.address===SP),r1.some(r=>r.split(",")[1]===SP)].join("/");};   // the note in the Observations, the SITREP, the JSON and the CSV
STARCHORUS.libraryAssign("friend",{ids:[SP]});o.friendBulk=tup();STARCHORUS.setIdentity(SP,"unknown");await ld(null,"wd-back1");   // the bulk mark takes the note out at once; unmarked, it returns after its dwell
STARCHORUS.libraryImport(SP+" friend");o.friendImport=tup();STARCHORUS.setIdentity(SP,"unknown");await ld(null,"wd-back2");   // the library import too
STARCHORUS.setIdentity(SP,"friend");const f1=await rings([SP]),k1=S.alerts;S.alerts=k1.concat([{type:"deauth",t:0,ap:SP,n:3}]);const f2=await rings([SP]);S.alerts=k1;
o.friendNow=tup();   // P6: the friend mark takes the note out of the Observations, the SITREP, the JSON and the CSV at once, before the next capture
await ld(null,"wd-friend");const f3=notes().length;
await ld(d=>{d.alerts=d.alerts.filter(a=>a.ap!==SP).concat([{type:"deauth",t:d.generated-300,ap:SP,n:3}]);},"wd-friend-deauth");
o.friend=[f1,f2,f3,notes().includes("many deauth/disassoc frames heard for this AP: Spinney (3)")].join("/");
STARCHORUS.setIdentity(SP,"unknown");
await ld(d=>{d.center.own_bssids.push(P+"02");},"wd-own");o.own=notes().length+"/"+(await rings([P+"02"]));
await ld(null,"wd-back");STARCHORUS.setToggles({bands:{"5":false}});await sleep(300);o.bands=(await rings(R1))+"/"+notes().length+"/"+row().visible;
STARCHORUS.setToggles({bands:{"5":true}});
await ld(bt("public"),"wd-bt");await sleep(1200);const bn=STARCHORUS.nodeScreen("bt:"+BA);o.bt=[notes()[2],notes().length,!!(bn&&bn.visible),await rings(["bt:"+BA])].join("/");
await ld1(null,"wd-bt");o.btGone=notes().length;   // the same source: the mark is still held, now without its address in the capture
await ld(bt("random-resolvable"),"wd-bt-rot");o.btRot=notes().length;
await ld(d=>{d.alerts.push({type:"bt_fixed_new",t:d.generated-400,ap:P+"04",n:3});},"wd-bt-ap");o.btAp=(await rings([P+"04"]))+"/"+notes().length;
await ld(d=>{d.alerts=[{type:"constructor",t:d.generated,ap:P+"04",n:3},{type:"__proto__",t:d.generated,ap:P+"03",n:3},{type:"toString",t:d.generated,ap:P+"07",n:1}];},"wd-proto");o.proto=[notes().length,S.alerts.length,row().visible].join("/");
await ld(null,"wd-exp");const N=S.obs.filter(x=>x.group==="Alerts"),T=N.map(x=>x.text),sr=STARCHORUS.exportText("sitrep"),js=STARCHORUS.exportText("json"),cs=STARCHORUS.exportText("csv");
const ex=JSON.parse(js).alerts||[],L=cs.split("\n"),rows=L.filter(l=>l.startsWith("alert,")),cell=(r,i)=>r.split(",")[i],same=(w,x)=>!!w.alert&&x.kind===w.alert.kind&&x.address===w.alert.address&&x.count===w.alert.count,inRow=(w,r)=>!!w.alert&&cell(r,1)===w.alert.address&&cell(r,14)===w.alert.kind&&cell(r,15)===String(w.alert.count);
o.exports=[T.length,T.filter(t=>sr.includes("\n  "+t+"\n")).length,N.filter(w=>ex.some(x=>same(w,x))).length,N.filter(w=>rows.some(r=>inRow(w,r))).length].join("/");   // P6: every note in the SITREP, the JSON and the CSV
o.entries=ex.filter(x=>!N.some(w=>same(w,x))).length+rows.filter(r=>!N.some(w=>inRow(w,r))).length+[sr,js,cs].filter(x=>x.includes(BA)||x.includes(P+"01")||x.includes(P+"08")).length;   // P6: nothing beyond the notes in the JSON or CSV, and the addresses only an entry names (the own transmitter 07:01, the hotspot 07:08, the Bluetooth address without its mark) in no text export
o.jsonAlerts=JSON.stringify(ex);o.csvAlerts=rows.concat([L[0].slice(L[0].indexOf(",cloud")+6)]).join("|");
STARCHORUS.setFixedTime(null);o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
# al_wids PAGE PREFIX: the WIDS eval on PAGE (the page, or a planted copy); the value comes back in AL_W, with its keys sorted in AL_WN
al_wids() {
  AL_HK=$H; H=$1   # runq serves $H: point it at the copy for this one call, then put it back
  runq "$AL_WX" "$AL_Q" "$2" --fps 0 --wait 3 --ready "$AL_RDY" --eval-timeout 120 --eval "$AL_EVW" >/dev/null 2>&1
  H=$AL_HK
  AL_W=$(evalv "$2.json" 1)
  AL_WN=$(printf '%s' "$AL_W" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin),separators=(",",":"),sort_keys=True))' 2>/dev/null)
}
al_wids "$H" "$AL_T/wids"
AL_WWANT='{"bands":"00011/5/true","bt":"new fixed Bluetooth address, strong signal: 02:00:00:00:09:01 (5)/6/true/0","btAp":"0/5","btGone":5,"btRot":5,"csvAlerts":"alert,02:00:00:00:07:02,HomeNet,,,,,,,,,,,,own_name,2|alert,02:00:00:00:07:05,Meadow,,,,,,,,,,,,sec_profiles,2|alert,02:00:00:00:07:06,Orchard,,,,,,,,,,,,sec_weaker,1|alert,02:00:00:00:07:07,Paddock,,,,,,,,,,,,chan_changed,1|alert,02:00:00:00:07:09,Spinney,,,,,,,,,,,,chan_changed,2|,alert,count","entries":0,"errors":0,"exports":"5/5/5/5","friend":"0/1/4/true","friendBulk":"true/false/false/false/false","friendImport":"true/false/false/false/false","friendNow":"true/false/false/false/false","jsonAlerts":"[{\"kind\":\"own_name\",\"address\":\"02:00:00:00:07:02\",\"name\":\"HomeNet\",\"count\":2},{\"kind\":\"sec_profiles\",\"address\":\"02:00:00:00:07:05\",\"name\":\"Meadow\",\"count\":2},{\"kind\":\"sec_weaker\",\"address\":\"02:00:00:00:07:06\",\"name\":\"Orchard\",\"count\":1},{\"kind\":\"chan_changed\",\"address\":\"02:00:00:00:07:07\",\"name\":\"Paddock\",\"count\":1},{\"kind\":\"chan_changed\",\"address\":\"02:00:00:00:07:09\",\"name\":\"Spinney\",\"count\":2}]","legend":"true|alert ring = an alert for this AP, see Observations","notes":"[\"own name also sent by another transmitter: HomeNet (2)\",\"one name, several security profiles: Meadow (2)\",\"security weaker than when first heard: Orchard (1)\",\"channel changed since first heard: Paddock (1)\",\"channel changed since first heard: Spinney (2)\"]","own":"4/0","proto":"0/0/false","rings":"111110000|111110000|111110000"}'
rowif "alerts: the five kinds of 0.2.7 on wids.json: five notes exactly, the legend row in kind-neutral words, the ring at the five access points with a Wi-Fi kind and at none of the four others (own transmitter, phone hotspot, two without an entry) in three themes; a friend loses the derived ring and note and keeps a deauth one, an own transmitter loses both, a band filtered off keeps the note; bt_fixed_new a note only while the capture holds a fixed mark of it (not rotating, not after it left, never a ring, not at an access point of that address); inherited type names dropped; the SITREP, the JSON and the CSV carry the notes, word for word, and nothing beyond them, the three addresses without a note in no text export [${AL_WN:-no-value}]" [ "$AL_WN" = "$AL_WWANT" ]
[ "$AL_WN" = "$AL_WWANT" ] || printf '    %s\n' "$(printf '%s' "${AL_W:-no-value}" | cut -c1-600)"

# ---- R16 the keys of R15 and R6 bite: nine planted copies, each differing from the page in exactly one line, each turns its own key (the copies boot without an error)
al_wkey() { printf '%s' "$AL_W" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(str(d.get(k)) for k in sys.argv[1:]))' "$@" 2>/dev/null; }
# a friend that keeps a derived kind's ring and note
al_copy "$AL_T/p-wfriend.html" 'a.type !== "bt_fixed_new" && identityOf(a.ap) !== "friend") && S.aps.get(a.ap);' 'a.type !== "bt_fixed_new") && S.aps.get(a.ap);'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_wids "$AL_T/p-wfriend.html" "$AL_T/wids-friend"; AL_V=$(al_wkey friend errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "1/1/5/true,0" ] && AL_OK=1
rowif "alerts: the friend key bites: a page whose derived kinds ignore the friend mark keeps their ring and note at a friend [copy differs in $AL_C1 line, friend/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]
# the identity change without the recompute: the friend's note stays in the Observations and the three text exports until the next capture
al_copy "$AL_T/p-wstale.html" 'saveIdentity(); buildLegend(); S.dirty = true; obsCompute(); renderObs();' 'saveIdentity(); buildLegend(); S.dirty = true;'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_wids "$AL_T/p-wstale.html" "$AL_T/wids-stale"; AL_V=$(al_wkey friendNow errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "true/true/true/true/true,0" ] && AL_OK=1
rowif "alerts: the friendNow key bites: a page that marks the friend without recomputing the notes keeps its note in the Observations, the SITREP, the JSON and the CSV until the next capture [copy differs in $AL_C1 line, friendNow/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]
# the bulk mark without the recompute, and the library import without it
al_copy "$AL_T/p-wbulk.html" 'renderInv(); obsCompute(); renderObs(); }' 'renderInv(); }'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_wids "$AL_T/p-wbulk.html" "$AL_T/wids-bulk"; AL_V=$(al_wkey friendBulk errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "true/true/true/true/true,0" ] && AL_OK=1
rowif "alerts: the friendBulk key bites: a page whose bulk assignment does not recompute the notes keeps a friend's note in the Observations and the three text exports [copy differs in $AL_C1 line, friendBulk/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]
al_copy "$AL_T/p-wimport.html" 'saveLibrary(); buildLegend(); S.dirty = true; renderInv(); obsCompute(); renderObs();' 'saveLibrary(); buildLegend(); S.dirty = true; renderInv();'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_wids "$AL_T/p-wimport.html" "$AL_T/wids-import"; AL_V=$(al_wkey friendImport errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "true/true/true/true/true,0" ] && AL_OK=1
rowif "alerts: the friendImport key bites: a page whose library import does not recompute the notes keeps a friend's note in the Observations and the three text exports [copy differs in $AL_C1 line, friendImport/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]
# bt_fixed_new treated as a Wi-Fi kind: a ring and a note at an access point of that address
al_copy "$AL_T/p-wbt.html" '(a.type === "deauth" || a.type !== "bt_fixed_new" && identityOf(a.ap) !== "friend")' '(a.type === "deauth" || identityOf(a.ap) !== "friend")'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_wids "$AL_T/p-wbt.html" "$AL_T/wids-bt"; AL_V=$(al_wkey btAp errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "1/6,0" ] && AL_OK=1
rowif "alerts: the Bluetooth key bites: a page that treats bt_fixed_new as a Wi-Fi kind draws a ring and writes a note at an access point of that address [copy differs in $AL_C1 line, btAp/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]
# the kinds looked up with `in`: the names an object inherits pass
al_copy "$AL_T/p-win.html" '!Object.keys(AL_TXT).includes(x.type)' '!(x.type in AL_TXT)'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_wids "$AL_T/p-win.html" "$AL_T/wids-in"; AL_V=$(al_wkey proto errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "3/3/true,0" ] && AL_OK=1
rowif "alerts: the kinds key bites: a page that looks the kind up with 'in' keeps constructor, __proto__ and toString as alerts, with a note and a ring each [copy differs in $AL_C1 line, proto/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]
# the Bluetooth note without the mark's live test: it outlives the capture the address left
al_copy "$AL_T/p-wlive.html" '(S.bt.get("bt:" + a.ap) || {}).target === 1' 'S.bt.has("bt:" + a.ap)'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_wids "$AL_T/p-wlive.html" "$AL_T/wids-live"; AL_V=$(al_wkey btGone errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "6,0" ] && AL_OK=1
rowif "alerts: the live key bites: a Bluetooth note that only asks whether the mark exists outlives the capture its address left [copy differs in $AL_C1 line, btGone/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]
# the exports without the alerts (the page before P6 (c)): the exports key reads the two notes in the SITREP alone
al_lkey() { printf '%s' "$AL_L" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(str(d.get(k)) for k in sys.argv[1:]))' "$@" 2>/dev/null; }
al_copy "$AL_T/p-lnone.html" 'if (al.length) out.alerts = al;' 'if (!al.length) out.alerts = al;'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_legend "$AL_T/p-lnone.html" "$AL_T/legend-none"; AL_V=$(al_lkey exports errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "2/2/0/0,0" ] && AL_OK=1
rowif "alerts: the exports key bites: a page whose JSON and CSV leave the alerts out reports the two notes in the SITREP alone, against P6 [copy differs in $AL_C1 line, exports/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]
# alerts[] itself in the exports: the entries key sees the entry of the address the capture does not hold, in the JSON and in the CSV, and that address in both
al_copy "$AL_T/p-lraw.html" 'const al = S.obs.filter(o => o.alert).map(o => ({ ...o.alert }));' 'const al = S.alerts.map(a => ({ kind: a.type, address: a.ap, name: null, count: a.n }));'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_legend "$AL_T/p-lraw.html" "$AL_T/legend-raw"; AL_V=$(al_lkey entries errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "4,0" ] && AL_OK=1
rowif "alerts: the entries key bites: a page whose exports carry alerts[] itself reports the entry of the unknown address in the JSON and the CSV and that address in both, which P6 forbids [copy differs in $AL_C1 line, entries/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]

# ---- R17 the dwell key names the kind (1 November 2026): at an alerted access point a second kind waits its own two captures, and a kind that replaces another in
# the same capture waits too (keyed by the address alone, the first kind's clock served the next); the kinds that vanished go at once. Orchard (02:00:00:00:07:06)
# of wids.json carries sec_weaker: chan_changed is added (two entries for one address: a document the collector never writes and the validator refuses, so this
# step tests the page's own guard), then both are replaced by own_name (the case the collector can produce: a kind taking over an address). One label throughout:
# a new label is a new source, which starts the dwell afresh (the first load from the served fixture is one).
AL_EVD='(async()=>{const sleep=STARCHORUS.wait,o={},P="02:00:00:00:07:";await sleep(1500);
const fx=await (await fetch("starchorus.json")).json();
let cnt=0;const ld1=async(mut)=>{const d=JSON.parse(JSON.stringify(fx));d.generated+=5*(++cnt);if(mut)mut(d);STARCHORUS.load(d,"dw");await sleep(300);};
const orch=()=>STARCHORUS.observations().filter(x=>x.group==="Alerts"&&x.text.includes(": Orchard (")).map(x=>x.text);
const addc=d=>{d.alerts.push({type:"chan_changed",t:d.generated-100,ap:P+"06",n:3});};
const swap=d=>{d.alerts=d.alerts.filter(a=>a.ap!==P+"06").concat([{type:"own_name",t:d.generated-50,ap:P+"06",n:2}]);};
STARCHORUS.setToggles({crt:false});
await ld1(null);await ld1(null);o.warm=orch().join("|");
await ld1(addc);o.add1=orch().length+"/"+orch().some(t=>t.startsWith("channel changed"));
await ld1(addc);o.add2=orch().length+"/"+orch().some(t=>t.startsWith("channel changed"));
await ld1(swap);o.swap1=orch().length;
await ld1(swap);o.swap2=orch().join("|");
o.total=STARCHORUS.observations().filter(x=>x.group==="Alerts").length;o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
# al_dwell PAGE PREFIX: the dwell eval on PAGE (the page, or a planted copy); the value in AL_D, its keys sorted in AL_DN
al_dwell() {
  AL_HK=$H; H=$1
  runq "$AL_WX" "$AL_Q" "$2" --fps 0 --wait 3 --ready "$AL_RDY" --eval-timeout 120 --eval "$AL_EVD" >/dev/null 2>&1
  H=$AL_HK
  AL_D=$(evalv "$2.json" 1)
  AL_DN=$(printf '%s' "$AL_D" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin),separators=(",",":"),sort_keys=True))' 2>/dev/null)
}
al_dkey() { printf '%s' "$AL_D" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(str(d.get(k)) for k in sys.argv[1:]))' "$@" 2>/dev/null; }
al_dwell "$H" "$AL_T/dwell"
AL_DWANT='{"add1":"1/false","add2":"2/true","errors":0,"swap1":0,"swap2":"own name also sent by another transmitter: Orchard (2)","total":5,"warm":"security weaker than when first heard: Orchard (1)"}'
rowif "alerts: the dwell is per kind and address: at Orchard (sec_weaker shown) a chan_changed entry waits a second capture (1/false, then 2/true), and own_name replacing both waits too (0, then the one note); five notes in all [${AL_DN:-no-value}]" [ "$AL_DN" = "$AL_DWANT" ]
[ "$AL_DN" = "$AL_DWANT" ] || printf '    %s\n' "$(printf '%s' "${AL_D:-no-value}" | cut -c1-600)"
# the old key, by the address alone: the second kind and the replacement show at once
al_copy "$AL_T/p-wdwell.html" 'add("alert:" + a.type + ":" + a.ap, "Alerts"' 'add("alert:" + a.ap, "Alerts"'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_dwell "$AL_T/p-wdwell.html" "$AL_T/dwell-old"; AL_V=$(al_dkey add1 swap1 errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "2/true,1,0" ] && AL_OK=1
rowif "alerts: the dwell key bites: a page that keys the dwell by the address alone shows a second kind and a replacement at once [copy differs in $AL_C1 line, add1/swap1/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]
