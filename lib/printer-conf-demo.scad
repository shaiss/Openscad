// Smoke test / example consumer for printer-conf.scad.
// Not a printable design — rendered by scripts/check.sh to catch regressions.
// Shows the canonical use: read the measured profile instead of hardcoding a
// generic clearance. All dimensions in millimeters.

include <printer-conf.scad>

$fn = 48;

// A block with a slot whose width is grown by the measured fit clearance —
// printer_fit() reads printer_xy_tol from the resolved profile.
difference() {
    cube([24, 14, 8]);
    translate([4, 4, 3]) cube([printer_fit(12), 6, 8]);
}

// Report what the profile compiled to, so a reader (and printer-conf-check.sh)
// can see the resolved values.
echo(printer_xy_tol = printer_xy_tol,
     printer_nozzle_d = printer_nozzle_d,
     printer_material = printer_material);
