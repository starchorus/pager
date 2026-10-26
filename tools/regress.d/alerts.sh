# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/alerts.sh -- the firmware's deauth/disassoc alert on the page (0.2): a ring in the theme's alert colour (the token status.alert, red in all three themes) round an alerted access point that
# flickers in the theme's own idiom, and a legend row for it. The data is alerts[] of the capture (tests/fixtures/alerts.json: two reports for access
# points the capture holds and one for an address it does not hold); the collector writes it, the page only draws it, and nothing is sent.
#   R1 the fixture is the generator's, it validates, and the validator refuses twelve broken alerts[] · R2 the ring flickers in each theme's idiom (Foundation a slow
#   pulse, WarGames a seeded phosphor flicker in half-second steps, Whitehall a chalk blink of two levels) and stands steady under reduced motion · R3 it is drawn
#   at the alerted access points and at no other, it reads the theme's alert token, and it leaves the pixels of the access point's own rings as they were · R4 the
#   legend row exists exactly while such a ring can be drawn (not with its band filtered off), in the alert token, with the neutral words · R5 the frame loop is asked
#   for each step of the flicker and for nothing else, and the ring takes both its levels on the canvas · R6 the observation notes are as before, two lines · R7 no P10
#   word in what the feature says · R8 the running page makes no request but GET to its own origin while the alert is shown · R9 the planted copies of the page
#   (below) · R10 the colour role of the alert token · R11 the Scope's blip of an alerted access point blinks in the ring's rhythm (frames, both levels, reduced motion, paused, Foundation's
#   pulse sampled at the half second) · R12 the ring's band, as section 14.6 states it (it touches the selection ring)
# GUARDS AGAINST: a ring that does not flicker, flickers faster than twice a second or flickers under reduced motion; a ring drawn for an address the capture does not
#                 hold, for an own transmitter, or at an access point that was not reported; a colour typed in the draw code instead of the theme's token; a legend row that
#                 shows without a ring or hides with one (or with its band filtered off); a flicker that freezes when the sky does not spin (the frame loop is not asked for
#                 it) or that renders sixty frames a second for a change twice a second; a ring that lands on the security ring, its double, the identity frame or the new-plot
#                 mark; an alert that adds a word the neutral-language rule forbids, or a path that sends; a generator that lets a malformed alerts[] through; a step of the flicker that arms the
#                 phosphor fade again (WarGames, persistence on: 22 frames for each step); a Scope whose alerted blip never blinks, or that renders sixty frames a second for it; a ring that moves so
#                 that the band stated in section 14.6 is no longer true.
# NEGATIVE PROBE: R9 runs the same evals on planted copies of the page, each differing from it in exactly one line (the old text exists once): the ring back at px + 8,
#                 the flicker factor replaced by 1, the reduced-motion test removed, no frame request, a frame request every frame, and a legend row that ignores the band
#                 filter; a step that arms the phosphor fade again (R5), in the Scope a loop never asked for the step and Foundation's pulse asked for on every frame (R11), and a ring thinned to
#                 1.25 px at 11.4 (R12), are more. Each must turn its own key red (the key and the value are in the label of the row), and the copies must boot without an error. R1's twelve variants
#                 are the validator's own controls (the unbroken fixture is green); R3 compares the same sky with and without its alerts, and swaps the alert token for a
#                 green one; R5 compares with the same page without alerts, under reduced motion and paused; R10 mutates the token sets (amber, a band colour, no token).
# NOT PROVEN:     how the flicker looks on a phone or under a real display's refresh; photosensitivity beyond the rule that nothing steps more than twice a second;
#                 an alert from a real flood (none has been measured: docs/device-notes.md section 5c).
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only AL_* globals are set. Runs without ?fixed (nodes must fade in) and freezes the
# clock itself (STARCHORUS.setFixedTime) for the samples; the WarGames persistence is switched off for them (it would blend neighbouring frames), and on in the one frame count of R5 that is about it.

