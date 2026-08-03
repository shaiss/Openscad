// nuggs-coupling.scad — the N.U.G.G.S. genderless quarter-turn bayonet port.
// All dimensions in millimeters. Use from a design with:
//   use <nuggs-coupling.scad>
//
// Extracted from designs/nuggs at its second consumer: NUGGS is a TUBE SYSTEM
// with ONE interlock standard shared by every module, so the interlock cannot
// live inside one design's .scad file and be copied by the next one.
//
// WHAT IT IS. One face of a coupling. The ring [ro, r_out] is split at r_mid
// into an inner and an outer band; each face carries the OUTER band over n_lug
// sectors and the INNER band over the sectors between them, so two IDENTICAL
// faces nest at a relative clocking of half a sector pitch — where one part
// presents outer shell, the mate presents inner shell, at a different radius.
// There are no gendered halves and no orphan ends. Each outer sector carries an
// inward locking rib; each inner sector carries the matching bayonet groove (an
// axial entry slot, then a circumferential run). Push together, twist either
// way, the ribs seat.
//
// THE INVARIANT THAT KEEPS THE PAIR HONEST, and it is the same one
// lib/threads-fdm.scad states for its threads: the male feature (the rib) and
// the female feature (the groove) come from ONE parameter set and ONE
// derivation — the groove is the rib grown by `port_tol` on every surface, with
// the circumferential oversize derived from that same millimetre through
// nuggs_tol_deg(). There is no second, independent female profile to drift.
// Keep it that way: never size the groove from a literal.
//
// ONE KNOB, IN MILLIMETRES. port_tol is a clearance in mm everywhere it
// appears. Rib and groove flanks are radial planes, so a fixed *angle* is a gap
// that grows with radius: feeding port_tol straight into rotate() and into a
// sector's angular width — which designs/nuggs did until issue #56 — realised
// 0.2317 mm/side at r = 44.25 instead of 0.300, and made the circumferential
// clearance scale with bore_d, so a coupon tuned at one bore mis-tuned another.
// nuggs_tol_deg(cfg, r) converts arc length to angle and is evaluated ONCE, at
// rib_in, the tightest radius where a rib flank faces a groove flank. An
// explicit port_tol_deg argument was considered and rejected upstream because
// it makes the one-knob claim false by construction; that rejection travels
// with the library. The derivation is pinned by a regression assert in
// nuggs_cfg() that reads the realised clearance back OUT of the angular widths
// the geometry actually uses, so writing a degree where a millimetre belongs
// fails the render instead of silently tightening the joint 23%.
//
// NOT BORE-CLEAN. nuggs_port() deliberately emits material INSIDE the bore — at
// the backing collar and at the inner sectors' anchoring half, both reaching in
// to ri - anchor_bite — because that is how those features fuse to the tube.
// The caller MUST subtract nuggs_bore_cut() over the port's whole z extent.
// Forget it and you get a watertight, sliceable, gate-passing, 100/100-scoring
// part with 2 mm of plastic standing in the bore. This is the same shape of
// footgun as thread_bore_cut()'s MANDATORY minor bore, and it is held down the
// same way — by lib/nuggs-coupling-mates.conf, not by this paragraph. Prefer
// nuggs_neck(), which does the cut for you.
//
// ORIENTATION IS A SILENT CRITICAL. nuggs_port() puts its tube body on +z and
// its coupling sectors on -z. Placed unmirrored on a flange it points every
// sector at the bed: 30% overhang, printcheck CRITICAL, gate exit 1. The
// mirrored form is spelled out at the call site on purpose, so it is visible in
// the design rather than hidden behind a flag:
//
//   translate([0, 0, port_proj + collar_t]) mirror([0, 0, 1]) nuggs_port(cfg);
//
// NOTHING HERE HAS EVER BEEN PRINTED. port_tol = 0.30 is a guess, and issue #56
// changed what that number means circumferentially by 23% one round ago.
// Extracting it makes the guess the default for every future consumer at every
// bore. Tune it on designs/nuggs's coupon in +/-0.05 steps before trusting it,
// and note the asymmetry the coupon cannot see: the inner sector's bore face
// clears the mate's TUBE OD by only port_tol/2, because the tube sits at
// exactly ro on both parts and only one side contributes clearance. That is the
// surface that binds first at a large bore.
//
// For machine threads, generic fillets/roundings, gears or attachments reach
// for BOSL2 instead; this library does one joint.

// ---------------------------------------------------------------------------
// Tessellation
// ---------------------------------------------------------------------------

