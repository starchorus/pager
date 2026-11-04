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
# DOCUMENTS PROBE: a commit that stages only a document (CONTRIBUTING.md, README.md, docs/architecture.md) has to START the documents mode (`quick.sh docs`)
#                 and not T1: clean => rc 0 and the summary line "quick docs: ..."; a hand-typed check count in README.md (doc-truth) and a
#                 hotkey of the spec's section 9.6 renamed in docs/architecture.md (doc-binding) => rc 1, the red row named, HEAD kept.
#                 Negative control: the document filter switched off in a copy of the hook lets the first of them through (rc 0). A
#                 commit of code and a document runs T1 first and then the documents mode (T1 green, documents red => rc 1, both named);
#                 tools/README.md alone (its fixture table made untrue; doc-truth binds it) is a document for the hook as well as code: T1 green,
#                 then the documents mode red => rc 1, HEAD kept (it used to land, and the break showed one commit later).
#                 a code-only commit prints T1's summary and never the documents mode's. Needs Chrome (doc-binding), like the mode itself.
# MAP PROBE:      docs/MAP.md staged alone is a document for the hook and code as well (its checker, repo-map, runs in T1): a comment line
#                 appended => T1 green, then the documents mode green, rc 0 and the commit lands; a line that names a document the tree has
#                 not got => T1 red on repo-map's row 'every path the map names exists', rc 1, HEAD kept. Negative control: the code filter
#                 without the map in a copy of the hook lets that commit through (rc 0, on the documents mode alone): it does not run repo-map.
# ADDED OR DELETED PROBE: a .md or .sh path added or deleted, alone, has to START T1 (repo-map wants a row in docs/MAP.md for every document
#                 and script, and every path the map names has to exist): docs/hook-probe-new.md without a row => T1 red on 'every script, tool
#                 and document has a row', rc 1, HEAD kept (red on 'files a drop-in names are among its subjects' too, since this drop-in names
#                 the file; the assertions read the first row); the same file with its row in the map, and its name among this drop-in's
#                 subjects there => T1 green, then the documents mode green, rc 0 and the commit lands; hook-probe.sh in the top directory
#                 without a row => red on 'every script, tool and document has a row', HEAD kept; DESIGN-DECISIONS.md deleted alone => T1 red
#                 on 'every path the map names exists' and, as this drop-in's own row names the file, on 'every subject is a group, a fragment
#                 or a file', HEAD kept; renamed alone => red on those two, on 'every script, tool and document has a row' for the new name
#                 and on 'files a drop-in names are among its subjects', HEAD kept. Negative controls: the hook without the added-or-deleted
#                 rule lets the new document through (rc 0, on the documents mode alone); a copy that looks at additions only (--diff-filter=A)
#                 lets the deletion through, and one without --no-renames lets the rename through (git then reports a rename, neither an
#                 addition nor a deletion), each on the documents mode alone.
# WIDER DOCUMENTS PROBE: every .md is a document for the hook (ROADMAP.md matched no filter before): a hand-typed check count in ROADMAP.md
#                 => the documents mode red (doc-truth), T1 not run, rc 1, HEAD kept; a comment line => rc 0 and the commit lands on the
#                 documents mode alone. Negative control: the document filter switched off lets the count through (rc 0).
# NOT PROVEN:     does not prove the index-versus-working-tree contract or the rest of the path filter (for those, the hand probes in the
#                 commit message), nothing under BusyBox, no git version other than the local one.
# Sourced by tools/regress.sh with cwd = repo root; twenty-five hook runs (one of them ends at the preflight, two before any mode; thirteen of them
# run the documents mode, about 15 s each, which needs Chrome; four of those are T1 and the documents mode in turn). Only HKB_*, HKM_*, HKS_*, HKD_*,
# HKN_*, HKR_*, HKT_*, HKW_* and HKX_* names are set.
# The neutral change of the code probes is one comment line appended to tools/install-hooks.sh in the copy (never tools/README.md: the hook counts
# that as a document); the page gets the appended bait text (never executed: quick.sh only greps it); no collector or display script is touched;
# the src-only probe takes the empty last line off one fragment and rebuilds the page in the copy, which gets smaller by that one byte;
# the map probe appends a comment line, and then a line naming an absent document, to docs/MAP.md in the copy; the added-or-deleted probe
# writes docs/hook-probe-new.md, a row and a subject for it in the map, and hook-probe.sh in the copy, and deletes and renames
# DESIGN-DECISIONS.md there; the wider documents probe appends to ROADMAP.md.
# shellcheck disable=SC2016   # the probe texts are literal Markdown (backticks), not expansions
HKB_t=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-hookb.XXXXXX") || HKB_t=
HKB_msg=""; HKB_ok=0; HKB_rc1=-; HKB_rc2=-; HKB_named=0; HKB_kept=0
HKM_ok=0; HKM_rc=-; HKM_named=0; HKM_kept=0   # the hook with a tool missing (jq) from PATH
HKS_msg=""; HKS_ok=0; HKS_rc1=-; HKS_rc2=-; HKS_named=0; HKS_kept=0   # a src-only commit, the page stale and then rebuilt
HKD_ok=0; HKD_clean=-; HKD_t1off=0; HKD_moved=0; HKD_rc1=-; HKD_rc2=-; HKD_n1=0; HKD_n2=0; HKD_k1=0; HKD_k2=0; HKD_ctl=-   # documents only
HKX_ok=0; HKX_rc=-; HKX_t1=0; HKX_dn=0; HKX_kept=0; HKX_c1only=0                                                           # code plus a document
HKT_ok=0; HKT_rc=-; HKT_t1=0; HKT_dn=0; HKT_kept=0                                                                         # tools/README.md alone
HKR_ok=0; HKR_rc1=-; HKR_t1=0; HKR_dn=0; HKR_moved=0; HKR_rc2=-; HKR_named=0; HKR_kept=0; HKR_ctl=-; HKR_cd=0               # docs/MAP.md alone
HKN_ok=0; HKN_rc1=-; HKN_n1=0; HKN_k1=0; HKN_ctl=-; HKN_cd=0; HKN_rc2=-; HKN_t1=0; HKN_dn=0; HKN_moved=0; HKN_rc3=-; HKN_n3=0; HKN_k3=0   # a .md or .sh added or deleted
HKN_rc4=-; HKN_n4=0; HKN_k4=0; HKN_ctl2=-; HKN_cd2=0; HKN_rc5=-; HKN_n5=0; HKN_k5=0; HKN_ctl3=-; HKN_cd3=0
HKW_ok=0; HKW_rc1=-; HKW_n1=0; HKW_k1=0; HKW_ctl=-; HKW_rc2=-; HKW_n2=0; HKW_moved=0                                         # ROADMAP.md alone
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
      # 11. docs/MAP.md alone (the MAP PROBE of the header): a comment line lands with T1 and the documents mode green; a line naming a document
      #     the tree has not got is refused on repo-map's row, HEAD kept; the control, the code filter without the map, lets it through.
      HKB_git reset -q --hard HEAD
      echo "<!-- hook probe map -->" >> "$HKB_t/w/docs/MAP.md"
      HKB_git add docs/MAP.md
      HKR_head=$(HKB_git rev-parse HEAD)
      HKB_git commit -q -m mapclean > "$HKB_t/c11.txt" 2>&1; HKR_rc1=$?
      grep -q '^pre-commit: quick: [0-9]* PASS, 0 FAIL' "$HKB_t/c11.txt" && HKR_t1=1
      grep -q '^pre-commit: quick docs: [0-9]* PASS, 0 FAIL' "$HKB_t/c11.txt" && HKR_dn=1
      [ "$(HKB_git rev-parse HEAD)" != "$HKR_head" ] && HKR_moved=1
      HKR_head=$(HKB_git rev-parse HEAD)
      printf '%s\n' '`docs/hook-probe-absent.md`' >> "$HKB_t/w/docs/MAP.md"
      HKB_git add docs/MAP.md
      HKB_git commit -q -m mapstale > "$HKB_t/c12.txt" 2>&1; HKR_rc2=$?
      grep -q 'every path the map names exists' "$HKB_t/c12.txt" && grep -q 'hook-probe-absent' "$HKB_t/c12.txt" && HKR_named=1
      [ "$(HKB_git rev-parse HEAD)" = "$HKR_head" ] && HKR_kept=1
      # control: the code filter without docs/MAP.md in the hook => the same stale map goes through on the documents mode alone
      sed 's,|docs/MAP\\[.]md),),' "$HKB_t/w/.githooks/pre-commit" > "$HKB_t/hook.nomap"
      if ! cmp -s "$HKB_t/hook.nomap" "$HKB_t/w/.githooks/pre-commit"; then
        cp "$HKB_t/hook.nomap" "$HKB_t/w/.githooks/pre-commit"; chmod +x "$HKB_t/w/.githooks/pre-commit"
        HKB_git commit -q -m mapctl > "$HKB_t/c12c.txt" 2>&1; HKR_ctl=$?
        grep -q '^pre-commit: quick docs: [0-9]* PASS, 0 FAIL' "$HKB_t/c12c.txt" && ! grep -q '^pre-commit: quick: ' "$HKB_t/c12c.txt" && HKR_cd=1
      else HKR_ctl=nochange; fi
      HKB_git reset -q --hard "$HKR_head"
      [ "$HKR_rc1" = 0 ] && [ "$HKR_t1" = 1 ] && [ "$HKR_dn" = 1 ] && [ "$HKR_moved" = 1 ] && [ "$HKR_rc2" = 1 ] && [ "$HKR_named" = 1 ] \
        && [ "$HKR_kept" = 1 ] && [ "$HKR_ctl" = 0 ] && [ "$HKR_cd" = 1 ] && HKR_ok=1
      # 12. a .md or .sh added or deleted, alone (the ADDED OR DELETED PROBE of the header): docs/hook-probe-new.md without a row is refused on
      #     repo-map's row, HEAD kept; the control, the hook without the added-or-deleted rule, lets it through on the documents mode alone;
      #     with its row in the map, and its name among this drop-in's subjects there, it lands, T1 and the documents mode green;
      #     hook-probe.sh in the top directory without a row is refused on the same row; DESIGN-DECISIONS.md deleted alone, then renamed
      #     alone, is refused on 'every path the map names exists', each with a control that lets it through on the documents mode alone.
      HKB_git reset -q --hard HEAD
      echo "A probe document." > "$HKB_t/w/docs/hook-probe-new.md"
      HKB_git add docs/hook-probe-new.md
      HKN_head=$(HKB_git rev-parse HEAD)
      HKB_git commit -q -m newdoc > "$HKB_t/c13.txt" 2>&1; HKN_rc1=$?
      grep -q 'every script, tool and document has a row' "$HKB_t/c13.txt" && grep -q 'hook-probe-new.md: a document without a row' "$HKB_t/c13.txt" && HKN_n1=1
      [ "$(HKB_git rev-parse HEAD)" = "$HKN_head" ] && HKN_k1=1
      # control: the hook without the added-or-deleted rule => the same new document lands on the documents mode alone
      sed '/staged_ad/d' "$HKB_t/w/.githooks/pre-commit" > "$HKB_t/hook.noad"
      if ! cmp -s "$HKB_t/hook.noad" "$HKB_t/w/.githooks/pre-commit"; then
        cp "$HKB_t/hook.noad" "$HKB_t/w/.githooks/pre-commit"; chmod +x "$HKB_t/w/.githooks/pre-commit"
        HKB_git commit -q -m newdocctl > "$HKB_t/c13c.txt" 2>&1; HKN_ctl=$?
        grep -q '^pre-commit: quick docs: [0-9]* PASS, 0 FAIL' "$HKB_t/c13c.txt" && ! grep -q '^pre-commit: quick: ' "$HKB_t/c13c.txt" && HKN_cd=1
      else HKN_ctl=nochange; fi
      HKB_git reset -q --hard "$HKN_head"
      echo "A probe document." > "$HKB_t/w/docs/hook-probe-new.md"
      awk '/^\| `hook-behavior` \|/ { sub(/ \|$/, " `docs/hook-probe-new.md` |") } { print } /^\| `docs\/MAP\.md` \|/ { print "| `docs/hook-probe-new.md` | |" }' "$HKB_t/w/docs/MAP.md" > "$HKB_t/map.new" && cp "$HKB_t/map.new" "$HKB_t/w/docs/MAP.md"
      HKB_git add docs/hook-probe-new.md docs/MAP.md
      HKB_git commit -q -m newdocrow > "$HKB_t/c14.txt" 2>&1; HKN_rc2=$?
      grep -q '^pre-commit: quick: [0-9]* PASS, 0 FAIL' "$HKB_t/c14.txt" && HKN_t1=1
      grep -q '^pre-commit: quick docs: [0-9]* PASS, 0 FAIL' "$HKB_t/c14.txt" && HKN_dn=1
      [ "$(HKB_git rev-parse HEAD)" != "$HKN_head" ] && HKN_moved=1
      HKB_git reset -q --hard "$HKN_head"
      printf '%s\n' '#!/bin/sh' '# SPDX-License-Identifier: GPL-3.0-or-later' ': probe' > "$HKB_t/w/hook-probe.sh"
      HKB_git add hook-probe.sh
      HKB_git commit -q -m newscript > "$HKB_t/c15.txt" 2>&1; HKN_rc3=$?
      grep -q 'every script, tool and document has a row' "$HKB_t/c15.txt" && grep -q 'hook-probe.sh: a script without a row' "$HKB_t/c15.txt" && HKN_n3=1
      [ "$(HKB_git rev-parse HEAD)" = "$HKN_head" ] && HKN_k3=1
      HKB_git reset -q --hard "$HKN_head"; rm -f "$HKB_t/w/hook-probe.sh" "$HKB_t/w/docs/hook-probe-new.md"
      # a document the map names deleted alone: T1 red on 'every path the map names exists', HEAD kept; the control, a copy of the hook that
      # looks at additions only, lets it land on the documents mode alone
      HKB_git rm -q DESIGN-DECISIONS.md
      HKB_git commit -q -m deldoc > "$HKB_t/c18.txt" 2>&1; HKN_rc4=$?
      grep -q 'every path the map names exists' "$HKB_t/c18.txt" && grep -q '"DESIGN-DECISIONS.md" does not exist' "$HKB_t/c18.txt" && HKN_n4=1
      [ "$(HKB_git rev-parse HEAD)" = "$HKN_head" ] && HKN_k4=1
      sed 's/--diff-filter=AD/--diff-filter=A/' "$HKB_t/w/.githooks/pre-commit" > "$HKB_t/hook.addonly"
      if ! cmp -s "$HKB_t/hook.addonly" "$HKB_t/w/.githooks/pre-commit"; then
        cp "$HKB_t/hook.addonly" "$HKB_t/w/.githooks/pre-commit"; chmod +x "$HKB_t/w/.githooks/pre-commit"
        HKB_git commit -q -m deldocctl > "$HKB_t/c18c.txt" 2>&1; HKN_ctl2=$?
        grep -q '^pre-commit: quick docs: [0-9]* PASS, 0 FAIL' "$HKB_t/c18c.txt" && ! grep -q '^pre-commit: quick: ' "$HKB_t/c18c.txt" && HKN_cd2=1
      else HKN_ctl2=nochange; fi
      HKB_git reset -q --hard "$HKN_head"
      # the same document renamed alone: T1 red (the old name gone from the tree, the new one without a row), HEAD kept; the control, a copy
      # without --no-renames on the added-or-deleted list, lets it land on the documents mode alone (git then reports a rename, neither A nor D)
      HKB_git mv DESIGN-DECISIONS.md DESIGN-DECISIONS-2.md
      HKB_git commit -q -m mvdoc > "$HKB_t/c19.txt" 2>&1; HKN_rc5=$?
      grep -q '"DESIGN-DECISIONS.md" does not exist' "$HKB_t/c19.txt" && grep -q 'DESIGN-DECISIONS-2.md: a document without a row' "$HKB_t/c19.txt" && HKN_n5=1
      [ "$(HKB_git rev-parse HEAD)" = "$HKN_head" ] && HKN_k5=1
      sed '/^staged_ad=/s/ --no-renames//' "$HKB_t/w/.githooks/pre-commit" > "$HKB_t/hook.renames"
      if ! cmp -s "$HKB_t/hook.renames" "$HKB_t/w/.githooks/pre-commit"; then
        cp "$HKB_t/hook.renames" "$HKB_t/w/.githooks/pre-commit"; chmod +x "$HKB_t/w/.githooks/pre-commit"
        HKB_git commit -q -m mvdocctl > "$HKB_t/c19c.txt" 2>&1; HKN_ctl3=$?
        grep -q '^pre-commit: quick docs: [0-9]* PASS, 0 FAIL' "$HKB_t/c19c.txt" && ! grep -q '^pre-commit: quick: ' "$HKB_t/c19c.txt" && HKN_cd3=1
      else HKN_ctl3=nochange; fi
      HKB_git reset -q --hard "$HKN_head"
      [ "$HKN_rc1" = 1 ] && [ "$HKN_n1" = 1 ] && [ "$HKN_k1" = 1 ] && [ "$HKN_ctl" = 0 ] && [ "$HKN_cd" = 1 ] && [ "$HKN_rc2" = 0 ] && [ "$HKN_t1" = 1 ] \
        && [ "$HKN_dn" = 1 ] && [ "$HKN_moved" = 1 ] && [ "$HKN_rc3" = 1 ] && [ "$HKN_n3" = 1 ] && [ "$HKN_k3" = 1 ] \
        && [ "$HKN_rc4" = 1 ] && [ "$HKN_n4" = 1 ] && [ "$HKN_k4" = 1 ] && [ "$HKN_ctl2" = 0 ] && [ "$HKN_cd2" = 1 ] \
        && [ "$HKN_rc5" = 1 ] && [ "$HKN_n5" = 1 ] && [ "$HKN_k5" = 1 ] && [ "$HKN_ctl3" = 0 ] && [ "$HKN_cd3" = 1 ] && HKN_ok=1
      # 13. ROADMAP.md alone (the WIDER DOCUMENTS PROBE of the header): a hand-typed check count is refused by the documents mode, T1 not run,
      #     HEAD kept; the control, the document filter switched off, lets it through; a comment line lands on the documents mode alone.
      printf '%s\n' '- `--selftest` green (42 checks) under BusyBox' >> "$HKB_t/w/ROADMAP.md"
      HKB_git add ROADMAP.md
      HKW_head=$(HKB_git rev-parse HEAD)
      HKB_git commit -q -m roadmapcount > "$HKB_t/c16.txt" 2>&1; HKW_rc1=$?
      grep -q 'hand-typed check count' "$HKB_t/c16.txt" && grep -q 'documents mode' "$HKB_t/c16.txt" && ! grep -q '^pre-commit: quick: ' "$HKB_t/c16.txt" && HKW_n1=1
      [ "$(HKB_git rev-parse HEAD)" = "$HKW_head" ] && HKW_k1=1
      sed 's/&& need_docs=1$/\&\& need_docs=0/' "$HKB_t/w/.githooks/pre-commit" > "$HKB_t/hook.off2"
      if ! cmp -s "$HKB_t/hook.off2" "$HKB_t/w/.githooks/pre-commit"; then
        cp "$HKB_t/hook.off2" "$HKB_t/w/.githooks/pre-commit"; chmod +x "$HKB_t/w/.githooks/pre-commit"
        HKB_git commit -q -m roadmapctl > "$HKB_t/c16c.txt" 2>&1; HKW_ctl=$?
      else HKW_ctl=nochange; fi
      HKB_git reset -q --hard "$HKW_head"
      echo "<!-- hook probe roadmap -->" >> "$HKB_t/w/ROADMAP.md"
      HKB_git add ROADMAP.md
      HKB_git commit -q -m roadmapclean > "$HKB_t/c17.txt" 2>&1; HKW_rc2=$?
      grep -q '^pre-commit: quick docs: [0-9]* PASS, 0 FAIL' "$HKB_t/c17.txt" && ! grep -q '^pre-commit: quick: ' "$HKB_t/c17.txt" && HKW_n2=1
      [ "$(HKB_git rev-parse HEAD)" != "$HKW_head" ] && HKW_moved=1
      [ "$HKW_rc1" = 1 ] && [ "$HKW_n1" = 1 ] && [ "$HKW_k1" = 1 ] && [ "$HKW_ctl" = 0 ] && [ "$HKW_rc2" = 0 ] && [ "$HKW_n2" = 1 ] && [ "$HKW_moved" = 1 ] && HKW_ok=1
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
rowif "pre-commit hook, only docs/MAP.md staged: a comment line rc $HKR_rc1 (want 0), T1 green $HKR_t1, documents mode green $HKR_dn, commit landed $HKR_moved; a line naming a document the tree has not got rc $HKR_rc2 (want 1), repo-map's row named $HKR_named, HEAD kept $HKR_kept; code filter without the map rc $HKR_ctl (want 0), the documents mode alone $HKR_cd" [ "$HKR_ok" = 1 ]
if [ "$HKR_ok" != 1 ] && [ -n "$HKB_t" ]; then
  for HKR_x in c11 c12 c12c; do [ -f "$HKB_t/$HKR_x.txt" ] && { echo "    -- $HKR_x:"; tail -n 8 "$HKB_t/$HKR_x.txt" | cut -c1-200 | sed 's/^/    /'; }; done
