// Calibration cube — starter design demonstrating repo conventions.
// A simple cube with chamfered bottom edges and an engraved size marker,
// useful for checking printer dimensional accuracy.
// All dimensions in millimeters.

/* [Size] */
// Edge length of the cube (mm)
size = 20;

/* [Printing] */
// 45-degree chamfer on the bottom edges so the first layer releases cleanly (mm, 0 to disable)
bottom_chamfer = 0.6;

/* [Quality] */
// Iterating: 32. Production: 64+.
$fn = 64;

module calibration_cube() {
    difference() {
        // Cube with chamfered bottom edges
        hull() {
            translate([bottom_chamfer, bottom_chamfer, 0])
                cube([size - 2 * bottom_chamfer, size - 2 * bottom_chamfer, 0.01]);
            translate([0, 0, bottom_chamfer])
                cube([size, size, size - bottom_chamfer]);
        }
        // Engraved size marker on the top face
        translate([size / 2, size / 2, size - 0.4])
            linear_extrude(0.5)
                text(str(size), size = size * 0.35, halign = "center", valign = "center");
    }
}

calibration_cube();
