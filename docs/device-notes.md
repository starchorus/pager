# Device notes

The device is the Hak5 WiFi Pineapple Pager (a trademark of Hak5 LLC; Starchorus is not
affiliated with Hak5). This is the developer reference for the facts **verified on the device** on which the collector, the Overview and the
payload rest. The details come from a read-only session on the device and from its unpacked
firmware image. Anything not yet verified on the device is marked as open (§2a, §2b, §5a, §5b, §7 and the list at the end of §6a);
`tools/device-probe.sh` answers these questions in a read-only session, as far as that is possible
without transmitting and without changing state.

> **Hard rule: strictly passive.** Starchorus only receives. It reads the device's recon database
> read-only, reads (opt-in) the AP service's read-only recon lists, listens (opt-in) to Bluetooth LE advertisements with a passive
> scan, or receives in monitor mode. It **never** transmits: no deauth/disassoc, no rogue or
> evil AP, no injection, no association, no active function of the AP service, no Bluetooth inquiry, active scan, advertising or
> connection, no jamming.
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
| `jq` | present, **without regex** | every Overview filter; built without Oniguruma, see §2a |
| `timeout` | present: `/usr/libexec/timeout-coreutils` (GNU coreutils; measured 17 October 2026, A2 in §2b). It forks: the command is its child with a pid of its own, and a TERM sent to `timeout` ends the child (a hand run of `timeout -s INT 10 hcitool lescan --passive --duplicates` on 16 October 2026 had ended with exit status 124, which a `timeout` that executes its program in its own process cannot return). Whether it passes INT on is still open. GNU `timeout` installs handlers of its own for INT, QUIT, HUP and TERM (the coreutils source; not measured here), so its command starts with those four signals at default whatever the caller had ignored: the collector's `trap '' HUP QUIT` around the two launches does not reach the tools on the device, and a SIGINT that reaches `hcitool` before it has installed its own handler ends it. The Bluetooth window therefore notes the pid of the tool itself, signals only the tool, and holds the first SIGINT of an abort back for a scan younger than a second | bounds the Overview's `jq` (`timeout 20`, where `timeout` exists), the collector's Bluetooth tools (§2b) and the AP service calls, and nothing else of the Overview's: never a key wait, never any other UI command, because killing the client of a UI command might leave its request pending in the UI service (M7 in §7 saw no such effect, on weak evidence) and the Overview needs no `timeout` for its work; the Overview ends a `jq` that a key has cut short together with the processes `timeout` started for it, because whether it passes INT on is not known; `tools/device-probe.sh` reports which implementation it is (`timeout.kind`) |
| `nice`, `setsid` | present (BusyBox) | the payload starts the collector (detached with `setsid`), the page server and the Overview at nice 19 |
| `nc` | present | **GNU netcat 0.7.1** (not BusyBox nc); carries the page server `starchorus-serve.sh`; offers `-s ADDRESS` (local address, §8) |
| `cksum` | missing | `ash: cksum: not found`, exit 127 (seen 11 October 2026, and in the installer runs of 14 and 15 October). `tools/install.sh` therefore verifies by reading all six files back with `scp` and comparing them with `cmp`, and reports that as a pass: a missing applet is a fact about the device, not a warning |
| `head -c` | present | `head -c 400` works, exit 0 (installer runs of 14 and 15 October 2026); the installer reads the first 400 bytes of `starchorus.json` with it and prints only `generated` and `source` |
| `stat` | missing | the collector reads the size and mtime of `recon.db` with one `ls -lnL --full-time` instead (§6a) |
| `crond` | present | BusyBox cron, one-minute tick (`starchorus-collect.sh --once`) |
| `start-stop-daemon` | present | detaches the netcat server cleanly from the payload run |
| `pgrep` | present (BusyBox), **no `-c`** (15 October 2026) | a count has to be taken as `pgrep -f PATTERN \| wc -l`, and that count includes the calling shell when its own command line holds the pattern |
| `airodump-ng` | missing | optional source; only after `opkg install -d mmc aircrack-ng` |
| `python3` | missing | no `python3 -m http.server`; absent after the system update of 13 October 2026 |
| `uhttpd` | missing since the system update of 13 October 2026 | it had been installed as `/usr/sbin/uhttpd`, not enabled at boot and not running by default; the payload uses it when it is present. It can be added as a local `.ipk`, see [display-paths.md](display-paths.md). The system update on the Pager removed it (same firmware 24.10.1, new SSH host keys, `/root` intact); the payload then fell back to the netcat server, which served a browser cleanly. On a Pager in that state the netcat server is the normal page server |
| BusyBox `httpd` | missing | applet not compiled in |
| `nginx`, `lighttpd`, `php` | missing | – |

Checked again on 14 and 15 October 2026, firmware as shipped, after the system update of 13 October:
`stat` is absent; `timeout`, `nice` and `setsid` are present; `python3` and `uhttpd` are absent;
`recon.db` has `journal_mode` `delete` (§4). The installer runs of those days found `cksum` absent and
`head -c` working, and read all six files back with `scp` to compare them byte for byte; all six were
identical.

**Consequence:** by default **no web server** runs for files of our own. The web interface on port
1471 serves only itself. Since the system update of 13 October 2026 the Pager has neither `uhttpd` nor
`python3`, so the payload serves the page with its own netcat server (`starchorus-serve.sh`, §7); where
`uhttpd` or `python3` is present, the payload starts it on its own port instead.

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
| `endswith`, `until`, `index`, slicing `.[a:b]`, `tostring` | **measured on the device** on 14 and 15 October 2026 (verification V-12): the Overview's self-test probes each one and passed. Standard builtins with no regex involvement. The Overview's filters use them. |

The error arises **at the call**, not at parse time: a regex call in a branch that is never taken
does no harm. As soon as it is evaluated, the **whole** jq program aborts. Because the Overview's jq
runner `fetch()` discards `stderr` (a screen should never show jq messages), such an abort would produce
no error message but **blank** counters, for example:

```
APs <n>   ·   2.4:  5:  6:          instead of   APs <n>   ·   2.4:<n>  5:<n>  6:<n>
No open/WEP networks                instead of   Open/WEP networks: <n>
```

**Rule for this repository:** in `starchorus-display.sh`, and in every other jq filter that runs on
the device, the regex family is **forbidden**, the self-test included. The replacements are the
string building blocks above, gathered in the `JQLIB` block (`bandnorm`, `secupper`, `isopenwep`,
`sectag` and others), which is placed in front of every screen's jq program. A builtin the filters
do not yet use needs a check on the device before it is used. The record helpers of `JQLIB` use
`try`: if one value fails, the others of the screen still arrive. The payload's start time
(`STARCHORUS_SINCE`) is a gate in front of a screen's program, so a program may follow a pipe with a
`def` of its own. Nothing else is new. Both forms ran on the device on 14 and 15 October 2026: the
self-test probes them (`syntax try`, `syntax def after a pipe`) and passed, and the marker would
show a jq that cannot compile `JQLIB`.

Three safeguards hold the rule:

1. **Regression rows on the development machine.** `tools/regress.d/jq-noregex.sh` checks both
   copies of `starchorus-display.sh` statically for regex calls, runs the complete Overview through
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
   `add`, `group_by`, `sort_by`; made once per run of the Overview, the result is kept), whether
   the building blocks work on this device. If they do not,
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

   It checks (a) every jq building block the filters use, one by one (among them the five that V-12
   had left open, the string building blocks, `group_by`, `sort_by` also with several keys, `unique`,
   `add`, `map`, `max`, `range`, `round`, `type`, `not`/`empty`, the `//` operator, `\uXXXX`
   escapes, string interpolation and `def` with `$` parameters), (b) `bandnorm`, `secupper`,
   `isopenwep` and `sectag` against a small fixed table and (c) the summary over an embedded mini
   fixture (dummy BSSIDs): band counters must be digits, and the Open/WEP line must match the
   fixture. The single `INFO:` line names the jq version and never changes the result. The self-test
   calls **no** regex builtin. Its output contains no environment data. If a building block fails,
   a `FAIL: jq builtin <name>` line names it, and the run ends with `SELFTEST: FAILED (k of N)` and
   exit 1. If `jq` is missing altogether, it reports `FAIL: jq present` and
   `SELFTEST: FAILED (1 of 1)` (exit 1).

   This one-liner checks only the five building blocks that V-12 had left open (answered on the device on 14 and 15 October 2026 by the self-test above):

   ```
   jq -n '["5 GHZ"|ascii_downcase|endswith("ghz"), ("ab"|until(length==1; .[:-1])), ([" "]|index(" ")), (5|tostring)]'
   # expected: [true,"a",0,"5"]
   ```

`starchorus-collect.sh` is **not** affected by the rule: its only jq call is the validity check
`jq -e .`; the `sub`/`gsub`/`match` occurrences there are `awk`, not jq.

---

### 2b. Bluetooth (V-13)

Read-only observations of the evening of 16 October 2026 and of the morning of 17 October 2026 (06:00 to 06:10), from the person at the device:
nothing was transmitted, and only counts left the device (the fixture of A1 is masked). They settle
what the device offers; they do **not** show that a window of the collector is passive (that is read back from the controller's own
traffic each cycle, and the device checks for it are listed at the end of this section).

| Topic | Value |
|---|---|
| BlueZ | 5.72, complete on the stock firmware: `hcitool`, `btmon`, `hciconfig`, `bluetoothctl`, `btmgmt`, `bluetoothd`, `gatttool`, `l2ping`. There is no `rfkill`. `bluetoothd` runs |
| Controller | `hci0`, **internal USB** on the SoC's EHCI (`btusb`, USB id `0e8d:7961`, 'Wireless_Device', MediaTek), HCI and LMP 5.2, UP RUNNING, link mode PERIPHERAL ACCEPT, class 0 |
| Shared chip | the controller is the **same combo chip as a Wi-Fi radio**, so Bluetooth and 2.4 GHz Wi-Fi share hardware: `wlan1mon` (`mt7921u`) sits on USB device 1-1.2, the device `hci0` is on (A15, measured 17 October 2026) |
| `hcitool lescan` | this build has `--passive`, `--duplicates`, `--privacy`, `--acceptlist` and `--discovery` |

