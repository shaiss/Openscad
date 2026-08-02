// Mate/lock verification harness — NOT a printable part, not in ci.parts.
// Renders the INTERSECTION of two identical straights joined face to face:
// the mate is the same part mirrored and clocked by pitch/2 to nest.
// Any non-zero volume is interference — geometry that cannot be assembled.
//
//   for c in 60 20 100; do for g in 0 2.0; do
//     openscad -o /tmp/i.stl -D "clock=$c" -D "gap=$g" nuggs-matetest.scad
//   done; done
//
// The locked clocking is pitch/2 +/- twist_deg, so it moves with the
// parameters. At the SHIPPED defaults (n_lug=3, twist_deg=40):
//   clock = 60      -> insertion clocking
//   clock = 20/100  -> locked, either twist direction
// The 35/85 quoted in NOTES.md belong to the PROPOSED lug_deg=30,
// twist_deg=25; reproduce those with
//   -D 'lug_deg=30' -D 'twist_deg=25' -D 'clock=35'
//
// Insertion and locked clockings must both read 0 mm3. gap > 0 at a locked
// clock is the pull-off test: it must be NON-zero once the bayonet actually
// retains. It currently reads free at every clocking - see NOTES.md.
use <nuggs.scad>
gap = 0; L = 30; clock = 60;
intersection() {
    nuggs_straight(L);
    translate([0, 0, -gap]) rotate([0, 0, clock]) mirror([0, 0, 1]) nuggs_straight(L);
}
