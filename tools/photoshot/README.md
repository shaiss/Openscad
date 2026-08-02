# photoshot — STL → studio product shot

Point it at an STL exported by OpenSCAD and it raytraces a product-page hero
image with POV-Ray: seamless studio backdrop, soft key/fill/rim lighting, a
glossy floor carrying the contact shadow, and a plastic material with faint
FDM layer lines. It is the render half of `./scripts/product-shot.sh` (which
does the geometry-true STL export first and drives this from each design's
`shots.conf`), but it runs standalone on any STL.

```bash
python3 tools/photoshot/photoshot.py build/calibration-cube.stl \
  -o designs/calibration-cube/previews/product-hero.png \
  --color e8734a --finish satin --rotz 35 --elev 18 --zoom 0.85 --size 1280x960
```

## Requirements

- **povray** (+ `povray-includes`) on `PATH`. A missing povray is a hard exit
  pointing at the installer; the SessionStart hook apt-installs both packages,
  so run `.claude/hooks/session-start.sh --force` rather than work around it.
- **Python 3 + trimesh**, for STL loading only. trimesh is a printcheck
  dependency, so `pip install -e tools/printcheck` covers it.

## Usage

| Argument | Default | Notes |
|---|---|---|
| `stl ...` | required | one or more; all composed into a single scene |
| `-o`, `--output` | required | output PNG; parent directories are created |
| `--color` | `#e8734a` | repeatable, one per STL in order; `#rrggbb`, bare `rrggbb`, or the 3-digit short form |
| `--finish` | `satin` | `satin` \| `gloss` \| `matte` |
| `--rotz` | `35` | orbit angle around the grounded model, degrees |
| `--elev` | `18` | camera elevation, degrees |
| `--zoom` | `1.0` | scales an automatic bounding-box fit; must be > 0 |
| `--size` | `1280x960` | output `WxH` in pixels |
| `--layers` | `0.2` | FDM layer-line pitch in mm for the surface texture; `0` or negative = smooth, `nan`/`inf` rejected |
| `--no-radiosity` | off | faster, flatter light (see below) |
| `--threads` | `0` | POV-Ray render threads; `0` picks the reproducible default — 1 with radiosity, 4 without |
| `--keep-pov` | off | keep the generated `.pov` next to the PNG instead of deleting it |

`--rotz`/`--elev`/`--zoom` reject `nan`/`inf`, and `--zoom` rejects values ≤ 0.
Coordinates are OpenSCAD's — z-up, millimeters.

## How the scene is built

Everything is generated in `scene()`; there is no `.pov` template on disk.

- **Framing.** All meshes are translated by one shared offset that centres the
  combined bounding box in xy and grounds it on `z = 0` (so multi-part
  assemblies keep their relative positions). The camera is a 30° *horizontal*
  FOV mild telephoto with `sky z`, looking at 42% of the model height; the
  push-back distance is solved so every bbox corner clears **both** the
  horizontal and the vertical FOV, times a 1.06 margin, divided by `--zoom`.
  That is why a tall part cannot silently lose its top edge.
- **Backdrop.** A `sky_sphere` with a z-gradient from light grey to white —
  both the visible seamless-studio background and the radiosity light bath.
- **Light rig**, scaled to the model's bbox diagonal: a key `area_light`
  (circular, `orient`, 5×5 samples) high and camera-left; a shadowless fill at
  `rgb 0.30` camera-right; a shadowless rim at `rgb 0.35` behind and above.
- **Floor.** An infinite near-white plane at `z = 0` with a fresnel
  `reflection { 0.03, 0.09 }` and `conserve_energy`. The soft floor reflection
  and contact shadow, the area-light penumbra and the bounced light are what
  make the output read as photographed rather than as a viewport render.
- **Radiosity** (on by default): `count 80 error_bound 0.6 recursion_limit 2
  nearest_count 8 brightness 0.75`, with `ambient 0` everywhere so all fill
  light is actually bounced. `--no-radiosity` swaps it for a flat `ambient 0.28`.
- **Material.** Each STL becomes a `mesh2` with an sRGB→linear pigment
  (`assumed_gamma 1.0`), a finish from the table below, and `interior { ior
  1.46 }`. When `--layers > 0` a `normal { gradient z, 0.35 triangle_wave }`
  scaled to the layer pitch adds FDM layer lines — a shading perturbation only,
  it never changes geometry.

  | finish | diffuse | specular | roughness | reflection |
  |---|---|---|---|---|
  | `satin` | 0.72 | 0.30 | 0.012 | 0.015–0.05 |
  | `gloss` | 0.62 | 0.55 | 0.004 | 0.03–0.12 |
  | `matte` | 0.85 | 0.08 | 0.060 | none |

POV-Ray is invoked with `+A0.3 +AM2 +R3 +Q9 -D +WT<threads>`.

## Determinism

Same STL, same args, same machine ⇒ byte-identical PNG. Shots are committed
and diffed across review rounds, so a shot that moves without a geometry change
means something else drifted (manifest, scene code, POV-Ray version). Three
sources of run-to-run noise are handled deliberately:

- Area-light `jitter` randomizes shadow rays per run, so it is never used;
  penumbra quality comes from the denser 5×5 sample grid instead (and
  `adaptive` is left off, since it prunes samples by contrast).
- Radiosity's sample cache is gathered in thread-completion order, so radiosity
  renders single-threaded by default. `--threads N` buys speed by giving that
  up; without radiosity, threads are safe (hence the default of 4).
- POV-Ray stamps the PNG with wall-clock `tIME`/`tEXt`/`zTXt`/`iTXt` chunks.
  Those are dropped after the render by a chunk-level rewrite that never
  re-encodes, so pixels are untouched.

The guarantee is scoped to one machine; a different POV-Ray build is not
promised to match.

## Colors in `shots.conf`

The manifest field is bare `rrggbb`, **no leading `#`**: `product-shot.sh`
truncates each manifest line at the first `#` (`line="${line%%#*}"`), so a `#`
would comment out the rest of the shot. `parse_color()` here `lstrip("#")`s
either way, so on the command line both forms work.

## Multi-STL composition

Multiple positional STLs render into one scene and `--color` maps to them in
order — a two-tone assembly is `photoshot.py body.stl lid.stl --color 333
--color e8734a -o shot.png`. Any mesh past the last `--color` falls back to the
default orange, and surplus colors are ignored without complaint. Note that
`shots.conf` drives exactly one STL export per entry, so multi-STL scenes are
run by hand (see the `/product-shots` skill).

## No tests yet

Unlike `tools/printcheck/`, this tool ships no pytest suite and no
`pyproject.toml` — it is one script invoked by `scripts/product-shot.sh`. Its
pure functions (`parse_size`, `parse_color`, `finite_float`,
`srgb_to_linear`, `strip_png_metadata`, the camera solve in `scene()`) are
unit-testable as they stand, but any end-to-end check needs povray installed,
which CI does not have — CI only verifies, via `scripts/readme-gate.sh`, that
every `shots.conf` entry has a committed README-embedded PNG within the size
budget. Re-rendering an unchanged design and confirming `git status` stays
clean is the practical regression test.
