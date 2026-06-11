# Module 07 — Persistence & Storage

Every app needs to remember something between launches: a theme preference, an
auth token, the user's notes, a downloaded cache. Apple gives you several
storage mechanisms, and the right one depends on *what* you're storing and *how
sensitive* it is. This module walks the spectrum from the simplest option to the
most robust, building on the conventions already baked into the templates.

We progress from small to large:

1. `@AppStorage` and the `AppStorage+Keys` pattern — for tiny user preferences.
2. `UserDefaults` directly, and the `UserDefaultsManager` wrapper used in the
   UIKit/AppKit templates.
3. The **Keychain** — for secrets and tokens (we'll secure the auth token from
   Module 04).
4. **SwiftData** — for structured, queryable local data (and when to reach for
   Core Data instead).
5. Plain **files + `Codable`** — for blobs you control on disk.

By the end you'll have a decision rule for picking among them.

**What you'll learn**

- When each storage mechanism is the correct tool — and when it is the wrong one.
- How to extend the template's `StorageKeys` catalog with a new typed
  `@AppStorage` key and wire it to a Settings toggle.
- How to write a small, `Sendable` `KeychainStore` over the Security framework
  with `save`/`read`/`delete`, and use it to persist the auth token.
- How to define a SwiftData `@Model`, attach a `ModelContainer` at the app
  entry point, `@Query` it in a view, and insert/delete records.
- How to read and write `Codable` values to the app's Application Support
  directory.

**Prerequisites**

- [Module 06 — Navigation & Routing](06-navigation-and-routing.md). We'll reuse
  `SettingsView`, `SettingsViewModel`, and the `AppRouter` you already know.
- A passing build of the `Swift-SwiftUI` template (all ten templates build green
  in CI).
- The auth token concept from Module 04 — we secure it properly here.

---

## A map of the storage options

Hold this table in your head; the rest of the module fills it in.

| Mechanism            | Good for                                  | Backed by              | Secure? | Queryable? |
| -------------------- | ----------------------------------------- | ---------------------- | ------- | ---------- |
| `@AppStorage`        | A handful of user prefs (Bool/String/enum)| `UserDefaults`         | No      | No         |
| `UserDefaults`       | Same, but from non-View code              | `UserDefaults`         | No      | No         |
| **Keychain**         | Tokens, passwords, small secrets          | Security framework     | **Yes** | No         |
| **SwiftData**        | Structured records you list/filter/sort   | SQLite (via Core Data) | No*     | **Yes**    |
| **Files + Codable**  | Documents, caches, exports, large blobs   | The filesystem         | No*     | No         |

\* SwiftData stores and files can be placed in protected data classes / encrypted
volumes, but they are **not** a substitute for the Keychain for secrets.

The golden rule: **never put a secret in `UserDefaults` or an unencrypted file.**
`UserDefaults` is a plaintext plist; anyone with the device backup can read it.

---

## Step 1 — Extend the `@AppStorage` keys catalog

The `Swift-SwiftUI` template already centralizes its persisted keys in
`Core/Storage/AppStorage+Keys.swift`. Open it and you'll find a `StorageKeys`
namespace plus typed `@AppStorage` initializers so feature code never hard-codes
a raw string:

```swift
// Core/Storage/AppStorage+Keys.swift  (existing)
enum StorageKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let appColorScheme = "appColorScheme"
    static let isAnalyticsEnabled = "isAnalyticsEnabled"
    // TODO: Add new persisted keys here.
}

extension AppStorage where Value == Bool {
    init(analyticsEnabled: Void) {
        self.init(wrappedValue: true, StorageKeys.isAnalyticsEnabled)
    }
}
```

Let's add a new preference: **haptic feedback enabled**. Two edits, both in
`Core/Storage/AppStorage+Keys.swift`.

First, register the key:

```swift
enum StorageKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let appColorScheme = "appColorScheme"
    static let isAnalyticsEnabled = "isAnalyticsEnabled"
    static let isHapticsEnabled = "isHapticsEnabled"   // <-- new
}
```

Then add a typed helper next to the existing `Bool` initializers:

