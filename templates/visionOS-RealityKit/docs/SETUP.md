# Setup

## Prerequisites

- **macOS** recent enough to run Xcode 16.
- **Xcode 16+** with the **visionOS SDK** installed
  (Xcode ▸ Settings ▸ Components ▸ visionOS).
- **visionOS 2** deployment target.
- The **visionOS Simulator** (installed alongside the visionOS SDK) or an Apple
  Vision Pro device for on-device testing.
- Swift 6 toolchain (bundled with Xcode 16).

## Get the code

```bash
git clone https://github.com/imattas/ipa-template.git
cd ipa-template/templates/visionOS-RealityKit
```

## Create / open the Xcode project

This template intentionally ships **without** an `.xcodeproj` so you can drop the
sources into a project of your choosing. To run it:

1. In Xcode, choose **File ▸ New ▸ Project… ▸ visionOS ▸ App**.
   - Product Name: anything (e.g. `VisionOSRealityKit`).
   - Initial Scene: **Window**.
   - Immersive Space Renderer: **RealityKit**.
   - Language: **Swift**.
2. Delete the generated `App`, `ContentView`, and `ImmersiveView` stubs.
3. Drag the `App/`, `Core/`, `Features/`, and `Resources/` folders from this
   template into the project navigator (choose *Create groups*).
4. In the target's **General** settings, confirm:
   - **Minimum Deployments**: visionOS 2.0.
   - **Bundle Identifier**: `com.example.visionos` (or your own).
   - The `Assets.xcassets` from `Resources/` is the target's asset catalog.
5. Use this template's `Info.plist` (or merge its `UIApplicationSceneManifest`
   into the generated one).

## Run in the simulator

1. Select the **Apple Vision Pro** simulator as the run destination.
2. Press **⌘R**.
3. The window control panel appears. Tap **Enter Immersive Space** to open the
   3D scene, then **Spawn Random Entity** / tap entities to interact.

## Configuration

- **Immersion style** — edit `.immersionStyle(...)` in `AppEntry.swift`
  (`.mixed`, `.progressive`, `.full`).
- **Default window size** — `.defaultSize(...)` in `AppEntry.swift`.
- **Bundle identifier** — `Info.plist` and target settings.
- **Accent color** — `Resources/Assets.xcassets/AccentColor.colorset`.
- **App icon** — visionOS icons are layered; replace the `.solidimagestacklayer`
  references in `AppIcon.appiconset/Contents.json` with real Back/Middle/Front
  layers exported from your design tool.

## Tests

If you add the optional `Tests/Unit/RealityManagerTests.swift` to a test target,
run them with **⌘U** or:

```bash
xcodebuild test -scheme YourScheme -destination 'platform=visionOS Simulator,name=Apple Vision Pro'
```
