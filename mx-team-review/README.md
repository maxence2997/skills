# mx-team-review

Multi-perspective code review using three AI review agents (Senior Engineer, SRE Guardian, Future Maintainer) synthesized by a Tech Lead into one final report.

## How it works

1. Parses git diff or reads files directly
2. Right-sizes the review — a docs/config-only diff gets a single Future Maintainer pass, and a small single-file diff runs in single-pass mode
3. Detects programming languages from file extensions
4. Runs three independent review perspectives (parallel when possible), unless step 2 scaled the review down
5. Tech Lead synthesizes findings — deduplicates, resolves conflicts, filters noise (skipped on the scaled-down path)
6. Saves the report to `.mx/<name>/tmp/` (or `/tmp/review-reports/` if no active feature) and displays it
7. Presents the report for interactive review (skipped when an orchestrator invoked it)

The report header states which path was taken, and flags any perspective that failed or did not confirm reading the standards — a degraded review never looks like a clean one.

## Modes

**Diff mode** (default):
```
/mx-team-review                    # staged changes
/mx-team-review HEAD~3             # last 3 commits
/mx-team-review main..HEAD         # branch diff
/mx-team-review abc..def           # commit range
```

**Repo mode**:
```
/mx-team-review --repo src/service/          # entire directory
/mx-team-review --repo src/service/order.go  # specific file
```

## Supported languages

- Go (`.go`)
- C# .NET 8 (`.cs`)

Extensible via `references/_template.md`.

## Customization

The reviewer prompts and output schema live in `references/prompts.md`;
cross-language review standards in `references/principles.md`. Both are
yours to edit — the installer preserves local changes to `references/*`.

## In the workflow

Use after completing a milestone in the TDD phase, before `/mx-review-triage`:

```
TDD (tasks done) → mx-team-review → mx-review-triage --source review
```

The report is saved to `.mx/<name>/tmp/` and automatically picked up by `/mx-review-triage --source review`.
