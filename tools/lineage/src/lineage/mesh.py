"""Identify an exported mesh by its geometry, independently of facet order.

scripts/gate.sh proves a derivative's override actually took by rendering the
derivative's part and the parent's part and asking whether they are the same
mesh. That question needs an identity that answers "same geometry" and nothing
else, which is what this module computes.

Hashing the exported file's bytes does NOT do that, and the way it fails is the
worst available: OpenSCAD 2021.01 emits a complete mesh whose FACET ORDER varies
between runs of the *same unchanged source*. Measured on this repo's
sushi-battleship, part=top, rendered twice with no edit in between:

    facet count      24256 == 24256      (identical)
    file size      1212884 == 1212884    (identical)
    raw bytes                             3248 differing bytes
    sorted triangle lists                 IDENTICAL

The geometry is the same both times; only the order it was written in moved.
(A small model — a cube, a cylinder — reproduces byte for byte, which is why
this is easy to miss: the check appears sound on exactly the toy cases you
would test it with, then silently stops working on every real design.)

Left unhandled, that noise makes the parent and the derivative differ every
time, so the override check reports "the override took" no matter what — a gate
that always passes, guarding the one failure that already looks like success.
Canonicalising the facet order is what keeps it a gate.

Deliberately not compared: the per-facet normal (derived from the vertices, so
it carries no information they do not) and the 80-byte header (OpenSCAD's
banner, not geometry).
"""

from __future__ import annotations

import hashlib
import struct
from pathlib import Path

#: A binary STL is an 80-byte header, a uint32 facet count, then 50 bytes per
#: facet: 3 floats of normal, 9 floats of vertex, 2 bytes of attribute.
HEADER_BYTES = 80
COUNT_BYTES = 4
FACET_BYTES = 50
_VERTEX_OFFSET = 12                     # past the normal, within a facet
_VERTEX_FLOATS = 9

#: What `mesh_hash` returns for "there is no mesh here". OpenSCAD writes no
#: file at all when a source's top level emits nothing, and that is a real,
#: nameable outcome rather than an error: it is exactly what a base-safe design
#: renders to. Giving it one stable identity keeps the comparison total — two
#: sides that both render to nothing genuinely ARE the same mesh, which is a
#: failed override, not a crash.
EMPTY = "empty-mesh"


class MalformedSTL(ValueError):
    """The file exists but is not a readable binary STL."""


def facets(data: bytes) -> list[tuple[float, ...]]:
    """The vertex triples of a binary STL, in file order.

    Raises MalformedSTL rather than returning something plausible: this feeds a
    comparison whose whole job is to be trusted, so "I could not read it" must
    never be indistinguishable from "it was empty".
    """
    if len(data) < HEADER_BYTES + COUNT_BYTES:
        raise MalformedSTL(
            f"{len(data)} bytes is too short to hold a binary STL header")
    count = struct.unpack_from("<I", data, HEADER_BYTES)[0]
    expected = HEADER_BYTES + COUNT_BYTES + count * FACET_BYTES
    if len(data) != expected:
        raise MalformedSTL(
            f"header declares {count} facets, which needs {expected} bytes, "
            f"but the file is {len(data)}")
    out = []
    for i in range(count):
        start = HEADER_BYTES + COUNT_BYTES + i * FACET_BYTES + _VERTEX_OFFSET
        out.append(struct.unpack_from(f"<{_VERTEX_FLOATS}f", data, start))
    return out


def _canonical(values: tuple[float, ...]) -> tuple[float, ...]:
    """Normalise a vertex triple so equal geometry compares equal.

    Only -0.0 needs the help: it is a distinct bit pattern that compares equal
    to 0.0, so leaving it alone would let two identical meshes sort and hash
    differently depending on which zero the exporter happened to emit.
    """
    return tuple(0.0 if v == 0.0 else v for v in values)


def mesh_hash(path: str | Path) -> str:
    """A facet-order-independent identity for the mesh in `path`.

    Returns EMPTY when the file does not exist (see EMPTY). Raises
    MalformedSTL when it exists but cannot be read as a binary STL.
    """
    path = Path(path)
    if not path.exists():
        return EMPTY
    tris = [_canonical(f) for f in facets(path.read_bytes())]
    if not tris:
        return EMPTY
    digest = hashlib.sha256()
    # Sorted, and re-packed rather than hashed as text: struct gives every run
    # the same bytes for the same float, where repr() has changed across Python
    # versions before and would silently re-key every stored hash if it did
    # again.
    for tri in sorted(tris):
        digest.update(struct.pack(f"<{_VERTEX_FLOATS}f", *tri))
    return digest.hexdigest()


def facet_count(path: str | Path) -> int:
    """How many facets the mesh in `path` has; 0 when the file is absent.

    Absent means OpenSCAD had no geometry to write, which is the answer the
    base-safety proof in scripts/gate.sh is looking for, so it is a count of
    zero rather than an error.
    """
    path = Path(path)
    if not path.exists():
        return 0
    data = path.read_bytes()
    if len(data) < HEADER_BYTES + COUNT_BYTES:
        raise MalformedSTL(
            f"{len(data)} bytes is too short to hold a binary STL header")
    return int(struct.unpack_from("<I", data, HEADER_BYTES)[0])
