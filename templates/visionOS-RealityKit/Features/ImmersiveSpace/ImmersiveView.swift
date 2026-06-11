import SwiftUI
import RealityKit

/// Hosts the RealityKit 3D content shown inside the ``ImmersiveSpace``.
///
/// The view defers all entity construction to ``RealityManager`` so that the
/// 2D control panel and this 3D view operate on the same scene graph.
struct ImmersiveView: View {

    @Environment(RealityManager.self) private var reality

    var body: some View {
        RealityView { content in
            // `make` closure: build the initial scene once when the
            // RealityView is created. It is async so we can load resources
            // off the main render path.
            let root = await reality.buildScene()
            content.add(root)
        } update: { content in
            // `update` closure: runs when observed SwiftUI state changes.
            // The manager mutates its root entity in place, so nothing more is
            // required here, but this is where you'd react to view-level state
            // (e.g. toggling visibility of a sub-tree).
            // TODO: Add per-frame or state-driven updates here as needed.
            _ = content
        }
        // Tap anywhere on an entity to let the manager react (highlight,
        // animate, remove, etc.).
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    reality.handleTap(on: value.entity)
                }
        )
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(RealityManager())
}
