"""Command-line entry point for the scheduled backlog burn.

    backlog-burn select   # snapshot JSON on stdin -> selection record
    backlog-burn gather    # live GitHub read -> snapshot JSON
    backlog-burn run       # gather then select (what the workflow runs)

``select`` is the pure, tested core; ``gather`` is the thin live read; ``run``
composes them. Any command can write GitHub Actions outputs (``--gh-output``)
and a job-summary block (``--summary``) so the workflow stays a few lines of
glue with no policy of its own.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from typing import Any, Optional

from .select import DEFAULT_REQUIRED_LABEL, render_summary, select_issue


def _emit(record: dict[str, Any], args: argparse.Namespace) -> None:
    """Write the record to stdout and, when present, GitHub Actions outputs."""
    # The record itself, always, to stdout, so `run`/`select` are pipeable.
    json.dump(record, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")

    # GitHub Actions step outputs: `issue` is the empty string when nothing
    # was selected, which an `if: steps.x.outputs.issue != ''` gate reads
    # correctly as "skip the ship step".
    gh_output = args.gh_output or os.environ.get("GITHUB_OUTPUT")
    if gh_output:
        selected = record["selected"]
        with open(gh_output, "a", encoding="utf-8") as fh:
            fh.write(f"issue={selected if selected is not None else ''}\n")

    summary_path = args.summary or os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as fh:
            fh.write("## Backlog burn\n\n")
            fh.write(render_summary(record))
            fh.write("\n")


def _load_snapshot(path: Optional[str]) -> dict[str, Any]:
    """Load a snapshot from ``path`` (or stdin when ``path`` is None/``-``)."""
    if path and path != "-":
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    return json.load(sys.stdin)


def _token() -> str:
    """The GitHub token from ``GH_TOKEN``/``GITHUB_TOKEN`` (``""`` if unset)."""
    return os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN") or ""


def cmd_select(args: argparse.Namespace) -> int:
    """`select`: apply the policy to a snapshot read from stdin/file."""
    snapshot = _load_snapshot(args.input)
    record = select_issue(snapshot, required_label=args.label,
                          now=datetime.now(timezone.utc))
    _emit(record, args)
    return 0


def cmd_gather(args: argparse.Namespace) -> int:
    """`gather`: print the live snapshot for ``--repo`` as JSON."""
    from .github import gather_snapshot  # imported here so `select` needs no network stack

    snapshot = gather_snapshot(args.repo, _token())
    json.dump(snapshot, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


def cmd_run(args: argparse.Namespace) -> int:
    """`run`: gather the live snapshot then apply the policy."""
    from .github import gather_snapshot

    snapshot = gather_snapshot(args.repo, _token())
    record = select_issue(snapshot, required_label=args.label,
                          now=datetime.now(timezone.utc))
    _emit(record, args)
    return 0


def _add_output_flags(p: argparse.ArgumentParser) -> None:
    """Attach the shared ``--gh-output`` / ``--summary`` / ``--label`` flags."""
    p.add_argument("--gh-output", help="path to append `issue=` (defaults to $GITHUB_OUTPUT)")
    p.add_argument("--summary", help="path to append a markdown summary (defaults to $GITHUB_STEP_SUMMARY)")
    p.add_argument("--label", default=DEFAULT_REQUIRED_LABEL,
                   help=f"required opt-in label (default: {DEFAULT_REQUIRED_LABEL})")


def build_parser() -> argparse.ArgumentParser:
    """Construct the argument parser for the three subcommands."""
    parser = argparse.ArgumentParser(prog="backlog-burn", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p_select = sub.add_parser("select", help="apply the policy to a snapshot on stdin")
    p_select.add_argument("--input", help="snapshot JSON file (default: stdin)")
    _add_output_flags(p_select)
    p_select.set_defaults(func=cmd_select)

    p_gather = sub.add_parser("gather", help="read the live snapshot from GitHub")
    p_gather.add_argument("--repo", required=True, help="owner/name")
    p_gather.set_defaults(func=cmd_gather)

    p_run = sub.add_parser("run", help="gather then select")
    p_run.add_argument("--repo", required=True, help="owner/name")
    _add_output_flags(p_run)
    p_run.set_defaults(func=cmd_run)

    return parser


def main(argv: Optional[list[str]] = None) -> int:
    """CLI entry point; returns the process exit code."""
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
