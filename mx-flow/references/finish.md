# Phase 8 — Finish (post-merge cleanup, mx-flow)

> Read this when triggered by `/mx-flow finish <name>`. This phase runs
> independently from the main pipeline.

## 8.1 — Establish merge evidence (no question when it can be derived)

Worktree removal must run from outside the worktree, so move there
yourself rather than asking:

```bash
MAIN_ROOT=$(cd "$(dirname "$(git rev-parse --git-common-dir)")" && pwd)
cd "$MAIN_ROOT"
```

(in a normal checkout MAIN_ROOT resolves to the same directory as
REPO_ROOT)

Then collect merge evidence, in order — stop as soon as (a) and (b) hold:

- **(a) PR/MR state** — `gh pr view <branch-name> --json state -q .state`
  → `MERGED`, or
  `glab mr view <branch-name> --output json | jq -r .state` → `merged`
- **(b) Content is in the base** —
  `git fetch origin <base-branch> && git diff --quiet origin/<base-branch>..<branch-name>`.
  An empty diff means every change on the branch is already in the base:
  squash- and rebase-proof, and independent of commit SHAs.
- **(c) Nothing unpushed** — `git rev-list --count @{u}..<branch-name>`
  is 0, or the upstream is gone (the remote branch was deleted after the
  merge — itself merge evidence)
- **(d) Worktree clean** —
  `git -C .mx/<name>/worktree status --porcelain` is empty

If (a) is unavailable (no `gh`/`glab`, no auth, no remote) but (b) holds,
that is sufficient. Only if neither (a) nor (b) can be established: ask
the user to confirm the merge.

## 8.2 — Delete the plan

```bash
rm -f .mx/<name>/plan.md
```

The plan describes in-flight work — it has no value after all tasks
are done. Report: `Deleted .mx/<name>/plan.md`

## 8.3 — Preserve design spec and ADRs

Do **not** delete `~/.mx/<project>/<name>/spec.md` or
`~/.mx/<project>/<name>/adr.md`. The design spec records what was built,
the ADRs record why — both have lasting documentation value.

Report: `Kept ~/.mx/<project>/<name>/spec.md (and adr.md when present)`

## 8.4 — Clean up temp files

List what is there, then delete the whole directory and report what was
removed:

```bash
ls -lt .mx/<name>/tmp/ 2>/dev/null
rm -rf .mx/<name>/tmp/
```

`.mx/` is gitignored and ephemeral by definition; at this point the
directory holds review reports and PR drafts for a feature that has just
merged. Keep a file only if the user asked for it earlier in this session
— move that file out first, then delete the rest. Never touch anything
outside `.mx/<name>/tmp/`.

## 8.5 — Remove the worktree

```bash
git worktree remove .mx/<name>/worktree
```

**If the command succeeds:** report `Worktree removed.`

**If git refuses** (uncommitted changes detected):

```
git worktree remove failed — the worktree has uncommitted changes.

Either:
  1. Go into .mx/<name>/worktree, commit or discard changes, then re-run /mx-flow finish
  2. Force remove (loses uncommitted changes):
     git worktree remove --force .mx/<name>/worktree
```

Do not force-remove automatically. Wait for the user to decide.

## 8.6 — Delete the branch

```bash
git branch -d <branch-name>
```

`-d` (not `-D`) first — git refuses to delete an unmerged branch, which
acts as a safety net.

**If git refuses** (branch not fully merged): after a squash-merge or
rebase this is the expected outcome, not an error. With 8.1's evidence in
hand — (a) or (b) established and (c) clean — run
`git branch -D <branch-name>` immediately and report:

```
Branch deleted (-D; squash-merge verified: PR #<n> MERGED, branch content identical to <base-branch>).
```

**Still ask — never auto-force — when:**

- 8.1 (b) failed: the branch carries work that is not in the base branch;
- 8.1 (c) failed: unpushed commits would be lost;
- the worktree is dirty — that is 8.5's guard, which stands as written.

## 8.7 — Clean up local .mx directory

If `.mx/<name>/` is now empty, remove it:
```bash
rmdir .mx/<name>/ 2>/dev/null
```

## 8.8 — Summary

```
Finished <name>:
  ✓ Plan deleted (.mx/<name>/plan.md)
  ✓ Design spec and ADRs preserved at ~/.mx/<project>/<name>/
  ✓ Temp directory deleted (.mx/<name>/tmp/)
  ✓ Worktree removed
  ✓ Branch deleted
```

If any step was skipped due to a safety refusal, mark it with `○` and note
what remains.
