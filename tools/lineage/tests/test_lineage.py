"""Fixture-driven tests: build a tiny designs/ tree, point --root at it.

Every rule gets a tree that breaks it and a tree that does not, because a
validation rule that only ever fires is as useless as one that never does.
The trees are the real thing in miniature — designs/<name>/<name>.scad with
real `include <../parent/parent.scad>` lines, ci.parts, derives.conf — so the
tests exercise the same resolution the repo does, not a mock of it.
"""

import json
import struct

import pytest

from lineage import mesh
from lineage.checks import check
from lineage.cli import main
from lineage.conf import DerivesConf, split_replaces
from lineage.graph import Lineage


# --------------------------------------------------------------------------
# Fixture-tree helpers
# --------------------------------------------------------------------------

def design(root, name, *, includes=(), uses=(), conf=None, parts=None,
           body="cube(10);\n"):
    """Write designs/<name>/ with an entry .scad and optional lineage state."""
    directory = root / "designs" / name
    directory.mkdir(parents=True, exist_ok=True)
    lines = [f"include <../{p}/{p}.scad>" for p in includes]
    lines += [f"use <../{p}/{p}.scad>" for p in uses]
    (directory / f"{name}.scad").write_text("\n".join(lines + [body]))
    if conf is not None:
        (directory / "derives.conf").write_text(conf)
    if parts is not None:
        (directory / "ci.parts").write_text("".join(f"{p}\n" for p in parts))
    return directory


def derivative(root, name, parent, *, key="variant-of", extra="", **kwargs):
    """A well-formed single-parent derivative: declared and included, in order."""
    return design(root, name, includes=(parent,),
                  conf=f"{key}: {parent}\n{extra}", **kwargs)


def tree(tmp_path):
    """An empty repo root with a designs/ directory."""
    (tmp_path / "designs").mkdir()
    return tmp_path


def messages(root, names=None):
    """Every check message for a tree, as plain strings."""
    return [p.message for p in check(Lineage.discover(root), names)]


def one(root, names=None):
    """Assert the tree has exactly one problem and return its message."""
    found = messages(root, names)
    assert len(found) == 1, found
    return found[0]


def run(capsys, *argv):
    """Run the CLI, returning (exit code, stdout lines, stderr text)."""
    code = main(list(argv))
    captured = capsys.readouterr()
    return code, captured.out.splitlines(), captured.err


# --------------------------------------------------------------------------
# Happy paths — the tree the rules exist to allow
# --------------------------------------------------------------------------

def test_clean_tree_with_no_lineage_at_all_passes(tmp_path):
    # The state of the repo today: no derives.conf anywhere.
    root = tree(tmp_path)
    design(root, "base")
    design(root, "other")
    assert messages(root) == []


def test_single_parent_happy_path(tmp_path):
    root = tree(tmp_path)
    design(root, "base", parts=["top", "bottom"])
    derivative(root, "deep", "base", extra="replaces: base:top\n")
    assert messages(root) == []
    lineage = Lineage.discover(root)
    assert lineage.parents("deep") == ["base"]
    assert lineage.children("base") == ["deep"]


def test_multi_parent_without_a_diamond_passes(tmp_path):
    root = tree(tmp_path)
    design(root, "hull")
    design(root, "lid")
    design(root, "combo", includes=("hull", "lid"),
           conf="variant-of: hull\nderivative-of: lid\n")
    assert messages(root) == []
    assert Lineage.discover(root).parents("combo") == ["hull", "lid"]


def test_comments_and_blank_lines_are_ignored(tmp_path):
    root = tree(tmp_path)
    design(root, "base", parts=["top"])
    design(root, "deep", includes=("base",), conf=(
        "# Parents in include order. LAST WINS on any module both define.\n"
        "\n"
        "variant-of:    base   # keeps the tray, new lid\n"
        "derivative-of:\n"
        "replaces:      base:top\n"))
    assert messages(root) == []
    conf = DerivesConf.load(root / "designs/deep/derives.conf")
    assert conf.parents == ["base"]
    assert conf.replaces == ("base:top",)


# --------------------------------------------------------------------------
# Rules 1-4 — the parser
# --------------------------------------------------------------------------

