# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/text-budget.sh -- the canvas text budget belongs to the data.
#   RENDER.maxText is a raster budget (2D 30, 3D 24). Text whose wording is fixed by the CODE (the centre
#   post, the 3D ring dBm posts and the WarGames cursor) is baked once per theme and blitted, so the whole
#   budget goes to strings that vary -- access point names, vendor names, group keys.
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only TXB_* globals are set.

# --ready for a run on a served fixture: the boot poll has replaced the built-in sky (a count of access points would be met at once, the built-in sky has some)
TXB_RDY="window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'"

txb_nj() { python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin),sort_keys=True,separators=(",",":"),ensure_ascii=False))' 2>/dev/null; }

# ---- the payoff, measured the same way tools/regress.sh measures the stress budget: every visible AP pinned,
# vendor on, reduced motion, one AP selected+hovered so WarGames draws its cursor. In every theme and both
# views the counted text must be access point names ONLY, and there must be as many of them as the budget
# allows. Counted fixed posts would take 1 slot in 2D (2 in WarGames) and 4 in 3D (5 in WarGames).
TXB_EV='(async()=>{const o={},cap={"2d":STARCHORUS._internals.RENDER.maxText["2d"],"3d":STARCHORUS._internals.RENDER.maxText["3d"]};
STARCHORUS.setToggles({vendor:true});STARCHORUS.setReducedMotion(true);
const aps=STARCHORUS.nodes("ap").filter(n=>n.visible).sort((a,b)=>b.rssi-a.rssi||(a.id<b.id?-1:1));
if(aps.length<30)return JSON.stringify({vacuous:aps.length});
aps.forEach(n=>STARCHORUS.pin(n.id,true));STARCHORUS.frame();
const drawn=new Set(STARCHORUS.labels().filter(l=>l.kind==="label").map(l=>l.id));
const sel=(aps.find(n=>drawn.has(n.id))||aps[0]).id;STARCHORUS.select(sel);STARCHORUS.hoverNode(sel);
const names=[],baked=[],counted=[];
for(const v of ["2d","3d"]){STARCHORUS.setView(v);await STARCHORUS.wait(1400);
 for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await STARCHORUS.wait(1400);STARCHORUS.frame();
  const ls=STARCHORUS.labels(),ft=STARCHORUS.perf().drawCalls.fillText;
  names.push(ls.filter(l=>l.kind==="label"&&l.id!=="__center__").length===cap[v]?1:0);
  counted.push(ft===cap[v]&&ls.filter(l=>l.sprite&&["label","ring","vendor","badge","group","cursor"].indexOf(l.kind)>=0).every(l=>l.kind!=="vendor"&&l.kind!=="group")?1:0);
  const b=ls.filter(l=>l.sprite);
  baked.push(b.length+":"+b.map(l=>l.kind).sort().join(","));}}
o.allNames=names.join("");o.counted=counted.join("");o.baked=baked.join(" | ");
o.centre=(function(){const c=STARCHORUS.labels().filter(l=>l.id==="__center__")[0];return c?c.sprite:"missing"})();
o.spritesUnderCap=STARCHORUS.stats().sprites<=STARCHORUS._internals.RENDER.spriteCap;
STARCHORUS.setView("2d");STARCHORUS.setTheme("foundation");STARCHORUS.deselect();STARCHORUS.hoverNode(null);STARCHORUS.setToggles({vendor:false});
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
runq "$F/field-scale.json" "?poll=0&spin=0&intro=0&debug=1&autolod=0" "out/$P-txb-budget" --width 1440 --height 900 --wait 4 --fps 0 --eval-timeout 180 --eval "$TXB_EV" >/dev/null 2>&1
TXB_V=$(evalv "out/$P-txb-budget.json" 1 | txb_nj)
# 2D: the centre post is baked (WarGames also bakes its cursor). 3D adds the three ring posts.
TXB_W=$(printf '%s' '{"allNames":"111111","baked":"1:label | 2:cursor,label | 1:label | 4:label,ring,ring,ring | 5:cursor,label,ring,ring,ring | 4:label,ring,ring,ring","centre":true,"counted":"111111","errors":0,"spritesUnderCap":true}' | txb_nj)
if [ "$TXB_V" = "$TXB_W" ]; then
  row "text budget goes to the data: in all 3 themes and both views every counted fillText is an access point name and there are as many as the budget allows (2D 30, 3D 24); the fixed posts (centre, 3D rings, WarGames cursor) are baked sprites; sprite cache under its cap" PASS
else
  row "text budget goes to the data" FAIL; echo "    got:  $TXB_V"; echo "    want: $TXB_W"
fi

# ---- the guard that keeps one runaway string from baking a huge bitmap: a centre label longer than
# SPRITE_TEXT_MAX falls back to the counted path. Negative control for the branch, not just for the constant.
TXB_EVG='(async()=>{const o={},doc=(lab)=>({source:"recon-db",generated:1789300000,center:{label:lab},
 aps:[{bssid:"02:00:00:00:71:01",ssid:"a",band:"2.4",channel:6,rssi:-50,security:"WPA2",clients:[]}],unassociated:[]});
