#!/usr/bin/env bash
# Gate the style packs and any design that claims to follow one.
#   ./scripts/style-check.sh              # every style + every design with style.conf
#   ./scripts/style-check.sh <name>...    # named styles and/or designs
#
# For each style under styles/<name>/ this checks that:
#   1. style.scad is what style.json generates (no hand-edited token drift),
#   2. swatch.scad — the small part written in the style — renders, and
#   3. the swatch passes its own style's conformance rules.
#
# (3) is what keeps a style honest. A spec whose own swatch cannot satisfy it
# is not a design language, it is a wish; catching that here costs one small
# render, and catching it later costs somebody a design session.
#
# A design opts in by writing the style's name into designs/<name>/style.conf.
# Its printable parts (ci.parts-aware, like gate.sh) are then rendered and
# checked too, so "this design follows soft-utility" is a claim CI verifies
# rather than a sentence in a README.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build
# lib/ resolves `use <printability.scad>`; the repo root resolves
# `include <styles/<name>/style.scad>`.
export OPENSCADPATH="$PWD/lib:$PWD"

OPENSCAD_BIN="${OPENSCAD_BIN:-openscad}"
read -ra OSC_ARGS <<<"${OPENSCAD_ARGS:-}"

command -v stylelift >/dev/null || {
  echo "error: stylelift not on PATH — pip install -e tools/stylelift" >&2
  echo "       (or run .claude/hooks/session-start.sh --force)" >&2
  exit 2; }

fail=0
checked=0

render() {  # src out [-D...] -> 0/1, quiet on success
  local src="$1" out="$2"; shift 2
  local err
  if ! err="$(xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
      -o "$out" "$@" "$src" 2>&1)"; then
    tail -20 <<<"$err" >&2
    return 1
  fi
  return 0
}

# Failures set fail=1 and keep going (gate.sh does the same) so one broken
# style never hides the results of the styles after it.
check_style() {
  local name="$1"
  local dir="styles/${name}"
  echo "== style ${name} =="
  checked=$((checked + 1))

  local f
  for f in style.json STYLE.md swatch.scad; do
    if [[ ! -f "${dir}/${f}" ]]; then
      echo "FAIL  ${dir}/${f} is missing"
      fail=1
      return 0
    fi
  done

  if ! stylelift sync "$dir" --check; then
    fail=1
    return 0
  fi

  local stl="build/style-${name}-swatch.stl"
  if ! render "${dir}/swatch.scad" "$stl"; then
    echo "FAIL  ${name}: swatch.scad did not render"
    fail=1
    return 0
  fi

  # The swatch preview is a convenience, not a verdict: refreshing it needs
  # ImageMagick, and the gate's job — tokens in sync, swatch renders, swatch
  # obeys its own rules — does not. Skip it rather than failing a conformance
  # run over a missing image tool. The committed PNG's existence is checked by
  # scripts/docs-check.sh, which needs no tools at all.
  if command -v montage >/dev/null 2>&1; then
    mkdir -p "${dir}/previews"
    local pngs=() view label rot png
    for view in "iso:55,0,25" "top:0,0,0" "front:90,0,0" "bottom:235,0,55"; do
      label="${view%%:*}"; rot="${view#*:}"
      png="build/.swatch-${name}-${label}.png"
      if render "${dir}/swatch.scad" "$png" --imgsize=800,600 \
          --camera="0,0,0,${rot},140" --viewall --autocenter; then
        montage -label "$label" "$png" -geometry +0+0 -pointsize 24 "$png"
        pngs+=("$png")
      fi
    done
    if [[ ${#pngs[@]} -gt 0 ]]; then
      montage "${pngs[@]}" -tile 2x2 -geometry +2+2 "${dir}/previews/swatch.png"
      rm -f "${pngs[@]}"
    fi
  else
    echo "note  montage not installed — leaving ${dir}/previews/swatch.png as committed"
  fi

  if ! stylelift check "$stl" --style "$dir"; then
    echo "FAIL  ${name}: the style's own swatch does not satisfy its rules"
    fail=1
  fi
}

check_design() {
  local name="$1"
  local dir="designs/${name}"
  local style
  # `|| true`: grep exits 1 on a file with nothing but comments, and under
  # `set -e` that aborts the whole run with no output at all — a gate that
  # fails silently is worse than one that does not run.
  style="$(grep -vE '^[[:space:]]*(#|$)' "${dir}/style.conf" 2>/dev/null \
           | head -1 | tr -d '[:space:]' || true)"
  checked=$((checked + 1))
  if [[ -z "$style" ]]; then
    echo "== design ${name} =="
    echo "FAIL  ${dir}/style.conf names no style (it must contain one style name)"
    fail=1
    return 0
  fi
  echo "== design ${name} (style: ${style}) =="
  if [[ ! -f "styles/${style}/style.json" ]]; then
    echo "FAIL  ${dir}/style.conf names style '${style}', which does not exist"
    fail=1
    return 0
  fi

  # Same part enumeration as gate.sh: ci.parts when present, else the default
  # render of the entry file.
  local src="${dir}/${name}.scad" stls=() part stl
  if [[ -f "${dir}/ci.parts" ]]; then
    while read -r part; do
      [[ -z "$part" || "$part" == \#* ]] && continue
      stl="build/${name}-${part}.stl"
      if render "$src" "$stl" -D "part=\"${part}\""; then
        stls+=("$stl")
      else
        echo "FAIL  ${name} (part=${part}): render failed"
        fail=1
      fi
    done <"${dir}/ci.parts"
  else
    stl="build/${name}.stl"
    if render "$src" "$stl"; then
      stls+=("$stl")
    else
      echo "FAIL  ${name}: render failed"
      fail=1
    fi
  fi

  for stl in ${stls[@]+"${stls[@]}"}; do
    if ! stylelift check "$stl" --style "styles/${style}"; then
      fail=1
    fi
  done
}

names=()
for arg in "$@"; do
  case "$arg" in
    -*) echo "error: unknown flag $arg" >&2; exit 2 ;;
    *) names+=("$arg") ;;
  esac
done

if [[ ${#names[@]} -ge 1 ]]; then
  for name in "${names[@]}"; do
    if [[ -f "styles/${name}/style.json" ]]; then
      check_style "$name"
    elif [[ -f "designs/${name}/style.conf" ]]; then
      check_design "$name"
    else
      echo "FAIL  '${name}' is neither a style (styles/${name}/style.json) nor a"
      echo "      design declaring one (designs/${name}/style.conf)"
      fail=1
    fi
  done
else
  shopt -s nullglob
  for dir in styles/*/; do
    [[ -f "${dir}style.json" ]] || continue
    check_style "$(basename "$dir")"
  done
  for dir in designs/*/; do
    [[ -f "${dir}style.conf" ]] || continue
    check_design "$(basename "$dir")"
  done
fi

if [[ "$checked" == 0 ]]; then
  echo "no styles to check (styles/ is empty) — ./scripts/style-lift.sh <name> <ref.stl>"
fi
exit "$fail"
