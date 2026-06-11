//
//  MetalView.swift
//  Metal Template
//
//  A SwiftUI bridge that hosts an MTKView and wires it to the Renderer.
//
//  UIViewRepresentable is the standard way to embed UIKit/MetalKit views in a
//  SwiftUI hierarchy. The Renderer is created in `makeCoordinator()` so its
//  lifetime matches the representable, and retained by the coordinator (MTKView
//  holds its delegate weakly).
//

import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {

    /// Holds the Renderer alive for the lifetime of the view. MTKView's
    /// `delegate` is weak, so something must own the Renderer.
    @MainActor
    final class Coordinator {
        var renderer: Renderer?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()

        // Pixel format must match what the render pipeline is built against.
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false   // Use the internal draw timer.
        view.isPaused = false

        do {
            let renderer = try Renderer(view: view)
            context.coordinator.renderer = renderer
            view.delegate = renderer
        } catch {
            // In a template we surface setup errors loudly. In production you
            // might present a fallback UI instead.
            assertionFailure("Failed to create Renderer: \(error)")
        }

        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        // No dynamic SwiftUI state drives the view in this template. Push
        // bindings (e.g. paused, color) into the Renderer here as you add them.
    }
}

#Preview {
    // Note: the Metal device is unavailable in some preview contexts; this
    // preview is primarily a layout check.
    MetalView()
        .ignoresSafeArea()
}
