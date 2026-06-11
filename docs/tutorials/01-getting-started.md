# Module 01 — Getting Started

Welcome! This course teaches you to build real, shippable apps on top of the
production-ready skeletons in the [`ipa-template`](https://github.com/imattas/ipa-template)
repository. Rather than starting from a blank Xcode project, you'll begin from a
template that already wires up navigation, networking, dependency injection, and
tests the "right" way — then spend the rest of the course extending it into your
own app. This first module gets your machine set up, helps you pick a template,
and gets something running on the simulator.

**What you'll learn**

- What the `ipa-template` repo is and how the ten templates relate to each other
- The tools and OS versions you need before you start
- How to clone the repo and copy a template out into your own project
- How to choose a template (and why **Swift-SwiftUI** is the default)
- The deliberate "no `.xcodeproj`" design, and the two supported ways to wire a
  template into a buildable project
- How to set your bundle identifier and deployment target, then run on the
  simulator
- How the C and C++ templates run from the terminal via `make test` instead

**Prerequisites**

None — this is the first module. Just a Mac and a willingness to use the
terminal a little.

---

## 1. What this repo is

`ipa-template` ships **ten** self-contained templates under `templates/<Name>/`.
Each one is a clean, opinionated starting point for a specific kind of Apple (or
cross-platform) project:

| Template | Language | Platform(s) |
|---|---|---|
| **Swift-SwiftUI** | Swift | iOS / iPadOS / macOS |
| **Swift-UIKit** | Swift | iOS / iPadOS |
| **ObjectiveC-UIKit** | Objective-C | iOS / iPadOS |
| **ObjectiveCpp-Mixed** | Objective-C++ / C++ | iOS |
| **Metal** | Swift + Metal | iOS |
| **visionOS-RealityKit** | Swift + RealityKit | visionOS |
| **watchOS-SwiftUI** | Swift + WatchKit | watchOS |
| **macOS-AppKit** | Swift + AppKit | macOS |
| **C-Library** | C (C11) | cross-platform |
| **CPlusPlus-Framework** | C++ (C++17) | cross-platform |

All ten build green in CI. Every UI template follows the same spine
(`App/`, `Features/`, `Core/`, `Resources/`, `Tests/`), so once you learn one you
can move between them easily. The C and C++ templates use the classic
`include/` · `src/` · `tests/` · `docs/` library layout instead.

For the full descriptions, see [`../TEMPLATES.md`](../TEMPLATES.md). For a
head-to-head on the language / UI-framework tradeoffs, see
[`../COMPARISON.md`](../COMPARISON.md).

## 2. How this course works

Each module is a self-contained, hands-on chapter. You'll open real files from a
template, read what's there, and extend it. The examples throughout the course
are grounded in the **Swift-SwiftUI** template, so that's the one to set up now.
Later modules build directly on the project you create here, so don't throw it
away between sessions.

## 3. Prerequisites: tools and OS versions

You'll need:

- **macOS** recent enough to run the latest Xcode.
- **Xcode 16 or later** — this gives you the **Swift 6** toolchain, which every
  template targets (Swift 6 language mode, strict concurrency, actors).
- **Deployment targets** for the Swift-SwiftUI template: **iOS 17 / iPadOS 17 /
  macOS 14** or later. These are required by the **Observation framework**
  (`@Observable`) and SwiftUI APIs the template uses such as
  `ContentUnavailableView` and `navigationDestination`.
  - If you must support an older OS, the template's view models and `AppRouter`
    include inline notes showing how to fall back to `ObservableObject` +
    `@Published` observed via `@StateObject` / `@ObservedObject`.
- An **Apple Developer account** is only needed to run on a *physical* device.
  The simulator needs none.

> The C and C++ templates only need a C/C++ toolchain and `make` — Xcode's
> command-line tools are enough.

## 4. Clone the repository

Open Terminal and clone the repo:

```bash
git clone https://github.com/imattas/ipa-template.git
cd ipa-template
```

Take a moment to look around:

```bash
ls templates
# C-Library  CPlusPlus-Framework  Metal  ObjectiveC-UIKit
# ObjectiveCpp-Mixed  Swift-SwiftUI  Swift-UIKit
# macOS-AppKit  visionOS-RealityKit  watchOS-SwiftUI
```

## 5. Choose a template

For greenfield Apple work — one platform or several — reach for
**Swift-SwiftUI**. It's the default for this course because it's modern, runs on
iOS / iPadOS / macOS from a single codebase, and demonstrates every pattern the
course teaches (MVVM, a router, protocol-oriented networking, DI, typed errors).

Pick a different template only when you have a specific reason:

- iOS only and you need imperative UIKit power → **Swift-UIKit**
- Maintaining an Objective-C app → **ObjectiveC-UIKit**
- Reusing a C++ engine on iOS → **ObjectiveCpp-Mixed** + **CPlusPlus-Framework**
- Custom GPU rendering → **Metal**; Vision Pro → **visionOS-RealityKit**;
  Apple Watch → **watchOS-SwiftUI**; classic Mac → **macOS-AppKit**

See [`../TEMPLATES.md`](../TEMPLATES.md) and
[`../COMPARISON.md`](../COMPARISON.md) for the full decision guide. The rest of
this course assumes **Swift-SwiftUI**.

## 6. Copy the template out

Templates live *inside* the repo as references. To start your own app, copy one
out so you can edit it freely without touching the repo:

```bash
cp -R templates/Swift-SwiftUI ~/Developer/MyApp
cd ~/Developer/MyApp
```

You now own a private copy under `~/Developer/MyApp`. Everything from here on
happens in that copy.

## 7. The "no `.xcodeproj`" design

Open your copy and notice what's *missing*:

```bash
ls
# App  Core  Features  README.md  Resources  Tests  docs
```

There is **no `.xcodeproj` and no `.xcworkspace`**, on purpose. Project files are
huge, machine-generated, and a constant source of merge conflicts; they also tie
the template to one exact Xcode layout. Instead, the template ships only **source
files in a clean folder structure**, and you generate the project around them.
There are two supported ways to do that.

### Option A — A new Xcode App target (recommended to start)

1. In Xcode: **File ▸ New ▸ Project ▸ Multiplatform ▸ App**. Name it `MyApp`.
2. Save it *inside* `~/Developer/MyApp` (so the generated `.xcodeproj` sits next
   to the existing folders).
3. Delete the placeholder `ContentView.swift` and `MyAppApp.swift` that Xcode
   created — the template provides its own `@main` entry point in
   `App/AppEntry.swift`.
4. In Finder, drag the `App/`, `Features/`, `Core/`, and `Resources/` folders
   into the Xcode Project navigator. In the dialog, choose **"Create groups"**
   and check your app target under **"Add to targets"**.
5. Drag `Tests/Unit` into a **Unit Testing Bundle** target and `Tests/UI` into a
   **UI Testing Bundle** target (create these via **File ▸ New ▸ Target** if the
   project wizard didn't).

This is the fastest path and what the rest of the course assumes.

### Option B — A Swift Package

If you prefer a package-driven setup (or plan to generate the project with
**XcodeGen** or **Tuist**), describe the same `App/`, `Features/`, `Core/`,
`Resources/` folders as targets in a `Package.swift` (or a generator manifest)
and point the tool at those directories. The folder layout is identical either
way; only the project description differs.

> The template's own [`docs/SETUP.md`](../../templates/Swift-SwiftUI/docs/SETUP.md)
> covers both options in more detail.

## 8. Set the bundle identifier and deployment target

With the source added to a target:

1. Select the project in the navigator, then your app target → **General**.
2. Set the **Bundle Identifier**. The template ships
   `com.example.swiftswiftui` in `App/Info.plist`; change it to your own reverse-DNS
   id, e.g. `net.mattas.MyApp`.
3. Point **Build Settings ▸ Info.plist File** at `App/Info.plist`.
4. Set the **Minimum Deployments** to **iOS 17** (and **macOS 14** if you build
   the Mac destination).
5. Add `Resources/Assets.xcassets` to the app target, then set the **App Icon**
   and **Accent Color** to the bundled asset sets.

## 9. Run on the simulator

1. In the scheme/destination picker at the top of Xcode, choose a simulator such
   as **iPhone 16**.
2. Press **Run** (**⌘R**).

You should see a **Home** screen with a list of items ("Welcome",
"Networking", "Navigation"), a gear button in the toolbar that pushes a Settings
screen, and pull-to-refresh. That list is served by `MockAPIClient`'s sample data
through the template's networking layer — proof the whole stack is wired up.

Run the tests too, with **Product ▸ Test** (**⌘U**), to confirm the test targets
are connected.

## 10. The C / C++ templates run differently

The **C-Library** and **CPlusPlus-Framework** templates are *not* Xcode apps —
they're `make`-based library projects. You don't run them on a simulator; you
build and test them from the terminal:

```bash
cp -R templates/C-Library ~/Developer/MyLib
cd ~/Developer/MyLib
make test
```

The `test` target in the `Makefile` compiles the sources from `src/` against the
headers in `include/` and runs everything under `tests/`. **CPlusPlus-Framework**
works the same way (`make test`) and additionally ships a `CMakeLists.txt` for
CMake-based builds. We'll explore those layouts in a later module; for the SwiftUI
track, stick with the Xcode flow from steps 6–9.

---

## Try it yourself

1. Run the app on **two** different destinations (an iPhone simulator and, if you
   added the macOS destination, "My Mac"). Notice the same code produces a native
   UI on each.
2. Change the **Bundle Display Name** in `App/Info.plist` from `Swift-SwiftUI` to
   your app's name and re-run. Watch the app's name update under its icon.
3. Copy a *second* template (e.g. `cp -R templates/C-Library ~/Developer/MyLib`)
   and run `make test` in it. Compare how a library project differs from an app
   project.
4. Open [`../COMPARISON.md`](../COMPARISON.md) and write down, in one sentence,
   why Swift-SwiftUI is the right call for your own next app — or why it isn't.

## Recap

You learned what `ipa-template` is, set up Xcode 16+ with the iOS 17 / macOS 14
toolchain, cloned the repo, and copied **Swift-SwiftUI** out to
`~/Developer/MyApp`. You saw the deliberate no-`.xcodeproj` design and wired the
`App/`, `Features/`, `Core/`, `Resources/`, and `Tests/` folders into a fresh
Xcode App target (or a Swift Package), set your bundle id and deployment target,
and ran the template on the simulator. You also saw that the C/C++ templates run
from the terminal via `make test`. Next, we'll dissect *what's inside* a template
and why each folder exists.

**Next:** [Module 02 — Anatomy of a Template](02-anatomy-of-a-template.md)
