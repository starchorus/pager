# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/doc-binding.sh -- the documentation is bound to the code.
#   spec §3.8 (the three theme token blocks) and §7.0a (the contrast table) are GENERATED from the code and compared deep-equal (tools/spec-sync.py --check) ·
#   every STARCHORUS function is named in §10 · every hotkey is in §9.6 · every query parameter is in §2.7 · the versions agree · CONTRIBUTING makes the passivity check mandatory
# Sourced by tools/regress.sh with cwd = repo root. Only DBN_* globals are set.

DBN_SPEC=docs/architecture.md
DBN_T="out/$P-dbn"; mkdir -p "$DBN_T"
sh tools/dump-themes.sh themes "$DBN_T/themes.json" 2>/dev/null; sh tools/dump-themes.sh contrast "$DBN_T/contrast.json" 2>/dev/null
DBN_O=$(python3 tools/spec-sync.py --check "$DBN_T/themes.json" "$DBN_T/contrast.json" "$DBN_SPEC" 2>&1); DBN_R=$?
rowif "spec binding: spec §3.8 (three token blocks, deep-equal) and §7.0a (contrast table) = the code [$(printf '%s' "$DBN_O" | head -n 1 | cut -c1-80)]" [ "$DBN_R" = 0 ]
[ "$DBN_R" = 0 ] || printf '%s\n' "$DBN_O" | sed 's/^/    /' | head -n 4
# spec-sync can fail: negative control — a changed token must be caught
DBN_NEG=$(python3 - "$DBN_T/themes.json" <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); d["whitehall"]["chrome"]["ink"]="#000001"
json.dump(d,open(sys.argv[1]+".neg","w"))
PY
)
python3 tools/spec-sync.py --check "$DBN_T/themes.json.neg" "$DBN_T/contrast.json" "$DBN_SPEC" >/dev/null 2>&1; DBN_NR=$?
if [ "$DBN_NR" = 1 ] && [ -z "$DBN_NEG" ]; then row "spec binding: spec-sync.py notices a changed token (negative control, exit $DBN_NR = 1)" PASS
else row "spec binding: spec-sync.py notices a changed token (negative control, exit $DBN_NR = 1)" FAIL; fi

# every STARCHORUS function is named in §10 (from "## 10." to "## 11.")
runq demo "?poll=0&spin=0&intro=0&debug=1" "out/$P-dbn-api" --wait 1 --fps 0 --eval 'JSON.stringify(Object.keys(STARCHORUS).filter(k=>k!=="_internals"&&k!=="version"))' >/dev/null 2>&1
DBN_API=$(evalv "out/$P-dbn-api.json" 1)
awk '/^## 10\. /{f=1} /^## 11\. /{f=0} f' "$DBN_SPEC" > "$DBN_T/s10.txt"
cat > "$DBN_T/miss.py" <<'PY'
import json, sys
names = json.load(sys.stdin)
t = open(sys.argv[1], encoding="utf-8").read()
print(",".join(n for n in names if (n + "(") not in t and ("`" + n + "`") not in t and (n + " ") not in t and (n + ",") not in t))
PY
DBN_MISS=$(printf '%s' "$DBN_API" | python3 "$DBN_T/miss.py" "$DBN_T/s10.txt" 2>/dev/null)
DBN_NAPI=$(printf '%s' "$DBN_API" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))' 2>/dev/null)
if [ -z "$DBN_MISS" ] && [ "${DBN_NAPI:-0}" -ge 90 ]; then row "spec binding: every STARCHORUS function ($DBN_NAPI) is named in §10 (missing: ${DBN_MISS:-none})" PASS
else row "spec binding: every STARCHORUS function ($DBN_NAPI) is named in §10 (missing: ${DBN_MISS:-none})" FAIL; fi

# every single-letter hotkey of the page's KEYS table is in §9.6
DBN_KEYS=$(awk '/^const KEYS = \[/,/^\];/' starchorus.html | grep -o 'key: "[A-Za-z]"' | sed 's/key: "\(.\)"/\1/' | sort -u | tr '\n' ' ')
awk '/^### 9\.6 /{f=1} /^### 9\.7 /{f=0} f' "$DBN_SPEC" > "$DBN_T/s96.txt"
DBN_KM=""; for DBN_K in $DBN_KEYS; do grep -q "\`$DBN_K\`" "$DBN_T/s96.txt" || DBN_KM="$DBN_KM $DBN_K"; done
if [ -z "$DBN_KM" ] && [ -n "$DBN_KEYS" ]; then row "spec binding: every hotkey ($DBN_KEYS) is in §9.6 (missing:${DBN_KM:- none})" PASS
else row "spec binding: every hotkey ($DBN_KEYS) is in §9.6 (missing:${DBN_KM:- none})" FAIL; fi

