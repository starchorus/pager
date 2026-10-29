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
| **Reading the recon database** | The preferred path on the device. The SQLite database that the device's recon service fills passively is **copied** before reading and opened only with `sqlite3 -readonly`, so that capture is never locked. The working copy lives in RAM (`STARCHORUS_TMPDIR`, default `/tmp`, a tmpfs on the device) and is deleted after each cycle. With too little room there, or if the copy fails, it is made in `STARCHORUS_CAPDIR` instead (flash; it stays there until a later copy fits in RAM), and as a last resort the live file is read in place, still read-only. It holds other people's MAC addresses and SSIDs, and on the default path it is not written to flash. A copy made in `STARCHORUS_CAPDIR` (`cap/recon_copy.db`) is not in the directory that a page server serves (see Network exposure of the page, below). The collector also keeps the document of its last full pass in its memory (not in a file), which a skipped cycle republishes with a new `generated`. |
| **Receiving in monitor mode** | Listening with `tcpdump` (or `airodump-ng`, if installed) on a monitor interface: receive only, no injection. |
| **Tuning the receiver to a channel** | Only in order to listen; nothing is sent. |
| **Bluetooth LE, passive scan** | Opt-in: `STARCHORUS_BLUETOOTH=1`, or Settings > Bluetooth; off by default. For 5 s per cycle the collector runs `hcitool -i hci0 lescan --passive --duplicates` and reads what the controller hands the host with `btmon -i hci0`. By the Bluetooth specification a passive scan sends no scan request: the controller only listens for advertisements that devices broadcast anyway. In a hand run on the device on 16 October 2026 the HCI transmit counter rose by 20 bytes in 3 commands (scan parameters, enable, disable), all passing from the host to the controller inside the device; they are not radio transmissions, and they change nothing in the controller's configuration beyond the passive scan's own parameters and its enable and disable. A window counts only when `btmon` shows the collector's own scan parameters with `Type: Passive` before the first report; that is what was asked of the controller (this project measures the host side; an observation of the air would need a separate sniffer). The scan is ended with SIGINT (a SIGTERM is the last resort and is logged, see [docs/device-notes.md](docs/device-notes.md) §2b, V-13); `hcitool` is never sent SIGKILL. A collector that is stopped sends the first SIGINT to a scan younger than a second one second after its start, because a scan that has not yet installed its handler would die of it with the controller still scanning (passively); a collector that was killed with SIGKILL leaves its tools to their own dead-man timers and to the next start's sweep, which sends SIGINT only. Nothing else of the Bluetooth stack is called. The collector ran its window on the Pager on 18 October 2026 at 6 s, the default then (device-notes §6a); the 5-s default has not run there yet, and the device checks that remain are listed in device-notes §2b and §6a. On firmware 2.0, where the Pager's own scanner `blue5` holds the controller, this window does not run: a foreign-holder guard stands it down, and `STARCHORUS_BT_SOURCE=auto` reads `blue5.db` instead (the row below). |
| **Reading the firmware's Bluetooth database (`blue5.db`)** | Opt-in: `STARCHORUS_BT_SOURCE=blue5`, or `auto` when the file is present (firmware 2.0). The database that the Pager's own Bluetooth scanner `blue5` fills is **copied** before reading and opened only with `sqlite3 -readonly`, exactly as `recon.db` is; the working copy lives in RAM and is removed after the read, and the live file is **never read in place** (there is no flash or live-file fallback: no copy means no Bluetooth that cycle). Starchorus never starts, stops or configures the `blue5` service and never runs `blue5ctl` (both are denied by name in the passivity check). Whatever Bluetooth scanning filled the database — passive or active — is the Pager's own setting, outside Starchorus's control; reading the result sends nothing. It holds other people's addresses and is not written to flash. |
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
| `apcli_ro` | the only place where a command of the AP service's command line may appear: **exactly** four fixed command lines, literal in the code, no `eval`, no command name taken from a variable and no argument taken from outside (the lines only carry the optional prefix `timeout 10`). They are three read-only commands: `RECON APS format=json` and `RECON DEVICES format=json` (the recon lists as JSON), the second one also in the CLI's own bounded form `bytime=true limit=400` (newest first; this is the form `STARCHORUS_SOURCE=pineap` runs by default, `STARCHORUS_PINEAP_CALLS=full` runs the two plain lists), and `RECON CHANNELS format=json` (the frame count per frequency, the row above), which runs only with `STARCHORUS_TRAFFIC=1`: its id is gated on that switch alone, so Traffic does not make the recon lists callable and `STARCHORUS_APCLI_RO=1` does not make it callable. The plain lists were checked on the device (docs/device-notes.md, V-3): the transmit counters of every wireless interface (`wlan0`, `wlan0mon`, `wlan1mon`) were the same before and after each call. The bounded form was checked the same way: on firmware 1.x its former shape `sort=time sortdir=desc limit=400` in a 130 s run of the source on 14 October 2026 (the forms `limit=50` and `pagesize=100 page=1` earlier), and — after firmware 2.0 rejected `sort=time` — the newest-first shape `bytime=true limit=400` read-only on 29 October 2026; the counters were unchanged each time. The calls run under `timeout 10` where a `timeout` command exists. Listening to a single BSSID, never verified on the device and called by nothing, is no longer in the list. The self-test calls the function with a stub and shows that deauth, stopping and restarting recon, `RECON CLIENTS` (which does not exist), SSID pool commands, uploads, GPS, listening to a BSSID, extra arguments and injection attempts are refused **without** a call. | off (`STARCHORUS_APCLI_RO=1`); `STARCHORUS_SOURCE=pineap` switches `apcli_ro` on for itself; the channel line needs `STARCHORUS_TRAFFIC=1` only | no (read-only commands) |
| Source `pineap` (experimental) | `STARCHORUS_SOURCE=pineap` builds `starchorus.json` from these lists instead of from the database (opt-in only; `auto` never chooses it, and recon.db stays the default). When the AP service gives no usable answer, that cycle is built from the database. The security of each access point: on firmware 2.0 the beacon records carry an `encryption` bitmask, read from it directly; on firmware 1.x, or for an access point a beacon has not named, from the database path already described — one query at most once a minute while an access point is new to the cache (every 10 minutes for those the database does not know). The labels are kept in a small cache in RAM, `$STARCHORUS_TMPDIR/starchorus-sec.txt`: the BSSIDs of nearby access points with their security. The collector does not delete it when it exits; it goes with a reboot, or delete it by hand. The lists of BSSIDs that a lookup is made from (`starchorus-pineap-<pid>.*`) are deleted at the end of each cycle. If `STARCHORUS_TMPDIR` is not a writable directory no lookup is made and every access point reads `Unknown`. Nothing else is run. | off (`STARCHORUS_SOURCE=pineap`) | no |
| Alerts | with `STARCHORUS_ALERTS=1` the collector reads `alerts.log` in `STARCHORUS_ALERT_DIR` (default `/root/loot/starchorus-alerts`, a directory of its own outside the one the page server serves) when that name is a readable regular file with something in it (a directory or a pipe is read as no file): the last 256 KiB through a snapshot in RAM (mode 600, removed after the cycle), as untrusted text, of which only a digit epoch, `deauth` and an access point address are kept. It writes `alerts[]` into `starchorus.json`: per access point the address, how many reports and the newest time, at most 20, for `STARCHORUS_ALERT_WINDOW` seconds (default 600). The file is written by the companion `alert-deauth.sh`, which the owner puts into the firmware's alert tree, by hand or with the Settings row 'Alerts' (next row): the firmware runs it for each of its own deauth/disassoc alerts, with the event in environment variables, and it appends one line (the time and four addresses; the message text is not written) under `flock`, keeps the last 2,000 lines, and runs no command but `date`, `printf`, `tr`, `wc`, `tail`, `mv`, `mkdir`, `rm` and `flock`. It calls no display, sound, LED or vibration command, receives and sends nothing, and the passivity check reads it with the other shell files of the payload directory. The log holds addresses of other people's equipment and stays on the device (mode 600, in a directory that no page server of the payload serves); the source and destination addresses reach no document, and the counts on the page stay local and live (P6). The page draws a ring and a legend row for an alerted access point, and the Overview one red line, from the document alone: nothing is sent, and no vibration, sound or LED is used | on (`STARCHORUS_ALERTS=0` ends it), and silent without the file; unmeasured on the device | no |
| Alerts: install and remove (Settings row 'Alerts') | on the owner's press, and only after a confirmation dialogue, the payload runs `mkdir -p`, `cp`, `chmod +x` and `mv`: it makes `/root/payloads/alerts/deauth_flood_detected/starchorus`, copies the `alert-deauth.sh` that sits beside the payload into it as `payload.sh.tmp`, makes that executable and renames it to `payload.sh` (so the firmware never finds half a script); a failed step removes the temporary file and the directory if it is empty. On an installed companion a press asks again and runs `rm -f` on that `payload.sh` (and the temporary file) and `rmdir` on that directory, which only removes it while it is empty; nothing else of the tree is touched, apart from a stale `DISABLED.starchorus` copy of ours, described below. This is the one place the payload writes outside its own directories. It toggles no switch of the firmware; an alert placed in the tree may run at once (not yet measured), and switching it off stays with the firmware's Alerts page. A copy that the firmware's switch has renamed to `DISABLED.starchorus` is looked for: the row then reads 'OFF (firmware)' and a press installs nothing over it, it only says to switch it on there; the removal of an installed companion takes such a stale copy of ours with it (`rm -f` on its `payload.sh`, `rmdir` on its directory, which only removes it while it is empty). Passivity is unchanged: the companion it installs is the file the previous row describes, which only appends times and addresses to a log and sends nothing; the payload gains no radio, network or controller command, and the plain paths (arguments, `STARCHORUS_PAYLOAD_PLAIN=1`) cannot reach the row. The row is locked while `STARCHORUS_ALERTS` is set in the environment to anything but 1 (the collector then ignores the log, so an installed companion would feed nothing), and the test hook `STARCHORUS_ALERT_TREE` (default `/root/payloads/alerts`) exists for the test suite | off until pressed | no |
| `center.max_age`, `center.interval`, `akm`/`cipher`/`auth` | pure **output** fields in `starchorus.json`, computed from existing values | always | no |

