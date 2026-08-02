"""Measure shapes whose geometry we chose, and assert the numbers come back.

Every probe mesh is built from exact arcs and lines (examples/make_probe_models.py),
so these are truth comparisons, not snapshots: a 3 mm fillet has to measure 3 mm,
at any tessellation, in any pose, at any scale.
"""

import json

import numpy as np
import pytest
import trimesh

from make_probe_models import (chamfered_prism, chamfered_slab, drilled_plate,
                               rounded_prism, rounded_slab, sharp_prism,
                               shelled_tube, tapered_boss_plate)
from stylelift import measure
from stylelift.cli import main
from stylelift.emit import lift, render_tokens, sync
from stylelift.spec import Status, StyleSpec, conform, snap_fn, verdict


def save(tmp_path, mesh, name):
    """Export a probe mesh and return its path."""
    path = tmp_path / name
    mesh.export(str(path))
    return str(path)


def dominant(report):
    """The report's dominant outer radius, or None."""
    return report["edges"]["rounding"]["dominant_r_mm"]


# --------------------------------------------------------------------------
# Edge treatment
# --------------------------------------------------------------------------

def test_sharp_box_has_no_rounding(tmp_path):
    r = measure(save(tmp_path, sharp_prism(), "sharp.stl"))
    assert r["edges"]["softness"] == 0.0
    assert r["edges"]["rounding"]["convex"] == []
    assert r["edges"]["grammar"]["sharp_share"] == pytest.approx(1.0)


def test_rounded_box_recovers_its_radius(tmp_path):
    r = measure(save(tmp_path, rounded_prism(radius=3.0), "round.stl"))
    assert dominant(r) == pytest.approx(3.0, abs=0.01)
    assert r["edges"]["rounding"]["dominant_share"] > 0.9
    assert r["edges"]["rounding"]["implied_fn"] == pytest.approx(64, abs=1)
    assert r["edges"]["softness"] > 0.6
    assert r["edges"]["grammar"]["rounded_share"] > 0.6


@pytest.mark.parametrize("segments,expected_fn", [(4, 16), (8, 32), (32, 128)])
def test_radius_is_independent_of_tessellation(tmp_path, segments, expected_fn):
    # The whole method rests on this: a coarse export and a fine export of the
    # same design must report the same radius, only a different segment count.
    mesh = rounded_prism(radius=3.0, quarter_segments=segments)
    r = measure(save(tmp_path, mesh, f"round{segments}.stl"))
    assert dominant(r) == pytest.approx(3.0, abs=0.02)
    assert r["edges"]["rounding"]["implied_fn"] == pytest.approx(expected_fn, abs=1)


def test_measurements_survive_an_arbitrary_pose(tmp_path):
    # A downloaded STL is in whatever pose it was exported in.
    mesh = rounded_prism(radius=3.0)
    upright = measure(save(tmp_path, mesh, "upright.stl"))
    tumbled = mesh.copy()
    for angle, axis in ((37, [1, 0, 0]), (22, [0, 1, 0]), (61, [0, 0, 1])):
        tumbled.apply_transform(
            trimesh.transformations.rotation_matrix(np.radians(angle), axis))
    tumbled.apply_translation([123.0, -45.0, 7.5])
    rotated = measure(save(tmp_path, tumbled, "tumbled.stl"))
    assert dominant(rotated) == pytest.approx(dominant(upright), abs=0.02)
    assert rotated["edges"]["softness"] == pytest.approx(
        upright["edges"]["softness"], abs=0.01)


def test_radius_scales_with_the_part_but_softness_does_not(tmp_path):
    mesh = rounded_prism(radius=3.0)
    base = measure(save(tmp_path, mesh, "base.stl"))
    big = mesh.copy()
    big.apply_scale(2.5)
    scaled = measure(save(tmp_path, big, "big.stl"))
    assert dominant(scaled) == pytest.approx(7.5, abs=0.05)
    assert scaled["edges"]["softness"] == pytest.approx(
        base["edges"]["softness"], abs=0.01)


def test_chamfer_is_measured_as_a_chamfer_not_a_fillet(tmp_path):
    r = measure(save(tmp_path, chamfered_prism(leg=1.0), "chamfer.stl"))
    assert r["edges"]["chamfers"]["dominant_leg_mm"] == pytest.approx(1.0, abs=0.02)
    assert r["edges"]["chamfers"]["bands"][0]["turn_deg"] == pytest.approx(90, abs=1)
    # a chamfered box is not a soft box: nothing here curves
    assert r["edges"]["rounding"]["convex"] == []
    assert r["edges"]["softness"] == 0.0
    assert r["edges"]["grammar"]["chamfered_share"] > 0.15


