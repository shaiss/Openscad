"""CLI for the telemetry tool. Invoked via scripts/telemetry.sh, which
sources scripts/preview-budget.sh and supplies the two budget flags — never
call `capture` with hand-typed budgets, or the record can disagree with the
gate about what "over budget" means.

    telemetry capture --gate-log gate.log --gif-budget N --shot-budget N \
        [--designs-dir designs] [--out log.ndjson] [--meta k=v ...]
    telemetry report [--log telemetry/log.ndjson] [--out telemetry/REPORT.md]
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from . import budgets, gatelog, report

SCHEMA = 1


def _parse_meta(pairs: list[str]) -> dict[str, str]:
    meta: dict[str, str] = {}
    for pair in pairs:
        key, sep, value = pair.partition("=")
        if not sep or not key:
            raise SystemExit(f"error: --meta expects key=value, got {pair!r}")
        meta[key] = value
    return meta


def cmd_capture(args: argparse.Namespace) -> int:
    try:
        text = Path(args.gate_log).read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        print(f"error: cannot read gate log: {e}", file=sys.stderr)
        return 2
    designs_dir = Path(args.designs_dir)
    if not designs_dir.is_dir():
        print(f"error: designs dir {designs_dir} does not exist", file=sys.stderr)
        return 2
    record = {
        "schema": SCHEMA,
        "kind": "gate-run",
        "utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "meta": _parse_meta(args.meta),
        "gate": gatelog.parse(text),
        "budgets": budgets.scan(designs_dir, args.gif_budget, args.shot_budget),
    }
    line = json.dumps(record, sort_keys=True)
    if args.out:
        # Append: the log is one line per run, oldest first.
        with open(args.out, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    else:
        print(line)
    return 0


def cmd_report(args: argparse.Namespace) -> int:
    try:
        text = Path(args.log).read_text(encoding="utf-8")
    except OSError as e:
        print(f"error: cannot read telemetry log: {e}", file=sys.stderr)
        return 2
    try:
        records = report.parse_log(text)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    rendered = report.render(records)
    if args.out:
        Path(args.out).write_text(rendered + "\n", encoding="utf-8")
    else:
        print(rendered)
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="telemetry", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("capture", help="turn one gate run into one JSON record")
    p.add_argument("--gate-log", required=True, help="gate.sh log to parse")
    p.add_argument("--gif-budget", type=int, required=True,
                   help="MAX_GIF_BYTES from scripts/preview-budget.sh")
    p.add_argument("--shot-budget", type=int, required=True,
                   help="MAX_SHOT_BYTES from scripts/preview-budget.sh")
    p.add_argument("--designs-dir", default="designs",
                   help="designs tree to scan for preview budget headroom")
    p.add_argument("--out", default="",
                   help="NDJSON file to append the record to (default: stdout)")
    p.add_argument("--meta", action="append", default=[], metavar="KEY=VALUE",
                   help="run metadata to embed in the record (repeatable)")
    p.set_defaults(func=cmd_capture)

    p = sub.add_parser("report", help="render the NDJSON log into markdown")
    p.add_argument("--log", default="telemetry/log.ndjson",
                   help="NDJSON telemetry log to read")
    p.add_argument("--out", default="",
                   help="markdown file to write (default: stdout)")
    p.set_defaults(func=cmd_report)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
