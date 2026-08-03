"""Command-line interface: lineage check | blast-radius | parents | ...

Exit codes are the contract, because scripts/gate.sh and CI read them:
  0  the question has an answer, and it is on stdout
  1  the tree is wrong (check) or unanswerable (blast-radius on a cycle)
  2  the invocation is wrong — no such design, no such root

`blast-radius` in particular must never fail open. It decides which designs a
push re-gates; answering "nothing" because a file did not parse would skip
exactly the gate the broken file needed.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from .checks import check, summary
from .conf import split_replaces
from .graph import Lineage
from .mesh import MalformedSTL, facet_count, mesh_hash


def find_root(start: Path) -> Path:
    """Walk up from `start` to the nearest directory holding designs/.

    So the tool answers the same way from anywhere in the checkout — the
    scripts cd to the repo root, humans do not.
    """
    for candidate in (start, *start.parents):
        if (candidate / "designs").is_dir():
            return candidate
    return start


def load(args) -> Lineage:
    """Resolve --root and discover the forest under it."""
    root = Path(args.root).resolve() if args.root else find_root(Path.cwd())
    if not (root / "designs").is_dir():
        raise ValueError(f"{root}/designs does not exist — pass --root <repo>")
    return Lineage.discover(root)


def require(lineage: Lineage, name: str) -> str:
    """Fail loudly on a design that does not exist.

    Answering "no parents" for a misspelled name would be a confident wrong
    answer, and every consumer of these commands treats an empty list as
    "nothing to do".
    """
    if name not in lineage:
        raise ValueError(f"no design named {name!r} under "
                         f"{lineage.root}/designs")
    return name


# --------------------------------------------------------------------------
# Subcommands
# --------------------------------------------------------------------------

def cmd_check(args) -> int:
    """Validate derives.conf across the tree (or the named designs)."""
    lineage = load(args)
    names = [require(lineage, n) for n in dict.fromkeys(args.name)] or None
    problems = check(lineage, names)
    for problem in problems:
        print(problem.format())
    if problems:
        return 1
    print(summary(lineage, names))
    return 0


def cmd_blast_radius(args) -> int:
    """Print the designs a change to the named ones has to re-gate."""
    lineage = load(args)
    broken = [d.name for d in lineage.designs.values()
              if d.conf is not None and d.conf.problems]
    if broken:
        print(f"lineage: cannot compute a blast radius — derives.conf does "
              f"not parse in: {', '.join(sorted(broken))}. Run "
              f"`lineage check`.", file=sys.stderr)
        return 1
    cycles = lineage.find_cycles()
    if cycles:
        loops = "; ".join(" -> ".join(c) for c in cycles)
        print(f"lineage: cannot compute a blast radius — lineage cycle "
              f"{loops}. Run `lineage check`.", file=sys.stderr)
        return 1
    for name in lineage.blast_radius(args.name):
        print(name)
    return 0


def cmd_parents(args) -> int:
    """Direct parents that are real designs, in include order.

    Filtered, not `declared_parents`. Every consumer of this command turns a
    parent name into a path — readme-gate.sh demands a link to
    `../<parent>/`, gallery.sh writes one into the README — so handing back a
    name with no design behind it makes them insist on a link that 404s, which
    is the one thing readme-gate's own rule says it will not gate in. A parent
    that is not a design is `lineage check`'s finding and only its finding;
    reporting it a second time, as a demand to link it, helps nobody.

    This is also what `order` and `primary_parent` already traverse, so the
    nesting a reader sees and the credit they see now come from one list.
    """
    lineage = load(args)
    for name in lineage.parents(require(lineage, args.name)):
        print(name)
    return 0


def cmd_children(args) -> int:
    """Direct children, sorted."""
    lineage = load(args)
    for name in lineage.children(require(lineage, args.name)):
        print(name)
    return 0


def cmd_ancestors(args) -> int:
    """Transitive parents, sorted."""
    lineage = load(args)
    for name in lineage.ancestors(require(lineage, args.name)):
        print(name)
    return 0


def cmd_descendants(args) -> int:
    """Transitive children, sorted."""
    lineage = load(args)
    for name in lineage.descendants(require(lineage, args.name)):
        print(name)
    return 0


def cmd_replaces(args) -> int:
    """TAB-separated parent and part per replaces entry; empty part = default."""
    lineage = load(args)
    design = lineage.designs[require(lineage, args.name)]
    if design.conf is None:
        return 0
    for item in design.conf.replaces:
        split = split_replaces(item)
        if split is None:
            raise ValueError(f"{design.name}: replaces entry {item!r} is not "
                             f"'<parent>:<part>' — run `lineage check`")
        parent, part = split
        print(f"{parent}\t{part}")
    return 0


def cmd_base_safe_required(args) -> int:
    """The ancestors this design asserts are base-safe, for the gate to prove."""
    lineage = load(args)
    design = lineage.designs[require(lineage, args.name)]
    for ancestor in sorted(set(design.diamond_ok)):
        print(ancestor)
    return 0


def cmd_order(args) -> int:
    """Every design in gallery order: depth, name, primary parent."""
    lineage = load(args)
    cycles = lineage.find_cycles()
    if cycles:
        loops = "; ".join(" -> ".join(c) for c in cycles)
        print(f"lineage: no order exists — lineage cycle {loops}. Run "
              f"`lineage check`.", file=sys.stderr)
        return 1
    for depth, name, parent in lineage.order():
        print(f"{depth}\t{name}\t{parent}")
    return 0


def _annotations(lineage: Lineage, name: str) -> str:
    """The parenthetical after a name in the text graph, or empty."""
    design = lineage.designs[name]
    bits = []
    parents = design.declared_parents
    primary = lineage.primary_parent(name)
    # The primary parent is already the row this one hangs off, so it is only
    # worth spelling out when the list is not just that: a second parent (whose
    # position decides which one wins) or a parent that is not a design.
    if parents != ([primary] if primary else []):
        bits.append("parents: " + ", ".join(parents))
    if design.conf is not None:
        if design.conf.replaces:
            bits.append("replaces: " + ", ".join(design.conf.replaces))
        if design.diamond_ok:
            bits.append("diamond-ok: " + ", ".join(design.diamond_ok))
    return f"  ({'; '.join(bits)})" if bits else ""


def _tree_prefixes(rows) -> list[str]:
    """The box-drawing prefix for each row of `order()` output.

    Rows are depth-first, so a row is the last of its siblings when no later
    row shares its depth before one gets shallower — which is also what says
    whether an ancestor's branch line has to keep running down the page.
    """
    last = []
    for i, (depth, _, _) in enumerate(rows):
        following = [d for d, _, _ in rows[i + 1:]]
        end = next((j for j, d in enumerate(following) if d < depth),
                   len(following))
        last.append(depth not in following[:end])

    prefixes = []
    branch: list[bool] = []
    for i, (depth, _, _) in enumerate(rows):
        del branch[depth:]
        branch.append(last[i])
        indent = "".join("    " if branch[k] else "│   " for k in range(1, depth))
        prefixes.append("" if depth == 0
                        else indent + ("└─ " if last[i] else "├─ "))
    return prefixes


def cmd_graph(args) -> int:
    """Human or machine view of the whole lineage forest."""
    lineage = load(args)
    if args.format == "json":
        depths = {name: depth for depth, name, _ in lineage.order()}
        payload = {
            "root": str(lineage.root),
            "cycles": lineage.find_cycles(),
            "designs": [],
        }
        for name in lineage.names:
            design = lineage.designs[name]
            replaces = []
            for item in design.conf.replaces if design.conf else ():
                split = split_replaces(item)
                replaces.append({
                    "raw": item,
                    "parent": split[0] if split else None,
                    "part": split[1] if split else None,
                })
            payload["designs"].append({
                "name": name,
                "has_derives_conf": design.conf is not None,
                "depth": depths.get(name),
                "primary_parent": lineage.primary_parent(name),
                "parents": design.declared_parents,
                "children": lineage.children(name),
                "ancestors": lineage.ancestors(name),
                "descendants": lineage.descendants(name),
                "replaces": replaces,
                "diamond_ok": list(design.diamond_ok),
            })
        print(json.dumps(payload, indent=2))
        return 0

    total = len(lineage.designs)
    derived = len(lineage.derivatives)
    print(f"lineage: {total} design(s), {derived} with parents")
    print()
    cycles = lineage.find_cycles()
    if cycles:
        for cycle in cycles:
            print("cycle: " + " -> ".join(cycle))
        print()
    rows = lineage.order()
    for (_, name, _), prefix in zip(rows, _tree_prefixes(rows)):
        print(f"{prefix}{name}{_annotations(lineage, name)}")
    listed = {name for _, name, _ in rows}
    for name in lineage.names:
        if name not in listed:                  # only reachable via a cycle
            print(f"?  {name}{_annotations(lineage, name)}")
    return 0


def cmd_mesh_hash(args) -> int:
    """Print a facet-order-independent identity for an exported mesh.

    scripts/gate.sh compares the derivative's part against the parent's with
    this. It lives here rather than in the shell because the identity has to
    ignore facet order (see mesh.py: OpenSCAD reorders facets between runs of
    unchanged source) and that is not a thing `sha256sum` can be talked into.
    """
    print(mesh_hash(args.stl))
    return 0


def cmd_facet_count(args) -> int:
    """Print the facet count of an exported mesh; 0 when there is no file."""
    print(facet_count(args.stl))
    return 0


# --------------------------------------------------------------------------
# Parser
# --------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    """Build the lineage argument parser."""
    p = argparse.ArgumentParser(
        prog="lineage",
        description="Resolve and validate design lineage: which design "
                    "derives from which, and what a change has to re-gate.")
    # --root on every subcommand rather than before them: the scripts call
    # `lineage <cmd> --root ...`, and the tests point it at fixture trees.
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--root", default=None, metavar="DIR",
                        help="repo root to read designs/ from "
                             "(default: the repo the cwd is in)")
    sub = p.add_subparsers(dest="command", required=True)

    c = sub.add_parser("check", parents=[common],
                       help="validate derives.conf across the tree")
    c.add_argument("name", nargs="*", help="designs to check (default: all)")

    b = sub.add_parser("blast-radius", parents=[common],
                       help="the designs a change to these has to re-gate")
    b.add_argument("name", nargs="+", help="changed design name(s)")

    for name, help_text in (
            ("parents", "direct parents, in include order"),
            ("children", "direct children, sorted"),
            ("ancestors", "transitive parents, sorted"),
            ("descendants", "transitive children, sorted"),
            ("replaces", "TAB-separated parent and part, one per entry"),
            ("base-safe-required",
             "ancestors this design asserts are base-safe")):
        s = sub.add_parser(name, parents=[common], help=help_text)
        s.add_argument("name", help="design name")

    sub.add_parser("order", parents=[common],
                   help="every design in gallery order: depth, name, parent")

    g = sub.add_parser("graph", parents=[common],
                       help="the whole lineage forest, for humans or machines")
    g.add_argument("--format", choices=("text", "json"), default="text",
                   help="output format (default: text)")

    # These two read one exported STL and never look at designs/, so they take
    # no --root. They are the geometry half of the derivative gate, called from
    # scripts/lineage.sh.
    m = sub.add_parser("mesh-hash",
                       help="facet-order-independent identity of a binary STL")
    m.add_argument("stl", help="path to a binary STL (need not exist)")

    fc = sub.add_parser("facet-count",
                        help="facet count of a binary STL (0 when absent)")
    fc.add_argument("stl", help="path to a binary STL (need not exist)")
    return p


HANDLERS = {
    "check": cmd_check,
    "blast-radius": cmd_blast_radius,
    "parents": cmd_parents,
    "children": cmd_children,
    "ancestors": cmd_ancestors,
    "descendants": cmd_descendants,
    "replaces": cmd_replaces,
    "base-safe-required": cmd_base_safe_required,
    "order": cmd_order,
    "graph": cmd_graph,
    "mesh-hash": cmd_mesh_hash,
    "facet-count": cmd_facet_count,
}


def main(argv: list[str] | None = None) -> int:
    """Entry point: dispatch to the subcommand and map errors to exit codes."""
    args = build_parser().parse_args(argv)
    try:
        return HANDLERS[args.command](args)
    except MalformedSTL as exc:
        # Its own case, ahead of ValueError (which it subclasses): a mesh that
        # cannot be read is a broken render, not a bad invocation, and the gate
        # has to fail the design rather than report a usage error against it.
        print(f"lineage: {getattr(args, 'stl', '?')}: {exc}", file=sys.stderr)
        return 1
    except (FileNotFoundError, NotADirectoryError, ValueError) as exc:
        print(f"lineage: {exc}", file=sys.stderr)
        return 2
    except BrokenPipeError:
        # `lineage graph | head` closes the pipe early. Point stdout at
        # devnull so the interpreter's final flush cannot raise again and
        # print a traceback over the user's terminal.
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        return 141                      # 128 + SIGPIPE, as a shell reports it


if __name__ == "__main__":
    sys.exit(main())
