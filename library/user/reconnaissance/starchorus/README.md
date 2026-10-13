# Starchorus

## Description

Starchorus is a strictly passive, receive-only Wi-Fi observation tool. It reads what is on the air
anyway and draws the radio environment from it: access points are stars, their clients orbit them
as satellites, and the distance from the centre follows the signal strength. It never transmits: no
deauth, no rogue AP, no injection, no association, no active scan.

This payload is for the Hak5 WiFi Pineapple Pager. It starts the passive collector on the Pager,
serves the page on a local port if a static web server is available, and opens the dashboard on the
Pager's display.

Starchorus is an independent project, not affiliated with, sponsored or endorsed by Hak5. Hak5,
WiFi Pineapple and WiFi Pineapple Pager are trademarks of Hak5 LLC.

## Features

- Passive collector (`starchorus-collect.sh`): reads the device's recon database from a copy with
  `sqlite3 -readonly` (or receives in monitor mode) and writes `starchorus.json` atomically every
  `STARCHORUS_INTERVAL` seconds. One collector runs per Pager, so that two loops never share the
  monitor interface or radio: starting or stopping any instance stops every other collector loop on
  the device, and each loop so stopped is named in the collector's LOG with its pid and directory.
- Page (`starchorus.html`, `index.html` on the device): a single, self-contained HTML file on port
  8199; it fetches only `starchorus.json` and sends nothing.
- Dashboard (`starchorus-display.sh`): seven screens on the device's display (summary, strongest
  networks, bands and security, devices and merges, probe requests, stations, air quality), plus a
  key menu for switching screens and for starting, stopping and querying the collector. Its only
  output is LOG lines.
- The payload's menu on the device: 'Start', 'Dashboard', 'Services', 'Options', 'Status', 'Stop',
  'Exit' (see Operation). Every menu setting has a command-line equivalent (`payload.sh set`).
- The payload reads a one-hour window of the recon record (`STARCHORUS_MAX_AGE=3600`) and writes
  every 30 seconds; within the window, the page dims entries by their freshness.

## Requirements

- The device with its recon service running; the collector reads the service's database read-only.
- `sqlite3` for the collector and `jq` for the dashboard, both present on the device. The device's
  `jq` is built without a regex library; the dashboard manages without regexes.
- The collector, page, dashboard and fallback server under `/root/loot/starchorus`, or next to
  `payload.sh` in a self-contained payload directory (see Installation).
- Optionally, a static web server to serve the page from the device: the payload uses `uhttpd`,
  otherwise `python3`, otherwise the bundled netcat fallback server `starchorus-serve.sh` (reliable
  only for `curl`, not for a browser). Without a server, the collector still writes
  `starchorus.json`; the page then comes from a connected computer.

## Installation

Step-by-step instructions for macOS, Linux and Windows: [INSTALL.md](../../../../INSTALL.md) in the
repository.

Copy the collector, page, dashboard and fallback server to `/root/loot/starchorus`, and this payload
directory to the device's payload directory (`<device>` is the device's address):

```sh
ssh root@<device> 'mkdir -p /root/loot/starchorus /root/payloads/user/reconnaissance/starchorus'
scp -O starchorus-collect.sh starchorus-display.sh starchorus-serve.sh root@<device>:/root/loot/starchorus/
scp -O starchorus.html root@<device>:/root/loot/starchorus/index.html
scp -O library/user/reconnaissance/starchorus/payload.sh library/user/reconnaissance/starchorus/starchorus-display.sh root@<device>:/root/payloads/user/reconnaissance/starchorus/
ssh root@<device> 'chmod +x /root/loot/starchorus/*.sh /root/payloads/user/reconnaissance/starchorus/*.sh'
```

Starchorus then appears in the device's payload menu under 'Reconnaissance'. From the repository,
`sh tools/install.sh` makes this simpler: it copies the same files, compares the checksums and runs
the self-tests on the device (`--dry-run` only shows the commands; `--host` or `STARCHORUS_HOST`
chooses the device).

