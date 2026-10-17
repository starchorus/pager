# Changelog

All notable changes to Starchorus are listed here, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 0.2.0 - unreleased

### Added

- The detail panel of an access point reads 'PMF: yes (derived)' for a network whose class guarantees Protected Management Frames (pure WPA3, OWE, and anything on 6 GHz, with the band read from the band or frequency and never from the channel number) and 'PMF: unknown' for every other. Like the PHY estimate, it is marked as derived, and the help spells PMF out.
- On a desktop the zoom and reset buttons also show in the 2D view, titled 'Zoom in [+]', 'Zoom out [−]' and 'Reset [0]' in both views; the four orbit arrows stay in 3D. On a desktop window 620 px high or less the 2D row is hidden, to keep the panels apart.
- Page query parameter `?demo=1` holds the built-in sample sky: the chip reads 'Sample' from the start and the page never asks for `starchorus.json`. `?poll=0` keeps its meaning.
- The passivity check also denies the firmware's other active or outward commands, by name and by prefix (`WIFI_PCAP_`, `OPENVPN_`, `WIREGUARD_`, `AUTOSSH_`, `DNSSPOOF_` and `PINEAPPLE_` among them), and the Bluetooth commands that transmit, by name (`hcitool` with `scan`, `inq`, `cc`, `lecc`, `leadv` or `cmd`, `l2ping`, `btmgmt`, `gatttool`, `bluetoothctl scan on`, and `hciconfig` with anything but `-a`). The one `hcitool` call it lets through is the literal `hcitool lescan --passive`, and its mutation probe plants one violation for every new alternative.

### Changed
- The masthead and the source panel keep their shape under a browser's minimum font size and a wide fallback face (as an in-car browser showed): the version and the cursor wrap under the name instead of leaving the box, the letters tighten first, the name keeps clear of the plot clock and the lamps, and the Load button wraps under the text instead of squeezing it.

- Probe requests are worded as named ones, because the collector drops wildcard probes at every source and the data cannot say that a station sent one. On the page, the tooltips, the detail panel and the cloud sheet read 'named probe: <SSID>', 'named probes: a, b' for several and 'no named probe heard' for a station without one; the SITREP text export counts them ('named probes 3') and still says 'free' or 'assoc ...' for a station without any. On the Overview, the Probes screen reads 'N client(s) with a named probe:' and then one line per network, 'named: <SSID>  (xN)', or 'No named probe heard.' when there is none, and the Stations screen reads 'named probe' where it used to read 'probing'.
- The 2D sky can be zoomed out to half its size. The rings stay centred on the device, and reset returns to full size.
- The page may grow to 620,000 bytes in 0.2 (it was 600,000), for the Scope and the radio pair.
- Documentation: the installation guide says that the Virtual Pager's terminal is the same shell as ssh, that Starchorus needs no packages and no Internet connection, what a firmware recovery, a factory reset and a system update do to `/root`, and what Hak5 advises for a long session; the README names the firmware that `LIST_PICKER` (1.0.8) and the QR dialogue of 'Open on Phone' (1.1.1) need.

### Fixed

- A label near the edge of the sky, on a phone or a desktop and in 2D or 3D, is moved inside it, 6 px from the edge, where it used to run off the screen; a label that cannot fit is dropped like one that collides with another, and so is the label of a star that is itself off the sky. `layoutInfo().labelsOutside` counts the boxes that still leave it, over the list of what was drawn. The cursor block of Wargames, the security glyphs and the dBm posts of the 3D rings are not moved and not counted.
- A security label that names both SAE and PSK, as one built from separate privacy and authentication columns can, counts as WPA3/WPA2 transition. It used to count as pure WPA3, and so would have read 'PMF: yes (derived)'; it now reads 'PMF: unknown'.
- On a desktop window shorter than the keyboard help, the help ran off the top of the window with no way to reach its first keys; it now stops 16 px below the top and scrolls inside itself.
- A zoom left over from 2D still decided, in the 3D view, whether a bubble showed its counter, and in 2D the zoom was counted twice in that test; it is now counted once, from the radius that is drawn.

## 0.1.1 - 2026-10-16

### Added

