---
name: mx-pr
description: >
  Draft a pull request from the feature spec and git log, run an autonomous
  commit-history cleanup (content check), then publish to GitHub or GitLab
  (Bitbucket experimental) — or hand off. Use when a feature branch is ready
  for PR, standalone or from mx-flow. Usage: /mx-pr [name]
author: Maxence Yang
github: https://github.com/maxence2997/mx-harness
source: https://github.com/maxence2997/mx-harness/tree/main/mx-pr
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
---

# mx-pr

## Trigger

```
/mx-pr <name>   ← draft PR for named feature
/mx-pr          ← infer from active spec or ask
```

## Orchestrated mode

This skill has interactive pauses (Steps 4, 5 and 6). **When invoked from
an orchestrator that declares auto-proceed for its PR gate (e.g. mx-flow
GATE 4), the orchestrator's gate table overrides those pauses**: still
display everything you would have shown, but proceed without waiting —
pause only if you cannot determine how to proceed (no remote, ambiguous
platform, missing credentials). "Cannot determine" means the command would
fail or target the wrong repo — not that you would like a second opinion.
If `git remote -v` names exactly one host, that is the platform; do not
ask. When invoked directly by the user, the pauses apply as written.

Step 6 publishes. That is the irreversible step: under auto-proceed,
publish without asking, but say what you are about to push and to which
base before you run it.

Because auto-proceed removes the human review of the draft, add one check
in its place: if a subagent tool (Agent/Task) is available, spawn a fresh
read-back agent on the draft before Step 6 — criteria: every factual claim
traces to spec.md or the git log; every referenced issue number exists;
the body names no local-only files (Step 3's committed-files-only rule).
Fix findings before pushing. If no subagent tool exists, re-check the
draft yourself against those criteria and label the result "self-checked,
single-context" in the output.

## Path resolution

Resolve two base directories before any file operation:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
PROJECT=$(basename "$REPO_ROOT")
```

| Variable | Path | Used for |
|----------|------|----------|
| `GLOBAL_MX` | `~/.mx/<project>/<name>/` | Reading spec.md (permanent) |
| `LOCAL_MX` | `<repo-root>/.mx/<name>/` | Writing PR drafts to tmp/ (ephemeral) |

---

## Step 1 — Gather context

Read `GLOBAL_MX/spec.md` (`~/.mx/<project>/<name>/spec.md`) for the
What/Why/How summary.

Resolve the base branch once — every later step uses this value (the log
below, the content check in Step 2, and the PR target in Step 6):

```bash
BASE_BRANCH=""
for cand in develop main; do
  if git rev-parse --verify --quiet "refs/heads/$cand" >/dev/null; then
    BASE_BRANCH="$cand"; break
  elif git rev-parse --verify --quiet "refs/remotes/origin/$cand" >/dev/null; then
    BASE_BRANCH="origin/$cand"; break
  fi
done
```

Assign the ref you actually verified: a base that exists only on the
remote is `origin/<name>`, never the bare local name — the bare name is
not a valid object and every later command degrades to an empty range in
silence. If `BASE_BRANCH` is still empty, neither branch exists — ask the
user, do not guess.

If invoked from an orchestrator that already resolved a base branch (e.g.
mx-flow Phase 4.2), use that value instead.

Get the git log since the branch diverged from the base branch:

```bash
git log $(git merge-base HEAD "$BASE_BRANCH")..HEAD --oneline
```

Get the diff summary:

```bash
git diff $(git merge-base HEAD "$BASE_BRANCH")..HEAD --stat
```

If `git merge-base HEAD "$BASE_BRANCH"` fails, or the log comes back
empty, stop and tell the user — never draft a PR from an empty commit
range.

Find related issues by checking in this order:
1. Branch name — extract any issue number (e.g. `fix/123-timeout` → `#123`)
2. Commit messages since branch start — look for `#<number>`, `closes`,
   `fixes`, `resolves`
3. Open issues list — match by title keywords against the feature name:
```bash
gh issue list --state open --limit 20 2>/dev/null || true
```

Collect all candidate issue references. If ambiguous, include all
candidates and let the user trim during review.

---

## Step 2 — Autonomous content check (mandatory)

This check is **required** — never skip it. mx-pr is the only place it runs
(mx-flow hands off to mx-pr for it). Two autonomous passes, no user prompt:
net-zero churn out, small fixups folded into their parent, each pass
reverted by a tree-hash invariant if it moves the tree. **Execute the full
canonical procedure** — read and follow
`${CLAUDE_SKILL_DIR}/references/content-check.md` (next to this SKILL.md),
passing `$BASE_BRANCH` from Step 1 as its base. If that file is missing,
say the content check is unavailable in this install and continue to Step 3
**without** rewriting any history — never improvise a history rewrite from
the summary above.

---

## Step 3 — Write draft to temp file

Read `references/pr-template.md` (located in the same directory as this
SKILL.md). It defines the PR sections and how each placeholder maps to a
source.

Fill each placeholder using the context gathered in Step 1.

**Committed-files-only rule.** The published body is read by people who
can see only the repository — every file or path it names must exist in
the repo at the branch's HEAD (verifiable:
`git cat-file -e "HEAD:<path>"`). spec.md, plan.md, the draft file, and
anything under `~/.mx/` or `<repo-root>/.mx/` are local-only: use them as
sources for the content, but never name them or their paths in the body.
For `{{test_plan}}` this means stating the verification itself (tests
added, commands run, results) rather than pointing at plan.md. The rule
covers text copied from the template as well as filled placeholders —
scan the assembled body once before Step 6 and strip any skill-local path
it carries in.

