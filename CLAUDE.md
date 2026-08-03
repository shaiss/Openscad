# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository holds 3D-printable designs co-designed in OpenSCAD. Each design is a parametric `.scad` file; the deliverables are STL files ready for slicing, plus PNG previews so the design can be reviewed without a 3D viewer.

## Environment

OpenSCAD (2021.01) runs headless here — there is no display, so every invocation must go through `xvfb-run -a`. Rendering with plain `openscad` will fail.

The scripts honor `OPENSCAD_BIN` (default `openscad`) and `OPENSCAD_ARGS`: CI's render gate runs the dev snapshot with `OPENSCAD_BIN=openscad-nightly OPENSCAD_ARGS=--backend=manifold` (order-of-magnitude faster full renders), while the stable 2021.01 check job keeps designs compatible with the release build. Locally the default is whatever `openscad` is installed; don't use nightly-only flags (like `--backend`) in scripts or designs without going through `OPENSCAD_ARGS`.

The SessionStart hook (`.claude/hooks/session-start.sh`) installs the full toolchain: openscad, xvfb, imagemagick, bpy (Blender as a Python module, for `product-shot.sh`), prusa-slicer, printcheck and stylelift (with pytest). `bpy` is a Python module rather than a command, so `command -v` won't find it — check it with `python3 -c 'import bpy'`. If any of them is missing mid-session, run `.claude/hooks/session-start.sh --force` rather than working around the gap (`--force` is needed outside Claude Code on the web, where the hook otherwise no-ops) — `gate.sh --slice` must be runnable locally.

Set `OPENSCADPATH="$PWD/lib:$PWD"` (the scripts do this automatically): `lib/` resolves library includes, and the repo root resolves `include <styles/<name>/style.scad>`. Available libraries:

- **BOSL2** (vendored at `lib/BOSL2/`) — `include <BOSL2/std.scad>`. Use for fillets/roundings (`cuboid`, `cyl`), attachments, threads (`include <BOSL2/screws.scad>`), gears, and anything geometrically hard. Prefer it over hand-rolled hulls for rounded/filleted parts.
- **MCAD** (system-installed) — `include <MCAD/...>`.
- **`lib/printability.scad`** — repo-local FDM helpers: `screw_hole()` (plain/socket/countersunk, M2–M6 presets), `teardrop_hole()` (support-free horizontal holes), `heatset_boss()`, `chamfered_cylinder()`, `rounded_box()`. Lightweight and fast; reach for these before BOSL2 for simple fastener work.
- **`lib/threads-fdm.scad`** — printable trapezoidal threads for vertical bores: `thread_helix()` (the generator), `thread_neck()` (male, with lead-in chamfer), `thread_bore_cut()` (the matching female cutter), `flank_add()` (the clearance derivation). 45° flanks so both halves print supportless, one tunable radial `tol`, and both profiles from one generator so male and female cannot drift apart. Use it over BOSL2's `screws.scad` for printed threads; use BOSL2 for machine threads.
- Each **first-party** library (the `lib/*.scad` files above; not vendored BOSL2 or system-installed MCAD) ships a `lib/<name>-demo.scad` exercising every module; `check.sh` CGAL-renders all of them, so they are those libraries' regression tests. Add one with any new first-party library.

## Commands

All commands run from the repo root.

