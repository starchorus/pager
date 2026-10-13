#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# tools/install-hooks.sh -- activate (or check) the repository's git hook directory on THIS clone.
# usage: sh tools/install-hooks.sh            set core.hooksPath = .githooks (local git config; idempotent), then check
#        sh tools/install-hooks.sh --check    change nothing; exit 0 = active and executable, 1 = not active or not executable
# core.hooksPath is local configuration, never part of a commit or a clone: every clone has to run this once.
# The check is deliberately NOT a tools/regress.sh row: a fresh clone (tools/fresh-check.sh) has no such configuration.
# Diagnose by hand: git config --show-origin --get core.hooksPath   (a worktree-local value beats the repo value)
# Dev machine only; nothing here sends anything.
set -u
here=$(cd "$(dirname "$0")" && pwd -P) || exit 2
top=$(git -C "$here" rev-parse --show-toplevel 2>/dev/null) || { echo "install-hooks: not inside a git work tree" >&2; exit 2; }
cd "$top" || exit 2
check() {
  cur=$(git config --get core.hooksPath 2>/dev/null); crc=$?
  git config --show-origin --get core.hooksPath 2>/dev/null | sed 's/^/install-hooks: core.hooksPath (origin, value): /'
  if [ "$crc" != 0 ] || [ "$cur" != .githooks ]; then
    echo "install-hooks: INACTIVE (core.hooksPath is '${cur:-unset}', want .githooks): sh tools/install-hooks.sh" >&2; return 1
  fi
  if [ ! -f .githooks/pre-commit ] || [ ! -x .githooks/pre-commit ]; then
    echo "install-hooks: INACTIVE (.githooks/pre-commit is missing or not executable: chmod +x .githooks/pre-commit)" >&2; return 1
  fi
  echo "install-hooks: active (.githooks/pre-commit runs on every commit that touches the checked paths)"
}
case "${1:-}" in
  --check) check; exit $? ;;
  "") git config core.hooksPath .githooks || exit 2; check; exit $? ;;
  *) echo "usage: sh tools/install-hooks.sh [--check]" >&2; exit 2 ;;
esac
