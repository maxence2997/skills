---
name: mx-flow
description: >
  Full development workflow orchestrator: brainstorm → plan → scope analysis →
  worktree → convergent TDD/review loop → verify → PR. One human gate (spec
  approval); all other gates auto-proceed. Use when starting a new feature or
  significant change from scratch. Usage: /mx-flow <topic>;
  /mx-flow finish <name> for post-merge cleanup.
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
| **GATE 2 — Task list** | Auto. Show the task list for visibility, then proceed immediately. |
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

---

## Overview

```
Phase 1  Brainstorm  →  Design spec + ADR        (/mx-brainstorm)
           [GATE 1] Spec approval                 ← human (only hard gate)
Phase 2  Plan        →  Ordered task list         (built-in)
Phase 3  Scope       →  Plan audit: order, split, complexity (built-in)
Phase 4  Worktree    →  Isolated branch + baseline (built-in)

── convergent loop (max 3 iterations) ──────────────
  Phase 5a  TDD (per task) → Commit              (built-in + /mx-commit)
  Phase 5b  Review → Triage                      (/mx-team-review + /mx-review-triage)
  → if fixes: back to TDD
  → if clean: exit loop
────────────────────────────────────────────────────

Phase 6  Verify      →  Tests + plan + content check (built-in)
Phase 7  PR          →  Draft → publish            (/mx-pr)
Phase 8  Finish      →  Clean up branch + worktree (references/finish.md, post-merge)
```

---

## Path resolution

All phases use two base directories. Resolve them once at the start.

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
PROJECT=$(basename "$REPO_ROOT")
```

| Variable | Path | Contains |
|----------|------|----------|
| `GLOBAL_MX` | `~/.mx/<project>/<name>/` | spec.md, adr.md (permanent) |
| `LOCAL_MX` | `<repo-root>/.mx/<name>/` | plan.md, scope.yaml, worktree/, tmp/ (ephemeral) |

- `~/.mx/<project>/ai-learning.md` is also in GLOBAL (project-level, not per-feature)
- Create directories as needed: `mkdir -p` for both GLOBAL_MX and LOCAL_MX
- On Windows: `GLOBAL_MX` = `%USERPROFILE%\.mx\<project>\<name>\`

---

## Phase 0 — Initialize

Before anything else:

1. Derive the feature name from the topic (kebab-case, ≤ 4 words).
   Example: `write-timeout-error-propagation`
2. Resolve GLOBAL_MX and LOCAL_MX per the path resolution section above
3. Create both directories if they do not exist
4. **Check `.gitignore`** — ensure `.mx/` is gitignored:
   ```bash
   if [ ! -f "$REPO_ROOT/.gitignore" ]; then
     echo '.mx/' > "$REPO_ROOT/.gitignore"
   elif ! grep -q '^\.mx/$' "$REPO_ROOT/.gitignore"; then
     echo '.mx/' >> "$REPO_ROOT/.gitignore"
   fi
   ```
   If `.gitignore` was created or modified, commit it:
   ```bash
   git add .gitignore && git commit -m "chore: add .mx/ to .gitignore"
   ```
5. **Read relevant context** — based on the topic, use Glob and Read to
   collect information the brainstorm will need:
   - Files, modules, or packages mentioned explicitly in the topic
   - Related code that is likely in scope (e.g. if topic mentions a
     component, read adjacent files)
   - Any design docs, behaviour specs, or CLAUDE.md files that apply
   - Read broadly enough that the brainstorm's clarifying questions are
     grounded in actual code
6. Announce clearly:

```
mx-flow started
Feature : <feature-name>
Spec    : ~/.mx/<project>/<name>/spec.md (will be written after GATE 1)
Plan    : .mx/<name>/plan.md
Phase   : 1 — Brainstorm
```

Do this before asking any questions or writing any files.

---

## Phase 1 — Brainstorm

Run /mx-brainstorm with the following context:
- The GLOBAL_MX directory has already been created in Phase 0
- The topic is already provided — begin asking clarifying questions
  immediately, do not ask if the user wants to start

Follow mx-brainstorm's full procedure. It owns the spec and ADR output
(written to GLOBAL_MX). If mx-brainstorm is not installed, run GATE 1
yourself: propose 2–3 distinct approaches, get an explicit approval, write
spec.md to GLOBAL_MX — do not skip the gate.

**GATE 1**: Present the draft spec. Do not proceed until the user
explicitly confirms.

With the spec approval, state (do not ask) the Phase 5a execution mode —
the default is `inline`, the parent running the TDD cycle itself (both
modes are defined in Phase 5a). Choose `delegated` instead when there is a
tier gap: your main-loop model sits above the strongest tier in your Agent
tool's `model` enum (map by tier, not by name — mx-doctrine
model-dispatch §1). No Agent tool → inline, no choice to state. Say it in
one line and continue; the user can say "delegated" at any point and
switch between tasks (their instruction always wins). Record the mode for
Phase 5a.

---

## Phase 2 — Plan

Decompose the approved spec into a concrete, ordered task list.

### Planning principles

These bind every task you write in this phase. The TDD loop in Phase 5
executes the plan literally — if the plan over-reaches, the implementation
will too. Lock scope here, not later.

**Simplicity first — minimum code that satisfies the spec.**

- No tasks beyond what the spec requires.
- No abstractions, interfaces, or "flexibility" layers the spec did not
  ask for.
- No error handling for impossible scenarios.
- No speculative configuration, feature flags, or extension points "for
  the future".
- If a single function would do, do not invent a class. If a class would
  do, do not invent a package.

**Surgical changes — touch only what the spec requires.**

- Do not plan to "improve" adjacent code, comments, or formatting that the
  spec did not call out.
- Do not plan refactors of code that is not broken.
- Match existing style and structure even if a different style would be
  your preference.
- If you notice unrelated dead code or technical debt, mention it once to
  the user — do not silently add a cleanup task.
- Orphans your tasks create (now-unused imports, variables, helpers)
  **must** be cleaned in the same task. Pre-existing dead code is out of
  scope unless the user approves.

The test for every task: it traces directly to a sentence in the spec. If
it does not, drop it and note the drop in the plan summary. Ask only if
dropping it would leave a spec sentence unimplemented.

### 2.1 — Read the design spec

Read `GLOBAL_MX/spec.md` in full.
Also read relevant existing code (entry points, interfaces, test files) to
understand the current structure before decomposing.

### 2.2 — Decompose into tasks

Break the spec into the smallest tasks where each task:

- Implements **one behavior** (not a file, not a layer)
- Maps to **one commit type** (`feat`, `fix`, `refactor`, `test`, `chore`, `doc`)
- Has a **concrete expected test**: what to write, what it verifies,
  expected output
- Can be committed independently without breaking the build

**Forbidden content in any task:**
- `TBD` or `TODO`
- "similar to Task N"
- "add error handling" (without specifying what error and how)
- "update tests" (without specifying which behavior)
- Pseudo-code or vague descriptions

Task format:

```markdown
### Task N — <type>: <subject (≤ 50 chars)>

