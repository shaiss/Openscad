#!/usr/bin/env python3
"""Render a studio product shot from one or more STLs.

Turns a geometry-true STL (exported by OpenSCAD) into a product-page hero
image: seamless studio backdrop, soft key/fill/rim lighting, a subtly glossy
floor with contact shadows, and a plastic material with visible FDM layer
lines.

Rendering is Blender's Cycles path tracer, driven headlessly through the
`bpy` Python module (no GUI, no X display, no `xvfb-run`).

Renders are reproducible: the same STL and args give byte-identical pixels
on the same machine, so shots re-render on demand and diff cleanly across
review rounds. Three things that would otherwise break that are pinned here
rather than left to chance:

  * the sampling seed is fixed, so the stochastic path tracer replays the
    same random sequence every run;
  * the thread count is pinned to an explicit value. Cycles is in fact
    thread-count invariant (verified: 1, 2 and 4 threads produce identical
    pixels), but pinning it keeps the render time comparable run to run;
  * Blender stamps wall-clock render times into PNG tEXt chunks, which carry
    no image data but change every run — they are dropped after the render.

One caveat is worth knowing before wiring this into a CI regeneration gate:
Cycles dispatches one of two CPU kernels (SSE4.2 or AVX2) at runtime, and
their floating-point rounding differs. Pixels are stable on a given machine
and across thread counts, but NOT guaranteed identical across machines with
different instruction sets. Compare renders perceptually, not byte-wise,
when the two sides may have run on different hardware.

Usage:
    photoshot.py part.stl -o shot.png --color '#e8734a'
    photoshot.py body.stl lid.stl --color '#333' --color '#e8734a' -o shot.png

Multiple STLs compose one scene (e.g. a two-tone assembly); --color repeats
in the same order. Coordinates are OpenSCAD's (z-up, millimeters); the model
is grounded on the floor plane automatically.

Requires: bpy (`pip install 'bpy~=4.5.0'`, installed by the session-start
hook). Pinned to the 4.5 LTS series — output is byte-reproducible across
point releases within a series, not promised across them — and its wheels
are built per Python minor version, so it needs Python 3.11.
"""

import argparse
import contextlib
import math
import os
import sys
import tempfile
from pathlib import Path

# Horizontal field of view in degrees. A mild telephoto keeps product-shot
# perspective flattering; the vertical FOV follows from the output aspect.
CAMERA_ANGLE = 30
# Breathing room around the fitted bounding box at zoom 1.0.
FRAME_MARGIN = 1.06

# Blender's own limits on render resolution; see parse_size().
RESOLUTION_MIN = 4
RESOLUTION_MAX = 65536

# Faces meeting at less than this smooth together; sharper edges stay crisp.
# Deliberately below OpenSCAD's coarse tessellations: at 30 degrees a $fn=16
# cylinder (22.5 degree facets) would render smooth, implying a roundness the
# printed part will not have. At 15, everything from $fn=32 up smooths — which
# covers the $fn >= 64 this repo requires for production curves — while coarse
# iteration values stay visibly faceted, as they should.
SMOOTH_ANGLE = 15

# Principled BSDF parameters per finish: roughness, specular level, clearcoat
# weight, clearcoat roughness. Extruded plastic is never mirror-smooth, so even
# "gloss" keeps some roughness; the coat layer is what reads as a resin sheen.
FINISHES = {
    "satin": (0.38, 0.45, 0.12, 0.35),
    "gloss": (0.18, 0.60, 0.35, 0.10),
    "matte": (0.62, 0.25, 0.00, 0.50),
}

# PNG chunks Blender stamps with the wall-clock time of the render. They carry
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
    except ValueError as e:
        raise argparse.ArgumentTypeError(
            f"bad size {s!r} (want WxH, e.g. 1280x960)"
        ) from e
    # Blender's resolution_x/y RNA range is 4..65536 and it CLAMPS silently on
    # assignment, so a smaller value would render at 4px while the tool happily
    # reported the size that was asked for. Reject it here instead.
    if not (RESOLUTION_MIN <= w <= RESOLUTION_MAX) or not (
        RESOLUTION_MIN <= h <= RESOLUTION_MAX
    ):
        raise argparse.ArgumentTypeError(
            f"bad size {s!r} (each dimension must be "
            f"{RESOLUTION_MIN}..{RESOLUTION_MAX} pixels)"
        )
    return w, h