```swift
extension AppStorage where Value == Bool {
    init(onboardingCompleted: Void) {
        self.init(wrappedValue: false, StorageKeys.hasCompletedOnboarding)
    }

    init(analyticsEnabled: Void) {
        self.init(wrappedValue: true, StorageKeys.isAnalyticsEnabled)
    }

    /// `@AppStorage` for the haptic-feedback flag (defaults to on).
    init(hapticsEnabled: Void) {
        self.init(wrappedValue: true, StorageKeys.isHapticsEnabled)
    }
}
```

Why the `Void`-argument trick? It lets you write `@AppStorage(hapticsEnabled: ())`
and get *both* the correct key and the correct default for free — the call site
can't accidentally pass the wrong string or a mismatched default.

---

## Step 2 — Wire the new key to a Settings toggle

Open `Features/Settings/SettingsView.swift`. The template already declares two
typed `@AppStorage` properties; add a third:

```swift
// Features/Settings/SettingsView.swift
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(AppRouter.self) private var router

    @AppStorage(colorScheme: ()) private var colorScheme: AppColorScheme
    @AppStorage(analyticsEnabled: ()) private var analyticsEnabled: Bool
    @AppStorage(hapticsEnabled: ()) private var hapticsEnabled: Bool   // <-- new
    // ...
}
```

Then add a toggle to the `Form`, alongside the existing analytics toggle:

```swift
Section("Privacy") {
    Toggle("Share Analytics", isOn: $analyticsEnabled)
}

Section("Feedback") {
    Toggle("Haptic Feedback", isOn: $hapticsEnabled)
}
```

That's it. `@AppStorage` is a property wrapper over `UserDefaults`; flipping the
toggle persists the value immediately and any other view reading
`@AppStorage(hapticsEnabled: ())` updates live. No view model code, no manual
save call.

> **Reading it elsewhere.** From non-View code (a view model, a service), you
> read the same value with `UserDefaults.standard.bool(forKey: StorageKeys.isHapticsEnabled)`.
> Always go through `StorageKeys` so the key stays in one place — exactly what
> `SettingsViewModel.resetOnboarding()` does today.

---

## Step 3 — `UserDefaults` directly, and the `UserDefaultsManager` wrapper

`@AppStorage` only works inside a SwiftUI `View`. When you're in a view model or
a plain service, you talk to `UserDefaults` directly:

```swift
// Reading/writing from non-View code
UserDefaults.standard.set(false, forKey: StorageKeys.hasCompletedOnboarding)
let done = UserDefaults.standard.bool(forKey: StorageKeys.hasCompletedOnboarding)
```

This is precisely what the template's `SettingsViewModel` does:

```swift
// Features/Settings/SettingsViewModel.swift  (existing)
func resetOnboarding() {
    UserDefaults.standard.set(false, forKey: StorageKeys.hasCompletedOnboarding)
}
```

### The UIKit/AppKit approach: `UserDefaultsManager`

The UIKit and AppKit templates don't have SwiftUI's `@AppStorage`, so instead of
the keys-catalog pattern they ship a **typed wrapper** in
`Core/Storage/UserDefaultsManager.swift`. It uses a custom `@UserDefault`
property wrapper to pair each key with its default in one place:

```swift
// Swift-UIKit/Core/Storage/UserDefaultsManager.swift  (existing)
@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value
    var store: UserDefaults = .standard

    var wrappedValue: Value {
        get { store.object(forKey: key) as? Value ?? defaultValue }
        set { store.set(newValue, forKey: key) }
    }
}

final class UserDefaultsManager: @unchecked Sendable {
    static let shared = UserDefaultsManager()

    @UserDefault(key: Keys.notifications, defaultValue: true)
    var isNotificationsEnabled: Bool

    @UserDefault(key: Keys.darkMode, defaultValue: false)
    var isDarkModePreferred: Bool
    // ...
}
```

Read or write a preference as a plain property: `UserDefaultsManager.shared.isDarkModePreferred = true`.

The `init` rebinds each wrapper to the injected `defaults` store, so a unit test
can pass `UserDefaults(suiteName: "test")` and avoid polluting the real domain:

```swift
let suite = UserDefaults(suiteName: "com.example.tests")!
let manager = UserDefaultsManager(defaults: suite)
```

**SwiftUI vs UIKit, same goal.** Both patterns exist to stop raw key strings
leaking into feature code. SwiftUI leans on `@AppStorage` extensions
(`AppStorage+Keys.swift`); UIKit/AppKit lean on a typed `UserDefaultsManager`.
Pick the one your template already uses; don't mix them.

---

## Step 4 — The Keychain: a `KeychainStore` for secrets

Back in Module 04 you obtained an auth token from a sign-in call. If you stored
it in `UserDefaults`, stop — that token is a credential, and `UserDefaults` is
plaintext. Tokens, passwords, refresh keys, and API secrets belong in the
**Keychain**, which the OS stores encrypted and tied to the device.

The Security framework's C API is verbose, so we wrap it once. Create
`Core/Storage/KeychainStore.swift`:

```swift
//
//  KeychainStore.swift
//  Swift-SwiftUI
//
//  A minimal, Sendable wrapper over the Security framework for storing small
//  secrets (tokens, passwords) as generic passwords. Values are Data; encode
//  strings as UTF-8 at the call site.
//

import Foundation
import Security

/// Errors surfaced by `KeychainStore`. `status` carries the raw OSStatus.
enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String?
            return "Keychain operation failed (\(status)): \(message ?? "unknown")."
        }
    }
}

/// A thin, value-type wrapper over the Keychain. It holds no mutable state, so
/// it is trivially `Sendable` and safe to share across concurrency domains.
struct KeychainStore: Sendable {
    /// Scopes all items to this app/service so keys never collide with other
    /// apps in the same access group.
    let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "app") {
        self.service = service
    }

    /// Stores `data` under `key`, overwriting any existing value.
    func save(_ data: Data, for key: String) throws {
        // Delete first so we can treat save as an upsert.
        try? delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // Available after first unlock; not migrated to new devices.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Reads the value for `key`, or `nil` if no item exists.
    func read(_ key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Removes the item for `key`. A missing item is not an error.
    func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

// Convenience for the common case: storing a token string.
extension KeychainStore {
    func saveString(_ value: String, for key: String) throws {
        try save(Data(value.utf8), for: key)
    }

    func readString(_ key: String) throws -> String? {
        guard let data = try read(key) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
```

### Securing the auth token

Now persist the Module 04 token securely. A natural home is a small
`AuthTokenStore` that owns the key string, mirroring how `StorageKeys` owns the
`UserDefaults` keys:

```swift
// Core/Storage/AuthTokenStore.swift
import Foundation

/// Persists the authentication token in the Keychain. Inject this into any
/// service that needs to attach a bearer token to requests.
struct AuthTokenStore: Sendable {
    private static let key = "auth.token"
    private let keychain: KeychainStore

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    var token: String? {
        get throws { try keychain.readString(Self.key) }
    }

    func save(_ token: String) throws {
        try keychain.saveString(token, for: Self.key)
    }

    /// Call on sign-out.
    func clear() throws {
        try keychain.delete(Self.key)
    }
}
```

At your sign-in call site (the place that produced the token in Module 04):

```swift
let token = try await api.signIn(email: email, password: password)
try AuthTokenStore().save(token)
```

And when building a request that needs authorization, read it back:

```swift
if let token = try AuthTokenStore().token {
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}
```

> **Why `KeychainStore` is `Sendable`.** It's an immutable `struct` (just a
> `service` string), so Swift 6 lets you pass it freely into actors and tasks.
> The Keychain itself is thread-safe; the wrapper adds no shared mutable state.
> This matters because, as Module 08 shows, you'll inject it into the actor-based
> `APIClient` or a service layer.

---

## Step 5 — Structured data with SwiftData

`UserDefaults` and the Keychain hold a few scalars. When you need *records* you
list, filter, and sort — notes, tasks, cached items — reach for **SwiftData**
(iOS 17 / macOS 14+). It's a modern, declarative layer over the same SQLite store
Core Data uses, and it integrates directly with SwiftUI.

