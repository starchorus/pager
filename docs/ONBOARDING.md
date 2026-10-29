# Onboarding

Starchorus is a strictly passive radio monitor for the WiFi Pineapple Pager: it receives, reads and
counts what the airwaves and the device's own services already hold, and draws it as a quiet page.
It sends nothing. This note is the short way in for someone new to the code. The reference material
it points to is the authority; this is only the map.

## Read in this order

1. [README.md](README.md): what Starchorus is and does, and how to install it.
2. [SECURITY.md](SECURITY.md): every path by which it touches a radio or a file, and why each is
   receive-only. This is the heart of the project.
3. [docs/architecture.md](docs/architecture.md): the full specification. The JSON contract, the
   page, the Overview, and section 14, the passivity contract in detail.
4. [docs/device-notes.md](docs/device-notes.md): the facts verified on the device (the recon
   database schema, the Bluetooth controller, the display commands, `jq`), and what is still open.
5. [CONTRIBUTING.md](CONTRIBUTING.md): the one rule, the two mandatory checks, and the shell
   conventions.

## The one rule

Starchorus **only receives**. It never transmits: no deauth, no rogue access point, no injection, no
association, no active scan, no Bluetooth inquiry. A change that adds an active path is declined,
even behind a switch. The rule is stated in [SECURITY.md](SECURITY.md) and
[CONTRIBUTING.md](CONTRIBUTING.md), and it is enforced by a tool, not by trust (see "The gates").

## The map

| Path | What it is |
|---|---|
| `starchorus-collect.sh` | The collector: a POSIX shell script that reads the recon database (a read-only copy), or listens in monitor mode, or reads the AP service's recon lists, and writes `starchorus.json`. The largest file; it carries its `awk` programs as shell strings. |
| `starchorus-display.sh` | The Overview: the on-device screen (eight screens), driven by the device's display commands and `jq`. A byte-identical copy lives under `library/.../starchorus/`. |
| `starchorus-serve.sh` | The page server: a small netcat listener that serves the page and the JSON on the device. |
| `payload.sh` | The Hak5 payload: starts and stops the collector and the server, and the menu. Its user copy is under `library/.../starchorus/`. |
| `starchorus.html` | The page: a single self-contained file, **built** from the fragments under `src/`, never edited by hand. |
| `src/` | The page's fragments (one per section, named by section number) and the build manifest. `sh tools/build-page.sh` joins them into `starchorus.html`. |
| `docs/` | The specification (`architecture.md`), the device notes (`device-notes.md`), the ways to reach the page (`display-paths.md`). |
| `tools/`, `tools/regress.d/` | The gates (below), the page build, the fixture generator, the installer, the device probe. |
| `library/` | The payload bundle laid out as it is for the Pager. |
| `packaging/` | How a release archive is built. |
| `tests/` | Fixtures and test data. |
| `.githooks/` | The pre-commit hook that runs the fast gate over what is staged. |

## The gates: the safety net

Starchorus is held to its contract by tools, not by review alone. A change that breaks the contract,
the JSON shape, or the agreement between the documents and the code turns a gate red, and the gate
is precise about what broke. Run them early.

- `sh tools/passivity-check.sh`: **the one mandatory check.** It reads every shell file and proves,
  among much else, that the page cannot send, that AP-service commands live only in the allowlisted
  functions, and that every `sqlite3` call is read-only. Seconds to run.
- `sh tools/quick.sh`: the Chrome-free tier (T1): shell parsing, the self-tests, the build rules,
  and more.
- `sh tools/quick.sh docs`: the documents mode, which binds the prose to the code (versions, the
  specification's tables, hand-typed lists and numbers). It needs Google Chrome.
- `sh starchorus-collect.sh --selftest` and `sh starchorus-display.sh --selftest`: offline
  self-tests with embedded sample data; no device needed.
- `sh tools/regress.sh <prefix>`: the full run (T2): everything, end to end. It needs Chrome.
- `sh tools/install-hooks.sh`: once per clone. After that the right tier runs on each commit over
  the staged state.

**A word on timing.** The full run is not quick, and a commit that stages the passivity
checker itself runs a mutation probe on top: tens of minutes, and longer on a slow or busy machine.
It is working, not hung; the parent process waits at near-zero CPU while its children do the work.
Give it time, and never pass `--no-verify`.

## Making a change

- **The page** is built from fragments. Edit the fragment under `src/css`, `src/html` or `src/js`
  (its name carries the section number), run `sh tools/build-page.sh`, and commit `src/` together
  with the rebuilt `starchorus.html`. A hand-edited page is red.
- **The collector and the Overview** run on the device under BusyBox `ash` and a cut-down `awk` and
  `jq`: POSIX only, no bashisms, no GNU-only flags, no `jq` regex builtins. Arithmetic is
  double-precision, so a large integer wants exact (string) handling, not plain `awk` maths.
  [CONTRIBUTING.md](CONTRIBUTING.md) has the full list.
- **Add a test** with every new function (a self-test case with invented sample data), and describe
  any device run in the pull request.
- **Never commit a real SSID or MAC.** Fixtures are made with `tools/gen-testdata.py`.

## The device

The target is the Hak5 WiFi Pineapple Pager (OpenWrt, BusyBox, a MIPS core). What is known about it
for certain, and what is not, is in [docs/device-notes.md](docs/device-notes.md);
`tools/device-probe.sh` answers open questions in a strictly read-only session. Almost all
development and testing can be done off the device, against the fixtures and the self-tests.
