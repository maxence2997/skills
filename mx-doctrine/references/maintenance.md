# Maintenance protocol — updating mx-harness without wrecking it

> Shipped with mx-harness. Written 2026-07-07. Applies to every file in the
> mx-harness repo and to installed copies of the skills. Read this WHOLE
> file before editing any of them.

## §1 Know which copy you are editing

mx-harness files exist in two places with different rules:

| Location | Role | Editing rule |
|---|---|---|
| The git repo (`mx-harness/`) | Canonical source | All durable changes go here, through git. The clean working tree + history IS the backup. |
| Installed copies (`~/.claude/skills/mx-*/`, `~/.codex/skills/…`) | Deployment | Treat as read-only. `install.sh` **overwrites SKILL.md and README.md unconditionally** on update; `references/*` survive only if the user modified them (hash lock in `~/.mx/.mx-harness.lock`). An edit made only to an installed SKILL.md will be silently lost. |

If you find yourself improving an installed copy: stop, make the change in
the repo instead, and tell the user to re-run `install.sh`. Exception: the
user explicitly wants a local-only customization → put it in that skill's
`references/` (the hash lock will then protect it), never in SKILL.md.

## §2 Universal rules (no exceptions)

1. **Backup first.** In the repo with a clean tree, git is the backup —
   commit or verify `git status` is clean before large edits. Outside git
   (installed copies, user config), copy the file aside with a date suffix
   before touching it.
2. **Verify environment claims before writing them.** Any statement about
   tool names, parameters, model availability, or paths must be checked in
   the CURRENT session (schema in context, `ls`, `--help`, official docs).
   If you cannot verify, prefix it `UNVERIFIED (YYYY-MM-DD):`. Never carry
   a claim forward just because the previous version said so.
3. **Date everything you add.** Absolute dates only ("2026-07-07"), never
   "today"/"recently".
4. **One canonical statement per rule.** Before adding rule text, grep the
   repo for the same concept. If it exists, point at it; if you must move
   it, grep for every reference to the old location before finishing.
   (This repo's worst historical defects were drifted duplicates and dead
   pointers — see `diagnosis.md` Focus 3 / Error 1.)
5. **Three-places sync** when changing what a skill does:
   `<skill>/SKILL.md` (the change) + `<skill>/README.md` (user-facing list)
   + root `README.md` (skills table, if the one-liner changed). Adding a
   new skill → also append it to `install.sh`'s `SKILLS=(...)` array, or it
   won't ship.

## §3 What you may change autonomously

- **Append a lesson** (format in §5) to `judgment-rubrics.md`,
  `model-dispatch.md`, or a skill's references. Appending is safe;
  rewriting is not.
- **Fix verified staleness**: a tool/parameter/path/skill-name that
  provably changed — show the verification in the same session, update the
  fact AND its verified-date stamp.
- **Add a delegation template** for a task shape that recurs.
- **Fix a dead pointer or broken example** (with the grep that proves it
  dead).
- **Prune your own additions** within the same session.

## §4 What requires asking the user first

- **Deleting or weakening any rule** — hard guards, gate behavior,
  verification contracts. Rules encode past failures; a rule that seems
  pointless is usually working.
- **Changing thresholds**: the 2-failed-rounds cap, the 4-round absolute
  cap, mx-flow's 3-iteration loop limit, the ≤50-word description budget,
  the >40-line extraction rule. Drift here is how the institution
  dissolves.
- **Changing gate semantics** — turning a human gate into auto-proceed or
  vice versa (mx-flow's gate table, mx-brainstorm's spec approval).
- **Restructuring**: renaming skills or reference files, moving canonical
  content between skills. Every stale pointer you create outlives your
  session.
- **Changing `install.sh` behavior** (the hash-lock contract especially) —
  it guards every user's local customizations.

## §5 Lesson write-back — where and in what format

After a real failure (wrong direction caught late, gate bypassed, wasted
escalation, user correction), write the lesson down BEFORE ending the turn:

| Lesson type | Goes to |
|---|---|
| A judgment call decided wrongly | `judgment-rubrics.md` — a new ✅/❌ example under the matching §, or a new numbered signal |
| Wrong tier or delegation shape | `model-dispatch.md` — routing-table row or §6 ladder note |
| A recurring task shape worth templating | `delegation-templates.md` — new template |
| A skill's procedure failed in the field | that skill's SKILL.md or references — via §3/§4 rules above |
| Environment truth or degradation warning | `diagnosis.md` — dated line under "Additional findings" |

Format (three lines, dated):

```
- (YYYY-MM-DD, from <one-line incident>): <the rule, imperative>.
  ✅ <positive example> / ❌ <negative example>
```

A lesson without the incident and the counterexample is a platitude —
don't write it.

## §6 Compaction — when and how

Triggers: any `description:` > 50 words; any SKILL.md > ~450 lines
(investigate via the extraction rule in `diagnosis.md` Leak 3 — core-path
content may justifiably keep a file larger; mx-flow sits near ~920 lines
by design: ~65% always-executed procedure, ~12% branch-only in six blocks
none of which reaches the 40-line extraction threshold (re-measured
2026-09-06)); any file in this directory > ~300 lines; the same concept
stated in 2+ places.

How: rely on git history as the archive; merge duplicate lessons into the
strongest phrasing; NEVER silently drop a rule — deletions go through §4.
Compaction removes repetition, dead references, and superseded facts
(after verification) — it preserves rules and examples.

## §7 Sanity check after any edit

30 seconds, every time:
(a) every path/skill name you wrote exists — `ls` / grep it;
(b) after a rename or renumber, grep the whole repo for the old name —
    zero hits or you're not done;
(c) `bash -n install.sh` still parses if you touched it;
(d) run the description-budget check from `diagnosis.md`'s re-audit block
    if you touched frontmatter.

For anything bigger than one appended lesson, spawn the read-back stub
from `delegation-templates.md` instead of trusting yourself — acceptance
criteria: the specific rules you added/changed, checked cold by a fresh
context.
