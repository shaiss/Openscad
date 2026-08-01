"""Report data structures: findings, severities, and the scored report."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from enum import Enum


class Severity(str, Enum):
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"


# Score penalty applied per finding, by severity.
_PENALTY = {Severity.INFO: 0, Severity.WARNING: 8, Severity.CRITICAL: 25}


@dataclass
class Finding:
    check: str
    severity: Severity
    title: str
    detail: str
    # Machine-readable measurements backing the finding (areas, counts, mm).
    metrics: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "check": self.check,
            "severity": self.severity.value,
            "title": self.title,
            "detail": self.detail,
            "metrics": self.metrics,
        }


@dataclass
class Report:
    source: str
    mesh_summary: dict
    findings: list[Finding] = field(default_factory=list)
    orientation_hint: dict | None = None
    ai_summary: str | None = None

    @property
    def score(self) -> int:
        """Printability score 0-100. 100 = no warnings or criticals."""
        penalty = sum(_PENALTY[f.severity] for f in self.findings)
        return max(0, 100 - penalty)

    @property
    def verdict(self) -> str:
        if any(f.severity is Severity.CRITICAL for f in self.findings):
            return "NOT PRINTABLE AS-IS"
        if any(f.severity is Severity.WARNING for f in self.findings):
            return "PRINTABLE WITH CAVEATS"
        return "PRINTABLE"

    def to_dict(self) -> dict:
        return {
            "source": self.source,
            "score": self.score,
            "verdict": self.verdict,
            "mesh": self.mesh_summary,
            "findings": [f.to_dict() for f in self.findings],
            "orientation_hint": self.orientation_hint,
            "ai_summary": self.ai_summary,
        }

    def to_json(self, indent: int = 2) -> str:
        return json.dumps(self.to_dict(), indent=indent)

    def to_text(self) -> str:
        icon = {
            Severity.INFO: "·",
            Severity.WARNING: "⚠",
            Severity.CRITICAL: "✗",
        }
        m = self.mesh_summary
        lines = [
            f"printcheck report — {self.source}",
            "=" * 60,
            f"  size:      {m['extents_mm'][0]:.1f} × {m['extents_mm'][1]:.1f} "
            f"× {m['extents_mm'][2]:.1f} mm",
            f"  triangles: {m['faces']:,}   bodies: {m['bodies']}   "
            f"watertight: {m['watertight']}",
            "",
            f"  SCORE: {self.score}/100 — {self.verdict}",
            "",
        ]
        for sev in (Severity.CRITICAL, Severity.WARNING, Severity.INFO):
            group = [f for f in self.findings if f.severity is sev]
            for f in group:
                lines.append(f"  {icon[sev]} [{sev.value.upper():8s}] {f.title}")
                lines.append(f"      {f.detail}")
        if not self.findings:
            lines.append("  No issues found.")
        if self.orientation_hint:
            oh = self.orientation_hint
            lines += [
                "",
                f"  Orientation: {oh['message']}",
            ]
        if self.ai_summary:
            lines += ["", "AI summary", "-" * 60, self.ai_summary]
        return "\n".join(lines)
