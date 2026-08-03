"""Validation rules for derives.conf and the graph it describes.

Every rule here exists because OpenSCAD will not tell you: an override that
never took, a parent that never got included, an include order that quietly
picked the other parent, a shared ancestor evaluated twice. All of those exit
0 with a watertight, sliceable, 100/100 STL — of the wrong part. So the
messages are written to be actionable on their own: name the design, quote the
offending text, say what to do about it.

The rules that need geometry are deliberately NOT here. Proving an override
actually took, and proving a base is safe to sit at the confluence of a
diamond, both require rendering; that lives in scripts/gate.sh. This module
never renders anything.
"""

from __future__ import annotations

from dataclasses import dataclass

from .conf import PARENT_KEYS, split_replaces
from .graph import Lineage


@dataclass(frozen=True)
class Problem:
    """One validation failure, already attributed to a design."""

    design: str
    message: str

    def format(self) -> str:
        """The single line `lineage check` prints for this problem."""
        return f"FAIL  lineage: {self.design}: {self.message}"


def _list(names) -> str:
    """Render a name list for a message, or a visible marker when empty."""
    return ", ".join(names) if names else "(none)"


def _path(path) -> str:
    """Render a lineage path child -> ... -> ancestor."""
    return " -> ".join(path)


# --------------------------------------------------------------------------
# Rules 5, 6, 8 — the parent declarations themselves
# --------------------------------------------------------------------------

def check_parents(lineage: Lineage, name: str) -> list[Problem]:
    """Rules 5, 6, 8: parents must exist, not be self, and be named once."""
    design = lineage.designs[name]
    conf = design.conf
    problems = []
    if conf is None:
        return problems

    for entry in conf.entries:
        if entry.key not in PARENT_KEYS:
            continue
        for parent in entry.values:
            if parent == name:
                problems.append(Problem(name, (
                    f"{entry.key} names this design itself — a design cannot "
                    f"derive from itself")))
            elif parent not in lineage.designs:
                problems.append(Problem(name, (
                    f"{entry.key} names {parent!r}, which is not a design — "
                    f"designs/{parent}/{parent}.scad does not exist")))

    for parent in dict.fromkeys(conf.parents):
        keys = conf.parent_keys(parent)
        if len(keys) < 2:
            continue
        if len(set(keys)) > 1:
            problems.append(Problem(name, (
                f"{parent!r} is named in both variant-of and derivative-of — "
                f"pick the one that describes the relationship (the tooling "
                f"treats them identically); named twice it enters the ordered "
                f"parent list twice, which no set of include lines can match")))
        else:
            problems.append(Problem(name, (
                f"{keys[0]} names {parent!r} more than once — the parent list "
                f"is positional (the last include of a module wins), so a "
                f"repeat is a typo the include lines can never match")))
    return problems


# --------------------------------------------------------------------------
# Rule 7 — cycles
# --------------------------------------------------------------------------

def cycle_problem(cycle: list[str]) -> Problem:
    """Word one cycle, attributed to its alphabetically first member."""
    return Problem(cycle[0], (
        f"lineage cycle {_path(cycle)} — a design cannot be its own ancestor; "
        f"the includes would recurse and nothing downstream (blast radius, "
        f"gallery order) has an answer. Delete one of the parent declarations "
        f"in the loop"))


def check_cycles(lineage: Lineage) -> list[Problem]:
    """Rule 7: no design may be its own ancestor, however indirectly."""
    return [cycle_problem(cycle) for cycle in lineage.find_cycles()]


# --------------------------------------------------------------------------
# Rules 9, 10, 11 — replaces
# --------------------------------------------------------------------------

def check_replaces(lineage: Lineage, name: str) -> list[Problem]:
    """Rules 9, 10, 11: every `replaces` entry names a real parent and part."""
    design = lineage.designs[name]
    conf = design.conf
    problems = []
    if conf is None:
        return problems
    declared = conf.parents

    for item in conf.replaces:
        split = split_replaces(item)
        if split is None:
            problems.append(Problem(name, (
                f"replaces entry {item!r} is not '<parent>:<part>' — it has "
                f"{item.count(':')} colons. With more than one parent a bare "
                f"part name cannot be resolved, so the parent is always "
                f"written out: 'base:top', or 'base:' for the parent's "
                f"default render")))
            continue
        parent, part = split
        if not parent:
            problems.append(Problem(name, (
                f"replaces entry {item!r} names no parent — write "
                f"'<parent>:{part}' so it is clear which parent's part this "
                f"replaces")))
            continue
        if parent not in declared:
            problems.append(Problem(name, (
                f"replaces names parent {parent!r}, which this design does "
                f"not declare (declared: {_list(declared)}) — a replacement "
                f"only means something against a parent this design "
                f"includes")))
            continue
        if parent not in lineage.designs:
            continue                    # already reported by rule 5
        target = lineage.designs[parent]
        if not target.has_ci_parts:
            if part:
                problems.append(Problem(name, (
                    f"replaces names part {part!r} of parent {parent!r}, but "
                    f"{parent} ships no ci.parts — its only render is the "
                    f"default one, so write '{parent}:' (or give {parent} a "
                    f"ci.parts naming {part})")))
        elif part and part not in target.parts:
            problems.append(Problem(name, (
                f"replaces names part {part!r} of parent {parent!r}, which is "
                f"not in designs/{parent}/ci.parts ({_list(target.parts)}) — "
                f"a part the parent does not render cannot be the thing this "
                f"design changes")))
    return problems


