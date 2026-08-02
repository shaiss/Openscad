#!/usr/bin/env bash
# Render animated GIF previews for design product pages.
# Usage:
#   ./scripts/animate.sh          # render all designs that have animations.conf
#   ./scripts/animate.sh <name>   # render one design's animations
#
# Each design opts in with designs/<name>/animations.conf, one animation
# per line:
#
#   name | frames | delay | size | camera | spin | defines...
#
#   name    output GIF basename -> designs/<name>/previews/<name>.gif
#   frames  frame count (each frame runs OpenSCAD with -D '$t=i/frames')
#   delay   inter-frame delay in centiseconds (convert -delay)
#   size    frame size WxH (e.g. 640x480)
#   camera  fixed camera as tx,ty,tz,rx,ry,rz,dist (openscad --camera form)
#   spin    degrees added to the camera's rz over the loop (360 = full
#           turntable, 0 = fixed camera); model motion comes from $t instead
#   defines optional space-separated -D payloads, e.g. part="assembled"
#           anim="shutter" (no spaces inside a single define)
#
# Like the PNG cameras in previews/CAMERAS.md, manifest entries are FIXED
# across review rounds so before/after GIFs align; add a new entry rather
# than moving an existing one.
#
# GIFs are committed like the PNG previews (regenerate when the model
# changes); scripts/readme-gate.sh verifies each manifest entry has a
# committed GIF that the README embeds and holds them to a size budget.
#
# Frames render in OpenSCAD preview mode (fast, same as the PNG previews).
# Requires: openscad, xvfb-run, ImageMagick (convert); gifsicle is used to
# shrink the palette if installed, but is optional.
set -euo pipefail

cd "$(dirname "$0")/.."
export OPENSCADPATH="$PWD/lib"

MAX_GIF_BYTES=$((6 * 1024 * 1024))   # keep in sync with readme-gate.sh
MIN_GIF_BYTES=10240                  # smaller than this = blank frames

# whitespace trim that, unlike xargs, preserves quotes in -D payloads
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}

animate_one() {
  local design="$1"
  local conf="designs/${design}/animations.conf"
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

  local line
  # `|| [[ -n ... ]]`: don't silently drop a final manifest line that lacks
  # a trailing newline (read returns nonzero but still fills the variable).
  while IFS= read -r line || [[ -n "$line" ]]; do
    # strip comments and surrounding whitespace; skip blank lines
    line="${line%%#*}"
    [[ "$line" =~ [^[:space:]] ]] || continue

    local name frames delay size camera spin defines
    IFS='|' read -r name frames delay size camera spin defines <<<"$line"
    # trim each field
    name="$(trim "$name")"; frames="$(trim "$frames")"
    delay="$(trim "$delay")"; size="$(trim "$size")"
    camera="$(trim "$camera")"; spin="$(trim "$spin")"
    defines="$(trim "${defines:-}")"

    if [[ -z "$name" || -z "$frames" || -z "$delay" || -z "$size" \
          || -z "$camera" || -z "$spin" ]]; then
      echo "error: malformed line in $conf: $line" >&2
      return 1
    fi

    local rz prefix
    # camera = tx,ty,tz,rx,ry,rz,dist — spin is applied to rz per frame
    IFS=',' read -r -a cam <<<"$camera"
    if [[ "${#cam[@]}" -ne 7 ]]; then
      echo "error: camera needs 7 comma-separated values in $conf: $camera" >&2
      return 1
    fi

    echo "== ${design}: ${name}.gif (${frames} frames) =="
    local tmpdir
    tmpdir="$(mktemp -d)"
    local dargs=() d
    for d in $defines; do dargs+=(-D "$d"); done

    local i
    for i in $(seq 0 $((frames - 1))); do
      # $t sweeps [0,1) like openscad --animate; rz advances by spin/frames
      rz="$(awk -v rz="${cam[5]}" -v s="$spin" -v i="$i" -v n="$frames" \
              'BEGIN { printf "%.4f", rz + s * i / n }')"
      t="$(awk -v i="$i" -v n="$frames" 'BEGIN { printf "%.6f", i / n }')"
      prefix="$(printf '%s/f%04d' "$tmpdir" "$i")"
      xvfb-run -a openscad -o "${prefix}.png" --imgsize="${size/x/,}" \
        --camera="${cam[0]},${cam[1]},${cam[2]},${cam[3]},${cam[4]},${rz},${cam[6]}" \
        -D "\$t=${t}" "${dargs[@]}" "$src" 2>/dev/null
    done

    local gif="${outdir}/${name}.gif"
    convert -delay "$delay" -loop 0 "$tmpdir"/f*.png "$gif"
    if command -v gifsicle >/dev/null 2>&1; then
      gifsicle -O3 --colors 128 --batch "$gif"
    fi
    rm -rf "$tmpdir"

    local bytes
    bytes="$(stat -c %s "$gif")"
    echo "   -> ${gif} ($(( (bytes + 1023) / 1024 )) KiB)"
    if (( bytes > MAX_GIF_BYTES )); then
      echo "error: ${gif} exceeds the $((MAX_GIF_BYTES / 1024 / 1024)) MiB budget — fewer frames or a smaller size" >&2
      return 1
    fi
    if (( bytes < MIN_GIF_BYTES )); then
      echo "error: ${gif} is suspiciously small — frames likely rendered blank (bad part=/anim= define?)" >&2
      return 1
    fi
  done <"$conf"
}

if [[ $# -ge 1 ]]; then
  animate_one "$1"
else
  found=0
  for conf in designs/*/animations.conf; do
    [[ -f "$conf" ]] || continue
    found=1
    animate_one "$(basename "$(dirname "$conf")")"
  done
  if [[ "$found" -eq 0 ]]; then
    echo "no designs with animations.conf found under designs/"
  fi
fi
