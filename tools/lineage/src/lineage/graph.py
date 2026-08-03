"""The lineage graph: who derives from whom, and what follows from that.

Designs are discovered exactly the way gate.sh, style-check.sh and gallery.sh
discover them — a directory under designs/ containing a .scad matching its own
name — so a design that CI renders is a design this tool reasons about, with
no second list to drift.

Edges point child -> parent, in declared order. Order is not cosmetic: OpenSCAD
resolves two parents defining the same module by last-include-wins, silently,
so every traversal here preserves the order the file declared.
"""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

from .conf import DerivesConf
from .scad import resolve, targets


def read_parts(path: Path) -> list[str]:
    """Parse a ci.parts file the way gate.sh reads it."""
    parts = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts.append(line)
    return parts


@dataclass
class Design:
    """One design directory, with whatever lineage state it carries."""

    name: str
    directory: Path
    entry: Path
    conf: DerivesConf | None = None
    parts: tuple[str, ...] = ()
    has_ci_parts: bool = False

    @property
    def declared_parents(self) -> list[str]:
        """Parents named in derives.conf, in declared order (may not exist)."""
        return self.conf.parents if self.conf else []

    @property
    def diamond_ok(self) -> tuple[str, ...]:
        """Ancestors this design asserts are base-safe."""
        return self.conf.diamond_ok if self.conf else ()


