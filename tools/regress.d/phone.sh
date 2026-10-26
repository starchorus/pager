# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/phone.sh -- D21 phone mode (§9.8) and Hide panels (U), at every size.
# GUARDS AGAINST: chrome that overlaps or runs off a phone screen; a control that a phone cannot reach or hit (< 44 px); a sheet
#                 that shows two cards at once or forgets its height; the sky under the bar or the sheet; phone rules leaking
#                 into the desktop (any --ph-* variable, a .ph-only element shown, the sky off the viewport centre); a Hide
#                 that drops the Whitehall disclaimer, the dialogues or the status; reduced motion that still animates.
#                 A label box that leaves the sky (phone and desktop); a Camera row that is missing in 2D or shows the orbit arrows
#                 there; a 2D zoom that stops at 1 or leaves the rings, the names or the bubble counters behind when it shrinks.
# NEGATIVE PROBE: the probes name what fails; they went red while this was built on 25 px sortable columns, on a channel bar
#                 that kept its desktop offset inside the sheet, on a mouse drag that left the sheet's head, on a reduced-motion
#                 sheet that still faded with the panels hidden. The breakpoint row has both sides of every bound. Nothing
#                 inside a sideways scroller (the inventory table) counts as off the screen.
#                 The label rows have one too: a page copy without the label margin must see labels outside the sky, on the phone and
#                 on the desktop; the numbers they judge are layoutInfo().labelsOutside and the least labelsDrawn per state.
#                 The count is taken over the list of drawn labels, not inside place(), so a second page copy draws the AP names without place()
#                 (the old occupy loop) and must also see labels outside on the phone.
# NOT PROVEN:     iOS WebKit (safe areas, the soft keyboard, Safari's bars, VoiceOver), a real finger; the check on a real iPhone
#                 is listed in docs/architecture.md §9.8. The desktop pixels are compared with the page before the change by hand, not here.
# --mobile (cdp.py) emulates a phone: mobile metrics and touch, so (pointer: coarse) matches as on a phone on its side.
# Sourced by tools/regress.sh with cwd = repo root, after the core rows. Only PHN_* globals are set.

PHN_Q="?poll=0&spin=0&intro=0&fixed=$STARCHORUS_FIXED"
PHN_RDY='window.STARCHORUS && document.fonts.status === "loaded" && STARCHORUS.stats().apsTotal > 0 && STARCHORUS.stats().sourceKind !== "demo"'   # --ready: the fonts are in and the capture is loaded; the --wait beside it stays the ceiling
PHN_MAXB=650000   # bytes: the size the page may reach (wc -c starchorus.html); 650000 since 26 October 2026 on the owner's word, for 0.2.5's mark on names and the fixes after the switch audit (0.2's cap was 625000, raised from 620000 for the Scope and the alerts)
# shared helpers inside every eval: visible, rect, pairwise overlap of the phone chrome, tap targets under 44 px, overflow
PHN_JS='const E=i=>document.getElementById(i),R=e=>e.getBoundingClientRect(),vis=e=>!!e&&e.getClientRects().length>0&&getComputedStyle(e).display!=="none"&&getComputedStyle(e).visibility!=="hidden"&&R(e).width>0,
ovl=()=>{const L=["bar","sheet","classbar-top","classbar-bot","dtg","panels-pill"].map(E).filter(vis),o=[];for(let i=0;i<L.length;i++)for(let j=i+1;j<L.length;j++){const a=R(L[i]),b=R(L[j]),w=Math.min(a.right,b.right)-Math.max(a.left,b.left),h=Math.min(a.bottom,b.bottom)-Math.max(a.top,b.top);if(w>0.5&&h>0.5)o.push(L[i].id+"/"+L[j].id)}return o},
small=()=>[...document.querySelectorAll("#bar button,#sheet button,#t-scope,#panels-pill,#sheet button.chip,#sheet th[data-sort],#sheet tr[data-id],#sheet input,#sheet select")].filter(vis).filter(e=>R(e).width<43.5||R(e).height<43.5).map(e=>(e.id||e.tagName+":"+e.textContent.trim().slice(0,8))+" "+Math.round(R(e).width)+"x"+Math.round(R(e).height)),
inner=e=>{for(let p=e.parentElement;p&&p.id!=="sheet-body"&&p.id!=="bar";p=p.parentElement)if(getComputedStyle(p).overflowX!=="visible")return true;return false},
wide=()=>document.documentElement.scrollWidth!==innerWidth||[...document.querySelectorAll("#bar *,#sheet *")].some(e=>vis(e)&&!inner(e)&&(R(e).right>innerWidth+0.5||R(e).left<-0.5)),
shown=()=>["controls","legend","detail","help"].filter(i=>vis(E(i))).join("+");'

