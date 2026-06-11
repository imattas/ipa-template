# Contributing

Thanks for contributing! Please follow the guidelines below.

## Style Guide

- **Language**: Swift 6 with strict concurrency. Prefer `async`/`await` and
  actors over completion handlers and locks.
- **Concurrency**: UI types and view models are `@MainActor`. Types crossing
  concurrency boundaries must be `Sendable`.
- **MVVM boundaries**: View controllers never perform networking or persistence;
  view models never import `AppKit`.
- **Programmatic UI**: No Storyboards or XIBs. Build views in `loadView()` and
  use the helpers in `NSView+Extensions.swift` for Auto Layout.
- **Dependency injection**: Pass dependencies (e.g. `APIClientProtocol`,
  `UserDefaultsManager`) through initializers; default to the live type.
- **Naming**: `UpperCamelCase` for types, `lowerCamelCase` for members. Suffix
  view controllers with `ViewController` and view models with `ViewModel`.
- **Formatting**: 4-space indentation, no trailing whitespace, keep lines
  reasonably short. Use `// MARK: -` to group sections.
- **TODOs**: Mark template placeholders with `// TODO:` and a short note.

## Branch Naming

Use a type prefix and a short kebab-case description:

- `feature/<short-description>` — new functionality
- `fix/<short-description>` — bug fixes
- `chore/<short-description>` — tooling, docs, refactors

Examples: `feature/search-screen`, `fix/refresh-spinner`, `chore/update-readme`.

## Commits

- Write imperative, present-tense subjects (e.g. "Add settings reset button").
- Keep commits focused and self-contained.

## Pull Request Process

1. Branch off the default branch using the naming convention above.
2. Ensure the project builds and **all unit tests pass** (⌘U).
3. Add or update tests for any behavior you change (view models especially).
4. Update relevant docs (`README.md`, `docs/*`) when behavior or setup changes.
5. Open a PR with a clear description of *what* changed and *why*; link any
   related issues.
6. Address review feedback by pushing follow-up commits to the same branch.
7. A maintainer merges once CI is green and the PR has approval.
```
