#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""
gen-recon.py -- a synthetic recon.db at the scale the device was measured at (docs/device-notes.md section 6a, 14 October 2026).

What it makes: the three tables the collector reads (ssid, wifi_device, scan) with 21,123 rows of type 4 (probe requests), 338 of type 5
(probe responses) and 1,461 of type 8 (beacons), 22,606 stations, and, inside a one-hour window ending at NOW, 29 access points and 299
stations. Every name is invented ("Fixture-NNN", "Fixture-Probe-NNNN") and every address is in the locally administered range
02:00:00:xx:xx:xx (written without colons, as the firmware's database does), so nothing here can belong to a real network or device.
As a consequence no address has a vendor to look up: the census exercises the OUI index build but not the per-address lookup.

Deterministic: the same NOW gives the same bytes of rows (random.seed(7)); only the file's page layout may differ between SQLite builds.
Needs: python3 (stdlib, sqlite3 module). Writes only the file named on the command line. Nothing here touches the device or the network.

usage: python3 -B -I gen-recon.py OUT.db NOW        (NOW = epoch seconds; the window is the hour before it)
"""
import os
import random
import sqlite3
import sys

if len(sys.argv) != 3:
    sys.exit(__doc__)
out, now = sys.argv[1], int(sys.argv[2])
random.seed(7)
if os.path.exists(out):
    os.remove(out)
db = sqlite3.connect(out)
db.executescript("""
CREATE TABLE ssid(hash INT PRIMARY KEY, wifi_device INT, scan INT, type INT, bssid TEXT, ssid BLOB, hidden INT, time INT, signal INT, freq INT, channel INT, encryption INT, UNIQUE(hash) ON CONFLICT REPLACE);
CREATE TABLE wifi_device(hash INT PRIMARY KEY, scan INT, mac TEXT, time INT, signal INT, freq INT, packets INT, UNIQUE(hash) ON CONFLICT REPLACE);
CREATE TABLE scan(id INTEGER PRIMARY KEY, uuid TEXT, time INT, name TEXT);
""")


def mac():
    return "020000%06X" % random.randrange(1 << 24)


enc = [0, 17184063752, 6597073961232, 2216207319320, 17184063752]
aps = []
for i in range(150):
    aps.append((mac(), "Fixture-%03d" % i, random.choice([2412, 2437, 2462, 5180, 5220, 5500, 5745, 5955]), random.choice(enc)))
now_aps = aps[:29]
h = 1
# type 8 beacons: 1,461 rows; the 29 access points inside the window get about ten rows each in the last hour, the rest are older
rows8 = []
for a in now_aps:
    for k in range(10):
        rows8.append((a, now - random.randrange(3500)))
while len(rows8) < 1461:
    a = random.choice(aps[29:])
    rows8.append((a, now - random.randrange(4000, 86400 * 7)))
for a, t in rows8:
    fr = a[2]
    ch = (fr - 2407) // 5 if fr < 3000 else (fr - 5000) // 5
    db.execute("INSERT INTO ssid VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", (h, 0, 1, 8, a[0], a[1].encode(), 0, t, -random.randrange(40, 92), fr, ch, a[3]))
    h += 1
for k in range(338):   # type 5, probe responses
    inw = k <= 60
    a = random.choice(now_aps if inw else aps[29:])
    t = now - random.randrange(3500) if inw else now - random.randrange(4000, 86400 * 7)
    db.execute("INSERT INTO ssid VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", (h, 0, 1, 5, a[0], ("Fixture-%03d" % random.randrange(150)).encode(), 0, t, -random.randrange(40, 92), a[2], 6, a[3]))
    h += 1
# wifi_device: 22,606 rows, 299 of them inside the window; ssid of type 4: 21,123 rows
devs = []
for d in range(22606):
    inwin = d < 299
    t = now - random.randrange(3500) if inwin else now - random.randrange(4000, 86400 * 7)
    devs.append((100000 + d, mac(), t))
    db.execute("INSERT INTO wifi_device VALUES (?,?,?,?,?,?,?)", (100000 + d, 1 + d % 22, devs[-1][1], t, -random.randrange(40, 92), 0, random.randrange(1, 90000)))
ssid_pool = ["Fixture-Probe-%04d" % i for i in range(1500)]
for k in range(21123):
    d = devs[k % 22606] if k >= 1000 else devs[k % 299]
    t = d[2] if k >= 1000 else now - random.randrange(3500)
    db.execute("INSERT INTO ssid VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", (h, d[0], 1, 4, "FFFFFFFFFFFF", random.choice(ssid_pool).encode(), 0, t, -random.randrange(40, 92), 0, 0, 0))
    h += 1
db.commit()
db.execute("VACUUM")
db.close()
print(out, os.path.getsize(out))