With a server, the page is then available at `http://172.16.52.1:8199/`, over USB-C or the
management Wi-Fi (see [Network exposure](#network-exposure)).

### Self-contained payload directory

`sh tools/hak5-package.sh [OUTDIR]` builds the directory as Hak5's payload library expects it,
`OUTDIR/library/user/reconnaissance/starchorus/` (default `out/hak5/`): this `payload.sh`, the
collector, the page as `index.html`, the dashboard, the fallback server, a `README.md` written for
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
installation above untouched. To take a newer package, delete
`/root/loot/starchorus/starchorus-collect.sh` and start the payload again; the settings are kept.

## Operation

On the device, the payload shows a menu if it starts without arguments, the `LIST_PICKER` command is
present and `STARCHORUS_PAYLOAD_PLAIN` is not `1`. The device has no toggle widgets; every switch is
a selection list 'On'/'Off' with the current state preselected. The menu lines show the effective
value of each setting.

| Menu item | Effect |
|---|---|
| Start | asks first ('Start collector, web page?', naming only the services that are switched on), then restarts cleanly and afterwards opens the dashboard if 'Auto dash' is on. If both services are off, 'No service on' appears and nothing starts. |
| Dashboard | opens only the dashboard; starts and stops nothing. |
| Services | 'Collector' and 'Web page', each 'On'/'Off': what 'Start' starts. |
| Options | 'Window' (2 min, 10 min, 1 h, 6 h, All or a number of seconds), 'Interval' (10, 30, 60, 120 s or a number), 'Port', 'Vendor', 'Own radios', 'Survey', 'Auto dash', 'Defaults' (reset all settings, after confirmation). 'All' and a window above 21600 s take effect only after confirmation, because they can overload the device. |
| Status | state of the collector, of the page (`Page: 172.16.52.1:8199 running`, `not running` or `off`), window and interval. |
| Stop | stops the collector and the page server without asking (the same narrow path as `payload.sh stop`). |
| Exit | leaves the menu; running services keep running. |

Back (cancel) in a submenu leaves the setting unchanged; Back in the main menu ends the payload
without starting anything. An invalid number is rejected with an error dialogue. Status and the
menu lines show the stored values. If you change Window, Interval, Port, Vendor, Own radios or
Survey while the collector is running, the menu reports 'Applies on next Start': the new value takes
effect only at the next 'Start'.

Command line (without any on-device menu, on the device as well):

```sh
payload.sh                 # on the device the menu, otherwise start according to the settings
payload.sh start           # start according to the settings (the dashboard opens only from the menu)
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
| `STARCHORUS_ALLOW_ACTIVE` | `0` | `1` permits the collector, as a last resort, the ACTIVE `iw scan` (sends probe requests); the page and the dashboard then show the ACTIVE line. |
| `STARCHORUS_DISPLAY_TEMPLATE` | – | a template line for the dashboard's summary with `{aps}`, `{b24}`, `{b5}`, `{b6}`, `{open}`, `{crowding}`, `{gen}`; otherwise the first line of `/root/loot/starchorus/display.tpl`. |

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
| `vendor` | `on` | `on`, `off` | `STARCHORUS_VENDOR` (`1`/`0`): vendor name from the local OUI list |
| `own` | `off` | `on`, `off` | `STARCHORUS_OWN` (`1`/`0`): the device's own interface MACs from sysfs |
| `survey` | `off` | `on`, `off` | `STARCHORUS_SURVEY` (`1`/`0`): channel occupancy from the survey dump |
| `collector` | `on` | `on`, `off` | payload only (`STARCHORUS_COLLECTOR`): start the collector |
| `page` | `on` | `on`, `off` | payload only (`STARCHORUS_PAGE`): serve the page |
| `dashboard` | `on` | `on`, `off` | payload only (`STARCHORUS_DASHBOARD`): open the dashboard after 'Start' in the menu |

All three collector options only read. No key, no menu item and no command-line command reaches the
collector's active scan; that remains an environment variable alone (above).

Why a window: the recon record only grows. The device's CPU cannot turn the whole record into
`starchorus.json` on every pass; the collector and the dashboard then fall behind, and the display
freezes. With one hour, the file and the pass stay small enough for the 30-second interval.
`STARCHORUS_MAX_AGE=0` still reads the whole record.

The installation directory and data path is `/root/loot/starchorus` (redirected with
`STARCHORUS_DIR` for tests); the collector writes `starchorus.json` there, and a self-contained
payload directory installs itself there on its first run. All other collector
variables are described in the 'Configuration' section of the repository's README.

To stop everything: the 'Stop' menu item or `payload.sh stop`.

### Network exposure

The page server listens on one address. With `bind=auto`, the default, that is the address of
`br-lan` (`172.16.52.1`), which covers USB-C and the management Wi-Fi. A network the Pager joins as
a client does not reach it, even though the stock firewall accepts input there. If `br-lan` has no
address, the server falls back to `172.16.52.1` where an interface has it, and otherwise to
`127.0.0.1` with a note; it never falls back to every interface.

`payload.sh set bind all` listens on every interface. The page and `starchorus.json`, with every
captured MAC address and SSID, are then open to anyone on any network the Pager is on. An explicit
address (`payload.sh set bind 172.16.52.1`) binds that address only. The fallback server can bind
one address only with an `nc` that offers `-s` (the Pager's GNU netcat does); with any other `nc`
it does not start unless `bind` is `all`. Status shows the address in use.
