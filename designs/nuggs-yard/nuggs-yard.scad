// nuggs-yard — an open-top playpen run for a Syrian hamster: turns,
// branches, a closed circuit and a covered refuge, built from one channel
// cross-section and one lap joint.
//
// The design request and the measurements behind it: issue #73.
// Requirements, decisions and the print-this-first note: NOTES.md.
// All dimensions in millimeters.
//
// Why open-topped: the welfare limits that make an enclosed hamster tube a
// bad idea (length budget, dead air, one-action opening) all follow from
// there being a roof. Take the roof off and they stop applying, which is
// what buys the loops and branches an enclosed run cannot have. The limits
// that are about the ANIMAL rather than the tube -- bore floor, incline,
// chew edges -- are unchanged, and are asserted below.

/* [Part] */
// Which module to render. "assembled" is the preview, not a printable part.
part = "assembled"; // [assembled, straight, curve90, curve45, wye, refuge, coupon]

/* [Animal — welfare floors, not styling] */
// Head-and-body length of YOUR animal (mm). Sets the covered-segment budget.
body_len_mm = 180;
// Minimum inscribed circle of any COVERED segment (mm). Never lower this.
min_covered_bore = 70;
// Minimum internal width of the open run (mm).
min_run_width = 80;

/* [Run cross-section] */
// Internal floor width (mm)
inner_w = 80;
// Internal sidewall height of the open channel (mm). Set by the refuge's
// bore floor, not by the open run — see the covered_bore assert below.
// 46.1 is the analytic minimum at inner_w = 80 and wall = 1.6; 47 keeps a
// little margin so a thicker wall does not silently drop under the floor.
side_h = 47;
// Internal floor-to-wall fillet radius (mm)
fillet_r = 12;

/* [Module sizes] */
// Face-to-face length of a straight (mm)
straight_len = 160;
// Centreline radius of a curve (mm)
curve_r = 80;
// Face-to-face length of the covered refuge (mm)
refuge_len = 160;
// Main-run length of the wye (mm). Kept equal to straight_len so a wye is a
// drop-in replacement for a straight anywhere in a layout -- otherwise a
// circuit containing one simply does not close.
wye_len = 160;
// Branch length of the wye, junction to port (mm)
wye_branch = 130;
// Distance from the wye's -X port to the branch junction (mm). Set well back
// from wye_len so the crotch wedge has room to thicken -- see wye_end_wedge.
wye_junction = 50;
// Branch angle of the wye (deg)
wye_ang = 45;
// Length of each coupon stub (mm)
coupon_len = 45;

/* [Joint] */
// Skirt overlap onto the neighbouring module (mm)
joint_lap = 12;
// Skirt height up the sidewall (mm)
joint_h = 25;
// Skirt plate thickness (mm)
joint_t = 2.4;
// THE fit knob: radial clearance between skirt and neighbour wall (mm).
// Tune on the coupon in +/-0.05 steps before printing anything else.
joint_tol = 0.30;

/* [Print settings] */
// Shell thickness (mm) — 1.6 is 4 perimeters at a 0.4 mm nozzle
wall = 1.6;
// Horizontal inset of the bed-edge chamfer (mm); it rises cham_v = 1.3x this
bottom_chamfer = 0.8;

// How far a cavity sweep overruns the shell at a free face (mm). Exists so no
// port face is a coplanar face pair -- see sweep_straight. Not a fit knob.
cav_over = 0.6;

/* [Quality] */
// Iterating: 32. Production: 96+.
$fn = 96;

// ---------------------------------------------------------------------------
// Derived values and welfare asserts
// ---------------------------------------------------------------------------

ow = inner_w + 2 * wall;              // outer width of the channel shell

// Bed-edge chamfer rises slightly faster than it insets, so the chamfer face
// sits a few degrees off vertical-45 rather than exactly on it. A true 45-deg
// chamfer lands on printcheck's overhang threshold and books the whole strip
// as unsupported area (335 mm² on a straight, 8 points) for a surface that
// prints perfectly well. Steeper is also strictly more self-supporting.
cham_v = bottom_chamfer * 1.3;
peak_i = side_h + inner_w / 2;        // inner apex of the 45-deg gable roof
peak_o = peak_i + wall * sqrt(2);     // outer apex

