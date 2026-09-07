# Phase 2 — Plan (mx-flow)

> Read on entering Phase 2. Produces `LOCAL_MX/plan.md` from the approved
> spec, then audits it. Return to SKILL.md for GATE 2.

## Planning principles

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

## 2.1 — Read the design spec

Read `GLOBAL_MX/spec.md` in full.
Also read relevant existing code (entry points, interfaces, test files) to
understand the current structure before decomposing.

## 2.2 — Decompose into tasks

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

## 2.3 — Order the tasks

Order tasks so that:
1. Infrastructure / scaffolding comes first
2. Each task builds on previous ones without requiring future tasks
3. Tests for a behavior come in the same task as the implementation (not
   before, not after)

## 2.4 — Write the plan

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

## Plan checks (run before GATE 2)

Audit the plan you just wrote, before any code is written. Run the checks
**inline in the parent, autonomously** — no sub-agent, no user gate. Work
from what Phases 1–2 already put in context; re-read `GLOBAL_MX/spec.md` or
`LOCAL_MX/plan.md` only if they are no longer in context (compacted or
resumed session).

**Grounded in real files and symbols.**
Confirm, don't explore: per task, use targeted Glob/Grep to pin down
the files and symbols it will touch — verify a predicted path exists,
locate the module that owns a function. 2.1 already did the broad
reading; do not start repo-wide exploration here.

Audit the split, and fix `plan.md` directly where it fails — rewriting and
renumbering is safe here, nothing has executed yet:

- **Dependency order**: every task must depend only on earlier tasks. A
  dependency is either a **shared file** (two tasks edit the same file →
  ordering matters) or a **logical precondition** (task B calls a symbol
  introduced by task A). A forward reference → reorder the plan.
- **One behaviour per task**: a task hiding several behaviors (unrelated
  files, or a What that needs "and") → split it into one-behavior tasks per
  the 2.2 rules.
- **No overlapping tasks**: two tasks touching the same file and symbol
  with no stated order between them → order them explicitly, or merge them
  if they are really one behavior.
- **No vague tasks**: a task you cannot pin to files/symbols → rewrite the
  bullet naming the file(s), the function/endpoint, the interface contract.
  A targeted Read/Grep to settle the open question is fine.

**Max 2 refinement passes.** Pass 1 rewrites the vague bullets; pass 2
re-checks only those, leaving the rest untouched. After pass 2 the result
is final: a task still unpinnable keeps the conservative default — treat it
as the largest and riskiest task in the plan, expect ≥ 2 TDD rounds, and
proceed. Bouncing further has diminishing returns; that task requires
hands-on discovery during TDD. Never loop past 2 passes.

**Escape hatch — delegate only on context loss.** If the spec and plan are
NOT in context AND re-acquiring the repo picture would exceed the
inline-reading limits in model-dispatch §2's delegate table (the `Explore`
rows), dispatch ONE `Explore` sub-agent (mid tier) briefed with: the spec
path, the plan path, the repo root, the four checks above, and a directive
— read-only analysis, return per task the files and symbols it touches, the
tasks it depends on, and whether it could be pinned at all, as your final
message. The parent applies the plan fixes itself from what comes back
(`Explore` sub-agents cannot write files). One dispatch maximum; the
refinement passes never re-dispatch.

**If the checks cannot be completed** — unparseable plan, or the
escape-hatch sub-agent timed out, crashed, or returned nothing usable —
say so, apply the conservative default to every task, and proceed in plan
order. Downstream phases treat the plan as unaudited. The flow does not
block.

When signals are ambiguous, bias toward **more** dependencies and **more**
splitting. Over-estimating costs nothing; under-estimating hides a task
that should have been split and burns TDD rounds against the retry budget.

Print one line for visibility (not a gate):

```
Plan checks: <N> tasks — <V> rewritten (vague), <R> reordered, <P> split, <G> merged.
```

If the plan needed no fixes:

```
Plan checks: <N> tasks, split confirmed — no fixes needed.
```

If the fallback fired:

```
Plan checks: failed → conservative defaults applied, plan proceeds unaudited.
```

Then return to SKILL.md: GATE 2, then Phase 4.