# every query parameter of the page is in §2.7 (query.intro0 -> ?intro, poll0 -> ?poll, demo1 -> ?demo, rm1 -> ?rm, debug1 -> ?debug)
DBN_Q=$(grep -o 'query\.[a-zA-Z0-9]*' starchorus.html | sed 's/query\.//' | sort -u | sed 's/^intro0$/intro/;s/^poll0$/poll/;s/^demo1$/demo/;s/^rm1$/rm/;s/^debug1$/debug/' | tr '\n' ' ')
awk '/^### 2\.7 /{f=1} /^### 2\.8 /{f=0} f' "$DBN_SPEC" > "$DBN_T/s27.txt"
DBN_QM=""; for DBN_P in $DBN_Q; do grep -q "?$DBN_P" "$DBN_T/s27.txt" || DBN_QM="$DBN_QM $DBN_P"; done
if [ -z "$DBN_QM" ] && [ -n "$DBN_Q" ]; then row "spec binding: every query parameter ($DBN_Q) is in §2.7 (missing:${DBN_QM:- none})" PASS
else row "spec binding: every query parameter ($DBN_Q) is in §2.7 (missing:${DBN_QM:- none})" FAIL; fi

# versions agree: the page, the spec's §10 listing, the display script (the full list of places is the version row of station-outputs.sh)
DBN_PV=$(grep -o 'version: "[0-9.]*"' starchorus.html | head -n 1 | sed 's/version: "\(.*\)"/\1/')
DBN_SV=$(grep -o '^  version: "[0-9.]*",' "$DBN_SPEC" | head -n 1 | sed 's/.*"\(.*\)".*/\1/')
DBN_GV=$(sed -n 's/^# Version:      \([0-9.]*\)$/\1/p' starchorus-display.sh | head -n 1)
if [ -n "$DBN_PV" ] && [ "$DBN_PV" = "$DBN_SV" ] && [ "$DBN_PV" = "$DBN_GV" ]; then row "spec binding: versions agree — page $DBN_PV = spec §10 $DBN_SV = display script $DBN_GV" PASS; else row "spec binding: versions disagree — page $DBN_PV / spec $DBN_SV / display script $DBN_GV" FAIL; fi
# CONTRIBUTING: ONE policy. The mandatory section names the passivity check as "must be green" for every PR and the full
# regression as green before the merge; no heading or sentence calls the checks as a whole "not a condition"/"not mandatory"
# (two sections with opposite positions side by side would each satisfy a bare word count).
DBN_CM=$(awk '/^## The passivity check is mandatory$/ { f = 1; next } /^## / { f = 0 } f' CONTRIBUTING.md | tr '\n' ' ')
DBN_CO=0; case $DBN_CM in *"sh tools/passivity-check.sh"*"must be green"*) DBN_CO=1 ;; esac
DBN_CR=0; case $DBN_CM in *"Before the merge"*"sh tools/regress.sh"*"must also be green"*) DBN_CR=1 ;; esac
DBN_CX=$(grep -ciE '^## .*(not a condition|not mandatory|no obligation)' CONTRIBUTING.md)
if [ "$DBN_CO" = 1 ] && [ "$DBN_CR" = 1 ] && [ "$DBN_CX" = 0 ]; then row "spec binding: CONTRIBUTING makes the passivity check mandatory for every PR and the regression mandatory before the merge, no heading says the opposite (passivity $DBN_CO, regress $DBN_CR, contrary headings $DBN_CX)" PASS
else row "spec binding: CONTRIBUTING makes the passivity check mandatory for every PR and the regression mandatory before the merge, no heading says the opposite (passivity $DBN_CO, regress $DBN_CR, contrary headings $DBN_CX)" FAIL; fi
# the display script's outputs are described where a reader looks for them: SECURITY.md (LOG lines only) and the payload's
# README (its seven screens, down to the last one, air quality)
DBN_PR=library/user/reconnaissance/starchorus/README.md
DBN_SS=$(grep -c 'LOG lines' SECURITY.md); DBN_HK=$(grep -c 'Overview (.starchorus-display.sh.): seven screens' "$DBN_PR"); DBN_HA=$(grep -c 'stations, air quality)' "$DBN_PR")
if [ "$DBN_SS" -ge 1 ] && [ "$DBN_HK" -ge 1 ] && [ "$DBN_HA" -ge 1 ]; then row "spec binding: SECURITY.md and the payload README describe the display outputs ($DBN_SS/$DBN_HK/$DBN_HA)" PASS
else row "spec binding: SECURITY.md and the payload README describe the display outputs ($DBN_SS/$DBN_HK/$DBN_HA)" FAIL; fi
