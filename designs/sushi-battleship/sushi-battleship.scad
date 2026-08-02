// sushi-battleship — two-part game board for playing battleship
// with sushi rolls.
// Requirements and decisions: see NOTES.md next to this file.
// All dimensions in millimeters.
//
//  * bottom : tray with a grid of cells (one sushi piece each),
//             low dividers, tall raised outer walls and a rebate
//             the lid drops into.
//  * top    : lid with one print-in-place sliding shutter per
//             cell.  On a "hit", slide the shutter toward the
//             high row numbers (~6.7 mm at defaults) until it
//             stops, then lift it out to reveal (and eat!) the
//             sushi below.  Closed shutters are locked and
//             cannot be lifted.
//
//  Printing: both parts print flat, no supports.
//  The top prints with all doors captive in place.  Each door's
//  first layer bridges its window in free air; the one-layer
//  sacrificial membrane at the bottom of each window only
//  catches drooped strands (it sits ~3 mm below the door and
//  does NOT support the bridge).  After printing, free each
//  door with one firm push toward its arrow, then punch the
//  membranes out.
// ============================================================

/* [Quality] */
// Production values; the only curved features are the thumb notches,
// so these are cheap enough to iterate with as well.
$fs = 0.5;
$fa = 4;

/* [What to render] */
// assembled = preview; bottom / top / door are the printable parts
part = "assembled";   // [assembled, bottom, top, door]
// in "assembled" view, show one shutter slid open and lifted
demo_open = true;

/* [Board] */
// columns (letters)
grid_x = 4;
// rows (numbers) - doors slide toward the high row numbers
grid_y = 4;
// mm, diameter of a cut sushi-roll piece the cells must fit
roll_d = 40;
// mm, height of a piece standing on the board
roll_h = 30;
// mm, lid margin around the play field (labels live here)
border  = 9;
// mm, lid plate thickness
plate_t = 3;
// mm, tray floor thickness
floor_t = 3;

/* [Slider mechanism] */
// mm, shutter plate thickness
door_t   = 2.4;
// mm, shutter side-tab thickness (bottom layer of the door)
tab_t    = 1.2;
// mm, how far tabs stick out sideways
tab_w    = 3.5;
// mm, length of each of the 3 tabs / lips
tab_len  = 5.5;
// mm, lip overhang from the rail wall (45 deg underside)
lip_d    = 3.2;
// mm, rail wall thickness (shared between columns)
rail_w   = 2.4;
// mm, solid lip height above the 45 deg chamfer
rail_ext = 0.8;

/* [Print tuning] */
// mm, horizontal print-in-place clearance (increase if doors stick)
clr_h    = 0.5;
// mm, vertical print-in-place clearance
clr_v    = 0.4;
// mm, air gap under the door: stays >= 2 air layers at any layer
// height up to 0.3 mm (see the quantization table in NOTES.md)
gap_z    = 0.6;
// mm, sacrificial layer under each window - punch out after printing.
// 0.2 sits on the layer grid: exactly one printed layer at the common
// presets (0.3 landed mid-layer and could coin-flip into two layers)
membrane = 0.2;
// mm, door-only fit adjustment: shrinks the door body and tabs
// symmetrically (+ = looser, - = tighter). Tune in +-0.1 steps on the
// coupon or a spare door; the lid and tray are untouched, so a tuned
// door drops straight into an already-printed board
door_fit = 0;
// mm, window lead-in chamfer on the rear (slide-crossing) edge: ramps
// a sagged door belly over the edge instead of jamming against it
chamfer_rear  = 1.6;
// mm, window chamfer on the front edge (kept small to preserve the
// 1.2 mm bridge-anchor strip under the door's front edge)
chamfer_front = 0.8;
// mm, edge break on the window side edges (door never crosses these;
// smaller chamfer leaves a wider landing under the door's long edges)
chamfer_side  = 0.3;

/* [Tray] */
// mm, cell divider height above the floor
divider_h = 14;
// mm, inner depth of the tray
cavity_h  = roll_h + 8;
// mm, raised rim standing proud around the lid
rim_h     = 3.4;
// mm, thumb notches for lifting the lid out of the tray
notch_r   = 6;

/* [Hidden] */

// -------------------- derived dimensions --------------------
opening  = roll_d + 6;                                // lid window
pitch    = opening + rail_w + 2*clr_h + 2*tab_w + 1.6; // cell pitch
door_w   = opening + 1.6;                             // door body width
door_l   = opening + 4;                               // door length
m_y      = (pitch - door_l)/2;                        // door end margin
ridge_w   = 0.8;                                      // end-stop ridge width
ridge_gap = clr_h;    // ridge to closed-door face; printable, not weldable
slide    = 2*m_y - ridge_w - ridge_gap;               // opening travel
rail_h   = gap_z + tab_t + clr_v - clr_h + lip_d + rail_ext; // above plate
lip_z    = gap_z + tab_t + clr_v - clr_h;             // lip root height

