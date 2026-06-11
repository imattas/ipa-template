# Module 02 — Anatomy of a Template

In Module 01 you copied the **Swift-SwiftUI** template out and got it running.
Now we'll open the hood. Every UI template in this repo shares the same skeleton,
and that skeleton encodes a set of deliberate decisions: where code lives, which
direction dependencies point, and how data flows from a tap to the network and
back. Learn this structure once and you'll feel at home in any of the templates —
and, more importantly, you'll know exactly where your *own* new code belongs.

**What you'll learn**

- The shared folder structure — `App/`, `Features/`, `Core/` (Networking,
  Storage, Navigation, Extensions), `Resources/`, `Tests/`, `docs/` — and why
  each one exists
- The "one folder per feature = View + ViewModel" rule
- The job of each `Core/` subsystem
- How data flows: **View → @Observable ViewModel → APIClientProtocol → network**
- Where new code belongs as your app grows
- Which real files to read right now to make all of this concrete

**Prerequisites**

[Module 01 — Getting Started](01-getting-started.md). You should have a copy of
the Swift-SwiftUI template (e.g. at `~/Developer/MyApp`) that builds and runs.

---

## 1. The shared folder structure

Open your template copy. The top level looks like this:

```
Swift-SwiftUI/
├── App/                     # Entry point and Info.plist
│   ├── AppEntry.swift       # @main App; owns AppRouter; builds NavigationStack
│   └── Info.plist
├── Features/                # One folder per feature: View + ViewModel pairs
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
├── Core/                    # Cross-cutting infrastructure (no feature knowledge)
│   ├── Navigation/
│   │   └── AppRouter.swift
│   ├── Networking/
│   │   ├── APIClient.swift  # Protocol, live actor, mock, Item model, APIError
│   │   └── Endpoint.swift
│   ├── Storage/
│   │   └── AppStorage+Keys.swift
│   └── Extensions/
│       └── View+Extensions.swift
├── Resources/
│   └── Assets.xcassets/     # AppIcon, AccentColor
├── Tests/
│   ├── Unit/                # XCTest unit tests (view models)
│   └── UI/                  # XCUITest launch/UI tests
└── docs/                    # ARCHITECTURE / SETUP / CONTRIBUTING
```

The single most important rule this structure enforces is a **one-way
dependency**: `Features → Core`, never the reverse. Features know about Core's
abstractions; Core knows nothing about any feature. Keep that arrow in mind as we
walk each folder.

### `App/` — the entry point

`App/AppEntry.swift` is the `@main` `App`. It owns the app-wide objects and wires
up the root navigation. Open it and you'll see it holds the router and the API
client, then builds the root `NavigationStack`:

```swift
@main
struct AppEntry: App {
    @State private var router = AppRouter()
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
}
```

Two things to notice. First, the router is held as `@State` so SwiftUI keeps a
single instance alive for the whole scene, and it's injected into the environment
so any descendant can drive navigation. Second, the API client is typed as
`any APIClientProtocol` — the app depends on the *protocol*, so you can swap in
`MockAPIClient()` here for an offline build without touching any feature.

`App/Info.plist` holds the bundle identifier, display name, and launch
configuration you set in Module 01.

### `Features/` — one folder per screen

Each user-facing screen gets its own folder under `Features/`, and that folder
contains exactly a **View + ViewModel pair**:

```
Features/
├── Home/
│   ├── HomeView.swift        # SwiftUI; renders state, forwards intent
│   └── HomeViewModel.swift   # @Observable @MainActor; holds state, calls API
└── Settings/
    ├── SettingsView.swift
    └── SettingsViewModel.swift
```

This is the **"one folder per feature = View + ViewModel"** rule. Co-locating the
two halves of a screen means a feature is trivial to find, move between projects,
or delete wholesale. The View stays *thin* — it renders state and forwards user
intent; all logic lives in the testable ViewModel.

### `Core/` — shared infrastructure

`Core/` holds reusable infrastructure that features depend on but that contains
no feature-specific knowledge. It has four subsystems.