```bash
# Render STL + 4-view preview PNG for one design (or all designs with no args)
./scripts/render.sh <name>

# Fast syntax/eval check of every .scad in the repo + lib geometry regression
# test + docs-drift check (scripts/docs-check.sh: docs must match the tree)
./scripts/check.sh

# Report-only sca2d static analysis of first-party .scad files (pip install sca2d)
./scripts/lint-scad.sh

# Render printable parts (designs/<name>/ci.parts, if present) and gate the
# STLs with tools/printcheck; --slice adds a PrusaSlicer test-slice. CI runs this.
./scripts/gate.sh [--slice] [<name>...]

# Check every design ships a product-page README.md (title, intro pitch,
# preview image, Print settings + Parameters sections). CI runs this.
./scripts/readme-gate.sh [<name>]

# Render animated GIF previews (designs/<name>/animations.conf, if present)
# into designs/<name>/previews/; commit the GIFs like the PNG previews
./scripts/animate.sh [<name>]

# Render real-world-looking product shots (designs/<name>/shots.conf, if
# present) into designs/<name>/previews/: OpenSCAD exports the STL, Blender's
# Cycles path-traces it in a studio scene (soft lighting, glossy floor, FDM
# layer lines). Commit the PNGs like the other previews; see /product-shots.
./scripts/product-shot.sh [<name>]

# Re-render a design's frozen preview shots from previews/cameras.conf
# (cameras are fixed across review rounds — see Design conventions)
./scripts/render.sh <name> --previews

# Labeled tolerance-sweep strip: N copies of the design's coupon (or entry
# part) across a parameter range, value embossed next to each copy
./scripts/render.sh <name> --sweep thread_tol=0.15:0.35:0.05

# Regenerate the README design gallery (check.sh fails when it's stale)
./scripts/gallery.sh

# Build the static product site into build/site (--serve to preview it
# locally); this is the same command Vercel runs, so green here = deploy builds
./scripts/site.sh [--serve]

# Lift a design style out of a reference mesh into styles/<name>/ — the
# measured spec later designs build from and are checked against
./scripts/style-lift.sh <name> <reference.stl> --source <url> --license <terms>
./scripts/style-lift.sh --list

# Gate the style packs (tokens in sync, swatch renders and obeys its own
# rules) and every design that names a style in designs/<name>/style.conf
./scripts/style-check.sh [<style-or-design>...]

# Calling openscad directly means setting OPENSCADPATH yourself — the scripts
# above do it for you. Without it a `use <printability.scad>` / `use
# <threads-fdm.scad>` silently resolves to nothing: OpenSCAD only WARNs about
# the unknown modules, exits 0, and hands you a watertight sliceable STL with
# the features missing (the capsule comes out with a threadless neck). The
# trailing `:$PWD` is what resolves `include <styles/<name>/style.scad>`.
export OPENSCADPATH="$PWD/lib:$PWD"

# Render a design to STL manually (full CGAL render, catches geometry errors)
xvfb-run -a openscad -o build/<name>.stl designs/<name>/<name>.scad

# Render a single custom-angle PNG (rot is x,y,z camera rotation)
xvfb-run -a openscad -o build/<name>.png --imgsize=1200,900 \
  --camera=0,0,0,55,0,25,140 --viewall --autocenter designs/<name>/<name>.scad

