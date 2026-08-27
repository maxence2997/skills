# mx-pr

Draft a pull/merge request from the feature spec and git log, review it, then publish — or skip.

## Usage

```
/mx-pr <name>   # draft PR for named feature
/mx-pr          # infer from active spec or ask
```

## What it does

1. Reads `~/.mx/<project>/<name>/spec.md` and the git log since branch creation
2. **Autonomous content check** (two passes, each guarded by a tree-invariant check — `HEAD^{tree}` must be identical before and after, otherwise the pass is reverted):
   - *Pass 1 — Cancellation cleanup*: removes net-zero churn on the branch. Whole-commit inverse pairs (`++A` then `--A` later) are dropped mechanically. Partial cancellation (`++A,++B` then `--B,++C` → effectively `++A,++C`) goes through a semantic relatedness gate before any hunks are trimmed
   - *Pass 2 — Squash-into-parent*: folds fixup/wip/typo/review-feedback noise *and* small diff-overlap touch-ups into their parent commit via autosquash
   - Final safety net — runs unconditionally even when /mx-flow's Phase 6 already ran the same check; after a prior Phase 6 it is typically a no-op
3. Drafts a structured PR description from the (cleaned-up) history — the body only names files that exist in the committed branch; local sources (spec.md, plan.md, anything under `~/.mx/` or `.mx/`) feed the content but are never cited
4. Saves draft to `.mx/<name>/tmp/pr-draft-<timestamp>.md` (timestamp prevents collisions)
5. Shows you the draft — you decide to proceed or edit first
6. Asks which platform to publish to
7. Pushes the branch (`--force-with-lease` if history was rewritten) and publishes
8. Leaves draft in `.mx/<name>/tmp/` — cleaned up by `/mx-flow finish`

## Platforms supported

| Platform | CLI used |
|----------|----------|
| GitHub | `gh pr create` |
| GitLab | `glab mr create` |
| Bitbucket | `bb pr create` |
| Other / Manual | Shows draft, you handle it |
| Skip | Don't publish now |

## PR draft format

Defined in `references/pr-template.md` — edit it to match your team's conventions.

Default sections and their sources:

| Section | Source |
|---------|--------|
| Summary | Design spec — What and How |
| Motivation | Design spec — Why |
| Changes | Git log since branch start, grouped by commit type |
| Test plan | Completed tasks from plan.md |
| Notes | Design spec — Out of scope / trade-offs (omitted if empty) |

## Notes

- Run after verification passes — the branch does not need to be pushed yet (Step 6 pushes it)
- The content check's full procedure lives in `references/content-check.md` — it is the single canonical copy, also invoked by mx-flow Phase 6.5
- Customize `references/pr-template.md` to add checklists, issue references, screenshots, etc.
- CHANGELOG entry format lives in `references/changelog-convention.md` — backs the "CHANGELOG updated" checklist item
- Draft is never deleted on failure — you can recover and retry
- After merge: run `/mx-flow finish <name>` to clean up
