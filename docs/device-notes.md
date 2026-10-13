# Device notes

The device is the Hak5 WiFi Pineapple Pager (a trademark of Hak5 LLC; Starchorus is not
affiliated with Hak5). This is the developer reference for the facts **verified on the device** on which the collector, dashboard and
payload rest. The details come from a read-only session on the device and from its unpacked
firmware image. Anything not yet verified on the device is marked as open (§2a, §5a, §5b);
`tools/device-probe.sh` answers these questions in a read-only session, as far as that is possible
without transmitting and without changing state.

> **Hard rule: strictly passive.** Starchorus only receives. It reads the device's recon database
> read-only or receives in monitor mode. It **never** transmits: no deauth/disassoc, no rogue or
> evil AP, no injection, no association, no active function of the AP service, no jamming.
> `iw scan` sends probe requests and therefore counts as **active**; the collector uses it only with
> an explicit opt-in (`STARCHORUS_ALLOW_ACTIVE=1`). Everything in this document describes reading or
> receiving paths.

---

## 1. Device and operating system

| Topic | Value |
|---|---|
| Operating system | OpenWrt **24.10.1** |
| Shell / userland | **BusyBox 1.36.1**: no `grep -P`, no gawk (BusyBox `awk` only) |
| Architecture | **MIPS `mipsel_24kc`** (musl, soft-float) |
| Access | SSH as `root` to the device's management address (here `<device>`). `tools/install.sh` knows it as the default host; `--host` or `STARCHORUS_HOST` choose another. |
| Device web interface | Port **1471**; belongs to the AP service and serves no other files |
| Persistent storage | internal eMMC; `/root/…` == `/mmc/root/…`. **No SD card, no `/sd`.** `/tmp` is in RAM. |

The default paths follow from this: `/root/loot/starchorus` for the collector, the page and
`starchorus.json` (persistent), and `/tmp/starchorus` as the collector's volatile default
(`STARCHORUS_OUTDIR`).

---

## 2. Tools on board

Checked on the device with `command -v` or `iw dev`. The preferred route through the recon database
therefore runs **without** `opkg` and **without** internet access on the device.

