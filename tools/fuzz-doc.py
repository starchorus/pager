#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
fuzz-doc.py -- deterministic mutants of starchorus.json documents for the ingest fuzz. Dev machine only.

The viewer's border is STARCHORUS.load()/the poll/paste: a foreign or broken document must neither crash it nor wipe a good
display, and an SSID (attacker text from the air) must never run script. This tool builds the documents; the Chrome side
is tools/regress.d/ingest-fuzz.sh + tools/evals/ingest-fuzz.js. Python 3 stdlib only. Nothing here is executed by the
device; all data is derived from tests/fixtures (synthetic, P9) or invented. No file in tests/fixtures is written.

Field lists are DERIVED, never typed: the contract keys come from tools/gen-testdata.py (REQUIRED_TOP, OPT_TOP, AP_KEYS,
OPT_AP, OPT_CL ...), the keys the fixtures really carry from the fixtures themselves, and the keys the viewer reads (and
what type it expects: numOrNull / stripCtl / Array.isArray) from normalizeDoc()/normClient() in the page. A field the
viewer learns tomorrow is fuzzed tomorrow without touching this file.

Classes (the number is the row's class in the bundle):
  1 a field is missing            2 a field has the wrong type ("x", 42, true, null, [], {}) and the whole document is not a
  document                        3 junk entries in aps[] / aps[].clients[] / unassociated[]     4 number garbage (rssi "abc"/1e308/-999,
  channel 0/-1/9999, generated 0/future/string ...)       5 "__proto__"/"constructor" as bssid/mac/ssid and as a JSON key, duplicate
  BSSID/MAC          6 control characters / RTL / 10 000 characters / HTML in every text field (also as "all fields at once", the
  documents that carry the positive anchor of the sink checks)          7 many APs / clients (own list "big", run apart)

usage: fuzz-doc.py [--seed N] [--fixtures DIR] [--page HTML] [--canary PATH] [--big N] [--classes 1,2,...] [--out BUNDLE.json]
                   [--emit-dir DIR --emit-classes 5,6] [--summary]
The bundle is itself a valid document (a slim few-clients carrier) with one extra key "fuzz"; the page ignores unknown keys, so
it can be served as starchorus.json and the eval fetches it back. Same seed, same bytes.
"""
import argparse, copy, importlib.util, json, os, random, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SEED = 20260918
# The canary payloads carry the path UNQUOTED (`$(touch PATH)`), as a shell-injectable sink would see them. A path with a space (the
# repo may live in "Application Support") would split `touch A B/c` into several arguments: a real injection could then never create
# the file, and "the canary was not created" would prove nothing. So only a path that stays ONE word is accepted.
SAFE_CANARY = re.compile(r"^[A-Za-z0-9_./-]+$")
HOSTILE = [   # text that must stay text. The first is the classic; ssid limit is 32 chars, so it is exactly that long.
    "<img src=x onerror=window.__x=1>",
    "<b>x</b>",
    "\"><script>window.__x=1</script>",
    "'\"&<>&amp;&lt;",
    "A\x00\x07\x1b[31m\x7f\x85B\r\nC",
    "\u202eDCBA\u2066\u2069\u200f\ufeff\U0001f4a5",
    "A" * 10000,
]
WRONG_TYPES = ["x", 42, True, None, [], {}]
NUM_GARBAGE = ["abc", 1e308, -1e308, -999, 0, -1, 9999, 4102444800, 1e-320]
PROTO_NAMES = ["__proto__", "constructor", "toString", "hasOwnProperty", "valueOf"]


def load_contract():
    """The contract key lists of tools/gen-testdata.py (the one place they are defined)."""
    spec = importlib.util.spec_from_file_location("gen_testdata", os.path.join(HERE, "gen-testdata.py"))
    m = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(m)
    return m


def fn_body(text, name):
    """Source of `function NAME(...) {` up to the closing brace at line start ("" if the function is gone)."""
    m = re.search(r"^function %s\(.*?\{\n(.*?)^\}" % re.escape(name), text, re.S | re.M)
    return m.group(1) if m else ""


def page_fields(page):
    """What the viewer reads: {"top": {field: hint}, "ap": ..., "client": ...}, hint in {num, str, list, any}."""
    try:
        text = open(page, encoding="utf-8").read()
    except OSError:
        return {"top": {}, "ap": {}, "client": {}}
    nd, nc = fn_body(text, "normalizeDoc"), fn_body(text, "normClient")

    def scan(body, var):
        out = {}
        for f in sorted(set(re.findall(r"\b%s\.([A-Za-z_]\w*)" % var, body))):
            hint = "any"
            if re.search(r"numOrNull\(\s*%s\.%s\s*\)" % (var, f), body):
                hint = "num"
            elif re.search(r"stripCtl\(\s*%s\.%s\b" % (var, f), body) or re.search(r'typeof %s\.%s === "string"' % (var, f), body):
                hint = "str"
            elif re.search(r"Array\.isArray\(\s*%s\.%s\s*\)" % (var, f), body):
                hint = "list"
            out[f] = hint
        return out
    return {"top": scan(nd, "raw"), "ap": scan(nd, "a"), "client": scan(nc, "c")}


def kind_of(v):
    if isinstance(v, bool):
        return "any"
    if isinstance(v, (int, float)):
        return "num"
    if isinstance(v, str):
        return "str"
    if isinstance(v, list) and v and all(isinstance(x, str) for x in v):
        return "list"
    return "any"


class Fixtures:
    """The fixtures, smallest first, and the derived field table."""

    def __init__(self, fdir, gen, pf):
        self.docs = []
        for fn in sorted(os.listdir(fdir)):
            if fn.endswith(".json"):
                p = os.path.join(fdir, fn)
                with open(p, encoding="utf-8") as fh:
                    d = json.load(fh)
                if isinstance(d, dict) and isinstance(d.get("aps"), list):
                    self.docs.append((os.path.getsize(p), fn, d))
        self.docs.sort(key=lambda t: (t[0], t[1]))
        if not self.docs:
            sys.exit("fuzz-doc: no fixture in %s" % fdir)
        # the generator keeps some key lists as SETS (OPT_TOP/OPT_AP/OPT_CL): their iteration order
        # follows the per-process string hash, so they are sorted here, or "same seed, same bytes" would not hold
        def seq(x):
            return list(x) if isinstance(x, (list, tuple)) else sorted(x)
        cl = ("mac", "rssi") + tuple(seq(gen.OPT_CL))
        self.fields = {
            "top": seq(gen.REQUIRED_TOP) + seq(gen.OPT_TOP),
            "ap": seq(gen.AP_KEYS) + seq(gen.OPT_AP) + seq(gen.IWSCAN_OPT_AP),
            "client": list(cl),
        }
        for k in ("top", "ap", "client"):   # the viewer reads more than the contract lists (caps, packets ...): add what it reads
            for f in pf.get(k, {}):
                if f not in self.fields[k]:
                    self.fields[k].append(f)
        self.fields["ap"] = [f for f in dict.fromkeys(self.fields["ap"])]
        self.hint = {k: dict(pf.get(k, {})) for k in ("top", "ap", "client")}

    def elements(self, doc, kind):
        """[(path, element)] of a document; path is a tuple of keys/indices."""
        out = []
        if kind == "ap":
            for i, a in enumerate(doc.get("aps", [])):
                if isinstance(a, dict):
                    out.append((("aps", i), a))
        else:
            for i, a in enumerate(doc.get("aps", [])):
                if isinstance(a, dict):
                    for j, c in enumerate(a.get("clients") or []):
                        if isinstance(c, dict):
                            out.append((("aps", i, "clients", j), c))
            if kind == "client":
                return out
            out = []
            for j, c in enumerate(doc.get("unassociated", [])):
                if isinstance(c, dict):
                    out.append((("unassociated", j), c))
        return out

    def donor(self, kind, field):
        """(doc, path, element) of the smallest fixture element that carries FIELD, or None."""
        for _, _, d in self.docs:
            if kind == "top":
                if field in d:
                    return d, (), d
                continue
            for path, e in self.elements(d, kind):
                if field in e:
                    return d, path, e
        return None

    def base(self, prefer=None):
        for _, fn, d in self.docs:
            if prefer and fn == prefer:
                return d
        return self.docs[-1][2] if not prefer else self.base(None)


def get(doc, path):
    for k in path:
        doc = doc[k]
    return doc


def slim(doc, path):
    """A small valid copy of DOC that keeps the element at PATH first in its list (so the mutation always hits index 0)."""
    d = copy.deepcopy(doc)
    aps, un = d.get("aps", []), d.get("unassociated", [])
    if path and path[0] == "aps":
        i = path[1]
        head = aps.pop(i)
        if len(path) == 4:   # a client: keep it first inside its AP
            cl = head.get("clients") or []
            cl.insert(0, cl.pop(path[3]))
            head["clients"] = cl[:3]
        d["aps"] = [head] + aps[:3]
        d["unassociated"] = un[:3]
    elif path and path[0] == "unassociated":
        un.insert(0, un.pop(path[1]))
        d["aps"], d["unassociated"] = aps[:4], un[:3]
    else:
        d["aps"], d["unassociated"] = aps[:4], un[:3]
    for a in d["aps"]:
        if isinstance(a.get("clients"), list):
            a["clients"] = a["clients"][:3]
    return d


class Bundle:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.muts = []
        self.seen = set()

    def add(self, cls, name, doc, anchor=False):
        key = json.dumps(doc, sort_keys=True, ensure_ascii=True)
        if key in self.seen:
            return
        self.seen.add(key)
        self.muts.append({"c": cls, "n": name, "d": doc, "a": 1 if anchor else 0})


def setp(doc, path, field, val):
    tgt = get(doc, path)
    tgt[field] = val


def build(fx, seed, canary, nbig):
    b = Bundle(seed)
    hostile = HOSTILE + ["$(touch %s)" % canary, "`touch %s`" % canary, "\";touch %s;\"" % canary]
    for kind in ("top", "ap", "client", "unassoc"):
        fields = fx.fields["client" if kind == "unassoc" else kind]
        hints = fx.hint["client" if kind == "unassoc" else kind]
        for f in fields:
            dn = fx.donor(kind, f)
            if dn is None:
                # a field no fixture carries (the viewer reads it): base = the first fixture that has an element of this kind
                doc0 = None
                for _, _, d in fx.docs:
                    if kind == "top" or fx.elements(d, kind):
                        doc0 = d; break
                if doc0 is None:
                    continue
                path = () if kind == "top" else fx.elements(doc0, kind)[0][0]
                present, orig = False, None
            else:
                doc0, path, e = dn
                present, orig = True, e[f]
            def fresh():   # a slim copy in which the element that carries FIELD is the first of its list
                d = slim(doc0, path)
                return d, {"top": (), "ap": ("aps", 0), "client": ("aps", 0, "clients", 0), "unassoc": ("unassociated", 0)}[kind]
            label = "%s.%s" % (kind, f)
            hint = hints.get(f, "any")
            if present:
                hint = kind_of(orig) if kind_of(orig) != "any" else hint
            if present:
                d, p = fresh(); del get(d, p)[f]; b.add(1, "1:%s:missing" % label, d)
            for wt in WRONG_TYPES:
                if present and json.dumps(wt) == json.dumps(orig):
                    continue
                d, p = fresh(); setp(d, p, f, copy.deepcopy(wt)); b.add(2, "2:%s:%s" % (label, json.dumps(wt)), d)
            if hint == "num":
                for g in NUM_GARBAGE:
                    d, p = fresh(); setp(d, p, f, g); b.add(4, "4:%s:%s" % (label, json.dumps(g)), d)
            if hint in ("str", "list"):
                for hs in hostile:
                    d, p = fresh(); setp(d, p, f, [hs] if hint == "list" else hs)
                    b.add(6, "6:%s:h%d" % (label, hostile.index(hs)), d)
    # nested: center.label and the whole-document shapes
    dn = fx.donor("top", "center")
    if dn:
        for hs in hostile:
            d = slim(dn[0], ()); d["center"] = {"label": hs}; b.add(6, "6:top.center.label:h%d" % hostile.index(hs), d)
        for wt in WRONG_TYPES + [{"label": 5}, {"label": None}, {"label": []}]:
            d = slim(dn[0], ()); d["center"] = wt; b.add(2, "2:top.center:%s" % json.dumps(wt)[:30], d)
    base = fx.base("few-clients.json")
    for wt in [None, "x", 42, True, [], {}, [{"aps": []}], {"aps": {}}, {"aps": None}, {"aps": "x"}, {"aps": [[]]}, {"aps": 0}]:
        b.add(2, "2:doc:%s" % json.dumps(wt)[:30], wt)
    # class 3: junk entries in the three lists (null first, the entry most likely to crash a parser)
    for junk in (None, "x", 42, True, [], {}):
        jn = json.dumps(junk)
        d = slim(base, ()); d["aps"][0] = junk; b.add(3, "3:aps[0]=%s" % jn, d)
        d = slim(base, ()); d["aps"].insert(b.rng.randrange(1, len(d["aps"]) + 1), junk); b.add(3, "3:aps.insert=%s" % jn, d)
        d = slim(base, ()); d["aps"] = [junk, junk]; b.add(3, "3:aps=[j,j]=%s" % jn, d)
        d = slim(base, ()); ci = next((a for a in d["aps"] if a.get("clients")), None)
        if ci is not None:
            ci["clients"][0] = junk; b.add(3, "3:clients[0]=%s" % jn, d)
            d = copy.deepcopy(d); ci = next(a for a in d["aps"] if a.get("clients")); ci["clients"] = [junk] + ci["clients"]; b.add(3, "3:clients.prepend=%s" % jn, d)
        d = slim(base, ()); d["unassociated"] = [junk] + d["unassociated"]; b.add(3, "3:unassociated.prepend=%s" % jn, d)
        d = slim(base, ()); d["unassociated"] = [junk, junk]; b.add(3, "3:unassociated=[j,j]=%s" % jn, d)
    # class 5: prototype names, duplicates, JSON keys
    for pn in PROTO_NAMES:
        for fld, path in (("bssid", ("aps", 0)), ("ssid", ("aps", 0))):
            d = slim(base, ()); d["aps"][0][fld] = pn; b.add(5, "5:ap.%s=%s" % (fld, pn), d)
        d = slim(base, ()); ci = next((a for a in d["aps"] if a.get("clients")), None)
        if ci is not None:
            ci["clients"][0]["mac"] = pn; b.add(5, "5:client.mac=%s" % pn, d)
        d = slim(base, ());
        if d["unassociated"]:
            d["unassociated"][0]["mac"] = pn; b.add(5, "5:unassoc.mac=%s" % pn, d)
    d = slim(base, ()); d["aps"][1]["bssid"] = d["aps"][0]["bssid"]; b.add(5, "5:dup-bssid", d)
    d = slim(base, ()); d["aps"].insert(1, copy.deepcopy(d["aps"][0])); b.add(5, "5:dup-ap-entry", d)
    d = slim(base, ()); d["aps"][0]["bssid"] = d["aps"][0]["bssid"].upper(); d["aps"].insert(1, copy.deepcopy(d["aps"][0])); d["aps"][1]["bssid"] = d["aps"][0]["bssid"].lower(); b.add(5, "5:dup-bssid-case", d)
    d = slim(base, ()); c2 = [a for a in d["aps"] if a.get("clients")]
    if len(c2) >= 2:
        c2[1]["clients"][0]["mac"] = c2[0]["clients"][0]["mac"]; b.add(5, "5:dup-client-mac-two-aps", d)
    d = slim(base, ())
    if d["unassociated"] and c2:
        d["unassociated"][0]["mac"] = next(a for a in d["aps"] if a.get("clients"))["clients"][0]["mac"]; b.add(5, "5:unassoc=associated-mac", d)
    d = slim(base, ())
    if d["unassociated"]:
        d["unassociated"][0]["mac"] = d["aps"][0]["bssid"]; b.add(5, "5:unassoc-mac=ap-bssid", d)
    for js in ('{"__proto__":{"polluted":1}}', '{"constructor":{"prototype":{"polluted":1}}}'):
        d = slim(base, ()); d.update(json.loads(js)); b.add(5, "5:key:top:%s" % js[:24], d)
        d = slim(base, ()); d["aps"][0].update(json.loads(js)); b.add(5, "5:key:ap:%s" % js[:24], d)
        d = slim(base, ()); d["center"] = dict(json.loads(js), label="x"); b.add(5, "5:key:center:%s" % js[:24], d)
    # class 6 "all text fields at once": every string / string-list field of every element hostile, ids kept unique.
    # These carry the positive anchor of the sink checks (the masked text must be findable in the panels).
    for hi, hs in enumerate(hostile):
        d = slim(fx.base("many-clients.json"), ())
        for kind, elems in (("ap", d["aps"]), ("client", [c for a in d["aps"] for c in (a.get("clients") or [])]), ("client", d["unassociated"])):
            for i, e in enumerate(elems):
                for f in list(fx.fields["ap" if kind == "ap" else "client"]):
                    v = e.get(f)
                    if f in ("bssid", "mac"):
                        e[f] = "%s#%d" % (hs[:64], i) if isinstance(v, str) else v
                    elif isinstance(v, str):
                        e[f] = hs if i == 0 else hs[:64]
                    elif isinstance(v, list) and v and all(isinstance(x, str) for x in v):
                        e[f] = [hs if i == 0 else hs[:64], hs[:64] + "2"]
        # probes and caps are not in the many-clients fixture: give the unassociated ones a hostile probe list, the APs a caps list
        for e in d["unassociated"]:
            e["probes"] = [hs]
        for e in d["aps"]:
            e["caps"] = [hs]
        d["source"] = "airodump-csv"
        b.add(6, "6:all-text:h%d" % hi, d, anchor=True)
    # "none" source: the note is a sink of #source-desc
    dn = fx.donor("top", "note")
    if dn:
        for hi, hs in enumerate(hostile):
            d = slim(dn[0], ()); d["note"] = hs; b.add(6, "6:note-none:h%d" % hi, d, anchor=True)
    # class 7: many entries (own list, own eval with an explicit timeout)
    big = []
    src = fx.base("few-clients.json")
    ap0 = copy.deepcopy(src["aps"][0]); ap0["clients"] = []
    chans = [1, 6, 11, 36, 40, 44, 100, 149]
    def mkap(i):
        a = copy.deepcopy(ap0)
        a["bssid"] = "02:fz:%02x:%02x:%02x:%02x" % ((i >> 24) & 255, (i >> 16) & 255, (i >> 8) & 255, i & 255)
        a["bssid"] = a["bssid"].replace("fz", "f0")
        a["ssid"] = "fuzz-%d" % (i // 3)
        ch = chans[b.rng.randrange(len(chans))]
        a["channel"] = ch; a["band"] = "2.4GHz" if ch < 15 else "5GHz"; a["freq"] = 2412 + 5 * ch if ch < 15 else 5000 + 5 * ch
        a["rssi"] = -30 - b.rng.randrange(60)
        return a
    def mkcl(i, pre):
        return {"mac": "%s:%02x:%02x:%02x" % (pre, (i >> 16) & 255, (i >> 8) & 255, i & 255), "rssi": -40 - b.rng.randrange(50)}
    d = copy.deepcopy(src); d["aps"] = [mkap(i) for i in range(nbig)]; d["unassociated"] = []
    big.append({"c": 7, "n": "7:aps-%d" % nbig, "d": d, "a": 0})
    d = copy.deepcopy(src); d["aps"] = [d["aps"][0]]; d["aps"][0]["clients"] = [mkcl(i, "06:c0:01") for i in range(nbig)]; d["unassociated"] = []
    big.append({"c": 7, "n": "7:clients-%d-one-ap" % nbig, "d": d, "a": 0})
    d = copy.deepcopy(src); d["unassociated"] = [mkcl(i, "0a:c0:02") for i in range(nbig)]
    big.append({"c": 7, "n": "7:unassociated-%d" % nbig, "d": d, "a": 0})
    return b.muts, big


def collector_safe(doc):
    """Could starchorus-collect.sh have written this document? Every list entry an object and no control character in any string
    (the collector strips them from SSIDs: starchorus-collect.sh, the sanitiser above build_from_iwscan). Only such documents go to
    the display script: text with a line feed in an SSID cannot reach it, so a second output line would not be a finding."""
    if not isinstance(doc, dict) or not isinstance(doc.get("aps"), list) or not isinstance(doc.get("unassociated", []), list):
        return False
    def texts(o):
        if isinstance(o, str):
            yield o
        elif isinstance(o, list):
            for x in o:
                yield from texts(x)
        elif isinstance(o, dict):
            for k, v in o.items():
                yield k
                yield from texts(v)
    if any(not isinstance(a, dict) or not isinstance(a.get("clients", []), list) or any(not isinstance(c, dict) for c in a.get("clients", []))
           for a in doc["aps"]):
        return False
    if any(not isinstance(c, dict) for c in doc.get("unassociated", [])):
        return False
    return not any(re.search(r"[\x00-\x1f\x7f]", t) for t in texts(doc))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seed", type=int, default=DEFAULT_SEED)
    ap.add_argument("--fixtures", default=os.path.join(HERE, "..", "tests", "fixtures"))
    ap.add_argument("--page", default=os.path.join(HERE, "..", "starchorus.html"))
    ap.add_argument("--canary", default="fuzz-canary.tmp", help="path the shell-metacharacter SSIDs try to touch (must never appear); one shell word, no space/quote (checked)")
    ap.add_argument("--big", type=int, default=2000, help="entries of the class-7 documents")
    ap.add_argument("--classes", default="", help="keep only these classes in the bundle (default: all; 7 = the big list)")
    ap.add_argument("--out", help="write the bundle here")
    ap.add_argument("--emit-dir", help="also write the mutants of --emit-classes as single documents (for the display script), "
                    "only those the collector could have written (see collector_safe); name mNNNN-cC[a].json, a = anchor mutant")
    ap.add_argument("--emit-classes", default="5,6")
    ap.add_argument("--summary", action="store_true")
    a = ap.parse_args(argv)
    if not SAFE_CANARY.match(a.canary):
        ap.error("--canary %r would not stay one shell word (allowed: letters, digits, _ . / -): an injected touch could not create it" % a.canary)
    gen = load_contract()
    fx = Fixtures(a.fixtures, gen, page_fields(a.page))
    muts, big = build(fx, a.seed, a.canary, a.big)
    if a.classes:
        keep = {int(x) for x in a.classes.split(",") if x}
        muts, big = [m for m in muts if m["c"] in keep], [m for m in big if m["c"] in keep]
    classes = {}
    for m in muts + big:
        classes[m["c"]] = classes.get(m["c"], 0) + 1
    carrier = slim(fx.base("few-clients.json"), ())
    carrier["fuzz"] = {"seed": a.seed, "classes": {str(k): classes[k] for k in sorted(classes)}, "mutants": muts, "big": big,
                       "canary": a.canary}
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            json.dump(carrier, fh, separators=(",", ":"), ensure_ascii=True)
            fh.write("\n")
    if a.emit_dir:
        os.makedirs(a.emit_dir, exist_ok=True)
        want = {int(x) for x in a.emit_classes.split(",") if x}
        n = 0
        for i, m in enumerate(muts):
            if m["c"] in want and collector_safe(m["d"]):
                with open(os.path.join(a.emit_dir, "m%04d-c%d%s.json" % (i, m["c"], "a" if m["a"] else "")), "w", encoding="utf-8") as fh:
                    json.dump(m["d"], fh, ensure_ascii=True)
                n += 1
        print("emitted %d documents to %s" % (n, a.emit_dir), file=sys.stderr)
    if a.summary or not a.out:
        print("seed %d: %d mutants + %d big; classes %s" % (a.seed, len(muts), len(big), " ".join("%s=%d" % (k, classes[k]) for k in sorted(classes))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
