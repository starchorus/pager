# Access and display routes

This document describes every route for viewing Starchorus: the animated page in the browser
(routes A to D) and the dashboard on the device's display. The device facts behind them (the
missing web server, tools, firewall, display commands) are in [device-notes.md](device-notes.md).

> **Strict passivity holds on every route.** None of these routes alters the purely passive
> character of the tool: the collector reads the recon database read-only or receives in monitor
> mode, the servers deliver only the page and `starchorus.json`, and the dashboard reads only the
> local `starchorus.json`. Nothing is ever transmitted: no deauth, no rogue AP, no injection, no
> association, no active scan. A web server on a high port is ordinary HTTP traffic on the
> management network and has nothing to do with Wi-Fi reception.

## Overview

| Route | Target | Status | Effort |
|---|---|---|---|
| **A** | browser against a server **on the device** (`uhttpd`, port 8199) | works | low if `uhttpd` is present: the payload starts it itself; otherwise moderate: add it once as an `.ipk` |
| **B** | browser on a **connected computer**, which does the serving | works | low: nothing to install on the device |
| **C** | fallback server `starchorus-serve.sh` (GNU netcat) on the device | for single requests (`curl`) only, **not** fit for a browser | low: the tool is present |
| **D** | **any client on the management network** (phone, laptop) against the server from A | works like A | low: uses the server from A |
| Dashboard | figures as text on the **device display** (`starchorus-display.sh`) | works | none: part of the payload |

For all browser routes:

- The page and `starchorus.json` must come from the **same origin**, not via `file://`; otherwise
  the live poll does not take effect. The page requests exactly one file: `GET starchorus.json`,
  every 5 s.
- The page starts with a simulation marked 'Sample', finds the neighbouring `starchorus.json`,
  switches the chip to 'Live' and from then on polls every 5 seconds.
