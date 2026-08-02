"""Geometric measurement of a mesh's *style*: how the form is shaped.

The whole tool rests on one identity. Tessellate a cylinder of radius r as an
inscribed prism and every fold between neighbouring strips turns by the same
angle theta, while each strip is a chord of width w = 2 r sin(theta/2). Read
backwards, a fold with turn theta between two strips of width w sits on a
surface of local radius

    r = w / (2 sin(theta / 2))

That estimate is *exact* for an inscribed tessellation, and — the useful part —
independent of how finely the curve was tessellated: a cylinder exported at
$fn=24 and the same cylinder at $fn=64 both measure r to the last decimal. It
is also invariant under rotation and covariant under scale, so a downloaded STL
in an arbitrary pose measures the same as one resting on the bed.

Everything here is deterministic: no sampling without a fixed seed, no AI, no
network.
"""

from __future__ import annotations

from dataclasses import dataclass, asdict
from pathlib import Path

import numpy as np
import trimesh


@dataclass
class Config:
    """Thresholds separating tessellation noise from deliberate shaping."""

    # A fold below this is the mesher's rounding error, not a design edge.
    flat_deg: float = 0.5
    # A single fold turning more than this reads as a hard edge, not a curve.
    soft_max_deg: float = 40.0
    # Beyond this no band interpretation is attempted at all.
    band_max_deg: float = 75.0
    # A chamfer's bounding folds turn at least this much.
    chamfer_min_deg: float = 15.0
    # ...and cuts back at least this far. Shallower than an extrusion width
    # nobody designed it and nobody could print it: on an organic mesh those
    # slivers are where the tessellation crosses a curvature change.
    min_chamfer_mm: float = 0.3
    # A curve wider than the part is not an edge treatment (it gets filed as
    # form); wider than this multiple of the part it is not a curve at all,
    # just a nominally flat surface tessellated with sub-degree folds.
    noise_radius_multiple: float = 5.0
    # Two strips of a common curved band have comparable width; a curve meeting
    # a large flat face does not. Guards the radius estimate at tangent joins.
    width_ratio: float = 3.0
    # Radius modes: half-width of the refinement window, and the share of
    # folded length below which a mode is noise rather than vocabulary.
    mode_tol: float = 0.12
    mode_min_share: float = 0.05
    # A curved band whose folds sum to this much has closed on itself.
    closed_turn_deg: float = 350.0
    thickness_samples: int = 2000
    symmetry_samples: int = 1500
    # Faces within this of the build direction count as vertical walls.
    vertical_tol_deg: float = 5.0


def load_mesh(path: str | Path) -> trimesh.Trimesh:
    """Load a mesh and merge duplicate vertices so folds are measurable.

    STL stores every triangle with its own copy of each vertex; without the
    merge there is no face adjacency at all and every edge looks like a
    boundary.
    """
    loaded = trimesh.load(str(path), force="mesh", process=False)
    if not isinstance(loaded, trimesh.Trimesh):
        raise ValueError(f"{path}: no triangle mesh found in file")
    loaded.merge_vertices()
    return loaded


def _facet_groups(mesh: trimesh.Trimesh):
    """Coplanar face groups, plus the group index of every face (-1 = alone)."""
    groups = [np.asarray(g) for g in mesh.facets]
    index = -np.ones(len(mesh.faces), dtype=np.int64)
    for i, g in enumerate(groups):
        index[g] = i
    return groups, index