// The library PINS its own fragment settings inside every geometry module and
// ignores the caller's $fn/$fa/$fs. That is surprising for an OpenSCAD module
// and it is deliberate.
//
// Every surface of this coupling comes from rotate_extrude, so the realised
// radii are polygonal: a sector's cylindrical face is inscribed in its nominal
// radius and lands short of it by the chord sagitta, by a different amount per
// radius and per swept angle. The two halves of this fit are split at ONE
// radius (r_mid +/- port_tol/2), which means the clearance there is a function
// of how finely the caller happened to tessellate.
//
// Measured on the pre-extraction geometry (designs/nuggs's nuggs_port on a
// plain 30 mm neck), at the INSERTION clocking with the pair pulled 0.01 mm
// apart — the position that must be free — the interference solid came out at:
//
//   $fn =  48  ->  0.1754 mm3        $fn =  96  ->  empty
//   $fn =  56  ->  0.0717 mm3        $fn = 120  ->  empty
//   $fn =  64  ->  0.0260 mm3        $fn = 128  ->  empty
//
// The same dependence, stated on the port alone rather than on a fit, is
// larger: one bare port face measures 19840.72 mm3 at $fn = 16, 20781.11 at 48,
// 20830.18 at 96 and 20838.26 at 128 — a 5.0% swing on nothing but a quality
// preset. Under the pin it is 20837.636278394 mm3 at every one of them.
//
// "One genderless interlock shared by every module" is literally false if the
// fit moves when a second consumer sets a different quality preset. And the
// harness that is supposed to catch that cannot: scripts/mate-check.sh renders
// at a hardcoded $fn = 96, so an unpinned library would have been proved at
// exactly one resolution and shipped to callers using any other.
//
// So the fit gets its own resolution and the caller keeps theirs for the rest
// of the part. The values are designs/nuggs's own $fa/$fs at the time of
// extraction, which is what makes the extraction provably mesh-neutral: a part
// built through this library at the design's defaults exports facet-for-facet
// what designs/nuggs exported before it. Raising them to the production
// $fa = 2 / $fs = 0.5 is a real change to every shipped mesh and belongs in its
// own commit, with lib/nuggs-coupling-mates.conf re-run, not smuggled into an
// extraction where an extraction bug and a resolution change would be
// indistinguishable.
_NUGGS_FA = 3;
_NUGGS_FS = 0.8;

// Half-width of the WALK BAND: the arc of bore, centred on the invert, that an
// animal's paws actually land on at a ~45 mm body width (+/-25.71 mm lateral at
// ri = 40). It is engineering judgement, not a sourced figure, and it exists
// here for exactly one reason: nuggs_window() must refuse a longitudinal window
// wide enough to eat the floor the animal walks on. An open module is a TUBE
// WITH A WINDOW — its floor is the ri arc, continuous with the round mate's
// bore to 0.000 mm at every lateral position. A flat trough floor tangent to
// the invert sits BELOW the round bore everywhere off the centreline, so at the
// joint plane the round mate's material stands proud of it by
// ri - sqrt(ri^2 - x^2) — 9.36 mm at the walk-band edge (x = 25.71, ri = 40).
// That is a full-height vertical toe-stub across the joint plane. There is no
// third option and no blend fixes it in less than a 21 mm ramp at 1:3.
// (An earlier revision of this comment quoted 6.93 mm and had the step facing
// the other way. 6.93 is the value at x = 22.5, half a 45 mm body width, not at
// the walk-band edge this module actually guards — PR #78 review.)
_NUGGS_WALK_HALF_DEG = 40;

// ---------------------------------------------------------------------------
// Configuration
//
// CONFIG-VECTOR IDIOM. nuggs_port() reads seventeen numbers and half of them
// are derived from the other half. Passing them as a long argument list to
// every module means every caller restates the derivations, and restated
// derivations drift — which is the failure this whole library exists to
// prevent. So a design builds ONE cfg with nuggs_cfg() and hands it around.
//
// Every guard lives in here rather than at file level, for two reasons. A
// top-level assert cannot see per-call arguments, so it could only ever check
// defaults. And scripts/check.sh fails any lib/*.scad whose asserts fire during
// its echo pass, so a library that guards at top level cannot ship a guards
// manifest at all.
// ---------------------------------------------------------------------------

_NC_BORE_D      = 0;
_NC_WALL        = 1;
_NC_LUG_R       = 2;
_NC_SPLIT       = 3;
_NC_PORT_PROJ   = 4;
_NC_COLLAR_T    = 5;
_NC_N_LUG       = 6;
_NC_LUG_DEG     = 7;
_NC_RIB_H       = 8;
_NC_RIB_W       = 9;
_NC_RIB_DEG     = 10;
_NC_TWIST_DEG   = 11;
_NC_BITE        = 12;
_NC_COLLAR_BITE = 13;
_NC_ANCHOR_BITE = 14;
_NC_PORT_TOL    = 15;
_NC_EPS         = 16;
_NC_NOZZLE      = 17;
_NC_MIN_BORE    = 18;

