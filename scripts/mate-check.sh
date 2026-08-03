#!/usr/bin/env bash
# Positive tests for the fits in lib/*.scad: prove a mating pair still ASSEMBLES
# at its declared clearance, and that a pair with no clearance still does not.
# Run by scripts/check.sh.
#
# This is the mirror of scripts/guard-check.sh. That one proves a library still
# REFUSES what it must refuse; this one proves it still FITS what it must fit.
# Both exist because a demo cannot cover either: a firing assert aborts the
# render it lives in, and a render cannot measure its own mesh.
#
# The specific hole this closes is issue #37's third consequence. The library's
# demo "verified" its flank clearance by echoing
#
#     (tol + flank_add(tol)/2) / sqrt(2)
#
# — the algebraic identity that DEFINES flank_add — and printed
# "0.3 (should equal 0.3)" while the built geometry delivered 0.2794. The echo
# could not have said otherwise: it never touched the profile thread_helix
# actually makes. And check.sh only greps ERROR/WARNING, so an echo carries no
# pass/fail signal even when it is wrong. A check that restates its own premise
# is not a check.
#
# So this measures the EXPORTED MESH instead. Each case is an interference
# solid — the intersection of a male part with the female part it goes into.
# If the two fit, that intersection is empty and OpenSCAD writes no facets.
#
# Cases live beside the library they test, in lib/<name>-mates.conf:
#
#   # <case name> | empty|interfering | <statement producing the interference>
#
# Only the first two `|` split fields, so a statement may contain `||`.
#
# Three implementation choices worth knowing before editing this:
#
#   * Both expectations are load-bearing. `empty` is the invariant; at least one
#     `interfering` case must exist per library, or this harness proves nothing
#     — a check that has only ever seen the passing input looks exactly like a
#     check that cannot fail. The natural negative control is the same pair at
#     tol = 0: legal (the guard allows it), and necessarily interfering, since
#     the female cutter is then the male thread exactly.
#
#   * Facets, not exit codes. OpenSCAD treats an empty top level as an error —
#     it prints "Current top level object is empty", exits 1 and writes nothing
#     — which for us is the SUCCESS signal, not a failure. lineage.sh already
#     untangles that from a real render failure (it needs the same distinction
#     for the base-safety proof), so this sources those helpers rather than
#     re-deriving the rule and getting it subtly different.
#
#   * STL export, not CSG. Emptiness is a property of the evaluated geometry,
#     so unlike guard-check.sh this one has to pay for the CGAL render.
set -euo pipefail

cd "$(dirname "$0")/.."
export OPENSCADPATH="$PWD/lib:$PWD"

# lineage_render_binstl (empty-vs-broken) and lineage_facet_count. Sourcing is
# safe: everything above lineage.sh's bottom guard is a definition.
# shellcheck source=scripts/lineage.sh
source ./scripts/lineage.sh

fail=0
cases=0

mkdir -p build
work="build/.mate-case"
trap 'rm -f "$work".scad "$work".stl' EXIT

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

shopt -s nullglob
for conf in lib/*-mates.conf; do
  lib="$(basename "$conf" -mates.conf)"
  [[ -f "lib/${lib}.scad" ]] || {
    echo "FAIL  ${conf}: no lib/${lib}.scad to test"
    fail=1
    continue
  }

  saw_negative=0
  saw_positive=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue

    # Both separators are required before the fields are split. With only one,
    # `${rest%%|*}` and `${rest#*|}` both return the same text, so a line like
    # `mycase | empty` yields expect=empty AND stmt=empty — a valid-looking
    # expectation attached to `empty` as OpenSCAD source. That renders nothing
    # and gets reported as "did not render", which points at the statement
    # instead of at the typo. A harness whose whole job is to not lie about
    # what it measured should not start by mis-parsing its own input.
    if [[ "$line" != *"|"*"|"* ]]; then
      echo "FAIL  ${lib}: malformed case, needs two '|' separators"
      echo "      expected: <name> | empty|interfering | <statement>"
      echo "      got:      ${line}"
      fail=1
      continue
    fi

    name="$(trim "${line%%|*}")"
    rest="${line#*|}"
    expect="$(trim "${rest%%|*}")"
    stmt="$(trim "${rest#*|}")"

    if [[ -z "$name" || -z "$stmt" ]]; then
      echo "FAIL  ${lib}: malformed case, name and statement must both be non-empty"
      echo "      got:      ${line}"
      fail=1
      continue
    fi
    if [[ "$expect" != "empty" && "$expect" != "interfering" ]]; then
      echo "FAIL  ${lib}/${name}: expectation must be 'empty' or 'interfering', got '${expect}'"
      fail=1
      continue
    fi
    [[ "$expect" == "interfering" ]] && saw_negative=1
    [[ "$expect" == "empty" ]] && saw_positive=1
    cases=$((cases + 1))

    printf 'use <%s.scad>\n$fn = 96;\n%s\n' "$lib" "$stmt" > "$work.scad"

    if ! lineage_render_binstl "$work.scad" "$work.stl"; then
      echo "FAIL  ${lib}/${name}: did not render (output above)"
      fail=1
      continue
    fi

    facets="$(lineage_facet_count "$work.stl")" || facets=unreadable

    case "$expect:$facets" in
      empty:0)
        echo "ok    ${lib}/${name} mates cleanly (0 facets of interference)" ;;
      empty:unreadable)
        # Ahead of empty:* on purpose. An STL that will not parse is a harness
        # or render fault, and reporting it as interference would send a reader
        # hunting a geometry bug that the measurement never actually saw.
        echo "FAIL  ${lib}/${name}: interference solid did not parse as a binary STL"
        echo "      This is a harness/render fault, NOT evidence that the pair"
        echo "      overlaps — the check never got a mesh to measure."
        fail=1 ;;
      empty:*)
        echo "FAIL  ${lib}/${name}: the pair INTERFERES — ${facets} facets of overlap"
        echo "      The male part does not go into the female part at its declared"
        echo "      clearance. Either the profile changed on one side only, or the"
        echo "      clearance derivation no longer matches the geometry it describes."
        fail=1 ;;
      interfering:0)
        echo "FAIL  ${lib}/${name}: expected interference, measured none"
        echo "      This case is the negative control: it exists to prove the check"
        echo "      above can fail. If a deliberately zero-clearance pair now reads"
        echo "      as mating cleanly, this harness is measuring nothing."
        fail=1 ;;
      interfering:unreadable)
        echo "FAIL  ${lib}/${name}: interference solid did not parse as a binary STL"
        fail=1 ;;
      interfering:*)
        echo "ok    ${lib}/${name} interferes as expected (${facets} facets) — the check can fail" ;;
    esac
  done < "$conf"

  # Both directions are required, and for the same reason. A manifest with no
  # `interfering` case never proves the harness can fail; a manifest with no
  # `empty` case never proves a declared fit assembles. Either one alone is a
  # suite that cannot say anything about the thing it is named after.
  if (( saw_negative == 0 )); then
    echo "FAIL  ${conf}: no 'interfering' case — nothing proves these fits can fail"
    fail=1
  fi
  if (( saw_positive == 0 )); then
    echo "FAIL  ${conf}: no 'empty' case — nothing proves this library's fit assembles"
    fail=1
  fi
done

if (( cases == 0 )); then
  echo "ok    no lib/*-mates.conf cases to check"
elif (( fail == 0 )); then
  echo "ok    ${cases} mate case(s) behave as declared"
fi

exit "$fail"
