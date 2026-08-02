// workshop-utility swatch — the smallest part that still shows the whole
// style: rounded plan-view corners, a chamfered bed edge, the family's M3
// clearance holes, and a boss whose top edge is broken the same way.
//
// This is the style's regression test. ./scripts/style-check.sh renders it and
// checks it against styles/workshop-utility/style.json, so a spec that no part
// can actually satisfy fails here rather than in somebody's design session.
// It is also a printable thing in its own right: a mounting pad.
//
// Every number below comes from the style, not from taste — that is the point.
include <styles/workshop-utility/style.scad>
use <printability.scad>

/* [Swatch size] */
// Pad footprint and thickness (mm)
pad = [34, 22, 8];
// Boss diameter and height above the pad (mm)
boss_d = 12;
boss_h = 5;

/* [Quality] */
$fn = style_fn;

module swatch() {
    difference() {
        union() {
            rounded_box(pad, r = style_corner_r,
                        bottom_chamfer = style_edge_chamfer);
            // 0.01 overlap: a boss that merely touches the pad leaves a
            // zero-thickness seam for the mesher to argue with
            translate([pad[0] / 2, pad[1] / 2, pad[2] - 0.01])
                chamfered_cylinder(d = boss_d, h = boss_h + 0.01,
                                   chamfer1 = 0, chamfer2 = style_edge_chamfer);
        }
        for (x = [style_corner_r + 3, pad[0] - style_corner_r - 3])
            translate([x, pad[1] / 2, -0.1])
                screw_hole("M3", l = pad[2] + 0.2);
    }
}

swatch();
