# Contributing to Starchorus

Thank you for your interest. Starchorus is a **strictly passive** observation tool, and that is not
open to negotiation. Contributions are welcome as long as they respect this boundary.

## The hard rule first

**Receive only. Never transmit.** Pull requests that add active or offensive functions will be
declined, even as an option and even behind a switch. Specifically, the following is not accepted:

- deauth/disassoc, rogue or evil-twin APs, packet injection, association with other people's networks,
- active functions of the device's AP service, broadcasting the SSID pool, jamming,
- anything that sends frames to force a result.

Only receiving is permitted: reading the recon database read-only (a copy, `sqlite3 -readonly`),
receiving in monitor mode (`tcpdump`/`airodump-ng` without injection), and tuning the receiver to a
channel. `iw scan` sends probe requests and counts as active; it stays behind
`STARCHORUS_ALLOW_ACTIVE=1` and is off by default. The details are in [SECURITY.md](SECURITY.md).

## The passivity check is mandatory

Before every pull request, `sh tools/passivity-check.sh` is run and must be green. Among other
things, the check requires that the page has no way to send (`fetch(` exactly once, on
`starchorus.json`; no `method:`/`POST`/`XMLHttpRequest`/`WebSocket`/`EventSource`/`sendBeacon`), that
commands of the AP service appear only in the allowlisted functions `apcli_ro`, `apcli_stub` and
`apcli_selftest`, that `iw scan` appears only behind the opt-in, and that every `sqlite3` call
carries `-readonly`. That is the one condition for every contribution.

Before the merge, `sh tools/regress.sh <prefix>` must also be green: build rules, passivity at run
time, legal and neutral language, privacy, layout, Overview = page, specification = code. The full
run needs Google Chrome and takes over 20 minutes; if nobody else has, the maintainer runs it.

A new read or output path is described in [SECURITY.md](SECURITY.md) and in the [README](README.md)
before it is merged.

## Quality requirements

The collector and the Overview run on the device (OpenWrt, BusyBox). Contributions to the shell
code must:

- **work with POSIX and BusyBox `ash`**: no bashisms, no GNU-only flags. Check against
  `busybox ash -n` and real BusyBox `awk`.
- **be clean under `shellcheck -s sh`** (`disable` directives with a stated reason are fine).
- **keep `sh starchorus-collect.sh --selftest` and `sh starchorus-display.sh --selftest` green.**
  New functions get a self-test case with embedded sample data (no real device needed).
- in the Overview, **not call any of `jq`'s regex builtins** (`test`, `match`, `sub`, `gsub`,
  `capture`, `scan`, `splits`, `split` with flags): the device's `jq` is built without a regex
  library.
- keep both copies of `starchorus-display.sh` (root and `library/…/starchorus/`) **byte-identical**.
- not break the **JSON contract**: `{generated, center, source, aps[], unassociated[]}` with stable
  fields, new fields only additively; write atomically (temporary file, then `mv`); degrade cleanly
  down to the empty `none` document.

For `starchorus.html`, please send only genuine bug fixes that do not change behaviour, and check the
JavaScript with a syntax check. The specification and the page stay in step: every `STARCHORUS`
function is in §10, every key in §9.6 and every query parameter in §2.7 of
[docs/architecture.md](docs/architecture.md).

Do not commit real SSIDs or MACs captured from the surroundings, only obviously invented sample data
(fixtures are made with `tools/gen-testdata.py`; see
[tools/README.md](tools/README.md#fixtures)).

**Conventions:** documentation and code comments are in English. Every original source file carries
`SPDX-License-Identifier: GPL-3.0-or-later` as a comment near the top (after a shebang or after
`<!doctype html>`); the exceptions are JSON fixtures, the denylists under `tools/` (they must not
contain comments), `tools/env-expected.txt` (a data file compared line by line) and `OFL.txt`.

## Further checking tools (optional)

Beyond the two mandatory checks, everything here is offered to contributors, not required of them:

- `sh tools/quick.sh`: the Chrome-free checks, in seconds.
- `sh tools/install-hooks.sh`: once per clone; after that, `quick.sh` runs on the staged state with
  every commit that touches code, tests or tools.
- `sh tools/verify.sh starchorus.html demo out/demo`: load the page headless in Chrome and check it.

What the test nets prove, and what they do not, is set out in [tools/README.md](tools/README.md). A
pull request is not declined for arriving without tests.

## Licensing of your contributions

Starchorus is licensed under GPL-3.0-or-later and is also licensed commercially on request. So that
this remains possible with contributions from others, the following applies when you submit a pull
request:

1. You license your contribution under `GPL-3.0-or-later`.
2. In addition, you grant the maintainer of Starchorus (the owner of the `starchorus`
   organisation on GitHub) the non-exclusive, perpetual, irrevocable, worldwide and
   royalty-free right to use, modify and distribute your contribution under other licence terms as
   well, including commercially. You retain your own copyright; you remain free to use your
   contribution yourself as you wish.
3. You confirm that the contribution is your own or that you hold the rights to contribute it on
   these terms, and that it contains no code under a licence incompatible with them.

If you do not agree to this, please describe your idea in an issue rather than in a pull request.

## Workflow

1. Open an issue, or comment on an existing one, so that work is not duplicated.
2. Fork the repository and create a feature branch.
3. Make the change; run `sh tools/passivity-check.sh`, the self-tests and `shellcheck`; test on the
   device if you can, and describe the result in the pull request (commands and output).
4. Open the pull request: what and why, and confirmation that passivity is preserved.

## Device knowledge

Facts verified on the device (the recon database schema, the `encryption` bits, interfaces,
display, `jq`) are in [docs/device-notes.md](docs/device-notes.md); the ways to reach and display
Starchorus are in [docs/display-paths.md](docs/display-paths.md). `tools/device-probe.sh` answers
open device questions in a strictly read-only session.

## Responsibility

Radio monitoring is regulated differently from country to country. Use and test Starchorus only in
your own environments or in ones you are expressly authorised to use. The recon database contains
other people's MAC addresses and SSIDs; handle this data with care and do not publish it.
