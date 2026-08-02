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
| coupon | 76/100 | 111.2 g | was 222.9 g until the override-order bug below was fixed |

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

## Verified: the coupling fails (round 1 measurements)

`nuggs-matetest.scad` renders the **intersection** of two identical straights
joined face to face — the mate is the same part mirrored and clocked by
`pitch/2`. Any non-zero volume is geometry that cannot be assembled. This is
the check that should have existed before anything was called done: every
part gates green individually, and the gate can never see an assembled joint.

**1. The ports do not nest — 1645 mm³ of interference at the insertion
clocking.** The `bite` that fuses each inner sector into *our* tube also
drives it 0.8 mm into the **mate's** tube OD, where the projecting half runs
alongside it. Predicted π(42.4² − 41.6²) × (165/360) × 10 ≈ 967 mm³ per side,
~1.9 cm³ total; measured 1645. The fix is to split the inner sector so only
the anchoring half (our side) bites, and it does drop the interference to
**exactly 0** — but the split introduces coincident cylindrical surfaces that
make CGAL return a non-watertight mesh, and rebuilding it as a full shell
plus an offset root web did not clear that either. Reverted; unresolved.

**2. The bayonet assert encodes the wrong constraint.** It reads
`twist_deg + lug_deg <= pitch`. The real limit is **`pitch/2`**: the mate's
*like-radius* sectors sit half a pitch away, so free travel is
`pitch/2 - lug_deg`, not `pitch - lug_deg`. The committed defaults
(55 + 40 = 95) satisfy the written assert and violate the true one by 35°,
so the outer sectors collide the moment you try to twist — measured 6902 mm³
of interference at the locked clocking. `lug_deg = 30, twist_deg = 25`
(55 ≤ 60) takes both the insertion and locked interference to **0.0 mm³**.
The parameters cannot be changed without fix (1), because they were what
exposed it.

**3. Nothing retains axially, in either twist direction.** With the parts
seated and clocked to lock, pulling them apart is free at 0.5, 2.0 and
5.0 mm — zero interference, so there is no bayonet at all. Two causes:
the groove floor is cut to r = 44.1 while the rib's inner face is at
r = 44.4, so the rib passes clean over the material that should catch it;
and the lead-in taper is a **solid subtracted cone**, which removes
everything *inside* it — at the ribs' z it deletes all material below
r ≈ 46.9, i.e. the ribs themselves. Removing the taper restores the ribs
and also breaks watertightness, so the tip treatment and the rib have to be
redesigned together.

## Open items — next round

- **THE JOINT DOES NOT WORK YET.** Verified this round with
  `nuggs-matetest.scad`, not guessed. Three separate defects, all still
  present in the committed geometry — see "Verified: the coupling fails" —
  and fixing them is the whole of the next round.
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