# ---- desktop (1440x900): nothing of the phone, the sky on the viewport centre, Hide keeps every box, the pill, U, Ctrl+U, dialogues
PHN_EVD='(async()=>{'"$PHN_JS"'const W=STARCHORUS.wait,o={},snap=()=>JSON.stringify([...document.querySelectorAll("[id]")].filter(e=>e.closest(".panel")&&e.id!=="panels-pill").map(e=>{const r=R(e);return e.id+":"+[r.left,r.top,r.width,r.height].map(Math.round)}));
o.mode=[document.documentElement.dataset.phone,[...document.querySelectorAll(".ph-only")].filter(vis).length,document.documentElement.style.cssText.indexOf("--ph-")<0].join();
const s=STARCHORUS.phone().sky;o.sky=s.cx===innerWidth/2&&s.cy===innerHeight/2&&s.r===Math.round(Math.min(innerWidth,innerHeight)/2*920)/1000;
const tp=R(E("t-panels")),cr=R(E("controls"));o.corner=tp.left>=cr.left&&tp.right<=cr.right&&tp.top>=cr.top&&[...E("controls").querySelectorAll("button")].filter(b=>b.id!=="t-panels"&&vis(b)).every(b=>{const r=R(b);return r.right<=tp.left||r.left>=tp.right||r.bottom<=tp.top||r.top>=tp.bottom});
const s0=snap();document.body.dispatchEvent(new KeyboardEvent("keydown",{key:"u",bubbles:true}));await W(350);
o.hidden=[STARCHORUS.getToggles().panels,[...document.querySelectorAll(".panel")].filter(e=>e.id!=="detail"&&e.id!=="paste-box"&&e.id!=="export-box"&&getComputedStyle(e).visibility!=="hidden").map(e=>e.id).join("+")||"none",vis(E("panels-pill")),E("pill-chip").textContent===E("mode-chip").textContent,snap()===s0,vis(E("classbar-top"))].join();
o.saved=(STARCHORUS.storageDump()||{}).panels;
STARCHORUS.select(STARCHORUS.nodes("ap")[0].id);await W(300);o.detail=vis(E("detail"));STARCHORUS.deselect();
E("btn-export").dispatchEvent(new MouseEvent("click",{bubbles:true}));await W(300);o.dialog=vis(E("export-box"));E("export-close").dispatchEvent(new MouseEvent("click",{bubbles:true}));
document.body.dispatchEvent(new KeyboardEvent("keydown",{key:"u",ctrlKey:true,bubbles:true}));o.ctrl=STARCHORUS.getToggles().panels;
document.body.dispatchEvent(new KeyboardEvent("keydown",{key:"u",bubbles:true}));await W(350);o.back=[STARCHORUS.getToggles().panels,vis(E("controls")),vis(E("panels-pill"))].join();
o.help=/Hide or show the panels/.test(E("help-list").textContent)&&E("t-panels").title.indexOf("[U]")>0;o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
runq "$F/field-probes.json" "$PHN_Q" "out/$P-phn-desk" --width 1440 --height 900 --wait 4 --ready "$PHN_RDY" --fps 0 --eval "$PHN_EVD" >/dev/null 2>&1
PHN_V=$(evalv "out/$P-phn-desk.json" 1)
PHN_W='{"mode":"off,0,true","sky":true,"corner":true,"hidden":"false,none,true,true,true,false","saved":false,"detail":true,"dialog":true,"ctrl":false,"back":"true,true,false","help":true,"errors":0}'
rowif "desktop: no phone chrome or --ph-*, sky on the viewport centre, #t-panels in its corner; U hides every panel but the detail and the dialogues, keeps every box, shows the pill = chip, is saved, Ctrl+U is the browser's" [ "$PHN_V" = "$PHN_W" ]
[ "$PHN_V" = "$PHN_W" ] || { echo "    got:  ${PHN_V:-no-value}"; echo "    want: $PHN_W"; }
# ?panels=0 hides from the boot and saves nothing (a query override)
runq "$F/field-probes.json" "$PHN_Q&panels=0" "out/$P-phn-qp" --width 1440 --height 900 --wait 3 --ready "$PHN_RDY" --fps 0 --eval '(async()=>{await STARCHORUS.wait(400);return [document.documentElement.dataset.panels,getComputedStyle(document.getElementById("controls")).visibility,String((STARCHORUS.storageDump()||{}).panels)].join()})()' >/dev/null 2>&1
PHN_V=$(evalv "out/$P-phn-qp.json" 1)
rowif "?panels=0: hidden from the boot, its value not saved [$PHN_V]" [ "$PHN_V" = "off,hidden,undefined" ]

# ---- phone portrait 375x812 in all three themes: bar, collapsed sheet, sky between them, no overlap, no sideways scroll; half, full
PHN_EVP='(async()=>{'"$PHN_JS"'const W=STARCHORUS.wait,o={};
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await W(500);const p=STARCHORUS.phone(),b=R(E("bar")),sh=R(E("sheet")),c=R(E("mode-chip")),ds=document.documentElement.dataset,bad=[];
 if(ds.phone!=="on"||p.card!=="controls"||p.detent!=="peek")bad.push("state:"+ds.phone+p.card+p.detent);
 if(Math.round(b.height)!==44||E("mode-chip").parentNode.id!=="bar"||c.right>b.right-7.5)bad.push("bar");
 if(E("bar-ap").textContent!==E("n-ap").textContent||E("bar-cl").textContent!==E("n-cl").textContent)bad.push("counts");
 if(Math.abs(sh.height-p.peek)>1)bad.push("peek "+sh.height);
 const ov=ovl();if(ov.length)bad.push("overlap "+ov);
 if(p.sky.cy-p.sky.r<b.bottom||p.sky.cy+p.sky.r>sh.top)bad.push("sky "+JSON.stringify(p.sky));
 if(wide())bad.push("wide");
 if(t==="whitehall"){const top=E("classbar-top"),bot=E("classbar-bot");if(!(top.scrollWidth<=top.clientWidth&&bot.scrollWidth<=bot.clientWidth&&/NOT A GOVERNMENT SYSTEM/.test(top.textContent)&&/NOT A GOVERNMENT SYSTEM/.test(bot.textContent)&&R(E("dtg")).bottom<=b.top-4&&sh.bottom<=innerHeight-R(bot).height-8+1))bad.push("banners");}
 STARCHORUS.setSheet("half");await W(400);const ph=STARCHORUS.phone();if(Math.abs(R(E("sheet")).height-ph.half)>1||ph.half<ph.peek+100||R(E("sheet")).top<ph.sky.cy+20)bad.push("half "+ph.half);
 STARCHORUS.setSheet("full");await W(400);const f=R(E("sheet"));if(f.top<b.bottom+8-1||E("sheet-body").scrollHeight<=E("sheet-body").clientHeight)bad.push("full "+f.top);
 for(const id of ["grp-view","grp-look","grp-layers","grp-watch","grp-analyse","chanbar","stats","source","masthead"]){E(id).scrollIntoView({block:"nearest"});const r=R(E(id)),bb=R(E("sheet-body"));if(!vis(E(id))||r.top<bb.top-0.5||r.bottom>bb.bottom+0.5)bad.push("section "+id);}
 if(wide())bad.push("wide-full");STARCHORUS.setSheet("peek");await W(400);
 o[t]=bad.join(";")||"ok";}
E("mast-brand").querySelector(".dot").dataset.live="live";o.pulse=getComputedStyle(E("mast-brand").querySelector(".dot")).animationName;
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
runq "$F/field-probes.json" "$PHN_Q" "out/$P-phn-port" --width 375 --height 812 --mobile --wait 4 --ready "$PHN_RDY" --fps 0 --eval-timeout 60 --eval "$PHN_EVP" >/dev/null 2>&1
PHN_V=$(evalv "out/$P-phn-port.json" 1)
PHN_W='{"foundation":"ok","wargames":"ok","whitehall":"ok","pulse":"pulse","errors":0}'
rowif "phone 375x812, 3 themes: bar 44 px with chip and counts, sheet collapsed, sky clear of both, no overlap or sideways scroll, banners whole, half keeps the device clear, full scrolls every section" [ "$PHN_V" = "$PHN_W" ]
[ "$PHN_V" = "$PHN_W" ] || echo "    got: ${PHN_V:-no-value}"

# ---- landscape 812x375 (touch, no ?phone): the side column, the sky right of it, full height clear of the bar
PHN_EVL='(async()=>{'"$PHN_JS"'const W=STARCHORUS.wait,o={};
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await W(500);STARCHORUS.setSheet("full");await W(400);const p=STARCHORUS.phone(),b=R(E("bar")),sh=R(E("sheet")),bad=[];
 if(document.documentElement.dataset.phone!=="on"||p.dock!=="side")bad.push("state");
 if(p.sky.cx-p.sky.r<Math.max(b.right,sh.right)-0.5)bad.push("sky "+JSON.stringify(p.sky));
 if(sh.top<b.bottom+8-1)bad.push("full "+sh.top);
 if(R(E("mode-chip")).right>b.right-7.5)bad.push("chip");
 const ov=ovl();if(ov.length)bad.push("overlap "+ov);if(wide())bad.push("wide");const s=small();if(s.length)bad.push("small "+s);
 STARCHORUS.setSheet("peek");await W(300);o[t]=bad.join(";")||"ok";}
