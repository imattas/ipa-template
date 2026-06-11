# Module 12 — Platform Deep Dives

By now you've built real features on the SwiftUI template and learned the cross-cutting craft: layered architecture, networking, observable state, dependency injection, testing, and Swift concurrency. This module is a **tour of the other nine templates** in `ipa-template` — UIKit, AppKit, watchOS, visionOS, Metal, Objective-C, Objective-C++, and the C / C++ libraries. Each one targets a different platform or language, but they all share the same DNA.

**The big idea: Modules 01–11 still apply.** Every template uses the same `Core/Networking` + `Core/Storage` layering, the same `@Observable @MainActor` view-model pattern (or its ObjC/C++ analog), the same protocol-based DI for testability, and the same `async`/`await` concurrency discipline you already know. What changes from template to template is only the **platform surface**: the UI framework, the app lifecycle, and a handful of platform-specific APIs. This module focuses on exactly that surface — what's distinct, the key APIs each template demonstrates, how to extend it, the gotchas, and which earlier modules carry over unchanged.

Read each subsection as a self-contained mini-guide. Skim the one you need; the patterns rhyme across all of them.

**Prerequisites**

- You've completed Modules 01–11, especially [Module 11 — Design System and Accessibility](11-design-system-and-accessibility.md). The architecture, networking, state, DI, testing, and concurrency vocabulary from those modules is assumed here.
- You can open and build a template in Xcode (or, for the libraries, run `make` / `cmake` from a terminal).

---

## Swift-UIKit (iOS)

`templates/Swift-UIKit/` is a fully **programmatic UIKit** app — no storyboards, no XIBs. The app boots through `App/AppDelegate.swift` + `App/SceneDelegate.swift`, and every screen is a `UIViewController` whose view hierarchy is built in code with Auto Layout.

**What makes it distinct.** UIKit is imperative: you own the view lifecycle (`viewDidLoad`, `viewWillAppear`, …) and you push state into views by hand. The template marries that to the *same* MVVM you used in SwiftUI. `HomeViewModel` is an ordinary `@Observable @MainActor` class — identical in spirit to the SwiftUI one — and the view controller observes it.

**Key API — observing an `@Observable` VM without SwiftUI.** SwiftUI subscribes to `@Observable` automatically; UIKit does not, so the template uses `withObservationTracking`. This fires its `onChange` closure exactly **once**, so you re-arm it after every render to keep observing:

```swift
private func observeViewModel() {
    withObservationTracking {
        // Read every property you render so the tracker subscribes to them.
        _ = viewModel.items
        _ = viewModel.isLoading
        _ = viewModel.errorMessage
    } onChange: { [weak self] in
        // onChange is delivered off the main actor; hop back before UIKit work.
        Task { @MainActor [weak self] in
            self?.render()
            self?.observeViewModel()   // re-arm for the next change
        }
    }
    render()   // initial paint
}
```

`render()` reads the view model and updates the `UITableView`, `UIActivityIndicatorView`, and `UIRefreshControl`. The controller is the `dataSource`/`delegate` and dequeues cells with `cell.defaultContentConfiguration()`.

**Tables and collections.** `HomeViewController` uses a classic `UITableView` with `register(_:forCellReuseIdentifier:)` + `dequeueReusableCell`. For new screens, prefer a **diffable data source** (`UITableViewDiffableDataSource` / `UICollectionViewDiffableDataSource`) — you apply an `NSDiffableDataSourceSnapshot` instead of calling `reloadData()`, and you get animated, crash-free updates for free. Collection views with compositional layout (`UICollectionViewCompositionalLayout`) are the modern default for anything grid- or list-shaped.

**How to extend it.** Copy the Home feature folder: a `<Name>ViewController.swift` + `<Name>ViewModel.swift` pair. Build the view in `viewDidLoad`/`loadView`, inject the view model through `init(viewModel:)` (note `init(coder:)` is marked `@available(*, unavailable)` — these controllers are never decoded from a storyboard), wire `withObservationTracking`, and present or push it.

**Gotchas.**
- `withObservationTracking`'s `onChange` runs off the main actor — always hop back with `Task { @MainActor in … }` before touching UIKit.
- It's one-shot. Forget to re-arm and your UI silently stops updating after the first change.
- Use `[weak self]` in the closures; the controller and view model can otherwise retain each other through the observation.