**What**: <one sentence describing the behavior added or changed>
**Test**: <what test to write — file, scenario, expected result>
**Files**: <which files will change>
```

### 2.3 — Order the tasks

Order tasks so that:
1. Infrastructure / scaffolding comes first
2. Each task builds on previous ones without requiring future tasks
3. Tests for a behavior come in the same task as the implementation (not
   before, not after)

### 2.4 — Write the plan

Write `LOCAL_MX/plan.md`:

```markdown
# <name> — Plan

> Design spec: ~/.mx/<project>/<name>/spec.md

## Tasks

- [ ] Task 1 — feat: <subject>
- [ ] Task 2 — test: <subject>
- [ ] Task 3 — fix: <subject>
```

Show the full task breakdown (with Task N details) to the user for review.

**GATE 2**: Show the task list for visibility, then proceed immediately.
Announce: `Task list auto-approved.`

Allow the user to add, remove, reorder, or rewrite tasks if they intervene
before auto-proceed.

---

## Phase 3 — Scope analysis

Audit the plan before any code is written: read the spec, the plan, and
the repo, then verify every task is grounded in real files and symbols,
correctly ordered, and cut at the right granularity — fixing `plan.md`
where it is not. The audit's machine-readable record is
`.mx/<name>/scope.yaml`. This phase runs
**inline in the parent, autonomously** — no sub-agent by default, no user
gate; print a one-line summary at the end for visibility.

Why inline (2026-07-15): by the end of Phase 2 the spec, the plan, and
the relevant code are already in the parent's context — a sub-agent has
to rebuild all of it from disk, and the dispatch round-trips were
observed to cost more wall-clock than the analysis itself. Canonical
rule: mx-doctrine model-dispatch §2 (do inline).

Never skip this phase — it is the last cheap place to catch a bad task
split. A vague or oversized task found here costs one plan edit; found
in Phase 5 it costs TDD rounds against the retry budget. Phase 5 also
reads `scope.yaml` per task as advisory context (where to look first,
how much effort to expect).

### 3.1 — Audit (inline)

Work from what Phases 1–2 already put in context. Re-read
`GLOBAL_MX/spec.md` or `LOCAL_MX/plan.md` only if they are no longer in
context (compacted or resumed session).

1. Confirm, don't explore: per task, use targeted Glob/Grep to pin down
   the files and symbols it will touch — verify a predicted path exists,
   locate the module that owns a function. Phase 2.1 already did the
   broad reading; do not start repo-wide exploration here.
2. For each task in plan.md, infer the schema fields below (3.2), scoring
   complexity against the rubric (3.3)
3. Audit the split, and fix `plan.md` directly where it fails — rewriting
   and renumbering is safe here, nothing has executed yet:
   - **Ordering**: every `depends_on` must point to an earlier task. A
     forward dependency → reorder the plan.
   - **Too big**: one task hiding several behaviors (an L whose
     `predicted_touches` don't relate, or a What that needs "and") →
     split it into one-behavior tasks per the Phase 2.2 rules.
   - **Overlap**: two tasks predicting the same file+symbol with no
     `depends_on` between them → add the missing dependency, or merge
     them if they are really one behavior.
   - **Vague**: cannot pin the task to files/symbols → mark `vague: true`;
     the refinement pass (3.4) handles it.
4. Write `.mx/<name>/scope.yaml` directly, keeping the counts (vague,
   reordered, split, merged) for the 3.6 summary.

**Escape hatch — delegate only on context loss.** If the spec and plan
are NOT in context AND re-acquiring the repo picture would exceed the
inline-reading limits in model-dispatch §2's delegate table (the
`Explore` rows), dispatch ONE `Explore`
sub-agent (mid tier) briefed with: the spec path, the plan path, the repo
root, the schema (3.2), the rubric (3.3), and a directive — read-only
analysis, return the complete scope YAML as your final message. The
parent writes `.mx/<name>/scope.yaml` from that returned YAML (Explore
sub-agents cannot write files) and applies step 3's plan fixes itself
from the returned metadata. One dispatch maximum; the refinement pass
(3.4) never re-dispatches.

### 3.2 — Schema

```yaml
- id: task-1                                   # matches plan.md ordering: task-1, task-2, ...
  task: "<verbatim copy of plan.md bullet>"
  predicted_files:                             # repo-relative paths
    - internal/cache/adapter.go
    - internal/cache/adapter_test.go
  predicted_touches:                           # symbols, functions, endpoints
    - RedisClient.Get
    - RedisClient.Set
  depends_on: []                               # ids of tasks that must finish first; [] if independent
  complexity: M                                # S | M | L
  complexity_reason: "two new files, ~80 LOC, follows existing adapter pattern"
  vague: false                                 # true only when the fields above could not be reliably inferred
  vague_reason: ""                             # populated only when vague: true
