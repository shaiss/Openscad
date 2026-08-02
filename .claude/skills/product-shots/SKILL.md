---
name: product-shots
description: Give a design's product page real-world-looking product shots — raytraced studio renders of the printed part (deterministic, CI-gated), plus an optional AI-restyled lifestyle shot when the session has an image-generation tool. Use when asked for product shots, hero images, photoreal/real-world renders, or when invoked as /product-shots [name].
---

# Product shots — real-world-looking images for the product page

A product page sells the print. The 4-view contact sheet proves geometry;
the **product shot** is what makes a stranger want the thing: the part as
it would look printed, sitting under studio light. Every design's README
should lead with one.

Two tiers, in order:

1. **Studio raytrace (always — this is the CI-gated deliverable).**
   `./scripts/product-shot.sh <name>` exports the geometry-true STL with
   OpenSCAD and raytraces it with POV-Ray: seamless backdrop, soft
   key/fill/rim lighting, glossy floor with contact shadows, plastic
   material with FDM layer lines. Re-rendering an unchanged design
   reproduces the committed PNG pixel for pixel, so shots diff cleanly
   across review rounds: hold the manifest, the scene code and the
   toolchain still, and a shot that moves means the geometry moved. That
   costs render time (radiosity is single-threaded to stay reproducible;
   expect tens of seconds for a small part, minutes for a large one).
2. **AI-restyled lifestyle shot (optional — only when the session has an
   image-generation tool).** Restyle the committed raytrace into a
   real-world scene. Never a substitute for tier 1, and never the only
   image on the page.

## Tier 1 workflow

1. **Write the manifest** `designs/<name>/shots.conf` (format documented in
   `scripts/product-shot.sh`), one line per shot:

   ```text
   product-hero | e8734a | satin | 35,18,0.85 | 1280x960 | part="assembled"
   ```

   - Name the lead shot `product-hero`. Colors are `rrggbb` **without**
     `#` (a `#` starts a manifest comment). Pick a plausible filament
     color that flatters the part; vary colors across a repo so pages
     don't all look alike.
   - Camera is `rotz,elev,zoom`: three-quarter views (rotz 25–45,
     elev 12–25) read as product photography; flat wide parts want more
     elevation. Start at `35,18,0.85` and iterate.
   - `zoom` scales an automatic fit, so it means the same thing on every
     design regardless of size: 1.0 frames the part's bounding box with a
     small margin, below 1.0 pulls back for more room, above 1.0 crops in.
     The fit solves both the horizontal and vertical field of view, so a
     tall part cannot silently lose its top edge — you do not have to
     hand-check framing per design, only judge it.
   - Like `animations.conf`, entries are FIXED across review rounds so
     before/after images align — add a new entry rather than moving one.

2. **Render and look at it**: `./scripts/product-shot.sh <name>`, then
   actually view `designs/<name>/previews/<shot>.png` (Read it) before
   shipping — check framing, that the part isn't crushed against the
   frame edge, and that the visible face is the one that sells the design.
   Send it to the user with SendUserFile like any other preview.

3. **Embed it** near the top of the README (above the contact sheet), with
   descriptive alt text naming the material/color:

   ```markdown
   ![Product shot: the assembled board in charcoal PLA](previews/product-hero.png)
   ```

4. **Gate**: `./scripts/readme-gate.sh <name>` must pass — every
   `shots.conf` entry needs its committed PNG, embedded in the README,
   within the size budget (`scripts/preview-budget.sh`). CI enforces this;
   commit the PNGs like every other preview.

Multi-part scenes: `tools/photoshot/photoshot.py` accepts multiple STLs
with per-mesh `--color` for two-tone assemblies; the manifest drives one
geometry per shot, so compose multi-STL shots manually and name the output
to match a manifest entry only if it is reproducible from source noted in
NOTES.md.

If `povray` is missing, run `.claude/hooks/session-start.sh --force` —
don't work around the gap.

## Tier 2: AI-restyled lifestyle shot

Only when the session actually has an image-generation tool (check your
available tools; do not shell out to external image APIs that aren't
configured). If none is available, skip this tier silently — tier 1 is the
deliverable — and leave the idea in NOTES.md for a session that has one.

- **Input is the committed tier-1 raytrace**, so the geometry in the
  generated image stays anchored to the real part. Prompt for: same object,
  same viewpoint, photographed in a real setting relevant to the design's
  use (the battleship board on a dinner table set with sushi; the desiccant
  capsule beside a filament dry-box), natural lighting, shallow depth of
  field.
- **Honesty rules**: the shot must not invent or hide geometry — reject
  generations that change the part's shape, proportions, or feature count
  (count them: shutters, vents, ribs). Commit as
  `previews/lifestyle-<shot>.png` and embed with alt text that says
  `AI-styled scene` so nobody mistakes it for a photo of a physical print.
- The tier-1 shot stays on the page; the lifestyle shot augments it.

## Freezing and review

Product shots follow the same freeze policy as `previews/CAMERAS.md`
cameras and `animations.conf`: once reviewers have compared against a
shot, don't silently re-frame it. Regenerate (same manifest line) whenever
the model changes; the gate can't detect a stale PNG, so re-running
`./scripts/product-shot.sh <name>` after geometry changes is part of the
design's definition of done, alongside `render.sh` and `gate.sh --slice`.

Because renders are reproducible, staleness is *checkable* even though the
gate doesn't check it: re-run the shot on an unchanged design and the PNG
should come back byte-identical (`git status` stays clean). A shot that
moves without a geometry change means something else drifted — the
manifest, the scene code, or the POV-Ray version — and is worth
understanding before committing.
