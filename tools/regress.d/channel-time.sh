# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/channel-time.sh -- channel, time, replay.
#   channel view (spectrum, max/peak hold, DFS, beacon airtime estimate) · air quality · signal over time + threshold ring ·
#   recording and replay (a view: no engine advances) + channel x time waterfall · keys, buttons, D15 with the drawers
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only CHT_* globals are set.
#
# The recorder, the long history and the peak hold are memory only (nothing is stored, P8). The airtime number is an ESTIMATED lower bound and is checked
# against a Python recount of the same formula, never against a measurement.

CHT_Q="?poll=0&spin=0&intro=0&debug=1"
cht_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }

# ---- channel model and air quality against Python recounts
CHT_BEACON=$(python3 -c 'import json;print(json.dumps([int(n*(pre+200*8/mb)/(102.4*10)*10+0.5+1e-9) for band,pre,mb in (("2.4",192,1),("5",20,6)) for n in (1,2,3,7,13)]).replace(" ",""))')
CHT_DFS=$(python3 -c 'import json;print(json.dumps(sorted(set(range(52,65,4))|set(range(100,145,4)))).replace(" ",""))')
CHT_EVC='(async()=>{
await STARCHORUS.wait(800);const o={};
const ap=(n,ch,rssi,extra)=>Object.assign({bssid:"02:00:00:00:0b:"+String(n).padStart(2,"0"),ssid:"c"+n,band:ch>14?"5":"2.4",channel:ch,rssi,security:"WPA2"},extra||{});
const doc=(g,aps,cl)=>({source:"recon-db",generated:g,aps:aps.map((a,i)=>i===0&&cl?Object.assign({},a,{clients:cl}):a),unassociated:[{mac:"3c:22:fb:10:20:99",rssi:-70}]});
// beacon airtime: n APs on one channel, per band
const bp=[];for(const [ch,band] of [[6,"2.4"],[36,"5"]])for(const n of [1,2,3,7,13]){const a=[];for(let i=0;i<n;i++)a.push(ap(i+1,ch,-60));STARCHORUS.load(doc(100+n+(ch>14?50:0),a),"bp"+ch+"_"+n);bp.push(STARCHORUS.channelView().bands[band].filter(r=>r.ch===ch)[0].beaconPct);}
o.beacon=JSON.stringify(bp.map(v=>Math.round(v*10)));
// DFS flags over the 5 GHz channels 36..165
const all=[];for(let c=36;c<=165;c+=4)all.push(c);const a5=all.map((c,i)=>ap(i+1,c,-70));STARCHORUS.load(doc(300,a5),"dfs");
o.dfs=JSON.stringify(STARCHORUS.channelView().bands["5"].filter(r=>r.dfs).map(r=>r.ch));
// max signal, co-/adjacent-channel, probe activity (stations via APs on the channel), no identity in the model
STARCHORUS.load(doc(400,[ap(1,6,-70),ap(2,6,-55),ap(3,8,-60),ap(4,1,-80),ap(5,11,-65)],[{mac:"3c:22:fb:10:20:01",rssi:-60},{mac:"3c:22:fb:10:20:02",rssi:-62}]),"co");
const r6=STARCHORUS.channelView().bands["2.4"].filter(r=>r.ch===6)[0];o.r6=[r6.count,r6.maxDbm,r6.co,r6.adjacent,r6.probeActivity,r6.assumed,r6.widthMax].join();
o.noMac=!/[0-9a-f]{2}(:[0-9a-f]{2}){5}/i.test(JSON.stringify(STARCHORUS.channelView())+JSON.stringify(STARCHORUS.airQuality()));
STARCHORUS.setChannelMode("spectrum");
const ht=STARCHORUS.hoverChannel("2.4",6);o.hover=[/max -55 dBm/.test(ht),/beacons ≥ 3.5 % of airtime \(estimate: 102.4 ms, 200 B at 1 Mbit\/s\)/.test(ht),/probe activity heard on channel: 2 stations/.test(ht)].join();
// peak hold: a strong AP leaves, the held peak stays 12 captures and then follows the current maximum
const seq=[];for(let i=0;i<15;i++){const a=i===0?[ap(1,6,-40),ap(2,6,-70)]:[ap(2,6,-70)];STARCHORUS.load(doc(500+5*i,a),"peak");const r=STARCHORUS.channelView().bands["2.4"].filter(x=>x.ch===6)[0];seq.push(r.peakDbm);}
o.peak=seq.join(" ");
// air quality: words are the neutral five, the levels agree with crowding, the quietest of the usual set is offered
STARCHORUS.load(doc(700,[ap(1,1,-50),ap(2,1,-55),ap(3,6,-60),ap(4,6,-52),ap(5,6,-70),ap(6,36,-60)]),"air");
const aq=STARCHORUS.airQuality();o.air=[aq.level===STARCHORUS.stats().crowding,["quiet","light","moderate","busy","very busy"][aq.level-1]===aq.word,aq.bands["2.4"].quietest.ch,aq.bands["2.4"].top[0].ch,aq.bands["6"]===null,aq.bands["5"].aps].join();
o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$CHT_Q" "out/$P-cht-chan" --wait 2 --fps 0 --ready --eval-timeout 90 --eval "$CHT_EVC" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CHT_C=$(evalv "out/$P-cht-chan.json" 1 | cht_nj); CHT_CE=$(evalv "out/$P-cht-chan.json" 2)
CHT_CW=$(printf '%s' "{\"air\":\"true,true,11,6,true,1\",\"beacon\":\"$CHT_BEACON\",\"dfs\":\"$CHT_DFS\",\"errors\":0,\"hover\":\"true,true,true\",\"noMac\":true,\"peak\":\"-40 -40 -40 -40 -40 -40 -40 -40 -40 -40 -40 -40 -40 -70 -70\",\"r6\":\"2,-55,2,1,2,true,20\"}" | cht_nj)
if [ "$CHT_C" = "$CHT_CW" ] && [ "$CHT_CE" = 0 ]; then
  row "channel model: beacon airtime = Python recount (1..13 APs, 2.4 and 5 GHz), DFS table, max/co/adjacent/probe activity, no identity, peak hold holds 12 captures, air quality words = crowding, quietest of the usual set" PASS
