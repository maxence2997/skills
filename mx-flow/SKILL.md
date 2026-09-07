---
name: mx-flow
description: >
  Full development workflow orchestrator: brainstorm → plan → worktree →
  convergent TDD/review loop → verify → PR. One human gate (spec approval);
  all other gates auto-proceed. Use when starting a feature or significant
  change from scratch. Usage: /mx-flow <topic>; /mx-flow status [name];
  /mx-flow finish <name>.
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/mx-flow
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - Agent
  - Task
---

# mx-flow

## Trigger

```
/mx-flow <topic>          ← full pipeline: idea to PR
/mx-flow status [name]    ← where every feature stands, next command
/mx-flow finish <name>    ← post-merge cleanup (read references/finish.md and follow it)
```

**Not this skill** when the change is one obvious edit with no design
choice — a rename, a constant, a one-file fix. Say so and do it directly
(/mx-commit for the commit, /mx-pr if it needs a PR). mx-flow's cost is the
spec and the review loop; a change that needs neither should not pay for them.

## Non-negotiables

Violating any of these is a workflow failure. They bind every phase and
every sub-agent this skill dispatches.

1. **Worktree before any code edit** — before making any code change,
   verify the working directory is a git worktree
   (`git rev-parse --git-dir` contains `worktrees/`). If not, STOP and run
   Phase 4 first.
2. **Iron Law — no production code without a failing test first.** Code
   written before its test exists must be deleted and reimplemented after
   the test is in place. No exceptions.
3. **Never weaken a gate to get green** — no `--no-verify`, no lint
   suppressions to silence a finding, no deleting/skipping a failing test,
   no rewriting a RED test to match broken behavior, no relaxed assertions,
   no widened timeouts. A gate fighting you is a design signal: apply the
   wrong-direction rubric (doctrine below) — change approach or ask.
4. **Review before verify** — do not enter Phase 6 unless mx-team-review
   and mx-review-triage have run on the current branch diff at least once
   in this session. If unsure, check for a review report in
   `.mx/<name>/tmp/`.
5. **Retry budget** — the same task failing verification twice (regardless
   of approach) → stop retrying. In a harness with sub-agents, escalate to
   the strongest tier with the full failure trail (what was tried, exact
   diffs, exact errors); otherwise present that trail to the user with
   concrete options. Never a third identical attempt. (Small-tier/haiku
   workers get only ONE attempt before escalating — counting rule:
   mx-doctrine model-dispatch §6.)

## Gates

mx-flow pauses at **one human gate** (spec approval). All other gates
auto-proceed — reports are still shown for visibility. Gates are review
opportunities, not "y/n continue" prompts.

| Gate | Behaviour |
|------|-----------|
| **GATE 1 — Spec** | **Human.** Show the draft spec; discuss and adjust until the user explicitly confirms. Do not proceed without approval. With the approval, state the default execution mode (inline / delegated) for Phase 5a; the user may switch at any time. |
| **GATE 2 — Task list** | Auto. After the plan checks, show the task list for visibility, then proceed immediately. |
| **GATE 3 — Triage** | Auto. Show the triage report, auto-approve all "fix" items, execute immediately. |
| **GATE 4 — PR** | Auto. Draft and publish the PR autonomously; show the draft for visibility. Pause only if the agent cannot determine how to proceed (no remote, ambiguous platform, missing credentials). |

The convergent-loop safety limit (3 iterations, Phase 5) always applies —
its escalation requires human input regardless.

**Orchestrated sub-skills:** the sub-skills this flow invokes contain
their own interactive pauses. This gate table overrides those pauses at
GATE 2/3/4. From their side: mx-team-review, mx-review-triage, and mx-pr
each carry an "Orchestrated mode" section stating the same; mx-commit is
orchestrated by passing `--auto` (no section needed); mx-brainstorm's only
pause is GATE 1, which stays human. (Invocation spelling per harness:
mx-doctrine model-dispatch §0.)

## Doctrine

