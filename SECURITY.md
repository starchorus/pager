# Security and passivity

Starchorus is a strictly passive, receive-only Wi-Fi observation tool; it never transmits. It only
listens to radio. The tool contains no function that transmits or interferes; this property is the
core of the design, not a matter of configuration. This document records what Starchorus reads,
what it stores and what it outputs, names the single active exception (and why it is off by
default), and describes responsible use that respects privacy.

## 1. Passivity contract

Starchorus evaluates only frames that are on the air anyway (beacons, probe requests, probe
responses) and reads the device's passively filled recon database. It never associates with a
network, sends no frames and changes no one else's radio state.

### Permitted read paths

| Path | Implementation |
|---|---|
| **Reading the recon database** | The preferred path on the device. The SQLite database that the device's recon service fills passively is **copied** before reading and opened only with `sqlite3 -readonly`, so that capture is never locked. The working copy lives in RAM (`STARCHORUS_TMPDIR`, default `/tmp`, a tmpfs on the device) and is deleted after each cycle. With too little room there, or if the copy fails, it is made in `STARCHORUS_CAPDIR` instead (flash; it stays there until a later copy fits in RAM), and as a last resort the live file is read in place, still read-only. It holds other people's MAC addresses and SSIDs, and on the default path it is not written to flash. The collector also keeps the document of its last full pass in its memory (not in a file), which a skipped cycle republishes with a new `generated`. |
| **Receiving in monitor mode** | Listening with `tcpdump` (or `airodump-ng`, if installed) on a monitor interface: receive only, no injection. |
| **Tuning the receiver to a channel** | Only in order to listen; nothing is sent. |

The collector creates its own monitor interface only if none exists (`STARCHORUS_CREATE_MON=1`,
the default), and then only on an adapter that is not the management radio; on exit it removes
exactly that interface again. An existing monitor interface is shared but never removed. The
collector never touches the management radio.

### Additional read and output paths

Every further path is named here. Anything that depends on the device's behaviour is a switch that
defaults to **off**.

