# Preview render commands — fixed cameras

Run from the repo root. Cameras are FIXED across review rounds so
before/after comparisons align; if a new region needs a shot, add a new
camera here rather than moving an existing one.

Set these shell variables before running any command:

```bash
SRC=designs/sushi-battleship/sushi-battleship.scad
PRE=designs/sushi-battleship/previews
```

**contact-sheet.png** — 4-view overview (iso / top / front / bottom-iso):

```bash
./scripts/render.sh sushi-battleship && cp build/sushi-battleship.png $PRE/contact-sheet.png
```

**assembly.png** — assembled board, shutter D1 slid open and lifted
(`demo_open`), preview sushi piece visible. Explicit camera (no
auto-framing) so this shot stays aligned across rounds like the rest:

```bash
xvfb-run -a openscad -o $PRE/assembly.png --imgsize=1400,1000 \
  --camera=0,0,22,55,0,25,700 -D 'part="assembled"' -D 'demo_open=true' $SRC
```

**shutter-closeup.png** — lid only, D1 slid fully open at plate level:
tabs aligned with the lip gaps, membrane visible through the revealed
window slice:

```bash
xvfb-run -a openscad -o $PRE/shutter-closeup.png --imgsize=1400,1000 \
  --camera=72,-95,0,60,0,30,150 -D 'part="top_open"' $SRC
```

**cutaway.png** — X-Z section through the middle tab of cell B1
(row 1): gap_z air gap under the door, tab/lip stack, membrane at bed
level, side-edge chamfers:

```bash
xvfb-run -a openscad --render -o $PRE/cutaway.png --imgsize=1600,400 \
  --projection=o --camera=-29,-160,5,90,0,0,80 -D 'part="cutaway"' $SRC
```

**slide-section.png** — Y-Z section through the centre of column B,
framed on the row-1/row-2 boundary: rear 1.6 mm vs front 0.8 mm window
chamfers, end-stop ridge with its 0.5 mm gap to the door face, grip
bar profile (re-framed once on reviewer request before the camera
freeze, 2026-08-01):

```bash
xvfb-run -a openscad --render -o $PRE/slide-section.png --imgsize=1600,320 \
  --projection=o --camera=-29,-58,4,90,0,-90,55 -D 'part="cutaway_slide"' $SRC
```

**ridge-closeup.png** — view onto the row-1/row-2 boundary of column B
with both neighbouring doors in frame for scale: door B1's rear edge
(bottom, arrow visible), the end-stop ridge, the 0.5 mm ridge_gap
channel, and door B2's leading edge and grip (top). Re-framed once on
reviewer request before the camera freeze, 2026-08-01:

```bash
xvfb-run -a openscad -o $PRE/ridge-closeup.png --imgsize=1400,1000 \
  --camera=-29,-58,3,45,0,20,85 -D 'part="top"' $SRC
```
