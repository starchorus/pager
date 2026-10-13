# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/theme-schema.sh -- the symmetric theme schema and the theme-free geometry (core radius,
# depth fog and far size, one shared label-candidate model). Sourced by tools/regress.sh with cwd = repo
# root, after the core rows. Only TSC_*/TSR_* globals are set.
#
# One demo run with ?debug=1 carries the boot audit (EVA), a second flatten of the RUNTIME THEMES as
# a cross-check of auditThemes() (EVB), a synthetic both-ways mutation probe and the token-location
# check. EVB is NOT a source-level check: the boot crash-guard fill (starchorus.html ~840) repairs
# THEMES whenever the audit reported errors, i.e. exactly when there would be an asymmetry to see, so
# this row's source-level evidence is the boot audit EVA, taken before the fill. Three cross-theme
# runs compare STARCHORUS.labelCandidates(), a hitTest grid, the node hit/edge probes and the drawn star sizes
# in all three themes, and check that the drawn labels are an ordered subsequence of the candidates.
# Cross-theme runs use ?poll=0&spin=0 and freeze the clock INSIDE the eval after the fade-in; they never
# use ?fixed from boot (under ?fixed nothing fades in, so every comparison would pass vacuously).
# The token count itself is not frozen here: tokens may be added; it only has to stay equal in
# all three themes (STARCHORUS.themeAudit().errors === 0).

# ---- schema and geometry on one demo run (?debug=1 exposes STARCHORUS._internals)
TSC_EVA="(function(){const a=STARCHORUS.themeAudit();const k=a.keyCount;return a.errors===0&&a.ids.join()==='foundation,wargames,whitehall'&&a.union>0&&k.foundation===a.union&&k.wargames===a.union&&k.whitehall===a.union})()"
TSC_EVB="(function(){const T=STARCHORUS._internals.THEMES,f=(o,p,a)=>{for(const k of Object.keys(o)){const v=o[k],q=p?p+'.'+k:k;if(v&&typeof v==='object'&&!Array.isArray(v))f(v,q,a);else a.push(q)}return a};const s=['foundation','wargames','whitehall'].map(id=>f(T[id],'',[]).sort().join('|'));return s[0]===s[1]&&s[1]===s[2]&&s[0].length>0})()"
TSC_EVC="(function(){const T=STARCHORUS._internals.THEMES;T.foundation.k04={a:1,b:[1,2]};T.wargames.k04={a:1,b:3};T.whitehall.k04={c:1};const m=STARCHORUS.themeAudit(true);delete T.foundation.k04;delete T.wargames.k04;delete T.whitehall.k04;return JSON.stringify({f:m.missing.foundation,w:m.missing.wargames,h:m.missing.whitehall,k:m.kinds,e:m.errors})+'|'+STARCHORUS.themeAudit(true).errors})()"
TSC_WANT='{"f":["k04.c"],"w":["k04.c"],"h":["k04.a","k04.b"],"k":["k04.b array/number/-"],"e":5}|0'
TSR_EVS="(function(){const I=STARCHORUS._internals;return ['foundation','wargames','whitehall'].every(id=>{const t=I.THEMES[id];return !('coreRadiusPx' in t.rssi)&&!('fogNearAlpha' in t.depth)&&!('fogFarAlpha' in t.depth)&&!('sizeFarFactor' in t.depth)})&&Array.isArray(I.LAYOUT.coreRadiusPx)&&I.LAYOUT.coreRadiusPx[1]===I.LAYOUT.basePxMaxCore&&I.CFG3D.fogFarAlpha===0.33&&I.CFG3D.sizeFarFactor===0.58})()"
runq demo "?intro=0&poll=0&debug=1" "out/$P-tsc" --fps 0 \
  --eval "$TSC_EVA" --eval "$TSC_EVB" --eval "$TSC_EVC" --eval "$TSR_EVS" --eval "JSON.stringify(STARCHORUS.themeAudit())" >/dev/null 2>&1
TSC_A=$(evalv "out/$P-tsc.json" 1); TSC_B=$(evalv "out/$P-tsc.json" 2); TSC_C=$(evalv "out/$P-tsc.json" 3)
TSR_S=$(evalv "out/$P-tsc.json" 4); TSC_AUDIT=$(evalv "out/$P-tsc.json" 5)
TSC_N=$(printf '%s' "$TSC_AUDIT" | sed -n 's/.*"union":\([0-9]*\).*/\1/p')
if [ "$TSC_A" = true ] && [ "$TSC_B" = true ] && [ "$TSC_C" = "$TSC_WANT" ]; then
  row "theme schema: theme keys symmetric (${TSC_N:-?} in all 3)" PASS
else
  row "theme schema: theme keys symmetric (audit/flatten/probe)" FAIL
  echo "    audit=$TSC_A flatten=$TSC_B probe=$TSC_C"
fi
rowif "theme-free geometry: core/fog/size only in LAYOUT/CFG3D" [ "$TSR_S" = true ]

# ---- static: no theme-scaled core radius, fog or far size anywhere; validation once at boot
TSR_G=$(grep -c 'THEME\.rssi\.coreRadiusPx\|S\.anim\.fog\|S\.anim\.sizeFar\|d\.fogNearAlpha\|d\.sizeFarFactor' "$H")
if [ "$TSR_G" = 0 ]; then
  row "theme-free geometry: no theme-scaled core/fog/size reads" PASS
