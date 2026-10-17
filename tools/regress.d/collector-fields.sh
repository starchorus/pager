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
return JSON.stringify([cls("WPA2/PSK/CCMP"),cls("WPA2/PSK/TKIP"),cls("WPA2/PSK/TKIP,CCMP"),cls("OWE"),cls("WPA3"),cls("WPA2/WPA3"),cls("WPA3-Enterprise"),cls("Secured"),cls("Open"),cls("WPA3",{akm:["owe"]}),cls("WPA2",{akm:["psk","sae"]}),cls("WPA3/SAE PSK/CCMP"),cls("WPA3/SAE/CCMP")]);})()'
runq demo "$CFL_Q" "out/$P-cfl-lbl" --wait 2 --fps 0 --eval "$CFL_EVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CFL_L=$(evalv "out/$P-cfl-lbl.json" 1); CFL_LE=$(evalv "out/$P-cfl-lbl.json" 2)
CFL_LW='["wpa2","tkip-weak","wpa2","owe","wpa3","wpa3-transition","enterprise","wpa","open","owe","wpa3-transition","wpa3-transition","wpa3"]'
if [ "$CFL_L" = "$CFL_LW" ] && [ "$CFL_LE" = 0 ]; then row "collector fields: label-only classification (airodump strings, akm overrides) [$CFL_L]" PASS
else row "collector fields: label-only classification (airodump strings, akm overrides) [$CFL_L]" FAIL; fi

# ---- PMF in the detail (v0.2): 'yes (derived)' for pure WPA3, OWE and a 6 GHz network (the band from band/freq alone, never from the channel number), otherwise 'unknown';
# a label that names both SAE and PSK ('WPA3/SAE PSK/CCMP') is a transition network, not pure WPA3, so it reads 'unknown'.
# marked derived like the PHY estimate (span.est with a title), and 'Protected Management Frames' spelt out once, in the help (a title shows on no phone). Per network: node.pmf / the detail row / the mark is there / the page's band; then whether the help carries the name.
# The help may not grow by more than two lines (spec item 1): with the help open, the paragraph that carries the name counts at most 2 lines (Range.getClientRects, one rect row per line)
# at 1440x900 and at 375x812 (--mobile), in every theme. The counter proves it bites: the same paragraph set to an earlier, longer wording (128 characters) must count 3 or more in every cell.
# On a desktop (1440x900 and a short 1000x500) the whole help box also lies inside the window, scrolling inside itself where the keys are taller than it (a box that ran off the top could not be reached).
CFL_EVP='(async()=>{
const mk=(n,sec,f)=>Object.assign({bssid:"02:00:00:00:05:0"+n,ssid:"pmf"+n,rssi:-60-n,security:sec},f);
STARCHORUS.load({source:"recon-db",generated:1789300000,aps:[mk(1,"WPA3",{band:"5",channel:36,akm:["sae"]}),mk(2,"OWE",{band:"2.4",channel:6,akm:["owe"]}),mk(3,"WPA2",{band:"6",channel:5}),mk(4,"WPA2",{freq:5955}),
 mk(5,"WPA2",{band:"5",channel:36}),mk(6,"WPA2/WPA3",{band:"5",channel:36}),mk(7,"WPA3-Enterprise",{band:"5",channel:36}),mk(8,"WPA2",{channel:197}),mk(9,"WPA3/SAE PSK/CCMP",{band:"5",channel:36})]},"pmf");
await STARCHORUS.wait(600);const o=[];
for(let i=1;i<=9;i++){const id="02:00:00:00:05:0"+i,n=STARCHORUS.node(id);STARCHORUS.select(id);const d=document.getElementById("detail-body"),m=d.innerText.match(/PMF\s*([^\n]*)/);
 o.push([n.pmf,m?m[1].trim():null,!!d.querySelector("span.est[title]"),n.band].join("/"));}
