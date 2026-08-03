// N.U.G.G.S. — Nugget's Universal Genderless Gallery Standard.
// A short, straight, wide-bore tunnel bridging two hamster enclosures.
// Requirements, welfare sources and decisions: see NOTES.md next to this file.
// All dimensions in millimeters.
//
// The genderless quarter-turn port is NOT defined here any more. It is
// lib/nuggs-coupling.scad — one interlock standard shared by every module in
// the system (PM.md N10), which is precisely why it cannot live inside one
// design's .scad file and be copied by the next one. This design is a CONSUMER
// of that standard: it builds one cfg with nuggs_cfg() and hands it around.
use <nuggs-coupling.scad>

/* [What to render] */
// assembled = review preview; the rest are printable parts
part = "assembled";  // [assembled, straight, bulkhead_in, bulkhead_out, coupon, cutaway]

/* [The NUGGS standard - change these and nothing you already printed fits] */
// Revision of the PORT STANDARD in lib/nuggs-coupling.scad that this design
// builds to, engraved on every module whose marked face is out of the animal's
// reach (straight, bulkhead_out - see the "Revision mark" section). It names
// the STANDARD, not this design: a printed module is identifiable years later
// by what it MATES with, and every family in the system shares one port
// (PM.md N10). Bump only on a breaking change to the port itself - a
// non-breaking change to the straight does not touch it.
NUGGS_PORT_REV = 1;
// Internal bore (mm) - the headline number. Asserted >= min_bore_mm by the lib
bore_d = 80.0;
// Tube shell thickness (mm)
wall = 2.4;
// Radial depth of the coupling ring beyond the tube OD (mm)
lug_r = 6.0;
// Axial projection of the coupling sectors past the tube face (mm)
port_proj = 10.0;
// Coupling sectors per face (3 = kinematically determinate)
n_lug = 3;
// Angular width of each sector (deg). Asserted lug_deg + twist_deg <= pitch/2.
// Wider is better for bed adhesion: the part prints standing on these tips,
// so lug_deg sets the first-layer area and how much of the circumference is
// anchored. 40 leaves 6 deg of headroom for twist_deg to grow; the ceiling
// here is 46.
lug_deg = 40;
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
// Overlap used to fuse the ribs into the outer sectors (mm). Never zero: a
// zero-volume "kiss" contact leaves CGAL counting them as separate bodies.
bite = 0.8;

/* [Fit & tolerances] */
// The one knob. Uniform clearance on every coupling surface (mm).
// Tune on the coupon in +/-0.05 steps. Asserted 0.10-0.60 by the lib
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
// The bore floor itself is asserted inside nuggs_cfg().
min_bore_mm = 70;
// Syrian head-and-body length (mm). MEASURE YOUR ANIMAL and change this.
// The per-run length limit is 2 x this - see the RUN LENGTH assert below.
body_len_mm = 180;

/* [Print settings] */
// Nozzle diameter (mm) - feeds the wall and web guards in the lib
nozzle = 0.4;
// Bed-contact edge break (mm)
bottom_chamfer = 0.8;
// House angle for every chamfer and cone (deg). Not 45 - see NOTES.md
chamfer_ang = 50;

/* [Revision mark] */
// Cap height of the engraved mark (mm). 0 leaves every part unmarked.
mark_h = 5.0;
// Engrave depth (mm). Recessed, never proud - a raised character is exactly
// the chew-initiation edge PM.md N6 forbids. Asserted to leave 3 perimeters.
mark_d = 0.6;
// Per-character advance along the marked surface (mm). Fixed pitch, not the
// font's own metrics - OpenSCAD cannot report them, and each character has to
// be placed on its own tangent anyway. Wide enough that O/N/W do not touch.
mark_adv = 4.8;

/* [Quality] */
// This design's own quality preset. Iterating: $fa=6/$fs=1.5.
// Production: $fa=2/$fs=0.5. NOTE it does not reach the coupling: the library
// pins its own $fa/$fs inside every geometry module body, deliberately, so the
// realised fit cannot move with a consumer's quality preset. Raising these
// changes the tube, the flanges and the mark, never the joint.
$fa = 3;
$fs = 0.8;

/* [Hidden] */
eps = 0.01;

