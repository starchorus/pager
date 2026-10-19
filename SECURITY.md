# Security and passivity

Starchorus is a strictly passive, receive-only Wi-Fi observation tool (and, opt-in, a passive Bluetooth LE
listener); it never transmits. It only listens to radio. The tool contains no function that transmits or interferes; this property is the
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
| **Bluetooth LE, passive scan** | Opt-in: `STARCHORUS_BLUETOOTH=1`, or Settings > Bluetooth; off by default. For 5 s per cycle the collector runs `hcitool -i hci0 lescan --passive --duplicates` and reads what the controller hands the host with `btmon -i hci0`. By the Bluetooth specification a passive scan sends no scan request: the controller only listens for advertisements that devices broadcast anyway. In a hand run on the device on 16 October 2026 the HCI transmit counter rose by 20 bytes in 3 commands (scan parameters, enable, disable), all passing from the host to the controller inside the device; they are not radio transmissions, and they change nothing in the controller's configuration beyond the passive scan's own parameters and its enable and disable. A window counts only when `btmon` shows the collector's own scan parameters with `Type: Passive` before the first report; that is what was asked of the controller (this project measures the host side; an observation of the air would need a separate sniffer). The scan is ended with SIGINT (a SIGTERM is the last resort and is logged, see [docs/device-notes.md](docs/device-notes.md) §2b, V-13); `hcitool` is never sent SIGKILL. A collector that is stopped sends the first SIGINT to a scan younger than a second one second after its start, because a scan that has not yet installed its handler would die of it with the controller still scanning (passively); a collector that was killed with SIGKILL leaves its tools to their own dead-man timers and to the next start's sweep, which sends SIGINT only. Nothing else of the Bluetooth stack is called. The collector ran its window on the Pager on 18 October 2026 at 6 s, the default then (device-notes §6a); the 5-s default has not run there yet, and the device checks that remain are listed in device-notes §2b and §6a. |
| **Channel activity** | Opt-in: `STARCHORUS_TRAFFIC=1`, or Settings > Traffic; off by default. `_pineap RECON CHANNELS format=json`, a fixed line of `apcli_ro`, reads the AP service's frame count per frequency, on the first cycle and then on every second one (the cycle in between publishes the answer of the cycle before). It was checked on the device (`docs/device-notes.md` V-3, 14 October 2026): the transmit counters of `wlan0`, `wlan0mon` and `wlan1mon` stayed the same around single calls. The repetition that matches how the collector uses it was run on 18 October 2026 (`docs/device-notes.md` §6a), when the call was still made every cycle, which is twice the rate of today: one call every cycle for ten minutes, with the transmit counters of `wlan0`, `wlan0mon` and `wlan1mon` taken before and after (the firmware had no `wlan0mgmt` or `wlan0cli` interface that day); they stayed the same. |

The collector creates its own monitor interface only if none exists (`STARCHORUS_CREATE_MON=1`,
the default), and then only on an adapter that is not the management radio; on exit it removes
exactly that interface again. An existing monitor interface is shared but never removed. The
collector never touches the management radio.

### Additional read and output paths

Every further path is named here. Anything that depends on the device's behaviour is a switch that
defaults to **off**, with one exception, the Alerts row: it defaults to on, but it reads a file that exists only after the owner has put
the companion alert in place by hand, so without that nothing happens, and nothing of the alert path has been observed on the device (the
firmware's alert and the variables it hands over, whether a copied alert runs, `flock`, `tail -c` and `bash` there:
[docs/device-notes.md](docs/device-notes.md) §5c).

