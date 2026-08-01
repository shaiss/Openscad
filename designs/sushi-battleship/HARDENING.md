# sushi-battleship — first-print hardening (PR #3 work plan)

Owner directive: the quality bar for this design is now **a stranger's first
print succeeds**. A five-lens print-physics analysis of the merged design
found the defects below. This file is the working brief for the hardening
rounds; it is replaced by updates to NOTES.md as rounds land. The design
coach reviews each round on the PR; standing requirement: every round ships
`previews/` close-ups of each changed region, with exact render commands
recorded in `previews/CAMERAS.md` (fixed cameras across rounds).

## Round A — print-physics defects (landed — decisions and margin math
## recorded in NOTES.md "Key decisions"; summary on the PR)

**A1 (killer) — end-stop ridge welds to doors.** The ridge sits 0.2 mm from
every closed door's leading face by construction (ridge at
`boundary + m_y - 1`, 0.8 mm wide; door face at `boundary + m_y`), ~1 mm of
z-overlap along 42 mm, on all 16 doors. The door's draped first-layer
perimeter spot-welds to it. Fix parametrically (`ridge_gap = clr_h`) and
re-derive `slide` + asserts to track it (at 0.5 mm gap, ~6.7 mm travel
still frees the tabs — show the margin math in NOTES).

**A2 (killer) — gap_z quantization.** `gap_z = 0.4` is 2 air layers only on
the 0.2 mm grid; at 0.24-with-0.2-first-layer and at uniform 0.3 it
quantizes to ONE layer and all 16 doors fuse. Raise to 0.6 (survives
0.2/0.24/0.28/0.3; ~0.2 mm extra closed rattle) or keep 0.4 with hard
layer-height limits as the first line of the print notes. Either way, put
the quantization table (0.12/0.16/0.2/0.24/0.28/0.3) in NOTES and defend
the choice.

**A3 (major) — 47.6 mm free-air first-layer bridge per door.** The window
chamfer mouth equals `door_w` to 0.01 mm (zero side bearing) and the
membrane top is 3.1 mm below the door bottom — it catches dropped strands,
it does not support the bridge (correct the code comment). Deepen the
window-edge lead-in chamfer (0.8 → ~1.6 mm) so sag at the slide-crossing
point ramps over instead of jamming; consider side bearing for the door
long edges; document freeing doors toward the arrow.

Round A previews minimum: ridge-zone close-up (gap visible), door
cross-section showing the gap_z stack, window-edge chamfer profile,
standard contact sheet. Verify 18 CGAL volumes still hold.

## Later rounds (assigned by coach on the PR — do not pre-empt)

- Round B: 1-cell test coupon part, door-only clearance knob, membrane on
  the layer grid, honest print-settings page (bed-fit table correction).
- Round C: closed-position detent, re-lock lead-in chamfers, on-record
  locking-mechanism options analysis.
