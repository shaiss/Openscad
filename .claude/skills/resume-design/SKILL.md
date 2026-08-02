---
name: resume-design
description: Pick up an existing design cold — read its NOTES.md and state files, verify their claims against fresh renders and the gate before trusting them, then brief the human on where the design stands. Use at the start of a session that continues a previous session's design, when asked to resume/continue/pick up a design, or when invoked as /resume-design [name].
---

# Resume design — reconstruct context, verify it, then work

CLAUDE.md promises "NOTES.md is what lets a later session resume the design
cold" — this skill is how you cash that in. The order is fixed: **read,
verify, brief, then work**. No new modeling until the recorded state and the
actual state agree. Scope boundary: `/design-coach` drives one open PR to
merge from the reviewer's side; this skill reconstructs working context so
a developer session can continue the design.

## 1. Read the recorded state

For `designs/<name>/`, read everything that carries session-to-session
state:

- **`NOTES.md`** — goal, given vs assumed measurements, key decisions,
  intended print orientation/settings. This is the primary record.
- **`HARDENING.md`** (if present) — review-round findings and fixes.
- **`previews/CAMERAS.md`** and/or **`previews/cameras.conf`** — the frozen
  camera list and the exact command per shot.
- **`ci.parts`** / **`printcheck.args`** — what CI actually gates and
  against which build volume.
- **`README.md`** — the product page: promises already made to strangers.
- **Open PRs and issues** mentioning the design (`gh pr list`,
  `gh issue list --search <name>`) — an open PR may mean a coach session
  owns the review thread; read it before pushing anything.

## 2. Verify before trusting

Recorded state is a claim, not a fact. Before any new work:

```bash
./scripts/render.sh <name>       # STL + contact sheet must still succeed
./scripts/check.sh               # repo-wide syntax + docs-drift check
./scripts/gate.sh --slice <name> # printcheck + test-slice — the CI bar
```

- Re-render the frozen shots (`./scripts/render.sh <name> --previews`,
  driven by `previews/cameras.conf`) and **look at** the regenerated PNGs
  against the committed ones. Do **not** treat a non-zero pixel diff as
  drift on its own: OpenSCAD renders are only byte-reproducible within one
  environment, so a different OpenSCAD build, font set or GPU/driver
  repaints every shot at the anti-aliasing level while the geometry is
  identical. A `compare -metric AE` in the low thousands on a 1400×1000
  shot is that, not a finding.

  What counts as real drift is a *structural* difference — a feature that
  moved, appeared or vanished, a reframed camera, a changed part count.
  When the distinction matters, re-render twice in the current environment:
  run-to-run must be AE=0, so anything that differs between two fresh
  renders is nondeterminism, and anything that matches fresh-vs-fresh but
  differs from the committed PNG is environment, not source. Only restore
  or re-commit pixels when you can name the geometric change.
- Take NOTES.md's claimed key numbers (clearances, wall thicknesses, bed
  footprint, part counts) and recompute them from the `.scad` source —
  read the parameters and redo the arithmetic; don't accept the prose.

**Any mismatch is finding #1 of the session**, reported before new work
begins: either the code drifted from NOTES.md or NOTES.md lied. Say which,
with the numbers, and fix NOTES.md on the spot so the record matches
verified reality. A clean pass is also worth one line — it's what makes the
briefing below trustworthy.

## 3. Brief the human

Open with a short **state of the design** before asking what's next:

- **Goal** in a sentence (from NOTES.md, confirmed against the source).
- **Settled decisions**, each with its provenance (which session, which
  review round or reviewer) — marked **do-not-relitigate**.
- **Open questions** the record left unanswered.
- **Where the last session stopped** — what's unfinished or half-done, and
  the step 2 verdict (clean, or the mismatch that got fixed).

## 4. Guard rails for the resumed session

- **Cameras are frozen.** A new region gets a new line in
  `previews/cameras.conf` (plus its description in `previews/CAMERAS.md`);
  never move or reframe an existing one — reviewers compare before/after
  shots across rounds.
- **Decisions recorded in NOTES.md stay decided.** Reopening one takes the
  user's explicit say-so; until then treat it as a constraint, not a
  suggestion.
- Keep NOTES.md current as new decisions land — the next resuming session
  gets only what you write down.
