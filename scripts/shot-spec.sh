#!/usr/bin/env bash
# Author a design's product-shot manifests from a PM's art-direction brief,
# without hand-writing the syntax. This is the mechanics half of the
# /art-direction skill: the PM (via the skill) picks a named *view* and a
# named *color*; this script owns the camera math, the hex, the freeze rule,
# and the exact README embed — so a creative request never turns into a
# pipe-delimited line typed by hand.
#
#   ./scripts/shot-spec.sh views                       # named framing presets
#   ./scripts/shot-spec.sh palette                     # named filament colors
#   ./scripts/shot-spec.sh add <design> <shot> [opts]  # -> shots.conf (tier 1)
#   ./scripts/shot-spec.sh lifestyle <design> <shot> --scene '...'  # tier 2
#   ./scripts/shot-spec.sh embed <design> <shot> [--lifestyle]      # README block
#   ./scripts/shot-spec.sh check <design>              # validate manifests
#   ./scripts/shot-spec.sh --selftest
#
# What it deliberately does NOT do: touch README.md, or render anything. The
# skill places the embed with framing judgment, and CI renders the PNGs
# (scripts/product-shot.sh for tier 1, the lifestyle workflow for tier 2). The
# division of labor mirrors product-shots/SKILL.md: you own the manifest and the
# embed; CI owns the pixels.
#
# Standards this enforces so the PM never has to remember them:
#   * Freeze policy — `add`/`lifestyle` REFUSE to touch an existing entry of the
#     same name (shots are fixed across review rounds; add a new one, never move
#     one). See CLAUDE.md "Frozen preview cameras".
#   * Tier-1 shape — a studio shot is geometry-true and its scene is fixed, so
#     the only creative levers are pose (a -D define), color, finish, framing.
#     Scenery/staging lives in tier 2, which is why `lifestyle` is a separate
#     verb and emits the disclosure readme-gate requirement 9 demands.
#   * Well-formedness — finish in the known set, color a known name or #rrggbb,
#     camera a numeric rotz,elev,zoom, size a sane WxH. `check` re-runs all of
#     these on the committed manifests before CI ever spins up a renderer.
set -euo pipefail

cd "$(dirname "$0")/.."

# The design tree to operate on. Overridable so --selftest can point every
# subcommand at a throwaway fixture tree without touching the real designs/
# (mirrors readme-gate.sh's READMEGATE_DESIGNS_DIR). Defaults to designs/.
ROOT="${SHOTSPEC_DESIGNS_DIR:-designs}"

# ---- vocabularies -----------------------------------------------------------
# Named framing presets: rotz,elev,zoom (the tuple scripts/product-shot.sh and
# tools/photoshot/photoshot.py consume). rotz/elev orbit the grounded model in
# degrees; zoom scales an automatic bounding-box fit (1.0 = snug, <1 pulls back,
# >1 crops in), so a preset means the same framing on any design's size. These
# are the product-photography angles product-shots/SKILL.md recommends, named so
# a brief can say "top" instead of "0,80,0.95".
VIEWS=(
  "hero:35,18,0.90"          # the lead three-quarter product shot
  "hero-tall:35,14,0.92"     # same, framed for a tall part (e.g. an instrument)
  "three-quarter:28,24,0.85" # higher three-quarter, more of the top face
  "front:0,8,0.90"           # straight-on elevation
  "top:0,80,0.95"            # near top-down, for grids/trays/flat parts
  "low:40,6,0.92"            # dramatic low angle, hero of a tall silhouette
  "detail:45,20,1.25"        # crop in on one feature
)

# Named filament colors -> #rrggbb (product-shot.sh wants the hex WITHOUT '#',
# which this script strips when it writes the manifest line). Plausible, varied
# filament tones so pages across the repo don't all look alike; pass a raw
# #rrggbb to --color for anything not here.
PALETTE=(
  "charcoal:3a3f4a" "graphite:4a4f57" "slate:5b6b7a" "black:222831"
  "ivory:e8e2d0" "sand:c9b48a"
  "orange:e8734a" "amber:d98a3d" "crimson:b5384a" "rust:9c5a3c"
  "forest:3a6b46" "sage:8a9a5b" "teal:2a8a8a"
  "sky:4a7fb5" "navy:2f3f66" "plum:6a4a9a"
)

FINISHES="satin gloss matte"

# largest sensible per-side pixel dimension. The real ceiling is the byte
# budget (scripts/preview-budget.sh, enforced at render and by readme-gate), but
# that can't be known before the render exists; this catches the fat-finger
# 12800x9600 that would blow it, while leaving normal 1100..1600 sizes alone.
MAX_DIM=2400

