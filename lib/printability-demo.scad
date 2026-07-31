// Smoke test / visual demo for printability.scad helpers.
// Not a printable design — rendered by scripts/check.sh to catch regressions.
// All dimensions in millimeters.

use <printability.scad>

$fn = 48;

// Plate with one of each screw hole style
difference() {
    cube([46, 16, 6]);
    translate([8, 8, 0])  screw_hole("M3", l = 6);
    translate([23, 8, 0]) screw_hole("M3", l = 6, head = "socket");
    translate([38, 8, 0]) screw_hole("M3", l = 6, head = "countersunk");
}

// Teardrop hole through a wall (axis horizontal)
translate([0, 24, 0]) difference() {
    cube([16, 8, 16]);
    translate([8, 4, 9]) teardrop_hole(d = 6, l = 10);
}

// Heat-set boss and chamfered cylinder
translate([24, 28, 0]) heatset_boss("M3", h = 8);
translate([38, 28, 0]) chamfered_cylinder(d = 10, h = 12);

// Rounded box base
translate([52, 0, 0]) rounded_box([24, 20, 10], r = 4);
