# ci-gates — Smart CI gate selection

The `changes` classifier in `.github/workflows/ci.yml` decides which of the CI
gates that **already exist** run for a PR. This tool is the second layer: it
decides which gates *should exist* but don't yet. From a PR's changed files it
proposes candidate gates, runs the ones already approved, and reports the rest
so a maintainer can cross them with one command.

Stdlib-only, like `tools/lineage`, and for the same reason: CI's `smart-ci` job
runs the selector to decide what to gate, and that decision must not sit behind
a `pip install`.

## The three moving parts

| part | where | job |
| --- | --- | --- |
| **detectors** | `src/ci_gates/detectors.py` | decide whether a candidate gate *applies* to a PR — pure functions of the changed-file list and the tree |
| **registry** | `.github/ci-gates/registry.conf` | the committed, reproducible record of the *decision* about each candidate (`on` / `proposed` / `off`) and its tier |
| **selector** | `src/ci_gates/select.py` | joins the two into the buckets the job runs and the comment reports |

The registry is the source of truth precisely because it lives in git: a clone
carries it, a diff shows every change, and every run reads it identically.
GitHub supplies only the *interaction* (the `/ci-gate` command and the sticky
comment) and the *authorization* (the commenter's real repo permission).

## Tiers and the auto-approve policy

- **advisory** — cheap and non-blocking. Auto-approved: it runs whenever it
  applies, with no human step (default state `on`). A mis-fire only warns.
- **gating** — can *fail* a PR. Stays `proposed` until a human crosses it
  (default state `proposed`), so a new blocking check never lands unannounced.

`default_state()` in `registry.py` is where that policy lives: advisory → `on`,
gating → `proposed`. A gate is known to selection only if it has a stanza in
the registry; within that stanza the `state` field is what may be omitted, and
it falls back to the tier default — so a gate's *decision* can be left implicit,
but the gate itself (tier, title, run) must be declared.

## Seeded gates

| id | tier | fires when | out of the box |
| --- | --- | --- | --- |
| `classifier-coverage` | advisory | a changed file lives under a top-level dir the `changes` classifier does not mention | **on** — the CAUTION at the top of ci.yml, made into a check |
| `shellcheck` | gating | a `scripts/` or `.claude/hooks/` `*.sh` changed (the trees the gate lints) | **proposed** — cross with `/ci-gate approve shellcheck` |
| `actionlint` | gating | a `.github/workflows/*.yml` changed | **proposed** — cross with `/ci-gate approve actionlint` |

## CLI

```bash
export PYTHONPATH=tools/ci-gates/src

# Compute the selection for a PR (writes a run plan and the sticky comment)
python -m ci_gates select --changed-from changed.txt --sha "$(git rev-parse --short HEAD)" \
  --plan plan.json --comment comment.md

# Run the active gates from a plan (gating failures exit 1; advisory only warn)
python -m ci_gates run-plan plan.json --changed-from changed.txt

# Approve / decline a gate (what the /ci-gate workflow runs; edits the registry)
python -m ci_gates approve shellcheck
python -m ci_gates decline actionlint

# Show every gate and its state
python -m ci_gates list
```

Exit codes: `0` success, `1` a blocking gate failed under `run-plan`, `2` a bad
invocation or a malformed registry.

## Tests

```bash
pip install -e 'tools/ci-gates[test]'
python -m pytest tools/ci-gates/tests -q
```

The suite carries negative controls throughout — a detector that must *not*
fire, a gating gate that must *stay* proposed until crossed, an advisory gate
that must never block, a registry write that must touch only the changed line —
because the engine decides what CI does, so every check in it has to be able to
fail. CI runs it (the `smart-ci selector unit tests` job) whenever the tool or
the registry changes.
