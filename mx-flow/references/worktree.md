# Phase 4 — Worktree (mx-flow)

> Read on entering Phase 4. Creates an isolated git worktree for the
> feature branch and establishes the two values later phases reuse: the
> base ref (4.2) and the test runner (4.4).

## 4.1 — Determine branch name

Apply branch naming convention:

| Change type | Prefix |
|---|---|
| New feature | `feat/<name>` |
| Bug fix | `bugfix/<name>` |
| Quick fix (config, docs, CI) | `fix/<name>` |
| Maintenance, deps, tooling | `chore/<name>` |

If the name has no prefix, derive it from the dominant commit type in
plan.md (feat → `feat/`, fix → `bugfix/`, chore → `chore/`) and state the
choice. Ask only if the plan mixes types with no clear majority.
If the name already has a correct prefix, proceed.

## 4.2 — Create the worktree

First, resolve the base branch (`develop` preferred, then `main`) and assign
the ref you actually verified — a base that exists only on the remote is
`origin/<name>`; the bare local name would be an invalid object and every
later `<base>..HEAD` range would degrade to empty in silence:

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

If `BASE_BRANCH` is empty, neither branch exists — ask the user which branch
to base from. This value is **canonical**: Phases 5b, 6 and 7 and mx-pr use
it rather than re-deriving one (strip the `origin/` prefix only where a
platform CLI needs a branch *name*).

Then create the worktree under LOCAL_MX:

```bash
git worktree add .mx/<name>/worktree -b <branch-name> <base-branch>
```

Verify it was created:

```bash
git worktree list
```

## 4.3 — Run project setup

From inside the worktree (`.mx/<name>/worktree`), install dependencies
using whatever the repo's lockfile / manifest indicates (go.mod,
package.json + its lockfile, requirements.txt / pyproject.toml,
Cargo.toml, …). If nothing is detected, skip — Phase 4.4's baseline run
will surface a broken environment.

## 4.4 — Verify baseline

Run the full test suite to confirm the worktree starts clean.

Auto-detect the runner in this priority order (this is the canonical
runner-detection rule — Phases 5 and 6 reuse it):

1. `Makefile` with a `check` or `test` target → `make check` or `make test`
2. `package.json` with a `test` script → `npm test` / `yarn test` / `pnpm test`
3. Language detection: `.go` → `go test ./...`, `.rs` → `cargo test`,
   `.py` → `pytest`, `.cs` → `dotnet test`, `.swift` → `swift test`
4. None of the above matched → say so once, ask the user for the test
   command, and record it as the runner for this session. If the project
   genuinely has no test suite, say so, and Non-negotiable 2's RED step is
   satisfied by a reviewable manual check documented in the commit — never
   by skipping it.

**If baseline fails:**
Report the failures and ask the user whether to proceed or investigate
first. Do not proceed silently with a failing baseline.

## 4.5 — Report

```
Worktree ready at .mx/<name>/worktree/
Branch  : <branch-name>
Baseline: <N> tests passing
```
