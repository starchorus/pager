#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""tools/doc-truth.py -- lists and numbers that were typed by hand, derived from their source instead.

usage: python3 -B tools/doc-truth.py CHECK [--root DIR] [options]      (any cwd; python3 stdlib only; reads files, writes nothing)
  one label line on stdout; exit 0 = the check holds, 1 = it does not (indented detail lines follow), 2 = setup problem.
CHECKS
  lists     --list FILE... --exception GLOB=REASON...   every shell file of the repository (git ls-files, or a walk where there is
            no git work tree) is in the union of the list files or covered by a reasoned exception; every listed file exists; every
            exception matches a shell file that is NOT listed (otherwise: stale, "please remove"); a floor keeps an empty listing
            from passing.
  sources   the "source" values tools/gen-testdata.py knows (SOURCES) = the ones starchorus-collect.sh emits (awk -v src="..." and the
            printf "source": "..." outside selftest()), both directions.
  census    --no-fixture NAME=REASON...   every SOURCES value occurs in >= 1 fixture or is listed (and a listed one has none).
  fixtures  the fixture table of tools/README.md: every fixture has a row, every row a fixture, and the sizes the row states
            (APs, APs with clients[], free clients, band split, source, the active.json generator call) are the measured ones.
  prose     no hand-typed check counts ("N PASS", "N checks/checkpoints/cases", "N tests/assertions", "N green") in the prose
            documents; a version number after a collector/display script name ("collector 1.3", "Collector: 1.2", "starchorus-collect.sh 1.2 delivers",
            a table cell "| starchorus-collect.sh | 1.2 |") must be the version of the script header (older and newer numbers are red;
            "since/until/up to/from/first/>=" and lines with "as of" say when, not what is current). Markdown decoration (backticks, **bold**, _italics_,
            no-break spaces) is removed before reading; a claim wrapped over one line end is read on the line where it starts.
  runlist   the run list of docs/architecture.md §11.0 = the fixture loop of tools/regress.sh (names, order, count).
  headers   the "# Version:" header of every script that carries one (collector, display script and its library copy, serve script,
            both payload.sh) is the page version (`version: "x.y.z"` in starchorus.html): one project, one version number.
  contract  [--want N]   the "# Contract:" header of the four scripts that carry one (collector, display script and its library copy,
            the library payload.sh) is one number, and N where --want is given (the radio pair's interface number is 3).
GUARDS AGAINST: a list or number that is copied by hand goes stale without any row noticing (a new shell script in no shell list; a
                README that names a check count the selftest no longer has; a doc that names a collector version other than the current one).
NEGATIVE PROBE: tools/regress.d/doc-truth.sh breaks one input per check in a copy (rename a source literal, a wrong count, a header
                bump, an unlisted script, ...) and demands red; the same check on the real tree must be green.
NOT PROVEN:     a mention is not a proof that the text around it is true (headers vs. the page binds a number, not a sentence);
                prose that says a thing in words is not checked (a count spelled out, "forty-two", or a version more than 40
                characters after the name, or a claim wrapped over more than one line end, is not seen; HTML other than &nbsp; is not decoded); a fixture row's numbers other than those named above are not read; a row whose
                APs / free clients / clients[] / GHz split / source are stated in a form the patterns do not read is red, not skipped.
Dev machine only; nothing here sends anything or runs a script of the repository.
"""
import argparse
import ast
import fnmatch
import glob
import json
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True   # no __pycache__ in the work tree

MIN_SHELL_FILES = 27   # shell files the listing must find (about 80 %); measure: git ls-files '*.sh' | wc -l   (measured: 56)
MIN_MD_FILES = 5       # prose documents the prose check reads
MIN_FIXTURE_ROWS = 13  # rows of the fixture table; measure: ls tests/fixtures/*.json | wc -l   (measured: 13)
MIN_CLAIMS = 20        # stated sizes the fixtures check compares; measure: the count in its label line (measured: 39); each row also has to state what the file has (see chk_fixtures)


def rd(root, rel):
    with open(os.path.join(root, rel), encoding="utf-8", errors="surrogateescape") as f:
        return f.read()


def listing(root):
    """(files, how): the repository files, relative. git ls-files (tracked + untracked, not ignored) where root is the top level of
    a git work tree (the state fresh-check.sh copies); otherwise a walk that skips .git and out/ (a copy without .git, a probe copy)."""
    real = os.path.realpath(root)
    try:
        top = subprocess.run(["git", "-C", root, "rev-parse", "--show-toplevel"], capture_output=True, check=True).stdout.decode().strip()
        if os.path.realpath(top) == real:
            out = subprocess.run(["git", "-C", root, "ls-files", "-z", "-co", "--exclude-standard"], capture_output=True, check=True).stdout
            fs = [p for p in out.decode("utf-8", "surrogateescape").split("\0") if p and os.path.isfile(os.path.join(root, p))]
            return sorted(fs), "git ls-files"
    except (OSError, subprocess.CalledProcessError):
        pass
    fs = []
    for d, dirs, names in os.walk(root):
        dirs[:] = [x for x in dirs if x not in (".git", "out")]
        for n in names:
            fs.append(os.path.relpath(os.path.join(d, n), root))
    return sorted(fs), "find"


def result(label, problems):
    print(label)
    for p in problems:
        print("    " + p)
    return 1 if problems else 0


def kv(items, what):
    out = []
    for it in items or []:
        if "=" not in it or not it.split("=", 1)[1].strip():
            print("doc-truth: %s %r needs GLOB=REASON, and a reason" % (what, it), file=sys.stderr)
            sys.exit(2)
        out.append(tuple(x.strip() for x in it.split("=", 1)))
    return out


# ------------------------------------------------------------------ lists
def chk_lists(a, root):
    files, how = listing(root)
    fset = set(files)
    sh = sorted(f for f in files if f.endswith(".sh"))
    listed = set()
    for lf in a.list or []:
        try:
            with open(lf, encoding="utf-8") as f:
                listed |= {ln.strip() for ln in f if ln.strip()}
        except OSError as e:
            print("doc-truth: cannot read list %s: %s" % (lf, e), file=sys.stderr)
            return 2
    excs = kv(a.exception, "--exception")
    prob = []
    if len(sh) < MIN_SHELL_FILES:
        prob.append("only %d shell files found (floor %d): the listing is broken, not the lists" % (len(sh), MIN_SHELL_FILES))
    if not listed:
        prob.append("the list files are empty")
    excepted = set()
    for glob_, why in excs:
        hit = [f for f in sh if fnmatch.fnmatchcase(f, glob_)]
        if not hit:
            prob.append("exception %r (%s) matches no shell file: please remove" % (glob_, why))
        also = [f for f in hit if f in listed]
        if also:
            prob.append("exception %r covers file(s) that ARE listed (%s): please remove" % (glob_, ", ".join(also[:3])))
        excepted |= set(hit)
    for f in sh:
        if f not in listed and f not in excepted:
            prob.append("shell file not in the list and not excepted: %s" % f)
    for f in sorted(listed):
        if f not in fset:
            prob.append("listed but not in the repository: %s" % f)
    return result("%d shell files (%s), %d listed, %d excepted by %d exception(s)" % (len(sh), how, len(listed), len(excepted), len(excs)), prob)


# ------------------------------------------------------------------ sources
def gen_sources(root):
    """SOURCES of tools/gen-testdata.py read from the syntax tree (nothing is executed): a tuple of string literals and names bound to one."""
    tree = ast.parse(rd(root, "tools/gen-testdata.py"))
    env, src = {}, None
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            n = node.targets[0].id
            if isinstance(node.value, ast.Constant) and isinstance(node.value.value, str):
                env[n] = node.value.value
            elif n == "SOURCES" and isinstance(node.value, (ast.Tuple, ast.List)):
                src = node.value
    if src is None:
        return None
    out = []
    for e in src.elts:
        if isinstance(e, ast.Constant) and isinstance(e.value, str):
            out.append(e.value)
        elif isinstance(e, ast.Name) and e.id in env:
            out.append(env[e.id])
        else:
            return None
    return tuple(out)


def collector_sources(root):
    """(set of literal source values outside selftest(), number of `-v src=` uses, number of those with a literal)."""
    vals, nsrc, nlit, in_st = set(), 0, 0, False
    for ln in rd(root, "starchorus-collect.sh").split("\n"):
        if re.match(r"^selftest\(\)[ \t]*\{", ln):
            in_st = True
            continue
        if in_st:
            if ln.startswith("}"):
                in_st = False
            continue
        if ln.lstrip().startswith("#"):
            continue
        nsrc += len(re.findall(r"-v src=", ln))
        for m in re.finditer(r'-v src="([^"$]+)"', ln):
            vals.add(m.group(1))
            nlit += 1
        for m in re.finditer(r'"source": "([^"$%\\]+)"', ln):
            vals.add(m.group(1))
    return vals, nsrc, nlit


def chk_sources(a, root):
    g = gen_sources(root)
    if not g:
        print("doc-truth: SOURCES not found in tools/gen-testdata.py as a tuple of literals", file=sys.stderr)
        return 2
    c, nsrc, nlit = collector_sources(root)
    prob = []
    for s in sorted(set(g) - c):
        prob.append("gen-testdata.py SOURCES has %r, the collector emits no such source" % s)
    for s in sorted(c - set(g)):
        prob.append("the collector emits source %r, missing in gen-testdata.py SOURCES (the validator would reject it)" % s)
    if nsrc != nlit:
        prob.append("%d awk `-v src=` uses, only %d with a literal: the source value cannot be read from the text" % (nsrc, nlit))
    if len(c) < 4:
        prob.append("only %d collector sources found (floor 4): the extraction is broken" % len(c))
    return result("SOURCES {%s} = collector literals {%s} (%d awk -v src)" % (" ".join(sorted(g)), " ".join(sorted(c)), nsrc), prob)


def chk_census(a, root):
    g = gen_sources(root)
    if not g:
        print("doc-truth: SOURCES not found in tools/gen-testdata.py", file=sys.stderr)
        return 2
    without = kv(a.no_fixture, "--no-fixture")
    have, n = {}, 0
    for fp in sorted(glob.glob(os.path.join(root, "tests", "fixtures", "*.json"))):
        n += 1
        try:
            d = json.load(open(fp, encoding="utf-8"))
        except (OSError, ValueError) as e:
            print("doc-truth: cannot read %s: %s" % (fp, e), file=sys.stderr)
            return 2
        have.setdefault(d.get("source"), []).append(os.path.basename(fp))
    prob = []
    if n < 9:
        prob.append("only %d fixtures found (floor 9)" % n)
    for s in have:
        if s not in g:
            prob.append("fixture(s) %s carry source %r, which is not in SOURCES" % (", ".join(have[s]), s))
    listed = {k for k, _ in without}
    for s in g:
        if s not in have and s not in listed:
            prob.append("source %r occurs in no fixture and is not in the --no-fixture list (add a fixture, or list it with a reason)" % s)
    for s, why in without:
        if s not in g:
            prob.append("the --no-fixture list names %r, which is not in SOURCES: please remove" % s)
        elif s in have:
            prob.append("the --no-fixture list names %r, but fixture(s) %s carry it now: please remove" % (s, ", ".join(have[s])))
    return result("%d fixtures cover %d of %d sources; without fixture: %s" % (n, len([s for s in g if s in have]), len(g), " ".join(sorted(listed)) or "none"), prob)


# ------------------------------------------------------------------ fixtures
def fixture_facts(path):
    d = json.load(open(path, encoding="utf-8"))
    aps = d.get("aps") or []
    bands = {}
    for ap in aps:
        b = ap.get("band")
        bands[b] = bands.get(b, 0) + 1
    return {"aps": len(aps), "withc": sum(1 for ap in aps if ap.get("clients")), "free": len(d.get("unassociated") or []),
            "bands": bands, "source": d.get("source")}


def chk_fixtures(a, root):
    rows = {}
    for ln in rd(root, "tools/README.md").split("\n"):
        m = re.match(r"^\| `([A-Za-z0-9._-]+\.json)` \| (.*) \|$", ln)
        if m:
            rows[m.group(1)] = m.group(2)
    have = sorted(os.path.basename(p) for p in glob.glob(os.path.join(root, "tests", "fixtures", "*.json")))
    prob = []
    if len(rows) < MIN_FIXTURE_ROWS:
        prob.append("only %d fixture rows in tools/README.md (floor %d)" % (len(rows), MIN_FIXTURE_ROWS))
    for f in have:
        if f not in rows:
            prob.append("fixture %s has no row in the tools/README.md table" % f)
    for f in rows:
        if f not in have:
            prob.append("the table has a row for %s, which does not exist" % f)
    nclaims = 0
    for f in have:
        if f not in rows:
            continue
        t, fx = rows[f], fixture_facts(os.path.join(root, "tests", "fixtures", f))
        claims = []
        m = re.search(r"(\d+) APs?\b", t)
        if m:
            claims.append(("APs", int(m.group(1)), fx["aps"]))
        m = re.search(r"\((\d+) with `clients\[\]`\)", t)
        if m:
            claims.append(("APs with clients[]", int(m.group(1)), fx["withc"]))
        m = re.search(r"(\d+) free clients?\b", t)
        if m:
            claims.append(("free clients", int(m.group(1)), fx["free"]))
        m = re.search(r"\((\d+) × 2\.4 / (\d+) × 5 / (\d+) × 6 GHz\)", t)
        if m:
            for k, v in zip(("2.4GHz", "5GHz", "6GHz"), m.groups()):
                claims.append(("APs on " + k, int(v), fx["bands"].get(k, 0)))
        m = re.search(r'source: "([^"]*)"', t)
        if m:
            claims.append(("source", m.group(1), fx["source"]))
        # a claim that dropped out of the pattern (row reworded) must not pass silently: what the data has to state is derived from the file
        have_kinds = {c[0] for c in claims}
        need = []
        if fx["aps"] > 0:
            need.append("APs")
        if fx["free"] > 0 and re.search(r"\bfree\b|\bclients?\b(?!\[)", t, re.I):
            need.append("free clients")
        if re.search(r"with `clients\[\]`", t):
            need.append("APs with clients[]")
        if "GHz" in t:
            need.append("APs on 2.4GHz")
        if "source:" in t:
            need.append("source")
        for k in need:
            if k not in have_kinds:
                prob.append("%s: the row no longer states %s in the form the check reads (the number is not compared): %s" % (f, k, t[:80]))
        for what, said, real in claims:
            nclaims += 1
            if said != real:
                prob.append("%s: the table says %s = %s, the file has %s" % (f, what, said, real))
    if nclaims < MIN_CLAIMS:
        prob.append("only %d stated sizes were checked (floor %d): the row patterns no longer match the table" % (nclaims, MIN_CLAIMS))
    # the generator call of active.json is quoted from static.sh (ACTIVE_GEN), not typed a second time
    m = re.search(r'^ACTIVE_GEN="([^"]+)"', rd(root, "tools/static.sh"), re.M)
    if not m:
        prob.append("ACTIVE_GEN not found in tools/static.sh")
    elif "active.json" in rows and m.group(1) not in rows["active.json"]:
        prob.append("active.json row does not quote ACTIVE_GEN verbatim: %s" % m.group(1))
    return result("%d table rows = %d fixtures, %d stated sizes checked against the files" % (len(rows), len(have), nclaims), prob)


# ------------------------------------------------------------------ prose
# a number in front of a word that names a check (also "217 (checks)", "**217** checks", "217 assertions", "217 cases", "217 green"); markup is removed by plain() first
COUNT_RE = re.compile(r"\b\d+ \(?(PASS|checks?|check ?points?|tests?|assertions?|cases?|green)\b", re.I)
# a script name followed (no digit, no sentence end in between) by a version-like token: "version 1.2", "starchorus-collect.sh 1.2 delivers", "collector 1.3",
# "Collector: 1.2", a table row "| starchorus-collect.sh | 1.2 |"
WHO_RE = re.compile(r"(?<![\w-])(collector|starchorus-collect\.sh|Dashboard|starchorus-display\.sh)(?![\w-])([^\d.;]{0,40}?)(?<![\w.§])v?(\d+\.\d+(?:\.\d+)?)(?![\d.]*\d)(?! ?(?:s|ms|px|Hz|kB|MB)\b)", re.I)   # "1.2 s" is a duration, not a version
HIST_RE = re.compile(r"\b(since|from|until|up to|first)\b|≥|>=")   # "since 1.3", "up to 1.0.1": says when something began or ended, not what is current


def plain(t):
    """Markdown decoration and blanks that must not hide a claim: backticks, emphasis stars, underscores around a number, no-break spaces, runs of blanks."""
    t = t.replace("&nbsp;", " ").replace("`", "").replace("*", "").replace("\u00a0", " ").replace("\u202f", " ")
    t = re.sub(r"(?<![A-Za-z0-9])_+(?=\d)|(?<=\d)_+(?![A-Za-z0-9])", "", t)
    return re.sub(r"[ \t]+", " ", t)


def vtuple(v):
    return tuple(int(x) for x in v.split("."))


def head_version(root, script):
    for ln in rd(root, script).split("\n")[:40]:
        m = re.match(r"^#\s*Version:\s*(\d+\.\d+(?:\.\d+)?)\s*$", ln)
        if m:
            return m.group(1)
    return None


def chk_prose(a, root):
    files, how = listing(root)
    md = [f for f in files if f.endswith(".md")]
    prob = []
    if len(md) < MIN_MD_FILES:
        prob.append("only %d prose documents found (floor %d)" % (len(md), MIN_MD_FILES))
    heads = {"collector": head_version(root, "starchorus-collect.sh"), "display script": head_version(root, "starchorus-display.sh")}
    for k, v in heads.items():
        if not v:
            prob.append("no `# Version:` header found for the %s (needed to judge version claims)" % k)
    nver = 0
    for f in md:
        lines = [plain(x) for x in rd(root, f).split("\n")]
        for i, ln in enumerate(lines, 1):
            if re.search(r"\bas of\b", ln, re.I):      # dated statements ("as of <version>: 56 PASS") are allowed, they say when they were true
                continue
            # a claim that wraps over the line end ("collector\n1.2") is read on the line where it starts: the next line of the paragraph is appended
            nxt = lines[i].strip() if i < len(lines) else ""
            both = ln + " " + nxt
            for m in COUNT_RE.finditer(both):
                if m.start() < len(ln):
                    prob.append("%s:%d hand-typed check count (delete it, or date it with \"as of\"): %s" % (f, i, ln.strip()[:90]))
                    break
            for m in WHO_RE.finditer(both):
                if m.start() >= len(ln):
                    continue
                if m.end() > len(ln) and len(m.group(2)) > 12:   # wrapped over the line end: only a short gap counts ("collector" + newline + "1.2"), not a name far up the line
                    continue
                nver += 1
                who = "collector" if re.match(r"collector|starchorus-collect", m.group(1), re.I) else "display script"
                head = heads[who]
                if not head or HIST_RE.search(both[max(0, m.start() - 12):m.end() + 12]):
                    continue
                # one project, one version: a claim that is not the header's version (older or newer) is stale
                if vtuple(m.group(3) + ".0" * (2 - m.group(3).count("."))) != vtuple(head + ".0" * (2 - head.count("."))):
                    prob.append("%s:%d version claim %s about the %s, the header says %s (delete it, date it with \"as of\", or say \"since\"/\"until\"): %s" % (f, i, m.group(3), who, head, ln.strip()[:90]))
    return result("%d documents read (%s), hand-typed check counts and collector/display version claims: %d (%d version mentions judged)" % (len(md), how, len(prob), nver), prob)


# ------------------------------------------------------------------ runlist
def chk_runlist(a, root):
    prob = []
    m = re.search(r"^for f in ([a-z0-9 -]+); do$", rd(root, "tools/regress.sh"), re.M)
    loop = m.group(1).split() if m else []
    if not loop:
        prob.append("fixture loop `for f in ...; do` not found in tools/regress.sh")
    lines = rd(root, "docs/architecture.md").split("\n")
    at = [i for i, ln in enumerate(lines) if "**Global mandatory criteria for every regression run**" in ln]
    spec, n = [], None
    if len(at) != 1:
        prob.append("the §11.0 anchor `**Global mandatory criteria for every regression run**` occurs %d times (want 1)" % len(at))
    else:
        head = " ".join(lines[at[0]:at[0] + 2])
        spec = re.findall(r"`([a-z0-9-]+)`", head)
        for ln in lines[at[0]:at[0] + 8]:
            mm = re.search(r"for all (\d+) runs", ln)
            if mm:
                n = int(mm.group(1))
                break
    if loop and spec != loop:
        prob.append("spec run list %s != regress.sh loop %s" % (" ".join(spec), " ".join(loop)))
    if loop and n != len(loop):
        prob.append("spec says %s runs, the loop has %d" % (n, len(loop)))
    if len(loop) < 5:
        prob.append("only %d runs in the loop (floor 5)" % len(loop))
    return result("%d runs (%s)" % (len(loop), " ".join(loop)), prob)


# ------------------------------------------------------------------ headers
HEADER_SCRIPTS = ("starchorus-collect.sh", "starchorus-display.sh", "library/user/reconnaissance/starchorus/starchorus-display.sh",
                  "starchorus-serve.sh", "payload.sh", "library/user/reconnaissance/starchorus/payload.sh")


def chk_headers(a, root):
    prob, parts = [], []
    m = re.search(r'^  version: "(\d+\.\d+\.\d+)",$', rd(root, "starchorus.html"), re.M)
    page = m.group(1) if m else None
    if not page:
        prob.append('starchorus.html has no `  version: "x.y.z",` line')
    for script in HEADER_SCRIPTS:
        head = head_version(root, script)
        if not head:
            prob.append("%s has no `# Version:` header in its first 40 lines" % script)
        elif page and head != page:
            prob.append("%s: header %s, but the page version is %s" % (script, head, page))
        else:
            parts.append("%s %s" % (script, head))
    return result("page %s = %d script headers (%s)" % (page, len(parts), "; ".join(parts) if parts else "none"), prob)


# ------------------------------------------------------------------ contract
CONTRACT_SCRIPTS = ("starchorus-collect.sh", "starchorus-display.sh", "library/user/reconnaissance/starchorus/starchorus-display.sh",
                    "library/user/reconnaissance/starchorus/payload.sh")


def chk_contract(a, root):
    prob, nums = [], []
    for script in CONTRACT_SCRIPTS:
        n = None
        for ln in rd(root, script).split("\n")[:40]:
            m = re.match(r"^#\s*Contract:\s*(\d+)\s*$", ln)
            if m:
                n = int(m.group(1))
                break
        if n is None:
            prob.append("%s has no `# Contract:` header in its first 40 lines" % script)
        else:
            nums.append(n)
            if a.want is not None and n != a.want:
                prob.append("%s: header says %d, want %d" % (script, n, a.want))
    if len(set(nums)) > 1:
        prob.append("the headers do not agree: %s" % ", ".join("%s %d" % (s, n) for s, n in zip(CONTRACT_SCRIPTS, nums)))
    return result("Contract %s in %d script headers%s" % ("/".join(str(n) for n in sorted(set(nums))) or "none", len(nums),
                                                        "" if a.want is None else " (want %d)" % a.want), prob)


CHECKS = {"lists": chk_lists, "sources": chk_sources, "census": chk_census, "fixtures": chk_fixtures,
          "prose": chk_prose, "runlist": chk_runlist, "headers": chk_headers, "contract": chk_contract}


def main():
    ap = argparse.ArgumentParser(prog="doc-truth.py", add_help=True)
    ap.add_argument("check", choices=sorted(CHECKS))
    ap.add_argument("--root", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    ap.add_argument("--list", action="append")
    ap.add_argument("--exception", action="append")
    ap.add_argument("--no-fixture", action="append", dest="no_fixture")
    ap.add_argument("--want", type=int, default=None)
    a = ap.parse_args()
    try:
        return CHECKS[a.check](a, os.path.abspath(a.root))
    except (OSError, ValueError) as e:
        print("doc-truth: %s: %s" % (a.check, e), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
