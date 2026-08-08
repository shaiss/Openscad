"""Policy tests for the backlog-burn selector.

Each guard is proved two ways: an issue that trips it is excluded, and the
*same* issue with the disqualifier removed is selected. That pairing is the
negative control — delete the guard from ``select.py`` and the "excluded"
half of the pair fails, so a weakened policy cannot pass silently (the
``lib/*-guards.conf`` discipline, applied to Python).
"""

from __future__ import annotations

import copy

import pytest

from backlog_burn.select import render_summary, select_issue

LABEL = "autonomy-ok"


def issue(number, created, *, labels=(LABEL,), locks=()):
    return {
        "number": number,
        "title": f"issue {number}",
        "createdAt": created,
        "labels": list(labels),
        "shipLockComments": list(locks),
    }


def snap(issues, *, open_prs=(), branches=()):
    return {
        "issues": list(issues),
        "openPRs": list(open_prs),
        "branches": list(branches),
    }


# --------------------------------------------------------------------------
# Ordering + the hard cap
# --------------------------------------------------------------------------

def test_selects_oldest_eligible():
    s = snap([
        issue(10, "2026-08-07T23:00:00Z"),
        issue(11, "2026-08-06T23:00:00Z"),  # older
        issue(12, "2026-08-08T23:00:00Z"),
    ])
    r = select_issue(s)
    assert r["selected"] == 11


def test_hard_cap_one_per_firing():
    # Five eligible issues; exactly one is selected, the rest deferred.
    s = snap([issue(n, f"2026-08-0{n}T00:00:00Z") for n in range(1, 6)])
    r = select_issue(s)
    assert r["selected"] == 1
    assert r["eligible_count"] == 5
    assert r["deferred"] == [2, 3, 4, 5]


def test_deterministic_tie_break_by_number():
    s = snap([
        issue(20, "2026-08-07T00:00:00Z"),
        issue(19, "2026-08-07T00:00:00Z"),  # same timestamp, lower number wins
    ])
    assert select_issue(s)["selected"] == 19


def test_nothing_eligible_returns_none():
    s = snap([issue(3, "2026-08-01T00:00:00Z", labels=["enhancement"])])
    r = select_issue(s)
    assert r["selected"] is None
    assert r["considered"] == 1


# --------------------------------------------------------------------------
# Guard: the autonomy-ok opt-in label
# --------------------------------------------------------------------------

def test_requires_optin_label():
    without = issue(30, "2026-08-01T00:00:00Z", labels=["enhancement"])
    # Excluded without the label...
    assert select_issue(snap([without]))["selected"] is None
    # ...and selected once it carries it (negative control).
    withlabel = copy.deepcopy(without)
    withlabel["labels"].append(LABEL)
    assert select_issue(snap([withlabel]))["selected"] == 30


def test_custom_label():
    s = snap([issue(31, "2026-08-01T00:00:00Z", labels=["ship-me"])])
    assert select_issue(s, required_label="ship-me")["selected"] == 31


# --------------------------------------------------------------------------
# Guard: an active SHIP-LOCK claim (and a WITHDRAWN one must release it)
# --------------------------------------------------------------------------

def test_active_ship_lock_excludes():
    locked = issue(40, "2026-08-01T00:00:00Z", locks=[
        {"body": "🚢 SHIP-LOCK — shipping this as one PR.", "createdAt": "2026-08-02T00:00:00Z"},
    ])
    assert select_issue(snap([locked]))["selected"] is None
    assert select_issue(snap([locked]))["excluded"]["40"].startswith("an active")


def test_withdrawn_lock_is_re_eligible():
    # Newest lock comment is a withdrawal -> the issue is claimable again.
    issue_ = issue(41, "2026-08-01T00:00:00Z", locks=[
        {"body": "🚢 SHIP-LOCK — shipping.", "createdAt": "2026-08-02T00:00:00Z"},
        {"body": "🚢 SHIP-LOCK WITHDRAWN — yielding.", "createdAt": "2026-08-03T00:00:00Z"},
    ])
    assert select_issue(snap([issue_]))["selected"] == 41


