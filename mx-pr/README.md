# mx-pr

Draft a pull/merge request from the feature spec and git log, review it, then publish — or skip.

## Usage

```
/mx-pr <name>   # draft PR for named feature
/mx-pr          # infer from active spec or ask
```

## What it does

1. Reads `~/.mx/<project>/<name>/spec.md` and the git log since branch creation
2. **Autonomous content check** (two passes, each guarded by a tree-invariant check — `HEAD^{tree}` must be identical before and after, otherwise that pass reverts itself):
   - *Net-zero churn*: commits and hunks that cancel each other on the branch (`++A` in one commit, `--A` in a later one) come out, so they leave no trace in the PR
   - *Fixups*: small touch-ups — `fixup!`/`wip`/`typo`/review-feedback subjects, or a small diff sitting inside exactly one earlier commit — fold into their logical parent
   - No user prompt, and anything uncertain is skipped (history fidelity wins). A single-commit branch short-circuits: neither pass can apply. This is the only place the check runs — /mx-flow hands off to /mx-pr for it
3. Drafts a structured PR description from the (cleaned-up) history — the body only names files that exist in the committed branch; local sources (spec.md, plan.md, anything under `~/.mx/` or `.mx/`) feed the content but are never cited
4. Adds a CHANGELOG entry (and commits it) when the repo has a `CHANGELOG.md` — otherwise that checklist item is dropped from the body
5. Saves draft to `.mx/<name>/tmp/pr-draft-<timestamp>.md` (timestamp prevents collisions)
6. Shows you the draft — you decide to proceed or edit first
7. Asks which platform to publish to
8. Pushes the branch (`--force-with-lease` if history was rewritten) and publishes against the resolved base branch — if that platform's CLI is missing it falls back to hand-off instead of switching platforms
9. Reports the URL, the base branch, and the commit count; it does not wait on CI
10. Leaves draft in `.mx/<name>/tmp/` — cleaned up by `/mx-flow finish`

## Platforms supported

| Platform | CLI used |
|----------|----------|
| GitHub | `gh pr create` |
| GitLab | `glab mr create` |
| Bitbucket | `bb pr create` — experimental: requires the `bb` CLI, and the target branch has to be confirmed in the web UI |
| Other / Manual | Shows draft, you handle it |
| Skip | Don't publish now |

## PR draft format

Defined in `references/pr-template.md` — edit it to match your team's conventions.

Default sections and their sources:

| Section | Source |
|---------|--------|
| Summary | Design spec — What and How |
| Related issues | Issue numbers found in the branch name, commit messages, or open issue list (omitted if none) |
| Motivation | Design spec — Why |
| Changes | Git log since branch start, grouped by commit type |
| Test plan | Completed tasks from plan.md |
| Notes | Design spec — Out of scope / trade-offs (omitted if empty) |
| Checklist | Fixed required items, plus conditional items the skill selects from the commit types in the git log |

## Notes

- Run after verification passes — the branch does not need to be pushed yet (Step 6 pushes it)
- The content check's full procedure lives in `references/content-check.md` — the single canonical copy, and mx-pr is the only skill that runs it
- Customize `references/pr-template.md` to add checklists, issue references, screenshots, etc.
- CHANGELOG entry format lives in `references/changelog-convention.md` — backs the "CHANGELOG updated" checklist item
- Draft is never deleted on failure — you can recover and retry
- After merge: run `/mx-flow finish <name>` to clean up
