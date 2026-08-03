#!/usr/bin/env node
// Build the static product site.
//
//   node site/build.mjs [--out <dir>]     (default: build/site)
//
// Everything it publishes already exists in the repo and is already gated by
// CI — product pages, previews, product shots, style specs. This turns that
// into a browsable site; it invents no content of its own.
//
// The output tree mirrors the repo tree (designs/<name>/ → /designs/<name>/),
// which is what lets a product page keep its `previews/foo.png` links with no
// rewriting. Any local reference that does not resolve on disk fails the
// build — a broken link should stop a deploy, not become a 404 in production.

import {
  mkdirSync,
  writeFileSync,
  copyFileSync,
  rmSync,
  readdirSync,
  readFileSync,
  statSync,
} from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import { readDesigns, readStyles } from "./lib/content.mjs";
import { renderMarkdown, tocHtml } from "./lib/markdown.mjs";
import { parseParameters, includeClosure } from "./lib/scadparams.mjs";
import {
  indexPage,
  designPage,
  stylesIndexPage,
  stylePage,
  FAVICON,
} from "./lib/templates.mjs";

const SITE_DIR = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(SITE_DIR, "..");
const GITHUB_BASE = "https://github.com/shaiss/Openscad/blob/main";

function parseArgs(argv) {
  let out = join(REPO_ROOT, "build", "site");
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--out") {
      const v = argv[++i];
      if (!v) fail("--out needs a directory");
      out = resolve(process.cwd(), v);
    } else {
      fail(`unknown argument: ${argv[i]}`);
    }
  }
  return { out };
}

function fail(msg) {
  console.error(`error: ${msg}`);
  process.exit(2);
}

function write(outDir, relPath, contents) {
  const dest = join(outDir, relPath);
  mkdirSync(dirname(dest), { recursive: true });
  writeFileSync(dest, contents);
}

function copyTree(from, to) {
  for (const entry of readdirSync(from, { withFileTypes: true })) {
    const src = join(from, entry.name);
    const dest = join(to, entry.name);
    if (entry.isDirectory()) {
      mkdirSync(dest, { recursive: true });
      copyTree(src, dest);
    } else if (entry.isFile()) {
      mkdirSync(dirname(dest), { recursive: true });
      copyFileSync(src, dest);
    }
  }
}

// The runtime OpenSCAD build served to visitors, and the font it needs.
// Both come from pinned npm packages (see site/package.json and the lockfile)
// rather than a floating download, so what ships is reproducible.
const RUNTIME_PKG = "openscad-wasm";
const RUNTIME_FILE = join(SITE_DIR, "node_modules", RUNTIME_PKG, "openscad.js");
const FONT_FILE = join(SITE_DIR, "node_modules", "dejavu-fonts-ttf", "ttf", "DejaVuSans.ttf");
const FONT_LICENSE = join(SITE_DIR, "node_modules", "dejavu-fonts-ttf", "LICENSE");

/**
 * The design's parameters and its complete source bundle, as the browser
 * needs them.
 *
 * The include closure is flattened to basenames on purpose: the WASM build
 * has no include path and ignores OPENSCADPATH, so every file has to sit in
 * the same directory as the entry file for `use <threads-fdm.scad>` to
 * resolve. Verified against the real binary — desiccant-capsule renders only
 * when threads-fdm.scad is written next to model.scad.
 */
function buildConfigurator(design) {
  const source = readFileSync(join(design.dir, `${design.name}.scad`), "utf8");
  const { sections, asserts } = parseParameters(source);
  if (!sections.length) return null;

  // Same search path the scripts export: OPENSCADPATH="lib:repo-root", plus
  // the design's own directory for a sibling include.
  const resolve = (ref) => {
    for (const candidate of [
      join(REPO_ROOT, "lib", ref),
      join(design.dir, ref),
      join(REPO_ROOT, ref),
    ]) {
      try {
        if (statSync(candidate).isFile()) {
          return { contents: readFileSync(candidate, "utf8") };
        }
      } catch {
        /* try the next root */
      }
    }
    return null;
  };

  return {
    name: design.name,
    title: design.title,
    source,
    files: includeClosure(source, resolve),
    sections,
    asserts,
  };
}

/**
 * GPL-2.0 requires that whoever receives the binary can get its source and
 * knows their rights. This ships next to the artifact and names the exact
 * version served, so the offer points at something specific.
 */
function runtimeNotice() {
  const pkg = JSON.parse(
    readFileSync(join(SITE_DIR, "node_modules", RUNTIME_PKG, "package.json"), "utf8")
  );
  return `OpenSCAD compiled to WebAssembly — licence and source
=========================================================

openscad.js in this directory is a build of OpenSCAD, which is free software
licensed under the GNU General Public License, version 2 or later.

  Artifact : npm "${RUNTIME_PKG}" version ${pkg.version}
  Licence  : ${pkg.license || "GPL-2.0"}
  Registry : https://registry.npmjs.org/${RUNTIME_PKG}/-/${RUNTIME_PKG}-${pkg.version}.tgz

The exact bytes served here are the ones npm resolves for that version; the
integrity hash that pins them is recorded in site/package-lock.json in the
source repository of this site.

CORRESPONDING SOURCE
--------------------
OpenSCAD's complete source is published by the OpenSCAD project at
https://github.com/openscad/openscad, and the WebAssembly build definition at
https://github.com/openscad/openscad-wasm. Both are GPL-2.0.

You may also request the corresponding source for the exact build served here
by opening an issue at https://github.com/shaiss/Openscad/issues — this is a
written offer, valid for as long as this site serves the binary.

You may redistribute and/or modify OpenSCAD under the terms of the GNU General
Public License as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. It is distributed in the
hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License at https://www.gnu.org/licenses/old-licenses/gpl-2.0.html
for more details.

FONT
----
design.ttf is DejaVu Sans, shipped because OpenSCAD's text() renders nothing
without a font on its virtual filesystem. Its licence is LICENSE-dejavu.txt in
this directory.
`;
}