play_x   = grid_x * pitch;
play_y   = grid_y * pitch;
lid_x    = play_x + 2*border;
lid_y    = play_y + 2*border;

ledge    = 2;         // tray ledge width under the lid edge
tray_ix  = lid_x/2 - ledge;        // half size of inner cavity
tray_iy  = lid_y/2 - ledge;
tray_rx  = lid_x/2 + 0.35;         // half size of lid rebate (clearance)
tray_ry  = lid_y/2 + 0.35;
tray_ox  = tray_rx + 1.6;          // half size of tray outside
tray_oy  = tray_ry + 1.6;
ledge_z  = floor_t + cavity_h;     // lid rests here
tray_h   = ledge_z + rim_h;        // total tray height

tabspan  = opening - 10;                       // tabs stay inside this
tab_c    = (tabspan - tab_len)/2;              // outer tab centres

assert(slide - tab_len >= 1, "slide travel too short to free the tabs");
assert(lip_d - clr_h >= 2,     "not enough lip engagement");
assert(tab_c >= slide + tab_len + 0.5,
       "tabs would hit the lips at full slide; enlarge roll_d or shorten tab_len");
assert(door_fit >= -0.2 && door_fit <= 0.5,
       "door_fit outside the safe range (-0.2 .. 0.5)");
assert(chamfer_side == 0
       || chamfer_side < min(chamfer_front, chamfer_rear),
       "chamfer_side must stay below the front/rear chamfers so the side wedges can bury their ends in those cuts (mesh validity)");
assert(lip_d - clr_h - max(door_fit, 0) >= 1.5,
       "door_fit too loose; tabs would barely engage the lips");

echo(str("Cell pitch: ", pitch, " mm, window: ", opening, " mm"));
echo(str("Lid footprint: ", lid_x, " x ", lid_y, " mm"));
echo(str("Tray footprint: ", 2*tray_ox, " x ", 2*tray_oy, " x ", tray_h, " mm"));
echo(str("Door slide travel: ", slide, " mm"));

eps = 0.01;

// Lips stop this far below the rail top. A lip top exactly coplanar with
// the rail top leaves a shared-plane strip that the Manifold backend
// exports as a non-manifold seam (288 bad edges at z = rail top in CI);
// CGAL papered over the same seam as zero-area triangles. Purely a mesh-
// hygiene step on the non-functional filler web above the lip slope —
// engagement geometry (lip_z .. lip_z + lip_d) is untouched.
lip_top_drop = 0.4;
assert(rail_ext > lip_top_drop, "lip_top_drop must stay below rail_ext");

// column letter + row number, e.g. "B3"
function cell_label(i, j) = str(chr(65 + i), j + 1);
function cell_cx(i) = (i - (grid_x - 1)/2) * pitch;
function cell_cy(j) = (j - (grid_y - 1)/2) * pitch;

// ============================================================
//  SHUTTER DOOR (origin = cell centre, z = 0 at lid plate top)
// ============================================================
module door(label = "A1") {
    // door_fit shrinks (+) or grows (-) the door symmetrically; the
    // lid geometry never changes, so a re-tuned door stays a drop-in
    dw = door_w - 2*door_fit;      // effective body width
    dl = door_l - 2*door_fit;      // effective body length
    gw = min(18, dw - 10);         // grip bar width
    difference() {
        union() {
            // body
            translate([-dw/2, -dl/2, gap_z])
                cube([dw, dl, door_t]);
            // 3 locking tabs per side (bottom slab sticking out sideways)
            for (s = [-1, 1], c = [-tab_c, 0, tab_c])
                translate([s*dw/2 - (s < 0 ? tab_w : 0),
                           c - tab_len/2, gap_z])
                    cube([tab_w, tab_len, tab_t]);
            // grip bar near the front edge
            translate([-gw/2, -dl/2 + 2, gap_z + door_t - eps])
                cube([gw, 3.2, 2.4]);
        }
        // engraved coordinate
        translate([0, -1, gap_z + door_t - 0.6])
            linear_extrude(0.7)
                text(label, size = 9, halign = "center", valign = "center",
                     font = "DejaVu Sans:style=Bold");
        // engraved "push this way" arrow
        translate([0, dl/2 - 9, gap_z + door_t - 0.6])
            linear_extrude(0.7)
                polygon([[-3.5, 0], [3.5, 0], [0, 4.5]]);
    }
}

