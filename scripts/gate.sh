#!/usr/bin/env bash
# Render each design's printable STL(s) and gate them with printcheck
# (tools/printcheck — pip install -e tools/printcheck).
#   ./scripts/gate.sh                  # gate all designs under designs/
#   ./scripts/gate.sh <name>...        # gate one or more designs
#   ./scripts/gate.sh --slice [<name>...] # additionally test-slice each gated
#                                      # STL with PrusaSlicer (ground truth:
#                                      # slicing errors fail the gate; slicer
#                                      # warnings and print time are surfaced)
#
# Per-design config, all optional:
#   designs/<name>/ci.parts        one `part` value per line; each renders as
#                                  build/<name>-<part>.stl via -D part="..."
#                                  (without it, <name>.scad renders as-is —
#                                  use it when the default render is an
#                                  assembled preview, not the printable part)
#   designs/<name>/printcheck.args extra printcheck flags, e.g.
#                                  --build-volume 256x256x256 for designs
#                                  that target a larger printer
#   designs/<name>/<name>-coupon.scad  "print this first" coupon wrapper;
#                                  rendered as build/<name>-coupon.stl and
#                                  gated like any other part
#   designs/<name>/derives.conf    lineage of a derivative design: the
#                                  parent(s) it includes, the parent parts it
#                                  claims to replace, and any diamond-ok:
#                                  assertions (format: tools/lineage). Its
#                                  presence turns on derivative_gate below,
#                                  which proves each claimed override actually
#                                  changed the mesh and each base-safety claim
#                                  is true
set -euo pipefail

SLICE=0
names=()
for arg in "$@"; do
  case "$arg" in
    --slice) SLICE=1 ;;
    -*) echo "error: unknown flag $arg" >&2; exit 2 ;;
    *) names+=("$arg") ;;
  esac
done
if [[ "$SLICE" == 1 ]]; then
  command -v prusa-slicer >/dev/null || {
    echo "error: --slice needs prusa-slicer on PATH" >&2; exit 2; }
fi

cd "$(dirname "$0")/.."
mkdir -p build
# lib/ resolves `use <printability.scad>`; the repo root resolves
# `include <styles/<name>/style.scad>` (see scripts/style-lift.sh).
export OPENSCADPATH="$PWD/lib:$PWD"

# OPENSCAD_BIN selects the binary (e.g. openscad-nightly); OPENSCAD_ARGS
# passes extra flags (e.g. --backend=manifold — nightly-only, 2021.01 has
# no --backend). Both default to the stable invocation.
OPENSCAD_BIN="${OPENSCAD_BIN:-openscad}"
read -ra OSC_ARGS <<<"${OPENSCAD_ARGS:-}"

# Sourced, not re-implemented: lineage_render_binstl / lineage_mesh_hash /
# lineage_facet_count are the same functions `./scripts/lineage.sh selftest`
# exercises against known-good and known-broken fixtures, which is the only
# reason to believe derivative_gate below can still fire.
# shellcheck source=scripts/lineage.sh
source scripts/lineage.sh

fail=0

slice_one() {
  local stl="$1"
  local gcode="${stl%.stl}.gcode"
  echo "== test-slice ${stl} =="
  local out
  # --filament-density: without it PrusaSlicer emits "total filament used
  # [g] = 0.00" — the grams line the summary parses would silently read zero
  # for every part. 1.24 g/cm³ is PLA; the summary labels the assumption.
  if ! out=$(prusa-slicer --export-gcode -o "$gcode" \
      --layer-height 0.2 --nozzle-diameter 0.4 --filament-diameter 1.75 \
      --filament-density 1.24 \
      "$stl" 2>&1); then
    tail -20 <<<"$out"
    echo "FAIL  ${stl}: slicing failed"
    fail=1
    return 0
  fi
  grep -i "warning" <<<"$out" | sed 's/^/      /' || true
  grep -m1 "estimated printing time" "$gcode" | sed 's/^; */      /' || true
  grep -m1 "^; total filament used \[g\]" "$gcode" | sed 's/^; */      /' || true
}

