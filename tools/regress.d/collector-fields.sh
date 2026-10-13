# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/collector-fields.sh -- the additive, passive collector fields and what the page does with them.
#   security suite (OWE first, enterprise, TKIP, transition; akm/cipher/auth) · packets · channels[] hop info ·
#   own transmitters · responded_ssids · max_age/interval + the payload default (U3 = yes) · §14.6 allowlist (self-tested in the collector)
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only CFL_* globals are set. The collector's own checks (bitmask decode,
# allowlist refusals with a logging stub, flags, run_cycle post-pass) run in the core row "collector --selftest"; this file adds the page side.
#
# Not verified on a device (flags stay OFF, documented in docs/device-notes.md): the recon.db `time` semantics behind channels[], `iw survey`
# on the device's driver, `wifi_device.packets`, the output formats of the AP-service CLI, own BSSIDs beyond the interface MACs.

CFL_Q="?poll=0&spin=0&intro=0&debug=1"

# ---- fixture = generator output
python3 tools/gen-testdata.py --secsuite --out "out/$P-secsuite.json" 2>/dev/null
rowif "secsuite.json = gen-testdata --secsuite" cmp -s "out/$P-secsuite.json" "$F/secsuite.json"

# ---- the page reads the collector's fields: classes, legend, detail rows, counts only for own_*, P1 for stations
CFL_EV='(async()=>{
const o={};await STARCHORUS.wait(1500);const st=STARCHORUS.stats();
o.sec=JSON.stringify(st.security);
o.hop=JSON.stringify(st.hop);o.own=JSON.stringify(st.own);
o.legend=STARCHORUS.legendRows().filter(r=>/^sec-/.test(r.kind)).map(r=>r.kind.slice(4)+":"+(r.visible?r.cnt:"-")).join(",");
STARCHORUS.select("02:00:5e:b0:00:04");let d=document.getElementById("detail-body").innerText;
o.sae=[/AKM\s+sae/.test(d),/Cipher\s+group ccmp128 · pairwise ccmp128/.test(d),/Auth scheme\s+open · sae/.test(d)].join(",");
STARCHORUS.select("02:00:5e:b0:00:0b");d=document.getElementById("detail-body").innerText;o.resp=/Answers for\s+3 different SSIDs/.test(d);
STARCHORUS.select("02:00:5e:b0:00:06");d=document.getElementById("detail-body").innerText;o.owe=[/Security\s+OWE \(owe\)/.test(d),/AKM\s+owe/.test(d)].join(",");
STARCHORUS.deselect();
const cl=STARCHORUS.node("3c:22:fb:10:20:31"),ks=Object.keys(cl);o.clientKeys=["akm","cipher","auth","respondedSsids"].filter(k=>ks.includes(k)).join(",")||"none";o.clientPackets=cl.packets;   // stations never carry the akm/cipher/auth detail; their (contract-less) packets stays null
const ap=STARCHORUS.node("02:00:5e:b0:00:04");o.apKeys=["akm","cipher","auth","respondedSsids","packets"].filter(k=>Object.keys(ap).includes(k)).join(",");
const txt=await (async()=>document.body.innerText+" "+[...document.querySelectorAll("[title]")].map(e=>e.title).join(" "))();
o.ownLeak=/00:c0:ca:98:76:54|my-own-net/i.test(txt+JSON.stringify(STARCHORUS.stats())+JSON.stringify(STARCHORUS.skyStats()));
return JSON.stringify(o);})()'
runq "$F/secsuite.json" "$CFL_Q" "out/$P-cfl-suite" --wait 3 --fps 0 --eval "$CFL_EV" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CFL_O=$(evalv "out/$P-cfl-suite.json" 1 | python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":")))' 2>/dev/null); CFL_OE=$(evalv "out/$P-cfl-suite.json" 2)
CFL_OW='{"apKeys":"akm,cipher,auth,respondedSsids,packets","clientKeys":"none","clientPackets":null,"hop":"{\"channels\":11,\"busy\":11}","legend":"open:1,wep:1,wpa:-,wpa2:2,wpa3:1,owe:1,enterprise:2,wpa3-transition:1,tkip-weak:2,unknown:-","own":"{\"bssids\":1,\"ssids\":1}","ownLeak":false,"owe":"true,true","resp":true,"sae":"true,true,true","sec":"{\"open\":1,\"wep\":1,\"wpa\":0,\"wpa2\":2,\"wpa3\":1,\"owe\":1,\"enterprise\":2,\"wpa3-transition\":1,\"tkip-weak\":2,\"unknown\":0}"}'
CFL_OW=$(printf '%s' "$CFL_OW" | python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":")))' 2>/dev/null)
if [ "$CFL_O" = "$CFL_OW" ] && [ "$CFL_OE" = 0 ]; then
  row "collector fields: classes owe/enterprise/tkip-weak/wpa3-transition, akm/cipher/auth, responder, hop counts, own_* never shown, no station detail" PASS
else
  row "collector fields: page side (err ${CFL_OE:-?})" FAIL
  echo "    got:  $(printf '%s' "$CFL_O" | cut -c1-420)"; echo "    want: $CFL_OW"
fi

