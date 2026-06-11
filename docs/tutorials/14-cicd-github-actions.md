# Module 14 — CI/CD: Extending the Pipeline

The `ipa-template` repo already ships a working continuous-integration pipeline:
every push and pull request to `main` compiles all ten templates in parallel, in
isolation, with downloadable logs on failure and a single required status check.
In this module you'll first understand that pipeline *in depth* — the real
[`.github/workflows/build.yml`](../../.github/workflows/build.yml) and the
[`scripts/ci-build.sh`](../../scripts/ci-build.sh) dispatcher it calls — and then
extend it for a real app: running the actual XCTest suite, caching, lint and
format gates, code coverage, building an archive, and uploading to TestFlight,
all gated behind branch protection.

**What you'll learn**

- How the existing matrix workflow runs one isolated job per template, why
  `fail-fast: false` matters, and what the `all-templates` gate buys you
- How `ci-build.sh` dispatches the right toolchain per template and uploads logs
- How to run a true XCTest suite in CI once you have an `.xcodeproj`/`.xcworkspace`
- How to cache to speed up runs, and add SwiftLint / swift-format checks
- How to collect and surface code coverage
- How to build an archive and upload to TestFlight with fastlane *or*
  `xcodebuild` + an App Store Connect API key, with secrets in GitHub Secrets
- How to require the `all-templates` (and your new) checks via branch protection
- How to add a new template to the matrix and the dispatcher

**Prerequisites**

- [Module 13 — Shipping to the App Store](13-shipping-to-the-app-store.md). You
  should have an App Store Connect record, a bundle identifier, and signing set
  up; this module automates the build and upload you did by hand there.

---

## 1. The existing pipeline, end to end

The whole pipeline is two jobs. Here is the real workflow,
`.github/workflows/build.yml`, annotated:

```yaml
name: build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:           # lets you run it by hand from the Actions tab

# Cancel superseded runs on the same ref to save runner minutes.
concurrency:
  group: build-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read               # least privilege — CI only reads the repo

jobs:
  template:
    name: ${{ matrix.template }}
    runs-on: macos-latest
    strategy:
      fail-fast: false         # one template failing does NOT cancel the rest
      matrix:
        template:
          - Swift-UIKit
          - Swift-SwiftUI
          - ObjectiveC-UIKit
          - ObjectiveCpp-Mixed
          - Metal
          - visionOS-RealityKit
          - watchOS-SwiftUI
          - macOS-AppKit
          - C-Library
          - CPlusPlus-Framework
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: |
          sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer
          xcodebuild -version
          echo "SDKs:"; xcodebuild -showsdks 2>/dev/null || true
      - name: Build ${{ matrix.template }}
        id: build
        run: |
          set -o pipefail
          mkdir -p build-logs
          bash scripts/ci-build.sh "${{ matrix.template }}" \
            2>&1 | tee "build-logs/${{ matrix.template }}.log"
      - name: Upload build log on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: build-log-${{ matrix.template }}
          path: build-logs/${{ matrix.template }}.log
          retention-days: 14

  all-templates:
    name: all-templates
    runs-on: ubuntu-latest
    needs: template
    if: always()
    steps:
      - name: Verify every template job succeeded
        run: |
          if [[ "${{ needs.template.result }}" != "success" ]]; then
            echo "::error::One or more template builds failed."
            exit 1
          fi
          echo "All template builds passed."
```

The shape, also documented in [`docs/CI.md`](../CI.md):

- **One job per template (matrix).** `strategy.matrix.template` over the ten
  names fans out into ten jobs, each on its own `macos-latest` runner, all in
  parallel. You get fast, independent feedback per language/platform.
- **Failure isolation (`fail-fast: false`).** GitHub's default would cancel the
  whole matrix the moment one cell fails. Setting it to `false` means a broken
  Metal shader doesn't hide a broken Swift typecheck — *every* template is always
  exercised, and each one reports its own status.
- **Logs on failure only (`if: failure()`).** Each job tees its output to
  `build-logs/<Template>.log` and uploads that as an artifact only when the build
  fails, so a red job gives you the exact error to download (kept 14 days) without
  bloating green runs.
