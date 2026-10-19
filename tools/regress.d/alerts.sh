# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/alerts.sh -- the firmware's deauth/disassoc alert on the page (0.2): a ring in the theme's alarm colour round an alerted access point that
# flickers in the theme's own idiom, and a legend row for it. The data is alerts[] of the capture (tests/fixtures/alerts.json: two reports for access
# points the capture holds and one for an address it does not hold); the collector writes it, the page only draws it, and nothing is sent.
#   R1 the fixture is the generator's, it validates, and the validator refuses twelve broken alerts[] · R2 the ring flickers in each theme's idiom (Foundation a slow
#   pulse, WarGames a seeded phosphor flicker in half-second steps, Whitehall a chalk blink of two levels) and stands steady under reduced motion · R3 it is drawn
#   at the alerted access points and at no other, and it reads the theme's alarm token · R4 the legend row exists exactly while such a ring can be drawn, in the
#   alarm token, with the neutral words · R5 the frame loop stays alive for the flicker and only for it · R6 the observation notes are as before, two lines ·
#   R7 no P10 word in what the feature says · R8 the running page makes no request but GET to its own origin while the alert is shown
# GUARDS AGAINST: a ring that does not flicker, flickers faster than twice a second or flickers under reduced motion; a ring drawn for an address the capture does not
#                 hold, for an own transmitter, or at an access point that was not reported; a colour typed in the draw code instead of the theme's token; a legend row that
#                 shows without a ring or hides with one; a flicker that freezes when the sky does not spin (the frame loop is not asked for it); an alert that adds a word
#                 the neutral-language rule forbids, or a path that sends; a generator that lets a malformed alerts[] through.
# NEGATIVE PROBE: R2 and R3 read the canvas, so a flicker taken out of the draw (the reduced-motion factor kept), the reduced-motion test removed, the token replaced by a
#                 colour, the ring drawn for every reported address and the frame loop not asked for the flicker each turn their own keys red (tried on copies of the page when
#                 the rows were written; the keys are in the label of the failing row); R1's twelve variants are the validator's own controls (the unbroken fixture is
#                 green); R3 compares the same sky with and without its alerts, and swaps the alarm token for a green one; R5 compares with the same page without alerts,
#                 under reduced motion and paused.
# NOT PROVEN:     how the flicker looks on a phone or under a real display's refresh; photosensitivity beyond the rule that nothing steps more than twice a second;
#                 an alert from a real flood (none has been measured: docs/device-notes.md section 5c).
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only AL_* globals are set. Runs without ?fixed (nodes must fade in) and freezes the
# clock itself (STARCHORUS.setFixedTime) for the samples; the WarGames persistence is switched off for them (it would blend neighbouring frames).

AL_FX="$F/alerts.json"; AL_T="out/$P-al"; mkdir -p "$AL_T"
AL_Q="?poll=0&spin=0&intro=0&debug=1"

# ---- R1 the fixture and the validator
python3 tools/gen-testdata.py --alerts --out "$AL_T/gen.json" 2>/dev/null
AL_VL=$(python3 tools/gen-testdata.py --validate "$AL_FX" 2>&1 | tail -n 1)
AL_OK=0; if cmp -s "$AL_FX" "$AL_T/gen.json"; then case $AL_VL in *" OK") AL_OK=1 ;; esac; fi
rowif "alerts: alerts.json = gen-testdata.py --alerts byte for byte, and it validates" [ "$AL_OK" = 1 ]
[ "$AL_OK" = 1 ] || echo "    validate: $AL_VL"
# twelve broken alerts[]: each must be refused for alerts[] itself (a PROBLEM line naming it), the unbroken fixture not
AL_BROKEN=$(python3 - "$AL_FX" "$AL_T" <<'PY'
import copy, json, subprocess, sys
src, out = sys.argv[1], sys.argv[2]
d = json.load(open(src))
def refused(name, f):
    x = copy.deepcopy(d); f(x)
    p = "%s/v-%s.json" % (out, name)
    json.dump(x, open(p, "w"))
    r = subprocess.run([sys.executable, "tools/gen-testdata.py", "--validate", p], capture_output=True, text=True)
    return r.returncode == 1 and "alerts" in r.stdout
cases = [
    ("type", lambda x: x["alerts"][0].update(type="flood")),
    ("zero", lambda x: x["alerts"][0].update(n=0)),
    ("text", lambda x: x["alerts"][0].update(n="9")),
    ("upper", lambda x: x["alerts"][0].update(ap="02:00:5E:A1:00:01")),
    ("notmac", lambda x: x["alerts"][0].update(ap="nonsense")),
    ("order", lambda x: x.update(alerts=[{"t": e["t"], "type": e["type"], "ap": e["ap"], "n": e["n"]} for e in x["alerts"]])),
    ("extra", lambda x: x["alerts"][0].update(src="02:00:5e:a1:00:09")),
    ("unsorted", lambda x: x["alerts"].reverse()),
    ("dupe", lambda x: x["alerts"].append(dict(x["alerts"][2], t=1))),
    ("many", lambda x: x.update(alerts=[dict(x["alerts"][0], ap="02:00:5e:a1:01:%02x" % i, t=2000000000 - i) for i in range(21)])),
    ("object", lambda x: x.update(alerts=x["alerts"][0])),
    ("negative", lambda x: x["alerts"][2].update(t=-1)),
]
bad = [n for n, f in cases if not refused(n, f)]
r = subprocess.run([sys.executable, "tools/gen-testdata.py", "--validate", src], capture_output=True, text=True)
print("%d/%d unbroken %s%s" % (len(cases) - len(bad), len(cases), "OK" if r.returncode == 0 else "REFUSED", "" if not bad else " not refused: " + " ".join(bad)))
PY
)
rowif "alerts: the validator refuses twelve broken alerts[] (a type that is not deauth, a count of 0 or a text, an upper-case or no address, another key order, an extra key, unsorted, a repeated access point, 21 entries, an object, a negative time) and passes the fixture [$AL_BROKEN]" [ "$AL_BROKEN" = "12/12 unbroken OK" ]