One collector runs per Pager, so that two loops never share the monitor interface or radio: starting
or stopping any instance stops every other collector loop on the device (`--once` and `--status`
runs are left alone), and each loop so stopped is logged on stderr with its pid and working
directory. `starchorus.json` is written atomically (temporary file, then `mv`) and lives in
`STARCHORUS_OUTDIR`; pidfiles live in `STARCHORUS_PIDDIR`. The on-device payload writes its
settings to `settings.conf` in the same directory. Where it starts a page server of route A (`uhttpd` or `python3`; the root launcher also BusyBox `httpd`), it also makes `www` in that directory, a directory of its own that holds two symbolic links, `index.html` and `starchorus.json`, with the relative targets `../index.html` and `../starchorus.json`, and writes nothing else below it. Run from a self-contained payload directory
(`tools/hak5-package.sh`), it also copies its bundled collector, page, Overview and netcat server
there once, on the first run, and never over a collector that is already installed. These are
local file writes; nothing is sent.

The recon database is read through a plain copy in RAM (`/tmp`, then `STARCHORUS_CAPDIR`), and the files of the database are looked at (`ls`) before and after
that copy: when size, modification time or the presence of a journal differ, the copy is made a second time after 0.2 s. On the copy paths nothing is locked or
written on the live database, and the second copy is the same read-only copy; the last-resort read of the original in place, described above, is unchanged. Beside the copy the collector keeps a small file with the error output of the one query
(`starchorus-recon-<pid>.db-err`, removed with the copy). With a window (`STARCHORUS_MAX_AGE`) the query cuts the rows of the window out once into a temporary table (`rwin`) that lives in the memory of the `sqlite3` process (`PRAGMA temp_store=MEMORY`) and in no file: `-readonly` accepts it and the copy is as it was after the pass (a reader that refuses the table is noticed by a marker row of the batch and asked again without it). What is published: a document only when it is whole (first line `{`, last line `}`, one `aps`
line); one that is cut short, one built from a copy that `sqlite3` reports as damaged, and one that cannot be written or renamed into place leave the
document published last as it was, are logged once per episode, and make `--once` exit 1.

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
  APIs and no navigation used as a command path; external URLs only in the font's licence header. The regression run adds a zero list for the ways the page could run text as code or reach out of itself
  (`eval(`, `new Function`, `Function(`, a string given to `setTimeout` or `setInterval`, `setAttribute('on…')`, `document.write`, `insertAdjacentHTML`, `.outerHTML =`, `srcdoc`, `javascript:`, an inline `on…=` attribute in a markup
  string, `import(`, `postMessage`, the word `eval` as any identifier (`window.eval(…)`, `(0, eval)(…)`), `createElement('script')`, `createContextualFragment`, and a bracket name such as `self["eval"]`): none stands in the page today, and a copy with one planted line per word has to be counted (as of 24 October 2026). It reads the text of the page, so a name put together at run time is not seen.
