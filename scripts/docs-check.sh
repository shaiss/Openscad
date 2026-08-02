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
#    layout docs (generated/infra dirs allowlisted). tools/ is expanded one
#    level: each tool is its own component with its own docs, and checking
#    only the `tools/` parent let tools/photoshot/ land undocumented in both
#    files while the check stayed green.
ALLOW=" build .git .claude .github "
dirs=()
for dir in */ .*/; do
  d="${dir%/}"
  [[ "$d" == "." || "$d" == ".." ]] && continue
  [[ "$ALLOW" == *" $d "* ]] && continue
  dirs+=("$d")
done
for dir in tools/*/; do
  [[ -d "$dir" ]] && dirs+=("${dir%/}")
done
for d in "${dirs[@]}"; do
  grep -qF "${d}/" CLAUDE.md || err "${d}/ not mentioned in CLAUDE.md"
  grep -qF "${d}/" README.md || err "${d}/ not mentioned in README.md"
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

# 4. The README gallery has one fresh row per design, no orphans.
./scripts/gallery.sh --check >/dev/null || err "README gallery is stale — run ./scripts/gallery.sh"

# 5. Freshness canary where docs quote reality: every file in scripts/ is
#    named in both CLAUDE.md and README.md. Boundary-aware match so e.g.
#    readme-gate.sh can't satisfy the check for gate.sh.
#
#    For CLAUDE.md the match is scoped to the `scripts/` layout bullet, not
#    the whole file. Matching anywhere is what let product-shot.sh land: it
#    was named in the Commands block, so the check passed while the layout
#    bullet — the one place claiming to enumerate the toolchain — silently
#    fell out of date. The bullet is one line starting "- `scripts/`".
# `--` before the pattern: it starts with "-", which grep would otherwise
# parse as an option bundle and reject.
scripts_bullet="$(grep -m1 -F -- '- `scripts/`' CLAUDE.md || true)"
[[ -n "$scripts_bullet" ]] \
  || err "CLAUDE.md has no '- \`scripts/\`' layout bullet to check against"
for f in scripts/*; do
  # regular files only: `scripts/*` also globs generated directories such as
  # __pycache__ (gitignored, but present after anything imports gate-summary),
  # and demanding those be documented is nonsense.
  [[ -f "$f" ]] || continue
  b="$(basename "$f")"
  b_re="${b//./\\.}"
  pat="(^|[^a-zA-Z0-9._-])${b_re}([^a-zA-Z0-9_-]|\$)"
  grep -qE "$pat" <<<"$scripts_bullet" \
    || err "scripts/${b} missing from CLAUDE.md's \`scripts/\` layout bullet"
  grep -qE "$pat" README.md || err "scripts/${b} not mentioned in README.md"
done

if [[ "$fail" == 0 ]]; then
  echo "ok    docs match the tree"
fi
exit "$fail"
