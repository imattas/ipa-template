# Build Your Own App — A Hands-On Course

Welcome! This course teaches you to build a real, production-quality Apple
platform app **on top of the templates in this repository** — not toy demos.
Every module is grounded in the actual code under [`../../templates/`](../../templates/):
the same `APIClient`, `AppRouter`, `@Observable` view models, and tests you'll
ship with.

By the end you'll have taken an app from `git clone` all the way to TestFlight,
and you'll understand *why* the scaffolding is shaped the way it is — so you can
extend it confidently.

## Who this is for

You're comfortable programming and know a little Swift, but you're new to this
repo (or to building Apple apps the "real" way: architecture, networking,
testing, shipping). No prior SwiftUI experience required — we build it up.

## What you'll need

- A Mac running **Xcode 16+**.
- Deployment targets: iOS 17 / macOS 14+ for the `@Observable` path (each module
  notes the pre-iOS-17 fallback where relevant).
- About 20–40 minutes per module. Do them in order the first time through.

The default template for the course is **`Swift-SwiftUI`** (universal
iOS/iPadOS/macOS). Module 12 branches out to every other platform. If you're
unsure which template fits your real project, read
[`../TEMPLATES.md`](../TEMPLATES.md) and [`../COMPARISON.md`](../COMPARISON.md)
first.

## Syllabus

### Part 1 — Foundations
| # | Module | You'll learn |
|---|---|---|
| 01 | [Getting Started](01-getting-started.md) | Clone the repo, pick a template, wire it into Xcode, run it. |
| 02 | [Anatomy of a Template](02-anatomy-of-a-template.md) | The `App / Features / Core / Resources / Tests` layout and why it exists. |
| 03 | [Building Your First Feature](03-your-first-feature.md) | Add a new screen end to end (View + ViewModel + route). |

### Part 2 — The core systems
| # | Module | You'll learn |
|---|---|---|
| 04 | [The Networking Layer](04-the-networking-layer.md) | Replace the stubs with a real REST API: endpoints, decoding, errors. |
| 05 | [State & Data Flow](05-state-and-data-flow.md) | `@Observable` in depth, `@MainActor`, the loading/error pattern, fallbacks. |
| 06 | [Navigation & Routing](06-navigation-and-routing.md) | The `AppRouter`, typed routes, passing data, deep links. |
| 07 | [Persistence & Storage](07-persistence-and-storage.md) | `@AppStorage` → Keychain → SwiftData; choosing the right tool. |
| 08 | [Dependency Injection & Architecture](08-dependency-injection-and-architecture.md) | Protocol-based DI, composition root, scaling the structure. |

### Part 3 — Quality
| # | Module | You'll learn |
|---|---|---|
| 09 | [Testing Your App](09-testing-your-app.md) | Unit-test async view models, mock the API, XCUITest, Swift Testing. |
| 10 | [Concurrency with Swift 6](10-concurrency-swift6.md) | async/await, actors, `Sendable`, cancellation, fixing strict-concurrency errors. |
| 11 | [Design System & Accessibility](11-design-system-and-accessibility.md) | Theming, dark mode, Dynamic Type, VoiceOver, reusable modifiers. |

### Part 4 — Going wide and going live
| # | Module | You'll learn |
|---|---|---|
| 12 | [Platform Deep Dives](12-platform-deep-dives.md) | UIKit, AppKit, watchOS, visionOS, Metal, Objective-C(++), and C/C++ cores. |
| 13 | [Shipping to the App Store](13-shipping-to-the-app-store.md) | Signing, archiving, TestFlight, App Review, the release checklist. |
| 14 | [CI/CD with GitHub Actions](14-cicd-github-actions.md) | Extend this repo's pipeline: run tests, lint, coverage, deploy. |
| 15 | [Capstone: Build a Complete App](15-capstone-project.md) | Put it all together — a full multi-screen app, start to finish. |

## How to use this course

- **Linear the first time.** Each module builds on the last and links forward
  with a **Next** pointer. Later modules assume the earlier ones.
- **Reference afterward.** Once you've done the run-through, treat the modules as
  a reference — jump straight to *Navigation* or *Shipping* when you need it.
- **Type the code.** Every module names the exact file to open or create in the
  template and shows real Swift 6 code. Building it yourself is the point.
- **Do the exercises.** Each module ends with a *Try it yourself* section — the
  fastest way to make the patterns stick.

Ready? Start with **[Module 01 — Getting Started](01-getting-started.md)**.
