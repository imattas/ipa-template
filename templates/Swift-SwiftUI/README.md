# Swift-SwiftUI Template

![CI](https://github.com/imattas/ipa-template/actions/workflows/build.yml/badge.svg)

A production-ready starting point for a **universal Apple app** (iOS, iPadOS,
macOS) built with **Swift 6** and **SwiftUI**. It ships with an opinionated
**MVVM + Router** architecture, protocol-oriented networking, dependency
injection, and tests — so you can start building features immediately instead of
wiring up infrastructure.

## Overview

- **Universal:** one codebase for iOS / iPadOS / macOS.
- **MVVM:** thin SwiftUI views backed by `@Observable`, `@MainActor` view models.
- **Router/Coordinator:** centralized, typed navigation via `AppRouter` driving a
  `NavigationStack`.
- **Networking:** `async/await` over `URLSession`, an `actor`-based `APIClient`
  behind `APIClientProtocol`, typed `APIError`, and a `MockAPIClient` for
  previews/tests.
- **Testable:** XCTest unit tests for view models and a XCUITest launch test.

## Folder tree

```
Swift-SwiftUI/
├── App/
│   ├── AppEntry.swift          # @main; owns AppRouter; root NavigationStack
│   └── Info.plist
├── Features/
│   ├── Home/                   # HomeView + HomeViewModel
│   └── Settings/               # SettingsView + SettingsViewModel
├── Core/
│   ├── Navigation/AppRouter.swift
│   ├── Networking/             # APIClient.swift, Endpoint.swift
│   ├── Storage/AppStorage+Keys.swift
│   └── Extensions/View+Extensions.swift
├── Resources/Assets.xcassets/  # AppIcon, AccentColor
├── Tests/
│   ├── Unit/                   # HomeViewModelTests
│   └── UI/                     # HomeViewTests
└── docs/                       # ARCHITECTURE, SETUP, CONTRIBUTING
```

## Pattern: MVVM + Router

```
View  ⇄  @Observable ViewModel  ⇄  APIClient (Protocol)
                  ▲
                  │ drives
              AppRouter  ⇒  NavigationStack(path:)
```

The view renders state and forwards intent; the view model owns presentation
state and talks to the API via `async/await`; the router owns the navigation
path. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full data-flow
diagram and rationale.

## Build & run

- **Requirements:** Xcode 16+, deployment target iOS 17 / macOS 14
  (with an `ObservableObject` fallback noted in code for earlier OSes).
- This template intentionally ships **without** an `.xcodeproj`. Add the source
  folders to a new Multiplatform App target (or generate a project with
  XcodeGen/Tuist), set the bundle id to `com.example.swiftswiftui`, and add the
  asset catalog and test bundles.

Full instructions: [docs/SETUP.md](docs/SETUP.md).

Run tests:

```bash
xcodebuild test \
  -scheme Swift-SwiftUI \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Contributing

See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for the style guide, branch
naming (`feature/*`, `fix/*`, `chore/*`), and PR process.
```