STARCHORUS.load(doc("This device"),"short");await STARCHORUS.wait(300);STARCHORUS.frame();
const s=STARCHORUS.labels().filter(l=>l.id==="__center__")[0];o.short=[s?s.sprite:"missing",STARCHORUS.perf().drawCalls.fillText];
STARCHORUS.load(doc("This device with an unreasonably long operator label"),"long");await STARCHORUS.wait(300);STARCHORUS.frame();
const g=STARCHORUS.labels().filter(l=>l.id==="__center__")[0];o.long=[g?g.sprite:"missing",STARCHORUS.perf().drawCalls.fillText];
o.text=g?g.text:"";o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
runq demo "?poll=0&spin=0&intro=0&debug=1&autolod=0" "out/$P-txb-guard" --width 1440 --height 900 --wait 3 --fps 0 --ready --eval-timeout 90 --eval "$TXB_EVG" >/dev/null 2>&1
TXB_G=$(evalv "out/$P-txb-guard.json" 1 | txb_nj)
# the short label is baked and costs no slot (1 fillText = the one AP name); the long one is not baked and
# costs one (2 fillText), and either way the string itself is printed untransformed (D16).
TXB_GW=$(printf '%s' '{"errors":0,"long":[false,2],"short":[true,1],"text":"This device with an unreasonably long op"}' | txb_nj)
if [ "$TXB_G" = "$TXB_GW" ]; then
  row "text budget: SPRITE_TEXT_MAX guard: a short centre label is baked and free; a longer one (the ingest caps the label at 40 characters, still over the 32 the bake allows) falls back to the counted path and costs its slot, and the string is printed as it stands (D16)" PASS
else
  row "text budget: SPRITE_TEXT_MAX guard" FAIL; echo "    got:  $TXB_G"; echo "    want: $TXB_GW"
fi

# ---- static: the budget constants stay at 30/24, and the four baked call sites (centre post, 3D ring posts, cursor, the random-cloud tags of §8.8a) do not decrement it.
TXB_S1=$(grep -c 'maxText: { "2d": 30, "3d": 24 }' "$H")
TXB_S2=$(awk '/==== 35 RENDER HUD/,/==== 36 INTERACTION/' "$H" | grep -c 'getSprite("text"')
TXB_S3=$(awk '/==== 35 RENDER HUD/,/==== 36 INTERACTION/' "$H" | grep -c 'budget--')
rowif "text budget: budget unchanged at 30/24 ($TXB_S1), four baked posts in §35 ($TXB_S2: centre, ring posts, cursor, cloud tags), six counted draws left — AP name, vendor, badge, client vendor, group and the over-long centre fallback ($TXB_S3)" [ "$TXB_S1/$TXB_S2/$TXB_S3" = 1/4/6 ]
TXB_S4=$(grep -c 'SPRITE_TEXT_MAX' "$H")
rowif "text budget: the bake guard is declared once and used once ($TXB_S4)" [ "$TXB_S4" = 3 ]

# ---- #hud is rastered at hudDpr (>= RENDER.hudMinDpr 1.5 on a Retina display) so that HUD TEXT stays crisp
# while the dpr governor scales the sky down. Baked text, the security glyphs and the device counters are
# blitted there, so they must be baked at the HUD scale -- baked at the sky scale they would be upscaled and
# soft next to the names fT() still draws (the bubble counters go onto the sky and keep the sky scale). This run
# forces devicePixelRatio 2 on a 1320-node fixture, where the sky drops to 1.25 and the HUD stays 1.5: the
# two scales genuinely differ here, so the row cannot pass by them being accidentally equal. ?autolod=0: the start DPR
# from the node count (1.25), not what the quality governor makes of a busy test machine's first seconds.
TXB_EVD='(async()=>{await STARCHORUS.wait(600);STARCHORUS.frame();const o={},I=STARCHORUS._internals;
const hud=document.getElementById("hud"),hudScale=hud.width/innerWidth,sky=STARCHORUS.stats().dpr;
const txt=[];I.spriteCache.forEach(function(v){if(/^(text|glyph|devcount)$/.test(v.kind))txt.push(v)});
o.diverge=Math.abs(hudScale-sky)>0.01;o.hud=Math.round(hudScale*100)/100;o.sky=Math.round(sky*100)/100;
o.n=txt.length;o.kinds=Array.from(new Set(txt.map(function(v){return v.kind}))).sort().join("+");o.allAtHudScale=txt.length>0&&txt.every(function(v){return Math.abs(v.dpr-hudScale)<0.01});
o.bitmapMatches=txt.every(function(v){return v.c.width===Math.ceil(v.w*hudScale)});
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
runq "$F/field-scale.json" "?poll=0&spin=0&intro=0&debug=1&autolod=0" "out/$P-txb-dpr" --width 1440 --height 900 --wait 4 --fps 0 --scale 2 --ready "$TXB_RDY" --eval-timeout 90 --eval "$TXB_EVD" >/dev/null 2>&1
TXB_D=$(evalv "out/$P-txb-dpr.json" 1 | txb_nj)
TXB_DW=$(printf '%s' '{"allAtHudScale":true,"bitmapMatches":true,"diverge":true,"errors":0,"hud":1.5,"kinds":"glyph+text","n":4,"sky":1.25}' | txb_nj)
if [ "$TXB_D" = "$TXB_DW" ]; then
  row "text budget: baked HUD text is baked at the HUD scale: at devicePixelRatio 2 on a 1320-node sky the canvas scales genuinely differ (sky 1.25, hud 1.5) and every sprite baked for #hud (the text posts and the security glyphs) carries 1.5, so they stay as crisp as the names beside them" PASS
