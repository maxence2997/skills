# C# .NET 8 — Language-Specific Review Standards

> This file covers C#/.NET-specific patterns only.
> Cross-language principles (logging concepts, test coverage, comments, etc.) are in `principles.md`.

---

## Logging — C# Specifics

**Use `ILogger<T>`, prohibit the following:**
```csharp
// ❌
Console.WriteLine("order created");
Debug.WriteLine("error occurred");
Log.Information("..."); // Serilog static — no scope, hard to trace
```

**Message template must use placeholders, no string interpolation:**
```csharp
// ❌ string interpolation cannot be parsed by structured log, poor performance
_logger.LogInformation($"Order {orderId} created by {userId}");

// ✅ structured logging, Seq / ELK can query by OrderId
_logger.LogInformation("Order {OrderId} created by {UserId}", orderId, userId);
```

**A `catch` that handles the error logs it once, with the exception object** (canonical rule: `principles.md` → *P0 — Exception / Error Handling*):
```csharp
// ❌ swallowed
try { await _repo.SaveAsync(order); }
catch (Exception) { }

// ❌ message only, no stack trace
catch (Exception ex) { _logger.LogError("Save failed"); }

// ❌ log-and-rethrow: the boundary above will log again (double-logging)
catch (Exception ex) { _logger.LogError(ex, "Save failed"); throw; }

// ✅ handling boundary: exception object + business context, logged once
catch (Exception ex)
{
    _logger.LogError(ex, "Failed to save order {OrderId} for user {UserId}", order.Id, order.UserId);
    return SaveResult.Failed(order.Id);
}

// ✅ not the handling boundary: propagate without logging
catch (Exception ex) { throw new OrderPersistenceException(order.Id, ex); }
```

**CorrelationId / TraceId via `ILogger.BeginScope`:**
```csharp
using (_logger.BeginScope(new { CorrelationId = correlationId }))
{
    _logger.LogInformation("Calling payment service for Order {OrderId}", orderId);
}
```

---

## Race Condition — C# Specifics

### Async/Await Race
```csharp
// ❌ read-then-write across awaits is not atomic
var balance = await _repo.GetBalanceAsync(userId);
await _repo.UpdateBalanceAsync(userId, balance - amount);

// ✅ use DB transaction
await using var tx = await _ctx.Database.BeginTransactionAsync(IsolationLevel.RepeatableRead);
await tx.CommitAsync();
```

### Static Mutable Fields
```csharp
// ❌ non-atomic increment on static field
private static int _orderCount = 0;
public void Process() { _orderCount++; }

// ✅ Interlocked
Interlocked.Increment(ref _orderCount);
```

---

## Exception Handling — C# Specifics

```csharp
// ❌ throw ex — truncates stack trace
catch (Exception ex) { throw ex; }

// ✅ throw — preserves full stack trace
catch (Exception ex)
{
    _logger.LogError(ex, "Failed to process order {OrderId}", orderId);
    throw;
}

// ✅ using declaration (C# 8+) for resource cleanup
await using var stream = new FileStream(path, FileMode.Open);
```

---

## Performance — C# Specifics

### EF Core N+1
```csharp
// ❌ N+1: each order queries customer separately
var orders = await _ctx.Orders.ToListAsync();
foreach (var order in orders)
    var customer = await _ctx.Customers.FindAsync(order.CustomerId);

// ✅ single JOIN
var orders = await _ctx.Orders.Include(o => o.Customer).ToListAsync();
```

### Load-then-filter
```csharp
// ❌ loads entire table then filters in memory
var expired = (await _ctx.Orders.ToListAsync())
    .Where(o => o.ExpiredAt < DateTime.UtcNow);

// ✅ filter at DB
var expired = await _ctx.Orders
    .Where(o => o.ExpiredAt < DateTime.UtcNow)
    .ToListAsync();
```

---

---

## Brace Style — C# Specifics

**Always use braces `{}` for control flow blocks, even with a single statement:**
```csharp
// ❌ no braces — easy to introduce bugs when adding a second statement
if (order == null)
    return;

for (var i = 0; i < items.Count; i++)
    Process(items[i]);

// ✅ always braces
if (order == null)
{
    return;
}

for (var i = 0; i < items.Count; i++)
{
    Process(items[i]);
}
```

Applies to: `if`, `else`, `else if`, `for`, `foreach`, `while`, `do`.

