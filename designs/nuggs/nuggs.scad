// N.U.G.G.S. — Nugget's Universal Genderless Gallery Standard.
// A short, straight, wide-bore tunnel bridging two hamster enclosures.
// Requirements, welfare sources and decisions: see NOTES.md next to this file.
// All dimensions in millimeters.

/* [What to render] */
// assembled = review preview; the rest are printable parts
part = "assembled";  // [assembled, straight, bulkhead_in, bulkhead_out, coupon, cutaway]

/* [The NUGGS standard - change these and nothing you already printed fits] */
// Embossed on every module; bump only on a breaking port change
NUGGS_REV = 1;
// Internal bore (mm) - the headline number. Asserted >= min_bore_mm
bore_d = 80.0;
// Tube shell thickness (mm)
wall = 2.4;
// Radial depth of the coupling ring beyond the tube OD (mm)
lug_r = 6.0;
// Axial projection of the coupling sectors past the tube face (mm)
port_proj = 10.0;
// Coupling sectors per face (3 = kinematically determinate)
n_lug = 3;
// Angular width of each sector (deg). Asserted <= 360/n_lug/2
lug_deg = 55;
// Radial depth of the locking rib (mm)
rib_h = 1.0;
// Axial width of the locking rib / groove (mm)
rib_w = 2.4;
// Circumferential run of the bayonet groove (deg) - the locking twist
twist_deg = 40;
// Backing-collar thickness (mm) - ties the outer sectors in, stops the mate
collar_t = 3.0;
// Overlap used to fuse sectors into the tube/collar (mm). Never zero: a
// zero-volume "kiss" contact leaves CGAL counting them as separate bodies.
bite = 0.8;

/* [Fit & tolerances] */
// The one knob. Uniform clearance on every coupling surface (mm).
// Tune on the coupon in +/-0.05 steps. Asserted 0.10-0.60
port_tol = 0.30;
// M4 clearance in the bulkhead flanges (mm)
bolt_clr = 0.40;

/* [Straight] */
// Face-to-face length of the straight run (mm)
straight_len = 160;

/* [Bulkhead] */
// Enclosure-wall hole diameter (mm) - 89 mm is a stocked bi-metal size
wall_hole_d = 89;
// Spigot shell thickness through the wall (mm)
bh_spigot_wall = 2.0;
// Spigot length through the wall (mm)
bh_spigot_len = 25;
// Clamp flange outer diameter (mm)
bh_flange_d = 130;
// Flange plate thickness (mm)
bh_flange_t = 4.0;
// Clamp bolts, evenly spaced
bh_screws_n = 6;
// Clamp bolt nominal diameter (mm)
bh_bolt_d = 4.0;

/* [Welfare limits - asserted, not tunable down] */
// DTSchB entrance minimum, pouch-full criterion (mm). NEVER lower this.
min_bore_mm = 70;
// Syrian head-and-body length (mm). MEASURE YOUR ANIMAL and change this.
body_len_mm = 180;

/* [Print settings] */
// Nozzle diameter (mm) - feeds the wall assert
nozzle = 0.4;
// Bed-contact edge break (mm)
bottom_chamfer = 0.8;
// House angle for every chamfer and cone (deg). Not 45 - see NOTES.md
chamfer_ang = 50;

/* [Quality] */
// Iterating: $fa=6/$fs=1.5. Production: $fa=2/$fs=0.5.
$fa = 3;
$fs = 0.8;

/* [Hidden] */
ri = bore_d / 2;              // bore radius
ro = ri + wall;               // tube outer radius
r_mid = ro + lug_r / 2;       // split radius between inner and outer sectors
r_out = ro + lug_r;           // coupling ring outer radius
pitch = 360 / n_lug;
eps = 0.01;

// ---------------------------------------------------------------------------
// Welfare and printability asserts. These fail the render, not a lint pass.
// ---------------------------------------------------------------------------
assert(bore_d >= min_bore_mm,
       "BORE FLOOR: Deutscher Tierschutzbund gives 7 cm as the entrance minimum \
for a Syrian hamster with full cheek pouches. bore_d must be >= min_bore_mm.");
assert(lug_deg <= pitch / 2,
       "GENDERLESS: lug_deg must be <= 360/n_lug/2 or the sector pattern is not \
its own complement and two identical faces cannot interleave.");
assert(wall >= 3 * nozzle,
       "WALL: needs >= 3 perimeters at the given nozzle.");
assert(port_tol >= 0.10 && port_tol <= 0.60,
       "PORT_TOL: outside the tunable band; 0.10-0.60 mm.");
assert(straight_len + 2 * port_proj <= 240,
       "BED: the straight plus both port projections must fit a 256 mm bed \
printed upright (240 mm, leaving margin).");
assert(straight_len + 2 * (bh_spigot_len + port_proj) <= 2 * body_len_mm,
       "TVT LENGTH BUDGET: total enclosed tube must stay <= 2x body length \
(TVT Merkblatt 62). Shorten straight_len or measure a longer animal.");
assert(wall_hole_d >= bore_d + 2 * bh_spigot_wall + 1.0,
       "WALL HOLE: the hole must clear the full-bore spigot - the bore is never \
necked down at the wall crossing.");
assert(twist_deg + lug_deg <= pitch,
       "BAYONET: the locking twist plus the sector width cannot exceed the \
sector pitch, or the sectors collide before the rib seats.");
assert(rib_h < lug_r / 2 - 0.4,
       "RIB: too deep for the coupling ring's radial budget.");