AL_FX="$F/alerts.json"; AL_T="out/$P-al"; mkdir -p "$AL_T"
AL_Q="?poll=0&spin=0&intro=0&debug=1"
# --ready for a run on the served fixture: the boot poll has replaced the built-in sky (its apsTotal is above 0 from the first frame, so a count would be met at once)
AL_RDY="window.STARCHORUS && STARCHORUS.stats().sourceKind !== 'demo'"

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
# access points, per theme, then again under reduced motion, then against the same sky without its alerts and with the alert token swapped for green.
AL_EVR='(async()=>{const sleep=STARCHORUS.wait,I=STARCHORUS._internals,S=I.S,T=I.THEMES,o={},TM=[0,100,400,500,900,1000,1400,1500,2000,2500,3000,3500],TH=["foundation","wargames","whitehall"];
const A1="02:00:5e:a1:00:01",A4="02:00:5e:a1:00:04",C="02:00:5e:a1:00:02";
await sleep(1500);
const px=(id,o)=>{const n=STARCHORUS.nodeScreen(id);return n?STARCHORUS.pixel("sky",Math.floor(n.sx+n.px+(o===undefined?11.5:o)),Math.round(n.sy)):{r:-1,g:-1,b:-1,a:-1};};
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
const own={},band={};
for(const th of TH){STARCHORUS.setTheme(th);STARCHORUS.setFixedTime(1000);await sleep(120);const ids=[A1,A4,C];
  const sm=()=>{for(let k=0;k<4;k++)STARCHORUS.frame();return ids.map(id=>px(id).a);};
  const w=sm(),keep=S.alerts;S.alerts=[];const z=sm();S.alerts=keep;
  own[th]=(w[0]-z[0]>=60&&w[1]-z[1]>=60&&Math.abs(w[2]-z[2])<=2)?"ok":"bad "+w+"/"+z;
  const bd=()=>[A1,A4].map(id=>{const r=[];for(let o=3;o<=9;o++){const p=px(id,o);r.push(p.r+","+p.g+","+p.b+","+p.a);}return r.join(";");}).join("|");
  const bw=(sm(),bd());S.alerts=[];const bz=(sm(),bd());S.alerts=keep;sm();band[th]=bw===bz?"ok":"moved";
  const al=T[th].status.alert;T[th].status.alert="#00ff00";const g=(sm(),px(A4));T[th].status.alert=al;const q=(sm(),px(A4));
  own[th]+=(g.g>=200&&g.r<=80&&g.b<=80&&q.r>=q.g)?"":" token "+[g.r,g.g,g.b]+"/"+[q.r,q.g,q.b];}
