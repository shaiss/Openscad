# Desiccant Capsule

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
- **Thread fit**: `thread_tol=0.3` radial clearance on the female thread
  (also widens the groove axially). Lid binds → +0.1 and reprint lid only;
  too loose → -0.1.
- **Lid**: rim seats on the body shoulder as a positive closing stop;
  lead-in chamfer at the rim; 24 grip ribs (~35 mm over ribs). Interior
  shoulder in the body is a 45 deg cone (no internal supports).
- Walls 2.0 mm, floor 2.0 mm, lid top 2.4 mm; webs between vents 1.6 mm —
  all above the 0.8 mm minimum-feature rule.

## Print orientation

- **Body**: as modeled, upright on its floor. No supports.
- **Lid**: `part="lid"` already outputs it flipped — flat top on the bed,
  internal threads up a vertical bore. No supports.
- PETG/PLA both fine; silica regeneration temps suggest PETG if the
  capsule goes in a warm oven with the beads (or empty it first).

## Status

Both parts and the closed assembly CGAL-render clean; thread engagement
verified in the cutaway view (uniform ~0.3 mm gap, flanks interleaved).
