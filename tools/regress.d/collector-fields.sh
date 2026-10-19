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
CFL_V=$(sed -n 's/^# Version:      \([0-9][0-9A-Za-z.-]*\)$/\1/p' starchorus-collect.sh | head -n 1)
# U3: the device payload reads a 1 h window (exactly one export line, default 3600); the collector alone reads the whole record (0)
# shellcheck disable=SC2016  # literal ${...}/$VAR of the scanned script text, nothing is meant to expand
CFL_PL=$(grep -c '^export STARCHORUS_MAX_AGE="\${STARCHORUS_MAX_AGE:-3600}"' library/user/reconnaissance/starchorus/payload.sh)
CFL_PLA=$(grep -c 'STARCHORUS_MAX_AGE:-' library/user/reconnaissance/starchorus/payload.sh)
# shellcheck disable=SC2016  # literal ${...}/$VAR of the scanned script text, nothing is meant to expand
CFL_CM=$(grep -cxF 'MAX_AGE=${STARCHORUS_MAX_AGE:-0}' starchorus-collect.sh)
CFL_PLV=$(sed -n 's/^# Version:  *\([0-9][0-9A-Za-z.-]*\)$/\1/p' library/user/reconnaissance/starchorus/payload.sh | head -n 1)
rowif "collector 0.2.0-dev.1 · payload default STARCHORUS_MAX_AGE 3600, collector 0 (U3) · payload 0.2.0-dev.1 [$CFL_V/$CFL_PL/$CFL_PLA/$CFL_CM/$CFL_PLV]" [ "$CFL_V/$CFL_PL/$CFL_PLA/$CFL_CM/$CFL_PLV" = 0.2.0-dev.1/1/1/1/0.2.0-dev.1 ]
CFL_FL=$(grep -cE '^(HOPINFO|SURVEY|OWN|APCLI_RO)=\$\{STARCHORUS_[A-Z_]+:-0\}' starchorus-collect.sh)
rowif "collector fields: device-dependent flags default OFF (HOPINFO/SURVEY/OWN/APCLI_RO = $CFL_FL/4)" [ "$CFL_FL" = 4 ]

# ---- the radio pair (0.2): the switches, and what the collector's own self-test has to have covered. Chrome-free.
# Bluetooth and Traffic are off by default (anything that depends on the device is a flag until it has been looked at there, spec §14.10), the scan window
# is a checked integer, and the names on record of hidden networks are gone: the device's database holds none (device-notes 4a, measured 17 October 2026).
CFL_SW=$(grep -cE '^(BLUETOOTH|TRAFFIC)=\$\{STARCHORUS_(BLUETOOTH|TRAFFIC):-0\}$' starchorus-collect.sh)
CFL_RN=$(grep -c 'RECORDED_NAMES\|ap_rec' starchorus-collect.sh)
CFL_BW=$(grep -cE '^BT_WIN=\$\{STARCHORUS_BT_WINDOW:-5\}( |$)' starchorus-collect.sh)
rowif "collector fields: Bluetooth and Traffic off by default, the scan window 5 s, no names-on-record switch or code (BLUETOOTH, TRAFFIC $CFL_SW/2, RECORDED_NAMES or ap_rec $CFL_RN/0, BT_WIN $CFL_BW/1)" [ "$CFL_SW/$CFL_RN/$CFL_BW" = 2/0/1 ]
# the row bites: the same count over a text whose Bluetooth default is 1 finds one switch, not two
# shellcheck disable=SC2016  # the text is the thing searched
CFL_SWB=$(printf '%s\n%s\n' 'BLUETOOTH=${STARCHORUS_BLUETOOTH:-1}' 'TRAFFIC=${STARCHORUS_TRAFFIC:-0}' | grep -cE '^(BLUETOOTH|TRAFFIC)=\$\{STARCHORUS_(BLUETOOTH|TRAFFIC):-0\}$')
rowif "collector fields: the default row bites (a Bluetooth default of 1 is not counted: $CFL_SWB of 2)" [ "$CFL_SWB" = 1 ]
# The payload exports 0 for both, like its SURVEY line (the payload's own track writes the lines; the check follows the Contract number, which
# integration raises to 3 once for the new settings keys): while the header says 2 the payload only may not default either switch to 1, from 3 on it
# must export both with 0.
CFL_PLB=library/user/reconnaissance/starchorus/payload.sh
CFL_CN=$(sed -n 's/^# Contract:  *\([0-9][0-9]*\)$/\1/p' starchorus-collect.sh | head -n 1)
CFL_PX=$(grep -cE '^export STARCHORUS_(BLUETOOTH|TRAFFIC)="\$\{STARCHORUS_(BLUETOOTH|TRAFFIC):-0\}"' "$CFL_PLB")
CFL_P1=$(grep -cE 'STARCHORUS_(BLUETOOTH|TRAFFIC):-1' "$CFL_PLB")
if [ "${CFL_CN:-0}" -ge 3 ] 2>/dev/null; then
  rowif "collector fields: the payload exports 0 for Bluetooth and Traffic (Contract $CFL_CN: $CFL_PX/2 export lines, $CFL_P1 defaults of 1)" [ "$CFL_PX/$CFL_P1" = 2/0 ]