**`Core/Navigation/` — the router.** `AppRouter.swift` is an
`@Observable @MainActor final class` that owns the navigation path and a typed
`Route` enum:

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
    func pop()  { guard !path.isEmpty else { return }; path.removeLast() }
    func popToRoot() { guard !path.isEmpty else { return }; path.removeLast(path.count) }
}
```

Centralizing navigation here — instead of scattering `NavigationLink`s through
views — keeps the route graph in one place, makes navigation testable, and lets
any view trigger a transition with `router.push(.settings)`.

**`Core/Networking/` — the API layer.** Two files:

- `APIClient.swift` defines `protocol APIClientProtocol: Sendable` (the boundary
  features depend on), the live `actor APIClient`, the `final class MockAPIClient`
  for previews/tests, the `Item` model, and the typed `enum APIError`.
- `Endpoint.swift` defines the `struct Endpoint` value type (path, `HTTPMethod`,
  query, headers, body) and `urlRequest(baseURL:)` that turns an endpoint into a
  `URLRequest`.

The protocol is the key: features import `APIClientProtocol`, never the concrete
`APIClient`. That single abstraction makes offline mode, previews, and unit tests
trivial.

**`Core/Storage/` — persistence keys.** `AppStorage+Keys.swift` namespaces all
`UserDefaults` keys in one `StorageKeys` enum and provides typed `@AppStorage`
helpers, so feature code never hard-codes a raw string key (and never typos one).

**`Core/Extensions/` — small shared helpers.** `View+Extensions.swift` holds
focused, reusable view modifiers such as `cardStyle()` and
`redactedWhileLoading(_:)`. Keep these small and generic — anything
feature-specific belongs in that feature's folder, not here.

### `Resources/` — assets

`Resources/Assets.xcassets/` holds the App Icon, the Accent Color, and any images
or colors the app ships. Non-code resources live here so they're easy to find and
manage in one place.

### `Tests/` — Unit and UI

- `Tests/Unit/` holds XCTest unit tests, primarily for view models (e.g.
  `HomeViewModelTests.swift`). Because view models take their dependencies via
  `init`, tests inject `MockAPIClient` and assert on `items` / `isLoading` /
  `errorMessage` with no network involved.
- `Tests/UI/` holds XCUITest launch and UI tests.

### `docs/` — the template's own documentation

Each template carries its own `docs/` with `ARCHITECTURE.md`, `SETUP.md`, and
`CONTRIBUTING.md`. The architecture doc for this template lives at
[`../../templates/Swift-SwiftUI/docs/ARCHITECTURE.md`](../../templates/Swift-SwiftUI/docs/ARCHITECTURE.md)
and is the canonical reference for everything in this module.

## 2. How data flows

Here's the path from a fresh launch to items on screen, and from a tap to a new
screen:

```
        ┌──────────────────────────────────────────────────────────┐
        │                      AppEntry (@main)                     │
        │   owns AppRouter ───────────────┐                         │
        │   NavigationStack(path:)        │ .environment(router)    │
        └───────────────┬─────────────────┴─────────────────────────┘
                        │ navigationDestination(for: Route)
                        ▼
   ┌──────────────┐  reads state   ┌────────────────────┐  async/await  ┌──────────────┐
   │              │ ─────────────► │                    │ ────────────► │              │
   │   HomeView   │                │   HomeViewModel    │               │  APIClient   │
   │  (SwiftUI)   │ ◄───────────── │  (@Observable,     │ ◄──────────── │  (actor,     │
   │              │  observes      │   @MainActor)      │   [Item]      │  Protocol)   │
   └──────┬───────┘                └────────────────────┘   /APIError   └──────────────┘
          │ user taps
          │ router.push(.detail(id))
          ▼
   ┌──────────────┐
   │  AppRouter   │  mutates NavigationPath ──► NavigationStack re-renders
   │ (@Observable)│
   └──────────────┘
```

Trace it through the real files:

1. **The view kicks off a load.** `HomeView` runs `.task { await viewModel.load() }`
   when it appears (and again on pull-to-refresh):

   ```swift
   .task {
       await viewModel.load()
   }
   ```

2. **The view model calls the API and publishes state.** `HomeViewModel.load()`
   toggles `isLoading`, awaits the injected client, and stores results or an error
   message:

   ```swift
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

   Because the model is `@Observable`, assigning `items` / `isLoading` /
   `errorMessage` automatically re-renders the view — no manual notification.

