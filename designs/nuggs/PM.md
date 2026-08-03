# nuggs — product charter

Enforced by `/pm nuggs`. Engineering log: `NOTES.md`. Product page:
`README.md`. Sourced research: [`docs/nuggs-research.md`](../../docs/nuggs-research.md).
Design request: #34.

## The product, in one paragraph

A short, straight, 80 mm-bore tunnel that joins **two** hamster enclosures
through their walls, for someone with a Bambu-class printer, a spool of
natural PETG, and an adult Syrian whose factory cage tubes are too narrow
for a pouch-full animal. The one thing it must do well is **be a bore an
adult Syrian can traverse safely and an owner can open in one action**.
It is not a tube *system*, it does not go inside the cage, and it competes
with a hole saw and a length of drainpipe — so if it is not safer,
cleanable, and openable, it has no reason to exist.

The customer is the **owner**, but the user is the **animal**, and the
animal cannot report a defect. That asymmetry is why the non-negotiables
below are asserts rather than guidance.

## Non-negotiables

May not be weakened to make engineering easier.

| # | Constraint | Number | Source | Reopens if |
|---|---|---|---|---|
| N1 | No passage narrower than the bore floor, anywhere — including the bulkhead throat and any future bend's inscribed circle | **70 mm** | Deutscher Tierschutzbund, pouch-full entrance minimum | A better-sourced figure for a *pouch-full* Syrian appears. Not for print convenience, ever. |
| N2 | Total enclosed tube ≤ 2 × body length | **360 mm** at `body_len_mm = 180` | TVT Merkblatt 62 | The owner measures a longer animal — the assert scales, the rule does not |
| N3 | No dead-air volume and no dead end; every run is a through-path open at both ends into a ventilated enclosure | 0 closed volumes | TVT (condensation, ventilation) | A branch terminus becomes a chamber the animal can turn around in |
| N4 | No vertical runs; maximum incline | **15°** | Fall risk — Syrians climb well but have almost no depth perception | Never for v1; a future ramp module with treads would need its own evidence |
| N5 | The entire enclosed length opens by hand, tool-free, in one action | 1 action | A wedged or pouch-impacted animal cannot reverse | Never. Glued or screwed assembly does not satisfy this |
| N6 | Nothing protrudes into the bore, and no chew-initiation geometry the animal can reach | — | Ingested fragments; claw and pouch snag | Never |
| N7 | Hand wash only, ≤ 50 °C; never a dishwasher | 50 °C | PLA Tg 57–70 °C, PETG 80–85 °C, dry cycle 70 °C+ | Never — a deformed tube is a *narrowed* tube, so the material failure mode is the injury failure mode |
| N8 | No interoperability with any commercial tube system, and no reducers in either direction | Kaytee 57.15 mm is 18.4 % under N1 | Adapting down imports the exact defect the product exists to fix | Never |
| N9 | Never drill tempered glass | — | Detolf and most tank panels shatter | A no-drill rim saddle (B3) serves glass instead |

**N1 and N5 are the product.** If the design cannot hold both, it should
not ship at all — that is a finding for the human, not a trade to make.

## Out of scope

**Never.** Any reducer to commercial bore. Any vertical riser. Any
dead-end cap. Any run over 2 × body length. Any tempered-glass drilling
variant. Any in-cage configuration — the enclosure minimum is 100 × 50 cm
and an in-cage L-run eats about a quarter of it, so a tunnel that consumes
floor or substrate is a net welfare loss (Hauzenberger et al. 2006 puts
substrate depth, not tunnels, at the centre of hamster welfare).

**Deferred.** Everything in the backlog below. The default answer to
"could we also…" is "yes, as a backlog item".

## v1 — definition of done

Gate-green is necessary and **not** sufficient. v1 is done when:

- [ ] `gate.sh --slice nuggs` exits 0 across all four parts *(met)*
- [ ] Every welfare assert fires when deliberately violated *(met)*
- [x] **Two identical ports mate, twist shut, and resist axial pull** —
      measured by `nuggs-matetest.scad`: 0 interference seated at the
      insertion and both locked clockings, 47.8 mm³ on pull-off when locked,
      28.1 mm² of bearing area *(met, round 2)*
- [ ] Minimum internal diameter ≥ 70 mm measured on every exported STL
- [ ] The coupon has been **physically printed** and the joint exercised
- [ ] README leads with the PLOS One / TVT position and the honest bill
- [ ] The emergency opening action is stated in one sentence

## Backlog, ranked by user value