o.errors=STARCHORUS.errors().length;return JSON.stringify(o)})()'
runq "$F/field-probes.json" "$PHN_Q" "out/$P-phn-land" --width 812 --height 375 --mobile --wait 4 --ready "$PHN_RDY" --fps 0 --eval-timeout 60 --eval "$PHN_EVL" >/dev/null 2>&1
PHN_V=$(evalv "out/$P-phn-land.json" 1)
PHN_W='{"foundation":"ok","wargames":"ok","whitehall":"ok","errors":0}'
rowif "phone 812x375 on its side: one left column, the sky right of it, full sheet below the bar, chip unclipped, no overlap, 44 px targets" [ "$PHN_V" = "$PHN_W" ]
[ "$PHN_V" = "$PHN_W" ] || echo "    got: ${PHN_V:-no-value}"

# ---- the Scope's button #t-scope (D22, spec 7.2): in #sheet-row where the row has the room (52 px beyond its other buttons: 375x812, 390x844, 430x932) and in #grp-look where it has not (320x568, and a
# phone on its side); 44x44 or more where it is a square and small() names it; the row never scrolls sideways; shown on the controls card only (not on a drawer, the legend, the keys or a detail)
PHN_EVS='(async()=>{'"$PHN_JS"'const W=STARCHORUS.wait,sc=E("t-scope"),row=E("sheet-row"),bad=[];
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await W(500);STARCHORUS.setSheet("full");await W(400);const r=R(sc);
 if(!vis(sc))bad.push(t+" hidden");else{if(r.width<43.5||r.height<43.5)bad.push(t+" "+Math.round(r.width)+"x"+Math.round(r.height));if(small().some(x=>x.indexOf("t-scope")===0))bad.push(t+" small()")}
 if(sc.parentNode.id!==WANT)bad.push(t+" in "+sc.parentNode.id);
 if(row.scrollWidth>row.clientWidth)bad.push(t+" row "+row.scrollWidth+">"+row.clientWidth);
 if(wide())bad.push(t+" wide")}
STARCHORUS.setToggles({inventory:true});await W(400);if(vis(sc))bad.push("drawer");STARCHORUS.setToggles({inventory:false});await W(300);
E("t-legend").dispatchEvent(new MouseEvent("click",{bubbles:true}));await W(400);if(vis(sc))bad.push("legend");E("sheet-close").dispatchEvent(new MouseEvent("click",{bubbles:true}));await W(300);
E("t-help").dispatchEvent(new MouseEvent("click",{bubbles:true}));await W(400);if(vis(sc))bad.push("keys");E("sheet-close").dispatchEvent(new MouseEvent("click",{bubbles:true}));await W(300);
STARCHORUS.select(STARCHORUS.nodes("ap")[0].id);await W(400);if(vis(sc))bad.push("detail");STARCHORUS.deselect();await W(300);if(!vis(sc))bad.push("back");
return JSON.stringify([bad.join(";")||"ok",STARCHORUS.errors().length])})()'
phn_scope() {   # phn_scope WANT WIDTH HEIGHT -> the eval's verdict on the page $H serves: ["ok",0], or what is wrong (WANT = the id of the parent the button should have)
  runq "$F/devices.json" "$PHN_Q" "out/$P-phn-sc-$2x$3" --width "$2" --height "$3" --mobile --wait 4 --ready "$PHN_RDY" --fps 0 --eval-timeout 60 --eval "(async()=>{const WANT=\"$1\";${PHN_EVS#\(async()=>\{}" >/dev/null 2>&1
  evalv "out/$P-phn-sc-$2x$3.json" 1
}
PHN_V=""
for PHN_Z in sheet-row:375:812 sheet-row:390:844 sheet-row:430:932 grp-look:320:568 grp-look:812:375; do
  PHN_R=$(phn_scope "${PHN_Z%%:*}" "$(echo "$PHN_Z" | cut -d: -f2)" "${PHN_Z##*:}")
  [ "$PHN_R" = '["ok",0]' ] || PHN_V="$PHN_V ${PHN_Z}=${PHN_R:-no-value}"
done
rowif "phone: #t-scope sits in #sheet-row at 375x812, 390x844 and 430x932 and in #grp-look at 320x568 and on its side (812x375), is 44x44 or more where it is a square and small() names it, the row never scrolls sideways, in all three themes, and is shown on the controls card only${PHN_V:+ [$PHN_V]}" [ -z "$PHN_V" ]
# the control: a page copy whose room test is 0 puts the button into the row at 320x568, where it does not fit: the row scrolls (or the button is not in #grp-look) and the verdict is not "ok"
sed 's/c.scrollWidth + 8), -8) >= 52;/c.scrollWidth + 8), -8) >= 0;/' "$H" > "out/$P-phn-noroom.html"
PHN_KH=$H; H="out/$P-phn-noroom.html"; PHN_R=$(phn_scope grp-look 320 568); H=$PHN_KH
PHN_KD=$(diff "$H" "out/$P-phn-noroom.html" | grep -c '^<')
PHN_KOK=0; [ "$PHN_KD" = 1 ] && [ "$PHN_R" != '["ok",0]' ] && PHN_KOK=1
rowif "phone: the Scope button's control: a page copy with the 52 px room test set to 0 (one line differs: $PHN_KD) is red at 320x568 [${PHN_R:-no-value}]" [ "$PHN_KOK" = 1 ]

