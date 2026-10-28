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
--radio is the hand-built fixture of the 0.2 radio pair (bluetooth[], activity[], station "packets",
a hidden network without a name); see build_radio_doc().
--alerts is the hand-built fixture of the 0.2 alerts (alerts[]: two access points the firmware reported many
deauth/disassoc frames for, and a report for an address the capture does not hold); see build_alerts_doc().
--source iw-scan-ACTIVE mirrors the collector's ACTIVE opt-in scan (STARCHORUS_ALLOW_ACTIVE=1):
APs only, no clients, its security words, no extras. --validate also checks "source"
and the source-specific shape (none / iw-scan-ACTIVE) and rejects unknown keys.

Everything is deterministic for a given --seed. Python 3 stdlib only.

Examples:
  tools/gen-testdata.py --aps 25 --clients 180 --assoc-frac 0.4 --vendor-frac 0.6 --extras \
      --hidden-frac 0.1 --source airodump-csv --seed 7 --out tests/fixtures/many-clients.json
  tools/gen-testdata.py --stamp tests/fixtures/many-clients.json     # strips last_seen (not a recon-db or pineap source)
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
SOURCES = ("recon-db", "airodump-csv", "tcpdump", "pineap", IWSCAN, "none")   # every "source" starchorus-collect.sh emits
LAST_SEEN_SOURCES = ("recon-db", "pineap")      # the sources whose collector writes `last_seen` (both take it from a `time`)
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
# The recon.db collector and the pineap source write `last_seen` on every AP; a recon-db or pineap fixture without it is not what the
# collector emits. `--stamp FILE` adds a deterministic, idempotent `last_seen` to every AP of such a fixture that has none:
# age = -mean * ln(1 - u) seconds against `generated`, u = the first 8 hex digits of sha1(bssid) / 2^32 (no random
# state, no ordering dependence), capped at 3600 s. Every OTHER source (airodump-csv, tcpdump, iw scan) is the
# opposite case: those collectors write no `last_seen` (recon.db and pineap only, starchorus-collect.sh), so `--stamp` REMOVES it
# from the APs and stations of such a fixture. --stamp-mean sets the mean age (default 90 s = the payload's 120 s
# window; the screenshot fixture field-probes-aged.json uses 600 s so that the older freshness tiers show).
def stamp_doc(doc, mean):
    if doc.get("source") not in LAST_SEEN_SOURCES:
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