@pytest.mark.parametrize("height", [2.0, 3.0, 8.0, 20.0])
def test_a_chamfer_reads_the_same_however_thin_the_plate(tmp_path, height):
    # Regression: chamfer-vs-curve used to be decided by comparing the band
    # against its neighbour's size, so the *same* 0.6 mm chamfer on a thinner
    # plate stopped looking like a chamfer once the wall above it got short —
    # and the part then reported a corner radius (2.12 mm) and a curve
    # resolution ($fn=8) that exist nowhere in it.
    r = measure(save(tmp_path, chamfered_slab(height=height, leg=0.6),
                     f"slab{height}.stl"))
    assert r["edges"]["chamfers"]["dominant_leg_mm"] == pytest.approx(0.6, abs=0.02)
    assert r["edges"]["chamfers"]["count"] == 4
    assert r["edges"]["rounding"]["dominant_r_mm"] is None


def test_a_coarse_curve_is_not_mistaken_for_chamfers(tmp_path):
    # The other side of that coin: an 8-sided cylinder has the same topology as
    # a chamfered box — eight faces meeting at eight 45-degree folds. What
    # separates them is that a chamfer is narrow between wide faces, while a
    # coarse curve's facets are all the same width. Read as chamfers, this
    # would report a 7.6 mm "chamfer leg" and lose the radius entirely.
    for sections in (8, 12, 20):
        barrel = trimesh.creation.cylinder(radius=10.0, height=20.0,
                                           sections=sections)
        r = measure(save(tmp_path, barrel, f"barrel{sections}.stl"))
        assert r["edges"]["chamfers"]["count"] == 0
        assert r["edges"]["form"]["dominant_r_mm"] == pytest.approx(10.0, abs=0.05)


def test_a_tapered_boss_is_not_a_corner_radius(tmp_path):
    # A bar with one plain draft-angled boss contains no fillet at all. The
    # radius identity assumes a cylinder's parallel-sided strip; a cone's strip
    # is a trapezoid, and applying the identity to it reported a 12.7 mm corner
    # radius over 95% of the curved length — a number belonging to no feature
    # of the part.
    r = measure(save(tmp_path, tapered_boss_plate(), "frustum.stl"))
    assert r["edges"]["rounding"]["dominant_r_mm"] is None
    assert r["edges"]["rounding"]["convex"] == []


def test_a_coarse_arc_reports_only_the_radius_it_has(tmp_path):
    # At $fn=8 a 3 mm fillet's strips are wide enough that the tangent fold
    # where the arc meets the flat face passes the width test, and each such
    # fold contributes twice the true radius. The dominant mode was 8.07 mm on
    # a part whose only radius is 3.
    mesh = rounded_prism(width=10, depth=10, height=40, radius=3.0,
                         quarter_segments=2)
    r = measure(save(tmp_path, mesh, "coarse.stl"))
    assert r["edges"]["rounding"]["dominant_r_mm"] == pytest.approx(3.0, abs=0.05)
    assert r["edges"]["rounding"]["dominant_share"] > 0.9


def test_grammar_shares_partition_the_shaped_edges(tmp_path):
    # rounded / chamfered / sharp are shares of one quantity, so they must sum
    # to 1. Adding chamfer length to hard length counted every chamfer's own
    # 45-degree bounding folds twice.
    for name, mesh in (("chamfer", chamfered_prism(leg=1.0)),
                       ("round", rounded_prism(radius=3.0)),
                       ("slab", chamfered_slab(height=8.0, leg=0.6))):
        g = measure(save(tmp_path, mesh, f"{name}.stl"))["edges"]["grammar"]
        assert sum(g.values()) == pytest.approx(1.0, abs=1e-6)


def test_shelled_does_not_depend_on_the_pose_of_the_file(tmp_path):
    # Everything else this tool measures is invariant under rotation; deciding
    # "is this a shell?" from the axis-aligned bounding box made this one metric
    # depend on how the exporter happened to orient the part, and a rotated
    # solid could mint a wall-thickness token for a style.
    for name, mesh, expected in (("tube", shelled_tube(wall=2.4), True),
                                 ("solid", sharp_prism(), False)):
        tumbled = mesh.copy()
        for angle, axis in ((17, [1, 0, 0]), (29, [0, 1, 0]), (41, [0, 0, 1])):
            tumbled.apply_transform(
                trimesh.transformations.rotation_matrix(np.radians(angle), axis))
        upright = measure(save(tmp_path, mesh, f"{name}.stl"))
        rotated = measure(save(tmp_path, tumbled, f"{name}-rot.stl"))
        assert upright["walls"]["shelled"] is expected
        assert rotated["walls"]["shelled"] is expected


