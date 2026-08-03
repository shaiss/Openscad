"""Read the `include`/`use` targets out of a .scad file.

A derivative works because `include <../parent/parent.scad>` pulls the parent's
source in and later definitions win, so the parent's own call sites route to
the override. That makes the include lines — their presence and their order —
load-bearing, and makes them the one place the declared lineage can be checked
against what OpenSCAD will actually read.

Text scanning is enough here and a parser would not be better: what matters is
which files the entry point pulls in and in what order, which is exactly what
these lines say.
"""

from __future__ import annotations

import re
from pathlib import Path

# `include <x>` / `use <x>`, wherever on the line it starts. OpenSCAD needs no
# terminating semicolon and tolerates space before the bracket.
_TARGET_RE = re.compile(r"\b(include|use)\s*<([^>]*)>")

_BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)
_LINE_COMMENT_RE = re.compile(r"//[^\n]*")


def strip_comments(text: str) -> str:
    """Blank out comments so a commented-out include is not read as one.

    Designs really do keep an old `// include <../base/base.scad>` around
    while a derivation is being reworked, and counting it would report drift
    against a line OpenSCAD never executes — the opposite of this tool's job.
    """
    text = _BLOCK_COMMENT_RE.sub(" ", text)
    return _LINE_COMMENT_RE.sub("", text)


def targets(path: Path, keyword: str = "include") -> list[str]:
    """Every `<...>` target of `keyword` in `path`, in file order."""
    text = strip_comments(Path(path).read_text())
    return [target.strip() for kw, target in _TARGET_RE.findall(text)
            if kw == keyword]


def resolve(target: str, design_dir: Path, root: Path) -> Path | None:
    """Resolve an include target to a path, the way OpenSCAD would.

    Relative to the including file first (OpenSCAD's own rule), then relative
    to the repo root, which is on OPENSCADPATH for every script in this repo
    (`OPENSCADPATH="$PWD/lib:$PWD"`) and so makes
    `include <designs/base/base.scad>` resolve too. Returns None when neither
    exists — an unresolvable include is a broken design, not a lineage edge,
    and render.sh/check.sh are where that gets caught.
    """
    if not target:
        return None
    for base in (design_dir, root):
        candidate = (Path(base) / target).resolve()
        if candidate.is_file():
            return candidate
    return None