# --------------------------------------------------------------------------- random-clouds fixture (spec §8.8a)
# One nearby device that scans with a fresh randomised address for every burst: 30 bursts of 4 addresses at -28..-30 dBm, one
# burst every 47 s (two bursts left out), next to everything the rule must NOT fold in. Synthetic: locally administered or
# invented addresses, invented SSIDs (P9). DOCUMENTED GROUND TRUTH (tools/regress.d/clouds.sh pins it, page and Overview alike):
#
#   free stations ............................ 160      associated ............. 2 (one randomised, never a member)
#   randomised (all) ......................... 140      randomised free ........ 139      eligible (dated, with a signal) .. 133
#   clouds ................................... 1        addresses in it ........ 121 (core 120, joined 1)
#   bursts 30 · cadence 47 s · rhythm share 1.0 · centre -29 · cloud signal -29 (range -34 to -28)
#   first heard generated - 1482 · last heard generated - 24 · distinct probed SSIDs 3
#   loose randomised free .................... 18 (off-band 1, one single burst 6, slow rhythm 5, undated 5, no signal 1)
#
#   core     30 x 4 da:c1:00:a1:ii:jj, age 25 + 47*i for i in 0..31 except 9 and 20, offsets 0/0/+1/+1 s, -29/-28/-30/-29 dBm;
#            burst 15 slot 3 is 3c:22:fb:c1:00:f3 (randomised by its field, no U/L bit); probes HomeWiFi (burst 3, slots 0-1),
#            Lab-Net and Cafe-Free (burst 12, slot 0)
#   joiner   da:c1:00:a2:00:01 at -34 inside burst 5 -> joins         off-band  da:c1:00:a2:00:02 at -37 inside burst 7 -> loose
#   loose    6 x 6e:c1:00:b0:00:0j at -45..-50 in one burst (age 900); 5 x 6e:c1:00:b1:00:0j at -69..-71, ages 300/1100/1250/
#            2000/2900 (cadence over 300 s); 5 x 6e:c1:00:b2:00:jj at -31 undated (4 without last_seen, 1 with 0); 6e:c1:00:b3:00:01
#            without a signal
#   genuine  20 stations with an OUI and a vendor (3 at -30 inside cloud bursts: never members); 7a:c1:00:c0:00:01 has the U/L bit
#            AND a vendor, so it is not randomised
#   APs      02:00:5e:c1:0n:01, each with a fifth byte of its own: no device rule (§8.8) can link two of them, not even with the
#            U/L exclusion removed (the planted fault of tools/regress.d/data-oracle.sh), so the HomeWiFi ESS stays what it is
def build_clouds_doc(generated, center):
    def ap(n, ssid, band, ch, rssi, sec, age):
        return fixed_ap("02:00:5e:c1:%02x:01" % n, ssid, band, ch, rssi, sec, last_seen=generated - age)

    aps = [ap(1, "HomeWiFi", "2.4GHz", 6, -48, "WPA2", 5), ap(2, "HomeWiFi", "5GHz", 36, -55, "WPA2", 8),
           ap(3, "Office-5G", "5GHz", 44, -62, "WPA3", 12), ap(4, "Lab-Net", "2.4GHz", 1, -70, "WPA2", 20),
           ap(5, "Guest-Net", "2.4GHz", 11, -74, "Open", 30), ap(6, "", "5GHz", 149, -80, "WPA2", 40)]
    aps[0]["clients"] = [{"mac": "aa:c1:00:00:a0:01", "rssi": -29, "last_seen": generated - 20, "randomized": True}]
    aps[2]["clients"] = [{"mac": "3c:22:fb:c1:00:a1", "rssi": -61, "vendor": "Apple", "last_seen": generated - 15}]
    un, pat = [], (-29, -28, -30, -29)
    for i in range(32):
        if i in (9, 20):
            continue
        for j in range(4):
            m = {"mac": "da:c1:00:a1:%02x:%02x" % (i, j), "rssi": pat[j], "last_seen": generated - (25 + 47 * i) + (1 if j >= 2 else 0),
                 "randomized": True}
            if i == 15 and j == 3:
                m["mac"] = "3c:22:fb:c1:00:f3"
            if i == 3 and j in (0, 1):
                m["probes"] = ["HomeWiFi"]
            if i == 12 and j == 0:
                m["probes"] = ["Lab-Net", "Cafe-Free"]
            un.append(m)
    un.append({"mac": "da:c1:00:a2:00:01", "rssi": -34, "last_seen": generated - (25 + 47 * 5), "randomized": True})
    un.append({"mac": "da:c1:00:a2:00:02", "rssi": -37, "last_seen": generated - (25 + 47 * 7), "randomized": True})
    for j, r in enumerate((-45, -46, -47, -48, -49, -50)):
        un.append({"mac": "6e:c1:00:b0:00:%02x" % j, "rssi": r, "last_seen": generated - 900, "randomized": True})
    for j, (r, a) in enumerate(((-70, 300), (-71, 1100), (-69, 1250), (-70, 2000), (-70, 2900))):
        un.append({"mac": "6e:c1:00:b1:00:%02x" % j, "rssi": r, "last_seen": generated - a, "randomized": True})
    for j in range(4):
        un.append({"mac": "6e:c1:00:b2:00:%02x" % j, "rssi": -31, "randomized": True})
    un.append({"mac": "6e:c1:00:b2:00:10", "rssi": -31, "last_seen": 0, "randomized": True})
    un.append({"mac": "6e:c1:00:b3:00:01", "rssi": None, "last_seen": generated - 60, "randomized": True})
    vend = (("3c:22:fb", "Apple"), ("8c:f5:a3", "Samsung Electronics"), ("24:6f:28", "Espressif"), ("50:c7:bf", "TP-Link"),
            ("dc:a6:32", "Raspberry Pi Foundation"))
    for j in range(20):
        o, v = vend[j % 5]
        un.append({"mac": "%s:c1:01:%02x" % (o, j), "rssi": -30 if j < 3 else -40 - 2 * j, "vendor": v,
                   "last_seen": generated - (25 + 47 * (j + 1)) if j < 3 else generated - 30 * j})
    un.append({"mac": "7a:c1:00:c0:00:01", "rssi": -29, "vendor": "Espressif", "last_seen": generated - 25})
    return {"generated": generated, "center": {"label": center, "max_age": 3600, "interval": 30}, "source": "recon-db",
            "aps": aps, "unassociated": un}


