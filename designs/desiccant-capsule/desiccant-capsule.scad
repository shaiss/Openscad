// ============================================================
// Parametric Desiccant Capsule for Filament Dry-Boxes
// ============================================================
// Two-part screw capsule for loose silica gel beads:
//   - Perforated cylindrical body (hex or slot vents)
//   - Screw-on lid with real trapezoidal threads and grip ribs
//
// Designed for support-free FDM printing:
//   - Body prints upright. Slot vents bridge only their own width;
//     hex vents are point-up (30 deg walls).
//   - Threads use 45 deg flanks (2-start, coarse pitch).
//   - Lid prints upside down (flat top on the bed); internal
//     threads in a vertical bore need no support.
//   - Internal shoulder inside the body is a 45 deg cone.
//
// If the lid binds, increase thread_tol (radial clearance) in
// steps of 0.1 and reprint the lid only. If it is too loose,
// decrease it.
// ============================================================

/* [Part selection] */
// Which geometry to generate ("print" = both parts laid out for one plate)
part = "print"; // [body, lid, print, assembly, cutaway]

/* [Body] */
// Outer diameter of the body (mm)
body_od = 30;
// Overall body height, including the threaded neck (mm)
body_h = 40;
// Side wall thickness (mm)
wall = 2.0;
// Floor thickness (mm)
floor_t = 2.0;

/* [Vents] */
// Vent pattern on the side wall. Slots are the default: at sub-1 mm
// openings FDM nozzles tend to seal hex holes shut, while narrow
// vertical slots print crisply.
vent_style = "slot"; // [hex, slot]
// Max opening size (mm); guarded against bead_min below (hex inscribed width is ~0.87x this)
vent_w = 0.8;
// Material web left between openings (mm)
vent_web = 2.4;
// Perforate the floor as well
floor_vents = true;
// Height of each slot segment (mm, slot style only)
slot_seg_h = 8;

/* [Thread] */
// Major (outer) diameter of the male thread on the neck (mm)
thread_major = 28;
// Axial distance between adjacent thread crests (mm)
thread_pitch = 4;
// Number of thread starts (2 = opens in ~1 turn)
thread_starts = 2;
// Radial depth of the thread (mm)
thread_depth = 1.2;
// Height of the threaded neck (mm)
neck_h = 9;
// TUNE THIS if the lid binds: radial clearance added to the female thread (mm)
thread_tol = 0.3;

/* [Lid] */
// Lid wall thickness around the thread (mm)
lid_wall = 2.4;
// Lid top plate thickness (mm)
lid_top_t = 2.4;
// Number of grip ribs
rib_count = 24;
// Grip rib diameter (mm)
rib_d = 1.6;
// Axial clearance between neck top and lid ceiling (mm)
lid_clear_top = 0.4;

/* [Bead containment] */
// Smallest silica bead diameter the capsule must retain (mm)
// (1.0 = indicating silica gel, 1-3 mm grade)
bead_min = 1.0;
// Safety margin below bead_min (mm; beads shed size over drying cycles)
bead_margin = 0.2;

/* [Quality] */
$fa = 4;
$fs = 0.4;
// Thread facets per turn
thread_seg = 48;

// ---------------- derived dimensions ----------------
eps          = 0.01;
z_sh         = body_h - neck_h;              // shoulder: neck base / lid rim seat
thread_minor = thread_major - 2 * thread_depth;
body_id      = body_od - 2 * wall;
mouth_id     = thread_minor - 2 * wall;      // pour opening
cone_h       = (body_id - mouth_id) / 2;     // 45 deg internal shoulder
assert(cone_h > 0,
    str("Internal shoulder cone height is ", cone_h,
        " mm; mouth_id (", mouth_id, " mm) must stay below body_id (",
        body_id, " mm) - lower thread_major or thicken wall."));
assert(thread_pitch > 0, "thread_pitch must be positive.");
assert(thread_starts >= 1, "thread_starts must be at least 1.");
assert(thread_seg >= 1, "thread_seg must be at least 1.");
lid_bore     = thread_minor + 2 * thread_tol;              // slides over the neck core
lid_od       = thread_major + 2 * thread_tol + 2 * lid_wall; // wall covers groove depth
lid_h        = neck_h + lid_clear_top + lid_top_t;

// Axial widening of the female groove so the flank-normal clearance equals
// thread_tol exactly. The female profile is the male profile translated
// radially by thread_tol and widened axially by flank_add/2 per side; both
// displacements move a 45-degree flank along its normal:
//   gap = (thread_tol + flank_add/2) / sqrt(2)  ==  thread_tol
//   =>  flank_add = 2*(sqrt(2) - 1)*thread_tol      (~0.83*thread_tol)
// Full derivation in NOTES.md.
flank_add = 2 * (sqrt(2) - 1) * thread_tol;

