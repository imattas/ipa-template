# ObjectiveC++ Mixed (Bridging) Template

![CI](https://github.com/imattas/ipa-template/actions/workflows/build.yml/badge.svg)

A production-ready scaffold demonstrating **clean mixed-language bridging** on
iOS: a pure **C++** core engine, an **Objective-C++** bridge wrapper, and an
**Objective-C / UIKit** app that consumes it.

## Overview

The goal of this template is to show the *right* way to mix C++ and
Objective-C in an iOS app:

- The compute core (`app::ComputeEngine`) is **pure C++17** — no Objective-C,
  no UIKit — so it stays portable and independently testable.
- A thin **bridge** (`EngineBridge`) exposes that engine to the rest of the app
  through a **pure Objective-C interface** (no C++ in the header), which keeps
  it importable from both Objective-C and Swift.
- The bridge's implementation (`.mm`) is the *only* translation unit where the
  two languages meet. It owns the C++ object via `std::unique_ptr` (the **Pimpl
  / facade** pattern) and forwards each ObjC method to C++.

## Folder tree

```
ObjectiveCpp-Mixed/
├── App/
│   ├── AppDelegate.{h,mm}
│   ├── SceneDelegate.{h,mm}
│   ├── main.m
│   └── Info.plist
├── Features/
│   └── Home/HomeViewController.{h,mm}
├── Core/
│   ├── Engine/                 # pure C++17
│   │   ├── ComputeEngine.hpp
│   │   └── ComputeEngine.cpp
│   ├── Bridge/                 # the language seam
│   │   ├── EngineBridge.h       # pure ObjC — Swift-importable
│   │   └── EngineBridge.mm      # ObjC++ wrapper over the C++ engine
│   └── Networking/APIClient.{h,mm}
├── Resources/Assets.xcassets/
├── Tests/Unit/EngineBridgeTests.mm
└── docs/{ARCHITECTURE,SETUP}.md
```

## The pattern: Pimpl bridge / facade

```
UIKit / Swift  →  EngineBridge.h (pure ObjC)  →  EngineBridge.mm (ObjC++)  →  ComputeEngine (pure C++)
```

- **Header stays C++-free.** `EngineBridge.h` only references `NSObject`,
  `double`, and `NSUInteger`. The C++ engine is hidden behind an opaque
  `std::unique_ptr` ivar declared inside the `.mm`.
- **`.mm` compilation.** Files needing C++ use `.mm` (Objective-C++ mode);
  Swift-facing headers stay `.h`.
- **Memory management.** ARC owns the ObjC objects; C++ RAII (`unique_ptr`)
  owns the engine and frees it automatically on dealloc.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for diagrams and the
step-by-step guide to exposing a new C++ API.

## Build & run

This template ships source only (no `.xcodeproj`). In short:

1. Create a new iOS App target in Xcode 16+ (Objective-C, iOS 15 deployment).
2. Add the `App/`, `Features/`, `Core/`, and `Resources/` folders.
3. Set **C++ Language Dialect = GNU++17** and **C++ Standard Library = libc++**.
4. Build & run (**⌘R**); run tests with **⌘U**.

Full instructions are in [`docs/SETUP.md`](docs/SETUP.md).

## Tests

`Tests/Unit/EngineBridgeTests.mm` contains XCTest cases that verify the bridge
forwards correctly to the C++ engine — mean, standard deviation, reset, and
min/max — including a direct comparison against a raw `app::ComputeEngine`.