// Largest circle that fits a gable-roofed trough of width inner_w whose walls
// are side_h tall and whose roof rises at 45 deg.
//
// The `- wall` is load-bearing and was missing at first: the trough FLOOR sits
// at z = wall, not z = 0, so the usable height is peak_i - wall. Without it
// this read 70.42 mm and the assert passed while the exported mesh measured
// 69.09 -- under the welfare floor, silently. That is the whole reason
// NOTES.md requires this number to be re-measured off the STL rather than
// trusted from here.
covered_bore = 2 * (peak_i - wall) / (1 + sqrt(2));

assert(inner_w >= min_run_width,
       str("Y4: run width ", inner_w, " mm is under the ", min_run_width,
           " mm floor. Widen inner_w."));

assert(covered_bore >= min_covered_bore,
       str("Y1: a covered segment would have a ", covered_bore,
           " mm inscribed circle, under the ", min_covered_bore,
           " mm floor. Raise side_h (46.1 mm is the minimum at inner_w = 80,",
           " wall = 1.6)."));

assert(refuge_len <= 2 * body_len_mm,
       str("Y2: refuge_len ", refuge_len, " mm exceeds 2 x body length (",
           2 * body_len_mm, " mm). Shorten it or measure a longer animal."));

assert(wall >= 1.2,
       str("wall ", wall, " mm is under 3 perimeters at a 0.4 mm nozzle."));

// wye_ang sits in a trig denominator below (sin in wedge_tip_x, tan in
// wye_end_wedge), so it has to be bounded before it is used, not after: at 0
// the division is by zero and at 90 tan is infinite, which would sail through
// the crotch assert rather than trip it. The practical envelope is narrower
// than the mathematical one anyway — under 15° the branch is nearly parallel
// to the main run and the part grows without bound, over 75° it is a tee with
// no acute crotch to protect.
assert(wye_ang >= 15 && wye_ang <= 75,
       str("wye_ang ", wye_ang, " deg is outside 15-75. Below/above that the ",
           "crotch derivation divides by ~0 or returns an infinite wedge."));

// Where the branch's near edge crosses the main trough's edge, and how thick
// the crotch wedge has grown by the time the main run ends.
wedge_tip_x = wye_junction + (inner_w / 2) *
              (sin(wye_ang) + cos(wye_ang) * (1 + cos(wye_ang)) / sin(wye_ang));
wye_end_wedge = (wye_len - wedge_tip_x) * tan(wye_ang);

assert(wye_end_wedge >= 8,
       str("Wye crotch reaches the port face only ", wye_end_wedge,
           " mm thick (need >= 8). Move wye_junction back or lengthen wye_len."));

assert(wye_junction > joint_lap + wall && wye_junction < wye_len,
       "wye_junction must sit between the -X port skirt and the +X port.");

// A circuit swaps one straight for the refuge, so the two must be the same
// face-to-face length or the loop does not close -- the same requirement
// wye_len carries. Asserted rather than assumed: circuit() used to pass its
// own run length into refuge(), which silently ignored refuge_len and would
// have let the assembled preview disagree with the part you actually print.
assert(refuge_len == straight_len,
       str("refuge_len ", refuge_len, " must equal straight_len ", straight_len,
           ": a circuit substitutes the refuge for one straight."));

assert(wye_len == straight_len,
       str("wye_len ", wye_len, " must equal straight_len ", straight_len,
           ": a wye is a drop-in replacement for one straight."));

// cav_over is what keeps port faces off each other's planes. At 0 the cavity
// goes back to running flush with the shell and the non-manifold wye returns
// -- silently, because CGAL still calls it watertight. It is not a tuning
// knob and must not be zeroed.
assert(cav_over > 0,
       str("cav_over must be > 0: at 0 every port face is a coplanar face ",
           "pair again, which renders watertight under CGAL and non-manifold ",
           "under Manifold. See sweep_straight."));

// sweep_curve revolves the profile about x = 0, and rotate_extrude requires
// the whole profile to stay on one side of that axis. The profile spans
// +/- ow/2 about the centreline radius, so the inner edge is at r - ow/2.
assert(curve_r > ow / 2,
       str("curve_r ", curve_r, " must exceed ow/2 = ", ow / 2,
           ": the swept profile would cross the rotation axis."));