// ---- bead-containment guards: no opening may pass a worn (undersized) bead.
// A bead passes an opening iff its diameter fits the opening's inscribed
// circle: vertex-up hex -> vent_w*cos(30); slot width and round floor
// holes -> vent_w.
max_wall_opening = (vent_style == "hex") ? vent_w * cos(30) : vent_w;
assert(max_wall_opening <= bead_min - bead_margin,
    str("Wall vent opening ", max_wall_opening,
        " mm can pass a worn ", bead_min, " mm bead; reduce vent_w (need <= ",
        bead_min - bead_margin, " mm effective)."));
assert(!floor_vents || vent_w <= bead_min - bead_margin,
    str("Floor vent hole ", vent_w,
        " mm can pass a worn ", bead_min, " mm bead; reduce vent_w or set ",
        "floor_vents = false."));

// ---- vent pattern (shared by geometry modules and the area report,
//      so the echoed numbers are computed from what actually gets cut)
vband_lo  = floor_t + 2;                     // vent band z-range
vband_hi  = z_sh - 3;
vband_h   = vband_hi - vband_lo;
vcols     = floor(PI * body_od / (vent_w + vent_web));
hex_row_p = (vent_w + vent_web) * 0.85;
hex_rows  = floor((vband_h - vent_w) / hex_row_p) + 1;

// Slot segment count, guarded: OpenSCAD division by zero yields inf
// (IEEE 754) instead of erroring, so an unguarded slot_nseg of 0 would
// surface as a runaway cube dimension rather than a clean abort.
assert(vband_h > 0,
    str("Vent band height is ", vband_h,
        " mm; body_h/neck_h/floor_t leave no room for vents."));
slot_nseg_fit = floor((vband_h + vent_web) / (slot_seg_h + vent_web));
assert(vent_style != "slot" || slot_nseg_fit >= 1,
    str("Vent band (", vband_h, " mm) is too short for one slot segment; ",
        "reduce slot_seg_h (", slot_seg_h, " mm) or increase body_h."));
slot_nseg = max(1, slot_nseg_fit);
slot_seg  = (vband_h - (slot_nseg - 1) * vent_web) / slot_nseg;

// floor hole rings
fl_ring_p  = vent_w + vent_web + 0.6;
fl_nrings  = floor((body_id / 2 - 2 - vent_w / 2) / fl_ring_p);
fl_counts  = fl_nrings < 1 ? [] :
    [for (i = [1:fl_nrings])
        max(4, floor(2 * PI * i * fl_ring_p / (vent_w + vent_web)))];
function _sum(v, i = 0) = i >= len(v) ? 0 : v[i] + _sum(v, i + 1);

// open-area report (mm^2); hex area with across-corners d is 3*sqrt(3)/8*d^2
wall_open  = (vent_style == "hex")
    ? vcols * hex_rows * 3 * sqrt(3) / 8 * vent_w * vent_w
    : vcols * slot_nseg * slot_seg * vent_w;
vband_area = PI * body_od * vband_h;
floor_open = floor_vents ? _sum(fl_counts) * PI * vent_w * vent_w / 4 : 0;

echo(str("Mouth opening: ", mouth_id, " mm"));
echo(str("Lid OD (incl. ribs): ", lid_od + rib_d, " mm"));
echo(str("Closed height: ", z_sh + lid_h, " mm"));
echo(str("Wall vent open area: ", wall_open, " mm2 (",
         round(1000 * wall_open / vband_area) / 10, "% of the ",
         vband_h, " mm vent band)"));
echo(str("Floor vent open area: ", floor_open, " mm2"));

// ============================================================
// Thread: trapezoidal profile swept as a helical polyhedron.
// Solid rib for the male thread; pass tol/w_add to grow it into
// a cutter for the female thread.
// ============================================================
module thread_helix(d_major, depth, pitch, starts, length, w_add = 0) {
    lead    = pitch * starts;
    r_maj   = d_major / 2;
    r_min   = r_maj - depth;
    w_crest = 0.25 * pitch + w_add;
    w_root  = w_crest + 2 * depth;           // 45 deg flanks
    sink    = 0.4;                           // weld into the core
    prof = [
        [r_min - sink, -w_root / 2],
        [r_maj,        -w_crest / 2],
        [r_maj,         w_crest / 2],
        [r_min - sink,  w_root / 2]
    ];
    k     = len(prof);
    turns = (length + 2 * lead) / lead;
    N     = ceil(thread_seg * turns);
    da    = 360 * turns / N;
    dz    = lead * turns / N;
    pts   = [for (i = [0:N], p = prof)
                [p[0] * cos(i * da), p[0] * sin(i * da), p[1] + i * dz - lead]];
    faces = concat(
        [[for (j = [k-1:-1:0]) j]],                 // start cap
        [[for (j = [0:k-1]) N * k + j]],            // end cap
        [for (i = [0:N-1], j = [0:k-1])                     // side quads,
            [i*k + j, i*k + (j+1)%k, (i+1)*k + (j+1)%k]],   // triangulated
        [for (i = [0:N-1], j = [0:k-1])
            [i*k + j, (i+1)*k + (j+1)%k, (i+1)*k + j]]
    );
    for (s = [0:starts-1])
        rotate([0, 0, s * 360 / starts])
            polyhedron(points = pts, faces = faces, convexity = 10);
}

