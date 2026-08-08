# GitHub Actions security posture: dispatch-selects-branch

This is the tracked decision for [issue #113](https://github.com/shaiss/print-bench/issues/113) — a follow-up from the CodeRabbit review on [#112](https://github.com/shaiss/print-bench/pull/112#discussion_r3740564181), which agreed the property belonged in its own record rather than a PR thread. It documents a property of GitHub Actions, the workflows in this repo it touches, and the posture we have accepted toward it. It changes no workflow, because the property cannot be fixed inside a workflow — see below.

## The property

A `workflow_dispatch` run **executes the workflow YAML from the ref (branch or tag) the dispatcher selected**, not from the default branch. The same is true of a `push`-triggered run: it executes the pushed branch's copy of the YAML. So for any manually-dispatchable (or push-triggered) workflow that

- grants **write** permissions (`contents`, `issues`, `pull-requests`), and
- exposes a **secret** (e.g. `REGEN_TOKEN`, `ANTHROPIC_API_KEY`, `ZAI_KEY`), and
- runs **inline shell or an action** with those grants,

a user who dispatches a **branch on which they have rewritten that workflow file** runs *their* steps with those grants and that secret. The rewritten steps are whatever they authored.

### Why no in-YAML guard closes it

Pinning `actions/checkout` to the default branch — as [#112](https://github.com/shaiss/print-bench/pull/112) did for `log-print-result.yml` (`ref: ${{ github.event.repository.default_branch }}`) — protects the **working-tree scripts** the job runs: it guarantees the checked-out `scripts/`, `tools/`, etc. are the trusted default-branch copies, not the dispatch ref's. It does **not** protect the **workflow definition itself**. The `steps:` that decide *what runs at all*, which secrets are wired into which step, and what permissions the job holds are read from the selected ref's YAML **before** any checkout step executes. No guard written inside the file can help, because a dispatcher who controls the file simply deletes the guard along with everything else. The checkout pin and this property are orthogonal: a pinned-checkout workflow is still fully subject to the definition vector on dispatch.

## Scope of the risk (bounded)

`workflow_dispatch` **requires repository write access.** Only an already-trusted collaborator can trigger one, and such an actor already has equivalent avenues (they can push to branches, open PRs that run CI, and — for `contents: write` secrets like `REGEN_TOKEN` — already operate inside the trust boundary those secrets assume). This is a **defense-in-depth / least-privilege** consideration, not an external-attacker vector. It is **not reachable from a fork**: a fork PR's `GITHUB_TOKEN` is read-only and repo secrets are not exposed to fork-triggered runs, so none of the write+secret combinations below are available to an untrusted contributor. Hence: tracked, not urgent.

## Inventory — write-scoped, manually-dispatchable workflows

Every workflow in `.github/workflows/` that has a `workflow_dispatch` trigger **and** a write grant **and** a secret. Audited from the tree (the set has grown since #113 was filed, which named only the first two).

| Workflow | Triggers | Write grants | Secret(s) | Off-by-default gate | `checkout` ref |
|---|---|---|---|---|---|
| `log-print-result.yml` | `workflow_dispatch` | contents, pull-requests | `REGEN_TOKEN` | `PRINT_FEEDBACK_ENABLED` | pinned to `default_branch` |
| `backlog-burn.yml` | schedule, `workflow_dispatch` | contents, issues, pull-requests | `ANTHROPIC_API_KEY`, `ZAI_KEY` | `BACKLOG_BURN_ENABLED` + committed `enabled:` | unpinned (selected ref); `persist-credentials: false` |
| `design-run.yml` | schedule, `workflow_dispatch` | contents, issues, pull-requests | `CLAUDE_KEY`, `GH_TOKEN`, `ZAI_KEY` | `DESIGN_RUN_ENABLED` + committed `enabled:` | pinned to `default_branch` |
| `lifestyle-shot.yml` | push (`designs/*/lifestyle.conf`), `workflow_dispatch` | contents, pull-requests | `GITHUB_TOKEN`, `ZAI_KEY` | none — gated on `ZAI_KEY` presence | unpinned |
| `lifestyle-clip.yml` | push (`designs/*/motion.conf`), `workflow_dispatch` | contents, pull-requests (job-level) | `GITHUB_TOKEN`, `ZAI_KEY` | none — gated on `ZAI_KEY` presence | unpinned |
| `backlog-burn-config.yml` | `issue_comment`, `workflow_dispatch` | issues, pull-requests | `REGEN_TOKEN` | none | trusted base-branch tooling only (see note) |

Notes:

- The **`checkout` ref** column describes only the working-tree-script mitigation. As established above, it is orthogonal to the definition vector — a `default_branch`-pinned row is still subject to the property on dispatch. The pin remains worthwhile: it closes the separate script-substitution path #112 was about.
- The **off-by-default gates** are the more material mitigation for the two autonomy routines and the print-feedback logger: with `PRINT_FEEDBACK_ENABLED` / `BACKLOG_BURN_ENABLED` / `DESIGN_RUN_ENABLED` unset (the default clone/fork state), those workflows halt early with a `::notice::` and never reach their write steps. That reduces exposure but does not eliminate the property, since a dispatcher rewriting the YAML can also delete the gate check.
- **`backlog-burn-config.yml` is listed for its `workflow_dispatch` trigger only.** Its `issue_comment` path is *not* subject to the property (see the next section); but because it *also* carries a `workflow_dispatch` trigger, that path runs the selected ref's YAML with `REGEN_TOKEN` like the others. Its by-design safety (Contents-API-only writes, never checking out the PR head) is a property of its *steps*, which a dispatch-ref rewrite replaces.

## Related-but-distinct vectors

The dispatch property is one member of a family "the trigger runs *that ref's* YAML." Two neighbours the issue flagged, confirmed here:

- **Push-triggered `regen` in `ci.yml`.** A `push` (or same-repo PR) runs the pushed branch's YAML, and `regen` holds `contents: write` (job-level) with `REGEN_TOKEN`. Same risk class as dispatch: a collaborator pushing a branch with a rewritten `ci.yml` runs their `regen` steps with the PAT. Same bound applies — and is enforced in the job: `regen` pushes with `REGEN_TOKEN` **only when the head repo is this repo** (`github.event.pull_request.head.repo.full_name == github.repository`); a fork gets the read-only `GITHUB_TOKEN` and the job fails with the file list instead of pushing. So the PAT-write path is reachable only from trusted, same-repo branches.
- **`issue_comment`-triggered privileged workflows.** `ci-gate-approve.yml` (and `backlog-burn-config.yml`'s `issue_comment` path) run in the **base repository's context from the default branch by GitHub's design** — an `issue_comment` event always uses the default-branch copy of the workflow, regardless of the PR's head branch. **Assumption confirmed.** They are therefore *not* subject to the dispatch-selects-branch property on that trigger. Both reinforce it structurally: they never check out or execute the PR head, and treat the registry / config files as **data through the Contents API**, so even a malicious PR head cannot inject code into the privileged run. (`ci-gate-approve.yml` has no `workflow_dispatch` trigger at all; `backlog-burn-config.yml` does, which is why it appears in the inventory above for that path.)

## The decision

**Accept and document the current posture** (Option 2 of the two #113 listed). Rationale: write-access ⇒ already-trusted actor; not reachable from a fork; the two heaviest routines are off by default; and the property is intrinsic to `workflow_dispatch` — no file in the repo can neutralize it.

**Option 1 — a repo/org Actions policy or ruleset restricting who may dispatch or from which ref — is not a mergeable change.** It is a GitHub settings/admin action, and GitHub exposes no native file-based "dispatch from the default branch only" toggle. It is recorded here as the available lever, not applied:

- **Restrict who can dispatch.** `workflow_dispatch` already requires write access; tightening *which* collaborators hold write (or moving the write-scoped jobs behind a GitHub **Environment** with **required reviewers**, so a dispatched run pauses for approval before its write steps) is the closest native control. Environment protection rules *do* gate the job regardless of which ref's YAML defined it, because the environment's reviewers are configured in repo settings, not in the selectable file — so this is the one lever that survives a YAML rewrite.
- **Restrict the ref.** There is no first-class "dispatch only from default branch" setting; the practical equivalents are branch **rulesets** limiting who can create/push the `claude/*` and feature branches a dispatch would select from, plus keeping the write-scoped secrets on **Environments** as above.

If a future maintainer wants to move from "documented" to "enforced," the Environment-with-required-reviewers route is the recommended next step, and it is a settings change plus a small `environment:` addition to each write-scoped job — a separate, deliberate piece of work, filed as its own issue.

This document is the record #113 asked for. It is intentionally descriptive: it does not change any workflow, because the issue is explicit that an in-YAML guard is ineffective and the effective lever lives in repository settings.
