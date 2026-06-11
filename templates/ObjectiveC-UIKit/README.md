# ObjectiveC-UIKit Template

![CI](https://github.com/imattas/ipa-template/actions/workflows/build.yml/badge.svg)

A production-ready scaffolding for an **Objective-C + UIKit** iOS / iPadOS app,
built around the **Model–View–Controller (MVC)** pattern with a fully
programmatic UI (no storyboards).

## Overview

This template gives you a real, idiomatic starting point rather than a
hello-world: a scene-based app lifecycle, a navigation-driven Home screen with
a `UITableView`, pull-to-refresh, an async networking layer over
`NSURLSession`, a settings screen backed by `NSUserDefaults`, Auto Layout
helpers, and self-contained unit tests. Modern Objective-C throughout:
nullability annotations, lightweight generics, `NS_ENUM`, blocks, and ARC.

## Folder tree

```
ObjectiveC-UIKit/
├── App/
│   ├── main.m
│   ├── AppDelegate.{h,m}
│   ├── SceneDelegate.{h,m}
│   └── Info.plist
├── Features/
│   ├── Home/HomeViewController.{h,m}
│   └── Settings/SettingsViewController.{h,m}
├── Core/
│   ├── Models/Item.{h,m}
│   ├── Networking/APIClient.{h,m}
│   └── Extensions/UIView+Extensions.{h,m}
├── Resources/Assets.xcassets/
├── Tests/Unit/APIClientTests.m
└── docs/
    ├── ARCHITECTURE.md
    └── SETUP.md
```

## Pattern: MVC

- **Model** — `Item` (`Core/Models/`), a plain value object with JSON parsing.
- **View** — created programmatically inside each controller (`UITableView`,
  cells, switches), with Auto Layout via `UIView+Extensions`.
- **Controller** — `HomeViewController` and `SettingsViewController` mediate
  between the model and the views and own all UIKit state.

Networking is isolated in a singleton `APIClient` that returns results through
completion blocks dispatched back to the main queue. See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full data-flow diagram and
guidance on adding new features.

## Build & run

```bash
git clone https://github.com/imattas/ipa-template.git
cd ipa-template/templates/ObjectiveC-UIKit
```

This template ships without an `.xcodeproj` — generate or attach one and add
the `App/`, `Features/`, `Core/`, and `Resources/` folders, then build with
**⌘R**. Full instructions, including project settings and test commands, are in
[docs/SETUP.md](docs/SETUP.md).

```bash
# Run the unit tests
xcodebuild test \
  -scheme ObjectiveC-UIKit \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Requirements

- Xcode 16+
- iOS 15.0 deployment target
