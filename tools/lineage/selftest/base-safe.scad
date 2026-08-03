// Selftest fixture for scripts/lineage.sh: what "base-safe" has to mean.
//
// `include` is not guarded — a diamond (two parents that both include the same
// ancestor) evaluates that ancestor twice, and every facet its top level emits
// is unioned in twice over. The duplicate unions cleanly, stays watertight and
// scores 100/100, so nothing downstream can see it. The only design that can
// safely sit at the confluence is one whose top level defines modules and emits
// nothing, like this one.
//
// OpenSCAD renders this to nothing at all: it prints "Current top level object
// is empty", exits 1, and writes NO output file. That is why the facet-count
// helper reads a missing file as zero facets instead of as a render failure —
// the passing case of the base-safety proof produces no STL to count.

$fn = 8;

module lid() {
    cube([10, 10, 2], center = true);
}
