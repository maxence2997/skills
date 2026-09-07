# ADR Format

Architecture Decision Records capture *why* a design was chosen over the alternatives.
The spec records what was built; the ADR records the rationale behind the design.

Written at the end of mx-brainstorm only when Step 5's condition holds — a real
choice was made; otherwise there is no ADR and the decision lives in `spec.md`'s
How section. When written: appended to `MX/<name>/adr.md` (created if it doesn't
exist). Use today's date as the section header so multiple decisions in the same
feature remain distinguishable.

---

## Format

```markdown
# ADR: <feature-name>

Date: <YYYY-MM-DD>

## Context

<What problem were we solving? What constraints applied?>

## Options considered

### Option A — <name>
<What it is, pros, cons>

### Option B — <name>
<What it is, pros, cons>

### Option C — <name> (if applicable)
<What it is, pros, cons>

## Decision

<Which option was chosen and the primary reason>

## Consequences

<What becomes easier, what becomes harder, what must be monitored>

## Rejected alternatives

<Brief note on why each non-chosen option was set aside>
```

---

## Rules

- Populate from the brainstorm conversation — do not fabricate content
- If information is missing, leave a `TBD` placeholder
- Do not ask the user to confirm — write and notify, then continue
- `adr.md` is permanent and must not be deleted by `/mx-flow finish`
