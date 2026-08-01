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

# Render printable parts (designs/<name>/ci.parts, if present) and gate the
# STLs with tools/printcheck; --slice adds a PrusaSlicer test-slice. CI runs this.
./scripts/gate.sh [--slice] [<name>]

# Check every design ships a product-page README.md (title, intro pitch,
# preview image, Print settings + Parameters sections). CI runs this.
./scripts/readme-gate.sh [<name>]

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
- `designs/<name>/README.md` — the design's **product page**, required and CI-gated (`scripts/readme-gate.sh`): what it is, preview images, print settings, and the parameters worth tuning — everything a stranger needs to decide to print it and succeed. `NOTES.md` stays the engineering log (decisions, derivations, session-resume context); don't duplicate it here. Start from `templates/README.md`.
- `lib/` — shared OpenSCAD modules. With `OPENSCADPATH` set, designs reference them as `use <printability.scad>` / `include <BOSL2/std.scad>`. Anything used by two or more designs belongs here. `lib/BOSL2/` is vendored third-party code — never edit it.
- `build/` — generated STLs and PNGs; gitignored. STLs are regenerated from source, never hand-edited or committed.
- `scripts/` — `render.sh` and `check.sh`, described above.
- `templates/design.scad` — starting point for new designs; demonstrates the parameter conventions below.

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

This repo is used in a session-per-design pattern: the user starts a fresh session, brings one design idea, iterates on it here, and the finished design is committed back. Follow this loop:

1. **Brief.** Get the essentials before modeling: what the part does, the dimensions that matter (what it must fit/hold — ask for measurements), and anything printer-specific. Don't block on details you can default sensibly; state your assumptions.
2. **Scaffold.** Pick a kebab-case name, copy `templates/design.scad` to `designs/<name>/<name>.scad`, and create `designs/<name>/NOTES.md` recording: the goal, given measurements, key decisions, and intended print orientation. NOTES.md is what lets a later session resume the design cold — keep it current as decisions are made.
3. **Iterate preview-first.** After each meaningful change, run `./scripts/render.sh <name>` and send the user `build/<name>.png` (SendUserFile) so they react to the shape, not the code. Look at the bottom-iso view yourself for overhang/bed-contact problems before sending.
4. **Finish.** A design is done when the user approves the preview and `./scripts/check.sh` plus `./scripts/render.sh <name>` pass clean. Send the final STL to the user as well — it's the deliverable they'll slice. Then write the product page: copy `templates/README.md` to `designs/<name>/README.md`, fill it in (commit the preview images it shows under `designs/<name>/previews/`), and check it with `./scripts/readme-gate.sh <name>` — CI rejects designs without one.
5. **Commit.** Commit the design directory (`.scad`, `README.md`, `NOTES.md`, any variants) with message `Add design: <name>` (or `Update design: <name>`). If a module written for this design is generally reusable, move it into `lib/` and mention it in the commit. Push to the branch designated for the session.

Multi-part designs (lids, hinged pairs, assemblies) stay in one design directory: either one `.scad` with a `part` parameter selecting what to render, or `<name>-<part>.scad` files next to the entry point — note the choice in NOTES.md.
