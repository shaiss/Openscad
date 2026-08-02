// threads-fdm.scad — printable trapezoidal threads for vertical FDM bores.
// All dimensions in millimeters. Use from a design with:
//   use <threads-fdm.scad>
//
// Extracted from designs/desiccant-capsule at its second consumer (issue #18).
// FDM-native rather than machine-accurate: 45 degree flanks so both the male
// crest and the female groove print supportless in a vertical bore, a coarse
// multi-start lead so the lid spins closed in a fraction of a turn, and a
// single tunable radial clearance instead of a fit class.
//
// The male and female profiles come from ONE helix generator, so they cannot
// drift apart: the female cutter is the male thread grown radially by `tol`
// and widened axially by flank_add(tol). Keep it that way.
//
// For machine threads (ISO metric, UTS) reach for BOSL2 instead:
//   include <BOSL2/screws.scad>

// ---------------------------------------------------------------------------
// Clearance math
// ---------------------------------------------------------------------------

// Axial widening of the female groove so the flank-normal clearance equals
// `tol` exactly. The female profile is the male profile translated radially
// by `tol` and widened axially by flank_add/2 per side; on a 45 degree flank
// both displacements move along the same normal:
//   gap = (tol + flank_add/2) / sqrt(2)  ==  tol
//   =>  flank_add = 2*(sqrt(2) - 1)*tol      (~0.83*tol)
// Widen the flanks without this and the thread binds on the flanks while the
// radial gap still measures correctly — the failure that motivated deriving it.
function flank_add(tol) = 2 * (sqrt(2) - 1) * tol;

// ---------------------------------------------------------------------------
// Core generator
// ---------------------------------------------------------------------------

// One trapezoidal helix as a single polyhedron, swept `starts` times.
//   d_major  outer (crest) diameter
//   depth    radial thread depth; flanks are 45 degrees, so this also sets
//            the axial flank run
//   pitch    axial rise per start; lead = pitch * starts
//   starts   number of thread starts (>= 1)
//   length   threaded length; the helix runs one lead past each end so the
//            caller can intersect it to a clean boundary
//   w_add    axial widening of the profile — 0 for the male thread,
//            flank_add(tol) for the female cutter
//   seg      profile samples per turn, the $fn of the helix; 48 is smooth
//            enough for a 28 mm neck, raise it for larger diameters
module thread_helix(d_major, depth, pitch, starts, length, w_add = 0,
                    seg = 48) {
    // These guards travel with the module on purpose: left behind in the
    // calling design, a bad parameter becomes a division by zero deep in the
    // point list instead of a named error.
    assert(pitch > 0, "thread pitch must be positive.");
    assert(starts >= 1, "thread starts must be at least 1.");
    assert(seg >= 1, "thread seg must be at least 1.");
    assert(depth > 0, "thread depth must be positive.");
    assert(d_major > 2 * depth, "thread depth must be less than the radius.");

    lead    = pitch * starts;
    r_maj   = d_major / 2;
    r_min   = r_maj - depth;
    w_crest = 0.25 * pitch + w_add;
    w_root  = w_crest + 2 * depth;           // 45 deg flanks

    // The profile is w_root tall axially and repeats every `lead`. If it does
    // not fit, consecutive turns overlap and the sweep self-intersects — the
    // polyhedron still exports, then CGAL fails on the union with an opaque
    // "assertion violation" nowhere near the cause. The capsule that this
    // library came from never hit it (w_root 3.4 against a lead of 8), so the
    // precondition stayed implicit until a second parameter set found it.
    assert(w_root < lead, str(
        "thread profile does not fit the lead: 0.25*pitch + w_add + 2*depth = ",
        w_root, " must be < pitch*starts = ", lead,
        ". Raise pitch or starts, or cut depth."));
    sink    = 0.4;                           // weld into the core
    prof = [
        [r_min - sink, -w_root / 2],
        [r_maj,        -w_crest / 2],
        [r_maj,         w_crest / 2],
        [r_min - sink,  w_root / 2]
    ];
    k     = len(prof);
    turns = (length + 2 * lead) / lead;
    N     = ceil(seg * turns);
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

// ---------------------------------------------------------------------------
// Male / female pair
// ---------------------------------------------------------------------------

// Threaded neck sitting on z = 0, chamfered at the top so the mating part
// finds the start of the thread instead of cross-threading.
//   d_major/depth/pitch/starts/seg  as thread_helix
//   length    neck height
//   chamfer   lead-in cone height; defaults to depth + 0.2
//   eps       overlap fudge to keep the cone welded to the neck
module thread_neck(d_major, depth, pitch, starts, length,
                   chamfer = undef, seg = 48, eps = 0.01) {
    ch    = is_undef(chamfer) ? depth + 0.2 : chamfer;
    d_min = d_major - 2 * depth;
    assert(length > ch, "thread neck length must exceed its lead-in chamfer.");
    intersection() {
        union() {
            cylinder(d = d_min, h = length);
            thread_helix(d_major, depth, pitch, starts, length, seg = seg);
        }
        union() {
            cylinder(d = d_major + 2, h = length - ch);
            translate([0, 0, length - ch])
                cylinder(d1 = d_major + 2, d2 = d_min - 0.6, h = ch + eps);
        }
    }
}

// Female cutter for the neck above: difference() this out of the lid body.
// Same helix grown radially by `tol` and widened axially by flank_add(tol),
// running out below z = 0 so the bore has no lip to print into.
//   over    extra bore length past `length` (headroom above the neck)
module thread_bore_cut(d_major, depth, pitch, starts, length, tol,
                       over = 0, seg = 48) {
    assert(tol >= 0, "thread tol must not be negative.");
    ext = pitch;                             // run out past the rim
    intersection() {
        thread_helix(d_major + 2 * tol, depth, pitch, starts, length + over,
                     w_add = flank_add(tol), seg = seg);
        translate([0, 0, -ext])
            cylinder(d = d_major + 4, h = length + over + ext);
    }
}