// Build a coupling configuration. Defaults ARE the NUGGS standard: change one
// and nothing you already printed fits.
//
//   bore_d       internal bore diameter — the headline number
//   wall         tube shell thickness; ro = bore_d/2 + wall is the datum every
//                coupling radius is measured from
//   lug_r        radial depth of the coupling ring beyond ro
//   split        fraction of lug_r given to the INNER band. 0.5 is an even
//                split; the inner band additionally hosts the groove, so this
//                is an assumption, not a derivation, and it is exposed rather
//                than hidden as a `/2`
//   port_proj    axial projection of the sectors past the tube face. Also sets
//                the seat: z_seat = port_proj = -z_tip, which is what makes the
//                two tube end faces butt at the same instant the mate's tips
//                land on the collar. Both stops are at ZERO nominal clearance;
//                in a print the tighter one wins, and which that is has never
//                been measured
//   collar_t     backing-collar thickness
//   n_lug        sectors per face (3 is kinematically determinate)
//   lug_deg      angular width of both sector sets. Doubles as the bed-adhesion
//                knob: the part prints standing on these tips
//   rib_h        radial reach of the locking rib into the mate's inner band
//   rib_w        axial thickness of the rib / height of the groove run
//   rib_deg      angular width of the rib
//   twist_deg    the locking twist. READS NO GEOMETRY — it appears only in the
//                guards below and in nuggs_clockings(). A reviewer diffing
//                meshes to check that a twist change "took" will find nothing;
//                only a mate test at the three clockings verifies it
//   bite         radial overlap fusing each rib into its outer sector. Never
//                zero: a zero-volume kiss leaves CGAL counting separate bodies
//   collar_bite  radial overlap fusing the collar into the outer sectors. A
//                bite-class number that is NOT bite — it was a hardcoded 1.0
//   anchor_bite  how far the collar and the inner sectors' anchoring half reach
//                INBOARD of ri to fuse with the tube. This is the material the
//                caller's bore cut must remove
//   port_tol     THE fit knob, millimetres, everywhere
//   eps          cut overshoot
//   nozzle       feeds the wall and web guards
//   min_bore     welfare floor on bore_d. NEVER lower this
function nuggs_cfg(
        bore_d      = 80.0,
        wall        = 2.4,
        lug_r       = 6.0,
        split       = 0.5,
        port_proj   = 10.0,
        collar_t    = 3.0,
        n_lug       = 3,
        lug_deg     = 40,
        rib_h       = 1.0,
        rib_w       = 2.4,
        rib_deg     = 12,
        twist_deg   = 14,
        bite        = 0.8,
        collar_bite = 1.0,
        anchor_bite = 2.0,
        port_tol    = 0.30,
        eps         = 0.01,
        nozzle      = 0.4,
        min_bore    = 70) =

    // These guards travel with the configuration on purpose: left behind in the
    // calling design, a bad parameter becomes a division by zero deep in a
    // point list, or — far more often here — a mesh that is watertight, one
    // body, sliceable and simply wrong.

    // WELFARE. The one number in this file that is not an engineering trade.
    assert(bore_d >= min_bore, str(
        "NUGGS BORE FLOOR: bore_d = ", bore_d, " mm is below the ", min_bore,
        " mm floor. The Deutscher Tierschutzbund gives 7 cm as the ENTRANCE",
        " minimum for a Syrian hamster with full cheek pouches. A bore that",
        " wedges a pouched animal fails silently — the part prints, gates and",
        " looks right, and the injury happens later. Raise bore_d."))

    assert(wall >= 3 * nozzle, str(
        "NUGGS WALL: wall = ", wall, " mm needs >= 3 perimeters at a ", nozzle,
        " mm nozzle (", 3 * nozzle, " mm). ro is derived from wall, so this is",
        " upstream of every coupling radius, not just the tube."))
    assert(n_lug >= 2, str(
        "NUGGS N_LUG: ", n_lug, " sectors cannot make a determinate joint;",
        " n_lug must be at least 2 (3 is kinematically determinate)."))
    assert(split > 0 && split < 1, str(
        "NUGGS SPLIT: split = ", split, " must lie strictly between 0 and 1 —",
        " it is the fraction of lug_r given to the inner band."))
    assert(lug_r > 0 && port_proj > 0 && collar_t > 0 && rib_w > 0
           && rib_deg > 0 && lug_deg > 0 && bite > 0, str(
        "NUGGS POSITIVE: lug_r, port_proj, collar_t, rib_w, rib_deg, lug_deg",
        " and bite must all be positive."))

    let(pitch = 360 / n_lug)

    // twist_deg = 0 is legal arithmetic and a broken joint: nuggs_clockings()
    // collapses to [pitch/2, pitch/2, pitch/2], so there is nowhere to twist TO
    // and the bayonet retains nothing. No mesh changes, so nothing else notices.
    assert(twist_deg > 0, str(
        "NUGGS TWIST: twist_deg = ", twist_deg, " gives no lock at all — the",
        " three clockings collapse onto the insertion clocking and the joint",
        " pulls straight back out. twist_deg must be positive."))
    // The genderless condition, in its twisted form. The mate's like-radius
    // sectors sit HALF a pitch away, so free travel is pitch/2 - lug_deg, not
    // pitch - lug_deg. The looser form lets the part render and gate cleanly
    // while being physically impossible to twist shut.
    assert(lug_deg + twist_deg <= pitch / 2, str(
        "NUGGS BAYONET CLEARANCE: lug_deg + twist_deg = ", lug_deg + twist_deg,
        " must fit within HALF the sector pitch (", pitch / 2, " deg). The",
        " mate's like-radius sectors sit half a pitch away, so free travel is",
        " pitch/2 - lug_deg, not pitch - lug_deg."))
    // Bayonet travel: the rib has to get from the entry slot to somewhere still
    // inside the circumferential run.
    assert(rib_deg + twist_deg <= lug_deg, str(
        "NUGGS BAYONET TRAVEL: rib_deg + twist_deg = ", rib_deg + twist_deg,
        " must fit inside lug_deg (", lug_deg, " deg), or the rib runs off the",
        " end of the mate's sector and retains nothing."))
    assert(port_tol >= 0.10 && port_tol <= 0.60, str(
        "NUGGS PORT_TOL: ", port_tol, " mm is outside the tunable band;",
        " 0.10-0.60 mm. Tune on the coupon in +/-0.05 steps."))

    let(ri     = bore_d / 2,
        ro     = ri + wall,
        r_mid  = ro + lug_r * split,
        r_out  = ro + lug_r,
        t2     = port_tol / 2,
        i_out  = r_mid - t2,
        rib_in = i_out - rib_h,
        tol_a  = port_tol / rib_in * 180 / PI,
        // The regression pin (issue #56, finding 1). circ_clr reads the
        // realised clearance back OUT of the angular widths the geometry
        // actually uses and converts it to millimetres at the engagement radii.
        // It is deliberately NOT the identity that defines tol_a: slot_deg and
        // run_deg are what nuggs_port() sweeps, so if either is ever set from
        // port_tol directly the render fails here instead of quietly tightening
        // the joint by 23%.
        slot_deg     = rib_deg + 2 * tol_a,
        run_deg      = lug_deg + 2 * tol_a,
        circ_clr     = (slot_deg - rib_deg) / 2 * PI / 180 * rib_in,
        circ_clr_max = (run_deg  - lug_deg) / 2 * PI / 180 * i_out,
        // The thinnest structural section of the projecting inner sector: what
        // is left between the groove floor and the sector's bore-side face.
        web = lug_r * split - rib_h - 2 * port_tol)

    assert(rib_in > ro, str(
        "NUGGS RIB DEPTH: the rib tip radius ", rib_in, " has fallen to or",
        " inside the tube OD ", ro, ". rib_h is deeper than the whole inner",
        " band; there is no groove floor left to cut."))
    // MEASURED silent failure. designs/nuggs guarded this region with
    // `rib_h < lug_r/2 - 0.4`, which bounds nothing that matters: at rib_h =
    // 2.15 — legal there — the web comes out at 0.25 mm, under a single 0.4 mm
    // extrusion width, and the 25 mm straight renders with no diagnostic at
    // all, exports watertight and ONE body (3944 facets, 40187.2 mm3 against
    // the baseline's 41784.6) and gates: printcheck scores it 76/100
    // PRINTABLE WITH CAVEATS against the baseline's 84, with the thin wall as a
    // WARNING, and warnings do not fail the gate. So this guard replaces that
    // one — it is stated at the printable-feature floor, which is the thing
    // that actually breaks. It runs BEFORE the circumferential pins below so a
    // too-deep rib is reported as the structural failure it is: in designs/nuggs
    // the only thing that stopped rib_h from going further was the loose-end
    // pin firing, and it announced "the angle is being derived at the wrong
    // radius", which was a misdiagnosis of a rib that was simply too deep.
    assert(web >= 2 * nozzle, str(
        "NUGGS WEB: the projecting inner sector is left ", web,
        " mm thick between its groove floor and its bore-side face (lug_r*split",
        " - rib_h - 2*port_tol), under the ", 2 * nozzle,
        " mm two-extrusion floor. At web <= 0 the entry slot cuts clean through",
        " the sector and the mesh stays watertight and one body. Cut rib_h, cut",
        " port_tol, or widen lug_r."))
    assert(abs(circ_clr - port_tol) < 1e-6, str(
        "NUGGS PORT_TOL (circumferential): the gap between a rib flank and its",
        " groove flank must BE port_tol in millimetres at the rib radius; the",
        " built widths deliver ", circ_clr, " against ", port_tol,
        ". Derive the bayonet's angular widths with nuggs_tol_deg(cfg, r);",
        " never set them from port_tol directly — that spends a millimetre as",
        " if it were a degree."))
    // The loose end of the same band. Two radial planes cannot be parallel, so
    // one angular width cannot deliver the same millimetre gap at both ends of
    // the engagement band; 5% is the spread this design accepts (it sits at
    // 2.26%). Exceeding it means one of two things and the message names both:
    // the angle was derived at the wrong radius, or the band is radially so
    // deep that no single radius can size it.
    assert(circ_clr_max <= port_tol * 1.05, str(
        "NUGGS PORT_TOL (circumferential): the loose end of the engagement",
        " band delivers ", circ_clr_max, " against port_tol ", port_tol,
        ", more than 5% over. Either the angle is being derived at the wrong",
        " radius — derive it at rib_in, the tightest radius where the flanks",
        " face each other — or rib_h is so deep against rib_in = ", rib_in,
        " that one angular width cannot size both ends of the band."))
    // The entry slot is the only way in, and it is deliberately much narrower
    // than the sector so there is solid material left to twist under. Let it
    // reach the sector's full width and it severs the sector instead. Note this
    // is NOT covered by BAYONET TRAVEL above: that bound only implies it while
    // twist_deg >= 2*tol_a, and twist_deg may legally be smaller.
    assert(slot_deg < lug_deg, str(
        "NUGGS SLOT: the entry slot is ", slot_deg, " deg wide against a ",
        lug_deg, " deg sector — it consumes the sector it is cut into and",
        " there is nothing left for the mate's rib to twist under."))
    // The budget is the OUTER band, r_out - r_mid = lug_r * (1 - split) — not
    // lug_r * split, which is the INNER band and is only the same number at the
    // default split = 0.5. Written with the wrong limb this guard let a rib
    // stand proud of r_out at any asymmetric split while still reporting the
    // correct radius in its own message (PR #78 review).
    assert(bite + t2 <= lug_r * (1 - split), str(
        "NUGGS RIB OD: the rib's fusing overlap puts its outer face at ",
        r_mid + t2 + bite, ", past the coupling ring OD ", r_out,
        ". Nothing mates out there, and a proud rib breaks the snag-free outer",
        " surface. Cut bite or widen lug_r."))
    // Same outer-band budget as NUGGS RIB OD above, and strict: the collar must
    // stop SHORT of r_out, never land on it.
    assert(collar_bite + t2 < lug_r * (1 - split), str(
        "NUGGS COLLAR OD: the backing collar reaches ", r_mid + t2 + collar_bite,
        ", at or past the outer sectors' OD ", r_out, ". It must stop SHORT of",
        " r_out so it never shares a cylindrical surface with the sectors it",
        " overlaps — a shared surface is how this geometry produces",
        " non-watertight meshes. Cut collar_bite or widen lug_r."))
    assert(anchor_bite > 0 && anchor_bite < wall, str(
        "NUGGS ANCHOR BITE: ", anchor_bite, " mm must be positive and less than",
        " wall (", wall, "). It is how far the collar and the inner sectors'",
        " anchoring half reach inboard of ri to fuse with the tube; at zero",
        " they only kiss it, and beyond the wall thickness they are reaching",
        " through nothing."))
    assert(eps > 0, "NUGGS EPS: the cut overshoot must be positive.")

    [bore_d, wall, lug_r, split, port_proj, collar_t, n_lug, lug_deg,
     rib_h, rib_w, rib_deg, twist_deg, bite, collar_bite, anchor_bite,
     port_tol, eps, nozzle, min_bore];

