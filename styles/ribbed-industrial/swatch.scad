// ribbed-industrial — the style's swatch: a small ribbed housing.
//
// Written FROM the tokens, never from retyped numbers, so it satisfies the
// style's rules by construction. ./scripts/style-check.sh ribbed-industrial
// renders this and holds it to styles/ribbed-industrial/style.json — if the
// swatch cannot pass, the spec is wrong, not the swatch.
//
// Every sloped face here is at exactly 45 degrees, which is the whole style:
// the rib flanks, the bed break and the rim break are all the same cut, so
// nothing on the part needs support.
include <styles/ribbed-industrial/style.scad>

$fn = style_fn;

/* [Swatch] */
w = 44;                     // outer width (mm)
d = 34;                     // outer depth (mm)
h = 25;                     // outer height (mm)
band_w = 14;                // width of the smooth grip band (mm)

eps = 0.01;                 // slab thickness for hull() transitions

// The family's plan: a rounded rectangle at the style's corner radius,
// optionally grown by `g` (negative shrinks it, for a bed or rim break).
module plan(g = 0) {
    offset(r = style_corner_r + g)
        square([w - 2 * style_corner_r, d - 2 * style_corner_r], center = true);
}

// One rib: out at 45, along the crest, back in at 45. Hulling between two
// plans whose offsets differ by exactly their height difference is what makes
// the flank 45 degrees — the same construction as the bed break below.
module rib(z0) {
    hull() {
        translate([0, 0, z0]) linear_extrude(eps) plan();
        translate([0, 0, z0 + style_rib_depth])
            linear_extrude(eps) plan(style_rib_depth);
    }
    translate([0, 0, z0 + style_rib_depth])
        linear_extrude(style_rib_crest) plan(style_rib_depth);
    hull() {
        translate([0, 0, z0 + style_rib_depth + style_rib_crest])
            linear_extrude(eps) plan(style_rib_depth);
        translate([0, 0, z0 + 2 * style_rib_depth + style_rib_crest])
            linear_extrude(eps) plan();
    }
}

// The smooth band the ribs run into: where a hand grips the part, the family
// stops articulating the surface and leaves it plain.
module grip_band() {
    proud = 2 * style_rib_depth;
    intersection() {
        hull() {
            linear_extrude(h - style_edge_chamfer) plan(proud);
            linear_extrude(h) plan(proud - style_edge_chamfer);
        }
        // rounded in plan, so the band meets the ribs as a swelling of the
        // wall rather than as a lug bolted onto it
        linear_extrude(h)
            offset(r = style_corner_r / 2)
                square([band_w - style_corner_r, 2 * d], center = true);
    }
}

module shell() {
    // core, broken at 45 degrees where it meets the bed and again at the rim
    hull() {
        linear_extrude(eps) plan(-style_edge_chamfer);
        translate([0, 0, style_edge_chamfer]) linear_extrude(eps) plan();
    }
    translate([0, 0, style_edge_chamfer])
        linear_extrude(h - 2 * style_edge_chamfer) plan();
    hull() {
        translate([0, 0, h - style_edge_chamfer]) linear_extrude(eps) plan();
        translate([0, 0, h - eps])
            linear_extrude(eps) plan(-style_edge_chamfer);
    }
    // ribs run the height of the wall, stopping short of the rim break so the
    // top edge stays a clean 45-degree cut
    for (z = [style_rib_pitch : style_rib_pitch :
              h - 2 * style_rib_depth - style_rib_crest - style_edge_chamfer])
        rib(z);
    grip_band();
}

difference() {
    shell();
    // cavity: vertical walls on a flat floor, open at the top, so there is
    // nothing inside for a printer to bridge
    translate([0, 0, style_wall])
        linear_extrude(h) offset(r = -style_wall) plan();
}