// ---------------------------------------------------------------------------
// Primitives
// ---------------------------------------------------------------------------

// Annular sector: radii r1..r2, angular width `ang` from 0, height h from z=0.
module arc(r1, r2, ang, h) {
    rotate_extrude(angle = ang) translate([r1, 0]) square([r2 - r1, h]);
}

// Plain tube section.
module tube(l, r_i = ri, r_o = ro) {
    difference() {
        cylinder(r = r_o, h = l);
        translate([0, 0, -eps]) cylinder(r = r_i, h = l + 2 * eps);
    }
}

// ---------------------------------------------------------------------------
// The genderless port
//
// The coupling ring [ro, r_out] is split at r_mid into an inner and an outer
// shell. Each face carries the OUTER shell over n_lug sectors and the INNER
// shell over the sectors between them. Two identical faces therefore nest:
// where one part presents its outer shell, the mate presents its inner shell,
// at a different radius. No gendered halves, no orphan ends.
//
// Locking: each outer sector carries an inward rib; each inner sector carries
// a matching external bayonet groove — an axial entry slot, then a
// circumferential run of twist_deg. Push together, twist, the ribs seat.
// Because both features live on every part, any face mates with any face.
//
// Everything is outboard of `ro`. Nothing protrudes into the bore, ever.
// ---------------------------------------------------------------------------

// Sector angular start for index i, with a half-pitch offset for the inner set.
function outer_a(i) = i * pitch;
function inner_a(i) = i * pitch + pitch / 2;

// Bayonet groove cut into one inner sector's outer face. The mate's rib
// enters axially from our free tip (+port_proj), runs down to the seat just
// above the backing collar, then rotates along the circumferential run.
// Cut oversize by port_tol on every surface — this is the one fit knob.
module bayonet_groove(a0) {
    t = port_tol;
    // axial entry slot: from our free tip (-port_proj) up to the seat, which
    // is where the mate's tip lands against our collar (+port_proj).
    rotate([0, 0, a0 - t])
        translate([0, 0, -port_proj - eps])
            arc(r_mid - rib_h - t, r_mid + eps, lug_deg + 2 * t,
                2 * port_proj + eps);
    // circumferential run at seat depth — the twist travel
    translate([0, 0, port_proj - rib_w - t])
        rotate([0, 0, a0 - twist_deg - t])
            arc(r_mid - rib_h - t, r_mid + eps, twist_deg + lug_deg + 2 * t,
                rib_w + 2 * t);
}

// One port face. The tube face sits at z = 0 and the mate's face butts it
// there, so the bore is continuous across the joint — no gap, no step.
//
// The sectors span z = -port_proj .. +port_proj: the +z half reaches past our
// own face and runs alongside the MATE's tube, while the -z half sits
// alongside ours and leaves the interleaved sectors free for the mate's. A
// full backing collar below z = -port_proj ties the outer sectors to the tube
// (they are at r > r_mid and would otherwise float) and is the axial stop the
// mate's sector tips seat against.
// The tube body lies on the +z side of the face; the port projects to -z.
module nuggs_port() {
    difference() {
        union() {
            // backing collar: full annulus inside the tube body, fused to it.
            // This is what the mate's sector tips seat against.
            translate([0, 0, port_proj]) tube(collar_t, ri, r_out);
            // outer shell sectors: r_mid..r_out, tip at -port_proj, running up
            // into the collar so they fuse (they touch no tube wall).
            for (i = [0 : n_lug - 1])
                rotate([0, 0, outer_a(i)])
                    translate([0, 0, -port_proj])
                        arc(r_mid + port_tol / 2, r_out,
                            lug_deg, 2 * port_proj + bite);
            // inner shell sectors: bite into the tube wall so they fuse to it
            for (i = [0 : n_lug - 1])
                rotate([0, 0, inner_a(i)])
                    translate([0, 0, -port_proj])
                        arc(ro - bite, r_mid - port_tol / 2,
                            lug_deg, 2 * port_proj + bite);
            // locking rib: inward off each outer sector, just back from its tip
            for (i = [0 : n_lug - 1])
                translate([0, 0, -port_proj])
                    rotate([0, 0, outer_a(i)])
                        arc(r_mid - rib_h, r_mid + port_tol / 2 + bite, lug_deg, rib_w);
        }
        // bayonet groove in each inner sector: axial entry then a
        // circumferential run the mate's rib rotates along.
        for (i = [0 : n_lug - 1]) bayonet_groove(inner_a(i));
        // Lead-in taper on the sector tips so two faces self-centre.
        // Cut as a cone from BELOW the tips: an annular cutter that starts
        // exactly at the tip plane slices a disc off every sector instead of
        // chamfering it (12 free bodies, and printcheck rates that PRINTABLE).
        translate([0, 0, -port_proj - 1.5])
            cylinder(r1 = r_out + 1.5, r2 = r_mid - rib_h - 0.5, h = 3.0);
    }
}

