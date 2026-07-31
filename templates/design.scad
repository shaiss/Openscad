// <Design name> — <one-line description of what this part is for>.
// Requirements and decisions: see NOTES.md next to this file.
// All dimensions in millimeters.

use <printability.scad>       // repo FDM helpers (resolved via OPENSCADPATH=lib)
// include <BOSL2/std.scad>   // uncomment for fillets, threads, attachments

/* [Main dimensions] */
// Outer width (mm)
width = 40;
// Outer depth (mm)
depth = 30;
// Outer height (mm)
height = 15;

/* [Fit & tolerances] */
// Added to hole/slot dimensions to compensate for printer accuracy (mm)
fit_clearance = 0.2;

/* [Print settings] */
// Wall thickness (mm) — keep >= 1.2 (3 perimeters at 0.4 mm nozzle)
wall = 1.6;
// 45-degree chamfer on bed-contact edges (mm, 0 to disable)
bottom_chamfer = 0.6;

/* [Quality] */
// Iterating: 32. Production: 64+ (more for large-radius curves).
$fn = 32;

module main() {
    rounded_box([width, depth, height], r = 3, bottom_chamfer = bottom_chamfer);
}

main();