else
  row "channel model (err ${CHT_CE:-?})" FAIL
  echo "    got:  $(printf '%s' "$CHT_C" | cut -c1-700)"; echo "    want: $CHT_CW"
fi

# ---- signal over time (min/max/mean per curve, gaps, ESS curves, 3 scales) against a Python recount, and the operator threshold
CHT_PYT=$(python3 - <<'PY'
import json, math
N = 130
def r1(i): return -80 + (i % 40)
def r2(i): return None if 49 <= i <= 58 else -70
out = {}
for sc, w in (("1m", 12), ("10m", 120), ("1h", 720)):
    rows = []
    for name, f in (("01", r1), ("02", r2)):
        s = [f(i) for i in range(N)][-w:]
        v = [x for x in s if x is not None]
        rows.append([name, len(v), min(v), max(v), (lambda m: int(m) if m == int(m) else m)(math.floor(sum(v) / len(v) * 10 + 0.5) / 10)])
    out[sc] = rows
print(json.dumps(out, separators=(",", ":"), sort_keys=True))
PY
)
CHT_EVT='(async()=>{
await STARCHORUS.wait(800);const o={};
const id=(n)=>"02:00:00:00:0c:"+String(n).padStart(2,"0");
const ap=(n,ssid,rssi)=>({bssid:id(n),ssid,band:"2.4",channel:6,rssi,security:"WPA2"});
for(let i=0;i<130;i++){const aps=[ap(1,"ess",-80+(i%40)),ap(3,"other",-50)];if(!(i>=49&&i<=58))aps.push(ap(2,"ess",-70));STARCHORUS.load({source:"recon-db",generated:2000+5*i,aps,unassociated:[]},"ts");}
STARCHORUS.select(id(1));
const tab={};for(const sc of ["10m","1h","1m"])tab[sc]=STARCHORUS.timeSeries(sc).curves.map(c=>[c.id.slice(-2),c.n,c.min,c.max,c.mean]).sort();
o.tab=JSON.stringify(tab);
const t1=STARCHORUS.timeSeries("1h");o.meta=[t1.window,t1.limited,t1.intervalS,t1.curves.length,STARCHORUS.timeSeries("1m").window].join();
o.gap=STARCHORUS.timeSeries("10m").curves.filter(c=>c.id.slice(-2)==="02")[0].samples.filter(v=>v===null).length;
STARCHORUS.deselect();o.top3=STARCHORUS.timeSeries("1m").curves.map(c=>c.id.slice(-2)).join();
STARCHORUS.pin(id(3),true);o.pinned=STARCHORUS.timeSeries("1m").curves.map(c=>c.id.slice(-2)).join();STARCHORUS.pin(id(3),false);
// threshold: clamp, clear, count at or above, drawer input survives a re-render
o.thr=[STARCHORUS.setThreshold(-60),STARCHORUS.setThreshold(-5),STARCHORUS.setThreshold(-140),STARCHORUS.setThreshold("x"),STARCHORUS.setThreshold(null),STARCHORUS.setThreshold(-60)].join();
o.above=STARCHORUS.timeSeries("1m").above;
STARCHORUS.openDrawer("time");await STARCHORUS.wait(150);const ti=document.getElementById("thr-in");ti.focus();ti.value="-7";
const d0={source:"recon-db",generated:9000,aps:[ap(1,"ess",-60),ap(3,"other",-50)],unassociated:[]};STARCHORUS.load(d0,"ts");await STARCHORUS.wait(100);
const ti2=document.getElementById("thr-in");o.keep=[ti2.value,document.activeElement===ti2].join();
ti2.value="-66";ti2.dispatchEvent(new KeyboardEvent("keydown",{key:"Enter",bubbles:true}));o.enter=STARCHORUS.stats().threshold;
document.getElementById("thr-clear").click();o.cleared=STARCHORUS.stats().threshold;
o.tt=/Signal over time/i.test(document.getElementById("time-body").innerText)&&!!document.getElementById("time-cv");
STARCHORUS.openDrawer(null);
o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$CHT_Q" "out/$P-cht-time" --wait 2 --fps 0 --ready --eval-timeout 120 --eval "$CHT_EVT" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CHT_T=$(evalv "out/$P-cht-time.json" 1 | cht_nj); CHT_TE=$(evalv "out/$P-cht-time.json" 2)
CHT_TW=$(CHT_PYT="$CHT_PYT" python3 -c 'import json,os;print(json.dumps({"above":1,"cleared":None,"enter":-66,"errors":0,"gap":10,"keep":"-7,true","meta":"720,false,5,2,12","pinned":"03","tab":os.environ["CHT_PYT"],"thr":"-60,-20,-100,,,-60","top3":"03,02,01","tt":True},sort_keys=True,separators=(",",":"),ensure_ascii=False))')
if [ "$CHT_T" = "$CHT_TW" ] && [ "$CHT_TE" = 0 ]; then
  row "signal over time: min/max/mean per curve = Python recount (1 min/10 min/1 h, a gap stays a gap), ESS curves, pinned, top 3; threshold clamps, counts, input survives a poll re-render" PASS
