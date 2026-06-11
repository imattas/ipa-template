# Templates Overview

This repository ships ten templates. Each is a self-contained, production-ready
skeleton under `templates/<Name>/`. This guide summarizes what each one is for
and when to reach for it.

## At a glance

| Template | Language | Platform(s) | Best for |
|---|---|---|---|
| **Swift-UIKit** | Swift | iOS / iPadOS | New iOS apps that need fine-grained UIKit control, complex custom transitions, or interop with a large existing UIKit codebase. |
| **Swift-SwiftUI** | Swift | iOS / iPadOS / macOS | New, multi-platform apps. The default choice for greenfield work. |
| **ObjectiveC-UIKit** | Objective-C | iOS / iPadOS | Extending or maintaining established Objective-C apps; teams standardized on ObjC. |
| **ObjectiveCpp-Mixed** | Objective-C++ / C++ | iOS | Apps with a portable C++ core (engine, codec, ML, cross-platform business logic) bridged into an Apple UI. |
| **Metal** | Swift + Metal | iOS | Custom GPU rendering and/or compute: games, visualizers, image/video processing, simulations. |
| **visionOS-RealityKit** | Swift + RealityKit | visionOS | Spatial apps mixing 2D windows with immersive 3D content. |
| **watchOS-SwiftUI** | Swift + WatchKit | watchOS | Standalone or companion watch apps with background refresh. |
| **macOS-AppKit** | Swift + AppKit | macOS | Native Mac apps needing deep AppKit features (menus, windows, document model) beyond SwiftUI's reach. |
| **C-Library** | C (C11) | cross-platform | A low-level, dependency-free C utility/library target to embed or vend. |
| **CPlusPlus-Framework** | C++ (C++17) | cross-platform | A reusable C++ core packaged as a static lib or `xcframework`. |

## Shared architecture

Every UI template follows the same spine so the templates feel consistent:

```
App/         App lifecycle / entry point
Features/    One folder per screen: a View(Controller) + its ViewModel
Core/        Cross-feature infrastructure
  Networking/  APIClient (async, typed errors) + Endpoint
  Storage/     UserDefaults / @AppStorage wrappers
  Navigation/  Router (SwiftUI templates)
  Extensions/  Small, focused helpers
Resources/   Assets.xcassets, launch screens
Tests/       Unit/ and UI/ targets
docs/        ARCHITECTURE / SETUP / CONTRIBUTING
```

The C and C++ templates use the canonical `include/` · `src/` · `tests/` ·
`docs/` library layout instead.

## How to choose

- **Greenfield Apple app, one or many platforms?** → **Swift-SwiftUI**.
- **iOS only, need imperative UIKit power or heavy UIKit interop?** →
  **Swift-UIKit**.
- **Maintaining an Objective-C app?** → **ObjectiveC-UIKit**.
- **Have a C++ engine to reuse on iOS?** → **ObjectiveCpp-Mixed** (UI bridge) +
  **CPlusPlus-Framework** (the engine itself).
- **Custom GPU work?** → **Metal**.
- **Spatial / Vision Pro?** → **visionOS-RealityKit**.
- **Apple Watch?** → **watchOS-SwiftUI**.
- **Native Mac with classic AppKit needs?** → **macOS-AppKit**.
- **Portable low-level code?** → **C-Library** or **CPlusPlus-Framework**.

For a head-to-head on the language/UI-framework tradeoffs, see
[`COMPARISON.md`](COMPARISON.md).

## Using a template

1. Copy the template directory out of the repo:
   `cp -R templates/<Name> ~/Developer/MyApp`.
2. Follow that template's `docs/SETUP.md` to wire it into an Xcode project or a
   Swift Package, set your bundle identifier, and choose a deployment target.
3. Replace the stubbed `APIClient` endpoints, sample `Item` model, and the
   `TODO:` markers with your real logic.
4. Build on the existing `Features/` pattern as you add screens.
