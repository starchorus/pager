# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/hook-behavior.sh -- the pre-commit hook has to STOP a violation, not just exist.
# GUARDS AGAINST: a hook that never starts tools/quick.sh (call replaced by `true`, `echo`, a trailing comment, a wrong path) lets
#                 every commit through, and the text row in static.sh ("runs sh tools/quick.sh") cannot tell.
# NEGATIVE PROBE: the call in a copy of .githooks/pre-commit replaced by `true` => the row is
#                 red ("violation rc 0"); likewise only the word quick.sh -> qk.sh. Without the change: green.
# SRC-ONLY PROBE: a fragment under src/ staged alone, the page not rebuilt, has to START the hook (the path filter names src/) and turn it red
#                 on the row "page = build of src/", HEAD kept; the same fragment with the page rebuilt (tools/build-page.sh) is green.
#                 Negative control: the filter without src/ lets the first commit through (rc 0), and the row is red.
# NOT PROVEN:     does not prove the index-versus-working-tree contract or the rest of the path filter (for those, the hand probes in the
#                 commit message), nothing under BusyBox, no git version other than the local one.
# Sourced by tools/regress.sh with cwd = repo root; chrome-free, five hook runs (one of them ends at the preflight). Only HKB_*, HKM_* and HKS_*
# names are set. Only the PAGE gets the appended text (never executed: quick.sh only greps it), no collector or display script is touched;
# the src-only probe takes the empty last line off one fragment and rebuilds the page in the copy, which gets smaller by that one byte.
HKB_t=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-hookb.XXXXXX") || HKB_t=
HKB_msg=""; HKB_ok=0; HKB_rc1=-; HKB_rc2=-; HKB_named=0; HKB_kept=0
HKM_ok=0; HKM_rc=-; HKM_named=0; HKM_kept=0   # the hook with a tool missing (jq) from PATH
HKS_msg=""; HKS_ok=0; HKS_rc1=-; HKS_rc2=-; HKS_named=0; HKS_kept=0   # a src-only commit, the page stale and then rebuilt
HKS_f=src/js/41-boot.js
HKB_bait='fetch("/x",{method:"POST"});'
HKB_git() { env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$HKB_t/w" -c user.name=probe -c user.email=probe@example.invalid "$@"; }
if [ -z "$HKB_t" ] || ! command -v git > /dev/null 2>&1; then
  HKB_msg="no mktemp or no git"
else
  mkdir "$HKB_t/w"
  # the tree without out/ and .git (the run may itself sit in a clone or a `git archive` copy: no git needed to copy)
  tar -cf - --exclude='./out' --exclude='./.git' . | tar -xf - -C "$HKB_t/w"
  if [ ! -f "$HKB_t/w/tools/quick.sh" ] || [ ! -f "$HKB_t/w/.githooks/pre-commit" ]; then
    HKB_msg="copy of the tree lacks tools/quick.sh or the hook"
  elif [ "$(grep -c -F "$HKB_bait" "$HKB_t/w/starchorus.html")" != 0 ]; then
    HKB_msg="fairness: the page already contains the bait line"
  else
    HKB_git init -q . && HKB_git add -A && HKB_git commit -q --no-verify -m base
    (cd "$HKB_t/w" && env GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 sh tools/install-hooks.sh > /dev/null 2>&1) \
      || HKB_msg="install-hooks.sh failed in the copy"
    if [ -z "$HKB_msg" ]; then
      # 1. control: a neutral staged change under tools/ must pass the hook (a hook that refuses everything proves nothing)
      echo "<!-- hook probe -->" >> "$HKB_t/w/tools/README.md"
      HKB_git add tools/README.md
      HKB_git commit -q -m clean > "$HKB_t/c1.txt" 2>&1; HKB_rc1=$?
      # 2. the violation: the bait line appended to the page and staged
      HKB_head=$(HKB_git rev-parse HEAD)
      printf '%s\n' "$HKB_bait" >> "$HKB_t/w/starchorus.html"
      HKB_git add starchorus.html
      HKB_git commit -q -m dirty > "$HKB_t/c2.txt" 2>&1; HKB_rc2=$?
      grep -q 'HTML network surface' "$HKB_t/c2.txt" && HKB_named=1
      [ "$(HKB_git rev-parse HEAD)" = "$HKB_head" ] && HKB_kept=1
      [ "$HKB_rc1" = 0 ] && [ "$HKB_rc2" = 1 ] && [ "$HKB_named" = 1 ] && [ "$HKB_kept" = 1 ] && HKB_ok=1
      # 3. a setup problem is not a finding: staged neutral change, jq missing from PATH => quick.sh exits 2, the hook refuses
      #    the commit, says "could not run" and names the tool (a hook that let this through would check nothing; one that said
      #    "red" would send the committer looking for a violation)
      HKB_git reset -q --hard HEAD
      mkdir "$HKB_t/nojq"; path_farm "$HKB_t/nojq" jq
      echo "<!-- hook probe 3 -->" >> "$HKB_t/w/tools/README.md"
      HKB_git add tools/README.md
      HKM_head=$(HKB_git rev-parse HEAD)
      # shellcheck disable=SC2123   # deliberate: this probe IS a PATH without jq (in a subshell, so nothing leaks)
      ( PATH="$HKB_t/nojq"; export PATH; HKB_git commit -q -m nojq ) > "$HKB_t/c3.txt" 2>&1; HKM_rc=$?
      grep -q 'MISSING: jq' "$HKB_t/c3.txt" && grep -q 'could not run' "$HKB_t/c3.txt" && HKM_named=1
      [ "$(HKB_git rev-parse HEAD)" = "$HKM_head" ] && HKM_kept=1
      [ "$HKM_rc" = 1 ] && [ "$HKM_named" = 1 ] && [ "$HKM_kept" = 1 ] && HKM_ok=1
      # 4. a commit that stages only a fragment under src/: the page is stale (it is not the build of the fragments any more), so T1 has to
      #    run (the filter names src/) and go red on "page = build of src/"; 5. the same fragment and the rebuilt page in one commit: green
      #    (the hook checks, it never rebuilds). The fragment loses its empty last line, so the page does not grow past a ceiling.
      HKB_git reset -q --hard HEAD
      if [ -n "$(tail -n 1 "$HKB_t/w/$HKS_f" 2> /dev/null | tr -d ' ')" ]; then
        HKS_msg="fairness: $HKS_f does not end in an empty line"
      else
        sed '$d' "$HKB_t/w/$HKS_f" > "$HKB_t/f.new" && cp "$HKB_t/f.new" "$HKB_t/w/$HKS_f"
        HKB_git add "$HKS_f"
        HKS_head=$(HKB_git rev-parse HEAD)
        HKB_git commit -q -m srconly > "$HKB_t/c4.txt" 2>&1; HKS_rc1=$?
        grep -q 'page = build of src' "$HKB_t/c4.txt" && HKS_named=1
        [ "$(HKB_git rev-parse HEAD)" = "$HKS_head" ] && HKS_kept=1
        (cd "$HKB_t/w" && sh tools/build-page.sh > /dev/null 2>&1) || HKS_msg="build-page.sh failed in the copy"
        HKB_git add starchorus.html
        HKB_git commit -q -m srcrebuilt > "$HKB_t/c5.txt" 2>&1; HKS_rc2=$?
        [ "$HKS_rc1" = 1 ] && [ "$HKS_named" = 1 ] && [ "$HKS_kept" = 1 ] && [ "$HKS_rc2" = 0 ] && [ -z "$HKS_msg" ] && HKS_ok=1
      fi
    fi
  fi
fi
rowif "pre-commit hook: clean commit rc $HKB_rc1 (want 0), staged POST rc $HKB_rc2 (want 1), red row named $HKB_named, HEAD kept $HKB_kept${HKB_msg:+ ($HKB_msg)}" [ "$HKB_ok" = 1 ]
if [ "$HKB_ok" != 1 ] && [ -n "$HKB_t" ]; then
  for HKB_f in c1 c2; do [ -f "$HKB_t/$HKB_f.txt" ] && { echo "    -- $HKB_f:"; tail -n 8 "$HKB_t/$HKB_f.txt" | cut -c1-200 | sed 's/^/    /'; }; done
fi
rowif "pre-commit hook without jq on PATH: commit rc $HKM_rc (want 1), 'MISSING: jq' and 'could not run' named $HKM_named, HEAD kept $HKM_kept" [ "$HKM_ok" = 1 ]
if [ "$HKM_ok" != 1 ] && [ -n "$HKB_t" ] && [ -f "$HKB_t/c3.txt" ]; then echo "    -- c3:"; tail -n 8 "$HKB_t/c3.txt" | cut -c1-200 | sed 's/^/    /'; fi
rowif "pre-commit hook, only $HKS_f staged: page stale rc $HKS_rc1 (want 1), 'page = build of src' named $HKS_named, HEAD kept $HKS_kept; page rebuilt rc $HKS_rc2 (want 0)${HKS_msg:+ ($HKS_msg)}" [ "$HKS_ok" = 1 ]
if [ "$HKS_ok" != 1 ] && [ -n "$HKB_t" ]; then
  for HKS_x in c4 c5; do [ -f "$HKB_t/$HKS_x.txt" ] && { echo "    -- $HKS_x:"; tail -n 8 "$HKB_t/$HKS_x.txt" | cut -c1-200 | sed 's/^/    /'; }; done
fi
[ -z "$HKB_t" ] || rm -rf "$HKB_t"