| # | Item | Why this rank | Cost |
|---|---|---|---|
| ~~B0~~ | ~~Make the coupling work~~ | **Done, round 2.** Nests, twists both ways, retains at 28.1 mm² bearing area | — |
| ~~B1~~ | ~~Bed contact on the straight~~ | **Done, round 3.** lug_deg 30->40: contact 396->528 mm2, coverage 52->69%, printcheck warning cleared, joint unchanged | +4 g |
| **B1a** | **Print the coupon and tune `port_tol`** | Now top. The joint is proven in geometry, not in plastic. Until a printed pair twists at a sane torque, every fit number here is a guess — and it is also the only way to know whether bed contact is really solved | ~90 g, 7 h |
| B2 | Elbow-45 | First thing everyone asks for, and two of them make any turn 0–90° | Must assert the inscribed circle ≥ 70 mm (N1) |
| B3 | Rim saddle | The only route for glass enclosures (N9), and no-drill lowers the entry cost more than any other item | Needs an internal ramp ≤ 15° (N4) |
| B4 | Turnaround chamber | Prerequisite for any branch — N3 means every branch terminus must be turn-around-able | First part enclosing volume, so first needing vents |
| B5 | Wye-45 | Branch. Needs B4 first, and total enclosed length across a branched run may simply not satisfy N2 | May be non-compliant |
| B6 | Bulkhead variants (thick plywood, thin PP) | Widens the enclosures served | Small |
| B7 | Elbow-90 | Worse ergonomics and a tighter inscribed circle than B2 | |
| B8 | Factory-port blank | Caps a commercial cage's stock port so the owner can cut a proper one. **Replaces** any notion of a reducer (N8) | Small |
| B9 | Drainpipe adapter | 3 in sch40 ID is 77.3 mm — above N1 but below our 80 mm, so it *necks* the animal. Document as a neck, never sell as an upgrade | |

## Open decisions

| Question | Blocking? | Assumption if unanswered |
|---|---|---|
| Head-and-body length of the actual animal | **Blocks N2's real value** | `body_len_mm = 180` (Merck upper figure) |
| Shoulder width, hip width, head width with both pouches loaded | Not blocking, but it is the **only** unsourced input in the design — nobody publishes it | 80 mm is generous. This is an assumption, not a derivation |
| Which two enclosures, and their wall thickness (calipers) | Blocks the bulkhead's real dimensioning | Plastic bin, 1.5–20 mm range supported |
| Bedding depth in each, and the level difference | Blocks mounting height guidance | 25–30 cm substrate; ≤ 41.4 mm level difference on a 160 mm straight |
| Does the owner have an 89 mm hole saw? | **Blocks buildability** — no hole saw, no v1 | Assumed yes; it is a stocked size but not in a 13-piece set |
| PETG or PLA? | Not blocking; changes `port_tol` and how loud N7 gets | PETG |
| Licence | Blocks first STL release | Permissive, no NC clause |
| Is the hamster actually called Nugget? | Cosmetic | Fallback: *Nocturnal Underground Genderless Gallery Standard* |

## Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-08-02 | Short bridge between two enclosures, not a tube system | TVT's 2 × body-length limit makes a sprawling run non-compliant; PLOS One rates the category unsuitable, so the design answers each cited defect or omits the part |
| 2026-08-02 | Bore 80 mm, floor 70 mm as an assert | Commercial ~57 mm is 18.4 % under the floor; the animal cannot report a too-narrow bore, so it cannot be a tunable minimum |
| 2026-08-02 | Genderless coupling | One tolerance knob, one coupon, zero coupler parts — and it is what makes N5 (one-action opening) physically true |
| 2026-08-02 | No vent slots in v1 | N3 means nothing encloses air, so there is nothing to vent; this also removed the indexing problem that broke earlier connector proposals |
| 2026-08-02 | Ship the first round with the coupling documented as broken | A green gate plus an honest NOTES.md beats a design that looks finished; the three defects were measured, not suspected |
| 2026-08-02 | Rib is a narrow tab (`rib_deg = 12`), not the full sector width | The entry slot must admit the rib axially, so a full-width rib leaves nothing to twist under. This is what made round 1 retain nothing |
| 2026-08-02 | Circumferential run spans the full sector, so the joint locks in either twist direction | Handedness is a thing to get wrong for no benefit, especially one-handed during an emergency (N5) |
| 2026-08-03 | lug_deg 30 -> 40 to fix bed contact, not the coupling | The part stands on its sector tips, so sector width IS first-layer area. 16 degrees were sitting unused under the asserted ceiling. Mate test identical at 30/40/44, so the joint is unaffected |
| 2026-08-03 | 40 not 44, though 44 anchors more | 44 leaves 2 deg of headroom on lug_deg + twist_deg <= pitch/2; 40 leaves 6, so twist_deg can grow to 20 if the printed coupon says the twist is too short. The unmeasured fit gets the margin |
| 2026-08-03 | No sacrificial first-layer tie ring yet | It would make one continuous ring, but a part that must be removed is an N6 chew-edge risk if forgotten. Not worth that trade before a real print says the six islands are insufficient |
| 2026-08-02 | Every sector is one swept polygon, never a union of two arcs | Two arcs sharing an exact radius leave a coincident cylindrical surface and CGAL returns a non-watertight mesh |
