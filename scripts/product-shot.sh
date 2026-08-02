#!/usr/bin/env bash
# Render real-world-looking product shots for design product pages.
# Usage:
#   ./scripts/product-shot.sh          # all designs that have shots.conf
#   ./scripts/product-shot.sh <name>   # one design's shots
#
# Each design opts in with designs/<name>/shots.conf, one shot per line:
#
#   name | color | finish | camera | size | defines...
#
#   name    output basename -> designs/<name>/previews/<name>.png
#   color   filament color as rrggbb hex (no leading '#' — that would
#           read as a manifest comment)
#   finish  satin | gloss | matte (see tools/photoshot/photoshot.py)
#   camera  rotz,elev,zoom — orbit angle and elevation in degrees around
#           the grounded model, zoom scales the framing (1.0 = default)
#   size    output WxH in pixels (e.g. 1280x960)
#   defines optional space-separated -D payloads, e.g. part="assembled"
#           (no spaces inside a single define)
#
# Pipeline: OpenSCAD exports the geometry-true STL (full CGAL render, so a
# shot can never show geometry the printable part doesn't have), then
# tools/photoshot/photoshot.py raytraces it in a studio scene (POV-Ray):
# seamless backdrop, soft key/fill/rim light, glossy floor, FDM layer-line
# texture. Re-rendering an unchanged design reproduces the committed PNG
# pixel for pixel (photoshot.py documents what that costs: no light jitter,
# and radiosity renders single-threaded), so a shot that changes in a diff
# means the geometry changed.
#
# Like animations.conf entries, shots are FIXED across review rounds so
# before/after images align; add a new entry rather than moving one.
# PNGs are committed like the other previews; scripts/readme-gate.sh
# verifies each manifest entry has a committed, README-embedded PNG within
# the size budget.
#
# Requires: openscad, xvfb-run, povray, python3 + trimesh.
set -euo pipefail

cd "$(dirname "$0")/.."
# lib/ resolves `use <printability.scad>`; the repo root resolves
# `include <styles/<name>/style.scad>` (see scripts/style-lift.sh).
export OPENSCADPATH="$PWD/lib:$PWD"

# OPENSCAD_BIN selects the binary (e.g. openscad-nightly); OPENSCAD_ARGS
# passes extra flags (e.g. --backend=manifold). Same contract as render.sh
# and gate.sh, so a shot is exported by the same toolchain that gates it.
OPENSCAD_BIN="${OPENSCAD_BIN:-openscad}"
read -ra OSC_ARGS <<<"${OPENSCAD_ARGS:-}"

# shellcheck source=scripts/preview-budget.sh
. scripts/preview-budget.sh          # defines MAX_SHOT_BYTES
MIN_SHOT_BYTES=20480                 # smaller than this = blank render

# whitespace trim that, unlike xargs, preserves quotes in -D payloads
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}

shoot_one() {
  local design="$1"
  local conf="designs/${design}/shots.conf"
  local src="designs/${design}/${design}.scad"
  local outdir="designs/${design}/previews"

  if [[ ! -f "$conf" ]]; then
    echo "error: $conf not found" >&2
    return 1
  fi
  if [[ ! -f "$src" ]]; then
    echo "error: $src not found" >&2
    return 1
  fi
  mkdir -p "$outdir"

  # One scratch dir for the whole design, removed on every exit path — a
  # failed export must not strand a multi-hundred-MB STL in /tmp.
  local tmpdir
  tmpdir="$(mktemp -d)"
  # Single quotes on purpose: $tmpdir is read when the trap fires, so a
  # TMPDIR containing shell syntax can't be interpolated into the command.
  trap 'rm -rf -- "$tmpdir"' RETURN

  local line
  # `|| [[ -n ... ]]`: don't silently drop a final manifest line that lacks
  # a trailing newline (read returns nonzero but still fills the variable).
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ "$line" =~ [^[:space:]] ]] || continue

    local name color finish camera size defines
    IFS='|' read -r name color finish camera size defines <<<"$line"
    name="$(trim "$name")"; color="$(trim "$color")"
    finish="$(trim "$finish")"; camera="$(trim "$camera")"
    size="$(trim "$size")"; defines="$(trim "${defines:-}")"

    if [[ -z "$name" || -z "$color" || -z "$finish" || -z "$camera" \
          || -z "$size" ]]; then
      echo "error: malformed line in $conf: $line" >&2
      return 1
    fi

    local rotz elev zoom
    IFS=',' read -r rotz elev zoom <<<"$camera"
    if [[ -z "$rotz" || -z "$elev" || -z "$zoom" ]]; then
      echo "error: camera needs rotz,elev,zoom in $conf: $camera" >&2
      return 1
    fi

    echo "== ${design}: ${name}.png =="
    # Split the defines field on whitespace WITHOUT globbing: an unquoted
    # expansion would let a define like part=*.scad match filenames.
    local dargs=() d parts=()
    read -r -a parts <<<"$defines"
    for d in "${parts[@]}"; do dargs+=(-D "$d"); done

    # OpenSCAD's CGAL statistics are noise here, so the log is kept quiet on
    # success — but diagnostics are never swallowed: a shot is only
    # "geometry-true" if the export was clean.
    local log="${tmpdir}/openscad.log"
    if ! xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
         -o "${tmpdir}/part.stl" "${dargs[@]}" "$src" >"$log" 2>&1; then
      echo "error: openscad failed exporting ${design} (${name}):" >&2
      cat "$log" >&2
      return 1
    fi
    # Warnings are advisory, but an ERROR must not become a product shot:
    # OpenSCAD reports CGAL failures on stderr and still exits 0, so the
    # exit status above cannot be the only check. Rendering past one would
    # publish a hero image of geometry the printable part doesn't have.
    grep -E '^WARNING:' "$log" >&2 || true
    if grep -q '^ERROR:' "$log"; then
      echo "error: openscad reported errors exporting ${design} (${name}):" >&2
      grep -E '^ERROR:' "$log" >&2
      return 1
    fi

    local png="${outdir}/${name}.png"
    python3 tools/photoshot/photoshot.py "${tmpdir}/part.stl" -o "$png" \
      --color "$color" --finish "$finish" \
      --rotz "$rotz" --elev "$elev" --zoom "$zoom" --size "$size"

    local bytes
    bytes="$(stat -c %s "$png")"
    echo "   -> ${png} ($(( (bytes + 1023) / 1024 )) KiB)"
    if (( bytes > MAX_SHOT_BYTES )); then
      echo "error: ${png} exceeds the $((MAX_SHOT_BYTES / 1024 / 1024)) MiB budget — use a smaller size" >&2
      return 1
    fi
    if (( bytes < MIN_SHOT_BYTES )); then
      echo "error: ${png} is suspiciously small — render likely blank (bad part= define?)" >&2
      return 1
    fi
  done <"$conf"
}

if [[ $# -ge 1 ]]; then
  shoot_one "$1"
else
  found=0
  for conf in designs/*/shots.conf; do
    [[ -f "$conf" ]] || continue
    found=1
    shoot_one "$(basename "$(dirname "$conf")")"
  done
  if [[ "$found" -eq 0 ]]; then
    echo "no designs with shots.conf found under designs/"
  fi
fi
