# Starchorus

## Description

Starchorus is a strictly passive, receive-only Wi-Fi observation tool. It reads what is on the air
anyway and draws the radio environment from it: access points are stars, their clients orbit them
as satellites, and the distance from the centre follows the signal strength. It never transmits: no
deauth, no rogue AP, no injection, no association, no active scan.

This payload is for the Hak5 WiFi Pineapple Pager. It starts the passive collector on the Pager,
serves the page on a local port (with the netcat server it carries, or with `uhttpd` or `python3`
where the Pager has them), and opens the Overview on the Pager's display.

Starchorus is an independent project, not affiliated with, sponsored or endorsed by Hak5. Hak5,
WiFi Pineapple and WiFi Pineapple Pager are trademarks of Hak5 LLC.

## Features

- Passive collector (`starchorus-collect.sh`): reads the device's recon database from a copy with
  `sqlite3 -readonly` (or receives in monitor mode) and writes `starchorus.json` atomically every
  `STARCHORUS_INTERVAL` seconds. One collector runs per Pager, so that two loops never share the
  monitor interface or radio: starting or stopping any instance stops every other collector loop on
  the device, and each loop so stopped is named in the collector's LOG with its pid and directory.
  Two settings, both off by default, add to what it reads: 'Traffic' (channel activity from the AP
  service and the frame counts of stations) and 'Bluetooth' (a scan of 5 s per refresh). Bluetooth:
  passive LE scan only: by the Bluetooth specification a passive scan sends no scan request, it listens for advertisements that devices
  broadcast anyway (this project measures the host side of it: [SECURITY.md](SECURITY.md)).
- Page (`starchorus.html`, `index.html` on the device): a single, self-contained HTML file on port
  8199; it fetches only `starchorus.json` and sends nothing.
- Overview (`starchorus-display.sh`): eight screens on the device's display (summary, strongest
  networks, bands and security, devices and merges, probe requests, stations, Bluetooth, air quality),
  opened from the menu or after 'Start'. It starts its wait for a key before it draws a screen and keeps one open
  while it draws, so a press made while it reads is kept, and it never redraws by itself: key A draws the screen again, key B goes up
  one level, and Left and Right step through the screens. It starts and stops nothing, and its only
  output is LOG lines.
- Alert companion (`alert-deauth.sh`, optional): when the firmware's alert engine reports many deauth/disassoc frames heard for an
  access point, this file, put into the firmware's alert tree, appends one line of time and addresses to `alerts.log`, and the collector
  shows the last ten minutes of it on the page (see Alerts). It is not a payload of its own, sends nothing, and calls no display, sound,
  LED or vibration command.
- The payload's menu on the device shows its state in the title, 'Starchorus: Stopped' or
  'Starchorus: Running', and offers only what makes sense in that state (see Operation). Every
  menu setting has a command-line equivalent (`payload.sh set`).
- The payload reads a one-hour window of the recon record (`STARCHORUS_MAX_AGE=3600`) and writes
  every 30 seconds; within the window, the page dims entries by their freshness.

## Requirements

- The device with its recon service running; the collector reads the service's database read-only.
- `sqlite3` for the collector and `jq` for the Overview, both present on the device. The device's
  `jq` is built without a regex library; the Overview manages without regexes.
- The collector, page, Overview and netcat server under `/root/loot/starchorus`, or next to
  `payload.sh` in a self-contained payload directory (see Installation).
- A page server on the device: the payload uses `uhttpd` or `python3` where the device has them,
  and otherwise the bundled netcat server `starchorus-serve.sh`. A Pager that has had its system
  update has neither `uhttpd` nor `python3`, so the netcat server is the normal case there; it
  answers one request at a time, which suits one browser. Without any server, the collector still
  writes `starchorus.json`; the page then comes from a connected computer.

## Installation

Step-by-step instructions for macOS, Linux and Windows: [INSTALL.md](../../../../INSTALL.md) in the
repository.

Copy the collector, page, Overview and netcat server to `/root/loot/starchorus`, and this payload
directory to the device's payload directory (`<device>` is the device's address). These are six
files in all, counting the Overview's second copy beside the payload:

