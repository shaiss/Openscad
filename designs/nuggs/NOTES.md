# nuggs — N.U.G.G.S.

**Nugget's Universal Genderless Gallery Standard.** Design request: #34.
Full research dossier with sources: [`docs/nuggs-research.md`](../../docs/nuggs-research.md).

## Previews

![4-view contact sheet](previews/contact-sheet.png)

## Status — first modelling round; gate green, NOT validated

`./scripts/gate.sh --slice nuggs` **exits 0**. All four parts are
watertight single bodies with no CRITICAL findings:

| part | printcheck | filament | note |
|---|---|---|---|
| straight | 76/100 | 160.6 g | small bed contact patch — see open items |
| bulkhead_in | 84/100 | 57.3 g | |
| bulkhead_out | 84/100 | 38.0 g | |
| coupon | 84/100 | 222.9 g | coupon is heavier than a bulkhead — see open items |

A green gate is **not** validation. Nothing has been printed, and the lock
kinematics have not been verified by mating two rendered copies. Treat every
number here as provisional. Open items are at the bottom.

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
  overlap" the same document claims. The engagement is an *angle*
  (`twist_deg`, default 40°), not a chord length. Recorded here so the
  2.4 mm figure is not reintroduced from the dossier.
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
3. Both body-count bugs were found by splitting the STL with trimesh and printing each
   body's volume, extents and centroid — the disconnected pieces were all
   exactly 1.5 mm tall at the tip radii, which named the culprit instantly.
   Worth doing on any multi-sector part before trusting the gate.

## Open items — next round

- **Bed contact is the live problem.** Printed upright the part now stands
  on its sector tips, not a full annulus: printcheck reports "Small bed
  contact patch" and the score is 76. The plain-tube 100/100 in the dossier
  was measured *without* ports. Options: a sacrificial first-layer disc, a
  wider tip land, or printing the straight port-up on a raft. Unresolved.
- **Degenerate faces** warning on the straight — trace and fix.
- **Lock kinematics unverified.** Mate two rendered copies at the insertion
  clocking and at +`twist_deg`, and measure the boolean intersection volume:
  it must be zero at both, and the ribs must overlap the groove run axially.
  This is the single most important check before any print.
- **`gate.sh --slice nuggs` has not been run green** across all four STLs.
- Bulkhead spigot/counterbore fit is drawn but not dimensioned against a
  real wall thickness range.
- No previews/cameras.conf, no shots.conf, no product shot yet.
