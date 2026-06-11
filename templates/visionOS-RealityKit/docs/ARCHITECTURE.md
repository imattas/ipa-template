# Architecture

This template is a **dual-scene visionOS app**: a 2D window for controls and an
immersive RealityKit space for 3D content. State is centralized in a single
`@Observable` manager that both scenes share.

## Folder structure

```
visionOS-RealityKit/
├── App/
│   ├── AppEntry.swift          # @main App: WindowGroup + ImmersiveSpace, env injection
│   └── Info.plist              # Scene manifest, bundle id (com.example.visionos)
├── Core/
│   └── RealityManager.swift    # @Observable @MainActor: scene graph + immersive state
├── Features/
│   ├── WindowScene/
│   │   └── ContentView.swift   # 2D glass control panel
│   └── ImmersiveSpace/
│       └── ImmersiveView.swift # RealityView (3D content + gestures)
├── Resources/
│   └── Assets.xcassets/        # App icon (layered), accent color
├── Tests/
│   └── Unit/
│       └── RealityManagerTests.swift
└── docs/
    ├── ARCHITECTURE.md
    └── SETUP.md
```

### Rationale

- **`App/`** holds the composition root only. Wiring (which scenes exist, how
  state is injected, immersion style) lives here and nowhere else.
- **`Core/`** holds framework-facing, view-agnostic logic. `RealityManager`
  knows about RealityKit entities but not about any specific SwiftUI view.
- **`Features/`** is split by *scene*, mirroring the two distinct surfaces of a
  visionOS app (window vs. immersive). This keeps the 2D and 3D concerns from
  bleeding into each other.
- **`Resources/`** isolates asset catalogs so they're easy to find and swap.

## Component diagram

```
        ┌───────────────────────────┐
        │       AppEntry (@main)     │
        │  WindowGroup + Immersive   │
        │  @State RealityManager     │
        │  .environment(reality)     │
        └─────────────┬─────────────┘
                      │ injects
        ┌─────────────▼──────────────────────────────┐
        │                                             │
┌───────┴────────────┐                    ┌───────────┴───────────┐
│  ContentView       │   observes /       │   ImmersiveView       │
│  (2D window)       │◄── commands ──────►│   (RealityView / 3D)  │
│  - open/dismiss    │                    │   - make: buildScene  │
│    immersive space │   ┌────────────┐   │   - update closure    │
│  - spawn / reset   │──►│ Reality    │◄──│   - SpatialTapGesture │
│  - status readout  │   │ Manager    │   │                       │
└────────────────────┘   │ @Observable│   └───────────────────────┘
                         │ @MainActor │
                         │  - root    │
                         │  - state   │
                         └────────────┘
```

`ContentView` and `ImmersiveView` never talk to each other directly. They both
read and mutate `RealityManager`, which owns the RealityKit scene graph and the
immersive-space lifecycle state.

## Patterns

- **MVVM-ish with a manager.** `RealityManager` plays the view-model/model role.
  Views stay declarative and delegate behavior to the manager.
- **Window + immersive dual-scene.** A `WindowGroup` and an `ImmersiveSpace`
  declared in `AppEntry`. The immersive space is opened/closed imperatively from
  the window via the `openImmersiveSpace` / `dismissImmersiveSpace` environment
  actions (async/await).
- **Environment injection.** A single `@State` manager is shared via
  `.environment(_:)` and read with `@Environment(RealityManager.self)`. This
  avoids singletons and keeps previews trivial (`.environment(RealityManager())`).
- **Modern Observation.** `@Observable` (not `ObservableObject`) — see the note
  in `RealityManager.swift`: visionOS always ships an Observation-capable
  runtime, so no fallback is needed.

## Where to add things

### A new piece of 3D content
1. Add a builder/helper in `RealityManager` (e.g. `makeTorus(...)`) that returns
   a configured `ModelEntity` with `SimpleMaterial`, collision shapes, and an
   `InputTargetComponent` if it should be tappable.
2. Attach it to `contentContainer` inside `buildScene()` (for starter content)
   or in a new public method (for on-demand spawning), and update `entityCount`.

### A new gesture
1. Add a handler method on `RealityManager` (e.g. `handleDrag(...)`).
2. In `ImmersiveView`, attach a gesture to the `RealityView`, e.g.
   `.gesture(DragGesture().targetedToAnyEntity().onChanged { ... })`, and call
   the manager from its callback. Ensure target entities have collision shapes +
   `InputTargetComponent`.

### A new window control
Add SwiftUI controls to `ContentView` that read/command `RealityManager`. Keep
RealityKit types out of the view; route through the manager.
