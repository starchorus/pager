# tools/bench -- measurements that can be run again

The CPU measurements of 24 October 2026 covered what Starchorus costs: the collector's cycle, the Overview's key wait, the open page. These are its
scripts, cleaned up so that the figures can be reproduced after a change. **They are not part of any gate.** `tools/quick.sh`, `tools/regress.sh`
and the Git hook neither run nor compile anything here, and no gate reads these files: shellcheck, the denylists and the passivity scope of the tools
name their files one by one and none of them names a file here. The one rule that would notice this directory is `doc-truth`, which asks that every
shell file of the repository is in the list the gates shellcheck; that is why the drivers are Python.

Every script follows the same rules.

- It reads **copies** (of the collector, the page, the fixtures) and **synthetic data**: addresses in `02:00:00:xx:xx:xx`, names such as `Fixture-017`,
  seeded generators. No real SSID or address is in any input or output.
- It writes **only under the output directory given on its command line**, and says which files.
- It needs **no device and no network** (the page benches serve `127.0.0.1` only) and sends nothing; the collector census runs the collector on
  its database source against a copy, with Bluetooth and Traffic off.
- Its header says what it measures, how to run it, what is **deterministic** (counts, output equality, md5) and what is **noise** (seconds, CPU
  percentages). Quote noise only as a **ratio between two rows of the same run**, repeated, and with the caveat below.
- Python runs as `python3 -B -I` (no bytecode written next to the sources, no user site), as the other tools do. There is no shell file in this
  directory: the shell files the gates shellcheck are listed by `tools/static.sh` (`tools/*.sh`, `tools/regress.d/*.sh`, `library/`, the payload
  scripts), and `doc-truth` asks that every shell file of the repository is in that list, so the drivers are written in Python. `census/rexec.c` is
  the one C file: it needs a C compiler (`cc`), and nothing in the gates compiles it.

| Script | Inputs | Outputs (under OUTDIR) | Reproducible? |
|---|---|---|---|
| `census/gen-recon.py` | OUT.db, NOW | a synthetic `recon.db` at the device's documented scale (29 APs and 299 stations in the window) | yes (seeded) |
| `census/gen-oui.py` | OUT.txt | a synthetic OUI file of 38,959 lines | yes (seeded) |
| `census/run-census.py` + `rexec.c` | a copy of the collector, the two files above, SECONDS, `full` or `skip` | `log.tsv` (one line per process the collector started), `rq.PID.sql` (its SQL batches) | **counts yes**; times to about +-10 percent |
| `census/seg.py` | `log.tsv` | per cycle: processes started, child CPU, the commands by CPU (stdout) | counts yes; times no |
| `census/bench-sql.py` | `recon.db` and `rq.PID.sql` from the census | `rq_base.sql`, `rq_one.sql`; base against one-scan variant (stdout) | output equality yes; milliseconds within about +-5 percent |
| `bt/bench-bt.py` | a copy of the collector, `tests/fixtures/btmon-window.txt` | the awk programs, `kept.txt`, `clean.txt`; grep, tr and awk times, md5 per variant (stdout) | md5 and counts yes; milliseconds no |
| `page/make-instr.py` | the built page | an instrumented copy of it (timers round named functions) | yes |
| `page/bench-page.py` | ROOT (`tools/cdp.py`, the page), a fixture, a viewport | `results.jsonl`: frames drawn, main-thread share, CPU by Chrome process type | **frame counts yes**; CPU only as a ratio, +-15 to 25 percent |
| `page/ab-pulse.py` | ROOT, rounds | `smooth.html`, `results.jsonl`; the live dot's pulse smooth against stepped (stdout) | ratio only |
| `page/agg.py` | one or more `results.jsonl` | mean CPU per label, repeats grouped (stdout) | arithmetic yes; inputs no |
| `page/bench-poll.py` | the instrumented page, a fixture | milliseconds of `STARCHORUS.load()` fresh and repeated, by function (stdout) | byte counts yes; milliseconds within about +-10 percent |
| `page/sim-poll.py` | none | polls per capture for four invented collectors (stdout) | yes (seeded); a restatement of the page's poll rules, so change it when they change |

## Running them