**When to choose UIKit over SwiftUI.** Reach for UIKit when you need fine-grained control SwiftUI doesn't expose: complex custom `UICollectionView` layouts, precise text input / `UITextInteraction`, advanced gesture and hit-testing, mature camera/AVFoundation view plumbing, or interop with a large existing UIKit codebase. Otherwise SwiftUI is faster to build in.

**Embedding SwiftUI in UIKit.** You don't have to pick one. Wrap any SwiftUI view in `UIHostingController` and add it as a child controller:

```swift
let host = UIHostingController(rootView: ProfileView(viewModel: profileVM))
addChild(host)
host.view.translatesAutoresizingMaskIntoConstraints = false
view.addSubview(host.view)
NSLayoutConstraint.activate([ /* pin host.view to its container */ ])
host.didMove(toParent: self)
```

This is the standard incremental-migration path: keep UIKit navigation, render individual screens in SwiftUI.

**Modules that still apply:** all of them. Networking (`Core/Networking/APIClient.swift`), DI through `APIClientProtocol`, the `@Observable` VM, `async load()`, and testing are unchanged from the SwiftUI template — only the view layer differs.

---

## macOS-AppKit

`templates/macOS-AppKit/` is a programmatic **AppKit** desktop app. It looks like the UIKit template's cousin: `NSViewController` + `NSTableView` instead of `UIViewController` + `UITableView`, and the same `withObservationTracking` observation pattern.

**Distinct: the single explicit entry point.** AppKit apps here boot from `App/main.swift`, **not** from a `@main`/`@NSApplicationMain` attribute. `main.swift` creates the application, installs the delegate, and runs the loop:

```swift
import AppKit

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)   // appears in the Dock, owns windows
application.run()                           // does not return until quit
```

`AppDelegate` therefore carries **no** `@main` attribute — adding one would create a second top-level entry point and fail to compile. The rule the template enforces: *exactly one entry point.*

**Key APIs.** `AppDelegate` is `@MainActor`-isolated (Swift 6 strict concurrency requires main-actor isolation before touching `NSWindow`, menus, or view controllers) and builds everything in code:
- `applicationDidFinishLaunching` calls `setupMainMenu()` and `setupMainWindow()`.
- `setupMainWindow()` constructs an `NSWindow` with an explicit `styleMask`, sets `contentViewController`, and retains an `NSWindowController`.
- `setupMainMenu()` builds the App and Edit menus by hand — including the conventional `Settings…` item at `⌘,` and standard `Quit`/`Hide`/clipboard items wired to `NSApplication`/`NSText` selectors.

`HomeViewController` builds its view in `loadView()` (no nib), hosts a view-based `NSTableView` inside an `NSScrollView`, and acts as both `NSTableViewDataSource` and `NSTableViewDelegate`. Cells are recycled via `tableView.makeView(withIdentifier:owner:)` returning an `NSTableCellView`.

**How to extend it.** Add a feature as an `NSViewController` + `NSViewModel` pair, build its UI in `loadView()`, observe with the same `withObservationTracking` loop, and present it. New windows follow `openSettings(_:)`: build an `NSWindow`, set its `contentViewController`, wrap it in an `NSWindowController`, and retain the controller (otherwise the window deallocates and vanishes).

**Gotchas.**
- **Retain your window controllers.** AppKit windows are owned by their controllers; the template keeps `mainWindowController`/`settingsWindowController` as properties for exactly this reason.
- AppKit's coordinate system is flipped relative to UIKit (origin bottom-left) unless you override `isFlipped`.
- `@MainActor` everywhere: under Swift 6 strict concurrency you'll get diagnostics if delegate callbacks or table data-source methods aren't main-actor isolated.

**Embedding SwiftUI in AppKit.** Same story as UIKit, with `NSHostingController` / `NSHostingView`:

```swift
let host = NSHostingController(rootView: SettingsView())
let window = NSWindow(contentViewController: host)
```

**Modules that still apply:** networking, storage (`Core/Storage/UserDefaultsManager.swift`), DI, the `@Observable` VM, and testing (`Tests/Unit/HomeViewModelTests.swift`) are identical to iOS. Only the view framework and the `main.swift` lifecycle differ.

---

## watchOS-SwiftUI