// ---------------------------------------------------------------------------
// The coupling configuration
//
// ONE cfg, built once, handed to every port call. Every coupling guard — the
// bore floor, the wall, the bayonet clearance and travel, the port_tol band,
// the web under the groove, the circumferential-clearance regression pins —
// fires inside nuggs_cfg(), so they are not restated here. Restated
// derivations drift, which is the failure the library exists to prevent.
// ---------------------------------------------------------------------------
cfg = nuggs_cfg(bore_d    = bore_d,    wall      = wall,      lug_r    = lug_r,
                port_proj = port_proj, collar_t  = collar_t,  n_lug    = n_lug,
                lug_deg   = lug_deg,   rib_h     = rib_h,     rib_w    = rib_w,
                rib_deg   = rib_deg,   twist_deg = twist_deg, bite     = bite,
                port_tol  = port_tol,  eps       = eps,       nozzle   = nozzle,
                min_bore  = min_bore_mm);

// The handful of contract values this design actually reaches for. Everything
// else the port needs stays inside the library.
ri    = nuggs_ri(cfg);      // bore radius
ro    = nuggs_ro(cfg);      // tube outer radius — the marked surface
r_out = nuggs_r_out(cfg);   // coupling ring OD — the coupon's spacing
z_top = nuggs_z_top(cfg);   // top of the port zone; the mark must clear it

// Enclosed bore of the Bin Bridge, end to end. Per end, FOUR things enclose
// bore, not two: bulkhead_in's flange plate, its spigot through the wall,
// bulkhead_out's flange plate, and the port projection that carries the joint.
// `-nuggs_z_tip(cfg)` IS port_proj, read from the library rather than restated,
// so a change to the port's projection moves this number.
//
// The two flange plates were missing until PR #78 review (CodeRabbit).
// `clamp_flange()` bores its plate at `ri` over the full thickness, so a plate
// is bore the animal walks through — it is not a mounting detail outside the
// run. Omitting all four cost 4 * bh_flange_t = 16 mm, so this assert has
// UNDER-REPORTED the enclosed run since v1: 230 mm against a true 246. It
// still passes at the defaults, which is exactly why nothing caught it, and
// under-counting is the one direction a welfare limit must never be wrong in.
run_len   = straight_len
            + 2 * (2 * bh_flange_t + bh_spigot_len - nuggs_z_tip(cfg));
run_limit = 2 * body_len_mm;

echo(str("nuggs: port standard R", NUGGS_PORT_REV, " at bore ", bore_d,
         " mm, port_tol ", port_tol, " mm -> web ", nuggs_web(cfg),
         " mm, bearing area ", nuggs_bearing_area(cfg),
         " mm2, clockings ", nuggs_clockings(cfg), " deg"));
echo(str("nuggs: run = ", run_len, " mm of continuously enclosed bore ",
         "(straight ", straight_len, " + 2 bulkhead throats) against the ",
         run_limit, " mm per-run limit"));

// ---------------------------------------------------------------------------
// Welfare and printability asserts. These fail the render, not a lint pass.
//
// The coupling's own guards are NOT here — they live in nuggs_cfg() above, so
// that a second consumer of the standard inherits them instead of copying
// them. What is left is what belongs to THIS design: its bed, its wall
// crossing, its mark, and the one welfare rule that is about an assembled RUN
// rather than about a port.
// ---------------------------------------------------------------------------
assert(straight_len + 2 * port_proj <= 240,
       "BED: the straight plus both port projections must fit a 256 mm bed \
printed upright (240 mm, leaving margin).");

// PM.md N2, NOTES.md §5.2. The message has to carry the whole rule, because
// this is the one place a person changing straight_len will read it.
assert(run_len <= run_limit, str(
    "NUGGS RUN LENGTH: this run encloses ", run_len,
    " mm of bore against the ", run_limit, " mm limit (2 x body_len_mm = ",
    body_len_mm, " mm).",
    " A RUN is the maximal chain of CONTINUOUSLY ENCLOSED bore between two",
    " BREAKS, and a BREAK is only one of: an open module (a longitudinal",
    " window >= 180 deg), a port discharging into a ventilated enclosure, or a",
    " turnaround node of clear internal width >= body_len_mm.",
    " A BEND IS NOT A BREAK. A JUNCTION AT BORE DIAMETER IS NOT A BREAK.",
    " A COUPLING IS NOT A BREAK - two straights twisted together are ONE run,",
    " and because every NUGGS face mates with every other they will click",
    " together and feel right. A top hatch resets RETRIEVAL, not REVERSING.",
    " SOURCE: Deutscher Tierschutzbund position paper 'Tierschutzwidriges",
    " Zubehoer' - NOT TVT Merkblatt 62, which this project cited for two",
    " rounds and which appears to publish no length limit at all. There it is",
    " ONE LIMB OF A CONJUNCTIVE product test: a tube is acceptable only if it",
    " is at most twice body length AND adequately ventilated AND sold with",
    " instructions against misuse. Quoting the length limb alone quotes it out",
    " of context.",
    " WHY THE 2x MATTERS HERE, AND THIS PART IS ENGINEERING JUDGEMENT, NOT",
    " LITERATURE: the animal cannot turn around in a ", bore_d,
    " mm bore, so he leaves by whichever end is nearer and worst-case",
    " unassisted reverse travel is HALF the run; ", run_limit,
    " mm bounds that at one body length. No source measures how far a hamster",
    " will reverse. A run that is NOT hand-releasable in one action is capped",
    " at min(", run_limit, ", 300) = ", min(run_limit, 300), " mm instead —",
    " the 300 is an adult hand's reach into an ", bore_d, " mm bore, ~150 mm",
    " from each end, and it is a separate bound rather than a smaller one (at",
    " body_len_mm below 150 the 2x limit is already the stricter of the two).",
    " Every NUGGS joint IS hand-releasable (PM.md N5), so this run gets the",
    " full 2x. Shorten straight_len, break the run with a node or an open",
    " module, or measure a longer animal."));