Shared execution doctrine ships in the sibling `mx-doctrine` skill. Paths
resolve as `${CLAUDE_SKILL_DIR}/../mx-doctrine/references/<file>` — if a
file is missing (partial install), say so once and use the fallback noted
at each reference site.

- `model-dispatch.md` — model tiers for every sub-agent this flow spawns
  (§4 has a table of mx-flow's dispatch sites); escalation ladder (§6).
- `judgment-rubrics.md` — when done is done (§2), when to stop and ask
  (§3), wrong-direction signals (§4), quality floor (§5).
- `delegation-templates.md` — prompt shapes if you need an ad-hoc
  sub-agent beyond the ones this file specifies.

Fallback when mx-doctrine is absent: dispatch execution sub-agents at the
mid tier (`sonnet`), decisions/reviews at the strongest available; apply
the Non-negotiables above literally.

## Path resolution

All phases use two base directories. Resolve them once at the start.

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
PROJECT=$(basename "$REPO_ROOT")
```

| Variable | Path | Contains |
|----------|------|----------|
| `GLOBAL_MX` | `~/.mx/<project>/<name>/` | spec.md, adr.md (permanent) |
| `LOCAL_MX` | `<repo-root>/.mx/<name>/` | plan.md, worktree/, tmp/ (ephemeral) |

- `~/.mx/<project>/ai-learning.md` is also in GLOBAL (project-level, not per-feature)
- Create directories as needed: `mkdir -p` for both GLOBAL_MX and LOCAL_MX
- On Windows: `GLOBAL_MX` = `%USERPROFILE%\.mx\<project>\<name>\`

Each phase below is a skeleton — purpose, in/out, gate, guards; its procedure lives in `references/` and is read on entering the phase.

## Phase 0 — Initialize

1. Derive the feature name from the topic (kebab-case, ≤ 4 words).
   Example: `write-timeout-error-propagation`
2. Resolve GLOBAL_MX and LOCAL_MX per the path resolution section above
3. Create both directories if they do not exist
4. **Check `.gitignore`** — ensure `.mx/` is gitignored:
   ```bash
   grep -q '^\.mx/$' "$REPO_ROOT/.gitignore" 2>/dev/null \
     || echo '.mx/' >> "$REPO_ROOT/.gitignore"
   ```
   If `.gitignore` was created or modified, commit it:
   `git add .gitignore && git commit -m "chore: add .mx/ to .gitignore"`
5. **Read relevant context** — based on the topic, use Glob and Read to
   collect information the brainstorm will need:
   - Files, modules, or packages mentioned explicitly in the topic
   - Related code that is likely in scope (e.g. if topic mentions a component, read adjacent files)
   - Any design docs, behaviour specs, or CLAUDE.md files that apply
   - Read broadly enough that the brainstorm's clarifying questions are grounded in actual code
6. Announce clearly:

```
mx-flow started
Feature : <feature-name>
Spec    : ~/.mx/<project>/<name>/spec.md (will be written after GATE 1)
Plan    : .mx/<name>/plan.md
Phase   : 1 — Brainstorm
```

Do this before asking any questions or writing any files.

## Phase 1 — Brainstorm

Run /mx-brainstorm with the following context:
- The GLOBAL_MX directory has already been created in Phase 0
- The topic is already provided — begin asking clarifying questions immediately, do not ask if the user wants to start

Follow mx-brainstorm's full procedure. It owns the spec and ADR output
(written to GLOBAL_MX). If mx-brainstorm is not installed, run GATE 1
yourself: propose 2–3 distinct approaches, get an explicit approval, write
spec.md to GLOBAL_MX — do not skip the gate.

**GATE 1**: Present the draft spec. Do not proceed until the user
explicitly confirms.

With the spec approval, state (do not ask) the Phase 5a execution mode — the default is
`inline`, the parent running the TDD cycle itself (both modes are defined in
`references/tdd.md`). Choose `delegated` instead when there is a tier gap: your main-loop
model sits above the strongest tier in your Agent tool's `model` enum (map by tier, not
by name — mx-doctrine model-dispatch §1). No Agent tool → inline, no choice to state. Say
it in one line and continue; the user can say "delegated" at any point and switch between
tasks (their instruction always wins). Record the mode for Phase 5a.

## Phase 2 — Plan

Decompose the approved spec into a concrete, ordered task list, then audit that list before any code is written.

- **In**: `GLOBAL_MX/spec.md` (approved at GATE 1) plus the existing code. **Out**: `LOCAL_MX/plan.md` — ordered tasks, one behaviour each, every one traceable to a sentence in the spec.
- Never skip the plan checks — they are the last cheap place to catch a bad task split. A vague or oversized task found here costs one plan edit; found in Phase 5 it costs TDD rounds against the retry budget.

**GATE 2**: after the plan checks, show the task list for visibility, then
proceed immediately. Announce: `Task list auto-approved.` Allow the user to
add, remove, reorder, or rewrite tasks if they intervene before auto-proceed.

Read ${CLAUDE_SKILL_DIR}/references/plan.md and follow it. If the file is missing, say so and stop — do not improvise the phase.

## Phase 4 — Worktree

Create an isolated git worktree for the feature branch: branch prefix from the plan's dominant
commit type, a verified base ref, dependencies installed, a detected test runner, green baseline.

- **In**: `LOCAL_MX/plan.md`. **Out**: branch + worktree at `.mx/<name>/worktree/`, the base ref, the runner command, the baseline count.
- The base ref (4.2) and the runner detection (4.4) resolved here are **canonical** — Phases 5b, 6 and 7 and mx-pr reuse both instead of re-deriving them.
- **If baseline fails:** report the failures and ask the user whether to proceed or investigate first. Do not proceed silently with a failing baseline.

Read ${CLAUDE_SKILL_DIR}/references/worktree.md and follow it. If the file is missing, say so and stop — do not improvise the phase.

## Phase 5a — TDD cycle (per task, strictly serial)

Execute the plan one task at a time, in plan order, in the execution mode chosen at
GATE 1 (no recorded choice → inline). Either mode is **strictly serial — one task in
flight, ever**. Parallel dispatch stays removed (mx-doctrine model-dispatch §2). The
user may switch modes between tasks; their instruction always wins. All rules in this
phase bind whoever types — parent or executor; Non-negotiables 1–3 govern every cycle.

**Exit condition checklist** — Before marking the task done, verify all
seven conditions:

```
□ RED observed: test failure was seen with actual output (not assumed)
□ GREEN confirmed: test passes after implementation
□ Full suite clean: no new failures introduced by this change
□ Deterministic test: the new test touches no real clock (no sleep, timer, timeout or polling) and no machine state; fixed instants / fake clock only
□ Comment policy: no WHAT-comments, no vague pronouns, magic numbers/workarounds explain WHY, every comment ≤3 lines
□ Plan updated: task marked [x] in .mx/<name>/plan.md
□ Committed: /mx-commit --auto completed for this task
```

If any item is unchecked, do not advance to the next task. After each task completes, take
the next `[ ]` task in plan order. Exit to 5b when all tasks are done or a milestone is reached.

Read ${CLAUDE_SKILL_DIR}/references/tdd.md and follow it. If the file is missing, say so and stop — do not improvise the phase.

## Phase 5b — Review (at milestone)

Run /mx-team-review on the diff since the branch was created, using the base branch
resolved in Phase 4.2, then /mx-review-triage with `--source review` (no auto-detect).

If either review skill is missing, say so once and satisfy Non-negotiable
4 with a single self-review of the branch diff labelled `single-context,
no team review` (per mx-doctrine model-dispatch §5); do not silently skip
Phase 5b, and do not treat the missing skill as permission to skip
Phase 6.

**GATE 3**: Show the triage summary, auto-approve all "fix" items, execute immediately
(commits go through `/mx-commit --auto`). "Track" items are still written to TODOS.md
and "Skip" items noted in the report — both without pausing. Announce:
`Triage auto-approved — executing <N> fixes.`

**Loop safety limit** — the convergent loop has a maximum of **3 iterations** (one
iteration = one full tdd → review → triage cycle). At 3 iterations without converging to
clean, do not continue automatically: show the escalation block from `references/tdd.md`
and wait for the user to choose.

Read ${CLAUDE_SKILL_DIR}/references/tdd.md and follow it. If the file is missing, say so and stop — do not improvise the phase.

## Phase 6 — Verify and commit

Final verification gate. No partial checks accepted.

- Run the complete test suite with the runner from Phase 4.4. **No partial runs.** If all pass, state the count explicitly: `N tests passing, 0 failures`.
- Read `LOCAL_MX/plan.md`; every task line must be `[x]`. If all are, report: `All N tasks complete.`
- **If any test fails or a task is still `[ ]`:** report it, then return to Phase 5a and fix it — this is option [A] of the abort path and it is the default; you do not need permission to take it. Re-enter Phase 6 when green. Present the [A]/[B]/[C] menu and wait only when Non-negotiable 5's retry budget is exhausted on the same failure, or when the fix would change the spec.

Read ${CLAUDE_SKILL_DIR}/references/verify.md and follow it. If the file is missing, say so and stop — do not improvise the phase.

## Phase 7 — PR

Run /mx-pr (if the mx-pr skill is not installed, tell the user the flow
ends here and hand them the branch name and base branch — do not improvise
a PR). It will:
- Run the commit-history content check — mx-pr owns that procedure and runs it unconditionally; mx-flow no longer runs a copy
- Draft the PR description from the spec and git log
- Publish or hand off

**GATE 4** applies: auto-proceed — draft the PR and publish directly. Show the draft for
visibility but do not wait for confirmation (mx-pr's "Orchestrated mode" section defers
to this gate). Only pause and ask the user if:
- No git remote is configured
- Multiple remotes exist and the target is ambiguous
- Platform credentials are missing or authentication fails
- Any other situation where the agent cannot determine the correct action

Announce: `PR auto-published.` mx-pr prints `PR created: <url>` — append
that URL to `LOCAL_MX/plan.md` as a line `PR: <url>` (the status subcommand
reads it to reach its PR stage).

Before announcing completion, report against mx-doctrine judgment-rubrics §2: restate
each spec acceptance criterion with its evidence, list every path created, and give an
explicit `Not done` section. Fallback if mx-doctrine is absent: tests + plan + PR URL +
what was deferred.

After /mx-pr completes (published or skipped), announce:

```
mx-flow complete.
After merge: /mx-flow finish <name>
```

## Phase 8 — Finish (post-merge cleanup)

Triggered by `/mx-flow finish <name>`, independently from the main pipeline. Summary:
establish merge evidence without asking (PR/MR state, or an empty
`git diff origin/<base>..<branch>`) → delete `plan.md`, preserve the spec and ADR under
`~/.mx/<project>/<name>/`, delete `.mx/<name>/tmp/` → `git worktree remove` (never
`--force` automatically) → `git branch -d`, escalating to `-D` on the expected
squash-merge refusal once that evidence holds → summary. Still ask before `-D` when the
branch carries content the base does not have or has unpushed commits, and never force
past a dirty worktree.

Read ${CLAUDE_SKILL_DIR}/references/finish.md and follow it in full. If the file is missing, say so and follow this summary literally.

## Status — `/mx-flow status [name]`

Report which mx-flow stage each feature in this project is at, its task progress, and the
next command to run; detect broken states and give recovery instructions. No argument →
every feature under `~/.mx/<project>/` and `<repo-root>/.mx/`; `<name>` → that one. The
output is a status block; **this subcommand modifies no file — read-only**. It reports
and stops: it never runs a phase on the user's behalf.

Read ${CLAUDE_SKILL_DIR}/references/status.md and follow it. If the file is missing, say so and stop — do not improvise the phase.