- The AP service's command words (command-line call, the service's environment variables, deauth,
  SSID pool, upload, GPS) appear only in `apcli_ro`, `apcli_stub` and `apcli_selftest`; the `pineap`
  source reaches the command line only through `apcli_ro`. The firmware's other active or outward
  commands are denied the same way, by name and by the prefixes `WIFI_PCAP_`, `OPENVPN_`,
  `WIREGUARD_`, `AUTOSSH_`, `DNSSPOOF_` and `PINEAPPLE_`.
- Which function a line belongs to, and with it which allowlist and which pinned line applies, is read from the file as a whole and not from a scan of its text. The collector, both
  Overview copies, both `payload.sh`, `starchorus-serve.sh` and everything under `library/` are each read from the first line to the last by one reader, and the function of a line, the function heads and the comment lines
  come from that reading: a function is a `name()` at the start of a line with nothing open and outside every other function, and a line inside a here-document body, a string, a comment or after a backslash that looks
  like `apcli_ro() {`, a closing brace or a comment starts, ends and hides nothing (a comment-looking line in a string is code, and a quote in it ends the string). A head that comes while another function is still open
  (a definition nested in a body, or a function above it whose closing brace is not at the start of a line) is named in the first row of the check, and neither it nor the lines after it belong to any function, so no
  allowlist reaches them. The body of a here-document with a bare delimiter is expanded when it runs, so a `$( )` or backtick expression in it is read like any command line; with two here-documents on a line, the line is bare
  if either delimiter is. A here-document body, bare or quoted, and a string that goes over several lines are text (a bare body with its expansions as code) up to the first function head at the start of one of their lines; from that head to the end the text is a script
  (the handler that `starchorus-serve.sh` writes for the `nc` listener is one), and the rows for built names and globs read it once more as code. A head in it is no
  function of the file: it gives no line a function and no allowlist a name. The part of a quoted body before its first head is text, and so is a script it writes out that holds no function head, which is a program text that is built and
  then run (below). A here-document delimiter that is not a plain name, bare or wholly in quotes ends a body at another line than the shell does (`<<e"x"` ends at `ex`), and the first row of the check names it. The allowlists are by
  name: a second function with the name of an allowed one may hold what the first may hold, as before, and the words of the allowed functions are reviewed, except for the five `_pineap` lines.
