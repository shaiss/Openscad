// Smoke test / visual demo for nuggs-coupling.scad.
// Not a printable design — rendered by scripts/check.sh to catch regressions.
// All dimensions in millimeters.

use <nuggs-coupling.scad>

// Deliberately hostile, and deliberately left in. The library pins its own
// $fa/$fs inside every geometry module body, so this line reaches NONE of the
// coupling geometry below — verified on the open module of specimen 3 (which
// exercises nuggs_neck, nuggs_port, nuggs_bore_cut, nuggs_sector and
// nuggs_window between them): 2716 facets and 30257.724763505 mm3 at $fn of 16,
// 48, 96 and 128 alike. What it does still reach is this file's own scaffolding
// — the plate in specimen 7 and the shell in specimen 2 are plain cylinders and
// belong to the demo, not to the library. Before the pin the coupling's
// realised clearance at the shell split moved with exactly this number, which
// made "one genderless interlock shared by every module" false for any second
// consumer with a different quality preset.
$fn = 48;

// The reference configuration: the NUGGS standard's own numbers, so a change
// that would alter designs/nuggs shows up here first.
cfg = nuggs_cfg();

// 1. The reference neck — a bore-clean port face on 30 mm of full-round shell.
//    This is what nuggs_neck() is for and what every other specimen is measured
//    against. Its fit is tested in lib/nuggs-coupling-mates.conf, not here.
nuggs_neck(cfg, 30);

// 2. THE FOOTGUN, worked. nuggs_port() emits material INSIDE the bore, at the
//    backing collar and at the inner sectors' anchoring half, because that is
//    how those features fuse to the tube. Drop the nuggs_bore_cut() line and
//    this specimen comes out with 2304.7 mm3 of plastic standing in an 80 mm
//    bore — watertight, one body, sliceable, and scoring 100/100. It is the
//    same shape of footgun as thread_bore_cut()'s mandatory minor bore, and it
//    is held down the same way: bore-clean-neck / bore-footgun-raw-port in
//    lib/nuggs-coupling-mates.conf measure it, this only shows it.
translate([120, 0, 0]) difference() {
    union() {
        cylinder(r = nuggs_ro(cfg), h = 30);
        nuggs_port(cfg);
    }
    nuggs_bore_cut(cfg, nuggs_z_tip(cfg) - 1, 31);        // <- mandatory
}

// 3. AN OPEN MODULE: a tube with a 180 deg longitudinal window. Its floor is
//    still the ri arc, so a round mate's bore is continuous with it to 0.000 mm
//    at every lateral position — which is the whole reason the window is a
//    window and not a redesign of the section. The window starts at z_top, so
//    the port face keeps its full-round backing; cut it any lower and the inner
//    sectors fuse to a window edge instead of a ring.
translate([240, 0, 0]) difference() {
    nuggs_neck(cfg, 40);
    nuggs_window(cfg, nuggs_z_top(cfg), 41, 180);
}

// 4. A SECOND BORE, at the welfare floor. 70 mm is the smallest bore_d the
//    library accepts, so this is the accepting half of the bore-floor guard
//    whose refusing half is `bore-floor` in lib/nuggs-coupling-guards.conf.
//    Every coupling radius and the flank angle with them are derived from
//    bore_d; that they still mate at a second bore is proved on the mesh in
//    lib/nuggs-coupling-mates.conf, not asserted here.
translate([360, 0, 0]) nuggs_neck(nuggs_cfg(bore_d = 70), 20);

// 5. THE ACCEPTING HALF OF THE WEB BOUND.
//
//    port_tol = 0.60 is the top of the band the library documents as tunable,
//    and at the shipped rib_h = 1.0 it lands the inner sector's web at exactly
//    2*nozzle = 0.80 mm — precisely on the guard. So the knob a user is invited
//    to turn already reaches the edge, and this proves the CONDITION admits it.
//
//    Its partner is `web-boundary` in lib/nuggs-coupling-guards.conf, which
//    carries the refusing half at rib_h = 1.05 (web 0.75). Split this way
//    because a guard manifest can only express refusals, so "0.80 is accepted"
//    has nowhere to live but a render. Drop this specimen and a guard that
//    tightened past its own documented band would keep every check in the repo
//    green while refusing the tolerance the docs tell people to use.
translate([480, 0, 0]) nuggs_neck(nuggs_cfg(port_tol = 0.60), 20);

// 6. nuggs_sector() on its own — the ONE-swept-polygon primitive every surface
//    of the coupling is built from. Shown as the bare annular sector it is.
translate([600, 0, 0])
    nuggs_sector([[nuggs_ro(cfg), 0], [nuggs_r_out(cfg), 0],
                  [nuggs_r_out(cfg), 6], [nuggs_ro(cfg), 6]], nuggs_pitch(cfg));

// 7. THE MIRROR-AND-LIFT RECIPE, which is a silent CRITICAL if you get it
//    wrong. nuggs_port() puts its tube body on +z and its coupling sectors on
//    -z. Placed unmirrored on a flange it points every sector at the bed: 30%
//    overhang, printcheck CRITICAL, gate exit 1. On a flange it is always
//    mirrored and lifted by z_top, which is what this specimen shows — the
//    bulkhead_out arrangement, reduced to its two lines.
translate([720, 0, 0]) difference() {
    union() {
        cylinder(r = nuggs_r_out(cfg) + 4, h = 4);
        translate([0, 0, nuggs_z_top(cfg)]) mirror([0, 0, 1]) nuggs_port(cfg);
    }
    nuggs_bore_cut(cfg, -1, nuggs_z_top(cfg) + nuggs_z_seat(cfg) + 1);
}

// The contract values a design has to be able to ask for rather than re-derive.
// Every one of these was a reach into a global in designs/nuggs — the bore
// cuts, the revision mark's placement, bulkhead_out's lift, the coupon's
// spacing — and each is a caller obligation, so each has to be callable or the
// library is unusable at a second bore.
echo(str("nuggs-coupling frame: ri = ", nuggs_ri(cfg), ", ro = ", nuggs_ro(cfg),
         ", r_mid = ", nuggs_r_mid(cfg), ", r_out = ", nuggs_r_out(cfg),
         ", pitch = ", nuggs_pitch(cfg), ", z_tip = ", nuggs_z_tip(cfg),
         ", z_seat = ", nuggs_z_seat(cfg), ", z_top = ", nuggs_z_top(cfg)));
echo(str("nuggs-coupling clockings [insert, lock-, lock+] = ",
         nuggs_clockings(cfg), " deg; walk band +/-",
         nuggs_walk_half_deg(), " deg about the invert"));

// The engagement band and what it delivers. These are REPORTED, not verified:
// nuggs_tol_deg() is the derivation itself, so echoing the clearance it implies
// would print the identity that defines it and prove nothing about the built
// geometry. That is not hypothetical — this library's sibling printed
// "0.3 (should equal 0.3)" for the whole period its geometry delivered 0.2794
// (issue #37), and it could not have said otherwise. The clearance is measured
// against the exported mesh in lib/nuggs-coupling-mates.conf.
echo(str("nuggs-coupling band: rib_in = ", nuggs_rib_in(cfg), " .. i_out = ",
         nuggs_i_out(cfg), ", flank angle at rib_in = ",
         nuggs_tol_deg(cfg, nuggs_rib_in(cfg)), " deg",
         "  -- realised clearance is measured in nuggs-coupling-mates.conf"));
echo(str("nuggs-coupling: bearing area ", nuggs_bearing_area(cfg),
         " mm2 from ONE of the two rib sets (never both at once), inner-sector",
         " web ", nuggs_web(cfg), " mm"));
