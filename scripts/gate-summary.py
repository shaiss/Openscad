#!/usr/bin/env python3
"""Turn a gate.sh log into a GitHub-flavored markdown table.

Usage: gate-summary.py gate.log > summary.md

Reads the `== name: printcheck stl ==` / `SCORE:` / `== test-slice ... ==` /
`estimated printing time` lines gate.sh emits and renders one row per gated
STL. Used by CI for both the job summary and the sticky PR comment; safe on
partial logs (a crashed gate run still yields whatever rows completed).
"""
import re
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    try:
        with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
            lines = f.read().splitlines()
    except OSError as e:
        print(f"gate-summary: {e}", file=sys.stderr)
        return 2

    rows = []          # {stl, score, verdict, criticals, warnings, time, slice_fail}
    cur = None
    for line in lines:
        m = re.match(r"== .*: printcheck (\S+) ==", line)
        if m:
            cur = {"stl": m.group(1), "score": "?", "verdict": "no report",
                   "criticals": 0, "warnings": 0, "time": "—", "slice_fail": False}
            rows.append(cur)
            continue
        if cur is None:
            continue
        m = re.search(r"SCORE: (\d+)/100 — (.+)", line)
        if m:
            cur["score"], cur["verdict"] = m.group(1), m.group(2).strip()
            continue
        if "[CRITICAL]" in line:
            cur["criticals"] += 1
            continue
        if "[WARNING" in line:
            cur["warnings"] += 1
            continue
        m = re.search(r"estimated printing time \(normal mode\) = (.+)", line)
        if m:
            cur["time"] = m.group(1).strip()
            continue
        if re.search(r"FAIL\s+\S+: slicing failed", line):
            cur["slice_fail"] = True

    print("### printcheck + slice results")
    print()
    if not rows:
        print("_no gate output captured_")
        return 0
    print("| Part | Score | Verdict | Findings | Est. print time |")
    print("|---|---|---|---|---|")
    for r in rows:
        findings = []
        if r["criticals"]:
            findings.append(f"{r['criticals']} critical")
        if r["warnings"]:
            findings.append(f"{r['warnings']} warning" + ("s" if r["warnings"] > 1 else ""))
        verdict = r["verdict"] + (" — **slice failed**" if r["slice_fail"] else "")
        icon = "❌" if r["criticals"] or r["slice_fail"] else ("⚠️" if r["warnings"] else "✅")
        print(f"| `{r['stl']}` | {icon} {r['score']}/100 | {verdict} "
              f"| {', '.join(findings) or '—'} | {r['time']} |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