assert(joint_h <= side_h,
       "Joint skirt must not stand proud of the sidewall (chew edge, Y5).");

assert(fillet_r < inner_w / 2 && fillet_r < side_h,
       "fillet_r must fit inside the trough cross-section.");

// ---------------------------------------------------------------------------
// 2D cross-sections
//
// Built as separate shell and cavity profiles so that junction modules (the
// wye) can union the shells and THEN subtract the union of the cavities --
// which is what stops an internal wall being left standing across the crotch.
// ---------------------------------------------------------------------------

// Rounded-bottom trough cavity, open well above the shell. The cavity must
// run ABOVE the outer shell: a cavity that stops level with it leaves
// coincident horizontal faces, which render as naked edges and a CRITICAL
// non-watertight verdict rather than as an open top.
module trough_cavity_2d(h) {
    offset(r = fillet_r) offset(r = -fillet_r)
        translate([-inner_w / 2, 0]) square([inner_w, h]);
}

// Open channel: flat outside bottom, 45-deg chamfered bed edges. Rounding
// the OUTER profile instead lifts the part onto a curved underside and
// turns a 1% overhang into 12%.
module channel_shell_2d() {
    oh = side_h + wall;
    polygon([[-ow / 2 + bottom_chamfer, 0], [ow / 2 - bottom_chamfer, 0],
             [ow / 2, cham_v], [ow / 2, oh],
             [-ow / 2, oh], [-ow / 2, cham_v]]);
}

module channel_cavity_2d() {
    translate([0, wall]) trough_cavity_2d(side_h + wall + 10);
}

// Covered refuge: the same trough with a 45-deg gable roof. A gable rather
// than an arch because both slopes are then self-supporting; an arch's
// crown is a horizontal overhang.
module refuge_shell_2d() {
    polygon([[-ow / 2 + bottom_chamfer, 0], [ow / 2 - bottom_chamfer, 0],
             [ow / 2, cham_v], [ow / 2, side_h],
             [0, peak_o], [-ow / 2, side_h], [-ow / 2, cham_v]]);
}

module refuge_cavity_2d() {
    translate([0, wall]) {
        // rounded floor corners, topped out exactly at the gable eaves --
        // running it a wall higher leaves a 1.6 mm horizontal ledge inside
        // the roof for the animal's back to meet
        trough_cavity_2d(side_h - wall);
        // sharp gable above, overlapping the rounded band so the eaves and
        // the apex stay crisp (the offset pair would round the apex too,
        // which would quietly cost ~5 mm of inscribed circle)
        polygon([[-inner_w / 2, side_h - fillet_r],
                 [inner_w / 2, side_h - fillet_r],
                 [inner_w / 2, side_h - wall],
                 [0, peak_i - wall], [-inner_w / 2, side_h - wall]]);
    }
}

// ---------------------------------------------------------------------------
// Sweeps
//
// Canonical frame: the run travels along +X from x = 0, width in Y, floor on
// z = 0. rotate([90,0,90]) maps profile-X to Y and profile-Y to Z.
// ---------------------------------------------------------------------------

// A cavity profile (1 or 3) is swept PAST both ends of the shell rather than
// flush with them.
//
// The cavity already had to run above the shell so the open top isn't a pair
// of coincident faces; the sweep ends need the same treatment and originally
// didn't get it. Flush ends made every port face a coplanar face pair. CGAL
// resolves those exactly and reported watertight; CI's Manifold backend did
// not, and returned edges shared by more than two triangles on the wye
// (75/100 NOT PRINTABLE, 614 triangles against CGAL's 540).
//
// It surfaced on the wye alone because a flush end is only *exactly*
// coincident when the end face is axis-aligned. The branch is rotated 45°, so
// its vertices land on irrationals and the two faces coincide only to within
// floating point — which is worse for a boolean than coinciding exactly. The
// non-manifold edges clustered at the branch's far-end +Y corner, every one
// inside the floor-fillet band. Overrunning the ends removes the coincidence
// for every module instead of special-casing the one that failed.
function cavity_profile(p) = (p == 1 || p == 3);

module sweep_straight(len, profile_2d = 0) {
    o = cavity_profile(profile_2d) ? cav_over : 0;
    translate([-o, 0, 0]) rotate([90, 0, 90]) linear_extrude(len + 2 * o)
        if (profile_2d == 0) channel_shell_2d();
        else if (profile_2d == 1) channel_cavity_2d();
        else if (profile_2d == 2) refuge_shell_2d();
        else refuge_cavity_2d();
}

