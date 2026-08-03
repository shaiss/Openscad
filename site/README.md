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

The one-line pitch on each gallery card is the same one `scripts/gallery.sh`
puts in the README gallery — NOTES.md's `## Goal` paragraph, falling back to
the product page's intro. `site/lib/content.mjs` ports that rule deliberately;
if `gallery.sh` changes how it picks, change this with it, or the gallery in
`README.md` and the gallery on the site start describing designs differently.

## Layout

- `build.mjs` — the generator; discovery, render, asset copy, link check
- `lib/content.mjs` — what exists: designs, styles, pitches, parts, previews
- `lib/markdown.mjs` — markdown → HTML, link resolution and rewriting
- `lib/templates.mjs` — the four page shells
- `assets/` — `site.css` (the design system) and `site.js` (theme toggle),
  copied to `/assets/` verbatim

## Dependencies

One: [`marked`](https://github.com/markedjs/marked) for markdown parsing
(~470 KB installed, no transitive dependencies). Everything else is Node's
standard library. There is no framework and no bundler — four page types is
well under the weight where either starts paying for itself.
