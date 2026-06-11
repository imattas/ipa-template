# Setup

## Prerequisites

- **Xcode 16 or newer** (required for Swift 6 language mode and the Observation
  framework).
- **iOS 17 deployment target** recommended — the template uses `@Observable` and
  `withObservationTracking`.
  - **iOS 13 fallback:** the app lifecycle (`SceneDelegate`) supports iOS 13+.
    To deploy below iOS 17, replace the `@Observable` view models with
    `ObservableObject` + `@Published` (see the inline note in
    `Features/Home/HomeViewModel.swift`) and observe via Combine.
- A configured Apple developer team if you intend to run on a physical device.

## Clone and open

```bash
git clone https://github.com/imattas/ipa-template.git
cd ipa-template/templates/Swift-UIKit
```

This template is distributed as a **source tree only** (no `.xcodeproj`). To
build it, either:

- Create a new Xcode iOS App project and drag these folders in, **or**
- Generate a project with a tool such as XcodeGen / Tuist pointing at this tree.

Set the bundle identifier to `com.example.swiftuikit` (or your own) and the
deployment target to iOS 17.0.

## Running the app

Select an iOS Simulator (or device) and press **Cmd+R**.

## Running tests

- In Xcode: **Cmd+U** runs the full unit + UI test suite.
- From the command line:

```bash
xcodebuild test \
  -scheme Swift-UIKit \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'
```

Adjust the simulator `name`/`OS` to one installed on your machine
(`xcrun simctl list devices`).

## Configuration notes

- The networking base URL is set in `APIClient.init` (`https://api.example.com/v1`).
  Override it per environment via injection from `SceneDelegate`, or load it from
  an `xcconfig`/`Info.plist` value.
- `APIClient.fetchItems()` currently returns stubbed sample data. Replace the
  stub with `return try await send(.items)` once your backend is ready.
- Persisted settings keys live in `Core/Storage/UserDefaultsManager.swift`.
