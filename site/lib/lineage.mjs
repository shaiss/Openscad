// Lineage: which designs are derivatives, and of what.
//
// A port of tools/lineage (the Python resolver), rule for rule, for the same
// reason content.mjs's pitch() is a port of the one in scripts/gallery.sh: the
// site and the README gallery must agree about what a design *is*, and the
// deploy cannot run the resolver. vercel.json pins the build to
// `npm --prefix site ci` + `node site/build.mjs` — no Python, no ./scripts —
// so shelling out to ./scripts/lineage.sh is not available here.
//
// A port is a drift risk, which is the exact failure issue #55 was filed for.
// It is held to the original by site/test/lineage.test.mjs, which runs BOTH
// implementations over the same fixture trees and fails on any disagreement
// about order or parentage. Change a rule here without changing it there and
// that test says so.

/** The only keys a derives.conf may carry (conf.py KEYS). */
export const KEYS = ["variant-of", "derivative-of", "replaces", "diamond-ok"];

/**
 * Keys whose values are parent design names. The combined ordered parent list
 * is every parent-bearing line in FILE order, left to right within a line,
 * because that order has to match the entry .scad's include order — include
 * order is what silently decides which parent wins when two of them define
 * the same module.
 */
export const PARENT_KEYS = ["variant-of", "derivative-of"];

/**
 * Keys retired from an earlier draft of the format; never accepted silently.
 * Exported so the test can hold all three key sets against conf.py's.
 */
export const RETIRED_KEYS = new Set(["reuses"]);

/**
 * Parse a derives.conf, collecting problems instead of throwing — one bad
 * line must not hide the rest of the file.
 *
 * The site only needs the parent list, but the parse rules have to match
 * conf.py exactly or the two surfaces disagree about who the parent is.
 * The subtle one is that **trailing** comments are stripped, not just
 * whole-line ones: no legal value can contain '#', and without it
 * `variant-of: base  # the tray` parses as a parent named "base  # the tray".
 */
export function parseDerivesConf(text) {
  const entries = [];
  const problems = [];
  const seen = new Map();

  const raw = text.split("\n");
  for (let i = 0; i < raw.length; i++) {
    const lineno = i + 1;
    const line = raw[i].split("#", 1)[0].trim();
    if (!line) continue;

    if (!line.includes(":")) {
      problems.push(`line ${lineno}: '${line}' has no ':'`);
      continue;
    }
    const at = line.indexOf(":");
    const key = line.slice(0, at).trim();
    const value = line.slice(at + 1);

    if (RETIRED_KEYS.has(key)) {
      problems.push(`line ${lineno}: '${key}:' is retired`);
      continue;
    }
    if (!KEYS.includes(key)) {
      problems.push(`line ${lineno}: unknown key '${key}'`);
      continue;
    }
    if (seen.has(key)) {
      problems.push(`line ${lineno}: duplicate key '${key}' (already on line ${seen.get(key)})`);
      continue;
    }
    seen.set(key, lineno);

    const values = value
      .split(",")
      .map((v) => v.trim())
      .filter(Boolean);
    entries.push({ lineno, key, values, raw: line });
  }

  return { entries, problems };
}

/** Every declared parent, in the order the includes must appear in. */
export function declaredParents(conf) {
  const out = [];
  for (const e of conf.entries) {
    if (PARENT_KEYS.includes(e.key)) out.push(...e.values);
  }
  return out;
}

/**
 * Resolve a set of designs into traversable parentage and gallery order.
 *
 * `names` is every design that exists; `declared` maps a name to its declared
 * parents (in include order, unfiltered).
 *
 * Returns:
 *   parents      name -> declared parents that are REAL designs, deduped,
 *                order preserved. Filtered for the same reason graph.py
 *                filters: every consumer turns a parent name into a path, so
 *                handing back a name with no design behind it produces a link
 *                that 404s. A parent that is not a design is `lineage check`'s
 *                finding and only its finding.
 *   order        [{depth, name, parent}] — roots alphabetically, each
 *                immediately followed by its descendants depth-first and
 *                alphabetical among siblings. A multi-parent design appears
 *                exactly once, under its FIRST declared real parent.
 *   unreachable  designs `order` could not place, i.e. designs sitting on a
 *                lineage cycle. The Python `order` exits 1 on a cycle; the
 *                caller here is expected to fail the build rather than
 *                quietly ship a site with designs missing from the index.
 */
export function resolveLineage(names, declared) {
  const known = new Set(names);
  const parents = new Map();

  for (const name of names) {
    const seen = new Set();
    const list = [];
    for (const parent of declared.get(name) || []) {
      if (known.has(parent) && parent !== name && !seen.has(parent)) {
        seen.add(parent);
        list.push(parent);
      }
    }
    parents.set(name, list);
  }

  const sorted = [...names].sort();
  const kids = new Map();
  const roots = [];
  for (const name of sorted) {
    // "First" is the same order that decides include precedence, so the tree a
    // reader sees matches the file OpenSCAD reads.
    const primary = parents.get(name)[0] ?? null;
    if (primary === null) roots.push(name);
    else {
      if (!kids.has(primary)) kids.set(primary, []);
      kids.get(primary).push(name);
    }
  }

  const order = [];
  const placed = new Set();
  const walk = (name, depth, parent) => {
    order.push({ depth, name, parent });
    placed.add(name);
    for (const kid of [...(kids.get(name) || [])].sort()) walk(kid, depth + 1, name);
  };
  for (const root of roots) walk(root, 0, "");

  // Each design has at most one primary parent, so the kid graph is a forest
  // plus any cycles among non-roots — those are unreachable from a root rather
  // than infinitely recursive, and fall out here.
  const unreachable = sorted.filter((n) => !placed.has(n));

  return { parents, order, unreachable };
}
