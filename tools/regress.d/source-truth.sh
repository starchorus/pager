# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/source-truth.sh -- source truth: sourceKind + copy tokens (D4), liveness (D3),
# the U4 chip, the D13 lazy mode line AND the D13 poll gate, the wall-clock-free ingest and the ACTIVE
# swap in starchorus-display.sh. Sourced by tools/regress.sh with cwd = repo root, after the core rows.
# Only SRC_* globals are set.
#
# Six Chrome runs. They may keep ?fixed: every eval reads DOM text, STARCHORUS.stats() or STARCHORUS.hist(),
# never a node position or a canvas (under a frozen clock nothing fades in). The sequence evals
# (pollNow chains) are exactly the case ?poll=0&spin=0&intro=0&fixed=… is meant for.
# Two evals share the active.json and the field-probes.json run; ?poll=0 still performs the one boot
# poll (spec §2.7), so the served fixture is the source before the first pollNow().

SRC_CLAIM='rx only|nothing (is )?transmitted|never transmits|nothing sent|receive[- ]only|listen only|passive rx|nothing leaves'
SRC_ACT='ACTIVE SCAN · the collector sent probe requests'
SRC_ACTRE='ACTIVE SCAN [·-] the collector sent probe requests'   # Whitehall's teleprinter has no middle dot (ITA2), it types a hyphen; the display script is checked with the literal form
SRC_Q="?poll=0&spin=0&fixed=$STARCHORUS_FIXED&intro=0"

