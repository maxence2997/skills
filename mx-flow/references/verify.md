# Phase 6 — Verify and commit (mx-flow)

> Read on entering Phase 6. Final verification gate. No partial checks
> accepted. The commit-history content check is **not** part of this
> phase — mx-pr owns it and runs it in Phase 7.

## 6.1 — Run full test suite

Run the complete test suite with the runner from Phase 4.4. No partial
runs. **If all pass:** state the count explicitly:
`N tests passing, 0 failures`.

## 6.2 — Check plan completion

Read `LOCAL_MX/plan.md`; every task line must be `[x]`. If all are,
report: `All N tasks complete.`

**If any test fails or a task is still `[ ]`:** report it, then return to
Phase 5a and fix it — this is option [A] of the abort path below and it is
the default; you do not need permission to take it. Re-enter Phase 6 when
green. Present the [A]/[B]/[C] menu and wait only when Non-negotiable 5's
retry budget is exhausted on the same failure, or when the fix would
change the spec.

## 6.3 — Remind ai-learning

Remind the user to add an entry to `~/.mx/<project>/ai-learning.md` before
closing this session. The entry format is in
`${CLAUDE_SKILL_DIR}/references/ai-learning.md` (located in the same
directory as this SKILL.md); if that file is missing, just remind — do not
improvise a format.

## 6.4 — Gate result

Only if 6.1 and 6.2 both pass:

```
Verification passed.
  Tests: N passing, 0 failures
  Plan:  N/N tasks complete

Ready to commit and push.
```

If verification passes, run /mx-commit --auto for any remaining staged
changes.

Phase 6 ends here. Proceed to Phase 7.

## Abort path

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
