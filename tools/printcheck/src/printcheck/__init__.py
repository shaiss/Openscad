"""printcheck: STL printability analysis for FDM 3D printing.

Loads a mesh, runs a battery of geometric heuristics (mesh integrity,
overhangs, thin walls, bed adhesion/stability, fine detail, build volume),
and produces a scored report. Optionally layers an AI-written summary on
top of the heuristic findings — the heuristics are always the source of
truth.
"""

from .analyzer import analyze
from .report import Finding, Report, Severity

__all__ = ["analyze", "Finding", "Report", "Severity"]
__version__ = "0.1.0"
