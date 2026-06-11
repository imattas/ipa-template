# Architecture

This template uses **MVVM** (Model–View–ViewModel) with manual dependency
injection and a protocol-oriented networking layer. It targets Swift 6 language
mode and uses Swift Concurrency (`async`/`await`, actors, `@MainActor`).

## Folder structure

```
Swift-UIKit/
├── App/                 # App entry point + lifecycle (AppDelegate, SceneDelegate, Info.plist)
├── Features/            # One folder per feature, each with a VC + ViewModel
│   ├── Home/
│   └── Settings/
├── Core/                # Cross-cutting building blocks shared by features
│   ├── Networking/      # APIClient, Endpoint, APIError, models
│   ├── Storage/         # UserDefaultsManager
│   └── Extensions/      # UIView / String helpers
├── Resources/           # Assets.xcassets, LaunchScreen.storyboard
├── Tests/
│   ├── Unit/            # XCTest unit tests (view models, etc.)
│   └── UI/              # XCUITest end-to-end tests
└── docs/                # This documentation
```

### Rationale

- **Feature-first** organization keeps everything for a screen together, so a
  feature can be added, moved, or deleted as a unit.
- **Core** holds reusable infrastructure that multiple features depend on. It
  never imports from `Features`, keeping dependencies pointing one direction.
- **App** owns composition: it builds the dependency graph in `SceneDelegate`
  and injects it downward. View models never construct their own dependencies.

## Data flow

```
 ┌──────────────────────┐   user action / refresh    ┌──────────────────┐
 │   HomeViewController  │ ─────────────────────────► │   HomeViewModel   │
 │  (View, @MainActor)   │                            │ (@Observable,     │
 │                       │ ◄───── observable state ── │   @MainActor)     │
 └──────────────────────┘   withObservationTracking   └──────────────────┘
                                                              │ async/await
                                                              ▼
                                                     ┌──────────────────┐
                                                     │    APIClient      │
                                                     │ (actor, conforms  │
                                                     │  APIClientProtocol)│
                                                     └──────────────────┘
                                                              │ URLSession
                                                              ▼
                                                     ┌──────────────────┐
                                                     │      Network      │
                                                     └──────────────────┘
```

- The **View** holds a reference to its **ViewModel** and renders observable
  state. It forwards user intent (load, refresh) by calling view-model methods
  inside a `Task`.
- The **ViewModel** is the single source of truth for screen state
  (`items`, `isLoading`, `errorMessage`). It talks to the network through the
  `APIClientProtocol` abstraction — never `URLSession` directly.
- The **APIClient** is an `actor` that builds `URLRequest`s from `Endpoint`
  values, performs them, validates the response, and decodes JSON. Errors are
  normalized into the typed `APIError` enum.

## Patterns used

- **MVVM** — UIKit view controllers stay thin; logic and state live in
  `@Observable` view models.
- **Dependency injection** — concrete dependencies are constructed once in
  `SceneDelegate` and passed into initializers. Tests inject mocks.
- **Protocol-oriented networking** — `APIClientProtocol` decouples view models
  from the concrete client, enabling `MockAPIClient` in unit tests.
- **Observation framework** — `withObservationTracking` drives reactive UI
  updates without Combine. A pre-iOS 17 `ObservableObject`/`@Published` fallback
  is documented inline in `HomeViewModel`.

## Where to add a new feature

1. Create `Features/<Name>/`.
2. Add `<Name>ViewModel.swift` — an `@MainActor @Observable final class` that
   takes its dependencies via `init`.
3. Add `<Name>ViewController.swift` — a programmatic `@MainActor` controller
   that observes the view model and renders state.
4. Wire it up in `SceneDelegate` (construct the view model with shared
   dependencies and push/embed the controller).
5. Add `Tests/Unit/<Name>ViewModelTests.swift` using mock dependencies.
6. If the feature needs new network calls, extend `APIClientProtocol` and add
   `Endpoint` constructors in `Core/Networking`.