o.where=TH.map(th=>own[th]).join("|");o.band=TH.map(th=>band[th]).join("|");
{STARCHORUS.setTheme("whitehall");
const fx=await (await fetch("starchorus.json")).json();fx.center.own_bssids=[A1,A4];fx.generated+=50;STARCHORUS.load(fx,"al-own");await sleep(1200);
STARCHORUS.setFixedTime(1000);await sleep(120);
const sm2=()=>{for(let k=0;k<4;k++)STARCHORUS.frame();return [A1,A4].map(id=>px(id).a);};
const ow=sm2(),keep=S.alerts;S.alerts=[];const z=sm2();S.alerts=keep;
o.own=(Math.abs(ow[0]-z[0])<=2&&Math.abs(ow[1]-z[1])<=2)?"ok":"bad "+ow+"/"+z;}
STARCHORUS.setReducedMotion(null);STARCHORUS.setFixedTime(null);
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
# al_ring PAGE PREFIX: the ring eval on PAGE (the page, or a planted copy of it); the keys it reads come back in AL_R (all) and AL_RN (the verdict keys)
al_ring() {
  AL_HK=$H; H=$1   # runq serves $H: point it at the copy for this one call, then put it back
  runq "$AL_FX" "$AL_Q" "$2" --fps 0 --wait 3 --eval-timeout 120 --eval "$AL_EVR" >/dev/null 2>&1
  H=$AL_HK
  AL_R=$(evalv "$2.json" 1)
  AL_RN=$(printf '%s' "$AL_R" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({k: d.get(k) for k in ("foundation","wargames","whitehall","steady","where","band","own","errors")}, separators=(",",":")))' 2>/dev/null)
}
al_ring "$H" "$AL_T/ring"
AL_WANT='{"foundation":true,"wargames":true,"whitehall":true,"steady":"111","where":"ok|ok|ok","band":"ok|ok|ok","own":"ok","errors":0}'
rowif "alerts: the ring of an alerted access point flickers in each theme's idiom (Foundation a slow smooth pulse, WarGames a seeded phosphor flicker in steps of half a second, Whitehall a chalk blink of two levels), stands steady under reduced motion, is drawn at the two reported access points and at no other (not at an own transmitter either), reads the theme's alert token, and leaves every pixel of the access point's own rings (3 to 9 px beyond the star: the security ring and its double, the identity frame, the new-plot mark) as it was without the alert [${AL_RN:-no-value}]" [ "$AL_RN" = "$AL_WANT" ]
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
o.tokens=TH.map(th=>{STARCHORUS.setTheme(th);const r=row();return r.visible&&r.paints.length>0&&r.paints.every(p=>p.tok==="status.alert"&&p.css===p.val)?1:0;}).join("");
STARCHORUS.setTheme("foundation");
const txt=document.getElementById("leg-alert").textContent;
o.words=txt==="alert ring = many deauth/disassoc frames heard for this AP";
o.notes=JSON.stringify(notes());
await ld(d=>{d.alerts=[d.alerts[2]];},"al-unknown");o.unknown=vis();
await ld(d=>{d.center.own_bssids=[A1,A4];},"al-own");o.own=vis();
await ld(d=>{d.alerts=[d.alerts[1]];},"al-one");o.one=vis()+"/"+notes().length;
await ld(d=>{delete d.alerts;},"al-none");o.none=vis();
await ld(null,"al-back");o.back=vis();
STARCHORUS.setToggles({bands:{"2.4":false}});await sleep(300);o.off24=vis();   // alert-a is 2.4 GHz and alert-b 5 GHz: one ring can still be drawn, then none
STARCHORUS.setToggles({bands:{"5":false}});await sleep(300);o.off245=vis();
STARCHORUS.setToggles({bands:{"2.4":true,"5":true}});await sleep(300);o.on=vis();
const all=[txt].concat(notes());o.text=all.join("|");
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
# al_legend PAGE PREFIX: the legend eval on PAGE (the page, or a planted copy); the value comes back in AL_L, the keys without the words in AL_LN
al_legend() {
  AL_HK=$H; H=$1   # runq serves $H: point it at the copy for this one call, then put it back
  runq "$AL_FX" "$AL_Q" "$2" --fps 0 --wait 3 --ready "$AL_RDY" --eval-timeout 60 --eval "$AL_EVL" >/dev/null 2>&1
  H=$AL_HK
  AL_L=$(evalv "$2.json" 1)
  AL_LN=$(printf '%s' "$AL_L" | python3 -c 'import json,sys; d=json.load(sys.stdin); d.pop("text",None); print(json.dumps(d,separators=(",",":"),sort_keys=True))' 2>/dev/null)
}
al_legend "$H" "$AL_T/legend"
AL_LWANT='{"back":"1/2","errors":0,"none":"0/0","notes":"[\"many deauth/disassoc frames heard for this AP: alert-a (9)\",\"many deauth/disassoc frames heard for this AP: alert-b (4)\"]","off24":"1/2","off245":"0/2","on":"1/2","one":"1/1/1","own":"0/0","start":"1/2","tokens":"111","unknown":"0/0","words":true}'
rowif "alerts: the legend row is there while a ring is drawn (2 notes) and gone with no alert, with only the unknown address, with both access points an own transmitter and with the bands of both filtered off (still there for one of them); in the alert token in all three themes; with its neutral words; the two observation notes read as before [${AL_LN:-no-value}]" [ "$AL_LN" = "$AL_LWANT" ]
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

