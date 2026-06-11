# Module 05 — State & Data Flow

By now you have a feature that loads real data from the network. But *how* does the UI know to redraw when `items` changes? Why is `HomeViewModel` marked `@Observable` and `@MainActor`? What happens if you still need to ship to iOS 16? This module is a deep dive into the Observation framework and the patterns the templates use to move state from your view models into your views — correctly, efficiently, and safely.

**What you'll learn**

- How `@Observable` works under the hood, and why the templates prefer it.
- Why view models are `@MainActor`, and what that buys you.
- How SwiftUI views observe only the properties they actually read.
- The three ways to get a view model into a view: `init`, `@State`, and `@Environment`.
- Modeling loading / loaded / error as a single `ViewState<T>` enum.
- The legacy `ObservableObject` / `@Published` model, and exactly how to convert a view model for pre-iOS 17 / macOS 14 targets — shown side by side.
- `@Bindable` for two-way bindings into an `@Observable` object.
- Where shared, app-level state lives (an `@Observable AppModel` in the environment).

**Prerequisites**

- You've completed [Module 04 — The Networking Layer](04-the-networking-layer.md). You should have `HomeViewModel` loading items and surfacing errors.
- You recognize the `HomeViewModel` from the templates: an `@Observable @MainActor final class` with `items`, `isLoading`, and `errorMessage`.

---

## The view model we're studying

Here's the model the rest of this module refers to, exactly as it ships in `templates/Swift-SwiftUI/Features/Home/HomeViewModel.swift`:

```swift
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
}
```

Two macros do the heavy lifting: `@Observable` and `@MainActor`. Let's take them in turn.

---

## Step 1 — How `@Observable` works

`@Observable` is a macro from Apple's **Observation** framework (iOS 17 / macOS 14+). At compile time it rewrites your class so that:

- Each stored property's storage is routed through an `ObservationRegistrar`.
- Reading a property registers the current observation context as a dependency of *that specific property*.
- Writing a property notifies only the observers that read it.

You don't see any of this — your code still says `var items: [Item] = []`. But the macro expands it into something equivalent to a getter that calls `access(keyPath:)` and a setter that calls `withMutation(keyPath:)`. The practical consequences are what matter:

1. **No property wrappers on your model.** No `@Published`. Plain `var` is observable.
2. **Per-property tracking.** SwiftUI knows the difference between "`items` changed" and "`isLoading` changed."
3. **Computed properties just work.** A computed `var hasItems: Bool { !items.isEmpty }` is tracked because reading it reads `items`.
4. **Works with any reference type**, not only SwiftUI views — you can observe an `@Observable` from `withObservationTracking` anywhere.

### Why the templates use it

The templates target modern OS versions and prefer Observation because it is **less error-prone and more efficient** than the legacy `ObservableObject`: you can't forget a `@Published`, nested-model changes propagate naturally, and views re-render far less often (see Step 3). The single annotation `@Observable` replaces conformance plus a wrapper on every property.

The template even documents the fallback inline — note the comment at the top of `HomeViewModel.swift`:

```swift
// NOTE: This uses the Observation framework (@Observable), available on
// iOS 17 / macOS 14+. For earlier deployment targets, replace `@Observable`
// with `: ObservableObject` and annotate the published properties with
// `@Published`, then observe with `@StateObject`/`@ObservedObject` in the view.
```

We'll do exactly that conversion in Step 6.

---

## Step 2 — Why `@MainActor`?

UI state must be mutated on the main thread. `@MainActor` on the class isolates *every* property and method to the main actor, so:

- `items`, `isLoading`, and `errorMessage` are always read and written on the main thread — no torn reads, no "Publishing changes from background threads" warnings.
- `load()` runs on the main actor. The `await api.fetchItems()` call hops off to the `actor APIClient` to do the network I/O, then hops *back* to the main actor to assign `items`. You never manage threads by hand.
- The compiler enforces it. If you tried to touch `items` from a background context without `await`, Swift 6 would refuse to build.

