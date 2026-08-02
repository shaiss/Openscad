# nuggs — N.U.G.G.S.

**Nugget's Universal Genderless Gallery Standard.** Design request: #34.
Full research dossier with sources: [`docs/nuggs-research.md`](../../docs/nuggs-research.md).

## Previews

![4-view contact sheet](previews/contact-sheet.png)

## Status — round 2; the coupling now works, still not printed

`./scripts/gate.sh --slice nuggs` **exits 0**. All four parts are
watertight single bodies with no CRITICAL findings:

| part | printcheck | filament | note |
|---|---|---|---|
| straight | 76/100 | 145.4 g | small bed contact patch — still the live problem |
| bulkhead_in | 84/100 | 53.5 g | |
| bulkhead_out | 84/100 | 32.6 g | |
| coupon | 76/100 | 82.1 g | |

Round 2 narrowed the sectors, which took ~15 g off the straight and ~29 g
off the coupon.

A green gate is **not** validation, but the joint is no longer taken on
faith: `nuggs-matetest.scad` now confirms two identical ports nest, twist
either way, and **retain** (below). Nothing has been physically printed, so
`port_tol` remains a guess. Open items are at the bottom.

## Goal

A short, straight, wide-bore tunnel joining **two** hamster enclosures
through their walls, for an adult Syrian. Not a tube *system* and nothing
inside the cage — see the dossier for why that framing is deliberate
(PLOS One / EXOPET-II rates tube systems unsuitable as a category; this
design answers each cited defect individually or omits the part).

Hero build — the **Bin Bridge**: bin wall → bulkhead → straight →
bulkhead → bin wall.

## Given / assumed measurements

- **Assumed, needs the owner's ruler:** `body_len_mm = 180` (Merck's upper
  head-and-body figure). This sets the entire TVT length budget. Measure the
  animal.
- **Assumed:** enclosure wall 1.5–20 mm (thin PP tote through plywood).
- **Unknown, and nobody publishes it:** Syrian shoulder width, hip width,
  and head width with both pouches loaded. The pelvis is the rigid
  non-compressible section. 80 mm is very probably generous — but that is
  not a derivation, and the bore floor is an assert precisely because of it.

## Key decisions

- **Bore 80 mm, hard floor 70 mm.** 70 is the Deutscher Tierschutzbund
  entrance minimum on the pouch-full criterion; 80 is the German
  tube-specific figure for a full-grown Syrian. `min_bore_mm` is asserted,
  never a tunable minimum.
- **Total enclosed length ≤ 2 × body length** (TVT Merkblatt 62) — asserted
  across straight + both bulkhead throats. At defaults: 160 + 2×(25+10) =
  230 ≤ 360 ✓. The bed limit (240 mm incl. port projections) binds before
  the welfare limit does, so a single-straight run cannot breach it by
  accident. **Two straights chained would** — OpenSCAD cannot assert what a
  human assembles; the README says "one straight per run".
- **Genderless coupling, and it is the whole thesis.** One tolerance knob,
  one coupon, zero coupler parts, and any module leaves the middle of a run
  in one twist — which is what the emergency-access requirement actually
  cashes out to.
- **How the genderless port works.** The coupling ring `[ro, r_out]` is
  split at `r_mid`. Each face carries the **outer** shell over `n_lug`
  sectors and the **inner** shell over the sectors between them. Two
  identical faces therefore nest: where one part presents outer shell, the
  mate presents inner shell, at a different radius. Self-complementarity is
  asserted as `lug_deg <= 360/n_lug/2`.
- **Locking** is a bayonet: each outer sector carries an inward rib, each
  inner sector a matching external groove (axial entry, then a `twist_deg`
  circumferential run). Both features exist on every part, so any face mates
  with any face.
- **A backing collar is structurally required.** The outer sectors sit at
  `r > r_mid` and touch no tube wall — without a full annular collar inside
  the tube body they are free-floating geometry. The collar doubles as the
  mate's axial stop.
- **Tube faces butt at z = 0; sectors run alongside the mate's tube.** This
  is what keeps the bore continuous — an earlier arrangement put the port
  projection *between* the faces and opened a 5.6 mm gap in the bore, which
  is a claw and pouch trap.
