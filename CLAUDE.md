# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository holds 3D-printable designs co-designed in OpenSCAD. Each design is a parametric `.scad` file; the deliverables are STL files ready for slicing, plus PNG previews so the design can be reviewed without a 3D viewer.

## Environment

OpenSCAD (2021.01) runs headless here — there is no display, so every invocation must go through `xvfb-run -a`. Rendering with plain `openscad` will fail.

## Commands

All commands run from the repo root.

```bash
# Render a design to STL (full CGAL render, catches geometry errors)
xvfb-run -a openscad -o build/<name>.stl designs/<name>/<name>.scad

# Render a PNG preview for visual review
xvfb-run -a openscad -o build/<name>.png --imgsize=1200,900 --viewall --autocenter designs/<name>/<name>.scad

# Syntax/type check only (fast, no geometry) — exports an echo-only run
xvfb-run -a openscad -o /dev/null --export-format echo designs/<name>/<name>.scad

# Override parameters without editing the file
xvfb-run -a openscad -o build/<name>.stl -D 'wall_thickness=2.4' designs/<name>/<name>.scad

# Render STL + PNG for one design in one step
./scripts/render.sh <name>
```

`scripts/render.sh` renders every design under `designs/` when called with no arguments — use it as the "build everything / CI check" command.

## Repository layout

- `designs/<name>/<name>.scad` — one directory per design; the `.scad` file matching the directory name is the entry point. Notes, dimensions sketches, or variants live alongside it.
- `lib/` — shared OpenSCAD modules (`use <../../lib/foo.scad>` from a design). Anything used by two or more designs belongs here.
- `build/` — generated STLs and PNGs; gitignored. STLs are regenerated from source, never hand-edited or committed.
- `scripts/render.sh` — render helper described above.

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
