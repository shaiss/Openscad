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
- **`designs/<name>/...` changed** (and no infra) → gate just those designs
  (skip names whose `designs/<name>/<name>.scad` no longer exists).
- **`templates/` changed** → run `check.sh` (templates are echo-checked),
  no gate.
- **Only docs/skills/audits changed** → the lint step below still applies
  if `.claude/hooks/` changed; otherwise only the readme-gate below runs.

CI runs the `design-docs` job (readme-gate) on **every** PR regardless of
scope — it needs no installs and takes seconds, so it is never skipped
here either.

## 2. Run (in this order — fastest failure first)

```bash
# lint (CI runs these on every PR; locally, run when scripts/hooks/workflow changed)
shellcheck --severity=warning scripts/*.sh .claude/hooks/*.sh
actionlint .github/workflows/*.yml   # if missing: install pinned, same as ci.yml's lint job

./scripts/readme-gate.sh                             # product pages + committed GIFs + configured product shots (every PR)
./scripts/check.sh                                   # syntax/eval of every .scad
./scripts/gate.sh --slice <changed-names...>         # or no args when infra changed
python -m pytest tools/printcheck/tests -q           # if tools/printcheck or the workflow changed
```

Missing tools (openscad, prusa-slicer, printcheck) mean the SessionStart
hook hasn't run — run `.claude/hooks/session-start.sh` first, don't skip
the gate.

## 3. Verdict

Report a one-line verdict first: **"CI would pass"** or **"CI would fail:
<step>"**, then per-part printcheck scores (capture the gate output with
`tee` to a log file and run `python3 scripts/gate-summary.py <log>` for the
same table CI posts). A gate
failure is a stop: fix and re-run preflight before pushing. Never soften a
red result — a failed step with output beats a green summary that lies.
