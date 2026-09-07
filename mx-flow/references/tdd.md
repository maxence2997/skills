# Phase 5 — Convergent loop (mx-flow)

> Read on entering Phase 5a or 5b. SKILL.md holds the guards this file
> assumes: the Non-negotiables, the seven-box exit-condition checklist, and
> the 3-iteration loop limit. Do not restate them here — walk the checklist
> in SKILL.md before marking any task done.

## 5a — TDD cycle (per task, strictly serial)

Execute the plan one task at a time, in plan order, in the execution mode
chosen at GATE 1 (no recorded choice → inline):

- **Inline** — the parent does the TDD cycle itself.
- **Delegated** — dispatch each task to ONE `general-purpose` executor:
  mid tier by default, strongest when the task touches concurrency,
  auth/security, data migration or a public API. Use the TDD TASK template
  (mx-doctrine delegation-templates §6). The executor writes tests and code
  only; the parent keeps verification, plan bookkeeping, and commits.

Either mode is **strictly serial — one task in flight, ever**. Parallel
dispatch stays removed (mx-doctrine model-dispatch §2). The escape hatch is
the user's: they may switch modes between tasks at any time and their
instruction always wins — take the switch on the next task, never mid-task.

All rules in this phase bind whoever types — parent or executor.

### Delegated mode — per-task protocol (parent side)

1. Pick the executor tier from the task itself: mid unless it touches
   concurrency, auth/security, data migration or a public API.
2. Dispatch one executor with the TDD TASK template: absolute worktree
   path, the task's What/Test/Files verbatim, and the runner command from
   Phase 4.4.
3. Verify mechanically yourself: run the full suite and read `git diff`
   for blast radius and comment policy. The executor's pasted output is
   a claim, not evidence (model-dispatch §5).
4. Verified green → mark the task `[x]` in plan.md, run
   /mx-commit --auto, walk SKILL.md's exit-condition checklist.
   Failed → a burned round at the executor's tier. Apply the
   model-dispatch §6 ladder with the parent as the tier above
   strongest: mid fails twice → strongest executor with the full
   failure trail; strongest executor fails twice → the parent takes
   the task inline (this satisfies Non-negotiable 5's escalation).
   The §6 absolute cap always wins over further escalation: 4 failed
   rounds on one task across all tiers → stop and ask the user.

Phase 2's plan checks validated the ordering, so plan order already
satisfies every dependency — take the tasks as written, in order.

### Philosophy: Vertical Slices Only

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

### For each `[ ]` task in the plan:

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
  synchronize on signals, never `sleep` and never a per-test timer such as
  `time.After`; the command-line timeout (`go test -timeout`) is the only
  backstop. Canonical:
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

**Update the plan and commit** — mark the task `[x]` in
`LOCAL_MX/plan.md`, then run /mx-commit --auto for that task alone. Then
walk SKILL.md's seven-box exit-condition checklist; if any item is
unchecked, do not advance to the next task.

## 5b — Review (at milestone)

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

GATE 3 (see SKILL.md) auto-approves the "fix" items. After fixes are
applied:
- If fixes were made → run the test suite → back to 5a for any new tasks,
  increment iteration counter
- If clean (no fixes needed) → exit the loop

### Loop safety limit — escalation block

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
