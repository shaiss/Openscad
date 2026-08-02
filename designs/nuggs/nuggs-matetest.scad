// Mate/lock verification harness — NOT a printable part, not in ci.parts.
// Renders the INTERSECTION of two identical straights joined face to face:
// the mate is the same part mirrored and clocked by pitch/2 to nest.
// Any non-zero volume is interference — geometry that cannot be assembled.
//
//   for c in 60 35 85; do for g in 0 2.0; do
//     openscad -o /tmp/i.stl -D "clock=$c" -D "gap=$g" nuggs-matetest.scad
//   done; done
//
// clock = 60  -> insertion clocking (must be 0 mm3)
// clock = 35/85 -> locked, either twist direction (must be 0 mm3)
// gap > 0 with a locked clock -> pulling apart; must be NON-zero once the
// bayonet actually retains. It currently reads free: see NOTES.md.
use <nuggs.scad>
gap = 0; L = 30; clock = 60;
intersection() {
    nuggs_straight(L);
    translate([0, 0, -gap]) rotate([0, 0, clock]) mirror([0, 0, 1]) nuggs_straight(L);
}
