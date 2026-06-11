# Contributing

Thanks for contributing! Please follow the conventions below.

## Swift code style

- **Swift 6 language mode.** Prefer `async`/`await` over completion handlers.
- Use `@MainActor` on UI types (view controllers, view models) and mark shared,
  cross-actor types `Sendable`.
- Use `actor` for stateful concurrency-sensitive services (e.g. `APIClient`).
- Inject dependencies through initializers; do not reach for singletons inside
  feature code (the shared `UserDefaultsManager.shared` default is the only
  sanctioned exception, and it is still overridable).
- Keep view controllers thin — logic and state belong in the view model.
- 4-space indentation, no tabs. Keep lines reasonably short (~120 cols).
- Mark intentional extension points with `// TODO:` and explain the why.
- `MARK:` comments to separate sections (`// MARK: - Lifecycle`).
- Name files after their primary type. Extensions use `Type+Purpose.swift`.
- Run SwiftFormat / SwiftLint if configured before pushing.

## Branch naming

Create a topic branch off `main`:

- `feature/<short-description>` — new functionality
- `fix/<short-description>` — bug fixes
- `chore/<short-description>` — tooling, deps, docs, refactors

Example: `feature/home-pagination`.

## Pull request process

1. Keep PRs focused and small; one logical change per PR.
2. Add or update tests (`Tests/Unit`, `Tests/UI`) for any behavior change.
3. Ensure `xcodebuild test` passes locally and CI is green.
4. Update relevant docs (`docs/`, `README.md`) when behavior or structure changes.
5. Write a clear PR description: what changed, why, and how to verify.
6. Request review and address feedback with follow-up commits (avoid force-push
   until the review is approved, then squash if desired).
7. Squash-merge once approved and CI passes.
