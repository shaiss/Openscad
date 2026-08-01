"""End-to-end tests: build known-good and known-bad meshes, assert the
checker flags exactly the problems each one has."""

import numpy as np
import pytest
import trimesh

from printcheck import analyze
from printcheck.checks import Config
from printcheck.report import Severity


def _save(tmp_path, mesh, name):
    path = tmp_path / name
    mesh.export(str(path))
    return path


def _titles(report, severity=None):
    return [f.title for f in report.findings
            if severity is None or f.severity is severity]


def test_clean_cube_scores_high(tmp_path):
    cube = trimesh.creation.box(extents=(20, 20, 20))
    report = analyze(_save(tmp_path, cube, "cube.stl"))
    assert report.mesh_summary["watertight"]
    assert report.verdict == "PRINTABLE"
    assert report.score == 100


def test_open_mesh_is_critical(tmp_path):
    cube = trimesh.creation.box(extents=(20, 20, 20))
    cube.faces = cube.faces[:-2]  # rip a hole in it
    report = analyze(_save(tmp_path, cube, "open.stl"))
    assert report.verdict == "NOT PRINTABLE AS-IS"
    assert any("watertight" in t for t in _titles(report, Severity.CRITICAL))


def test_overhang_detected_and_orientation_fixes_it(tmp_path):
    # A 'table': flat slab on a thin center column — big ceiling overhang.
    slab = trimesh.creation.box(extents=(40, 40, 4))
    slab.apply_translation([0, 0, 20 + 2])
    leg = trimesh.creation.cylinder(radius=3, height=20)
    leg.apply_translation([0, 0, 10])
    table = trimesh.util.concatenate([slab, leg])
    report = analyze(_save(tmp_path, table, "table.stl"))
    assert any(f.check == "overhangs" for f in report.findings)
    # Flipping it upside down puts the slab on the plate: advisor should see it.
    assert report.orientation_hint["best"] != "current"


def test_thin_walls_flagged(tmp_path):
    shell = trimesh.creation.box(extents=(30, 30, 0.4))
    shell.apply_translation([0, 0, 5])
    base = trimesh.creation.box(extents=(30, 30, 2))
    wall = trimesh.util.concatenate([base, shell])
    report = analyze(_save(tmp_path, wall, "thin.stl"))
    assert any(f.check == "walls" for f in report.findings)


def test_oversize_and_tiny(tmp_path):
    big = trimesh.creation.box(extents=(300, 50, 50))
    r = analyze(_save(tmp_path, big, "big.stl"))
    assert any("build volume" in t for t in _titles(r))

    tiny = trimesh.creation.box(extents=(0.5, 0.5, 0.5))
    r = analyze(_save(tmp_path, tiny, "tiny.stl"))
    assert any("microscopic" in t for t in _titles(r, Severity.CRITICAL))


def test_sphere_contact_warned(tmp_path):
    # Sphere resting on the plate: tiny contact disc -> at least a warning.
    ball = trimesh.creation.icosphere(subdivisions=3, radius=10)
    report = analyze(_save(tmp_path, ball, "ball.stl"))
    assert any(f.check == "stability" for f in report.findings)


def test_point_contact_is_critical(tmp_path):
    # Cone balanced on its tip: genuine point contact -> critical.
    cone = trimesh.creation.cone(radius=10, height=20)
    cone.apply_transform(
        trimesh.transformations.rotation_matrix(np.pi, [1, 0, 0]))
    report = analyze(_save(tmp_path, cone, "cone.stl"))
    assert any(f.check == "stability" and f.severity is Severity.CRITICAL
               for f in report.findings)


def test_json_roundtrip(tmp_path):
    cube = trimesh.creation.box(extents=(10, 10, 10))
    report = analyze(_save(tmp_path, cube, "cube.stl"))
    d = report.to_dict()
    assert d["score"] == report.score
    assert d["verdict"] == "PRINTABLE"
    assert isinstance(d["findings"], list)


def test_cli(tmp_path, capsys):
    from printcheck.cli import main
    cube = trimesh.creation.box(extents=(10, 10, 10))
    path = _save(tmp_path, cube, "cube.stl")
    assert main([str(path)]) == 0
    assert "SCORE: 100/100" in capsys.readouterr().out

    bad = trimesh.creation.box(extents=(10, 10, 10))
    bad.faces = bad.faces[:-2]
    badpath = _save(tmp_path, bad, "bad.stl")
    assert main([str(badpath)]) == 1


def test_fail_under_gate(tmp_path):
    from printcheck.cli import main
    ball = trimesh.creation.icosphere(subdivisions=3, radius=10)
    path = _save(tmp_path, ball, "ball.stl")
    assert main([str(path), "--fail-under", "90", "--json"]) == 1
