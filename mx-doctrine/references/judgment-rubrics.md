# Judgment rubrics — decisions externalized as checklists

> Shipped with mx-harness. Written 2026-07-07. Each rubric: trigger →
> procedure → one positive and one negative example. These encode judgment
> that smaller models tend to get wrong under pressure. When a rubric and
> your in-the-moment reasoning collide, **follow the rubric** — it exists
> because in-the-moment reasoning failed here before.
>
> Companion files: `model-dispatch.md` (tiers, counting rule),
> `delegation-templates.md` (prompts), `maintenance.md` (how to append
> lessons to this file).

## §1 When to escalate the model

Escalate (per `model-dispatch.md` §6) when ANY of:

- The same error survives two attempts — same or different approach; the
  counting rule is model-dispatch §6.
- The worker's explanation contradicts observable output (report says
  "test passes", test output shows FAIL).
- The output references APIs, files, or symbols that don't exist in the
  repo — hallucination is a capability ceiling, not a typo.
- The task is a *decision* with long-lived consequences (public API shape,
  schema, concurrency model) — decide at the strongest tier even if
  execution stays mid-tier.

Do NOT escalate when the failure is missing information — an unread spec,
an unstated constraint. Feed the information first: a stronger model with
the same blindfold fails the same way.

- ✅ A mid-tier agent twice "fixes" a flaky test by widening its timeout;
  escalate with both diffs + the flake output attached → the stronger model
  finds the unwaited goroutine. Right call: identical failure class twice,
  full trail attached.
- ❌ A first-draft cache-key layout "looks uninspired", so it's re-run at
  the strongest tier with the same one-line prompt. Wrong: no failure
  signal, no added information — spend the effort on a better prompt.

## §2 When "done" is actually done

Done means ALL of:

1. Every acceptance criterion from the original request is restated in the
   final report with per-item evidence (test output, file:line, read-back
   verdict).
2. The quality floor for this change type (§5) ran **for real** and its
   output is quoted.
3. Everything created or changed is listed by path; nothing exists only in
   the conversation.
4. Verification was mechanical or fresh-context, not self-review
   (`model-dispatch.md` §5).
5. Anything skipped, stubbed, or deferred is called out under an explicit
   **"Not done"** heading. An omission discovered later costs 10× the
   honesty now.

- ✅ "Criterion 1 (cache invalidation clears every shard): test
  `TestInvalidationClearsAllShards` added — fails before, passes after,
  output pasted. Criterion 2: full suite green, tail pasted. **Not done:**
  README update — needs a decision on where the config table lives."
- ❌ "I've implemented the retry logic and it should now handle the
  timeout case correctly." — no test run, no criteria restated; *should*
  is a confession.

## §3 When to stop and ask the user

Ask — with a concrete recommendation attached, never an open-ended
question — when ANY of:

- The action is irreversible or outward-facing: push to a shared branch,
  publish a PR the orchestrator didn't authorize, tag/release, delete >~50
  lines the session didn't write, any `--force`. (Exception:
  `git push --force-with-lease` executed by mx-pr Step 6 after its
  tree-invariant-guarded content check is pre-authorized by that skill.)
  (Exception: `git branch -D` executed by mx-flow Phase 8
  (`mx-flow/references/finish.md` 8.6) after 8.1's merge evidence holds —
  PR/MR state MERGED, or an empty `git diff origin/<base>..<branch>`, with
  no unpushed commits and a clean worktree.)
- Two instructions genuinely conflict and no precedence rule in the skill
  resolves it — surface the conflict, propose which side should win.
- The remaining work forks on a taste or scope choice the user hasn't
  made: two defensible API shapes; "fix here or in a follow-up PR".
- Cost exploded: the fix touches 3× the files the task implied.
- A skill's hard gate says so (mx-flow GATE 1 spec approval; mx-flow's
  3-iteration loop escalation; failing baseline in Phase 4.4).

Do NOT ask when the answer is derivable from the repo, the spec, or a
gate; when the choice is cheap to reverse (pick one, label it, move on);
or as reassurance — "shall I proceed?" on an already-authorized path is
noise. Orchestrated auto-proceed gates (mx-flow GATE 2/3/4) exist
precisely so you don't ask there.

