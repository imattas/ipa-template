# Module 15 — Capstone: Build a Complete App

This is it — the final module. You've learned every piece of the `Swift-SwiftUI` template in isolation. Now you'll assemble them into one real, shippable app, built end to end: **Field Notes**, a small but complete app for capturing short notes from the field, each with a title, body, location tag, and timestamp.

Field Notes is deliberately *just* big enough to exercise everything: a **list** of notes, a **detail** screen, an **add/edit** sheet, and a **settings** screen — backed by local persistence, a repository behind a protocol, tested view models, a design pass, and a green CI pipeline that ships to TestFlight.

You won't get a finished codebase handed to you. Instead you'll work through **ten milestones**, each one applying a prior module. The trickier milestones (the domain model, a view model, the add/edit flow) come with concrete code; the rest are tightly specced steps with hints, because by now you can write them. Every milestone links back to the module it draws on — keep those open in another tab.

**What you'll learn**

- How the template's patterns compose into a coherent multi-screen app.
- How to take a feature from domain model to persisted, navigable, tested UI.
- How to make deliberate architecture choices (repository vs. raw store, sheet vs. push) and defend them.
- How to land the whole thing green in CI and out to testers.

**Prerequisites**

- You've completed [Module 14 — CI/CD: Extending the Pipeline](14-cicd-github-actions.md) and ideally all of Modules 01–14. Each milestone below names the modules it relies on; revisit them as needed.
- A working `Swift-SwiftUI` checkout that builds, runs, and passes its tests.

> **The app we're building — Field Notes.** A note has a *title*, a *body*, an optional *location* tag, and a *createdAt* timestamp. Screens: **List** (all notes, newest first, swipe to delete), **Detail** (read a note, edit it), **Add/Edit** (a sheet to create or modify a note), **Settings** (color-scheme preference + a "clear all" action). Data lives **on device** so the app is fully usable offline.

---

## Milestone map

| # | Milestone | Draws on | Output |
| --- | --- | --- | --- |
| 1 | Scaffold from the template | [01](01-getting-started.md), [02](02-anatomy-of-a-template.md) | App builds & runs |
| 2 | Model the domain + feature folder | [03](03-your-first-feature.md) | `Note` model, `Notes/` feature |
| 3 | A real store behind a protocol | [04](04-the-networking-layer.md), [07](07-persistence-and-storage.md) | `NotesRepository` |
| 4 | State & navigation (detail + add/edit sheet) | [05](05-state-and-data-flow.md), [06](06-navigation-and-routing.md) | List ⇄ Detail ⇄ Sheet |
| 5 | Persist user data + settings | [07](07-persistence-and-storage.md) | Notes survive relaunch |
| 6 | DI & a repository/service layer | [08](08-dependency-injection-and-architecture.md) | Clean injection seams |
| 7 | Tests for the view models | [09](09-testing-your-app.md) | Green unit tests |
| 8 | Polish: design, dark mode, a11y | [11](11-design-system-and-accessibility.md) | Designed, accessible UI |
| 9 | Ship to TestFlight | [13](13-shipping-to-the-app-store.md) | A build testers can run |
| 10 | CI green | [14](14-cicd-github-actions.md) | Passing pipeline |

Work top to bottom. Each milestone leaves you with a runnable app.

---

## Milestone 1 — Scaffold from the template · [01], [02]

**Goal:** a fresh, runnable copy of the template you can grow into Field Notes.

1. Copy `templates/Swift-SwiftUI/` to a new project location (or generate an Xcode project from it per [docs/SETUP.md](../../templates/Swift-SwiftUI/docs/SETUP.md)).
2. Set the **bundle identifier** to something you control (e.g. `net.mattas.fieldnotes`) and the **display name** to `Field Notes` (`CFBundleDisplayName` in `App/Info.plist`).
3. Build and run. Confirm the stock `Home` and `Settings` screens appear and navigation works.

**Hint:** don't delete `Home` yet — you'll repurpose it as your Notes list, reusing its loading/error/`.task` shape. Re-read [Module 02](02-anatomy-of-a-template.md) if the `AppEntry` ▸ `AppRouter` ▸ feature wiring isn't fresh.

---

## Milestone 2 — Model the domain + a feature folder · [03]

