# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/station-models.sh -- client stations have the theme-free models of the access points.
#   the station mechanisms exist in the source, each at its exact count
#   D1 freshness per station = a Python recount of aged.json (both ingest loops, every tier and "undated")
#   D2 arrival and departure per station, from consecutive captures only; a new source resets
#   the caps: station RSSI series (HIST_CL_MAX) and baseline stations (BASELINE_CL_MAX, strongest first)
#   D19 baseline and ghosts for stations: stored rssi only, never gone without hop data, a MAC heard as an AP is not gone
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only SMD_* globals are set.
#
# Every behaviour row pairs the station half with a control that turns it red if the model were simply absent: a row
# that cannot fail is not a row. The mutation that turns each row red is named above it.
#
# Three Chrome runs. On the device's DEFAULT source (recon.db) a station stays in the document for the whole window
# (the device payload's 1 h, STARCHORUS_MAX_AGE=3600; the whole record with the collector's own 0) and STARCHORUS_HOPINFO=0
# gives no hop data, so departures and ghosts stay dormant there for that long; that is the D2/D19 rule, not a defect,
# and these rows use synthetic captures for exactly that reason.

SMD_Q="?poll=0&spin=0&intro=0&debug=1"
smd_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }

# ---- static: the station mechanisms, fixed strings at exact counts (station-inventory.sh pins the fourteen decision points).
# Red if: a station freshOf call is dropped from either loop (2 -> 1), the station history push or the station departure
# count is removed, or the caps line is edited without this row.
smd_n() { grep -cF "$1" "$H"; }
SMD_ANCHORS="
2|const fc = freshOf(c.last_seen, gen);
1|if (!rp) histPushCl(seenCl, gen);
1|function histPushCl(seenCl, gen) {
1|S.clients.forEach(n => { if (!seenCl.has(n.id) && n.capSeq === seq - 1) dps++; });
1|const HIST_CL_MAX = 2400, BASELINE_CL_MAX = 2000, GHOST_CL_MAX = 40;
1|if (isObj(o.st)) for (const k of Object.keys(o.st).slice(0, BASELINE_CL_MAX))
"
SMD_BAD=$(printf '%s\n' "$SMD_ANCHORS" | while IFS='|' read -r _want _pat; do
  [ -n "$_pat" ] || continue
  _got=$(smd_n "$_pat"); [ "$_got" = "$_want" ] || printf '%s (want %s, got %s)\n' "$_pat" "$_want" "$_got"
done)
SMD_CNT=$(printf '%s\n' "$SMD_ANCHORS" | grep -c '|')
if [ -z "$SMD_BAD" ] && [ "$SMD_CNT" = 6 ]; then
  row "station models in the source: 6 anchors at their exact counts" PASS
else
  row "station models in the source (anchors $SMD_CNT/6)" FAIL; [ -z "$SMD_BAD" ] || printf '    %s\n' "$SMD_BAD"
fi

# ---- D1 per station. The recount covers both loops (3 associated stations, 2 unassociated) and must itself reach every
# tier and "undated", or it would prove nothing about the tier it misses. stats().fresh is re-read too: a station leaking
# into the AP count turns THIS row red as well as the freshness row of ap-models.sh.
# Red if: freshOf is removed from the associated loop (tiers "uu1uu" for "3210u") or the unassociated one ("32u0u"), a
# station's tier is taken from its AP's last_seen ("1011u": aged.json puts every associated station in another tier than
# its AP, so this fails on all three, not on one), or stations enter stats().fresh.
SMD_PY=$(python3 - "$F/aged.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); g = d["generated"]
def tier(ls):
    if ls is None or ls <= 0 or g - ls < -300:
        return None
    a = max(0, g - ls)
    return 0 if a < 60 else 1 if a < 300 else 2 if a < 900 else 3
def count(xs):
    c = {"t0": 0, "t1": 0, "t2": 0, "t3": 0, "undated": 0}
    for x in xs:
        t = tier(x.get("last_seen")); c["undated" if t is None else "t%d" % t] += 1
    return c
st = [c for a in d["aps"] for c in a["clients"]] + d["unassociated"]
tiers = "".join("u" if tier(x.get("last_seen")) is None else str(tier(x.get("last_seen"))) for x in sorted(st, key=lambda x: x["mac"]))
print(json.dumps({"ap": count(d["aps"]), "cl": count(st), "tiers": tiers}, sort_keys=True, separators=(",", ":")))
PY
)
SMD_EVF='(async()=>{const o={};
o.ap=STARCHORUS.stats().fresh;o.cl=STARCHORUS.stats().freshClients;
o.tiers=STARCHORUS.nodes("client").map(n=>n.id).sort().map(id=>{const t=STARCHORUS.node(id).freshTier;return t==null?"u":String(t)}).join("");
return JSON.stringify(o);})()'
runq "$F/aged.json" "$SMD_Q" "out/$P-smd-fresh" --wait 3 --fps 0 --ready "window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'" --eval "$SMD_EVF" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
SMD_FR=$(evalv "out/$P-smd-fresh.json" 1 | smd_nj); SMD_FRE=$(evalv "out/$P-smd-fresh.json" 2)
SMD_COVER=$(printf '%s' "$SMD_PY" | python3 -c 'import json,sys;c=json.load(sys.stdin)["cl"];print(int(all(v>0 for v in c.values())))' 2>/dev/null)
if [ -n "$SMD_PY" ] && [ "$SMD_FR" = "$SMD_PY" ] && [ "$SMD_FRE" = 0 ] && [ "$SMD_COVER" = 1 ]; then
  row "D1 per station = Python recount of aged.json $SMD_PY" PASS