class Lineage:
    """The whole forest, resolved once and queried many times."""

    def __init__(self, root: Path, designs: dict[str, Design]):
        self.root = Path(root)
        self.designs = designs
        self._entries: dict[Path, str] | None = None

    # ----------------------------------------------------------------------
    # Discovery
    # ----------------------------------------------------------------------

    @classmethod
    def discover(cls, root: Path) -> Lineage:
        """Load every design under <root>/designs/ and its lineage state."""
        root = Path(root)
        designs: dict[str, Design] = {}
        for directory in sorted((root / "designs").iterdir()):
            if not directory.is_dir():
                continue
            name = directory.name
            entry = directory / f"{name}.scad"
            if not entry.is_file():
                continue
            design = Design(name=name, directory=directory, entry=entry)
            conf = directory / "derives.conf"
            if conf.is_file():
                design.conf = DerivesConf.load(conf)
            ci_parts = directory / "ci.parts"
            if ci_parts.is_file():
                design.has_ci_parts = True
                design.parts = tuple(read_parts(ci_parts))
            designs[name] = design
        return cls(root, designs)

    def __contains__(self, name: str) -> bool:
        return name in self.designs

    @property
    def names(self) -> list[str]:
        """Every design name, sorted."""
        return sorted(self.designs)

    @property
    def derivatives(self) -> list[str]:
        """Designs that declare at least one parent, sorted."""
        return sorted(n for n in self.designs if self.designs[n].declared_parents)

    # ----------------------------------------------------------------------
    # Edges
    # ----------------------------------------------------------------------

    def declared_parents(self, name: str) -> list[str]:
        """Parents as declared, including any that are not designs."""
        design = self.designs.get(name)
        return list(design.declared_parents) if design else []

    def parents(self, name: str) -> list[str]:
        """Declared parents that are real designs — the traversable edges.

        A parent that does not exist is reported by `lineage check` (rule 5);
        dropping it here keeps every traversal total, so a single typo cannot
        turn `blast-radius` into a crash and CI into a red X with no answer.
        """
        seen: set[str] = set()
        out = []
        for parent in self.declared_parents(name):
            if parent in self.designs and parent != name and parent not in seen:
                seen.add(parent)
                out.append(parent)
        return out

    def children(self, name: str) -> list[str]:
        """Designs that declare `name` as a parent, sorted."""
        return sorted(n for n in self.designs if name in self.parents(n))

    def _entry_index(self) -> dict[Path, str]:
        """Resolved entry-.scad path -> design name, built once per instance."""
        if self._entries is None:
            self._entries = {d.entry.resolve(): d.name
                             for d in self.designs.values()}
        return self._entries

    def scad_parents(self, name: str, keyword: str = "include") -> list[str]:
        """Parent designs the entry .scad names, in file order.

        Only targets resolving to another design's entry .scad count: a design
        including its own sibling part file (`include <sushi-battleship.scad>`)
        or a library is not deriving from anything.

        `keyword` exists for the `use` case. `use` imports modules without
        pulling the source in, so the base's own call sites keep calling the
        base's version — a derivative written with `use` overrides nothing,
        which is worth telling someone whose declaration looks right.
        """
        design = self.designs.get(name)
        if design is None:
            return []
        index = self._entry_index()
        out = []
        for target in targets(design.entry, keyword):
            path = resolve(target, design.directory, self.root)
            parent = index.get(path) if path is not None else None
            if parent is not None and parent != name:
                out.append(parent)
        return out

    def ancestors(self, name: str) -> list[str]:
        """Transitive parents, sorted, excluding `name`."""
        return sorted(self._reach(name, self.parents))

    def descendants(self, name: str) -> list[str]:
        """Transitive children, sorted, excluding `name`."""
        return sorted(self._reach(name, self.children))

    def _reach(self, start: str, step) -> set[str]:
        """Everything reachable from `start` via `step`, minus `start` itself.

        Iterative and visited-guarded so a cycle is a wrong answer at worst,
        never a hang: `blast-radius` must still terminate on a tree that
        `check` would reject.
        """
        seen: set[str] = set()
        stack = list(step(start))
        while stack:
            node = stack.pop()
            if node in seen:
                continue
            seen.add(node)
            stack.extend(step(node))
        seen.discard(start)
        return seen

    def blast_radius(self, names) -> list[str]:
        """The inputs plus every transitive descendant, deduplicated, sorted.

        What CI has to re-gate when these designs change. Unknown names are
        passed through rather than dropped — the caller hands us whatever
        changed, and silently forgetting one is the failure mode that matters.
        """
        out: set[str] = set()
        for name in names:
            out.add(name)
            out.update(self.descendants(name))
        return sorted(out)

    # ----------------------------------------------------------------------
    # Cycles and diamonds
    # ----------------------------------------------------------------------

    def find_cycles(self) -> list[list[str]]:
        """Every cycle, each as a name list whose first name repeats at the end.

        Canonicalized (rotated to start at its alphabetically first member) so
        the same loop is reported once no matter which node found it.
        """
        seen: set[tuple[str, ...]] = set()
        cycles = []
        for start in self.names:
            path = self._path_back(start)
            if path is None:
                continue
            body = path[:-1]
            pivot = body.index(min(body))
            key = tuple(body[pivot:] + body[:pivot])
            if key in seen:
                continue
            seen.add(key)
            cycles.append(list(key) + [key[0]])
        return cycles

    def _path_back(self, start: str) -> list[str] | None:
        """A parent path from `start` back to `start`, or None."""
        stack = [(start, [start])]
        visited: set[str] = set()
        while stack:
            node, path = stack.pop()
            for parent in self.parents(node):
                if parent == start:
                    return path + [start]
                if parent in visited:
                    continue
                visited.add(parent)
                stack.append((parent, path + [parent]))
        return None

    def ancestor_paths(self, name: str) -> dict[str, list[tuple[str, ...]]]:
        """Every distinct simple path from `name` up to each ancestor."""
        paths: dict[str, list[tuple[str, ...]]] = defaultdict(list)

        def walk(node: str, path: tuple[str, ...]) -> None:
            for parent in self.parents(node):
                if parent in path:                  # cycle guard
                    continue
                extended = path + (parent,)
                paths[parent].append(extended)
                walk(parent, extended)

        walk(name, (name,))
        return {a: sorted(set(p)) for a, p in paths.items()}

    def diamonds(self, name: str) -> list[tuple[str, tuple[str, ...], tuple[str, ...]]]:
        """Ancestors reachable by more than one path, with two of those paths.

        This is the shape that makes `include` dangerous: it is not guarded, so
        a shared ancestor is evaluated once per path — measured, an echo in the
        ancestor fired twice — and any top-level geometry it emits is unioned
        in twice with no diagnostic anywhere.
        """
        out = []
        for ancestor, paths in sorted(self.ancestor_paths(name).items()):
            if len(paths) > 1:
                out.append((ancestor, paths[0], paths[1]))
        return out

    # ----------------------------------------------------------------------
    # Presentation order
    # ----------------------------------------------------------------------

    def primary_parent(self, name: str) -> str | None:
        """The first declared parent that is a real design, else None.

        "First" is the same order that decides include precedence, so the tree
        a reader sees matches the file OpenSCAD reads.
        """
        parents = self.parents(name)
        return parents[0] if parents else None

    def order(self) -> list[tuple[int, str, str]]:
        """(depth, name, primary parent) for every design, in gallery order.

        Roots alphabetically, each immediately followed by its descendants
        depth-first and alphabetical among siblings. A multi-parent design
        appears exactly once, under its first declared parent — a listing that
        repeated it would make "every design, once" impossible to read off.
        """
        kids: dict[str, list[str]] = defaultdict(list)
        roots = []
        for name in self.names:
            parent = self.primary_parent(name)
            if parent is None:
                roots.append(name)
            else:
                kids[parent].append(name)

        rows: list[tuple[int, str, str]] = []

        def walk(name: str, depth: int, parent: str) -> None:
            rows.append((depth, name, parent))
            for kid in sorted(kids[name]):
                walk(kid, depth + 1, name)

        for root in roots:
            walk(root, 0, "")
        return rows