# every claim surface of one theme: body text, all [title], meta description, logon lines + #intro-text,
# both classbar lines. Returns "<sourceKind> <claim hits> <themes carrying the ACTIVE line> <chips>".
SRC_EVC='(async()=>{const re=/'"$SRC_CLAIM"'/i,act=/'"$SRC_ACTRE"'/i;let bad=0,ok=0,chips=[];for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await STARCHORUS.wait(50);const ti=[...document.querySelectorAll("[title]")].map(e=>e.getAttribute("title")).join("\n"),me=document.querySelector("meta[name=description]").content,lo=STARCHORUS.logonLines().join("\n")+"\n"+document.getElementById("intro-text").textContent,ba=document.getElementById("classbar-top").textContent+"\n"+document.getElementById("classbar-bot").textContent,tx=document.body.innerText;bad+=[tx,ti,me,lo,ba].filter(x=>re.test(x)).length;ok+=[act.test(tx),act.test(me),STARCHORUS.logonLines().some(l=>act.test(l)),act.test(ba)].every(Boolean)?1:0;chips.push(document.getElementById("mode-chip").textContent);}STARCHORUS.setTheme("foundation");return [STARCHORUS.stats().sourceKind,bad,ok,chips.join("/")].join(" ");})()'
# 6 polls of an unchanged served capture -> stale on the 6th; a newer `generated` resets the counter
SRC_EVS='(async()=>{const s=[];for(let i=0;i<6;i++)s.push((await STARCHORUS.pollNow()).captureStale?1:0);const c=document.getElementById("mode-chip").textContent;STARCHORUS.load({source:"recon-db",generated:1789300005,aps:[{bssid:"02:00:00:00:00:01",ssid:"x",band:"2.4",channel:1,rssi:-50}]},"starchorus.json",{mode:"live"});return s.join("")+" "+c+" "+STARCHORUS.stats().stalePolls+" "+document.getElementById("mode-chip").textContent;})()'
# state after 6 polls: kind | captureStale | chip | chip class | chip title
SRC_EVN='(async()=>{for(let i=0;i<6;i++)await STARCHORUS.pollNow();const s=STARCHORUS.stats();const c=document.getElementById("mode-chip");return [s.sourceKind,s.captureStale,c.textContent,c.className,c.getAttribute("title")].join("|");})()'
# demo and recorded never go stale; failed polls of a poll-fed source do count; pollNow shares one request
SRC_EVD='(async()=>{const doc={source:"recon-db",generated:1789300000,aps:[{bssid:"02:00:00:00:00:01",ssid:"x",band:"2.4",channel:1,rssi:-50}]};const r=[];for(let i=0;i<8;i++)await STARCHORUS.pollNow();r.push(STARCHORUS.stats().sourceKind+":"+STARCHORUS.stats().captureStale+":"+document.getElementById("mode-chip").textContent);STARCHORUS.load(doc,"pasted capture");for(let i=0;i<6;i++)await STARCHORUS.pollNow();r.push(STARCHORUS.stats().sourceKind+":"+STARCHORUS.stats().captureStale);STARCHORUS.load(doc,"API",{mode:"live"});for(let i=0;i<6;i++)await STARCHORUS.pollNow();r.push(STARCHORUS.stats().sourceKind+":"+STARCHORUS.stats().captureStale);const a=STARCHORUS.pollNow(),b=STARCHORUS.pollNow();r.push(a===b);await a;return r.join(" ");})()'
# §2 determinism: no capture time -> "Last seen —" and an undated history sample (ts null).
# Its own BSSID (…0a), so the run's earlier loads leave no history behind for it.
SRC_EVT='(()=>{const ID="02:00:00:00:00:0a";const mk=(g)=>{const d={source:"recon-db",aps:[{bssid:ID,ssid:"x",band:"2.4",channel:1,rssi:-50,last_seen:1789299990}],unassociated:[]};if(g!=null)d.generated=g;return d;};STARCHORUS.load(mk(null),"A");STARCHORUS.select(ID);const a=(document.getElementById("detail-body").innerText.match(/Last seen\s*([^\n]*)/)||[])[1];const ta=STARCHORUS.hist(ID).ts;STARCHORUS.load(mk(1789300000),"B");STARCHORUS.select(ID);const b=(document.getElementById("detail-body").innerText.match(/Last seen\s*([^\n]*)/)||[])[1];return JSON.stringify({a,ta,b,tb:STARCHORUS.hist(ID).ts});})()'
# §2 determinism: the history sweep counts capture time (HIST_KEEP_S = 300 s of `generated`), not polls and not wall time; an undated
# document counts ingests (HIST_KEEP_INGESTS = 60). Dated 10 s apart: kept at 290 and 300 s, gone at 310 s; dated 1 s apart: still kept
# after 61 ingests; undated: kept at 59 and 60 ingests, gone at 61.
SRC_EVI='(()=>{const ap=(b)=>({bssid:b,ssid:"s"+b.slice(-2),band:"2.4",channel:1,rssi:-50}),mk=(g,l)=>Object.assign({source:"recon-db"},g==null?{}:{generated:g},{aps:l});const run=(n,a,b,g0,st)=>{STARCHORUS.load(mk(g0,[ap(a),ap(b)]),"A");const res=[];for(let i=1;i<=n;i++){STARCHORUS.load(mk(g0==null?null:g0+st*i,[ap(b)]),"A");res.push(STARCHORUS.hist(a)!==null);}return res;};const x=run(31,"02:00:00:00:00:01","02:00:00:00:00:02",1,10),y=run(61,"02:00:00:00:00:03","02:00:00:00:00:04",1000,1),z=run(61,"02:00:00:00:00:05","02:00:00:00:00:06",null,0);return JSON.stringify([x[28],x[29],x[30],y[60],z[58],z[59],z[60]]);})()'
# D4: the client detail hint drops "rx only" on an ACTIVE capture; loadDemo is demo; labels stay escaped
SRC_EVH='(()=>{STARCHORUS.load({source:"iw-scan-ACTIVE",generated:1789300000,aps:[{bssid:"02:00:00:00:00:01",ssid:"x",band:"2.4",channel:1,rssi:-50}],unassociated:[{mac:"02:00:00:00:00:99",rssi:-60,probes:["x"]}]},"API");STARCHORUS.select("02:00:00:00:00:99");const t=document.getElementById("detail").innerText;const o={kind:STARCHORUS.stats().sourceKind,hint:/heard probe requests/i.test(t),claim:/rx only/i.test(t)};STARCHORUS.loadDemo();o.demo=[STARCHORUS.stats().sourceKind,STARCHORUS.stats().mode,document.getElementById("mode-chip").textContent].join("/");STARCHORUS.load({aps:[{bssid:"aa:bb:cc:dd:ee:09",ssid:"<img src=x onerror=window.__x=1>"}]},"<b>evil</b>");o.esc=document.getElementById("source-desc").innerHTML.includes("&lt;b&gt;evil")&&window.__x===undefined;STARCHORUS.load({aps:[]},12345);o.lbl=STARCHORUS.stats().sourceLabel;return JSON.stringify(o);})()'
# D4: THEME.copy has the same leaf paths in all three themes, and copy.rx/copy.active the same sites
SRC_EVK='(()=>{const T=STARCHORUS._internals.THEMES;const fl=(o,p="",out=[])=>{for(const k of Object.keys(o)){const v=o[k],q=p?p+"."+k:k;if(v&&typeof v==="object"&&!Array.isArray(v))fl(v,q,out);else out.push(q);}return out;};const ks=["foundation","wargames","whitehall"].map(t=>fl(T[t].copy).sort().join(","));return JSON.stringify({sym:ks[0]===ks[1]&&ks[1]===ks[2],n:ks[0].split(",").length,rxEqActive:Object.keys(T.foundation.copy.rx).sort().join()===Object.keys(T.foundation.copy.active).sort().join()});})()'
# D13: the mode line is computed when it is typed, so it names the ACTIVE capture the first poll brought
SRC_EVL='(()=>{const t=document.getElementById("intro-text").textContent;return /MODE: ACTIVE SCAN · THE COLLECTOR SENT PROBE REQUESTS/.test(t)&&!/'"$SRC_CLAIM"'/i.test(t);})()'
# D13 gate: with the feed held back 2 s the overlay is up but NOTHING has been typed at ~400 ms -- the
# typing waits for the first completed poll. Independent of typing speed and far from the 1 s release cap
# (measured: 0 chars with the gate, 13 without it). The only row that uses runq's --delay.
SRC_EVG='[document.getElementById("intro-text").textContent.length,STARCHORUS.stats().introShown].join("/")'

