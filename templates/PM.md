# <Design name> — product charter

<!-- The charter the /pm skill enforces. Copy to designs/<name>/PM.md and
     fill in. This is what the design IS and who it is FOR; NOTES.md is the
     engineering log of what happened, and README.md is the product page a
     stranger reads. Keep this one short enough that a PM can hold it in
     mind — if it grows past a page it has stopped being a charter.
     Delete these comments. -->

## The product, in one paragraph

What it is, who it is for, and the one thing it must do well. If you
cannot name the customer, the design does not have a charter yet.

## Non-negotiables

Constraints that may **not** be weakened to make engineering easier. Each
needs a number and a source, and ideally an `assert` in the .scad so the
render fails rather than the reviewer catching it. State what would have
to be true to reopen each one.

| # | Constraint | Number | Source | Reopens if |
|---|---|---|---|---|
| N1 | | | | |

## Out of scope

**Deferred** — good ideas, not now, ranked in the backlog below.

**Never** — things this design will not do, with the reason. This list is
the PM's most useful asset; without it every session re-litigates the same
suggestions.

## v1 — definition of done

What must be true to call the first version finished. Checkable by someone
other than the author, and separate from "the gate is green" (which is
necessary, not sufficient).

- [ ] 

## Backlog, ranked by user value

Ranked by what a real user hits most often, not by what is interesting to
build. Include the cost where the repo can tell you (print time, filament,
part count).

| # | Item | Why this rank | Cost |
|---|---|---|---|
| B1 | | | |

## Open decisions

Questions only the human can answer. Mark which ones **block** work versus
which can proceed on a stated assumption.

| Question | Blocking? | Assumption if unanswered |
|---|---|---|

## Decision log

Append-only. Date, decision, reason. A later session must be able to tell
a considered choice from an accident.

| Date | Decision | Reason |
|---|---|---|