**Goal:** a `Note` domain model and a `Features/Notes/` folder following the template's feature recipe.

Unlike the template's `Item` (which is fetched from a server), a `Note` is **created and edited locally**, so it carries identity you generate (`UUID`) and a `createdAt` timestamp. Here's the model — put it in `Features/Notes/Note.swift` (or `Core/Models/Note.swift` if you prefer a shared models folder):

```swift
//
//  Note.swift
//  Field Notes
//
//  The core domain model: a short note captured in the field.
//

import Foundation

/// A single field note. Value type, `Sendable` so it crosses concurrency
/// domains, `Codable` so the store can persist it, `Identifiable` for SwiftUI
/// lists, `Hashable` so it can ride a NavigationPath.
struct Note: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var body: String
    var location: String?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        location: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.location = location
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Note {
    /// A blank draft for the "add" flow. Title is empty until the user types.
    static func draft() -> Note {
        Note(title: "", body: "")
    }

    /// Whether this note has enough content to save.
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#if DEBUG
extension Note {
    static let samples: [Note] = [
        Note(title: "Trailhead", body: "Parking lot was nearly full by 9am.", location: "Mt. Tam"),
        Note(title: "Tide pools", body: "Found three sea stars near the north rocks.", location: "Pillar Point"),
        Note(title: "Idea", body: "App: log bird sightings with photos.")
    ]
}
#endif
```

Create the folder `Features/Notes/` now; the next milestones fill it with `NotesListView`, `NotesListViewModel`, `NoteDetailView`, and the editor.

**Hint:** mirror the template's recipe from [Module 03](03-your-first-feature.md): one folder per feature, a `View` + an `@Observable @MainActor` `ViewModel`, dependencies injected through a protocol. The `#if DEBUG` samples are your preview/test fixtures — the analog of `MockAPIClient.sampleItems`.

---

## Milestone 3 — A real store behind a protocol · [04], [07]

**Goal:** a `NotesRepository` protocol (the `APIClientProtocol` analog) with two implementations — a persistent one and an in-memory mock.

Define the capability first, then implementations. This is the same protocol-DI move the template makes with networking ([Module 04](04-the-networking-layer.md)), applied to a local store ([Module 07](07-persistence-and-storage.md)).

```swift
//
//  NotesRepository.swift
//  Field Notes
//

import Foundation

/// The store capability the UI depends on. View models name *this*, never a
/// concrete store — so they're testable and previewable with a mock.
protocol NotesRepository: Sendable {
    func all() async throws -> [Note]
    func save(_ note: Note) async throws        // insert or update by id
    func delete(id: Note.ID) async throws
    func clear() async throws
}
```

**Specced steps:**

1. **`FileNotesRepository`** — an `actor` that persists `[Note]` as JSON to a file in the app's Documents (or Application Support) directory. Model it on the template's `actor APIClient`: load on first access, encode/decode with `JSONEncoder`/`JSONDecoder`, write atomically on every mutation. `save` upserts by `id`; `delete` filters by `id`; `clear` empties the array and the file.
   - **Hint:** for a richer alternative, back it with **SwiftData** (`@Model`, `ModelContainer`) instead of a JSON file — [Module 07](07-persistence-and-storage.md) covers both. Either way the *protocol* is unchanged, which is the point.
2. **`MockNotesRepository`** — an in-memory `final class ... @unchecked Sendable` seeded with `Note.samples`, mirroring `MockAPIClient`. Add optional injected `error` and `delay` so you can drive error/loading states in previews and tests.

**Why a repository at all?** Because the rest of the app should depend on *"I can read and write notes,"* not on *"there's a JSON file at this path"* or *"there's a SwiftData container."* That seam is what lets Milestone 7's tests run with zero disk I/O.

---

## Milestone 4 — State & navigation: detail + add/edit sheet · [05], [06]

**Goal:** a Notes list that pushes to a detail screen and presents an add/edit **sheet**, all state-driven.

### 4a. The list view model

This is your `HomeViewModel`, retargeted at the repository. It owns the list state and the load/delete intents:

