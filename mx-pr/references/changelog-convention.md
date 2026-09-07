# CHANGELOG Rules

Convention for the target repo's `CHANGELOG.md`. Backs the
"CHANGELOG updated" checklist item in `pr-template.md`.

## Format

```markdown
## [<version>] - YYYY-MM-DD

### <Category>
- <change> (#<PR>)
```

- Newest version first. Unmerged/unreleased changes accumulate under `## [Unreleased]` at the top; rename that section to the version on release.
- **Hard limit: max 8 lines per version entry** (category headings + bullets combined). Over the limit → keep the most user-visible changes, merge the remainder into one summary line.
- One line per change. No wrapping, no sub-bullets, no paragraphs.
- All text in English.

---

## Categories

Category names follow Keep a Changelog. Commit types are defined in
`${CLAUDE_SKILL_DIR}/../mx-commit/references/commit-message.md` — if that
file is missing (partial install), say so once and use the type list below
as written. Map them as:

| Category | From commit type | Note |
|---|---|---|
| Added | `feat` | New user-facing capability |
| Changed | `feat`/`refactor` that alters existing behavior | |
| Fixed | `fix` | |
| Removed | any removal of a feature/flag/API | |
| Deprecated | — | Announce before Removed |
| Security | `fix`/`chore` for CVE, auth, injection | Never dropped for the 8-line cap |

- Omit empty categories.
- `refactor`/`test`/`chore`/`style`/`doc` with no user-visible effect: do not record at all.

---

## Writing style

Facts only. Each line = the change + its user-visible effect. No background,
no narrative, no "we"/"this PR".

1. Lead with a verb: Add / Fix / Change / Remove / Deprecate.
2. State the user-visible effect, not the implementation.
3. Name the concrete subject (flag, endpoint, command, config key) — no pronouns.
4. Breaking change: prefix `**BREAKING**` and state the migration in the same line.
5. Append the PR reference `(#<PR>)`; add the issue too if one exists.

```
// ❌ Narrative + background
- We noticed users were confused by retry behavior, so after discussion we changed it

// ❌ Implementation detail, no user-visible effect
- Refactor reconnectLoop internals

// ✅ Verb first, concrete subject, effect stated
- Fix double-charge on Stripe webhook retry (#142)
- **BREAKING** Rename `--out` to `--output`; update scripts before upgrading (#150)
```

---

## Example

```markdown
## [1.4.0] - 2026-08-27

### Added
- Add `--dry-run` flag to preview install changes (#88)

### Fixed
- Fix symlinked skills reverting on install with unpushed commits (#91)

### Security
- Upgrade gorilla/websocket to v1.5.3 to patch CVE (#93)
```

7 lines — within the 8-line cap.
