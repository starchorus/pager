# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/station-tools.sh -- identity, notes, homing and bulk assign accept client stations (P2).
#   the station mechanisms exist in the source, each at its exact count
#   the gate observed(): a present station and a baseline station are observed; an unheard key is not; a dual-key MAC resolves to its AP
#   a station identity AND a note survive a page RELOAD (proven by a reboot sentinel)
#   a wildcard rule may set suspect, and bulk assign covers stations (friend/neutral/suspect)
#   IDENT_MAX: refuse-when-full on the write paths and a load-side clamp (P8)
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only STL_* globals are set.
#
# Homing onto a station is also covered by the homing run of operator-tools.sh; here the gate predicate is asserted
# directly. Each behaviour row names the mutation that turns it red.

STL_Q="?poll=0&spin=0&intro=0&debug=1"
stl_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }

# ---- static: the station mechanisms, fixed strings at exact counts (station-inventory.sh pins the fourteen decision points).
# Red if: the gate loses its present-station or baseline-station branch, the homing gate is not both-kinds, identCanAdd is
# removed, libraryAssign stops iterating stations, or the station identity frame is dropped from drawClients.
stl_n() { grep -cF "$1" "$H"; }
STL_ANCHORS="
1|const a = S.aps.get(b); if (a && a.target === 1) return true;
1|const c = S.clients.get(b); if (c && c.target === 1) return true;
1|(!seenAp.has(h.bssid) && !seenCl.has(h.bssid))
1|const identCanAdd = (b) => S.identity.has(b) || S.identity.size < IDENT_MAX;
1|for (const cl of S.clientOrder) if (cl.target === 1) take(cl, false);
1|if (idn !== \"unknown\") { setAlpha(ctx, alpha); drawIdentityFrame(ctx, sx, sy, px + 4
1|IDENT_MAX = 5000
"
STL_BAD=$(printf '%s\n' "$STL_ANCHORS" | while IFS='|' read -r _want _pat; do
  [ -n "$_pat" ] || continue
  _got=$(stl_n "$_pat"); [ "$_got" = "$_want" ] || printf '%s (want %s, got %s)\n' "$_pat" "$_want" "$_got"
done)
STL_CNT=$(printf '%s\n' "$STL_ANCHORS" | grep -c '|')
if [ -z "$STL_BAD" ] && [ "$STL_CNT" = 7 ]; then
  row "station tools in the source: 7 anchors at their exact counts" PASS
else
  row "station tools in the source (anchors $STL_CNT/7)" FAIL; [ -z "$STL_BAD" ] || printf '    %s\n' "$STL_BAD"
fi

# ---- the gate observed(), through the API paths that call it. A present station and a baseline station are accepted;
# a key never heard is refused; a MAC that is both an AP and a station resolves to its AP (STARCHORUS.node prefers S.aps).
# Red if: the present-station branch is dropped (identSt "unknown"), the baseline branch is dropped (baseSt "unknown"),
# or the gate rejects a station / accepts an unheard key (unheard != "1 rejected: not observed"). The dual-key MAC is
# observed (assignable) — a gate that short-circuited on S.clients before the AP check would wrongly reject it.
STL_EV1='(async()=>{const o={};
const A="02:00:00:00:0a:01",C="02:00:00:00:0a:02",D="02:00:00:00:0a:03",BOTH="02:00:00:00:0a:04";
const mk=(g,aps,un)=>({source:"recon-db",generated:g,center:{label:"x"},aps,unassociated:un});
const ap=(b,ss)=>({bssid:b,ssid:ss,band:"2.4",channel:6,freq:2437,rssi:-50,security:"WPA2",clients:[]});
// BOTH is emitted as an AP and (same MAC) as a station in the same capture
STARCHORUS.load(mk(100,[ap(A,"a"),ap(BOTH,"dual")],[{mac:C,rssi:-60},{mac:D,rssi:-61},{mac:BOTH,rssi:-62}]),"stl-gate");
o.identSt=STARCHORUS.setIdentity(C,"friend");            // a present station is observed -> taken
o.identAp=STARCHORUS.setIdentity(A,"neutral");           // an access point, unchanged
o.dual=(STARCHORUS.setIdentity(BOTH,"hostile"),STARCHORUS.node(BOTH).kind);   // a dual-key MAC is observed (assignable); STARCHORUS.node prefers the AP
o.dualId=STARCHORUS.identity(BOTH);
o.unheard=STARCHORUS.libraryImport("de:ad:be:ef:00:99 friend").message;  // never heard -> refused
// D is dropped from the next capture but kept in the baseline; it must stay observed (the post-reload re-observe path)
STARCHORUS.setIdentity(D,"friend");o.beforeBase=STARCHORUS.identity(D);
STARCHORUS.setBaseline();
STARCHORUS.load(mk(105,[ap(A,"a")],[{mac:C,rssi:-60}]),"stl-gate");   // D is gone from the document but in the baseline
o.baseSt=STARCHORUS.setIdentity(D,"neutral");            // a baseline station is still observed -> re-assignable
o.err=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$STL_Q" "out/$P-stl-gate" --wait 2 --fps 0 --ready --eval "$STL_EV1" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
STL_G=$(evalv "out/$P-stl-gate.json" 1 | stl_nj); STL_GE=$(evalv "out/$P-stl-gate.json" 2)
STL_GW='{"baseSt":"neutral","beforeBase":"friend","dual":"ap","dualId":"hostile","err":0,"identAp":"neutral","identSt":"friend","unheard":"1 rejected: not observed"}'
if [ "$STL_G" = "$STL_GW" ] && [ "$STL_GE" = 0 ]; then
  row "gate observed(): present station and baseline station accepted, unheard key refused, a dual-key MAC is observed (resolves to its AP)" PASS
else
  row "gate observed() (err ${STL_GE:-?})" FAIL; echo "    got:  $STL_G"; echo "    want: $STL_GW"
fi

# ---- a station identity AND a note survive a page reload. The reboot sentinel (window.__stl) is set before the reload
# and read after: it must be undefined afterwards, proving the readback runs in the FRESH boot context (loadIdentity /
# loadLibrary re-read localStorage), not the stale pre-navigation one.
# Red if: saveIdentity/saveNotes stop writing, loadIdentity/loadLibrary stop reading, or the sequence hits the stale context
# (sentinel != "undefined" -> the reload did not happen and the row proves nothing).
STL_CID='STARCHORUS.nodes("client").map(n=>n.id).sort()[0]'
runq "$F/many-clients.json" "$STL_Q" "out/$P-stl-reload" --wait 2 \
  --step "eval:const C=$STL_CID;STARCHORUS.setIdentity(C,'hostile');STARCHORUS.notes(C,{alias:'keepme',tags:['t1']});window.__stl=1;JSON.stringify([C,STARCHORUS.identity(C),(STARCHORUS.notes(C)||{}).alias])" \
  --step 'eval:(location.reload(),"reloading")' \
  --step 'wait:2.5' \
  --step "eval:const C=$STL_CID;JSON.stringify([typeof window.__stl,typeof STARCHORUS,STARCHORUS.identity(C),(STARCHORUS.notes(C)||{}).alias,((STARCHORUS.notes(C)||{}).tags||[]).join(',')])" >/dev/null 2>&1
STL_R=$(python3 - "out/$P-stl-reload.json" <<'PY'
import json, sys
try:
    r = json.load(open(sys.argv[1])); ev = r.get("eval", [])
    before = json.loads(ev[0]["value"]); after = json.loads(ev[2]["value"])
    ok = (before[1] == "hostile" and before[2] == "keepme"          # set before the reload
          and after[0] == "undefined"                               # the sentinel is gone -> fresh context
          and after[1] == "object" and after[2] == "hostile"        # identity survived, via loadIdentity
          and after[3] == "keepme" and after[4] == "t1")            # note + tags survived, via loadLibrary
    print("PASS" if ok else "FAIL " + json.dumps([before, after]))
except Exception as e:
    print("FAIL " + str(e))
PY
)
if [ "$STL_R" = PASS ]; then
  row "a station identity and note survive a reload (reboot sentinel proves the fresh boot context re-read localStorage)" PASS
else
  row "station identity/note survive a reload" FAIL; echo "    $STL_R"
fi

# ---- a wildcard rule may set suspect, and bulk assign covers stations (friend/neutral/suspect).
# The document has 8 stations on OUI aa:bb:cc plus 2 APs. A rule "aa:bb:cc:??:??:?? suspect" marks all 8 stations suspect
# via ruleOf (rule-matched, not stored per-MAC). libraryAssign("friend",{}) then sets every present AP+station friend
# (manual, overriding the rule). Red if: a wildcard-suspect guard is added (ruleAdded 0), or libraryAssign drops the
# station loop (bulkFriend counts only the 2 APs), or hostile is refused by bulk (bulkHostile 0).
STL_EV3='(async()=>{const o={};
const h2=(n)=>n.toString(16).padStart(2,"0");
const st=Array.from({length:8},(_,i)=>({mac:"aa:bb:cc:00:00:"+h2(i),rssi:-60-i}));
const ap=(n)=>({bssid:"02:00:00:00:0b:"+h2(n),ssid:"m2r"+n,band:"2.4",channel:6,freq:2437,rssi:-50,security:"WPA2",clients:[]});
STARCHORUS.load({source:"recon-db",generated:200,center:{label:"x"},aps:[ap(1),ap(2)],unassociated:st},"stl-rule");
const r=STARCHORUS.libraryImport("aa:bb:cc:??:??:?? suspect");o.ruleAdded=r.rules+"/"+(r.message||"ok");
o.ruleHits=st.filter(s=>STARCHORUS.identity(s.mac)==="hostile").length;                 // all 8 stations match the suspect rule
o.ruleSrc=STARCHORUS.identitySource(st[0].mac);                                         // "rule-matched", not "manual"
o.bulkFriend=STARCHORUS.libraryAssign("friend",{});                                     // every present AP + station -> friend
o.friendSt=STARCHORUS.identity(st[0].mac)+"/"+STARCHORUS.identitySource(st[0].mac);          // now manual friend
o.bulkHostile=STARCHORUS.libraryAssign("hostile",{});                                   // suspect via bulk reaches the 8 stations too
STARCHORUS.clearLocalData();o.err=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$STL_Q" "out/$P-stl-rule" --wait 2 --fps 0 --ready --eval "$STL_EV3" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
STL_U=$(evalv "out/$P-stl-rule.json" 1 | stl_nj); STL_UE=$(evalv "out/$P-stl-rule.json" 2)
# bulkFriend = 10 (2 AP + 8 st); bulkHostile = 10 (band 2.4 matches all, vendor null matches all) -> suspect assigned in bulk
STL_UW='{"bulkFriend":10,"bulkHostile":10,"err":0,"friendSt":"friend/manual","ruleAdded":"1/ok","ruleHits":8,"ruleSrc":"rule-matched"}'
# A suspect wildcard rule must SURVIVE a reload: import it, reload, and confirm a matching MAC still reads hostile
# (rule-matched). loadLibrary must admit a hostile rule, mirroring loadIdentity — until this it dropped it silently.
runq demo "$STL_Q" "out/$P-stl-rulereload" --wait 2 \
  --step 'eval:STARCHORUS.libraryImport("aa:bb:cc:??:??:?? suspect");window.__mr=1;STARCHORUS.identity("aa:bb:cc:00:00:01")+"/"+STARCHORUS.identitySource("aa:bb:cc:00:00:01")' \
  --step 'eval:(location.reload(),"reloading")' \
  --step 'wait:2.5' \
  --step 'eval:typeof window.__mr+"/"+STARCHORUS.identity("aa:bb:cc:00:00:01")+"/"+STARCHORUS.identitySource("aa:bb:cc:00:00:01")' >/dev/null 2>&1
STL_RR=$(python3 - "out/$P-stl-rulereload.json" <<'PYX'
import json, sys
try:
    r = json.load(open(sys.argv[1])); ev = r.get("eval", [])
    before = ev[0]["value"]; after = ev[2]["value"]   # before: "hostile/rule-matched"; after: "undefined/hostile/rule-matched"
    print("PASS" if before == "hostile/rule-matched" and after == "undefined/hostile/rule-matched" else "FAIL before=%s after=%s" % (before, after))
except Exception as e:
    print("FAIL " + str(e))
PYX
)
if [ "$STL_U" = "$STL_UW" ] && [ "$STL_UE" = 0 ] && [ "$STL_RR" = PASS ]; then
  row "wildcard rule sets suspect (8 rule-matched) and SURVIVES a reload, bulk assign covers stations incl. hostile" PASS
else
  row "wildcard/bulk suspect (err ${STL_UE:-?}, reload $STL_RR)" FAIL; echo "    got:  $STL_U"; echo "    want: $STL_UW"
fi

# ---- IDENT_MAX (P8), two halves. WRITE side: a synthetic capture of IDENT_MAX+50 stations; bulk assign fills exactly
# IDENT_MAX and refuses the rest (identCanAdd). LOAD side: localStorage is PRE-SEEDED with IDENT_MAX+50 identity entries and
# the page is reloaded; loadIdentity must clamp to IDENT_MAX (the write cap alone never lets storage grow past it, so only a
# pre-seed exercises the load slice). Red if: identCanAdd is removed (set > IDENT_MAX), or the load slice is removed
# (afterReload > IDENT_MAX).
STL_EV4='(async()=>{const o={};
const h2=(n)=>n.toString(16).padStart(2,"0");
const many=Array.from({length:5050},(_,i)=>({mac:"0a:"+h2((i>>16)&255)+":"+h2((i>>8)&255)+":"+h2(i&255)+":00:01",rssi:-60}));
STARCHORUS.load({source:"recon-db",generated:300,center:{label:"x"},aps:[],unassociated:many},"stl-cap");
o.present=STARCHORUS.nodes("client").length>=5050;
o.set=STARCHORUS.libraryAssign("neutral",{});                       // tries 5050, cap 5000
o.size=Object.keys(STARCHORUS.identities()).length;                 // exactly IDENT_MAX
o.refuseNew=STARCHORUS.libraryImport(many[5049].mac+" friend").message;   // a further new key is refused
o.reAssignOk=STARCHORUS.setIdentity(many[0].mac,"friend");          // an EXISTING key can still be re-set (not a new key)
o.err=STARCHORUS.errors().length;
return JSON.stringify(o);})()'
runq demo "$STL_Q" "out/$P-stl-cap" --wait 2 --fps 0 --ready --eval-timeout 150 --eval "$STL_EV4" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
STL_C=$(evalv "out/$P-stl-cap.json" 1 | stl_nj); STL_CE=$(evalv "out/$P-stl-cap.json" 2)
STL_CW='{"err":0,"present":true,"reAssignOk":"friend","refuseNew":"1 rejected","set":5000,"size":5000}'
# LOAD side: pre-seed 5050 identity entries, reload, and read back the clamped size. Single quotes are literal inside
# the shell double-quoted step; JS strings use double quotes to avoid any escaping.
runq demo "$STL_Q" "out/$P-stl-loadcap" --wait 2 \
  --step 'eval:var o={};for(var i=0;i<5050;i++){var m="0b:00:"+((i>>16)&255).toString(16).padStart(2,"0")+":"+((i>>8)&255).toString(16).padStart(2,"0")+":"+(i&255).toString(16).padStart(2,"0")+":00:02";o[m]="friend";}localStorage.setItem("starchorus.identity.v1",JSON.stringify(o));window.__lc=1;String(Object.keys(o).length)' \
  --step 'eval:(location.reload(),"reloading")' \
  --step 'wait:2.5' \
  --step 'eval:typeof window.__lc+"/"+Object.keys(STARCHORUS.identities()).length' >/dev/null 2>&1
STL_LC=$(python3 - "out/$P-stl-loadcap.json" <<'PYX'
import json, sys
try:
    r = json.load(open(sys.argv[1])); ev = r.get("eval", [])
    seeded = ev[0]["value"]; after = ev[2]["value"]   # "undefined/<size>" — sentinel gone (fresh context), size clamped
    sc, sz = after.split("/")
    print("PASS" if seeded == "5050" and sc == "undefined" and sz == "5000" else "FAIL seeded=%s after=%s" % (seeded, after))
except Exception as e:
    print("FAIL " + str(e))
PYX
)
if [ "$STL_C" = "$STL_CW" ] && [ "$STL_CE" = 0 ] && [ "$STL_LC" = PASS ]; then
  row "IDENT_MAX: bulk fills exactly 5000 (write) and a pre-seeded 5050 clamps to 5000 on reload (load); a further new key refused" PASS
else
  row "IDENT_MAX cap (write ${STL_CE:-?}, load $STL_LC)" FAIL; echo "    got:  $STL_C"; echo "    want: $STL_CW"
fi
