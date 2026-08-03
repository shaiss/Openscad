#!/usr/bin/env bash
# Draft a design's product page (designs/<design>/README.md) with the Claude
# API, from what the design already commits: the entry .scad's parameter block,
# NOTES.md, the preview manifests, and whatever README prose exists today.
#
#   ANTHROPIC_API_KEY=... ./scripts/product-page.sh <design>
#   ./scripts/product-page.sh <design> --mock    # offline stub, no API call
#   ./scripts/product-page.sh <design> --force   # redraft a page that passes
#
# Only drafts when there is something to fix: a design whose README already
# satisfies scripts/readme-gate.sh is left alone unless --force. That is the
# whole safety model for putting a generator on top of prose — the gate, not
# the model, decides whether the page is acceptable, and this script REVERTS
# its own output if the gate rejects it. A draft that cannot pass is not
# committed and not silently half-applied; the exit status says so.
#
# The page is prose about a physical object, so it is a *draft for a human*,
# not a deliverable: the commit and the CI job summary both say so, and the
# page carries an HTML-comment marker a reviewer deletes once they have read
# it. Nothing downstream keys on the marker — readme-gate ignores comments.
#
# Meant to run in CI (.github/workflows/ci.yml, the `regen` job) where
# ANTHROPIC_API_KEY is a repo secret; --mock lets the surrounding pipeline
# (gate, commit, revert-on-failure) be exercised locally without a key.
set -euo pipefail

cd "$(dirname "$0")/.."

# Opus 5 by default: this is prose a stranger reads to decide whether to spend
# six hours of printer time, and the draft is only worth having if it is good.
# Override for a cheaper sweep; the gate is the same either way.
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-opus-5}"
CLAUDE_ENDPOINT="${CLAUDE_ENDPOINT:-https://api.anthropic.com/v1/messages}"
# Thinking is on by default on Opus 5 and max_tokens caps thinking + text
# together, so this is deliberately generous: a tight budget truncates the
# page mid-section, which then fails the gate and reverts for the wrong reason.
CLAUDE_MAX_TOKENS="${CLAUDE_MAX_TOKENS:-16000}"
CLAUDE_EFFORT="${CLAUDE_EFFORT:-high}"

MARKER='<!-- product-page: AI-drafted from the design sources; review and delete this line. -->'

design="${1:-}"
mock=0
force=0
for arg in "${@:2}"; do
  case "$arg" in
    --mock)  mock=1 ;;
    --force) force=1 ;;
    *) echo "unknown option '$arg'" >&2; exit 2 ;;
  esac
done
if [[ -z "$design" ]]; then
  echo "usage: ANTHROPIC_API_KEY=... $0 <design> [--mock] [--force]" >&2
  exit 2
