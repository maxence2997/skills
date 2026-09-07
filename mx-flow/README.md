# mx-flow

> You make a few decisions. The agent handles the rest.

Full development workflow orchestrator. One command to run the entire process from idea to verified, committable code.

## Usage

```
/mx-flow <topic>          # full pipeline: idea to PR
/mx-flow status [name]    # where every feature stands, and the next command
/mx-flow finish <name>    # post-merge cleanup
```

_Rough or detailed — the agent will ask what it needs._

**Not this skill** when the change is one obvious edit with no design choice — a rename, a
constant, a one-file fix. mx-flow's cost is the spec and the review loop; do it directly
instead (`/mx-commit` for the commit, `/mx-pr` if it needs a PR).

## What it runs

```
  Brainstorm  ──▶  Design spec + ADR
  Plan        ──▶  Ordered task list + plan checks (order, split, grounding)
  Worktree    ──▶  Isolated branch + baseline pass

  ┌─ convergent loop (max 3 iterations) ────────────┐
  │                                                 │
  │  ┌─ per task ────────────────────────┐          │
  │  │  TDD       red → green → refactor │          │
  │  │  Commit    one structured commit  │          │
  │  └──────────────────────────────────-┘          │
  │                                                 │
  │  Review      3-perspective code review          │
  │  Triage      fix / track / skip                 │
  │                                                 │
  │  ↺  fixes? → TDD + Commit → Review + Triage     │
  │  ✔  clean? → exit loop                          │
  └─────────────────────────────────────────────────┘

  Verify      ──▶  Full suite + plan completion
  PR          ──▶  Content check → draft → publish
  Finish      ──▶  Clean up branch + worktree
```

Plan, Worktree, TDD, Verify, Status, and Finish are built-in mx-flow phases. Brainstorm,
Review + Triage, and PR delegate to standalone skills (/mx-brainstorm,
/mx-team-review + /mx-review-triage, /mx-pr).

SKILL.md is a router: each phase is a short skeleton — purpose, inputs and outputs, its
gate, its guards — and the procedure itself lives in `references/` and is read on entering
that phase.

The plan phase ends with its own checks, run inline in the parent: by the end of planning
the spec, plan, and relevant code are already in its context, so nothing is delegated.
Targeted lookups ground every task in real files and symbols, then the checks fix the plan
where the split is wrong: forward dependencies get reordered, tasks hiding several
behaviors get split, overlapping tasks get merged or explicitly ordered, and vague tasks
get rewritten (max 2 passes, then conservative defaults). Execution itself is strictly
serial — one task in flight, ever: parallel task sub-agents each rebuilt context the parent
already had, multiplied machine costs (per-worktree setup, test suites contending for the
same cores), and their failure paths (merge conflicts, integration failures) re-ran tasks
sequentially anyway. *Who types* is stated, not asked: the default is **inline** (the parent
does TDD itself — fastest), announced alongside spec approval. **Delegated** (one executor
sub-agent per task — mid tier, strongest when the task touches concurrency, auth/security,
data migration or a public API — while the parent verifies, tracks the plan, and commits)
is the choice when there is a tier gap: the main-loop model sits above the strongest tier
its Agent tool can dispatch; no Agent tool means inline with no choice to state. The parent
re-runs the test suite and reads the diff before accepting an executor's work; an executor
that fails twice is escalated up the doctrine ladder, ending with the parent taking the
task inline. You can say "delegated" and switch modes between tasks at any time.

## File locations

mx-flow stores files in two places:

| Location | Contains | Lifecycle |
|----------|----------|-----------|
| `~/.mx/<project>/<name>/` | spec.md, adr.md | Permanent — survives cleanup |
| `.mx/<name>/` (project root) | plan.md, worktree/, tmp/ | Ephemeral — cleaned by `/mx-flow finish` |

`.mx/` is automatically added to `.gitignore` on first run.

## Convergent loop safety limit

The TDD → review → triage cycle runs a maximum of **3 iterations**. If findings are still unresolved after 3 rounds, mx-flow escalates and presents three options:

- **Continue** — extend the loop manually
- **Redesign** — return to the spec; the findings indicate a design problem
- **Abort** — discard the branch and start fresh

Three unresolved iterations almost always signal a design issue, not a code issue.

## Status

`/mx-flow status` shows the current stage, progress, and next action for features in the
current project. It scans `~/.mx/<project>/` for specs/ADRs and `.mx/` (project-local) for
plans, worktrees, and temp files. Use it whenever you lose track of where you are.

```
/mx-flow status              # show all features in current project
/mx-flow status <name>       # show one specific feature
```

```
mx-flow status — <project>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ● write-timeout-error-propagation  [ACTIVE] Stage 3 — TDD  4/7 tasks
  ✓ close-transport-drop-nil         PR created — /mx-flow finish to clean up
  ○ done-priority-check              Stage 1 — awaiting plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Active: write-timeout-error-propagation
Next  : continue the TDD loop — task 5: wire handler into router
```

