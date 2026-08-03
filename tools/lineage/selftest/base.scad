// Selftest fixture for scripts/lineage.sh — never printed, never gated as a
// design. Rendered only so `./scripts/lineage.sh selftest` can prove the
// derivative gate in scripts/gate.sh can still tell a working override from a
// silently-broken one on whatever OpenSCAD this machine has.
//
// This is an ordinary entry point, shaped like every design in designs/: it
// defines a module and calls it at the top level. It plays two parts in the
// selftest — the mesh a derivative's override has to differ from, and the
// NOT-base-safe half of the base-safety proof, since its top level emits
// geometry that a diamond would evaluate and union twice.

// Coarse on purpose: these renders exist to be hashed, not looked at, and a
// smooth cylinder would only make the selftest slower.
$fn = 8;

module lid() {
    cube([10, 10, 2], center = true);
}

lid();
