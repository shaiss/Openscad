#!/usr/bin/env bash
# Product-page gate: every design directory must ship a README.md that
# works as a product page — the page a stranger reads to decide whether
# to print the design and how. CI runs this on every PR.
#   ./scripts/readme-gate.sh          # gate all designs under designs/
#   ./scripts/readme-gate.sh <name>   # gate one design
#
# A passing README.md must:
#   1. exist in designs/<name>/
#   2. open with an H1 title (# <design name>)
#   3. pitch the design in prose before the first ## section
#      (what it is, who it is for)
#   4. contain non-empty "## Print settings" and "## Parameters" sections
#      (### subheadings belong to their parent ## section; a section needs
#      at least one line of real content — prose, list, or table)
#   5. show at least one committed preview image — a local reference that
#      resolves relative to the design directory (remote http(s) images
#      are allowed but don't satisfy this); every local reference must
#      exist
#   6. if the design ships an animations.conf (GIF previews, rendered by
#      scripts/animate.sh): every manifest entry must have its committed
#      previews/<name>.gif, the README must embed it, and each GIF must
#      stay within the size budget — GIFs live in git history forever
#   7. if the design ships a shots.conf (product shots, rendered by
#      scripts/product-shot.sh): every manifest entry must have its
#      committed previews/<name>.png, the README must embed it, and each
#      shot must stay within the size budget
#   8. if the design ships a derives.conf (it reuses another design's
#      geometry): the page must link every parent's design directory, so a
#      reader who arrives at the derivative can reach what it was built from.
#      Accepted targets, all of them sibling-relative because that is what
#      resolves from designs/<name>/README.md: ../<parent>, ../<parent>/ and
#      ../<parent>/README.md, written as a markdown link — ](...) — or as an
#      HTML <a href="...">, since a page that credits its base with a working
#      anchor has done the thing being asked for. A repo-root-relative
#      designs/<parent>/ does NOT count: from inside designs/<name>/ it
#      resolves to designs/<name>/designs/<parent>/ and 404s, and gating in a
#      dead link is worse than gating in none.
#   9. if the design ships one or more previews/lifestyle-*.png (an
#      AI-restyled lifestyle shot — cosmetic, and assumed geometrically
#      approximate, so it is never regenerated or geometry-checked): each must
#      be embedded in the README, within the size budget, and carry its
#      disclosure — an "AI-styled scene" alt label AND a visible warning note
#      in the paragraph directly below the image (alt text is not shown on the
#      rendered page). This is what keeps a cosmetic AI image off the product
#      page masquerading as a photo of the printed part. Unlike the GIF and
#      product-shot checks there is no manifest: the committed PNG itself is
#      the trigger, because an AI restyle cannot be regenerated from source.
#
# Fenced code blocks and HTML comments are ignored throughout: an example
# snippet or commented-out line is not page content, so it neither
# satisfies a requirement nor trips one.
#
# templates/README.md is a skeleton that passes once filled in.
# NOTES.md remains the engineering log; README.md is the product page.
set -euo pipefail

# Absolute path to this script, captured before the cd below so `--selftest`
# can re-invoke the gate against throwaway fixture directories from any CWD.
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

cd "$(dirname "$0")/.."
# shellcheck source=scripts/preview-budget.sh
# defines MAX_GIF_BYTES (shared with animate.sh) and MAX_SHOT_BYTES (the
# product-shot budget, reused below for lifestyle shots)
. scripts/preview-budget.sh

# The design tree to gate. Overridable so `--selftest` can point the gate at a
# fixture tree without touching the real designs/; defaults to designs/.
ROOT="${READMEGATE_DESIGNS_DIR:-designs}"

fail=0

err() {
  echo "FAIL  $1: $2"
  fail=1
}

