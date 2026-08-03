# aerochord — product charter

## The product, in one paragraph

aerochord is a novelty print-in-place wind instrument that sounds a fixed chord
from a single breath. The customer is a **maker/musician who wants an object
that can't be bought and is obviously computer-designed** — a conversation piece
that also actually plays. The one thing it must do well: **print as a single
supportless piece whose internal air path is intact**, so that after a short
tuning pass it makes the chord. It is a curio and a pipeline stress test, not a
concert instrument.

## Non-negotiables

| # | Constraint | Number | Source | Reopens if |
|---|---|---|---|---|
| N1 | Prints in place, one piece, no supports | 0 support material | Brief ("prints in place"); `printcheck` overhang < 25 % (no CRITICAL) | Someone proves a two-piece or supported version is still "print in place" — it isn't |
| N2 | Flue slot printable on a 0.2/0.4 mm nozzle | `flue_h ≥ 0.8` mm | 2× layer/extrusion floor; `assert` in `.scad` | A finer nozzle is made the target |
| N3 | Walls ≥ 3 perimeters | `wall ≥ 1.2` mm | Repo design convention; `assert` in `.scad` | Never — thinner walls buzz and leak |
| N4 | Labium prints as a real edge, not a knife | `labium_land ≥ 0.3` mm | ~1 nozzle width; `assert` in `.scad` | Never |
| N5 | Watertight, sliceable mesh | `printcheck` watertight = True; test-slice exits 0 | Repo gate (`gate.sh --slice`) | Never |

## Out of scope

**Deferred** — good ideas, ranked in the backlog:

- Finger holes / pitch bending per voice.
- A minor/7th/sus preset gallery beyond the documented `chord_ratios` override.
- Airflow-balanced windways (per-voice flue area tuned so voices speak evenly).

**Never:**

- **Guaranteed absolute pitch from the model alone.** Acoustics can't be
  verified from geometry here; the honest deliverable is a *tunable* nominal
  pitch (`tune` + coupon), not a factory-tuned note. Re-litigating this wastes
  every session.
- **Supports or multi-part assembly** to make a "better" sound. That breaks N1,
  which is the whole point.
- **A concert-grade voice.** This is a curio; chasing recorder-quality tone is
  out of scope.

## v1 — definition of done

- [x] Prints in place, one piece, no supports (N1) — `printcheck` 84/100, 3 % overhang.
- [x] Watertight + test-slices (N5) — `gate.sh --slice` exits 0.
- [x] Fipple air path verified continuous in the cutaway render (plenum → windway → flue → window → labium → bore).
- [x] Coupon ships and gates (the one-voice "print this first").
- [x] Product page explains the mechanism *and* discloses the acoustic caveat.
- [ ] **Physical print + tuning pass** (owner: whoever prints it) — the one
      thing the gate can't do; `tune`/`flue_h`/`cutup` calibrated on the coupon.

## Backlog, ranked by user value

| # | Item | Why this rank | Cost |
|---|---|---|---|
| B1 | Physical calibration + a `tune` default that lands closer | It's the gap between "prints" and "plays" — the user's first real friction | 1 coupon print (~1 h) |
| B2 | Preset chords documented as copy-paste `-D` lines | Most users want a different chord, not new geometry | docs only |
| B3 | Per-voice airflow balance | If one voice dominates in practice, this is the fix | design + reprint |
| B4 | Optional finger hole on the tallest voice | Turns a fixed chord into a 2-chord toy | design + reprint |

## Open decisions

| Question | Blocking? | Assumption if unanswered |
|---|---|---|
| Does the default C6 triad speak evenly from one plenum? | No | Assume it needs minor `cutup`/`tune` tweaks; documented as expected |
| Is ~106 mm tall too tall for the target user's bed/taste? | No | Assume acceptable with a brim; higher `root_freq` shortens it |

## Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-08-03 | Ship as a tunable curio, not a factory-tuned instrument | Acoustics unverifiable from geometry; honesty beats a false pitch claim (N-Never) |
| 2026-08-03 | Default 3-voice just major triad, root C6 | Clear, bright, printable size; everything else is one `chord_ratios` override |
| 2026-08-03 | Encode N2–N4 as `assert`s in the `.scad` | A weakened printability floor should fail the render, not wait for review |