def test_latest_lock_wins_even_if_reclaimed():
    # withdrawn, then re-claimed by another run: newest is active -> excluded.
    issue_ = issue(42, "2026-08-01T00:00:00Z", locks=[
        {"body": "🚢 SHIP-LOCK — a.", "createdAt": "2026-08-02T00:00:00Z"},
        {"body": "🚢 SHIP-LOCK WITHDRAWN — a yields.", "createdAt": "2026-08-03T00:00:00Z"},
        {"body": "🚢 SHIP-LOCK — b.", "createdAt": "2026-08-04T00:00:00Z"},
    ])
    assert select_issue(snap([issue_]))["selected"] is None


def test_non_ship_lock_comment_does_not_lock():
    issue_ = issue(43, "2026-08-01T00:00:00Z", locks=[])
    issue_["shipLockComments"] = []
    # A comment that merely mentions ship-lock but isn't the marker line.
    issue_["shipLockComments"] = [
        {"body": "discussion about 🚢 SHIP-LOCK semantics", "createdAt": "2026-08-02T00:00:00Z"},
    ]
    # First line does not START with the marker -> not a claim.
    assert select_issue(snap([issue_]))["selected"] == 43


# --------------------------------------------------------------------------
# Guard: an open PR already closes the issue
# --------------------------------------------------------------------------

@pytest.mark.parametrize("body", [
    "Closes #50",
    "closes #50",
    "This fixes #50 in full",
    "Resolved: #50",
    "resolve #50",
    "fixed #50",
])
def test_open_pr_closing_keyword_excludes(body):
    s = snap([issue(50, "2026-08-01T00:00:00Z")],
             open_prs=[{"number": 200, "headRefName": "feature", "body": body}])
    assert select_issue(s)["selected"] is None


def test_open_pr_unrelated_does_not_exclude():
    # Negative control: a PR that closes a *different* issue leaves #50 free.
    s = snap([issue(50, "2026-08-01T00:00:00Z")],
             open_prs=[{"number": 200, "headRefName": "feature", "body": "Closes #51"}])
    assert select_issue(s)["selected"] == 50


def test_closing_keyword_does_not_match_number_prefix():
    # "#5" must not disqualify issue 50.
    s = snap([issue(50, "2026-08-01T00:00:00Z")],
             open_prs=[{"number": 200, "headRefName": "x", "body": "Closes #5"}])
    assert select_issue(s)["selected"] == 50


def test_open_pr_issue_branch_excludes():
    s = snap([issue(52, "2026-08-01T00:00:00Z")],
             open_prs=[{"number": 201, "headRefName": "claude/issue-52-foo", "body": "wip"}])
    assert select_issue(s)["selected"] is None


# --------------------------------------------------------------------------
# Guard: a claude/issue-<N>-* branch already exists
# --------------------------------------------------------------------------

def test_existing_issue_branch_excludes():
    excluded = select_issue(snap(
        [issue(60, "2026-08-01T00:00:00Z")],
        branches=["main", "claude/issue-60-wip"],
    ))
    assert excluded["selected"] is None
    # Negative control: without that branch the same issue is selected.
    assert select_issue(snap(
        [issue(60, "2026-08-01T00:00:00Z")],
        branches=["main", "claude/other-work"],
    ))["selected"] == 60


def test_issue_branch_prefix_is_boundary_safe():
    # A branch for issue 6 must not disqualify issue 60.
    s = snap([issue(60, "2026-08-01T00:00:00Z")], branches=["claude/issue-6-thing"])
    assert select_issue(s)["selected"] == 60


# --------------------------------------------------------------------------
# The outcome record (AC4)
# --------------------------------------------------------------------------

def test_record_reports_reasons():
    s = snap(
        [
            issue(70, "2026-08-01T00:00:00Z", labels=["enhancement"]),  # no label
            issue(71, "2026-08-02T00:00:00Z"),                          # eligible
        ],
        branches=[],
    )
    r = select_issue(s)
    assert r["selected"] == 71
    assert "70" in r["excluded"]
    assert r["considered"] == 2


def test_render_summary_selected_and_empty():
    chosen = render_summary(select_issue(snap([issue(80, "2026-08-01T00:00:00Z")])))
    assert "#80" in chosen
    none = render_summary(select_issue(snap([issue(81, "2026-08-01T00:00:00Z", labels=[])])))
    assert "No issue selected" in none
