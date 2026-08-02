"""Mesh repair via manifold3d: re-union shells that were concatenated.

The failure class this targets is the one printcheck's watertightness
check calls out: closed shells exported as one STL without a boolean
union (overlapping or duplicate geometry, stray bodies). Each connected
component is rebuilt as a Manifold and the set is boolean-unioned, which
is guaranteed to yield manifold output.

What this cannot fix: zero-volume "kiss" contacts (faces or edges that
merely touch), open holes, or single shells that are intrinsically
non-manifold — those are design problems; the union either preserves the
touching edge or fails cleanly. Repair here is a convenience artifact for
slicing experiments, never a substitute for fixing the source model.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import trimesh

try:
    import manifold3d as _m3d
except ImportError as _e:  # pragma: no cover - dep is mandatory in pyproject
    _m3d = None
    _import_error = _e


@dataclass
class RepairResult:
    """Outcome of a repair attempt."""
    mesh: trimesh.Trimesh | None   # None when repair failed
    note: str                      # one-line human-readable outcome


def _to_manifold(mesh: trimesh.Trimesh) -> "_m3d.Manifold":
    """Build a Manifold from one trimesh body (raises on failure)."""
    mm = _m3d.Mesh(
        vert_properties=np.ascontiguousarray(mesh.vertices, dtype=np.float32),
        tri_verts=np.ascontiguousarray(mesh.faces, dtype=np.uint32),
    )
    mm.merge()  # weld duplicate vertices so the halfedge graph closes
    man = _m3d.Manifold(mm)
    status = man.status()
    if status != _m3d.Error.NoError:
        raise ValueError(f"manifold rejected body: {status}")
    return man


def repair(mesh: trimesh.Trimesh) -> RepairResult:
    """Union all connected components of `mesh` into one manifold mesh."""
    if _m3d is None:  # pragma: no cover
        raise RuntimeError(f"manifold3d is not installed: {_import_error}")
    if not len(mesh.faces):
        return RepairResult(None, "empty mesh, nothing to repair")

    bodies = mesh.split(only_watertight=False)
    if not len(bodies):
        bodies = [mesh]

    manifolds = []
    for i, body in enumerate(bodies):
        try:
            manifolds.append(_to_manifold(body))
        except ValueError as e:
            return RepairResult(
                None, f"body {i + 1}/{len(bodies)} not repairable ({e}); "
                      "fix the source geometry instead")

    union = _m3d.Manifold.batch_boolean(manifolds, _m3d.OpType.Add)
    if union.status() != _m3d.Error.NoError or union.is_empty():
        return RepairResult(None, f"union failed: {union.status()}")

    out = union.to_mesh()
    fixed = trimesh.Trimesh(
        vertices=np.asarray(out.vert_properties, dtype=np.float64)[:, :3],
        faces=np.asarray(out.tri_verts), process=False)
    fixed.merge_vertices()

    note = (f"unioned {len(bodies)} shell(s) -> "
            f"{'watertight' if fixed.is_watertight else 'NOT watertight'}, "
            f"{fixed.body_count} body(ies), "
            f"volume {float(union.volume()):.1f} mm^3")
    return RepairResult(fixed, note)
