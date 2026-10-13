# Starchorus

**Strictly passive: it receives and never transmits.** Starchorus shows the Wi-Fi around a device as
a night sky: a shell script on the device listens, and a single HTML page draws the sky from what it
hears.

Starchorus is written for the **Hak5 WiFi Pineapple Pager**, and 'the device' throughout this
repository means the Pager. It is an independent project, not affiliated with, sponsored or endorsed
by Hak5; see [Trademarks](#trademarks).

[![quick (T1)](https://github.com/starchorus/pager/actions/workflows/quick.yml/badge.svg)](https://github.com/starchorus/pager/actions/workflows/quick.yml)
[![Licence: GPL-3.0-or-later](https://img.shields.io/badge/Licence-GPL--3.0--or--later-blue.svg)](LICENSE)
[![Release: v0.1.0](https://img.shields.io/badge/Release-v0.1.0-orange.svg)](https://github.com/starchorus/pager/releases)

[Quick start](#quick-start) · [Installation](INSTALL.md) · [Payload](#payload) · [Passivity](#passivity-as-a-design-guarantee) ·
[Configuration](#configuration) · [Licence](#licence) · [Contributing](CONTRIBUTING.md) ·
[Security](SECURITY.md) · [Code of Conduct](CODE_OF_CONDUCT.md)

[![Starchorus in the Foundation theme: the device in the centre, access points as stars coloured by band, clients as satellites, signal-level rings in dBm, the legend on the left, the counter bar along the top, channel bars and the control panel along the bottom](docs/img/starchorus-foundation.jpg)](docs/img/starchorus-foundation.jpg)

<table>
  <tr>
    <td align="center" width="33%"><a href="docs/img/starchorus-foundation.jpg"><img src="docs/img/starchorus-foundation.jpg" width="260" alt="Foundation theme: a quiet star chart on a dark blue ground"></a><br><sub><b>Foundation</b> (default)</sub></td>
    <td align="center" width="33%"><a href="docs/img/starchorus-wargames.jpg"><img src="docs/img/starchorus-wargames.jpg" width="260" alt="WarGames theme: a situation-wall look in green and cyan on black with diagonal grid lines"></a><br><sub><b>WarGames</b></sub></td>
    <td align="center" width="33%"><a href="docs/img/starchorus-whitehall.jpg"><img src="docs/img/starchorus-whitehall.jpg" width="260" alt="Whitehall theme: a plotting-table look on a dark olive ground with an EXERCISE banner at the top and a notice banner at the bottom"></a><br><sub><b>Whitehall</b></sub></td>
  </tr>
</table>

<sub>All images show the built-in demo mode: simulated sample data with placeholder names, not a real environment. `T` switches between the themes.</sub>

## Overview

The device sits in the centre, each access point is a star, and its clients orbit it as satellites.
Signal strength sets the orbit radius (stronger = closer to the centre), the colour stands for the
band (2.4/5/6 GHz), and a fine ring for the encryption.

- **Collector.** `starchorus-collect.sh`, a POSIX shell script on the device, reads the device's
  recon database (from a read-only copy) or listens in monitor mode, and writes `starchorus.json`.
- **Page.** `starchorus.html` is one self-contained page without external resources. It reads
  `starchorus.json` every 5 seconds. The Pager's display is too small for a sky, so the page is
  meant for a second screen: a laptop, tablet or phone on the Pager's USB-C or management Wi-Fi
  opens `http://172.16.52.1:8199/`, with nothing to install.
- **On-device dashboard.** `starchorus-display.sh` shows the same data, as counts and lists, on the
  device's own display, for a glance when no second screen is to hand.
- **Payload.** On the device, the payload in `library/user/reconnaissance/starchorus/` starts the
  collector, the page server (port 8199) and the dashboard.
- **In your browser.** The demonstration runs at <https://starchorus.com/pager/>, nothing to install.
- **Without hardware.** Run `python3 -m http.server --bind 127.0.0.1 8000` in this folder and open
  `http://127.0.0.1:8000/`; with no data file, the page runs a built-in demo.

Starchorus never transmits. The one exception, an active scan, needs an explicit opt-in
(`STARCHORUS_ALLOW_ACTIVE=1`) and is off by default. The code is under GPL-3.0-or-later; the
embedded font is under the SIL OFL 1.1 (see [Licence](#licence)).

## Why a sky

A Wi-Fi survey usually arrives as a table: dozens of rows of BSSIDs, channels and dBm figures,
accurate and very nearly unreadable. Starchorus draws the same facts as a sky. Which networks
dominate, which channels are crowded, which devices are asking after networks, and how all of it
changes over a few minutes can be taken in at a glance rather than worked out line by line.

That makes it useful beyond the person holding the Pager: for teaching how Wi-Fi actually behaves,
for explaining a site survey to someone who does not read dBm, and for putting on a screen what is
otherwise invisible. The built-in demo, with simulated data and placeholder names, is suitable for
on-set playback and screen graphics in film and television as it stands: it looks the part and
discloses nothing about anyone. If Starchorus appears on screen, a credit is appreciated, though
the licence does not require one.

## Version

Starchorus 0.1.0. Every part carries the same number:

| Part | File | Version |
|---|---|---|
| Page | `starchorus.html` | 0.1.0 |
| Collector | `starchorus-collect.sh` | 0.1.0 |
| On-device dashboard | `starchorus-display.sh` | 0.1.0 |
| Payload | `library/user/reconnaissance/starchorus/payload.sh` | 0.1.0 |

## What the page shows

- **The turning sky.** The whole sky turns slowly about the device, one revolution in five minutes
  (key `S`, on by default). The rotation is rigid: every distance from the centre (= signal strength)
  and every distance between two nodes stays exact. Pause and Reduced Motion hold the sky still;
  `?spin=0` switches the rotation off.
- **Rings at −40/−60/−80 dBm** mark the received signal level, not distance. Direction is not
  measured.
- **Freshness.** Star, ring and station dot dim with age (`generated − last_seen`): under 1 min,
  under 5 min, under 15 min, only in the record, undated.
- **Derived views**, each display only and without new JSON fields:
  - Device links (`D`) group BSSIDs that probably belong to one physical device.
  - Merge SSID (`M`) folds a roaming network into one node.
  - Probe orbits (`P`) let a client circle, dashed, around the visible network it is looking for.
    The orbit is inferred, not an association.
- **Tools:** Observations (`W`), baseline diff (`B`), inventory (`I`), air quality (`Q`),
  signal over time (`J`), recording and replay (`H`), channel view (`Y`), homing meter (`F`).
  Export as JSON, CSV, SITREP text or PNG.
- **2D/3D** (`V`): a flat ring chart or a tilted orbit (height = band). The device always stays in
  the middle, and zoom centres on the device.

The page is a single HTML file without external resources. Its only network call fetches
`starchorus.json` from the same directory, every 5 seconds. It starts with a simulation marked
'Sample' and switches the chip to 'Live' as soon as the file is there. If no new capture arrives for
six polls (≈ 30 s), the chip shows 'Stale'. A fetch that has not answered after 4 s is aborted and
counts as failed. A `starchorus.json` can also be added with 'Load…' or dropped onto the page.

With a passive source, the masthead reads 'Observation only — it listens, it never transmits.'.
If the capture comes from the collector's active opt-in (`source: "iw-scan-ACTIVE"`), the page
replaces every statement of passivity with 'ACTIVE SCAN · the collector sent probe requests'.

## Passivity as a design guarantee

Starchorus contains no function that transmits or interferes:

- no deauth or disassoc
- no spoofed or impersonated access point
- no packet injection
- no association with other people's networks
- no active scan

Only the following is permitted:

- reading the device's recon database: it is copied before reading and opened with
  `sqlite3 -readonly`, so that capture is never locked;
- receiving in monitor mode (`tcpdump`, or `airodump-ng` without injection);
- tuning the receiver to a channel.

The collector creates its own monitor interface only if none exists, and removes it again on exit.
It never touches the recon radio or the management radio.

**The one exception is named plainly.** `iw scan` sends probe requests and is therefore active. The
collector uses it only with the explicit opt-in `STARCHORUS_ALLOW_ACTIVE=1`, and then as a last
resort (or when forced with `STARCHORUS_SOURCE=iwscan`). The capture then carries
`source: "iw-scan-ACTIVE"`, and the page and the dashboard say so. Default: off.

The details are in [SECURITY.md](SECURITY.md): the passivity contract, every read and output path,
and every browser storage key with its limit. `sh tools/passivity-check.sh` checks the rules
statically.

## Quick start

Step-by-step instructions: [INSTALL.md](INSTALL.md).

On the development machine, without any hardware:

```sh
sh starchorus-collect.sh --selftest              # offline, with embedded sample data
sh starchorus-display.sh --selftest              # dashboard: jq paths and a summary
sh tools/verify.sh starchorus.html demo out/demo # check the page headless with the demo (Chrome)
python3 -m http.server --bind 127.0.0.1 8000  # demo in the browser: http://127.0.0.1:8000/ (Ctrl-C stops it)
```

On the device (`<device>` is its address):

```sh
ssh root@<device> 'mkdir -p /root/loot/starchorus'
scp -O starchorus-collect.sh starchorus-serve.sh payload.sh root@<device>:/root/loot/starchorus/
scp -O starchorus.html root@<device>:/root/loot/starchorus/index.html
ssh root@<device> 'cd /root/loot/starchorus && chmod +x *.sh && ./payload.sh'   # collector + server on :8199
```

Then open `http://<device>:8199/` in the browser. `./payload.sh stop` stops the collector and the
server. `sh tools/install.sh` makes this simpler: the script copies the collector, page, dashboard,
fallback server and payload from this repository over ssh/scp and compares the checksums. It then
runs the self-tests, one passive `--once` run and a dashboard test. With `--dry-run` it only shows
the commands; `--host` or `STARCHORUS_HOST` sets the device's address.

### Collector

```sh
./starchorus-collect.sh            # loop: writes starchorus.json every STARCHORUS_INTERVAL seconds
./starchorus-collect.sh --once     # a single pass (e.g. for crond)
./starchorus-collect.sh --status   # is a loop running?
./starchorus-collect.sh --stop     # stop the loop (and any airodump-ng it started itself)
```

`--status` and `--stop` need the same `STARCHORUS_OUTDIR` as the loop, because the pidfile lives
there. One collector runs per Pager, so that two loops never share the monitor interface or radio:
starting or stopping any instance stops every other collector loop on the device, and each loop so
stopped is named on stderr with its pid and working directory. The log on stderr names the source
chosen; in the JSON it is in `"source"`. With no usable source, the collector still writes valid
JSON, with `"source": "none"` and a `"note"` giving the reason.

### Serving the page

The page must come from the same origin as `starchorus.json`, not via `file://`. Ports 80 and 1471
are left alone.

- **A) On the device:** the root `payload.sh` starts the first server available on port
  `STARCHORUS_PORT` (default 8199): `uhttpd`, BusyBox `httpd` or `python3`. The payload tries
  `uhttpd`, `python3` and finally the fallback server. Every server listens on the management
  address only (`STARCHORUS_BIND`, below), so the page is reachable over USB-C and the management
  Wi-Fi, not from a network the device has joined.
- **B) From a connected computer:** put `index.html` and the `starchorus.json` produced by the device
  in a local directory, fetch the file again at regular intervals and serve it locally.
- **C) Fallback server `starchorus-serve.sh`:** it needs only GNU netcat and serves nothing but
  `index.html` and `starchorus.json`, one connection at a time. That is enough for `curl`; for a
  browser page it is unreliable.

All paths in detail: [docs/display-paths.md](docs/display-paths.md).

## Payload

```
library/user/reconnaissance/starchorus/
├── payload.sh              # on-device menu; starts the collector, page server and dashboard; "payload.sh stop" stops everything
├── starchorus-display.sh   # byte-identical copy of the dashboard
└── README.md               # description, requirements, installation, configuration
```

The payload expects the collector and the page under `/root/loot/starchorus`; a self-contained
payload directory built by `sh tools/hak5-package.sh` for Hak5's payload library carries them beside
`payload.sh` and copies them there on its first run (details in the payload's README). It reads a
one-hour window of the recon record (`STARCHORUS_MAX_AGE=3600`) and writes every 30 seconds
(`STARCHORUS_INTERVAL=30`): the record only grows, and the device's CPU cannot process all of it on
every pass. Within the window, the page dims entries by their freshness. `STARCHORUS_MAX_AGE=0`
reads the whole record. On the device it offers a menu: 'Start', 'Dashboard', 'Services' (collector
and page, each on or off), 'Options' (window, interval, port, vendor names, own radios, channel
occupancy, dashboard after start), 'Status', 'Stop', 'Exit'. The settings live in
`/root/loot/starchorus/settings.conf`; the payload reads the file but never executes it, and an
environment variable takes precedence. `payload.sh set KEY VALUE` sets the same settings;
`payload.sh get`, `status`, `start` and `reset` work without the on-device menu. Details: the
payload's README.

The dashboard `starchorus-display.sh` reads the same `starchorus.json` and shows seven screens on the
device's display: summary, strongest networks, bands and security, devices and merges, probe
requests, stations, air quality. Its only output is LOG lines. Red stands only for an alarm (an
open or WEP network, or the line 'jq incomplete'). On the development machine,
`sh starchorus-display.sh --once <screen> <file>` prints the same content as text; `<screen>` is
`summary`, `top`, `bands`, `devices`, `probes`, `clients` or `air`.

## Configuration

All variables are optional.

**Collector** (`starchorus-collect.sh`):

| Variable | Default | Meaning |
|---|---|---|
| `STARCHORUS_INTERVAL` | `5` | Seconds between two writes (with tcpdump, also the burst length). |
| `STARCHORUS_OUTDIR` | `/tmp/starchorus` | Directory for `starchorus.json` (volatile; for persistence e.g. `/root/loot/starchorus`). |
| `STARCHORUS_IFACE` | `auto` | Monitor interface, or `auto` to detect one. |
| `STARCHORUS_SOURCE` | `auto` | `auto`, `capture`, `recondb` or `iwscan` (only with `STARCHORUS_ALLOW_ACTIVE=1`). |
| `STARCHORUS_RECON_DB` | `auto` | Path to the recon database, or `auto` to search for it. |
| `STARCHORUS_ALLOW_ACTIVE` | `0` | `1` permits the **active** `iw scan`. Leave it off. |
| `STARCHORUS_CREATE_MON` | `1` | `1` permits creating a monitor interface if none exists. |
| `STARCHORUS_MAX_AGE` | `0` | Recon database only: only devices from the last N seconds (live window, e.g. `120`); `0` = the whole record. |
| `STARCHORUS_CAPDIR` | `$OUTDIR/cap` | Capture files and the working copy of the database. |
| `STARCHORUS_PIDDIR` | `$OUTDIR` | Pidfiles. |
| `STARCHORUS_VENDOR` | `1` | `1` = fields `vendor`/`randomized` from a local OUI file; `0` = never. |
| `STARCHORUS_OUI_FILE` | `auto` | Path of the OUI file; `auto` tries the usual paths (listed in the collector's header). |
| `STARCHORUS_HOPINFO` | `0` | `1` = `channels[]` with `freq`/`last_heard` from the recon database. |
| `STARCHORUS_SURVEY` | `0` | `1` = `busy_pct`/`noise` in `channels[]` from `iw dev IF survey dump` (read-only); `STARCHORUS_SURVEY_IFACE` chooses `IF`. |
| `STARCHORUS_OWN` | `0` | `1` = own BSSIDs (interface MACs) and own SSIDs (only from `STARCHORUS_OWN_SSID_FILE`) in `center`. |
| `STARCHORUS_HOMING_BSSID` | empty | one AP for the homing meter; alternatively the first line of `$STARCHORUS_OUTDIR/homing.target`. |
| `STARCHORUS_APCLI_RO` | `0` | `1` permits `apcli_ro()` three read-only commands of the AP service; nothing calls the function. |

With `STARCHORUS_SOURCE=auto`, this order applies:

1. a monitor interface the collector created itself → `capture`;
2. otherwise a readable recon database → `recondb`;
3. otherwise an existing monitor interface it did not create → `capture`, with a warning;
4. otherwise, only with `STARCHORUS_ALLOW_ACTIVE=1`, `iwscan`;
5. otherwise `none`.

**Payload, fallback server, dashboard, installer:**

| Variable | Default | Meaning |
|---|---|---|
| `STARCHORUS_DIR` | `/root/loot/starchorus` | Installation directory (fallback server, dashboard, root `payload.sh`). |
| `STARCHORUS_PORT` | `8199` | Port of the page server. |
| `STARCHORUS_BIND` | `auto` | Address the page server listens on. `auto`: the IPv4 address of `br-lan` (USB-C and management Wi-Fi), otherwise `172.16.52.1` if an interface has it, otherwise `127.0.0.1` with a note. An IPv4 address: that address only. `all`: every interface, which makes the page and `starchorus.json` (every captured MAC address and SSID) reachable from every network the device is on. On-device payload: also the `bind` key. |
| `STARCHORUS_MAX_AGE` | `3600` | On-device payload: window of the recon record in seconds (one hour); `0` = the whole record. The collector on its own uses `0`. |
| `STARCHORUS_INTERVAL` | `30` | On-device payload: seconds between two passes. The collector on its own uses `5`. |
| `STARCHORUS_JSON` | `$STARCHORUS_DIR/starchorus.json` | File the dashboard reads. |
| `STARCHORUS_DISPLAY_TEMPLATE` | empty | a custom line on the dashboard, e.g. `'{aps} APs · crowding {crowding}'` (otherwise the first line of `display.tpl`). |
| `STARCHORUS_DISPLAY_PLAIN` | `0` | `1` = text output instead of the device's display commands. |
| `STARCHORUS_HOST` | – | Address of the device for `tools/install.sh` (like `--host`). |

**Page:** query parameters override the stored settings without storing them, for example
`?theme=whitehall`, `?view=3d`, `?intro=0`, `?rm=1` (Reduced Motion) or `?spin=0`. The full list is
in [docs/architecture.md](docs/architecture.md) §2.7.

## Themes and keys

`T` cycles through three themes without reloading; the layout stays where it is.

- **Foundation** (default): a quiet star chart. Dust clouds show freshness.
- **WarGames**: a situation-wall look with wireframe stars and monospaced capitals. `C` toggles the
  CRT overlay.
- **Whitehall**: a plotting-table look with a plotting grid. It is marked as an exercise: the banner
  is a fictional framing, and every line ends with 'NOT A GOVERNMENT SYSTEM'.

Each theme introduces itself briefly once per session. A click or a key press cuts it short;
`?intro=0` suppresses the introduction. In the detail panel, a network can be classified by hand as
friend, neutral or suspect. The page itself never classifies anything.

| Key | Action | Key | Action |
|---|---|---|---|
| `T` | Theme | `Space` | Pause / resume |
| `V` | 2D / 3D | `1` `2` `3` | Band filter 2.4 / 5 / 6 GHz |
| `S` | Sky rotation | `+` `−` `0` | Zoom, reset |
| `L` | Labels | `[` `]` | Step through pinned nodes |
| `D` `M` `P` | Device links, Merge SSID, probe orbits | `Esc` | Close dialogue or detail |
| `W` `B` `I` | Observations, baseline, inventory | `?` | All keys |

`?` on the page shows the full list; it is also in the specification (§9.6).

The page stores only settings and the operator's data (baseline, watchlist, classifications,
library, notes) under `starchorus.*` keys in the browser. 'Clear local data' in the Observations
panel deletes the baseline, watchlist and classifications.

## Data format

The collector produces exactly the format the page reads:

```json
{
  "generated": 1710000000,
  "center": { "label": "This device" },
  "source": "recon-db",
  "aps": [
    { "bssid": "aa:bb:cc:11:22:33", "ssid": "HomeNet", "channel": 6, "band": "2.4GHz", "freq": 2437,
      "rssi": -42, "security": "WPA2", "clients": [ { "mac": "c0:ff:ee:00:00:01", "rssi": -48 } ] }
  ],
  "unassociated": [ { "mac": "c0:ff:ee:00:00:02", "rssi": -66 } ]
}
```

- `"ssid": ""` means a hidden network. `channel`, `freq` and `rssi` may be `null`.
- `source` is `recon-db`, `airodump-csv`, `tcpdump`, `iw-scan-ACTIVE` or `none`.
- `clients` is filled only with `airodump-csv`. The other sources list overheard probe senders under
  `unassociated`.
- Additional fields, such as `vendor`, `last_seen`, `akm`, `cipher`, `auth`, `channels[]` or
  `homing`, are omitted when unknown; they are never `null`.

The header of `starchorus-collect.sh` describes the fields. The page's data model is in the
specification.

## Project layout

| Path | Purpose |
|---|---|
| `INSTALL.md` | step-by-step installation on the Pager, and the demo without one |
| `starchorus-collect.sh` | passive collector (POSIX sh / BusyBox), writes `starchorus.json` atomically |
| `starchorus.html` | the visualisation, one HTML/canvas file; `index.html` redirects to it |
| `starchorus-display.sh` | dashboard on the device's display |
| `starchorus-serve.sh` | netcat fallback server for devices without a web server |
| `payload.sh` | lean launcher: collector and page server |
| `library/user/reconnaissance/starchorus/` | payload (see above) |
| `packaging/hak5/` | README for the self-contained payload directory that `tools/hak5-package.sh` builds for Hak5's payload library |
| `docs/architecture.md` | specification of the page (themes, layout, keys, query parameters, `window.STARCHORUS`) |
| `docs/device-notes.md` | facts verified on the device: recon database, tools, display |
| `docs/display-paths.md` | every way to show the page or the dashboard |
| `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` | passivity contract and privacy, contribution rules, Code of Conduct |
| `docs/img/` | screenshots of the three themes in demo mode and the preview image for the project page |
| `tools/`, `tests/fixtures/` | test net and fixtures, for the development machine only ([tools/README.md](tools/README.md)) |

## Contributing

Bug reports, suggestions and pull requests are welcome. The rules are in
[CONTRIBUTING.md](CONTRIBUTING.md), how we treat one another in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md),
and the passivity contract and how to report a concern in [SECURITY.md](SECURITY.md). Proposals that
would transmit anything are outside the scope of the project.

**Privacy:** never post real SSIDs, MAC addresses or capture files, whether in issues or in pull
requests. To reproduce a problem, use the demo mode, `tests/fixtures/` or
`python3 tools/gen-testdata.py`.

## Usage

Use Starchorus only on your own devices and on networks for which you have explicit permission.
Radio monitoring is regulated differently from country to country. Starchorus is provided without
warranty.

## Licence

Copyright (C) 2026 The Starchorus Authors

Original code is under the [GNU General Public License, version 3 or later](LICENSE)
(`GPL-3.0-or-later`).

The embedded label font 'Starchorus Sans' is **Overpass**, a free typeface in the style of
Highway Gothic. © 2016 Red Hat, Inc.; © 2021 The Overpass Project Authors. It is under the SIL Open
Font License 1.1, not the GPL. The licence text is in [OFL.txt](OFL.txt) and, word for word, next to the
font in `starchorus.html`.

Alternative or commercial licensing is available on request. What that means for contributions is
set out in [CONTRIBUTING.md](CONTRIBUTING.md#licensing-of-your-contributions).

## Trademarks

Hak5, WiFi Pineapple and WiFi Pineapple Pager are trademarks of Hak5 LLC. They are used here only to
say which device Starchorus runs on. Starchorus is an independent project; it is not affiliated
with, sponsored or endorsed by Hak5 LLC, and Hak5 does not support it. Other product names belong to
their respective owners.
