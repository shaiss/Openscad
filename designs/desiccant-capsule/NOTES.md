# Desiccant Capsule

## Previews

![4-view contact sheet](previews/contact-sheet.png)

| Closed assembly | Section through the thread zone |
|---|---|
| ![Assembly](previews/assembly.png) | ![Cutaway](previews/cutaway.png) |

The cutaway faces the cut plane: male ribs (body) interleave the female
grooves (lid) with the thread_tol clearance visible as the zigzag gap;
the lid rim seats on the body shoulder below the threads.

## Goal

Refillable two-part capsule for loose silica gel beads, lived-in filament
dry-boxes. Perforated body lets air/moisture reach the beads; screw-on lid
with real threads (not press-fit) and a ribbed grip edge so it can be opened
with dry-box gloves on. Must print on FDM with no supports on either part.

## Given measurements

- Body: ~30 mm outer diameter, ~40 mm tall (defaults: 30 x 40).
- Silica gel beads: 2-3 mm diameter — every opening must be < 2 mm.

## Key decisions

- **Single `.scad` with a `part` parameter** (`body`, `lid`, `print`,
  `assembly`, `cutaway`). Default is `print` (both parts laid out) so
  `render.sh` emits a directly sliceable STL. `assembly`/`cutaway` are
  review views; the cutaway shows thread engagement.
- **Vents**: `vent_style="hex"` (default) or `"slot"`. Hexes are
  vertex-up so wall openings print supportless (30 deg from vertical);
  slots bridge only their own 1.8 mm width. Default opening `vent_w=1.8`
  across corners → inscribed width ~1.56 mm, safely below 2 mm beads.
  Floor is perforated too (`floor_vents=true`), plain first-layer holes.
- **Threads**: custom trapezoidal helical polyhedron (2-start, 4 mm pitch
  → 8 mm lead, lid opens in ~1 turn; depth 1.2 mm). Flanks are exactly
  45 deg so the male thread prints supportless upright. BOSL2 screws.scad
  was considered; hand-rolled sweep kept the profile/printability fully
  under parameter control and the file dependency-free.
- **Thread fit**: `thread_tol=0.3` clearance on the female thread — equal
  radially and normal to the flanks (derivation below). Lid binds → +0.1
  and reprint lid only; too loose → -0.1.
- **Lid**: rim seats on the body shoulder as a positive closing stop;
  lead-in chamfer at the rim; 24 grip ribs (~35 mm over ribs). Interior
  shoulder in the body is a 45 deg cone (no internal supports).
- Walls 2.0 mm, floor 2.0 mm, lid top 2.4 mm; webs between vents 1.6 mm —
  all above the 0.8 mm minimum-feature rule.

## Thread clearance derivation

The thread profile has 45 deg flanks (slope dz/dr = +/-1 in the radial
plane). The female groove is the male profile transformed two ways:

1. translated **radially outward** by `thread_tol` (major and minor
   diameters both grow by `2*thread_tol`), and
2. **widened axially** by `flank_add/2` on each side (`w_add` in
   `thread_helix`).

Crest/root clearance is radial displacement alone = `thread_tol`.

For a 45 deg plane, a radial shift of `t` moves the plane `t/sqrt(2)`
along its normal, and an axial shift of `a` moves it `a/sqrt(2)` — and
for this profile both displacements move each flank *away* from its
mating flank. So the flank-normal gap is:

```
gap = (thread_tol + flank_add/2) / sqrt(2)
```

Requiring `gap == thread_tol` gives:

```
flank_add = 2*(sqrt(2) - 1)*thread_tol   ~= 0.83*thread_tol
```

which is what the code uses. One unit of `thread_tol` now buys exactly
one unit of clearance at crests, roots, and flank normals alike.

(Note: counting only the axial term would predict a flank gap of
`thread_tol/(2*sqrt(2))` ~= 0.11 mm and early binding — but that ignores
the radial translation's `thread_tol/sqrt(2)` ~= 0.21 mm contribution to
the same normal. Even the previous `w_add = thread_tol` gave
`1.06*thread_tol` on the flanks, i.e. within 6% of uniform; the current
form makes it exact.)

## Bead containment guard

Openings are guarded by `assert()` against `bead_min = 2.0` minus
`bead_margin = 0.2` (beads shed size over repeated drying cycles). A bead
passes an opening iff it fits the opening's inscribed circle:

- hex vents (vertex-up): inscribed width = `vent_w*cos(30)` ~= 0.87*vent_w
- slot vents: slot width = `vent_w`
- floor holes (round): diameter = `vent_w`

Both wall styles and the floor holes are checked; a `vent_w` that could
leak a worn bead fails the render with a message saying the allowed
maximum. Defaults (hex 1.56 mm effective, slot/floor 1.8 mm) pass.

## Print orientation

- **Body**: as modeled, upright on its floor. No supports.
- **Lid**: `part="lid"` already outputs it flipped — flat top on the bed,
  internal threads up a vertical bore. No supports.
- PETG/PLA both fine; silica regeneration temps suggest PETG if the
  capsule goes in a warm oven with the beads (or empty it first).

## Status

Both parts and the closed assembly CGAL-render clean; thread engagement
verified in the committed cutaway preview (uniform thread_tol gap at
crests, roots, and flank normals; flanks interleaved). Review round 1
(previews committed, clearance derivation, bead-containment asserts)
addressed on the PR thread.
