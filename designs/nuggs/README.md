# N.U.G.G.S.

A short, straight, 80 mm-bore tunnel that joins **two** hamster enclosures
through their walls, for an adult Syrian whose factory cage tubes are too
narrow for a pouch-full animal. Every joint is one genderless quarter-turn
port: both ends of every module are identical, so any module mates with any
other either way round — and the whole run comes apart in one twist with
the animal still inside it.

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
PLOS One 2022 (EXOPET-II) rated them unsuitable as a product category, and
the German veterinary welfare association's Merkblatt 62 gives the reasons:
they cannot be ventilated, they condense, they cannot be cleaned, and clear
tube denies a prey animal any refuge.

This design exists to answer each of those individually, or to omit the
part. That is why it is short, opaque, open at both ends, and lives
*between* enclosures rather than inside one.

| Documented defect | What this does about it |
|---|---|
| Bore too narrow for a pouch-full adult | 80 mm, full-bore through the wall crossing; 70 mm floor as a hard `assert` |
| Cannot be ventilated / condenses | No closed volumes. Every run is open at both ends into a ventilated enclosure — no caps, no blind branches |
| Cannot be cleaned | One twist releases any module for a hand wash, without disturbing the nest |
| Transparent tube gives no refuge | Opaque, uncoloured filament; you inspect it by it being short and straight |
| Endless tube mazes | Total enclosed length asserted at ≤ 2 × body length, and **one straight per run** — engraved on the part, see [Assembly & use](#assembly--use) |
| Eats cage floor and substrate | Runs between enclosures at bedding height — zero floor area, zero substrate |

**Measure your hamster.** `body_len_mm` defaults to 180 mm and sets the
whole length budget. And `min_bore_mm = 70` is not a suggestion: an
undersized opening lets grit in a full pouch lacerate the mucosa, which
leads to impaction and abscess with no visible symptom until surgery.

## What you get

- `straight` — the entire enclosed run, ⌀96.8 × 180 mm at defaults
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
- **Orientation:** tube axis vertical
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
| `body_len_mm` | 180 mm | Your animal's head-and-body length; sets the TVT length budget |
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
> This is the one rule the model cannot enforce for you. The total enclosed
> tube must stay within **2 × your animal's head-and-body length** (TVT
> Merkblatt 62). One straight plus both bulkhead throats is 160 + 2×(25+10)
> = **230 mm**, inside the 360 mm budget at `body_len_mm = 180`. Two
> straights coupled together is **420 mm** and breaks it — and because
> every NUGGS face mates with every other, two straights *will* click
> together and feel right. `assert` runs at render time and cannot see what
> you assemble on the bench, so the rule is engraved on the outside of every
> straight instead: **NUGGS R1 / ONE STRAIGHT PER RUN**.
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
years later:

| Part | Mark | Where |
|---|---|---|
| `straight` | `NUGGS R1` + `ONE STRAIGHT PER RUN` | outer tube wall, mid-length — in the room, between the enclosures |
| `bulkhead_out` | `NUGGS R1` | flange rim, outside the enclosure wall |
| `bulkhead_in` | *(none, deliberately)* | every face it has is either inside the enclosure or buried in the wall hole |

The marks are **engraved, never raised** — a proud character is a
chew-initiation edge. Set `mark_h = 0` to omit them.