# ---- R5 the frame loop: the page renders a frame for each step of the flicker, and for nothing else. Whitehall at rest (no orbiting station) renders only when asked,
# so the frames of 0.7 s are the frames the flicker asked for: a step is due every half second, so one or two, never the sixty a second of a loop that is always asked.
# The ring's own pixel on the canvas is sampled every 100 ms for 2.7 s, live: it must take both its levels (the chalk blink switches every second), which a loop that is not
# asked for the step would never show. Without alerts, under reduced motion and paused it renders next to nothing.
AL_EVF='(async()=>{const sleep=STARCHORUS.wait,I=STARCHORUS._internals,S=I.S,o={};
STARCHORUS.setTheme("whitehall");   // Foundation breathes, so its frame loop never rests; Whitehall (and WarGames) render only when asked, and only a sky without an orbiting station is at rest
const fx=await (await fetch("starchorus.json")).json();fx.aps.forEach(a=>{a.clients=[];});STARCHORUS.load(fx,"al-rest");await sleep(3000);
const n=async()=>{const a=S.perf.rendered;await sleep(700);return S.perf.rendered-a;};
const ring=()=>{const q=STARCHORUS.nodeScreen("02:00:5e:a1:00:01");return STARCHORUS.pixel("sky",Math.floor(q.sx+q.px+11.5),Math.round(q.sy)).a;};
o.alerts=await n();
const lv=new Set();for(let k=0;k<27;k++){lv.add(ring());await sleep(100);}o.levels=[...lv].filter(a=>a>0).length;
const keep=S.alerts;S.alerts=[];S.dirty=true;await sleep(300);o.none=await n();S.alerts=keep;S.dirty=true;
STARCHORUS.setReducedMotion(true);await sleep(300);o.rm=await n();STARCHORUS.setReducedMotion(null);
STARCHORUS.setToggles({paused:true});await sleep(300);o.paused=await n();STARCHORUS.setToggles({paused:false});
await sleep(300);o.again=await n();
fx.generated+=60;STARCHORUS.setTheme("wargames");STARCHORUS.setToggles({crt:true});STARCHORUS.load(fx,"al-rest-wg");await sleep(3000);   // WarGames with its phosphor persistence on: a step is one clean frame, it must not arm the 20-frame fade (it did: 30 frames in 0.7 s)
o.wgOn=S.persistOn;o.wg=await n();o.wg2=await n();
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
# al_frames PAGE PREFIX: the frame eval on PAGE (the page, or a planted copy); the value comes back in AL_F, its verdict ("ok" or "bad") in AL_FOK
al_frames() {
  AL_HK=$H; H=$1
  runq "$AL_FX" "$AL_Q" "$2" --fps 0 --wait 3 --eval-timeout 60 --eval "$AL_EVF" >/dev/null 2>&1
  H=$AL_HK
  AL_F=$(evalv "$2.json" 1)
  AL_FOK=$(printf '%s' "$AL_F" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("ok" if 1<=d["alerts"]<=6 and 1<=d["again"]<=6 and d["levels"]>=2 and d["none"]<=3 and d["rm"]<=3 and d["paused"]<=3 and d["wgOn"] is True and 1<=d["wg"]<=6 and 1<=d["wg2"]<=6 and d["errors"]==0 else "bad")' 2>/dev/null)
}
al_frames "$H" "$AL_T/frames"
rowif "alerts: the frame loop is asked for each step of the flicker and for nothing else (Whitehall, which rests when nothing moves: between 1 and 6 frames in 0.7 s with alerts, not sixty a second; the ring takes both its levels on the canvas within 2.7 s; without alerts, under reduced motion and paused at most 3 frames each; WarGames with its phosphor persistence on, which used to render 22 frames for every step, also between 1 and 6 frames in 0.7 s) [${AL_F:-no-value}]" [ "$AL_FOK" = ok ]

# ---- R8 the running page, with the alert drawn, asks for nothing but its own page and file (GET, own origin)
AL_NV=$(net_verdict "$AL_T/ring.json" - 0); AL_NC=$?
AL_NOK=0; [ "$AL_NC" = 0 ] && AL_NOK=1
rowif "alerts: with the alert drawn the page makes no request but GET to its own origin: $AL_NV" [ "$AL_NOK" = 1 ]

# ---- R10 the colour role: the alert colour is red and apart from the three bands and from selection in every theme (tools/check-colors.py, spec 14.4). The validator runs
# on the live token sets; three mutations must each turn it red for the alert role: Foundation's alert in its amber alarm colour, Whitehall's in the 5 GHz band colour, and
# WarGames' without the token. The counts are pinned: 18 checks of the role (3 themes x hue, 3 bands, 2 selection tokens) and a green validator on the real tokens.
runq demo "$AL_Q" "$AL_T/themes" --wait 1 --fps 0 --ready --eval 'JSON.stringify(STARCHORUS._internals.THEMES)' >/dev/null 2>&1
AL_CC=$(python3 -B - "$AL_T/themes.json" <<'PY'
import json, subprocess, sys, tempfile
d = json.load(open(sys.argv[1])); t = json.loads(d["eval"][0]["value"])
def run(mut, *a):
    u = json.loads(json.dumps(t)); mut(u)
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(u, f); n = f.name
    return subprocess.run([sys.executable, "tools/check-colors.py", n, *a], capture_output=True, text=True)
base = run(lambda u: None, "--table")
role = [l for l in base.stdout.splitlines() if l.split()[:3][2:] == ["alert"]]
def bites(mut):
    r = run(mut)
    return r.returncode == 1 and any(l.startswith("FAIL") and " alert " in l for l in r.stdout.splitlines())
m = [bites(lambda u: u["foundation"]["status"].__setitem__("alert", u["foundation"]["status"]["alarm"])),
     bites(lambda u: u["whitehall"]["status"].__setitem__("alert", u["whitehall"]["band"]["5"]["core"])),
     bites(lambda u: u["wargames"]["status"].pop("alert"))]
print("%d/%d/%s" % (len(role), base.returncode, "".join("1" if x else "0" for x in m)))
PY
)
rowif "alerts: the colour role of the alert ring holds in all three themes (hue red, ΔE ≥ 15 from the bands and selection: 18 checks, validator green) and bites on the amber alarm colour, a band colour and a missing token [$AL_CC]" [ "$AL_CC" = "18/0/111" ]

# ---- R9 the keys bite: the same evals on six planted copies of the page here (the R5 persistence copy and the R11 and R12 copies follow). Fair by construction: each old text exists once, each copy differs from the page in exactly
# that line, and it boots without an error; each must turn its own key red, and the keys that belong to the other rows stay as they are. The copies are only served to
# headless Chrome on 127.0.0.1; nothing in them sends.
# al_plant OUT OLD NEW [OLD NEW ...]: a copy of the page with each OLD replaced by NEW; return 1 unless every OLD is in the page exactly once
al_plant() {
  _ap_o=$1; shift
  python3 -B - "$H" "$_ap_o" "$@" <<'PY'
import sys
src, out, *pairs = sys.argv[1:]
s = open(src, encoding="utf-8").read()
for old, new in zip(pairs[0::2], pairs[1::2]):
    if s.count(old) != 1:
        sys.exit(1)
    s = s.replace(old, new)
open(out, "w", encoding="utf-8").write(s)
PY
}
# al_copy OUT OLD NEW ...: al_plant, then AL_CPR = its status and AL_CPD = the lines of the page that differ in the copy
al_copy() { al_plant "$@"; AL_CPR=$?; AL_CPD=$(diff "$H" "$1" 2>/dev/null | grep -c '^<'); }
AL_FLK='n.alphaDraw * (reduceMotion ? 1 : cm === "glowPulse" ? 0.7 + 0.3 * Math.sin(S.clock * 3) : cm === "bloomPulse" ? 0.3 + 0.7 * hash(a.ap.slice(-2) + e2 * 97) : 0.4 + 0.6 * (e2 >> 1 & 1))'
AL_REQ='!S.ui.paused && S.clock >= alAt) {'
# the ring key: ring_key FILE KEY... prints the value of each key of the ring eval in FILE, comma-separated
al_key() { printf '%s' "$AL_R" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(str(d.get(k)) for k in sys.argv[1:]))' "$@" 2>/dev/null; }

# the ring back at px + 8 (the outer circle of a WPA2 double ring): the band key
al_copy "$AL_T/p-band.html" 'ringArc(THEME.status.alert, 1.5, null, n.alphaDraw' 'ringArc(THEME.status.alert, 2, null, n.alphaDraw' 'n.px + ENCODING.hidden.offsetPx + 1.5, 0, Math.PI * 2)' 'n.px + 2 * ENCODING.ringOffsetPx, 0, Math.PI * 2)'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_ring "$AL_T/p-band.html" "$AL_T/ring-band"; AL_V=$(al_key band errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "moved|moved|moved,0" ] && AL_OK=1
rowif "alerts: the band key bites: the ring put back at px + 8 (the outer circle of a WPA2 double ring) moves the access point's own pixels in all three themes [copy differs in $AL_C1 line, band/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]

# the flicker factor replaced by 1: the three flicker keys
al_copy "$AL_T/p-flat.html" "$AL_FLK" 'n.alphaDraw * 1'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_ring "$AL_T/p-flat.html" "$AL_T/ring-flat"; AL_V=$(al_key foundation wargames whitehall steady errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "False,False,False,111,0" ] && AL_OK=1
rowif "alerts: the flicker keys bite: a ring whose alpha factor is 1 turns the Foundation, WarGames and Whitehall keys red and leaves the steady key green [copy differs in $AL_C1 line, ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]

# the reduced-motion test removed: the steady key
al_copy "$AL_T/p-rm.html" 'n.alphaDraw * (reduceMotion ? 1 : cm === "glowPulse"' 'n.alphaDraw * (cm === "glowPulse"'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_ring "$AL_T/p-rm.html" "$AL_T/ring-rm"; AL_V=$(al_key foundation wargames whitehall steady errors)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && case $AL_V in "True,True,True,"*",0") [ "$AL_V" != "True,True,True,111,0" ] && AL_OK=1 ;; esac
rowif "alerts: the steady key bites: a ring that still flickers under reduced motion turns the steady key red and leaves the three flicker keys green [copy differs in $AL_C1 line, ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]