| Path | What exactly | Default | Transmits? |
|---|---|---|---|
| Vendor name from an OUI file | reads a **local** file of MAC prefixes (`STARCHORUS_OUI_FILE`; `auto` tries known paths) and adds `vendor`; `randomized` follows from the MAC itself, without a lookup. A cache and an index of the OUI file live in `STARCHORUS_CAPDIR`. | on (`STARCHORUS_VENDOR=1`) | no |
| `iw dev <IF> survey dump` | reads the channel statistics kept by the driver (frequency, noise, active and busy time) via a netlink dump; **no scan** | off (`STARCHORUS_SURVEY=1`) | no |
| `/sys/class/net/*/address` | reads the MAC addresses of the device's own interfaces into `center.own_bssids`; `own_ssids` comes **only** from the file in `STARCHORUS_OWN_SSID_FILE`, never from the AP service's SSID pool | off (`STARCHORUS_OWN=1`) | no |
| Recon database, column `time` | a further read-only query of the same copy: last time heard per frequency into `channels[]` | off (`STARCHORUS_HOPINFO=1`) | no |
| Recon database, probe responses | number of distinct SSIDs with which a BSSID has answered probes (`responded_ssids`, only from 2 upwards); a number, not a list of SSIDs | always on the database path | no |
| Homing AP | reads `STARCHORUS_HOMING_BSSID` or the first line of `$STARCHORUS_OUTDIR/homing.target` and adds a `homing` object built from that AP's row in the same document (section 4) | no AP | no |
| `apcli_ro` | the only place where a command of the AP service's command line may appear: **exactly** four fixed command lines, literal in the code, no `eval`, no command name taken from a variable and no argument taken from outside (the lines only carry the optional prefix `timeout 10`). They are three read-only commands: `RECON APS format=json` and `RECON DEVICES format=json` (the recon lists as JSON), the second one also in the CLI's own bounded form `sort=time sortdir=desc limit=400` (newest first; this is the form `STARCHORUS_SOURCE=pineap` runs by default, `STARCHORUS_PINEAP_CALLS=full` runs the two plain lists), and `RECON CHANNELS format=json` (the frame count per frequency, the row above), which runs only with `STARCHORUS_TRAFFIC=1`: its id is gated on that switch alone, so Traffic does not make the recon lists callable and `STARCHORUS_APCLI_RO=1` does not make it callable. The plain lists were checked on the device (docs/device-notes.md, V-3): the transmit counters of every wireless interface (`wlan0`, `wlan0mon`, `wlan1mon`) were the same before and after each call. The bounded form (`limit=400`) was checked the same way in a 130 s run of the source on 14 October 2026 (the forms `limit=50` and `pagesize=100 page=1` earlier): the counters were unchanged. The calls run under `timeout 10` where a `timeout` command exists. Listening to a single BSSID, never verified on the device and called by nothing, is no longer in the list. The self-test calls the function with a stub and shows that deauth, stopping and restarting recon, `RECON CLIENTS` (which does not exist), SSID pool commands, uploads, GPS, listening to a BSSID, extra arguments and injection attempts are refused **without** a call. | off (`STARCHORUS_APCLI_RO=1`); `STARCHORUS_SOURCE=pineap` switches `apcli_ro` on for itself; the channel line needs `STARCHORUS_TRAFFIC=1` only | no (read-only commands) |
| Source `pineap` (experimental) | `STARCHORUS_SOURCE=pineap` builds `starchorus.json` from these lists instead of from the database (opt-in only; `auto` never chooses it, and recon.db stays the default). When the AP service gives no usable answer, that cycle is built from the database. Its only extra read is the database path already described: the security of each access point, which the lists do not carry, from one query at most once a minute while an access point is new to the cache (every 10 minutes for those the database does not know). The labels are kept in a small cache in RAM, `$STARCHORUS_TMPDIR/starchorus-sec.txt`: the BSSIDs of nearby access points with their security. The collector does not delete it when it exits; it goes with a reboot, or delete it by hand. The lists of BSSIDs that a lookup is made from (`starchorus-pineap-<pid>.*`) are deleted at the end of each cycle. If `STARCHORUS_TMPDIR` is not a writable directory no lookup is made and every access point reads `Unknown`. Nothing else is run. | off (`STARCHORUS_SOURCE=pineap`) | no |
| Alerts | with `STARCHORUS_ALERTS=1` the collector reads `alerts.log` in `STARCHORUS_ALERT_DIR` (default `/root/loot/starchorus-alerts`, a directory of its own outside the one the page server serves) when that name is a readable regular file with something in it (a directory or a pipe is read as no file): the last 256 KiB through a snapshot in RAM (mode 600, removed after the cycle), as untrusted text, of which only a digit epoch, `deauth` and an access point address are kept. It writes `alerts[]` into `starchorus.json`: per access point the address, how many reports and the newest time, at most 20, for `STARCHORUS_ALERT_WINDOW` seconds (default 600). The file is written by the companion `alert-deauth.sh`, which the owner puts into the firmware's alert tree, by hand or with the Settings row 'Alerts' (next row): the firmware runs it for each of its own deauth/disassoc alerts, with the event in environment variables, and it appends one line (the time and four addresses; the message text is not written) under `flock`, keeps the last 2,000 lines, and runs no command but `date`, `printf`, `tr`, `wc`, `tail`, `mv`, `mkdir`, `rm` and `flock`. It calls no display, sound, LED or vibration command, receives and sends nothing, and the passivity check reads it with the other shell files of the payload directory. The log holds addresses of other people's equipment and stays on the device (mode 600, in a directory that no page server of the payload serves); the source and destination addresses reach no document, and the counts on the page stay local and live (P6). The page draws a ring and a legend row for an alerted access point, and the Overview one red line, from the document alone: nothing is sent, and no vibration, sound or LED is used | on (`STARCHORUS_ALERTS=0` ends it), and silent without the file; unmeasured on the device | no |
| Alerts: install and remove (Settings row 'Alerts') | on the owner's press, and only after a confirmation dialogue, the payload runs `mkdir -p`, `cp`, `chmod +x` and `mv`: it makes `/root/payloads/alerts/deauth_flood_detected/starchorus`, copies the `alert-deauth.sh` that sits beside the payload into it as `payload.sh.tmp`, makes that executable and renames it to `payload.sh` (so the firmware never finds half a script); a failed step removes the temporary file and the directory if it is empty. On an installed companion a press asks again and runs `rm -f` on that `payload.sh` (and the temporary file) and `rmdir` on that directory, which only removes it while it is empty; nothing else is touched. This is the one place the payload writes outside its own directories. It starts, enables, disables and stops nothing in the firmware: whether the alert is listed, and whether it runs, stays with the firmware's own Alerts page. Passivity is unchanged: the companion it installs is the file the previous row describes, which only appends times and addresses to a log and sends nothing; the payload gains no radio, network or controller command, and the plain paths (arguments, `STARCHORUS_PAYLOAD_PLAIN=1`) cannot reach the row. The row is locked while `STARCHORUS_ALERTS` is set in the environment, and the test hook `STARCHORUS_ALERT_TREE` (default `/root/payloads/alerts`) exists for the test suite | off until pressed | no |
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
| Bluetooth inquiry or active scan (no scan request), advertising, connection, pairing, GATT access or echo request, and any change to the controller's configuration beyond a passive scan's parameters and its enable and disable | not present |