// 45-degree lead-in wedge cut along the +Y window edge (rotate into
// place for the other edges); cell-local coordinates, z = plate bottom.
// `len` is the wedge length along the edge. An end face must never land
// exactly on another wedge's 45-degree slope: the two cut volumes then
// touch at a single point, and the CGAL difference exports that kiss as
// a zero-volume two-triangle shell (non-manifold STL). Ends must sit
// strictly inside a crossing cut, or strictly clear of it.
module window_wedge(d, len) {
    if (d > 0)
        translate([-len/2, 0, 0])
            rotate([90, 0, 90])
                linear_extrude(len)
                    polygon([[opening/2,     plate_t - d],
                             [opening/2,     plate_t + 1],
                             [opening/2 + d, plate_t + 1],
                             [opening/2 + d, plate_t]]);
}

// ============================================================
//  LID (origin = board centre, z = 0 at plate bottom)
// ============================================================
module lid_body() {
    difference() {
        union() {
            // plate
            translate([-lid_x/2, -lid_y/2, 0])
                cube([lid_x, lid_y, plate_t]);

            // perimeter frame
            linear_extrude(plate_t + rail_h)
                difference() {
                    square([lid_x, lid_y], center = true);
                    square([lid_x - 2*rail_w, lid_y - 2*rail_w], center = true);
                }

            // rail walls along every column boundary (buried eps into the
            // plate: an exact z = plate_t seat is a kiss contact — CGAL
            // fuses it, Manifold exports it as a separate shell)
            for (i = [0 : grid_x])
                translate([-play_x/2 + i*pitch - rail_w/2, -lid_y/2 + 1,
                           plate_t - eps])
                    cube([rail_w, lid_y - 2, rail_h + eps]);

            // castellated lips (3 per rail side per cell), 45 deg underside;
            // root edge buried s*eps into the rail wall so the lip and rail
            // share volume, not just a face (see rail-wall comment)
            for (i = [0 : grid_x - 1], j = [0 : grid_y - 1],
                 s = [-1, 1], c = [-tab_c, 0, tab_c])
                translate([cell_cx(i) + s*(pitch/2 - rail_w/2),
                           cell_cy(j) + c + tab_len/2, plate_t])
                    rotate([90, 0, 0])
                        linear_extrude(tab_len)
                            polygon([[s*eps, lip_z],
                                     [-s*lip_d, lip_z + lip_d],
                                     [-s*lip_d, rail_h - lip_top_drop],
                                     [s*eps, rail_h - lip_top_drop]]);

            // door end-stop ridges on every row boundary (kept narrower than
            // the door body so they never reach the tab/lip zone, and a full
            // ridge_gap away from the closed door face so the door's first
            // layer cannot weld to them)
            for (i = [0 : grid_x - 1], j = [0 : grid_y])
                translate([cell_cx(i) - (door_w/2 - 2.8),
                           -play_y/2 + j*pitch + m_y - ridge_w - ridge_gap,
                           plate_t - eps])
                    cube([door_w - 5.6, ridge_w, 1.4 + eps]);
        }

        // windows, with per-edge 45-degree lead-in chamfers (deep ramp on
        // the rear edge the sliding door crosses, small front chamfer to
        // keep the bridge-anchor strip, edge break only on the sides)
        for (i = [0 : grid_x - 1], j = [0 : grid_y - 1])
            translate([cell_cx(i), cell_cy(j), 0]) {
                translate([0, 0, membrane])
                    linear_extrude(plate_t)
                        square(opening, center = true);
                rotate([0, 0, 0])
                    window_wedge(chamfer_rear,  opening + 2*chamfer_rear + 2);
                rotate([0, 0, 180])
                    window_wedge(chamfer_front, opening + 2*chamfer_front + 2);
                // Side wedges end past the window wall but short of the
                // front/rear wedges' apex-height crossings, so each end
                // face is strictly contained inside those bigger cuts: an
                // end face exactly on a neighbouring wedge's slope is a
                // point contact that exports as a non-manifold sliver
                // (exactly where chamfer_rear = 1.6 landed the old
                // opening + 2*d + 2 length), and an end at opening/2
                // alone would be coplanar with the window wall. Burial
                // needs chamfer_side < min(chamfer_front, chamfer_rear)
                // -- see the assert next to the chamfer parameters.
                for (r = [90, 270])
                    rotate([0, 0, r])
                        window_wedge(chamfer_side,
                                     opening + min(chamfer_front, chamfer_rear)
                                             - chamfer_side);
            }

        // column letters on the front border
        for (i = [0 : grid_x - 1])
            translate([cell_cx(i), -(play_y/2 + (border - rail_w)/2 + rail_w/2 - 1),
                       plate_t - 0.6])
                linear_extrude(0.7)
                    text(chr(65 + i), size = 4.8, halign = "center",
                         valign = "center", font = "DejaVu Sans:style=Bold");

        // row numbers on the left border
        for (j = [0 : grid_y - 1])
            translate([-(play_x/2 + (border - rail_w)/2 + rail_w/2 - 1),
                       cell_cy(j), plate_t - 0.6])
                linear_extrude(0.7)
                    text(str(j + 1), size = 4.8, halign = "center",
                         valign = "center", font = "DejaVu Sans:style=Bold");
    }
}