# ---- R2 / R3 the ring, read from the canvas at the point of the ring (the access point's screen position plus its radius plus the ring's offset of two rings' width)
# (the last block of the eval makes both reported access points own transmitters of this device: no ring then, as the note is skipped for them too)
# The eval samples the alpha of #sky there at twelve fixed times (the clock is frozen with setFixedTime; a tick runs before each sample) for the two alerted
# access points, per theme, then again under reduced motion, then against the same sky without its alerts and with the alarm token swapped for green.
AL_EVR='(async()=>{const sleep=STARCHORUS.wait,I=STARCHORUS._internals,S=I.S,T=I.THEMES,o={},TM=[0,100,400,500,900,1000,1400,1500,2000,2500,3000,3500],TH=["foundation","wargames","whitehall"];
const A1="02:00:5e:a1:00:01",A4="02:00:5e:a1:00:04",C="02:00:5e:a1:00:02";
await sleep(1500);
const px=(id)=>{const n=STARCHORUS.nodeScreen(id);return n?STARCHORUS.pixel("sky",Math.round(n.sx+n.px+8),Math.round(n.sy)):{r:-1,g:-1,b:-1,a:-1};};
const ser=async(ids)=>{const r=ids.map(()=>[]);for(const ms of TM){STARCHORUS.setFixedTime(ms);await sleep(120);for(let k=0;k<4;k++)STARCHORUS.frame();ids.forEach((id,i)=>r[i].push(px(id).a));}return r;};
const mx=a=>Math.max(...a),mn=a=>Math.min(...a),dist=a=>new Set(a).size,eq=(a,ix)=>ix.every(i=>a[i]===a[ix[0]]);
STARCHORUS.setToggles({crt:false});
const live={};for(const th of TH){STARCHORUS.setTheme(th);live[th]=await ser([A1,A4]);}
const F=live.foundation,W=live.wargames,H=live.whitehall;
o.foundation=F.every(a=>mn(a)>0&&mx(a)>=1.5*mn(a)&&dist(a)>=6&&[[0,1],[4,5],[6,7]].every(([i,j])=>Math.abs(a[i]-a[j])<=0.25*mx(a)));
o.wargames=W.every(a=>[[0,1,2],[3,4],[5,6]].every(g=>eq(a,g))&&dist([0,3,5,7,8,9,10,11].map(i=>a[i]))>=4);
o.whitehall=H.every(a=>eq(a,[0,1,2,3,4,8,9])&&eq(a,[5,6,7,10,11])&&a[0]>0&&a[0]/a[5]>=0.35&&a[0]/a[5]<=0.45);
STARCHORUS.setReducedMotion(true);
const rm={};for(const th of TH){STARCHORUS.setTheme(th);rm[th]=await ser([A1,A4]);}
o.steady=TH.map(th=>rm[th].every((a,i)=>dist(a)===1&&a[0]>=0.95*mx(live[th][i]))?1:0).join("");
const own={};
for(const th of TH){STARCHORUS.setTheme(th);STARCHORUS.setFixedTime(1000);await sleep(120);const ids=[A1,A4,C];
  const sm=()=>{for(let k=0;k<4;k++)STARCHORUS.frame();return ids.map(id=>px(id).a);};
  const w=sm(),keep=S.alerts;S.alerts=[];const z=sm();S.alerts=keep;
  own[th]=(w[0]-z[0]>=60&&w[1]-z[1]>=60&&Math.abs(w[2]-z[2])<=2)?"ok":"bad "+w+"/"+z;
  const al=T[th].status.alarm;T[th].status.alarm="#00ff00";const g=(sm(),px(A4));T[th].status.alarm=al;const q=(sm(),px(A4));
  own[th]+=(g.g>=200&&g.r<=80&&g.b<=80&&q.r>=q.g)?"":" token "+[g.r,g.g,g.b]+"/"+[q.r,q.g,q.b];}
