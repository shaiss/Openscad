"""lineage: which design derives from which, and what a change has to re-gate.

A derivative reuses another design's geometry and replaces part of it —
`include <../parent/parent.scad>`, then redefine a module, and the parent's
own call sites route to the override. OpenSCAD reports nothing about any of
that: not that a design is a derivative, not that an override missed, not that
two parents both defined the module and the last include won, not that a
shared ancestor got evaluated twice.

This package reads the lineage record (designs/<name>/derives.conf), resolves
the graph it describes, validates it against the entry .scad's include lines,
and answers the questions CI and the render gate ask of it. It never renders:
the two claims that need geometry — that an override took, and that a base is
safe at the confluence of a diamond — are proved in scripts/gate.sh.
"""

from .checks import Problem, check, summary
from .conf import KEYS, DerivesConf, split_replaces
from .graph import Design, Lineage

__all__ = ["Problem", "check", "summary", "KEYS", "DerivesConf",
           "split_replaces", "Design", "Lineage"]
__version__ = "0.1.0"
