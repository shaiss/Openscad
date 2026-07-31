#!/usr/bin/env bash
# Render designs to STL + PNG under build/.
# Usage:
#   ./scripts/render.sh          # render all designs under designs/
#   ./scripts/render.sh <name>   # render designs/<name>/<name>.scad
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build

render_one() {
  local name="$1"
  local src="designs/${name}/${name}.scad"
  if [[ ! -f "$src" ]]; then
    echo "error: $src not found" >&2
    return 1
  fi
  echo "== ${name}: STL =="
  xvfb-run -a openscad -o "build/${name}.stl" "$src"
  echo "== ${name}: PNG =="
  xvfb-run -a openscad -o "build/${name}.png" --imgsize=1200,900 --viewall --autocenter "$src"
  echo "== ${name}: done -> build/${name}.stl, build/${name}.png"
}

if [[ $# -ge 1 ]]; then
  render_one "$1"
else
  found=0
  for dir in designs/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ -f "designs/${name}/${name}.scad" ]] || continue
    found=1
    render_one "$name"
  done
  if [[ "$found" -eq 0 ]]; then
    echo "no designs found under designs/"
  fi
fi