def _strip_widths(mesh: trimesh.Trimesh, groups, index):
    """Per adjacency, how wide each side's facet is *across* the shared fold.

    Measured perpendicular to the fold and inside the facet's own plane, which
    is what the radius identity wants: for a tapering band (a cone, a sphere's
    polar cap) the across-fold extent is still the chord that turned, where a
    bounding-box or minor-extent measure would pick up the band's length
    instead. Returns (widths[n, 2], facet_key[n, 2]) — the key identifies the
    facet on each side so callers can group folds by the facet they bound.
    """
    pairs = mesh.face_adjacency
    edges = mesh.face_adjacency_edges
    verts = mesh.vertices
    widths = np.zeros((len(pairs), 2))
    keys = np.zeros((len(pairs), 2), dtype=np.int64)
    cache: dict[int, np.ndarray] = {}

    def facet_vertices(face: int) -> tuple[np.ndarray, int]:
        g = int(index[face])
        # faces in no coplanar group get a private key that cannot collide
        # with a group index
        key = g if g >= 0 else -1 - int(face)
        if key not in cache:
            faces = groups[g] if g >= 0 else np.array([face])
            cache[key] = verts[np.unique(mesh.faces[faces].ravel())]
        return cache[key], key

    for k in range(len(pairs)):
        edge = verts[edges[k, 1]] - verts[edges[k, 0]]
        length = np.linalg.norm(edge)
        if length == 0:
            continue
        edge = edge / length
        for side in (0, 1):
            face = int(pairs[k, side])
            v, key = facet_vertices(face)
            keys[k, side] = key
            across = np.cross(mesh.face_normals[face], edge)
            n = np.linalg.norm(across)
            if n == 0:
                continue
            widths[k, side] = float(np.ptp(v @ (across / n)))
    return widths, keys


def radius_modes(radii: np.ndarray, weights: np.ndarray, cfg: Config) -> list[dict]:
    """The radii a shape actually reuses, as length-weighted modes.

    A design language is a *small* set of reused radii, so the useful statistic
    is the mode, not the mean or median: on a part whose edges are all r=3 but
    whose corners are spherical, the sphere's polar tessellation smears the
    median while the r=3 mode still carries the overwhelming majority of folded
    length. Peaks are found in a log-spaced histogram (radii span decades) and
    then refined off the histogram grid by the weighted median of the folds
    inside the peak, so the reported value does not inherit the bin width.
    """
    ok = np.isfinite(radii) & (radii > 0)
    radii, weights = radii[ok], weights[ok]
    if not len(radii) or weights.sum() <= 0:
        return []
    total = float(weights.sum())
    lo, hi = float(radii.min()) * 0.98, float(radii.max()) * 1.02
    if not np.isfinite(lo) or lo <= 0 or hi <= lo:
        return [{"r_mm": round(float(np.median(radii)), 4), "share": 1.0,
                 "length_mm": round(total, 3)}]
    counts, edges = np.histogram(radii, bins=np.geomspace(lo, hi, 64),
                                 weights=weights)
    modes: list[dict] = []
    claimed = np.zeros(len(radii), dtype=bool)
    for i in np.argsort(counts)[::-1]:
        if counts[i] <= 0:
            break
        centre = float(np.sqrt(edges[i] * edges[i + 1]))
        window = ((~claimed) & (radii > centre * (1 - cfg.mode_tol))
                  & (radii < centre * (1 + cfg.mode_tol)))
        if not window.any():
            continue
        claimed |= window
        w, r = weights[window], radii[window]
        order = np.argsort(r)
        cumulative = np.cumsum(w[order])
        value = float(r[order][np.searchsorted(cumulative, cumulative[-1] / 2)])
        share = float(w.sum() / total)
        if share >= cfg.mode_min_share:
            modes.append({"r_mm": round(value, 4), "share": round(share, 4),
                          "length_mm": round(float(w.sum()), 3)})
    return sorted(modes, key=lambda m: -m["share"])


