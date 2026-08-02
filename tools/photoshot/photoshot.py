#!/usr/bin/env python3
"""Raytrace a studio product shot from one or more STLs.

Turns a geometry-true STL (exported by OpenSCAD) into a product-page hero
image: seamless studio backdrop, soft key/fill/rim lighting, glossy floor
with contact shadows and reflections, and a plastic material with visible
FDM layer lines.

Renders are reproducible: the same STL and args give byte-identical pixels
on the same machine, so shots re-render on demand and diff cleanly across
review rounds. Two POV-Ray features would break that and are handled here
rather than left to chance:

  * area-light `jitter` randomizes shadow-ray offsets per run, so it is
    never used; shadow quality comes from a denser sample grid instead.
  * radiosity's sample cache is gathered in thread-completion order, so a
    radiosity render is single-threaded by default. `--threads N` trades
    that reproducibility for speed; without radiosity, threads are safe.

Usage:
    photoshot.py part.stl -o shot.png --color '#e8734a'
    photoshot.py body.stl lid.stl --color '#333' --color '#e8734a' -o shot.png

Multiple STLs compose one scene (e.g. a two-tone assembly); --color repeats
in the same order. Coordinates are OpenSCAD's (z-up, millimeters); the model
is grounded on the floor plane automatically.

Requires: trimesh (STL loading), povray (rendering).
"""

import argparse
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import trimesh

# Horizontal field of view in degrees. A mild telephoto keeps product-shot
# perspective flattering; the vertical FOV follows from the output aspect.
CAMERA_ANGLE = 30
# Breathing room around the fitted bounding box at zoom 1.0.
FRAME_MARGIN = 1.06

FINISHES = {
    # diffuse, specular, roughness, reflection min/max
    "satin": (0.72, 0.30, 0.012, 0.015, 0.05),
    "gloss": (0.62, 0.55, 0.004, 0.03, 0.12),
    "matte": (0.85, 0.08, 0.060, 0.0, 0.0),
}


# PNG chunks POV-Ray stamps with the wall-clock time of the render. They carry
# no image data, but they change every run, so a re-render of unchanged
# geometry would still show up as a git diff. Dropped for byte-stable output.
_VOLATILE_PNG_CHUNKS = {b"tIME", b"tEXt", b"zTXt", b"iTXt"}


def strip_png_metadata(path):
    """Rewrite a PNG without its timestamp/text chunks, leaving pixels alone.

    Chunks are self-contained (each carries its own CRC), so dropping whole
    chunks needs no re-encoding and cannot alter the decoded image.
    """
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return
    out = bytearray(data[:8])
    i = 8
    while i + 8 <= len(data):
        length = int.from_bytes(data[i : i + 4], "big")
        ctype = data[i + 4 : i + 8]
        end = i + 12 + length
        if ctype not in _VOLATILE_PNG_CHUNKS:
            out += data[i:end]
        i = end
        if ctype == b"IEND":
            break
    path.write_bytes(bytes(out))


def parse_size(s):
    """Parse a WxH pixel size, rejecting anything that is not two positive ints."""
    parts = s.lower().split("x")
    if len(parts) != 2:
        raise argparse.ArgumentTypeError(f"bad size {s!r} (want WxH, e.g. 1280x960)")
    try:
        w, h = (int(p) for p in parts)
    except ValueError:
        raise argparse.ArgumentTypeError(f"bad size {s!r} (want WxH, e.g. 1280x960)")
    if w < 1 or h < 1:
        raise argparse.ArgumentTypeError(f"bad size {s!r} (both dimensions must be > 0)")
    return w, h


def positive_float(s):
    """Parse a float that must be greater than zero (camera zoom, scales)."""
    try:
        v = float(s)
    except ValueError:
        raise argparse.ArgumentTypeError(f"{s!r} is not a number")
    if v <= 0:
        raise argparse.ArgumentTypeError(f"must be greater than 0, got {v}")
    return v