# Strip fenced code blocks and HTML comments so example snippets are not
# mistaken for real content (an image inside a ``` fence or <!-- --> comment
# neither renders on the page nor satisfies the gate).
strip_noise() {
  awk '
    BEGIN { fence = 0; incomment = 0 }
    {
      line = $0
      if (fence) {
        if (line ~ /^(```|~~~)/) fence = 0
        next
      }
      if (!incomment && line ~ /^(```|~~~)/) { fence = 1; next }
      out = ""
      rest = line
      while (length(rest) > 0) {
        if (incomment) {
          p = index(rest, "-->")
          if (p == 0) { rest = ""; break }
          rest = substr(rest, p + 3)
          incomment = 0
        } else {
          p = index(rest, "<!--")
          if (p == 0) { out = out rest; rest = ""; break }
          out = out substr(rest, 1, p - 1)
          rest = substr(rest, p + 4)
          incomment = 1
        }
      }
      print out
    }
  ' "$1"
}

# Does the (noise-stripped) README have a "## <section>" heading
# (case-insensitive) with at least one non-blank line of content before the
# next same-or-higher-level heading? Nested ### subheadings count as content.
section_has_content() {
  local section="$1"
  awk -v want="$(tr '[:upper:]' '[:lower:]' <<<"$section")" '
    tolower($0) ~ ("^##[ \t]+" want "([ \t]|$)") { insec = 1; next }
    insec && /^##?[ \t]/                         { exit }
    insec && !/^[ \t]*$/                         { found = 1; exit }
    END                                          { exit !found }
  '
}

# For one committed lifestyle PNG, decide whether an embed of it in the
# (noise-stripped) README carries the disclosure the gate requires. Reads the
# cleaned README on stdin and prints exactly one verdict:
#   OK             an embed has both the "AI-styled scene" alt label and a
#                  visible warning note in the paragraph directly below it
#   MISSING_EMBED  the committed PNG is never embedded
#   MISSING_LABEL  embedded, but no embed carries the "AI-styled scene" label
#   MISSING_NOTE   a labeled embed exists, but none is followed by a visible note
# The note must name the shot as AI-generated AND say the geometry is
# approximate, and it must sit in the paragraph directly below the image — so
# the alt label alone (not shown on the rendered page, and carrying no
# approximation wording) can never satisfy it.
lifestyle_disclosure() {
  local png="$1"
  awk -v png="$png" '
    function is_ai_note(s,   t) {
      t = tolower(s)
      if (t !~ /ai[- ]generated|ai[- ]styled|ai image|ai[- ]rendered|generated by ai|ai impression/) return 0
      if (t !~ /approximat|may not|not exact|illustrat|cosmetic/) return 0
      return 1
    }
    { line[NR] = $0 }
    END {
      key = "](" png ")"
      any_embed = 0; any_label = 0; ok = 0
      for (i = 1; i <= NR; i++) {
        p = index(line[i], key)
        if (p == 0) continue
        pre = substr(line[i], 1, p - 1)     # text up to the "]" of "]("
        b = index(pre, "![")
        if (b == 0) continue                # a link to the PNG, not an image embed
        any_embed = 1
        alt = tolower(substr(pre, b + 2))   # between "![" and "]"
        has_label = (alt ~ /ai[- ]styled scene/)
        if (has_label) any_label = 1
        # accumulate the paragraph directly below the image, then test it as a
        # whole so a note split across lines still counts.
        para = ""
        j = i + 1
        while (j <= NR && line[j] ~ /^[ \t]*$/) j++     # skip blank lines
        for (; j <= NR; j++) {
          if (line[j] ~ /^[ \t]*$/) break               # end of paragraph
          if (line[j] ~ /^[ \t]*#/) break               # a heading ends the region
          if (line[j] ~ /!\[/) break                    # the next image ends the region
          para = para " " line[j]
        }
        if (has_label && para != "" && is_ai_note(para)) ok = 1
      }
      if (!any_embed) { print "MISSING_EMBED"; exit }
      if (ok)         { print "OK"; exit }
      if (any_label)  { print "MISSING_NOTE"; exit }
      print "MISSING_LABEL"
    }
  '
}

check_one() {
  local name="$1"
  local dir="${ROOT}/${name}"
  local readme="${dir}/README.md"
  local ok=1

  if [[ ! -d "$dir" ]]; then
    echo "error: $dir not found" >&2
    fail=1
    return 0
  fi

  if [[ ! -f "$readme" ]]; then
    err "$name" "missing README.md — every design ships a product page (start from templates/README.md)"
    return 0
  fi

  # All content checks run on the noise-stripped text: fenced code blocks
  # and HTML comments don't render as page content, so they neither satisfy
  # a requirement nor trip one.
  local cleaned
  cleaned="$(strip_noise "$readme")"

  # Checks below are numbered to match the requirement list in the header
  # comment (requirement 1 — the README exists — is the early return above).

  # 2. Title: the first non-blank line must be an H1 with actual text
  #    ("# Name" — markdown requires the space, and a bare "#" is no title).
  local first
  first="$(grep -m1 -v '^[[:space:]]*$' <<<"$cleaned" || true)"
  if [[ ! "$first" =~ ^#[[:space:]]+[^[:space:]] ]]; then
    err "$name" "README.md must open with an H1 title (# <design name>)"
    ok=0
  fi

  # 3. Intro pitch: at least one line of prose (not a heading, image,
  #    or table row) before the first ## section.
  if ! awk '
      /^## /                                        { exit }
      !/^#/ && !/^!\[/ && !/^\|/ && !/^[ \t]*$/     { found = 1; exit }
      END                                           { exit !found }
    ' <<<"$cleaned"; then
    err "$name" "README.md needs an intro paragraph before the first ## section — pitch the design (what it is, who it is for)"
    ok=0
  fi

  # 4. Required sections, each non-empty.
  local section
  for section in "Print settings" "Parameters"; do
    if ! grep -qiE "^##[[:space:]]+${section}([[:space:]]|$)" <<<"$cleaned"; then
      err "$name" "README.md is missing a \"## ${section}\" section"
      ok=0
    elif ! section_has_content "$section" <<<"$cleaned"; then
      err "$name" "README.md \"## ${section}\" section is empty"
      ok=0
    fi
  done

  # 5. Images: at least one committed local preview, and every local
  #    reference must resolve. Remote http(s) images are allowed but don't
  #    satisfy the requirement — a dead URL is not a product page.
  local images has_local=0
  images="$(grep -oE '!\[[^]]*\]\([^)]+\)' <<<"$cleaned" \
            | sed -E 's/^!\[[^]]*\]\(([^) ]+).*$/\1/' || true)"
  if [[ -n "$images" ]]; then
    local img
    while IFS= read -r img; do
      [[ "$img" =~ ^https?:// ]] && continue
      has_local=1
      if [[ ! -f "${dir}/${img}" ]]; then
        err "$name" "README.md references a missing image: ${img}"
        ok=0
      fi
    done <<<"$images"
  fi
  if [[ "$has_local" == 0 ]]; then
    err "$name" "README.md needs at least one committed preview image (![...](previews/...)); remote URLs don't count"
    ok=0
  fi

  # 6. Animated previews: every animations.conf entry needs its committed
  #    GIF, embedded in the README, within the size budget (MAX_GIF_BYTES,
  #    shared with scripts/animate.sh via scripts/preview-budget.sh).
  local conf="${dir}/animations.conf"
  if [[ -f "$conf" ]]; then
    local anim gif bytes
    # `|| [[ -n ... ]]`: a final line without a trailing newline still makes
    # read populate the variable while returning nonzero — without the guard
    # that entry would silently escape the gate (false pass).
    while IFS= read -r anim || [[ -n "$anim" ]]; do
      anim="${anim%%#*}"
      anim="${anim%%|*}"
      anim="$(tr -d '[:space:]' <<<"$anim")"
      [[ -n "$anim" ]] || continue
      gif="previews/${anim}.gif"
      if [[ ! -f "${dir}/${gif}" ]]; then
        err "$name" "animations.conf lists \"${anim}\" but ${gif} is missing — run ./scripts/animate.sh ${name}"
        ok=0
        continue
      fi
      bytes="$(stat -c %s "${dir}/${gif}")"
      if (( bytes > MAX_GIF_BYTES )); then
        err "$name" "${gif} is $(( (bytes + 1023) / 1024 )) KiB, over the $((MAX_GIF_BYTES / 1024 / 1024)) MiB budget — fewer frames or a smaller size"
        ok=0
      fi
      if ! grep -qF "](${gif})" <<<"$cleaned"; then
        err "$name" "README.md doesn't embed ${gif} — an animation nobody sees isn't a product-page feature"
        ok=0
      fi
    done <"$conf"
  fi

  # 7. Product shots: every shots.conf entry needs its committed PNG,
  #    embedded in the README, within the size budget (MAX_SHOT_BYTES,
  #    shared with scripts/product-shot.sh via scripts/preview-budget.sh).
  local shotsconf="${dir}/shots.conf"
  if [[ -f "$shotsconf" ]]; then
    local shot png sbytes
    # same no-trailing-newline guard as the animations loop above
    while IFS= read -r shot || [[ -n "$shot" ]]; do
      shot="${shot%%#*}"
      shot="${shot%%|*}"
      shot="$(tr -d '[:space:]' <<<"$shot")"
      [[ -n "$shot" ]] || continue
      png="previews/${shot}.png"
      if [[ ! -f "${dir}/${png}" ]]; then
        err "$name" "shots.conf lists \"${shot}\" but ${png} is missing — run ./scripts/product-shot.sh ${name}"
        ok=0
        continue
      fi
      sbytes="$(stat -c %s "${dir}/${png}")"
      if (( sbytes > MAX_SHOT_BYTES )); then
        err "$name" "${png} is $(( (sbytes + 1023) / 1024 )) KiB, over the $((MAX_SHOT_BYTES / 1024 / 1024)) MiB budget — use a smaller size"
        ok=0
      fi
      if ! grep -qF "](${png})" <<<"$cleaned"; then
        err "$name" "README.md doesn't embed ${png} — a product shot nobody sees isn't a product page"
        ok=0
      fi
    done <"$shotsconf"
  fi

  # 8. Lineage credit. A derivative's product page documents the delta and
  #    links its base — that link is the only durable form the lineage takes.
  #    The Thingiverse-remix failure this answers is not that people refuse to
  #    credit: it is that the credit lives in a creation-time gesture nobody
  #    can repair afterwards, so a page that ships without it never gets one.
  #    Here the parent list comes from derives.conf, which the design has to
  #    keep accurate anyway (the render gate re-gates every derivative when a
  #    parent changes), so the page and the machinery cannot disagree.
  #    Whether derives.conf is itself well-formed is not asked here — a
  #    retired key or a parent that does not exist is `lineage check`'s
  #    finding, and reporting it twice in two voices helps nobody. This gate
  #    asks one question: does the page link the parents the resolver reports?
  local derives="${dir}/derives.conf"
  if [[ -f "$derives" ]]; then
    local parents parent parent_re
    if ! parents="$(./scripts/lineage.sh parents "$name")"; then
      err "$name" "could not read the lineage of a design that ships a derives.conf — run ./scripts/lineage.sh check"
      ok=0
      parents=""
    fi
    while IFS= read -r parent; do
      [[ -n "$parent" ]] || continue
      # Escape dots so a name containing one can't match a neighbour's path.
      # The terminator class is what keeps the match honest: without it a page
      # linking ../sushi-battleship-tall/ would satisfy a claim to derive from
      # sushi-battleship, crediting the wrong design.
      parent_re="${parent//./\\.}"
      if ! grep -qE "(\]\(|href=\"|href=')\.\./${parent_re}(/|/README\.md)?[\"')# ]" <<<"$cleaned"; then
        err "$name" "README.md never links its base — add a link to ../${parent}/ (derives.conf says this design reuses ${parent}'s geometry; a page that doesn't send the reader there is a remix with the lineage left out)"
        ok=0
      fi
    done <<<"$parents"
  fi

  # 9. Lifestyle (AI-styled) shots. Manifest-less on purpose: the presence of a
  #    committed previews/lifestyle-*.png IS the trigger, because an AI restyle
  #    cannot be regenerated from source. It is cosmetic and assumed
  #    geometrically approximate, so the gate never checks geometry — it checks
  #    the DISCLOSURE that keeps a cosmetic image off the page passing as a
  #    photo of the real print: embedded, in budget, an "AI-styled scene" alt
  #    label, and a visible warning note directly below the image (alt text
  #    isn't shown on the rendered page). See product-shots/SKILL.md, tier 2.
  local lf lrel lbytes verdict
  for lf in "${dir}"/previews/lifestyle-*.png; do
    [[ -e "$lf" ]] || continue          # no match: the glob stays literal, skip it
    lrel="previews/$(basename "$lf")"
    lbytes="$(stat -c %s "$lf")"
    if (( lbytes > MAX_SHOT_BYTES )); then
      err "$name" "${lrel} is $(( (lbytes + 1023) / 1024 )) KiB, over the $((MAX_SHOT_BYTES / 1024 / 1024)) MiB budget — use a smaller image"
      ok=0
    fi
    verdict="$(lifestyle_disclosure "$lrel" <<<"$cleaned")"
    case "$verdict" in
      OK) ;;
      MISSING_EMBED)
        err "$name" "commits ${lrel} but the README never embeds it — an AI-styled shot that isn't on the page can't carry its disclosure (embed it with the label and note, or drop the file)"
        ok=0 ;;
      MISSING_LABEL)
        err "$name" "${lrel} is embedded without an \"AI-styled scene\" alt label — the label is what marks the image AI-generated rather than a photo of the print"
        ok=0 ;;
      MISSING_NOTE)
        err "$name" "${lrel} is embedded without a visible warning note directly below it — alt text isn't shown on the rendered page, so add a line saying the image is AI-generated and its geometry approximate"
        ok=0 ;;
    esac
  done

  if [[ "$ok" == 1 ]]; then
    echo "ok    ${name}"
  fi
}

# --selftest: prove every lifestyle-disclosure failure still fires. Builds a
# throwaway design tree, points the gate at it via READMEGATE_DESIGNS_DIR, and
# asserts the verdict on a good fixture and one fixture per failure mode. This
# is the half the per-design gate on the real tree cannot cover: no
# lifestyle-*.png exists in designs/ yet, so without these fixtures the whole
# check could be weakened or deleted and every gate in the repo stays green.
# Mirrors scripts/lineage.sh selftest and scripts/guard-check.sh.
run_selftest() {
  local tmp
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064  # expand $tmp now, when the trap is installed
  trap "rm -rf '$tmp'" RETURN

  # Write a README that passes every OTHER requirement, so the only thing a
  # fixture can trip is the lifestyle check being probed. Echoes the dir path.
  _fixture() {
    local n="$1" d="$tmp/$1"
    mkdir -p "$d/previews"
    : >"$d/previews/contact.png"          # a normal committed preview (req 5)
    {
      printf '# %s\n\n' "$n"
      printf 'A throwaway fixture for the readme-gate selftest.\n\n'
      printf '![contact sheet](previews/contact.png)\n\n'
      printf '## Print settings\n\n- layer height: 0.2 mm\n\n'
      printf '## Parameters\n\n- `wall` — wall thickness (mm)\n'
    } >"$d/README.md"
    printf '%s' "$d"
  }

  local pass=1
  _check() {   # _check <name> <expected-rc> <needle>
    local n="$1" want_rc="$2" needle="$3" out rc=0
    out="$(READMEGATE_DESIGNS_DIR="$tmp" bash "$SELF" "$n" 2>&1)" || rc=$?
    if [[ "$rc" != "$want_rc" ]]; then
      echo "SELFTEST FAIL  ${n}: expected exit ${want_rc}, got ${rc}"
      sed 's/^/    /' <<<"$out"
      pass=0
      return
    fi
    if [[ -n "$needle" ]] && ! grep -qF "$needle" <<<"$out"; then
      echo "SELFTEST FAIL  ${n}: output missing \"${needle}\""
      sed 's/^/    /' <<<"$out"
      pass=0
      return
    fi
    echo "selftest ok    ${n} (${needle:-passes clean})"
  }

  local d

  # good: embedded, labeled, visible note directly below -> passes
  d="$(_fixture good)"
  : >"$d/previews/lifestyle-hero.png"
  {
    printf '\n![AI-styled scene: the fixture on a desk](previews/lifestyle-hero.png)\n\n'
    printf '*AI-generated impression for general illustration only — geometry is approximate and may not exactly match the printed part.*\n'
  } >>"$d/README.md"
  _check good 0 ""

  # missing-embed: committed PNG, never embedded -> MISSING_EMBED
  d="$(_fixture missing-embed)"
  : >"$d/previews/lifestyle-hero.png"
  _check missing-embed 1 "never embeds it"

  # over-budget: proper disclosure, but the PNG exceeds MAX_SHOT_BYTES
  d="$(_fixture over-budget)"
  truncate -s "$((MAX_SHOT_BYTES + 1))" "$d/previews/lifestyle-hero.png"
  {
    printf '\n![AI-styled scene: the fixture on a desk](previews/lifestyle-hero.png)\n\n'
    printf '*AI-generated impression, geometry approximate, may not match the print.*\n'
  } >>"$d/README.md"
  _check over-budget 1 "over the"

  # missing-label: embedded with a note, but no "AI-styled scene" alt label
  d="$(_fixture missing-label)"
  : >"$d/previews/lifestyle-hero.png"
  {
    printf '\n![The fixture on a desk](previews/lifestyle-hero.png)\n\n'
    printf '*AI-generated impression, geometry approximate, may not match the print.*\n'
  } >>"$d/README.md"
  _check missing-label 1 "AI-styled scene"

  # missing-note: labeled embed, but the paragraph below discloses nothing
  d="$(_fixture missing-note)"
  : >"$d/previews/lifestyle-hero.png"
  {
    printf '\n![AI-styled scene: the fixture on a desk](previews/lifestyle-hero.png)\n\n'
    printf 'Just some ordinary prose that discloses nothing.\n'
  } >>"$d/README.md"
  _check missing-note 1 "visible warning note"

  if [[ "$pass" == 1 ]]; then
    echo "ok    readme-gate --selftest: every lifestyle-disclosure guard fires"
    return 0
  fi
  echo "FAIL  readme-gate --selftest: a lifestyle-disclosure guard did not fire"
  return 1
}

if [[ "${1:-}" == "--selftest" ]]; then
  run_selftest || fail=1
elif [[ $# -ge 1 ]]; then
  check_one "$1"
else
  found=0
  for dir in "${ROOT}"/*/; do
    [[ -d "$dir" ]] || continue
    found=1
    check_one "$(basename "$dir")"
  done
  if [[ "$found" -eq 0 ]]; then
    echo "no designs found under ${ROOT}/"
  fi
fi

exit "$fail"
