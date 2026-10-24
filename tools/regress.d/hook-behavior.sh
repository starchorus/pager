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
# DOCUMENTS PROBE: a commit that stages only a document (CONTRIBUTING.md, README.md, docs/) has to START the documents mode (`quick.sh docs`)
#                 and not T1: clean => rc 0 and the summary line "quick docs: ..."; a hand-typed check count in README.md (doc-truth) and a
#                 hotkey of the spec's section 9.6 renamed in docs/architecture.md (doc-binding) => rc 1, the red row named, HEAD kept.
#                 Negative control: the document filter switched off in a copy of the hook lets the first of them through (rc 0). A
#                 commit of code and a document runs T1 first and then the documents mode (T1 green, documents red => rc 1, both named);
#                 tools/README.md alone (its fixture table made untrue; doc-truth binds it) is a document for the hook as well as code: T1 green,
#                 then the documents mode red => rc 1, HEAD kept (it used to land, and the break showed one commit later).
#                 a code-only commit prints T1's summary and never the documents mode's. Needs Chrome (doc-binding), like the mode itself.
# NOT PROVEN:     does not prove the index-versus-working-tree contract or the rest of the path filter (for those, the hand probes in the
#                 commit message), nothing under BusyBox, no git version other than the local one.
# Sourced by tools/regress.sh with cwd = repo root; eleven hook runs (one of them ends at the preflight; five of them run the documents mode, about 15 s
# each, which needs Chrome; two of those are T1 and the documents mode in turn). Only HKB_*, HKM_*, HKS_*, HKD_*, HKT_* and HKX_* names are set.
# The neutral change of the code probes is one comment line appended to tools/install-hooks.sh in the copy (never tools/README.md: the hook counts
# that as a document); the page gets the appended bait text (never executed: quick.sh only greps it); no collector or display script is touched;
# the src-only probe takes the empty last line off one fragment and rebuilds the page in the copy, which gets smaller by that one byte.
# shellcheck disable=SC2016   # the probe texts are literal Markdown (backticks), not expansions
HKB_t=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-hookb.XXXXXX") || HKB_t=
HKB_msg=""; HKB_ok=0; HKB_rc1=-; HKB_rc2=-; HKB_named=0; HKB_kept=0
HKM_ok=0; HKM_rc=-; HKM_named=0; HKM_kept=0   # the hook with a tool missing (jq) from PATH
HKS_msg=""; HKS_ok=0; HKS_rc1=-; HKS_rc2=-; HKS_named=0; HKS_kept=0   # a src-only commit, the page stale and then rebuilt
HKD_ok=0; HKD_clean=-; HKD_t1off=0; HKD_moved=0; HKD_rc1=-; HKD_rc2=-; HKD_n1=0; HKD_n2=0; HKD_k1=0; HKD_k2=0; HKD_ctl=-   # documents only
HKX_ok=0; HKX_rc=-; HKX_t1=0; HKX_dn=0; HKX_kept=0; HKX_c1only=0                                                           # code plus a document
HKT_ok=0; HKT_rc=-; HKT_t1=0; HKT_dn=0; HKT_kept=0                                                                         # tools/README.md alone
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
      # 1. control: a neutral staged change under tools/ (a comment line in a script; NOT tools/README.md, which is a document for the hook) must pass the hook (a hook that refuses everything proves nothing)
      echo "# hook probe" >> "$HKB_t/w/tools/install-hooks.sh"
      HKB_git add tools/install-hooks.sh
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
      echo "# hook probe 3" >> "$HKB_t/w/tools/install-hooks.sh"
      HKB_git add tools/install-hooks.sh
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
      # 6. documents only, clean: the documents mode runs (summary "quick docs:"), T1 does not ("quick:" without "docs"), the commit lands.
      #    A code-only commit (probe 1) printed T1's summary and no "quick docs:" line: that is the third half of the same row.
      grep -q '^pre-commit: quick: [0-9]* PASS' "$HKB_t/c1.txt" && ! grep -q 'quick docs:' "$HKB_t/c1.txt" && HKX_c1only=1
      HKB_git reset -q --hard HEAD
      echo "<!-- hook probe docs -->" >> "$HKB_t/w/CONTRIBUTING.md"
      HKB_git add CONTRIBUTING.md
      HKD_head=$(HKB_git rev-parse HEAD)
      HKB_git commit -q -m docsclean > "$HKB_t/c6.txt" 2>&1; HKD_clean=$?
      grep -q '^pre-commit: quick docs: [0-9]* PASS, 0 FAIL' "$HKB_t/c6.txt" && HKD_n1=1
      ! grep -q '^pre-commit: quick: ' "$HKB_t/c6.txt" && HKD_t1off=1
      [ "$(HKB_git rev-parse HEAD)" != "$HKD_head" ] && HKD_moved=1
      # 7. documents only, doc-truth: a hand-typed check count in README.md; 8. doc-binding: the hotkey Q of the spec's 9.6 renamed
      HKD_head=$(HKB_git rev-parse HEAD)
      printf '%s\n' '- `--selftest` green (42 checks) under BusyBox' >> "$HKB_t/w/README.md"
      HKB_git add README.md
      HKB_git commit -q -m docstruth > "$HKB_t/c7.txt" 2>&1; HKD_rc1=$?
      grep -q 'hand-typed check count' "$HKB_t/c7.txt" && grep -q 'documents mode' "$HKB_t/c7.txt" && ! grep -q '^pre-commit: quick: ' "$HKB_t/c7.txt" && HKD_n2=1
      [ "$(HKB_git rev-parse HEAD)" = "$HKD_head" ] && HKD_k1=1
      # control: the document filter switched off in the hook => the same broken commit goes through (the blind spot of old)
      sed 's/&& need_docs=1$/\&\& need_docs=0/' "$HKB_t/w/.githooks/pre-commit" > "$HKB_t/hook.off"
      if ! cmp -s "$HKB_t/hook.off" "$HKB_t/w/.githooks/pre-commit"; then
        cp "$HKB_t/hook.off" "$HKB_t/w/.githooks/pre-commit"; chmod +x "$HKB_t/w/.githooks/pre-commit"
        HKB_git commit -q -m docsctl > "$HKB_t/c7c.txt" 2>&1; HKD_ctl=$?
      else HKD_ctl=nochange; fi
      HKB_git reset -q --hard "$HKD_head"
      sed 's/`Q`/`QQ`/g' "$HKB_t/w/docs/architecture.md" > "$HKB_t/arch.new" && cp "$HKB_t/arch.new" "$HKB_t/w/docs/architecture.md"
      HKB_git add docs/architecture.md
      HKB_git commit -q -m docsbind > "$HKB_t/c8.txt" 2>&1; HKD_rc2=$?
      grep -q 'every hotkey' "$HKB_t/c8.txt" && grep -q 'missing: Q' "$HKB_t/c8.txt" && grep -q 'documents mode' "$HKB_t/c8.txt" \
        && ! grep -q '^pre-commit: quick: ' "$HKB_t/c8.txt" && HKD_k2=1
      [ "$(HKB_git rev-parse HEAD)" = "$HKD_head" ] || HKD_k2=0
      [ "$HKD_clean" = 0 ] && [ "$HKD_n1" = 1 ] && [ "$HKD_t1off" = 1 ] && [ "$HKD_moved" = 1 ] && [ "$HKD_rc1" = 1 ] && [ "$HKD_n2" = 1 ] \
        && [ "$HKD_k1" = 1 ] && [ "$HKD_ctl" = 0 ] && [ "$HKD_rc2" = 1 ] && [ "$HKD_k2" = 1 ] && [ "$HKX_c1only" = 1 ] && HKD_ok=1
      # 9. code and a document in one commit: T1 first (green: a neutral line under tools/), then the documents mode (red: the check count)
      HKB_git reset -q --hard HEAD
      echo "# hook probe mixed" >> "$HKB_t/w/tools/install-hooks.sh"
      printf '%s\n' '- `--selftest` green (42 checks) under BusyBox' >> "$HKB_t/w/README.md"
      HKB_git add tools/install-hooks.sh README.md
      HKX_head=$(HKB_git rev-parse HEAD)
      HKB_git commit -q -m mixed > "$HKB_t/c9.txt" 2>&1; HKX_rc=$?
      grep -q '^pre-commit: quick: [0-9]* PASS, 0 FAIL' "$HKB_t/c9.txt" && HKX_t1=1
      grep -q 'documents mode' "$HKB_t/c9.txt" && grep -q 'hand-typed check count' "$HKB_t/c9.txt" && HKX_dn=1
      [ "$(HKB_git rev-parse HEAD)" = "$HKX_head" ] && HKX_kept=1
      [ "$HKX_rc" = 1 ] && [ "$HKX_t1" = 1 ] && [ "$HKX_dn" = 1 ] && [ "$HKX_kept" = 1 ] && HKX_ok=1
      # 10. tools/README.md alone, its fixture table made untrue (doc-truth binds it): the hook has to run T1 (green) and then the documents mode
      #     (red). It used to count as code only, ran T1 and let the commit land; the break showed one commit later.
      HKB_git reset -q --hard HEAD
      sed 's/| `many-clients.json` | 25 APs/| `many-clients.json` | 26 APs/' "$HKB_t/w/tools/README.md" > "$HKB_t/readme.new"
      if cmp -s "$HKB_t/readme.new" "$HKB_t/w/tools/README.md"; then HKT_ok=nochange
      else
        cp "$HKB_t/readme.new" "$HKB_t/w/tools/README.md"
        HKB_git add tools/README.md
        HKT_head=$(HKB_git rev-parse HEAD)
        HKB_git commit -q -m toolsreadme > "$HKB_t/c10.txt" 2>&1; HKT_rc=$?
        grep -q '^pre-commit: quick: [0-9]* PASS, 0 FAIL' "$HKB_t/c10.txt" && HKT_t1=1
        grep -q 'documents mode' "$HKB_t/c10.txt" && grep -q 'many-clients.json: the table says APs = 26' "$HKB_t/c10.txt" && HKT_dn=1
        [ "$(HKB_git rev-parse HEAD)" = "$HKT_head" ] && HKT_kept=1
        [ "$HKT_rc" = 1 ] && [ "$HKT_t1" = 1 ] && [ "$HKT_dn" = 1 ] && [ "$HKT_kept" = 1 ] && HKT_ok=1
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
rowif "pre-commit hook, documents only: clean rc $HKD_clean (want 0), 'quick docs:' named $HKD_n1, T1 not run $HKD_t1off, commit landed $HKD_moved, a code-only commit printed T1's summary $HKX_c1only; hand-typed count rc $HKD_rc1 (want 1) named $HKD_n2 HEAD kept $HKD_k1; filter off rc $HKD_ctl (want 0); renamed hotkey rc $HKD_rc2 (want 1) named and HEAD kept $HKD_k2" [ "$HKD_ok" = 1 ]
if [ "$HKD_ok" != 1 ] && [ -n "$HKB_t" ]; then
  for HKD_x in c6 c7 c7c c8; do [ -f "$HKB_t/$HKD_x.txt" ] && { echo "    -- $HKD_x:"; tail -n 8 "$HKB_t/$HKD_x.txt" | cut -c1-200 | sed 's/^/    /'; }; done
fi
rowif "pre-commit hook, code and a document staged together: T1 green ($HKX_t1) then the documents mode red ($HKX_dn), rc $HKX_rc (want 1), HEAD kept $HKX_kept" [ "$HKX_ok" = 1 ]
if [ "$HKX_ok" != 1 ] && [ -n "$HKB_t" ] && [ -f "$HKB_t/c9.txt" ]; then echo "    -- c9:"; tail -n 8 "$HKB_t/c9.txt" | cut -c1-200 | sed 's/^/    /'; fi
rowif "pre-commit hook, only tools/README.md staged (fixture table made untrue): T1 green ($HKT_t1) then the documents mode red ($HKT_dn), rc $HKT_rc (want 1), HEAD kept $HKT_kept" [ "$HKT_ok" = 1 ]
if [ "$HKT_ok" != 1 ] && [ -n "$HKB_t" ] && [ -f "$HKB_t/c10.txt" ]; then echo "    -- c10:"; tail -n 8 "$HKB_t/c10.txt" | cut -c1-200 | sed 's/^/    /'; fi
[ -z "$HKB_t" ] || rm -rf "$HKB_t"
