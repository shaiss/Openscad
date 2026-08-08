// Exercises every module in print-in-place.scad — check.sh CGAL-renders this
// on every run, so it is the library's geometry regression test (guards have
// their own negative suite in print-in-place-guards.conf, and the tab/lip and
// hinge FITS are measured on exported meshes in print-in-place-mates.conf —
// a render cannot measure itself, issue #37).
use <print-in-place.scad>

// The hinge's teardrop bore is the library's one curved surface and is
// $fn-sensitive; everything else is polyhedral. Production-quality per
// CLAUDE.md's visible-cylinder floor.
$fn = 64;

// ---------------------------------------------------------------------------
// Station 1: reference bay at the battleship's exact one-cell numbers
// (window 46 -> pitch 58, door 47.6 x 50, travel 6.7). A change that would
// have altered the frozen design's mechanism shows up here first. The wall
// and plate are caller-owned (see slide_rail's doc): the wall is sized by
// pip_rail_h() and buried eps into the plate, the same relationships the
// battleship uses — they are load-bearing mesh hygiene (a kiss contact is
// fused by CGAL but shipped by Manifold as a separate shell).
// ---------------------------------------------------------------------------
pitch = 58; opening = 46; rail_w = 2.4; plate_t = 3;
door_w = 47.6; door_l = 50; door_t = 2.4; gap_z = 0.6;
travel = 6.7;
rh = pip_rail_h();                 // 5.7 at the battleship defaults
wall_in = pitch/2 - rail_w/2;      // the rail wall's cell-side face

{
    // plate patch (top at z = 0, the slide_rail/end_stop origin plane)
    translate([-(wall_in + rail_w), -pitch/2, -plate_t])
        cube([2*(wall_in + rail_w), pitch, plate_t]);
    for (s = [-1, 1]) {
        // caller-owned rail wall, pip_rail_h() tall, eps-buried into the plate
        translate([s == 1 ? wall_in : -(wall_in + rail_w), -pitch/2, -0.01])
            cube([rail_w, pitch, rh + 0.01]);
        translate([s*wall_in, 0, 0])
            slide_rail(travel, side = s);
    }
    // end stop, gap-clear of the closed door's rear face
    translate([0, -door_l/2, 0])
        end_stop(door_w);
    // the door, posed mid-slide: body + tabs (tabs under lips, lifted-out
    // clearances visible in section)
    translate([0, travel/2, 0]) {
        translate([-door_w/2, -door_l/2, gap_z])
            cube([door_w, door_l, door_t]);
        slide_tab(door_w);
    }
}

// ---------------------------------------------------------------------------
// Station 2: sacrificial membrane worked example — the module is the WINDOW
// CUTTER, and the membrane is what it spares below z = h.
// ---------------------------------------------------------------------------
translate([90, 0, 0])
    difference() {
        translate([-15, -15, 0]) cube([30, 30, 3]);
        sacrificial_membrane(h = 0.2, cut_h = 3)
            square(20, center = true);
    }

// ---------------------------------------------------------------------------
// Station 3: hinge — quadrant-cut knuckle (teardrop bore profile visible),
// the matching pin, and the pair assembled (pin captive in the bore, 0.5 mm
// radial clearance; the fit itself is measured in print-in-place-mates.conf).
// ---------------------------------------------------------------------------
translate([140, 0, 0]) {
    difference() {
        pip_hinge();
        translate([0, -10, 0]) cube([20, 20, 20]);
    }
    translate([25, 0, 0]) pip_hinge_pin();
    translate([50, 0, 0]) { pip_hinge(); pip_hinge_pin(); }
}

// ---------------------------------------------------------------------------
// Station 4: boundary-accepting renders — the accepting halves of the range
// guards, which a guards manifest (refusals only) cannot express: the
// loosest legal door fit, and an end-stop gap just above the weld floor.
// ---------------------------------------------------------------------------
translate([210, 0, 0]) {
    slide_tab(door_w, fit = 0.5);
    translate([0, 0, 5]) end_stop(door_w, gap = 0.41);
}

echo(str("pip_lip_z() = ", pip_lip_z(),
         " mm — the tab/lip fit is verified on the exported mesh in ",
         "print-in-place-mates.conf, not by this echo (issue #37)"));