// A turn in PLAN view. rotate_extrude already maps profile-X to radius and
// profile-Y to Z, so the cross-section never tilts out of the print plane --
// which is why a 90-deg turn here is one part at 100/100, unlike the 45-deg
// ceiling that applies to a bend in a vertically-printed bore (issue #34).
module sweep_curve(ang, r, profile_2d = 0) {
    // same end overrun as sweep_straight, expressed as the angle that
    // subtends cav_over at the centreline radius
    d = cavity_profile(profile_2d) ? cav_over * 180 / (PI * r) : 0;
    rotate([0, 0, -d]) rotate_extrude(angle = ang + 2 * d) translate([r, 0])
        if (profile_2d == 0) channel_shell_2d();
        else channel_cavity_2d();
}

// ---------------------------------------------------------------------------
// The joint
//
// A lap: two flat skirts on the OUTSIDE of the sidewalls at a module's -X
// end, overlapping the neighbour's sidewalls. Everything is outboard, so
// nothing enters the walking surface (Y5), and because the skirts never pass
// under the neighbour's floor a module lifts straight out of an assembled
// run for cleaning instead of having to be slid along it.
//
// Each module carries skirts at one end and a bare face at the other, so any
// module mates with any other as long as they all face the same way round
// the circuit.
// ---------------------------------------------------------------------------

// Port frame: face at the origin, this module's body extending in -X, the
// neighbour in +X. The rooted half must therefore sit at x < 0 (on our own
// wall, closing the tolerance gap so the skirt is one body with the shell)
// and the overlapping half at x > 0 (standing off the neighbour by
// joint_tol). Reversing the two is silent in OpenSCAD and shows up only as
// a second disconnected shell in the printcheck body count.
// Both halves interpenetrate rather than meeting face to face: solids that
// merely share a coincident face stay separate volumes through CGAL, which
// surfaces as a rising body count in printcheck and a skirt that would drop
// off the plate. The rooted half bites wall/2 into the sidewall, and the
// overlapping half starts half a lap back inside the rooted one.
// One extruded profile per side, not a pair of overlapping boxes. Two boxes
// sharing a top face give coplanar geometry and a non-watertight mesh; a
// single stepped polygon has no internal faces to be coincident. The rooted
// run (x < 0) bites wall/2 into this module's sidewall so the skirt is
// genuinely one solid with the shell rather than merely touching it; the
// overlapping run (x > 0) stands off the neighbour's wall by joint_tol.
module joint_skirt() {
    y_in  = ow / 2 - wall / 2;          // bitten into our own wall
    y_off = ow / 2 + joint_tol;         // clears the neighbour's wall
    y_out = ow / 2 + joint_tol + joint_t;
    for (s = [1, -1]) scale([1, s, 1])
        linear_extrude(joint_h)
            polygon([[-joint_lap, y_in], [0, y_in], [0, y_off],
                     [joint_lap, y_off], [joint_lap, y_out],
                     [-joint_lap, y_out]]);
}

// Place a skirt at a port. The port frame has its face at the origin with
// the module body extending in -X.
module port_skirt(pos, rot_z) {
    translate(pos) rotate([0, 0, rot_z]) joint_skirt();
}

// ---------------------------------------------------------------------------
// Printable modules
// ---------------------------------------------------------------------------

module straight(len = straight_len) {
    difference() {
        union() {
            sweep_straight(len, 0);
            port_skirt([0, 0, 0], 180);   // skirts at the -X end
        }
        sweep_straight(len, 1);
    }
}

module refuge(len = refuge_len) {
    difference() {
        union() {
            sweep_straight(len, 2);
            port_skirt([0, 0, 0], 180);
        }
        sweep_straight(len, 3);
    }
}