runq "$F/active.json" "$SRC_Q" "out/$P-src-active" --wait 3 --fps 0 \
  --eval "$SRC_EVC" --eval "$SRC_EVN" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
SRC_A=$(evalv "out/$P-src-active.json" 1)
SRC_AN=$(evalv "out/$P-src-active.json" 2)
SRC_AE=$(evalv "out/$P-src-active.json" 3)

runq "$F/field-probes.json" "$SRC_Q" "out/$P-src-passive" --wait 3 --fps 0 \
  --eval "$SRC_EVC" --eval "$SRC_EVS" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
SRC_P=$(evalv "out/$P-src-passive.json" 1)
SRC_PS=$(evalv "out/$P-src-passive.json" 2)
SRC_PE=$(evalv "out/$P-src-passive.json" 3)

runq "$F/empty-none.json" "$SRC_Q" "out/$P-src-none" --wait 2 --fps 0 \
  --eval "$SRC_EVN" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
SRC_NN=$(evalv "out/$P-src-none.json" 1)
SRC_NE=$(evalv "out/$P-src-none.json" 2)

runq demo "?debug=1&poll=0&spin=0&fixed=$STARCHORUS_FIXED&intro=0" "out/$P-src-demo" --wait 2 --fps 0 \
  --eval "$SRC_EVD" --eval "$SRC_EVT" --eval "$SRC_EVI" --eval "$SRC_EVH" --eval "$SRC_EVK" \
  --eval "STARCHORUS.errors().length" >/dev/null 2>&1
SRC_D=$(evalv "out/$P-src-demo.json" 1)
SRC_T=$(evalv "out/$P-src-demo.json" 2)
SRC_I=$(evalv "out/$P-src-demo.json" 3)
SRC_H=$(evalv "out/$P-src-demo.json" 4)
SRC_K=$(evalv "out/$P-src-demo.json" 5)
SRC_DE=$(evalv "out/$P-src-demo.json" 6)

# the logon run keeps the intro (no intro=0, fresh profile) and needs the full typing time
runq "$F/active.json" "?theme=wargames&poll=0" "out/$P-src-logon" --wait 10 --fps 0 \
  --eval "$SRC_EVL" --eval "STARCHORUS.errors().length" >/dev/null 2>&1
SRC_L=$(evalv "out/$P-src-logon.json" 1)
SRC_LE=$(evalv "out/$P-src-logon.json" 2)

runq "$F/active.json" "?theme=wargames&poll=0" "out/$P-src-gate" --delay 2 --wait 0.4 --fps 0 \
  --eval "$SRC_EVG" >/dev/null 2>&1
SRC_G=$(evalv "out/$P-src-gate.json" 1)

# ---- rows
if [ "$SRC_A" = "active 0 3 Active scan/Active scan/Active scan" ] && [ "$SRC_AE" = 0 ]; then
  row "source truth: claims swap on ACTIVE [$SRC_A]" PASS
else
  row "source truth: claims on ACTIVE [$SRC_A] err ${SRC_AE:-?}" FAIL
fi
if [ "$SRC_P" = "live 11 0 Live/Live/Live" ] && [ "$SRC_PE" = 0 ]; then
  row "source truth: passive control (11 claim places; Whitehall's live banner says REAL-WORLD DATA · NOT EXERCISE PLAY, no RX claim) [$SRC_P]" PASS
else
  row "source truth: passive control [$SRC_P] err ${SRC_PE:-?}" FAIL
