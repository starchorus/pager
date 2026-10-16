# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/clouds.sh -- §8.8a random clouds: one nearby device that scans with a fresh randomised address for every burst
# is one node, not a hundred satellites; the Random switch (X) shows the addresses one by one or hides them; the numbers stay honest.
#   R1 the fixture is the generator's · R2 the anchors in page and Overview · R3 the model on clouds.json = the documented ground truth ·
#   R4 order invariance · R5 identity across polls, the keep rule, history, the receive ring, a kept cloud's sheet · R6 the switch (button,
#   key, storage, ?random=) · R7 hidden · R8 one by one · R9 the cloud drawn in 3 themes x 2D/3D · R10 never in a bubble · R11 page =
#   Overview on documents at every threshold · R12 the detail sheet · R13 the Overview's lines · R15 desktop boxes unchanged ·
#   R16-R19 two devices at one signal, a crowd, a device among strays, a device with three signal bands (page = JQLIB = Overview) ·
#   R20 a second device next to an established cloud · R21 a replay is a view · R22 baseline diff · R23 an own transmitter ·
#   R24 inventory, legend, CSV and observation texts · R25 mutants bite · R26-R31 a very dense crowd, a drifting device, two devices of one
#   period (mixed rhythm and its wording), three devices, six hours, a phone and a laptop of 47 and 73 s
# GUARDS AGAINST: a rule that folds by screen density or by probed SSID instead of signal and rhythm; a rhythm judged on a whole signal band
#                 (two devices, or one among strays, then give no cloud), on a flat share or a Poisson count that a dense crowd passes,
#                 or a band cap that gives no cloud for a long window; a device that moves from one signal band to the next drawn as
#                 several clouds; a label or a claim ('steady rhythm', 'one device') that the bursts do not bear out; a cloud that
#                 flickers, changes its id from poll to poll, takes another device's id or depends on what the page saw before; members that leak into
#                 bubbles, probe orbits, the baseline or the visible counts; a replay that loses the cloud; an own transmitter counted;
#                 a switch that loses a state or its storage; an Overview that counts differently from the page; a button that moves
#                 the desktop panels.
# NEGATIVE PROBE: R25 serves one-line page copies to headless Chrome on 127.0.0.1 only (dating guard, joinDb, the chance test, the chance
#                 level beside the window, the stream split, the band merge, the merge of interleaved bursts, the chains, the burst cap,
#                 the chance-partner purge, the mixed hedge, the keep rule, the replay guard, the baseline fix, the own filter) and a
#                 display copy whose clouds answer nothing; each must turn its row red with the predicted value, the unmutated page is
#                 the control (the rows themselves).
# NOT PROVEN:     real devices' scanning habits beyond the one capture this was tuned on (bursts about every 47 s at one signal) and the
#                 synthetic scenes here (the rule's false-cloud rate on noise, about one scene in 2500 at the densest, was measured on
#                 tens of thousands of generated scenes, not pinned here); the keep rule over hours of polls on the device (R5 walks 31
#                 captures); BusyBox jq timing; the dense band of four devices (two clouds of four; the rest are singles or bubbles).
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only CLD_* globals are set.

CLD_FX="$F/clouds.json"; CLD_T="out/$P-cld"; mkdir -p "$CLD_T"
CLD_Q="?poll=0&spin=0&intro=0"
cld_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }
cld_dsp() { STARCHORUS_DISPLAY_PLAIN=1 sh "$1" --once "$2" "$3" 2>&1; }

# ---- R1 the fixture: clouds.json is the generator's output byte for byte and passes the contract check
python3 tools/gen-testdata.py --clouds --out "$CLD_T/gen.json" 2>/dev/null
CLD_VL=$(python3 tools/gen-testdata.py --validate "$CLD_FX" 2>&1 | tail -n 1)
CLD_OK=0; if cmp -s "$CLD_FX" "$CLD_T/gen.json"; then case $CLD_VL in *" OK") CLD_OK=1 ;; esac; fi
rowif "clouds: clouds.json = gen-testdata.py --clouds byte for byte, and it validates" [ "$CLD_OK" = 1 ]
[ "$CLD_OK" = 1 ] || echo "    validate: $CLD_VL"

# ---- R2 anchors: the constants, the model call, the key, the button in the View group, the query parameter, the storage names; the
# two Overview copies equal and both programs (summary, stations) evaluate `clouds`
cld_c() { grep -cF -- "$1" "$H"; }
CLD_GV=$(awk '/<div class="group" id="grp-view">/,/<\/div>/' "$H" | grep -c 'id="t-random"')
CLD_A="$(cld_c 'const CLOUD = { bandDb: 3, shiftEps: 0.01, shiftMax: 8,')/$(cld_c 'function rebuildClouds(')/$(cld_c 'if (rebuildClouds(gen, rp)) changed = true;')/$(cld_c 'x: () => cycleRandom()')/$CLD_GV/$(grep -c 'query\.random' "$H")/$(cld_c 'const PERSIST_KEYS = ["theme", "view", "random",')"
CLD_DC=0; cmp -s starchorus-display.sh library/user/reconnaissance/starchorus/starchorus-display.sh && CLD_DC=1
CLD_DS=$(sed -n "/^JQ_SUMMARY='/,/'\$/p" starchorus-display.sh | grep -c 'try clouds catch null')
CLD_DK=$(sed -n "/^JQ_CLIENTS='/,/'\$/p" starchorus-display.sh | grep -c 'try clouds catch null')
rowif "clouds: anchors CLOUD/rebuildClouds/its ingest call/key X/#t-random in View/?random/PERSIST_KEYS ($CLD_A), Overview copies equal ($CLD_DC), summary and stations call clouds ($CLD_DS/$CLD_DK)" [ "$CLD_A/$CLD_DC/$CLD_DS/$CLD_DK" = "1/1/1/1/1/1/1/1/1/1" ]

# ---- R3 the model on clouds.json: clouds() and stats() = the ground truth in the header of gen-testdata.py; the member set is derived
# here from the fixture (every da:c1:00:a1:* address, the field-randomised 3c:22:fb:c1:00:f3 and the joiner), and none of the 18
# loose randomised addresses is in a cloud. The same eval judges the mutants of R25.
python3 - "$CLD_FX" "$CLD_T/truth.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); g = d["generated"]
assoc = {c["mac"] for a in d["aps"] for c in a["clients"]}
rnd = [c["mac"] for c in d["unassociated"] if c["mac"] not in assoc and (c.get("randomized") is True or (not c.get("vendor") and c["mac"][1] in "26ae"))]
mem = sorted(m for m in rnd if m.startswith("da:c1:00:a1:") or m in ("3c:22:fb:c1:00:f3", "da:c1:00:a2:00:01"))
loose = sorted(m for m in rnd if m not in mem)
want = {"clouds": [{"n": 121, "core": 120, "joined": 1, "bursts": 30, "cadenceS": 47, "rhythm": 1, "centre": -29, "rssi": -29, "rssiMin": -34,
                    "rssiMax": -28, "first": g - 1482, "last": g - 24, "probes": ["HomeWiFi", "Cafe-Free", "Lab-Net"], "members": mem}],
        "stats": [140, 139, 1, 121, 160, 162], "loose": [None] * len(loose)}
json.dump({"want": want, "loose": loose, "members": mem}, open(sys.argv[2], "w"))
PY
CLD_LOOSE=$(python3 -c 'import json,sys;print(json.dumps(json.load(open(sys.argv[1]))["loose"]))' "$CLD_T/truth.json" 2>/dev/null)
CLD_EVM='(()=>{const L='"${CLD_LOOSE:-[]}"',s=STARCHORUS.stats(),c=STARCHORUS.clouds();return JSON.stringify({clouds:c.map(k=>({n:k.n,core:k.core,joined:k.joined,bursts:k.bursts,cadenceS:k.cadenceS,rhythm:k.rhythm,centre:k.centre,rssi:k.rssi,rssiMin:k.rssiMin,rssiMax:k.rssiMax,first:k.first,last:k.last,probes:k.probes,members:k.members})),stats:[s.randomised,s.randomisedFree,s.clouds,s.inClouds,s.free,s.clients],loose:L.map(m=>{const n=STARCHORUS.node(m);return n?n.cloud:"missing"})})})()'
# cld_m3 REPORT -> "ok|n1,n2,…" (ok = 1 when the eval equals the ground truth), the cloud sizes largest first
cld_m3() { evalv "$1" 1 | python3 -c '
import json, sys
w = json.load(open(sys.argv[1]))["want"]
try: g = json.loads(sys.stdin.read())
except ValueError: print("0|none"); sys.exit()
print("%d|%s" % (g == w, ",".join(str(n) for n in sorted((k["n"] for k in g["clouds"]), reverse=True))))' "$CLD_T/truth.json" 2>/dev/null; }
runseq "$CLD_FX" "$CLD_T/m3" --eval "$CLD_EVM" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CLD_M3=$(cld_m3 "$CLD_T/m3.json"); CLD_M3E=$(evalv "$CLD_T/m3.json" 2)
rowif "clouds: clouds.json = its ground truth: 1 cloud of 121 (120 + 1 joined, 30 bursts about every 47 s, -29 dBm, -34 to -28), 140 randomised, 139 free, 18 loose outside ($CLD_M3, errors ${CLD_M3E:-?})" [ "${CLD_M3%%|*}/$CLD_M3E" = "1/0" ]
[ "${CLD_M3%%|*}" = 1 ] || echo "    got: $(evalv "$CLD_T/m3.json" 1 | cut -c1-600)"

# ---- R4 order invariance: unassociated[] shuffled with five fixed seeds (mulberry32 here, a fresh label per load) gives the same cloud
# ids, members and centre
CLD_EV4='(async()=>{const doc=await (await fetch("starchorus.json",{cache:"no-store"})).json();
const mb=(seed)=>{let a=seed>>>0;return()=>{a=(a+0x6D2B79F5)|0;let t=Math.imul(a^(a>>>15),1|a);t=(t+Math.imul(t^(t>>>7),61|t))^t;return((t^(t>>>14))>>>0)/4294967296;};};
const sig=()=>JSON.stringify(STARCHORUS.clouds().map(c=>[c.id,c.members,c.centre]));
STARCHORUS.load(doc,"cld-order-0");const ref=sig(),out=[];
for(const seed of [11,23,37,51,73]){const d=JSON.parse(JSON.stringify(doc)),r=mb(seed),u=d.unassociated;for(let i=u.length-1;i>0;i--){const j=Math.floor(r()*(i+1));const t=u[i];u[i]=u[j];u[j]=t;}
const moved=u.some((x,i)=>x.mac!==doc.unassociated[i].mac);STARCHORUS.load(d,"cld-order-"+seed);out.push((sig()===ref)+"/"+moved);}
return JSON.parse(ref).length+":"+out.join(" ")+":"+STARCHORUS.errors().length;})()'
runq "$CLD_FX" "$CLD_Q" "$CLD_T/ord" --wait 2 --fps 0 --eval "$CLD_EV4" >/dev/null 2>&1
CLD_O=$(evalv "$CLD_T/ord.json" 1)
rowif "clouds: order invariance, 5 shuffles of unassociated[]: same ids, members, centre ($CLD_O)" [ "$CLD_O" = "1:true/true true/true true/true true/true true/true:0" ]

