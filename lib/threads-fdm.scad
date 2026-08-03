// threads-fdm.scad — printable trapezoidal threads for vertical FDM bores.
// All dimensions in millimeters. Use from a design with:
//   use <threads-fdm.scad>
//
// Extracted from designs/desiccant-capsule at its second consumer (issue #18).
// FDM-native rather than machine-accurate: shallow trapezoidal flanks so both
// the male crest and the female groove print supportless in a vertical bore, a
// coarse multi-start lead so the lid spins closed in a fraction of a turn, and
// a single tunable radial clearance instead of a fit class.
//
// The flanks are 45 degrees where they mate, and the weld skirt is vertical.
// That distinction is the fix for issue #37, and it is worth stating plainly
// because the obvious version of the fix does not build:
//
// The profile spans `depth + sink` radially but only the `depth` part of it is
// ever exposed — `sink` is a weld allowance that the caller's core cylinder
// swallows (thread_neck unions cylinder(d = d_min), and d_min/2 == r_min).
// Running one straight flank across the whole span, as the profile used to,
// makes the slope depth/(depth + sink) = 36.87 deg at the capsule's numbers,
// measured on the export as |nz| = 0.795..0.799 == cos(36.87).
//
// Widening the profile to keep one straight 45 deg flank across the full span
// (issue #37's fix A) drives w_root from 3.4 to 4.2 at the capsule's numbers
// and trips the multi-start guard below: 4.2 is not < pitch = 4, so the
// capsule stops rendering. So the flank runs 45 deg over `depth` and the skirt
// drops vertically through `sink` instead — six profile points, not four.
// w_root is unchanged, every guard keeps its bound, and the exposed geometry
// is identical to what fix A would have produced. Measured after: |nz| = 0.707
// on both a bare helix and the capsule's neck, and the capsule's
// beyond-45-deg overhang falls from 4% of its surface to 1%.
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

// Axial widening of the female groove, so the clearance normal to the flanks
// lands near `tol` rather than far under it. The female profile is the male
// profile translated radially by `tol` and widened axially by flank_add/2 per
// side; both displacements push the flank along its own normal, so for a flank
// of slope m the gap is
//   gap = (flank_add/2 + m*tol) / sqrt(1 + m^2)
// Setting m = 1 (a 45 degree flank) and solving gap == tol gives what this
// returns:
//   flank_add = 2*(sqrt(2) - 1)*tol          (~0.83*tol)
// Widen the flanks by less than this and the thread binds on the flanks while
// the radial gap still measures correctly — the failure that motivated the
// derivation.
//
// This is exact only because the mating flank really is at m = 1. It was not
// until issue #37: the built profile ran at m = 0.75, where this delivered
// 0.2794 against a promised 0.300 (6.9% tight, and worse as depth shrank —
// 13% at depth 0.6, 15% at depth 0.5). The fix was to the profile, not to
// this line, which is why the expression is unchanged. Crest and root
// clearance were never affected: those are pure radial displacement and
// measure exactly `tol` at any slope.
//
// Do not "generalise" this to flank_add = 2*tol*(sqrt(1 + m^2) - m) to
// accommodate some other slope. That would make the constant compensate for a
// flank angle the rest of the file promises is 45 deg, and the promise is what
// keeps the rib printable — see lib/threads-fdm-demo.scad, which measures the
// delivered gap on built geometry rather than restating this algebra.
function flank_add(tol) = 2 * (sqrt(2) - 1) * tol;

// ---------------------------------------------------------------------------
// Core generator
// ---------------------------------------------------------------------------

// How far the profile's inner edge sinks below the core surface so the helix
// welds into the core instead of merely touching it. File-level because the
// guards in thread_helix have to reason about it — see the r_min > sink
// assert, which was written as `d_major > 2*depth` and missed this term.
//
// This region is a weld allowance, not thread: in a neck it is inside the core
// cylinder, and in a bore it is outside the lid material. That is why the
// profile's skirt walls are vertical rather than continuing the flank — see
// the file header and `prof` below.
_sink = 0.4;

