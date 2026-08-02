bore = 75; wall = 2.4; $fn = 96;
ro = bore/2 + wall; ri = bore/2;
part = "miter45";

module tube(l) { difference() { cylinder(r=ro,h=l); translate([0,0,-1]) cylinder(r=ri,h=l+2); } }

// A cylinder segment whose TOP face is cut at 45deg: prints flat-on-bed,
// the cut face is an upward-facing 45deg slope (self-supporting).
module miter45(base=30) {
    intersection() {
        tube(base + 2*ro);
        // half-space below the 45deg plane through z=base at x=0
        translate([-200,-200,-400]) rotate([0,45,0]) cube([400,400,400], center=false);
    }
}

// Swept 90deg elbow, centreline radius R
module sweep90(R=75) {
    rotate_extrude(angle=90) translate([R,0,0]) difference(){ circle(r=ro); circle(r=ri); }
}

if (part == "miter45") miter45();
else if (part == "sweep_flat") sweep90();                       // elbow plane on the bed
else if (part == "sweep_upright") rotate([90,0,0]) sweep90();    // one leg vertical
else if (part == "sweep_45") rotate([90,0,0]) rotate([0,-45,0]) sweep90(); // corner-down
