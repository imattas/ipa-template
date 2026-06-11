# Module 06 — Navigation & Routing

In Module 05 you learned how state flows through `@Observable` view models and into views. Navigation is just another kind of state: *which screens are on the stack right now.* This template treats it exactly that way. Instead of scattering `NavigationLink`s through every view, it funnels all navigation through a single `AppRouter` that owns a `NavigationPath` and exposes a typed `Route` enum. This module is a deep dive on that pattern — why it exists, how the pieces fit, and how to extend it with data passing, deep links, and modal presentation.

**What you'll learn**

- Why a centralized router/coordinator beats scattered `NavigationLink`s.
- How `NavigationStack(path:)`, a typed `Route` enum, and `.navigationDestination(for:)` work together.
- How to pass data between screens with associated values (`detail(Item.ID)`).
- Programmatic navigation: `push`, `pop`, and `popToRoot`.
- Deep linking: mapping a `URL` (via `onOpenURL`) to a `Route`, with a worked example.
- When to *push* vs *present* a sheet or full-screen cover.
- How the UIKit templates do the same job with a coordinator + `UINavigationController`.

**Prerequisites**

- You've completed [Module 05 — State & Data Flow](05-state-and-data-flow.md) and are comfortable with `@Observable`, `@State`, and `@Environment`.
- You've built a feature in [Module 03 — Building Your First Feature](03-your-first-feature.md) (we'll reference its route).

---

## Why a centralized router?

A `NavigationLink` couples a *source view* to a *destination view*. That seems convenient at first, but it doesn't scale:

- **Logic gets scattered.** Each screen has to know how to construct every screen it can reach, including that screen's dependencies. Navigation rules end up smeared across the view layer.
- **Programmatic navigation is awkward.** "Pop to root after checkout" or "deep-link straight to a detail screen" is hard when navigation lives inside view bodies.
- **It's hard to test.** You can't assert "tapping save navigates home" without rendering views.

The router pattern fixes this by making navigation **data**. Views express intent — `router.push(.settings)` — and a single place (`AppEntry`) decides what view that route maps to. The router owns the path, so navigation becomes a property you can read, mutate, and test.

Here's the template's router (`Core/Navigation/AppRouter.swift`), trimmed to the essentials:

```swift
@Observable
@MainActor
final class AppRouter {
    enum Route: Hashable {
        case home
        case settings
        case detail(Item.ID)
    }

    var path = NavigationPath()

    func push(_ route: Route) { path.append(route) }
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    func popToRoot() {
        guard !path.isEmpty else { return }
        path.removeLast(path.count)
    }
}
```

> The router is `@Observable @MainActor`. On targets earlier than iOS 17 / macOS 14, the same pattern works by conforming to `ObservableObject` and marking `path` with `@Published`, then injecting it with `@EnvironmentObject` instead of `@Environment`.

---

## How the three pieces fit together

Three things cooperate to make typed navigation work:

1. **`NavigationStack(path:)`** — a stack bound to a mutable path. When the path changes, the stack changes. This is the engine.
2. **A typed `Route` enum** — the *values* that live on the path. Because `Route` is `Hashable`, instances can be appended to a `NavigationPath`.
3. **`.navigationDestination(for:)`** — the *translator*. It tells SwiftUI: "whenever a value of type `Route` appears on the path, here's the view to show."

`AppEntry` wires all three together at the root (`App/AppEntry.swift`):

```swift
@main
struct AppEntry: App {
    @State private var router = AppRouter()
    @State private var apiClient: any APIClientProtocol = APIClient()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {                 // 1. the stack, bound to the router's path
                HomeView(viewModel: HomeViewModel(api: apiClient))
                    .navigationDestination(for: AppRouter.Route.self) { route in   // 3. translate route -> view
                        destination(for: route)
                    }
            }
            .environment(router)   // make the router available to every descendant
        }
    }

    @ViewBuilder
    private func destination(for route: AppRouter.Route) -> some View {  // 2. routes mapped to views
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

The flow is a loop:

```
view calls router.push(.settings)
        │
        ▼
router.path.append(.settings)        // path is @Observable state
        │
        ▼
NavigationStack(path: $router.path)  // observes the path, sees a new value
        │
        ▼
.navigationDestination(for: Route.self) resolves .settings
        │
        ▼