`templates/watchOS-SwiftUI/` is a **single-target watch app** built entirely in SwiftUI. The UI code (`HomeView`, `SettingsView`, their `@Observable` view models) will look completely familiar after the SwiftUI module — the watch-specific surface is the lifecycle and the form factor.

**Distinct: the WatchKit lifecycle bridge.** The entry point is a SwiftUI `App`, but watchOS still has a classic WatchKit application lifecycle. The template bridges them with `@WKApplicationDelegateAdaptor`:

```swift
@main
struct WatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            NavigationStack { HomeView() }   // watchOS roots on a NavigationStack
        }
    }
}
```

`AppDelegate` conforms to `WKApplicationDelegate` and receives `applicationDidFinishLaunching`, `applicationDidBecomeActive`, and `applicationWillResignActive`.

**Key API — background refresh.** The watch is aggressively power-managed, so background work arrives as scheduled `WKRefreshBackgroundTask`s in `handle(_:)`. The contract: **every task must be completed**, or the system penalizes your background budget. The template handles each task type and re-schedules the next refresh:

```swift
func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
    for task in backgroundTasks {
        switch task {
        case let refresh as WKApplicationRefreshBackgroundTask:
            scheduleNextBackgroundRefresh()                 // keep the cycle going
            refresh.setTaskCompletedWithSnapshot(false)
        case let urlTask as WKURLSessionRefreshBackgroundTask:
            urlTask.setTaskCompletedWithSnapshot(false)
        case let snapshot as WKSnapshotRefreshBackgroundTask:
            snapshot.setTaskCompleted(restoredDefaultState: true,
                                      estimatedSnapshotExpiration: .distantFuture,
                                      userInfo: nil)
        default:
            task.setTaskCompletedWithSnapshot(false)        // never leak budget
        }
    }
}

private func scheduleNextBackgroundRefresh() {
    let next = Date().addingTimeInterval(15 * 60)
    WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: next, userInfo: nil) { error in
        if let error { print("Failed to schedule refresh: \(error)") }
    }
}
```

**Designing for the tiny screen.** `HomeView` shows the watch idioms: a `List` of compact two-line rows, `ProgressView` for loading, and `ContentUnavailableView` for the error state with a Retry button. Note `.containerBackground(.blue.gradient, for: .navigation)` — the watchOS way to tint the navigation container. Keep tap targets large, text short, and hierarchies shallow; the screen is small and interactions are brief.

**How to extend it.** Add a feature exactly as in the SwiftUI module: `Features/<Name>/<Name>View.swift` + `@Observable` view model, navigate with `NavigationLink` inside the root `NavigationStack`. Storage uses `Core/Storage/AppStorage+Keys.swift` (`@AppStorage`) rather than a `UserDefaultsManager`.

**Complications and connectivity (pointers).** Two watch-specific surfaces this minimal template leaves as next steps:
- **Complications:** build them with **WidgetKit** (a `Widget` in a widget extension with watch-specific families). They share your data layer but render through the widget timeline, not your app UI.
- **iPhone connectivity:** use **WatchConnectivity** (`WCSession`) to exchange messages, application context, and file transfers with a paired iPhone app. Wire `WCSession` activation in `applicationDidFinishLaduching` alongside the refresh scheduling.

**Gotchas.**
- Forgetting to complete a background task is the classic watch bug — it silently degrades your refresh budget over days.
- Background time is scarce; do the minimum (fetch, cache, update snapshot) and finish fast.

**Modules that still apply:** networking, the `@Observable` VM, `async load()`, DI, and testing are unchanged. The lifecycle adaptor and background-task budget are the only new concepts.

---

## visionOS-RealityKit

`templates/visionOS-RealityKit/` is the most spatial of the bunch. It demonstrates the signature visionOS architecture: a **2D window for controls plus a 3D immersive space for content**, both driven by one shared, observable manager.

**Distinct: windows vs. immersive spaces.** `App/AppEntry.swift` declares two scenes and injects a single `RealityManager` into both via `.environment(_:)`:

```swift
@main
struct VisionOSRealityKitApp: App {
    @State private var reality = RealityManager()

    var body: some Scene {
        WindowGroup {                                   // 2D control panel
            ContentView().environment(reality)
        }
        .defaultSize(width: 420, height: 560)

        ImmersiveSpace(id: RealityManager.immersiveSpaceID) {   // 3D content
            ImmersiveView().environment(reality)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed, .progressive, .full)
    }
}
```

