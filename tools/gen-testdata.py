#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
gen-testdata.py -- synthetic starchorus.json generator for Starchorus (dev machine only).

Produces a document in the stable JSON contract written by starchorus-collect.sh:

  {generated, center:{label}, source,
   aps:[{bssid, ssid, channel, band, freq, rssi, security, clients:[{mac, rssi}]}],
   unassociated:[{mac, rssi}]}

Optional, additive fields (only when asked for): "vendor" (per AP / client),
and with --extras "rate", "last_seen", "width", "phy" (APs) and "last_seen",
"randomized" (clients). --legacy emits exactly the base contract, nothing else.
--source iw-scan-ACTIVE mirrors the collector's ACTIVE opt-in scan (STARCHORUS_ALLOW_ACTIVE=1):
APs only, no clients, its security words, no extras. --validate also checks "source"
and the source-specific shape (none / iw-scan-ACTIVE) and rejects unknown keys.

Everything is deterministic for a given --seed. Python 3 stdlib only.

Examples:
  tools/gen-testdata.py --aps 25 --clients 180 --assoc-frac 0.4 --vendor-frac 0.6 --extras \
      --hidden-frac 0.1 --source airodump-csv --seed 7 --out tests/fixtures/many-clients.json
  tools/gen-testdata.py --stamp tests/fixtures/many-clients.json     # strips last_seen (not a recon-db source)
  tools/gen-testdata.py --source none --out tests/fixtures/empty-none.json
  tools/gen-testdata.py --source iw-scan-ACTIVE --aps 24 --vendor-frac 0.5 --seed 158 \
      --out tests/fixtures/active.json
  tools/gen-testdata.py --validate tests/fixtures/many-clients.json
