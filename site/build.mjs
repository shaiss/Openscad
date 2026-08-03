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

import { mkdirSync, writeFileSync, copyFileSync, rmSync, readdirSync, statSync } from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import { readDesigns, readStyles } from "./lib/content.mjs";
import { renderMarkdown, tocHtml } from "./lib/markdown.mjs";
import {
  indexPage,
  designPage,
  stylesIndexPage,
  stylePage,
  FAVICON,
} from "./lib/templates.mjs";

const SITE_DIR = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(SITE_DIR, "..");
const GITHUB_BASE = "https://github.com/shaiss/print-bench/blob/main";

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
    rendered.push({
      path: `${design.relDir}/index.html`,
      contents: designPage(design, {
        html,
        toc: tocHtml(headings),
        githubBase: GITHUB_BASE,
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

  const pageCount = rendered.length + 1 + (styles.length ? 1 : 0);
  console.log(
    `site: ${pageCount} pages, ${assets.size} assets ` +
      `(${(assetBytes / 1024 / 1024).toFixed(1)} MB) → ${relative(REPO_ROOT, out) || out}`
  );
  console.log(
    `      ${designs.length} designs, ${styles.length} styles, every local reference resolved`
  );
}

main();
