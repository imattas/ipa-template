# Architecture

This template follows **MVVM** with a centralized **Router/Coordinator** and a
**protocol-oriented networking** layer, all wired together with constructor
**dependency injection**.

## Folder structure

```
Swift-SwiftUI/
├── App/                     # Entry point and Info.plist
│   ├── AppEntry.swift       # @main App; owns AppRouter; builds NavigationStack
│   └── Info.plist
├── Features/                # One folder per feature; View + ViewModel pairs
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
├── Core/                    # Cross-cutting infrastructure
│   ├── Navigation/
│   │   └── AppRouter.swift  # Typed Route enum + NavigationPath
│   ├── Networking/
│   │   ├── APIClient.swift  # Protocol, live actor, mock, Item model, APIError
│   │   └── Endpoint.swift   # Endpoint value type + URLRequest building
│   ├── Storage/
│   │   └── AppStorage+Keys.swift
│   └── Extensions/
│       └── View+Extensions.swift
├── Resources/
│   └── Assets.xcassets/     # AppIcon, AccentColor
├── Tests/
│   ├── Unit/                # XCTest unit tests (view models)
│   └── UI/                  # XCUITest launch/UI tests
└── docs/
```

### Rationale

- **Feature-first** under `Features/` keeps a screen's view and view model
  co-located, so a feature is easy to find, move, or delete.
- **`Core/`** holds reusable infrastructure that features depend on but that has
  no feature-specific knowledge. This enforces a one-way dependency:
  `Features → Core`, never the reverse.
- **Protocols at the boundary** (`APIClientProtocol`) decouple features from
  concrete implementations and make previews/tests trivial.

## Data flow

```
        ┌─────────────────────────────────────────────────────────┐
        │                       AppEntry (@main)                   │
        │   owns AppRouter ──────────────┐                         │
        │   NavigationStack(path:)       │ .environment(router)    │
        └───────────────┬────────────────┼─────────────────────────┘
                        │ navigationDestination(for: Route)
                        ▼
   ┌──────────────┐  reads state   ┌────────────────────┐  async/await  ┌──────────────┐
   │              │ ─────────────► │                    │ ────────────► │              │
   │   HomeView   │                │   HomeViewModel    │               │  APIClient   │
   │ (SwiftUI)    │ ◄───────────── │  (@Observable,     │ ◄──────────── │ (actor,      │
   │              │  observes      │   @MainActor)      │   [Item]      │  Protocol)   │
   └──────┬───────┘  published     └────────────────────┘   /APIError   └──────────────┘
          │ user taps
          │ router.push(.detail(id))
          ▼
   ┌──────────────┐
   │  AppRouter   │  mutates NavigationPath ──► NavigationStack re-renders
   │ (@Observable)│
   └──────────────┘
```

- The **View** renders state and forwards user intent.
- The **ViewModel** (`@Observable`, `@MainActor`) holds presentation state
  (`items`, `isLoading`, `errorMessage`) and calls the API via `async/await`.
- The **APIClient** (`actor`) performs I/O off the main thread and returns typed
  results or throws `APIError`.
- The **AppRouter** (`@Observable`) owns the `NavigationPath`; mutating it drives
  the `NavigationStack`.

## Patterns

- **MVVM** — Views are thin; logic lives in testable view models.
- **Router / Coordinator** — Navigation state is centralized in `AppRouter` with
  a typed `Route` enum, instead of scattering `NavigationLink`s.
- **Dependency Injection** — Dependencies (the API client) are passed through
  initializers, enabling `MockAPIClient` in tests/previews.
- **Protocol-oriented networking** — Features depend on `APIClientProtocol`.
- **Observation framework** — `@Observable` for fine-grained, automatic view
  updates (with an `ObservableObject` fallback noted in code for older OSes).

## Where to add a new feature

1. Create `Features/<Name>/` with `<Name>View.swift` and `<Name>ViewModel.swift`.
2. Make the view model `@Observable @MainActor` and inject its dependencies via
   `init` (e.g. `any APIClientProtocol`).
3. Add a case to `AppRouter.Route` (e.g. `case profile(User.ID)`).
4. Handle the new case in `AppEntry.destination(for:)`.
5. Navigate with `router.push(.<name>)` from any view that has the router in its
   environment.
6. Add endpoints under `Core/Networking` and unit tests under `Tests/Unit`.
```
