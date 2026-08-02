# Design Name

<!-- Product page template — copy to designs/<name>/README.md and fill in.
     This is the page a stranger reads to decide whether to print the
     design and how; NOTES.md stays the engineering log (decisions,
     derivations, session-resume context). CI enforces this page with
     scripts/readme-gate.sh: H1 title, intro pitch, at least one preview
     image that exists, and non-empty "Print settings" and "Parameters"
     sections. Delete these comments. -->

One- or two-sentence pitch: what the thing is, what problem it solves,
who would want to print it.

<!-- Lead with the product shot (studio raytrace of the printed part):
     add a shots.conf, run ./scripts/product-shot.sh <name>, and embed
     the result here. See /product-shots. -->
![Product shot](previews/product-hero.png)

![4-view contact sheet](previews/contact-sheet.png)

## What you get

The printable part(s) this design produces and roughly how big they are.
For multi-part designs, list each part and what it is for.

- `part-name` — what it is (approx. W × D × H mm)

## Print settings

The settings a first-time printer needs: material, layer height, infill,
supports (designs here should not need any — say so), orientation, and
anything non-obvious (brim, print order, which part to print first).

- **Material:**
- **Layer height:**
- **Infill:**
- **Supports:** none needed
- **Orientation:**

## Parameters

The handful of parameters a user is most likely to tune, with defaults
and units — not the whole Customizer listing. Point at the .scad file
for the rest.

| Parameter | Default | What it does |
|---|---|---|
| `example` | 20 mm | … |

All parameters are at the top of `<name>.scad`, grouped in Customizer
sections; override on the command line with `-D 'example=25'`.

## Assembly & use

Optional but encouraged: how the parts go together, how to use the
finished print, and what to tweak (and reprint) if a fit is off.