else
  rowif "collector fields: the payload defaults neither Bluetooth nor Traffic to 1 (Contract $CFL_CN: the exports with 0 are required from Contract 3; $CFL_PX/2 there, $CFL_P1 defaults of 1)" [ "$CFL_P1" = 0 ]
fi
# the payload rows bite: a payload line that exports a Bluetooth default of 1 is counted as a default of 1 and not as an export with 0
# shellcheck disable=SC2016  # the text is the thing searched
CFL_PB=$(printf '%s\n' 'export STARCHORUS_BLUETOOTH="${STARCHORUS_BLUETOOTH:-1}"' | grep -cE 'STARCHORUS_(BLUETOOTH|TRAFFIC):-1')
# shellcheck disable=SC2016
CFL_PB0=$(printf '%s\n' 'export STARCHORUS_BLUETOOTH="${STARCHORUS_BLUETOOTH:-1}"' | grep -cE '^export STARCHORUS_(BLUETOOTH|TRAFFIC)="\$\{STARCHORUS_(BLUETOOTH|TRAFFIC):-0\}"')
rowif "collector fields: the payload rows bite (a default of 1 is seen as one, and is not an export with 0: $CFL_PB/$CFL_PB0)" [ "$CFL_PB/$CFL_PB0" = 1/0 ]
# ---- alerts (0.2): the collector reads alerts.log in STARCHORUS_ALERT_DIR (default /root/loot/starchorus-alerts, a directory of its own) by default (STARCHORUS_ALERTS 1, a window of 600 s), and the README says so in the two table rows of the collector's
# variables and names the companion file that writes the log. Three names, three counts: a name that is missing, or documented with another default, is red.
CFL_AD=$(grep -cE '^ALERTS=\$\{STARCHORUS_ALERTS:-1\}( |$)' starchorus-collect.sh)
# shellcheck disable=SC2016  # literal ${...} of the scanned script text, nothing is meant to expand
CFL_AWD=$(grep -cF 'alert_window "${STARCHORUS_ALERT_WINDOW:-600}"' starchorus-collect.sh)
# shellcheck disable=SC2016  # the backticks are the Markdown's, nothing is meant to expand
cfl_names() {   # FILE -> how many of the three README names are documented there, as "table row 1, table row 2, file named"
  printf '%s/%s/%s' "$(grep -c '^| `STARCHORUS_ALERTS` | `1` |' "$1")" "$(grep -c '^| `STARCHORUS_ALERT_WINDOW` | `600` |' "$1")" "$(grep -c 'alert-deauth\.sh' "$1")"
}
CFL_AN=$(cfl_names README.md)
# shellcheck disable=SC2016  # the backticks are the Markdown's
CFL_ANB=$(printf '%s\n' '| `STARCHORUS_ALERTS` | `0` | wrong default |' '| `STARCHORUS_ALERT_WINDOW` | `600` | right |' > "out/$P-cfl-alerts.txt"; cfl_names "out/$P-cfl-alerts.txt")
case $CFL_AN in 1/1/[1-9]*) CFL_ANO=1 ;; *) CFL_ANO=0 ;; esac
rowif "collector fields: alerts on by default (STARCHORUS_ALERTS 1, window 600 s: $CFL_AD/$CFL_AWD), and the README documents STARCHORUS_ALERTS, STARCHORUS_ALERT_WINDOW and the file alert-deauth.sh (table rows and mentions $CFL_AN)" [ "$CFL_AD/$CFL_AWD/$CFL_ANO" = 1/1/1 ]
# the row bites: a README table with another default for the switch, and no mention of the file, is counted as 0 / 1 / 0
rowif "collector fields: the alerts documentation row bites (a wrong default of the switch and no file mention count $CFL_ANB, not 1/1/n)" [ "$CFL_ANB" = 0/1/0 ]