This is the division of labor the templates establish: **actors (like `APIClient`) own I/O and background work; `@MainActor` view models own UI state.** The `await` boundary between them is where the thread hop happens, and it's checked at compile time.

---

## Step 3 — Views observe only what they read

This is the headline efficiency win of Observation. A SwiftUI view's `body` automatically tracks exactly the `@Observable` properties it reads during evaluation — nothing more.

```swift
// In HomeView.swift
struct HomeView: View {
    let viewModel: HomeViewModel

    var body: some View {
        // This body reads `isLoading`, `errorMessage`, and `items`.
        if viewModel.isLoading {
            ProgressView()
        } else if let message = viewModel.errorMessage {
            Text(message)
        } else {
            List(viewModel.items) { item in
                Text(item.title)
            }
        }
        .task { await viewModel.load() }
    }
}
```

Suppose a different view reads only `viewModel.items`. When `isLoading` flips true and back to false during a load, **that view does not re-evaluate its body**, because it never read `isLoading`. With the legacy `ObservableObject`, *any* `@Published` change invalidated *every* view observing the object. Observation makes invalidation precise and per-property, so large screens redraw far less.

You don't opt into this — reading the property inside `body` is the subscription. Read it conditionally (inside an `if`) and you're only subscribed on the branches where you actually read it.

---

## Step 4 — Getting a view model into a view

There are three idioms; choose based on **who owns the object's lifetime**.

### a) Plain `let` via `init` — the view doesn't own it

When a parent creates and owns the view model and just hands it down, a plain `let` is enough. The view reads it; it doesn't need to create or persist it.

```swift
struct HomeView: View {
    let viewModel: HomeViewModel   // owned by the parent
    var body: some View { /* reads viewModel.* */ }
}
```

This is the simplest option and is correct whenever something *above* this view holds the model for as long as the view lives.

### b) `@State` — the view owns and persists it

When the **view itself** should create the model and keep it alive across body re-evaluations, use `@State`. With Observation, `@State` is the correct wrapper for an `@Observable` object the view owns (this replaces the old `@StateObject`).

```swift
struct HomeScreen: View {
    @State private var viewModel: HomeViewModel

    init(api: any APIClientProtocol) {
        _viewModel = State(initialValue: HomeViewModel(api: api))
    }

    var body: some View { HomeView(viewModel: viewModel) }
}
```

`@State` guarantees the instance is created once and survives re-renders. Use it at the point in the tree where the model is born.

### c) `@Environment` — shared down a subtree

For state many views need, inject the `@Observable` object into the environment and read it with `@Environment(_:)`. We cover this in Step 8.

```swift
struct ProfileBadge: View {
    @Environment(AppModel.self) private var app
    var body: some View { Text(app.currentUser?.name ?? "Guest") }
}
```

Rule of thumb: **`init`/`let`** when a parent owns it, **`@State`** when the view owns it, **`@Environment`** when a subtree shares it.

---

## Step 5 — Modeling state as `ViewState<T>`

`HomeViewModel` uses three independent properties — `items`, `isLoading`, `errorMessage` — which is clear and works well. But it technically allows nonsensical combinations (loading *and* an error *and* items, all at once). For more complex screens, a single enum makes the states mutually exclusive and impossible to misrepresent:

```swift
// A reusable view-state enum.
enum ViewState<T> {
    case idle
    case loading
    case loaded(T)
    case failed(String)
}
```

A view model built on it:

```swift
@Observable
@MainActor
final class HomeViewModel {
    private(set) var state: ViewState<[Item]> = .idle
    private let api: any APIClientProtocol

    init(api: any APIClientProtocol) { self.api = api }

    func load() async {
        state = .loading
        do {
            let items = try await api.fetchItems()
            state = .loaded(items)
        } catch is CancellationError {
            // leave prior state
        } catch {
            let message = (error as? APIError)?.errorDescription
                ?? error.localizedDescription
            state = .failed(message)
        }
    }
}
```