def parse_color(s):
    """Parse #rrggbb or rrggbb (and the 3-digit short form) into 0..1 sRGB floats."""
    s = s.lstrip("#")
    if len(s) == 3:
        s = "".join(c * 2 for c in s)
    if len(s) != 6:
        raise argparse.ArgumentTypeError(f"bad color {s!r} (want #rrggbb)")
    return tuple(int(s[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def srgb_to_linear(c):
    """Convert an sRGB triple to linear light, which is what POV-Ray shades in."""
    return tuple(
        v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c
    )


def mesh2_block(mesh, color, finish, layer_h):
    """Emit one mesh as a POV-Ray mesh2 object with its plastic texture.

    layer_h > 0 adds a faint z-gradient normal perturbation that reads as FDM
    layer lines at that pitch; it is a surface shading effect, not geometry.
    """
    v = mesh.vertices
    f = mesh.faces
    verts = ", ".join(f"<{x:.4f},{y:.4f},{z:.4f}>" for x, y, z in v)
    faces = ", ".join(f"<{a},{b},{c}>" for a, b, c in f)
    r, g, b = srgb_to_linear(color)
    diffuse, spec, rough, rmin, rmax = FINISHES[finish]
    # Faint z-gradient ridges ~ layer_h apart read as FDM layer lines.
    normal = (
        f"normal {{ gradient z, 0.35 triangle_wave scale <1,1,{layer_h}> }}"
        if layer_h > 0
        else ""
    )
    reflection = (
        f"reflection {{ {rmin}, {rmax} fresnel }} conserve_energy"
        if rmax > 0
        else ""
    )
    return f"""
mesh2 {{
  vertex_vectors {{ {len(v)}, {verts} }}
  face_indices {{ {len(f)}, {faces} }}
  texture {{
    pigment {{ rgb <{r:.4f},{g:.4f},{b:.4f}> }}
    finish {{ diffuse {diffuse} specular {spec} roughness {rough}
              {reflection} ambient 0 }}
    {normal}
  }}
  interior {{ ior 1.46 }}
}}
"""


def scene(meshes, args):
    """Build the complete POV-Ray scene for the given meshes.

    Grounds the model on the floor plane (translating every mesh by the same
    offset, so multi-part assemblies keep their relative positions), then
    frames a camera orbiting at args.rotz/args.elev and lights the studio.
    """
    bounds = [m.bounds for m, _ in meshes]
    lo = [min(b[0][i] for b in bounds) for i in range(3)]
    hi = [max(b[1][i] for b in bounds) for i in range(3)]
    # ground the model at the origin
    dx, dy, dz = -(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]
    for m, _ in meshes:
        m.apply_translation((dx, dy, dz))
    ex, ey, ez = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]
    diag = math.sqrt(ex * ex + ey * ey + ez * ez)

    az = math.radians(args.rotz)
    el = math.radians(args.elev)
    w, h = args.size

    # POV-Ray's `angle` is the HORIZONTAL field of view — it is measured along
    # the `right` vector. On a 4:3 frame the vertical FOV is only 3/4 as wide,
    # so sizing the camera from the horizontal angle alone crops tall parts off
    # the top of the frame with no error anywhere. Both axes are fitted below.
    hhalf = math.radians(CAMERA_ANGLE) / 2
    vhalf = math.atan(math.tan(hhalf) * h / w)

    # Camera basis. The orbit direction depends only on rotz/elev, so the
    # framing distance can be solved for afterwards. `sky z` fixes the roll,
    # which makes `right` the horizontal in the xy-plane.
    look_z = ez * 0.42
    ux = math.cos(el) * math.sin(az)
    uy = -math.cos(el) * math.cos(az)
    uz = math.sin(el)
    fwd = (-ux, -uy, -uz)
    rlen = math.hypot(-uy, ux) or 1.0
    right_v = (-uy / rlen, ux / rlen, 0.0)
    up_v = (
        right_v[1] * fwd[2] - right_v[2] * fwd[1],
        right_v[2] * fwd[0] - right_v[0] * fwd[2],
        right_v[0] * fwd[1] - right_v[1] * fwd[0],
    )

    # Push the camera back until every bounding-box corner is inside both FOVs.
    # A corner nearer the camera (negative depth) needs more distance, hence the
    # subtraction; zoom then scales the whole framing.
    need = 0.0
    for sx in (-ex / 2, ex / 2):
        for sy in (-ey / 2, ey / 2):
            for sz in (0.0, ez):
                v = (sx, sy, sz - look_z)
                depth = sum(v[i] * fwd[i] for i in range(3))
                hoff = abs(sum(v[i] * right_v[i] for i in range(3)))
                voff = abs(sum(v[i] * up_v[i] for i in range(3)))
                need = max(
                    need,
                    hoff / math.tan(hhalf) - depth,
                    voff / math.tan(vhalf) - depth,
                )
    dist = need * FRAME_MARGIN / args.zoom

    cx = dist * ux
    cy = dist * uy
    cz = look_z + dist * uz
    look = f"<0,0,{look_z:.3f}>"
    key = diag * 1.5

    blocks = "".join(mesh2_block(m, c, args.finish, args.layers) for m, c in meshes)
    radiosity = (
        "radiosity { count 80 error_bound 0.6 recursion_limit 2 "
        "nearest_count 8 brightness 0.75 }"
        if not args.no_radiosity
        else ""
    )
    return f"""#version 3.7;
global_settings {{ assumed_gamma 1.0 max_trace_level 8 {radiosity} }}
#default {{ finish {{ ambient {0.0 if not args.no_radiosity else 0.28} }} }}

camera {{
  location <{cx:.3f},{cy:.3f},{cz:.3f}>
  sky z
  look_at {look}
  right -x*{w}/{h}
  up z
  angle {CAMERA_ANGLE}
}}

// seamless white-studio environment (also the radiosity light bath)
sky_sphere {{
  pigment {{
    gradient z
    color_map {{ [0.0 rgb <0.88,0.89,0.91>] [0.6 rgb <0.99,0.99,1.00>] }}
  }}
}}

// key: large area light, high and camera-left. No `jitter` — it randomizes
// per run and would break reproducibility; a 5x5 sample grid (and no
// `adaptive`, which prunes samples by contrast) keeps the penumbra smooth.
light_source {{
  <{-key:.1f},{-key * 0.9:.1f},{key * 1.5:.1f}> rgb <1.02,1.01,0.99> * 0.95
  area_light x*{diag * 0.9:.1f}, y*{diag * 0.9:.1f}, 5, 5
  circular orient
}}
// fill: soft, camera-right, no shadows
light_source {{ <{key:.1f},{-key * 0.6:.1f},{key * 0.8:.1f}> rgb 0.30 shadowless }}
// rim: behind and above, edge highlight
light_source {{ <{key * 0.3:.1f},{key:.1f},{key * 1.2:.1f}> rgb 0.35 shadowless }}

// glossy studio floor
plane {{
  z, 0
  pigment {{ rgb <0.94,0.945,0.955> }}
  finish {{ diffuse 0.8 specular 0.06 roughness 0.02
            reflection {{ 0.03, 0.09 fresnel }} conserve_energy ambient 0 }}
  interior {{ ior 1.5 }}
}}

{blocks}
"""


def main():
    """Render the STL(s) named on the command line to a studio product shot."""
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("stl", nargs="+", help="input STL(s), composed into one scene")
    ap.add_argument("-o", "--output", required=True, help="output PNG")
    ap.add_argument(
        "--color",
        action="append",
        type=parse_color,
        help="#rrggbb per STL, in order (default: one warm orange)",
    )
    ap.add_argument("--finish", choices=FINISHES, default="satin")
    ap.add_argument("--rotz", type=float, default=35, help="orbit angle, degrees")
    ap.add_argument("--elev", type=float, default=18, help="camera elevation, degrees")
    ap.add_argument("--zoom", type=positive_float, default=1.0)
    ap.add_argument("--size", default="1280x960", type=parse_size, help="WxH pixels")
    ap.add_argument(
        "--layers",
        type=float,
        default=0.2,
        help="FDM layer-line height in mm for the surface texture (0 = smooth)",
    )
    ap.add_argument("--no-radiosity", action="store_true", help="faster, flatter light")
    ap.add_argument(
        "--threads",
        type=int,
        default=0,
        help="POV-Ray render threads (default: 1 with radiosity, 4 without — "
        "radiosity's sample cache is thread-order dependent, so raising this "
        "with radiosity on trades reproducible pixels for speed)",
    )
    ap.add_argument("--keep-pov", action="store_true", help="keep the .pov next to the PNG")
    args = ap.parse_args()

    # Default threading is whatever is reproducible for the chosen lighting.
    threads = args.threads if args.threads > 0 else (4 if args.no_radiosity else 1)

    povray = shutil.which("povray")
    if povray is None:
        sys.exit(
            "error: povray not found on PATH — run "
            "`.claude/hooks/session-start.sh --force` to install the toolchain"
        )

    colors = args.color or []
    default = parse_color("#e8734a")
    meshes = []
    for i, path in enumerate(args.stl):
        m = trimesh.load(path, force="mesh")
        if m.is_empty or len(m.faces) == 0:
            sys.exit(f"error: {path} loaded empty")
        meshes.append((m, colors[i] if i < len(colors) else default))

    pov = scene(meshes, args)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    w, h = args.size
    with tempfile.NamedTemporaryFile(
        "w", suffix=".pov", delete=False, dir=out.parent
    ) as fh:
        fh.write(pov)
        povfile = Path(fh.name)
    try:
        subprocess.run(
            [
                povray,
                f"+I{povfile}",
                f"+O{out}",
                f"+W{w}",
                f"+H{h}",
                "+A0.3",
                "+AM2",
                "+R3",
                "+Q9",
                "-D",
                f"+WT{threads}",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as e:
        sys.exit(f"povray failed:\n{e.stderr[-3000:]}")
    finally:
        if args.keep_pov:
            povfile.replace(out.with_suffix(".pov"))
        else:
            povfile.unlink(missing_ok=True)
    strip_png_metadata(out)
    print(f"wrote {out} ({w}x{h})")


if __name__ == "__main__":
    main()
