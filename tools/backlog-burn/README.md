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
   remote `claude/issue-<N>-*` branch. A SHIP-LOCK more than a few hours old
   with **no** backing branch and **no** closing PR is a *stale* claim — a run
   that died between posting its lock and pushing — and, exactly as the skill's
   §0.3 takeover rule allows, it does **not** block: otherwise a dead run would
   freeze the issue out of the burn forever, since the skill's own takeover
   only runs for an issue this selector actually hands it.
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
GH_TOKEN=... backlog-burn run --repo owner/name --label autonomy-ok

# Read the committed policy (what the workflow gates on)
backlog-burn config --get enabled      # -> true|false
backlog-burn config --get label        # -> autonomy-ok
```

`select` and `run` also honour `$GITHUB_OUTPUT` (writes `issue=<n>`, empty
when nothing was selected) and `$GITHUB_STEP_SUMMARY` (a markdown outcome
block), so the workflow stays a few lines of glue.

## Config: where the on/off and label live

`.github/backlog-burn.conf` is the **git-tracked source of truth** for the
routine's policy — the same idea as `.github/ci-gates/registry.conf`:

```
enabled: true
label: autonomy-ok
provider: anthropic   # or: zai
```

`config.py` parses it strictly (a typo'd key, bad value, or unknown provider
fails loudly, so the routine never runs on a policy nobody wrote). The workflow
reads `enabled`, `label`, and `provider` from it, and the routine acts only
when **both** the committed `enabled: true` **and** the `BACKLOG_BURN_ENABLED`
repo variable agree — the committed file is the reproducible intent (change it
in a reviewed PR); the variable is the fast, human-only arming/kill switch (not
in git on purpose). Cadence is the `cron` literal in the workflow, since
Actions can't read a file or variable for `on.schedule`.

### Choosing the LLM provider

`provider:` selects which model runs `/ship-issue`. Each known provider
(`KNOWN_PROVIDERS`) has an explicit ship step in the workflow — a provider is a
reviewed, git-tracked step because GitHub Actions can only reference a secret
by its literal name, so a runtime label can't pick the secret on its own:

- `anthropic` — Claude via `api.anthropic.com`, secret `ANTHROPIC_API_KEY` (default).
- `zai` — Z.AI GLM via its Anthropic-compatible endpoint
  (`ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic`, `--model glm-4.6`),
  secret `ZAI_KEY`.

Switching is this one line in the config. Adding a new provider is a new ship
step in the workflow plus its label in `KNOWN_PROVIDERS`. Note: `/ship-issue`
is a Claude Code skill and Anthropic doesn't officially support routing Claude
Code to non-Claude models, so non-`anthropic` providers are best-effort and
quality may vary.

## Layout

- `src/backlog_burn/select.py` — the pure policy (tested)
- `src/backlog_burn/github.py` — the thin live GitHub read (stdlib `urllib`)
- `src/backlog_burn/config.py` — the committed-policy parser (tested)
- `src/backlog_burn/cli.py` — `select` / `gather` / `run` / `config`
- `tests/` — pytest; CI runs it when the tool changes

Stdlib-only on purpose (empty `dependencies` in `pyproject.toml`): the
routine runs on the system Python in a scheduled CI job, so a third-party
import would mean a pip step in front of the step that decides what to ship.

## Tests

```bash
pip install -e 'tools/backlog-burn[test]'
python -m pytest tools/backlog-burn/tests -q
```
