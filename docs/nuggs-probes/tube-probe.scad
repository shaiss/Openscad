// Orientation probe: a plain 75 mm-bore tube, three ways.
bore = 75;      // internal diameter (mm)
wall = 2.4;     // wall thickness (mm)
len  = 150;     // segment length (mm)
part = "vertical";
$fn = 64;

module tube() {
    difference() {
        cylinder(d = bore + 2*wall, h = len);
        translate([0,0,-1]) cylinder(d = bore, h = len + 2);
    }
}

if (part == "vertical") tube();
else if (part == "horizontal") rotate([0,90,0]) tube();
else if (part == "clamshell")  // one half-shell, cut face down on the bed
    rotate([0,90,0]) intersection() {
        tube();
        translate([-100,0,-1]) cube([200,200,len+2]);
    }
