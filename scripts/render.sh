#!/usr/bin/env bash
# Render designs to STL + preview PNGs under build/.
# Usage:
#   ./scripts/render.sh          # render all designs under designs/
#   ./scripts/render.sh <name>   # render designs/<name>/<name>.scad
#   ./scripts/render.sh <name> --previews
#                                # re-render the design's frozen preview shots
#                                # from designs/<name>/previews/cameras.conf
#                                # into designs/<name>/previews/
#   ./scripts/render.sh <name> --sweep param=start:end:step
#                                # tolerance-sweep strip: N labeled copies of
#                                # the design's coupon (or entry part) at
#                                # param = start, start+step, ..., end ->
#                                # build/<name>-sweep-<param>.stl + .png
#
# Outputs per design:
#   build/<name>.stl        — printable STL (full CGAL render)
#   build/<name>.png        — 2x2 contact sheet: iso / top / front / bottom-iso
#
# cameras.conf format (mirrors animations.conf; see scripts/animate.sh), one
# shot per line, `#` comments allowed:
#
#   name | size | camera | opts | defines...
#
#   name    output PNG basename -> designs/<name>/previews/<name>.png
#   size    image size WxH (e.g. 1400x1000)
#   camera  full fixed camera as tx,ty,tz,rx,ry,rz,dist (openscad --camera)
#   opts    space-separated flags: `ortho` (--projection=o), `render`
#           (--render, needed for section/cutaway shots), `src=<file>` to
#           render a sibling file (e.g. a coupon wrapper) instead of the
#           entry .scad
#   defines optional space-separated -D payloads, e.g. part="cutaway"
#
#   The single field `contact-sheet` (no other fields) re-renders the 4-view
#   contact sheet into previews/contact-sheet.png.
#
# Like animations.conf, camera lines are FIXED once a reviewer has seen the
# shot — before/after comparisons across review rounds must align. New
# region to show = new line, never move an existing camera.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build
# lib/ resolves `use <printability.scad>`; the repo root resolves
# `include <styles/<name>/style.scad>` (see scripts/style-lift.sh).
export OPENSCADPATH="$PWD/lib:$PWD"

# OPENSCAD_BIN selects the binary (e.g. openscad-nightly); OPENSCAD_ARGS
# passes extra flags (e.g. --backend=manifold — nightly-only, 2021.01 has
# no --backend). Both default to the stable invocation.
OPENSCAD_BIN="${OPENSCAD_BIN:-openscad}"
read -ra OSC_ARGS <<<"${OPENSCAD_ARGS:-}"

# label:rotx,roty,rotz — camera rotations for the four preview views
VIEWS=("iso:55,0,25" "top:0,0,0" "front:90,0,0" "bottom:235,0,55")

# whitespace trim that preserves quotes in -D payloads (same as animate.sh)
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}

# 4-view contact sheet of $1 (a .scad file) into $2 (a .png path)
contact_sheet() {
  local src="$1" out="$2"
  local pngs=() view
  for view in "${VIEWS[@]}"; do
    local label="${view%%:*}" rot="${view#*:}"
    local png="build/.cs-${label}-$$.png"
    xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
      -o "$png" --imgsize=800,600 \
      --camera="0,0,0,${rot},140" --viewall --autocenter "$src" 2>/dev/null
    montage -label "$label" "$png" -geometry +0+0 -pointsize 24 "$png"
    pngs+=("$png")
  done
  montage "${pngs[@]}" -tile 2x2 -geometry +2+2 "$out"
  rm -f "${pngs[@]}"
}

render_one() {
  local name="$1"
  local src="designs/${name}/${name}.scad"
  if [[ ! -f "$src" ]]; then
    echo "error: $src not found" >&2
    return 1
  fi

  echo "== ${name}: STL =="
  xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
    -o "build/${name}.stl" "$src"

  echo "== ${name}: previews =="
  contact_sheet "$src" "build/${name}.png"

  echo "== ${name}: done -> build/${name}.stl, build/${name}.png"
}

# Re-render the frozen preview shots from designs/<name>/previews/cameras.conf
render_previews() {
  local name="$1"
  local conf="designs/${name}/previews/cameras.conf"
  local outdir="designs/${name}/previews"
  if [[ ! -f "$conf" ]]; then
    echo "error: $conf not found (this design has no frozen preview shots)" >&2
    return 1
  fi

  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ "$line" =~ [^[:space:]] ]] || continue

    local shot size camera opts defines
    IFS='|' read -r shot size camera opts defines <<<"$line"
    shot="$(trim "$shot")"; size="$(trim "${size:-}")"
    camera="$(trim "${camera:-}")"; opts="$(trim "${opts:-}")"
    defines="$(trim "${defines:-}")"

    if [[ "$shot" == "contact-sheet" && -z "$size" ]]; then
      echo "== ${name}: previews/contact-sheet.png =="
      contact_sheet "designs/${name}/${name}.scad" "${outdir}/contact-sheet.png"
      continue
    fi
    if [[ -z "$shot" || -z "$size" || -z "$camera" ]]; then
      echo "error: malformed line in $conf: $line" >&2
      return 1
    fi

    local src="designs/${name}/${name}.scad"
    local args=() opt
    for opt in $opts; do
      case "$opt" in
        ortho) args+=(--projection=o) ;;
        render) args+=(--render) ;;
        src=*) src="designs/${name}/${opt#src=}" ;;
        *) echo "error: unknown opt '$opt' in $conf: $line" >&2; return 1 ;;
      esac
    done
    local d
    for d in $defines; do args+=(-D "$d"); done

    echo "== ${name}: previews/${shot}.png =="
    # capture stderr rather than discarding it: a failed shot must say why,
    # not vanish under set -e
    local err
    if ! err="$(xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
        -o "${outdir}/${shot}.png" --imgsize="${size/x/,}" \
        --camera="$camera" ${args[@]+"${args[@]}"} "$src" 2>&1)"; then
      echo "error: shot '${shot}' failed to render" >&2
      tail -20 <<<"$err" >&2
      return 1
    fi
  done <"$conf"
  echo "== ${name}: previews done -> ${outdir}/"
}

