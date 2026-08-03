---
name: product-shots
description: Give a design's product page real-world-looking product shots — path-traced studio renders of the printed part (deterministic, CI-gated), plus an optional AI-restyled lifestyle shot when the session has an image-generation tool. Use when asked for product shots, hero images, photoreal/real-world renders, or when invoked as /product-shots [name].
---

# Product shots — real-world-looking images for the product page

A product page sells the print. The 4-view contact sheet proves geometry;
the **product shot** is what makes a stranger want the thing: the part as
it would look printed, sitting under studio light. Every design's README
should lead with one.

Two tiers, in order:

1. **Studio render (always — this is the CI-gated deliverable).**
   `./scripts/product-shot.sh <name>` exports the geometry-true STL with
   OpenSCAD and path-traces it with Blender's Cycles: seamless backdrop,
   soft key/fill/rim lighting, glossy floor with contact shadows, plastic
   material with FDM layer lines. Re-rendering an unchanged design
   reproduces the committed PNG pixel for pixel **on the same machine**, so
   shots diff cleanly across review rounds: hold the manifest, the scene
   code and the toolchain still, and a shot that moves means the geometry
   moved. Expect roughly a minute per shot. One caveat before trusting a
   byte-level comparison across machines: Cycles dispatches an SSE4.2 or
   AVX2 CPU kernel by what the host supports, and their rounding differs,
   so compare renders from different hardware perceptually, not byte-wise.
2. **AI-restyled lifestyle shot (optional — only when the session has an
   image-generation tool).** Restyle the committed raytrace into a
   real-world scene. This tier is **purely supplemental and cosmetic** — a
   general real-world impression for the reader, not a geometry-true render:
   assume it may be geometrically off. Never a substitute for tier 1, never
   the only image on the page, and it always ships with a visible warning
   note directly below it (see below).

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

If the `bpy` module is missing, run `.claude/hooks/session-start.sh --force`
— don't work around the gap.

## Tier 2: AI-restyled lifestyle shot

Only when the session actually has an image-generation tool (check your
available tools; do not shell out to external image APIs that aren't
configured). If none is available, skip this tier silently — tier 1 is the
deliverable — and leave the idea in NOTES.md for a session that has one.

- **Start from the committed tier-1 raytrace** so the generated image at
  least begins from the real part. Prompt for: same object, same viewpoint,
  photographed in a real setting relevant to the design's use (the
  battleship board on a dinner table set with sushi; the desiccant capsule
  beside a filament dry-box), natural lighting, shallow depth of field.
- **It is cosmetic, so assume it is geometrically off.** Image generators
  add, drop, and reshape features, and we do **not** reject a lifestyle shot
  for that — chasing pixel-faithful geometry out of a restyle is a losing
  game, and the studio render (tier 1) and the STL are already the
  geometry-true artifacts on the page. What keeps the lifestyle shot honest
  is the *disclosure*, not a fidelity check. Every lifestyle shot ships all
  three:
  - Committed as `previews/lifestyle-<shot>.png`, where `<shot>` is the
    exact tier-1 manifest name it restyles (so `product-hero` becomes
    `lifestyle-product-hero.png`).
  - Embedded with alt text that carries the label `AI-styled scene`.
  - **A short visible note directly below the image**, so a reader skimming
    the *rendered* page — not the markdown — sees the warning that alt text
    alone can't give them:

    ```markdown
    ![AI-styled scene: the board on a set dinner table](previews/lifestyle-product-hero.png)

    *AI-generated impression for general illustration only — geometry is
    approximate and may not exactly match the printed part; see the studio
    render above and the STL for the true shape.*
    ```
- The tier-1 shot stays on the page as the geometry-true reference; the
  lifestyle shot only augments it, giving the reader a general real-world
  feel for the piece.

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
manifest, the scene code, or the Blender version — and is worth
understanding before committing. Across two different machines, expect a
near-identical but not byte-identical image; that is the CPU-kernel caveat
above, not drift.