# no frame request: the loop is not asked for the step, so the ring never takes its second level and no frame is rendered
al_copy "$AL_T/p-noreq.html" "$AL_REQ" '!S.ui.paused && false) {'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_frames "$AL_T/p-noreq.html" "$AL_T/frames-noreq"
AL_V=$(printf '%s' "$AL_F" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["alerts"], d["levels"])' 2>/dev/null)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_FOK" = bad ] && [ "$AL_V" = "0 1" ] && AL_OK=1
rowif "alerts: the frame key bites (no request): a loop that is never asked for the step renders no frame in 0.7 s and the ring keeps one level [copy differs in $AL_C1 line, frames/levels ${AL_V:-no-value}, verdict ${AL_FOK:-none}]" [ "$AL_OK" = 1 ]

# a request every frame: the sixty frames a second this fix removed
al_copy "$AL_T/p-always.html" "$AL_REQ" '!S.ui.paused && true) {'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_frames "$AL_T/p-always.html" "$AL_T/frames-always"
AL_V=$(printf '%s' "$AL_F" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["alerts"] > 6, d["levels"] >= 2, d["errors"])' 2>/dev/null)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_FOK" = bad ] && [ "$AL_V" = "True True 0" ] && AL_OK=1
rowif "alerts: the frame key bites (every frame): a loop asked for on every frame renders more than 6 frames in 0.7 s, while the ring still takes both levels [copy differs in $AL_C1 line, over 6 frames/both levels/errors ${AL_V:-no-value}, verdict ${AL_FOK:-none}]" [ "$AL_OK" = 1 ]