# Tolerance-sweep strip: N labeled copies of the design's coupon (preferred)
# or entry part at param = start..end in `step` increments, arranged side by
# side with the value embossed on a label tag in front of each copy — one
# plate print replaces N sequential guess-prints. See issue #15.
render_sweep() {
  local name="$1" spec="$2"
  local param="${spec%%=*}" range="${spec#*=}"
  local start="${range%%:*}" rest="${range#*:}"
  local end="${rest%%:*}" step="${rest#*:}"
  if [[ -z "$param" || "$param" == "$spec" || -z "$start" || -z "$end" \
        || -z "$step" || "$end" == "$rest" ]]; then
    echo "error: --sweep wants param=start:end:step (got '$spec')" >&2
    return 1
  fi
  # Reject non-numeric bounds before awk sees them. awk's -v assigns a plain
  # STRING (not a strnum) when the value doesn't look like a number, so the
  # `s <= 0` guard below silently becomes a *string* compare — "0,05" > "0"
  # is false, the guard is skipped, and `v += s` then coerces s to its
  # numeric prefix 0, so the loop never advances and spools output until the
  # shell OOMs. This also catches a step that swallowed extra fields
  # ("0.05:0.1" from a 4-field spec) or a unit suffix ("0.05mm"), both of
  # which awk would otherwise truncate to a plausible-looking number and
  # sweep with, silently ignoring what the user actually typed.
  local num_re='^[+-]?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][+-]?[0-9]+)?$'
  local n
  for n in "$start" "$end" "$step"; do
    if [[ ! "$n" =~ $num_re ]]; then
      echo "error: --sweep start/end/step must be numeric (got '$n' in '$spec')" >&2
      return 1
    fi
  done

  # Sweep the coupon wrapper when the design ships one — sweeping N full
  # parts costs N full print times; sweeping N coupons is an evening.
  local src="designs/${name}/${name}-coupon.scad"
  if [[ -f "$src" ]]; then
    echo "== ${name}: sweeping coupon wrapper ${src} =="
  else
    src="designs/${name}/${name}.scad"
    echo "== ${name}: no coupon wrapper, sweeping entry ${src} =="
  fi
  [[ -f "$src" ]] || { echo "error: $src not found" >&2; return 1; }

  local values
  # Defence in depth behind the numeric validation above: force numeric
  # context (+= 0) so the guard can never degrade into a string compare, and
  # cap the iteration count so no future caller can reintroduce an unbounded
  # loop feeding a command substitution.
  # while, not a comma-operator for-loop: POSIX awk (and mawk, what runs
  # here) has no comma operator, so `for (v = a, i = 0; ...)` is a syntax
  # error and every sweep would die reporting "step must be > 0".
  # exit 2 (cap hit) is distinct from exit 1 (step <= 0) so an oversized
  # range is refused outright rather than silently rendering the first 1000
  # coupons as if that were what was asked for.
  local rc=0
  values="$(awk -v a="$start" -v b="$end" -v s="$step" \
    'BEGIN { a += 0; b += 0; s += 0;
             if (s <= 0) exit 1;
             v = a; i = 0;
             while (v <= b + s/2) {
               if (i >= 1000) exit 2;
               printf "%g\n", v; v += s; i++;
             } }')" || rc=$?
  case "$rc" in
    0) ;;
    1) echo "error: step must be > 0" >&2; return 1 ;;
    2) echo "error: --sweep '$spec' spans more than 1000 values — widen the step or narrow the range" >&2
       return 1 ;;
    *) echo "error: sweep value generation failed (awk exit $rc)" >&2; return 1 ;;
  esac

  if [[ -z "$values" ]]; then
    echo "error: --sweep range '$spec' produced no values (start > end?)" >&2
    return 1
  fi

  local stls=() v
  for v in $values; do
    local stl="build/.sweep-${name}-${param}-${v}.stl"
    echo "== ${name}: ${param}=${v} =="
    # binstl so the bbox pass below can parse one fixed format
    xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
      -o "$stl" --export-format binstl -D "${param}=${v}" "$src"
    stls+=("$stl")
  done

  # Arrange the copies into one strip .scad: each STL placed at a cumulative
  # x offset with a label tag (raised text on a 1.2 mm plate) in front of it.
  # Tags sit beside the coupons, not fused to them, so a warped strip can't
  # corrupt the samples — everything still prints as one plate.
  local wrapper="build/.sweep-${name}-${param}.scad"
  python3 - "$wrapper" "$param" "${stls[@]}" <<'PY'
