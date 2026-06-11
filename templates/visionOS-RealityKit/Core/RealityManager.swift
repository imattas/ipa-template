import Foundation
import SwiftUI
import RealityKit

/// Central, observable manager for the app's RealityKit scene and the
/// immersive-space lifecycle.
///
/// This is the "M" + a thin coordinator in an MVVM-ish setup: SwiftUI views
/// (``ContentView``, ``ImmersiveView``) observe and command this single type
/// rather than owning RealityKit state themselves.
///
/// - Note: We use the modern `@Observable` macro. An `ObservableObject` /
///   `@Published` fallback is **not** needed here: visionOS ships only on an
///   iOS 17-era (Observation-capable) runtime, so the macro is always
///   available. We keep `@Observable` deliberately.
@Observable
@MainActor
final class RealityManager {

    /// Stable identifier shared by `AppEntry`'s `ImmersiveSpace(id:)` and the
    /// `openImmersiveSpace(id:)` call in `ContentView`.
    static let immersiveSpaceID = "ImmersiveSpace"

    /// Lifecycle of the immersive space, driven from the UI but stored here so
    /// every view sees a single source of truth.
    enum ImmersiveState: Sendable {
        case closed
        case opening
        case open

        var label: String {
            switch self {
            case .closed:  "Closed"
            case .opening: "Opening…"
            case .open:    "Open"
            }
        }
    }

    /// Current immersive-space state. Mutated by `ContentView` around the
    /// async open/dismiss calls.
    var immersiveState: ImmersiveState = .closed

    /// Number of spawnable entities currently in the scene (excludes lights).
    private(set) var entityCount: Int = 0

    /// The root entity for all content. Built lazily by ``buildScene()`` and
    /// reused so the window scene can mutate the live graph.
    private var root: Entity?

    /// Container that holds only the user-spawnable model entities, so we can
    /// reset/count them without touching lighting.
    private var contentContainer: Entity?

    // MARK: - Scene Construction

    /// Builds (or returns the existing) root entity for the immersive scene.
    ///
    /// Called from `ImmersiveView`'s async `make` closure. Adds a small
    /// starter scene: a light plus a few primitive `ModelEntity`s.
    func buildScene() async -> Entity {
        if let root { return root }

        let root = Entity()
        root.name = "Root"

        // A container we can clear on reset.
        let container = Entity()
        container.name = "Content"
        root.addChild(container)
        self.contentContainer = container

        // Lighting. An image-based or directional light makes materials read
        // correctly in `.mixed`/`.full` immersion.
        root.addChild(makeDirectionalLight())

        // Seed the scene with a couple of primitives.
        let sphere = makeModel(
            mesh: .generateSphere(radius: 0.12),
            color: .systemTeal,
            position: SIMD3<Float>(-0.25, 1.4, -1.5)
        )
        let box = makeModel(
            mesh: .generateBox(size: 0.2, cornerRadius: 0.02),
            color: .systemOrange,
            position: SIMD3<Float>(0.25, 1.4, -1.5)
        )
        container.addChild(sphere)
        container.addChild(box)
        entityCount = container.children.count

        self.root = root
        return root
    }

    // MARK: - Scene Mutation

    /// Spawns a randomly shaped, randomly colored, randomly placed entity.
    /// Safe to call only while the immersive space is open.
    func addRandomEntity() {
        guard let container = contentContainer else { return }

        let mesh: MeshResource = Bool.random()
            ? .generateSphere(radius: Float.random(in: 0.06...0.16))
            : .generateBox(size: Float.random(in: 0.1...0.24), cornerRadius: 0.02)

        let palette: [UIColor] = [.systemTeal, .systemOrange, .systemPink,
                                  .systemIndigo, .systemGreen, .systemYellow]

        let model = makeModel(
            mesh: mesh,
            color: palette.randomElement() ?? .systemTeal,
            position: SIMD3<Float>(
                Float.random(in: -0.5...0.5),
                Float.random(in: 1.1...1.7),
                Float.random(in: -1.8 ... -1.1)
            )
        )

        container.addChild(model)
        entityCount = container.children.count

        animatePop(model)
    }

    /// Reacts to a spatial tap on an entity (from `ImmersiveView`'s gesture).
    /// Here we animate a quick "pop" on the tapped entity.
    /// - TODO: Replace with app-specific behavior (select, delete, inspect…).
    func handleTap(on entity: Entity) {
        animatePop(entity)
    }

    /// Removes all spawnable entities, restoring the empty container.
    func reset() {
        guard let container = contentContainer else { return }
        container.children.removeAll()
        entityCount = 0
    }

    // MARK: - Helpers

    /// Creates a `ModelEntity` with a `SimpleMaterial` and a tap collision
    /// shape so it can receive `SpatialTapGesture`s.
    private func makeModel(mesh: MeshResource, color: UIColor, position: SIMD3<Float>) -> ModelEntity {
        let material = SimpleMaterial(color: color, roughness: 0.35, isMetallic: false)
        let model = ModelEntity(mesh: mesh, materials: [material])
        model.position = position

        // Required for gesture targeting + hit testing.
        model.generateCollisionShapes(recursive: false)
        model.components.set(InputTargetComponent())

        return model
    }

    private func makeDirectionalLight() -> Entity {
        let light = DirectionalLight()
        light.light.intensity = 1500
        light.look(at: .zero, from: SIMD3<Float>(0, 2, 0), relativeTo: nil)
        let holder = Entity()
        holder.name = "KeyLight"
        holder.addChild(light)
        return holder
    }

    /// Simple scale "pop" animation used for spawns and taps.
    private func animatePop(_ entity: Entity) {
        let base = entity.transform
        var enlarged = base
        enlarged.scale = base.scale * 1.25
        entity.move(to: enlarged, relativeTo: entity.parent, duration: 0.12, timingFunction: .easeOut)
        // Return to base shortly after.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            entity.move(to: base, relativeTo: entity.parent, duration: 0.18, timingFunction: .easeInOut)
        }
    }
}