- `iw scan` appears only behind `STARCHORUS_ALLOW_ACTIVE=1` (the default of the switch is 0, and the guard stands on the line right after the head of `build_from_iwscan`; both are read from the code of a line, not from a comment, a string or a copy of
  the head in a here-document); no transmitting tool is called, and the
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
  empty. A glob in a for-list, in a case pattern or as an argument is no command word and is not read. **What these two rows do not read:** a glob that is only handed
  on as an argument (`ln -s /usr/bin/hc?tool x` and then `x ...`, `cp`: the `ln` itself is a pinned line now, below), a program text that is built and then run (`eval`, `sh -c`, a pipe into `sh`, an awk `system()`,
  `. file` are pinned places now, below, but what they run is not read; nor is the part of a script that a here-document with a quoted delimiter writes out which stands before its first function head, or a script with none) and a name made by a function the script defines. For those the static check says nothing more and the guarantee rests on review; the run-time witness reads back what
  was asked of the controller during the collector's own scan window only, so it cannot vouch for a scan that something else started outside one. The tool names
  themselves are still red outside the allowlist, wherever they stand in the text. The five `_pineap` lines of `apcli_ro` are pinned byte for byte, each once. Read-only reads of `/sys/class/bluetooth` are the one exception to 'by tool', since sysfs holds no tool.
  The list of names is what is known of BlueZ, the programs that the project had not named yet included (`mpris-proxy`, `hex2hcd`, `obexctl`, `bluetooth-player`, `btinfo`,
  `scotest`, `hcieventmask`); the device's own file listing (`tools/device-probe.sh`, V-13) has not been taken yet, and every name it adds becomes one more alternative.