# ---- R5 identity across polls (WarGames, page clock held): one device, bursts of three at -40 every 20 s, captures 30 s apart in a
# 600 s window. The cloud forms at the first capture (21 bursts; a lone regular device needs 11) and keeps its id while it
# grows (to 31 bursts), is still on a repeated capture, and runs down once the device has stopped (its last burst 680 s in): from
# 10 bursts down the rule says no, the keep rule holds the id (kept) down to 2 addresses, and at 1 address the cloud is gone
# and that address a single. A fresh load of the 9-burst capture has no cloud, nor has the Overview on it. The cloud's series has one
# sample per capture, a member none. A capture whose only news is a new burst of a live cloud does not contract the receive ring;
# one new genuine station does. The sheet of a kept cloud says its rhythm is no longer clear.
python3 - "$CLD_T" <<'PY'
import json, sys
G0, W, out = 1789300000, 600, sys.argv[1]
def burst(k, js=(0, 1, 2)):
    return [{"mac": "da:c5:00:00:%02x:%02x" % (k, j), "rssi": -41 if j == 2 else -40, "last_seen": G0 + 20 * k + (1 if j == 2 else 0), "randomized": True} for j in js]
def doc(g, sts):
    return {"generated": g, "center": {"label": "r5", "max_age": W, "interval": 30}, "source": "recon-db", "unassociated": sts,
            "aps": [{"bssid": "02:00:5e:c5:00:01", "ssid": "cl-a", "channel": 6, "band": "2.4GHz", "freq": 2437, "rssi": -50, "security": "WPA2", "clients": [], "last_seen": g - 5}]}
LAST, caps, g = 34, [], G0 + 400
for j in range(30):
    caps.append(doc(g, [s for k in range(LAST + 1) if G0 + 20 * k <= g and G0 + 20 * k + 1 > g - W for s in burst(k)])); g += 30
