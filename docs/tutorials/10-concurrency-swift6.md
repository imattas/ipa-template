# Module 10 — Concurrency with Swift 6

Swift 6 turns the concurrency rules you used to *hope* you got right into rules
the **compiler enforces**. Data races aren't runtime surprises anymore — they're
build errors. That's stricter, but it means once your code compiles in Swift 6
language mode, an entire class of crashes is gone.

This module is a practical tour of the concurrency the `Swift-SwiftUI` template
already uses: why `APIClient` is an `actor`, why `HomeViewModel` is `@MainActor`,
why `send<T: Decodable & Sendable>` needs that `Sendable`, and how to read and fix
the strict-concurrency errors this template hit on its way to building green.

## What you'll learn

- `async`/`await` basics and how they read
- **Structured concurrency**: `async let` and `TaskGroup`, with a worked parallel
  fetch in a view model
- **Actors** and actor isolation — why `APIClient` is an actor
- **`@MainActor`** and UI isolation — why view models are main-actor isolated
- **`Sendable`**, and why `send<T: Decodable & Sendable>` needs that constraint
- **`Task`**, cancellation, and the `.task` lifecycle in SwiftUI
- How to avoid data races
- The exact strict-concurrency errors this repo hit, and how to fix each class

## Prerequisites

- You've completed [Module 09 — Testing Your App](09-testing-your-app.md).
- The `Swift-SwiftUI` template open in Xcode 16+, **Swift 6 language mode**
  enabled (Build Settings → *Swift Language Version* → *Swift 6*).

---

## 1. `async`/`await` basics

An `async` function is one that may *suspend* — pause, let other work run, and
resume later — typically while waiting on I/O. You call it with `await`, which
marks the suspension point:

```swift
// Core/Networking/APIClient.swift
func fetchItems() async throws -> [Item] {
    try await send(.items)
}
```

Reading this top to bottom: `fetchItems` is `async` (it can suspend) and `throws`
(it can fail). The `await` says "this call may suspend here"; the `try` says "it
may throw here". Crucially, while suspended at an `await`, the thread is **not
blocked** — it's free to run other tasks. That's the whole point: concurrency
without manual thread juggling.

The view model consumes it the same way:

```swift
// Features/Home/HomeViewModel.swift
func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
        items = try await api.fetchItems()
    } catch is CancellationError {
        // Ignore cancellations (e.g. view dismissed mid-load).
    } catch {
        errorMessage = (error as? APIError)?.errorDescription
            ?? error.localizedDescription
    }
}
```

`await api.fetchItems()` suspends `load()` until the network call completes, then
resumes on the same actor (the main actor — see §4) with `items` assigned safely.

---

## 2. Structured concurrency: `async let` and `TaskGroup`

The calls above are *sequential* — one `await` after another. **Structured
concurrency** lets you run work in parallel while keeping a clear parent/child
scope: children can't outlive the parent, and cancelling the parent cancels the
children.

### `async let` — a fixed, small number of parallel tasks

Suppose your Home screen needs three things at once: items, a featured banner, and
the unread-count badge. Sequentially that's three round-trips back to back. With
`async let` they overlap:

```swift
// A new method you could add to HomeViewModel.
func loadDashboard() async {
    isLoading = true
    defer { isLoading = false }
    do {
        // All three requests start immediately and run concurrently.
        async let items: [Item]     = api.send(.items)
        async let banner: Banner    = api.send(.featuredBanner)
        async let unread: UnreadInfo = api.send(.unreadCount)

        // `await` here joins all three; we suspend until each is ready.
        self.items  = try await items
        self.banner = try await banner
        self.unread = try await unread
    } catch {
        errorMessage = (error as? APIError)?.errorDescription
            ?? error.localizedDescription
    }
}
```

`async let` binds a child task that starts *now*. You read its result with `await`
later. Three requests, roughly one request's worth of latency. Use this when the
number of parallel tasks is known and small.

### `TaskGroup` — a dynamic number of parallel tasks