def _edge_treatment(mesh: trimesh.Trimesh, cfg: Config) -> dict:
    """Fold-by-fold analysis: what the shape does at every change of direction."""
    angles = np.asarray(mesh.face_adjacency_angles, dtype=float)
    pairs = mesh.face_adjacency
    edges = mesh.face_adjacency_edges
    convex = np.asarray(mesh.face_adjacency_convex, dtype=bool)
    verts = mesh.vertices
    if not len(angles):
        return {"folds": 0}
    lengths = np.linalg.norm(verts[edges[:, 0]] - verts[edges[:, 1]], axis=1)

    groups, index = _facet_groups(mesh)
    widths, keys = _strip_widths(mesh, groups, index)

    flat = angles < np.radians(cfg.flat_deg)
    soft = (~flat) & (angles <= np.radians(cfg.soft_max_deg))
    hard = (~flat) & (angles > np.radians(cfg.soft_max_deg))
    soft_len, hard_len = float(lengths[soft].sum()), float(lengths[hard].sum())
    shaped = soft_len + hard_len

    # --- pass 1: chamfer bands -------------------------------------------
    # A chamfer is one narrow face bridging two much wider ones, bounded by two
    # decisive folds. Both bounding folds fail the comparable-width test, which
    # is exactly what separates a chamfer from a fillet's first strip.
    band = (~flat) & (angles <= np.radians(cfg.band_max_deg))
    wmin = np.minimum(widths[:, 0], widths[:, 1])
    wmax = np.maximum(widths[:, 0], widths[:, 1])
    comparable = (wmin > 0) & (wmax <= cfg.width_ratio * wmin)
    candidate = band & (~comparable) & (angles > np.radians(cfg.chamfer_min_deg))

    by_facet: dict[int, list] = {}
    for k in np.where(candidate)[0]:
        narrow = 0 if widths[k, 0] <= widths[k, 1] else 1
        by_facet.setdefault(int(keys[k, narrow]), []).append(
            (float(angles[k]), float(widths[k, narrow]), float(lengths[k]),
             int(keys[k, 1 - narrow]), bool(convex[k])))

    chamfer_facets: set[int] = set()
    bands: list[dict] = []
    for facet, folds in by_facet.items():
        # group by the facet on the far side: one chamfer has exactly two
        # neighbours however finely either of them is triangulated
        sides: dict[int, list] = {}
        for angle, width, length, other, cvx in folds:
            sides.setdefault(other, []).append((angle, width, length, cvx))
        if len(sides) != 2:
            continue
        turn = 0.0
        length_total = 0.0
        widths_seen = []
        convexity = []
        for entries in sides.values():
            w = np.array([e[2] for e in entries])
            a = np.degrees([e[0] for e in entries])
            turn += float(np.average(a, weights=w) if w.sum() else a.mean())
            length_total += float(w.sum())
            widths_seen += [e[1] for e in entries]
            convexity += [e[3] for e in entries]
        width = float(np.median(widths_seen))
        # A symmetric chamfer cutting a corner of total turn T with equal legs
        # c presents a face of width w = 2 c cos(T/2).
        half = np.radians(min(turn, 179.0)) / 2
        leg = width / (2 * np.cos(half)) if np.cos(half) > 1e-6 else width
        if leg < cfg.min_chamfer_mm:
            continue
        chamfer_facets.add(facet)
        bands.append({"leg_mm": round(leg, 4), "width_mm": round(width, 4),
                      "turn_deg": round(turn, 2),
                      "length_mm": round(length_total, 3),
                      "convex": bool(np.mean(convexity) >= 0.5)})

    # --- pass 2: rounding vocabulary --------------------------------------
    # Folds bounding a chamfer band on *both* sides describe the chamfer's own
    # tessellation (a chamfer swept around a cylinder is a cone; a chamfer
    # swept around a rounded corner is a torus slice). Reporting their
    # osculating radius as a rounding radius would invent a radius the designer
    # never chose, so they are excluded here and accounted as chamfer.
    on_chamfer = np.array([
        (int(keys[k, 0]) in chamfer_facets) and (int(keys[k, 1]) in chamfer_facets)
        for k in range(len(angles))]) if chamfer_facets else np.zeros(len(angles), bool)

    usable = band & comparable & (~on_chamfer)
    radii = np.full(len(angles), np.nan)
    with np.errstate(divide="ignore", invalid="ignore"):
        radii[usable] = ((widths[usable, 0] + widths[usable, 1]) / 2
                         / (2 * np.sin(angles[usable] / 2)))

    def modes_for(selection: np.ndarray, sweeps=None) -> list[dict]:
        out = radius_modes(radii[selection], lengths[selection], cfg)
        for mode in out:
            window = (selection & np.isfinite(radii)
                      & (radii > mode["r_mm"] * (1 - cfg.mode_tol))
                      & (radii < mode["r_mm"] * (1 + cfg.mode_tol)))
            if not window.any():
                continue
            turn = float(np.median(np.degrees(angles[window])))
            mode["implied_fn"] = round(360.0 / turn, 1) if turn > 0 else None
            if sweeps is not None:
                # How far the band this mode lives on actually goes around:
                # ~90 degrees is an edge being broken, 180+ is the body of the
                # part curving. The number a reader needs to tell a 15 mm
                # fillet from a 15 mm barrel.
                arcs = sweeps[window]
                arcs = arcs[arcs > 0]
                if len(arcs):
                    mode["sweep_deg"] = round(float(np.median(arcs)), 1)
        return out

    # --- pass 3: edge rounding vs form curvature --------------------------
    # A 15 mm radius can be a generous fillet or it can be the barrel of a
    # capsule, and a style spec that confuses the two hands the next design a
    # 15 mm "corner radius". Curvature counts as FORM when the surface closes
    # on itself (a full barrel or bore) or when its radius is a sizeable
    # fraction of the part — at which point the curve is the shape, not a
    # treatment applied to its edges.
    regions, closed = _regions(mesh, usable, angles, lengths, radii, convex, cfg)
    # Measured against the part's LONGEST dimension, so that rounding the
    # corners of a thin plate stays edge treatment: against the shortest
    # dimension a 3 mm radius on a 4 mm plate would score 0.75 and be
    # misfiled as form, taking the plate's real corner radius with it.
    longest = float(np.max(mesh.extents)) if len(mesh.vertices) else 0.0
    form = np.zeros(len(angles), dtype=bool)
    if longest > 0:
        with np.errstate(invalid="ignore"):
            scale = np.nan_to_num(radii) / longest
            # Bigger than the whole part: cannot be an edge treatment. Far
            # bigger: not a curve at all, just a flat face whose triangles
            # disagree by a fraction of a degree — drop it before it becomes
            # 80% of a "rounding vocabulary".
            form = usable & (scale >= 0.35)
            usable &= scale <= cfg.noise_radius_multiple
            form &= usable
    sweeps = np.zeros(len(angles))
    for root, folds in regions.items():
        idx = np.array(folds)
        # Only a band that stops somewhere has an arc worth quoting. A region
        # that keeps turning is a continuous surface network (every edge of a
        # fully-rounded box joins its neighbours), and reporting "sweeps 51953
        # degrees" would be noise dressed as a measurement.
        turn = float(np.degrees(angles[idx]).sum())
        sweeps[idx] = turn if turn <= 400.0 else 0.0
        if closed.get(root):
            form[idx] = True

    outer = modes_for(usable & convex & ~form, sweeps)
    inner = modes_for(usable & ~convex & ~form, sweeps)
    form_outer = modes_for(usable & convex & form, sweeps)
    form_inner = modes_for(usable & ~convex & form, sweeps)

    chamfer_len = float(sum(b["length_mm"] for b in bands))
    round_len = float(lengths[usable].sum())
    grammar_total = chamfer_len + round_len + hard_len

    # How the curved surfaces are tessellated, because it bounds how far the
    # radii can be trusted. CAD and OpenSCAD emit quad strips (two coplanar
    # triangles per strip) and the radius identity is then exact — measured
    # error under half a percent. A mesh of free-standing triangles (sculpted,
    # or remeshed in Blender) has no strips: consecutive folds turn about
    # non-parallel axes, and the same estimator reads high by a factor of
    # about 1.38 on an equilateral triangulation. That is reported, not
    # silently corrected: the factor is only stable at the isotropic extreme,
    # and a confident wrong number is worse than a flagged approximate one.
    stripped = 0.0
    if usable.any():
        paired = np.array([(keys[k, 0] >= 0) or (keys[k, 1] >= 0)
                           for k in np.where(usable)[0]])
        stripped = float(lengths[usable][paired].sum() / lengths[usable].sum())
    tessellation = ("strip" if stripped > 0.6
                    else "triangulated" if stripped < 0.15 else "mixed")
    return {
        "folds": int(len(angles)),
        "soft_length_mm": round(soft_len, 3),
        "hard_length_mm": round(hard_len, 3),
        "softness": round(soft_len / shaped, 4) if shaped > 0 else 0.0,
        "tessellation": tessellation,
        "strip_share": round(stripped, 4),
        "rounding": {
            "convex": outer,
            "concave": inner,
            "dominant_r_mm": outer[0]["r_mm"] if outer else None,
            "dominant_share": outer[0]["share"] if outer else 0.0,
            "implied_fn": outer[0].get("implied_fn") if outer else None,
        },
        # Curvature that *is* the shape rather than a treatment of its edges:
        # barrels, domes, bores. Reported so a style can say "bodies are
        # cylindrical", but deliberately kept out of the corner-radius token.
        "form": {
            "convex": form_outer,
            "concave": form_inner,
            "dominant_r_mm": form_outer[0]["r_mm"] if form_outer else None,
        },
        "chamfers": {
            "bands": sorted(bands, key=lambda b: -b["length_mm"])[:8],
            "count": len(bands),
            "length_mm": round(chamfer_len, 3),
            "dominant_leg_mm": (
                round(float(np.median([b["leg_mm"] for b in bands])), 4)
                if bands else None),
        },
        "grammar": {
            "rounded_share": round(round_len / grammar_total, 4) if grammar_total else 0.0,
            "chamfered_share": round(chamfer_len / grammar_total, 4) if grammar_total else 0.0,
            "sharp_share": round(hard_len / grammar_total, 4) if grammar_total else 0.0,
        },
        # handed to the feature pass so the regions are grown only once
        "_internal": {"radii": radii, "usable": usable, "lengths": lengths,
                      "angles": angles, "convex": convex,
                      "regions": regions, "closed": closed},
    }