fi
rowif "pre-commit hook, a .md or .sh added or deleted, alone: docs/hook-probe-new.md without a row rc $HKN_rc1 (want 1), repo-map's row named $HKN_n1, HEAD kept $HKN_k1; hook without the added-or-deleted rule rc $HKN_ctl (want 0), the documents mode alone $HKN_cd; with its row and subject in the map rc $HKN_rc2 (want 0), T1 green $HKN_t1, documents mode green $HKN_dn, commit landed $HKN_moved; hook-probe.sh without a row rc $HKN_rc3 (want 1), named $HKN_n3, HEAD kept $HKN_k3; DESIGN-DECISIONS.md deleted alone rc $HKN_rc4 (want 1), named $HKN_n4, HEAD kept $HKN_k4, additions-only copy rc $HKN_ctl2 (want 0) on the documents mode alone $HKN_cd2; renamed alone rc $HKN_rc5 (want 1), named $HKN_n5, HEAD kept $HKN_k5, copy without --no-renames rc $HKN_ctl3 (want 0) on the documents mode alone $HKN_cd3" [ "$HKN_ok" = 1 ]
if [ "$HKN_ok" != 1 ] && [ -n "$HKB_t" ]; then
  for HKN_x in c13 c13c c14 c15 c18 c18c c19 c19c; do [ -f "$HKB_t/$HKN_x.txt" ] && { echo "    -- $HKN_x:"; tail -n 8 "$HKB_t/$HKN_x.txt" | cut -c1-200 | sed 's/^/    /'; }; done
fi
rowif "pre-commit hook, only ROADMAP.md staged (every .md is a document): hand-typed count rc $HKW_rc1 (want 1), named and T1 not run $HKW_n1, HEAD kept $HKW_k1; filter off rc $HKW_ctl (want 0); a comment line rc $HKW_rc2 (want 0), the documents mode alone $HKW_n2, commit landed $HKW_moved" [ "$HKW_ok" = 1 ]
if [ "$HKW_ok" != 1 ] && [ -n "$HKB_t" ]; then
  for HKW_x in c16 c16c c17; do [ -f "$HKB_t/$HKW_x.txt" ] && { echo "    -- $HKW_x:"; tail -n 8 "$HKB_t/$HKW_x.txt" | cut -c1-200 | sed 's/^/    /'; }; done
fi
[ -z "$HKB_t" ] || rm -rf "$HKB_t"