else
  row "text budget: baked HUD sprites follow hudDpr" FAIL; echo "    got:  $TXB_D"; echo "    want: $TXB_DW"
fi
TXB_S5=$(grep -Ec '^  const dpr = /\^\(text\|glyph\|devcount\)\$/\.test\(kind\) \? hudDpr : S\.perf\.dpr, pad = 3;$' "$H")
TXB_S6=$(grep -c 'if (hudDpr !== prevHudDpr) clearSprites();' "$H")
rowif "text budget: the bake scale follows the destination canvas ($TXB_S5) and a hudDpr change drops the cache ($TXB_S6)" [ "$TXB_S5/$TXB_S6" = 1/1 ]

# ---- 0.2, the radio pair: the Bluetooth layer takes no text budget (tests/fixtures/radio-pair.json with 40 fixed-address marks added). With the layer on, off and on again, in 2D and 3D
# (the 3D turn stopped: it would change which names fit between two readings), the unbaked entries of labels(), the counted fillText and the set of AP label ids are identical, and no mark carries a tag.
TXB_EVB='(async()=>{const sleep=STARCHORUS.wait,o={};await sleep(1500);const fx=await (await fetch("starchorus.json")).json(),G=fx.generated;const d=JSON.parse(JSON.stringify(fx));d.generated=G+10;d.bluetooth=[];for(let i=0;i<40;i++)d.bluetooth.push({addr:"02:00:00:00:05:"+(i+16).toString(16),addr_type:"public",rssi:-45-i,reports:1+i%4,last_seen:G+5,company:65535,company_name:"Maker "+"AB"[i%2]});STARCHORUS.load(d,"rp-tb");STARCHORUS.setToggles({rotate:false});const snap=()=>{STARCHORUS.frame();const L=STARCHORUS.labels();return JSON.stringify([L.filter(l=>!l.sprite).map(l=>l.kind+"|"+(l.text||l.id||"")).sort(),STARCHORUS.perf().drawCalls.fillText,L.filter(l=>l.kind==="label").map(l=>l.id).sort()])};o.marks=STARCHORUS.stats().bluetooth.marks;o.tags=0;o.same={};o.nonEmpty={};for(const v of ["2d","3d"]){STARCHORUS.setView(v);await sleep(3000);const r=[]; for(const bt of [true,false,true]){STARCHORUS.setToggles({bands:{bt}});await sleep(900);r.push(snap());} o.same[v]=r[0]===r[1]&&r[1]===r[2];o.nonEmpty[v]=JSON.parse(r[0])[2].length;o["ft"+v]=JSON.parse(r[0])[1];o.tags+=STARCHORUS.labels().filter(l=>/bt|tag/.test(l.kind)).length;}o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$F/radio-pair.json" "?poll=0&spin=0&intro=0&debug=1" "out/$P-txb-bt" --width 1440 --height 900 --wait 4 --fps 0 --ready "$TXB_RDY" --eval-timeout 120 --eval "$TXB_EVB" >/dev/null 2>&1
TXB_B=$(evalv "out/$P-txb-bt.json" 1 | txb_nj)
TXB_BW=$(printf '%s' '{"marks":40,"tags":0,"same":{"2d":true,"3d":true},"nonEmpty":{"2d":9,"3d":10},"ft2d":8,"ft3d":9,"errors":0}' | txb_nj)
if [ "$TXB_B" = "$TXB_BW" ]; then
  row "text budget (radio pair): 40 Bluetooth marks leave the AP labels alone: the unbaked labels() entries, the counted fillText (8 in 2D, 9 in 3D) and the AP label ids are the same with the layer on, off and on, in 2D and 3D, and no mark carries a tag" PASS
else
  row "text budget (radio pair): Bluetooth leaves the AP labels alone" FAIL; echo "    got:  $TXB_B"; echo "    want: $TXB_BW"
fi
