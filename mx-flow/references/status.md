# `/mx-flow status [name]` (mx-flow)

> Read on entering the status subcommand. It reports where every feature in
> this project stands and what to run next. It does not modify any file and
> never enters the pipeline.

## Path resolution

The status subcommand works one level above the phases, because it lists
every feature: SKILL.md's `GLOBAL_MX` and `LOCAL_MX` are the `<name>/`
subdirectories of the two directories below. Resolve `REPO_ROOT` and
`PROJECT` exactly as SKILL.md's path resolution section does.

| Variable | Path | Contains |
|----------|------|----------|
| `MX_PROJECT_DIR` | `~/.mx/<project>/` | `<name>/spec.md`, `<name>/adr.md`, `ai-learning.md` |
| `MX_LOCAL_DIR` | `<repo-root>/.mx/` | `<name>/plan.md`, `<name>/worktree/`, `<name>/tmp/` |

On Windows: `MX_PROJECT_DIR` = `%USERPROFILE%\.mx\<project>\`

If the current directory is not inside a git repo, show all projects under `~/.mx/` and ask the user which one to inspect.

## Step 1 — Collect features

A feature is any `<name>` that appears as a subdirectory in **either** MX_PROJECT_DIR or MX_LOCAL_DIR.

1. List all subdirectories under `~/.mx/<project>/` (excluding `ai-learning.md`)
2. List all subdirectories under `.mx/`
3. Union the two lists — a feature may appear in one or both locations

If neither directory exists, or the union is empty, print
`No mx-flow features in <project>.` plus the Stage-0 next action (Step 4) and stop —
this is a normal state, not an error.

For each feature, collect:

| File / path | Location | Meaning |
|---|---|---|
| `spec.md` | `~/.mx/<project>/<name>/spec.md` (GLOBAL) | Brainstorm complete |
| `adr.md` | `~/.mx/<project>/<name>/adr.md` (GLOBAL) | Architecture decision recorded |
| `plan.md` | `.mx/<name>/plan.md` (LOCAL) | Plan written |
| `worktree/` directory | `.mx/<name>/worktree/` (LOCAL) | Worktree created |
| Task lines `[x]` / `[ ]` in `plan.md` | `.mx/<name>/plan.md` (LOCAL) | TDD progress |
| `tmp/review-*.md` | `.mx/<name>/tmp/review-*.md` (LOCAL) | Review report exists |
| PR URL in `plan.md` | `.mx/<name>/plan.md` (LOCAL) | PR created |

If `<name>` is given, collect only that feature.

## Step 2 — Classify each feature into a stage

Apply this decision tree from the strongest evidence down — first match wins, Stage 0
is the fallthrough:

| Stage | Condition | Label |
|---|---|---|
| **6 — PR** | PR URL found in `plan.md` | `PR created` |
| **5 — Triage** | `tmp/review-*.md` exists, no PR URL in `plan.md` | `awaiting triage / verify` |
| **4 — Review** | `plan.md` exists and all its tasks are `[x]`, no `tmp/review-*.md` | `awaiting review` |
| **3 — TDD** | `worktree/` exists AND at least one `[ ]` task | `in progress` |
| **2 — Plan** | `plan.md` exists, no `worktree/` dir | `awaiting worktree` |
| **Done (archived)** | `spec.md` exists, no `plan.md`, no `worktree/`, feature branch merged | `done (archived)` |
| **1 — Spec** | `spec.md` exists, no `plan.md` | `awaiting plan` |
| **0 — Nothing** | No `spec.md` AND no `plan.md` AND no `worktree/` | `not started` |

If `plan.md` exists but contains no `[ ]` or `[x]` task lines, classify the feature as
Stage 2 and flag it as a broken state:

```
[!] plan.md has no task list — re-run the plan phase or add tasks manually.
```

An "active" feature is any feature at Stage 1–5 (not yet at PR stage).

## Step 3 — Detect broken states

Before showing normal status, check for these anomalies:

**Broken worktree** — `plan.md` references a worktree path but `.mx/<name>/worktree/` does not exist on disk:
```
[!] Worktree missing: .mx/<name>/worktree/
    The plan references a worktree but it no longer exists on disk.
    Recovery:
      Option A — Recreate: from the main repo directory run
                 `git worktree add .mx/<name>/worktree -b <branch> <base>` (mx-flow Phase 4.2),
                 then resume the TDD loop in that worktree
      Option B — Proceed without worktree: work directly in the main repo
```

**Tasks done but no worktree** — `plan.md` has all `[x]` tasks but `worktree/` never existed:
```
[!] State inconsistency: all tasks marked done but worktree was never created.
    Likely cause: tasks were completed in the main repo, not a worktree.
    This is fine if intentional — continue to /mx-team-review.
```

**Multiple active features** — more than one feature at Stage 1–5:
```
[!] Multiple features in progress. Specify which one to continue:
    /mx-flow status <name>
```
List them all so the user can choose.

## Step 4 — Determine next action

For the focused feature (or the single active one if only one exists), output the concrete next step — a command where one exists:

mx-flow has no phase re-entry point: `/mx-flow <topic>` always restarts at Phase 0 and
re-runs the spec-approval gate. Stages 1–3 therefore continue by hand or in the session
that started them.

| Stage | Next action |
|---|---|
| 0 | `/mx-brainstorm <topic>` or `/mx-flow <topic>` |
| 1 | Run `/mx-flow <topic>` — it will re-run brainstorm; or plan manually |
| 2 | Resume the mx-flow session that wrote the plan (it continues with the worktree), or create the worktree yourself and work there |
| 3 | Continue the TDD loop — next task: first `[ ]` task in `plan.md`. Resume in the existing session, or run that task directly |
| 4 | `/mx-team-review` |
| 5 — review exists, no triage | `/mx-review-triage --source review` |
| 5 — triage done, no PR | `/mx-pr` |
| 6 | `/mx-flow finish <name>` (after merge) |
| Done (archived) | Nothing — the feature is finished; its spec/ADR stay in `~/.mx/<project>/<name>/` |

## Step 5 — Output

Print the status block. Keep it dense and scannable — no prose.

### Single feature focus

```
mx-flow status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Project  : <project>
Feature  : <name>
Stage    : <N> — <label>
Progress : <done>/<total> tasks  (or "no plan" if Stage 0–1)
Spec     : ~/.mx/<project>/<name>/spec.md [exists | missing]
Plan     : .mx/<name>/plan.md [exists | missing]
Worktree : .mx/<name>/worktree/ [exists | missing | none]
Review   : <report filename, or "none">

Next     : <command>
           <one-line explanation if non-obvious>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### All features in project

```
mx-flow status — <project>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ● <name>   [ACTIVE] Stage 3 — TDD  4/7 tasks
  ✓ <name>   PR created — /mx-flow finish to clean up
  ○ <name>   Stage 1 — awaiting plan
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Active: <name>
Next  : continue the TDD loop — task 5: <description>
```

Symbols:
- `●` active (Stages 1–5)
- `✓` done (Stage 6 or archived)
- `○` not started (Stage 0)

If there are broken state warnings (Steps 2–3), show them above the status block with `[!]` prefix.

## Step 6 — Close out

If a broken state was detected, end with one line:

```
Recovery options are listed above — say which one to apply.
```

Do not block on a yes/no question. If no broken states, just show the status and stop.
The status subcommand modifies no file — it is read-only.