```

`depends_on` should reflect either **shared files** (two tasks edit the
same file → ordering matters) or **logical preconditions** (task B calls a
symbol introduced by task A). When unsure, add the dependency rather than
omit it.

### 3.3 — Complexity rubric

| Level | Criteria |
|-------|----------|
| **S** | ≤ ~30 LOC, single file, predicted 1 TDD round, no external integration |
| **M** | ~30–150 LOC, 2–3 files, predicted 1–2 TDD rounds, may touch one integration boundary |
| **L** | > 150 LOC, multi-module, ≥ 2 TDD rounds expected, or non-trivial external integration (DB / network / filesystem / external API) |

When signals are ambiguous, bias toward **higher** complexity and **more**
dependencies. Over-estimating costs nothing; under-estimating hides a
task that should have been split and burns TDD rounds against the retry
budget.

### 3.4 — Refinement pass (max 2 passes)

After the first pass, inspect `scope.yaml` for `vague: true` entries.

**Pass 1 → Pass 2.** If any task is vague, rewrite those specific bullets
in `plan.md` using `vague_reason` as guidance — name the file(s), the
function/endpoint, the interface contract; a targeted Read/Grep to settle
the open question is fine. Then re-infer those tasks only. Tasks that
were not vague stay untouched.

**After Pass 2.** The result is final. Any task still marked `vague: true`
keeps its conservative default (`complexity: L`) and proceeds. Bouncing
further has diminishing returns — the task is one that requires hands-on
discovery during TDD.

Cap is **2 passes**. Never loop indefinitely, and never re-dispatch the
escape-hatch sub-agent for refinement — resolve vagueness inline or apply
the defaults.

### 3.5 — Fallback on failure

If the analysis cannot produce valid YAML for every task (unparseable
plan, or the escape-hatch sub-agent timed out, crashed, or returned
invalid YAML), write a minimal `scope.yaml` directly:

```yaml
- id: task-N
  task: "<copy from plan.md>"
  predicted_files: []
  predicted_touches: []
  depends_on: []
  complexity: L
  complexity_reason: "scope analysis failed; conservative default applied"
  vague: true
  vague_reason: "scope analysis failed; safe fallback applied"