# Derivative designs (those shipping a derives.conf) get two extra proofs.
# Both exist because OpenSCAD's override mechanism — `include <parent.scad>`,
# then redefine a module so the parent's own call sites route to your version —
# reports NOTHING when it fails to bind. Misspell the module you meant to
# replace and you get exit 0, no WARNING, no ERROR, and a watertight STL that
# printcheck scores 100/100: the parent's part, shipped under the derivative's
# name. The only difference between "override took" and "override was a typo"
# is the mesh itself, so the mesh is what gets compared.
#
# Every line printed here is machine-read by scripts/gate-summary.py into the
# sticky PR comment: keep the "<status>  derivative <name>: <kind> <subject> —
# <detail>" shape, and keep ` — ` out of <detail>, since that is the separator.
# Continuation lines are indented, which is what keeps the parser off them.
derivative_gate() {
  local name="$1"
  [[ -f "designs/${name}/derives.conf" ]] || return 0

  # A lineage check that quietly no-ops is the same failure class this gate was
  # built to catch, so an unrunnable CLI fails the design instead of skipping it.
  if [[ ! -x scripts/lineage.sh ]]; then
    echo "FAIL  derivative ${name}: derives.conf — scripts/lineage.sh is not executable, so no lineage claim can be checked"
    fail=1
    return 0
  fi

  echo "== ${name}: derivative checks =="
  # Its own directory rather than reusing build/<name>-<part>.stl: those are
  # written in whatever format the .stl extension implied, and a hash
  # comparison means nothing unless both sides came out of the same exporter.
  local outdir="build/.lineage"
  mkdir -p "$outdir"

  # claims counts what derives.conf actually asked to be proven and read_ok
  # records whether we managed to ask. Together they separate "this derivative
  # asserts nothing" — worth saying out loud, since a reader seeing a
  # derives.conf reasonably assumes the gate is holding it to something — from
  # "the assertions could not be read", which is a failure.
  local claims=0 read_ok=1

  local replaces parent part label slug dstl pstl dhash phash dfacets pfacets
  local dargs=()
  if ! replaces=$(./scripts/lineage.sh replaces "$name"); then
    echo "FAIL  derivative ${name}: derives.conf — reading its replaces: entries failed, see the lineage output above"
    read_ok=0
    fail=1
  else
    while IFS=$'\t' read -r parent part; do
      [[ -n "$parent" ]] || continue
      claims=$((claims + 1))
      label="${parent}:${part}"
      # An empty part means the parent's default render — no -D part= at all.
      if [[ -n "$part" ]]; then
        dargs=(-D "part=\"${part}\"")
        slug="$part"
      else
        dargs=()
        slug="default"
      fi
      if [[ ! -f "designs/${parent}/${parent}.scad" ]]; then
        echo "FAIL  derivative ${name}: override ${label} — designs/${parent}/${parent}.scad is missing, so there is no baseline to compare against"
        fail=1
        continue
      fi
      dstl="${outdir}/${name}--${slug}.stl"
      pstl="${outdir}/${parent}--${slug}.stl"
      if ! lineage_render_binstl "designs/${name}/${name}.scad" "$dstl" \
          ${dargs[@]+"${dargs[@]}"}; then
        echo "FAIL  derivative ${name}: override ${label} — the derivative's own render did not complete"
        fail=1
        continue
      fi
      if ! lineage_render_binstl "designs/${parent}/${parent}.scad" "$pstl" \
          ${dargs[@]+"${dargs[@]}"}; then
        echo "FAIL  derivative ${name}: override ${label} — the parent's render did not complete"
        fail=1
        continue
      fi
      dhash=$(lineage_mesh_hash "$dstl")
      phash=$(lineage_mesh_hash "$pstl")
      if [[ "$dhash" == "$phash" ]]; then
        echo "FAIL  derivative ${name}: override ${label} — the override did not take, the mesh is identical to the parent's"
        printf '      %s\n' \
          "Both sides hash to ${dhash}." \
          "That is what a redefinition binding nothing looks like from the outside:" \
          "OpenSCAD never mentions an override that matched no existing name, so the" \
          "part renders, slices and scores exactly as the parent's does." \
          "Check the module or variable designs/${name}/${name}.scad redefines against" \
          "the spelling in designs/${parent}/${parent}.scad, check the include line" \
          "actually names ${parent}, and check the redefinition sits after that include."
        fail=1
      else
        dfacets=$(lineage_facet_count "$dstl") || dfacets="?"
        pfacets=$(lineage_facet_count "$pstl") || pfacets="?"
        echo "ok    derivative ${name}: override ${label} — mesh differs from the parent (${pfacets} → ${dfacets} facets)"
      fi
    done <<<"$replaces"
  fi

  # diamond-ok: is a claim, not a fact. `include` is not guarded, so a diamond
  # evaluates the shared ancestor twice and unions its top-level geometry in
  # twice — cleanly, watertight, invisible to printcheck. The claim is only
  # true if the ancestor's entry point emits no geometry at all, and that is
  # cheap to check, so it gets checked rather than believed.
  local required ancestor astl facets
  if ! required=$(./scripts/lineage.sh base-safe-required "$name"); then
    echo "FAIL  derivative ${name}: derives.conf — reading its diamond-ok: entries failed, see the lineage output above"
    read_ok=0
    fail=1
  else
    while read -r ancestor; do
      [[ -n "$ancestor" ]] || continue
      claims=$((claims + 1))
      if [[ ! -f "designs/${ancestor}/${ancestor}.scad" ]]; then
        echo "FAIL  derivative ${name}: base-safe ${ancestor} — designs/${ancestor}/${ancestor}.scad is missing, so the claim cannot be proven"
        fail=1
        continue
      fi
      astl="${outdir}/${ancestor}--base-safe.stl"
      if ! lineage_render_binstl "designs/${ancestor}/${ancestor}.scad" "$astl"; then
        echo "FAIL  derivative ${name}: base-safe ${ancestor} — its entry point did not render, so the claim cannot be proven"
        fail=1
        continue
      fi
      if ! facets=$(lineage_facet_count "$astl"); then
        echo "FAIL  derivative ${name}: base-safe ${ancestor} — its export could not be read back, so the claim cannot be proven"
        fail=1
        continue
      fi
      if [[ "$facets" == 0 ]]; then
        echo "ok    derivative ${name}: base-safe ${ancestor} — its entry point emits no geometry"
      else
        echo "FAIL  derivative ${name}: base-safe ${ancestor} — its entry point emits ${facets} facets, so the diamond-ok claim is false"
        printf '      %s\n' \
          "Anything ${ancestor}'s top level draws lands in this design twice, and the" \
          "duplicate unions cleanly enough that no downstream check can see it." \
          "Split designs/${ancestor}/${ancestor}.scad into a geometry-free module" \
          "library plus a thin dispatcher that calls it, then re-assert diamond-ok."
        fail=1
      fi
    done <<<"$required"
  fi

  if (( read_ok && claims == 0 )); then
    echo "ok    derivative ${name}: derives.conf — records lineage only, with no replaces: or diamond-ok: entries for the gate to prove"
  fi
}