o.where=TH.map(th=>own[th]).join("|");
{STARCHORUS.setTheme("whitehall");
const fx=await (await fetch("starchorus.json")).json();fx.center.own_bssids=[A1,A4];fx.generated+=50;STARCHORUS.load(fx,"al-own");await sleep(1200);
STARCHORUS.setFixedTime(1000);await sleep(120);
const sm2=()=>{for(let k=0;k<4;k++)STARCHORUS.frame();return [A1,A4].map(id=>px(id).a);};
const ow=sm2(),keep=S.alerts;S.alerts=[];const z=sm2();S.alerts=keep;
o.own=(Math.abs(ow[0]-z[0])<=2&&Math.abs(ow[1]-z[1])<=2)?"ok":"bad "+ow+"/"+z;}
STARCHORUS.setReducedMotion(null);STARCHORUS.setFixedTime(null);
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$AL_FX" "$AL_Q" "$AL_T/ring" --fps 0 --wait 3 --eval-timeout 120 --eval "$AL_EVR" >/dev/null 2>&1
AL_R=$(evalv "$AL_T/ring.json" 1)
AL_WANT='{"foundation":true,"wargames":true,"whitehall":true,"steady":"111","where":"ok|ok|ok","own":"ok","errors":0}'
AL_RN=$(printf '%s' "$AL_R" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({k: d.get(k) for k in ("foundation","wargames","whitehall","steady","where","own","errors")}, separators=(",",":")))' 2>/dev/null)
rowif "alerts: the ring of an alerted access point flickers in each theme's idiom (Foundation a slow smooth pulse, WarGames a seeded phosphor flicker in steps of half a second, Whitehall a chalk blink of two levels), stands steady under reduced motion, is drawn at the two reported access points and at no other (not at an own transmitter either), and reads the theme's alarm token [${AL_RN:-no-value}]" [ "$AL_RN" = "$AL_WANT" ]
[ "$AL_RN" = "$AL_WANT" ] || printf '    %s\n' "$(printf '%s' "${AL_R:-no-value}" | cut -c1-300)"