And the view becomes an exhaustive `switch` — the compiler won't let you forget a case:

```swift
var body: some View {
    switch viewModel.state {
    case .idle, .loading:
        ProgressView()
    case .loaded(let items):
        List(items) { Text($0.title) }
    case .failed(let message):
        Text(message)
    }
    .task { await viewModel.load() }
}
```

Use the three-property style for simple screens (it's what the template ships); reach for `ViewState<T>` when the combinations start to matter. Both are idiomatic.

---

## Step 6 — The legacy `ObservableObject` model, side by side

If you must support **iOS 16 / macOS 13 or earlier**, `@Observable` isn't available. You fall back to `ObservableObject` + `@Published`. Here is the exact conversion of `HomeViewModel`, shown next to the modern version.

**Modern — Observation (iOS 17 / macOS 14+):**

```swift
import Foundation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let api: any APIClientProtocol
    init(api: any APIClientProtocol) { self.api = api }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await api.fetchItems()
        } catch is CancellationError {
        } catch {
            errorMessage = (error as? APIError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
```

**Legacy — ObservableObject (iOS 13–16 / macOS 10.15–13):**

```swift
import Foundation
import Combine   // ObservableObject lives in Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let api: any APIClientProtocol
    init(api: any APIClientProtocol) { self.api = api }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await api.fetchItems()
        } catch is CancellationError {
        } catch {
            errorMessage = (error as? APIError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
```

What changed, precisely:

| Concern | Observation (`@Observable`) | Legacy (`ObservableObject`) |
| --- | --- | --- |
| Class annotation | `@Observable` | `: ObservableObject`, `import Combine` |
| Observable properties | plain `var` | each needs `@Published` |
| View ownership (view creates it) | `@State private var vm` | `@StateObject private var vm` |
| View receives it from parent | `let vm` | `@ObservedObject var vm` |
| Shared in environment | `.environment(model)` + `@Environment(Type.self)` | `.environmentObject(model)` + `@EnvironmentObject` |
| Two-way binding | `@Bindable` (or `@State`) | `@ObservedObject` / `@StateObject` provide `$` directly |
| Re-render granularity | per property read in `body` | any `@Published` change invalidates all observers |

The corresponding view sites for the legacy version:

```swift
// View that owns the model:
@StateObject private var viewModel = HomeViewModel(api: api)

// View that receives it from a parent:
@ObservedObject var viewModel: HomeViewModel
```

The business logic — `load()`, the error mapping, `@MainActor` isolation — is identical. Only the observation plumbing differs. That's why the template ships the modern version and documents the swap in a comment: migrating is mechanical.

> Tip: keep your `import` and annotations in one place so the swap is a small diff. The `async`/`await` code, the `APIClientProtocol` dependency, and the `defer { isLoading = false }` pattern carry over unchanged.

---

## Step 7 — `@Bindable` for two-way bindings

Reading `@Observable` properties is automatic. But controls like `TextField`, `Toggle`, and `Picker` need a `Binding<T>` to write back. `@Bindable` produces those bindings from an `@Observable` object.

Say you add an editable search field to a view model (note: make the property non-`private(set)` so it can be bound):

```swift
@Observable
@MainActor
final class SearchViewModel {
    var query: String = ""        // writable, so a TextField can bind to it
    private(set) var results: [Item] = []
    // ...
}
```

Bind to it with `@Bindable`:

```swift
struct SearchBar: View {
    @Bindable var viewModel: SearchViewModel   // received from a parent

    var body: some View {
        TextField("Search", text: $viewModel.query)
    }
}
```

The `$viewModel.query` syntax gives you a `Binding<String>` straight from the `@Observable` object. When the view *owns* the object via `@State`, you can derive bindings inline without `@Bindable`:

```swift
@State private var viewModel = SearchViewModel(/* ... */)
// inside body:
@Bindable var vm = viewModel
TextField("Search", text: $vm.query)
```

Reach for `@Bindable` whenever a child view needs to write into an `@Observable` it didn't create. (In the legacy model, `@StateObject`/`@ObservedObject` already vend `$`-bindings, so there's no `@Bindable` equivalent — that's one of the table rows above.)

---

## Step 8 — Where app-level shared state lives

Feature view models like `HomeViewModel` are local — created with the screen, gone when it's dismissed. Some state, though, is *global*: the signed-in user, a theme, a feature-flag set, an app-wide router. Model that as a single `@Observable` `AppModel` and put it in the environment at the root.

```swift
// AppModel.swift
@Observable
@MainActor
final class AppModel {
    var currentUser: User?
    var theme: Theme = .system
    let api: any APIClientProtocol

    init(api: any APIClientProtocol) {
        self.api = api
    }
}
```

Inject it once, at the top of the app:

```swift
@main
struct MyApp: App {
    @State private var appModel = AppModel(api: APIClient())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)   // available to the whole tree
        }
    }
}
```

Any descendant reads it with `@Environment` — and, thanks to per-property tracking, only re-renders when the *specific* fields it reads change:

```swift
struct ThemedRoot: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        RootView()
            .preferredColorScheme(app.theme.colorScheme)  // re-renders only on theme change
    }
}
```

A clean architecture, then, layers state by lifetime:

- **App-level** (`AppModel`) — lives for the whole session, in the environment. Often holds shared dependencies like the `APIClient`, which feature view models pull from.
- **Feature-level** (`HomeViewModel`) — lives with one screen, created via `@State` or injected by a parent.
- **View-local** (`@State var isExpanded`) — ephemeral UI state owned by a single view.

Keep each piece at the lowest layer that needs it. Promote to the environment only when genuinely shared; otherwise you trade clarity for global coupling.

---

## Try it yourself

1. **Prove per-property tracking.** Add a `Text("\(viewModel.items.count) items")` to one subview and `if viewModel.isLoading { ProgressView() }` to another. Add `print` statements in each `body` and watch which re-evaluates during a load. Confirm the count view stays quiet while `isLoading` toggles.
2. **Refactor to `ViewState<T>`.** Convert `HomeViewModel` from the three-property style to the `ViewState<[Item]>` enum from Step 5, and switch the view to an exhaustive `switch`.
3. **Do the legacy conversion.** Make a copy of `HomeViewModel` and convert it to `ObservableObject` + `@Published` per Step 6. Build it against an iOS 16 deployment target and confirm the view sites (`@StateObject` / `@ObservedObject`) compile.
4. **Add a binding.** Give `HomeViewModel` a writable `var showsSubtitles = false` and a `Toggle("Show subtitles", isOn: $viewModel.showsSubtitles)` via `@Bindable`.
5. **Introduce an `AppModel`.** Create the `@Observable AppModel` from Step 8, move the `APIClient` into it, and have a `HomeScreen` build its `HomeViewModel(api: app.api)` from the environment.

## Recap

- `@Observable` rewrites your class to track property access through an `ObservationRegistrar`, giving plain `var`s precise, per-property observation — no `@Published`, no boilerplate.
- `@MainActor` isolates view-model state to the main thread; actors like `APIClient` own background I/O, and the `await` boundary is the checked thread hop.
- SwiftUI views observe only the properties their `body` reads, so unrelated changes don't trigger re-renders.
- Choose `init`/`let` (parent owns), `@State` (view owns), or `@Environment` (subtree shares) to deliver a model into a view.
- A `ViewState<T>` enum makes loading/loaded/error mutually exclusive for complex screens; the three-property style is fine for simple ones.
- Converting to the legacy `ObservableObject` model is mechanical: add the conformance and `@Published`, switch to `@StateObject`/`@ObservedObject`, and use `.environmentObject`. The logic is unchanged.
- `@Bindable` vends two-way bindings from an `@Observable` object the view didn't create.
- App-level state lives in an `@Observable AppModel` injected at the root with `.environment(_:)`, layered by lifetime above feature and view-local state.

**Next:** [Module 06 — Navigation & Routing](06-navigation-and-routing.md)
