# OSS libraries & tooling research (August 2026)

A survey of current open-source libraries and tools on GitHub (and adjacent
forges) that could apply to this repo, matched against what we already have:
vendored [BOSL2](https://github.com/BelfrySCAD/BOSL2), system MCAD,
`lib/printability.scad`, `tools/printcheck` (trimesh-based STL gate), and a
PrusaSlicer test-slice in CI — all running on OpenSCAD **2021.01**.

## TL;DR — ranked recommendations

| # | What | Why it matters here | Effort |
|---|------|--------------------|--------|
| 1 | **OpenSCAD nightly + Manifold backend** | 10–100× faster full renders; CI gate + local iteration speedup. 2021.01 is 5 years old and still the latest stable — the ecosystem has moved to dev snapshots. | Low–medium |
| 2 | **[NopSCADlib](https://github.com/nophead/NopSCADlib)** | Vitamins (screws, inserts, electronics), BOM generation, exploded assembly views — directly matches our heatset/fastener and preview-driven-review workflows | Low (vendor like BOSL2) |
| 3 | **[SCA2D](https://gitlab.com/bath_open_instrumentation_group/sca2d)** linter | Static analysis for `.scad` (scope/variable-shadowing bugs the echo-check in `check.sh` can't see) | Low (`pip install sca2d`) |
| 4 | **[Round-Anything](https://github.com/Irev-Dev/Round-Anything)** | `polyRound`: per-point radii on 2D profiles + `polyRoundExtrude` end fillets — the easiest way to do fully-rounded extruded profiles; complements BOSL2 | Low |
| 5 | **[Tweaker-3](https://github.com/ChristophSchranz/Tweaker-3)** | Auto-orientation scoring for STLs — could extend printcheck to *suggest* a better print orientation instead of just flagging overhangs | Medium |
| 6 | **[openscad_docsgen](https://github.com/BelfrySCAD/openscad_docsgen)** | Generate markdown + image docs for `lib/printability.scad` from comments (it's what BOSL2 itself uses; the `.openscad_docsgen_rc` is already vendored in `lib/BOSL2/`) | Low |

Details and the wider field below.

## 1. OpenSCAD itself: nightly + Manifold is the big win

- There is **still no stable release after 2021.01** ([issue #6664](https://github.com/openscad/openscad/issues/6664)); the project's own guidance is that serious users run dev snapshots ([downloads](https://openscad.org/downloads.html)).
- The **[Manifold](https://github.com/elalish/manifold) geometry backend** left
  experimental status in the 2024.09+ snapshots and is now the default in
  nightlies — replacing CGAL for CSG. Reported speedups run from 10× to
  "half an hour → under three seconds"
  ([PR #4533](https://github.com/openscad/openscad/pull/4533),
  [mailing list](https://lists.openscad.org/empathy/thread/D6KV3ZLXHLBHSITSQ5GPUZUKHURU4ABE)).
  CGAL stays available via `--backend=cgal`.
- Nightlies also bring newer language/CLI features we currently design around:
  `roof()`, built-in `fill()`, textures, lazy-union, better 3MF export, and
  `--export-format` improvements.
- Install paths for our headless Ubuntu CI: the
  [openscad-nightly apt/snap packages](https://snapcraft.io/openscad-nightly)
  (parallel-installable with the release build, binary is `openscad-nightly`),
  or the marketplace action
  [`Irev-Dev/action-install-openscad-nightly`](https://github.com/marketplace/actions/install-openscad-nightly)
  which also sets up xvfb.

**Suggested adoption:** add nightly alongside 2021.01; let
`scripts/render.sh` / `gate.sh` prefer `openscad-nightly` when present with a
fallback, and keep one CI job on 2021.01 so designs stay compatible with the
stable release most users have. Full-render CI time should drop dramatically
(sushi-battleship's multi-part CGAL renders are the current long pole).

## 2. Geometry / parts libraries

### NopSCADlib — parts library + project framework ⭐ recommended
[nophead/NopSCADlib](https://github.com/nophead/NopSCADlib) (GPL-3.0, actively
maintained by an OpenSCAD core developer). "Vitamins" (screws, heatset
inserts, bearings, extrusions, PCBs, displays, hinges…), printed-part
helpers, and Python scripts that generate **BOMs, per-part STLs, DXFs, and
assembly instructions with exploded-view PNGs** scraped from comments. Our
repo already reinvents small pieces of this (contact sheets, `ci.parts`,
NOTES.md conventions) — for multi-part designs like sushi-battleship, the
BOM/exploded-view pipeline would slot straight into the review-round workflow.
Caveat: GPL-3.0 (BOSL2 is BSD-2) — fine for our use, worth noting in lib docs.

### Round-Anything — rounding via point lists ⭐ recommended
[Irev-Dev/Round-Anything](https://github.com/Irev-Dev/Round-Anything) (MIT).
`polyRound()` takes `[x, y, radius]` point lists — a much more direct way to
build rounded 2D profiles than nested `offset()`/`hull()`, and
`polyRoundExtrude()` fillets the top/bottom of the extrusion (chamfer-friendly
for FDM bottoms). Small, stable, zero dependencies; complements BOSL2 rather
than overlapping it (BOSL2 rounds primitives and paths; polyRound rounds
arbitrary hand-authored profiles).

### dotSCAD — functional/curve toolkit
[JustinSDK/dotSCAD](https://github.com/JustinSDK/dotSCAD) (LGPL-3.0). Bézier
curves and surfaces, path extrusion, voronoi, turtle graphics, function
plotting. High-quality code; most useful if a design needs organic/curved
surfaces beyond BOSL2's sweeps. Adopt on demand rather than pre-vendoring.

### threads-scad
[rcolyer/threads-scad](https://github.com/rcolyer/threads-scad) (CC0). Single
file, printer-tolerance-aware threading. **Not recommended**: BOSL2's
`screws.scad`/`threading.scad` (already vendored) covers this with more
options; adding a second thread library would fragment our designs.

### gridfinity-rebuilt-openscad
[kennetek/gridfinity-rebuilt-openscad](https://github.com/kennetek/gridfinity-rebuilt-openscad)
(MIT). The de-facto parametric implementation of the Gridfinity organizer
standard. Not a general library — but if an organizer/bin design session comes
up, start from this instead of modeling bins from scratch.

### Others surveyed, lower priority
From the [official libraries page](https://openscad.org/libraries.html) and
[LibHunt's OpenSCAD topic](https://www.libhunt.com/l/openscad/topic/openscad):
[UB.scad](https://github.com/UBaer21/UB.scad) (broad utility lib, FDM-aware,
active), [Constructive](https://github.com/solidboredom/constructive)
(stamping/positioning DSL for assemblies),
[StoneAgeLib](https://github.com/StoneAgeSculptor/StoneAgeLib) (new-ish, CC0),
[BOLTS](https://github.com/boltsparts/BOLTS) (standard-parts DB, quiet lately),
[keyv2](https://github.com/rsheldiii/KeyV2) (keycaps, niche). None fill a gap
BOSL2 + NopSCADlib wouldn't; revisit per-design.

## 3. Dev tooling & CI

### SCA2D — static analysis ⭐ recommended
[bath_open_instrumentation_group/sca2d](https://gitlab.com/bath_open_instrumentation_group/sca2d)
(GPL-3.0, `pip install sca2d`). Lexes `.scad` properly and flags scope
problems — variable shadowing/redefinition across `use`/`include` — which our
echo-based `check.sh` can't detect (OpenSCAD itself only WARNs on some).
Early-stage but low-risk to add as a non-fatal CI step first (report-only),
promoting to a gate once we see its false-positive rate on BOSL2-heavy code.

### scadformat — formatter
[hugheaves/scadformat](https://github.com/hugheaves/scadformat) (GPL-3.0, Go,
single binary, opinionated/zero-config). Would end formatting drift across
design sessions. Alternative: clang-format via the
[VS Code extension](https://github.com/JulianGmp/vscode-openscad-formatter)
approach. Optional — our style is already consistent by convention.

### openscad_docsgen
[BelfrySCAD/openscad_docsgen](https://github.com/BelfrySCAD/openscad_docsgen)
(pip-installable; BOSL2's own doc generator — its config files ship in our
vendored `lib/BOSL2/`). Adding its comment format to `lib/printability.scad`
would give us generated markdown + rendered example images for the repo's own
helpers, useful as the lib grows.

### Tweaker-3 — auto-orientation
[ChristophSchranz/Tweaker-3](https://github.com/ChristophSchranz/Tweaker-3)
(MIT, Python/numpy). Scores orientations by support volume / surface,
evolutionary-tuned. Natural printcheck extension: when the overhang or
bed-contact check fails, run Tweaker-3 and report "rotating [x,y,z] would cut
support area N%" instead of only flagging. Pure-Python, same dependency
family (numpy) as our trimesh stack.

### manifold3d (Python bindings)
[elalish/manifold](https://github.com/elalish/manifold) publishes
`manifold3d` on PyPI — guaranteed-manifold booleans and mesh repair.
Printcheck currently *detects* non-watertight meshes; manifold3d would let a
future `printcheck --repair` attempt a fix, and is also the fastest way to
compute true shell/wall measurements. Optional dependency candidate.

### OpenSCAD MCP server(s)
E.g. [quellant/openscad-mcp](https://glama.ai/mcp/servers/@quellant/openscad-mcp) —
MCP wrappers around OpenSCAD render/preview. Given this repo's Claude-driven
co-design workflow, worth watching, but our `scripts/` + skills already cover
the same ground with more control; no action now.

## 4. What we already have that's healthy

- **BOSL2** — ~2k stars, commits within days of this writing; keep the vendored
  copy fresh (last sync worth checking against upstream).
- **trimesh** (printcheck) — remains the standard Python mesh-analysis stack.
- **PrusaSlicer CLI gate** — still the right ground-truth check; no OSS
  replacement offers a better headless test-slice.

## Sources

- https://openscad.org/libraries.html
- https://openscad.org/downloads.html
- https://www.libhunt.com/l/openscad/topic/openscad
- https://github.com/openscad/openscad/issues/6664
- https://github.com/openscad/openscad/pull/4533
- https://lists.openscad.org/empathy/thread/D6KV3ZLXHLBHSITSQ5GPUZUKHURU4ABE
- https://github.com/marketplace/actions/install-openscad-nightly
- https://snapcraft.io/openscad-nightly
- https://github.com/nophead/NopSCADlib
- https://github.com/Irev-Dev/Round-Anything
- https://github.com/JustinSDK/dotSCAD
- https://github.com/rcolyer/threads-scad
- https://github.com/kennetek/gridfinity-rebuilt-openscad
- https://gitlab.com/bath_open_instrumentation_group/sca2d
- https://github.com/hugheaves/scadformat
- https://github.com/BelfrySCAD/openscad_docsgen
- https://github.com/ChristophSchranz/Tweaker-3
- https://github.com/elalish/manifold
