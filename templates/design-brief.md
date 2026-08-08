<!-- The design-brief format — the input contract of a design session. This
     is the shape /intake files and the .github/ISSUE_TEMPLATE/design-brief.yml
     issue form collects; the section headings here and that form's field
     labels must stay identical. The brief becomes the BODY of an issue
     titled "Design brief: <idea>" and labeled `design-brief`; a design
     session (human-driven or scheduled) picks it up cold and starts the
     co-design loop at Scaffold, so everything Brief owes — measurements,
     printer constraints, a style decision, stated assumptions — must be in
     here or in Open questions. Delete these comments. -->

## What it is

One paragraph: what the part does, where it lives, what it must interact
with. If you cannot say who uses it and for what, the idea is not ready to
brief.

## Must fit / hold

The measurements that decide the geometry — what the part must fit around,
hold, or mate with. Every row is either **given** (measured, with the
source) or **assumed** (a stated default a session may challenge). A
dimension nobody can supply yet is not a guess — move it to Open questions.

| Dimension | Value (mm) | Given / assumed | Source |
|---|---|---|---|
| | | | |

## Printer & material

Printer, nozzle, material, and anything build-specific (bed size if
non-default, enclosure, supports tolerance). When the filer doesn't care,
say so and the repo's FDM defaults apply: 0.4 mm nozzle, walls ≥ 1.2 mm,
print flat-side-down without supports where possible.

## Style

One of: a pack name from `styles/` (catalog: `styles/README.md`, or
`./scripts/style-lift.sh --list`), `none`, or `new — lift from <reference>
with /style-spec` when there's a model the look should come from. Deciding
here is the point: retrofitting a look onto finished geometry means redoing
it.

## First-pass part breakdown

The parts a session would scaffold: each part, its likely print
orientation, and any tuned fit (threads, sliders, press-fits) — a tuned fit
means a coupon, so flagging it here prices the design honestly.

## Assumptions & defaults

Everything defaulted above, restated in one list so a session (or the
filer, reading back) can challenge each one without re-deriving which
numbers were guesses.

## Open questions

What must be asked before modeling starts, and which of them **block**
scaffolding versus which can proceed on the stated assumption. An empty
section is a claim: it says a session can start modeling from this brief
alone.