- **Corrected from the dossier: `lug_engage = 2.4 mm` is not usable.** At
  r = 44.4 that is 3.1° of arc, which cannot deliver the "60° twist to full
  overlap" the same document claims. Engagement is an *angle*, not a chord.
  Recorded here so the 2.4 mm figure is not reintroduced from the dossier.
- **The rib must be much narrower than the sector** (`rib_deg = 12` against
  `lug_deg = 30`). The entry slot has to admit the rib axially, so a
  full-width rib means a full-width slot and nothing left to twist under.
  This is the non-obvious constraint that made round 1's joint hold nothing.
- **The circumferential run is full sector width**, so the joint retains in
  either twist direction. Handedness is a thing to get wrong for no benefit.
- **`chamfer_ang = 50`, not 45.** printcheck's overhang test is a strict `>`
  against cos 45°, and OpenSCAD's inscribed polygons put a nominal 45° cone
  at 45.0086°. 50° costs nothing and removes the ambiguity.
- **`bite = 0.8` everywhere two solids meet.** A zero-volume "kiss" contact
  leaves CGAL counting the parts as separate bodies — this cost two debug
  rounds (see below).

## Print settings (intended, not yet validated)

- **Material:** natural/uncoloured PETG. Not PLA — PLA's Tg (57–70 °C)
  overlaps the dishwasher band, and a deformed tube is a *narrowed* tube, so
  the material failure mode is the animal-injury failure mode.