def test_edge_rounding_is_kept_apart_from_bores(tmp_path):
    # A part rounded at 6 mm that also has 3.4 mm holes: the corner radius is
    # 6 mm and the holes are features. Averaging the two into "4.7 mm rounding"
    # would hand the next design in the family a radius nothing here uses.
    plate = drilled_plate(height=6.0)
    body = rounded_prism(width=40, depth=30, height=6, radius=6.0)
    r = measure(save(tmp_path, trimesh.util.concatenate([plate, body]), "two.stl"))
    assert r["edges"]["rounding"]["dominant_r_mm"] == pytest.approx(6.0, abs=0.05)
    assert not any(m["r_mm"] == pytest.approx(1.7, abs=0.1)
                   for m in r["edges"]["rounding"]["concave"])
    assert any(f["d_mm"] == pytest.approx(3.4, abs=0.05)
               for f in r["features"]["cylinders"])


def test_a_barrel_is_form_not_a_corner_radius(tmp_path):
    # A plain cylinder has no corner radius to inherit: its 10 mm is the shape
    # itself. A style lifted from it must not claim style_corner_r = 10.
    barrel = trimesh.creation.cylinder(radius=10.0, height=25.0, sections=64)
    r = measure(save(tmp_path, barrel, "barrel.stl"))
    assert r["edges"]["rounding"]["dominant_r_mm"] is None
    assert r["edges"]["form"]["dominant_r_mm"] == pytest.approx(10.0, abs=0.05)
    assert r["edges"]["form"]["convex"][0]["sweep_deg"] == pytest.approx(360, abs=1)


def test_tessellation_style_is_reported(tmp_path):
    # The radius identity is exact on quad strips (what CAD and OpenSCAD
    # export) and reads high on a freely triangulated mesh (what sculpting and
    # remeshing produce). The tool cannot fix the second case, so it has to say
    # which one it is looking at.
    strips = measure(save(tmp_path, rounded_prism(), "strips.stl"))
    assert strips["edges"]["tessellation"] == "strip"

    blob = trimesh.creation.icosphere(subdivisions=3, radius=6.0)
    soup = measure(save(tmp_path, blob, "soup.stl"))
    assert soup["edges"]["tessellation"] == "triangulated"
    # ...and the radius it reports is the known-biased one, not silently
    # "corrected" into a number with no defensible derivation
    assert soup["edges"]["form"]["dominant_r_mm"] == pytest.approx(8.3, abs=0.3)


def test_sweep_tells_an_edge_fillet_from_a_body(tmp_path):
    r = measure(save(tmp_path, rounded_prism(radius=3.0), "round.stl"))
    # four quarter-round vertical edges: each band sweeps about 90 degrees
    assert r["edges"]["rounding"]["convex"][0]["sweep_deg"] == pytest.approx(85, abs=8)


# --------------------------------------------------------------------------
# Features, walls, massing
# --------------------------------------------------------------------------

def test_holes_are_found_with_their_diameter_and_axis(tmp_path):
    r = measure(save(tmp_path, drilled_plate(hole_d=3.4), "plate.stl"))
    holes = [f for f in r["features"]["cylinders"] if f["kind"] == "hole"]
    assert len(holes) == 1                      # one entry, four instances
    assert holes[0]["d_mm"] == pytest.approx(3.4, abs=0.02)
    assert holes[0]["count"] == 4
    assert holes[0]["axis"] == "z"


def test_wall_thickness_of_a_shell(tmp_path):
    r = measure(save(tmp_path, shelled_tube(wall=2.4), "tube.stl"))
    assert r["walls"]["shelled"] is True
    assert r["walls"]["mode_mm"] == pytest.approx(2.4, abs=0.05)


def test_a_solid_block_reports_no_wall(tmp_path):
    # Rays through a solid part measure the part, not a wall; calling that a
    # 15 mm "wall thickness" would poison every style lifted from a solid.
    r = measure(save(tmp_path, sharp_prism(), "solid.stl"))
    assert r["walls"]["shelled"] is False
    assert "radius_to_wall" not in r["ratios"]