function main() {
  const { out } = parseArgs(process.argv.slice(2));

  const designs = readDesigns(REPO_ROOT);
  const styles = readStyles(REPO_ROOT);

  if (designs.length === 0) fail("no designs found under designs/");

  // Documents the site itself publishes, so links between them stay internal
  // instead of bouncing the reader out to GitHub.
  const pages = new Map();
  for (const d of designs) pages.set(d.readmePath, `/${d.relDir}/`);
  for (const s of styles) pages.set(s.specPath, `/${s.relDir}/`);
  const pageFor = (absPath) => pages.get(absPath) || null;

  const assets = new Set();
  const errors = [];
  const onAsset = (p) => assets.add(p);
  const onError = (m) => errors.push(m);

  rmSync(out, { recursive: true, force: true });
  mkdirSync(out, { recursive: true });

  const rendered = [];

  for (const design of designs) {
    const { html, headings } = renderMarkdown(design.readme, {
      repoRoot: REPO_ROOT,
      sourcePath: design.readmePath,
      onAsset,
      onError,
      githubBase: GITHUB_BASE,
      pageFor,
    });

    const configurator = buildConfigurator(design);
    if (configurator) {
      rendered.push({
        path: `${design.relDir}/configurator.json`,
        contents: JSON.stringify(configurator),
      });
    }

    rendered.push({
      path: `${design.relDir}/index.html`,
      contents: designPage(design, {
        html,
        toc: tocHtml(headings),
        githubBase: GITHUB_BASE,
        configurator,
      }),
    });
  }

  for (const style of styles) {
    const { html, headings } = renderMarkdown(style.spec, {
      repoRoot: REPO_ROOT,
      sourcePath: style.specPath,
      onAsset,
      onError,
      githubBase: GITHUB_BASE,
      pageFor,
    });
    rendered.push({
      path: `${style.relDir}/index.html`,
      contents: stylePage(style, {
        html,
        toc: tocHtml(headings),
        githubBase: GITHUB_BASE,
        users: designs.filter((d) => d.style === style.name),
      }),
    });
  }

  // The gallery needs its thumbnails even though no rendered markdown
  // references them: the cards are built from structured data, not prose.
  for (const design of designs) {
    if (design.thumb) assets.add(join(design.dir, "previews", design.thumb));
  }
  for (const style of styles) {
    if (style.swatch) assets.add(join(style.dir, style.swatch));
  }

  if (errors.length) {
    console.error(`\n${errors.length} broken reference(s):`);
    for (const e of errors) console.error(`  ${e}`);
    console.error(
      "\nFix the source document — a link that does not resolve here would 404 in production."
    );
    process.exit(1);
  }

  for (const page of rendered) write(out, page.path, page.contents);

  write(out, "index.html", indexPage(designs));
  if (styles.length) write(out, "styles/index.html", stylesIndexPage(styles, designs));

  let assetBytes = 0;
  for (const abs of assets) {
    const rel = relative(REPO_ROOT, abs).split(sep).join("/");
    const dest = join(out, rel);
    mkdirSync(dirname(dest), { recursive: true });
    copyFileSync(abs, dest);
    assetBytes += statSync(abs).size;
  }

  mkdirSync(join(out, "assets"), { recursive: true });
  copyTree(join(SITE_DIR, "assets"), join(out, "assets"));
  write(out, "assets/favicon.svg", FAVICON);
  write(out, "robots.txt", "User-agent: *\nAllow: /\n");

  // OpenSCAD compiled to WebAssembly, plus the font text() needs. Served from
  // /assets/openscad/ and fetched only when a visitor opens a configurator —
  // it is ~14 MB, so it must never load with the page.
  //
  // OpenSCAD is GPL-2.0. Serving this build to visitors is distribution, so
  // the licence and the provenance of the exact artifact ship beside it.
  let runtimeBytes = 0;
  mkdirSync(join(out, "assets", "openscad"), { recursive: true });
  try {
    copyFileSync(RUNTIME_FILE, join(out, "assets", "openscad", "openscad.js"));
    runtimeBytes = statSync(RUNTIME_FILE).size;
    copyFileSync(FONT_FILE, join(out, "assets", "openscad", "design.ttf"));
    copyFileSync(FONT_LICENSE, join(out, "assets", "openscad", "LICENSE-dejavu.txt"));
    write(out, "assets/openscad/README.txt", runtimeNotice());
  } catch (err) {
    fail(
      `the OpenSCAD runtime is missing (${err.message}).\n` +
        `Run \`npm --prefix site ci\` first — the configurator cannot be built without it.`
    );
  }

  const configurators = rendered.filter((p) => p.path.endsWith("configurator.json")).length;
  const pageCount = rendered.length - configurators + 1 + (styles.length ? 1 : 0);
  console.log(
    `site: ${pageCount} pages, ${assets.size} assets ` +
      `(${(assetBytes / 1024 / 1024).toFixed(1)} MB) → ${relative(REPO_ROOT, out) || out}`
  );
  console.log(
    `      ${designs.length} designs, ${styles.length} styles, every local reference resolved`
  );
  console.log(
    `      ${configurators} configurators, OpenSCAD runtime ` +
      `${(runtimeBytes / 1024 / 1024).toFixed(1)} MB (lazy-loaded, GPL notice shipped)`
  );
}

main();
