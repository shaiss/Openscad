# Frozen preview cameras — sushi-battleship-tracker

Rendered by `./scripts/render.sh sushi-battleship-tracker --previews` from
`cameras.conf`. Cameras are frozen once a reviewer has seen the shot; a new
region to show gets a new line, an existing line is never moved.

- **contact-sheet** — the standard 4-view sheet (iso / top / front /
  bottom-iso) of the default assembled render.
- **assembly** — the whole board assembled, shutter D1 slid open and lifted
  with the demo sushi piece visible: the same promise as the parent's
  assembly shot, now with a marker seat visible on every closed door.
- **seat-closeup** — the delta itself: the A1/A2 corner of the
  print-in-place top, close enough to read the dished miss-marker seat
  between each door's coordinate engraving and push arrow, with the rails
  and castellated lips for context.
- **coupon** — the single-cell "print this first" coupon
  (`sushi-battleship-tracker-coupon.scad`): one complete door with rails,
  lips, membrane and the marker seat, the piece to tune `door_fit` and
  marker fit on.
