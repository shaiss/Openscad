// printer-conf.scad — the printer profile a design reads to pre-fill its
// tuned-fit parameters, instead of shipping a generic clearance that ignores
// the machine it will print on. Part of the lightweight print-feedback loop
// (issue #101); the convention is documented in docs/print-feedback.md.
//
// Two files, one mechanism:
//   * this library defines GENERIC DEFAULTS for every profile value, so a
//     consumer always has a sane number even when nothing is measured;
//   * `include <printer.conf>` at the repo root then OVERRIDES any of them
//     with the values a user measured. OpenSCAD resolves a top-level variable
//     to its LAST assignment, so the profile always wins over the default.
//
// printer.conf is committed as an inert stub (it overrides nothing) precisely
// so this include always resolves — a missing include is a fatal "wrong
// geometry" warning in scripts/check.sh, not a silent no-op. Leaving it inert
// is the feature's off state: consumers fall back to the defaults below.
//
// A design opts in by `include <printer-conf.scad>` (include, not use — it is
// the variables you want, the way a style pack is included for its tokens),
// then reads printer_xy_tol / printer_nozzle_d / printer_material, or calls
// printer_fit() to grow a nominal horizontal dimension by the measured
// clearance. Nothing in the toolchain includes this file unless a design opts
// in, so it adds no dependency to designs that do not.
//
// All dimensions in millimeters.

// --- generic FDM defaults (used when printer.conf overrides nothing) --------
printer_xy_tol   = 0.20;   // measured horizontal fit clearance (press/slide)
printer_nozzle_d = 0.40;   // nozzle diameter
printer_material = "PLA";  // default material

// The repo-level measured profile. Committed inert; overrides any of the
// defaults above when a user fills it in. Resolved via OPENSCADPATH's repo-root
// entry, exactly like `include <styles/<name>/style.scad>`.
include <printer.conf>

// Grow a nominal horizontal dimension by the measured fit clearance. Reads the
// resolved printer_xy_tol (default or profile override), so a design writes
// printer_fit(slot_width) once and gets the right clearance per printer.
function printer_fit(nominal) = nominal + printer_xy_tol;
