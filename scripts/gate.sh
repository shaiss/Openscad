#!/usr/bin/env bash
# Render each design's printable STL(s) and gate them with printcheck
# (tools/printcheck — pip install -e tools/printcheck).
#   ./scripts/gate.sh                  # gate all designs under designs/
#   ./scripts/gate.sh <name>...        # gate one or more designs
#   ./scripts/gate.sh --slice [<name>...] # additionally test-slice each gated
#                                      # STL with PrusaSlicer (ground truth:
#                                      # slicing errors fail the gate; slicer
#                                      # warnings and print time are surfaced)
#
# Per-design config, both optional:
#   designs/<name>/ci.parts        one `part` value per line; each renders as
#                                  build/<name>-<part>.stl via -D part="..."
#                                  (without it, <name>.scad renders as-is —
#                                  use it when the default render is an
#                                  assembled preview, not the printable part)
#   designs/<name>/printcheck.args extra printcheck flags, e.g.
#                                  --build-volume 256x256x256 for designs
#                                  that target a larger printer
set -euo pipefail

SLICE=0
names=()
for arg in "$@"; do
  case "$arg" in
    --slice) SLICE=1 ;;
    -*) echo "error: unknown flag $arg" >&2; exit 2 ;;
    *) names+=("$arg") ;;
  esac
done
if [[ "$SLICE" == 1 ]]; then
  command -v prusa-slicer >/dev/null || {
    echo "error: --slice needs prusa-slicer on PATH" >&2; exit 2; }
fi

cd "$(dirname "$0")/.."
mkdir -p build
export OPENSCADPATH="$PWD/lib"

# OPENSCAD_BIN selects the binary (e.g. openscad-nightly); OPENSCAD_ARGS
# passes extra flags (e.g. --backend=manifold — nightly-only, 2021.01 has
# no --backend). Both default to the stable invocation.
OPENSCAD_BIN="${OPENSCAD_BIN:-openscad}"
read -ra OSC_ARGS <<<"${OPENSCAD_ARGS:-}"

fail=0

slice_one() {
  local stl="$1"
  local gcode="${stl%.stl}.gcode"
  echo "== test-slice ${stl} =="
  local out
  if ! out=$(prusa-slicer --export-gcode -o "$gcode" \
      --layer-height 0.2 --nozzle-diameter 0.4 --filament-diameter 1.75 \
      "$stl" 2>&1); then
    tail -20 <<<"$out"
    echo "FAIL  ${stl}: slicing failed"
    fail=1
    return 0
  fi
  grep -i "warning" <<<"$out" | sed 's/^/      /' || true
  grep -m1 "estimated printing time" "$gcode" | sed 's/^; */      /' || true
}

# Failures inside gate_one set fail=1 and keep going (matching how the
# printcheck step already aggregates) so one broken design never hides the
# results of the designs after it — gate_one always returns 0.
gate_one() {
  local name="$1"
  local src="designs/${name}/${name}.scad"
  if [[ ! -f "$src" ]]; then
    echo "FAIL  ${name}: ${src} not found"
    fail=1
    return 0
  fi

  local stls=()
  if [[ -f "designs/${name}/ci.parts" ]]; then
    local part
    while read -r part; do
      [[ -z "$part" || "$part" == \#* ]] && continue
      local stl="build/${name}-${part}.stl"
      echo "== ${name} (part=${part}): render =="
      if ! xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
          -o "$stl" -D "part=\"${part}\"" "$src"; then
        echo "FAIL  ${name} (part=${part}): render failed"
        fail=1
        continue
      fi
      stls+=("$stl")
    done < "designs/${name}/ci.parts"
  else
    echo "== ${name}: render =="
    if ! xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
        -o "build/${name}.stl" "$src"; then
      echo "FAIL  ${name}: render failed"
      fail=1
      return 0
    fi
    stls+=("build/${name}.stl")
  fi

  local args=()
  if [[ -f "designs/${name}/printcheck.args" ]]; then
    # Word-splitting the flag file is intended; `|| true` keeps set -e from
    # aborting on a comment-only file.
    # shellcheck disable=SC2207
    args=($(grep -vE '^(#|$)' "designs/${name}/printcheck.args" || true))
  fi
  local stl
  for stl in ${stls[@]+"${stls[@]}"}; do
    echo "== ${name}: printcheck ${stl} =="
    if ! printcheck "$stl" ${args[@]+"${args[@]}"}; then
      fail=1
    fi
    if [[ "$SLICE" == 1 ]]; then
      slice_one "$stl"
    fi
  done
}

if [[ ${#names[@]} -ge 1 ]]; then
  for name in "${names[@]}"; do
    gate_one "$name"
  done
else
  found=0
  for dir in designs/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ -f "designs/${name}/${name}.scad" ]] || continue
    found=1
    gate_one "$name"
  done
  if [[ "$found" -eq 0 ]]; then
    echo "no designs found under designs/"
  fi
fi

exit "$fail"
