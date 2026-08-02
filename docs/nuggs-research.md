# N.U.G.G.S. — design research dossier

Research and printability groundwork behind the **`design request`** issue
[#34](https://github.com/shaiss/Openscad/issues/34): *N.U.G.G.S. — an
interlocking 80 mm hamster tunnel bridging two enclosures*. Kept here the
same way `docs/oss-libraries-research.md` backs the library-adoption
backlog — the issue is the ask, this is the working behind it.

Two halves, and they have very different evidential weight:

1. **[Measured here](#part-1--measurements-run-on-this-repos-toolchain)** —
   printcheck / PrusaSlicer / OpenSCAD runs on this repo's own toolchain.
   Reproducible; re-run them before trusting them anyway.
2. **[Researched and fact-checked](#part-2--synthesised-design-plan)** — a
   five-dimension research sweep (Syrian hamster welfare, habitat-tube
   ecosystem, FDM printability, repo/CI mechanics, system architecture),
   each dossier then handed to an adversarial fact-checker instructed to
   *refute* rather than agree. Corrections won over originals, and the
   refuted figures are named in place so they cannot creep back in.

> **Provenance caveat, load-bearing:** every external source below was
> reached through web-search result summaries under an egress block that
> returned 403 on effectively every research host. **No page was read end
> to end.** The fact-check pass caught four load-bearing errors in the
> first-pass research — which says the method works, and does not
> substitute for reading the primary text. Before any of this reaches a
> published product page, verify in the original: the DTSchB 7 cm entrance
> minimum, TVT Merkblatt 62's exact wording on the 2x-body-length limit,
> the PLOS One verdict, and the 20 mm loaded-pouch width.

---

## Part 1 — Measurements run on this repo's toolchain

Everything below was measured in this session on the repo toolchain
(OpenSCAD 2021.01 headless, printcheck, PrusaSlicer), not quoted.
Probe sources are committed alongside this doc:
`docs/nuggs-probes/{tube,elbow,bend,vent}-probe.scad`. Reproduce the
headline figure with:

```bash
OPENSCADPATH="$PWD/lib" xvfb-run -a openscad -o /tmp/repro.stl \
  -D 'part="vertical"' -D 'bore=80' -D 'wall=2.4' -D 'len=160' -D '$fn=128' \
  docs/nuggs-probes/tube-probe.scad
printcheck /tmp/repro.stl --build-volume 256x256x256   # 100/100, no findings
```

Note the probes sit outside `check.sh`'s glob (`designs/*/*.scad
lib/*.scad templates/*.scad`), so nothing re-validates them automatically
— they are frozen reproduction inputs, not maintained sources.

## 1. Print orientation for a 75 mm-bore tube (150 mm long, 2.4 mm wall)

printcheck --build-volume 256x256x256:

| orientation | score | finding |
|---|---|---|
| vertical (axis Z) | **100/100 PRINTABLE** | no issues at all |
| horizontal (axis X) | 92/100 | 23% of surface overhangs >45° — 17,055 mm² needing support |
| clamshell half, cut-face down | 84/100 | 23% overhang + tip-over risk |

printcheck escalates the overhang finding from WARNING to CRITICAL at 25%
(tools/printcheck/src/printcheck/checks.py:173). The horizontal tube sits
at 23% — **two points under a hard CI failure**. Vertical is not a
preference, it's the only orientation with margin.

Bed contact, vertical: **582.6 mm² against a 6,368 mm² footprint = 9.2%**,
above printcheck's 5% "small bed contact patch" threshold (checks.py:248)
— confirmed, no warning raised.

Two corrections to an earlier draft of this line, both caught in review on
PR #35, because the method matters more than the conclusion here:

- **The footprint is the bounding box, not a circle.** printcheck uses
  `footprint = mesh.extents[0] * mesh.extents[1]` (checks.py:238), so for
  an OD of 79.8 mm it is 79.8 × 79.8 = 6,368 mm² — not pi*39.9² = 5,001 mm².
  The earlier "11.7%" used the circular area and was wrong.
- **Contact is measured, not derived.** Running printcheck's own
  `plate_contact_faces()` over the mesh gives 582.6 mm², slightly under the
  analytic annulus pi*(39.9² − 37.5²) = 583.6 mm², because a faceted
  polygon is marginally smaller than the ideal circle it approximates.

The conclusion is unchanged — 9.2% clears the 5% threshold and no warning
fires — which is exactly why the wrong number survived a first pass. **The
gate's silence here is not a pass**; see §"the warning nothing can give
you" implication under the v1 straight below.

## 2. Bend angle: 45 deg is the printable ceiling

Mitred bend (two straight legs meeting on the bisecting plane), printed
standing on its inlet flange:

| bend | score | overhang finding |
|---|---|---|
| 15 deg | 92/100 | none |
| 45 deg | 92/100 | **none** |
| 60 deg | 84/100 | 9% of surface overhangs >45° |
| 90 deg | 84/100 | 11% of surface overhangs >45° |

(The 92s are a thin-wall warning from the 0.02 mm epsilon overlap in my
probe's boolean — a probe artifact, not a design finding. The real signal
is the overhang column.)

Swept (radiused) 90 deg elbow for comparison: 84/100 flat on the bed
(23% overhang + small bed contact 615/13,202 mm²), 92/100 with one leg
vertical (10% overhang).

=> **45 deg is the maximum bend a single printed module can carry
support-free.** A 90 deg turn is two 45 deg modules coupled, not one part.
And if the coupling can be clocked, two 45s reach any direction change
from 0 to 90 deg in any plane — one bend part covers the whole system.

Watch out: the naive miter (union of two half-space-cut tubes) renders
NON-WATERTIGHT at 30 deg and 45 deg — coplanar-face artifact, printcheck
CRITICAL, gate fails. The real design needs a single swept solid
(rotate_extrude / hull of end profiles), not a boolean of two cut tubes.

## 3. Print cost — the adoption risk

150 mm straight segment, 75 mm bore, 3 perimeters, 15% infill,
PrusaSlicer, 1.24 g/cm3 PLA:

| config | time | filament |
|---|---|---|
| 2.4 mm wall, 0.20 layer, 0.4 nozzle | 6h 55m | 106.4 g |
| 2.4 mm wall, 0.28 layer, 0.4 nozzle | 4h 57m | 105.6 g |
| 2.4 mm wall, 0.30 layer, 0.6 nozzle | **3h 26m** | 105.5 g |
| 1.6 mm wall, 0.20 layer, 0.4 nozzle | 5h 03m | 69.6 g |
| 1.6 mm wall, 0.30 layer, 0.6 nozzle | **2h 16m** | 68.7 g |

Filament is set by wall thickness; time is set by layer height + nozzle.
They are independent levers.

Bore cost curve (150 mm segment, 2.4 mm wall, 0.20/0.4) — linear in bore,
as circumference says it should be:

| bore | OD | time | filament |
|---|---|---|---|
| 55 mm | 60 mm | 5h 18m | 78.9 g |
| 65 mm | 70 mm | 5h 57m | 92.7 g |
| 75 mm | 80 mm | 6h 49m | 106.4 g |
| 85 mm | 90 mm | 8h 01m | 120.2 g |

A 1 m run at 75 mm bore / 2.4 mm wall is ~710 g and ~46 h at 0.2/0.4,
or ~15 h at 0.3 with a 0.6 nozzle. This is the number that decides whether
anyone finishes the build.

## 4. Ventilation holes

60 x 6 mm round radial holes in a vertical tube wall: 1% overhang area,
84/100. At 6 mm the round-vs-teardrop difference measured as ~0-1% either
way, so lib/printability.scad's teardrop_hole() is not required at this
size — it becomes the tool if vent diameter grows.

## 5. Connector constraint derived from orientation

A genderless (Storz-style) twist-lock has hooks on both ends. Printed
vertically, one end's hook undersides necessarily face down = overhang.
=> hook undersides must be 45 deg chamfered to stay self-supporting.
Repo precedent exists: sushi-battleship's castellated rail lips use
"45 deg chamfered undersides (self-supporting, no drooping overhangs)"
(designs/sushi-battleship/NOTES.md). Reuse, don't reinvent — this is
exactly what open issue #19 proposes extracting into lib/.

## 6. CI reality (read from the scripts, not assumed)

- scripts/gate.sh: ci.parts -> one STL per part via -D part="...";
  <name>-coupon.scad rendered and gated too; printcheck run with
  designs/<name>/printcheck.args; --slice adds PrusaSlicer at 0.2 mm /
  0.4 mm nozzle / 1.24 g cm-3.
- printcheck exits non-zero only on verdict "NOT PRINTABLE AS-IS", i.e.
  any CRITICAL finding (report.py:57). WARNINGs cost 8 points each,
  CRITICALs 25 (report.py:17).
- readme-gate.sh: H1 + prose pitch + non-empty "Print settings" and
  "Parameters" sections + >=1 committed local preview image; every
  shots.conf / animations.conf entry needs its committed file, embedded,
  within budget (MAX_GIF_BYTES 6 MiB, MAX_SHOT_BYTES 3 MiB).
- CI re-gates every design when lib/, scripts/, tools/printcheck/ or
  ci.yml change (.github/workflows/ci.yml).

### The proposed straight, measured at final dimensions

Bore 80, wall 2.4, length 160, printed vertically — the actual v1 part,
not a stand-in:

```
printcheck nuggs-straight.stl --build-volume 256x256x256
  size: 84.8 x 84.8 x 160.0 mm   bodies: 1   watertight: True
  SCORE: 100/100 — PRINTABLE
  No issues found.

prusa-slicer 0.2 mm / 0.4 nozzle / 5 perimeters / 20% infill / PETG 1.27
  estimated printing time = 8h 5m 37s
  total filament used [g] = 123.95
```

Solid-annulus theory gives pi*(42.4^2 - 40^2)*160 = 99,405 mm3 = 126.2 g at
1.27 g/cm3, so the slicer came in 1.8% under theory. Bare tube only —
flanges and lugs add roughly 12% on top.

Bed contact: **621.0 mm2 measured** (via printcheck's own
`plate_contact_faces()`; the analytic annulus is 621.3) against a
7,191 mm2 bounding-box footprint
= 8.6%, above printcheck's 5% threshold, so **no brim warning will ever
fire** on a 160 mm-tall part standing on a 2.4 mm-wide ring. Brim is a
README instruction, not a gate outcome.

Plate throughput: pitch 84.8 + 6 = 90.8 mm, floor(256/90.8) = 2 per axis
= **4 straights per plate** printed vertically, against 2 horizontal and
1 as clamshell halves.

---

## Part 2 — Synthesised design plan

*(Corrections from the adversarial fact-check are already folded in;
refuted figures are named inline with a warning marker so they cannot be
reintroduced by a later reader who only remembers the first draft.)*


**N.U.G.G.S. — Nugget's Universal Genderless Gallery Standard**
*"No Uphill Gradients, Go Short."*

> The winning acronym from the architecture dossier used **Gnawproof**. Dropped. The strongest source available says "chew-resistant," and the documented rodent hazard is ingestion of fragments. Naming a standard after a property you cannot deliver is the thing that gets quoted back at you. **Genderless** replaces it — it is literally true, it is the actual technical thesis, and it is the strongest single argument in the whole research set. "Gallery" is the correct zoological term for a burrow tunnel (Gattermann et al. 2001 uses "gallery system"). If the hamster is not called Nugget, the fallback is *Nocturnal Underground Genderless Gallery Standard*.

---

## 1. The pitch

N.U.G.G.S. is a deliberately **short** 80 mm-bore tunnel that joins two hamster enclosures through their walls, for someone with a Bambu-class printer, a spool of natural PETG, and an adult Syrian whose factory 55 mm cage tubes are too narrow for a pouch-full animal. It is not a tunnel *system* and it does not go inside the cage: peer-reviewed work (PLOS One / EXOPET-II 2022) rated tube systems **unsuitable as a product category**, and the German veterinary welfare association (TVT Merkblatt 62) names the reasons — they cannot be ventilated, they condense, they cannot be cleaned, and transparent tube denies a prey animal refuge. N.U.G.G.S. exists to answer each of those defects individually rather than to ignore them: one straight opaque run, capped at **twice the animal's body length** (TVT's own limit), **open at both ends into two ventilated enclosures** so there is no closed volume and no dead end, at a bore **80 mm** — the German welfare figure for an adult golden hamster, ~1.96× the cross-section of a Kaytee Fun-nel at its nominal diameter. Every joint is one genderless quarter-turn coupling: one tolerance knob, one 30-minute coupon, and any module comes out of the middle of a run in one twist for washing. The hero build is the **Bin Bridge** — two bins side by side, one 89 mm hole in each facing wall at bedding height, two bulkheads, one 160 mm straight. It doubles the animal's territory without consuming one cm² of floor or one cm of substrate.

---

## 2. Hard safety constraints

Each is a design constraint with its number and source. Where the fact-checker corrected a figure, **the corrected value is used and the refuted one is named** so it cannot creep back in.

| # | Constraint | Number | Why |
|---|---|---|---|
| **S1** | **No passage anywhere may be narrower than 70 mm ID** — measured at the worst point, including inside the bulkhead throat, at every joint, and through any future bend's inscribed circle. Non-negotiable `assert`, never a Customizer-tunable minimum. | **70 mm** | Deutscher Tierschutzbund's Goldhamster brochure: *"the entrance diameter should be 7 cm so that the animals can pass through easily even with full cheek pouches."* ⚠️ **The 65 mm figure in circulation is Hamsterhilfe Südwest, a rescue org — not the DTSchB, and 5 mm below what the body it was attributed to actually publishes.** Do not use 65 mm. |
| **S2** | **Design target 80 mm ID for the sustained run.** | **80 mm** | German tube-specific guidance: *"mindestens 7–8 cm Innendurchmesser… mindestens 8 cm für ausgewachsene Goldhamster."* 80 mm is the stated minimum for a *full-grown* Syrian, not the top of a range. A doorway is a momentary squeeze; a tube is a traverse with no room to reverse. |
| **S3** | **Sizing case is the pouch-full animal, not the resting one.** Cheek pouches are 20 mm wide when full, 40 mm long, extending to the scapulae. | 20 mm/pouch | ScienceDirect (veterinary science): *"4–8 mm wide when empty and 20 mm when full"*, *"20 × 40 mm"*. ⚠️ The "30 mm head + 2×20 mm = 70 mm" derivation is **not** independent corroboration — the 30 mm head width is uncited and the geometry double-counts. The agreement with 70 mm is coincidence. Cite DTSchB, not the arithmetic. |
| **S4** | **Body girth is not the binding constraint** — do not size the bore from it. Uniform-cylinder equivalent diameter is 37–48 mm across the whole mass range, comfortably under every bore under discussion. The pouch is what binds. | 37–48 mm | Derived; and hamsters are compressible, so "clearance per side" is not a wedging criterion. ⚠️ The "1.34 mm clearance at 200 g" alarm figure is **retracted** — it rested on a CritterTrail bore of 50.8 mm when Kaytee publishes 2.25 in / 57.15 mm. |
| **S5** | **Total enclosed tube length ≤ 2 × body length = 360 mm.** This is the single hardest quantitative limit available and it drives the entire architecture. | **360 mm** (2 × 180) | TVT Merkblatt 62 (Jan 2010, rev. April 2024): plastic tubes are acceptable only up to twice the animal's body length. Merck Vet Manual: head-and-body **170–180 mm**. ⚠️ Gattermann's 200 cm wild gallery is **not** a length licence — a soil burrow is snug, substrate-buffered and self-ventilating; a smooth sealed bore is the exact object TVT condemns. Measure your animal and use 2× its real length. |
| **S6** | **Chronic injury is silent.** An undersized opening lets sharp grains inside a full pouch lacerate the mucosa → impaction → abscess, with no wedging event and no visible symptom until surgery. | USD 400–1000 | Hamsterhilfe Südwest + hamsterrettung-nord (mechanism), Tree of Life Exotics (debridement/marsupialisation, cost band). **Consequence: "my hamster fits fine" is not valid validation.** The bore floor must be a hard assert, not a user judgement. |
| **S7** | **No dead-air volume and no dead end.** Every enclosed length must be a through-path open at both ends into a ventilated enclosure. No caps, no blind branches. Any future branch terminates in a chamber the animal can turn around in (> 180 mm across). | 0 closed volumes | TVT: long tube systems produce condensation in which pathogens proliferate; cannot be adequately ventilated. NC3Rs: 20–24 °C, 45–65 % RH; TNZ 28–30 °C; hamsters cannot sweat or pant. ⚠️ No ppm target is defensible — the NIOSH REL is **25 ppm TWA / 35 ppm STEL** (50 ppm is the *OSHA* PEL), and Broderson's 25 ppm was the *lowest concentration tested* (the LOAEL), not proof that no threshold exists. Target zero unventilated pockets, not a number. |
| **S8** | **No vertical runs. Maximum incline 15°.** Maximum end-to-end height difference on a 160 mm straight = 160 × sin 15° = **41.4 mm**. Both bore floors are drilled level at the bedding surface, so the design case is 0°. | ≤ 15° | Small-mammal husbandry: 20–30° is the "ideal" band; an independent keeper source reports tubes steeper than 20° are already hard for a hamster to climb, so take the bottom. ⚠️ **The reason is not "Syrians can't climb" — they climb well, using claws and toes.** The real mechanism is that they have essentially no depth perception, fall, and break limbs. Assuming they can't climb predicts they won't enter a steep section; the truth is they will. |
| **S9** | **No unbroken free-fall drop above 150 mm.** | 150 mm | ⚠️ The graded 25 / 38–51 / 51–76 cm tiers are invented precision from pet-content sites that disagree with each other; the "300 mm max vertical span" has exactly one blog behind it. The only defensible band is **~15–25 cm**; take the lower end. In v1 the drop is 0 by construction. |
| **S10** | **Emergency access: the entire enclosed length opens by hand, tool-free, in one action.** State the opening action in the README. | 1 action, < 5 s | Welfare: the realistic emergency is a wedged or pouch-impacted animal that cannot reverse. A 60° twist releases the straight; the whole 160 mm run comes free with the animal inside. Do not pull the animal. Glued or screwed assembly does not satisfy this. |
| **S11** | **No chew-initiation geometry anywhere the animal can reach.** No thin free edges, no protruding tabs, no sharp lips inside the bore. All coupling hardware lives on an outboard annulus. | — | Rodent incisors grow continuously and need a purchase point to start. Ingested fragments cause GI obstruction and laceration. ⚠️ *"Most hamsters don't chew hard plastic"* is anecdote and is **not** a safety argument. Assume they will. |
| **S12** | **Opaque, natural/uncoloured filament.** Inspectability comes from geometry (short straight run, line of sight end to end), not from clear walls. | — | TVT: transparent tubes offer *"no optical possibility of retreat."* English pet guidance wants visibility. Resolve by design, not by picking a side. Colour is a safety decision: cheap pigments can carry Pb/Cd/Cr, red/orange/pink fail compliance most often, and "FDA compliant" typically covers only the base polymer. A gnawing rodent abrades pigment straight into its mouth. |
| **S13** | **Hand wash only. Never a dishwasher.** Max wash temperature 50 °C. | 50 °C | PLA Tg 57–70 °C vs dishwasher 50–75 °C plus heated dry >70 °C → overlap. **A deformed tube is a narrowed tube — the deformation failure mode converts directly into the animal-injury failure mode.** PETG Tg is **80–85 °C** (corrected up from "75–80"), so the wash is fine but the *dry cycle* reaches into the band. Neither material is dishwasher safe. |
| **S14** | **No interoperability with any commercial tube system. No reducers, ever.** | 18.4 % short | Kaytee publishes 2.25 in / 57.15 mm for Fun-nels (some Fun-nels are sold as 2 in / 50.8 mm, and Kaytee never states ID vs OD). Against the 70 mm floor: 70 − 57.15 = 12.85 mm = **18.4 % short**; against the 80 mm target, 28.6 % short. ⚠️ The "22–27 %" headline is retracted — it used a bore Kaytee's own pages contradict. Adapting down imports the exact defect the product exists to fix. |
| **S15** | **Respect the enclosure budget.** The tunnel consumes zero floor area and zero substrate — it runs *between* enclosures, at bedding height. | 100 × 50 cm floor, 25–30 cm bedding | PDSA and Blue Cross each independently recommend min. 100 × 50 × 50 cm with ≥ 25 cm substrate; DTSchB 100 × 100 × 70 cm with ≥ 30 cm. Hauzenberger et al. 2006 shows **substrate depth** is what demonstrably fixes hamster welfare (10 cm group: significantly more wire-gnawing; 40 and 80 cm groups burrowed). A tunnel that displaces bedding or floor is a net welfare loss. An in-cage L-run would eat 24.5 % of a *minimum* floor — which is why there is no in-cage configuration. |
| **S16** | **Never drill tempered glass.** Detolf and most tank panels are tempered and shatter under a hole saw. v1 does not serve glass enclosures. | — | Documented Detolf conversion failures. Say this in the model *and* the README, not just the FAQ. |

---

## 3. The interlock standard

**One connector. Genderless. Round bore. Storz-*style* — cite the principle, never brand the product with the name.**

### 3.1 Why genderless (in order of force)

1. **One tolerance knob, one coupon.** Gendered M/F means two mating geometries, two fits, two failure modes, and a coupon that tests both. Genderless means `port_tol` is tuned once on a 30 g part and every joint in the kit — 3 modules today, a dozen eventually — is tuned. In an FDM system, fit *is* the product.
2. **No orphan ends, no couplers.** With M/F you inevitably end a sub-assembly with two males facing each other and need a double-female in the kit. Genderless: zero couplers.
3. **Reversibility for cleaning.** Any module comes out of the middle of a run and goes back either way round, at 11 pm, wet, one-handed. This is what S10 (emergency access) actually cashes out to.
4. **Halves the future part count.** A gendered elbow needs a left and a right variant; identical ports mean one printed elbow does both.

### 3.2 Bore profile: round, not arched

The architecture dossier proposed a flat-floored arch. **Rejected**, on three grounds the fact-check established:

- Its bulkhead argument is backwards. The arch's minimum enclosing circle is 91.87 mm; a 72.3 mm round throat admits at most 90.5 % of the arch's area, so the wall crossing **is** the pinch point. Comparing *areas* is not passability.
- Its traction argument is geometrically false. Printing flat-floor-down puts the build-plate texture on the **outside** of the floor; the animal walks on an internal top-solid surface 2.4 mm above it, which is smooth and probably ironed.
- Its printability argument is moot once the tube prints **vertically**, which is independently the best orientation (§7).

A round 80 mm bore is rotationally symmetric, which is what makes the whole rest of this coherent: with no vent slots (S7 — there is no closed volume to vent) there is no "floor arc" to protect, so the coupling needs **no keyed orientation at all**. The N-fold-symmetry-vs-single-orientation conflict that broke the earlier connector proposals simply does not arise. State honestly that a round bore cradles rather than flattens: a ~45 mm-wide animal in an 80 mm bore sits centred, with the wall rising at ≤ 30° at its flanks. Longitudinal slip is handled by S8 (horizontal by rule), not by ribs.

### 3.3 Geometry, concretely enough to write `module nuggs_port()`

Each port face is identical. Working outward from the bore:

1. **Bore continuity.** The 80 mm bore runs dead straight through the port zone. Nothing protrudes inward, anywhere, ever.
2. **Internal edge break.** `bore_lead = 1.0 mm` at `bore_lead_ang = 50°`, cut as a relief at each face. This is deliberately **more than double** the worst-case elephant's-foot lip (0.1–0.2 mm in-plane spread on a vertically printed part's bed face). Any residual spread lands inside the relief and presents a ramp, never a lip a claw or a loaded pouch can catch. *(This is the defect the "zero internal step" claim exempted itself from: a vertically printed tube's butt face **is** its bed face.)*
3. **Three lugs, T-section, one handedness.** `n_lug = 3`, `lug_deg = 55°` angular width, gaps 65°. Each lug stands `lug_h = 3.2 mm` proud of the face on a pitch diameter outboard of the bore, with a head overhanging `lug_engage = 2.4 mm` **in the locking-twist direction only**. Same handedness on every lug — that is what makes the pattern its own complement.
4. **Self-complementarity rule (assert it):** `lug_deg <= 360/n_lug/2` → 55 ≤ 60 ✓. At the mating clocking each face's lug sits in the opposing face's gap; a **60° twist (half a lug pitch)** carries every lug into full overlap with its opposite number. Heads interlock with each other — there is no separate retaining ring, which is why the lugs must be this wide. Three points is kinematically determinate: no rocking, and the three lug roots at 120° are also the radial centring feature, so no separate spigot register is needed (and no gendered register to fight the symmetry).
5. **Wedge, not gap.** The head undersides are ramped at `lug_ramp = 50°`, so the twist draws the two faces together under preload. Designed `face_gap = 0`. This is what makes the joint tight without a tight sliding fit — the ramp eats the tolerance. 50° rather than 45° because printcheck's overhang test is a strict `>` against cos 45° and a nominally-45° surface sits within ~1e-4 of it; 50° costs nothing and removes the ambiguity. *(Note: the mechanism is faceting, not strictness — OpenSCAD's inscribed polygons make a nominal 45° cone come out at 45.0086°, always biased toward passing. The advice is prudence, not the threshold story originally given for it.)*
6. **Detent.** A `detent_h = 0.4 mm` bump on the lug's leading flank near the end of travel, dropping into a shallow pocket, plus a hard stop at 60°. Sets the twist-off torque and stops vibration back-off.
7. **Everything outboard.** No lug, ramp, detent, pocket or free edge is inside the bore or reachable from it (S11).

### 3.4 Indexing

**None required, and that is a feature.** Round bore + no vent slots ⇒ rotationally symmetric ⇒ any of the three engagement clockings is correct. The bulkhead's 6-bolt circle is what fixes the run's angle in space (you drill the two wall holes level; S8), not the coupling.

### 3.5 How it resists a hamster opening it

- **A bayonet cannot be opened by axial force.** The heads interlock in Z; an animal bracing and pushing loads them in shear and root bending, not in the release direction.
- **Release needs a 60° torque couple across two separate bodies.** An animal inside the bore has no purchase on both parts simultaneously.
- **Both bulkhead halves are rotationally fixed** by 6× M4 through the enclosure wall, so only the straight can turn — and it needs two human hands.
- **The detent** resists nudging and vibration back-off.
- **No cantilever, no snap arm.** Snap-fit was originally rejected on stacked pessimism (1 % design strain + constant-section beam ⇒ a bogus 16–21 mm arm; at 2 % with a tapered beam it is ~10–12 mm, which is ordinary). It is rejected here for a *different and better* reason: a protruding thin arm is a chew-initiation site (S11) and a fatigue item on a joint opened weekly for cleaning. The bayonet has neither.

### 3.6 Tolerance parameters

| Name | Default | Role |
|---|---|---|
| `port_tol` | **0.30 mm** | **The one knob.** Applied as a uniform surface offset: the pocket is cut with the lug solid inflated by `port_tol` in all directions, so circumferential, radial and ramp-normal clearances move together. Tune on the coupon in ±0.05 steps. Asserted 0.10–0.60. |
| `detent_h` | 0.40 mm | Twist-off torque. Raise if the joint backs off; lower if it needs two hands to break. |
| `bore_lead` / `bore_lead_ang` | 1.0 mm / 50° | Internal edge break; swallows elephant's foot. |
| `bolt_clr` | 0.40 mm | M4 clearance in the bulkhead flanges. |

⚠️ Do **not** import `clr_h = 0.5 / clr_v = 0.4` from sushi-battleship as "printer-validated." Those are clearances between two surfaces made in **one** print at a fixed orientation. A coupling between two separately printed ~93 mm parts must additionally absorb per-part diameter error and shrinkage — 0.3 % of 93 mm is 0.28 mm on its own. Likewise `flank_add = 2(√2−1)·tol` from desiccant-capsule is a **screw-thread** derivation (radial offset + axial widening) and does not transfer to a circumferentially-engaging lug. Start at 0.30 and let the coupon decide.

### 3.7 Versioning

`NUGGS_REV = 1`, embossed on every module's outer surface. Changing `bore_d`, `wall`, `port_len`, `n_lug`, `lug_deg`, `lug_h` or `lug_engage` invalidates every part already printed. Publish the port spec as a one-page table under the repo's licence — permissive, no NC clause, following Gridfinity's pattern (which, note, only went MIT in April 2023; its CC-BY-NC-SA precursor is exactly the fragmentation to avoid).

---

## 4. Bore and dimensions

**Nominal internal bore: 80.0 mm. Wall: 2.4 mm. Tube OD: 84.8 mm. Flange OD: 92.8 mm.**

**Bore justification chain**

- Hard floor **70 mm**, Deutscher Tierschutzbund, explicitly the pouch-full criterion (S1).
- Design target **80 mm**, German tube-specific guidance: *mindestens 8 cm für ausgewachsene Goldhamster* (S2).
- 80 mm clears the DTSchB floor by 10 mm (14 %) and clears it at *every* point in the system — the bulkhead throat is full-bore, so there is no worst point below nominal.
- Cross-section π×40² = **5026.5 mm²**. That is **1.96×** a Kaytee Fun-nel at its published 2.25 in nominal (2565.2 mm²) and **1.36×** the 68.5 mm free printable prior art (3685.0 mm²).
- 80 mm is also the bore the printability work actually measured: bore 80 / wall 3 / L 200 printed vertically scored **printcheck 100/100 with no findings and drew no PrusaSlicer warning** — reproduced independently by the fact-checker.

**Wall thickness justification**

Bending never governs. A 225 g animal mid-span on a 300 mm span gives σ ≈ 0.017 MPa. Even against the *pessimistic* Z-direction figure the same research cites (3.89 MPa, printed vertically the bending stress crosses the layer bond), the safety factor is ~240; deflection is < 0.001 mm. Reaching a 5 MPa design stress would need a multi-metre span. So wall is set by **gnaw margin, print quality and cost**, not by load. 2.4 mm = 6 perimeters at a 0.4 mm nozzle, comfortably over CLAUDE.md's 1.2 mm floor, and 20 % cheaper than 3.0 mm.

⚠️ Three different PLA strengths (50 / 25 / 3.89 MPa) were used across the source analysis, each chosen to make its own conclusion comfortable. Use **one** number in NOTES.md and say which.

**Module lengths and the TVT budget**

| Contribution | mm |
|---|---|
| bulkhead throat (spigot 25 + port 14) × 2 | 78 |
| straight (default) | 160 |
| **total enclosed** | **238** |
| **TVT limit (2 × 180 mm)** | **360** ✓ |

Maximum straight that still complies: 360 − 78 = **282 mm**. Maximum straight that fits the bed: **240 mm**. **The bed is stricter than TVT, so a single-straight run cannot violate the welfare limit by accident.** Two straights chained (320 + 78 = 398 mm) *would* — so `straight_len` defaults to 160, the README states "one straight per run," and the limit is embossed on the part. OpenSCAD cannot assert what a user assembles; this is a documented limitation, not a solved one.

**Bed-fit arithmetic, 256 × 256 × 256 mm (Bambu X1/P1 class)**

- Straight prints **vertically**, tube axis = Z. Footprint = flange OD² = 92.8 × 92.8 mm.
- Pitch with a 6 mm gap = 98.8 mm. `floor(256 / 98.8) = 2` per axis → **4 straights per plate**. (3 across would need 3×92.8 + 2×6 = 290.4 mm > 256.) Horizontal or clamshell orientations give 2 and 1 respectively.
- Height: 160 mm ≪ 256 mm, 96 mm headroom. Max `straight_len` = 240 mm (16 mm margin).
- Bulkhead flange OD 130 mm → 1 per axis, but both halves fit side by side (130 + 6 + 130 = 266 > 256 — so **one half per plate row**, two halves per plate diagonally, or simply 1 in + 1 out per plate).
- `printcheck.args`: `--build-volume 256x256x256`. The default 250×210×220 would flag the flange.

**First-layer contact and brim (printcheck is blind here — check it yourself)**

- Bare annulus contact = π × 2.4 × 82.4 = **621.2 mm²**, spread as a 2.4 mm-wide, 266 mm-long ring under a 160 mm-tall part.
- contact / bbox-footprint = 621.2 / 7191 = **8.6 %**, above printcheck's 5 % brim threshold → **no warning will fire.** The heuristic counts the ring's hollow centre as footprint. The `D_crit = 61.82 × wall = 148.4 mm` rule also never binds at OD 84.8. Neither tells you anything; do not let either argue the bore down or the wall thinner.
- Specify in Print settings: `brim_type = outer_and_inner`, `brim_width = 5`. Outer-only (PrusaSlicer's default, with `brim_width = 0`) leaves the bore side unanchored. Areas: outer ring π(47.4² − 42.4²) = 1410.5 mm²; inner ring π(40² − 35²) = 1178.1 mm²; total with bare = **3209.8 mm², 5.17× bare** vs 2031.7 mm² / 3.27× outer-only.
- `seam_position = Random`. ⚠️ **Not Rear** — Rear stacks the seam *more* than Aligned. Random is the one that helps.

**Filament and time (estimates — replace with the gate's real test-slice figures before the README ships)**

Straight, bore 80 / wall 2.4 / L 160: solid annulus π(42.4² − 40²) × 160 = **99 398 mm³ = 99.4 cm³**. × 1.27 g/cm³ (PETG) = 126.2 g; the reference measurement showed the slicer coming in ~5 % under solid-annulus theory (184.28 g vs 194.0 g), and flanges/lugs add ~12 % → **≈ 135 g, ≈ 8 h**. Complete Bin Bridge (2 bulkhead pairs + 1 straight + coupon) ≈ **390 g and 16–18 h across three plates.**

⚠️ `gate.sh` hardcodes `--filament-density 1.24` and labels it PLA. A PETG README table will disagree with the gate summary by ~2 % (1.27) to ~11 % (1.38). Note the discrepancy in NOTES.md rather than silently diverging. And lead the product page with the honest bill — every filament figure in the source research was ~5 % low and every time figure divided volume by a near-peak flow rate with no allowance for travel, acceleration or ~800 layer changes.

---

## 5. v1 module list (MVP)

One `.scad`, one `part` parameter. ⚠️ **This is not a stylistic choice.** `gate.sh` renders parts *exclusively* from `ci.parts` via `-D part="…"` against the entry file, plus `<name>-coupon.scad`. Sibling `<name>-<part>.scad` files are echo-checked by `check.sh` but **never produce an STL** — a kit split that way ships completely ungated while CI stays green.

`designs/nuggs/nuggs.scad`, `part = "assembled"` default, enum `[assembled, straight, bulkhead_in, bulkhead_out, coupon, cutaway]`.

| Part | ci.parts | Function | Approx. envelope | Est. |
|---|---|---|---|---|
| **Coupon** | *(auto)* | Two 25 mm port stubs, printed as a mated pair on one plate. Tunes `port_tol` before you commit 135 g to a straight. **Doubles as the go/no-go bore gauge** — measure its bore with calipers; if it is under 79.0 mm your printer is shrinking and the straights will too. | 93 × 190 × 30 | ~30 g, 40 min |
| **Straight** | `straight` | The entire enclosed run. Parametric `straight_len`, default 160 mm. | ⌀92.8 × 160 | ~135 g, 8 h |
| **Bulkhead In** | `bulkhead_in` | Inner flange + full-bore 80 mm spigot through an 89 mm wall hole + one genderless port facing into the enclosure. | ⌀130 × 48 | ~60 g, 2.5 h |
| **Bulkhead Out** | `bulkhead_out` | Outer flange + spigot counterbore + 6× M4 bolt circle + genderless port facing the run. **Doubles as the drill-marking template** — no extra part. | ⌀130 × 22 | ~50 g, 2 h |

**4 gated STLs** (3 in `ci.parts` + the auto-detected coupon). Builds the complete **Bin Bridge**: bin wall → bulkhead → straight → bulkhead → bin wall. Closed, real, useful on day one.

**What is deliberately absent, and why — say all of this on the product page**

- **No end cap.** A cap makes a dead end, which makes a closed volume, which is exactly the TVT condensation/ventilation objection *and* the reversal trap for a wide-bodied pouch-full animal (S7). Every port either goes to an enclosure or is not built.
- **No vent slots.** Because there is no closed volume: a ≤ 360 mm run open at both ends into two ventilated enclosures is a through-duct with 5027 mm² of open area at each end. Slots would only be needed for a part that encloses air — and by rule, none does. (This also removes the "solid floor arc" requirement and with it the indexing problem that broke the earlier connector proposals.) ⚠️ If a chamber ever ships, vents go in the **upper arc only** — never the floor, or urine runs out through them — with fully rounded slot ends and an edge break, since slot ends are the highest-stress gnaw-initiation sites.
- **No internal traction ribs.** The run is horizontal by rule (S8), so longitudinal traction is not load-bearing in v1. And the "0.8 mm rib at 40° flanks scores 100/100" spec **could not be reproduced** — the fact-checker's rebuild drew thin-wall warnings at 40°, 44° and 45°, and at a 2 mm pitch the grooves are 0.09 mm wide, which the slicer renders as a smooth wall with zero traction and a perfect score. Do not ship an unvalidated rib.
- **No adapter to any commercial system, in either direction** (S14).
- **No vertical riser, ever** (S8).
- **No clamshell / split tube.** It relocates the overhang *into the bore*, halves plate throughput, and its defining risk — the internal longitudinal seam — is structurally invisible to this repo's gate, since printcheck only ever sees one half.
- **No locking cuff, because the bayonet is already captive** against axial pull. (The earlier proposal designated the bulkhead joint "must never come apart" and then deferred the only part preventing that to the backlog — a real safety hole that a bayonet closes by construction.)

### Deferred backlog, ranked

| # | Module | Why here | Gate note |
|---|---|---|---|
| **B1** | **Elbow-45** | First thing everyone asks for. Prints standing on the bisector, support-free. | Must compute the **minimum inscribed circle through the bend** and assert ≥ 70 mm. This is the most likely place for an 80 mm design to secretly violate the floor. |
| **B2** | **Turnaround chamber** | Prerequisite for any branch: "no dead ends" means every branch terminus is a chamber the animal can turn around in — comfortably over the 170–180 mm body length. First part that encloses volume, so first part that needs upper-arc vents. | Exceeds 256 mm if built to 200 mm+ across; may need a two-part split. |
| **B3** | **Rim saddle** | No-drill entry that hooks over a bin/tank rim. The **only** route for glass enclosures (S16). Needs an internal ramp at ≤ 15°, which makes it a substantial module. | |
| **B4** | **Wye-45** | Branch. Needs B2 first (three termini ⇒ third enclosure or chamber). 45° so there is no head-on wall for an animal running at speed. | Total enclosed length across a branched system is much harder to keep under 360 mm — this may simply not be compliant. |
| **B5** | **Bulkhead variants** | Thick plywood/melamine (long M4s), and a thin-PP variant with a wider flange to spread clamp load. | |
| **B6** | **Elbow-90** | Worse ergonomics, harder print, tighter inscribed circle than B1. | |
| **B7** | **Factory-port blank** | Caps a commercial cage's stock ~55 mm port so the owner can cut a proper one. **Replaces** any notion of a reducer. | |
| **B8** | **Drainpipe adapter** | 3 in sch40 average ID is **77.3 mm** (not 77.9 — that is the min-wall arithmetic), UK 110 mm soil ID ~101 mm. Note 77.3 < our 80 mm bore, so a 3 in adapter *necks* the animal — still above the 70 mm floor, but it must be documented as a neck, not sold as an upgrade. Exclude 68 mm downpipe (ID ~64 mm) and all flexible ducting. | |
| **B9** | **Traction insert** | Only if an inclined module ever ships. Needs a real rib sweep coupon, not the unreproducible spec. | |
| — | **Never** | Any reducer to CritterTrail/Ferplast bore; any vertical riser; any dead-end cap; any run over 2× body length; any Detolf/tempered-glass drilling variant. | |

---

## 6. Parameter table

Customizer sections in repo house style; units and purpose on every line; `/* [Hidden] */` before derived values.

**`/* [What to render] */`**

| Name | Default | Unit | Purpose |
|---|---|---|---|
| `part` | `"assembled"` | — | `[assembled, straight, bulkhead_in, bulkhead_out, coupon, cutaway]` |
| `anim` | `"none"` | — | `[none, twist]` — `$t`-driven 60° lock/unlock for the GIF. Compute `$t`-dependent values **inside** a geometry block; top-level assignments evaluate before `-D '$t=…'` lands. |

**`/* [The NUGGS standard — change these and nothing you already printed fits] */`**

| Name | Default | Unit | Purpose |
|---|---|---|---|
| `NUGGS_REV` | `1` | — | Embossed on every module; bump only on a breaking port change |
| `bore_d` | `80.0` | mm | Internal bore. The headline number. Asserted `>= min_bore_mm` |
| `wall` | `2.4` | mm | Tube shell. Asserted `>= 3*nozzle` |
| `port_len` | `14.0` | mm | Axial length of the lug/flange zone at each end |
| `n_lug` | `3` | — | Lugs per face. 3 = kinematically determinate, 60° twist to lock |
| `lug_deg` | `55` | ° | Lug angular width. Asserted `<= 360/n_lug/2` (self-complementarity) |
| `lug_h` | `3.2` | mm | Lug stem height (axial stand-off from the face) |
| `lug_r` | `4.0` | mm | Radial stand-off of the lug pitch circle beyond the tube OD |
| `lug_engage` | `2.4` | mm | Head overhang in the locking direction. Sets pull-out capacity |
| `lug_ramp` | `50` | ° | Head-underside ramp from horizontal. Self-supporting **and** the wedge that eats tolerance. Asserted `>= 47` |
| `detent_h` | `0.40` | mm | Detent bump height. Sets twist-off torque |
| `bore_lead` | `1.0` | mm | Internal edge break at each port face |
| `bore_lead_ang` | `50` | ° | Its angle from horizontal |

**`/* [Fit & tolerances] */`**

| Name | Default | Unit | Purpose |
|---|---|---|---|
| `port_tol` | `0.30` | mm | **The one knob.** Uniform inflation of the lug solid when cutting the pocket. Tune on the coupon in ±0.05 steps. Asserted 0.10–0.60 |
| `bolt_clr` | `0.40` | mm | M4 clearance in the bulkhead flanges (feeds `screw_clearance_d()` from `lib/printability.scad`) |

**`/* [Straight] */`**

| Name | Default | Unit | Purpose |
|---|---|---|---|
| `straight_len` | `160` | mm | Face to face. Asserted `<= 240` (bed Z) and against the TVT budget below |

**`/* [Bulkhead] */`**

| Name | Default | Unit | Purpose |
|---|---|---|---|
| `wall_hole_d` | `89` | mm | Enclosure-wall hole. 89 mm is a stocked bi-metal size and passes the full-bore spigot with 2.5 mm radial clearance. **Not in a typical 13-piece starter set — this is a specific purchase** |
| `bh_spigot_wall` | `2.0` | mm | Spigot shell. Bore stays 80 mm through the wall — no neck anywhere |
| `bh_spigot_len` | `25` | mm | Spigot length; lands in the outer half's counterbore |
| `bh_flange_d` | `130` | mm | Clamp flange OD, both halves |
| `bh_wall_min` | `1.5` | mm | Thinnest enclosure wall supported (thin PP tote) |
| `bh_wall_max` | `20` | mm | Thickest (plywood/melamine). Screw length user-supplied |
| `bh_screw` | `"M4"` | — | Clamp fastener |
| `bh_screws_n` | `6` | — | Evenly spaced on the flange |

**`/* [Welfare limits — asserted, not tunable down] */`**

| Name | Default | Unit | Purpose |
|---|---|---|---|
| `min_bore_mm` | `70` | mm | DTSchB entrance minimum, pouch-full criterion. `assert(bore_d >= min_bore_mm)` |
| `body_len_mm` | `180` | mm | Merck head-and-body upper figure. **Measure your animal and change this.** |
| `max_incline_deg` | `15` | ° | `assert(max_incline_deg <= 15)`. On a 160 mm straight, max end-to-end height difference = 160·sin 15° = 41.4 mm |
| `max_drop_mm` | `150` | mm | No unbroken free-fall above this. 0 by construction in v1 |

TVT assert: `assert(straight_len + 2*(bh_spigot_len + port_len) <= 2*body_len_mm)` → 160 + 78 = 238 ≤ 360 ✓
Hole assert: `assert(wall_hole_d >= bore_d + 2*bh_spigot_wall + 1.0)` → 89 ≥ 85 ✓

**`/* [Print settings] */`**

| Name | Default | Unit | Purpose |
|---|---|---|---|
| `nozzle` | `0.4` | mm | Feeds the wall assert |
| `bottom_chamfer` | `0.8` | mm | Bed-contact edge break |
| `chamfer_ang` | `50` | ° | House angle for every chamfer/cone. **Not 45** |

**`/* [Quality] */`**

| Name | Default | Unit | Purpose |
|---|---|---|---|
| `$fa` | `4` | ° | Production (iterate at 12) |
| `$fs` | `0.6` | mm | Production (iterate at 2) |

**Stubbed now so the file grows cleanly:** `/* [Elbow — backlog] */ elbow_angle = 45; elbow_radius = 90; min_inscribed_mm = 70;` with the inscribed-circle assert already written even though no elbow ships in v1.

---

## 7. Print and material guidance

**Orientation, per part**

| Part | Orientation | Why |
|---|---|---|
| Straight | **Vertical, tube axis = Z** | The only orientation that scores printcheck 100/100 with no findings and draws **no** PrusaSlicer warning. Horizontal is 23 % overhang (2 points under the 25 % CRITICAL cutoff) and PrusaSlicer says *"Collapsing overhang, Low bed adhesion, Long bridging extrusions."* Vertical is also the **fastest** (12h15m vs 12h53m on the reference part) and gives 4 per plate vs 2. The theoretical objection — layer lines then run perpendicular to a hanging load — is real and irrelevant: even against the pessimistic 3.89 MPa Z figure the margin is ~240×. |
| Bulkhead in | Flange on the bed, spigot up | Large first-layer contact; only overhangs are the lug heads (ramped 50°) and the flange→spigot cone (50°) |
| Bulkhead out | Flange on the bed | Flat ring, trivial |
| Coupon | Both stubs axis = Z, side by side | Prints the joint in exactly the orientation the production parts use — otherwise the fit test is testing the wrong geometry |

**Supports: none, anywhere.** Every downward-facing surface in the kit is at ≥ 50° from horizontal by construction. If a support is ever needed, the geometry is wrong.

**Material: natural (uncoloured) PETG.**

- **Not PLA.** PLA Tg 57–70 °C overlaps the entire dishwasher band (50–75 °C wash, >70 °C heated dry). A deformed tube is a *narrowed* tube, so the material failure mode is the animal-injury failure mode. PLA also splinters, and ingested fragments cause GI obstruction.
- **PETG Tg is 80–85 °C** (corrected up from the "75–80 / 0–5 °C margin" figure). It survives a hand wash with ~31 °C to spare. It does **not** survive a heated dry cycle, which reaches 80 °C+. So: **hand wash only, and never claim dishwasher safe for either material.** The reason is the dry cycle, not the wash margin.
- **PP** is the only genuinely hot-wash-tolerant option (Tg −20 to +20 °C, melt 160–180 °C — HDT governs, not Tg) at the cost of being notoriously hard to print. State the tradeoff; do not hide it.
- **Colour is a safety decision.** Natural/uncoloured, or an explicitly food-contact-certified filament. Cheap pigments can carry lead, cadmium and chromium; red, orange and pink fail compliance most often; "FDA compliant" typically covers the base polymer only, not the masterbatch. A gnawing rodent abrades pigment straight into its mouth.

**Slicer settings to state in `## Print settings`:** 0.2 mm layers, 5 perimeters minimum (fills the 2.4 mm wall), 20 % infill, `brim_type = outer_and_inner`, `brim_width = 5`, `seam_position = Random`, **supports off**, no ironing on internal surfaces.

**Hygiene stance — state it honestly, both studies, no cherry-picking**

- **The "FDM layer lines are a bacterial trap" claim is refuted, including by the source usually cited for it.** The Hackaday write-up of the UVU study reports SEM showing typical 3D prints have **no detectable porosity**, that layer-line grooves are too large relative to bacteria to be relevant, and that ordinary dish soap and water removed 90 %+ of all pathogens tested. The frequently-cited "2017 study finding FDM retains more bacteria than injection-moulded controls" could not be located and appears not to exist.
- **The real, citable result** is Thomas et al. (IEEE): PLA/PLA+ and PETG parts can be cleaned to safe levels with **warm water at 120 °F (48.9 °C) and non-concentrated dish soap** — with the honest qualifier that this is a **~90 % (one-log) CFU/PFU reduction, not sterilisation.**
- 48.9 °C is 6 °C below PLA's Tg floor and ~31 °C below PETG's. Another reason for PETG.
- **Cleaning protocol:** spot-clean the run every few days; release the straight and hand-wash in warm (≤ 50 °C) water with unscented mild dish soap; rinse thoroughly; dry fully before reassembly. Per-segment removal exists so a soiled tube is washed **without disturbing the nest** — whole-enclosure deep cleaning is itself a welfare harm (RSPCA: deep clean only once or twice a month; NC3Rs: minimise frequency and transfer nesting material to preserve the scent map). No blind cavities anywhere, so nothing traps wash water.
- **Do not state a sourced "avoid bleach" rule** while citing a study whose own protocol includes a dilute bleach soak. If bleach is mentioned at all, cite the study's dilution and require a thorough rinse. Avoid ammonia-based cleaners and strong scented disinfectants (respiratory).
- **No sealant or coating.** Nothing was established as simultaneously food-contact safe, resistant to repeated dilute-vinegar immersion, and safe if gnawed off in flakes. Prefer smooth printing plus replaceability.

---

## 8. Risks and open questions

**Could fail the animal**

1. **The category itself is the risk.** PLOS One (EXOPET-II, German federal funding; 28 websites, 50 pet shops, 13 garden centres) rated tube systems **unsuitable as a product category**, alongside exercise balls, harnesses and hamster bedding — and 82.7 % of 208 cages and 86.1 % of 101 wheels welfare-adverse. TVT Merkblatt 62 says the same. **The default expert position is that this product should not exist.** The README must name each cited defect and show the specific feature that answers it; silence reads as negligence.
2. **The evidence base points at substrate, not tunnels.** Hauzenberger et al. 2006 is the strongest welfare finding in the set and it is about **depth** (10 cm → significantly more wire-gnawing; 40 and 80 cm → burrows). If this kit displaces bedding or floor area it is a net welfare loss. That is why it runs *between* enclosures and why "optional enrichment, not housing" is not a hedge — it is the honest positioning.
3. **The 70 mm floor can be violated invisibly at a bend.** v1 has no bends, which is partly why v1 has no bends. B1 needs an inscribed-circle assert before it ships.
4. **Chain two straights and you break the TVT limit** (398 mm vs 360 mm). The genderless port makes this physically possible and OpenSCAD cannot stop it. Emboss the rule, state it, keep the default single.
5. **Gnawing is low-probability, high-severity, and cannot be designed to zero.** The mitigation is removing initiation sites, not hoping. Provide better chew targets elsewhere in the enclosure.
6. **Escape and entrapment at the bulkhead.** The bayonet is captive against axial pull, but this is a joint an animal lives in — the coupon must be pull-tested by hand and the detent tuned, and the joint inspected at every clean.

**Could fail the printer**

7. **Elephant's foot is printer-specific and uncalibrated by default.** Every dimension landing on the first layer — lug heads on the bulkhead, the bore edge at each port face — is out of spec on an uncalibrated machine, and nothing in the pipeline can detect it. The 1.0 mm bore lead-in exists specifically to absorb this; the coupon exists to catch the rest.
8. **A 160 mm-tall part on a 2.4 mm-wide ring is a warping risk that no tool in this repo can see.** printcheck's 5 % brim heuristic passes it at 8.6 % because it counts the ring's hollow centre as footprint. Brim is a README instruction, not a gate outcome.
9. **The coupling absorbs per-part shrinkage that the repo's existing clearance values never had to.** 0.3 % of a 93 mm flange is 0.28 mm — nearly the whole `port_tol` budget on its own. Expect the first coupon to be wrong.

**Could fail the CI gate**

10. **`gate.sh` passes no `--fail-under`, so the score is advisory** and only a CRITICAL finding fails CI. Realistic connector shapes score 76–92 and pass. **Do not set `--fail-under 85`** — the repo's own reference design (`sushi-battleship-top`) scores 84 and would fail. If a floor is wanted, add `--fail-under 75` *after* v1's real scores are known.
11. **The first red CI run will almost certainly be docs, not geometry.** `check.sh` → `docs-check.sh` → `gallery.sh --check` exits 1 if `previews/contact-sheet.png` is missing, separately if `NOTES.md` is missing, and separately if the top-level README gallery is stale. None of the three is stated in CLAUDE.md's design conventions. `readme-gate.sh` runs on **every** push regardless of what changed.
12. **`printcheck.args` is design-scoped, not part-scoped.** `--build-volume 256x256x256` loosens the size check for the coupon too. There is no way to hold small parts to a tighter standard.
13. **Permanent CI tax.** Every future change to `lib/`, `scripts/`, `tools/printcheck/` or `ci.yml` re-gates every part (3 + coupon = 4 renders) plus geo-diff's base+head per `ci.parts` entry (6 more) = **10 renders per infra PR, forever.** Keeping `ci.parts` at 3 is the argument; CI wall-clock is not (no `timeout-minutes` anywhere, so 360 min default).
14. **Camera freeze.** Every `cameras.conf` / `animations.conf` / `shots.conf` line is fixed the moment a reviewer sees it, and every manifest entry is a permanent commitment to a committed binary plus a **literal** `](previews/name.ext)` embed — reference-style links and `<img>` tags do not satisfy `grep -qF`. Plan the shot names before the first review round.

**Questions only the owner can answer**

- **What is the hamster's name?** The acronym is built around "Nugget."
- **Measure the animal: head-and-body length.** `body_len_mm = 180` is Merck's upper figure and it sets the entire TVT length budget. Two minutes with a ruler replaces the weakest assumption in the plan.
- **Measure the animal: width across the shoulders, and head width with both pouches loaded.** ⚠️ **This is the gap nobody filled.** Not one source in five dossiers gives a Syrian's shoulder width, hip width, or loaded-pouch width — the only measurements that actually determine whether an animal fits. 80 mm is almost certainly generous, but "almost certainly generous" is not a derivation. The pelvis is the rigid, non-compressible section and no measured figure exists anywhere.
- **What are the two enclosures?** Two plastic bins (v1 works today), one bin + one tank, plywood/melamine (works, needs long M4s), or glass/Detolf (**v1 does not serve this — tempered glass shatters under a hole saw**; needs B3).
- **Measure the bin wall thickness with calipers.** Sterilite and Rubbermaid publish nothing; the 1.5 mm IKEA Samla figure is one hobbyist's measurement and IKEA publishes no value.
- **How deep is the bedding, in each bin?** This sets the hole height (bore floor at the bedding surface — with 25–30 cm substrate, hole centre ≈ 290–340 mm up the wall) and the level difference between the two, which must be ≤ 41.4 mm on a 160 mm straight.
- **PETG or PLA?** PETG is the welfare-correct answer. If the printer only runs PLA, the cleaning guidance and the "never a dishwasher" warning both get louder, and `port_tol` will differ.
- **Does the owner already own, or will they buy, an 89 mm bi-metal hole saw + arbor + pilot bit?** There is no way around a hole larger than the bore. If the answer is no, v1 is not buildable and that needs to be known before a session starts, not after.
- **Licence?** Decide before the first STL ships. Permissive, no NC clause, so third-party compatible parts are legally clean and the port spec can be quoted.

**Methods caveat to carry forward verbatim:** every external source in this plan was reached through WebSearch result summaries under an organisational egress block that returned 403 on CONNECT for effectively every research host. No page was read end to end. Before this becomes a published product page, the load-bearing figures — the DTSchB 7 cm entrance minimum, TVT Merkblatt 62's 2×-body-length limit and its exact wording, the PLOS One verdict, and the 20 mm full-pouch width — should be read in the primary text from an unrestricted network.

---

## 9. Acceptance criteria

**Scaffold**
- [ ] `designs/nuggs/nuggs.scad` exists as the **single entry file** with a top-level `part` parameter using the Customizer enum comment form. No `nuggs-<part>.scad` file is relied on for gating.
- [ ] `designs/nuggs/ci.parts` lists exactly `straight`, `bulkhead_in`, `bulkhead_out` — printable deliverables only, not `assembled`.
- [ ] `designs/nuggs/printcheck.args` contains `--build-volume 256x256x256` and nothing else. No `--fail-under` in v1. No inline comments (only full-line `#` is stripped; an inline comment breaks the gate).
- [ ] `designs/nuggs/nuggs-coupon.scad` is a **≤ 10-line** include-and-override wrapper on the production modules, overrides **above** any geometry statement, **no copied geometry**.
- [ ] `designs/nuggs/NOTES.md` exists, with a **"Print this first"** section naming `port_tol` as the knob, ±0.05 as the step, and the caliper bore check (≥ 79.0 mm) as the go/no-go.

**Safety asserts present and firing**
- [ ] `assert(bore_d >= min_bore_mm)` with a message naming the DTSchB 7 cm entrance minimum.
- [ ] `assert(straight_len + 2*(bh_spigot_len + port_len) <= 2*body_len_mm)` — TVT Merkblatt 62.
- [ ] `assert(lug_deg <= 360/n_lug/2)` — genderless self-complementarity.
- [ ] `assert(lug_ramp >= 47)`, `assert(wall >= 3*nozzle)`, `assert(straight_len <= 240)`, `assert(wall_hole_d >= bore_d + 2*bh_spigot_wall + 1.0)`, `assert(max_incline_deg <= 15)`.
- [ ] Each assert fails the render when violated — verified by deliberately breaking one and seeing a non-zero exit.

**Geometry**
- [ ] Minimum internal diameter measured on **every exported STL** — straight, both bulkhead halves, coupon — is ≥ 70 mm at the worst point. Recorded in NOTES.md with the method.
- [ ] Nothing protrudes into the bore anywhere. Verified on the `cutaway` render.
- [ ] Two coupon stubs, printed and mated, engage with a 60° twist, hold under a firm axial pull, and release one-handed. **The design is not done until this is physically printed and tested** — printcheck gates single STLs and can never see an assembled joint.

**Gate**
- [ ] `./scripts/render.sh nuggs` succeeds; `build/nuggs.png` contact sheet reviewed, **including the bottom-iso view**, for overhang and bed contact.
- [ ] `./scripts/gate.sh --slice nuggs` **exits 0** across all 4 STLs.
- [ ] **Read the WARNING lines, do not trust the exit code.** Record each part's score. Target ≥ 92 per part; the straight should be 100/100. Any part below 92 is investigated, not accepted. (The gate cannot fail on score, and `support_material = 0` means a collapsing part slices and exits 0 regardless.)
- [ ] No part reports a CRITICAL finding — the only nine ways to fail: non-watertight, inconsistent winding, inverted normals, empty mesh, **microscopic model (< 1.6 mm max extent)**, overhang ≥ 25 %, thin-wall ≥ 20 %, bed contact < 1.0 mm², or exceeding build volume at every rotation.
- [ ] `./scripts/check.sh` passes (syntax + lib geometry regression + docs drift).
- [ ] `./scripts/readme-gate.sh nuggs` passes.
- [ ] `/preflight` comes back green. That skill is the authoritative check set.

**Docs and previews**
- [ ] `designs/nuggs/README.md` from `templates/README.md`: H1 with text, a prose pitch line **before** the first `##`, non-empty `## Print settings` **and** `## Parameters`, and at least one **local** image that resolves.
- [ ] README leads with the **PLOS One / TVT position stated plainly**, followed by a defect-by-answer table (narrow bore / ventilation / condensation / cleanability / refuge / length), before any feature copy.
- [ ] README states, above the fold: the honest filament and time bill (**from the gate's real test-slice figures, not an estimate**), the 89 mm hole saw requirement, the bedding-height mounting rule with its arithmetic, "one straight per run," "hand wash only, never a dishwasher," and "do not attempt on glass."
- [ ] README states the **emergency opening action** in one sentence.
- [ ] `designs/nuggs/previews/contact-sheet.png` committed. **This is effectively mandatory** — `gallery.sh --check` exits 1 without it and `check.sh` runs it.
- [ ] `./scripts/gallery.sh` run so the top-level README table is not stale.
- [ ] `previews/cameras.conf` + `previews/CAMERAS.md`, with one camera line per region planned **before** the first review round, and a `src=nuggs-coupon.scad` line for the joint close-up. Treat every line as frozen once seen.
- [ ] `shots.conf` (bare hex colour, no leading `#`) + `./scripts/product-shot.sh nuggs`; the studio shot leads the README.
- [ ] `animations.conf` entry #1 is the money shot: **release, remove, reverse, reinsert** — the genderless port doing its job in four seconds. Every manifest entry has its committed binary, embedded as a **literal** `](previews/name.ext)`, inside budget (6 MiB GIF / 3 MiB PNG).

**Deliverable**
- [ ] Final STLs sent to the user.
- [ ] Committed as `Add design: nuggs`.

---

## 10. Sources

**Bore, anatomy and the injury mechanism**
- Deutscher Tierschutzbund, *Haltung von Goldhamstern* (7 cm entrance minimum, pouch-full criterion; 100×100×70 cm enclosure, ≥30 cm bedding) — https://www.tierschutzbund.de/fileadmin/Seiten/tierschutzbund.de/Downloads/Broschueren/Broschuere_Haltung_von_Goldhamstern.pdf
- hamsterwelten.de (7–8 cm tube ID; ≥8 cm for adult Syrians) — https://hamsterwelten.de/c/einrichtung/verstecke/roehren-tunnel · https://www.hamster-haltung.de/zubehoer/hamsterhaus/
- ScienceDirect, *Cheek Pouch* (4–8 mm empty, 20 mm full, 20×40 mm, extends to the scapulae) — https://www.sciencedirect.com/topics/veterinary-science-and-veterinary-medicine/cheek-pouch
- Merck Veterinary Manual, hamster physical characteristics (head-and-body 170–180 mm; 110–140 g; **females heavier than males**) — https://www.merckvetmanual.com/all-other-pets/hamsters/description-and-physical-characteristics-of-hamsters
- Hamsterhilfe Südwest (pouch-laceration mechanism; **and the true origin of the 6.5 cm figure**) — https://www.hamsterhilfe-suedwest.net/optimale-haltung-fuer-gold-und-teddyhamster/ · https://hamsterrettung-nord.jimdofree.com/ratgeber/eingangsgr%C3%B6%C3%9Fe-bei-verstecken/
- Tree of Life Exotics, cheek-pouch abscesses (debridement, flushing, marsupialization; USD 150–400 / 400–1000) — https://treeoflifeexotics.vet/education-resource-center/for-clients/pet-care-guides/small-rodents/cheek-pouch-abscesses-in-hamsters

**The case against the product category — engage these directly**
- PLOS One 2022, EXOPET-II: *tube systems rated unsuitable as a product category* — https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0262658 · https://pmc.ncbi.nlm.nih.gov/articles/PMC8809526/
- TVT Merkblatt 62, *Tierschutzwidriges Zubehör für Heimtiere* (Jan 2010, rev. April 2024) — ventilation, condensation, "no optical possibility of retreat," **and the ≤ 2× body length limit** — https://www.tierschutz-tvt.de/alle-merkblaetter-und-stellungnahmen/
- Hauzenberger, Mueller & Wechsler 2006, *Appl. Anim. Behav. Sci.* 100:280–294 — substrate depth 10/40/80 cm — https://www.sciencedirect.com/science/article/abs/pii/S016815910500393X

**Environment, cleaning and enclosure context**
- NC3Rs, housing and husbandry: hamster (20–24 °C, 45–65 % RH, TNZ 28–30 °C) — https://nc3rs.org.uk/3rs-resources/housing-and-husbandry-hamster
- RSPCA, hamster environment (spot clean every few days; deep clean 1–2×/month; transfer nesting material) — https://www.rspca.org.uk/adviceandwelfare/pets/rodents/hamsters/environment
- hamsterwelfare.com, cage advice and evidence (PDSA / Blue Cross 100×50×50 cm, ≥25 cm substrate) — https://www.hamsterwelfare.com/cage-advice-and-evidence/
- NIOSH, ammonia REL 25 ppm TWA / 35 ppm STEL — https://www.cdc.gov/niosh/chemicals/pel88/pell-pages/7664-41.html · Broderson et al., ammonia + respiratory mycoplasmosis in rats (25 ppm = LOAEL, lowest tested) — https://pmc.ncbi.nlm.nih.gov/articles/PMC2032551/

**Incline, falls and climbing**
- Furry Critter Network, small-mammal ladders and ramps (20–30° ideal; steeper increases fall risk and makes descent difficult) — https://www.furrycritter.com/pages/articles/small_mammals/ladders.htm
- choosehamstercages.com (tubes steeper than 20° are difficult; part-way falls) — https://choosehamstercages.com/hamster-exercise/hamster-tube-tips/
- Hamsters climb using claws and toes; the hazard is absent depth perception, not inability — https://petsintech.com/can-hamsters-climb/ · https://animals.mom.com/dont-hamsters-good-eyesight-1060.html

**Material, hygiene and colour**
- All3DP, PLA/PETG glass transition (PLA 57–70 °C, PETG 80–85 °C) — https://all3dp.com/2/pla-petg-glass-transition-temperature-3d-printing/
- 3Dprinterly, dishwasher and dry-cycle temperatures — https://3dprinterly.com/3d-printing-filament-dishwasher-microwave-safe/
- Thomas et al., *Study on the Sanitization Efficacy for Safe Use of 3D-Printed Parts* (IEEE): PLA/PLA+/PETG cleanable at 120 °F with dish soap — **~90 %, one log, not sterilisation** — https://ieeexplore.ieee.org/document/10152238/
- Hackaday / UVU: SEM shows no detectable porosity; layer-line grooves too large relative to bacteria to matter — https://hackaday.com/2022/09/05/food-safe-3d-printing-a-study/
- Pigment heavy metals; "FDA compliant" covers the base polymer only — https://3dspro.com/resources/blog/which-food-safe-3d-printing-filaments-are-truly-safe-for-food · https://filamentcheatsheet.com/blog/food-safe-filament-bambu-pure-pla-2026/

**Commercial systems and hardware (for the "we do not mate with this" statement)**
- Kaytee CritterTrail Fun-nel product pages: **2.25 in / 57.15 mm**, ID vs OD unstated; some Fun-nels sold as 2 in — https://www.kaytee.com/all-products/small-animal/crittertrail-fun-nel-tube-u-turn · https://www.amazon.com/Kaytee-Crittertrail-Loop-Accessory-Kit/dp/B000BL28S0
- Ferplast tube kit (6 cm) — https://www.ferplast.com/products/kit-tube-tunnel
- Bi-metal hole saw standard ladder (…76, 79, 83, **89**, 95, 102 mm) — https://www.icscuttingtools.com/catalog/page_336A.pdf · https://homerepairgeek.com/tips/hole-saw-size-chart/
- Bambu Lab X1/P1 build volume 256×256×256 mm — https://wiki.bambulab.com/en/knowledge-sharing/print-volume-limitations
- Tempered glass cannot be drilled — https://www.bulkreefsupply.com/content/post/how-to-drill-glass-aquarium · real Detolf failure: https://www.dendroboard.com/threads/56-gal-ikea-detolf-hack-paludarium.301290/

**Connector precedent**
- Storz coupling: sexless/hermaphroditic, **two lugs** (three is a variant), quarter turn (some designs 22°) — https://www.tubes-international.com/products/industrial-fittings/storz-couplings/ · https://shop.eriks.nl/en/storz-couplings/
- Gattermann et al. 2001, *J. Zool.* 254:359–365 — wild golden hamster burrows: single vertical entrance, depth 36–106 cm (mean 65), gallery mean 200 cm. **Cited as the argument *against* copying burrow geometry:** a soil burrow is snug, grippable on all sides and substrate-ventilated; an 80 mm smooth printed bore is none of those. — https://zslpublications.onlinelibrary.wiley.com/doi/abs/10.1017/S0952836901000851