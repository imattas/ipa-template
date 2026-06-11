# Architecture

This template is a native **macOS AppKit** application built with **Swift 6**,
**programmatic UI** (no Storyboards/XIBs), and an **MVVM** presentation layer.

## Folder Structure

```
macOS-AppKit/
├── App/                     # Entry point, app lifecycle, window & menu setup
│   ├── main.swift           # The single entry point (creates NSApplication, runs)
│   ├── AppDelegate.swift    # NSApplicationDelegate: window, menu, settings window
│   └── Info.plist           # Bundle metadata; programmatic (empty NSMainNibFile)
├── Features/                # One folder per feature; each has a VC + VM
│   ├── Home/
│   │   ├── HomeViewController.swift   # NSTableView, refresh button, rendering
│   │   └── HomeViewModel.swift        # @Observable @MainActor state + load logic
│   └── Settings/
│       ├── SettingsViewController.swift
│       └── SettingsViewModel.swift
├── Core/                    # Reusable, feature-agnostic infrastructure
│   ├── Networking/
│   │   ├── APIClient.swift  # actor APIClient + protocol + Item + APIError + mock
│   │   └── Endpoint.swift   # Endpoint value type + HTTPMethod
│   ├── Storage/
│   │   └── UserDefaultsManager.swift  # Typed preferences wrapper
│   └── Extensions/
│       └── NSView+Extensions.swift    # Auto Layout pin helpers
├── Resources/
│   └── Assets.xcassets/     # AppIcon, AccentColor
├── Tests/
│   └── Unit/
│       └── HomeViewModelTests.swift   # XCTest with MockAPIClient
└── docs/                    # ARCHITECTURE / SETUP / CONTRIBUTING
```

### Rationale

- **App/** isolates process bootstrap and lifecycle from feature code. Keeping a
  single `main.swift` entry point (and *no* `@main` on the delegate) avoids the
  classic duplicate-entry-point compile error.
- **Features/** groups each screen's view controller with its view model so a
  feature is self-contained and easy to delete or move.
- **Core/** holds cross-cutting infrastructure (networking, storage, extensions)
  that any feature may depend on, but which depends on no feature.
- **Tests/** mirror the source tree and exercise view models in isolation using
  the injected `APIClientProtocol`.

## Data Flow

```
                 user action (refresh / settings change)
                              │
                              ▼
        ┌──────────────────────────────────────┐
        │           AppDelegate                 │
        │  - builds NSWindow + NSWindowController│
        │  - builds main menu (Quit, Settings…) │
        └───────────────┬──────────────────────┘
                        │ hosts
                        ▼
        ┌──────────────────────────────────────┐        observes
        │          NSViewController             │◀───────────────────┐
        │  (HomeViewController / Settings…)     │                    │
        │  - builds views programmatically      │                    │
        │  - NSTableViewDataSource/Delegate     │                    │
        └───────────────┬──────────────────────┘                    │
                        │ calls async methods            withObservationTracking
                        ▼                                            │
        ┌──────────────────────────────────────┐                    │
        │   @Observable @MainActor ViewModel    │────────────────────┘
        │  - items / isLoading / errorMessage   │
        └───────────────┬──────────────────────┘
                        │ await fetchItems()
                        ▼
        ┌──────────────────────────────────────┐
        │  APIClientProtocol  (actor APIClient) │
        │  - send<T>(_:) over URLSession        │
        │  - typed APIError                     │
        └───────────────┬──────────────────────┘
                        │ URLRequest (Endpoint.urlRequest)
                        ▼
                  ┌───────────┐
                  │  Network  │
                  └───────────┘
```

The view controller observes the `@Observable` view model via
`withObservationTracking`, re-registering after each change so updates keep
flowing. The view model never imports AppKit; the view controller never performs
networking.

## Patterns

- **MVVM**: View controllers are thin and own no business logic. View models are
  `@MainActor @Observable`, expose plain state, and orchestrate async work.
- **Dependency Injection**: View models receive an `APIClientProtocol`; settings
  receive a `UserDefaultsManager`. Tests inject `MockAPIClient`.
- **Programmatic AppKit**: All views are built in code (`loadView()` /
  `NSStackView` / Auto Layout helpers). No nibs; `NSMainNibFile` is empty.
- **Window Controller**: `AppDelegate` wraps each window in an
  `NSWindowController` and retains it, the idiomatic AppKit ownership pattern.
- **Actors for concurrency**: `APIClient` is an `actor`; UI types are `@MainActor`.

## Where to Add a New Feature / Window

1. Create `Features/<Name>/<Name>ViewController.swift` and
   `<Name>ViewModel.swift`. Build the VC's UI in `loadView()`.
2. Make the view model `@MainActor @Observable`, inject any `Core` dependencies
   through its initializer, and expose only plain state plus async actions.
3. To present it as a window, follow `AppDelegate.openSettings(_:)`: create an
   `NSWindow`, set its `contentViewController`, wrap it in an
   `NSWindowController`, retain the controller, and `showWindow`.
4. To add a menu entry, append an `NSMenuItem` in `AppDelegate.setupMainMenu()`
   with a `target`/`action` that opens the new window.
5. Add `Tests/Unit/<Name>ViewModelTests.swift` exercising success and error
   paths via a mock dependency.
```
