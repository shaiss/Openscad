import json

import pytest

from telemetry import report


def _record(**overrides):
    rec = {
        "schema": 1,
        "kind": "gate-run",
        "utc": "2026-08-08T00:00:00Z",
        "meta": {"event": "push", "designs": "ALL"},
        "gate": {
            "parts": [
                {"stl": "build/a.stl", "score": 97, "verdict": "ok",
                 "criticals": 0, "warnings": 1, "slice_failed": False,
                 "print_time": "1h", "filament_g": "9.9"},
            ],
            "pre_fails": [],
            "derivatives": [],
            "design_seconds": {"a": 12},
            "archived_skips": ["frozen-thing"],
            "fail_lines": 0,
            "ok": True,
        },
        "budgets": [
            {"file": "designs/a/previews/x.gif", "bytes": 900,
             "budget": 1000, "headroom_pct": 10.0},
        ],
    }
    rec.update(overrides)
    return rec


def test_parse_log_roundtrip():
    text = json.dumps(_record()) + "\n" + json.dumps(_record()) + "\n"
    assert len(report.parse_log(text)) == 2


def test_parse_log_refuses_malformed_json():
    # Negative control: a corrupt committed log must fail loudly, not render
    # a report that quietly skipped history.
    with pytest.raises(ValueError, match="line 2"):
        report.parse_log(json.dumps(_record()) + "\n{not json\n")


def test_parse_log_refuses_non_record():
    with pytest.raises(ValueError, match="line 1"):
        report.parse_log('{"just": "some json"}\n')


def test_empty_log_renders_placeholder():
    out = report.render([])
    assert "No gate runs recorded yet" in out
    assert "GENERATED" in out


def test_render_carries_the_facts():
    out = report.render([_record()])
    assert "| 2026-08-08T00:00:00Z | push | ALL (1 archived skipped) | 1 | ✅ pass | 12s |" in out
    assert "`build/a.stl`" in out and "97/100" in out
    assert "1 warning" in out
    assert "`designs/a/previews/x.gif`" in out and "10.0% ⚠️" in out


def test_render_flags_failed_run_and_unscored_part():
    rec = _record()
    rec["gate"]["ok"] = False
    rec["gate"]["fail_lines"] = 2
    rec["gate"]["parts"][0]["score"] = None
    out = report.render([rec])
    assert "❌ 2 FAIL line(s)" in out
    assert "no report ❌" in out


def test_render_is_deterministic():
    recs = [_record(), _record(utc="2026-08-09T00:00:00Z")]
    assert report.render(recs) == report.render(recs)


def test_run_table_is_bounded():
    recs = [_record(utc=f"2026-08-{d:02d}T00:00:00Z") for d in range(1, 8)]
    old = report.MAX_RUN_ROWS
    report.MAX_RUN_ROWS = 5
    try:
        out = report.render(recs)
    finally:
        report.MAX_RUN_ROWS = old
    assert "Latest 5 of 7 recorded runs" in out
    assert "2026-08-01" not in out
    assert "2026-08-07" in out


def test_pipes_are_escaped():
    rec = _record()
    rec["gate"]["parts"][0]["stl"] = "build/a|b.stl"
    out = report.render([rec])
    assert "a\\|b" in out
