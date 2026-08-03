---
name: ship-issue
description: Pick ONE open issue and ship the draft PR that closes it — scope contract frozen on the issue before any code is read, diff audited against it in both directions, CI mirrored locally. Use when asked to work/close/ship an issue, to burn down the issue backlog, to turn an issue into a PR, or when invoked as /ship-issue [issue-number].
---

# Ship Issue — one issue in, one PR out

You take **exactly one** open issue and land a draft PR that closes it. The
whole point is the boundary: the PR does what the issue asked, all of it, and
nothing else. Everything below exists to make that claim checkable by someone
who reads only the issue and the diff.

This skill runs the same attended (a human invoked it) or unattended (a
workflow did). Section 7 says what changes when nobody is watching.

## 0. Claim exactly one issue

1. If the invoker named an issue, take it. Otherwise select per §1.
2. **Lock check** — an issue is taken if any of these hold; move to the next
   candidate:
   - a comment contains the marker `🚢 SHIP-LOCK`
   - an open PR body says `Closes #<N>` / `Fixes #<N>` (search open PRs)
   - a remote branch `claude/issue-<N>-*` already exists
3. Claim it by posting the §2 contract as a comment led by `🚢 SHIP-LOCK`.
   One per issue, ever. The comment's timestamp is the proof the contract
   predates the diff — that is the whole anti-retrofit mechanism, so post it
   **before** you read a line of implementation code.

If no issue is free, say so and stop. Never work two.

## 1. Select — is this closeable by one PR?

Rank the free candidates by shippability, not by age:

**Take it** when the issue states a defect or a bounded change, and you can
name the finished state from the issue text alone. Best signals: a
reproduction, a measured number, an explicit deliverable list, "decisions
locked", or an owner comment picking between named options.

**Decline it** — comment saying why, don't half-do it:
- **`design request` label, or any new `designs/<name>/`.** A design is a
  co-design session with a human reacting to previews (`/new-design`, then
  the CLAUDE.md loop). This skill cannot approve a shape on the user's
  behalf. Say that and leave it.
- **Open question inside the scope.** If the issue offers options and nobody
  picked one, and the choice changes what ships, ask on the issue and stop.
  (#37-style issues that *recommend* an option — "A is the better fix" — are
  decided; take the recommendation and record it in the contract.)
- **Bigger than one reviewable PR.** Multiple independent deliverables that
  could merge separately → propose the split as a comment listing the
  sub-issues you'd file, and stop.

An issue nobody can close in one PR is a triage result, not a failure.
Reporting it is the deliverable.

## 2. Freeze the scope contract — before reading code

Written from the **issue text only**. Reading the implementation first
contaminates it: you start writing criteria that describe the fix you
already have in mind instead of the outcome the issue asked for.

```markdown
🚢 SHIP-LOCK — shipping this as one PR.

**Chosen approach:** <the option the issue picked, or the only one on offer>

**Acceptance criteria** (done = every box checked, verified not asserted)
- [ ] AC1 — <outcome, with the number the issue names>
- [ ] AC2 — …
  (mine the issue's own "the deliverable includes" list — those are ACs,
  not extras; that list is the author telling you where the blast radius ends)

**Touches:** <path globs — every file this PR may change>
**Explicitly not in scope:** <adjacent things a reader might expect; say
where each goes instead — usually "follow-up issue">
```

Every AC must be checkable by a command or a measurement, not by reading the
diff and agreeing with it. "`flank_add` derivation corrected" is not an AC;
"exported flank facet normals measure |nz| = 0.707 ± 0.005" is.

## 3. Build

Branch: the session's designated branch if the harness assigned one,
otherwise `claude/issue-<N>-<slug>` off the current default branch. Commit in
steps that map to ACs; message body ends with `Refs #<N>`.

Follow the repo's conventions from CLAUDE.md — they are not optional extras
you can defer to a follow-up: parametric variables with units, `$fn`
declared, first-party lib change ⇒ its `lib/<name>-demo.scad` exercises the
change, docs-drift assertions in `scripts/docs-check.sh` stay true.

## 4. Blast radius is not scope creep — but adjacent defects are

Know the difference, because getting it backwards is how this skill fails in
both directions:

- **Consequence of the fix ⇒ in scope, ship it.** A `lib/` geometry change
  moves every design that includes it: committed previews under
  `designs/*/previews/` re-render, the design's NOTES.md derivation is now
  wrong, the gallery may shift. Leaving those stale ships a repo that
  contradicts itself. Re-render with the **frozen cameras**
  (`./scripts/render.sh <name> --previews`) — never reframe a camera to make
  a diff look better.
- **Defect you noticed on the way ⇒ out of scope, file it.** Open a new
  issue with the reproduction you already have, link it from the PR, move
  on. This is the single most common creep: the fix is done, the file is
  open, and the adjacent wart is *right there*.
- **Refactor, rename, tidy ⇒ out of scope.** Always. Even one line.
- **Contract wrong?** If implementation proves an AC impossible or
  incomplete, amend it on the issue thread as a new comment saying what
  changed and why — then keep going. Amending in the open is legitimate;
  silently drifting is not.

## 5. Verify — two independent passes

**Pass A — would CI pass?** Run `/preflight`. It owns the check set and the
scoping rules; do not maintain a competing list here. A red result is a stop.

**Pass B — scope audit.** Both directions, over
`git diff --name-only $(git merge-base origin/<default-branch> HEAD)`:

| direction | question | failure mode it catches |
|---|---|---|
| diff → contract | does every changed file match a `Touches` glob and serve a named AC? | creep, drive-by edits, stray build artifacts |
| contract → diff | does every AC have a diff hunk **and** evidence it holds? | under-delivery, ACs quietly dropped |

Evidence means a re-derivation, not a restatement. Issue #37's third
consequence is the cautionary tale: the demo echoed the algebraic identity
that *defines* the constant and printed "should equal 0.3" while the built
geometry measured 0.2794. **Measure the exported artifact** — facet-normal
histograms, printcheck output, render logs — never the formula you just
typed. If an AC's evidence can only be produced by hand today, add the check
to the lib demo so the next session gets it for free.

Anything unmapped: revert it, or file it, before the PR exists.

## 6. Ship

Draft PR, base = default branch, title stating the outcome (not "fix #37").
Body:

1. `Closes #<N>` on its own line.
2. The frozen contract with boxes now checked, **linking the claim comment**
   so a reader can see it predates the diff.
3. The scope-audit table from Pass B — file → AC, and AC → evidence with the
   actual numbers.
4. Preflight verdict, and anything deliberately left out with its follow-up
   issue link.

Then `subscribe_pr_activity` and drive it to green per the PR-ownership
rules — a PR you opened is yours until it merges or closes.

## 7. Unattended mode (a workflow invoked this)

Same skill, three tightenings — nobody is there to catch a wrong guess:

- **Never guess past an ambiguity.** Attended, a judgement call is a
  question. Unattended, it is a `🚢 DECLINED — needs a decision` comment
  naming the options, and a clean stop. A stopped run costs nothing; a
  confidently wrong PR costs a review.
- **Hard stop conditions:** preflight red after one honest fix attempt; the
  diff outgrowing `Touches` in a way that isn't §4 blast radius; the issue
  turning out to need a human's taste (any shape, any look, any "is this
  what you meant"). Stop and comment — never push a PR you'd have to
  apologise for.
- **The issue thread is the only log.** Assume nobody reads the run output.
  Claim, amendments, declines, and the final verdict all land as comments,
  each one readable cold.