else
  row "theme-free geometry: theme-scaled core/fog/size reads = $TSR_G" FAIL
  grep -n 'THEME\.rssi\.coreRadiusPx\|S\.anim\.fog\|S\.anim\.sizeFar\|d\.fogNearAlpha\|d\.sizeFarFactor' "$H" | cut -c1-140 | sed 's/^/    /'
fi
TSC_PER=$(grep -c 'validateTheme(THEME)\|const ref = THEMES\.foundation' "$H")
TSC_BOOT=$(grep -c '^  validateThemes();' "$H")
rowif "theme schema: validateThemes() once at boot ($TSC_BOOT/1, per-theme validate paths $TSC_PER/0)" [ "$TSC_PER/$TSC_BOOT" = 0/1 ]

# ---- cross-theme: label candidates, hit test, star size (and drawn labels ⊆ candidates)
TSR_EV7="(async()=>{STARCHORUS.setFixedTime(0);const o=[],n=[];for(const t of['foundation','wargames','whitehall']){STARCHORUS.setTheme(t);await STARCHORUS.wait(300);STARCHORUS.settle();STARCHORUS.frame();const c=STARCHORUS.labelCandidates(),h=[];for(let y=6;y<innerHeight;y+=12)for(let x=6;x<innerWidth;x+=12)h.push(STARCHORUS.hitTest(x,y));const a=STARCHORUS.nodes().map(q=>STARCHORUS.hitTest(q.sx,q.sy)+'|'+STARCHORUS.hitTest(q.sx+q.px+6.5,q.sy));o.push(JSON.stringify([c,STARCHORUS.nodes().map(q=>q.px),h,a]));n.push(c.length)}STARCHORUS.setTheme('foundation');return (o[0]===o[1]&&o[1]===o[2]?'EQ:':'DIFF:')+n.join('/')})()"
TSR_EVH="(()=>{const a=STARCHORUS.nodes('ap').filter(q=>q.visible);return a.length>3?STARCHORUS.hoverNode(a[3].id):null})()"
TSR_EVU="(()=>{const r=[];for(const t of['foundation','wargames','whitehall']){STARCHORUS.setTheme(t);STARCHORUS.frame();const c=STARCHORUS.labelCandidates(),l=STARCHORUS.labels().filter(x=>x.kind==='label'&&x.id!=='__center__').map(x=>x.id);let i=0,ok=l.length>0;for(const id of l){const j=c.indexOf(id,i);if(j<0){ok=false;break}i=j+1}r.push(ok+':'+l.length+'/'+c.length)}STARCHORUS.setTheme('foundation');return r.join(' ')})()"
TSR_EVT="(async()=>{STARCHORUS.setFixedTime(0);await STARCHORUS.wait(100);const f=()=>JSON.stringify(STARCHORUS.nodes('assoc').map(n=>[n.sx,n.sy]));STARCHORUS.settle();const b=f();await STARCHORUS.wait(300);STARCHORUS.frame();const c=f();return (b===c)+':'+STARCHORUS.nodes('assoc').length})()"
for TSR_SPEC in many-clients:2d:settle field-probes:2d:settle many-clients:3d:-; do
  TSR_FX=${TSR_SPEC%%:*}; TSR_REST=${TSR_SPEC#*:}; TSR_VW=${TSR_REST%%:*}; TSR_FL=${TSR_REST##*:}
  TSR_OUT="out/$P-tsr-$TSR_FX-$TSR_VW"
  if [ "$TSR_FL" = settle ]; then
    runq "$F/$TSR_FX.json" "?view=$TSR_VW&intro=0&poll=0&spin=0" "$TSR_OUT" --fps 0 \
      --eval "$TSR_EV7" --eval "$TSR_EVH" --eval "$TSR_EVU" --eval "$TSR_EVT" >/dev/null 2>&1
  else
    runq "$F/$TSR_FX.json" "?view=$TSR_VW&intro=0&poll=0&spin=0" "$TSR_OUT" --fps 0 \
      --eval "$TSR_EV7" --eval "$TSR_EVH" --eval "$TSR_EVU" >/dev/null 2>&1
  fi
  TSR_V=$(evalv "$TSR_OUT.json" 1); TSR_U=$(evalv "$TSR_OUT.json" 3)
  case $TSR_V in
    EQ:0/*|EQ:*/0|"") row "theme-free geometry: candidates+hitTest $TSR_FX $TSR_VW (${TSR_V:-no-value})" FAIL ;;
    EQ:*) row "theme-free geometry: candidates+hitTest $TSR_FX $TSR_VW ($TSR_V)" PASS ;;
    *) row "theme-free geometry: candidates+hitTest $TSR_FX $TSR_VW ($TSR_V)" FAIL ;;
  esac
  case $TSR_U in
    true:*" "true:*" "true:*) row "theme-free geometry: labels ⊆ candidates $TSR_FX $TSR_VW" PASS ;;
    *) row "theme-free geometry: labels ⊆ candidates $TSR_FX $TSR_VW" FAIL; echo "    $TSR_U" ;;
  esac
  if [ "$TSR_FL" = settle ]; then
    TSR_T=$(evalv "$TSR_OUT.json" 4)
    case $TSR_T in
      true:0|"") row "theme-free geometry: settle() snaps assoc $TSR_FX (${TSR_T:-no-value})" FAIL ;;
      true:*) row "theme-free geometry: settle() snaps assoc $TSR_FX ($TSR_T)" PASS ;;
      *) row "theme-free geometry: settle() snaps assoc $TSR_FX ($TSR_T)" FAIL ;;
    esac
  fi
done
