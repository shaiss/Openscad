// The in-browser 3D viewer (issue #100), held to the guarantees the product
// page makes about it: every design gets a viewer, it renders the design's own
// source, it never loads its heavy runtime eagerly, and the page is complete
// without JavaScript.
//
// A render cannot be measured here (that needs a browser + the WASM runtime),
// so these tests pin the wiring the runtime depends on: the model bundle the
// viewer feeds to the worker, and the markup that lazy-loads it. The real
// geometry is the design's own `<name>.scad` at default parameters — the same
// file render.sh/gate.sh export — routed through the same worker the
// configurator uses.

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

import { readDesigns } from "../lib/content.mjs";
import { buildModel, hasConfigurator } from "../lib/model.mjs";
import { designPage } from "../lib/templates.mjs";

const REPO_ROOT = fileURLToPath(new URL("../..", import.meta.url));

/** A throwaway tree of `path → contents`. */
function fixture(files) {
  const root = mkdtempSync(join(tmpdir(), "print-bench-viewer-"));
  for (const [rel, contents] of Object.entries(files)) {
    const abs = join(root, rel);
    mkdirSync(dirname(abs), { recursive: true });
    writeFileSync(abs, contents);
  }
  return root;
}

function page(root, name) {
  const design = readDesigns(root).find((d) => d.name === name);
  const model = buildModel(root, design);
  return { design, model, html: designPage(design, { html: "<p>body</p>", toc: "", githubBase: "https://example.invalid", model }) };
}

test("every design gets a model bundle — including one with no tunable parameters", () => {
  const root = fixture({
    // No `/* [Section] */`, so no configurator — but it still has geometry.
    "designs/plain/plain.scad": "cube(10);\n",
    "designs/plain/README.md": "# Plain\n\nA plain cube.\n",
  });
  try {
    const { model } = page(root, "plain");
    assert.equal(model.entry, "designs/plain/plain.scad");
    assert.match(model.source, /cube\(10\)/);
    assert.equal(hasConfigurator(model), false, "a paramless design must not get a configurator");
    assert.deepEqual(model.sections, []);
    assert.equal(typeof model.files, "object");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("the viewer is on every product page, configurator or not", () => {
  const paramless = fixture({
    "designs/plain/plain.scad": "cube(10);\n",
    "designs/plain/README.md": "# Plain\n\nA plain cube.\n",
  });
  const tunable = fixture({
    "designs/knob/knob.scad": "/* [Main] */\n// diameter in mm\ndia = 20;\ncylinder(d=dia, h=5);\n",
    "designs/knob/README.md": "# Knob\n\nA tunable knob.\n",
  });
  try {
    const plain = page(paramless, "plain");
    const knob = page(tunable, "knob");

    // Viewer present on both.
    for (const { html } of [plain, knob]) {
      assert.match(html, /class="viewer"/, "viewer section missing");
      assert.match(html, /data-viewer/);
      assert.match(html, /data-canvas/);
      assert.match(html, /<script type="module" src="\/assets\/viewer\.js"><\/script>/);
    }

    // Configurator only where there are parameters.
    assert.doesNotMatch(plain.html, /class="cfg"/, "paramless design must have no configurator");
    assert.doesNotMatch(plain.html, /configurator\.js/);
    assert.match(knob.html, /class="cfg"/, "tunable design must have a configurator");
    assert.match(knob.html, /configurator\.js/);
  } finally {
    rmSync(paramless, { recursive: true, force: true });
    rmSync(tunable, { recursive: true, force: true });
  }
});

test("the viewer points at the design's own model bundle and the shared runtime", () => {
  const root = fixture({
    "designs/knob/knob.scad": "/* [Main] */\n// diameter in mm\ndia = 20;\ncylinder(d=dia, h=5);\n",
    "designs/knob/README.md": "# Knob\n\nA tunable knob.\n",
  });
  try {
    const { html } = page(root, "knob");
    assert.match(html, /data-model="\/designs\/knob\/model\.json"/);
    assert.match(html, /data-worker="\/assets\/openscad-worker\.js"/);
    assert.match(html, /data-runtime="\/assets\/openscad\/openscad\.js"/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("the viewer never loads its heavy runtime eagerly, and refers only to vendored assets", () => {
  const root = fixture({
    "designs/plain/plain.scad": "cube(10);\n",
    "designs/plain/README.md": "# Plain\n\nA plain cube.\n",
  });
  try {
    const { html } = page(root, "plain");
    // The 14 MB runtime is a data attribute, never an eager <script src> or a
    // <link rel=preload> — opening the viewer is what fetches it.
    assert.doesNotMatch(html, /<script[^>]+openscad\.js/, "runtime must not be an eager script");
    assert.doesNotMatch(html, /<link[^>]+openscad\.js/, "runtime must not be preloaded");
    // three.js is resolved to the vendored copy, not a CDN.
    assert.match(
      html,
      /<script type="importmap">\{"imports":\{"three":"\/assets\/three\/three\.module\.min\.js"\}\}<\/script>/
    );
    assert.doesNotMatch(html, /import\s+map[^]*https?:\/\//);
    // The viewer block itself introduces no external origin.
    const viewer = html.slice(html.indexOf('class="viewer"'), html.indexOf("</section>", html.indexOf('class="viewer"')));
    assert.doesNotMatch(viewer, /https?:\/\//, "viewer markup must reference no external origin");
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("progressive enhancement: a <noscript> fallback and the prose survive without JS", () => {
  const root = fixture({
    "designs/plain/plain.scad": "cube(10);\n",
    "designs/plain/README.md": "# Plain\n\nA plain cube.\n",
  });
  try {
    const { html } = page(root, "plain");
    assert.match(html, /<noscript>[^]*Enable JavaScript[^]*<\/noscript>/);
    // The page body is real markup, not injected by the viewer.
    assert.match(html, /<p>body<\/p>/);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});

test("the real repo: every design has a viewer and a bundle of its own source", () => {
  const designs = readDesigns(REPO_ROOT);
  assert.ok(designs.length > 0, "no designs found");
  for (const design of designs) {
    const model = buildModel(REPO_ROOT, design);
    assert.equal(
      model.entry,
      `designs/${design.name}/${design.name}.scad`,
      `${design.name}: bundle entry is the design's own entry .scad`
    );
    assert.ok(model.source && model.source.length > 0, `${design.name}: bundle carries source`);
    assert.equal(typeof model.files, "object", `${design.name}: bundle carries an include closure`);

    const html = designPage(design, { html: "<p>body</p>", toc: "", githubBase: "https://example.invalid", model });
    assert.match(html, /data-viewer/, `${design.name}: product page is missing the 3D viewer`);
    assert.match(
      html,
      new RegExp(`data-model="/designs/${design.name}/model\\.json"`),
      `${design.name}: viewer must point at the design's model bundle`
    );
    // Configurator presence stays tied to whether the design has parameters.
    if (hasConfigurator(model)) {
      assert.match(html, /class="cfg"/, `${design.name}: has parameters but no configurator`);
    }
  }
});
