#!/usr/bin/env bash
# Generate a tier-2 AI-restyled *lifestyle* shot for a design from a text
# prompt via the Z.AI GLM-Image API, size it to the product-shot budget, and
# embed it in the design's README with the canonical disclosure readme-gate
# requirement 9 demands (an "AI-styled scene" alt label and a "geometry is
# approximate" caption). The shot is COSMETIC and geometrically approximate —
# GLM-Image is text-to-image, so it renders an impression of the scene, not the
# real mesh; the studio product shot (tier 1) stays the geometry-true image.
# See .claude/skills/product-shots/SKILL.md (tier 2) and issue #66.
#
#   ZAI_KEY=... ./scripts/lifestyle-shot.sh <design>
#   ./scripts/lifestyle-shot.sh <design> --mock   # offline placeholder, no API
#
# Reads designs/<design>/lifestyle.conf ("<shot> | <prompt>" per line) and
# writes designs/<design>/previews/lifestyle-<shot>.png. Re-running is safe:
# the README embed is inserted only if it isn't there already. Meant to run in
# CI (.github/workflows/lifestyle-shot.yml) where ZAI_KEY is a repo secret;
# --mock lets the whole pipeline be exercised locally without a key.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/preview-budget.sh
. scripts/preview-budget.sh          # MAX_SHOT_BYTES

ZAI_MODEL="${ZAI_MODEL:-glm-image}"
ZAI_ENDPOINT="${ZAI_ENDPOINT:-https://api.z.ai/api/paas/v4/images/generations}"
ZAI_SIZE="${ZAI_SIZE:-1280x960}"

design="${1:-}"
mock=0
[[ "${2:-}" == "--mock" ]] && mock=1
if [[ -z "$design" ]]; then
  echo "usage: ZAI_KEY=... $0 <design> [--mock]" >&2
  exit 2
fi

conf="designs/${design}/lifestyle.conf"
if [[ ! -f "$conf" ]]; then
  echo "no ${conf} — nothing to generate" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# trim leading/trailing whitespace without touching interior spaces
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# Shrink an image (any format) to a stripped PNG that fits MAX_SHOT_BYTES,
# stepping the width down until it does. Photoreal 1280-wide PNGs can blow the
# 3 MiB budget, so this is not optional.
fit_budget() {
  local src="$1" out="$2" w=1280
  convert "$src" -strip "$out"
  while (( $(stat -c %s "$out") > MAX_SHOT_BYTES )) && (( w > 480 )); do
    w=$(( w * 85 / 100 ))
    convert "$src" -resize "${w}x" -strip "$out"
  done
}

generated=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  [[ -n "$(trim "$line")" ]] || continue
  shot="$(trim "${line%%|*}")"
  prompt="$(trim "${line#*|}")"
  if [[ -z "$shot" || -z "$prompt" || "$line" != *"|"* ]]; then
    echo "malformed lifestyle.conf line (want '<shot> | <prompt>'): $line" >&2
    exit 1
  fi

  outdir="designs/${design}/previews"
  mkdir -p "$outdir"
  out="${outdir}/lifestyle-${shot}.png"

  if (( mock )); then
    # Offline placeholder so the fit-to-budget, README-embed and gate steps are
    # testable without the API or a key. Never commit a --mock image.
    convert -size "$ZAI_SIZE" gradient:'#2b3a4a'-'#c98f5a' \
      -gravity center -pointsize 42 -fill white \
      -annotate 0 "MOCK lifestyle shot\n${design} / ${shot}\n(placeholder, not for commit)" \
      "$tmp/gen.png"
  else
    if [[ -z "${ZAI_KEY:-}" ]]; then
      echo "ZAI_KEY is not set — export it (CI: repo secret) or pass --mock" >&2
      exit 1
    fi
    local_req="$(python3 -c 'import json,sys; print(json.dumps({"model":sys.argv[1],"prompt":sys.argv[2],"size":sys.argv[3]}))' \
      "$ZAI_MODEL" "$prompt" "$ZAI_SIZE")"
    resp="$(curl -fsS -X POST "$ZAI_ENDPOINT" \
      -H "Authorization: Bearer ${ZAI_KEY}" \
      -H "Content-Type: application/json" \
      -d "$local_req")" || { echo "GLM-Image request failed" >&2; exit 1; }
    url="$(python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print(d["data"][0]["url"])
except Exception as e:
    sys.stderr.write("unexpected API response: %s\n" % sys.stdin.read()[:500]); raise' <<<"$resp")"
    curl -fsSL "$url" -o "$tmp/gen.img"
    convert "$tmp/gen.img" "$tmp/gen.png"
  fi

  fit_budget "$tmp/gen.png" "$out"
  echo "wrote ${out} ($(( ($(stat -c %s "$out") + 1023) / 1024 )) KiB)"
  generated+=("$shot")
done <"$conf"

# Insert the canonical disclosure embed into the README for each shot (only if
# it isn't already embedded), directly after the tier-1 hero image so the
# lifestyle shot sits beside the geometry-true one it augments.
readme="designs/${design}/README.md"
for shot in "${generated[@]}"; do
  DESIGN="$design" SHOT="$shot" README="$readme" python3 - <<'PY'
import os
design, shot, readme = os.environ["DESIGN"], os.environ["SHOT"], os.environ["README"]
rel = f"previews/lifestyle-{shot}.png"
hero = f"previews/{shot}.png"
block = (
    f"\n![AI-styled scene: {design} staged in a real-world setting]({rel})\n\n"
    "*AI-generated impression for general illustration only — geometry is "
    "approximate and may not exactly match the printed part; see the studio "
    "render above and the STL for the true shape.*\n"
)
text = open(readme, encoding="utf-8").read()
if f"]({rel})" in text:
    print(f"README already embeds {rel}")
    raise SystemExit(0)
lines = text.splitlines(keepends=True)
# insert after the paragraph containing the tier-1 hero embed, else after the
# first image embed, else append.
anchor = next((i for i, l in enumerate(lines) if f"]({hero})" in l), None)
if anchor is None:
    anchor = next((i for i, l in enumerate(lines) if l.lstrip().startswith("![")), None)
if anchor is None:
    out = text + block
else:
    out = "".join(lines[: anchor + 1]) + block + "".join(lines[anchor + 1 :])
open(readme, "w", encoding="utf-8").write(out)
print(f"embedded {rel} in {readme}")
PY
done
