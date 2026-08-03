# Desiccant Capsule

## Previews

![4-view contact sheet](previews/contact-sheet.png)

| Closed assembly | Section through the thread zone |
|---|---|
| ![Assembly](previews/assembly.png) | ![Cutaway](previews/cutaway.png) |

![Vent close-up](previews/vents-closeup.png)

Vent close-up at printable scale: 0.8 mm slots, 2.4 mm webs (3 x the
0.8 mm minimum feature).

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
- Silica gel beads: originally 2-3 mm; **revised in PR review round 2 to
  indicating silica gel, 1-3 mm** — every opening must retain a worn
  1 mm bead (effective opening <= 0.8 mm at the default margin).

## Key decisions

- **Single `.scad` with a `part` parameter** (`body`, `lid`, `print`,
  `assembly`, `cutaway`). Default is `print` (both parts laid out) so
  `render.sh` emits a directly sliceable STL. `assembly`/`cutaway` are
  review views; the cutaway shows thread engagement.
- **Vents**: `vent_style="slot"` (default) or `"hex"`. Default is
  0.8 mm-wide vertical slots with 2.4 mm webs, in two staggered bands.
  Slots became the default in review round 2 when the bead spec dropped
  to 1 mm: sub-1 mm hex holes tend to seal shut on a 0.4 mm FDM nozzle,
  while narrow vertical slots print crisply (each slot bridges only its
  own 0.8 mm width). Hex (vertex-up, supportless) remains available for
  coarser beads. Floor is perforated too (`floor_vents=true`), plain
  first-layer holes.
- **Threads**: custom trapezoidal helical polyhedron (2-start, 4 mm pitch
  → 8 mm lead, lid opens in ~1 turn; depth 1.2 mm). Flanks are exactly
  45 deg so the male thread prints supportless upright. BOSL2 screws.scad
  was considered; hand-rolled sweep kept the profile/printability fully
  under parameter control. Now shared via `lib/threads-fdm.scad` rather
  than defined here — see "Thread engine moved to lib/" below.
- **Thread fit**: `thread_tol=0.3` clearance on the female thread — equal
  radially and normal to the flanks (derivation below). Lid binds → +0.1
  and reprint lid only; too loose → -0.1.
- **Lid**: rim seats on the body shoulder as a positive closing stop;
  lead-in chamfer at the rim; 24 grip ribs (~35 mm over ribs). Interior
  shoulder in the body is a 45 deg cone (no internal supports).
- Walls 2.0 mm, floor 2.0 mm, lid top 2.4 mm; webs between vents 2.4 mm
  (was 1.6 mm in the round-1 hex pattern) — all above the 0.8 mm
  minimum-feature rule.

## Thread engine moved to lib/ (issue #18)

The helix generator and the male/female pair now live in
`lib/threads-fdm.scad`; this design keeps thin `male_neck()` /
`female_thread_cut()` wrappers that bind its own parameter names to the
library call. The derivation below is unchanged and is what
`flank_add()` implements there.

Verified behaviour-preserving at extraction: `argus diff` of the exported
STL before vs after reports 0 bodies added/removed/modified and +0.00%
volume (12387.6 mm³ both sides), 11,376 triangles and printcheck 92/100
either way. Byte-comparing the STL does **not** work as a check — CGAL's
facet ordering varies run to run, so two renders of identical source
differ in ~200 kB.

Extracting also surfaced a precondition this design never violated: the
axial profile height must fit inside the lead
(`0.25*pitch + w_add + 2*depth < pitch*starts`), or consecutive turns
self-intersect and CGAL fails on the union with an opaque assertion. The
capsule sits at 3.4 against a lead of 8, which is why it never showed up
here; `thread_helix()` now asserts it.

## Thread clearance derivation

