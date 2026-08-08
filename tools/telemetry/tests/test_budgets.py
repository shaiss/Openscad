import pytest

from telemetry import budgets

GIF_BUDGET = 1000
SHOT_BUDGET = 500


def _tree(tmp_path, files):
    designs = tmp_path / "designs"
    for rel, size in files.items():
        p = designs / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(b"x" * size)
    return designs


def test_scan_matches_extension_to_budget(tmp_path):
    designs = _tree(tmp_path, {
        "a/previews/turntable.gif": 900,
        "a/previews/hero.png": 100,
    })
    got = budgets.scan(designs, GIF_BUDGET, SHOT_BUDGET)
    by_file = {e["file"]: e for e in got}
    gif = by_file[(designs / "a/previews/turntable.gif").as_posix()]
    png = by_file[(designs / "a/previews/hero.png").as_posix()]
    assert gif["budget"] == GIF_BUDGET and gif["headroom_pct"] == 10.0
    assert png["budget"] == SHOT_BUDGET and png["headroom_pct"] == 80.0


def test_scan_is_worst_first(tmp_path):
    designs = _tree(tmp_path, {
        "a/previews/roomy.gif": 100,
        "b/previews/tight.gif": 990,
    })
    got = budgets.scan(designs, GIF_BUDGET, SHOT_BUDGET)
    assert [e["file"].rsplit("/", 3)[-3] for e in got] == ["b", "a"]


def test_scan_ignores_non_preview_files(tmp_path):
    designs = _tree(tmp_path, {
        "a/previews/CAMERAS.md": 10,       # wrong extension
        "a/previews/.regen-stamp": 10,     # wrong extension
        "a/hero.png": 10,                  # not under previews/
    })
    assert budgets.scan(designs, GIF_BUDGET, SHOT_BUDGET) == []


def test_over_budget_goes_negative(tmp_path):
    # Negative headroom is the whole reading: readme-gate would fail this
    # file, and the record must say so rather than clamp at zero.
    designs = _tree(tmp_path, {"a/previews/fat.png": 600})
    got = budgets.scan(designs, GIF_BUDGET, SHOT_BUDGET)
    assert got[0]["headroom_pct"] == -20.0


def test_nonpositive_budget_refused(tmp_path):
    # Negative control: a zero budget means the sourcing of
    # preview-budget.sh silently failed — that must never scan "clean".
    designs = _tree(tmp_path, {"a/previews/x.gif": 1})
    with pytest.raises(ValueError):
        budgets.scan(designs, 0, SHOT_BUDGET)