die() { echo "error: $*" >&2; exit 1; }

# kebab-case, the repo convention for design and shot names. Same shape
# product-shot.sh's <shot> and lifestyle-shot.sh validate against.
is_kebab() { [[ "$1" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; }

lookup() {  # lookup <name> <table-array-name...> ; echoes value or empty
  local want="$1"; shift
  local -n tbl="$1"
  local kv
  for kv in "${tbl[@]}"; do
    [[ "${kv%%:*}" == "$want" ]] && { printf '%s' "${kv#*:}"; return 0; }
  done
  return 1
}

resolve_color() {  # name or #rrggbb / rrggbb -> rrggbb (no '#'), or die
  local c="$1" hex
  if hex="$(lookup "$c" PALETTE)"; then printf '%s' "$hex"; return; fi
  c="${c#\#}"
  [[ "$c" =~ ^[0-9a-fA-F]{6}$ ]] || die "unknown color '$1' — see 'palette', or pass a #rrggbb"
  printf '%s' "$c"
}

resolve_view() {  # view name -> rotz,elev,zoom, or die
  local cam
  cam="$(lookup "$1" VIEWS)" || die "unknown view '$1' — see 'views', or pass --camera rotz,elev,zoom"
  printf '%s' "$cam"
}

valid_camera() {  # rotz,elev,zoom, each a finite number
  local r e z rest
  IFS=',' read -r r e z rest <<<"$1"
  [[ -z "$rest" && -n "$r" && -n "$e" && -n "$z" ]] || return 1
  local n
  for n in "$r" "$e" "$z"; do
    [[ "$n" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || return 1
  done
  # zoom scales a fit; zero or negative is meaningless.
  awk -v z="$z" 'BEGIN{exit !(z>0)}'
}

valid_size() {  # WxH, both positive ints within a sane ceiling
  local w h rest
  IFS='x' read -r w h rest <<<"${1,,}"
  [[ -z "$rest" && "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] || return 1
  (( w >= 4 && h >= 4 && w <= MAX_DIM && h <= MAX_DIM ))
}

# ---- subcommands ------------------------------------------------------------
cmd_views() {
  echo "Named framing presets (rotz,elev,zoom):"
  local kv
  for kv in "${VIEWS[@]}"; do printf '  %-14s %s\n' "${kv%%:*}" "${kv#*:}"; done
  echo "Pass --camera rotz,elev,zoom for a custom angle."
}

cmd_palette() {
  echo "Named filament colors (#rrggbb):"
  local kv
  for kv in "${PALETTE[@]}"; do printf '  %-10s #%s\n' "${kv%%:*}" "${kv#*:}"; done
  echo "Pass --color '#rrggbb' for a custom color."
}

# Print the tier-1 README embed for a shot. Alt text names the color/finish so
# the page is descriptive (readme-gate wants the embed present; the alt is the
# skill's to refine).
embed_tier1() {  # <design> <shot> <color-name-or-hex> <finish>
  printf '![Product shot: %s in %s %s](previews/%s.png)\n' \
    "$1" "$3" "$4" "$2"
}

# Print the canonical tier-2 disclosure block VERBATIM — the exact structure
# readme-gate requirement 9 keys on (an "AI-styled scene" alt label plus a
# "geometry is approximate" caption in the paragraph directly below). Copying it
# from here is what keeps a lifestyle shot from ever landing undisclosed.
embed_lifestyle() {  # <design> <shot>
  printf '![AI-styled scene: %s staged in a real-world setting](previews/lifestyle-%s.png)\n\n' \
    "$1" "$2"
  printf '*AI-generated impression for general illustration only — geometry is '
  printf 'approximate and may not exactly match the printed part; see the studio '
  printf 'render above and the STL for the true shape.*\n'
}

# Does a manifest already carry an entry named <shot>? (first pipe field,
# comments/blank ignored). This is the freeze guard.
manifest_has() {  # <conf> <shot>
  local conf="$1" want="$2" line name
  [[ -f "$conf" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    [[ "$line" =~ [^[:space:]] ]] || continue
    IFS='|' read -r name _ <<<"$line"
    name="${name//[[:space:]]/}"
    [[ "$name" == "$want" ]] && return 0
  done <"$conf"
  return 1
}

cmd_add() {
  local design="${1:-}" shot="${2:-}"; shift $(( $# >= 2 ? 2 : $# ))
  [[ -n "$design" && -n "$shot" ]] || die "usage: add <design> <shot> [--view N|--camera R,E,Z] [--color C] [--finish F] [--pose 'def'] [--size WxH] [--dry-run]"
  local view="hero" camera="" color="orange" finish="satin" pose="" size="1280x960" dry=0
  while (( $# )); do
    case "$1" in
      --view)    view="${2:?}"; shift 2;;
      --camera)  camera="${2:?}"; shift 2;;
      --color)   color="${2:?}"; shift 2;;
      --finish)  finish="${2:?}"; shift 2;;
      --pose)    pose="${2:?}"; shift 2;;
      --size)    size="${2:?}"; shift 2;;
      --dry-run) dry=1; shift;;
      *) die "unknown option '$1' to add";;
    esac
  done

  [[ -d "$ROOT/$design" ]] || die "no $ROOT/$design"
  is_kebab "$shot" || die "shot name '$shot' must be kebab-case ([a-z0-9-])"
  is_kebab "$design" || die "design name '$design' must be kebab-case"
  [[ " $FINISHES " == *" $finish "* ]] || die "unknown finish '$finish' — one of: $FINISHES"
  valid_size "$size" || die "bad size '$size' — want WxH (each 4..$MAX_DIM px)"

  local hex; hex="$(resolve_color "$color")"
  [[ -z "$camera" ]] && camera="$(resolve_view "$view")"
  valid_camera "$camera" || die "bad camera '$camera' — want rotz,elev,zoom (zoom>0)"

  # The pose is a raw -D payload passed to OpenSCAD (e.g. part="assembled"). A
  # space would split it into two defines the manifest can't represent per its
  # single-field grammar, so reject an interior space rather than emit a line
  # product-shot.sh will misparse. Multiple defines are legal in the file, but
  # this convenience writes one; hand-edit for more and re-run `check`.
  if [[ -n "$pose" && "$pose" == *" "* ]]; then
    die "pose '$pose' has a space — one define per shot here (e.g. part=\"assembled\"); hand-edit shots.conf for multiple"
  fi

  local conf="$ROOT/$design/shots.conf"
  if manifest_has "$conf" "$shot"; then
    die "shots.conf already has an entry '$shot' — shots are frozen across review rounds; pick a new name instead of moving it (CLAUDE.md: Frozen preview cameras)"
  fi

  local line="$shot | $hex | $finish | $camera | $size"
  [[ -n "$pose" ]] && line="$line | $pose"

  if (( dry )); then
    echo "# would append to $conf:"
    echo "$line"
  else
    if [[ ! -f "$conf" ]]; then
      echo "# Studio product shots for the product page (scripts/product-shot.sh)." >"$conf"
      echo "# name | color | finish | camera(rotz,elev,zoom) | size | defines" >>"$conf"
    fi
    printf '%s\n' "$line" >>"$conf"
    echo "wrote entry '$shot' to $conf"
  fi
  echo
  echo "Embed this near the top of $ROOT/$design/README.md (above the contact sheet):"
  embed_tier1 "$design" "$shot" "$color" "$finish"
}

cmd_lifestyle() {
  local design="${1:-}" shot="${2:-}"; shift $(( $# >= 2 ? 2 : $# ))
  [[ -n "$design" && -n "$shot" ]] || die "usage: lifestyle <design> <shot> --scene '...' [--dry-run]"
  local scene="" dry=0
  while (( $# )); do
    case "$1" in
      --scene)   scene="${2:?}"; shift 2;;
      --dry-run) dry=1; shift;;
      *) die "unknown option '$1' to lifestyle";;
    esac
  done
  [[ -d "$ROOT/$design" ]] || die "no $ROOT/$design"
  is_kebab "$shot" || die "shot name '$shot' must be kebab-case ([a-z0-9-])"
  [[ -n "$scene" ]] || die "a lifestyle shot needs --scene '<describe the setting>' (text-to-image: describe the scene, not fake geometry)"
  # A '#' in the scene would be read as a comment by lifestyle-shot.sh's
  # full-line rule only at line start, but the manifest is '<shot> | <prompt>'
  # and a literal newline can't live in one line — reject it early with a clear
  # message rather than writing a broken second line.
  [[ "$scene" != *$'\n'* ]] || die "scene must be a single line"

  local conf="$ROOT/$design/lifestyle.conf"
  if manifest_has "$conf" "$shot"; then
    die "lifestyle.conf already has an entry '$shot' — add a new scene name instead of moving one"
  fi

  local line="$shot | $scene"
  if (( dry )); then
    echo "# would append to $conf:"
    echo "$line"
  else
    if [[ ! -f "$conf" ]]; then
      echo "# Tier-2 AI lifestyle-shot prompts (scripts/lifestyle-shot.sh) — one" >"$conf"
      echo "# '<shot> | <prompt>' per line. COSMETIC and text-to-image, so the" >>"$conf"
      echo "# geometry is only an impression; readme-gate forces the disclosure." >>"$conf"
    fi
    printf '%s\n' "$line" >>"$conf"
    echo "wrote scene '$shot' to $conf"
  fi
  echo
  echo "Embed this in $ROOT/$design/README.md, directly below the tier-1 hero (VERBATIM — the disclosure is gated):"
  embed_lifestyle "$design" "$shot"
}

cmd_embed() {
  local design="${1:-}" shot="${2:-}"; shift $(( $# >= 2 ? 2 : $# ))
  [[ -n "$design" && -n "$shot" ]] || die "usage: embed <design> <shot> [--lifestyle]"
  if [[ "${1:-}" == "--lifestyle" ]]; then
    embed_lifestyle "$design" "$shot"
  else
    # Recover the color/finish from the manifest so the alt text is accurate.
    local conf="$ROOT/$design/shots.conf" line name color finish
    local col="a printed part" fin=""
    if [[ -f "$conf" ]]; then
      while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"; [[ "$line" =~ [^[:space:]] ]] || continue
        IFS='|' read -r name color finish _ <<<"$line"
        name="${name//[[:space:]]/}"
        [[ "$name" == "$shot" ]] || continue
        col="#${color//[[:space:]]/}"; fin="${finish//[[:space:]]/}"
        break
      done <"$conf"
    fi
    embed_tier1 "$design" "$shot" "$col" "$fin"
  fi
}

# Validate a design's manifests against the standards BEFORE CI renders. This is
# the complement to readme-gate (which is presence-only, and runs post-render):
# it catches a malformed line while it is still cheap to fix, and it is what the
# --selftest exercises.
check_shots() {  # <conf> ; sets rc via `bad`
  local conf="$1" line name color finish camera size
  [[ -f "$conf" ]] || return 0
  local n=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n+1))
    line="${line%%#*}"; [[ "$line" =~ [^[:space:]] ]] || continue
    # trailing `_` absorbs the optional defines field; it is not validated here
    # (product-shot.sh owns -D parsing), so it is intentionally unused.
    IFS='|' read -r name color finish camera size _ <<<"$line"
    name="${name//[[:space:]]/}"; color="${color//[[:space:]]/}"
    finish="${finish//[[:space:]]/}"; camera="${camera//[[:space:]]/}"
    size="${size//[[:space:]]/}"
    if [[ -z "$name" || -z "$color" || -z "$finish" || -z "$camera" || -z "$size" ]]; then
      echo "  FAIL $conf:$n — need 'name | color | finish | camera | size [| defines]'"; bad=1; continue
    fi
    is_kebab "$name"                || { echo "  FAIL $conf:$n — shot name '$name' not kebab-case"; bad=1; }
    [[ "$color" =~ ^[0-9a-fA-F]{6}$ ]] || { echo "  FAIL $conf:$n — color '$color' is not rrggbb (no '#')"; bad=1; }
    [[ " $FINISHES " == *" $finish "* ]] || { echo "  FAIL $conf:$n — finish '$finish' not one of: $FINISHES"; bad=1; }
    valid_camera "$camera"          || { echo "  FAIL $conf:$n — camera '$camera' not rotz,elev,zoom (zoom>0)"; bad=1; }
    valid_size "$size"              || { echo "  FAIL $conf:$n — size '$size' not a sane WxH"; bad=1; }
  done <"$conf"
}

check_lifestyle() {  # <conf>
  local conf="$1" line shot prompt
  [[ -f "$conf" ]] || return 0
  local n=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n+1))
    # Full-line comments only (a '#' can be scene content), matching
    # lifestyle-shot.sh.
    local trimmed="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$trimmed" || "$trimmed" == '#'* ]] && continue
    [[ "$line" == *"|"* ]] || { echo "  FAIL $conf:$n — want '<shot> | <prompt>'"; bad=1; continue; }
    shot="${line%%|*}"; shot="${shot//[[:space:]]/}"
    prompt="${line#*|}"; prompt="${prompt#"${prompt%%[![:space:]]*}"}"; prompt="${prompt%"${prompt##*[![:space:]]}"}"
    is_kebab "$shot" || { echo "  FAIL $conf:$n — scene name '$shot' not kebab-case"; bad=1; }
    [[ -n "$prompt" ]] || { echo "  FAIL $conf:$n — empty scene prompt"; bad=1; }
  done <"$conf"
}

cmd_check() {
  local design="${1:-}"
  [[ -n "$design" ]] || die "usage: check <design>"
  [[ -d "$ROOT/$design" ]] || die "no $ROOT/$design"
  local bad=0
  check_shots "$ROOT/$design/shots.conf"
  check_lifestyle "$ROOT/$design/lifestyle.conf"
  if (( bad )); then
    echo "FAIL  $design: manifest problems above"
    return 1
  fi
  echo "ok    $design: shot manifests well-formed"
}

# ---- selftest ---------------------------------------------------------------
# Prove every validation and the freeze guard still fire. The repo's rule (see
# guard-check.sh, mate-check.sh, readme-gate --selftest): a check that guards
# something ships a firing negative test, because a weakened guard leaves every
# other check green. Wired into scripts/check.sh.
run_selftest() {
  local tmp; tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  local pass=1
  local root="$tmp/designs"
  mkdir -p "$root/gadget"

  # Every subcommand reads its design tree from SHOTSPEC_DESIGNS_DIR, so point it
  # at the fixture and the file-writing verbs land in $tmp, never the real tree.
  _run() {  # _run <expect-rc> <needle-or-empty> -- <args...>
    local want="$1" needle="$2"; shift 2; [[ "$1" == "--" ]] && shift
    local out rc=0
    out="$( SHOTSPEC_DESIGNS_DIR="$root" "$SELF" "$@" 2>&1 )" || rc=$?
    if [[ "$rc" != "$want" ]]; then
      echo "SELFTEST FAIL: [$*] expected rc $want got $rc"; sed 's/^/    /' <<<"$out"; pass=0; return
    fi
    if [[ -n "$needle" ]] && ! grep -qF "$needle" <<<"$out"; then
      echo "SELFTEST FAIL: [$*] output missing '$needle'"; sed 's/^/    /' <<<"$out"; pass=0; return
    fi
    echo "selftest ok    [$*] ${needle:+($needle)}"
  }

  # vocab commands work
  _run 0 "hero"   -- views
  _run 0 "forest" -- palette

  # add: happy path writes a valid line
  _run 0 "wrote entry" -- add gadget product-hero --view hero --color forest --finish satin --pose 'part="assembled"'
  if ! grep -qE '^product-hero \| 3a6b46 \| satin \| 35,18,0.90 \| 1280x960 \| part="assembled"$' "$tmp/designs/gadget/shots.conf"; then
    echo "SELFTEST FAIL: add did not write the expected manifest line"; sed 's/^/    /' "$tmp/designs/gadget/shots.conf"; pass=0
  else echo "selftest ok    add wrote the expected line"; fi

  # freeze: re-adding the same name refuses
  _run 1 "already has an entry" -- add gadget product-hero --view top --color amber
  # bad finish / view / color / size all refuse
  _run 1 "unknown finish" -- add gadget b --finish shiny
  _run 1 "unknown view"   -- add gadget b --view sideways
  _run 1 "unknown color"  -- add gadget b --color mauve
  _run 1 "bad size"       -- add gadget b --size 99999x10
  _run 1 "has a space"    -- add gadget b --pose 'part="a" show="b"'
  # custom camera + hex color accepted
  _run 0 "wrote entry" -- add gadget top-down --camera 0,80,0.95 --color '#123456'

  # lifestyle: happy path + disclosure emitted + freeze + empty-scene refusal
  _run 0 "geometry is approximate" -- lifestyle gadget product-hero --scene "on a workbench under warm light"
  _run 1 "already has an entry"    -- lifestyle gadget product-hero --scene "again"
  _run 1 "needs --scene"           -- lifestyle gadget nostory

  # check: passes on the good tree
  _run 0 "well-formed" -- check gadget

  # check: fails on a hand-corrupted line (bad finish, bad camera)
  printf 'busted | 3a6b46 | neon | 35,x,0.9 | 1280x960\n' >>"$tmp/designs/gadget/shots.conf"
  _run 1 "FAIL" -- check gadget

  if (( pass )); then echo "ok    shot-spec --selftest: every validator and the freeze guard fire"; return 0; fi
  echo "FAIL  shot-spec --selftest"; return 1
}

# Absolute path to self so --selftest can invoke subcommands from the fixture CWD.
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

case "${1:-}" in
  views)      shift; cmd_views "$@";;
  palette)    shift; cmd_palette "$@";;
  add)        shift; cmd_add "$@";;
  lifestyle)  shift; cmd_lifestyle "$@";;
  embed)      shift; cmd_embed "$@";;
  check)      shift; cmd_check "$@";;
  --selftest) run_selftest;;
  ""|-h|--help)
    sed -n '2,40p' "$SELF" | sed 's/^# \{0,1\}//'
    ;;
  *) die "unknown command '$1' — try: views, palette, add, lifestyle, embed, check, --selftest";;
esac