def finite_float(s):
    """Parse a float, rejecting nan/inf.

    float() happily accepts "nan" and "inf"; both reach the camera solve and
    turn into unusable coordinates (nan silently, inf as a ValueError deep in
    scene generation) rather than a readable argument error.
    """
    try:
        v = float(s)
    except ValueError as e:
        raise argparse.ArgumentTypeError(f"{s!r} is not a number") from e
    if not math.isfinite(v):
        raise argparse.ArgumentTypeError(f"must be a finite number, got {s!r}")
    return v


def positive_float(s):
    """Parse a finite float that must be greater than zero (camera zoom)."""
    v = finite_float(s)
    if v <= 0:
        raise argparse.ArgumentTypeError(f"must be greater than 0, got {v}")
    return v


def positive_int(s):
    """Parse an int that must be greater than zero (sample count)."""
    try:
        v = int(s)
    except ValueError as e:
        raise argparse.ArgumentTypeError(f"{s!r} is not an integer") from e
    if v < 1:
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
    """Convert an sRGB triple to linear light, which is what Cycles shades in."""
    return tuple(
        v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c
    )


def solve_camera(extents, look_z, rotz, elev, zoom, size):
    """Place the camera so the whole bounding box is framed, on BOTH axes.

    `CAMERA_ANGLE` is the HORIZONTAL field of view. On a 4:3 frame the vertical
    FOV is only 3/4 as wide, so sizing the camera from the horizontal angle
    alone crops tall parts off the top of the frame with no error anywhere.
    Both axes are fitted below.

    Returns (location, distance). The orbit direction depends only on
    rotz/elev, so the framing distance is solved for afterwards.
    """
    ex, ey, ez = extents
    w, h = size
    hhalf = math.radians(CAMERA_ANGLE) / 2
    vhalf = math.atan(math.tan(hhalf) * h / w)

    az, el = math.radians(rotz), math.radians(elev)
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
    dist = need * FRAME_MARGIN / zoom
    return (dist * ux, dist * uy, look_z + dist * uz), dist


def _tail(log, limit=2000):
    """Last of whatever Blender printed, for a failure message."""
    try:
        log.flush()
        log.seek(0)
        text = log.read()
    except (OSError, ValueError):
        return ""
    text = text.strip()
    return f"--- blender output ---\n{text[-limit:]}" if text else ""


@contextlib.contextmanager
def captured_fd(sink, stream=1):
    """Divert Blender's C-level chatter on the given fd into `sink`.

    Cycles writes per-sample progress straight to fd 1, below Python's stdout,
    so redirecting sys.stdout is not enough. It goes to a file rather than
    /dev/null so that a failing render can still show what Blender said —
    discarding it outright would make every failure mode look identical.
    """
    saved = os.dup(stream)
    try:
        os.dup2(sink.fileno(), stream)
        yield
    finally:
        os.dup2(saved, stream)
        os.close(saved)


@contextlib.contextmanager
def passthrough_fd(_sink, _stream=1):
    """--verbose counterpart of captured_fd: leave the fd alone."""
    yield