// lid with all shutters captive (this is the print-in-place top)
module lid_assembly(open_i = -1, open_j = -1, open_lift = 0) {
    lid_body();
    for (i = [0 : grid_x - 1], j = [0 : grid_y - 1]) {
        opened = (i == open_i && j == open_j);
        translate([cell_cx(i),
                   cell_cy(j) + (opened ? slide : 0),
                   plate_t + (opened ? open_lift : 0)])
            door(cell_label(i, j));
    }
}

// ============================================================
//  TRAY (origin = board centre, z = 0 at the bed)
// ============================================================
module tray() {
    difference() {
        union() {
            // shell
            difference() {
                translate([-tray_ox, -tray_oy, 0])
                    cube([2*tray_ox, 2*tray_oy, tray_h]);
                // cavity
                translate([-tray_ix, -tray_iy, floor_t])
                    cube([2*tray_ix, 2*tray_iy, tray_h]);
                // rebate the lid drops into
                translate([-tray_rx, -tray_ry, ledge_z])
                    cube([2*tray_rx, 2*tray_ry, rim_h + eps]);
            }
            // cell dividers
            for (i = [0 : grid_x])
                translate([-play_x/2 + i*pitch - 0.8, -play_y/2, floor_t - eps])
                    cube([1.6, play_y, divider_h]);
            for (j = [0 : grid_y])
                translate([-play_x/2, -play_y/2 + j*pitch - 0.8, floor_t - eps])
                    cube([play_x, 1.6, divider_h]);
        }

        // thumb notches in the rim to lift the lid out
        for (s = [-1, 1])
            translate([s*tray_ox, 0, tray_h + 1.5])
                rotate([90, 0, 0])
                    cylinder(r = notch_r, h = 30, center = true);

        // coordinate engraved in each cell floor
        for (i = [0 : grid_x - 1], j = [0 : grid_y - 1])
            translate([cell_cx(i), cell_cy(j), floor_t - 0.5])
                linear_extrude(0.6)
                    text(cell_label(i, j), size = 12, halign = "center",
                         valign = "center", font = "DejaVu Sans:style=Bold");

        // title on the front wall
        translate([0, -tray_oy + 0.8, (floor_t + ledge_z)/2])
            rotate([90, 0, 0])
                linear_extrude(1)
                    text("SUSHI  BATTLESHIP", size = 9, halign = "center",
                         valign = "center", font = "DejaVu Sans:style=Bold");
    }
}

// ============================================================
//  PART SELECTION
// ============================================================
if (part == "bottom") {
    tray();
} else if (part == "top") {
    lid_assembly();
} else if (part == "door") {
    translate([0, 0, -gap_z]) door("A1");
} else if (part == "top_open") {
    // lid only, shutter D1 slid fully open (tabs aligned with lip gaps)
    lid_assembly(open_i = grid_x - 1, open_j = 0, open_lift = 0);
} else if (part == "cutaway") {
    // X-Z section through the middle tab of cell B1: tab/lip stack,
    // gap_z air gap, membrane, side-edge chamfers
    intersection() {
        lid_assembly();
        translate([-lid_x/2 - 1, cell_cy(0) - 2, -1])
            cube([lid_x + 2, 4, 40]);
    }
} else if (part == "cutaway_slide") {
    // Y-Z section through the centre of column B: rear/front window
    // chamfers, end-stop ridge gap, grip bar profile
    intersection() {
        lid_assembly();
        translate([cell_cx(1) - 2, -lid_y/2 - 1, -1])
            cube([4, lid_y + 2, 40]);
    }
} else { // assembled
    color("LightSteelBlue") tray();
    translate([0, 0, ledge_z]) {
        if (demo_open)
            lid_assembly(open_i = grid_x - 1, open_j = 0, open_lift = 14);
        else
            lid_assembly();
    }
    // a sushi piece in the revealed cell, just for the preview
    if (demo_open && $preview)
        color("Salmon")
            translate([cell_cx(grid_x - 1), cell_cy(0), floor_t])
                cylinder(d = roll_d, h = roll_h);
}
