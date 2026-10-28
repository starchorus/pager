# Installing Starchorus

These instructions put Starchorus on a Hak5 WiFi Pineapple Pager and show its sky in your browser.
They take you through every step, one action at a time, on macOS, Linux or Windows.

Starchorus is an independent project and is not affiliated with, sponsored or endorsed by Hak5.
WiFi Pineapple and Hak5 are trademarks of Hak5 LLC.

From here on, the device is simply 'the Pager'.

Starchorus only listens. Installing it merely copies files to the Pager, over a cable or the Pager's
own management network; Starchorus itself never transmits.

**Contents:** [0 What you need](#0-what-you-need) · [1 Download](#1-download-starchorus) ·
[2 Connect](#2-connect-to-the-pager) · [3 Easy route](#3-easy-route-the-installer-script) ·
[4 Manual route](#4-manual-route-step-by-step) · [5 Start](#5-start-starchorus) ·
[6 Open the page](#6-open-the-page-in-a-browser) · [7 Stop, update, uninstall](#7-stop-update-uninstall) ·
[8 Troubleshooting](#8-troubleshooting) · [9 Without a Pager](#9-try-it-without-a-pager)

Facts about the Pager itself (cable, address, password, menus) follow Hak5's documentation at
<https://docs.hak5.org>; where these instructions say 'Hak5's documentation', that is the source.

---

## 0. What you need

- The Pager, charged and switched on.
- A computer running macOS, Linux, or Windows 10 or 11.
- A USB-C cable that carries data, not merely charge; some cheap cables are charge-only and will
  not work. Alternatively, your computer within reach of the Pager's management Wi-Fi.
- The Pager's root password. There is no default: you chose it on the Pager itself during its
  first-time setup, with the D-pad and the green A button. The same password is used for ssh and
  for Hak5's Virtual Pager.
- A web browser.

Nothing else is needed on the Pager. Starchorus installs no packages and needs no Internet
connection, and `jq` and `sqlite3`, which it uses, are already present on the firmware we measured
(see the [device notes](docs/device-notes.md#2-tools-on-board)).

A few terms used below:

- **Terminal**: a window in which you type commands instead of clicking. On macOS it is called
  Terminal; on Windows, use PowerShell; on Linux, your desktop's terminal application.
- **ssh**: a program that lets your computer run commands on the Pager over a network connection.
- **scp**: its companion, which copies files to the Pager over the same connection.
- **IP address**: the number that identifies a device on a network, written like `172.16.52.1`.
- **root**: the administrator account on the Pager.

macOS, Linux and Windows 10/11 all include `ssh` and `scp`. To check, open a terminal:

- **macOS:** open Finder, then Applications → Utilities → Terminal.
- **Windows:** open the Start menu, type `PowerShell`, and press Enter.
- **Linux:** open your terminal application from the applications menu.

Then type this and press Enter:

```sh
ssh -V
```

**You should see** one line naming OpenSSH and a version number.

**If something goes wrong**

- *Windows says `ssh` is not recognised:* the OpenSSH client is an optional Windows feature. Add
  it under Settings → Apps → Optional features ('OpenSSH Client'), then open a new PowerShell
  window.
- *Linux says `ssh: command not found`:* install your distribution's OpenSSH client package (often
  named `openssh-client`).

---

## 1. Download Starchorus

Choose **one** of the two ways.

**A. Without git (simplest)**

1. Open <https://github.com/starchorus/pager> in your browser.
2. Click the green **Code** button.
3. Click **Download ZIP**.
4. Unpack the ZIP file (double-click it on macOS and Windows; on Windows choose 'Extract all').

**You should see** a folder named something like `pager-main`, containing `README.md`,
`starchorus.html` and a folder `tools`.

**B. With git** (if you already use it)

```sh
git clone https://github.com/starchorus/pager.git
```

**You should see** a new folder `pager`.

**If you took the Pager archive from a release** (`starchorus-<version>-pager.tar.gz`) instead, check it
before you use it: put it and `SHA256SUMS` in one folder, unpack it there (`tar xzf starchorus-<version>-pager.tar.gz`)
and run `shasum -a 256 -c SHA256SUMS` (`sha256sum -c SHA256SUMS` on Linux). **You should see** `OK` after the archive
and after each of the eight files; any other word means the download is not what was published, so fetch it again.

**Then, in either case,** move your terminal into that folder. Type `cd`, a space, then drag the
folder from Finder or Explorer into the terminal window, and press Enter. For example:

```sh
cd ~/Downloads/pager-main
```

On Windows the path looks more like `cd C:\Users\you\Downloads\pager-main`.

To confirm you are in the right place:

```sh
ls
```

**You should see** `starchorus.html`, `starchorus-collect.sh`, `tools` and `library` among the
names listed.

**If something goes wrong**

- *`ls` shows only one folder:* the ZIP unpacked into a folder within a folder. `cd` into the
  inner one and try `ls` again.
- *The path contains spaces:* put it in double quotes, `cd "/path/with spaces/pager-main"`.

Every command from here on is typed in this folder.

---

## 2. Connect to the Pager

1. Connect the Pager to your computer with the USB-C cable, **or** join your computer to the
   Pager's management Wi-Fi.

   - *USB-C:* the Pager appears to your computer as a USB network adapter (Realtek RTL8153). macOS,
     Linux and Windows support it without extra drivers. The Pager gives your computer an address
     in the range `172.16.52.x` automatically.
   - *Management Wi-Fi:* it has no default name or password. You set both on the Pager under
     **Settings → Network → Management AP Setup**, then join that network from your computer as you
     would any other.

2. Note the Pager's address: `172.16.52.1`. On both the USB-C and the management Wi-Fi
   connection the Pager always uses this address, and ssh listens on the standard port 22. Every
   command below uses it.

   If your computer shows an address beginning `169.254.`, it has not yet received one from the
   Pager: switch the network connection off and on again in your computer's network settings.
   Nothing else on your computer (a VPN, or Docker's virtual networks) should use the range
   `172.16.52.x`.

3. Check that your computer can reach the Pager. On macOS or Linux:

   ```sh
   ping -c 3 172.16.52.1
   ```

   On Windows:

   ```sh
   ping 172.16.52.1
   ```

   **You should see** lines containing 'bytes from' (macOS, Linux) or 'Reply from' (Windows).

4. Log in once with ssh, to confirm the password and to accept the Pager's identity:

   ```sh
   ssh root@172.16.52.1
   ```

   The first time, ssh asks whether you are sure you want to continue connecting. Type `yes` and
   press Enter. Then type the root password and press Enter. Nothing appears while you type the
   password; that is normal.

   **You should see** a command prompt from the Pager, usually ending in `#`.

5. Leave the Pager's prompt again:

   ```sh
   exit
   ```

   **You should see** your own computer's prompt again.

**If something goes wrong**

- *`ping` reports 'timeout', 'unreachable' or '100% packet loss':* the cable or Wi-Fi connection is
  not up, or the address is different. Check the connection and the address (step 2).
- *`Permission denied` after the password:* the password is wrong. It is the root password you
  chose during the Pager's first-time setup; try again. If you no longer know it, see Hak5's
  documentation.
- *`WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`:* this can follow a firmware reinstall. If you
  are sure the device on the cable is your Pager, remove the old entry with
  `ssh-keygen -R 172.16.52.1` and log in again.

---

## 3. Easy route: the installer script

**macOS and Linux only.** `tools/install.sh` is a shell script for a Unix-style computer. On
Windows, use the manual route in [section 4](#4-manual-route-step-by-step).

The installer copies seven files to the Pager: the collector, the page, the netcat page server, the
Overview and the payload, a second copy of the Overview that sits beside the payload, and the alert
companion `alert-deauth.sh` beside it (the Settings row 'Alerts' installs that one into the firmware's
alert tree on your press; the installer only places it). It checks
that each one arrived intact and runs Starchorus's own passive checks on the Pager. It asks for the
root password once; type it within about two minutes, because the Pager's `sshd` closes a connection
that waits longer, and the installer then reports that it could not authenticate and installed nothing
(run it again). With a key for the Pager in your `~/.ssh/config` it asks for nothing.

1. Show what it would do, without connecting to anything (a 'dry run'):

   ```sh
   sh tools/install.sh --dry-run
   ```

   **You should see** a table of files with their versions and target paths on the Pager, the line
   'DRY RUN: nothing is connected, nothing is copied', and a numbered list of the exact `ssh` and
   `scp` commands a real run would use. If the files you downloaded carry different versions (a page
   of one build with a collector of another), it stops here with an error and sends nothing; download
   the folder again as one.

2. Run it for real:

   ```sh
   sh tools/install.sh
   ```

   If your Pager has a different address, name it:

   ```sh
   sh tools/install.sh --host 192.0.2.10
   ```

3. Type the root password when asked ('connecting to root@… (enter the root password once)').

   **You should see** sections headed `==> the collector on the device`, `==> uploading`, `==> setting
   exec bits`, `==> renaming the 7 files into place`, `==> integrity`, `==> selftests on the
   device`, `==> one real passive capture` and `==> Overview smoke test`, with lines marked `[PASS]`
   in the checks. Near the end comes a line beginning `==> result:` that ends in `0 failed`.

The installer first asks the collector that is already on the Pager, read-only, whether a loop is running
(`==> the collector on the device`). If one is, you get a `!! [WARN]` line and the run goes on: stop
Starchorus first, as the update steps say, or the loop keeps running its old script until you stop it and
start it again. Each file goes up under its name plus `.new` and all seven are renamed into place with one
command at the end, so that a connection that drops in the middle leaves the old files where they were
(a `.new` file left behind is harmless; the next run replaces it).

The Pager has no `cksum`, so the `==> integrity` section is a single `[PASS]` line saying that the
device has none and that all seven files were read back and compared byte for byte. That is how
the installer checks them; it is not a warning.

A line marked `!! [WARN]` is a warning, not a failure; the installer repeats it in its closing
summary with an explanation. Go on to [section 5](#5-start-starchorus).

**If something goes wrong**

- *'cannot reach or authenticate on root@…':* go back to [section 2](#2-connect-to-the-pager) and
  check that `ssh root@172.16.52.1` works by hand.
- *'source file missing' or 'cannot read the version':* the download is incomplete. Download it
  again ([section 1](#1-download-starchorus)) and run the script from the top folder.
- *'INSTALL NOT VERIFIED':* one of the checks failed. The lines marked `!! [FAIL]` say which. Run the
  installer again; if it fails the same way, see [section 8](#8-troubleshooting). The installer's
  output contains no network names or addresses of other people, so you may paste it into an issue.
- `sh tools/install.sh --help` lists the options.

---

## 4. Manual route, step by step

Use this on Windows, or if you prefer to see each step. It does what the installer does, without
the checks. Type each command on one line, exactly as shown.

The Pager has no SFTP service, so `scp` is given `-O` to use the older copying method.

1. Create the two folders on the Pager:

   ```sh
   ssh root@172.16.52.1 'mkdir -p /root/loot/starchorus /root/payloads/user/reconnaissance/starchorus'
   ```

   **You should see** a password prompt, then your own prompt again with no message.

2. Copy the collector, the Overview and the netcat page server:

   ```sh
   scp -O starchorus-collect.sh starchorus-display.sh starchorus-serve.sh root@172.16.52.1:/root/loot/starchorus/
   ```

   **You should see** one line per file, each reaching 100%.

3. Copy the page, renamed to `index.html`:

   ```sh
   scp -O starchorus.html root@172.16.52.1:/root/loot/starchorus/index.html
   ```

   **You should see** one line reaching 100%.

4. Copy the payload, its copy of the Overview and the alert companion:

   ```sh
   scp -O library/user/reconnaissance/starchorus/payload.sh library/user/reconnaissance/starchorus/starchorus-display.sh library/user/reconnaissance/starchorus/alert-deauth.sh root@172.16.52.1:/root/payloads/user/reconnaissance/starchorus/
   ```

   **You should see** three lines, each reaching 100%.

5. Make the scripts runnable:

   ```sh
   ssh root@172.16.52.1 'chmod +x /root/loot/starchorus/*.sh /root/payloads/user/reconnaissance/starchorus/*.sh'
   ```

   **You should see** your own prompt again with no message.

6. Run the collector's self-test on the Pager:

   ```sh
   ssh root@172.16.52.1 'sh /root/loot/starchorus/starchorus-collect.sh --selftest'
   ```

   **You should see** a final line containing `SELFTEST: ALL PASS`. The self-test uses built-in
   sample data and does not touch the radio.

**If something goes wrong**

- *`scp: unknown option -- O`:* your `scp` is older and already uses the older method. Repeat the
  step without `-O`.
- *`scp` reports a 'subsystem request failed' or 'sftp' error:* you left out `-O`. Repeat the step
  with it.
- *'No such file or directory' for a local file:* your terminal is not in the Starchorus folder. See
  the end of [section 1](#1-download-starchorus).
- *'Permission denied' when running a script:* step 5 was missed. Run it, then try again.

---

## 5. Start Starchorus

Choose **one** of the two ways.

**A. From the Pager's payload menu**

1. On the Pager's dashboard, open **Payloads** (move with the D-pad, select with the green A
   button; the red B button goes back).
2. Open the category **Reconnaissance**.
3. Choose **Starchorus**.
4. The menu is titled 'Starchorus: Stopped'. Choose **Start**; nothing asks for confirmation.

**You should see** the spinner 'Starting' stay up until the first capture has been written. The payload
waits at most 20 seconds for it, and the first capture can take up to half a minute. Then the Overview
opens on the Pager's display: the line 'Overview', 'Reading...', and a summary with counts of access points
by band, ending with the time of the scan ('Last scan 12:04:31 (42 s ago)') and the keys ('A: Refresh   B: Back').
If the first scan is late, it reads 'Waiting for the first scan.' instead; key A looks again. If the capture file is there but cannot be read (cut off, or not JSON), it reads 'Capture unreadable.' instead. The screen
never changes by itself: key A draws it again, Left and Right step through the other screens, and key B
goes up one level, to the list of screens and from there to the menu, now titled 'Starchorus: Running'.

While Starchorus runs, the menu offers 'Overview', 'Open on Phone' (a QR code of the page's address
for a phone on the Pager's Wi-Fi, with firmware 1.1.1 or later; on an older firmware the address is
shown as text, and without a network address the payload says 'No network address.'; 'Start Web Page'
takes its place while the page server is not up), 'Stop' and 'Settings' (web page, refresh interval,
time window, vendor names, channel load, traffic, Bluetooth, alerts, port, and a reset to the defaults). 'Traffic'
(channel activity and frame rates) and 'Bluetooth' (a passive Bluetooth LE scan, 5 seconds per refresh) are
off by default; switch them on only if you want those layers. A change in Settings is
applied when you leave it, except 'Web Page', which takes effect at once. Key B on the menu leaves the
payload and keeps Starchorus running. The
[payload's README](library/user/reconnaissance/starchorus/README.md#operation) describes every item.

When you open the payload, it compares the version and the `# Contract:` number of the installed
collector and Overview with its own. If they differ, a dialogue says so once ('Installed …,
payload …' or 'Installed files differ from the payload.') and tells you what to do; see
[section 7](#7-stop-update-uninstall).

**B. From your computer, over ssh**

1. Start it:

   ```sh
   ssh root@172.16.52.1 '/root/payloads/user/reconnaissance/starchorus/payload.sh start'
   ```

   **You should see** a line such as 'Starchorus (passive) -> http://172.16.52.1:8199/ (nc
   mini-server)'. The words in brackets appear when the netcat server serves the page.

2. Check that it is running:

   ```sh
   ssh root@172.16.52.1 '/root/payloads/user/reconnaissance/starchorus/payload.sh status'
   ```

   **You should see** a line containing `loop RUNNING` (the collector) and the line
   `Page: 172.16.52.1:8199 running`. A line saying `airodump not running` is normal.

Started this way, the Overview does not open on the Pager's display; it opens only from the
payload menu.

**For a long session**, follow Hak5's own advice
([Welcome to the WiFi Pineapple Pager](https://documentation.hak5.org/wifi-pineapple-pager/setup/welcome-to-the-wifi-pineapple-pager)):
the battery lasts an estimated four hours per charge, so charge it fully before you start; for
longer, run the Pager from a USB battery bank with a high-quality USB-C cable, starting full and
staying connected; and keep the vents clear, because the Pager runs warm. Use a cable that carries
data, not only charge (section 0), if the same cable also connects your computer.

**If something goes wrong**

- *'Starchorus is not installed.' on the Pager, or 'Starchorus not installed in
  /root/loot/starchorus' over ssh:* the files from step 2 of the manual route are missing. Install
  again (section 3 or 4).
- *'Could not start.':* the collector did not come up. The red line under it is the last line of
  `/root/loot/starchorus/collect.log`; run the installer again (section 3), which checks the
  collector on the Pager.
- *'no service on':* the page is switched off (`page=off`) and `STARCHORUS_COLLECTOR=0` is set in the
  environment. Unset the variable; `payload.sh reset` returns the settings file to its defaults.
- *'No web server found.' (on the Pager) or 'no web server for the page' (over ssh):* the payload
  found no program to serve the page, not even `nc`. The collector still runs and the Overview
  works; see 'The page server' in [section 6](#6-open-the-page-in-a-browser).
- *'Web page did not start. Port … may be in use.':* another program holds the port. Choose another
  under Settings → Port, or stop the other program.
- *Starchorus does not appear under Reconnaissance:* the payload went to the wrong folder. Repeat
  steps 1, 4 and 5 of the manual route.

---

## 6. Open the page in a browser

1. On the computer connected to the Pager, open your browser.
2. Go to this address:

   ```text
   http://172.16.52.1:8199/
   ```

**You should see** the night sky. The page starts with a sample marked 'Sample', and the chip
switches to 'Live' once it has read the Pager's first capture. The page then refreshes as each new
capture arrives.

Any phone or laptop on the Pager's management network can open the same address. On a phone, choose
'Open on Phone' in the payload menu for a QR code of it; the page then shows the sky under a narrow
status bar, with the controls in a bottom sheet. By default the page is reachable over USB-C and the
management Wi-Fi only, not from a network the Pager has joined.

**The page server.** The payload serves the page with `uhttpd` or `python3` where the Pager has one
of them, and otherwise with the small netcat server it carries (`starchorus-serve.sh`). A Pager
that has had its system update has neither, so the netcat server is the normal case there. It
answers one request at a time, which suits one browser; a second device is served after the first.
`uhttpd` and `python3` are given `/root/loot/starchorus/www`, a directory of two links (the page and the capture) that the
payload makes itself, so the settings, the pid files and the logs are not served; if `www` is something else (a file, a link, a
directory with other entries) the payload does not use them and says so.
If `payload.sh status` shows `Page: 172.16.52.1:8199 not running`, the page server did not start:
'Start Web Page' in the menu tries again and says if the port is taken. For several viewers at once,
or when no server can run on the Pager, you have two choices, both described in
[docs/display-paths.md](docs/display-paths.md):

- **Route A:** install `uhttpd` on the Pager once, from a package downloaded on a computer with
  internet access.
- **Route B:** serve the page from your own computer and fetch `starchorus.json` from the Pager at
  regular intervals.

**If something goes wrong**

- *The page does not load at all:* check `payload.sh status` (section 5). Use `http://`, not
  `https://`, and include `:8199`.
- *The chip stays on 'Sample':* the collector has not written a capture yet. Wait half a minute and
  reload.
- *The chip shows 'Stale':* no new capture has arrived for twice the collector's interval plus 15
  seconds (75 seconds with the payload's 30-second interval). Check that the collector is running
  (section 5).
- *The chip shows 'Offline':* the page has had no answer from the Pager for as long. Check that the
  phone or computer is on the Pager's Wi-Fi and that the page server is running (section 5).
- *You changed the port under 'Settings':* use that port in the address instead of 8199.

---

## 7. Stop, update, uninstall

**Stop** (choose one):

- On the Pager: payload menu → Reconnaissance → Starchorus → **Stop**.
- From your computer:

  ```sh
  ssh root@172.16.52.1 '/root/payloads/user/reconnaissance/starchorus/payload.sh stop'
  ```

  **You should see** 'Starchorus stopped'.

Stopping ends only Starchorus's own collector and page server, never the Pager's own web interface.

The terminal in Hak5's [Virtual Pager](https://documentation.hak5.org/wifi-pineapple-pager/connecting-to-the-wifi-pineapple-pager/virtual-pager)
(`http://172.16.52.1:1471` in a browser, the same root password) is the same shell as ssh. So
`payload.sh stop`, `payload.sh status` and the uninstall below can be typed there, without the
`ssh root@172.16.52.1` in front. Installing still goes through section 3 or 4.

**Update**

1. Stop Starchorus (above).
2. Download the new version ([section 1](#1-download-starchorus)). With git, run `git pull` in the
   folder instead.
3. Replace all seven files, by the route you used before: the installer (section 3) and the manual
   route (section 4) both copy all seven. With the payload directory from Hak5's library, copy the new
   directory over the old one and delete `/root/loot/starchorus/starchorus-collect.sh`; the payload
   then copies its bundle into `/root/loot/starchorus` again. The installer replaces each file by renaming a new one onto it,
   and your settings in `/root/loot/starchorus/settings.conf` are kept either way.
4. Start it again (section 5). The first start after an update takes a little longer: the collector
   splits the vendor (OUI) list into an index once, so the first capture comes later than usual.

Replace all seven, not only the payload. The payload compares the installed collector and Overview,
and the companion alert in the firmware's alert tree while Alerts is ON, with itself when it opens,
by version and by their `# Contract:` number, the interface the payload, the collector, the Overview
and the companion alert share, and the installed netcat server and page by version. When they differ, it says so once, in a dialogue: 'Installed
…, payload …' for another version, 'Installed files differ from the payload.' for the same version
with another contract. The dialogue names the remedy: 'Run tools/install.sh.', or, with the Hak5
library copy, which has no `tools` folder on the Pager, the collector file to delete; for the
companion alert, whose copy in the alert tree only the Alerts row replaces, 'Switch Alerts off, then on.' A payload
replaced on its own is caught at the same version too. Files from the first release carry no
Contract line and count as contract 1. The netcat server and the page have no contract line, so only
their version is compared (as of 24 October 2026; the dialogue is the same and appears once, for the
first file that differs). The installer refuses to install files that disagree with each other.

**Uninstall**

The repository has no uninstaller; Starchorus lives in the two folders created during installation,
and in two more places if you also installed the alert companion into the firmware's alert tree, by the Settings row 'Alerts' or by hand (its file there, and its log directory)
([README](README.md#alerts)).

1. Stop Starchorus (above).
2. If you installed the alert companion, remove it first, so that no later alert can write its log again
   (the firmware runs it for each alert, and it creates `/root/loot/starchorus-alerts` if that is missing):

   ```sh
   ssh root@172.16.52.1 'rm -rf /root/payloads/alerts/deauth_flood_detected/starchorus'
   ```

3. Remove both folders and the alert log directory (`alerts.log` and `alerts.lock`: the addresses of other people's equipment):

   ```sh
   ssh root@172.16.52.1 'rm -rf /root/loot/starchorus /root/loot/starchorus-alerts /root/payloads/user/reconnaissance/starchorus'
   ```

This deletes the collected `starchorus.json`, your saved settings and the alert log, and cannot be undone. The log's
place is fixed (`/root/loot/starchorus-alerts`): the companion takes no directory from your environment.

**Recovery, reset and system updates.** Starchorus lives under `/root`. As Hak5 documents it, a
[firmware recovery](https://documentation.hak5.org/wifi-pineapple-pager/firmware-recovery) rewrites the boot flash only, so `/root` stays; a
[factory reset](https://documentation.hak5.org/wifi-pineapple-pager/factory-reset) erases it, so install again afterwards; and a
[system update](https://documentation.hak5.org/wifi-pineapple-pager/software-updates/software-updates) keeps it.

---

## 8. Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| ssh warns 'REMOTE HOST IDENTIFICATION HAS CHANGED' after a system update | the update gave the Pager new SSH host keys | if you have just updated the Pager yourself, run `ssh-keygen -R 172.16.52.1` and connect again |
| after a system update the page is served by the netcat server | the update removed `uhttpd`; the payload serves the page with its small netcat server, one request at a time | nothing to do for one viewer; for several at once add `uhttpd` again ([docs/display-paths.md](docs/display-paths.md), route A) |
| `ping` gets no reply | cable or Wi-Fi not connected, or a different address | check the connection; check the address in Hak5's documentation ([section 2](#2-connect-to-the-pager)) |
| `ssh` says 'Connection refused' or 'timed out' | wrong address, or the Pager is still starting | wait a minute, check the address, try again |
| `Permission denied` after the password | wrong root password | see Hak5's documentation |
| 'REMOTE HOST IDENTIFICATION HAS CHANGED' | the Pager was reinstalled | `ssh-keygen -R 172.16.52.1`, then log in again |
| `scp` fails with an 'sftp' or 'subsystem' error | `-O` left out | add `-O` ([section 4](#4-manual-route-step-by-step)) |
| `scp: unknown option -- O` | older `scp` | leave `-O` out |
| Starchorus is not in the payload menu | payload copied to the wrong folder | repeat the manual route, steps 1, 4 and 5 |
| `Page: 172.16.52.1:8199 not running` | the page server did not start or has ended: the port is taken, or no server program was found | 'Start Web Page' in the menu; another port under Settings; or route B in [docs/display-paths.md](docs/display-paths.md) |
| the page does not load while another device is loading it | the netcat server answers one request at a time | wait a moment and reload; for several viewers at once install `uhttpd` (route A) or use route B |
| the installer warns 'collector --once exited 1' | the collector did not publish this cycle's document: there is no usable source, or the data directory cannot be made or written (full, or read-only), or the copy of the recon database could not be read | read the lines the installer prints above the warning; free space on the Pager, then run the installer again |
| chip stays on 'Sample' | no capture yet | wait half a minute, reload; check `payload.sh status` |
| chip shows 'Stale' | no new capture for twice the collector's interval plus 15 seconds: the collector has stopped | start it again ([section 5](#5-start-starchorus)) |
| chip shows 'Offline' | the Pager has answered nothing for as long: the device is off the Pager's Wi-Fi, or the page server has stopped | join the Pager's Wi-Fi again; check `payload.sh status` |
| the Overview shows 'jq incomplete' in red | an Overview filter failed on the Pager | run the installer again and report its output in an issue |
| the Overview shows 'No new scan for …' in red | the collector stopped writing | go back with B (twice from a screen: to the list of screens, then to the menu); the menu then says whether it still runs |
| the Overview shows 'This scan took over 20 s to read.' | 'Show Last' under 'Settings' is too long for the Pager's CPU | choose a shorter time (the default is 1 h) |
| a dialogue says 'Installed …, payload …' or 'Installed files differ …' | the payload and the files in `/root/loot/starchorus` come from different builds (another version, or another `# Contract:` number) | replace all seven files: run the installer again (section 3); with the Hak5 library copy, delete `/root/loot/starchorus/starchorus-collect.sh` and open the payload again |

When you report a problem, never post real network names, MAC addresses or capture files. The
installer's output is safe to paste; the contents of `starchorus.json` are not.

---

## 9. Try it without a Pager

You can see the page with simulated sample data on any computer that has Python 3.

1. In the Starchorus folder, start a small local web server:

   ```sh
   python3 -m http.server --bind 127.0.0.1 8000
   ```

   On Windows the command may be `python` or `py` instead of `python3`.

   **You should see** a line saying it is serving HTTP on port 8000.

2. Open this address in your browser:

   ```text
   http://127.0.0.1:8000/
   ```

   **You should see** the sky with sample networks. With no data file present, the page runs its
   built-in demonstration; nothing is received or transmitted.

3. Press `T` to cycle through the three themes, and `?` to see every key.

4. To stop the server, return to the terminal and press Ctrl-C.

**If something goes wrong**

- *'Address already in use':* another program is using port 8000. Use another number, for example
  `8001`, in both the command and the address.
- *`python3` not found:* install Python 3 from <https://www.python.org>, or use the other command
  names above on Windows.