// ---------------------------------------------------------------------------
// The caller's contract values
//
// Every one of these was a global reach in designs/nuggs — the bore cuts, the
// revision mark's placement, bulkhead_out's lift, the coupon's spacing. Each is
// a caller obligation, so each has to be callable or the library is unusable at
// a second bore.
// ---------------------------------------------------------------------------

function nuggs_ri(cfg)    = cfg[_NC_BORE_D] / 2;                    // bore radius
function nuggs_ro(cfg)    = nuggs_ri(cfg) + cfg[_NC_WALL];          // tube OD radius
function nuggs_r_mid(cfg) = nuggs_ro(cfg) + cfg[_NC_LUG_R] * cfg[_NC_SPLIT];
function nuggs_r_out(cfg) = nuggs_ro(cfg) + cfg[_NC_LUG_R];         // ring OD / envelope
function nuggs_pitch(cfg) = 360 / cfg[_NC_N_LUG];

// z = 0 is the TUBE END FACE, and the mate's tube end face butts it there, so
// the bore is continuous across the joint. Our sectors project to z_tip, PAST
// our own face, and run alongside the mate's tube. z_seat is where the MATE's
// tips land on our collar. z_top is how far into our own tube body the port
// zone reaches — anything the design wants to put on the tube wall (a revision
// mark, a window) has to start beyond it.
function nuggs_z_tip(cfg)  = -cfg[_NC_PORT_PROJ];
function nuggs_z_seat(cfg) =  cfg[_NC_PORT_PROJ];
function nuggs_z_top(cfg)  =  cfg[_NC_PORT_PROJ] + cfg[_NC_COLLAR_T];