When the count is dynamic — say, fetch the detail for each item id — use a task
group:

```swift
func fetchDetails(for ids: [Int]) async throws -> [Item] {
    try await withThrowingTaskGroup(of: Item.self) { group in
        for id in ids {
            group.addTask {
                // Each child runs concurrently; `self.api` is shared safely
                // because APIClientProtocol is Sendable (see §5).
                try await self.api.send(Endpoint(path: "/items/\(id)"))
            }
        }
        var results: [Item] = []
        for try await item in group {   // collect as each finishes
            results.append(item)
        }
        return results
    }
}
```

The group bounds the work: if any child throws, the rest are cancelled and the
error propagates out. Nothing leaks past the closure. Note results arrive in
*completion* order — sort afterward if you need input order.

---

## 3. Actors and actor isolation

An **actor** is a reference type that protects its mutable state by serializing
access: only one task touches an actor's stored properties at a time. That makes
data races on that state impossible — the compiler guarantees it.

That's exactly why `APIClient` is an actor:

```swift
// Core/Networking/APIClient.swift
actor APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    // ...
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T { /* ... */ }
}
```

Even though the stored properties here are `let`, modeling the client as an actor
gives it an **isolation domain**: as you grow it (add caching, an in-flight request
map, a token you refresh), that mutable state is automatically protected. From the
outside, every method becomes `async` — that's why callers write
`await api.fetchItems()`. The `await` is the compiler reminding you that you're
*hopping onto the actor* and may have to wait your turn.

Inside the actor, you access its own state synchronously and safely. Across the
boundary, you `await`.

---

## 4. `@MainActor` and UI isolation

UIKit and SwiftUI require that UI state changes happen on the **main thread**. The
`@MainActor` is a global actor representing exactly that thread. Annotating a type
with it means *all* its members run on the main actor:

```swift
// Features/Home/HomeViewModel.swift
@Observable
@MainActor
final class HomeViewModel {
    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
}
```

Because `HomeViewModel` is `@MainActor`, assigning `self.items = ...` inside
`load()` is guaranteed to happen on the main thread — so SwiftUI can observe and
re-render safely. You never have to write `DispatchQueue.main.async` again; the
isolation is part of the type.

This is also why, back in Module 09, the *test class* had to be `@MainActor` — to
touch a main-actor type's state, you must be on the main actor too.

The interplay with §3 is the key mental model:

- `await api.fetchItems()` hops **off** the main actor, onto the `APIClient` actor,
  to do networking.
- When it returns, `load()` resumes **back on the main actor**, so `items = ...` is
  main-thread-safe automatically.

Two isolation domains, one `await` bridging them. The compiler checks every hop.

---

## 5. `Sendable`, and why `send<T: Decodable & Sendable>` needs it

A value is **`Sendable`** if it's safe to pass across isolation boundaries — from
the `APIClient` actor back to the main actor, for instance. Value types of
`Sendable` parts are automatically `Sendable`; reference types generally are not
(another thread might mutate them).

Look at the generic signature:

```swift
protocol APIClientProtocol: Sendable {
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T
    func fetchItems() async throws -> [Item]
}
```

Two `Sendable`s here, both load-bearing:

1. **`APIClientProtocol: Sendable`** — `HomeViewModel` stores `any
   APIClientProtocol` and uses it from the main actor, while the concrete actor
   lives in its own domain. The client must be safe to share across domains, so
   the protocol requires `Sendable`. (`APIClient` is an actor, so it's `Sendable`
   for free; `MockAPIClient` is a class and opts in with `@unchecked Sendable`.)

2. **`T: Decodable & Sendable`** — `send` decodes a value *inside* the `APIClient`
   actor and **returns it across the boundary** to the caller. If `T` weren't
   `Sendable`, you could decode a mutable reference type on the actor, hand it to
   the main actor, and have both mutate it concurrently — a data race. The
   `Sendable` constraint makes the compiler reject that.

