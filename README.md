# Openscad

Parametric, 3D-printable designs written in [OpenSCAD](https://openscad.org/).

## Layout

- `designs/<name>/<name>.scad` — one directory per design; the matching `.scad` file is the entry point
- `lib/` — shared modules reused across designs
- `build/` — generated STL/PNG outputs (gitignored)
- `scripts/render.sh` — render one design (`./scripts/render.sh <name>`) or all of them (no args)

## Rendering

Requires OpenSCAD on the PATH. In headless environments, prefix commands with `xvfb-run -a`:

```bash
./scripts/render.sh <name>   # produces build/<name>.stl and build/<name>.png
```

All dimensions are in millimeters. Designs target FDM printing by default and expose printer-tuning parameters (wall thickness, fit tolerances) at the top of each file.