There is no switch and no environment variable that enables any of these functions; they are not
implemented. Nor is the receiver ever held on a channel or BSSID: the homing value is one value per
cycle, taken from the document that was captured anyway. Starchorus creates no persistent device
configuration (no rules, no services) and controls neither LED nor buzzer; the one file it can put into the firmware's own tree is the alert companion, only
when the owner presses 'Alerts' in Settings and confirms (the row above).

### Static check

`sh tools/passivity-check.sh` checks these rules against the source:

- The page has no way to send: `fetch(` appears exactly once, with the target `starchorus.json`; no
  `method:`, `POST`, `XMLHttpRequest`, `WebSocket`, `EventSource`, `sendBeacon`, no other network
  APIs and no navigation used as a command path; external URLs only in the font's licence header.
- The AP service's command words (command-line call, the service's environment variables, deauth,
  SSID pool, upload, GPS) appear only in `apcli_ro`, `apcli_stub` and `apcli_selftest`; the `pineap`
  source reaches the command line only through `apcli_ro`. The firmware's other active or outward
  commands are denied the same way, by name and by the prefixes `WIFI_PCAP_`, `OPENVPN_`,
  `WIREGUARD_`, `AUTOSSH_`, `DNSSPOOF_` and `PINEAPPLE_`.
- `iw scan` appears only behind `STARCHORUS_ALLOW_ACTIVE=1`; no transmitting tool is called, and the
  check denies the Bluetooth verbs that transmit by name (`hcitool` with `scan`, `inq`, `cc`, `lecc`,
  `leadv` or `cmd`, `l2ping`, `btmgmt`, `gatttool`, `bluetoothctl scan on`, `hciconfig` beyond `-a`) as
  a second line of defence. The list of transmitting tools names, wherever they stand in a code line (a log text too), `aireplay-ng`, `mdk3`, `mdk4`,
  `hostapd`, `hostapd_cli`, `airbase-ng`, `hcxdumptool`, `wpa_supplicant`, `wpa_cli`, `nmcli`, `iwlist`, `iwconfig`, `airmon-ng`, `besside-ng`, `reaver`, `bully`,
  `nmap`, `hping3`, `arping`, `mausezahn`, `tcpreplay` and `bettercap`, each with a sample in the mutation probe. Three lines of the collector must name one of them
  and are pinned byte for byte, each once, with their file and function: the two lines of the last resort of `create_monitor` (when `iw phy ... interface add` fails
  and `STARCHORUS_CREATE_MON` is on, its default, the collector makes its monitor interface with `airmon-ng start`; that changes an interface and sends nothing, and it has been so
  since 0.1) and the path of the OUI file that comes with Nmap, which is read and never run. An edited, a copied and a vanished pinned line are red.