else
  row "D1 per station (err ${SMD_FRE:-?}, recount covers every tier: ${SMD_COVER:-?})" FAIL
  echo "    got:  $SMD_FR"; echo "    want: $SMD_PY"
fi

# ---- D2 per station, and D19 for stations: one run of synthetic captures (the rule needs a sequence).
# D2 red if: the departure count in eventsSettle is removed ("2/1/0"), a departure is counted on a first capture, or
#   isNew is not exposed per station.
# D19 red if: saveBaseline drops st, a station is stored with its parent, the hop-data guard is removed (noHop != 0 gone),
#   a MAC heard as an AP is still counted gone, or GHOST_CL_MAX does not bite (45 stations gone -> 45 counted, 40 drawn).
SMD_EVS='(async()=>{const o={};
const st=(m,r)=>({mac:"02:00:00:00:77:"+m,rssi:r});
const ap1={bssid:"02:00:00:00:76:01",ssid:"m1",band:"2.4",channel:6,freq:2437,rssi:-50,security:"WPA2"};
const mk=(g,un,extra)=>Object.assign({source:"recon-db",generated:g,aps:[ap1],unassociated:un},extra||{});
const ev=()=>{const e=STARCHORUS.stats().events;return [e.captureSeq,e.newStations,e.departedStations].join("/")};
const seq=[];
STARCHORUS.load(mk(3000,[st("01",-60),st("02",-61),st("03",-62)]),"m1seq");seq.push(ev());
STARCHORUS.load(mk(3005,[st("01",-60),st("02",-61),st("04",-63)]),"m1seq");seq.push(ev());
seq.push([STARCHORUS.node("02:00:00:00:77:04").isNew,STARCHORUS.node("02:00:00:00:77:01").isNew].join());
STARCHORUS.load(mk(3005,[st("01",-60)]),"m1seq");seq.push(ev());
STARCHORUS.load(mk(3010,[st("01",-60)]),"m1new");seq.push(ev());
o.seq=seq.join(" | ");
const hop=[{freq:2412},{freq:2437},{freq:2462}];
const gs=(m)=>({mac:"02:00:00:00:7a:"+m,rssi:-60});
STARCHORUS.load(mk(5000,[gs("01"),gs("02"),gs("03")],{channels:hop}),"m1ghost");
o.setAp=STARCHORUS.setBaseline();STARCHORUS.setToggles({baselineDiff:true});
o.stored=(()=>{const j=JSON.parse(localStorage.getItem("starchorus.baseline.v1"));return [Object.keys(j.aps).length,Object.keys(j.st||{}).length,JSON.stringify(j.st&&j.st["02:00:00:00:7a:01"])].join("/")})();
const B=()=>{const b=STARCHORUS.baseline();return [b.size,b.sizeCl,b.newCl,b.goneCl,b.ghostsCl,b.ghosts].join("/")};
STARCHORUS.load(mk(5005,[gs("01"),gs("02"),gs("04")],{channels:hop}),"m1ghost");o.gone=B();STARCHORUS.frame();
o.ghostRow=STARCHORUS.legendRows().filter(r=>r.kind==="ghost").map(r=>r.visible).join();
STARCHORUS.load(mk(5010,[gs("01")]),"m1ghost");o.noHop=B();
const asAp=mk(5015,[gs("01"),gs("02")],{channels:hop});asAp.aps=[ap1,{bssid:"02:00:00:00:7a:03",ssid:"was-a-station",band:"2.4",channel:1,freq:2412,rssi:-55,security:"WPA2"}];
STARCHORUS.load(asAp,"m1ghost");o.asAp=B();
const g45=Array.from({length:45},(_,i)=>({mac:"02:00:00:00:7b:"+String(i).padStart(2,"0"),rssi:-60}));
STARCHORUS.load(mk(6000,g45,{channels:hop}),"m1gcap");STARCHORUS.setBaseline();
STARCHORUS.load(mk(6005,[],{channels:hop}),"m1gcap");const bb=STARCHORUS.baseline();o.ghostCap=[bb.sizeCl,bb.goneCl,bb.ghostsCl].join("/");
STARCHORUS.clearLocalData();o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$SMD_Q" "out/$P-smd-seq" --wait 2 --fps 0 --ready --eval "$SMD_EVS" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
SMD_S=$(evalv "out/$P-smd-seq.json" 1 | smd_nj); SMD_SE=$(evalv "out/$P-smd-seq.json" 2)
SMD_SQ=$(printf '%s' "$SMD_S" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("seq",""))' 2>/dev/null)
SMD_SQW="1/0/0 | 2/1/1 | true,false | 2/1/1 | 1/0/0"
if [ "$SMD_SQ" = "$SMD_SQW" ] && [ "$SMD_SE" = 0 ]; then
  row "D2 per station: first capture 0/0, then one arrival + one departure, isNew per station, same capture no change, new source resets" PASS
