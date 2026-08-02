#!/bin/bash
# SessionStart hook: install the OpenSCAD toolchain in Claude Code on the web.
# The repo needs: openscad (renderer), xvfb (headless display), imagemagick
# (montage, for multi-view preview sheets), bpy (Blender as a Python module —
# studio product shots via ./scripts/product-shot.sh), prusa-slicer +
# printcheck (so
# ./scripts/gate.sh --slice — the exact gate CI runs — works locally before
# a push). Idempotent — exits fast when everything is already present
# (e.g. cached container state).
set -euo pipefail

# --force: install even outside Claude Code on the web (manual invocation);
# without it the hook is a silent no-op on local machines.
if [ "${1:-}" != "--force" ] && [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# find_spec rather than `import bpy`: importing Blender costs seconds and
# hundreds of MB, and this guard runs on every session start.
has_bpy() {
  python3 -c 'import importlib.util,sys; sys.exit(0 if importlib.util.find_spec("bpy") else 1)' \
    >/dev/null 2>&1
}

if command -v openscad >/dev/null 2>&1 \
  && command -v xvfb-run >/dev/null 2>&1 \
  && command -v montage >/dev/null 2>&1 \
  && has_bpy \
  && command -v prusa-slicer >/dev/null 2>&1 \
  && command -v printcheck >/dev/null 2>&1 \
  && command -v stylelift >/dev/null 2>&1 \
  && command -v pytest >/dev/null 2>&1; then
  echo "OpenSCAD toolchain already installed"
  exit 0
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

export DEBIAN_FRONTEND=noninteractive
# Package indexes in the base image can be stale (404s on install); refresh
# first and tolerate unrelated repo failures (e.g. blocked PPAs).
$SUDO apt-get update -qq 2>/dev/null || true
$SUDO apt-get install -y -qq openscad xvfb imagemagick prusa-slicer

# Blender ships on PyPI as `bpy`, a self-contained Python module — no apt
# package, no X display. Pinned to the 4.5 LTS series: product shots are
# byte-reproducible across point releases within a series, but not necessarily
# across them, and the committed PNGs are diffed. Wheels are built per Python
# minor version, so this needs the interpreter Blender 4.5 targets (3.11).
if ! has_bpy; then
  pip install -q 'bpy~=4.5.0'
fi

# [test] extra brings pytest, so /preflight can run the unit tests locally
# exactly as CI does
if ! command -v printcheck >/dev/null 2>&1 || ! command -v pytest >/dev/null 2>&1; then
  pip install -q -e "$REPO_DIR/tools/printcheck[test]"
fi
# stylelift backs scripts/style-lift.sh and the style gate; same mesh stack
if ! command -v stylelift >/dev/null 2>&1; then
  pip install -q -e "$REPO_DIR/tools/stylelift[test]"
fi

echo "Installed: $(openscad --version 2>&1); prusa-slicer + printcheck + stylelift ready"
