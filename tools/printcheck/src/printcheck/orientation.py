"""Orientation advisor: try axis-aligned rotations, score support need.

A deliberately simple take on what Tweaker-3 does with an evolutionary
tuned scoring function — we test the six axis-aligned "which face is
down" candidates and report if one clearly beats the current pose.
"""

from __future__ import annotations

import numpy as np
import trimesh

from .checks import Config

# Rotations bringing each principal axis to point down (+Z up convention).
_CANDIDATES = [
    ("current", np.eye(4)),
    ("flip 180° about X", trimesh.transformations.rotation_matrix(np.pi, [1, 0, 0])),
    ("rotate +90° about X", trimesh.transformations.rotation_matrix(np.pi / 2, [1, 0, 0])),
    ("rotate -90° about X", trimesh.transformations.rotation_matrix(-np.pi / 2, [1, 0, 0])),
    ("rotate +90° about Y", trimesh.transformations.rotation_matrix(np.pi / 2, [0, 1, 0])),
    ("rotate -90° about Y", trimesh.transformations.rotation_matrix(-np.pi / 2, [0, 1, 0])),
]


def _support_score(mesh: trimesh.Trimesh, cfg: Config) -> tuple[float, float]:
    """Return (overhang_area, contact_area) for a plate-resting mesh."""
    normals = mesh.face_normals
    down = -normals[:, 2]
    threshold = np.cos(np.radians(cfg.overhang_deg))
    face_z = mesh.triangles[:, :, 2].max(axis=1)
    on_plate = face_z < (cfg.layer_height_mm * 1.5)
    overhang = float(mesh.area_faces[(down > threshold) & ~on_plate].sum())
    contact = float(mesh.area_faces[on_plate & (normals[:, 2] < -0.5)].sum())
    return overhang, contact


def suggest_orientation(mesh: trimesh.Trimesh, cfg: Config) -> dict:
    results = []
    for name, xf in _CANDIDATES:
        m = mesh.copy()
        m.apply_transform(xf)
        m.apply_translation([0, 0, -m.bounds[0][2]])
        overhang, contact = _support_score(m, cfg)
        # Less overhang is the priority; more bed contact breaks ties.
        results.append({"name": name, "overhang_mm2": overhang,
                        "contact_mm2": contact,
                        "score": overhang - 0.1 * contact})

    current = results[0]
    best = min(results, key=lambda r: r["score"])
    improved = (best is not current
                and current["overhang_mm2"] - best["overhang_mm2"]
                > max(5.0, 0.15 * current["overhang_mm2"]))
    if improved:
        message = (
            f"'{best['name']}' reduces unsupported overhang from "
            f"{current['overhang_mm2']:.0f} to {best['overhang_mm2']:.0f} mm². "
            "(For production-grade auto-orientation see Tweaker-3.)"
        )
    else:
        message = "Current orientation is as good as any axis-aligned alternative."
    return {"message": message, "best": best["name"],
            "candidates": results}