STARCHORUS.deselect();o.push(document.getElementById("help").textContent.includes("Protected Management Frames"));return JSON.stringify(o);})()'
runq demo "$CFL_Q" "out/$P-cfl-pmf" --wait 2 --fps 0 --eval "$CFL_EVP" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
CFL_P=$(evalv "out/$P-cfl-pmf.json" 1); CFL_PE=$(evalv "out/$P-cfl-pmf.json" 2); CFL_PS=$(grep -c 'Protected Management Frames' starchorus.html)
CFL_EVH='(async()=>{const T0=STARCHORUS.getTheme(),n=[],b=[],bad=[],long="PMF, in the detail of an access point: Protected Management Frames (802.11w), derived from the security class or the 6 GHz band.";
STARCHORUS.setToggles({help:true});
const lines=p=>{const r=document.createRange();r.selectNodeContents(p);return new Set(Array.from(r.getClientRects()).filter(x=>x.width>0).map(x=>Math.round(x.top))).size;};
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await STARCHORUS.wait(200);STARCHORUS.frame();
 const p=Array.from(document.querySelectorAll("#help p")).find(x=>x.textContent.includes("Protected Management Frames")),keep=p.textContent;
 const a=lines(p);p.textContent=long;const c=lines(p);p.textContent=keep;n.push(a);b.push(c);
 if(!(a>=1&&a<=2))bad.push(t+" paragraph "+a+" lines");if(!(c>=3))bad.push(t+" counter reads "+c+" for the long sentence");
 if(innerWidth>720){const b=document.getElementById("help").getBoundingClientRect();if(b.top<0||b.bottom>innerHeight)bad.push(t+" help box "+Math.round(b.top)+" to "+Math.round(b.bottom)+" of "+innerHeight);}}
STARCHORUS.setToggles({help:false});STARCHORUS.setTheme(T0);return (bad.length?"BAD "+bad.join("; "):"ok")+" [lines "+n.join(",")+"; long sentence "+b.join(",")+"]";})()'
runq demo "$CFL_Q" "out/$P-cfl-pmfh-d" --width 1440 --height 900 --wait 3 --fps 0 --eval "$CFL_EVH" >/dev/null 2>&1
runq demo "$CFL_Q" "out/$P-cfl-pmfh-p" --width 375 --height 812 --mobile --wait 3 --fps 0 --eval "$CFL_EVH" >/dev/null 2>&1
runq demo "$CFL_Q" "out/$P-cfl-pmfh-s" --width 1000 --height 500 --wait 3 --fps 0 --eval "$CFL_EVH" >/dev/null 2>&1
CFL_HD=$(evalv "out/$P-cfl-pmfh-d.json" 1); CFL_HP=$(evalv "out/$P-cfl-pmfh-p.json" 1); CFL_HS=$(evalv "out/$P-cfl-pmfh-s.json" 1)
CFL_PW='["yes (derived)/yes (derived)/true/5","yes (derived)/yes (derived)/true/2.4","yes (derived)/yes (derived)/true/6","yes (derived)/yes (derived)/true/6","unknown/unknown/true/5","unknown/unknown/true/5","unknown/unknown/true/5","unknown/unknown/true/6","unknown/unknown/true/5",true]'
case $CFL_HD in ok\ *) CFL_HDO=1 ;; *) CFL_HDO=0 ;; esac; case $CFL_HP in ok\ *) CFL_HPO=1 ;; *) CFL_HPO=0 ;; esac; case $CFL_HS in ok\ *) CFL_HSO=1 ;; *) CFL_HSO=0 ;; esac
if [ "$CFL_P" = "$CFL_PW" ] && [ "$CFL_PE" = 0 ] && [ "$CFL_PS" = 1 ] && [ "$CFL_HDO" = 1 ] && [ "$CFL_HPO" = 1 ] && [ "$CFL_HSO" = 1 ]; then row "PMF derived: WPA3-only, OWE, 6 GHz by band and by freq = yes (derived); WPA2, transition (also a label that names SAE and PSK), enterprise and a 6 GHz guess from the channel number alone = unknown; spelt out once, in the help ($CFL_PS), whose paragraph is at most 2 lines at 1440x900 and 375x812 in every theme, and the help box lies inside a 1440x900 and a 1000x500 window" PASS
else row "PMF derived (err ${CFL_PE:-?}, spelt out ${CFL_PS:-?}x, help lines desktop ${CFL_HD:-?}, phone ${CFL_HP:-?}, short desktop ${CFL_HS:-?})" FAIL; echo "    got:  $CFL_P"; echo "    want: $CFL_PW"; fi

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
rowif "collector 0.1.1 · payload default STARCHORUS_MAX_AGE 3600, collector 0 (U3) · payload 0.1.1 [$CFL_V/$CFL_PL/$CFL_PLA/$CFL_CM/$CFL_PLV]" [ "$CFL_V/$CFL_PL/$CFL_PLA/$CFL_CM/$CFL_PLV" = 0.1.1/1/1/1/0.1.1 ]
CFL_FL=$(grep -cE '^(HOPINFO|SURVEY|OWN|APCLI_RO)=\$\{STARCHORUS_[A-Z_]+:-0\}' starchorus-collect.sh)
rowif "collector fields: device-dependent flags default OFF (HOPINFO/SURVEY/OWN/APCLI_RO = $CFL_FL/4)" [ "$CFL_FL" = 4 ]
