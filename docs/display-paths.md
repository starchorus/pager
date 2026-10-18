# Access and display routes

This document describes every route for viewing Starchorus: the animated page in the browser
(routes A to D) and the Overview on the device's display. The device facts behind them (the
missing web server, tools, firewall, display commands) are in [device-notes.md](device-notes.md).

> **Strict passivity holds on every route.** None of these routes alters the purely passive
> character of the tool: the collector reads the recon database read-only or receives in monitor
> mode, the servers deliver only the page and `starchorus.json`, and the Overview reads only the
> local `starchorus.json`. Nothing is ever transmitted: no deauth, no rogue AP, no injection, no
> association, no active scan. A web server on a high port is ordinary HTTP traffic on the
> management network and has nothing to do with Wi-Fi reception.

## Overview

| Route | Target | Status | Effort |
|---|---|---|---|
| **A** | browser against a server **on the device** (`uhttpd`, port 8199) | works where `uhttpd` is present; an updated Pager has none | low if `uhttpd` is present: the payload starts it itself; otherwise moderate: add it once as an `.ipk` |
| **B** | browser on a **connected computer**, which does the serving | works | low: nothing to install on the device |
| **C** | netcat server `starchorus-serve.sh` (GNU netcat) on the device | works: the normal page server on an updated Pager (no `uhttpd`, no `python3`); one request at a time, which suits one browser | low: the tool is present, and the payload starts it when it finds no other server |
| **D** | **any client on the management network** (phone, laptop) against the server from A or C | works like the server it opens | low: uses the server from A or C |
| Overview | figures as text on the **device display** (`starchorus-display.sh`) | works | none: part of the payload |

For all browser routes:

- The page and `starchorus.json` must come from the **same origin**, not via `file://`; otherwise
  the live poll does not take effect. The page requests exactly one file: `GET starchorus.json`,
  one request at a time.
