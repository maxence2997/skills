# mx-review-triage

Triage review findings and decide what to fix, track, or skip.

Works with two sources:
- **Local review** — output from `/mx-team-review` (use after a local code review)
- **PR comments** — unresponded comments on a GitHub or GitLab PR/MR

The triage logic is identical for both sources: assess validity, severity, and cost, then classify into fix / track / skip buckets, then show the triage report before executing anything.

## Usage

```
/mx-review-triage                       # auto-detect source
/mx-review-triage --source review       # local mx-team-review report
/mx-review-triage --source pr 42        # GitHub/GitLab PR by number
/mx-review-triage --source pr <url>     # PR by URL
```

## Action buckets

| Bucket | When |
|--------|------|
| **Fix now** | P0 always; high risk + low/medium cost |
| **Track** | Medium risk, deferred; added to `TODOS.md` |
| **Skip** | Low risk, false positive, or nitpick |

## Severity levels

Defined in `references/SEVERITY.md`, along with the mapping from mx-team-review's 🔴 / 🟡 / 🔵 report severities — customize both to match your team's priorities.

Reply templates and a worked triage table live in `references/EXAMPLES.md`, read before any PR reply is written.

## Notes

- `--source pr`: never makes code changes or posts PR replies without user approval — except when invoked by an orchestrator that declares auto-proceed for its triage gate (mx-flow GATE 3)
- `--source review`: shows the triage table, then executes the "Fix now" bucket immediately; pauses only for fixes that reach outside the reviewed diff or exceed the assigned cost class
- `--source pr` mode: zero unaddressed comments is a hard gate before merge
- Auto-detect only runs when invoked directly — mx-flow always uses `--source review`
- Supports both GitHub (`gh`) and GitLab (`glab`) — authenticate before use
