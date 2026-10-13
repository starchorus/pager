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

**You should see** `starchorus.html`, `starchorus-collect.sh`, `payload.sh`, `tools` and
`library` among the names listed.

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

The installer copies the collector, the page, the dashboard, the fallback server and the payload to
the Pager, checks that each file arrived intact, and runs Starchorus's own passive checks on the
Pager. It asks for the root password once.

1. Show what it would do, without connecting to anything (a 'dry run'):

   ```sh
   sh tools/install.sh --dry-run
   ```

   **You should see** a table of files with their versions and target paths on the Pager, the line
   'DRY RUN: nothing is connected, nothing is copied', and a numbered list of the exact `ssh` and
   `scp` commands a real run would use.

2. Run it for real:

   ```sh
   sh tools/install.sh
   ```

   If your Pager has a different address, name it:

   ```sh
   sh tools/install.sh --host 192.0.2.10
   ```

3. Type the root password when asked ('connecting to root@… (enter the root password once)').

   **You should see** sections headed `==> uploading`, `==> integrity`, `==> selftests on the
   device`, `==> one real passive capture` and `==> dashboard smoke test`, each followed by lines
   marked `[PASS]`. Near the end comes a line beginning `==> result:` that ends in `0 failed`.

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

2. Copy the collector, dashboard and fallback server:

   ```sh
   scp -O starchorus-collect.sh starchorus-display.sh starchorus-serve.sh root@172.16.52.1:/root/loot/starchorus/
   ```

   **You should see** one line per file, each reaching 100%.

3. Copy the page, renamed to `index.html`:

   ```sh
   scp -O starchorus.html root@172.16.52.1:/root/loot/starchorus/index.html
   ```

   **You should see** one line reaching 100%.

4. Copy the payload and its copy of the dashboard:

   ```sh
   scp -O library/user/reconnaissance/starchorus/payload.sh library/user/reconnaissance/starchorus/starchorus-display.sh root@172.16.52.1:/root/payloads/user/reconnaissance/starchorus/
   ```

   **You should see** two lines, each reaching 100%.

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
4. Choose **Start**. Confirm when the Pager asks 'Start collector, web page?'.

**You should see** the dashboard on the Pager's display after a moment: a summary with counts of
access points by band. Key B opens the dashboard's menu.

The payload's menu also offers 'Services' (what 'Start' starts), 'Options' (time window, interval,
port and more), 'Status', 'Stop' and 'Exit'. Leaving with 'Exit' keeps Starchorus running. The
[payload's README](library/user/reconnaissance/starchorus/README.md#operation) describes every item.

**B. From your computer, over ssh**

1. Start it:

   ```sh
   ssh root@172.16.52.1 '/root/payloads/user/reconnaissance/starchorus/payload.sh start'
   ```

   **You should see** a line such as 'Starchorus (passive) -> http://172.16.52.1:8199/'.

2. Check that it is running:

   ```sh
   ssh root@172.16.52.1 '/root/payloads/user/reconnaissance/starchorus/payload.sh status'
   ```

   **You should see** a line containing `loop RUNNING` (the collector) and the line
   `Page: 172.16.52.1:8199 running`. A line saying `airodump not running` is normal.

Started this way, the dashboard does not open on the Pager's display; it opens only from the
payload menu.

**If something goes wrong**

- *'Starchorus not installed in /root/loot/starchorus':* the files from step 2 of the manual route
  are missing. Install again (section 3 or 4).
- *'no service on':* both services were switched off under 'Services'. Switch at least one on, or
  run `payload.sh reset` on the Pager to return every setting to its default.
- *'no web server for the page':* the Pager has no web server for Starchorus. The collector still
  runs; see 'No web server' in [section 6](#6-open-the-page-in-a-browser).
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
switches to 'Live' once it has read the Pager's first capture. The page then refreshes every 5
seconds.

Any phone or laptop on the Pager's management network can open the same address. By default the
page is reachable over USB-C and the management Wi-Fi only, not from a network the Pager has joined.

**No web server.** The payload serves the page with `uhttpd` if it is present on the Pager, and
otherwise with a small fallback server that is reliable only for single requests, not for a
browser. If Status shows `Page: 172.16.52.1:8199 not running`, or the page loads only in part, you have two
choices, both described in [docs/display-paths.md](docs/display-paths.md):

- **Route A:** install `uhttpd` on the Pager once, from a package downloaded on a computer with
  internet access.
- **Route B:** serve the page from your own computer and fetch `starchorus.json` from the Pager at
  regular intervals.

**If something goes wrong**

- *The page does not load at all:* check Status (section 5). Use `http://`, not `https://`, and
  include `:8199`.
- *The chip stays on 'Sample':* the collector has not written a capture yet. Wait half a minute and
  reload.
- *The chip shows 'Stale':* no new capture has arrived for about 30 seconds. Check that the collector
  is running (section 5).
- *You changed the port under 'Options':* use that port in the address instead of 8199.

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

**Update**

1. Stop Starchorus (above).
2. Download the new version ([section 1](#1-download-starchorus)). With git, run `git pull` in the
   folder instead.
3. Install again by the route you used before (section 3 or 4). Files are overwritten in place;
   your settings in `/root/loot/starchorus/settings.conf` are kept.
4. Start it again (section 5).

**Uninstall**

The repository has no uninstaller; Starchorus lives entirely in the two folders created during
installation.

1. Stop Starchorus (above).
2. Remove both folders:

   ```sh
   ssh root@172.16.52.1 'rm -rf /root/loot/starchorus /root/payloads/user/reconnaissance/starchorus'
   ```

This deletes the collected `starchorus.json` and your saved settings as well, and cannot be undone.

---

## 8. Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| `ping` gets no reply | cable or Wi-Fi not connected, or a different address | check the connection; check the address in Hak5's documentation ([section 2](#2-connect-to-the-pager)) |
| `ssh` says 'Connection refused' or 'timed out' | wrong address, or the Pager is still starting | wait a minute, check the address, try again |
| `Permission denied` after the password | wrong root password | see Hak5's documentation |
| 'REMOTE HOST IDENTIFICATION HAS CHANGED' | the Pager was reinstalled | `ssh-keygen -R 172.16.52.1`, then log in again |
| `scp` fails with an 'sftp' or 'subsystem' error | `-O` left out | add `-O` ([section 4](#4-manual-route-step-by-step)) |
| `scp: unknown option -- O` | older `scp` | leave `-O` out |
| Starchorus is not in the payload menu | payload copied to the wrong folder | repeat the manual route, steps 1, 4 and 5 |
| `Page: 172.16.52.1:8199 not running` | no web server on the Pager | route A or B in [docs/display-paths.md](docs/display-paths.md) |
| page loads in part or not at all | the fallback server serves one request at a time | install `uhttpd` (route A) or use route B |
| chip stays on 'Sample' | no capture yet | wait half a minute, reload; check Status |
| chip shows 'Stale' | collector stopped | start it again ([section 5](#5-start-starchorus)) |
| dashboard shows 'jq incomplete' in red | a dashboard filter failed on the Pager | run the installer again and report its output in an issue |
| the Pager's display stops updating | the time window under 'Options' is too large | choose a shorter window (the default is 1 h) |

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