| Path | What exactly | Default | Transmits? |
|---|---|---|---|
| Vendor name from an OUI file | reads a **local** file of MAC prefixes (`STARCHORUS_OUI_FILE`; `auto` tries known paths) and adds `vendor`; `randomized` follows from the MAC itself, without a lookup. A cache and an index of the OUI file live in `STARCHORUS_CAPDIR`. | on (`STARCHORUS_VENDOR=1`) | no |
| `iw dev <IF> survey dump` | reads the channel statistics kept by the driver (frequency, noise, active and busy time) via a netlink dump; **no scan** | off (`STARCHORUS_SURVEY=1`) | no |
| `/sys/class/net/*/address` | reads the MAC addresses of the device's own interfaces into `center.own_bssids`; `own_ssids` comes **only** from the file in `STARCHORUS_OWN_SSID_FILE`, never from the AP service's SSID pool | off (`STARCHORUS_OWN=1`) | no |
| Recon database, column `time` | a further read-only query of the same copy: last time heard per frequency into `channels[]` | off (`STARCHORUS_HOPINFO=1`) | no |
| Recon database, probe responses | number of distinct SSIDs with which a BSSID has answered probes (`responded_ssids`, only from 2 upwards); a number, not a list of SSIDs | always on the database path | no |
| Homing AP | reads `STARCHORUS_HOMING_BSSID` or the first line of `$STARCHORUS_OUTDIR/homing.target` and adds a `homing` object built from that AP's row in the same document (section 4) | no AP | no |
| `apcli_ro` | the only place where a command of the AP service's command line may appear: **exactly** three fixed command lines, literal in the code, no `eval`, no command name taken from a variable and no argument taken from outside (the lines only carry the optional prefix `timeout 10`). They are two read-only commands: `RECON APS format=json` and `RECON DEVICES format=json` (the recon lists as JSON), the second one also in the CLI's own bounded form `sort=time sortdir=desc limit=400` (newest first; this is the form `STARCHORUS_SOURCE=pineap` runs by default, `STARCHORUS_PINEAP_CALLS=full` runs the two plain lists). The plain lists were checked on the device (docs/device-notes.md, V-3): the transmit counters of every wireless interface (`wlan0`, `wlan0mon`, `wlan1mon`) were the same before and after each call. The bounded form (`limit=400`) was checked the same way in a 130 s run of the source on 14 October 2026 (the forms `limit=50` and `pagesize=100 page=1` earlier): the counters were unchanged. The calls run under `timeout 10` where a `timeout` command exists. Listening to a single BSSID, never verified on the device and called by nothing, is no longer in the list. The self-test calls the function with a stub and shows that deauth, stopping and restarting recon, `RECON CLIENTS` (which does not exist), SSID pool commands, uploads, GPS, listening to a BSSID, extra arguments and injection attempts are refused **without** a call. | off (`STARCHORUS_APCLI_RO=1`); `STARCHORUS_SOURCE=pineap` switches `apcli_ro` on for itself | no (read-only commands) |
| Source `pineap` (experimental) | `STARCHORUS_SOURCE=pineap` builds `starchorus.json` from these lists instead of from the database (opt-in only; `auto` never chooses it, and recon.db stays the default). When the AP service gives no usable answer, that cycle is built from the database. Its only extra read is the database path already described: the security of each access point, which the lists do not carry, from one query at most once a minute while an access point is new to the cache (every 10 minutes for those the database does not know). The labels are kept in a small cache in RAM, `$STARCHORUS_TMPDIR/starchorus-sec.txt`: the BSSIDs of nearby access points with their security. The collector does not delete it when it exits; it goes with a reboot, or delete it by hand. The lists of BSSIDs that a lookup is made from (`starchorus-pineap-<pid>.*`) are deleted at the end of each cycle. If `STARCHORUS_TMPDIR` is not a writable directory no lookup is made and every access point reads `Unknown`. Nothing else is run. | off (`STARCHORUS_SOURCE=pineap`) | no |
| `center.max_age`, `center.interval`, `akm`/`cipher`/`auth` | pure **output** fields in `starchorus.json`, computed from existing values | always | no |

One collector runs per Pager, so that two loops never share the monitor interface or radio: starting
or stopping any instance stops every other collector loop on the device (`--once` and `--status`
runs are left alone), and each loop so stopped is logged on stderr with its pid and working
directory. `starchorus.json` is written atomically (temporary file, then `mv`) and lives in
`STARCHORUS_OUTDIR`; pidfiles live in `STARCHORUS_PIDDIR`. The on-device payload writes its
settings to `settings.conf` in the same directory. Run from a self-contained payload directory
(`tools/hak5-package.sh`), it also copies its bundled collector, page, Overview and netcat server
there once, on the first run, and never over a collector that is already installed. These are
local file writes; nothing is sent.

### Never done (none of these functions exists in the code)

| Prohibited action | Status |
|---|---|
| Deauthentication / disassociation | not present |
| Spoofed or impersonated access point | not present |
| Packet injection | not present |
| Association with other people's networks | not present |
| Active functions of the AP service, broadcasting the SSID pool | not present |
| Jamming / interference transmission | not present |

There is no switch and no environment variable that enables any of these functions; they are not
implemented. Nor is the receiver ever held on a channel or BSSID: the homing value is one value per
cycle, taken from the document that was captured anyway. Starchorus creates no persistent device
configuration (no rules, no services) and controls neither LED nor buzzer.

### Static check

`sh tools/passivity-check.sh` checks these rules against the source:

- The page has no way to send: `fetch(` appears exactly once, with the target `starchorus.json`; no
  `method:`, `POST`, `XMLHttpRequest`, `WebSocket`, `EventSource`, `sendBeacon`, no other network
  APIs and no navigation used as a command path; external URLs only in the font's licence header.