# --------------------------------------------------------------------------- alerts fixture (0.2: the firmware's deauth/disassoc alert)
# Six access points, all WPA2 or WPA3 (so the only red line the Overview may print is the alert's), two with a station and three free stations,
# and alerts[] as the collector writes it: {type, t, ap, n}, newest first, the addresses in lower case. DOCUMENTED GROUND TRUTH
# (tools/regress.d/alerts.sh and the Overview rows of tools/regress.d/display-selftest.sh read it):
#
#   02:00:5e:a1:00:01  "alert-a"  2.4 GHz ch 1    n 9, newest, 38 s before `generated`      <- alerted
#   02:00:5e:a1:00:04  "alert-b"  5 GHz ch 36      n 4, 205 s before `generated`             <- alerted
#   02:00:5e:a1:00:77  (not in aps[])              n 2, 410 s before `generated`             <- a report for an address the capture does not hold:
#                                                  the page draws nothing for it and the Overview counts no access point for it
#   alerted access points the page draws ........ 2   (the Overview says "Deauth/disassoc frames heard: 2 APs")
#   reports in alerts[] ........................ 3   (the sum of n over the two known access points: 13)
ALERT_APS = ("02:00:5e:a1:00:01", "02:00:5e:a1:00:04")
ALERT_AGES = (38, 205, 410)    # seconds before `generated`, newest first


def build_alerts_doc(generated, center):
    plan = [("2.4GHz", 1, -41, "WPA2", "alert-a"), ("2.4GHz", 6, -52, "WPA2", "calm-b"), ("2.4GHz", 11, -60, "WPA3", "calm-c"),
            ("5GHz", 36, -48, "WPA2", "alert-b"), ("5GHz", 100, -66, "WPA3", "calm-e"), ("6GHz", 37, -73, "WPA3", "calm-f")]
    aps = [fixed_ap("02:00:5e:a1:00:%02x" % n, ssid, band, ch, rssi, sec, last_seen=generated - 5 * n)
           for n, (band, ch, rssi, sec, ssid) in enumerate(plan, 1)]
    aps[1]["clients"] = [{"mac": "3c:22:fb:a1:00:01", "rssi": -57, "last_seen": generated - 12}]
    aps[4]["clients"] = [{"mac": "8c:f5:a3:a1:00:02", "rssi": -69, "last_seen": generated - 30}]
    unassoc = [{"mac": "3c:22:fb:a1:00:10", "rssi": -61, "last_seen": generated - 20},
               {"mac": "8c:f5:a3:a1:00:11", "rssi": -70, "last_seen": generated - 45},
               {"mac": "24:6f:28:a1:00:12", "rssi": -75, "last_seen": generated - 90}]
    alerts = [{"type": "deauth", "t": generated - age, "ap": ap, "n": n}
              for age, ap, n in zip(ALERT_AGES, ALERT_APS + ("02:00:5e:a1:00:77",), (9, 4, 2))]
    return {"generated": generated, "center": {"label": center}, "source": "recon-db",
            "alerts": alerts, "aps": aps, "unassociated": unassoc}


