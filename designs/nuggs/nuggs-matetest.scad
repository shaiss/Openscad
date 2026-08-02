// Mate/lock verification harness — NOT a printable part, not in ci.parts.
// Renders the INTERSECTION of two identical straights joined face to face:
// the mate is the same part mirrored and clocked to nest.
// Any non-zero volume is interference — geometry that cannot be assembled.
//
// The clockings move with the parameters, so this file does NOT hardcode
// them: rendering echoes the live values from nuggs_clockings(). Read them
// off the echo and feed them back in.
//
//   openscad -o /dev/null nuggs-matetest.scad          # prints the clockings
//   for c in <insertion> <locked-> <locked+>; do
//     for g in 0 2.0; do
//       openscad -o /tmp/i.stl -D "clock=$c" -D "gap=$g" nuggs-matetest.scad
//     done
//   done
//
// Pass criteria:
//   gap = 0  at the insertion clocking AND both locked clockings -> 0 mm3.
//            Non-zero means the parts cannot reach that position at all.
//   gap > 0  at the insertion clocking -> 0 mm3 (it must come apart).
//   gap > 0  at either locked clocking -> NON-ZERO (the bayonet retains).
//
// Current readings are in NOTES.md; at the time of writing the locked
// clockings both block a 2 mm pull at 47.8 mm3.
use <nuggs.scad>
gap = 0; L = 30; clock = 60;

cl = nuggs_clockings();
echo(str("nuggs-matetest: insertion clock = ", cl[0],
         " ; locked = ", cl[1], " or ", cl[2],
         " (deg) — re-run with -D clock=<one of these>"));

intersection() {
    nuggs_straight(L);
    translate([0, 0, -gap]) rotate([0, 0, clock]) mirror([0, 0, 1]) nuggs_straight(L);
}
