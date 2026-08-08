"""Pins the gate.sh line shapes the capture parser reads.

Every fixture line below is copied from a real gate.sh emission (or the
comment in gate.sh documenting the shape). If gate.sh rewords a line, the
matching test here fails — which is the point: the alternative is the field
silently dropping out of every future telemetry record.
"""

from telemetry import gatelog

GATE_LOG = """\
== calibration-cube: render ==
== calibration-cube: printcheck build/calibration-cube.stl ==
[WARNING] thin wall at layer 3
SCORE: 96/100 — printable with care
== test-slice build/calibration-cube.stl ==
      estimated printing time (normal mode) = 1h 2m 3s
      total filament used [g] = 12.34
time  calibration-cube: gated in 42s
== widget: render ==
FAIL  widget: render failed
== widget: printcheck build/widget-lid.stl ==
[CRITICAL] not watertight
SCORE: 40/100 — do not print
== test-slice build/widget-lid.stl ==
FAIL  build/widget-lid.stl: slicing failed
time  widget: gated in 7s
skip old-thing: archived at v0.1 — frozen, not gated in full-catalog runs
ok    derivative kid: override parent:lid — mesh differs from the parent (12 → 20 facets)
FAIL  derivative kid: base-safe grand — its default render emits 4 facets, so the diamond-ok claim is false
"""


def test_parts_scores_and_slice_facts():
    got = gatelog.parse(GATE_LOG)
    assert [p["stl"] for p in got["parts"]] == [
        "build/calibration-cube.stl",
        "build/widget-lid.stl",
    ]
    cube, lid = got["parts"]
    assert cube["score"] == 96
    assert cube["verdict"] == "printable with care"
    assert cube["warnings"] == 1
    assert cube["criticals"] == 0
    assert cube["print_time"] == "1h 2m 3s"
    assert cube["filament_g"] == "12.34"
    assert cube["slice_failed"] is False
    assert lid["score"] == 40
    assert lid["criticals"] == 1
    assert lid["slice_failed"] is True


def test_pre_fail_and_overall_verdict():
    got = gatelog.parse(GATE_LOG)
    assert got["pre_fails"] == ["widget: render failed"]
    # 3 FAIL lines: render failed, slicing failed, base-safe
    assert got["fail_lines"] == 3
    assert got["ok"] is False


def test_clean_log_is_ok():
    got = gatelog.parse("== a: printcheck build/a.stl ==\nSCORE: 100/100 — ship it\n")
    assert got["ok"] is True
    assert got["fail_lines"] == 0


def test_design_gate_seconds():
    got = gatelog.parse(GATE_LOG)
    assert got["design_seconds"] == {"calibration-cube": 42, "widget": 7}


def test_archived_skips():
    got = gatelog.parse(GATE_LOG)
    assert got["archived_skips"] == ["old-thing"]


def test_derivative_lines():
    got = gatelog.parse(GATE_LOG)
    assert got["derivatives"] == [
        {"ok": True, "design": "kid", "kind": "override", "subject": "parent:lid",
         "detail": "mesh differs from the parent (12 → 20 facets)"},
        {"ok": False, "design": "kid", "kind": "base-safe", "subject": "grand",
         "detail": "its default render emits 4 facets, so the diamond-ok claim is false"},
    ]


def test_part_without_score_stays_unscored():
    # printcheck died mid-part: the record must say so (score None), never
    # default to something a reader could mistake for a pass.
    got = gatelog.parse("== a: printcheck build/a.stl ==\n")
    assert got["parts"][0]["score"] is None


def test_empty_log_parses_to_nothing():
    got = gatelog.parse("")
    assert got["parts"] == []
    assert got["ok"] is True