else
  row "signal over time (err ${CHT_TE:-?})" FAIL
  echo "    got:  $(printf '%s' "$CHT_T" | cut -c1-700)"; echo "    want: $CHT_TW"
fi

# ---- recording and replay. A replay is a VIEW: nothing that keeps history advances; polls that arrive meanwhile are recorded and shown after "Back to live" (U4)
CHT_BIGMAX=$(python3 -c 'print((8*1024*1024)//(1500+600*420))')
CHT_EVR='(async()=>{
await STARCHORUS.wait(800);const o={};
const id=(n)=>"02:00:00:00:0d:"+String(n).padStart(2,"0");
const ap=(n,ch,rssi,cl)=>({bssid:id(n),ssid:"r"+n,band:ch>14?"5":"2.4",channel:ch,rssi,security:"WPA2",clients:cl||[]});
const mk=(i)=>({source:"recon-db",generated:3000+5*i,aps:[ap(1,6,-60+i,[{mac:"3c:22:fb:10:20:01",rssi:-55}]),ap(2,i>=7?1:11,-70),ap(3,36,-55),ap(4,52,-65)].concat(i>=5?[ap(5,1,-50)]:[]),unassociated:[{mac:"3c:22:fb:10:20:77",rssi:-70}]});
const live=(d)=>STARCHORUS.load(d,"rp",{mode:"live"});
for(let i=0;i<10;i++)live(mk(i));
const rc=STARCHORUS.recording();o.count=rc.count;o.aps=rc.snapshots.map(s=>s.aps).join("");o.gens=rc.snapshots[0].generated+"-"+rc.snapshots[9].generated;o.noMac=!/[0-9a-f]{2}(:[0-9a-f]{2}){5}/i.test(JSON.stringify(rc));
const I=STARCHORUS._internals.S,eng=()=>JSON.stringify([I.ev,I.captureSeq,Array.from(I.chg.entries()),I.sky.seq,I.sky.resets,Array.from(I.sky.ref.entries()),Array.from(I.sky.t0||[]),I.sky.dev,Array.from(I.long.entries()).map(([k,h])=>[k,h.n,h.head,h.lastSeq,Array.from(h.buf).join(" ")]),Array.from(I.chanPeak.entries()),Array.from(I.hist.entries()).map(([k,h])=>[k,h.n,h.head,h.lastSeq]),I.homing,I.stalePolls,I.ingestSeq,I.threshold]);
const E0=eng(),chip0=document.querySelector(".mode").textContent,dot0=document.querySelector("#masthead .brand .dot").dataset.live;
o.replay=JSON.stringify(STARCHORUS.replay(3));
o.view=[STARCHORUS.stats().generated,STARCHORUS.stats().aps,STARCHORUS.nodes("ap").map(n=>n.id.slice(-2)).sort().join(),STARCHORUS.node(id(1)).rssi,STARCHORUS.node(id(2)).channel].join();
o.chip=[chip0,document.querySelector(".mode").textContent,dot0,document.querySelector("#masthead .brand .dot").dataset.live,STARCHORUS.stats().replay].join();
o.same=eng()===E0;
o.last=JSON.stringify([STARCHORUS.replay(9).index,STARCHORUS.stats().aps,STARCHORUS.node(id(2)).channel]);STARCHORUS.replay(3);
await STARCHORUS.wait(2600);o.faded=STARCHORUS.node(id(5))===null;   // the nodes the replay dropped have faded out and are gone: "Back to live" must not announce them as arrivals
// a poll arrives during the replay: recorded, buffered, not shown
const pr=live(mk(10));o.poll=[pr.replay,STARCHORUS.recording().count,STARCHORUS.replayInfo().buffered,STARCHORUS.stats().generated].join();
o.same2=eng()===E0;
o.exit=STARCHORUS.replayExit();
o.back=[STARCHORUS.stats().generated,STARCHORUS.stats().aps,document.querySelector(".mode").textContent,STARCHORUS.stats().replay,STARCHORUS.replayInfo().active].join();
const ev=STARCHORUS.stats().events;o.events=[ev.captureSeq,ev.arrived,ev.departed,ev.newAps].join();
// exit without a buffered poll shows the newest recorded capture and does not count a stale tick
const st0=STARCHORUS.stats().stalePolls;STARCHORUS.replay(2);STARCHORUS.replayExit();o.noPending=[STARCHORUS.stats().generated,STARCHORUS.stats().stalePolls===st0,STARCHORUS.stats().events.arrived,STARCHORUS.stats().events.captureSeq].join();
// recorder rules: undated and repeated captures are not recorded; another source starts a new recording; 130 captures keep 120; memory bytes bound
const n0=STARCHORUS.recording().count;live({source:"recon-db",aps:[ap(1,6,-60)],unassociated:[]});live(mk(10));o.rules=[STARCHORUS.recording().count-n0].join();
STARCHORUS.load(mk(0),"other",{mode:"live"});o.newSrc=STARCHORUS.recording().count;
for(let i=0;i<130;i++)STARCHORUS.load(mk(i+100),"many",{mode:"live"});o.cap=STARCHORUS.recording().count;o.bytesOk=STARCHORUS.recording().bytes<=STARCHORUS.recording().maxBytes;
const big=(g)=>{const a=[];for(let i=0;i<600;i++)a.push({bssid:"02:00:0e:"+(i>>8).toString(16).padStart(2,"0")+":"+(i&255).toString(16).padStart(2,"0")+":01",ssid:"b"+i,band:"5",channel:36,rssi:-50,security:"WPA2"});return {source:"recon-db",generated:g,aps:a,unassociated:[]};};
for(let i=0;i<50;i++)STARCHORUS.load(big(9000+i),"big",{mode:"live"});o.big=[STARCHORUS.recording().count,STARCHORUS.recording().bytes<=STARCHORUS.recording().maxBytes].join();
// nothing is stored, and clearing works
o.keys=Object.keys(localStorage).filter(k=>/rec|replay|long|thr|wave|air|time/i.test(k)).length;
STARCHORUS.load(mk(1),"c1",{mode:"live"});STARCHORUS.load(mk(2),"c1",{mode:"live"});STARCHORUS.replay(0);o.clr=[STARCHORUS.clearRecording(),STARCHORUS.recording().count,STARCHORUS.replayInfo().active].join();
STARCHORUS.load(mk(3),"c2",{mode:"live"});STARCHORUS.clearLocalData();o.clr2=STARCHORUS.recording().count;
o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$CHT_Q" "out/$P-cht-rec" --wait 2 --fps 0 --ready --eval-timeout 120 --eval "$CHT_EVR" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CHT_R=$(evalv "out/$P-cht-rec.json" 1 | cht_nj); CHT_RE=$(evalv "out/$P-cht-rec.json" 2)
CHT_RW=$(CHT_BIGMAX="$CHT_BIGMAX" python3 -c 'import json,os;print(json.dumps({"aps":"4444455555","back":"3050,5,Live,false,false","big":os.environ["CHT_BIGMAX"]+",true","bytesOk":True,"cap":120,"chip":"Live,Recorded,live,off,true","clr":"true,0,false","clr2":0,"count":10,"errors":0,"events":"11,0,0,0","exit":True,"faded":True,"gens":"3000-3045","keys":0,"last":"[9,5,1]","newSrc":1,"noMac":True,"noPending":"3050,true,0,11","poll":"true,11,1,3015","replay":"{\"active\":true,\"index\":3,\"count\":10,\"generated\":3015,\"buffered\":0,\"playing\":false}","rules":"0","same":True,"same2":True,"view":"3015,4,01,02,03,04,-57,11"},sort_keys=True,separators=(",",":"),ensure_ascii=False))')
if [ "$CHT_R" = "$CHT_RW" ] && [ "$CHT_RE" = 0 ]; then
  row "recording: 10 captures = 10 snapshots, replay shows capture n unchanged, the engines (events, change log, sky reference, histories, peak hold, homing, stale count) do not advance, a poll during the replay is recorded and shown after Back to live without inventing arrivals, limits 120 / 8 MB, no key stored, Clear" PASS
