# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/display-parity.sh -- the Overview (starchorus-display.sh) says what the page says.
#   the numbers of `sh starchorus-display.sh --once summary <fixture>` = the page's stats() for every fixture (the randomised free
#   stations and the random clouds of §8.8a included) · red only for an alarm · GEN instead of SEQ ·
#   the Air quality LOG block = the page's airQuality() · the optional template · no new output path ·
#   the busiest channel = the page's crowdingOf() on every fixture and on generated tie/edge documents ·
#   the whole Air block (AP count, beacon estimate, top channels, least occupied) = airQuality() on the same documents ·
#   the top screen's red = the security field, never the SSID text
#   the radio pair: the summary's BT figure = the page's stats().bluetooth, the Bluetooth screen = the page's counts and an independent reading
#   of the rules, each Bands line's activity bar = the page's band share of S.act (the last rows; DSP_BTE, DSP_ACE and the edge documents of
#   that section). They need tests/fixtures/radio-pair.json and a page that has the radio-pair fields: against 0.1 they are red.
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only DSP_* globals are set.

DSP_Q="?poll=0&spin=0&intro=0&debug=1"
# --ready for a run on a served document: the boot poll has replaced the built-in sky (its apsTotal is above 0 from the first frame, so a count would be met at once); every eval then waits its own 0.9 s
DSP_RDY="window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'"
# the page's busiest channel (crowdingOf, via airQuality) as the display script prints it; the fixture loop below asks for it too (eval 2)
DSP_BZE='(async()=>{await STARCHORUS.wait(900);const b=STARCHORUS.airQuality().busiest;return b?b.band+" GHz ch "+b.channel:"";})()'
DSP_PG() { STARCHORUS_DISPLAY_PLAIN=1 sh "$R/starchorus-display.sh" --once "$1" "$2" 2>&1; }
# the page's Air drawer (airQuality) per band as "band:APs@beaconPctSum ch/co/adj ...|quietest;" ("band:-;" = no APs), and the
# display script's Air screen in the same shape (dsp_airp); both loops below ask the page for it (eval 3 of the fixture runs, eval 2 of the edge runs)
DSP_AQE='(async()=>{await STARCHORUS.wait(900);const a=STARCHORUS.airQuality();return ["2.4","5","6"].map(b=>{const x=a.bands[b];if(!x)return b+":-;";return b+":"+x.aps+"@"+x.beaconPctSum+x.top.map(t=>" "+t.ch+"/"+t.co+"/"+t.adjacent).join("")+"|"+(x.quietest?x.quietest.ch:"")+";";}).join("");})()'
# the radio-pair fields as the page holds them: stats().bluetooth as "addresses rotating fixed void" ("none" without an array), and the three band
# shares of the page's own S.act (a Map frequency -> share), each band's entries added up in the Map's order, as JSON, null for a band without one
DSP_BTE='(async()=>{await STARCHORUS.wait(900);const b=STARCHORUS.stats().bluetooth;return b?[b.addresses,b.rotating,b.fixed,b.void?1:0].join(" "):"none";})()'
DSP_ACE='(async()=>{await STARCHORUS.wait(900);const m=STARCHORUS._internals.S.act,e=m?Array.from(m.entries()):[];const f=(lo,hi)=>{let n=0,t=0;for(const [q,x] of e)if(q>=lo&&q<hi){t+=x;n++}return n?t:null};return JSON.stringify([f(2400,2500),f(4900,5925),f(5925,7200)]);})()'
dsp_airp() { DSP_PG air "$1" | awk '
  /^  (2\.4|5|6) GHz: / { cur=$1; if ($3 == "no") na[cur]=1; else { n[cur]=$3; v=$8; sub(/%$/, "", v); bp[cur]=v } }
  /^    ch [0-9]+: / { ch=$2; sub(/:/, "", ch); top[cur]=top[cur] " " ch "/" $3 "/" $6 }
  /^    least occupied: ch / { q[cur]=$4 }
  END { for (b=1; b<=3; b++) { k=(b==1?"2.4":(b==2?"5":"6")); if (na[k] || !(k in n)) printf "%s:-;", k; else printf "%s:%s@%s%s|%s;", k, n[k], bp[k], top[k], q[k] } }'; }

# ---- numbers: display summary = page stats() for every fixture (APs, bands, alarms, the four freshness stages + undated, crowding, and
# from the Clients line "(N random, K clouds)" the randomised free stations and the clouds; no parenthesis = 0 and 0)
DSP_BAD=0; DSP_N=0; DSP_SHOW=""
for DSP_J in "$F"/*.json; do
  DSP_B=$(basename "$DSP_J" .json); DSP_N=$((DSP_N + 1))
  runq "$DSP_J" "$DSP_Q" "out/$P-dsp-$DSP_B" --wait 2 --fps 0 --ready "$DSP_RDY" --eval-timeout 60 --eval '(async()=>{await STARCHORUS.wait(900);const s=STARCHORUS.stats(),f=s.fresh,b=s.bandsTotal;return JSON.stringify([s.apsTotal,b["2.4"],b["5"],b["6"],s.alarms,f.t0,f.t1,f.t2,f.t3,f.undated,s.crowding,s.randomisedFree,s.clouds]);})()' --eval "$DSP_BZE" --eval "$DSP_AQE" --eval "$DSP_BTE" --eval "$DSP_ACE" >/dev/null 2>&1
  DSP_PAGE=$(evalv "out/$P-dsp-$DSP_B.json" 1 | python3 -c 'import json,sys;print(" ".join(str(x) for x in json.load(sys.stdin)))' 2>/dev/null)
  DSP_OUT=$(DSP_PG summary "$DSP_J")
  DSP_DISP=$(printf '%s\n' "$DSP_OUT" | awk '
    /^APs [0-9]+/ { aps=$2; for (i=1;i<=NF;i++) { if ($i ~ /^2\.4:/) { sub(/^2\.4:/,"",$i); b24=$i } else if ($i ~ /^5:/) { sub(/^5:/,"",$i); b5=$i } else if ($i ~ /^6:/) { sub(/^6:/,"",$i); b6=$i } } }
    /^Open\/WEP networks: / { open=$3 }
    /^heard < 1 min / { t0=$5; t1=$11; t2=$17; t3=$21; u=0; for (i=1;i<=NF;i++) if ($i=="undated") u=$(i+1) }
    /^Crowding / { split($2,c,"/"); cr=c[1] }
    /^Clients / { for (i=1;i<=NF;i++) { if ($i ~ /^\([0-9]+$/ && $(i+1) ~ /^random/) { rn=substr($i,2) } if ($i ~ /^[0-9]+$/ && $(i+1) ~ /^clouds?\)$/) { nc=$i } } }
    END { print aps+0, b24+0, b5+0, b6+0, open+0, t0+0, t1+0, t2+0, t3+0, u+0, cr+0, rn+0, nc+0 }')
  if [ "$DSP_PAGE" != "$DSP_DISP" ]; then DSP_BAD=$((DSP_BAD + 1)); DSP_SHOW="$DSP_SHOW $DSP_B: page [$DSP_PAGE] display [$DSP_DISP];"; fi
done
if [ "$DSP_BAD" = 0 ] && [ "$DSP_N" -ge 13 ]; then row "display summary = page stats() on all $DSP_N fixtures (APs, bands, alarms, freshness stages, crowding, randomised, clouds; $DSP_BAD differ)" PASS
else row "display summary = page stats() on all $DSP_N fixtures (APs, bands, alarms, freshness stages, crowding, randomised, clouds; $DSP_BAD differ)" FAIL; fi
[ "$DSP_BAD" = 0 ] || echo "   $DSP_SHOW"

# ---- busiest channel: the display script's "busiest" = the page's crowdingOf() busiest, on every fixture AND on generated edge documents.
# crowdingOf keeps the FIRST channel with the highest overlap sum (strict ">"), bands 2.4, 5, 6, per band in the order the channels
# first appear in S.apOrder (RSSI desc, then BSSID), each sum added up in S.apOrder order. Taking jq's max_by instead
# (the LAST maximum) over channels sorted by number and summed in file order would let every tie name another channel.
# The edge documents live here, not in tests/fixtures (locally administered dummy BSSIDs); the page's answer is pinned per document
# (DSP_BZW) so a document that stops being the case it claims to be fails too. The max_by answer in brackets:
#   tie-order   2.4 ch 1 and ch 11 tie, ch 1 holds the lower BSSID            -> 2.4 GHz ch 1   [ch 11]
#   tie-band    2.4 ch 1 and 5 ch 36 tie, the 5 GHz AP has the lower BSSID    -> 2.4 GHz ch 1   [5 GHz ch 36]
#   tie-seen    ch 11 (one AP -50) ties ch 1 (two APs -70), ch 11 seen first  -> 2.4 GHz ch 11  [same; guards a "lowest channel" fix]
#   tie-sum     ch 1 = -89,-88,-84 in file order: 0.15 in S.apOrder order but 0.15000000000000002 in file order; ch 11 = 0.15
#                                                                              -> 2.4 GHz ch 11  [ch 1]
#   rssi-null   an AP without RSSI counts as -75 dBm on the page (normalizeDoc) -> 2.4 GHz ch 6   [ch 1: it counted as 1]
#   dup-bssid   one BSSID twice (the page merges it, strongest RSSI)          -> 2.4 GHz ch 6   [ch 1]
#   band-freq   band "" but freq 5180: the page's bandOf falls back to freq   -> 5 GHz ch 36    [2.4 GHz ch 1]
#   width-bad   width 60 is not a width: the page assumes 20 MHz              -> 2.4 GHz ch 1   [ch 6]
#   mac-case    "0B" vs "0a": the page lowercases BSSIDs before sorting       -> 2.4 GHz ch 1   [ch 11]
#   quiet-tie   tie-sum plus ch 6 at -40: ch 6 is the busiest, and ch 1 / ch 11 tie on the ROUNDED load (0.15), so the Air
#               block's "least occupied" is the lower channel, ch 1             -> 2.4 GHz ch 6   [Air: least occupied ch 11]
DSP_TD="out/$P-dsp-ties"; rm -rf "$DSP_TD"; mkdir -p "$DSP_TD"
dsp_doc() { # dsp_doc NAME 'AP-JSON-LIST' -> $DSP_TD/NAME.json
  printf '{"generated":1700000000,"source":"fixture","center":{"label":"edge"},"unassociated":[],"aps":[%s]}\n' "$2" > "$DSP_TD/$1.json"
}
dsp_ap() { # dsp_ap LAST-OCTET CHANNEL RSSI [BAND] [EXTRA-JSON] -> one AP object (band 2.4 when omitted, "" stays ""; RSSI "-" = no rssi field)
  dsp_r=""; [ "$3" = - ] || dsp_r="\"rssi\":$3,"
  printf '{"bssid":"02:00:00:00:00:%s","ssid":"E%s",%s"channel":%s,"band":"%s","security":"WPA2"%s}' "$1" "$1" "$dsp_r" "$2" "${4-2.4}" "${5:+,$5}"
}
dsp_doc tie-order "$(dsp_ap 01 1 -60),$(dsp_ap 02 11 -60)"
dsp_doc tie-band  "$(dsp_ap 02 1 -60),$(dsp_ap 01 36 -60 5)"
dsp_doc tie-seen  "$(dsp_ap 01 1 -70),$(dsp_ap 02 1 -70),$(dsp_ap 03 11 -50)"
dsp_doc tie-sum   "$(dsp_ap 01 1 -89),$(dsp_ap 02 1 -88),$(dsp_ap 03 1 -84),$(dsp_ap 04 11 -89),$(dsp_ap 05 11 -82)"
dsp_doc rssi-null "$(dsp_ap 01 1 -),$(dsp_ap 02 6 -70)"
dsp_doc dup-bssid "$(dsp_ap 01 1 -60),$(dsp_ap 01 1 -65),$(dsp_ap 02 6 -55)"
dsp_doc band-freq "$(dsp_ap 01 36 -40 '' '"freq":5180'),$(dsp_ap 02 1 -60)"
dsp_doc width-bad "$(dsp_ap 01 1 -40 2.4 '"width":60'),$(dsp_ap 02 6 -45)"
dsp_doc mac-case  "$(dsp_ap 0B 11 -60),$(dsp_ap 0a 1 -60)"
dsp_doc quiet-tie "$(dsp_ap 01 1 -89),$(dsp_ap 02 1 -88),$(dsp_ap 03 1 -84),$(dsp_ap 04 11 -89),$(dsp_ap 05 11 -82),$(dsp_ap 06 6 -40)"
DSP_BZW="tie-order=2.4 GHz ch 1;tie-band=2.4 GHz ch 1;tie-seen=2.4 GHz ch 11;tie-sum=2.4 GHz ch 11;rssi-null=2.4 GHz ch 6;dup-bssid=2.4 GHz ch 6;band-freq=5 GHz ch 36;width-bad=2.4 GHz ch 1;mac-case=2.4 GHz ch 1;quiet-tie=2.4 GHz ch 6"
DSP_BZN=0; DSP_BZBAD=0; DSP_BZSHOW=""; DSP_BZE0=0
for DSP_J in "$F"/*.json "$DSP_TD"/*.json; do
  DSP_B=$(basename "$DSP_J" .json); DSP_BZN=$((DSP_BZN + 1))
  case $DSP_J in
    "$DSP_TD"/*) runq "$DSP_J" "$DSP_Q" "out/$P-dspbz-$DSP_B" --wait 2 --fps 0 --ready "$DSP_RDY" --eval-timeout 60 --eval "$DSP_BZE" --eval "$DSP_AQE" >/dev/null 2>&1
                DSP_BPG=$(evalv "out/$P-dspbz-$DSP_B.json" 1) ;;
    *)          DSP_BPG=$(evalv "out/$P-dsp-$DSP_B.json" 2) ;;   # already asked in the fixture loop above
  esac
  DSP_BPR=$(DSP_PG summary "$DSP_J" | sed -n 's/^Crowding .* · busiest //p')
  [ -n "$DSP_BPG" ] || DSP_BZE0=$((DSP_BZE0 + 1))
  case $DSP_J in "$DSP_TD"/*)
    DSP_BW=$(printf '%s\n' "$DSP_BZW" | tr ';' '\n' | sed -n "s/^$DSP_B=//p")
    [ "$DSP_BPG" = "$DSP_BW" ] || { DSP_BZBAD=$((DSP_BZBAD + 1)); DSP_BZSHOW="$DSP_BZSHOW $DSP_B: page [$DSP_BPG] is not the pinned [$DSP_BW];"; } ;;
  esac
  [ "$DSP_BPG" = "$DSP_BPR" ] || { DSP_BZBAD=$((DSP_BZBAD + 1)); DSP_BZSHOW="$DSP_BZSHOW $DSP_B: page [$DSP_BPG] display [$DSP_BPR];"; }
done
DSP_BZT=$(find "$DSP_TD" -name '*.json' | wc -l | tr -d ' ')
# vacuity: all 12 fixtures + all 10 edge documents compared; only empty-none has no channel on the page
if [ "$DSP_BZBAD" = 0 ] && [ "$DSP_BZT" = 10 ] && [ "$DSP_BZN" -ge 22 ] && [ "$DSP_BZE0" = 1 ]; then row "display busiest channel = the page's crowdingOf() on $DSP_BZN documents ($DSP_BZT generated ties/edges; $DSP_BZBAD differ, $DSP_BZE0 without a channel)" PASS
else row "display busiest channel = the page's crowdingOf() on $DSP_BZN documents ($DSP_BZT generated ties/edges; $DSP_BZBAD differ, $DSP_BZE0 without a channel)" FAIL; fi
[ "$DSP_BZBAD" = 0 ] || echo "   $DSP_BZSHOW"

# ---- colours: red only for an alarm, nothing is green; GEN moves with the capture, not with the render; the version
# The alarms are the open/WEP lines, the ONE "jq incomplete" fault line of
# jq_warn (the counts may be blank) and the ONE "No new scan" line (stale_line: the collector has not written for three of its
# intervals; stamp(), which frame() calls, prints it at the end of every screen in place of the time of the scan): exactly those lines,
# in exactly those functions, are allowed besides open/WEP, and since 0.2 the ONE alert line (alert_line: the access points the firmware has reported many
# deauth/disassoc frames for; red because it is an alarm like the open/WEP line). It is pinned the way the stale line is: exactly that text, once, inside alert_line, and
# (the whole file counted too, so that a verbatim second copy in another function does not pass) once in the file, as is the stale line.
DSP_JQW='^jq_warn() { jq_healthy || log red "jq incomplete on this device -- counts may be blank. Run: sh starchorus-display.sh --selftest"; }$'
# shellcheck disable=SC2016   # literal script text
DSP_STL='    log red "No new scan for $st."'
# shellcheck disable=SC2016   # literal script text
DSP_ALR='    log red "Deauth/disassoc frames heard: $al_w"'
# the top screen's alarm line is the one its jq filter marked with "!" from the security field, not a text search
DSP_TOPR="'!'*) log red \"\${line#?}\" ;;"
dsp_redcount() {   # dsp_redcount FILE -> DSP_GREEN, DSP_RED (all red calls), DSP_REDJ, DSP_REDS, DSP_REDA (the pinned lines), DSP_REDSF, DSP_REDAF (the same two lines anywhere in the file) and DSP_REDL (red calls on no alarm) of a display script
  DSP_GREEN=$(grep -v '^[[:space:]]*#' "$1" | grep -c 'green')
  DSP_RED=$(grep -v '^[[:space:]]*#' "$1" | grep -c 'log red')
  DSP_REDJ=$(grep -v '^[[:space:]]*#' "$1" | grep -c "$DSP_JQW")
  DSP_REDS=$(awk '/^stale_line\(\) *{/,/^}/' "$1" | grep -cxF "$DSP_STL")
  DSP_REDA=$(awk '/^alert_line\(\) *{/,/^}/' "$1" | grep -cxF "$DSP_ALR")
  DSP_REDSF=$(grep -v '^[[:space:]]*#' "$1" | grep -cxF "$DSP_STL")
  DSP_REDAF=$(grep -v '^[[:space:]]*#' "$1" | grep -cxF "$DSP_ALR")
  DSP_REDL=$(grep -v '^[[:space:]]*#' "$1" | grep 'log red' | grep -v 'Open/WEP\|"Open:"' | grep -vF "$DSP_TOPR" | grep -vxF "$DSP_STL" | grep -vxF "$DSP_ALR" | grep -cv "$DSP_JQW")
}
dsp_redok() { [ "$DSP_GREEN" = 0 ] && [ "$DSP_REDL" = 0 ] && [ "$DSP_REDJ" = 1 ] && [ "$DSP_REDS" = 1 ] && [ "$DSP_REDA" = 1 ] && [ "$DSP_REDSF" = 1 ] && [ "$DSP_REDAF" = 1 ] && [ "$DSP_RED" -ge 6 ]; }
dsp_redcount starchorus-display.sh
if dsp_redok; then row "display colours: no green anywhere ($DSP_GREEN), red only on the open/WEP lines, the one jq-incomplete line, the one stale-scan line and the one alert line ($DSP_RED red calls, jq line $DSP_REDJ, stale line $DSP_REDS/$DSP_REDSF, alert line $DSP_REDA/$DSP_REDAF, $DSP_REDL not on an alarm)" PASS
else row "display colours: no green anywhere ($DSP_GREEN), red only on the open/WEP lines, the one jq-incomplete line, the one stale-scan line and the one alert line ($DSP_RED red calls, jq line $DSP_REDJ, stale line $DSP_REDS/$DSP_REDSF, alert line $DSP_REDA/$DSP_REDAF, $DSP_REDL not on an alarm)" FAIL; fi
# the controls of that pin: on copies of the display script, a red call anywhere else (in the bands screen, the alert's own wording changed, a second alert line, the alert line
# outside its function), a green call, and the alert line or the stale line copied verbatim into the bands screen each turn it red, and the unchanged copy stays green; the
# numbers of the real file are taken again afterwards
DSP_RCD="out/$P-dsp-redpin"; rm -rf "$DSP_RCD"; mkdir -p "$DSP_RCD"
cp starchorus-display.sh "$DSP_RCD/ok.sh"
awk '{ print } /^screen_bands\(\) *{/ { print "    log red \"stray\"" }' starchorus-display.sh > "$DSP_RCD/m1.sh"
# shellcheck disable=SC2016   # sed program: the display script's own text, not to be expanded here
sed 's|log red "Deauth/disassoc frames heard: \$al_w"|log red "Flood heard for $al_w"|' starchorus-display.sh > "$DSP_RCD/m2.sh"
awk '{ print } /^    log red "Deauth\/disassoc frames heard: \$al_w"$/ { print }' starchorus-display.sh > "$DSP_RCD/m3.sh"
sed 's|^alert_line() {|alert_lin2() {|' starchorus-display.sh > "$DSP_RCD/m4.sh"
awk '{ print } /^screen_bands\(\) *{/ { print "    log green \"stray\"" }' starchorus-display.sh > "$DSP_RCD/m5.sh"
# shellcheck disable=SC2016   # awk programs: the display script's own text, not to be expanded here
awk '{ print } /^screen_bands\(\) *{/ { print "    log red \"Deauth/disassoc frames heard: $al_w\"" }' starchorus-display.sh > "$DSP_RCD/m6.sh"
# shellcheck disable=SC2016
awk '{ print } /^screen_bands\(\) *{/ { print "    log red \"No new scan for $st.\"" }' starchorus-display.sh > "$DSP_RCD/m7.sh"
DSP_RCB=""
dsp_redcount "$DSP_RCD/ok.sh"; dsp_redok || DSP_RCB="$DSP_RCB ok"
for DSP_RCM in m1 m2 m3 m4 m5 m6 m7; do
  cmp -s starchorus-display.sh "$DSP_RCD/$DSP_RCM.sh" && DSP_RCB="$DSP_RCB $DSP_RCM-unchanged"
  dsp_redcount "$DSP_RCD/$DSP_RCM.sh"; ! dsp_redok || DSP_RCB="$DSP_RCB $DSP_RCM-green"
done
dsp_redcount starchorus-display.sh
if [ -z "$DSP_RCB" ]; then row "display colours bite: a red call elsewhere, the alert wording changed, a second alert line, the alert line outside its function, a green call, and the alert line or the stale line copied verbatim into another function each turn the pin red; the unchanged copy stays green" PASS
else row "display colours bite: wrong on:$DSP_RCB" FAIL; fi
# the same at run time, through the device path (stand-in LOG / LIST_PICKER that print the colour word): a WPA2/WPA3 network whose
# SSID contains Open/OPEN/WEP is NOT red, an AP with security "" (open, as the summary counts it) and a WEP one ARE, and a newline
# in an SSID cannot start a line of its own (it would otherwise forge a leading "!"); a text search in the shell would get all three wrong.
DSP_TB="out/$P-dsp-topbin"; rm -rf "$DSP_TB"; mkdir -p "$DSP_TB"
# shellcheck disable=SC2016  # the stand-in's own "$1"/"$*" are meant literally
printf '#!/bin/sh\nc=; case "$1" in red|blue) c="[$1]"; shift;; esac; printf "LOG%%s %%s\\n" "$c" "$*"\n' > "$DSP_TB/LOG"
printf '#!/bin/sh\nexit 0\n' > "$DSP_TB/LIST_PICKER"; chmod +x "$DSP_TB/LOG" "$DSP_TB/LIST_PICKER"
printf '{"generated":1700000000,"source":"fixture","unassociated":[],"aps":[%s]}\n' \
  '{"bssid":"02:00:00:00:00:01","ssid":"OpenWrt","band":"2.4","channel":6,"rssi":-50,"security":"WPA2"},{"bssid":"02:00:00:00:00:02","ssid":"Cafe","band":"2.4","channel":1,"rssi":-60,"security":""},{"bssid":"02:00:00:00:00:03","ssid":"WEPless","band":"2.4","channel":11,"rssi":-70,"security":"WPA3"},{"bssid":"02:00:00:00:00:04","ssid":"Lab","band":"5","channel":36,"rssi":-80,"security":"WEP"},{"bssid":"02:00:00:00:00:05","ssid":"x\n!Fake OPEN","band":"5","channel":40,"rssi":-85,"security":"WPA2"}' > "$DSP_TB/top.json"
DSP_TOP=$(PATH="$R/$DSP_TB:$PATH" sh "$R/starchorus-display.sh" --once top "$DSP_TB/top.json" 2>&1)
DSP_TRED=$(printf '%s\n' "$DSP_TOP" | sed -n 's/^LOG\[red\] -[0-9]* dBm  \([^ ]*\) .*/\1/p' | tr '\n' ' ')
DSP_TL=$(printf '%s\n' "$DSP_TOP" | grep -c '^LOG')
DSP_TALL=$(printf '%s\n' "$DSP_TOP" | grep -c '^')
if [ "$DSP_TRED" = "Cafe Lab " ] && [ "$DSP_TL" = 6 ] && [ "$DSP_TALL" = 6 ]; then row "display top: red = security open/WEP, not the SSID text (red: ${DSP_TRED:-none}; want Cafe Lab; $DSP_TL LOG lines of $DSP_TALL, want 6 of 6)" PASS
else row "display top: red = security open/WEP, not the SSID text (red: ${DSP_TRED:-none}; want Cafe Lab; $DSP_TL LOG lines of $DSP_TALL, want 6 of 6)" FAIL; fi
rm -rf "$DSP_TB"
DSP_SEQ=$(grep -v '^[[:space:]]*#' starchorus-display.sh | grep -c 'SEQ')
DSP_GT=$(grep -c '^gen_tick()' starchorus-display.sh)
DSP_G1=$(DSP_PG summary "$F/field-probes.json" | grep -c '^GEN 1 ')
DSP_V=$(sed -n 's/^# Version:      \([0-9][0-9A-Za-z.-]*\)$/\1/p' starchorus-display.sh | head -n 1)
if [ "$DSP_SEQ" = 0 ] && [ "$DSP_GT" = 1 ] && [ "$DSP_G1" = 1 ] && [ "$DSP_V" = 0.2.6 ]; then row "display: GEN, no SEQ (SEQ = $DSP_SEQ, gen_tick = $DSP_GT, 'GEN 1' on a first capture = $DSP_G1), version 0.2.6 [$DSP_V]" PASS; else row "display: GEN/SEQ/version off (SEQ $DSP_SEQ, gt $DSP_GT, g1 $DSP_G1, v $DSP_V)" FAIL; fi
# GEN counts captures: two different `generated` in one process give 1 then 2 (the function, lifted out of the script, fed the
# "generated" of two documents as the screens feed it: the value of the gen record of their one jq program)
DSP_T=$(mktemp -d 2>/dev/null || echo "out/dsp-tmp"); mkdir -p "$DSP_T"
sed -n '/^gen_tick()/p' starchorus-display.sh > "$DSP_T/lib.sh"
printf '{"generated":100,"aps":[]}' > "$DSP_T/a.json"; printf '{"generated":105,"aps":[]}' > "$DSP_T/b.json"
DSP_GA=$(jq -r '.generated // empty' "$DSP_T/a.json"); DSP_GB=$(jq -r '.generated // empty' "$DSP_T/b.json")
DSP_GEN=$(sh -c '. "$1"; GEN=0; LASTG=; gen_tick "$2"; a=$GEN; gen_tick "$2"; b=$GEN; gen_tick "$3"; c=$GEN; gen_tick ""; d=$GEN; echo "$a $b $c $d"' sh "$DSP_T/lib.sh" "$DSP_GA" "$DSP_GB" 2>/dev/null)
rowif "display GEN moves only when the capture time changes (same capture twice, then a new one, then none: $DSP_GEN, want 1 1 2 2)" [ "$DSP_GEN" = "1 1 2 2" ]
rm -rf "$DSP_T" 2>/dev/null

# ---- the optional template: only numbers are substituted; unset = no line
DSP_TPL=$(STARCHORUS_DISPLAY_TEMPLATE='A{aps} B{b24}/{b5}/{b6} C{crowding} O{open} G{gen}' DSP_PG summary "$F/field-probes.json" | tail -n 1)
DSP_NOT=$(DSP_PG summary "$F/field-probes.json" | grep -c 'A60')
if [ "$DSP_TPL" = "A60 B25/32/3 C4 O20 G1" ] && [ "$DSP_NOT" = 0 ]; then row "display template line: [$DSP_TPL] (unset: $DSP_NOT extra lines)" PASS
else row "display template line: [$DSP_TPL] (unset: $DSP_NOT extra lines)" FAIL; fi

# ---- the Air quality LOG block = the page's airQuality() on every fixture and every edge document: per band the AP count, the beacon
# estimate (beaconPctSum: rounded per channel, then summed), the top three channels with co/adjacent counts, the least occupied channel.
# The edge documents hold what field-probes does not: a missing RSSI, a duplicate BSSID, a band known only from freq, a ranking that
# differs between raw load and rounded beacon estimate.
# The page's answer for the edge documents is pinned too (DSP_AQW), so an edge document that stops being its case fails.
DSP_AQW="rssi-null=2.4:2@3.6 6/1/0 1/1/0|11;5:-;6:-;
dup-bssid=2.4:2@3.6 6/1/0 1/1/0|11;5:-;6:-;
band-freq=2.4:1@1.8 1/1/0|6;5:1@0.3 36/1/0|40;6:-;
quiet-tie=2.4:6@10.6 6/1/0 1/3/0 11/2/0|1;5:-;6:-;"
DSP_AN=0; DSP_ABAD=0; DSP_ASHOW=""
for DSP_J in "$F"/*.json "$DSP_TD"/*.json; do
  DSP_B=$(basename "$DSP_J" .json); DSP_AN=$((DSP_AN + 1))
  case $DSP_J in "$DSP_TD"/*) DSP_AW=$(evalv "out/$P-dspbz-$DSP_B.json" 2) ;; *) DSP_AW=$(evalv "out/$P-dsp-$DSP_B.json" 3) ;; esac
  DSP_AP=$(dsp_airp "$DSP_J")
  DSP_AX=$(printf '%s\n' "$DSP_AQW" | sed -n "s/^$DSP_B=//p")
  if [ -n "$DSP_AX" ] && [ "$DSP_AW" != "$DSP_AX" ]; then DSP_ABAD=$((DSP_ABAD + 1)); DSP_ASHOW="$DSP_ASHOW $DSP_B: page [$DSP_AW] is not the pinned [$DSP_AX];"; fi
  if [ -z "$DSP_AW" ] || [ "$DSP_AW" != "$DSP_AP" ]; then DSP_ABAD=$((DSP_ABAD + 1)); DSP_ASHOW="$DSP_ASHOW $DSP_B: page [$DSP_AW] display [$DSP_AP];"; fi
done
DSP_APN=$(printf '%s\n' "$DSP_AQW" | grep -c '=')
if [ "$DSP_ABAD" = 0 ] && [ "$DSP_AN" -ge 22 ] && [ "$DSP_APN" = 4 ]; then row "display air block = the page's airQuality() on $DSP_AN documents (APs, beacon estimate, top three with co/adjacent, least occupied per band; $DSP_APN edge answers pinned; $DSP_ABAD differ)" PASS
else row "display air block = the page's airQuality() on $DSP_AN documents (APs, beacon estimate, top three with co/adjacent, least occupied per band; $DSP_APN edge answers pinned; $DSP_ABAD differ)" FAIL; fi
[ "$DSP_ABAD" = 0 ] || echo "   $DSP_ASHOW"
DSP_AB=$(DSP_PG air "$F/field-probes.json" | grep -c 'beacons >= .*% (est.)')
rowif "display air block names the estimate and its assumptions ($DSP_AB band lines with (est.), assumptions line present: $(DSP_PG air "$F/field-probes.json" | grep -c '^estimate: 1 beacon per AP / 102.4 ms'))" [ "$DSP_AB" = 3 ]

# ---- no new output path: the display script only appends LOG lines (no LED, no buzzer, no menu of its own beyond LIST_PICKER, nothing sent)
# LED not preceded by a letter: the device command LED (and any LED_* name) is caught, the word FAILED of the selftest verdict is not
DSP_OUT=$(grep -v '^[[:space:]]*#' starchorus-display.sh | grep -cE '(^|[^A-Za-z])LED|VIBRATE|RINGTONE|BUZZ|curl|wget|nc |sendmail|ssh |scp ')
rowif "display: no LED/buzzer/network command anywhere ($DSP_OUT); the LOG is append-only" [ "$DSP_OUT" = 0 ]

# ---- the radio pair on the Overview: the Bluetooth figure on the summary's APs line, the Bluetooth screen
# and the activity bars of the Bands screen, held against the page and against an independent reading of the rules (DSP_RO, python3).
#   the page's side: stats().bluetooth (addresses rotating fixed void; "none" without an array) and the three band shares of its own S.act
#   (eval 4 and 5 of the fixture loop above; eval 1 and 2 of the runs below). A page that has neither answers "none" and null, so on a capture
#   with Bluetooth or activity these rows are red against it, never vacuously green.
#   the documents: every fixture (radio-pair.json is the one with the array and the activity) and the edge documents of this section, generated
#   here with locally administered dummy addresses (tests/fixtures is the contract corpus):
#     bt-cap     300 records, strongest first: the page keeps 256, the Overview says 256+
#     bt-void    bt_window 0 with three held records: the records and the line that says they are held
#     bt-void0   bt_window 0, an empty array: 0 addresses and that line
#     bt-active  the capture of the ACTIVE scan with the array: the page's ACTIVE line instead of "rx only", one company line fewer
#     bt-wide    120 addresses of one company with a 48-character name at -127 dBm and five of another by id: no line over 40 columns
#     bt-ids     an id without a name, no company at all, a name with two ids, a name with a line feed: the five ways a company line is named
#     bt-many    fourteen records in eleven companies (five by name, five by id, one with no company at all), strongest first: more groups than the screen has lines, so
#                the cap of seven company lines takes effect (no other document has more than six groups); bt-many-void (bt_window 0), bt-many-active (the ACTIVE scan) and
#                bt-many-av (both) are the same records under the two things that each take a line of the screen's budget: they show six, six and five company lines, and
#                every one of the four is ten lines, twelve with the frame's two
#     bt-fixed   only fixed addresses (public, random-static): 0 rotating, the singular for one
#     bt-types   records of the wrong types: only the objects with a numeric rssi count (a string that is no number: the page reads a numeric string such as "-60"
#                through its own numOrNull and the Overview does not; the collector writes numbers, so the edge documents keep to strings both reject)
#     act-edge   activity on 2.4 GHz only, an entry outside every band, a share over 1, a share of 0, a frequency that is no number: one bar and the note
#     act-all    activity on all three bands (6 GHz included): three bars and the note
# The gate: these rows need tests/fixtures/radio-pair.json (tools/gen-testdata.py --radio writes it, the page track delivers it). Until it is there the
# first row is red (the one thing missing, said once) and the rows that need it are NOT COVERED; they are never skipped quietly and never green without it.
if [ ! -s "$F/radio-pair.json" ]; then
  row "radio-pair fixture present: tests/fixtures/radio-pair.json (tools/gen-testdata.py --radio) -- the radio-pair rows need it" FAIL
  notcov "display BT figure = page (needs tests/fixtures/radio-pair.json)"
  notcov "display bluetooth screen (needs tests/fixtures/radio-pair.json)"
  notcov "display bands activity (needs tests/fixtures/radio-pair.json)"
  notcov "display radio parity bites (needs tests/fixtures/radio-pair.json)"
else
row "radio-pair fixture present: tests/fixtures/radio-pair.json (tools/gen-testdata.py --radio) -- the radio-pair rows need it" PASS
DSP_RD="out/$P-dsp-radio"; rm -rf "$DSP_RD"; mkdir -p "$DSP_RD"
python3 -B - "$DSP_RD" <<'DSPPY'
import json, sys
d = sys.argv[1]; G = 1789300000
def doc(name, bt=None, act=None, center=None, source="recon-db"):
    c = {"label": "edge"}
    if bt is not None: c.update({"bt_window": 6, "bt_hold": 120})
    c.update(center or {})
    o = {"generated": G, "source": source, "center": c, "unassociated": [],
         "aps": [{"bssid": "02:00:00:00:00:01", "ssid": "Edge-A", "rssi": -50, "channel": 6, "band": "2.4GHz", "freq": 2437, "security": "WPA2", "clients": []},
                 {"bssid": "02:00:00:00:00:02", "ssid": "Edge-B", "rssi": -60, "channel": 36, "band": "5GHz", "freq": 5180, "security": "WPA3", "clients": []}]}
    if bt is not None: o["bluetooth"] = bt
    if act is not None: o["activity"] = act
    json.dump(o, open("%s/%s.json" % (d, name), "w"), indent=1)
def rec(i, rssi, t="random-resolvable", **kw):
    r = {"addr": "42:00:00:%02x:%02x:%02x" % (i >> 16 & 255, i >> 8 & 255, i & 255), "addr_type": t, "rssi": rssi, "reports": 1, "last_seen": G - 3}
    r.update(kw); return r
doc("bt-cap", [rec(i, -40 - i // 4) for i in range(300)])
held = [rec(1, -50, company=65535, company_name="Maker A"), rec(2, -58, company=65535, company_name="Maker A"), rec(3, -77, "random-static", name="Sensor-1")]
doc("bt-void", held, center={"bt_window": 0})
doc("bt-void0", [], center={"bt_window": 0})
doc("bt-active", held + [rec(4, -70, company=7, company_name="Maker B")], source="iw-scan-ACTIVE")
doc("bt-wide", [rec(i, -100 if i == 0 else -127, company=1, company_name="A very long company name of forty-eight characters!!") for i in range(120)]
    + [rec(1000 + i, -90 - i, "public", company=123) for i in range(5)])
doc("bt-ids", [rec(1, -45, company=65535), rec(2, -50), rec(3, -52, company=7, company_name="Maker B"), rec(4, -53, company=8, company_name="Maker B"),
               rec(5, -61, company=9, company_name="Line\nFeed"), rec(6, -70, company_name="   ", company=70000), rec(7, -72, company=0)])
doc("bt-fixed", [rec(1, -50, "public", company=65535, company_name="Maker A")])
many = [rec(i, -40 - i, **({"company": 100 + i, "company_name": "Maker %d" % i} if i % 3 == 0 else {"company": 300 + i} if i % 3 == 1 else {})) for i in range(14)]
doc("bt-many", many)
doc("bt-many-void", many, center={"bt_window": 0})
doc("bt-many-active", many, source="iw-scan-ACTIVE")
doc("bt-many-av", many, center={"bt_window": 0}, source="iw-scan-ACTIVE")
doc("bt-types", [rec(1, -50, company_name=42), rec(2, -55, "public", company=[1]), {"addr": "02:00:00:00:00:03", "rssi": "loud"},
                 "text", None, 3, rec(4, -65, "weird")])
doc("act-edge", [], act=[{"freq": 2412, "share": 0.5}, {"freq": 2437, "share": 0.25}, {"freq": 100, "share": 0.1}, {"freq": 2462, "share": 1.5},
                         {"freq": 2467, "share": 0}, {"freq": "wide", "share": 0.2}])
act = [{"freq": 2412, "share": 0.3}, {"freq": 2437, "share": 0.2}, {"freq": 5180, "share": 0.2}, {"freq": 5500, "share": 0.1},
       {"freq": 5955, "share": 0.15}, {"freq": 6975, "share": 0.05}]
doc("act-all", [rec(1, -50)], act=act)
DSPPY
cat > "$DSP_RD/oracle.py" <<'DSPORACLE'
#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""tools/regress.d/display-parity.sh, the radio pair: an independent reading of the specification (section 4 of the radio-pair design) that
the display script's Bluetooth screen, the Bluetooth figure of the summary and the activity bars of the Bands screen are held against.
usage: oracle.py MANIFEST [--self]     one document per line, tab separated:  name  document  page-bluetooth  page-activity  summary-out  bluetooth-out  bands-out
  page-bluetooth: stats().bluetooth as "addresses rotating fixed void", or "none" (no array);  page-activity: the page's three band shares
  (S.act summed per band, 2400-2499 / 4900-5924 / 5925-7199 MHz) as JSON, null for a band without an entry. With --self the two page columns are
  ignored and worked out from the document by the same rules (the page's normBt and normAct): the oracle then needs no page, which is how the
  row that proves it can fail runs it.
Prints three lines, FIG / SCR / BND:  "<bad> <documents> <with the thing> <detail>" -- the caller judges them. Reads files, writes nothing."""
import json, math, re, sys

WS = "\t\n\x0b\x0c\r \x85\xa0                　﻿"
ACTIVE_LINE = "ACTIVE SCAN · the collector sent probe requests"

def rnd(x):                      # jq's round: half away from zero
    return int(math.floor(abs(x) + 0.5)) * (1 if x >= 0 else -1)

def isnum(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)

def btlist(doc):
    b = doc.get("bluetooth")
    if not isinstance(b, list):
        return None
    return [r for r in b if isinstance(r, dict) and isnum(r.get("rssi"))][:256]

def company(r):
    n = r.get("company_name")
    if isinstance(n, str) and n.strip(WS) != "":
        return n.strip(WS)
    c = r.get("company")
    if isnum(c) and 0 <= c <= 65535 and c == rnd(c):
        return "company id %d" % c
    return "company not advertised"

def age_words(s):
    if s < 120: return "%d s" % s
    if s < 7200: return "%d min" % (s // 60)
    return "%d h" % (s // 3600)

def bt_screen(doc):
    src = doc.get("source")
    active = isinstance(src, str) and "active" in src.lower()
    out = []
    if active:
        out += ["Bluetooth LE (GEN 1)", ACTIVE_LINE]; mx = 6
    else:
        out += ["Bluetooth LE (GEN 1)  rx only"]; mx = 7
    L = btlist(doc)
    if L is None:
        return out + ["No Bluetooth in this scan.", "Turn it on in Settings > Bluetooth."]
    c = doc.get("center") if isinstance(doc.get("center"), dict) else {}
    void = c.get("bt_window") == 0 and isinstance(c.get("bt_window"), int) and not isinstance(c.get("bt_window"), bool)
    n = len(L)
    fixed = sum(1 for r in L if r.get("addr_type") in ("public", "random-static"))
    word = "addresses"
    ns = str(n)
    if n >= 256: ns = "256+"
    elif n == 1: word = "address"
    out.append("%s %s (%d rotating, %d fixed)" % (ns, word, n - fixed, fixed))
    if n > 0:
        h = c.get("bt_hold")
        h = h if isinstance(h, int) and not isinstance(h, bool) and 0 < h < 100000 else 120
        out.append("Strongest by company (last %s):" % age_words(h))
        if void: mx -= 1
        g = {}
        for r in L:
            k = company(r); v = rnd(r["rssi"])
            e = g.setdefault(k, [0, v]); e[0] += 1; e[1] = max(e[1], v)
        rows = sorted(g.items(), key=lambda kv: (-kv[1][1], kv[0]))[:7][:mx]
        for k, (cnt, mxr) in rows:
            name = k.replace("\n", " ")[:22].rstrip(WS)
            out.append(" %d dBm  %s  (%d)" % (mxr, name, cnt))
    if void:
        out.append("No valid scan now; showing held records.")
    return out

def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read().rstrip("\n").split("\n")

def self_bt(doc):
    L = btlist(doc)
    if L is None:
        return "none"
    c = doc.get("center") if isinstance(doc.get("center"), dict) else {}
    fixed = sum(1 for r in L if r.get("addr_type") in ("public", "random-static"))
    return "%d %d %d %d" % (len(L), len(L) - fixed, fixed, 1 if c.get("bt_window") == 0 and isnum(c.get("bt_window")) else 0)

def self_act(doc):
    a = doc.get("activity")
    e = [x for x in a if isinstance(x, dict) and isnum(x.get("freq")) and isnum(x.get("share")) and 0 < x["share"] <= 1][:69] if isinstance(a, list) else []
    def band(lo, hi):
        v = [x["share"] for x in e if lo <= x["freq"] < hi]
        return sum(v) if v else None
    return json.dumps([band(2400, 2500), band(4900, 5925), band(5925, 7200)])

SELF = len(sys.argv) > 2 and sys.argv[2] == "--self"
fig = [0, 0, 0, []]; scr = [0, 0, 0, []]; bnd = [0, 0, 0, []]
apsre = re.compile(r"^APs \d+   ·   2\.4:\d+  5:\d+  6:\d+(?:  BT (\d+\+?))?$")
bandre = re.compile(r"^  (2\.4|5|6) GHz: \d+ AP\(s\)(?:  act ([#-]{8}) (\d+)%)?$")
for line in open(sys.argv[1], encoding="utf-8"):
    if not line.strip():
        continue
    name, docp, pbt, pact, sump, btp, bndp = line.rstrip("\n").split("\t")
    doc = json.load(open(docp, encoding="utf-8"))
    if SELF: pbt, pact = self_bt(doc), self_act(doc)
    # ---- the figure on the APs line
    fig[1] += 1
    aps = [l for l in read(sump) if l.startswith("APs ")]
    m = apsre.match(aps[0]) if len(aps) == 1 else None
    if m is None:
        fig[0] += 1; fig[3].append("%s: no APs line in the shape" % name)
    else:
        shown = m.group(1)
        if pbt == "none":
            if shown is not None: fig[0] += 1; fig[3].append("%s: page has no array, display says BT %s" % (name, shown))
        else:
            fig[2] += 1
            addr = int(pbt.split()[0])
            want = "256+" if addr >= 256 else str(addr)
            if shown != want: fig[0] += 1; fig[3].append("%s: page %d addresses, display BT %s" % (name, addr, shown))
    # ---- the Bluetooth screen
    scr[1] += 1
    got = read(btp); exp = bt_screen(doc)
    if got != exp:
        scr[0] += 1; scr[3].append("%s: display %r, reading %r" % (name, got, exp))
    elif len(got) > 10:
        scr[0] += 1; scr[3].append("%s: %d lines (10 with the frame's two = 12)" % (name, len(got)))
    elif any(len(l) > 40 for l in got if l != ACTIVE_LINE):
        scr[0] += 1; scr[3].append("%s: a line over 40 columns" % name)
    if pbt != "none":
        scr[2] += 1
        a, r, f, v = [int(x) for x in pbt.split()]
        cnt = [l for l in got if re.match(r"^(\d+\+?) address(es)? \(", l)]
        want = "%s %s (%d rotating, %d fixed)" % ("256+" if a >= 256 else a, "address" if a == 1 else "addresses", r, f)
        if cnt != [want]: scr[0] += 1; scr[3].append("%s: page says %r, display %r" % (name, want, cnt))
        if (v == 1) != any(l == "No valid scan now; showing held records." for l in got):
            scr[0] += 1; scr[3].append("%s: the void line and the page's void disagree" % name)
    elif got[-2:] != ["No Bluetooth in this scan.", "Turn it on in Settings > Bluetooth."]:
        scr[0] += 1; scr[3].append("%s: no array on the page, display does not say so" % name)
    # ---- the activity bars
    bnd[1] += 1
    bl = read(bndp)
    bands = [l for l in bl if re.match(r"^  (2\.4|5|6) GHz: ", l)]
    sh = json.loads(pact)
    ok = len(bands) == 3
    bars = 0
    if ok:
        for l, key, s in zip(bands, ("2.4", "5", "6"), sh):
            m = bandre.match(l)
            if m is None or m.group(1) != key: ok = False; break
            if s is None:
                if m.group(2) is not None: ok = False; break
            else:
                n8 = int(math.floor(s * 8 + 0.5)); pct = int(math.floor(s * 100 + 0.5))
                if m.group(2) != "#" * n8 + "-" * (8 - n8) or int(m.group(3)) != pct: ok = False; break
                bars += 1
    note = [l for l in bl if l == "act = share of frames heard (relative)"]
    if bars: bnd[2] += 1
    if not ok or len(note) != (1 if bars else 0) or any(len(l) > 40 for l in bl):
        bnd[0] += 1; bnd[3].append("%s: page %s, display %r, note x%d" % (name, pact, bands, len(note)))
for tag, v in (("FIG", fig), ("SCR", scr), ("BND", bnd)):
    print("%s %d %d %d %s" % (tag, v[0], v[1], v[2], "; ".join(v[3][:3]).replace("\n", " ")))
DSPORACLE
DSP_RMAN="$DSP_RD/manifest.tsv"; : > "$DSP_RMAN"; DSP_RN=0
DSP_RTAB=$(printf '\t')
dsp_rd_one() {   # dsp_rd_one NAME DOCUMENT PAGE-BLUETOOTH PAGE-ACTIVITY: the three screens of the display script on DOCUMENT -> one manifest line
  DSP_RN=$((DSP_RN + 1))
  DSP_PG summary "$2" > "$DSP_RD/$1.summary"; DSP_PG bluetooth "$2" > "$DSP_RD/$1.bluetooth"; DSP_PG bands "$2" > "$DSP_RD/$1.bands"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$DSP_RD/$1.summary" "$DSP_RD/$1.bluetooth" "$DSP_RD/$1.bands" >> "$DSP_RMAN"
}
for DSP_J in "$F"/*.json; do
  DSP_B=$(basename "$DSP_J" .json)
  dsp_rd_one "$DSP_B" "$DSP_J" "$(evalv "out/$P-dsp-$DSP_B.json" 4)" "$(evalv "out/$P-dsp-$DSP_B.json" 5)"
done
for DSP_J in "$DSP_RD"/*.json; do
  DSP_B=$(basename "$DSP_J" .json)
  runq "$DSP_J" "$DSP_Q" "out/$P-dsprd-$DSP_B" --wait 2 --fps 0 --ready "$DSP_RDY" --eval-timeout 60 --eval "$DSP_BTE" --eval "$DSP_ACE" >/dev/null 2>&1
  dsp_rd_one "$DSP_B" "$DSP_J" "$(evalv "out/$P-dsprd-$DSP_B.json" 1)" "$(evalv "out/$P-dsprd-$DSP_B.json" 2)"
done
DSP_RO=$(python3 -B -I "$DSP_RD/oracle.py" "$DSP_RMAN" 2>&1)
dsp_ro() { printf '%s\n' "$DSP_RO" | sed -n "s/^$1 //p"; }   # the line of FIG, SCR or BND: "bad documents with-it detail"
DSP_FIG=$(dsp_ro FIG); DSP_SCR=$(dsp_ro SCR); DSP_BND=$(dsp_ro BND)
# the edge documents are what they claim to be: the page's own answers for the ones that decide the rows are pinned
DSP_PIN=""
dsp_pin() { DSP_PX=$(grep "^$1$DSP_RTAB" "$DSP_RMAN" | cut -f"$2"); [ "$DSP_PX" = "$3" ] || DSP_PIN="$DSP_PIN $1[$DSP_PX != $3]"; }
dsp_pin bt-cap 3 "256 256 0 0"; dsp_pin bt-void 3 "3 2 1 1"; dsp_pin bt-void0 3 "0 0 0 1"; dsp_pin bt-fixed 3 "1 0 1 0"; dsp_pin bt-types 3 "3 2 1 0"
dsp_pin radio-pair 3 "9 7 2 0"
dsp_pin bt-many 3 "14 14 0 0"; dsp_pin bt-many-void 3 "14 14 0 1"; dsp_pin bt-many-active 3 "14 14 0 0"; dsp_pin bt-many-av 3 "14 14 0 1"
# the cap, counted on the screens themselves and not only through the oracle: exactly 7, 6, 6 and 5 company lines (a company line is the only line that holds ' dBm  '), and
# with the frame's two lines (Last scan, the keys) at most 12 lines in all. The documents have eleven companies, so a cap that is not applied gives 11, 10, 10 and 9.
DSP_CAP=""
dsp_cap() {   # dsp_cap NAME WANT
  DSP_CN=$(grep -c ' dBm  ' "$DSP_RD/$1.bluetooth"); DSP_CL=$(grep -c . "$DSP_RD/$1.bluetooth")
  { [ "$DSP_CN" = "$2" ] && [ $((DSP_CL + 2)) -le 12 ]; } || DSP_CAP="$DSP_CAP $1[$DSP_CN company lines (want $2), $((DSP_CL + 2)) lines with the frame (at most 12)]"
}
dsp_cap bt-many 7; dsp_cap bt-many-void 6; dsp_cap bt-many-active 6; dsp_cap bt-many-av 5
dsp_pin act-edge 4 "[0.75,null,null]"; dsp_pin act-all 4 "[0.5,0.30000000000000004,0.2]"
dsp_f() {   # "bad documents with-it detail" -> its first three words
  read -r DSP_F1 DSP_F2 DSP_F3 _ <<DSPEOF
$1
DSPEOF
  DSP_F1=${DSP_F1:-x}; DSP_F2=${DSP_F2:-0}; DSP_F3=${DSP_F3:-0}
}
dsp_f "$DSP_FIG"; DSP_FB="$DSP_F1/$DSP_F2/$DSP_F3"
if [ "$DSP_F1" = 0 ] && [ "$DSP_F2" -ge 28 ] && [ "$DSP_F3" -ge 14 ] && [ -z "$DSP_PIN" ]; then
  row "display BT figure = page: the summary's 'BT n' = stats().bluetooth.addresses on every capture with an array ('256+' at the cap), absent without ($DSP_FB bad/documents/with array; edge answers pinned)" PASS
else row "display BT figure = page ($DSP_FB bad/documents/with array; pins:${DSP_PIN:- ok}) $DSP_FIG" FAIL; fi
dsp_f "$DSP_SCR"; DSP_SB="$DSP_F1/$DSP_F2/$DSP_F3"
if [ "$DSP_F1" = 0 ] && [ "$DSP_F2" -ge 28 ] && [ "$DSP_F3" -ge 14 ] && [ -z "$DSP_CAP" ]; then
  row "display bluetooth screen: the eighth screen on $DSP_F2 captures = an independent reading (count line = the page's addresses/rotating/fixed, companies by strongest signal, 'company id N', 'company not advertised', the cap of 256 addresses, a void window, the ACTIVE line, the empty-capture lines), the cap of company lines on eleven companies = exactly 7 (plain), 6 (void), 6 (ACTIVE) and 5 (both), 10 lines and the frame's two, none over 40 columns ($DSP_SB bad/documents/with array)" PASS
else row "display bluetooth screen ($DSP_SB bad/documents/with array; the cap:${DSP_CAP:- ok}) $DSP_SCR" FAIL; fi
dsp_f "$DSP_BND"; DSP_BB="$DSP_F1/$DSP_F2/$DSP_F3"
if [ "$DSP_F1" = 0 ] && [ "$DSP_F2" -ge 28 ] && [ "$DSP_F3" -ge 3 ]; then
  row "display bands activity: each band's bar and whole percent = the page's band share of S.act on $DSP_F2 captures, the note line only with a bar, none over 40 columns ($DSP_BB bad/documents/with a bar)" PASS
else row "display bands activity ($DSP_BB bad/documents/with a bar) $DSP_BND" FAIL; fi
# the three rows can fail (convention 1): the same oracle on the radio-pair outputs with one fault each is red in its own row and in no other,
# and green on the unbroken ones. It runs with --self (the page's numbers worked out from the document), so this row proves the oracle and the
# display script and does not depend on the page. field 5 = the summary, 6 = the Bluetooth screen, 7 = the Bands screen of the manifest line
DSP_RM="$DSP_RD/mut"; mkdir -p "$DSP_RM"
DSP_RL=$(grep "^radio-pair$DSP_RTAB" "$DSP_RMAN")
dsp_bite() {   # dsp_bite TAG FIELD 'AWK-PROGRAM' -> "FIG=n SCR=n BND=n" of the oracle on radio-pair with that output run through the program
  _dsb_src=$(printf '%s\n' "$DSP_RL" | cut -f"$2")
  awk "$3" "$_dsb_src" > "$DSP_RM/$1.out"
  printf '%s\n' "$DSP_RL" | awk -F'\t' -v OFS='\t' -v f="$2" -v p="$DSP_RM/$1.out" '{ $f = p; print }' > "$DSP_RM/$1.tsv"
  python3 -B -I "$DSP_RD/oracle.py" "$DSP_RM/$1.tsv" --self 2>&1 | awk '{ printf "%s%s=%s", (NR > 1 ? " " : ""), $1, $2 }'
}
DSP_BK=0; DSP_BS=""
dsp_bt() { [ "$(dsp_bite "$1" "$2" "$3")" = "$4" ] && DSP_BK=$((DSP_BK + 1)) || DSP_BS="$DSP_BS $1[$(dsp_bite "$1" "$2" "$3") want $4]"; }   # dsp_bt TAG FIELD PROGRAM WANT
dsp_bt control 5 '{ print }' "FIG=0 SCR=0 BND=0"
dsp_bt fig 5 '{ sub(/  BT [0-9]+\+?$/, "  BT 99") } 1' "FIG=1 SCR=0 BND=0"
dsp_bt count 6 '/ dBm  / && !d { sub(/\([0-9]+\)$/, "(77)"); d = 1 } 1' "FIG=0 SCR=1 BND=0"
dsp_bt cell 7 '/ act [#-]+ / && !d { if (sub(/ act #/, " act -")) d = 1; else if (sub(/ act -/, " act #")) d = 1 } 1' "FIG=0 SCR=0 BND=1"
# shellcheck disable=SC2016   # awk program, $0 is awk's
dsp_bt note 7 '$0 != "act = share of frames heard (relative)"' "FIG=0 SCR=0 BND=1"
# the same on the cap document: one company line more than the cap allows (an eighth, as a screen with bt_max raised would print) is red in the screen row only
DSP_RL0=$DSP_RL; DSP_RL=$(grep "^bt-many$DSP_RTAB" "$DSP_RMAN")
dsp_bt capcontrol 6 '{ print }' "FIG=0 SCR=0 BND=0"
dsp_bt cap 6 '{ print } / dBm  / { n++ } n == 7 && !d { print " -99 dBm  Maker Z  (1)"; d = 1 }' "FIG=0 SCR=1 BND=0"
DSP_RL=$DSP_RL0
if [ "$DSP_BK" = 7 ]; then row "display radio parity bites: the oracle is red for a BT figure of 99, a company count of 77, a flipped bar cell, a missing note line and an eighth company line over the cap, each in its own row only, green on the unbroken outputs ($DSP_BK/7)" PASS
else row "display radio parity bites ($DSP_BK/7):$DSP_BS" FAIL; fi
fi
