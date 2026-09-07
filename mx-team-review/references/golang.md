# Go — Language-Specific Review Standards

> This file covers Go-specific patterns only.
> Cross-language principles (logging concepts, test coverage, comments, etc.) are in `principles.md`.

---

## Logging — Go Specifics

**Use `slog` (Go 1.21+) or `zap`, prohibit `fmt.Println` / `log.Printf`:**
```go
// ❌
fmt.Println("order created:", orderId)
log.Printf("error: %v", err)

// ✅ slog
slog.Info("order created", "order_id", orderId, "user_id", userId)
slog.Error("failed to process order", "order_id", orderId, "error", err)

// ✅ zap (high-performance scenarios)
logger.Info("order created", zap.String("order_id", orderId))
```

**TraceID via context:**
```go
traceID := ctx.Value(TraceIDKey).(string)
logger := slog.With("trace_id", traceID)
logger.Info("calling payment service", "order_id", orderId)
```

---

## Goroutine Leak (Go-specific P0)

### Goroutines must have explicit exit conditions
```go
// ❌ goroutine never exits
go func() {
    for { process() }
}()

// ✅ context-controlled lifecycle
go func() {
    for {
        select {
        case <-ctx.Done():
            return
        default:
            process()
        }
    }
}()
```

### Channel operations must consider blocking
```go
// ❌ unbuffered channel, sender blocks forever if receiver is gone
ch := make(chan Result)
go func() { ch <- doWork() }()

// ✅ buffered channel or select + ctx
ch := make(chan Result, 1)
```

### WaitGroup: `Done()` must be guaranteed via `defer`
```go
go func() {
    defer wg.Done()
    doRiskyWork()
}()
```

### HTTP Response Body must be closed
```go
resp, err := http.Get(url)
if err != nil { return err }
defer resp.Body.Close()
```

---

## Error Handling — Go Specifics

**Never ignore errors with `_`:**
```go
// ❌
os.Remove(tmpFile)
json.Unmarshal(data, &result)

// ✅
if err := os.Remove(tmpFile); err != nil {
    slog.Warn("failed to remove temp file", "path", tmpFile, "error", err)
}
```

**Error wrap with `%w` to preserve error chain:**
```go
// ❌ %v loses error chain
return fmt.Errorf("failed to save: %v", err)

// ✅ %w allows errors.Is / errors.As
return fmt.Errorf("save order %s: %w", orderID, err)
```

**Use sentinel errors or custom error types:**
```go
// sentinel
var ErrOrderNotFound = errors.New("order not found")

// custom type
type ValidationError struct {
    Field   string
    Message string
}
```

---

## Race Condition — Go Specifics

### Map concurrent access
```go
// ❌ map is not thread-safe, concurrent read+write panics
var cache = map[string]string{}

// ✅ sync.RWMutex
var mu sync.RWMutex
var cache = map[string]string{}

// ✅ sync.Map (read-heavy)
var cache sync.Map
```

### Package-level mutable variables
```go
// ❌ mutable global accessed by multiple goroutines
var globalConfig Config

// ✅ sync.Once
var configOnce sync.Once
configOnce.Do(func() { globalConfig = loadConfig() })
```

---

## Performance — Go Specifics

### Slice pre-allocation
```go
// ❌ triggers multiple realloc
var results []Order

// ✅ pre-allocate
results := make([]Order, 0, len(ids))
```

### HTTP Client reuse
```go
// ❌ new client per request
func callAPI(url string) {
    client := &http.Client{}
    resp, _ := client.Get(url)
}

// ✅ package-level or DI-injected
var httpClient = &http.Client{Timeout: 10 * time.Second}
```

### Avoid `fmt.Sprintf` in hot paths
```go
// ❌ reflection overhead
key := fmt.Sprintf("order:%s", id)

// ✅ direct concat
key := "order:" + id
```

---

## Interface Design — Go Specifics