module curve(ang = 90, r = curve_r) {
    difference() {
        union() {
            sweep_curve(ang, r, 0);
            // The start face sits at (r,0,0) with the body sweeping toward +Y,
            // so the port frame's -X (its "into the body" direction) must map
            // to +Y — i.e. rotate by -90, matching chain_curve's derivation.
            // At +90 the lap is inverted, and it does not merely look wrong:
            // the rooted half — which carries no clearance because it is meant
            // to fuse into our OWN wall — lands in the band the neighbour's
            // wall has to occupy, filling the joint_tol gap with solid. A
            // curve then interferes with whatever it joins by a full wall
            // thickness and the run cannot be assembled.
            //
            // Nothing in the render says so: it is one watertight body at
            // 100/100 either way. It was caught by sampling the tolerance band
            // for material (inverted: occupied; correct: clear), which is the
            // only check here that looks at the joint as a FIT rather than as
            // a mesh.
            port_skirt([r, 0, 0], -90);
        }
        sweep_curve(ang, r, 1);
    }
}

// Symmetric-ish branch: main run along +X, branch leaving the junction at
// wye_ang. Shells are unioned and the cavities subtracted afterwards, so no
// sidewall is left standing across the crotch.
//
// The crotch wedge -- the shell between the two troughs on the acute side --
// begins where the branch's near edge crosses the main trough's edge, at
// wedge_tip_x, and thickens from there at tan(wye_ang). Put that crossing too
// close to the main run's end and the wedge reaches the port face as a
// feather edge: PrusaSlicer calls the part "Thin fragile part", and a feather
// edge on something a hamster shares a pen with is a chew-initiation site
// (Y5). The cure is geometric, not a boolean patch -- give the wedge enough
// run to thicken by putting the junction far enough back. wye_end_wedge below
// is the thickness it actually reaches, and it is asserted, so moving the
// junction or the branch angle cannot quietly reintroduce the sliver.
module wye() {
    difference() {
        union() {
            sweep_straight(wye_len, 0);
            translate([wye_junction, 0, 0]) rotate([0, 0, wye_ang])
                sweep_straight(wye_branch, 0);
            port_skirt([0, 0, 0], 180);
        }
        sweep_straight(wye_len, 1);
        translate([wye_junction, 0, 0]) rotate([0, 0, wye_ang])
            sweep_straight(wye_branch, 1);
    }
}

// Two stubs, printed side by side, to tune joint_tol before committing to a
// full module. Mate them by hand: the skirted end slides onto the bare one.
module coupon() {
    straight(coupon_len);
    translate([0, ow + joint_lap + 25, 0]) straight(coupon_len);
}

// ---------------------------------------------------------------------------
// Assembled preview — a closed circuit: 4 curves + 4 straights, no dead ends
// ---------------------------------------------------------------------------

// A curve sweeps counter-clockwise from the +X axis, so its entry face sits
// at (r,0) heading +Y and its exit at (0,r) heading -X. Re-frame it into the
// chain convention every module shares -- entry at the origin heading +X --
// so modules can simply be laid end to end. Exit then lands at (r,r) heading
// +Y, i.e. a left turn.
module chain_curve(ang = 90, r = curve_r) {
    translate([0, r, 0]) rotate([0, 0, -90]) curve(ang, r);
}

// Lay straight -> left curve, four times, and the run closes on itself: a
// circuit has no terminus at all, which is the topology Y6 wants. Each
// module's skirted (-X) end meets the previous module's bare end.
// No length parameter: every module in the loop is straight_len face-to-face
// (asserted above for both the refuge and the wye), so an overridable run
// could only ever disagree with them and leave the circuit open.
module circuit(i = 0) {
    run = straight_len;
    if (i < 4) {
        // One side of the loop is the covered refuge: the hide is ON the
        // route, so he passes through it rather than detouring to it.
        // refuge() is called on its own length, not the circuit's, so the
        // assembled preview can never disagree with the standalone part --
        // the assert above is what keeps the loop closed.
        if (i == 3) refuge(); else straight(run);
        translate([run, 0, 0]) {
            chain_curve(90, curve_r);
            translate([curve_r, curve_r, 0]) rotate([0, 0, 90])
                circuit(i + 1);
        }
    }
}

module assembled() {
    circuit();
}

// ---------------------------------------------------------------------------

if      (part == "assembled") assembled();
else if (part == "straight")  straight();
else if (part == "curve90")   curve(90, curve_r);
else if (part == "curve45")   curve(45, curve_r);
else if (part == "wye")       wye();
else if (part == "refuge")    refuge();
else if (part == "coupon")    coupon();
else assert(false, str("unknown part: ", part));
