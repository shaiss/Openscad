# sushi-battleship

## Previews

![4-view contact sheet](previews/contact-sheet.png)

| Assembled (D1 opened) | Section through a shutter's middle tab |
|---|---|
| ![Assembly](previews/assembly.png) | ![Cutaway](previews/cutaway.png) |

![Shutter close-up](previews/shutter-closeup.png)

Close-up: shutter D1 slid fully open (7 mm) — its side tabs now sit in
the gaps between the castellated rail lips, ready to lift straight out;
the strip visible through the revealed slice of window is the
sacrificial membrane. The cutaway faces a cut plane through a shutter's
middle tab: door plate floating 0.4 mm above the lid plate, tabs under
the 45°-chamfered lips (0.4 mm vertical / 0.5 mm horizontal clearance),
membrane down at bed level.

## Goal

Battleship played with real sushi. Two printed parts:

- **bottom** — a tray with a 4×4 grid of cells (one cut roll piece per cell),
  low dividers to keep pieces in place, tall raised outer walls, and a
  rebated rim the lid drops into. Cell coordinates are engraved in each
  cell floor so ships can be placed by call-out.
- **top** — a lid with one **print-in-place sliding shutter per cell**
  (A1–D4). On a "hit" you slide the shutter ~7 mm toward the high row
  numbers until it stops, then lift it straight out to reveal (and eat)
  the piece below. Closed shutters are locked and cannot be lifted.

## Given / assumed measurements

- Common cut roll piece (California-style futomaki): ~40 mm Ø × ~30 mm tall
  → `roll_d = 40`, `roll_h = 30`. Lid window is `roll_d + 6 = 46 mm`,
  cell pitch 58 mm, tray cell interior 56.4 mm (pitch − 1.6 mm divider) —
  comfortable buffer around a piece.
- Default 4×4 grid → lid 250 × 250 mm, tray 253.9 × 253.9 × 44.4 mm.
  Fits a 256 mm bed (Bambu X1/P1, Prusa CORE One). For a 220 mm bed use
  `grid_x = grid_y = 3` (lid 192 × 192 mm); reducing `roll_d` alone is not
  enough (`roll_d = 34` still yields a 226 mm lid on 4×4, and the shutter
  tab spacing stops working below `roll_d ≈ 36` — an assert catches this).
  Any grid size works; suggested "fleet" for 4×4:
  one 3-piece roll, two 2-piece rolls, two single nigiri.

## Key decisions

- **Shutter mechanism**: bayonet slide-and-lift, not a full-travel slider.
  A shutter that slides fully open needs parking space equal to its own
  window, which would roughly double the board depth per row (a 4×4 board
  would exceed 400 mm). Instead each door carries 3 tabs per side that sit
  under castellated rail lips; sliding the door 7 mm lines the tabs up with
  the gaps between lips, and the door lifts out. Opening a cell = slide +
  lift, and the removed tile doubles as a hit marker. Doors drop back in at
  the open position and slide forward to re-lock.
- **Lift lock**: lips have 45° chamfered undersides (self-supporting, no
  drooping overhangs); tabs engage them with 2.7 mm of horizontal overlap
  and 0.4 mm vertical clearance.
- **End stops**: 1.4 mm ridges on every row boundary stop each door at
  full-open (so it doesn't hit the next row's door) and stop the next row's
  door from over-travelling forward past closed.
- **Print-in-place strategy for the top**: doors print closed, 0.4 mm above
  the plate. Each window keeps a 0.3 mm sacrificial membrane at bed level,
  so the door's first layer bridges over air/membrane and cannot fuse to
  anything structural. After printing: work each door loose with one firm
  push toward the arrow, then punch the membranes out with a fingertip or
  knife.
- **Membrane punch-out aftermath**: the membrane is fused to the window
  walls at the lid's *bottom* face, ~2.7 mm below the door's slide plane
  (the door rides 0.4 mm above the plate *top*), so punch-out burrs land
  on the window's underside rim facing the tray and cannot reach the
  slide path — cosmetic only. Printers with well-tuned bridging can set
  `membrane = 0` to omit it entirely (verified: the top still exports as
  18 free bodies).
- Doors are engraved with their coordinate and an arrow showing the slide
  direction; grip bar for pushing/pulling.
- Tray/lid fit: lid drops into a 3.4 mm rebate (0.35 mm/side clearance);
  thumb notches on left/right rim expose the lid edge for lifting it out.

## Print orientation

- Both parts print flat side down, no supports.
- **top**: as modeled (plate on bed). Bridging fan on; the door undersides
  bridge the 46 mm windows — slight sag is invisible and harmless.
- **bottom**: as modeled (floor on bed).
- 0.2 mm layers assumed for the membrane/clearance numbers. PLA or PETG.
- Food contact: FDM prints are not dishwasher-safe or truly food-safe;
  serve pieces on nori/parchment squares or in silicone cups, or seal the
  tray with a food-safe epoxy if it will touch food directly.

## Rendering

`./scripts/render.sh sushi-battleship` renders the assembled preview
(default `part="assembled"`, one shutter shown open). Printable exports:

```bash
xvfb-run -a openscad -o build/sushi-battleship-top.stl    designs/sushi-battleship/sushi-battleship-top.scad
xvfb-run -a openscad -o build/sushi-battleship-bottom.stl designs/sushi-battleship/sushi-battleship-bottom.scad
xvfb-run -a openscad -o build/sushi-battleship-door.stl   designs/sushi-battleship/sushi-battleship-door.scad
```

(or `-D 'part="top"'` etc. on the main file). The top must export with
**18 CGAL volumes** (outer space + lid + 16 doors) — that's the check that
every door is a separate, free body.
