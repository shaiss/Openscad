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
//             high row numbers (~7 mm) until it stops, then lift
//             it out to reveal (and eat!) the sushi below.
//             Closed shutters are locked and cannot be lifted.
//
//  Printing: both parts print flat, no supports.
//  The top prints with all doors captive in place; a one-layer
//  sacrificial membrane under each window keeps the first door
//  layer bridging cleanly - punch the membranes out afterwards
//  and work each door loose with one firm slide.
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
// mm, gap under the door (bridge height)
gap_z    = 0.4;
// mm, sacrificial layer under each window - punch out after printing
membrane = 0.3;

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
slide    = 2*m_y - 1;                                 // opening travel
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

assert(slide >= tab_len + 1.2, "slide travel too short to free the tabs");
assert(lip_d - clr_h >= 2,     "not enough lip engagement");

echo(str("Cell pitch: ", pitch, " mm, window: ", opening, " mm"));
echo(str("Lid footprint: ", lid_x, " x ", lid_y, " mm"));
echo(str("Tray footprint: ", 2*tray_ox, " x ", 2*tray_oy, " x ", tray_h, " mm"));
echo(str("Door slide travel: ", slide, " mm"));

eps = 0.01;

// column letter + row number, e.g. "B3"
function cell_label(i, j) = str(chr(65 + i), j + 1);
function cell_cx(i) = (i - (grid_x - 1)/2) * pitch;
function cell_cy(j) = (j - (grid_y - 1)/2) * pitch;

// ============================================================
//  SHUTTER DOOR (origin = cell centre, z = 0 at lid plate top)
// ============================================================
module door(label = "A1") {
    difference() {
        union() {
            // body
            translate([-door_w/2, -door_l/2, gap_z])
                cube([door_w, door_l, door_t]);
            // 3 locking tabs per side (bottom slab sticking out sideways)
            for (s = [-1, 1], c = [-tab_c, 0, tab_c])
                translate([s*door_w/2 - (s < 0 ? tab_w : 0),
                           c - tab_len/2, gap_z])
                    cube([tab_w, tab_len, tab_t]);
            // grip bar near the front edge
            translate([-9, -door_l/2 + 2, gap_z + door_t - eps])
                cube([18, 3.2, 2.4]);
        }
        // engraved coordinate
        translate([0, -1, gap_z + door_t - 0.6])
            linear_extrude(0.7)
                text(label, size = 9, halign = "center", valign = "center",
                     font = "DejaVu Sans:style=Bold");
        // engraved "push this way" arrow
        translate([0, door_l/2 - 9, gap_z + door_t - 0.6])
            linear_extrude(0.7)
                polygon([[-3.5, 0], [3.5, 0], [0, 4.5]]);
    }
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

            // rail walls along every column boundary
            for (i = [0 : grid_x])
                translate([-play_x/2 + i*pitch - rail_w/2, -lid_y/2 + 1, plate_t])
                    cube([rail_w, lid_y - 2, rail_h]);

            // castellated lips (3 per rail side per cell), 45 deg underside
            for (i = [0 : grid_x - 1], j = [0 : grid_y - 1],
                 s = [-1, 1], c = [-tab_c, 0, tab_c])
                translate([cell_cx(i) + s*(pitch/2 - rail_w/2),
                           cell_cy(j) + c + tab_len/2, plate_t])
                    rotate([90, 0, 0])
                        linear_extrude(tab_len)
                            polygon([[0, lip_z],
                                     [-s*lip_d, lip_z + lip_d],
                                     [-s*lip_d, rail_h],
                                     [0, rail_h]]);

            // door end-stop ridges on every row boundary
            for (i = [0 : grid_x - 1], j = [0 : grid_y])
                translate([cell_cx(i) - 21,
                           -play_y/2 + j*pitch + m_y - 1, plate_t])
                    cube([42, 0.8, 1.4]);
        }

        // windows (with chamfered top edge)
        for (i = [0 : grid_x - 1], j = [0 : grid_y - 1])
            translate([cell_cx(i), cell_cy(j), 0]) {
                translate([0, 0, membrane])
                    linear_extrude(plate_t)
                        square(opening, center = true);
                translate([0, 0, plate_t - 0.8])
                    linear_extrude(0.81, scale = (opening + 1.6)/opening)
                        square(opening, center = true);
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