> **The real fix in this repo's history.** Early on, `send` was declared
> `func send<T: Decodable>(...)`. Under Swift 6 strict concurrency that failed to
> compile: *"Non-sendable type 'T' returned by actor-isolated function cannot
> cross actor boundary."* Adding `& Sendable` to the constraint is what made it
> build green — and it's why the domain model is declared
> `struct Item: Codable, Identifiable, Hashable, Sendable`. The `Sendable`
> conformance on `Item` is what lets `[Item]` satisfy `T: ... & Sendable`.

So this one constraint ties the whole pipeline together: an actor produces a value,
`Sendable` certifies it's safe to ship, and the main actor receives it without a
race.

---

## 6. `Task`, cancellation, and `.task` in SwiftUI

A `Task` is the unit of asynchronous work. SwiftUI's `.task` modifier creates one
tied to a view's lifetime — it starts when the view appears and is **cancelled
automatically when the view disappears**:

```swift
// Features/Home/HomeView.swift
List(viewModel.items) { item in
    Text(item.title)
}
.task {
    await viewModel.load()   // runs on appear; cancelled on disappear
}
```

This is why `load()` handles cancellation explicitly:

```swift
do {
    items = try await api.fetchItems()
} catch is CancellationError {
    // Ignore cancellations (e.g. view dismissed mid-load).
} catch { /* real error */ }
```

If the user navigates away while a load is in flight, SwiftUI cancels the `.task`,
the in-flight `await` throws `CancellationError`, and `load()` swallows it instead
of flashing a bogus error message. **Cancellation in Swift is cooperative**: it
sets a flag; your code checks it (or APIs like `URLSession` and `Task.sleep` check
it for you) and bails. Check it in long loops with `try Task.checkCancellation()`
or `if Task.isCancelled { return }`.

Don't reach for a manual `Task { }` in a view body when `.task` will do — the
modifier gives you lifetime management for free. Use a standalone `Task { }` for
fire-and-forget work triggered by, say, a button tap:

```swift
Button("Refresh") {
    Task { await viewModel.load() }
}
```

---

## 7. Avoiding data races

The rules above combine into a simple discipline:

- **Own each piece of mutable state with exactly one actor.** UI state →
  `@MainActor` (the view model). Networking state → the `APIClient` actor.
- **Cross boundaries only with `Sendable` values.** Value types (`Item`,
  `Endpoint`, `APIError`) travel freely; reference types need justification.
- **Let `await` mark every hop.** If there's no `await`, you're not crossing a
  boundary — and the compiler has already proven it's safe.
- **Prefer structured concurrency** (`async let`, `TaskGroup`) over detached
  `Task`s, so cancellation and error propagation are automatic.

Follow these and Swift 6's checker is your ally, not your obstacle.

---

## 8. Common Swift 6 strict-concurrency errors (and fixes)

These are the exact classes of error this template hit while reaching a green
build. You will see them too.

### A. Non-Sendable type crossing an actor boundary

> *"Non-sendable type 'T' returned by actor-isolated instance method cannot cross
> actor boundary."*

**Cause.** A value produced inside an actor is returned to a different isolation
domain, but its type isn't `Sendable`. This is the `send<T: Decodable>` story from
§5.

**Fix.** Constrain the generic (or conform the type) to `Sendable`:

```swift
// Before — fails in Swift 6:
func send<T: Decodable>(_ endpoint: Endpoint) async throws -> T

// After — builds:
func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T
```

…and make your models `Sendable`:

```swift
struct Item: Codable, Identifiable, Hashable, Sendable { /* ... */ }
```

### B. Calling a main-actor API from a nonisolated context

> *"Call to main actor-isolated instance method 'load()' in a synchronous
> nonisolated context."* (or *"...property 'items'..."*)

**Cause.** Touching `HomeViewModel` (which is `@MainActor`) from code that isn't on
the main actor — a `nonisolated` callback, a detached `Task`, or a test method that
forgot the annotation.

**Fix — option 1: annotate the context.** The test in Module 09 does this:

```swift
@MainActor
final class HomeViewModelTests: XCTestCase { /* ... */ }
```

**Fix — option 2: hop explicitly** from a context you can't annotate:

```swift
someNonisolatedCallback = {
    Task { @MainActor in
        await viewModel.load()
    }
}
```

The `Task { @MainActor in ... }` switches onto the main actor before touching the
view model. The `await` is the compiler making the hop visible.

### C. Capturing non-Sendable state in a concurrent closure

> *"Capture of 'self' with non-sendable type ... in a `@Sendable` closure."*

**Cause.** A `Task.addTask` or detached `Task` closure captures something that
isn't safe to send — often a non-`Sendable` reference type, or `self` of a class
that isn't isolated.

**Fix.** Capture `Sendable` values, or route through a properly isolated type. In
the `TaskGroup` example in §2, capturing `self.api` is fine *because*
`APIClientProtocol` is `Sendable` (§5). Had it not been, the group's child closures
wouldn't compile — which is the checker steering you toward the safe design.

### D. Mutable global / static state

> *"Static property '...' is not concurrency-safe because it is non-isolated global
> shared mutable state."*

**Cause.** A `static var` that any thread can read and write.

**Fix.** Isolate it to an actor (or `@MainActor`), make it a `let`, or — for the
narrow case of a test stub touched on one thread — opt out explicitly with
`nonisolated(unsafe)`, exactly as the `StubURLProtocol` in Module 09 does:

```swift
nonisolated(unsafe) static var stub: (status: Int, data: Data)?
```

Reach for `nonisolated(unsafe)` only when you can *prove* the access pattern is
race-free; for production state, prefer real isolation.

---

## Try it yourself

1. Add `loadDashboard()` to `HomeViewModel` using `async let` for two endpoints
   and verify both fire concurrently (give the `MockAPIClient` a `delay` and time
   the call — it should take ~one delay, not two).
2. Temporarily change `send<T: Decodable & Sendable>` back to `send<T: Decodable>`
   and read the exact error Swift 6 produces. Restore it.
3. Remove `@MainActor` from `HomeViewModelTests` (from Module 09) and observe error
   class **B**. Put it back.
4. Write a `fetchDetails(for:)` using `withThrowingTaskGroup` and add a unit test
   that asserts it returns one `Item` per id (sort the results, since group order
   is completion order).
5. Add `if Task.isCancelled { return }` inside a loop and trigger cancellation by
   wrapping the call in a `Task` you `.cancel()` immediately.

## Recap

- **`async`/`await`** lets functions suspend without blocking threads; `await`
  marks each suspension point.
- **Structured concurrency** — `async let` for a fixed small set, `TaskGroup` for a
  dynamic set — runs work in parallel with automatic cancellation and error
  propagation.
- **Actors** serialize access to their state; `APIClient` is an actor so its
  (growing) networking state is race-free, and callers `await` across the boundary.
- **`@MainActor`** pins `HomeViewModel` to the main thread so SwiftUI can observe
  its state safely; `await` bridges to and from the `APIClient` actor.
- **`Sendable`** certifies a value is safe to cross isolation domains;
  `send<T: Decodable & Sendable>` needs it because the actor *returns* `T` across a
  boundary — the real fix that made this repo build under Swift 6, alongside
  `Item: Sendable`.
- **`Task` and `.task`** tie async work to the SwiftUI view lifecycle; cancellation
  is cooperative, which is why `load()` ignores `CancellationError`.
- **Avoid data races** by owning state with one actor, crossing boundaries only with
  `Sendable` values, and preferring structured concurrency.
- The **four strict-concurrency error classes** above — non-Sendable across a
  boundary, main-actor calls from nonisolated contexts, non-Sendable captures, and
  mutable statics — are the ones this template hit, each with a concrete fix.

You've completed the core build track. From here, take what you've learned —
architecture, DI, testing, and Swift 6 concurrency — and ship something real on top
of the templates.

**Next:** [Module 11 — Design System & Accessibility](11-design-system-and-accessibility.md)
