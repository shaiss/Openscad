#!/usr/bin/env bash
# Build the static product site from the committed designs and styles.
#   ./scripts/site.sh           # build into build/site
#   ./scripts/site.sh --serve   # build, then serve it at http://localhost:8000
#
# This runs the same build command Vercel runs (see vercel.json), so a green
# run here means the deploy builds too. The build fails on any local reference
# that does not resolve — a broken link stops it rather than becoming a 404 in
# production.
#
# It also runs the site's own unit tests first, which the deploy does not.
# They are what holds site/lib/lineage.mjs to tools/lineage: the site cannot
# call the Python resolver (Vercel installs npm deps only), so it ports it,
# and a port that nothing cross-checks is how the site and the README gallery
# came to disagree about what a design is in the first place (issue #55).
set -euo pipefail

cd "$(dirname "$0")/.."

SERVE=0
for arg in "$@"; do
  case "$arg" in
    --serve) SERVE=1 ;;
    *) echo "error: unknown flag $arg" >&2; exit 2 ;;
  esac
done

command -v node >/dev/null || {
  echo "error: node is not on PATH (the site generator is a Node script)" >&2
  exit 2
}

# npm ci needs the lockfile and wipes node_modules; only worth it when the
# tree is missing or stale relative to the lockfile.
if [ ! -d site/node_modules ] || [ site/package-lock.json -nt site/node_modules ]; then
  echo "== installing site dependencies =="
  npm --prefix site ci
fi

echo "== site unit tests =="
npm --prefix site test

node site/build.mjs --out build/site

if [ "$SERVE" == 1 ]; then
  echo
  echo "serving build/site at http://localhost:8000 (ctrl-c to stop)"
  cd build/site
  exec python3 -m http.server 8000
fi