- Pager menu: 'Starchorus: Stopped' offers 'Start' and 'Settings', and 'Starchorus: Running' offers 'Overview', 'Open on Phone', 'Stop' and 'Settings', worked out afresh at every draw from the processes themselves.
- 'Open on Phone' shows the page's address as a QR code, and 'Start Web Page' takes its place while the page server is not up.
- Phone layout: the sky keeps the screen under a narrow status bar, and the controls move into a bottom sheet with three heights: a peek, half and full.
- On a phone held on its side, the status bar and the sheet form a column on the left, and every edge keeps clear of the device's safe areas.
- Hide panels (key U, at any screen size) leaves the sky alone with a small status pill that brings the panels back.
- Random clouds: free randomised addresses heard in one signal band, in bursts that recur at a steady period, are drawn as one cloud with its count, and its detail gives the period and lists the addresses. A period counts only when it stands clear of what unrelated bursts in that band would give by chance, so two devices of different periods at one signal are two clouds, and bands whose periods match are merged; a band is judged on its newest 1,500 bursts.
- A cloud whose bursts keep no one rhythm (a rhythm share below 0.6) is mixed: its detail reads 'no one rhythm' in place of a period, and the page words it 'possibly one or more nearby devices' where it would say 'probably one nearby device'.
- Random (key X, `?random=cloud|show|hide`) cycles between clouds, the addresses one by one, and hidden; the legend reads 'n randomised MAC · k in m clouds', and the randomised and cloud counts also appear in the statistics and the inventory.
- The Overview counts clouds by the same rule, capture by capture, in its summary ('Clients 247 free (245 random, 1 cloud)') and shows each one as a single line on the Stations screen.
- The Overview shows 'No new scan for …' in red, on every screen, when the collector has not written a capture for more than three of its intervals.
- A setting that an environment variable fixes shows '(locked)' in Settings, and its row opens a note instead of changing.
- Page query parameters `?phone=1|0`, `?panels=0|1` and `?random=cloud|show|hide`.
- The page's favicon is inline, so the page still fetches nothing but `starchorus.json`.
- The payload compares the version and the new `# Contract:` header of the installed collector and Overview with its own, and says so once in a dialogue when they differ.
- The collector's log says when the vendor cache grows and, once per episode, why a merge into it did not happen.
- The opt-in `STARCHORUS_SOURCE=pineap` reads the AP service's own recon list with one bounded read-only command, `RECON DEVICES` (with `STARCHORUS_PINEAP_CALLS=full`, `RECON APS` and `RECON DEVICES` unbounded); it is experimental and not cheaper on the Pager than the database path, which stays the default.
- New environment variables for the collector: `STARCHORUS_TMPDIR` (where the work copy of `recon.db` lives, `/tmp` by default), `STARCHORUS_SKIP_UNCHANGED` (`0` turns the skipping of unchanged cycles off) and `STARCHORUS_PINEAP_CALLS` (`recent` or `full`, for the `pineap` source only).
- The masthead shows the version in small type after the name, read from the page's one version line.

### Changed