Stages are evaluated from the strongest evidence down (6 → 0), first match wins. mx-flow
has no phase re-entry point, so Stages 1–3 continue by hand or in the session that started
them.

| Stage | Condition | Next action |
|-------|-----------|-------------|
| 0 — Nothing | No `spec.md`, no `plan.md`, no `worktree/` | `/mx-brainstorm <topic>` or `/mx-flow <topic>` |
| 1 — Spec | `spec.md` exists, no `plan.md` | `/mx-flow <topic>` (re-runs brainstorm), or plan manually |
| 2 — Plan | `plan.md` exists, no `worktree/` | Resume the mx-flow session, or create the worktree yourself |
| 3 — TDD | `worktree/` exists, tasks pending | Continue the TDD loop — names the next `[ ]` task |
| 4 — Review | All tasks `[x]`, no review report | `/mx-team-review` |
| 5 — Triage | Review report exists, no PR | `/mx-review-triage --source review` then `/mx-pr` |
| 6 — PR | PR URL found in `plan.md` | `/mx-flow finish <name>` (after merge) |
| Done (archived) | `spec.md` only — plan and worktree gone, branch merged | Nothing — the feature is finished |

It also checks for four anomalies and gives recovery instructions when found:

| Anomaly | Likely cause | Recovery |
|---------|-------------|----------|
| Worktree dir referenced but missing on disk | Worktree was removed or moved | Recreate with `/mx-flow`, or proceed in main repo |
| All tasks `[x]` but worktree never existed | Work done directly in main repo | Fine if intentional — continue to `/mx-team-review` |
| Multiple features in progress | Parallel work or stale entries | Run `/mx-flow status <name>` to focus on one |
| `plan.md` has no task list | Plan phase interrupted, or tasks never written | Re-run the plan phase, or add tasks manually |

Run outside a git repo, it lists all projects under `~/.mx/` and asks which to inspect. If
the project has no mx-flow features yet, it says so in one line and stops — not an error.
It modifies nothing: read-only.

## Example

```
/mx-flow add Redis caching to the search endpoint
```

**Brainstorm** — Agent asks its clarifying questions in one batch, each with a proposed default: Redis or in-memory? TTL strategy? Invalidation scope? Then writes a design spec and ADR to `~/.mx/<project>/search-cache/`, and waits for your approval.

**Plan** — Decomposes the spec into ordered tasks: cache interface, Redis adapter, handler wiring, integration test. Then audits that list against the repo: pins each task to real files and symbols, fixes ordering, splits oversized tasks, rewrites vague ones. Plan saved to `.mx/search-cache/plan.md`.

**Worktree** — Creates an isolated branch and worktree at `.mx/search-cache/worktree/`, runs baseline tests to confirm a clean starting point.

**TDD loop** — For each task: writes a failing test, implements the minimum to pass, refactors, and commits with a structured message.

**Review** — Three perspectives weigh in on the full diff:

```
Senior Engineer:   "Cache key not normalised — case mismatch will miss."
SRE:               "No fallback if Redis is down."
Future Maintainer: "Document why TTL=300."
```

**Triage** — Findings are sorted into fix / track / skip. Fixes loop back to TDD. Clean results move on to Verify.

**Verify → PR** — Full test suite passes and the plan checklist is complete; then mx-pr's content check autonomously cleans up review-iteration noise (Pass 1 removes mutually-cancelling changes; Pass 2 squashes fixups into parents; both tree-invariant guarded), the PR is drafted and published, its URL recorded in `plan.md`, and completion reported criterion by criterion with evidence, the paths created, and an explicit *Not done* section.

```
/mx-flow finish search-cache
```

**Finish** — Establishes the merge itself (PR state, or an empty diff against the base — squash-merges included) rather than asking you, then deletes the plan, deletes the tmp directory, and removes the worktree and branch. Design spec and ADRs are preserved permanently. It still stops and asks when the branch holds work the base does not, has unpushed commits, or the worktree is dirty.

## Notes

- Default mode auto-publishes the PR
- After merge: run `/mx-flow finish <name>` to clean up
- `.mx/` directory is gitignored automatically
- Per-phase procedures and tunable templates live in `references/`
  (plan, worktree, tdd, verify, status, finish, ai-learning entry format);
  the content check's canonical copy is `mx-pr/references/content-check.md`
  and only mx-pr runs it
- No test runner detected → mx-flow asks once for the command instead of
  guessing; a project with genuinely no test suite still owes a reviewable
  manual check in the commit, never a skipped RED step
- A missing sub-skill degrades loudly, never silently: no mx-brainstorm →
  mx-flow runs the spec gate itself; no review skill → a single
  self-review labelled `single-context, no team review`; a missing
  `references/` file → mx-flow says so and stops rather than improvising
  the phase
- Sub-agent model choice, escalation after repeated failures, and
  verification rules come from the sibling [mx-doctrine](../mx-doctrine/)
  skill
