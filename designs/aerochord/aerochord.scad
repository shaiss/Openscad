// aerochord — a print-in-place polyphonic fipple vessel: one breath sounds a
// whole chord. A single mouthpiece feeds a shared plenum that splits into N
// parallel internal windways, each with its own fipple (flue + labium) voicing
// an independent closed-pipe resonator. The resonator lengths are SOLVED from
// pipe acoustics so the N pitches land on a just-intonation chord.
//
// Requirements, acoustic derivation and honest caveats: see NOTES.md.
// All dimensions in millimeters. Prints as ONE piece, standing on its base,
// no supports (see "Print orientation" in NOTES.md).

use <printability.scad>       // repo FDM helpers (OPENSCADPATH="$PWD/lib:$PWD")

/* [What to render] */
// solid = the printable deliverable (what CI gates and you slice).
// cutaway = a preview slice that opens the internal air path for the README;
//           it is NOT printable and is never gated.
show = "solid";  // [solid, cutaway]

/* [Chord] */
// Root frequency of the lowest voice (Hz). 1046.5 = C6. Lower roots make
// taller, floppier tubes; higher roots make a shriller, sturdier comb.
root_freq = 1046.5;
// Just-intonation ratios of each voice to the root, one entry per voice.
// [1, 5/4, 3/2] = a major triad. Try [1, 6/5, 3/2] for minor, or add a
// fourth voice [1, 5/4, 3/2, 2] for a root + octave.
chord_ratios = [1, 5/4, 3/2];
// Multiplies every solved resonator length. Leave at 1.0 for nominal tuning;
// a physical print needs a per-printer tweak (see NOTES.md "Print this
// first"). >1 lowers all pitches together, <1 raises them.
tune = 1.0;

/* [Acoustics] */
// Speed of sound in air (mm/s) at ~20 C. Rises ~0.6 m/s per C, so a warm
// breath sharpens the pitch slightly — fold that into `tune` when you tune.
c_sound = 343000;
// Open-window end correction (mm): the extra effective air length the mouth
// adds beyond the physical labium. It joins the conical cap (r_bore) to form
// the lumped `end_corr` subtracted from every tube. Same for every voice, so
// leaving it out shifts the chord's intervals (default ratios drift to
// ~1.244/1.487 instead of 1.25/1.5). ~0.3–0.6 x bore radius is the usual range;
// calibrate against a physical print. Default 2 mm ≈ 0.4 x the 5 mm bore radius.
window_corr = 2;

/* [Resonator] */
// Bore diameter of each pipe (mm). Wider bores are louder and lower-impedance
// but push the tubes apart and cost plastic.
bore_d = 10;
// Pipe wall thickness (mm) — keep >= 1.2 (3 perimeters at 0.4 mm nozzle).
wall = 1.6;
// Gap between neighbouring tubes at the base (mm).
tube_gap = 3;

/* [Fipple] */
// Windway (flue) air-gap height — the THIN dimension of the jet slot (mm).
// This is the make-or-break FDM feature: it must bridge cleanly. 1.0 mm =
// 5 layers at 0.2 mm. Do not go below 0.8.
flue_h = 1.0;
// Windway width across the jet (mm) — the wide dimension of the flue slot.
flue_w = 7;
// Cut-up: flue-exit-to-labium distance (mm). The acoustically critical
// fipple dimension; ~1/4 of the window width is the classic whistle ratio.
cutup = 4.5;
// Labium land (mm): a small flat at the splitting edge so it is a printable
// ~1-nozzle tip rather than an unprintable zero-thickness knife.
labium_land = 0.5;
// Height of the plenum chamber under the blocks (mm).
plenum_h = 10;
// Floor thickness under the plenum (mm, bed-contact wall).
floor_t = 1.6;

/* [Mouthpiece] */
// Bore of the mouthpiece you blow into (mm). Kept small enough that its
// teardrop fits inside the base bar.
mouth_d = 6;
// How far the beak projects past the base end (mm).
mouth_proj = 11;

/* [Base] */
// Extra base material in front of (toward the windows) the tube centres (mm).
base_front = 7;
// Extra base material behind the tube centres (mm).
base_back = 5;
// Extra base material at each Y end, around the end tubes (mm).
base_end = 5;
// 45-degree chamfer on bed-contact edges (mm).
bottom_chamfer = 0.8;

/* [Quality] */
// Production smoothness (visible cylinders want >= 64). Drop to ~48 only for
// quick iteration; the default render is what CI gates and what you slice.
$fn = 96;

// ---------------------------------------------------------------------------
// Derived geometry (mm)
// ---------------------------------------------------------------------------
voices  = len(chord_ratios);
r_bore  = bore_d / 2;
tube_od = bore_d + 2 * wall;
r_out   = tube_od / 2;
pitch   = tube_od + tube_gap;          // voice-to-voice spacing along Y
eps     = 0.02;                        // boolean overlap fudge