- Never put a server on port 1471 (the device's web interface) or 80; Starchorus takes a free high
  port (default 8199, `STARCHORUS_PORT`).
- Every Starchorus server listens on the management address only (`STARCHORUS_BIND=auto`: the
  address of `br-lan`), not on a network the device has joined; `all` listens on every interface
  ([SECURITY.md](../SECURITY.md#network-exposure-of-the-page)).

---

## A) Server on the device: `uhttpd` on port 8199

**What it is.** The device serves the page (`index.html`) and `starchorus.json` itself through a
real web server capable of concurrent connections. You open `http://<device>:8199/` from any
computer on the management network (USB-C or management Wi-Fi).

**Why `uhttpd`.** A browser loads the page, data and fonts almost simultaneously and then polls
every 5 s. `uhttpd` is OpenWrt's standard web server, holds parallel connections and keep-alive,
and carries this reliably.

**Installation.** `uhttpd` may already be present on the device (`command -v uhttpd`; not enabled at
boot, not running by default). In that case this step falls away: the payload starts it itself on
port 8199. If it is missing: the device has no internet access for `opkg`. The matching package
(target `mipsel_24kc`, OpenWrt 24.10.1) is therefore downloaded on a computer with internet access
and installed locally. The four dependencies (`libubox`, `libblobmsg-json`, `libjson-script`,
`libjson-c`) are already present on the device.

```sh
# on the computer with internet access: fetch the current uhttpd_*_mipsel_24kc.ipk from this directory
URL=https://downloads.openwrt.org/releases/24.10.1/packages/mipsel_24kc/base
curl -sLO "$URL/<uhttpd_…_mipsel_24kc.ipk>"
scp uhttpd_*.ipk root@<device>:/tmp/

# on the device
opkg install /tmp/uhttpd_*.ipk
/etc/init.d/uhttpd disable; /etc/init.d/uhttpd stop   # move the standard instance on port 80 out of the way

# start Starchorus
cd /root/loot/starchorus
./payload.sh            # collector + server on port 8199
```

Then open `http://<device>:8199/` in the browser.

**Which server starts.** Both start scripts take the first server present:

| Script | Order |
|---|---|
| root `payload.sh` | `uhttpd`, BusyBox `httpd`, `python3` (each started in foreground mode, so that `httpd.pid` holds the PID of exactly this server) |
| payload `library/user/reconnaissance/starchorus/payload.sh` | `uhttpd` (detaches itself), `python3`, finally the fallback server from C |

If the payload finds no server, it carries on collecting to `starchorus.json`; the view then comes
through B. `payload.sh stop` ends the collector and the server; it ends only the Starchorus server
on its own port, never the device's `uhttpd` on 80 or 1471.

**Advantages.** No second computer needed for serving; one origin for page and data; stable in the
browser.

**Disadvantages.** A one-off installation of the `.ipk` (which briefly needs a computer with
internet access); an additional package on the device.

---

## B) A connected computer serves

**What it is.** A computer connected over USB-C or the management Wi-Fi places the page as
`index.html`, together with the `starchorus.json` produced by the device, in a local directory,
serves both locally and keeps fetching `starchorus.json` from the device. You open
`http://localhost:<port>/`.

**Status.** Works, with nothing installed on the device at all: the device only collects, the
computer displays.

**How to use it.**

1. Put `starchorus.html` as `index.html`, and a `starchorus.json`, in a local directory.
2. Fetch `starchorus.json` from the device regularly, e.g. with `scp` every few seconds from
   `/root/loot/starchorus/`, or from a server running on the device with
   `curl http://<device>:8199/starchorus.json`.
3. Serve the directory with any simple HTTP server on a free port and open
   `http://localhost:<port>/`.

**Advantages.** Nothing to install on the device; a full desktop browser on a large screen.

**Disadvantages.** Needs a connected computer and a small mechanism to keep fetching the file.

---

## C) Fallback server `starchorus-serve.sh` (GNU netcat)

**What it is.** A minimal server for when no real web server is available, built on the GNU netcat
0.7.1 already present, using the FIFO pattern: the request flows from `nc` through a FIFO to the
handler, the response from the handler back to `nc`, and `-c` closes the connection at the end. It
answers only `GET` and `HEAD` on `/`, `/index.html` and `/starchorus.json` from `STARCHORUS_DIR`,
and everything else with 404.

**Limit.** GNU netcat 0.7.1 holds **no parallel connections**: the server handles one request after
another. That is enough for a single `curl` request; a browser page that loads several resources at
once and then polls loads unreliably through it.

**How to use it.** As a diagnostic tool, to check whether the device is delivering the data:

```sh
./starchorus-serve.sh            # foreground, STARCHORUS_BIND:STARCHORUS_PORT (default br-lan:8199)
curl http://<device>:8199/starchorus.json
./starchorus-serve.sh stop       # ends only its own processes for this directory and this port
```

For the browser view, use A or B instead.

---

## D) Any client on the management network

**What it is.** Any client on the device's management network, phone or laptop, over USB-C or the
management Wi-Fi, opens the page delivered by the server from A at `http://<device>:8199/`.

**Why it works.** The device's firewall (fw4/nftables) has input policy `accept` and accepts traffic
over `br-lan` in full; a high port is reachable without a rule of its own.

**Prerequisites.** The server from A is running; the client is on the management network. Nothing
needs installing on the client.

---

## Dashboard on the device display

**What it is.** `starchorus-display.sh` shows figures from `starchorus.json` as text on the
device's 480×222 display, in place of the animated graphics. The payload opens it after starting
(menu item 'Start', when 'Auto dash' is on, and menu item 'Dashboard').

**Why text.** The display path has no webview and no HTML/JS engine, and a payload cannot register a
screen of its own. It can, however, write lines to the log on the display and show selection lists.
The dashboard uses exactly these payload runtime commands (`LOG`, `LIST_PICKER`,
`START_SPINNER`/`STOP_SPINNER`, `ERROR_DIALOG`, `WAIT_FOR_BUTTON_PRESS`, described in
[device-notes.md](device-notes.md) §7) and changes nothing in the device's interface; a firmware
update does not touch it.

**Screens.**

| Screen | `--once` name | Content |
|---|---|---|
| Summary | `summary` | GEN and age of the capture, number of APs split by band, clients (free/associated), freshness, channel crowding (level 1–5, busiest channel), number of searching stations, number of open/WEP networks (red) |
| Strongest networks | `top` | the eight strongest networks by RSSI, with band and security; open and WEP networks in red |
| Bands and security | `bands` | APs per band and the count per security class; Open and WEP in red |
| Devices and merges | `devices` | logical devices (at least two BSSIDs sharing the first five bytes, locally administered addresses excepted), merged SSIDs (one name under at least two devices), up to four examples |
| Probe requests | `probes` | how many stations are asking for a network, the eight most sought SSIDs (received only) |
| Stations | `clients` | clients free/associated, the eight strongest stations with their assignment |
| Air quality | `air` | crowding level; per band the three busiest channels with co-channel and adjacent-channel counts, the least occupied common channel and the estimated beacon share |

The summary refreshes about every 4 seconds; key B opens the menu with every screen and the
'Collector' submenu (Status, Start, Stop). From any other screen, B returns to the summary. GEN
advances only when the collector has written a new capture; a stopped collector shows a GEN that
stands still.

**Output.** LOG lines only; the log is append-only. Red stands only for an alarm (an open or WEP
network, or the 'jq incomplete' line), blue for headings. If the capture comes from the collector's
active opt-in scan, the line `ACTIVE SCAN · the collector sent probe
requests` replaces the passivity statement. An optional template line
(`STARCHORUS_DISPLAY_TEMPLATE` or the first line of `$STARCHORUS_DIR/display.tpl`) substitutes
numbers only: `{aps}`, `{b24}`, `{b5}`, `{b6}`, `{open}`, `{crowding}`, `{gen}`.

**On the development machine.** Without the display commands, or with `STARCHORUS_DISPLAY_PLAIN=1`,
every output falls back to plain text on stdout:

```sh
sh starchorus-display.sh --once summary tests/fixtures/field-probes.json
sh starchorus-display.sh --selftest     # jq building blocks and a summary; exit 0 = all green
```

The dashboard needs `jq`; on the device it is built without regex, so no filter uses the regex
family ([device-notes.md](device-notes.md) §2a).

---

## Recommendation

- **Browser view straight from the device: route A** (`uhttpd` on port 8199). With `uhttpd` present,
  or added once, the device serves the animated page itself. **D** is the same route from your own
  phone or laptop; **B** is the installation-free alternative when a computer is connected anyway.
  **C** remains a `curl` diagnostic tool, not a browser route.
- **Figures without a browser: the dashboard** on the device display.

In every case each of these routes preserves the tool's strict passivity: observe, never transmit.
