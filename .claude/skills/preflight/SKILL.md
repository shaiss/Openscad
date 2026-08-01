---
name: preflight
description: Answer "would CI pass?" before pushing — run the exact checks CI runs, scoped the same way CI scopes them. Use before any push of design or tooling changes, when asked to preflight, pre-check, or verify a branch is green, or when invoked as /preflight.
---

# Preflight — run CI locally before pushing

Mirror `.github/workflows/ci.yml` on the working tree, so a push never
discovers a failure CI could have told you about locally. The contract:
**what you run here is what CI runs there** — same scripts, same scoping
rules. If this skill and the workflow ever disagree, the workflow is right;
follow it and fix this skill.

## 1. Scope — what changed?

Diff against the merge base with the default branch
(`git diff --name-only $(git merge-base origin/<default-branch> HEAD)` plus
uncommitted changes; `git status --porcelain` catches unstaged work).
Classify exactly like CI's `changes` job:

- **Infra changed** (`lib/`, `scripts/`, `tools/printcheck/`, the CI
  workflow) → everything below runs, gate **all** designs.
- **Only `designs/<name>/...` changed** → gate just those designs (skip
  names whose `designs/<name>/<name>.scad` no longer exists).
- **Only docs/skills/audits changed** → nothing to run; say so and stop.

## 2. Run (in this order — fastest failure first)

```bash
shellcheck --severity=warning scripts/*.sh .claude/hooks/*.sh   # if scripts/hooks changed
./scripts/check.sh                                              # syntax/eval of every .scad
./scripts/gate.sh --slice <changed-names...>                    # or no args when infra changed
python -m pytest tools/printcheck/tests -q                      # if tools/printcheck changed
```

Missing tools (openscad, prusa-slicer, printcheck) mean the SessionStart
hook hasn't run — run `.claude/hooks/session-start.sh` first, don't skip
the gate.

## 3. Verdict

Report a one-line verdict first: **"CI would pass"** or **"CI would fail:
<step>"**, then per-part printcheck scores (pipe the gate output through
`python3 scripts/gate-summary.py` for the same table CI posts). A gate
failure is a stop: fix and re-run preflight before pushing. Never soften a
red result — a failed step with output beats a green summary that lies.
