# Content check — autonomous branch-history cleanup

> Canonical procedure. Invoked by mx-pr (Step 2, unconditionally before
> drafting) and by mx-flow (Phase 6.5, before handing off to mx-pr).
> Running it twice is safe — the second run is a no-op.

Multiple TDD → review → triage iterations leave two kinds of history noise:

1. **Net-zero churn** — changes reverted on the same branch. Full:
   `++A` in commit 1, `--A` in commit 4 → both commits drop. Partial:
   `++A,++B` in commit 1, `--B,++C` in commit 5 → effective net is
   `++A,++C`, so the `B`-related hunks come out of both commits.
2. **Squash-able fixups** — small touch-ups that logically belong inside an
   earlier commit.

**Both passes run autonomously — no user prompt.** Safety comes from a
tree-invariant check, not user confirmation: the working-tree hash before
and after each pass MUST match. If they differ for any reason, revert that
pass to its starting HEAD and continue. Each pass is its own transaction.

## Pass 0 — Capture pre-state

```bash
PRE_HEAD=$(git rev-parse HEAD)
PRE_TREE=$(git rev-parse HEAD^{tree})
BASE=$(git merge-base HEAD <base-branch>)
```

`<base-branch>` is the branch this work will merge into: `develop` if it
exists, otherwise `main`, unless the invoking skill already resolved one —
then use that. Use the ref that actually exists: the local branch, or
`origin/<name>` when only the remote-tracking ref is there — the bare name
of a remote-only branch makes `merge-base` fail and leaves `BASE` empty, so
both passes would silently analyse nothing. If neither `develop` nor `main`
exists, ask the user which branch to use — do not guess.

Short-circuit: if `git rev-list --count $BASE..HEAD` is 1, neither pass can
apply (Pass 1 needs a pair, Pass 2 needs a parent on the branch). Log
`Content check: 1 commit on branch, nothing to do.` and return.

## Pass 1 — Cancellation cleanup

Read every commit's diff in `BASE..HEAD` (`git show --format= <sha>`).
Look for hunks that mutually cancel and remove them so they leave no trace
in the PR.

### Level 1 — Whole-commit inverse pairs (rule-based)

A pair (X, Y) with X earlier than Y qualifies if Y's diff is the exact
reverse of X's diff — every `+line` in X appears as `-line` in Y in the
same file with identical content, and vice versa, with the same hunk
locations. No semantic judgment needed; this is mechanical.

For each qualifying pair, schedule both commits for **removal in
entirety**. Multiple pairs can be processed together.

### Level 2 — Partial cancellation (semantic judgment)

For cancelling hunks that are **not** part of a whole-commit inverse pair,
judge content relatedness before acting. Textual cancellation alone is not
sufficient — the cancelling lines might be two independent decisions that
coincidentally touched the same code.

Identify candidate hunk groups: a `+lines` segment in commit X with a
matching `-lines` segment (identical content) in a later commit Y on the
branch.

For each candidate group, read the diffs, the surrounding code, and the
commits in between, then judge relatedness. **All** of the following gates
must hold; if any is uncertain, skip the group (default to keeping history
fidelity):

- **File proximity**: cancelling hunks are in the same file, or in files
  that are clearly part of the same logical change (e.g., a struct and its
  test file).
- **Iteration continuity**: the commits between X and Y are part of the
  same iteration on this branch (e.g., review-triage adjustments), not
  work in an unrelated feature area.
- **Subject signals**: commit subjects on the iteration path suggest
  refinement (`fix`, `address review`, `adjust`, `refactor`, follow-up
  wording) rather than two independent decisions.
- **Local semantic relatedness**: the `+A` and `-A` occur in semantically
  related positions — same function, same block, related logic. Incidental
  coincidences (e.g., two unrelated commits both adding then removing a
  blank line) → reject.

If all gates pass, schedule the cancelling hunks for removal from X and
from Y. Commits that become empty after hunk removal are dropped; commits
with remaining content are rewritten with the cancelling hunks gone.

### Execute Pass 1