else
  row "recording and replay (err ${CHT_RE:-?})" FAIL
  echo "    got:  $(printf '%s' "$CHT_R" | cut -c1-900)"; echo "    want: $CHT_RW"
fi

# ---- Back to live writes no false change. A replay has already written its own channel, SSID, band, security and RSSI over the live nodes (and deleted and re-created the ones it faded out), so the resume
# ingest must not judge the buffered poll against them: the change log (exported), the change count, the cue pulses and the twinkles stay as they were before the replay. The same run gives the buffered poll one
# access point that was never heard (a real arrival, judged from the restored capture marks), which is still counted. The log before the replay holds the one real change of the recording (ap 2, capture 8, 11>1):
# the false entry the resume used to add is the same words at capture 11, so the log is read whole, and again by the capture it was written at.
CHT_EVB='(async()=>{
await STARCHORUS.wait(800);const o={};
const id=(n)=>"02:00:00:00:0d:"+String(n).padStart(2,"0");
const ap=(n,ch,rssi,cl)=>({bssid:id(n),ssid:"r"+n,band:ch>14?"5":"2.4",channel:ch,rssi,security:"WPA2",clients:cl||[]});
const mk=(i)=>({source:"recon-db",generated:3000+5*i,aps:[ap(1,6,-60+i,[{mac:"3c:22:fb:10:20:01",rssi:-55}]),ap(2,i>=7?1:11,-70),ap(3,36,-55),ap(4,52,-65)].concat(i>=5?[ap(5,1,-50)]:[]),unassociated:[{mac:"3c:22:fb:10:20:77",rssi:-70}]});
const live=(d)=>STARCHORUS.load(d,"rs",{mode:"live"});
for(let i=0;i<10;i++)live(mk(i));
const ids=[1,2,3,4,5,6].map(id),chg=(b)=>STARCHORUS.changes(b)||[];
const log=()=>ids.map(b=>chg(b).map(c=>c.seq+":"+c.kind+":"+c.from+">"+c.to).join(",")).join("|");   // seq:kind:from>to per access point, ap 1 to 6
const L0=log(),N0=STARCHORUS.stats().changeEntries,T0=STARCHORUS.stats().twinkles;o.before=L0;
STARCHORUS.replay(3);
await STARCHORUS.wait(2600);o.faded=STARCHORUS.node(id(5))===null;   // ap 5 is gone while the replay shows capture 3: Back to live creates it again from the defaults
const buf=mk(10);buf.aps.push(ap(6,6,-60));live(buf);o.buffered=STARCHORUS.replayInfo().buffered;   // the poll that arrives meanwhile: ap 6 is new, the rest as capture 10 (1 dB on ap 1)
STARCHORUS.replayExit();
const st=STARCHORUS.stats(),ev=st.events;
o.after=log();o.atResume=ids.reduce((a,b)=>a+chg(b).filter(c=>c.seq===ev.captureSeq).length,0);o.entries=st.changeEntries-N0;
o.changed=ev.changed;o.cues=ev.cues;o.twinkles=st.twinkles-T0;
o.events=[ev.captureSeq,ev.arrived,ev.departed,ev.newAps].join();
o.active=STARCHORUS.replayInfo().active;
o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$CHT_Q" "out/$P-cht-rsm" --wait 2 --fps 0 --ready --eval-timeout 120 --eval "$CHT_EVB" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CHT_B=$(evalv "out/$P-cht-rsm.json" 1 | cht_nj); CHT_BE=$(evalv "out/$P-cht-rsm.json" 2)
CHT_BW=$(printf '%s' '{"active":false,"after":"|8:channel:11>1||||","atResume":0,"before":"|8:channel:11>1||||","buffered":1,"changed":0,"cues":0,"entries":0,"errors":0,"events":"11,1,0,1","faded":true,"twinkles":0}' | cht_nj)
if [ "$CHT_B" = "$CHT_BW" ] && [ "$CHT_BE" = 0 ]; then
  row "recording: Back to live after a replay that faded a node out writes no false change: the log is the one it was (only the real 11>1 of capture 8), 0 entries at the resumed capture, 0 changed, 0 cues, 0 twinkles, while a real arrival in the buffered poll is still counted (events 11,1,0,1)" PASS