### Small interfaces, defined by consumer
```go
// ❌ large interface defined by implementor
type OrderRepository interface { /* 10 methods */ }

// ✅ consumer defines only what it needs
type orderSaver interface {
    Save(ctx context.Context, order *Order) error
}
```

---

## Context — Go Specifics

```go
// ✅ context must be first parameter
func (s *OrderService) CreateOrder(ctx context.Context, req Request) error {}

// ❌ context stored in struct
type OrderService struct { ctx context.Context }

// ❌ nil context — panics on ctx.Done()
repo.Save(nil, order)

// ✅ check cancellation in loops
for _, item := range items {
    select {
    case <-ctx.Done():
        return ctx.Err()
    default:
    }
    process(ctx, item)
}
```

---

## Test Determinism — Go Specifics

> Canonical rule: `principles.md` → *P1 — Component Test* → *Deterministic Time*.

### Inject the clock, don't read it
```go
// ❌ time.Now() buried in logic — tests can't control expiry
func (s *Session) Expired() bool {
    return time.Now().After(s.expiresAt)
}

// ✅ injected now() — tests set the clock; prod wires time.Now
type Session struct {
    now func() time.Time
}
func (s *Session) Expired() bool {
    return s.now().After(s.expiresAt)   // comparing an injected instant is fine — the test chose now()
}
```

### Forbidden in `_test.go` (outside a `synctest` bubble)
`time.Now`, `time.Since`, `time.Until`, `time.Sleep`, `time.After`, `time.Tick`,
`time.NewTimer` / `time.NewTicker`, `context.WithTimeout` / `WithDeadline` used as
a wait, polling helpers (`require.Eventually`, `assert.Eventually`,
`EventuallyWithT`, gomega `Eventually`), and `Time.After` / `Before` / `Equal` /
`Sub` on values that came from the real clock. Each one ties the outcome to CPU
speed or scheduler load and each has flaked on loaded CI. Tests use fixed instants
(`time.Date(...)`) fed through the injected clock, or `testing/synctest` (Go 1.25+),
whose bubble runs the code under a fake clock so production timers and sleeps fire
instantly and deterministically.

Choose by what the code does with time: logic that depends on an instant (expiry,
scheduling windows) → inject `now`; code that drives its own timers, tickers or
timeouts (retry backoff, heartbeats) → run it under `synctest`, where
`context.WithTimeout` deadlines also follow the fake clock.

### No `time.Sleep` / `time.After` for synchronization
```go
// ❌ bets on scheduler timing — flakes on loaded CI
go worker.Start()
time.Sleep(100 * time.Millisecond)
require.True(t, worker.Running())

// ❌ still wall-clock: on a slow machine the timeout arm races the signal
select {
case <-worker.Ready():
case <-time.After(5 * time.Second):
    t.Fatal("worker never became ready")
}

// ✅ wait on the observable signal only; a hang is caught by the command-line `go test -timeout`
go worker.Start()
<-worker.Ready()
require.True(t, worker.Running())

// ✅ time-dependent logic under a fake clock — nothing waits for real time
synctest.Test(t, func(t *testing.T) {
    s := NewSession(24 * time.Hour) // production code may call time.Now / time.After
    time.Sleep(25 * time.Hour)      // inside the bubble: advances the fake clock, returns at once
    synctest.Wait()
    require.True(t, s.Expired())
})
```

### Deterministic environment — Go APIs
- Randomness: inject `*rand.Rand` or seed it (`rand.New(rand.NewSource(1))`); never assert on `uuid.New()` output.
- Environment and files: `t.Setenv`, `t.TempDir()` — the framework restores both after the test.
- Network: `net.Listen("tcp", "127.0.0.1:0")` or `httptest.NewServer`; never a fixed port.
- Leaks: `goleak.VerifyTestMain(m)` in `TestMain`, or a `synctest` bubble (fails if goroutines outlive it).
- CI invocation: `go test -race -shuffle=on -count=1 -timeout 10m ./...` — shuffle and count catch order dependence; `-timeout` is the only wall-clock backstop.