> Unlike Go (`gofmt` enforces this automatically), C# does not enforce brace style at the compiler or formatter level — reviewers must catch violations manually.

---

## Switch / Pattern Matching — C# Specifics

**Prefer switch expression over if-else chains for type/value dispatch:**
```csharp
// ❌ if-else chain — verbose, easy to miss a case
if (status == "pending")
    return HandlePending(order);
else if (status == "confirmed")
    return HandleConfirmed(order);
else if (status == "shipped")
    return HandleShipped(order);
else
    throw new InvalidOperationException($"Unknown status: {status}");

// ✅ switch expression — concise, compiler warns on missing cases (with enum)
return status switch
{
    "pending"   => HandlePending(order),
    "confirmed" => HandleConfirmed(order),
    "shipped"   => HandleShipped(order),
    _ => throw new InvalidOperationException($"Unknown status: {status}")
};
```

**Use pattern matching for type checks and null guards:**
```csharp
// ❌ cast + null check
if (result is OrderResult)
{
    var order = (OrderResult)result;
    Process(order);
}

// ✅ pattern matching with variable binding
if (result is OrderResult order)
{
    Process(order);
}

// ✅ switch with type patterns
return action switch
{
    CreateAction create => HandleCreate(create),
    UpdateAction update => HandleUpdate(update),
    DeleteAction delete => HandleDelete(delete),
    _ => throw new InvalidOperationException($"Unhandled action: {action.GetType().Name}")
};
```

**Use property patterns for complex conditions:**
```csharp
// ❌ nested if conditions
if (order.Status == "confirmed" && order.Total > 1000 && order.IsPriority)
    ApplyDiscount(order);

// ✅ property pattern — reads like a spec
if (order is { Status: "confirmed", Total: > 1000, IsPriority: true })
    ApplyDiscount(order);
```

**Switch on enum must handle all cases or have an explicit default with throw:**
```csharp
// ❌ missing cases silently fall through
return severity switch
{
    Severity.Error => "🔴",
    Severity.Warning => "🟡",
    // Severity.Info is silently unhandled
};

// ✅ exhaustive — throws on unhandled
return severity switch
{
    Severity.Error   => "🔴",
    Severity.Warning => "🟡",
    Severity.Info    => "🔵",
    _ => throw new ArgumentOutOfRangeException(nameof(severity))
};
```

---

## Async/Await — C# Specifics

```csharp
// ❌ async void — exception cannot be caught by caller
public async void ProcessOrder() { await DoWorkAsync(); }

// ✅ async Task
public async Task ProcessOrderAsync() { await DoWorkAsync(); }

// ❌ unnecessary async wrapper
public async Task<string> GetNameAsync() => await _repo.GetNameAsync();

// ✅ return Task directly
public Task<string> GetNameAsync() => _repo.GetNameAsync();

// ❌ .Result / .Wait() in async context — deadlock risk
var result = _service.GetAsync().Result;
```

---

## DI — C# Specifics

```csharp
// ❌ constructor creates dependencies directly — untestable
public OrderService(IConfiguration config)
{
    _db = new SqlConnection(config["DB:Connection"]);
}

// ✅ constructor only receives injected dependencies
public OrderService(IRepository<Order> repo, ILogger<OrderService> logger)
{
    _repo = repo;
    _logger = logger;
}
```

---

## Test Determinism — C# Specifics

> Canonical rule: `principles.md` → *P1 — Component Test* → *Deterministic Time*.

### Inject `TimeProvider` (.NET 8), don't read the clock
```csharp
// ❌ DateTime.UtcNow buried in logic — tests can't control expiry
public bool IsExpired() => DateTime.UtcNow > _expiresAt;

// ✅ injected TimeProvider — FakeTimeProvider drives time in tests
public OrderSession(TimeProvider clock) => _clock = clock;
public bool IsExpired() => _clock.GetUtcNow() > _expiresAt;

// test (Microsoft.Extensions.TimeProvider.Testing):
var clock = new FakeTimeProvider();
clock.Advance(TimeSpan.FromHours(2));
```

### No `Task.Delay` for synchronization
```csharp
// ❌ bets on scheduler timing — flakes on loaded CI
await Task.Delay(100);
Assert.True(worker.IsRunning);

// ✅ await an observable signal; real time only as deadlock backstop
await worker.Started.WaitAsync(TimeSpan.FromSeconds(5));
```

> See `principles.md` for general Separation of Concerns / Single Responsibility rules.
