"""backlog-burn: pick one unclaimed, autonomy-eligible issue for a scheduled
unattended /ship-issue run.

The policy lives in :mod:`backlog_burn.select` (pure, tested); the live
GitHub read lives in :mod:`backlog_burn.github` (thin I/O, stdlib only).
"""

from .select import DEFAULT_REQUIRED_LABEL, render_summary, select_issue

__all__ = ["select_issue", "render_summary", "DEFAULT_REQUIRED_LABEL"]
