# Content check — autonomous branch-history cleanup

> Canonical procedure, and the only place this check runs: mx-pr executes it
> in Step 2, unconditionally, before drafting. Running it twice is safe.

Goal: the branch reads as if the work had been done right the first time.
**Net-zero churn** — commits/hunks that cancel each other on the branch
(`++A` in one commit, `--A` in a later one) — comes out; small **fixups**
fold into their logical parent. Both run autonomously, **no user prompt**:
safety comes from a tree-invariant check, not user confirmation. Each pass
is its own transaction — it either lands with `HEAD^{tree}` unchanged, or
reverts itself and the next pass starts from there.

## 1 — Pre-state

```bash
PRE_HEAD=$(git rev-parse HEAD)
PRE_TREE=$(git rev-parse HEAD^{tree})
BASE=$(git merge-base HEAD "$BASE_BRANCH")
```

`$BASE_BRANCH` is the ref the caller already verified (mx-pr Step 1) —
`origin/<x>` when the branch exists only on the remote. Never guess one
here; if the caller supplied none, stop and ask the user.

Short-circuit: if `git rev-list --count "$BASE..HEAD"` is 1, log
`Content check: 1 commit on branch, nothing to do.` and return — neither
pass can apply to a single commit.

## 2 — Choose candidates

Read every commit's diff over `$BASE..HEAD` (`git show --format= <sha>`).

- **Net-zero**: a later commit whose diff exactly reverses an earlier one →
  drop both; a `-lines` segment exactly undoing an earlier `+lines` segment
  → trim it out of both.
- **Fixup**: a commit belonging inside exactly one earlier commit — subject
  `fixup!`/`squash!`, `wip`/`tmp`/`debug`/`nit`/`typo`/`oops`, or review
  feedback; or a small diff (≤ ~20 lines) whose files and line ranges sit
  inside one earlier commit.

Judge each candidate first, on one standard: would a reviewer read the two
commits as one iteration on the same thing? Same file (or an obviously
paired one, e.g. a type and its test), same function or block, intervening
commits part of that iteration, subjects reading as refinement rather than
two independent decisions. **Uncertain → skip the candidate**; a fixup with
several plausible parents → skip. History fidelity is the default: a noisy
commit that survives costs a reader a moment, a wrong fold destroys
information.

## 3 — Rewrite: one rebase per kind

Net-zero first, then fixups, each its own transaction. One mechanism for
both — an explicitly authored `git rebase -i` todo:

```bash
TODO=$(mktemp)
git log --reverse --pretty='pick %H %s' "$BASE..HEAD" > "$TODO"
# edit "$TODO": `drop` a cancelled commit; for a fixup switch `pick`→`fixup` and move its line under its parent's
GIT_SEQUENCE_EDITOR="cp '$TODO'" git rebase -i "$BASE"
```

A commit that only partially cancels gets `edit` rather than `drop`: at the
stop, remove the cancelling hunks (`git apply -R`), `git commit --amend`,
`git rebase --continue`. A pass with no candidates skips its rebase.

## 4 — Verify the invariant

Run this after every rebase — it reverts the pass both when the tree moved
and when the rebase stopped mid-flight on a conflict or any other error:

```bash
if [ -d "$(git rev-parse --git-path rebase-merge)" ] ||
   [ "$(git rev-parse HEAD^{tree})" != "$PRE_TREE" ]; then
  git rebase --abort 2>/dev/null || true
  git reset --hard "$PRE_HEAD"
fi
```

Report an aborted pass as aborted and continue from `$PRE_HEAD`. On success
set `PRE_HEAD=$(git rev-parse HEAD)` for the next pass; `PRE_TREE` never
changes.

## 5 — Report, then return control to the invoking skill

```
Content check:
  Net-zero: <K1> commit(s) dropped, <H1> hunk(s) trimmed  (or "none" / "aborted")
  Fixups:   <K2> commit(s) folded into <P> parent(s)      (or "none" / "aborted")
  Tree unchanged. <N before> → <N after> commits on branch.
```