- **Orientation:** tube axis vertical.
- **Supports:** none intended; every downward face should be ≥ 50°.
- **Brim:** required, `outer_and_inner`. Not optional — see below.
- **Cleaning:** hand wash only, ≤ 50 °C. Never a dishwasher (the *dry* cycle
  is what exceeds even PETG's Tg).

## Print this first: the coupon

`nuggs-coupon.scad` is two 25 mm port stubs printed as a mated pair, from
the production modules. Tune `port_tol` in ±0.05 steps (asserted 0.10–0.60).
It doubles as the **bore gauge**: caliper it, and if the bore is under
79.0 mm your printer is shrinking and the straights will shrink too.

`port_tol = 0.30` is a starting guess, deliberately not inherited from
sushi-battleship's `clr_h`/`clr_v` — those are clearances between surfaces
made in *one* print at a fixed orientation. This joins two separately
printed ~97 mm parts and must additionally absorb per-part diameter error
and shrinkage: 0.3 % of 97 mm is 0.29 mm on its own, nearly the whole
budget. Expect the first coupon to be wrong.

## Debug log — things that cost a round

1. **13 free bodies, and printcheck called it PRINTABLE.** The first port
   rendered as 26 CGAL volumes. Two causes: (a) ribs spanning
   `[r_mid-rib_h, r_mid]` while the outer sectors start at
   `r_mid + port_tol/2` — a 0.15 mm gap, so every rib floated; (b) the
   lead-in taper was an annular cutter whose bottom plane sat exactly at the
   sector tips, slicing a 1.5 mm disc off all 12 sectors. Recut as a cone
   rising from *below* the tips. **The gate never flagged this**: multiple
   bodies is INFO, not CRITICAL, so a part that would arrive on the plate as
   13 loose pieces scored 76/100 and would have exited 0.
2. **`bulkhead_out` printed its port into the flange.** `nuggs_port()` puts
   its tube body on +z and its sectors on -z, so placing it unmirrored on top
   of the flange pointed every sector at the bed: 30 % overhang, CRITICAL,
   `gate.sh` exit 1. Mirrored and lifted by the collar height it reads 3 %.
   This is the one failure in the round the gate *did* catch on its own.
3. **The coupon was rendering the entire assembly.** The wrapper had its
   overrides *above* `include <nuggs.scad>`, so the entry file's own
   `part = "assembled"` won — OpenSCAD's include semantics are
   include-then-override, and `sushi-battleship-coupon.scad` shows the
   correct order. The "print this first" part was a 130 × 130 × 188 mm,
   223 g, 16-hour full assembly, and the gate happily gated it. Now 111 g.
   Still heavy for a fit coupon: at an 80 mm bore even two 25 mm stubs are
   ~98 cm³, nothing like the dossier's 30 g estimate.
4. Both body-count bugs were found by splitting the STL with trimesh and printing each
   body's volume, extents and centroid — the disconnected pieces were all
   exactly 1.5 mm tall at the tip radii, which named the culprit instantly.
   Worth doing on any multi-sector part before trusting the gate.

## Verified: the coupling works (round 2)

`nuggs-matetest.scad` renders the **intersection** of two identical
straights joined face to face — the mate is the same part mirrored and
clocked by `pitch/2`. Zero volume means they can occupy that position;
non-zero means they cannot. Seated, then again after a 2 mm axial pull:

| clocking | seated | pulled 2 mm | reading |
|---|---|---|---|
| 60° (insertion) | 0 | **free** | pushes together and comes apart — the entry path |
| 46° (twist −14°) | 0 | **47.8 mm³** | locked |
| 74° (twist +14°) | 0 | **47.8 mm³** | locked |

Retains in **both** twist directions, so there is no handedness to get
right at 11 pm with a hamster in the tube.

**Retention capacity.** The rib reaches `rib_h` into the mate's inner-shell
band, giving a radial engagement of 44.25 → 45.25 mm = 1.00 mm over a
12° arc, ×3 ribs = **28.1 mm² of bearing area**. At a conservative 10 MPa
that is ~281 N (29 kg); at PETG's ~30 MPa, ~844 N. The animal weighs under
2 N. Retention is not the limiting factor — `port_tol` and the rib's root
in a printed part are, which is what the coupon exists to find out.

Twist travel is ±(`lug_deg` − `rib_deg`) = ±18°, and `twist_deg = 14`
leaves 4° of margin before the rib runs off the end of the sector.

### The three round-1 defects, and what fixed each

1. **Ports did not nest (1645 mm³).** The `bite` fusing each inner sector
   to *our* tube also drove 0.8 mm into the **mate's** tube OD. Fixed by
   sweeping the inner sector as one L-shaped profile: bore-side face clears
   `ro + port_tol/2` over the projecting half, and only the anchoring half
   reaches inward to fuse. Splitting it into two arcs instead — the round-1
   attempt — left a coincident cylindrical surface and a non-watertight
   mesh, which is why every sector is now **one swept polygon, never a
   union of two arcs**.
2. **The bayonet assert encoded the wrong constraint.** `twist_deg +
   lug_deg <= pitch` allowed defaults that collide on any twist. The mate's
   *like-radius* sectors sit half a pitch away, so the real limit is
   **`pitch/2`**. Now asserted, with `lug_deg = 30`, `twist_deg = 14`.
3. **Nothing retained.** The rib was as wide as the sector, so the entry
   slot that admits it consumed the whole sector and left nothing to twist
   under; and the lead-in taper was a *solid subtracted cone*, which
   removed everything inside it — the ribs included. Fixed by making the
   rib a narrow tab (`rib_deg = 12`, asserted `rib_deg + twist_deg <=
   lug_deg`) entering through a matching narrow slot, with a **full-width**
   circumferential run at the seat so it retains either way round. The
   taper is gone; square tips are also the better bed-contact face.

## Open items — next round

- **Bed contact is the live problem, and now the top-ranked one.** Printed
  upright the straight stands on its sector tips, not a full annulus:
  printcheck reports "Small bed contact patch" and scores 76. The plain-tube
  100/100 in the dossier was measured *without* ports. Options: a
  sacrificial first-layer disc, a wider tip land, or printing port-up on a
  raft. Every user prints this part first, so a failed 145 g / 10 h print is
  the worst available first impression.
- **Nothing has been printed.** `port_tol = 0.30` is still a guess, and the
  coupon is what settles it. Geometry says the joint retains; only a printed
  pair says it does so at a torque a human wants to apply.
- **Degenerate faces** warning on the straight under CGAL 2021.01. Absent
  under the manifold backend, so it is a meshing artifact rather than a
  design fault — but trace it rather than assuming.
- Bulkhead spigot/counterbore fit is drawn but not dimensioned against a
  real wall-thickness range.
- No `previews/cameras.conf`, no `shots.conf`, no product shot yet.
- The mate test is not gated. `ci.parts` gates parts; nothing in this repo
  gates a *fit*, so a future change could silently un-fix the coupling and
  CI would stay green. Running `nuggs-matetest.scad` in the gate needs a
  convention that does not exist yet.