- **The `all-templates` gate.** A tiny `ubuntu-latest` job that `needs:
  template`, runs `if: always()`, and fails unless
  `needs.template.result == 'success'`. This collapses ten checks into **one**
  required status check — branch protection requires `all-templates` and
  transitively requires all ten.
- **Concurrency control.** `cancel-in-progress: true` cancels superseded runs on
  the same ref so a flurry of pushes doesn't burn runner minutes.

---

## 2. The `ci-build.sh` dispatcher

The workflow deliberately contains *no* build logic. Every job runs the same
line — `bash scripts/ci-build.sh <Template>` — and the script is the single
source of truth for *how each template is compiled*. That means CI and a
developer reproducing a failure on their Mac run the identical commands.

Why a script of typecheck/syntax steps rather than `xcodebuild`? The templates
are **source scaffolding** — they intentionally ship without a committed
`.xcodeproj`. So CI verifies them at the strongest level achievable *without* a
project file. The `case "$TEMPLATE"` dispatches per language:

| Template(s) | Toolchain | What CI actually does |
|---|---|---|
| `Swift-UIKit`, `Swift-SwiftUI`, `macOS-AppKit`, `watchOS-SwiftUI`, `visionOS-RealityKit` | `swiftc` | `swiftc -typecheck -swift-version 6` of app sources against the platform SDK (resolves UIKit/SwiftUI/AppKit symbols); `swiftc -parse` of `Tests/` sources |
| `ObjectiveC-UIKit` | `clang` | `clang -fsyntax-only` per `.m` against the iphonesimulator SDK |
| `ObjectiveCpp-Mixed` | `clang++` | real `clang++ -std=c++17 -c` of the pure C++ engine, plus `clang++ -fsyntax-only -std=gnu++17` of the `.mm` files |
| `Metal` | `swiftc` + `xcrun metal` | Swift typecheck with the `ShaderTypes.h` bridging header, plus a real `xcrun metal -c` shader compile to AIR |
| `C-Library`, `CPlusPlus-Framework` | `make` | a real `make clean && make test` — these actually build *and run tests* |

Two robustness details worth copying into your own scripts:

- **SDK fallback.** `swift_check` calls `sdk_path` first; if the SDK isn't on the
  runner it downgrades from `-typecheck` to a syntax-only `-parse` and emits a
  `::warning::` rather than failing — the code is still validated.
