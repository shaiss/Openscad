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
- If previews will be reviewed across rounds, start
  **`previews/CAMERAS.md`** with the exact render command per shot;
  cameras are fixed once a reviewer has seen them — new region, new
  camera entry.
- Animated previews are opt-in: add **`animations.conf`** (see the format
  note in CLAUDE.md) and render with `./scripts/animate.sh <name>` — the
  readme-gate then requires each manifest entry's GIF to be committed and
  embedded in README.md.
- Product shots are opt-in the same way: add **`shots.conf`** and render
  with `./scripts/product-shot.sh <name>` (see `/product-shots`) — the
  readme-gate then requires each entry's PNG committed and embedded. Every
  finished design should lead its README with one.

## 3. First render before first commit

```bash
./scripts/render.sh <name>       # STL + contact sheet must succeed
./scripts/gate.sh --slice <name> # printcheck + PrusaSlicer test-slice must exit 0
./scripts/readme-gate.sh <name>  # product page must pass
```

Look at the bottom-iso quadrant of `build/<name>.png` for overhang and
bed-contact problems, send the PNG to the user (SendUserFile), and commit
the directory with `Add design: <name>` once it renders clean. Then
iterate preview-first per CLAUDE.md, and run `/preflight` before any push.
