// Discovery: what the site is made of, read straight out of the repo.
//
// Nothing here is hand-maintained. A new design directory appears on the
// site because it exists on disk, with the same entry-point rule the rest
// of the toolchain uses (designs/<name>/<name>.scad), and the same one-line
// pitch scripts/gallery.sh puts in the README gallery — so the site and the
// README cannot drift into disagreeing about what a design is.

import { readdirSync, readFileSync, existsSync, statSync } from "node:fs";
import { join } from "node:path";

export const IMAGE_EXT = new Set([".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp"]);

function read(path) {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return null;
  }
}

function dirs(path) {
  if (!existsSync(path)) return [];
  return readdirSync(path, { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .sort();
}

/**
 * The design's one-line pitch.
 *
 * Deliberately a port of the `pitch()` shell function in scripts/gallery.sh,
 * rule for rule: NOTES.md's "## Goal" paragraph, falling back to the first
 * prose line of the product page. Keep the two in step — if that script's
 * rule changes, this changes with it, or the gallery in README.md and the
 * gallery on the site start describing the same design differently.
 */
export function pitch(repoRoot, name) {
  let line = "";

  const notes = read(join(repoRoot, "designs", name, "NOTES.md"));
  if (notes) {
    const out = [];
    let hit = false;
    let got = false;
    for (const raw of notes.split("\n")) {
      if (/^##\s+Goal/.test(raw)) {
        hit = true;
        continue;
      }
      if (!hit) continue;
      if (/^\s*$/.test(raw)) {
        if (got) break;
        continue;
      }
      if (/^#/.test(raw)) break;
      out.push(raw);
      got = true;
    }
    line = out.join(" ");
  }

  if (!line) {
    const readme = read(join(repoRoot, "designs", name, "README.md"));
    if (readme) {
      const lines = readme.split("\n");
      for (let i = 0; i < lines.length; i++) {
        const raw = lines[i];
        if (i === 0 && /^#/.test(raw)) continue;
        if (/^\s*$/.test(raw)) continue;
        if (/^[#![|<]/.test(raw)) continue;
        line = raw;
        break;
      }
    }
  }

  line = line.replace(/\s+$/, "").trim();

  // A Goal paragraph that leads into a list ends with "...:" — drop the
  // dangling fragment, keep the complete sentences before it. (Same guard
  // as gallery.sh.)
  if (line.endsWith(":") && line.includes(".")) {
    line = line.slice(0, line.lastIndexOf(".") + 1);
  }
  return line;
}

/** First H1 text of a markdown document, or null. */
export function title(markdown) {
  const m = markdown.match(/^#\s+(.+?)\s*$/m);
  return m ? m[1].trim() : null;
}

/**
 * A prominent warning the product page opens with, if any.
 *
 * nuggs currently carries a "Work in progress — do not print yet" blockquote.
 * A gallery card that quietly dropped that would be actively harmful, so it
 * is lifted out as structured data and shown on the card too.
 */
export function warningBanner(markdown) {
  const bq = markdown.match(/^>\s*\*\*(.+?)\*\*/m);
  if (!bq) return null;
  const text = bq[1].replace(/\s+/g, " ").trim();
  return text.length > 90 ? `${text.slice(0, 88)}…` : text;
}

function lines(path) {
  const raw = read(path);
  if (!raw) return [];
  return raw
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l && !l.startsWith("#"));
}

export function readDesigns(repoRoot) {
  const out = [];
  for (const name of dirs(join(repoRoot, "designs"))) {
    const dir = join(repoRoot, "designs", name);
    const entry = join(dir, `${name}.scad`);
    const readmePath = join(dir, "README.md");
    // Same entry-point rule as gate.sh/gallery.sh: a directory without
    // designs/<name>/<name>.scad is not a design.
    if (!existsSync(entry) || !existsSync(readmePath)) continue;

    const readme = read(readmePath);
    const parts = lines(join(dir, "ci.parts"));
    const styleConf = lines(join(dir, "style.conf"));

    const previewsDir = join(dir, "previews");
    const previews = existsSync(previewsDir)
      ? readdirSync(previewsDir)
          .filter((f) => IMAGE_EXT.has(f.slice(f.lastIndexOf(".")).toLowerCase()))
          .sort()
      : [];

    const scads = readdirSync(dir)
      .filter((f) => f.endsWith(".scad"))
      .sort();

    out.push({
      name,
      dir,
      relDir: `designs/${name}`,
      readme,
      readmePath,
      title: title(readme) || name,
      pitch: pitch(repoRoot, name),
      warning: warningBanner(readme),
      parts,
      style: styleConf[0] || null,
      previews,
      scads,
      hero: previews.includes("product-hero.png")
        ? "product-hero.png"
        : previews.includes("contact-sheet.png")
          ? "contact-sheet.png"
          : previews[0] || null,
      thumb: previews.includes("contact-sheet.png")
        ? "contact-sheet.png"
        : previews[0] || null,
      hasCoupon: existsSync(join(dir, `${name}-coupon.scad`)),
    });
  }
  return out;
}

export function readStyles(repoRoot) {
  const out = [];
  for (const name of dirs(join(repoRoot, "styles"))) {
    const dir = join(repoRoot, "styles", name);
    const specPath = join(dir, "STYLE.md");
    if (!existsSync(specPath)) continue;
    const spec = read(specPath);

    let summary = "";
    try {
      const json = JSON.parse(read(join(dir, "style.json")) || "{}");
      summary = json.description || json.summary || "";
    } catch {
      summary = "";
    }
    if (!summary) {
      for (const raw of spec.split("\n")) {
        if (/^\s*$/.test(raw)) continue;
        if (/^[#![|<>]/.test(raw)) continue;
        summary = raw.trim();
        break;
      }
    }

    const swatch = join(dir, "previews", "swatch.png");
    out.push({
      name,
      dir,
      relDir: `styles/${name}`,
      spec,
      specPath,
      title: title(spec) || name,
      summary,
      swatch: existsSync(swatch) ? "previews/swatch.png" : null,
    });
  }
  return out;
}

/** Designs that declare a given style, for cross-linking. */
export function designsUsingStyle(designs, styleName) {
  return designs.filter((d) => d.style === styleName);
}

export function fileExists(path) {
  try {
    return statSync(path).isFile();
  } catch {
    return false;
  }
}
