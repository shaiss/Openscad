// ribbed-industrial — style tokens.
//
// GENERATED from style.json by `stylelift sync styles/ribbed-industrial` — edit style.json, not this file.
// All dimensions in millimeters.
//
// Use from a design (OPENSCADPATH includes the repo root):
//     include <styles/ribbed-industrial/style.scad>
//     $fn = style_fn;
//     rounded_box([w, d, h], r = style_corner_r);

style_name = "ribbed-industrial";
style_corner_r = 4;  // mm — radius of the family's rounded edges
style_edge_chamfer = 1;  // mm — leg length of the family's chamfers
style_wall = 3;  // mm — material thickness the family builds at
style_fn = 64;  // segments — curve resolution ($fn) the family draws at
style_max_overhang_deg = 45;
style_rib_crest = 1;
style_rib_depth = 1;
style_rib_pitch = 5;

// Not part of this style (the reference gave no evidence for them): hole_d