- The Pager menu is shorter: 'Start' and 'Stop' ask nothing, and the rows Dashboard, Services, Options, Status and Exit are gone.
- Settings rows flip in place ('Web Page: ON'), a change made while Starchorus runs is applied when you leave Settings (except 'Web Page', which takes effect at once), and only 'Reset to Defaults' asks first.
- The 'Refresh' and 'Show Last' lists have no 'Other' row. They offer 10 s, 30 s, 1 min and 2 min, and 2 min, 10 min, 1 h, 6 h and 'All (may be slow)'; other values go through `payload.sh set`.
- Every menu title and row is in Title Case, as in the Pager's own settings.
- Own radios, opening the Overview after 'Start' and switching the collector off are no longer settings: they remain the environment variables `STARCHORUS_OWN`, `STARCHORUS_DASHBOARD` and `STARCHORUS_COLLECTOR`, and an old line for them in `settings.conf` is skipped.
- 'Start' keeps its spinner up until the first scan since that 'Start' has been written (up to 20 seconds) and then opens the Overview on its summary; key B in the Overview goes up one level, from a screen to the list of screens and from the list to the menu.
- The Overview's first line is 'Overview'. It starts its wait for a key, which has no time limit, before it draws a screen and keeps one open while it draws, so a press made during 'Reading...' is kept and key B does not fall through to the Pager's own UI then (measured on the Pager, 16 October 2026: with no wait open, a press is lost and B leaves the payload's view). A wait takes one key, so that key ends the draw (nothing more is printed and its `jq` is ended) and the next wait starts at once; a press that lands in the fraction of a second between one wait ending and the next being registered is still lost. It never redraws by itself: key A draws the screen again, key B goes up one level (a screen, then the list of the seven screens, then the menu), Left and Right step through the screens, and Up and Down are ignored. 'Reading...' shows while a scan is read, each screen ends with the time of its scan ('Last scan 12:04:31 (42 s ago)') and the keys ('A: Refresh   B: Back'), and it reads 'Waiting for the first scan.' until the first scan after 'Start'.
- The page turns 'Stale' when no new capture has come for twice the interval the file announces plus 15 seconds (at least 30 seconds), where it used to count six polls.
- The page says 'Offline' (WarGames 'Link down', Whitehall 'No link') where it said 'Stale' when the Pager has not answered the last three polls by then, as when a phone leaves its Wi-Fi; 'Stale' stays for a Pager that answers with an old capture.
- The page polls in step with the collector, shortly before the next capture is due and then every 2 seconds until it arrives, about three requests per 30-second capture where it made six.
- The replay banner counts captures, not polls, and the signal-over-time axis follows the observed spacing of the captures.
- The page keeps the history of a vanished station for 300 seconds of capture time instead of 60 polls, and an announced interval is capped at 600 seconds.
- The Random switch starts on 'clouds', so a busy sky shows fewer single dots than before.
- The CSV export gains a trailing `cloud` column. With clouds present, the JSON export gains a `clouds` array, a station in a cloud carries `cloud`, and `station_counts` adds `randomised` and `in_clouds`; the SITREP lists the stations outside clouds.
- The collector works on a copy of `recon.db` in RAM instead of on flash, and reads it with one `sqlite3` process per cycle instead of four to seven.
- The collector skips a cycle whose database has not changed since the last full pass, and republishes that pass with a new `generated`.
- A collector cycle takes 265 to 266 ticks of 10 ms of the Pager's CPU where 0.1.0 took 369 to 376, about 28 per cent less, measured one straight after the other on the same data (29 access points, about 299 stations, vendor cache warm).
- A new vendor prefix costs about half a second where it cost about 14 s, because the OUI file is split once by first octet and a lookup reads only the files it needs. The split is made when the collector first starts with the new version (about 8 to 10 s of CPU; 512 files, 2.2 MB, under `cap/oui-index` beside `starchorus.json`), so the first capture after an upgrade comes later than usual.
- The security label is decoded from the encryption bits in one walk that stops at the highest bit set, instead of a separate test for each possible bit.
- The Overview runs one `jq` process per screen and reuses the result while the capture is unchanged, so a screen costs CPU (1.8 s for the summary) only when it is drawn on a new capture, or again after a key has ended a draw at 'Reading...' (a cut draw keeps nothing) and nothing while the Overview waits for a key (0.1.0: 4.6 s every 4 s). A scan that takes `jq` more than 20 seconds to read ends as 'This scan took over 20 s to read.' with the hint 'Try Settings > Show Last: 1 h.'.
- The collector, the page server and the Overview, as the payload starts them, run at nice 19, so that the Pager's own services come first.
- The netcat page server sends the page with `Cache-Control: max-age=60` and `starchorus.json` with `no-store`, where both used to be `no-store`.
- `tools/install.sh` reads the six files back and compares them byte for byte, and no longer counts the Pager's missing `cksum` as a warning.
- Documentation: the netcat server is described as the normal page server on an updated Pager, and the Quick Start, the installation guide and the payload's READMEs go through the payload.
- Documentation: the notes on the device record the AP service's recon lists, the OUI file, and the last field of the beacon lines, which is Management Frame Protection and not encryption.

### Fixed

- 'Stop' waits until the collector has really ended, and ends its `sleep` between passes so that it does not wait for the next one.
- After a reboot, a pidfile whose process id now belongs to another program no longer shows a false 'Running' or receives a signal.
- Temporary files of a pass that was cut short (`starchorus.json.tmp.<pid>`) are removed at the next start.
- The netcat page server sends each answer from a copy of the file made in RAM, so the `Content-Length` matches the bytes even when the collector replaces `starchorus.json` meanwhile.
- A client that connects to the netcat page server and sends nothing no longer holds it: it is dropped after 15 seconds, a client that stalls in the request headers is answered after 10 (where the shell has `read -t`), and a whole request is ended after 60.
- The Overview no longer redraws itself every 4 seconds, a loop that listened for keys only between redraws and so could miss a press; it draws when asked, keeps a key wait open while it draws, so that a press during 'Reading...' is kept (measured on the Pager, 16 October 2026: a press made while no wait is open is lost) and ends the draw it comes in, and nothing else runs while it waits.
- The payload stops its spinner when it is ended while one shows, instead of leaving it on the display.
- The Overview no longer keeps the payload's output open: a payload that is ended while the Overview waits for a key lets go of its runner at once, and the Overview itself ends at its next key press.

### Removed

- The page's separate small-screen mode below 720 px, replaced by the phone layout.
- The Overview's own menu with its Summary, Collector and Exit rows.
- The unverified `monitor` command from the collector's list of read-only AP-service calls, which now holds `RECON APS` and `RECON DEVICES` only.

### Security

- The netcat page server no longer sends `Access-Control-Allow-Origin: *`, so a web page open in someone else's browser cannot read `starchorus.json` from the Pager, with every MAC address and SSID in it.
- The payload and the collector count a process id from a pidfile as theirs only while `/proc/PID/cmdline` still names what they started, so no foreign process is ever signalled.
- The transmit counters of the Pager's wireless interfaces stayed unchanged across the new code, the opt-in `pineap` source included.

### Upgrading

Stop Starchorus, then replace all six files: run `tools/install.sh`, or, with the Hak5 library copy, replace the payload directory and delete `/root/loot/starchorus/starchorus-collect.sh`, so that the payload copies its bundle again. The payload now compares the installed files' Contract with its own and says so in a dialogue when they differ, so a payload replaced on its own is noticed. Files from 0.1.0 carry no Contract line and count as contract 1. Your settings in `/root/loot/starchorus/settings.conf` are kept. Details: [INSTALL.md](INSTALL.md#7-stop-update-uninstall).

## 0.1.0 - 2026-10-13

### Added

- First release: the page, the passive collector, the Overview on the Pager's display, the payload with its menu, the netcat page server and the installer.