# Failures inside gate_one set fail=1 and keep going (matching how the
# printcheck step already aggregates) so one broken design never hides the
# results of the designs after it — gate_one always returns 0.
gate_one() {
  local name="$1"
  local src="designs/${name}/${name}.scad"
  if [[ ! -f "$src" ]]; then
    echo "FAIL  ${name}: ${src} not found"
    fail=1
    return 0
  fi

  local stls=()
  if [[ -f "designs/${name}/ci.parts" ]]; then
    local part
    # `|| [[ -n "$part" ]]`: without it a ci.parts whose last line has no
    # trailing newline loses that part from the gate entirely.
    while read -r part || [[ -n "$part" ]]; do
      [[ -z "$part" || "$part" == \#* ]] && continue
      local stl="build/${name}-${part}.stl"
      echo "== ${name} (part=${part}): render =="
      if ! xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
          -o "$stl" -D "part=\"${part}\"" "$src"; then
        echo "FAIL  ${name} (part=${part}): render failed"
        fail=1
        continue
      fi
      stls+=("$stl")
    done < "designs/${name}/ci.parts"
  else
    echo "== ${name}: render =="
    if ! xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
        -o "build/${name}.stl" "$src"; then
      echo "FAIL  ${name}: render failed"
      fail=1
      return 0
    fi
    stls+=("build/${name}.stl")
  fi

  # "Print this first" coupon wrapper (repo convention, see CLAUDE.md): a
  # ≤10-line include-and-override wrapper on the production modules. It is
  # the first STL a user prints, so it gets the same printcheck + test-slice
  # treatment as the parts it stands in for.
  local coupon="designs/${name}/${name}-coupon.scad"
  if [[ -f "$coupon" ]]; then
    local coupon_stl="build/${name}-coupon.stl"
    echo "== ${name} (coupon): render =="
    if ! xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
        -o "$coupon_stl" "$coupon"; then
      echo "FAIL  ${name} (coupon): render failed"
      fail=1
    else
      stls+=("$coupon_stl")
    fi
  fi

  local args=()
  if [[ -f "designs/${name}/printcheck.args" ]]; then
    # Word-splitting the flag file is intended; `|| true` keeps set -e from
    # aborting on a comment-only file.
    # shellcheck disable=SC2207
    args=($(grep -vE '^(#|$)' "designs/${name}/printcheck.args" || true))
  fi
  local stl
  for stl in ${stls[@]+"${stls[@]}"}; do
    echo "== ${name}: printcheck ${stl} =="
    if ! printcheck "$stl" ${args[@]+"${args[@]}"}; then
      fail=1
    fi
    if [[ "$SLICE" == 1 ]]; then
      slice_one "$stl"
    fi
  done

  # Last, so the printcheck rows above stay one contiguous block in the log
  # and in the summary table. A no-op for every design without a derives.conf.
  derivative_gate "$name"
}

if [[ ${#names[@]} -ge 1 ]]; then
  for name in "${names[@]}"; do
    gate_one "$name"
  done
else
  found=0
  for dir in designs/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    [[ -f "designs/${name}/${name}.scad" ]] || continue
    found=1
    gate_one "$name"
  done
  if [[ "$found" -eq 0 ]]; then
    echo "no designs found under designs/"
  fi
fi

exit "$fail"