- **Outward and state-changing programs** (as of 24 October 2026). The collector, both Overview copies, both `payload.sh`, the page server's script and everything under `library/` are read for their literal command words, with
  the reader that reads the device probe: the name the shell would find, behind `nice`, `exec`, `env`, `timeout`, `busybox`, `xargs` and the other wrapper words (also with a path, and with the options that take a word: `env -u NAME`,
  `sudo -u USER`, `exec -a NAME`), after a separator, a keyword, a redirection, in a `$( )`, a backtick expression and a case arm, in the body of a here-document with a bare delimiter, and with an escaped newline in the middle of a word
  joined. A comment, a string, an awk or `jq` program and the text of a here-document with a quoted delimiter are text, and a word in them is none. The row is red for a program that connects out, installs, configures or switches
  something (`curl`, `wget`, `ping`, `ssh`, `telnet`, `nc`, `socat`, `ftpput`, `rsync`, `nslookup`, `dig`, `ntpd`, `sendmail`, `mail`, `opkg`, `uci`, `wifi`, `service`, `ubus`, `sysctl`, `rfkill`, `nft`, `iptables`, `modprobe`,
  `reboot`, `pkill`, the other ssh client `dbclient`, the Wake-on-LAN sender `ether-wake`, `whois`, `openssl`, `host`, the MQTT clients, `fw3` and `fw4`, `mtd`, `sysupgrade`, `firstboot`, `fw_setenv`, `devmem`, `i2cset`, `mount`, `hwclock`, and as of 26 October 2026 BusyBox's other network applets (`nameif`, `zcip`, `pscan`, `udhcpd`, `ssl_client`, `inetd`), its flash writers, `mtr`, `fping`, `arp-scan`, `masscan`, `zmap`, the mDNS
  tools, `lftp`, the SNMP tools, `at`, `batch`, the modem tools and the page servers that are not route A's (`lighttpd`, `nginx`, `mini_httpd`, `thttpd`, `darkhttpd`), and the rest of its list in `OUT_WORDS`; the name alone
  decides, so `uci show` is red as well), for `ip`, `tc` and `bridge` with a verb that sets or changes or the beginning of one (`set`, `add`, `del`, `delete`, `flush`, `change`, `replace`, `append`, `prepend`, `disconnect`, `exec`, `restore`, and for `tc` also `qdisc`, `class`, `filter`; iproute2
  takes every unambiguous prefix, so `ip l s wlan1mon down`, `ip r d default`, `ip a a 192.0.2.1/24 dev wlan0` and `tc q a dev wlan0 root netem` are read as the verbs they can stand for, and `ip a` and `ip r` are red with them), for `iw` with any command but the ones that read
  (`iw` matches its commands whole, so the ones that read are listed: `info`, `link`, `scan`, `survey dump`, `station dump` or `get`, `reg get`, `wowlan show`, `event`, `features`, `commands`, `help`, `version`, `list`, `channels`, `get`, `mpath dump`; `scan` stands in the list because the row for the opt-in scan holds
  its one guarded line; `switch`, `offchannel`, `roc`, `ocb`, `auth`, `measurement`, `vendor`, `ap`, `cac`, `mpath new`, `mesh leave`, `wowlan enable`, `coalesce`, `reg reload` and a command that an expansion makes are red), for `date` with `-s`, `--set` or an operand of digits or from an expansion, for `logger -n`,
  `logread -r` and `iwinfo … scan`, for a word from an expansion where a verb or an option can stand (`ip link "$v" wlan0 down`: before a verb that reads for `ip` and `tc`, any operand of `route`, before a read option of `arp`, the command of `iwinfo`, before `--` for `logger` but its tag and priority, any but the count and the pattern for `logread`), for the BusyBox applets `iplink`, `ipaddr`, `iproute`, `iprule`, `ipneigh` and `iptunnel` as for `ip`, for `route add` or `del`, `arp -s` or `-d`, `hostname NAME`, `sed -i` and `truncate` on a path of `/sys`, and for the programs that change an interface or a radio by name (`macchanger`, `wl`, `nvram`, `wlanconfig`, `vconfig`, `ifenslave`, `batctl`, `tunctl`), for `ifconfig` given more than an interface, for a redirection, `tee`, `dd of=` or a copy into `/sys`, `/proc/sys`, `/dev/tcp`, `/dev/udp` or any device file other than `/dev/null`, `/dev/zero`, `/dev/full`, `/dev/stdout`, `/dev/stderr`, `/dev/tty` and
  `/dev/fd/N`, for a start script by its path, for a program of the list among the arguments of one that runs its operand (`flock FILE curl`, `start-stop-daemon -x curl`, `su -c`, `chpst`, `setuidgid`, `envuidgid`, `envdir`, `softlimit`) or behind `builtin`, and for a name that is not spelled in one piece on its line (`hci\` and
  `tool -i hci0 lescan` on two lines: the text rows read each line alone). `iw dev wlan0 info`, `iw dev wlan0 survey dump`, `ip link show` and `ifconfig wlan0` read and stay green. Six lines of the collector stand in the row: the monitor
  interface that it makes and removes itself (`iw phy ... interface add ... type monitor`, the three `ip link set ... up` and the `ifconfig ... up` that follow it, and `iw dev ... del` when it ends; see
  [docs/device-notes.md](docs/device-notes.md)). They are pinned byte for byte, each once, with their file and function; an edited, a copied and a vanished one are red, as are fewer than six pins. The listener runs `"$NC"`, a name that is built
  when the line runs, which is the row for built names and no `nc` for this one. **Not read:** a path that an expansion makes (`> "$SYSFS/flags"`), a program whose name is in no list (the list names programs; it is not an allowlist of what the scope may run), a path reached through a symbolic link or a `cd`, a program that has been copied to
  a name of its own and then run, the text of an awk program or a `sh -c` string, and what a program does with its arguments. The action of a `trap`, a plain name or one string on a line, is read as code (up to three traps deep), so a `curl` in it is red.
- **Program-text sinks** (as of 24 October 2026). Every place where the shipped scripts make or take a program text and run it is a pinned line, byte for byte with its file and function, each once: `eval`, `ln`, `xargs`, `.` and
  `source`, a shell with `-c` (also in a cluster of options), one that has no file to run (after a pipe, with `-s` and its operands, which are positional parameters, with the argument of `-o`, with a here-document) and one that is given a file (`sh /tmp/x`: the text is in the file, which the script may have written; `"$0"`, the script itself, is
  the one exception), `find` with `-exec`, `-execdir`, `-ok` or `-okdir`, `su`, `runuser` and `script` with `-c` (also glued, `--command` in any spelling, `--session-command`), `flock -c`, `watch` and `run-parts`, an interpreter (`python`, `perl`, `lua`, `ruby`, `php`, `node`) with `-c`, `-e` or `-E`, with no script (`printf x | python3`, `python3 -`) or given a script file, `awk -f FILE`, an `exec` whose command word is built,
  an awk command pipe (`"cmd" | getline`, `print x | "cmd"`), the awk function `system(`, the dot commands of the sqlite3 shell that run a program (`.shell`, `.system`), `tcpdump -z`, the options of `tar` that run a program, a program of this list behind a program that runs its operand (`flock FILE sh -c …`, `chroot DIR python3 -c …`),
  a command run by a path outside the system directories (`/tmp/x`, `./x`), and a `trap` whose action is not a plain name or one string. Thirty-three lines stand in 0.2.6: nine `eval` (the Overview's four, its library copy's four, one in the collector's self-test), nine `sh -c` stand-ins in the self-test, the five `sh` lines of the self-test that start
  the stand-in scripts it wrote, the two `ln -sf` of the payloads that link the page and the capture into `www`, the three lines of the payloads that call the collector as `./starchorus-collect.sh`, the `python3 -c` of the collector's JSON test, and the four of the Bluetooth self-test (a `python3 -I -c` that binds a socket and three `ln -s` of its stand-in `/proc` tree). A new one, a changed one and a vanished one are red until someone has read it. **A pinned `eval` is read, not proven safe:** the Overview's four put a record of the document into a variable
  name, which rests on the framing of the records and on the canary rows of the regression run; the pin forces a review and proves nothing about what the line runs. The row does not read the text itself (what a pinned line runs, what a file holds that a pinned `sh FILE` runs), an awk pipe into a command held in a variable that is no `getline` (`print x | c`), a sed program that runs a command (GNU sed `e`),
  or a sink in the text of a here-document with a quoted delimiter (the self-test's stand-ins are such texts; a script that a text writes out is read as code from its first function head on, which the page server's handler now has at its top).
- The directory a route-A page server is given (row `§14.6f`). On a line that names a page server (`uhttpd`, `httpd`, `http.server`, `python`) and is not a message, every docroot argument (`-h`, `--directory`, python's `-d`, their glued,
  clustered and abbreviated spellings) has to be exactly `"$STARCHORUS_DIR/www"`, whatever it names (`-h /root`, `-h "$d"` and `-h .` are red); on other lines an argument that names `STARCHORUS_DIR` has to be that. A launch that gives its server no
  docroot option at all (`python3 -m http.server 9999` after a `cd`, `uhttpd -c FILE`) serves the current directory or what a file says, and is red; so is one whose only docroot option stands in a trailing comment (`uhttpd -f -p 1 # -h "$STARCHORUS_DIR/www"`), one that python is given with `-m` in a cluster of
  options (`-Im`) or glued to its module, and one that runs behind a program that runs its operand (`flock FILE uhttpd`, `start-stop-daemon -x /usr/sbin/uhttpd`, `chroot`, `su -c`, and the others of the list). The option is looked for in each simple command on its own (as of 24 October 2026): a docroot on one
  command of a line clears no other launch on it (`uhttpd -h "$STARCHORUS_DIR/www" & uhttpd -p 2` is red), and a brace group or a backtick expression ends a command as a separator does. It does not read a directory that a configuration file overrides, a page server other than the three under a name that no list holds (`lighttpd`, `nginx`, `mini_httpd`, `thttpd` and `darkhttpd` are red by name on row `§14.6g`), a server started
  from a built program text or by a built name (those are the rows above), or what the server does with the directory.
- Every `sqlite3` call outside the self-test carries `-readonly`.
- `tools/device-probe.sh`, the one file of `tools/` that runs on the device (it is piped into a device shell over ssh and reads, and sends and changes nothing), is in the scope of the check with three rows
  of its own. It is read with the same denylists as the files above and, besides, for the network, capture, package and service tools (`curl`, `wget`, `nc`, `ssh`, `uci`, `opkg`, `tcpdump`, `reboot` and the rest of `PNET_WORDS`).
  The allowlists of the other files (`SEC6_FUNCS`, `BT_FUNCS` and every pin) do not apply to it, and none of its own applies to them. What the probe deliberately names or runs is a pinned line, byte for byte with its
  function and each once: a presence test by tool name, a read-only `iw` dump (`iw dev`, `iw dev X info`, `iw dev X survey dump`, `iw phy X info`), the one `sqlite3 -readonly` open on a copy inside its private directory, a version text,
  the copies of the recon database, the lock (`flock -x 9`, taken once, in a subshell whose descriptor 9 is opened on a file of its private directory), the signals it sends to its own background jobs and the removal of its own
  temp directory, the self-tests of the installed Starchorus, and every line that uses `date`, `sed` or `sort` (each can set the clock or write a file by an option of its own: `-s`, `-i`, `-o`; the next line of a command that goes on
  over a backslash is pinned with it). Every command it starts is a function of its own (a program named after `command` is never one), a builtin, a plain read command from a short list or one of those pinned lines; any other name,
  a path or a `.` is red, and so is a pin whose line has changed or gone. The probe is read whole, by one reader, and what counts as one of its functions, as a function head (which gives a pinned line its function) and as a comment comes from that reading, not from a scan of the text: a line in a here-document body, a string or a comment that looks like `name() { :; }`, a head, a closing brace or a comment defines, starts, ends and hides nothing. A function is a `name()` at the start of a line with nothing open, and one named like a listed program is red wherever it stands. A `trap` runs its action as a command when the signal comes and the check reads no string, so the action is accepted only as `-`, an empty string, a function of
  the probe or `exit N`; a here-document only with a delimiter that is a plain name, bare or wholly in quotes (the shell removes the quotes of the whole word: `<<wait"x"` ends at `waitx`), and, when the delimiter is bare, with a body that
  has no `$(` and no backtick (such a body is expanded when it runs; a line with two here-documents is bare if either delimiter is). It writes nowhere but its private directory, and that is read on the whole file, not on one section: every redirection (`>`, `>>`, `2>`, `9>`) and every
  destination of `cp`, `mv` and `tee` is `/dev/null` or a file below `$T` whose name holds no expansion (`$T/$1` is whatever the caller hands over); the variables that stand for such a file (`T`, `OUT`, `A`, `B`) are only ever set
  to one; the three lines that write through a variable (the output file of `run_limited`, the `mktemp -d` that makes `$T`, and `vset`, whose file is named by the number of the verification, so every call of `vset` has to give digits)
  are pinned. Like the other scripts it is not read for a program text that is built and then run, or for what an awk or sed program does with its text; that rests on review.
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
| `starchorus.notes.v1` | alias (≤ 24 characters), note (≤ 120), up to 4 tags (≤ 12) per **observed key** (AP or station) | **≤ 200 entries**; control characters are removed (see the note below) |

Text that comes from the air or from a file (SSIDs, security texts, source and centre labels, aliases, notes, tags) goes through one function of the page before it is shown or stored. It removes the control
characters below U+0020 and U+007F, the C1 controls (U+0080 to U+009F), the zero-width characters and direction marks (U+200B to U+200F), the embeddings and overrides (U+202A to U+202E:
U+202E would make what follows it read backwards, so that a network could be drawn under another name), the invisible operators and isolates (U+2060 to U+2069) and U+FEFF; the range
U+2060 to U+2069 also takes U+2065, which no character uses. All of it is still escaped on display, and the text is cut to its length limit after the removal. A network name that
lost characters this way is marked: its tooltip and its detail sheet read `invisible characters removed`, and the observations count such names under Look-alike, so that a name
which resembles another only because of what was removed can be told from it by the mark and by its BSSID. U+200C and U+200D (the joiners) fall under the range, so an emoji
sequence or a Persian or Indic name with a joiner is drawn as its parts, with the same mark. As of 24 October 2026 the removal is checked in the page's DOM text (tooltip and
detail sheet) in headless Chrome, as of 26 October 2026 the marks too; no other browser was tried. The collector's own handling of such characters is not part of this note.

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
- A CSV cell that is text and starts with `=`, `+`, `-`, `@`, a tab or a carriage return is written with a leading apostrophe, so that a spreadsheet
  does not run a network name or a probed name as a formula; a number stays a number.
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
  device itself; the other page servers are the device's own programs (`uhttpd` or `python3`, started by the payload;
  BusyBox `httpd` by the root launcher). Those are given `/root/loot/starchorus/www`, a directory of their own that holds
  two symbolic links and nothing else, `index.html -> ../index.html` and `starchorus.json -> ../starchorus.json`, so that to
  whoever the bind setting lets in they show the page and the capture and not `settings.conf`, the pid files, the logs,
  `homing.target` or, when `/tmp` has no room for the collector's working copy, `cap/recon_copy.db`, a copy of the device's
  recon database with every address and network name it has recorded. Before 0.2.5 they were given the whole of
  `/root/loot/starchorus`. The payload uses `www` only when it is a plain directory (not a symbolic link) that holds nothing but
  those two links, and makes the directory and the links itself. If `www` is a symbolic link or a file, holds any other entry
  (a dot file too), holds `index.html` or `starchorus.json` as anything but a link, or the links cannot be made, it fails
  closed: route A is not used, and in the payload of the library the netcat server takes over where it and `nc` are there; otherwise no page server starts
  (the collector goes on, and one note on stderr names `www`); the root launcher has no netcat branch, so it starts none. Neither serves the whole directory in any branch. A `uhttpd` of an
  earlier build (it detaches itself and survives a payload update) is still found by its port and its directory, `www` or the
  whole of it, and stopped by `stop` in both launchers and, in the payload of the library, by the next Start as well. A server that does not follow the links would answer 404 for the page;
  it cannot serve more than those two names. **Not measured on the device (as of 23 October 2026):** whether the Pager's `uhttpd`
  follows symbolic links or lists a directory, and whether its BusyBox `ln -s` makes the links as the test machine's does; the
  Pager after the system update of 13 October 2026 has neither `uhttpd` nor `python3`, so route C is the normal server there and none of
  this runs on it. The netcat server answers only `GET` and `HEAD` on `/`, `/index.html` and `/starchorus.json`, everything
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