### 5a — Define a `@Model`

Create `Features/Notes/Note.swift`:

```swift
//
//  Note.swift
//  Swift-SwiftUI
//

import Foundation
import SwiftData

/// A persisted note. `@Model` makes the class a SwiftData entity: each stored
/// property becomes a column, and the class gains identity + change tracking.
@Model
final class Note {
    var title: String
    var body: String
    var createdAt: Date

    init(title: String, body: String = "", createdAt: Date = .now) {
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}
```

### 5b — Attach a `ModelContainer` at the entry point

A `ModelContainer` is the SwiftData equivalent of the API client you build once
in `App/AppEntry.swift`. Add the `.modelContainer(for:)` modifier to your
`WindowGroup` so every descendant view gets a `modelContext` from the
environment:

```swift
// App/AppEntry.swift  (additions shown in context)
import SwiftUI
import SwiftData

@main
struct AppEntry: App {
    @State private var router = AppRouter()
    @State private var apiClient: any APIClientProtocol = APIClient()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                HomeView(viewModel: HomeViewModel(api: apiClient))
                    .navigationDestination(for: AppRouter.Route.self) { route in
                        destination(for: route)
                    }
            }
            .environment(router)
        }
        .modelContainer(for: Note.self)   // <-- one container for the whole app
    }
}
```

`for: Note.self` infers a schema from your models and provisions an on-disk
SQLite store automatically. List multiple models with `for: [Note.self, Tag.self]`.

> For previews and tests, build an in-memory container so you never touch the
> real store:
> ```swift
> let config = ModelConfiguration(isStoredInMemoryOnly: true)
> let container = try ModelContainer(for: Note.self, configurations: config)
> ```

### 5c — `@Query` in a view, then insert and delete

`@Query` fetches and *observes* the store: insert a `Note` anywhere and every
view querying it refreshes. Create `Features/Notes/NotesView.swift`:

```swift
//
//  NotesView.swift
//  Swift-SwiftUI
//

import SwiftUI
import SwiftData

struct NotesView: View {
    // Live, sorted query. Re-runs automatically on any change to the store.
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]

    // The context to insert/delete through, provided by .modelContainer above.
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            ForEach(notes) { note in
                VStack(alignment: .leading) {
                    Text(note.title).font(.headline)
                    Text(note.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Notes")
        .toolbar {
            Button("Add", systemImage: "plus") {
                context.insert(Note(title: "New Note \(notes.count + 1)"))
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(notes[index])
        }
    }
}
```

Notice there's no explicit `save()` — SwiftData autosaves on the main run loop.
Call `try context.save()` yourself only when you need a write to be durable
*immediately* (e.g. just before backgrounding).

To reach this screen, add a `.notes` case to `AppRouter.Route` and return
`NotesView()` from `destination(for:)` in `AppEntry.swift` — exactly the routing
pattern from Module 06.

### When to choose Core Data instead of SwiftData

SwiftData is the default for new code, but choose **Core Data** when you need:

