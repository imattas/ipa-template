# macOS-AppKit Template

![CI](https://github.com/imattas/ipa-template/actions/workflows/build.yml/badge.svg)

A production-ready scaffolding for a native **macOS** app built with
**Swift 6 + AppKit**, fully **programmatic UI** (no Storyboards), and an
**MVVM** architecture using the **Observation** framework (`@Observable`).

## Overview

- Single, explicit entry point in `main.swift` (no `@main` on the delegate).
- `AppDelegate` builds the main `NSWindow` (via `NSWindowController`), a
  programmatic main menu, and a separate Settings window.
- `HomeViewController` renders a view-based `NSTableView` driven by an
  `@Observable @MainActor` view model that loads data asynchronously.
- Networking layer is an `actor`-based `APIClient` (async/await over
  `URLSession`) behind a protocol, with a `MockAPIClient` for tests.
- Typed `UserDefaultsManager` powers a programmatic Settings form.
- Unit tests cover the Home view model's success and error paths.

## Folder Tree

```
macOS-AppKit/
├── App/
│   ├── main.swift            # Single entry point: builds NSApplication, runs
│   ├── AppDelegate.swift     # Window, menu, settings window
│   └── Info.plist
├── Features/
│   ├── Home/                 # HomeViewController + HomeViewModel
│   └── Settings/             # SettingsViewController + SettingsViewModel
├── Core/
│   ├── Networking/           # APIClient, Endpoint, Item, APIError
│   ├── Storage/              # UserDefaultsManager
│   └── Extensions/           # NSView+Extensions (Auto Layout helpers)
├── Resources/
│   └── Assets.xcassets/      # AppIcon, AccentColor
├── Tests/
│   └── Unit/                 # HomeViewModelTests
└── docs/                     # ARCHITECTURE, SETUP, CONTRIBUTING
```

## Pattern: MVVM

- **View** (`NSViewController`): builds the UI programmatically, forwards user
  actions, and re-renders by observing the view model. No business logic.
- **ViewModel** (`@MainActor @Observable`): holds presentation state
  (`items`, `isLoading`, `errorMessage`) and orchestrates async work.
- **Model / Services** (`Core`): networking and storage behind protocols, making
  view models trivially testable via dependency injection.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the data-flow diagram and
guidance on adding a new feature or window.

## Build & Run

Prerequisites: **Xcode 16+**, **macOS 14+** deployment target (a pre-macOS 14
`ObservableObject` fallback is documented in
[docs/SETUP.md](docs/SETUP.md)).

This template intentionally ships **without an `.xcodeproj`**. Generate a project
(Xcode App target, or SPM/XcodeGen/Tuist) that includes the `App/`, `Features/`,
`Core/`, and `Resources/` folders plus a test target over `Tests/Unit/`, then:

- Build & run: **⌘R**
- Run tests: **⌘U**

Full instructions: [docs/SETUP.md](docs/SETUP.md).

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for the style guide, branch
naming (`feature/*`, `fix/*`, `chore/*`), and the PR process.