// Male thread + neck core, chamfered at the top for lead-in.
module male_neck() {
    ch = thread_depth + 0.2;
    intersection() {
        union() {
            cylinder(d = thread_minor, h = neck_h);
            thread_helix(thread_major, thread_depth, thread_pitch,
                         thread_starts, neck_h);
        }
        union() {
            cylinder(d = thread_major + 2, h = neck_h - ch);
            translate([0, 0, neck_h - ch])
                cylinder(d1 = thread_major + 2, d2 = thread_minor - 0.6,
                         h = ch + eps);
        }
    }
}

// Female thread cutter: same thread grown radially by thread_tol
// and axially widened, running out below the rim.
module female_thread_cut() {
    ext = thread_pitch;                      // run out past the rim
    intersection() {
        thread_helix(thread_major + 2 * thread_tol, thread_depth,
                     thread_pitch, thread_starts,
                     neck_h + lid_clear_top, w_add = flank_add);
        translate([0, 0, -ext])
            cylinder(d = thread_major + 4,
                     h = neck_h + lid_clear_top + ext);
    }
}

// ============================================================
// Vents
// ============================================================
module side_vents() {
    if (vent_style == "hex") {
        for (r = [0:hex_rows - 1], c = [0:vcols - 1])
            rotate([0, 0, c * 360 / vcols + (r % 2) * 180 / vcols])
                translate([0, 0, vband_lo + vent_w / 2 + r * hex_row_p])
                    rotate([0, 90, 0])
                        // vertex-up hexagon: printable in a vertical wall
                        cylinder(d = vent_w, h = body_od, $fn = 6);
    } else { // slot
        for (s = [0:slot_nseg - 1], c = [0:vcols - 1])
            rotate([0, 0, c * 360 / vcols + (s % 2) * 180 / vcols])
                translate([0, -vent_w / 2, vband_lo + s * (slot_seg + vent_web)])
                    cube([body_od, vent_w, slot_seg]);
    }
}

module floor_vent_cut() {
    for (i = [1:max(1, fl_nrings)]) {
        if (i <= fl_nrings) {
            r = i * fl_ring_p;
            n = fl_counts[i - 1];
            for (j = [0:n - 1])
                rotate([0, 0, j * 360 / n])
                    translate([r, 0, -eps])
                        cylinder(d = vent_w, h = floor_t + 2 * eps, $fn = 12);
        }
    }
}

// ============================================================
// Parts
// ============================================================
module body() {
    difference() {
        union() {
            cylinder(d = body_od, h = z_sh);
            translate([0, 0, z_sh]) male_neck();
        }
        // main cavity
        translate([0, 0, floor_t])
            cylinder(d = body_id, h = z_sh - cone_h - floor_t + eps);
        // 45 deg internal shoulder up to the mouth
        translate([0, 0, z_sh - cone_h])
            cylinder(d1 = body_id, d2 = mouth_id, h = cone_h + eps);
        // mouth bore
        translate([0, 0, z_sh - eps])
            cylinder(d = mouth_id, h = neck_h + 2 * eps);
        side_vents();
        if (floor_vents) floor_vent_cut();
    }
}

// Modeled in closed position on the body so the assembly view
// shows real thread engagement; rim seats on the body shoulder.
module lid_in_place() {
    translate([0, 0, z_sh]) difference() {
        union() {
            cylinder(d = lid_od, h = lid_h);
            for (i = [0:rib_count - 1])
                rotate([0, 0, i * 360 / rib_count])
                    translate([lid_od / 2, 0, 0])
                        cylinder(d = rib_d, h = lid_h, $fn = 16);
        }
        // bore over the neck
        translate([0, 0, -eps])
            cylinder(d = lid_bore, h = neck_h + lid_clear_top + eps);
        female_thread_cut();
        // lead-in chamfer at the rim
        translate([0, 0, -eps])
            cylinder(d1 = thread_major + 2 * thread_tol + 1, d2 = lid_bore,
                     h = thread_depth + 0.5);
    }
}

// Lid in print orientation: top face on the bed, threads up.
module lid_print() {
    translate([0, 0, z_sh + lid_h]) rotate([180, 0, 0]) lid_in_place();
}

// ============================================================
// Part selection
// ============================================================
if (part == "body") {
    body();
} else if (part == "lid") {
    lid_print();
} else if (part == "print") {
    body();
    translate([body_od / 2 + lid_od / 2 + rib_d + 8, 0, 0]) lid_print();
} else if (part == "assembly") {
    color("SteelBlue") body();
    color("Orange") lid_in_place();
} else if (part == "cutaway") {
    difference() {
        union() {
            color("SteelBlue") body();
            color("Orange") lid_in_place();
        }
        translate([-body_od, -body_od, -1])
            cube([2 * body_od, body_od, body_h + lid_h + 2]);
    }
}
