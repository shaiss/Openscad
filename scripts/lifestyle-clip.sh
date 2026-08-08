#!/usr/bin/env bash
# Generate a tier-2 AI *motion clip* for a design via the Z.AI Vidu 2
# image-to-video API, transcode it to a GIF within the animation-GIF budget,
# and embed it in the design's README with the canonical disclosure
# readme-gate requirement 9 demands (an "AI-styled scene" alt label and a
# "geometry is approximate" caption). The clip is COSMETIC and geometrically
# approximate — the model animates an impression of the seed image, not the
# real mesh, and can invent motion the printed part cannot perform; the
# deterministic animations.conf GIF stays the motion-true artifact. See
# .claude/skills/product-shots/SKILL.md (tier 2) and issue #75.
#
#   ZAI_KEY=... ./scripts/lifestyle-clip.sh <design>
#   ./scripts/lifestyle-clip.sh <design> --mock   # offline placeholder, no API
#
# Reads designs/<design>/motion.conf ("<shot> | <prompt>" per line; full-line
# comments only, since a '#' inside a prompt is content) and writes
# designs/<design>/previews/lifestyle-<shot>.gif. <shot> SHOULD match an
# animations.conf or shots.conf entry so the clip sits beside the
# deterministic artifact it restyles; previews/<shot>.png (the tier-1 studio
# shot) is the image-to-video seed when it exists. Re-running is safe: the
# README embed is inserted only if it isn't there already. Meant to run in CI
# (.github/workflows/lifestyle-clip.yml) where ZAI_KEY is a repo secret;
# --mock exercises the whole local pipeline (encode, budget, embed) without
# a key.
#
# PROVENANCE CAVEAT — read before the first live run. docs.z.ai is not
# reachable from the environment this script was written in, so every Vidu 2
# API fact below is a corroborated search-summary paraphrase of the docs
# (marked [S]), not a first-hand page read, and none has been exercised
# against the live API (no ZAI_KEY has ever been set for this repo). The
# first live run must verify, and this header should then be updated:
#   - the model id (vidu2-image) and both endpoint paths
#   - the create/poll response shapes (task id field, task_status values,
#     video_result[].url)
#   - the legal duration (4 documented; 8 unverified) and size values (the
#     docs' own examples disagree: 720x480 vs 1280x720)
#   - that the delivered video is an mp4 (the MIME pin below will name the
#     real container if not)
# Every fact is env-overridable so a wrong default is a one-variable fix.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/preview-budget.sh
. scripts/preview-budget.sh          # MAX_GIF_BYTES

ZAI_VIDEO_MODEL="${ZAI_VIDEO_MODEL:-vidu2-image}"    # [S] flagship image-to-video model
ZAI_VIDEO_ENDPOINT="${ZAI_VIDEO_ENDPOINT:-https://api.z.ai/api/paas/v4/videos/generations}"  # [S]
ZAI_POLL_ENDPOINT="${ZAI_POLL_ENDPOINT:-https://api.z.ai/api/paas/v4/async-result}"  # [S] GET <endpoint>/<task-id>
ZAI_VIDEO_DURATION="${ZAI_VIDEO_DURATION:-4}"        # [S] seconds; 4 is the documented-safe value
ZAI_VIDEO_SIZE="${ZAI_VIDEO_SIZE:-1280x720}"         # [S] the docs' python example; their curl example says 720x480
ZAI_MOVEMENT="${ZAI_MOVEMENT:-auto}"                 # [S] movement_amplitude: auto|small|medium|large
ZAI_SEED_URL="${ZAI_SEED_URL:-}"                     # explicit https image_url override for the seed
ZAI_POLL_INTERVAL="${ZAI_POLL_INTERVAL:-5}"          # seconds; doubles per poll, capped at 30
ZAI_POLL_DEADLINE="${ZAI_POLL_DEADLINE:-900}"        # generation latency is minutes — the docs' own example sleeps 10
CLIP_FPS="${CLIP_FPS:-10}"                           # GIF frame rate; dropped to 6 by the budget ladder if needed
CLIP_WIDTH="${CLIP_WIDTH:-640}"                      # GIF width; stepped down by the budget ladder if needed