```

Every task gets the same shape. Downstream phases treat the plan as
unaudited and proceed in plan order. The flow does not block.

### 3.6 — Summary

Print one line to the user for visibility (not a gate):

```
Scope audit: <N> tasks — <V> rewritten (vague), <R> reordered, <P> split, <G> merged; complexity <a>S/<b>M/<c>L.
```

If the plan needed no fixes:

```
Scope audit: <N> tasks, split confirmed — no fixes needed; complexity <a>S/<b>M/<c>L.
```

If the fallback fired:

```
Scope audit: failed → conservative defaults recorded, plan proceeds unaudited.
```

Then auto-proceed to Phase 4.

---

## Phase 4 — Worktree

Create an isolated git worktree for the feature branch.

### 4.1 — Determine branch name

Apply branch naming convention:

| Change type | Prefix |
|---|---|
| New feature | `feat/<name>` |
| Bug fix | `bugfix/<name>` |
| Quick fix (config, docs, CI) | `fix/<name>` |
| Maintenance, deps, tooling | `chore/<name>` |

If the name has no prefix, derive it from the dominant commit type in
plan.md (feat → `feat/`, fix → `bugfix/`, chore → `chore/`) and state the
choice. Ask only if the plan mixes types with no clear majority.
If the name already has a correct prefix, proceed.

### 4.2 — Create the worktree

First, resolve the base branch (`develop` preferred, then `main`) and assign
the ref you actually verified — a base that exists only on the remote is
`origin/<name>`; the bare local name would be an invalid object and every
later `<base>..HEAD` range would degrade to empty in silence:

```bash
BASE_BRANCH=""
for cand in develop main; do
  if git rev-parse --verify --quiet "refs/heads/$cand" >/dev/null; then
    BASE_BRANCH="$cand"; break
  elif git rev-parse --verify --quiet "refs/remotes/origin/$cand" >/dev/null; then
    BASE_BRANCH="origin/$cand"; break
  fi