```swift
//
//  NotesListViewModel.swift
//  Field Notes
//

import Foundation

@Observable
@MainActor
final class NotesListViewModel {
    private(set) var notes: [Note] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: any NotesRepository

    init(repository: any NotesRepository) {
        self.repository = repository
    }

    /// Loads all notes, newest first. Safe to call from `.task` and after edits.
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            notes = try await repository.all()
                .sorted { $0.createdAt > $1.createdAt }
        } catch is CancellationError {
            // Ignore — view dismissed mid-load.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes the notes at the given list offsets, then reloads.
    func delete(at offsets: IndexSet) async {
        let ids = offsets.map { notes[$0].id }
        do {
            for id in ids { try await repository.delete(id: id) }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

Note the shape is identical to `HomeViewModel` from [Module 03](03-your-first-feature.md)/[Module 05](05-state-and-data-flow.md): private-set state, an `async load()` with the `CancellationError` swallow, dependency injected through a protocol.

### 4b. The add/edit flow (the trickiest part)

The editor is one screen used **two ways**: *add* (start from `Note.draft()`) and *edit* (start from an existing note). Present it as a **sheet**, not a pushed route — a sheet reads as a modal, self-contained task with explicit Save/Cancel, which is exactly right for a form ([Module 06](06-navigation-and-routing.md) covers sheet vs. push).

The editor's view model owns a *working copy* and reports the result back via a closure, so it never mutates the repository directly during typing:

```swift
//
//  NoteEditorViewModel.swift
//  Field Notes
//

import Foundation

@Observable
@MainActor
final class NoteEditorViewModel {
    /// The note being edited. A working copy; committed only on Save.
    var draft: Note
    /// True when editing an existing note (changes the title bar wording).
    let isEditing: Bool
    private(set) var isSaving = false
    private(set) var errorMessage: String?

    private let repository: any NotesRepository
    /// Called after a successful save so the presenter can dismiss + reload.
    private let onSaved: () -> Void

    init(
        note: Note,
        isEditing: Bool,
        repository: any NotesRepository,
        onSaved: @escaping () -> Void
    ) {
        self.draft = note
        self.isEditing = isEditing
        self.repository = repository
        self.onSaved = onSaved
    }

    var canSave: Bool { draft.isValid && !isSaving }

