// Selftest fixture for scripts/lineage.sh: an override that really binds.
//
// `include` pulls in base.scad's definitions AND its top-level call; redefining
// lid() afterwards reroutes the base's own call site to this version, so the
// rendered mesh is this cylinder and not the base's cube. That difference is
// the only evidence an override took, so the selftest asserts the two meshes
// hash differently — i.e. that gate.sh's override check can recognise success.

include <base.scad>

module lid() {
    cylinder(h = 2, r = 5, center = true);
}