// The mate's clockings, derived so nothing has to restate them: insertion is
// half a pitch; locked is that plus or minus the twist, either direction.
// Hardcoded numbers here went stale three rounds running in designs/nuggs, so
// a mate test must call this rather than copy it.
function nuggs_clockings(cfg) = [
    nuggs_pitch(cfg) / 2,
    nuggs_pitch(cfg) / 2 - cfg[_NC_TWIST_DEG],
    nuggs_pitch(cfg) / 2 + cfg[_NC_TWIST_DEG]];

// Arc length -> angle. THE one-knob derivation; see the file header.
function nuggs_tol_deg(cfg, r) = cfg[_NC_PORT_TOL] / r * 180 / PI;

// The engagement band: rib_in is the rib tip and the tightest radius where a
// rib flank faces a groove flank; i_out is the inner shell's outer face and the
// loose end of the same band.
function nuggs_i_out(cfg)  = nuggs_r_mid(cfg) - cfg[_NC_PORT_TOL] / 2;
function nuggs_rib_in(cfg) = nuggs_i_out(cfg) - cfg[_NC_RIB_H];

// Retention area, in mm2. NOTE what it does NOT say: only ONE of the two rib
// sets bears per twist direction — at pitch/2 - twist it is our ribs trapped
// under the mate's inner sectors, at pitch/2 + twist it is the mate's ribs
// under ours. Retention is symmetric but never simultaneous, so a doc that says
// "the ribs seat" overstates this by 2x.
function nuggs_bearing_area(cfg) =
    cfg[_NC_N_LUG] * (cfg[_NC_RIB_DEG] * PI / 180)
    * (pow(nuggs_i_out(cfg), 2) - pow(nuggs_rib_in(cfg), 2)) / 2;