caps.append(doc(g, burst(LAST, (0, 1)))); g += 30                                    # 2 addresses: the keep rule holds
caps.append(doc(g, burst(LAST, (0,)))); g += 30                                       # 1 address: gone
caps.append(doc(g, burst(LAST, (0,)) + [{"mac": "3c:22:fb:c5:00:01", "rssi": -60, "vendor": "Apple", "last_seen": g - 2}]))
json.dump(caps, open(out + "/r5-caps.json", "w"), separators=(",", ":"))
json.dump(caps[24], open(out + "/r5-9bursts.json", "w"))
PY
CLD_EV5='(async()=>{const D='"$(cat "$CLD_T/r5-caps.json" 2>/dev/null || echo '[]')"',T=7000000,o={ids:[],n:[],kept:[],nic:[],ring:[]};
const at=async(ms)=>{STARCHORUS.setFixedTime(ms);await STARCHORUS.wait(60);},live=(d)=>STARCHORUS.load(d,"cld-r5",{mode:"live"});
const one=()=>{const c=STARCHORUS.clouds(),s=STARCHORUS.stats();o.ids.push(c.length?c[0].id:null);o.n.push(c.length?c[0].n:0);o.kept.push(c.length?c[0].kept:null);o.nic.push(s.events.newInClouds);o.ring.push(STARCHORUS.recvRing().active);};
await STARCHORUS.wait(600);for(let j=0;j<10;j++){await at(T+1000*(j+1));live(D[j]);one();}
for(let q=0;q<60&&!STARCHORUS.layoutInfo().settled;q++)await STARCHORUS.wait(100);
const id=o.ids[0],i0=STARCHORUS.layoutInfo().iterations,p0=JSON.stringify(STARCHORUS.clouds().map(c=>[c.sx,c.sy])),h0=STARCHORUS.hist(id).n;
await at(T+10500);live(D[9]);await STARCHORUS.wait(300);
o.repeat=[i0===STARCHORUS.layoutInfo().iterations,p0===JSON.stringify(STARCHORUS.clouds().map(c=>[c.sx,c.sy])),h0===STARCHORUS.hist(id).n].join();
for(let j=10;j<31;j++){await at(T+1000*(j+2));live(D[j]);one();if(j===20)o.member=String(STARCHORUS.hist("da:c5:00:00:16:00"));if(j===26){STARCHORUS.select(id);await STARCHORUS.wait(200);const ob=document.querySelector("#detail-body .obsnote");o.lead=ob?ob.textContent:null;}}
const hh=STARCHORUS.hist(id);o.hist=hh?hh.n:null;
await at(T+33000);live(D[31]);one();o.gone=[STARCHORUS.clouds().length,String(STARCHORUS.node("da:c5:00:00:22:00").cloud)].join();
await at(T+34000);live(D[32]);o.genuine=[STARCHORUS.stats().events.newInClouds,STARCHORUS.stats().events.newStations,STARCHORUS.recvRing().active].join();
STARCHORUS.load(D[24],"cld-r5-fresh");o.fresh=STARCHORUS.clouds().length;o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "$CLD_Q&theme=wargames" "$CLD_T/r5" --width 1440 --height 900 --wait 2 --fps 0 --eval-timeout 90 --eval "$CLD_EV5" >/dev/null 2>&1
CLD_R5=$(evalv "$CLD_T/r5.json" 1 | python3 -c '
import json, sys
try: o = json.loads(sys.stdin.read())
except ValueError: print("no result"); sys.exit()
ids = o["ids"]; why = []
if not ids[0] or not ids[0].startswith("rc:") or any(i != ids[0] for i in ids[:31]) or ids[31] is not None: why.append("ids %s" % ids)
want = [63, 66, 72, 75, 81, 84, 90, 90, 93, 90, 90, 84, 81, 75, 72, 66, 63, 57, 54, 48, 45, 39, 36, 30, 27, 21, 18, 12, 9, 3, 2, 0]
if o["n"] != want: why.append("n %s" % o["n"])
if o["kept"] != [False] * 23 + [True] * 8 + [None]: why.append("kept %s" % o["kept"])
if o["nic"] != [0, 3, 6, 3, 6, 3, 6, 3, 6, 3, 3] + [0] * 21 or any(o["ring"]): why.append("burst news nic %s ring %s" % (o["nic"], o["ring"]))
if o["repeat"] != "true,true,true": why.append("repeat " + o["repeat"])
if o["hist"] != 31 or o["member"] != "null": why.append("hist %s member %s" % (o["hist"], o["member"]))
if o["lead"] != "Probably the same nearby device as before, though its rhythm is no longer clear: the addresses still here are kept together. An estimate from signal and timing only; it does not count devices.": why.append("kept lead %r" % o["lead"])
if o["gone"] != "0,null": why.append("gone " + o["gone"])
if o["genuine"] != "0,1,true": why.append("genuine " + o["genuine"])
if o["fresh"] != 0 or o["errors"] != 0: why.append("fresh %s errors %s" % (o["fresh"], o["errors"]))
print("; ".join(why) or "ok")' 2>/dev/null)
CLD_R5D=$(cld_dsp starchorus-display.sh summary "$CLD_T/r5-9bursts.json" | grep '^Clients ')
rowif "clouds: one id over polls while it forms (21 bursts) and grows (to 31), still on a repeated capture, kept from the 10th burst down to 2, gone at 1; 31 samples on the cloud, none on a member; a burst of a live cloud is no news for the ring, a new station is; the 9-burst capture alone has no cloud, nor in the Overview ($CLD_R5; $CLD_R5D)" [ "$CLD_R5/$CLD_R5D" = "ok/Clients  27 free (27 random) · 0 associated" ]

# ---- R6 the switch: default cloud; a click on #t-random and the x key cycle cloud -> show -> hide -> cloud with the state, aria-label,
# title and the saved name in step; an unknown value is ignored; ?random=hide boots hidden and is saved only once changed
CLD_EV6='(async()=>{const E=i=>document.getElementById(i),W=STARCHORUS.wait,o={steps:[]};await W(400);
const look=()=>{const b=E("t-random"),st=STARCHORUS.storageDump()||{};return [STARCHORUS.getToggles().random,b.dataset.state,b.classList.contains("on"),b.getAttribute("aria-label"),b.title,String(st.random)].join("|")};
o.boot=look().split("|").slice(0,5).join("|");
for(let i=0;i<3;i++){E("t-random").dispatchEvent(new MouseEvent("click",{bubbles:true}));await W(350);o.steps.push(look());}
for(let i=0;i<3;i++){document.body.dispatchEvent(new KeyboardEvent("keydown",{key:"x",bubbles:true}));await W(350);o.steps.push(look());}
STARCHORUS.setToggles({random:"x"});o.invalid=STARCHORUS.getToggles().random;
o.help=E("help-list").textContent.indexOf("Randomised addresses: one node per cloud · one by one · hidden (cycles)")>=0;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$CLD_FX" "$CLD_Q" "$CLD_T/sw" --wait 2 --fps 0 --eval "$CLD_EV6" >/dev/null 2>&1
CLD_EV6Q='(async()=>{await STARCHORUS.wait(400);const st0=(STARCHORUS.storageDump()||{}).random,m=STARCHORUS.getToggles().random,h=STARCHORUS.stats().randomHidden;STARCHORUS.setToggles({labels:false});await STARCHORUS.wait(400);const st1=(STARCHORUS.storageDump()||{}).random;STARCHORUS.setToggles({random:"cloud"});await STARCHORUS.wait(400);return [m,h,String(st0),String(st1),String((STARCHORUS.storageDump()||{}).random)].join("|")})()'
runq "$CLD_FX" "$CLD_Q&random=hide" "$CLD_T/swq" --wait 2 --fps 0 --eval "$CLD_EV6Q" >/dev/null 2>&1
CLD_S6=$(evalv "$CLD_T/sw.json" 1 | cld_nj); CLD_S6Q=$(evalv "$CLD_T/swq.json" 1)
CLD_W6=$(python3 -c '
import json
L = {"cloud": ("true", "one node per cloud", "one by one"), "show": ("false", "one by one", "hidden"), "hide": ("true", "hidden", "one node per cloud")}
row = lambda m: "|".join([m, m, L[m][0], "Randomised addresses: " + L[m][1], "Randomised addresses: " + L[m][1] + " [X] · next: " + L[m][2]])
print(json.dumps({"boot": row("cloud"), "steps": [row(m) + "|" + m for m in ("show", "hide", "cloud") * 2], "invalid": "cloud", "help": True, "errors": 0},
                 sort_keys=True, separators=(",", ":"), ensure_ascii=False))')
rowif "clouds: the Random switch: button and X cycle one node per cloud -> one by one -> hidden, state/label/title/saved name in step, an unknown value ignored, help lists X; ?random=hide boots hidden, saved once changed ($CLD_S6Q)" [ "$CLD_S6/$CLD_S6Q" = "$CLD_W6/hide|139|undefined|undefined|cloud" ]
[ "$CLD_S6" = "$CLD_W6" ] || { echo "    got:  $(printf '%s' "$CLD_S6" | cut -c1-700)"; echo "    want: $(printf '%s' "$CLD_W6" | cut -c1-700)"; }

# ---- R7 hidden: the visible counts lose the 139 randomised free addresses, the model and the legend keep them; none is drawn or hit,
# a locked one is let go, no probe orbit is left
CLD_EV7='(async()=>{const W=STARCHORUS.wait,o={};await W(1200);
const ck=STARCHORUS.clouds()[0],mem=ck.members[0],pos=[ck.sx,ck.sy];
STARCHORUS.setToggles({random:"show"});await W(900);STARCHORUS.select(mem);await W(200);o.lockedShow=STARCHORUS.camera().locked===mem;
const mp=STARCHORUS.node(mem),mpos=[mp.sx,mp.sy];
STARCHORUS.setToggles({random:"hide"});await W(2200);
const s=STARCHORUS.stats();o.counts=[s.clients,s.free,s.assoc,s.randomHidden,s.randomised,s.randomisedFree,s.clouds,s.affinity,s.visibleClouds,s.nodes].join();
o.legend=document.querySelector("#leg-random .cnt").textContent;o.locked=String(STARCHORUS.camera().locked);
const rnd=new Set(STARCHORUS.nodes("client").filter(n=>{const x=STARCHORUS.node(n.id);return x.randomized&&x.free}).map(n=>n.id));
o.visible=[rnd.size,STARCHORUS.nodes("client").filter(n=>rnd.has(n.id)&&n.visible).length].join();
const ok=(h)=>h===null||(!rnd.has(h)&&String(h).indexOf("rc:")!==0);o.hit=[ok(STARCHORUS.hitTest(mpos[0],mpos[1])),ok(STARCHORUS.hitTest(pos[0],pos[1]))].join();
o.cell=document.getElementById("n-cl").textContent+" | "+document.getElementById("n-cl").title;o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$CLD_FX" "$CLD_Q" "$CLD_T/hide" --wait 2 --fps 0 --eval "$CLD_EV7" >/dev/null 2>&1
CLD_S7=$(evalv "$CLD_T/hide.json" 1 | cld_nj)
CLD_W7=$(printf '%s' '{"cell":"23 | 21 free · 2 associated · 140 randomised, 121 of them in 1 cloud · 139 hidden","counts":"23,21,2,139,140,139,1,0,0,29","errors":0,"hit":"true,true","legend":"140","locked":"null","lockedShow":true,"visible":"139,0"}' | cld_nj)
rowif "clouds: hidden: 23 visible (21 free, 2 associated), 139 hidden, legend still 140, none drawn or hit, the locked one let go, no probe orbit" [ "$CLD_S7" = "$CLD_W7" ]
[ "$CLD_S7" = "$CLD_W7" ] || { echo "    got:  $CLD_S7"; echo "    want: $CLD_W7"; }

# ---- R8 one by one (bubbles off, so every address is a single): no cloud drawn, all 139 randomised free addresses drawn, the three
# probing members orbit their networks again (0 while folded); nodes = 6 APs + 162 stations, against 6 + 41 + 1 cloud
CLD_EV8='(async()=>{const W=STARCHORUS.wait,o={};await W(1200);const n0=STARCHORUS.stats();o.cloud=[n0.affinity,n0.nodes,n0.forcedAgg].join();
STARCHORUS.setToggles({random:"show"});await W(2500);const s=STARCHORUS.stats();
const r=STARCHORUS.nodes("client").filter(n=>{const x=STARCHORUS.node(n.id);return x.randomized&&(x.free||x.affinity)});
o.show=[s.affinity,s.nodes,s.forcedAgg,STARCHORUS.nodes("cloud").filter(n=>n.visible).length,r.length,r.filter(n=>n.visible).length,STARCHORUS.layoutInfo().clusterCount].join();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$CLD_FX" "$CLD_Q&agg=0" "$CLD_T/show" --wait 2 --fps 0 --eval "$CLD_EV8" >/dev/null 2>&1
CLD_S8=$(evalv "$CLD_T/show.json" 1 | cld_nj)
CLD_W8=$(printf '%s' '{"cloud":"0,48,false","errors":0,"show":"3,168,false,0,139,139,0"}' | cld_nj)
rowif "clouds: one by one: no cloud, 139 randomised drawn, 3 probe orbits (0 folded), 168 nodes against 48 ($CLD_S8)" [ "$CLD_S8" = "$CLD_W8" ]

# ---- R9 drawn in 3 themes x 2D/3D: one visible cloud; its tag a baked sprite "121 · random" (upper case where the theme sets its
# HUD in capitals) clear of the centre label, as is the glyph; in 2D at least inner - coreZonePx from the centre; the tag costs no
# fillText (every counted draw is a listed text label, and one by one counts no fewer: the tag may only take a label's grid cell);
# no member drawn
CLD_EV9='(async()=>{const o={},I=STARCHORUS._internals,cv=document.createElement("canvas").getContext("2d"),fx=1789300000;
for(const t of ["foundation","wargames","whitehall"])for(const v of ["2d","3d"]){
STARCHORUS.setTheme(t);STARCHORUS.setView(v);STARCHORUS.setFixedTime(null);await STARCHORUS.wait(v==="3d"?1800:1000);STARCHORUS.setFixedTime(fx);await STARCHORUS.wait(60);STARCHORUS.frame();
const ks=STARCHORUS.nodes("cloud").filter(n=>n.visible),L=STARCHORUS.labels(),tag=L.filter(l=>l.kind==="cloud"),cen=L.find(l=>l.id==="__center__");
const f=I.THEMES[t].font;cv.font=f.weight.label+" "+f.sizesPx.label+"px "+f.ui;const tw=tag.length?cv.measureText(tag[0].text).width:0;cv.font="400 "+f.sizesPx.hud+"px "+f.ui;const cw=cen?cv.measureText(cen.text).width:0;
const k=ks[0]||{sx:0,sy:0,px:0},hit=(a,b)=>a.x<b.x+b.w&&b.x<a.x+a.w&&a.y<b.y+b.h&&b.y<a.y+a.h,C={x:cen.x,y:cen.y,w:cw,h:12};
const Tg=tag.length?{x:tag[0].x,y:tag[0].y,w:tw,h:12}:null,Gl={x:k.sx-k.px,y:k.sy-k.px,w:2*k.px,h:2*k.px};
const sky=STARCHORUS.phone().sky,inner=Math.min(96,Math.max(64,0.22*sky.r)),d=Math.hypot(k.sx-sky.cx,k.sy-sky.cy);
const ft=STARCHORUS.perf().drawCalls.fillText,ftL=L.filter(l=>!l.sprite&&["label","vendor","group","badge"].includes(l.kind)).length,mem=new Set((STARCHORUS.clouds()[0]||{members:[]}).members),mv=STARCHORUS.nodes("client").filter(n=>mem.has(n.id)&&n.alphaDraw>0.05).length;
STARCHORUS.setToggles({random:"show"});STARCHORUS.frame();const fs=STARCHORUS.perf().drawCalls.fillText;STARCHORUS.setToggles({random:"cloud"});STARCHORUS.frame();
o[t+"/"+v]=[ks.length,tag.length,tag.length?tag[0].text:"",tag.length?tag[0].sprite:false,Tg?!hit(Tg,C):false,!hit(Gl,C),v==="3d"||d>=inner-10-0.01,ft===ftL&&ft<=fs,mv].join();}
STARCHORUS.setTheme("foundation");STARCHORUS.setView("2d");o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$CLD_FX" "$QS_SEQ&debug=1" "$CLD_T/draw" --width 1440 --height 900 --wait 2 --fps 0 --eval-timeout 90 --eval "$CLD_EV9" >/dev/null 2>&1
CLD_S9=$(evalv "$CLD_T/draw.json" 1 | cld_nj)
CLD_W9=$(python3 -c '
import json
r = lambda up: "1,1,121 · " + ("RANDOM" if up else "random") + ",true,true,true,true,true,0"
print(json.dumps({"foundation/2d": r(0), "foundation/3d": r(0), "wargames/2d": r(1), "wargames/3d": r(1), "whitehall/2d": r(1), "whitehall/3d": r(1), "errors": 0},
                 sort_keys=True, separators=(",", ":"), ensure_ascii=False))')
rowif "clouds: drawn as one glyph with a baked tag in 3 themes x 2D/3D, clear of the centre label and the core, the tag costs no fillText, no member drawn" [ "$CLD_S9" = "$CLD_W9" ]
[ "$CLD_S9" = "$CLD_W9" ] || { echo "    got:  $CLD_S9"; echo "    want: $CLD_W9"; }

# ---- R10 never in a bubble: with bubbles on, and on a copy with 700 more genuine free stations (aggregation forced), a bubble holds no
# cloud member while the cloud is shown and no randomised free address while they are hidden; one by one the members may (the
# positive control: they do). A randomised address outside every cloud is a single like any other while the clouds are shown. Each
# mode waits 2.5 s: a bubble of the mode before keeps its old member list while it fades out (bubbles() lists it until it is gone).
python3 - "$CLD_FX" "$CLD_T/dense.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); g = d["generated"]
ouis = ("3c:22:fb", "8c:f5:a3", "24:6f:28", "50:c7:bf", "dc:a6:32"); names = ("Apple", "Samsung Electronics", "Espressif", "TP-Link", "Raspberry Pi Foundation")
for i in range(700):
    d["unassociated"].append({"mac": "%s:c2:%02x:%02x" % (ouis[i % 5], i // 256, i % 256), "rssi": -40 - (i * 7) % 50, "vendor": names[i % 5], "last_seen": g - (i * 13) % 900})
json.dump(d, open(sys.argv[2], "w"))
PY
CLD_EV10='(async()=>{const W=STARCHORUS.wait,o={};await W(1500);
const A=new Set(STARCHORUS.nodes("client").filter(n=>{const x=STARCHORUS.node(n.id);return x.randomized&&(x.free||x.affinity)}).map(n=>n.id)),M=new Set(STARCHORUS.clouds().flatMap(c=>c.members));
const inter=(R)=>STARCHORUS.bubbles().reduce((a,b)=>a+b.members.filter(m=>R.has(m)).length,0);
for(const [m,R] of [["cloud",M],["hide",A],["show",M]]){STARCHORUS.setToggles({random:m});await W(2500);o[m]=[STARCHORUS.bubbles().length>0,inter(R)>0,STARCHORUS.stats().forcedAgg,M.size>0].join();}
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$CLD_FX" "$CLD_Q&agg=1" "$CLD_T/bub" --wait 2 --fps 0 --eval "$CLD_EV10" >/dev/null 2>&1
runq "$CLD_T/dense.json" "$CLD_Q&agg=1" "$CLD_T/bubd" --wait 3 --fps 0 --eval-timeout 60 --eval "$CLD_EV10" >/dev/null 2>&1
CLD_S10="$(evalv "$CLD_T/bub.json" 1 | cld_nj) $(evalv "$CLD_T/bubd.json" 1 | cld_nj)"
CLD_W10="$(printf '%s' '{"cloud":"false,false,false,true","errors":0,"hide":"false,false,false,true","show":"true,true,false,true"}' | cld_nj) $(printf '%s' '{"cloud":"true,false,true,true","errors":0,"hide":"true,false,true,true","show":"true,true,true,true"}' | cld_nj)"
rowif "clouds: no cloud member in a bubble while shown, no randomised free address while hidden (bubbles on; forced with 700 more stations), one by one the members are" [ "$CLD_S10" = "$CLD_W10" ]
[ "$CLD_S10" = "$CLD_W10" ] || { echo "    got:  $CLD_S10"; echo "    want: $CLD_W10"; }

# ---- R11 page = Overview at every threshold. Hand documents (locally administered addresses): a device that scans every 20 s, or
# the same with one thing moved one step across a boundary, the answer pinned: [randomised free, clouds, [n, bursts, core] per cloud]
# from a fresh page load, from the JQLIB cut out of the shipped script, and the (N random, K clouds) of the Overview's summary line.
# A lone regular device needs 11 bursts (10: none); two addresses 3 s apart are two bursts, two chains of one period and two clouds.
rm -f "$CLD_T"/edoc-[0-9]*.json
python3 - "$CLD_T" <<'PY'
import json, sys
G = 1789300000
def st(i, r, t, pre="02:00:5e:e0:00"):
    o = {"mac": "%s:%02x" % (pre, i), "rssi": r, "randomized": True}
    if t is not None: o["last_seen"] = G - 1000 + t
    return o
def doc(un, aps=None, gen=G, own=None):
    d = {"generated": gen, "center": {"label": "edge"}, "source": "recon-db", "aps": aps or [], "unassociated": un}
    if gen is None: del d["generated"]
    if own: d["center"]["own_bssids"] = own
    return d
def dev(n, cad=20, r=-40, t0=100, k=1, gap=2, pre="02:00:5e:e0:00"):   # n bursts of k addresses, one every cad s, gap s apart inside a burst
    return [st(i * k + j, r, t0 + cad * i + gap * j, pre) for i in range(n) for j in range(k)]
ap = {"bssid": "02:00:5e:e1:00:01", "ssid": "edge", "channel": 6, "band": "2.4GHz", "freq": 2437, "rssi": -50, "security": "WPA2", "clients": [{"mac": "02:00:5e:e0:00:03", "rssi": -40}]}
X = lambda r: [st(99, r, 100 + 20 * 5 + 1, "02:00:5e:e3:00")]   # one more address, heard inside the 6th burst
D = [("10 bursts", doc(dev(10)), [10, 0, []]), ("11 bursts", doc(dev(11)), [11, 1, [[11, 11, 11]]]),
     ("burst gap 2 s", doc(dev(24, k=2, gap=2)), [48, 1, [[48, 24, 48]]]), ("burst gap 3 s", doc(dev(24, k=2, gap=3)), [48, 2, [[24, 24, 24], [24, 24, 24]]]),
     ("band-in -43", doc(dev(28) + X(-43)), [29, 1, [[29, 28, 29]]]), ("band-out -44", doc(dev(28) + X(-44)), [29, 1, [[29, 28, 28]]]),
     ("join -46", doc(dev(28) + X(-46)), [29, 1, [[29, 28, 28]]]), ("loose -47", doc(dev(28) + X(-47)), [29, 1, [[28, 28, 28]]]),
     ("two levels", doc(dev(24) + dev(24, cad=25, r=-70, pre="02:00:5e:e2:00")), [48, 2, [[24, 24, 24], [24, 24, 24]]]),
     ("duplicate + associated", doc(dev(28) + [st(5, -70, 700)], aps=[ap]), [27, 1, [[27, 27, 27]]]),
     ("no generated", doc(dev(28), gen=None), [28, 0, []]),
     ("own transmitter", doc(dev(28), own=["02:00:5e:e0:00:03"]), [28, 1, [[27, 27, 27]]]),
     ("probed SSIDs are no key", doc([dict(x, probes=["net-%d" % (i % 3)]) if i % 2 else x for i, x in enumerate(dev(28))]), [28, 1, [[28, 28, 28]]])]
for i, (n, d, w) in enumerate(D):
    json.dump(d, open("%s/edoc-%02d.json" % (sys.argv[1], i), "w"))
    if n == "two levels": json.dump(d, open(sys.argv[1] + "/twolevels.json", "w"))
    if n == "no generated": json.dump(d, open(sys.argv[1] + "/nogen.json", "w"))
json.dump([[n, d, w] for n, d, w in D], open(sys.argv[1] + "/edocs.json", "w"), separators=(",", ":"))
PY
CLD_EV11='(async()=>{const D='"$(cat "$CLD_T/edocs.json" 2>/dev/null || echo '[]')"',o=[];await STARCHORUS.wait(300);
for(let i=0;i<D.length;i++){STARCHORUS.load(D[i][1],"cld-edge-"+i);const s=STARCHORUS.stats();o.push([s.randomisedFree,s.clouds,STARCHORUS.clouds().map(c=>[c.n,c.bursts,c.core]).sort((a,b)=>a[0]-b[0]||a[1]-b[1]||a[2]-b[2])]);}
return JSON.stringify(o);})()'
runq demo "$CLD_Q" "$CLD_T/edge" --wait 1 --fps 0 --eval "$CLD_EV11" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
sed -n "/^JQLIB='/,/^'$/p" starchorus-display.sh | sed "1s/^JQLIB='//; \$s/^'$//" > "$CLD_T/jqlib.jq"
: > "$CLD_T/edge-jq.txt"; : > "$CLD_T/edge-dsp.txt"
for CLD_E in "$CLD_T"/edoc-[0-9]*.json; do
  jq -c "$(cat "$CLD_T/jqlib.jq") clouds | [.rnd, (.clouds | length), ([.clouds[] | [.n, .nb, .core]] | sort)]" "$CLD_E" >> "$CLD_T/edge-jq.txt" 2>/dev/null || echo "error" >> "$CLD_T/edge-jq.txt"
  cld_dsp starchorus-display.sh summary "$CLD_E" | grep '^Clients ' >> "$CLD_T/edge-dsp.txt"
done
CLD_R11=$(python3 - "$CLD_T/edocs.json" "$CLD_T/edge-jq.txt" "$CLD_T/edge-dsp.txt" "$(evalv "$CLD_T/edge.json" 1)" "$(evalv "$CLD_T/edge.json" 2)" <<'PY'
import json, re, sys
D = json.load(open(sys.argv[1])); why = []
try: page = json.loads(sys.argv[4])
except ValueError: page = []
jq = [l.strip() for l in open(sys.argv[2])]; dsp = [l.strip() for l in open(sys.argv[3])]
if len(page) != len(D) or len(jq) != len(D) or len(dsp) != len(D): why.append("runs %d/%d/%d of %d" % (len(page), len(jq), len(dsp), len(D)))
for i, (name, _d, w) in enumerate(D):
    if i < len(page) and page[i] != w: why.append("%s: page %s" % (name, page[i]))
    if i < len(jq):
        try: j = json.loads(jq[i])
        except ValueError: j = jq[i]
        if j != w: why.append("%s: jq %s" % (name, j))
    if i < len(dsp):
        m = re.search(r"free \((\d+) random(?:, (\d+) clouds?)?\)", dsp[i])
        got = [int(m.group(1)), int(m.group(2) or 0)] if m else [0, 0]
        if got != w[:2]: why.append("%s: Overview %s" % (name, dsp[i]))
if sys.argv[5] != "0": why.append("page errors " + sys.argv[5])
print("; ".join(why) or "ok, %d documents" % len(D))
PY
)
rowif "clouds: page = JQLIB = Overview at every threshold, answers pinned: 10/11 bursts, burst gap 2/3 s, band -43/-44, join -46/-47, two levels, duplicate and associated MACs, no generated, an own transmitter, probed SSIDs ($CLD_R11)" [ "${CLD_R11%%,*}" = ok ]
[ "${CLD_R11%%,*}" = ok ] || echo "    got: $CLD_R11"

# ---- R12 the detail sheet of the cloud: title, lead and every row as written (the Signal row up to the theme's level word), one row per
# member, the addresses shown and folded again after their 6 s (page clock, polled), a member row selects and draws that member, Enter
# shows the addresses again, and a pointer click on the cloud selects it without pinning it
CLD_EV12='(async()=>{const W=STARCHORUS.wait,E=i=>document.getElementById(i),o={};await W(1500);
const id=STARCHORUS.clouds()[0].id;STARCHORUS.select(id);await W(300);const b=E("detail-body");
o.title=E("detail-title").textContent;o.lead=b.querySelector(".obsnote").textContent;
o.rows=[...b.querySelectorAll("tr")].map(r=>r.querySelector("th").textContent+"="+r.querySelector("td").textContent);
o.members=b.querySelectorAll("[data-member]").length;o.note=[...b.querySelectorAll(".obsnote")].pop().textContent;o.chip=E("cloud-show").textContent;
o.openExpands=STARCHORUS.clouds()[0].expanded;
const mv=()=>{const m=new Set(STARCHORUS.clouds()[0].members);return STARCHORUS.nodes("client").filter(n=>m.has(n.id)&&n.alphaDraw>0.05).length};
const until=async(f,ms)=>{const t0=performance.now();while(performance.now()-t0<ms){if(f())return Math.round(performance.now()-t0);await W(100);}return -1};
o.fold=await until(()=>!STARCHORUS.clouds()[0].expanded&&mv()===0,15000)>=0;
E("cloud-show").dispatchEvent(new MouseEvent("click",{bubbles:true}));const t1=performance.now();
o.shown=await until(()=>mv()===121,1500)>=0;o.refold=await until(()=>!STARCHORUS.clouds()[0].expanded&&mv()===0,15000)>=0;o.after6=performance.now()-t1>=5900;
const row=E("detail-body").querySelector("[data-member]"),mid=row.getAttribute("data-member");row.dispatchEvent(new MouseEvent("click",{bubbles:true}));
o.member=(await until(()=>STARCHORUS.camera().locked===mid&&STARCHORUS.node(mid).alphaDraw>0.5,3000))>=0&&E("detail-title").textContent===mid;
STARCHORUS.select(id);o.waitFold=(await until(()=>!STARCHORUS.clouds()[0].expanded,15000))>=0;
document.body.dispatchEvent(new KeyboardEvent("keydown",{key:"Enter",bubbles:true}));o.enter=STARCHORUS.clouds()[0].expanded;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$CLD_FX" "$CLD_Q" "$CLD_T/detail" --wait 2 --fps 0 --eval-timeout 90 --eval "$CLD_EV12" \
  --step 'clickat:(()=>{const c=STARCHORUS.clouds()[0];return [c.sx,c.sy]})()' --step 'eval:JSON.stringify([STARCHORUS.clouds()[0].pinned,STARCHORUS.camera().locked===STARCHORUS.clouds()[0].id])' >/dev/null 2>&1
CLD_R12=$(python3 - "$(evalv "$CLD_T/detail.json" 1)" "$(evalv "$CLD_T/detail.json" 3)" <<'PY'
import json, re, sys
why = []
try: o = json.loads(sys.argv[1])
except ValueError: print("no result"); sys.exit()
rows = ["Addresses=121 · randomised (locally administered)", None, "Rhythm=about every 47 s · 30 bursts", "First heard=25 min ago",
        "Last heard=24 s ago", "Freshness=heard < 1 min", "Probes for=HomeWiFi · Cafe-Free · Lab-Net (heard probe requests, rx only)"]
want = {"title": "121 randomised addresses", "members": 121, "chip": "Show the addresses",
        "lead": "Probably one nearby device changing its address: the same signal, heard in bursts at a steady rhythm. An estimate from signal and timing only; it does not count devices.",
        "note": "Random [X]: one node per cloud, one by one, or hidden. Enter shows the addresses of the selected cloud again."}
for k, v in want.items():
    if o.get(k) != v: why.append("%s %r" % (k, o.get(k)))
got = o.get("rows") or []
if len(got) != len(rows): why.append("rows %r" % got)
for g, w in zip(got, rows):
    if (w is None and not re.match(r"^Signal=-29 dBm \(100 %, .+\) · range -34 to -28 dBm$", g)) or (w is not None and g != w): why.append("row %r" % g)
for k in ("openExpands", "fold", "shown", "refold", "after6", "member", "waitFold", "enter"):
    if o.get(k) is not True: why.append("%s %s" % (k, o.get(k)))
if o.get("errors") != 0: why.append("errors %s" % o.get("errors"))
if sys.argv[2] != "[false,true]": why.append("canvas click %s" % sys.argv[2])
print("; ".join(why) or "ok")
PY
)
rowif "clouds: detail sheet: title, lead, rows and note as written, 121 member rows, shown and folded after 6 s, a member row selects and draws it, Enter shows again, a canvas click selects without a pin ($CLD_R12)" [ "$CLD_R12" = ok ]

# ---- R13 the Overview: the summary and the stations screen carry the randomised and the cloud count in their lines, the stations
# screen lists the cloud as one line and no member; both copies print the same; a capture without randomised stations is unchanged
CLD_D1=$(cld_dsp starchorus-display.sh summary "$CLD_FX"); CLD_D2=$(cld_dsp starchorus-display.sh clients "$CLD_FX")
CLD_D3=$(cld_dsp library/user/reconnaissance/starchorus/starchorus-display.sh summary "$CLD_FX"); CLD_D4=$(cld_dsp library/user/reconnaissance/starchorus/starchorus-display.sh clients "$CLD_FX")
CLD_D5=$(cld_dsp starchorus-display.sh summary "$F/single-ap.json" | grep -c '^Clients  0 free · 0 associated$')
CLD_D6=$(printf '%s\n' "$CLD_D2" | python3 -c '
import json, sys
mem = set(json.load(open(sys.argv[1]))["members"]); L = sys.stdin.read().split("\n")
want = ["  160 free (139 random, 1 cloud) · 2 associated", "-29 dBm  cloud of 121 random addresses", "-29 dBm  7a:c1:00:c0:00:01  free",
        "-29 dBm  aa:c1:00:00:a0:01  assoc 02:00:5e:c1:01:01", "-30 dBm  24:6f:28:c1:01:02  free"]
i = L.index(want[0]) if want[0] in L else -1
print(int(i >= 0 and L[i:i + 5] == want and not any(m in l for l in L for m in mem)))' "$CLD_T/truth.json" 2>/dev/null)
CLD_D7=$(printf '%s\n' "$CLD_D1" | grep -c '^Clients  160 free (139 random, 1 cloud) · 2 associated$')
CLD_D8=0; [ "$CLD_D1$CLD_D2" = "$CLD_D3$CLD_D4" ] && CLD_D8=1
rowif "clouds: Overview: 'Clients  160 free (139 random, 1 cloud) · 2 associated' ($CLD_D7), the stations screen with the cloud as one line and no member ($CLD_D6), both copies alike ($CLD_D8), single-ap unchanged ($CLD_D5)" [ "$CLD_D7/$CLD_D6/$CLD_D8/$CLD_D5" = "1/1/1/1" ]

# ---- R15 desktop boxes: with the detail of the strongest AP open, every panel box is the same with #t-random in the View group and
# after taking it out and laying the edges out again (1440x900 and 1000x640, three themes): the button changes no other panel
CLD_EV15='(async()=>{const E=i=>document.getElementById(i),R=e=>{const r=e.getBoundingClientRect();return [r.left,r.top,r.width,r.height].map(v=>Math.round(v*10)/10).join(",")};
const IDS=["masthead","stats","source","legend","controls","chanbar","detail"],snap=()=>IDS.map(i=>{const e=E(i);return i+":"+(e&&!e.hidden&&e.getClientRects().length?R(e):"-")}).join(" ");
const ap=STARCHORUS.nodes("ap").sort((a,b)=>b.rssi-a.rssi)[0].id,TH=["foundation","wargames","whitehall"],before={},out=[];
for(const t of TH){STARCHORUS.setTheme(t);STARCHORUS.select(ap);await STARCHORUS.wait(500);STARCHORUS.edgeLayout();before[t]=snap();}
E("t-random").remove();
for(const t of TH){STARCHORUS.setTheme(t);STARCHORUS.select(ap);await STARCHORUS.wait(500);STARCHORUS.edgeLayout();out.push(before[t]===snap()?"same":t+" "+before[t]+" -> "+snap());}
return out.join(" ")+(E("detail").hidden?" (detail closed)":"");})()'
CLD_B=""
for CLD_SZ in 1440x900 1000x640; do
  runq "$F/field-probes.json" "$CLD_Q" "$CLD_T/box-$CLD_SZ" --width "${CLD_SZ%x*}" --height "${CLD_SZ#*x}" --wait 2 --fps 0 --eval "$CLD_EV15" >/dev/null 2>&1
  CLD_BV=$(evalv "$CLD_T/box-$CLD_SZ.json" 1); [ "$CLD_BV" = "same same same" ] || CLD_B="$CLD_B $CLD_SZ: $CLD_BV;"
done
rowif "clouds: desktop panels (masthead, stats, source, legend, controls, chanbar, detail) unchanged by #t-random at 1440x900 and 1000x640 in 3 themes${CLD_B:+:$CLD_B}" [ -z "$CLD_B" ]

# ---- R16-R19 the scenes beyond one device (tools/gen-testdata.py --clouds KIND, generated here, not stored): the page, the JQLIB cloud
# rule and the Overview's summary line each give the same signature, "size/core/bursts/period/addresses by their first octets" per cloud,
# largest first, and it is the pinned one.
#   R16 two  a phone (every 47 s) and a laptop (every 61 s) at one signal: a cloud for each, 516 of the 544 addresses in one of them
#            (the old rule judged the band as one rhythm and gave none: the Milky Way came back). Two runs of phone bursts (4 and 3,
#            28 addresses) are in neither: a burst of the laptop that lands within 2 s of one of the phone's is one burst, and the
#            chain of the phone does not go through it; the phone's cloud holds 28 laptop addresses that were in such bursts
#   R17 crowd  600 unrelated addresses in 5 minutes: none (the first rule, a flat share of gaps on one period, made a cloud of 206 of this one)
#   R18 strays  the phone with 40 single addresses at random times in its band: its cloud, the strays loose but for those a burst reaches
#   R19 wide  the phone with -28, -34 and -40 dBm in every burst, three signal bands: one cloud of 231, not three
#   R26 dense  1500 unrelated addresses in 15 minutes: none (pairs against a Poisson chance level made a cloud of about 600 of this one)
#   R27 drift  the phone whose signal moves 10 dB in the hour: one cloud (the bursts cross from one band to the next; two clouds before)
#   R28 same   two devices of one period, 17 s apart: one cloud labelled about every 47 s, its rhythm mixed (its sheet, observation and
#              export say 'possibly one or more nearby devices', never 'steady rhythm' or 'one device'; the first rule said every 28 s)
#   R29 three  three devices at one signal (47, 61 and 83 s): a cloud for each (one cloud of the three, with a made-up period, before)
#   R30 long   the phone for six hours, 1840 addresses: one cloud (none while a band with more than 240 bursts yielded none)
#   R31 pair   a phone (47 s) and a laptop (73 s) at one signal: a cloud each, the laptop's bursts kept out of the phone's
#   R32 wander a device whose schedule wanders (late bursts, missed ones, the way a real one was heard): one cloud of 264 of 284 addresses
#              (a chain of bursts breaks at every late one, the pairs a period shows do not: 148 without the pairs)
#   R33 polls  220 captures 30 s apart of a device whose signal moves 6 and 10 dB in the hour: one cloud, one id, never two (page clock held)
CLD_EVMIX='(()=>{return JSON.stringify(STARCHORUS.clouds().map(k=>{const p={};for(const m of k.members){const x=m.slice(0,8);p[x]=(p[x]||0)+1}return [k.n,k.core,k.bursts,k.cadenceS,p]}))})()'
cld_sigpy() {   # stdin: [[n, core, bursts, period, {first octets: count} | [ids]]…] -> "n/core/bursts/period/da:c2:a1:308,…;…" largest first
  python3 -c '
import json, sys
try: L = json.loads(sys.stdin.read())
except ValueError: print("no data"); sys.exit()
out = []
for n, core, nb, cad, p in L:
    if isinstance(p, list):
        q = {}
        for m in p: q[m[:8]] = q.get(m[:8], 0) + 1
        p = q
    out.append((-n, "%d/%d/%d/%s/%s" % (n, core, nb, cad, ",".join("%s:%d" % kv for kv in sorted(p.items())))))
print(";".join(s for _, s in sorted(out)))' 2>/dev/null
}
cld_mix() {   # cld_mix KIND -> "page|jq|Overview's (N random, K clouds)"
  python3 tools/gen-testdata.py --clouds "$1" --out "$CLD_T/mixdoc-$1.json" 2>/dev/null
  runseq "$CLD_T/mixdoc-$1.json" "$CLD_T/mix-$1" --eval "$CLD_EVMIX" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
  _cm_p=$(evalv "$CLD_T/mix-$1.json" 1 | cld_sigpy); _cm_e=$(evalv "$CLD_T/mix-$1.json" 2)
  _cm_j=$(jq -c "$(cat "$CLD_T/jqlib.jq") clouds | [.clouds[] | [.n, .core, .nb, .cad, .ids]]" "$CLD_T/mixdoc-$1.json" 2>/dev/null | cld_sigpy)
  _cm_o=$(cld_dsp starchorus-display.sh summary "$CLD_T/mixdoc-$1.json" | python3 -c '
import re, sys
m = re.search(r"free \((\d+) random(, \d+ clouds?)?\)", sys.stdin.read())
print(m.group(1) + (m.group(2) or "") if m else "none")' 2>/dev/null)
  printf '%s|%s|%s|%s\n' "$_cm_p" "$_cm_j" "$_cm_o" "$_cm_e"
}
CLD_M16=$(cld_mix two); CLD_M17=$(cld_mix crowd); CLD_M18=$(cld_mix strays); CLD_M19=$(cld_mix wide)
CLD_M26=$(cld_mix dense); CLD_M27=$(cld_mix drift); CLD_M28=$(cld_mix same); CLD_M29=$(cld_mix three); CLD_M30=$(cld_mix long); CLD_M31=$(cld_mix pair); CLD_M32=$(cld_mix wander)
# $1 = the signature, equal in page and jq; the Overview's count; 0 page errors
cld_chk() { _cc_p=${1%%|*}; _cc_r=${1#*|}; _cc_j=${_cc_r%%|*}; _cc_r=${_cc_r#*|}; _cc_o=${_cc_r%%|*}; _cc_e=${_cc_r#*|}
  [ "$_cc_p" = "$_cc_j" ] && [ "$_cc_p/$_cc_o/$_cc_e" = "$2/$3/0" ]; }
rowif "clouds: two devices at one signal (47 s and 61 s): a cloud each, 516 of the 544 addresses in one of them (two runs of phone bursts, 28 addresses, in neither); page = JQLIB, Overview '544 random, 2 clouds' (${CLD_M16%%|*})" cld_chk "$CLD_M16" "300/300/68/48/da:c2:a1:272,da:c2:b1:28;216/216/52/62/da:c2:a1:8,da:c2:b1:208" "544, 2 clouds"
rowif "clouds: a crowd (600 unrelated addresses in 5 minutes) is no cloud; page = JQLIB, Overview '600 random' without a cloud (${CLD_M17%%|*})" cld_chk "$CLD_M17" "" "600"
rowif "clouds: a device among 40 strays in its band keeps its cloud (308 + the 7 strays a burst reaches), 33 strays stay loose; page = JQLIB (${CLD_M18%%|*})" cld_chk "$CLD_M18" "315/315/83/48/6e:c2:00:7,da:c2:a1:308" "348, 1 cloud"
rowif "clouds: a device with three signal bands (-28, -34, -40 dBm) is one cloud of 231, not three; page = JQLIB (${CLD_M19%%|*})" cld_chk "$CLD_M19" "231/231/77/48/da:c2:a1:231" "231, 1 cloud"
rowif "clouds: a very dense crowd (1500 unrelated addresses in 15 minutes) is no cloud; page = JQLIB, Overview '1500 random' without a cloud (${CLD_M26%%|*})" cld_chk "$CLD_M26" "" "1500"
rowif "clouds: a device whose signal moves 10 dB in the hour is one cloud of 308 (300 + 8 joined), not one per signal band; page = JQLIB (${CLD_M27%%|*})" cld_chk "$CLD_M27" "308/300/77/48/da:c2:a1:308" "308, 1 cloud"
rowif "clouds: two devices of one period, 17 s apart, are one cloud of 612 labelled about every 48 s; page = JQLIB (${CLD_M28%%|*})" cld_chk "$CLD_M28" "612/612/153/48/da:c2:a1:308,da:c2:b1:304" "612, 1 cloud"
rowif "clouds: three devices at one signal (47, 61, 83 s) are a cloud each, 656 of the 716 addresses; page = JQLIB (${CLD_M29%%|*})" cld_chk "$CLD_M29" "268/268/56/48/da:c2:a1:224,da:c2:b1:24,da:c2:c1:20;248/248/53/62/da:c2:a1:16,da:c2:b1:208,da:c2:c1:24;140/140/32/84/da:c2:a1:12,da:c2:c1:128" "716, 3 clouds"
rowif "clouds: six hours of one device (1840 addresses, 460 bursts) are one cloud; page = JQLIB (${CLD_M30%%|*})" cld_chk "$CLD_M30" "1840/1840/460/48/da:c2:a1:1840" "1840, 1 cloud"
rowif "clouds: a phone (47 s) and a laptop (73 s) at one signal are a cloud each, 496 of the 504 addresses, the laptop's bursts not taken into the phone's cloud; page = JQLIB (${CLD_M31%%|*})" cld_chk "$CLD_M31" "336/336/79/48/da:c2:a1:308,da:c2:b1:28;160/160/40/74/da:c2:b1:160" "504, 2 clouds"

rowif "clouds: a device whose schedule wanders (late bursts, missed ones) is one cloud of 264 of its 284 addresses; page = JQLIB (${CLD_M32%%|*})" cld_chk "$CLD_M32" "264/264/66/47/da:c2:a1:264" "284, 1 cloud"

# ---- R33 220 polls of a device whose signal moves (the verifier's drift sequence, built in the page from a compact generator): captures 30 s
# apart, each the last hour of a device that bursts every 47 s, three or four addresses a burst, its signal moving 6 dB in the hour (sd 1)
# and 10 dB (sd 2); one cloud on every poll, one id for all 220, the biggest cloud never moves by more than 30 addresses between polls
CLD_EV33='(async()=>{
function rngOf(seed){let a=seed>>>0;return function(){a=(a+0x6D2B79F5)|0;let t=Math.imul(a^(a>>>15),1|a);t=(t+Math.imul(t^(t>>>7),61|t))^t;return((t^(t>>>14))>>>0)/4294967296}}
function gauss(r){let u=0;while(!u)u=r();const v=r();return Math.sqrt(-2*Math.log(u))*Math.cos(2*Math.PI*v)}
let K=0;const mac=()=>{K++;return "da:"+(K>>>16&255).toString(16).padStart(2,"0")+":"+(K>>>8&255).toString(16).padStart(2,"0")+":"+(K&255).toString(16).padStart(2,"0")+":00:01"};
const G0=1789300000,W=3600,POLLS=220,out=[];
function device(r,drift,sd){const o=[];for(let t=-200;t<W+30*POLLS;t+=47){const b=t+1.2*gauss(r),n=Math.max(1,3+[-1,0,0,1][Math.floor(r()*4)]);for(let j=0;j<n;j++){const ts=Math.round(b+(n>1?j*2/(n-1):0)+(r()*0.6-0.3));o.push({mac:mac(),rssi:Math.min(-20,Math.max(-95,Math.round(-50+drift*t/3600+sd*gauss(r)))),last_seen:G0+ts,randomized:true});}}return o;}
for(const [drift,sd] of [[6,1],[10,2]]){const ALL=device(rngOf(4242),drift,sd);let multi=0,ids=new Set(),step=0,prev=null,n0=0;
 for(let p=0;p<POLLS;p++){const g=W+30*p;STARCHORUS.load({generated:G0+g,center:{label:"poll",max_age:W,interval:30},source:"recon-db",aps:[],unassociated:ALL.filter(x=>x.last_seen-G0>g-W&&x.last_seen-G0<=g)},"cld-r33-"+drift,{mode:"live"});
  const c=STARCHORUS.clouds();if(c.length!==1)multi++;c.forEach(k=>ids.add(k.id));const big=c.length?c[0].n:0;if(prev!=null)step=Math.max(step,Math.abs(big-prev));prev=big;}
 out.push([drift,multi,ids.size,step<=30]);}
return JSON.stringify({runs:out,errors:STARCHORUS.errors().length});})()'
runq demo "$CLD_Q" "$CLD_T/polls" --width 1000 --height 640 --wait 1 --fps 0 --eval-timeout 300 --eval "$CLD_EV33" >/dev/null 2>&1
CLD_R33=$(evalv "$CLD_T/polls.json" 1 | cld_nj)
rowif "clouds: 220 captures of a device whose signal moves 6 and 10 dB in the hour: a cloud on every poll, never two, one id for all 220, no step over 30 addresses ($CLD_R33)" [ "$CLD_R33" = '{"errors":0,"runs":[[6,0,1,true],[10,0,1,true]]}' ]

# ---- R28b what a cloud of mixed rhythm says: the sheet's lead, its Rhythm row, the observation and the export hedge ('possibly one or more
# nearby devices'), and the cadence that is shown is the fitted period, not a gap between bursts of two devices
CLD_EV28='(async()=>{const W=STARCHORUS.wait,o={};STARCHORUS.setToggles({observations:true});await W(300);const c=STARCHORUS.clouds()[0];o.cl=[STARCHORUS.clouds().length,c.cadenceS,c.rhythm<0.6];
STARCHORUS.select(c.id);await W(300);const ob=document.querySelector("#detail-body .obsnote");o.lead=ob?ob.textContent.split(" An estimate")[0]:null;
o.row=[...document.querySelectorAll("#detail-body tr")].filter(r=>r.textContent.startsWith("Rhythm")).map(r=>r.textContent)[0];
o.est=JSON.parse(STARCHORUS.exportText("json")).clouds[0].estimate;
const d=await (await fetch("starchorus.json",{cache:"no-store"})).json();for(let i=0;i<3;i++){d.generated+=30;STARCHORUS.load(d,"cld-obs");await W(100);}
o.obs=STARCHORUS.observations().map(x=>x.text).filter(t=>t.includes("randomised addresses in"));o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runseq "$CLD_T/mixdoc-same.json" "$CLD_T/mixed" --eval "$CLD_EV28" >/dev/null 2>&1
CLD_R28=$(evalv "$CLD_T/mixed.json" 1 | cld_nj)
rowif "clouds: a cloud of mixed rhythm hedges: sheet 'Possibly one or more nearby devices ... no one rhythm', Rhythm row 'no one rhythm', observation and export 'possibly one or more nearby devices' ($CLD_R28)" [ "$CLD_R28" = '{"cl":[1,48,true],"errors":0,"est":"possibly one or more nearby devices changing their address; not a device count","lead":"Possibly one or more nearby devices changing their address: the same signal, heard in bursts that keep no one rhythm.","obs":["612 randomised addresses in 1 cloud: possibly one or more nearby devices changing their address"],"row":"Rhythmno one rhythm · 153 bursts"}' ]

# ---- R20 a second device next to an established cloud (page clock held): the phone (every 47 s) has had its cloud for an hour when a
# laptop (every 61 s, same signal) starts; ten captures 300 s apart. The phone's cloud keeps its id and all its addresses, the laptop's
# cloud appears once its rhythm stands clear (16 bursts) with an id of its own and never takes the phone's, and the last capture loaded
# fresh gives the very same member sets (what a page that has run for an hour shows is what a new page shows). The old rule let the
# established cloud swallow the newcomer ("kept" with 411 addresses) while a fresh load showed none.
python3 - "$CLD_T" <<'PY'
import json, sys
G0, W = 1789300000, 3600
def device(tag, period, phase, until):
    un, k, t = [], 0, phase
    while t < until:
        at = t + ((k * 7) % 3) - 1
        for j, r in enumerate((-30, -29, -31, -30)):
            un.append({"mac": "da:c6:%s:%02x:%02x:%02x" % (tag, k >> 8, k & 255, j), "rssi": r, "last_seen": G0 + at + (1 if j >= 2 else 0), "randomized": True})
        k, t = k + 1, t + period
    return un
A, B = device("a1", 47, 3, 6100), device("b1", 61, 3400, 6100)
def doc(t):
    g = G0 + t
    return {"generated": g, "center": {"label": "r20", "max_age": W, "interval": 30}, "source": "recon-db", "aps": [], "unassociated": [x for x in A + B if g - W < x["last_seen"] <= g]}
json.dump([doc(t) for t in range(3300, 6001, 300)], open(sys.argv[1] + "/r20-caps.json", "w"), separators=(",", ":"))
PY
CLD_EV20='(async()=>{const D='"$(cat "$CLD_T/r20-caps.json" 2>/dev/null || echo '[]')"',T=7000000,o={rows:[]};const at=async(ms)=>{STARCHORUS.setFixedTime(ms);await STARCHORUS.wait(60);};
await STARCHORUS.wait(500);for(let j=0;j<D.length;j++){await at(T+1000*(j+1));STARCHORUS.load(D[j],"cld-r20",{mode:"live"});
o.rows.push(STARCHORUS.clouds().map(c=>[c.id.slice(3,7),c.members.filter(m=>m.startsWith("da:c6:a1")).length,c.members.filter(m=>m.startsWith("da:c6:b1")).length,c.kept?1:0]));}
const sg=()=>JSON.stringify(STARCHORUS.clouds().map(c=>c.members.slice().sort().join(",")).sort()),run=sg();STARCHORUS.load(D[D.length-1],"cld-r20-fresh");o.same=run===sg();o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "$CLD_Q&theme=wargames" "$CLD_T/r20" --width 1440 --height 900 --wait 2 --fps 0 --eval-timeout 90 --eval "$CLD_EV20" >/dev/null 2>&1
cld_v20() { evalv "$1" 1 | python3 -c '
import json, sys
try: o = json.loads(sys.stdin.read())
except ValueError: print("no result"); sys.exit()
R, why = o["rows"], []
phone = [r[0] for r in R if r]
ids = {c[0] for r in R for c in r[:1]}
if len(R) != 10 or any(not r or r[0][1] < 280 or r[0][3] for r in R) or len({r[0][0] for r in R}) != 1: why.append("the phone cloud %s" % [r[:1] for r in R])
if [len(r) for r in R] != [1] * 4 + [2] * 6 or any(r[1][0] == r[0][0] or r[1][1] or r[1][2] < 60 for r in R if len(r) > 1): why.append("the laptop cloud %s" % [r[1:] for r in R])
if any(r[0][2] > 40 for r in R): why.append("too much of the laptop in the phone cloud")
if o["same"] is not True or o["errors"] != 0: why.append("fresh %s errors %s" % (o["same"], o["errors"]))
print("; ".join(why) or "ok")' 2>/dev/null; }
CLD_R20=$(cld_v20 "$CLD_T/r20.json")
rowif "clouds: a second device next to an established cloud: the phone's cloud keeps its id and its 280+ addresses over ten captures, the laptop gets a cloud of its own from the 5th (16 bursts) and never the phone's id, a fresh load of the last capture gives the same member sets ($CLD_R20)" [ "$CLD_R20" = ok ]
[ "$CLD_R20" = ok ] || echo "    rows: $(evalv "$CLD_T/r20.json" 1 | cut -c1-500)"

# ---- R21 a replay is a view (WarGames): the cloud is pinned, replay(0) shows the empty first capture (the cloud fades out and is left
# alone), Back to live brings it back with its id, its series and its pin (the old page deleted it and made a new one: another id, one
# sample, no pin)
python3 - "$CLD_T" <<'PY'
import json, sys
D = json.load(open(sys.argv[1] + "/r5-caps.json"))
empty = {"generated": D[0]["generated"] - 30, "center": D[0]["center"], "source": "recon-db", "unassociated": [], "aps": D[0]["aps"]}
json.dump([empty] + D[:12], open(sys.argv[1] + "/r21-caps.json", "w"), separators=(",", ":"))
PY
CLD_EV21='(async()=>{const D='"$(cat "$CLD_T/r21-caps.json" 2>/dev/null || echo '[]')"',T=7000000,o={};const at=async(ms)=>{STARCHORUS.setFixedTime(ms);await STARCHORUS.wait(60);};
await STARCHORUS.wait(500);for(let j=0;j<D.length;j++){await at(T+1000*(j+1));STARCHORUS.load(D[j],"cld-r21",{mode:"live"});}await STARCHORUS.wait(300);
const c=STARCHORUS.clouds()[0],id=c.id;STARCHORUS.pin(id,true);o.before=[c.n,STARCHORUS.hist(id).n,STARCHORUS.clouds()[0].pinned];
STARCHORUS.setFixedTime(null);const r=STARCHORUS.replay(0);o.replay=[r.active,r.index,STARCHORUS.clouds().length];await STARCHORUS.wait(3000);o.during=[STARCHORUS.clouds().length,STARCHORUS.nodes("cloud").length];
STARCHORUS.replayExit();await STARCHORUS.wait(800);const k=STARCHORUS.clouds()[0];o.after=k?[k.id===id,k.n,STARCHORUS.hist(k.id).n,k.pinned]:null;o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "$CLD_Q&theme=wargames" "$CLD_T/r21" --width 1440 --height 900 --wait 2 --fps 0 --eval-timeout 90 --eval "$CLD_EV21" >/dev/null 2>&1
CLD_R21=$(evalv "$CLD_T/r21.json" 1 | cld_nj)
rowif "clouds: a replay is a view: replay(0) on the empty first capture shows no cloud, Back to live brings the same cloud back (id, 12 samples, pin) ($CLD_R21)" [ "$CLD_R21" = '{"after":[true,84,12,true],"before":[84,12,true],"during":[0,0],"errors":0,"replay":[true,0,0]}' ]

# ---- R22 the baseline diff and a cloud: 10 stations are baselined, then the cloud forms and takes them in; they are still heard, so none is
# gone (no ghost, none new) -- the old page reported all 10 gone because a cloud member counted as not present
python3 - "$CLD_T" <<'PY'
import json, sys
G = 1789300000
def doc(n, t0):
    un = [{"mac": "02:00:5e:e0:00:%02x" % i, "rssi": -40, "randomized": True, "last_seen": G - 1000 + t0 + 20 * i} for i in range(n)]
    return {"generated": G, "center": {"label": "r22"}, "source": "recon-db", "channels": [{"freq": 2437, "last_heard": G - 5}], "unassociated": un,
            "aps": [{"bssid": "02:00:5e:e1:00:01", "ssid": "edge", "channel": 6, "band": "2.4GHz", "freq": 2437, "rssi": -50, "security": "WPA2", "clients": []}]}
json.dump([doc(10, 600), doc(28, 100)], open(sys.argv[1] + "/r22-caps.json", "w"), separators=(",", ":"))
PY
CLD_EV22='(async()=>{const D='"$(cat "$CLD_T/r22-caps.json" 2>/dev/null || echo '[]')"',o={};await STARCHORUS.wait(500);STARCHORUS.load(D[0],"cld-r22");o.c1=STARCHORUS.clouds().length;STARCHORUS.setBaseline();STARCHORUS.setToggles({baselineDiff:true});
STARCHORUS.load(D[1],"cld-r22");const b=STARCHORUS.baseline();o.c2=[STARCHORUS.clouds().length,STARCHORUS.clouds()[0].n];o.base=[b.sizeCl,b.newCl,b.goneCl,b.ghostsCl].join();o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq demo "$CLD_Q" "$CLD_T/r22" --wait 2 --fps 0 --eval "$CLD_EV22" >/dev/null 2>&1
CLD_R22=$(evalv "$CLD_T/r22.json" 1 | cld_nj)
rowif "clouds: baseline diff: 10 baselined stations taken into a cloud are not gone, no ghost, none new ($CLD_R22)" [ "$CLD_R22" = '{"base":"10,0,0,0","c1":0,"c2":[1,28],"errors":0}' ]

# ---- R23 this device's own transmitter among the members is no cloud member: cloud, member list, export and counts agree (120)
CLD_EV23='(async()=>{const d=await (await fetch("starchorus.json",{cache:"no-store"})).json(),o={};d.center.own_bssids=["da:c1:00:a1:05:01"];STARCHORUS.load(d,"cld-own");
const c=STARCHORUS.clouds()[0],s=STARCHORUS.stats(),J=JSON.parse(STARCHORUS.exportText("json"));o.cloud=[c.n,c.core,c.members.includes("da:c1:00:a1:05:01")];o.stats=[s.inClouds,s.clouds];
o.export=[J.clouds[0].addresses,J.stations.filter(x=>x.cloud).length,J.station_counts.in_clouds];o.own=STARCHORUS.node("da:c1:00:a1:05:01").cloud;o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runseq "$CLD_FX" "$CLD_T/own" --eval "$CLD_EV23" >/dev/null 2>&1
CLD_R23=$(evalv "$CLD_T/own.json" 1 | cld_nj)
CLD_R23J=$(jq -c "$(cat "$CLD_T/jqlib.jq") .center.own_bssids = [\"da:c1:00:a1:05:01\"] | clouds | [.rnd, (.clouds | length), .clouds[0].n]" "$CLD_FX" 2>/dev/null)
rowif "clouds: an own transmitter among the members is left out: cloud 120 (core 119), export 120 = 120 = 120, the address single; the Overview's rule 120 ($CLD_R23; $CLD_R23J)" [ "$CLD_R23/$CLD_R23J" = '{"cloud":[120,119,false],"errors":0,"export":[120,120,120],"own":null,"stats":[120,1]}/[139,1,120]' ]

# ---- R24 what the numbers beside the cloud say: the Inventory's stations chip counts the hidden randomised addresses too (162 in all three
# modes, beside '140 randomised · 121 in 1 cloud'); the legend's sub-label gives the members (' · 121 in 1 cloud'); the CSV has a trailing cloud
# column with the cloud id on the 121 member rows and nothing else; the observation hedges ('probably one nearby device' for one cloud,
# 'possibly one or more nearby devices' for two); a kept cloud's sheet says its rhythm is no longer clear (R5's run, below)
CLD_EV24='(async()=>{const W=STARCHORUS.wait,E=i=>document.getElementById(i),o={};STARCHORUS.setToggles({inventory:true,observations:true});await W(500);o.inv=[];
for(const m of ["cloud","show","hide"]){STARCHORUS.setToggles({random:m});await W(500);const t=E("inv-body").textContent,a=t.match(/(\d+) stations \(count only\)/),b=t.match(/(\d+) randomised( · \d+ in \d+ clouds?)?/);o.inv.push(m+": "+(a?a[1]:"-")+" | "+(b?b[0]:"-"));}
STARCHORUS.setToggles({random:"cloud"});await W(300);o.legend=E("leg-random-cl").textContent;
const csv=STARCHORUS.exportText("csv").trim().split("\n"),head=csv[0].split(","),rows=csv.slice(1,-1),idc=rows.map(r=>r.split(",").pop()).filter(Boolean);
o.csv=[head[head.length-1],[...new Set(rows.map(r=>r.split(",").length))].join(),rows.length,idc.length,[...new Set(idc)].length,idc[0].slice(0,3)];
const d=await (await fetch("starchorus.json",{cache:"no-store"})).json();for(let i=0;i<3;i++){d.generated+=30;STARCHORUS.load(d,"cld-obs");await W(100);}
o.obs=STARCHORUS.observations().map(x=>x.text).filter(t=>t.includes("randomised addresses in"));o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runseq "$CLD_FX" "$CLD_T/nums" --eval "$CLD_EV24" >/dev/null 2>&1
CLD_R24=$(evalv "$CLD_T/nums.json" 1 | cld_nj)
CLD_EV24B='(async()=>{const W=STARCHORUS.wait,o={};STARCHORUS.setToggles({observations:true});const d=await (await fetch("starchorus.json",{cache:"no-store"})).json();for(let i=0;i<3;i++){d.generated+=30;STARCHORUS.load(d,"cld-obs");await W(100);}
o.obs=STARCHORUS.observations().map(x=>x.text).filter(t=>t.includes("randomised addresses in"));o.leg=document.getElementById("leg-random-cl").textContent;o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runseq "$CLD_T/twolevels.json" "$CLD_T/nums2" --eval "$CLD_EV24B" >/dev/null 2>&1
CLD_R24B=$(evalv "$CLD_T/nums2.json" 1 | cld_nj)
rowif "clouds: the numbers beside a cloud: stations chip 162 in every mode, legend ' · 121 in 1 cloud' (' · 48 in 2 clouds'), CSV cloud column on 121 rows, observation texts for 1 and 2 clouds ($CLD_R24; $CLD_R24B)" [ "$CLD_R24/$CLD_R24B" = '{"csv":["cloud","14",168,121,1,"rc:"],"errors":0,"inv":["cloud: 162 | 140 randomised · 121 in 1 cloud","show: 162 | 140 randomised · 121 in 1 cloud","hide: 162 | 140 randomised · 121 in 1 cloud"],"legend":" · 121 in 1 cloud","obs":["121 randomised addresses in 1 cloud: probably one nearby device changing its address"]}/{"errors":0,"leg":" · 48 in 2 clouds","obs":["48 randomised addresses in 2 clouds: possibly one or more nearby devices changing their address"]}' ]

# ---- R25 the probes bite: one-line copies of the page (served to headless Chrome on 127.0.0.1 only), each run on the scene that its rule
# keeps right; the mutated answer is the predicted one (the unmutated page is the control: R3 and R5 to R24 themselves). Each target
# line exists exactly once and each sed changes exactly that line. A display copy whose clouds answer nothing must turn R13 red.
#   dating guard removed -> a capture without `generated` gives a cloud (28) · joinDb 0 -> no loose address joins (120) · chance test removed ->
#   the crowds are full of clouds · chance level of the bands beside the window removed -> the dense crowd is one cloud of 549 · one stream
#   per band -> the laptop is lost to the phone's cloud · bands not merged -> three clouds for one device · merge by interleaved bursts
#   removed -> the drifting phone is two clouds · pairs removed -> the wandering device has 148 of its 264 · chains removed -> the dense band of three devices has none · burst cap 240 -> six hours of
#   one device are the newest 240 bursts · chance partners kept -> the phone and laptop of 47 and 73 s are 348 and 132 · mixed hedge removed
#   -> the sheet of two devices of one period says 'Probably one nearby device' · keep rule removed -> the cloud is gone at the 10th burst ·
#   replay guard removed -> Back to live makes a new cloud · baseline fix removed -> 10 stations gone · own filter removed -> 121
cld_sizes() { evalv "$1" 1 | python3 -c 'import json,sys;print(",".join(str(n) for n in sorted(json.loads(sys.stdin.read()), reverse=True)) or "none")' 2>/dev/null; }
CLD_EVSZ='JSON.stringify(STARCHORUS.clouds().map(c=>c.n))'
cld_probe() {   # cld_probe SCENARIO -> the signature of the page $H on it
  case $1 in
    fx) runseq "$CLD_FX" "$CLD_T/mut" --eval "$CLD_EVM" >/dev/null 2>&1; _cp=$(cld_m3 "$CLD_T/mut.json"); printf '%s\n' "${_cp#*|}" ;;
    crowd|two|wide|dense|drift|three|long|pair|wander) runseq "$CLD_T/mixdoc-$1.json" "$CLD_T/mut" --eval "$CLD_EVSZ" >/dev/null 2>&1; cld_sizes "$CLD_T/mut.json" ;;
    nogen) runseq "$CLD_T/nogen.json" "$CLD_T/mut" --eval "$CLD_EVSZ" >/dev/null 2>&1; cld_sizes "$CLD_T/mut.json" ;;
    r5) runq demo "$CLD_Q&theme=wargames" "$CLD_T/mut" --width 1440 --height 900 --wait 2 --fps 0 --eval-timeout 90 --eval "$CLD_EV5" >/dev/null 2>&1
        evalv "$CLD_T/mut.json" 1 | python3 -c 'import json,sys;o=json.loads(sys.stdin.read());print("n[23]=%s kept[23]=%s" % (o["n"][23], o["kept"][23]))' 2>/dev/null ;;
    sheet) runseq "$CLD_T/mixdoc-same.json" "$CLD_T/mut" --eval "$CLD_EV28" >/dev/null 2>&1
        evalv "$CLD_T/mut.json" 1 | python3 -c 'import json,sys;print(json.loads(sys.stdin.read())["lead"][:24])' 2>/dev/null ;;
    r21) runq demo "$CLD_Q&theme=wargames" "$CLD_T/mut" --width 1440 --height 900 --wait 2 --fps 0 --eval-timeout 90 --eval "$CLD_EV21" >/dev/null 2>&1
        evalv "$CLD_T/mut.json" 1 | python3 -c 'import json,sys;print(json.dumps(json.loads(sys.stdin.read())["after"],separators=(",",":")))' 2>/dev/null ;;
    r22) runq demo "$CLD_Q" "$CLD_T/mut" --wait 2 --fps 0 --eval "$CLD_EV22" >/dev/null 2>&1
        evalv "$CLD_T/mut.json" 1 | python3 -c 'import json,sys;print(json.loads(sys.stdin.read())["base"])' 2>/dev/null ;;
    own) runseq "$CLD_FX" "$CLD_T/mut" --eval "$CLD_EV23" >/dev/null 2>&1
        evalv "$CLD_T/mut.json" 1 | python3 -c 'import json,sys;print(json.dumps(json.loads(sys.stdin.read())["cloud"],separators=(",",":")))' 2>/dev/null ;;
  esac
}
CLD_HKEEP=$H; CLD_PB=""
while IFS='|' read -r CLD_MN CLD_MA CLD_MS CLD_MSC CLD_MW; do
  [ -n "$CLD_MN" ] || continue
  CLD_MC="$CLD_T/mut.html"; sed "$CLD_MS" "$CLD_HKEEP" > "$CLD_MC"
  CLD_ME=$(grep -cF -- "$CLD_MA" "$CLD_HKEEP"); CLD_MD=$(diff "$CLD_HKEEP" "$CLD_MC" | grep -c '^<')
  H=$CLD_MC; CLD_MG=$(cld_probe "$CLD_MSC"); H=$CLD_HKEEP
  [ "$CLD_ME/$CLD_MD/$CLD_MG" = "1/1/$CLD_MW" ] || CLD_PB="$CLD_PB [$CLD_MN: anchor $CLD_ME, changed $CLD_MD, got $CLD_MG, want $CLD_MW]"