destination(for: .settings) -> SettingsView   // pushed onto the stack
```

Crucially, `destination(for:)` is the *only* place that constructs destination views and injects their dependencies. A view that wants to navigate doesn't import or know about `SettingsView` — it just pushes a `Route`.

The router reaches every screen because `AppEntry` injects it with `.environment(router)`. Any descendant reads it back with `@Environment(AppRouter.self) private var router` (you saw this in `HomeView`).

---

## Passing data with associated values

A route is just an enum value, so it can carry data. The template's `detail(Item.ID)` case is the canonical example: the detail screen needs to know *which* item, so the id rides along on the route.

`HomeView` pushes it when a row is tapped:

```swift
ForEach(displayedItems) { item in
    Button {
        router.push(.detail(item.id))    // the id travels with the route
    } label: {
        ItemRow(item: item)
    }
}
```

And `destination(for:)` unpacks it:

```swift
case .detail(let id):
    DetailPlaceholderView(itemID: id)
```

**Pass identifiers, not whole objects.** Notice the route carries `Item.ID` (an `Int`), not a full `Item`. There are two good reasons:

- **Hashable cost & correctness.** Everything on a `NavigationPath` must be `Hashable`. An id is cheap and stable; a whole model may be large or change underneath you.
- **Freshness.** The detail screen should re-fetch (or look up) the latest data for that id rather than display a possibly-stale snapshot captured at tap time. The template's `DetailPlaceholderView` leaves a `TODO` to "load by id" — that's the intended design.

If you do need to pass a richer value, make sure the type is `Hashable` (the template's `Item` already is: `Codable, Identifiable, Hashable, Sendable`) and add a case like `case itemDetail(Item)` — but prefer ids unless you have a reason not to.

---

## Programmatic navigation: push, pop, popToRoot

Because the path is plain state, you navigate by mutating it. The router wraps the three common operations:

```swift
// Go forward
router.push(.settings)

// Go back one screen (e.g. a custom Back button or after a save)
router.pop()

// Unwind everything (e.g. after checkout, or on sign-out)
router.popToRoot()
```

A realistic example — a Settings action that completes and returns home:

```swift
Button("Done") {
    viewModel.save()
    router.popToRoot()
}
```

Both `pop()` and `popToRoot()` guard against an empty path, so calling them when you're already at the root is a safe no-op. And because all of this is just method calls on an `@Observable` object, you can drive and assert navigation from tests or from a view model without rendering any views.

---

## Deep linking: mapping a URL to a Route

Deep links are where the centralized router really pays off. An incoming `URL` (a custom scheme like `myapp://item/42` or a universal link) just needs to be *parsed into a `Route`* — and then the existing machinery does the rest.

### Step 1 — Add a parser to the router

Add this to `AppRouter` so URL-to-route logic lives next to the route definition:

```swift
extension AppRouter {
    /// Parses a deep-link URL into a Route, or returns nil if unrecognized.
    /// Example: myapp://item/42  ->  .detail(42)
    static func route(for url: URL) -> Route? {
        guard url.scheme == "myapp" else { return nil }
        switch url.host {
        case "settings":
            return .settings
        case "item":
            // First path component after the host is the id.
            let idString = url.pathComponents.dropFirst().first
            guard let idString, let id = Int(idString) else { return nil }
            return .detail(id)
        default:
            return nil
        }
    }

    /// Resets to root, then navigates to a deep-linked route.
    func handle(_ url: URL) {
        guard let route = Self.route(for: url) else { return }
        popToRoot()        // start from a known state
        push(route)
    }
}
```

### Step 2 — Feed `onOpenURL` into the router

