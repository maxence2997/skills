# mx-harness

> Your AI agent writes fast. mx-harness makes it engineer properly.

![License](https://img.shields.io/badge/license-MIT-blue)
![Works with](https://img.shields.io/badge/works%20with-Claude%20%7C%20Codex%20%7C%20Copilot%20%7C%20Cursor-blueviolet)

---

## What it looks like

Once installed, you tell the agent your idea — rough or detailed, it asks what it needs.

```
/mx-flow add Redis caching to the search endpoint
```

You make a few decisions. The agent handles the rest. [Full walkthrough →](mx-flow/)

---

## Principles

Without a harness, AI agents skip planning, skip tests, and produce unmaintainable diffs. mx-harness wraps the lifecycle into skills the agent must follow.

| Principle                    | Addresses                                           |
|------------------------------|-----------------------------------------------------|
| **Spec before code**         | Vague requirements, hidden assumptions, scope creep |
| **Test-first**               | Tests written after the fact, missed edge cases     |
| **Multi-perspective review** | Single-reviewer blind spots, missed SRE concerns    |
| **Structured commits**       | "fix stuff" messages, mixed concerns per commit     |
| **Surgical changes**         | Drive-by edits, inflated diffs, unrelated refactors |
| **Don't assume**             | Silent guessing on ambiguous specs                  |

---

## The difference

**Without mx-harness**

```
User:  "Add caching to the search endpoint"
Agent: [writes 200 lines of code]
       [commit: "add cache"]
       [no tests · no design doc · breaks 2 existing behaviours]
```

**With mx-harness**

```
User:  /mx-flow "Add caching to the search endpoint"
Agent: → Asks: Redis or in-memory? TTL strategy? Cache invalidation scope?
       → Writes design spec + ADR to ~/.mx/project/search-cache/
       → Waits for approval before touching any code

       → Task 1: Cache interface (testable abstraction)
       → Task 2: Redis adapter
       → Task 3: Wire into search handler
       → Task 4: Integration test with mock Redis

       [each task: red → green → refactor → structured commit]

       → Senior Engineer:     "Cache key includes user locale? Edge case."
       → SRE:                 "No TTL cap — potential memory leak under load."
       → Future Maintainer:   "Document why TTL=300 was chosen."
```

The first scenario is something most engineers have lived through. The second is what mx-harness locks in by default.

---

## Skills

### `/mx-flow` — the full pipeline

One command in. A few decisions from you. PR out.

```
/mx-flow add Redis caching to the search endpoint
/mx-flow finish search-cache                # post-merge cleanup
```

[How it works →](mx-flow/)

### Standalone skills

Most of these also run inside `mx-flow`; all of them work standalone.

| Skill                                  | Description                                                         |
| -------------------------------------- | ------------------------------------------------------------------- |
| [mx-brainstorm](mx-brainstorm/)       | Turn a rough idea into an approved design spec (with ADR)           |
| [mx-team-review](mx-team-review/)     | Standards-based 3-perspective code review (Go, C#) — Senior Engineer, SRE, Future Maintainer |
| [mx-review-triage](mx-review-triage/) | Triage review findings into fix / track / skip buckets              |
| [mx-commit](mx-commit/)               | Structured commit with enforced message format                      |
| [mx-pr](mx-pr/)                       | Draft, review, and publish a PR to GitHub / GitLab (Bitbucket experimental) |
| [mx-status](mx-status/)               | Show which mx-flow stage each feature is at, its progress, and the next command |
| [mx-doctrine](mx-doctrine/)           | Shared execution doctrine: model dispatch, escalation, verification, judgment rubrics |

---

## Installation

mx-harness installs via [`npx skills`](https://github.com/vercel-labs/skills) — a CLI that drops skill folders into your agent's global skill directory:

- Claude Code: `~/.claude/skills/`
- Codex: `~/.codex/skills/`
- GitHub Copilot: `~/.copilot/skills/`
- Cursor: `~/.cursor/skills/`

**Install or update everything:**

```bash
curl -fsSL --retry 3 https://github.com/maxence2997/mx-harness/archive/refs/heads/main.tar.gz | tar -xz -C /tmp && bash /tmp/mx-harness-main/install.sh
```

Inspect the script first if you'd rather: [install.sh](install.sh).

**Install or update a single skill:**

```bash
npx skills add https://github.com/maxence2997/mx-harness --skill <skill-name> -g -y
```

> This single-skill path bypasses `install.sh`'s hash lock, so it overwrites any local customizations you made under that skill's `references/`.

> **If you cloned the repo directly:** `install.sh` always installs from GitHub `main`, never from your working tree — push your local changes before running it. On a symlinked dev install, use `git pull` alone and do **not** run `install.sh`: it would copy the remote files back through the symlinks into your working tree.

---

## License

MIT