- The AP service's command words (command-line call, the service's environment variables, deauth,
  SSID pool, upload, GPS) appear only in `apcli_ro`, `apcli_stub` and `apcli_selftest`; the `pineap`
  source reaches the command line only through `apcli_ro`.
- `iw scan` appears only behind `STARCHORUS_ALLOW_ACTIVE=1`; no transmitting tool is called.
- Every `sqlite3` call outside the self-test carries `-readonly`.
- `starchorus-serve.sh` answers only `GET` and `HEAD` on `/`, `/index.html` and `/starchorus.json`.

`tools/passivity-mutate.sh` shows that each of these checks can turn red, and the regression run
also watches the requests of the running page in the browser (see
[tools/README.md](tools/README.md)).

## 2. Special case `iw scan` (active, off by default)

There is exactly **one** exception to 'receive only', and it is switched off.

`iw dev <iface> scan` sends **probe request frames** and is therefore **active**, not passive. That
breaks the passivity contract. This path therefore runs only after an explicit opt-in:

```sh
STARCHORUS_ALLOW_ACTIVE=1   # default: 0 (off). Sends probe requests. Set only deliberately.
```

| Property | Value |
|---|---|
| Environment variable | `STARCHORUS_ALLOW_ACTIVE` |
| Default | `0` (off) |
| Effect when `1` | `iw scan` becomes the last resort of the `auto` source selection; it can be forced with `STARCHORUS_SOURCE=iwscan`, but even then only with `STARCHORUS_ALLOW_ACTIVE=1` |
| Marking in the JSON | `"source": "iw-scan-ACTIVE"` |
| Display | the page and the Overview switch to the ACTIVE line; the 'receive only' statement then appears nowhere |

> **Warning.** While `STARCHORUS_ALLOW_ACTIVE=1` is set, Starchorus is **no longer passive**: the
> device emits probe requests and so takes a detectable part in radio traffic. Leave this variable
> off in normal operation. Set it only if you understand the active behaviour, want it deliberately,
> and it is permitted where you are. The `iw scan` path is the only one that produces JSON marked
> `-ACTIVE`; an active run is recognisable by that at once.

## 3. Responsible use

- **Use it only in your own environments or in ones you are expressly authorised to use.** Passive
  listening inevitably also captures other people's devices in range; that is no reason to do it
  everywhere.
- **Mind the law.** Whether, and to what extent, monitoring radio traffic is permitted, even
  purely passively, is **regulated differently from country to country**; it may require a licence,
  or be restricted or prohibited. Establish the rules that apply to you before you operate the tool.
  This document is not legal advice.
- **Think twice about active mode.** Where passive listening is permitted, sending probe requests
  (section 2) may be judged differently. If in doubt, leave it off.

## 4. Privacy

The recon database and the `starchorus.json` it produces contain **data that can identify third
parties**, in particular **other people's MAC addresses and SSIDs** of access points and clients in
range. Handle this data with care:

- **Do not publish it.** Do not pass on or put online raw `starchorus.json` files, database extracts,
  screenshots with legible MACs or SSIDs, or lists derived from them.
- **Collect as little as you need.** For a live view, use the age window rather than the whole
  record: `STARCHORUS_MAX_AGE=120` shows, on the database path, only what was heard in the last two
  minutes. The recon database is cumulative; Starchorus deletes nothing in it.
- **Make it reachable only as far as necessary.** If the page is served, it is on port
  `STARCHORUS_PORT` (default 8199) of the management address only (§5); ports 80 and 1471 are left
  alone. Do not make it more widely reachable than necessary, and clear out `STARCHORUS_OUTDIR` when
  you no longer need the data (with the `pineap` source also `$STARCHORUS_TMPDIR/starchorus-sec.txt`).
- **No profiling of people.** The tool visualises the radio environment; it is not meant for
  tracking individuals.

### What the page stores in the browser

The page writes only these six `localStorage` keys. **'Clear local data'** in the Observations
panel, or `STARCHORUS.clearLocalData()`, deletes them all in one call. There are no other
`starchorus.*` keys in `localStorage` and no upload.

