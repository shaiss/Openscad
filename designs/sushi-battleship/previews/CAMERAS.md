# Preview shots — fixed cameras

The camera numbers live in [`cameras.conf`](cameras.conf) (format documented
in `scripts/render.sh`); regenerate every shot with:

```bash
./scripts/render.sh sushi-battleship --previews
```

Cameras are FIXED across review rounds so before/after comparisons align;
if a new region needs a shot, add a new `cameras.conf` line rather than
moving an existing one. The migration from hand-run commands to
`cameras.conf` (2026-08-02) was verified byte-identical per shot before
landing.

Animated shots (the GIFs) live in `../animations.conf`, rendered by
`./scripts/animate.sh sushi-battleship`; the same fixed-camera policy
applies there.

## What each shot shows

- **contact-sheet.png** — 4-view overview (iso / top / front / bottom-iso),
  same sheet `./scripts/render.sh sushi-battleship` produces.
- **assembly.png** — assembled board, shutter D1 slid open and lifted
  (`demo_open`), preview sushi piece visible. Explicit camera (no
  auto-framing) so this shot stays aligned across rounds like the rest.
- **shutter-closeup.png** — lid only, D1 slid fully open at plate level:
  tabs aligned with the lip gaps, membrane visible through the revealed
  window slice.
- **coupon.png** — the 1×1 test coupon (full production lid at
  `grid_x = grid_y = 1`): one complete door with rails, lips, ridges,
  membrane and chamfers. Renders the coupon wrapper
  (`src=sushi-battleship-coupon.scad`), not the entry `.scad`.
- **cutaway.png** — X-Z section through the middle tab of cell B1 (row 1):
  gap_z air gap under the door, tab/lip stack, membrane at bed level,
  side-edge chamfers.
- **slide-section.png** — Y-Z section through the centre of column B,
  framed on the row-1/row-2 boundary: rear 1.6 mm vs front 0.8 mm window
  chamfers, end-stop ridge with its 0.5 mm gap to the door face, grip bar
  profile (re-framed once on reviewer request before the camera freeze,
  2026-08-01).
- **ridge-closeup.png** — view onto the row-1/row-2 boundary of column B
  with both neighbouring doors in frame for scale: door B1's rear edge
  (bottom, arrow visible), the end-stop ridge, the 0.5 mm ridge_gap
  channel, and door B2's leading edge and grip (top). Re-framed once on
  reviewer request before the camera freeze, 2026-08-01.
