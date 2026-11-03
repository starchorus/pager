#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/affected.sh -- which drop-ins a change reaches, read from the repository map (docs/MAP.md). A help for work in pieces, no gate.
# usage: sh tools/affected.sh [--map FILE] [--wide] [--run] [--] [PATH...]
#        sh tools/affected.sh [--map FILE] --table
#   PATH...   paths from the top of the repository (a leading ./ or the repository's own path is dropped); none: what git sees changed
#             against HEAD, in the working tree and in the index, and the untracked files that are not ignored
#   --wide    for a page fragment, also every drop-in that names page (those see every fragment)
#   --run     then run the drop-ins alone: sh tools/quick.sh only NAME...
#   --table   print the map as records, one per line: KIND, LINE, KEY, ITEM separated by TABs (tools/regress.d/repo-map.sh reads them)
# What a changed path reaches is the rule of the Groups paragraph of docs/MAP.md, applied here; the grammar of the map is its section
# 'Editing this map'. For a fragment the answer is narrow (the drop-ins that name it), and a line counts the drop-ins that run the whole
# page, which --wide adds. The full run, sh tools/regress.sh PREFIX, is the gate before a push or a release; the last line says so.
# exit 0 = printed (with --run: the exit status of quick.sh), 2 = setup (an unknown option, a map that is missing or does not parse,
# no paths and no git work tree, a missing tool). Dev machine only; nothing here runs on the device or sends anything.
# shellcheck source-path=SCRIPTDIR source=harness.sh
. "$(dirname "$0")/harness.sh" || exit 2
AF_map=""; AF_wide=0; AF_run=0; AF_table=0
while [ "$#" -gt 0 ]; do
  case $1 in
    --map) [ "$#" -ge 2 ] || { echo "affected: --map wants a file" >&2; exit 2; }; AF_map=$2; shift 2 ;;
    --wide) AF_wide=1; shift ;;
    --run) AF_run=1; shift ;;
    --table) AF_table=1; shift ;;
    --) shift; break ;;
    -*) echo "affected: unknown option $1 (the head of tools/affected.sh lists them)" >&2; exit 2 ;;
    *) break ;;
  esac