- ✅ The only clean fix renames a public metric family (breaks dashboards).
  Stop: "Option A — rename, breaks 2 known panels; Option B — add a label,
  keeps the name, uglier queries. Recommend A. Which?" Outward-facing
  break → user's call.
- ❌ "The linter rejects this test filename, blocking commit. Should I
  rename it?" — the gate already answers this. Rename it, note it in the
  report.

## §4 Wrong-direction signals — change path, don't retry

Any TWO of these (or #1 alone) mean the approach is wrong. Retrying harder
is forbidden; back out and rethink or ask:

1. The candidate fix requires weakening a gate (canonical list — other
   files point here): `--no-verify`, a lint suppression,
   deleting/skipping a failing test, relaxing an assertion, widening a
   timeout. **In a TDD flow this includes rewriting the RED test to match
   broken behavior instead of fixing the code.**
2. Each retry fails somewhere NEW (whack-a-mole = fighting the design).
3. The diff keeps growing past the blast radius the task implied.
4. You're editing generated, vendored, or explicitly frozen code to make
   the change fit.
5. You can't state in one sentence why the fix works — only that tests
   pass now.

Procedure: revert to last green, write three lines — goal / why the
approach fails / next approach or the question to ask — then proceed at
the appropriate tier (`model-dispatch.md` §6).

- ✅ A dependency-boundary lint blocks an import from a public package;
  after one interface workaround also feels forced → read the signal: the
  logic belongs on the internal side of the boundary. Move it.
- ❌ A "no sleeps in tests" rule rejects `time.Sleep`, so attempt #2 hides
  the sleep behind a helper in a non-test file. That is signal #1 — the
  test needs a synchronization redesign, not a smuggled sleep.

## §5 Quality floor — minimum verification per change type

| Change type | Floor (run it for real, quote the output) |
|---|---|
| Any code change | The project's own gate: `make check`/`make test` if a Makefile defines it, else the package-manager test script, else the language default (`go test ./...`, `cargo test`, `pytest`, `dotnet test`). No gate findable → say exactly that in the report; never invent a command and never claim green without running. New behavior additionally requires the failing-test-first evidence (mx-flow Iron Law). |
| Spec / plan / PR body / docs | Fresh eyes before use: a human review gate counts (mx-flow GATE 1, interactive mx-pr Step 4); when no human will see it before it ships (auto-published PR body, orchestrated docs), a fresh-context read-back against explicit acceptance criteria (`model-dispatch.md` §5, item 2). Either way: every referenced path, command, and skill name checked to exist (`ls`, grep — don't assume). |
| Config (JSON/YAML) | Parse check (`jq empty`, `yq`, or the consuming tool's own validator), then exercise the config once and show the effect. |
| History rewrite (content check) | Tree-hash invariant compared before/after — already built into mx-pr's content check; never skip it. |
| Cross-language / cross-repo change | Run the consuming side, not just the producing side. |

- ✅ Config change to a CI file: `yq` parse passes AND the changed job was
  triggered once with its run link quoted — both shown in the report.
- ❌ "The YAML looks well-formed and the paths appear correct" — no parser
  run, no execution, appearance is not evidence.

## §6 Honest limits — what process cannot buy

Decomposition, fresh-context verification, and multi-candidate judging
raise *execution* quality to near-frontier. They do NOT compensate for
**taste and ambiguity**: naming a public API, choosing between two clean
designs, judging whether prose "reads well", sensing that a spec smells
wrong. A weak model following this pack perfectly will still be mediocre
at those. When such a call arises:

- **Cheap to reverse** → pick one, label it — "taste call: chose X because
  Y; cheap to reverse" — and move on.
- **Expensive** (public API, schema, spec direction) → generate 2–3 named
  options with trade-offs and give them to the user (mx-brainstorm's
  Step 2 shape), or run a strongest-tier judge over independent candidates
  and present the winner as a **recommendation**, not a decision.
- **Genuinely beyond the harness** → say exactly that: "this is a taste
  judgment this setup can't make reliably." That sentence is worth more
  than a confident coin-flip. A confident wrong answer is the only
  unrecoverable output this system produces.
