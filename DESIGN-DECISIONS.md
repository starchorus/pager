# Design decisions

Why Starchorus is built the way it is. If you are about to change something and it seems needlessly
strict or roundabout, the reason is probably here.

## Strictly passive, with no exceptions

The project exists to watch the airwaves without touching them, and everything else follows from
this. Receiving is allowed (monitor mode, a read-only copy of the recon database, the AP service's
read-only lists, a passive Bluetooth scan, the firmware's own Bluetooth database); transmitting is
not, in any form, not even behind an off-by-default switch. The one marked exception, `iw scan`
(which sends probe requests), is opt-in, off by default, and labelled as active wherever its data
appears. The contract is not a convention: `tools/passivity-check.sh` checks it on every change, and
the checker itself is proven against deliberately broken copies so that it cannot be quietly
blinded. See section 14 of [docs/architecture.md](docs/architecture.md) and [SECURITY.md](SECURITY.md).

## Read a copy, never the live file

The recon database (and the firmware's Bluetooth database) is copied before reading and opened with
`sqlite3 -readonly`, so a capture is never locked and nothing is written to flash on the normal
path. The working copy lives in RAM and is removed after each cycle. The live file is not read in
place, because a long read would hold a lock that stalls the writer.

## The data sources are layered, and degrade

The collector follows an order of sources (a monitor interface it made itself, the recon database,
an existing monitor interface, and, only with the active opt-in, `iw scan`). Each extra reading
(Bluetooth, channel activity, alerts) is opt-in and off by default, because it depends on device
behaviour that has to be verified first. When a source gives nothing, the document degrades cleanly
to an empty one rather than failing.

## The page is a single built file, from fragments

The page ships as one self-contained `starchorus.html`, with no outward request but the one that
fetches its own JSON. It is built from per-section fragments under `src/` so that it can be worked
on in pieces, and the build is checked: a hand-edited page that is not the build of `src/` is red.

## The documents are bound to the code

The specification, the README and the device notes are not allowed to drift from the code. A set of
checks ties the version strings, the specification's tables, and hand-typed lists and numbers to
their source, so that a change which makes a document untrue turns a gate red. This is why the prose
is sometimes worded carefully: a count is spelt out or dated rather than left as a bare number that
a check would read as a claim.

## The test nets are the contract, mechanically

Review alone does not hold a passive tool passive. So the contract, the JSON shape, the
document-and-code agreement and the device assumptions are each a test that must stay green, and the
hardest of them (the passivity checker) is itself tested by planting violations and confirming each
is caught. The full run takes a while, and a change to the checker runs a slow mutation probe. That
cost is deliberate: it is what lets anyone extend the tool without quietly breaking its promise.

## Privacy and neutrality

The recon data holds other people's addresses and network names. They are never written to the
page's served directory on the normal path, never published in the repository, and the sample data
in the tests is invented. The language of the project is kept neutral and lawful; the checks refuse
real identifiers and flag loaded wording.
