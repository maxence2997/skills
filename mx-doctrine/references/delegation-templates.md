# Delegation templates — fill in the blanks, don't freestyle

> Shipped with mx-harness. Written 2026-07-07. Copy the template, replace
> every `{{...}}`, delete unused optional lines. Rule of thumb: **if you
> can't fill in ACCEPTANCE, you don't understand the task yet** — stop and
> clarify it for yourself first.
>
> Tier suggestions follow `model-dispatch.md` §4. The Agent tool has no
> effort parameter — tier choice IS the effort knob. In a harness without a
> subagent tool (`model-dispatch.md` §0), these templates still earn their
> keep as self-checklists: fill one in, then execute it yourself.

**Shared REPORT block** — the single canonical report contract. Paste it
into every prompt with wording unchanged EXCEPT: fill its two blanks
(`{{output_dir}}`, `{{slug}}`) with a real absolute path and a real slug:

```
REPORT FORMAT — return exactly:
1. VERDICT: one sentence answering the goal.
2. FINDINGS/RESULTS: bullet list, each with file:line where applicable.
3. EVIDENCE: quoted output or ±5-line excerpts only.
4. NOT COVERED: what you did not check/do, and why.
If total output would exceed ~50 lines, write the full version to
{{output_dir}}/{{slug}}.md and return the path + a 10-line summary.
Your final message is data for the orchestrator, not prose for a human.
```

For `{{output_dir}}`, prefer the active feature's temp dir
(`<repo-root>/.mx/<name>/tmp/`) when one exists; otherwise a session
scratchpad or OS temp dir.

---

## 1. SEARCH  (type: `Explore`; model: mid — small only for a literal-string hunt)

```
GOAL: Find {{what}} in {{repo/dir}}. Motivation: {{why — what decision this feeds}}.
SCOPE: Look in {{paths/packages}}; also check {{naming variants / conventions}}.
Search breadth: {{"medium" (targeted lookup, named packages) | "very
thorough" (a missed hit is costly — sweep the whole repo incl. tests and
generated code)}}.
MUST ANSWER:
- {{question 1, phrased so the answer is a location or a yes/no + location}}
- {{question 2}}
ACCEPTANCE:
- Every claim carries file:line.
- If not found, list WHERE you looked (paths + patterns tried) — "not
  found" without a search trail is a failed task.
[REPORT block]
```

## 2. IMPLEMENT  (type: `general-purpose` or default; model: mid — strongest if design judgment is embedded)

```
GOAL: {{feature/fix in one sentence}}. Motivation: {{user-visible why}}.
CONTEXT: Read first: {{files/specs the agent must read, with paths}}.
Constraints that override your instincts: {{repo hard rules — e.g. failing
test first, comment policy, sealed module boundaries; cite the file that
defines them}}.
DO:
1. Write the failing test: {{test name/behavior}}.
2. Implement minimally in {{package/file}}.
3. Run {{gate command, e.g. `make check`}} until green.
DO NOT: {{explicit non-goals — files not to touch, APIs not to change}}.
ACCEPTANCE:
- Failing-test-first shown (test output before AND after).
- {{gate command}} green — paste the tail.
- Diff confined to {{expected blast radius}}; list every changed file.
[REPORT block]
```

## 3. REFACTOR  (type: `general-purpose` or default; model: mid for mechanical; strongest to DESIGN the recipe once; small to stamp a proven recipe)

```
GOAL: {{refactor in one sentence}}. Motivation: {{debt being paid}}.
INVARIANT (the contract): behavior must not change. Evidence required:
{{tests that must stay green / byte-identical output / bench numbers}}.
RECIPE: {{exact transformation, ideally from one already-done example:
"in X.go we changed A→B like <example>; apply the same to: <file list>"}}.
DO NOT: rename/move anything outside the recipe; "improve" adjacent code;
touch {{frozen paths}}.
ACCEPTANCE:
- {{gate command}} green before AND after — paste both tails.
- Zero semantic diff outside the recipe (explain any hunk that looks like
  one).
[REPORT block]
```

## 4. RESEARCH  (type: `general-purpose`; model: mid — strongest if the conclusion drives a design decision)

```
GOAL: Answer: {{question}}. Motivation: {{decision this feeds}}.
SOURCES: Start with {{docs/URLs/packages}}; prefer primary sources
(official docs, source code) over blogs. Note the publication date of
anything cited.
MUST ANSWER:
- {{sub-question 1}}
- {{sub-question 2}}
MUST DISTINGUISH: verified fact (with source) / inference (labeled) /
unknown (labeled — do NOT fill gaps with plausible guesses).
ACCEPTANCE:
- Each MUST-ANSWER gets: answer + source + confidence (high/med/low).
- Contradictions between sources are surfaced, not silently resolved.
[REPORT block]
```

