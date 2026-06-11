# Module 08 — Dependency Injection & Architecture

You've been using a particular architecture this whole course without naming it.
`HomeViewModel` doesn't create an `APIClient` — it *receives* one. `AppEntry`
builds that client once and passes it down. Settings persistence hides behind a
keys catalog. These aren't accidents; they're a deliberate, testable design that
the templates encode so your app stays flexible as it grows.

This module names the pattern, explains *why* each piece exists, and shows how to
scale it from a three-screen template to a real, multi-feature app: protocol-based
dependency injection, a composition root, the SwiftUI `Environment` for app-wide
services, Swift 6 concurrency for services, a repository/service layer, and
module organization. We close with how MVVM (the SwiftUI templates) compares to
MVC (the UIKit/ObjC templates) and to a coordinator pattern.

**What you'll learn**

- Why view models depend on `APIClientProtocol`, not the concrete `actor APIClient`.
- Constructor (initializer) injection into `@Observable @MainActor` view models.
- The **composition root**: building live dependencies once at `App/AppEntry.swift`.
- Sharing app-wide services through the SwiftUI **`Environment`**.
- Making services **`Sendable`** / actor-isolated for Swift 6's strict concurrency.
- Introducing a **service / repository layer** between view models and the API.
- Organizing code at scale: feature folders, then feature modules / Swift Packages.
- **MVVM vs MVC vs coordinator** — what each template uses and why.

**Prerequisites**

- [Module 07 — Persistence & Storage](07-persistence-and-storage.md). We'll inject
  the `KeychainStore` / `AuthTokenStore` from that module into a service here.
- Familiarity with `HomeViewModel`, `APIClient`, and `App/AppEntry.swift` from the
  `Swift-SwiftUI` template (all ten templates build green in CI).

---

## Step 1 — Depend on the protocol, not the actor

Open `Core/Networking/APIClient.swift`. The networking layer is built in three
pieces, and the ordering is the whole lesson:

```swift
// Core/Networking/APIClient.swift  (abridged, existing)

/// Abstraction over the networking layer. Conformers must be `Sendable`.
protocol APIClientProtocol: Sendable {
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint) async throws -> T
    func fetchItems() async throws -> [Item]
}

/// Default URLSession-backed client. An `actor` so its config is isolated.
actor APIClient: APIClientProtocol { /* ... */ }

/// In-memory client for previews and tests.
final class MockAPIClient: APIClientProtocol, @unchecked Sendable { /* ... */ }
```

The protocol comes first, and `HomeViewModel` depends on **the protocol**:

```swift
// Features/Home/HomeViewModel.swift  (existing)
private let api: any APIClientProtocol

init(api: any APIClientProtocol) {
    self.api = api
}
```

Why not just hold a concrete `APIClient`? Three reasons:

1. **Testability.** A test injects `MockAPIClient` and controls the response —
   no real network, no flakiness. `HomeViewModelTests` does exactly this.
2. **Previews.** A SwiftUI `#Preview` injects a mock with sample data so the
   canvas renders offline and instantly.
3. **Substitutability.** Swap the live client for a logging decorator, a cached
   client, or a different backend without touching a single view model.