# The self-test has one line per family of the new cases (a case that stops running would otherwise only lower a count that nobody reads): the output
# of the run that tools/static.sh made (out/PREFIX-selftest.txt); without it (a drop-in run on its own) the row says so.
cfl_fam() {   # FILE -> the families that have no PASS line in the self-test output FILE
  _cf_m=""
  for _cf_p in 'bt_parse: the worked example' 'bt_parse: the grep prefilter' 'bt_parse: the real window of the device' 'bt_judge: Type: Active' 'bt_judge: no passive parameters' \
               'bt_judge: an LE Extended' 'forgery: a forged RSSI' 'forgery: a company line' 'bt_judge: a frame number' 'bt_begin: runs exactly' 'bt_end abort:' \
               'window same:' 'window parent:' 'overlap:' 'bt_begin: a monitor that holds no socket' 'bt_end: a scan that fails' 'watchdog same:' 'watchdog parent:' \
               'watchdog noforward:' 'watchdog: a scan that ignores INT and TERM' 'watchdog: a monitor that ignores' 'watchdog: without /proc' 'naps:' 'bt_sweep:' 'bt_sweep: a collector killed with -9' 'bt_sweep: a tool whose recorded start differs' 'bt_begin: a collector that has only written its marker' 'bt_end abort: the first INT to a scan younger' \
               'hold: addresses that go and come back' 'hold: at most 4 carries' 'hold: 300 addresses' 'layers: airodump-csv' 'layers: write_empty' 'layers: recon.db' \
               'layers: pineap' 'layers: tcpdump' 'traffic: the answer' 'traffic: [], an object' 'traffic: a hung AP service' 'size: a' 'station packets: STARCHORUS_TRAFFIC=1' \
               'station packets: a schema without' 'hidden networks: a hidden beacon row gives' 'hidden networks: a stronger probe response' \
               'hidden networks: a newer non-hidden' 'skip with layers: nothing changed' 'skip with layers: 22 quiet cycles' 'apcli_ro: the four allowed ids' \
               'apcli_ro: Traffic alone opens no list command' 'window state:' 'run_cycle: a capture-source cycle with a Bluetooth window' 'pineap: a cycle with the Bluetooth layer' \
               'pineap: a hidden beacon gives' 'run_cycle: a cycle without data' 'STARCHORUS_BT_WINDOW:' 'bt_note:' 'bt_stat:' 'bt_tick:' 'cleanup: a wrapper forked' \
               'bt_parse: an LE Direct' 'bt_parse: RSSI invalid' 'forgery: a TAB' 'forgery: a Type: Passive' 'bt_judge: no Scanning: Disabled' 'bt_parse: an awk that runs out' \
               'bt_parse: a header-shaped' 'bt_parse: a name that holds a header' 'bt_parse: a name with a newline inside' 'bt_nap: the nap is its argument' \
               'bt_end: the wait polls every 0.5 s' 'bt_begin: a monitor that has written only its banner' 'traffic: a share below 0.001' \
               'traffic: a whole cycle with only Traffic on' 'traffic: every second cycle: three cycles' 'traffic: every second cycle: an answer' \
               'alerts: ten lines' 'alerts: skip rules' 'alerts: 25 APs' 'alerts: no file' 'alerts: a directory' 'alerts: a read that fails' 'alerts: the switch' 'alerts: with Traffic' \
               'STARCHORUS_ALERT_WINDOW: values' 'STARCHORUS_ALERT_WINDOW: the log line' 'alerts: the window'; do
    grep -qF "PASS: $_cf_p" "$1" || _cf_m="$_cf_m [$_cf_p]"
  done
  printf '%s' "$_cf_m"
}
if [ -s "out/$P-selftest.txt" ]; then
  CFL_FM=$(cfl_fam "out/$P-selftest.txt")
  rowif "collector selftest: the Bluetooth, layer, traffic, hidden-network and skip cases all ran (missing:${CFL_FM:- none})" [ -z "$CFL_FM" ]
  # the row bites: the output without the watchdog cases and the size case names them
  CFL_FB=$(grep -v 'PASS: watchdog\|PASS: size:' "out/$P-selftest.txt" > "out/$P-cfl-st.txt"; cfl_fam "out/$P-cfl-st.txt")
  case $CFL_FB in *'[watchdog same:]'*'[size: a]'*) CFL_FBO=1 ;; *) CFL_FBO=0 ;; esac
  rowif "collector selftest: the family row bites (an output without the watchdog and size cases names them)" [ "$CFL_FBO" = 1 ]
