#!/usr/bin/env bash
# Lift a design style out of reference mesh(es) into styles/<name>/.
#   ./scripts/style-lift.sh <name> <reference.stl>...
#   ./scripts/style-lift.sh <name> <ref.stl> --source <url> --license <terms>
#                                  # record where the reference came from
#   ./scripts/style-lift.sh <name> <reference.stl>... --force
#                                  # overwrite an existing style.json/STYLE.md
#   ./scripts/style-lift.sh --list # show the styles this repo ships
#
# Writes (see tools/stylelift):
#   styles/<name>/style.json  measured evidence + tokens + conformance rules
#   styles/<name>/style.scad  GENERATED from style.json — the numbers a design
#                             includes and builds with
#   styles/<name>/STYLE.md    the spec a human or an agent reads (draft: the
#                             prose and the do/don't list are written by hand)
#   build/style-<name>-reference.png   4-view contact sheet of the reference
#
# The reference contact sheet lands in build/ (gitignored) on purpose: a
# reference mesh is usually somebody else's work, and a render of it is a
# derivative. Look at it, describe what you see in STYLE.md, and commit a
# render of the style's own swatch.scad instead — that geometry is ours.
#
# After lifting, the pack is a DRAFT. Finish it: write the prose, decide which
# measured numbers are actually the family's rules, add swatch.scad, then
# ./scripts/style-check.sh <name>. See .claude/skills/style-spec/SKILL.md.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build
# lib/ resolves `use <printability.scad>`; the repo root resolves
# `include <styles/<name>/style.scad>`.
export OPENSCADPATH="$PWD/lib:$PWD"

OPENSCAD_BIN="${OPENSCAD_BIN:-openscad}"
read -ra OSC_ARGS <<<"${OPENSCAD_ARGS:-}"

list_styles() {
  local found=0 dir name
  for dir in styles/*/; do
    [[ -f "${dir}style.json" ]] || continue
    found=1
    name="$(basename "$dir")"
    printf '%-24s %s\n' "$name" \
      "$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); \
         print(d.get('summary') or d.get('title') or '')" "${dir}style.json")"
  done
  [[ "$found" == 1 ]] || echo "no styles yet — ./scripts/style-lift.sh <name> <ref.stl>"
}

if [[ "${1:-}" == "--list" ]]; then
  list_styles
  exit 0
fi

FORCE=()
EXTRA=()
NAME=""
refs=()
expect=""
for arg in "$@"; do
  if [[ -n "$expect" ]]; then
    EXTRA+=("$expect" "$arg"); expect=""; continue
  fi
  case "$arg" in
    --force) FORCE=(--force) ;;
    # passed through to `stylelift lift` so provenance records where the
    # reference came from and what it is licensed as
    --source|--license|--title|--summary) expect="$arg" ;;
    --source=*|--license=*|--title=*|--summary=*)
      EXTRA+=("${arg%%=*}" "${arg#*=}") ;;
    -*) echo "error: unknown flag $arg" >&2; exit 2 ;;
    *)
      if [[ -z "$NAME" ]]; then NAME="$arg"; else refs+=("$arg"); fi ;;
  esac
done
if [[ -n "$expect" ]]; then
  echo "error: $expect needs a value" >&2; exit 2
fi

if [[ -z "$NAME" || ${#refs[@]} -eq 0 ]]; then
  echo "usage: ./scripts/style-lift.sh <name> <reference.stl>... [--force]" >&2
  exit 2
fi
if [[ ! "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "error: style name must be kebab-case (got '$NAME')" >&2
  exit 2
fi
command -v stylelift >/dev/null || {
  echo "error: stylelift not on PATH — pip install -e tools/stylelift" >&2
  echo "       (or run .claude/hooks/session-start.sh --force)" >&2
  exit 2; }

for ref in "${refs[@]}"; do
  [[ -f "$ref" ]] || { echo "error: reference '$ref' not found" >&2; exit 2; }
done

echo "== lifting style '${NAME}' from ${#refs[@]} reference(s) =="
stylelift lift "${refs[@]}" --name "$NAME" --out "styles/${NAME}" \
  ${EXTRA[@]+"${EXTRA[@]}"} ${FORCE[@]+"${FORCE[@]}"}

# Contact sheet of the primary reference so the session can actually look at
# the thing it just measured. Rendered through OpenSCAD's import() so this
# needs no extra viewer in the toolchain.
primary="${refs[0]}"
wrapper="build/.style-ref-${NAME}.scad"
printf 'import("%s");\n' "$(realpath "$primary")" >"$wrapper"
pngs=()
err=""
for view in "iso:55,0,25" "top:0,0,0" "front:90,0,0" "bottom:235,0,55"; do
  label="${view%%:*}"; rot="${view#*:}"
  png="build/.style-ref-${NAME}-${label}.png"
  # OpenSCAD narrates the render on stdout; keep it out of the script's own
  # output and surface it only if the render actually fails.
  if err="$(xvfb-run -a "$OPENSCAD_BIN" ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
      -o "$png" --imgsize=800,600 --camera="0,0,0,${rot},140" \
      --viewall --autocenter "$wrapper" 2>&1)"; then
    montage -label "$label" "$png" -geometry +0+0 -pointsize 24 "$png"
    pngs+=("$png")
  else
    echo "warning: reference view '${label}' did not render" >&2
    tail -5 <<<"$err" >&2
  fi
done
if [[ ${#pngs[@]} -gt 0 ]]; then
  montage "${pngs[@]}" -tile 2x2 -geometry +2+2 "build/style-${NAME}-reference.png"
  rm -f "${pngs[@]}"
  echo "  wrote build/style-${NAME}-reference.png (look at it before writing the prose)"
fi
rm -f "$wrapper"

cat <<EOF

Next:
  1. Look at build/style-${NAME}-reference.png and read styles/${NAME}/STYLE.md.
  2. Write the prose and prune the rules in styles/${NAME}/style.json to the
     ones that really define the family, then:  stylelift sync styles/${NAME}
  3. Write styles/${NAME}/swatch.scad — a small part in this style — and:
       ./scripts/style-check.sh ${NAME}
EOF
