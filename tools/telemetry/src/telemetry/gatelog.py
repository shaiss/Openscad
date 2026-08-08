"""Parse a gate.sh log into structured facts.

The line shapes matched here are the same ones scripts/gate-summary.py reads
for the sticky PR comment — gate.sh documents them as a machine-read contract
("keep the '<status>  derivative ...' shape"). The two parsers are kept
deliberately independent: gate-summary renders a human report for one run and
must stay a single-file script, while this one feeds the committed telemetry
log. The tests in tests/test_gatelog.py pin every shape, so a gate.sh
rewording breaks a test here instead of silently dropping a field from the
log.

Two shapes are telemetry-only (gate-summary ignores them by construction —
its regexes cannot match them):

    time  <name>: gated in <N>s     per-design gate wall time
    skip <name>: archived at ...    a design the full-catalog run skipped
"""

from __future__ import annotations

import re

_RE_PRINTCHECK = re.compile(r"== .*: printcheck (\S+) ==")
_RE_DERIV = re.compile(
    r"(ok|FAIL)\s+derivative (\S+): "
    r"(override|base-safe|derives\.conf)(?: (\S+))? — (.+)$"
)
_RE_PRE_FAIL = re.compile(r"FAIL\s+(.+: (?:render failed|\S+ not found))$")
_RE_SCORE = re.compile(r"SCORE: (\d+)/100 — (.+)")
_RE_TIME = re.compile(r"estimated printing time \(normal mode\) = (.+)")
_RE_GRAMS = re.compile(r"total filament used \[g\] = (.+)")
_RE_SLICE_FAIL = re.compile(r"FAIL\s+\S+: slicing failed")
_RE_GATE_TIME = re.compile(r"^time\s+(\S+): gated in (\d+)s$")
_RE_SKIP = re.compile(r"^skip (\S+): archived at (\S+)")


def parse(text: str) -> dict:
    """Parse a gate.sh log (possibly partial) into a dict of facts.

    Never raises on content: a crashed gate run still yields whatever
    completed, same as gate-summary.py. `fail_lines` counts every line
    starting with FAIL — gate.sh sets its exit code from exactly those, so
    `ok` (zero of them) mirrors the gate verdict without needing the exit
    code smuggled in from outside.
    """
    parts: list[dict] = []
    pre_fails: list[str] = []
    derivatives: list[dict] = []
    design_seconds: dict[str, int] = {}
    archived_skips: list[str] = []
    fail_lines = 0
    cur: dict | None = None
    for line in text.splitlines():
        if line.startswith("FAIL"):
            fail_lines += 1
        m = _RE_PRINTCHECK.match(line)
        if m:
            cur = {
                "stl": m.group(1),
                "score": None,
                "verdict": None,
                "criticals": 0,
                "warnings": 0,
                "slice_failed": False,
                "print_time": None,
                "filament_g": None,
            }
            parts.append(cur)
            continue
        m = _RE_DERIV.match(line)
        if m:
            status, design, kind, subject, detail = m.groups()
            derivatives.append(
                {
                    "ok": status == "ok",
                    "design": design,
                    "kind": kind,
                    "subject": subject or "",
                    "detail": detail.strip(),
                }
            )
            continue
        m = _RE_GATE_TIME.match(line)
        if m:
            design_seconds[m.group(1)] = int(m.group(2))
            continue
        m = _RE_SKIP.match(line)
        if m:
            archived_skips.append(m.group(1))
            continue
        m = _RE_PRE_FAIL.match(line)
        if m:
            pre_fails.append(m.group(1))
            continue
        if cur is None:
            continue
        m = _RE_SCORE.search(line)
        if m:
            cur["score"] = int(m.group(1))
            cur["verdict"] = m.group(2).strip()
            continue
        if "[CRITICAL]" in line:
            cur["criticals"] += 1
            continue
        if "[WARNING" in line:
            cur["warnings"] += 1
            continue
        m = _RE_TIME.search(line)
        if m:
            cur["print_time"] = m.group(1).strip()
            continue
        m = _RE_GRAMS.search(line)
        if m:
            cur["filament_g"] = m.group(1).strip()
            continue
        if _RE_SLICE_FAIL.search(line):
            cur["slice_failed"] = True
    return {
        "parts": parts,
        "pre_fails": pre_fails,
        "derivatives": derivatives,
        "design_seconds": design_seconds,
        "archived_skips": archived_skips,
        "fail_lines": fail_lines,
        "ok": fail_lines == 0,
    }