A `WindowGroup` floats a flat panel in the user's space; an `ImmersiveSpace` takes over the volume around them. `.mixed` blends with passthrough; `.full` replaces it; `.progressive` is the dial-in style. Only one immersive space is open at a time.

**Key API — `RealityView` and the RealityManager pattern.** `ImmersiveView` hosts RealityKit content through `RealityView`, deferring all scene construction to the manager so the window and the immersive space share one scene graph:

```swift
RealityView { content in
    let root = await reality.buildScene()   // async make: build once, off the render path
    content.add(root)
} update: { content in
    // runs when observed SwiftUI state changes; the manager mutates in place
}
.gesture(
    SpatialTapGesture()
        .targetedToAnyEntity()
        .onEnded { value in reality.handleTap(on: value.entity) }
)
```

`RealityManager` is the single source of truth — an `@Observable @MainActor` class (visionOS always ships an Observation-capable runtime, so no `ObservableObject` fallback is needed). It owns:
- **Entities, materials, lighting.** `buildScene()` assembles a root `Entity`, adds a `DirectionalLight`, and seeds `ModelEntity`s from `MeshResource.generateSphere`/`generateBox` with `SimpleMaterial`. Lighting matters: in `.mixed`/`.full` immersion, materials only read correctly with a light in the scene.
- **Gesture targeting.** For an entity to receive a `SpatialTapGesture`, it needs `generateCollisionShapes(recursive:)` **and** an `InputTargetComponent()` — `makeModel` sets both. Skip either and taps won't register.
- **Scene mutation.** `addRandomEntity()`, `handleTap(on:)`, and `reset()` mutate the live graph; `entityCount` is observable so the 2D panel reflects it instantly.

**Key API — opening and dismissing the space.** The 2D `ContentView` drives the immersive lifecycle through environment actions, which are `async`:

```swift
@Environment(\.openImmersiveSpace)    private var openImmersiveSpace
@Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

Task {
    reality.immersiveState = .opening
    switch await openImmersiveSpace(id: RealityManager.immersiveSpaceID) {
    case .opened:                    reality.immersiveState = .open
    case .userCancelled, .error:     reality.immersiveState = .closed   // revert
    @unknown default:                reality.immersiveState = .closed
    }
}
// elsewhere:
await dismissImmersiveSpace()
```

Driving `immersiveState` through the shared manager keeps the button label, status dot, and entity controls in sync.

**How to extend it.** Add entity types or behaviors as methods on `RealityManager` (keep RealityKit state out of the views). Add controls to `ContentView` that call those methods. For richer assets, load USDZ via `Entity(named:in:)` or `ModelEntity(named:)`. Match the `ImmersiveSpace(id:)` to the `openImmersiveSpace(id:)` argument — both use `RealityManager.immersiveSpaceID`.

**Gotchas.**
- Entities without a collision shape + `InputTargetComponent` are invisible to gestures.
- The immersive open/dismiss calls are async and can be cancelled by the user — handle `.userCancelled`/`.error` and revert state (the template disables the button while `.opening`).
- Position entities in front of and around the user (note the negative-Z, ~1.4m-high placements in `buildScene()`); content at the origin may spawn inside the user.

**Modules that still apply:** the architecture (single observable manager as the source of truth), DI/environment injection, `@Observable` state, and concurrency (`async` scene building and space transitions) are the same ideas you already know, applied to a 3D scene graph.

---

## Metal (GPU)

`templates/Metal/` drops below the UI frameworks to talk to the GPU directly. It renders an animated triangle and runs an independent compute pass, hosted in SwiftUI through a `UIViewRepresentable`.

**Distinct: the render loop.** `Renderer` (in `Renderer/Renderer.swift`) is an `@MainActor` `MTKViewDelegate`. MetalKit calls `draw(in:)` every frame; you encode GPU work into a **command buffer** via a **command encoder** and commit it:

```swift
func draw(in view: MTKView) {
    _ = buffers.inFlightSemaphore.wait(timeout: .distantFuture)   // throttle

    guard let commandBuffer = metal.commandQueue.makeCommandBuffer(),
          let rpd = view.currentRenderPassDescriptor,
          let drawable = view.currentDrawable else {
        buffers.inFlightSemaphore.signal(); return
    }

    let semaphore = buffers.inFlightSemaphore
    commandBuffer.addCompletedHandler { _ in semaphore.signal() }  // signal when GPU done

    buffers.advanceFrame()
    buffers.update(uniforms: Uniforms(modelViewProjection: projectionMatrix(), time: time))

    if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) {
        encoder.setRenderPipelineState(renderPipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: Int(BufferIndex.vertices.rawValue))
        encoder.setVertexBuffer(buffers.currentUniformBuffer, offset: 0, index: Int(BufferIndex.uniforms.rawValue))
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        encoder.endEncoding()
    }
    commandBuffer.present(drawable)
    commandBuffer.commit()
}
```

The CPU encoding is cheap; the GPU runs asynchronously. You never block the main thread waiting on the GPU.

**Key API — compute kernels.** `runCompute()` shows the compute path, fully decoupled from rendering: make a `MTLComputeCommandEncoder`, set the compute pipeline and buffers, then `dispatchThreadgroups`. The grid is rounded up to cover all elements and the kernel (`compute_main`) guards against the overshoot with `if (gid >= count) return;`. It's wrapped in `withCheckedContinuation` so callers `await` GPU completion without blocking a thread.

**Key API — CPU/GPU shared types.** `Renderer/ShaderTypes.h` is the single source of truth for memory layout, imported from **both** Swift (via the bridging header) and `.metal` files. It detects which side it's on with `#ifdef __METAL_VERSION__`. All shared structs use `simd` vector/matrix types, which have identical layout on both sides.

The detail worth internalizing: buffer indices are a **shared `NS_ENUM`**. On the CPU it imports into Swift as `BufferIndex`, and you reference cases like `BufferIndex.vertices` / `BufferIndex.uniforms` / `BufferIndex.compute` (`Int(BufferIndex.vertices.rawValue)`); on the GPU the *same* enum drives the `[[ buffer(BufferIndexVertices) ]]` attributes:

```c
typedef NS_ENUM(EnumBackingType, BufferIndex) {
    BufferIndexVertices = 0,
    BufferIndexUniforms = 1,
    BufferIndexCompute  = 2,
};
```

Because both sides read the same enum, the buffer slots can never drift out of sync — the classic class of Metal bug this design eliminates. (One subtlety the template exploits in the compute pass: it reuses `BufferIndex.vertices` to pass the element `count`, since the compute kernel has no vertex buffer.)

**Key API — triple-buffering.** `Core/BufferManager.swift` keeps a ring of `kMaxBuffersInFlight` (3) uniform buffers plus a `DispatchSemaphore`. The CPU records frame N+1 while the GPU still reads frame N; the ring prevents the CPU from overwriting data the GPU is mid-read on, and the semaphore caps how far ahead the CPU may run. Waiting before encoding + signaling in the completion handler is the whole synchronization story. Buffers use `.storageModeShared` (correct on Apple Silicon).

**Hosting.** `Renderer/MetalView.swift` is a `UIViewRepresentable` wrapping an `MTKView`. The `Renderer` is created and retained in `makeCoordinator()` because `MTKView.delegate` is **weak** — something must own the renderer or it deallocates immediately.

**How to add a new shader / pipeline.** (1) Write the function(s) in `Shaders.metal`. (2) If they need new shared data, add the struct/enum to `ShaderTypes.h` so both sides agree. (3) Build the pipeline state in `Renderer.init` via the `MetalDevice` helpers (`makeRenderPipelineState(vertex:fragment:pixelFormat:)` or `makeComputePipelineState(function:)`), looking functions up by name. (4) Bind buffers at the shared `BufferIndex` slots and encode in `draw(in:)` or a new compute method.

**Gotchas.**
- `MTKView.delegate` is weak — retain the `Renderer` (the coordinator does this).
- The view's `colorPixelFormat` must match what the render pipeline was built against (`.bgra8Unorm` here).
- Keep shared structs GPU-aligned (16-byte); `ShaderTypes.h` flags this for `Uniforms`.
- Never block the main thread on the GPU; throttle with the semaphore instead.