# ---- cards and tap targets (390x844): one card at a time, × back to the controls at their height, every target ≥ 44 px
PHN_EVC='(async()=>{'"$PHN_JS"'const W=STARCHORUS.wait,o={},bad=[],cl=i=>E(i).dispatchEvent(new MouseEvent("click",{bubbles:true}));
const card=async(k,want)=>{await W(400);const p=STARCHORUS.phone(),s=small();o[k]=p.card+":"+shown();if(p.card!==want)bad.push(k+" card "+p.card);if(s.length)bad.push(k+" small "+s);if(wide())bad.push(k+" wide");};
STARCHORUS.setSheet("full");await card("controls","controls");
E("sheet-body").scrollTop=200;o.pre=E("sheet-body").scrollTop;
STARCHORUS.setToggles({inventory:true});await card("inv","drawer");o.reset=o.pre+">"+E("sheet-body").scrollTop;STARCHORUS.setToggles({inventory:false});
STARCHORUS.openDrawer("air");await card("air","drawer");STARCHORUS.openDrawer("time");await card("time","drawer");
STARCHORUS.openDrawer("rec");await card("rec","drawer");cl("sheet-close");await card("closed","controls");o.height=STARCHORUS.phone().detent;
STARCHORUS.setToggles({observations:true});await card("obs","drawer");STARCHORUS.setToggles({observations:false});
cl("t-home");await card("home","drawer");o.homeTitle=E("sheet-title").textContent;cl("sheet-close");
cl("t-legend");await card("legend","legend");cl("sheet-close");
cl("t-help");await card("help","help");cl("sheet-close");await card("back","controls");
STARCHORUS.setSheet("peek");await W(300);
const aps=STARCHORUS.nodes("ap").sort((a,b)=>a.sy-b.sy),hi=aps[0],lo=aps[aps.length-1];
const tt=STARCHORUS.select(hi.id);await card("detail","detail");o.high=STARCHORUS.phone().detent+":"+(E("sheet-title").textContent===tt);
STARCHORUS.deselect();await W(300);o.after=STARCHORUS.phone().card+":"+STARCHORUS.phone().detent;
STARCHORUS.select(lo.id);await W(400);o.low=STARCHORUS.phone().detent;STARCHORUS.deselect();
const cli=STARCHORUS.nodes("client")[0];if(cli){STARCHORUS.select(cli.id);await card("client","detail");STARCHORUS.deselect();}
o.bad=bad.join(";")||"none";o.errors=STARCHORUS.errors().length;return JSON.stringify([o.bad,o.reset,o.height,o.homeTitle,o.high,o.after,o.low,o.errors,o.inv,o.legend,o.help,o.detail].join("|"))})()'
runq "$F/devices.json" "$PHN_Q" "out/$P-phn-cards" --width 390 --height 844 --mobile --wait 4 --ready "$PHN_RDY" --fps 0 --eval-timeout 60 --eval "$PHN_EVC" >/dev/null 2>&1
PHN_V=$(evalv "out/$P-phn-cards.json" 1)
PHN_W='"none|200>0|full|Homing|half:true|controls:peek|peek|0|drawer:legend|legend:legend|help:help|detail:detail"'
rowif "phone cards: one at a time (controls · six drawers · legend · help · detail), a new card opens at the top (the controls scrolled 200 px, the inventory at 0), × back to the controls at their height, a star low on the screen opens its detail collapsed, every target ≥ 44 px" [ "$PHN_V" = "$PHN_W" ]
[ "$PHN_V" = "$PHN_W" ] || { echo "    got:  ${PHN_V:-no-value}"; echo "    want: $PHN_W"; }

# ---- every load starts collapsed (C17), also with a drawer open: ?inv=1 and ?obs=1 take the way a saved drawer does (S.ui before the boot)
for PHN_Z in inv obs; do
  runq "$F/devices.json" "$PHN_Q&$PHN_Z=1" "out/$P-phn-ld-$PHN_Z" --width 390 --height 844 --mobile --wait 3 --ready "$PHN_RDY" --fps 0 --eval '(p=>[p.card,p.detent,p.h===p.peek,p.peek>0].join())(STARCHORUS.phone())' >/dev/null 2>&1
done
PHN_V="$(evalv "out/$P-phn-ld-inv.json" 1) $(evalv "out/$P-phn-ld-obs.json" 1)"
rowif "phone: a drawer open at the load (?inv=1, ?obs=1) leaves the sheet collapsed [$PHN_V]" [ "$PHN_V" = "drawer,peek,true,true drawer,peek,true,true" ]

# ---- the sheet by hand (390x844, pointer events): chevron, Esc, a drag up, a flick down, a drag that starts on 2.4, a scroll at
# half, a tap on empty sky. The drags need page coordinates, so a first run reads them (collapsed and full).
PHN_GEO='(async()=>{const p=()=>{const g=document.getElementById("sheet-grab").getBoundingClientRect();return [Math.round(g.left+g.width/2),Math.round(g.top+g.height/2)]},a=p();STARCHORUS.setSheet("full");await STARCHORUS.wait(500);const b=p(),c=document.querySelector("#sheet-lead [data-band=\"2.4\"]").getBoundingClientRect();return a.concat(b,[Math.round(c.left+c.width/2),Math.round(c.top+c.height/2)]).join(" ")})()'
runq "$F/field-probes.json" "$PHN_Q" "out/$P-phn-geo" --width 390 --height 844 --mobile --wait 4 --ready "$PHN_RDY" --fps 0 --eval "$PHN_GEO" >/dev/null 2>&1
# shellcheck disable=SC2046   # word-split the six coordinates on purpose
set -- $(evalv "out/$P-phn-geo.json" 1) 0 0 0 0 0 0
PHN_TG='(()=>{const r=document.getElementById("sheet-toggle").getBoundingClientRect();return [r.left+r.width/2,r.top+r.height/2]})()'
PHN_SKY='(()=>{for(let y=130;y<330;y+=10)for(let x=20;x<370;x+=10)if(STARCHORUS.hitTest(x,y)===null)return [x,y];return null})()'
PHN_DT='STARCHORUS.phone().detent'
runq "$F/field-probes.json" "$PHN_Q" "out/$P-phn-hand" --width 390 --height 844 --mobile --wait 4 --ready "$PHN_RDY" --fps 0 \
  --step "clickat:$PHN_TG" --step "eval:$PHN_DT" --step "clickat:$PHN_TG" --step "eval:$PHN_DT" \
  --step 'eval:STARCHORUS.setSheet("half")' --step key:Escape --step "eval:$PHN_DT" \
  --step "drag:$1,$2,$1,$(($2 - 400)),300" --step "eval:$PHN_DT" \
  --step "drag:$3,$4,$3,$(($4 + 80)),40" --step "eval:$PHN_DT" \
  --step 'eval:STARCHORUS.setSheet("full")' --step wait:0.5 \
  --step "drag:$5,$6,$5,$(($6 + 300)),300" --step 'eval:[STARCHORUS.getToggles().bands["2.4"],STARCHORUS.phone().detent].join()' \
  --step 'eval:STARCHORUS.setSheet("half")' --step wait:0.5 --step 'eval:(document.getElementById("sheet-body").scrollTop=40,1)' --step wait:0.4 --step "eval:$PHN_DT" \
  --step 'eval:STARCHORUS.setSheet("half")' --step wait:0.5 --step "clickat:$PHN_SKY" --step "eval:$PHN_DT" --step 'eval:STARCHORUS.errors().length' \
  --step 'eval:(window.__v=[],addEventListener("pointermove",()=>{if(document.documentElement.dataset.sheetDrag==="on")__v.push(getComputedStyle(document.getElementById("sheet-body")).visibility+"/"+document.documentElement.dataset.sheet)}),1)' \
  --step "drag:$1,$2,$1,$(($2 - 200)),300" --step 'eval:[...new Set(__v)].join()+":"+(__v.length>3)' >/dev/null 2>&1
