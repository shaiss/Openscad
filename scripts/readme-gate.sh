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
#
# Fenced code blocks and HTML comments are ignored throughout: an example
# snippet or commented-out line is not page content, so it neither
# satisfies a requirement nor trips one.
#
# templates/README.md is a skeleton that passes once filled in.
# NOTES.md remains the engineering log; README.md is the product page.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/preview-budget.sh
# defines MAX_GIF_BYTES (shared with animate.sh) and MAX_SHOT_BYTES (the
# product-shot budget enforced below)
. scripts/preview-budget.sh

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

check_one() {
  local name="$1"
  local dir="designs/${name}"
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

  if [[ "$ok" == 1 ]]; then
    echo "ok    ${name}"
  fi
}

if [[ $# -ge 1 ]]; then
  check_one "$1"
else
  found=0
  for dir in designs/*/; do
    [[ -d "$dir" ]] || continue
    found=1
    check_one "$(basename "$dir")"
  done
  if [[ "$found" -eq 0 ]]; then
    echo "no designs found under designs/"
  fi
fi

exit "$fail"
