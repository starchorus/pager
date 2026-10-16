# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/display-parity.sh -- the Overview (starchorus-display.sh) says what the page says.
#   the numbers of `sh starchorus-display.sh --once summary <fixture>` = the page's stats() for every fixture (the randomised free
#   stations and the random clouds of §8.8a included) · red only for an alarm · GEN instead of SEQ ·
#   the Air quality LOG block = the page's airQuality() · the optional template · no new output path ·
#   the busiest channel = the page's crowdingOf() on every fixture and on generated tie/edge documents ·
#   the whole Air block (AP count, beacon estimate, top channels, least occupied) = airQuality() on the same documents ·
#   the top screen's red = the security field, never the SSID text
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only DSP_* globals are set.

DSP_Q="?poll=0&spin=0&intro=0&debug=1"
# the page's busiest channel (crowdingOf, via airQuality) as the display script prints it; the fixture loop below asks for it too (eval 2)
DSP_BZE='(async()=>{await STARCHORUS.wait(900);const b=STARCHORUS.airQuality().busiest;return b?b.band+" GHz ch "+b.channel:"";})()'
DSP_PG() { STARCHORUS_DISPLAY_PLAIN=1 sh "$R/starchorus-display.sh" --once "$1" "$2" 2>&1; }
# the page's Air drawer (airQuality) per band as "band:APs@beaconPctSum ch/co/adj ...|quietest;" ("band:-;" = no APs), and the
# display script's Air screen in the same shape (dsp_airp); both loops below ask the page for it (eval 3 of the fixture runs, eval 2 of the edge runs)
DSP_AQE='(async()=>{await STARCHORUS.wait(900);const a=STARCHORUS.airQuality();return ["2.4","5","6"].map(b=>{const x=a.bands[b];if(!x)return b+":-;";return b+":"+x.aps+"@"+x.beaconPctSum+x.top.map(t=>" "+t.ch+"/"+t.co+"/"+t.adjacent).join("")+"|"+(x.quietest?x.quietest.ch:"")+";";}).join("");})()'
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
  runq "$DSP_J" "$DSP_Q" "out/$P-dsp-$DSP_B" --wait 2 --fps 0 --eval-timeout 60 --eval '(async()=>{await STARCHORUS.wait(900);const s=STARCHORUS.stats(),f=s.fresh,b=s.bandsTotal;return JSON.stringify([s.apsTotal,b["2.4"],b["5"],b["6"],s.alarms,f.t0,f.t1,f.t2,f.t3,f.undated,s.crowding,s.randomisedFree,s.clouds]);})()' --eval "$DSP_BZE" --eval "$DSP_AQE" >/dev/null 2>&1
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
    "$DSP_TD"/*) runq "$DSP_J" "$DSP_Q" "out/$P-dspbz-$DSP_B" --wait 2 --fps 0 --eval-timeout 60 --eval "$DSP_BZE" --eval "$DSP_AQE" >/dev/null 2>&1
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
# in exactly those functions, are allowed besides open/WEP.
DSP_JQW='^jq_warn() { jq_healthy || log red "jq incomplete on this device -- counts may be blank. Run: sh starchorus-display.sh --selftest"; }$'
# shellcheck disable=SC2016   # literal script text
DSP_STL='    log red "No new scan for $st."'
DSP_GREEN=$(grep -v '^[[:space:]]*#' starchorus-display.sh | grep -c 'green')
DSP_RED=$(grep -v '^[[:space:]]*#' starchorus-display.sh | grep -c 'log red')
DSP_REDJ=$(grep -v '^[[:space:]]*#' starchorus-display.sh | grep -c "$DSP_JQW")
DSP_REDS=$(awk '/^stale_line\(\) *{/,/^}/' starchorus-display.sh | grep -cxF "$DSP_STL")
# the top screen's alarm line is the one its jq filter marked with "!" from the security field, not a text search
DSP_TOPR="'!'*) log red \"\${line#?}\" ;;"
DSP_REDL=$(grep -v '^[[:space:]]*#' starchorus-display.sh | grep 'log red' | grep -v 'Open/WEP\|"Open:"' | grep -vF "$DSP_TOPR" | grep -vxF "$DSP_STL" | grep -cv "$DSP_JQW")
if [ "$DSP_GREEN" = 0 ] && [ "$DSP_REDL" = 0 ] && [ "$DSP_REDJ" = 1 ] && [ "$DSP_REDS" = 1 ] && [ "$DSP_RED" -ge 5 ]; then row "display colours: no green anywhere ($DSP_GREEN), red only on the open/WEP lines, the one jq-incomplete line and the one stale-scan line ($DSP_RED red calls, jq line $DSP_REDJ, stale line $DSP_REDS, $DSP_REDL not on an alarm)" PASS
else row "display colours: no green anywhere ($DSP_GREEN), red only on the open/WEP lines, the one jq-incomplete line and the one stale-scan line ($DSP_RED red calls, jq line $DSP_REDJ, stale line $DSP_REDS, $DSP_REDL not on an alarm)" FAIL; fi
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
DSP_V=$(sed -n 's/^# Version:      \([0-9.]*\)$/\1/p' starchorus-display.sh | head -n 1)
if [ "$DSP_SEQ" = 0 ] && [ "$DSP_GT" = 1 ] && [ "$DSP_G1" = 1 ] && [ "$DSP_V" = 0.1.1 ]; then row "display: GEN, no SEQ (SEQ = $DSP_SEQ, gen_tick = $DSP_GT, 'GEN 1' on a first capture = $DSP_G1), version 0.1.1 [$DSP_V]" PASS; else row "display: GEN/SEQ/version off (SEQ $DSP_SEQ, gt $DSP_GT, g1 $DSP_G1, v $DSP_V)" FAIL; fi
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
