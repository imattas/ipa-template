# Contributing

## Style Guide

- **Swift 6** with strict concurrency. Prefer `async/await` over completion
  handlers.
- Mark UI types and view models `@MainActor`; keep networking off the main actor
  (the `APIClient` is an `actor`).
- Make models and protocols `Sendable`.
- Use the `@Observable` macro for view models (with the documented
  `ObservableObject` fallback for older deployment targets).
- Inject dependencies through initializers behind protocols (e.g.
  `APIClientProtocol`); never reference concrete `Core` types from views.
- Add a `#Preview` to every new SwiftUI view.
- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Keep watch UI compact: small fonts, `List`, `.containerBackground`, and
  `ContentUnavailableView` for empty/error states.
- Leave actionable `// TODO:` markers rather than placeholder/lorem content.

## Branch Naming

- `feature/<short-description>` — new functionality
- `fix/<short-description>` — bug fixes
- `chore/<short-description>` — tooling, docs, refactors

## Pull Request Process

1. Branch off `main` using the convention above.
2. Keep PRs focused and small; describe **what** and **why**.
3. Add or update unit tests (`Tests/Unit/`) for any logic change.
4. Ensure the project builds and **all tests pass** (⌘U) before requesting review.
5. Reference any related issues in the PR description.
6. At least one approving review is required before merge.
7. Squash-merge with a clear, conventional commit message.
