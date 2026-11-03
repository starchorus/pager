# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/repo-map.sh -- the repository map, docs/MAP.md, stays true to the tree, and the tools around it do what tools/README.md
#   says: tools/affected.sh answers by the map, the drop-ins mode of tools/quick.sh runs the drop-ins it is given, and the documents mode
#   prints what it printed before.
# GUARDS AGAINST: a map that rots as the code moves: a fragment, marker line, script, tool, document or drop-in without its row, or a row
#                 left over; a named path that is gone; an anchor that no longer occurs, or a region's anchor outside its region; a
#                 drop-in row that misses what the drop-in's own text shows (a section slice, a Chrome run, a read of the page or of the
#                 fixtures, a file it names); tools/affected.sh answering otherwise than its map; the drop-ins mode running more or less
#                 than it was given; a documents mode that prints otherwise.
# NEGATIVE PROBE: planted copies of the map and a planted drop-in, one break each, turn exactly their own check red and an unbroken one
#                 none (row 'probes bite'); a planted map changes the answer of tools/affected.sh. The last three rows (the drop-ins
#                 mode, the documents mode, affected.sh) are probed by hand, not by a standing row: a muted case in each turns its row red.
# NOT PROVEN:     that a row names everything its drop-in reads (a read through another tool, a file named through a glob or a variable,
#                 or a fragment reached through the page's API, is not in the drop-in's text); that the prose of the map is right.
# Sourced by tools/regress.sh (T2) and tools/quick.sh (T1) with cwd = repo root; Chrome-free: the Chrome rule is read from the
# QUICK_CHROME_RE line of tools/static.sh, never written here. git only where the root is a git work tree (the hook's export has none:
# then a walk). Only RMP_* names and rmp_* functions are set; the functions are removed at the end.
# shellcheck disable=SC2016   # backticks and dollars in single quotes are Markdown and shell text of planted files, not expansions