**Modules that still apply:** concurrency (the semaphore throttle, completion handlers, and `async runCompute()` with `withCheckedContinuation`) and the DI/testing mindset carry over. The rendering and shared-type plumbing are the genuinely new surface.

---

## Objective-C (UIKit)

`templates/ObjectiveC-UIKit/` is a complete UIKit app written in **Objective-C** — `.h`/`.m` pairs, `main.m`, `AppDelegate`, `SceneDelegate`, and a hand-built networking layer.

**Why ObjC still matters.** You'll meet it maintaining established codebases, writing low-level interop, working with frameworks that expose ObjC-first APIs, or building a bridge layer (see the next subsection). Knowing modern ObjC lets you read and extend that code confidently rather than rewriting it.

**Key API — NSURLSession + completion blocks.** `Core/Networking/APIClient.m` is the canonical pre-`async`/`await` networking shape: a `dataTaskWithURL:completionHandler:` whose completion handles transport errors, HTTP status, empty bodies, and JSON decoding, then **always delivers on the main queue**:

```objc
NSURLSessionDataTask *task =
    [self.session dataTaskWithURL:url
                completionHandler:^(NSData *_Nullable data,
                                    NSURLResponse *_Nullable response,
                                    NSError *_Nullable transportError) {
    if (transportError != nil) { /* wrap + deliver */ return; }
    // ... status / empty / JSON checks ...
    [self deliver:completion items:[items copy] error:nil];
}];
[task resume];
```

```objc
- (void)deliver:(APIClientItemsCompletion)completion
          items:(nullable NSArray<Item *> *)items
          error:(nullable NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{ completion(items, error); });
}
```

Compare this to Swift's `async`/`await`: the completion-block version manually threads the success/error split through every branch and hand-hops to the main queue. `async` collapses all of that into linear code with structured error propagation. When you bridge ObjC into Swift, you can wrap these completion APIs in `withCheckedThrowingContinuation` to give callers a clean `await`.

**Key API — error domains and `NS_ENUM`.** Errors are modeled the idiomatic ObjC way: an exported domain constant plus a typed code enum (`APIClient.h`):

```objc
extern NSString *const APIClientErrorDomain;

typedef NS_ENUM(NSInteger, APIClientErrorCode) {
    APIClientErrorCodeInvalidURL    = 1,
    APIClientErrorCodeTransport     = 2,
    APIClientErrorCodeBadStatus     = 3,
    APIClientErrorCodeEmptyResponse = 4,
    APIClientErrorCodeDecoding      = 5,
};
```

`NSError`s are built with that domain/code plus a `userInfo` carrying `NSLocalizedDescriptionKey` and an optional `NSUnderlyingErrorKey`. `NS_ENUM` imports into Swift as a proper enum, so Swift callers get type-safe `APIClientErrorCode` cases for free.

**Interop with Swift.** ObjC and Swift coexist in one target:
- ObjC → Swift: list your ObjC headers in the **bridging header**; Swift sees the classes directly.
- Swift → ObjC: Xcode generates `<Module>-Swift.h`; mark Swift APIs `@objc`/`@objcMembers` and classes `NSObject`-derived to expose them.

The template's `APIClient` is built for this: a `sharedClient` singleton for app code **and** a designated `initWithBaseURL:session:` (with `init` marked `NS_UNAVAILABLE`) so tests — and Swift callers — can inject a stubbed `NSURLSession`. That's the same protocol-based DI idea from the testing module, in ObjC clothing.

**Modern ObjC.** The template uses today's conventions throughout:
- **Nullability:** `NS_ASSUME_NONNULL_BEGIN/END` plus explicit `_Nullable`, so the API imports into Swift with correct optionals.
- **Lightweight generics:** `NSArray<Item *> *`, `NSMutableDictionary<NSErrorUserInfoKey, id> *` — typed collections that bridge to typed Swift arrays/dictionaries.
- **`NS_DESIGNATED_INITIALIZER` / `NS_UNAVAILABLE`** to make object construction explicit and testable.

**Gotchas.**
- A completion that doesn't hop to the main queue will update UIKit off the main thread — the template centralizes the hop in `deliver:`.
- Missing nullability annotations import everything as implicitly-unwrapped optionals (`!`) on the Swift side — annotate consistently.

**Modules that still apply:** networking layering, protocol/initializer-based DI, error modeling, and unit testing (`Tests/Unit/APIClientTests.m`) all map directly onto what you learned — the language is different, the architecture is the same.

