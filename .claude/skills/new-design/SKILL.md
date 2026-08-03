---
name: new-design
description: Scaffold a new parametric design directory with everything CI and the reviewers expect — entry .scad from the template, NOTES.md, ci.parts/printcheck.args when relevant — then first-render it. Use at the start of a design session, when asked to start/scaffold/set up a new design, or when invoked as /new-design [name].
---

# New design scaffold

Create `designs/<name>/` with every convention the repo's CI gate and
reviewer skills will later look for, so nothing has to be retrofitted round
by round. Follow the co-design workflow in CLAUDE.md — this skill covers
its Scaffold step (and assumes the Brief already happened: you know what
the part does and the measurements that matter; if not, get those first).

## 1. Name and files

Pick a kebab-case name. Then create:

- **`designs/<name>/<name>.scad`** — copy `templates/design.scad`; replace
  the placeholder header, parameters, and `main()` with the real design.
  Keep the template's conventions: units-and-purpose comment on every
  parameter, Customizer `/* [Section] */` groups, `$fn` declared with the
  production value noted, FDM rules from CLAUDE.md (walls ≥ 1.2 mm,
  chamfered bed edges, clearance parameters for every fit).
- **`designs/<name>/README.md`** — the product page, copied from
  `templates/README.md`. CI's `design-docs` job rejects any design without
  one that passes `./scripts/readme-gate.sh <name>` (H1 title, intro pitch,
  a committed preview image, non-empty Print settings + Parameters
  sections), so fill it in before the first push — the preview images it
  embeds live under `designs/<name>/previews/`.
- **`designs/<name>/NOTES.md`** — the file a later session resumes from.
  Sections: **Goal** (what the part does, for whom), **Given / assumed
  measurements** (mark which is which), **Key decisions** (append as they
  happen), **Print settings** (orientation, supports, material, layer
  height the design assumes). Keep it current; a decision that isn't in
  NOTES.md didn't happen.

**Following a style?** If the brief settled on one (see `styles/`,
`./scripts/style-lift.sh --list`), record it in `designs/<name>/style.conf`
now — one line, the style's name — and build the geometry from its tokens:

```scad
include <styles/<style>/style.scad>
$fn = style_fn;
```

`./scripts/style-check.sh <name>` then holds every printable part to that
style on each push. Adding it later means redoing geometry, so decide at
scaffold time; `/style-spec` lifts a new style if the user has a reference
they like rather than one of the packs already here.

## 2. CI configuration — decide now, not in review

- Default render is an assembled preview, or the design has multiple
  printable parts → **`ci.parts`**: one `part` value per line; CI renders
  each as `build/<name>-<part>.stl`. Without it, CI gates the default
  render of `<name>.scad` as the printable deliverable.
- Design targets a printer bigger than the default build volume → 
  **`printcheck.args`** with e.g. `--build-volume 256x256x256`, and a
  bed-fit note in NOTES.md saying which printers it fits.
- Multi-part designs: one `.scad` with a `part` parameter or
  `<name>-<part>.scad` wrappers — either way, record the choice in
  NOTES.md.
- Design has a tuned fit (threads, sliders, press-fits) →
  **`<name>-coupon.scad`**: a ≤10-line include-and-override wrapper on the
  production modules (`include <<name>.scad>` then override the grid/part
  parameters — overrides must stay above any geometry; see
  sushi-battleship-coupon.scad), plus a "Print this first" section in
  NOTES.md stating what to tune and in what steps. gate.sh gates the
  coupon STL automatically.
- If previews will be reviewed across rounds, start
  **`previews/cameras.conf`** (format in `scripts/render.sh`) so
  `./scripts/render.sh <name> --previews` regenerates every shot, and
  describe what each shot shows in `previews/CAMERAS.md`; cameras are
  fixed once a reviewer has seen them — new region, new camera entry.
- Animated previews are opt-in: add **`animations.conf`** (see the format
  note in CLAUDE.md) and embed each entry's GIF in README.md. CI renders
  and commits the GIF; the manifest and the embed are yours.
- Product shots are **expected, not optional**: `templates/README.md`
  embeds `previews/product-hero.png` the same way it embeds the contact
  sheet, so write **`shots.conf`** and keep the embed (see
  `/product-shots`). Every finished design leads its README with one.

In all three cases you declare the shot and CI produces it — the manifest
is the deliverable, the image is derived. Run a generator yourself only to
look at the result; `product-shot.sh` additionally needs `bpy`
(`.claude/hooks/session-start.sh --force --with-bpy` — `--force` too, or the
hook no-ops outside Claude Code on the web), which is not installed by
default precisely because you no longer need it to ship a design.

## 3. First render before first commit

```bash
./scripts/render.sh <name>       # STL + contact sheet must succeed
./scripts/gate.sh --slice <name> # printcheck + PrusaSlicer test-slice must exit 0
./scripts/readme-gate.sh <name>  # see below — not a "must pass" before the first push
```

The first two must pass here: they judge geometry, which is yours.

`readme-gate.sh` is different before the first push. It fails on any
`shots.conf` or `animations.conf` entry whose image doesn't exist yet, and
those images are CI's to render — so that failure is **expected**, and
"must pass" only applies after `regen` has run and committed them. Check
that everything *else* it reports is clean (title, pitch, Print settings,
Parameters), and don't install bpy just to clear the missing-image lines.

On a fork branch it *is* a real failure — CI can't push there, so the
images are yours to generate and commit (see `/preflight`).

The product shot comes before the readme gate on purpose: the template
embeds `previews/product-hero.png`, so the gate fails on a missing image
until that render has run.

Look at the bottom-iso quadrant of `build/<name>.png` for overhang and
bed-contact problems, send the PNG to the user (SendUserFile), and commit
the directory with `Add design: <name>` once it renders clean. Then
iterate preview-first per CLAUDE.md, and run `/preflight` before any push.