def test_a_solid_part_with_a_boss_is_still_not_shelled(tmp_path):
    # A boss makes the bounding box taller than the body, so the rays crossing
    # it return the boss's width as the commonest thickness. Judging "shelled"
    # on that number alone called a 100% solid block a shell and fed its boss
    # diameter into styles as a wall thickness.
    solid = trimesh.util.concatenate([
        trimesh.creation.box(extents=(40, 30, 15)),
        trimesh.creation.cylinder(radius=4, height=20).apply_translation(
            [0, 0, 15])])
    r = measure(save(tmp_path, solid, "boss.stl"))
    assert r["walls"]["shelled"] is False
    assert "radius_to_wall" not in r["ratios"]


def test_massing_and_symmetry(tmp_path):
    r = measure(save(tmp_path, rounded_prism(), "round.stl"))
    assert r["massing"]["bbox_fill"] == pytest.approx(0.99, abs=0.02)
    assert r["massing"]["aspect"][0] == 1.0
    assert all(r["symmetry"][axis] > 0.99 for axis in "xyz")

    lopsided = trimesh.util.concatenate(
        [sharp_prism(), sharp_prism(width=10, depth=10, height=10)])
    asym = measure(save(tmp_path, lopsided, "asym.stl"))
    assert asym["symmetry"]["x"] < 0.95


# --------------------------------------------------------------------------
# Spec: tokens, rules, conformance
# --------------------------------------------------------------------------

@pytest.fixture
def soft_style(tmp_path):
    """A style lifted from the 40x30x15 r=3 reference box."""
    reference = save(tmp_path, rounded_prism(radius=3.0), "reference.stl")
    result = lift([reference], "soft-test", tmp_path / "style",
                  title="Soft Test")
    return result["spec"], tmp_path / "style"


def test_lift_writes_a_usable_pack(soft_style):
    spec, directory = soft_style
    assert (directory / "style.json").exists()
    assert (directory / "style.scad").exists()
    assert (directory / "STYLE.md").exists()
    assert spec.tokens["corner_r"] == pytest.approx(3.0, abs=0.01)
    assert spec.tokens["fn"] == 64
    assert {r["id"] for r in spec.rules} >= {"corner-radius", "soft-edges"}
    scad = (directory / "style.scad").read_text()
    assert "style_corner_r = 3;" in scad
    assert "style_fn = 64;" in scad


def test_lift_refuses_to_clobber_a_tuned_spec(soft_style, tmp_path):
    _, directory = soft_style
    reference = save(tmp_path, rounded_prism(radius=3.0), "ref2.stl")
    with pytest.raises(FileExistsError):
        lift([reference], "soft-test", directory)


def test_a_different_part_in_the_same_language_passes(soft_style, tmp_path):
    spec, _ = soft_style
    # less than half the size, same radius and resolution
    part = save(tmp_path, rounded_slab(), "slab.stl")
    results = conform(measure(part), spec)
    assert verdict(results) in ("IN STYLE", "IN STYLE (with advisories)")
    assert not [r for r in results if r.status is Status.FAIL]


def test_an_off_style_part_fails_with_a_reason(soft_style, tmp_path):
    spec, _ = soft_style
    part = save(tmp_path, rounded_prism(radius=8.0), "fat.stl")
    results = conform(measure(part), spec)
    failed = [r for r in results if r.status is Status.FAIL]
    assert [r.rule for r in failed] == ["corner-radius"]
    assert failed[0].why                      # the report says why it matters
    assert verdict(results) == "OFF-STYLE"


def test_a_coarse_export_fails_the_smoothness_rule(soft_style, tmp_path):
    spec, _ = soft_style
    part = save(tmp_path, rounded_prism(radius=3.0, quarter_segments=3),
                "coarse.stl")
    results = conform(measure(part), spec)
    assert "curve-smoothness" in [r.rule for r in results
                                  if r.status is Status.FAIL]


def test_a_rule_that_cannot_apply_is_skipped_not_failed(soft_style, tmp_path):
    # The sharp box has no rounded edges at all. "Your 3 mm radius is wrong" is
    # a lie about a part that has no radius; the radius rules must skip. The
    # softness rule has no precondition and *should* fail — that is the finding.
    spec, _ = soft_style
    part = save(tmp_path, sharp_prism(), "sharp.stl")
    results = conform(measure(part), spec)
    by_rule = {r.rule: r for r in results}
    assert by_rule["corner-radius"].status is Status.SKIP
    assert by_rule["corner-radius"].detail
    assert by_rule["curve-smoothness"].status is Status.SKIP
    # ...and the softness advisory does flag it, without pretending the radius
    # rules judged anything: with no required rule evaluable, the honest
    # verdict is that the two parts cannot be compared at all.
    assert by_rule["soft-edges"].status is Status.WARN
    assert verdict(results).startswith("NOT COMPARABLE")