---

## Objective-C++ (mixed C++ core)

`templates/ObjectiveCpp-Mixed/` is the template to study when you have a **portable C++ core** you want to use from an Apple app. It demonstrates a clean bridging discipline so C++ never leaks into Swift.

**The layers.**
- **Pure C++ core** — `Core/Engine/ComputeEngine.hpp` / `.cpp`. `app::ComputeEngine` is a statistics processor with **zero** Objective-C or platform code: just STL (`std::vector<double>`), RAII, and value semantics. It compiles and unit-tests on any C++17 toolchain.
- **A C++-free ObjC bridge** — `Core/Bridge/EngineBridge.h` is a plain `NSObject` facade whose header contains **no C++ types at all**. Every method speaks `double`/`NSUInteger`:

```objc
@interface EngineBridge : NSObject
- (void)addSample:(double)value;
- (double)mean;
- (double)standardDeviation;
- (NSUInteger)count;
- (void)reset;
@end
```

- **The Objective-C++ implementation** — `EngineBridge.mm`. The `.mm` extension makes it Objective-C++, so it may freely `#include "ComputeEngine.hpp"` and use STL. It holds the C++ engine behind an **opaque pointer (Pimpl)**, as a `std::unique_ptr` ivar:

```objc
@implementation EngineBridge {
    std::unique_ptr<app::ComputeEngine> _engine;   // concrete C++ type only known here
}
- (instancetype)init {
    if ((self = [super init])) { _engine = std::make_unique<app::ComputeEngine>(); }
    return self;
}
- (double)mean { return _engine->mean(); }
// ...no explicit -dealloc: ARC deallocs the object, which destroys the
// unique_ptr ivar, which tears down the C++ object (RAII).
@end
```

**Why the header stays C++-free.** Swift's ObjC importer cannot parse C++ types in a header. The moment a bridge header exposes `std::vector` or an `app::` type, it becomes unimportable from Swift. Keeping the header to ObjC/Foundation types only is what lets **both** Objective-C and Swift consume `EngineBridge` directly — the C++ lives entirely inside the `.mm` translation unit. This also gives you the Pimpl benefit: changing `ComputeEngine`'s internals doesn't ripple into anything that imports the bridge header.

**Memory management.** This is the clean ARC + C++ story: ARC manages the `EngineBridge` object; the `std::unique_ptr` ivar's destructor runs automatically when the object is deallocated, freeing the C++ engine. No manual `-dealloc`, no leaks, no double-frees.

**Compiling `.mm`.** Files with the `.mm` extension are compiled as Objective-C++ — set the C++ dialect (e.g. `-std=gnu++17` / `CLANG_CXX_LANGUAGE_STANDARD = gnu++17`) in build settings. The pure C++ `.cpp` files compile under the same standard. Only the `.mm` and `.cpp` files need C++; the rest of the app stays pure ObjC/Swift.

**Exposing a new C++ API across the bridge.** Four mechanical steps:
1. Add the method to the C++ class (`ComputeEngine.hpp` + `.cpp`).
2. Declare a matching ObjC method on `EngineBridge.h` using **only** ObjC/C scalar/Foundation types (convert C++ types — e.g. `std::string` → `NSString *`, `std::vector` → `NSArray *` — at the boundary).
3. Implement it in `EngineBridge.mm`, forwarding to `_engine->...` and converting types as needed (note the `static_cast<NSUInteger>(_engine->count())` already in the template).
4. Call it from Swift/ObjC — no C++ knowledge required on the caller's side.

**Gotchas.**
- One C++ type in the bridge header and Swift interop breaks. Keep it pure ObjC.
- Convert C++ <-> ObjC types **at** the boundary, not past it.
- Make sure the bridge file is `.mm`, not `.m` — `.m` won't compile the C++ includes.

**Modules that still apply:** the facade/bridge **is** the dependency-inversion boundary from the architecture and DI modules; you can unit-test the pure C++ core with any C++ test runner *and* the bridge from ObjC (`Tests/Unit/EngineBridgeTests.mm`). Networking and UI layers above the bridge are ordinary ObjC/Swift.

---

## C and C++ libraries

The last two templates aren't apps — they're **reusable cores** you compile into a library and link from one. They share a conventional layout and tie directly back to the Objective-C++ bridge above.

