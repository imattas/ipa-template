# Comparison — Swift vs Objective-C vs SwiftUI (and friends)

A practical tradeoff guide for picking a stack. There is no universally "best"
choice; the right one depends on your platform targets, team, and how much
existing code you're building on.

## Language: Swift vs Objective-C vs Objective-C++ vs C/C++

| Dimension | Swift | Objective-C | Objective-C++ | C / C++ |
|---|---|---|---|---|
| **Memory safety** | High (value types, optionals, bounds checks) | Manual-ish (ARC + nil-messaging) | Mixed (ARC for ObjC, manual/RAII for C++) | Manual (C) / RAII (C++) |
| **Concurrency** | First-class `async`/`await`, actors, `Sendable` | GCD / blocks | GCD + `std::thread`/`std::async` | pthreads / `std::thread` |
| **Interop** | C, ObjC (via headers); C++ improving | C, C++ (as ObjC++) | C, C++, ObjC — the bridge layer | The thing being bridged |
| **Tooling** | Best-in-class, evolving fast | Mature, stable | Mature | Universal |
| **Verbosity** | Concise | Verbose | Verbose | Low-level |
| **Hiring / future** | Apple's strategic direction | Legacy maintenance | Niche (engines) | Cross-platform cores |
| **When to pick** | Default for all new app code | Existing ObjC codebases | Reusing a portable C++ core on Apple platforms | Low-level/portable libraries |
| **Template** | `Swift-*` | `ObjectiveC-UIKit` | `ObjectiveCpp-Mixed` | `C-Library`, `CPlusPlus-Framework` |

**Takeaways**

- **Start in Swift** for anything new. Objective-C remains essential for
  maintaining and incrementally modernizing existing apps, and the two interop
  cleanly in the same target.
- **Objective-C++** is the bridge, not a destination: keep pure C++ in
  `.hpp/.cpp`, expose a **C++-free** Objective-C header, and do the mixing in
  `.mm`. That header stays importable from Swift. (See the
  `ObjectiveCpp-Mixed` template.)
- **C/C++** shines for portable, performance-critical cores you also ship on
  Android/Windows/Linux; wrap them for Apple platforms rather than rewriting.

## UI framework: SwiftUI vs UIKit vs AppKit

| Dimension | SwiftUI | UIKit | AppKit |
|---|---|---|---|
| **Paradigm** | Declarative, state-driven | Imperative, view/controller | Imperative, view/controller |
| **Platforms** | iOS/iPadOS/macOS/watchOS/tvOS/visionOS | iOS/iPadOS/tvOS | macOS |
| **Multiplatform reuse** | Excellent (one codebase) | Limited | macOS only |
| **Boilerplate** | Low | Higher | Higher |
| **Fine control** | Improving; some gaps | Total | Total |
| **Min deployment** | Best on iOS 17 / macOS 14+ (`@Observable`) | Back to very old OSes | Back to very old OSes |
| **Interop** | Wraps UIKit/AppKit via `*Representable` | Hosts SwiftUI via hosting controllers | Hosts SwiftUI via hosting controllers |
| **When to pick** | New apps; multiplatform; fast iteration | Complex custom UI, precise control, big UIKit codebases | Deep Mac-native features |
| **Template** | `Swift-SwiftUI`, `watchOS-SwiftUI`, `visionOS-RealityKit` | `Swift-UIKit`, `ObjectiveC-*` | `macOS-AppKit` |

**Takeaways**

- **SwiftUI is the default** for new apps, especially multiplatform ones. Its
  `@Observable` model (iOS 17 / macOS 14) gives clean, minimal view models.
- **UIKit/AppKit** still win when you need total control (custom layout/drawing,
  intricate gestures/transitions, document-based Mac apps) or must integrate
  with a large imperative codebase. You can always embed SwiftUI views inside
  them and vice versa, so the choice isn't all-or-nothing.

## State & architecture

All UI templates use **MVVM** (AppKit/UIKit) or **MVVM + a router**
(SwiftUI), with view models exposed through `@Observable`:

- **`@Observable`** (Observation framework, iOS 17 / macOS 14+) — the modern
  default used throughout. Less boilerplate than `ObservableObject`, and only
  the properties a view reads trigger its updates.
- **`ObservableObject` + `@Published`** — the fallback for deployment targets
  older than iOS 17 / macOS 14. Every template's view model header notes how to
  switch. The `ObjectiveC-UIKit` template uses plain MVC with delegation/blocks,
  since Observation is Swift-only.

## Quick decision flow

```
Need portable/low-level code?  ── yes ─▶ C-Library / CPlusPlus-Framework
        │ no
        ▼
Reusing a C++ core on iOS?     ── yes ─▶ ObjectiveCpp-Mixed (+ CPlusPlus-Framework)
        │ no
        ▼
Maintaining an ObjC app?       ── yes ─▶ ObjectiveC-UIKit
        │ no
        ▼
Custom GPU / spatial / watch?  ── yes ─▶ Metal / visionOS-RealityKit / watchOS-SwiftUI
        │ no
        ▼
Need imperative UIKit/AppKit?  ── yes ─▶ Swift-UIKit / macOS-AppKit
        │ no
        ▼
                                   ──────▶ Swift-SwiftUI  (the default)
```