| Tool | Status | Role for Starchorus |
|---|---|---|
| `sqlite3` | present | real SQLite; carries the preferred source `recondb` |
| `tcpdump` | present | monitor-mode capture (receive only), fallback source `capture` |
| `iw` | present | interface detection; `iw scan` only with opt-in (active) |
| `iwinfo` | present | interface introspection |
| `jq` | present, **without regex** | every dashboard filter; built without Oniguruma, see §2a |
| `timeout` | present | genuine coreutils `timeout` (the dashboard's key wait) |
| `nc` | present | **GNU netcat 0.7.1** (not BusyBox nc); carries only the fallback server; offers `-s ADDRESS` (local address, §8) |
| `cksum` | missing | `ash: cksum: not found`; `tools/install.sh` therefore verifies by reading every file back and comparing it byte for byte (seen 11 October 2026) |
| `crond` | present | BusyBox cron, one-minute tick (`starchorus-collect.sh --once`) |
| `start-stop-daemon` | present | detaches the fallback server cleanly from the payload run |
| `airodump-ng` | missing | optional source; only after `opkg install -d mmc aircrack-ng` |
| `python3` | missing | no `python3 -m http.server` |
| `uhttpd` | may be present | installed as `/usr/sbin/uhttpd`, not enabled at boot and not running by default; the payload uses it when it is present. If it is missing, it can be added as a local `.ipk`, see [display-paths.md](display-paths.md). Seen on 13 October 2026: a system update on the Pager removed it (same firmware 24.10.1, new SSH host keys, `/root` intact); the payload then fell back to the netcat server, which served a browser cleanly |
| BusyBox `httpd` | missing | applet not compiled in |
| `nginx`, `lighttpd`, `php` | missing | – |

**Consequence:** by default **no web server** runs for files of our own. The web interface on port
1471 serves only itself. `uhttpd` may be present but is not enabled; the payload starts it, when it
is present, on its own port (§7).

### 2a. `jq` is built **without Oniguruma**: no regex functions

Measured on the device:

```
$ jq -n '"abc"|test("b")'
jq: error (at <unknown>): jq was compiled without ONIGURUMA regex library.
           match/test/sub and related functions are not available.
$ echo $?
5
```

| jq function | Status on the device |
|---|---|
| `test`, `match`, `capture`, `scan`, `sub`, `gsub`, `splits`, `split/2` (with flags argument) | **missing**: error at run time, exit 5 |
| `ascii_upcase`, `ascii_downcase` | measured on the device, work |
| `ltrimstr`, `rtrimstr` | measured on the device, work |
| `startswith`, `contains` | measured on the device, work |
| `split/1` (plain separator string, no flags) | measured on the device, works |
| `endswith`, `until`, `index`, slicing `.[a:b]`, `tostring` | **not yet measured individually on the device** (open verification V-12). Standard builtins with no regex involvement; checked locally against jq 1.7.1. The dashboard's filters use them. |

The error arises **at the call**, not at parse time: a regex call in a branch that is never taken
does no harm. As soon as it is evaluated, the **whole** jq program aborts. Because the dashboard's jq
helper `q()` discards `stderr` (a screen should never show jq messages), such an abort would produce
no error message but **blank** counters, for example:

```
APs <n>   ·   2.4:  5:  6:          instead of   APs <n>   ·   2.4:<n>  5:<n>  6:<n>
No open/WEP networks                instead of   Open/WEP networks: <n>
```

**Rule for this repository:** in `starchorus-display.sh`, and in every other jq filter that runs on
the device, the regex family is **forbidden**, the self-test included. The replacements are the
string building blocks above, gathered in the `JQLIB` block (`bandnorm`, `secupper`, `isopenwep`,
`sectag` and others), which `q()` prepends to every filter. A builtin the filters do not yet use
needs a check on the device before it is used.

Three safeguards hold the rule:

1. **Regression rows on the development machine.** `tools/regress.d/jq-noregex.sh` checks both
   copies of `starchorus-display.sh` statically for regex calls, runs the complete dashboard through
   a reconstructed 'jq without regex' and compares the result with a run under the real jq, guards
   that reconstruction against vacuity, checks the meaning of `bandnorm`/`sectag`/`isopenwep`/
   `secupper` against a fixed table (including the whitespace set `_WS` at **both** ends of the
   string), and checks the top screen with non-text `ssid`/`security`/`band`.
   `tools/regress.d/display-selftest.sh` pins down the self-test and the marker, including a
   negative control with a jq in which exactly `endswith` fails at run time, and a second regex scan
   that first joins the shell's `''` pairs: a `te''st(` split in the source escapes the static scan
   of `jq-noregex.sh`, but not this one.
2. **Visible marker on the device.** `summary`, `top` and `bands` first check, with **one** cheap
   jq call through the same `JQLIB` path (known values for `bandnorm`/`sectag`/`isopenwep` plus
   `add`, `group_by`, `sort_by`), whether the building blocks work on this device. If they do not,
   **one** red line appears:
   `jq incomplete on this device -- counts may be blank. Run: sh starchorus-display.sh --selftest`.
   With a healthy jq the marker prints nothing and leaves the rest of the output unchanged.
3. **Self-test on the device.** It uses the file's **real** `JQLIB` filters (not a copy) and prints
   **one line per building block**:

   ```
   sh /root/loot/starchorus/starchorus-display.sh --selftest
   # lines "[display-selftest]   PASS: jq builtin endswith" and so on, finally
   # "[display-selftest] SELFTEST: ALL PASS (<N> checks)", exit 0
   ```

   It checks (a) every jq building block the filters use, one by one (among them the five open ones
   from V-12, the string building blocks, `group_by`, `sort_by` also with several keys, `unique`,
   `add`, `map`, `max`, `range`, `round`, `type`, `not`/`empty`, the `//` operator, `\uXXXX`
   escapes, string interpolation and `def` with `$` parameters), (b) `bandnorm`, `secupper`,
   `isopenwep` and `sectag` against a small fixed table and (c) the summary over an embedded mini
   fixture (dummy BSSIDs): band counters must be digits, and the Open/WEP line must match the
   fixture. The single `INFO:` line names the jq version and never changes the result. The self-test
   calls **no** regex builtin. Its output contains no environment data. If a building block fails,
   a `FAIL: jq builtin <name>` line names it, and the run ends with `SELFTEST: FAILED (k of N)` and
   exit 1. If `jq` is missing altogether, it reports `FAIL: jq present` and
   `SELFTEST: FAILED (1 of 1)` (exit 1).

   This one-liner checks only the five open building blocks:

   ```
   jq -n '["5 GHZ"|ascii_downcase|endswith("ghz"), ("ab"|until(length==1; .[:-1])), ([" "]|index(" ")), (5|tostring)]'
   # expected: [true,"a",0,"5"]
   ```

`starchorus-collect.sh` is **not** affected by the rule: its only jq call is the validity check
`jq -e .`; the `sub`/`gsub`/`match` occurrences there are `awk`, not jq.

---

## 3. Interfaces and passivity

Confirmed on the device with `iw dev`:

| Interface | Radio | Role |
|---|---|---|
| `wlan0mgmt` | radio0 (2.4 GHz) | management AP |
| `wlan0cli` | radio0 (2.4 GHz) | client VIF |
| `wlan0mon` | radio0 (2.4 GHz) | monitor VIF on the 2.4 GHz radio |
| **`wlan1mon`** | radio1 | **recon monitor** of the recon service, **channel-hopping** (2.4 + 5 GHz) |
| `wlan2mon` | radio2 | optional USB adapter in monitor mode |

**Behaviour of the collector:**

- `STARCHORUS_SOURCE=auto` resolves to **`recondb`** on the device: `wlan1mon` already exists and
  belongs to the recon service, and `sqlite3` is present. The collector only reads the database
  that this service fills, and starts no second capture on the same radio.
- `wlan1mon` and the management radio stay **untouched**. Among several monitor interfaces, `auto`
  picks `wlan1mon` first, then any one other than `wlan0mon`, otherwise the first.
- The collector creates a monitor VIF of its own only when **none at all** exists
  (`STARCHORUS_CREATE_MON=1`, the default), and never on the management radio. The exit handler
  removes only a VIF it created itself; on the device that never happens.
- Tuning the receiver's channel is permitted; transmitting of any kind is not.
- One collector runs per Pager, so that two loops never share the monitor interface or radio:
  starting or stopping any instance stops every other collector loop on the device (`--once` and
  `--status` runs are left alone), and each loop so stopped is logged with its pid and working
  directory (read from `/proc/PID/cwd`).

---

## 4. Recon database: schema

**Path:** `/root/recon/recon.db` (== `/mmc/root/recon/recon.db`). With `STARCHORUS_RECON_DB=auto`
the collector tries this and a few other known paths, and finally searches, with a limit
(`find -maxdepth 4`), under `/root`, `/mmc`, `/tmp` and `/etc`; the first readable match wins.

Before every read the collector **copies** the database to `STARCHORUS_CAPDIR/recon_copy.db`
(together with `-wal`/`-shm`, if present) and opens the copy with `sqlite3 -readonly`, so that it
never locks the capture. The AP service writes with `journal_mode=MEMORY`, so there are usually no
`-wal`/`-shm` files. If copying fails, it reads the original file, likewise `-readonly`.

`build_from_recondb()` serves both schemas below and, in addition, an older `aps` table, by trying
the matching `SELECT` statements in turn; the first non-empty result wins.

### 4a. Schema with `bssid`/`channel` and the `wifi_device` join (confirmed live on the device)

```
ssid(hash, wifi_device, scan, type, bssid, ssid BLOB, hidden, time, signal, freq, channel, encryption)
wifi_device(hash, scan, mac, time, signal, freq, packets)
```

- **APs** are read from `ssid` through `type IN (5,8)` and deduplicated with **`GROUP BY bssid`**;
  the values of the strongest observation come through `MAX(signal)`. `last_seen` is `MAX(time)`
  per BSSID and comes from a derived table: a second aggregate in the same `SELECT` would make the
  remaining columns (SQLite 'bare columns') arbitrary.
- **Client MACs** come through the join `ssid.wifi_device → wifi_device.hash (.mac)`, filtered to
  `type = 4` (probe requests).
- **Sought SSIDs** (optional `probes[]`): the `ssid` column of the `type = 4` rows is the network
  the station **asks for** (received, not transmitted). The collector emits them per station,
  deduplicated, sorted and at most eight; wildcard probes (empty SSID) are dropped.
- **Several SSIDs per BSSID** (optional `responded_ssids`): how many different SSIDs a BSSID has
  named in probe responses (`type = 5`), as a number only and only from two upwards.
- `channel` is a column of its own; `band` is preferably derived from `freq` (which includes
  6 GHz), otherwise from `channel`.

### 4b. Schema with `apmac`/`stamac` and `band` (from the firmware image)

```
ssid(scan, type, apmac, stamac, ssid BLOB, encryption, freq, signal, hidden, band)
   UNIQUE(scan, type, apmac, stamac, ssid)
wifi_device(hash, mac, packets)
```

- Here APs are keyed by **`apmac`** (`GROUP BY apmac`), clients directly by **`stamac`**.
- There is **no** `channel` column and **no** `bssid` column; the channel is calculated back from
  `freq`.
- The `band` column serves as a fallback when `freq` is missing.

### `type`: 802.11 management subtype

| `type` | Subtype | Meaning | Assignment |
|---|---|---|---|
| **8** | Beacon | access point | AP entry (via `bssid` or `apmac`) |
| **5** | Probe response | access point | AP entry (via `bssid` or `apmac`) |
| **4** | Probe request | client/station | unassociated client (via the `wifi_device` join or `stamac`) |

The recon database knows nothing of associations. All its stations end up in `unassociated`, and
the APs' `clients[]` stay empty; real assignments come only from the `capture` source with
`airodump-ng`.

### MAC normalisation

The database stores MAC/BSSID in **upper case without colons**; the collector normalises to lower
case with colons. `ssid` is a **BLOB** and is read with `CAST(ssid AS TEXT)`; embedded tabs and line
breaks become spaces. `hidden = 1` or an empty SSID means a hidden network and yields `"ssid": ""`.

---

## 5. `encryption`: bitmask and meaning

The `encryption` column is the **`encryption_info` bitmask (uint64)** of the libwifi library. The
class bits sit low, the bits of the authentication schemes (e.g. SAE) far up:

| Bit | Value | Meaning |
|---|---|---|
| `1<<1` | 2 | WEP |
| `1<<2` | 4 | WPA |
| `1<<3` | 8 | WPA2 |
| `1<<4` | 16 | WPA3 |
| `1<<57` | (high) | SAE (auth scheme; counted as WPA3) |

### Confirmed on the device against real networks

Checked against networks in range (reduced mask `encryption & 30`):

| Reduced mask | Bits set | Meaning | Note |
|---|---|---|---|
| `0` | – | **open** | |
| `4` | bit 2 | **WPA** | rare |
| `8` | bit 3 | **WPA2** | the majority of networks |
| `16` | bit 4 | **WPA3** | |
| `24` | bits 3+4 | **WPA2/WPA3 transition** | transition mode |
| `2` | bit 1 | **WEP** | assigned by libwifi; no real WEP network observed on the device |

### SQL extraction

`awk` computes 64-bit integers as doubles and would lose precision. The mask is therefore reduced
**in SQL**:

```sql
CASE WHEN typeof(encryption)='integer'
     THEN ((encryption & 30) | (CASE WHEN ((encryption>>57)&1)=1 THEN 16 ELSE 0 END))
     ELSE encryption END
```

- `encryption & 30` keeps the four bits 1–4 (WEP/WPA/WPA2/WPA3 = 2+4+8+16 = 30).
- The second term sets the WPA3 bit (16) when the **SAE auth bit (57)** is set; this is how pure
  SAE networks are recognised as WPA3.
- If `encryption` is text (`"WPA2"`, `"OWE"`, …), the `CASE` returns the raw value, which is
  normalised afterwards.

### 5a. What else the collector reads from `encryption`, and open device questions

The bit layout of libwifi's `encryption_info`, pinned to a commit, stands as a comment above
`build_from_recondb` in the collector: class bits 1–4, group cipher 5–17, pairwise cipher 18–31,
AKM 32–53 (bit 38 is unassigned in the header), auth scheme 54–58. The collector fetches the four
fields in SQL as small integers (each < 2^22, exact in `awk`). Three values seen on the device break
down as follows:

| Value | Bits | Meaning |
|---|---|---|
| `17184063752` | {3, 8, 22, 34} | WPA2, group CCMP128, pairwise CCMP128, AKM PSK |
| `6597073961232` | {4, 8, 22, 41, 42} | WPA3, CCMP128, SAE + SAE-FT |
| `2216207319320` | {3, 4, 8, 22, 34, 41} | transition: PSK **and** SAE |

From these come the AP fields `akm[]`, `cipher{}` and `auth[]` and the labels `OWE`,
`…-Enterprise` (802.1X AKMs) and `… (TKIP)` (TKIP as the only pairwise cipher, or, with no pairwise
field, as the only group cipher). OWE is checked first, because libwifi also sets the WPA3 class
bit for OWE.

Everything that depends on device behaviour not yet verified sits behind a switch whose default is
**off**. Each question needs the person at the device to approve the command:

| Question | One-liner / procedure | Affects | Probe |
|---|---|---|---|
| Is `time` in `ssid` a first-seen time or an update time (upsert)? | `sqlite3 -readonly <copy> "SELECT bssid, time FROM ssid WHERE type=8 LIMIT 5"`, twice, 30 s apart | `STARCHORUS_HOPINFO`, freshness, `first_seen` (stays unwritten) | V-1 |
| Is `freq` the receive frequency? | compare `channel` and `freq` of the same rows | band from `freq` | V-2 |
| Does the driver provide `iw dev wlan1mon survey dump` (noise, active/busy time)? | `iw dev wlan1mon survey dump` (read-only) | `STARCHORUS_SURVEY` | V-5 |
| What does `wifi_device.packets` count? | read the counter twice, cross-check against `tcpdump -c` | `ap.packets` (stays unwritten) | V-10 |
| Format and fields of the recon output of the AP service command line (`apcli_ro` `recon_aps`/`recon_clients`) | **one** call each; record the output only as a schema with placeholders, no real SSIDs or MACs | `apcli_ro`, `STARCHORUS_APCLI_RO` | V-3 |
| Do the `tx_packets` of `wlan1mon`/`wlan2mon` stay the same before and after every `apcli_ro` command? | `cat /sys/class/net/wlan1mon/statistics/tx_packets` before/after | every `apcli_ro` id | V-3 |
| Are the interface MACs the BSSIDs the device itself transmits? | `cat /sys/class/net/*/address` against the beacons in the database | `STARCHORUS_OWN` | V-9 |
| What format does the firmware's OUI file have? | `head -5` and `wc -lc` of the file | `STARCHORUS_OUI_FILE=auto` | V-8 |

At the end, `tools/device-probe.sh` reports each open verification as `V-<id> <name>: OBSERVED …` or
`NOT-OBSERVABLE …`. Beyond the table it covers V-6 (6 GHz reception), V-11 (multi-BSSID profiles,
which the database may under-record) and V-12 (the five open jq building blocks, §2a). V-3, V-4
(a radio-locking examine command, not used by Starchorus), V-7 (the device's deauth reporter) and
V-11 remain `NOT-OBSERVABLE` there: they would need a command that a read-only run does not call.

### 5b. Homing: open device questions

Homing calls **no** command of its own: it takes the `rssi` from the selected AP's row in the
document the collector writes in any case (one value per cycle). Still open on the device, each
with approval per command:

| Question | Procedure | Affects |
|---|---|---|
| How often does the database update `signal` for a single AP (every cycle or less often)? | read the same BSSID over ten cycles with `sqlite3 -readonly <copy>` | the coarse display |
| Can a selection on the device display write `homing.target` (first line, MAC) atomically? | `LIST_PICKER` over `aps[]` without the device's own BSSIDs, then `printf … > homing.target.tmp && mv` | choosing the target on the device |

---

## 6. The recon database is cumulative: `STARCHORUS_MAX_AGE` as a window

The recon service collects **cumulatively** and discards nothing. Without an age window the map
shows the whole database: the numbers only grow, and do not shrink when networks and stations leave
the area.

The whole database is too large for the device's CPU to process on every pass. Measured on the
device: a database grown over a long time (874 APs, 15,362 clients, 1.7 MB of JSON) takes minutes
for one collector pass, while the loop starts every 5 s, and the dashboard's `jq` calls over the
1.7 MB file never finish; the display freezes. A one-hour window yields 27–30 APs, about 420
clients and 46 KB of JSON; a `--once` takes 11 s, a dashboard screen 1–6 s. The payload on the
device therefore reads a one-hour window (`STARCHORUS_MAX_AGE=3600`) and writes every 30 s
(`STARCHORUS_INTERVAL=30`). Within the window the page dims entries according to their freshness.
`STARCHORUS_MAX_AGE=0` reads the whole database; that is the collector's default when run by hand.

`STARCHORUS_MAX_AGE` (in seconds) filters on the **`time` column** (Unix seconds) for genuine live
presence. `0` (the collector's default) = the whole database; a value > 0 keeps only observations
from the last N seconds. The cut-off is computed against the local clock (the same UTC epoch as the
recon engine). In SQL this becomes `AND time > <cutoff>` (or `AND s.time > …` in the
`wifi_device` join).

`STARCHORUS_MAX_AGE=120` suits a calm live map: on the device the numbers then shrink to the
networks, and above all the clients, that are in range at that moment. A window below about 15 s
can flicker, because the recon radio listens to the channels one after another and a single AP is
not heard afresh in every cycle. The window acts **only** on the `recondb` source;
`airodump-ng`/`tcpdump` deliver only the current slice in any case.

---

## 7. No web server, and how the display works

### The page in the browser

By default no web server for files of our own runs on the device (§2); `uhttpd` may be present,
and the payload then uses it. The page is a browser view; it must come from the same origin as
`starchorus.json`. The routes to it, each with status, limits and commands, are described in
[display-paths.md](display-paths.md):

| Route | Status |
|---|---|
| **A**: `uhttpd` on the device, port 8199 | works if `uhttpd` is present (otherwise add it once as an `.ipk`) |
| **B**: a connected computer serves the page and a regularly fetched `starchorus.json` | works, with nothing installed on the device |
| **C**: fallback server `starchorus-serve.sh` over GNU netcat | for single requests (`curl`) only; unreliable for a browser |
| **D**: any client on the management network opens the server from A | works like A |

Never put a server on port 1471 (the device's web interface) or 80; Starchorus takes a free high
port (default 8199, `STARCHORUS_PORT`).

### The device display

- **480×222 LCD**, driven by the AP service through its own interface, which composes PNG image
  layers, text templates and key-driven menus. Keys: `a`, `b`, `up`, `down`, `left`, `right`.
- **No webview, no HTML/JS** on the display path. There is **no documented hook** through which a
  payload could register a screen of its own; a firmware update would overwrite changes to the
  interface itself. The page therefore remains a browser view.
- A payload addresses the display through commands that exist **only in the payload runtime**.
  Starchorus uses exactly these:

| Command | Effect | Used by |
|---|---|---|
| `LOG [colour] "text"` | appends a line to the log on the display (append-only); optionally with a colour | dashboard (`red` = alarm, `blue` = heading), payload (`blue` = heading, `red` = no web server, `green` on stopping, plus the status lines) |
| `LIST_PICKER "title" opt1 … default` | shows a selection list and prints the chosen option on stdout; the last argument is the default | the payload's and dashboard's menus; in the payload also every switch ('On'/'Off', the current state preselected) |
| `NUMBER_PICKER "title" default` | number entry; prints the number on stdout | payload: port, custom window, custom interval |
| `CONFIRMATION_DIALOG "text"` | yes/no confirmation | payload: before 'Start', before 'Defaults', before the 'All' window and a window above 21600 s |
| `START_SPINNER "text"` / `STOP_SPINNER id` | busy indicator on and off; `START_SPINNER` prints the id | dashboard and payload when starting the collector |
| `ERROR_DIALOG "text"` | error dialogue | dashboard when `jq` is missing; payload on an invalid number, when both services are off, when saving fails and when the dashboard is missing |
| `WAIT_FOR_BUTTON_PRESS B` | waits for key B (bounded by `timeout`) | dashboard: B opens the menu or returns |

**The payload's cancel contract (not confirmed on the device).** How cancelling (key B) ends
`LIST_PICKER`, `NUMBER_PICKER` and `CONFIRMATION_DIALOG` (exit code, output) has not been measured
on the device. The payload therefore reads every answer defensively: a picker counts as 'Back' if
the exit code is not 0, the output is empty or it is none of the options offered; an empty or
cancelled number entry leaves the value unchanged; a confirmation counts as yes only if the exit
code is 0 **and** the output reads `1` (the runtime's 'confirmed' value, as a literal, so that the
environment cannot redefine what counts as yes). Open on the device: these return values; whether
`\n` breaks a line in a dialogue text (the payload avoids line breaks); how many characters a menu
line shows (the payload keeps titles to at most 14 and options to at most 18 characters; the limit
is an estimate); and whether a `LOG` line stays visible behind or after a picker (status, stop and
start draw a menu again after the log, rather than ending as they used to).

The dashboard `starchorus-display.sh` is the on-device view: seven screens from `starchorus.json`
(summary, strongest networks, bands and security, devices and merges, probe requests, stations, air
quality) as LOG lines, plus a menu to start and stop the collector and show its status. It
recognises the device by the `LIST_PICKER` command (`LOG` alone will not do: macOS has
`/usr/bin/log`). Without that command, or with `STARCHORUS_DISPLAY_PLAIN=1`, every command falls
back to plain text on stdout; `sh starchorus-display.sh --once summary <json>` thus prints the same
content on the development machine. It does not draw the animated web view. Details:
[display-paths.md](display-paths.md#dashboard-on-the-device-display).

---

## 8. Payload layout and firewall

### Payload layout

Payloads live on the device under:

```
/root/payloads/user/<category>/<name>/payload.sh
```

The AP service starts `payload.sh` from its payload menu. Starchorus sits as a purely passive
payload in the **reconnaissance** category:

```
/root/payloads/user/reconnaissance/starchorus/payload.sh
/root/payloads/user/reconnaissance/starchorus/starchorus-display.sh
```

The collector, the page (`index.html`), the dashboard and the fallback server live under
`/root/loot/starchorus`; `tools/install.sh` copies both sets. A self-contained payload directory
(`tools/hak5-package.sh`) carries them beside `payload.sh` instead, and the payload copies them to
`/root/loot/starchorus` on its first run when no collector is there yet. The payload starts the
passive collector over a one-hour window (`STARCHORUS_MAX_AGE=3600`, every 30 s; §6), serves the
page on port 8199 **if** a server is present (`uhttpd`, then `python3`, then the fallback server),
and opens the dashboard. What starts, and with which values, is set by the payload's menu; it saves
the choice in `/root/loot/starchorus/settings.conf` (never overwritten by `tools/install.sh`).
Without a server the collector carries on writing `starchorus.json`; the view then comes from a
connected computer (route B). `payload.sh stop` ends the collector and the server.

### Firewall (fw4/nftables)

Observed on firmware 'Pineapple Pager' 24.10.1:

| Zone | Networks | Input |
|---|---|---|
| `lan` | `lan` = `br-lan`, `172.16.52.1/24` (USB-C and management Wi-Fi) | `ACCEPT` |
| `wan` | `wan`, `wan6`, `eth`, `cli`, `wwan`, `usb`, `wpa`, `open`, `ent` | `ACCEPT` |

The device's own rules restrict only ports 22 and 1471 to USB-C and the management Wi-Fi.

- **Consequence:** any high port (e.g. 8199) is reachable from a computer on the management
  network without any firewall rule being needed, and equally from any network the Pager joins in
  client mode, if the server listens there.
- **Hence** every Starchorus page server listens on the address of `br-lan` by default
  (`STARCHORUS_BIND=auto`; `ip -4 -o addr` shows `br-lan 172.16.52.1/24`), not on `0.0.0.0`.
  `STARCHORUS_BIND=all` restores every interface and with it the exposure above.
- **Syntax, verified on the device:** `uhttpd -h` prints `-p [addr:]port` (and `-s [addr:]port` for
  HTTPS); the payloads start `uhttpd -p ADDR:PORT`. `nc` is GNU netcat 0.7.1 with
  `-s, --source=ADDRESS` and `-l`/`-p`/`-n`; the fallback server listens with
  `nc -l -n -s ADDR -p PORT -c`. Checked on the device on 11 October 2026: with the default bind,
  `netstat -ltn` shows `172.16.52.1:8199` for uhttpd and `172.16.52.1:8299` for the fallback server
  on a test port, nothing on `0.0.0.0`; the Pager's own `:1471` and `:22` are unchanged. BusyBox `httpd` (`-p [IP:]PORT`) and `python3` (`--bind ADDR`) are
  absent here; the root `payload.sh` binds them the same way where they exist. The device's
  BusyBox does not accept `--list` (`-list: applet not found`), so the root `payload.sh`'s
  BusyBox `httpd` test is simply false here.
