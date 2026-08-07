# N.U.G.G.S.

> [!NOTE]
> **Archived at v0.1 (2026-08-07) — frozen, not actively maintained.** This
> design is retired from active CI to save render cycles. To improve it, fork
> the repo, update it against current CI, and contribute it back as a
> derivative per the repo's [lineage tracking](../../docs/derivative-designs.md)
> (see also [CLAUDE.md](../../CLAUDE.md) → "Archived designs"). It was frozen
> **before it was ever printed or physically validated** (see the work-in-progress
> note below), so its geometry is unproven — a revival should start there.

An 80 mm-bore tunnel **system** for an adult Syrian hamster whose factory
cage tubes are too narrow for a pouch-full animal. The system is really one
thing: a **genderless quarter-turn port**. Every module carries the same
port at every end, so any module mates with any other either way round, and
the whole run comes apart in one twist with the animal still inside it.
Today the kit that exists is the **Bin Bridge** — two bulkheads and one
straight, joining two enclosures through their walls. Everything else
(elbow, node, open module, wye) is backlog, not product.

> **Work in progress — nothing here has been printed yet.** The design
> passes `gate.sh --slice`, and the coupling is verified in geometry: two
> identical ports nest, twist either way, and resist axial pull. What no
> one has checked is how it behaves in plastic — `port_tol = 0.30` is a
> starting guess, so **print the coupon first** and expect to tune it.
> Track progress in [issue #34](https://github.com/shaiss/print-bench/issues/34);
> `NOTES.md` has the open items and `PM.md` the ranked backlog.

![4-view contact sheet](previews/contact-sheet.png)

## Read this before anything else

The expert consensus is that hamster tube systems **should not exist**.
PLOS One 2022 rated them unsuitable as a product category, and the German
veterinary welfare association's Merkblatt 62 gives reasons: they cannot be
ventilated, they condense, they cannot be cleaned, and clear tube denies a
prey animal any refuge.

This design exists to answer each of those individually, or to omit the
part. That is why it is short, opaque, open at both ends, and lives
*between* enclosures rather than inside one.

**And here is the limit of that claim, stated plainly:** we could not
retrieve *why* PLOS One rated tube systems unsuitable — only that it did.
So the table below answers the defects **we** enumerated. It is not a
demonstration that this design escapes that paper's verdict. If you are
deciding whether to print this, that gap is yours to weigh, and it is the
honest reason the page leads with the objection instead of burying it.

| Documented defect | What this does about it |
|---|---|
| Bore too narrow for a pouch-full adult | 80 mm, full-bore through the wall crossing; 70 mm floor as a hard `assert` |
| Cannot be ventilated / condenses | No closed volumes. Every run is open at both ends into a ventilated enclosure — no caps, no blind branches |
| Cannot be cleaned | One twist releases any module for a hand wash, without disturbing the nest |
| Transparent tube gives no refuge | Opaque, uncoloured filament; you inspect it by it being short and straight |
| Endless tube mazes | **No single *run* of enclosed bore exceeds 2 × your animal's body length** — 360 mm at the default. A run ends at an open end, an open module, or a chamber he can turn around in. **A bend, a junction, a coupling and a top hatch are not ends** (see [The length rule](#the-length-rule-and-how-far-to-trust-it)). The Bin Bridge is one 246 mm run, and the limit is engraved on the part (`MAX RUN 360MM` / `COUPLINGS DONT RESET`) |
| Eats cage floor and substrate | Runs between enclosures at bedding height — zero floor area, zero substrate |

**Measure your hamster.** `body_len_mm` defaults to 180 mm and sets the
budget for each enclosed **run** (not for the system as a whole — see
[The length rule](#the-length-rule-and-how-far-to-trust-it)).

And `min_bore_mm = 70` is not a suggestion. The reason usually given is
that an undersized opening lets grit in a full pouch lacerate the mucosa,
leading to impaction and abscess with no visible symptom until surgery —
and that mechanism is **reported rather than verified**: it comes from
secondary rescue and veterinary pages, and nobody on this project has read
the primary literature. Treat it as the reason the floor is conservative,
not as a diagnosis.

The floor stays regardless, and the argument for it does not depend on that
mechanism being exactly right: the animal cannot report a bore that is too
narrow, being generous costs a few grams of filament, and being wrong costs
surgery. That asymmetry is why it is an `assert` and not a preference.

## The length rule, and how far to trust it

The one rule you have to hold in your head when you lay out a run. It is
also the rule this project got wrong twice, so it comes with its receipts.

**The rule.** No **run** of continuously enclosed bore may exceed
**2 × body length** (360 mm at `body_len_mm = 180`). A *run* is the
unbroken stretch of enclosed bore between two **breaks**, and there are
exactly three breaks:

- an **open end** — a port discharging into a ventilated enclosure;
- an **open module** — a bore with a longitudinal window of at least 180°,
  so the opening is the widest part of the void and the animal lifts
  straight out;
- a **turnaround node** — a chamber at least one body length clear inside
  **and itself open to ventilated space** (an open top, a ≥ 180° window, or
  a port into an enclosure). Width alone is not enough: width answers *can
  he turn around*, and it says nothing about *can the air move*. A sealed
  wide chamber is a dead volume in the middle of a run, which is one of the
  defects this whole design exists to answer.

**What is not a break, and this matters more than the number:**

| Not a break | Why |
|---|---|
| A bend | He cannot rotate in an 80 mm bore. A 45° elbow turns the *tube*, not the *animal* — he still has to reverse the whole way back |
| A junction at bore diameter | A wye at 80 mm is a *branching* one-way bore. It multiplies the ways to be trapped, it does not reduce them |
| A coupling | It is a joint. Two straights coupled are **one 406 mm run**, which is over the limit |
| A top hatch | It resets **retrieval** — you can reach him. It does not reset **reversing** — he still cannot turn around. Two different problems, two different fixes |

**Why 360 and not some other number.** Because he cannot turn around, he
leaves by whichever end is nearer — so the worst case is **half the run**.
A 360 mm run bounds worst-case unassisted reversing at 180 mm: one body
length. **That reasoning is ours, not a published finding.** No literature
measures how far a hamster will reverse, or the width he needs to fold in.

**Where the 2× comes from, corrected.** It is the **Deutscher
Tierschutzbund** position paper *Tierschutzwidriges Zubehör* — **not** TVT
Merkblatt 62, which this project cited for two rounds and which appears
never to have published a length limit at all (its objections are
qualitative). In the source it is one limb of a *conjunctive* test: tubes
are acceptable only if they are at most twice body length **and** ensure
adequate ventilation. Both limbs, or neither.

**How much to trust it.** Every source here was reached through search-result
summaries under an egress block; **nobody on this project has read the
primary text.** Specifically:

- *Probably right:* the rule is DTSchB's, not TVT's, and it is conjunctive.
- *Least certain, and it is the load-bearing part:* that the limit applies
  **per tube** rather than to a whole system. That reading is inferred from
  plural German in a search summary. If it turns out to be per-system, this
  page's rule is too permissive and the "one straight per run" line becomes
  "one straight, full stop."
- *Two figures that cut the other way, both real:* German pet-care sites
  circulate a **stricter** 25–30 cm maximum; and wild Syrians work burrow
  galleries averaging **200 cm** and reaching 900 cm, at tunnel diameters
  of only 40–50 mm (Gattermann et al. 2001) — which is why the 2× figure
  cannot be read as a biological tolerance. A soil burrow is grippable on
  all sides, self-ventilating, dug to fit that animal, and escapable by
  digging. Printed PETG is none of those, which is why we keep the limit
  anyway.

The full working, with the confidence ladder, is in
[`docs/nuggs-research.md`](../../docs/nuggs-research.md) §11.

## What you get

- `straight` — the enclosed run, ⌀96.8 × 180 mm at defaults
- `bulkhead_in` — inner flange + full-bore spigot through an 89 mm wall hole
- `bulkhead_out` — outer flange + bolt circle; doubles as the drill template
- `nuggs-coupon` — two port stubs; print this first to tune the fit

A complete Bin Bridge is two bulkhead pairs and one straight.

## Print settings

- **Material:** natural (uncoloured) PETG. **Not PLA** — its glass
  transition (57–70 °C) overlaps dishwasher temperatures, and a deformed
  tube is a *narrowed* tube.
- **Layer height:** 0.2 mm
- **Perimeters:** 5 (fills the 2.4 mm wall)
- **Infill:** 20 %
- **Supports:** none needed — every downward-facing surface is ≥ 50°
- **Orientation:** tube axis vertical. This is not a preference: horizontal
  puts unsupported bore crown *inside* the tube the animal walks through,
  and it is also what caps any future bend at 45° per module
- **Brim:** required, `outer_and_inner`, 5 mm. Not optional, and worth
  understanding: the straight has no flat base — it stands on the six port
  sector tips, 528 mm² across 69% of the circumference, holding up a 180 mm
  tall part for ten hours. A brim roughly triples the anchored area, but it
  does **not** bridge the gaps between the tips (each is ~17 mm of arc, and
  a 5 mm brim reaches 5 mm). Use it anyway; also print on a clean, degreased
  plate, and do not run a draughty room.
- **You will also need:** an 89 mm bi-metal hole saw. It is a stocked size
  but *not* in a typical 13-piece set, and there is no way around a hole
  larger than the bore.

**Never drill tempered glass** — Detolfs and most tank panels shatter under
a hole saw. This design does not serve glass enclosures.

**Cleaning:** hand wash only, ≤ 50 °C, unscented mild dish soap, rinse and
dry fully. Never a dishwasher — the heated dry cycle exceeds even PETG.

## Parameters

| Parameter | Default | What it does |
|---|---|---|
| `bore_d` | 80 mm | Internal bore. The headline number; asserted ≥ `min_bore_mm` |
| `min_bore_mm` | 70 mm | Welfare floor (DTSchB pouch-full entrance minimum). Never lower it |
| `body_len_mm` | 180 mm | Your animal's head-and-body length; sets the enclosed-**run** budget (2 ×) |
| `straight_len` | 160 mm | Face-to-face run length |
| `port_tol` | 0.30 mm | **The one fit knob.** A real clearance in millimetres on every coupling surface — radial, axial *and* circumferential — whatever bore you set. Tune on the coupon in ±0.05 steps |
| `wall` | 2.4 mm | Tube shell; 6 perimeters at a 0.4 mm nozzle |
| `lug_deg` | 40° | Coupling sector width. Also sets first-layer area, since the part stands on these tips — raise it toward 46 for more bed grip, never past `pitch/2 − twist_deg` |
| `wall_hole_d` | 89 mm | Enclosure-wall hole — a stocked hole-saw size |
| `twist_deg` | 14° | The locking twist. Bounded by `rib_deg + twist_deg ≤ lug_deg` |
| `mark_h` | 5 mm | Cap height of the engraved revision mark. 0 leaves parts unmarked |

All parameters are at the top of `nuggs.scad`, grouped in Customizer
sections; override on the command line with `-D 'straight_len=120'`.

## Assembly & use

> ### One straight per run. Never chain two.
>
> This is the one rule the model cannot enforce for you. A **run** — the
> continuously enclosed bore between two breaks — must stay within
> **2 × your animal's head-and-body length**. One straight plus both
> bulkhead throats is 160 + 2×(4+4+25+10) = **246 mm**, inside the 360 mm
> budget at `body_len_mm = 180`. (The two 4 mm figures are the bulkhead
> flange plates. They are bored at full bore, so they are tube the animal
> walks through, not mounting hardware outside the run — omitting them is
> what made this read 230 mm until PR #78.) Two straights coupled together
> is **406 mm** and breaks it, because **a coupling is not a break** — the two
> tubes are one run. And because every NUGGS face mates with every other,
> two straights *will* click together and feel right. `assert` runs at
> render time and cannot see what you assemble on the bench, so the rule is
> engraved on the outside of every straight instead: the port revision
> (`NUGGS PORT R1`) plus **`MAX RUN 360MM`** and **`COUPLINGS DONT RESET`**.
> Both engraved lines are derived from `body_len_mm`, so they cannot
> disagree with the assert.
>
> If you need a longer bridge, move the enclosures closer or raise
> `body_len_mm` to your *measured* animal — never add a second straight.

Drill one 89 mm hole in each facing wall, at bedding height, level with
each other. Bolt a bulkhead pair into each hole with 6 × M4. Push the
straight onto one port, twist 14° to lock — either direction works, the
coupling is symmetric — then the same at the other end.

To open a run — for cleaning, or because an animal is in trouble — twist
one joint back 14° and lift the straight away. Do not pull the animal.

### Markings

Every part that has a face the animal can never reach carries its port
revision engraved on it, so you can tell what a printed part conforms to
years later — which is the point of there being one port standard rather
than several:

| Part | Mark | Where |
|---|---|---|
| `straight` | `NUGGS PORT R1` + `MAX RUN 360MM` + `COUPLINGS DONT RESET` | outer tube wall, mid-length — in the room, between the enclosures |
| `bulkhead_out` | port revision | flange rim, outside the enclosure wall |
| `bulkhead_in` | *(none, deliberately)* | every face it has is either inside the enclosure or buried in the wall hole |

The marks are **engraved, never raised** — a proud character is a
chew-initiation edge. Set `mark_h = 0` to omit them.