def test_rule1_unknown_key(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "deep", includes=("base",),
           conf="variant-of: base\nforked-from: base\n")
    message = one(root)
    assert "unknown key 'forked-from'" in message
    for key in ("variant-of", "derivative-of", "replaces", "diamond-ok"):
        assert key in message


def test_rule2_reuses_is_retired(tmp_path):
    root = tree(tmp_path)
    design(root, "base", parts=["top"])
    design(root, "deep", includes=("base",),
           conf="variant-of: base\nreuses: bottom\n")
    message = one(root)
    assert "'reuses:'" in message
    assert "retired" in message
    assert "delete the line" in message


def test_rule3_line_without_a_colon(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "deep", includes=("base",), conf="variant-of base\n")
    message = one(root)
    assert "'variant-of base'" in message
    assert "has no ':'" in message


def test_rule4_duplicate_key(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "other")
    design(root, "deep", includes=("base", "other"),
           conf="variant-of: base\nvariant-of: other\n")
    found = messages(root)
    assert any("duplicate key 'variant-of'" in m and "line 1" in m
               for m in found), found


def test_a_bad_line_does_not_hide_the_rest_of_the_file(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "deep", includes=("base",),
           conf="variant-of: base\nnonsense\nreuses: top\n")
    found = messages(root)
    assert len(found) == 2, found


# --------------------------------------------------------------------------
# Rules 5, 6, 8 — parent declarations
# --------------------------------------------------------------------------

def test_rule5_parent_must_be_a_design(tmp_path):
    root = tree(tmp_path)
    design(root, "deep", conf="variant-of: ghost\n")
    # One typo, one message: the missing include is not a second problem.
    message = one(root)
    assert "'ghost'" in message
    assert "designs/ghost/ghost.scad" in message


def test_rule6_self_reference(tmp_path):
    root = tree(tmp_path)
    design(root, "deep", conf="variant-of: deep\n")
    message = one(root)
    assert "itself" in message


def test_rule8_same_parent_in_both_keys(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "deep", includes=("base",),
           conf="variant-of: base\nderivative-of: base\n")
    found = messages(root)
    assert any("both variant-of and derivative-of" in m for m in found), found


def test_rule8_same_parent_twice_in_one_key(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "deep", includes=("base",), conf="variant-of: base, base\n")
    found = messages(root)
    assert any("more than once" in m for m in found), found


# --------------------------------------------------------------------------
# Rule 7 — cycles
# --------------------------------------------------------------------------

def test_rule7_cycle_names_the_full_path(tmp_path):
    root = tree(tmp_path)
    design(root, "a", includes=("b",), conf="variant-of: b\n")
    design(root, "b", includes=("a",), conf="variant-of: a\n")
    found = messages(root)
    cycles = [m for m in found if "cycle" in m]
    assert len(cycles) == 1, found
    assert "a -> b -> a" in cycles[0]


def test_rule7_longer_cycle_is_reported_once(tmp_path):
    root = tree(tmp_path)
    design(root, "a", includes=("c",), conf="variant-of: c\n")
    design(root, "b", includes=("a",), conf="variant-of: a\n")
    design(root, "c", includes=("b",), conf="variant-of: b\n")
    cycles = [m for m in messages(root) if "cycle" in m]
    assert len(cycles) == 1, cycles
    assert "a -> c -> b -> a" in cycles[0]


def test_a_cycle_is_reported_even_when_scoped_to_another_member(tmp_path):
    root = tree(tmp_path)
    design(root, "a", includes=("b",), conf="variant-of: b\n")
    design(root, "b", includes=("a",), conf="variant-of: a\n")
    assert any("cycle" in m for m in messages(root, ["b"]))


# --------------------------------------------------------------------------
# Rules 9, 10, 11 — replaces
# --------------------------------------------------------------------------

@pytest.mark.parametrize("entry", ["top", "base:top:extra"])
def test_rule9_replaces_must_be_parent_colon_part(tmp_path, entry):
    root = tree(tmp_path)
    design(root, "base", parts=["top"])
    derivative(root, "deep", "base", extra=f"replaces: {entry}\n")
    message = one(root)
    assert repr(entry) in message
    assert "'<parent>:<part>'" in message


