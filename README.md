# Openscad

Parametric, 3D-printable designs written in [OpenSCAD](https://openscad.org/).

## Layout

- `designs/<name>/<name>.scad` — one directory per design; the matching `.scad` file is the entry point
- `lib/` — shared modules: `printability.scad` (FDM fastener/chamfer helpers) and vendored [BOSL2](https://github.com/BelfrySCAD/BOSL2)
- `build/` — generated STL/PNG outputs (gitignored)
- `scripts/render.sh` — render one design (`./scripts/render.sh <name>`) or all of them (no args); produces an STL and a 4-view preview sheet
- `scripts/check.sh` — fast syntax/geometry validation of every `.scad` file
- `scripts/gate.sh` — render each design's printable parts and gate the STLs with printcheck; `--slice` adds a PrusaSlicer test-slice (this is what CI runs)
- `scripts/readme-gate.sh` — check every design ships a product-page `README.md` (CI runs this too)
- `templates/design.scad`, `templates/README.md` — starting points for a new design and its product page
- `tools/printcheck/` — STL printability analyzer (`printcheck build/<name>.stl`); scores rendered models for watertightness, overhangs, thin walls, and bed adhesion before slicing — see its [README](tools/printcheck/README.md)

Each design directory contains the parametric source, a `README.md` product page (what it is, previews, print settings, tunable parameters — start there to print one), and a `NOTES.md` engineering log recording its requirements, measurements, and design decisions.

## Rendering

Requires OpenSCAD on the PATH. In headless environments, prefix commands with `xvfb-run -a`:

```bash
./scripts/render.sh <name>   # produces build/<name>.stl and build/<name>.png
```

All dimensions are in millimeters. Designs target FDM printing by default and expose printer-tuning parameters (wall thickness, fit tolerances) at the top of each file.