def _regions(mesh: trimesh.Trimesh, usable: np.ndarray, angles: np.ndarray,
             lengths: np.ndarray, radii: np.ndarray, convex: np.ndarray,
             cfg: Config) -> tuple[dict, dict]:
    """Group folds into continuous curved surfaces, and say which ones close.

    Union-find over the folds that carry a usable radius. A region is *closed*
    when its folds sum to one full turn and its radius holds steady across
    them: that is a barrel or a bore. Summing past a full turn means several
    features grew together — the unbroken shell of a box rounded on all twelve
    edges, say — which is not one cylinder and must not be reported as one.
    """
    pairs = mesh.face_adjacency
    parent = np.arange(len(mesh.faces))

    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return int(a)

    def union(a: int, b: int) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    # Coplanar faces first: a tessellated strip is two triangles sharing a
    # diagonal, and without joining them the chain of strips around a hole
    # breaks at every strip and no band ever closes.
    for group in mesh.facets:
        group = np.asarray(group)
        for face in group[1:]:
            union(int(group[0]), int(face))
    members: dict[int, list[int]] = {}
    for k in np.where(usable)[0]:
        union(int(pairs[k, 0]), int(pairs[k, 1]))
    for k in np.where(usable)[0]:
        root = find(int(pairs[k, 0]))
        members.setdefault(root, []).append(int(k))

    closed: dict[int, bool] = {}
    for root, folds in members.items():
        idx = np.array(folds)
        turn = float(np.degrees(angles[idx]).sum())
        if not cfg.closed_turn_deg <= turn <= 400.0:
            continue
        sign = float(convex[idx].mean())
        if 0.15 < sign < 0.85:          # mixed curvature: not one clean barrel
            continue
        r = _weighted_median(radii[idx], lengths[idx])
        if r <= 0 or float(np.std(radii[idx]) / r) > 0.15:
            continue                    # radius wanders: not a cylinder
        closed[root] = True
    return members, closed