## 5. REVIEW  (type: `general-purpose`; model: strongest for risky diffs, mid for routine; NEVER the agent that wrote the change)

```
GOAL: Adversarial review of {{diff/branch/files}}. Motivation: {{what
breaks if this is wrong}}. You did not write this code; your job is to
find what's wrong with it, not to approve it.
READ FIRST: {{repo CLAUDE.md / spec / the PR description}}.
CHECK, in order:
1. Correctness: {{project-specific invariants}}; race conditions;
   swallowed errors; broken error paths.
2. Gate compliance: {{failing-test-first evidence, comment policy,
   project lint rules}}.
3. Blast radius: does the diff touch anything the goal doesn't require?
4. The tests themselves: do they bite? Would a mutation survive them?
ACCEPTANCE:
- Every finding: severity (P0 blocker / P1 required / P2 suggestion —
  generic template; for mx-* reviews the scale is P0–P3 per
  mx-review-triage/references/SEVERITY.md) + file:line + the concrete
  failure scenario (inputs → wrong outcome).
- If you find nothing, list the 3 riskiest spots you cleared and how —
  "LGTM" with no cleared-risk list is a failed review.
[REPORT block]
```

> For multi-perspective review, don't hand-roll it here — invoke
> `/mx-team-review`, which already dispatches three perspectives plus a
> synthesizer.

## 6. TDD TASK  (type: `general-purpose`; model: mid by default, strongest when the task touches concurrency, auth/security, data migration or a public API; ONE at a time, never parallel — mx-flow Phase 5a delegated mode)

```
GOAL: Complete ONE TDD task in an existing worktree.
TASK (verbatim from plan.md): {{What / Test / Files block}}.
Motivation: {{the spec sentence this task traces to}}.
CONTEXT: Work ONLY inside {{absolute worktree path}}. Test runner:
{{runner command}}. Files this task is expected to touch (from the plan):
{{Files line, verbatim}}.
Read the relevant existing code before writing anything.
HARD RULES (violating any = failed task):
1. Iron Law — write the failing test FIRST, run the runner, and OBSERVE
   the failure output before any production code exists.
2. Vertical slices — one test → its minimal implementation → next test.
   Never batch tests up front.
3. Minimal GREEN — only enough code to pass the current test; no
   speculative features, abstractions, or config.
4. Refactor only after GREEN; re-run tests after each refactor step.
5. Never weaken a gate to get green. Canonical list of what counts:
   {{absolute path to mx-doctrine/references/judgment-rubrics.md}} → §4
   signal 1.
6. Comment policy — WHY-comments only, ≤3 lines, no WHAT-comments.
   Canonical: {{absolute path to mx-team-review/references/principles.md}}
   → P2.
7. Do NOT commit, do NOT touch plan.md, do NOT edit files
   outside this task's blast radius.
ACCEPTANCE:
- RED shown: paste the failing-test output (before any implementation).
- GREEN shown: paste the passing output AND the tail of the full suite.
- Every changed file listed; diff confined to the task's Files — explain
  any file beyond them.
[REPORT block]
```

> Parent-side contract: the orchestrator re-runs the full suite itself and
> reads the diff before accepting — the executor's pasted output is a
> claim, not evidence (`model-dispatch.md` §5). The parent owns plan
> bookkeeping and `/mx-commit --auto`.

---

## Read-back verification stub  (pair with any of the above; fresh agent; model: mid)

```
GOAL: Verify the deliverable at {{path(s)}} against the criteria below.
You did not produce it; do not assume good faith — check.
CRITERIA:
- {{criterion 1, mechanically checkable}}
- {{criterion 2}}
For each: PASS/FAIL + one line of quoted evidence (or the missing thing).
Also flag: internal contradictions; references to paths/commands/tools/
skills that don't exist (verify with ls / grep / --help); statements a
less-capable model could misread. Return PASS only if every criterion
passes.
[REPORT block]
```

Anti-rubber-stamp rule: acceptance criteria must be mechanically checkable,
and every PASS needs quoted evidence. A verifier that returns zero findings
must list the riskiest spots it cleared. If you can falsify its PASS with
one command, that verification run was worthless — redo it (counts as a
failed round, `model-dispatch.md` §6).
