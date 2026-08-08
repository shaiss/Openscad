#!/usr/bin/env bash
# Proves the printer.conf mechanism (lib/printer-conf.scad, issue #101) still
# does what a design opts into it for: read the GENERIC DEFAULT when nothing is
# measured, and read the MEASURED VALUE when a printer.conf provides one — with
# that value reaching the exported geometry, not just an echo. Run by
# scripts/check.sh.
#
# Why a dedicated check, and not just the demo: check.sh renders the demo and
# greps for ERROR/WARNING, which proves the file BUILDS but says nothing about
# whether an override actually overrode. This is the same hole guard-check.sh
# and mate-check.sh exist to close — a mechanism a render cannot measure about
# itself. So this measures it, under two real configurations, and is written so
# it FAILS if the override ever stops taking:
#
#   * default case  — committed (inert) printer.conf: the resolved value is the
#     library default. Establishes the baseline.
#   * override case — a printer.conf on OPENSCADPATH (shadowing the repo-root
#     one, exactly how a user's real profile would sit ahead of it) sets a
#     sentinel. The resolved value must equal the sentinel AND differ from the
#     default, and the exported STL must differ from the default's. If the
#     include/override chain regressed to a no-op, the override case would read
#     the default and every assertion below would fire.
set -euo pipefail

cd "$(dirname "$0")/.."
export OPENSCADPATH="$PWD/lib:$PWD"

OPENSCAD_BIN="${OPENSCAD_BIN:-openscad}"
read -ra OSC_ARGS <<<"${OPENSCAD_ARGS:-}"

mkdir -p build
work="build/.printer-conf-case"
shadow="build/.printer-conf-shadow"
trap 'rm -rf "$work".scad "$work"-def.echo "$work"-ovr.echo \
      "$work"-def.stl "$work"-ovr.stl "$shadow"' EXIT

# Fixture: read the resolved clearance and both echo it and let it size a
# solid, so the same value is checked as a number and as geometry.
cat > "$work.scad" <<'EOF'
include <printer-conf.scad>
$fn = 16;
echo(resolved_xy_tol = printer_xy_tol);
cube([10 + printer_xy_tol, 10, 10]);
EOF

# Render helpers. Output is captured, not discarded: a successful render stays
# quiet, but a failure prints the OpenSCAD diagnostics (indented, with a FAIL
# prefix) before returning non-zero — so a broken render in this check, which
# scripts/check.sh runs unconditionally, is debuggable instead of a bare abort.
render() {  # format out scad [extra OPENSCADPATH prefix dir]
  local fmt="$1" out="$2" scad="$3" prefix="${4:-}"
  local path="$OPENSCADPATH" log
  [ -n "$prefix" ] && path="$prefix:$OPENSCADPATH"
  if ! log="$(OPENSCADPATH="$path" xvfb-run -a "$OPENSCAD_BIN" \
      ${OSC_ARGS[@]+"${OSC_ARGS[@]}"} \
      -o "$out" --export-format "$fmt" "$scad" 2>&1)"; then
    echo "FAIL  printer-conf: ${fmt} render failed for ${scad}" >&2
    sed 's/^/      /' <<<"$log" >&2
    return 1
  fi
}
render_echo() { render echo   "$2" "$1" "${3:-}"; }  # scad out.echo [prefix]
render_stl()  { render binstl "$2" "$1" "${3:-}"; }  # scad out.stl  [prefix]
resolved() {  # out.echo -> the number after "resolved_xy_tol = "
  sed -n 's/.*resolved_xy_tol = \([0-9.][0-9.]*\).*/\1/p' "$1" | head -1
}
# Numeric equality, tolerant of formatting (0.31 vs 0.3100).
num_eq() { awk -v a="$1" -v b="$2" 'BEGIN{exit !((a-b<1e-9)&&(b-a<1e-9))}'; }

fail=0
note() { echo "FAIL  printer-conf: $1"; fail=1; }

# --- default case: inert committed printer.conf ---
render_echo "$work.scad" "$work-def.echo"
default_val="$(resolved "$work-def.echo")"
if [ -z "$default_val" ]; then
  note "could not read the resolved clearance with the inert printer.conf"
  exit 1
fi

# --- override case: a printer.conf ahead on OPENSCADPATH ---
# Sentinel derived from the default so it is always different, whatever the
# library default happens to be — the check never hardcodes 0.2.
sentinel="$(awk -v d="$default_val" 'BEGIN{printf "%.4f", d+0.11}')"
mkdir -p "$shadow"
printf 'printer_xy_tol = %s;\n' "$sentinel" > "$shadow/printer.conf"
render_echo "$work.scad" "$work-ovr.echo" "$shadow"
override_val="$(resolved "$work-ovr.echo")"

if [ -z "$override_val" ]; then
  note "could not read the resolved clearance with an override printer.conf"
elif ! num_eq "$override_val" "$sentinel"; then
  note "override did not take: printer.conf set $sentinel but the design resolved $override_val"
elif num_eq "$override_val" "$default_val"; then
  note "override equals the default ($default_val) — nothing proves the profile changed anything"
else
  echo "ok    printer-conf resolves default=$default_val, override=$override_val (profile wins)"
fi

# --- geometry: the override must reach the exported mesh, not only the echo ---
render_stl "$work.scad" "$work-def.stl"
render_stl "$work.scad" "$work-ovr.stl" "$shadow"
if cmp -s "$work-def.stl" "$work-ovr.stl"; then
  note "the two profiles export an identical STL — the clearance never reached the geometry"
else
  echo "ok    printer-conf override reaches the exported geometry (STLs differ)"
fi

exit "$fail"
