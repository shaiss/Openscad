// workshop-utility — style tokens.
//
// GENERATED from style.json by `stylelift sync styles/workshop-utility` — edit style.json, not this file.
// All dimensions in millimeters.
//
// Use from a design (OPENSCADPATH includes the repo root):
//     include <styles/workshop-utility/style.scad>
//     $fn = style_fn;
//     rounded_box([w, d, h], r = style_corner_r);

style_name = "workshop-utility";
style_corner_r = 4;  // mm — radius of the family's rounded edges
style_edge_chamfer = 0.6;  // mm — leg length of the family's chamfers
style_hole_d = 3.4;  // mm — the family's fastener clearance hole
style_fn = 64;  // segments — curve resolution ($fn) the family draws at

// Not part of this style (the reference gave no evidence for them): wall
