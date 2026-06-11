# Module 03 — Building Your First Feature

In Module 02 you toured the template and saw how `AppEntry`, `AppRouter`, and the `Home`/`Settings` features fit together. Now you'll add a brand-new feature of your own — a **Profile** screen — end to end. By the time you finish you'll have a repeatable recipe you can apply to every screen you build: **one folder per feature (a View + a ViewModel), dependencies injected through a protocol, and a typed route wired into the router.**

We'll follow the exact pattern the template already uses for `Home`, so your code looks like it shipped with the repo.

**What you'll learn**

- The template's feature recipe: `Features/<Name>/<Name>View.swift` + `<Name>ViewModel.swift`.
- How to write an `@Observable @MainActor` view model with loading/error state and an `async load()`.
- How to inject a dependency (the API client) through a protocol so the view model is testable and previewable.
- How to consume a view model in SwiftUI with `.task`, render loading/error states, and add a `#Preview` backed by a mock.
- How to register a new `Route` and a `navigationDestination` branch, then navigate to it programmatically.

**Prerequisites**

- You've completed [Module 02 — Anatomy of a Template](02-anatomy-of-a-template.md) and can open `templates/Swift-SwiftUI/` in Xcode.
- The project builds and runs the Home screen.

---

## The recipe at a glance

Every feature in this template is three small moves:

1. **Create the folder** `Features/<Name>/` with two files: the SwiftUI `View` and its `@Observable` `ViewModel`.
2. **Inject dependencies** into the view model via a protocol (here, `any APIClientProtocol`) so it can be tested and previewed with a mock.
3. **Wire a route**: add a `case` to `AppRouter.Route`, add a matching branch in `AppEntry`'s `destination(for:)`, and `router.push(...)` from somewhere.

Let's do all three for a Profile screen.

---

## Step 1 — Create the feature folder and view model

Create a new group/folder at `templates/Swift-SwiftUI/Features/Profile/`.

Add the file `Features/Profile/ProfileViewModel.swift`. It mirrors `HomeViewModel` exactly: it owns presentation state, takes its dependency through the `APIClientProtocol` abstraction, and exposes a single `async load()`.

```swift
//
//  ProfileViewModel.swift
//  Swift-SwiftUI
//
//  View model for the Profile feature. Loads the user's items from the
//  injected API client and exposes presentation state for ProfileView.
//

import Foundation

// NOTE: Uses the Observation framework (@Observable), available on
// iOS 17 / macOS 14+. For earlier deployment targets, replace `@Observable`
// with `: ObservableObject`, annotate the published properties with
// `@Published`, and observe with `@StateObject`/`@ObservedObject` in the view.
@Observable
@MainActor
final class ProfileViewModel {
    /// The display name shown in the header.
    private(set) var displayName = "Guest"
    /// Items associated with this profile (reuses the template's Item model).
    private(set) var items: [Item] = []
    /// True while a load is in flight (drives the loading UI).
    private(set) var isLoading = false
    /// A user-facing error message, or nil when there is no error.
    private(set) var errorMessage: String?

    private let api: any APIClientProtocol

    /// - Parameter api: The networking dependency. Inject `MockAPIClient`
    ///   for previews and tests.
    init(api: any APIClientProtocol) {
        self.api = api
    }

    /// Loads the profile's items, updating loading/error state along the way.
    /// Safe to call repeatedly (e.g. from `.task` and pull-to-refresh).
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await api.fetchItems()
            displayName = "Welcome back"
        } catch is CancellationError {
            // Ignore cancellations (e.g. the view was dismissed mid-load).
        } catch {
            errorMessage = (error as? APIError)?.errorDescription
                ?? error.localizedDescription
        }
    }
}
```

Notice what we reused: the `Item` model, the `APIClientProtocol` dependency, and the exact `load()` shape from `HomeViewModel` — including the `CancellationError` swallow and the `APIError` message extraction. Staying consistent with the template means less to learn and fewer surprises.

> **Why inject `any APIClientProtocol` instead of `APIClient()`?** Because the view model never names the concrete type, you can hand it a real `APIClient` in the app and a `MockAPIClient` in previews and tests. That's the whole point of protocol-based DI: the screen depends on a *capability* (`fetchItems()`), not an implementation.

---

## Step 2 — Write the view

Add `Features/Profile/ProfileView.swift`. It owns its view model as `@State` (so the `@Observable` instance survives re-renders), drives loading with `.task`, and renders explicit loading and error states — exactly like `HomeView`.

```swift
//
//  ProfileView.swift
//  Swift-SwiftUI
//
//  The Profile feature screen. Renders the user's items with loading and
//  error states and reloads on appear / pull-to-refresh.
//

import SwiftUI

struct ProfileView: View {
    /// View model owned by this screen. `@State` keeps the @Observable model
    /// alive across re-renders.
    @State private var viewModel: ProfileViewModel

    /// The shared router, supplied via the environment by AppEntry.
    @Environment(AppRouter.self) private var router

    init(viewModel: ProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Profile")
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let message = viewModel.errorMessage, viewModel.items.isEmpty {
            ContentUnavailableView {
                Label("Couldn't Load Profile", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await viewModel.load() }
                }
            }
        } else if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView("Loading…")
        } else {
            profileList
        }
    }

    private var profileList: some View {
        List {
            Section {
                Text(viewModel.displayName)
                    .font(.title2.bold())
            }
            Section("Your Items") {
                ForEach(viewModel.items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.headline)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}

#Preview("Loaded") {
    NavigationStack {
        ProfileView(viewModel: ProfileViewModel(api: MockAPIClient()))
    }
    .environment(AppRouter())
}

#Preview("Error") {
    NavigationStack {
        ProfileView(
            viewModel: ProfileViewModel(
                api: MockAPIClient(error: APIError.server(status: 500))
            )
        )
    }
    .environment(AppRouter())
}
```