rmp_table() {   # rmp_table MAP OUT: the map as records (tools/affected.sh --table); its exit status in RMP_trc
  sh tools/affected.sh --map "$1" --table > "$2" 2> "$2.err"; RMP_trc=$?
}
rmp_facts() {   # rmp_facts FILE...: what each drop-in's own text shows, NAME TAB KIND TAB VALUE
  awk '
    # one path per line; then the drop-in files. Output: NAME TAB KIND TAB VALUE, KIND = file | slice | path | hvar | fvar.
    function flush(    i, j, k, t, s, w, f, tok, p, seen) {
      if (cur == "") return
      print nm "\tfile\t-"
      split("", w)
      for (i = 1; i <= n; i++)
        if (match(L[i], /[A-Za-z_][A-Za-z0-9_]*\(\) *[{][^}]*sec_(slice|grepc) "[$]1" "[$]2"/)) {
          s = substr(L[i], RSTART, RLENGTH); sub(/\(.*/, "", s); w[s] = 1
        }
      split("", seen)
      for (i = 1; i <= n; i++) {
        t = L[i]
        while (match(t, /sec_(slice|grepc) [0-9][0-9] [0-9][0-9]/)) {
          s = substr(t, RSTART, RLENGTH); split(s, f, " "); print nm "\tslice\t" f[2] " " f[3]; t = substr(t, RSTART + RLENGTH)
        }
        for (s in w) {
          t = " " L[i]
          while (match(t, "[^A-Za-z0-9_]" s " [0-9][0-9] [0-9][0-9]")) {
            k = substr(t, RSTART + 1, RLENGTH - 1); split(k, f, " "); print nm "\tslice\t" f[2] " " f[3]; t = substr(t, RSTART + RLENGTH)
          }
        }
        t = L[i]
        while (match(t, /[\/]==== [0-9][0-9] [^\/]*[\/],[\/]==== [0-9][0-9] /)) {
          s = substr(t, RSTART, RLENGTH); gsub(/[^0-9 ]/, " ", s); split(s, f, " "); print nm "\tslice\t" f[1] " " f[2]
          t = substr(t, RSTART + RLENGTH)
        }
        if (L[i] ~ /[$]H([^A-Za-z0-9_]|$)/ || L[i] ~ /[$][{]H[}]/) hv = 1
        if (L[i] ~ /[$]F([^A-Za-z0-9_]|$)/ || L[i] ~ /[$][{]F[}]/) fv = 1
        t = L[i]
        gsub(/"[$]R"[\/]/, "", t); gsub(/[$][{]R[}][\/]/, "", t); gsub(/[$]R[\/]/, "", t)
        gsub(/[^A-Za-z0-9._\/-]+/, " ", t)
        k = split(t, tok, " ")
        for (j = 1; j <= k; j++) {
          p = tok[j]; sub(/^[.][\/]/, "", p)
          if ((p in U) && !(p in seen) && p != own) { seen[p] = 1; print nm "\tpath\t" p }
        }
      }
      if (hv) print nm "\thvar\t-"
      if (fv) print nm "\tfvar\t-"
    }
    NR == FNR { if ($0 !~ /^out[\/]/) U[$0] = 1; next }
    FNR == 1 { flush(); cur = FILENAME; nm = cur; sub(/.*[\/]/, "", nm); sub(/[.]sh$/, "", nm); own = "tools/regress.d/" nm ".sh"; n = 0; hv = 0; fv = 0 }
    /^[ \t]*#/ { next }
    { L[++n] = $0 }
    END { flush() }
  ' "$RMP_t/u.txt" "$@"
  for RMP_f in "$@"; do
    RMP_c=0
    [ -z "$RMP_cre" ] || RMP_c=$(grep -v '^[[:space:]]*#' "$RMP_f" | grep -cE "$RMP_cre")
    printf '%s\tchrome\t%s\n' "$(basename "$RMP_f" .sh)" "$RMP_c"
  done
}
rmp_marks() {   # rmp_marks TABLE > OUT: the titled marker lines of each script of the map; a byte copy of an earlier script is "copy"
  RMP_seen=""
  awk -F '\t' '$1 == "script" { print $3 }' "$1" > "$RMP_t/scripts.txt"
  while IFS= read -r RMP_s; do
    [ -f "$RMP_s" ] || continue
    RMP_c=""
    # shellcheck disable=SC2086   # the scripts seen so far: a word list (the map's paths hold no blank)
    for RMP_o in $RMP_seen; do if cmp -s "$RMP_o" "$RMP_s"; then RMP_c=$RMP_o; break; fi; done
    if [ -n "$RMP_c" ]; then printf '%s\tcopy\t%s\n' "$RMP_s" "$RMP_c"
    else
      grep -n -E '^# [-=]{4,} +[^ ]' "$RMP_s" | awk -v s="$RMP_s" '{ i = index($0, ":"); t = substr($0, i + 1); sub(/^# [-=]+ +/, "", t); print s "\t" substr($0, 1, i - 1) "\t" t }'
      awk -v s="$RMP_s" 'END { print s "\tend\t" NR }' "$RMP_s"
    fi
    RMP_seen="$RMP_seen $RMP_s"
  done < "$RMP_t/scripts.txt"
}
rmp_judge() {   # rmp_judge TABLE FACTS DIR: every check on one map and one set of facts -> DIR/res (CHECK TAB ok|red TAB COUNT), DIR/ev
  mkdir -p "$3"; : > "$3/ev"
  awk -v ev="$3/ev" -v trc="$RMP_trc" -v cre="$RMP_creok" '
    BEGIN { FS = "\t" }
    function glob(g,    i, c, r) {
      r = "^"
      for (i = 1; i <= length(g); i++) { c = substr(g, i, 1); r = r (c == "*" ? "[^/]*" : c == "." ? "[.]" : c) }
      return r "$"
    }
    function ingroup(w, p,    i) { for (i = 1; i <= GN[w]; i++) if (p ~ glob(GP[w, i])) return 1; return 0 }
    function exists(p,    q, u, rx) {
      if (index(p, "*")) { rx = glob(p); for (u in U) if (u ~ rx) return 1; return 0 }
      q = p; sub(/\/$/, "", q); return (q in U) || (q in DIR)
    }
    function pathlike(s) {
      if (s !~ /^[A-Za-z0-9._][A-Za-z0-9._\/*-]*$/ || s ~ /^out\//) return 0
      return (index(s, "/") > 0 || s ~ /[.](md|sh|py|js|json|html|css|list|txt|yml)$/)
    }
    function red(c, t) { RED[c] = 1; if (t != "") print c "\t" t > ev }
    function named(d, s,    j) { for (j = 1; j <= SC[d]; j++) if (SS[d, j] == s) return 1; return 0 }
    function covers(d, p,    j, s) {
      if (p == "tools/regress.d/" d ".sh" || ingroup("all", p)) return 1
      for (j = 1; j <= SC[d]; j++) {
        s = SS[d, j]
        if (s in GN) { if (ingroup(s, p)) return 1 }
        else if (s in FP) { if (FP[s] == p) return 1 }
        else if (p ~ glob(s)) return 1
      }
      return 0
    }
    FILENAME == ARGV[1] {
      k = $1
      if (k == "bad") { red("C1", "docs/MAP.md line " $2 ": " $4); next }
      if (k == "prose") { if (pathlike($4)) { PL2[++NP] = $4; PLN[NP] = $2 } next }
      if (k == "table" || k == "anchor" || k == "ranchor") next
      if (k == "subject") { SS[$3, ++SC[$3]] = $4; SL[$3, SC[$3]] = $2; NSUB++; next }
      ROWS[$2] = 1
      if (k == "group") { if (!($3 in GN)) GW[++NG] = $3; GP[$3, ++GN[$3]] = $4; PL2[++NP] = $4; PLN[NP] = $2 }
      else if (k == "fragment") { FR[++NFR] = $3; f = $3; sub(/.*\//, "", f); sub(/\.[^.]*$/, "", f); FP[f] = $3; PL2[++NP] = $3; PLN[NP] = $2
        if (f ~ /^[0-9][0-9]-/) FNUM[substr(f, 1, 2) + 0] = f }
      else if (k == "script") { SCR[++NS] = $3; ISS[$3] = 1; PL2[++NP] = $3; PLN[NP] = $2 }
      else if (k == "region") { RGS[++NRG] = $3; RGT[NRG] = $4; RL[NRG] = $2 }
      else if (k == "tool") { TL[++NTL] = $3; PL2[++NP] = $3; PLN[NP] = $2 }
      else if (k == "document") { DOC[$3] = 1; PL2[++NP] = $3; PLN[NP] = $2 }
      else if (k == "dropin") { DR[$3] = $2; DN[++ND] = $3 }
      else if (k == "place") { PL2[++NP] = $3; PLN[NP] = $2 }
      next
    }
    FILENAME == ARGV[2] {
      d = $1
      if ($2 == "file") { FILE[d] = 1; FN[++NFN] = d }
      else if ($2 == "slice") { SLA[++NSL] = d; SLV[NSL] = $3 }
      else if ($2 == "path") { PA[++NPA] = d; PV[NPA] = $3 }
      else if ($2 == "hvar") HV[d] = 1
      else if ($2 == "fvar") FV[d] = 1
      else if ($2 == "chrome") CH[d] = $3 + 0
      next
    }
    FILENAME == ARGV[3] { U[$0] = 1; UL[++NU] = $0; p = $0; while (sub(/\/[^\/]*$/, "", p)) DIR[p] = 1; next }
    FILENAME == ARGV[4] { if ($0 != "") PGL[++NPG] = "src/" $0; next }
    FILENAME == ARGV[5] { if ($2 == "copy") COPY[$1] = 1; else if ($2 == "end") MEND[$1] = $3; else { MK[$1, ++MN[$1]] = $3; ML[$1, MN[$1]] = $2 } next }
    END {
      # C1: the map parses
      if (trc != 0) red("C1", "tools/affected.sh --table: exit " trc)
      n = 0; for (l in ROWS) n++
      print "C1\t" (("C1" in RED) ? "red" : "ok") "\t" n
      # C2: the fragments are the lines of src/PAGE.list, in build order
      m = (NFR > NPG) ? NFR : NPG; e = 0
      for (i = 1; i <= m; i++) if (FR[i] != PGL[i] && e++ < 3)
        red("C2", "position " i ": docs/MAP.md has \"" (FR[i] == "" ? "no row" : FR[i]) "\", src/PAGE.list has \"" (PGL[i] == "" ? "no line" : PGL[i]) "\": make the rows follow src/PAGE.list")
      if (e) RED["C2"] = 1
      print "C2\t" (("C2" in RED) ? "red" : "ok") "\t" NPG
      # C3: per script with marker lines (a byte copy has none of its own), its rows follow them; each region starts exactly one title
      nm = 0; nk = 0
      for (i = 1; i <= NS; i++) { s = SCR[i]; if ((s in COPY) || MN[s] == 0) continue; BEAR[s] = 1; nk++; nm += MN[s] }
      for (i = 1; i <= NS; i++) {
        s = SCR[i]; if (!(s in BEAR)) continue
        r = 0
        for (j = 1; j <= NRG; j++) if (RGS[j] == s) {
          r++
          if (r <= MN[s] && index(MK[s, r], RGT[j]) != 1) red("C3", "docs/MAP.md line " RL[j] ": \"" RGT[j] "\" does not start the title of marker " r " of " s " (\"" substr(MK[s, r], 1, 60) "\", line " ML[s, r] ")")
          u = 0; for (q = 1; q <= MN[s]; q++) if (index(MK[s, q], RGT[j]) == 1) u++
          if (u != 1) red("C3", "docs/MAP.md line " RL[j] ": \"" RGT[j] "\" starts " u " marker titles of " s ": name it so that it starts exactly one")
        }
        if (r != MN[s]) red("C3", s ": " MN[s] " marker lines, " r " region rows: a row per marker line, in order")
      }
      for (j = 1; j <= NRG; j++) if (!(RGS[j] in BEAR)) red("C3", "docs/MAP.md line " RL[j] ": " RGS[j] " is no script of the map with marker lines of its own")
      print "C3\t" (("C3" in RED) ? "red" : "ok") "\t" nm " in " nk
      # C4: every script, tool and document of the repository has a row
      ns = nt = nd = 0
      for (i = 1; i <= NU; i++) {
        u = UL[i]
        if ((u ~ /[.]sh$/ && u !~ /^tools\//) || u ~ /^[.]githooks\//) { ns++; if (!(u in ISS)) red("C4", u ": a script without a row in docs/MAP.md (Scripts): add one") }
        if (u ~ /^tools\// && u !~ /^tools\/regress[.]d\// && u !~ /[.]md$/) {
          nt++; c = 0
          for (j = 1; j <= NTL; j++) if (TL[j] == u || (TL[j] ~ /\/$/ && index(u, TL[j]) == 1)) c = 1
          if (!c) red("C4", u ": a tool without a row in docs/MAP.md (Tools): add one")
        }
        if (u ~ /[.]md$/) { nd++; if (!(u in DOC)) red("C4", u ": a document without a row in docs/MAP.md (Documents): add one") }
      }
      print "C4\t" (("C4" in RED) ? "red" : "ok") "\t" ns ", " nt ", " nd
      # C5: the drop-ins are the files of tools/regress.d, each row with a subject
      for (i = 1; i <= NFN; i++) if (!(FN[i] in DR)) red("C5", "tools/regress.d/" FN[i] ".sh: no row in docs/MAP.md (Drop-ins): add one")
      for (i = 1; i <= ND; i++) {
        d = DN[i]
        if (!(d in FILE)) red("C5", "docs/MAP.md line " DR[d] ": no tools/regress.d/" d ".sh: remove the row")
        else if (SC[d] < 1) red("C5", "docs/MAP.md line " DR[d] ": " d " names no subject")
      }
      print "C5\t" (("C5" in RED) ? "red" : "ok") "\t" NFN
      # C6: every subject is a group, a fragment or a file (a glob that matches one)
      for (i = 1; i <= ND; i++) for (j = 1; j <= SC[DN[i]]; j++) {
        s = SS[DN[i], j]
        if ((s in GN) || (s in FP) || (s in U) || (index(s, "*") > 0 && exists(s))) continue
        red("C6", "docs/MAP.md line " SL[DN[i], j] ": " DN[i] " names \"" s "\", which is no group, no fragment and no file of the repository")
      }
      print "C6\t" (("C6" in RED) ? "red" : "ok") "\t" NSUB + 0
      # C7: every other path and glob the map names exists
      for (i = 1; i <= NP; i++) if (!exists(PL2[i])) red("C7", "docs/MAP.md line " PLN[i] ": \"" PL2[i] "\" does not exist: correct or remove it")
      print "C7\t" (("C7" in RED) ? "red" : "ok") "\t" NP
      # C10: a section slice names its fragments
      for (i = 1; i <= NSL; i++) {
        d = SLA[i]; if (!(d in DR)) continue
        split(SLV[i], ab, " "); a = ab[1] + 0; b = ab[2] + 0; if (b <= a) b = a + 1; hit = 0
        for (q = a; q < b; q++) if (q in FNUM) { hit++; f = FNUM[q]; if (!named(d, f) && !covers(d, FP[f])) red("C10", d ": a section slice of " ab[1] " " ab[2] ", and its row names no " f ": add it") }
        if (!hit) red("C10", d ": a section slice of " ab[1] " " ab[2] ", which no fragment of src/PAGE.list carries")
      }
      print "C10\t" (("C10" in RED) ? "red" : "ok") "\t" NSL + 0
      # C11: a drop-in that runs Chrome or reads the page (H of tools/harness.sh) names page
      if (!cre) red("C11", "the rule could not be read from the QUICK_CHROME_RE line of tools/static.sh: adjust repo-map.sh")
      n = 0
      for (i = 1; i <= NFN; i++) {
        d = FN[i]; if (!(d in DR) || !(CH[d] > 0 || (d in HV))) continue
        n++; if (!named(d, "page")) red("C11", d ": " (CH[d] > 0 ? "runs Chrome (the rule of tools/static.sh)" : "reads the page (H of tools/harness.sh)") ", and its row does not name page: add it")
      }
      print "C11\t" (("C11" in RED) ? "red" : "ok") "\t" n
      # C12: every file a drop-in names, and the fixtures it reads (F of tools/harness.sh), are among its subjects
      n = 0
      for (i = 1; i <= NPA; i++) {
        d = PA[i]; if (!(d in DR)) continue
        n++; if (!covers(d, PV[i])) red("C12", d ": names " PV[i] ", which no subject of its row covers: add the path or its group")
      }
      for (i = 1; i <= NFN; i++) {
        d = FN[i]; if (!(d in FV) || !(d in DR)) continue
        n++; c = named(d, "fixtures"); for (j = 1; j <= SC[d]; j++) if (index(SS[d, j], "tests/fixtures/") == 1) c = 1
        if (!c) red("C12", d ": reads the fixtures (F of tools/harness.sh), and its row names no fixture: add fixtures")
      }
      print "C12\t" (("C12" in RED) ? "red" : "ok") "\t" n
    }
  ' "$1" "$2" "$RMP_t/u.txt" src/PAGE.list "$RMP_t/marks.txt" > "$3/res"
  # C8: every anchor occurs in its file (skipped and taken from the real run when the list of anchors is the real one)
  awk -F '\t' '$1 == "anchor" { print $3 "\t" $4 }' "$1" > "$3/c8.in"
  if [ -s "$RMP_t/real/c8.in" ] && cmp -s "$3/c8.in" "$RMP_t/real/c8.in" && [ "$3" != "$RMP_t/real" ]; then
    grep '^C8	' "$RMP_t/real/res" >> "$3/res"
  else
    awk -F '\t' '$1 == "anchor" { print $3 "\t" $4 "\t" $2 }' "$1" | awk -v ev="$3/ev" '
      BEGIN { FS = "\t" }
      FILENAME == ARGV[1] { U[$0] = 1; next }
      { f = $1; if (!(f in U)) next; if (!(f in NA)) FL[++NFL] = f; A[f, ++NA[f]] = $2; L[f, NA[f]] = $3; N++ }
      END {
        for (i = 1; i <= NFL; i++) {
          f = FL[i]; split("", hit)
          while ((getline line < f) > 0) for (j = 1; j <= NA[f]; j++) if (!(j in hit) && index(line, A[f, j])) hit[j] = 1
          close(f)
          for (j = 1; j <= NA[f]; j++) if (!(j in hit)) { bad = 1; print "C8\tdocs/MAP.md line " L[f, j] ": \"" A[f, j] "\" does not occur in " f ": update the anchor" > ev }
        }
        print "C8\t" (bad ? "red" : "ok") "\t" N + 0
      }' "$RMP_t/u.txt" - >> "$3/res"
  fi
  # C9: a region's anchors lie inside the region (skipped likewise when the regions and their anchors are the real ones)
  awk -F '\t' '$1 == "region" || $1 == "ranchor"' "$1" | cut -f1,3,4 > "$3/c9.in"
  if [ -s "$RMP_t/real/c9.in" ] && cmp -s "$3/c9.in" "$RMP_t/real/c9.in" && [ "$3" != "$RMP_t/real" ]; then
    grep '^C9	' "$RMP_t/real/res" >> "$3/res"
  else
    awk -v ev="$3/ev" '
      BEGIN { FS = "\t" }
      FILENAME == ARGV[1] { if ($2 == "end") E[$1] = $3; else if ($2 != "copy") { MK[$1, ++MN[$1]] = $3; ML[$1, MN[$1]] = $2 } next }
      $1 == "region" { RGS[$2] = $3; RGT[$2] = $4; next }
      $1 == "ranchor" { AN[++N] = $4; AL[N] = $2; next }
      END {
        for (i = 1; i <= N; i++) {
          l = AL[i]; s = RGS[l]; t = RGT[l]; u = 0
          for (q = 1; q <= MN[s]; q++) if (index(MK[s, q], t) == 1) { u++; k = q }
          if (u != 1) continue
          if (!(s in NW)) SL[++NS] = s
          W[s, ++NW[s]] = i; WA[i] = ML[s, k]; WB[i] = (k < MN[s]) ? ML[s, k + 1] - 1 : E[s]
        }
        for (j = 1; j <= NS; j++) {
          s = SL[j]; n = 0; split("", hit)
          while ((getline line < s) > 0) { n++; for (q = 1; q <= NW[s]; q++) { i = W[s, q]; if (!(i in hit) && n >= WA[i] && n <= WB[i] && index(line, AN[i])) hit[i] = 1 } }
          close(s)
          for (q = 1; q <= NW[s]; q++) { i = W[s, q]; if (!(i in hit)) { bad = 1; print "C9\tdocs/MAP.md line " AL[i] ": \"" AN[i] "\" is not inside " s " lines " WA[i] "-" WB[i] ": give it to the row of its region" > ev } }
        }
        print "C9\t" (bad ? "red" : "ok") "\t" N + 0
      }' "$RMP_t/marks.txt" "$1" >> "$3/res"
  fi
}
rmp_reds() { awk -F '\t' '$2 == "red" { print $1 }' "$1" | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'; }   # the red checks of a res file
rmp_ins() {   # rmp_ins IN OUT SECTION LINE: copy IN with LINE as the first row of the table under "## SECTION"
  awk -v h="## $3" -v l="$4" '/^## / { t = $0 } { print } t == h && /^[|][-: |]+$/ && !d { print l; d = 1 }' "$1" > "$2"
}
rmp_app() {   # rmp_app IN OUT SECTION LINE: copy IN with LINE after the last row of the table under "## SECTION"
  awk -v h="## $3" -v l="$4" 'NR == FNR { if (/^## /) t = $0; if (t == h && /^[|]/) n = FNR; next } { print } FNR == n { print l }' "$1" "$1" > "$2"
}
rmp_del() {   # rmp_del IN OUT SECTION: copy IN without the first row of the table under "## SECTION"
  awk -v h="## $3" '/^## / { t = $0 } t == h && /^[|] `/ && !d { d = 1; next } { print }' "$1" > "$2"
}
rmp_dkey() {  # rmp_dkey IN OUT START: copy IN without the first line that starts with START
  awk -v k="$3" 'index($0, k) == 1 && !d { d = 1; next } { print }' "$1" > "$2"
}
rmp_sub() {   # rmp_sub IN OUT LINE OLD NEW: copy IN with the first OLD (a fixed string) on line LINE replaced by NEW
  awk -v n="$3" -v o="$4" -v w="$5" 'FNR == n + 0 && (i = index($0, o)) { $0 = substr($0, 1, i - 1) w substr($0, i + length(o)) } { print }' "$1" > "$2"
}
rmp_plant() { # rmp_plant LINE...: the planted drop-in rmp-probe.sh, its header lines and the given lines
  { printf '%s\n' '# SPDX-License-Identifier: GPL-3.0-or-later' '# shellcheck shell=sh'; printf '%s\n' "$@"; } > "$RMP_t/p/rmp-probe.sh"
}
rmp_probe() { # rmp_probe LABEL OWN MAP [planted]: judge MAP on the real drop-ins (and rmp-probe.sh); its red checks must be the real ones and OWN
  RMP_pn=$((RMP_pn + 1))
  if [ -z "${4:-}" ] && cmp -s "$3" docs/MAP.md; then RMP_pbad="$RMP_pbad;probe $1: not planted (the edit did not apply: has the form of docs/MAP.md changed?)"; return; fi
  rmp_table "$3" "$RMP_t/pt.txt"
  cp "$RMP_t/facts.txt" "$RMP_t/pf.txt"
  [ -z "${4:-}" ] || rmp_facts "$RMP_t/p/rmp-probe.sh" >> "$RMP_t/pf.txt"
  rm -rf "$RMP_t/j"; rmp_judge "$RMP_t/pt.txt" "$RMP_t/pf.txt" "$RMP_t/j"
  RMP_got=$(rmp_reds "$RMP_t/j/res")
  # shellcheck disable=SC2086   # word lists on purpose
  RMP_want=$(printf '%s\n' $RMP_real $2 | sed '/^$/d' | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//')
  [ "$RMP_got" = "$RMP_want" ] || RMP_pbad="$RMP_pbad;probe $1: red {$RMP_got}, want {$RMP_want}"
}
rmp_q() {     # rmp_q PROBE ARG...: tools/quick.sh of the planted tree with ARG...; STARCHORUS_PREFLIGHT_ONLY=PROBE; output RMP_t/qo.txt, status RMP_qrc
  RMP_po=$1; shift
  CHROME_BIN="$RMP_t/browser" STARCHORUS_ROOT="$RMP_t/q" STARCHORUS_PREFLIGHT_ONLY=$RMP_po sh "$RMP_t/q/tools/quick.sh" "$@" > "$RMP_t/qo.txt" 2>&1; RMP_qrc=$?
}
rmp_case() {  # rmp_case LABEL GOT WANT
  RMP_on=$((RMP_on + 1)); [ "$2" = "$3" ] || RMP_obad="$RMP_obad;$1: got {$2}, want {$3}"
}
rmp_aff() {   # rmp_aff ARG...: tools/affected.sh ARG...; output RMP_t/ao.txt, status RMP_arc, the names of its line drop-ins in RMP_ag
  sh tools/affected.sh "$@" > "$RMP_t/ao.txt" 2>&1; RMP_arc=$?
  RMP_ag=$(sed -n 's/^drop-ins: //p' "$RMP_t/ao.txt")
}
rmp_want() {  # rmp_want MAP WIDE PATH...: the drop-ins the paths reach, read here (a second reading of the rule of tools/affected.sh)
  RMP_x=$1; RMP_w=$2; shift 2
  rmp_table "$RMP_x" "$RMP_t/wt.txt"
  for RMP_f in tools/regress.d/*.sh; do [ -f "$RMP_f" ] && basename "$RMP_f" .sh; done > "$RMP_t/have.txt"
  printf '%s\n' "$@" | awk -v wide="$RMP_w" '
    BEGIN { FS = "\t" }
    function glob(g,    i, c, r) { r = "^"; for (i = 1; i <= length(g); i++) { c = substr(g, i, 1); r = r (c == "*" ? "[^/]*" : c == "." ? "[.]" : c) } return r "$" }
    function ingroup(w, p,    i) { for (i = 1; i <= GN[w]; i++) if (p ~ glob(GP[w, i])) return 1; return 0 }
    FILENAME == ARGV[1] {
      if ($1 == "group") GP[$3, ++GN[$3]] = $4
      if ($1 == "fragment") { f = $3; sub(/.*\//, "", f); sub(/\.[^.]*$/, "", f); FP[f] = $3; FA[$3] = 1 }
      if ($1 == "dropin") DN[++ND] = $3
      if ($1 == "subject") SS[$3, ++SC[$3]] = $4
      next
    }
    FILENAME == ARGV[2] { HAVE[$0] = 1; next }
    { P[++NP] = $0; if ($0 ~ /^src\//) SRC = 1 }
    END {
      for (i = 1; i <= NP; i++) {
        p = P[i]; if (p == "starchorus.html" && SRC) continue
        for (k = 1; k <= ND; k++) {
          d = DN[k]; if (!(d in HAVE)) continue
          h = (p == "tools/regress.d/" d ".sh") || ingroup("all", p)
          for (j = 1; !h && j <= SC[d]; j++) {
            s = SS[d, j]
            if (s in GN) h = ingroup(s, p); else if (s in FP) h = (FP[s] == p); else h = (p ~ glob(s))
            if (!h && wide == 1 && (p in FA) && s == "page") h = 1
          }
          if (h) print d
        }
      }
    }' "$RMP_t/wt.txt" "$RMP_t/have.txt" - | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//'
}

RMP_t=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-repomap.XXXXXX") || RMP_t=""
if [ -z "$RMP_t" ]; then
  row "repo map: a temporary directory (mktemp)" FAIL
else
  RMP_cre=$(sed -n "s/^QUICK_CHROME_RE='\(.*\)'\$/\1/p" tools/static.sh); RMP_creok=0; [ -z "$RMP_cre" ] || RMP_creok=1
  # the files of the repository: git's view where the root is a git work tree, else a walk (the rule of listing() in tools/doc-truth.py)
  if [ "$(git -C "$R" rev-parse --show-toplevel 2> /dev/null)" = "$R" ]; then
    git -C "$R" -c core.quotePath=false ls-files -co --exclude-standard | while IFS= read -r RMP_f; do [ -f "$RMP_f" ] && printf '%s\n' "$RMP_f"; done
  else
    find . \( -name .git -o -name out -o -name __pycache__ \) -prune -o -type f -print | sed 's,^[.]/,,'
  fi | LC_ALL=C sort -u > "$RMP_t/u.txt"
  rmp_facts tools/regress.d/*.sh > "$RMP_t/facts.txt"
  rmp_table docs/MAP.md "$RMP_t/table.txt"
  rmp_marks "$RMP_t/table.txt" > "$RMP_t/marks.txt"
  rmp_judge "$RMP_t/table.txt" "$RMP_t/facts.txt" "$RMP_t/real"
  cp "$RMP_t/table.txt" "out/$P-rmp-table.txt"; cp "$RMP_t/facts.txt" "out/$P-rmp-facts.txt"

  # ---- one row per check of the real map; what to adjust stands below a red row
  for RMP_c in 1 2 3 4 5 6 7 8 9 10 11 12; do
    RMP_n=$(awk -F '\t' -v c="C$RMP_c" '$1 == c { print $3 }' "$RMP_t/real/res")
    case $RMP_c in
      1) RMP_l="docs/MAP.md parses into its tables ($RMP_n rows)" ;;
      2) RMP_l="page fragments = src/PAGE.list, in build order ($RMP_n)" ;;
      3) RMP_l="regions = the marker lines of the scripts, in order ($RMP_n scripts)" ;;
      4) RMP_l="every script, tool and document has a row ($RMP_n)" ;;
      5) RMP_l="drop-ins = tools/regress.d, each with a subject ($RMP_n)" ;;
      6) RMP_l="every subject is a group, a fragment or a file ($RMP_n)" ;;
      7) RMP_l="every path the map names exists ($RMP_n)" ;;
      8) RMP_l="every anchor occurs in its file ($RMP_n)" ;;
      9) RMP_l="region anchors lie inside their regions ($RMP_n)" ;;
      10) RMP_l="section slices name their fragments ($RMP_n)" ;;
      11) RMP_l="drop-ins that run Chrome or read the page name page ($RMP_n)" ;;
      *) RMP_l="files a drop-in names are among its subjects ($RMP_n)" ;;
    esac
    if grep -q "^C$RMP_c	ok	" "$RMP_t/real/res"; then row "repo map: $RMP_l" PASS; else row "repo map: $RMP_l" FAIL; fi
    awk -F '\t' -v c="C$RMP_c" '$1 == c { print "    " substr($2, 1, 192) }' "$RMP_t/real/ev" | head -n 12
  done

  # ---- the checks bite. Each planted copy breaks one thing; its red checks are the real ones and exactly its own.
  RMP_pn=0; RMP_pbad=""; RMP_real=$(rmp_reds "$RMP_t/real/res"); mkdir -p "$RMP_t/p"; RMP_m=docs/MAP.md; RMP_pm="$RMP_t/pm.md"
  rmp_app "$RMP_m" "$RMP_pm" "Documentation places" '| `rmp` |'; rmp_probe parse C1 "$RMP_pm"; cp "$RMP_pm" "$RMP_t/badmap.md"
  RMP_x=$(sed -n '$p' src/PAGE.list); RMP_y=$(basename "$RMP_x"); RMP_y=${RMP_y%.*}; RMP_o=C2
  awk -F '\t' -v y="$RMP_y" '$1 == "subject" && $4 == y { f = 1 } END { exit !f }' "$RMP_t/table.txt" && RMP_o="C2 C6"
  rmp_dkey "$RMP_m" "$RMP_pm" "| \`src/$RMP_x\` |"; rmp_probe fragment "$RMP_o" "$RMP_pm"
  rmp_del "$RMP_m" "$RMP_pm" Regions; rmp_probe region C3 "$RMP_pm"
  rmp_del "$RMP_m" "$RMP_pm" Tools; rmp_probe tool-row C4 "$RMP_pm"
  rmp_del "$RMP_m" "$RMP_pm" Documents; rmp_probe document-row C4 "$RMP_pm"
  rmp_ins "$RMP_m" "$RMP_pm" Drop-ins '| `rmp-gone` | `page` |'; rmp_probe dropin-gone C5 "$RMP_pm"
  rmp_plant ': planted'; rmp_probe dropin-norow C5 "$RMP_m" planted
  rmp_ins "$RMP_m" "$RMP_pm" Drop-ins '| `rmp-probe` | `page` `rmp-undefined` |'; rmp_probe subject C6 "$RMP_pm" planted
  { cat "$RMP_m"; printf '%s\n' '`docs/rmp-absent.md`'; } > "$RMP_pm"; rmp_probe path C7 "$RMP_pm"
  RMP_x=$(awk -F '\t' '$1 == "anchor" && $3 ~ /^src\// { print $2 "\t" $4; exit }' "$RMP_t/table.txt")
  rmp_sub "$RMP_m" "$RMP_pm" "${RMP_x%%	*}" "\`${RMP_x#*	}\`" "\`${RMP_x#*	}rmp-absent\`"; rmp_probe anchor C8 "$RMP_pm"
  RMP_x=$(awk -F '\t' '$1 == "region" && ++n <= 2 { L[n] = $2; S[n] = $3 } $1 == "ranchor" && n <= 2 && !(($2) in A) { A[$2] = $4 }
    END { if (S[1] == S[2] && (L[1] in A) && (L[2] in A)) print L[2] "\t" A[L[2]] "\t" A[L[1]] }' "$RMP_t/table.txt")
  RMP_y=${RMP_x#*	}; rmp_sub "$RMP_m" "$RMP_pm" "${RMP_x%%	*}" "\`${RMP_y%%	*}\`" "\`${RMP_y#*	}\`"; rmp_probe span C9 "$RMP_pm"
  rmp_ins "$RMP_m" "$RMP_t/pp.md" Drop-ins '| `rmp-probe` | `page` |'; rmp_ins "$RMP_m" "$RMP_t/pf.md" Drop-ins '| `rmp-probe` | `fixtures` |'
  rmp_plant ': planted'; rmp_probe control "" "$RMP_t/pp.md" planted
  RMP_s1=$(awk -F '\t' '$1 == "fragment" { f = $3; sub(/.*\//, "", f); if (f ~ /^[0-9][0-9]-/ && ++n <= 2) printf "%s ", substr(f, 1, 2) }' "$RMP_t/table.txt")
  RMP_s2=${RMP_s1#* }; RMP_s2=${RMP_s2%% *}; RMP_s1=${RMP_s1%% *}
  rmp_plant "$(printf ': "$(sec_slice %s %s)"' "$RMP_s1" "$RMP_s2")"; rmp_probe slice C10 "$RMP_t/pp.md" planted
  rmp_plant 'rmp_w() { sec_grepc "$1" "$2" 1 x; }' "$(printf ': "$(rmp_w %s %s)"' "$RMP_s1" "$RMP_s2")"; rmp_probe wrapper C10 "$RMP_t/pp.md" planted
  rmp_plant "$(printf ': "$(awk %s/==== %s x/,/==== %s x/%s f)"' "'" "$RMP_s1" "$RMP_s2" "'")"; rmp_probe range C10 "$RMP_t/pp.md" planted
  rmp_plant ": $(printf '%s\n' "${RMP_cre%%|*}" | tr -d '\134')"; rmp_probe chrome C11 "$RMP_t/pf.md" planted
  RMP_d='$'; rmp_plant "$(printf ': "%sH"' "$RMP_d")"; rmp_probe page-var C11 "$RMP_t/pf.md" planted
  rmp_plant "$(printf ': "%sF"' "$RMP_d")"; rmp_probe fixture-var C12 "$RMP_t/pp.md" planted
  awk -F '\t' '$1 == "group" && $3 == "page" { print $4 }' "$RMP_t/table.txt" > "$RMP_t/pagepats.txt"
  RMP_x=$(grep '^tools/[^/]*[.]py$' "$RMP_t/u.txt" | grep -vE "${RMP_cre:-^$}" | grep -vxF -f "$RMP_t/pagepats.txt" | sed -n 1p)
  rmp_plant ": $RMP_x"; rmp_probe file C12 "$RMP_t/pp.md" planted
  rowif "repo map probes bite ($RMP_pn planted copies, each red exactly where expected)" [ -z "$RMP_pbad" ]
  [ -z "$RMP_pbad" ] || printf '%s\n' "${RMP_pbad#;}" | tr ';' '\n' | cut -c1-192 | sed 's/^/    /'

  # ---- tools/quick.sh in a planted tree (copies of the runner and its helpers, planted drop-ins, a stand-in browser)
  RMP_q="$RMP_t/q"; mkdir -p "$RMP_q/tools/regress.d" "$RMP_q/library"
  cp tools/harness.sh tools/quick.sh tools/static.sh "$RMP_q/tools/"; cp tools/*.py "$RMP_q/tools/"; : > "$RMP_q/starchorus.html"
  printf '%s\n' '#!/bin/sh' 'exit 0' > "$RMP_t/browser"; chmod +x "$RMP_t/browser"
  RMP_dl=$(sed -n 's/^ *QUICK_DOCS_DROPINS="\(.*\)"$/\1/p' tools/quick.sh)
  for RMP_x in $RMP_dl; do
    printf '%s\n' '# SPDX-License-Identifier: GPL-3.0-or-later' '# shellcheck shell=sh' "row \"repo map planted $RMP_x\" PASS" > "$RMP_q/tools/regress.d/$RMP_x.sh"
  done
  RMP_x=$(sed -n -E 's/^((MIN|MAX|BASE)_[A-Z0-9_]+)=[0-9]+.*/\1/p' tools/static.sh | sed -n 1p)
  printf '%s\n' '# SPDX-License-Identifier: GPL-3.0-or-later' '# shellcheck shell=sh' \
    "if [ -n \"\${$RMP_x:-}\" ] && [ \"\${STATIC_SELFTEST:-1}\" = 0 ]; then row \"repo map planted rmp-ok\" PASS; else row \"repo map planted rmp-ok\" FAIL; fi" \
    > "$RMP_q/tools/regress.d/rmp-ok.sh"
  printf '%s\n' '# SPDX-License-Identifier: GPL-3.0-or-later' '# shellcheck shell=sh' 'notcov "repo map planted rmp-zero"' > "$RMP_q/tools/regress.d/rmp-zero.sh"
  RMP_on=0; RMP_obad=""
  rmp_q 0 only --prefix qo1 rmp-ok
  rmp_case alone "$RMP_qrc/$(grep -c '^quick only drop-in rmp-ok ran (1 rows) *PASS$' "$RMP_t/qo.txt")/$(grep -c '^repo map planted rmp-ok *PASS$' "$RMP_t/qo.txt")/$(grep -c '^drop-ins mode: the shell-file lists are written as tools/static.sh writes them PASS$' "$RMP_t/qo.txt")/$(tail -n 1 "$RMP_t/qo.txt" | grep -cE '^quick only: [0-9]+ PASS, 0 FAIL, 0 NOT COVERED, [0-9]+ s$')/$(grep -cE '^quick( docs)?: ' "$RMP_t/qo.txt")" "0/1/1/1/1/0"
  rmp_q 0 only --prefix qo2 rmp-ok rmp-ok rmp-zero
  rmp_case twice "$RMP_qrc/$(grep -c '^quick only drop-in rmp-ok ran (' "$RMP_t/qo.txt")/$(grep -c '^quick only drop-in rmp-zero ran (0 rows) *FAIL$' "$RMP_t/qo.txt")/$(tail -n 1 "$RMP_t/qo.txt" | grep -cE '^quick only: [0-9]+ PASS, 1 FAIL, 1 NOT COVERED, [0-9]+ s$')" "1/1/1/1"
  for RMP_x in "unknown:rmp-none" "name:../rmp-ok" "empty:" "prefix:--prefix a/b rmp-ok"; do
    # shellcheck disable=SC2086   # the arguments are a word list on purpose
    rmp_q 0 only ${RMP_x#*:}
    rmp_case "${RMP_x%%:*}" "$RMP_qrc/$(grep -cE ' (PASS|FAIL)$' "$RMP_t/qo.txt")/$(grep -c '^quick only: ' "$RMP_t/qo.txt")" "2/0/1"
  done
  rmp_q 1 only rmp-ok; rmp_case probe "$RMP_qrc/$(cat "$RMP_t/qo.txt")" "0/preflight: ok (T1, drop-ins mode)"
  rmp_q 1; rmp_case t1-probe "$RMP_qrc/$(cat "$RMP_t/qo.txt")" "0/preflight: ok (T1)"
  rowif "repo map: quick.sh only runs the named drop-ins alone ($RMP_on cases)" [ -z "$RMP_obad" ]
  [ -z "$RMP_obad" ] || printf '%s\n' "${RMP_obad#;}" | tr ';' '\n' | cut -c1-192 | sed 's/^/    /'
  RMP_on=0; RMP_obad=""
  rmp_q 0 docs qd1
  RMP_x=0; for RMP_y in $RMP_dl; do RMP_x=$((RMP_x + 1)); done
  { printf '%-44s %s\n' "documents mode: the shell-file lists are written as tools/static.sh writes them" PASS
    for RMP_y in $RMP_dl; do printf '%-44s %s\n' "repo map planted $RMP_y" PASS "quick docs drop-in $RMP_y ran (1 rows)" PASS; done
    printf 'quick docs: %s PASS, 0 FAIL, T s\n' $((2 * RMP_x + 1)); } > "$RMP_t/qd-want.txt"
  sed -E 's/, [0-9]+ s$/, T s/' "$RMP_t/qo.txt" > "$RMP_t/qd-got.txt"
  rmp_case output "$RMP_qrc/$(cmp -s "$RMP_t/qd-got.txt" "$RMP_t/qd-want.txt" && echo same)" "0/same"
  rmp_case files "$(for RMP_y in "$RMP_q"/out/qd1-*; do basename "$RMP_y"; done | tr '\n' ' ')" "qd1-quick.txt qd1-rowfns.sh qd1-shfiles-tools.txt qd1-shfiles.txt qd1-timing.txt "
  rmp_case timing "$(sed -E 's/ +[0-9]+ s$//' "$RMP_q/out/qd1-timing.txt" | tr '\n' '/')" "phase file lists/$(for RMP_y in $RMP_dl; do printf 'drop-in %s/' "$RMP_y"; done)total/"
  rmp_q 1 docs; rmp_case probe "$RMP_qrc/$(cat "$RMP_t/qo.txt")" "0/preflight: ok (T1, documents mode)"
  rowif "repo map: the documents mode prints what it printed, byte for byte ($RMP_on cases)" [ -z "$RMP_obad" ]
  [ -z "$RMP_obad" ] || printf '%s\n' "${RMP_obad#;}" | tr ';' '\n' | cut -c1-192 | sed 's/^/    /'

  # ---- tools/affected.sh against a second reading of the map here
  RMP_on=0; RMP_obad=""
  RMP_x=$(awk -F '\t' '$1 == "dropin" { print $3 }' "$RMP_t/table.txt" | while IFS= read -r RMP_y; do [ -f "tools/regress.d/$RMP_y.sh" ] && { echo "$RMP_y"; break; }; done)
  rmp_aff "tools/regress.d/$RMP_x.sh"; rmp_case own "$RMP_arc/$(printf ' %s ' "$RMP_ag" | grep -c " $RMP_x ")" "0/1"
  RMP_g=$(awk -F '\t' '$1 == "group" { n[$3]++; p[$3] = $4; if (!($3 in o)) o[$3] = ++k }
    END { for (w in o) if (w != "all" && n[w] == 1 && index(p[w], "*") == 0 && (b == "" || o[w] < o[b])) b = w; print b "\t" p[b] }' "$RMP_t/table.txt")
  RMP_gp=${RMP_g#*	}; RMP_g=${RMP_g%%	*}
  rmp_aff "$RMP_gp"; rmp_case group "$RMP_arc/$RMP_ag" "0/$(rmp_want docs/MAP.md 0 "$RMP_gp")"
  RMP_f=$(awk -F '\t' '$1 == "fragment" { f = $3; sub(/.*\//, "", f); sub(/\.[^.]*$/, "", f); P[f] = $3; o[++k] = f } $1 == "subject" { c[$4]++ }
    END { for (i = 1; i <= k; i++) if (c[o[i]] > m) { m = c[o[i]]; b = P[o[i]] } print b }' "$RMP_t/table.txt")
  rmp_aff "$RMP_f" starchorus.html
  rmp_case fragment "$RMP_arc/$RMP_ag/$(grep -c '^path: starchorus.html (page): left out' "$RMP_t/ao.txt")" "0/$(rmp_want docs/MAP.md 0 "$RMP_f" starchorus.html)/1"
  rmp_aff --wide "$RMP_f"; rmp_case wide "$RMP_arc/$RMP_ag" "0/$(rmp_want docs/MAP.md 1 "$RMP_f")"
  RMP_x=$(awk -F '\t' '$1 == "group" && $3 == "all" { print $4; exit }' "$RMP_t/table.txt")
  rmp_aff "$RMP_x"; rmp_case all "$RMP_arc/$RMP_ag" "0/$(rmp_want docs/MAP.md 0 "$RMP_x")"
  rmp_aff rmp/absent; rmp_case none "$RMP_arc/$RMP_ag/$(tail -n 1 "$RMP_t/ao.txt" | grep -c '^gate: the full run, sh tools/regress.sh')" "0/(none)/1"
  # a planted map without the group in the first row that names it: that drop-in leaves the answer
  RMP_x=$(awk -F '\t' -v g="$RMP_g" '$1 == "subject" && $4 == g { print $2; exit }' "$RMP_t/table.txt")
  rmp_sub "$RMP_m" "$RMP_pm" "$RMP_x" " \`$RMP_g\`" ""
  RMP_x=$(rmp_want "$RMP_pm" 0 "$RMP_gp"); RMP_y=$(rmp_want docs/MAP.md 0 "$RMP_gp")
  rmp_aff --map "$RMP_pm" "$RMP_gp"; rmp_case planted "$RMP_arc/$RMP_ag" "0/$RMP_x"
  rmp_case planted-differs "$([ "$RMP_x" != "$RMP_y" ] && echo yes)" yes
  rmp_aff --map "$RMP_t/absent.md" x; rmp_case no-map "$RMP_arc" 2
  rmp_aff --map "$RMP_t/badmap.md" x; rmp_case bad-map "$RMP_arc" 2
  rmp_aff --rmp-unknown; rmp_case option "$RMP_arc" 2
  rowif "repo map: affected.sh answers by the map ($RMP_on cases)" [ -z "$RMP_obad" ]
  [ -z "$RMP_obad" ] || printf '%s\n' "${RMP_obad#;}" | tr ';' '\n' | cut -c1-192 | sed 's/^/    /'
  rm -rf "$RMP_t"
fi
unset -f rmp_table rmp_facts rmp_marks rmp_judge rmp_reds rmp_ins rmp_app rmp_del rmp_dkey rmp_sub rmp_plant rmp_probe rmp_q rmp_case rmp_aff rmp_want