```sh
ssh root@<device> 'mkdir -p /root/loot/starchorus /root/payloads/user/reconnaissance/starchorus'
scp -O starchorus-collect.sh starchorus-display.sh starchorus-serve.sh root@<device>:/root/loot/starchorus/
scp -O starchorus.html root@<device>:/root/loot/starchorus/index.html
scp -O library/user/reconnaissance/starchorus/payload.sh library/user/reconnaissance/starchorus/starchorus-display.sh root@<device>:/root/payloads/user/reconnaissance/starchorus/
ssh root@<device> 'chmod +x /root/loot/starchorus/*.sh /root/payloads/user/reconnaissance/starchorus/*.sh'
```

Starchorus then appears in the device's payload menu under 'Reconnaissance'. From the repository,
`sh tools/install.sh` makes this simpler: it copies the same files, checks each one (the Pager has
no `cksum`, so it reads every file back and compares the bytes) and runs the self-tests on the
device (`--dry-run` only shows the commands; `--host` or `STARCHORUS_HOST` chooses the device).

The page is then available at `http://172.16.52.1:8199/`, over USB-C or the management Wi-Fi (see
[Network exposure](#network-exposure)).

### Upgrading

Stop Starchorus, then replace all six files, by the same route: `sh tools/install.sh`, or the `scp`
commands above, or, with the self-contained directory below, the new directory plus deleting
`/root/loot/starchorus/starchorus-collect.sh`. The payload compares the installed collector and
Overview with itself when it opens, by version and by `# Contract:` number, and says so when they
differ (see Operation), so a payload replaced on its own does not go unnoticed. The settings in
`settings.conf` are kept. The first start after an upgrade takes a little longer: the collector splits
the vendor (OUI) list into an index once.

### Self-contained payload directory

`sh tools/hak5-package.sh [OUTDIR]` builds the directory as Hak5's payload library expects it,
`OUTDIR/library/user/reconnaissance/starchorus/` (default `out/hak5/`): this `payload.sh`, the
collector, the page as `index.html`, the Overview, the netcat server, the companion alert `alert-deauth.sh` (see Alerts), a `README.md` written for
Hak5's library (its source is `packaging/hak5/README.md`) and `LICENSE`. Every file is a byte copy
of its source in this repository; tests, tools and other development files are not included. The
script runs on the development machine only and sends nothing.

Copied as a whole to `/root/payloads/user/reconnaissance/starchorus/`, that directory needs no
separate installation. On its first run the payload finds the collector and `index.html` beside
itself (in `$_PAYLOAD_HOME`, otherwise the directory of `payload.sh`) and, if
`/root/loot/starchorus` holds no collector yet, copies the four run-time files there and carries on
as usual; `starchorus.json` and `settings.conf` stay in `/root/loot/starchorus`. Each file is
written through a temporary file and a rename, the collector last, so an interrupted copy is
completed on the next run. A collector already present is never overwritten, which also leaves the
installation above untouched. To take a newer package, replace this directory, delete
`/root/loot/starchorus/starchorus-collect.sh` and start the payload again; the settings are kept.

### Alerts (optional)

The firmware tells a payload when it hears many deauth/disassoc frames for an access point (its alert `deauth_flood_detected`). `alert-deauth.sh`, beside
`payload.sh` in this directory, is the companion that records those reports for Starchorus. It is no payload of its own, which is why it is not called
`payload.sh`. The easy way is the Settings row 'Alerts': OFF while the companion is not in the firmware's alert tree, ON while it is. A press asks first ('Install the
alert companion?') and then makes `/root/payloads/alerts/deauth_flood_detected/starchorus`, copies `alert-deauth.sh` there as `payload.sh` (through a temporary file and a
rename, so that the firmware never finds half a script) and makes it executable; on an ON row a press asks 'Remove the alert companion?' and takes away that `payload.sh`
and the directory if it is empty, and nothing else of the tree, apart from a stale `DISABLED.starchorus` copy of ours. The row toggles no switch of the firmware; an alert placed in the tree may run at once (not yet measured), and switching it off stays
with the firmware's Alerts page. A copy that the firmware's switch has renamed to `DISABLED.starchorus` reads 'OFF (firmware)': a press installs nothing over it and says to switch it on there,
and Remove takes a stale copy of that kind away too. The row is locked while `STARCHORUS_ALERTS` is set in the environment to anything but 1 (the collector then ignores the alert log).
The same installation by hand is:

```sh
ssh root@<device> 'mkdir -p /root/payloads/alerts/deauth_flood_detected/starchorus'
scp -O alert-deauth.sh root@<device>:/root/payloads/alerts/deauth_flood_detected/starchorus/payload.sh
ssh root@<device> 'chmod +x /root/payloads/alerts/deauth_flood_detected/starchorus/payload.sh'
```

Either way, check on the firmware's Alerts page that it is listed and switched on: whether a copied alert needs the `chmod` and starts enabled has not been tried on a device
yet. For each report the file appends one line to `/root/loot/starchorus-alerts/alerts.log` (a directory of its own, outside the one the page server serves) (the time, `deauth`, and the access point, source, destination and client
addresses, tab separated, lower case, `-` where there is none), keeps the last 2,000 lines, and writes no message text. The collector shows the lines of the last
`STARCHORUS_ALERT_WINDOW` seconds on the page as 'many deauth/disassoc frames heard for this AP'. The report has no channel, no signal strength and no count of
frames, and its source address is usually not the sender's, so it is a hint and not a diagnosis; whether the Pager's own deauth frames would raise it is not known.
The repository's README and `docs/architecture.md` §14.6 say more; `docs/device-notes.md` §5c lists what has not been measured on the device.

## Operation

On the device, the payload shows a menu if it starts without arguments, the `LIST_PICKER` command is
present and `STARCHORUS_PAYLOAD_PLAIN` is not `1`. Nothing starts on its own: opening the payload
only shows the menu. The title says whether Starchorus is running, worked out afresh at every draw
from the processes themselves, so a reboot or a crash never leaves a false 'Running'.

| Menu | Rows |
|---|---|
| Starchorus: Stopped | 'Start', 'Settings' |
| Starchorus: Running | 'Overview', 'Open on Phone' (or 'Start Web Page' when the page is not up), 'Stop', 'Settings' |

- **Start** asks nothing. It starts the collector and, with 'Web Page: ON', the page server. If the
  collector does not come up within a few seconds, 'Could not start.' appears and the last line of
  `collect.log` is shown. Otherwise the 'Starting' spinner stays up until the first scan since 'Start'
  has been written (up to 20 seconds, and no longer once the collector has gone), and then the Overview
  opens on its summary. If the scan is late, it opens on 'Waiting for the first scan.', and key A looks
  again.
- **Overview** opens on the summary. It starts its wait for a key, with no time limit, before it draws and
  keeps one open while it draws, so a press made while 'Reading...' shows is kept and acted on in its turn: B, Left and Right end that
  draw at once, A, Up and Down let it finish, and an A pressed during a draw is answered by that draw; it never redraws by itself.
  Key A draws the screen again, key B goes up one level (a screen, then the list 'Overview', then this
  menu), and Left and Right step through the eight screens; Up and Down do nothing. The list offers
  'Summary', 'Strongest Networks', 'Bands & Security', 'Devices & Merges', 'Probe Requests', 'Stations',
  'Bluetooth' and 'Air Quality'. Each screen ends with the time of its scan ('Last scan 12:04:31 (42 s ago)') and the
  keys ('A: Refresh   B: Back'); 'Reading...' shows while a scan is read. A scan that takes `jq` more than
  20 seconds ends as 'This scan took over 20 s to read.' with the hint 'Try Settings > Show Last: 1 h.'.
  The summary's 'APs' line ends in 'BT 23' when the scan carries Bluetooth, and 'Bluetooth' lists the
  addresses heard in the last scan and the strongest few by company (a company id is what an advertiser
  puts in its manufacturer data, not necessarily who made the device); the figures are addresses, not
  devices, because random addresses dominate what is heard and they change from time to time. Without the
  Bluetooth setting it says 'No Bluetooth in this scan.' With the Traffic setting on, 'Bands & Security' adds
  to each band line that band's share of the frames heard ('act ######-- 78%', a relative figure) and a line
  that says what it is.
- **Open on Phone** shows the page's address as a QR code, with the address written under it (firmware
  1.1.1 or later; on an older firmware the address is shown as text). Without a network address it says
  'No network address.' and asks you to connect USB-C or Wi-Fi.