# --------------------------------------------------------------------------- radio-pair fixture (0.2: Bluetooth, activity, traffic)
# Hand-built, synthetic (locally administered addresses 02:00:00:00:NN:NN, placeholder names, the Bluetooth SIG's test company id 65535; P9).
# DOCUMENTED GROUND TRUTH (tools/regress.d/radio-pair.sh pins it, R3's parity rows read it):
#
#   access points .................... 10 (02:00:00:00:01:01 .. 06 and 09 .. 0c; 01:0b is the 5 GHz ch 100 one the kept-apart row baselines)
#   hidden without a name ............ 02:00:00:00:01:06 (ssid "")
#   stations ......................... 20 free (02:00:00:00:02:01 .. 14), 4 of them with "packets" (02:00:00:00:02:01 .. 04: 1520, 310, 48, 9)
#   channels[] ....................... last_heard on 2412 and 5180 only
#   activity[] ....................... 2412 .280 · 2437 .240 · 5180 .160 · 5500 .100 · 2452 .120 · 5320 .060 (sorted by freq); 2452 and 5320 have no AP
#   bluetooth[] ...................... 9 addresses in 6 marks (strongest first): 02:00:00:00:04:01 -50, :02 -56, :03 -58 (Maker A, rotating, ring 1: ONE mark of 3),
#                                      :09 -63 (Maker A, public: its own mark), :05 -66 (no company, rotating, ring 2) and :06 -75 (same: ONE mark of 2),
#                                      :04 -72 (Maker A, rotating, ring 2: its own mark), :08 -77 (random-static, name "Sensor-1": its own mark, 75 s old),
#                                      :07 -83 (no company, rotating, ring 3: its own mark); 7 rotating, 2 fixed
#   center ........................... bt_window 6, bt_hold 120, max_age 3600, interval 30
def build_radio_doc(generated, center):
    g = generated
    ap = lambda n, ssid, band, ch, rssi, sec, age, **o: fixed_ap("02:00:00:00:01:%02x" % n, ssid, band, ch, rssi, sec, last_seen=g - age, **o)
    aps = [ap(1, "HomeNet", "2.4GHz", 1, -44, "WPA2", 4), ap(2, "HomeNet", "5GHz", 36, -48, "WPA2", 6),
           ap(3, "Neighbour-A", "2.4GHz", 6, -58, "WPA2", 9), ap(4, "Cafe-Guest", "2.4GHz", 11, -66, "Open", 15),
           ap(5, "Office-5G", "5GHz", 44, -61, "WPA3", 11), ap(6, "", "2.4GHz", 6, -72, "WPA2", 20),
           ap(9, "Lab-Net", "2.4GHz", 1, -70, "WPA2", 30), ap(10, "Guest-5G", "5GHz", 52, -74, "Open", 45),
           ap(11, "Hub-4432", "5GHz", 100, -58, "WPA3", 14), ap(12, "Legacy-Net", "2.4GHz", 4, -82, "WEP", 90)]
    un = []
    for i in range(1, 21):
        o = {"mac": "02:00:00:00:02:%02x" % i, "rssi": -52 - 2 * i, "last_seen": g - (6 + 9 * i)}
        if i <= 8:
            o["vendor"] = "Vendor %s" % "GHIJKLMN"[i - 1]
        else:
            o["randomized"] = True
        if i <= 4:
            o["packets"] = (1520, 310, 48, 9)[i - 1]
        un.append(o)
    def bt(n, t, rssi, reps, age, maker=False, name=None, connectable=False):   # the key order of spec 1.2; optional keys only when set
        o = {"addr": "02:00:00:00:04:%02x" % n, "addr_type": t, "rssi": rssi, "reports": reps, "last_seen": g - age}
        if maker:
            o.update(company=65535, company_name="Maker A")
        if name:
            o["name"] = name
        if connectable:
            o["connectable"] = True
        return o

    bluetooth = [bt(1, "random-resolvable", -50, 3, 4, True, connectable=True), bt(2, "random-resolvable", -56, 2, 4, True),
                 bt(3, "random-resolvable", -58, 1, 10, True), bt(9, "public", -63, 2, 4, True, connectable=True),
                 bt(5, "random-nonresolvable", -66, 2, 4), bt(4, "random-resolvable", -72, 1, 40, True),
                 bt(6, "random-nonresolvable", -75, 1, 4), bt(8, "random-static", -77, 1, 75, name="Sensor-1"),
                 bt(7, "random-nonresolvable", -83, 1, 4)]
    activity = [{"freq": f, "share": s} for f, s in ((2412, 0.28), (2437, 0.24), (2452, 0.12), (5180, 0.16), (5320, 0.06), (5500, 0.1))]
    activity.sort(key=lambda x: x["freq"])
    channels = [{"freq": 2412, "last_heard": g - 27}, {"freq": 5180, "last_heard": g - 35}]
    return {"generated": g, "center": {"label": center, "max_age": 3600, "interval": 30, "bt_window": 6, "bt_hold": 120}, "source": "recon-db",
            "bluetooth": bluetooth, "activity": activity, "channels": channels, "aps": aps, "unassociated": un}