import struct, sys

wrapper, param, stls = sys.argv[1], sys.argv[2], sys.argv[3:]

def bbox(path):
    """Return ([min_x, min_y, min_z], [max_x, max_y, max_z]) of a binary STL.

    Reads the 80-byte header, the uint32 triangle count, then each 50-byte
    record (normal + 3 vertices + attribute count), tracking extremes across
    the 3 vertices. Binary is guaranteed: render_sweep exports with
    --export-format binstl.
    """
    with open(path, "rb") as f:
        f.read(80)
        n = struct.unpack("<I", f.read(4))[0]
        lo = [float("inf")] * 3
        hi = [float("-inf")] * 3
        for _ in range(n):
            rec = f.read(50)
            for v in range(3):
                x, y, z = struct.unpack_from("<3f", rec, 12 + 12 * v)
                for i, c in enumerate((x, y, z)):
                    lo[i] = min(lo[i], c)
                    hi[i] = max(hi[i], c)
    return lo, hi

gap = 4.0        # mm between strip entries — snappable/pluckable, not fused
tag_d = 9.0      # label tag depth (y)
tag_h = 1.2      # tag plate thickness (min wall)
text_h = 0.6     # raised text height (3 layers at 0.2)
out = [f"// generated tolerance sweep: {param} — do not edit", ""]
x = 0.0
depths = []      # reused for the footprint line; bbox() re-parses the mesh
for stl in stls:
    lo, hi = bbox(stl)
    w, d = hi[0] - lo[0], hi[1] - lo[1]
    depths.append(d)
    val = stl.rsplit(f"-{param}-", 1)[1][: -len(".stl")]
    # place the copy with its bbox min corner at (x, 0), bed at z=0
    out.append(
        f"translate([{x - lo[0]:.3f}, {-lo[1]:.3f}, {-lo[2]:.3f}]) "
        f'import("{stl.split("/")[-1]}");'
    )
    # label tag in front (-y), value embossed 0.6 mm proud of a 1.2 mm plate
    out.append(f"translate([{x:.3f}, {-(tag_d + 1.0):.3f}, 0]) {{")
    out.append(f"  cube([{w:.3f}, {tag_d}, {tag_h}]);")
    out.append(
        f"  translate([{w / 2:.3f}, {tag_d / 2}, {tag_h}]) "
        f"linear_extrude({text_h}) "
        f'text("{val}", size={min(5.0, max(3.0, w / max(1, len(val)) / 1.4)):.2f}, '
        f'halign="center", valign="center");'
    )
    out.append("}")
    x += w + gap
print(f"strip footprint: {x - gap:.1f} x {max(depths) + tag_d + 1.0:.1f} mm")
with open(wrapper, "w") as f:
    f.write("\n".join(out) + "\n")
PY

  local out_stl="build/${name}-sweep-${param}.stl"
  local out_png="build/${name}-sweep-${param}.png"
  echo "== ${name}: strip STL =="
  xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
    -o "$out_stl" "$wrapper"
  echo "== ${name}: strip preview =="
  xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
    -o "$out_png" --imgsize=1600,600 \
    --camera=0,0,0,35,0,10,140 --viewall --autocenter "$wrapper" 2>/dev/null
  rm -f "$wrapper" "${stls[@]}"
  echo "== ${name}: done -> ${out_stl}, ${out_png} (check the labels before printing)"
}

MODE=stl
SWEEP_SPEC=""
names=()
expect_sweep=0
for arg in "$@"; do
  if [[ "$expect_sweep" == 1 ]]; then
    SWEEP_SPEC="$arg"; expect_sweep=0; continue
  fi
  case "$arg" in
    --previews) MODE=previews ;;
    --sweep) MODE=sweep; expect_sweep=1 ;;
    --sweep=*) MODE=sweep; SWEEP_SPEC="${arg#--sweep=}" ;;
    -*) echo "error: unknown flag $arg" >&2; exit 2 ;;
    *) names+=("$arg") ;;
  esac
done
if [[ "$MODE" == sweep && -z "$SWEEP_SPEC" ]]; then
  echo "error: --sweep wants param=start:end:step" >&2; exit 2
fi
if [[ "$MODE" != stl && ${#names[@]} -ne 1 ]]; then
  echo "error: --previews/--sweep take exactly one design name" >&2; exit 2
fi

case "$MODE" in
  previews) render_previews "${names[0]}" ;;
  sweep) render_sweep "${names[0]}" "$SWEEP_SPEC" ;;
  stl)
    if [[ ${#names[@]} -ge 1 ]]; then
      for name in "${names[@]}"; do
        render_one "$name"
      done
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
    ;;
esac