**`C-Library` (`libutil`).** A dependency-free C11 utility library:
- `include/util.h` is an **umbrella header**: include it once to pull in the whole public API (`util/status.h`, `util/dyn_array.h`, `util/str_util.h`). It wraps declarations in `extern "C"` so the library is callable from C++ too, and exposes version macros + `util_version()`.
- `src/` holds the implementation (`dyn_array.c`, `str_util.c`, `status.c`, `version.c`).
- `tests/` holds `test_*.c` runners.
- `Makefile` builds a static archive `build/libutil.a` and runs tests:

```
make          # build build/libutil.a
make test     # build and run every tests/test_*.c
make clean
# override toolchain/flags from the environment:
make CC=clang CFLAGS_EXTRA="-fsanitize=address,undefined"
```

**`CPlusPlus-Framework` (`appcore`).** A C++17 library with public headers under `include/appcore/` (`version.hpp`, `result.hpp`, `event_bus.hpp`, `task_queue.hpp`). The headers show idiomatic modern C++: `appcore::EventBus` is a thread-safe, type-erased pub/sub with an **RAII `Subscription` token** that unsubscribes on destruction (move-only, non-copyable). It builds with either Make or CMake:

```
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
ctest --test-dir build --output-on-failure
```

The `CMakeLists.txt` sets `CMAKE_CXX_STANDARD 17`, exposes `include/` as a `PUBLIC` include directory (build- and install-interface), links `Threads`, and registers each test with `add_test`.

**The `include` / `src` / `tests` layout.** Both libraries follow the same convention: public headers in `include/` (the *only* thing consumers see), implementation in `src/`, tests in `tests/`. Keeping the public surface in `include/` and everything else private is what lets you ship the library as a binary without leaking internals — the same encapsulation discipline as the ObjC++ bridge header.

**Packaging a C++ core as an `xcframework`.** To consume the library from an Apple app, build it as a framework and wrap it in an `.xcframework` so one artifact covers device + simulator (and multiple platforms). `appcore`'s `CMakeLists.txt` already sketches this — a commented Apple block sets:

```cmake
set_target_properties(appcore PROPERTIES
    FRAMEWORK TRUE
    MACOSX_FRAMEWORK_IDENTIFIER com.example.appcore
    VERSION ${PROJECT_VERSION}
    PUBLIC_HEADER "include/appcore/version.hpp;include/appcore/result.hpp;include/appcore/event_bus.hpp;include/appcore/task_queue.hpp")
```

Build a framework slice per platform/arch, then combine them:

```
xcodebuild -create-xcframework \
    -framework build/ios/appcore.framework \
    -framework build/sim/appcore.framework \
    -output appcore.xcframework
```

Drag the resulting `appcore.xcframework` into your Xcode app (or reference it from a Swift Package as a `binaryTarget`).

**Consuming it from an app — tie back to the ObjC++ bridge.** A C++ library can't be called from Swift directly — the importer can't see C++ headers. So you consume it through exactly the bridge pattern from the previous subsection:
1. Link `appcore.xcframework` into your app target.
2. Add a **C++-free** ObjC bridge (`@interface`/`.mm`) that holds the `appcore` type behind a `std::unique_ptr` Pimpl, mirroring `EngineBridge`.
3. Expose only ObjC/Foundation types from the bridge header.
4. Call the bridge from Swift or ObjC.

The C-library case is simpler: because `util.h` already wraps its API in `extern "C"`, you can call it from Swift via a bridging header / module map **without** a C++ shim — plain C imports cleanly.

**Gotchas.**
- An `xcframework` must include every slice you ship to (device + simulator, each platform) or you'll hit link errors on a missing arch.
- Only headers under `include/` are public — don't `#include` `src/` internals from consumer code.
- C++ libraries always need the ObjC++ bridge for Swift; pure C libraries with `extern "C"` do not.

**Modules that still apply:** these libraries are the lowest layer of the architecture from Module 01 — the portable core with no platform dependencies. The testing discipline maps onto `make test` / `ctest`, and the encapsulation (public `include/` vs private `src/`) is the same boundary thinking that runs through the whole course.

---

**Next:** [Module 13 — Shipping to the App Store](13-shipping-to-the-app-store.md)