def _weighted_median(values: np.ndarray, weights: np.ndarray) -> float:
    """Median of `values` weighted by `weights` (edge length, everywhere here)."""
    order = np.argsort(values)
    cumulative = np.cumsum(weights[order])
    if not len(cumulative) or cumulative[-1] <= 0:
        return 0.0
    return float(values[order][np.searchsorted(cumulative, cumulative[-1] / 2)])


def _cylindrical_features(mesh: trimesh.Trimesh, internal: dict, cfg: Config) -> dict:
    """The holes, bosses and barrels: curved bands that close on themselves.

    Concave means a bore, convex a round pillar. Instances of the same size and
    axis are reported once with a count, because "four M3 clearance holes" is
    the fact worth carrying into a style, not four near-identical entries.
    """
    radii, angles = internal["radii"], internal["angles"]
    lengths, convex = internal["lengths"], internal["convex"]
    regions, closed = internal["regions"], internal["closed"]
    pairs = mesh.face_adjacency

    features = []
    for root in closed:
        idx = np.array(regions[root])
        r = _weighted_median(radii[idx], lengths[idx])
        normals = mesh.face_normals[np.unique(pairs[idx].ravel())]
        axis = np.abs(np.linalg.svd(normals, full_matrices=False)[2][-1])
        features.append({
            "d_mm": round(2 * r, 3),
            "kind": "boss" if float(convex[idx].mean()) >= 0.85 else "hole",
            "along": ("z" if axis[2] > 0.95
                      else ("xy" if axis[2] < 0.05 else "oblique")),
            "implied_fn": round(
                360.0 / float(np.median(np.degrees(angles[idx]))), 1),
        })

    grouped: dict[tuple, dict] = {}
    for f in features:
        key = (round(f["d_mm"], 2), f["kind"], f["along"])
        entry = grouped.setdefault(key, {"d_mm": key[0], "kind": key[1],
                                         "axis": key[2], "count": 0,
                                         "implied_fn": f["implied_fn"]})
        entry["count"] += 1
    cylinders = sorted(grouped.values(),
                       key=lambda c: (-c["count"], c["d_mm"]))[:12]
    # The fastener vocabulary as a plain number a rule can compare against:
    # "this family drills M3 clearance" is one of the most portable things a
    # style carries, and it survives into parts of any size.
    holes = [c for c in cylinders if c["kind"] == "hole"]
    return {"cylinders": cylinders,
            "count": len(features),
            "hole_count": sum(h["count"] for h in holes),
            "dominant_hole_d_mm": holes[0]["d_mm"] if holes else None}


