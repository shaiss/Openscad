#!/usr/bin/env bash
# Negative tests for the guards in lib/*.scad: prove each one still FIRES on
# the input it exists to reject. Run by scripts/check.sh.
#
# A guard is the one kind of library code its own demo cannot cover. A firing
# assert aborts the render, so the case that proves the guard works is exactly
# the case that would break check.sh's geometry pass — which means a guard can
# be deleted, weakened, or quietly bypassed and every check in this repo stays
# green. The regression is invisible precisely because the thing being
# protected is a failure.
#
# Cases live beside the library they test, in lib/<name>-guards.conf:
#
#   # <case name> | <expected message substring> | <statement>
#   neg-chamfer | chamfer must not be negative | thread_neck(28, 1.2, 4, 2, 9, chamfer = -2);
#
# Only the first two `|` split fields, so a statement may contain `||`.
#
# Two implementation choices worth knowing before editing this:
#
#   * Matching is on the MESSAGE, never the exit code. Under CSG export
#     OpenSCAD prints `ERROR: Assertion ... failed` and then exits 0 anyway
#     (verified on 2021.01). A harness keyed on exit status would report
#     success forever without a single guard having run. Matching the text
#     also closes the other silent hole: a case that aborts for some unrelated
#     reason otherwise looks exactly like a working guard. The match is on an
#     ERROR carrying the guard's own words rather than on OpenSCAD's exact
#     assertion phrasing, so the dev snapshot (CI runs check.sh under it too)
#     rewording its diagnostics cannot quietly turn every case green.
#
#   * CSG export, not STL. It instantiates geometry, so asserts inside module
#     bodies evaluate — `--export-format echo` does NOT instantiate and reports
#     nothing at all, which is why the guards below cannot be checked the way
#     check.sh checks syntax. CSG skips the CGAL render, so the path taken when
#     a guard has regressed (no abort, full evaluation) still costs ~0.1s.
set -euo pipefail

cd "$(dirname "$0")/.."
export OPENSCADPATH="$PWD/lib:$PWD"

OPENSCAD_BIN="${OPENSCAD_BIN:-openscad}"
read -ra OSC_ARGS <<<"${OPENSCAD_ARGS:-}"

fail=0
cases=0

mkdir -p build
work="build/.guard-case"
trap 'rm -f "$work".scad "$work".csg' EXIT

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

shopt -s nullglob
for conf in lib/*-guards.conf; do
  lib="$(basename "$conf" -guards.conf)"
  [[ -f "lib/${lib}.scad" ]] || {
    echo "FAIL  ${conf}: no lib/${lib}.scad to test"
    fail=1
    continue
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue

    name="$(trim "${line%%|*}")"
    rest="${line#*|}"
    expect="$(trim "${rest%%|*}")"
    stmt="$(trim "${rest#*|}")"

    if [[ -z "$name" || -z "$expect" || -z "$stmt" || "$rest" == "$line" ]]; then
      echo "FAIL  ${conf}: malformed case (want 'name | expect | statement'): $line"
      fail=1
      continue
    fi

    cases=$((cases + 1))
    # $fn is deliberately coarse: these renders exist to reach an assert, not
    # to produce geometry, and a guard that only fires at high $fn would be a
    # bug in the guard.
    printf 'use <%s.scad>\n$fn = 16;\n%s\n' "$lib" "$stmt" >"$work.scad"

    out=$(xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
      -o "$work.csg" "$work.scad" 2>&1 || true)

    # Test on "an ERROR carrying THIS guard's own words", not on the exact
    # `ERROR: Assertion '<expr>' failed:` wording: check.sh runs a second time
    # under the dev snapshot (CI's scad-check-nightly), and a phrasing change
    # there must not turn every guard green. The expected substring is text
    # that exists nowhere but inside the guard being tested, so it carries the
    # specificity on its own.
    if ! grep -q "ERROR" <<<"$out"; then
      echo "FAIL  ${lib}/${name}: guard did not fire — the failure it prevents is unguarded again"
      echo "      statement: ${stmt}"
      sed 's/^/      /' <<<"$out" | tail -5
      fail=1
    elif ! grep -qF "$expect" <<<"$out"; then
      echo "FAIL  ${lib}/${name}: aborted, but not on the expected guard"
      echo "      expected message to contain: ${expect}"
      grep "ERROR" <<<"$out" | sed 's/^/      /' | head -2
      fail=1
    else
      echo "ok    ${lib}/${name} fires"
    fi
  done <"$conf"
done

if (( cases == 0 )); then
  echo "ok    no lib/*-guards.conf cases to run"
fi

exit "$fail"
