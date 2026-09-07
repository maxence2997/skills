---
name: mx-doctrine
description: >
  Shared execution doctrine for all mx-* skills: model dispatch and escalation,
  delegation templates, judgment rubrics (when done / when to ask / wrong-direction
  signals), verification contracts, maintenance protocol. Consult when dispatching
  sub-agents, when repeatedly failing, or before editing any mx-harness file.
  Usage: /mx-doctrine [topic]
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/mx-doctrine
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# mx-doctrine

Shared doctrine consumed by the other mx-* skills. This SKILL.md is a
router; the content lives in `references/`.

## Trigger

```
/mx-doctrine              ← summarize what doctrine exists and when each applies
/mx-doctrine <topic>      ← read the matching reference file and apply/answer
```

Other mx-* skills reference these files directly at the moments they
matter — you rarely need to invoke this skill explicitly.

## The files

| Read this | When |
|---|---|
| `references/model-dispatch.md` | Before spawning any sub-agent; when choosing a model tier; when a subtask keeps failing (escalation ladder §6); to check what your harness supports (§0/§1) |
| `references/judgment-rubrics.md` | Before declaring work done (§2); before interrupting the user with a question (§3); after 2 failed attempts (§1); when a fix requires weakening a gate (§4); when a taste call has no right answer (§6) |
| `references/delegation-templates.md` | When writing any sub-agent prompt — search, implement, refactor, research, review, read-back |
| `references/maintenance.md` | Before editing ANY mx-harness file (repo or installed copy) |
| `references/diagnosis.md` | To understand why the suite is structured this way; when re-auditing for bloat (procedure at the bottom of that file) |

On `/mx-doctrine <topic>`: pick the file(s) whose row above matches the
topic, read them, and answer or apply. On bare `/mx-doctrine`: print the
table above plus a 3-line summary of each file.

## How mx-* skills reference these files

From another skill's SKILL.md, the path convention is:

```
${CLAUDE_SKILL_DIR}/../mx-doctrine/references/<file>.md
```

(`${CLAUDE_SKILL_DIR}` = the directory containing the running SKILL.md;
skills install as sibling directories. In harnesses without that
substitution, resolve relative to the SKILL.md file you are executing.
When briefing a sub-agent, the orchestrator resolves these to absolute
paths and puts the resolved paths in the brief — sub-agents must not be
asked to re-derive sibling-skill paths.)

Same-directory reads use a bare `references/<file>` path (the directory
sits next to the SKILL.md); cross-skill reads use
`${CLAUDE_SKILL_DIR}/../<skill>/references/<file>` and always carry a
missing-file fallback.

**Graceful degradation (partial installs):** if the referenced file does
not exist, say so in one line, apply the inline summary at the reference
site, and continue. Never silently skip the step, and never fabricate the
missing file's contents.

## Hard defaults (apply even if no reference file is ever read)

1. **Commander doesn't descend** — bulk reading, repo sweeps, web research,
   and batch edits go to sub-agents when the harness has them; only
   conclusions enter the orchestrating context.
2. **Never self-verify a deliverable** — code: run the project's gate and
   show output; prose/config: fresh-context read-back; no sub-agent tool
   available: label the check "self-checked, single-context".
3. **Two failed rounds max** per subtask at one tier (small tier/haiku:
   one), then escalate model or ask; 4 failed rounds total → stop and ask
   the user.
4. **Never weaken a gate to get green** — full list:
   `references/judgment-rubrics.md` §4 signal 1. A gate fighting you is a
   design signal.
5. **Every delegation carries**: goal + motivation, acceptance criteria,
   report format.