else
  notcov "collector selftest: the Bluetooth, layer, traffic, hidden-network and skip cases (no out/$P-selftest.txt: run tools/static.sh or tools/regress.sh first)"
fi

# ---- the self-test reaches no radio and no controller, whatever the environment holds (spec 2.11, preamble; tools/install.sh and the README call it "offline,
# embedded sample data, no radio"). Both switches are set in the environment, hci0 stands in a sysfs of its own, and trap programs named hcitool, btmon, _pineap
# and timeout come first in PATH: the first three record any call, the timeout trap records a call whose command is one of them (not a stand-in of the same name that
# a case put in front) and runs everything else unbounded.
# The run must record none (the cases that need a window or a call put their own stand-ins first, which this PATH sits behind). The trap bites: three direct calls are
# three records. The same run on the tree before this fix recorded 86 scans, 86 monitors and 76 channel calls (measured by the review that found it).
cfl_trap() {   # cfl_trap DIR: the trap programs in DIR/bin, an empty DIR/calls.log, a sysfs with hci0 in DIR/sys
  rm -rf "$1"; mkdir -p "$1/bin" "$1/sys/hci0"; : > "$1/calls.log"; CFL_TD=$(cd "$1" && pwd)
  for _cn in hcitool btmon _pineap; do
    printf '#!/bin/sh\necho "%s $*" >> "%s/calls.log"\nexit 0\n' "$_cn" "$CFL_TD" > "$1/bin/$_cn"
  done
  # shellcheck disable=SC2016  # the text is the program of the trap, written to a file
  printf '#!/bin/sh\nif [ "$1" = -s ]; then shift 2; fi\nn=$1; shift\ncase $(command -v "$1" 2>/dev/null) in "%s/bin/"*) echo "timeout $n $*" >> "%s/calls.log"; exit 0 ;; esac\nexec "$@"\n' "$CFL_TD" "$CFL_TD" > "$1/bin/timeout"
  chmod +x "$1/bin/hcitool" "$1/bin/btmon" "$1/bin/_pineap" "$1/bin/timeout"
}
cfl_trap "out/$P-cfl-trap"
PATH="$CFL_TD/bin:$PATH" hcitool -i hci0 lescan --passive --duplicates >/dev/null 2>&1
PATH="$CFL_TD/bin:$PATH" timeout -s INT 6 btmon -i hci0 >/dev/null 2>&1
PATH="$CFL_TD/bin:$PATH" _pineap RECON CHANNELS format=json >/dev/null 2>&1
CFL_TB=$(wc -l < "$CFL_TD/calls.log" | tr -d ' '); : > "$CFL_TD/calls.log"
STARCHORUS_BLUETOOTH=1 STARCHORUS_TRAFFIC=1 STARCHORUS_APCLI_RO=1 STARCHORUS_SYSFS_BT="$CFL_TD/sys" PATH="$CFL_TD/bin:$PATH" \
  sh starchorus-collect.sh --selftest > "out/$P-cfl-hostile.txt" 2>&1
CFL_HC=$(wc -l < "$CFL_TD/calls.log" | tr -d ' '); CFL_HV=$(grep -c 'SELFTEST: ALL PASS' "out/$P-cfl-hostile.txt")
rowif "collector selftest: with both switches on in the environment, hci0 in its sysfs and trap programs for hcitool, btmon, timeout and _pineap first in PATH, the run passes and no trap is called ($CFL_HC calls, verdict lines $CFL_HV; the trap records 3 of 3 direct calls: $CFL_TB)" [ "$CFL_HC/$CFL_HV/$CFL_TB" = 0/1/3 ]
[ "$CFL_HC" = 0 ] || sed 's/^/    call: /' "$CFL_TD/calls.log" | sort | uniq -c | sort -rn | head -n 5
