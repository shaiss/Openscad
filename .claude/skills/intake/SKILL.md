---
name: intake
description: Turn a one-line design idea (or a photo of the thing to design around) into a well-formed design-brief issue — measurements asked for or defaulted with stated assumptions, printer constraints, a style from styles/ or none, a first-pass part breakdown — filed with the design-brief label so a design session can pick it up cold. Use when the user brings an idea to capture rather than build now, asks to file/queue a design brief, or when invoked as /intake [idea].
---

# Design-brief intake

Take one idea in, file one well-formed issue out. The issue is the
deliverable: a brief a design session — human-driven or scheduled — can
start the co-design loop from without re-asking what this skill already
settled. The format is `templates/design-brief.md`, and the same shape
arrives from the `Design brief` issue form when a human files by hand;
this skill exists for the cases where an interview or stated defaults are
needed to make the brief well-formed.

This skill does **not** scaffold, model, or render. The hand-off is the
issue; the next step is a design session running `/new-design` from it.
And turning a brief into a design is co-design work — a human reacts to
previews — so a `design-brief` issue is not something plain `/ship-issue`
turns into a code PR: building it would create a new `designs/<name>/`,
which that skill declines by design. A brief is the input to a design
session, or to the idea→PR pipeline this format is the first slice of,
each of which keeps its own human-in-the-loop stop points.

## 1. Input

A one-line idea (`/intake a wall bracket for the shop vacuum hose`), or a
photo of the object to design around. From a photo, extract what it shows
— the object, its mounting context, visible proportions — but never read
measurements off it: a photo has no scale. Photo-derived numbers are
estimates and go in the brief as **assumed**, with "estimated from photo"
as the source.

## 2. Interview — ask only what can't be defaulted

The brief owes four things (CLAUDE.md, co-design step 1): what the part
does, the measurements that decide the geometry, printer specifics, and a
style decision. Split them honestly:

- **Ask** (AskUserQuestion, one round, batched) for the fit/hold
  measurements no default can supply — the diameter of the thing it grips,
  the spacing of the holes it must match. These are *given* rows, each
  with its source ("user, calipers").
- **Default** everything defaultable and say so: repo FDM conventions
  (0.4 mm nozzle, walls ≥ 1.2 mm, supportless flat-side-down orientation),
  common hardware dimensions, sensible proportions. These are *assumed*
  rows, restated in **Assumptions & defaults** so they can be challenged.
- **Neither** — a measurement nobody present can supply and no default
  covers goes to **Open questions**, marked blocking or not. A brief with
  open questions is still well-formed; a brief with hidden guesses is not.

Unattended (a workflow invoked this, or the user is gone): never block on
a question. Default what's defaultable, move the rest to Open questions,
and say in the issue that the brief was filed without an interview.

## 3. Style

Settle the look now — retrofitting a style onto finished geometry means
redoing it. Offer the packs (`./scripts/style-lift.sh --list`, catalog in
`styles/README.md`) and record one of: the pack name, `none`, or — when
the user shows a reference model they like — `new — lift from <reference>
with /style-spec`, so the design session knows to run the lift before
modeling starts. Don't run `/style-spec` from here; the brief records the
intent.

## 4. First-pass part breakdown

Name the parts a session would scaffold, each with its likely print
orientation, and flag every tuned fit (threads, sliders, press-fits) —
each one means a printed coupon, so the flag prices the design honestly.
This is a first pass a session may overturn; being present and plausible
is the bar, not being final.

## 5. File it

Compose the body from `templates/design-brief.md` (drop the template's
comment block), title `Design brief: <idea>`, label **`design-brief`**.
The label may not exist yet — this repo has no labels machinery — so
create it first if missing (suggested: color `#1D76DB`, description
"Well-formed design brief a design session can pick up cold"); the issue
form's `labels:` entry also only applies once the label exists. One idea,
one issue: a second idea in the same conversation is a second `/intake`,
not a second section.

## 6. Done means

A stranger session could start modeling from the issue alone:

- every **Must fit / hold** row is given-with-source or assumed-with-a-
  stated-default — no bare numbers of unknown provenance;
- **Style** holds a decision, not a shrug (`none` is a decision);
- **Open questions** lists everything genuinely unknown, marked blocking
  or not — and if it's empty, that's a checkable claim, not an omission;
- the issue carries the `design-brief` label and the `Design brief:` title
  so the scheduled backlog and a browsing human can both find it.

Read the filed issue back once as that stranger. If any section makes you
want to ask the filer something, the brief isn't done — fix it before
leaving the issue.