else
  row "recording: Back to live writes no false change (err ${CHT_BE:-?})" FAIL
  echo "    got:  $(printf '%s' "$CHT_B" | cut -c1-900)"; echo "    want: $CHT_BW"
fi

# The row bites: the same run on a copy of the page whose change-log comparison also runs on a resume ('&& !opts.resume' taken out). Fair by construction: the old text is in the page exactly once, the copy
# differs from the page in that one line, and it boots without an error. It must turn red exactly the keys that read the false entries (the log after the exit, the entries at the resumed capture and in all,
# changed, cues, twinkles) and leave every other key as the page has it: the log before the replay, the faded node, the buffered poll, the real arrival, the end of the replay. The copy is only served to headless
# Chrome on 127.0.0.1; nothing in it sends.
CHT_PL="out/$P-cht-plant"; mkdir -p "$CHT_PL"
python3 -B - "$H" "$CHT_PL/p-resume.html" 'else if (cmp && !opts.resume) {' 'else if (cmp) {' <<'PY'
import sys
src, out, old, new = sys.argv[1:]
s = open(src, encoding="utf-8").read()
if s.count(old) != 1:
    sys.exit(1)
open(out, "w", encoding="utf-8").write(s.replace(old, new))
PY
CHT_PR=$?; CHT_PD=$(diff "$H" "$CHT_PL/p-resume.html" 2>/dev/null | grep -c '^<')
CHT_HK=$H; H="$CHT_PL/p-resume.html"   # runq serves $H: point it at the copy for this one call, then put it back
runq demo "$CHT_Q" "out/$P-cht-rsx" --wait 2 --fps 0 --ready --eval-timeout 120 --eval "$CHT_EVB" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
H=$CHT_HK
CHT_X=$(evalv "out/$P-cht-rsx.json" 1 | cht_nj); CHT_XE=$(evalv "out/$P-cht-rsx.json" 2)
CHT_XK=$(printf '%s' "$CHT_X" | CHT_BW="$CHT_BW" python3 -c 'import json,os,sys;w=json.loads(os.environ["CHT_BW"]);g=json.load(sys.stdin);print(",".join(k for k in sorted(w) if g.get(k)!=w[k]))' 2>/dev/null)
CHT_XV=$(printf '%s' "$CHT_X" | python3 -c 'import json,sys;g=json.load(sys.stdin);print("%s at the resumed capture, %s in all, changed %s, cues %s, twinkles %s, events %s" % (g["atResume"],g["entries"],g["changed"],g["cues"],g["twinkles"],g["events"]))' 2>/dev/null)
CHT_XOK=0; [ "$CHT_PR" = 0 ] && [ "$CHT_PD" = 1 ] && [ "$CHT_XE" = 0 ] && [ "$CHT_XK" = "after,atResume,changed,cues,entries,twinkles" ] && CHT_XOK=1
rowif "recording: the resume key bites: a copy of the page whose change-log comparison also runs on a resume turns the log, the entries, changed, cues and twinkles red (false 11>1 for the replayed node, null-to-value entries for the re-created one) and leaves the log before the replay, the fade-out, the buffered poll, the real arrival and the end of the replay as they are [copy differs in $CHT_PD line, err ${CHT_XE:-?}, red keys ${CHT_XK:-none}; ${CHT_XV:-no value}]" [ "$CHT_XOK" = 1 ]