    func save() async {
        guard draft.isValid else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        var toSave = draft
        toSave.updatedAt = .now
        do {
            try await repository.save(toSave)
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

And the editor view — a `Form` with a binding into the `@Observable` draft, plus Cancel/Save toolbar buttons:

```swift
//
//  NoteEditorView.swift
//  Field Notes
//

import SwiftUI

struct NoteEditorView: View {
    @State private var viewModel: NoteEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: NoteEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("Title", text: $viewModel.draft.title)
                    TextField("Body", text: $viewModel.draft.body, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("Location") {
                    TextField(
                        "Where were you?",
                        text: Binding(
                            get: { viewModel.draft.location ?? "" },
                            set: { viewModel.draft.location = $0.isEmpty ? nil : $0 }
                        )
                    )
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Note" : "New Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.save() }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }
}

#Preview("Add") {
    NoteEditorView(
        viewModel: NoteEditorViewModel(
            note: .draft(), isEditing: false,
            repository: MockNotesRepository(), onSaved: {}
        )
    )
}

#Preview("Edit") {
    NoteEditorView(
        viewModel: NoteEditorViewModel(
            note: Note.samples[0], isEditing: true,
            repository: MockNotesRepository(), onSaved: {}
        )
    )
}
```

**Specced steps:**

1. **`NotesListView`** — render `viewModel.notes` in a `List`, with `.task { await viewModel.load() }`, `.refreshable`, swipe-to-delete (`.onDelete { offsets in Task { await viewModel.delete(at: offsets) } }`), and explicit loading/empty/error states (`ContentUnavailableView`), exactly like `HomeView`.
2. **Present the editor.** Hold `@State private var editing: Note?` (or a small `enum EditorMode`) in `NotesListView`; a toolbar **+** button sets it to `.draft()`, and `.sheet(item:)` presents `NoteEditorView`. Pass `onSaved: { editing = nil; Task { await viewModel.load() } }`.
3. **`NoteDetailView`** — push via the router when a row is tapped. Reuse the template's `detail(Item.ID)` pattern, but introduce a `Route.note(Note.ID)` case (add it to `AppRouter.Route`, add a branch in `AppEntry.destination(for:)`) so detail loads by id. From detail, an **Edit** button presents the same `NoteEditorView` seeded with the existing note.

**Hint:** this is the navigation lesson from [Module 06](06-navigation-and-routing.md) made concrete — *push* for drill-down (list → detail), *sheet* for a modal task (add/edit). One editor view serves both add and edit; only its seed note and title differ.

---

## Milestone 5 — Persist user data + settings · [07]

**Goal:** notes survive relaunch, and the Settings screen persists a preference.

1. Wire `FileNotesRepository` (or SwiftData) as the live repository in `AppEntry`. Add a note, force-quit, relaunch — it's still there.
2. Repurpose the template's **Settings** feature: keep the color-scheme picker backed by `@AppStorage(colorScheme: ())` from [`Core/Storage/AppStorage+Keys.swift`](../../templates/Swift-SwiftUI/Core/Storage/AppStorage+Keys.swift), and add a **"Clear All Notes"** button that calls `repository.clear()` behind a confirmation dialog.
3. Apply the persisted color scheme at the root: in `AppEntry`, read the stored `AppColorScheme` and set `.preferredColorScheme(scheme.colorScheme)` on the `WindowGroup` content.

**Hint:** [Module 07](07-persistence-and-storage.md) draws the line between *user content* (notes → the repository/file/SwiftData) and *preferences* (color scheme → `UserDefaults`/`@AppStorage`). Keep them in their lanes. Remember (from [Module 13](13-shipping-to-the-app-store.md)) that `@AppStorage` is a required-reason API you must declare in `PrivacyInfo.xcprivacy`.

---

## Milestone 6 — DI & a service/repository layer · [08]

**Goal:** clean injection seams so nothing constructs its own dependencies deep in the view tree.

1. Construct the live `NotesRepository` once in `AppEntry` (as the template constructs one `apiClient`), and inject it into each view model at the navigation boundary inside `destination(for:)`.
2. Optionally introduce a small **environment-based container** (an `@Observable AppServices` holding the repository) and inject it with `.environment(...)`, so deep screens resolve dependencies without prop-drilling. Weigh this against constructor injection — [Module 08](08-dependency-injection-and-architecture.md) covers the trade-off; for an app this size, constructor injection at the route boundary is enough.
3. Confirm the seam works by *swapping* the live repository for `MockNotesRepository()` in one line and running entirely offline/in-memory.

**Hint:** the test of good DI is exactly that one-line swap. If you can't flip the whole app to the mock from a single place, your dependencies are leaking — pull them back to the boundary.

---

## Milestone 7 — Tests for the view models · [09]

**Goal:** fast, deterministic unit tests for `NotesListViewModel` and `NoteEditorViewModel`, with no disk and no waiting.

Model these on `Tests/Unit/HomeViewModelTests.swift`. Inject `MockNotesRepository` so tests are hermetic.

```swift
import XCTest
@testable import FieldNotes

@MainActor
final class NotesListViewModelTests: XCTestCase {
    func test_load_sortsNewestFirst() async {
        let repo = MockNotesRepository(notes: Note.samples)
        let vm = NotesListViewModel(repository: repo)
        await vm.load()
        XCTAssertEqual(vm.notes.count, Note.samples.count)
        XCTAssertNil(vm.errorMessage)
        // Newest-first invariant:
        XCTAssertTrue(zip(vm.notes, vm.notes.dropFirst())
            .allSatisfy { $0.createdAt >= $1.createdAt })
    }

    func test_load_surfacesError() async {
        let repo = MockNotesRepository(error: URLError(.notConnectedToInternet))
        let vm = NotesListViewModel(repository: repo)
        await vm.load()
        XCTAssertTrue(vm.notes.isEmpty)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_delete_removesNote() async {
        let repo = MockNotesRepository(notes: Note.samples)
        let vm = NotesListViewModel(repository: repo)
        await vm.load()
        let before = vm.notes.count
        await vm.delete(at: IndexSet(integer: 0))
        XCTAssertEqual(vm.notes.count, before - 1)
    }
}
```

**Specced steps:** add `NoteEditorViewModelTests` covering: `canSave` is `false` for an empty title and `true` for a valid draft; `save()` calls the repository and fires `onSaved`; `save()` is a no-op for an invalid draft. Use a spy/closure flag to assert `onSaved` fired. ([Module 09](09-testing-your-app.md) covers `@MainActor` test classes, async tests, and the mock-injection pattern.)

---

## Milestone 8 — Polish: design system, dark mode, accessibility · [11]

**Goal:** the app looks intentional and is usable by everyone.

1. **Design system:** lean on `AccentColor` from `Assets.xcassets`, consistent `Section` grouping, and semantic colors (`.secondary`, `Color(.systemGroupedBackground)`) so the UI adapts to light/dark automatically.
2. **Dark mode:** verify every screen in both schemes (Settings still overrides via the color-scheme preference). Avoid hard-coded `.black`/`.white`.
3. **Accessibility:** add `.accessibilityLabel`/`.accessibilityHint` to icon-only buttons (the **+** add button, swipe actions); ensure **Dynamic Type** scales (your `TextField` body already grows with `lineLimit(3...8)`); test with **VoiceOver** and the largest accessibility text size; check contrast.

**Hint:** [Module 11](11-design-system-and-accessibility.md) has the checklist. The cheapest win is never hard-coding colors and always labeling icon-only controls.

---

## Milestone 9 — Ship to TestFlight · [13]

**Goal:** a build a real tester can install.

1. Set a real **bundle identifier**, **marketing version** (`1.0.0`), and **build number** (`1`) in `App/Info.plist` ([Module 13](13-shipping-to-the-app-store.md)).
2. Add a 1024×1024 **app icon** to `AppIcon.appiconset` and author a **`PrivacyInfo.xcprivacy`** declaring the `UserDefaults` required-reason API (you use `@AppStorage`).
3. **Archive** (Xcode **Product ▸ Archive** or `xcodebuild archive` + `-exportArchive`), **upload** to App Store Connect, and add the processed build to an **internal TestFlight** group. Install it on your own device from the TestFlight app.

**Hint:** internal testers need no Beta App Review — you'll be testing within minutes of the build finishing processing. Run the full release checklist at the end of [Module 13](13-shipping-to-the-app-store.md).

---

## Milestone 10 — CI green · [14]

**Goal:** every push builds and tests Field Notes automatically.

1. Add a build/test job for your app modeled on the repo's matrix workflow (`.github/workflows/build.yml` and `scripts/ci-build.sh`) — build for the simulator and run the unit + UI tests ([Module 14](14-cicd-github-actions.md)).
2. Make the **green badge** real: fix anything that fails on the runner (often a stricter Swift 6 concurrency warning that's a local note but a CI error).
3. (Stretch) Add a **release job** that, on a tag, archives and uploads to TestFlight using an **App Store Connect API key** and manual signing — the manual-signing path from [Module 13](13-shipping-to-the-app-store.md).

**Hint:** the same `xcodebuild archive` / `-exportArchive` commands you ran by hand in Milestone 9 are what the CI release job automates; the only differences are non-interactive signing and secrets stored in GitHub Actions.

---

## Where to go next

You have a complete, shipped app. Pick an extension and apply the same patterns:

- **Photos:** attach an image to each note (PhotosPicker + on-disk storage; declare the file-access API in your privacy manifest).
- **Search & filter:** add `.searchable` over title/body and a location filter — pure view-model state.
- **Real location:** capture GPS with CoreLocation instead of a typed string (new capability + permission usage string + privacy label).
- **Sync:** move the store to **SwiftData + CloudKit** so notes sync across the user's devices — your `NotesRepository` protocol absorbs the change without touching the views.
- **Widgets / App Intents:** surface the latest note on the Home Screen, or add a "New Note" App Shortcut.
- **Localization & richer accessibility:** extract strings to a catalog; add custom rotor actions.

Each one slots cleanly into the seams you built — a new feature folder, maybe a new `Route` case, maybe a new repository method behind the same protocol. That composability is the whole payoff of the template's architecture.

---

## Congratulations

You started this course able to open a template, and you're finishing it having designed, built, tested, polished, signed, and shipped a real multi-screen Apple app — domain model to TestFlight to green CI. Every pattern you used here (MVVM with `@Observable @MainActor` view models, protocol-based DI, a typed router, a repository behind a protocol, hermetic tests, an automated pipeline) is exactly how production apps are built. Take Field Notes, make it yours, and ship the next one. Well done.

**Back to the [course index](README.md).**