def _massing(mesh: trimesh.Trimesh) -> dict:
    """Overall proportion and how much of the bounding box the form fills."""
    extents = np.asarray(mesh.extents, dtype=float)
    ordered = np.sort(extents)[::-1]
    bbox_volume = float(np.prod(extents)) if np.all(extents > 0) else 0.0
    volume = float(mesh.volume) if mesh.is_watertight else float("nan")
    try:
        hull_volume = float(mesh.convex_hull.volume)
    except Exception:                                  # degenerate hull
        hull_volume = float("nan")
    return {
        "extents_mm": [round(float(e), 3) for e in extents],
        "aspect": [round(float(o / ordered[0]), 4) for o in ordered]
        if ordered[0] > 0 else [0, 0, 0],
        "volume_mm3": round(volume, 3) if np.isfinite(volume) else None,
        "bbox_fill": round(volume / bbox_volume, 4)
        if bbox_volume > 0 and np.isfinite(volume) else None,
        "convexity": round(volume / hull_volume, 4)
        if np.isfinite(hull_volume) and hull_volume > 0 and np.isfinite(volume) else None,
        "surface_area_mm2": round(float(mesh.area), 3),
    }


def _orientation(mesh: trimesh.Trimesh, cfg: Config) -> dict:
    """Area shares by face direction, in the mesh's own frame (+Z assumed up).

    Style-bearing because design families differ in how they meet the build
    plate: a family of flat-topped boxes with vertical walls reads differently
    from one whose surfaces all slope. Meaningless if the file was exported in
    an arbitrary pose, hence `assumes_z_up` in the output.
    """
    areas = np.asarray(mesh.area_faces, dtype=float)
    total = float(areas.sum())
    if total <= 0:
        return {"assumes_z_up": True}
    nz = np.clip(np.asarray(mesh.face_normals)[:, 2], -1.0, 1.0)
    tilt = np.degrees(np.arccos(nz))                    # 0 = up, 180 = down
    vertical = np.abs(tilt - 90.0) <= cfg.vertical_tol_deg
    up = tilt <= cfg.vertical_tol_deg
    down = tilt >= 180.0 - cfg.vertical_tol_deg
    sloped = ~(vertical | up | down)
    slopes = []
    if sloped.any():
        # dominant slope angles, measured from horizontal, area-weighted
        angle = np.abs(90.0 - tilt[sloped])
        counts, edges = np.histogram(angle, bins=np.arange(0, 91, 2.5),
                                     weights=areas[sloped])
        for i in np.argsort(counts)[::-1][:3]:
            if counts[i] <= 0.02 * total:
                continue
            sel = sloped.copy()
            sel[sloped] = (angle >= edges[i]) & (angle < edges[i + 1])
            slopes.append({
                "angle_deg": round(float(np.average(np.abs(90.0 - tilt[sel]),
                                                    weights=areas[sel])), 2),
                "share": round(float(areas[sel].sum() / total), 4)})
    return {
        "assumes_z_up": True,
        "up_share": round(float(areas[up].sum() / total), 4),
        "down_share": round(float(areas[down].sum() / total), 4),
        "vertical_share": round(float(areas[vertical].sum() / total), 4),
        "sloped_share": round(float(areas[sloped].sum() / total), 4),
        "dominant_slopes": slopes,
    }


