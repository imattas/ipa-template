# Architecture

This template is a single-target **watchOS** app built with **Swift + SwiftUI**
and the **WatchKit lifecycle** bridge, following the **MVVM** pattern with
**dependency injection**.

## Folder Structure

```
watchOS-SwiftUI/
├── App/                       # App entry point & WatchKit lifecycle
│   ├── AppEntry.swift         # @main App; WKApplicationDelegateAdaptor
│   ├── AppDelegate.swift      # WKApplicationDelegate, background refresh
│   └── Info.plist             # WKApplication = true (modern watch app)
├── Features/                  # One folder per feature (View + ViewModel)
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
├── Core/                      # Cross-cutting infrastructure
│   ├── Networking/
│   │   ├── APIClient.swift    # actor APIClient + MockAPIClient + Item + APIError
│   │   └── Endpoint.swift     # Endpoint + HTTPMethod
│   └── Storage/
│       └── AppStorage+Keys.swift
├── Resources/
│   └── Assets.xcassets/       # App icon, accent color
├── Tests/
│   └── Unit/
│       └── HomeViewModelTests.swift
└── docs/
```

### Rationale

- **App/** isolates lifecycle plumbing from feature code. The WatchKit delegate
  lives here so background-refresh logic is easy to find.
- **Features/** groups each screen's View and ViewModel together, so a feature
  is self-contained and easy to add, move, or delete.
- **Core/** holds reusable infrastructure (networking, storage) that features
  depend on via protocols, never on concrete types.
- **Tests/** mirror the source structure for discoverability.

## Data Flow

```
        ┌──────────────────────── WatchKit Lifecycle ────────────────────────┐
        │  WKApplicationDelegateAdaptor → AppDelegate                          │
        │    applicationDidFinishLaunching()                                  │
        │    handle(_ backgroundTasks:)  ── WKRefreshBackgroundTask           │
        │        └─ scheduleNextBackgroundRefresh()                           │
        └─────────────────────────────────────────────────────────────────────┘

   SwiftUI View                @Observable ViewModel              APIClient (actor)
  ┌────────────┐   .task()    ┌──────────────────┐   async/await  ┌────────────────┐
  │  HomeView  │ ───────────► │  HomeViewModel   │ ─────────────► │   APIClient    │
  │            │              │  - items         │                │  send<T>()     │
  │  observes  │ ◄─────────── │  - isLoading     │ ◄───────────── │  fetchItems()  │
  │  state     │   state Δ    │  - errorMessage  │   [Item]/throws │   URLSession   │
  └────────────┘              └──────────────────┘                └────────────────┘
                                       ▲
                                       │ injected (APIClientProtocol)
                                MockAPIClient (tests / previews)
```

1. The View triggers work via `.task { await viewModel.load() }`.
2. The ViewModel (`@MainActor`, `@Observable`) calls the injected
   `APIClientProtocol`.
3. The `APIClient` actor performs the request off the main actor and returns
   decoded models or throws a typed `APIError`.
4. The ViewModel updates `items` / `isLoading` / `errorMessage`; SwiftUI
   re-renders only the views that read the changed properties.

## Patterns

- **MVVM** — Views are declarative and stateless beyond their `@State` view
  model; all logic and state live in the ViewModel.
- **Dependency Injection** — ViewModels receive `APIClientProtocol` via their
  initializer, defaulting to the live client. Tests/previews inject
  `MockAPIClient`.
- **WatchKit Lifecycle Adaptor** — `@WKApplicationDelegateAdaptor` bridges the
  SwiftUI `App` to a `WKApplicationDelegate` for lifecycle + background tasks.
- **Concurrency** — `async/await` end to end; the network client is an `actor`;
  UI types are `@MainActor`; models and protocols are `Sendable` (Swift 6).

## Where to Add …

### A new feature
1. Create `Features/<Name>/` with `<Name>View.swift` and `<Name>ViewModel.swift`.
2. Make the ViewModel `@MainActor @Observable` and inject any `Core` protocols.
3. Add navigation from an existing view (e.g. a `NavigationLink` in `HomeView`).
4. Add a matching `Tests/Unit/<Name>ViewModelTests.swift` using mocks.

### A new background task
1. Add handling in `AppDelegate.handle(_ backgroundTasks:)` for the relevant
   `WKRefreshBackgroundTask` subtype.
2. Schedule it (e.g. `scheduleNextBackgroundRefresh()` or
   `WKApplication.shared().scheduleBackgroundRefresh(...)`).
3. **Always** complete the task with `setTaskCompletedWithSnapshot(_:)` so you
   don't exhaust the background budget.
```
