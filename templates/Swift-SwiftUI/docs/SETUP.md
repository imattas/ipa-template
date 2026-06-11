# Setup

## Prerequisites

- **Xcode 16+** (Swift 6 toolchain).
- **Deployment target: iOS 17 / iPadOS 17 / macOS 14** or later.
  - These targets are required by the **Observation framework** (`@Observable`)
    and several SwiftUI APIs used here (`ContentUnavailableView`,
    `navigationDestination`).
  - **Fallback for earlier OSes:** replace `@Observable` with
    `ObservableObject` + `@Published` in the view models and `AppRouter`, and
    observe with `@StateObject` / `@ObservedObject` in the views. Inline notes in
    those files mark exactly what to change.
- An Apple Developer account is only needed for running on a physical device.

## Get the code

```bash
git clone https://github.com/imattas/ipa-template.git
cd ipa-template/templates/Swift-SwiftUI
```

## Open and run

This template ships **without** an `.xcodeproj` on purpose. Generate a project
or add the sources to your own Xcode project / Swift package:

1. In Xcode: **File ▸ New ▸ Project ▸ Multiplatform App**, then drag the
   `App/`, `Features/`, `Core/`, and `Resources/` folders into the project
   (choose "Create groups").
2. Set the app's **Info.plist** to `App/Info.plist` and the **bundle identifier**
   to `com.example.swiftswiftui` (or your own).
3. Set the **deployment targets** to iOS 17 / macOS 14.
4. Add `Resources/Assets.xcassets` to the app target and set the **App Icon**
   and **Accent Color** to the provided asset sets.
5. Add `Tests/Unit` to a **Unit Testing Bundle** and `Tests/UI` to a **UI Testing
   Bundle**.

> Alternatively, use a project generator such as XcodeGen or Tuist and point it
> at these folders.

## Run the tests

From Xcode: **Product ▸ Test** (⌘U).

From the command line:

```bash
xcodebuild test \
  -scheme Swift-SwiftUI \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Configuration

- **API base URL:** set in `Core/Networking/APIClient.swift` (`APIClient.init`
  default). Look for the `// TODO: configure` marker. Prefer injecting it from a
  build configuration / `.xcconfig` for real apps.
- **Offline / preview mode:** inject `MockAPIClient()` into `AppEntry` (or any
  view model) instead of the live `APIClient`.
- **Persisted preferences:** keys live in `Core/Storage/AppStorage+Keys.swift`.
```