done
```

If `BASE_BRANCH` is empty, neither branch exists — ask the user which branch
to base from. This value is the canonical base for Phases 5b, 6.5 and 7
(strip the `origin/` prefix only where a platform CLI needs a branch *name*).

Then create the worktree under LOCAL_MX:

```bash
git worktree add .mx/<name>/worktree -b <branch-name> <base-branch>
```

Verify it was created:

```bash
git worktree list
```

### 4.3 — Run project setup

From inside the worktree (`.mx/<name>/worktree`), install dependencies
using whatever the repo's lockfile / manifest indicates (go.mod,
package.json + its lockfile, requirements.txt / pyproject.toml,
Cargo.toml, …). If nothing is detected, skip — Phase 4.4's baseline run
will surface a broken environment.

### 4.4 — Verify baseline

Run the full test suite to confirm the worktree starts clean.

Auto-detect the runner in this priority order (this is the canonical
runner-detection rule — Phases 5 and 6 reuse it):

1. `Makefile` with a `check` or `test` target → `make check` or `make test`
2. `package.json` with a `test` script → `npm test` / `yarn test` / `pnpm test`
3. Language detection: `.go` → `go test ./...`, `.rs` → `cargo test`,
   `.py` → `pytest`, `.cs` → `dotnet test`, `.swift` → `swift test`
4. None of the above matched → say so once, ask the user for the test
   command, and record it as the runner for this session. If the project
   genuinely has no test suite, say so, and Non-negotiable 2's RED step is
   satisfied by a reviewable manual check documented in the commit — never
   by skipping it.

**If baseline fails:**
Report the failures and ask the user whether to proceed or investigate
first. Do not proceed silently with a failing baseline.

### 4.5 — Report

```
Worktree ready at .mx/<name>/worktree/
Branch  : <branch-name>
Baseline: <N> tests passing
```

---

## Phase 5 — Convergent loop

### 5a — TDD cycle (per task, strictly serial)

Execute the plan one task at a time, in plan order, in the execution
mode chosen at GATE 1 (no recorded choice → inline):

- **Inline** — the parent does the TDD cycle itself.
- **Delegated** — dispatch each task to ONE `general-purpose` executor:
  mid tier for S complexity, strongest for M/L or unknown (from
  `scope.yaml`). Use the TDD TASK template (mx-doctrine
  delegation-templates §6). The executor writes tests and code only;
  the parent keeps verification, plan bookkeeping, and commits.

Either mode is **strictly serial — one task in flight, ever**. Parallel
dispatch stays removed (mx-doctrine model-dispatch §2). The user may
switch modes between tasks; their instruction always wins.

All rules in this phase bind whoever types — parent or executor.

#### Delegated mode — per-task protocol (parent side)

1. Pick the executor tier from the task's scope.yaml entry.
2. Dispatch one executor with the TDD TASK template: absolute worktree
   path, the task's What/Test/Files verbatim, scope hints, and the
   runner command from Phase 4.4.
3. Verify mechanically yourself: run the full suite and read `git diff`
   for blast radius and comment policy. The executor's pasted output is
   a claim, not evidence (model-dispatch §5).
4. Verified green → mark the task `[x]` in plan.md, run
   /mx-commit --auto, walk the exit-condition checklist below.
   Failed → a burned round at the executor's tier. Apply the
   model-dispatch §6 ladder with the parent as the tier above
   strongest: mid fails twice → strongest executor with the full
   failure trail; strongest executor fails twice → the parent takes
   the task inline (this satisfies Non-negotiable 5's escalation).
   The §6 absolute cap always wins over further escalation: 4 failed
   rounds on one task across all tiers → stop and ask the user.

Phase 3's audit validated the ordering, so plan order satisfies every
`depends_on`. Before starting a task, read its `scope.yaml` entry as
advisory context: `predicted_files`/`predicted_touches` say where to
look first, `complexity` sets the effort expectation. If `scope.yaml`
is missing, proceed in plan order without the hints.

#### Philosophy: Vertical Slices Only

```
WRONG (horizontal slicing):
  RED:   test1, test2, test3
  GREEN: impl1, impl2, impl3   ← never do this

RIGHT (vertical slices):
  RED → GREEN: test1 → impl1
  RED → GREEN: test2 → impl2
  RED → GREEN: test3 → impl3
```

Writing tests in bulk produces tests that verify imagined behavior, not
actual behavior. Each test must respond to what you learned from the
previous cycle.

#### For each `[ ]` task in the plan:

**Read the task** — Read `LOCAL_MX/plan.md` and identify the next `[ ]`
task. Read its full specification (What, Test, Files). Read the relevant
existing code before writing anything.

**Tracer bullet (first task only)** — For the first task of a new feature,
write one minimal test that proves the end-to-end path works — even if it
only touches a stub. This confirms the test infrastructure is wired
correctly before building out.

**Red: write the failing test** — Write the test as specified in the task.

Test quality rules:
- Tests verify **behavior through public interfaces**, not implementation
  details
- A good test reads like a specification: "user can do X given Y"
- Tests must not depend on **wall-clock / real time** — inject the clock,
  synchronize on signals, never `sleep`. Canonical:
  `${CLAUDE_SKILL_DIR}/../mx-team-review/references/principles.md` →
  *P1 — Component Test* → *Deterministic Time*
- The test must **fail** before any production code is written
- Run the test and **observe the failure** — if it passes immediately, the
  test is wrong

Run it with the runner from Phase 4.4. Confirm the test fails with the
expected error (missing symbol, assertion failure, etc.). A test that
passes without implementation proves nothing.

**Green: minimal implementation** — Write the **simplest code** that makes
the test pass.

Rules:
- Only enough code to pass the current test
- Do not anticipate future tests
- Do not add features not required by the current test
- Speculative code is forbidden

**Comment policy (enforced while writing, not only at review)** —
Canonical source:
`${CLAUDE_SKILL_DIR}/../mx-team-review/references/principles.md` →
*P2 — Comment (Why)*. Essentials:

- **Default: no comment.** Add one only when WHY is non-obvious to a
  future reader.
- **Forbidden:** comments that restate WHAT the code does, empty doc
  summaries (`/// Creates an order.`), vague pronouns (`this`,
  `the above`, `as mentioned`).
