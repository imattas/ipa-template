# visionOS-RealityKit Template

![CI](https://github.com/imattas/ipa-template/actions/workflows/build.yml/badge.svg)

A production-ready scaffolding for a **visionOS** app built with **Swift 6**,
**SwiftUI**, and **RealityKit**. It demonstrates the canonical visionOS shape: a
2D **window** for controls plus an **immersive space** for 3D content, with a
single `@Observable` manager shared between them.

## Overview

- **Window scene** (`ContentView`): a glass control panel that opens/closes the
  immersive space, shows live status, and spawns/resets 3D entities.
- **Immersive space** (`ImmersiveView`): a `RealityView` that builds its scene
  from `RealityManager` and supports spatial tap gestures.
- **`RealityManager`** (`@Observable @MainActor`): owns the RealityKit scene
  graph and the immersive-space lifecycle state — the single source of truth.

## Folder tree

```
visionOS-RealityKit/
├── App/
│   ├── AppEntry.swift          # @main App: WindowGroup + ImmersiveSpace
│   └── Info.plist
├── Core/
│   └── RealityManager.swift    # @Observable @MainActor scene + state manager
├── Features/
│   ├── WindowScene/
│   │   └── ContentView.swift   # 2D control panel
│   └── ImmersiveSpace/
│       └── ImmersiveView.swift # RealityView 3D content
├── Resources/
│   └── Assets.xcassets/        # AppIcon (layered), AccentColor
├── Tests/
│   └── Unit/
│       └── RealityManagerTests.swift
├── docs/
│   ├── ARCHITECTURE.md
│   └── SETUP.md
└── README.md
```

## Pattern

MVVM-ish with a **manager**. SwiftUI views stay declarative and delegate all
behavior and RealityKit knowledge to `RealityManager`, which is injected through
the SwiftUI environment (`.environment(_:)` / `@Environment(RealityManager.self)`).
The window and immersive scenes never talk directly — they share the manager.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for diagrams and extension
points ("where to add new 3D content / a new gesture").

## Build & run

1. Install **Xcode 16+** with the **visionOS SDK** and the visionOS Simulator.
2. Create a new visionOS **App** project (Window + RealityKit immersive space)
   and drop in the `App/`, `Core/`, `Features/`, and `Resources/` folders.
3. Set the deployment target to **visionOS 2.0** and bundle id
   `com.example.visionos`.
4. Select the **Apple Vision Pro** simulator and press **⌘R**.

Full instructions: [docs/SETUP.md](docs/SETUP.md).

## Requirements

- Xcode 16+, visionOS 2 SDK
- Swift 6 (async/await, `@MainActor`, Observation)
