# Cross-Language Review Principles

> Core review standards that apply regardless of programming language.
> Language-specific syntax and patterns are in separate language spec files.

---

## Priority

| Priority | Category | Rationale |
|----------|----------|-----------|
| P0 | SRP / Separation of Concerns | Constructor only does DI, business logic must not leak into infrastructure |
| P0 | Exception / Error Handling | Swallowed errors are the hardest anti-pattern to debug, must preserve stack trace |
| P0 | Race Condition | Concurrency bugs are nearly impossible to reproduce in test environments |
| P1 | Component Test | Mock external dependencies, test complete cross-layer scenarios |
| P1 | Observability / Logging | No logs in production = blind debugging |
| P1 | Simplicity / Over-engineering | Speculative abstractions and unused flexibility become permanent technical debt |
| P1 | Surgical Changes / Scope Creep | Unrelated edits inflate diffs, hide intent, and create regressions outside the stated change |
| P2 | Comment (Why) | Code says What, comments say Why |
| P2 | Performance | Not premature optimization — obvious performance hazards |
| P3 | Metrics | Observable production health: counters, gauges, histograms for key operations |

---

## P0 — SRP / Separation of Concerns

### Core Rules

**A class/module/function should have one reason to change.**

- If a single class handles order creation, email notification, report generation, AND inventory management — it has too many responsibilities.
- Split by business capability, not by technical layer.

**Constructor / initialization should only wire dependencies, not execute business logic.**

- No database calls, no HTTP requests, no complex computation in constructors.
- Dependencies should be injected, not created internally.

**Don't mix infrastructure concerns with business logic.**

- Business rules should not know about HTTP status codes, database drivers, or serialization formats.
- Infrastructure adapters wrap external dependencies and expose clean interfaces to the business layer.
- Dependencies point inward only (infrastructure → application → domain); domain code never imports infrastructure packages.

---

## P0 — Exception / Error Handling

### Core Rules

**Every error path must log, wrap-and-propagate, or be handled explicitly — never silently discarded. Log exactly once, at the boundary that handles the error; a function that wraps and returns must not also log (double-logging hides the real handler).**

This is the canonical error-path rule for this skill. Nowhere else — later in this file, in a language spec, in `_template.md` — may state a competing version of it; point back here instead. The list below expands how to satisfy this rule; it does not replace it. Where a language spec's example shows log-and-re-throw, this paragraph wins.

**Preserve error chain / stack trace.** Re-throwing must not lose the original error context.
- C#: `throw;` not `throw ex;`
- Go: `fmt.Errorf("context: %w", err)` not `fmt.Errorf("context: %v", err)`

**Use semantically appropriate error/exception types.** Validation errors, not-found errors, and system errors should be distinguishable.
- C#: Use specific exception types (`ValidationException`, `NotFoundException`), not generic `InvalidOperationException` for everything
- Go: Use sentinel errors (`var ErrNotFound = errors.New(...)`) or custom error types

**Resources must be released on error.** Use language-appropriate patterns:
- C#: `using` / `await using` declarations
- Go: `defer` for cleanup

**Every `catch` / error branch must satisfy the canonical rule above.** In practice that is one of:
1. Wrap with context and propagate — do not log here; the handling boundary logs, OR
2. Handle the error explicitly (return appropriate response, retry, fallback) and log it once, with the error object and the business identifiers

Logging and then continuing as if nothing happened is not "handled" — that hides bugs.

---

## P0 — Race Condition

### Core Concepts

**Shared mutable state must be synchronized.**

- Any mutable variable accessible by multiple threads/goroutines/tasks requires explicit synchronization (locks, atomic operations, concurrent collections, etc.).
- Static / singleton mutable fields are high-risk by default.

**Check-then-act is NOT atomic.**

- Reading a value, making a decision, then writing back is a classic race condition pattern.
- Use atomic operations, transactions, or lock-protected critical sections.

**Cache read-modify-write must be atomic.**

- `if not cached -> compute -> store` executed by concurrent callers can cause redundant computation or data corruption.
- Use built-in atomic cache patterns (e.g., `GetOrCreate`, `LoadOrStore`, `singleflight`).

---

## P1 — Component Test

### When to Require

Component tests validate complete scenarios with external dependencies mocked out. They sit between unit tests and integration tests — testing real cross-layer collaboration without requiring live infrastructure.

**When to require component tests:**
- Features involving multiple collaborating classes (e.g., Controller → Service → Repository)
- Background services / hosted services with complex lifecycle (start → process → error → retry → stop)
- Event pipelines (webhook received → validated → queued → consumed → side effect)
- State machines or multi-step workflows

**What to mock:**
- External APIs (HTTP clients, third-party SDKs)
- Databases (use in-memory fakes or mock repositories)
- Message brokers (Kafka, RabbitMQ — use fake producers/consumers)
- Redis / distributed cache

**What NOT to mock:**
- The classes under test and their internal collaborators
- Serialization / deserialization (test real JSON handling)
- DI wiring (use real or test-specific DI container)

