"""Command-line interface: stylelift measure | lift | check | sync."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from .emit import lift, sync
from .measure import Config, measure
from .report import conformance_text, measurement_text
from .spec import Status, StyleSpec, conform, verdict


def build_parser() -> argparse.ArgumentParser:
    """Build the stylelift argument parser."""
    p = argparse.ArgumentParser(
        prog="stylelift",
        description="Translate a reference mesh into a reusable design-style "
                    "spec, and check new parts against it.")
    sub = p.add_subparsers(dest="command", required=True)

    m = sub.add_parser("measure", help="report the style-bearing geometry of a mesh")
    m.add_argument("model", nargs="+", help="mesh file(s) to measure")
    m.add_argument("--json", action="store_true", help="emit JSON instead of text")

    li = sub.add_parser("lift", help="write a style pack from reference mesh(es)")
    li.add_argument("reference", nargs="+", help="reference mesh file(s)")
    li.add_argument("--name", required=True, help="style name (kebab-case)")
    li.add_argument("--out", default=None,
                    help="output directory (default styles/<name>)")
    li.add_argument("--title", default="", help="human-readable style title")
    li.add_argument("--summary", default="", help="one-line description")
    li.add_argument("--source", default="",
                    help="where the reference came from (URL, or the command "
                         "that rendered it) — recorded in provenance")
    li.add_argument("--license", default="", dest="license_note",
                    help="the reference's licence, if it is someone else's work")
    li.add_argument("--force", action="store_true",
                    help="overwrite an existing style.json and STYLE.md")

    c = sub.add_parser("check", help="check a mesh against a style spec")
    c.add_argument("model", nargs="+", help="mesh file(s) to check")
    c.add_argument("--style", required=True,
                   help="style directory or style.json to check against")
    c.add_argument("--json", action="store_true", help="emit JSON instead of text")
    c.add_argument("--advisory-only", action="store_true",
                   help="report violations but always exit 0")

    s = sub.add_parser("sync", help="regenerate style.scad from style.json")
    s.add_argument("style", nargs="+", help="style directory")
    s.add_argument("--check", action="store_true",
                   help="verify instead of writing; exit 1 if stale")
    return p


def _style_path(value: str) -> Path:
    """Accept either a style directory or a style.json path."""
    path = Path(value)
    return path / "style.json" if path.is_dir() else path


def cmd_measure(args) -> int:
    """Measure meshes and print (or dump) the style report."""
    cfg = Config()
    reports = [measure(model, cfg) for model in args.model]
    if args.json:
        print(json.dumps(reports if len(reports) > 1 else reports[0], indent=2))
    else:
        for report in reports:
            print(measurement_text(report))
            print()
    return 0


def cmd_lift(args) -> int:
    """Write a style pack from one or more reference meshes."""
    out = args.out or f"styles/{args.name}"
    result = lift(args.reference, args.name, out, title=args.title,
                  summary=args.summary, force=args.force, source=args.source,
                  license_note=args.license_note)
    print(f"lifted style '{args.name}' from "
          f"{', '.join(Path(r).name for r in args.reference)}")
    for f in result["written"]:
        print(f"  wrote {out}/{f}")
    spec = result["spec"]
    print(f"  {len(spec.tokens)} tokens, {len(spec.rules)} rules")
    print("\nNext: write the prose in STYLE.md, tune the rules in style.json, "
          "then add a swatch.scad and check it:")
    print(f"  ./scripts/style-check.sh {args.name}")
    return 0


def cmd_check(args) -> int:
    """Check meshes against a style spec.

    Exit 1 when a part breaks a required rule *or* when the style could not
    judge it at all: a part that shares none of the family's features has not
    passed, and a gate that says otherwise would wave through anything
    sufficiently unlike the reference.
    """
    spec = StyleSpec.load(_style_path(args.style))
    failed = False
    payload = []
    for model in args.model:
        results = conform(measure(model), spec)
        if (any(r.status is Status.FAIL for r in results)
                or verdict(results).startswith("NOT COMPARABLE")):
            failed = True
        if args.json:
            payload.append({"model": model, "style": spec.name,
                            "verdict": verdict(results),
                            "results": [r.to_dict() for r in results]})
        else:
            print(conformance_text(model, spec, results))
            print()
    if args.json:
        print(json.dumps(payload if len(payload) > 1 else payload[0], indent=2))
    return 1 if (failed and not args.advisory_only) else 0


def cmd_sync(args) -> int:
    """Regenerate (or verify) each style's generated style.scad."""
    rc = 0
    for style in args.style:
        ok, message = sync(style, check=args.check)
        print(message)
        if not ok:
            rc = 1
    return rc


def main(argv: list[str] | None = None) -> int:
    """Entry point: dispatch to the subcommand and map errors to exit codes."""
    args = build_parser().parse_args(argv)
    handler = {"measure": cmd_measure, "lift": cmd_lift, "check": cmd_check,
               "sync": cmd_sync}[args.command]
    try:
        return handler(args)
    except (FileNotFoundError, FileExistsError, ValueError) as exc:
        print(f"stylelift: {exc}", file=sys.stderr)
        return 2
    except BrokenPipeError:
        # `stylelift measure x | head` closes the pipe early. Point stdout at
        # devnull so the interpreter's final flush cannot raise again and
        # print a traceback over the user's terminal.
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        return 141                      # 128 + SIGPIPE, as a shell reports it


if __name__ == "__main__":
    sys.exit(main())