PHN_V=$(evals "out/$P-phn-hand.json" | sed -n '2p;4p;6p;7p;8p;10p;13p;16p;17p;19p' | tr '\n' ' ')
PHN_W='"half" "peek" "peek" "full" "half" "true,half" "full" "peek" 0 "visible/peek:true" '
rowif "sheet by hand: chevron half/peek, Esc collapses, a drag up → full, a flick down → half, a drag from 2.4 moves the sheet and leaves the band on, a scroll at half → full, a tap on empty sky collapses, and the content shows while the sheet is dragged up from collapsed" [ "$PHN_V" = "$PHN_W" ]
[ "$PHN_V" = "$PHN_W" ] || { echo "    got:  ${PHN_V:-no-value} (geometry: $1 $2 $3 $4 $5 $6)"; echo "    want: $PHN_W"; }

# ---- Hide panels on the phone (375x812, Whitehall): bar and sheet go, banners and pill stay, the sky re-centres; a detail
# still opens in the sheet and the pill makes way; reduced motion (?rm=1): no sheet transition, no pulse in the bar or the pill
PHN_EVH='(async()=>{'"$PHN_JS"'const W=STARCHORUS.wait,o=[];document.body.dispatchEvent(new KeyboardEvent("keydown",{key:"u",bubbles:true}));await W(500);
const pill=R(E("panels-pill")),p=STARCHORUS.phone(),bar=R(E("bar")),sh=R(E("sheet"));
o.push(vis(E("bar")),vis(E("sheet")),vis(E("classbar-top"))&&vis(E("classbar-bot")),vis(E("panels-pill")),E("pill-chip").textContent===E("mode-chip").textContent,pill.height>=44,Math.abs(p.sky.cy-(bar.top+sh.bottom-52)/2)<=1,ovl().join("+")||"none");
STARCHORUS.select(STARCHORUS.nodes("ap")[0].id);await W(500);o.push(STARCHORUS.phone().card,vis(E("sheet")),vis(E("panels-pill")),ovl().join("+")||"none");STARCHORUS.deselect();await W(400);
const t=getComputedStyle(E("sheet")).transitionDuration.split(",").every(v=>v.trim()==="0s");E("pill-dot").dataset.live="live";E("mast-brand").querySelector(".dot").dataset.live="live";
o.push(t,getComputedStyle(E("pill-dot")).animationName,getComputedStyle(E("mast-brand").querySelector(".dot")).animationName);
document.body.dispatchEvent(new KeyboardEvent("keydown",{key:"u",bubbles:true}));await W(500);o.push(vis(E("bar")),vis(E("sheet")),vis(E("panels-pill")),STARCHORUS.errors().length);return o.join()})()'
runq "$F/field-probes.json" "$PHN_Q&theme=whitehall&rm=1" "out/$P-phn-hide" --width 375 --height 812 --mobile --wait 4 --ready "$PHN_RDY" --fps 0 --eval-timeout 60 --eval "$PHN_EVH" >/dev/null 2>&1
PHN_V=$(evalv "out/$P-phn-hide.json" 1)
PHN_W="false,false,true,true,true,true,true,none,detail,true,false,none,true,none,none,true,true,false,0"
rowif "phone Hide (Whitehall): bar and sheet go, banners and a 44 px pill = chip stay, sky re-centred; a detail opens in the sheet and the pill makes way; reduced motion: no transition, no pulse" [ "$PHN_V" = "$PHN_W" ]
[ "$PHN_V" = "$PHN_W" ] || { echo "    got:  ${PHN_V:-no-value}"; echo "    want: $PHN_W"; }

# ---- the bound: 720 wide is a phone, 721 is not; short is a phone only with a coarse pointer; ?phone overrides; leaving phone mode
# by a resize gives back the desktop of a fresh load (every panel home, the same boxes, the same :root)
PHN_SN='(()=>{const o={};for(const i of ["masthead","stats","source","legend","controls","chanbar","mode-chip","mast-brand","grp-bands","detail","help"]){const e=document.getElementById(i),r=e.getBoundingClientRect();o[i]=[e.parentNode.id||e.parentNode.tagName,Math.round(r.left*10),Math.round(r.top*10),Math.round(r.width*10),Math.round(r.height*10),getComputedStyle(e).display].join()}o.root=document.documentElement.style.cssText;o.phone=document.documentElement.dataset.phone;return JSON.stringify(o)})()'
PHN_PH='document.documentElement.dataset.phone'
runq "$F/field-probes.json" "$PHN_Q" "out/$P-phn-bnd" --width 720 --height 900 --wait 4 --ready "$PHN_RDY" --fps 0 \
  --step "eval:$PHN_PH" --step size:721x900 --step "eval:$PHN_PH" --step size:812x375 --step "eval:$PHN_PH" \
  --step size:375x812 --step "eval:$PHN_PH" --step size:1440x900 --step wait:1 --step "eval:$PHN_SN" >/dev/null 2>&1
runq "$F/field-probes.json" "$PHN_Q" "out/$P-phn-fresh" --width 1440 --height 900 --wait 5 --ready "$PHN_RDY" --fps 0 --eval "$PHN_SN" >/dev/null 2>&1
runq "$F/field-probes.json" "$PHN_Q" "out/$P-phn-bndm" --width 1000 --height 500 --mobile --wait 4 --ready "$PHN_RDY" --fps 0 \
  --step "eval:$PHN_PH" --step size:812x375 --step "eval:$PHN_PH" >/dev/null 2>&1
runq "$F/field-probes.json" "$PHN_Q&phone=1" "out/$P-phn-q1" --width 1440 --height 900 --wait 3 --ready "$PHN_RDY" --fps 0 --eval "$PHN_PH" >/dev/null 2>&1
runq "$F/field-probes.json" "$PHN_Q&phone=0" "out/$P-phn-q0" --width 375 --height 812 --mobile --wait 3 --ready "$PHN_RDY" --fps 0 --eval "$PHN_PH" >/dev/null 2>&1
PHN_V="$(evals "out/$P-phn-bnd.json" | head -n 4 | tr '\n' ' ')$(evals "out/$P-phn-bndm.json" | tr '\n' ' ')$(evalv "out/$P-phn-q1.json" 1) $(evalv "out/$P-phn-q0.json" 1)"
PHN_S1=$(evalv "out/$P-phn-bnd.json" 5); PHN_S2=$(evalv "out/$P-phn-fresh.json" 1)
PHN_OK=0; [ "$PHN_V" = '"on" "off" "off" "on" "off" "on" on off' ] && [ -n "$PHN_S1" ] && [ "$PHN_S1" = "$PHN_S2" ] && PHN_OK=1
rowif "phone bound: 720 on, 721 off, 812x375 off with a mouse and on with touch, 1000x500 touch off, ?phone=1/0; back to 1440x900 = a fresh desktop load [$PHN_V]" [ "$PHN_OK" = 1 ]
[ "$PHN_OK" = 1 ] || { [ "$PHN_S1" = "$PHN_S2" ] || { echo "    after resize: $(printf '%s' "$PHN_S1" | cut -c1-400)"; echo "    fresh load:   $(printf '%s' "$PHN_S2" | cut -c1-400)"; }; }

