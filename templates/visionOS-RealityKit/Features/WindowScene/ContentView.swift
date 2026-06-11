import SwiftUI

/// 2D control panel shown in the app's main window.
///
/// Responsibilities:
///  - Open / close the ``ImmersiveSpace`` using the SwiftUI environment
///    actions `openImmersiveSpace` and `dismissImmersiveSpace`.
///  - Reflect the current immersive-space state from ``RealityManager``.
///  - Drive scene mutations (spawn / reset entities) via the manager.
struct ContentView: View {

    /// Shared state, injected from `AppEntry.swift` via `.environment(_:)`.
    @Environment(RealityManager.self) private var reality

    // Environment actions for managing the immersive space. These are async
    // because the system may need to transition between spaces.
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 24) {
            header

            statusCard

            controls

            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The signature visionOS "glass" backing for windows.
        .glassBackgroundEffect()
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("RealityKit Control Panel")
                .font(.title2.weight(.semibold))
            Text("Window + Immersive Space template")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusCard: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            Text("Immersive space: \(reality.immersiveState.label)")
                .font(.headline)
            Spacer()
            Text("Entities: \(reality.entityCount)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
    }

    private var controls: some View {
        VStack(spacing: 16) {
            Button(action: toggleImmersiveSpace) {
                Label(
                    reality.immersiveState == .open ? "Exit Immersive Space" : "Enter Immersive Space",
                    systemImage: reality.immersiveState == .open ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
            // Avoid double-taps while a transition is in flight.
            .disabled(reality.immersiveState == .opening)

            Button {
                reality.addRandomEntity()
            } label: {
                Label("Spawn Random Entity", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(reality.immersiveState != .open)

            Button(role: .destructive) {
                reality.reset()
            } label: {
                Label("Reset Scene", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(reality.immersiveState != .open)
        }
    }

    // MARK: - Actions

    private var statusColor: Color {
        switch reality.immersiveState {
        case .closed:  .secondary
        case .opening: .yellow
        case .open:    .green
        }
    }

    /// Opens or dismisses the immersive space, keeping ``RealityManager``'s
    /// state in sync. Runs in a `Task` because the environment actions are
    /// `async`.
    private func toggleImmersiveSpace() {
        Task {
            switch reality.immersiveState {
            case .closed:
                reality.immersiveState = .opening
                let result = await openImmersiveSpace(id: RealityManager.immersiveSpaceID)
                switch result {
                case .opened:
                    reality.immersiveState = .open
                case .userCancelled, .error:
                    // The user denied the transition or it failed; revert.
                    reality.immersiveState = .closed
                @unknown default:
                    reality.immersiveState = .closed
                }
            case .open, .opening:
                await dismissImmersiveSpace()
                reality.immersiveState = .closed
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(RealityManager())
}
