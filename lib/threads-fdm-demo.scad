// Smoke test / visual demo for threads-fdm.scad.
// Not a printable design — rendered by scripts/check.sh to catch regressions.
// All dimensions in millimeters.

use <threads-fdm.scad>

$fn = 48;

// Reference thread: the desiccant-capsule's own numbers, so a change that
// would alter that design shows up here first (it is the library's only
// production consumer today).
d_major = 28;
depth   = 1.2;
pitch   = 4;
starts  = 2;
neck    = 9;
tol     = 0.3;

// 1. Bare helix — the generator on its own, no core.
thread_helix(d_major, depth, pitch, starts, neck);

// 2. Male neck on a plinth, with its lead-in chamfer.
translate([45, 0, 0]) {
    cylinder(d = d_major + 6, h = 3);
    translate([0, 0, 3]) thread_neck(d_major, depth, pitch, starts, neck);
}

// 3. Matching female bore, cut out of a lid blank — the worked example the
//    thread_bore_cut() doc points at. Cut away one quadrant so the groove
//    profile is visible in the render.
translate([90, 0, 0]) difference() {
    cylinder(d = d_major + 2 * tol + 4, h = neck + 2);
    // MANDATORY, not incidental: thread_bore_cut() cuts the groove only. Drop
    // this line and the lid is a solid plug — it still renders, slices and
    // passes the gate, it just cannot go on the neck.
    translate([0, 0, -0.01])
        cylinder(d = d_major - 2 * depth + 2 * tol, h = neck + 2.02);
    thread_bore_cut(d_major, depth, pitch, starts, neck, tol, over = 0.4);
    translate([0, 0, -0.01]) cube([40, 40, neck + 2.02]);   // quadrant window
}

// 4. Single-start, finer thread on a smaller neck — a different lead from the
//    capsule's, to keep the library honest about parameter sets it has never
//    seen. (0.8 mm depth at pitch 2 would put w_root at 2.1 against a 2.0 lead
//    and self-intersect; the assert in thread_helix now says so out loud.)
translate([135, 0, 0]) thread_neck(16, 0.6, 3, 1, 10);

// 5. The accepting half of the chord bound's boundary.
//
//    The seg guard does not only refuse — it advises, computing the seg that
//    would satisfy it as ceil(180 / acos(1 - 2*_max_chord / d_major)). At
//    d_major 28 that advice is 27. This renders at exactly 27, so if the
//    advice ever drifts one too high the render aborts here.
//
//    Its partner is boundary-seg-26-refused in lib/threads-fdm-guards.conf,
//    which pins the other side. A guard manifest can only express refusals, so
//    "27 is accepted" has nowhere to live but a render — and without it, an
//    off-by-one in the advice would leave every check in the repo green while
//    the error message named a seg that does not actually work.
translate([180, 0, 0]) thread_helix(d_major, depth, pitch, starts, neck, seg = 27);

// 6. The clearance derivation is a function, not a magic number.
//
//    This echoes the value only. It deliberately does NOT echo the flank gap
//    that value is supposed to produce, because the arithmetic for that gap is
//    the identity that defines flank_add — printing it proves the formula
//    equals itself and nothing about the geometry above.
//
//    That is not hypothetical: this line used to print
//    "0.3 (should equal 0.3)" for the whole time the built profile was
//    delivering 0.2794 (issue #37). It could not have said otherwise.
//
//    The invariant is tested where it can actually fail, against the exported
//    mesh: lib/threads-fdm-mates.conf, run by scripts/mate-check.sh.
echo(str("flank_add(", tol, ") = ", flank_add(tol),
         "  -- fit is verified in threads-fdm-mates.conf, not here"));
