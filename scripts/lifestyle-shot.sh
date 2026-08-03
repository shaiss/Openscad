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
ZAI_SIZE="${ZAI_SIZE:-1280x1280}"   # a size the GLM-Image docs show in examples

design="${1:-}"
mock=0
[[ "${2:-}" == "--mock" ]] && mock=1
if [[ -z "$design" ]]; then
  echo "usage: ZAI_KEY=... $0 <design> [--mock]" >&2
  exit 2
fi
# The design name is interpolated into paths (designs/<design>/...); pin it to
# the repo's kebab-case convention so a stray "../" or a space can't write or
# edit outside the design directory.
if [[ ! "$design" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "invalid design name '${design}' — must be kebab-case ([a-z0-9-])" >&2
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
# 3 MiB budget, so this is not optional. The ">" on -resize means "only shrink,
# never enlarge", so a small source is never upscaled. Fails (rather than
# silently shipping an over-budget file) if it can't be met.
fit_budget() {
  local src="$1" out="$2" w=1280
  convert "$src" -resize "${w}x>" -strip "$out"
  while (( $(stat -c %s "$out") > MAX_SHOT_BYTES )) && (( w > 480 )); do
    w=$(( w * 85 / 100 ))
    convert "$src" -resize "${w}x>" -strip "$out"
  done
  if (( $(stat -c %s "$out") > MAX_SHOT_BYTES )); then
    echo "could not fit ${out} under $((MAX_SHOT_BYTES / 1024 / 1024)) MiB (down to ${w}px wide)" >&2
    return 1
  fi
}

generated=()
while IFS= read -r line || [[ -n "$line" ]]; do
  # Full-line comments and blank lines only — a '#' inside a prompt is content
  # (a scene may legitimately say "buoy #3"), so do not strip inline.
  trimmed="$(trim "$line")"
  [[ -z "$trimmed" || "$trimmed" == '#'* ]] && continue
  shot="$(trim "${line%%|*}")"
  prompt="$(trim "${line#*|}")"
  if [[ -z "$shot" || -z "$prompt" || "$line" != *"|"* ]]; then
    echo "malformed lifestyle.conf line (want '<shot> | <prompt>'): $line" >&2
    exit 1
  fi
  # <shot> becomes the filename stem (lifestyle-<shot>.png) and part of the
  # README embed URL — pin it to kebab-case so it can't escape previews/ or
  # produce a broken markdown link.
  if [[ ! "$shot" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "invalid shot name '${shot}' in ${conf} — must be kebab-case ([a-z0-9-])" >&2
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
    req_body="$(python3 -c 'import json,sys; print(json.dumps({"model":sys.argv[1],"prompt":sys.argv[2],"size":sys.argv[3]}))' \
      "$ZAI_MODEL" "$prompt" "$ZAI_SIZE")"
    # Capture body AND status (no -f): a 4xx body carries the real reason — a
    # rejected size, an invalid key, a content-filter block — which we must
    # surface, not swallow, on the first live run.
    http="$(curl -sS -w $'\n%{http_code}' -X POST "$ZAI_ENDPOINT" \
      -H "Authorization: Bearer ${ZAI_KEY}" \
      -H "Content-Type: application/json" \
      -d "$req_body")" || { echo "GLM-Image request failed (curl transport error)" >&2; exit 1; }
    code="${http##*$'\n'}"
    resp="${http%$'\n'*}"
    if [[ "$code" != 2?? ]]; then
      echo "GLM-Image HTTP ${code}: ${resp:0:800}" >&2
      exit 1
    fi
    # Parse ONCE from the captured body. Accept a hosted url or inline base64;
    # surface an error/refusal object or an unexpected shape (async task,
    # content filter) with the raw body instead of a bare traceback.
    parsed="$(printf '%s' "$resp" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    obj = json.loads(raw)
except Exception:
    sys.stderr.write("non-JSON GLM-Image response: %s\n" % raw[:800]); raise
if isinstance(obj, dict) and obj.get("error"):
    sys.stderr.write("GLM-Image error: %s\n" % json.dumps(obj["error"])[:500]); sys.exit(3)
try:
    item = obj["data"][0]
    if item.get("url"):
        print("url\t" + item["url"])
    elif item.get("b64_json"):
        print("b64\t" + item["b64_json"])
    else:
        raise KeyError("data[0] has neither url nor b64_json")
except Exception:
    sys.stderr.write("unexpected GLM-Image response shape: %s\n" % raw[:800]); raise')"
    kind="${parsed%%$'\t'*}"
    value="${parsed#*$'\t'}"
    if [[ "$kind" == "url" ]]; then
      # SSRF guard: only fetch a public https URL. Even if the API response or
      # ZAI_ENDPOINT is tampered with, never let it point curl at http:// or an
      # internal/link-local host (cloud metadata at 169.254.169.254, etc.).
      if [[ "$value" != https://* ]]; then
        echo "refusing non-https image URL from API: ${value:0:80}" >&2
        exit 1
      fi
      host="${value#https://}"; host="${host%%/*}"; host="${host%%:*}"
      case "$host" in
        localhost|0.*|127.*|10.*|169.254.*|192.168.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|\[::1\]|::1|\[fe80:*|fe80:*)
          echo "refusing image URL to a private/internal host: ${host}" >&2
          exit 1 ;;
      esac
      curl -fsSL "$value" -o "$tmp/gen.img"
    else
      printf '%s' "$value" | base64 -d >"$tmp/gen.img"
    fi
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
(( ${#generated[@]} )) || { echo "no shots generated (empty lifestyle.conf?)" >&2; exit 1; }
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
