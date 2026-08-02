# N.U.G.G.S.

A short, straight, 80 mm-bore tunnel that joins **two** hamster enclosures
through their walls, for an adult Syrian whose factory cage tubes are too
narrow for a pouch-full animal. Every joint is one genderless quarter-turn
port: both ends of every module are identical, so any module mates with any
other either way round — and the whole run comes apart in one twist with
the animal still inside it.

> **Work in progress — do not print yet.** The model renders and the port
> closes geometrically, but nothing here has been printed, the lock has not
> been verified on assembled copies, and the design has not yet passed
> `gate.sh --slice`. Bed adhesion in particular is an open problem. Track it
> in [issue #34](https://github.com/shaiss/print-bench/issues/34) and see
> `NOTES.md` for the open items.

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
| Endless tube mazes | Total enclosed length asserted at ≤ 2 × body length |
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
- **Brim:** required, `outer_and_inner`, 5 mm. Not optional: the part stands
  on a narrow ring and no automated check in this repo can see that risk.
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
| `port_tol` | 0.30 mm | **The one fit knob.** Tune on the coupon in ±0.05 steps |
| `wall` | 2.4 mm | Tube shell; 6 perimeters at a 0.4 mm nozzle |
| `wall_hole_d` | 89 mm | Enclosure-wall hole — a stocked hole-saw size |
| `twist_deg` | 40° | The locking twist |

All parameters are at the top of `nuggs.scad`, grouped in Customizer
sections; override on the command line with `-D 'straight_len=120'`.

## Assembly & use

Drill one 89 mm hole in each facing wall, at bedding height, level with
each other. Bolt a bulkhead pair into each hole with 6 × M4. Push the
straight onto one port, twist 40° to lock, then the same at the other end.

To open a run — for cleaning, or because an animal is in trouble — twist
one joint back 40° and lift the straight away. Do not pull the animal.
