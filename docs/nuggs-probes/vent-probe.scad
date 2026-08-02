use <printability.scad>
bore = 75; wall = 2.4; len = 150; vent_d = 6; $fn = 64;
style = "round";   // "round" | "teardrop" | "none"
ro = bore/2 + wall; ri = bore/2;
rings = 6; per_ring = 10;

module tube() { difference(){ cylinder(r=ro,h=len); translate([0,0,-1]) cylinder(r=ri,h=len+2);} }

module vents() {
    for (k = [0:rings-1]) for (i = [0:per_ring-1])
        translate([0,0, 20 + k*(len-40)/(rings-1)])
            rotate([0,0, i*360/per_ring + (k%2)*180/per_ring])
                translate([0, 0, 0]) rotate([0,0,0])
                    // move outward along +Y, axis radial
                    if (style == "round")
                        rotate([-90,0,0]) translate([0,0,0]) cylinder(d=vent_d, h=2*ro+2, center=true);
                    else
                        teardrop_hole(d=vent_d, l=2*ro+2);
}

difference(){ tube(); if (style != "none") vents(); }