3. **The client performs I/O off the main thread.** `APIClient` is an `actor`, so
   its network work is isolated from the UI and returns typed `[Item]` or throws
   `APIError`. The view model is `@MainActor`, so state updates land safely back on
   the main thread.

4. **Navigation is a separate flow.** When the user taps a row, the view asks the
   router — `router.push(.detail(item.id))` — which mutates the `NavigationPath`,
   and `AppEntry`'s `navigationDestination(for:)` maps the `Route` to a
   destination view. Navigation state and screen state stay cleanly separated.

The arrows only ever point `Features → Core`: `HomeViewModel` depends on
`APIClientProtocol`, and `HomeView` depends on `AppRouter`, but nothing in `Core/`
ever imports a feature.

## 3. Where things belong as the app grows

Use the structure as a decision tree when you add code:

- **A new screen?** Create `Features/<Name>/` with `<Name>View.swift` and
  `<Name>ViewModel.swift`. Make the view model `@Observable @MainActor` and inject
  its dependencies (e.g. `any APIClientProtocol`) via `init`.
- **A new route to that screen?** Add a case to `AppRouter.Route`, then handle it
  in `AppEntry.destination(for:)`. Navigate with `router.push(.<name>)`.
- **A new network call?** Add an `Endpoint` factory in `Core/Networking` and, if
  useful, a convenience method on `APIClientProtocol`.
- **A new persisted preference?** Add a key to `StorageKeys` and a typed
  `@AppStorage` helper in `Core/Storage`.
- **A reusable view modifier?** Add it to `Core/Extensions` — but only if it's
  generic. Feature-specific helpers stay in the feature folder.

If you ever can't decide where something goes, ask: *does this know about a
specific feature?* If yes, it belongs under `Features/`. If no — it's
infrastructure — it belongs under `Core/`.

---

## Try it yourself

1. Open `Features/Settings/SettingsView.swift` and `SettingsViewModel.swift`.
   Confirm they follow the same View + ViewModel rule as `Home`. What state does
   the Settings view model hold?
2. In `Core/Networking/Endpoint.swift`, find the `static var items` factory. Sketch
   (on paper) the `Endpoint` you'd add for a `GET /items/{id}` detail call.
3. Trace the **error** path: in `HomeView`, find where `viewModel.errorMessage`
   drives a `ContentUnavailableView`, then look at the `#Preview("Error")` that
   injects `MockAPIClient(error: APIError.server(status: 500))`. Run that preview.
4. Draw your own copy of the data-flow diagram from memory, then check it against
   [`../../templates/Swift-SwiftUI/docs/ARCHITECTURE.md`](../../templates/Swift-SwiftUI/docs/ARCHITECTURE.md).

### Read these files now

Before the next module, open and skim these real files so the patterns are fresh:

- `App/AppEntry.swift` — how the app is composed and navigation is wired
- `Features/Home/HomeView.swift` — a thin view that renders state and forwards intent
- `Features/Home/HomeViewModel.swift` — `@Observable @MainActor` state + `load()`
- `Core/Navigation/AppRouter.swift` — the typed router
- `Core/Networking/APIClient.swift` — the protocol, the actor, the mock, `Item`, `APIError`
- `Core/Networking/Endpoint.swift` — the `Endpoint` value type

## Recap

You toured the shared template structure and learned why each folder exists:
`App/` composes the app, `Features/` holds one View + ViewModel pair per screen,
`Core/` provides feature-agnostic infrastructure (Navigation, Networking, Storage,
Extensions), `Resources/` holds assets, and `Tests/` holds Unit and UI tests — all
governed by the one-way `Features → Core` dependency rule. You traced data flowing
from `HomeView` → `HomeViewModel` → `APIClientProtocol` → the network and back, and
saw where new screens, routes, endpoints, and preferences belong. With the map in
hand, the next module dives into the networking layer in depth.

**Next:** [Module 03 — Building Your First Feature](03-your-first-feature.md)