| Key | Content | Limit |
|---|---|---|
| `starchorus.ui.v1` | view switches (theme, 2D/3D, the Random switch, layers, Hide panels, Observations and baseline on or off): booleans and names only | a few bytes |
| `starchorus.identity.v1` | the **manual** classification Friend/Neutral/Suspect per **observed key** (AP or station; MAC → class) | **≤ 5000 entries** (`IDENT_MAX`); when the list is full, a new key is refused, and an existing classification is never silently displaced |
| `starchorus.baseline.v1` | the baseline: per AP `[SSID, channel, band, security class, RSSI]` under its BSSID, per station only `[RSSI]` under its MAC (field `st`, **no link** to an AP), plus the capture's timestamp | **≤ 500 APs, ≤ 2000 stations** (strongest first); never the device's own transmitters, never probable phone hotspots |
| `starchorus.watch.v1` | the watchlist: SSID texts only (≤ 32 characters) | **≤ 20 entries**; it matches only `aps[].ssid`, never probes |
| `starchorus.library.v1` | the library **rules**: OUI patterns with `?` and `*` (`aa:bb:cc:??:??:??`) and their class `friend`/`neutral`/`suspect` | **≤ 20 rules**; vendor prefixes only |
| `starchorus.notes.v1` | alias (≤ 24 characters), note (≤ 120), up to 4 tags (≤ 12) per **observed key** (AP or station) | **≤ 200 entries**; control characters are removed |

In `sessionStorage`, each theme has a flag `starchorus.introShown.<theme>` (`"1"`) so that the
introduction runs only once per session; it disappears with the tab.

### What is held only in memory

The **recording** holds the last ≤ 120 captures (≤ 8 MB, estimated) **in full** in memory, including
the stations with their addresses, because the replay is meant to show exactly what was heard. It is
**never** stored (no `localStorage`, no `sessionStorage`), is **not** read by the export, and is
returned by `STARCHORUS.recording()` only as counts. It disappears when the source changes, with
'Clear local data' (also on its own: `STARCHORUS.clearRecording()`) and when the page is closed. A
poll that arrives during a replay is recorded but shown only after 'Back to live'.

Likewise held only in memory, and discarded when the source changes:

- the long-term signal-strength history (one value per capture and AP, ≤ 720 values), the channels'
  peak values and the signal threshold;
- the change log (≤ 12 entries per AP, ≤ 500 BSSIDs);
- observations and ghosts.

Random clouds are computed in the browser, and on the Pager's own screen by the Overview, from the
capture already present, so nothing new leaves the device.

The observations are derived notes in neutral language, without judgement. A note appears only once
it has held for two captures in a row, and never for the device's own transmitters or for phone
hotspots. The number of stations that have searched for a confirmed SSID is shown only in bands
('<5' or '5 or more') and only after ten minutes of capture time, without timestamps and without
identifiers.

Of stations, the page stores only MAC and RSSI in the baseline: no link to an AP, no probe list, no
RSSI history, no `last_seen`.

### Export

Export, inventory and homing write nothing to storage. The **export** (JSON, CSV, SITREP, PNG
snapshot, print) is built in the browser from what the page shows, and ends up only in the text box,
the clipboard, the print dialogue or as a `data:` image on the page. The page has no way to send
data.

- It contains access points and stations (MAC, vendor, band, signal, probes and the AP link, all
  received) as well as aliases and tags.
- Addresses the page groups into a cloud carry the cloud's id in JSON and in a trailing CSV column; the cloud entry holds counts,
  signal range, times and probed network names, all received, and is marked as an estimate.
- It contains none of the device's own transmitters, no probable phone hotspots (not even as a
  station's link; only their number) and no note texts.
- Every format carries the footer 'Starchorus · passive observation · not a government system · no
  official marking'.

### Homing