def _walls(mesh: trimesh.Trimesh, cfg: Config) -> dict:
    """Material thickness by inward ray casting from area-weighted samples.

    printcheck asks whether a wall is too thin to print; this asks what
    thickness the family *chose*, which is a style token — a design language
    that always builds 2.4 mm walls looks different from one at 1.2 mm.
    """
    if not mesh.is_watertight or len(mesh.faces) == 0:
        return {"measured": False, "reason": "mesh is not watertight"}
    areas = np.asarray(mesh.area_faces, dtype=float)
    total = float(areas.sum())
    if total <= 0:
        return {"measured": False, "reason": "degenerate faces"}
    n = min(cfg.thickness_samples, int((areas > 0).sum()))
    rng = np.random.default_rng(0)                      # fixed: results repeat
    idx = rng.choice(len(mesh.faces), size=n, replace=False, p=areas / total)
    directions = -np.asarray(mesh.face_normals)[idx]
    origins = np.asarray(mesh.triangles_center)[idx] + directions * 1e-4
    hits, ray_idx, _ = mesh.ray.intersects_location(origins, directions,
                                                    multiple_hits=False)
    if not len(hits):
        return {"measured": False, "reason": "no interior ray hits"}
    thickness = np.linalg.norm(hits - origins[ray_idx], axis=1)
    counts, edges = np.histogram(thickness, bins=64)
    peak = int(np.argmax(counts))
    centre = float((edges[peak] + edges[peak + 1]) / 2)
    # Refine off the histogram grid, as radius_modes does: the bin only has to
    # find the peak, and a bin wide enough to span a whole part is far too
    # coarse to report as "this family builds at 2.5 mm".
    window = thickness[(thickness >= centre * 0.88) & (thickness <= centre * 1.12)]
    mode = float(np.median(window)) if len(window) else centre
    # On a solid part these rays measure the part, not a wall: the commonest
    # "thickness" is simply its shortest dimension. Saying so keeps a solid
    # block from contributing a 15 mm "wall thickness" token to a style.
    thinnest_extent = float(np.min(mesh.extents))
    shelled = bool(mode < 0.85 * thinnest_extent)
    return {
        "measured": True,
        "shelled": shelled,
        "samples": int(len(thickness)),
        "p05_mm": round(float(np.percentile(thickness, 5)), 3),
        "median_mm": round(float(np.median(thickness)), 3),
        "mode_mm": round(mode, 3),
        "min_mm": round(float(thickness.min()), 3),
    }