// Fipple stack heights (z), shared by every voice.
block_top    = floor_t + plenum_h;     // top of the plenum void / base bar
window_bot_z = block_top + 1.2;        // flue exit, just above the block
labium_z     = window_bot_z + cutup;   // resonator open end (window top edge)

// Per-voice resonator length from the stopped-pipe relation f = c/(4*Leff):
// the open window is one end, the closed cap the other. The physical air column
// actually runs from the labium up to the cone APEX (r_bore above the cap
// base), plus the open-end correction at the window. That extra length is the
// SAME for every voice (identical fipple, identical cone), so leaving it in
// would add a constant to each column — and a constant offset distorts the
// chord RATIOS (a global `tune` multiplier can't undo an additive error). So
// we subtract a lumped end correction, `end_corr`, from the cap base, keeping
// each effective column proportional to 1/f. It has two constant parts: the
// conical cap (r_bore, geometric) and the open-window correction
// (`window_corr`, acoustic) — both identical across voices. A physical print
// refines it if the intervals sound off.
end_corr = r_bore + window_corr;
function freq(i)      = root_freq * chord_ratios[i];
function reson_len(i) = tune * c_sound / (4 * freq(i));
function tube_top(i)  = labium_z + reson_len(i) - end_corr;  // cap base; apex ~= target length
function tube_y(i)    = i * pitch;                  // voice centre along Y

cap_h    = r_out;                       // 45deg conical closed top
top_z    = max([for (i = [0:voices-1]) tube_top(i)]) + cap_h;

// Base footprint (X: back at -X, front/windows at +X)
x_lo = -(r_bore + base_back);
x_hi =  (r_bore + base_front);
y_lo = tube_y(0)          - r_out - base_end;
y_hi = tube_y(voices - 1) + r_out + base_end;

// Mouthpiece bore centre height, low enough that the teardrop's point clears
// the top of the base bar with wall to spare.
mouth_z = floor_t + mouth_d/2 + 0.6;

// Printability non-negotiables (see PM.md). Firing any of these aborts the
// render, so the gate can't go green on a design that quietly dropped below
// the FDM floor.
assert(flue_h >= 0.8,
       "flue_h must be >= 0.8 mm (>= 2x a 0.4 mm nozzle width) or the jet slot prints shut");
assert(wall >= 1.2,
       "wall must be >= 1.2 mm (3 perimeters at 0.4 nozzle)");
assert(labium_land >= 0.3,
       "labium_land must be >= 0.3 mm (~1 nozzle) so the splitting edge prints");
assert(voices >= 1, "need at least one voice");
assert(flue_h < r_bore, "flue slot must be thinner than the bore radius");
assert(cutup > flue_h, "cut-up must exceed the flue height for a working fipple");
// Guard the acoustic inputs: these are all `-D`-overridable (see README), and a
// zero/negative value would divide by zero or make negative cylinder heights.
assert(root_freq > 0, "root_freq must be positive");
assert(c_sound > 0, "c_sound must be positive");
assert(tune > 0, "tune must be positive");
assert(min(chord_ratios) > 0, "every chord ratio must be positive");
assert(min([for (i = [0:voices-1]) reson_len(i)]) > end_corr + cutup,
       "root_freq too high for this bore: a resonator is shorter than its end correction — lower root_freq or bore_d");

// ---------------------------------------------------------------------------
// Solid body
// ---------------------------------------------------------------------------

// One resonator column: tube + self-supporting conical closed top.
module tube_solid(i) {
    translate([0, tube_y(i), 0]) {
        cylinder(d = tube_od, h = tube_top(i));
        // conical cap: narrows upward, so both its outer face and (via the
        // bore cone below) its inner ceiling are self-supporting.
        translate([0, 0, tube_top(i)])
            cylinder(d1 = tube_od, d2 = 2 * wall, h = cap_h);
    }
}

module base_bar() {
    translate([x_lo, y_lo, 0])
        rounded_box([x_hi - x_lo, y_hi - y_lo, block_top],
                    r = 3, bottom_chamfer = bottom_chamfer);
}

// External beak: a bed-resting mouthpiece snout at the -Y end you put your lips
// to. A flat-bottomed foot (not a floating cantilever) makes it fully self-
// supporting and adds a stable footprint. It encloses the teardrop bore with a
// full `wall` all round — including above the point, which rises 0.8*mouth_d
// above the bore centre (`td_top`); undersizing here would open a ~0.2 mm slit
// along the top, an air leak. Overlaps the base bar in +Y for a seamless union.
module beak_solid() {
    td_top = mouth_z + 0.8 * mouth_d + wall;   // wall above the teardrop point
    w      = mouth_d + 2 * wall;               // foot width in X
    translate([-w/2, y_lo - mouth_proj, 0])
        rounded_box([w, mouth_proj + 2, td_top], r = 2, bottom_chamfer = bottom_chamfer);
}