**Component-test scenario IDs (traceability labels, not function names):**
Group by feature area with clear scenario IDs for traceability:
```
A1 — Normal lifecycle (start → process → stop)
A2 — Lifecycle with empty input
B1 — Error during processing → retry succeeds
B2 — Error during processing → max retries → fail
C1 — Token rotation before expiry
E1 — Edge case: concurrent requests
```

### Unit Test Coverage

Every tested unit should cover:

| Scenario | Description |
|----------|-------------|
| Happy path | Normal successful flow |
| Edge cases | Empty collections, zero, null/nil, boundary values, max values |
| Error path | Behavior when external dependencies fail |
| Business rule violation | Correct rejection of invalid input |

### Mock / Stub Guidelines

- Mock external dependencies (DB, HTTP, message queues), not pure functions.
- Verify critical side effects (e.g., was the error logged? was the notification sent?).
- Avoid over-mocking — if a function has no external dependency, don't mock it.

### Deterministic Time (no wall-clock in tests)

Time is an external dependency — treat it like one. A test that reads the real clock is nondeterministic by construction.

- Code under test must not read the system clock directly (`time.Now()`, `DateTime.UtcNow`) when the value affects behavior — inject a clock the test controls (per-language pattern in `golang.md` / `dotnet.md`).
- Never use real sleeps to synchronize with concurrent work — `sleep(100ms)` is a bet on scheduler timing and flakes on slow CI. Synchronize on an observable signal (channel, event, callback) or advance a fake clock.
- Never assert on real elapsed time (`elapsed < 50ms`) — that measures machine speed, not behavior.
- Real-time timeouts in tests are allowed only as a failure backstop (catching a deadlock), never as the synchronization mechanism.

Flag violations as `warning` (rule area P1) — flaky tests erode trust in the whole suite and mask real races.

### Test function naming

Use descriptive names that express intent:
```
MethodName_StateUnderTest_ExpectedBehavior
```

Bad: `Test1`, `TestCreateOrder`
Good: `TestCreateOrder_WhenAmountIsZero_ShouldReturnValidationError`

---

## P1 — Observability / Logging

### Mandatory Rules

**Use structured logging framework, never raw print / console output.**

- All log entries must be structured (key-value pairs), parsable by log aggregation tools (ELK, Loki, Seq, etc.).
- Raw print / console / debug output is strictly prohibited in production code.

**Log Level Guidelines:**

| Level | Usage | Production Visibility |
|-------|-------|----------------------|
| Debug | Diagnostics only, not on hot paths | Off by default |
| Info | Business milestones (2-5 per request) | On |
| Warn | Expected degradation / retry, no immediate human action needed | On |
| Error | Requires human intervention, must include error/exception object | On |
| Critical/Fatal | Service cannot continue, should trigger alerts | On |

**Error-path handling is defined once, in "P0 — Exception / Error Handling" above — apply that rule, not a variant of it.** When an error path does log:

- Log must include the error/exception object (not just a message string).
- Log must include business context (e.g., order ID, user ID) for traceability.

**Correlation / Trace ID must be propagated across service boundaries.**

- Every log entry in a request chain should carry a trace ID.
- Cross-service calls must forward the trace ID.

**Never log sensitive information:**

- PII (email, phone, address), credentials (passwords, tokens, API keys), financial data (card numbers).
- Mask or exclude sensitive fields.

---

## P1 — Simplicity / Over-engineering

### Core Rule: Minimum code that solves the stated problem. Nothing speculative.

The reviewer's job here is to ask, for every new abstraction, parameter, branch, or layer: **what concrete requirement made this necessary?** If the answer is "in case we need it later" or "for flexibility", flag it.

### Flag When You See

- **Abstractions with a single caller.** An interface, factory, or strategy pattern wrapping one concrete implementation. If there is no second implementation in the diff or planned, the abstraction has no buyer.
- **Configurability that was not asked for.** New constructor parameters, config flags, or environment variables that the spec / PR description does not mention.
- **Error handling for impossible scenarios.** Defensive checks for conditions the type system or upstream contract already guarantees.
- **Scaffolding for hypothetical future requirements.** Plugin systems, hook points, generic dispatchers added "in case".
- **Disproportionate size.** A 500-line diff for a problem that a senior engineer would solve in 50. Ask: would removing half this code still satisfy the stated requirement?

### Not Flagged

- Abstractions that already have ≥2 callers in the diff.
- Error handling for scenarios that demonstrably occur (tests exist, or the boundary is external).
- Complexity that is inherent to the problem domain (concurrency, distributed state, regulatory rules).

### Severity Calibration

- **error**: a new public interface / package / framework added for one use case.
- **warning**: unnecessary config knobs, defensive checks for guaranteed-safe inputs.
- **suggestion**: a single helper that could be inlined; small structural redundancy.

---

## P1 — Surgical Changes / Scope Creep

### Core Rule: Every changed line should trace directly to the stated change.