If nothing was scheduled, log `Pass 1: no cancellation candidates` and
skip to Pass 2.

Otherwise rewrite the branch. The mechanism is your choice —
`git format-patch` + edit + `git am`, or `git rebase --interactive` with
per-commit edits, or `git commit-tree` reconstruction are all acceptable.
The contract: produce a branch where the scheduled commits/hunks are gone
and everything else is byte-identical.

A reference recipe using format-patch:

```bash
PATCHDIR=$(mktemp -d)
git format-patch "$BASE..HEAD" -o "$PATCHDIR"
# Drop fully-cancelled commits: rm "$PATCHDIR"/<seq>-*.patch
# For partial cancellation: edit the patch file to delete the cancelling hunks (keep the header)
git reset --hard "$BASE"
if ls "$PATCHDIR"/*.patch >/dev/null 2>&1; then
  git am "$PATCHDIR"/*.patch  # empty patches are skipped automatically
else
  git reset --hard "$PRE_HEAD"   # every patch was dropped — see below
fi
rm -rf "$PATCHDIR"
```

If every patch was dropped, the branch would be empty relative to base:
the `reset --hard "$BASE"` has already happened, so return to `$PRE_HEAD`,
log `Pass 1 aborted (would empty the branch)`, skip the tree-invariant
verification below, and continue to Pass 2 from `$PRE_HEAD`.

### Verify Pass 1 tree invariant

```bash
POST_TREE=$(git rev-parse HEAD^{tree})
```

`POST_TREE` MUST equal `PRE_TREE`. If they differ, the cleanup changed the
working tree — revert:

```bash
git reset --hard "$PRE_HEAD"
```

If `git am` or rebase fails mid-flight (conflict, empty-commit refusal,
etc.), abort and revert:

```bash
git am --abort 2>/dev/null || git rebase --abort 2>/dev/null
git reset --hard "$PRE_HEAD"
```

Either failure mode → log `Pass 1 aborted (tree/rebase mismatch),
cancellations kept as-is`. Continue to Pass 2 from `$PRE_HEAD`.

On success → update the baseline for Pass 2:

```bash
PRE_HEAD=$(git rev-parse HEAD)
# PRE_TREE must remain equal to the original PRE_TREE
```

## Pass 2 — Squash-into-parent

List commits with `git log $BASE..HEAD --pretty=format:'%h %s'` and
inspect each diff with `git show --stat <sha>`.

Flag a commit as a squash candidate only if it meets **one** of these
high-confidence signals AND points to exactly one parent commit on the
branch. Ambiguous candidates are skipped silently.

**Subject signals**:
- Starts with `fixup!` or `squash!` (autosquash markers)
- Mentions `wip`, `tmp`, `temp`, `debug`, `nit`, `typo`, `oops`
- Mentions `address review`, `address feedback`, `PR feedback`,
  `code review`, `review comments`

**Diff signals**:
- Changed-files set is a subset of exactly one earlier commit's files AND
  the diff is small (≤ 20 lines added+removed combined)
- Touches the same function or hunk range as exactly one earlier commit on
  the branch (overlapping line ranges in the same file)

If a candidate matches multiple potential parents, skip it. Better to
leave a noisy commit than to merge into the wrong parent.

If no candidates are found, log `Pass 2: no squash candidates` and skip to
the report.

Otherwise rewrite each candidate's subject to `fixup! <parent-subject>`
and run autosquash:

```bash
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash $BASE
```

Verify the tree invariant the same way as Pass 1. On any failure:

```bash
git rebase --abort 2>/dev/null || true
git reset --hard "$PRE_HEAD"
```

Log `Pass 2 aborted (tree/rebase mismatch), squashes kept as-is`, proceed.

## Report

```
Content check:
  Pass 1 (cancellation): <K1> commit(s) removed, <H1> hunk(s) trimmed   (or "no candidates" / "aborted")
  Pass 2 (squash):       <K2> commit(s) folded into <P> parent(s)        (or "no candidates" / "aborted")
  Tree unchanged. <N before> → <N after> commits on branch.
```

Return control to the invoking skill.
