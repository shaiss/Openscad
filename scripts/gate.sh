#!/usr/bin/env bash
# Render each design's printable STL(s) and gate them with printcheck
# (tools/printcheck — pip install -e tools/printcheck).
#   ./scripts/gate.sh          # gate all designs under designs/
#   ./scripts/gate.sh <name>   # gate one design
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

cd "$(dirname "$0")/.."
mkdir -p build
export OPENSCADPATH="$PWD/lib"

fail=0

gate_one() {
  local name="$1"
  local src="designs/${name}/${name}.scad"
  if [[ ! -f "$src" ]]; then
    echo "error: $src not found" >&2
    return 1
  fi

  local stls=()
  if [[ -f "designs/${name}/ci.parts" ]]; then
    local part
    while read -r part; do
      [[ -z "$part" || "$part" == \#* ]] && continue
      local stl="build/${name}-${part}.stl"
      echo "== ${name} (part=${part}): render =="
      xvfb-run -a openscad -o "$stl" -D "part=\"${part}\"" "$src"
      stls+=("$stl")
    done < "designs/${name}/ci.parts"
  else
    echo "== ${name}: render =="
    xvfb-run -a openscad -o "build/${name}.stl" "$src"
    stls+=("build/${name}.stl")
  fi

  local args=()
  if [[ -f "designs/${name}/printcheck.args" ]]; then
    # shellcheck disable=SC2207 — word-splitting the flag file is intended
    args=($(grep -v '^#' "designs/${name}/printcheck.args"))
  fi
  local stl
  for stl in "${stls[@]}"; do
    echo "== ${name}: printcheck ${stl} =="
    if ! printcheck "$stl" ${args[@]+"${args[@]}"}; then
      fail=1
    fi
  done
}

if [[ $# -ge 1 ]]; then
  gate_one "$1"
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