In `AppEntry`, attach `.onOpenURL` to the `NavigationStack` (or the `WindowGroup`'s content):

```swift
NavigationStack(path: $router.path) {
    HomeView(viewModel: HomeViewModel(api: apiClient))
        .navigationDestination(for: AppRouter.Route.self) { route in
            destination(for: route)
        }
}
.environment(router)
.onOpenURL { url in
    router.handle(url)
}
```

Now `myapp://item/42` opens the app, parses to `.detail(42)`, resets to root, and pushes the detail screen — reusing the *exact same* `destination(for:)` branch that an in-app tap uses. No duplicate navigation code. (For multi-level deep links, build an array of routes and append them all to the path before the stack renders.)

> **Value-type destinations vs the router.** SwiftUI also lets you attach `.navigationDestination(for: SomeValue.self)` directly for value types and use `NavigationLink(value:)`. That's fine for small, leaf-level navigation. But for app-wide flows and deep links you want a single source of truth — the router — so the whole graph is described in one place and is reachable programmatically.

---

## Pushing vs presenting (sheets & full-screen covers)

Not every destination belongs on the navigation stack. Use the right tool:

- **Push** (`router.push(...)`) for forward progress in a hierarchy — drilling from a list into a detail, or into Settings. The user expects a Back button and a sense of "deeper."
- **Sheet** (`.sheet`) for a self-contained, dismissible task that's *modal* to the current context — composing a message, a quick form, a confirmation. The user expects to finish or cancel and return to exactly where they were.
- **Full-screen cover** (`.fullScreenCover`) for an immersive modal flow that should hide everything beneath — onboarding, sign-in, a media viewer.

You can extend the router to drive sheets too, keeping presentation centralized:

```swift
@Observable
@MainActor
final class AppRouter {
    enum Route: Hashable { case home, settings, detail(Item.ID) }

    /// Sheets are modal, so they're tracked separately from the push stack.
    enum Sheet: Identifiable {
        case composeFeedback
        var id: String { String(describing: self) }
    }

    var path = NavigationPath()
    var presentedSheet: Sheet?

    func present(_ sheet: Sheet) { presentedSheet = sheet }
    func dismissSheet() { presentedSheet = nil }
}
```

Bind it in `AppEntry`. Note the `@Bindable` so the environment router can supply a binding to `.sheet(item:)`:

```swift
@Bindable var router = router   // inside body, where `router` is the @Environment value
...
.sheet(item: $router.presentedSheet) { sheet in
    switch sheet {
    case .composeFeedback:
        FeedbackView()
    }
}
```

Then anywhere: `router.present(.composeFeedback)`. The key idea is that **a sheet is its own dimension of navigation state**, separate from the push stack — so it gets its own property rather than living on `path`.

---

## How the UIKit templates do it

If you open one of the UIKit templates in this repo, you'll find the same *idea* expressed with UIKit primitives:

- A **`Coordinator`** object plays the role of `AppRouter`. It owns a `UINavigationController` and exposes methods like `showDetail(id:)` instead of `push(.detail(id))`.
- **Pushing** is `navigationController.pushViewController(_:animated:)`; **popping** is `popViewController` / `popToRootViewController`. That's the imperative equivalent of mutating `path`.
- **View controllers don't construct each other.** Just like SwiftUI views push *routes* rather than building destinations, UIKit view controllers call back to the coordinator (via a delegate or closure) and let *it* build and present the next screen with the right dependencies.
- **Presentation** maps cleanly: `present(_:animated:)` for modals is the analogue of `.sheet`/`.fullScreenCover`.

So the mental model transfers directly: **centralize navigation in one object, express destinations as data/intents, and keep screens ignorant of each other.** SwiftUI gives you `NavigationStack` + `NavigationPath` + a `Route` enum; UIKit gives you a coordinator + `UINavigationController`. Same architecture, different engine.

---

## Try it yourself

1. **Add a route.** Following [Module 03](03-your-first-feature.md), add `case profile`, a `destination(for:)` branch, and push it from a toolbar button.
2. **Deep link to it.** Extend `AppRouter.route(for:)` so `myapp://profile` returns `.profile`, register a URL scheme in `Info.plist`, and test it from the simulator with `xcrun simctl openurl booted "myapp://profile"`.
3. **Unwind on an action.** Add a "Back to Home" button somewhere deep in the stack that calls `router.popToRoot()`, and confirm it clears the path.
4. **Present a sheet.** Wire up the `Sheet` enum from above with a tiny `FeedbackView`, present it from Home, and dismiss it with `router.dismissSheet()`.
5. **Pass a value type.** Add `case itemDetail(Item)` and push a full `Item` from `HomeView`. Compare the trade-offs against `detail(Item.ID)` — which feels safer as the app grows?

---

## Recap

- Navigation is *state*: `AppRouter` owns a `NavigationPath` and a typed, `Hashable` `Route` enum.
- `NavigationStack(path:)` (the engine) + the `Route` enum (the values) + `.navigationDestination(for:)` (the translator) form the loop; `AppEntry`'s `destination(for:)` is the single place routes become views.
- Pass identifiers (`detail(Item.ID)`), not whole objects, for cheap hashing and fresh data.
- `push`/`pop`/`popToRoot` make navigation programmatic and testable.
- Deep links parse a `URL` into a `Route` in one place and reuse the existing destination map via `.onOpenURL`.
- Push for hierarchy; sheets/full-screen covers for modal tasks — track modals as separate state from the push stack.
- UIKit templates achieve the same with a coordinator + `UINavigationController`; the architecture is identical.

**Next:** [Module 07 — Persistence & Storage](07-persistence-and-storage.md)
