# Severity Definitions

Customize these definitions to match your team's priorities.

| Level | Name | Criteria | Action |
|-------|------|----------|--------|
| **P0** | Must fix | Bug, security vulnerability, data loss risk, silent error | Always "Fix now" — cannot be skipped or deferred |
| **P1** | Should fix | Correctness issue, design flaw, missing error handling, race condition | Default "Fix now" if cost is low; "Track" if needs design |
| **P2** | Nice to have | Style improvement, better naming, minor enhancement, readability | Default "Track" or "Skip" depending on cost |
| **P3** | Optional | Personal preference, nitpick, cosmetic, formatting | Default "Skip" unless trivial to fix |

## Mapping from mx-team-review report severities

🔴 error → P0 if the finding is a bug, security issue, data loss, or a silently
swallowed error, otherwise P1. 🟡 warning → P1 if it concerns correctness or missing
error handling, otherwise P2. 🔵 suggestion → P2 if it changes behaviour or structure,
otherwise P3. Triage refines within the band, never outside it.