// Thickness left in the projecting inner sector under its groove — the guarded
// quantity, exposed so a design can report it rather than re-derive it.
function nuggs_web(cfg) =
    cfg[_NC_LUG_R] * cfg[_NC_SPLIT] - cfg[_NC_RIB_H] - 2 * cfg[_NC_PORT_TOL];

// Half-width of the walk band, in degrees about the invert. See the constant.
function nuggs_walk_half_deg() = _NUGGS_WALK_HALF_DEG;

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

// Annular-sector sweep: ONE swept polygon, never a union of two arcs.
//
// This helper and this comment must not be separated. Two arcs that share an
// exact radius leave a coincident cylindrical surface and CGAL returns a
// NON-WATERTIGHT mesh; that cost designs/nuggs a round, and it cost nuggs-yard
// another. The inner sector's L-profile below is a single six-point polygon for
// exactly this reason. designs/nuggs also carried an `arc(r1, r2, ang, h)`
// primitive, dead code left over from the version that built the L from two
// arcs — it is deliberately NOT extracted, because shipping it is shipping the
// trap.
module nuggs_sector(pts, ang) {
    $fa = _NUGGS_FA; $fs = _NUGGS_FS; $fn = 0;
    rotate_extrude(angle = ang) polygon(pts);
}

// Sector angular starts. The inner set is offset by half a pitch, which puts it
// exactly in the centre of the outer set's angular gaps for ANY lug_deg — that
// centring is the genderless condition, and it is why two identical faces nest.
function _nuggs_outer_a(cfg, i) = i * nuggs_pitch(cfg);
function _nuggs_inner_a(cfg, i) = i * nuggs_pitch(cfg) + nuggs_pitch(cfg) / 2;

// The bayonet groove cut into one inner sector's outer face:
//   * a narrow axial entry slot running from our tip to the seat — the only way
//     in, and much narrower than the sector so there is material left to twist
//     under;
//   * a full-width circumferential run at the seat, so the rib retains in
//     EITHER twist direction and no handedness has to be got right.
// Oversize by port_tol on every surface. `t` is the axial and radial clearance
// and is MILLIMETRES; tol_a is the SAME clearance expressed as the angle that
// delivers it at the rib radius. Do not collapse the two back into one symbol.
module _nuggs_bayonet_groove(cfg, a0) {
    $fa = _NUGGS_FA; $fs = _NUGGS_FS; $fn = 0;
    t       = cfg[_NC_PORT_TOL];
    eps     = cfg[_NC_EPS];
    i_out   = nuggs_i_out(cfg);
    rib_in  = nuggs_rib_in(cfg);
    g_floor = rib_in - t;                       // clears the rib tip by port_tol
    z_tip   = nuggs_z_tip(cfg);
    z_seat  = nuggs_z_seat(cfg);
    rib_w   = cfg[_NC_RIB_W];
    tol_a   = nuggs_tol_deg(cfg, rib_in);
    rotate([0, 0, a0 - tol_a])                                // axial entry slot
        nuggs_sector([[g_floor, z_tip - eps], [i_out + eps, z_tip - eps],
                      [i_out + eps, z_seat + t], [g_floor, z_seat + t]],
                     cfg[_NC_RIB_DEG] + 2 * tol_a);
    rotate([0, 0, a0 - tol_a])                             // circumferential run
        nuggs_sector([[g_floor, z_seat - rib_w - t], [i_out + eps, z_seat - rib_w - t],
                      [i_out + eps, z_seat + t], [g_floor, z_seat + t]],
                     cfg[_NC_LUG_DEG] + 2 * tol_a);
}