else
  row "D2 per station (err ${SMD_SE:-?})" FAIL; echo "    got:  $SMD_SQ"; echo "    want: $SMD_SQW"
fi
SMD_G=$(printf '%s' "$SMD_S" | python3 -c '
import json, sys
o = json.load(sys.stdin); o.pop("seq", None)
print(json.dumps(o, sort_keys=True, separators=(",", ":")))' 2>/dev/null)
# size/sizeCl/newCl/goneCl/ghostsCl/ghosts. "gone": 03 left and hop data is there -> 1 gone, 1 ghost, 04 new; the AP ghost count
# stays 0, so the visible ghost row is the STATION ghost's doing. "noHop": no channels -> never gone. "asAp": 03 is heard as an AP.
SMD_GW='{"asAp":"1/3/0/0/0/0","errors":0,"ghostCap":"45/45/40","ghostRow":"true","gone":"1/3/1/1/1/0","noHop":"1/3/0/0/0/0","setAp":1,"stored":"1/3/[-60]"}'
if [ "$SMD_G" = "$SMD_GW" ] && [ "$SMD_SE" = 0 ]; then
  row "D19 for stations: stored rssi only, gone -> ghost + legend row, never gone without hop data, heard as an AP is not gone, 40-ghost cap" PASS
else
  row "D19 for stations (err ${SMD_SE:-?})" FAIL; echo "    got:  $SMD_G"; echo "    want: $SMD_GW"
fi

# ---- the caps, on captures of up to 2500 stations. Four captures of one source, each claim observed, not assumed:
#   A  2500 new "0a"                    -> exactly HIST_CL_MAX series, the first 2400 in document order (the creation gate)
#   B  0a[0..1199] again + 1300 new "0c" -> the 1200 absent 0a series make room; the 1200 PRESENT 0a keep theirs (no thrash:
#                                         a present series is never evicted) and 0c gets the 1200 slots left (100 gated)
#   C  0c[0..1199] only                 -> nothing new, nothing evicted; the 0a series now carry an OLDER lastSeq than 0c
#   D  1300 new "0d"                    -> longest unheard first: all 1200 0a go, then the 100 lowest 0c; 0d gets all 1300
#   E  0d[0] comes back as an AP, 2500 new "0f" press the cap -> the AP keeps its series (2 samples: station, then AP) while
#                                         every stale station series makes room (0f gets 2400). A series that kept its
#                                         station tag would be evicted although its AP is present.
#   Red if: the gate is removed (A: 2500); present series are evictable (B: present 0a < 1200); the stale eviction is removed
#   (B: 0c 0); the eviction order is reversed or unsorted (D: 0a survives, 0c falls); a live AP's series is evictable (E: null).
# Baseline: set on capture A -> exactly BASELINE_CL_MAX stations, the STRONGEST (rssi -40..-79). Red if the sort is removed
#   (the first 2000 in document order reach -89).
SMD_EVC='(async()=>{const o={};
const h2=(n)=>n.toString(16).padStart(2,"0");
const many=(p,n)=>Array.from({length:n},(_,i)=>({mac:p+":00:00:00:"+h2(i>>8)+":"+h2(i&255),rssi:-40-(i%50)}));
const A=many("0a",2500),Cc=many("0c",1300),Dd=many("0d",1300);
const cnt=(xs)=>xs.filter(s=>STARCHORUS.hist(s.mac)!==null).length;
const cap=(g,un)=>STARCHORUS.load({source:"recon-db",generated:g,aps:[],unassociated:un},"m1cap");
cap(4000,A);
o.histA=cnt(A);
o.firstKept=[STARCHORUS.hist(A[0].mac)!==null,STARCHORUS.hist(A[2399].mac)!==null,STARCHORUS.hist(A[2400].mac)!==null].join();
o.setAp=STARCHORUS.setBaseline();
const j=JSON.parse(localStorage.getItem("starchorus.baseline.v1"));const ks=Object.keys(j.st||{});
o.baseCl=[ks.length,STARCHORUS.baseline().sizeCl,Math.min.apply(null,ks.map(k=>j.st[k][0]))].join("/");
cap(4005,A.slice(0,1200).concat(Cc));
o.noThrash=[cnt(A.slice(0,1200)),cnt(A.slice(1200)),cnt(Cc)].join("/");
cap(4010,Cc.slice(0,1200));
cap(4015,Dd);
o.oldestFirst=[cnt(A),cnt(Cc.slice(0,100)),cnt(Cc.slice(100,1200)),cnt(Dd)].join("/");
const X=Dd[0].mac,Ff=many("0f",2500);
STARCHORUS.load({source:"recon-db",generated:4020,aps:[{bssid:X,ssid:"was-a-station",band:"2.4",channel:6,freq:2437,rssi:-50,security:"WPA2"}],unassociated:Ff},"m1cap");
o.apKeep=[STARCHORUS.hist(X)!==null,(STARCHORUS.hist(X)||{samples:[]}).samples.length,cnt(Ff)].join("/");
STARCHORUS.clearLocalData();o.errors=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$SMD_Q" "out/$P-smd-cap" --wait 2 --fps 0 --ready --eval-timeout 150 --eval "$SMD_EVC" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
SMD_C=$(evalv "out/$P-smd-cap.json" 1 | smd_nj); SMD_CE=$(evalv "out/$P-smd-cap.json" 2)
SMD_CW='{"apKeep":"true/2/2400","baseCl":"2000/2000/-79","errors":0,"firstKept":"true,true,false","histA":2400,"noThrash":"1200/0/1200","oldestFirst":"0/0/1100/1300","setAp":0}'
if [ "$SMD_C" = "$SMD_CW" ] && [ "$SMD_CE" = 0 ]; then
  row "station caps: 2400 station series (gate, present never evicted, longest unheard first, a live AP never evicted), 2000 baseline stations strongest first" PASS
else
  row "station caps (err ${SMD_CE:-?})" FAIL; echo "    got:  $SMD_C"; echo "    want: $SMD_CW"
fi