// Internal edge break at a bore face: swallows elephant's foot so no lip is
// ever presented to a claw or a loaded cheek pouch.
module bore_lead(z, dir = 1) {
    translate([0, 0, z])
        rotate([dir > 0 ? 0 : 180, 0, 0])
            cylinder(r1 = ri + 1.0, r2 = ri - eps, h = 1.0 / tan(90 - chamfer_ang) );
}

// ---------------------------------------------------------------------------
// Parts
// ---------------------------------------------------------------------------

// The straight run: tube with an identical genderless port at each end.
module nuggs_straight(l = straight_len) {
    difference() {
        union() {
            tube(l);
            nuggs_port();                                   // z = 0 end
            translate([0, 0, l]) mirror([0, 0, 1]) nuggs_port();
        }
        translate([0, 0, -port_proj - 2]) cylinder(r = ri, h = l + 2 * port_proj + 4);
        translate([0, 0, -port_proj]) bore_lead(0.001, 1);
        translate([0, 0, l + port_proj]) mirror([0, 0, 1]) bore_lead(0.001, 1);
    }
}

// Flange plate with the clamp bolt circle.
module clamp_flange(t) {
    difference() {
        cylinder(r = bh_flange_d / 2, h = t);
        translate([0, 0, -eps]) cylinder(r = ri, h = t + 2 * eps);
        for (i = [0 : bh_screws_n - 1])
            rotate([0, 0, i * 360 / bh_screws_n])
                translate([(bh_flange_d / 2 + wall_hole_d / 2) / 2, 0, -eps])
                    cylinder(d = bh_bolt_d + bolt_clr, h = t + 2 * eps);
    }
}

// Inner half: flange inside the enclosure, full-bore spigot through the wall,
// and one genderless port facing into the enclosure.
module nuggs_bulkhead_in() {
    difference() {
        union() {
            clamp_flange(bh_flange_t);
            // spigot passes through the enclosure wall, bore never necked
            translate([0, 0, bh_flange_t])
                tube(bh_spigot_len, ri, ri + bh_spigot_wall);
            // port faces back out of the flange
            mirror([0, 0, 1]) nuggs_port();
        }
        translate([0, 0, -port_proj - eps])
            cylinder(r = ri, h = port_proj + bh_flange_t + bh_spigot_len + 2 * eps);
        mirror([0, 0, 1]) bore_lead(0.001, 1);
    }
}

// Outer half: flange outside the enclosure with a spigot counterbore, and a
// genderless port facing the run. Doubles as the drill-marking template.
module nuggs_bulkhead_out() {
    difference() {
        union() {
            clamp_flange(bh_flange_t);
            // Port projects UP, away from the bed. nuggs_port() puts its tube
            // body on +z and its sectors on -z, so it is mirrored and lifted
            // by the collar height; placed unmirrored the sectors point down
            // into the flange and printcheck reads 30% overhang (CRITICAL).
            translate([0, 0, port_proj + collar_t]) mirror([0, 0, 1]) nuggs_port();
        }
        // counterbore that receives the inner half's spigot
        translate([0, 0, -eps])
            cylinder(r = ri + bh_spigot_wall + port_tol, h = bh_flange_t / 2);
        translate([0, 0, -eps])
            cylinder(r = ri, h = 2 * port_proj + collar_t + 2 * eps);
        translate([0, 0, 2 * port_proj + collar_t]) mirror([0, 0, 1]) bore_lead(0.001, 1);
    }
}

// Coupon: two port stubs as a mated pair, printed side by side. Tunes
// port_tol and doubles as the bore gauge.
// stub defaults from straight_len so the wrapper's override is the real
// control. Hardcoding it made nuggs-coupon.scad's `straight_len = 25` inert:
// the geometry only looked right because the hardcoded value happened to
// match, and re-tuning the wrapper would have silently changed nothing.
module nuggs_coupon(stub = straight_len) {
    for (x = [-1, 1])
        translate([x * (r_out + 6), 0, 0]) nuggs_straight(stub);
}

// ---------------------------------------------------------------------------
// Views
// ---------------------------------------------------------------------------

module assembled() {
    color("#cdd6e0") nuggs_bulkhead_out();
    translate([0, 0, bh_flange_t + port_proj])
        color("#e8b7c8") rotate([0, 0, twist_deg]) nuggs_straight();
    translate([0, 0, bh_flange_t + port_proj + straight_len + port_proj + bh_flange_t])
        mirror([0, 0, 1]) color("#cdd6e0") nuggs_bulkhead_out();
}

if (part == "assembled") assembled();
else if (part == "straight") nuggs_straight();
else if (part == "bulkhead_in") nuggs_bulkhead_in();
else if (part == "bulkhead_out") nuggs_bulkhead_out();
else if (part == "coupon") nuggs_coupon();
else if (part == "cutaway")
    difference() { assembled(); translate([0, -200, -50]) cube([200, 400, 500]); }
else assert(false, str("unknown part: ", part));