# --------------------------------------------------------------------------
# Rule 12 — declaration/include drift
# --------------------------------------------------------------------------

def check_include_drift(lineage: Lineage, name: str) -> list[Problem]:
    """Rule 12: the declared parent list must equal the entry .scad's includes.

    Both membership and order. Order because two parents defining the same
    module are resolved by last-include-wins with no diagnostic at all —
    measured: swapping two include lines changed the exported mesh (12 facets
    vs 72) and OpenSCAD said nothing either way. A declaration that disagrees
    with the file is worse than no declaration, because everything downstream
    believes it.
    """
    design = lineage.designs[name]
    declared = design.declared_parents
    included = lineage.scad_parents(name)
    entry = f"designs/{name}/{name}.scad"
    problems = []

    # No derives.conf at all is the same failure wearing a different hat: the
    # design IS a derivative — it includes one — and nothing in the repo knows
    # it, so a change to the parent re-gates everything except the design most
    # likely to break.
    if design.conf is None:
        if included:
            problems.append(Problem(name, (
                f"{entry} includes {_list(included)}, so this design derives "
                f"from {'them' if len(included) > 1 else 'it'}, but "
                f"designs/{name}/ has no derives.conf — an undeclared parent "
                f"is invisible to the blast radius, so changing the parent "
                f"would not re-gate this design")))
        return problems

    # A parent included twice is the diamond hazard inside a single file: the
    # same unguarded include, the same double evaluation, and no path through
    # the graph to notice it. Report it on its own — compared against a
    # single declaration it would otherwise surface as a baffling "order"
    # complaint about the same name twice.
    repeats = [p for p in dict.fromkeys(included) if included.count(p) > 1]
    if repeats:
        for parent in repeats:
            problems.append(Problem(name, (
                f"{entry} includes {parent!r} {included.count(parent)} times — "
                f"include is not guarded, so {parent} is evaluated once per "
                f"line and any top-level geometry it emits is unioned in that "
                f"many times, silently; delete the extra include")))
        return problems

    if set(declared) != set(included):
        used = set(lineage.scad_parents(name, "use"))
        for parent in declared:
            if parent in included:
                continue
            if parent == name or parent not in lineage.designs:
                # Rules 5 and 6 already said what is wrong with this name;
                # "and you never include it" is a true sentence about an
                # imaginary parent, and two messages for one typo teaches
                # people to skim.
                continue
            hint = ""
            if parent in used:
                hint = (f"; {entry} has `use <...>` for it, and `use` imports "
                        f"modules without pulling the source in — the parent's "
                        f"own call sites keep calling the parent's version, so "
                        f"nothing is overridden")
            problems.append(Problem(name, (
                f"declares parent {parent!r} but {entry} does not include it{hint}"
                f" — add `include <../{parent}/{parent}.scad>`; the "
                f"declaration is documentation, the include is what OpenSCAD "
                f"reads")))
        for parent in included:
            if parent in declared:
                continue
            problems.append(Problem(name, (
                f"{entry} includes parent {parent!r} but derives.conf does "
                f"not declare it — add it to variant-of or derivative-of; an "
                f"undeclared parent is invisible to the blast radius, so a "
                f"change to {parent} would not re-gate this design")))
    elif declared != included:
        problems.append(Problem(name, (
            f"declares parents in the order ({_list(declared)}) but {entry} "
            f"includes them in the order ({_list(included)}) — include order "
            f"silently decides which parent wins when both define the same "
            f"module (measured: swapping two include lines changed the mesh, "
            f"with no warning), so the declaration has to match the file")))
    return problems


# --------------------------------------------------------------------------
# Rules 13, 14 — diamonds and the assertions that allow them
# --------------------------------------------------------------------------

