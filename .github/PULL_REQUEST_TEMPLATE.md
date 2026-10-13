## What and why

<!-- Briefly: what changes and why. Refer to an issue, if there is one. -->

## Checklist

- [ ] Receive only: no new way to send (no frames, no probe requests, no new request from the page).
- [ ] `sh tools/passivity-check.sh` is green.
- [ ] `sh tools/quick.sh` is green; for changes to the page, `sh tools/regress.sh <prefix>` as well.
- [ ] Both copies of `starchorus-display.sh` are byte-identical (root and `library/…/starchorus/`).
- [ ] No real captured data: no real SSIDs, MAC addresses or capture files, only the demo or synthetic fixtures.
- [ ] New original source files carry `SPDX-License-Identifier: GPL-3.0-or-later`.
- [ ] I agree to the [licensing of my contributions](https://github.com/starchorus/pager/blob/main/CONTRIBUTING.md#licensing-of-your-contributions) (GPL-3.0-or-later plus an additional right of use for the maintainer).

## Evidence

<!-- Commands and shortened output; replace MAC addresses and SSIDs with placeholders. -->