# ---- static: size, keys, theme-free phone pass
PHN_SZ=$(wc -c < "$H" | tr -d ' ')
rowif "page size $PHN_SZ bytes ≤ $PHN_MAXB" [ "$PHN_SZ" -le "$PHN_MAXB" ]
PHN_K=$(awk '/^const KEYS = \[/,/^\];/' "$H" | grep -o 'key: "[^"]*"' | sed 's/key: "\(.*\)"/\1/' | tr '\n' ' ')
PHN_KB=$(awk '/^const KEYS = \[/,/^\];/' "$H" | grep -cE 'key: "F",.*btn: "t-home"|key: "U",.*btn: "t-panels"|key: "\?",.*btn: "t-help"')
PHN_KA=$(grep -c '^  q: () => setDx("air"), .*u: () => setPanels(!S.ui.panels),$' "$H")
# 26 October 2026: "=" (after "+ / −") and "Enter" (before "Esc") joined the list, two keys the handler already had and the help did not say; the figure below is the list as it stands
rowif "keys: the old list plus U after B, X after A and Z after U (the Scope, regress.d/scope.sh), F and ? bound to #t-home and #t-help ($PHN_KB/3), KEY_ACT.u ($PHN_KA)" [ "$PHN_K/$PHN_KB/$PHN_KA" = "T V R S C Space L O K A X E N G D M P W I F Q J H Y B U Z 1 / 2 / 3 / 4 ← → ↑ ↓ + / − = 0 [ / ] Enter Esc ? /3/1" ]
PHN_TF=0; for PHN_FN in phoneLayout skyBox phDetailDetent applyPhone; do PHN_N=$(awk -v FN="$PHN_FN" '$0 ~ ("^function " FN "\\(") , /^}/' "$H" | grep -cE 'THEME|[^A-Za-z]TD\.|[^A-Za-z]TK[^A-Za-z]'); PHN_TF=$((PHN_TF + PHN_N)); done
PHN_FC=$(grep -cE '^function (phoneLayout|skyBox|phDetailDetent|applyPhone)\(' "$H")
rowif "phone pass theme-free: phoneLayout, skyBox, phDetailDetent, applyPhone ($PHN_FC functions, token reads $PHN_TF)" [ "$PHN_FC/$PHN_TF" = 4/0 ]

# ---- the masthead shows the version in small type: the text is STARCHORUS.version (the page's one version line), its font is
# at most three quarters of the brand's, and the brand still fits one line on a 375-px phone
PHN_VER=$(sed -n 's/^  version: "\([0-9][0-9A-Za-z.-]*\)",$/\1/p' "$H")
PHN_VE='(()=>{const e=document.getElementById("mast-ver"),b=document.getElementById("mast-brand"),fs=x=>parseFloat(getComputedStyle(x).fontSize);return [e.textContent===STARCHORUS.version,fs(e)<=fs(b)*0.75,b.getBoundingClientRect().height<fs(b)*2.2,e.textContent].join("|")})()'
runq "$F/field-probes.json" "$PHN_Q" "out/$P-phn-ver" --width 1440 --height 900 --wait 3 --ready "$PHN_RDY" --fps 0 --eval "$PHN_VE" >/dev/null 2>&1
runq "$F/field-probes.json" "$PHN_Q" "out/$P-phn-verp" --width 375 --height 812 --mobile --wait 3 --ready "$PHN_RDY" --fps 0 --eval "$PHN_VE" >/dev/null 2>&1
PHN_V1=$(evalv "out/$P-phn-ver.json" 1); PHN_V2=$(evalv "out/$P-phn-verp.json" 1)
rowif "masthead version: '$PHN_VER' from STARCHORUS.version, small type, brand on one line on desktop and on a 375-px phone [$PHN_V1 / $PHN_V2]" \
  [ "$PHN_V1/$PHN_V2" = "true|true|true|$PHN_VER/true|true|true|$PHN_VER" ]

