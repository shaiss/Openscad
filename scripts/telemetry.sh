#!/usr/bin/env bash
# Telemetry entry point (issue #93): the repo measures itself.
#
#   ./scripts/telemetry.sh capture --gate-log gate.log \
#       [--out telemetry/log.ndjson] [--meta k=v ...]
#                                  # one gate run -> one JSON record; parses
#                                  # the gate log and scans committed previews
#                                  # against the shared size budgets
#   ./scripts/telemetry.sh report [--log telemetry/log.ndjson] \
#       [--out telemetry/REPORT.md]
#                                  # render the committed NDJSON log into the
#                                  # committed markdown report
#   ./scripts/telemetry.sh --selftest
#                                  # prove the shell glue: the budgets sourced
#                                  # from preview-budget.sh reach the record,
#                                  # capture refuses a missing log, report
#                                  # refuses a corrupt one (run by check.sh)
#
# The parsing and rendering live in tools/telemetry (stdlib-only, own pytest
# suite). This wrapper owns exactly one fact the tool must not duplicate: the
# preview size budgets come from scripts/preview-budget.sh — the single source
# the renderers and readme-gate.sh already share — so the record can never
# disagree with the gate about what "over budget" means.
#
# Why PYTHONPATH instead of requiring `pip install -e tools/telemetry`: same
# rule as scripts/lineage.sh — capture runs inside CI's render-gate job with
# no install step of its own, and pointing PYTHONPATH at the source tree means
# a contributor can never capture against a stale installed copy.
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=scripts/preview-budget.sh
source scripts/preview-budget.sh

run_tool() {
  env PYTHONPATH="$PWD/tools/telemetry/src${PYTHONPATH:+:$PYTHONPATH}" \
    python3 -m telemetry.cli "$@"
}

selftest() {
  local tmp fail=0
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  # A minimal but real gate log (the shapes gate.sh emits), and a preview
  # tree with one file per budget class.
  cat >"$tmp/gate.log" <<'EOF'
== thing: printcheck build/thing.stl ==
SCORE: 98/100 — ship it
time  thing: gated in 3s
EOF
  mkdir -p "$tmp/designs/thing/previews"
  printf 'x%.0s' {1..1024} >"$tmp/designs/thing/previews/turntable.gif"
  printf 'x%.0s' {1..2048} >"$tmp/designs/thing/previews/hero.png"

  # 1. The sourced budgets reach the record — the one fact only this wrapper
  #    can prove, since the pytest suite drives the tool with synthetic flags.
  local rec
  if rec=$(run_tool capture --gate-log "$tmp/gate.log" \
      --gif-budget "$MAX_GIF_BYTES" --shot-budget "$MAX_SHOT_BYTES" \
      --designs-dir "$tmp/designs" --meta event=selftest); then
    printf '%s\n' "$rec" >"$tmp/rec.json"
    if GIF_B="$MAX_GIF_BYTES" SHOT_B="$MAX_SHOT_BYTES" REC="$tmp/rec.json" \
        python3 - <<'PY'
import json, os
with open(os.environ["REC"], encoding="utf-8") as f:
    rec = json.load(f)
budgets = {b["file"].rsplit(".", 1)[-1]: b["budget"] for b in rec["budgets"]}
expect = {"gif": int(os.environ["GIF_B"]), "png": int(os.environ["SHOT_B"])}
assert budgets == expect, (budgets, expect)
assert rec["gate"]["parts"][0]["score"] == 98
assert rec["gate"]["design_seconds"] == {"thing": 3}
assert rec["meta"] == {"event": "selftest"}
PY
    then
      echo "ok    selftest: sourced budgets and gate facts reach the record"
    else
      echo "FAIL  selftest: the captured record does not carry the sourced budgets"
      fail=1
    fi
  else
    echo "FAIL  selftest: capture failed on a well-formed gate log"
    fail=1
  fi

  # 2. Negative control: capture must refuse a missing gate log.
  if run_tool capture --gate-log "$tmp/no-such.log" \
      --gif-budget "$MAX_GIF_BYTES" --shot-budget "$MAX_SHOT_BYTES" \
      --designs-dir "$tmp/designs" >/dev/null 2>&1; then
    echo "FAIL  selftest: capture accepted a missing gate log"
    fail=1
  else
    echo "ok    selftest: capture refuses a missing gate log"
  fi

  # 3. The record round-trips through report, and a corrupt log is refused.
  printf '%s\n' "$rec" >"$tmp/log.ndjson"
  if run_tool report --log "$tmp/log.ndjson" | grep -q 'build/thing.stl'; then
    echo "ok    selftest: report renders the captured record"
  else
    echo "FAIL  selftest: report did not render the captured record"
    fail=1
  fi
  printf '%s\n{broken\n' "$rec" >"$tmp/corrupt.ndjson"
  if run_tool report --log "$tmp/corrupt.ndjson" >/dev/null 2>&1; then
    echo "FAIL  selftest: report accepted a corrupt log line"
    fail=1
  else
    echo "ok    selftest: report refuses a corrupt log line"
  fi

  return "$fail"
}

cmd="${1:-}"
case "$cmd" in
  capture)
    shift
    run_tool capture --gif-budget "$MAX_GIF_BYTES" \
      --shot-budget "$MAX_SHOT_BYTES" "$@"
    ;;
  report)
    shift
    run_tool report "$@"
    ;;
  --selftest)
    selftest
    ;;
  *)
    echo "usage: $0 capture|report|--selftest [args]" >&2
    echo "       (see the header of this script and tools/telemetry/README.md)" >&2
    exit 2
    ;;
esac