# a legend row that ignores the band filter: the off245 key
al_copy "$AL_T/p-leg.html" 'return eventSkip(n) || S.ui.filters[n.band] === false ? null : n; };' 'return eventSkip(n) ? null : n; };'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_legend "$AL_T/p-leg.html" "$AL_T/legend-leg"
AL_V=$(printf '%s' "$AL_L" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["off24"], d["off245"], d["on"], d["errors"])' 2>/dev/null)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_V" = "1/2 1/2 1/2 0" ] && AL_OK=1
rowif "alerts: the filter key bites: a legend row that ignores the band filter stays when both bands are filtered off [copy differs in $AL_C1 line, off24/off245/on/errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]

# the persistence key: an alert step that arms the phosphor fade again (the 22 frames for each step that this fix removed): only WarGames' count goes over 6
al_copy "$AL_T/p-fade.html" 'S.clock >= alAt) { ctxSky.clearRect(0, 0, W, H); render(); S.perf.rendered++; }' 'S.clock >= alAt) { render(); S.perf.rendered++; S.persistFade = S.persistOn ? RENDER.persistFadeFrames : 0; }'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_frames "$AL_T/p-fade.html" "$AL_T/frames-fade"
AL_V=$(printf '%s' "$AL_F" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["alerts"] <= 6, d["again"] <= 6, d["levels"] >= 2, d["wg"] > 6, d["errors"])' 2>/dev/null)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_FOK" = bad ] && [ "$AL_V" = "True True True True 0" ] && AL_OK=1
rowif "alerts: the persistence key bites: a step that arms the phosphor fade again renders more than 6 frames in 0.7 s in WarGames with persistence on, and only there (Whitehall and the ring's levels stay green) [copy differs in $AL_C1 line, Whitehall frames/again/levels, WarGames over 6, errors ${AL_V:-no-value}]" [ "$AL_OK" = 1 ]