def _symmetry(mesh: trimesh.Trimesh, cfg: Config) -> dict:
    """Mirror symmetry about each bounding-box mid-plane, as a 0..1 score.

    Points are sampled on the surface, mirrored, and measured against the real
    surface — not against the sample set, so the score does not degrade with
    sampling density.
    """
    if len(mesh.faces) == 0:
        return {}
    diagonal = float(np.linalg.norm(mesh.extents))
    if diagonal <= 0:
        return {}
    points, _ = trimesh.sample.sample_surface(mesh, cfg.symmetry_samples, seed=0)
    centre = mesh.bounds.mean(axis=0)
    tolerance = 0.005 * diagonal
    out = {}
    for i, name in enumerate("xyz"):
        mirrored = np.array(points)
        mirrored[:, i] = 2 * centre[i] - mirrored[:, i]
        distance = trimesh.proximity.closest_point(mesh, mirrored)[1]
        out[name] = round(float((np.abs(distance) <= tolerance).mean()), 4)
    return out


def measure(path: str | Path, cfg: Config | None = None) -> dict:
    """Measure every style-bearing property of a mesh file."""
    cfg = cfg or Config()
    mesh = load_mesh(path)
    edges = _edge_treatment(mesh, cfg)
    internal = edges.pop("_internal", None)
    features = (_cylindrical_features(mesh, internal, cfg) if internal
                else {"cylinders": [], "count": 0})
    walls = _walls(mesh, cfg)
    massing = _massing(mesh)

    ratios = {}
    r = edges.get("rounding", {}).get("dominant_r_mm")
    chamfer = edges.get("chamfers", {}).get("dominant_leg_mm")
    # Only a shelled part has a wall to be in proportion with.
    wall = walls.get("mode_mm") if walls.get("shelled") else None
    if r and wall:
        ratios["radius_to_wall"] = round(r / wall, 3)
    if chamfer and wall:
        ratios["chamfer_to_wall"] = round(chamfer / wall, 3)
    longest = max(massing["extents_mm"]) if massing["extents_mm"] else 0
    if r and longest:
        ratios["radius_to_size"] = round(r / longest, 4)

    return {
        "source": str(path),
        "mesh": {
            "faces": int(len(mesh.faces)),
            "vertices": int(len(mesh.vertices)),
            "watertight": bool(mesh.is_watertight),
            "bodies": int(mesh.body_count) if len(mesh.faces) else 0,
        },
        "massing": massing,
        "edges": edges,
        "features": features,
        "orientation": _orientation(mesh, cfg),
        "walls": walls,
        "symmetry": _symmetry(mesh, cfg),
        "ratios": ratios,
        "config": asdict(cfg),
    }
