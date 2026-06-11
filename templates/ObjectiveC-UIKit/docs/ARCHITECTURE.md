# Architecture

This template follows the classic **Model–View–Controller (MVC)** pattern that
UIKit is designed around, kept deliberately small so it is easy to extend.

## Folder structure

```
ObjectiveC-UIKit/
├── App/                  # Process + scene lifecycle, entry point
│   ├── main.m            # UIApplicationMain bootstrap
│   ├── AppDelegate.{h,m} # App-level lifecycle + scene session config
│   ├── SceneDelegate.{h,m} # Builds the UIWindow + root nav controller
│   └── Info.plist        # Scene manifest, launch screen, bundle id
├── Features/             # One folder per screen / feature (View + Controller)
│   ├── Home/             # HomeViewController (list of items)
│   └── Settings/         # SettingsViewController (toggles)
├── Core/                 # Reusable, feature-agnostic building blocks
│   ├── Models/           # Item — plain model objects
│   ├── Networking/       # APIClient — NSURLSession wrapper (singleton)
│   └── Extensions/       # UIView+Extensions — Auto Layout helpers
├── Resources/            # Asset catalog (app icon, accent color)
├── Tests/Unit/           # XCTest unit tests
└── docs/                 # This documentation
```

### Rationale

- **App/** isolates the boot sequence so the rest of the code never deals with
  process startup details.
- **Features/** is organized by screen rather than by type ("all controllers",
  "all views"). Everything for one screen lives together, which keeps changes
  local and makes deletion safe.
- **Core/** holds code that has no knowledge of any specific feature, so it can
  be shared freely and unit-tested in isolation.
- **Tests/** mirror the source layout and depend only on `Core/`, never on UI.

## Data flow

The Home screen is the canonical example of how data moves through the app.
Networking is asynchronous and built on completion blocks; results are always
delivered back on the main queue so the controller can touch UIKit safely.

```
 ┌──────────────────────┐   fetchItemsWithCompletion:   ┌───────────────┐
 │  HomeViewController   │ ────────────────────────────▶ │   APIClient    │
 │  (Controller / View)  │                               │  (singleton)   │
 │                       │                               │                │
 │  - owns UITableView   │                               │  - baseURL     │
 │  - owns [Item] model  │                               │  - NSURLSession│
 └──────────▲───────────┘                               └───────┬───────┘
            │                                                   │ dataTaskWithURL:
            │   completion(items, error)                        │ completionHandler:
            │   (dispatch_async → main queue)                   ▼
            │                                          ┌──────────────────┐
            │                                          │   NSURLSession     │
            │                                          │   (transport)      │
            │                                          └─────────┬─────────┘
            │                                                    │ NSData
            │                                                    ▼
            │                                          ┌──────────────────┐
            └──────────────────────────────────────── │  NSJSONSerialize  │
                  [Item] / NSError (APIClientErrorDomain) │  → [Item itemFromJSON:]
                                                       └──────────────────┘
```

## Patterns used

- **MVC** — `*ViewController` objects are the controllers; `Item` is the model;
  views are created programmatically (no storyboards).
- **Singleton** — `APIClient.sharedClient` provides app-wide network access,
  while the injectable `initWithBaseURL:session:` keeps it testable.
- **Completion blocks** — async results flow back through typed block
  callbacks (`APIClientItemsCompletion`) rather than delegates, with an
  explicit hop to the main queue.
- **Delegation** — `UITableViewDataSource` / `UITableViewDelegate` and
  `UIWindowSceneDelegate` follow UIKit's standard delegate protocols.
- **Category extensions** — `UIView+Extensions` adds Auto Layout convenience
  without subclassing.
- **Dependency injection** — `APIClient` accepts a custom `NSURLSession`, which
  the tests use to stub responses via `NSURLProtocol`.

## Where to add a new feature

1. Create `Features/<FeatureName>/<FeatureName>ViewController.{h,m}`.
2. Build its view hierarchy programmatically in `viewDidLoad`, using the
   `UIView+Extensions` helpers for layout.
3. If it needs data, add a method to `APIClient` (or a new client in
   `Core/Networking/`) returning results via a completion block on the main
   queue, and add a model to `Core/Models/` if needed.
4. Present/push it from an existing controller (e.g. from `HomeViewController`,
   the way `SettingsViewController` is pushed today).
5. Add unit tests under `Tests/Unit/` for any non-UI logic.
```