def build_scene(bpy, stl_paths, colors, args):
    """Import the STLs and build the complete studio scene around them.

    Grounds the model at the origin (translating every mesh by the same offset,
    so multi-part assemblies keep their relative positions), then frames the
    camera and lights the studio.
    """
    import mathutils

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = args.samples
    scene.cycles.seed = 0
    scene.cycles.use_denoising = True
    scene.cycles.denoiser = "OPENIMAGEDENOISE"
    scene.render.resolution_x, scene.render.resolution_y = args.size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    # Blender defaults to 15, which barely compresses. These PNGs are committed
    # to the repo, so spend the encode time: it is lossless, pixels are
    # untouched, and it takes about a quarter off what lands in git.
    scene.render.image_settings.compression = 100
    scene.render.use_stamp = False
    # Blender otherwise appends ".png" to whatever filepath it is given, so an
    # output without that suffix would land somewhere the caller never named
    # and the existence check below would fire on the wrong path.
    scene.render.use_file_extension = False
    scene.render.threads_mode = "FIXED"
    scene.render.threads = args.threads
    # AgX (Blender 4.x default) is a film emulation that visibly mutes saturated
    # plastics. A product shot must show the filament colour that was asked for.
    scene.view_settings.view_transform = "Standard"

    objects = []
    # strict: main() has already padded or rejected, so a length mismatch here
    # is a bug rather than user input, and silently dropping STLs would render
    # a shot missing a part of the assembly.
    for path, color in zip(stl_paths, colors, strict=True):
        before = set(bpy.data.objects)
        bpy.ops.wm.stl_import(filepath=str(path))
        new = [o for o in bpy.data.objects if o not in before]
        if not new:
            sys.exit(f"error: {path} imported no geometry")
        for obj in new:
            if not obj.data.polygons:
                sys.exit(f"error: {path} loaded empty")
            objects.append((obj, color))

    # Ground the combined bounding box at the origin, one shared offset so a
    # multi-part assembly keeps its relative positions.
    corners = [
        obj.matrix_world @ mathutils.Vector(corner)
        for obj, _ in objects
        for corner in obj.bound_box
    ]
    lo = [min(c[i] for c in corners) for i in range(3)]
    hi = [max(c[i] for c in corners) for i in range(3)]
    offset = (-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2])
    for obj, _ in objects:
        obj.location = (
            obj.location.x + offset[0],
            obj.location.y + offset[1],
            obj.location.z + offset[2],
        )
    bpy.context.view_layer.update()

    extents = tuple(hi[i] - lo[i] for i in range(3))
    ex, ey, ez = extents
    diag = math.sqrt(ex * ex + ey * ey + ez * ez)

    for obj, color in objects:
        obj.data.materials.append(filament_material(bpy, color, args))
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        # Smooth only finely-tessellated curves (see SMOOTH_ANGLE); coarse
        # facets stay faceted, so the shot cannot imply a smoothness the
        # printed part will not have.
        #
        # NOT bpy.ops.object.shade_auto_smooth(): that operator appends a
        # "Smooth by Angle" geometry-nodes asset, and asset loading never
        # completes in the headless bpy module — it returns {'CANCELLED'} and
        # silently smooths nothing. shade_smooth() plus the mesh-level
        # set_sharp_from_angle() is the same result through the data API.
        # Order matters: shade_smooth() on its own smooths EVERY face, including
        # the hard edges of a box. Only pair it with the angle pass — falling
        # back to flat is right if that API is ever unavailable, since flat is
        # honest about the mesh while all-smooth actively misrepresents it.
        if hasattr(obj.data, "set_sharp_from_angle"):
            bpy.ops.object.shade_smooth()
            obj.data.set_sharp_from_angle(angle=math.radians(SMOOTH_ANGLE))
        else:
            bpy.ops.object.shade_flat()
            print(
                "warning: this Blender has no mesh.set_sharp_from_angle(); "
                "rendering flat-shaded, so curves will look faceted",
                file=sys.stderr,
            )
        obj.select_set(False)

    studio_floor(bpy, diag)
    studio_world(bpy, scene)
    studio_lights(bpy, diag)

    look_z = ez * 0.42
    location, dist = solve_camera(extents, look_z, args.rotz, args.elev,
                                  args.zoom, args.size)
    place_camera(bpy, scene, location, look_z, dist)
    return scene