# ---- R12 the ring's band, read from the page's own numbers: the ring runs from 10.75 to 12.25 px beyond the star's edge (1.5 wide at offsetPx + 1.5). The hidden-SSID ring (offset 10, 1 wide) ends
# at 10.5 and the selection ring (offset 13, 1.5 wide) starts at 12.25: the alert ring is 0.25 px clear of the first and touches the second. docs/architecture.md section 14.6 says exactly that; a free band
# of 1.75 px cannot hold a ring that keeps 0.5 px from both and is still a ring the canvas rows can read (0.75 px). This row keeps the sentence true: the gaps are computed from the page, and a ring that is
# moved or thinned is red until the section is read again.
cat > "$AL_T/gap.py" <<'PY'
import re, sys
s = open(sys.argv[1], encoding="utf-8").read()
def one(rx):
    m = re.findall(rx, s)
    if len(m) != 1: print("BROKEN:" + rx[:30]); sys.exit(0)
    return m[0]
w, d = one(r"ringArc\(THEME\.status\.alert, ([\d.]+), null, n\.alphaDraw .*? n\.px \+ ENCODING\.hidden\.offsetPx \+ ([\d.]+), 0, Math\.PI \* 2\)")
hw, ho = one(r'hidden: \{ ring: "dashed", dash: \[4, 4\], widthPx: ([\d.]+), offsetPx: ([\d.]+) \}')
so = one(r"selectionRingOffsetPx: ([\d.]+)")
sw = one(r"if \(n\.id === S\.locked\) \{\s*setAlpha\(ctx, alpha\); ctx\.strokeStyle = THEME\.accent\.selection; ctx\.lineWidth = ([\d.]+);")
w, d, hw, ho, so, sw = map(float, (w, d, hw, ho, so, sw))
c = ho + d
print("%.3f/%.3f/%.3f/%.3f" % (c - w / 2, c + w / 2, (c - w / 2) - (ho + hw / 2), (so - sw / 2) - (c + w / 2)))
PY
al_gap() { python3 -B "$AL_T/gap.py" "$1" 2>&1 | head -n 1; }   # al_gap PAGE -> inner edge/outer edge/gap to the hidden-SSID ring/gap to the selection ring, in px
AL_GAP=$(al_gap "$H")
al_copy "$AL_T/p-gap.html" 'ringArc(THEME.status.alert, 1.5, null, n.alphaDraw' 'ringArc(THEME.status.alert, 1.25, null, n.alphaDraw' 'n.px + ENCODING.hidden.offsetPx + 1.5, 0, Math.PI * 2); } }' 'n.px + ENCODING.hidden.offsetPx + 1.4, 0, Math.PI * 2); } }'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; AL_GAPP=$(al_gap "$AL_T/p-gap.html")
AL_OK=0; [ "$AL_GAP" = "10.750/12.250/0.250/0.000" ] && [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_GAPP" != "$AL_GAP" ] && AL_OK=1
rowif "alerts: the ring's band is as section 14.6 states it: from 10.75 to 12.25 px beyond the star, 0.25 px clear of the hidden-SSID ring and touching the selection ring [$AL_GAP]; a ring thinned to 1.25 px at 11.4 reads $AL_GAPP and the row is red for it (copy differs in $AL_C1 line)" [ "$AL_OK" = 1 ]

# ---- R11 the Scope (phone fan, spec 2.3 and 2.4): the blip of an alerted access point blinks in the ring's rhythm. The ring is drawn by drawStars, which the Scope calls; what the Scope
# lacked was the frame for each step (its frame rule knew only the wave and the snow). Whitehall, at 390x844 with the wave over: between 1 and 6 frames in 0.7 s, the ring takes both
# its levels on the canvas within 2.7 s; without alerts, under reduced motion (steady, one level) and paused at most 3 frames each.
AL_EVS='(async()=>{const sleep=STARCHORUS.wait,I=STARCHORUS._internals,S=I.S,o={};
STARCHORUS.setTheme("whitehall");
const fx=await (await fetch("starchorus.json")).json();fx.aps.forEach(a=>{a.clients=[];});fx.unassociated=[];fx.generated+=10;STARCHORUS.load(fx,"al-scope");await sleep(4500);   // the wave (1.2 s here) and its 1.5 s of grace are over
o.on=document.documentElement.dataset.scope;
const n=async()=>{const a=S.perf.rendered;await sleep(700);return S.perf.rendered-a;};
const ring=()=>{const q=STARCHORUS.nodeScreen("02:00:5e:a1:00:01");return STARCHORUS.pixel("sky",Math.floor(q.sx+q.px+11.5),Math.round(q.sy)).a;};
o.frames=await n();o.again=await n();
const lv=new Set();for(let k=0;k<27;k++){lv.add(ring());await sleep(100);}o.levels=[...lv].filter(a=>a>0).length;
const keep=S.alerts;S.alerts=[];S.dirty=true;await sleep(300);o.none=await n();S.alerts=keep;S.dirty=true;
STARCHORUS.setReducedMotion(true);await sleep(300);o.rm=await n();
const rl=new Set();for(let k=0;k<12;k++){rl.add(ring());await sleep(100);}o.rmLv=[...rl].filter(a=>a>0).length;STARCHORUS.setReducedMotion(null);
STARCHORUS.setToggles({paused:true});await sleep(300);o.paused=await n();STARCHORUS.setToggles({paused:false});
STARCHORUS.setTheme("foundation");await sleep(1500);o.fnd=await n();o.fnd2=await n();   // the pulse of Foundation is smooth in the sky and asks for every frame there; in the Scope it is sampled at the half second like the others
o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
# al_scope PAGE PREFIX: the Scope eval on PAGE (the page, or a planted copy); the value comes back in AL_S, its verdict ("ok" or "bad") in AL_SOK
al_scope() {
  AL_HK=$H; H=$1
  runq "$AL_FX" "$AL_Q&scope=1" "$2" --width 390 --height 844 --mobile --fps 0 --wait 3 --eval-timeout 90 --eval "$AL_EVS" >/dev/null 2>&1
  H=$AL_HK
  AL_S=$(evalv "$2.json" 1)
  AL_SOK=$(printf '%s' "$AL_S" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("ok" if d["on"]=="on" and 1<=d["frames"]<=6 and 1<=d["again"]<=6 and d["levels"]>=2 and d["none"]<=3 and d["rm"]<=3 and d["rmLv"]==1 and d["paused"]<=3 and 1<=d["fnd"]<=6 and 1<=d["fnd2"]<=6 and d["errors"]==0 else "bad")' 2>/dev/null)
}
al_scope "$H" "$AL_T/scope"
rowif "alerts: the Scope blip of an alerted access point blinks in the ring's rhythm (Whitehall, fan on, wave over: between 1 and 6 frames in 0.7 s and both levels of the chalk blink on the canvas within 2.7 s; without alerts, paused and under reduced motion at most 3 frames, and steady in one level under reduced motion; Foundation, whose pulse is smooth in the sky, between 1 and 6 frames in 0.7 s too) [${AL_S:-no-value}]" [ "$AL_SOK" = ok ]
# the Scope key bites: the copy that is never asked for the step renders no frame in the Scope and the blip keeps one level (the same planted copy as the sky's frame key)
al_copy "$AL_T/p-noreq-sc.html" "$AL_REQ" '!S.ui.paused && false) {'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_scope "$AL_T/p-noreq-sc.html" "$AL_T/scope-noreq"
AL_V=$(printf '%s' "$AL_S" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["frames"], d["levels"], d["errors"])' 2>/dev/null)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_SOK" = bad ] && [ "$AL_V" = "0 1 0" ] && AL_OK=1
rowif "alerts: the Scope key bites: a loop that is never asked for the step renders no frame in the Scope and the blip keeps one level [copy differs in $AL_C1 line, frames/levels/errors ${AL_V:-no-value}, verdict ${AL_SOK:-none}]" [ "$AL_OK" = 1 ]
# the Foundation key bites: the smooth pulse asked for on every frame in the Scope as well (the sky's rule) renders more than 6 frames in 0.7 s there and only there
al_copy "$AL_T/p-fnd.html" 'cm === "glowPulse" && !scopeOn ? 0 :' 'cm === "glowPulse" ? 0 :'
AL_C1=$AL_CPD; AL_C1R=$AL_CPR; al_scope "$AL_T/p-fnd.html" "$AL_T/scope-fnd"
AL_V=$(printf '%s' "$AL_S" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["frames"] <= 6, d["levels"] >= 2, d["fnd"] > 6, d["errors"])' 2>/dev/null)
AL_OK=0; [ "$AL_C1R" = 0 ] && [ "$AL_C1" = 1 ] && [ "$AL_SOK" = bad ] && [ "$AL_V" = "True True True 0" ] && AL_OK=1
rowif "alerts: the Foundation key bites: a smooth pulse asked for on every frame in the Scope renders more than 6 frames in 0.7 s there, while Whitehall's blip stays within 6 [copy differs in $AL_C1 line, Whitehall frames/levels, Foundation over 6, errors ${AL_V:-no-value}, verdict ${AL_SOK:-none}]" [ "$AL_OK" = 1 ]