This is the **Dependency Inversion Principle**: high-level policy (the view
model's "load items, show errors" logic) shouldn't depend on a low-level detail
(URLSession plumbing). Both depend on the abstraction, `APIClientProtocol`.

> **`any` vs `some`.** The template writes `any APIClientProtocol` — an *existential*
> — because the concrete type is chosen at runtime (live in the app, mock in
> tests). That dynamism is the entire point of DI, so the existential's small
> overhead is exactly what you want here.

---

## Step 2 — Constructor injection into view models

The template injects dependencies through the **initializer** — "constructor
injection." It's the clearest form: a view model's `init` signature is an honest,
compiler-enforced list of everything it needs.

```swift
// Features/Home/HomeViewModel.swift  (existing)
@Observable
@MainActor
final class HomeViewModel {
    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let api: any APIClientProtocol

    init(api: any APIClientProtocol) {
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await api.fetchItems()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
```

Note the annotations — they're load-bearing:

- **`@Observable`** (the Observation framework, iOS 17 / macOS 14+) makes the
  stored properties observable so the view re-renders when they change.
- **`@MainActor`** pins the view model to the main thread. UI state is only ever
  mutated on the main actor, which is why `load()` can `await` a background
  `actor` call and still assign `items` safely.

The view holds the view model in `@State` and passes the dependency at the call
site:

```swift
// Features/Settings/SettingsView.swift  (existing)
@State private var viewModel: SettingsViewModel

init(viewModel: SettingsViewModel) {
    _viewModel = State(initialValue: viewModel)
}
```

Avoid the alternatives: a **singleton** (`APIClient.shared`) that the view model
reaches for internally is invisible in the `init` and impossible to swap in a
test; a **property injection** (set after construction) leaves a window where the
dependency is `nil`. Constructor injection has neither problem.

---

## Step 3 — The composition root at the app entry point

If view models receive their dependencies, *someone* has to create the real ones.
That someone is the **composition root** — the single place that knows about
concrete types and wires the object graph together. In the templates it's
`App/AppEntry.swift`:

```swift
// App/AppEntry.swift  (existing)
@main
struct AppEntry: App {
    @State private var router = AppRouter()

    /// A single shared API client. In a larger app you'd resolve this from a DI
    /// container; here we inject the concrete client (swap with `MockAPIClient()`
    /// for offline/UI testing).
    @State private var apiClient: any APIClientProtocol = APIClient()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                HomeView(viewModel: HomeViewModel(api: apiClient))
                    .navigationDestination(for: AppRouter.Route.self) { route in
                        destination(for: route)
                    }
            }
            .environment(router)
        }
    }

    @ViewBuilder
    private func destination(for route: AppRouter.Route) -> some View {
        switch route {
        case .home:
            HomeView(viewModel: HomeViewModel(api: apiClient))
        case .settings:
            SettingsView(viewModel: SettingsViewModel())
        case .detail(let id):
            DetailPlaceholderView(itemID: id)
        }
    }
}
```

Two principles to take from this:

- **Build live dependencies once.** `apiClient` is created a single time and held
  in `@State` so SwiftUI keeps one instance alive for the scene's lifetime. Every
  `HomeViewModel(api: apiClient)` shares it — you don't spin up a new client per
  screen.
- **Concrete types live only here.** `APIClient()` is named exactly once, at the
  root. Push `MockAPIClient()` in for a UI test build and the entire app runs
  offline, no other file changed. That's the payoff of Steps 1–2.

> **Toward a DI container.** For three dependencies, hand-wiring in `AppEntry` is
> perfect — don't add a framework you don't need. When the graph grows to a dozen
> services with interdependencies, introduce a small `AppDependencies` struct (or
> a lightweight container) that constructs them in order and hands them to the
> root view. The composition root just moves into that type; the principle is
> unchanged.

A minimal `AppDependencies` looks like:

```swift
// App/AppDependencies.swift
@MainActor
struct AppDependencies {
    let apiClient: any APIClientProtocol
    let authTokens: AuthTokenStore   // from Module 07

    static func live() -> AppDependencies {
        let tokens = AuthTokenStore()
        return AppDependencies(
            apiClient: APIClient(),
            authTokens: tokens
        )
    }
}
```

`AppEntry` then holds `@State private var deps = AppDependencies.live()` and reads
`deps.apiClient` wherever it builds a view model.

---

## Step 4 — App-wide services via the SwiftUI Environment

Constructor injection is ideal for a view model's *direct* collaborators. But some
services are needed deep in the tree, and threading them through every initializer
is tedious. For those, use the SwiftUI **`Environment`** — exactly how the
template already shares the router:

```swift
// AppEntry injects it once:
.environment(router)

// Any descendant reads it without it appearing in any init:
@Environment(AppRouter.self) private var router   // SettingsView
```

You can put any `@Observable` (or `Environment`-keyed) service in there. To share
the API client app-wide:

```swift
// In AppEntry's WindowGroup:
.environment(\.apiClient, apiClient)

// Define the key:
private struct APIClientKey: EnvironmentKey {
    static let defaultValue: any APIClientProtocol = MockAPIClient()
}
extension EnvironmentValues {
    var apiClient: any APIClientProtocol {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

// A view reads it:
@Environment(\.apiClient) private var apiClient
```

**When to use which.** Prefer **constructor injection for view models** — it keeps
their dependencies explicit and testable. Reach for the **`Environment` for
cross-cutting, app-wide services** (router, theme, analytics, a feature-flag
provider) that many unrelated views touch. The template uses both deliberately:
the router is environmental (everyone navigates); the API client is constructor-
injected into the one view model that needs it. Don't make *everything*
environmental — an implicit dependency is one you'll forget to mock.

---

## Step 5 — Sendable services for Swift 6 concurrency

The templates compile under Swift 6's strict concurrency checking, which means
every dependency that crosses a thread boundary must be `Sendable`. Look back at
how the template earns that guarantee:

```swift
protocol APIClientProtocol: Sendable { ... }     // the contract
actor APIClient: APIClientProtocol { ... }        // isolation via actor
final class MockAPIClient: APIClientProtocol, @unchecked Sendable { ... }
```

Three distinct strategies, each correct for its case:

1. **`actor` for mutable shared state.** `APIClient` holds configuration and
   serializes access — the compiler guarantees no data races. A view model
   `await`s its async methods from the `@MainActor`; the hop is automatic.
2. **Immutable value types are `Sendable` for free.** `KeychainStore` and
   `AuthTokenStore` from Module 07 are `struct`s with no mutable state, so they
   satisfy `Sendable` with no annotation and pass freely into the actor.
3. **`@unchecked Sendable` as an escape hatch.** `MockAPIClient` is a mutable
   class used only single-threaded in tests/previews, so it asserts safety
   manually. Use `@unchecked` sparingly and only when *you* can prove the safety
   the compiler can't.

The rule of thumb for a new service: make it an **`actor`** if it has mutable
state shared across tasks, a **`struct`/immutable type** if it doesn't, and pin
anything that touches UI to **`@MainActor`** (like every view model in the
templates). Then `: Sendable` on the protocol enforces it for all conformers.

---

## Step 6 — A service / repository layer as the app grows

Right now `HomeViewModel` calls `api.fetchItems()` directly. That's fine for one
endpoint. But as features pile up you'll find view models doing too much:
combining endpoints, caching, mapping DTOs to domain models, retrying. Pushing
all of that into view models makes them fat and hard to test.

Introduce a **repository** (a service layer) between view models and the API. It
owns the data-access policy; the view model just asks for what it needs:

```swift
// Features/Home/ItemRepository.swift
protocol ItemRepositoryProtocol: Sendable {
    func items(forceRefresh: Bool) async throws -> [Item]
}

/// Coordinates the network and the on-disk cache from Module 07.
actor ItemRepository: ItemRepositoryProtocol {
    private let api: any APIClientProtocol
    private let cache: FileStore          // FileStore from Module 07
    private var memory: [Item] = []

    init(api: any APIClientProtocol, cache: FileStore) {
        self.api = api
        self.cache = cache
    }

    func items(forceRefresh: Bool) async throws -> [Item] {
        if !forceRefresh, !memory.isEmpty { return memory }
        let fetched = try await api.fetchItems()
        memory = fetched
        try? cache.save(fetched, to: "items-cache.json")   // best-effort
        return fetched
    }
}
```

Now the view model depends on `ItemRepositoryProtocol` instead of the raw client:

```swift
@Observable @MainActor
final class HomeViewModel {
    private let repository: any ItemRepositoryProtocol

    init(repository: any ItemRepositoryProtocol) {
        self.repository = repository
    }

    func load() async {
        // ...same loading/error handling, now via the repository.
        items = try await repository.items(forceRefresh: false)
    }
}
```

Nothing else about the pattern changes: the protocol keeps it testable, the
composition root builds the live `ItemRepository(api:cache:)` and injects it. The
caching, the merge of network + disk, the DTO mapping — all of it lives in one
place the view model never sees. **Add this layer when a view model starts
juggling more than one source; don't add it preemptively** when a single
`api.fetchItems()` is all you need.

---

## Step 7 — Organizing code at scale

The templates use a **feature-folder** layout that already separates concerns:

```
App/        AppEntry.swift            // composition root, scene setup
Core/       Networking/  Storage/  Navigation/  Extensions/
Features/   Home/  Settings/         // each: View + ViewModel (+ repository)
Tests/      Unit/  UI/
```

This scales further along two axes:

- **More features → more folders under `Features/`.** Keep each feature
  self-contained: its views, view models, and repository live together, depending
  only on `Core` abstractions (`APIClientProtocol`, `KeychainStore`, `AppRouter`).
  A feature should never reach into another feature's internals.
- **A large app → Swift Packages (feature modules).** When the team and codebase
  grow, promote `Core` and each feature into local **Swift Packages**. Benefits:
  enforced boundaries (a feature can only see what a package *exports*), faster
  incremental builds (only changed modules recompile), and the ability to build a
  feature in isolation with its own preview app. A common split is a `CoreKit`
  package (networking, storage, models) that feature packages (`HomeFeature`,
  `SettingsFeature`) depend on, with the thin app target as the composition root
  that links them all.

The migration is mechanical *because* of the DI discipline: features already talk
through protocols, so moving them behind a package boundary mostly means deciding
what's `public`. Architecture you can split cleanly is architecture that scaled.

---

## Step 8 — MVVM vs MVC vs coordinator

The templates pick an architecture per platform; here's how they relate.

### MVVM — the SwiftUI templates

**Model–View–ViewModel.** The `View` is declarative and (nearly) logic-free; the
**`ViewModel`** (`@Observable @MainActor`) holds presentation state and talks to
services; the **Model** is your domain data (`Item`, `Note`). The view binds to
the view model, which is injected with protocol dependencies. This is what every
SwiftUI template uses, and what this whole course has been building.

- **Strengths:** view models are plain objects you can unit-test without a UI
  (see `HomeViewModelTests`); pairs naturally with SwiftUI's data flow.
- **Watch for:** "massive view models" — the cure is the service/repository layer
  from Step 6.

### MVC — the UIKit / Objective-C templates

**Model–View–Controller**, UIKit's native pattern. A `UIViewController` owns its
views and mediates between them and the model. The UIKit/AppKit templates follow
this — and note from Module 07 they store preferences in a `UserDefaultsManager`
rather than `@AppStorage`, because `@AppStorage` is SwiftUI-only.

- **Strengths:** idiomatic for UIKit/AppKit; the framework is built around it.
- **Watch for:** the classic "massive view controller," where the controller
  accumulates networking, layout, and navigation. The fix is the same DI: inject
  an `APIClientProtocol`, push logic into testable helpers, and consider a
  coordinator for navigation.

### Coordinator — orthogonal, for navigation

A **coordinator** isn't a rival to MVVM/MVC; it's a complement that pulls
*navigation* out of views and controllers into a dedicated object. The SwiftUI
templates already do a lightweight version of this with **`AppRouter`**: the
`@Observable` router owns the `NavigationStack` path and the route graph, and
`AppEntry.destination(for:)` maps routes to views — so individual views don't know
the full navigation map (covered in Module 06).

- **Use it when:** flows get complex (auth → onboarding → main, deep links,
  modal flows), or you want navigation testable in isolation.
- **In UIKit:** a coordinator owns the `UINavigationController` and decides which
  controller comes next, keeping each controller ignorant of its neighbors.

### Picking one

You usually don't pick freely — **the platform picks for you**: SwiftUI ⇒ MVVM,
UIKit/AppKit ⇒ MVC. Layer a coordinator/router on top of either when navigation
outgrows ad-hoc pushes. Across all three, the constant is what this module is
really about: **inject dependencies through protocols and compose them at one
root.** That principle is what makes any of these architectures testable.

---

## Try it yourself

1. **Add a dependencies struct.** Introduce `AppDependencies.live()` (Step 3),
   hold it in `AppEntry`'s `@State`, and have every view-model construction read
   from it instead of the bare `apiClient`.
2. **Inject a second service.** Put `AuthTokenStore` (Module 07) into
   `AppDependencies` and pass it to a new `ProfileViewModel`; write a test that
   injects a `KeychainStore` over an empty in-memory state.
3. **Make the client environmental.** Implement the `\.apiClient`
   `EnvironmentKey` from Step 4 and refactor one view model construction to read
   it from `@Environment` instead of the initializer. Note what you gain and lose.
4. **Build the repository.** Implement `ItemRepository` from Step 6, switch
   `HomeViewModel` to depend on `ItemRepositoryProtocol`, and add a
   `MockItemRepository` so the existing `HomeViewModel` tests still pass with no
   network.
5. **Sketch a package split.** On paper, list which template files move into a
   `CoreKit` package and which `public` symbols each feature needs from it.

---

## Recap

- View models depend on **`APIClientProtocol`**, not `actor APIClient`, for
  testability, previews, and substitutability (dependency inversion).
- Dependencies arrive through **constructor injection** into `@Observable`
  `@MainActor` view models — explicit, compiler-checked, mockable.
- The **composition root** at `App/AppEntry.swift` builds live dependencies
  *once* and is the only place concrete types are named; an `AppDependencies`
  struct extends this cleanly as the graph grows.
- The SwiftUI **`Environment`** shares app-wide services (like `AppRouter`);
  constructor injection stays the default for a view model's direct collaborators.
- **Swift 6 concurrency**: `actor` for mutable shared state, immutable structs for
  free `Sendable`, `@MainActor` for UI, `@unchecked Sendable` only as a proven
  escape hatch — all enforced by `: Sendable` on the protocol.
- A **repository / service layer** absorbs caching and multi-source logic so view
  models stay thin; add it when a view model outgrows one source.
- Scale the **feature-folder** layout into **Swift Package feature modules** when
  the codebase grows — clean because DI already drew the boundaries.
- **MVVM** (SwiftUI), **MVC** (UIKit/AppKit), and the **coordinator/router**
  (navigation) all rest on the same foundation: protocol DI composed at one root.

You've reached the end of the architecture track. The templates encode these
choices so you can focus on features — and now you understand *why* each piece is
where it is, and how to grow it without rewrites.

**Next:** [Module 09 — Testing Your App](09-testing-your-app.md)
