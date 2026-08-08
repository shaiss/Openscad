"""Join detectors and the registry into the buckets the smart-ci job runs and
the PR comment reports.

For every gate in the registry that APPLIES to the PR (its detector fired), its
`state` decides the bucket:

  active       state=on   -> run it this PR. advisory runs non-blocking; gating
                            blocks (a non-zero exit fails smart-ci).
  proposed     state=proposed -> a gating candidate awaiting a human. Surfaced
                            in the comment with the command to cross it. Does
                            NOT run.
  declined     state=off  -> neither run nor proposed; kept only so the report
                            can say it was deliberately turned off.

A gate whose detector did NOT fire is irrelevant to this PR and appears in none
of the buckets. `auto` marks the advisory actives, which are the ones that got
here with no human step — the "auto-approved" half of the feature.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

from .detectors import applies as detector_applies
from .registry import Gate, Registry


@dataclass(frozen=True)
class Selected:
    gate: Gate
    why: str  # what the detector matched, for the report

    @property
    def id(self) -> str:
        return self.gate.id

    @property
    def auto(self) -> bool:
        """True for an advisory active: it runs with no human approval."""
        return self.gate.advisory


@dataclass
class Selection:
    active: list[Selected] = field(default_factory=list)
    proposed: list[Selected] = field(default_factory=list)
    declined: list[Selected] = field(default_factory=list)

    def blocking(self) -> list[Selected]:
        """Active gates whose failure must fail the job (the gating ones)."""
        return [s for s in self.active if s.gate.gating]

    def advisory_actives(self) -> list[Selected]:
        return [s for s in self.active if s.gate.advisory]


def select(registry: Registry, changed: list[str], root: Path) -> Selection:
    sel = Selection()
    for gate in registry:
        ap = detector_applies(gate.id, changed, root)
        if not ap.applies:
            continue
        picked = Selected(gate=gate, why=ap.why)
        if gate.state == "on":
            sel.active.append(picked)
        elif gate.state == "proposed":
            sel.proposed.append(picked)
        elif gate.state == "off":
            sel.declined.append(picked)
    return sel