module solid_body() {
    base_bar();
    beak_solid();
    for (i = [0:voices - 1]) tube_solid(i);
}

// ---------------------------------------------------------------------------
// Voids (subtracted)
// ---------------------------------------------------------------------------

// Resonator bore: a vertical cylinder from the labium up, closed by a cone so
// the internal ceiling self-supports (no flat bridge under the cap).
module bore_void(i) {
    translate([0, tube_y(i), 0]) {
        translate([0, 0, labium_z])
            cylinder(d = bore_d, h = tube_top(i) - labium_z + eps);
        translate([0, 0, tube_top(i)])
            cylinder(d1 = bore_d, d2 = 0, h = r_bore);       // 45deg cone roof (clean apex)
    }
}

// Windway (flue): a thin vertical slot in the front of the block carrying air
// up from the plenum to the flue exit at window_bot_z. Vertical walls -> self
// supporting; the slot is thin in X (flue_h), wide in Y (flue_w). It starts
// low enough (floor_t + 0.6) to always overlap the (flat-roofed) plenum below
// it, so the air path from plenum to flue exit is continuous.
module windway_void(i) {
    z0 = floor_t + 0.6;
    translate([r_bore - flue_h, tube_y(i) - flue_w/2, z0])
        cube([flue_h, flue_w, window_bot_z - z0 + eps]);
}

// Window (mouth): a through-opening in the front wall from the flue exit up to
// the labium, plus a labium bevel steeper than 45deg (self-supporting) that
// leaves a printable `labium_land` tip. Built from an extruded wedge (not a
// rotated cube) so the mesh carries no sliver/degenerate faces.
module window_void(i) {
    ww   = flue_w + 1;                       // window a touch wider than the jet
    outx = base_front + wall + flue_h + 2;   // cut well past the outer wall
    translate([0, tube_y(i), 0]) {
        // open rectangular mouth: flue exit up to the labium
        translate([r_bore - flue_h, -ww/2, window_bot_z])
            cube([outx, ww, cutup + eps]);
        // labium bevel — wedge in X-Z extruded along Y. Polygon coords are
        // (x, -z): rotate([-90,0,0]) maps the 2D y-axis onto -Z (see
        // teardrop_hole in printability.scad). The tip keeps a `labium_land`
        // flat; the underside rises steeper than 45deg from there.
        rotate([-90, 0, 0])
            linear_extrude(ww, center = true)
                polygon([[r_bore + labium_land, -labium_z],
                         [r_bore + wall + 1,     -labium_z],
                         [r_bore + wall + 1,     -(labium_z + wall + 1)]]);
    }
}

// Plenum: a flat-roofed rectangular channel along Y feeding every windway,
// plus the mouthpiece bore. A flat roof (rather than a gable) means each thin
// windway punches through it TRANSVERSELY — a clean crossing — instead of
// grazing a sloped face tangentially, which is what made CGAL non-manifold.
// The roof is a short bridge (~9 mm span) that FDM handles without support;
// it costs a little overhang area but nothing structural.
module plenum_void() {
    hw   = r_bore - 0.5;               // half-width; front face inside windway
    roof = block_top - 2;              // flat ceiling, under the bar's top face
    translate([-hw, y_lo + wall, floor_t])
        cube([2*hw, y_hi - y_lo - 2*wall, roof - floor_t]);
    // mouthpiece bore into the plenum (teardrop -> supportless horizontal hole)
    translate([0, y_lo + eps, mouth_z])
        teardrop_hole(d = mouth_d, l = 2*(mouth_proj + base_end + wall));
}

// ---------------------------------------------------------------------------
// Assembly
// ---------------------------------------------------------------------------

module aerochord_solid() {
    difference() {
        solid_body();
        for (i = [0:voices - 1]) {
            bore_void(i);
            windway_void(i);
            window_void(i);
        }
        plenum_void();
    }
}

module aerochord() {
    if (show == "cutaway") {
        // longitudinal section: keep everything up to the middle voice's axis,
        // exposing that voice's plenum / windway / window / labium / bore.
        mid  = floor(voices / 2);
        y0   = y_lo - mouth_proj - 1;
        ysec = tube_y(mid) - y0;              // cut plane at the voice centre
        intersection() {
            aerochord_solid();
            translate([x_lo - 1, y0, -1])
                cube([x_hi - x_lo + 2, ysec, top_z + 2]);
        }
    } else {
        aerochord_solid();
    }
}

aerochord();