The thread profile has 45 deg flanks (slope dz/dr = +/-1 in the radial
plane) **where the two parts mate** — from the core surface out to the
crest. Below the core surface the profile continues for another
`sink = 0.4` as a vertical weld skirt, which carries no thread: the neck's
core cylinder swallows it, and the lid's minor bore removes it.

That distinction was the substance of issue #37. Everything derived below
assumes a 45 deg flank, and until that issue was fixed the built profile
did not have one: a single straight flank ran across the whole span
including the skirt, giving slope `depth/(depth + sink)` = 0.75, i.e.
36.87 deg. So this section was arithmetically correct and describing a
shape the library was not producing. Measured on the export before and
after, by unwrapping the helix back to its generating polygon:

```text
before:  flank slope 0.750 (36.87 deg)  ->  delivered gap 0.279400  (6.87% short)
after:   flank slope 1.000 (45.00 deg)  ->  delivered gap 0.299990  (exact)
```

The fix was to the profile, not to the derivation below — `flank_add` is
unchanged. The invariant is now tested against built geometry rather than
restated, in `lib/threads-fdm-mates.conf`.

The female groove is the male profile transformed two ways:

1. translated **radially outward** by `thread_tol` (major and minor
   diameters both grow by `2*thread_tol`), and
2. **widened axially** by `flank_add/2` on each side (`w_add` in
   `thread_helix`).

Crest/root clearance is radial displacement alone = `thread_tol`.

For a 45 deg plane, a radial shift of `t` moves the plane `t/sqrt(2)`
along its normal, and an axial shift of `a` moves it `a/sqrt(2)` — and
for this profile both displacements move each flank *away* from its
mating flank. So the flank-normal gap is:

```text
gap = (thread_tol + flank_add/2) / sqrt(2)
```

Requiring `gap == thread_tol` gives:

```text
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

(That last comparison holds only at a 45 deg flank, which is why issue #37
read it as backwards: at the 36.87 deg the profile actually had, it was
`w_add = thread_tol` that came out exact and the current form that ran 6.9%
tight. Fixing the flank angle rather than the constant is what makes the
paragraph true as written — the alternative would have been to keep the
wrong angle and tune `flank_add` to compensate for it, leaving the rib
overhanging past the 45 deg rule in CLAUDE.md.)

## Bead containment guard

Openings are guarded by `assert()` against `bead_min = 1.0` (indicating
silica, 1-3 mm grade) minus `bead_margin = 0.2` (beads shed size over
repeated drying cycles). A bead passes an opening iff it fits the
opening's inscribed circle:

- hex vents (vertex-up): inscribed width = `vent_w*cos(30)` ~= 0.87*vent_w
- slot vents: slot width = `vent_w`
- floor holes (round): diameter = `vent_w`

Both wall styles and the floor holes are checked; a `vent_w` that could
leak a worn bead fails the render with a message saying the allowed
maximum. Defaults (slot/floor 0.8 mm) pass at exactly the limit. The
round-1 hex defaults (1.8 mm) correctly fail under this spec — that
rejection is what forced the round-2 vent rework.

## Vent open-area accounting

Reported by `echo` at render time, computed from the same variables the
geometry modules cut with (`vcols`, `slot_nseg`, `slot_seg`, `hex_rows`,
`fl_counts`):

| | Wall open area | % of vent band | Floor | Total |
|---|---|---|---|---|
| Round 1 (hex 1.8 / web 1.6) | 454.6 mm² | 20.1% | 53.4 mm² | 508.0 mm² |
| Round 2 (slot 0.8 / web 2.4) | 501.1 mm² | 22.2% | 10.6 mm² | 511.7 mm² |

Wall-only change: +10.2%; wall+floor: +0.7% — both within the 15%
budget. The band is the 24 mm-tall perforated zone (`pi * 30 * 24 =
2262` mm²).

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
and round 2 (1 mm bead spec: slot vent rework + open-area accounting)
addressed on the PR thread. Thread, lid, and body envelope unchanged
since round 1.