**CHANGELOG.** If the repo has one (`test -f CHANGELOG.md`), add an entry
following `references/changelog-convention.md` (same directory as this
SKILL.md) and commit it before Step 6 — the PR number does not exist yet,
so leave that reference off. If the repo has no `CHANGELOG.md`, drop the
"CHANGELOG updated" checklist item from the body.

If spec.md does not exist, derive `{{summary}}`, `{{motivation}}`, and
`{{notes}}` from the git log only.
Remove any section whose content is empty and marked optional in the
template.

Create `LOCAL_MX/tmp/` (`.mx/<name>/tmp/`) if it does not exist.
Generate draft path: `.mx/<name>/tmp/pr-draft-<YYYYMMDD-HHmmss>.md` using
the current timestamp.
Write the filled template to the draft file.

---

## Step 4 — Show draft and ask for review

Display the full draft content inline.

Then present two options (subject to Orchestrated mode above):

```
Draft saved to: $DRAFT

Options:
  [A] Looks good — proceed to platform selection
  [B] Edit first — open the draft file, make changes, then re-run /mx-pr
```

Wait for the user to choose. Do not proceed automatically. (Orchestrated
mode: continue with the draft as displayed — see "Orchestrated mode"
above.)

If the user chooses [B], remind them:
```
Edit $DRAFT, then run /mx-pr again — it will detect the existing draft.
```

If the user runs /mx-pr again and a draft file exists under
`.mx/<name>/tmp/` (within 24h), offer to reuse it instead of regenerating.

---

## Step 5 — Select platform

Ask the user which platform to publish to:

```
Publish to:
  [1] GitHub      (gh pr create)
  [2] GitLab      (glab mr create)
  [3] Bitbucket   (experimental — requires bb CLI)
  [4] Hand off    (show draft path, you push and open the PR yourself)
  [5] Skip        (do nothing — branch stays local, come back later)
```

Wait for the user to choose. (Orchestrated mode: pick from the repo's
remote and continue — see "Orchestrated mode" above.)

---

## Step 6 — Push and publish

Before invoking the platform CLI, make sure the (possibly rewritten)
branch is on the remote:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if git rev-parse --verify --quiet "origin/$BRANCH" >/dev/null; then
  # branch exists on remote — Step 2 may have rewritten history, so push with a lease
  git push --force-with-lease origin "$BRANCH"
else
  git push -u origin "$BRANCH"
fi
```

Use `--force-with-lease` (never plain `--force`) so a concurrent update on
the remote aborts the push instead of clobbering someone else's work. If
push fails, surface the error and stop — do not retry blindly.

Then check the chosen platform's CLI is present before invoking it:

```bash
command -v gh >/dev/null      # GitHub
command -v glab >/dev/null    # GitLab
command -v bb >/dev/null      # Bitbucket
```

If it is missing, do not substitute another platform — fall back to
option [4] Hand off and say which CLI was missing.

The platform CLIs take a branch **name**, so strip any `origin/` prefix
`$BASE_BRANCH` carries: `${BASE_BRANCH#origin/}`.

### GitHub

```bash
gh pr create \
  --title "<title from first Summary bullet>" \
  --body "$(cat $DRAFT)" \
  --base "${BASE_BRANCH#origin/}"
```

### GitLab

```bash
glab mr create \
  --title "<title>" \
  --description "$(cat $DRAFT)" \
  --target-branch "${BASE_BRANCH#origin/}"
```

### Bitbucket

```bash
bb pr create \
  --title "<title>" \
  --description "$(cat $DRAFT)"
```

No verified CLI target-branch flag exists for `bb` — after creating,
confirm the PR targets `${BASE_BRANCH#origin/}` and correct it in the web
UI if it does not.

### Other / Skip

Display the draft path and content for the user to use manually.

---

## Step 7 — Report

**Done** = the PR/MR URL is printed, its base branch is
`${BASE_BRANCH#origin/}`, and the body contains no unfilled
`{{placeholder}}` and no path that fails `git cat-file -e "HEAD:<path>"`.
Print the URL, the base, and the commit count. Do not wait on CI; if the
platform CLI reports checks, name them and stop — CI failures are the
user's next action, not this skill's. For [4] Hand off and [5] Skip there
is no URL: done means the draft path is printed and you have said what was
and was not pushed.

```
PR created: <url>          ← if published
Base: <base branch>  ·  <N> commit(s)
Draft kept at: $DRAFT

Next: after merge, run /mx-flow finish <name> (will clean up .mx/<name>/tmp/)
```

Do not delete the draft file here. `/mx-flow finish` handles all
`.mx/<name>/tmp/` cleanup.

---

## Notes

- PR format is defined in `references/pr-template.md` — customize it to
  match your team's conventions
- Title is derived from the first bullet of `{{summary}}` — keep it under
  72 characters
- If spec.md does not exist, all content is derived from the git log
- Draft files live in `.mx/<name>/tmp/` — project-local, gitignored
- The timestamp suffix prevents collisions if mx-pr is run multiple times
  for the same feature
