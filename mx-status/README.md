# mx-status

Show the current stage, progress, and next action for features in the current project. Scans `~/.mx/<project>/` for specs/ADRs and `.mx/` (project-local) for plans, worktrees, and temp files. Use whenever you lose track of where you are in the mx-flow workflow.

## Usage

```
/mx-status              # show all features in current project
/mx-status <name>       # show one specific feature
```

## Output

```
mx-status — <project>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ● write-timeout-error-propagation  [ACTIVE] Stage 3 — TDD  4/7 tasks
  ✓ close-transport-drop-nil         PR created — /mx-flow finish to clean up
  ○ done-priority-check              Stage 1 — awaiting plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Active: write-timeout-error-propagation
Next  : continue the TDD loop — task 5: wire handler into router
```

## File locations

| File | Location |
|------|----------|
| spec.md, adr.md | `~/.mx/<project>/<name>/` (permanent) |
| plan.md, scope.yaml, worktree/, tmp/ | `.mx/<name>/` in project root (ephemeral) |

## Stages

Evaluated from the strongest evidence down (6 → 0), first match wins. mx-flow has no
phase re-entry point, so Stages 1–3 continue by hand or in the session that started them.

| Stage | Condition | Next action |
|-------|-----------|-------------|
| 0 — Nothing | No `spec.md`, no `plan.md`, no `worktree/` | `/mx-brainstorm <topic>` or `/mx-flow <topic>` |
| 1 — Spec | `spec.md` exists, no `plan.md` | `/mx-flow <topic>` (re-runs brainstorm), or plan manually |
| 2 — Plan | `plan.md` exists, no `scope.yaml` | Resume the mx-flow session, or write `scope.yaml` yourself |
| 2b — Scoped | `scope.yaml` exists, no `worktree/` | Resume the mx-flow session, or create the worktree yourself |
| 3 — TDD | `worktree/` exists, tasks pending | Continue the TDD loop — names the next `[ ]` task |
| 4 — Review | All tasks `[x]`, no review report | `/mx-team-review` |
| 5 — Triage | Review report exists, no PR | `/mx-review-triage --source review` then `/mx-pr` |
| 6 — PR | PR URL found in `plan.md` | `/mx-flow finish <name>` (after merge) |
| Done (archived) | `spec.md` only — plan and worktree gone, branch merged | Nothing — the feature is finished |

## Broken state detection

mx-status checks for four anomalies and gives recovery instructions when found:

| Anomaly | Likely cause | Recovery |
|---------|-------------|----------|
| Worktree dir referenced but missing on disk | Worktree was removed or moved | Recreate with `/mx-flow`, or proceed in main repo |
| All tasks `[x]` but worktree never existed | Work done directly in main repo | Fine if intentional — continue to `/mx-team-review` |
| Multiple features in progress | Parallel work or stale entries | Run `/mx-status <name>` to focus on one |
| `plan.md` has no task list | Plan phase interrupted, or tasks never written | Re-run the plan phase, or add tasks manually |

## Notes

- Resolves project name from `git rev-parse --show-toplevel`
- If run outside a git repo, lists all projects under `~/.mx/` and asks which to inspect
- If the project has no mx-flow features yet, says so in one line and stops — not an error
- Does not modify any files — read-only