# --------------------------------------------------------------------------- random-clouds scenes beyond one device (spec §8.8a)
# Four scenes for the rule's weak points, all synthetic (locally administered addresses, nothing real): they are generated when a row of
# tools/regress.d/clouds.sh needs them, not stored. A tiny integer generator (no random module) keeps them identical on every machine.
#   two     a phone (4 addresses every 47 s) and a laptop (4 every 61 s), both at -31..-29 dBm, one hour: two scanning devices at the
#           same signal. TRUTH: the phone's 308 addresses (da:c2:a1:*, 77 bursts) and the laptop's 236 (da:c2:b1:*, 59 bursts), every one
#           of them in a cloud and a cloud for each (the rule may let a few of one device's bursts into the other's cloud)
#   crowd   600 unrelated randomised addresses at random times in a 5-minute window, signal around -68 dBm (sd about 8): a busy place.
#           TRUTH: 0 clouds (a crowd has no rhythm). The seed is one for which the first rule, a flat share of gaps on one period, folded
#           the crowd into a cloud of 206 addresses
#   wide    the phone alone (3 addresses per burst, every 47 s, one hour) with a wide spread: -28, -34 and -40 dBm in every burst, three
#           signal bands of one device. TRUTH: 1 cloud of all 231 addresses (da:c2:a1:*), the bands' streams merged into it
#   strays  the phone alone (one hour) with 40 single addresses in its signal band at random times, none within 6 s of a burst.
#           TRUTH: 1 cloud, the phone's 308 addresses; the strays are not in it (a stray can only join by being heard inside a burst)
#   dense   1500 unrelated randomised addresses at random times in 15 minutes, signal around -60 dBm (sd about 7): a very busy place. TRUTH: 0
#           clouds. The seed is one for which the previous rule (pairs against a Poisson chance level) made a cloud of several hundred
#   drift   the phone alone (4 addresses every 47 s) in an hour in which its signal moves 10 dB (-30 to -40 dBm): its bursts cross from one
#           signal band to the next. TRUTH: 1 cloud of all 308 addresses (the previous
#           rule made two, one per band)
#   same    two devices of one period: 4 addresses every 47 s from each, one 17 s behind the other, at one signal. TRUTH: 1 cloud of all
#           616 addresses, labelled about every 47 s, whose rhythm is mixed (no one device is claimed)
#   three   three devices at one signal, every 47, 61 and 83 s, 4 addresses a burst, one hour. TRUTH: a cloud for each of the three
#   long    the phone alone for six hours (4 addresses every 47 s, 1840 addresses). TRUTH: 1 cloud (the previous rule saw too many bursts
#           in one band and gave none)
#   wander  the phone alone whose schedule wanders: a gap of 47 s (+-1) in 70 % of the bursts, 6 to 11 s late in 14 %, a burst missed in 8 %, 47 s
#           again in the rest, 4 addresses a burst, one hour, the way a real device's bursts were heard. TRUTH: 1 cloud of all its addresses (a
#           chain of bursts breaks at every late one; the pairs that a period shows do not)
#   pair    a phone (every 47 s) and a laptop (every 73 s), 4 addresses a burst, at one signal. TRUTH: a cloud each, 336 and 160 addresses
#           of the 496 (the bursts a chance partner of the phone's period would take from the laptop are left to it; without that purge
#           the clouds are 348 and 132)
def _lcg(seed):
    x = seed & 0x7FFFFFFF
    while True:
        x = (x * 1103515245 + 12345) & 0x7FFFFFFF
        yield x >> 8


def build_clouds_mix_doc(kind, generated, center):
    ap = fixed_ap("02:00:5e:c3:01:01", "Cloud-Lab", "2.4GHz", 6, -52, "WPA2", last_seen=generated - 10)
    rnd, un = _lcg({"crowd": 2, "dense": 7}.get(kind, 1789)), []

    def device(tag, period, phase, hours=3600, pat=(-30, -29, -31, -30), fall=0):
        k, t = 0, phase
        while t < hours:
            at = t + ((k * 7) % 3) - 1                       # a jitter of -1, 0 or +1 s on every burst start
            for j in range(len(pat)):                        # fall = dB the signal loses over the hour (drift)
                un.append({"mac": "da:c2:%s:%02x:%02x:%02x" % (tag, k >> 8, k & 255, j), "rssi": pat[j] - (fall * t + 1800) // 3600,
                           "last_seen": generated - at + (1 if j >= 2 else 0), "randomized": True})
            k, t = k + 1, t + period
        return k

    if kind == "two":
        device("a1", 47, 25)
        device("b1", 61, 40)
    elif kind == "wide":
        device("a1", 47, 25, pat=(-28, -34, -40))
    elif kind == "strays":
        n = device("a1", 47, 25)
        for i in range(40):                                  # random times, none within 6 s of a burst of the phone
            while True:
                at = next(rnd) % 3600
                if all(abs(at - (25 + 47 * b)) > 6 for b in range(n)):
                    break
            un.append({"mac": "6e:c2:%02x:%02x:00:%02x" % (i >> 8, i & 255, 1), "rssi": -30 + (next(rnd) % 3) - 1,
                       "last_seen": generated - at, "randomized": True})
    elif kind == "dense":
        for i in range(1500):
            r = -60 + ((next(rnd) % 17) - 8) + ((next(rnd) % 17) - 8)
            un.append({"mac": "a2:c2:%02x:%02x:00:%02x" % (i >> 8, i & 255, 1), "rssi": r,
                       "last_seen": generated - (next(rnd) % 900), "randomized": True})
    elif kind == "drift":
        device("a1", 47, 25, fall=10)
    elif kind == "same":
        device("a1", 47, 25, pat=(-30, -29, -31, -30))
        device("b1", 47, 42, pat=(-31, -30, -30, -31))
    elif kind == "three":
        device("a1", 47, 25, pat=(-32, -31, -33, -32))
        device("b1", 61, 40, pat=(-32, -31, -33, -32))
        device("c1", 83, 55, pat=(-32, -31, -33, -32))
    elif kind == "long":
        device("a1", 47, 25, hours=21600)
    elif kind == "pair":
        device("a1", 47, 25)
        device("b1", 73, 40, pat=(-31, -30, -30, -31))
    elif kind == "wander":
        k, at, pat = 0, 30, (-30, -29, -31, -30)
        while at < 3600:
            for j in range(len(pat)):
                un.append({"mac": "da:c2:a1:%02x:%02x:%02x" % (k >> 8, k & 255, j), "rssi": pat[j], "last_seen": generated - at + (1 if j >= 2 else 0),
                           "randomized": True})
            u = next(rnd) % 100
            gap = 47 + (next(rnd) % 3) - 1 if u < 70 else 47 + 6 + next(rnd) % 6 if u < 84 else 94 + (next(rnd) % 3) - 1 if u < 92 else 47
            k, at = k + 1, at + gap
    elif kind == "crowd":
        for i in range(600):
            r = -68 + ((next(rnd) % 17) - 8) + ((next(rnd) % 9) - 4) // 2
            un.append({"mac": "a2:c2:%02x:%02x:00:%02x" % (i >> 8, i & 255, 1), "rssi": r,
                       "last_seen": generated - (next(rnd) % 300), "randomized": True})
    else:
        raise ValueError(kind)
    return {"generated": generated, "center": {"label": center, "max_age": {"crowd": 300, "dense": 900, "long": 21600}.get(kind, 3600), "interval": 30},
            "source": "recon-db", "aps": [ap], "unassociated": un}