The reviewer's job is to verify the diff stays within the boundary the PR description / spec defines. Edits outside that boundary inflate review surface, hide the intent of the change, and create regression risk in code that no one expected to be touched.

### Flag When You See

- **Drive-by reformatting.** Whitespace, brace style, import reordering in files that have no functional change for this PR.
- **Refactors not called out.** Renames, extractions, or restructures that the spec / PR description does not mention. These belong in their own PR.
- **"While I was here" edits.** Comment rewrites, variable renames, or cleanup in code unrelated to the stated change.
- **Deletion of pre-existing dead code.** Unless the PR is explicitly a cleanup PR, removing pre-existing unused code mixes concerns.
- **Style normalization across unrelated files.** Converting `var` to `let`, `interface{}` to `any`, etc., in files outside the change boundary.

### Not Flagged

- **Orphans created by the change itself.** Imports, variables, or helpers that became unused *because of* this PR's edits — these must be cleaned up in the same PR.
- **Edits genuinely required by the change.** Adjacent code that must change for the new behavior to compile or work correctly.
- **Updates to tests, docs, types, or callers that the change forces.**

### Severity Calibration

- **error**: a structural refactor bundled into a feature / fix PR.
- **warning**: multiple unrelated cleanups across several files.
- **suggestion**: a single drive-by reformat or rename in one file.

---

## P2 — Comment (Why)

### Core Rule: Comments explain WHY, not WHAT.

Code already tells you WHAT it does. Comments must explain:

- **Why** this approach was chosen over alternatives
- **Why** a magic number has this specific value
- **Why** a workaround exists (link to issue / external bug)
- **Why** a business rule is enforced here

### Writing Style

**Comments must be concise and self-contained.** A reader should understand the content and scenario from the comment alone, without scanning surrounding code, prior comments, or unrelated context.

- **Be brief. Hard limit: 3 lines.** If it needs more, the code or design probably needs to change, not the comment.
- **Lead with WHY.** Describe HOW only when the mechanism is non-obvious and matters for correctness.
- **No pronouns or vague references.** Avoid "this", "it", "that thing", "the above", "as mentioned". Name the concrete subject (function, field, condition, business rule) explicitly.
- **State the scenario.** When the comment guards a branch, edge case, or workaround, name the triggering condition — not "handle the case" but "when the upstream API returns 429 during burst traffic".

```
// ❌ Vague pronouns, no scenario
// Do this here because of the issue mentioned above.

// ❌ Describes HOW, not WHY
// Loop through orders and sum their amounts.

// ✅ Concise, names subject + scenario + why
// Stripe webhook may deliver the same event_id twice within 5 minutes during
// retry storms; dedupe by event_id to avoid double-charging the customer.
```

### Must-Have "Why" Comments

| Situation | Example |
|-----------|---------|
| Non-obvious algorithm or magic number | Why retry 3 times? Why timeout 30s? |
| Framework default overridden | Why we bypass the default behavior |
| Business rule enforcement | Rate calculation, fee logic, eligibility rules |
| Known external limitation / workaround | Third-party bug, API quirk |
| TODO / FIXME | Must include issue link or explanation of why and when |

### Anti-Patterns

```
// ❌ Says WHAT (code already says this)
// Call the repository to save the order
await repo.SaveAsync(order);

// ❌ Empty / meaningless doc
/// <summary>
/// Creates an order.
/// </summary>

// ✅ Says WHY
// TransactionScope is not used here because EF Core 8 has a known issue
// with distributed transactions (dotnet/efcore#23523).
// We manually control commit order in the service layer instead.
await repo.SaveAsync(order);
```

---

## P2 — Performance

### Obvious Hazards to Flag

| Hazard | Description |
|--------|-------------|
| N+1 queries | Querying inside a loop instead of batch/join |
| Load-then-filter | Loading entire dataset into memory, then filtering client-side |
| Unnecessary allocation in hot paths | Creating objects/buffers inside tight loops |
| Client/connection not reused | Creating new HTTP clients or DB connections per request |
| Blocking async | Synchronously waiting on async operations (deadlock risk) |

These are not premature optimization concerns — they are production-impacting patterns that should be flagged during review.

---

## P3 — Metrics

### Core Concepts

**Key operations should emit observable metrics for production health monitoring.**

Metrics complement logging — logs tell you what happened, metrics tell you how the system is performing over time.

**What to measure:**

- **Counters** — total requests, errors, retries, messages processed
- **Gauges** — active connections, queue depth, in-flight requests
- **Histograms** — request latency, processing duration, payload size

**When to require metrics:**

- API endpoints: request count + latency + error rate
- Background services: execution count + duration + failure count
- External calls: call count + latency + timeout/error rate
- Queue consumers: messages processed + lag + processing time

**Anti-patterns:**

- High-cardinality labels (user IDs, request IDs as metric labels — use logs for those)
- Metrics without alerts — if nobody acts on it, don't collect it
- Missing error rate metrics — knowing request count without error rate is incomplete
