# Contributing

Thanks for contributing! This guide covers the SwiftUI style conventions and the
branch/PR workflow for this template.

## SwiftUI style guide

- **Swift 6 concurrency.** Use `async/await`; isolate UI and view models with
  `@MainActor`; use `actor`s for shared mutable infrastructure (e.g. the API
  client). Make shared types `Sendable`.
- **State ownership.**
  - `@State` for view-owned `@Observable` view models and value state.
  - `@Environment` for shared dependencies injected from above (e.g.
    `AppRouter`).
  - Avoid `@State` for derived data — compute it in the view model.
- **One feature, one folder.** Keep `<Feature>View.swift` and
  `<Feature>ViewModel.swift` together under `Features/<Feature>/`.
- **Thin views.** No networking, persistence, or business logic in views — push
  it into the view model.
- **Navigation through the router.** Use `router.push(.route)` rather than
  inline `NavigationLink` destinations. Add new cases to `AppRouter.Route`.
- **Previews.** Provide at least one `#Preview` per view, using `MockAPIClient`
  for data and injecting `AppRouter()` into the environment.
- **Naming.** Types `UpperCamelCase`; members `lowerCamelCase`; one primary type
  per file, named after the file.
- **Formatting.** 4-space indentation; keep lines readable (~100 cols). Run
  `swift-format`/SwiftLint if configured.
- **TODOs.** Mark intentional stubs with `// TODO:` and a short description.

## Branch naming

Use a type prefix and a short, kebab-case description:

- `feature/<short-description>` — new functionality
- `fix/<short-description>` — bug fixes
- `chore/<short-description>` — tooling, deps, docs, refactors

Examples: `feature/profile-screen`, `fix/items-decoding`, `chore/update-ci`.

## Pull request process

1. Branch off `main` using the convention above.
2. Keep PRs focused and reasonably small.
3. Ensure the project builds and **all tests pass** (`⌘U` /
   `xcodebuild test`). Add tests for new logic — at minimum a success and a
   failure path for any new view model.
4. Update relevant docs (`docs/`, `README.md`) when behavior changes.
5. Open the PR with a clear description and link any related issue. Fill in what
   changed and how it was verified.
6. CI must be green before review. Address review feedback by pushing additional
   commits (avoid force-pushing once review has started).
7. Squash-merge once approved.
```
