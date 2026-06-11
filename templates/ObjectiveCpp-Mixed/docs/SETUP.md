# Setup

## Prerequisites

- **Xcode 16+** with the iOS SDK.
- **iOS 15** deployment target (minimum).
- A basic understanding of Objective-C++ interop. Two rules matter most:
  - **Any file that consumes C++ must use the `.mm` extension** so Clang
    compiles it in Objective-C++ mode.
  - **The bridge header (`EngineBridge.h`) must stay C++-free** so it remains
    importable from Swift and plain Objective-C. C++ lives only in `.hpp`/`.cpp`
    and `.mm` files.

## Get the code

```bash
git clone https://github.com/imattas/ipa-template.git
cd ipa-template/templates/ObjectiveCpp-Mixed
```

## Create / open an Xcode project

This template ships **source only** — no `.xcodeproj`. To build it:

1. In Xcode, create a new **iOS App** target (language: Objective-C).
2. Remove the auto-generated `AppDelegate`/`ViewController` files.
3. Add the `App/`, `Features/`, `Core/`, and `Resources/` folders to the
   target (choose "Create groups").
4. Add `Resources/Assets.xcassets` and set the app's Info.plist to `App/Info.plist`.
5. In **Build Settings**:
   - Set **C++ Language Dialect** to `GNU++17` (or `C++17`).
   - Set **C++ Standard Library** to `libc++`.
   - Set the **iOS Deployment Target** to `15.0`.
6. Add a **Unit Test** target and add `Tests/Unit/EngineBridgeTests.mm` to it,
   together with the `Core/Engine` and `Core/Bridge` sources (or link the app
   target into the test target).

> Tip: rename `AppDelegate.m`/`ViewController.m` to `.mm` if you let Xcode
> generate them, since this template uses `.mm` for the app lifecycle files.

## Run the tests

From Xcode press **⌘U**, or from the command line:

```bash
xcodebuild test \
  -scheme ObjectiveCppMixed \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

The tests in `Tests/Unit/EngineBridgeTests.mm` verify that `EngineBridge`
faithfully forwards to the underlying `app::ComputeEngine`.

## Configuration

- **Bundle identifier:** `com.example.objcppmixed` (in `App/Info.plist`).
- **Accent color / launch screen:** edit
  `Resources/Assets.xcassets/AccentColor.colorset/Contents.json`.
- **App icon:** drop a 1024×1024 PNG into
  `Resources/Assets.xcassets/AppIcon.appiconset/`.
- **Networking base URL / endpoints:** see the `TODO` markers in
  `Core/Networking/APIClient.mm`.