- The page starts with a simulation marked 'Sample', finds the neighbouring `starchorus.json`,
  switches the chip to 'Live' and from then on polls in step with the collector: shortly before the
  next capture is due, then every 2 s until it arrives (about three requests per 30 s capture of the
  payload); every 5 s while it shows no live capture. The chip turns 'Stale' when no new capture has
  come for twice the announced interval plus 15 s (75 s with the payload's 30 s), and 'Offline' when the
  Pager has answered nothing for as long, for example once the phone has left its Wi-Fi.
- Never put a server on port 1471 (the device's web interface) or 80; Starchorus takes a free high
  port (default 8199, `STARCHORUS_PORT`).
- Every Starchorus server listens on the management address only (`STARCHORUS_BIND=auto`: the
  address of `br-lan`), not on a network the device has joined; `all` listens on every interface
  ([SECURITY.md](../SECURITY.md#network-exposure-of-the-page)).

---

## A) Server on the device: `uhttpd` on port 8199

**What it is.** The device serves the page (`index.html`) and `starchorus.json` itself through a
real web server capable of concurrent connections. You open `http://<device>:8199/` from any
computer on the management network (USB-C or management Wi-Fi). A Pager that has had the system
update of 13 October 2026 has no `uhttpd` and no `python3`: route C is the normal page server there,
and this route needs `uhttpd` added again.

**Why `uhttpd`.** A browser loads the page and the data almost at once and then polls one request
at a time. `uhttpd` is OpenWrt's standard web server, holds parallel connections and keep-alive,
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

# start Starchorus (the payload that tools/install.sh or the Quick Start put on the device)
/root/payloads/user/reconnaissance/starchorus/payload.sh start   # collector + server on port 8199
```

Then open `http://<device>:8199/` in the browser.

**Which server starts.** The payload takes the first server present, and so does the root `payload.sh`, the repository's
lean launcher, which the installer does not copy to the device (copy it by hand to use it):

| Script | Order |
|---|---|
| root `payload.sh` | `uhttpd`, BusyBox `httpd`, `python3` (each started in foreground mode, so that `httpd.pid` holds the PID of exactly this server); with none of them it says so and serves nothing |
| payload `library/user/reconnaissance/starchorus/payload.sh` | `uhttpd` (detaches itself), `python3`, finally the netcat server from C |

If the payload finds no server at all (not even `nc`), it carries on collecting to
`starchorus.json`; the view then comes through B. `payload.sh stop` ends the collector and the
server; it ends only the Starchorus server on its own port, never the device's `uhttpd` on 80 or
1471.

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

## C) Netcat server `starchorus-serve.sh` (GNU netcat)

**What it is.** The page server of a Pager that has no real web server, which is how a Pager stands
after its system update of 13 October 2026 (no `uhttpd`, no `python3`). It is built on the GNU
netcat 0.7.1 already present, using the FIFO pattern: the request flows from `nc` through a FIFO to
the handler, the response from the handler back to `nc`, and `-c` closes the connection at the end. It
answers only `GET` and `HEAD` on `/`, `/index.html` and `/starchorus.json` from `STARCHORUS_DIR`,
and everything else with 404. It sends the page with `Cache-Control: max-age=60` and
`starchorus.json` with `no-store`, and no `Access-Control-Allow-Origin` header. Each answer is sent
from a copy of the file in `/tmp` (RAM), so its `Content-Length` is the length of the bytes that
follow even when the collector replaces `starchorus.json` meanwhile. A client that connects and
sends nothing is dropped after 15 s (the listener is replaced then), one that stops in the request
headers is answered after 10 s, and the whole of one request is ended after 60 s. Where `read -t`
is missing (`dash`) a header line has no limit of its own and the 60 s is the only one.

**Limit.** GNU netcat 0.7.1 holds **no parallel connections**: the server handles one request after
another. That suits one browser, which asks for the page once and then polls `starchorus.json` one
request at a time; a second device is served after the first. For several viewers at once, use A or
B. What has been checked on the Pager itself is in [device-notes.md](device-notes.md) §7.

**How to use it.** The payload starts it when it finds neither `uhttpd` nor `python3`. By hand, for
instance to check whether the device is delivering the data:

```sh
./starchorus-serve.sh            # foreground, STARCHORUS_BIND:STARCHORUS_PORT (default br-lan:8199)
curl http://<device>:8199/starchorus.json
./starchorus-serve.sh stop       # ends only its own processes for this directory and this port
```

---

## D) Any client on the management network

**What it is.** Any client on the device's management network, phone or laptop, over USB-C or the
management Wi-Fi, opens the page delivered by the server from A or C at `http://<device>:8199/`. On a
phone the page has a layout of its own: the sky, a status bar and a bottom sheet with every control
(`docs/architecture.md` §9.8).

**Why it works.** The device's firewall (fw4/nftables) has input policy `accept` and accepts traffic
over `br-lan` in full; a high port is reachable without a rule of its own.

**Prerequisites.** The server from A or C is running; the client is on the management network. Nothing
needs installing on the client.

---

## Overview on the device display

**What it is.** `starchorus-display.sh`, the Overview, shows figures from `starchorus.json` as text
on the device's 480×222 display, in place of the animated graphics. The payload opens it after
'Start' (unless `STARCHORUS_DASHBOARD=0`) and from the menu row 'Overview', as a child process at
nice 19: key B in the Overview goes up one level, and from the list of screens back to the payload's
menu. It hands over the time of the last Start, so a capture from before it is never shown
('Waiting for the first scan.'), and its own pid, so that an Overview whose payload has gone ends at its next key press: it
waits for a key with no time limit and looks at the pid once per pass, after an answer (which is also before the next wait is
armed) and again when the list returns, without starting a process. The payload therefore gives it no stdout and no
stderr: the payload runner reads the payload's output until it ends, and an Overview left waiting behind a killed payload
would otherwise keep it open. After 'Start' the payload keeps the 'Starting' spinner up until the first capture since that
Start exists (up to 20 seconds; `STARCHORUS_FIRST_CAP` sets the wait in tenths of a second, default 200, and the wait ends
early when the collector has gone), so the Overview normally opens on numbers. If the first scan is late
it opens on 'Waiting for the first scan.', and key A draws it again.

**Why text.** The display path has no webview and no HTML/JS engine, and a payload cannot register a
screen of its own. It can, however, write lines to the log on the display and show selection lists.
The Overview uses exactly these payload runtime commands (`LOG`, `LIST_PICKER`, `ERROR_DIALOG`,
`WAIT_FOR_INPUT`, which waits for a key with no time limit, described in [device-notes.md](device-notes.md) §7) and
changes nothing in the device's interface; a firmware update does not touch it.

**Screens.**

| Screen | `--once` name | Content |
|---|---|---|
| Summary | `summary` | GEN and age of the capture, number of APs split by band (with `BT n`, the addresses of the last Bluetooth scan, on the same line when the capture has the array; `256+` at the cap), clients (free, how many of them randomised and in how many clouds, associated), freshness, channel crowding (level 1–5, busiest channel), number of searching stations, number of open/WEP networks (red) |
| Strongest networks | `top` | the eight strongest networks by RSSI, with band and security; open and WEP networks in red |
| Bands and security | `bands` | APs per band, each with the band's share of all channel activity as an 8-cell ASCII bar (`act ######-- 78%`) when the capture has activity, and the note 'act = share of frames heard (relative)' under the band lines only then; the count per security class; Open and WEP in red |
| Devices and merges | `devices` | logical devices (at least two BSSIDs sharing the first five bytes, locally administered addresses excepted), merged SSIDs (one name under at least two devices), up to four examples |
| Probe requests | `probes` | how many stations have a named probe, the eight most named SSIDs as 'named: <SSID>' (received only; 'No named probe heard.' when there is none) |
| Stations | `clients` | clients free (randomised, clouds)/associated, the eight strongest stations with their assignment; the addresses of a cloud as one line |
| Bluetooth | `bluetooth` | the addresses of the last passive Bluetooth LE scan ('23 addresses (21 rotating, 2 fixed)'), the strongest by company over the last two minutes (at most seven lines: signal, company name, 'company id N' where only the id is known, 'company not advertised' for rotating addresses without manufacturer data, and the count; addresses, never devices; no names), the time of the last scan and, on a window that was void, ' - no valid scan now'. A capture without the array reads 'No Bluetooth in this scan.' and 'Turn it on in Settings > Bluetooth.'. Every line is at most 40 columns, ASCII separators only |
| Air quality | `air` | crowding level; per band the three busiest channels with co-channel and adjacent-channel counts, the least occupied common channel and the estimated beacon share |

The Overview moves only when a key is pressed. Every screen is drawn in the order ARM, DRAW, TAKE. ARM starts one
`WAIT_FOR_INPUT` in the background, with no time limit (the payload was looked at when the last key was taken). DRAW prints `Reading...`
when `jq` runs, the block and the frame, with that wait open. The wait takes one key, and a draw that went on after it would run with
none open for the rest of its time, so the first key ends the draw: nothing more is printed, a `jq` that is running is ended (with the
processes `timeout` started for it) and nothing it was reading is kept. TAKE collects the wait's answer (it is there at once if a key
came during the draw), checks again that the payload is there, and acts on the key, and the next pass arms again straight away. A wait
is therefore open while a screen or `Reading...` is drawn, which matters because a press made while none is open is lost, and B is then
taken by the Pager's own UI and leaves the payload's view (M1 and M2 in [device-notes.md](device-notes.md) §7, measured on the device on
16 October 2026). It does not make every moment safe, and a press that falls into one of these is lost and, for B, may leave the
payload's view: (1) the start, from the first line of the script's code to the first wait: the traps are set and the temporary
directory is made; (2) the time from a key being answered to the next wait being registered with the UI: while a `jq` runs the shell
sees the key at the next look of its watcher (every 0.2 s), then it ends the `jq`, takes the key, asks whether the payload is still
there (no process), and starts the waiter, which is two processes before `WAIT_FOR_INPUT` itself runs, and the UI takes the request in
its own time, so the first line of a draw can be written before its wait exists; (3) the list, which is a wait of its own: no wait is
armed while it shows, and when it returns the Overview checks the payload, arms, then draws. None of them was timed on the device. (1)
and (2) are a fraction of a second at most, not the seconds of a draw, but this document does not claim that B can never leave the
payload's view. Nothing redraws by itself, and nothing but the wait runs once a screen is drawn. No UI command is ever put under
`timeout`: killing the client of a command might leave its request pending in the UI service, which could then take the next press (M7
saw no such effect, on weak evidence, and the Overview has no need to find out). It has no Start, Stop or Exit of its own. The states,
and what each key does in them:

| State | Shows | A | B | Left / Right | Up / Down |
|---|---|---|---|---|---|
| Arm, then Draw (any of the eight) | the wait is started, then `Reading...` while `jq` runs, the block, the frame | the first key ends the draw, then the same screen is drawn again (a cut draw keeps nothing: `jq` runs again) | the draw ends, then the list opens | the draw ends, then the previous / next screen is drawn | the draw ends and, because it was cut, the same screen is drawn again |
| Screen (any of the eight), wait open | the finished draw | Arm, Draw: the same screen again | opens the list, the cursor on this screen | Arm, Draw: the previous / next screen | ignored: Arm again at once, nothing drawn |
| Waiting, wait open | 'Waiting for the first scan.' and the frame | Arm, Draw: again, and reads the capture if one has come | opens the list | as on a screen | ignored |
| List, no wait | `LIST_PICKER` titled `Overview` with the rows `Summary`, `Strongest Networks`, `Bands & Security`, `Devices & Merges`, `Probe Requests`, `Stations`, `Bluetooth`, `Air Quality` | Arm, Draw: the chosen screen | ends the Overview with exit 0: the payload's menu, the cursor on 'Overview' | the picker's own | the picker's own |

Left and Right step through the screens in the order of the list and round its ends: Right on Air Quality shows the summary, and
Left on the summary shows Air Quality. BACK and Escape count as B, and a lower-case a or b as the capital (the words other payloads of the library test for); any other
answer, an empty one included, is a strike; three strikes in a row, each answered at
once (its wait ended within a second of the arm, or there is no clock to tell), end the Overview with exit 0, so a broken key path
never becomes a busy loop. The same answer after a real wait of a second or more is no strike: the UI took its time, a new wait is
armed and the count starts over. The time is read from `/proc/uptime` without starting a process.
A press made during a draw reaches the wait that was armed before it and is acted on at once: it was made on purpose at what the
screen showed, so it is not dropped for having come early, and the draw it came in is over. Where no wait is open a press is lost (M1),
which is why the wait is armed first. The wait writes into a file in a private temporary directory (mode 700), with the output of the
screen's `jq` in a second file there; the directory is removed when the Overview ends, and an exit trap ends a wait that is still
pending, so none is left behind. A file that cannot be written (the file system is full) is reported as 'Overview could not read a key.'
and does not count as an empty answer.

Each draw prints `Reading...` (only when `jq` has to run), the block of the screen and, last, the frame: `Last scan 12:04:31 (42 s ago)`
(the time of the capture's `generated` in UTC, as the page shows it; no line without a capture), then `A: Refresh   B: Back`, and on the
summary the page's address when the payload serves one (`Web page: 172.16.52.1:8199`). GEN advances only when the collector has
written a new capture. When none has come for more than three of the collector's intervals, a red line says `No new scan for 4 min.`
(with the time measured) in place of the `Last scan` line. Since nothing refreshes by itself, that line tells how old the numbers are;
press A for the present state.

Each screen reads the capture with a single `jq` process, run under `timeout 20` where the device has `timeout`
(`STARCHORUS_JQ_CAP` moves the limit, for tests only). A scan that takes longer ends as the two lines `This scan took over 20 s to
read.` and `Try Settings > Show Last: 1 h.`. What a read gave (the numbers, 'no data' or 'too slow') is kept for as long as the capture
file is unchanged, so A on an unchanged capture runs no `jq` and only the age in the frame moves.

Random clouds (the page's §8.8a) are counted by the same rule as on the page: randomised free addresses with a capture time
(this device's own transmitters left out), heard at one signal (±3 dB) in bursts whose period stands clear of what unrelated
bursts would give by chance, judged against what the band itself shows beside that period (at least six bursts, 15 to 300 s apart, in
practice eleven; in a band too dense for that, a chain of bursts that keeps its phase; devices of different periods at one signal are
separate rhythms, devices of one period are one cloud of mixed rhythm; the newest 1500 bursts of a band). The Overview
evaluates each capture on its own, without the page's memory, so a cloud that is fading out (its last bursts) is a cloud on the page
and no longer one here. The rule is arithmetic only (no `exp`, `pow`, regex): the slowest case measured on a laptop, 11 500 addresses
over a day (one device among a crowd of 6000), is 1.7 s of jq; an hour of 2000 or 5000 unrelated addresses is 0.2 or 0.45 s. On `tests/fixtures/clouds.json` the summary reads `Clients  160 free (139 random, 1 cloud) · 2 associated`
and the stations screen shows the cloud as one line, `-29 dBm  cloud of 121 random addresses`, and none of its addresses.
Without a randomised station the lines are as before.

**Output.** LOG lines only; the log is append-only. The first line, `Overview`, comes before any
`jq` call, and a draw that runs `jq` begins with `Reading...`. The log only grows, so a screen drawn again sits below the one before it.
Red stands only for an alarm (an open or WEP network, the 'jq incomplete' line, or the
'No new scan' line), blue for headings. If the capture comes from the collector's
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

The Overview needs `jq` (without it: 'Overview needs jq.', and the payload's menu hides the row);
on the device it is built without regex, so no filter uses the regex family
([device-notes.md](device-notes.md) §2a).

---

## Recommendation

- **Browser view straight from the device: route C on an updated Pager.** The payload starts the
  netcat server itself and the device serves the animated page, one request at a time, which suits
  one browser. **A** (`uhttpd` on port 8199) serves several viewers at once where `uhttpd` is
  present or added once. **D** is the same from your own phone or laptop; **B** is the
  installation-free alternative when a computer is connected anyway.
- **Figures without a browser: the Overview** on the device display.

In every case each of these routes preserves the tool's strict passivity: observe, never transmit.
