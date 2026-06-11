import SwiftUI

/// Entry point for the visionOS app.
///
/// This app demonstrates a *dual-scene* visionOS pattern:
///  - A 2D `WindowGroup` that hosts a control panel (`ContentView`).
///  - An `ImmersiveSpace` that hosts RealityKit 3D content (`ImmersiveView`).
///
/// A single ``RealityManager`` is created here and injected into the SwiftUI
/// environment so both scenes share the same source of truth (entities,
/// immersive-space state, etc.).
@main
struct VisionOSRealityKitApp: App {

    /// The shared scene/state manager. `@State` keeps it alive for the app's
    /// lifetime; `.environment(_:)` makes it available to every child view.
    @State private var reality = RealityManager()

    var body: some Scene {
        // MARK: - 2D Window Scene
        WindowGroup {
            ContentView()
                .environment(reality)
        }
        // A reasonably sized default control panel.
        .defaultSize(width: 420, height: 560)

        // MARK: - Immersive Space
        ImmersiveSpace(id: RealityManager.immersiveSpaceID) {
            ImmersiveView()
                .environment(reality)
        }
        // `.mixed` blends content with passthrough; swap for `.full` or
        // `.progressive` depending on the desired experience.
        // TODO: Expose immersion style as a user setting if you support
        // multiple modes.
        .immersionStyle(selection: .constant(.mixed), in: .mixed, .progressive, .full)
    }
}
