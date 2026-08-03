# site/ — the static product site

Turns what this repo already commits — product pages, previews, product
shots, style specs — into a browsable site, deployed on Vercel. It invents
no content: every word and image on the site comes from a file CI already
gates.

```bash
./scripts/site.sh           # build into build/site
./scripts/site.sh --serve   # build, then serve at http://localhost:8000
```

Vercel runs the same generator (`vercel.json` at the repo root pins the
install and build commands), so a green local build means the deploy builds.

## What it publishes

| Page | Built from |
|---|---|
| `/` | every `designs/<name>/` with a `<name>.scad` and a `README.md` |
| `/designs/<name>/` | that design's `README.md`, rendered |
| `/styles/` | every `styles/<name>/` with a `STYLE.md` |
| `/styles/<name>/` | that style's `STYLE.md`, rendered |

Adding a design requires no edit here — the generator finds it by the same
entry-point rule `gate.sh` and `gallery.sh` use.

## Two decisions worth knowing

**The output tree mirrors the repo tree.** `designs/nuggs/README.md` becomes
`/designs/nuggs/`, and its images are copied to `/designs/nuggs/previews/`.
That is what lets a product page keep writing `previews/contact-sheet.png`
and have it resolve on the site with no rewriting at all. Only references
the site does *not* serve — a `.scad`, `NOTES.md`, a `.conf` — get rewritten,
to GitHub, where they really live.

**A broken local reference fails the build.** Every non-external link and
image is resolved against the filesystem; anything missing is collected and
reported, and the build exits non-zero. A link that would 404 in production
stops the deploy instead.

**Lineage is ported, not re-derived — and the port is cross-checked.** Index
order and nesting come from the lineage record, so a derivative appears under
the design whose geometry it reuses and credits it, exactly as
`scripts/gallery.sh` does for the README gallery. The site cannot ask the real
resolver: `vercel.json` pins the deploy to `npm --prefix site ci` +
`node site/build.mjs`, and `./scripts/lineage.sh` needs Python. So `lib/`
carries a port — and `test/lineage.test.mjs` runs the port and `tools/lineage`
over the same fixture trees and fails on any disagreement about order or
parentage. Two surfaces of this repo silently disagreeing about what a design
*is* was [issue #55](https://github.com/shaiss/print-bench/issues/55); the
cross-check is what stops it recurring.

The one-line pitch on each gallery card is the same one `scripts/gallery.sh`
puts in the README gallery — NOTES.md's `## Goal` paragraph, falling back to
the product page's intro. `site/lib/content.mjs` ports that rule deliberately;
if `gallery.sh` changes how it picks, change this with it, or the gallery in
`README.md` and the gallery on the site start describing designs differently.

## The configurator

Each product page carries an in-browser configurator: controls built from the
design's own Customizer parameters, a render button, and a download. OpenSCAD
is compiled to WebAssembly and runs on the **visitor's** machine, so nothing is
uploaded, nothing is installed, and the render costs us no compute.

`lib/scadparams.mjs` reads the parameter block straight out of the `.scad` at
build time — sections, descriptions, `[min:step:max]` and dropdown annotations
— so the controls cannot drift from the source. It is deliberately
conservative: a parameter is exposed only when its value is a literal that
round-trips through `-D name=value`. Computed values, `[Hidden]` sections,
`$fn`/`$fa`/`$fs`, and anything below where geometry starts are all skipped.

Four things here were established by running the binary, not by reading docs.
Change them at your peril:

1. **The flag is `--backend=manifold`.** The upstream openscad-wasm README
   still shows `--enable=manifold`, which is an obsolete spelling that does
   *not* error — OpenSCAD prints "Ignoring request to enable unknown feature"
   and silently runs the old CGAL backend, measured **145× slower**. The worker
   therefore also checks the geometry line says `(manifold)` and reports it if
   not.
2. **One module instance per render.** A second `callMain()` on the same
   instance throws *and* the previous run's output file is still readable — so
   reuse hands the visitor the previous model.
3. **`OPENSCADPATH` works — but only from `preRun`.** The runtime reads its
   environment at startup, so assigning `ENV` afterwards is too late, and
   OpenSCAD's parser only registers search paths that *exist* when `callMain`
   is called. Set it in `preRun`, create the directories first, and the repo's
   own `lib:root` search path works unchanged — which is why the browser
   mirrors the repo layout under `/repo` instead of flattening includes to
   basenames. Flattening would have worked today (nothing uses a nested
   include) and broken the first time a design wrote `include <BOSL2/std.scad>`
   or `include <styles/<name>/style.scad>`.
4. **`text()` needs a font.** Without a TTF on the virtual filesystem it emits
   a warning and contributes *no* geometry — calibration-cube's embossed size
   marker just vanishes while the render still reports success. DejaVu Sans
   ships for this reason (20 triangles without it, 1300 with).

The runtime is ~13 MB and is fetched only when a visitor opens a configurator,
never with the page.

**Licence.** OpenSCAD is GPL-2.0, so serving this build is distribution. The
build writes `/assets/openscad/README.txt` next to the binary naming the exact
pinned artifact, linking upstream source, and carrying a written offer for the
corresponding source; the font's licence ships beside it.

**The pin is worth revisiting.** The artifact is the npm package
`openscad-wasm`, pinned with its integrity hash in `package-lock.json` and
verified to be OpenSCAD 2025.07.18 with a working Manifold backend. The
*preferable* artifact is the build the official OpenSCAD playground ships
(`files.openscad.org`), which keeps `openscad.wasm` as a separate file and so
gets streaming compilation and independent caching, instead of base64-inlining
it into a 13 MB JS bundle. It was unreachable from the environment this was
built in, so it could not be verified or pinned here.

## Layout

- `build.mjs` — the generator; discovery, render, asset copy, link check
- `lib/content.mjs` — what exists: designs, styles, pitches, parts, previews
- `lib/lineage.mjs` — `derives.conf` → gallery order and parentage, ported from `tools/lineage`
- `lib/markdown.mjs` — markdown → HTML, link resolution and rewriting
- `lib/scadparams.mjs` — Customizer parameters and include closure from a `.scad`
- `lib/templates.mjs` — the page shells
- `test/` — `npm --prefix site test`; run by `./scripts/site.sh` and CI
- `assets/` — `site.css` (the design system), `site.js` (theme toggle),
  `configurator.js` (the panel) and `openscad-worker.js` (the renderer),
  copied to `/assets/` verbatim

## Dependencies

Three, all pinned in `package-lock.json`:

| Package | Why | Size |
|---|---|---|
| `marked` | markdown → HTML | ~470 KB, no transitive deps |
| `openscad-wasm` | the configurator's renderer (GPL-2.0) | ~13 MB, lazy-loaded |
| `dejavu-fonts-ttf` | a font for `text()`, without which glyphs vanish | one 750 KB TTF is shipped |

Everything else is Node's standard library. There is no framework and no
bundler.