- The Bluetooth stack is denied **by tool**, not by verb. Every program and path of BlueZ that this project knows of
  (`hcitool`, `btmon`, `hciconfig`, `bluetoothctl`, `btmgmt`, `bluetoothd`, `gatttool`, `l2ping`, `l2test`, `rctest`,
  `sdptool`, `rfcomm`, `btgatt-client`, the other BlueZ programs, the bus tools `dbus-send`, `busctl` and `gdbus` and the service name
  `org.bluez`, which is the D-Bus route to a discovery, and the rest of `BT_WORDS` in `tools/passivity-check.sh`) may stand only
  inside the functions of `BT_FUNCS` (`bt_begin`, `bt_end`, `bt_busy`, `bt_sweep`, `bt_stub`, `bt_selftest`), in code, in a string or in
  a log text, whatever the verb or the option order: `hciconfig` with any argument, `bluetoothctl scan le`, `advertise`, `connect` or `pair`,
  `sdptool`, `rfcomm`, `btgatt-client` and the others are red everywhere else. A name is read after the quotes and backslashes of its line
  are removed and adjacent string literals are joined, so `hc''itool`, `hc\itool` and an awk `"hci" "tool"` are `hcitool`. In `bt_begin` every
  line that holds one of these words or `timeout` must be one of seven enumerated lines, the two literals of the permitted path above once
  each; in the other functions a tool word may stand only as the last argument of the identity checks `bt_is` and `bt_kid`; inside
  those functions no command wrapper (`eval`, `sh -c`, `env`, `exec`, `source`, `time` and the rest), no command word that is a variable,
  a `$( )` or backtick expansion or a glob and, outside `bt_begin`, no `timeout` may appear, and the test code starts no tool. A name that is only
  built when a line runs is looked for twice: inside those functions by that rule, and in every shell file of the scope by two rows of their own. The first
  lists each simple command whose command word holds an expansion (`$name`, `${...}`, `$( )` or a backtick expression, quoted or not, also behind
  `exec`, `env`, `nice`, `timeout N` and the other wrapper words, after `NAME=value` and after a redirection). The few lines that stand today (the `nice`
  prefix of the launchers, the fixture builder of the collector's self-test, the Overview's `screen_$1` dispatch, the page server's `$NC` and `$HANDLER`,
  the stop call, and the four `$ap_to` lines of `apcli_ro`) are pinned byte for byte with the function they stand in, so a new one, a changed one and a
  missing one are red. The second is red for a command word that holds an unquoted glob character (`/usr/bin/hc?tool`, `/usr/bin/hci[t]ool`, `/usr/sbin/i[w]`;
  `[` and `[[` themselves, the test, are not such a word), for `find` with `-exec`, `-execdir`, `-ok` or `-okdir`, for an `xargs` whose command is its own replacement
  string (`xargs -I{} {}`: stdin then names the command) or is missing, and for any `alias` definition; nothing of that kind stands in the scope today, so its list of pins is
  empty. A glob in a for-list, in a case pattern or as an argument is no command word and is not read. **What the checks do not read:** a glob that is only handed
  on as an argument (`ln -s /usr/bin/hc?tool x` and then `x ...`, `cp`), a program text that is built and then run (`eval`, `sh -c`, a pipe into `sh`, an awk `system()`,
  `. file`) and a name made by a function the script defines. For those the static check says nothing and the guarantee rests on review; the run-time witness reads back what
  was asked of the controller during the collector's own scan window only, so it cannot vouch for a scan that something else started outside one. The tool names
  themselves are still red outside the allowlist, wherever they stand in the text. The five `_pineap` lines of `apcli_ro` are pinned byte for byte, each once. Read-only reads of `/sys/class/bluetooth` are the one exception to 'by tool', since sysfs holds no tool.
  The list of names is what is known of BlueZ, the programs that the project had not named yet included (`mpris-proxy`, `hex2hcd`, `obexctl`, `bluetooth-player`, `btinfo`,
  `scotest`, `hcieventmask`); the device's own file listing (`tools/device-probe.sh`, V-13) has not been taken yet, and every name it adds becomes one more alternative.
