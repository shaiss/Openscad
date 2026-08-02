---
name: style-spec
description: Translate a reference model the user likes (an STL, or an existing design) into a committed, checkable design-style spec that later design work can follow — so a user can pick a style instead of leaving the look to chance. Use when asked to capture/copy/lift a style from a model, to make a design match something, to define a house style, or when invoked as /style-spec [reference.stl] [name].
---

# Style spec — translate a model you like into a spec designs can follow

The user has something they like the look of. The job is to turn that into
`styles/<name>/`: a spec precise enough that a later session can be told "build
it in the `<name>` style" and produce something that visibly belongs to the
same family — and checkable enough that CI can say whether it did.

Split the work honestly. **`stylelift` measures; you judge.** The tool's numbers
are exact and reproducible, but a reference measures whatever it happens to be,
and deciding which of those numbers *is* the family is the part that needs a
person looking at the thing. A spec that just enshrines every measurement is
worse than no spec: it fails parts for having a different silhouette than a
reference nobody meant to copy that literally.

Scope: this skill creates and edits style packs. Designing a part *in* a style
is ordinary design work (`/new-design`, the CLAUDE.md co-design loop) with
`include <styles/<name>/style.scad>` and `./scripts/style-check.sh` in the
verification set.

## 1. Get the reference, and its provenance

Ask for the STL if you weren't handed one. Also acceptable: an existing
`designs/<name>/` (render it first) or several meshes that share a look.

Before measuring, get **where it came from and what it is licensed as**. This
is not paperwork: a lifted style is derived from someone's work, and the pack
gets committed to a public repo.

- Record both via `--source` and `--license`; they land in `style.json`
  provenance and on the STYLE.md page.
- **Do not commit the reference mesh** unless its licence allows
  redistribution. The sha256 in the pack identifies it; that is enough to
  re-derive the measurements later. The same goes for renders of it — which is
  why `style-lift.sh` puts the reference contact sheet in gitignored `build/`
  and the committed image is the style's own swatch.
- If the user can't say where a mesh came from, say so in the pack rather than
  inventing a licence.

## 2. Measure, then look

```bash
./scripts/style-lift.sh <name> <reference.stl> \
    --title "<Human Readable>" --summary "<one line>" \
    --source "<url or how it was produced>" --license "<terms>"
```

Then **actually look at `build/style-<name>-reference.png`** (Read it) with the
measurement report open. You are checking that the numbers describe the thing
you can see. Every judgement in step 3 depends on having done this.

## 3. Prune the draft — the part only you can do

`stylelift lift` proposes tokens and rules from what it measured. Go through
them and cut what isn't the style. The usual suspects:

- **Form mistaken for edge treatment.** A dominant radius with a `sweep_deg`
  near 360, or one that is a large fraction of the part, is the *shape* — the
  barrel of a bottle, the curve of a dome — not a radius you would apply to a
  new part's edges. stylelift files most of these under `edges.form`, but a
  reference whose body is cut open can still land one in the rounding
  vocabulary. A 90° sweep is an edge being broken; 180°+ is the object itself.
- **Wall thickness that is really part thickness.** `walls.shelled: false`
  means the rays measured a solid, and the "wall" is just its shortest
  dimension. Drop the token.
- **Massing measured on an arrangement.** If the reference is a plate of
  several bodies (`mesh.bodies` > 1), `bbox_fill` describes the gaps between
  them. Drop it.
- **Radii off a sculpted mesh.** If the report says the mesh is
  `triangulated` rather than `strip`, the radii read roughly 1.4x high — the
  estimator assumes the quad strips that CAD exports and a remeshed model has
  none. Don't copy those numbers into tokens unchallenged: check them against
  the render, and say in STYLE.md that they are approximate.
- **Anything the user tells you is incidental.** They chose this reference for
  a reason; ask what they actually like about it if the numbers are ambiguous.

Edit `styles/<name>/style.json` — it is the only hand-edited file — then
regenerate the derived ones:

```bash
stylelift sync styles/<name>
```

Keep the rule set small. Five or six rules that really separate this family
from another beat a dozen that fire on everything. Tolerances should be wide
enough that a part half the size still passes: the family is the *radius*, not
the silhouette.

## 4. Write the prose

The generated tables carry the numbers; you write what they mean.

- **The pitch** — what this style feels like and what it is for, in two
  sentences.
- **Do / Don't** — concrete instructions a modelling session can obey. "Round
  every vertical edge at `style_corner_r`, even on small parts" is usable;
  "maintain visual harmony" is not.
- **What the mesh cannot tell you** — colour, material, finish, use context,
  deliberate non-goals. Put these in `asserted` in style.json and on the page,
  marked as claims rather than measurements. They are half of what makes a
  style recognisable, and no amount of geometry recovers them.

Leave the `<!-- stylelift:… -->` blocks alone; `stylelift sync` owns them and
`--check` fails the gate if they drift from style.json.

## 5. Write the swatch, and let it judge the spec

`styles/<name>/swatch.scad` is a small part written in the style, built **from
the tokens** (`include <styles/<name>/style.scad>`), not from retyped numbers.
It is the style's regression test:

```bash
./scripts/style-check.sh <name>
```

This renders the swatch and checks it against the style's own rules. If the
swatch cannot pass, the spec is wrong — not the swatch. Either the rules are
too tight, or they encode something that was never reproducible. Fix
style.json, `sync`, and re-run.

Look at `styles/<name>/previews/swatch.png` too, and put it in front of the
user next to the reference render (SendUserFile). Passing rules while looking
nothing like the reference means the rules are measuring the wrong things —
that is a finding, and it is worth saying out loud rather than shipping.

## 6. Finish

- Add the style to the table in `styles/README.md` (docs-check.sh enforces
  that every pack is listed).
- Commit the pack — `STYLE.md`, `style.json`, `style.scad`, `swatch.scad`,
  `previews/swatch.png` — with `Add style: <name>`.
- Run `/preflight` before pushing; it covers the style gate.

## Using a style afterwards

A design opts in by naming the style in `designs/<name>/style.conf`, which
makes CI check every printable part on each push. In the design:

```scad
include <styles/<name>/style.scad>
$fn = style_fn;
```

If a design has a good reason to break a rule, change the rule in style.json
and say why in STYLE.md, or don't declare the style — do not weaken a rule
until it stops meaning anything. A style everything passes tells nobody
anything.
