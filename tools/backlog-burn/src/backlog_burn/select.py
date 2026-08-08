"""Selection policy for the scheduled backlog burn.

Pure functions: given a *snapshot* of the repository's open issues — plus the
open PRs and remote branches that reveal which issues are already claimed —
decide the single issue an unattended ``/ship-issue`` run should take next,
or none.

Every exclusion here mirrors the ``/ship-issue`` skill's own §0 lock check:

* an active ``🚢 SHIP-LOCK`` marker comment (a ``WITHDRAWN`` one releases it),
* an open PR that *closes* the issue (any of GitHub's nine closing keywords,
  or a PR branch named ``claude/issue-<N>-*``),
* an existing remote ``claude/issue-<N>-*`` branch.

The skill re-verifies all of this before it touches a line of code, so this
module is a best-effort *pre-filter*. Its only jobs are to never hand the run
an issue that is plainly already taken, and — the hard cap — to never hand it
more than one. Keeping the policy pure (a function of the snapshot, with no
network) is what lets every guard below carry a negative-control test.
"""

from __future__ import annotations

import re
from typing import Any, Optional

# The label a human must add for an issue to be eligible for unattended
# shipping. Nothing is eligible until someone opts it in, so the routine is
# safe on the day it lands: it selects nothing until the backlog is curated.
DEFAULT_REQUIRED_LABEL = "autonomy-ok"

SHIP_LOCK_MARKER = "🚢 SHIP-LOCK"

# GitHub honours these nine keywords, case-insensitively, each optionally
# followed by a colon, to auto-close an issue from a PR body. Grepping only
# for "Closes #N" misses "Resolved: #38" — so match the full set, exactly as
# the /ship-issue skill's §0 note spells out.
_CLOSING_KEYWORDS = (
    "close", "closes", "closed",
    "fix", "fixes", "fixed",
    "resolve", "resolves", "resolved",
)


def _first_line(text: str) -> str:
    for line in (text or "").splitlines():
        stripped = line.strip()
        if stripped:
            return stripped
    return ""


def _ship_lock_active(comments: list[dict[str, Any]]) -> bool:
    """True when the *latest* SHIP-LOCK comment is an active claim.

    A claim is a state, not a flag (the skill's §0.3 rule): read the newest
    ``🚢 SHIP-LOCK`` comment and act on that one. ``🚢 SHIP-LOCK WITHDRAWN``
    releases the claim and must not block, which is why a withdrawal has to be
    able to *un*-exclude an issue here — not merely be ignored.
    """
    lock_comments = [
        c for c in (comments or [])
        if _first_line(c.get("body", "")).startswith(SHIP_LOCK_MARKER)
    ]
    if not lock_comments:
        return False
    # createdAt is ISO-8601 UTC ("2026-08-07T23:35:56Z"), which sorts
    # lexicographically in timestamp order — newest last.
    latest = max(lock_comments, key=lambda c: c.get("createdAt", ""))
    return "WITHDRAWN" not in _first_line(latest.get("body", "")).upper()


def _closes_issue(pr_body: str, number: int) -> bool:
    for kw in _CLOSING_KEYWORDS:
        # keyword, optional ':', whitespace, '#<number>', not glued to more
        # digits (so "#9" does not match issue 95).
        pattern = rf"(?i)\b{kw}:?\s+#{number}\b"
        if re.search(pattern, pr_body or ""):
            return True
    return False


def _issue_branch_re(number: int) -> re.Pattern[str]:
    return re.compile(rf"^claude/issue-{number}-")


def _has_issue_branch(branches: list[str], number: int) -> bool:
    rx = _issue_branch_re(number)
    return any(rx.match(b or "") for b in (branches or []))


def _open_pr_claims(open_prs: list[dict[str, Any]], number: int) -> bool:
    rx = _issue_branch_re(number)
    for pr in open_prs or []:
        if _closes_issue(pr.get("body", ""), number):
            return True
        if rx.match(pr.get("headRefName", "") or ""):
            return True
    return False


def exclusion_reason(
    issue: dict[str, Any],
    open_prs: list[dict[str, Any]],
    branches: list[str],
    required_label: str = DEFAULT_REQUIRED_LABEL,
) -> Optional[str]:
    """Why this issue is *not* eligible, or ``None`` if it is.

    Order matters only for the reported reason, never for correctness — an
    issue is eligible exactly when none of the four guards fire.
    """
    number = issue["number"]
    labels = issue.get("labels", []) or []
    if required_label not in labels:
        return f"not labelled {required_label!r}"
    if _ship_lock_active(issue.get("shipLockComments", [])):
        return "an active 🚢 SHIP-LOCK claim"
    if _open_pr_claims(open_prs, number):
        return f"an open PR already closes #{number}"
    if _has_issue_branch(branches, number):
        return f"a claude/issue-{number}-* branch already exists"
    return None


def select_issue(
    snapshot: dict[str, Any],
    required_label: str = DEFAULT_REQUIRED_LABEL,
) -> dict[str, Any]:
    """Pick at most one issue from a snapshot; return a structured record.

    The record is the outcome log the workflow surfaces (AC4): what was
    selected, how many were considered, and — for every issue that was not —
    the reason it was skipped, so a maintainer reading the run can see the
    routine's reasoning without re-deriving it.
    """
    issues = snapshot.get("issues", []) or []
    open_prs = snapshot.get("openPRs", []) or []
    branches = snapshot.get("branches", []) or []

    eligible: list[dict[str, Any]] = []
    excluded: dict[str, str] = {}
    for issue in issues:
        reason = exclusion_reason(issue, open_prs, branches, required_label)
        if reason is None:
            eligible.append(issue)
        else:
            excluded[str(issue["number"])] = reason

    # Oldest-first (the /ship-issue policy's default ordering), tie-broken by
    # issue number so the choice is deterministic across runs and machines.
    eligible.sort(key=lambda i: (i.get("createdAt", ""), i["number"]))

    # The hard cap: one issue per firing, so a bad night costs one PR, not
    # five. Everything past the first eligible issue is deferred to the next
    # firing, and reported as such.
    selected = eligible[0] if eligible else None
    deferred = [i["number"] for i in eligible[1:]]

    return {
        "selected": (selected["number"] if selected else None),
        "selected_title": (selected.get("title") if selected else None),
        "considered": len(issues),
        "eligible_count": len(eligible),
        "deferred": deferred,
        "excluded": excluded,
        "required_label": required_label,
    }


def render_summary(record: dict[str, Any]) -> str:
    """A short markdown block for the job summary / logs (AC4)."""
    lines = []
    if record["selected"] is not None:
        lines.append(
            f"**Selected #{record['selected']}** — "
            f"{record.get('selected_title') or ''}".rstrip(" —")
        )
    else:
        lines.append(
            f"**No issue selected** — nothing labelled "
            f"`{record['required_label']}` is currently unclaimed."
        )
    lines.append("")
    lines.append(
        f"- considered: {record['considered']} open issue(s); "
        f"eligible: {record['eligible_count']}"
    )
    if record["deferred"]:
        deferred = ", ".join(f"#{n}" for n in record["deferred"])
        lines.append(f"- deferred to a later firing (cap 1): {deferred}")
    if record["excluded"]:
        lines.append("- skipped:")
        for num, reason in sorted(record["excluded"].items(), key=lambda kv: int(kv[0])):
            lines.append(f"  - #{num}: {reason}")
    return "\n".join(lines)