# ---- a second capture of the same secsuite (new generated, nothing changed) is no change: the class comes from label AND akm/cipher on both sides
CFL_EVC='(async()=>{await STARCHORUS.wait(600);const d=await fetch("starchorus.json").then(r=>r.json());const a=JSON.parse(JSON.stringify(d));a.generated=d.generated+5;STARCHORUS.load(d,"twice");STARCHORUS.load(a,"twice");const e=STARCHORUS.stats().events;return [e.captureSeq,e.arrived,e.departed,e.changed,e.cues].join("/");})()'
runq "$F/secsuite.json" "$CFL_Q" "out/$P-cfl-same" --wait 2 --fps 0 --eval "$CFL_EVC" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CFL_C=$(evalv "out/$P-cfl-same.json" 1); CFL_CE=$(evalv "out/$P-cfl-same.json" 2)
if [ "$CFL_C" = 2/0/0/0/0 ] && [ "$CFL_CE" = 0 ]; then row "collector fields: an unchanged second capture is no change (classes from akm/cipher stay stable) [$CFL_C]" PASS
else row "collector fields: an unchanged second capture is no change (classes from akm/cipher stay stable) [$CFL_C]" FAIL; fi

# ---- label-only sources still classify: airodump strings, OWE before WPA3, TKIP with CCMP is not weak
CFL_EVL='(async()=>{
const ap=(n,sec,extra)=>Object.assign({bssid:"02:00:00:00:04:"+String(n).padStart(2,"0"),ssid:"l"+n,band:"2.4",channel:6,rssi:-60,security:sec},extra||{});
const cls=(sec,extra)=>{STARCHORUS.load({source:"recon-db",generated:1789300000,aps:[ap(1,sec,extra)]},"cls"+Math.random().toString(36).slice(2));return STARCHORUS.node("02:00:00:00:04:01").sec;};
return JSON.stringify([cls("WPA2/PSK/CCMP"),cls("WPA2/PSK/TKIP"),cls("WPA2/PSK/TKIP,CCMP"),cls("OWE"),cls("WPA3"),cls("WPA2/WPA3"),cls("WPA3-Enterprise"),cls("Secured"),cls("Open"),cls("WPA3",{akm:["owe"]}),cls("WPA2",{akm:["psk","sae"]})]);})()'
runq demo "$CFL_Q" "out/$P-cfl-lbl" --wait 2 --fps 0 --eval "$CFL_EVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CFL_L=$(evalv "out/$P-cfl-lbl.json" 1); CFL_LE=$(evalv "out/$P-cfl-lbl.json" 2)
CFL_LW='["wpa2","tkip-weak","wpa2","owe","wpa3","wpa3-transition","enterprise","wpa","open","owe","wpa3-transition"]'
if [ "$CFL_L" = "$CFL_LW" ] && [ "$CFL_LE" = 0 ]; then row "collector fields: label-only classification (airodump strings, akm overrides) [$CFL_L]" PASS
else row "collector fields: label-only classification (airodump strings, akm overrides) [$CFL_L]" FAIL; fi

# ---- older documents run unchanged (no akm/channels/own_*): stats keys, no hop, empty own
CFL_EVO='(async()=>{await STARCHORUS.wait(800);const s=STARCHORUS.stats();return JSON.stringify([s.hop,s.own,Object.keys(s.security).length]);})()'
runq "$F/legacy.json" "$CFL_Q" "out/$P-cfl-legacy" --wait 2 --fps 0 --eval "$CFL_EVO" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CFL_G=$(evalv "out/$P-cfl-legacy.json" 1); CFL_GE=$(evalv "out/$P-cfl-legacy.json" 2)
if [ "$CFL_G" = '[null,{"bssids":0,"ssids":0},10]' ] && [ "$CFL_GE" = 0 ]; then row "collector fields: a document without the optional collector fields still loads: hop null, own empty, 10 classes [$CFL_G]" PASS
else row "collector fields: a document without the optional collector fields still loads: hop null, own empty, 10 classes [$CFL_G]" FAIL; fi

# ---- static anchors
CFL_V=$(sed -n 's/^# Version:      \([0-9.]*\)$/\1/p' starchorus-collect.sh | head -n 1)
# U3: the device payload reads a 1 h window (exactly one export line, default 3600); the collector alone reads the whole record (0)
# shellcheck disable=SC2016  # literal ${...}/$VAR of the scanned script text, nothing is meant to expand
CFL_PL=$(grep -c '^export STARCHORUS_MAX_AGE="\${STARCHORUS_MAX_AGE:-3600}"' library/user/reconnaissance/starchorus/payload.sh)
CFL_PLA=$(grep -c 'STARCHORUS_MAX_AGE:-' library/user/reconnaissance/starchorus/payload.sh)
# shellcheck disable=SC2016  # literal ${...}/$VAR of the scanned script text, nothing is meant to expand
CFL_CM=$(grep -cxF 'MAX_AGE=${STARCHORUS_MAX_AGE:-0}' starchorus-collect.sh)
CFL_PLV=$(sed -n 's/^# Version:  *\([0-9.]*\)$/\1/p' library/user/reconnaissance/starchorus/payload.sh | head -n 1)
rowif "collector 0.1.0 · payload default STARCHORUS_MAX_AGE 3600, collector 0 (U3) · payload 0.1.0 [$CFL_V/$CFL_PL/$CFL_PLA/$CFL_CM/$CFL_PLV]" [ "$CFL_V/$CFL_PL/$CFL_PLA/$CFL_CM/$CFL_PLV" = 0.1.0/1/1/1/0.1.0 ]
CFL_FL=$(grep -cE '^(HOPINFO|SURVEY|OWN|APCLI_RO)=\$\{STARCHORUS_[A-Z_]+:-0\}' starchorus-collect.sh)
rowif "collector fields: device-dependent flags default OFF (HOPINFO/SURVEY/OWN/APCLI_RO = $CFL_FL/4)" [ "$CFL_FL" = 4 ]
