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
// Angular width of each sector (deg). Asserted lug_deg + twist_deg <= pitch/2
lug_deg = 30;
// Radial depth of the locking rib (mm)
rib_h = 1.0;
// Axial width of the locking rib / groove (mm)
rib_w = 2.4;
// Angular width of the locking rib (deg). Must be narrower than the sector,
// or the entry slot that admits it consumes the whole sector and there is
// nothing left for the rib to twist under.
rib_deg = 12;
// The locking twist (deg). Asserted rib_deg + twist_deg <= lug_deg.
twist_deg = 14;
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
assert(rib_deg + twist_deg <= lug_deg,
       "BAYONET TRAVEL: the rib must be able to twist rib_deg->lug_deg within \
the mate's sector. rib_deg + twist_deg must fit inside lug_deg, or the rib \
runs off the end of the sector and retains nothing.");
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
assert(twist_deg + lug_deg <= pitch / 2,
       "BAYONET CLEARANCE: twist_deg + lug_deg must fit within HALF the sector \
pitch. The mate's like-radius sectors sit half a pitch away, so free travel is \
pitch/2 - lug_deg, not pitch - lug_deg. The looser form lets the part render \
and gate cleanly while being physically impossible to twist shut.");
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

// Sector cross-sections are swept as ONE polygon each, not unioned from two
// arcs. Two arcs that share an exact radius leave a coincident cylindrical
// surface and CGAL returns a non-watertight mesh — that cost a round.
module sector(pts, ang) { rotate_extrude(angle = ang) polygon(pts); }

/* [Hidden] */
t2      = port_tol / 2;
i_out   = r_mid - t2;             // inner shell outer face
i_in    = ro + t2;                // inner shell bore-side face, PROJECTING half
o_in    = r_mid + t2;             // outer shell inner face
rin     = ri - 2;                 // buried inside the bore; the bore cut removes it
z_tip   = -port_proj;             // our sector tips
z_top   = port_proj + collar_t;   // top of the port zone, inside the tube body
z_seat  = port_proj;              // where the MATE's tips land on our collar
rib_in  = i_out - rib_h;          // how far the rib reaches into the mate's band
g_floor = i_out - rib_h - port_tol;   // groove floor: clears the rib by port_tol

// Bayonet groove cut into one inner sector's outer face:
//   * a narrow axial entry slot (rib_deg wide) running from our tip to the
//     seat — this is the only way in, and it is deliberately much narrower
//     than the sector so there is solid material left to twist under;
//   * a full-width circumferential run at the seat, so the rib retains in
//     EITHER twist direction and no handedness has to be got right.
// Cut oversize by port_tol on every surface — the one fit knob.
module bayonet_groove(a0) {
    t = port_tol;
    rotate([0, 0, a0 - t])                                   // axial entry slot
        sector([[g_floor, z_tip - eps], [i_out + eps, z_tip - eps],
                [i_out + eps, z_seat + t], [g_floor, z_seat + t]],
               rib_deg + 2 * t);
    rotate([0, 0, a0 - t])                                   // circumferential run
        sector([[g_floor, z_seat - rib_w - t], [i_out + eps, z_seat - rib_w - t],
                [i_out + eps, z_seat + t], [g_floor, z_seat + t]],
               lug_deg + 2 * t);
}

// One port face. The tube face sits at z = 0 and the mate's face butts it
// there, so the bore is continuous across the joint — no gap, no step.
//
// Sectors span z_tip..z_top. The half below z = 0 reaches past our own face
// and runs alongside the MATE's tube, so its bore-side face must clear ro by
// the fit tolerance; only the half above z = 0 may reach inward to fuse with
// our own tube. Biting inward along the whole length instead drives the
// sector into the mate's tube OD, and the two parts simply do not go
// together — that was 1645 mm3 of interference.
module nuggs_port() {
    difference() {
        union() {
            // Backing collar: full ring, fused to the tube, and the hard stop
            // the mate's sector tips seat against. Its outer radius stops
            // short of r_out so it never shares a surface with the outer
            // sectors it overlaps.
            translate([0, 0, z_seat])
                difference() {
                    cylinder(r = o_in + 1.0, h = collar_t);
                    translate([0, 0, -eps]) cylinder(r = rin, h = collar_t + 2 * eps);
                }
            // Outer shell sectors — run up into the collar so they fuse
            for (i = [0 : n_lug - 1])
                rotate([0, 0, outer_a(i)])
                    sector([[o_in, z_tip], [r_out, z_tip],
                            [r_out, z_top], [o_in, z_top]], lug_deg);
            // Inner shell sectors — one L-shaped profile: clear of the mate's
            // tube below z = 0, reaching into our own tube above it.
            for (i = [0 : n_lug - 1])
                rotate([0, 0, inner_a(i)])
                    sector([[i_in, z_tip], [i_out, z_tip], [i_out, z_top],
                            [rin, z_top], [rin, 0], [i_in, 0]], lug_deg);
            // Locking rib: a narrow tab at one edge of each outer sector,
            // reaching rib_h into the mate's inner-shell band at the tip.
            for (i = [0 : n_lug - 1])
                rotate([0, 0, outer_a(i)])
                    sector([[rib_in, z_tip], [o_in + bite, z_tip],
                            [o_in + bite, z_tip + rib_w], [rib_in, z_tip + rib_w]],
                           rib_deg);
        }
        for (i = [0 : n_lug - 1]) bayonet_groove(inner_a(i));
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
