#!/usr/bin/env bash
# Append a FIELD-TEST entry to a design's NOTES.md (issue #101). This is the
# formatting-and-file half of the "Log a print result" GitHub Action
# (.github/workflows/log-print-result.yml) — kept in a script, not buried in
# workflow YAML, so it is testable: `--selftest` is run by scripts/check.sh.
#
# Usage:
#   scripts/field-test.sh --design <name> --printer <p> --result <r> \
#       [--settings <s>] [--deviations <d>] [--carry <c>] \
#       [--parts <what>] [--date <YYYY-MM-DD>]
#   scripts/field-test.sh --selftest
#
# Required: --design, --printer, --result. The design must exist
# (designs/<name>/<name>.scad). The "## Field test log" section is created at
# the end of NOTES.md when absent; entries append to the end, so keep that
# section last (see templates/FIELD-TEST.md and docs/print-feedback.md).
#
# --notes-file <path> overrides the resolved NOTES.md (used by --selftest);
# with it, --design is not required and no design lookup happens.
set -euo pipefail

# Absolute path to this script, captured before the cd below so --selftest can
# re-invoke the real CLI end-to-end.
SELF="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)/$(basename "$0")"
cd "$(dirname "$0")/.."

die() { echo "field-test: $*" >&2; exit 1; }

# One entry block on stdout. Unset optional fields render as an em dash (or
# "none" for carry-forward) so the shape is always complete.
format_entry() {  # date printer parts settings result deviations carry
  printf '### %s — %s\n' "$1" "$2"
  printf -- '- **Part(s):** %s\n' "${3:-—}"
  printf -- '- **Slicer settings:** %s\n' "${4:-—}"
  printf -- '- **Result:** %s\n' "$5"
  printf -- '- **Measured deviations:** %s\n' "${6:-—}"
  printf -- '- **Carry forward:** %s\n' "${7:-none}"
}

# Append an entry to a NOTES.md, creating the section header once if needed.
append_entry() {  # notes date printer parts settings result deviations carry
  local notes="$1"; shift
  [ -f "$notes" ] || die "no such NOTES.md: $notes"
  if ! grep -qF '## Field test log' "$notes"; then
    {
      printf '\n## Field test log\n\n'
      printf '_Real prints of this design, newest at the bottom. See '
      printf 'templates/FIELD-TEST.md and docs/print-feedback.md._\n'
    } >> "$notes"
  fi
  printf '\n%s\n' "$(format_entry "$@")" >> "$notes"
}

# Validate a design name (path safety) and that it exists.
validate_design() {  # name
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "invalid design name: '$1'"
  [ -f "designs/$1/$1.scad" ] || die "no such design: designs/$1/$1.scad"
}

selftest() {
  local tmp notes rc out headers entries
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  notes="$tmp/NOTES.md"
  printf '# demo\n\n## Goal\nx\n' > "$notes"

  # 1. First entry creates the section and lands the fields.
  "$SELF" --notes-file "$notes" --printer "Bambu A1" \
    --result "slot fit snug" --deviations "slot 0.15 mm tight" \
    --date 2026-01-02 >/dev/null || die "selftest: first append failed"
  grep -qF '## Field test log' "$notes" || die "selftest: section not created"
  grep -qF '### 2026-01-02 — Bambu A1' "$notes" || die "selftest: entry header missing"
  grep -qF 'slot 0.15 mm tight' "$notes" || die "selftest: deviations not written"

  # 2. Second entry reuses the one section and adds a second entry.
  "$SELF" --notes-file "$notes" --printer "Prusa MK4" \
    --result "loose" --date 2026-01-03 >/dev/null || die "selftest: second append failed"
  headers="$(grep -cF '## Field test log' "$notes")"
  [ "$headers" = 1 ] || die "selftest: expected exactly one section header, got $headers"
  entries="$(grep -cE '^### ' "$notes")"
  [ "$entries" = 2 ] || die "selftest: expected two entries, got $entries"

  # 3. Missing required field is refused.
  rc=0; out="$("$SELF" --notes-file "$notes" --printer p 2>&1)" || rc=$?
  [ "$rc" -ne 0 ] || die "selftest: missing --result was accepted"
  grep -qi 'result' <<<"$out" || die "selftest: missing-result message unclear: $out"

  # 4. An invalid design name is refused (path safety).
  rc=0; "$SELF" --design "../etc" --printer p --result r >/dev/null 2>&1 || rc=$?
  [ "$rc" -ne 0 ] || die "selftest: invalid design name was accepted"

  # 5. A nonexistent design is refused.
  rc=0; "$SELF" --design no-such-design-xyz --printer p --result r >/dev/null 2>&1 || rc=$?
  [ "$rc" -ne 0 ] || die "selftest: nonexistent design was accepted"

  echo "ok    field-test.sh selftest passed"
}

# --- argument parsing -------------------------------------------------------
design="" printer="" result="" settings="" deviations="" carry="" parts=""
date="" notes_override=""
while [ $# -gt 0 ]; do
  case "$1" in
    --selftest)    selftest; exit 0 ;;
    --design)      design="$2"; shift 2 ;;
    --printer)     printer="$2"; shift 2 ;;
    --result)      result="$2"; shift 2 ;;
    --settings)    settings="$2"; shift 2 ;;
    --deviations)  deviations="$2"; shift 2 ;;
    --carry)       carry="$2"; shift 2 ;;
    --parts)       parts="$2"; shift 2 ;;
    --date)        date="$2"; shift 2 ;;
    --notes-file)  notes_override="$2"; shift 2 ;;
    -h|--help)     grep '^#' "$SELF" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)             die "unknown argument: $1" ;;
  esac
done

[ -n "$printer" ] || die "--printer is required"
[ -n "$result" ]  || die "--result is required"
[ -n "$date" ]    || date="$(date -u +%F)"

if [ -n "$notes_override" ]; then
  notes="$notes_override"
else
  [ -n "$design" ] || die "--design is required"
  validate_design "$design"
  notes="designs/$design/NOTES.md"
fi

append_entry "$notes" "$date" "$printer" "$parts" "$settings" "$result" \
  "$deviations" "$carry"
echo "field-test: appended a ${date} entry to $notes"