The two `#Preview`s use `MockAPIClient` — the same in-memory client the template ships for `HomeView`. The first shows the happy path; the second injects `APIError.server(status: 500)` so you can verify your error UI in the canvas without a network.

> Both previews wrap the view in `NavigationStack { ... }` and supply `.environment(AppRouter())`. The view reads `AppRouter` from the environment, so a preview must provide one or it will crash.

---

## Step 3 — Register the route

Open `Core/Navigation/AppRouter.swift` and add a `case profile` to the `Route` enum. The template literally leaves a TODO at this spot:

```swift
enum Route: Hashable {
    case home
    case settings
    case detail(Item.ID)
    case profile          // <-- add this
}
```

Because `Route` is `Hashable` and `profile` has no associated value, nothing else in `AppRouter` needs to change — `push(_:)`, `pop()`, and `popToRoot()` already work for any case.

> **When to add a `case` vs reuse `detail`.** Add a new case when the screen is a distinct destination with its own view model — that's Profile. The existing `detail(Item.ID)` case is the right choice when you're navigating to a screen that's parameterized by an item's id (a detail screen). If your "profile" were really "the detail page for a user id," you could reuse `detail(_:)` and pass the id along instead of adding a case.

---

## Step 4 — Add the destination branch in AppEntry

Open `App/AppEntry.swift` and add a branch to the `destination(for:)` `@ViewBuilder`, alongside the existing `home`/`settings`/`detail` cases:

```swift
@ViewBuilder
private func destination(for route: AppRouter.Route) -> some View {
    switch route {
    case .home:
        HomeView(viewModel: HomeViewModel(api: apiClient))
    case .settings:
        SettingsView(viewModel: SettingsViewModel())
    case .detail(let id):
        DetailPlaceholderView(itemID: id)
    case .profile:
        ProfileView(viewModel: ProfileViewModel(api: apiClient))   // <-- add this
    }
}
```

This is where the dependency gets injected at the navigation boundary: `AppEntry` already holds a shared `apiClient`, and it constructs the `ProfileViewModel` with it. The view never touches the concrete client — it just receives a fully built view model.

Centralizing this `switch` in `AppEntry` is deliberate: individual views push *routes* (data), and only `AppEntry` knows how to turn a route into a concrete view. We dig into why that matters in [Module 06 — Navigation & Routing](06-navigation-and-routing.md).

---

## Step 5 — Navigate to it

Finally, give the user a way to get there. Add a toolbar button to `Features/Home/HomeView.swift` next to the existing Settings button:

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button {
            router.push(.settings)
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }
    ToolbarItem(placement: .topBarLeading) {
        Button {
            router.push(.profile)        // <-- pushes your new route
        } label: {
            Label("Profile", systemImage: "person.crop.circle")
        }
    }
}
```

`HomeView` already reads the router from the environment (`@Environment(AppRouter.self) private var router`), so `router.push(.profile)` appends your route to the `NavigationPath`, `AppEntry`'s `navigationDestination(for:)` resolves it, and SwiftUI pushes `ProfileView` onto the stack.

Build and run. Tap **Profile** on the Home screen and you'll land on your new feature, fully wired.

---

## Try it yourself

1. **Add a sign-out action.** Put a `func signOut()` on `ProfileViewModel` that clears `items` and resets `displayName` to `"Guest"`, and surface it as a toolbar button.
2. **Simulate latency.** `MockAPIClient` accepts a `delay:` (`MockAPIClient(delay: .seconds(2))`). Use it in the "Loaded" preview to watch your `ProgressView("Loading…")` state in the canvas.
3. **Reuse `detail` instead of adding a case.** Make a profile row push `router.push(.detail(item.id))` and confirm it lands on the template's `DetailPlaceholderView` — proof that the routing recipe scales without new cases when a destination is just "a thing identified by an id."
4. **Write a unit test.** Mirror `Tests/Unit/HomeViewModelTests.swift`: construct `ProfileViewModel(api: MockAPIClient(...))`, call `await load()`, and assert on `items`/`errorMessage`.

---

## Recap

- A feature in this template is a folder under `Features/` containing a `View` and an `@Observable @MainActor` `ViewModel`.
- View models take dependencies through protocols (`any APIClientProtocol`) so they're testable and previewable with `MockAPIClient`.
- The view owns its view model as `@State`, kicks off work in `.task`, and renders explicit loading/error states with a `#Preview` per state.
- Wiring navigation is three edits: a `Route` case, a `destination(for:)` branch in `AppEntry`, and a `router.push(...)` call.
- Reuse `detail(Item.ID)` when a destination is id-parameterized; add a new case for a genuinely distinct screen.

**Next:** [Module 04 — The Networking Layer](04-the-networking-layer.md)