- A **deployment target below iOS 17 / macOS 14** (SwiftData is unavailable).
- An **existing Core Data store** to keep using (don't rewrite a working model).
- Features SwiftData doesn't yet expose cleanly: complex `NSFetchedResultsController`
  batching, fine-grained migration policies, child/background contexts with
  precise control, or advanced predicates.

The two share a storage engine, so you can adopt SwiftData for new entities while
an older Core Data stack lives on. For a greenfield template app, prefer
SwiftData.

---

## Step 6 — Files and `Codable` on disk

Sometimes you just want to drop a `Codable` value on disk: a cached API response,
an exported document, a JSON config you regenerate. Put app-managed data the user
never browses in the **Application Support** directory (it's backed up but hidden
from the user, unlike `Documents`).

Create `Core/Storage/FileStore.swift`:

```swift
//
//  FileStore.swift
//  Swift-SwiftUI
//

import Foundation

/// Reads and writes `Codable` values as JSON files under Application Support.
struct FileStore: Sendable {
    private let directory: URL

    init() throws {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        // Namespace under the bundle id so we don't collide with the system.
        directory = base.appendingPathComponent(
            Bundle.main.bundleIdentifier ?? "app", isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
    }

    func save<T: Encodable>(_ value: T, to filename: String) throws {
        let url = directory.appendingPathComponent(filename)
        let data = try JSONEncoder().encode(value)
        // .atomic writes to a temp file then renames — no half-written files.
        try data.write(to: url, options: [.atomic])
    }

    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T? {
        let url = directory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    func delete(_ filename: String) throws {
        let url = directory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
```

The template's `Item` is already `Codable`, so caching a fetched feed is one
line each way:

```swift
let store = try FileStore()
try store.save(items, to: "items-cache.json")           // write
let cached = try store.load([Item].self, from: "items-cache.json")  // read
```

> **Directory cheat sheet.** `Documents` — user-visible files the user creates;
> `Application Support` — app data the user shouldn't see; `Caches` — regenerable
> data the OS may purge under disk pressure (great for the items cache above);
> `tmp` — scratch space cleared aggressively.

---

## Choosing among them

A decision tree for "where does this value go?":

1. **Is it a secret** (token, password, key)? → **Keychain** (`KeychainStore`).
   Never anywhere else.
2. **Is it a small user preference** (a Bool, a String, an enum)?
   → SwiftUI: **`@AppStorage`** via `AppStorage+Keys.swift`.
   → UIKit/AppKit: **`UserDefaultsManager`**.
3. **Is it a collection of records you list/filter/sort**?
   → **SwiftData** (or **Core Data** for pre-iOS 17 or an existing store).
4. **Is it a document, cache, or large blob you control**? → **Files + `Codable`**
   in Application Support (or Caches if regenerable).

Two anti-patterns to avoid: a **secret in `UserDefaults`** (it's plaintext), and
**relational data in JSON files** (you'll reinvent a worse SQLite — use SwiftData).

---

## Try it yourself

1. **Finish the haptics preference.** In `HomeView`, read
   `@AppStorage(hapticsEnabled: ())` and trigger a
   `UIImpactFeedbackGenerator` (or `.sensoryFeedback` on iOS 17+) on a button tap
   only when the flag is on.
2. **Add a sign-out button** to `SettingsView` that calls
   `try AuthTokenStore().clear()`, then verify with a breakpoint that
   `AuthTokenStore().token` returns `nil` afterward.
3. **Edit notes.** Add a `body` editor: tap a `Note` to push a detail screen that
   binds to its `body`; confirm the list reflects the change with no manual save.
4. **Test against an in-memory store.** Write a unit test that builds a
   `ModelContainer(isStoredInMemoryOnly: true)`, inserts two `Note`s, and asserts
   a `@Query`-equivalent `FetchDescriptor` returns them sorted by `createdAt`.
5. **Cache the feed.** In `HomeViewModel.load()`, after a successful fetch, write
   items via `FileStore`; on launch, show the cached items first, then refresh.

---

## Recap

- **`@AppStorage` + `AppStorage+Keys`** centralizes small preferences behind
  typed initializers; you added `isHapticsEnabled` and a Settings toggle without
  touching a view model.
- **`UserDefaults`** is the same store from non-View code; UIKit/AppKit templates
  wrap it in a typed `UserDefaultsManager` with a `@UserDefault` property wrapper.
- **`KeychainStore`** is a small, `Sendable` wrapper over the Security framework
  with `save`/`read`/`delete`; it's where the Module 04 auth token belongs.
- **SwiftData** handles structured local data: a `@Model`, one `ModelContainer`
  at the entry point, `@Query` to read live, `insert`/`delete` to mutate — with
  Core Data as the fallback for older targets or existing stores.
- **Files + `Codable`** in Application Support cover documents, caches, and blobs.
- The decision tree: secrets → Keychain, prefs → `@AppStorage`/`UserDefaults`,
  records → SwiftData/Core Data, blobs → files.

**Next:** [Module 08 — Dependency Injection & Architecture](08-dependency-injection-and-architecture.md)