def filament_material(bpy, color, args):
    """A plastic material in the requested colour, with optional layer lines."""
    mat = bpy.data.materials.new("filament")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    roughness, specular, coat, coat_rough = FINISHES[args.finish]
    r, g, b = srgb_to_linear(color)
    bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["IOR"].default_value = 1.46
    for name, value in (("Specular IOR Level", specular),
                        ("Coat Weight", coat),
                        ("Coat Roughness", coat_rough)):
        if name in bsdf.inputs:
            bsdf.inputs[name].default_value = value

    if args.layers > 0:
        # Faint bands along z, one per layer, driven into a bump. This is a
        # surface shading effect at the print's layer pitch, not geometry.
        tex_co = nt.nodes.new("ShaderNodeTexCoord")
        wave = nt.nodes.new("ShaderNodeTexWave")
        bump = nt.nodes.new("ShaderNodeBump")
        wave.wave_type = "BANDS"
        wave.bands_direction = "Z"
        wave.wave_profile = "SIN"
        # Blender's band wave evaluates sin(p * 20 * scale), so one full band
        # spans 2*pi / (20 * scale) object units. Solving that for a pitch of
        # `layers` mm gives pi / (10 * layers) — NOT 1/layers, which would put
        # the bands at 0.063 mm for a 0.2 mm layer height: 3.18x too fine to
        # survive to a pixel, so the texture would silently do nothing.
        wave.inputs["Scale"].default_value = math.pi / (10.0 * args.layers)
        wave.inputs["Distortion"].default_value = 0.0
        bump.inputs["Strength"].default_value = 0.35
        bump.inputs["Distance"].default_value = args.layers * 0.05
        nt.links.new(tex_co.outputs["Object"], wave.inputs["Vector"])
        nt.links.new(wave.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def studio_floor(bpy, diag):
    """A large, faintly glossy floor: contact shadows plus a hint of reflection."""
    bpy.ops.mesh.primitive_plane_add(size=diag * 40, location=(0, 0, 0))
    floor = bpy.context.active_object
    mat = bpy.data.materials.new("floor")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.87, 0.878, 0.895, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.22
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.35
    floor.data.materials.append(mat)
    return floor


def studio_world(bpy, scene):
    """Seamless white-studio environment; also the ambient light bath.

    A gentle vertical gradient (dimmer low, brighter high) is what makes the
    backdrop read as a lit cyclorama rather than flat paper.
    """
    world = bpy.data.worlds.new("studio")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    tex_co = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    rng = nt.nodes.new("ShaderNodeMapRange")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    rng.inputs["From Min"].default_value = -1.0
    rng.inputs["From Max"].default_value = 1.0
    ramp.color_ramp.elements[0].color = (0.72, 0.735, 0.76, 1.0)
    ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
    nt.links.new(tex_co.outputs["Generated"], sep.inputs["Vector"])
    nt.links.new(sep.outputs["Z"], rng.inputs["Value"])
    nt.links.new(rng.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    return world


def studio_lights(bpy, diag):
    """Key / fill / rim, the standard three-point product-photography setup.

    Area-light power is in watts and falls off with distance squared, so it is
    scaled by the model size to keep exposure constant across designs.
    """
    import mathutils

    key = diag * 1.5
    watts = diag * diag

    def add(name, location, energy, size, diffuse_only=False):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.size = size
        light.rotation_euler = (
            mathutils.Vector((0, 0, 0)) - mathutils.Vector(location)
        ).to_track_quat("-Z", "Y").to_euler()
        if diffuse_only:
            # Fill and rim shape the exposure; letting them cast their own
            # shadows would muddy the single clean key shadow.
            light.data.use_shadow = False
        return light

    add("key", (-key, -key * 0.9, key * 1.5), watts * 2.2, diag * 0.9)
    add("fill", (key, -key * 0.6, key * 0.8), watts * 0.55, diag * 1.2, True)
    add("rim", (key * 0.3, key, key * 1.2), watts * 0.7, diag * 0.8, True)


def place_camera(bpy, scene, location, look_z, dist):
    """Point a 30-degree-horizontal-FOV camera at the model and clip generously.

    Blender's default clip_end is 1000, and these scenes are in millimetres, so
    a 250 mm part framed from ~1.4 m away falls entirely beyond the far plane
    and renders blank with no error at all. The clip range is sized from the
    solved distance instead.
    """
    import mathutils

    cam_data = bpy.data.cameras.new("camera")
    cam_data.sensor_fit = "HORIZONTAL"
    cam_data.angle = math.radians(CAMERA_ANGLE)
    cam_data.clip_start = max(dist * 0.001, 1e-4)
    cam_data.clip_end = dist * 10.0
    cam = bpy.data.objects.new("camera", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = location
    target = mathutils.Vector((0, 0, look_z))
    cam.rotation_euler = (
        target - mathutils.Vector(location)
    ).to_track_quat("-Z", "Y").to_euler()
    return cam


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
    ap.add_argument(
        "--rotz", type=finite_float, default=35, help="orbit angle, degrees"
    )
    ap.add_argument(
        "--elev", type=finite_float, default=18, help="camera elevation, degrees"
    )
    ap.add_argument("--zoom", type=positive_float, default=1.0)
    ap.add_argument("--size", default="1280x960", type=parse_size, help="WxH pixels")
    ap.add_argument(
        "--layers",
        # finite_float, not plain float, for the same reason --rotz and --elev
        # use it: float() accepts "inf" and "nan". A positive infinity passes
        # the `layers > 0` guard and lands in the wave texture as a 1/inf
        # scale; nan passes it too and poisons the whole node tree. Finite
        # negatives still parse and fail that guard, rendering smooth — which
        # the help text states.
        type=finite_float,
        default=0.2,
        help="FDM layer-line height in mm for the surface texture "
        "(0 or negative = smooth)",
    )
    ap.add_argument(
        "--samples",
        type=positive_int,
        default=48,
        help="Cycles path-tracing samples; denoising means more than ~48 buys "
        "very little (default: 48)",
    )
    ap.add_argument(
        "--verbose",
        action="store_true",
        help="let Blender's render log through instead of capturing it "
        "(it is shown automatically when a render fails)",
    )
    ap.add_argument(
        "--threads",
        type=int,
        default=0,
        help="Cycles render threads (default: all cores). Cycles is "
        "thread-count invariant, so raising this does not change the pixels",
    )
    args = ap.parse_args()

    if args.threads <= 0:
        args.threads = os.cpu_count() or 1

    try:
        import bpy
    except ImportError:
        sys.exit(
            "error: the bpy module (Blender) is not installed — run "
            "`.claude/hooks/session-start.sh --force` to install the toolchain"
        )

    for path in args.stl:
        if not Path(path).is_file():
            sys.exit(f"error: {path} not found")

    colors = list(args.color or [])
    if len(colors) > len(args.stl):
        sys.exit(
            f"error: {len(colors)} --color values for {len(args.stl)} STL(s) — "
            "colors map to STLs in order, so the extra ones name nothing"
        )
    default = parse_color("#e8734a")
    colors += [default] * (len(args.stl) - len(colors))

    out = Path(args.output)
    try:
        out.parent.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        sys.exit(f"error: cannot create output directory {out.parent}: {e}")
    w, h = args.size

    # The output path is usually a committed PNG that already exists, so
    # "the file is there afterwards" proves nothing. Remember what was there
    # and require this run to have replaced it.
    before = out.stat().st_mtime_ns if out.is_file() else None

    diverted = passthrough_fd if args.verbose else captured_fd
    with tempfile.TemporaryFile("w+") as log:
        try:
            with diverted(log, 1):
                scene = build_scene(bpy, args.stl, colors, args)
                scene.render.filepath = str(out)
                result = bpy.ops.render.render(write_still=True)
        except Exception as e:  # noqa: BLE001 - re-raised as a clean exit below
            sys.exit(f"error: render failed: {e}\n{_tail(log)}")
        if "FINISHED" not in result:
            sys.exit(f"error: render did not finish (got {result})\n{_tail(log)}")
        if not out.is_file():
            sys.exit(f"error: render wrote no file at {out}\n{_tail(log)}")
        if before is not None and out.stat().st_mtime_ns == before:
            sys.exit(
                f"error: {out} was not rewritten by this render — the file on "
                f"disk is the previous one\n{_tail(log)}"
            )

    strip_png_metadata(out)
    print(f"wrote {out} ({w}x{h})")


if __name__ == "__main__":
    main()
