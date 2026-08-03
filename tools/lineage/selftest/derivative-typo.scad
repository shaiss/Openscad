// Selftest fixture for scripts/lineage.sh: the failure the override check
// exists to catch.
//
// `Lid` is not `lid`, so nothing here overrides anything — and OpenSCAD reports
// that in no way whatsoever. No WARNING, no ERROR, exit 0, and a watertight STL
// that printcheck scores 100/100. What you get is the base's part, unchanged,
// wearing the derivative's name. The single observable trace is that the mesh
// comes out byte-identical to base.scad's, which is the signature gate.sh keys
// on; if this fixture ever stops reproducing the base mesh exactly, the gate
// has lost the ability to see a misspelled override and the selftest is what
// says so before a derivative ships the wrong part.

include <base.scad>

module Lid() {
    cylinder(h = 2, r = 5, center = true);
}
