# backlog-burn

The selection engine behind the **scheduled backlog burn**
(`.github/workflows/backlog-burn.yml`, issue #95): a nightly routine that
picks **one** open issue and runs `/ship-issue` on it unattended, leaving a
draft PR for human review.

This tool owns the one decision that must be reproducible and testable —
*which* issue — and nothing else. The agentic `/ship-issue` run is the
workflow's job; the off-switch and the live invocation are the workflow's
job. Here lives the policy.

## The policy

From a snapshot of the repo's open issues (plus the open PRs and remote
branches that reveal what is already claimed), `select` returns **at most
one** issue, applying, in order:

1. **opt-in** — the issue must carry the `autonomy-ok` label. Nothing is
   eligible until a human adds it, so the routine ships nothing on the day it
   lands: it waits for a curated backlog. This is the per-issue on-ramp that
   complements the workflow's repo-variable off-switch.
2. **not already claimed** — excluded if any of the `/ship-issue` §0 lock
   signals hold: an active `🚢 SHIP-LOCK` marker comment (a `WITHDRAWN` one
   releases it), an open PR that closes the issue (any of GitHub's nine
   closing keywords, or a `claude/issue-<N>-*` head branch), or an existing
   remote `claude/issue-<N>-*` branch.
3. **oldest-first** — among what survives, the oldest issue by creation time
   (tie-broken by number, so the pick is deterministic across runs).
4. **cap of one** — everything past the first eligible issue is deferred to
   the next firing, so a bad night costs one PR, not five.

`select` is a **pure function of the snapshot** — no network — which is what
lets every guard above carry a negative-control test (see
`tests/test_select.py`: remove a guard and its "excluded" assertion fails).
That mirrors the repo's `lib/*-guards.conf` discipline in Python: a policy
that silently stops refusing what it exists to refuse is the failure this
suite exists to catch.

The `/ship-issue` skill re-verifies all of §2 before it touches code, so this
is a best-effort *pre-filter*: its contract is only to never *hand* the run
an issue that is plainly taken, and never more than one.

## Usage

```bash
# Pure policy: snapshot JSON on stdin -> selection record on stdout
backlog-burn select --input snapshot.json

# Live read: build the snapshot from the GitHub REST API (needs GH_TOKEN)
GH_TOKEN=... backlog-burn gather --repo owner/name

# What the workflow runs: gather then select
GH_TOKEN=... backlog-burn run --repo owner/name
```

`select` and `run` also honour `$GITHUB_OUTPUT` (writes `issue=<n>`, empty
when nothing was selected) and `$GITHUB_STEP_SUMMARY` (a markdown outcome
block), so the workflow stays a few lines of glue.

## Layout

- `src/backlog_burn/select.py` — the pure policy (tested)
- `src/backlog_burn/github.py` — the thin live GitHub read (stdlib `urllib`)
- `src/backlog_burn/cli.py` — `select` / `gather` / `run`
- `tests/` — pytest; CI runs it when the tool changes

Stdlib-only on purpose (empty `dependencies` in `pyproject.toml`): the
routine runs on the system Python in a scheduled CI job, so a third-party
import would mean a pip step in front of the step that decides what to ship.

## Tests

```bash
pip install -e 'tools/backlog-burn[test]'
python -m pytest tools/backlog-burn/tests -q
```
