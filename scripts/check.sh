#!/usr/bin/env bash
# Fast validation of every .scad file in the repo (no STL output).
#   1. Syntax/eval check of all designs and lib files (echo export — seconds)
#   2. Full CGAL render of the lib demo to catch geometry regressions
# Run before committing. For full STL+PNG output use scripts/render.sh.
set -euo pipefail

cd "$(dirname "$0")/.."
export OPENSCADPATH="$PWD/lib"

fail=0

check() {
  local f="$1"
  if out=$(xvfb-run -a openscad -o /dev/null --export-format echo "$f" 2>&1); then
    # Surface WARNINGs even on success
    if grep -q "WARNING" <<<"$out"; then
      echo "WARN  $f"
      grep "WARNING" <<<"$out" | sed 's/^/      /'
    else
      echo "ok    $f"
    fi
  else
    echo "FAIL  $f"
    sed 's/^/      /' <<<"$out" | tail -20
    fail=1
  fi
}

shopt -s nullglob
for f in designs/*/*.scad lib/*.scad; do
  check "$f"
done

echo "-- geometry check: lib/printability-demo.scad"
if xvfb-run -a openscad -o /dev/null --export-format binstl lib/printability-demo.scad 2>&1 | grep -E "ERROR|WARNING"; then
  echo "FAIL  lib demo rendered with errors/warnings above"
  fail=1
else
  echo "ok    lib demo renders clean"
fi

exit "$fail"