// ONE port face, in the fixed local frame the caller must honour: the tube end
// face is z = 0, the port's own tube body is on +z up to z_top, and the
// coupling sectors project to -z down to z_tip, past our own face and alongside
// the MATE's tube.
//
// NOT BORE-CLEAN — see the file header. Subtract nuggs_bore_cut() over
// z_tip..z_top at minimum, or use nuggs_neck().
//
// Four solids and one subtraction:
//   (a) the backing collar, a full annulus at the seat. It ties the outer
//       sectors in (they touch no tube wall — they live outboard of r_mid), it
//       is the mate's axial hard stop, and its OD stops short of r_out so it
//       never shares a cylindrical surface with the sectors it overlaps;
//   (b) the outer shell sectors, running up into the collar so they fuse;
//   (c) the inner shell sectors, ONE L-shaped profile each: clear of the mate's
//       tube below z = 0, reaching inboard to fuse with our own tube above it.
//       Biting inward along the whole length instead drives the sector into the
//       mate's tube OD — that was 1645 mm3 of interference;
//   (d) the locking rib, a narrow tab at each outer sector's CCW-leading edge,
//       reaching rib_h into the mate's inner band at the tip.
// Then the groove is subtracted from the WHOLE union, so it also notches the
// collar's bottom face. That notch is not incidental: it is what gives the
// mate's rib top face its port_tol of axial clearance at the seat.
module nuggs_port(cfg) {
    $fa = _NUGGS_FA; $fs = _NUGGS_FS; $fn = 0;
    ri      = nuggs_ri(cfg);
    ro      = nuggs_ro(cfg);
    r_out   = nuggs_r_out(cfg);
    t2      = cfg[_NC_PORT_TOL] / 2;
    i_out   = nuggs_i_out(cfg);
    i_in    = ro + t2;                        // bore-side face, PROJECTING half
    o_in    = nuggs_r_mid(cfg) + t2;          // outer shell inner face
    rin     = ri - cfg[_NC_ANCHOR_BITE];      // buried inside the bore
    rib_in  = nuggs_rib_in(cfg);
    z_tip   = nuggs_z_tip(cfg);
    z_seat  = nuggs_z_seat(cfg);
    z_top   = nuggs_z_top(cfg);
    eps     = cfg[_NC_EPS];
    n_lug   = cfg[_NC_N_LUG];
    lug_deg = cfg[_NC_LUG_DEG];
    difference() {
        union() {
            translate([0, 0, z_seat])                              // (a) collar
                difference() {
                    cylinder(r = o_in + cfg[_NC_COLLAR_BITE], h = cfg[_NC_COLLAR_T]);
                    translate([0, 0, -eps])
                        cylinder(r = rin, h = cfg[_NC_COLLAR_T] + 2 * eps);
                }
            for (i = [0 : n_lug - 1])                       // (b) outer sectors
                rotate([0, 0, _nuggs_outer_a(cfg, i)])
                    nuggs_sector([[o_in, z_tip], [r_out, z_tip],
                                  [r_out, z_top], [o_in, z_top]], lug_deg);
            for (i = [0 : n_lug - 1])                       // (c) inner sectors
                rotate([0, 0, _nuggs_inner_a(cfg, i)])
                    nuggs_sector([[i_in, z_tip], [i_out, z_tip], [i_out, z_top],
                                  [rin, z_top], [rin, 0], [i_in, 0]], lug_deg);
            for (i = [0 : n_lug - 1])                        // (d) locking ribs
                rotate([0, 0, _nuggs_outer_a(cfg, i)])
                    nuggs_sector([[rib_in, z_tip], [o_in + cfg[_NC_BITE], z_tip],
                                  [o_in + cfg[_NC_BITE], z_tip + cfg[_NC_RIB_W]],
                                  [rib_in, z_tip + cfg[_NC_RIB_W]]],
                                 cfg[_NC_RIB_DEG]);
        }
        for (i = [0 : n_lug - 1])
            _nuggs_bayonet_groove(cfg, _nuggs_inner_a(cfg, i));
    }
}