# ---- 2D zoom out to half, the Camera buttons on the phone, and every label inside the sky (0.2)
# The built-in sample sky (?demo=1: nothing is polled) on a live clock: a frozen one never fades the stars in, and then no label is drawn.
PHN_DQ="?demo=1&poll=0&spin=0&intro=0"
# per theme and state: the least labelsDrawn and the sum of layoutInfo().labelsOutside (drawn boxes that leave the sky box); the states are
# [view, 2D zoom, camera]: the phone shrinks the sky to half, the desktop grows it to two and a half times, where stars at the edge carry labels that would leave.
# The last state is 3D seen from above (elevation 1, azimuth 2.4) with the camera at 0.3 of its distance (the nearest the page allows is 1.1): the stars at the rim of the
# disc sit at the edge, and labels there bite in a page copy without the margin on both screens, where the plain 3D state (kept) has none to move
PHN_LB1='(async()=>{const S=STARCHORUS,o={},st='
PHN_LB2=';for(const t of ["foundation","wargames","whitehall"])for(const [v,z,c] of st){S.setTheme(t);S.resetCamera();S.setView(v);S.setZoom2d(z);await S.wait(1300);if(c){S.setCamera({az:c.az,el:c.el,dist:Math.max(1.1,S.camera().dist*c.k)});await S.wait(300)}S.frame();const L=S.layoutInfo(),k=v+z+(c?"c":""),a=o[k]||(o[k]={min:1e9,out:0});a.min=Math.min(a.min,L.labelsDrawn);a.out+=L.labelsOutside}S.setView("2d");S.setZoom2d(1);S.resetCamera();o.errors=S.errors().length;return JSON.stringify(o)})()'
phn_lab() {   # phn_lab JSON ok|bite KEY MIN2 MIN3: "state:least-drawn/outside ..." on stdout; ok: exit 0 iff no errors, no box outside in any state, every 2D state drew >= MIN2 labels and every 3D one >= MIN3; bite: exit 0 iff every state of the comma list KEY has a box outside
  python3 -c 'import json,sys
r=json.loads(sys.argv[1]); m=sys.argv[2]; k=sys.argv[3]; lo2=int(sys.argv[4]); lo3=int(sys.argv[5])
b={x:v for x,v in r.items() if isinstance(v,dict)}
print(" ".join("%s:%d/%d" % (x,v["min"],v["out"]) for x,v in sorted(b.items())))
if m=="bite": sys.exit(0 if all(b.get(x,{}).get("out",0)>=1 for x in k.split(",")) else 1)
sys.exit(0 if len(b)==4 and r.get("errors")==0 and all(v["out"]==0 and v["min"]>=(lo3 if x.startswith("3d") else lo2) for x,v in b.items()) else 1)' "$@" 2>/dev/null
}
# the Camera group on the phone: in the sheet in both views, + - and reset in 2D, all seven in 3D
PHN_CAMJS='(async()=>{const E=i=>document.getElementById(i),q=()=>[...document.querySelectorAll("#cam button")].filter(b=>!b.hidden).map(b=>b.id.slice(4)).join("+"),o=[E("cam").hidden,q()];STARCHORUS.setView("3d");await STARCHORUS.wait(300);o.push(E("cam").hidden,q());STARCHORUS.setView("2d");await STARCHORUS.wait(300);o.push(q());return o.join()})()'
PHN_MUT="out/$P-phn-nomargin.html"
sed 's/labelMarginPx: 6/labelMarginPx: -9999/' "$H" > "$PHN_MUT"   # the margin gone: no label is moved inside any more
PHN_MN=$(grep -c 'labelMarginPx: -9999' "$PHN_MUT")
# the number the rows judge is counted over the list of drawn labels, not inside place(): a copy that draws the AP names without place() (the old occupy loop, no clamp) must show boxes outside
PHN_MUT2="out/$P-phn-noplace.html"
sed 's/const placed = place(positions, w + ext, 12);/const placed = positions.find(p => occupy(p[0], p[1], w + ext, 12));/' "$H" > "$PHN_MUT2"
PHN_MN2=$(grep -c 'const placed = positions.find(p => occupy(p\[0\], p\[1\], w + ext, 12));' "$PHN_MUT2")
PHN_STP='[["2d",1],["2d",0.5],["3d",1],["3d",1,{"az":2.4,"el":1,"k":0.3}]]'
PHN_STD='[["2d",1],["2d",2.5],["3d",1],["3d",1,{"az":2.4,"el":1,"k":0.3}]]'
runq demo "$PHN_DQ" "out/$P-phn-lab" --width 375 --height 812 --mobile --wait 4 --fps 0 --eval-timeout 90 --eval "$PHN_LB1$PHN_STP$PHN_LB2" --eval "$PHN_CAMJS" >/dev/null 2>&1
runq demo "$PHN_DQ" "out/$P-phn-labd" --width 1440 --height 900 --wait 4 --fps 0 --eval-timeout 90 --eval "$PHN_LB1$PHN_STD$PHN_LB2" >/dev/null 2>&1
PHN_HKEEP=$H; H=$PHN_MUT   # runq serves $H: point it at the copy for these two calls, then put it back
runq demo "$PHN_DQ" "out/$P-phn-labm" --width 375 --height 812 --mobile --wait 4 --fps 0 --eval-timeout 90 --eval "$PHN_LB1$PHN_STP$PHN_LB2" >/dev/null 2>&1
runq demo "$PHN_DQ" "out/$P-phn-labdm" --width 1440 --height 900 --wait 4 --fps 0 --eval-timeout 90 --eval "$PHN_LB1$PHN_STD$PHN_LB2" >/dev/null 2>&1
H=$PHN_MUT2
runq demo "$PHN_DQ" "out/$P-phn-labn" --width 375 --height 812 --mobile --wait 4 --fps 0 --eval-timeout 90 --eval "$PHN_LB1$PHN_STP$PHN_LB2" >/dev/null 2>&1
H=$PHN_HKEEP
PHN_V=$(evalv "out/$P-phn-lab.json" 1); PHN_O=$(phn_lab "$PHN_V" ok x 4 3); PHN_R=$?
rowif "phone 375x812, sample sky, 3 themes x (2D, 2D at half size, 3D, 3D from above and near): no drawn label box leaves the sky and every state draws labels [$PHN_O]" [ "$PHN_R" = 0 ]
[ "$PHN_R" = 0 ] || echo "    got: ${PHN_V:-no-value}"
PHN_V=$(evalv "out/$P-phn-labd.json" 1); PHN_O=$(phn_lab "$PHN_V" ok x 4 5); PHN_R=$?
rowif "desktop 1440x900, sample sky, 3 themes x (2D, 2D at 2.5 times the size, 3D, 3D from above and near): no drawn label box leaves the sky [$PHN_O]" [ "$PHN_R" = 0 ]
[ "$PHN_R" = 0 ] || echo "    got: ${PHN_V:-no-value}"
PHN_OP=$(phn_lab "$(evalv "out/$P-phn-labm.json" 1)" bite 2d1,3d1c 0 0); PHN_RP=$?
PHN_OD=$(phn_lab "$(evalv "out/$P-phn-labdm.json" 1)" bite 2d2.5,3d1c 0 0); PHN_RD=$?
PHN_B=0; [ "$PHN_MN" = 1 ] && [ "$PHN_RP" = 0 ] && [ "$PHN_RD" = 0 ] && PHN_B=1
rowif "label rows can bite: a page copy without the margin has boxes outside, on the phone (2D, and 3D from above and near) and on the desktop (2D at 2.5 times the size, and 3D from above and near) (mutation $PHN_MN) [$PHN_OP / $PHN_OD]" [ "$PHN_B" = 1 ]
PHN_ON=$(phn_lab "$(evalv "out/$P-phn-labn.json" 1)" bite 2d1 0 0); PHN_RN=$?
rowif "label rows count by themselves: a page copy that draws the AP names without place() has boxes outside on the phone (2D) (mutation $PHN_MN2) [$PHN_ON]" [ "$PHN_MN2/$PHN_RN" = 1/0 ]
PHN_V=$(evalv "out/$P-phn-lab.json" 2)
rowif "phone: the Camera group is in the sheet in 2D with + - reset only, all seven in 3D [$PHN_V]" [ "$PHN_V" = "false,in+out+reset,false,left+right+up+down+in+out+reset,in+out+reset" ]