- **Required for:** magic numbers, framework-default overrides,
  business-rule enforcement, external workarounds (link the issue),
  TODO/FIXME (link or explain why and when).
- **Style:** lead with WHY, name the concrete subject + triggering
  scenario, hard limit **3 lines**. If it needs more, the code probably
  needs to change instead.

If you find yourself writing a "WHAT" comment, delete it and improve the
identifier name instead.

Run the test again — confirm it passes.
Run the full suite — confirm nothing else broke.

**If GREEN won't come** — the same task failing twice triggers
Non-negotiable 5 (retry budget). Weakening the test to pass is
Non-negotiable 3. There is no third identical attempt.

**Refactor** — Only after GREEN, look for improvements:

- Extract duplication
- Improve naming
- Simplify logic
- Apply existing patterns from the codebase

Rules:
- **Never refactor while RED**
- Run tests after each refactor step — if anything breaks, revert
  immediately
- Refactor is optional; skip if the code is already clean

**Exit condition checklist** — Before marking the task done, verify all
six conditions:

```
□ RED observed: test failure was seen with actual output (not assumed)
□ GREEN confirmed: test passes after implementation
□ Full suite clean: no new failures introduced by this change
□ Comment policy: no WHAT-comments, no vague pronouns, magic numbers/workarounds explain WHY, every comment ≤3 lines
□ Plan updated: task marked [x] in .mx/<name>/plan.md
□ Committed: /mx-commit --auto completed for this task
```

If any item is unchecked, do not advance to the next task.

After each task completes, take the next `[ ]` task in plan order. Exit
to 5b when all tasks are done or a milestone is reached.

### 5b — Review (at milestone)

Run /mx-team-review on the diff since the branch was created, using the
base branch resolved in Phase 4.2:
```bash
git diff $(git merge-base HEAD <base-branch>)..HEAD
```

Run /mx-review-triage with `--source review` directly (no auto-detect).

If either review skill is missing, say so once and satisfy Non-negotiable
4 with a single self-review of the branch diff labelled `single-context,
no team review` (per mx-doctrine model-dispatch §5); do not silently skip
Phase 5b, and do not treat the missing skill as permission to skip
Phase 6.

**GATE 3**: Show the triage summary, auto-approve all "fix" items, execute
immediately (commits go through `/mx-commit --auto`). "Track" items are
still written to TODOS.md and "Skip" items noted in the report — both
without pausing. Announce: `Triage auto-approved — executing <N> fixes.`

After fixes are applied:
- If fixes were made → run the test suite → back to 5a for any new tasks,
  increment iteration counter
- If clean (no fixes needed) → exit the loop

### Loop safety limit

The convergent loop has a maximum of **3 iterations** (one iteration = one
full tdd → review → triage cycle).

If the loop reaches 3 iterations without converging to clean:

```
[ESCALATE] Convergent loop has not resolved after 3 iterations.

Current state:
  Iteration: 3/3
  Remaining findings: <list>

Options:
  [A] Continue — extend the loop (you take responsibility)
  [B] Redesign — the findings suggest a design issue; revisit ~/.mx/<project>/<name>/spec.md (design spec)
  [C] Abort — discard this branch and start fresh

Three iterations without convergence usually indicates a design problem,
not a code problem.
```

Do not continue automatically. Wait for the user to choose.

---

## Phase 6 — Verify and commit

Final verification gate. No partial checks accepted.

### 6.1 — Run full test suite

Run the complete test suite with the runner from Phase 4.4. No partial
runs. **If all pass:** state the count explicitly:
`N tests passing, 0 failures`.

### 6.2 — Check plan completion

Read `LOCAL_MX/plan.md`; every task line must be `[x]`. If all are,
report: `All N tasks complete.`

**If any test fails or a task is still `[ ]`:** report it, then return to
Phase 5a and fix it — this is option [A] of the abort path below and it is
the default; you do not need permission to take it. Re-enter Phase 6 when
green. Present the [A]/[B]/[C] menu and wait only when Non-negotiable 5's
retry budget is exhausted on the same failure, or when the fix would
change the spec.

### 6.3 — Remind ai-learning