fi
# The name is interpolated into paths (designs/<design>/...); pin it to the
# repo's kebab-case convention so a stray "../" can't write outside the design.
if [[ ! "$design" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "invalid design name '${design}' — must be kebab-case ([a-z0-9-])" >&2
  exit 2
fi

dir="designs/${design}"
entry="${dir}/${design}.scad"
readme="${dir}/README.md"
if [[ ! -f "$entry" ]]; then
  echo "no ${entry} — not a design directory" >&2
  exit 2
fi

# Already acceptable? Then there is nothing to draft. Checked before the key,
# so the common CI case (every page fine) costs neither a secret nor a call.
if (( ! force )) && ./scripts/readme-gate.sh "$design" >/dev/null 2>&1; then
  echo "${design}: product page already passes readme-gate — nothing to draft"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------- context ---
# Everything the drafter is allowed to know, assembled from committed files.
# Deliberately not the whole tree: a page that describes geometry the design
# does not have is worse than no page, so the model sees the entry .scad (where
# the parameters and their unit comments live) and the engineering log, and
# nothing it would have to guess from.

# Local images the page may embed, and the ones the gate REQUIRES it to embed.
required_embeds=()
# `|| [[ -n "$line" ]]` on both loops, matching readme-gate.sh and animate.sh:
# a manifest saved without a trailing newline makes `read` return non-zero on
# the last entry, dropping it. That would silently omit a required embed, and
# the gate would then reject the draft for something the model did right.
if [[ -f "${dir}/animations.conf" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"; [[ "$line" =~ [^[:space:]] ]] || continue
    n="${line%%|*}"; n="$(tr -d '[:space:]' <<<"$n")"
    [[ -n "$n" ]] && required_embeds+=("previews/${n}.gif")
  done <"${dir}/animations.conf"
fi
if [[ -f "${dir}/shots.conf" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"; [[ "$line" =~ [^[:space:]] ]] || continue
    n="${line%%|*}"; n="$(tr -d '[:space:]' <<<"$n")"
    [[ -n "$n" ]] && required_embeds+=("previews/${n}.png")
  done <"${dir}/shots.conf"
fi

available_images=()
if [[ -d "${dir}/previews" ]]; then
  while IFS= read -r f; do
    available_images+=("previews/$(basename "$f")")
  done < <(find "${dir}/previews" -maxdepth 1 -type f \
             \( -name '*.png' -o -name '*.gif' -o -name '*.jpg' \) | sort)
fi

# A derivative must link its parents, so the drafter needs to know who they are.
parents=()
if [[ -f "${dir}/derives.conf" ]]; then
  while IFS= read -r p; do
    [[ -n "$p" ]] && parents+=("$p")
  done < <(./scripts/lineage.sh parents "$design" 2>/dev/null || true)
fi

{
  echo "=== designs/${design}/${design}.scad (the entry point; parameters and their units live at the top) ==="
  cat "$entry"
  for extra in "${dir}"/*.scad; do
    [[ "$extra" == "$entry" ]] && continue
    [[ -f "$extra" ]] || continue
    echo
    echo "=== ${extra} ==="
    cat "$extra"
  done
  if [[ -f "${dir}/NOTES.md" ]]; then
    echo
    echo "=== designs/${design}/NOTES.md (engineering log — decisions and derivations; do NOT copy it wholesale into the product page) ==="
    cat "${dir}/NOTES.md"
  fi
  if [[ -f "${dir}/ci.parts" ]]; then
    echo
    echo "=== designs/${design}/ci.parts (the printable parts CI gates) ==="
    cat "${dir}/ci.parts"
  fi
  if [[ -f "$readme" ]]; then
    echo
    echo "=== designs/${design}/README.md (the CURRENT page — preserve any accurate prose in it) ==="
    cat "$readme"
  fi
  echo
  echo "=== templates/README.md (the house structure for a product page) ==="
  cat templates/README.md
} >"$tmp/context.txt"

# ------------------------------------------------------------------ draft ---
if (( mock )); then
  # Offline stub: structurally valid so the gate/commit/revert pipeline around
  # this script is testable without a key. Never commit a --mock page.
  {
    echo "# ${design}"
    echo
    echo "$MARKER"
    echo
    echo "MOCK product page for \`${design}\` — placeholder text produced by"
    echo "\`product-page.sh --mock\`, not a real draft. Not for commit."
    echo
    for img in "${required_embeds[@]}" "${available_images[@]:0:1}"; do
      echo "![${design}](${img})"
      echo
    done
    echo "## Print settings"
    echo
    echo "- **Supports:** none needed"
    echo
    echo "## Parameters"
    echo
    echo "See the top of \`${design}.scad\`."
  } >"$tmp/draft.md"
else
  if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "ANTHROPIC_API_KEY is not set — export it (CI: repo secret) or pass --mock" >&2
    exit 1
  fi

  system=$(cat <<'SYS'
You are writing the product page (README.md) for one 3D-printable OpenSCAD
design in a repository of them. The page is what a stranger reads to decide
whether to print the design and how to succeed at it.

Absolute rules:
- Every factual claim must come from the source files you were given. Do not
  invent dimensions, tolerances, print times, material recommendations, or
  features. If the sources do not establish something, leave it out rather
  than guessing — a plausible wrong number here becomes a failed print.
- Parameter defaults and units must be copied from the .scad, not estimated.
- Do not copy the engineering log (NOTES.md) into the page. NOTES.md records
  why decisions were made; the product page tells a stranger what the thing
  is and how to print it.
- Preserve accurate prose from the current README where it exists.
- Output ONLY the finished Markdown for the page. No preamble, no code fence
  around the whole document, no commentary.
SYS
)

  reqs="$(printf '%s\n' \
    "Structural requirements the page must satisfy (a CI gate enforces them):" \
    "1. Opens with an H1 title." \
    "2. One or two sentences of plain prose pitching the design BEFORE the first ## section: what it is, who it is for." \
    "3. Has non-empty '## Print settings' and '## Parameters' sections." \
    "4. Embeds at least one of the local images listed below, with descriptive alt text.")"
  if (( ${#required_embeds[@]} )); then
    reqs+=$'\n'"5. MUST embed every one of these, exactly as written, each with descriptive alt text: $(printf '%s ' "${required_embeds[@]}")"
  fi
  if (( ${#parents[@]} )); then
    reqs+=$'\n'"6. This design is a DERIVATIVE. Document only what it changes relative to its parent, and link each parent's directory as a sibling-relative link: $(printf '../%s ' "${parents[@]}")"
  fi
  if (( ${#available_images[@]} )); then
    reqs+=$'\n'"Local images that exist and may be embedded: $(printf '%s ' "${available_images[@]}")"
    reqs+=$'\n'"Do NOT reference any image not on that list — a broken link fails the build."
  fi
  reqs+=$'\n'"Include this line verbatim, on its own line, immediately after the H1: ${MARKER}"

  # Build the JSON with python3 (not jq — the repo's other API caller does the
  # same, so neither script adds a jq dependency to the toolchain).
  CTX_FILE="$tmp/context.txt" SYSTEM="$system" REQS="$reqs" \
  MODEL="$CLAUDE_MODEL" MAXTOK="$CLAUDE_MAX_TOKENS" EFFORT="$CLAUDE_EFFORT" \
  DESIGN="$design" python3 - >"$tmp/req.json" <<'PY'
import json, os
ctx = open(os.environ["CTX_FILE"], encoding="utf-8", errors="replace").read()
prompt = (
    f"Write the product page for the design `{os.environ['DESIGN']}`.\n\n"
    f"{os.environ['REQS']}\n\n"
    "Here are the design's source files:\n\n" + ctx
)
print(json.dumps({
    "model": os.environ["MODEL"],
    "max_tokens": int(os.environ["MAXTOK"]),
    "system": os.environ["SYSTEM"],
    "output_config": {"effort": os.environ["EFFORT"]},
    "messages": [{"role": "user", "content": prompt}],
}))
PY

  # Capture body AND status (no -f): a 4xx body carries the real reason — a bad
  # key, an oversized request, a rejected parameter — which must be surfaced,
  # not swallowed. The key goes in via -K - (stdin config) so it never lands in
  # curl's argv (readable from /proc); printf is a builtin, so it doesn't fork.
  # --retry covers the transient statuses (429 and 5xx, which is what an
  # overload looks like) so one busy moment doesn't lose the whole draft; a
  # 4xx that needs the request changed is not retried and falls through below.
  http="$(printf 'header = "x-api-key: %s"\n' "$ANTHROPIC_API_KEY" \
    | curl -sS -K - --connect-timeout 15 --max-time 900 \
      --retry 3 --retry-delay 5 --retry-max-time 600 -w $'\n%{http_code}' \
      -X POST "$CLAUDE_ENDPOINT" \
      -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" \
      --data-binary "@$tmp/req.json")" \
    || { echo "Claude API request failed (curl transport error)" >&2; exit 1; }
  code="${http##*$'\n'}"
  resp="${http%$'\n'*}"
  if [[ "$code" != 2?? ]]; then
    echo "Claude API HTTP ${code}: ${resp:0:800}" >&2
    exit 1
  fi

  # Parse once from the captured body. stop_reason is checked before content:
  # a refusal returns HTTP 200 with an empty content array, and a max_tokens
  # stop returns a truncated page that would fail the gate for a misleading
  # reason. Both are reported as themselves.
  printf '%s' "$resp" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    obj = json.loads(raw)
except Exception:
    sys.stderr.write("non-JSON Claude API response: %s\n" % raw[:800]); raise
if isinstance(obj, dict) and obj.get("type") == "error":
    sys.stderr.write("Claude API error: %s\n" % json.dumps(obj.get("error"))[:500]); sys.exit(3)
stop = obj.get("stop_reason")
if stop == "refusal":
    sys.stderr.write("Claude declined to draft this page (stop_reason=refusal): %s\n"
                     % json.dumps(obj.get("stop_details"))[:300]); sys.exit(4)
if stop == "max_tokens":
    sys.stderr.write("draft was truncated at max_tokens — raise CLAUDE_MAX_TOKENS\n"); sys.exit(5)
text = "".join(b.get("text", "") for b in obj.get("content", []) if b.get("type") == "text").strip()
if not text:
    sys.stderr.write("Claude API returned no text content: %s\n" % raw[:800]); sys.exit(6)
sys.stdout.write(text + "\n")
' >"$tmp/draft.md"
fi

# Models like to wrap a whole document in a fence even when told not to; strip
# one if it is the entire payload, rather than committing a page whose H1 is
# inside a code block (which the gate reads as "no H1" — a confusing failure).
if [[ "$(head -1 "$tmp/draft.md")" == '```'* && "$(tail -1 "$tmp/draft.md")" == '```' ]]; then
  sed -i '1d;$d' "$tmp/draft.md"
fi

if [[ ! -s "$tmp/draft.md" ]]; then
  echo "${design}: generator produced an empty page" >&2
  exit 1
fi

# The marker is the ONLY in-file signal that a human didn't write this page,
# and nothing downstream can enforce it: readme-gate ignores HTML comments, so
# a draft that dropped it passes and gets committed while the CI job summary
# still tells the reviewer to look for it. Asking the model for it is not the
# same as having it — insert it after the H1 when it is missing.
if ! grep -qF "$MARKER" "$tmp/draft.md"; then
  MARKER="$MARKER" awk 'NR==1 { print; print ""; print ENVIRON["MARKER"]; next } { print }' \
    "$tmp/draft.md" >"$tmp/draft.marked.md"
  mv "$tmp/draft.marked.md" "$tmp/draft.md"
  echo "${design}: generator omitted the draft marker — inserted it"
fi

# ------------------------------------------------------- gate, or put back ---
# The gate is the acceptance test, and it runs against the file in place
# because that is the only thing readme-gate can read. Restore the original on
# failure so a rejected draft leaves the tree exactly as it found it.
backup="$tmp/README.md.orig"
had_readme=0
if [[ -f "$readme" ]]; then
  had_readme=1
  cp "$readme" "$backup"
fi
cp "$tmp/draft.md" "$readme"

if ./scripts/readme-gate.sh "$design"; then
  echo "${design}: drafted ${readme} ($(wc -l <"$readme") lines) — REVIEW BEFORE MERGING"
else
  status=$?
  if (( had_readme )); then
    cp "$backup" "$readme"
    echo "${design}: draft rejected by readme-gate — original README.md restored" >&2
  else
    rm -f "$readme"
    echo "${design}: draft rejected by readme-gate — no README.md written" >&2
  fi
  exit "$status"
fi
