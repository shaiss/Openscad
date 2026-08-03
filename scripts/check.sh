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

# WARNINGs that mean the file silently produced the WRONG SHAPE rather than
# something cosmetic: OpenSCAD skips the call, exits 0, and hands you a
# watertight, sliceable, gate-passing STL with the feature missing. These fail
# the check; every other WARNING stays advisory.
#
# Note the echo pass below does not instantiate geometry, so it never sees an
# unresolved `use <lib.scad>` — that is what the link check further down is
# for. This pattern covers the top-level cases the echo pass does reach.
FATAL_WARN="Ignoring unknown module|Ignoring unknown function|Can't open include file"

# Under `--export-format echo` OpenSCAD writes its diagnostics into the export
# file, not to stderr — so the old `-o /dev/null` threw every WARNING away and
# the FATAL_WARN test below could never fire. Export to a real file and read
# the warnings back out of it (plus whatever stderr does carry).
mkdir -p build
ECHO_OUT="build/.check-echo.txt"
trap 'rm -f "$ECHO_OUT"' EXIT

check() {
  local f="$1" rc=0 err
  : >"$ECHO_OUT"
  err=$(xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
    -o "$ECHO_OUT" --export-format echo "$f" 2>&1) || rc=$?
  out=$(printf '%s\n%s' "$err" "$(cat "$ECHO_OUT")")
  if (( rc == 0 )); then
    # Surface WARNINGs even on success
    if grep -q "WARNING" <<<"$out"; then
      if grep -qE "$FATAL_WARN" <<<"$out"; then
        echo "FAIL  $f  (unresolved module/include — wrong geometry, not a nit)"
        fail=1
      else
        echo "WARN  $f"
      fi
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

# Library-link check. OpenSCAD treats an unresolvable `use <x.scad>` as a
# non-event: no error, no warning during the echo pass, exit 0 — and at render
# time only "Ignoring unknown module", after which you get a watertight,
# sliceable STL with the feature simply absent. Rendering the capsule without
# OPENSCADPATH gives you a threadless neck that passes every downstream gate.
# So resolve the links statically instead of hoping a render complains.
echo "-- library-link check"
# Search path mirrors what the scripts export: lib/ for shared modules, the
# repo root for `include <styles/<name>/style.scad>`. A style's swatch is a
# .scad like any other and gets link-checked too — a swatch that silently
# loses its tokens would render an unstyled shape and still pass the gate.
lib_search=("$PWD/lib" "$PWD" /usr/share/openscad/libraries)
for f in designs/*/*.scad lib/*.scad templates/*.scad styles/*/*.scad; do
  while read -r ref; do
    [[ -f "$(dirname "$f")/$ref" ]] && continue     # sibling file
    found=0
    for d in "${lib_search[@]}"; do
      [[ -f "$d/$ref" ]] && { found=1; break; }
    done
    (( found )) || { echo "FAIL  $f: use/include <$ref> resolves nowhere"; fail=1; }
  done < <(grep -oE '^[[:space:]]*(use|include)[[:space:]]*<[^>]+>' "$f" \
             | sed -E 's/.*<([^>]+)>.*/\1/')
done
(( fail )) || echo "ok    every use/include resolves"

# Every lib/*-demo.scad is a full CGAL render, not just an echo check: that is
# what catches a geometry regression in a shared module before a design does.
# Globbed rather than named so a new library's demo is covered the day it
# lands (the echo pass above already covers every lib/*.scad for syntax).
for demo in lib/*-demo.scad; do
  [[ -f "$demo" ]] || continue
  echo "-- geometry check: ${demo}"
  if xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
      -o /dev/null --export-format binstl "$demo" 2>&1 \
      | grep -E "ERROR|WARNING"; then
    echo "FAIL  ${demo} rendered with errors/warnings above"
    fail=1
  else
    echo "ok    ${demo} renders clean"
  fi
done

echo "-- docs-drift check: scripts/docs-check.sh"
if ! ./scripts/docs-check.sh; then
  fail=1
fi

exit "$fail"