# ---- R4 / R6 / R7 the legend row, the observation notes, the words: one run on the fixture, then variants of it loaded into the same page
AL_EVL='(async()=>{const sleep=STARCHORUS.wait,I=STARCHORUS._internals,S=I.S,o={},TH=["foundation","wargames","whitehall"];
const A1="02:00:5e:a1:00:01",A4="02:00:5e:a1:00:04",U="02:00:5e:a1:00:77";
await sleep(1500);
const fx=await (await fetch("starchorus.json")).json();
let cnt=0;const ld1=async(mut,lab)=>{const d=JSON.parse(JSON.stringify(fx));d.generated+=5*(++cnt);if(mut)mut(d);STARCHORUS.load(d,lab);await sleep(300);};
const ld=async(mut,lab)=>{await ld1(mut,lab);await ld1(mut,lab);};   // a note shows once its alert has held for two captures (the observations dwell), the legend row and the ring at once
const row=()=>STARCHORUS.legendRows().find(r=>r.kind==="alert");
const notes=()=>STARCHORUS.observations().filter(x=>x.group==="Alerts").map(x=>x.text);
const vis=()=>(row().visible?1:0)+"/"+notes().length;
await ld(null,"al-warm");o.start=vis();
o.tokens=TH.map(th=>{STARCHORUS.setTheme(th);const r=row();return r.visible&&r.paints.length>0&&r.paints.every(p=>p.tok==="status.alarm"&&p.css===p.val)?1:0;}).join("");
STARCHORUS.setTheme("foundation");
const txt=document.getElementById("leg-alert").textContent;
o.words=txt==="flickering ring = many deauth/disassoc frames heard for this AP";
o.notes=JSON.stringify(notes());
await ld(d=>{d.alerts=[d.alerts[2]];},"al-unknown");o.unknown=vis();
await ld(d=>{d.center.own_bssids=[A1,A4];},"al-own");o.own=vis();
await ld(d=>{d.alerts=[d.alerts[1]];},"al-one");o.one=vis()+"/"+notes().length;
await ld(d=>{delete d.alerts;},"al-none");o.none=vis();
await ld(null,"al-back");o.back=vis();
const all=[txt].concat(notes());o.text=all.join("|");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$AL_FX" "$AL_Q" "$AL_T/legend" --fps 0 --wait 3 --eval-timeout 60 --eval "$AL_EVL" >/dev/null 2>&1
AL_L=$(evalv "$AL_T/legend.json" 1)
AL_LN=$(printf '%s' "$AL_L" | python3 -c 'import json,sys; d=json.load(sys.stdin); d.pop("text",None); print(json.dumps(d,separators=(",",":"),sort_keys=True))' 2>/dev/null)
AL_LWANT='{"back":"1/2","errors":0,"none":"0/0","notes":"[\"many deauth/disassoc frames heard for this AP: alert-a (9)\",\"many deauth/disassoc frames heard for this AP: alert-b (4)\"]","one":"1/1/1","own":"0/0","start":"1/2","tokens":"111","unknown":"0/0","words":true}'
rowif "alerts: the legend row is there while a ring is drawn (2 notes) and gone with no alert, with only the unknown address and with both access points an own transmitter; in the alarm token in all three themes; with its neutral words; the two observation notes read as before [${AL_LN:-no-value}]" [ "$AL_LN" = "$AL_LWANT" ]
[ "$AL_LN" = "$AL_LWANT" ] || printf '    %s\n' "$(printf '%s' "${AL_L:-no-value}" | cut -c1-400)"
AL_P10=$(sed -n "s/^NTL_P10_RE='\(.*\)'\$/\1/p" tools/regress.d/neutral-language.sh | head -n 1)   # the one definition of the P10 words, read where it lives
AL_TXT=$(printf '%s' "$AL_L" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("text",""))' 2>/dev/null)
printf '%s\n' "$AL_TXT" > "$AL_T/words.txt"
AL_HIT=$(python3 - "$AL_T/words.txt" "$AL_P10" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
print(len(re.findall(sys.argv[2], t, re.I)), len(t))
PY
)
AL_HL=${AL_HIT#* }; AL_HITOK=0
case $AL_HIT in "0 "*) [ -n "$AL_P10" ] && [ "${AL_HL:-0}" -ge 100 ] && AL_HITOK=1 ;; esac
rowif "alerts: P10: no forbidden word in the legend row and the two notes ($AL_HL characters read; the regex is read from neutral-language.sh, which is where it lives)" [ "$AL_HITOK" = 1 ]

# ---- R5 the frame loop: with alerts and no spin the page renders on its own (the flicker needs frames); without alerts, under reduced motion and paused it renders
# next to nothing
AL_EVF='(async()=>{const sleep=STARCHORUS.wait,I=STARCHORUS._internals,S=I.S,o={};
STARCHORUS.setTheme("whitehall");   // Foundation breathes, so its frame loop never rests; Whitehall (and WarGames) render only when asked, and only a sky without an orbiting station is at rest
const fx=await (await fetch("starchorus.json")).json();fx.aps.forEach(a=>{a.clients=[];});STARCHORUS.load(fx,"al-rest");await sleep(3000);
const n=async()=>{const a=S.perf.rendered;await sleep(700);return S.perf.rendered-a;};
o.alerts=await n();
const keep=S.alerts;S.alerts=[];S.dirty=true;await sleep(300);o.none=await n();S.alerts=keep;S.dirty=true;
STARCHORUS.setReducedMotion(true);await sleep(300);o.rm=await n();STARCHORUS.setReducedMotion(null);
STARCHORUS.setToggles({paused:true});await sleep(300);o.paused=await n();STARCHORUS.setToggles({paused:false});
await sleep(300);o.again=await n();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$AL_FX" "$AL_Q" "$AL_T/frames" --fps 0 --wait 3 --eval-timeout 60 --eval "$AL_EVF" >/dev/null 2>&1
AL_F=$(evalv "$AL_T/frames.json" 1)
AL_FOK=$(printf '%s' "$AL_F" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("ok" if d["alerts"]>=15 and d["again"]>=15 and d["none"]<=3 and d["rm"]<=3 and d["paused"]<=3 and d["errors"]==0 else "bad")' 2>/dev/null)
rowif "alerts: the flicker keeps the frame loop alive and only the flicker (Whitehall, which rests when nothing moves: frames rendered in 0.7 s with alerts at least 15, without alerts, under reduced motion and paused at most 3 each) [${AL_F:-no-value}]" [ "$AL_FOK" = ok ]

# ---- R8 the running page, with the alert drawn, asks for nothing but its own page and file (GET, own origin)
AL_NV=$(net_verdict "$AL_T/ring.json" - 0); AL_NC=$?
AL_NOK=0; [ "$AL_NC" = 0 ] && AL_NOK=1
rowif "alerts: with the alert drawn the page makes no request but GET to its own origin: $AL_NV" [ "$AL_NOK" = 1 ]
