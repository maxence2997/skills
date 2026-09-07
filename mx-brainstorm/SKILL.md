---
name: mx-brainstorm
description: >
  Turn a rough idea into an approved design spec before any code is written:
  clarifying questions in one batch, 2-3 distinct approaches with trade-offs,
  spec and ADR written to ~/.mx/<project>/<name>/. Hard gate: no implementation until
  the user approves the spec. Use at the start of any feature or non-trivial fix.
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/mx-brainstorm
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Write
---

# mx-brainstorm

## Trigger

```
/mx-brainstorm <topic>
/mx-brainstorm
```

---

## Operating principles

**Don't assume. Don't hide confusion. Surface tradeoffs.** These apply at
every step below — not just Step 1.

- **State assumptions explicitly.** If uncertain, ask rather than guess.
- **Present multiple interpretations.** When the user's request is
  ambiguous, surface the readings and let the user pick. Do not silently
  choose one and proceed.
- **Push back when warranted.** If a simpler approach exists, say so. If a
  proposed option is over-engineered for the stated problem, name it.
- **Stop when confused.** Name what is unclear and ask for clarification.
  Do not paper over confusion with plausible-sounding text.

Applied to this skill specifically:
- In Step 2, options must be **genuinely distinct** — do not pad to three
  options by inventing a contrived variant. Two real options beats three
  fake ones.
- In Step 2, prefer the **minimum approach that solves the stated
  problem**. Larger options must justify their extra scope explicitly in
  `Best when`.

### Side requests

At any step, the user may ask for something mid-conversation (e.g. "open
an issue", "add a comment", "check a file"). When this happens:

- Execute **exactly** what was requested — nothing more
- Do not make additional code changes, file edits, or actions that were
  not asked for
- After completing the side request, return to the brainstorm conversation

Example: "go open an issue describing this" → open the issue, stop. Do not
also edit source files.

---

## Step 1 — Understand the idea

Exit early if the change is small enough that the spec would restate the
diff: a single obvious fix, one call site, no design choice to make. Say
"this is small enough to skip the spec — I'll do it directly" and stop. If
the user disagrees, continue. Not under an orchestrator: when mx-flow
invoked this skill the user already chose the full flow — write the spec.

Read existing code relevant to the topic (if any) using Glob and Read.
Then ask **all** your clarifying questions in ONE message. Before sending,
list every open question you have; group them, then send the group. The
ground to cover:

- What problem does this solve?
- Who is affected and how?
- Are there constraints (performance, compatibility, deadlines)?
- What does success look like?

Rules:
- One batch, 3-6 questions, hard cap 6. If you have more, ask the 6 whose
  answers most change the design and note that others may follow
- Every question carries (a) a proposed default and (b) one clause on why
  it matters. The user may reply "defaults" / "just decide" to accept all
  proposed defaults — then say which defaults you adopted and continue
- Number the questions so the user can answer any subset; treat unanswered
  items as accepting the stated default and say so
- Prefer multiple-choice over open-ended where possible. Do not lead:
  state the default as a default, not as a recommendation, and state the
  trade-off it accepts
- Stop asking when you can write all four spec sections — What / Why /
  How / Out of scope — without a TBD that would change the chosen
  approach. Remaining uncertainty that does not change the approach goes
  into Out of scope, not into another question
- Follow-up batches only when an answer opens a genuine new fork (a choice
  whose options were not visible before). Max 2 follow-up batches; after
  that, state the remaining uncertainty in Out of scope and move on
- If invoked from mx-flow, the topic is already provided — send the batch
  immediately, do not ask if the user wants to start

When the answers are in, say what you now understand in 2-3 lines and move
to Step 2 in the same message. The user can correct you at any point.

---

## Step 2 — Propose approaches

Present **2 or 3 distinct approaches**. For each:

```
### Option A — <short name>
What: <one sentence>
Trade-offs: <pros and cons>
Best when: <the condition that makes this the right choice>
```

Do not recommend one option as "best" — let the user decide.
If you have a strong preference based on the context, state the reason
once, briefly.

---

## Step 3 — Refine

Ask follow-up questions as one further batch if the user's choice reveals
new ambiguities (Step 1's batch rules apply, follow-up cap included).
Iterate until the design is unambiguous or that cap is reached — what is
still open then goes into the spec's Out of scope.

Then go to Step 4 — the spec-approval gate lives there, after the spec
exists.

---

## Step 4 — Write the design spec

Resolve the MX directory:
- Get the repo root name: final path component of
  `git rev-parse --show-toplevel`. If that command fails you are not in a
  git repo: say so, ask the user for a project name, and use that
- MX = `~/.mx/<project>/` (Unix) or `%USERPROFILE%\.mx\<project>\` (Windows)
- Create `MX/<name>/` if it does not exist. If it cannot be created or
  written, print the full spec inline in your final message and tell the
  user it was not saved — never end silently

Create `MX/<name>/spec.md`.

Spec format:

```markdown
# <feature-name> — Spec

## What
<What is being built or changed — one paragraph>

## Why
<The problem it solves and why it matters>

## How
<The chosen approach, key design decisions, trade-offs accepted>

## Out of scope
<Explicitly list what this change does NOT cover>
```

### GATE — spec approval (human; mx-flow's GATE 1)

**Hard gate: nothing is implemented until this passes.** It stays human
even when invoked from an orchestrator.

Display the written spec in full, then stop and wait. Approved = the user
says so in words that name approval ("approved", "ok", "go", "ship it",
"yes"). Silence, a question, or a comment on the content is NOT approval.
A partial objection means: apply it, re-display, ask again.

If the user edits `spec.md` after approving, re-read it before Step 5 and,
if the chosen approach changed, re-run Step 5's ADR against the new
content.

---

## Step 5 — Record ADR

After the gate passes, write the ADR.

Read `references/adr-format.md` (located in the same directory as this
SKILL.md) and follow it.

Report: `ADR saved to ~/.mx/<project>/<name>/adr.md`

---

## Step 6 — Hand off

Once the design spec and ADR are saved, announce:

```
Design spec saved to ~/.mx/<project>/<name>/spec.md
ADR saved to ~/.mx/<project>/<name>/adr.md
Ready for /mx-flow — this will decompose the spec into tasks and continue the workflow.
```

Do not invoke mx-flow automatically. The user invokes it. When invoked
from an orchestrator, omit the `Ready for /mx-flow` line and just return
control.