# ---- keys Q/J/H/Y, buttons, drawer exclusivity, channel-bar modes, waterfall, threshold ring, autoplay, drawer language (P10)
CHT_EVU='(async()=>{
await STARCHORUS.wait(800);const o={},key=(k)=>window.dispatchEvent(new KeyboardEvent("keydown",{key:k}));
const id=(n)=>"02:00:00:00:0f:"+String(n).padStart(2,"0");
const ap=(n,ch,rssi)=>({bssid:id(n),ssid:"u"+n,band:ch>14?"5":"2.4",channel:ch,rssi,security:n%2?"WPA2":"Open",clients:[]});
const mk=(i)=>({source:"recon-db",generated:5000+5*i,aps:[ap(1,6,-60+i),ap(2,11,-70),ap(3,36,-55),ap(4,100,-65)].concat(i>=5?[ap(5,1,-50)]:[]),unassociated:[]});
for(let i=0;i<10;i++)STARCHORUS.load(mk(i),"ui",{mode:"live"});
const dr=()=>document.documentElement.dataset.drawer,pr=(i)=>document.getElementById(i).getAttribute("aria-pressed");
o.start=dr();key("q");o.q=[dr(),pr("t-air"),document.getElementById("air-body").hidden].join();key("j");o.j=[dr(),pr("t-air"),pr("t-time")].join();key("h");o.h=[dr(),pr("t-rec")].join();key("h");o.off=dr();
STARCHORUS.setToggles({inventory:true});key("q");o.excl=[dr(),STARCHORUS.getToggles().inventory].join();key("q");
key("w");o.obs=dr();key("q");o.obs2=[dr(),STARCHORUS.getToggles().observations].join();key("q");
key("f");o.homing=dr();key("q");o.homing2=[dr(),STARCHORUS.stats().drawer].join();key("q");
o.btn=(()=>{document.getElementById("t-time").click();const a=dr();document.getElementById("t-time").click();return a+">"+dr();})();
const help=document.getElementById("help-list").innerText;o.help=[/Air quality/.test(help),/Signal over time/.test(help),/Recording and replay/.test(help),/Channel view/.test(help)].join();
// channel-bar modes: the button and Y cycle bars > spectrum > waterfall; each paints the canvas
const painted=()=>{const c=document.getElementById("chan"),x=c.getContext("2d"),d=x.getImageData(0,0,c.width,c.height).data;let n=0;for(let i=3;i<d.length;i+=4)if(d[i]>0)n++;return n;};
o.chanVisible=!document.getElementById("chanbar").hidden;const cm=[];const lab=()=>document.getElementById("t-chan").getAttribute("aria-label").slice(14);
cm.push(lab()+":"+STARCHORUS.stats().chanMode+":"+(painted()>0));key("y");cm.push(lab()+":"+STARCHORUS.stats().chanMode+":"+(painted()>0));key("y");cm.push(lab()+":"+STARCHORUS.stats().chanMode+":"+(painted()>0));document.getElementById("t-chan").click();cm.push(lab()+":"+STARCHORUS.stats().chanMode);o.modes=cm.join(" ");
// the three drawings differ; the waterfall draws the recorded captures, the spectrum the APs
STARCHORUS.setChannelMode("bars");const pb=painted();STARCHORUS.setChannelMode("spectrum");const ps=painted();STARCHORUS.setChannelMode("waterfall");const pw=painted();o.differ=[pb!==ps,ps!==pw,pb!==pw].join();
STARCHORUS.clearRecording();STARCHORUS.setChannelMode("waterfall");o.wfEmpty=painted()<pw;STARCHORUS.setChannelMode("bars");
for(let i=0;i<10;i++)STARCHORUS.load(mk(i),"ui2",{mode:"live"});
o.wf=[STARCHORUS.waterfall("2.4").channels.join("/"),STARCHORUS.waterfall("5").channels.join("/"),STARCHORUS.waterfall("6").channels.length,STARCHORUS.waterfall("2.4").cols.length].join();
// threshold ring: drawn (2D and 3D), bigger radius for a weaker threshold, gone when cleared
STARCHORUS.setFixedTime(4000000);STARCHORUS.setView("2d");await STARCHORUS.wait(700);
const CX=Math.round(innerWidth/2),CY=Math.round(innerHeight/2);
const scan=()=>{const s=new Set();for(let y=CY-7;y<=CY+7;y++)for(let x=CX+4;x<innerWidth-2;x++)if(STARCHORUS.pixel("sky",x,y).a>0)s.add(x+","+y);return s;};
const ringR=(thr)=>{STARCHORUS.setThreshold(null);STARCHORUS.frame();const a=scan();STARCHORUS.setThreshold(thr);STARCHORUS.frame();const b=scan();const xs=[];b.forEach(k=>{if(!a.has(k))xs.push(+k.split(",")[0]);});return xs.length?Math.round(xs.reduce((p,q)=>p+q,0)/xs.length)-CX:0;};
const r50=ringR(-50),r80=ringR(-80);o.ring2d=[r50>0,r80>r50].join();
STARCHORUS.setThreshold(null);STARCHORUS.frame();o.ringGone=ringR(null)===0;
STARCHORUS.setView("3d");await STARCHORUS.wait(900);STARCHORUS.setFixedTime(4100000);
const s3=(()=>{STARCHORUS.setThreshold(null);STARCHORUS.frame();const c=document.getElementById("sky"),x=c.getContext("2d"),a=x.getImageData(0,0,c.width,c.height).data;STARCHORUS.setThreshold(-60);STARCHORUS.frame();const b=x.getImageData(0,0,c.width,c.height).data;let n=0;for(let i=3;i<a.length;i+=4)if(a[i]!==b[i])n++;STARCHORUS.setThreshold(null);return n;})();o.ring3d=s3>20;
STARCHORUS.setView("2d");STARCHORUS.setFixedTime(null);
// autoplay: Play steps one capture per second of the page clock; it stops at the newest and Back to live ends the replay
STARCHORUS.openDrawer("rec");await STARCHORUS.wait(150);document.getElementById("rec-play").click();const i0=STARCHORUS.replayInfo().index;await STARCHORUS.wait(2600);const i1=STARCHORUS.replayInfo().index;o.play=[i0,i1>=i0+2,STARCHORUS.replayInfo().playing].join();
document.getElementById("rec-live").click();o.live=[STARCHORUS.replayInfo().active,STARCHORUS.stats().generated].join();
// drawer language: no P10 word in any of the three drawers
const P10=/\b(evil[ -]?twin|rogue|attack(er)?|threat|intru(der|sion)|malicious|spoof(ed|ing)?|karma|bandit|target|deauth flood)\b/i;let bad=0;
for(const [d,idb] of [["air","air-body"],["time","time-body"],["rec","rec-body"]]){STARCHORUS.openDrawer(d);await STARCHORUS.wait(120);if(P10.test(document.getElementById(idb).innerText))bad++;}
STARCHORUS.openDrawer(null);o.p10=bad;
o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$CHT_Q" "out/$P-cht-ui" --width 1440 --height 900 --wait 2 --fps 0 --ready --eval-timeout 180 --eval "$CHT_EVU" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CHT_U=$(evalv "out/$P-cht-ui.json" 1 | cht_nj); CHT_UE=$(evalv "out/$P-cht-ui.json" 2)
CHT_UW=$(printf '%s' '{"btn":"time>legend","chanVisible":true,"differ":"true,true,true","errors":0,"excl":"air,false","h":"rec,true","help":"true,true,true,true","homing":"home","homing2":"air,air","j":"time,false,true","live":"false,5045","modes":"bars:bars:true spectrum:spectrum:true waterfall:waterfall:true bars:bars","obs":"obs","obs2":"air,false","off":"legend","p10":0,"play":"0,true,true","q":"air,true,false","ring2d":"true,true","ring3d":true,"ringGone":true,"start":"legend","wf":"1/6/11,36/100,0,10","wfEmpty":true}' | cht_nj)
if [ "$CHT_U" = "$CHT_UW" ] && [ "$CHT_UE" = 0 ]; then
  row "channel/time keys Q/J/H/Y + buttons: one drawer at a time (with inventory, observations, homing), help entries; channel bar bars/spectrum/waterfall each paint and differ, waterfall from the recording, threshold ring 2D (bigger for weaker) and 3D, autoplay per page-clock second, no P10 word in the drawers" PASS
