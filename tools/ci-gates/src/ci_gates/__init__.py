"""Smart CI gate selection.

The `changes` classifier in ci.yml chooses which of the *existing* gates run
for a PR. This package is the layer on top: it looks at a PR's changed files,
proposes candidate gates that ought to cover what the PR introduced, runs the
ones already approved, and reports the rest so a human can cross them.

Two ideas, kept separate on purpose:

  detectors  decide whether a candidate gate APPLIES to a PR (does the diff
             introduce the thing this gate exists to cover?). Pure functions of
             the changed-file list and the tree — no I/O beyond reading files.

  registry   records the DECISION about each candidate (on / proposed / off)
             plus its tier. It is a committed file — the reproducible source of
             truth — read every run and written only by an explicit /ci-gate
             command.

`select()` joins the two into the buckets the smart-ci job and the PR comment
consume.
"""

from .registry import Gate, Registry, default_state
from .select import Selection, Selected, select

__all__ = [
    "Gate",
    "Registry",
    "Selected",
    "Selection",
    "default_state",
    "select",
]