Remind the user to add an entry to `~/.mx/<project>/ai-learning.md` before
closing this session. The entry format is in
`${CLAUDE_SKILL_DIR}/references/ai-learning.md` (located in the same
directory as this SKILL.md); if that file is missing, just remind — do not
improvise a format.

### 6.4 — Gate result

Only if 6.1 and 6.2 both pass:

```
Verification passed.
  Tests: N passing, 0 failures
  Plan:  N/N tasks complete

Ready to commit and push.
```

If verification passes, run /mx-commit --auto for any remaining staged
changes.

### 6.5 — Content check (autonomous cleanup)

Clean the branch history before the PR phase: two autonomous passes —
**Pass 1** removes net-zero churn (commits/hunks that cancel each other on
the branch), **Pass 2** folds small fixups into their logical parent. Each
pass is guarded by a tree-hash invariant and reverts itself on any
mismatch. No user prompt.

**Execute the canonical procedure**: read and follow
`${CLAUDE_SKILL_DIR}/../mx-pr/references/content-check.md`, with
`<base-branch>` = the base branch resolved in Phase 4.2 (if that value is
no longer in context, re-derive it with the same develop-then-main rule).
If the content-check file is missing, announce `Content-check reference
missing — skipping here; Phase 7 will run mx-pr's own copy if mx-pr is
installed` and proceed to Phase 7 **without** rewriting any history.

Phase 6 ends here. Proceed to Phase 7.

### Abort path

When 6.2 sends you here — the retry budget is exhausted on the same
failure, or the fix would change the spec — present three recovery
options:

```
[VERIFICATION FAILED]
  <specific failure: test output / open tasks>

Recovery options:
  [A] Investigate — return to Phase 5a to fix the failing test or task
        Re-entry: specify which task or failing test to address first
  [B] Adjust plan — the failure reveals that a task definition was wrong
        Re-entry: edit .mx/<name>/plan.md, then re-run Phase 5a for that task
  [C] Abort branch — this branch is not recoverable
        Will preserve: ~/.mx/<project>/<name>/spec.md and adr.md (design spec)
        Will discard:  .mx/<name>/plan.md
        Reminder:      git worktree remove .mx/<name>/worktree
```

Wait for the user to choose. Outside the two cases 6.2 names, do not
present this menu at all — take [A] directly.

---

## Phase 7 — PR

Run /mx-pr (if the mx-pr skill is not installed, tell the user the flow
ends here and hand them the branch name and base branch — do not improvise
a PR). It will:
- Run the content check again (no-op if Phase 6.5 already cleaned)
- Draft the PR description from the spec and git log
- Publish or hand off

**GATE 4** applies: auto-proceed — draft the PR and publish directly. Show
the draft for visibility but do not wait for confirmation (mx-pr's
"Orchestrated mode" section defers to this gate). Only pause and ask the
user if:
- No git remote is configured
- Multiple remotes exist and the target is ambiguous
- Platform credentials are missing or authentication fails
- Any other situation where the agent cannot determine the correct action

Announce: `PR auto-published.`

mx-pr prints `PR created: <url>` — append that URL to `LOCAL_MX/plan.md`
as a line `PR: <url>` (mx-status reads it to reach its PR stage).

Before announcing completion, report against mx-doctrine judgment-rubrics
§2: restate each spec acceptance criterion with its evidence, list every
path created, and give an explicit `Not done` section. Fallback if
mx-doctrine is absent: tests + plan + PR URL + what was deferred.

After /mx-pr completes (published or skipped), announce:

```
mx-flow complete.
After merge: /mx-flow finish <name>
```

---

## Phase 8 — Finish (post-merge cleanup)

Triggered by `/mx-flow finish <name>`, independently from the main
pipeline. Read `${CLAUDE_SKILL_DIR}/references/finish.md` and follow it in
full.

Summary of what it does: establish merge evidence without asking (PR/MR
state, or an empty `git diff origin/<base>..<branch>`) → delete `plan.md`
and `scope.yaml` → preserve the spec and ADR under
`~/.mx/<project>/<name>/` → delete `.mx/<name>/tmp/` → `git worktree
remove` (never `--force` automatically) → `git branch -d`, escalating to
`-D` on the expected squash-merge refusal once that evidence holds →
summary. If the reference file is missing, follow this summary literally;
still ask before `-D` when the branch carries content the base does not
have or has unpushed commits, and never force past a dirty worktree.