else
  row "channel/time keys, drawers, channel modes, ring (err ${CHT_UE:-?})" FAIL
  echo "    got:  $(printf '%s' "$CHT_U" | cut -c1-900)"; echo "    want: $CHT_UW"
fi

# ---- D15: the three drawers keep the edge panels apart
eval "$(grep '^EDG_OVL=' tools/regress.d/edge-layout.sh)"
eval "$(grep '^EDG_RDY=' tools/regress.d/edge-layout.sh)"
CHT_RDY=$EDG_RDY   # the fonts are loaded, the served capture has replaced the built-in sky and a frame has been painted (the overlap reads font metrics)
for CHT_VP in 1440x900 1000x640; do
  for CHT_D in air time rec; do
    runq "$F/field-probes.json" "?poll=0&spin=0&intro=0" "out/$P-cht-d15$CHT_D-$CHT_VP" --width "${CHT_VP%x*}" --height "${CHT_VP#*x}" --wait 4 --fps 0 --ready "$CHT_RDY" --eval "(async()=>{STARCHORUS.openDrawer('$CHT_D');await STARCHORUS.wait(300);return 1})()" --eval "$EDG_OVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
    CHT_OV=$(evalv "out/$P-cht-d15$CHT_D-$CHT_VP.json" 2); CHT_OVE=$(evalv "out/$P-cht-d15$CHT_D-$CHT_VP.json" 3)
    if [ "$CHT_OV" = 0 ] && [ "$CHT_OVE" = 0 ]; then row "channel/time drawers: D15 overlap 0 with the $CHT_D drawer open $CHT_VP (err ${CHT_OVE:-?}) [$(printf '%s' "$CHT_OV" | cut -c1-60)]" PASS
    else row "channel/time drawers: D15 overlap 0 with the $CHT_D drawer open $CHT_VP (err ${CHT_OVE:-?}) [$(printf '%s' "$CHT_OV" | cut -c1-60)]" FAIL; fi
  done
done

