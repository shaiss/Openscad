#!/usr/bin/env bash
# Report-only static analysis of first-party .scad files with sca2d
# (pip install sca2d). Vendored lib/BOSL2 is never linted.
#
# Always exits 0: the step is informational while we build confidence in
# the signal. Current baseline (sca2d 0.4.0): 0 errors everywhere; a few
# W2010/W1002/W2002 warnings inherent to the multi-file `part` pattern in
# sushi-battleship. To promote to a gate, fail on E-lines by flipping
# REPORT_ONLY to 0.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2
# lib/ resolves `use <printability.scad>`; the repo root resolves
# `include <styles/<name>/style.scad>` (see scripts/style-lift.sh).
export OPENSCADPATH="$PWD/lib:$PWD"   # sca2d resolves use/include through this

REPORT_ONLY=1

command -v sca2d >/dev/null || {
  echo "error: sca2d not on PATH (pip install sca2d)" >&2; exit 2; }

errors=0
warnings=0
shopt -s nullglob
# lib/*.scad is the top level of lib/ only, so vendored lib/BOSL2/ is excluded
# by the glob itself — do not expand this to lib/**/*.scad. Globbed rather than
# named file-by-file so a new library is linted the day it lands.
for f in designs/*/*.scad lib/*.scad templates/*.scad; do
  out=$(sca2d "$f" 2>&1) || true
  # message lines look like: path:line:col: X####: text  (X in E/W/I/D)
  findings=$(grep -E ':[0-9]+:[0-9]+: [EW][0-9]{4}:' <<<"$out" || true)
  e=$(grep -cE ': E[0-9]{4}:' <<<"$findings" || true)
  w=$(grep -cE ': W[0-9]{4}:' <<<"$findings" || true)
  errors=$((errors + e))
  warnings=$((warnings + w))
  if [[ -n "$findings" ]]; then
    echo "== $f"
    sed 's/^/   /' <<<"$findings"
  fi
done

echo "sca2d: ${errors} error(s), ${warnings} warning(s) across first-party .scad files"
if [[ "$REPORT_ONLY" == 1 ]]; then
  exit 0
fi
[[ "$errors" -eq 0 ]]
