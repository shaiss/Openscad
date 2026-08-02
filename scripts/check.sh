#!/usr/bin/env bash
# Fast validation of every .scad file in the repo (no STL output).
#   1. Syntax/eval check of all designs, lib, template and style files
#      (echo export — seconds)
#   2. Full CGAL render of the lib demo to catch geometry regressions
#   3. Docs-drift check (scripts/docs-check.sh): docs must match the tree
# Run before committing. For full STL+PNG output use scripts/render.sh.
set -euo pipefail

cd "$(dirname "$0")/.."
# lib/ resolves `use <printability.scad>`; the repo root resolves
# `include <styles/<name>/style.scad>` (see scripts/style-lift.sh).
export OPENSCADPATH="$PWD/lib:$PWD"

# OPENSCAD_BIN selects the binary (e.g. openscad-nightly); OPENSCAD_ARGS
# passes extra flags (e.g. --backend=manifold — nightly-only, 2021.01 has
# no --backend). Both default to the stable invocation.
OPENSCAD_BIN="${OPENSCAD_BIN:-openscad}"
read -ra OSC_ARGS <<<"${OPENSCAD_ARGS:-}"

fail=0

check() {
  local f="$1"
  if out=$(xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
      -o /dev/null --export-format echo "$f" 2>&1); then
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
for f in designs/*/*.scad lib/*.scad templates/*.scad styles/*/*.scad; do
  check "$f"
done

echo "-- geometry check: lib/printability-demo.scad"
if xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
    -o /dev/null --export-format binstl lib/printability-demo.scad 2>&1 \
    | grep -E "ERROR|WARNING"; then
  echo "FAIL  lib demo rendered with errors/warnings above"
  fail=1
else
  echo "ok    lib demo renders clean"
fi

echo "-- docs-drift check: scripts/docs-check.sh"
if ! ./scripts/docs-check.sh; then
  fail=1
fi

exit "$fail"
