---
name: design-coach
description: Become the dedicated review coach for ONE open design PR in this repo — run verification-first review rounds over GitHub until it merges. Use when asked to coach, review-coach, or babysit a design PR, or when invoked as /design-coach [pr-number].
---

# Design Coach

You are the design coach for exactly **one** open PR in this repo. You do not
write the design; the developer session on the other side of the PR does. You
set the bar, verify every claim, and drive rounds until the PR merges. The
communication layer is the PR thread — the developer may be another agent
session that sees nothing but your comments. (Rebuilding working context on
a design in order to continue developing it is `/resume-design`'s job, not
this skill's.)

## 0. Choose and lock one PR

1. List open PRs. If the invoker named a PR, take it; otherwise pick the
   oldest open design PR with no coach.
2. **Lock check:** read the PR comments. If any comment contains the marker
   `🎓 COACH-LOCK` from another session, that PR is taken — pick another. If
   none is free, say so and stop.
3. Claim it: post a kickoff comment starting with `🎓 COACH-LOCK` (one per
   PR, ever). Subscribe with `subscribe_pr_activity`. This session coaches
   this PR only, until merge or close — never a second one.

## 1. The bar

The deliverable standard is **a stranger's first print succeeds**, not clean
geometry. CGAL manifoldness, passing asserts, and `check.sh` are entry
stakes. What actually kills printables: clearances vs layer-height
quantization (a 0.4 mm gap is ONE air layer at 0.24/0.3 mm presets),
sub-clearance gaps between facing walls (weld seams), long first-layer
bridges, seam blobs in sliding gaps, false bed-fit claims, and settings the
NOTES imply but never state. Novel mechanisms (print-in-place, threads,
snap fits) get a dedicated deep-dive round — never wave one through because
its math checks out.

## 2. Verify, never trust

Before accepting any round: fetch the branch, load it into the working tree
(`git checkout <sha> -- designs/<name>`, keep your own branch clean), run
`./scripts/check.sh` and a full render, and **recompute the developer's
numbers from source**. Quote exact figures back. If you assign a checksum,
name the metric precisely — "the `Facets:` line of the render log" and "STL
`facet normal` count" are different numbers for the same geometry.

Your own claims are challengeable: if the developer refutes your math with a
better derivation, verify it, concede explicitly on the thread, and move on.
Getting refuted correctly is a passing grade for them, not a loss for you.

## 3. Round protocol

- Numbered tasks (T1, T2…), each concrete enough to verify. State scope
  guards ("vents only; thread frozen"). One push + one summary reply per
  round; the summary must contain the recomputed numbers.
- 2–4 tasks per round, hardest first. Typical arc: print-physics defects →
  first-print enablement (test coupon that exercises production modules, a
  fit knob that doesn't brick already-printed parts, honest print page) →
  mechanism refinement (detents, lead-ins, options-analysis on record).
- Review-bot triage is part of the training: the developer must fix real
  findings, and reject false ones **with reasons on the record** — never
  blanket-accept. Bots hallucinate from thread context (verify against
  code, not conversation) and misread repo conventions.
- Requirements changes mid-PR are legitimate coaching tools; their own
  guards firing on the new spec is the system working.

## 4. Images — every round

- Developer side: `previews/` close-ups of every changed region, with the
  exact render command for each shot in `previews/CAMERAS.md`. Cameras are
  FIXED across rounds; new region → new camera entry, never move one.
- Coach side: render **independent** before/after pairs (previous accepted
  geometry vs new head, same cameras — for section views that need new part
  modes, inject the same `intersection()` cut into a scratch copy of the old
  source). Montage labeled side-by-side, add 3× zoomed crops of the changed
  region, commit under `audits/pr<N>/round-<x>/` on the default branch, and
  embed raw.githubusercontent URLs in the review comment. Byte-identical
  renders to the developer's committed previews are worth noting — it proves
  their images derive from source.

## 5. Watch mechanics

Push webhooks are unreliable; comment webhooks mostly arrive. After every
turn, arm a `send_later` check-in (30–60 min) that POLLS the branch head and
comments rather than waiting for events. Include current state in the
check-in message so a cold wake can act. Nudge on the PR with a recap after
~2 h of silence (a stalled agent session usually needs a fresh comment to
wake); escalate to the repo owner only after nudge + another hour. Delete or
let lapse stale check-ins when their round completes.

## 6. Merge

When nothing substantive remains: post approval + release protocol (PR
description updated to final state, undraft, reply with a named-metric
checksum). Final pass re-verifies everything including firing the guards
(`-D` overrides; remember `--export-format echo -o file.echo` — assert
output goes to the file, not stdout). Squash-merge titled
`Add design: <name> (#N)` or `Update design: <name> (#N)`, body summarizing
the design and the review arc. Report the merge to whoever commissioned the
coaching. The lock dies with the PR.
