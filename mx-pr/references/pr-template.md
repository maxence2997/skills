# PR Template

This file defines the pull request description format.
Customize the sections, labels, and instructions to match your team's conventions.
The skill reads this file and fills each section using collected context.

---

## How the skill fills each section

| Placeholder | Source |
|-------------|--------|
| `{{summary}}` | Design spec — What and How sections (2-4 bullets) |
| `{{motivation}}` | Design spec — Why section (one paragraph) |
| `{{changes}}` | Git log since branch start, grouped by commit type |
| `{{test_plan}}` | Completed tasks from plan.md |
| `{{notes}}` | Design spec — Out of scope / trade-offs (omitted if empty) |
| `{{checklist_conditional}}` | Skill selects relevant items based on commit types in the git log |
| `{{issues}}` | Related issues found via branch name, commit messages, or open issue list — `Closes #N` if this PR resolves the issue, `Relates to #N` if partial; omitted if none found |

Sections marked `<!-- optional -->` are omitted from the draft if no content is available.

---

## Template

```markdown
## Summary

{{summary}}

## Related issues <!-- optional -->

{{issues}}

## Motivation

{{motivation}}

## Changes

{{changes}}

## Test plan

{{test_plan}}

## Checklist

### Required

- [ ] Full test suite passes
- [ ] Each commit represents exactly one logical change
- [ ] Commit messages follow the project's commit format
- [ ] No unrelated code reformatting in this PR
- [ ] No secrets committed
- [ ] CHANGELOG updated

### Conditional

<!-- Skill selects applicable items based on change type. Remove any that do not apply. -->

{{checklist_conditional}}

## Notes <!-- optional -->

{{notes}}
```

---

## Conditional checklist items

The skill picks from this list based on commit types found in the git log:

| Condition | Trigger |
|-----------|---------|
| `- [ ] Bug fix: includes a failing test before the fix and passing after` | any `fix:` commit |
| `- [ ] New public API: includes documentation and usage examples` | any `feat:` commit touching public interfaces |
| `- [ ] Breaking change: migration notes included, version bump discussed` | commit message contains `BREAKING` or `!` |
| `- [ ] Performance-sensitive change: benchmark results included (before/after)` | any `perf:` commit |
| `- [ ] Database migration: rollback plan documented` | migration files detected in diff |

If none apply, the Conditional section is omitted entirely.

---

## Customization examples

**Add a screenshots section:**
```markdown
## Screenshots <!-- optional -->

{{screenshots}}
```

**Add a project-specific conditional item:**
```markdown
- [ ] Shared state mutation only happens in the designated owner goroutine
```

**Rename sections to match your team:**
```markdown
## What changed
## Why
## How to test
```

---

## Rules

- The CHANGELOG entry itself follows `changelog-convention.md` in this directory. That path is skill-local: it must never appear in the published body — the checklist line stays plain, and so does anything else you add here
- The title is derived from the first bullet of `{{summary}}` — keep it under 72 characters
- If the design spec does not exist, `{{summary}}`, `{{motivation}}`, and `{{notes}}` are derived from the git log only
- Empty optional sections are removed from the final draft
