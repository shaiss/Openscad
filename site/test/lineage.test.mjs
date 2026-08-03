// The site's lineage port, held to the resolver it was ported from.
//
// site/lib/lineage.mjs re-implements tools/lineage in JS because the deploy
// cannot run Python (vercel.json pins the build to `npm ci` + `node
// build.mjs`). A re-implementation is a drift risk, and two surfaces of this
// repo disagreeing about what a design *is* is exactly what issue #55 was
// filed for — so every case below runs BOTH implementations over the same
// fixture tree and fails on any disagreement about order or parentage.
//
// The Python side is invoked the way scripts/lineage.sh invokes it, via
// PYTHONPATH against the source tree, so this tests the resolver in the repo
// rather than an installed copy of it.

import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

import { readDesigns } from "../lib/content.mjs";
import { indexPage, designPage } from "../lib/templates.mjs";
import { parseDerivesConf, declaredParents, resolveLineage } from "../lib/lineage.mjs";

const REPO_ROOT = fileURLToPath(new URL("../..", import.meta.url));

/**
 * Build a throwaway designs/ tree.
 *
 * `spec` maps a design name to its derives.conf contents (null for a design
 * that has none). Every design gets the entry .scad and README.md that
 * readDesigns and the Python discovery both require.
 */
function fixture(spec) {
  const root = mkdtempSync(join(tmpdir(), "print-bench-lineage-"));
  for (const [name, derives] of Object.entries(spec)) {
    const dir = join(root, "designs", name);
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, `${name}.scad`), "// lineage fixture\n");
    writeFileSync(join(dir, "README.md"), `# ${name}\n\nThe ${name} design.\n`);
    if (derives !== null) writeFileSync(join(dir, "derives.conf"), derives);
  }
  return root;
}

/** Run the Python resolver the way scripts/lineage.sh does. */
function lineageCli(root, args) {
  const res = spawnSync("python3", ["-m", "lineage.cli", ...args, "--root", root], {
    encoding: "utf8",
    env: { ...process.env, PYTHONPATH: join(REPO_ROOT, "tools", "lineage", "src") },
  });
  if (res.error) {
    // Never skip: a cross-check that quietly does not run is indistinguishable
    // from one that passes, and this is the only thing keeping the two
    // implementations honest.
    assert.fail(
      `could not run the Python resolver (${res.error.message}). ` +
        "python3 is required to cross-check site/lib/lineage.mjs against tools/lineage."
    );
  }
  return res;
}

/** `lineage order` as [{depth, name, parent}]. */
function pythonOrder(root) {
  const res = lineageCli(root, ["order"]);
  assert.equal(res.status, 0, `lineage order failed: ${res.stderr}`);
  return res.stdout
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [depth, name, parent] = line.split("\t");
      return { depth: Number(depth), name, parent: parent ?? "" };
    });
}

/** `lineage parents <name>` as an ordered array. */
function pythonParents(root, name) {
  const res = lineageCli(root, ["parents", name]);
  assert.equal(res.status, 0, `lineage parents ${name} failed: ${res.stderr}`);
  return res.stdout.split("\n").filter(Boolean);
}

/** The JS side, from the same tree. */
function jsLineage(root) {
  const designs = readDesigns(root);
  return {
    designs,
    order: designs.map((d) => ({
      depth: d.depth,
      name: d.name,
      parent: d.parents.length ? d.parents[0] : "",
    })),
  };
}

/**
 * The assertion this file exists for: both implementations, one tree, no
 * disagreement — about row order, nesting depth, the parent each design nests
 * under, or the full include-ordered parent list.
 */
function assertAgreement(root, designNames) {
  const { order } = jsLineage(root);
  assert.deepEqual(order, pythonOrder(root), "site and tools/lineage disagree about gallery order");
  for (const name of designNames) {
    const js = readDesigns(root).find((d) => d.name === name);
    assert.deepEqual(
      js.parents,
      pythonParents(root, name),
      `site and tools/lineage disagree about the parents of ${name}`
    );
  }
}

