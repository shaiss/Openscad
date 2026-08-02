#!/usr/bin/env bash
# Docs-drift check: assert the docs match the tree, so staleness fails fast.
# Run by check.sh (and therefore by /preflight and CI's scad-check jobs).
#
# Scope discipline (deliberate, keep it this way): every check here is a
# MECHANICAL fact — a file exists, a name is mentioned — verified with
# test/grep against the filesystem. The moment a check tries to verify a
# prose claim ("gate.sh --slice is what CI enforces") it becomes flaky and
# earns deletion. Judgment calls about prose belong to reviewer skills,
# not bash.
set -euo pipefail

cd "$(dirname "$0")/.."

fail=0
err() { echo "FAIL  docs: $1"; fail=1; }

# 1. Every top-level directory appears in CLAUDE.md's and README.md's
#    layout docs (generated/infra dirs allowlisted).
ALLOW=" build .git .claude .github "
for dir in */ .*/; do
  d="${dir%/}"
  [[ "$d" == "." || "$d" == ".." ]] && continue
  [[ "$ALLOW" == *" $d "* ]] && continue
  grep -q "${d}/" CLAUDE.md || err "top-level ${d}/ not mentioned in CLAUDE.md"
  grep -q "${d}/" README.md || err "top-level ${d}/ not mentioned in README.md"
done

# 2. Skills <-> CLAUDE.md, both directions. Boundary-aware match so a
#    longer name (e.g. /resume-design) can't satisfy a shorter one.
for skill in .claude/skills/*/; do
  s="$(basename "$skill")"
  grep -qE "/${s}([^a-z0-9-]|\$)" CLAUDE.md \
    || err "skill .claude/skills/${s} not mentioned in CLAUDE.md"
done
while read -r ref; do
  [[ -d ".claude/skills/${ref}" ]] \
    || err "CLAUDE.md names skill /${ref} but .claude/skills/${ref} does not exist"
done < <(grep -oE '`/[a-z0-9-]+' CLAUDE.md | sed 's|^`/||' | sort -u)

# 3. Every design ships the NOTES.md the co-design workflow requires
#    (README.md is readme-gate.sh's job).
for dir in designs/*/; do
  n="$(basename "$dir")"
  [[ -f "designs/${n}/${n}.scad" ]] || continue
  [[ -f "designs/${n}/NOTES.md" ]] || err "designs/${n}/ has no NOTES.md"
done

# 3b. Every style ships a complete pack, and appears in the styles catalog.
#     (The pack's internal consistency — style.scad and STYLE.md matching
#     style.json — is scripts/style-check.sh's job; this is the file census.)
for dir in styles/*/; do
  n="$(basename "$dir")"
  [[ -f "styles/${n}/style.json" ]] || continue
  for f in STYLE.md style.scad swatch.scad; do
    [[ -f "styles/${n}/${f}" ]] || err "styles/${n}/ has no ${f}"
  done
  grep -q "${n}/STYLE.md" styles/README.md \
    || err "style ${n} is not listed in styles/README.md"
done

# 4. The README gallery has one fresh row per design, no orphans.
./scripts/gallery.sh --check >/dev/null || err "README gallery is stale — run ./scripts/gallery.sh"

# 5. Freshness canary where docs quote reality: every file in scripts/ is
#    named in both CLAUDE.md and README.md. Boundary-aware match so e.g.
#    readme-gate.sh can't satisfy the check for gate.sh.
for f in scripts/*; do
  b="$(basename "$f")"
  b_re="${b//./\\.}"
  pat="(^|[^a-zA-Z0-9._-])${b_re}([^a-zA-Z0-9_-]|\$)"
  grep -qE "$pat" CLAUDE.md || err "scripts/${b} not mentioned in CLAUDE.md"
  grep -qE "$pat" README.md || err "scripts/${b} not mentioned in README.md"
done

if [[ "$fail" == 0 ]]; then
  echo "ok    docs match the tree"
fi
exit "$fail"
