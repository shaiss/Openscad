"""Orchestrates loading, checks, orientation advice, and report assembly."""

from __future__ import annotations

from pathlib import Path

import trimesh

from .checks import ALL_CHECKS, Config
from .orientation import suggest_orientation
from .report import Report


def load_mesh(path: str | Path) -> trimesh.Trimesh:
    """Load a mesh file and merge duplicate vertices for topology checks."""
    loaded = trimesh.load(str(path), force="mesh", process=False)
    if not isinstance(loaded, trimesh.Trimesh):
        raise ValueError(f"{path}: no triangle mesh found in file")
    # STL stores per-triangle vertices; merge duplicates so topology
    # (watertightness, bodies) is meaningful. We deliberately skip the
    # full process=True pass, which would silently drop the degenerate
    # and duplicate faces we want to report on.
    loaded.merge_vertices()
    return loaded


def analyze(path: str | Path, cfg: Config | None = None,
            orientation: bool = True) -> Report:
    """Run every printability check on a mesh file and return the Report."""
    cfg = cfg or Config()
    mesh = load_mesh(path)

    # Rest the part on the plate: all heuristics assume z=0 is the bed.
    if len(mesh.vertices):
        mesh.apply_translation([0, 0, -mesh.bounds[0][2]])

    summary = {
        "faces": int(len(mesh.faces)),
        "vertices": int(len(mesh.vertices)),
        "extents_mm": [float(x) for x in (mesh.extents if len(mesh.vertices)
                                          else (0, 0, 0))],
        "watertight": bool(mesh.is_watertight),
        "bodies": int(mesh.body_count) if len(mesh.faces) else 0,
        "volume_mm3": float(mesh.volume) if mesh.is_watertight else None,
        "surface_area_mm2": float(mesh.area) if len(mesh.faces) else 0.0,
    }

    report = Report(source=str(path), mesh_summary=summary)
    for check in ALL_CHECKS:
        report.findings.extend(check(mesh, cfg))

    if orientation and len(mesh.faces):
        report.orientation_hint = suggest_orientation(mesh, cfg)
    return report