# --------------------------------------------------------------------------- contract check
REQUIRED_TOP = ("generated", "center", "source", "aps", "unassociated")
OPT_TOP = {"note", "channels", "bluetooth", "activity", "alerts"}   # additive optional top-level keys the collector emits (channels[] = hop info; bluetooth[] and activity[] are the radio pair, contract 3; alerts[] the firmware's deauth/disassoc alert, 0.2)
OPT_CENTER = {"max_age", "interval", "own_bssids", "own_ssids", "bt_window", "bt_hold"}
AP_KEYS = ("bssid", "ssid", "channel", "band", "freq", "rssi", "security", "clients")
# akm/cipher/auth/responded_ssids exist on APs only (never on a station, P1); packets is accepted when a source reports it
OPT_AP = {"vendor", "rate", "last_seen", "width", "phy", "akm", "cipher", "auth", "responded_ssids", "packets"}
OPT_CL = {"vendor", "last_seen", "randomized", "probes", "packets"}
BT_TYPES = ("public", "random-static", "random-resolvable", "random-nonresolvable", "random")   # bluetooth[].addr_type
BT_KEYS = ("addr", "addr_type", "rssi", "reports", "last_seen")                                 # always written
OPT_BT = {"company", "company_name", "name", "connectable"}                                      # written only when the advertisement has them
IWSCAN_OPT_AP = {"vendor"}    # build_from_iwscan() emits no rate/last_seen/width/phy


def validate_alerts(al):
    """alerts[] (0.2): {type, t, ap, n} in that order, type "deauth", t a whole number of seconds, ap a lower-case MAC, n a whole count above 0;
    at most 20, newest first, one entry per access point."""
    if not isinstance(al, list):
        return ["alerts must be an array"]
    p = []
    if len(al) > 20:
        p.append("alerts: more than 20 entries")
    for i, e in enumerate(al):
        ok = (isinstance(e, dict) and list(e) == ["type", "t", "ap", "n"] and e["type"] == "deauth"
              and all(isinstance(e[k], int) and not isinstance(e[k], bool) for k in ("t", "n")) and e["t"] >= 0 and e["n"] > 0
              and isinstance(e["ap"], str) and re.fullmatch(r"([0-9a-f]{2}:){5}[0-9a-f]{2}", e["ap"]) is not None)
        if not ok:
            p.append("alerts[%d]: needs type deauth, a whole t >= 0, a lower-case MAC ap and a whole n > 0, in that order" % i)
    ts = [e["t"] for e in al if isinstance(e, dict) and isinstance(e.get("t"), int)]
    if ts != sorted(ts, reverse=True):
        p.append("alerts must be sorted by t, newest first")
    aps = [e["ap"] for e in al if isinstance(e, dict) and isinstance(e.get("ap"), str)]
    if len(aps) != len(set(aps)):
        p.append("alerts: one entry per access point")
    return p