done <<'MUT'
dating guard removed| && c.freshTier != null && !eventSkip(c)) E.push(|s/ \&\& c\.freshTier != null \&\& !eventSkip(c)) E\.push(/ \&\& !eventSkip(c)) E.push(/|nogen|28
joinDb 0|joinDb: 6,|s/joinDb: 6,/joinDb: 0,/|fx|120
chance test removed| && h.p.length >= CLOUD.ratio * Math.max(1, h.side) && z2 >= CLOUD.zK * CLOUD.zK) ok.push(o);|s/ \&\& h\.p\.length >= CLOUD\.ratio \* Math\.max(1, h\.side) \&\& z2 >= CLOUD\.zK \* CLOUD\.zK) ok\.push(o);/) ok.push(o);/|crowd|520,76
chance level of the bands beside the window removed|side: (a + b) / 2 };|s/side: (a + b) \/ 2 };/side: 0 };/|dense|549
one stream per band|streamMax: 5,|s/streamMax: 5,/streamMax: 1,/|two|300
bands not merged|mergeDb: 12,|s/mergeDb: 12,/mergeDb: -1,/|wide|77,77,77
merge by interleaved bursts removed|mergeShare: 0.8,|s/mergeShare: 0\.8,/mergeShare: 2,/|drift|168,140
chains removed|for (let pass = 0; pass < CLOUD.streamMax && R.length >= CLOUD.minBursts; pass++) {   // a band too dense for pairs|s/\(for (let pass = 0; pass < \)CLOUD\.streamMax\( \&\& R\.length >= CLOUD\.minBursts; pass++) {   \/\/ a band too dense for pairs\)/\10\2/|three|none
burst cap 240|burstCap: 1500,|s/burstCap: 1500,/burstCap: 240,/|long|960
chance partners kept|if (deg.get(i) === 1 && deg.get(j) >= 3) drop.add(i);|s/if (deg\.get(i) === 1 \&\& deg\.get(j) >= 3) drop\.add(i); if (deg\.get(j) === 1 \&\& deg\.get(i) >= 3) drop\.add(j);//|pair|348,132
mixed hedge removed|function cloudMixed(k) { return !k.kept && k.rhythm < CLOUD.mixedShare; }|s/return !k\.kept \&\& k\.rhythm < CLOUD\.mixedShare;/return false;/|sheet|Probably one nearby devi
pairs removed|ratio: 2,|s/ratio: 2,/ratio: 99,/|wander|148
keep rule removed|if (M.length < CLOUD.keepAddr) return;|s/if (M\.length < CLOUD\.keepAddr) return;/return;/|r5|n[23]=0 kept[23]=None
replay guard removed|k.alpha < 0.02 && !S.replay) { S.clouds.delete(|s/k\.alpha < 0\.02 \&\& !S\.replay) { S\.clouds\.delete(/k.alpha < 0.02) { S.clouds.delete(/|r21|[false,84,1,false]
baseline fix removed|if (n.target === 1 && n.cloud != null && !eventSkip(n)) { curCl.add(n.id); return; } |s/if (n\.target === 1 \&\& n\.cloud != null \&\& !eventSkip(n)) { curCl\.add(n\.id); return; } //|r22|10,0,10,10
own filter removed| && !eventSkip(c)) E.push(|s/ \&\& !eventSkip(c)) E\.push(/) E.push(/|own|[121,120,true]
MUT
CLD_DM="$CLD_T/display-mut.sh"
# shellcheck disable=SC2016   # jq text, nothing for the shell to expand
sed 's/^def clouds: rndfree as \$R$/def clouds: {rnd: 0, clouds: []}; def _cl0: rndfree as $R/' starchorus-display.sh > "$CLD_DM"
# shellcheck disable=SC2016
CLD_DE=$(grep -c '^def clouds: rndfree as \$R$' starchorus-display.sh); CLD_DD=$(diff starchorus-display.sh "$CLD_DM" | grep -c '^<')
CLD_DR=$(cld_dsp "$CLD_DM" summary "$CLD_FX" | grep -c '^Clients  160 free (139 random, 1 cloud) · 2 associated$')
[ "$CLD_DE/$CLD_DD/$CLD_DR" = "1/1/0" ] || CLD_PB="$CLD_PB [display: anchor $CLD_DE, changed $CLD_DD, still green $CLD_DR]"
rowif "clouds: probes bite: dating guard off (28 clouds out of an undated capture), joinDb 0 (120), chance test off (clouds of 520 and 76 in the crowd), sideband level off (549 in the dense crowd), pairs off (148 of the wandering device's 264), one stream per band (300), bands not merged (77,77,77), interleave merge off (168,140), chains off (none), burst cap 240 (960), chance partners kept (348,132), mixed hedge off ('Probably one nearby devi'), keep rule off (gone at the 10th burst), replay guard off (a new cloud), baseline fix off (10 gone), own filter off (121); an empty Overview rule turns R13 red${CLD_PB:+:$CLD_PB}" [ -z "$CLD_PB" ]
