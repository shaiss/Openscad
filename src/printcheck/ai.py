"""Optional AI layer: turn the heuristic findings into a plain-English
assessment with concrete fix suggestions.

This never decides printability — the geometric checks do. It only
explains and prioritizes what they found. Requires `pip install
printcheck[ai]` and an ANTHROPIC_API_KEY in the environment.
"""

from __future__ import annotations

import os

from .report import Report

_PROMPT = """You are reviewing the JSON output of a 3D-print printability
checker that ran geometric heuristics on an STL. Write a short assessment
for the person about to print it:

1. Lead with the single most important problem (or say it's good to go).
2. For each warning/critical finding, give one concrete fix (tool or
   slicer setting), in priority order.
3. Do not invent problems not present in the findings; do not soften
   critical findings.

Keep it under 200 words, plain prose.

Report JSON:
{json}
"""


def summarize(report: Report, model: str = "claude-sonnet-5") -> str:
    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise RuntimeError(
            "ANTHROPIC_API_KEY is not set; run without --ai or export a key.")
    try:
        import anthropic
    except ImportError as e:
        raise RuntimeError(
            "AI summary needs the 'anthropic' package: "
            "pip install 'printcheck[ai]'") from e

    client = anthropic.Anthropic()
    msg = client.messages.create(
        model=model,
        max_tokens=600,
        messages=[{
            "role": "user",
            "content": _PROMPT.format(json=report.to_json()),
        }],
    )
    return "".join(b.text for b in msg.content if b.type == "text").strip()