# 2D zoom out on the desktop (field-scale: 120 APs, 44 bubbles): the zoom stops at 0.5 and 4, the buttons and keys step it (x1.25, 0 and reset give
# 1), the stars sit at half their distance, the -60 dBm ring is drawn at half its radius and no longer at the old one (pixels of #bg), every bubble keeps
# its counter, and the names the stars had at 1 they keep at 0.5
PHN_EVZ='(async()=>{const S=STARCHORUS,E=i=>document.getElementById(i),W=S.wait,z=()=>S.camera().zoom2d,key=k=>document.body.dispatchEvent(new KeyboardEvent("keydown",{key:k,bubbles:true})),
cnt=()=>{const ids=new Set(S.bubbles().map(b=>b.id));return S.labels().filter(l=>l.kind==="counter"&&ids.has(l.id)).length},
bg=E("bg").getContext("2d"),kk=E("bg").width/innerWidth,mr=S.phone().sky.r,inn=Math.min(96,Math.max(64,0.22*mr)),R=(d,f)=>f*(inn+(1-(d+90)/60)*(mr-inn)),
ring=r=>{let h=0;for(let a=0;a<36;a++){const t=a*Math.PI/18+0.13;let m=0;for(let d=-1.5;d<=1.5;d+=0.5)m=Math.max(m,bg.getImageData(Math.round((innerWidth/2+Math.cos(t)*(r+d))*kk),Math.round((innerHeight/2+Math.sin(t)*(r+d))*kk),1,1).data[3]);if(m>30)h++}return h/36},o={};
await W(2500);S.frame();
const ids=S.nodes("ap").filter(n=>n.visible).slice(0,3).map(n=>n.id),dist=()=>ids.map(i=>{const n=S.node(i);return Math.hypot(n.sx-innerWidth/2,n.sy-innerHeight/2)}),d1=dist(),k1=S.labelCandidates().length,r1=ring(R(-60,1));
S.setZoom2d(0.3);o.clamp=[z()];S.setZoom2d(9);o.clamp.push(z());
S.setZoom2d(1);const st=[];for(let i=0;i<5;i++){E("cam-out").click();st.push(z())}E("cam-in").click();st.push(z());E("cam-reset").click();st.push(z());key("-");st.push(z());key("0");st.push(z());o.steps=st.join();
S.setZoom2d(0.5);await W(700);S.frame();const d5=dist();
o.scale=d5.length===3&&d5.every((d,i)=>Math.abs(d/d1[i]-0.5)<0.002);
o.rings=[r1>=0.9,ring(R(-60,0.5))>=0.9,ring(R(-60,1))<=0.3];
o.counters=cnt()===S.bubbles().length&&cnt()>0;o.labels=[S.labelCandidates().length===k1,S.layoutInfo().labelsDrawn>=5];
S.setZoom2d(1);o.errors=S.errors().length;return JSON.stringify(o)})()'
runq "$F/field-scale.json" "?poll=0&spin=0&intro=0&theme=foundation" "out/$P-phn-zoom" --width 1440 --height 900 --wait 4 --ready "$PHN_RDY" --fps 0 --eval-timeout 90 --eval "$PHN_EVZ" >/dev/null 2>&1
PHN_V=$(evalv "out/$P-phn-zoom.json" 1)
PHN_W='{"clamp":[0.5,4],"steps":"0.8,0.64,0.512,0.5,0.5,0.625,1,0.8,1","scale":true,"rings":[true,true,true],"counters":true,"labels":[true,true],"errors":0}'
rowif "2D zoom out (1440x900, 1200 stations): clamped to 0.5 and 4, buttons and keys step it by 1.25 and reset to 1, stars at half their distance, the -60 dBm ring at half its radius and gone from the old one, every bubble counter and the same star names" [ "$PHN_V" = "$PHN_W" ]
[ "$PHN_V" = "$PHN_W" ] || { echo "    got:  ${PHN_V:-no-value}"; echo "    want: $PHN_W"; }

# ---- 0.2, the radio pair: the fourth band button (BT) in the sheet's Layers row, on tests/fixtures/radio-pair.json. At 375x812 all four are in the bar, 44 px or more,
# clear of one another and of the screen edges, with no sideways scroll, in the three themes. Four layer buttons, Legend and the chevron need 338 px: below 375 px
# the sheet row wraps (the chevron, at 320 px also Legend, on a second line), so the layer can be switched off on a 360 px and a 320 px phone too
PHN_EVR='(async()=>{const sleep=STARCHORUS.wait,o={};await sleep(1800);const R=(e)=>e.getBoundingClientRect(),vis=(e)=>e.offsetParent!==null||getComputedStyle(e).position==="fixed";
const res=[];
for(const t of ["foundation","wargames","whitehall"]){STARCHORUS.setTheme(t);await sleep(500);STARCHORUS.frame();
 const b=[...document.querySelectorAll("#grp-bands .btn")],lead=[...document.querySelectorAll("#sheet-row .btn")].filter(vis),all=b.concat(lead.filter(x=>!b.includes(x)));
 const r=all.filter(vis).map(e=>R(e)),ov=r.some((x,i)=>r.some((y,j)=>j>i&&x.left<y.right-0.5&&y.left<x.right-0.5&&x.top<y.bottom-0.5&&y.top<x.bottom-0.5)),inside=r.every(x=>x.left>=-0.5&&x.right<=innerWidth+0.5);
 res.push([t,b.length,b.filter(e=>vis(e)).length,Math.min(...r.map(x=>Math.round(Math.min(x.width,x.height)))),ov,inside,document.documentElement.scrollWidth===innerWidth,document.querySelector("[data-band=bt]").getBoundingClientRect().width>0].join("/"));}
o.res=res;o.phone=STARCHORUS.phone().on;o.errors=STARCHORUS.errors().length;return JSON.stringify(o);})()'
runq "$F/radio-pair.json" "?poll=0&spin=0&intro=0&debug=1" "out/$P-phn-radio" --width 375 --height 812 --mobile --wait 4 --ready "$PHN_RDY" --fps 0 --eval-timeout 60 --eval "$PHN_EVR" >/dev/null 2>&1
runq "$F/radio-pair.json" "?poll=0&spin=0&intro=0&debug=1" "out/$P-phn-radio320" --width 320 --height 568 --mobile --wait 4 --ready "$PHN_RDY" --fps 0 --eval-timeout 60 --eval "$PHN_EVR" >/dev/null 2>&1
runq "$F/radio-pair.json" "?poll=0&spin=0&intro=0&debug=1" "out/$P-phn-radio360" --width 360 --height 800 --mobile --wait 4 --ready "$PHN_RDY" --fps 0 --eval-timeout 60 --eval "$PHN_EVR" >/dev/null 2>&1
PHN_V=$(evalv "out/$P-phn-radio.json" 1); PHN_V3=$(evalv "out/$P-phn-radio320.json" 1); PHN_V6=$(evalv "out/$P-phn-radio360.json" 1)
PHN_W='{"res":["foundation/4/4/44/false/true/true/true","wargames/4/4/44/false/true/true/true","whitehall/4/4/44/false/true/true/true"],"phone":true,"errors":0}'
PHN_W3=$PHN_W
rowif "phone 375x812 (radio pair, 3 themes): four band buttons in the bar, 44 px or more, no overlap, inside the screen, no sideways scroll" [ "$PHN_V" = "$PHN_W" ]
[ "$PHN_V" = "$PHN_W" ] || { echo "    got:  ${PHN_V:-no-value}"; echo "    want: $PHN_W"; }
rowif "phone 320x568 (radio pair, 3 themes): the sheet row wraps, all four band buttons stay (BT included), Legend and the chevron stay, 44 px or more, no overlap, inside the screen, no sideways scroll" [ "$PHN_V3" = "$PHN_W3" ]
[ "$PHN_V3" = "$PHN_W3" ] || { echo "    got:  ${PHN_V3:-no-value}"; echo "    want: $PHN_W3"; }
rowif "phone 360x800 (radio pair, 3 themes): the same: four band buttons, Legend and the chevron, 44 px or more, no overlap, inside the screen, no sideways scroll" [ "$PHN_V6" = "$PHN_W" ]
[ "$PHN_V6" = "$PHN_W" ] || { echo "    got:  ${PHN_V6:-no-value}"; echo "    want: $PHN_W"; }