assert(wall_hole_d >= bore_d + 2 * bh_spigot_wall + 1.0,
       "WALL HOLE: the hole must clear the full-bore spigot - the bore is never \
necked down at the wall crossing.");
assert(mark_d <= wall - 3 * nozzle,
       "MARK DEPTH: the revision engraving must leave >= 3 perimeters of tube \
shell behind it. Reduce mark_d or thicken wall.");

// ---------------------------------------------------------------------------
// Primitives
// ---------------------------------------------------------------------------

// Plain tube section. The design's own body, not the coupling's — the port's
// sectors fuse to this, which is why it is full-round for the whole port zone.
module tube(l, r_i = ri, r_o = ro) {
    difference() {
        cylinder(r = r_o, h = l);
        translate([0, 0, -eps]) cylinder(r = r_i, h = l + 2 * eps);
    }
}

// ---------------------------------------------------------------------------
// Revision mark
//
// The port revision has to be legible on a printed part or the standard is not
// a standard, just a number in a file — and the one composition hazard this
// design admits (assembling past the per-run length limit) is a rule only the
// part itself can carry to whoever is holding it. Both were claimed and
// neither existed until issue #56 finding 4.
//
// Two rules govern where it may go:
//   * ENGRAVED, never proud. A raised character is a chew-initiation edge,
//     which PM.md N6 forbids outright.
//   * Only on a face that looks at the ROOM. The straight's outer tube wall
//     runs between the two enclosures and the bulkhead_out flange rim sits
//     outside the wall, so neither is reachable from the bore or from inside
//     the cage. bulkhead_in gets no mark at all: every face it has is either
//     inside the enclosure with the animal or buried in the wall hole.
//
// WHAT THE RULE LINES SAY, and why they changed. Round 4 engraved "ONE
// STRAIGHT PER RUN". That is a conclusion, not the rule, and it is only true
// at these parameters: it hardcodes straight_len and body_len_mm — neither of
// which is on the part — into a permanent mark. At straight_len = 100 two
// straights are a legal 270 mm run and the part lies; at body_len_mm = 120 one
// straight is already illegal and the part lies the other way. So the mark now
// carries the LIMIT (derived, so it tracks body_len_mm) and the clause the
// charter says must be more prominent than the number: a coupling does not
// reset the count. Both stay true under every parameter set that renders.
//
// Cut one character at a time, each on its own tangent plane. The longest line
// spans 96 mm of arc (129.7 deg at r = 42.4), and one flat cut across that has
// a sagitta of 24.5 mm — ten times the wall. Per character it is 0.068 mm.
// ---------------------------------------------------------------------------
function mark_rev() = str("NUGGS PORT R", NUGGS_PORT_REV);
// The per-run rule, in the two lines a person holding the part needs. Derived
// from run_limit so it can never disagree with the assert above.
function mark_rule() = [str("MAX RUN ", run_limit, "MM"), "COUPLINGS DONT RESET"];

// Text wrapped around the outside of a cylinder of radius `r`, centred on
// angle `a0` at height `z`, reading left to right seen from outside. Returns
// the cutting solid — always subtract it, never union it.
module wrap_text(s, r, z, a0 = 0, h = mark_h, depth = mark_d, adv = mark_adv) {
    step = adv / r * 180 / PI;                 // arc advance -> degrees
    for (i = [0 : len(s) - 1])
        rotate([0, 0, a0 + (i - (len(s) - 1) / 2) * step])
            translate([r - depth, 0, z])
                rotate([90, 0, 90])            // text plane -> tangent plane
                    linear_extrude(depth + eps)
                        text(s[i], size = h, halign = "center",
                             valign = "center");
}

