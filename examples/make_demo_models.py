#!/usr/bin/env python3
"""Generate demo STLs — one clean, one riddled with problems — so you can
try printcheck without hunting for models:

    python examples/make_demo_models.py
    printcheck examples/good_bracket.stl examples/bad_gadget.stl
"""

from pathlib import Path

import trimesh

OUT = Path(__file__).parent


def good_bracket():
    base = trimesh.creation.box(extents=(40, 20, 4))
    base.apply_translation([0, 0, 2])
    rib = trimesh.creation.box(extents=(40, 4, 12))
    rib.apply_translation([0, 8, 4 + 6])
    # Proper boolean union (needs manifold3d) so the result is watertight,
    # unlike a raw concatenate of overlapping shells.
    return trimesh.boolean.union([base, rib])


def bad_gadget():
    # Mushroom: ball on a skinny stalk (overhang + tip-over), with a
    # paper-thin fin (thin wall) and a hole ripped in the ball (open mesh).
    stalk = trimesh.creation.cylinder(radius=1.5, height=25)
    stalk.apply_translation([0, 0, 12.5])
    cap = trimesh.creation.icosphere(subdivisions=3, radius=12)
    cap.apply_translation([0, 0, 30])
    cap.faces = cap.faces[:-4]
    fin = trimesh.creation.box(extents=(20, 0.3, 10))
    fin.apply_translation([12, 0, 5])
    return trimesh.util.concatenate([stalk, cap, fin])


if __name__ == "__main__":
    for name, mesh in [("good_bracket", good_bracket()),
                       ("bad_gadget", bad_gadget())]:
        path = OUT / f"{name}.stl"
        mesh.export(str(path))
        print(f"wrote {path}")
