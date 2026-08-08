"""Command-line interface: select | run-plan | run | approve | decline | list.

Exit codes are the contract CI reads:
  0  the command succeeded (for run-plan: every blocking gate passed)
  1  a blocking (gating) gate failed under run-plan
  2  the invocation or the registry is wrong

`select` never fails on gate results — it only decides what to run and writes
the plan and the comment. Running the plan, and thus any blocking failure, is
run-plan's job, kept separate so the sticky comment is posted whether or not a
gate later fails.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

from . import comment as comment_mod
from .detectors import applies as detector_applies
from .registry import Registry, find_root
from .select import Selection, select


def _read_changed(args) -> list[str]:
    files: list[str] = []
    if args.changed_from:
        text = Path(args.changed_from).read_text(encoding="utf-8")
        files.extend(line for line in text.splitlines())
    files.extend(args.files or [])
    return [f.strip() for f in files if f.strip()]


def _load_registry(args) -> Registry:
    if args.registry:
        return Registry.load(Path(args.registry))
    return Registry.find(Path(args.root) if args.root else None)


def _root(args) -> Path:
    return Path(args.root).resolve() if args.root else find_root(Path.cwd())


def _emit_output(key: str, value) -> None:
    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as fh:
            fh.write(f"{key}={value}\n")


def cmd_select(args) -> int:
    registry = _load_registry(args)
    root = _root(args)
    changed = _read_changed(args)
    sel = select(registry, changed, root)

    plan = {
        "active": [
            {
                "id": s.id,
                "tier": s.gate.tier,
                "blocking": s.gate.gating,
                "setup": s.gate.setup,
                "run": s.gate.run,
                "why": s.why,
            }
            for s in sel.active
        ],
    }
    if args.plan:
        Path(args.plan).write_text(json.dumps(plan, indent=2) + "\n", encoding="utf-8")

    body = comment_mod.render(sel, sha=args.sha or "", registry_path=_registry_rel(registry, root))
    if args.comment:
        Path(args.comment).write_text(body, encoding="utf-8")

    _emit_output("active", len(sel.active))
    _emit_output("proposed", len(sel.proposed))
    _emit_output("blocking", len(sel.blocking()))
    _emit_output("has_comment", "true" if (sel.active or sel.proposed or sel.declined) else "false")

    _print_summary(sel)
    return 0


def _registry_rel(registry: Registry, root: Path) -> str:
    if registry.path is None:
        return ".github/ci-gates/registry.conf"
    try:
        return str(registry.path.resolve().relative_to(root))
    except ValueError:
        return str(registry.path)


def _print_summary(sel: Selection) -> None:
    print(f"active:   {len(sel.active)}  ({len(sel.blocking())} blocking)")
    for s in sel.active:
        print(f"  - {s.id} [{s.gate.tier}] {s.why}")
    print(f"proposed: {len(sel.proposed)}")
    for s in sel.proposed:
        print(f"  - {s.id} [{s.gate.tier}] -> {s.gate.cross}")
    if sel.declined:
        print(f"declined: {len(sel.declined)}")


def cmd_run_plan(args) -> int:
    plan = json.loads(Path(args.plan).read_text(encoding="utf-8"))
    root = _root(args)
    env = dict(os.environ)
    env["CI_GATES_ROOT"] = str(root)
    if args.changed_from:
        env["CI_GATES_CHANGED"] = str(Path(args.changed_from).resolve())
    failures: list[str] = []
    for gate in plan.get("active", []):
        gid = gate["id"]
        blocking = gate["blocking"]
        label = "gating" if blocking else "advisory"
        print(f"::group::smart-ci gate {gid} ({label})")
        ok = True
        if gate.get("setup"):
            ok = _run_step(gate["setup"], root, env) == 0
        if ok and gate.get("run"):
            rc = _run_step(gate["run"], root, env)
            ok = rc == 0
        print("::endgroup::")
        if not ok:
            if blocking:
                failures.append(gid)
                print(f"::error::gating gate {gid} failed")
            else:
                print(f"::warning::advisory gate {gid} reported findings (non-blocking)")
    if failures:
        print(f"\nblocking gates failed: {', '.join(failures)}")
        return 1
    print("\nall active gates passed (or were advisory)")
    return 0


def _run_step(cmd: str, root: Path, env: dict) -> int:
    print(f"$ {cmd}")
    return subprocess.run(["bash", "-c", cmd], cwd=root, env=env).returncode


def cmd_run(args) -> int:
    """Run a single gate's built-in behavior.

    Only the pure-python advisory gates route here (their registry `run` is
    `python -m ci_gates run <id>`); it re-states the detector's finding and
    exits 0, because an advisory gate's whole check is that it detected the
    condition — there is nothing to fail on.
    """
    root = Path(os.environ.get("CI_GATES_ROOT", "")) if os.environ.get("CI_GATES_ROOT") else _root(args)
    changed: list[str] = []
    cf = os.environ.get("CI_GATES_CHANGED")
    if cf and Path(cf).is_file():
        changed = [l.strip() for l in Path(cf).read_text(encoding="utf-8").splitlines() if l.strip()]
    ap = detector_applies(args.id, changed, root)
    if ap.applies:
        print(f"[{args.id}] {ap.why}")
    else:
        print(f"[{args.id}] no longer applies")
    return 0


def cmd_approve(args) -> int:
    return _set_state(args, "on")


def cmd_decline(args) -> int:
    return _set_state(args, "off")


def _set_state(args, state: str) -> int:
    registry = _load_registry(args)
    if args.id not in registry:
        print(f"no gate named {args.id!r} in {registry.path}", file=sys.stderr)
        print(f"known gates: {', '.join(registry.ids())}", file=sys.stderr)
        return 2
    before = registry.get(args.id).state
    registry.set_state(args.id, state)
    registry.save()
    after = registry.get(args.id).state
    print(f"{args.id}: {before} -> {after}")
    if before == after:
        print("(already in that state — no change)")
    return 0


def cmd_list(args) -> int:
    registry = _load_registry(args)
    for gate in registry:
        print(f"{gate.state:>8}  {gate.tier:>8}  {gate.id}  —  {gate.title}")
    return 0


def _add_common(p, *, need_changed: bool = False) -> None:
    p.add_argument("--root", help="repo root (default: walk up to .github/ci-gates)")
    p.add_argument("--registry", help="registry path (default: <root>/.github/ci-gates/registry.conf)")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="ci-gates", description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    ps = sub.add_parser("select", help="compute the gate selection for a PR")
    _add_common(ps)
    ps.add_argument("--changed-from", help="file of changed paths, one per line")
    ps.add_argument("files", nargs="*", help="changed paths (in addition to --changed-from)")
    ps.add_argument("--sha", help="commit sha, for the comment footer")
    ps.add_argument("--plan", help="write the run plan JSON here")
    ps.add_argument("--comment", help="write the sticky comment markdown here")
    ps.set_defaults(fn=cmd_select)

    pr = sub.add_parser("run-plan", help="run the active gates from a plan JSON")
    _add_common(pr)
    pr.add_argument("plan", help="plan JSON from `select --plan`")
    pr.add_argument("--changed-from", help="changed-paths file, exported to gates as CI_GATES_CHANGED")
    pr.set_defaults(fn=cmd_run_plan)

    pn = sub.add_parser("run", help="run one advisory gate's built-in behavior")
    _add_common(pn)
    pn.add_argument("id")
    pn.set_defaults(fn=cmd_run)

    pa = sub.add_parser("approve", help="set a gate's state to on")
    _add_common(pa)
    pa.add_argument("id")
    pa.set_defaults(fn=cmd_approve)

    pd = sub.add_parser("decline", help="set a gate's state to off")
    _add_common(pd)
    pd.add_argument("id")
    pd.set_defaults(fn=cmd_decline)

    pl = sub.add_parser("list", help="show every gate and its state")
    _add_common(pl)
    pl.set_defaults(fn=cmd_list)

    args = parser.parse_args(argv)
    try:
        return args.fn(args)
    except (ValueError, KeyError, FileNotFoundError) as e:
        print(f"error: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
