#!/usr/bin/env bash
# Run every nvim/test/*_spec.lua headless. Exits nonzero if any spec fails.
# Each spec is self-contained: it sets package.path, requires what it needs,
# prints `ok`/`FAIL` lines, and calls `cquit 1` on failure (nonzero exit).
#
# Usage:
#   nvim/test/run.sh            # run all specs
#   nvim/test/run.sh foo bar    # run only nvim/test/foo_spec.lua, bar_spec.lua
set -uo pipefail

test_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

specs=()
if [ "$#" -gt 0 ]; then
  for name in "$@"; do
    specs+=("$test_dir/${name%_spec.lua}_spec.lua")
  done
else
  for spec in "$test_dir"/*_spec.lua; do
    [ -e "$spec" ] && specs+=("$spec")
  done
fi

if [ "${#specs[@]}" -eq 0 ]; then
  echo "no specs found in $test_dir" >&2
  exit 1
fi

failed=0
for spec in "${specs[@]}"; do
  if [ ! -e "$spec" ]; then
    echo "MISSING $spec" >&2
    failed=1
    continue
  fi
  echo "=== $(basename "$spec") ==="
  if ! nvim --headless -u NONE -l "$spec"; then
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  echo "FAILED" >&2
  exit 1
fi
echo "ALL SPECS PASSED"