- Every `sqlite3` call outside the self-test carries `-readonly`.
- `starchorus-serve.sh` answers only `GET` and `HEAD` on `/`, `/index.html` and `/starchorus.json`.

`tools/passivity-mutate.sh` shows that each of these checks can turn red (it plants one violation for every alternative of the
tool and wrapper lists), and the regression run
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
| `starchorus.ui.v1` | view switches (theme, 2D/3D, the Random switch, layers, Hide panels, the Scope, Observations and baseline on or off): booleans and names only | a few bytes |
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

The Bluetooth marks, the memory of which signal ring each address was last drawn in, and the stations' frame rates are held only in
memory too (no storage key): a Bluetooth address is display and export only, with no baseline, identity, note or event, and a rotating
address is never linked to another across a rotation.

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
- With a Bluetooth capture the JSON export holds the `bluetooth` addresses (an array, with `bluetooth_counts`), each with its signal, company,
  advertised name and the mark it is drawn in, all received. The CSV has no Bluetooth row and no extra column.
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
neither LED nor buzzer, calls no network program and stores nothing that outlasts it (but see the temporary directory below, after a KILL). An optional line
template (`STARCHORUS_DISPLAY_TEMPLATE`, otherwise the first line of `$STARCHORUS_DIR/display.tpl`) is only
read, and only numbers are inserted into it.

While it runs, the keys it waits for are handed over through files in a private temporary directory
(`mktemp -d`, mode 700). A key reader, a background process of the Overview, runs the device's wait for a key again and again and
appends one line per answer to a queue file there: how long that wait was open, in hundredths of a second, and what the wait printed
(the name of the key pressed), nothing from the capture. Beside the queue are a small file of counts (the lines so far, and how many of
them are a B, Left or Right), a file with the pid of the wait that is open, a file with what the last wait printed (the name of the key),
two marks (the reader has ended; the Overview is ending) and a file with the output of the screen's `jq` program, the lines that go to the
display next, until the next program replaces it. The counts and the pid are each written to a finished file beside them (`count.new`,
`wpid.new`, a few bytes, there for a moment) that is renamed onto the file. A `trap` ends the reader and deletes the directory when the
Overview ends, even on INT, TERM and HUP; it ignores a further one of the three while it does so, and waits for the reader for about two
seconds at most (about ten where the device's `sleep` takes no fractions of a second) before it deletes. A KILL runs no trap and leaves
the directory in the device's RAM until it restarts. The Overview signals only
processes it started itself (the key reader, the wait it has open, its `jq` and the watcher of that `jq`).

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