# Override parameters without editing the file
xvfb-run -a openscad -o build/<name>.stl -D 'wall_thickness=2.4' designs/<name>/<name>.scad
```

`scripts/render.sh` produces `build/<name>.stl` plus `build/<name>.png`, a 2×2 contact sheet (iso / top / front / bottom-iso) — the bottom-iso view exists to check overhangs and bed contact, look at it. `scripts/check.sh` is the fast pre-commit check: it echo-checks every design and lib file (surfacing WARNINGs) and CGAL-renders the lib demo. `scripts/gate.sh --slice` is what CI actually enforces.

Workflow skills (`.claude/skills/`):

- **`/preflight`** — before any push: runs the exact checks CI runs (check.sh, gate.sh --slice, printcheck tests), scoped to what changed the same way CI scopes them, and answers "would CI pass?".
- **`/new-design <name>`** — scaffolds `designs/<name>/` with everything CI and reviewers expect: entry `.scad` from the template, NOTES.md, `ci.parts` / `printcheck.args` when relevant, then first-renders it.
- **`/product-shots [name]`** — gives the product page its real-world-looking hero image: writes `shots.conf`, path-traces the studio product shot, embeds it in the README, plus an optional AI-restyled lifestyle scene when the session has an image-generation tool.
- **`/resume-design <name>`** — picks an existing design up cold: reads the recorded state (NOTES.md and friends), verifies it against fresh renders and the gate before trusting it, then briefs the human on where the design stands.
- **`/pm [name]`** — acts as one design's dedicated product manager from the charter in `designs/<name>/PM.md`: owns the non-negotiables, scope, backlog ranking and open decisions, and intrudes at defined checkpoints (a scope change, before a preview goes to the human, before a push, when a decision contradicts the charter) rather than only when asked. The reviewer skills are reactive; the PM is the one role that decides work should exist at all.
- **`/style-spec [reference.stl] [name]`** — translates a model the user likes into a committed, checkable style under `styles/<name>/`, so later design work can be told which style to build in instead of leaving the look to chance. The tool measures; the skill covers the judgement (which measurements are the family, and what an STL can never carry).

## Repository layout

- `designs/<name>/<name>.scad` — one directory per design; the `.scad` file matching the directory name is the entry point. Notes, dimensions sketches, or variants live alongside it.
- `designs/<name>/README.md` — the design's **product page**, required and CI-gated (`scripts/readme-gate.sh`): what it is, preview images, print settings, and the parameters worth tuning — everything a stranger needs to decide to print it and succeed. `NOTES.md` stays the engineering log (decisions, derivations, session-resume context); don't duplicate it here. Start from `templates/README.md`.
- `designs/<name>/PM.md` — the design's **product charter**: customer, non-negotiables (with sources), what is explicitly out of scope, the ranked backlog, open decisions and a decision log. This is what `/pm` enforces, and it is deliberately separate from NOTES.md (what happened) and README.md (what a stranger reads). Start from `templates/PM.md`; keep it under a page.
- `designs/<name>/animations.conf` — optional GIF-preview manifest (format documented in `scripts/animate.sh`). Each entry renders to a committed `previews/<anim>.gif` showing a key feature in motion — a turntable needs no model changes (camera spin); mechanism animations drive model motion from `$t` via an `anim` parameter (see sushi-battleship's shutter). The gate checks every entry has its GIF, embedded in the README, within the size budget. Compute `$t`-dependent values inside a geometry block, not in top-level assignments — top-level assignments evaluate before a `-D '$t=...'` override lands.
- `designs/<name>/shots.conf` — optional product-shot manifest (format documented in `scripts/product-shot.sh`). Each entry path-traces the exported STL into a committed `previews/<shot>.png` studio product shot for the README — the hero image a stranger sees first. The gate checks every entry has its PNG, embedded in the README, within the size budget. Shots are geometry-true (rendered from the same STL export the printable part uses), so they can never show a *feature* the print doesn't have — though shading still flatters, which is why the renderer smooths only finely-tessellated curves. Re-rendering an unchanged design reproduces the committed PNG pixel for pixel **on the same machine**; across machines expect near-identical but not byte-identical output (see `tools/photoshot/README.md`).
- `lib/` — shared OpenSCAD modules. With `OPENSCADPATH` set, designs reference them as `use <printability.scad>` / `include <BOSL2/std.scad>`. Anything used by two or more designs belongs here. `lib/BOSL2/` is vendored third-party code — never edit it.
- `build/` — generated STLs and PNGs; gitignored. STLs are regenerated from source, never hand-edited or committed.
- `scripts/` — the full toolchain: `render.sh`, `check.sh`, `gate.sh`, `readme-gate.sh`, `animate.sh`, `product-shot.sh`, `gallery.sh`, `style-lift.sh`, `style-check.sh`, `lint-scad.sh`, `site.sh` (all described above), plus `docs-check.sh` (docs-drift assertions, run by check.sh), `gate-summary.py` (turns a gate.sh log into the markdown table CI posts as the job summary and sticky PR comment) and `preview-budget.sh` (sourced helper defining the GIF and product-shot size budgets). `docs-check.sh` asserts this bullet names every file in `scripts/`, so keep it exhaustive.
- `styles/<name>/` — a **design language** lifted from a reference model, so a user can choose how a new design looks instead of getting whatever the session felt like. `STYLE.md` is the spec a modelling session reads; `style.json` is the hand-edited source of truth (measured evidence, tokens, conformance rules); `style.scad` and STYLE.md's tables are **generated** from it (`stylelift sync`); `swatch.scad` is a small part written in the style that the gate holds to the style's own rules. Designs opt in with `designs/<name>/style.conf` naming the style, and build from the tokens: `include <styles/<name>/style.scad>`. `styles/README.md` is the catalog — docs-check.sh requires every pack to be listed. Never hand-edit `style.scad`; `style-check.sh` fails on drift.
- `templates/design.scad` — starting point for new designs; demonstrates the parameter conventions below. `templates/README.md` and `templates/PM.md` are the product-page and product-charter starting points.
- `tools/printcheck/` — the STL printability analyzer gate.sh runs on every rendered part; has its own README and pytest suite (CI runs it when the tool changes).
- `tools/photoshot/` — the STL → Blender/Cycles studio renderer behind `product-shot.sh`; has its own README. Needs the `bpy` module locally, but CI never runs it: the gate only checks that the committed PNGs exist and are embedded.
- `tools/stylelift/` — measures how a mesh is *shaped* (edge softness, the rounding vocabulary, chamfer grammar, feature sizes, proportion) and turns that into a style pack; `stylelift check` holds a new part to one. Has its own README and pytest suite (CI runs it when the tool changes). It deliberately does not judge printability — that stays printcheck's job.
- `site/` — the static **product site** built from what the repo already commits (product pages, previews, product shots, style specs) and deployed on Vercel; `vercel.json` at the repo root pins the install and build commands so the deploy runs the same generator `./scripts/site.sh` does. It publishes no content of its own, and a local reference that does not resolve fails the build rather than 404ing in production. See its [README](site/README.md).
- `docs/` — repo-level research and reference notes (e.g. `oss-libraries-research.md`, the OSS-library evaluation behind the adoption backlog; `vercel-hosted-tooling.md`, the evaluation behind the site).
- `audits/` — preserved before/after render comparisons from design review rounds (e.g. `audits/pr3/`). Review history: keep it, never treat it as disposable scratch.

## Design conventions

- Every design is parametric: user-tunable dimensions are declared as top-level variables at the top of the file with a comment giving units (always millimeters) and purpose. Use the OpenSCAD Customizer section syntax (`/* [Section] */`) so parameters are grouped.
- Declare `$fn` (or `$fa`/`$fs`) at the top of the file. Use a coarse value while iterating and note the production value in a comment; final STL renders should use smooth curves (`$fn >= 64` for visible cylinders, more for large-radius curves).
- Design for FDM printing unless the user says otherwise:
  - Default wall thickness ≥ 1.2 mm (3 perimeters at 0.4 mm nozzle).
  - Orient the model so it prints flat-side-down without supports where possible; chamfer (45°) rather than fillet the bottom edges of overhangs.
  - Holes for fasteners get 0.2–0.4 mm diameter clearance; press-fit and sliding fits get explicit tolerance parameters so the user can tune for their printer.
  - Avoid features thinner than 0.8 mm (2 extrusion widths).
- **Frozen preview cameras.** A design whose previews are reviewed across rounds keeps its shots in `designs/<name>/previews/`, driven by `previews/cameras.conf` (rendered via `./scripts/render.sh <name> --previews`; format documented in `scripts/render.sh`) with per-shot descriptions in `previews/CAMERAS.md`. Once a reviewer has seen a shot its camera is **frozen** — before/after comparisons across rounds must align — so a new region gets a new cameras.conf line; never move or reframe an existing one. The same policy applies to `animations.conf` entries.
- **Following a style.** A design that declares one in `designs/<name>/style.conf` must build from that style's tokens (`include <styles/<name>/style.scad>`) rather than retyping its numbers — then it satisfies the style's rules by construction, and `./scripts/style-check.sh` proves it on every printable part. A style is a constraint on *look*, not on printability: when the two conflict, printability wins and the exception gets recorded in NOTES.md.
- Designs may carry extra per-design docs beyond NOTES.md when a work phase needs its own brief — e.g. `sushi-battleship/HARDENING.md`, the review-round hardening work plan. They are preserved history, same as NOTES.md: keep them current or mark them closed, don't delete them.
- Designs with a tuned fit (threads, sliding doors, press-fits) ship a **"print this first" coupon**: `designs/<name>/<name>-coupon.scad`, a ≤10-line include-and-override wrapper on the production modules — never copied geometry — plus a "Print this first" section in NOTES.md saying what to tune and in what steps. The wrapper relies on OpenSCAD's include-then-override semantics: keep the overrides above any geometry statements. `gate.sh` picks the wrapper up automatically and gates `build/<name>-coupon.stl` (printcheck + test-slice) like any other part.
- A design is not done until `render.sh <name>` succeeds (STL render completes without CGAL errors, PNG visually checked) **and** `gate.sh --slice <name>` exits 0 — printcheck watertightness/printability plus a PrusaSlicer test-slice. That is the bar CI enforces; `render.sh` alone is not it.

## Co-design workflow

This repo is used in a session-per-design pattern: the user starts a fresh session, brings one design idea, iterates on it here, and the finished design is committed back. Follow this loop:

1. **Brief.** Get the essentials before modeling: what the part does, the dimensions that matter (what it must fit/hold — ask for measurements), and anything printer-specific. Don't block on details you can default sensibly; state your assumptions. If the user cares how it *looks* — or shows you a model they like — settle the style here: pick one from `styles/` (`./scripts/style-lift.sh --list`), or lift a new one from their reference with `/style-spec` before modeling starts. Retrofitting a look onto a finished design means redoing the geometry.
2. **Scaffold.** Pick a kebab-case name, copy `templates/design.scad` to `designs/<name>/<name>.scad`, copy `templates/README.md` to `designs/<name>/README.md` (the product page — fill it in as the design takes shape; CI's readme-gate rejects designs without one), and create `designs/<name>/NOTES.md` recording: the goal, given measurements, key decisions, and intended print orientation. NOTES.md is what lets a later session resume the design cold — keep it current as decisions are made.
3. **Iterate preview-first.** After each meaningful change, run `./scripts/render.sh <name>` and send the user `build/<name>.png` (SendUserFile) so they react to the shape, not the code. Look at the bottom-iso view yourself for overhang/bed-contact problems before sending.
4. **Finish.** Complete the product page scaffolded in step 2 (commit the preview images it shows under `designs/<name>/previews/`). Give the page a real product shot: add a `shots.conf`, run `./scripts/product-shot.sh <name>` (see `/product-shots`), and lead the README with the result. A design is done when the user approves the preview and `/preflight` comes back green — that skill defines the check set (it mirrors CI), so don't keep a competing list here. Send the final STL to the user as well — it's the deliverable they'll slice.
5. **Commit.** Commit the design directory (`.scad`, `README.md`, `NOTES.md`, any variants) with message `Add design: <name>` (or `Update design: <name>`). If a module written for this design is generally reusable, move it into `lib/` and mention it in the commit. Push to the branch designated for the session.

Multi-part designs (lids, hinged pairs, assemblies) stay in one design directory: either one `.scad` with a `part` parameter selecting what to render, or `<name>-<part>.scad` files next to the entry point — note the choice in NOTES.md.

## Review skills

Reviewer personas live in `.claude/skills/` and can be invoked on any design PR or `designs/<name>/` directory:

- **`/jane-review`** — printability/profile review: re-derives margin math from source, exports and shell-counts the model, checks the design against what stock slicer profiles actually do (bed exclusion zones, seam defaults, bridge-angle auto-selection), and QAs preview cameras before they freeze.
- **`/drik-review`** — end-user/fitness-for-purpose review as the design's first real customer: independently recomputes every claimed number with the arithmetic shown, re-ranks the backlog by real-usage frequency, and audits for information leaks (fog-of-war) that geometry checks can't catch.
- **`/design-coach`** — becomes the dedicated review coach for one open design PR and drives verification-first rounds until it merges.