def test_advisory_rules_warn_but_do_not_fail(soft_style, tmp_path):
    spec, _ = soft_style
    spec.rules = [
        {"id": "identity", "metric": "edges.rounding.dominant_r_mm",
         "op": "near", "value": 3.0, "tol": 0.35, "severity": "required",
         "why": "the family radius"},
        {"id": "advice", "metric": "edges.softness", "op": "min",
         "value": 0.99, "severity": "advisory", "why": "just saying"},
    ]
    results = conform(measure(save(tmp_path, rounded_prism(), "r.stl")), spec)
    by_rule = {r.rule: r for r in results}
    assert by_rule["identity"].status is Status.PASS
    assert by_rule["advice"].status is Status.WARN
    assert verdict(results) == "IN STYLE (with advisories)"


def test_verdict_when_nothing_is_comparable(soft_style, tmp_path):
    spec, _ = soft_style
    spec.rules = [{"id": "n/a", "metric": "edges.softness", "op": "min",
                   "value": 0.5, "when": {"metric": "edges.rounding."
                                          "dominant_share", "op": "min",
                                          "value": 0.9}}]
    results = conform(measure(save(tmp_path, sharp_prism(), "s.stl")), spec)
    assert verdict(results).startswith("NOT COMPARABLE")


# --------------------------------------------------------------------------
# Pack plumbing
# --------------------------------------------------------------------------

def test_style_scad_is_generated_and_drift_is_caught(soft_style):
    spec, directory = soft_style
    ok, _ = sync(directory, check=True)
    assert ok
    (directory / "style.scad").write_text("style_corner_r = 99;\n")
    ok, message = sync(directory, check=True)
    assert not ok and "stale" in message
    ok, _ = sync(directory)                       # rewrite from style.json
    assert ok
    assert sync(directory, check=True)[0]


def test_spec_roundtrips_through_json(soft_style):
    spec, directory = soft_style
    again = StyleSpec.load(directory / "style.json")
    assert again.tokens == spec.tokens
    assert again.rules == spec.rules
    assert render_tokens(again) == render_tokens(spec)


def test_unknown_schema_is_rejected(tmp_path):
    path = tmp_path / "style.json"
    path.write_text(json.dumps({"schema": "stylelift/style@99", "name": "x"}))
    with pytest.raises(ValueError, match="unsupported schema"):
        StyleSpec.load(path)


def test_snap_fn_rounds_to_values_a_design_would_write():
    assert snap_fn(63.2) == 64
    assert snap_fn(64.0) == 64
    assert snap_fn(65.0) == 64          # 8% slack absorbs measurement noise
    assert snap_fn(90.0) == 96
    assert snap_fn(None) is None


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def test_cli_measure_json(tmp_path, capsys):
    path = save(tmp_path, rounded_prism(), "r.stl")
    assert main(["measure", path, "--json"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["edges"]["rounding"]["dominant_r_mm"] == pytest.approx(3.0, abs=0.01)


def test_cli_check_exit_codes(tmp_path, capsys):
    reference = save(tmp_path, rounded_prism(radius=3.0), "ref.stl")
    assert main(["lift", reference, "--name", "cli-test",
                 "--out", str(tmp_path / "s")]) == 0
    capsys.readouterr()

    good = save(tmp_path, rounded_slab(), "good.stl")
    assert main(["check", good, "--style", str(tmp_path / "s")]) == 0

    bad = save(tmp_path, rounded_prism(radius=8.0), "bad.stl")
    assert main(["check", bad, "--style", str(tmp_path / "s")]) == 1
    assert "OFF-STYLE" in capsys.readouterr().out

    # --advisory-only reports the same finding without failing a pipeline
    assert main(["check", bad, "--style", str(tmp_path / "s"),
                 "--advisory-only"]) == 0


def test_cli_reports_a_missing_file_without_a_traceback(tmp_path, capsys):
    assert main(["measure", str(tmp_path / "nope.stl")]) == 2
    assert "stylelift:" in capsys.readouterr().err