"""
import argparse
import hashlib
import json
import math
import random
import re
import sys
import time

# The tables below and the order of the random draws are part of the fixtures: changing either changes
# every generated fixture (tools/regress.sh regenerates active.json and compares it byte for byte).

# --------------------------------------------------------------------------- built-in tables
# (OUI prefix, vendor name). Prefixes are plausible allocations; the names are what the
# collector's on-device lookup would emit. One vendor carries a double quote, one an
# ampersand and one non-ASCII text to exercise JSON / HTML escaping downstream.
VENDORS = [
    ("3c:22:fb", "Apple"), ("a4:83:e7", "Apple"), ("f0:18:98", "Apple"),
    ("8c:f5:a3", "Samsung Electronics"), ("50:32:75", "Samsung Electronics"),
    ("3c:a9:f4", "Intel Corporate"), ("8c:8d:28", "Intel Corporate"),
    ("24:6f:28", "Espressif"), ("84:cc:a8", "Espressif"), ("a4:cf:12", "Espressif"),
    ("44:4e:6d", "Arcadyan Technology"), ("3c:a6:2f", "Arcadyan Technology"), ("2c:91:ab", "Arcadyan Technology"),
    ("50:c7:bf", "TP-Link"), ("60:e3:27", "TP-Link"), ("b0:be:76", "TP-Link"),
    ("78:8a:20", "Ubiquiti"), ("f0:9f:c2", "Ubiquiti"), ("24:a4:3c", "Ubiquiti"),
    ("64:cc:2e", "Xiaomi"), ("28:6c:07", "Xiaomi"),
    ("54:60:09", "Google"), ("f4:f5:d8", "Google"),
    ("f0:f0:a4", "Amazon Technologies"), ("74:c2:46", "Amazon Technologies"),
    ("5c:aa:fd", "Sonos"), ("34:7e:5c", "Sonos"),
    ("b8:27:eb", "Raspberry Pi Foundation"), ("dc:a6:32", "Raspberry Pi Foundation"),
    ("e4:5f:01", "Raspberry Pi Foundation"),
    ("00:e0:fc", "Huawei"), ("48:46:fb", "Huawei"),
    ("58:97:bd", "Cisco Systems"), ("00:1b:d4", "Cisco Systems"),
    ("24:de:c6", "Aruba / HPE"), ("9c:1c:12", "Aruba / HPE"),
    ("7c:03:ab", "Sagemcom"), ("34:2c:c4", "Sagemcom"),
    ("b8:ec:a3", "Zyxel"), ("9c:3d:cf", "Netgear"), ("2c:fd:a1", "ASUSTek"),
    ("28:18:78", "Microsoft"), ("98:b6:e9", "Nintendo"), ("04:5d:4b", "Sony"),
    ("88:36:6c", "LG Electronics"), ("5c:f8:a1", "Murata Manufacturing"),
    ("00:e0:4c", "Realtek"), ("00:a0:c6", "Qualcomm"), ("94:65:2d", "OnePlus"),
    ("70:b3:d5", "O\"Neil & Sons"),            # quote + ampersand: escaping test
    ("d8:3a:dd", "Åsgard Optics Ltd"),    # non-ASCII: encoding test
]
VENDOR_BY_OUI = dict(VENDORS)
OUIS_OF = {}                                  # vendor -> its OUIs, in table order
for _o, _v in VENDORS:
    OUIS_OF.setdefault(_v, []).append(_o)

CLIENT_OUIS = [o for o, v in VENDORS if v in (
    "Apple", "Samsung Electronics", "Intel Corporate", "Espressif", "Xiaomi", "Google",
    "Amazon Technologies", "Sonos", "Raspberry Pi Foundation", "Huawei", "Microsoft", "Nintendo",
    "Sony", "LG Electronics", "Murata Manufacturing", "Realtek", "Qualcomm", "OnePlus",
    "O\"Neil & Sons", "Åsgard Optics Ltd")]

# ESSID templates: (name or pattern, weight, allowed group sizes, vendor, forced security or None).
# {N} = N random hex digits. The vendor must be one of VENDORS.
SSID_TEMPLATES = [
    ("BT Smart Hub", 6, (1, 2, 3), "Arcadyan Technology", None),
    ("BT-Hub6-{2}", 5, (1, 2), "Arcadyan Technology", None),
    ("BT-WholeHome", 2, (2, 3), "Arcadyan Technology", None),
    ("eduroam", 5, (2, 3, 4), "Aruba / HPE", "WPA2"),
    ("BTWi-fi", 5, (2, 3, 4), "Huawei", "Open"),
    ("EE-Hub-{4}", 4, (1, 2), "Sagemcom", None),
    ("SKY{4}", 5, (1, 2), "Huawei", None),
    ("_The Cloud", 2, (1, 2, 3), "Huawei", "Open"),
    ("PLUSNET-{4}", 4, (1, 2), "Sagemcom", None),
    ("TALKTALK{6}", 4, (1, 2), "Zyxel", None),
    ("VM{7}", 2, (1, 2), "Sagemcom", None),
    ("Virgin Media WiFi", 2, (1, 2), "Sagemcom", "Open"),
    ("Village-Mesh", 3, (1, 2, 3), "Ubiquiti", "Open"),
    ("GuestNet", 3, (1, 2), "Ubiquiti", "Open"),
    ("Office-5G", 2, (1,), "Ubiquiti", None),
    ("Café-Guest", 2, (1, 2), "Ubiquiti", None),        # non-ASCII SSID
    ("Corner Café Guest", 2, (1, 2), "TP-Link", "Open"),
    ("MeshNode-Garden", 2, (2, 3, 4), "Google", None),
    ("NETGEAR-Legacy", 1, (1,), "Netgear", "WEP"),
    ("TP-Link_{4}", 3, (1, 2), "TP-Link", None),
    ("TP-Link_Extender", 1, (1, 2), "TP-Link", None),
    ("ASUS_{2}_5G", 2, (1,), "ASUSTek", None),
    ("Xiaomi_{4}", 2, (1, 2), "Xiaomi", None),
    ("HUAWEI-{4}", 2, (1, 2), "Huawei", None),
    ("DIRECT-{2}-HP OfficeJet", 2, (1,), "Cisco Systems", "WPA2"),
    ("Chromecast{4}", 1, (1,), "Google", "WPA2"),
    ("Sonos-{6}", 1, (1,), "Sonos", "WPA2"),
    ("ESP_{6}", 2, (1,), "Espressif", "Open"),
    ("Max's iPhone", 2, (1,), "Apple", "WPA2"),
    ("Lisa's Galaxy S23", 1, (1,), "Samsung Electronics", "WPA2"),
    ("Pi-Hole-AP", 1, (1,), "Raspberry Pi Foundation", "WPA2"),
    ("O\"Neil & Sons Guest", 1, (1, 2), "O\"Neil & Sons", "Open"),  # quotes in SSID
    ("Back\\slash Net", 1, (1,), "TP-Link", None),                  # backslash in SSID
]
SSID_W = [t[1] for t in SSID_TEMPLATES]

SECURITIES = ("WPA2", "WPA3/WPA2", "WPA3", "Open", "WPA", "WEP", "OWE")
SECURITY_W = (52, 16, 10, 9, 4, 3, 3)

IWSCAN = "iw-scan-ACTIVE"   # the collector's only non-passive source (opt-in STARCHORUS_ALLOW_ACTIVE=1)
SOURCES = ("recon-db", "airodump-csv", "tcpdump", IWSCAN, "none")   # every "source" starchorus-collect.sh emits
# build_from_iwscan() in starchorus-collect.sh derives security from the RSN/WPA/Privacy IEs in these words;
# anything else becomes "WPA" or "WPA/WPA2".
IWSCAN_SEC = {"WPA2": "WPA2/WPA3", "WPA3/WPA2": "WPA2/WPA3", "WPA3": "WPA2/WPA3", "OWE": "WPA2/WPA3",
              "WEP": "WEP", "Open": "Open"}
# SSIDs a station may probe for although no AP around carries them
REMEMBERED = ("BTWi-fi", "GWR WiFi", "Hotel-Guest", "Starbucks WiFi", "BT-Hub6", "Anna's iPhone",
              "AndroidAP", "Avanti WiFi", "Sky WiFi", "Underground WiFi", "Airport_Free_WiFi", "O2 Wifi")

CH_24 = list(range(1, 14))
CH_24_W = [10, 1, 1, 1, 2, 10, 1, 1, 2, 1, 10, 1, 1]   # 1/6/11 dominate
CH_5 = [36, 40, 44, 48, 52, 56, 60, 64] + list(range(100, 145, 4)) + [149, 153, 157, 161, 165]
CH_6 = list(range(1, 234, 4))
BANDS = ("2.4GHz", "5GHz", "6GHz")


def freq_of(band, ch):
    if band == "2.4GHz":
        return 2484 if ch == 14 else 2407 + ch * 5
    if band == "5GHz":
        return 5000 + ch * 5
    return 5950 + ch * 5


def clamp(v, lo, hi):
    return max(lo, min(hi, int(round(v))))


# --------------------------------------------------------------------------- generator
class Gen:
    def __init__(self, args):
        self.a = args
        self.r = random.Random(args.seed)
        self.used_macs = set()

    def fill(self, pat):
        return re.sub(r"\{(\d+)\}", lambda m: "".join(self.r.choice("0123456789ABCDEF") for _ in range(int(m.group(1)))), pat)

    def mac(self, oui=None, near=None):
        """A MAC not handed out before: `near` = a close successor of that BSSID (multi-BSSID of one
        physical device), `oui` = that prefix + a random suffix, neither = locally administered (randomized)."""
        r = self.r
        for _ in range(1000):
            if near:
                m = "%012x" % ((int(near.replace(":", ""), 16) + r.randint(1, 6)) & 0xFFFFFFFFFFFF)
            elif oui:
                m = oui.replace(":", "") + "".join("%02x" % r.randint(0, 255) for _ in range(3))
            else:
                first = r.randint(0, 15) * 16 + r.choice([0x2, 0x6, 0xA, 0xE])
                m = "%02x" % first + "".join("%02x" % r.randint(0, 255) for _ in range(5))
            m = ":".join(m[k:k + 2] for k in range(0, 12, 2))
            if m not in self.used_macs:
                self.used_macs.add(m)
                return m
        raise RuntimeError("could not allocate a unique MAC")

    def pick_channel(self, band):
        r = self.r
        if band == "2.4GHz":
            return r.choices(CH_24, CH_24_W)[0]
        if band == "5GHz":
            return r.choice(CH_5)
        return r.choice(CH_6)

    def ap_rssi(self):
        # most APs are far away: triangular, mode around -72
        return clamp(self.r.triangular(-88, -35, -72), -88, -35)

    def client_rssi(self):
        r = self.r
        if r.random() < 0.06:                       # outliers: very close or at the edge
            return clamp(r.uniform(-34, -55) if r.random() < 0.6 else r.uniform(-86, -93), -95, -30)
        return clamp(r.gauss(-72, 6.5), -92, -40)

    def phy_rate_width(self, band, security):
        # the 5 GHz width dict draws all three choices: that is part of the RNG sequence, keep it
        r = self.r
        if band == "6GHz":
            phy = "ax" if r.random() < 0.8 else "be"
            width = r.choice([80, 160, 160, 320] if phy == "be" else [80, 160])
            rate = {80: 1201, 160: 2402, 320: 5764}[width]
        elif band == "5GHz":
            phy = r.choices(["a/n", "ac", "ax"], [1, 5, 4])[0]
            width = {"a/n": r.choice([20, 40]), "ac": r.choice([40, 80, 80]), "ax": r.choice([80, 80, 160])}[phy]
            rate = {20: 150, 40: 300, 80: 866 if phy == "ac" else 1201, 160: 2402}[width]
        else:
            if security == "WEP":
                phy, width, rate = "b/g", 20, 54
            else:
                phy = r.choices(["b/g", "g/n", "ax"], [1, 6, 3])[0]
                width = 40 if (phy != "b/g" and r.random() < 0.2) else 20
                rate = {"b/g": 54, "g/n": 300 if width == 40 else 144, "ax": 574 if width == 40 else 287}[phy]
        return phy, rate, width

    # ---- document parts
    def build_aps(self):
        a, r = self.a, self.r
        n, aps = a.aps, []
        while len(aps) < n:
            pat, _, sizes, vendor, forced = r.choices(SSID_TEMPLATES, SSID_W)[0]
            name = self.fill(pat)
            # a fixed name drawn again (BT Smart Hub, eduroam) simply grows that ESSID group
            size = r.choice([s for s in sizes if s <= n - len(aps)] or [1])
            sec = forced or r.choices(SECURITIES, SECURITY_W)[0]
            if sec == "OWE" and forced is None and r.random() < 0.5:
                sec = "WPA2"
            oui = r.choice(OUIS_OF[vendor])
            base_rssi = self.ap_rssi()
            if size == 1:
                bands = [r.choices(BANDS, [55, 40, 5])[0]]
            elif size == 2:
                bands = ["2.4GHz", "5GHz"]
            elif size == 3:
                bands = ["2.4GHz", "5GHz", "6GHz"] if r.random() < 0.4 else ["2.4GHz", "5GHz", "5GHz"]
            else:
                bands = ["2.4GHz", "5GHz", "2.4GHz", "5GHz"]
            hidden = r.random() < a.hidden_frac
            mac = None
            for k, band in enumerate(bands):
                # a group of 4 is two dual-band devices: the second starts a fresh BSSID
                mac = self.mac(oui=oui) if k == 0 or k == 2 and size == 4 else self.mac(near=mac)
                ch = self.pick_channel(band)
                aps.append({"bssid": mac, "ssid": "" if hidden else name, "channel": ch, "band": band,
                            "freq": freq_of(band, ch),
                            "rssi": clamp(base_rssi + r.gauss(0, 3) - (2 if band != "2.4GHz" else 0), -90, -33),
                            "security": sec, "clients": [], "_vendor": vendor})
        # associated clients on a fraction of APs (airodump-style)
        idx = list(range(len(aps)))
        r.shuffle(idx)
        for i in idx[:int(round(a.assoc_frac * len(aps)))]:
            ap = aps[i]
            k = r.choices([1, 2, 3, 4, 5, 6, 8, 12], [8, 8, 6, 4, 3, 2, 1, 1])[0]
            ap["clients"] = [self.client(clamp(ap["rssi"] + r.gauss(-7, 6), -92, -35)) for _ in range(k)]
        return aps

    def client(self, rssi):
        a, r = self.a, self.r
        randomized = r.random() < a.random_frac
        mac = self.mac() if randomized else self.mac(oui=r.choice(CLIENT_OUIS))
        c = {"mac": mac, "rssi": rssi}
        if a.legacy:
            return c
        if not randomized and r.random() < a.vendor_frac:
            c["vendor"] = VENDOR_BY_OUI[mac[:8]]
        if a.extras:
            if r.random() < 0.7:
                c["last_seen"] = a.generated - r.randint(0, 600)
            if randomized:
                c["randomized"] = True
            elif r.random() < 0.3:
                c["randomized"] = False
        return c

    def build(self):
        a, r = self.a, self.r
        doc = {"generated": a.generated, "center": {"label": a.center}, "source": a.source}
        if a.source == "none":
            doc.update(note=a.note, aps=[], unassociated=[])
            return doc
        aps = self.build_aps()
        for ap in aps:
            vendor = ap.pop("_vendor")
            if a.source == IWSCAN:
                ap["security"] = IWSCAN_SEC.get(ap["security"]) or r.choice(["WPA", "WPA/WPA2"])
            elif a.source == "tcpdump":
                # the tcpdump parser knows neither channel nor security, and clients[] stays empty
                ap.update(channel=None, band="", freq=None, security="", clients=[])
                if r.random() < 0.05:
                    ap["rssi"] = None
            if a.legacy:
                continue
            if r.random() < a.vendor_frac:   # the collector's OUI post-pass runs on every source
                ap["vendor"] = VENDOR_BY_OUI.get(ap["bssid"][:8]) or vendor
            if a.extras and a.source != "tcpdump" and r.random() < 0.75:
                ap["phy"], ap["rate"], ap["width"] = self.phy_rate_width(ap["band"], ap["security"])
                ap["last_seen"] = a.generated - r.randint(0, 300)
        doc["aps"] = aps
        doc["unassociated"] = [self.client(self.client_rssi()) for _ in range(a.clients)]
        if a.probe_frac > 0 and not a.legacy:
            self.add_probes(doc)
        return doc

    def add_probes(self, doc):
        # A SEPARATE RNG stream keeps every fixture generated without --probe-frac byte-identical.
        a = self.a
        pr = random.Random(a.seed * 7919 + 17)
        visible = sorted({ap["ssid"] for ap in doc["aps"] if ap.get("ssid")})
        for c in doc["unassociated"]:
            if pr.random() >= a.probe_frac:
                continue
            want = []
            for _ in range(pr.randint(1, 3)):
                s = pr.choice(visible if (visible and pr.random() < 0.6) else REMEMBERED)
                if s not in want:
                    want.append(s)
            c["probes"] = want


def fixed_ap(bssid, ssid, band, ch, rssi, sec, **opt):
    """A hand-built AP in contract key order; optional keys follow in call order, None ones are left out."""
    o = {"bssid": bssid, "ssid": ssid, "channel": ch, "band": band, "freq": freq_of(band, ch),
         "rssi": rssi, "security": sec, "clients": []}
    o.update((k, v) for k, v in opt.items() if v is not None)
    return o


# --------------------------------------------------------------------------- devices fixture
# Hand-built fixture for the logical AP grouping (spec §8.8). The numbers below are the
# DOCUMENTED GROUND TRUTH the HTML acceptance criteria check against:
#
#   total APs ................................. 18
#   device clusters (>= 2 members) ............ 3
#       tri-band  44:4e:6d:aa:bb:10/11/12  (2.4 + 5 + 6 GHz, sequential BSSIDs, "BT Smart Hub")
#       dual-band 78:8a:20:cc:dd:20/21     (2.4 + 5 GHz, "UniFi-Home")
#       MBSSID    50:c7:bf:ee:00:40/41/42/43 (4 vSSIDs on ONE 5 GHz radio, low-bit BSSIDs)  <- reason matches /vBSSID/
#   ESS sets (same SSID across >= 2 DISTINCT devices) ... 2
#       "eduroam"  on 3 physically distinct devices (24:de:c6.. , 58:97:bd.. , 9c:1c:12..)  -> apCount 3, 3 devices
#       "GuestNet" on 2 physically distinct devices (f0:9f:c2.. , b8:ec:a3..)               -> apCount 2, 2 devices
#   Sum(members - 1) over ESS sets ............ 3   (visible AP-node count drops by 3 when essMerge on: 18 -> 15)
#   unrelated singleton APs ................... 2   ("Netgear-Home", "ASUS-RT")
#   randomized/locally-administered pair ...... 2   (a2:11:22:aa:bb:10/11 -> EXCLUDED from OUI/device logic,
#                                                     different SSIDs so they form no ESS either)
#
# tri-band device's first (smallest) BSSID = 44:4e:6d:aa:bb:10 ; its members sorted =
#   ['44:4e:6d:aa:bb:10', '44:4e:6d:aa:bb:11', '44:4e:6d:aa:bb:12'].
def build_devices_doc(generated, center):
    def ap(bssid, ssid, band, ch, sec, vendor, rssi):
        return fixed_ap(bssid, ssid, band, ch, rssi, sec, vendor=vendor)

    aps = [
        # tri-band device (one physical box, 3 radios, sequential BSSIDs)
        ap("44:4e:6d:aa:bb:10", "BT Smart Hub", "2.4GHz", 6, "WPA2", "Arcadyan Technology", -50),
        ap("44:4e:6d:aa:bb:11", "BT Smart Hub", "5GHz", 44, "WPA2", "Arcadyan Technology", -52),
        ap("44:4e:6d:aa:bb:12", "BT Smart Hub", "6GHz", 37, "WPA3/WPA2", "Arcadyan Technology", -60),
        # dual-band device
        ap("78:8a:20:cc:dd:20", "UniFi-Home", "2.4GHz", 1, "WPA2", "Ubiquiti", -55),
        ap("78:8a:20:cc:dd:21", "UniFi-Home", "5GHz", 36, "WPA2", "Ubiquiti", -57),
        # MBSSID: four virtual SSIDs on one 5 GHz radio (low-bit BSSIDs)
        ap("50:c7:bf:ee:00:40", "Office-Main", "5GHz", 149, "WPA2", "TP-Link", -48),
        ap("50:c7:bf:ee:00:41", "Office-Guest", "5GHz", 149, "Open", "TP-Link", -49),
        ap("50:c7:bf:ee:00:42", "Office-IoT", "5GHz", 149, "WPA2", "TP-Link", -50),
        ap("50:c7:bf:ee:00:43", "Office-Voice", "5GHz", 149, "WPA3", "TP-Link", -51),
        # ESS set A: "eduroam" on three physically distinct devices
        ap("24:de:c6:01:00:01", "eduroam", "5GHz", 40, "WPA2", "Aruba / HPE", -58),
        ap("58:97:bd:02:00:01", "eduroam", "5GHz", 48, "WPA2", "Cisco Systems", -63),
        ap("9c:1c:12:03:00:01", "eduroam", "2.4GHz", 11, "WPA2", "Aruba / HPE", -66),
        # ESS set B: "GuestNet" on two physically distinct devices
        ap("f0:9f:c2:04:00:01", "GuestNet", "5GHz", 157, "Open", "Ubiquiti", -61),
        ap("b8:ec:a3:05:00:01", "GuestNet", "2.4GHz", 1, "Open", "Zyxel", -70),
        # unrelated singleton APs (unique SSIDs, single band)
        ap("9c:3d:cf:07:00:01", "Netgear-Home", "5GHz", 64, "WPA2", "Netgear", -68),
        ap("2c:fd:a1:08:00:01", "ASUS-RT", "5GHz", 153, "WPA3", "ASUSTek", -72),
        # locally-administered (randomized) pair: same prefix + sequential byte5, but the U/L bit
        # (a2 -> bit set) must EXCLUDE them from OUI/device clustering; distinct SSIDs -> no ESS
        ap("a2:11:22:aa:bb:10", "AndroidAP-1", "2.4GHz", 6, "WPA2", None, -74),
        ap("a2:11:22:aa:bb:11", "AndroidAP-2", "5GHz", 44, "WPA2", None, -76),
    ]
    # a handful of associated clients (airodump-style) on two APs
    aps[0]["clients"] = [
        {"mac": "3c:22:fb:10:20:31", "rssi": -55, "vendor": "Apple"},
        {"mac": "8c:f5:a3:11:21:32", "rssi": -61, "vendor": "Samsung Electronics"},
    ]
    aps[5]["clients"] = [
        {"mac": "24:6f:28:aa:bb:cc", "rssi": -52, "vendor": "Espressif"},
    ]
    # free (unassociated) clients: some with vendor, some locally administered / randomized
    unassoc = [
        {"mac": "3c:22:fb:44:55:66", "rssi": -58, "vendor": "Apple"},
        {"mac": "dc:a6:32:12:34:56", "rssi": -64, "vendor": "Raspberry Pi Foundation"},
        {"mac": "64:cc:2e:77:88:99", "rssi": -70, "vendor": "Xiaomi"},
        {"mac": "a6:31:42:53:64:75", "rssi": -66, "randomized": True},
        {"mac": "ee:11:22:33:44:55", "rssi": -80, "randomized": True},
        {"mac": "5c:aa:fd:0a:0b:0c", "rssi": -60, "vendor": "Sonos"},
        {"mac": "94:65:2d:ab:cd:ef", "rssi": -73, "vendor": "OnePlus"},
        {"mac": "b2:44:55:66:77:88", "rssi": -85, "randomized": True},
        {"mac": "48:46:fb:01:02:03", "rssi": -68, "vendor": "Huawei"},
        {"mac": "84:cc:a8:aa:bb:cc", "rssi": None, "vendor": "Espressif"},
    ]
    return {"generated": generated, "center": {"label": center}, "source": "recon-db",
            "aps": aps, "unassociated": unassoc}


# --------------------------------------------------------------------------- aged fixture (D1 freshness)
# 14 APs whose `last_seen` sits at hand-picked ages against `generated` (default 1789300000), so the freshness
# tiers T0 < 60 s, T1 < 300 s, T2 < 900 s, T3 on record and "undated" (D1) are each hit on both sides of every
# boundary. Expected by design (a Python recount in tools/regress.d/ap-models.sh must agree with the page):
#   T0: ages 0, 30, 59 and -30 (a capture 30 s "in the future" is tolerated up to +300 s)     -> 4
#   T1: ages 60, 299 -> 2 · T2: ages 300, 899 -> 2 · T3: ages 900, 3600 -> 2
#   undated: no last_seen (2), last_seen 0 (a zero stamp is no time), last_seen = generated + 301 (too far ahead) -> 4
# Synthetic: locally administered BSSIDs and invented SSIDs only (P9).
AGED_AGES = (0, 30, 59, 60, 299, 300, 899, 900, 3600, -30)


def build_aged_doc(generated, center):
    chans = [("2.4GHz", 1), ("2.4GHz", 6), ("2.4GHz", 11), ("5GHz", 36), ("5GHz", 44), ("5GHz", 100),
             ("5GHz", 149), ("6GHz", 5), ("6GHz", 37), ("2.4GHz", 3), ("5GHz", 52), ("2.4GHz", 9),
             ("5GHz", 116), ("6GHz", 69)]
    rssis = [-38, -44, -49, -53, -57, -61, -64, -68, -71, -74, -77, -80, -84, -87]
    secs = ["WPA2", "WPA3", "WPA2", "Open", "WPA2", "WPA3", "WPA2", "WPA2", "WEP", "WPA2", "WPA3", "WPA2", "WPA2", "WPA3"]
    stamps = [generated - a for a in AGED_AGES] + [None, None, 0, generated + 301]
    aps = [fixed_ap("02:00:5e:a0:00:%02x" % n, "aged-%02d" % n, band, ch, rssi, sec, last_seen=ls)
           for n, ((band, ch), rssi, sec, ls) in enumerate(zip(chans, rssis, secs, stamps), 1)]
    # Stations (D1): one per tier through BOTH ingest loops (associated under aps[0]/aps[3], unassociated), and
    # the randomized one without last_seen = undated. Every ASSOCIATED station sits in a different tier than its AP
    # (aps[0] is T0, aps[3] is T1), so a station tier wrongly taken from the parent's last_seen fails on all three, not one.
    aps[0]["clients"] = [{"mac": "3c:22:fb:10:20:31", "rssi": -55, "last_seen": generated - 600}]    # T2 under a T0 AP
    aps[3]["clients"] = [{"mac": "8c:f5:a3:11:21:32", "rssi": -60, "last_seen": generated - 20},     # T0 under a T1 AP
                         {"mac": "24:6f:28:aa:bb:cc", "rssi": -63, "last_seen": generated - 2000}]  # T3 under a T1 AP
    unassoc = [{"mac": "3c:22:fb:44:55:66", "rssi": -58, "last_seen": generated - 200},            # T1
               {"mac": "a6:31:42:53:64:75", "rssi": -66, "randomized": True}]                     # undated
    return {"generated": generated, "center": {"label": center}, "source": "recon-db",
            "aps": aps, "unassociated": unassoc}


# --------------------------------------------------------------------------- last_seen stamping
# The recon.db collector writes `last_seen` on every AP; a recon-db fixture without it is not what the collector
# emits. `--stamp FILE` adds a deterministic, idempotent `last_seen` to every AP of a recon-db fixture that has none:
# age = -mean * ln(1 - u) seconds against `generated`, u = the first 8 hex digits of sha1(bssid) / 2^32 (no random
# state, no ordering dependence), capped at 3600 s. Every OTHER source (airodump-csv, tcpdump, iw scan) is the
# opposite case: those collectors write no `last_seen` (recon.db only, starchorus-collect.sh), so `--stamp` REMOVES it
# from the APs and stations of such a fixture. --stamp-mean sets the mean age (default 90 s = the payload's 120 s
# window; the screenshot fixture field-probes-aged.json uses 600 s so that the older freshness tiers show).
def stamp_doc(doc, mean):
    if doc.get("source") != "recon-db":
        objs = [o for a in doc["aps"] for o in [a] + a["clients"]] + doc["unassociated"]
        return sum(o.pop("last_seen", None) is not None for o in objs)
    n = 0
    for a in doc["aps"]:
        if "last_seen" not in a:
            u = int(hashlib.sha1(a["bssid"].encode()).hexdigest()[:8], 16) / 4294967296.0
            a["last_seen"] = doc["generated"] - min(3600, int(-mean * math.log(1.0 - u)))
            n += 1
    return n


# --------------------------------------------------------------------------- security-suite fixture
# What the collector emits for the recon.db path: one AP per security class the front-end draws, each with the akm/cipher/auth
# detail decoded from libwifi's encryption_info, a multi-SSID responder, the hop-aware channels[] and the center extras. Synthetic
# (locally administered BSSIDs, invented SSIDs, P9). Expected front-end classes (tools/regress.d/collector-fields.sh pins them):
#   open 1 · wep 1 · wpa 0 · wpa2 2 (PSK, responder) · wpa3 1 · wpa3-transition 1 · owe 1 · enterprise 2 · tkip-weak 2 · unknown 0  (11 APs)
def build_secsuite_doc(generated, center):
    def ap(n, band, ch, rssi, sec, akm=None, cipher=None, auth=None, ssid=None, extra=None):
        o = {"bssid": "02:00:5e:b0:00:%02x" % n, "ssid": ssid if ssid is not None else "sec-%02d" % n, "channel": ch, "band": band,
             "freq": freq_of(band, ch), "rssi": rssi, "security": sec, "last_seen": generated - 10 * n}
        o.update((k, v) for k, v in (("akm", akm), ("cipher", cipher), ("auth", auth)) if v)
        o.update(extra or {})
        o["clients"] = []
        return o

    ccmp = {"group": "ccmp128", "pairwise": ["ccmp128"]}
    tkip = {"group": "tkip", "pairwise": ["tkip"]}
    aps = [
        ap(1, "2.4GHz", 1, -42, "Open", auth=["open"]),
        ap(2, "2.4GHz", 6, -55, "WEP", auth=["open"]),
        ap(3, "5GHz", 36, -47, "WPA2", ["psk"], ccmp, ["open"]),
        ap(4, "5GHz", 44, -51, "WPA3", ["sae"], ccmp, ["open", "sae"]),
        ap(5, "5GHz", 100, -58, "WPA3/WPA2", ["psk", "sae"], ccmp, ["open", "sae"]),
        ap(6, "6GHz", 5, -61, "OWE", ["owe"], ccmp, ["open"]),
        ap(7, "5GHz", 149, -64, "WPA2-Enterprise", ["1x"], ccmp, ["open"]),
        ap(8, "5GHz", 157, -67, "WPA3-Enterprise", ["1x-suiteb-sha256"], {"group": "gcmp128", "pairwise": ["gcmp128"]}, ["open"]),
        ap(9, "2.4GHz", 11, -70, "WPA (TKIP)", ["psk"], tkip, ["open"]),
        ap(10, "2.4GHz", 3, -73, "WPA2 (TKIP)", ["psk"], tkip, ["open"]),
        ap(11, "2.4GHz", 9, -76, "WPA2", ["psk"], ccmp, ["open"], ssid="", extra={"responded_ssids": 3}),
    ]
    aps[0]["clients"] = [{"mac": "3c:22:fb:10:20:31", "rssi": -55}]
    aps[2]["clients"] = [{"mac": "8c:f5:a3:11:21:32", "rssi": -60, "vendor": "Samsung Electronics"}]
    unassoc = [{"mac": "a6:31:42:53:64:75", "rssi": -66, "randomized": True}]
    freqs = sorted({a["freq"] for a in aps})
    channels = [{"freq": f, "last_heard": generated - (3 + i * 7), "busy_pct": (10 + 9 * i) % 100, "noise": -95 + (i % 5)} for i, f in enumerate(freqs)]
    return {"generated": generated, "center": {"label": center, "max_age": 0, "interval": 5,
            "own_bssids": ["00:c0:ca:98:76:54"], "own_ssids": ["my-own-net"]},
            "source": "recon-db", "channels": channels, "aps": aps, "unassociated": unassoc}


# --------------------------------------------------------------------------- contract check
REQUIRED_TOP = ("generated", "center", "source", "aps", "unassociated")
OPT_TOP = {"note", "channels"}            # additive optional top-level keys the collector emits (channels[] = hop info)
OPT_CENTER = {"max_age", "interval", "own_bssids", "own_ssids"}
AP_KEYS = ("bssid", "ssid", "channel", "band", "freq", "rssi", "security", "clients")
# akm/cipher/auth/responded_ssids exist on APs only (never on a station, P1); packets is accepted when a source reports it
OPT_AP = {"vendor", "rate", "last_seen", "width", "phy", "akm", "cipher", "auth", "responded_ssids", "packets"}
OPT_CL = {"vendor", "last_seen", "randomized", "probes"}
IWSCAN_OPT_AP = {"vendor"}    # build_from_iwscan() emits no rate/last_seen/width/phy


def validate(doc, legacy=False):
    """Returns a list of problems (empty = ok)."""
    p = ["missing top-level key %r" % k for k in REQUIRED_TOP if k not in doc]
    if p:
        return p
    extra = set(doc) - set(REQUIRED_TOP) - OPT_TOP
    if extra:
        p.append("unknown top-level keys %s" % sorted(extra))
    src = doc["source"]
    if src not in SOURCES:
        p.append("unknown source %r (the collector emits %s)" % (src, ", ".join(SOURCES)))
    c = doc["center"] if isinstance(doc["center"], dict) else {}
    extra = set(c) - {"label"} - OPT_CENTER
    if "label" not in c:
        p.append("center.label missing")
    elif extra:
        p.append("unknown center keys %s" % sorted(extra))
    for k in ("max_age", "interval"):
        if k in c and not (isinstance(c[k], int) and not isinstance(c[k], bool) and c[k] >= 0):
            p.append("center.%s must be a non-negative integer" % k)
    if "own_bssids" in c and not (isinstance(c["own_bssids"], list)
                                  and all(isinstance(m, str) and len(m) == 17 for m in c["own_bssids"])):
        p.append("center.own_bssids must be a list of MAC strings")
    if "own_ssids" in c and not (isinstance(c["own_ssids"], list) and len(c["own_ssids"]) <= 32
                                 and all(isinstance(x, str) and len(x) <= 32 for x in c["own_ssids"])):
        p.append("center.own_ssids must be <= 32 strings of <= 32 chars")
    if "channels" in doc:
        if not isinstance(doc["channels"], list):
            p.append("channels must be an array")
        else:
            for i, e in enumerate(doc["channels"]):
                if not isinstance(e, dict) or not isinstance(e.get("freq"), int) or e["freq"] <= 0 \
                        or set(e) - {"freq", "last_heard", "busy_pct", "noise"}:
                    p.append("channels[%d]: needs an integer freq and only last_heard/busy_pct/noise" % i)
    if not isinstance(doc["aps"], list) or not isinstance(doc["unassociated"], list):
        return p + ["aps/unassociated must be arrays"]
    if src == "none":
        if doc["aps"] or doc["unassociated"]:
            p.append("source none must carry empty aps/unassociated")
        if not isinstance(doc.get("note"), str):
            p.append("source none needs a 'note' string")
    elif src == IWSCAN:
        # an ACTIVE scan lists APs only; the collector writes clients:[] and unassociated:[]
        if doc["unassociated"] or any(isinstance(a, dict) and a.get("clients") for a in doc["aps"]):
            p.append("%s: clients[]/unassociated[] must be empty (a scan cannot enumerate stations)" % IWSCAN)
        for i, ap in enumerate(doc["aps"]):
            extra = isinstance(ap, dict) and set(ap) - set(AP_KEYS) - IWSCAN_OPT_AP
            if extra:
                p.append("aps[%d]: %s never emits %s" % (i, IWSCAN, sorted(extra)))
    macs = set()

    def chk_client(c, where):
        if not isinstance(c, dict) or "mac" not in c or "rssi" not in c:
            p.append("%s: client needs mac+rssi" % where)
            return
        if c["mac"] in macs:
            p.append("%s: duplicate mac %s" % (where, c["mac"]))
        macs.add(c["mac"])
        extra = set(c) - {"mac", "rssi"} - OPT_CL
        if extra:
            p.append("%s: unknown client keys %s" % (where, sorted(extra)))
        if legacy and set(c) - {"mac", "rssi"}:
            p.append("%s: legacy must not carry optional keys" % where)

    for i, ap in enumerate(doc["aps"]):
        w = "aps[%d]" % i
        if not isinstance(ap, dict):
            p.append(w + ": not an object")
            continue
        p += ["%s: missing %r" % (w, k) for k in AP_KEYS if k not in ap]
        if ap.get("bssid") in macs:
            p.append("%s: duplicate bssid" % w)
        macs.add(ap.get("bssid"))
        if ap.get("band") not in ("", None) + BANDS:
            p.append("%s: odd band %r" % (w, ap.get("band")))
        extra = set(ap) - set(AP_KEYS) - OPT_AP
        if extra:
            p.append("%s: unknown AP keys %s" % (w, sorted(extra)))
        if legacy and set(ap) - set(AP_KEYS):
            p.append("%s: legacy must not carry optional keys" % w)
        for k in ("akm", "auth"):
            if k in ap and not (isinstance(ap[k], list) and ap[k] and all(isinstance(x, str) for x in ap[k])):
                p.append("%s: %s must be a non-empty list of strings" % (w, k))
        if "cipher" in ap and not (isinstance(ap["cipher"], dict) and ap["cipher"] and set(ap["cipher"]) <= {"group", "pairwise"}):
            p.append("%s: cipher must be {group?, pairwise?}" % w)
        if "responded_ssids" in ap and not (isinstance(ap["responded_ssids"], int) and ap["responded_ssids"] >= 2):
            p.append("%s: responded_ssids must be an integer >= 2 (the collector omits 1)" % w)
        for j, c in enumerate(ap.get("clients") or []):
            chk_client(c, "%s.clients[%d]" % (w, j))
    for j, c in enumerate(doc["unassociated"]):
        chk_client(c, "unassociated[%d]" % j)
    return p


# --------------------------------------------------------------------------- cli
def read_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_text(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def internal(probs):
    for x in probs:
        print("INTERNAL:", x, file=sys.stderr)
    return 2


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--aps", type=int, default=20, help="number of access points (default 20)")
    ap.add_argument("--clients", type=int, default=60, help="number of unassociated clients (default 60)")
    ap.add_argument("--assoc-frac", type=float, default=0.0,
                    help="fraction of APs that get a filled clients[] (airodump-style); rest stay empty like recondb")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--vendor-frac", type=float, default=0.0, help="fraction of APs/clients with an optional 'vendor'")
    ap.add_argument("--random-frac", type=float, default=0.35,
                    help="fraction of clients with a locally administered (randomized) MAC, never with vendor")
    ap.add_argument("--hidden-frac", type=float, default=0.08, help="fraction of ESSID groups with hidden (empty) SSID")
    ap.add_argument("--extras", action="store_true", help="also set optional rate/last_seen/width/phy/randomized on a subset")
    ap.add_argument("--legacy", action="store_true", help="exact base contract: no optional fields at all")
    ap.add_argument("--probe-frac", type=float, default=0.0,
                    help="fraction of unassociated clients carrying 'probes' (probed SSIDs; ~60%% name a visible network)")
    ap.add_argument("--stamp", metavar="FILE", help="add a deterministic last_seen to every AP of the recon-db fixture FILE (in place, idempotent)")
    ap.add_argument("--stamp-mean", type=float, default=90.0, help="mean age in seconds for --stamp (default 90)")
    ap.add_argument("--secsuite", action="store_true",
                    help="the security-suite fixture (one AP per security class with akm/cipher/auth, responder, channels[], center extras)")
    ap.add_argument("--aged", action="store_true",
                    help="the D1 freshness fixture (14 APs and 5 stations at hand-picked last_seen ages, see build_aged_doc)")
    ap.add_argument("--devices", action="store_true",
                    help="emit the hand-built logical AP grouping fixture (devices.json, spec §8.8); see build_devices_doc()")
    ap.add_argument("--source", default="recon-db", choices=SOURCES,
                    help="%s = the ACTIVE opt-in iw scan (APs only, no clients, no extras)" % IWSCAN)
    ap.add_argument("--note", default="no capture source available (synthetic fixture)", help="note for --source none")
    ap.add_argument("--center", default="This device", help="center.label")
    ap.add_argument("--generated", default="1789300000", help="unix timestamp or 'now' (default fixed for reproducibility)")
    ap.add_argument("--compact", action="store_true", help="single-line JSON instead of indented")
    ap.add_argument("--out", default="-", help="output file (default stdout)")
    ap.add_argument("--validate", metavar="FILE", help="only validate FILE against the contract and exit")
    args = ap.parse_args(argv)

    if args.stamp:
        doc = read_json(args.stamp)
        n = stamp_doc(doc, args.stamp_mean)
        probs = validate(doc)
        if probs:
            return internal(probs)
        if n:
            write_text(args.stamp, json.dumps(doc, ensure_ascii=False, indent=1) + "\n")
        recon = doc.get("source") == "recon-db"
        print("%s: %s %d %s" % (args.stamp, "stamped" if recon else "stripped", n,
                                "of %d APs" % len(doc["aps"]) if recon else "last_seen fields (this source has none)"), file=sys.stderr)
        return 0

    if args.validate:
        doc = read_json(args.validate)
        probs = validate(doc, legacy=args.legacy)
        for x in probs:
            print("PROBLEM:", x)
        aps = doc.get("aps", [])
        print("%s: aps=%d assoc_clients=%d unassociated=%d source=%s %s" % (
            args.validate, len(aps), sum(len(a.get("clients") or []) for a in aps), len(doc.get("unassociated", [])),
            doc.get("source"), "FAILED" if probs else "OK"))
        return 1 if probs else 0

    if args.legacy:
        args.vendor_frac, args.extras = 0.0, False
    if args.source == IWSCAN:   # like build_from_iwscan(): no stations, no extras
        args.clients, args.assoc_frac, args.extras, args.probe_frac = 0, 0.0, False, 0.0
    args.generated = int(time.time()) if args.generated == "now" else int(args.generated)

    if args.secsuite:
        doc = build_secsuite_doc(args.generated, args.center)
    elif args.aged:
        doc = build_aged_doc(args.generated, args.center)
    elif args.devices:
        doc = build_devices_doc(args.generated, args.center)
    else:
        doc = Gen(args).build()
    probs = validate(doc, legacy=args.legacy)
    if probs:
        return internal(probs)
    text = json.dumps(doc, ensure_ascii=False, separators=(",", ":")) if args.compact \
        else json.dumps(doc, ensure_ascii=False, indent=1)
    if args.out == "-":
        sys.stdout.write(text + "\n")
    else:
        write_text(args.out, text + "\n")
        print("wrote %s: aps=%d assoc_clients=%d unassociated=%d source=%s" % (
            args.out, len(doc["aps"]), sum(len(a["clients"]) for a in doc["aps"]), len(doc["unassociated"]), doc["source"]),
            file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