def test_rule10_replaces_parent_must_be_declared(tmp_path):
    root = tree(tmp_path)
    design(root, "base", parts=["top"])
    design(root, "elsewhere", parts=["top"])
    derivative(root, "deep", "base", extra="replaces: elsewhere:top\n")
    message = one(root)
    assert "'elsewhere'" in message
    assert "does not declare" in message


def test_rule11_replaces_part_must_be_in_the_parents_ci_parts(tmp_path):
    root = tree(tmp_path)
    design(root, "base", parts=["top", "bottom"])
    derivative(root, "deep", "base", extra="replaces: base:lid\n")
    message = one(root)
    assert "'lid'" in message
    assert "designs/base/ci.parts" in message
    assert "top, bottom" in message


def test_rule11_parent_without_ci_parts_only_has_the_default_render(tmp_path):
    root = tree(tmp_path)
    design(root, "base")                       # no ci.parts
    derivative(root, "deep", "base", extra="replaces: base:top\n")
    message = one(root)
    assert "ships no ci.parts" in message
    assert "'base:'" in message


def test_rule11_empty_part_is_the_default_render(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    derivative(root, "deep", "base", extra="replaces: base:\n")
    assert messages(root) == []


def test_split_replaces_shapes():
    assert split_replaces("base:top") == ("base", "top")
    assert split_replaces("base:") == ("base", "")
    assert split_replaces("top") is None
    assert split_replaces("a:b:c") is None


# --------------------------------------------------------------------------
# Rule 12 — declaration/include drift
# --------------------------------------------------------------------------

def test_rule12_declared_parent_must_be_included(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "deep", conf="variant-of: base\n")     # no include
    message = one(root)
    assert "does not include it" in message
    assert "include <../base/base.scad>" in message


def test_rule12_use_instead_of_include_is_called_out(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "deep", uses=("base",), conf="variant-of: base\n")
    message = one(root)
    assert "`use`" in message
    assert "overridden" in message


def test_rule12_included_parent_must_be_declared(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "other")
    design(root, "deep", includes=("base", "other"), conf="variant-of: base\n")
    message = one(root)
    assert "'other'" in message
    assert "blast radius" in message


def test_rule12_an_undeclared_derivative_fails_without_a_derives_conf(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "deep", includes=("base",))            # no derives.conf
    message = one(root)
    assert "has no derives.conf" in message
    assert "blast radius" in message


def test_rule12_including_the_same_parent_twice_fails(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "deep", includes=("base", "base"), conf="variant-of: base\n")
    message = one(root)
    assert "includes 'base' 2 times" in message
    assert "evaluated once per line" in message


def test_rule12_include_order_must_match_the_declaration(tmp_path):
    root = tree(tmp_path)
    design(root, "hull")
    design(root, "lid")
    design(root, "combo", includes=("lid", "hull"),
           conf="variant-of: hull, lid\n")
    message = one(root)
    assert "order (hull, lid)" in message
    assert "order (lid, hull)" in message
    assert "which parent wins" in message


def test_commented_out_includes_do_not_count(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "old")
    design(root, "deep", includes=("base",), conf="variant-of: base\n",
           body="// include <../old/old.scad>\n/* include <../old/old.scad> */\n"
                "cube(10);\n")
    assert messages(root) == []


def test_a_sibling_part_file_include_is_not_a_parent(tmp_path):
    # designs/<name>/<name>-top.scad including <name>.scad is the repo's
    # multi-part convention, not a derivation — and the entry file may well
    # include a library the same way.
    root = tree(tmp_path)
    design(root, "solo", body="include <../solo/solo-extra.scad>\ncube(10);\n")
    (root / "designs/solo/solo-extra.scad").write_text("x = 1;\n")
    assert messages(root) == []


# --------------------------------------------------------------------------
# Rules 13, 14 — diamonds
# --------------------------------------------------------------------------

def diamond_tree(tmp_path, *, diamond_ok=""):
    """base <- left, base <- right, both <- leaf: one ancestor, two paths."""
    root = tree(tmp_path)
    design(root, "base")
    derivative(root, "left", "base")
    derivative(root, "right", "base")
    design(root, "leaf", includes=("left", "right"),
           conf=f"variant-of: left, right\n{diamond_ok}")
    return root


def test_rule13_diamond_fails_by_default(tmp_path):
    message = one(diamond_tree(tmp_path))
    assert "diamond on 'base'" in message
    assert "leaf -> left -> base" in message
    assert "leaf -> right -> base" in message
    assert "evaluated once per path" in message
    assert "diamond-ok: base" in message


def test_rule13_diamond_ok_allows_the_diamond(tmp_path):
    assert messages(diamond_tree(tmp_path, diamond_ok="diamond-ok: base\n")) == []


def test_rule14_stale_diamond_ok_fails(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    derivative(root, "deep", "base", extra="diamond-ok: base\n")
    message = one(root)
    assert "diamond-ok names 'base'" in message
    assert "exactly one path" in message


def test_rule14_diamond_ok_naming_a_stranger_fails(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    derivative(root, "deep", "base", extra="diamond-ok: ghost\n")
    message = one(root)
    assert "'ghost'" in message
    assert "not a design" in message


def test_diamond_ok_does_not_leak_to_a_sibling(tmp_path):
    # The assertion is per-design: leaf may vouch for base, its sibling may not.
    root = diamond_tree(tmp_path, diamond_ok="diamond-ok: base\n")
    design(root, "leaf2", includes=("left", "right"),
           conf="variant-of: left, right\n")
    found = messages(root)
    assert len(found) == 1, found
    assert found[0].startswith("diamond on 'base'")
    assert "leaf2" in check(Lineage.discover(root))[0].design


# --------------------------------------------------------------------------
# Graph: blast radius, ancestry, order
# --------------------------------------------------------------------------

def chain(tmp_path):
    """base -> mid -> leaf -> tip, plus an unrelated design."""
    root = tree(tmp_path)
    design(root, "base")
    derivative(root, "mid", "base")
    derivative(root, "leaf", "mid")
    derivative(root, "tip", "leaf")
    design(root, "unrelated")
    return root


def test_blast_radius_is_transitive_over_three_levels(tmp_path):
    lineage = Lineage.discover(chain(tmp_path))
    assert lineage.blast_radius(["base"]) == ["base", "leaf", "mid", "tip"]
    assert lineage.blast_radius(["leaf"]) == ["leaf", "tip"]
    assert lineage.blast_radius(["tip"]) == ["tip"]
    assert lineage.blast_radius(["unrelated"]) == ["unrelated"]


def test_blast_radius_deduplicates_overlapping_inputs(tmp_path):
    lineage = Lineage.discover(chain(tmp_path))
    assert lineage.blast_radius(["base", "mid", "base"]) == [
        "base", "leaf", "mid", "tip"]


def test_ancestors_and_descendants(tmp_path):
    lineage = Lineage.discover(chain(tmp_path))
    assert lineage.ancestors("tip") == ["base", "leaf", "mid"]
    assert lineage.descendants("base") == ["leaf", "mid", "tip"]
    assert lineage.ancestors("base") == []
    assert lineage.descendants("tip") == []


def test_order_with_no_derivatives_is_every_design_at_depth_zero(tmp_path):
    root = tree(tmp_path)
    for name in ("nuggs", "calibration-cube", "sushi"):
        design(root, name)
    assert Lineage.discover(root).order() == [
        (0, "calibration-cube", ""), (0, "nuggs", ""), (0, "sushi", "")]


def test_order_puts_descendants_under_their_parent_depth_first(tmp_path):
    root = chain(tmp_path)
    design(root, "aaa")
    assert Lineage.discover(root).order() == [
        (0, "aaa", ""),
        (0, "base", ""),
        (1, "mid", "base"),
        (2, "leaf", "mid"),
        (3, "tip", "leaf"),
        (0, "unrelated", ""),
    ]


def test_order_lists_a_multi_parent_design_once_under_its_first_parent(tmp_path):
    root = tree(tmp_path)
    design(root, "hull")
    design(root, "lid")
    design(root, "combo", includes=("lid", "hull"),
           conf="variant-of: lid, hull\n")
    rows = Lineage.discover(root).order()
    assert [name for _, name, _ in rows].count("combo") == 1
    assert (1, "combo", "lid") in rows
    assert len(rows) == 3


def test_siblings_are_alphabetical(tmp_path):
    root = tree(tmp_path)
    design(root, "base")
    for name in ("zeta", "alpha", "mid"):
        derivative(root, name, "base")
    assert Lineage.discover(root).order() == [
        (0, "base", ""), (1, "alpha", "base"), (1, "mid", "base"),
        (1, "zeta", "base")]


# --------------------------------------------------------------------------
# CLI — one end-to-end pass per subcommand
# --------------------------------------------------------------------------

def test_cli_check_ok(tmp_path, capsys):
    root = chain(tmp_path)
    code, out, _ = run(capsys, "check", "--root", str(root))
    assert code == 0
    assert len(out) == 1
    assert out[0].startswith("ok    lineage:")


def test_cli_check_reports_one_line_per_problem(tmp_path, capsys):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "deep", includes=("base",),
           conf="variant-of: base\nreuses: top\nbogus: 1\n")
    code, out, _ = run(capsys, "check", "--root", str(root))
    assert code == 1
    assert len(out) == 2
    assert all(line.startswith("FAIL  lineage: deep: ") for line in out)


def test_cli_check_can_be_scoped_to_one_design(tmp_path, capsys):
    root = tree(tmp_path)
    design(root, "base")
    design(root, "broken", conf="nonsense\n")
    code, out, _ = run(capsys, "check", "base", "--root", str(root))
    assert code == 0
    assert "base" in out[0]


def test_cli_check_rejects_an_unknown_design(tmp_path, capsys):
    root = tree(tmp_path)
    design(root, "base")
    code, _, err = run(capsys, "check", "ghost", "--root", str(root))
    assert code == 2
    assert "ghost" in err


def test_cli_blast_radius(tmp_path, capsys):
    root = chain(tmp_path)
    code, out, _ = run(capsys, "blast-radius", "mid", "--root", str(root))
    assert code == 0
    assert out == ["leaf", "mid", "tip"]


def test_cli_blast_radius_passes_unknown_names_through(tmp_path, capsys):
    # CI hands it whatever changed; a deleted or renamed design must not turn
    # the gate list into an error, and must not vanish either.
    root = chain(tmp_path)
    code, out, _ = run(capsys, "blast-radius", "gone", "--root", str(root))
    assert code == 0
    assert out == ["gone"]


def test_cli_blast_radius_fails_closed_on_a_cycle(tmp_path, capsys):
    root = tree(tmp_path)
    design(root, "a", includes=("b",), conf="variant-of: b\n")
    design(root, "b", includes=("a",), conf="variant-of: a\n")
    code, out, err = run(capsys, "blast-radius", "a", "--root", str(root))
    assert code == 1
    assert out == []
    assert "cycle" in err


def test_cli_blast_radius_fails_closed_on_a_parse_error(tmp_path, capsys):
    root = chain(tmp_path)
    (root / "designs/mid/derives.conf").write_text("variant-of base\n")
    code, out, err = run(capsys, "blast-radius", "base", "--root", str(root))
    assert code == 1
    assert out == []
    assert "mid" in err


def test_cli_parents_children_ancestors_descendants(tmp_path, capsys):
    root = chain(tmp_path)
    assert run(capsys, "parents", "leaf", "--root", str(root))[1] == ["mid"]
    assert run(capsys, "children", "base", "--root", str(root))[1] == ["mid"]
    assert run(capsys, "ancestors", "tip", "--root", str(root))[1] == [
        "base", "leaf", "mid"]
    assert run(capsys, "descendants", "base", "--root", str(root))[1] == [
        "leaf", "mid", "tip"]


def test_cli_parents_keeps_include_order(tmp_path, capsys):
    root = tree(tmp_path)
    design(root, "hull")
    design(root, "lid")
    design(root, "combo", includes=("lid", "hull"),
           conf="variant-of: lid\nderivative-of: hull\n")
    code, out, _ = run(capsys, "parents", "combo", "--root", str(root))
    assert code == 0
    assert out == ["lid", "hull"]


def test_cli_replaces_output_shape(tmp_path, capsys):
    root = tree(tmp_path)
    design(root, "base", parts=["top", "door"])
    design(root, "plain")
    design(root, "deep", includes=("base", "plain"),
           conf="variant-of: base, plain\nreplaces: base:top, base:door, plain:\n")
    code, out, _ = run(capsys, "replaces", "deep", "--root", str(root))
    assert code == 0
    assert out == ["base\ttop", "base\tdoor", "plain\t"]


def test_cli_replaces_is_silent_without_a_derives_conf(tmp_path, capsys):
    root = tree(tmp_path)
    design(root, "base")
    code, out, _ = run(capsys, "replaces", "base", "--root", str(root))
    assert code == 0
    assert out == []


def test_cli_base_safe_required(tmp_path, capsys):
    root = diamond_tree(tmp_path, diamond_ok="diamond-ok: base\n")
    code, out, _ = run(capsys, "base-safe-required", "leaf", "--root", str(root))
    assert code == 0
    assert out == ["base"]
    assert run(capsys, "base-safe-required", "left", "--root", str(root))[1] == []


def test_cli_order(tmp_path, capsys):
    root = chain(tmp_path)
    code, out, _ = run(capsys, "order", "--root", str(root))
    assert code == 0
    assert out[0] == "0\tbase\t"
    assert out[1] == "1\tmid\tbase"
    assert out[-1] == "0\tunrelated\t"
    assert len(out) == 5


def test_cli_order_fails_on_a_cycle(tmp_path, capsys):
    root = tree(tmp_path)
    design(root, "a", includes=("b",), conf="variant-of: b\n")
    design(root, "b", includes=("a",), conf="variant-of: a\n")
    code, out, err = run(capsys, "order", "--root", str(root))
    assert code == 1
    assert out == []
    assert "cycle" in err


def test_cli_graph_text(tmp_path, capsys):
    root = chain(tmp_path)
    code, out, _ = run(capsys, "graph", "--root", str(root))
    assert code == 0
    body = "\n".join(out)
    assert "5 design(s), 3 with parents" in body
    assert "\nbase\n└─ mid\n    └─ leaf\n        └─ tip\nunrelated" in body


def test_cli_graph_text_spells_out_a_second_parent(tmp_path, capsys):
    # Which parent wins is decided by include order, so a multi-parent design
    # must not be shown as if it hung off one branch and nothing else.
    root = tree(tmp_path)
    design(root, "hull")
    design(root, "lid")
    design(root, "combo", includes=("hull", "lid"),
           conf="variant-of: hull, lid\n")
    code, out, _ = run(capsys, "graph", "--root", str(root))
    assert code == 0
    assert "└─ combo  (parents: hull, lid)" in "\n".join(out)


def test_cli_graph_json(tmp_path, capsys):
    root = tree(tmp_path)
    design(root, "base", parts=["top"])
    derivative(root, "deep", "base", extra="replaces: base:top\n")
    code, out, _ = run(capsys, "graph", "--format", "json", "--root", str(root))
    assert code == 0
    payload = json.loads("\n".join(out))
    by_name = {d["name"]: d for d in payload["designs"]}
    assert by_name["deep"]["parents"] == ["base"]
    assert by_name["deep"]["depth"] == 1
    assert by_name["deep"]["primary_parent"] == "base"
    assert by_name["deep"]["replaces"] == [
        {"raw": "base:top", "parent": "base", "part": "top"}]
    assert by_name["base"]["descendants"] == ["deep"]
    assert payload["cycles"] == []


def test_cli_rejects_a_root_without_designs(tmp_path, capsys):
    code, _, err = run(capsys, "check", "--root", str(tmp_path))
    assert code == 2
    assert "designs does not exist" in err


# --------------------------------------------------------------------------
# Mesh identity — the geometry half of the derivative gate
#
# These pin the reason mesh_hash exists at all. OpenSCAD 2021.01 writes the
# same mesh's facets in a different ORDER between renders of unchanged source
# (measured on sushi-battleship part=top: same 24256 facets, same file size,
# 3248 differing bytes, identical once sorted). A byte hash therefore reports
# "these differ" for two renders of the same thing — which, in the override
# check, means the derivative always looks different from its parent and the
# gate passes unconditionally. The shuffle test below is that failure in
# miniature, and it is the one that must never start passing by accident.
# --------------------------------------------------------------------------

def stl_bytes(triangles, header=b"OpenSCAD Model\n"):
    """A binary STL carrying `triangles`, each a 9-tuple of vertex floats."""
    out = bytearray(header.ljust(mesh.HEADER_BYTES, b"\0")[:mesh.HEADER_BYTES])
    out += struct.pack("<I", len(triangles))
    for tri in triangles:
        out += struct.pack("<3f", 0.0, 0.0, 0.0)     # normal, ignored
        out += struct.pack("<9f", *tri)
        out += struct.pack("<H", 0)                  # attribute byte count
    return bytes(out)


TRIS = [
    (0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0),
    (1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0),
    (0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 1.0, 1.0),
]


def test_mesh_hash_ignores_facet_order(tmp_path):
    a = tmp_path / "a.stl"
    b = tmp_path / "b.stl"
    a.write_bytes(stl_bytes(TRIS))
    b.write_bytes(stl_bytes(list(reversed(TRIS))))
    assert a.read_bytes() != b.read_bytes()          # the bytes really do differ
    assert mesh.mesh_hash(a) == mesh.mesh_hash(b)


def test_mesh_hash_separates_different_geometry(tmp_path):
    a = tmp_path / "a.stl"
    b = tmp_path / "b.stl"
    a.write_bytes(stl_bytes(TRIS))
    moved = [TRIS[0], TRIS[1], tuple(v + 0.5 for v in TRIS[2])]
    b.write_bytes(stl_bytes(moved))
    assert mesh.mesh_hash(a) != mesh.mesh_hash(b)


def test_mesh_hash_treats_negative_zero_as_zero(tmp_path):
    a = tmp_path / "a.stl"
    b = tmp_path / "b.stl"
    a.write_bytes(stl_bytes([(0.0,) * 9]))
    b.write_bytes(stl_bytes([(-0.0,) * 9]))
    assert a.read_bytes() != b.read_bytes()
    assert mesh.mesh_hash(a) == mesh.mesh_hash(b)


def test_missing_and_empty_meshes_share_one_identity(tmp_path):
    """A base-safe render writes no file; that must be a value, not a crash.

    And it must equal the identity of a written-but-facetless mesh, so the two
    ways of saying "nothing" cannot make an override look successful.
    """
    absent = tmp_path / "nope.stl"
    empty = tmp_path / "empty.stl"
    empty.write_bytes(stl_bytes([]))
    assert mesh.mesh_hash(absent) == mesh.EMPTY
    assert mesh.mesh_hash(empty) == mesh.EMPTY
    assert mesh.facet_count(absent) == 0
    assert mesh.facet_count(empty) == 0


def test_truncated_mesh_is_an_error_not_an_empty_one(tmp_path):
    """A half-written STL must never read as 'no geometry'.

    That is the base-safety proof's pass condition, so a truncated file
    silently answering zero would prove a design base-safe by failing to read
    it.
    """
    stl = tmp_path / "trunc.stl"
    stl.write_bytes(stl_bytes(TRIS)[:-20])
    with pytest.raises(mesh.MalformedSTL):
        mesh.mesh_hash(stl)
    stl.write_bytes(b"tiny")
    with pytest.raises(mesh.MalformedSTL):
        mesh.facet_count(stl)


def test_cli_mesh_hash_and_facet_count(tmp_path, capsys):
    stl = tmp_path / "m.stl"
    stl.write_bytes(stl_bytes(TRIS))
    code, out, _ = run(capsys, "mesh-hash", str(stl))
    assert code == 0 and len(out[0]) == 64
    code, out, _ = run(capsys, "facet-count", str(stl))
    assert code == 0 and out[0] == "3"
    code, out, _ = run(capsys, "mesh-hash", str(tmp_path / "absent.stl"))
    assert code == 0 and out[0] == mesh.EMPTY


def test_cli_mesh_hash_fails_on_a_malformed_stl(tmp_path, capsys):
    """Exit 1, not 2: a broken export is the design's problem, not the user's."""
    stl = tmp_path / "bad.stl"
    stl.write_bytes(stl_bytes(TRIS)[:-20])
    code, _, err = run(capsys, "mesh-hash", str(stl))
    assert code == 1
    assert "bad.stl" in err
