// The design's browser-side model bundle: its source and the complete include
// closure the WASM runtime needs to render it, plus its Customizer parameters.
//
// One bundle serves two consumers. The configurator (site/assets/configurator.js)
// reads its `sections`/`asserts` to build controls; the 3D viewer
// (site/assets/viewer.js, issue #100) renders `entry`/`source`/`files` at
// default parameters and draws the result. Every design gets a bundle — a
// design with no tunable parameters still has geometry to view — so the builder
// never returns null the way the old configurator-only path did.
//
// Files are keyed by their repo-relative path; the browser recreates that layout
// under one root with OPENSCADPATH set to `lib:root` — the same search path
// every script in this repo exports. Mirroring rather than flattening keeps a
// nested reference (`BOSL2/std.scad`, `styles/<n>/style.scad`) resolvable if a
// design ever takes one.

import { readFileSync, statSync } from "node:fs";
import { join, sep } from "node:path";

import { parseParameters, includeClosure } from "./scadparams.mjs";

export function buildModel(repoRoot, design) {
  const entry = `${design.relDir}/${design.name}.scad`;
  const source = readFileSync(join(repoRoot, entry), "utf8");
  const { sections, asserts } = parseParameters(source);

  // Same roots the scripts search: OPENSCADPATH="lib:repo-root", plus the
  // design's own directory for a sibling include.
  const resolve = (ref) => {
    for (const rel of [join("lib", ref), join(design.relDir, ref), ref]) {
      const candidate = join(repoRoot, rel);
      try {
        if (statSync(candidate).isFile()) {
          return {
            path: rel.split(sep).join("/"),
            contents: readFileSync(candidate, "utf8"),
          };
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
    entry,
    source,
    files: includeClosure(source, resolve),
    sections,
    asserts,
  };
}

/** Whether this model exposes tunable parameters — i.e. gets a configurator. */
export function hasConfigurator(model) {
  return !!(model && model.sections && model.sections.length);
}
