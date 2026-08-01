"""Command-line interface: printcheck MODEL.stl [options]."""

from __future__ import annotations

import argparse
import sys

from .analyzer import analyze
from .checks import Config


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="printcheck",
        description="Analyze an STL (or OBJ/3MF/PLY) for FDM printability.",
    )
    p.add_argument("model", nargs="+", help="mesh file(s) to analyze")
    p.add_argument("--json", action="store_true",
                   help="emit the report as JSON instead of text")
    p.add_argument("--nozzle", type=float, default=0.4,
                   help="nozzle diameter in mm (default 0.4)")
    p.add_argument("--layer-height", type=float, default=0.2,
                   help="layer height in mm (default 0.2)")
    p.add_argument("--min-wall", type=float, default=None,
                   help="minimum wall thickness in mm (default 2× nozzle)")
    p.add_argument("--overhang-angle", type=float, default=45.0,
                   help="support threshold in degrees from vertical (default 45)")
    p.add_argument("--build-volume", type=str, default="250x210x220",
                   help="printer build volume as XxYxZ in mm")
    p.add_argument("--no-orientation", action="store_true",
                   help="skip the orientation suggestion pass")
    p.add_argument("--ai", action="store_true",
                   help="append an AI-written summary of the heuristic "
                        "findings (needs ANTHROPIC_API_KEY)")
    p.add_argument("--fail-under", type=int, default=None, metavar="SCORE",
                   help="exit non-zero if the score is below SCORE "
                        "(for CI pipelines)")
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        bv = tuple(float(x) for x in args.build_volume.lower().split("x"))
        assert len(bv) == 3
    except (ValueError, AssertionError):
        print(f"error: bad --build-volume {args.build_volume!r}, "
              "expected e.g. 250x210x220", file=sys.stderr)
        return 2

    cfg = Config(
        nozzle_mm=args.nozzle,
        layer_height_mm=args.layer_height,
        min_wall_mm=args.min_wall if args.min_wall else args.nozzle * 2,
        overhang_deg=args.overhang_angle,
        build_volume_mm=bv,
    )

    worst_exit = 0
    for path in args.model:
        try:
            report = analyze(path, cfg, orientation=not args.no_orientation)
        except Exception as e:
            print(f"error: {path}: {e}", file=sys.stderr)
            worst_exit = max(worst_exit, 2)
            continue

        if args.ai:
            from .ai import summarize
            try:
                report.ai_summary = summarize(report)
            except RuntimeError as e:
                print(f"warning: AI summary skipped: {e}", file=sys.stderr)

        print(report.to_json() if args.json else report.to_text())
        if len(args.model) > 1 and not args.json:
            print()

        if args.fail_under is not None and report.score < args.fail_under:
            worst_exit = max(worst_exit, 1)
        elif report.verdict == "NOT PRINTABLE AS-IS":
            worst_exit = max(worst_exit, 1)
    return worst_exit


if __name__ == "__main__":
    raise SystemExit(main())
