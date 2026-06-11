# Continuous Integration

CI lives in [`.github/workflows/build.yml`](../.github/workflows/build.yml) and
compiles every template on each push and pull request to `main`. The actual
per-template build commands live in
[`scripts/ci-build.sh`](../scripts/ci-build.sh) so CI and local reproduction
use the exact same logic.

## Pipeline shape

```
push / pull_request to main
          │
          ▼
   ┌─────────────────────────────────────────────────────────┐
   │  job: template   (strategy.matrix, fail-fast: false)     │
   │                                                          │
   │   Swift-UIKit  Swift-SwiftUI  ObjectiveC-UIKit  …  (×10) │  ← one runner each,
   │      │             │               │                     │    all in parallel,
   │      ▼             ▼               ▼                     │    independent
   │  ci-build.sh   ci-build.sh    ci-build.sh               │
   └─────────────────────────────────────────────────────────┘
          │
          ▼
   job: all-templates   (needs: template)  ← single required status check
```

- **One job per template.** A `strategy.matrix` over the ten template names
  spawns ten jobs that run **in parallel** on separate `macos-latest` runners.
- **Failure isolation.** `fail-fast: false` means one template failing does
  **not** cancel the others — every template is always exercised.
- **Single gate.** The `all-templates` job depends on the matrix and fails if
  any template failed, so branch protection can require just one check.
- **Logs on failure.** Each job tees its output to
  `build-logs/<Template>.log` and uploads it as an artifact **only when the
  build fails** (`if: failure()`), so you can download the exact error.
- **Concurrency control.** Superseded runs on the same ref are cancelled to
  save runner minutes.

## Each job

1. **Checkout** — `actions/checkout@v4`.
2. **Select Xcode** — `sudo xcode-select -switch …` to pin the runner's stable
   Xcode so the iOS/macOS/watchOS/visionOS SDKs and the Metal toolchain are
   available; prints `xcodebuild -version` and `-showsdks`.
3. **Build** — `bash scripts/ci-build.sh <Template>`.
4. **Upload log** — on failure only.

## How each toolchain is compiled

These templates are **source scaffolding** — they intentionally ship without a
committed `.xcodeproj`, so CI verifies them at the strongest level achievable
without a project file. `scripts/ci-build.sh` picks the right toolchain per
template:

| Template | Toolchain | What CI does |
|---|---|---|
| Swift-UIKit | `swiftc` | `-typecheck` app sources vs the **iphonesimulator** SDK (resolves UIKit); `-parse` the `Tests/` sources |
| Swift-SwiftUI | `swiftc` | `-typecheck` vs the **macOS** SDK (SwiftUI present); `-parse` tests |
| macOS-AppKit | `swiftc` | `-typecheck` vs the **macOS** SDK (AppKit); `-parse` tests |
| watchOS-SwiftUI | `swiftc` | `-typecheck` vs the **watchsimulator** SDK; `-parse` tests |
| visionOS-RealityKit | `swiftc` | `-typecheck` vs the **xrsimulator** SDK; `-parse` tests |
| Metal | `swiftc` + `metal` | typecheck the Swift, then **real** `xcrun -sdk iphoneos metal -c` compile of every `.metal` shader to AIR |
| ObjectiveC-UIKit | `clang` | `-fsyntax-only` over every `.m` translation unit vs the iOS SDK |
| ObjectiveCpp-Mixed | `clang++` | **real** `-c` compile of the pure C++ engine, then `-fsyntax-only` over every `.mm` |
| C-Library | `make` / `cc` | **real** build **and** `make test` (runs the unit tests) |
| CPlusPlus-Framework | `make` / `c++` | **real** build **and** `make test` (also buildable via CMake/`ctest`) |

### Why type-check / syntax-only for the app UI templates?

Building a full `.app` bundle requires an Xcode project (targets, signing,
Info.plist processing, asset compilation). Rather than commit a brittle
generated `.xcodeproj` per template, CI compiles the sources directly:

- **`swiftc -typecheck`** fully parses **and type-checks** the app sources
  against the real platform SDK. It catches genuine errors — unknown APIs, type
  mismatches, bad `async`/`@MainActor` usage — without needing to link or sign.
- **`Tests/` sources are `-parse`-only** because they `@testable import` the app
  module, which isn't built in this no-project setup. Parsing still guarantees
  they are syntactically valid Swift.
- The **C, C++, and Metal** paths go further and do real compilation; the C/C++
  templates additionally **run their unit tests**.

If an SDK is missing on a given runner image, `ci-build.sh` falls back to a
syntax-only `swiftc -parse` and emits a `::warning::` rather than failing — so
the pipeline degrades gracefully instead of breaking on runner changes.

## Run a template's CI build locally (on a Mac)

```sh
bash scripts/ci-build.sh Swift-SwiftUI
bash scripts/ci-build.sh C-Library
```

On any machine (including Linux), the C and C++ templates build and test with
their `Makefile`s directly:

```sh
make -C templates/C-Library test
make -C templates/CPlusPlus-Framework test
```

## Adding a template to CI

1. Add a build recipe to the `case` in `scripts/ci-build.sh`.
2. Add the template name to the `matrix.template` list in `build.yml`.

That's it — the new template gets its own parallel, isolated job and log.

## Status badges

Because all templates are built by this single matrix workflow, the README
badges share one workflow status (GitHub renders one badge per *workflow*, not
per matrix job). Drill into the Actions tab to see the pass/fail of each
individual template job, or download its log artifact on failure.
