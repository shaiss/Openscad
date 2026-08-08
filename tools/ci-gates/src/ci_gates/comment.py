"""Render the sticky PR comment for a Selection.

The comment is the human face of the feature: it says which gates ran (and
whether they were auto-selected), and it lists the proposed gates with the one
command each takes to cross — "how to selectively cross the remaining." It
carries a marker so the workflow can upsert it in place, exactly like
render-gate's printcheck comment.

Kept free of run RESULTS on purpose: this module renders the selection, which
the smart-ci job knows before it runs anything. Pass/fail lands on the job's
own check, not in this comment, so a re-post never races the gate execution.
"""

from __future__ import annotations

from .select import Selection

MARKER = "<!-- smart-ci-gate-selection -->"


def render(sel: Selection, *, sha: str = "", registry_path: str = ".github/ci-gates/registry.conf") -> str:
    lines: list[str] = [MARKER, "### 🚦 Smart CI — gate selection", ""]

    active = sel.active
    if active:
        lines.append("**Active on this PR**")
        lines.append("")
        lines.append("| gate | tier | selected by |")
        lines.append("| --- | --- | --- |")
        for s in active:
            how = "auto (advisory)" if s.auto else "approved (gating)"
            lines.append(f"| `{s.id}` | {s.gate.tier} | {how} |")
        lines.append("")
        lines.append(
            "<sub>Advisory gates auto-run and never block; gating gates block "
            "on failure.</sub>"
        )
        lines.append("")
    else:
        lines.append("_No gates are active for this PR's changes._")
        lines.append("")

    if sel.proposed:
        lines.append(
            "**Proposed** — new checks this PR's changes call for, not yet "
            "enabled. Cross the ones you want; the rest are ignored."
        )
        lines.append("")
        for s in sel.proposed:
            cross = s.gate.cross or f"/ci-gate approve {s.id}"
            lines.append(f"- **`{s.id}`** — {s.gate.title}")
            lines.append(f"  <br><sub>{s.why}</sub>")
            lines.append(f"  <br>Cross it: `{cross}`")
        lines.append("")
        lines.append(
            "<sub>A maintainer with write access runs the command; it flips the "
            "gate to `on` in the registry and commits it to this branch, so "
            "every future run enforces it. Turn one off with "
            "`/ci-gate decline <id>`.</sub>"
        )
        lines.append("")

    if sel.declined:
        ids = ", ".join(f"`{s.id}`" for s in sel.declined)
        lines.append(
            f"<sub>Declined (off): {ids} — re-enable with "
            f"`/ci-gate approve <id>`.</sub>"
        )
        lines.append("")

    footer = f"<sub>Source of truth: `{registry_path}`"
    if sha:
        footer += f" · selection for {sha}"
    footer += ".</sub>"
    lines.append(footer)

    return "\n".join(lines).rstrip() + "\n"
