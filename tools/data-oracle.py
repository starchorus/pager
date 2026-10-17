#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
data-oracle.py -- an independently computed answer for the viewer's data logic. Dev machine only.

The viewer counts APs and clients, groups BSSIDs into devices (section 8.8 G1) and SSIDs into ESS sets (G2). Without this tool no
row would read those numbers (STARCHORUS.stats(), devices(), essClusters()). This tool holds a SECOND formulation of the rules,
written from the rules and not from the code (union-find over BSSID bytes, the same-OUI window/radio rules, the U/L bit, the SSID
base), and a judge that compares it with what the page reports after STARCHORUS.load() of every fixture. Combinatorial ground truth
only: counts and partitions, no geometry (no pixel pins, they would break with every layout change).
Python 3 stdlib only. Nothing here runs on the device or sends anything; documents are the fixtures (synthetic, P9) and the small
hand-made documents below (invented). No file in tests/fixtures is written.

usage: data-oracle.py bundle FIXTURE_DIR OUT.json     the bundle = a valid empty document + {"oracle": {name: document}}: every
                                                      fixture as it is plus the HAND documents (edge cases with hand-computed answers)
       data-oracle.py judge REPORT.json BUNDLE.json PAGE.html OPENFILE|- run|probe
                                                      judge one run of tools/evals/data-oracle.js (the first eval of REPORT); one label
                                                      line on stdout. MODE run: exit 0 iff the page agrees with the model in every field
                                                      of every document in both essMerge modes, except the findings listed in OPENFILE
                                                      ("glob|owner|cause"; a new one is red, a listed one that is gone is red: "please
                                                      remove"). MODE probe (the sensor's own proof, a page copy with planted faults):
                                                      exit 0 iff the run is RED for exactly the planted fault classes
       data-oracle.py truth DEVICES.json GENERATOR.py README.md
                                                      the documented ground truth of devices.json (header of gen-testdata.py:
                                                      18 APs, 3 device clusters, 2 ESS sets ...) against the model (exit 0 iff equal)
       data-oracle.py selftest                        the model against the hand documents, the judge against dummy reports (exit 0 iff
                                                      every case gets the verdict it has to get); Chrome-free, part of tier T1
"""
import fnmatch, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
# The rule constants of the page (const DEVICE = {...}); the judge reads them back from the page and says so if they moved.
DEVICE = {"mbssidBits": 3, "seqWindow": 4, "radioWindow": 16, "seqTight": 2}
BANDS = ("2.4", "5", "6")
# the page's ENCODING.security classes (enterprise, wpa3-transition and tkip-weak are decided also by the collector's akm/cipher)
SEC_KEYS = ("open", "wep", "wpa", "wpa2", "wpa3", "owe", "enterprise", "wpa3-transition", "tkip-weak", "unknown")
FIELDS = ("apsTotal", "aps", "clients", "free", "assoc", "groups", "bands", "bandsTotal", "security", "alarms", "hidden", "devices", "essMerged")
# Floors, only ever raised. The selftest holds every field of FIELDS to a case of its own; the judge holds the run to the floors.
MIN_FIELDS = 13     # len(FIELDS); measure: sed -n 's/.*const KEYS = \[\(.*\)\];/\1/p' tools/evals/data-oracle.js | tr ',' '\n' | grep -c '"'   (the counters the eval reads: 13)
MIN_FIXTURES = 13   # fixtures compared in a real run; measure: ls tests/fixtures/*.json | wc -l   (measured: 13; a bundle that loses fixtures must not stay green)


# ---------------------------------------------------------------- the model: normalisation (what the page keeps of a document)
def num(x):
    if x is None or x == "" or isinstance(x, bool):
        return None
    try:
        v = float(x)
    except (TypeError, ValueError):
        return None
    return v if v == v and v not in (float("inf"), float("-inf")) else None


def ctl(x, n):
    return "" if x is None else re.sub(r"[\x00-\x1f\x7f]", "", str(x))[:n]


def mac(x):
    s = str(x).strip().lower().replace("-", ":")
    return ":".join(s[i:i + 2] for i in range(0, 12, 2)) if re.fullmatch(r"[0-9a-f]{12}", s) else s


def band_of(band, freq, ch):
    b = re.sub(r"\s*ghz$", "", str(band if band is not None else "").strip(), flags=re.I)
    if b in BANDS:
        return b
    if freq is not None:
        return "6" if freq >= 5925 else "5" if freq >= 5000 else "2.4" if freq >= 2400 else "unknown"
    if ch is not None:
        return "6" if ch > 177 else "5" if 32 <= ch <= 177 else "2.4" if 1 <= ch <= 14 else "unknown"
    return "unknown"


def strs(v, n, m):
    """The page's strs(): the strings of a list, control characters out, cut to m, empty ones dropped, at most n; None if no list."""
    if not isinstance(v, list):
        return None
    return [y for y in (ctl(x, m) for x in v if isinstance(x, str)) if y][:n]


def sec_class(s, akm=None, cipher=None):
    """The page's secClass(security, akm, cipher): the label and, when present, the AKM/cipher detail, in the page's rule order."""
    u = str("" if s is None else s).upper().strip()
    ak = akm if isinstance(akm, list) else []
    if "owe" in ak and not any(re.match(r"(psk|sae|1x)", x) for x in ak): return "owe"
    if "OWE" in u: return "owe"
    if "ENTERPRISE" in u or "802.1X" in u or any(re.match(r"1x|fils", x) for x in ak): return "enterprise"
    pw = cipher["pairwise"] if isinstance(cipher, dict) and isinstance(cipher.get("pairwise"), list) else []
    if ("TKIP" in u and "CCMP" not in u and "GCMP" not in u) or ("tkip" in pw and not any(re.match(r"(ccmp|gcmp)", x) for x in pw)): return "tkip-weak"
    if ("WPA3" in u and "WPA2" in u) or ("sae" in ak and any(re.match(r"psk", x) for x in ak)) or ("SAE" in u and "PSK" in u): return "wpa3-transition"
    if "WPA3" in u or "SAE" in u: return "wpa3"
    if "WEP" in u: return "wep"
    if "WPA2" in u or "RSN" in u or "CCMP" in u: return "wpa2"
    if "WPA" in u or "PSK" in u or "TKIP" in u or "SECURED" in u: return "wpa"
    if u in ("", "OPEN", "NONE", "ESS"): return "open"
    return "unknown"


def normalise(raw):
    """-> (aps, free): aps = [ {bssid, ssid, band, rssi, security, vendor, clients:[mac...]} ] in first-seen order, free = [mac...]"""
    m = {}
    for i, a in enumerate(raw.get("aps") or []):
        if not isinstance(a, dict):
            continue
        b = a.get("bssid")
        bssid = mac(b) if b is not None and str(b).strip() != "" else "ap%d" % i
        ch, fr = num(a.get("channel")), num(a.get("freq"))
        r = num(a.get("rssi"))
        v = ctl(a.get("vendor"), 48).strip() if isinstance(a.get("vendor"), str) else None
        ap = {"bssid": bssid, "ssid": ctl(a.get("ssid"), 32), "channel": ch, "freq": fr, "band": band_of(a.get("band"), fr, ch),
              "rssi": None if r is None else max(-120.0, min(0.0, r)), "security": ctl(a.get("security"), 48), "vendor": v or None, "clients": [],
              "akm": strs(a.get("akm"), 12, 24),
              "cipher": {"pairwise": strs(a["cipher"].get("pairwise"), 8, 16) or []} if isinstance(a.get("cipher"), dict) else None}
        for j, c in enumerate(a.get("clients") if isinstance(a.get("clients"), list) else []):
            if isinstance(c, dict):
                cm = c.get("mac")
                ap["clients"].append(mac(cm) if cm is not None and str(cm).strip() != "" else bssid + ":c%d" % j)
        p = m.get(bssid)
        if p is None:
            m[bssid] = ap
            continue
        if ap["rssi"] is not None and (p["rssi"] is None or ap["rssi"] > p["rssi"]):
            p["rssi"] = ap["rssi"]
        if not p["ssid"] and ap["ssid"]:
            p["ssid"] = ap["ssid"]
        for k in ("channel", "freq", "security", "vendor", "akm", "cipher"):   # the page fills these from a later duplicate too
            if p[k] in (None, "") and ap[k] not in (None, ""):
                p[k] = ap[k]
        if p["band"] == "unknown" and ap["band"] != "unknown":
            p["band"] = ap["band"]
        for c in ap["clients"]:
            if c not in p["clients"]:
                p["clients"].append(c)
    assoc, aps = set(), []
    for ap in m.values():
        if ap["rssi"] is None:
            ap["rssi"] = -75.0
        uniq = []
        for c in ap["clients"]:
            if c not in assoc:
                assoc.add(c)
                uniq.append(c)
        ap["clients"] = uniq
        aps.append(ap)
    free, seen = [], set()
    for j, c in enumerate(raw.get("unassociated") if isinstance(raw.get("unassociated"), list) else []):
        if not isinstance(c, dict):
            continue
        cm = c.get("mac")
        x = mac(cm) if cm is not None and str(cm).strip() != "" else "free%d" % j
        if x in assoc or x in seen:
            continue
        seen.add(x)
        free.append(x)
    return aps, free


# ---------------------------------------------------------------- the model: devices (G1) and ESS sets (G2)
def octets(bssid):
    p = bssid.split(":")
    if len(p) != 6 or not all(re.fullmatch(r"[0-9a-f]{1,2}", x) for x in p):
        return None
    return [int(x, 16) for x in p]


def ssid_base(s):
    x = s.lower()
    x = re.sub(r"[-_ ]?(2\.?4|5|6)\s?g(hz)?$", "", x, flags=re.I)
    x = re.sub(r"[-_ ](2\.?4|5|6)$", "", x)
    return x.strip()


def linked(a, b):
    """The pair rule. a, b = (ap, octets). Same OUI + bytes 3..4 are the precondition of every mechanism."""
    (pa, ba), (pb, bb) = a, b
    if ba[:5] != bb[:5]:
        return False
    ad = abs(bb[5] - ba[5])
    if ad != 0 and ad <= DEVICE["seqTight"]:
        return True                                   # consecutive BSSIDs: one box hands out adjacent MACs
    if pa["band"] == pb["band"]:                      # one radio: virtual SSIDs
        return (ba[5] >> DEVICE["mbssidBits"]) == (bb[5] >> DEVICE["mbssidBits"]) or ad <= DEVICE["seqWindow"]
    if pa["band"] == "unknown" or pb["band"] == "unknown" or ad > DEVICE["radioWindow"]:
        return False                                  # two radios of one box: close byte 5 AND a hint
    sa, sb = ssid_base(pa["ssid"]), ssid_base(pb["ssid"])
    return (sa != "" and sa == sb) or (pa["vendor"] is not None and pa["vendor"] == pb["vendor"])


def model(raw):
    aps, free = normalise(raw)
    by_id = {a["bssid"]: a for a in aps}
    cand = []
    for a in aps:
        o = octets(a["bssid"])
        if o is None or (o[0] & 2):                   # synthetic id, or locally administered / randomised: no device logic
            continue
        cand.append((a, o))
    cand.sort(key=lambda t: t[0]["bssid"])
    par = list(range(len(cand)))

    def find(i):
        while par[i] != i:
            par[i] = par[par[i]]
            i = par[i]
        return i
    for i in range(len(cand)):
        for j in range(i + 1, len(cand)):
            if linked(cand[i], cand[j]):
                x, y = find(i), find(j)
                if x != y:
                    par[max(x, y)] = min(x, y)
    groups = {}
    for i in range(len(cand)):
        groups.setdefault(find(i), []).append(cand[i][0]["bssid"])
    devices = sorted([sorted(g) for g in groups.values() if len(g) >= 2], key=lambda g: g[0])
    dev_of = {a["bssid"]: None for a in aps}
    for g in devices:
        for b in g:
            dev_of[b] = g[0]
    # ESS: the same trimmed SSID on >= 2 DISTINCT devices (a BSSID outside every cluster is a device of its own)
    by_ssid = {}
    for a in aps:
        k = a["ssid"].strip()
        if k:
            by_ssid.setdefault(k, []).append(a)
    ess = []
    for k, mem in by_ssid.items():
        dset = {dev_of[a["bssid"]] or a["bssid"] for a in mem}
        if len(dset) >= 2:
            ids = sorted(a["bssid"] for a in mem)
            lead = None
            for i in ids:                             # strongest member, the first one in BSSID order on a tie
                if lead is None or by_id[i]["rssi"] > by_id[lead]["rssi"]:
                    lead = i
            ess.append({"ssid": k, "id": ids[0], "deviceIds": sorted(dset), "apCount": len(ids), "lead": lead})
    ess.sort(key=lambda e: e["id"])
    grp = sum(1 for k, mem in by_ssid.items() if len(mem) >= 2)
    sec = dict.fromkeys(SEC_KEYS, 0)
    for a in aps:
        sec[sec_class(a["security"], a["akm"], a["cipher"])] += 1
    band_t = dict.fromkeys(BANDS, 0)
    for a in aps:
        if a["band"] in band_t:
            band_t[a["band"]] += 1
    exp = {"apIds": sorted(by_id), "devicesList": devices, "essList": ess, "deviceOf": dev_of, "raw": {
        "aps": len(raw.get("aps") or []), "assoc": sum(len(a.get("clients") or []) for a in (raw.get("aps") or []) if isinstance(a, dict)),
        "free": len(raw.get("unassociated") or [])}}
    for mode in ("off", "on"):
        fold = set()
        if mode == "on":
            for e in ess:
                fold.update(x["bssid"] for x in by_ssid[e["ssid"]] if x["bssid"] != e["lead"])   # every member but the lead is folded away
        bands = dict.fromkeys(BANDS, 0)
        for a in aps:
            if a["band"] in bands and a["bssid"] not in fold:
                bands[a["band"]] += 1
        exp[mode] = {"apsTotal": len(aps), "aps": len(aps) - len(fold), "assoc": sum(len(a["clients"]) for a in aps), "free": len(free),
                     "clients": sum(len(a["clients"]) for a in aps) + len(free), "groups": grp, "bands": bands, "bandsTotal": dict(band_t),
                     "security": dict(sec), "alarms": sec["open"] + sec["wep"], "hidden": sum(1 for a in aps if a["ssid"] == ""),
                     "devices": len(devices), "essMerged": len(ess) if mode == "on" else 0}
    return exp


# ---------------------------------------------------------------- the hand documents: edge cases with hand-computed answers
def _ap(bssid, ssid, band, ch, sec="WPA2", vendor=None, rssi=-60, clients=()):
    o = {"bssid": bssid, "ssid": ssid, "band": band, "channel": ch, "rssi": rssi, "security": sec, "clients": [{"mac": c} for c in clients]}
    if vendor:
        o["vendor"] = vendor
    return o


def _doc(aps, unassoc=()):
    return {"generated": 1789300000, "center": {"label": "hand"}, "source": "recon-db", "aps": list(aps), "unassociated": [{"mac": c} for c in unassoc]}


# name -> (document, expected). expected = {"devices": [[members]...], "ess": [(ssid, apCount, ndevices)...], and the counts}: written
# by hand from the rules, NOT produced by model(); the selftest holds model() to them (they anchor the model against a shared misreading).
HAND = {
    # two consecutive BSSIDs of one OUI on two bands (byte 5 differs by 1) are one device; different SSIDs: no group, no ESS
    "hand-consecutive": (_doc([_ap("44:4e:6d:00:00:10", "Alpha", "2.4", 6), _ap("44:4e:6d:00:00:11", "Beta", "5", 44)]),
                         {"devices": [["44:4e:6d:00:00:10", "44:4e:6d:00:00:11"]], "ess": [], "apsTotal": 2, "assoc": 0, "free": 0, "groups": 0}),
    # the same SSID on two different boxes is an ESS of 2 APs / 2 devices and one group; folded (essMerge) only the lead stays
    "hand-ess": (_doc([_ap("44:4e:6d:00:00:10", "Net", "5", 36, rssi=-70), _ap("58:97:bd:00:00:01", "Net", "5", 40, rssi=-50)]),
                 {"devices": [], "ess": [("Net", 2, 2)], "apsTotal": 2, "assoc": 0, "free": 0, "groups": 1}),
    # a locally administered pair (U/L bit) with consecutive BSSIDs is NOT a device
    "hand-local": (_doc([_ap("a2:11:22:aa:bb:10", "Rand-1", "2.4", 6), _ap("a2:11:22:aa:bb:11", "Rand-2", "2.4", 6)]),
                   {"devices": [], "ess": [], "apsTotal": 2, "assoc": 0, "free": 0, "groups": 0}),
    # duplicate BSSID (upper case, dashes) merges into one AP; a client on two APs counts once (first wins); a free client that
    # is associated elsewhere is not free: 1 AP, 3 associated (c1 c2 c3), 1 free (c9)
    "hand-dups": (_doc([_ap("44:4E:6D:00:00:10", "Dup", "5", 36, clients=["02:00:00:00:00:01", "02:00:00:00:00:02"]),
                        _ap("44-4e-6d-00-00-10", "Dup", "5", 36, clients=["02:00:00:00:00:02", "02:00:00:00:00:03"])],
                       ["02:00:00:00:00:01", "02:00:00:00:00:09", "02:00:00:00:00:09"]),
                  {"devices": [], "ess": [], "apsTotal": 1, "assoc": 3, "free": 1, "groups": 0}),
    # one radio (same band): byte 5 :40 and :43 share the high 5 bits (>> 3 equal) -> one device; :48 is 8 away, other block -> alone
    "hand-vbssid": (_doc([_ap("50:c7:bf:ee:00:40", "O-Main", "5", 149), _ap("50:c7:bf:ee:00:43", "O-Guest", "5", 149), _ap("50:c7:bf:ee:00:48", "O-IoT", "5", 149)]),
                    {"devices": [["50:c7:bf:ee:00:40", "50:c7:bf:ee:00:43"]], "ess": [], "apsTotal": 3, "assoc": 0, "free": 0, "groups": 0}),
    # two radios (other band): byte 5 16 apart AND the SSID base equal ("Foo" / "Foo_5G") -> one device; 17 apart -> not
    "hand-radios": (_doc([_ap("44:4e:6d:00:01:10", "Foo", "2.4", 6), _ap("44:4e:6d:00:01:20", "Foo_5G", "5", 44),
                          _ap("44:4e:6d:00:02:10", "Bar", "2.4", 6), _ap("44:4e:6d:00:02:21", "Bar_5G", "5", 44)]),
                    {"devices": [["44:4e:6d:00:01:10", "44:4e:6d:00:01:20"]], "ess": [], "apsTotal": 4, "assoc": 0, "free": 0, "groups": 0}),
    # a client listed on two DIFFERENT APs belongs to the first one only: 3 associated (c1 c2 c3), not 4
    "hand-roam": (_doc([_ap("44:4e:6d:00:00:10", "Roam-A", "5", 36, clients=["02:00:00:00:00:01", "02:00:00:00:00:02"]),
                        _ap("58:97:bd:00:00:01", "Roam-B", "5", 40, clients=["02:00:00:00:00:02", "02:00:00:00:00:03"])]),
                  {"devices": [], "ess": [], "apsTotal": 2, "assoc": 3, "free": 0, "groups": 0}),
    # an ESS on two boxes with EQUAL signal: the lead is the first member in BSSID order (44:4e:.. on 2.4 GHz), the 5 GHz one folds away
    "hand-tie": (_doc([_ap("58:97:bd:00:00:01", "Tie", "5", 36, rssi=-60), _ap("44:4e:6d:00:00:10", "Tie", "2.4", 6, rssi=-60)]),
                 {"devices": [], "ess": [("Tie", 2, 2)], "apsTotal": 2, "assoc": 0, "free": 0, "groups": 1, "bands_on": {"2.4": 1, "5": 0, "6": 0}}),
    # empty SSID = hidden (2 APs), a blank "  " SSID is not hidden but has no group key; no group, no ESS from either
    "hand-hidden": (_doc([_ap("44:4e:6d:00:00:10", "", "2.4", 6), _ap("58:97:bd:00:00:01", "", "5", 36), _ap("9c:3d:cf:00:00:01", "  ", "5", 40)]),
                    {"devices": [], "ess": [], "apsTotal": 3, "assoc": 0, "free": 0, "groups": 0, "hidden": 2}),
    # security words and bands: WPA2/WPA3 -> wpa3-transition, OWE -> owe, WEP -> wep, Secured -> wpa, "" -> open, other -> unknown;
    # 2412 MHz -> 2.4, 5180 -> 5, 5955 -> 6, neither channel nor freq nor band -> unknown (counted in no band)
    "hand-sec": ({"generated": 1789300000, "center": {"label": "hand"}, "source": "recon-db", "unassociated": [], "aps": [
        {"bssid": "44:4e:6d:01:00:01", "ssid": "S1", "freq": 2412, "security": "WPA2/WPA3", "rssi": -50, "clients": []},
        {"bssid": "58:97:bd:02:00:01", "ssid": "S2", "freq": 5180, "security": "OWE", "rssi": -50, "clients": []},
        {"bssid": "9c:3d:cf:03:00:01", "ssid": "S3", "freq": 5955, "security": "WEP", "rssi": -50, "clients": []},
        {"bssid": "24:de:c6:04:00:01", "ssid": "S4", "channel": 6, "security": "Secured", "rssi": -50, "clients": []},
        {"bssid": "f0:9f:c2:05:00:01", "ssid": "S5", "security": "", "rssi": -50, "clients": []},
        {"bssid": "b8:ec:a3:06:00:01", "ssid": "S6", "band": "5GHz", "security": "Weird", "rssi": -50, "clients": []}]},
               {"devices": [], "ess": [], "apsTotal": 6, "assoc": 0, "free": 0, "groups": 0, "alarms": 2,
                "security": {"open": 1, "wep": 1, "wpa": 1, "wpa2": 0, "wpa3": 0, "owe": 1, "enterprise": 0, "wpa3-transition": 1, "tkip-weak": 0, "unknown": 1}, "bands": {"2.4": 2, "5": 2, "6": 1}}),
    # the collector's AKM/cipher detail decides a class the label alone does not: 802.1X / FILS AKM -> enterprise, SAE + PSK -> transition,
    # an OWE-only AKM -> owe although the label says WPA3 (libwifi sets the WPA3 class bit for OWE), TKIP as the ONLY pairwise cipher -> tkip-weak
    # (TKIP next to CCMP is not), "Enterprise" in the label -> enterprise; a duplicate BSSID fills the akm the first entry lacked
    "hand-akm": ({"generated": 1789300000, "center": {"label": "hand"}, "source": "recon-db", "unassociated": [], "aps": [
        {"bssid": "44:4e:6d:0a:00:01", "ssid": "A1", "channel": 6, "security": "WPA2", "akm": ["1x"], "rssi": -50, "clients": []},
        {"bssid": "58:97:bd:0b:00:01", "ssid": "A2", "channel": 6, "security": "WPA2", "akm": ["sae", "psk"], "rssi": -50, "clients": []},
        {"bssid": "9c:3d:cf:0c:00:01", "ssid": "A3", "channel": 6, "security": "WPA3", "akm": ["owe"], "rssi": -50, "clients": []},
        {"bssid": "24:de:c6:0d:00:01", "ssid": "A4", "channel": 6, "security": "WPA2", "cipher": {"group": "tkip", "pairwise": ["tkip"]}, "rssi": -50, "clients": []},
        {"bssid": "f0:9f:c2:0e:00:01", "ssid": "A5", "channel": 6, "security": "WPA2", "cipher": {"pairwise": ["tkip", "ccmp"]}, "rssi": -50, "clients": []},
        {"bssid": "b8:ec:a3:0f:00:01", "ssid": "A6", "channel": 6, "security": "WPA2 Enterprise", "rssi": -50, "clients": []},
        {"bssid": "3c:22:fb:10:00:01", "ssid": "A7", "channel": 6, "security": "WPA2", "rssi": -50, "clients": []},
        {"bssid": "3c:22:fb:10:00:01", "ssid": "A7", "channel": 6, "security": "WPA2", "akm": ["fils-sha256"], "rssi": -60, "clients": []}]},
                 {"devices": [], "ess": [], "apsTotal": 7, "assoc": 0, "free": 0, "groups": 0, "alarms": 0,
                  "security": {"open": 0, "wep": 0, "wpa": 0, "wpa2": 1, "wpa3": 0, "owe": 1, "enterprise": 3, "wpa3-transition": 1, "tkip-weak": 1, "unknown": 0}}),
    # the vBSSID window is inclusive: byte 5 exactly 4 apart (:3c/:40, different >>3 block) is one device, 5 apart (:3c/:41) is not
    "hand-seqwin": (_doc([_ap("44:4e:6d:00:03:3c", "Q-A", "5", 36), _ap("44:4e:6d:00:03:40", "Q-B", "5", 36),
                          _ap("44:4e:6d:00:04:3c", "Q-C", "5", 36), _ap("44:4e:6d:00:04:41", "Q-D", "5", 36)]),
                    {"devices": [["44:4e:6d:00:03:3c", "44:4e:6d:00:03:40"]], "ess": [], "apsTotal": 4, "assoc": 0, "free": 0, "groups": 0}),
    # the SSID base strips a separated band suffix even without a "g": "X" / "X-5" is one box (byte 5 :10/:20), "Y" / "Y5" is not
    "hand-suffix": (_doc([_ap("44:4e:6d:00:05:10", "X", "2.4", 6), _ap("44:4e:6d:00:05:20", "X-5", "5", 44),
                          _ap("44:4e:6d:00:06:10", "Y", "2.4", 6), _ap("44:4e:6d:00:06:20", "Y5", "5", 44)]),
                    {"devices": [["44:4e:6d:00:05:10", "44:4e:6d:00:05:20"]], "ess": [], "apsTotal": 4, "assoc": 0, "free": 0, "groups": 0}),
    # the band from the frequency alone: 5924 MHz is 5 GHz, 5925 and 5930 MHz are 6 GHz
    "hand-6ghz": ({"generated": 1789300000, "center": {"label": "hand"}, "source": "recon-db", "unassociated": [], "aps": [
        {"bssid": "44:4e:6d:07:00:01", "ssid": "F1", "freq": 5924, "security": "WPA2", "rssi": -50, "clients": []},
        {"bssid": "58:97:bd:08:00:01", "ssid": "F2", "freq": 5925, "security": "WPA2", "rssi": -50, "clients": []},
        {"bssid": "9c:3d:cf:09:00:01", "ssid": "F3", "freq": 5930, "security": "WPA2", "rssi": -50, "clients": []}]},
                   {"devices": [], "ess": [], "apsTotal": 3, "assoc": 0, "free": 0, "groups": 0, "bands": {"2.4": 0, "5": 1, "6": 2}}),
    # every security word the page knows, one AP each, in the classes the rules give them (checked in the rule order: "wpa2-psk" is wpa2, not
    # wpa), padded and lower case once; open = "", OPEN, NONE, ESS; the six words that decide wpa2/wpa/wpa3 by themselves: RSN, CCMP / TKIP,
    # PSK, WPA / SAE. Distinct OUIs: no device logic. Not a single word may fall to "unknown". A bare TKIP (no CCMP/GCMP) is tkip-weak.
    "hand-secwords": (_doc([_ap("44:4e:6d:%02x:00:01" % (16 + i), "W%d" % i, None, 6, sec=w) for i, w in enumerate(
                            ["RSN", "CCMP", "  wpa2-psk ", "TKIP", "PSK", "WPA", "SAE", "NONE", "ESS", "OPEN"])]),
                      {"devices": [], "ess": [], "apsTotal": 10, "assoc": 0, "free": 0, "groups": 0, "alarms": 3,
                       "security": {"open": 3, "wep": 0, "wpa": 2, "wpa2": 3, "wpa3": 1, "owe": 0, "enterprise": 0, "wpa3-transition": 0, "tkip-weak": 1, "unknown": 0}}),
    # the band of an AP without a band word: from the channel (1..14 -> 2.4, 32..177 -> 5, 178.. -> 6, anything between or below is unknown),
    # from the frequency (>= 2400 -> 2.4, >= 5000 -> 5, below 2400 unknown), the frequency before the channel, the band word before both
    # (also with a space before "GHz"). 15 APs, one per case, distinct OUIs: 2.4 = ch 1, ch 14, 2400 MHz, 4999 MHz (the rule as written: below 5000
    # and from 2400 is 2.4), freq-before-channel (5); 5 = ch 32, ch 177, 5000 MHz, band-word-before-freq (4); 6 = ch 178, ch 233, "6 GHz" (3); unknown = ch 15, ch 31, 2399 MHz (3, in no band)
    "hand-bands": ({"generated": 1789300000, "center": {"label": "hand"}, "source": "recon-db", "unassociated": [], "aps": [
        {"bssid": "44:4e:6d:%02x:00:01" % (32 + i), "ssid": "B%d" % i, "security": "WPA2", "rssi": -50, "clients": [], **kw} for i, kw in enumerate([
            {"channel": 1}, {"channel": 14}, {"freq": 2400}, {"freq": 4999}, {"freq": 2412, "channel": 36},
            {"channel": 32}, {"channel": 177}, {"freq": 5000}, {"band": "5GHz", "freq": 2412},
            {"channel": 178}, {"channel": 233}, {"band": "6 GHz"},
            {"channel": 15}, {"channel": 31}, {"freq": 2399}])]},
                   {"devices": [], "ess": [], "apsTotal": 15, "assoc": 0, "free": 0, "groups": 0, "bands": {"2.4": 5, "5": 4, "6": 3}}),
    # a radio pair needs BOTH bands known: the same box by every other hint (same OUI, byte 5 ten apart, SSID base equal) is NOT one device when
    # the lower AP has no band (pair 1) or the higher AP has none (pair 2)
    "hand-unkband": (_doc([_ap("44:4e:6d:40:00:10", "Zed", None, None), _ap("44:4e:6d:40:00:1a", "Zed_5G", "5", 44),
                           _ap("44:4e:6d:41:00:10", "Yak", "2.4", 6), _ap("44:4e:6d:41:00:1a", "Yak_5G", None, None)]),
                     {"devices": [], "ess": [], "apsTotal": 4, "assoc": 0, "free": 0, "groups": 0, "bands": {"2.4": 1, "5": 1, "6": 0}}),
}


# ---------------------------------------------------------------- the judge
def load_open(path):
    if path == "-":
        return []
    return [l.rstrip("\n").split("|") for l in open(path, encoding="utf-8") if l.strip()]


def compare(name, mode, want, got, add):
    """want = model()[mode] plus the lists, got = the page's observation for that mode."""
    st = got.get("stats") or {}
    for k in FIELDS:
        w, g = want[k], st.get(k, "MISSING")
        if g != w:
            add("%s/%s:stats.%s" % (name, mode, k), "page %s, model %s" % (json.dumps(g), json.dumps(w)))


def judge(rep_f, bundle_f, page_f, open_f, mode):
    why = []

    def note(m):
        if m not in why:
            why.append(m)
    try:
        ev = json.load(open(rep_f, encoding="utf-8")).get("eval") or []
        v = ev[0].get("value") if ev else None
        r = json.loads(v) if isinstance(v, str) else None
        docs = json.load(open(bundle_f, encoding="utf-8"))["oracle"]
    except Exception as e:
        print("no report (%s) -- FAIL" % e)
        return 1
    if not isinstance(r, dict) or not isinstance(r.get("fixtures"), list):
        print("no oracle result (%s) -- FAIL" % (str(v)[:100] if not isinstance(r, dict) else str((r.get("findings") or [""])[0])[:100]))
        return 1
    finds, seen = [], {f["name"]: f for f in r["fixtures"]}
    add = lambda n, w: finds.append((n, w))   # noqa: E731
    for n in (r.get("findings") or []):
        add(n[0], n[1])
    n_fix = n_hand = n_empty = n_dev = n_ess = n_ap = n_cl = n_assoc = n_free = 0
    for name in sorted(docs):
        m = model(docs[name])
        f = seen.get(name)
        if f is None:
            add(name, "the page did not report this document")
            continue
        if name.startswith("hand-"):
            n_hand += 1
        else:
            n_fix += 1
        if not m["apIds"] and docs[name].get("source") == "none":
            n_empty += 1                                          # a "none" document has nothing to count: the only allowed empty one
        elif not m["apIds"]:
            add(name, "the document has no AP: the comparison would be vacuous")
        n_assoc += m["off"]["assoc"]
        n_free += m["off"]["free"]
        for md in ("off", "on"):
            got = (f.get("modes") or {}).get(md)
            if not isinstance(got, dict):
                add("%s/%s" % (name, md), "the page reported nothing for this mode")
                continue
            if got.get("err"):
                add("%s/%s" % (name, md), "load failed: %s" % got["err"])
                continue
            compare(name, md, m[md], got, add)
            if sorted([[d["id"]] + sorted(d["members"]) for d in got.get("devices") or []]) != sorted([[g[0]] + g for g in m["devicesList"]]):
                add("%s/%s:devices()" % (name, md), "page %s, model %s" % (json.dumps([sorted(d["members"]) for d in got.get("devices") or []])[:100], json.dumps(m["devicesList"])[:100]))
            want_e = [[e["ssid"], e["id"], e["deviceIds"], e["apCount"]] for e in m["essList"]]
            got_e = sorted([[e["ssid"], e["id"], e["deviceIds"], e["apCount"]] for e in got.get("ess") or []], key=lambda x: x[1])
            if got_e != want_e:
                add("%s/%s:essClusters()" % (name, md), "page %s, model %s" % (json.dumps(got_e)[:100], json.dumps(want_e)[:100]))
            if sorted(got.get("apIds") or []) != m["apIds"]:
                add("%s/%s:apIds" % (name, md), "page has %d AP nodes, model %d" % (len(got.get("apIds") or []), len(m["apIds"])))
            bad = [b for b, d in (got.get("deviceOf") or {}).items() if m["deviceOf"].get(b, "?") != d]
            if bad:
                add("%s/%s:deviceOf" % (name, md), "%d of %d differ, first %s: page %s, model %s" % (len(bad), len(got.get("deviceOf") or {}), bad[0], (got["deviceOf"] or {}).get(bad[0]), m["deviceOf"].get(bad[0])))
        n_ap += m["on"]["apsTotal"]
        n_cl += m["on"]["clients"]
        n_dev += m["on"]["devices"]
        n_ess += len(m["essList"])
    # the rule constants the model assumes must be the page's
    try:
        src = open(page_f, encoding="utf-8").read()
        mm = re.search(r"const DEVICE = \{([^}]*)\}", src)
        for k, want in DEVICE.items():
            g = re.search(r"\b%s:\s*(\d+)" % k, mm.group(1)) if mm else None
            if not g or int(g.group(1)) != want:
                add("rule constant %s" % k, "page %s, model %d: if the rule changed on purpose, change tools/data-oracle.py DEVICE and the documented ground truth in the same commit" % (g.group(1) if g else "?", want))
    except OSError as e:
        add("rule constants", "page unreadable: %s" % e)
    if mode == "probe":
        # the page copy carries three planted faults (see tools/regress.d/data-oracle.sh): a randomised pair that clusters, an ESS
        # count that needs three devices, clients counted twice when they probe. Exactly these classes may turn red, and all of them.
        want = {"stats.devices", "devices()", "deviceOf", "stats.essMerged", "stats.clients"}
        got_c = {n.split(":", 1)[1] for n, w in finds if ":" in n and not n.startswith("rule ")}
        other = [n for n, w in finds if not (":" in n and n.split(":", 1)[1] in want)]
        for c in sorted(want - got_c):
            note("BLIND: no finding of class %s although the fault is planted" % c)
        for c in sorted(got_c - want):
            note("unplanned class %s" % c)
        for n in other[:2]:
            note("unplanned finding %s" % n[:60])
        print("probe: RED as planted (%d findings in %d classes: %s)%s" % (len(finds), len(got_c), " ".join(sorted(got_c)), " -- FAIL: " + "; ".join(why) if why else ""))
        return 1 if why else 0
    opens, used, new = load_open(open_f), set(), []
    for n, w in finds:
        hit = [i for i, o in enumerate(opens) if fnmatch.fnmatchcase(n, o[0])]
        if hit:
            used.update(hit)
        else:
            new.append((n, w))
    for n, w in new[:3]:
        note("NEW finding %s: %s" % (n[:60], w[:110]))
    if len(new) > 3:
        note("... and %d more new findings" % (len(new) - 3))
    for i, o in enumerate(opens):
        if i not in used:
            note("known-open entry %r no longer found: please remove" % o[0])
    if n_hand < len(HAND):
        note("%d hand documents compared (want %d)" % (n_hand, len(HAND)))
    if n_fix < MIN_FIXTURES:
        note("%d fixtures compared, at least %d are required: the bundle lost fixtures" % (n_fix, MIN_FIXTURES))
    if len(FIELDS) < MIN_FIELDS:
        note("the judge compares %d fields, at least %d are required: a counter fell out of FIELDS" % (len(FIELDS), MIN_FIELDS))
    if n_dev < 1 or n_ess < 1 or n_assoc < 1 or n_free < 1:
        note("all documents together carry %d device clusters, %d ESS sets, %d associated and %d free clients: a count that is never above 0 was not exercised" % (n_dev, n_ess, n_assoc, n_free))
    print("%d fixtures + %d hand documents (%d empty) x essMerge off/on: page = model in %d fields each; %d APs, %d clients, %d device clusters, %d ESS sets compared, %d s, %d known open%s" % (
        n_fix, n_hand, n_empty, len(FIELDS), n_ap, n_cl, n_dev, n_ess, round((r.get("ms") or 0) / 1000.0), len(opens), " -- FAIL: " + "; ".join(why) if why else ""))
    return 1 if why else 0


# ---------------------------------------------------------------- the ground truth of devices.json
def truth(dev_f, gen_f, readme_f):
    why = []
    try:
        m = model(json.load(open(dev_f, encoding="utf-8")))
        src = open(gen_f, encoding="utf-8").read()
    except (OSError, ValueError) as e:      # a missing or broken input is "cannot say" (exit 2), never a verdict of the ground truth
        print("ground truth not checkable: %s -- CANNOT CHECK" % str(e)[:120])
        return 2
    head = src[:src.find("def build_devices_doc")]
    t = {}
    for key, pat in (("aps", r"total APs \.+ (\d+)"), ("devices", r"device clusters \(>= 2 members\) \.+ (\d+)"),
                     ("ess", r"ESS sets \(.*?\) \.+ (\d+)"), ("fold", r"Sum\(members - 1\) over ESS sets \.+ (\d+)")):
        g = re.search(pat, head)
        if g:
            t[key] = int(g.group(1))
    for key in ("aps", "devices", "ess", "fold"):
        if key not in t:
            print("ground truth not readable: %r missing in the header of %s -- FAIL" % (key, os.path.basename(gen_f)))
            return 1
    ml = re.search(r"members sorted =\s*\n#\s*(\[[^\]]*\])", head)
    tri = re.findall(r"[0-9a-f]{2}(?::[0-9a-f]{2}){5}", ml.group(1)) if ml else []
    if len(tri) < 2:
        print("ground truth not readable: the sorted member list of the tri-band device is missing -- FAIL")
        return 1
    got = {"aps": len(m["apIds"]), "devices": len(m["devicesList"]), "ess": len(m["essList"]), "fold": sum(e["apCount"] - 1 for e in m["essList"])}
    for k in ("aps", "devices", "ess", "fold"):
        if got[k] != t[k]:
            why.append("%s: model %d, documented %d" % (k, got[k], t[k]))
    if [g for g in m["devicesList"] if g[0] == tri[0]] != [tri]:
        why.append("the tri-band device %s is not %s" % (tri[0], ",".join(tri)))
    rd = "no numbers"
    try:
        g = re.search(r"`devices\.json`[^\n]*?(\d+) APs[^\n]*?(\d+) device clusters, (\d+) roaming ESS", open(readme_f, encoding="utf-8").read())
    except (OSError, ValueError):
        g = None
    if g:
        rd = "agrees"
        if tuple(int(x) for x in g.groups()) != (t["aps"], t["devices"], t["ess"]):
            rd = "differs"
            why.append("README says %s APs / %s clusters / %s ESS, the generator header %d/%d/%d" % (g.group(1), g.group(2), g.group(3), t["aps"], t["devices"], t["ess"]))
    print("devices.json: %d APs, %d device clusters, %d ESS sets, %d APs folded (visible %d -> %d), %s the header of gen-testdata.py (README %s)%s" % (
        got["aps"], got["devices"], got["ess"], got["fold"], got["aps"], m["on"]["aps"], "differs from" if why else "equal to", rd, " -- FAIL: " + "; ".join(why) if why else ""))
    return 1 if why else 0


# ---------------------------------------------------------------- bundle
def bundle(fix_dir, out_f):
    o = {}
    for fn in sorted(os.listdir(fix_dir)):
        if fn.endswith(".json"):
            o[fn[:-5]] = json.load(open(os.path.join(fix_dir, fn), encoding="utf-8"))
    for k, (d, _e) in HAND.items():
        o[k] = d
    json.dump({"generated": 1789300000, "center": {"label": "oracle"}, "source": "none", "note": "oracle carrier", "aps": [], "unassociated": [], "oracle": o}, open(out_f, "w"))
    return 0


# ---------------------------------------------------------------- selftest
def observe(doc):
    """What a page that agrees with the model would report (for the dummy runs of the judge)."""
    m = model(doc)
    modes = {}
    for md in ("off", "on"):
        modes[md] = {"stats": dict(m[md]), "devices": [{"id": g[0], "members": list(g)} for g in m["devicesList"]],
                     "ess": [{"ssid": e["ssid"], "id": e["id"], "deviceIds": list(e["deviceIds"]), "apCount": e["apCount"]} for e in m["essList"]],
                     "apIds": list(m["apIds"]), "deviceOf": dict(m["deviceOf"])}
    return modes


def selftest():
    bad, n = [], 0

    def case(label, ok):
        nonlocal n
        n += 1
        if not ok:
            bad.append(label)
    # 1. the model against the hand-computed answers
    for k, (d, e) in HAND.items():
        m = model(d)
        ess = [(x["ssid"], x["apCount"], len(x["deviceIds"])) for x in m["essList"]]
        case(k + " devices", m["devicesList"] == e["devices"])
        case(k + " ess", ess == e["ess"])
        case(k + " counts", (m["off"]["apsTotal"], m["off"]["assoc"], m["off"]["free"], m["off"]["groups"]) == (e["apsTotal"], e["assoc"], e["free"], e["groups"]))
        for f in ("hidden", "alarms", "security", "bands"):
            if f in e:
                case(k + " " + f, m["off"][f] == e[f])
        if "bands_on" in e:
            case(k + " bands with essMerge on", m["on"]["bands"] == e["bands_on"])
    m = model(HAND["hand-ess"][0])
    case("hand-ess folded: 2 APs -> 1 visible, lead is the stronger one", (m["on"]["aps"], m["on"]["essMerged"], m["off"]["essMerged"], m["essList"][0]["lead"]) == (1, 1, 0, "58:97:bd:00:00:01"))
    case("hand-ess band counts follow the fold (both 5 GHz)", m["on"]["bands"]["5"] == 1 and m["off"]["bands"]["5"] == 2)
    # 2. the judge against dummy runs
    d = tempfile_dir()
    bf = os.path.join(d, "b.json")
    bundle(os.path.join(HERE, "..", "tests", "fixtures"), bf)
    docs = json.load(open(bf))["oracle"]
    page = os.path.join(d, "page.html")     # a stand-in that only carries the rule constants: the selftest must not depend on the real page
    open(page, "w").write("const DEVICE = { %s, essExpandMs: 6000 };\n" % ", ".join("%s: %d" % kv for kv in DEVICE.items()))

    last = [""]           # the label line of the last run(): a few cases ask WHY it was red, so that two guards cannot cover for each other

    def run(mutate, mode="run", open_txt=None, only=None, bf2=None):
        fx = []
        for name in sorted(only or docs):
            fx.append({"name": name, "modes": observe(docs[name])})
        rep = {"ms": 1000, "fixtures": fx, "findings": []}
        mutate(rep)
        rf, of = os.path.join(d, "r.json"), "-"
        json.dump({"eval": [{"value": json.dumps(rep)}]}, open(rf, "w"))
        if open_txt is not None:
            of = os.path.join(d, "o.txt")
            open(of, "w").write(open_txt)
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = judge(rf, bf2 or bf, page, of, mode)
        last[0] = buf.getvalue()
        return rc

    def fx_of(rep, name):
        return [f for f in rep["fixtures"] if f["name"] == name][0]
    rich = "devices"          # the fixture with clusters and ESS sets
    case("judge: a page that agrees is green", run(lambda r: None) == 0)
    case("judge: stats.assoc off by one is red", run(lambda r: fx_of(r, "many-clients")["modes"]["off"]["stats"].__setitem__("assoc", fx_of(r, "many-clients")["modes"]["off"]["stats"]["assoc"] + 1)) == 1)
    case("judge: stats.free off by one is red", run(lambda r: fx_of(r, "few-clients")["modes"]["on"]["stats"].__setitem__("free", 0)) == 1)
    case("judge: a lost device cluster is red", run(lambda r: fx_of(r, rich)["modes"]["off"]["devices"].pop()) == 1)
    case("judge: a device with a member less is red", run(lambda r: fx_of(r, rich)["modes"]["off"]["devices"][0]["members"].pop()) == 1)
    case("judge: a wrong deviceOf is red", run(lambda r: fx_of(r, rich)["modes"]["off"]["deviceOf"].__setitem__("44:4e:6d:aa:bb:10", None)) == 1)
    case("judge: a wrong ESS apCount is red", run(lambda r: fx_of(r, rich)["modes"]["on"]["ess"][0].__setitem__("apCount", 99)) == 1)
    case("judge: essMerged not counted in the on mode is red", run(lambda r: fx_of(r, rich)["modes"]["on"]["stats"].__setitem__("essMerged", 0)) == 1)
    case("judge: an AP node too many is red", run(lambda r: fx_of(r, "single-ap")["modes"]["off"]["apIds"].append("zz")) == 1)
    case("judge: a missing mode is red", run(lambda r: fx_of(r, rich)["modes"].pop("on")) == 1)
    case("judge: a document the page did not report is red", run(lambda r: r["fixtures"].pop()) == 1)
    case("judge: an empty run is red", run(lambda r: r.update(fixtures=[])) == 1)
    case("judge: a load error is red", run(lambda r: fx_of(r, rich)["modes"]["off"].update(err="boom")) == 1)
    case("judge: a setup finding is red", run(lambda r: r["findings"].append(["setup", "STARCHORUS._internals missing"])) == 1)
    open(page, "w").write("const DEVICE = { mbssidBits: 3, seqWindow: 5, radioWindow: 16, seqTight: 2 };\n")
    case("judge: a rule constant that moved in the page is red", run(lambda r: None) == 1)
    open(page, "w").write("const DEVICE = { %s, essExpandMs: 6000 };\n" % ", ".join("%s: %d" % kv for kv in DEVICE.items()))
    case("judge: a missing stats field is red", run(lambda r: fx_of(r, "legacy")["modes"]["off"]["stats"].pop("security")) == 1)

    def bump(r, mode, k):
        st = fx_of(r, "many-clients")["modes"][mode]["stats"]
        if isinstance(st[k], dict):
            st[k] = dict(st[k])
            st[k][sorted(st[k])[0]] += 1
        else:
            st[k] += 1
    # every field of FIELDS, in both modes, on its own: a field the judge stopped comparing must not go unseen. The cases are derived from FIELDS
    # itself, so the floor below is what catches a field that fell out of the list (the loop would just have one case less).
    case("judge: at least MIN_FIELDS (%d) fields are compared, %d are" % (MIN_FIELDS, len(FIELDS)), len(FIELDS) >= MIN_FIELDS)
    for k in FIELDS:
        for md in ("off", "on"):
            case("judge: stats.%s off by one in mode %s is red and named" % (k, md), run(lambda r, k=k, md=md: bump(r, md, k)) == 1 and ("stats.%s: " % k) in last[0])
    sc = lambda r: fx_of(r, "many-clients")["modes"]["off"]["stats"].__setitem__("assoc", 1)   # noqa: E731
    # the guards against a vacuous run, each asked for its own message (a second guard must not cover for the first)
    hand_only = os.path.join(d, "hand.json")
    json.dump({"oracle": {k: v[0] for k, v in HAND.items()}}, open(hand_only, "w"))
    run(lambda r: None, only=list(HAND), bf2=hand_only)
    case("judge: only hand documents (no fixture, but hand documents complete) is not flagged as a missing hand document", "hand documents compared" not in last[0])
    case("judge: only hand documents (no fixture at all) is red and says so", run(lambda r: None, only=list(HAND), bf2=hand_only) == 1 and "fixtures compared" in last[0])
    fewer = os.path.join(d, "fewer.json")     # one fixture lost from the bundle (and from the run): the run still agrees with itself, but not with the floor
    lost = sorted(k for k in docs if not k.startswith("hand-"))[0]
    json.dump({"oracle": {k: v for k, v in docs.items() if k != lost}}, open(fewer, "w"))
    case("judge: a bundle that lost one fixture is red and says so", run(lambda r: None, only=[k for k in docs if k != lost], bf2=fewer) == 1 and "fixtures compared" in last[0])
    case("judge: the full bundle does not trip the fixture floor (%d fixtures, floor %d)" % (sum(1 for k in docs if not k.startswith("hand-")), MIN_FIXTURES),
         run(lambda r: None) == 0 and "fixtures compared" not in last[0])
    nohand = os.path.join(d, "nohand.json")
    json.dump({"oracle": {k: v for k, v in docs.items() if not k.startswith("hand-")}}, open(nohand, "w"))
    case("judge: a run without the hand documents is red and says so", run(lambda r: None, only=[k for k in docs if not k.startswith("hand-")], bf2=nohand) == 1 and "hand documents compared" in last[0])
    zero = os.path.join(d, "zero.json")     # documents that carry no device cluster, no ESS set, no client at all: the counts would never be above 0
    zdocs = {"single-ap": docs["single-ap"], "active": docs["active"]}
    json.dump({"oracle": zdocs}, open(zero, "w"))
    case("judge: documents that never exercise a count are red and say so", run(lambda r: None, only=list(zdocs), bf2=zero) == 1 and "never above 0" in last[0])
    case("judge: a listed known-open finding is green", run(sc, open_txt="many-clients/off:stats.assoc|page|dummy\n") == 0)
    case("judge: a listed finding that is gone is red (please remove)", run(lambda r: None, open_txt="many-clients/off:stats.assoc|page|dummy\n") == 1)
    case("judge: a new finding beside a listed one is red", run(lambda r: (sc(r), fx_of(r, "legacy")["modes"]["on"]["stats"].__setitem__("free", 0)), open_txt="many-clients/off:stats.assoc|page|dummy\n") == 1)

    def plant(r):   # the probe's three planted faults, as the page copy would show them
        x = fx_of(r, rich)["modes"]
        x["off"]["stats"]["devices"] = 4
        x["off"]["devices"].append({"id": "a2:11:22:aa:bb:10", "members": ["a2:11:22:aa:bb:10", "a2:11:22:aa:bb:11"]})
        x["off"]["deviceOf"]["a2:11:22:aa:bb:10"] = "a2:11:22:aa:bb:10"
        x["on"]["stats"]["essMerged"] = 1
        fx_of(r, "field-probes")["modes"]["off"]["stats"]["clients"] += 5
    case("judge probe: the planted classes, and only those, are green", run(plant, "probe") == 0)
    case("judge probe: a page that agrees is BLIND (red)", run(lambda r: None, "probe") == 1)
    case("judge probe: one planted class missing is BLIND (red)", run(lambda r: (plant(r), fx_of(r, "field-probes")["modes"]["off"]["stats"].__setitem__("clients", model(docs["field-probes"])["off"]["clients"])), "probe") == 1)
    case("judge probe: an unplanned class is red", run(lambda r: (plant(r), fx_of(r, "legacy")["modes"]["off"]["stats"].__setitem__("free", 0)), "probe") == 1)
    # 3. the ground truth against broken copies of devices.json
    dev = json.load(open(os.path.join(HERE, "..", "tests", "fixtures", "devices.json"), encoding="utf-8"))
    gen, rd = os.path.join(HERE, "gen-testdata.py"), os.path.join(HERE, "README.md")

    def t(mut):
        dd = json.loads(json.dumps(dev))
        mut(dd)
        f = os.path.join(d, "dev.json")
        json.dump(dd, open(f, "w"))
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = truth(f, gen, rd)
        last[0] = buf.getvalue()
        return rc
    case("truth: the real devices.json equals the documented ground truth", t(lambda x: None) == 0)
    # each broken copy is asked for the check that has to catch it (the checks overlap; one must not cover for another)
    case("truth: a cluster member removed (dual-band box loses its second radio) is red for the cluster count",
         t(lambda x: x["aps"].__delitem__([a["bssid"] for a in x["aps"]].index("78:8a:20:cc:dd:21"))) == 1 and "devices: model 2, documented 3" in last[0])
    case("truth: one AP more is red for the AP count", t(lambda x: x["aps"].append(_ap("00:11:22:33:44:55", "Extra", "5", 36))) == 1 and "aps: model 19, documented 18" in last[0])
    case("truth: a MBSSID member removed is red for the tri-band/AP checks", t(lambda x: x["aps"].__delitem__([a["bssid"] for a in x["aps"]].index("50:c7:bf:ee:00:43"))) == 1 and "aps: model 17, documented 18" in last[0])
    case("truth: an ESS member renamed is red for the ESS count", t(lambda x: x["aps"][[a["bssid"] for a in x["aps"]].index("b8:ec:a3:05:00:01")].__setitem__("ssid", "Other")) == 1 and "ess: model 1, documented 2" in last[0])
    case("truth: the tri-band device changed shape is red for its member list", t(lambda x: x["aps"].__delitem__([a["bssid"] for a in x["aps"]].index("44:4e:6d:aa:bb:12"))) == 1 and "the tri-band device" in last[0])
    # the reading of the documentation fails closed, and a README that states other numbers is red
    def t2(gen_txt, readme_txt):
        gf, rf = os.path.join(d, "gen.py"), os.path.join(d, "readme.md")
        open(gf, "w").write(gen_txt)
        open(rf, "w").write(readme_txt)
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = truth(os.path.join(HERE, "..", "tests", "fixtures", "devices.json"), gf, rf)
        last[0] = buf.getvalue()
        return rc
    gsrc = open(gen).read()
    case("truth: a generator header that cannot be read is red and says so", t2("# nothing here\ndef build_devices_doc():\n", "") == 1 and "not readable" in last[0])
    case("truth: a README that states other numbers is red", t2(gsrc, "| `devices.json` | 17 APs, ground truth of the device grouping: 2 device clusters, 2 roaming ESSs |\n") == 1 and "README says" in last[0])
    case("truth: a README without numbers is green and says so", t2(gsrc, "| `devices.json` | the device-grouping fixture |\n") == 0 and "README no numbers" in last[0])
    case("truth: a README that states the same numbers is green", t2(gsrc, "| `devices.json` | 18 APs, ground truth of the device grouping: 3 device clusters, 2 roaming ESSs |\n") == 0 and "README agrees" in last[0])
    # a missing or broken input is "cannot check" (exit 2), not a verdict: a caller that counts exit 1 as "the copy is red" must not be fooled
    import io, contextlib
    for label, f in (("missing", os.path.join(d, "nothere.json")), ("not JSON", gen)):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = truth(f, gen, rd)
        case("truth: a %s devices.json is exit 2 (cannot check), not exit 1" % label, rc == 2 and "CANNOT CHECK" in buf.getvalue() and " -- FAIL: " not in buf.getvalue())
    print("data-oracle selftest: %d/%d cases as expected%s" % (n - len(bad), n, "" if not bad else " -- FAIL: " + "; ".join(bad)))
    return 1 if bad else 0


def tempfile_dir():
    import tempfile
    d = tempfile.mkdtemp(prefix="starchorus-oracle.")
    import atexit, shutil
    atexit.register(shutil.rmtree, d, True)
    return d


def main(argv):
    if len(argv) >= 2 and argv[0] == "bundle" and len(argv) == 3:
        return bundle(argv[1], argv[2])
    if len(argv) == 6 and argv[0] == "judge" and argv[5] in ("run", "probe"):
        return judge(argv[1], argv[2], argv[3], argv[4], argv[5])
    if len(argv) == 4 and argv[0] == "truth":
        return truth(argv[1], argv[2], argv[3])
    if argv == ["selftest"]:
        return selftest()
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
