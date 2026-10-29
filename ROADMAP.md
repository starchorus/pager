# Roadmap

The direction of travel, kept short. What has already landed is in [CHANGELOG.md](CHANGELOG.md);
this note looks forward. Nothing here is a promise of a date.

## Now

The 0.2 line is the current work: a strictly passive monitor with a page, an on-device Overview, an
alert companion, and the passivity contract enforced by the test nets. The most recent releases
hardened the passivity checker, added the release packaging, and adapted the code to the Pager's
2.0 firmware (the recon-list argument that 2.0 changed, reading the firmware's own Bluetooth
database as a passive source, and taking an access point's security from the 2.0 beacon records).

## Next

- **Test-data for the Bluetooth-database source.** A fixture for the firmware's Bluetooth source, so
  the test nets cover its document the way they cover the others; the contract validator learns the
  new `center.bt_source` field at the same time.
- **The open device questions in [docs/device-notes.md](docs/device-notes.md)** settle: each turns
  from "design" into "verified on the device", or into a change.

## Not planned

Active paths stay out, by the contract: no deauth, no rogue access point, no active scan, no
Bluetooth inquiry, no connection, no direction finding, no handshake capture. They are listed in
section 14.10 of [docs/architecture.md](docs/architecture.md). An idea that needs one of them is the
wrong project.

## How direction is decided

The owner sets the direction. A contributor with an idea opens an issue first (see
[CONTRIBUTING.md](CONTRIBUTING.md)); a passive, read-only improvement that respects the contract and
the test nets is welcome.
