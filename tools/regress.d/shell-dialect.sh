# SPDX-License-Identifier: GPL-3.0-or-later
# shellcheck shell=sh
# tools/regress.d/shell-dialect.sh -- every shell file of the scope parses under dash, the nearest thing to the BusyBox ash that the device runs.
# Chrome-free, dev machine only: `dash -n` reads each file and runs none of it. Sourced by tools/regress.sh with cwd = repo root, after the core rows.
# Only SDL_* names are set.
#
# GUARDS AGAINST: a bashism that the shell of the maker's machine accepts and an ash does not (an array assignment `x=(a b)`, a here-string `<<<`, `|&`, a
#                 `for ((;;))` loop, the `;&` of a case, a `function` head): shellcheck -s sh names most of them, but it is a linter with directives that a
#                 file may switch off, and `dash -n` is a parser with none. The files read are the shell files of the §14.6 scope (the collector, both
#                 Overview copies, both payload.sh, the page server's script, everything under library/ but its Markdown, and tools/device-probe.sh: the list
#                 `sh tools/passivity-check.sh --files` prints), then tools/*.sh and tools/regress.d/*.sh, so a helper and a drop-in are held to the same dialect.
#                 A file that went missing from the list, or a list that read fewer files than SDL_MIN_FILES, is red as well: the row cannot turn green by
#                 looking at less.
# NEGATIVE PROBE: five planted bashisms, each appended to a copy of the collector: an array assignment, a here-string, `|&`, a `for ((;;))` loop and `;&` in a
#                 case. The copy without them must pass and each of the five must make dash fail, or the row is red (the parser is then not parsing, or the
#                 probe is void). The same five run over a copy of this drop-in (a file of tools/regress.d, the other kind of file the row reads), with its own
#                 control: the copy without them must parse and each of the five must make dash fail, so a drop-in is read the way the shipped files are.
# NOT PROVEN:     that a file RUNS under ash (dash -n parses; it does not expand, so `${x//a/b}` and a bad substitution at run time pass it, and BusyBox
#                 applets, awk and jq are not dash's business: the collector's self-test under a BusyBox ash is not on this machine); that dash and BusyBox
#                 ash agree on every construct (they differ: `read -t`, `local`, `$'..'`, the `echo` flags); a construct that dash parses and an ash does not (`[[ a == a ]]` is read by `dash -n` as a command
#                 with the arguments `a`, `==`, `a`, `]]`, and fails only when it runs); files outside the lists above (the hooks under
#                 .githooks/, the Python tools). Where dash is absent (`command -v dash`) the row is NOT COVERED, which is neither green nor red, as the
#                 sqlite3 rows of the collector's self-test are when sqlite3 is absent (ALLOW_NO_SQLITE=1); it is announced at the end of tools/regress.sh.

SDL_MIN_FILES=63   # files read: the scope (7), the probe (1), tools/*.sh and tools/regress.d/*.sh (measured: see the row; the floor is about 90 % of it)
if ! command -v dash >/dev/null 2>&1; then
  notcov "shell dialect: dash -n on the shell files of the scope, tools/*.sh and tools/regress.d/*.sh (dash is not installed)"
  notcov "shell dialect sensor bites: five planted bashisms are red (dash is not installed)"
else
  SDL_T=$(mktemp -d "${TMPDIR:-/tmp}/starchorus-sdl.XXXXXX") || SDL_T=""
  if [ -z "$SDL_T" ] || [ ! -d "$SDL_T" ]; then
    row "shell dialect: no temp directory" FAIL
  else
    { sh tools/passivity-check.sh --files; for SDL_F in tools/*.sh tools/regress.d/*.sh; do [ -f "$SDL_F" ] && printf '%s\n' "$SDL_F"; done; } | awk '!seen[$0]++' > "$SDL_T/files"
    SDL_N=0; SDL_BAD=0; SDL_MISS=""
    while IFS= read -r SDL_F; do
      [ -f "$SDL_F" ] || { SDL_MISS="$SDL_MISS $SDL_F"; continue; }
      SDL_N=$((SDL_N + 1))
      if ! dash -n "$SDL_F" > "$SDL_T/err" 2>&1; then SDL_BAD=$((SDL_BAD + 1)); sed "s|^|    dash -n $SDL_F: |" "$SDL_T/err" | head -n 3 | cut -c1-200; fi
    done < "$SDL_T/files"
    SDL_OK=0; [ "$SDL_BAD" = 0 ] && [ -z "$SDL_MISS" ] && ge "$SDL_N" "$SDL_MIN_FILES" && SDL_OK=1
    rowif "shell dialect: dash -n parses $SDL_N shell files (≥ $SDL_MIN_FILES: the §14.6 scope and the probe, tools/*.sh, tools/regress.d/*.sh), failed $SDL_BAD, listed and missing:${SDL_MISS:- none}" [ "$SDL_OK" = 1 ]
    # the sensor: the same parser against a copy with one planted bashism at a time. A copy without it must parse (the control), each planted one must not.
    SDL_PL1='zz_a=(one two)'
    SDL_PL2='cat <<< "zz"'
    SDL_PL3='echo zz |& cat'
    SDL_PL4='for ((zz_i = 0; zz_i < 3; zz_i++)); do :; done'
    SDL_PL5='case zz in zz) : ;& *) : ;; esac'
    SDL_RED=0; SDL_CTL=0; SDL_COPY=starchorus-collect.sh
    cp "$SDL_COPY" "$SDL_T/c0.sh"; dash -n "$SDL_T/c0.sh" > /dev/null 2>&1 && SDL_CTL=1
    SDL_I=0
    for SDL_PL in "$SDL_PL1" "$SDL_PL2" "$SDL_PL3" "$SDL_PL4" "$SDL_PL5"; do
      SDL_I=$((SDL_I + 1))
      { cat "$SDL_COPY"; printf '%s\n' "$SDL_PL"; } > "$SDL_T/c$SDL_I.sh"
      dash -n "$SDL_T/c$SDL_I.sh" > /dev/null 2>&1 || SDL_RED=$((SDL_RED + 1))
    done
    SDL_DROP=tools/regress.d/shell-dialect.sh; SDL_DRED=0   # a drop-in is the other kind of file the row reads: this one, with each of the five appended in turn
    SDL_I=0
    for SDL_PL in "$SDL_PL1" "$SDL_PL2" "$SDL_PL3" "$SDL_PL4" "$SDL_PL5"; do
      SDL_I=$((SDL_I + 1))
      { cat "$SDL_DROP"; printf '%s\n' "$SDL_PL"; } > "$SDL_T/d$SDL_I.sh"
      dash -n "$SDL_T/d$SDL_I.sh" > /dev/null 2>&1 || SDL_DRED=$((SDL_DRED + 1))
    done
    SDL_DCTL=0; dash -n "$SDL_DROP" > /dev/null 2>&1 && SDL_DCTL=1
    SDL_SOK=0; [ "$SDL_CTL" = 1 ] && [ "$SDL_RED" = 5 ] && [ "$SDL_DCTL" = 1 ] && [ "$SDL_DRED" = 5 ] && SDL_SOK=1
    rowif "shell dialect sensor bites: the collector without a bashism parses ($SDL_CTL), $SDL_RED of 5 planted ones do not; a drop-in copy: control $SDL_DCTL, $SDL_DRED of 5 planted ones do not" [ "$SDL_SOK" = 1 ]
  fi
  case $SDL_T in */starchorus-sdl.??????) rm -rf "$SDL_T" ;; esac
fi