**The passive route.**

- `hcitool lescan --passive --duplicates` works. A passive scan sends no scan requests. In the hand run the HCI transmit counter
  rose by 20 bytes in 3 commands (scan parameters, enable, disable: from the host to the controller, which is not radio
  transmission). `timeout -s INT` stopped it cleanly; afterwards `hciconfig` showed UP RUNNING with no scan flag, and no process was left.
  `hciconfig` has no LE scan state, so that last observation is no evidence that the scan ended (A3: the collector looks for the
  `Scanning: Disabled` block in `btmon`'s text instead).
- Plain `hcitool lescan` (without `--passive`) is an **active** scan and is forbidden here, as are classic inquiry (`hcitool scan`,
  `inq`), connections (`cc`, `lecc`, `l2ping`, `gatttool`), advertising (`leadv`), `bluetoothctl scan on` and `btmgmt`. The static check
  goes further than these verbs and denies every tool of the stack by name (`docs/architecture.md` §14.6).
- `btmon` alone starts no scan: it only decodes the HCI traffic that another scanner causes. The passive route is therefore
  `hcitool lescan --passive --duplicates` as the starter and `btmon` (text) as the reader. `btmon` gives, per advertising report, the
  event type (`ADV_IND` and the others), the address type (public or random, resolvable or not where it can be decoded), the address,
  the data length, the flags, the company id (`Company:`), service UUIDs, a name when the advertisement carries one, and the **RSSI**.
  `hcitool lescan`'s own output carries addresses only, no RSSI.

**What a window gives** (30 s on the owner's desk): 924 `hcitool` lines and 890 `btmon` advertising reports, all with an RSSI, 878
with a company id, none with a name, 20 distinct addresses; 854 reports used a random address and 36 a public one; no extended
advertising reports. Random addresses dominate (96 % of the reports), and resolvable private addresses rotate about every 15 minutes
on phones, so Bluetooth 'devices' are mostly clouds in the sense of the page's random-address clouds, and a device count would
mislead. The company id (manufacturer data) is the most stable visible attribute; it names who registered the data format, not
necessarily who made the device. Names are rare under a passive scan.

**Measured on 17 October 2026** (06:00 to 06:10, counts only; the assumptions are those of the table below):

- **A1, the text of `btmon -i hci0`.** The headers read `> HCI Event: LE Meta Event (0x3e) plen 29   #5 1.546345`: there is no `[hci0]` tag. A
  command line is prefixed by the process and its name is cut short (`hcitool[3550]: < HCI Command: LE Set Scan E.. (0x08|0x000c) plen 2`),
  so the witness keys on the parameter lines (`Type: Passive (0x00)`, `Scanning: Enabled (0x01)`, `Scanning: Disabled`), never on the command name.
  `Scanning: Enabled` (line 20 of the masked fixture) comes before the first report (line 26). The hex `Data:` lines reach 66 characters. In a 10-s window
  the event types were `ADV_IND` 233, `ADV_NONCONN_IND` 59 and `ADV_SCAN_IND` 41, no `SCAN_RSP`, no extended report; address types Random 297 and Public 36, of
  the random ones Resolvable 256 and Static 41. Both tools take `-i hci0` (the fixture's command lines are theirs). The head start, measured on 18 October 2026 in five runs: `btmon` writes its banner line
  (`Bluetooth monitor ver 5.72`) 0.08 to 0.14 s after its start and holds its monitor socket 0.51 to 0.56 s after it; the index and note lines come with the socket. Until
  that day the collector took the first line of the window file as 'ready', which would have started the scan before the monitor was attached and left the
  parameters block unrecorded (a void window, `nopassive`); it now waits for the socket or for a line other than the banner (self-test 15b keeps the case).
- **A2.** `timeout` is `/usr/libexec/timeout-coreutils` (see §2): the command is its child, a TERM to `timeout` ends the child. INT is forwarded too (18 October 2026: INT to `timeout` ended its `sleep` child and `timeout` itself).
- **A5.** Three `RECON CHANNELS` calls one second apart summed to 2424, 2064 and 2146 (2412 MHz: 1765, 1532, 1588): a sliding window, not a read that consumes
  what it returns.
- **A8.** The per-station `packets` deltas per 30 s over ten copies of the database (36 MACs, 271 changed rows): median 8 frames, 90th percentile 118,
  95th 138, maximum 169, so the 95th percentile is about 4.6 frames per second. The page's `GLOW.rateFull` is therefore 5 frames per second (it was 10 until
  this was measured).
- **A9.** 60 s of `btmon` without a scan of ours showed 0 host HCI commands, 0 events and 0 reports: `bluetoothd` runs no scan of its own, and the witness sees only ours.
- **A10, read in BlueZ 5.72 `monitor/packet.c`.** `print_eir` prints an advertised name with `memcpy(name, data, data_len)` and
  `print_field("Name (complete): %s", name)` (likewise `Name (short)`), with no sanitising: a line feed inside a name splits the printed line and a NUL ends it early. Only the hex
  dump (`isprint(...) ? buf[i] : '.'`) sanitises. A name is at most 29 bytes (31 of payload less two). It is not the only text the air writes:
  `print_manufacturer_apple` (company 76 or 19456, type 0x01) prints the bytes after its length byte with `snprintf(identifier, 99, "%s", data + 1)` and no bound to the
  advertisement, so it reads on into the RSSI byte and stale buffer bytes, and in a multi-report event a run the advertiser controls can reach about 36 bytes. So the
  rule is not 'no line the air writes is longer than 29 bytes'. The lines the parser acts on stay out of reach: the headers are over 40 bytes and `Event type` is at
  least 38; a forged `Address type` or `Address` line (35 and 34 bytes at least) can only drop the report of its own sender, by the order of the labels. The real
  10-s window had `Num reports: 1` only, so a multi-report event has not been seen. Decoded on 18 October 2026 with `btmon -r` on the device from a crafted btsnoop file (monitor format and H4, six reports in one event, `plen 223`): a 29-byte name makes a
  54-byte line (`        Name (complete): ` and the name), the longest line the air wrote; a line feed inside a name makes a second line that can match a field line byte
  for byte (`        Type: Passive (0x00)`, 28 bytes, the most a 29-byte name can place after its line feed); a carriage return and a tab pass through (the collector's
  `clean_ctrl` removes the one and the parser's `clip` turns the other into a space); a NUL ends a short name; a report whose length exceeds its data printed the bytes
  that followed and `btmon` went on. Run through the collector's grammar, every injected line was read inside the injecting report only, which was then dropped as
  suspect; the other reports, the witness and the window were untouched, `active` stayed 0, and a line at column 0 is no line of the grammar. Self-test window 12 keeps
  the case with the four injections that fit (`Type: Active`, `RSSI`, `Type: Passive`, a short `Event type`).
- **A11.** The five busiest MACs show steady deltas (for example 112, 89, 105, 115, 147, 142, 118, 122, 107): no alternation between 0 and double, so the firmware updates
  `packets` steadily and nothing aliases with a 30-s capture.
- **A12.** In five minutes of passive scan: 30 addresses, 6,004 reports (20 per second). The strongest report of each address: one in the −30s, two in the −40s, six in the −50s,
  eight in the −60s, five in the −70s, one in the −80s, one in the −90s, two below −100 and four with a non-negative reading, which is the invalid-RSSI marker and is
  dropped (the parser drops every report of 0 dBm or more). About nine in ten addresses are heard above −90 dBm. The scan's text held one `Scanning: Disabled` after
  the `Enabled`, and no process was left.
- **A15.** `wlan1mon` and `hci0` are on the same USB device, 1-1.2.
- **A16.** There is no `od` on the device, so a btsnoop fallback that decodes with `od` is out.

**Cost and coexistence.**

- CPU (ticks of 10 ms on the one core): `hcitool lescan` 10 ticks per 30 s (0.3 % of the core); `btmon` text decoding 169 ticks per 30 s
  (5.6 %); `btmon --write` (binary btsnoop) 176 ticks per 60 s, the file 108,100 bytes for 60 s.
- Coexistence, rx packets per second on `wlan1mon`. 30-s windows: 95 without a scan, 89 with the scan and `btmon`, 72 without again.
  60-s windows, about 20:45: 35 off, 31 with `hcitool` only, 27 off, 57 with `hcitool` and `btmon --write`, 62 off. The traffic of the
  surroundings moved by more (27 to 62 rx/s with no scan) than any effect of the scan, so there was no loss to see; the measurement
  cannot show that there is none either. It was taken on `wlan1mon`, which is the interface that shares the USB device with `hci0` (A15,
  17 October 2026), so it watched the right radio; its weakness is the drift of the surroundings, not the interface. The paired
  measurement of 18 October 2026 (§6a, the coexistence row) answers it as far as 30 pairs can: with the window on, `wlan1mon` heard
  20.7 frames per second against 20.7 without, a within-pair difference of −0.07/s where the pairs could have shown about 1/s; the
  round trip of the management link stayed at 1.2 ms. A loss of a few per cent would have shown; a smaller one would not. The layer stays
  off by default for its CPU cost (§6a), not for coexistence.

**What the collector does** (the design, `docs/architecture.md` §14.6 and `SECURITY.md`; measured on the device on 18 October 2026, §6a).
It is opt-in (`STARCHORUS_BLUETOOTH=1`, or Settings > Bluetooth). Each cycle it starts `btmon -i hci0` and, once `btmon` holds its
monitor socket, `hcitool -i hci0 lescan --passive --duplicates`, for a window of 6 s (`STARCHORUS_BT_WINDOW`, 5 to 15), each under
`timeout -s INT` as a dead-man timer and each tracked by two pids (the `timeout` wrapper and the tool). It ends the tools with SIGINT:
`hcitool` gets SIGINT repeatedly for at most 12 s and then at most one SIGTERM, never SIGKILL (it ends the scan only from its SIGINT
handler); `btmon` may be escalated. A stop in the middle of a window sends the first SIGINT to a scan younger than a second one second after its start, and a
collector killed with SIGKILL leaves its tools to their dead-man timers and to the next daemon start's sweep (SIGINT only). It calls no `hciconfig`, `btmgmt` or `bluetoothctl` and never changes the controller's state. A
window counts only when `btmon`'s text shows the collector's own `LE Set Scan Parameters` block with `Type: Passive (0x00)` before the
first report, the scan enabled, no `Type: Active` block, no extended scan command or report, and frame numbers that increase. A
missing `Scanning: Disabled` block is logged ('no scan disable was seen; the controller may still be scanning (passive); see
device-notes V-13'). Records are held for 120 s after their window.

**A scan left running.** If an `hcitool` dies between enabling the scan and its SIGINT handler (the device's `timeout` starts it with INT at default, so an INT
in that moment kills it), or has to be terminated, the controller may go on scanning (A4: not to be provoked on purpose). The collector shows it by the missing disable block and by the next window
failing to set its scan parameters; it logs both once per episode and points here. It never tries to recover the controller itself
(Starchorus never changes the controller's state). Recovery is the owner's: a reboot is the plain answer, and a controller reset by hand is another that has not been
tried here.

**Assumptions and the device check that settles each** (all read-only, run by the person at the device with approval per command;
only counts leave the device, apart from the masked fixture of A1):

| # | Assumption | Check | Status |
|---|---|---|---|
| A1 | `btmon` 5.72 prints the strings, header shape, indentation and field order the parser and the witness read (`Type: Passive (0x00)`, `Scanning: Enabled`/`Disabled`, `Event type: … - ADV_IND (0x00)`, `Address type:`, `Address: XX… (Resolvable)`, `Company: <name> (<id>)`, `RSSI: -61 dBm (0xc3)`); both tools accept `-i hci0`; how long `btmon` takes from exec to its monitor socket; whether it writes each packet to its file at once; the event-type histogram of a window (are scan responses reported?) | one window by hand into a RAM file; `grep -c` of each string and event type; the head start timed; the masked fixture of the collector's selftest comes from it | measured 17 and 18 October 2026: header shape and field order (the fixture); both tools take `-i hci0`; the banner after 0.08 to 0.14 s, the monitor socket after 0.51 to 0.56 s (five runs), so the collector waits for the socket or a line other than the banner |
| A2 | the device's `timeout` stays the parent of its command, and whether it forwards INT and TERM | `timeout 30 sleep 60 & p=$!`; `/proc/$p/cmdline` and the command name of `$p`'s child; `kill -TERM $p`; does the `sleep` survive? Then `kill` the `sleep` if it did. `tools/device-probe.sh` reports `timeout.kind` | measured 17 and 18 October 2026: coreutils `timeout`, the command is its child; TERM and INT to `timeout` both end the child |
| A3 | `hcitool` turns the scan off on SIGINT and `btmon` flushes its file on SIGINT | the window's file ends with an `LE Set Scan Enable` block with `Scanning: Disabled` after the `Enabled` one; `hciconfig` shows no LE scan state, so it is no evidence here | **open** (the five-minute hand scan's text had one `Disabled` after the `Enabled`; the collector's own window has not run) |
| A4 | a TERMed or KILLed `hcitool` leaves the controller scanning, and the next `lescan` fails to set its parameters | not to be provoked on purpose; the missing disable and the next window's failure show it | **open** |
| A5 | the `"0"` key of `RECON CHANNELS` holds frames of no known channel, the counts cover 20 to 30 s, and a call does not consume them | two calls one second apart | measured 17 October 2026 (a sliding window, nothing consumed); **open**: what the `"0"` key holds |
| A8 | per-station rates are mostly under 10 frames/s | the distribution of 30-s deltas of `packets` | measured 17 October 2026: 95th percentile about 4.6/s |
| A9 | `bluetoothd` runs no LE scan of its own that would make `lescan` fail or the witness void | 60 s of `btmon` without a scan of ours: no `LE Set Scan Enable` from the host | measured 17 October 2026: none |
| A10 | what the air can write into `btmon`'s text, and that names are not filtered | read `monitor/packet.c` of the BlueZ 5.72 source; decode a crafted btsnoop file offline with `btmon -r` | read 17 October 2026 (names unsanitised; the Apple decoder is unbounded); decoded 18 October 2026 on the device with `btmon -r`: a 29-byte name gives a 54-byte line, a line feed in a name gives a second line that can match a field line byte for byte, and the grammar drops only the injecting report (self-test window 12) |
| A11 | the firmware updates `packets` steadily | ten captures' counters of a few busy MACs | measured 17 October 2026: steady |
| A12 | most advertisers are heard above −90 dBm | the distribution of per-address maximum RSSI over five minutes, as counts per 10-dB bin | measured 17 October 2026: about nine in ten |
| A13 | when a network stops hiding, its newest type-8 row says so | one BSSID that stopped hiding: its type-8 rows before and after | **none seen**: 34 hidden BSSIDs have more than one beacon row, none has a newest row with `hidden = 0` (the collector still decides from the newest beacon row; on this data that changes nothing) |
| A15 | which Wi-Fi radio shares the combo chip with `hci0` | `readlink -f /sys/class/net/wlan*/device` against `readlink -f /sys/class/bluetooth/hci0/device`; `tools/device-probe.sh` section 9 makes the comparison from sysfs alone | measured 17 October 2026: `wlan1mon`, USB device 1-1.2 |
| A16 | the fallback route, `btmon --write` plus a decode with `od` and `awk`, is cheaper than text if ever needed | `command -v od` | measured 17 October 2026: no `od`; the fallback is out |

`tools/device-probe.sh` answers V-13 from files only (section 9): the entries of `/sys/class/bluetooth`, the USB descriptors of
`hci0`'s parent, whether each `wlan*` interface sits on the same USB device (A15), which BlueZ tools exist (`command -v`, nothing is run),
the count and the plain names of the BlueZ-looking files in `/usr/bin` and `/usr/libexec/bluetooth`, and counts of processes named
`bluetoothd`, `hcitool` and `btmon`. It calls no Bluetooth tool, `hciconfig` included, and starts no scan. Every further name it finds goes
into `BT_WORDS` of `tools/passivity-check.sh`. What a window shows (the scan parameters, the event types, the head start) it cannot
say; the devbench rows in §6a do.

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

Before every read the collector **copies** the database to `$STARCHORUS_TMPDIR/starchorus-recon-<pid>.db`
(`/tmp`, a tmpfs; together with `-wal`/`-shm`, if present), opens the copy with `sqlite3 -readonly` and
deletes it after the queries, so that it never locks the capture and writes nothing to flash. The AP
service's `journal_mode` is **`delete`** (measured on the device, 14 October 2026; an earlier note here said
`MEMORY`): there is a rollback journal beside the database while a write is in flight, no WAL, and a long
read on the live file would hold a SHARED lock that stalls the engine's commits. That is why the copy is
made, and why the `-journal` is deliberately not copied (a hot journal beside a read-only copy cannot be
rolled back). With less free space in `/tmp` than the copy needs (size, half as much again for sqlite's
temporary files, 2 MB), or when the copy fails, the old place `STARCHORUS_CAPDIR/recon_copy.db` is used,
and as a last resort the original file, likewise `-readonly`.

`build_from_recondb()` serves both schemas below and, in addition, an older `aps` table. All
alternatives (one per schema family) go into **one** `sqlite3` process per cycle, separated by marker
rows (`SELECT '#STARCHORUS_APS3#'`): sqlite3 carries on after a statement it cannot prepare, so the
alternatives that do not fit the firmware's columns fail quietly and the first non-empty one per group wins.
The no-`time` duplicates are asked only until the first batch has shown that `ssid` has a `time` column.

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
- **Frame counters** (`wifi_device`, read 16 October 2026): one row per device per recon session. `packets` is cumulative and
  **monotonic** within a session (a 30-s difference: 23 rows up, none down, no row at zero; the largest value seen 1,296,575). `time`
  is the last-seen time in epoch seconds and is updated live (24 s behind the clock when it was read). `scan(id, uuid, time, name)`
  has one row per boot (22 sessions), `time` in epoch seconds. A difference of `packets` per MAC is therefore sound within a session,
  and a new session starts new rows with small counts. Over ten copies (17 October 2026, A8) the deltas per 30 s of 271 changed rows had a median of 8
  frames, a 90th percentile of 118, a 95th of 138 and a maximum of 169 (about 4.6 frames per second at the 95th percentile, which is where the page's cue scale
  ends), and the five busiest MACs changed steadily (A11), with no alternation between 0 and double. What the counter counts (frames heard from that MAC, or something else) is
  still open (V-10, A6).
- **Hidden networks carry no name on record** (re-measured 17 October 2026 with `hex()`; the reading of 16 October was wrong). An SQL
  comparison of the BLOB column with the text '' had made every hidden row look as if it held a name. Compared by bytes, all 313 beacon
  rows (type 8) with `hidden = 1`, 152 BSSIDs, hold zero bytes only: 311 are empty, one is 21 NUL bytes and one is 10 (the beacon's
  zero-filled SSID element). A7: none of the 152 hidden BSSIDs has a type-5 row. A14: none of the 313 rows has printable text, and no row
  of any type carries a name for a hidden BSSID. The data therefore holds no name for a hidden network: `ssid` stays `""` as in 0.1, and
  the 0.1 behaviour (a hidden network shows no name) loses nothing. The collector's name-on-record rule, the `ssid_recorded` field, the
  `STARCHORUS_RECORDED_NAMES` switch, the page's dimmed label and every row and document line for them were therefore dropped on 17 October 2026.
  A13: 34 hidden BSSIDs have more than one beacon row and none has a newest row with `hidden = 0`, so no network that stopped hiding has been
  seen; the collector still takes `hidden` from the newest beacon row of a BSSID, not from its strongest row of either kind (a rule that changes
  nothing observable on this data).
- **Wildcard probes are not stored.** Of 27,097 type-4 rows none had an empty SSID: the firmware keeps no wildcard probe, so a 'broadcast
  probe' cannot be derived and the wording stays 'named probe' / 'no named probe heard'.

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
breaks become spaces. `hidden = 1` or an empty SSID means a hidden network and yields `"ssid": ""` (§4a: the rows of a hidden network hold no name).

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
| What does `wifi_device.packets` count? | read the counter twice, cross-check against `tcpdump -c` for one busy MAC (A6: the difference over 30 s against the frames `tcpdump` sees for that transmitter address). Monotonic within a session is observed (§4a); what it counts is open | `ap.packets` (stays unwritten); the station `packets` of the opt-in Traffic switch | V-10 |
| Format and fields of the recon output of the AP service command line (`apcli_ro` `recon_aps`/`recon_devices`) | **done 14 October 2026**, see V-3 below (the unverified `monitor` id has left the allowlist) | `apcli_ro`, `STARCHORUS_SOURCE=pineap` | V-3 |
| Do the `tx_packets` of `wlan1mon`/`wlan2mon` stay the same before and after every `apcli_ro` command? | **done** for all three lines, `RECON APS`, `RECON DEVICES` and its bounded form (and the commands below) | every `apcli_ro` id | V-3 |
| Are the interface MACs the BSSIDs the device itself transmits? | `cat /sys/class/net/*/address` against the beacons in the database | `STARCHORUS_OWN` | V-9 |
| What format does the firmware's OUI file have? | `head -5` and `wc -lc` of the file; **done 14 October 2026**: `/lib/hak5/oui.txt`, 1,258,802 bytes (1.26 MB), 38,959 lines, mtime 2025-04-13, one line per prefix in the form `00:00:00<TAB>VENDOR NAME` (colon form, upper-case hex) (§6a) | `STARCHORUS_OUI_FILE=auto` | V-8 |

#### V-3 (done): the AP service's recon lists

Checked on the device on 14 October 2026 (and again the same day for the extra forms below), read-only, with the CLI `/usr/bin/_pineap`. Its help lists, among
others, `RECON APS {format=json}`, `RECON DEVICES {format=json} {sort=field} {bytime=true|false}
{sortdir=asc|desc} {pagesize=N} {page=N} {limit=N} {mac1,...}`, `RECON COUNT APS`, `RECON COUNT DEVICES`,
`RECON CHANNELS {format=json}` and `RECON SEARCH ...`. There is **no `RECON CLIENTS`**: the call the earlier
`apcli_ro` id `recon_clients` made does not exist; the stations are in `RECON DEVICES`.

- **Passivity.** The `tx_packets` of every wireless interface (`wlan0`, `wlan0mon`, `wlan1mon`) were identical
  before and after each of `RECON COUNT APS`, `RECON COUNT DEVICES`, `RECON APS format=json`,
  `RECON DEVICES format=json` and `RECON CHANNELS format=json` (all stayed 0), and, in a second round, after
  `RECON PING`, `RECON SEARCH` with `format=json`, `RECON DEVICES format=json sort=time sortdir=desc limit=50` and
  `RECON DEVICES format=json pagesize=100 page=1`. Only `eth0`/`br-lan` moved, by 2:
  the SSH session. Starchorus uses only the plain `format=json` lists (and, opt-in, the bounded form below and `RECON CHANNELS format=json`
  for the Traffic switch).
- **Exit codes.** `RECON COUNT *` exits non-zero with the count as the exit code and prints, for example,
  `35 access point devices in recon`; `RECON CHANNELS` exits 1 but prints valid JSON. The collector therefore
  never judges the lists by their exit status, only by whether the output is a complete JSON array.
- **Cost** (one call each): `RECON APS` 0.33 s wall, 0.09 s CPU, 11 KB; `RECON DEVICES` 0.63 s wall, 0.21 s CPU,
  53 KB; `RECON CHANNELS` 0.21 s.
- **Encryption.** None of the JSON keys carries it, and the last field of the text-output beacon lines does not
  correspond to the encryption either (checked against `recon.db`): it is Management Frame Protection (802.11w),
  `0` none (open networks included), `1` supported, `2` required, `3` both, as confirmed to the author on
  14 October 2026; the JSON does not carry it. The AP service's output therefore cannot tell open from protected,
  and the security of an AP comes from `recon.db`, or is `Unknown`.
- **Scope.** The lists are the **current recon session** (the oldest `time` is about 10 hours back; 250 devices),
  whereas `recon.db` is cumulative (22,606 devices). They carry **no encryption field** and **no station-to-AP
  association**.

Schema (placeholders only; no real SSID or MAC is recorded anywhere in this repository):

```
RECON APS format=json      -> [ { "mac": "<mac>", "freq": <MHz>, "signal": <dBm>, "packets": <n>, "time": <unix s>,
                                  "beacon":   { "<hash>": <rec>, ... },      # optional
                                  "response": { "<hash>": <rec>, ... },      # optional
                                  "probe":    { "<hash>": <rec>, ... } },    # optional
                                ... ]                                          # 35 entries
RECON DEVICES format=json  -> an array of the same shape: the APs plus the stations (250 entries); the stations
                              carry mostly `probe` records = the SSIDs they probe for
<rec> = { "ssid": "<text>", "ssidlen": <n>, "channel": <n>, "freq": <MHz>, "signal": <dBm>, "count": <n>,
          "time": <unix s>, "hidden": <bool> }                                 # "hidden" in beacon records only
RECON CHANNELS format=json -> { "0": <n>, "<MHz>": <n>, ... }                  # 69 keys; used by the opt-in Traffic switch as activity, see below
```

One AP can have several beacon or response records (one per SSID). The `<hash>` keys are numeric strings.

**`RECON CHANNELS`: activity, not devices** (read 16 October 2026). The answer is `{"0":0,"2412":566,"2417":111,…}`: 69 keys, the
centre frequency in MHz plus a `"0"` key, and 11 of them are 6 GHz frequencies (all 0 while that band is off); one call takes 0.21 s. The
numbers are **not devices**: at the same moment the recon database had 19 devices on 2412 MHz in the last hour, 318 in six hours, 4,779 in
the session and 7 access points there, while the JSON said 566 to 655 and changed with every call. The sum over all keys was 1,100 to 1,400
while `wlan1mon` received 35 to 60 packets per second. The best fit is **packets per channel over a recent window of roughly 20 to 30
seconds**, which is relative channel activity as the firmware's own recon graph shows it. Starchorus therefore takes it only as a
relative share (each frequency's count over the sum of the keys at 2400 MHz and above, the `"0"` key left out; assumption A5) in its own
`activity` array, says 'activity' and never 'devices', and never writes it into `channels[]`. The unit is a best fit, not a fact. A5, measured 17 October 2026: three calls one second apart summed to 2424, 2064 and 2146 (2412 MHz: 1765, 1532, 1588), a
sliding window and not a read that consumes the counts. Still open: what the `"0"` key holds (frames of no known channel?) and that the window is 20 to 30 s.
The single-call passivity check above covers `RECON CHANNELS format=json`; its **extension** is still to run before `SECURITY.md` gets
its dated sentence: the collector's call every cycle for 10 minutes, with the transmit counters of `wlan0mgmt`, `wlan0cli`, `wlan0mon` and
`wlan1mon` before and after, and the two calls one second apart.
The `pineap` source (`STARCHORUS_SOURCE=pineap`, opt-in) is built on exactly this: APs from `RECON APS` (the
name from the strongest, then newest, beacon or probe-response record; a hidden beacon gives an empty name;
`time` becomes `last_seen`), stations from the `RECON DEVICES` entries that are not APs (their `probe`
records become `probes[]`), the window `STARCHORUS_MAX_AGE` applied to `time`, and the security of each AP
taken from `recon.db` (one query when an unknown BSSID appears, at most once a minute; BSSIDs the database
does not know are retried every 10 minutes; a lookup that fails, which the closing marker row of its `-bail` batch
shows, changes nothing: the labels known so far stay), because the lists have none. It is not the default of `auto`:
the lists are a different view (current session only, no encryption), and not a cheaper one. The source has run end to end on the device
under BusyBox `awk` (14 October 2026, a daemon of the benchmark harness, valid JSON, transmit counters unchanged): the parse of the JSON in
`awk` is what it costs, see the `pineap` bullet of §6a.

The source is **experimental and opt-in**: recon.db stays the default of `auto`, which never chooses it. When the
AP service gives no usable answer (an empty list, a failure, nothing within the 10 s of `timeout`, for instance
right after it restarted or after `RECON NEW`), the collector builds that cycle from recon.db and logs it once.
An AP the cache does not know yet is written with `"security": "Unknown"`: the page classes it `unknown`, while an
empty or absent field would be read as Open by the page and by the Overview (`isopenwep`).

`STARCHORUS_PINEAP_CALLS=recent`, the default, is a bounded form suggested to the author (a `RECON DEVICES` query with
sensible arguments instead of everything): ONE call, `RECON DEVICES format=json sort=time sortdir=desc limit=400`. The same
list carries the APs (beacon and response records) and the stations (probe records), so `RECON APS` is not called; the
newest 400 devices are kept and the oldest fall off. An AP seen only through probe responses, with no beacon record
among those 400, would show as a station. The forms with `limit=50` and `pagesize=100 page=1` were checked for
passivity first; the value 400 on 14 October 2026, in a 130 s run of the source (the answer was a complete JSON array, the
transmit counters of `wlan0`, `wlan0mon` and `wlan1mon` unchanged). It is the default because `full`, which asks for
every device of the session, is parsed device by device: it grows with the size of the list (about 2,100 devices that day, §6a).

At the end, `tools/device-probe.sh` reports each open verification as `V-<id> <name>: OBSERVED …` or
`NOT-OBSERVABLE …`. Beyond the table it covers V-6 (6 GHz reception), V-11 (multi-BSSID profiles,
which the database may under-record) and V-13 (the Bluetooth controller and tools, from sysfs and file names alone, §2b). V-12, the five jq building blocks (§2a), was answered on the device by the Overview's self-test on 14 and 15 October 2026. V-3, V-4
(a radio-locking examine command, not used by Starchorus), V-7 (the device's deauth reporter) and
V-11 remain `NOT-OBSERVABLE` there: they would need a command that a read-only run does not call (V-3 was
done by hand, see above).

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
for one collector pass, while the loop starts every 5 s, and the Overview's `jq` calls over the
1.7 MB file never finish; the display freezes. A one-hour window yields 27–30 APs, about 420
clients and 46 KB of JSON; a `--once` takes 11 s, an Overview screen 1–6 s. The payload on the
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
not heard afresh in every cycle. The window acts on the `recondb` source (the `time` of the rows) and on the
`pineap` source (the `time` of both lists); `airodump-ng`/`tcpdump` deliver only the current slice in any case.

---

## 6a. Load on the device

Measured on the device on 14 October 2026 (firmware as shipped, MIPS 24KEc, one core at about 580 MHz, 250 MB
RAM, BusyBox `ash`; `/root` and `/root/loot` are on eMMC, `/tmp` is RAM). `recon.db`: 3.5 MB, `journal_mode`
`delete`, only the autoindexes of the hash primary keys and **no index on `time`**, so every windowed query
scans the table (`ssid`: 21,123 rows of type 4, 338 of type 5, 1,461 of type 8; `wifi_device`: 22,606). With the
payload defaults (`STARCHORUS_INTERVAL=30`, `STARCHORUS_MAX_AGE=3600`, vendor on), with the recon engine and the
Overview running at the same time: a `--once` took 12.4 s wall and 3.0 s CPU (3.5 s and 2.2 s with
`STARCHORUS_VENDOR=0`); `cp recon.db` alone 0.2 s; one AP query on the copy 0.64 s, the client JOIN 0.52 s; with a
cold OUI cache `add_vendor` alone took about 27 s. `top` showed `sqlite3` in state D (IO wait on the eMMC copy).
The firmware's OUI file `/lib/hak5/oui.txt` has 1,258,802 bytes and 38,959 lines, the form `00:00:00<TAB>VENDOR NAME`, mtime 2025-04-13 (read-only overlay; V-8); the vendor cache
`cap/oui-cache.txt` had 279 lines and had not been written for two days.

Cycle cost of the two builds, measured one straight after the other on 15 October 2026 (the benchmark harness on the
device, 30 s interval, one-hour window, vendor on, warm OUI cache, 29 access points, about 299 stations, 130 s each; a
tick is 10 ms of CPU): 369 to 376 ticks for 0.1.0 against 265 to 266 for this build (the database part 276 to 281
against 191 to 192, the vendor part 68 to 69 against 49 to 51), about 28 per cent less. Two earlier pairs, less tightly
controlled, gave 241 against 205 and 270 against 200 ticks. A new vendor prefix cost about 1,400 ticks (14 s) in 0.1.0
and about 50 now; building the OUI index, once, about 850. The Overview's summary cost 1.8 s of CPU, and only on a
press over a capture it had not read yet (a new capture, or another screen), nothing while it waits for a key, against 4.6 s every
4 s in 0.1.0, whose every pass redrew the summary. The transmit counters of the Pager's wireless interfaces did not
change.

What the collector does about it:

- **RAM copy.** The work copy of the database lives in `/tmp` (`STARCHORUS_TMPDIR`), not on eMMC (§4).
- **One `sqlite3` process per cycle** instead of four to seven (§4).
- **Unchanged cycles are skipped** (`STARCHORUS_SKIP_UNCHANGED=1`). The size and mtime of `recon.db` (and of a
  `-journal` or `-wal` beside it) are taken before the copy, once per cycle, with a single `ls -lnL --full-time`
  that reads nothing (about 0.01 s of CPU; the device has no `stat`, and `wc -c` on the 3.5 MB database cost 0.6 s,
  twice per cycle in the first version of this mechanism, which made the cycle slower than before it). Where `ls`
  has no `--full-time`: `stat`, then `wc` and `date`. If they are the same as at the last full pass, no
  row can have left the `STARCHORUS_MAX_AGE` window (the full pass asks for the oldest row it counted, one more
  `MIN(time)` statement in the same batch, and the cycle is skipped only while that row is still inside the window; an
  entry's `last_seen` would not do, since a strong old beacon or an old probe leaves while its entry stays and changes `rssi`,
  `ssid` and `probes[]`), no homing target, `STARCHORUS_SURVEY` or `STARCHORUS_OWN` is on, the clock has not gone back and fewer
  than 20 cycles in a row have been skipped, the cycle only republishes the document of that pass with a new `generated`. The
  document is kept in the collector's memory (a shell variable: a file in `/tmp` would stay behind when the collector is killed), so what the published file holds in the meantime (a crond `--once`
  with other settings, an empty document after a failed cycle) is replaced, not trusted. That
  keeps the page and the Overview alive: the page counts a new `generated` as a capture and calls a feed Stale
  when none has come for twice the announced interval plus 15 s (at least 30 s). A state sampled less than 2 s after the file's mtime, or with a `-journal`
  present, is never recorded. Because the engine writes whenever it hears something, expect this to fire in a
  quiet room, not on a busy night.
- **Vendor lookup.** Locally administered (randomised) MACs, the U/L bit `0x02` of the first octet, are never
  looked up (`randomized: true` instead), and a prefix the OUI file does not contain is cached as a negative
  entry, so a prefix is read from the 1.26 MB file once. Both were already in the code. What the code did not do
  was say when a merge into the cache does not happen; a cache that cannot grow means that every new
  prefix is "new" again in the next cycle and the whole file is scanned again. The merge now logs its growth
  (`vendor cache: N new prefix(es), M lines`) and, once per episode, why it did not happen (`vendor cache: merge
  skipped (...)`: another OUI file in the header, an unrepairable last line, nothing could be added, or the lock
  messages that were already there; lines that another instance merged first, a crond `--once` next to the daemon, are in the cache
  and are not reported as a failure). The lock backoff is also no longer held by a clock that was set back
  (the device has no battery clock). On the development machine a new prefix is appended to the cache in
  the daemon, the crond `--once` and the deferred-merge paths; the cause of the two stale days on the device
  could not be reproduced, see the list below.
- **OUI index.** A new prefix cost a pass over the whole OUI file: 38,959 lines, about 14 s of the device's CPU in
  `awk` (about 0.36 ms per line), and in a busy place a new prefix shows up in most cycles. The collector now splits the OUI file once into
  `STARCHORUS_CAPDIR/oui-index/`: one file per first octet (`00` ... `FF`), each with that octet's lines exactly as
  they stand in the file, in file order, and a `hdr` that names the OUI file (path, size, mtime: the line the cache
  carries) and the octets that are split further. The IEEE list has a third of its lines (13,031 of 38,959) under
  `00`, so an octet with more than 1,500 lines (the two biggest at most) is split by its first two octets
  (`00AB`, ...). A lookup reads the files of the prefixes it needs with the **same parser** as a pass over the file,
  so the vendor strings, the first-line-wins rule and the negative cache entries are the same by construction (the
  self-test compares the document and the cache lines of both paths, with every file format the parser accepts,
  also for an octet that is split). The index is built at start-up and again when the OUI file changes (size or
  mtime), into a directory of its own that is moved into place under the cache lock with `hdr` written last, and a
  build that kept fewer lines on disk than it read is thrown away. A missing, mismatching or damaged index is no
  error: the lookup scans the OUI file as before (a line is skipped after three operations when its first octet
  is not wanted: 3.8 s, 7.5 s under `00`, against 14 s without that gate), and the next `setup_vendor` builds it again. Measured on the device
  (14 October 2026): building it 8.5 s of CPU once (`oui_index` 847 to 859 ticks: counting the octets 1.3 s, the
  split 6.9 s, the check 0.3 s), 512 files, 2.2 MB on flash; a lookup of one new prefix 0.01 s on top of the 0.07 s
  that the `awk` process costs anyway (up to about 0.25 s in the biggest file), against 3.8 s (7.5 s under `00`) for
  the scan with the first-octet gate and 14 s before. In the daemon a cycle with a new prefix costs what any other
  cycle costs.
- **Priority.** The payloads start the collector, the page server and (on-device payload) the Overview with
  `nice -n 19` when `nice` exists, so that the Pager's own services come first; `sqlite3` and `awk` inherit it. A collector started by hand or by `crond` is not reniced.
- **Source `pineap`** (§5a, V-3), opt-in, and not a cheaper path. The calls are cheap: `RECON APS` 0.33 s wall and
  0.09 s CPU, `RECON DEVICES` 0.63 s and 0.21 s, so about 1 s of wall and 0.3 s of CPU for the two, one after the other. Parsing their
  JSON is not: measured on 14 October 2026 with the benchmark harness (a `STARCHORUS_SOURCE=pineap` daemon, window 3600 s, 30 s interval,
  vendor on, transmit counters unchanged), the default `recent` call (400 devices) costs 9 s of CPU per pass (900 ticks), a steady cycle
  10 s, and the first cycle 20 s, because the security lookup that follows builds the document a second time; `full` over the whole
  session list (about 2,100 devices, 422 KB) costs 46 s per pass and 95 s for the first cycle, longer than the interval. A cycle of the database path
  costs 2.0 to 2.7 s (200 to 270 ticks, measured above). That is about 22 ms of `awk` per device (the `sed` tokeniser needs 0.15 to 0.7 s per call). The first version also
  sorted the AP and station lists, and the probe list of each station, with insertion sorts, which grow with the square of the number of devices (1 s at those
  counts, 14 s for 800 devices in random order on the device); they are now a heap sort and a list of the 8 smallest probed SSIDs kept as the
  SSIDs come. The walker itself is as it was. Neither variant is lighter than the database path, so neither is the default of `auto`.

Still to be checked on the device, with the exact argument sets:

- `_pineap RECON DEVICES format=json sort=time sortdir=desc limit=400` (`STARCHORUS_PINEAP_CALLS=recent`, the default): the
  transmit counters stayed the same and the answer was a complete JSON array (a daemon of the harness, 14 October 2026). Still to be
  looked at: that it holds at most 400 entries, newest `time` first (`sortdir=desc` really descends, `sort=time` really sorts by time).
  If the argument names differ on this firmware, the one literal line in `apcli_ro` is the only place to change.
- `STARCHORUS_PINEAP_CALLS=full` end to end (the two plain lists): the daemon ran (46 s per pass, §6a above); the `tx_packets`
  comparison around it was unchanged.

Also, not yet looked at on the Pager although the tests on the development machine pin each of them (the cycle's CPU
time itself was measured, above): the number of `sqlite3` processes per cycle (a `sqlite3` shim in `PATH`); that `/tmp` really receives the copy
(`ls /tmp/starchorus-recon-*` during a cycle, nothing new in `cap/`); that a quiet period gives skipped cycles and a moving `generated`
(`collect.log` stays silent, the file's mtime moves); the log lines `vendor cache: ...` in
`collect.log` after a change of scenery (is the cache growing, and if not, which reason is named); and an end-to-end
`STARCHORUS_SOURCE=pineap sh starchorus-collect.sh --once` by hand (the daemon of the harness has run it under BusyBox `awk`).

**The radio pair on the device: measured on 18 October 2026.** The opt-in Bluetooth window and the opt-in Traffic read (`docs/architecture.md` §14.6)
were measured as part of the collector: a copy of the 0.2.0-dev.1 collector under `/tmp` with its own directories and the payload's defaults
(one-hour window, 30-s interval, vendor on), alongside the recon engine, the installed 0.1.1 collector and the owner's open Overview; the
reads that settle the design (A1, A2, A10, A15 of §2b) came first. Segments of 8, 8 and 10 minutes with both switches off, Bluetooth on and
Traffic on; the ticks are the CPU time of the collector's children per cycle (`cutime` and `cstime` of the loop), the tools' own ticks were read
from `/proc` once a second while they ran. The result in one line: the design is passive as built (V-13 and V-3 below), the tools cost what
the brief said, and the parse, the polling and the AP service's command-line client cost more than the budget; the switches stay off by default
and the levers are listed after the table. In a crowded hall the parse is held to a size and a time limit, so the cycle can lengthen but the
Wi-Fi document is never held back by it.

| Row | Procedure | Pass | Measured (18 October 2026) |
|---|---|---|---|
| Bluetooth, `btmon` part | the collector daemon with the payload's defaults, 20 min in alternating 10-min halves with `STARCHORUS_BLUETOOTH=0` and `1`; ticks of `btmon` and `hcitool` per cycle, a 6-s window measured directly (no scaling) | at most 50 ticks per cycle | **passes**: `btmon` 33 and `hcitool` 3 per window (399 and 37 ticks over 12 windows) |
| Bluetooth, parse and layers part | the same; ticks of `grep`, the parse and the per-cycle layer pass per cycle | at most 80 ticks per cycle | **fails**: about 295 per cycle (502 with Bluetooth against 171 without, less the tools' 36). Taken apart on a real 6-s window (322 reports, 4,475 lines, 177 KB, 2,261 lines after the prefilter): `grep` 25 ticks, the `awk` grammar 150 (0.68 ms per kept line; the brief reckoned 0.1 to 0.36), `tr` 2; the polling about 60 (73 process spawns more per cycle: the `$( )` substitutions and `sleep` naps of the window loop, 0.25 to 0.85 ticks each); the layer pass about 20 |
| Bluetooth, whole | the collector's process tree | at most 130 ticks per cycle (about 3 % at 44 s); above it, a 5-s window | **fails**: about 331 per cycle, 8 % of the core at the 40-s cycle the window makes; 54 reports per second in this room against the brief's 30 |
| crowded hall | a synthetic 1.5-MB window (the masked fixture repeated with counter-derived addresses) replayed through the parser on the device | wall time at most 6 s; the ticks are recorded | not run on 18 October; from the real window's 0.68 ms per kept line, 1.5 MB (about 19,000 kept lines) would take about 13 s, so the parse cap (512 KiB, `timeout 6`) is what holds the cycle, as designed |
| traffic | the same alternation with `STARCHORUS_TRAFFIC=0` and `1` | at most 20 ticks per cycle | **fails**: about 48 per cycle (219 against 171); the cost is the AP service's command-line client itself (one call per cycle) |
| V-3 extension | `RECON CHANNELS` called by the collector every cycle for 10 min; transmit counters of the radios before and after | counters unchanged | **passes**: `tx_packets` of `wlan0`, `wlan0mon` and `wlan1mon` stayed 0 over all 26 minutes of the three segments (the firmware had no `wlan0mgmt` or `wlan0cli` that day; `eth0` carried only the ssh session) |
| stop paths | in a copy: `--stop` in the middle of a window; `kill -9` of the loop in the middle of a window, then a new start | no tool left; the next window sets its parameters | **passes**: `--stop` returned in 2.4 s and the tools were gone 1 s later, no pid file left, the loop ended with 143; after `kill -9` the tools ended by their own timers 12.9 s later and the window's pid file stayed; the next start swept it, and its first window had its witness (1, 1, 1; 325 reports) |
| coexistence | on the interface that shares the chip with `hci0` (A15), plus the management link (ping latency from the owner's side, the `wlan0mgmt` counters): 30 pairs of 20 s on and 20 s off; the mean of the within-pair differences of rx frames per second, overall and per band (2.4 GHz against 5 GHz, from the activity shares or `iw survey` busy time) | the difference and the smallest difference these pairs can detect are written into §2b; the default stays off | **no loss to see**: 30 pairs (`btmon` and the passive scan for 20 s, then 20 s without), rx frames per second on `wlan1mon` 20.7 with the window and 20.7 without, mean within-pair difference −0.07/s (−0.3 %), the pairs could have shown a difference of about 1 frame per second (two standard errors, sd 2.6); the other radio (`wlan0mon`, a control that shares nothing) moved by −1.7/s, which marks the drift the pairs still carry rather than any effect; the management link's round trip from the owner's machine stayed at 1.2 ms median in both phases (600 and 557 samples, p95 1.3 ms, no loss); no per-band split (the activity shares were not taken alongside) |
| V-13 passivity | one window by the collector; the window's `btmon` text counted for `Type: Passive (0x00)` before the first report, `Scanning: Enabled`, `Scanning: Disabled` after it, and every event type (counts only; no address leaves the device) | 1, 1, 1; the event-type histogram is recorded; no `hcitool` or `btmon` process is left | **passes**: 1, 1, 1 and no `Type: Active`; 320 reports in 6 s, `ADV_IND` 261, `ADV_NONCONN_IND` 33, `ADV_SCAN_IND` 26, every event with one report; the document carried 23 Bluetooth records (6 public, 7 resolvable, 10 static) and 13 activity shares; no process and no pid file left |

**The levers, in the order of their yield** (none taken on 18 October; the owner decides for 0.2.0): the `awk` grammar of the parse runs its
header test, two `substr` and up to three regular expressions on every kept line, five of the seven of which are field lines that start with
eight blanks and can be told apart by their first byte, so the grammar can skip the header test for them (about a third of the 150 ticks);
the window loop polls every 0.2 s with `$( )` substitutions and a `sleep` applet, each a process on this shell, about 73 spawns and 60 ticks per
window, which globals set by the functions themselves and a longer nap would cut to a handful; a window of 5 s (`STARCHORUS_BT_WINDOW=5`, the
brief's Q2) takes a sixth off the tools and the parse alike; the Traffic read can be taken every second cycle (the AP service's window is 20 to 30 s
wide, so nothing is lost) for half its cost. The binary route (A16) stays out: the device has no `od`.
| V-3 extension | `RECON CHANNELS` called by the collector every cycle for 10 min; the transmit counters of `wlan0mgmt`, `wlan0cli`, `wlan0mon` and `wlan1mon` before and after; and two calls one second apart (A5) | the counters unchanged; the second call not far lower than the first |

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
| **C**: netcat server `starchorus-serve.sh` over GNU netcat | the page server of a Pager without `uhttpd` and `python3`, which is how the Pager stands after its system update; it answers one request at a time, which suits one browser; the 0.1.0 handler served a browser cleanly on 13 October 2026, and the 0.1.1 server was measured on the Pager on 15 October 2026 (see below) |
| **D**: any client on the management network opens the page server (A or C) | works like the server it opens |

Never put a server on port 1471 (the device's web interface) or 80; Starchorus takes a free high
port (default 8199, `STARCHORUS_PORT`).

**The 0.1.1 netcat server on the Pager (measured 15 October 2026).** `starchorus-serve.sh` was rewritten for 0.1.1: no
`Access-Control-Allow-Origin` header; each answer is sent from a copy of `starchorus.json` made in RAM, so that
`Content-Length` matches the bytes; a client that sends nothing is dropped after 15 s (the listener is started anew
after each 15 s of quiet, which leaves a short gap in which nobody is listening); a stalled header line is answered
after 10 s where the shell has `read -t`; a whole request is ended after 60 s. It was first tested on the development
machine, under bash, under dash and against a stand-in for `/proc`. On 15 October 2026 it ran on the Pager itself,
after `tools/install.sh` had installed 0.1.1 and its five steps had passed (read-back integrity; the collector
self-test, ALL PASS with 366 checks as of 0.1.1; the Overview self-test, ALL PASS with 66 checks as of 0.1.1; one
passive capture; the Overview smoke test). The payload started the server at `172.16.52.1:8199`, and a laptop on
USB-C checked it:

- `GET /starchorus.json`: HTTP/1.0 200, `Content-Type: application/json`, `Content-Length` 12529 equal to the 12529
  bytes of the body (which parses as JSON), `Cache-Control: no-store`, and no `Access-Control-Allow-Origin` header.
- `GET /`: 200, `Content-Length` 594940 (the whole page), `Cache-Control: max-age=60`.
- A silent client (a connection held open without sending anything) blocks the single-connection listener: a poll
  during the hold failed to connect at once, with no hang, and the listener accepted again 10 s after the hold began,
  when the idle limit closed the silent connection. The 15 s are counted from the start of each listening round, not
  from the moment the client connects, so a silent client that connects part-way through a round is let go sooner.
- Five consecutive polls: all 200, 0.09 to 0.18 s each.
- Afterwards: no stray `sleep 60`, no leftover copy in `/tmp` (`starchorus-http-*`), one `nc` listener, and the
  handler pair and the serve loop as designed. After `payload.sh stop`: no collector, serve loop, handler, `nc` or
  `airodump` process left, and no pid files left.

Not measured on the Pager: a client that stalls in the request headers (the 10 s limit applies only if the Pager's
`ash` has `read -t`; without it a stalled header line is ended by the 60 s limit), the 60 s limit itself, and a
browser loading the page from the 0.1.1 server (the browser check of 13 October was the 0.1.0 handler).

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
| `LOG [colour] "text"` | appends a line to the log on the display (append-only); optionally with a colour | Overview (`red` = alarm, `blue` = heading), payload (`blue` = heading, the page's address and 'Still running.'; `red` = 'Collector had stopped.', a failed start and a version difference; `green` = 'Stopped.') |
| `LIST_PICKER "title" opt1 … default` | shows a selection list and prints the chosen option on stdout; the last argument is the default | the payload's menus ('Starchorus: Stopped', 'Starchorus: Running', 'Settings' and its two short lists); the Overview's list of screens |
| `NUMBER_PICKER "title" default` | number entry; prints the number on stdout | payload: 'Port' |
| `CONFIRMATION_DIALOG "text"` | yes/no confirmation | payload: only before 'Reset to Defaults' |
| `START_SPINNER "text"` / `STOP_SPINNER id` | busy indicator on and off; `START_SPINNER` prints the id | payload: 'Starting', 'Stopping', 'Applying' (one word each: on firmware 1.0.4 and older a label of several words opens a dialogue that cannot be closed). 'Starting' stays up until the first capture since the Start exists, for as long as 20 seconds, and a trap stops the spinner if the payload is ended while it shows: a spinner that is never stopped can leave a background child holding the payload's output open, as the author of a published payload reported (not measured here) |
| `ERROR_DIALOG "text"` | error dialogue | payload on a failure (not installed, could not start or stop, no web server, port in use, invalid port, setting not saved, version difference); Overview when `jq` is missing |
| `PROMPT "text"` | a message until it is dismissed | payload: a setting locked by the environment; the QR text when `PROMPT_QR` is missing or fails |
| `PROMPT_QR …` | a QR code with a message (firmware 1.1.1 and later, as reported: this project has no method or date of its own for that boundary and has not tried an older firmware) | payload: 'Open on Phone' (an exit after a person's time counts as leaving it; a command that is absent or returns within 0.6 s gets the PROMPT) |
| `WAIT_FOR_INPUT` | waits for any key and prints its name (`A`, `B`, `UP`, `DOWN`, `LEFT`, `RIGHT`); no time limit is documented, and none is used | Overview: one wait, started in the background before each draw and collected when the draw is over; the wait takes one key and that key ends the draw, so a press during `Reading...` is kept and the next wait follows at once (M1 to M3, §7); nothing redraws by itself; A draws the screen again, B goes up one level, Left and Right step through the screens, Up and Down are ignored |

**Measured on the device (14 October 2026).** `LIST_PICKER` prints the chosen option's exact text
and exits 0; key B gives exit 3 and no output. Four rows are visible at a time, and a row of up to 28
characters shows in full. The default argument puts the cursor on the row with that exact text, and
a list drawn again with changed row text works. `WAIT_FOR_INPUT` prints the key's name;
`timeout 4 WAIT_FOR_INPUT` ends after 4 s without one (0.1.0's refresh loop; this build puts no
UI command under `timeout`, see M7 below). `PROMPT_QR "message"` shows a QR code.

**Confirmed on the device (15 October 2026).** The firmware's own usage text for the command (`strings` of
`/usr/bin/hak5cmd`) reads `PROMPT_QR [data] [message]`: the QR data (the URL) first, the message second. That is the
order the payload's probe picks (`url`). The method was reading that usage text. Which buttons dismiss it, and whether
three message lines fit under the code, remain open until the owner's click-through.

**Still read defensively.** A picker counts as 'Back' if the exit code is not 0, the output is empty
or it is none of the options offered; an empty or cancelled number entry leaves the value unchanged;
a confirmation counts as yes only if the exit code is 0 **and** the output reads `1` (the runtime's
'confirmed' value, as a literal, so that the environment cannot redefine what counts as yes). Dialogue
texts carry their line breaks as `\n`, as Hak5's own payloads do. Open on the device: whether `\n`
breaks a line in every dialogue; which keys leave `PROMPT_QR` and with which exit status (the payload
treats a non-zero exit after more than 0.6 s as leaving it, and shows the PROMPT only for a command
that is absent or returns at once); whether three message lines fit under its code; whether Down on the last row of a list wraps; and whether the middle dot `·` of the Overview's lines shows on the
device's font.

The Overview `starchorus-display.sh` is the on-device view: eight screens from `starchorus.json`
(the summary, strongest networks, bands and security, devices and merges, probe requests,
stations, Bluetooth, air quality) as LOG lines. The payload runs it as a child process at nice 19 and hands it
the time of the last Start, so it never shows a capture from before it ('Waiting for the first
scan.'). It has no menu of its own, and starting and stopping belong to the payload. Before it draws a
screen it starts one `WAIT_FOR_INPUT` in the background, with no time limit, and it collects the
answer when the draw is over, so a wait is open while a screen or 'Reading...' is drawn. That order
follows from the measurements below: a press made while no wait is open is lost (M1) and B is then
taken by the Pager's own UI (M2), whereas a wait started in the background still receives a key while
the foreground writes LOG lines (M3). A press made during 'Reading...' is therefore kept. A wait takes
one key, so that key also ends the draw: the shell prints nothing more, ends the `jq` that is running
and acts on the key at once, with the next wait started straight after. A draw that went on would run
with no wait open for the rest of its time (up to the 20 seconds of the `jq`, then every line of the
block), and a second press in that time, B again because nothing seems to happen, would be lost or,
for B, leave the payload's view. Three stretches are still without a wait, and a press that falls in
one is lost (M1) and, for B, may leave the payload's view (M2): the start, from the Overview's first
line of code to its first wait (the traps are set and the temporary directory is made); the time from
a key being answered to the next wait being registered with the UI (while a `jq` runs, the shell sees
the key at the next look of its watcher, every 0.2 s; then it ends the `jq`, takes the key, asks
whether the payload is still there, which starts no process, and starts the waiter, which is two
processes before `WAIT_FOR_INPUT` itself runs, and the UI takes the request in its own time), so even
the first line of a draw can be written before its wait exists; and the list, which is a wait of its
own. None of them was timed on the device. The first two are a fraction of a second at most (the
watcher's 0.2 s and a few process starts), not the seconds of a draw, but they exist, and this
document does not claim that B can never leave the payload's view. The
wait writes its answer into a file in a private temporary directory (`mktemp -d`, mode 700) that the
Overview removes when it ends, with the output of its `jq` in a second file there. An exit trap also
ends a wait that is still pending (after a TERM, say), so none is left behind. A file that cannot be
written (the file system is full) is reported as 'Overview could not read a key.' and not counted as
empty answers. Nothing redraws by itself, and no UI command is ever put under `timeout`; only its own
`jq` is (`timeout 20`, where `timeout` exists: a read that takes longer ends as 'This scan took over
20 s to read.', and 'Try Settings > Show Last: 1 h.' follows). The keys: A draws the screen again; B
goes up one level (a screen, then the `LIST_PICKER` 'Overview' with its eight rows, then exit 0 to the
payload's menu); Left and Right step through the screens, round the ends; Up and Down are ignored (a
new wait is started at once, nothing is drawn, unless the draw they came in was cut: then the screen
is drawn again); BACK and Escape count as B and a lower-case a or b as the capital; any other answer is
a strike when its wait ended within a second of being started, and three strikes in a row end the
Overview; a slower answer is only waited out and the wait is started again. Each draw ends with the frame, `Last scan 12:04:31 (42 s ago)` (the red 'No new scan for 4 min.' when the
capture is older than three intervals) and `A: Refresh   B: Back`. It recognises the device by the
`LIST_PICKER` command (`LOG` alone will not do: macOS has `/usr/bin/log`). Without that command, or
with `STARCHORUS_DISPLAY_PLAIN=1`, every command falls back to plain text on stdout;
`sh starchorus-display.sh --once summary <json>` thus prints the same content on the development
machine. It does not draw the animated web view.
Details: [display-paths.md](display-paths.md#overview-on-the-device-display).

### Measured on the device: what the Overview's keys rest on

Every UI command of the payload runtime (`LOG`, `LIST_PICKER`, `WAIT_FOR_INPUT` and the rest) is one
client of the Pager's UI service, which listens on the local socket `/tmp/api.sock` (`WAIT_FOR_INPUT`
is the request `/api/payload/interact/wait_for_input`). That is read from the vendor's documentation
and from published payloads, not measured on this Pager. How the service treats the keys a payload
waits for was measured on 16 October 2026 with a short lab payload that called only UI commands
(`LOG`, `LIST_PICKER`, `START_SPINNER`, `STOP_SPINNER`, `CONFIRMATION_DIALOG`, `WAIT_FOR_INPUT`),
wrote its timings to a file in `/tmp` and transmitted nothing. It was started twice on the Pager, with a
person pressing the keys each test asked for; the first run stopped after test 3b, so M2 to M6 come
from the second run alone (M1 and M7 from both). The Overview's order of work (the wait first, then
the draw) rests on M1 to M3.

| ID | Question | Measured on 16 October 2026 | What the Overview does |
|---|---|---|---|
| M1 | Is a press made while no `WAIT_FOR_INPUT` is open (during a 5 s `sleep`, during a spinner) kept for the next wait? | No. The wait that followed a 5 s `sleep` returned only when the owner pressed again (86 s and 41 s after it was opened, in the two runs), and the wait after a 4 s spinner was the same (56 s and 5 s). A press that falls where no wait is open is lost, not buffered. | A wait is open while a screen or `Reading...` is drawn: it is started before the draw and collected when the draw is over. A press made during `Reading...` is kept and acted on at once: it takes that wait, ends the draw and the next wait is started straight after, and no key is dropped for having come early. A second press in the same draw finds the next wait open after a fraction of a second (the stretch between the two is described under the keys in §7), where a draw that went on after the first key left seconds without one. The Overview cannot help while the payload's 'Starting' spinner is up: a press made then is lost. |
| M2 | What does B do while no wait is open? | The Pager's UI took it, and the view left the payload's log (the owner confirmed the change on the screen). | B reaches the Overview while a screen is drawn, because a wait is open, and a second B in the same draw reaches the next wait, which is started as soon as the first has ended the draw. A B that falls where no wait is open still leaves the payload's view: before the first wait, in the fraction of a second between one wait ending and the next being registered, and at the start of a draw, whose first line can be written before its wait exists (§7, the description of the Overview). |
| M3 | Does a `WAIT_FOR_INPUT` started in the background receive a key while the foreground writes `LOG` lines? | Yes. DOWN arrived 3.2 s after the first of six lines that the foreground wrote, one a second. | This is what allows the wait to be started before the draw. |
| M4 | Does `LIST_PICKER` restore the console behind it? | Yes. The three marker lines written before a list were still on the console after it closed. | The list of screens opens from a screen without losing it. The log only grows, so a screen drawn again sits below the one before. |
| M5 | Is the second press of a quick double press kept? | Not established. Test 7 asked for A twice in quick succession; the first wait returned RIGHT, not A, and the next wait, started at once, saw no key within 2 s, so it cannot be told whether a second press was made at all. | Nothing rests on it. The Overview takes a press that falls where no wait is open as lost (M1), and the next wait is started as soon as a key has been taken, which takes a fraction of a second. |
| M6 | How many characters fit on one console line? | At least 40: a line of forty digits stayed on one line. The stock theme's files say 50. **To be run (owner check, per command; it was to come before the Bluetooth figure went on the summary line, and the figure is on it already, so it is overdue):** a line of 50 digits, then a line holding the middle dot `·`. | Nothing depends on it: a draw taller than the screen scrolls, as the log always does. Whether a longer line wraps or is cut was not measured. The summary's APs line with the figure (`APs 12   ·   2.4:5  5:6  6:1  BT 23`) is 45 characters at the worst (three-digit counts, '256+'); if fewer than 45 stay on one line, the figure leaves the summary and the hub row of the Bluetooth screen reads 'Bluetooth (23)'; that fallback is not written (it is a change of both copies of the Overview that waits for this check). **Until M6 has passed, nothing switches the Bluetooth setting on by default**: it stays off in the payload and the collector, and the release pass does not change that, because a summary line that wraps or is cut on the Pager would show on every start. Every new line of the Bluetooth screen and of the Bands bars is at most 40 characters, ASCII separators only. |
| M7 | After a `timeout`-killed `WAIT_FOR_INPUT`, does the next call still return the next press? Do Up and Down reach a waiting payload? | No stale waiter was seen: the next call returned the next press (1.1 s and 3.8 s after it was opened in the two runs, then 0.5 s and 2.1 s for the one after), but the evidence is weak, because the owner's presses were not timed against the kill. UP and DOWN reached a waiting payload (tests 3 and 4), and so did RIGHT; LEFT was not seen (test 9, meant for it, returned A twice). | No UI command is put under `timeout`, here or anywhere in the project: M7 is too weak to rely on. Up and Down are ignored: a new wait is started, nothing is drawn, no strike. |

**Not measured.** Whether Up and Down also scroll the console while a wait is open (only the returned key was
recorded); what Left, Right, Up and Down do while no wait is open (A was lost in M1 and B left the view in M2; the
others were not tried, and the Overview does not depend on them, because a wait is open while it draws, apart from
the stretches listed above); whether a quick double press is kept (M5 is inconclusive); the
exit status of `WAIT_FOR_INPUT` on a cancel and any word it prints besides the six key names (the Overview takes
BACK and Escape as B, a lower-case a or b as the capital, and any other answer, an empty one included, as a
strike when it comes back within a second); how long a process takes to start; and where a line wider than 40
characters wraps or is cut.

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

The collector, the page (`index.html`), the Overview and the netcat server live under
`/root/loot/starchorus`; `tools/install.sh` copies both sets. A self-contained payload directory
(`tools/hak5-package.sh`) carries them beside `payload.sh` instead, and the payload copies them to
`/root/loot/starchorus` on its first run when no collector is there yet. The payload starts the
passive collector over a one-hour window (`STARCHORUS_MAX_AGE=3600`, every 30 s; §6), serves the
page on port 8199 **if** a server is present (`uhttpd`, then `python3`, then the netcat server),
and opens the Overview. What starts, and with which values, is set under the payload's Settings; it
saves the choice in `/root/loot/starchorus/settings.conf` (never overwritten by `tools/install.sh`).
Without a server the collector carries on writing `starchorus.json`; the view then comes from a
connected computer (route B). 'Stop' in the menu, or `payload.sh stop`, ends the collector and the
server and waits until the collector has gone. Whenever the payload stops its page server it also
waits (up to 3 s) until the port is free again, so that a restart on the same port does not find it
taken: the server runs at nice 19 on the single core and may handle its signal late.

Each script carries a `# Version:` and a `# Contract:` header. The contract number is the interface
the payload shares with the collector (`--status`, `--stop`, the pidfiles) and the Overview (its
environment); it changes with that interface, so a payload updated on its own is caught at the same
version too (an installed script with a version but no contract line counts as contract 1). A
difference is reported once at launch. The remedy is `tools/install.sh`; in the self-contained
layout, which has no `tools/` on the device, the dialogue names the file to delete instead
(`starchorus-collect.sh` in `/root/loot/starchorus`), after which the next run copies the bundle again.

The collector's pidfiles live in `/root/loot/starchorus`, on the eMMC: they outlive a reboot, and
the pid they name may by then belong to another program. The payload and the collector's `--stop`
and `--status` therefore count a pid as theirs only while `/proc/PID/cmdline` still names the
collector (`starchorus-collect`), `airodump` or `starchorus-serve`; any other pidfile is deleted
without a signal. The collector sleeps in the foreground between passes, and BusyBox ash runs a
trap only once that `sleep` has returned, so 'Stop' also ends the loop's `sleep` child (found through
`/proc/*/stat`) and the loop goes at once. Temporary files of a pass cut short
(`starchorus.json.tmp.<pid>`; a zero-byte one was found after a crash) are removed at the next
start. The marker `/tmp/starchorus.started` holds the time of the last Start; `/tmp` is RAM, so a
reboot clears it.

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
  `-s, --source=ADDRESS` and `-l`/`-p`/`-n`; the netcat server listens with
  `nc -l -n -s ADDR -p PORT -c`. Checked on the device on 11 October 2026: with the default bind,
  `netstat -ltn` shows `172.16.52.1:8199` for uhttpd and `172.16.52.1:8299` for the netcat server
  on a test port, nothing on `0.0.0.0`; the Pager's own `:1471` and `:22` are unchanged. BusyBox `httpd` (`-p [IP:]PORT`) and `python3` (`--bind ADDR`) are
  absent here; the root `payload.sh` binds them the same way where they exist. The device's
  BusyBox does not accept `--list` (`-list: applet not found`), so the root `payload.sh`'s
  BusyBox `httpd` test is simply false here.
