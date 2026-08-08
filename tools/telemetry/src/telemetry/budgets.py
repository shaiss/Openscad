"""Budget headroom: committed preview bytes vs. the shared size budgets.

The budgets themselves are NOT defined here — scripts/preview-budget.sh is
the single source both the renderers and readme-gate.sh read, and
scripts/telemetry.sh sources it and hands the two numbers in as flags, so
this module can never disagree with the gate about what "over budget" means.

The scan covers exactly what readme-gate budgets: committed GIFs (animations
and AI motion clips alike) against the GIF budget, and committed PNGs
(product shots and AI lifestyle stills) against the shot budget, all under
designs/<name>/previews/.
"""

from __future__ import annotations

from pathlib import Path


def scan(designs_dir: Path, gif_budget: int, shot_budget: int) -> list[dict]:
    """One entry per committed preview GIF/PNG, sorted by headroom ascending
    (nearest its cap first) then by path, so the record reads worst-first and
    is deterministic across filesystems."""
    if gif_budget <= 0 or shot_budget <= 0:
        raise ValueError("budgets must be positive byte counts")
    entries: list[dict] = []
    for path in sorted(designs_dir.glob("*/previews/*")):
        suffix = path.suffix.lower()
        if suffix == ".gif":
            budget = gif_budget
        elif suffix == ".png":
            budget = shot_budget
        else:
            continue
        size = path.stat().st_size
        entries.append(
            {
                "file": path.as_posix(),
                "bytes": size,
                "budget": budget,
                "headroom_pct": round((budget - size) * 100.0 / budget, 1),
            }
        )
    entries.sort(key=lambda e: (e["headroom_pct"], e["file"]))
    return entries