// One trapezoidal helix as a single polyhedron, swept `starts` times.
//   d_major  outer (crest) diameter
//   depth    radial thread depth; also sets the axial flank run, so the
//            exposed flank is 45 degrees (slope 1) at any depth
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
    // A fractional `starts` passes the bound above and then quietly disagrees
    // with itself: `lead` scales continuously while the [0:starts-1] sweep
    // rounds down, so starts = 1.5 builds ONE rib against a lead of 1.5*pitch.
    assert(starts == floor(starts), "thread starts must be a whole number.");
    assert(seg >= 1, "thread seg must be at least 1.");
    // depth == 0 is allowed on purpose: it degenerates the rib to a sliver
    // buried in the core, which is how a design asks for a threadless
    // slip-fit variant of the same part. The capsule renders cleanly under
    // -D 'thread_depth=0', and rejecting it here would have been the one
    // place this extraction changed behaviour.
    assert(depth >= 0, "thread depth must not be negative.");
    assert(length > 0, "thread length must be positive.");
    // The profile's inner point sits at r_min - _sink, so the real bound is
    // r_min > _sink, not r_min > 0: at or past the axis the sweep degenerates
    // and CGAL throws a bare "assertion violation!" from SNC_external_structure
    // with exit code 0 and a garbage STL that the gate then scores on its own
    // terms. Measured boundary at depth 1.2, pitch 4, starts 1, length 6:
    // d_major 3.2 (r_min 0.40) still fails, 3.3 (r_min 0.45) is clean — hence
    // a strict >. The old form of this guard, d_major > 2*depth, omitted the
    // _sink term entirely and passed all three failing cases.
    assert(d_major > 2 * (depth + _sink), str(
        "thread core is too small for the profile: d_major/2 - depth = ",
        d_major / 2 - depth, " must be > sink = ", _sink,
        ". Raise d_major or cut depth."));

    lead    = pitch * starts;
    r_maj   = d_major / 2;
    r_min   = r_maj - depth;
    w_crest = 0.25 * pitch + w_add;
    // w_add is caller-supplied (thread_bore_cut exposes it), and at
    // w_add <= -0.25*pitch the crest collapses to zero or inverts. The profile
    // points then coincide or cross before polyhedron() ever sees them.
    assert(w_crest > 0, str(
        "thread crest width 0.25*pitch + w_add = ", w_crest,
        " must be positive; w_add is too negative for this pitch."));
    w_root  = w_crest + 2 * depth;           // 45 deg flank: depth radial, depth axial

    // The profile is w_root tall axially and repeats every `lead`. If it does
    // not fit, consecutive turns collide and the sweep self-intersects — the
    // polyhedron still exports, then CGAL either fails on the union with an
    // opaque "assertion violation" or, at w_root == lead exactly, silently
    // drops the whole helical rib and leaves you the bare core (verified: the
    // pre-extraction capsule at depth 1.5, starts 1 exports maxR == d_min/2,
    // no crest, "mesh is not closed", exit 0). Hence a strict <, not <=.
    //
    // The capsule never hit it: 3.64853 for its female cutter — the binding
    // case, since w_add makes the cutter taller than the male's 3.4 — against
    // a lead of 8. One consumer that far from the bound is exactly why the
    // precondition stayed implicit until a second parameter set found it.
    assert(w_root < lead, str(
        "thread profile does not fit the lead: 0.25*pitch + w_add + 2*depth = ",
        w_root, " must be < pitch*starts = ", lead,
        ". Raise pitch or starts, or cut depth."));
    // The bound above is turn-to-turn WITHIN one start. At starts >= 2 the ribs
    // must also clear EACH OTHER, and that is a tighter bound: rotating the
    // helix by 360/starts is the same as translating it axially by
    // lead/starts == pitch, so adjacent starts sit `pitch` apart, not `lead`
    // apart. At w_root >= pitch consecutive ribs interpenetrate and fuse into
    // one solid — the export stays watertight and exits 0, it is simply no
    // longer a multi-start thread. Measured on thread_helix(28, 1.2, 2, 2, 9)
    // (w_root 2.9, pitch 2, lead 4, so the lead bound above passes): printcheck
    // reports ONE body, against two at the capsule's own numbers (w_root 3.4,
    // pitch 4). Strict <, for the same reason as the lead bound — at equality
    // the flanks coincide.
    //
    // This also makes the advice above safe: "Raise pitch or starts" can now
    // only land a caller on a named error, never on the silent fusion.
    //
    // Exact rather than conservative, and only because the weld skirt is
    // vertical (issue #37): w_root is the profile's width at every radius from
    // r_min - _sink up to r_min, so the widest part of the rib is also the
    // widest part a neck actually exposes. Had the flank instead run straight
    // through the skirt, w_root would exceed the exposed width by 2*_sink and
    // this bound would refuse parameter sets that mate perfectly — including
    // the capsule's own.
    assert(starts < 2 || w_root < pitch, str(
        "multi-start ribs do not clear each other: 0.25*pitch + w_add + 2*depth"
        , " = ", w_root, " must be < pitch = ", pitch, " at starts = ", starts,
        " (adjacent starts sit pitch apart, not lead apart). Raise pitch, cut ",
        "depth, or drop to a single start."));
    // Six points, not four: the mating flank runs 45 degrees over `depth`
    // (r_min -> r_maj, w_root/2 -> w_crest/2, equal radial and axial run), and
    // the weld skirt drops VERTICALLY through `sink` below the core surface.
    // The skirt carries no thread — the caller's core swallows it — so giving
    // it the flank's slope would only widen w_root and trip the multi-start
    // bound above, which is exactly what issue #37's fix A did.
    //
    // At depth == 0 there is no flank to slope: r_min == r_maj and
    // w_root == w_crest, so the two skirt corners would land exactly on the
    // two crest corners and the profile would carry duplicate vertices. That
    // is the documented slip-fit case (`-D thread_depth=0`), not a corner
    // nobody reaches. CGAL does collapse the zero-area faces — measured, the
    // capsule's mesh at depth 0 is hash-identical before and after this
    // change — but a degenerate polygon is not a thing to hand a geometry
    // kernel on purpose, and CI also renders under the manifold backend,
    // which is a different kernel with no such guarantee. So the degenerate
    // pair is never constructed: at depth 0 the profile is the plain
    // rectangle it collapses to anyway.
    prof = depth > 0
        ? [
            [r_min - _sink, -w_root / 2],
            [r_min,         -w_root / 2],
            [r_maj,         -w_crest / 2],
            [r_maj,          w_crest / 2],
            [r_min,          w_root / 2],
            [r_min - _sink,  w_root / 2]
          ]
        : [
            [r_min - _sink, -w_root / 2],
            [r_maj,         -w_crest / 2],
            [r_maj,          w_crest / 2],
            [r_min - _sink,  w_root / 2]
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
    // A negative chamfer clears the length > ch bound below and then inverts
    // the lead-in: the clip cylinder is `length - ch` tall, so the neck comes
    // out TALLER than the length it documents, while the cone (h = ch + eps)
    // renders empty. Measured on thread_neck(28, 1.2, 4, 2, 9, chamfer = -2):
    // STL z extent 11.0 mm against a documented 9, exit 0, no warning.
    // ch == 0 stays legal — that is how a caller asks for no lead-in at all.
    assert(ch >= 0, str(
        "thread neck chamfer must not be negative: ", ch, " would build a neck ",
        length - ch, " tall against a documented length of ", length,
        ". Use chamfer = 0 for no lead-in."));
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

// Female cutter for the neck above. Same helix grown radially by `tol` and
// widened axially by flank_add(tol), running out below z = 0 so the bore has
// no lip to print into.
//
// THIS CUTS THE GROOVE ONLY — it does not open the bore. On its own it leaves
// the material inside the female crest radius in place, and the lid comes out
// a solid plug the neck cannot enter: watertight, sliceable, gate-passing, and
// useless. The caller must also cut the minor bore:
//
//   difference() {
//       lid_blank();
//       cylinder(d = d_major - 2 * depth + 2 * tol, h = ...);   // <- mandatory
//       thread_bore_cut(d_major, depth, pitch, starts, length, tol);
//   }
//
// (Verified: intersecting the neck with a lid cut by this module alone leaves
// 4555 mm^3 of interference spanning the whole neck core; add the bore and the
// intersection is empty at tol. threads-fdm-demo.scad item 3 is the worked
// example.)
//   over    extra THREADED length past `length` — not plain bore. It is passed
//           straight through as the helix length, so what it adds is more
//           groove, not headroom. Measured on
//           thread_bore_cut(28, 1.2, 4, 2, 9, 0.3, over = 6): the cutter spans
//           z -4 .. 15, i.e. helical rib for the whole 6 mm above the neck's
//           z 9, not a smooth counterbore. (The -4 is the documented `ext`
//           runout below z = 0, one pitch deep.) For actual headroom, cut a
//           plain cylinder above the thread instead.
//   w_add   axial widening override; defaults to flank_add(tol). Exposed so a
//           design can tune flank clearance independently of the radial fit —
//           pre-extraction the capsule had this as a top-level variable and
//           could reach it with -D.
module thread_bore_cut(d_major, depth, pitch, starts, length, tol,
                       over = 0, seg = 48, w_add = undef) {
    assert(tol >= 0, "thread tol must not be negative.");
    // `over` is signed and unguarded elsewhere: at length + over <= 0 the clip
    // cylinder gets a negative height, which OpenSCAD renders as empty without
    // a word, so the whole cutter vanishes and difference() returns the blank
    // untouched — exit 0, no warning, and printcheck scores the unthreaded
    // result 100/100 PRINTABLE. Fail loudly instead.
    assert(length + over > 0, str(
        "thread bore length + over = ", length + over,
        " must be positive; a non-positive bore deletes the thread silently."));
    wa = is_undef(w_add) ? flank_add(tol) : w_add;
    ext = pitch;                             // run out past the rim
    intersection() {
        thread_helix(d_major + 2 * tol, depth, pitch, starts, length + over,
                     w_add = wa, seg = seg);
        translate([0, 0, -ext])
            cylinder(d = d_major + 4, h = length + over + ext);
    }
}