test("issue #55 reproduction: a derivative nests under its parent, not beside it", () => {
  const root = fixture({
    "calibration-cube": null,
    sderiv: "variant-of: calibration-cube\n",
  });
  try {
    assertAgreement(root, ["calibration-cube", "sderiv"]);

    const designs = readDesigns(root);
    assert.deepEqual(
      designs.map((d) => [d.depth, d.name]),
      [
        [0, "calibration-cube"],
        [1, "sderiv"],
      ]
    );

    const html = indexPage(designs);
    // The derivative is marked as one and credits its parent. Before the fix
    // this emitted href="/designs/sderiv/" as a flat sibling with zero
    // lineage text anywhere on the page.
    assert.match(html, /card card-derived/);
    assert.match(html, /derived from <a href="\/designs\/calibration-cube\/">calibration-cube<\/a>/);
    // The parent is not marked as a derivative of anything.
    assert.equal((html.match(/card-derived/g) || []).length, 1);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a derivative's design page credits and links its parent", () => {
  const root = fixture({ base: null, child: "variant-of: base\n" });
  try {
    const child = readDesigns(root).find((d) => d.name === "child");
    const html = designPage(child, {
      html: "<p>body</p>",
      toc: "",
      githubBase: "https://example.invalid",
      configurator: null,
    });
    assert.match(html, /<h3>Derived from<\/h3>/);
    assert.match(html, /<a href="\/designs\/base\/">base<\/a>/);

    const base = readDesigns(root).find((d) => d.name === "base");
    const baseHtml = designPage(base, {
      html: "<p>body</p>",
      toc: "",
      githubBase: "https://example.invalid",
      configurator: null,
    });
    assert.doesNotMatch(baseHtml, /Derived from/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("multi-parent: every parent named, in include order, last include wins", () => {
  const root = fixture({
    "base-a": null,
    "base-b": null,
    multi: "variant-of: base-a, base-b\n",
  });
  try {
    assertAgreement(root, ["base-a", "base-b", "multi"]);

    const designs = readDesigns(root);
    const multi = designs.find((d) => d.name === "multi");
    assert.deepEqual(multi.parents, ["base-a", "base-b"]);

    // Word for word the sentence scripts/gallery.sh writes into the README.
    const html = indexPage(designs);
    assert.match(
      html,
      /derived from <a href="\/designs\/base-a\/">base-a<\/a>, then <a href="\/designs\/base-b\/">base-b<\/a> — last include wins/
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a derivative of a derivative steps in one more level", () => {
  const root = fixture({
    root: null,
    mid: "variant-of: root\n",
    leaf: "variant-of: mid\n",
  });
  try {
    assertAgreement(root, ["root", "mid", "leaf"]);
    assert.deepEqual(
      readDesigns(root).map((d) => [d.depth, d.name]),
      [
        [0, "root"],
        [1, "mid"],
        [2, "leaf"],
      ]
    );
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a parent that is not a design is dropped, so no credit can 404", () => {
  const root = fixture({
    "real-base": null,
    child: "variant-of: real-base, ghost-design\n",
  });
  try {
    // `lineage check` is what reports the ghost; `parents` filters it so every
    // consumer that turns a parent into a path stays total.
    assertAgreement(root, ["real-base", "child"]);
    const child = readDesigns(root).find((d) => d.name === "child");
    assert.deepEqual(child.parents, ["real-base"]);

    const html = indexPage(readDesigns(root));
    assert.doesNotMatch(html, /ghost-design/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("derives.conf parsing matches conf.py: trailing comments, keys, duplicates", () => {
  // The one that bites: without stripping the trailing comment this parses as
  // a parent literally named "base  # the tray".
  const trailing = parseDerivesConf("variant-of: base  # the tray\n");
  assert.deepEqual(declaredParents(trailing), ["base"]);
  assert.deepEqual(trailing.problems, []);

  const both = parseDerivesConf("variant-of: a\nderivative-of: b\n");
  assert.deepEqual(declaredParents(both), ["a", "b"]);

  assert.equal(parseDerivesConf("# just a comment\n\n").entries.length, 0);
  assert.equal(parseDerivesConf("variant-of base\n").problems.length, 1);
  assert.equal(parseDerivesConf("bogus-key: x\n").problems.length, 1);
  assert.equal(parseDerivesConf("reuses: x\n").problems.length, 1);
  assert.equal(parseDerivesConf("variant-of: a\nvariant-of: b\n").problems.length, 1);
  // replaces/diamond-ok parse but name no parents.
  assert.deepEqual(declaredParents(parseDerivesConf("replaces: base:lid\n")), []);
});

test("a design on a lineage cycle is still listed, and flagged for the build to reject", () => {
  const { order, unreachable, parents } = resolveLineage(
    ["loop-a", "loop-b"],
    new Map([
      ["loop-a", ["loop-b"]],
      ["loop-b", ["loop-a"]],
    ])
  );
  assert.deepEqual(order, []);
  assert.deepEqual(unreachable, ["loop-a", "loop-b"]);
  assert.deepEqual(parents.get("loop-a"), ["loop-b"]);

  const root = fixture({
    "loop-a": "variant-of: loop-b\n",
    "loop-b": "variant-of: loop-a\n",
  });
  try {
    const designs = readDesigns(root);
    // Never silently drop a design from the index...
    assert.deepEqual(designs.map((d) => d.name).sort(), ["loop-a", "loop-b"]);
    // ...but do mark it, so build.mjs fails the way `lineage order` does.
    assert.ok(designs.every((d) => d.lineageCycle));
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("a tree with no derivatives is unchanged: flat, alphabetical, no lineage text", () => {
  const root = fixture({ alpha: null, beta: null, gamma: null });
  try {
    assertAgreement(root, ["alpha", "beta", "gamma"]);
    const designs = readDesigns(root);
    assert.deepEqual(designs.map((d) => d.name), ["alpha", "beta", "gamma"]);
    assert.ok(designs.every((d) => d.depth === 0 && d.parents.length === 0));
    const html = indexPage(designs);
    assert.doesNotMatch(html, /card-derived/);
    assert.doesNotMatch(html, /derived from/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("the real repo agrees with the resolver", () => {
  // The tree ships no derives.conf today, so this is the regression that
  // catches the port breaking the ordinary case — and it starts cross-checking
  // real lineage the moment a first derivative lands.
  assertAgreement(
    REPO_ROOT,
    readDesigns(REPO_ROOT).map((d) => d.name)
  );
});
