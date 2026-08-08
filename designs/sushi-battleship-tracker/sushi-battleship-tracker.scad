// sushi-battleship-tracker — shot-tracker refit of the archived
// sushi-battleship (frozen at v0.1): every print-in-place shutter door
// gains a shallow spherical miss-marker seat in its top face, so a called
// cell can be marked with a small round marker (dried soybean, 6 mm BB,
// peppercorn) instead of remembered.  Requirements and decisions: PM.md
// and NOTES.md next to this file.  All dimensions in millimeters.
//
// DERIVATIVE: the parent is included verbatim below and only door() is
// redefined; the parent's own call sites (lid_assembly) route to the
// redefinition, so the print-in-place top inherits the seat on all 16
// doors.  Lineage record: derives.conf; gate.sh proves each replaces:
// claim by mesh comparison (background: docs/derivative-designs.md).
//
// Fit surfaces — door body/tab dimensions, rails, lips, every clearance —
// are inherited untouched from the frozen parent (PM.md N1): the seat is
// a cut in the door's top face only, so a door_fit tuned on the parent's
// coupon transfers unchanged, and the refit adds zero height (N4).

include <../sushi-battleship/sushi-battleship.scad>

/* [Miss-marker seat] */
// mm, diameter of the roughly-spherical marker the seat is dished for
// (dried soybean ~7-9, 6 mm airsoft BB, peppercorn ~4-5)
marker_d = 8;
// mm, depth of the spherical seat cut into the door top face
seat_depth = 1.0;

/* [Hidden] */
assert(marker_d >= 4 && marker_d <= 10,
       "marker_d outside the practical 4-10 mm range the seat is designed for (peppercorn to large soybean)");
assert(seat_depth > 0 && seat_depth < marker_d/2,
       "seat_depth must be positive and shallower than the marker radius");
assert(door_t - seat_depth >= 1.2,
       "seat too deep: the door needs >= 1.2 mm of floor under the marker seat");

// ---- derived seat geometry ----
// contact-circle radius of a marker_d sphere sunk seat_depth into the face
seat_r  = sqrt((marker_d/2)*(marker_d/2)
             - (marker_d/2 - seat_depth)*(marker_d/2 - seat_depth));
// effective door length (the parent shrinks the body by door_fit per side)
dl_eff  = door_l - 2*door_fit;
// The seat sits centred in the free band between the engraved coordinate
// (size-9 text, valign=center at y=-1, so it spans to y=+3.5) and the
// engraved push arrow (base at y = dl_eff/2 - 9), in door-local coords.
seat_y  = ((dl_eff/2 - 9) + 3.5)/2;

assert((dl_eff/2 - 9) - (seat_y + seat_r) >= 0.8,
       "seat rim would run into the engraved push arrow; shrink marker_d or seat_depth");
assert((seat_y - seat_r) - 3.5 >= 0.8,
       "seat rim would run into the engraved coordinate; shrink marker_d or seat_depth");

echo(str("Marker seat: ", 2*seat_r, " mm opening, ", seat_depth,
         " mm deep, centred at door y=", seat_y));

// ============================================================
//  SHUTTER DOOR — replaces the parent's.  Body, tabs, grip bar and
//  engravings are restated verbatim (OpenSCAD has no way to extend a
//  module, and the parent is frozen so the restatement cannot drift);
//  the only delta is the spherical miss-marker seat.  The seat is a
//  dish cut from the top, so every layer's hole is wider than the one
//  below it: fully self-supporting in the print-in-place top.
// ============================================================
module door(label = "A1") {
    // door_fit shrinks (+) or grows (-) the door symmetrically; the
    // lid geometry never changes, so a re-tuned door stays a drop-in
    dw = door_w - 2*door_fit;      // effective body width
    dl = door_l - 2*door_fit;      // effective body length
    gw = min(18, dw - 10);         // grip bar width
    difference() {
        union() {
            // body
            translate([-dw/2, -dl/2, gap_z])
                cube([dw, dl, door_t]);
            // 3 locking tabs per side (bottom slab sticking out sideways)
            for (s = [-1, 1], c = [-tab_c, 0, tab_c])
                translate([s*dw/2 - (s < 0 ? tab_w : 0),
                           c - tab_len/2, gap_z])
                    cube([tab_w, tab_len, tab_t]);
            // grip bar near the front edge
            translate([-gw/2, -dl/2 + 2, gap_z + door_t - eps])
                cube([gw, 3.2, 2.4]);
        }
        // engraved coordinate
        translate([0, -1, gap_z + door_t - 0.6])
            linear_extrude(0.7)
                text(label, size = 9, halign = "center", valign = "center",
                     font = "DejaVu Sans:style=Bold");
        // engraved "push this way" arrow
        translate([0, dl/2 - 9, gap_z + door_t - 0.6])
            linear_extrude(0.7)
                polygon([[-3.5, 0], [3.5, 0], [0, 4.5]]);
        // miss-marker seat: a marker_d sphere sunk seat_depth into the
        // top face.  The rim edge is naturally obtuse (the sphere meets
        // the face at ~41 deg from vertical at the defaults), so no
        // extra edge break is needed and the marker self-centres.
        translate([0, seat_y, gap_z + door_t + marker_d/2 - seat_depth])
            sphere(d = marker_d);
    }
}