// The bore cut every caller of nuggs_port() owes. Subtract it over at least
// z_tip..z_top; a design with a port at each end of a tube cuts once, through
// the whole part.
//   r   defaults to ri. A module whose void is LARGER than the bore (a gabled
//       crown, a chamber) may pass more, never less — hence the assert.
module nuggs_bore_cut(cfg, z0, z1, r = undef) {
    $fa = _NUGGS_FA; $fs = _NUGGS_FS; $fn = 0;
    rr = is_undef(r) ? nuggs_ri(cfg) : r;
    assert(rr >= nuggs_ri(cfg), str(
        "NUGGS BORE CUT: r = ", rr, " is inside the bore radius ", nuggs_ri(cfg),
        ". A bore cut may only ever open the bore up, never neck it down."));
    assert(z1 > z0, str(
        "NUGGS BORE CUT: z1 = ", z1, " must be above z0 = ", z0,
        "; a non-positive height renders as nothing and leaves the port's",
        " material standing in the bore with no warning."));
    translate([0, 0, z0]) cylinder(r = rr, h = z1 - z0);
}

// A bore-clean port with `len` mm of full-round ri..ro shell behind it: port
// ring, shell, and the mandatory bore cut, as one solid. This is the module a
// non-round body should actually call, and the reason it exists is not
// convenience — it is that the port's inner sectors fuse to a FULL-ROUND shell.
// Fuse them to the edge of a window instead and they snap off, silently,
// watertight, one body. `len` is asserted >= z_top for exactly that reason.
module nuggs_neck(cfg, len) {
    $fa = _NUGGS_FA; $fs = _NUGGS_FS; $fn = 0;
    z_top = nuggs_z_top(cfg);
    assert(len >= z_top, str(
        "NUGGS NECK: len = ", len, " mm is shorter than the port zone z_top = ",
        z_top, " mm. Every port face must be backed by at least that much",
        " FULL-ROUND shell, or its inner sectors have no ring to fuse to."));
    difference() {
        union() {
            cylinder(r = nuggs_ro(cfg), h = len);
            nuggs_port(cfg);
        }
        nuggs_bore_cut(cfg, nuggs_z_tip(cfg) - 1, len + 1);
    }
}

// The longitudinal window that turns a neck-and-tube into an OPEN MODULE: a
// tube with a window, whose floor is therefore still the ri arc. Subtract it
// from the body between z0 and z1.
//
// The window is centred on +X, which is the module's crown; the invert (-X) is
// the floor the animal walks on. z0 is asserted at or above z_top so the window
// never reaches the neck, and open_deg is asserted clear of the walk band on
// both sides. A window of open_deg >= 180 leaves the wall tops at or below the
// springline, so the opening is the widest part of the void and the animal
// lifts straight out; that is the geometric argument, and it is judgement, not
// a sourced threshold.
module nuggs_window(cfg, z0, z1, open_deg) {
    $fa = _NUGGS_FA; $fs = _NUGGS_FS; $fn = 0;
    z_top = nuggs_z_top(cfg);
    max_open = 360 - 2 * _NUGGS_WALK_HALF_DEG;
    assert(open_deg > 0 && open_deg <= max_open, str(
        "NUGGS WINDOW: open_deg = ", open_deg, " must be in (0, ", max_open,
        "]. Beyond that the window eats into the walk band (+/-",
        _NUGGS_WALK_HALF_DEG, " deg about the invert) and the module stops",
        " presenting the ri arc a round mate's bore is continuous with."));
    assert(z0 >= z_top, str(
        "NUGGS WINDOW: z0 = ", z0, " cuts into the port zone, which ends at",
        " z_top = ", z_top, ". A window through the neck leaves the port's",
        " inner sectors fused to a window edge instead of a ring; they snap",
        " off and the mesh never says a word."));
    assert(z1 > z0, str(
        "NUGGS WINDOW: z1 = ", z1, " must be above z0 = ", z0, "."));
    // The cut's inner bound runs 1 mm INSIDE the bore radius rather than at it.
    // Everything between there and ri is void in any conforming body, so this
    // removes nothing extra — but a cutter bounded exactly at ri would face the
    // body's own bore across a near-coincident cylindrical pair (the two are
    // swept at different angles, so their polygonal radii differ by the chord
    // sagitta, 0.0137 mm at ri = 40) and CGAL answers that with slivers and a
    // 2-manifold warning. Measured: at ri - eps the window's own control case
    // warned; at ri - 1 it does not, and the cut volume is unchanged.
    rotate([0, 0, -open_deg / 2])
        nuggs_sector([[nuggs_ri(cfg) - 1, z0],
                      [nuggs_r_out(cfg) + 1, z0],
                      [nuggs_r_out(cfg) + 1, z1],
                      [nuggs_ri(cfg) - 1, z1]], open_deg);
}
