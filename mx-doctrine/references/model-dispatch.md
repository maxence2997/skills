# Model dispatch — who does what, at which tier

> Shipped with mx-harness. Written 2026-07-07; environment facts in §1 were
> verified against Claude Code docs and live tool schemas that day. **If your
> session's tool schema disagrees with §1, trust the schema, then update this
> file** (procedure: `maintenance.md`, same directory).
>
> Referenced by the mx-* SKILL.md files wherever they spawn sub-agents.
> Companion files: `judgment-rubrics.md` (when to escalate/stop/ask),
> `delegation-templates.md` (fill-in-the-blank prompts).

## §0 First: which kind of harness are you in?

Check your own tool schema for a subagent-spawning tool (`Agent`, or its
legacy alias `Task`).

- **Present** → you are an orchestrator-capable harness (Claude Code).
  Everything below applies.
- **Absent** → you are a single-context harness (Codex CLI, Copilot,
  Cursor) **or you are yourself a subagent**. Every delegation rule in this
  file is void for you: do the work inline, use each skill's single-pass
  fallback where one is defined (e.g. mx-team-review Step 4B), label any
  self-checked verification as single-context (§5), and keep your final
  report terse.

Two spellings differ across harnesses; neither changes the instruction:

- Sub-skill invocations in these files are written as `/mx-<name>`
  (Claude Code's slash form). On Codex the explicit trigger is
  `$mx-<name>`; treat either spelling as "invoke that skill now", and
  where no explicit invocation mechanism exists, follow the named skill's
  SKILL.md inline.
- Path convention (canonical statement: `mx-doctrine/SKILL.md` → "How
  mx-* skills reference these files"): bare `references/<file>` for
  same-directory reads; `${CLAUDE_SKILL_DIR}/../<skill>/references/<file>`
  plus a missing-file fallback for cross-skill reads.

## §1 Verified environment facts (Claude Code, 2026-07-07)

- Subagents spawn via the **Agent** tool (renamed from `Task` in v2.1.63;
  `Task` still works as an alias). Common types: `Explore` (read-only
  search — cannot edit), `Plan` (read-only architecture planning),
  `general-purpose` (full tools), plus a default catch-all. Check the
  types listed in your own session; do not assume this list.
- Agent accepts a **`model` override**. Tiers available 2026-07-07:
  `haiku` | `sonnet` | `opus` (a higher limited-availability tier may
  appear in some environments — never depend on it). Model names WILL
  drift; read the enum in your schema, map by tier: *small/cheap*,
  *mid/default*, *strongest available*.
- The Agent tool has **no effort parameter** — tier choice IS the effort
  knob. (Per-agent effort exists only inside Claude Code's opt-in Workflow
  orchestration tool; mx-* skills do not require it.)
- Independent Agent calls placed in ONE message run in parallel — that is
  how mx-team-review's three reviewers get their concurrency.
- `allowed-tools` in SKILL.md frontmatter is a **permission pre-grant, not
  a whitelist**: unlisted tools remain callable (with permission prompts).
- `${CLAUDE_SKILL_DIR}` expands to the directory containing the running
  SKILL.md — the base for `references/` and sibling-skill paths.

## §2 Commander doesn't descend

The orchestrating conversation's context is the scarcest resource in the
session. It is for decisions, small load-bearing edits, and talking to the
user — protect it.

**Delegate (don't do inline):**

| Work | Route to |
|---|---|
| Reading >3 files or >~400 lines to answer a question | `Explore` |
| Repo-wide grep/sweep with unpredictable hit count | `Explore` |
| Web research beyond one page | `general-purpose` — synthesis only comes back |
| Batch mechanical edits across >5 files | `general-purpose` with an exact recipe |
| Log/CI output analysis >200 lines | any worker — the 5-line verdict comes back |
| Verification of your own deliverable | fresh-context agent (§5) — never yourself |

**Do inline (delegation would be waste):**
- A single lookup in a file you can name.
- The core edit the whole task is about — the judgment IS the work.
- Anything where writing the delegation prompt costs more than doing it.
- Reading back subagent reports; talking to the user.
- (2026-07-15, from mx-flow Phase 3 scope analysis running slower via
  sub-agent): analysis whose inputs are already in your context — a
  sub-agent must rebuild the spec/plan/repo picture from disk, and the
  round-trips cost more wall-clock than the inference. Delegate analysis
  only when it saves parent context or buys real parallelism.
  ✅ scope the plan you just wrote, inline / ❌ spawn Explore to re-read
  the spec+plan you wrote one phase earlier
- (2026-07-15, from removing mx-flow's 5a-parallel batch execution):
  parallel sub-agents overlap model time only — machine costs multiply
  instead (per-worktree setup, full test suites contending for the same
  cores), and execution failure paths (merge conflicts, integration
  failures) fall back to serial re-runs that turn the parallel attempt
  into pure overhead. Parallel fan-out pays for read-only work
  (reviewers, searches); execution belongs serial in the warm parent.
  ✅ mx-team-review's three read-only reviewers in one message / ❌ three
  TDD task agents in three worktrees, each running the full suite
- (2026-08-19, from mx-flow TDD execution under a premium main loop):
  who types during execution is a speed/cost tradeoff the user owns, not
  a rule. Inline in the parent is fastest; a serial executor sub-agent
  per task (tier per §4) is cheaper when the main loop sits above the
  strongest dispatchable tier. mx-flow asks at GATE 1 and records the
  choice — recommend delegation on a tier gap, but the user's pick wins.
  Serial either way; parallel execution stays removed.
  ✅ ask once at GATE 1, then one `opus` executor per task / ❌ silently
  hard-coding either mode because a heuristic says so

## §3 Every delegation carries three things

1. **Goal + motivation** — what and why, so the agent resolves ambiguity in
   the right direction instead of guessing.
2. **Acceptance criteria** — enumerable checks the agent must satisfy and
   self-report against, one by one.
3. **Report format** — exactly what to return.

The report contract (canonical block in `delegation-templates.md`, top):
conclusions + `file:line` only; quoted excerpts capped at ±5 lines; any
output beyond ~50 lines goes to a file, and the agent returns the path plus
a ≤10-line summary. A subagent's final message is data for the
orchestrator, not prose for a human.

## §4 Routing table

Default worker is the **mid tier (`sonnet`)**. Escalate on signal (§6), not
on vibes. Set `model` explicitly on every Agent call; omitting it inherits
the main-loop model — do that only deliberately, not as a shortcut.

| Tier | Route here | Never route here |
|---|---|---|
| small (`haiku`) | Batch-apply of an exact, already-proven recipe (rename sweep, import fix); trivial lookups whose answer gets independently verified | Anything needing repo-idiom judgment, debugging, API design |
| mid (`sonnet`) | Searches (Explore), well-specified implementation where the failing test already exists, first-pass reviews, read-back verification, research summarization | Ambiguous design work; a subtask that already failed twice at this tier (§6) |
| strongest (`opus`) | Design/architecture decisions, gnarly debugging, adversarial review of risky diffs, spec writing, second opinions on high-risk judgment, anything mid tier failed at twice | Mechanical bulk work (pure waste) |

**Where the mx-* skills dispatch (defaults, override on signal):**

| Dispatch site | Type / tier |
|---|---|
| mx-flow Phase 3 scope analysis | inline in the parent (2026-07-15, see §2 do-inline list); `Explore` mid only as the context-loss escape hatch |
| mx-flow Phase 5a TDD execution | user's choice at GATE 1 — inline, or one serial `general-purpose` executor per task (mid for S, strongest for M/L/unknown); recommend delegation when the main loop is above the strongest dispatchable tier; escalation per §6 with the parent as the tier above strongest — the §6 absolute cap always wins |
| mx-team-review reviewers ×3 | mid |
| mx-team-review tech-lead synthesizer | mid; strongest when the diff touches concurrency, auth/security, data migration, or public API |
| Read-back verification (any skill) | mid, fresh context |
| Escalation target after two failed rounds | strongest, with the full failure trail |

## §5 Verification is never self-verification

The context that produced a change may not be the one that approves it.
Strength order — use the strongest available:

1. **Mechanical evidence** (strongest): the test suite actually run with
   output shown; the tree-hash invariant compared; `jq empty` on JSON.
   "It should pass" is not a result. Tests not runnable → say so explicitly.
2. **Fresh-context read-back**: for prose deliverables (spec, plan, PR
   body, docs), spawn a fresh agent with the acceptance criteria; it reads
   the file cold and returns PASS/FAIL per criterion, each with one line of
   quoted evidence. FAIL → fix → re-verify (counts as a round, §6).
3. **Second opinion on high-risk judgment** (irreversible ops, public API
   shape, schema, concurrency model): an independent agent at the strongest
   tier prompted to **REFUTE** your conclusion — or 2–3 candidate solutions
   plus a judge agent choosing with reasons. Skeptic can't refute with
   specifics → proceed. Skeptic refutes → treat as a failed round.
4. **Single-context self-check** (weakest — only when §0 says no subagent
   tool exists): re-read your own output against the criteria and **label
   the result** "self-checked, single-context" in the report. Never present
   it as independent verification.

## §6 Escalation / de-escalation ladder

**Counting rule (canonical — every other file defers here):** a *round* =
one attempt whose verification failed. Rounds count **per subtask at a
given tier, regardless of approach** — switching approach does NOT reset
the count. Budgets: small tier 1 round, mid 2, strongest 2. Absolute cap:
**4 failed rounds on one subtask across all tiers → stop and ask the
user.** The absolute cap always wins over per-tier budgets: a subtask that
already burned 3 rounds at lower tiers gets only 1 round at the strongest
tier before stopping.

- **Small tier errs once** → redo at mid immediately. No second attempt.
- **Mid tier fails the same subtask twice** → escalate to strongest **with
  the full failure trail**: what was tried, exact diffs/prompts, exact
  error output. Escalating without the trail wastes the stronger model —
  it will repeat attempt #1.
- **Strongest tier fails twice** → no longer a capability problem. Stop.
  Apply `judgment-rubrics.md` §4 (wrong-direction signals): change the
  approach or ask the user with concrete options.
- **De-escalate after solving**: when a hard instance cracks, extract the
  recipe (exact steps, exact pattern) and batch-apply the remaining
  instances at the small/mid tier. Don't keep paying top-tier prices for
  stamped-out work.
- A retry only counts as *new information* (not a burned round) when it
  feeds the agent something it demonstrably lacked — an unread spec, a
  missing constraint — not a rephrased prompt.

## §7 Cost discipline

Escalation is cheap insurance on load-bearing work and pure waste on
mechanical work. In doubt between mid and strongest for a *decision* →
take strongest. In doubt between mid and small for *execution* → take mid.
Never run parallel agents just to look thorough: each must have a distinct
job and a distinct report you will actually read.