- **Tests are softer than app sources.** Swift `Tests/` are `-parse`d (they
  `@testable import` a module that isn't built here), and ObjC test translation
  units that fail `-fsyntax-only` emit a `::warning::` instead of failing the
  job, because `XCTest` and the app module aren't available in project-less CI.
  The **app sources remain the hard gate.**

This is the foundation we'll build on. For a *real app* you eventually add an
Xcode project, and then you can do the things project-less CI can't: run the real
test suite, measure coverage, and ship a build.

---

## 3. Run the real XCTest suite

Once your app has an `.xcodeproj` (or `.xcworkspace`), replace
typecheck-only verification with a true build-and-test. Add a new workflow,
`.github/workflows/app.yml`, dedicated to your app (keep `build.yml` for the
template matrix):

```yaml
name: app

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: app-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    name: Build & Test
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer

      - name: Build and test
        run: |
          set -o pipefail
          xcodebuild test \
            -scheme MyApp \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -resultBundlePath TestResults.xcresult \
            CODE_SIGNING_ALLOWED=NO \
            | xcbeautify

      - name: Upload result bundle
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: TestResults.xcresult
```

Notes:

- Use `-workspace MyApp.xcworkspace -scheme MyApp` instead of `-scheme` alone if
  you use CocoaPods or SPM-via-workspace.
- `CODE_SIGNING_ALLOWED=NO` lets the simulator build skip signing — you only need
  signing for the *archive/upload* step (§7).
- `xcbeautify` (or `xcpretty`) turns xcodebuild's firehose into readable output;
  install it in a prior step with `brew install xcbeautify`.
- Pin the simulator to a name that exists on the runner image. If `iPhone 15`
  isn't available, list devices with `xcrun simctl list devices` or use a
  generic destination like `'platform=iOS Simulator,OS=latest,name=iPhone 15'`.

---

## 4. Caching

MacOS runner minutes are expensive — cache anything deterministic. The big wins
are Swift Package Manager dependencies and (if used) Homebrew.

```yaml
      - name: Cache SPM
        uses: actions/cache@v4
        with:
          path: |
            ~/Library/Caches/org.swift.swiftpm
            ~/Library/Developer/Xcode/DerivedData/**/SourcePackages
          key: spm-${{ runner.os }}-${{ hashFiles('**/Package.resolved') }}
          restore-keys: spm-${{ runner.os }}-
```

Key the cache on a lockfile hash (`Package.resolved`, or `Podfile.lock` for
CocoaPods) so it invalidates only when dependencies change. Avoid caching
`DerivedData` build products wholesale — it's brittle and often slower than a
clean build.

---

## 5. SwiftLint and format checks

Add a fast Linux job (no Xcode needed) that gates style. It runs in parallel with
the test job, so it doesn't slow feedback:

```yaml
  lint:
    name: Lint & Format
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install tools
        run: brew install swiftlint swift-format

      - name: SwiftLint
        run: swiftlint lint --strict   # warnings become errors

      - name: Format check
        run: swift-format lint --recursive --strict .
```

Commit a `.swiftlint.yml` at the repo root so local and CI runs agree. Use
`--strict` so a warning fails the build; otherwise style debt accumulates
silently. For auto-formatting, developers run `swift-format format -i -r .`
locally — CI only *checks*, it never rewrites.

---

## 6. Code coverage

Ask `xcodebuild` to gather coverage, then extract a number. Add to the test step:

```yaml
      - name: Build and test (with coverage)
        run: |
          set -o pipefail
          xcodebuild test \
            -scheme MyApp \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -enableCodeCoverage YES \
            -resultBundlePath TestResults.xcresult \
            CODE_SIGNING_ALLOWED=NO | xcbeautify

      - name: Report coverage
        run: |
          xcrun xccov view --report --only-targets TestResults.xcresult
```

For a PR badge or a threshold gate, feed the `.xcresult` to a service like
Codecov (`codecov/codecov-action@v4`, token in `secrets.CODECOV_TOKEN`) or parse
`xccov view --report --json` and fail the job below a minimum line-coverage
percentage. Keep the threshold realistic and ratchet it up over time.

---

## 7. Build an archive and upload to TestFlight

This runs on `main` (or on tags) after tests pass. It needs real signing, so all
credentials come from **GitHub Secrets** (Settings → Secrets and variables →
Actions), never the repo. There are two common approaches.

### Option A — fastlane

[`fastlane`](https://fastlane.tools) wraps signing, build, and upload. A
`fastlane/Fastfile` lane:

```ruby
lane :beta do
  setup_ci                       # creates a temporary keychain on CI
  api_key = app_store_connect_api_key(
    key_id: ENV["ASC_KEY_ID"],
    issuer_id: ENV["ASC_ISSUER_ID"],
    key_content: ENV["ASC_KEY_P8"]   # the .p8 contents, base64 or raw
  )
  match(type: "appstore", readonly: true)   # fetches signing assets
  build_app(scheme: "MyApp")
  upload_to_testflight(api_key: api_key, skip_waiting_for_build_processing: true)
end
```

The workflow job:

```yaml
  release:
    name: TestFlight
    runs-on: macos-latest
    needs: [test, lint]
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - run: sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer
      - name: Upload to TestFlight
        env:
          ASC_KEY_ID:    ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          ASC_KEY_P8:    ${{ secrets.ASC_KEY_P8 }}
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
        run: bundle exec fastlane beta
```

### Option B — `xcodebuild` + App Store Connect API key

Without fastlane, archive, export, and upload directly. Store the API key `.p8`,
its key ID, and issuer ID as secrets:

```yaml
      - name: Archive
        run: |
          xcodebuild archive \
            -scheme MyApp \
            -destination 'generic/platform=iOS' \
            -archivePath build/MyApp.xcarchive | xcbeautify

      - name: Export IPA
        run: |
          xcodebuild -exportArchive \
            -archivePath build/MyApp.xcarchive \
            -exportOptionsPlist ExportOptions.plist \
            -exportPath build | xcbeautify

      - name: Upload to TestFlight
        env:
          ASC_KEY_ID:    ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          ASC_KEY_P8:    ${{ secrets.ASC_KEY_P8 }}
        run: |
          mkdir -p ~/private_keys
          echo "$ASC_KEY_P8" > ~/private_keys/AuthKey_${ASC_KEY_ID}.p8
          xcrun altool --upload-app -f build/MyApp.ipa -t ios \
            --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
```

Either way: the **App Store Connect API key** (a `.p8` you generate under Users
and Access → Integrations → App Store Connect API) is the cleanest auth — it
avoids app-specific passwords and 2FA prompts in CI. Treat the `.p8` as a
secret. Bump the build number per upload (a `agvtool next-version -all` step, or
`CURRENT_PROJECT_VERSION=${{ github.run_number }}`) so TestFlight accepts it.

---

## 8. Branch protection

CI only protects `main` if merges *require* it. In **Settings → Branches → Add
branch protection rule** for `main`:

- Enable **Require status checks to pass before merging**.
- Add **`all-templates`** as a required check (it transitively requires all ten
  template jobs — see §1).
- Add your new app checks: **`Build & Test`** and **`Lint & Format`**.
- Optionally **Require branches to be up to date before merging** so checks run
  against the post-merge state.

Because `all-templates` is a single check, you never have to update branch
protection when you add or remove a template — only the matrix and dispatcher
change.

---

## 9. Add a new template to the matrix

Adding a template (say `tvOS-SwiftUI`) is two coordinated edits — the workflow
list and the dispatcher case — mirroring the existing design.

1. **Add the matrix entry** in `.github/workflows/build.yml`:

   ```yaml
       matrix:
         template:
           - Swift-UIKit
           - Swift-SwiftUI
           # … existing entries …
           - tvOS-SwiftUI        # ← new
   ```

2. **Add the build recipe** in `scripts/ci-build.sh`, inside the
   `case "$TEMPLATE"` block, reusing the helpers:

   ```bash
       tvOS-SwiftUI)
           swift_check appletvsimulator arm64-apple-tvos17.0-simulator
           ;;
   ```

3. Put the template sources under `templates/tvOS-SwiftUI/`. The matrix job's
   `Build` step already runs `bash scripts/ci-build.sh tvOS-SwiftUI`, so no
   further workflow changes are needed, and `all-templates` automatically covers
   it.

4. Update the table in [`docs/CI.md`](../CI.md) so the docs stay truthful.

Removing a template is the reverse: delete the matrix entry and the `case`. The
gate and branch protection need no changes either way.

---

## Try it yourself

1. Create `MyApp.xcodeproj`, then add the `app.yml` workflow from §3 and watch
   `xcodebuild test` run your real XCTest suite on a PR.
2. Add the SPM cache from §4 and compare wall-clock time across two runs.
3. Add the `lint` job from §5 with a `.swiftlint.yml`, intentionally introduce a
   style violation, and confirm the PR check goes red.
4. Turn on `-enableCodeCoverage YES` and print a coverage report (§6); add a
   minimum-coverage gate.
5. Add `tvOS-SwiftUI` to the matrix and dispatcher (§9) with a stub template and
   confirm a green `all-templates` once it typechecks.
6. Configure branch protection (§8) requiring `all-templates`, `Build & Test`,
   and `Lint & Format`, then verify you cannot merge a failing PR.

---

## Recap

- The repo's pipeline is a **matrix** of one isolated job per template
  (`fail-fast: false`), each running the shared `ci-build.sh` dispatcher, with
  **logs on failure** and a single **`all-templates`** gate that collapses ten
  checks into one required status check.
- `ci-build.sh` is the single source of truth for *how* each template compiles —
  `swiftc -typecheck`, `clang -fsyntax-only`, `clang++`, `xcrun metal`, or
  `make test` — with SDK fallbacks and softer test-source checks because the
  templates ship without a project.
- For a real app you add an Xcode project and extend CI: run the true XCTest
  suite with `xcodebuild test -scheme … -destination 'platform=iOS Simulator,…'`,
  add caching, SwiftLint/swift-format gates, and code coverage.
- Ship with fastlane *or* `xcodebuild` + an App Store Connect API key, keeping
  every credential in GitHub Secrets, and require the checks via branch
  protection.
- Adding a template is two coordinated edits — the matrix list and the
  `ci-build.sh` case — and the `all-templates` gate makes branch protection
  maintenance-free.

**Next:** [Module 15 — Capstone: Build a Complete App](15-capstone-project.md)