def check_diamonds(lineage: Lineage, name: str) -> list[Problem]:
    """Rules 13, 14: diamonds fail unless explicitly, currently, asserted.

    `include` is not guarded: a shared ancestor reached by two paths is
    evaluated once per path (echo-counted: fired twice), and any top-level
    geometry it emits is unioned in twice. The duplicate unions cleanly — one
    body, watertight, printcheck 100/100 — so nothing downstream can see it.
    """
    design = lineage.designs[name]
    allowed = set(design.diamond_ok)
    diamonds = lineage.diamonds(name)
    confluences = {ancestor for ancestor, _, _ in diamonds}
    problems = []

    for ancestor, first, second in diamonds:
        if ancestor in allowed:
            continue
        problems.append(Problem(name, (
            f"diamond on {ancestor!r}: reachable by two paths "
            f"({_path(first)}) and ({_path(second)}) — include is not "
            f"guarded, so {ancestor} is evaluated once per path and any "
            f"top-level geometry it emits is unioned in twice, silently "
            f"(the duplicate merges cleanly and stays watertight). Drop one "
            f"path, or — if {ancestor} is base-safe, i.e. its top level only "
            f"defines modules and emits no geometry — declare "
            f"'diamond-ok: {ancestor}' and let the render gate prove it")))

    if design.conf is None:
        return problems
    for ancestor in design.diamond_ok:
        if ancestor in confluences:
            continue
        if ancestor not in lineage.designs:
            why = f"{ancestor} is not a design"
        elif ancestor in lineage.ancestors(name):
            why = f"{ancestor} is an ancestor by exactly one path"
        else:
            why = f"{ancestor} is not an ancestor of this design at all"
        problems.append(Problem(name, (
            f"diamond-ok names {ancestor!r}, which is not a diamond "
            f"confluence for this design ({why}) — delete the line. An "
            f"assertion that has silently stopped applying is the same class "
            f"of bug it was written to prevent")))
    return problems


# --------------------------------------------------------------------------
# The whole check
# --------------------------------------------------------------------------

def check(lineage: Lineage, names=None) -> list[Problem]:
    """Validate the tree (or just `names`), in design order, rule order.

    Rules 1-4 come out of the parser (conf.py) already worded; the rest need
    the tree. Diamond rules are skipped for any design tangled in a cycle:
    "you are your own ancestor" makes every derived question meaningless, and
    piling ten confusing failures on top of the one real one helps nobody.
    """
    scope = list(lineage.names) if names is None else list(names)
    cycles = lineage.find_cycles()
    cycle_members = {n for cycle in cycles for n in cycle}
    by_design: dict[str, list[Problem]] = {}
    for cycle in cycles:
        by_design.setdefault(cycle[0], []).append(cycle_problem(cycle))

    problems = []
    for name in sorted(scope):
        design = lineage.designs.get(name)
        if design is None:
            continue
        # Syntax before semantics, the way a compiler does it. A file that did
        # not parse has no trustworthy parent list, and "you declared a parent
        # you never include" on top of "line 1 has no colon" sends the reader
        # chasing a second problem that does not exist.
        if design.conf is not None and design.conf.problems:
            problems.extend(Problem(name, m) for m in design.conf.problems)
            problems.extend(by_design.get(name, []))
            continue
        problems.extend(check_parents(lineage, name))
        problems.extend(by_design.get(name, []))
        problems.extend(check_replaces(lineage, name))
        problems.extend(check_include_drift(lineage, name))
        if not (cycle_members & ({name} | set(lineage.ancestors(name)))):
            problems.extend(check_diamonds(lineage, name))

    # A cycle whose alphabetically-first member is out of scope still has to
    # surface: `lineage check <one-design>` that says "ok" while the tree it
    # sits in is circular is the kind of green nobody should trust.
    if names is not None:
        in_scope = set(scope)
        for cycle in cycles:
            if cycle[0] not in in_scope and in_scope & set(cycle):
                problems.append(cycle_problem(cycle))
    return problems


def summary(lineage: Lineage, names=None) -> str:
    """The one-line `ok` message.

    It reports what was actually looked at, so a green line cannot be
    mistaken for a green tree: `lineage check <one-name>` says so.
    """
    scope = sorted(lineage.names if names is None else names)
    derived = [n for n in scope if lineage.designs[n].declared_parents]
    if names is not None:
        return (f"ok    lineage: {len(scope)} design(s) checked "
                f"({', '.join(scope)}), {len(derived)} with parents")
    if not derived:
        return (f"ok    lineage: {len(scope)} design(s), none declares a "
                f"parent (no derives.conf in the tree)")
    depth = max(d for d, _, _ in lineage.order())
    return (f"ok    lineage: {len(scope)} design(s), {len(derived)} with "
            f"parents, deepest chain {depth + 1}")
