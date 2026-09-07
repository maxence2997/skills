---
name: mx-team-review
description: >
  Deep code review of a local git diff or files against this user's own
  engineering standards (Go, C#), written to a report file that
  /mx-review-triage consumes. Use before commit/merge when you want the
  standards-based review, not a quick diff scan. Usage: /mx-team-review
  [diff-spec] | --repo <path>
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/mx-team-review
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
  - Task
---

# Code Review Orchestrator

## Trigger

```
/mx-team-review [diff-spec]
/mx-team-review --repo <path>
```

## Orchestrated mode

Step 6 (interactive review of the report) pauses for the user. **When
invoked from an orchestrator at all (mx-flow Phase 5b, or any orchestrator
that declares auto-proceed for a gate), skip the pause**: save and display
the report, then return control — triage happens in the orchestrator's
next step. When invoked directly by the user, Step 6 applies as written.

---

## Step 1: Parse Arguments and Determine Mode

Parse the user's argument to determine the review mode:

| Invocation | Mode | Action |
|---|---|---|
| `/mx-team-review` (no args) | diff | `git diff --cached` (staged changes) |
| `/mx-team-review HEAD~3` | diff | `git diff HEAD~3..HEAD` |
| `/mx-team-review main..HEAD` | diff | `git diff main..HEAD` |
| `/mx-team-review abc..def` | diff | `git diff abc..def` |
| `/mx-team-review --repo src/service/` | repo | Read all code files in directory |
| `/mx-team-review --repo src/service/order.go` | repo | Read specific file(s) |

**Argument parsing:**
1. If argument starts with `--repo` → repo mode. The path(s) follow.
2. Otherwise → diff mode. If no argument, default to `--cached`.

**Validation:**
- Diff mode: run the git diff command. If output is empty, print
  `No changes to review.` and stop.
- Repo mode: check if path exists. If not, print error and stop.

Display: `📋 Reviewing: {description of what is being reviewed}`

---

## Step 1.5: Right-Size the Review

Size the job before spending anything on it. In diff mode, read the size
off the diff Step 1 already ran. In repo mode, expand the target path with
Glob now to get the file list (Step 3 reuses it).

- **No source files** (docs/config only — `.md`, `.txt`, `.json`, `.yaml`,
  `.yml`, `.toml`, `.xml`): say so and run a **single Future Maintainer
  pass** (Step 4B, perspective 3 only — no Tech Lead synthesis). **Do not
  dispatch reviewers.** Files routed here count as explicitly targeted, so
  Step 3 reads them rather than applying its config skip-list.
- **Under ~30 changed lines in a single file** (diff mode; in repo mode, a
  single file of comparable size): use **Step 4B** regardless of Agent-tool
  availability.
- **Otherwise**: continue with the full pipeline.

State which path you took in the report header (Step 5).

---

## Step 2: Language Detection

Scan file extensions from the diff output (file paths in diff headers) or
the target file paths:

| Extension | Language Spec |
|-----------|--------------|
| `.go` | `references/golang.md` |
| `.cs` | `references/dotnet.md` |
| other | skip (no language spec applies) |

**Record which spec files apply**: always `references/principles.md`
(cross-language core principles), plus every matched language spec.
**Do not read them yet** — Step 4 decides how they are delivered.

Reference files are located relative to this SKILL.md file (sibling
`references/` directory). Record their **absolute paths** — Step 4A hands
those paths to subagents.

Display: `🔍 Detected: {language list}`

---

## Step 3: Gather Code Context

### Diff Mode

Run the git diff command determined in Step 1. The diff output is the
review material.

### Repo Mode

Reuse the file list Step 1.5 already produced with Glob (Glob it now if it
is not to hand). Use Read to load each file's content.

**Skip these files/directories:**
- Binary files (images, compiled assets)
- Lock files (`go.sum`, `package-lock.json`, `yarn.lock`)
- Vendor directories (`vendor/`, `node_modules/`)
- Generated files (`*.pb.go`, `*.generated.cs`)
- Config/data files (`.json`, `.yaml`, `.yml`, `.toml`, `.xml`) unless
  explicitly targeted

---

## Step 4: Multi-Perspective Review

**First, read `references/prompts.md`** (sibling `references/` directory).
It contains the reviewer output schema, the line-number rules, the three
reviewer prompts, and the Tech Lead synthesizer prompt used below.

This step has two execution modes. **Choose based on available
capabilities:**

- **Step 4A** — If the **Agent tool** (or its legacy alias **Task**) is
  available (e.g., Claude Code): dispatch four subagents (three reviewers
  in parallel, then one synthesizer).
- **Step 4B** — If neither is available (e.g. Codex CLI, Copilot, Cursor,
  or when you are yourself a subagent): perform all four perspectives
  sequentially in a single pass.

Both modes produce the **same final output**, so Step 5 works identically.

### Step 4A: Parallel Dispatch (Agent/Task tool available)

**Phase 1 — Three Reviewers (parallel):**

Dispatch Agent 1 (Senior Engineer), Agent 2 (SRE Guardian), and Agent 3
(Future Maintainer) simultaneously — all three Agent calls in a single
message.

Each subagent receives:
- Full diff or file content from Step 3
- The **absolute paths** of the spec files recorded in Step 2
  (`references/principles.md` plus any matched language spec) — the
  subagent reads them itself; do not inline their contents
- Its own perspective prompt plus the shared schema and line-number rules
  (all from `references/prompts.md`)

Model: set `model: "sonnet"` (mid tier) for the three reviewers.

Wait for all three to complete. Collect their JSON outputs.

If a reviewer returns no output, an error, or unparseable JSON: **retry
that one reviewer once**. If it fails again, continue with the remaining
reviewers and put `⚠️ <perspective> review unavailable — report based on N
of 3 perspectives` in the report header notes (Step 5), alongside any
`(single-pass mode)` marker. **Never silently drop a perspective.** If all
three fail, stop and say the review could not be produced — never emit an
empty report, which reads as a clean one.

Check each reviewer's `specs_read` field. If one is missing or empty, that
reviewer did not confirm reading the standards — note
`⚠️ <perspective> did not confirm reading the standards` in the report
header too.

**Phase 2 — Tech Lead (sequential):**

Dispatch Agent 4 (Tech Lead) with:
- All three JSON outputs from Phase 1 (or the surviving ones)
- The original diff/code content (for cross-verification)
- The **absolute path** of `references/principles.md` (for severity
  calibration) — the subagent reads it itself; do not inline its content

Model: `model: "sonnet"` by default. **Escalate the Tech Lead to the
strongest available tier** (e.g. `opus`) when the diff touches any of:
concurrency primitives, auth/security, data migration, or a public API
surface — synthesis quality there is worth the cost (see
`${CLAUDE_SKILL_DIR}/../mx-doctrine/references/model-dispatch.md` §4; if
missing, apply this sentence as written).

Collect the final merged JSON.

### Step 4B: Single-Pass Fallback (no Agent/Task tool)

Perform all four perspectives yourself, sequentially, using the prompts
from `references/prompts.md`:

0. Read the spec files recorded in Step 2 (`references/principles.md` plus
   any matched language spec). This is the point at which they are needed —
   read them now, not earlier.
1. Adopt the **Senior Engineer** perspective. Analyze the entire code.
   Produce its JSON output (`"agent": "senior-engineer"`).
2. Adopt the **SRE Guardian** perspective. Analyze independently — do not
   skip areas already covered. Produce its JSON output
   (`"agent": "sre-guardian"`).
3. Adopt the **Future Maintainer** perspective. Analyze independently.
   Produce its JSON output (`"agent": "future-maintainer"`).
4. Adopt the **Tech Lead** perspective. Take all three JSON outputs and
   synthesize the final merged JSON.

**Important:** Each perspective must be treated as an independent review.
Do not let findings from one perspective influence another. Duplicates are
expected — the Tech Lead handles merging.

Single-pass reviews share one context — genuinely useful, but weaker than
independent reviewers. Note `(single-pass mode)` in the report header so
readers calibrate their trust.

---

## Step 5: Report Generation

Take the Tech Lead's final JSON — or, on the Step 1.5 docs-only path, the
single reviewer's JSON, whose `issues` and `highlights` have the same
shape — and format the report.

**Report format:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Review: {description of scope}
   {n} files reviewed  |  {language list}
   {header notes}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📁 {file_path}

🔴 error  L{line}  [{category}]
   {message}
   💡 {suggestion}

🟡 warning  L{line}  [{category}]
   {message}
   💡 {suggestion}

🔵 suggestion  L{line}  [{category}]
   {message}
   💡 {suggestion}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 {e} errors  {w} warnings  {s} suggestions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ Highlights
{- {message}}
{- {message}}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Severity emoji: 🔴 error, 🟡 warning, 🔵 suggestion

Triage maps these to P0–P3 using
`${CLAUDE_SKILL_DIR}/../mx-review-triage/references/SEVERITY.md` (if
missing, the mapping still is not yours to make) — do not emit P-levels
here.

`{header notes}` carries the markers that tell the reader how much to trust
this report — omit the line when there are none:
- `(single-pass mode)` when Step 4B produced it
- the Step 1.5 path taken when it was not the full pipeline
- any `⚠️ …` degradation notice raised in Step 4A

For issues with `line: 0`, display `L-` instead of `L0`.

If there are no highlights, omit the ✨ Highlights section entirely.

**Output actions:**

1. Detect active feature:
   - Resolve repo root: `REPO_ROOT=$(git rev-parse --show-toplevel)`
   - If running inside a linked worktree, `.mx/` lives in the MAIN
     repository, not the worktree — resolve it too:
     `MAIN_ROOT=$(cd "$(dirname "$(git rev-parse --git-common-dir)")" && pwd)`
     (in a normal checkout `MAIN_ROOT` resolves to the same directory as
     `REPO_ROOT`)
   - Look for any `.mx/*/plan.md` under `$REPO_ROOT`, then under
     `$MAIN_ROOT` — take the first match as the active feature
   - If found → report directory is `.mx/<name>/tmp/` (create if needed)
   - If not found → report directory is `/tmp/review-reports/` on Unix or
     `%TEMP%\review-reports\` on Windows (create if needed)
2. Save the report as `{report-dir}/review-{YYYYMMDD-HHmmss}.md`
3. Display the full report in the terminal

---

## Step 6: Interactive Review

(Skipped in orchestrated mode — see "Orchestrated mode" above.)

After displaying the report, ask:

```
Please review the report. Any changes needed?
```

**If the user requests changes:**

1. Discuss the issue with the user
2. Modify the report and update the saved file accordingly
3. Display the updated report
4. Ask again: `Any other changes?`
5. Repeat until the user confirms

**If the user confirms (e.g., "no", "OK", "looks good"):**

Done. Display the saved report path with a reminder:

```
📄 Report saved: {report-dir}/review-{timestamp}.md
```

If saved to `/tmp/review-reports/`, add a note:
```
⚠️  No active feature detected — report saved to /tmp (cleared on reboot). Run from within a feature workflow to save under .mx/<name>/tmp/ instead.
```

---

## Extending to a New Language

To add a new language spec:
1. Create `references/{lang}.md` using `references/_template.md` as a base
2. Only include language-specific patterns — cross-language principles are
   in `references/principles.md`
3. Add a row to the language detection table in Step 2:
   ```
   | `.ext` | `references/{lang}.md` |
   ```
No other changes required.