done
preflight awk sed sort || exit 2
[ -n "$AF_map" ] || AF_map="$R/docs/MAP.md"
[ -r "$AF_map" ] || { echo "affected: no map at $AF_map" >&2; exit 2; }
# The one reading of the map's grammar: KIND TAB LINE TAB KEY TAB ITEM per record (docs/MAP.md, 'Editing this map').
af_table() {
  awk '
    function out(k, l, key, item) { printf "%s\t%s\t%s\t%s\n", k, l, key, item }
    function bad(l, why) { out("bad", l, "-", why) }
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    # split a column of code spans into a[1..n]; -1 when anything but spans separated by one blank stands in it
    function spans(cell, a,    n, s) {
      n = 0
      while (cell != "") {
        if (!match(cell, /^`[^`]+`/)) return -1
        s = substr(cell, 2, RLENGTH - 2)
        if (s ~ /^[ \t]/ || s ~ /[ \t]$/ || index(s, "\t") || index(s, "|") || index(s, "\\")) return -1
        a[++n] = s
        cell = substr(cell, RLENGTH + 1)
        if (cell == "") break
        if (substr(cell, 1, 1) != " " || substr(cell, 2, 1) != "`") return -1
        cell = substr(cell, 2)
      }
      return n
    }
    function prose(text, l,    s) {
      while (match(text, /`[^`]*`/)) {
        s = substr(text, RSTART + 1, RLENGTH - 2)
        if (s != "") out("prose", l, "-", s)
        text = substr(text, RSTART + RLENGTH)
      }
    }
    function fragname(p,    s) { s = p; sub(/.*\//, "", s); sub(/\.[^.]*$/, "", s); return s }
    function one(cell, l, what,    a, n) {
      n = spans(cell, a)
      if (n != 1) { bad(l, what " is one code span"); return "" }
      return a[1]
    }
    function anchors(cell, l, kind, file,    a, n, i) {
      n = spans(cell, a)
      if (n < 0) { bad(l, "the anchors are code spans, one blank apart"); return -1 }
      for (i = 1; i <= n; i++) out(kind, l, file, a[i])
      return n
    }
    function row(sec, line, l,    c, n, i, cell, k, t, a, na, kind) {
      t = line
      if (gsub(/`/, "`", t) % 2) { bad(l, "an odd number of backticks"); return }
      n = split(line, c, "|")
      if (c[1] != "" || c[n] !~ /^[ \t]*$/) { bad(l, "a row starts and ends with a vertical bar"); return }
      if (n - 2 != ncol[sec]) { bad(l, (n - 2) " cells, the table " sec " has " ncol[sec]); return }
      for (i = 2; i < n; i++) cell[i - 1] = trim(c[i])
      if (sec == "Documentation places") {
        prose(cell[1], l); prose(cell[4], l)
        k = one(cell[2], l, "the place"); if (k == "") return
        out("place", l, k, "-"); anchors(cell[3], l, "anchor", k); return
      }
      k = one(cell[1], l, "the first cell"); if (k == "") return
      if (sec == "Groups") {
        if (k !~ /^[a-z][a-z0-9-]*$/) { bad(l, "a group is a word of a-z, 0-9 and -"); return }
        if (k in gseen) { bad(l, "group " k " twice"); return }
        gseen[k] = l
        na = spans(cell[2], a)
        if (na < 1) { bad(l, "a group names one or more paths, code spans one blank apart"); return }
        for (i = 1; i <= na; i++) out("group", l, k, a[i])
        return
      }
      if (sec == "Regions") {
        t = one(cell[2], l, "the region"); if (t == "") return
        if ((k SUBSEP t) in rseen) { bad(l, "region " t " of " k " twice"); return }
        rseen[k SUBSEP t] = 1
        out("region", l, k, t); anchors(cell[3], l, "ranchor", k); return
      }
      if (sec == "Drop-ins") {
        if (k !~ /^[a-z0-9][a-z0-9-]*$/) { bad(l, "a drop-in is a name of a-z, 0-9 and -"); return }
        if (k in dseen) { bad(l, "drop-in " k " twice"); return }
        dseen[k] = 1
        na = spans(cell[2], a)
        if (na < 0) { bad(l, "the subjects are code spans, one blank apart"); return }
        out("dropin", l, k, "-")
        for (i = 1; i <= na; i++) out("subject", l, k, a[i])
        return
      }
      kind = (sec == "Page fragments") ? "fragment" : (sec == "Scripts") ? "script" : (sec == "Tools") ? "tool" : "document"
      if ((kind SUBSEP k) in kseen) { bad(l, kind " " k " twice"); return }
      kseen[kind SUBSEP k] = 1
      if (kind == "tool" && k ~ /\/$/ && cell[2] != "") { bad(l, "a directory has no anchors"); return }
      out(kind, l, k, "-"); anchors(cell[2], l, "anchor", k)
      if (kind == "fragment") { fname[fragname(k)] = 1 }
    }
    BEGIN {
      ncol["Groups"] = 2; ncol["Page fragments"] = 2; ncol["Scripts"] = 2; ncol["Regions"] = 3
      ncol["Tools"] = 2; ncol["Drop-ins"] = 2; ncol["Documents"] = 2; ncol["Documentation places"] = 4
      sec = ""; st = ""
    }
    /^(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^## / {
      if (st == "intro" || st == "sep") bad(NR, "no table under ## " sec)
      sec = substr($0, 4); st = ""
      if (sec in ncol) { seen[sec]++; if (seen[sec] > 1) bad(NR, "## " sec " twice"); else { out("table", NR, sec, "-"); st = "intro" } }
      else sec = ""
      next
    }
    st == "intro" && /^\|/ {
      t = $0; nh = split(t, hc, "|")
      if (nh - 2 != ncol[sec]) bad(NR, "the header of " sec " has " (nh - 2) " cells, the table has " ncol[sec])
      st = "sep"; next
    }
    st == "sep" { if ($0 !~ /^\|[-: |]+$/) bad(NR, "the line under the header of " sec " is its separator"); st = "rows"; next }
    st == "rows" && /^\|/ { row(sec, $0, NR); next }
    st == "rows" { st = "after" }
    st == "after" && /^\|/ { bad(NR, "a second table under ## " sec); next }
    { t = $0; if (gsub(/`/, "`", t) % 2) bad(NR, "an odd number of backticks"); else prose($0, NR) }
    END {
      if (st == "intro" || st == "sep") bad(NR, "no table under ## " sec)
      for (s in ncol) if (!(s in seen)) bad(0, "no section ## " s)
      split("page fixtures all", need, " ")
      for (i = 1; i <= 3; i++) if (!(need[i] in gseen)) bad(0, "no group " need[i] " (the tools read it)")
      for (g in gseen) if (g in fname) bad(gseen[g], "group " g " is also the name of a fragment")
    }
  ' "$1"
}
if [ "$AF_table" = 1 ]; then af_table "$AF_map"; exit 0; fi
AF_t=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-affected.XXXXXX") || exit 2
af_table "$AF_map" > "$AF_t/table.txt"
AF_bad=$(awk -F '\t' '$1 == "bad" { print "line " $2 ": " $4; exit }' "$AF_t/table.txt")
if [ -n "$AF_bad" ]; then
  echo "affected: $AF_map does not parse ($AF_bad); sh tools/quick.sh only repo-map says more" >&2; rm -rf "$AF_t"; exit 2
fi
if [ "$#" -gt 0 ]; then
  for AF_p in "$@"; do case $AF_p in "$R"/*) AF_p=${AF_p#"$R"/} ;; ./*) AF_p=${AF_p#./} ;; esac; printf '%s\n' "$AF_p"; done > "$AF_t/raw.txt"
else
  preflight git || { rm -rf "$AF_t"; exit 2; }
  [ "$(git -C "$R" rev-parse --show-toplevel 2> /dev/null)" = "$R" ] \
    || { echo "affected: no paths given, and $R is not the top of a git work tree" >&2; rm -rf "$AF_t"; exit 2; }
  { git -C "$R" -c core.quotePath=false diff --name-only --no-renames HEAD 2> /dev/null
    git -C "$R" -c core.quotePath=false diff --name-only --no-renames --cached
    git -C "$R" -c core.quotePath=false ls-files --others --exclude-standard; } > "$AF_t/raw.txt"
fi
sed '/^$/d' "$AF_t/raw.txt" | LC_ALL=C sort -u > "$AF_t/paths.txt"
for AF_p in "$R"/tools/regress.d/*.sh; do [ -f "$AF_p" ] && basename "$AF_p" .sh; done > "$AF_t/have.txt"
LC_ALL=C awk -v wide="$AF_wide" -v run="$AF_run" '
  BEGIN { FS = "\t" }
  function glob(g,    i, c, r) {
    r = "^"
    for (i = 1; i <= length(g); i++) { c = substr(g, i, 1); r = r (c == "*" ? "[^/]*" : c == "." ? "[.]" : c) }
    return r "$"
  }
  function ingroup(w, p,    i) { for (i = 1; i <= gn[w]; i++) if (p ~ glob(gp[w, i])) return 1; return 0 }
  function sorted(a, n,    i, j, t, s) {
    for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t }
    s = ""; for (i = 1; i <= n; i++) s = s (s == "" ? "" : " ") a[i]
    return s
  }
  FILENAME == ARGV[1] {
    if ($1 == "group") { if (!(($3) in gn)) gw[++ngw] = $3; gp[$3, ++gn[$3]] = $4 }
    else if ($1 == "fragment") { f = $3; sub(/.*\//, "", f); sub(/\.[^.]*$/, "", f); fpath[f] = $3; fname[$3] = f }
    else if ($1 == "dropin") { dn[++nd] = $3 }
    else if ($1 == "subject") { ds[$3, ++dc[$3]] = $4 }
    next
  }
  FILENAME == ARGV[2] { have[$0] = 1; next }
  { P[++np] = $0; if ($0 ~ /^src\//) src = 1 }
  END {
    for (k = 1; k <= np; k++) {
      p = P[k]
      if (p == "starchorus.html" && src) { print "path: " p " (page): left out: the page is the build of the src/ paths in this list"; continue }
      subj = ""; if (p in fname) { subj = fname[p]; nfr++ }
      for (i = 1; i <= ngw; i++) if (gw[i] != "all" && ingroup(gw[i], p)) subj = subj (subj == "" ? "" : " ") gw[i]
      if (ingroup("all", p)) {
        for (i = 1; i <= nd; i++) if (dn[i] in have) sel[dn[i]] = 1
        print "path: " p " (all): every drop-in"; continue
      }
      m = 0; split("", hit)
      for (i = 1; i <= nd; i++) {
        d = dn[i]; if (!(d in have)) continue
        h = (p == "tools/regress.d/" d ".sh")
        for (j = 1; !h && j <= dc[d]; j++) {
          s = ds[d, j]
          if (s in gn) h = ingroup(s, p)
          else if (s in fpath) h = (fpath[s] == p)
          else h = (p ~ glob(s))
          if (!h && wide && (p in fname) && s == "page") h = 1
        }
        if (h) { hit[++m] = d; sel[d] = 1 }
      }
      print "path: " p " (" (subj == "" ? "-" : subj) "): " (m ? sorted(hit, m) : "named by no drop-in")
    }
    m = 0; split("", all); for (d in sel) all[++m] = d
    if (np == 0) print "path: (none): nothing differs from HEAD"
    if (nfr && !wide) {
      w = 0
      for (i = 1; i <= nd; i++) { d = dn[i]; if (!(d in have) || (d in sel)) continue; for (j = 1; j <= dc[d]; j++) if (ds[d, j] == "page") { w++; break } }
      if (w) print "wide: " w " more drop-ins run the whole page and so see every fragment; --wide adds them"
    }
    print "drop-ins: " (m ? sorted(all, m) : "(none)")
    if (m) print "run: sh tools/quick.sh only " sorted(all, m)
    else if (run) print "run: nothing to run alone"
    print "gate: the full run, sh tools/regress.sh PREFIX, remains the gate before a push or a release; this list only says where to start"
  }
' "$AF_t/table.txt" "$AF_t/have.txt" "$AF_t/paths.txt" > "$AF_t/out.txt"
AF_go=$(sed -n 's/^drop-ins: //p' "$AF_t/out.txt"); [ "$AF_go" != "(none)" ] || AF_go=""
cat "$AF_t/out.txt"
rm -rf "$AF_t"
[ "$AF_run" = 1 ] && [ -n "$AF_go" ] || exit 0
# shellcheck disable=SC2086   # the names are a word list on purpose
exec sh "$R/tools/quick.sh" only $AF_go
