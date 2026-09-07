# mx-harness diagnosis — token leaks, focus risks, error sources

> Measured 2026-07-07 by a Fable 5 session against commit `cb6f850`. Line
> numbers refer to the files at that commit (retrievable via
> `git show cb6f850:<path>`); the 2026-07-07 restructure moved most of them.
> This file is the rationale record for that restructure. The fixes it
> prescribes live in: `model-dispatch.md`, `judgment-rubrics.md`,
> `delegation-templates.md` (all in this directory) and the rewritten
> SKILL.md files. Re-audit procedure at the bottom.

## Scope

The diagnosis covers the mx-harness skill suite as installed on *any*
machine (Claude Code, Codex, Copilot, Cursor) and run by *any* model tier —
not one specific user environment. Every number below was measured, not
estimated.

---

## Part 1 — Top 3 token leaks

### Leak 1: frontmatter descriptions carry implementation detail into every session

- **What**: every installed skill's `description:` is loaded into the system
  prompt of **every session** — including the thousands of sessions that
  never invoke the skill. Measured total across the 7 SKILL.md files:
  **4,111 bytes / 578 words** (~900 tokens standing cost per session, per
  machine). mx-flow alone: 1,200 bytes / 166 words, most of it narrating
  internals ("cherry-pick conflicts triage to trivial…", "tree-invariant
  guarded") that no router needs in order to decide *when to invoke*.
- **Why it hurts twice**: beyond tokens, a long description dilutes the
  trigger signal — a weak model choosing between 50+ installed skills
  matches on the first lines; burying "use when starting a new feature"
  under 140 words of architecture lowers invocation accuracy.
- **Fix (applied 2026-07-07)**: description budget = **≤ 50 words**, and it
  answers only three things: what the skill does (one sentence), when to
  trigger it, usage syntax if subcommands exist. All "how it works" moved to
  the SKILL.md body, which loads only on invocation.

### Leak 2: the content check existed twice, ~71% verbatim

- **What**: the autonomous content check (cancellation cleanup + squash-into-
  parent, tree-invariant guarded) appeared in full in `mx-pr` Step 2
  (lines 78–205, 128 lines) **and** in `mx-flow` Phase 6.5 (lines 806–932,
  127 lines) — ~90 of those lines byte-identical. A full `/mx-flow` run
  loads both copies (its own body, then mx-pr's at Phase 7).
- **Worse than tokens**: two normative copies of the same procedure WILL
  drift, and the next model cannot tell which is canonical. (The gate
  tables inside mx-flow had already drifted — see Focus 3.)
- **Fix (applied 2026-07-07)**: single canonical file
  `mx-pr/references/content-check.md` (mx-pr owns it because mx-pr must work
  standalone). Both SKILL.md files now hold a ≤10-line summary plus a
  pointer, read only when the step actually runs.

### Leak 3: branch-only procedure loaded on every invocation

- **What**: SKILL.md loads in full at invocation, but large blocks were
  needed only on branches most invocations never reach. mx-flow (1,075
  lines total): 5a-parallel details (~120 lines — only when a parallel
  batch actually forms), Phase 8 finish (~95 lines — only on
  `/mx-flow finish`), content check (~130 lines — only at Phase 6.5).
  mx-team-review (462 lines): four embedded reviewer prompts (~200 lines)
  needed only at Step 4.
- **Fix (applied 2026-07-07)** — the extraction rule, reusable for future
  edits: move a block to `references/` iff ALL of:
  (a) it exceeds ~40 lines,
  (b) it is needed only in one phase/branch that not every invocation
      reaches,
  (c) it is not a hard guard, gate rule, or safety limit.
  Guards and gates stay at the **top** of SKILL.md (see Focus 2). When
  extracting, SKILL.md keeps: a 1–3 line summary, the instruction to read
  the reference file *on entering that branch*, and a fallback for partial
  installs ("file missing → say so and <degraded behavior>; do not silently
  skip").
- **Counter-pressure**: do NOT extract for its own sake. Every extraction
  costs one Read round-trip and one risk that a weak model skips the read.
  A 20-line always-needed block belongs inline.

---

## Part 2 — Top 3 focus risks

### Focus 1: orchestrator vs sub-skill giving the model two direct orders

- **What**: mx-flow declares GATE 3/GATE 4 auto-proceed ("execute
  immediately", "do not wait for confirmation"), while the sub-skills it
  invokes command the opposite in their own text: mx-review-triage Step 5
  "**Do not make any code changes yet. Wait for user approval.**"; mx-pr
  Steps 4–5 "**Wait for the user to choose. Do not proceed
  automatically.**" A model running mx-flow Phase 5b/7 holds both files in
  context and must guess which order wins. Strong models infer the
  orchestrator wins; weak models flip-flop or stall.
- **Fix (applied 2026-07-07)**: a uniform **orchestrated-mode contract**,
  stated once near the top of each sub-skill with interactive pauses
  (mx-team-review, mx-review-triage, mx-pr): "When invoked from an
  orchestrator that declares auto-proceed for a gate, the orchestrator's
  gate table overrides this skill's pauses — still print everything you
  would have shown." The orchestrator (mx-flow) states the same contract
  from its side. Two deliberate exceptions: mx-commit is orchestrated via
  its `--auto` flag rather than a contract section, and mx-brainstorm's
  only pause is the spec gate, which stays human (GATE 1). One rule, both
  directions, no inference.

### Focus 2: load-bearing rules buried mid-file

- **What**: mx-flow's Iron Law (no production code without a failing test)
  sat at line 609; the two Hard Guards at line 456; the loop safety limit at
  line 723 — all *after* hundreds of lines of per-phase detail. Models
  weight early context heavily; a rule first seen 600 lines in competes
  with everything read before it.
- **Fix (applied 2026-07-07)**: every SKILL.md now front-loads, in order:
  trigger → hard guards / non-negotiables → gate table (once) → phase
  skeleton. Deep procedure follows. Rule of thumb: **anything whose
  violation is called "workflow failure" must appear in the first 60
  lines.**

### Focus 3: duplicated normative text that had already drifted

- **What**: mx-flow carried its gate table twice (lines 43–48 and 85–90)
  with wording already diverged (GATE 1: "requires explicit approval" vs
  "Discuss and adjust until user confirms"). mx-brainstorm carried the
  "Side requests" section twice verbatim (Step 1 and Step 3). Duplication
  inside one file is worse than across files: the model reads both, notices
  the difference, and burns attention reconciling them.
- **Fix (applied 2026-07-07)**: one statement per rule; later mentions
  point back ("per the gate table above"). Maintenance rule (see
  `maintenance.md` §2 rule 4): before adding any rule text, grep the
  repo for the same concept; if it exists, point at it instead of restating.

---

## Part 3 — Top 3 error sources (for weaker models especially)

### Error 1: references to things that do not exist

Weak models follow pointers literally; each dead pointer is a live
misdirection. Found and fixed 2026-07-07:

| Where (at cb6f850) | Said | Reality |
|---|---|---|
| mx-flow line 794 | "Only if 5.1 and 5.2 both pass" | means sections 6.1/6.2 (renumbering leftover) |
| mx-pr description | "Use after mx-verify passes" | no `mx-verify` skill exists (historic name; it is mx-flow Phase 6) |
| mx-commit line 30 | "orchestrating skill (mx-tdd, mx-flow)" | no `mx-tdd` skill exists |
| mx-team-review usage | `/team-review [diff-spec]` | the skill installs as `mx-team-review`; `/team-review` may not resolve |

**Rule going forward** (in `maintenance.md`): every skill/file/section
reference you write must be checked against the repo in the same session
(`ls`, grep). Renaming or renumbering anything → grep the whole repo for
the old name before finishing.

### Error 2: no failure ladder — the happy path was fully specified, failure was not

- **What**: the skills specified success paths in detail and a few local
  fallbacks (scope-analyzer failure, cherry-pick conflicts), but nothing
  said what to do when *the model itself keeps failing*: no retry cap in
  the TDD cycle (a weak model can loop RED→wrong-GREEN forever), no
  model-escalation guidance, and outside mx-commit no prohibition on the
  classic weak-model escape hatch — deleting/skipping the failing test,
  relaxing the assertion, `--no-verify`.
- **Fix (applied 2026-07-07)**: `model-dispatch.md` (escalation ladder,
  2-failed-rounds cap) + `judgment-rubrics.md` (wrong-direction signals,
  forbidden fixes), routed from mx-flow's TDD loop and hard guards. The
  gate-bypass prohibition is now a hard guard in mx-flow itself, not only
  in mx-commit.

### Error 3: self-verification at every checkpoint

- **What**: the same context that wrote the code ticks the exit-condition
  checklist; the spec, plan, and PR draft are never read back by fresh
  eyes. The review loop (mx-team-review) is genuinely independent in
  subagent mode, but in single-pass fallback (Step 4B) all "perspectives"
  share the author's context — useful, weaker than it looks; treat its
  PASS accordingly. Mechanical checks (test suite actually run, tree-hash
  invariant) are the strongest verifications in the suite — that pattern
  needed extending, not inventing.
- **Fix (applied 2026-07-07)**: verification contract in
  `model-dispatch.md` §5: mechanical evidence (tests run with output shown,
  tree-hash compare) counts; prose deliverables (spec/plan/PR body) get a
  fresh-context read-back agent when a subagent tool exists; where no
  subagent tool exists, the honest fallback is to say the check was
  single-context.

---

## Additional findings (not top-3, fixed or flagged in the same pass)

- `allowed-tools` frontmatter: verified against official docs 2026-07-07 —
  it is a **permission pre-grant, not a whitelist** (unlisted tools stay
  callable, with prompts). So mx-flow lacking Edit/Write was not a
  functional bug, but it meant permission interruptions mid-TDD; Edit/Write
  added where the procedure edits files. Related verified facts: the
  subagent tool is named `Agent` since Claude Code v2.1.63 (`Task` remains
  a valid alias); skill descriptions are truncated at 1,536 characters in
  the always-loaded listing (mx-flow's 1,200 bytes was near the cap);
  `${CLAUDE_SKILL_DIR}` is the documented substitution for the directory
  containing the running SKILL.md — the sibling-skill path convention in
  the rewritten files builds on it.
- mx-team-review dispatches reviewers at `model: "sonnet"` — reasonable,
  but with no escalation note for when the diff is high-risk; now routed
  to `model-dispatch.md`.
- README drift: minimal (verified by sweep 2026-07-07). Keep it that way
  via the three-places-sync rule in the repo CLAUDE.md.
- (2026-07-15) mx-flow's 5a-parallel batch execution was **removed**
  (observed slower than parent-serial: only model time overlaps, machine
  costs multiply, failure paths re-ran serially anyway — lesson in
  `model-dispatch.md` §2). `parallel-dispatch.md` no longer exists;
  Leak 3's ~120-line 5a-parallel figure above is a historical example
  from before the removal. Phase 3 was reframed the same day: scope
  analysis now runs inline in the parent and audits the plan's task
  split (ordering, granularity, overlap) instead of computing
  parallel-dispatch metadata.
- (2026-08-19) `install.sh` installs from the **remote main tarball**, not
  the local checkout — and on a dev machine where `~/.claude/skills/mx-*`
  are symlinks into the repo, an update copies the remote files *through
  the symlinks into the repo working tree*. Running it with unpushed
  commits reverted the working tree to remote main (recovered via
  `git checkout` — commits were unaffected). Rule: **push before running
  `install.sh`**; on symlinked installs the script is only needed for
  real-directory targets (e.g. `~/.codex/skills`).
- (2026-09-06) Full-suite re-audit against Provencher's "Rethinking skills
  and prompts for GPT-6 Astra" (2026-09-04): 83 findings; report, data and
  raw agent reports at `~/.mx/mx-harness/skill-audit-2026-09-06/` on the
  owner's machine. Lessons: (1) undeclared pauses — mx-flow had 19
  "wait/ask" points with only 4 in its gate table; every pause outside the
  gate table is now evidence-gated or removed, and the pause inventory grep
  below is part of the re-audit. (2) producer/consumer contracts drift
  silently — mx-status Stage 6 read a `PR:` line nobody wrote; reviewer
  severities (error/warning/suggestion) had no mapping to triage's P0–P3 —
  the mapping now lives in `mx-review-triage/references/SEVERITY.md`.
  (3) three executable defects hid in fenced bash (mx-pr base-branch
  resolution yielding an empty range; `git rebase --abort && git reset`
  short-circuit in content-check Pass 2; an unguarded `*.patch` glob) —
  fenced bash blocks are now syntax-checked by the re-audit script.

## Honest limits of this diagnosis

- Byte/word counts were measured on 2026-07-07; they will drift. The
  *rules* (description budget, extraction rule, one-statement-per-rule)
  matter more than the snapshot numbers.
- Claude Code behavior (descriptions always loaded; `allowed-tools`
  semantics) was verified only by direct observation in one session, not
  against a versioned spec. Other harnesses (Codex, Copilot, Cursor) were
  not measured; the skills must keep degrading gracefully there
  (single-pass fallbacks, no hard dependency on subagent tools).
- This diagnosis cannot see how *users other than the author* invoke these
  skills; trigger-phrase tuning is based on the author's usage.

## 60-second re-audit procedure

Run from the repo root when the suite feels bloated or misfiring:

```bash
# 1. Description budget (target: ≤ ~350 bytes / 50 words each)
for f in */SKILL.md; do desc=$(awk '/^description: >/{flag=1;next}/^[a-z-]+:/{flag=0}flag' "$f"); \
  printf '%-28s %4d bytes %3d words\n' "$f" "$(echo "$desc"|wc -c)" "$(echo "$desc"|wc -w)"; done

# 2. SKILL.md size (investigate anything > ~450 lines: apply the extraction rule)
wc -l */SKILL.md | sort -rn | head

# 3. Dead pointers (any hit = fix now)
grep -rn "mx-verify\|mx-tdd\|/team-review " */SKILL.md */README.md README.md

# 4. Duplicated normative blocks (spot-check the known-risky pair):
#    mx-flow §6.5 must stay a short router. More than ~25 lines, or any
#    "Pass 1"/"Pass 2" procedure text inline, means the duplication is
#    back — re-extract per Leak 3.
awk '/^### 6.5/{f=1} f{print; c++} f&&/^### [^6]|^## /{if(c>1)exit}' mx-flow/SKILL.md | wc -l
grep -n 'inverse pairs\|autosquash' mx-flow/SKILL.md   # any hit besides a pointer = duplication returned

# 5. Pause inventory. Every hit must be one of: a row in a gate table, an
#    evidence-gated pause, or a justified irreversible/outward-facing stop.
#    Anything else is a reflexive pause — remove it or gate it on evidence.
grep -rn -iE "wait for the user|do not proceed|ask the user|wait for user" \
  */SKILL.md */references/*.md

# 6. Fenced bash blocks parse. Placeholder templates containing <...> are
#    EXPECTED to fail — list them, do not treat them as defects.
T=$(mktemp -d)
for f in */SKILL.md */references/*.md; do b=$(echo "$f" | tr '/.' '__'); \
  awk -v p="$T/$b" '/^```bash$/{n++;o=p"-"n".sh";next} /^```$/{o="";next} o{print > o}' "$f"; done
for s in "$T"/*.sh; do bash -n "$s" 2>/dev/null || \
  { echo "--- ${s#$T/}"; head -3 "$s"; }; done
rm -rf "$T"
```

Findings go through `maintenance.md` (same directory) — fix, then update
this file's "Additional findings" with a dated line.
