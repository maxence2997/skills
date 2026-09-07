# mx-brainstorm

Turn a rough idea into an approved design spec before any code is written.

Asks all its clarifying questions in one batch — each with a proposed default — proposes 2-3 approaches with trade-offs, and saves the agreed design spec to `~/.mx/<project>/<name>/spec.md`. Automatically records an ADR capturing the options and rationale. Nothing gets built until the design spec is approved.

## Usage

```
/mx-brainstorm <topic>
/mx-brainstorm
```

## Output

`~/.mx/<project>/<name>/spec.md` — a design spec with four sections:

- **What** — what is being built or changed
- **Why** — the problem it solves
- **How** — the chosen approach and design decisions
- **Out of scope** — what this change explicitly does not cover

`~/.mx/<project>/<name>/adr.md` — the decision rationale and rejected alternatives (written automatically, no extra questions asked).

Both files have lasting value after implementation is done.

## Notes

- Clarifying questions arrive as one numbered batch (max 6); answer any subset — unanswered items take the stated default
- Bows out when the change is too small for a spec to add anything beyond the diff
- Hard gate: no code is written until the user approves the design spec — approval means saying so, in words; silence or a comment on the content is not approval
- Creates `~/.mx/<project>/<name>/` for permanent spec and ADR storage
- Hand-off: after approval, use `/mx-flow` to continue the workflow
