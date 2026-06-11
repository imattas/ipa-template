# Architecture

This template demonstrates **clean mixed-language bridging** between a pure C++
core engine and an Objective-C/UIKit iOS app, with an Objective-C++ bridge in
between.

## Folder structure

```
ObjectiveCpp-Mixed/
├── App/                     App lifecycle (UIKit entry points)
│   ├── AppDelegate.{h,mm}
│   ├── SceneDelegate.{h,mm}
│   ├── main.m
│   └── Info.plist
├── Features/
│   └── Home/                Screens consuming the bridge
│       └── HomeViewController.{h,mm}
├── Core/
│   ├── Engine/              Pure C++ — no Objective-C, no UIKit
│   │   ├── ComputeEngine.hpp
│   │   └── ComputeEngine.cpp
│   ├── Bridge/              The language seam
│   │   ├── EngineBridge.h   ← pure Objective-C (NO C++) -- Swift-importable
│   │   └── EngineBridge.mm  ← Objective-C++ implementation
│   └── Networking/
│       ├── APIClient.h
│       └── APIClient.mm
├── Resources/
│   └── Assets.xcassets/
├── Tests/
│   └── Unit/EngineBridgeTests.mm
└── docs/
```

### Rationale

- **`Core/Engine` is platform-agnostic C++.** Keeping it free of Objective-C
  means it compiles and unit-tests on any C++17 toolchain and could be reused
  in an Android NDK or desktop build.
- **`Core/Bridge` is the only place the two languages meet.** Everything ObjC
  outside the bridge stays blissfully unaware that C++ exists.
- **`Features` and `App`** are ordinary UIKit code that talk only to the
  C++-free bridge header.

## The three layers

```
┌──────────────────────────────────────────────────────────────┐
│  Swift / Objective-C UI  (HomeViewController, AppDelegate)     │
│  imports only EngineBridge.h                                   │
└───────────────────────────────┬──────────────────────────────┘
                                 │  pure Objective-C messages
                                 ▼
┌──────────────────────────────────────────────────────────────┐
│  EngineBridge.h   ← PURE Objective-C interface (NO C++)        │
│  @interface EngineBridge : NSObject                            │
│    -(void)addSample:(double)x;                                 │
│    -(double)mean; -(double)standardDeviation; -(void)reset;    │
└───────────────────────────────┬──────────────────────────────┘
                                 │  implemented by
                                 ▼
┌──────────────────────────────────────────────────────────────┐
│  EngineBridge.mm  ← Objective-C++ (compiled as .mm)           │
│    std::unique_ptr<app::ComputeEngine> _engine;  (Pimpl ivar)  │
│    forwards each ObjC method to the C++ object                 │
└───────────────────────────────┬──────────────────────────────┘
                                 │  ordinary C++ calls
                                 ▼
┌──────────────────────────────────────────────────────────────┐
│  ComputeEngine  ← PURE C++  (namespace app)                    │
│    std::vector<double> samples_;  mean(), standardDeviation()  │
└──────────────────────────────────────────────────────────────┘
```

## The bridging pattern

### Pimpl / opaque pointer
`EngineBridge` holds its C++ collaborator through a
`std::unique_ptr<app::ComputeEngine>` **instance variable declared inside the
`@implementation` block in the `.mm` file**. The header never names a C++ type.
This is the "pointer to implementation" (Pimpl) idiom adapted to ObjC++: the
concrete C++ type is an implementation detail of one translation unit.

### Why headers stay C++-free
When Swift imports an Objective-C module (via the bridging header or a module
map), the Clang importer parses the `.h` files. If a header contains C++ types
(`std::unique_ptr`, `namespace app`, templates) the import fails — Swift cannot
read C++ declarations through the ObjC importer. By keeping `EngineBridge.h`
limited to `NSObject`, `double`, and `NSUInteger`, the bridge is consumable from
both Objective-C **and** Swift with zero extra ceremony.

### `.mm` compilation
A file with the `.mm` extension is compiled by Clang in **Objective-C++** mode:
both ObjC message sends and C++ (STL, templates, RAII) are legal in the same
file. Files that need C++ (`EngineBridge.mm`, the tests, optionally
`HomeViewController.mm`) use `.mm`. Files that must remain reachable from Swift
or pure-ObjC compilation units (`EngineBridge.h`) use `.h` and stay C++-free.

### Memory management across the boundary
- Objective-C objects (`EngineBridge`, `APIClient`) are managed by **ARC**.
- The C++ object is managed by **RAII**: the `unique_ptr` ivar is constructed in
  `-init` and destroyed automatically when the `EngineBridge` deallocates. No
  manual `delete`, no `-dealloc` boilerplate required.

## Where to add a new feature / expose a new C++ API

To surface a new C++ capability to the UI:

1. **Add the C++ method** to `Core/Engine/ComputeEngine.hpp` / `.cpp`
   (e.g. `double median() const;`). Keep it pure C++.
2. **Declare a matching ObjC method** in `Core/Bridge/EngineBridge.h` using only
   ObjC/C scalar types (e.g. `- (double)median;`). Do **not** mention any C++.
3. **Forward it** in `Core/Bridge/EngineBridge.mm`:
   `- (double)median { return _engine->median(); }`.
4. **Consume it** from `Features/.../*.mm` (or Swift) via the bridge.
5. **Add a test** in `Tests/Unit/EngineBridgeTests.mm` that compares the bridge
   result against the raw C++ engine.

To add a whole new screen, create a `Features/<Name>/` folder with a
`UIViewController` subclass and wire it up in `SceneDelegate.mm`.
