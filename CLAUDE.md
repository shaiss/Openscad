# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository holds 3D-printable designs co-designed in OpenSCAD. Each design is a parametric `.scad` file; the deliverables are STL files ready for slicing, plus PNG previews so the design can be reviewed without a 3D viewer.

## Environment

OpenSCAD (2021.01) runs headless here — there is no display, so every invocation must go through `xvfb-run -a`. Rendering with plain `openscad` will fail.

Set `OPENSCADPATH="$PWD/lib"` (the scripts do this automatically) so library includes resolve. Available libraries:

- **BOSL2** (vendored at `lib/BOSL2/`) — `include <BOSL2/std.scad>`. Use for fillets/roundings (`cuboid`, `cyl`), attachments, threads (`include <BOSL2/screws.scad>`), gears, and anything geometrically hard. Prefer it over hand-rolled hulls for rounded/filleted parts.
- **MCAD** (system-installed) — `include <MCAD/...>`.
- **`lib/printability.scad`** — repo-local FDM helpers: `screw_hole()` (plain/socket/countersunk, M2–M6 presets), `teardrop_hole()` (support-free horizontal holes), `heatset_boss()`, `chamfered_cylinder()`, `rounded_box()`. Lightweight and fast; reach for these before BOSL2 for simple fastener work. `lib/printability-demo.scad` shows one of each and doubles as its regression test.

## Commands

All commands run from the repo root.

```bash
# Render STL + 4-view preview PNG for one design (or all designs with no args)
./scripts/render.sh <name>

# Fast syntax/eval check of every .scad in the repo + lib geometry regression test
./scripts/check.sh

# Render a design to STL manually (full CGAL render, catches geometry errors)
xvfb-run -a openscad -o build/<name>.stl designs/<name>/<name>.scad

# Render a single custom-angle PNG (rot is x,y,z camera rotation)
xvfb-run -a openscad -o build/<name>.png --imgsize=1200,900 \
  --camera=0,0,0,55,0,25,140 --viewall --autocenter designs/<name>/<name>.scad

# Override parameters without editing the file
xvfb-run -a openscad -o build/<name>.stl -D 'wall_thickness=2.4' designs/<name>/<name>.scad
```

`scripts/render.sh` produces `build/<name>.stl` plus `build/<name>.png`, a 2×2 contact sheet (iso / top / front / bottom-iso) — the bottom-iso view exists to check overhangs and bed contact, look at it. `scripts/check.sh` is the pre-commit / CI gate: it echo-checks every design and lib file (surfacing WARNINGs) and CGAL-renders the lib demo.

## Repository layout

- `designs/<name>/<name>.scad` — one directory per design; the `.scad` file matching the directory name is the entry point. Notes, dimensions sketches, or variants live alongside it.
- `lib/` — shared OpenSCAD modules. With `OPENSCADPATH` set, designs reference them as `use <printability.scad>` / `include <BOSL2/std.scad>`. Anything used by two or more designs belongs here. `lib/BOSL2/` is vendored third-party code — never edit it.
- `build/` — generated STLs and PNGs; gitignored. STLs are regenerated from source, never hand-edited or committed.
- `scripts/` — `render.sh` and `check.sh`, described above.

## Design conventions

- Every design is parametric: user-tunable dimensions are declared as top-level variables at the top of the file with a comment giving units (always millimeters) and purpose. Use the OpenSCAD Customizer section syntax (`/* [Section] */`) so parameters are grouped.
- Declare `$fn` (or `$fa`/`$fs`) at the top of the file. Use a coarse value while iterating and note the production value in a comment; final STL renders should use smooth curves (`$fn >= 64` for visible cylinders, more for large-radius curves).
- Design for FDM printing unless the user says otherwise:
  - Default wall thickness ≥ 1.2 mm (3 perimeters at 0.4 mm nozzle).
  - Orient the model so it prints flat-side-down without supports where possible; chamfer (45°) rather than fillet the bottom edges of overhangs.
  - Holes for fasteners get 0.2–0.4 mm diameter clearance; press-fit and sliding fits get explicit tolerance parameters so the user can tune for their printer.
  - Avoid features thinner than 0.8 mm (2 extrusion widths).
- A design is not done until `render.sh <name>` succeeds: the STL render must complete without CGAL errors (non-manifold geometry, zero-volume unions) and the PNG must be visually checked.

## Co-design workflow

When iterating on a design with the user: render a PNG preview after each meaningful change and send it to them (SendUserFile with the PNG) so they can react to the shape, not the code. Only produce the final STL once the shape is agreed.