// Revision + per-run rule on the straight's outer wall, at mid-length. Three
// lines at 1.6 x cap height, so the block is 3.2 * mark_h tall; it is cut only
// when there is that much clear tube between the two port zones, plus a cap
// height of margin. A 25 mm coupon stub is port zone end to end, and the
// coupon must stay a fit coupon.
module mark_straight(l) {
    lines = concat([mark_rev()], mark_rule());
    span  = (len(lines) - 1) * mark_h * 1.6;
    if (mark_h > 0 && l - 2 * z_top >= span + 2 * mark_h)
        for (i = [0 : len(lines) - 1])
            wrap_text(lines[i], ro, l / 2 + span / 2 - i * mark_h * 1.6);
}

// Revision on the outer flange rim — 4 mm of face, so it carries the
// revision only. The rule belongs on the straight, which is the part the
// rule is about.
module mark_flange_rim() {
    if (mark_h > 0)
        wrap_text(mark_rev(), bh_flange_d / 2, bh_flange_t / 2,
                  h = mark_h * 0.6, adv = mark_adv * 0.6);
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
//
// Every nuggs_port() call below is followed by a nuggs_bore_cut() over the
// port's whole z extent. That is not tidiness: the port is deliberately NOT
// bore-clean — its collar and the anchoring half of its inner sectors reach
// inboard of ri to fuse with the tube — and forgetting the cut yields a
// watertight, sliceable, gate-passing part with 2 mm of plastic standing in
// the bore. See the library header.
// ---------------------------------------------------------------------------

// The straight run: tube with an identical genderless port at each end. One
// bore cut serves both ports, through the whole part.
module nuggs_straight(l = straight_len) {
    difference() {
        union() {
            tube(l);
            nuggs_port(cfg);                                // z = 0 end
            translate([0, 0, l]) mirror([0, 0, 1]) nuggs_port(cfg);
        }
        nuggs_bore_cut(cfg, -port_proj - 2, l + port_proj + 2);
        translate([0, 0, -port_proj]) bore_lead(0.001, 1);
        translate([0, 0, l + port_proj]) mirror([0, 0, 1]) bore_lead(0.001, 1);
        mark_straight(l);
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

// Inner half: flange inside the enclosure and a full-bore spigot through the
// wall. Deliberately NO coupling port.
//
// It carried one until issue #56 finding 3: `mirror([0,0,1]) nuggs_port()`
// put 14 150 mm3 of sector tips, groove mouths and proud rib tabs 13 mm INTO
// the enclosure, at bedding height, reaching r = 48.4. Nothing mates with it —
// in the Bin Bridge the straight couples to bulkhead_out on the far side of
// the wall, `assembled()` never instantiates this part, and the README has
// always described it as "inner flange + full-bore spigot". It could only ever
// have served an in-enclosure module, and PM.md puts any in-cage configuration
// in Never scope. So it was unreachable geometry that failed N6 in the one
// place the animal actually lives. Removed; reasoning in NOTES.md.
module nuggs_bulkhead_in() {
    difference() {
        union() {
            clamp_flange(bh_flange_t);
            // spigot passes through the enclosure wall, bore never necked
            translate([0, 0, bh_flange_t])
                tube(bh_spigot_len, ri, ri + bh_spigot_wall);
        }
        nuggs_bore_cut(cfg, -eps, bh_flange_t + bh_spigot_len + eps);
        // Edge break on the enclosure-side bore mouth. With the port gone this
        // face IS the mouth the animal enters, so it is the one that must never
        // present a lip to a claw or a loaded pouch (N6). It only ever widens
        // the bore, so N1 is untouched.
        bore_lead(-0.001, 1);
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
            // The mirror-and-lift is spelled out at the call site on purpose —
            // the library refuses to hide it behind a flag.
            translate([0, 0, port_proj + collar_t]) mirror([0, 0, 1]) nuggs_port(cfg);
        }
        // counterbore that receives the inner half's spigot. NOT a bore cut:
        // it is wider than the bore and stops half way through the flange.
        translate([0, 0, -eps])
            cylinder(r = ri + bh_spigot_wall + port_tol, h = bh_flange_t / 2);
        nuggs_bore_cut(cfg, -eps, 2 * port_proj + collar_t + eps);
        translate([0, 0, 2 * port_proj + collar_t]) mirror([0, 0, 1]) bore_lead(0.001, 1);
        // Revision on the flange rim: outside the enclosure wall, in the room.
        mark_flange_rim();
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
