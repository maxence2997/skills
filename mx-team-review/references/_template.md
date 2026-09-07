# [Language] Review Standards

> Replace this line with a one-sentence philosophy for reviewing this language.
> Example: "Focus on what Go idiomatic code looks like in production, not just whether it compiles."

---

## Language Version
- Target: [e.g. Go 1.22+ / Python 3.12+ / Rust 1.75+]
- Primary frameworks: [e.g. Gin, GORM]

---

## Review Priority

Priorities are fixed in `principles.md` — do not restate them here. This file holds language-specific patterns only.

---

## Observability / Logging

[Describe the logging standard for this language/framework]

**Required structured logger:** [e.g. slog, zap, ILogger<T>]

**Forbidden:**
- [e.g. fmt.Println, Console.WriteLine]

**Log level guidelines:**
- Debug:
- Info:
- Warning:
- Error:
- Critical/Fatal:

**Error-path handling: follow `principles.md` §P0 — Exception / Error Handling. Do not restate the rule here.**

---

## [Language-Specific High Risk]

[Describe the most dangerous language-specific issue]

```[lang]
// ❌ Bad example
// explain why this is dangerous

// ✅ Good example
// explain the fix
```

---

## Test Coverage

**Business logic must have tests. Infrastructure layer (DB migrations, SDK wrappers) is exempt.**

Decision rule: "If this logic is wrong, will the business break?" → yes = must test.

Required scenarios:
- ✅ Happy path
- ✅ Edge cases (null, zero, empty, boundary values)
- ✅ Error path (behavior when dependencies fail)
- ✅ Business rule violations (inputs that should be rejected)

**Test naming convention:** `MethodName_StateUnderTest_ExpectedBehavior`

---

## Comments (Why)

Code says what. Comments say why.

**Forbidden comments (say what, not why):**
```[lang]
// ❌ calls the repository to save the order
// ❌ increment counter
```

**Required Why contexts:**
- Non-obvious numbers (why retry 3 times, why timeout 30s)
- Workarounds for known upstream bugs or limitations
- Business rules enforced in code (rates, limits, thresholds)
- TODO/FIXME must include an issue link or clear reason

---

## Error Handling

[Describe the language's error handling standards]

```[lang]
// ❌ Bad: swallow error / lose stack
// ✅ Good: propagate with context
```

---

## Performance

[Describe common performance issues specific to this language]

**DB / IO:**
- [e.g. N+1 queries, missing index hints]

**Memory / Allocation:**
- [e.g. unnecessary boxing, buffer reuse]

**Caching:**
- High-frequency, low-change data without a cache strategy is a `suggestion` (rule area P2).
- Cache TTL must be justified in a comment.

---

## [Language Idioms]

[Describe language-specific best practices that reviewers should check]

---

## Bad vs Good Examples

### ❌ Bad
```[lang]
// Example of a common mistake in this language
```

### ✅ Good
```[lang]
// The correct approach
```
