# Setup

## Prerequisites

- **macOS 14 (Sonoma) or later** to build the template as configured.
- **Xcode 16 or later** (provides the Swift 6 toolchain and the AppKit SDK).
- Command Line Tools: `xcode-select --install`.

### Deployment target & the `@Observable` fallback

The deployment target is **macOS 14** (`LSMinimumSystemVersion` in `Info.plist`).
This is required because the view models use the `@Observable` macro from the
**Observation** framework, which is macOS 14+.

If you must support **macOS 13 or earlier**, lower the deployment target and
convert each view model from `@Observable` to `ObservableObject`:

```swift
final class HomeViewModel: ObservableObject {
    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
}
```

Then have the view controller subscribe to the `@Published` publishers (Combine)
instead of using `withObservationTracking`. See the comments in
`Features/Home/HomeViewModel.swift`.

## Clone

```bash
git clone https://github.com/imattas/ipa-template.git
cd ipa-template/templates/macOS-AppKit
```

## Open / Generate a Project

This template ships **without an `.xcodeproj`** so it stays tooling-agnostic.
Pick one of:

- **Xcode**: Create a new "App" (macOS) project, then drag the `App/`,
  `Features/`, `Core/`, and `Resources/` folders in (choose *Create groups*).
  Set the target's *Info.plist* to `App/Info.plist` and add a unit test target
  pointing at `Tests/Unit/`.
- **Swift Package Manager / XcodeGen / Tuist**: Generate a project that maps the
  same folders to an executable target plus a test target. Name the app module
  `macOS_AppKit` so the test's `@testable import macOS_AppKit` resolves.

## Run

From Xcode, select the app scheme and press **⌘R**. The app launches a single
resizable window titled "macOS-AppKit Template" hosting the Home screen. Open
**Settings…** from the app menu (or **⌘,**).

## Run Tests

- In Xcode: **⌘U**.
- From the command line (if you generate an SPM/xcodebuild project):

```bash
xcodebuild test \
  -scheme macOS-AppKit \
  -destination 'platform=macOS'
```

The unit tests use `MockAPIClient`, so they make **no network calls**.

## Configuration

- **API base URL**: set in `Core/Networking/APIClient.swift`
  (`init(baseURL:)`, default `https://api.example.com`). Replace with your
  backend, or inject a different URL at the call site.
- **Endpoints**: defined in `Core/Networking/Endpoint.swift`
  (see `Endpoint.items`).
- **Preferences keys**: centralized in `Core/Storage/UserDefaultsManager.swift`.
- **Bundle identifier**: `com.example.macosappkit` in `App/Info.plist`.
```
