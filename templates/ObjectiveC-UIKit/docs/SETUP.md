# Setup

## Prerequisites

- **macOS** with **Xcode 16 or newer**.
- **iOS 15.0** deployment target (the template uses APIs available from iOS 15+,
  such as `UIListContentConfiguration` and `prefersLargeTitles`).
- Command Line Tools installed (`xcode-select --install`).

## Getting the code

```bash
git clone https://github.com/imattas/ipa-template.git
cd ipa-template/templates/ObjectiveC-UIKit
```

> This template intentionally ships **without** an `.xcodeproj`. Generate one
> with your tool of choice (Xcode's *File ▸ New ▸ Project*, XcodeGen, or
> Tuist) and add the source folders below, or drop these files into an existing
> project.

### Recommended Xcode project layout

When wiring up a project, add the groups so they map to the folders on disk:

- App target: `App/`, `Features/`, `Core/`, `Resources/Assets.xcassets`
  - Set **Info.plist File** to `App/Info.plist`.
  - Set **Bundle Identifier** to `com.example.objcuikit` (change for your app).
  - Set **iOS Deployment Target** to `15.0`.
  - Enable **Automatic Reference Counting (ARC)** (default).
- Unit test target: `Tests/Unit/`, with the app target as its host.

## Running

1. Open the generated project in Xcode.
2. Select an iPhone or iPad simulator (or a device).
3. Press **⌘R** to build and run.

The app launches into `HomeViewController`, attempts to load items from the
placeholder API, and shows an error alert (with Retry) because the default
`baseURL` is a stub — see the TODO in `Core/Networking/APIClient.m`.

## Running tests

From Xcode: **⌘U**.

From the command line:

```bash
xcodebuild test \
  -scheme ObjectiveC-UIKit \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

The tests in `Tests/Unit/APIClientTests.m` are self-contained: they inject a
stub `NSURLSession` (via `NSURLProtocol`) into `APIClient`, so **no network
access is required**.

## Configuration

- **API base URL** — edit `kDefaultBaseURLString` in
  `Core/Networking/APIClient.m`, or construct an `APIClient` with
  `initWithBaseURL:session:` and inject it where needed.
- **Accent color** — edit `Resources/Assets.xcassets/AccentColor.colorset`.
- **App icon** — add image assets to
  `Resources/Assets.xcassets/AppIcon.appiconset`.
- **Settings defaults** — toggle keys live at the top of
  `Features/Settings/SettingsViewController.m`.