- **Stop** asks nothing. It stops the collector and the page server and waits until the collector
  has really ended.
- **Settings** holds 'Web Page', 'Refresh', 'Show Last', 'Vendor Names', 'Channel Load', 'Traffic',
  'Bluetooth', 'Alerts', 'Port' and 'Reset to Defaults'. 'Traffic' and 'Bluetooth' are OFF by default; switching one
  on says in the log what it adds ('Traffic: channel activity and frame rates.', 'Bluetooth: passive LE
  scan, 5 s per refresh.'). A row with ON or OFF flips with one press; 'Refresh' and 'Show Last' open a
  short list ('Show Last' also offers 'All (may be slow)'), 'Port' a number entry. Every change is
  saved at once. While Starchorus runs, 'Web Page' takes effect at once, and the other changes are
  applied when you leave Settings, without a question. Only 'Reset to Defaults' and 'Alerts' ask first
  ('Alerts' is ON while the companion alert payload is installed in the firmware's alert tree; a press
  asks, then installs it or, when it is ON, removes it: see Alerts (optional) below). A
  setting fixed by an environment variable shows '(locked)' and is not changed here.

Key B always goes back one level. On the main menu it leaves the payload; whatever runs keeps
running, and the log says so ('Still running.', and the page's address). B never stops anything.

The payload checks each pid it reads from a pidfile against the process it names: a pidfile on the
device's flash outlives a reboot, and its pid may by then belong to another program. Such a pidfile
is deleted, and nothing is signalled. If the installed collector or Overview differs from the payload
in version, or in the interface number of its `# Contract:` header, a dialogue says so once when the
payload opens ('Installed …, payload …' for another version, 'Installed files differ from the
payload.' for another contract); run `tools/install.sh` again (with the self-contained layout the
dialogue names the file to delete instead). Files without a `# Contract:` line, those of the first
release, count as contract 1.

Command line (without any on-device menu, on the device as well):

```sh
payload.sh                 # on the device the menu, otherwise start according to the settings
payload.sh start           # start according to the settings (the Overview opens only from the menu)
payload.sh stop            # stop the collector and the page server
payload.sh status          # status lines
payload.sh get [KEY]       # KEY=VALUE (env|file|default), one key or all
payload.sh set KEY VALUE   # check and store; exit 2 for an unknown key or an invalid value
payload.sh reset           # delete the settings file
```

## Configuration

Environment variables, all optional:

| Variable | Default | Meaning |
|---|---|---|
| `STARCHORUS_PORT` | `8199` | Port of the page server (not 80 or 1471). |
| `STARCHORUS_BIND` | `auto` | Address of the page server: `auto`, an IPv4 address or `all` (see [Network exposure](#network-exposure)). |
| `STARCHORUS_MAX_AGE` | `3600` | Only devices from the last N seconds (one hour); `0` = the whole record, `120` = live window. |
| `STARCHORUS_INTERVAL` | `30` | Seconds between two writes of `starchorus.json`. |
| `STARCHORUS_ALLOW_ACTIVE` | `0` | `1` permits the collector, as a last resort, the ACTIVE `iw scan` (sends probe requests); the page and the Overview then show the ACTIVE line. |
| `STARCHORUS_OWN` | `0` | `1` marks the device's own radios (interface MACs from sysfs). Environment only. |
| `STARCHORUS_DASHBOARD` | `1` | `0` keeps the Overview from opening after 'Start'. Environment only. |
| `STARCHORUS_BT_WINDOW` | `5` | Length of the Bluetooth window in whole seconds, 5 to 15; any other value is 5. Environment only; the payload passes it to the collector unchanged. |
| `STARCHORUS_ALERTS` | `1` | `0` = the collector never reads `alerts.log` (the companion alert's log, see Alerts); any value but `1` reads nothing and locks the Settings row 'Alerts'. Environment only; the payload passes it to the collector unchanged. |
| `STARCHORUS_ALERT_WINDOW` | `600` | How long a report from the firmware's alert counts, in whole seconds, 60 to 86400; any other value is 600. Environment only; the payload passes it to the collector unchanged. |
| `STARCHORUS_COLLECTOR` | `1` | `0` starts no collector; the menu then refuses to run, and `payload.sh start` serves the page alone. Environment only. |
| `STARCHORUS_DISPLAY_TEMPLATE` | – | a template line for the Overview's summary with `{aps}`, `{b24}`, `{b5}`, `{b6}`, `{open}`, `{crowding}`, `{gen}`; otherwise the first line of `/root/loot/starchorus/display.tpl`. |

**Settings file** `/root/loot/starchorus/settings.conf` (`$STARCHORUS_DIR/settings.conf`): the menu
and `payload.sh set` write it, and only the keys that were changed, as `KEY=VALUE` lines via a
temporary file and a rename. The payload reads it line by line and never executes it: only the keys
in the table count, every value is checked, and anything unknown or invalid is skipped (the default
then applies). Lines beginning with `#` are comments; a comment after a value makes the line
invalid. Precedence: environment variable, then file, then default. `tools/install.sh` does not
touch the file.

| Key | Default | Valid | Acts as |
|---|---|---|---|
| `window` | `3600` | `0` (the whole record) or `60`–`86400` | `STARCHORUS_MAX_AGE` |
| `interval` | `30` | `5`–`3600` | `STARCHORUS_INTERVAL` |
| `port` | `8199` | `1024`–`65535`, not `1471` | `STARCHORUS_PORT` |
| `bind` | `auto` | `auto`, `all` or an IPv4 address (not `0.0.0.0`; every interface is `all`) | `STARCHORUS_BIND`: the page server's address; command line only, no menu item |
| `vendor` | `on` | `on`, `off` | `STARCHORUS_VENDOR` (`1`/`0`): vendor name from the local OUI list ('Vendor Names') |
| `survey` | `off` | `on`, `off` | `STARCHORUS_SURVEY` (`1`/`0`): channel occupancy from the survey dump ('Channel Load') |
| `page` | `on` | `on`, `off` | payload only (`STARCHORUS_PAGE`): serve the page ('Web Page') |
| `bluetooth` | `off` | `on`, `off` | `STARCHORUS_BLUETOOTH` (`1`/`0`): the passive Bluetooth LE scan, 5 s per refresh ('Bluetooth') |
| `traffic` | `off` | `on`, `off` | `STARCHORUS_TRAFFIC` (`1`/`0`): channel activity from the AP service and the frame counts of stations ('Traffic') |

'Refresh' in the menu is `interval`, 'Show Last' is `window`, 'Traffic' is `traffic` and 'Bluetooth' is `bluetooth`.
The collector options only read.
`own`, `collector` and `dashboard` are no longer keys: a line for them in an older settings file is
skipped, and the environment variables above take their place. No key, no menu item and no command-line command reaches the
collector's active scan; that remains an environment variable alone (above).

Why a window: the recon record only grows. The device's CPU cannot turn the whole record into
`starchorus.json` on every pass; the collector and the Overview then fall behind, and the display
freezes. With one hour, the file and the pass stay small enough for the 30-second interval.
`STARCHORUS_MAX_AGE=0` still reads the whole record.

The installation directory and data path is `/root/loot/starchorus` (redirected with
`STARCHORUS_DIR` for tests); the collector writes `starchorus.json` there, and a self-contained
payload directory installs itself there on its first run. All other collector
variables are described in the 'Configuration' section of the repository's README.

To stop everything: 'Stop' in the menu or `payload.sh stop`.

### Network exposure

The page server listens on one address. With `bind=auto`, the default, that is the address of
`br-lan` (`172.16.52.1`), which covers USB-C and the management Wi-Fi. A network the Pager joins as
a client does not reach it, even though the stock firewall accepts input there. If `br-lan` has no
address, the server falls back to `172.16.52.1` where an interface has it, and otherwise to
`127.0.0.1` with a note; it never falls back to every interface.

`payload.sh set bind all` listens on every interface. The page and `starchorus.json`, with every
captured MAC address and SSID, are then open to anyone on any network the Pager is on. An explicit
address (`payload.sh set bind 172.16.52.1`) binds that address only. The netcat server can bind
one address only with an `nc` that offers `-s` (the Pager's GNU netcat does); with any other `nc`
it does not start unless `bind` is `all`. `payload.sh status` shows the address in use.
