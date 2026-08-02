bore = 75; wall = 2.4; $fn = 96; BIG = 500;
ro = bore/2 + wall; ri = bore/2;
part = "bend45"; angle = 45; la = 40; lb = 40;

module tube(l) { difference() { cylinder(r=ro,h=l); translate([0,0,-1]) cylinder(r=ri,h=l+2); } }
module hs_below(t) { rotate([0,t,0]) translate([0,0,-BIG/2]) cube(BIG, center=true); }
module hs_above(t) { rotate([0,t,0]) translate([0,0, BIG/2 - 0.02]) cube(BIG, center=true); }

// Mitred bend: two straight legs meeting on a plane that bisects the bend.
// Printed standing on the inlet flange, the outlet leg leans back by `angle`.
module bend(a, la, lb) {
    translate([0,0,la]) union() {
        intersection() { translate([0,0,-la]) tube(la + BIG/2); hs_below(a/2); }
        intersection() { rotate([0,a,0]) translate([0,0,-BIG/2]) tube(lb + BIG/2); hs_above(a/2); }
    }
}
bend(angle, la, lb);
