---
name: mx-review-triage
description: >
  Triage review findings — from local mx-team-review reports or GitHub/GitLab PR
  comments — into fix / track / skip buckets by validity, severity (P0-P3), and
  cost, then execute approved decisions. Use after mx-team-review or when
  handling PR feedback before merge.
  Usage: /mx-review-triage [--source review | --source pr <id|url>]
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/mx-review-triage
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

# mx-review-triage

## Trigger

```
/mx-review-triage                       ← auto-detect source
/mx-review-triage --source review       ← local mx-team-review report
/mx-review-triage --source pr <id|url>  ← GitHub / GitLab PR comments
```

## Orchestrated mode

Step 5 pauses for user approval of the triage table. **When invoked from
an orchestrator that declares auto-proceed for its triage gate (e.g.
mx-flow GATE 3), skip that pause**: show the full triage table, treat all
"Fix now" items as approved, and execute them immediately. "Track" and
"Skip" buckets behave as written. When invoked directly by the user, the
pause applies as written.

**Hard gate**: with `--source pr`, this skill does not finish until zero
unresponded comments remain (Step 7).

---

## Step 1 — Determine source

### If `--source review`
Find the most recent review report:
1. Resolve repo root: `REPO_ROOT=$(git rev-parse --show-toplevel)`. If
   running inside a linked worktree, also resolve the main repository root
   (`.mx/` lives there):
   `MAIN_ROOT=$(cd "$(dirname "$(git rev-parse --git-common-dir)")" && pwd)`
   (in a normal checkout MAIN_ROOT resolves to the same directory as REPO_ROOT)
2. Check `.mx/*/tmp/review-*.md` under `$REPO_ROOT` and `$MAIN_ROOT`
   (project-local active feature path)
3. Fall back to `/tmp/review-reports/` (Unix) or `%TEMP%\review-reports\` (Windows)

Pick the file with the latest modification time across both locations.
If no report exists in either location, report the error and stop.

### If `--source pr <id|url>`
Detect the platform from the repo's remote URL:
- **GitHub**: `gh api` to fetch review comments and issue comments
- **GitLab**: `glab api` to fetch MR discussions and notes

Filter out:
- Comments already replied to by the PR author
- Bot-generated summary comments (e.g. Copilot review overview)
- Individual line comments from bots MUST still be evaluated

If the platform CLI is absent or its call fails for any reason (not installed, not
authenticated, network, 4xx/5xx), stop and report the exact error — never treat a
failed fetch as "no comments"; Step 7's gate cannot pass on an unread PR.
If the remote is neither GitHub nor GitLab, say so and ask the user for the comment
source.

If zero unresponded comments remain, report "No unresponded comments." and stop.

### If no argument (direct invocation only)

Auto-detect in this order:
1. `.mx/*/tmp/review-*.md` (project-local) or the OS temp review-reports directory has a file modified within the last hour → suggest `--source review`
2. Current branch has an open PR (`gh pr view` or `glab mr view` succeeds) → suggest `--source pr`
3. Both available → ask user which source to use
4. Neither available → ask user

> When invoked by mx-flow, always use `--source review` directly — skip this step.

---

## Step 2 — Parse findings

For each finding, extract:
- **Location**: file and line (or `—` if not applicable)
- **Category**: bug, correctness, design, security, performance, style/nitpick, question, suggestion
- **Severity**: classify using `references/SEVERITY.md`, including its mapping from
  the report's 🔴 / 🟡 / 🔵 severities

---

## Step 3 — Triage each finding

Read the referenced code and assess every finding on three dimensions:

| Dimension | Evaluate |
|-----------|----------|
| **Validity** | Is the observation factually correct? Does it apply to the current code? |
| **Implementation cost** | Low (< 10 lines, single file) / Medium (multiple files, needs testing) / High (architectural, risky) |
| **Risk of not fixing** | What breaks or degrades if ignored? P0 items cannot be skipped. |

---

## Step 4 — Classify into action buckets

| Bucket | Criteria |
|--------|----------|
| **Fix now** | High risk + low/medium cost. P0 always here. Bug, security, correctness, data loss. |
| **Track** | Medium risk + needs design, or medium cost + not blocking. Add to `TODOS.md`. |
| **Skip** | Low risk + high cost, false positive, nitpick, or already handled elsewhere. |

---

## Step 5 — Present report

With 1–2 findings, skip the table: state each finding, its bucket and severity in a
sentence, then proceed under the Step 5 approval rule for the active source.

Otherwise show the full triage table, sorted by bucket then severity, with these
eight columns:
`# | Bucket | Sev | File:Line | Comment (summary) | Cost | Risk | Recommended action`
(a rendered sample is in `references/EXAMPLES.md`).

Briefly explain any non-obvious triage decisions after the table.

Then, by source:
- `--source pr`: **do not post any reply or make changes yet** — wait for user
  approval (replies are public and not retractable).
  (Orchestrated mode: treat "Fix now" as approved and continue — see above.)
- `--source review`: execute the "Fix now" bucket immediately after showing the
  table; pause only for items whose fix touches files outside the reviewed diff or
  exceeds the cost class you assigned.

---

## Step 6 — Execute approved decisions

Once the decisions for the active source are settled (bucket assignments adjusted as
needed):

Before writing replies, read `references/EXAMPLES.md` (located in the same directory
as this SKILL.md) for the reply templates and a worked triage table; if the file is
missing, use the bare formats below.

**Fix now** — make the code change, then:
- `--source review`: commit with `/mx-commit` (pass `--auto` when running
  under an orchestrator's auto-proceed gate; default interactive otherwise)
- `--source pr`: commit then reply on the PR/MR:
  `Fixed in {hash}. {what changed and why}`

**Track** — append the entry to `<repo root>/TODOS.md`, creating the file with a
`# TODOS` heading if it does not exist. Entry format:
`- [ ] <sev> <file:line> — <finding> (from review <date>)`
- `--source pr`: reply `Tracked in TODOS.md — {reason}`

**Skip (won't fix)**:
- `--source pr`: reply `Won't fix. {clear reasoning}`

**Skip (not applicable)**:
- `--source pr`: reply `Not applicable — {explanation}`

Duplicate or related findings may reference each other: `Same reasoning as #{N} above — {brief}`.

---

## Step 7 — Final check

- `--source review`: report findings resolved. If fixes were made, note which commits.
- `--source pr`: verify zero unresponded comments remain. This is a hard gate before merge.
