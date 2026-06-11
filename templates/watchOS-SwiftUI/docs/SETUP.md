# Setup

## Prerequisites

- **macOS** with **Xcode 16 or later**.
- **watchOS 10+ deployment target** (required by the `@Observable` macro and
  `.containerBackground`).
  - **Fallback for older watchOS:** lower the deployment target and replace
    `@Observable` view models with `ObservableObject` + `@Published`, observing
    them via `@StateObject` / `@ObservedObject` instead of `@State`. See the
    notes in `HomeViewModel.swift` / `SettingsViewModel.swift`.
- A watch simulator or a paired Apple Watch for on-device testing.

## Clone & Open

```bash
git clone https://github.com/imattas/ipa-template.git
cd ipa-template/templates/watchOS-SwiftUI
```

> This template intentionally ships **without** an `.xcodeproj`. Create an
> Xcode project (or Swift Package) targeting watchOS, then add the `App`,
> `Features`, `Core`, and `Resources` folders to the watch app target and the
> `Tests` folder to a unit-test target. Set the test target's host/`@testable`
> module name to `watchOS_SwiftUI` (or update the `import` in the tests).

## Configure

- **Bundle identifier:** `com.example.watchos` (see `App/Info.plist`). Change it
  to your own reverse-DNS identifier.
- **API base URL:** update the default `baseURL` in `Core/Networking/APIClient.swift`.
- **Background refresh interval:** tune `scheduleNextBackgroundRefresh()` in
  `App/AppDelegate.swift`.

## Run

1. Select the watch app scheme.
2. Choose a watch simulator (e.g. *Apple Watch Series 10 (46mm)*).
3. Press **Run** (⌘R).

## Test

- In Xcode: **Product ▸ Test** (⌘U).
- From the command line:

```bash
xcodebuild test \
  -scheme watchOS-SwiftUI \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'
```

The unit tests use `MockAPIClient`, so they run without any network access.
