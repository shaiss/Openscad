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
//    This renders at exactly seg = 27, the smallest value the chord bound
//    accepts at d_major 28. It proves one thing, precisely: the CONDITION
//    admits 27. It says nothing about the advice the error message carries —
//    that string is built only when the assert fires, so ceil(180 / acos(...))
//    is never evaluated on this path.
//
//    Its partner is boundary-seg-26-refused in lib/threads-fdm-guards.conf,
//    which carries the other two thirds: the condition refuses 26, and the
//    message names 27. Split this way because a guard manifest can only
//    express refusals, so "27 is accepted" has nowhere to live but a render.
//
//    Only together do the two say the advice is exact — refuses 26, accepts
//    27, names 27. Drop this render and a condition that tightened past its
//    own advice would still pass every check in the repo, leaving the message
//    recommending a seg that no longer works.
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

// 7. The clip-mask regime of issue #64. Left: the capsule's neck under a
//    deliberately coarse caller $fn — at $fn = 8 the old fixed d_major + 2
//    mask's inradius (15·cos 22.5° = 13.858) fell below the 14 mm crest and
//    shaved it; the mask now never tessellates coarser than `seg` and derives
//    its oversize from _mask_clear. Right: the bore cutter at tol = 2, past
//    the old d_major + 4 mask that capped delivered clearance at 2 mm
//    (single start at pitch 8, because flank_add(2) puts w_root at 6.06,
//    which the multi-start rib bound refuses at the capsule's pitch 4).
//    Render-only: a render cannot measure a mesh, so the dimensional
//    before/after lives in issue #64's measurements; this keeps the regime
//    rendering and both derived masks exercised on every check.sh run.
translate([225, 0, 0]) { $fn = 8; thread_neck(d_major, depth, pitch, starts, neck); }
translate([270, 0, 0]) thread_bore_cut(28, 1.2, 8, 1, 9, 2, over = 0.4);