```sh
B=$(mktemp -d)                                   # any directory you like; nothing is written elsewhere
python3 -B -I tools/bench/census/run-census.py $B/census 20 full   # then: python3 -B -I tools/bench/census/seg.py $B/census/log.tsv
python3 -B -I tools/bench/census/bench-sql.py $B/census 60      # after the census above: it uses its database and SQL batches
python3 -B -I tools/bench/bt/bench-bt.py $B/bt 30
python3 -B -I tools/bench/page/ab-pulse.py $B/ab . 3            # needs Chrome; about four minutes
python3 -B -I tools/bench/page/bench-page.py $B/page . tests/fixtures/many-clients.json "?poll=0&intro=0&debug=1&scope=1" 390x844 3 1 8 gpu label=scope
python3 -B -I tools/bench/page/make-instr.py starchorus.html $B/instr.html
python3 -B -I tools/bench/page/bench-poll.py $B . $B/instr.html tests/fixtures/field-scale.json 1440x900 2 0
python3 -B -I tools/bench/page/sim-poll.py
```

`bench-page.py` takes `ROOT` as its second argument and only reads it; to measure a change, pass a copy of the repository (or `page=FILE` for a
copy of the page). The census runs the collector from a copy it makes in its output directory, never in place. Stop other work first if you can:
the figures below were taken with other jobs running.

## Figures

*Measured on the development machine (Apple silicon, macOS, headless Chrome, one-true-awk), 24 October 2026, under load, once each; the milliseconds
and percentages are noise-bound and are given to show that the scripts work and to give the order of magnitude, not as a baseline. Compare ratios
inside a run, never these numbers with a later run's. The counts are deterministic. Nothing was measured on the Pager.*

| Script | What it printed |
|---|---|
| `run-census.py` (20 s, `full`, interval 2 s, vendor on) | start-up 65 processes, 440 ms child CPU; then 25 processes and 45 to 56 ms child CPU for every full cycle (no address is vendor-resolvable, see `census/gen-recon.py`) |
| `run-census.py` (20 s, `skip`) | start-up 65 processes; the first cycle 27; then 12 processes and 13 ms for each skipped cycle |
| `bench-sql.py` (N=60) | outputs identical: True (42,737 bytes); the collector's batch 8.74 ms CPU (median), the one-scan variant 5.11 ms (-42 percent) |
| `bench-bt.py` (N=30) | 189,301 bytes in, 2,336 lines kept; grep 3.9 ms, tr 4.0 ms; awk 7.4 ms, v1 7.2 ms (97 percent), v2 7.0 ms (94 percent); output md5 `84881e98` for all three |
| `bench-poll.py` | `many-clients` (23,610 bytes): 2.06 ms fresh, 1.77 ms for the same capture again; `field-scale` (104,145 bytes): 4.07 ms and 3.26 ms; 0 errors |
| `sim-poll.py` | 2.47, 3.12, 2.77 and 5.96 polls per capture (4.5, 4.5, 5.5 and 9.9 a minute) |
| `bench-page.py` (8 s, GPU path, `many-clients`) | desktop 1440x900 running: 481 of 481 animation frames drawn; the phone's Scope at rest: **0 of 481** drawn; desktop paused (6 s run): 0 of 361 |
| `ab-pulse.py` (3 rounds, 12 s each, renderer + GPU process, core percent) | desktop sky paused: smooth pulse 14.4 (13.9 to 15.0), stepped 3.1 (2.8 to 3.3); phone Scope at rest: smooth 9.1 (8.3 to 9.8), stepped 2.4 (2.3 to 2.4); about -78 and -74 percent |

What each result is for: the census and `bench-sql.py` stand behind the collector's cycle cost (and the saving a single scan of `ssid` would bring: the collector's batch scans it six times), `bench-bt.py`
behind the Bluetooth parse, `bench-poll.py` and `sim-poll.py` behind the page's poll, and `ab-pulse.py` behind the stepped pulse of the live dot
(`docs/architecture.md`, liveness; `tools/regress.d/phone.sh` pins that no infinite CSS animation of the page at rest is smooth). What only the
device can show (ticks of the Overview's process tree, the pid counter over a minute) is listed in `docs/device-notes.md` sections 6a and 7 (the device to-do list), not here.
