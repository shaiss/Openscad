// Mate/lock verification harness — NOT a printable part, not in ci.parts.
// Renders the INTERSECTION of two identical bodies joined face to face: the
// mate is the same body mirrored and clocked to nest. Any non-zero VOLUME is
// interference — geometry that cannot be assembled.
//
// It now exercises the LIBRARY's port (lib/nuggs-coupling.scad), not a copy
// living in this design. Default `body = "neck"` is nuggs_neck() — the port on
// a plain full-round shell, i.e. the standard with nothing of this design
// attached, which is the thing every module in the system inherits.
// `body = "straight"` runs the same test on this design's actual printed part,
// which is the claim a person bolting one on cares about. The two must agree;
// if they ever do not, the design has done something to the joint.
//
// lib/nuggs-coupling-mates.conf is the CI-enforced version of this file and it
// is exhaustive. This one exists to be driven by hand while tuning.
//
//   openscad -o /dev/null nuggs-matetest.scad          # prints the clockings
//   for c in <insertion> <locked-> <locked+>; do
//     for g in 0.01 2.0; do
//       openscad -o /tmp/i.stl -D "clock=$c" -D "gap=$g" nuggs-matetest.scad
//     done
//   done
//
// Pass criteria:
//   gap = 0.01  at the insertion clocking AND both locked clockings -> empty.
//               Non-zero means the parts cannot reach that position at all.
//   gap = 2.0   at the insertion clocking -> empty (it must come apart).
//   gap = 2.0   at either locked clocking -> NON-EMPTY (the bayonet retains).
//
// WHY THE SMALLEST GAP IS 0.01 AND NOT 0. z_seat = port_proj = -z_tip, so the
// two tube end faces butt at exactly the instant the mate's sector tips land on
// the collar: both axial stops are at ZERO nominal clearance by construction.
// At gap = 0 the intersection is therefore a coincident-plane shell — real
// facets enclosing exactly 0.000 mm3 — and any harness that counts facets
// rather than volume reads that as interference. 0.01 mm separates coincident
// planes and nothing else; the retention cases pull 200x further. Do not
// mistake this for a fudge on the fit: it is the same 0.01 mm offset
// lib/nuggs-coupling-mates.conf uses, for the same reason, documented there.
//
// The clockings move with the parameters, so this file does NOT hardcode them:
// rendering echoes the live values from nuggs_clockings(). Read them off the
// echo and feed them back in.
//
// Current readings are in NOTES.md; at the time of writing the locked
// clockings both block a 2 mm pull at 47.8 mm3.
use <nuggs-coupling.scad>
use <nuggs.scad>

gap = 0.01; L = 30; clock = 60;
body = "neck";  // [neck, straight]

// The standard's own defaults. designs/nuggs reproduces them exactly — that is
// what "one interlock standard" means — so the neck and the straight are the
// same joint. Change a port parameter in nuggs.scad and this file must be
// given the same change, or the disagreement is the finding.
cfg = nuggs_cfg();

cl = nuggs_clockings(cfg);
echo(str("nuggs-matetest: body = ", body, " ; insertion clock = ", cl[0],
         " ; locked = ", cl[1], " or ", cl[2],
         " (deg) — re-run with -D clock=<one of these>"));

module mate_body() {
    if (body == "neck") nuggs_neck(cfg, L);
    else if (body == "straight") nuggs_straight(L);
    else assert(false, str("unknown body: ", body));
}

intersection() {
    mate_body();
    translate([0, 0, -gap]) rotate([0, 0, clock]) mirror([0, 0, 1]) mate_body();
}
