"""Detectors: does a candidate gate APPLY to a PR?

Each detector is a pure function of the changed-file list and the repo tree. It
answers "did this PR introduce the thing gate <id> exists to cover?" — nothing
about whether the gate is approved (that is the registry's job). A detector may
read files under the tree but performs no other I/O, so the tests drive them
with a fixture tree and a synthetic file list.

A gate id with no detector registered here APPLIES to every PR: a gate that
declares no trigger is one you always want to consider. So adding a gate to the
registry is enough to surface it; adding a detector only narrows when it shows.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Applicability:
    applies: bool
    why: str


# Top-level names that are covered without appearing as a classifier case
# pattern, or that never need one (docs, license, git plumbing). Everything
# else must be reachable in ci.yml or classifier-coverage fires.
_ALWAYS_OK_TOP = {
    ".git",
    ".github",  # its own files are classified by path *inside* it
    ".gitignore",
    "build",  # gitignored generated output
}


def _top_dirs(changed: list[str]) -> list[str]:
    """First path segment of every changed path that lives inside a directory,
    de-duplicated, order preserved."""
    seen: dict[str, None] = {}
    for f in changed:
        f = f.strip()
        if not f or "/" not in f:
            continue  # a loose top-level file (README.md, LICENSE) — not a dir
        top = f.split("/", 1)[0]
        seen.setdefault(top, None)
    return list(seen)


def detect_classifier_coverage(changed: list[str], root: Path) -> Applicability:
    """Fire when a changed file lives under a top-level directory the `changes`
    classifier in ci.yml does not mention.

    This is the CAUTION at the top of ci.yml made into a check: a top-level
    directory with no classifier case arm makes every PR that touches only it
    permanently unmergeable, and today nothing catches it until a PR wedges.
    Coverage is judged the same way docs-check judges its directory census — a
    literal `<dir>/` somewhere in the workflow — because that is exactly the
    token a real case arm (`lib/*`, `scripts/*`, `designs/*/`) carries.
    """
    ci = root / ".github" / "workflows" / "ci.yml"
    text = ci.read_text(encoding="utf-8") if ci.is_file() else ""
    uncovered = [
        d
        for d in _top_dirs(changed)
        if d not in _ALWAYS_OK_TOP and f"{d}/" not in text
    ]
    if uncovered:
        joined = ", ".join(sorted(uncovered))
        return Applicability(
            True,
            f"top-level {joined} is not referenced in ci.yml's `changes` "
            f"classifier — a PR touching only it cannot satisfy the required "
            f"geometry contexts and can never merge (see the CAUTION in ci.yml)",
        )
    return Applicability(False, "")


def _any_match(changed: list[str], *, prefix: str = "", suffix: str = "") -> list[str]:
    return [
        f for f in (c.strip() for c in changed)
        if f and f.startswith(prefix) and f.endswith(suffix)
    ]


# The directories the shellcheck gate actually lints. The detector fires only
# for scripts under these, so applicability matches execution — a .sh elsewhere
# does not advertise a gate that would not check it (and these are the same two
# trees the always-on lint job shellchecks).
_SHELLCHECK_DIRS = ("scripts/", ".claude/hooks/")


def detect_shellcheck(changed: list[str], root: Path) -> Applicability:
    """Fire when the PR adds or edits a shell script the gate lints."""
    hits = [
        f
        for f in (c.strip() for c in changed)
        if f.endswith(".sh") and f.startswith(_SHELLCHECK_DIRS)
    ]
    if hits:
        return Applicability(
            True, f"{len(hits)} shell script(s) changed: {', '.join(sorted(hits)[:5])}"
        )
    return Applicability(False, "")


def detect_actionlint(changed: list[str], root: Path) -> Applicability:
    """Fire when the PR adds or edits a GitHub Actions workflow."""
    hits = [
        f
        for f in (c.strip() for c in changed)
        if f.startswith(".github/workflows/") and f.endswith((".yml", ".yaml"))
    ]
    if hits:
        return Applicability(
            True, f"{len(hits)} workflow(s) changed: {', '.join(sorted(hits))}"
        )
    return Applicability(False, "")


DETECTORS = {
    "classifier-coverage": detect_classifier_coverage,
    "shellcheck": detect_shellcheck,
    "actionlint": detect_actionlint,
}


def applies(gate_id: str, changed: list[str], root: Path) -> Applicability:
    fn = DETECTORS.get(gate_id)
    if fn is None:
        return Applicability(True, "no detector registered — applies to every PR")
    return fn(changed, root)
