# telemetry

The capture-and-report engine behind the repo's self-measurement
(issue #93): the repo measures itself over time — gate scores, render
wall-time, preview budget headroom, what a run skipped and why — and
surfaces the result as a committed report, so autonomy decisions (the
scheduled backlog burn, the idea→PR pipeline) can consult data instead of
vibes.

Two halves, deliberately separated:

- **capture** turns *one* gate run into *one* JSON line: it parses the
  gate.sh log (the same machine-read line shapes `scripts/gate-summary.py`
  reads for the sticky PR comment — printcheck scores, slice results,
  derivative checks, plus the telemetry-only `time <name>: gated in <N>s`
  wall-time and `skip <name>: archived …` lines), scans the committed
  previews against the shared size budgets, and embeds whatever run
  metadata the caller hands it. Pure function of its inputs; safe on a
  partial log from a crashed run.
- **report** renders the accumulated NDJSON log (`telemetry/log.ndjson`)
  into the committed markdown report (`telemetry/REPORT.md`) — same
  regen-and-commit pattern as the previews: derived, never hand-edited,
  byte-stable for an unchanged log. A malformed log line fails the render
  loudly rather than being skipped: the log is committed, so corruption is
  something to fix, not to paper over.

Stdlib-only like `tools/lineage` — capture runs inside CI's render-gate job
and the report generator runs wherever `check.sh` does, neither behind a
pip install. The `[test]` extra is just pytest.

## Usage

Always via the wrapper, which sources `scripts/preview-budget.sh` and
supplies the budget flags (the one source both the renderers and
readme-gate read — hand-typing budgets here is how the record ends up
disagreeing with the gate):

```bash
# One gate run -> one JSON line appended to the committed log
./scripts/telemetry.sh capture --gate-log gate.log \
  --out telemetry/log.ndjson --meta event=push --meta designs=ALL

# Regenerate the committed report from the log
./scripts/telemetry.sh report --out telemetry/REPORT.md
```

## The record (schema 1, kind `gate-run`)

One JSON object per line, oldest first, `sort_keys` so a record is
byte-stable for given facts:

```json
{"schema": 1, "kind": "gate-run", "utc": "…", "meta": {"event": "push", "…": "…"},
 "gate": {"parts": [{"stl": "…", "score": 97, "verdict": "…", "criticals": 0,
                     "warnings": 1, "slice_failed": false,
                     "print_time": "…", "filament_g": "…"}],
          "pre_fails": ["…"], "derivatives": [{"ok": true, "…": "…"}],
          "design_seconds": {"name": 42}, "archived_skips": ["…"],
          "fail_lines": 0, "ok": true},
 "budgets": [{"file": "designs/…/previews/….gif", "bytes": 1, "budget": 6291456,
              "headroom_pct": 99.9}]}
```

`ok` counts gate.sh's own FAIL lines rather than smuggling in an exit code,
so a record can be captured from a log alone. A part whose printcheck died
mid-run carries `score: null` — never a default a reader could mistake for
a pass. Budgets read worst-first (least headroom), and negative headroom is
kept negative: that file is failing readme-gate, and the record says so.

Schema changes bump `schema` and keep the reader accepting old records —
the log is append-only history, never rewritten.

## Who writes the log

CI's render-gate job captures a record from every gate run and uploads it
as the `telemetry-record` artifact; on a default-branch push it also
appends the record to `telemetry/log.ndjson`, regenerates
`telemetry/REPORT.md`, and commits both. That commit is pushed with
`GITHUB_TOKEN` **on purpose** — the exact property the regen job must avoid
(a `GITHUB_TOKEN` push triggers no workflow) is the one this commit needs,
because a telemetry commit that re-triggered CI would gate the whole
catalog again, capture a new record, and commit forever. No required
check ever attaches to a main commit after the fact, so nothing is
stranded; the loop is simply never entered.

The tests (`tests/`) pin every gate.sh line shape the parser reads and
carry a negative control per refusal — the same `lib/*-guards.conf`
discipline the other tools keep: a parser that silently stops reading a
field, or a report that quietly skips corrupt history, is the failure this
suite exists to catch.