fi
if [ "$SRC_PS" = "000001 Stale 0 Live" ]; then
  row "D3 stale after 6 polls, reset on new gen [$SRC_PS]" PASS
else
  row "D3 stale after 6 polls [$SRC_PS]" FAIL
fi
if [ "$SRC_D" = "demo:false:Sample recorded:false live:true true" ] && [ "$SRC_DE" = 0 ]; then
  row "D3 demo/recorded never stale, 1 request [$SRC_D]" PASS
else
  row "D3 demo/recorded never stale [$SRC_D] err ${SRC_DE:-?}" FAIL
fi
if [ "$SRC_NN" = "none|false|No feed|mode none|" ] && [ "$SRC_AN" = "active|true|Active scan|mode active stale|no new capture for 6 polls" ] && [ "$SRC_NE" = 0 ]; then
  row "D3 none never stale, poll-fed ACTIVE can be stale" PASS
else
  row "D3 none [$SRC_NN] active [$SRC_AN]" FAIL
fi
if [ "$SRC_L" = true ] && [ "$SRC_LE" = 0 ]; then
  row "D13 logon mode line computed lazily = ACTIVE" PASS
else
  row "D13 logon mode line [$SRC_L] err ${SRC_LE:-?}" FAIL
fi
rowif "D13 logon waits for the first poll [$SRC_G]" [ "$SRC_G" = "0/true" ]
if [ "$SRC_T" = '{"a":"—","ta":[null],"b":"10 s ago","tb":[null,1789300000]}' ]; then
  row "§2 lastSeenAge/hist without generated [—, ts null]" PASS
else
  row "§2 lastSeenAge/hist without generated [$SRC_T]" FAIL
fi
if [ "$SRC_I" = "[true,true,false,true,true,true,false]" ]; then
  row "§2 history sweep counts capture time (300 s), undated ingests (60) $SRC_I" PASS
else
  row "§2 history sweep counts capture time, undated ingests [$SRC_I]" FAIL
fi
if [ "$SRC_H" = '{"kind":"active","hint":true,"claim":false,"demo":"demo/demo/Sample","esc":true,"lbl":"12345"}' ]; then
  row "D4 detail hint, loadDemo = Sample, label escaped" PASS
else
  row "D4 detail hint/loadDemo/label [$SRC_H]" FAIL
fi
if [ "$SRC_K" = '{"sym":true,"n":62,"rxEqActive":true}' ]; then
  row "D4 copy group symmetric (62 paths, rx = active, including signal, skyVoice, legendHeads, badge, crowdSign, lamps, logonListen, tote, clock, compendium, vault, lampStrip, caption)" PASS
else
  row "D4 copy group symmetric [$SRC_K]" FAIL
fi

# ---- static: every claim phrase lives in the pre-JS fallback (§0/§11) or in the copy tokens (§21)
SRC_CS=$(grep -niE "$SRC_CLAIM" "$H" | cut -d: -f1 | secs | sort -un | tr '\n' ' ')
SRC_BAD=0
for SRC_S in $SRC_CS; do case "$SRC_S" in 0 | 11 | 21) ;; *) SRC_BAD=1 ;; esac; done
SRC_S5=$(g 'MODE: RX ONLY — NOTHING IS TRANSMITTED')   # the pre-JS mode line: exactly one constant
if [ "$SRC_BAD" = 0 ] && [ "$SRC_S5" = 1 ]; then
  row "claim phrases in {$SRC_CS} ⊆ {0,11,21}" PASS
else
  row "claim phrases {$SRC_CS} / RX-MODE const $SRC_S5" FAIL
fi

# ---- starchorus-display.sh: the same swap on the Overview (cmp + shellcheck are core rows)
SRC_N1=$(for SRC_S in summary top bands devices probes clients bluetooth air; do
  STARCHORUS_DISPLAY_PLAIN=1 sh "$R/starchorus-display.sh" --once "$SRC_S" "$F/active.json"
done | grep -ciE "$SRC_CLAIM")
SRC_N2=$(for SRC_S in summary probes; do
  STARCHORUS_DISPLAY_PLAIN=1 sh "$R/starchorus-display.sh" --once "$SRC_S" "$F/active.json"
done | grep -cF "$SRC_ACT")
SRC_N3=$(STARCHORUS_DISPLAY_PLAIN=1 sh "$R/starchorus-display.sh" --once summary "$F/field-probes.json" | grep -c 'rx only, nothing sent')
rowif "starchorus-display.sh ACTIVE swap ($SRC_N1/$SRC_N2/$SRC_N3)" [ "$SRC_N1/$SRC_N2/$SRC_N3" = 0/2/1 ]