### The installer and the release files

`tools/install.sh` runs on the development machine and sends the remote commands its header lists, and no other: `mkdir -p`, the collector's read-only `--status`, `chmod`, one
`mv -f <name>.new <name> && ...` command that moves the uploaded files into place, `cksum`, the two `--selftest` runs, one passive `--once`, `head -c 400` of `starchorus.json` and the Overview's
`--once summary`. The status read and the rename were added in 0.2.5 by the owner's decision (24 October 2026); `tools/regress.d/installer.sh` pins the list, the order of every run and the
shape of the uploads (to `<name>.new` first, so that a dropped connection leaves no truncated script at a path that is run). Nothing the installer sends transmits over the air, changes a radio or the
controller, or stops a service. It refuses to start when the files it would install carry different versions.

`tools/release.sh OUTDIR` builds the Pager archive and `SHA256SUMS` (the archive, then every file inside it) so that the same sources and commit give the same bytes on the same machine (another zlib may compress differently; the files' sums are the same): owner and group `root`, one time
on every entry (the commit time of HEAD), sorted names, no name of the maintainer. A downloader unpacks the archive next to `SHA256SUMS` and runs `shasum -a 256 -c SHA256SUMS`
(INSTALL.md). The sums show that the files are the ones that were published; they are not a signature. Whoever can change the archive on the page it is served from can change
`SHA256SUMS` beside it, so the sums are worth most when the line for the archive is also read from a second place (the release notes). Nothing is signed.

## 6. Reporting security concerns

Please report a vulnerability, or anything that would let Starchorus transmit, **privately**:
on the repository's **Security** tab choose **'Report a vulnerability'**
(<https://github.com/starchorus/pager/security/advisories/new>). Only the maintainer sees the
report, and the matter is settled before it is made public.

General questions about security or passivity may go in an issue with the 'Question or contact'
form; a reproducible fault that is not a vulnerability, with the 'Bug report' form. Issues are
public. In neither place include real SSIDs, MAC addresses or capture files.