design="${1:-}"
mock=0
[[ "${2:-}" == "--mock" ]] && mock=1
if [[ -z "$design" ]]; then
  echo "usage: ZAI_KEY=... $0 <design> [--mock]" >&2
  exit 2
fi
# The design name is interpolated into paths (designs/<design>/...); pin it to
# the repo's kebab-case convention so a stray "../" or a space can't write or
# edit outside the design directory. Strict kebab-case (no leading/trailing
# or doubled hyphens) — the SAME pattern lifestyle-clip.yml's dispatch path
# validates against, so the workflow and the generator accept and reject
# identical names (the rule lifestyle-shot.sh set on #90).
if [[ ! "$design" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "invalid design name '${design}' — must be lowercase kebab-case (e.g. sushi-battleship)" >&2
  exit 2
fi

conf="designs/${design}/motion.conf"
if [[ ! -f "$conf" ]]; then
  echo "no ${conf} — nothing to generate" >&2
  exit 1
fi

# Both paths (mock and live) transcode through ffmpeg and shrink with
# gifsicle. gifsicle is REQUIRED here, not optional-if-present as in
# animate.sh: an optional shrinking pass is exactly how local GIFs came out
# bigger than CI's, and a budget the generator enforces must be enforced the
# same way everywhere.
for tool in ffmpeg gifsicle convert file; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "missing ${tool} — run .claude/hooks/session-start.sh --force to install the toolchain" >&2
    exit 1
  }
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# trim leading/trailing whitespace without touching interior spaces
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# Encode the source video to a GIF at the given fps/width/colors. The -f pins
# ffmpeg's input demuxer (the QuickTime/MP4 family's registered name is the
# full comma list — a bare "mp4" is not a demuxer name) so it can't pick a
# demuxer by sniffing API-controlled bytes — the same discipline as the
# ImageMagick coder pin in lifestyle-shot.sh. palettegen/paletteuse gives a
# per-clip palette; gifsicle then shrinks the frame stream in place.
encode_gif() {
  local src="$1" out="$2" fps="$3" w="$4" colors="$5"
  # -nostdin: this runs inside the while-read loop over motion.conf, and an
  # ffmpeg left interactive would eat the remaining manifest lines off the
  # shared stdin — a multi-shot manifest would silently generate one clip.
  ffmpeg -nostdin -v error -y -f 'mov,mp4,m4a,3gp,3g2,mj2' -i "$src" \
    -vf "fps=${fps},scale=${w}:-2:flags=lanczos,split[a][b];[a]palettegen=max_colors=${colors}[p];[b][p]paletteuse=dither=bayer" \
    -loop 0 "$out"
  gifsicle -O3 --colors "$colors" --batch "$out"
}

# Shrink the clip until it fits MAX_GIF_BYTES — the same ceiling the
# deterministic animations.conf GIFs live under. Three knobs, cheapest
# quality cost first: width steps down ×0.85 to a 320 px floor, then the
# palette halves to 64 colors, then the frame rate drops to 6 fps. Every
# attempt re-encodes from the source video (never from the previous GIF), so
# stepping down costs no generation loss. Fails rather than silently
# shipping an over-budget file.
fit_gif() {
  local src="$1" out="$2" fps colors w
  for fps in "$CLIP_FPS" 6; do
    for colors in 128 64; do
      w="$CLIP_WIDTH"
      while :; do
        encode_gif "$src" "$out" "$fps" "$w" "$colors"
        (( $(stat -c %s "$out") <= MAX_GIF_BYTES )) && return 0
        (( w > 320 )) || break
        w=$(( w * 85 / 100 )); (( w < 320 )) && w=320
      done
    done
  done
  echo "could not fit ${out} under $((MAX_GIF_BYTES / 1024 / 1024)) MiB (down to 320px / 64 colors / 6 fps) — trim the clip or its duration" >&2
  return 1
}

# Resolve the image-to-video seed for one shot to a public https URL.
# Vidu 2's documented input is a URL, not inline bytes [S], so the seed must
# be reachable by the API: the tier-1 studio shot previews/<shot>.png (or the
# first shots.conf shot as a fallback) is served from raw.githubusercontent
# pinned to the HEAD commit SHA — never a branch name, which a later push
# would silently repoint. Fails BEFORE spending a generation if the seed
# isn't committed and reachable; ZAI_SEED_URL overrides everything.
seed_url_for() {
  local shot="$1"
  if [[ -n "$ZAI_SEED_URL" ]]; then
    printf '%s' "$ZAI_SEED_URL"
    return 0
  fi
  local seed="designs/${design}/previews/${shot}.png"
  if [[ ! -f "$seed" ]]; then
    local first_shot=""
    if [[ -f "designs/${design}/shots.conf" ]]; then
      local sline strimmed
      while IFS= read -r sline || [[ -n "$sline" ]]; do
        strimmed="$(trim "$sline")"
        [[ -z "$strimmed" || "$strimmed" == '#'* ]] && continue
        first_shot="$(trim "${sline%%|*}")"
        break
      done <"designs/${design}/shots.conf"
    fi
    [[ -n "$first_shot" ]] && seed="designs/${design}/previews/${first_shot}.png"
  fi
  if [[ ! -f "$seed" ]]; then
    echo "no tier-1 shot to anchor the clip to (looked for previews/${shot}.png and the first shots.conf shot) — Vidu 2 is image-to-video; add a shots.conf shot or set ZAI_SEED_URL" >&2
    return 1
  fi
  local sha slug origin_url
  sha="$(git rev-parse HEAD)"
  slug="${GITHUB_REPOSITORY:-}"
  if [[ -z "$slug" ]]; then
    origin_url="$(git remote get-url origin)"
    slug="${origin_url#*github.com}"
    slug="${slug#[:/]}"
    slug="${slug%.git}"
  fi
  if [[ ! "$slug" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "cannot derive owner/repo from the origin remote — set ZAI_SEED_URL explicitly" >&2
    return 1
  fi
  if ! git cat-file -e "${sha}:${seed}" 2>/dev/null; then
    echo "seed image ${seed} is not committed at HEAD — commit it (and push) or set ZAI_SEED_URL" >&2
    return 1
  fi
  if [[ -n "$(git status --porcelain -- "$seed")" ]]; then
    echo "warning: ${seed} has uncommitted local changes — the API will see the committed version" >&2
  fi
  local url="https://raw.githubusercontent.com/${slug}/${sha}/${seed}"
  if ! curl -fsSI --proto '=https' --max-redirs 0 --connect-timeout 15 --max-time 60 "$url" >/dev/null; then
    echo "seed image not reachable at ${url} — push the commit so the API can fetch it, or set ZAI_SEED_URL" >&2
    return 1
  fi
  printf '%s' "$url"
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
    echo "malformed motion.conf line (want '<shot> | <prompt>'): $line" >&2
    exit 1
  fi
  # <shot> becomes the filename stem (lifestyle-<shot>.gif) and part of the
  # README embed URL — pin it to kebab-case so it can't escape previews/ or
  # produce a broken markdown link.
  if [[ ! "$shot" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "invalid shot name '${shot}' in ${conf} — must be kebab-case ([a-z0-9-])" >&2
    exit 1
  fi

  outdir="designs/${design}/previews"
  mkdir -p "$outdir"
  out="${outdir}/lifestyle-${shot}.gif"

  if (( mock )); then
    # Offline placeholder: gradient frames with a moving label, encoded to an
    # mp4 so everything downstream — the demuxer pin, the palette encode,
    # gifsicle, the budget ladder, the README embed — runs the exact live
    # path. Only submit/poll/download are skipped. Never commit a --mock clip.
    for i in $(seq 0 7); do
      convert -size 640x360 gradient:'#2b3a4a'-'#c98f5a' \
        -gravity west -pointsize 26 -fill white \
        -annotate "+$((20 + i * 40))+0" "MOCK clip\n${design} / ${shot}\n(not for commit)" \
        "$(printf '%s/f%02d.png' "$tmp" "$i")"
    done
    ffmpeg -nostdin -v error -y -framerate 4 -i "$tmp/f%02d.png" -pix_fmt yuv420p "$tmp/gen.mp4"
  else
    if [[ -z "${ZAI_KEY:-}" ]]; then
      echo "ZAI_KEY is not set — export it (CI: repo secret) or pass --mock" >&2
      exit 1
    fi
    seed_url="$(seed_url_for "$shot")" || exit 1
    req_body="$(python3 -c 'import json,sys; print(json.dumps({"model":sys.argv[1],"prompt":sys.argv[2],"image_url":sys.argv[3],"duration":int(sys.argv[4]),"size":sys.argv[5],"movement_amplitude":sys.argv[6]}))' \
      "$ZAI_VIDEO_MODEL" "$prompt" "$seed_url" "$ZAI_VIDEO_DURATION" "$ZAI_VIDEO_SIZE" "$ZAI_MOVEMENT")"
    # Capture body AND status (no -f): a 4xx body carries the real reason — a
    # rejected size, an invalid key, a refused seed URL — which we must
    # surface, not swallow, on the first live run. The Authorization header
    # goes in via -K - (stdin config) so the key never lands in curl's argv
    # (readable from /proc); the printf is a bash builtin, so it doesn't fork
    # either. --connect-timeout/--max-time bound a stalled third-party call.
    http="$(printf 'header = "Authorization: Bearer %s"\n' "$ZAI_KEY" \
      | curl -sS -K - --connect-timeout 15 --max-time 120 -w $'\n%{http_code}' \
        -X POST "$ZAI_VIDEO_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "$req_body")" || { echo "Vidu create request failed (curl transport error)" >&2; exit 1; }
    code="${http##*$'\n'}"
    resp="${http%$'\n'*}"
    if [[ "$code" != 2?? ]]; then
      echo "Vidu create HTTP ${code}: ${resp:0:800}" >&2
      exit 1
    fi
    # Parse ONCE from the captured body. Unlike GLM-Image (which returns the
    # image synchronously — lifestyle-shot.sh treats "an async task" as an
    # unexpected shape), a task handle IS the expected shape here [S]: the
    # create call returns an id and the video arrives later via the poll
    # endpoint. Surface an error object or anything else with the raw body.
    task_id="$(printf '%s' "$resp" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    obj = json.loads(raw)
except Exception:
    sys.stderr.write("non-JSON Vidu create response: %s\n" % raw[:800]); raise
if isinstance(obj, dict) and obj.get("error"):
    sys.stderr.write("Vidu error: %s\n" % json.dumps(obj["error"])[:500]); sys.exit(3)
tid = None
if isinstance(obj, dict):
    tid = obj.get("id")
    if not tid and isinstance(obj.get("data"), dict):
        tid = obj["data"].get("id")
if not tid:
    sys.stderr.write("unexpected Vidu create-response shape (no task id): %s\n" % raw[:800]); sys.exit(4)
print(tid)')" || exit 1
    # The id is interpolated into the poll URL — pin its shape first.
    if [[ ! "$task_id" =~ ^[A-Za-z0-9_-]+$ ]]; then
      echo "refusing suspicious task id from API: ${task_id:0:80}" >&2
      exit 1
    fi
    # Poll until SUCCESS/FAIL, backing off 5s -> 10s -> 20s -> 30s (video
    # generation takes minutes [S] — the docs' own example sleeps 10 of
    # them). The result URL expires ~24h after completion [S], so the
    # download below must happen in this same run.
    poll_deadline=$(( SECONDS + ZAI_POLL_DEADLINE ))
    interval="$ZAI_POLL_INTERVAL"
    value=""
    while :; do
      if (( SECONDS >= poll_deadline )); then
        echo "Vidu task ${task_id} still PROCESSING after ${ZAI_POLL_DEADLINE}s — raise ZAI_POLL_DEADLINE" >&2
        exit 1
      fi
      sleep "$interval"
      (( interval < 30 )) && { interval=$(( interval * 2 )); (( interval > 30 )) && interval=30; }
      http="$(printf 'header = "Authorization: Bearer %s"\n' "$ZAI_KEY" \
        | curl -sS -K - --connect-timeout 15 --max-time 60 -w $'\n%{http_code}' \
          "${ZAI_POLL_ENDPOINT}/${task_id}")" || { echo "Vidu poll request failed (curl transport error)" >&2; exit 1; }
      code="${http##*$'\n'}"
      resp="${http%$'\n'*}"
      if [[ "$code" != 2?? ]]; then
        echo "Vidu poll HTTP ${code}: ${resp:0:800}" >&2
        exit 1
      fi
      result="$(printf '%s' "$resp" | python3 -c '
import json, sys
raw = sys.stdin.read()
try:
    obj = json.loads(raw)
except Exception:
    sys.stderr.write("non-JSON Vidu poll response: %s\n" % raw[:800]); raise
if isinstance(obj, dict) and obj.get("error"):
    sys.stderr.write("Vidu error: %s\n" % json.dumps(obj["error"])[:500]); sys.exit(3)
status = obj.get("task_status") if isinstance(obj, dict) else None
if status == "PROCESSING":
    print("PROCESSING"); sys.exit(0)
if status == "FAIL":
    sys.stderr.write("Vidu generation FAILED: %s\n" % raw[:800]); sys.exit(4)
if status == "SUCCESS":
    try:
        url = obj["video_result"][0]["url"]
    except Exception:
        sys.stderr.write("SUCCESS but unexpected video_result shape: %s\n" % raw[:800]); raise
    print("SUCCESS\t" + url); sys.exit(0)
sys.stderr.write("unexpected task_status %r: %s\n" % (status, raw[:800])); sys.exit(5)')" || exit 1
      [[ "$result" == "PROCESSING" ]] && continue
      value="${result#SUCCESS$'\t'}"
      break
    done
    # SSRF guard: require https, extract the host correctly (dropping any
    # userinfo so https://x@169.254.169.254/ can't spoof it), then RESOLVE it
    # and refuse if any resolved address is non-public. Resolving — rather
    # than string-matching — is what catches decimal/hex IP literals and
    # hostnames that point at internal targets (cloud metadata, etc.), even
    # if the API response or the endpoints are tampered with. No hostname
    # allowlist: the docs don't name the CDN host, and the chain doesn't
    # need one.
    if [[ "$value" != https://* ]]; then
      echo "refusing non-https video URL from API: ${value:0:80}" >&2
      exit 1
    fi
    authority="${value#https://}"
    authority="${authority%%[/?#]*}"   # drop path / query / fragment
    authority="${authority##*@}"       # drop userinfo (segment after last @)
    if [[ "$authority" == \[* ]]; then
      host="${authority%%\]*}]"        # bracketed IPv6 literal, keep [ ... ]
      rest="${authority#*\]}"; port="${rest#:}"; [[ "$port" == "$rest" ]] && port=443
    else
      host="${authority%%:*}"
      port="${authority##*:}"; [[ "$port" == "$authority" ]] && port=443
    fi
    # Resolve + validate ONCE and capture the vetted IP, so curl connects to
    # that exact address via --resolve rather than doing its own second DNS
    # lookup — which a short-TTL rebind could swing to an internal host
    # between the check and the fetch (TOCTOU). A literal IP host has no DNS
    # lookup to rebind, so it's fetched directly once vetted.
    vet="$(python3 - "$host" <<'PY'
import sys, socket, ipaddress
host = sys.argv[1].strip("[]")
try:
    ipaddress.ip_address(host); literal = True
except ValueError:
    literal = False
try:
    addrs = {ai[4][0] for ai in socket.getaddrinfo(host, None)}
except Exception as e:
    sys.stderr.write("refusing video URL: cannot resolve host %r (%s)\n" % (host, e)); sys.exit(1)
vetted = ""
for a in addrs:
    ip = ipaddress.ip_address(a)
    if (not ip.is_global) or ip.is_private or ip.is_loopback or ip.is_link_local \
       or ip.is_reserved or ip.is_multicast:
        sys.stderr.write("refusing video URL: host %r resolves to non-public %s\n" % (host, a)); sys.exit(1)
    vetted = vetted or a
if not vetted:
    sys.stderr.write("refusing video URL: host %r has no addresses\n" % host); sys.exit(1)
print("literal" if literal else "name")
print(vetted)
PY
)" || exit 1
    vetted_ip="${vet##*$'\n'}"
    # Download hardening: --proto '=https' pins the scheme, --max-redirs 0 plus
    # no -L means a redirect can't send curl to a fresh, unvetted host (a 3xx
    # is refused below too), --connect-timeout/--max-time bound a stall, and
    # --max-filesize caps an API-controlled payload before it hits ffmpeg
    # (100 MB — generous for a 4s clip, whose real size the first live run
    # will report).
    dl_flags=(--proto '=https' --max-redirs 0 --connect-timeout 15 --max-time 600 --max-filesize 100000000)
    if [[ "${vet%%$'\n'*}" == "name" ]]; then
      resolve_host="${host#[}"; resolve_host="${resolve_host%]}"
      dl_code="$(curl -fsS "${dl_flags[@]}" -o "$tmp/gen.mp4" -w '%{http_code}' \
        --resolve "${resolve_host}:${port}:${vetted_ip}" "$value")" \
        || { echo "video download failed" >&2; exit 1; }
    else
      dl_code="$(curl -fsS "${dl_flags[@]}" -o "$tmp/gen.mp4" -w '%{http_code}' "$value")" \
        || { echo "video download failed" >&2; exit 1; }
    fi
    if [[ "$dl_code" == 3?? ]]; then
      echo "refusing video URL: it returned a redirect (HTTP ${dl_code}); not following it (SSRF guard)" >&2
      exit 1
    fi
    # These bytes are API-controlled. The container is expected to be mp4
    # [S, unverified] — anything else is refused WITH the observed type, so
    # the first live run tells us the real container instead of feeding
    # mystery bytes to ffmpeg.
    mime="$(file -b --mime-type "$tmp/gen.mp4")"
    if [[ "$mime" != video/mp4 ]]; then
      echo "refusing unexpected video type from API: ${mime} (expected video/mp4 — if this is legitimate, extend the check and the demuxer pin together)" >&2
      exit 1
    fi
  fi

  fit_gif "$tmp/gen.mp4" "$out"
  echo "wrote ${out} ($(( ($(stat -c %s "$out") + 1023) / 1024 )) KiB)"
  generated+=("$shot")
done <"$conf"

# Insert the canonical disclosure embed into the README for each clip (only if
# it isn't already embedded), directly after the deterministic artifact it
# restyles — the animations.conf GIF first, else the tier-1 hero shot — so
# the AI clip never sits above the motion-true one.
readme="designs/${design}/README.md"
(( ${#generated[@]} )) || { echo "no clips generated (empty motion.conf?)" >&2; exit 1; }
for shot in "${generated[@]}"; do
  DESIGN="$design" SHOT="$shot" README="$readme" python3 - <<'PY'
import os
design, shot, readme = os.environ["DESIGN"], os.environ["SHOT"], os.environ["README"]
rel = f"previews/lifestyle-{shot}.gif"
anchors = [f"previews/{shot}.gif", f"previews/{shot}.png"]
block = (
    f"\n![AI-styled scene: {design} in motion, staged in a real-world setting]({rel})\n\n"
    "*AI-generated motion impression for general illustration only — geometry "
    "is approximate and may not exactly match the printed part, and the "
    "movement shown is illustrative, not a simulation; see the deterministic "
    "previews above and the STL for the true shape.*\n"
)
text = open(readme, encoding="utf-8").read()
if f"]({rel})" in text:
    print(f"README already embeds {rel}")
    raise SystemExit(0)
lines = text.splitlines(keepends=True)
# insert after the paragraph containing the deterministic GIF, else the
# tier-1 hero, else the first image embed, else append.
anchor = next((i for a in anchors for i, l in enumerate(lines) if f"]({a})" in l), None)
if anchor is None:
    anchor = next((i for i, l in enumerate(lines) if l.lstrip().startswith("![")), None)
if anchor is None:
    out = text + block
else:
    # Advance past the anchor image's paragraph, then — if the next paragraph
    # is its caption (a blank-separated emphasis line, not another image or a
    # heading) — past that too, so the clip block lands after the whole unit
    # instead of wedged between the image and its caption.
    def end_of_para(i):
        while i < len(lines) and lines[i].strip():
            i += 1
        return i
    end = end_of_para(anchor + 1)
    nxt = end
    while nxt < len(lines) and not lines[nxt].strip():
        nxt += 1
    if nxt < len(lines):
        s = lines[nxt].lstrip()
        if s[:1] in ("*", "_") and not s.startswith("!["):
            end = end_of_para(nxt)
    out = "".join(lines[:end]) + block + "".join(lines[end:])
open(readme, "w", encoding="utf-8").write(out)
print(f"embedded {rel} in {readme}")
PY
done