def validate_bluetooth(bt):
    """bluetooth[] (spec 1.2): at most 256 records, strongest first (rssi descending, then addr); problems as a list."""
    if not isinstance(bt, list):
        return ["bluetooth must be an array"]
    p, seen = [], set()
    if len(bt) > 256:
        p.append("bluetooth: more than 256 records")
    for i, b in enumerate(bt):
        w = "bluetooth[%d]" % i
        if not isinstance(b, dict):
            p.append(w + ": not an object")
            continue
        p += ["%s: missing %r" % (w, k) for k in BT_KEYS if k not in b]
        extra = set(b) - set(BT_KEYS) - OPT_BT
        if extra:
            p.append("%s: unknown keys %s" % (w, sorted(extra)))
        a = b.get("addr")
        if not (isinstance(a, str) and re.fullmatch(r"[0-9a-f]{2}(:[0-9a-f]{2}){5}", a)):
            p.append(w + ": addr must be a lower-case xx:xx:xx:xx:xx:xx string")
        else:   # only a valid string is hashed: a list or an object as addr is a problem to report, not a crash
            if a in seen:
                p.append(w + ": duplicate addr")
            seen.add(a)
        if b.get("addr_type") not in BT_TYPES:
            p.append("%s: addr_type must be one of %s" % (w, ", ".join(BT_TYPES)))
        for k in ("rssi", "last_seen"):
            if k in b and not (isinstance(b[k], int) and not isinstance(b[k], bool)):
                p.append("%s: %s must be an integer" % (w, k))
        if "reports" in b and not (isinstance(b["reports"], int) and not isinstance(b["reports"], bool) and b["reports"] >= 1):
            p.append(w + ": reports must be an integer >= 1")
        if "company" in b and not (isinstance(b["company"], int) and not isinstance(b["company"], bool) and 0 <= b["company"] <= 65535):
            p.append(w + ": company must be an integer 0..65535")
        for k, n in (("company_name", 48), ("name", 32)):
            if k in b and not (isinstance(b[k], str) and 0 < len(b[k]) <= n):
                p.append("%s: %s must be a non-empty string of <= %d characters" % (w, k, n))
        if "connectable" in b and b["connectable"] is not True:
            p.append(w + ": connectable is written only when true")
    order = [(-b["rssi"], b["addr"]) for b in bt if isinstance(b, dict) and isinstance(b.get("rssi"), int) and isinstance(b.get("addr"), str)]
    if order != sorted(order):
        p.append("bluetooth must be sorted strongest first (rssi descending, then addr)")
    return p


def validate_activity(act):
    """activity[] (spec 1.3): {freq, share} sorted by freq, 0 < share <= 1, never more than 69, shares of one capture summing to at most 1."""
    if not isinstance(act, list):
        return ["activity must be an array"]
    p = []
    if len(act) > 69:
        p.append("activity: more than 69 entries")
    for i, e in enumerate(act):
        if not (isinstance(e, dict) and set(e) == {"freq", "share"} and isinstance(e["freq"], int) and not isinstance(e["freq"], bool) and e["freq"] >= 2400
                and isinstance(e["share"], (int, float)) and not isinstance(e["share"], bool) and 0 < e["share"] <= 1):
            p.append("activity[%d]: needs an integer freq >= 2400 MHz and a share in (0, 1]" % i)
    freqs = [e["freq"] for e in act if isinstance(e, dict) and isinstance(e.get("freq"), int)]
    if freqs != sorted(set(freqs)):
        p.append("activity must be sorted by freq without duplicates")
    if sum(e["share"] for e in act if isinstance(e, dict) and isinstance(e.get("share"), (int, float))) > 1.0001:
        p.append("activity shares sum to more than 1")
    return p


