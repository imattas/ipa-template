# watchOS-SwiftUI Template

![CI](https://github.com/imattas/ipa-template/actions/workflows/build.yml/badge.svg)

A production-ready scaffolding for a single-target **watchOS** app built with
**Swift + SwiftUI** and the **WatchKit lifecycle**, following the **MVVM**
pattern with dependency injection and Swift 6 concurrency.

## Overview

- SwiftUI `App` entry point bridged to WatchKit via
  `@WKApplicationDelegateAdaptor`, including a background-refresh task stub.
- `@Observable`, `@MainActor` view models that load data through an injected,
  `Sendable` networking protocol (`APIClientProtocol`).
- An `actor`-based `APIClient` over `URLSession` with typed `APIError`s, plus a
  `MockAPIClient` for tests and previews.
- Settings backed by `@AppStorage` with namespaced keys.
- Unit tests demonstrating success and error paths.

## Folder Tree

```
watchOS-SwiftUI/
├── App/
│   ├── AppEntry.swift
│   ├── AppDelegate.swift
│   └── Info.plist
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── HomeViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
├── Core/
│   ├── Networking/
│   │   ├── APIClient.swift
│   │   └── Endpoint.swift
│   └── Storage/
│       └── AppStorage+Keys.swift
├── Resources/
│   └── Assets.xcassets/
├── Tests/
│   └── Unit/
│       └── HomeViewModelTests.swift
└── docs/
    ├── ARCHITECTURE.md
    ├── SETUP.md
    └── CONTRIBUTING.md
```

## Pattern

**MVVM** — Views are declarative and delegate all state and logic to
`@Observable` view models. View models depend on `Core` infrastructure through
protocols, so dependencies can be swapped for mocks in tests and previews.
See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full data-flow diagram.

## Build & Run

This template ships without an `.xcodeproj`. Create a watchOS app target in
Xcode 16+, add the source folders, then:

1. Select the watch app scheme.
2. Choose a watch simulator (e.g. *Apple Watch Series 10*).
3. Press **Run** (⌘R).

Run tests with **Product ▸ Test** (⌘U). Full instructions are in
[docs/SETUP.md](docs/SETUP.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Setup](docs/SETUP.md)
- [Contributing](docs/CONTRIBUTING.md)
