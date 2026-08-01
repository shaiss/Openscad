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
#   4. show at least one preview image, and every local image it
#      references must exist (relative to the design directory)
#   5. contain non-empty "## Print settings" and "## Parameters" sections
#
# templates/README.md is a skeleton that passes once filled in.
# NOTES.md remains the engineering log; README.md is the product page.
set -euo pipefail

cd "$(dirname "$0")/.."

fail=0

err() {
  echo "FAIL  $1: $2"
  fail=1
}

# Does the README have a "## <section>" heading (case-insensitive) with at
# least one non-blank line of content before the next heading?
section_has_content() {
  local readme="$1" section="$2"
  awk -v want="$(tr '[:upper:]' '[:lower:]' <<<"$section")" '
    tolower($0) ~ ("^##[ \t]+" want "([ \t]|$)") { insec = 1; next }
    insec && /^#/                                { exit }
    insec && !/^[ \t]*$/                         { found = 1; exit }
    END                                          { exit !found }
  ' "$readme"
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

  # 1. Title: the first non-blank line must be an H1.
  local first
  first="$(grep -m1 -v '^[[:space:]]*$' "$readme" || true)"
  if [[ ! "$first" =~ ^#[^#] ]]; then
    err "$name" "README.md must open with an H1 title (# <design name>)"
    ok=0
  fi

  # 2. Intro pitch: at least one line of prose (not a heading, image,
  #    or table row) before the first ## section.
  if ! awk '
      /^## /                                        { exit }
      !/^#/ && !/^!\[/ && !/^\|/ && !/^[ \t]*$/     { found = 1; exit }
      END                                           { exit !found }
    ' "$readme"; then
    err "$name" "README.md needs an intro paragraph before the first ## section — pitch the design (what it is, who it is for)"
    ok=0
  fi

  # 3. Required sections, each non-empty.
  local section
  for section in "Print settings" "Parameters"; do
    if ! grep -qiE "^##[[:space:]]+${section}([[:space:]]|$)" "$readme"; then
      err "$name" "README.md is missing a \"## ${section}\" section"
      ok=0
    elif ! section_has_content "$readme" "$section"; then
      err "$name" "README.md \"## ${section}\" section is empty"
      ok=0
    fi
  done

  # 4. Images: at least one, and every local reference must resolve.
  local images
  images="$(grep -oE '!\[[^]]*\]\([^)]+\)' "$readme" \
            | sed -E 's/^!\[[^]]*\]\(([^) ]+).*$/\1/' || true)"
  if [[ -z "$images" ]]; then
    err "$name" "README.md needs at least one preview image (![...](previews/...))"
    ok=0
  else
    local img
    while IFS= read -r img; do
      [[ "$img" =~ ^https?:// ]] && continue
      if [[ ! -f "${dir}/${img}" ]]; then
        err "$name" "README.md references a missing image: ${img}"
        ok=0
      fi
    done <<<"$images"
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