def whole(v):
    """True for an integer that is not a bool (JSON true/false are Python ints as well)."""
    return isinstance(v, int) and not isinstance(v, bool)


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
    for k in ("bt_window", "bt_hold"):
        if k in c and not (isinstance(c[k], int) and not isinstance(c[k], bool) and c[k] >= 0):
            p.append("center.%s must be a non-negative integer" % k)
    if ("bt_window" in c or "bt_hold" in c) and not ("bluetooth" in doc and "bt_window" in c and "bt_hold" in c):
        p.append("center.bt_window and center.bt_hold go together with a bluetooth array")
    if "bluetooth" in doc:
        p += validate_bluetooth(doc["bluetooth"])
    if "activity" in doc:
        p += validate_activity(doc["activity"])
    if "alerts" in doc:
        p += validate_alerts(doc["alerts"])
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
        if not isinstance(c["mac"], str):   # not hashed: a list or an object as mac is a problem to report, not a crash
            p.append("%s: mac must be a string" % where)
        else:
            if c["mac"] in macs:
                p.append("%s: duplicate mac %s" % (where, c["mac"]))
            macs.add(c["mac"])
        if not (c["rssi"] is None or whole(c["rssi"])):   # a station without a signal carries null (clouds.json, devices.json)
            p.append("%s: rssi must be an integer or null" % where)
        extra = set(c) - {"mac", "rssi"} - OPT_CL
        if extra:
            p.append("%s: unknown client keys %s" % (where, sorted(extra)))
        if legacy and set(c) - {"mac", "rssi"}:
            p.append("%s: legacy must not carry optional keys" % where)
        if "packets" in c and not (isinstance(c["packets"], int) and not isinstance(c["packets"], bool) and c["packets"] >= 0):
            p.append("%s: packets must be an integer >= 0" % where)

    for i, ap in enumerate(doc["aps"]):
        w = "aps[%d]" % i
        if not isinstance(ap, dict):
            p.append(w + ": not an object")
            continue
        p += ["%s: missing %r" % (w, k) for k in AP_KEYS if k not in ap]
        if "bssid" in ap and not isinstance(ap["bssid"], str):   # not hashed: a list or an object as bssid is a problem to report, not a crash
            p.append("%s: bssid must be a string" % w)
        else:   # a missing bssid is reported above and still counts once, as before
            if ap.get("bssid") in macs:
                p.append("%s: duplicate bssid" % w)
            macs.add(ap.get("bssid"))
        for k in ("ssid", "security"):   # the collector writes both as strings (an unnamed network is "", never null)
            if k in ap and not isinstance(ap[k], str):
                p.append("%s: %s must be a string" % (w, k))
        for k in ("channel", "freq", "rssi"):   # whole numbers; the collector writes null when a source gives none
            if k in ap and not (ap[k] is None or whole(ap[k])):
                p.append("%s: %s must be an integer or null" % (w, k))
        if "clients" in ap and not isinstance(ap["clients"], list):
            p.append("%s: clients must be an array" % w)
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
        for j, c in enumerate(ap["clients"] if isinstance(ap.get("clients"), list) else []):
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
    ap.add_argument("--stamp", metavar="FILE", help="add a deterministic last_seen to every AP of the recon-db or pineap fixture FILE (in place, idempotent)")
    ap.add_argument("--stamp-mean", type=float, default=90.0, help="mean age in seconds for --stamp (default 90)")
    ap.add_argument("--secsuite", action="store_true",
                    help="the security-suite fixture (one AP per security class with akm/cipher/auth, responder, channels[], center extras)")
    ap.add_argument("--aged", action="store_true",
                    help="the D1 freshness fixture (14 APs and 5 stations at hand-picked last_seen ages, see build_aged_doc)")
    ap.add_argument("--radio", action="store_true",
                    help="the radio-pair fixture (radio-pair.json: bluetooth[], activity[], station packets, a hidden network without a name; see build_radio_doc())")
    ap.add_argument("--alerts", action="store_true",
                    help="the alerts fixture (alerts.json: six access points, two of them alerted, and a report for an address the capture does not hold; see build_alerts_doc())")
    ap.add_argument("--devices", action="store_true",
                    help="emit the hand-built logical AP grouping fixture (devices.json, spec §8.8); see build_devices_doc()")
    ap.add_argument("--clouds", nargs="?", const="one", choices=("one", "two", "crowd", "strays", "wide", "dense", "drift", "same", "three", "long", "pair", "wander"),
                    help="the random-clouds fixture (clouds.json, spec §8.8a: one device's bursts of randomised addresses and what must stay apart; see build_clouds_doc()); "
                         "two, crowd, strays, wide, dense, drift, same, three and long are the scenes of build_clouds_mix_doc(): two devices at one signal, a crowd, a device among strays, a device with a wide spread, a very dense crowd, a drifting device, two of one period, three devices, six hours of one, a phone and a laptop of 47 s and 73 s, a device whose schedule wanders")
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
        recon = doc.get("source") in LAST_SEEN_SOURCES
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
            args.validate, len(aps), sum(len(a["clients"]) for a in aps if isinstance(a, dict) and isinstance(a.get("clients"), list)),
            len(doc.get("unassociated", [])), doc.get("source"), "FAILED" if probs else "OK"))   # a malformed entry is already in probs: the summary must not crash on it
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
    elif args.radio:
        doc = build_radio_doc(args.generated, args.center)
    elif args.alerts:
        doc = build_alerts_doc(args.generated, args.center)
    elif args.clouds == "one":
        doc = build_clouds_doc(args.generated, args.center)
    elif args.clouds:
        doc = build_clouds_mix_doc(args.clouds, args.generated, args.center)
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