# ---- static: nothing is stored, no send path, no clock/random in the channel/time code, docs
CHT_KEYS=$(grep -oE '"starchorus\.[a-z]+\.v[0-9]+"' starchorus.html | sort -u | tr '\n' ' ')
rowif "P8 exactly the six storage keys; the recording, the histories and the threshold are memory only [$CHT_KEYS]" [ "$CHT_KEYS" = '"starchorus.baseline.v1" "starchorus.identity.v1" "starchorus.library.v1" "starchorus.notes.v1" "starchorus.ui.v1" "starchorus.watch.v1" ' ]
CHT_NET=$(grep -cE 'method:|POST|XMLHttpRequest|WebSocket|EventSource|sendBeacon' starchorus.html); CHT_FE=$(grep -c 'fetch(' starchorus.html)
if [ "$CHT_NET" = 0 ] && [ "$CHT_FE" = 1 ]; then row "channel/time passivity: no send path in the page (= $CHT_NET), fetch( = $CHT_FE" PASS
else row "channel/time passivity: no send path in the page (= $CHT_NET), fetch( = $CHT_FE" FAIL; fi
CHT_CLK=$(awk '/^\/\/ ---- channel\/air\/history\/replay models/,/^function phyEstimate\(/' starchorus.html | grep -cE 'Math\.random|Date\.now|performance\.now|new Date\(\)|setTimeout|setInterval')
rowif "channel/time models read no wall clock and no random (poll-clocked: $CHT_CLK)" [ "$CHT_CLK" = 0 ]
CHT_UI=$(awk '/^function setDx\(/,/^function applyDrawer\(/' starchorus.html | grep -cE 'Math\.random|Date\.now|performance\.now|setTimeout|setInterval')
rowif "channel/time drawers read no wall clock and no random ($CHT_UI)" [ "$CHT_UI" = 0 ]
CHT_SEC=$(grep -c 'recording' SECURITY.md)
rowif "P8 SECURITY.md says the recording, the histories and the threshold are memory only ($CHT_SEC)" [ "$CHT_SEC" -ge 1 ]

# ---- 0.2, the radio pair: channel activity is a whisker in the channel bar (tests/fixtures/radio-pair.json, bars mode). Read from the canvas, one pixel column per channel: the bar of channels 1, 6, 36 and 100
# stands 42, 36, 24 and 15 px high (the shares 0.28, 0.24, 0.16 and 0.10 over the largest, one scale across the bands), a share too small to see keeps 2 px
# and an empty channel none, and a document without activity draws nothing (the same columns as with the array removed). Only a drawn height is measured: no row here claims the title, the tooltip or the Air line.
CHT_EVW='(async()=>{const I=STARCHORUS._internals,S=I.S,sleep=STARCHORUS.wait,o={};await sleep(800);const fx=await (await fetch("starchorus.json")).json(),G=fx.generated;const cv=document.getElementById("chan"),box=document.getElementById("chanbar");const ld=(m,g)=>{const d=JSON.parse(JSON.stringify(fx));d.generated=g;d.bluetooth=[];if(m)m(d);return STARCHORUS.load(d,"rp-whisk");};const cssW=box.clientWidth-20,dpr=cv.width/cssW*1,segW=(cssW-32)/3,top=12,botY=54,ch=STARCHORUS.channels();const col=(band,c)=>{const keys=Object.keys(ch[band]).map(Number).sort((a,b)=>a-b),ci=keys.indexOf(c),bi=["2.4","5","6"].indexOf(band),x0=bi*(segW+16),cx=Math.round((x0+ci*(segW/keys.length)+segW/keys.length/2)*dpr);  const g=cv.getContext("2d"),px=[];for(let y=0;y<cv.height;y++){const q=g.getImageData(cx,y,1,1).data;px.push(q[0]+","+q[1]+","+q[2]+","+q[3]);}return px;};const cols=()=>[["2.4",1],["2.4",6],["5",36],["5",100]].map(([b,c])=>col(b,c));ld(null,G);await sleep(300);const A=cols();o.drawn=STARCHORUS.stats().activity.channels;o.max=STARCHORUS.stats().activity.max;ld(d=>{delete d.activity;},G+30);await sleep(300);const Bn=cols();o.none=STARCHORUS.stats().activity.channels;const h=A.map((a,i)=>{let n=0;for(let y=0;y<a.length;y++)if(a[y]!==Bn[i][y])n++;return n;});o.heights=h;ld(d=>{d.activity=[{freq:2412,share:0.28},{freq:5500,share:0.001}];},G+60);await sleep(300);const C=cols();const h2=C.map((a,i)=>{let n=0;for(let y=0;y<a.length;y++)if(a[y]!==Bn[i][y])n++;return n;});o.floor=h2;o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$F/radio-pair.json" "?poll=0&spin=0&intro=0&debug=1" "out/$P-cht-whisk" --width 1440 --height 900 --wait 3 --fps 0 --ready "$CHT_RDY" --eval-timeout 90 --eval "$CHT_EVW" >/dev/null 2>&1
CHT_W=$(evalv "out/$P-cht-whisk.json" 1 | python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":")))' 2>/dev/null)
CHT_WW='{"drawn":6,"errors":0,"floor":[42,0,0,2],"heights":[42,36,24,15],"max":0.28,"none":0}'
rowif "channel/time (radio pair): the whiskers stand 42/36/24/15 px for the shares 0.28/0.24/0.16/0.10 on one scale across the bands, a share too small to see keeps the 2 px floor, an empty channel has none, a document without activity draws none [$CHT_W]" [ "$CHT_W" = "$CHT_WW" ]
