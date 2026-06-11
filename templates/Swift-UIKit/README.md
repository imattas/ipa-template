# Swift-UIKit Template

![CI](https://github.com/imattas/ipa-template/actions/workflows/build.yml/badge.svg)

A production-ready scaffolding for **Swift + UIKit** iOS/iPadOS apps using the
**MVVM** pattern, Swift 6 concurrency, and a protocol-oriented networking layer.
It ships with programmatic UIKit screens, an `@Observable` view-model layer,
manual dependency injection, typed storage, reusable extensions, and unit + UI
test scaffolding — so you can start building features immediately instead of
wiring boilerplate.

## Folder structure

```
Swift-UIKit/
├── App/                 # AppDelegate, SceneDelegate, Info.plist
├── Features/
│   ├── Home/            # HomeViewController + HomeViewModel
│   └── Settings/        # SettingsViewController + SettingsViewModel
├── Core/
│   ├── Networking/      # APIClient, Endpoint, APIError, Item model
│   ├── Storage/         # UserDefaultsManager (@propertyWrapper)
│   └── Extensions/      # UIView+Extensions, String+Extensions
├── Resources/           # Assets.xcassets, LaunchScreen.storyboard
├── Tests/
│   ├── Unit/            # HomeViewModelTests (mock APIClient)
│   └── UI/              # HomeUITests (XCUIApplication)
└── docs/                # ARCHITECTURE, SETUP, CONTRIBUTING
```

## Pattern: MVVM

- **View** (`*ViewController`) — programmatic UIKit, `@MainActor`, observes the
  view model via `withObservationTracking` and forwards user intent.
- **ViewModel** (`*ViewModel`) — `@MainActor @Observable`, owns screen state
  (`items` / `isLoading` / `errorMessage`) and talks to services through
  protocols.
- **Model / Services** — `APIClient` (an `actor` conforming to
  `APIClientProtocol`), `Endpoint`, typed `APIError`, and the `Item` model.

Dependencies are constructed once in `SceneDelegate` and injected downward,
making view models trivially testable with mocks. See
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full data-flow diagram.

## Build & run

1. **Requirements:** Xcode 16+, iOS 17 deployment target (iOS 13 fallback noted
   inline in `HomeViewModel`).
2. This is a source tree only — no `.xcodeproj`. Drop the folders into a new
   Xcode iOS App target, or generate a project with XcodeGen/Tuist.
3. Set the bundle id to `com.example.swiftuikit` and press **Cmd+R**.

### Tests

```bash
# Xcode: Cmd+U
xcodebuild test \
  -scheme Swift-UIKit \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'
```

See [`docs/SETUP.md`](docs/SETUP.md) for detailed setup and
[`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) for code style and PR process.