Homing shows the signal strength of **one** chosen AP. The collector builds the `homing` object
(`bssid`, `dbm`, `peak`, `t`) only for an AP, from that AP's row in the same document, and refuses a
station, an unknown BSSID and one of the device's own. The page accepts the object only if the key
was observed in this capture (AP or station) and is not one of the device's own transmitters. The
tone is off and needs a user gesture; it changes only the pitch and names nothing.

### On-device Overview

`starchorus-display.sh` reads only the local `starchorus.json` and writes nothing but **LOG lines**
to the device's display (append only; a payload cannot register screens of its own). It sets
neither LED nor buzzer, calls no network program and stores nothing that outlasts it. An optional line
template (`STARCHORUS_DISPLAY_TEMPLATE`, otherwise the first line of `$STARCHORUS_DIR/display.tpl`) is only
read, and only numbers are inserted into it.

While it runs, the key it waits for is handed over through a file in a private temporary directory
(`mktemp -d`, mode 700). The file holds the name of the key pressed and a clock reading, nothing from the
capture. A second file in the same directory holds the output of the screen's `jq` program, the lines that go to the display next,
until the next program replaces it. A `trap` deletes the directory when the Overview ends, even on INT and TERM. The Overview signals only
processes it started itself (the waiter for the key, its `jq` and the watcher of that `jq`).

The one other file is that of the self-test `--selftest`, run by hand: it creates a small synthetic
fixture with `mktemp` (dummy BSSIDs, no real data), which a `trap` deletes again even on INT and TERM, and
writes its `PASS`/`FAIL` lines to stdout.

## 5. Network

- The page makes exactly one kind of request: `GET starchorus.json` from its own origin, one at a time: shortly before
  each capture is due, then every 2 s until it arrives, and every 5 s while it shows no live capture.
- The page must come from the same origin as `starchorus.json`. How it is served (web server on the
  device, connected computer, netcat server) is described in the
  [README](README.md#serving-the-page); the details are in
  [docs/display-paths.md](docs/display-paths.md).
- The netcat server `starchorus-serve.sh` is the only part of Starchorus that listens on the
  device itself; the other page servers are the device's own programs (`uhttpd`, BusyBox `httpd`,
  `python3`), started by the payload. It answers only `GET` and `HEAD` on `/`, `/index.html` and `/starchorus.json`, everything
  else with 404, one connection at a time. `starchorus-serve.sh stop` stops only the processes the
  script started itself. It sends no `Access-Control-Allow-Origin` header, so a web page of another
  origin that is open in the same browser cannot read `starchorus.json` from it. A client that stays
  silent is dropped after 15 s; while it answers, it holds a copy of the file in `/tmp` (RAM, mode
  600), removed when the answer ends.

### Network exposure of the page

Whoever can reach the page server can read `starchorus.json`, and with it every captured MAC address
and SSID. The Pager's stock firewall (fw4) accepts input on its management zone and also on the
zone of the networks it joins as a client (see
[docs/device-notes.md](docs/device-notes.md#firewall-fw4nftables)); a server listening on every
interface would therefore be open to anyone on such a network.

So every page server listens on one address, `STARCHORUS_BIND` (on-device payload: the `bind`
key). The default, `auto`, is the address of `br-lan`, reachable over USB-C and the management Wi-Fi
only; without it, `172.16.52.1` if configured, otherwise `127.0.0.1`. An explicit IPv4 address
binds that one. `all` listens on every interface and exposes the data to every network the device
is on; it is never chosen automatically, and `0.0.0.0` is not accepted in its place. The netcat
server binds one address through `nc -s`; with an `nc` that lacks it, it starts only with `all`.

## 6. Reporting security concerns

Please report a vulnerability, or anything that would let Starchorus transmit, **privately**:
on the repository's **Security** tab choose **'Report a vulnerability'**
(<https://github.com/starchorus/pager/security/advisories/new>). Only the maintainer sees the
report, and the matter is settled before it is made public.

General questions about security or passivity may go in an issue with the 'Question or contact'
form; a reproducible fault that is not a vulnerability, with the 'Bug report' form. Issues are
public. In neither place include real SSIDs, MAC addresses or capture files.
