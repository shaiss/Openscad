#!/usr/bin/env bash
# Render designs to STL + preview PNGs under build/.
# Usage:
#   ./scripts/render.sh          # render all designs under designs/
#   ./scripts/render.sh <name>   # render designs/<name>/<name>.scad
#
# Outputs per design:
#   build/<name>.stl        — printable STL (full CGAL render)
#   build/<name>.png        — 2x2 contact sheet: iso / top / front / bottom-iso
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build
export OPENSCADPATH="$PWD/lib"

# label:rotx,roty,rotz — camera rotations for the four preview views
VIEWS=("iso:55,0,25" "top:0,0,0" "front:90,0,0" "bottom:235,0,55")

render_one() {
  local name="$1"
  local src="designs/${name}/${name}.scad"
  if [[ ! -f "$src" ]]; then
    echo "error: $src not found" >&2
    return 1
  fi

  echo "== ${name}: STL =="
  xvfb-run -a openscad -o "build/${name}.stl" "$src"

  echo "== ${name}: previews =="
  local pngs=()
  for view in "${VIEWS[@]}"; do
    local label="${view%%:*}" rot="${view#*:}"
    local png="build/.${name}-${label}.png"
    xvfb-run -a openscad -o "$png" --imgsize=800,600 \
      --camera="0,0,0,${rot},140" --viewall --autocenter "$src" 2>/dev/null
    montage -label "$label" "$png" -geometry +0+0 -pointsize 24 "$png"
    pngs+=("$png")
  done
  montage "${pngs[@]}" -tile 2x2 -geometry +2+2 "build/${name}.png"
  rm -f "${pngs[@]}"

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
